class_name GestionModeles
extends RefCounted
## Bibliothèque d'objets low-poly du mode gestion (meubles, machines, jeux,
## véhicules), dessinés en code avec LpKit.
##
## Chaque modèle est dessiné en coordonnées locales : origine au sol, au
## centre de l'objet, face avant vers +Z (pour un objet accroché au mur, le
## mur est en z = 0 et l'objet avance vers +Z). dessiner() place le modèle
## (position, angle autour de Y) avec la transformation du kit.
##
## Couches : "base" (couleurs), "verre" (transparent), "eau" (transparent
## brillant), "lumiere" (sans ombrage, pour les lampes et les écrans).

const BOIS := Color("8a5a3b")
const BOIS_FONCE := Color("5c4033")
const METAL := Color("adb5bd")
const NOIR := Color("26262b")
const BLANC := Color("f6f4ef")
const OR := Color("d4af37")
const VERT := Color("3f8f4a")

## Places des clients apportées par un objet : modèle → [[x, z, angle, assis]] locaux.
const PLACES := {
	"canape": [[-0.45, 0.1, 0.0, true], [0.45, 0.1, 0.0, true]],
	"tapis_course": [[0.0, 0.1, PI, false]],
	"velo": [[0.0, 0.05, PI, true]],
	"banc_muscu": [[0.0, 0.0, 0.0, true]],
	"jacuzzi": [[-0.5, 0.0, 0.0, false], [0.5, 0.0, PI, false]],
	"sauna": [[0.0, 1.6, PI, false]],
	"billard": [[0.0, 1.5, PI, false]],
	"juke_box": [[0.0, 0.9, PI, false]],
	"presentoir_souvenirs": [[0.0, 1.2, PI, false]],
	"journaux": [[0.0, 0.8, PI, false]],
	"balancoire": [[0.0, 0.0, 0.0, true]],
	"toboggan_enfants": [[0.0, 1.6, PI, false]],
	"banc": [[-0.4, 0.0, 0.0, true], [0.4, 0.0, 0.0, true]],
	"kiosque": [[0.0, 0.0, 0.0, false]],
	"bar_piscine": [[0.0, 1.4, PI, false]],
	"buffet": [[0.0, 1.1, PI, false]],
	"aquarium": [[0.0, 1.1, PI, false]],
	"cheminee": [[-0.7, 1.4, PI, true], [0.7, 1.4, PI, true]],
	"fontaine": [[0.0, 1.3, PI, false]],
	"ecran": [],
}


