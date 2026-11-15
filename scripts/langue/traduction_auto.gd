class_name TraductionAuto
extends Translation
## Traduction de tout le jeu sans toucher au code des panneaux.
##
## Le jeu est écrit en français : chaque texte français est sa propre clé.
## Godot traduit tout seul les textes des Label, Button, infobulles, listes et
## onglets (auto_translate) en appelant _get_message. Cette classe trouve la
## traduction :
##  1. texte exact (« Fermer (Échap) ») ;
##  2. modèle avec des trous : « Population : %d » reconnaît « Population : 1250 » ;
##     les trous %s sont traduits à leur tour (« Bâtiment : %s » + « Boulangerie ») ;
##  3. sinon ligne par ligne, puis morceau par morceau (« A · B », « A : B »),
##     en gardant les puces, icônes et ponctuation autour.
## Un texte inconnu reste en français. Les résultats sont mis en cache.
##
## Fichier : res://assets/langues/<code>.json = {"textes": {"fr": "traduction"}}.
## Dans la traduction, les trous gardent l'ordre du français ; %2$s prend le
## 2e trou pour changer l'ordre des mots.

const CACHE_MAX := 40000

## Texte français → traduction (textes sans trou, et modèles tels quels).
var textes := {}
## Modèles rangés par début (« p:Pop ») ou fin (« s:ts. ») du texte, et le reste.
var _modeles := {}
var _general: Array = []
var _cache := {}
var _re_spec: RegEx
var _re_cible: RegEx
var _re_bords: RegEx
var _re_milliers: RegEx
var _re_decimale: RegEx
var _re_nombre: RegEx
var _re_date: RegEx
var nb_modeles := 0


func _init() -> void:
	_re_spec = RegEx.create_from_string("%(?:%|[-+ 0#]*\\d*(?:\\.\\d+)?[sdifxXc])")
	_re_cible = RegEx.create_from_string("%(?:%|(\\d+)\\$)?[-+ 0#]*\\d*(?:\\.\\d+)?[sdifxXc]|%%")
	# Ce qui entoure le texte : puces, icônes, flèches, espaces ; ponctuation finale.
	_re_bords = RegEx.create_from_string("^([^\\p{L}\\d«(%]*)(.*?)([\\s:.…!?»)▴▾▸◂▲▼]*)$")
	_re_milliers = RegEx.create_from_string("(\\d)[   ](?=\\d{3}(?!\\d))")
	# virgule décimale (1 ou 2 chiffres après : « 1,500 » reste un nombre anglais)
	_re_decimale = RegEx.create_from_string("(\\d),(\\d{1,2})(?!\\d)")
	# « 10 juin 2026 », « dim. 3 mai » : jour et mois traduits un par un.
	_re_date = RegEx.create_from_string("(?:(lun\\.|mar\\.|mer\\.|jeu\\.|ven\\.|sam\\.|dim\\.) )?(\\d{1,2}) (janvier|janv\\.|février|févr\\.|mars|avril|avr\\.|mai|juin|juillet|juil\\.|août|septembre|sept\\.|octobre|oct\\.|novembre|nov\\.|décembre|déc\\.)(?![\\p{L}])")
	_re_nombre = RegEx.create_from_string("^[-−+]?\\d[\\d   ]*(?:,\\d+)?$")


## Charge un fichier de langue. Renvoie false s'il manque.
func charger(chemin: String, code: String) -> bool:
	locale = code
	var f := FileAccess.open(chemin, FileAccess.READ)
	if f == null:
		return false
	var data = JSON.parse_string(f.get_as_text())
	if not data is Dictionary:
		return false
	ajouter(data.get("textes", {}))
	return true


## Ajoute des traductions (texte français → traduction).
func ajouter(d: Dictionary) -> void:
	for k in d:
		var fr := String(k)
		var en := String(d[k])
		if en == "":
			continue
		textes[fr] = en
		if fr.contains("%"):
			_ajouter_modele(fr, en)
	_cache.clear()
	for b in _modeles:
		(_modeles[b] as Array).sort_custom(func(a, c): return a[3] > c[3])
	_general.sort_custom(func(a, c): return a[3] > c[3])


