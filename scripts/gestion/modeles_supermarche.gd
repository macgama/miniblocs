class_name ModelesSupermarche
extends RefCounted
## Objets low-poly du supermarché (caisses, gondoles, meubles froids, étals,
## chariots, drive…), mêmes conventions que GestionModeles : origine au sol au
## centre de l'objet, face avant vers +Z, le kit est déjà placé (k.xf).

const GRIS := Color("5c636a")
const GRIS_C := Color("c3ccd4")
const NOIR := Color("26262b")
const BLANC := Color("f6f4ef")
const ROUGE := Color("e63946")
const VERT := Color("2a9d8f")
const BLEU := Color("1d6fa3")
const JAUNE := Color("f2b705")
const BOIS := Color("b08968")
const CARTON := Color("c9a46c")
const VERRE := Color(0.75, 0.88, 0.95, 0.35)
## Couleurs des produits en rayon.
const PRODUITS := [Color("e63946"), Color("f4a261"), Color("2a9d8f"), Color("457b9d"), Color("e9c46a"), Color("8ac926"), Color("6d597a"), Color("f6f4ef")]

## Places des visiteurs : modèle → [[x, z, angle, assis]] locaux.
const PLACES := {
	"caisse_auto": [[0.0, 0.7, PI, false]],
	"etal_fruits": [[0.0, 1.1, PI, false]],
	"balance_fruits": [[0.0, 0.6, PI, false]],
	"meuble_froid": [[-0.8, 0.9, PI, false], [0.8, 0.9, PI, false]],
	"bac_surgele": [[0.0, 0.9, PI, false]],
	"comptoir_boucherie": [[-0.8, 0.9, PI, false], [0.8, 0.9, PI, false]],
	"tete_gondole": [[0.0, 0.9, PI, false]],
	"borne_drive": [[0.0, 0.6, PI, false]],
	"consigne_bouteilles": [[0.0, 0.7, PI, false]],
}


## Rangée de produits colorés sur une tablette (largeur l, à la hauteur y).
static func _produits(k: LpKit, x0: float, l: float, y: float, z: float, h := 0.24, prof := 0.32, graine := 0) -> void:
	var n := maxi(2, int(l / 0.22))
	var w := l / n
	for i in n:
		var c: Color = PRODUITS[(i * 3 + graine) % PRODUITS.size()]
		k.box(Vector3(x0 + w * (i + 0.5), y + h * 0.5, z), Vector3(w * 0.85, h * (0.75 + 0.25 * ((i + graine) % 2)), prof), c, 0.0, false)


## Rayonnage double face : 4 tablettes de produits de chaque côté (long axe X).
static func gondole(k: LpKit, long: float, teinte := Color.WHITE, graine := 0) -> void:
	k.box(Vector3(0, 0.08, 0), Vector3(long, 0.16, 0.9), GRIS)
	k.box(Vector3(0, 0.95, 0), Vector3(long, 1.7, 0.08), GRIS_C)
	for e in 4:
		var y := 0.18 + e * 0.42
		k.box(Vector3(0, y, 0.24), Vector3(long, 0.03, 0.42), GRIS_C, 0.0, false)
		k.box(Vector3(0, y, -0.24), Vector3(long, 0.03, 0.42), GRIS_C, 0.0, false)
		_produits(k, -long * 0.5, long, y + 0.02, 0.26, 0.26, 0.3, graine + e)
		_produits(k, -long * 0.5, long, y + 0.02, -0.26, 0.26, 0.3, graine + e + 2)
	k.box(Vector3(0, 1.84, 0), Vector3(long, 0.1, 0.2), teinte if teinte != Color.WHITE else ROUGE, 0.0, false)