## Dessine un modèle à une position et un angle (autour de Y).
static func dessiner(k: LpKit, nom: String, p: Vector3, rot: float, teinte := Color.WHITE) -> void:
	var avant := k.xf
	k.xf = Transform3D(Basis(Vector3.UP, rot), p)
	match nom:
		"plante":
			_plante(k, 0.75)
		"plante_grande":
			_plante(k, 1.2)
		"canape":
			var c := teinte if teinte != Color.WHITE else Color("2a9d8f")
			k.box(Vector3(0, 0.22, 0), Vector3(1.9, 0.44, 0.85), c)
			k.box(Vector3(0, 0.62, -0.32), Vector3(1.9, 0.5, 0.22), c.darkened(0.12))
			k.box(Vector3(-0.88, 0.52, 0.05), Vector3(0.18, 0.3, 0.8), c.darkened(0.08))
			k.box(Vector3(0.88, 0.52, 0.05), Vector3(0.18, 0.3, 0.8), c.darkened(0.08))
			k.box(Vector3(-0.45, 0.5, -0.12), Vector3(0.35, 0.3, 0.12), Color("f1faee"))
		"tapis_rouge":
			k.box(Vector3(0, 0.075, 0), Vector3(1.6, 0.02, 5.2), Color("b5172b"), 0.0, false)
			k.box(Vector3(-0.85, 0.08, 0), Vector3(0.08, 0.02, 5.2), OR, 0.0, false)
			k.box(Vector3(0.85, 0.08, 0), Vector3(0.08, 0.02, 5.2), OR, 0.0, false)
		"presentoir":
			k.box(Vector3(0, 0.65, 0), Vector3(0.7, 1.3, 0.3), BOIS)
			for i in 3:
				for j in 2:
					k.box(Vector3(-0.17 + j * 0.34, 0.45 + i * 0.35, 0.17), Vector3(0.26, 0.3, 0.04), [Color("e76f51"), Color("2a9d8f"), Color("e9c46a")][(i + j) % 3])
		"chariot_bagages":
			k.box(Vector3(0, 0.25, 0), Vector3(1.1, 0.06, 0.6), OR)
			for sx in [-0.5, 0.5]:
				k.box(Vector3(sx, 0.9, 0), Vector3(0.05, 1.3, 0.05), OR, 0.0, false)
			k.box(Vector3(0, 1.55, 0), Vector3(1.1, 0.06, 0.06), OR, 0.0, false)
			k.box(Vector3(-0.2, 0.55, 0), Vector3(0.55, 0.55, 0.35), Color("6d4c41"))
			k.box(Vector3(0.28, 0.48, 0), Vector3(0.35, 0.4, 0.3), Color("1d3557"))
			k.box(Vector3(0.0, 0.92, 0), Vector3(0.45, 0.2, 0.3), Color("e63946"))
			for sx in [-0.45, 0.45]:
				k.box(Vector3(sx, 0.08, 0), Vector3(0.12, 0.16, 0.12), NOIR)
		"borne":
			k.box(Vector3(0, 0.6, 0), Vector3(0.5, 1.2, 0.35), Color("e9ecef"))
			k.layer = "lumiere"
			k.box(Vector3(0, 1.0, 0.18), Vector3(0.36, 0.3, 0.02), Color("7cc7ff"), 0.0, false)
			k.layer = "base"
		"horloges":
			for i in 3:
				var x := -0.7 + i * 0.7
				k.lathe(Vector3(x, 2.0, 0.02), [Vector2(0.0, 0.0), Vector2(0.24, 0.0), Vector2(0.24, 0.05), Vector2(0.0, 0.05)], 12, Color("f8f9fa"))
				k.box(Vector3(x, 2.0, 0.07), Vector3(0.03, 0.18, 0.01), NOIR, 0.0, false)
		"fontaine":
			k.lathe(Vector3.ZERO, [Vector2(0.0, 0.0), Vector2(0.95, 0.0), Vector2(1.0, 0.45), Vector2(0.85, 0.45), Vector2(0.0, 0.3)], 14, Color("e9e4da"))
			k.layer = "eau"
			k.lathe(Vector3(0, 0.38, 0), [Vector2(0.0, 0.0), Vector2(0.84, 0.0), Vector2(0.0, 0.01)], 14, Color(0.45, 0.8, 0.95, 0.8))
			k.layer = "base"
			k.tube(Vector3(0, 0.3, 0), Vector3(0, 1.1, 0), 0.08, 0.06, 8, Color("e9e4da"))
			k.lathe(Vector3(0, 1.1, 0), [Vector2(0.0, 0.0), Vector2(0.4, 0.05), Vector2(0.35, 0.18), Vector2(0.0, 0.12)], 10, Color("e9e4da"))
		"lustre":
			k.tube(Vector3(0, 2.4, 0), Vector3(0, 3.0, 0), 0.02, 0.02, 4, OR)
			k.lathe(Vector3(0, 2.0, 0), [Vector2(0.0, 0.0), Vector2(0.55, 0.2), Vector2(0.45, 0.4), Vector2(0.0, 0.5)], 10, OR)
			k.layer = "lumiere"
			for i in 8:
				var a := TAU * i / 8.0
				k.box(Vector3(cos(a) * 0.55, 2.28, sin(a) * 0.55), Vector3(0.08, 0.14, 0.08), Color("fff3b0"), 0.0, false)
			k.layer = "base"
		"tele_meuble":
			k.box(Vector3(0, 0.3, 0), Vector3(1.4, 0.6, 0.45), BOIS_FONCE)
			k.box(Vector3(0, 0.95, -0.05), Vector3(1.05, 0.62, 0.06), NOIR)
			k.layer = "lumiere"
			k.box(Vector3(0, 0.95, -0.01), Vector3(0.95, 0.52, 0.01), Color("5fa8d3"), 0.0, false)
			k.layer = "base"
		"clim":
			k.box(Vector3(0, 2.0, 0.12), Vector3(0.9, 0.28, 0.22), BLANC)
			k.box(Vector3(0, 1.9, 0.24), Vector3(0.8, 0.03, 0.02), Color("ced4da"), 0.0, false)
		"minibar":
			k.box(Vector3(0, 0.38, 0), Vector3(0.5, 0.76, 0.5), Color("343a40"))
			k.box(Vector3(0.2, 0.45, 0.26), Vector3(0.03, 0.25, 0.03), METAL, 0.0, false)
			k.box(Vector3(-0.1, 0.84, 0), Vector3(0.08, 0.16, 0.08), Color("2a9d8f"), 0.0, false)
			k.box(Vector3(0.08, 0.82, 0), Vector3(0.08, 0.12, 0.08), Color("e9c46a"), 0.0, false)
		"tableau":
			var c2 := teinte if teinte != Color.WHITE else Color("e76f51")
			k.box(Vector3(0, 1.75, 0.03), Vector3(1.1, 0.75, 0.05), OR)
			k.box(Vector3(0, 1.75, 0.06), Vector3(0.95, 0.6, 0.02), Color("a8dadc"), 0.0, false)
			k.box(Vector3(-0.15, 1.65, 0.075), Vector3(0.5, 0.25, 0.01), c2, 0.0, false)
			k.box(Vector3(0.25, 1.88, 0.075), Vector3(0.18, 0.18, 0.01), Color("ffd166"), 0.0, false)
		"machine_cafe":
			k.box(Vector3(0, 0.45, 0), Vector3(0.5, 0.9, 0.45), BOIS)
			k.box(Vector3(0, 1.05, 0), Vector3(0.3, 0.3, 0.25), NOIR)
			k.box(Vector3(0, 0.96, 0.14), Vector3(0.08, 0.08, 0.08), BLANC, 0.0, false)
		"coffre":
			k.box(Vector3(0, 0.3, 0), Vector3(0.5, 0.6, 0.45), Color("495057"))
			k.lathe(Vector3(0, 0.32, 0.23), [Vector2(0.0, 0.0), Vector2(0.1, 0.0), Vector2(0.1, 0.03), Vector2(0.0, 0.03)], 8, METAL)
		"baignoire":
			k.box(Vector3(0, 0.28, 0), Vector3(1.7, 0.56, 0.8), BLANC)
			k.layer = "eau"
			k.box(Vector3(0, 0.5, 0), Vector3(1.5, 0.04, 0.6), Color(0.6, 0.85, 0.95, 0.8), 0.0, false)
			k.layer = "base"
			k.box(Vector3(-0.78, 0.75, 0), Vector3(0.06, 0.4, 0.06), METAL, 0.0, false)
		"lave_linge":
			k.box(Vector3(0, 0.45, 0), Vector3(0.85, 0.9, 0.8), BLANC)
			k.lathe(Vector3(0, 0.45, 0.41), [Vector2(0.0, 0.0), Vector2(0.26, 0.0), Vector2(0.26, 0.03), Vector2(0.0, 0.03)], 12, Color("4a4e69"))
		"seche_linge":
			for i in 2:
				k.box(Vector3(-0.45 + i * 0.9, 0.5, 0), Vector3(0.85, 1.0, 0.8), Color("dee2e6"))
				k.lathe(Vector3(-0.45 + i * 0.9, 0.5, 0.41), [Vector2(0.0, 0.0), Vector2(0.26, 0.0), Vector2(0.26, 0.03), Vector2(0.0, 0.03)], 12, Color("6c757d"))
		"lave_linge_xxl":
			k.box(Vector3(0, 0.75, 0), Vector3(2.2, 1.5, 1.0), Color("ced4da"))
			for i in 3:
				k.lathe(Vector3(-0.7 + i * 0.7, 0.75, 0.51), [Vector2(0.0, 0.0), Vector2(0.25, 0.0), Vector2(0.25, 0.03), Vector2(0.0, 0.03)], 12, Color("4a4e69"))
			k.layer = "lumiere"
			k.box(Vector3(0.9, 1.35, 0.51), Vector3(0.2, 0.1, 0.01), Color("80ed99"), 0.0, false)
			k.layer = "base"
		"repassage":
			k.box(Vector3(0, 0.85, 0), Vector3(1.3, 0.04, 0.4), Color("90e0ef"))
			k.box(Vector3(0, 0.42, 0), Vector3(0.05, 0.84, 0.3), METAL, 0.0, false)
			k.box(Vector3(0.3, 0.93, 0), Vector3(0.25, 0.1, 0.14), Color("e63946"))
			k.box(Vector3(-0.9, 0.5, 0), Vector3(0.5, 1.0, 0.5), Color("e9ecef"))
			for i in 4:
				k.box(Vector3(-0.9, 1.02 + i * 0.07, 0), Vector3(0.42, 0.06, 0.38), [BLANC, Color("a8dadc"), Color("ffd6a5")][i % 3])
		"chariot_menage":
			k.box(Vector3(0, 0.5, 0), Vector3(1.0, 0.8, 0.55), Color("457b9d"))
			k.box(Vector3(0, 0.95, 0), Vector3(0.85, 0.1, 0.45), BLANC)
			k.box(Vector3(0.38, 1.1, 0), Vector3(0.18, 0.2, 0.18), Color("ffb703"))
			k.box(Vector3(-0.55, 0.6, 0), Vector3(0.1, 0.9, 0.5), Color("8d99ae"))
			for sx in [-0.4, 0.4]:
				k.box(Vector3(sx, 0.06, 0), Vector3(0.1, 0.12, 0.5), NOIR)
		"etagere_produits":
			k.box(Vector3(0, 0.95, 0), Vector3(1.4, 1.9, 0.4), BOIS)
			for j in 4:
				for i in 5:
					k.box(Vector3(-0.55 + i * 0.27, 0.3 + j * 0.45, 0.05), Vector3(0.16, 0.24, 0.16),
						[Color("e76f51"), Color("2a9d8f"), Color("e9c46a"), Color("8ecae6"), Color("cdb4db")][(i + j) % 5], 0.0, false)
		"ordinateur":
			k.box(Vector3(0, 0.74, 0), Vector3(1.6, 0.06, 0.8), BOIS_FONCE)
			for sx in [-0.7, 0.7]:
				k.box(Vector3(sx, 0.37, 0), Vector3(0.06, 0.74, 0.7), BOIS_FONCE, 0.0, false)
			k.box(Vector3(0, 1.05, -0.2), Vector3(0.7, 0.45, 0.05), NOIR)
			k.layer = "lumiere"
			k.box(Vector3(0, 1.05, -0.17), Vector3(0.62, 0.38, 0.01), Color("8ecae6"), 0.0, false)
			k.layer = "base"
			k.box(Vector3(0, 0.78, 0.15), Vector3(0.45, 0.02, 0.15), Color("495057"), 0.0, false)
			k.box(Vector3(0, 0.45, 0.75), Vector3(0.5, 0.08, 0.5), Color("1d3557"))
			k.box(Vector3(0, 0.75, 0.98), Vector3(0.5, 0.55, 0.08), Color("1d3557"))
		"tableau_blanc":
			k.box(Vector3(0, 1.6, 0.03), Vector3(2.0, 1.1, 0.05), METAL)
			k.box(Vector3(0, 1.6, 0.06), Vector3(1.9, 1.0, 0.01), BLANC, 0.0, false)
			for i in 6:
				k.box(Vector3(-0.7 + i * 0.28, 1.75 - (i % 2) * 0.3, 0.07), Vector3(0.2, 0.15, 0.01), [Color("ffd166"), Color("90e0ef"), Color("f4978e")][i % 3], 0.0, false)
		"juke_box":
			k.box(Vector3(0, 0.6, 0), Vector3(0.9, 1.2, 0.6), Color("9d0208"))
			k.lathe(Vector3(0, 1.2, 0), [Vector2(0.45, 0.0), Vector2(0.42, 0.25), Vector2(0.2, 0.4), Vector2(0.0, 0.42)], 10, Color("9d0208"))
			k.layer = "lumiere"
			k.box(Vector3(0, 0.85, 0.31), Vector3(0.6, 0.4, 0.01), Color("ffba08"), 0.0, false)
			k.layer = "base"
		"flechettes":
			k.lathe(Vector3(0, 1.7, 0.02), [Vector2(0.0, 0.0), Vector2(0.3, 0.0), Vector2(0.3, 0.05), Vector2(0.0, 0.05)], 14, Color("2b2d42"))
			k.lathe(Vector3(0, 1.7, 0.07), [Vector2(0.0, 0.0), Vector2(0.18, 0.0), Vector2(0.0, 0.01)], 12, Color("e63946"))
		"piano":
			k.box(Vector3(0, 0.78, 0), Vector3(1.5, 0.32, 1.7), Color("111111"))
			k.box(Vector3(0, 0.35, -0.5), Vector3(0.12, 0.7, 0.12), Color("111111"), 0.0, false)
			k.box(Vector3(0, 0.35, 0.5), Vector3(0.12, 0.7, 0.12), Color("111111"), 0.0, false)
			k.box(Vector3(0, 0.95, 0.92), Vector3(1.35, 0.05, 0.22), BLANC)
			k.box(Vector3(0, 1.25, -0.2), Vector3(1.3, 0.6, 0.05), Color("111111"))
			k.box(Vector3(0, 0.45, 1.35), Vector3(0.8, 0.08, 0.35), Color("111111"))
		"cave_vins":
			k.box(Vector3(0, 1.0, 0), Vector3(1.6, 2.0, 0.5), BOIS_FONCE)
			for j in 5:
				for i in 6:
					k.box(Vector3(-0.62 + i * 0.25, 0.3 + j * 0.36, 0.2), Vector3(0.1, 0.1, 0.16), [Color("6a040f"), Color("e9d8a6"), Color("2d6a4f")][(i + j) % 3], 0.0, false)
			k.layer = "verre"
			k.box(Vector3(0, 1.0, 0.27), Vector3(1.5, 1.9, 0.02), Color(0.7, 0.85, 0.9, 0.3), 0.0, false)
			k.layer = "base"
		"billard":
			k.box(Vector3(0, 0.75, 0), Vector3(2.4, 0.15, 1.3), BOIS_FONCE)
			k.box(Vector3(0, 0.83, 0), Vector3(2.15, 0.02, 1.05), Color("2d6a4f"), 0.0, false)
			for sx in [-1.05, 1.05]:
				for sz in [-0.5, 0.5]:
					k.box(Vector3(sx, 0.35, sz), Vector3(0.14, 0.7, 0.14), BOIS_FONCE, 0.0, false)
			for i in 6:
				k.box(Vector3(-0.3 + (i % 3) * 0.1, 0.88, -0.1 + (i / 3) * 0.1), Vector3(0.06, 0.06, 0.06), [Color("e63946"), Color("ffd166"), BLANC][i % 3], 0.0, false)
		"cheminee":
			k.box(Vector3(0, 0.6, 0.25), Vector3(1.8, 1.2, 0.5), Color("b08968"))
			k.box(Vector3(0, 0.4, 0.45), Vector3(0.9, 0.6, 0.12), NOIR)
			k.layer = "lumiere"
			k.box(Vector3(0, 0.25, 0.48), Vector3(0.6, 0.25, 0.05), Color("ff7b00"), 0.0, false)
			k.layer = "base"
			k.box(Vector3(0, 1.25, 0.3), Vector3(2.0, 0.1, 0.6), Color("e9e4da"))
			_fauteuil(k, Vector3(-0.7, 0, 1.4), PI, Color("6d2e46"))
			_fauteuil(k, Vector3(0.7, 0, 1.4), PI, Color("6d2e46"))
		"buffet":
			k.box(Vector3(0, 0.45, 0), Vector3(3.0, 0.9, 0.7), BLANC)
			k.box(Vector3(0, 0.91, 0), Vector3(3.1, 0.03, 0.8), Color("e9c46a"))
			for i in 6:
				k.lathe(Vector3(-1.2 + i * 0.48, 0.92, 0), [Vector2(0.0, 0.0), Vector2(0.18, 0.0), Vector2(0.2, 0.08), Vector2(0.0, 0.08)], 8, METAL)
				k.box(Vector3(-1.2 + i * 0.48, 1.02, 0), Vector3(0.2, 0.06, 0.2), [Color("e76f51"), Color("90be6d"), Color("f9c74f")][i % 3], 0.0, false)
		"chariot_desserts":
			k.box(Vector3(0, 0.75, 0), Vector3(0.9, 0.05, 0.5), METAL)
			k.box(Vector3(0, 0.4, 0), Vector3(0.9, 0.05, 0.5), METAL)
			for i in 3:
				k.lathe(Vector3(-0.28 + i * 0.28, 0.78, 0), [Vector2(0.0, 0.0), Vector2(0.12, 0.0), Vector2(0.12, 0.14), Vector2(0.0, 0.14)], 8, [Color("f4a261"), Color("ffafcc"), Color("6f1d1b")][i])
		"four_pizza":
			k.box(Vector3(0, 0.45, 0), Vector3(1.4, 0.9, 1.2), Color("9c6644"))
			k.lathe(Vector3(0, 0.9, 0), [Vector2(0.7, 0.0), Vector2(0.62, 0.4), Vector2(0.3, 0.7), Vector2(0.0, 0.75)], 10, Color("bc4749"))
			k.box(Vector3(0, 1.1, 0.55), Vector3(0.45, 0.3, 0.1), NOIR)
			k.layer = "lumiere"
			k.box(Vector3(0, 1.05, 0.6), Vector3(0.35, 0.18, 0.02), Color("ff7b00"), 0.0, false)
			k.layer = "base"
		"aquarium":
			k.box(Vector3(0, 0.4, 0), Vector3(2.2, 0.8, 0.6), BOIS_FONCE)
			k.layer = "eau"
			k.box(Vector3(0, 1.15, 0), Vector3(2.1, 0.7, 0.5), Color(0.3, 0.7, 0.9, 0.55), 0.0, false)
			k.layer = "base"
			for i in 5:
				k.box(Vector3(-0.8 + i * 0.4, 1.1 + (i % 2) * 0.2, 0.0), Vector3(0.14, 0.08, 0.04), [Color("ff9f1c"), Color("ffbf69"), Color("e71d36")][i % 3], 0.0, false)
			k.blob(Vector3(0.6, 0.9, 0), Vector3(0.2, 0.25, 0.15), Color("2d6a4f"), Color("52b788"), 0.2, 0)
		"sauna":
			k.box(Vector3(0, 1.1, 0), Vector3(2.6, 2.2, 2.4), Color("c68b59"))
			for i in 6:
				k.box(Vector3(-1.0 + i * 0.4, 1.1, 1.21), Vector3(0.04, 2.1, 0.02), Color("a0673b"), 0.0, false)
			k.layer = "verre"
			k.box(Vector3(0.4, 1.2, 1.22), Vector3(0.7, 1.5, 0.03), Color(0.9, 0.7, 0.5, 0.45), 0.0, false)
			k.layer = "base"
		"jacuzzi":
			k.lathe(Vector3.ZERO, [Vector2(0.0, 0.0), Vector2(1.3, 0.0), Vector2(1.35, 0.6), Vector2(1.15, 0.6), Vector2(0.0, 0.3)], 16, Color("e9ecef"))
			k.layer = "eau"
			k.lathe(Vector3(0, 0.52, 0), [Vector2(0.0, 0.0), Vector2(1.14, 0.0), Vector2(0.0, 0.01)], 16, Color(0.5, 0.85, 0.95, 0.8))
			k.layer = "base"
			for i in 6:
				var a := TAU * i / 6.0
				k.box(Vector3(cos(a) * 0.7, 0.56, sin(a) * 0.7), Vector3(0.08, 0.02, 0.08), BLANC, 0.0, false)
		"hammam":
			k.box(Vector3(0, 1.1, 0), Vector3(2.4, 2.2, 2.4), Color("e9ecef"))
			k.lathe(Vector3(0, 2.2, 0), [Vector2(1.1, 0.0), Vector2(0.8, 0.45), Vector2(0.0, 0.6)], 12, Color("e9ecef"))
			k.layer = "verre"
			k.box(Vector3(-1.21, 1.0, 0), Vector3(0.03, 1.8, 1.6), Color(0.8, 0.92, 0.95, 0.4), 0.0, false)
			k.layer = "base"
		"douche":
			k.box(Vector3(0, 0.03, 0), Vector3(0.9, 0.06, 0.9), Color("ced4da"), 0.0, false)
			k.tube(Vector3(-0.35, 0, -0.35), Vector3(-0.35, 2.1, -0.35), 0.03, 0.03, 6, METAL)
			k.box(Vector3(-0.2, 2.1, -0.2), Vector3(0.3, 0.04, 0.3), METAL, 0.0, false)
		"tisanerie":
			k.box(Vector3(0, 0.45, 0), Vector3(1.6, 0.9, 0.55), Color("d8e2dc"))
			for i in 4:
				k.lathe(Vector3(-0.55 + i * 0.36, 0.9, 0), [Vector2(0.0, 0.0), Vector2(0.1, 0.0), Vector2(0.11, 0.2), Vector2(0.0, 0.2)], 8, [Color("ffb4a2"), Color("b5e48c"), Color("ffd166"), BLANC][i])
		"presentoir_souvenirs":
			k.lathe(Vector3.ZERO, [Vector2(0.0, 0.0), Vector2(0.5, 0.0), Vector2(0.5, 0.1), Vector2(0.06, 0.12), Vector2(0.06, 1.7), Vector2(0.0, 1.7)], 10, METAL)
			for j in 4:
				for i in 6:
					var a := TAU * i / 6.0
					k.box(Vector3(cos(a) * 0.32, 0.45 + j * 0.35, sin(a) * 0.32), Vector3(0.18, 0.26, 0.04), [Color("e76f51"), Color("2a9d8f"), Color("e9c46a"), Color("8ecae6")][(i + j) % 4], 0.0, false)
		"journaux":
			k.box(Vector3(0, 0.6, 0), Vector3(1.2, 1.2, 0.4), BOIS)
			for j in 3:
				for i in 4:
					k.box(Vector3(-0.42 + i * 0.28, 0.35 + j * 0.35, 0.22), Vector3(0.22, 0.28, 0.02), [BLANC, Color("e5e5e5"), Color("ffd6a5"), Color("bde0fe")][(i + j) % 4], 0.0, false)
		"peluches":
			k.box(Vector3(0, 0.5, 0), Vector3(1.0, 1.0, 0.45), BOIS)
			for i in 4:
				var x := -0.35 + i * 0.23
				var c3: Color = [Color("c68b59"), Color("ffafcc"), Color("bde0fe"), Color("f8f9fa")][i]
				k.blob(Vector3(x, 1.12, 0), Vector3(0.1, 0.12, 0.09), c3, c3, 0.1, 0)
				k.blob(Vector3(x, 1.28, 0), Vector3(0.08, 0.08, 0.08), c3, c3, 0.1, 0)
		"tapis_course":
			k.box(Vector3(0, 0.15, 0), Vector3(0.8, 0.3, 1.9), Color("343a40"))
			k.box(Vector3(0, 0.31, 0.1), Vector3(0.6, 0.02, 1.5), NOIR, 0.0, false)
			for sx in [-0.35, 0.35]:
				k.box(Vector3(sx, 0.75, -0.75), Vector3(0.06, 0.9, 0.06), METAL, 0.0, false)
			k.box(Vector3(0, 1.2, -0.75), Vector3(0.75, 0.25, 0.15), Color("495057"))
			k.layer = "lumiere"
			k.box(Vector3(0, 1.25, -0.67), Vector3(0.4, 0.12, 0.01), Color("80ed99"), 0.0, false)
			k.layer = "base"
		"velo":
			k.box(Vector3(0, 0.08, 0), Vector3(0.4, 0.16, 1.2), Color("343a40"))
			k.box(Vector3(0, 0.45, 0.35), Vector3(0.12, 0.7, 0.12), Color("e63946"))
			k.box(Vector3(0, 0.45, -0.3), Vector3(0.1, 0.7, 0.1), Color("e63946"))
			k.box(Vector3(0, 0.85, 0.35), Vector3(0.3, 0.06, 0.25), NOIR)
			k.box(Vector3(0, 1.0, -0.35), Vector3(0.5, 0.05, 0.06), METAL, 0.0, false)
			k.lathe(Vector3(0, 0.35, -0.15), [Vector2(0.0, 0.0), Vector2(0.25, 0.0), Vector2(0.25, 0.06), Vector2(0.0, 0.06)], 10, NOIR, true, true, Callable(), 0.0)
		"banc_muscu":
			k.box(Vector3(0, 0.45, 0), Vector3(0.35, 0.1, 1.3), Color("1d3557"))
			k.box(Vector3(0, 0.22, 0), Vector3(0.1, 0.44, 1.0), METAL, 0.0, false)
			for sx in [-0.55, 0.55]:
				k.box(Vector3(sx * 0.6, 0.6, -0.45), Vector3(0.06, 1.2, 0.06), METAL, 0.0, false)
			k.box(Vector3(0, 1.15, -0.45), Vector3(1.6, 0.05, 0.05), METAL, 0.0, false)
			for sx in [-0.7, 0.7]:
				k.lathe(Vector3(sx, 1.15, -0.45), [Vector2(0.0, -0.05), Vector2(0.22, -0.05), Vector2(0.22, 0.05), Vector2(0.0, 0.05)], 10, NOIR)
		"sac_frappe":
			k.box(Vector3(0, 2.6, 0), Vector3(0.6, 0.06, 0.06), METAL, 0.0, false)
			k.tube(Vector3(0, 0.6, 0), Vector3(0, 1.7, 0), 0.22, 0.22, 10, Color("9d0208"))
			k.tube(Vector3(0, 1.7, 0), Vector3(0, 2.6, 0), 0.01, 0.01, 4, METAL)
		"miroir":
			k.box(Vector3(0, 1.3, 0.03), Vector3(3.0, 1.8, 0.05), METAL)
			k.layer = "verre"
			k.box(Vector3(0, 1.3, 0.06), Vector3(2.9, 1.7, 0.01), Color(0.85, 0.92, 0.98, 0.7), 0.0, false)
			k.layer = "base"
		"distributeur":
			k.box(Vector3(0, 0.95, 0), Vector3(0.9, 1.9, 0.8), Color("e63946"))
			k.layer = "lumiere"
			k.box(Vector3(-0.1, 1.15, 0.41), Vector3(0.55, 1.1, 0.01), Color("caf0f8"), 0.0, false)
			k.layer = "base"
		"vestiaire":
			for i in 4:
				k.box(Vector3(-0.75 + i * 0.5, 0.95, 0), Vector3(0.46, 1.9, 0.5), Color("4895ef").lerp(Color("3a0ca3"), i * 0.15))
				k.box(Vector3(-0.6 + i * 0.5, 1.2, 0.26), Vector3(0.04, 0.1, 0.02), METAL, 0.0, false)
			k.box(Vector3(0, 0.25, 0.7), Vector3(2.0, 0.08, 0.4), BOIS)
		"ecran":
			k.box(Vector3(0, 1.8, 0.04), Vector3(3.4, 2.0, 0.06), BLANC)
			k.layer = "lumiere"
			k.box(Vector3(0, 1.8, 0.08), Vector3(3.2, 1.8, 0.01), Color("bde0fe"), 0.0, false)
			k.layer = "base"
			k.box(Vector3(-0.6, 2.0, 0.09), Vector3(1.2, 0.5, 0.01), Color("ffd166"), 0.0, false)
			k.box(Vector3(0.7, 1.4, 0.09), Vector3(0.8, 0.6, 0.01), Color("90be6d"), 0.0, false)
		"pupitre":
			k.box(Vector3(0, 0.55, 0), Vector3(0.7, 1.1, 0.5), BOIS)
			k.box(Vector3(0, 1.15, 0.05), Vector3(0.75, 0.08, 0.6), BOIS_FONCE)
			k.tube(Vector3(0.2, 1.2, 0.2), Vector3(0.1, 1.5, 0.35), 0.015, 0.015, 4, NOIR)
		"enceinte":
			k.box(Vector3(0, 0.6, 0), Vector3(0.05, 1.2, 0.05), NOIR, 0.0, false)
			k.box(Vector3(0, 1.5, 0), Vector3(0.5, 0.7, 0.4), NOIR)
			k.lathe(Vector3(0, 1.45, 0.2), [Vector2(0.0, 0.0), Vector2(0.15, 0.0), Vector2(0.0, 0.02)], 10, Color("6c757d"))
		"cabine":
			k.box(Vector3(0, 1.1, 0), Vector3(1.4, 2.2, 1.6), Color("6c757d"))
			k.layer = "verre"
			k.box(Vector3(0, 1.4, 0.81), Vector3(1.2, 0.8, 0.02), Color(0.7, 0.85, 0.95, 0.5), 0.0, false)
			k.layer = "base"
		"parasol":
			k.box(Vector3(0, 1.1, 0), Vector3(0.06, 2.2, 0.06), BOIS, 0.0, false)
			var c4 := teinte if teinte != Color.WHITE else Color("e63946")
			k.lathe(Vector3(0, 1.95, 0), [Vector2(0.0, 0.0), Vector2(1.3, 0.0), Vector2(0.0, 0.45)], 8, c4)
			k.box(Vector3(0, 0.03, 0), Vector3(0.5, 0.06, 0.5), METAL, 0.0, false)
		"plongeoir":
			k.box(Vector3(0, 0.25, -0.6), Vector3(0.7, 0.5, 0.5), BLANC)
			k.box(Vector3(0, 0.55, 0.3), Vector3(0.55, 0.08, 2.2), Color("48cae4"))
		"palmier":
			k.tube(Vector3.ZERO, Vector3(0.3, 3.2, 0.1), 0.18, 0.12, 6, Color("8d6e63"))
			for i in 6:
				var a := TAU * i / 6.0
				k.beam(Vector3(0.3, 3.2, 0.1), Vector3(0.3 + cos(a) * 1.5, 2.6, 0.1 + sin(a) * 1.5), 0.45, 0.05, Color("2d6a4f").lerp(Color("74c69d"), (i % 2) * 0.4))
		"bouees":
			k.lathe(Vector3(0, -0.85, 0), [Vector2(0.15, 0.0), Vector2(0.4, 0.0), Vector2(0.4, 0.12), Vector2(0.15, 0.12)], 12, Color("ff006e"))
			k.lathe(Vector3(1.4, -0.85, 1.0), [Vector2(0.15, 0.0), Vector2(0.4, 0.0), Vector2(0.4, 0.12), Vector2(0.15, 0.12)], 12, Color("ffbe0b"))
			k.blob(Vector3(-1.2, -0.75, 1.6), Vector3(0.2, 0.2, 0.2), Color("3a86ff"), BLANC, 0.0, 1)
		"bar_piscine":
			k.box(Vector3(0, 0.55, 0), Vector3(2.4, 1.1, 0.7), Color("bc6c25"))
			k.box(Vector3(0, 1.12, 0), Vector3(2.6, 0.06, 0.85), Color("dda15e"))
			for sx in [-1.15, 1.15]:
				k.box(Vector3(sx, 1.6, -0.3), Vector3(0.08, 1.0, 0.08), BOIS, 0.0, false)
			k.box(Vector3(0, 2.15, -0.1), Vector3(2.8, 0.12, 1.4), Color("e9c46a"))
			for i in 3:
				k.box(Vector3(-0.8 + i * 0.8, 0.4, 0.75), Vector3(0.4, 0.08, 0.4), Color("e63946"))
				k.box(Vector3(-0.8 + i * 0.8, 0.2, 0.75), Vector3(0.06, 0.4, 0.06), METAL, 0.0, false)
		"toboggan":
			k.box(Vector3(0, 1.5, -1.5), Vector3(1.2, 0.1, 1.2), BLANC)
			for sx in [-0.5, 0.5]:
				for sz in [-2.0, -1.0]:
					k.box(Vector3(sx, 0.75, sz), Vector3(0.1, 1.5, 0.1), METAL, 0.0, false)
			k.beam(Vector3(0, 1.55, -0.9), Vector3(-0.8, 0.9, 1.0), 0.9, 0.15, Color("ffb703"))
			k.beam(Vector3(-0.8, 0.9, 1.0), Vector3(-2.6, 0.2, 1.6), 0.9, 0.15, Color("ffb703"))
		"balancoire":
			for sx in [-1.0, 1.0]:
				k.beam(Vector3(sx, 0, -0.6), Vector3(sx, 2.0, 0), 0.1, 0.1, Color("e63946"))
				k.beam(Vector3(sx, 0, 0.6), Vector3(sx, 2.0, 0), 0.1, 0.1, Color("e63946"))
			k.box(Vector3(0, 2.0, 0), Vector3(2.2, 0.1, 0.1), Color("e63946"))
			for sx in [-0.45, 0.45]:
				k.tube(Vector3(sx, 2.0, 0), Vector3(sx, 0.5, 0), 0.015, 0.015, 4, METAL)
				k.box(Vector3(sx, 0.48, 0), Vector3(0.45, 0.05, 0.25), Color("ffd166"))
		"toboggan_enfants":
			k.box(Vector3(0, 0.75, -0.8), Vector3(0.9, 0.08, 0.9), Color("3a86ff"))
			for sx in [-0.4, 0.4]:
				for sz in [-1.2, -0.4]:
					k.box(Vector3(sx, 0.37, sz), Vector3(0.08, 0.75, 0.08), Color("3a86ff"), 0.0, false)
			k.beam(Vector3(0, 0.78, -0.35), Vector3(0, 0.1, 1.2), 0.6, 0.08, Color("ffbe0b"))
			k.beam(Vector3(0, 0.0, -1.8), Vector3(0, 0.75, -1.25), 0.5, 0.06, Color("ff006e"))
		"bac_sable":
			k.box(Vector3(0, 0.12, 0), Vector3(2.4, 0.24, 2.0), BOIS)
			k.box(Vector3(0, 0.2, 0), Vector3(2.2, 0.06, 1.8), Color("f2cc8f"), 0.0, false)
			k.box(Vector3(0.4, 0.28, 0.3), Vector3(0.2, 0.15, 0.2), Color("e63946"))
			k.box(Vector3(-0.5, 0.26, -0.2), Vector3(0.3, 0.1, 0.12), Color("3a86ff"))
		"banc":
			k.box(Vector3(0, 0.45, 0), Vector3(1.6, 0.08, 0.45), BOIS)
			k.box(Vector3(0, 0.75, -0.2), Vector3(1.6, 0.4, 0.06), BOIS)
			for sx in [-0.7, 0.7]:
				k.box(Vector3(sx, 0.22, 0), Vector3(0.08, 0.45, 0.4), NOIR, 0.0, false)
		"massif":
			k.box(Vector3(0, 0.15, 0), Vector3(1.6, 0.3, 1.6), Color("6c584c"))
			for i in 9:
				var x := -0.5 + (i % 3) * 0.5
				var z := -0.5 + (i / 3) * 0.5
				k.blob(Vector3(x, 0.45, z), Vector3(0.22, 0.2, 0.22), Color("2d6a4f"), [Color("ff006e"), Color("ffbe0b"), Color("8338ec"), BLANC][i % 4], 0.15, 0)
		"kiosque":
			k.lathe(Vector3.ZERO, [Vector2(0.0, 0.0), Vector2(2.0, 0.0), Vector2(2.0, 0.2), Vector2(0.0, 0.2)], 8, Color("e9e4da"))
			for i in 8:
				var a := TAU * i / 8.0
				k.box(Vector3(cos(a) * 1.8, 1.3, sin(a) * 1.8), Vector3(0.1, 2.2, 0.1), BLANC, 0.0, false)
			k.lathe(Vector3(0, 2.4, 0), [Vector2(2.3, 0.0), Vector2(0.0, 1.2)], 8, Color("2a9d8f"))
		"lampadaire":
			k.tube(Vector3.ZERO, Vector3(0, 3.2, 0), 0.06, 0.05, 6, Color("343a40"))
			k.layer = "lumiere"
			k.box(Vector3(0, 3.3, 0), Vector3(0.3, 0.3, 0.3), Color("fff3b0"), 0.0, false)
			k.layer = "base"
			k.box(Vector3(0, 3.5, 0), Vector3(0.4, 0.08, 0.4), Color("343a40"), 0.0, false)
		"auvent":
			for sx in [-1.6, 1.6]:
				k.box(Vector3(sx, 1.4, 2.2), Vector3(0.1, 2.8, 0.1), OR, 0.0, false)
			k.box(Vector3(0, 2.85, 0.9), Vector3(3.6, 0.15, 3.0), Color("7b2d26"))
			k.box(Vector3(0, 2.7, 2.4), Vector3(3.6, 0.3, 0.05), Color("7b2d26").darkened(0.2))
		"borne_recharge":
			k.box(Vector3(0, 0.7, 0), Vector3(0.4, 1.4, 0.3), Color("2a9d8f"))
			k.layer = "lumiere"
			k.box(Vector3(0, 1.1, 0.16), Vector3(0.25, 0.15, 0.01), Color("80ed99"), 0.0, false)
			k.layer = "base"
		"guerite":
			k.box(Vector3(0, 1.0, 0), Vector3(1.3, 2.0, 1.3), Color("1d3557"))
			k.layer = "verre"
			k.box(Vector3(0, 1.3, 0.66), Vector3(1.0, 0.7, 0.02), Color(0.7, 0.85, 0.95, 0.5), 0.0, false)
			k.layer = "base"
			k.box(Vector3(0, 2.05, 0), Vector3(1.6, 0.12, 1.6), OR)
		"navette":
			voiture(k, Vector3.ZERO, Color("f8f9fa"), true)
		"voiture":
			voiture(k, Vector3.ZERO, teinte, false)
		_:
			ModelesRestaurant.dessiner(k, nom, teinte)
	k.xf = avant


