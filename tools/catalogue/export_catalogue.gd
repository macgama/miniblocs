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
	var avec_images := images(tout, abs_dir)
	_ecrit(abs_dir.path_join("catalogue.md"), markdown(tout))
	_ecrit(abs_dir.path_join("catalogue.json"), JSON.stringify(avec_images, "\t"))
	_ecrit(abs_dir.path_join("catalogue.html"), html(avec_images))
	_ecrit(abs_dir.path_join("dates-ajoutees.md"), dates_ajoutees(tout))
	print("Catalogue : %d objets exportés dans %s" % [tout.size(), abs_dir])
	quit()


## Copie des entrées avec leurs images (img/index.json, écrit par
## tools/catalogue/images_catalogue.gd) : "v" vignette, "evo" chantier → usure,
## "var" variantes, "sty" styles ; chemins relatifs à la page.
static func images(tout: Array, abs_dir: String) -> Array:
	var idx := {}
	var chemin := abs_dir.path_join("img/index.json")
	if FileAccess.file_exists(chemin):
		var j = JSON.parse_string(FileAccess.get_file_as_string(chemin))
		if j is Dictionary:
			idx = j
	var out := []
	var n := 0
	for e: Dictionary in tout:
		var c := e.duplicate()
		var im: Dictionary = idx.get("%s/%s" % [e.fam, e.id], {})
		for k in ["v", "evo", "var", "sty", "pixel"]:
			if not im.has(k):
				continue
			var v = im[k]
			if v is String:
				v = "img/" + v
			elif v is Dictionary:
				v = (v as Dictionary).duplicate()
				v["f"] = "img/" + String(v.f)
			c[k] = v
		if c.has("v"):
			n += 1
		out.append(c)
	print("Images : %d objets illustrés sur %d" % [n, tout.size()])
	return out


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
:root { --fond: #f6f4ef; --carte: #ffffff; --texte: #1f2a24; --doux: #5f6b64; --trait: #ddd8cc; --accent: #2f7d5b; --avenir: #b0573a; --scene: #e4ebee; }
@media (prefers-color-scheme: dark) { :root { --fond: #17201b; --carte: #212c26; --texte: #e8efe9; --doux: #9db0a5; --trait: #33413a; --accent: #6fcf9f; --avenir: #ef9a7a; --scene: #2c3a40; } }
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
main { padding: 8px 16px 40px; max-width: 1280px; margin: 0 auto; }
h2 { font-size: 16px; margin: 22px 0 8px; }
.grille { display: grid; grid-template-columns: repeat(auto-fill, minmax(148px, 1fr)); gap: 10px; }
.carte { background: var(--carte); border: 1px solid var(--trait); border-radius: 10px; padding: 8px; cursor: pointer; text-align: left; font: inherit; color: inherit; display: flex; flex-direction: column; gap: 4px; min-width: 0; }
.carte:hover, .carte:focus-visible { border-color: var(--accent); outline: none; }
.vig { width: 100%; aspect-ratio: 1; background: var(--scene); border-radius: 7px; display: grid; place-items: center; overflow: hidden; }
.vig img { width: 100%; height: 100%; object-fit: contain; }
.vig img.px { image-rendering: pixelated; }
.vig .sans { color: var(--doux); font-size: 12px; padding: 6px; text-align: center; }
.carte .n { font-size: 13px; font-weight: 600; line-height: 1.25; overflow-wrap: anywhere; }
.carte .a { font-size: 12px; color: var(--doux); font-variant-numeric: tabular-nums; }
.carte.avenir { opacity: .55; }
.carte.avenir .a { color: var(--avenir); font-weight: 600; }
.pastilles { display: flex; gap: 4px; flex-wrap: wrap; }
.pastilles span { font-size: 10.5px; padding: 1px 6px; border-radius: 99px; background: var(--fond); border: 1px solid var(--trait); color: var(--doux); }
table { width: 100%; border-collapse: collapse; background: var(--carte); border: 1px solid var(--trait); border-radius: 8px; overflow: hidden; }
th, td { text-align: left; padding: 5px 8px; border-bottom: 1px solid var(--trait); vertical-align: middle; font-size: 13px; }
th { color: var(--doux); font-weight: 600; }
td.m { width: 52px; padding: 3px; }
td.m img { width: 46px; height: 46px; object-fit: contain; background: var(--scene); border-radius: 5px; display: block; }
tr.l { cursor: pointer; }
tr.l:hover td { background: var(--fond); }
td.a { font-variant-numeric: tabular-nums; white-space: nowrap; }
tr.avenir td { color: var(--doux); }
tr.avenir td.a { color: var(--avenir); font-weight: 600; }
td.e { color: var(--doux); }
.g { color: var(--doux); font-size: 12px; }
@media (max-width: 700px) { td.i, th.i, td.e, th.e { display: none; } }
dialog { border: 1px solid var(--trait); border-radius: 14px; background: var(--carte); color: var(--texte); padding: 0; width: min(980px, calc(100vw - 24px)); max-height: calc(100vh - 32px); }
dialog::backdrop { background: rgba(10, 16, 13, .55); }
.fiche { padding: 18px 20px 22px; overflow: auto; max-height: calc(100vh - 34px); }
.tete { display: flex; gap: 16px; align-items: flex-start; }
.tete .vig { width: 180px; flex: none; }
.tete h3 { margin: 0 0 4px; font-size: 20px; }
.tete p { margin: 2px 0; }
.fermer { margin-left: auto; font: inherit; font-size: 20px; background: none; border: 0; color: var(--doux); cursor: pointer; padding: 0 4px; }
.fiche h4 { font-size: 14px; margin: 18px 0 8px; color: var(--doux); font-weight: 600; }
.frise { display: flex; flex-wrap: wrap; gap: 6px; padding-bottom: 6px; }
.etape { flex: none; width: 128px; text-align: center; font-size: 12px; color: var(--doux); }
.etape .img { width: 128px; height: 128px; border-radius: 8px; background-color: var(--scene); background-repeat: no-repeat; }
.etape .fl { color: var(--accent); }
.lignee { display: flex; gap: 6px; overflow-x: auto; align-items: stretch; padding-bottom: 6px; }
.lignee .carte { width: 128px; flex: none; }
.lignee .carte.ici { border-color: var(--accent); border-width: 2px; }
@media (max-width: 600px) { .tete { flex-direction: column; } .tete .vig { width: 140px; } }
</style>
</head>
<body>
<header>
<h1>Catalogue MiniBlocs : tout ce qui se construit, daté et en images</h1>
<div class="barre">
<input type="search" id="q" placeholder="Chercher (moulin, tram, looping…)">
<select id="fam"><option value="">Toutes les familles</option></select>
<select id="etat"><option value="tout">Tout</option><option value="dispo">Disponible à cette année</option><option value="avenir">Pas encore inventé</option></select>
<select id="vue"><option value="galerie">Galerie</option><option value="liste">Liste</option></select>
<label class="annee">Partie en <input type="range" id="an" min="1800" max="2040" step="1" value="2026"><b id="anv">2026</b></label>
</div>
<div id="resume"></div>
</header>
<main id="liste"></main>
<dialog id="dlg"><div class="fiche" id="fiche"></div></dialog>
<script>
const D = __DONNEES__;
const $ = (id) => document.getElementById(id);
for (const f of D.familles) { const o = document.createElement("option"); o.value = f.id; o.textContent = f.nom; $("fam").appendChild(o); }
const PAR = {};
for (const e of D.objets) PAR[e.fam + "/" + e.id] = e;
const txt = (y) => y <= 0 ? "toujours" : String(y);
const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({"&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;"}[c]));
const cle = (e) => esc(e.fam + "/" + e.id);
const vig = (e) => e.v ? `<img loading="lazy" src="${esc(e.v)}" alt="" class="${e.pixel ? "px" : ""}">` : `<span class="sans">pas d'image</span>`;
function pastilles(e) {
  const p = [];
  if (e.evo) p.push(e.fam === "batiments" ? "chantier → niveaux" : "époques");
  if (e.var) p.push(e.var.n + " variantes");
  if (e.sty) p.push(e.sty.n + " styles");
  if (e.lignee) p.push("lignée " + e.lignee.length);
  return p.length ? `<div class="pastilles">${p.map((x) => `<span>${esc(x)}</span>`).join("")}</div>` : "";
}
function carte(e, an, ici) {
  const ok = e.annee <= an;
  return `<button class="carte ${ok ? "" : "avenir"} ${ici ? "ici" : ""}" data-k="${cle(e)}"><div class="vig">${vig(e)}</div><div class="n">${esc(e.nom)}</div><div class="a">${ok ? txt(e.annee) : "arrive en " + e.annee}</div>${ici === undefined ? pastilles(e) : ""}</button>`;
}
function rendre() {
  const q = $("q").value.trim().toLowerCase().split(/\\s+/).filter(Boolean);
  const fam = $("fam").value, etat = $("etat").value, an = +$("an").value, vue = $("vue").value;
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
    html += `<h2>${esc(f.nom)} (${lignes.length})</h2>`;
    if (vue === "galerie") {
      let grp = null;
      html += `<div class="grille">`;
      for (const e of lignes) { n++; if (e.annee <= an) dispo++; html += carte(e, an); }
      html += `</div>`;
    } else {
      html += `<table><tr><th></th><th>Nom</th><th>Année</th><th class="i">Détails</th><th class="e">Évolutions</th></tr>`;
      for (const e of lignes) {
        const ok = e.annee <= an; n++; if (ok) dispo++;
        html += `<tr class="l ${ok ? "" : "avenir"}" data-k="${cle(e)}"><td class="m">${e.v ? `<img loading="lazy" src="${esc(e.v)}" alt="">` : ""}</td><td>${esc(e.nom)}<div class="g">${esc(e.groupe)}</div></td><td class="a">${ok ? txt(e.annee) : "arrive en " + e.annee}</td><td class="i">${esc(e.info)}</td><td class="e">${esc(e.evol)}</td></tr>`;
      }
      html += "</table>";
    }
  }
  $("liste").innerHTML = html || "<p>Rien ne correspond.</p>";
  $("resume").textContent = `${n} objets affichés, dont ${dispo} déjà inventés en ${an} (${D.objets.length} au total). Clique sur un objet pour voir ses évolutions.`;
}
function frise(titre, fr) {
  if (!fr) return "";
  const W = 128;
  let h = `<h4>${esc(titre)}</h4><div class="frise">`;
  fr.l.forEach((lab, i) => {
    h += `<div class="etape"><div class="img" style="background-image:url('${esc(fr.f)}');background-size:${fr.n * W}px ${W}px;background-position:${-i * W}px 0"></div>${esc(lab)}</div>`;
  });
  return h + `</div>`;
}
function ouvrir(k) {
  const e = PAR[k]; if (!e) return;
  const an = +$("an").value, ok = e.annee <= an;
  let h = `<div class="tete"><div class="vig">${vig(e)}</div><div><h3>${esc(e.nom)}</h3>`;
  h += `<p class="g">${esc(D.familles.find((f) => f.id === e.fam)?.nom || e.fam)} · ${esc(e.groupe)}</p>`;
  h += `<p><b>${ok ? (e.annee > 0 ? "Depuis " + e.annee : "De tout temps") : "Arrive en " + e.annee}</b></p>`;
  if (e.info) h += `<p>${esc(e.info)}</p>`;
  if (e.evol) h += `<p class="g">${esc(e.evol)}</p>`;
  h += `</div><button class="fermer" aria-label="Fermer" onclick="dlg.close()">✕</button></div>`;
  h += frise(e.fam === "batiments" ? "Du chantier à la vieillesse" : "Selon l'époque", e.evo);
  h += frise("Variantes de façade", e.var);
  h += frise("Le même meuble dans les styles de chaque époque", e.sty);
  if (e.lignee) {
    h += `<h4>Même rôle selon l'époque</h4><div class="lignee">`;
    for (const id of e.lignee) { const x = PAR[e.fam + "/" + id]; if (x) h += carte(x, an, id === e.id); }
    h += `</div>`;
  }
  $("fiche").innerHTML = h;
  if (!$("dlg").open) $("dlg").showModal();
  $("fiche").scrollTop = 0;
}
document.addEventListener("click", (ev) => {
  const t = ev.target.closest("[data-k]");
  if (t) ouvrir(t.dataset.k);
  else if (ev.target === $("dlg")) $("dlg").close();
});
const dlg = $("dlg");
for (const id of ["q", "fam", "etat", "an", "vue"]) $(id).addEventListener("input", rendre);
rendre();
</script>
</body>
</html>
"""
