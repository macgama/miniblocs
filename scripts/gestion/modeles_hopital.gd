class_name ModelesHopital
extends RefCounted
## Objets low-poly de l'hôpital (accueil, chambres, consultations, bloc,
## imagerie, labo, pharmacie, hélistation), mêmes conventions que
## GestionModeles : origine au sol au centre de l'objet, face avant vers +Z,
## le kit est déjà placé (k.xf).

const VERT := Color("2a9d8f")
const VERT_C := Color("a8dadc")
const BLANC := Color("f6f4ef")
const ROUGE := Color("d62828")
const JAUNE := Color("ffd60a")
const INOX := Color("c9ced3")
const INOX_F := Color("8d949b")
const GRIS := Color("5c636a")
const NOIR := Color("26262b")
const ECRAN := Color("90e0ef")

## Places des visiteurs : modèle → [[x, z, angle, assis]] locaux.
const PLACES := {
	"table_examen": [[0.0, 0.0, 0.0, true]],
	"squelette": [[0.0, 0.9, PI, false]],
	"helico": [[2.0, 2.0, -PI * 0.75, false]],
}


static func dessiner(k: LpKit, nom: String, _teinte := Color.WHITE) -> void:
	match nom:
		"fauteuil_roulant":
			for sx in [-0.28, 0.28]:
				k.lathe(Vector3(sx, 0.3, 0.05), [Vector2(0.0, -0.02), Vector2(0.3, -0.02), Vector2(0.3, 0.02), Vector2(0.0, 0.02)], 12, GRIS)
			k.box(Vector3(0, 0.48, 0.05), Vector3(0.48, 0.05, 0.45), Color("1d3557"))
			k.box(Vector3(0, 0.78, -0.18), Vector3(0.48, 0.55, 0.05), Color("1d3557"))
			for sx in [-0.26, 0.26]:
				k.beam(Vector3(sx, 0.5, 0.25), Vector3(sx, 0.08, 0.38), 0.03, 0.03, INOX)
				k.beam(Vector3(sx, 1.05, -0.2), Vector3(sx, 1.05, -0.32), 0.03, 0.03, NOIR)
		"lit_hopital":
			DecorsHopital.lit(k, Vector3.ZERO, 0.0)
		"perfusion":
			k.tube(Vector3.ZERO, Vector3(0, 1.9, 0), 0.02, 0.02, 5, INOX)
			for i in 4:
				var a := i * PI * 0.5
				k.beam(Vector3(0, 0.05, 0), Vector3(cos(a) * 0.3, 0.02, sin(a) * 0.3), 0.03, 0.03, GRIS)
			k.beam(Vector3(-0.2, 1.85, 0), Vector3(0.2, 1.85, 0), 0.02, 0.02, INOX)
			k.box(Vector3(0.18, 1.65, 0), Vector3(0.12, 0.22, 0.05), Color(0.85, 0.95, 1.0))
			k.tube(Vector3(0.18, 1.53, 0), Vector3(0.25, 0.8, 0.2), 0.008, 0.008, 4, BLANC)
		"table_examen":
			k.box(Vector3(0, 0.4, 0), Vector3(0.7, 0.8, 1.9), Color("e9ecef"))
			k.box(Vector3(0, 0.84, 0), Vector3(0.68, 0.08, 1.85), VERT_C)
			k.box(Vector3(0, 0.95, -0.7), Vector3(0.66, 0.12, 0.45), VERT_C)
			k.box(Vector3(0, 0.89, 0.2), Vector3(0.62, 0.01, 1.2), BLANC, 0.0, false)
		"tensiometre":
			k.box(Vector3(0, 0.45, 0), Vector3(0.6, 0.9, 0.45), BLANC)
			k.box(Vector3(0, 1.1, -0.15), Vector3(0.3, 0.4, 0.1), GRIS)
			k.lathe(Vector3(0, 1.15, -0.09), [Vector2(0.0, 0.0), Vector2(0.11, 0.0), Vector2(0.11, 0.02), Vector2(0.0, 0.02)], 10, BLANC)
			k.tube(Vector3(0.1, 0.92, 0.1), Vector3(-0.15, 0.95, 0.15), 0.015, 0.015, 4, NOIR)
		"squelette":
			k.box(Vector3(0, 0.03, 0), Vector3(0.4, 0.06, 0.4), GRIS)
			k.tube(Vector3(0, 0.06, -0.1), Vector3(0, 1.8, -0.1), 0.02, 0.02, 4, INOX)
			k.blob(Vector3(0, 1.62, 0), Vector3(0.1, 0.12, 0.11), BLANC, BLANC, 0.0, 0)
			k.tube(Vector3(0, 1.5, 0), Vector3(0, 0.95, 0), 0.025, 0.025, 5, BLANC)
			for j in 5:
				k.box(Vector3(0, 1.38 - j * 0.07, 0.02), Vector3(0.26 - j * 0.02, 0.02, 0.14), BLANC, 0.0, false)
			k.box(Vector3(0, 0.92, 0), Vector3(0.26, 0.1, 0.12), BLANC)
			for sx in [-0.09, 0.09]:
				k.beam(Vector3(sx, 0.88, 0), Vector3(sx, 0.08, 0.02), 0.03, 0.03, BLANC)
				k.beam(Vector3(sx * 2.0, 1.42, 0), Vector3(sx * 2.6, 0.9, 0.02), 0.025, 0.025, BLANC)
		"echographe":
			k.box(Vector3(0, 0.45, 0), Vector3(0.55, 0.9, 0.55), BLANC)
			k.box(Vector3(0, 0.95, 0.1), Vector3(0.5, 0.06, 0.35), GRIS, 0.0, false)
			k.box(Vector3(0, 1.35, -0.15), Vector3(0.5, 0.36, 0.04), NOIR, 0.0, false)
			k.layer = "lumiere"
			k.box(Vector3(0, 1.35, -0.12), Vector3(0.44, 0.3, 0.01), Color("495867"), 0.0, false)
			k.layer = "base"
		"table_operation":
			k.tube(Vector3.ZERO, Vector3(0, 0.75, 0), 0.12, 0.08, 8, INOX_F)
			k.box(Vector3(0, 0.82, 0), Vector3(0.6, 0.1, 2.0), Color("1d3557"))
			k.box(Vector3(0, 0.88, 0.2), Vector3(0.62, 0.02, 1.3), VERT, 0.0, false)
			k.box(Vector3(0, 0.02, 0), Vector3(0.6, 0.04, 0.8), INOX_F, 0.0, false)
		"scialytique":
			k.tube(Vector3(0, 3.0, 0), Vector3(0, 2.4, 0), 0.04, 0.04, 6, INOX)
			k.beam(Vector3(0, 2.4, 0), Vector3(0.4, 2.2, 0), 0.05, 0.05, INOX)
			k.lathe(Vector3(0.4, 1.95, 0), [Vector2(0.0, 0.0), Vector2(0.45, 0.0), Vector2(0.35, 0.18), Vector2(0.0, 0.22)], 12, BLANC)
			k.layer = "lumiere"
			k.lathe(Vector3(0.4, 1.94, 0), [Vector2(0.0, 0.0), Vector2(0.38, 0.0), Vector2(0.0, 0.01)], 12, Color("fff8dc"))
			k.layer = "base"
		"moniteur_medical":
			k.tube(Vector3.ZERO, Vector3(0, 1.2, 0), 0.03, 0.03, 5, INOX)
			k.box(Vector3(0, 0.04, 0), Vector3(0.5, 0.06, 0.5), GRIS, 0.0, false)
			k.box(Vector3(0, 1.45, 0), Vector3(0.5, 0.4, 0.12), Color("343a40"))
			k.layer = "lumiere"
			k.box(Vector3(0, 1.45, 0.065), Vector3(0.44, 0.32, 0.01), Color("0b2027"), 0.0, false)
			for i in 6:
				k.box(Vector3(-0.18 + i * 0.07, 1.5 + (0.08 if i == 3 else 0.0), 0.075), Vector3(0.06, 0.012 + (0.12 if i == 3 else 0.0), 0.005), Color("80ed99"), 0.0, false)
			k.layer = "base"
		"respirateur":
			k.box(Vector3(0, 0.55, 0), Vector3(0.5, 1.1, 0.45), BLANC)
			k.box(Vector3(0, 1.2, 0), Vector3(0.45, 0.3, 0.1), Color("343a40"), 0.0, false)
			k.layer = "lumiere"
			k.box(Vector3(0, 1.2, 0.055), Vector3(0.38, 0.22, 0.01), ECRAN, 0.0, false)
			k.layer = "base"
			k.tube(Vector3(0.2, 0.9, 0.2), Vector3(0.5, 0.95, 0.6), 0.04, 0.04, 6, Color("bde0fe"))
			for sx in [-0.2, 0.2]:
				k.lathe(Vector3(sx, 0.0, 0.2), [Vector2(0.0, 0.0), Vector2(0.05, 0.0), Vector2(0.05, 0.08), Vector2(0.0, 0.08)], 6, NOIR)
		"robot_chir":
			k.box(Vector3(0, 0.4, 0), Vector3(0.9, 0.8, 0.9), BLANC)
			k.tube(Vector3(0, 0.8, 0), Vector3(0, 1.9, 0), 0.12, 0.1, 8, BLANC)
			for i in 3:
				var a := (i - 1) * 0.6
				k.beam(Vector3(0, 1.8, 0), Vector3(sin(a) * 0.8, 1.5, 0.6), 0.08, 0.08, BLANC)
				k.beam(Vector3(sin(a) * 0.8, 1.5, 0.6), Vector3(sin(a) * 0.6, 1.0, 0.9), 0.05, 0.05, INOX_F)
			k.box(Vector3(0, 0.55, 0.46), Vector3(0.6, 0.15, 0.02), VERT, 0.0, false)
		"table_radio":
			k.box(Vector3(0, 0.4, 0), Vector3(0.8, 0.8, 2.0), Color("e9ecef"))
			k.box(Vector3(0, 0.84, 0), Vector3(0.78, 0.06, 1.95), Color("d0d7dd"))
			k.tube(Vector3(-0.9, 0, -0.6), Vector3(-0.9, 2.3, -0.6), 0.08, 0.08, 6, INOX_F)
			k.beam(Vector3(-0.9, 2.2, -0.6), Vector3(0, 2.2, -0.2), 0.12, 0.12, INOX)
			k.box(Vector3(0, 1.95, -0.2), Vector3(0.4, 0.35, 0.4), BLANC)
			k.box(Vector3(0, 1.75, -0.2), Vector3(0.05, 0.05, 0.05), JAUNE, 0.0, false)
		"negatoscope":
			k.box(Vector3(0, 1.6, 0.03), Vector3(1.0, 0.6, 0.06), INOX, 0.0, false)
			k.layer = "lumiere"
			k.box(Vector3(0, 1.6, 0.065), Vector3(0.9, 0.5, 0.01), Color("e0f2ff"), 0.0, false)
			k.layer = "base"
			k.box(Vector3(-0.2, 1.6, 0.075), Vector3(0.3, 0.42, 0.005), Color("3d5a80"), 0.0, false)
			k.box(Vector3(0.2, 1.6, 0.075), Vector3(0.3, 0.42, 0.005), Color("3d5a80"), 0.0, false)
		"scanner":
			k.box(Vector3(0, 0.45, 0), Vector3(2.2, 0.06, 0.9), GRIS, 0.0, false)
			k.lathe(Vector3(0, 1.0, -0.6), [Vector2(0.45, -0.35), Vector2(1.05, -0.35), Vector2(1.05, 0.35), Vector2(0.45, 0.35)], 20, BLANC)
			k.box(Vector3(0, 0.25, -0.6), Vector3(1.6, 0.5, 0.7), BLANC)
			k.box(Vector3(0, 0.6, 0.6), Vector3(0.55, 0.6, 1.6), Color("e9ecef"))
			k.box(Vector3(0, 0.93, 0.4), Vector3(0.5, 0.06, 2.2), Color("d0d7dd"))
			k.box(Vector3(0, 1.4, -0.24), Vector3(0.6, 0.12, 0.02), VERT, 0.0, false)
		"microscope":
			k.box(Vector3(0, 0.95, 0), Vector3(0.24, 0.04, 0.3), NOIR)
			k.beam(Vector3(0, 0.96, -0.1), Vector3(0, 1.3, -0.08), 0.06, 0.06, BLANC)
			k.tube(Vector3(0, 1.28, -0.05), Vector3(0, 1.38, 0.05), 0.03, 0.03, 6, NOIR)
			k.box(Vector3(0, 1.1, 0.02), Vector3(0.14, 0.02, 0.14), INOX, 0.0, false)
		"centrifugeuse":
			k.box(Vector3(0, 0.45, 0), Vector3(0.6, 0.9, 0.5), Color("dee2e6"))
			k.lathe(Vector3(0, 0.9, 0), [Vector2(0.0, 0.0), Vector2(0.22, 0.0), Vector2(0.24, 0.15), Vector2(0.0, 0.2)], 12, BLANC)
			k.layer = "lumiere"
			k.box(Vector3(0.18, 0.75, 0.255), Vector3(0.1, 0.05, 0.01), Color("80ed99"), 0.0, false)
			k.layer = "base"
		"frigo_sang":
			k.box(Vector3(0, 0.95, 0), Vector3(0.8, 1.9, 0.6), BLANC)
			k.layer = "verre"
			k.box(Vector3(0, 1.05, 0.31), Vector3(0.7, 1.5, 0.02), Color(0.8, 0.9, 1.0, 0.35), 0.0, false)
			k.layer = "base"
			for j in 4:
				for i in 4:
					k.box(Vector3(-0.24 + i * 0.16, 0.5 + j * 0.36, 0.1), Vector3(0.12, 0.2, 0.05), Color("9d0208"), 0.0, false)
		"chariot_soins":
			k.box(Vector3(0, 0.5, 0), Vector3(0.8, 0.8, 0.5), BLANC)
			for j in 4:
				k.box(Vector3(0, 0.2 + j * 0.18, 0.26), Vector3(0.7, 0.14, 0.01), [VERT_C, Color("ffe8d6"), Color("bde0fe"), VERT_C][j], 0.0, false)
			k.box(Vector3(0, 0.92, 0), Vector3(0.84, 0.04, 0.54), Color("343a40"), 0.0, false)
			for sx in [-0.35, 0.35]:
				for sz in [-0.2, 0.2]:
					k.lathe(Vector3(sx, 0.0, sz), [Vector2(0.0, 0.0), Vector2(0.05, 0.0), Vector2(0.05, 0.1), Vector2(0.0, 0.1)], 6, NOIR)
		"manche_air":
			k.tube(Vector3.ZERO, Vector3(0, 3.0, 0), 0.04, 0.04, 6, GRIS)
			k.tube(Vector3(0, 2.9, 0), Vector3(1.2, 2.75, 0), 0.22, 0.1, 8, Color("f77f00"))
			k.tube(Vector3(0.35, 2.86, 0), Vector3(0.55, 2.83, 0), 0.2, 0.17, 8, BLANC, false)
		"balise":
			k.lathe(Vector3.ZERO, [Vector2(0.0, 0.0), Vector2(0.12, 0.0), Vector2(0.1, 0.25), Vector2(0.0, 0.3)], 8, GRIS)
			k.layer = "lumiere"
			k.lathe(Vector3(0, 0.25, 0), [Vector2(0.0, 0.0), Vector2(0.08, 0.0), Vector2(0.0, 0.12)], 8, Color("80ed99"))
			k.layer = "base"
		"helico":
			k.blob(Vector3(0, 1.4, 0.4), Vector3(0.9, 0.9, 1.9), ROUGE, Color("f8f9fa"), 0.0, 1)
			k.layer = "verre"
			k.blob(Vector3(0, 1.6, 1.6), Vector3(0.7, 0.55, 0.6), Color(0.55, 0.7, 0.82, 0.8), Color(0.55, 0.7, 0.82, 0.8), 0.0, 0)
			k.layer = "base"
			k.tube(Vector3(0, 1.6, -1.2), Vector3(0, 1.9, -5.0), 0.3, 0.12, 6, ROUGE)
			k.box(Vector3(0, 2.4, -4.9), Vector3(0.08, 0.9, 0.5), ROUGE)
			k.tube(Vector3(0, 2.3, 0.3), Vector3(0, 2.6, 0.3), 0.1, 0.1, 6, GRIS)
			for i in 4:
				var a := PI * 0.25 + i * PI * 0.5
				k.beam(Vector3(0, 2.62, 0.3), Vector3(cos(a) * 4.5, 2.62, 0.3 + sin(a) * 4.5), 0.25, 0.04, NOIR)
			for sx in [-0.7, 0.7]:
				k.beam(Vector3(sx, 0.08, -0.8), Vector3(sx, 0.08, 1.6), 0.08, 0.08, GRIS)
				k.beam(Vector3(sx, 0.08, 0.6), Vector3(sx * 0.7, 0.7, 0.6), 0.05, 0.05, GRIS)
			k.box(Vector3(0.92, 1.3, 0.4), Vector3(0.02, 0.5, 0.5), BLANC, 0.0, false)
			k.box(Vector3(0.93, 1.3, 0.4), Vector3(0.02, 0.36, 0.12), ROUGE, 0.0, false)
			k.box(Vector3(0.93, 1.3, 0.4), Vector3(0.02, 0.12, 0.36), ROUGE, 0.0, false)
		_:
			ModelesParc.dessiner(k, nom, _teinte)
