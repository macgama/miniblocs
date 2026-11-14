class_name ParcThemes
extends RefCounted
## Décors à thème du parc (pirates, Far West, espace, contes, jungle,
## épouvante, mobilier du parc). Ce sont des décors comme les autres (touche
## G) : posés un par un, en rangée ou au pinceau, gommés, sauvegardés par
## DecorSystem. Ils sont dessinés ici, en formes simples, au lieu de venir de
## Blender : Decors les ajoute à son catalogue (entrées "proc").

const THEMES := [
	["theme_parc", "Parc : mobilier"],
	["theme_pirates", "Parc : pirates"],
	["theme_farwest", "Parc : Far West"],
	["theme_espace", "Parc : espace"],
	["theme_contes", "Parc : contes et château"],
	["theme_jungle", "Parc : jungle et temples"],
	["theme_epouvante", "Parc : épouvante"],
]

## id -> [nom, catégorie, taille [x, profondeur, hauteur]]
const PROPS := {
	"pt_lampadaire_guirlande": ["Lampadaire à guirlande", "theme_parc", [0.6, 0.6, 4.2]],
	"pt_poubelle_clown": ["Poubelle colorée", "theme_parc", [0.7, 0.7, 1.1]],
	"pt_banc_parc": ["Banc du parc", "theme_parc", [1.8, 0.7, 0.9]],
	"pt_jardiniere": ["Jardinière fleurie", "theme_parc", [2.0, 1.0, 0.9]],
	"pt_panneau_direction": ["Panneau directionnel", "theme_parc", [1.2, 0.3, 3.0]],
	"pt_mascotte": ["Statue de la mascotte", "theme_parc", [1.6, 1.6, 3.6]],
	"pt_arche_fleurs": ["Arche fleurie", "theme_parc", [4.0, 0.8, 3.6]],
	"pt_tonneau": ["Tonneau", "theme_pirates", [0.8, 0.8, 1.1]],
	"pt_coffre_tresor": ["Coffre au trésor", "theme_pirates", [1.2, 0.8, 1.0]],
	"pt_canon": ["Canon", "theme_pirates", [1.0, 2.4, 1.2]],
	"pt_ancre": ["Ancre", "theme_pirates", [1.6, 0.4, 2.4]],
	"pt_mat_pirate": ["Mât et drapeau pirate", "theme_pirates", [2.0, 0.4, 8.0]],
	"pt_rocher_crane": ["Rocher tête de mort", "theme_pirates", [4.0, 3.0, 4.0]],
	"pt_cactus": ["Cactus", "theme_farwest", [1.4, 0.6, 3.2]],
	"pt_chariot": ["Chariot bâché", "theme_farwest", [2.0, 4.0, 2.8]],
	"pt_facade_saloon": ["Façade de saloon", "theme_farwest", [8.0, 1.2, 7.0]],
	"pt_totem": ["Totem", "theme_farwest", [1.0, 1.0, 5.0]],
	"pt_poteau_attache": ["Barre d'attache", "theme_farwest", [3.0, 0.3, 1.2]],
	"pt_chateau_eau_western": ["Réservoir sur pilotis", "theme_farwest", [3.0, 3.0, 7.0]],
	"pt_fusee": ["Fusée", "theme_espace", [3.0, 3.0, 12.0]],
	"pt_soucoupe": ["Soucoupe volante", "theme_espace", [6.0, 6.0, 3.6]],
	"pt_radar": ["Antenne radar", "theme_espace", [3.0, 3.0, 5.0]],
	"pt_cristal": ["Cristaux géants", "theme_espace", [2.0, 2.0, 3.0]],
	"pt_robot": ["Robot", "theme_espace", [1.2, 0.8, 2.6]],
	"pt_planete": ["Planète à anneau", "theme_espace", [4.0, 4.0, 5.0]],
	"pt_tour_chateau": ["Tour de château", "theme_contes", [4.0, 4.0, 12.0]],
	"pt_porte_chateau": ["Porte de château", "theme_contes", [8.0, 2.0, 7.0]],
	"pt_champignon": ["Champignon géant", "theme_contes", [3.0, 3.0, 3.6]],
	"pt_citrouille_carrosse": ["Carrosse citrouille", "theme_contes", [2.4, 3.4, 2.8]],
	"pt_puits": ["Puits aux souhaits", "theme_contes", [1.8, 1.8, 2.8]],
	"pt_palmier": ["Palmier", "theme_jungle", [3.0, 3.0, 7.0]],
	"pt_tiki": ["Statue tiki", "theme_jungle", [1.0, 1.0, 3.0]],
	"pt_colonne_ruine": ["Colonne en ruine", "theme_jungle", [1.4, 1.4, 4.0]],
	"pt_bambous": ["Bosquet de bambous", "theme_jungle", [2.0, 2.0, 5.0]],
	"pt_tete_temple": ["Tête de temple", "theme_jungle", [3.4, 3.0, 4.0]],
	"pt_arbre_mort": ["Arbre mort", "theme_epouvante", [3.0, 3.0, 6.0]],
	"pt_citrouille_lanterne": ["Citrouille lanterne", "theme_epouvante", [0.8, 0.8, 0.8]],
	"pt_tombe_tordue": ["Tombe de travers", "theme_epouvante", [0.9, 0.3, 1.2]],
	"pt_grille_manoir": ["Grille du manoir", "theme_epouvante", [4.0, 0.3, 3.2]],
	"pt_cercueil": ["Cercueil debout", "theme_epouvante", [0.9, 0.5, 2.2]],
	"pt_corbeau": ["Corbeau sur son poteau", "theme_epouvante", [0.4, 0.4, 2.2]],
}

