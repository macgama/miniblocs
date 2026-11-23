class_name ModelesCommissariat
extends RefCounted
## Objets low-poly du commissariat (accueil, garage, armurerie, plaintes,
## enquêteurs, cellules, stand de tir, parvis, chenil, fourrière), mêmes
## conventions que GestionModeles : origine au sol au centre de l'objet, face
## avant vers +Z, le kit est déjà placé (k.xf).

const BLEU := Color("1d3557")
const BLEU_C := Color("457b9d")
const BLANC := Color("f6f4ef")
const ROUGE := Color("c1121f")
const JAUNE := Color("ffd60a")
const ORANGE := Color("f77f00")
const INOX := Color("c9ced3")
const INOX_F := Color("8d949b")
const GRIS := Color("5c636a")
const NOIR := Color("26262b")
const BOIS := Color("8a5a3b")
const BOIS_F := Color("5c4033")
const LIEGE := Color("c8a27a")

## Places des visiteurs : modèle → [[x, z, angle, assis]] locaux.
const PLACES := {
	"objets_trouves": [[0.0, 0.8, PI, false]],
	"estafette": [[1.6, 0.0, -PI * 0.5, false]],
	"chien": [[0.0, 1.0, PI, false]],
	"niche": [[0.0, 1.1, PI, false]],
	"moto_police": [[1.0, 0.0, -PI * 0.5, false]],
}


