extends SceneTree
## Exporte le catalogue daté de tout ce qui se construit (CatalogueJeu) :
##   docs/catalogue/catalogue.md      lisible sur GitHub, famille par famille
##   docs/catalogue/catalogue.html    page autonome : recherche, famille, curseur d'année
##   docs/catalogue/catalogue.json    les mêmes données, pour d'autres outils
##   docs/catalogue/dates-ajoutees.md les années données avec le catalogue (EpoquesObjets)
## Usage : godot --headless --path . --script res://tools/catalogue/export_catalogue.gd [-- --dossier <chemin>]

const PERIODES := [[0, 0, "De tout temps (avant 1800)"], [1800, 1849, "1800 – 1849"], [1850, 1899, "1850 – 1899"],
	[1900, 1949, "1900 – 1949"], [1950, 1989, "1950 – 1989"], [1990, 2029, "1990 – 2029"], [2030, 99999, "Futur"]]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var dossier := "res://docs/catalogue"
	var args := OS.get_cmdline_user_args()
	var i := args.find("--dossier")
	if i >= 0 and i + 1 < args.size():
		dossier = args[i + 1]
	var abs_dir := ProjectSettings.globalize_path(dossier)
	DirAccess.make_dir_recursive_absolute(abs_dir)
	var tout := CatalogueJeu.entrees(true)
	_ecrit(abs_dir.path_join("catalogue.md"), markdown(tout))
	_ecrit(abs_dir.path_join("catalogue.json"), JSON.stringify(tout, "\t"))
	_ecrit(abs_dir.path_join("catalogue.html"), html(tout))
	_ecrit(abs_dir.path_join("dates-ajoutees.md"), dates_ajoutees(tout))
	print("Catalogue : %d objets exportés dans %s" % [tout.size(), abs_dir])
	quit()


func _ecrit(chemin: String, texte: String) -> void:
	var f := FileAccess.open(chemin, FileAccess.WRITE)
	if f == null:
		push_error("Impossible d'écrire " + chemin)
		return
	f.store_string(texte)
	f.close()


static func _cell(s: String) -> String:
	return s.replace("|", "\\|").replace("\n", " ")


static func _periode(y: int) -> int:
	for i in PERIODES.size():
		if y >= int(PERIODES[i][0]) and y <= int(PERIODES[i][1]):
			return i
	return 0


static func _tri(a: Dictionary, b: Dictionary) -> bool:
	if String(a.groupe) != String(b.groupe):
		return String(a.groupe) < String(b.groupe)
	if int(a.annee) != int(b.annee):
		return int(a.annee) < int(b.annee)
	return String(a.nom).naturalnocasecmp_to(String(b.nom)) < 0


static func markdown(tout: Array) -> String:
	var l := PackedStringArray()
	l.append("# Catalogue de MiniBlocs : tout ce qui se construit, daté")
	l.append("")
	l.append("Fichier généré par `tools/catalogue/export_catalogue.gd` à partir des données du jeu : ne pas le modifier à la main.")
	l.append("Le même catalogue s'ouvre en jeu avec **Maj+F1** (ou menu Infos → Catalogue), et en page web avec [catalogue.html](catalogue.html).")
	l.append("")
	l.append("« toujours » : déjà là en 1800, au début de la plus ancienne partie possible. Une partie qui commence en 1850")
	l.append("n'a que ce qui est daté 1850 ou avant ; le reste arrive à sa date (« Arrive en 1882 »).")
	l.append("")
	# Résumé : familles × périodes.
	var entete := "| Famille | Total |"
	var sep := "|---|---:|"
	for p in PERIODES:
		entete += " %s |" % String(p[2])
		sep += "---:|"
	l.append("## En chiffres")
	l.append("")
	l.append(entete)
	l.append(sep)
	var total := 0
	for f in CatalogueJeu.FAMILLES:
		var es := CatalogueJeu.de_famille(String(f[0]))
		if es.is_empty():
			continue
		var n := []
		n.resize(PERIODES.size())
		n.fill(0)
		for e: Dictionary in es:
			n[_periode(int(e.annee))] += 1
		var ligne := "| [%s](#%s) | %d |" % [f[1], String(f[0]), es.size()]
		for v in n:
			ligne += " %d |" % int(v)
		l.append(ligne)
		total += es.size()
	l.append("| **Total** | **%d** | |" % total)
	l.append("")
	# Sources des années.
	l.append("### D'où viennent les années")
	l.append("")
	var src := {}
	for e: Dictionary in tout:
		src[String(e.source)] = int(src.get(String(e.source), 0)) + 1
	for s in CatalogueJeu.SOURCES:
		if src.has(s):
			l.append("- %s : %d" % [CatalogueJeu.SOURCES[s], int(src[s])])
	l.append("")
	l.append("Évolutions : un bâtiment qui accueille du monde ou produit s'agrandit en 3 niveaux (+50 %, puis ×2) et se rénove ;")
	l.append("beaucoup ont des variantes de façade ; ceux qui jouent le même rôle à différentes époques (école, hôpital, pompiers,")
	l.append("police, moulin…) sont reliés en « lignée ». Véhicules et machines agricoles : le modèle de chaque époque.")
	l.append("")
	for f in CatalogueJeu.FAMILLES:
		var es := CatalogueJeu.de_famille(String(f[0]))
		if es.is_empty():
			continue
		es.sort_custom(_tri)
		l.append('<a id="%s"></a>' % String(f[0]))
		l.append("")
		l.append("## %s (%d)" % [f[1], es.size()])
		var groupe := ""
		for e: Dictionary in es:
			if String(e.groupe) != groupe:
				groupe = String(e.groupe)
				l.append("")
				l.append("### %s" % groupe)
				l.append("")
				l.append("| Nom | Année | Détails | Évolutions |")
				l.append("|---|---:|---|---|")
			l.append("| %s | %s | %s | %s |" % [_cell(String(e.nom)), CatalogueJeu.texte_annee(int(e.annee)), _cell(String(e.info)), _cell(String(e.evol))])
		l.append("")
	return "\n".join(l) + "\n"


