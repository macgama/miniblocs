class_name ModelesUsine
extends RefCounted
## Objets low-poly de l'usine (machines, chaîne, stock, labo, quai, épuration,
## énergie), mêmes conventions que GestionModeles : origine au sol au centre
## de l'objet, face avant vers +Z, le kit est déjà placé (k.xf).

const ACIER := Color("8d99a6")
const ACIER_C := Color("c3ccd4")
const GRIS := Color("5c636a")
const NOIR := Color("26262b")
const BLANC := Color("f6f4ef")
const JAUNE := Color("f2b705")
const ORANGE := Color("e76f51")
const BLEU := Color("1d6fa3")
const VERT := Color("2a9d8f")
const BOIS := Color("b08968")
const CARTON := Color("c9a46c")

## Places des visiteurs : modèle → [[x, z, angle, assis]] locaux.
const PLACES := {
	"passerelle": [[-3.0, 0.0, PI, false], [-1.0, 0.0, PI, false], [1.0, 0.0, PI, false], [3.0, 0.0, PI, false]],
	"vitrine_produit": [[0.0, 0.9, PI, false]],
	"abri_chauffeurs": [[-0.5, 0.1, 0.0, true], [0.5, 0.1, 0.0, true]],
	"table_dessin": [[0.0, 0.8, PI, true]],
	"banc_essai": [[0.0, 1.0, PI, false]],
}