## Places des clients d'un modèle (toutes les bibliothèques).
static func places(nom: String) -> Array:
	if PLACES.has(nom):
		return PLACES[nom]
	if ModelesRestaurant.PLACES.has(nom):
		return ModelesRestaurant.PLACES[nom]
	if ModelesCaserne.PLACES.has(nom):
		return ModelesCaserne.PLACES[nom]
	if ModelesCommissariat.PLACES.has(nom):
		return ModelesCommissariat.PLACES[nom]
	if ModelesHopital.PLACES.has(nom):
		return ModelesHopital.PLACES[nom]
	var pu: Array = ModelesUsine.PLACES.get(nom, [])
	if not pu.is_empty():
		return pu
	if ModelesSupermarche.PLACES.has(nom):
		return ModelesSupermarche.PLACES[nom]
	if ModelesImmeuble.PLACES.has(nom):
		return ModelesImmeuble.PLACES[nom]
	return ModelesParc.PLACES.get(nom, [])


static func _plante(k: LpKit, taille: float) -> void:
	k.lathe(Vector3.ZERO, [Vector2(0.0, 0.0), Vector2(0.2, 0.0), Vector2(0.26, 0.45), Vector2(0.0, 0.45)], 8, Color("c0703f"))
	k.blob(Vector3(0, 0.45 + 0.4 * taille, 0), Vector3(0.38, 0.5, 0.38) * taille, Color("2f6b35"), Color("74c69d"), 0.22, 1)