static func dates_ajoutees(tout: Array) -> String:
	var l := PackedStringArray()
	l.append("# Années données avec le catalogue (16 novembre 2026)")
	l.append("")
	l.append("Ces objets n'avaient pas d'année à eux : ils prenaient celle de leur époque (« classique » = 1830, « moderne » = 1950)")
	l.append("ou étaient de tout temps. Ils ont maintenant une date historique (invention ou diffusion en Europe),")
	l.append("dans `scripts/epoques/epoques_objets.gd` (classe EpoquesObjets). « toujours » : déjà là en 1800.")
	l.append("")
	for f in CatalogueJeu.FAMILLES:
		var es := []
		for e: Dictionary in CatalogueJeu.de_famille(String(f[0])):
			if String(e.source) == "ajoutee":
				es.append(e)
		if es.is_empty():
			continue
		es.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a.annee) > int(b.annee) or int(a.annee) == int(b.annee) and String(a.nom) < String(b.nom))
		var dates := []
		var toujours := []
		for e: Dictionary in es:
			if int(e.annee) > 0:
				dates.append("%s (%d)" % [e.nom, int(e.annee)])
			else:
				toujours.append(String(e.nom))
		l.append("## %s : %d" % [f[1], es.size()])
		l.append("")
		if not dates.is_empty():
			l.append("**Datés** : " + ", ".join(dates) + ".")
			l.append("")
		if not toujours.is_empty():
			l.append("**De tout temps** : " + ", ".join(toujours) + ".")
			l.append("")
	return "\n".join(l) + "\n"


static func html(tout: Array) -> String:
	var fams := []
	for f in CatalogueJeu.FAMILLES:
		fams.append({"id": f[0], "nom": f[1]})
	var data := JSON.stringify({"familles": fams, "objets": tout}).replace("</", "<\\/")
	return HTML_MODELE.replace("__DONNEES__", data)


