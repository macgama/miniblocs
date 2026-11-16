class_name ImmobilierTypes
extends RefCounted
## Bâtiments de l'immobilier (catégorie « Logement » du panneau Construire) :
##
## - Logements sociaux, datés : cité ouvrière (1853, comme à Mulhouse), immeuble
##   HBM en briques (1894, loi Siegfried), barre HLM (1955), résidence sociale
##   (1985). Loyer modéré (Immobilier.LOYER_SOCIAL) ; la ville touche les loyers
##   et paie l'entretien (budget).
## - Résidence de standing (1960) : ce que bâtissent les promoteurs dans les
##   quartiers chers. Loyer plus élevé (Immobilier.STANDING).
## - Baraques d'un bidonville : jamais dans le catalogue. Elles apparaissent
##   toutes seules quand des familles ne trouvent aucun logement abordable
##   (Immobilier). Pas de loyer, pas de taxe, niveau de vie « Précaire ».
##
## Même format que BuildingCatalog, plus un champ "immo" qui dit le rôle :
## "social", "standing" ou "precaire".

const CATEGORY := "logement"
const ROAD := ["route"]

const TYPES := {
	"cite_ouvriere": {"name": "Cité ouvrière", "w": 34, "d": 16, "access": ROAD, "logements": 8,
		"cost": 1_300_000, "annee": 1853, "immo": "social",
		"desc": "Huit maisons ouvrières en bande avec leur jardinet, comme la cité de Mulhouse (1853). Loyer modéré : la ville touche les loyers et paie l'entretien."},
	"hbm": {"name": "Immeuble HBM", "w": 24, "d": 16, "access": ROAD, "logements": 30,
		"cost": 4_500_000, "annee": 1894, "immo": "social",
		"desc": "Habitations à bon marché en briques rouges (loi de 1894) : trente logements sains, une cour, des loyers modérés."},
	"hlm_barre": {"name": "Barre HLM", "w": 62, "d": 14, "access": ROAD, "logements": 120,
		"cost": 12_000_000, "annee": 1955, "immo": "social",
		"desc": "Grande barre des années de la reconstruction : 120 logements à loyer modéré, vite bâtis. Elle résorbe un bidonville d'un coup."},
	"residence_sociale": {"name": "Résidence sociale", "w": 26, "d": 18, "access": ROAD, "logements": 36,
		"cost": 6_500_000, "annee": 1985, "immo": "social",
		"desc": "Petit immeuble de logements aidés, balcons et local vélos : 36 logements à loyer modéré, mélangés au reste du quartier."},
	"residence_standing": {"name": "Résidence de standing", "w": 28, "d": 22, "access": ROAD, "logements": 24,
		"cost": 9_000_000, "annee": 1960, "immo": "standing",
		"desc": "Résidence fermée, piscine et gardien : 24 grands appartements aux loyers élevés. Les promoteurs en bâtissent dans les quartiers chers."},
	"baraques": {"name": "Baraques (bidonville)", "w": 16, "d": 16, "access": [], "logements": 4,
		"cost": 15_000, "annee": 0, "immo": "precaire", "cache": true, "sans_chantier": true,
		"desc": "Cabanes de planches, de tôle et de bâches, sans eau ni égouts. Des familles sans logement abordable vivent là."},
}
const ORDER := ["cite_ouvriere", "hbm", "hlm_barre", "residence_sociale", "residence_standing", "baraques"]


static func entries() -> Dictionary:
	var out := {}
	for id in ORDER:
		var t: Dictionary = TYPES[id].duplicate()
		t["cat"] = CATEGORY
		t["region"] = "monde"
		t["era"] = "moderne"
		t["style"] = ""
		out[id] = t
	return out


## Rôle immobilier d'un type ("social", "standing", "precaire" ou "").
static func role(type_id: String) -> String:
	return String(BuildingCatalog.get_type(BuildingCatalog.base_of(type_id)).get("immo", ""))


## Types de logement social déjà inventés à l'époque de la partie, du plus récent au plus ancien.
static func sociaux_disponibles() -> Array:
	var out := []
	for id in ["residence_sociale", "hlm_barre", "hbm", "cite_ouvriere"]:
		if Epoques.batiment_disponible(id):
			out.append(id)
	return out


# --- Modèles low-poly --------------------------------------------------------------------