func _ajouter_modele(fr: String, en: String) -> void:
	var ms := _re_spec.search_all(fr)
	var types := PackedStringArray()
	var motif := "^"
	var pos := 0
	var litteral := ""
	var prefixe := ""
	var premier := true
	for m in ms:
		var lit := fr.substr(pos, m.get_start() - pos)
		motif += _echapper(lit)
		litteral += lit
		if premier:
			prefixe = litteral
		pos = m.get_end()
		var spec := m.get_string()
		if spec == "%%":
			motif += "%"
			litteral += "%"
			if premier:
				prefixe = litteral
			continue
		premier = false
		var t := spec.right(1)
		types.append(t)
		if t == "d" or t == "i" or t == "x" or t == "X":
			motif += "([-−]?\\d+)"
		elif t == "f":
			motif += "([-−]?\\d+(?:[.,]\\d+)?)"
		else:
			motif += "(.*?)"
	if types.is_empty():
		return  # seulement des %% : un texte simple
	var fin := fr.substr(pos)
	motif += _echapper(fin) + "$"
	litteral += fin
	if RegEx.create_from_string("\\p{L}").search_all(litteral).size() < 4:
		return  # « %s de %s » : trop vague, seulement en texte exact
	var re := RegEx.create_from_string(motif)
	if not re.is_valid():
		return
	var entree := [re, en, types, litteral.length()]
	nb_modeles += 1
	if prefixe.length() >= 3:
		_ranger("p:" + prefixe.left(3), entree)
	elif prefixe.length() == 2:
		_ranger("p2:" + prefixe, entree)
	elif fin.length() >= 3:
		_ranger("s:" + fin.right(3), entree)
	elif fin.length() == 2:
		_ranger("s2:" + fin, entree)
	else:
		_general.append(entree)


func _ranger(cle: String, entree: Array) -> void:
	if not _modeles.has(cle):
		_modeles[cle] = []
	(_modeles[cle] as Array).append(entree)


static func _echapper(s: String) -> String:
	var out := ""
	for c in s:
		if "\\^$.|?*+()[]{}".contains(c):
			out += "\\" + c
		else:
			out += c
	return out


func _get_message(src_message: StringName, _context: StringName) -> StringName:
	var s := String(src_message)
	if s.is_empty():
		return &""
	var r := traduire(s)
	return StringName(r) if r != s else &""


func _get_plural_message(src_message: StringName, _src_plural: StringName, _n: int, _context: StringName) -> StringName:
	return _get_message(src_message, &"")


## Traduction d'un texte (le texte lui-même s'il est inconnu).
func traduire(s: String) -> String:
	if s.is_empty():
		return s
	var c = _cache.get(s)
	if c != null:
		return c
	# Les nombres à la française (« 1 234,5 ») passent à l'anglaise partout.
	var r := _nombres_texte(_traduire(s, 0))
	if _cache.size() > CACHE_MAX:
		_cache.clear()
	_cache[s] = r
	return r


func _traduire(s: String, prof: int) -> String:
	var e = textes.get(s)
	if e != null:
		return e
	if prof > 6 or s.length() < 2:
		return s
	if s.contains("\n"):
		var lignes := s.split("\n")
		for i in lignes.size():
			lignes[i] = _traduire(lignes[i], prof + 1)
		return "\n".join(lignes)
	var m := _par_modele(s, prof)
	if m != "":
		return m
	# Majuscules : « BUDGET » → « Budget »
	var maj := s.to_upper()
	if s == maj and s != s.to_lower() and s.length() > 1:
		var cap := s.left(1) + s.substr(1).to_lower()
		var t := _traduire(cap, prof + 1)
		if t != cap:
			return t.to_upper()
	# Minuscule au début (texte placé au milieu d'une phrase)
	var p := s.left(1)
	if p != p.to_upper():
		var cap2 := p.to_upper() + s.substr(1)
		var e2 = textes.get(cap2)
		if e2 != null:
			var en := String(e2)
			# garder la majuscule des noms propres et des sigles (« GPL », « I »)
			if en.length() > 1 and en.substr(1, 1) == en.substr(1, 1).to_lower():
				return en.left(1).to_lower() + en.substr(1)
			return en
	# Bords : puces, icônes, ponctuation finale
	var b := _re_bords.search(s)
	if b != null and (b.get_string(1) != "" or b.get_string(3) != "") and b.get_string(2) != "":
		var coeur := b.get_string(2)
		var t2 := _traduire(coeur, prof + 1)
		if t2 != coeur:
			var fin := b.get_string(3)
			if fin.begins_with(" :"):
				fin = fin.substr(1)  # pas d'espace avant les deux-points en anglais
			return b.get_string(1) + t2 + fin
	# Morceaux : on coupe aux séparateurs, en regroupant les morceaux voisins qui
	# forment ensemble un texte connu (« … · %d camion%s en livraison »).
	for sep in [" · ", " — ", " – ", " | ", " ; ", " : ", " / ", ", "]:
		if s.contains(sep):
			var parts := s.split(sep)
			var out := PackedStringArray()
			var change := false
			var i := 0
			while i < parts.size():
				var fait := false
				for j in range(mini(parts.size() - 1, i + 5), i, -1):
					var bloc: String = sep.join(parts.slice(i, j + 1))
					var tb = textes.get(bloc)
					var t4: String = String(tb) if tb != null else _par_modele(bloc, prof + 1)
					if t4 != "" and t4 != bloc:
						out.append(t4)
						change = true
						i = j + 1
						fait = true
						break
				if fait:
					continue
				var t3 := _traduire(parts[i], prof + 1)
				if t3 != parts[i]:
					change = true
				out.append(t3)
				i += 1
			if change:
				return sep.join(out) if sep != " : " else ": ".join(out)
	return _nombres(s) if _re_nombre.search(s) else s