const HTML_MODELE := """<!doctype html>
<html lang="fr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Catalogue MiniBlocs</title>
<style>
:root { --fond: #f6f4ef; --carte: #ffffff; --texte: #1f2a24; --doux: #5f6b64; --trait: #ddd8cc; --accent: #2f7d5b; --avenir: #b0573a; }
@media (prefers-color-scheme: dark) { :root { --fond: #17201b; --carte: #212c26; --texte: #e8efe9; --doux: #9db0a5; --trait: #33413a; --accent: #6fcf9f; --avenir: #ef9a7a; } }
* { box-sizing: border-box; }
body { margin: 0; background: var(--fond); color: var(--texte); font: 15px/1.45 system-ui, -apple-system, "Segoe UI", sans-serif; }
header { position: sticky; top: 0; background: var(--fond); border-bottom: 1px solid var(--trait); padding: 14px 16px 10px; z-index: 2; }
h1 { font-size: 20px; margin: 0 0 8px; }
.barre { display: flex; flex-wrap: wrap; gap: 8px; align-items: center; }
input[type=search], select { font: inherit; padding: 6px 8px; border: 1px solid var(--trait); border-radius: 6px; background: var(--carte); color: var(--texte); }
input[type=search] { flex: 1 1 220px; }
.annee { display: flex; align-items: center; gap: 8px; flex: 1 1 320px; }
.annee input { flex: 1; }
.annee b { min-width: 3.2em; text-align: right; font-variant-numeric: tabular-nums; }
#resume { color: var(--doux); font-size: 13px; margin-top: 6px; }
main { padding: 8px 16px 40px; max-width: 1200px; margin: 0 auto; }
h2 { font-size: 16px; margin: 22px 0 6px; }
table { width: 100%; border-collapse: collapse; background: var(--carte); border: 1px solid var(--trait); border-radius: 8px; overflow: hidden; }
th, td { text-align: left; padding: 5px 8px; border-bottom: 1px solid var(--trait); vertical-align: top; font-size: 13px; }
th { color: var(--doux); font-weight: 600; }
td.a { font-variant-numeric: tabular-nums; white-space: nowrap; }
tr.avenir td { color: var(--doux); }
tr.avenir td.a { color: var(--avenir); font-weight: 600; }
td.e { color: var(--doux); }
.g { color: var(--doux); font-size: 12px; }
@media (max-width: 700px) { td.i, th.i, td.e, th.e { display: none; } }
</style>
</head>
<body>
<header>
<h1>Catalogue MiniBlocs : tout ce qui se construit, daté</h1>
<div class="barre">
<input type="search" id="q" placeholder="Chercher (moulin, tram, looping…)">
<select id="fam"><option value="">Toutes les familles</option></select>
<select id="etat"><option value="tout">Tout</option><option value="dispo">Disponible à cette année</option><option value="avenir">Pas encore inventé</option></select>
<label class="annee">Partie en <input type="range" id="an" min="1800" max="2040" step="1" value="2026"><b id="anv">2026</b></label>
</div>
<div id="resume"></div>
</header>
<main id="liste"></main>
<script>
const D = __DONNEES__;
const $ = (id) => document.getElementById(id);
for (const f of D.familles) { const o = document.createElement("option"); o.value = f.id; o.textContent = f.nom; $("fam").appendChild(o); }
const txt = (y) => y <= 0 ? "toujours" : String(y);
const esc = (s) => String(s).replace(/[&<>]/g, (c) => ({"&": "&amp;", "<": "&lt;", ">": "&gt;"}[c]));
function rendre() {
  const q = $("q").value.trim().toLowerCase().split(/\\s+/).filter(Boolean);
  const fam = $("fam").value, etat = $("etat").value, an = +$("an").value;
  $("anv").textContent = an;
  let n = 0, dispo = 0, html = "";
  for (const f of D.familles) {
    if (fam && f.id !== fam) continue;
    const lignes = D.objets.filter((e) => e.fam === f.id).filter((e) => {
      const ok = e.annee <= an;
      if (etat === "dispo" && !ok || etat === "avenir" && ok) return false;
      const h = (e.nom + " " + e.groupe + " " + e.info + " " + e.id).toLowerCase();
      return q.every((m) => h.includes(m));
    }).sort((a, b) => a.groupe.localeCompare(b.groupe) || a.annee - b.annee || a.nom.localeCompare(b.nom));
    if (!lignes.length) continue;
    html += `<h2>${esc(f.nom)} (${lignes.length})</h2><table><tr><th>Nom</th><th>Année</th><th class="i">Détails</th><th class="e">Évolutions</th></tr>`;
    for (const e of lignes) {
      const ok = e.annee <= an; n++; if (ok) dispo++;
      html += `<tr class="${ok ? "" : "avenir"}"><td>${esc(e.nom)}<div class="g">${esc(e.groupe)}</div></td><td class="a">${ok ? txt(e.annee) : "arrive en " + e.annee}</td><td class="i">${esc(e.info)}</td><td class="e">${esc(e.evol)}</td></tr>`;
    }
    html += "</table>";
  }
  $("liste").innerHTML = html || "<p>Rien ne correspond.</p>";
  $("resume").textContent = `${n} objets affichés, dont ${dispo} déjà inventés en ${an} (${D.objets.length} au total).`;
}
for (const id of ["q", "fam", "etat", "an"]) $(id).addEventListener("input", rendre);
rendre();
</script>
</body>
</html>
"""
