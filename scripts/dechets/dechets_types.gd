class_name DechetsTypes
extends RefCounted
## Bâtiments de la propreté (catégorie « Déchets » du panneau Construire) :
## collecte, décharge, incinération, tri, recyclage, déchèterie et compost.
##
## Même format que BuildingCatalog, plus un champ "dechets" qui dit le rôle du
## bâtiment pour le système Dechets :
## - "depot" : garage des camions-bennes ("bennes" : nombre de camions) ;
## - "decharge" : enfouissement ("capacite" : tonnes avant d'être pleine) ;
## - "decharge_fermee" : ancienne décharge recouverte en colline verte ;
## - "incinerateur" : brûle les ordures ("t_jour"), produit de l'électricité ;
## - "tri" : centre de tri des recyclables et du verre ("t_jour") ;
## - "recyclage" : usine qui refait du papier, du plastique et de l'acier
##   (une usine ordinaire de l'économie, voir le champ "prod") ;
## - "decheterie" : les habitants y apportent encombrants et déchets verts
##   ("rayon" : distance d'où ils viennent) ;
## - "compost" : plateforme de compostage des déchets verts ("t_jour").
## Chiffres : ordres de grandeur français (un incinérateur moyen brûle
## 300 t par jour, une benne à ordures emporte environ 8 t).

const CATEGORY := "dechets"
const ROAD := ["route"]

const TYPES := {
	"depot_collecte": {"name": "Dépôt de collecte", "w": 36, "d": 28, "access": ROAD, "emplois": 15, "cost": 1_800_000,
		"dechets": {"role": "depot", "bennes": 4},
		"metiers": [["eboueur", 12], ["mecanicien", 1], ["agent_public", 2]],
		"desc": "Garage de 4 camions-bennes et vestiaires des éboueurs. Les tournées partent d'ici le matin."},
	"decharge": {"name": "Décharge (centre d'enfouissement)", "w": 90, "d": 90, "access": ROAD, "emplois": 6, "cost": 3_000_000,
		"dechets": {"role": "decharge", "capacite": 120_000.0},
		"metiers": [["conducteur_engins", 4], ["agent_public", 2]],
		"desc": "Casiers étanches où l'on enfouit les ordures. Bon marché, mais elle pollue l'eau et sent mauvais ; une fois pleine, on la recouvre."},
	"decharge_fermee": {"name": "Ancienne décharge recouverte", "w": 90, "d": 90, "access": [], "cost": 1_500_000,
		"dechets": {"role": "decharge_fermee"}, "cache": true,
		"desc": "Colline verte plantée d'herbe et d'arbustes, avec ses puits de biogaz."},
	"usine_incineration": {"name": "Usine d'incinération", "w": 52, "d": 40, "access": ROAD, "emplois": 40, "cost": 45_000_000,
		"dechets": {"role": "incinerateur", "t_jour": 300.0, "mwh_t": 0.6},
		"metiers": [["operateur", 28], ["ingenieur", 3], ["conducteur_engins", 4], ["agent_public", 5]],
		"desc": "Brûle 300 t d'ordures par jour et en tire de l'électricité (environ 7 MW). Pollue l'air."},
	"centre_tri": {"name": "Centre de tri", "w": 44, "d": 34, "access": ROAD, "emplois": 40, "cost": 8_000_000,
		"dechets": {"role": "tri", "t_jour": 60.0},
		"prod": {"kind": "transformation", "externe": true, "in": {}, "out": {"balles_tri": 40.0, "verre": 15.0}},
		"metiers": [["agent_tri", 30], ["conducteur_engins", 4], ["chauffeur", 3], ["cadre", 1]],
		"desc": "Tapis, trieurs et presses : recyclables en balles (papier, plastique, métal) et verre. Sans lui, personne ne trie."},
	"usine_recyclage": {"name": "Usine de recyclage", "w": 44, "d": 34, "access": ROAD, "emplois": 35, "cost": 10_000_000,
		"dechets": {"role": "recyclage"},
		"prod": {"kind": "transformation", "in": {"balles_tri": 30.0}, "out": {"papier": 14.0, "plastique": 6.0, "acier": 4.0}},
		"metiers": [["operateur", 20], ["ouvrier", 10], ["chauffeur", 3], ["ingenieur", 1]],
		"desc": "Balles de tri → papier et carton, granulés de plastique, acier. Livrés aux usines de la ville."},
	"decheterie": {"name": "Déchèterie", "w": 40, "d": 30, "access": ROAD, "emplois": 3, "cost": 800_000,
		"dechets": {"role": "decheterie", "rayon": 4000.0},
		"metiers": [["gardien_decheterie", 3]],
		"desc": "Quai et bennes : encombrants, gravats, déchets verts. Les habitants à moins de 4 km trient mieux."},
	"compost": {"name": "Plateforme de compostage", "w": 40, "d": 40, "access": ROAD, "emplois": 4, "cost": 600_000,
		"dechets": {"role": "compost", "t_jour": 30.0},
		"metiers": [["conducteur_engins", 2], ["agriculteur", 2]],
		"desc": "Andains de déchets verts et de biodéchets retournés au chargeur : du compost pour les champs."},
}
const ORDER := ["depot_collecte", "decheterie", "centre_tri", "usine_recyclage", "compost", "decharge", "usine_incineration", "decharge_fermee"]


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