static var _meshes: Dictionary = {}


## Ajoute les thèmes au catalogue des décors (appelé par Decors._charge).
static func ajoute(donnees: Dictionary, par_id: Dictionary) -> void:
	var cats: Array = donnees.get("categories", [])
	var decs: Array = donnees.get("decors", [])
	for c in THEMES:
		cats.append({"id": c[0], "nom": c[1]})
	for id in PROPS:
		var p: Array = PROPS[id]
		var e := {"id": id, "nom": p[0], "cat": p[1], "taille": p[2], "triangles": 0, "proc": 1}
		decs.append(e)
		par_id[id] = e
	donnees["categories"] = cats
	donnees["decors"] = decs


static func est_theme(id: String) -> bool:
	return PROPS.has(id)


static func mesh(id: String) -> Mesh:
	if _meshes.has(id):
		return _meshes[id]
	var k := BlocMesh.new()
	_dessine(k, id)
	var m := k.to_mesh(ParcTypes.material())
	_meshes[id] = m
	return m


const R := Color("d62828")
const J := Color("ffc93c")
const B := Color("277da1")
const V := Color("43aa8b")
const ROSE := Color("f78fb3")
const VI := Color("7b2cbf")
const O := Color("f77f00")
const BL := Color("f8f4ea")
const N := Color("2b2d42")
const BOIS := Color("9c6644")
const BOIS_F := Color("6f4a2f")
const PIERRE := Color("a8a29e")
const PIERRE_F := Color("78716c")
const METAL := Color("adb5bd")
const OR := Color("e9c46a")
const FEUILLE := Color("52b788")
const FEUILLE_F := Color("2d6a4f")