static func _fauteuil(k: LpKit, p: Vector3, rot: float, col: Color) -> void:
	var dos := Vector3(sin(rot), 0, cos(rot)) * -0.3
	var large := absf(cos(rot)) > 0.5
	k.box(p + Vector3(0, 0.25, 0), Vector3(0.8, 0.4, 0.8), col)
	k.box(p + dos + Vector3(0, 0.6, 0), Vector3(0.8 if large else 0.2, 0.6, 0.2 if large else 0.8), col.darkened(0.12))


## Voiture (ou minibus) le long de +Z.
static func voiture(k: LpKit, p: Vector3, col: Color, minibus := false) -> void:
	var l := 4.8 if minibus else 3.8
	var h := 1.0 if minibus else 0.65
	k.box(p + Vector3(0, 0.5, 0), Vector3(1.75, 0.6, l), col)
	k.box(p + Vector3(0, 0.8 + h * 0.5, -0.1 if not minibus else 0.0), Vector3(1.6, h, l * (0.55 if not minibus else 0.9)), col.lightened(0.08))
	k.layer = "verre"
	k.box(p + Vector3(0, 0.8 + h * 0.55, -0.1 if not minibus else 0.0), Vector3(1.62, h * 0.6, l * (0.5 if not minibus else 0.85)), Color(0.55, 0.7, 0.82, 0.75), 0.0, false)
	k.layer = "base"
	for sx in [-0.8, 0.8]:
		for sz in [-l * 0.32, l * 0.32]:
			k.box(p + Vector3(sx, 0.3, sz), Vector3(0.22, 0.6, 0.6), NOIR)
	k.layer = "lumiere"
	k.box(p + Vector3(-0.55, 0.6, l * 0.5), Vector3(0.3, 0.12, 0.02), Color("fff3b0"), 0.0, false)
	k.box(p + Vector3(0.55, 0.6, l * 0.5), Vector3(0.3, 0.12, 0.02), Color("fff3b0"), 0.0, false)
	k.layer = "base"
	if minibus:
		k.box(p + Vector3(0.88, 1.1, 0), Vector3(0.02, 0.25, l * 0.8), Color("1d3557"), 0.0, false)