## Bâtiments de la bible Blender qui jouent aussi un rôle pour les déchets.
const BIBLE := {"incinerateur": {"role": "incinerateur", "t_jour": 400.0, "mwh_t": 0.6}}


## Rôle d'un type de bâtiment pour les déchets ("" : aucun).
static func role_of(type_id: String) -> String:
	return String(spec_of(type_id).get("role", ""))


static func spec_of(type_id: String) -> Dictionary:
	if BIBLE.has(type_id):
		return BIBLE[type_id]
	return BuildingCatalog.get_type(type_id).get("dechets", {})


# --- Modèles low-poly --------------------------------------------------------------------

const BETON := Color("b9b6ae")
const BETON_C := Color("d6d3cc")
const TOLE := Color("8d99ae")
const TOLE_V := Color("2a9d8f")
const TERRE := Color("8a7458")
const GRAVIER := Color("c2b8a3")
const HERBE := Color("6aa84f")
const VITRE := Color("33495e")
const VERT_BOM := Color("43aa8b")
const ORDURES := [Color("3d3d3d"), Color("8d8d8d"), Color("2b2d42"), Color("e9c46a"), Color("4a6fa5"), Color("6d6875")]
const BALLES := [Color("d4a373"), Color("4895ef"), Color("adb5bd"), Color("e9c46a"), Color("90be6d")]