const BRIQUE := Color("a4553b")
const BRIQUE_C := Color("c0704f")
const CREPI := Color("e6dccb")
const BETON := Color("d2cec5")
const BETON_F := Color("a9a59c")
const VITRE := Color("33495e")
const PORTE := Color("6b4a33")
const TUILE := Color("9c4a32")
const ARDOISE := Color("55606b")
const HERBE := Color("6aa84f")
const TERRE := Color("8a7458")
const EAU := Color("4fb3d9")
const TOLES := [Color("8d99ae"), Color("a57f60"), Color("6c7a89"), Color("b0a48a"), Color("7d8f69"), Color("9e6b5a")]
const BACHES := [Color("3a7bd5"), Color("d64545"), Color("e9c46a"), Color("4caf50")]
const PLANCHE := Color("8b6b4a")


static func build(k: BlocMesh, id: String, t: Dictionary) -> void:
	var w := float(t.w)
	var d := float(t.d)
	match id:
		"cite_ouvriere":
			k.plate(0, 0, w, d, HERBE)
			# Huit maisons mitoyennes, façade sur −Z, jardinets derrière.
			for i in 8:
				var x := -w / 2.0 + 2.1 + i * 3.75
				var col := CREPI if i % 2 == 0 else Color("efe3c8")
				k.box(x, 0, -2.5, 3.7, 5.2, 7.0, col)
				k.box(x, 0, -6.05, 1.0, 2.1, 0.1, PORTE)
				k.windows_row(x + 0.9, -6.05, 1.0, 1.2, 1, 0.8, 1.1, VITRE)
				k.windows_row(x, -6.05, 2.6, 3.4, 2, 0.8, 1.0, VITRE)
				k.box(x, 0, 4.6, 0.15, 0.9, 6.6, Color("9c6b45"))
				k.box(x + 1.2, 5.2, -1.0, 0.5, 1.6, 0.5, Color("8c4a3a"))
			k.gable(0, 5.2, -2.5, w - 1.2, 7.6, 2.6, TUILE)
			for i in 3:
				k.tree(-w / 2.0 + 6.0 + i * 11.0, 6.0, 0.6)
		"hbm":
			k.plate(0, 0, w, d, BETON_F)
			k.box(0, 0, 0, w - 2.0, 18.5, d - 2.0, BRIQUE)
			# Bandeaux clairs et soubassement.
			k.box(0, 0, 0, w - 1.8, 1.2, d - 1.8, BETON)
			for f in 5:
				k.box(0, 3.4 + f * 3.0, 0, w - 1.8, 0.25, d - 1.8, BRIQUE_C)
			k.window_bands(0, 0, w - 2.0, d - 2.0, 1.4, 6, 2.9, VITRE)
			k.box(0, 0, -(d - 2.0) / 2.0 - 0.05, 2.6, 2.8, 0.2, PORTE)
			k.hip(0, 18.5, 0, w - 1.4, d - 1.4, 3.2, ARDOISE)
			k.box(-6.0, 20.0, 2.0, 0.8, 2.6, 0.8, BRIQUE)
			k.box(6.0, 20.0, 2.0, 0.8, 2.6, 0.8, BRIQUE)
		"hlm_barre":
			k.plate(0, 0, w, d, BETON_F)
			k.box(0, 0, 0, w - 2.0, 30.0, d - 2.0, BETON)
			k.window_bands(0, 0, w - 2.0, d - 2.0, 0.6, 10, 2.9, VITRE)
			# Joints des panneaux préfabriqués.
			for i in 7:
				k.box(-w / 2.0 + 1.0 + (i + 1) * (w - 2.0) / 8.0, 0, 0, 0.18, 30.0, d - 1.8, BETON_F)
			for i in 3:
				k.box(-18.0 + i * 18.0, 0, -(d - 2.0) / 2.0 - 0.05, 2.4, 2.6, 0.2, PORTE)
			k.box(0, 30.0, 0, w - 1.6, 0.6, d - 1.6, BETON_F)
			k.box(-20.0, 30.6, 0, 4.0, 2.4, 4.0, BETON)
			k.box(20.0, 30.6, 0, 4.0, 2.4, 4.0, BETON)
		"residence_sociale":
			k.plate(0, 0, w, d, HERBE)
			k.box(0, 0, 0, w - 4.0, 15.0, d - 4.0, Color("f0e6d6"))
			k.box(-(w - 4.0) / 4.0, 0, 0, (w - 4.0) / 2.0 + 0.1, 15.0, d - 3.9, Color("e9a46a"))
			k.window_bands(0, 0, w - 4.0, d - 4.0, 0.8, 5, 2.9, VITRE)
			for f in 4:
				for i in 4:
					k.box(-9.0 + i * 6.0, 3.6 + f * 2.9, -(d - 4.0) / 2.0 - 0.7, 3.4, 0.15, 1.4, BETON_F)
			k.box(0, 0, -(d - 4.0) / 2.0 - 0.05, 2.4, 2.6, 0.2, PORTE)
			k.box(0, 15.0, 0, w - 3.6, 0.4, d - 3.6, BETON_F)
			k.box(w / 2.0 - 3.0, 0, -d / 2.0 + 2.2, 3.4, 2.2, 2.6, Color("8d99ae"))
			k.tree(-w / 2.0 + 2.0, d / 2.0 - 2.0, 0.7)
			k.tree(w / 2.0 - 2.0, d / 2.0 - 2.0, 0.7)
		"residence_standing":
			k.plate(0, 0, w, d, HERBE)
			k.box(0, 0, 3.0, w - 4.0, 13.0, 11.0, Color("f5f1ea"))
			k.window_bands(0, 3.0, w - 4.0, 11.0, 0.6, 4, 3.2, VITRE)
			# Grands balcons vitrés et attique en retrait.
			for f in 3:
				k.box(0, 3.4 + f * 3.2, -2.9, w - 4.0, 0.2, 1.8, Color("dcd6cc"))
				k.box(0, 3.6 + f * 3.2, -3.75, w - 4.0, 0.9, 0.08, Color("9fc5d8"))
			k.box(0, 13.0, 3.5, w - 9.0, 3.0, 8.0, Color("ebe5da"))
			k.windows_row(0, -0.55, w - 10.0, 13.4, 5, 2.2, 2.0, VITRE)
			# Piscine, grille et loge du gardien devant.
			k.plate(-5.0, -7.5, 9.0, 4.0, Color("e9e2d4"), 0.0, 0.12)
			k.plate(-5.0, -7.5, 7.6, 2.8, EAU, 0.0, 0.16)
			k.box(0, 0, -d / 2.0 + 0.2, w - 0.6, 1.6, 0.12, Color("3b3b3b"))
			k.box(w / 2.0 - 4.0, 0, -d / 2.0 + 2.2, 3.0, 2.6, 2.6, Color("f5f1ea"))
			k.tree(-w / 2.0 + 2.0, -d / 2.0 + 3.0, 0.8)
			k.tree(5.0, -7.5, 0.6)
		"baraques":
			_baraques(k, w, d)


