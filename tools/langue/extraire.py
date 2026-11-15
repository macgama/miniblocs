#!/usr/bin/env python3
"""Extrait les textes français des scripts GDScript (scripts/**.gd) pour la traduction.

Chaque littéral de texte devient une clé. Les concaténations ("Prix : " + str(x) + " €")
deviennent des modèles avec %s ("Prix : %s €"). Les textes sur plusieurs lignes sont
découpés ligne par ligne (le jeu traduit aussi ligne par ligne).

Sortie : tools/langue/textes_fr.json (liste triée des clés, avec le fichier d'origine).
Usage : python3 tools/langue/extraire.py
        python3 tools/langue/extraire.py --manquants en
            → tools/langue/manquants_en.txt : textes pas encore dans assets/langues/en.json
              (« fichier | texte »), à traduire puis ajouter au JSON. Les noms propres et
              le code (noms de nœuds, SVG) y restent : c'est normal, ils ne se traduisent pas.
"""
import json, os, re, sys

RACINE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
# Fichiers de noms propres (prénoms, noms de famille, villes) : pas traduits.
IGNORES = {"scripts/habitants/prenoms.gd"}
# Appels dont les textes ne s'affichent pas au joueur.
APPELS_IGNORES = {"print", "prints", "printerr", "push_error", "push_warning", "assert", "print_debug",
	"load", "preload", "get_node", "get_node_or_null", "has_node", "find_child", "is_in_group", "add_to_group",
	"has_method", "call", "callv", "call_deferred", "connect", "emit_signal", "set_meta", "get_meta", "has_meta",
	"get_value", "set_value", "has_section_key", "get_shader_parameter", "set_shader_parameter", "Color",
	"add_theme_color_override", "add_theme_font_size_override", "add_theme_constant_override",
	"add_theme_stylebox_override", "add_theme_font_override", "get_theme_color", "RegEx", "compile",
	"begins_with", "ends_with", "has", "find", "split", "erase", "is_action_pressed", "is_action_just_pressed",
	"get", "set", "get_setting", "file_exists", "dir_exists", "open", "ResourceLoader", "OS", "Time"}

TOK = re.compile(r'''
	(?P<com>\#[^\n]*)
	|(?P<str3>"""(?:.|\n)*?""")
	|(?P<str>&?"(?:[^"\\\n]|\\.)*"|'(?:[^'\\\n]|\\.)*')
	|(?P<nl>\n)
	|(?P<num>\d[\d_]*(?:\.\d+)?(?:e[+-]?\d+)?)
	|(?P<id>[A-Za-z_][A-Za-z_0-9]*)
	|(?P<op>:=|\+=|-=|\*=|/=|==|!=|<=|>=|->|\*\*|[-+*/%=<>!&|^~.,:;()\[\]{}@$])
	|(?P<ws>[ \t\\]+)
''', re.X)

ESC = {"n": "\n", "t": "\t", '"': '"', "'": "'", "\\": "\\", "r": "\r"}


def decode(lit):
	if lit.startswith("&"):
		lit = lit[1:]
	q = lit[0]
	body = lit[1:-1]
	out, i = [], 0
	while i < len(body):
		c = body[i]
		if c == "\\" and i + 1 < len(body):
			n = body[i + 1]
			if n == "u" and i + 6 <= len(body):
				out.append(chr(int(body[i + 2:i + 6], 16))); i += 6; continue
			out.append(ESC.get(n, n)); i += 2; continue
		out.append(c); i += 1
	return "".join(out)


def tokens(src):
	res = []
	for m in TOK.finditer(src):
		k = m.lastgroup
		if k in ("ws", "com"):
			continue
		res.append((k, m.group()))
	return res

DELIM_G = {"(", "[", "{"}
DELIM_D = {")", "]", "}"}
STOP_OPS = {",", "=", ":=", "+=", "-=", ":", "%", "==", "!=", "<", ">", "<=", ">=", ";", "->", "*", "/"}
STOP_IDS = {"return", "if", "else", "elif", "and", "or", "not", "in", "var", "const", "for", "while", "match", "when"}


def span_operands(toks, i):
	"""Opérandes de la chaîne de + autour du jeton i (au même niveau de parenthèses)."""
	# gauche
	a = i
	depth = 0
	j = i - 1
	while j >= 0:
		k, v = toks[j]
		if v in DELIM_D:
			depth += 1
		elif v in DELIM_G:
			if depth == 0:
				break
			depth -= 1
		elif depth == 0 and (k == "nl" or v in STOP_OPS or (k == "id" and v in STOP_IDS)):
			break
		a = j
		j -= 1
	b = i
	depth = 0
	j = i + 1
	while j < len(toks):
		k, v = toks[j]
		if v in DELIM_G:
			depth += 1
		elif v in DELIM_D:
			if depth == 0:
				break
			depth -= 1
		elif depth == 0 and (v in STOP_OPS or (k == "id" and v in STOP_IDS)):
			break
		elif k == "nl" and depth == 0:
			# une ligne qui continue par + est rare : on s'arrête
			break
		b = j
		j += 1
	# découpe sur les + de niveau 0
	ops, cur, depth = [], [], 0
	for k, v in toks[a:b + 1]:
		if v in DELIM_G:
			depth += 1
		elif v in DELIM_D:
			depth -= 1
		if depth == 0 and v == "+":
			ops.append(cur); cur = []
			continue
		if k != "nl":
			cur.append((k, v))
	ops.append(cur)
	return ops, a, b