func _par_modele(s: String, prof: int) -> String:
	var listes := []
	if s.length() >= 3:
		listes.append(_modeles.get("p:" + s.left(3), []))
		listes.append(_modeles.get("s:" + s.right(3), []))
	listes.append(_modeles.get("p2:" + s.left(2), []))
	listes.append(_modeles.get("s2:" + s.right(2), []))
	listes.append(_general)
	var meilleur: Array = []
	var trous: RegExMatch = null
	for l in listes:
		for entree in l:
			if meilleur.size() > 0 and int(entree[3]) <= int(meilleur[3]):
				break
			var m: RegExMatch = (entree[0] as RegEx).search(s)
			if m != null:
				meilleur = entree
				trous = m
				break
	if trous == null:
		return ""
	var valeurs := PackedStringArray()
	var types: PackedStringArray = meilleur[2]
	for i in types.size():
		var v := trous.get_string(i + 1)
		if types[i] == "s":
			var t := _traduire(v, prof + 1) if v != "" else v
			v = _nombres(v) if t == v else t
		else:
			v = _nombres(v)
		valeurs.append(v)
	return _remplir(String(meilleur[1]), valeurs)


## Met les valeurs dans les trous de la traduction (%s, %d, %.1f… ou %2$s).
func _remplir(modele: String, valeurs: PackedStringArray) -> String:
	var out := ""
	var pos := 0
	var n := 0
	for m in _re_cible.search_all(modele):
		out += modele.substr(pos, m.get_start() - pos)
		pos = m.get_end()
		if m.get_string() == "%%":
			out += "%"
			continue
		var idx := n
		if m.get_string(1) != "":
			idx = int(m.get_string(1)) - 1
		else:
			n += 1
		out += valeurs[idx] if idx >= 0 and idx < valeurs.size() else ""
	return out + modele.substr(pos)


## Chiffres à l'anglaise : « 1 234,5 » → « 1,234.5 ».
## Nombres d'un texte entier : virgule décimale et espaces des milliers.
func _nombres_texte(v: String) -> String:
	if v.contains(" ") and _re_date.search(v) != null:
		var out := ""
		var pos := 0
		for m in _re_date.search_all(v):
			out += v.substr(pos, m.get_start() - pos)
			var jour := m.get_string(1)
			if jour != "":
				out += String(textes.get(jour, jour)) + " "
			out += m.get_string(2) + " " + String(textes.get(m.get_string(3), m.get_string(3)))
			pos = m.get_end()
		v = out + v.substr(pos)
	if not v.contains(",") and not v.contains(" ") and not v.contains(" ") and not v.contains(" "):
		return v
	v = _re_decimale.sub(v, "$1.$2", true)
	return _re_milliers.sub(v, "$1,", true)


func _nombres(v: String) -> String:
	v = _re_decimale.sub(v, "$1.$2", true)
	v = _re_milliers.sub(v, "$1,", true)
	return v.replace("−", "-")
