class_name ModelesImmeuble
extends RefCounted
## Objets low-poly de l'immeuble (boîtes aux lettres, ascenseur, cuisines,
## lits, vélos, étendoirs, boxes…), mêmes conventions que GestionModeles :
## origine au sol au centre de l'objet, face avant vers +Z, le kit est déjà
## placé (k.xf).

const GRIS := Color("5c636a")
const GRIS_C := Color("c3ccd4")
const NOIR := Color("26262b")
const BLANC := Color("f6f4ef")
const BOIS := Color("b08968")
const BOIS_F := Color("7f5539")
const BLEU := Color("1d6fa3")
const VERT := Color("2a9d8f")
const ROUGE := Color("e63946")
const JAUNE := Color("f2b705")

## Places des visiteurs : modèle → [[x, z, angle, assis]] locaux.
const PLACES := {
	"boites_lettres": [[0.0, 0.7, PI, false]],
	"table_salle": [[-0.9, 0.0, PI * 0.5, true], [0.9, 0.0, -PI * 0.5, true]],
	"table_ping_pong": [[0.0, 1.6, PI, false], [0.0, -1.6, 0.0, false]],
	"boite_livres": [[0.0, 0.7, PI, false]],
	"etendoir": [[0.0, 0.8, PI, false]],
}


