class_name Personnalisation
extends RefCounted
## Personnalisation d'un bâtiment du catalogue posé : couleurs (murs, toit,
## boiseries, volets, porte, vitres), forme du toit, nombre d'étages et pente.
## Rangée dans le bâtiment (b.perso), dans la sauvegarde et dans les modèles
## de la banque. Les clés absentes gardent la valeur du style.

## Couleurs personnalisables : clé -> [nom, clé de la palette de StyleBuilder].
const COLORS := {
	"mur": ["Murs", "wall"],
	"toit_c": ["Toit", "roof"],
	"boiseries": ["Boiseries, corniches", "trim"],
	"volets": ["Volets", "volet"],
	"porte": ["Porte", "door"],
	"vitres": ["Vitres", "glass"],
}
const COLOR_ORDER := ["mur", "toit_c", "boiseries", "volets", "porte", "vitres"]

## Formes de toit proposées (celles que sait faire StyleBuilder._roof).
const ROOFS := {
	"gable": "Deux pans", "hip": "Quatre pans", "flat": "Toit terrasse", "mansard": "Mansarde",
	"curved": "Bords relevés (Asie)", "shed": "Appentis", "thatch": "Chaume",
}
const ROOF_ORDER := ["gable", "hip", "flat", "mansard", "curved", "shed", "thatch"]

## Archétypes dont la forme (toit, étages) se règle : ceux du volume générique.
const SHAPED := ["maison", "grande_maison", "rangee", "immeuble", "boutique", "restaurant", "atelier", "bureaux",
	"ecole", "hopital", "tour", "grand_magasin"]
## Étages au plus par archétype.
const MAX_FLOORS := {"maison": 4, "grande_maison": 4, "rangee": 6, "immeuble": 16, "boutique": 4, "restaurant": 3,
	"atelier": 3, "bureaux": 20, "ecole": 4, "hopital": 8, "tour": 50, "grand_magasin": 6}

## Teintes ajoutées à celles du style dans le nuancier.
const EXTRA := ["f2ede1", "e8d8b0", "d9a066", "c2593f", "8c3b2e", "5a6b7d", "3d5a80", "2f6b4f", "6b8f3a",
	"e9c46a", "f4a261", "b5b5b5", "5a5a5a", "2a2a2a", "ffffff"]


## Modèles classiques MiniBlocs (dessinés en code, sans style) qu'on peut
## refaire dans un style du monde : type -> archétype de StyleBuilder. Tant que
## la personnalisation n'a pas de clé "style", le modèle d'origine reste.
const CLASSIQUES := {"maison": "maison", "villa": "grande_maison", "immeuble": "immeuble", "tour_habitation": "tour",
	"boulangerie": "boutique", "superette": "boutique", "bureaux": "bureaux", "atelier": "atelier", "cafe": "restaurant",
	"ecole": "ecole"}
## Styles essayés dans l'ordre quand on change une couleur d'un modèle classique
## sans avoir choisi de style (le premier qui connaît l'archétype).
const STYLES_DEFAUT := ["mediterraneen", "banlieue_us", "haussmann", "international", "verre"]
## Couleurs d'origine des modèles classiques, reprises par le style par défaut.
const CLASSIQUE_COULEURS := {"mur": "f1e6d2", "toit_c": "c8553d", "porte": "6b4a33", "vitres": "33495e"}


## Modèle classique qu'on peut refaire dans un style ?
static func is_classic(type_id: String) -> bool:
	var t := BuildingCatalog.get_type(type_id)
	return CLASSIQUES.has(type_id) and not t.has("arch") and not t.has("glb") and not t.has("modele") and not t.has("creation")