static func _dessine(k: BlocMesh, id: String) -> void:
	match id:
		"pt_lampadaire_guirlande":
			k.cylinder(0, 0, 0, 0.12, 0.08, 4.0, 6, N)
			k.box(0, 4.0, 0, 0.5, 0.4, 0.5, J)
			for i in 6:
				var a := TAU * i / 6.0
				k.box(cos(a) * 0.5, 3.4 - 0.1 * (i % 2), sin(a) * 0.5, 0.15, 0.15, 0.15, ParcTypes.VIFS[i % 7])
		"pt_poubelle_clown":
			k.cylinder(0, 0, 0, 0.32, 0.36, 0.95, 10, R)
			k.cylinder(0, 0.95, 0, 0.38, 0.0, 0.2, 10, J)
			k.box(0, 0.55, -0.34, 0.25, 0.15, 0.04, BL)
		"pt_banc_parc":
			k.box(0, 0.42, 0, 1.7, 0.08, 0.45, BOIS)
			k.box(0, 0.5, 0.22, 1.7, 0.4, 0.06, BOIS)
			for x: float in [-0.75, 0.75]:
				k.box(x, 0, 0, 0.08, 0.45, 0.45, N)
		"pt_jardiniere":
			k.box(0, 0, 0, 2.0, 0.6, 1.0, PIERRE)
			k.box(0, 0.6, 0, 1.8, 0.15, 0.8, Color("6f4518"))
			for i in 7:
				k.box(-0.75 + i * 0.25, 0.75, sin(i * 1.7) * 0.25, 0.22, 0.22, 0.22, [R, J, ROSE, VI, BL][i % 5])
		"pt_panneau_direction":
			k.cylinder(0, 0, 0, 0.06, 0.06, 3.0, 6, BOIS_F)
			for i in 3:
				var dir := 1.0 if i % 2 == 0 else -1.0
				k.box(0.45 * dir, 2.0 + i * 0.35, 0, 0.9, 0.25, 0.05, [R, B, V][i])
		"pt_mascotte":
			k.box(0, 0, 0, 1.6, 0.5, 1.6, PIERRE)
			k.cylinder(0, 0.5, 0, 0.5, 0.45, 1.4, 10, O)
			k.dome(0, 1.9, 0, 0.6, 0.9, O.lightened(0.2), 10)
			k.dome(-0.35, 2.6, 0, 0.18, 0.4, O, 6)
			k.dome(0.35, 2.6, 0, 0.18, 0.4, O, 6)
			k.box(-0.2, 2.25, -0.5, 0.12, 0.12, 0.05, N)
			k.box(0.2, 2.25, -0.5, 0.12, 0.12, 0.05, N)
		"pt_arche_fleurs":
			for x: float in [-1.8, 1.8]:
				k.box(x, 0, 0, 0.3, 3.0, 0.3, BL)
			var n := 10
			for i in n:
				var a := PI * i / (n - 1)
				k.box(cos(a) * 1.8, 3.0 + sin(a) * 0.6, 0, 0.5, 0.4, 0.6, [ROSE, R, J, BL][i % 4])
		"pt_tonneau":
			k.cylinder(0, 0, 0, 0.32, 0.4, 0.55, 10, BOIS)
			k.cylinder(0, 0.55, 0, 0.4, 0.32, 0.55, 10, BOIS)
			k.cylinder(0, 0.25, 0, 0.37, 0.37, 0.06, 10, N)
			k.cylinder(0, 0.8, 0, 0.37, 0.37, 0.06, 10, N)
		"pt_coffre_tresor":
			k.box(0, 0, 0, 1.1, 0.55, 0.7, BOIS)
			k.box(0, 0.55, 0.1, 1.1, 0.3, 0.5, BOIS_F)
			k.box(0, 0.55, -0.22, 1.0, 0.3, 0.2, OR)
			for i in 5:
				k.box(-0.3 + i * 0.15, 0.85, -0.25, 0.12, 0.12, 0.12, OR.lightened(0.2))
		"pt_canon":
			for x: float in [-0.4, 0.4]:
				k.cylinder(x, 0.0, 0.3, 0.38, 0.38, 0.1, 10, BOIS_F)
			k.box(0, 0.25, 0.2, 0.7, 0.3, 1.0, BOIS)
			ParcTypes.beam(k, Vector3(0, 0.7, 0.8), Vector3(0, 0.95, -1.2), 0.42, N)
		"pt_ancre":
			k.box(0, 0, 0, 1.4, 0.15, 0.3, PIERRE_F)
			ParcTypes.beam(k, Vector3(0, 0.2, 0), Vector3(0, 2.3, 0), 0.18, N)
			ParcTypes.beam(k, Vector3(-0.6, 1.9, 0), Vector3(0.6, 1.9, 0), 0.14, N)
			ParcTypes.beam(k, Vector3(-0.7, 0.6, 0), Vector3(0, 0.25, 0), 0.16, N)
			ParcTypes.beam(k, Vector3(0.7, 0.6, 0), Vector3(0, 0.25, 0), 0.16, N)
		"pt_mat_pirate":
			k.cylinder(0, 0, 0, 0.18, 0.12, 8.0, 8, BOIS_F)
			ParcTypes.beam(k, Vector3(-1.0, 6.0, 0), Vector3(1.0, 6.0, 0), 0.12, BOIS_F)
			k.box(0.9, 6.6, 0, 1.6, 1.0, 0.04, N)
			k.box(0.9, 6.7, -0.03, 0.4, 0.4, 0.02, BL)
			k.box(0, 7.3, 0, 0.8, 0.4, 0.8, BOIS)
		"pt_rocher_crane":
			k.box(0, 0, 0, 4.0, 1.0, 3.0, PIERRE_F)
			k.dome(0, 1.0, 0, 1.9, 2.8, PIERRE, 10)
			k.box(-0.65, 2.2, -1.65, 0.7, 0.7, 0.2, N)
			k.box(0.65, 2.2, -1.65, 0.7, 0.7, 0.2, N)
			k.box(0, 1.5, -1.75, 0.3, 0.4, 0.2, N)
			k.box(0, 1.0, -1.7, 1.2, 0.25, 0.2, BL)
		"pt_cactus":
			k.cylinder(0, 0, 0, 0.3, 0.25, 3.0, 8, V)
			k.cylinder(-0.5, 1.2, 0, 0.18, 0.15, 1.2, 6, V)
			ParcTypes.beam(k, Vector3(0, 1.2, 0), Vector3(-0.5, 1.2, 0), 0.3, V)
			k.cylinder(0.5, 1.6, 0, 0.16, 0.14, 0.9, 6, V)
			ParcTypes.beam(k, Vector3(0, 1.6, 0), Vector3(0.5, 1.6, 0), 0.28, V)
			k.box(0, 3.0, 0, 0.2, 0.15, 0.2, ROSE)
		"pt_chariot":
			for z: float in [-1.3, 1.3]:
				for x: float in [-1.0, 1.0]:
					k.cylinder(x, 0, z, 0.55, 0.55, 0.08, 10, BOIS_F)
			k.box(0, 0.55, 0, 1.6, 0.5, 3.4, BOIS)
			k.dome(0, 1.05, 0, 0.9, 1.5, BL, 8)
			k.box(0, 1.05, 0, 1.8, 0.1, 3.0, BL)
		"pt_facade_saloon":
			k.box(0, 0, 0, 8.0, 6.0, 0.4, BOIS)
			k.box(0, 6.0, 0, 5.0, 1.0, 0.4, BOIS_F)
			k.box(0, 2.6, -0.4, 8.0, 0.15, 1.0, BOIS_F)
			for x: float in [-3.6, 3.6]:
				k.box(x, 0, -0.85, 0.15, 2.6, 0.15, BOIS_F)
			k.box(0, 0, -0.22, 1.4, 2.0, 0.06, Color("4a2c1a"))
			k.box(-2.4, 3.4, -0.22, 1.2, 1.2, 0.06, Color("33495e"))
			k.box(2.4, 3.4, -0.22, 1.2, 1.2, 0.06, Color("33495e"))
			k.box(0, 5.0, -0.25, 4.0, 0.8, 0.06, J)
		"pt_totem":
			for i in 4:
				k.box(0, i * 1.15, 0, 0.9, 1.1, 0.9, [R, B, V, J][i])
				k.box(-0.2, i * 1.15 + 0.6, -0.47, 0.15, 0.15, 0.05, N)
				k.box(0.2, i * 1.15 + 0.6, -0.47, 0.15, 0.15, 0.05, N)
			k.box(0, 4.0, 0, 2.2, 0.25, 0.4, O)
		"pt_poteau_attache":
			for x: float in [-1.3, 1.3]:
				k.box(x, 0, 0, 0.2, 1.1, 0.2, BOIS_F)
			ParcTypes.beam(k, Vector3(-1.4, 1.05, 0), Vector3(1.4, 1.05, 0), 0.14, BOIS)
		"pt_chateau_eau_western":
			for x: float in [-1.1, 1.1]:
				for z: float in [-1.1, 1.1]:
					k.box(x, 0, z, 0.2, 4.0, 0.2, BOIS_F)
			k.cylinder(0, 4.0, 0, 1.5, 1.5, 2.0, 12, BOIS)
			ParcTypes.chapiteau(k, 0, 6.0, 0, 1.6, 0.9, 12, BOIS_F, BOIS_F)
		"pt_fusee":
			k.cylinder(0, 0, 0, 0.9, 0.9, 8.0, 12, BL)
			k.cylinder(0, 8.0, 0, 0.9, 0.0, 3.2, 12, R)
			k.box(0, 5.0, -0.85, 0.6, 0.6, 0.1, B)
			for i in 3:
				var a := TAU * i / 3.0
				ParcTypes.beam(k, Vector3(cos(a) * 0.8, 2.0, sin(a) * 0.8), Vector3(cos(a) * 1.5, 0.0, sin(a) * 1.5), 0.25, R)
		"pt_soucoupe":
			for i in 3:
				var a := TAU * i / 3.0
				ParcTypes.beam(k, Vector3(cos(a) * 2.0, 0, sin(a) * 2.0), Vector3(cos(a) * 1.2, 1.6, sin(a) * 1.2), 0.15, METAL)
			k.cylinder(0, 1.6, 0, 1.5, 3.0, 0.5, 16, METAL)
			k.cylinder(0, 2.1, 0, 3.0, 1.5, 0.5, 16, METAL.lightened(0.2))
			k.dome(0, 2.6, 0, 1.2, 1.0, Color("90e0ef"), 12)
			for i in 8:
				var a := TAU * i / 8.0
				k.box(cos(a) * 2.6, 2.05, sin(a) * 2.6, 0.2, 0.15, 0.2, J)
		"pt_radar":
			k.cylinder(0, 0, 0, 0.6, 0.4, 2.5, 8, METAL)
			k.dome(0, 2.6, 0, 1.4, -0.6, BL, 12)
			ParcTypes.beam(k, Vector3(0, 2.4, 0), Vector3(0, 3.6, -0.6), 0.1, N)
			k.box(0, 3.6, -0.6, 0.2, 0.2, 0.2, R)
		"pt_cristal":
			for i in 5:
				var a := TAU * i / 5.0
				var h := 1.4 + float(i % 3) * 0.6
				ParcTypes.beam(k, Vector3(cos(a) * 0.4, 0, sin(a) * 0.4), Vector3(cos(a) * 0.8, h, sin(a) * 0.8), 0.35, [Color("c77dff"), Color("4cc9f0"), Color("f72585")][i % 3])
		"pt_robot":
			k.box(-0.25, 0, 0, 0.25, 0.9, 0.3, METAL)
			k.box(0.25, 0, 0, 0.25, 0.9, 0.3, METAL)
			k.box(0, 0.9, 0, 1.0, 1.0, 0.6, METAL.lightened(0.15))
			k.box(0, 1.9, 0, 0.6, 0.5, 0.5, METAL)
			k.box(-0.15, 2.05, -0.26, 0.12, 0.12, 0.03, Color("4cc9f0"))
			k.box(0.15, 2.05, -0.26, 0.12, 0.12, 0.03, Color("4cc9f0"))
			k.cylinder(0, 2.4, 0, 0.03, 0.03, 0.3, 4, N)
			k.box(0, 2.7, 0, 0.12, 0.12, 0.12, R)
		"pt_planete":
			k.cylinder(0, 0, 0, 0.15, 0.15, 1.6, 6, METAL)
			k.dome(0, 3.2, 0, 1.6, 1.6, O, 14)
			k.dome(0, 3.2, 0, 1.6, -1.6, O.darkened(0.15), 14)
			k.cylinder(0, 3.15, 0, 2.6, 2.6, 0.1, 18, J)
		"pt_tour_chateau":
			k.cylinder(0, 0, 0, 2.0, 1.9, 9.0, 12, PIERRE)
			for i in 12:
				var a := TAU * i / 12.0
				if i % 2 == 0:
					k.box(cos(a) * 1.9, 9.0, sin(a) * 1.9, 0.6, 0.7, 0.6, PIERRE)
			ParcTypes.chapiteau(k, 0, 9.0, 0, 2.2, 3.0, 12, B, B.darkened(0.1))
			k.box(0, 3.0, -1.95, 0.6, 1.2, 0.1, N)
			k.box(0, 6.0, -1.95, 0.6, 1.2, 0.1, N)
		"pt_porte_chateau":
			for x: float in [-3.2, 3.2]:
				k.box(x, 0, 0, 1.6, 7.0, 2.0, PIERRE)
				ParcTypes.chapiteau(k, x, 7.0, 0, 1.2, 1.6, 8, R, R)
			k.box(0, 4.0, 0, 4.8, 2.0, 1.6, PIERRE)
			for i in 4:
				k.box(-1.8 + i * 1.2, 6.0, 0, 0.6, 0.6, 1.6, PIERRE)
			k.box(0, 0, -0.5, 3.2, 4.0, 0.2, BOIS_F)
		"pt_champignon":
			k.cylinder(0, 0, 0, 0.5, 0.4, 2.2, 10, BL)
			k.dome(0, 2.1, 0, 1.5, 1.4, R, 12)
			for i in 7:
				var a := TAU * i / 7.0
				k.box(cos(a) * 0.9, 2.7 + 0.2 * (i % 2), sin(a) * 0.9, 0.3, 0.15, 0.3, BL)
		"pt_citrouille_carrosse":
			for z: float in [-1.2, 1.2]:
				for x: float in [-1.0, 1.0]:
					k.cylinder(x, 0, z, 0.5, 0.5, 0.08, 10, OR)
			k.dome(0, 0.6, 0, 1.2, 1.6, O, 12)
			k.dome(0, 0.6, 0, 1.2, -0.5, O.darkened(0.1), 12)
			k.box(0, 2.2, 0, 0.15, 0.4, 0.15, V)
			k.box(0, 1.2, -1.1, 0.6, 0.6, 0.1, Color("33495e"))
		"pt_puits":
			k.cylinder(0, 0, 0, 0.85, 0.85, 0.9, 12, PIERRE)
			k.cylinder(0, 0.85, 0, 0.65, 0.65, 0.04, 12, Color("3f9ed8"))
			for x: float in [-0.75, 0.75]:
				k.box(x, 0.9, 0, 0.12, 1.4, 0.12, BOIS_F)
			k.gable(0, 2.3, 0, 1.8, 1.2, 0.5, R, true)
		"pt_palmier":
			var pts := [Vector3(0, 0, 0), Vector3(0.3, 2.0, 0), Vector3(0.8, 4.0, 0), Vector3(1.2, 6.0, 0)]
			for i in 3:
				ParcTypes.beam(k, pts[i], pts[i + 1], 0.35 - i * 0.05, BOIS)
			for i in 7:
				var a := TAU * i / 7.0
				ParcTypes.beam(k, pts[3], pts[3] + Vector3(cos(a) * 2.2, -0.9, sin(a) * 2.2), 0.4, FEUILLE if i % 2 == 0 else FEUILLE_F)
			k.box(1.2, 5.7, 0, 0.4, 0.4, 0.4, BOIS_F)
		"pt_tiki":
			k.box(0, 0, 0, 0.9, 2.6, 0.9, BOIS)
			k.box(0, 2.6, 0, 1.0, 0.3, 1.0, BOIS_F)
			k.box(-0.2, 1.9, -0.46, 0.25, 0.2, 0.05, J)
			k.box(0.2, 1.9, -0.46, 0.25, 0.2, 0.05, J)
			k.box(0, 1.2, -0.46, 0.6, 0.25, 0.05, BL)
			k.box(0, 1.55, -0.5, 0.2, 0.35, 0.12, BOIS_F)
		"pt_colonne_ruine":
			k.box(0, 0, 0, 1.4, 0.4, 1.4, PIERRE_F)
			k.cylinder(0, 0.4, 0, 0.5, 0.5, 3.0, 10, PIERRE)
			k.box(0.4, 0.0, 0.8, 0.7, 0.4, 0.5, PIERRE)
			ParcTypes.beam(k, Vector3(-0.4, 2.0, 0.4), Vector3(0.3, 3.0, -0.3), 0.15, FEUILLE_F)
		"pt_bambous":
			for i in 9:
				var a := float(i) * 2.4
				var r := 0.3 + float(i % 3) * 0.25
				k.cylinder(cos(a) * r, 0, sin(a) * r, 0.07, 0.06, 3.5 + float(i % 4) * 0.4, 6, Color("95d5b2") if i % 2 == 0 else V)
		"pt_tete_temple":
			k.box(0, 0, 0, 3.4, 0.6, 3.0, PIERRE_F)
			k.box(0, 0.6, 0, 2.8, 3.0, 2.4, PIERRE)
			k.box(0, 3.6, 0, 3.0, 0.4, 2.6, PIERRE_F)
			k.box(-0.7, 2.4, -1.22, 0.6, 0.4, 0.1, N)
			k.box(0.7, 2.4, -1.22, 0.6, 0.4, 0.1, N)
			k.box(0, 1.8, -1.3, 0.5, 0.7, 0.2, PIERRE_F)
			k.box(0, 0.6, -1.22, 1.2, 0.9, 0.1, N)
			k.box(1.2, 3.8, 0.5, 0.4, 0.5, 0.4, FEUILLE_F)
		"pt_arbre_mort":
			ParcTypes.beam(k, Vector3(0, 0, 0), Vector3(0.2, 3.5, 0), 0.45, Color("4a3b32"))
			ParcTypes.beam(k, Vector3(0.2, 3.5, 0), Vector3(-0.3, 5.8, 0.3), 0.25, Color("4a3b32"))
			for i in 5:
				var a := TAU * i / 5.0
				var y := 2.5 + float(i) * 0.6
				ParcTypes.beam(k, Vector3(0.1, y, 0), Vector3(cos(a) * 1.5, y + 0.8, sin(a) * 1.5), 0.12, Color("4a3b32"))
		"pt_citrouille_lanterne":
			k.dome(0, 0, 0, 0.4, 0.55, O, 10)
			k.box(0, 0.55, 0, 0.08, 0.15, 0.08, V)
			k.box(-0.12, 0.3, -0.37, 0.1, 0.1, 0.04, J)
			k.box(0.12, 0.3, -0.37, 0.1, 0.1, 0.04, J)
			k.box(0, 0.15, -0.38, 0.25, 0.06, 0.04, J)
		"pt_tombe_tordue":
			k.box(0, 0, 0, 0.8, 0.1, 0.3, PIERRE_F)
			ParcTypes.beam(k, Vector3(0, 0.1, 0), Vector3(0.15, 1.1, 0), 0.6, PIERRE)
			k.box(0.08, 0.6, -0.2, 0.3, 0.06, 0.03, N)
		"pt_grille_manoir":
			for x: float in [-1.9, 1.9]:
				k.box(x, 0, 0, 0.35, 3.0, 0.35, PIERRE_F)
			for i in 13:
				var x := -1.6 + i * 0.27
				k.box(x, 0, 0, 0.05, 2.4 + 0.3 * sin(i * 0.5), 0.05, N)
			ParcTypes.beam(k, Vector3(-1.8, 2.3, 0), Vector3(1.8, 2.3, 0), 0.06, N)
		"pt_cercueil":
			k.box(0, 0, 0, 0.8, 2.1, 0.35, Color("3d2b1f"))
			k.box(0, 1.2, -0.18, 0.12, 0.5, 0.02, OR)
			k.box(0, 1.6, -0.18, 0.35, 0.1, 0.02, OR)
		"pt_corbeau":
			k.cylinder(0, 0, 0, 0.06, 0.06, 1.8, 6, BOIS_F)
			k.box(0, 1.8, 0, 0.3, 0.3, 0.5, N)
			k.box(0, 2.1, -0.18, 0.18, 0.18, 0.2, N)
			k.box(0, 2.12, -0.32, 0.06, 0.05, 0.12, J)
		_:
			k.box(0, 0, 0, 1, 1, 1, R)