static func build(k: BlocMesh, id: String, t: Dictionary) -> void:
	var w := float(t.w)
	var d := float(t.d)
	match id:
		"depot_collecte":
			k.plate(0, 0, w, d, BETON)
			# Hall des bennes : quatre portes sur la façade (−Z).
			k.box(-4, 0, 2, 24, 7.5, 18, TOLE)
			k.gable(-4, 7.5, 2, 24.6, 18.6, 1.6, Color("5b5f66"))
			for i in 4:
				k.box(-13.5 + i * 6.3, 0, -7.05, 4.6, 4.8, 0.1, Color("e9ecef"))
			k.box(-4, 7.0, -7.1, 12.0, 0.9, 0.1, VERT_BOM)
			# Bureaux et vestiaires.
			k.box(13, 0, 4, 8, 6.5, 12, BETON_C)
			k.windows_row(13, -2.05, 7.0, 3.6, 3, 1.2, 1.2, VITRE)
			k.box(13, 6.5, 4, 8.4, 0.4, 12.4, Color("6c757d"))
			# Deux bennes garées dans la cour.
			for x in [-10.0, 2.0]:
				_benne(k, x, -11.0)
			# Bacs roulants alignés.
			for i in 6:
				k.box(10.0 + i * 1.1, 0, -10.5, 0.8, 1.1, 0.8, VERT_BOM if i % 2 == 0 else Color("ffd166"))
		"decharge":
			k.plate(0, 0, w, d, TERRE)
			# Butte d'ordures : couches décalées, terre de couverture et casier ouvert.
			for i in 6:
				var s := 72.0 - i * 10.0
				var col: Color = Color("7d6b5d") if i % 2 == 0 else Color("6b645c")
				k.plate(4.0 + i * 0.8, 8.0 - i * 1.2, s, s * 0.9, col.darkened(0.03 * i), float(i) * 1.6, 1.6)
			# Casier en cours de remplissage, au sommet : ordures en vrac, sacs de couleur.
			k.plate(8, 2, 18, 14, Color("4a4844"), 9.6, 0.2)
			for i in 40:
				var a := float(i) * 2.39996
				var r := 1.0 + float(i % 8) * 0.9
				var c: Color = ORDURES[i % ORDURES.size()]
				k.box(8 + cos(a) * r * 1.1, 9.8, 2 + sin(a) * r * 0.8, 0.9 + float(i % 3) * 0.3, 0.45, 0.8, c)
			# Compacteur à pieds de mouton, pont-bascule, poste de garde, clôture.
			k.box(2, 9.8, 6, 3.2, 2.4, 5.0, Color("f4a261"))
			k.box(2, 12.2, 7, 2.0, 1.2, 2.0, VITRE)
			k.box(-30, 0, -40, 4, 3.2, 5, BETON_C)
			k.plate(-20, -40, 4, 12, Color("5c677d"), 0.0, 0.15)
			for s in [-1.0, 1.0]:
				k.box(s * (w / 2 - 0.2), 0, 0, 0.2, 2.2, d, Color("495057"))
				k.box(0, 0, s * (d / 2 - 0.2), w if s > 0 else w * 0.7, 2.2, 0.2, Color("495057"))
			# Bassin de lixiviats.
			k.plate(32, -32, 18, 14, Color("5a6b3b"), 0.0, 0.1)
		"decharge_fermee":
			k.plate(0, 0, w, d, HERBE)
			for i in 6:
				var s := 72.0 - i * 10.0
				k.plate(4.0 + i * 0.8, 8.0 - i * 1.2, s, s * 0.9, HERBE.lightened(0.025 * i), float(i) * 1.6, 1.6)
			for i in 16:
				var a := float(i) * 2.39996
				var r := 8.0 + float(i % 5) * 6.0
				k.tree(6 + cos(a) * r, 6 + sin(a) * r, 0.9 + float(i % 3) * 0.2, Color("40916c"))
			# Puits de biogaz et torchère.
			for i in 5:
				k.cylinder(-6 + i * 5.0, 9.6, 4, 0.25, 0.25, 1.4, 6, Color("adb5bd"))
			k.cylinder(-34, 0, -34, 0.5, 0.4, 7.0, 8, Color("6c757d"))
		"usine_incineration":
			k.plate(0, 0, w, d, BETON)
			# Fosse de réception, four-chaudière, traitement des fumées.
			k.box(-14, 0, 2, 20, 14, 30, Color("e9ecef"))
			k.box(-14, 14, 2, 20.4, 0.5, 30.4, TOLE_V)
			k.box(8, 0, 4, 20, 26, 22, Color("dee2e6"))
			k.hip(8, 26, 4, 20.6, 22.6, 3.0, Color("6c757d"))
			k.window_bands(8, 4, 20, 22, 4.0, 5, 4.5, VITRE)
			k.box(-14, 0, -13.05, 16, 6, 0.1, Color("495057"))
			# Cheminée de 60 m et ses bagues.
			k.cylinder(20, 0, 14, 1.8, 1.4, 60, 12, BETON_C)
			k.cylinder(20, 56, 14, 1.5, 1.5, 2.0, 12, Color("e63946"))
			k.cylinder(20, 50, 14, 1.55, 1.55, 1.0, 12, Color("f1faee"))
			# Aérocondenseurs.
			k.box(-14, 14.5, 14, 14, 3.0, 6, Color("8d99ae"))
		"centre_tri":
			k.plate(0, 0, w, d, BETON)
			k.box(-2, 0, 3, 34, 11, 26, Color("f1faee"))
			k.gable(-2, 11, 3, 34.6, 26.6, 2.2, TOLE_V)
			k.box(-2, 9.0, -10.05, 34, 1.0, 0.1, Color("ffd166"))
			for i in 3:
				k.box(-14 + i * 10.0, 0, -10.05, 5.5, 5.5, 0.1, Color("6c757d"))
			# Balles de tri empilées dans la cour.
			for i in 5:
				for j in 2:
					k.box(18.0, float(j) * 1.1, -12.0 + i * 1.6, 1.4, 1.1, 1.4, BALLES[(i + j) % BALLES.size()])
			# Convoyeur incliné vers la trémie.
			k.box(-20, 3.5, -12, 2.0, 0.4, 6.0, Color("495057"))
			k.box(-20, 0, -15, 4.0, 4.0, 3.0, Color("adb5bd"))
		"usine_recyclage":
			k.plate(0, 0, w, d, BETON)
			k.box(-4, 0, 3, 30, 12, 24, Color("dee2e6"))
			for i in 4:
				k.gable(-15 + i * 7.5, 12, 3, 7.5, 24.4, 2.4, Color("5b5f66"), false)
			k.box(-4, 0, -9.05, 8, 6, 0.1, Color("6c757d"))
			k.cylinder(15, 0, 10, 1.2, 1.0, 22, 10, Color("adb5bd"))
			# Silos de granulés et bobines de papier.
			for i in 3:
				k.cylinder(15, 0, -4 + i * 4.0, 1.6, 1.6, 9, 10, Color("90be6d").darkened(i * 0.1))
			for i in 4:
				k.cylinder(-16 + i * 2.6, 0, -13.5, 1.0, 1.0, 1.8, 10, Color("e9e2c8"))
		"decheterie":
			k.plate(0, 0, w, d, GRAVIER)
			# Quai surélevé et bennes en contrebas.
			k.box(0, 0, 4, 34, 1.8, 8, BETON_C)
			k.box(0, 1.8, 0.2, 34, 1.0, 0.2, Color("e9c46a"))
			var cols := [Color("2a9d8f"), Color("e76f51"), Color("457b9d"), Color("6a994e"), Color("8d99ae")]
			for i in 5:
				var x := -13.6 + i * 6.8
				k.box(x, 0, -2.4, 5.6, 1.8, 3.6, cols[i])
				k.box(x, 1.4, -2.4, 4.8, 0.5, 2.8, ORDURES[i % ORDURES.size()] if i != 3 else Color("588157"))
			k.box(-14, 0, 12, 6, 3.0, 4, Color("f1faee"))
			k.box(-14, 3.0, 12, 6.4, 0.3, 4.4, TOLE_V)
		"compost":
			k.plate(0, 0, w, d, TERRE)
			for i in 5:
				var z := -14.0 + i * 7.0
				k.pyramid(-3, 0, z, 26, 4.0, 2.4, Color("6f4e37").lightened(0.04 * i))
			k.box(15, 0, -14, 3.0, 2.4, 4.5, Color("f4a261"))
			k.box(15, 2.4, -13.5, 2.0, 1.2, 2.0, VITRE)
			k.pyramid(15, 0, 8, 8, 8, 3.0, Color("588157"))
		_:
			k.plate(0, 0, w, d, BETON)
			k.box(0, 0, 0, w * 0.6, 6, d * 0.6, TOLE)


## Petite benne à ordures garée (décor du dépôt).
static func _benne(k: BlocMesh, x: float, z: float) -> void:
	k.box(x, 0.4, z - 3.0, 2.4, 2.6, 2.0, Color("f1faee"))
	k.box(x, 1.6, z - 3.9, 2.2, 0.9, 0.1, VITRE)
	k.box(x, 0.6, z + 1.0, 2.5, 3.0, 6.0, VERT_BOM)
	k.box(x, 0.6, z + 4.1, 2.3, 2.6, 0.3, Color("495057"))
