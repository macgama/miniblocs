class_name ModelesCaserne
extends RefCounted
## Objets low-poly de la caserne de pompiers (remise, alerte, vestiaires,
## chambres, formation, magasin, atelier, cour, tour de manœuvre, lavage),
## mêmes conventions que GestionModeles : origine au sol au centre de
## l'objet, face avant vers +Z, le kit est déjà placé (k.xf).

const ROUGE := Color("c1121f")
const ROUGE_F := Color("8d0f17")
const JAUNE := Color("ffd60a")
const INOX := Color("c9ced3")
const INOX_F := Color("8d949b")
const NOIR := Color("26262b")
const GRIS := Color("5c636a")
const BLANC := Color("f6f4ef")
const BOIS := Color("8a5a3b")
const BOIS_F := Color("5c4033")
const BLEU := Color("1d3557")
const OR := Color("d4af37")

## Places des visiteurs : modèle → [[x, z, angle, assis]] locaux.
const PLACES := {
	"mannequin_rcp": [[0.0, 0.75, PI, false]],
	"maquette_ville": [[0.0, 1.0, PI, false]],
	"pompe_bras": [[0.0, 1.2, PI, false]],
	"camion_ancien": [[1.6, 0.0, -PI * 0.5, false]],
	"stele": [[0.0, 1.0, PI, false]],
	"simulateur_feu": [[0.0, 1.0, PI, false]],
	"vitrine_casques": [[0.0, 0.8, PI, false]],
}