## Fiche du type telle que la personnalisation la dessine : un modèle classique
## avec un style choisi devient un bâtiment de ce style (archétype, style).
static func type_of(type_id: String, perso: Dictionary = {}) -> Dictionary:
	var t := BuildingCatalog.get_type(type_id)
	if not is_classic(type_id) or not Styles.STYLES.has(String(perso.get("style", ""))):
		return t
	var out := t.duplicate()
	out["arch"] = String(CLASSIQUES[type_id])
	out["style"] = String(perso.style)
	var s: Dictionary = Styles.STYLES[perso.style]
	out["region"] = String(s.get("region", ""))
	out["era"] = String(s.get("era", ""))
	return out


## Styles proposés pour un modèle classique (ceux qui connaissent son archétype).
static func styles_for(type_id: String) -> Array:
	if not is_classic(type_id):
		return []
	var arch := String(CLASSIQUES[type_id])
	var out := []
	for sid in Styles.STYLES:
		if arch in (Styles.STYLES[sid].get("archs", []) as Array):
			out.append(String(sid))
	return out


## Style mis d'office quand on change une couleur d'un modèle classique.
static func style_defaut(type_id: String) -> String:
	var ok := styles_for(type_id)
	for sid in STYLES_DEFAUT:
		if ok.has(sid):
			return String(sid)
	return String(ok[0]) if not ok.is_empty() else ""


## Personnalisation complétée pour un modèle classique : si on touche aux
## couleurs ou à la forme sans style, le style par défaut est posé avec les
## couleurs d'origine (le bâtiment reste proche de ce qu'il était).
static func completer(type_id: String, perso: Dictionary, force := false) -> Dictionary:
	if not is_classic(type_id) or (perso.is_empty() and not force) or perso.has("style"):
		return perso
	var sid := style_defaut(type_id)
	if sid == "":
		return perso
	var out := perso.duplicate()
	out["style"] = sid
	for k in CLASSIQUE_COULEURS:
		if not out.has(k):
			out[k] = CLASSIQUE_COULEURS[k]
	if not out.has("toit") and String(CLASSIQUES[type_id]) in ["maison", "grande_maison", "boutique", "restaurant", "atelier"]:
		out["toit"] = "gable"
	return out


## Un bâtiment du catalogue se personnalise-t-il (couleurs au moins) ?
## Les modèles faits en code (arch) et ceux modélisés dans Blender (glb), sauf
## les stades qui gardent leurs matériaux.
static func can_customize(type_id: String) -> bool:
	var t := BuildingCatalog.get_type(type_id)
	# Les modèles de l'atelier et les créations ont leur propre apparence.
	if t.has("modele") or t.has("creation"):
		return false
	if t.has("arch") or is_classic(type_id):
		return true
	return is_glb(type_id) and not BibleGlb.groupes(type_id).is_empty()


## Bâtiment modélisé dans Blender (couleurs seulement, la forme reste celle du modèle).
static func is_glb(type_id: String) -> bool:
	var t := BuildingCatalog.get_type(type_id)
	return t.has("glb") and not t.has("stade")


## Couleurs réglables de ce type, dans l'ordre du panneau.
static func color_keys(type_id: String) -> Array:
	if not is_glb(type_id):
		return COLOR_ORDER
	var g := BibleGlb.groupes(type_id)
	return COLOR_ORDER.filter(func(k: String) -> bool: return g.has(k))


## Nom affiché d'une couleur réglable.
static func color_label(type_id: String, key: String) -> String:
	if is_glb(type_id) and key == "volets":
		return "Volets, détails"
	if is_glb(type_id) and key == "boiseries":
		return "Encadrements, avant-toit"
	return String(COLORS[key][0])


## Sa forme (toit, étages) se règle-t-elle ?
static func can_shape(type_id: String, perso: Dictionary = {}) -> bool:
	if is_classic(type_id):
		return Styles.STYLES.has(String(perso.get("style", "")))
	var t := type_of(type_id, perso)
	return t.has("arch") and String(t.arch) in SHAPED