static func dessiner(k: LpKit, nom: String, teinte := Color.WHITE) -> void:
	match nom:
		"caddies":
			# Chariots emboîtés.
			for i in 5:
				var z := -0.9 + i * 0.32
				k.box(Vector3(0, 0.62, z), Vector3(0.55, 0.42, 0.7), GRIS_C, 0.0, false)
				k.box(Vector3(0, 0.42, z), Vector3(0.5, 0.03, 0.68), GRIS, 0.0, false)
				k.beam(Vector3(-0.28, 0.9, z + 0.38), Vector3(0.28, 0.9, z + 0.38), 0.04, 0.04, ROUGE)
			for sx in [-0.22, 0.22]:
				for sz in [-1.1, 0.9]:
					k.tube(Vector3(sx, 0.0, sz), Vector3(sx, 0.08, sz), 0.05, 0.05, 6, NOIR)
		"panier_pile":
			for i in 4:
				k.box(Vector3(0, 0.12 + i * 0.12, 0), Vector3(0.55, 0.12, 0.38), [ROUGE, BLEU, ROUGE, VERT][i], 0.0, false)
			k.beam(Vector3(-0.25, 0.62, 0), Vector3(0.25, 0.62, 0), 0.03, 0.03, NOIR)
		"portique_antivol":
			for sx in [-0.45, 0.45]:
				k.box(Vector3(sx, 0.85, 0), Vector3(0.06, 1.7, 0.4), GRIS_C)
				k.layer = "lumiere"
				k.box(Vector3(sx, 1.6, 0.21), Vector3(0.05, 0.08, 0.01), Color("ff595e"), 0.0, false)
				k.layer = "base"
		"caisse_tapis":
			# Tapis roulant, siège de la caissière, scanner, séparateur.
			k.box(Vector3(0, 0.42, -0.2), Vector3(0.7, 0.84, 2.4), GRIS_C)
			k.box(Vector3(0, 0.86, -0.4), Vector3(0.55, 0.03, 1.8), NOIR, 0.0, false)
			k.box(Vector3(-0.55, 0.38, 0.6), Vector3(0.45, 0.76, 0.6), GRIS)
			k.box(Vector3(-0.1, 0.92, 0.7), Vector3(0.3, 0.12, 0.3), NOIR, 0.0, false)
			k.layer = "lumiere"
			k.box(Vector3(-0.1, 0.99, 0.7), Vector3(0.2, 0.01, 0.2), Color("ff595e"), 0.0, false)
			k.layer = "base"
			k.tube(Vector3(0.3, 0.86, 0.9), Vector3(0.3, 1.9, 0.9), 0.03, 0.03, 5, GRIS)
			k.box(Vector3(0.3, 1.95, 0.9), Vector3(0.28, 0.28, 0.06), teinte if teinte != Color.WHITE else ROUGE, 0.0, false)
			k.box(Vector3(0.0, 0.9, -1.0), Vector3(0.5, 0.06, 0.05), BLEU, 0.0, false)
		"caisse_auto":
			k.box(Vector3(0, 0.45, 0), Vector3(0.7, 0.9, 0.55), BLANC)
			k.box(Vector3(0, 0.92, 0.05), Vector3(0.6, 0.04, 0.5), GRIS, 0.0, false)
			k.box(Vector3(0, 1.35, -0.18), Vector3(0.45, 0.35, 0.05), NOIR)
			k.layer = "lumiere"
			k.box(Vector3(0, 1.35, -0.15), Vector3(0.38, 0.28, 0.01), Color("8ecae6"), 0.0, false)
			k.box(Vector3(0, 1.95, -0.2), Vector3(0.1, 0.1, 0.1), Color("80ed99"), 0.0, false)
			k.layer = "base"
			k.tube(Vector3(0, 1.5, -0.2), Vector3(0, 1.9, -0.2), 0.02, 0.02, 4, GRIS)
			k.box(Vector3(0.48, 0.6, 0.0), Vector3(0.3, 0.04, 0.45), GRIS_C, 0.0, false)
		"gondole":
			gondole(k, 3.6, teinte)
		"tete_gondole":
			# Bout de rayon en promotion, panneau jaune.
			k.box(Vector3(0, 0.08, 0), Vector3(1.4, 0.16, 0.7), GRIS)
			for e in 3:
				_produits(k, -0.65, 1.3, 0.18 + e * 0.42, 0.0, 0.3, 0.55, e)
				k.box(Vector3(0, 0.17 + e * 0.42, 0), Vector3(1.35, 0.02, 0.6), GRIS_C, 0.0, false)
			k.box(Vector3(0, 1.75, 0.0), Vector3(1.2, 0.4, 0.05), JAUNE, 0.0, false)
			k.box(Vector3(0, 1.75, 0.03), Vector3(0.6, 0.18, 0.01), ROUGE, 0.0, false)
		"panneau_promo":
			# Panneau suspendu au plafond.
			k.tube(Vector3(-0.6, 2.4, 0), Vector3(-0.6, 3.0, 0), 0.01, 0.01, 3, GRIS)
			k.tube(Vector3(0.6, 2.4, 0), Vector3(0.6, 3.0, 0), 0.01, 0.01, 3, GRIS)
			k.box(Vector3(0, 2.25, 0), Vector3(1.6, 0.45, 0.04), teinte if teinte != Color.WHITE else ROUGE)
			k.box(Vector3(0, 2.25, 0.025), Vector3(1.1, 0.15, 0.01), BLANC, 0.0, false)
		"silos_vrac":
			for i in 4:
				var x := -0.75 + i * 0.5
				k.box(Vector3(x, 0.45, 0), Vector3(0.42, 0.9, 0.4), GRIS)
				k.layer = "verre"
				k.tube(Vector3(x, 0.95, 0), Vector3(x, 1.65, 0), 0.17, 0.17, 8, VERRE)
				k.layer = "base"
				k.tube(Vector3(x, 0.95, 0), Vector3(x, 1.35, 0), 0.15, 0.15, 8, [BOIS, JAUNE, Color("6f4518"), BLANC][i])
		"consigne_bouteilles":
			k.box(Vector3(0, 0.9, 0), Vector3(0.9, 1.8, 0.6), VERT)
			k.box(Vector3(0, 1.1, 0.31), Vector3(0.3, 0.3, 0.02), NOIR, 0.0, false)
			k.layer = "lumiere"
			k.box(Vector3(0, 1.55, 0.31), Vector3(0.4, 0.2, 0.01), Color("80ed99"), 0.0, false)
			k.layer = "base"
		"etal_fruits":
			# Étal incliné en bois avec cagettes de fruits.
			k.box(Vector3(0, 0.4, 0), Vector3(2.4, 0.8, 1.2), BOIS)
			var cols := [Color("e63946"), Color("f4a261"), Color("8ac926"), Color("ffca3a"), Color("6a4c93"), Color("2a9d8f")]
			for i in 3:
				for j in 2:
					var p := Vector3(-0.8 + i * 0.8, 0.9 + j * 0.18, 0.25 - j * 0.45)
					k.box(p, Vector3(0.72, 0.16, 0.42), CARTON, 0.0, false)
					k.blob(p + Vector3(0, 0.1, 0), Vector3(0.32, 0.1, 0.18), cols[(i * 2 + j) % cols.size()], cols[(i * 2 + j) % cols.size()].lightened(0.2), 0.3, 0)
			k.box(Vector3(0, 1.5, -0.5), Vector3(2.3, 0.3, 0.05), Color("3a5a40"), 0.0, false)
		"balance_fruits":
			k.tube(Vector3(0, 0, 0), Vector3(0, 0.9, 0), 0.05, 0.05, 6, GRIS)
			k.box(Vector3(0, 0.95, 0), Vector3(0.45, 0.06, 0.4), GRIS_C)
			k.box(Vector3(0, 1.25, -0.15), Vector3(0.3, 0.25, 0.08), BLANC)
			k.layer = "lumiere"
			k.box(Vector3(0, 1.25, -0.1), Vector3(0.22, 0.15, 0.01), Color("8ecae6"), 0.0, false)
			k.layer = "base"
		"meuble_froid":
			# Meuble réfrigéré ouvert, produits laitiers.
			k.box(Vector3(0, 1.0, -0.2), Vector3(2.4, 2.0, 0.6), BLANC)
			for e in 4:
				var y := 0.35 + e * 0.38
				k.box(Vector3(0, y, 0.05), Vector3(2.3, 0.03, 0.5), GRIS_C, 0.0, false)
				_produits(k, -1.1, 2.2, y + 0.02, 0.05, 0.22, 0.35, e * 2 + 1)
			k.layer = "lumiere"
			k.box(Vector3(0, 1.98, 0.1), Vector3(2.3, 0.05, 0.05), Color("caf0f8"), 0.0, false)
			k.layer = "base"
			k.box(Vector3(0, 2.15, 0.0), Vector3(2.4, 0.25, 0.7), BLEU)
		"bac_surgele":
			k.box(Vector3(0, 0.4, 0), Vector3(2.0, 0.8, 0.9), BLANC)
			k.box(Vector3(0, 0.79, 0), Vector3(1.9, 0.02, 0.8), Color("caf0f8"), 0.0, false)
			_produits(k, -0.9, 1.8, 0.62, -0.15, 0.14, 0.3, 3)
			k.layer = "verre"
			k.box(Vector3(0, 0.86, 0), Vector3(1.9, 0.02, 0.8), VERRE, 0.0, false)
			k.layer = "base"
		"comptoir_boucherie":
			# Vitrine réfrigérée bombée, viandes et poissons sur glace.
			k.box(Vector3(0, 0.45, 0), Vector3(2.6, 0.9, 0.9), BLANC)
			k.box(Vector3(0, 0.92, 0.05), Vector3(2.5, 0.04, 0.75), Color("e9ecef"), 0.0, false)
			for i in 6:
				k.box(Vector3(-1.05 + i * 0.42, 0.99, 0.1), Vector3(0.36, 0.08, 0.5), [Color("9d0208"), Color("d00000"), Color("ffb4a2"), Color("adb5bd"), Color("9d0208"), Color("e5989b")][i], 0.0, false)
			k.layer = "verre"
			k.box(Vector3(0, 1.25, 0.25), Vector3(2.5, 0.5, 0.03), VERRE, 0.0, false)
			k.layer = "base"
			k.box(Vector3(0, 1.52, 0.0), Vector3(2.6, 0.04, 0.6), GRIS_C, 0.0, false)
		"presse_carton":
			k.box(Vector3(0, 1.0, 0), Vector3(1.2, 2.0, 0.9), Color("e9c46a"))
			k.box(Vector3(0, 0.6, 0.46), Vector3(1.0, 0.9, 0.02), NOIR, 0.0, false)
			k.box(Vector3(0, 0.35, 0.47), Vector3(0.9, 0.4, 0.02), CARTON, 0.0, false)
			k.box(Vector3(0.45, 1.6, 0.46), Vector3(0.15, 0.15, 0.02), ROUGE, 0.0, false)
		"casiers_drive":
			# Casiers à colis ou à courses, portes numérotées.
			k.box(Vector3(0, 1.0, 0), Vector3(2.0, 2.0, 0.6), teinte if teinte != Color.WHITE else VERT)
			for i in 4:
				for j in 3:
					k.box(Vector3(-0.72 + i * 0.48, 0.4 + j * 0.6, 0.31), Vector3(0.42, 0.52, 0.02), GRIS_C, 0.0, false)
			k.layer = "lumiere"
			k.box(Vector3(0, 1.9, 0.32), Vector3(0.6, 0.12, 0.01), Color("80ed99"), 0.0, false)
			k.layer = "base"
		"abri_chariots":
			for sx in [-1.2, 1.2]:
				k.tube(Vector3(sx, 0, -0.6), Vector3(sx, 2.0, -0.6), 0.04, 0.04, 5, GRIS)
				k.tube(Vector3(sx, 0, 0.6), Vector3(sx, 2.0, 0.6), 0.04, 0.04, 5, GRIS)
			k.box(Vector3(0, 2.05, 0), Vector3(2.6, 0.06, 1.4), ROUGE)
			for i in 3:
				k.box(Vector3(-0.6 + i * 0.6, 0.6, 0), Vector3(0.5, 0.45, 1.0), GRIS_C, 0.0, false)
		"borne_drive":
			k.box(Vector3(0, 0.75, 0), Vector3(0.6, 1.5, 0.4), teinte if teinte != Color.WHITE else ROUGE)
			k.box(Vector3(0, 1.2, 0.21), Vector3(0.4, 0.3, 0.02), NOIR, 0.0, false)
			k.layer = "lumiere"
			k.box(Vector3(0, 1.2, 0.22), Vector3(0.34, 0.24, 0.01), Color("8ecae6"), 0.0, false)
			k.layer = "base"
		_:
			ModelesParc.dessiner(k, nom, teinte)