static func dessiner(k: LpKit, nom: String, _teinte := Color.WHITE) -> void:
	match nom:
		# --- Accueil -------------------------------------------------------------------
		"affiches":
			var cols := [Color("e63946"), Color("ffb703"), Color("2a9d8f")]
			for i in 3:
				k.box(Vector3(-1.0 + i * 1.0, 1.6, 0.02), Vector3(0.7, 0.95, 0.03), BLANC, 0.0, false)
				k.box(Vector3(-1.0 + i * 1.0, 1.8, 0.04), Vector3(0.55, 0.4, 0.02), cols[i], 0.0, false)
				k.box(Vector3(-1.0 + i * 1.0, 1.35, 0.04), Vector3(0.5, 0.06, 0.02), NOIR, 0.0, false)
		"vitrine_casques":
			k.box(Vector3(0, 0.45, 0), Vector3(1.4, 0.9, 0.5), BOIS_F)
			k.layer = "verre"
			k.box(Vector3(0, 1.3, 0), Vector3(1.36, 0.8, 0.46), Color(0.8, 0.9, 1.0, 0.3), 0.0, false)
			k.layer = "base"
			for i in 3:
				var c: Color = [OR, Color("e9ecef"), Color("1f2a44")][i]
				k.blob(Vector3(-0.42 + i * 0.42, 1.08, 0), Vector3(0.17, 0.13, 0.19), c, c.lightened(0.2), 0.05, 0)
				k.box(Vector3(-0.42 + i * 0.42, 0.97, 0.12), Vector3(0.3, 0.03, 0.12), c.darkened(0.2), 0.0, false)
			k.box(Vector3(0, 1.72, 0), Vector3(1.44, 0.06, 0.54), BOIS_F, 0.0, false)
		"defibrillateur":
			k.box(Vector3(0, 1.35, 0.06), Vector3(0.45, 0.5, 0.14), Color("2a9d8f"))
			k.box(Vector3(0, 1.4, 0.14), Vector3(0.22, 0.22, 0.02), BLANC, 0.0, false)
			k.box(Vector3(0, 1.4, 0.15), Vector3(0.06, 0.16, 0.01), Color("2a9d8f"), 0.0, false)
			k.box(Vector3(0, 1.4, 0.15), Vector3(0.16, 0.06, 0.01), Color("2a9d8f"), 0.0, false)
		"cadres":
			for i in 4:
				k.box(Vector3(-0.9 + i * 0.6, 1.55 + (i % 2) * 0.25, 0.02), Vector3(0.48, 0.36, 0.03), NOIR, 0.0, false)
				k.box(Vector3(-0.9 + i * 0.6, 1.55 + (i % 2) * 0.25, 0.04), Vector3(0.4, 0.28, 0.01), [Color("e76f51"), Color("6c757d"), Color("f4a261"), Color("457b9d")][i], 0.0, false)
		# --- Alerte --------------------------------------------------------------------
		"carte_murale":
			k.box(Vector3(0, 1.55, 0.03), Vector3(3.2, 1.6, 0.05), Color("3d3a36"), 0.0, false)
			k.box(Vector3(0, 1.55, 0.06), Vector3(3.0, 1.4, 0.02), Color("e9e5d6"), 0.0, false)
			for i in 6:
				k.box(Vector3(-1.3 + i * 0.52, 1.55, 0.075), Vector3(0.05, 1.3, 0.01), Color("bfb8a5"), 0.0, false)
			k.box(Vector3(0.2, 1.4, 0.08), Vector3(2.6, 0.08, 0.01), Color("f4a261"), 0.0, false)
			k.box(Vector3(-0.6, 1.7, 0.08), Vector3(0.08, 1.0, 0.01), Color("f4a261"), 0.0, false)
			k.box(Vector3(0.9, 1.75, 0.08), Vector3(0.7, 0.4, 0.01), Color("90be6d"), 0.0, false)
			k.box(Vector3(-1.0, 1.25, 0.08), Vector3(0.5, 0.3, 0.01), Color("8ecae6"), 0.0, false)
			for p in [Vector2(-0.3, 1.9), Vector2(0.6, 1.3), Vector2(-1.1, 1.6)]:
				k.box(Vector3(p.x, p.y, 0.09), Vector3(0.07, 0.07, 0.02), ROUGE, 0.0, false)
		"baie_radio":
			k.box(Vector3(0, 0.95, 0), Vector3(0.6, 1.9, 0.6), NOIR)
			k.layer = "lumiere"
			for i in 6:
				k.box(Vector3(-0.15 + (i % 2) * 0.3, 0.5 + i * 0.2, 0.31), Vector3(0.06, 0.03, 0.01), Color("80ed99") if i % 3 else Color("ffb703"), 0.0, false)
			k.layer = "base"
			k.tube(Vector3(0.2, 1.9, 0), Vector3(0.2, 2.5, 0), 0.015, 0.01, 4, INOX)
		"imprimante":
			k.box(Vector3(0, 0.35, 0), Vector3(0.6, 0.7, 0.5), GRIS)
			k.box(Vector3(0, 0.82, 0), Vector3(0.55, 0.24, 0.45), Color("e9ecef"))
			k.box(Vector3(0, 0.97, 0.12), Vector3(0.3, 0.02, 0.3), BLANC, 0.0, false)
		"mur_ecrans":
			for i in 3:
				for j in 2:
					k.box(Vector3(-1.05 + i * 1.05, 1.3 + j * 0.62, 0.04), Vector3(1.0, 0.58, 0.06), NOIR, 0.0, false)
			k.layer = "lumiere"
			var cols := [Color("8ecae6"), Color("90be6d"), Color("f4a261"), Color("8ecae6"), Color("e76f51"), Color("bde0fe")]
			for i in 3:
				for j in 2:
					k.box(Vector3(-1.05 + i * 1.05, 1.3 + j * 0.62, 0.08), Vector3(0.9, 0.48, 0.01), cols[i + j * 3], 0.0, false)
			k.layer = "base"
		# --- Remise --------------------------------------------------------------------
		"rack_tuyaux":
			k.box(Vector3(0, 0.9, -0.1), Vector3(1.3, 1.8, 0.08), GRIS, 0.0, false)
			for j in 3:
				k.box(Vector3(0, 0.4 + j * 0.55, 0.05), Vector3(1.3, 0.04, 0.35), INOX_F, 0.0, false)
				for i in 3:
					k.lathe(Vector3(-0.42 + i * 0.42, 0.42 + j * 0.55, 0.05), [Vector2(0.0, 0.0), Vector2(0.19, 0.0), Vector2(0.19, 0.12), Vector2(0.0, 0.12)], 10, Color("e9ecef") if (i + j) % 2 else ROUGE)
		"compresseur":
			k.box(Vector3(0, 0.45, 0), Vector3(1.1, 0.9, 0.7), Color("e9ecef"))
			k.box(Vector3(0, 0.92, 0), Vector3(1.12, 0.06, 0.72), ROUGE_F, 0.0, false)
			for i in 4:
				k.tube(Vector3(-0.4 + i * 0.27, 0.95, -0.15), Vector3(-0.4 + i * 0.27, 1.55, -0.15), 0.09, 0.09, 8, Color("ffd166") if i % 2 else INOX)
			k.box(Vector3(0.3, 0.6, 0.36), Vector3(0.3, 0.22, 0.02), NOIR, 0.0, false)
		"extincteurs":
			k.box(Vector3(0, 0.05, 0), Vector3(1.2, 0.1, 0.4), GRIS, 0.0, false)
			for i in 4:
				k.lathe(Vector3(-0.42 + i * 0.28, 0.1, 0), [Vector2(0.0, 0.0), Vector2(0.09, 0.0), Vector2(0.09, 0.5), Vector2(0.05, 0.58), Vector2(0.0, 0.6)], 8, ROUGE)
				k.box(Vector3(-0.42 + i * 0.28, 0.72, 0.03), Vector3(0.03, 0.08, 0.1), NOIR, 0.0, false)
		"desincarceration":
			k.box(Vector3(0, 0.45, 0), Vector3(1.4, 0.9, 0.55), ROUGE)
			k.box(Vector3(0, 0.92, 0), Vector3(1.42, 0.05, 0.57), NOIR, 0.0, false)
			k.box(Vector3(-0.35, 1.1, 0), Vector3(0.5, 0.3, 0.18), JAUNE)
			k.box(Vector3(0.1, 1.12, 0), Vector3(0.35, 0.08, 0.08), GRIS, 0.0, false)
			k.box(Vector3(0.45, 1.05, 0), Vector3(0.3, 0.22, 0.24), Color("ffb703"))
		"seche_tuyaux":
			for sx in [-0.45, 0.45]:
				for sz in [-0.45, 0.45]:
					k.beam(Vector3(sx, 0, sz), Vector3(sx * 0.8, 4.6, sz * 0.8), 0.08, 0.08, INOX_F)
			for j in 5:
				k.box(Vector3(0, 0.9 + j * 0.85, 0), Vector3(0.9, 0.05, 0.9), INOX_F, 0.0, false)
			for i in 4:
				k.box(Vector3(-0.3 + i * 0.2, 2.4, 0.0), Vector3(0.08, 3.6, 0.08), Color("e9ecef") if i % 2 else ROUGE, 0.0, false)
		"motopompe":
			k.box(Vector3(0, 0.12, 0), Vector3(0.9, 0.06, 0.7), NOIR, 0.0, false)
			for sx in [-0.4, 0.4]:
				k.tube(Vector3(sx, 0.1, -0.3), Vector3(sx, 0.1, 0.3), 0.05, 0.05, 6, NOIR)
				k.beam(Vector3(sx, 0.15, -0.3), Vector3(sx, 0.75, -0.3), 0.04, 0.04, ROUGE_F)
				k.beam(Vector3(sx, 0.15, 0.3), Vector3(sx, 0.75, 0.3), 0.04, 0.04, ROUGE_F)
			k.box(Vector3(0, 0.42, 0), Vector3(0.6, 0.5, 0.5), ROUGE)
			k.tube(Vector3(0.3, 0.45, 0.0), Vector3(0.55, 0.45, 0.0), 0.08, 0.08, 8, INOX)
		# --- Chambres, vestiaires --------------------------------------------------------
		"lits_superposes":
			for sx in [-0.95, 0.95]:
				for sz in [-0.45, 0.45]:
					k.beam(Vector3(sx, 0, sz), Vector3(sx, 1.75, sz), 0.06, 0.06, INOX_F)
			for h in [0.35, 1.25]:
				k.box(Vector3(0, h, 0), Vector3(1.95, 0.08, 0.95), INOX_F, 0.0, false)
				k.box(Vector3(0, h + 0.1, 0), Vector3(1.85, 0.14, 0.85), Color("e9ecef"))
				k.box(Vector3(0.2, h + 0.2, 0), Vector3(1.3, 0.06, 0.87), BLEU, 0.0, false)
				k.box(Vector3(-0.72, h + 0.22, 0), Vector3(0.32, 0.1, 0.55), BLANC)
			k.beam(Vector3(0.9, 0.4, 0.5), Vector3(0.9, 1.3, 0.5), 0.04, 0.04, INOX)
		"mat":
			k.tube(Vector3(0, 0, 0), Vector3(0, 2.9, 0), 0.05, 0.05, 8, Color("e9c46a"))
			k.lathe(Vector3.ZERO, [Vector2(0.0, 0.0), Vector2(0.55, 0.0), Vector2(0.55, 0.12), Vector2(0.0, 0.12)], 14, ROUGE_F)
			k.box(Vector3(0, 2.85, 0), Vector3(1.2, 0.08, 1.2), Color("3d3a36"), 0.0, false)
		"rideaux":
			for i in 3:
				k.box(Vector3(-1.5 + i * 1.5, 1.6, 0.08), Vector3(1.3, 1.6, 0.06), Color("2b2d42"))
			k.box(Vector3(0, 2.45, 0.08), Vector3(4.4, 0.05, 0.06), INOX, 0.0, false)
		"casiers":
			for i in 4:
				k.box(Vector3(-0.75 + i * 0.5, 0.95, 0), Vector3(0.47, 1.9, 0.5), Color("6c8ead") if i % 2 else Color("5a7a99"))
				k.box(Vector3(-0.75 + i * 0.5 + 0.15, 1.1, 0.26), Vector3(0.03, 0.12, 0.02), INOX, 0.0, false)
				for j in 3:
					k.box(Vector3(-0.75 + i * 0.5, 1.6 + j * 0.06, 0.26), Vector3(0.3, 0.02, 0.01), NOIR, 0.0, false)
		"tenues_feu":
			k.box(Vector3(0, 1.85, -0.05), Vector3(3.6, 0.06, 0.1), INOX, 0.0, false)
			for i in 6:
				var x := -1.5 + i * 0.6
				# Veste beige à bandes, pantalon dans les bottes, casque au-dessus.
				k.box(Vector3(x, 1.35, 0.1), Vector3(0.48, 0.75, 0.28), Color("c2a878"))
				k.box(Vector3(x, 1.12, 0.25), Vector3(0.49, 0.06, 0.02), JAUNE, 0.0, false)
				k.box(Vector3(x, 1.42, 0.25), Vector3(0.49, 0.06, 0.02), Color("d9d9d9"), 0.0, false)
				k.box(Vector3(x, 0.55, 0.12), Vector3(0.42, 0.5, 0.25), Color("2b2d42"))
				k.box(Vector3(x - 0.1, 0.15, 0.14), Vector3(0.16, 0.3, 0.28), NOIR)
				k.box(Vector3(x + 0.1, 0.15, 0.14), Vector3(0.16, 0.3, 0.28), NOIR)
				k.blob(Vector3(x, 2.05, 0.05), Vector3(0.17, 0.13, 0.19), Color("e9ecef"), Color("f8f9fa"), 0.04, 0)
		"sechoir_tenues":
			k.box(Vector3(0, 1.0, 0), Vector3(0.9, 2.0, 0.8), Color("dee2e6"))
			k.box(Vector3(0, 1.0, 0.41), Vector3(0.75, 1.75, 0.02), INOX, 0.0, false)
			k.box(Vector3(0.3, 1.0, 0.43), Vector3(0.04, 0.3, 0.03), NOIR, 0.0, false)
		# --- Cuisine, formation, bureau -------------------------------------------------
		"barbecue":
			k.box(Vector3(0, 0.45, 0), Vector3(1.2, 0.9, 0.6), Color("8d6e63"))
			k.box(Vector3(0, 0.92, 0), Vector3(1.0, 0.05, 0.5), NOIR, 0.0, false)
			k.layer = "lumiere"
			k.box(Vector3(0, 0.88, 0), Vector3(0.8, 0.03, 0.4), Color("ff7b00"), 0.0, false)
			k.layer = "base"
			for i in 3:
				k.box(Vector3(-0.3 + i * 0.3, 0.97, 0), Vector3(0.18, 0.05, 0.08), Color("9c4f3a"), 0.0, false)
		"mannequin_rcp":
			k.box(Vector3(0, 0.02, 0), Vector3(1.6, 0.04, 0.7), Color("2a9d8f"), 0.0, false)
			k.box(Vector3(0, 0.16, 0), Vector3(0.65, 0.22, 0.36), Color("f1c9a5"))
			k.blob(Vector3(-0.5, 0.15, 0), Vector3(0.14, 0.12, 0.13), Color("f1c9a5"), Color("f1c9a5"), 0.02, 0)
			k.box(Vector3(0.55, 0.1, -0.1), Vector3(0.5, 0.12, 0.12), Color("1d3557"))
			k.box(Vector3(0.55, 0.1, 0.1), Vector3(0.5, 0.12, 0.12), Color("1d3557"))
		"simulateur_feu":
			k.box(Vector3(0, 0.5, 0), Vector3(1.4, 1.0, 0.7), INOX_F)
			k.layer = "lumiere"
			k.box(Vector3(0, 1.05, 0), Vector3(1.0, 0.1, 0.4), Color("ff7b00"), 0.0, false)
			k.blob(Vector3(0, 1.3, 0), Vector3(0.35, 0.35, 0.18), Color("ff7b00"), Color("ffd166"), 0.3, 0)
			k.layer = "base"
			k.box(Vector3(0.55, 0.7, 0.36), Vector3(0.25, 0.2, 0.02), NOIR, 0.0, false)
		"maquette_ville":
			k.box(Vector3(0, 0.45, 0), Vector3(1.6, 0.9, 1.1), BOIS_F)
			k.box(Vector3(0, 0.92, 0), Vector3(1.5, 0.04, 1.0), Color("90be6d"), 0.0, false)
			k.box(Vector3(0, 0.95, 0), Vector3(1.5, 0.02, 0.12), GRIS, 0.0, false)
			k.box(Vector3(0.2, 0.95, 0), Vector3(0.12, 0.02, 1.0), GRIS, 0.0, false)
			var cols := [Color("e9c46a"), Color("e76f51"), Color("f1faee"), Color("a8dadc"), Color("bc6c25"), Color("f4a261")]
			for i in 6:
				var x := -0.55 + (i % 3) * 0.5
				var z := -0.3 if i < 3 else 0.28
				k.box(Vector3(x, 1.0 + 0.05 * (i % 2), z), Vector3(0.28, 0.12 + 0.1 * (i % 2), 0.24), cols[i])
		"drapeau":
			k.tube(Vector3.ZERO, Vector3(0, 2.2, 0), 0.025, 0.02, 6, OR)
			k.box(Vector3(0.32, 1.85, 0), Vector3(0.6, 0.4, 0.02), ROUGE, 0.0, false)
			k.box(Vector3(0.32, 1.85, 0.012), Vector3(0.2, 0.2, 0.01), OR, 0.0, false)
		"trophees":
			k.box(Vector3(0, 0.9, 0), Vector3(1.2, 1.8, 0.45), BOIS_F)
			for j in 3:
				k.box(Vector3(0, 0.5 + j * 0.5, 0.05), Vector3(1.1, 0.04, 0.36), BOIS, 0.0, false)
				for i in 3:
					k.lathe(Vector3(-0.35 + i * 0.35, 0.52 + j * 0.5, 0.05), [Vector2(0.0, 0.0), Vector2(0.07, 0.0), Vector2(0.02, 0.06), Vector2(0.02, 0.14), Vector2(0.09, 0.2), Vector2(0.09, 0.3), Vector2(0.0, 0.28)], 8, OR if (i + j) % 2 == 0 else INOX)
		# --- Magasin ---------------------------------------------------------------------
		"bouteilles_ari":
			k.box(Vector3(0, 0.6, -0.1), Vector3(1.4, 1.2, 0.08), GRIS, 0.0, false)
			for j in 2:
				for i in 5:
					k.tube(Vector3(-0.56 + i * 0.28, 0.1 + j * 0.62, 0.08), Vector3(-0.56 + i * 0.28, 0.6 + j * 0.62, 0.08), 0.1, 0.1, 8, Color("ffd166") if (i + j) % 2 else INOX)
		"sacs_secours":
			k.box(Vector3(0, 0.6, 0), Vector3(1.2, 1.2, 0.45), INOX_F)
			for j in 2:
				k.box(Vector3(0, 0.35 + j * 0.55, 0), Vector3(1.15, 0.04, 0.42), INOX, 0.0, false)
				for i in 2:
					k.box(Vector3(-0.28 + i * 0.56, 0.52 + j * 0.55, 0.02), Vector3(0.48, 0.3, 0.35), ROUGE if i == 0 else Color("2a9d8f"))
					k.box(Vector3(-0.28 + i * 0.56, 0.55 + j * 0.55, 0.2), Vector3(0.12, 0.12, 0.01), BLANC, 0.0, false)
		"brancards":
			for i in 2:
				var z := -0.2 + i * 0.4
				k.box(Vector3(0, 0.9 + i * 0.05, z), Vector3(0.12, 1.8, 0.1), Color("f4a261"))
				k.box(Vector3(0.2, 0.9 + i * 0.05, z), Vector3(0.03, 1.9, 0.03), INOX, 0.0, false)
				k.box(Vector3(-0.2, 0.9 + i * 0.05, z), Vector3(0.03, 1.9, 0.03), INOX, 0.0, false)
		# --- Sport ---------------------------------------------------------------------
		"corde":
			k.box(Vector3(0, 3.0, 0), Vector3(0.8, 0.1, 0.2), GRIS, 0.0, false)
			k.tube(Vector3(0, 0.4, 0), Vector3(0, 2.95, 0), 0.04, 0.04, 6, Color("c8a27a"))
			k.lathe(Vector3.ZERO, [Vector2(0.0, 0.0), Vector2(0.6, 0.0), Vector2(0.6, 0.06), Vector2(0.0, 0.06)], 12, BLEU)
		"espalier":
			for sx in [-0.5, 0.5]:
				k.box(Vector3(sx, 1.25, 0), Vector3(0.08, 2.5, 0.12), BOIS)
			for j in 9:
				k.tube(Vector3(-0.5, 0.25 + j * 0.25, 0), Vector3(0.5, 0.25 + j * 0.25, 0), 0.025, 0.025, 5, Color("d4a373"))
		"rameur":
			k.box(Vector3(0, 0.15, 0), Vector3(0.2, 0.1, 2.0), NOIR, 0.0, false)
			k.box(Vector3(0, 0.3, 0.2), Vector3(0.35, 0.08, 0.35), GRIS)
			k.lathe(Vector3(0, 0.15, -0.85), [Vector2(0.0, 0.0), Vector2(0.25, 0.0), Vector2(0.25, 0.4), Vector2(0.0, 0.4)], 10, BLEU)
			k.tube(Vector3(0, 0.4, -0.7), Vector3(0, 0.55, -0.4), 0.02, 0.02, 4, INOX)
		# --- Atelier -------------------------------------------------------------------
		"etabli":
			k.box(Vector3(0, 0.88, 0), Vector3(2.4, 0.08, 0.75), BOIS)
			for sx in [-1.1, 1.1]:
				k.box(Vector3(sx, 0.43, 0), Vector3(0.08, 0.86, 0.7), GRIS)
			k.box(Vector3(0, 1.5, -0.33), Vector3(2.4, 1.1, 0.04), Color("adb5bd"), 0.0, false)
			for i in 8:
				k.box(Vector3(-1.0 + i * 0.28, 1.5 + 0.12 * (i % 3), -0.3), Vector3(0.05, 0.35, 0.03), [ROUGE, NOIR, Color("ffb703"), INOX_F][i % 4], 0.0, false)
			k.box(Vector3(0.8, 1.0, 0.1), Vector3(0.3, 0.16, 0.2), Color("457b9d"))
		"pneus":
			for i in 4:
				k.lathe(Vector3(0, i * 0.3, 0), [Vector2(0.2, 0.0), Vector2(0.48, 0.0), Vector2(0.5, 0.15), Vector2(0.48, 0.3), Vector2(0.2, 0.3)], 12, NOIR)
		"chariot_outils":
			k.box(Vector3(0, 0.55, 0), Vector3(0.8, 0.8, 0.5), ROUGE)
			for j in 4:
				k.box(Vector3(0, 0.3 + j * 0.18, 0.26), Vector3(0.7, 0.02, 0.01), NOIR, 0.0, false)
			for sx in [-0.32, 0.32]:
				for sz in [-0.18, 0.18]:
					k.lathe(Vector3(sx, 0.0, sz), [Vector2(0.0, 0.0), Vector2(0.06, 0.0), Vector2(0.06, 0.12), Vector2(0.0, 0.12)], 6, NOIR)
			k.box(Vector3(0.6, 0.15, 0), Vector3(0.6, 0.1, 0.18), Color("ffb703"))
		"pont_elevateur":
			for sx in [-1.4, 1.4]:
				k.box(Vector3(sx, 1.4, 0), Vector3(0.3, 2.8, 0.4), Color("1d3557"))
				k.box(Vector3(sx * 0.6, 0.6, -0.9), Vector3(0.9, 0.08, 0.15), Color("ffb703"), 0.0, false)
				k.box(Vector3(sx * 0.6, 0.6, 0.9), Vector3(0.9, 0.08, 0.15), Color("ffb703"), 0.0, false)
			k.box(Vector3(0, 2.75, 0), Vector3(3.1, 0.15, 0.3), Color("1d3557"), 0.0, false)
			k.box(Vector3(0, 0.01, 0), Vector3(2.6, 0.02, 3.4), JAUNE, 0.0, false)
		# --- Cour d'honneur --------------------------------------------------------------
		"mat_drapeau":
			k.lathe(Vector3.ZERO, [Vector2(0.0, 0.0), Vector2(0.5, 0.0), Vector2(0.5, 0.2), Vector2(0.0, 0.2)], 10, Color("bdb5a6"))
			k.tube(Vector3(0, 0.2, 0), Vector3(0, 7.0, 0), 0.07, 0.05, 8, Color("e9ecef"))
			k.box(Vector3(0.75, 6.4, 0), Vector3(1.4, 0.95, 0.03), BLEU, 0.0, false)
			k.box(Vector3(1.22, 6.4, 0.005), Vector3(0.46, 0.95, 0.03), ROUGE, 0.0, false)
			k.box(Vector3(0.75, 6.4, 0.01), Vector3(0.46, 0.95, 0.03), BLANC, 0.0, false)
		"stele":
			k.box(Vector3(0, 0.12, 0), Vector3(1.8, 0.24, 1.0), Color("bdb5a6"))
			k.box(Vector3(0, 1.05, -0.15), Vector3(1.2, 1.7, 0.4), Color("9a958c"))
			k.box(Vector3(0, 1.4, 0.06), Vector3(0.8, 0.5, 0.02), OR, 0.0, false)
			k.blob(Vector3(0, 2.0, -0.15), Vector3(0.3, 0.22, 0.3), Color("8d949b"), Color("adb5bd"), 0.05, 0)
			for sx in [-0.5, 0.5]:
				k.blob(Vector3(sx, 0.4, 0.35), Vector3(0.25, 0.18, 0.18), Color("2f6b35"), Color("e63946"), 0.25, 0)
		"pompe_bras":
			for sx in [-0.5, 0.5]:
				for sz in [-0.75, 0.75]:
					k.lathe(Vector3(sx, 0.4, sz), [Vector2(0.0, -0.02), Vector2(0.4, -0.02), Vector2(0.4, 0.02), Vector2(0.0, 0.02)], 12, BOIS_F)
			k.box(Vector3(0, 0.75, 0), Vector3(0.8, 0.4, 1.4), ROUGE)
			k.tube(Vector3(0, 0.95, 0), Vector3(0, 1.45, 0), 0.14, 0.12, 10, OR)
			k.beam(Vector3(0, 1.3, -1.1), Vector3(0, 1.3, 1.1), 0.06, 0.06, BOIS)
			k.beam(Vector3(0, 0.6, 0.7), Vector3(0, 0.35, 1.6), 0.05, 0.05, BOIS)
		"camion_ancien":
			# Camion à échelle des années 1950, rouge et chromes.
			for sz in [-1.3, 1.3]:
				for sx in [-0.95, 0.95]:
					k.lathe(Vector3(sx, 0.42, sz), [Vector2(0.0, -0.12), Vector2(0.42, -0.12), Vector2(0.42, 0.12), Vector2(0.0, 0.12)], 12, NOIR)
			k.box(Vector3(0, 0.85, 0.4), Vector3(1.9, 0.7, 3.2), ROUGE)
			k.box(Vector3(0, 1.45, 1.35), Vector3(1.8, 0.55, 1.0), ROUGE)
			k.layer = "verre"
			k.box(Vector3(0, 1.55, 1.86), Vector3(1.5, 0.35, 0.03), Color(0.7, 0.85, 1.0, 0.5), 0.0, false)
			k.layer = "base"
			k.box(Vector3(0, 0.8, 2.1), Vector3(1.4, 0.5, 0.5), ROUGE_F)
			k.box(Vector3(0, 0.7, 2.37), Vector3(1.0, 0.35, 0.04), INOX, 0.0, false)
			k.beam(Vector3(-0.5, 1.35, -1.5), Vector3(-0.5, 1.65, 1.0), 0.06, 0.06, BOIS)
			k.beam(Vector3(0.5, 1.35, -1.5), Vector3(0.5, 1.65, 1.0), 0.06, 0.06, BOIS)
			for i in 8:
				k.beam(Vector3(-0.5, 1.37 + i * 0.037, -1.4 + i * 0.3), Vector3(0.5, 1.37 + i * 0.037, -1.4 + i * 0.3), 0.04, 0.04, BOIS)
			k.lathe(Vector3(0, 1.75, 1.6), [Vector2(0.0, 0.0), Vector2(0.08, 0.0), Vector2(0.06, 0.18), Vector2(0.0, 0.2)], 8, OR)
		# --- Tour de manœuvre ------------------------------------------------------------
		"echelle_crochets":
			for i in 3:
				var x := -0.5 + i * 0.5
				k.beam(Vector3(x - 0.15, 0, 0), Vector3(x - 0.15, 3.0, -0.3), 0.04, 0.04, BOIS)
				k.beam(Vector3(x + 0.15, 0, 0), Vector3(x + 0.15, 3.0, -0.3), 0.04, 0.04, BOIS)
				for j in 9:
					k.beam(Vector3(x - 0.15, 0.3 + j * 0.3, -j * 0.03), Vector3(x + 0.15, 0.3 + j * 0.3, -j * 0.03), 0.03, 0.03, BOIS_F)
		"mannequin":
			k.box(Vector3(0, 0.5, 0), Vector3(0.4, 0.6, 0.22), Color("e76f51"))
			k.box(Vector3(-0.1, 0.12, 0), Vector3(0.14, 0.25, 0.16), Color("2b2d42"))
			k.box(Vector3(0.1, 0.12, 0), Vector3(0.14, 0.25, 0.16), Color("2b2d42"))
			k.blob(Vector3(0, 0.95, 0), Vector3(0.12, 0.13, 0.12), Color("f1c9a5"), Color("f1c9a5"), 0.02, 0)
		"conteneur_feu":
			k.box(Vector3(0, 1.3, 0), Vector3(2.4, 2.6, 6.0), Color("6c757d"))
			for i in 12:
				k.box(Vector3(1.21, 1.3, -2.75 + i * 0.5), Vector3(0.02, 2.4, 0.08), Color("495057"), 0.0, false)
			k.box(Vector3(0, 1.1, 3.01), Vector3(1.0, 2.0, 0.02), NOIR, 0.0, false)
			k.box(Vector3(0, 2.75, 0), Vector3(1.2, 0.3, 0.8), INOX_F)
			k.blob(Vector3(0, 3.3, 0), Vector3(0.6, 0.5, 0.6), Color("6c757d"), Color("adb5bd"), 0.3, 0)
		"voiture_casse":
			k.box(Vector3(0, 0.55, 0), Vector3(1.7, 0.6, 3.8), Color("8d99ae"))
			k.box(Vector3(0, 1.05, -0.2), Vector3(1.5, 0.45, 1.8), Color("6c757d"))
			k.box(Vector3(0.86, 0.6, 0.6), Vector3(0.04, 0.5, 1.0), Color("495057"), 0.0, false)
			for sz in [-1.25, 1.25]:
				for sx in [-0.8, 0.8]:
					k.lathe(Vector3(sx, 0.3, sz), [Vector2(0.0, -0.1), Vector2(0.3, -0.1), Vector2(0.3, 0.1), Vector2(0.0, 0.1)], 8, NOIR)
		"parcours":
			for i in 4:
				var z := -2.0 + i * 1.3
				k.beam(Vector3(-0.7, 0, z), Vector3(-0.7, 0.4 + 0.3 * (i % 2), z), 0.1, 0.1, BOIS)
				k.beam(Vector3(0.7, 0, z), Vector3(0.7, 0.4 + 0.3 * (i % 2), z), 0.1, 0.1, BOIS)
				k.beam(Vector3(-0.7, 0.4 + 0.3 * (i % 2), z), Vector3(0.7, 0.4 + 0.3 * (i % 2), z), 0.12, 0.12, Color("d4a373"))
			k.box(Vector3(0, 0.6, 3.0), Vector3(1.6, 1.2, 0.2), BOIS_F)
		# --- Lavage ----------------------------------------------------------------------
		"pompe_carburant":
			k.box(Vector3(0, 0.08, 0), Vector3(1.4, 0.16, 0.8), Color("bdb5a6"))
			k.box(Vector3(0, 0.95, 0), Vector3(0.8, 1.6, 0.5), ROUGE)
			k.box(Vector3(0, 1.4, 0.26), Vector3(0.5, 0.35, 0.02), NOIR, 0.0, false)
			k.layer = "lumiere"
			k.box(Vector3(0, 1.42, 0.275), Vector3(0.4, 0.2, 0.01), Color("80ed99"), 0.0, false)
			k.layer = "base"
			k.tube(Vector3(0.42, 1.2, 0), Vector3(0.6, 0.7, 0.2), 0.03, 0.03, 5, NOIR)
			k.box(Vector3(0, 1.82, 0), Vector3(0.9, 0.12, 0.55), BLANC, 0.0, false)
		"karcher":
			k.box(Vector3(0, 0.35, 0), Vector3(0.5, 0.5, 0.4), Color("ffb703"))
			k.box(Vector3(0, 0.62, 0), Vector3(0.45, 0.06, 0.35), NOIR, 0.0, false)
			k.tube(Vector3(0, 0.3, 0.2), Vector3(0.4, 0.05, 0.9), 0.02, 0.02, 4, NOIR)
			for sx in [-0.22, 0.22]:
				k.lathe(Vector3(sx, 0.0, -0.15), [Vector2(0.0, 0.0), Vector2(0.1, 0.0), Vector2(0.1, 0.2), Vector2(0.0, 0.2)], 6, NOIR)
		"poteau_incendie":
			k.lathe(Vector3.ZERO, [Vector2(0.0, 0.0), Vector2(0.2, 0.0), Vector2(0.15, 0.08), Vector2(0.13, 0.7), Vector2(0.16, 0.75), Vector2(0.1, 0.9), Vector2(0.0, 0.95)], 10, ROUGE)
			for sx in [-0.17, 0.17]:
				k.tube(Vector3(sx * 0.6, 0.5, 0), Vector3(sx, 0.5, 0), 0.06, 0.06, 6, ROUGE_F)
		"cuve":
			k.lathe(Vector3.ZERO, [Vector2(0.0, 0.0), Vector2(0.75, 0.0), Vector2(0.75, 2.0), Vector2(0.6, 2.2), Vector2(0.0, 2.25)], 14, Color("2a9d8f"))
			for j in 3:
				k.lathe(Vector3(0, 0.4 + j * 0.6, 0), [Vector2(0.76, 0.0), Vector2(0.78, 0.0), Vector2(0.78, 0.06), Vector2(0.76, 0.06)], 14, Color("264653"))
			k.tube(Vector3(0.75, 0.3, 0), Vector3(1.1, 0.3, 0), 0.06, 0.06, 6, INOX_F)