static func base_floors(type_id: String, perso: Dictionary = {}) -> int:
	if is_glb(type_id):
		return int(BibleGlb.volume(type_id).get("etages", 1))
	var t := type_of(type_id, completer(type_id, perso))
	if not t.has("arch") or not Styles.STYLES.has(String(t.get("style", ""))):
		return 1
	return StyleBuilder.floors_of(Styles.STYLES[t.style], String(t.arch))


static func max_floors(type_id: String, perso: Dictionary = {}) -> int:
	var t := type_of(type_id, completer(type_id, perso))
	return maxi(base_floors(type_id, perso), int(MAX_FLOORS.get(String(t.get("arch", "")), 4)))


static func base_roof(type_id: String, perso: Dictionary = {}) -> String:
	var t := type_of(type_id, perso)
	if not Styles.STYLES.has(String(t.get("style", ""))):
		return "gable"
	return String(Styles.STYLES[t.style].roof)


## Style modifié par la personnalisation (copie).
static func style_with(s: Dictionary, perso: Dictionary) -> Dictionary:
	var out := s.duplicate()
	if perso.has("toit") and ROOFS.has(String(perso.toit)):
		out["roof"] = String(perso.toit)
	if perso.has("etages"):
		out["perso_etages"] = clampi(int(perso.etages), 1, 90)
	return out


## Applique les couleurs choisies à la palette de StyleBuilder.
static func apply_palette(p: Dictionary, perso: Dictionary) -> void:
	for key in COLORS:
		if perso.has(key):
			p[String(COLORS[key][1])] = Color(String(perso[key]))
	if perso.has("pente"):
		p["pente"] = clampf(float(perso.pente), 0.4, 2.0)


## Copie propre (types JSON : nombres en float, couleurs en texte).
static func clean(d: Dictionary) -> Dictionary:
	var out := {}
	for key in COLORS:
		if d.has(key):
			out[key] = Color(String(d[key])).to_html(false)
	if d.has("toit") and ROOFS.has(String(d.toit)):
		out["toit"] = String(d.toit)
	if d.has("etages"):
		out["etages"] = clampi(int(d.etages), 1, 90)
	if d.has("pente"):
		out["pente"] = snappedf(clampf(float(d.pente), 0.4, 2.0), 0.05)
	if d.has("style") and Styles.STYLES.has(String(d.style)):
		out["style"] = String(d.style)
	return out


## Couleurs proposées pour une clé : celles du style d'abord, puis le nuancier.
static func swatches(type_id: String, key: String, perso: Dictionary = {}) -> Array:
	var t := type_of(type_id, completer(type_id, perso))
	var out: Array = []
	if is_glb(type_id):
		out.append(BibleGlb.couleur_cle(type_id, 0, key).to_html(false))
	var s: Dictionary = Styles.STYLES.get(String(t.get("style", "")), {})
	match key:
		"mur":
			out.append_array(s.get("walls", []))
		"toit_c":
			out.append_array(s.get("roofs", []))
		"boiseries":
			if s.has("trim"):
				out.append(s.trim)
		"volets":
			out.append_array(StyleKit.VOLETS.get(String(s.get("region", "europe")), StyleKit.VOLETS["europe"]))
		"vitres":
			out.append_array(["33495e", "6fa8c9", "2a3a4a", "a7c7d9"])
	for c in EXTRA:
		if out.size() >= 16:
			break
		out.append(c)
	var seen := {}
	var res: Array = []
	for c in out:
		var h := Color(String(c)).to_html(false)
		if not seen.has(h):
			seen[h] = true
			res.append(h)
	return res


## Couleur actuelle d'une clé (personnalisée, ou celle du modèle d'origine).
static func color_of(type_id: String, variant: int, perso: Dictionary, key: String) -> Color:
	if perso.has(key):
		return Color(String(perso[key]))
	if is_glb(type_id):
		return BibleGlb.couleur_cle(type_id, variant, key)
	if is_classic(type_id) and not perso.has("style"):
		return Color(String(CLASSIQUE_COULEURS.get(key, "f6f1e7")))
	var p := palette(type_id, variant, perso)
	return Color(p.get(String(COLORS[key][1]), Color.WHITE))