## Bidonville : des cabanes de guingois, tôles de couleurs, bâches et linge.
static func _baraques(k: BlocMesh, w: float, d: float) -> void:
	k.plate(0, 0, w, d, TERRE)
	var v := int(k.variant)
	var spots := [[-4.5, -4.0, 4.2, 3.6], [1.2, -4.6, 3.6, 3.2], [5.0, -3.0, 3.0, 4.2],
		[-4.0, 2.2, 3.4, 4.0], [0.8, 1.8, 4.4, 3.0], [5.2, 4.2, 3.0, 3.0], [-0.6, 5.8, 3.2, 2.4]]
	for i in spots.size():
		if (i + v) % 7 == 6:
			continue
		var s: Array = spots[i]
		var h := 2.0 + float((i * 7 + v * 3) % 5) * 0.18
		var col: Color = TOLES[(i + v) % TOLES.size()]
		k.box(float(s[0]), 0, float(s[1]), float(s[2]), h, float(s[3]), PLANCHE if (i + v) % 3 == 0 else col)
		# Toit de tôle à une pente, qui déborde un peu.
		k.gable(float(s[0]), h, float(s[1]), float(s[2]) + 0.5, float(s[3]) + 0.5, 0.35, col.darkened(0.15))
		k.box(float(s[0]) - float(s[2]) * 0.2, 0, float(s[1]) - float(s[3]) / 2.0 - 0.03, 0.8, 1.8, 0.06, Color("3d2b1f"))
		if (i + v) % 2 == 0:
			k.box(float(s[0]) + 0.4, h + 0.35, float(s[1]), float(s[2]) * 0.6, 0.06, float(s[3]) * 0.6, BACHES[(i + v) % BACHES.size()])
	# Fil à linge, bidons, feu de bois.
	k.box(0, 1.7, -1.0, 7.0, 0.04, 0.04, Color("dddddd"))
	for i in 4:
		k.box(-2.5 + i * 1.6, 1.15, -1.0, 0.7, 0.55, 0.05, BACHES[(i + v) % BACHES.size()].lightened(0.3))
	k.cylinder(-6.6, 0, 6.6, 0.35, 0.35, 0.9, 8, Color("2f5d8a"))
	k.cylinder(-5.8, 0, 6.9, 0.35, 0.35, 0.9, 8, Color("8a2f2f"))
	k.box(3.0, 0, -0.6, 0.9, 0.25, 0.9, Color("4a4a4a"))