static func dessiner(k: LpKit, nom: String, teinte := Color.WHITE) -> void:
	match nom:
		"boites_lettres":
			k.box(Vector3(0, 1.1, 0), Vector3(1.6, 1.0, 0.35), GRIS)
			for i in 4:
				for j in 3:
					k.box(Vector3(-0.6 + i * 0.4, 0.8 + j * 0.3, 0.18), Vector3(0.36, 0.26, 0.02), Color("adb5bd") if (i + j) % 2 == 0 else GRIS_C, 0.0, false)
					k.box(Vector3(-0.6 + i * 0.4, 0.88 + j * 0.3, 0.195), Vector3(0.2, 0.03, 0.01), NOIR, 0.0, false)
		"digicode":
			k.box(Vector3(0, 1.3, 0.04), Vector3(0.3, 0.45, 0.08), GRIS)
			k.layer = "lumiere"
			k.box(Vector3(0, 1.42, 0.085), Vector3(0.2, 0.12, 0.01), Color("8ecae6"), 0.0, false)
			k.layer = "base"
			for i in 3:
				for j in 2:
					k.box(Vector3(-0.07 + i * 0.07, 1.2 + j * 0.06, 0.085), Vector3(0.04, 0.04, 0.01), GRIS_C, 0.0, false)
		"ascenseur":
			# Cabine vitrée dans sa gaine, portes inox.
			k.box(Vector3(0, 1.4, -0.1), Vector3(1.6, 2.8, 1.4), Color("d6ccc2"))
			k.box(Vector3(0, 1.05, 0.61), Vector3(1.0, 2.1, 0.04), Color("ced4da"), 0.0, false)
			k.box(Vector3(0, 1.05, 0.63), Vector3(0.02, 2.1, 0.01), GRIS, 0.0, false)
			k.box(Vector3(0.65, 1.2, 0.62), Vector3(0.1, 0.25, 0.02), NOIR, 0.0, false)
			k.layer = "lumiere"
			k.box(Vector3(0, 2.3, 0.62), Vector3(0.3, 0.1, 0.01), Color("ffb703"), 0.0, false)
			k.layer = "base"
		"lit_double":
			k.box(Vector3(0, 0.22, 0), Vector3(1.6, 0.36, 2.0), BOIS_F)
			k.box(Vector3(0, 0.46, 0.05), Vector3(1.55, 0.14, 1.9), BLANC)
			k.box(Vector3(0, 0.55, 0.35), Vector3(1.58, 0.05, 1.2), teinte if teinte != Color.WHITE else BLEU)
			k.box(Vector3(-0.38, 0.58, -0.7), Vector3(0.6, 0.12, 0.35), BLANC)
			k.box(Vector3(0.38, 0.58, -0.7), Vector3(0.6, 0.12, 0.35), BLANC)
			k.box(Vector3(0, 0.6, -0.98), Vector3(1.6, 0.9, 0.08), BOIS_F)
		"cuisine_equipee":
			# Plan de travail, évier, plaques, placards hauts, frigo.
			k.box(Vector3(0, 0.45, 0), Vector3(2.6, 0.9, 0.6), teinte if teinte != Color.WHITE else Color("e9edc9"))
			k.box(Vector3(0, 0.92, 0), Vector3(2.65, 0.04, 0.64), Color("6c757d"), 0.0, false)
			k.box(Vector3(-0.5, 0.92, 0.0), Vector3(0.5, 0.02, 0.4), GRIS_C, 0.0, false)
			k.box(Vector3(0.5, 0.93, 0.0), Vector3(0.55, 0.02, 0.45), NOIR, 0.0, false)
			k.box(Vector3(0, 1.8, -0.15), Vector3(2.6, 0.6, 0.35), teinte if teinte != Color.WHITE else Color("e9edc9"))
			k.box(Vector3(1.6, 0.95, 0), Vector3(0.6, 1.9, 0.6), BLANC)
		"table_salle":
			k.box(Vector3(0, 0.74, 0), Vector3(1.2, 0.05, 0.8), BOIS)
			for sx in [-0.55, 0.55]:
				for sz in [-0.35, 0.35]:
					k.box(Vector3(sx, 0.36, sz), Vector3(0.05, 0.72, 0.05), BOIS_F, 0.0, false)
		"rack_velos":
			for i in 3:
				var x := -0.8 + i * 0.8
				k.tube(Vector3(x, 0, -0.1), Vector3(x, 0.6, -0.1), 0.03, 0.03, 5, GRIS)
				k.tube(Vector3(x, 0, 0.1), Vector3(x, 0.6, 0.1), 0.03, 0.03, 5, GRIS)
				k.beam(Vector3(x, 0.6, -0.1), Vector3(x, 0.6, 0.1), 0.04, 0.04, GRIS)
				# Un vélo dans l'arceau.
				var c: Color = [ROUGE, BLEU, VERT][i]
				k.tube(Vector3(x + 0.12, 0.35, -0.6), Vector3(x + 0.12, 0.35, -0.55), 0.33, 0.33, 10, NOIR)
				k.tube(Vector3(x + 0.12, 0.35, 0.55), Vector3(x + 0.12, 0.35, 0.6), 0.33, 0.33, 10, NOIR)
				k.beam(Vector3(x + 0.12, 0.4, -0.55), Vector3(x + 0.12, 0.75, 0.0), 0.04, 0.04, c)
				k.beam(Vector3(x + 0.12, 0.75, 0.0), Vector3(x + 0.12, 0.4, 0.55), 0.04, 0.04, c)
		"etendoir":
			for sx in [-0.5, 0.5]:
				k.beam(Vector3(sx, 0, -0.3), Vector3(sx, 1.0, 0.0), 0.03, 0.03, GRIS_C)
				k.beam(Vector3(sx, 0, 0.3), Vector3(sx, 1.0, 0.0), 0.03, 0.03, GRIS_C)
			for i in 4:
				k.box(Vector3(-0.3 + i * 0.2, 0.75, 0.0), Vector3(0.16, 0.4, 0.02), [BLANC, BLEU, JAUNE, ROUGE][i], 0.0, false)
			k.beam(Vector3(-0.5, 1.0, 0), Vector3(0.5, 1.0, 0), 0.02, 0.02, GRIS)
		"boite_livres":
			k.tube(Vector3(0, 0, 0), Vector3(0, 0.8, 0), 0.05, 0.05, 6, BOIS_F)
			k.box(Vector3(0, 1.15, 0), Vector3(0.7, 0.7, 0.45), VERT)
			for i in 5:
				k.box(Vector3(-0.24 + i * 0.12, 1.12, 0.12), Vector3(0.08, 0.3, 0.2), [ROUGE, JAUNE, BLEU, BLANC, BOIS][i], 0.0, false)
			k.box(Vector3(0, 1.55, 0), Vector3(0.8, 0.08, 0.55), BOIS_F)
		"table_ping_pong":
			k.box(Vector3(0, 0.76, 0), Vector3(1.5, 0.05, 2.7), Color("2d6a4f"))
			k.box(Vector3(0, 0.79, 0), Vector3(0.02, 0.01, 2.7), BLANC, 0.0, false)
			k.box(Vector3(0, 0.86, 0), Vector3(1.6, 0.15, 0.02), BLANC, 0.0, false)
			for sx in [-0.6, 0.6]:
				for sz in [-1.1, 1.1]:
					k.box(Vector3(sx, 0.37, sz), Vector3(0.06, 0.74, 0.06), GRIS, 0.0, false)
		"box_garage":
			k.box(Vector3(0, 1.2, 0), Vector3(2.8, 2.4, 5.0), Color("adb5bd"))
			k.box(Vector3(0, 1.05, 2.51), Vector3(2.4, 2.0, 0.02), teinte if teinte != Color.WHITE else Color("d6ccc2"), 0.0, false)
			for i in 5:
				k.box(Vector3(0, 0.2 + i * 0.4, 2.53), Vector3(2.4, 0.02, 0.01), GRIS, 0.0, false)
			k.box(Vector3(0, 2.45, 0), Vector3(3.0, 0.1, 5.2), GRIS)
		_:
			ModelesParc.dessiner(k, nom, teinte)