## Palette d'origine (style et variante) d'un type du catalogue.
static func palette(type_id: String, variant: int, perso: Dictionary = {}) -> Dictionary:
	var t := type_of(type_id, perso)
	if not Styles.STYLES.has(String(t.get("style", ""))):
		return {}
	var s: Dictionary = Styles.STYLES[t.style]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(t.style) + String(t.arch))
	var p := StyleBuilder._palette(s, rng)
	var k := BlocMesh.new()
	k.variant = variant
	StyleBuilder._variante(k, s, p, String(t.style), String(t.arch))
	return p


## Nom de la couleur la plus proche (étiquette de la banque de modèles).
const COLOR_NAMES := {
	"blanc": "f2f2f2", "crème": "efe3c6", "beige": "d8c3a0", "ocre": "d19a4a", "jaune": "e9c46a", "orange": "e07a3a",
	"rouge": "c2453a", "brique": "9c4a36", "rose": "e3a0a8", "brun": "6b4428", "vert": "5f8f4a", "bleu": "3d6fa8",
	"gris": "9a9a9a", "anthracite": "4a4a4a", "noir": "1e1e1e", "violet": "7d5aa0",
}


static func color_name(c: Color) -> String:
	var best := ""
	var bd := INF
	for n in COLOR_NAMES:
		var o := Color(String(COLOR_NAMES[n]))
		var dd := Vector3(c.r - o.r, c.g - o.g, c.b - o.b).length_squared()
		if dd < bd:
			bd = dd
			best = n
	return best


## Prix des travaux de façade pour passer de `avant` à `apres` (personnalisations)
## sur un bâtiment qui a coûté `prix` : peinture par couleur changée, toit, pente,
## étages en plus ou en moins, changement de style, de variante. Un minimum par
## poste (échafaudage, artisans). Le style posé d'office avec la première couleur
## n'est pas compté à part.
const COUT_COULEUR := 0.03
const COUT_TOIT := 0.10
const COUT_PENTE := 0.04
const COUT_ETAGE := 0.20
const COUT_STYLE := 0.25
const COUT_VARIANTE := 0.05
const COUT_MIN := 1_500


static func cout_travaux(type_id: String, avant: Dictionary, apres: Dictionary, prix: int, variante := false) -> int:
	# Un modèle classique sans style vaut son style par défaut aux couleurs d'origine.
	var a := completer(type_id, avant, true)
	var b := completer(type_id, apres, true)
	var p := float(maxi(prix, 20_000))
	var total := 0.0
	var poste := func(f: float) -> float: return maxf(p * f, COUT_MIN)
	var sa := String(a.get("style", ""))
	var sb := String(b.get("style", ""))
	if sa != sb:
		# Nouveau style : façade refaite, peinture et toit compris.
		total += poste.call(COUT_STYLE)
	else:
		for key in COLORS:
			if color_of(type_id, 0, a, key).to_html(false) != color_of(type_id, 0, b, key).to_html(false):
				total += poste.call(COUT_COULEUR)
		if String(a.get("toit", "")) != String(b.get("toit", "")):
			total += poste.call(COUT_TOIT)
		if absf(float(a.get("pente", 1.0)) - float(b.get("pente", 1.0))) > 0.01:
			total += poste.call(COUT_PENTE)
	var ea := int(a.get("etages", base_floors(type_id, a)))
	var eb := int(b.get("etages", base_floors(type_id, b)))
	if ea != eb:
		total += poste.call(COUT_ETAGE) * absi(eb - ea)
	if variante:
		total += poste.call(COUT_VARIANTE)
	return int(roundf(total / 100.0) * 100.0)