static func dessiner(k: LpKit, nom: String, teinte := Color.WHITE) -> void:
	match nom:
		# --- Accueil ---------------------------------------------------------------------
		"pointeuse":
			k.box(Vector3(0, 1.3, 0.08), Vector3(0.4, 0.5, 0.16), GRIS)
			k.layer = "lumiere"
			k.box(Vector3(0, 1.42, 0.165), Vector3(0.28, 0.12, 0.01), Color("80ed99"), 0.0, false)
			k.layer = "base"
			k.box(Vector3(0.3, 1.2, 0.05), Vector3(0.14, 0.6, 0.06), Color("adb5bd"), 0.0, false)
		"panneau_jours":
			k.box(Vector3(0, 1.9, 0.03), Vector3(1.4, 0.7, 0.05), VERT)
			k.box(Vector3(0, 2.05, 0.06), Vector3(1.2, 0.16, 0.01), BLANC, 0.0, false)
			k.layer = "lumiere"
			k.box(Vector3(0, 1.76, 0.06), Vector3(0.6, 0.26, 0.01), Color("ffd166"), 0.0, false)
			k.layer = "base"
		# --- Atelier ---------------------------------------------------------------------
		"extracteur":
			k.box(Vector3(0, 2.8, 0.4), Vector3(1.2, 0.5, 0.8), ACIER_C)
			k.tube(Vector3(0, 3.05, 0.4), Vector3(0, 4.2, 0.4), 0.3, 0.3, 8, ACIER)
			k.lathe(Vector3(0, 1.9, 0.4), [Vector2(0.0, 0.0), Vector2(0.55, 0.0), Vector2(0.2, 0.6), Vector2(0.0, 0.62)], 8, ACIER_C)
		"pont_roulant":
			for sx in [-7.6, 7.6]:
				k.box(Vector3(sx, 2.3, 0), Vector3(0.25, 4.6, 0.25), JAUNE)
				k.box(Vector3(sx, 4.5, 0), Vector3(0.3, 0.3, 7.0), JAUNE)
			k.box(Vector3(0, 4.75, 0.6), Vector3(15.4, 0.35, 0.4), ORANGE)
			k.box(Vector3(-1.5, 4.5, 0.6), Vector3(0.8, 0.4, 0.7), GRIS)
			k.tube(Vector3(-1.5, 4.3, 0.6), Vector3(-1.5, 2.6, 0.6), 0.03, 0.03, 4, NOIR)
			k.box(Vector3(-1.5, 2.5, 0.6), Vector3(0.3, 0.2, 0.2), JAUNE)
		"presse":
			k.box(Vector3(0, 0.4, 0), Vector3(1.6, 0.8, 1.2), BLEU)
			for sx in [-0.65, 0.65]:
				k.box(Vector3(sx, 1.5, 0), Vector3(0.25, 1.6, 0.25), BLEU.darkened(0.2))
			k.box(Vector3(0, 2.4, 0), Vector3(1.7, 0.5, 1.2), BLEU)
			k.tube(Vector3(0, 2.15, 0), Vector3(0, 1.4, 0), 0.18, 0.18, 8, ACIER_C)
			k.box(Vector3(0, 1.3, 0), Vector3(1.0, 0.15, 0.8), ACIER)
			k.box(Vector3(0, 0.85, 0.75), Vector3(1.4, 0.06, 0.12), JAUNE, 0.0, false)
		"machine_outil":
			k.box(Vector3(0, 0.55, 0), Vector3(2.0, 1.1, 1.2), Color("e9ecef"))
			k.box(Vector3(0, 1.45, -0.1), Vector3(2.0, 0.7, 1.0), Color("dee2e6"))
			k.layer = "verre"
			k.box(Vector3(-0.2, 1.3, 0.42), Vector3(1.2, 0.8, 0.02), Color(0.7, 0.85, 0.95, 0.4), 0.0, false)
			k.layer = "base"
			k.box(Vector3(0.75, 1.3, 0.45), Vector3(0.35, 0.5, 0.08), NOIR)
			k.layer = "lumiere"
			k.box(Vector3(0.75, 1.38, 0.495), Vector3(0.28, 0.22, 0.01), Color("8ecae6"), 0.0, false)
			k.box(Vector3(0.95, 1.95, -0.2), Vector3(0.08, 0.08, 0.08), Color("57cc99"), 0.0, false)
			k.layer = "base"
			k.box(Vector3(0, 1.12, 0.5), Vector3(1.9, 0.05, 0.2), BLEU, 0.0, false)
		"four_indus":
			k.box(Vector3(0, 1.0, 0), Vector3(2.0, 2.0, 1.8), Color("6c757d"))
			k.box(Vector3(0, 0.9, 0.92), Vector3(1.2, 1.2, 0.06), GRIS)
			k.layer = "lumiere"
			k.box(Vector3(0, 0.9, 0.96), Vector3(0.9, 0.12, 0.01), Color("ff7b00"), 0.0, false)
			k.layer = "base"
			k.tube(Vector3(0.6, 2.0, -0.4), Vector3(0.6, 3.6, -0.4), 0.15, 0.15, 6, ACIER)
			k.box(Vector3(-0.8, 1.7, 0.92), Vector3(0.3, 0.3, 0.05), JAUNE, 0.0, false)
		"robot_bras":
			k.box(Vector3(0, 0.3, 0), Vector3(0.9, 0.6, 0.9), GRIS)
			k.tube(Vector3(0, 0.6, 0), Vector3(0, 0.85, 0), 0.32, 0.3, 8, ORANGE)
			k.beam(Vector3(0, 0.85, 0), Vector3(0.1, 1.85, 0.2), 0.24, 0.24, ORANGE)
			k.beam(Vector3(0.1, 1.85, 0.2), Vector3(0.1, 1.6, 0.95), 0.18, 0.18, ORANGE)
			k.box(Vector3(0.1, 1.5, 1.0), Vector3(0.14, 0.2, 0.14), NOIR)
			k.layer = "lumiere"
			k.box(Vector3(0.1, 1.38, 1.0), Vector3(0.06, 0.04, 0.06), Color("4cc9f0"), 0.0, false)
			k.layer = "base"
			for i in 4:
				k.box(Vector3(-0.55 + i * 0.37, 0.03, 0.62), Vector3(0.2, 0.012, 0.08), JAUNE, 0.0, false)
		"passerelle":
			for sx in [-3.8, 3.8]:
				k.box(Vector3(sx, 1.2, 0), Vector3(0.12, 2.4, 0.12), JAUNE)
			k.box(Vector3(0, 2.4, 0), Vector3(8.0, 0.1, 1.1), Color("adb5bd"))
			for sz in [-0.5, 0.5]:
				k.box(Vector3(0, 3.4, sz), Vector3(8.0, 0.05, 0.05), JAUNE, 0.0, false)
				for i in 9:
					k.box(Vector3(-4.0 + i, 2.9, sz), Vector3(0.04, 1.0, 0.04), JAUNE, 0.0, false)
		# --- Chaîne ----------------------------------------------------------------------
		"convoyeur":
			k.box(Vector3(0, 0.8, 0), Vector3(12.0, 0.12, 0.8), NOIR)
			k.box(Vector3(0, 0.72, 0), Vector3(12.2, 0.12, 0.9), ACIER)
			for i in 7:
				k.box(Vector3(-5.6 + i * 1.86, 0.35, 0), Vector3(0.1, 0.7, 0.8), ACIER, 0.0, false)
			for i in 8:
				k.box(Vector3(-5.2 + i * 1.5, 1.02, 0), Vector3(0.5, 0.32, 0.45), [CARTON, teinte if teinte != Color.WHITE else Color("90be6d"), CARTON][i % 3])
		"emballeuse":
			k.box(Vector3(0, 0.9, 0), Vector3(1.6, 1.8, 1.4), BLEU)
			k.layer = "verre"
			k.box(Vector3(0, 1.1, 0.71), Vector3(1.2, 1.0, 0.02), Color(0.7, 0.85, 0.95, 0.4), 0.0, false)
			k.layer = "base"
			k.box(Vector3(0, 1.85, 0), Vector3(1.0, 0.1, 1.0), JAUNE, 0.0, false)
			for i in 3:
				k.box(Vector3(-0.4 + i * 0.4, 0.8, 0.4), Vector3(0.3, 0.3, 0.3), CARTON)
		"agv":
			k.box(Vector3(0, 0.2, 0), Vector3(0.9, 0.3, 1.3), ORANGE)
			k.box(Vector3(0, 0.37, 0), Vector3(0.85, 0.04, 1.2), NOIR, 0.0, false)
			k.box(Vector3(0, 0.55, 0), Vector3(0.6, 0.32, 0.6), CARTON)
			k.layer = "lumiere"
			k.box(Vector3(0, 0.25, 0.66), Vector3(0.4, 0.05, 0.01), Color("4cc9f0"), 0.0, false)
			k.layer = "base"
		# --- Stock et entrepôt -----------------------------------------------------------
		"rack_palettes":
			for sx in [-1.4, 1.4]:
				for sz in [-0.45, 0.45]:
					k.box(Vector3(sx, 1.6, sz), Vector3(0.08, 3.2, 0.08), BLEU, 0.0, false)
			for y in [0.1, 1.15, 2.2]:
				k.box(Vector3(0, y + 0.05, -0.45), Vector3(2.9, 0.1, 0.08), ORANGE, 0.0, false)
				k.box(Vector3(0, y + 0.05, 0.45), Vector3(2.9, 0.1, 0.08), ORANGE, 0.0, false)
				for i in 2:
					k.box(Vector3(-0.7 + i * 1.4, y + 0.16, 0), Vector3(1.2, 0.12, 0.85), BOIS, 0.0, false)
					k.box(Vector3(-0.7 + i * 1.4, y + 0.55, 0), Vector3(1.1, 0.66, 0.8), [CARTON, Color("d8c3a5"), Color("a3b18a")][(i + int(y)) % 3])
		"chariot_elevateur":
			k.box(Vector3(0, 0.45, -0.1), Vector3(1.0, 0.6, 1.6), JAUNE)
			k.box(Vector3(0, 0.95, -0.5), Vector3(0.9, 0.5, 0.6), NOIR)
			for sx in [-0.42, 0.42]:
				k.box(Vector3(sx, 1.3, -0.1), Vector3(0.06, 1.3, 0.06), NOIR, 0.0, false)
			k.box(Vector3(0, 1.95, -0.1), Vector3(0.9, 0.06, 0.9), NOIR, 0.0, false)
			for sx in [-0.3, 0.3]:
				k.box(Vector3(sx, 0.12, 0.95), Vector3(0.12, 0.05, 0.9), GRIS, 0.0, false)
			k.box(Vector3(0, 1.2, 0.7), Vector3(0.9, 1.6, 0.08), GRIS, 0.0, false)
			for sx in [-0.5, 0.5]:
				for sz in [-0.6, 0.4]:
					k.tube(Vector3(sx, 0.2, sz), Vector3(sx * 1.1, 0.2, sz), 0.2, 0.2, 8, NOIR)
		"big_bags":
			for i in 2:
				k.box(Vector3(-0.55 + i * 1.1, 0.5, 0), Vector3(1.0, 1.0, 1.0), Color("f1faee"))
				k.box(Vector3(-0.55 + i * 1.1, 1.02, 0), Vector3(0.5, 0.1, 0.5), Color("e9ecef"), 0.0, false)
				for sx in [-0.4, 0.4]:
					k.box(Vector3(-0.55 + i * 1.1 + sx, 1.1, 0), Vector3(0.06, 0.2, 0.06), BLEU, 0.0, false)
		"silo_petit":
			for a in 4:
				var ang := TAU * a / 4.0 + PI * 0.25
				k.box(Vector3(cos(ang) * 0.7, 0.8, sin(ang) * 0.7), Vector3(0.1, 1.6, 0.1), GRIS, 0.0, false)
			k.lathe(Vector3(0, 0.8, 0), [Vector2(0.0, 0.0), Vector2(0.1, 0.0), Vector2(0.9, 0.9), Vector2(0.9, 3.2), Vector2(0.6, 3.6), Vector2(0.0, 3.7)], 10, ACIER_C)
		"filmeuse":
			k.lathe(Vector3.ZERO, [Vector2(0.0, 0.0), Vector2(0.9, 0.0), Vector2(0.9, 0.12), Vector2(0.0, 0.12)], 12, GRIS)
			k.box(Vector3(1.05, 1.0, 0), Vector3(0.15, 2.0, 0.15), GRIS)
			k.box(Vector3(0, 0.75, 0), Vector3(1.1, 1.2, 1.1), CARTON)
			k.layer = "verre"
			k.box(Vector3(0, 0.75, 0), Vector3(1.16, 1.24, 1.16), Color(0.85, 0.9, 0.95, 0.45), 0.0, false)
			k.layer = "base"
		"etiqueteuse":
			k.box(Vector3(0, 0.45, 0), Vector3(0.8, 0.9, 0.6), Color("e9ecef"))
			k.box(Vector3(0, 1.0, 0), Vector3(0.5, 0.2, 0.4), GRIS)
			k.box(Vector3(0, 1.0, 0.21), Vector3(0.3, 0.08, 0.01), BLANC, 0.0, false)
			for i in 6:
				k.box(Vector3(-0.15 + i * 0.06, 1.0, 0.215), Vector3(0.02, 0.06, 0.005), NOIR, 0.0, false)
		"cartons_marque":
			var c := teinte if teinte != Color.WHITE else Color("c9a46c")
			for i in 3:
				for j in 2:
					k.box(Vector3(-0.6 + i * 0.6, 0.27 + j * 0.54, 0), Vector3(0.55, 0.52, 0.55), c)
					k.box(Vector3(-0.6 + i * 0.6, 0.3 + j * 0.54, 0.28), Vector3(0.3, 0.15, 0.01), ORANGE, 0.0, false)
		# --- Labo et études --------------------------------------------------------------
		"balance":
			k.box(Vector3(0, 0.45, 0), Vector3(1.0, 0.9, 0.6), BLANC)
			k.box(Vector3(0, 0.98, 0), Vector3(0.36, 0.08, 0.3), GRIS)
			k.layer = "verre"
			k.box(Vector3(0, 1.18, 0), Vector3(0.34, 0.32, 0.28), Color(0.8, 0.9, 0.95, 0.4), 0.0, false)
			k.layer = "base"
		"banc_essai":
			k.box(Vector3(0, 0.45, 0), Vector3(2.0, 0.9, 1.0), GRIS)
			k.box(Vector3(-0.3, 1.1, 0), Vector3(0.6, 0.4, 0.5), ORANGE)
			k.tube(Vector3(0.0, 1.1, 0), Vector3(0.6, 1.1, 0), 0.06, 0.06, 6, ACIER_C)
			k.box(Vector3(0.75, 1.3, -0.3), Vector3(0.4, 0.5, 0.1), NOIR)
			k.layer = "lumiere"
			k.box(Vector3(0.75, 1.32, -0.24), Vector3(0.32, 0.36, 0.01), Color("57cc99"), 0.0, false)
			k.layer = "base"
		"spectrometre":
			k.box(Vector3(0, 0.45, 0), Vector3(1.4, 0.9, 0.7), BLANC)
			k.box(Vector3(-0.2, 1.15, -0.05), Vector3(0.8, 0.5, 0.55), Color("dee2e6"))
			k.box(Vector3(-0.2, 1.42, 0.2), Vector3(0.4, 0.04, 0.1), BLEU, 0.0, false)
			k.box(Vector3(0.45, 1.1, 0.0), Vector3(0.35, 0.35, 0.05), NOIR)
		"table_dessin":
			k.box(Vector3(0, 0.36, -0.2), Vector3(1.2, 0.06, 0.06), GRIS, 0.0, false)
			for sx in [-0.5, 0.5]:
				k.box(Vector3(sx, 0.4, -0.2), Vector3(0.06, 0.8, 0.06), GRIS, 0.0, false)
			k.beam(Vector3(0, 0.85, 0.2), Vector3(0, 1.15, -0.4), 1.3, 0.04, BLANC)
			k.box(Vector3(0.2, 1.0, -0.12), Vector3(0.6, 0.02, 0.4), Color("bde0fe"), 0.0, false)
			k.box(Vector3(0, 0.45, 0.8), Vector3(0.4, 0.06, 0.4), NOIR)
			k.box(Vector3(0, 0.22, 0.8), Vector3(0.06, 0.44, 0.06), GRIS, 0.0, false)
		"imprimante_3d":
			k.box(Vector3(0, 0.4, 0), Vector3(0.9, 0.8, 0.7), Color("343a40"))
			k.box(Vector3(0, 1.15, 0), Vector3(0.8, 0.7, 0.65), GRIS)
			k.layer = "verre"
			k.box(Vector3(0, 1.15, 0.33), Vector3(0.7, 0.6, 0.01), Color(0.9, 0.6, 0.3, 0.4), 0.0, false)
			k.layer = "base"
			k.box(Vector3(0, 1.0, 0.0), Vector3(0.2, 0.18, 0.2), ORANGE)
		"vitrine_produit":
			k.box(Vector3(0, 0.45, 0), Vector3(1.0, 0.9, 0.7), Color("343a40"))
			k.layer = "verre"
			k.box(Vector3(0, 1.3, 0), Vector3(0.95, 0.8, 0.65), Color(0.85, 0.92, 0.98, 0.35), 0.0, false)
			k.layer = "base"
			k.box(Vector3(0, 1.1, 0), Vector3(0.4, 0.4, 0.3), teinte if teinte != Color.WHITE else ORANGE)
			k.layer = "lumiere"
			k.box(Vector3(0, 1.72, 0), Vector3(0.7, 0.03, 0.4), Color("fff3b0"), 0.0, false)
			k.layer = "base"
		# --- Sécurité --------------------------------------------------------------------
		"douche_secu":
			k.tube(Vector3.ZERO, Vector3(0, 2.3, 0), 0.05, 0.05, 6, Color("2b9348"))
			k.tube(Vector3(0, 2.3, 0), Vector3(0, 2.3, 0.5), 0.05, 0.05, 6, Color("2b9348"))
			k.lathe(Vector3(0, 2.15, 0.5), [Vector2(0.0, 0.0), Vector2(0.25, 0.0), Vector2(0.05, 0.15), Vector2(0.0, 0.15)], 8, Color("2b9348"))
			k.box(Vector3(0, 1.1, 0.25), Vector3(0.35, 0.08, 0.3), Color("2b9348"))
			k.box(Vector3(0.25, 1.7, 0.05), Vector3(0.3, 0.3, 0.02), Color("55a630"), 0.0, false)
		# --- Quai ------------------------------------------------------------------------
		"niveleur":
			k.box(Vector3(0, 0.6, 0), Vector3(2.6, 1.2, 0.5), GRIS)
			k.box(Vector3(0, 1.21, 0.6), Vector3(2.2, 0.05, 1.0), ACIER)
			for i in 6:
				k.box(Vector3(-1.0 + i * 0.4, 1.245, 1.05), Vector3(0.2, 0.012, 0.1), JAUNE if i % 2 == 0 else NOIR, 0.0, false)
			for sx in [-1.3, 1.3]:
				k.box(Vector3(sx, 0.6, 0.3), Vector3(0.15, 0.9, 0.3), NOIR, 0.0, false)
		"camion_semi":
			# Tracteur à l'avant (+Z), remorque derrière.
			k.box(Vector3(0, 1.6, -1.8), Vector3(2.4, 2.6, 8.4), Color("e9ecef"))
			k.box(Vector3(0, 1.62, -1.8), Vector3(2.42, 0.4, 8.42), teinte if teinte != Color.WHITE else ORANGE, 0.0, false)
			k.box(Vector3(0, 1.3, 3.4), Vector3(2.3, 2.0, 1.8), BLEU)
			k.layer = "verre"
			k.box(Vector3(0, 1.9, 4.31), Vector3(2.0, 0.8, 0.02), Color(0.6, 0.75, 0.85, 0.7), 0.0, false)
			k.layer = "base"
			for z in [-4.8, -3.6, 3.6]:
				for sx in [-1.1, 1.1]:
					k.tube(Vector3(sx, 0.45, z), Vector3(sx * 1.12, 0.45, z), 0.45, 0.45, 10, NOIR)
		"abri_chauffeurs":
			for sx in [-1.0, 1.0]:
				k.box(Vector3(sx, 1.1, -0.4), Vector3(0.08, 2.2, 0.08), GRIS, 0.0, false)
			k.box(Vector3(0, 2.25, -0.1), Vector3(2.3, 0.08, 1.0), Color("adb5bd"))
			k.layer = "verre"
			k.box(Vector3(0, 1.2, -0.45), Vector3(2.0, 1.8, 0.03), Color(0.75, 0.85, 0.9, 0.35), 0.0, false)
			k.layer = "base"
			k.box(Vector3(0, 0.45, -0.1), Vector3(1.8, 0.06, 0.4), BOIS)
			k.box(Vector3(0.9, 1.4, -0.42), Vector3(0.3, 0.6, 0.05), JAUNE, 0.0, false)
		"pont_bascule":
			k.box(Vector3(0, 0.05, 0), Vector3(3.0, 0.1, 1.6), ACIER)
			for i in 4:
				k.box(Vector3(-1.2 + i * 0.8, 0.105, 0), Vector3(0.05, 0.01, 1.5), GRIS, 0.0, false)
			k.box(Vector3(1.8, 0.7, -0.7), Vector3(0.4, 1.4, 0.3), GRIS)
			k.layer = "lumiere"
			k.box(Vector3(1.8, 1.2, -0.54), Vector3(0.3, 0.18, 0.01), Color("ff4d4d"), 0.0, false)
			k.layer = "base"
		# --- Épuration -------------------------------------------------------------------
		"filtre_manches":
			k.box(Vector3(0, 1.0, 0), Vector3(2.4, 2.0, 2.0), ACIER_C)
			k.lathe(Vector3(0, 2.0, 0), [Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(0.3, 0.8), Vector2(0.0, 0.8)], 4, ACIER, true, true, Callable(), PI * 0.25)
			k.tube(Vector3(0, 2.8, 0), Vector3(0, 5.0, 0), 0.25, 0.25, 8, ACIER)
			k.tube(Vector3(-1.2, 1.4, 0), Vector3(-1.8, 1.4, 0), 0.3, 0.3, 8, ACIER)
			for i in 3:
				k.box(Vector3(-0.7 + i * 0.7, 1.0, 1.01), Vector3(0.5, 1.4, 0.02), GRIS, 0.0, false)
		"bassin_decantation":
			k.lathe(Vector3.ZERO, [Vector2(0.0, 0.0), Vector2(3.0, 0.0), Vector2(3.0, 0.7), Vector2(2.8, 0.7), Vector2(2.8, 0.1), Vector2(0.0, 0.1)], 16, Color("adb5bd"))
			k.layer = "eau"
			k.lathe(Vector3(0, 0.5, 0), [Vector2(0.0, 0.0), Vector2(2.8, 0.0), Vector2(0.0, 0.01)], 16, Color(0.45, 0.6, 0.55, 0.8))
			k.layer = "base"
			k.beam(Vector3(0, 0.9, 0), Vector3(2.9, 0.9, 0), 0.25, 0.1, JAUNE)
			k.tube(Vector3(0, 0.5, 0), Vector3(0, 1.2, 0), 0.2, 0.2, 8, GRIS)
		"cheminee_usine":
			k.lathe(Vector3.ZERO, [Vector2(0.0, 0.0), Vector2(0.7, 0.0), Vector2(0.45, 7.0), Vector2(0.0, 7.0)], 10, Color("9c6644"))
			for y in [5.6, 6.4]:
				k.lathe(Vector3(0, y, 0), [Vector2(0.0, 0.0), Vector2(0.52, 0.0), Vector2(0.52, 0.3), Vector2(0.0, 0.3)], 10, BLANC if y < 6.0 else ORANGE)
			k.box(Vector3(0.55, 4.0, 0), Vector3(0.2, 0.4, 0.2), GRIS)
			k.layer = "lumiere"
			k.box(Vector3(0.66, 4.05, 0), Vector3(0.02, 0.1, 0.1), Color("80ed99"), 0.0, false)
			k.layer = "base"
		# --- Énergie ---------------------------------------------------------------------
		"panneaux_solaires":
			for i in 3:
				var x := -2.0 + i * 2.0
				k.box(Vector3(x, 0.4, 0), Vector3(0.08, 0.8, 0.08), GRIS, 0.0, false)
				k.beam(Vector3(x, 0.9, 1.0), Vector3(x, 1.5, -1.0), 1.8, 0.05, Color("1d3557"))
				for j in 3:
					k.beam(Vector3(x - 0.6 + j * 0.6, 0.93, 1.0), Vector3(x - 0.6 + j * 0.6, 1.53, -1.0), 0.02, 0.01, Color("8ecae6"))
		"chaudiere":
			k.box(Vector3(0, 1.1, 0), Vector3(2.0, 2.2, 1.6), Color("c1121f"))
			k.box(Vector3(0, 0.8, 0.81), Vector3(0.7, 0.7, 0.04), GRIS, 0.0, false)
			k.tube(Vector3(0.5, 2.2, -0.3), Vector3(0.5, 4.0, -0.3), 0.18, 0.18, 8, ACIER)
			for i in 4:
				k.box(Vector3(-1.6 + (i % 2) * 0.5, 0.25 + (i / 2) * 0.45, -0.2), Vector3(0.45, 0.4, 1.2), BOIS)
		"eolienne":
			k.lathe(Vector3.ZERO, [Vector2(0.0, 0.0), Vector2(0.22, 0.0), Vector2(0.12, 6.0), Vector2(0.0, 6.0)], 8, BLANC)
			k.box(Vector3(0, 6.05, 0.0), Vector3(0.35, 0.35, 0.9), BLANC)
			for i in 3:
				var a := TAU * i / 3.0
				k.beam(Vector3(0, 6.05, 0.5), Vector3(cos(a) * 2.4, 6.05 + sin(a) * 2.4, 0.5), 0.22, 0.05, BLANC)
		_:
			ModelesParc.dessiner(k, nom, teinte)
