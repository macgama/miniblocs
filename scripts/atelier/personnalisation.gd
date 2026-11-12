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


## Un bâtiment du catalogue se personnalise-t-il (couleurs au moins) ?
static func can_customize(type_id: String) -> bool:
	return BuildingCatalog.get_type(type_id).has("arch")


## Sa forme (toit, étages) se règle-t-elle ?
static func can_shape(type_id: String) -> bool:
	var t := BuildingCatalog.get_type(type_id)
	return t.has("arch") and String(t.arch) in SHAPED


static func base_floors(type_id: String) -> int:
	var t := BuildingCatalog.get_type(type_id)
	if not t.has("arch") or not Styles.STYLES.has(String(t.get("style", ""))):
		return 1
	return StyleBuilder.floors_of(Styles.STYLES[t.style], String(t.arch))


static func max_floors(type_id: String) -> int:
	var t := BuildingCatalog.get_type(type_id)
	return maxi(base_floors(type_id), int(MAX_FLOORS.get(String(t.get("arch", "")), 4)))


static func base_roof(type_id: String) -> String:
	var t := BuildingCatalog.get_type(type_id)
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
	return out


## Couleurs proposées pour une clé : celles du style d'abord, puis le nuancier.
static func swatches(type_id: String, key: String) -> Array:
	var t := BuildingCatalog.get_type(type_id)
	var out: Array = []
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
	var p := palette(type_id, variant)
	return Color(p.get(String(COLORS[key][1]), Color.WHITE))


## Palette d'origine (style et variante) d'un type du catalogue.
static func palette(type_id: String, variant: int) -> Dictionary:
	var t := BuildingCatalog.get_type(type_id)
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