def est_texte(t):
	if not re.search(r"[A-Za-zÀ-ÿ]{2}", t):
		return False
	if re.fullmatch(r"[a-z0-9_./:#\-]*", t):  # identifiants, chemins
		return False
	if re.fullmatch(r"[A-Za-z0-9_]+", t) and "_" in t:
		return False
	if t.startswith("res://") or t.startswith("user://") or t.startswith("http"):
		return False
	if re.fullmatch(r"[A-Z0-9_]+", t) and len(t) <= 3:
		return False
	return True


def appel_parent(toks, i):
	"""Nom de la fonction appelée dont le jeton i est un argument (ou None)."""
	depth = 0
	j = i - 1
	while j >= 0:
		k, v = toks[j]
		if v in DELIM_D:
			depth += 1
		elif v in DELIM_G:
			if depth == 0:
				if v == "(" and j > 0 and toks[j - 1][0] == "id":
					return toks[j - 1][1]
				return None
			depth -= 1
		elif k == "nl" and depth == 0:
			return None
		j -= 1
	return None


def extraire():
	cles = {}
	for root, _, fs in os.walk(os.path.join(RACINE, "scripts")):
		for f in sorted(fs):
			if not f.endswith(".gd"):
				continue
			p = os.path.join(root, f)
			rel = os.path.relpath(p, RACINE).replace(os.sep, "/")
			if rel in IGNORES:
				continue
			toks = tokens(open(p, encoding="utf8").read())
			vus = set()
			for i, (k, v) in enumerate(toks):
				if k != "str" or i in vus or v.startswith("&"):
					continue
				if appel_parent(toks, i) in APPELS_IGNORES:
					continue
				# clé de dictionnaire ("cle": valeur) : pas un texte
				if i + 1 < len(toks) and toks[i + 1][1] == ":" and (i == 0 or toks[i - 1][1] in ("{", ",", "nl") or toks[i - 1][0] == "nl"):
					continue
				# comparaison == "texte" : un identifiant
				if i > 0 and toks[i - 1][1] in ("==", "!=", "in"):
					continue
				ops, a, b = span_operands(toks, i)
				modele = None
				if len(ops) > 1 and any(len(o) == 1 and o[0][0] == "str" for o in ops):
					parts = []
					for o in ops:
						if len(o) == 1 and o[0][0] == "str":
							parts.append(decode(o[0][1]).replace("%", "%%") if False else decode(o[0][1]))
						else:
							parts.append("\x00")
					# marquer les littéraux consommés
					for j in range(a, b + 1):
						if toks[j][0] == "str":
							vus.add(j)
					modele = "".join(parts).replace("\x00", "%s")
					# une chaîne déjà au format % garde ses %d ; ailleurs, %s seul
					texte = modele
				else:
					texte = decode(v)
				for ligne in texte.split("\n"):
					if not est_texte(ligne.replace("%s", "")):
						continue
					if ligne.strip() == "":
						continue
					cles.setdefault(ligne, set()).add(rel)
	return cles


if __name__ == "__main__":
	cles = extraire()
	if len(sys.argv) > 2 and sys.argv[1] == "--manquants":
		code = sys.argv[2]
		connus = json.load(open(os.path.join(RACINE, "assets", "langues", code + ".json"), encoding="utf8"))["textes"]
		manque = sorted((sorted(cles[c])[0], c) for c in cles if c not in connus and not c.startswith("<"))
		sortie = os.path.join(RACINE, "tools", "langue", "manquants_%s.txt" % code)
		with open(sortie, "w", encoding="utf8") as f:
			for fichier, c in manque:
				f.write("%s | %s\n" % (fichier, c.replace("\n", "\\n")))
		print(len(manque), "textes sans traduction →", sortie)
		sys.exit(0)
	sortie = os.path.join(RACINE, "tools", "langue", "textes_fr.json")
	liste = sorted(cles)
	json.dump([{"fr": c, "f": sorted(cles[c])[0]} for c in liste], open(sortie, "w", encoding="utf8"), ensure_ascii=False, indent=0)
	print(len(liste), "textes,", sum(len(c) for c in liste), "caractères")