static func dessiner(k: LpKit, nom: String, teinte := Color.WHITE) -> void:
	match nom:
		# --- Accueil -------------------------------------------------------------------
		"affiches_police":
			var cols := [BLEU, ROUGE, Color("2a9d8f")]
			for i in 3:
				k.box(Vector3(-1.0 + i * 1.0, 1.6, 0.02), Vector3(0.7, 0.95, 0.03), BLANC, 0.0, false)
				k.box(Vector3(-1.0 + i * 1.0, 1.85, 0.04), Vector3(0.55, 0.3, 0.02), cols[i], 0.0, false)
				k.box(Vector3(-1.0 + i * 1.0, 1.45, 0.04), Vector3(0.5, 0.05, 0.02), GRIS, 0.0, false)
		"objets_trouves":
			k.box(Vector3(0, 0.45, 0), Vector3(1.4, 0.9, 0.5), BOIS)
			k.layer = "verre"
			k.box(Vector3(0, 1.35, 0), Vector3(1.4, 0.9, 0.5), Color(0.8, 0.9, 1.0, 0.3), 0.0, false)
			k.layer = "base"
			var cols := [Color("e63946"), Color("ffb703"), NOIR, Color("8ecae6"), Color("6d597a")]
			for i in 5:
				k.box(Vector3(-0.5 + i * 0.25, 1.0 + (i % 2) * 0.06, 0.0), Vector3(0.18, 0.12 + (i % 3) * 0.06, 0.14), cols[i], 0.0, false)
			k.lathe(Vector3(0.4, 1.4, 0), [Vector2(0.0, 0.0), Vector2(0.1, 0.0), Vector2(0.12, 0.25), Vector2(0.0, 0.3)], 8, Color("2b2d42"))
			k.box(Vector3(-0.4, 1.4, 0), Vector3(0.3, 0.05, 0.2), JAUNE, 0.0, false)
		"portique":
			for sx in [-0.45, 0.45]:
				k.box(Vector3(sx, 1.05, 0), Vector3(0.12, 2.1, 0.5), Color("adb5bd"))
			k.box(Vector3(0, 2.15, 0), Vector3(1.05, 0.16, 0.52), Color("adb5bd"))
			k.layer = "lumiere"
			k.box(Vector3(-0.45, 1.7, 0.26), Vector3(0.06, 0.06, 0.02), Color("80ed99"), 0.0, false)
			k.layer = "base"
		"fontaine_eau":
			k.box(Vector3(0, 0.5, 0), Vector3(0.32, 1.0, 0.32), BLANC)
			k.lathe(Vector3(0, 1.0, 0), [Vector2(0.0, 0.0), Vector2(0.14, 0.0), Vector2(0.15, 0.35), Vector2(0.06, 0.42), Vector2(0.0, 0.42)], 10, Color(0.6, 0.8, 0.95))
			k.box(Vector3(0.1, 0.75, 0.17), Vector3(0.05, 0.05, 0.05), BLEU_C, 0.0, false)
		# --- Garage --------------------------------------------------------------------
		"tableau_cles":
			k.box(Vector3(0, 1.5, 0.02), Vector3(1.0, 0.7, 0.04), BOIS_F, 0.0, false)
			for i in 8:
				var x := -0.38 + (i % 4) * 0.25
				var y := 1.68 - (i / 4) * 0.3
				k.box(Vector3(x, y, 0.06), Vector3(0.03, 0.03, 0.04), INOX, 0.0, false)
				k.box(Vector3(x, y - 0.08, 0.07), Vector3(0.05, 0.1, 0.01), [BLEU, ROUGE, JAUNE, BLANC][i % 4], 0.0, false)
		"plots":
			for i in 3:
				k.lathe(Vector3(-0.6 + i * 0.6, 0, 0), [Vector2(0.0, 0.0), Vector2(0.18, 0.0), Vector2(0.18, 0.03), Vector2(0.11, 0.05), Vector2(0.02, 0.6), Vector2(0.0, 0.6)], 8, ORANGE)
				k.lathe(Vector3(-0.6 + i * 0.6, 0.3, 0), [Vector2(0.075, 0.0), Vector2(0.065, 0.1), Vector2(0.0, 0.1)], 8, BLANC, false, false)
			k.box(Vector3(0, 0.55, -0.25), Vector3(1.6, 0.18, 0.04), ROUGE, 0.0, false)
			for sx in [-0.7, 0.7]:
				k.box(Vector3(sx, 0.3, -0.25), Vector3(0.05, 0.6, 0.3), GRIS, 0.0, false)
		"moto_police":
			k.lathe(Vector3(0, 0.32, -0.7), [Vector2(0.0, -0.08), Vector2(0.32, -0.08), Vector2(0.32, 0.08), Vector2(0.0, 0.08)], 10, NOIR)
			k.lathe(Vector3(0, 0.32, 0.7), [Vector2(0.0, -0.08), Vector2(0.32, -0.08), Vector2(0.32, 0.08), Vector2(0.0, 0.08)], 10, NOIR)
			k.box(Vector3(0, 0.62, 0), Vector3(0.36, 0.4, 1.1), BLANC)
			k.box(Vector3(0, 0.88, -0.25), Vector3(0.32, 0.12, 0.6), NOIR)
			k.box(Vector3(0, 0.95, 0.45), Vector3(0.6, 0.45, 0.2), BLEU)
			k.box(Vector3(0, 0.66, -0.75), Vector3(0.5, 0.35, 0.3), BLANC)
			k.layer = "lumiere"
			k.box(Vector3(0, 1.3, 0.48), Vector3(0.3, 0.06, 0.06), Color("4ea8de"), 0.0, false)
			k.layer = "base"
		"radar":
			k.tube(Vector3(-0.25, 0, -0.2), Vector3(0, 1.0, 0), 0.02, 0.02, 4, GRIS)
			k.tube(Vector3(0.25, 0, -0.2), Vector3(0, 1.0, 0), 0.02, 0.02, 4, GRIS)
			k.tube(Vector3(0, 0, 0.25), Vector3(0, 1.0, 0), 0.02, 0.02, 4, GRIS)
			k.box(Vector3(0, 1.15, 0), Vector3(0.4, 0.3, 0.3), Color("343a40"))
			k.lathe(Vector3(0, 1.15, 0.16), [Vector2(0.0, 0.0), Vector2(0.1, 0.0), Vector2(0.1, 0.04), Vector2(0.0, 0.04)], 10, NOIR)
		# --- Vestiaires et repos -------------------------------------------------------
		"uniformes":
			k.box(Vector3(0, 1.8, 0.05), Vector3(1.8, 0.04, 0.04), INOX, 0.0, false)
			for i in 5:
				var x := -0.72 + i * 0.36
				k.box(Vector3(x, 1.4, 0.1), Vector3(0.3, 0.7, 0.12), BLEU)
				k.box(Vector3(x, 1.55, 0.17), Vector3(0.3, 0.06, 0.02), BLANC, 0.0, false)
				k.box(Vector3(x, 0.15, 0.1), Vector3(0.26, 0.3, 0.2), NOIR)
		# --- Plaintes ------------------------------------------------------------------
		"cloison":
			k.box(Vector3(0, 0.75, 0), Vector3(0.06, 1.5, 2.2), Color("b8c0c8"))
			k.box(Vector3(0, 1.52, 0), Vector3(0.08, 0.04, 2.2), GRIS, 0.0, false)
		# --- Enquêteurs ----------------------------------------------------------------
		"tableau_enquete":
			k.box(Vector3(0, 1.6, 0.02), Vector3(2.2, 1.1, 0.04), LIEGE, 0.0, false)
			k.box(Vector3(0, 1.6, 0.01), Vector3(2.3, 1.2, 0.03), BOIS_F, 0.0, false)
			var pts := [Vector3(-0.8, 1.9, 0.05), Vector3(-0.1, 1.35, 0.05), Vector3(0.7, 1.85, 0.05), Vector3(0.45, 1.3, 0.05), Vector3(-0.6, 1.3, 0.05)]
			for p in pts:
				k.box(p, Vector3(0.26, 0.3, 0.01), BLANC, 0.0, false)
				k.box(p + Vector3(0, 0.12, 0.01), Vector3(0.04, 0.04, 0.01), ROUGE, 0.0, false)
			for i in 4:
				k.beam(pts[i] + Vector3(0, 0.12, 0.02), pts[i + 1] + Vector3(0, 0.12, 0.02), 0.012, 0.005, ROUGE, Vector3.BACK)
		"classeurs":
			k.box(Vector3(0, 0.75, 0), Vector3(1.0, 1.5, 0.5), Color("adb5bd"))
			for j in 4:
				k.box(Vector3(0, 0.25 + j * 0.36, 0.26), Vector3(0.9, 0.3, 0.02), Color("ced4da"), 0.0, false)
				k.box(Vector3(0, 0.32 + j * 0.36, 0.275), Vector3(0.2, 0.04, 0.02), GRIS, 0.0, false)
		"valise_empreintes":
			k.box(Vector3(0, 0.37, 0), Vector3(0.8, 0.74, 0.5), GRIS)
			k.box(Vector3(0, 0.9, 0), Vector3(0.5, 0.3, 0.35), Color("343a40"))
			k.box(Vector3(0, 1.06, 0), Vector3(0.48, 0.02, 0.33), INOX, 0.0, false)
			k.box(Vector3(0.1, 1.08, 0.05), Vector3(0.12, 0.02, 0.08), NOIR, 0.0, false)
		"labo_police":
			k.box(Vector3(0, 0.45, 0), Vector3(1.8, 0.9, 0.65), BLANC)
			k.box(Vector3(0, 0.92, 0), Vector3(1.85, 0.04, 0.7), Color("343a40"), 0.0, false)
			k.box(Vector3(-0.5, 1.15, -0.1), Vector3(0.3, 0.4, 0.3), INOX)
			k.lathe(Vector3(0.2, 0.94, 0.05), [Vector2(0.0, 0.0), Vector2(0.05, 0.0), Vector2(0.05, 0.18), Vector2(0.0, 0.18)], 6, Color(0.6, 0.85, 0.7))
			k.lathe(Vector3(0.35, 0.94, 0.05), [Vector2(0.0, 0.0), Vector2(0.05, 0.0), Vector2(0.05, 0.14), Vector2(0.0, 0.14)], 6, Color(0.9, 0.6, 0.6))
			k.box(Vector3(0.6, 1.05, 0), Vector3(0.3, 0.2, 0.3), BLEU_C)
		# --- Pause ---------------------------------------------------------------------
		"beignets":
			k.box(Vector3(0, 0.74, 0), Vector3(1.2, 0.05, 0.7), BOIS)
			for sx in [-0.5, 0.5]:
				k.box(Vector3(sx, 0.36, 0), Vector3(0.05, 0.72, 0.6), GRIS, 0.0, false)
			k.box(Vector3(0, 0.82, 0), Vector3(0.45, 0.1, 0.32), Color("f1e3c6"))
			for i in 4:
				k.lathe(Vector3(-0.12 + (i % 2) * 0.24, 0.87, -0.07 + (i / 2) * 0.14), [Vector2(0.03, 0.0), Vector2(0.07, 0.0), Vector2(0.07, 0.04), Vector2(0.03, 0.04)], 8, [Color("ff8fab"), Color("c68b59"), Color("ffd166"), Color("7b4b2a")][i])
		# --- Armurerie -----------------------------------------------------------------
		"gilets":
			k.box(Vector3(0, 1.75, 0.05), Vector3(1.6, 0.04, 0.04), INOX, 0.0, false)
			for i in 4:
				k.box(Vector3(-0.6 + i * 0.4, 1.4, 0.1), Vector3(0.34, 0.6, 0.12), Color("2b2d42"))
				k.box(Vector3(-0.6 + i * 0.4, 1.5, 0.17), Vector3(0.3, 0.08, 0.02), BLANC, 0.0, false)
		"chargeur_radios":
			k.box(Vector3(0, 0.45, 0), Vector3(1.0, 0.9, 0.45), GRIS)
			k.box(Vector3(0, 0.93, 0), Vector3(0.9, 0.06, 0.35), NOIR, 0.0, false)
			for i in 6:
				k.box(Vector3(-0.36 + i * 0.145, 1.05, 0), Vector3(0.08, 0.2, 0.05), NOIR, 0.0, false)
				k.layer = "lumiere"
				k.box(Vector3(-0.36 + i * 0.145, 0.97, 0.18), Vector3(0.03, 0.02, 0.01), Color("80ed99") if i % 3 else Color("ffb703"), 0.0, false)
				k.layer = "base"
		"armoire_forte":
			k.box(Vector3(0, 0.95, 0), Vector3(0.9, 1.9, 0.55), Color("495057"))
			k.box(Vector3(0, 0.95, 0.28), Vector3(0.02, 1.8, 0.02), NOIR, 0.0, false)
			k.lathe(Vector3(0.18, 1.0, 0.28), [Vector2(0.0, 0.0), Vector2(0.07, 0.0), Vector2(0.07, 0.04), Vector2(0.0, 0.04)], 8, INOX)
		"scelles":
			for j in 3:
				k.box(Vector3(0, 0.3 + j * 0.6, 0), Vector3(1.4, 0.04, 0.45), INOX_F, 0.0, false)
				for i in 3:
					k.box(Vector3(-0.45 + i * 0.45, 0.45 + j * 0.6, 0), Vector3(0.35, 0.26, 0.35), Color("c9a66b"), 0.0, false)
					k.box(Vector3(-0.45 + i * 0.45, 0.45 + j * 0.6, 0.18), Vector3(0.36, 0.04, 0.01), ROUGE, 0.0, false)
			for sx in [-0.7, 0.7]:
				k.box(Vector3(sx, 0.9, 0), Vector3(0.04, 1.8, 0.45), INOX_F, 0.0, false)
		# --- Cellules ------------------------------------------------------------------
		"camera_surv":
			k.box(Vector3(0, 2.5, -0.05), Vector3(0.1, 0.1, 0.1), GRIS, 0.0, false)
			k.box(Vector3(0, 2.4, 0.1), Vector3(0.14, 0.12, 0.3), BLANC)
			k.layer = "lumiere"
			k.box(Vector3(0.04, 2.44, 0.26), Vector3(0.02, 0.02, 0.01), ROUGE, 0.0, false)
			k.layer = "base"
		"toise":
			k.box(Vector3(0, 1.1, 0.02), Vector3(0.9, 2.0, 0.02), Color("dee2e6"), 0.0, false)
			for j in 9:
				k.box(Vector3(0, 0.4 + j * 0.2, 0.035), Vector3(0.9 if j % 2 == 0 else 0.45, 0.012, 0.01), NOIR, 0.0, false)
		"table_audition":
			k.box(Vector3(0, 0.74, 0), Vector3(1.2, 0.05, 0.8), Color("adb5bd"))
			k.box(Vector3(0, 0.37, 0), Vector3(0.1, 0.74, 0.1), GRIS, 0.0, false)
			for sz in [-0.65, 0.65]:
				k.box(Vector3(0, 0.44, sz), Vector3(0.44, 0.06, 0.44), GRIS)
				k.box(Vector3(0, 0.7, sz + signf(sz) * 0.2), Vector3(0.44, 0.5, 0.05), GRIS, 0.0, false)
			k.layer = "lumiere"
			k.lathe(Vector3(0, 1.8, 0), [Vector2(0.0, 0.0), Vector2(0.2, 0.0), Vector2(0.06, 0.18), Vector2(0.0, 0.18)], 8, Color("fff3b0"))
			k.layer = "base"
		# --- Tir -----------------------------------------------------------------------
		"cible":
			k.box(Vector3(0, 1.2, 0), Vector3(0.6, 0.9, 0.03), BLANC, 0.0, false)
			k.blob(Vector3(0, 1.45, 0.02), Vector3(0.12, 0.14, 0.01), NOIR, NOIR, 0.0, 0)
			k.box(Vector3(0, 1.1, 0.02), Vector3(0.36, 0.45, 0.01), NOIR, 0.0, false)
			k.box(Vector3(0, 1.15, 0.03), Vector3(0.12, 0.12, 0.01), ROUGE, 0.0, false)
			k.box(Vector3(0, 2.4, 0), Vector3(0.1, 0.1, 0.6), GRIS, 0.0, false)
			k.box(Vector3(0, 2.05, 0), Vector3(0.02, 0.6, 0.02), GRIS, 0.0, false)
		"tapis_sol":
			k.box(Vector3(0, 0.04, 0), Vector3(3.0, 0.08, 2.0), Color("1d4e89"))
			k.box(Vector3(0, 0.085, 0), Vector3(2.2, 0.005, 1.4), Color("e63946"), 0.0, false)
		# --- Parvis --------------------------------------------------------------------
		"feu_tricolore":
			k.tube(Vector3.ZERO, Vector3(0, 1.6, 0), 0.04, 0.04, 6, GRIS)
			k.box(Vector3(0, 1.85, 0.05), Vector3(0.22, 0.6, 0.16), NOIR)
			k.layer = "lumiere"
			for j in 3:
				k.box(Vector3(0, 2.05 - j * 0.19, 0.14), Vector3(0.1, 0.1, 0.02), [Color("ff4d4d"), Color("ffb703"), Color("80ed99")][j], 0.0, false)
			k.layer = "base"
		"estafette":
			var c := Color("1d3557") if teinte == Color.WHITE else teinte
			k.box(Vector3(0, 0.55, 0), Vector3(1.7, 0.6, 3.8), c)
			k.box(Vector3(0, 1.35, -0.15), Vector3(1.68, 1.0, 3.4), c)
			k.box(Vector3(0, 1.0, 1.65), Vector3(1.7, 0.05, 0.4), BLANC, 0.0, false)
			k.layer = "verre"
			k.box(Vector3(0, 1.45, 1.56), Vector3(1.5, 0.5, 0.03), Color(0.55, 0.7, 0.82, 0.75), 0.0, false)
			k.layer = "base"
			k.box(Vector3(0, 1.1, 0.0), Vector3(1.72, 0.12, 3.0), BLANC, 0.0, false)
			k.layer = "lumiere"
			k.box(Vector3(0, 1.95, 0.8), Vector3(0.3, 0.14, 0.2), Color("4ea8de"), 0.0, false)
			k.layer = "base"
			for sx in [-0.8, 0.8]:
				for sz in [-1.2, 1.2]:
					k.lathe(Vector3(sx, 0.3, sz), [Vector2(0.0, -0.1), Vector2(0.3, -0.1), Vector2(0.3, 0.1), Vector2(0.0, 0.1)], 10, NOIR)
		# --- Chenil --------------------------------------------------------------------
		"niche":
			k.box(Vector3(0, 0.4, 0), Vector3(0.9, 0.8, 1.0), BOIS)
			k.beam(Vector3(-0.5, 0.8, 0), Vector3(0, 1.2, 0), 0.06, 1.1, BOIS_F, Vector3.FORWARD)
			k.beam(Vector3(0.5, 0.8, 0), Vector3(0, 1.2, 0), 0.06, 1.1, BOIS_F, Vector3.FORWARD)
			k.box(Vector3(0, 0.3, 0.51), Vector3(0.4, 0.5, 0.02), NOIR, 0.0, false)
		"haie_chien":
			for sx in [-0.6, 0.6]:
				k.box(Vector3(sx, 0.4, 0), Vector3(0.06, 0.8, 0.06), BLANC)
			k.box(Vector3(0, 0.55, 0), Vector3(1.2, 0.05, 0.04), ROUGE, 0.0, false)
			k.box(Vector3(0, 0.3, 0), Vector3(1.2, 0.05, 0.04), BLANC, 0.0, false)
		"chien":
			var c := Color("8c5a2b") if teinte == Color.WHITE else teinte
			k.blob(Vector3(0, 0.45, 0), Vector3(0.18, 0.18, 0.4), c, c.lightened(0.15), 0.05, 0)
			k.blob(Vector3(0, 0.68, 0.38), Vector3(0.13, 0.14, 0.16), c, c.lightened(0.15), 0.05, 0)
			k.box(Vector3(0, 0.64, 0.55), Vector3(0.08, 0.07, 0.12), Color("2b2118"), 0.0, false)
			for sx in [-0.08, 0.08]:
				k.box(Vector3(sx, 0.85, 0.36), Vector3(0.05, 0.12, 0.04), Color("2b2118"), 0.0, false)
				for sz in [-0.25, 0.25]:
					k.box(Vector3(sx, 0.18, sz), Vector3(0.06, 0.36, 0.06), c, 0.0, false)
			k.box(Vector3(0, 0.5, 0.25), Vector3(0.3, 0.06, 0.06), BLEU, 0.0, false)
			k.beam(Vector3(0, 0.5, -0.38), Vector3(0, 0.7, -0.55), 0.04, 0.04, c)
		"gamelle":
			k.lathe(Vector3.ZERO, [Vector2(0.0, 0.0), Vector2(0.14, 0.0), Vector2(0.17, 0.08), Vector2(0.0, 0.08)], 10, INOX)
			k.lathe(Vector3(0, 0.07, 0), [Vector2(0.0, 0.0), Vector2(0.13, 0.0), Vector2(0.0, 0.015)], 10, Color("7f4f24"))
		# --- Fourrière -----------------------------------------------------------------
		"grillage":
			for i in 11:
				k.beam(Vector3(-4.8 + i * 0.96, 0, 0), Vector3(-4.8 + i * 0.96, 1.8, 0), 0.05, 0.05, GRIS)
			k.beam(Vector3(-4.8, 1.8, 0), Vector3(4.8, 1.8, 0), 0.04, 0.04, GRIS)
			k.layer = "verre"
			k.box(Vector3(0, 0.9, 0), Vector3(9.6, 1.8, 0.02), Color(0.55, 0.6, 0.65, 0.35), 0.0, false)
			k.layer = "base"
			k.box(Vector3(3.0, 1.0, 0.05), Vector3(1.0, 0.5, 0.02), BLANC, 0.0, false)
			k.box(Vector3(3.0, 1.0, 0.065), Vector3(0.8, 0.1, 0.01), ROUGE, 0.0, false)
		"depanneuse":
			k.box(Vector3(0, 0.6, 1.4), Vector3(2.0, 1.4, 1.6), Color("f8f9fa"))
			k.layer = "verre"
			k.box(Vector3(0, 1.0, 2.21), Vector3(1.8, 0.55, 0.03), Color(0.55, 0.7, 0.82, 0.75), 0.0, false)
			k.layer = "base"
			k.box(Vector3(0, 0.65, -1.0), Vector3(2.1, 0.25, 3.2), Color("495057"))
			k.beam(Vector3(0, 0.8, -1.8), Vector3(0, 1.6, -0.6), 0.12, 0.12, ORANGE)
			k.layer = "lumiere"
			k.box(Vector3(0, 1.38, 1.4), Vector3(1.2, 0.1, 0.2), Color("ffb703"), 0.0, false)
			k.layer = "base"
			for sx in [-0.95, 0.95]:
				for sz in [-1.8, -0.6, 1.4]:
					k.lathe(Vector3(sx, 0.4, sz), [Vector2(0.0, -0.12), Vector2(0.4, -0.12), Vector2(0.4, 0.12), Vector2(0.0, 0.12)], 10, NOIR)
		"sabot":
			for i in 3:
				var p := Vector3(-0.5 + i * 0.5, 0, 0)
				k.lathe(p, [Vector2(0.0, 0.0), Vector2(0.18, 0.0), Vector2(0.18, 0.3), Vector2(0.0, 0.3)], 8, JAUNE)
				k.box(p + Vector3(0, 0.32, 0), Vector3(0.1, 0.06, 0.4), NOIR, 0.0, false)
		_:
			ModelesHopital.dessiner(k, nom, teinte)
