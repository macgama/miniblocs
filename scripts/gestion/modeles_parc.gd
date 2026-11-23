class_name ModelesParc
extends RefCounted
## Objets low-poly du parc de loisirs (billetterie, files d'attente, plage,
## petits, restauration, scène, atelier, parking), mêmes conventions que
## GestionModeles : origine au sol au centre de l'objet, face avant vers +Z,
## le kit est déjà placé (k.xf).

const ROUGE := Color("d62828")
const JAUNE := Color("ffc93c")
const BLEU := Color("277da1")
const CIEL := Color("4cc9f0")
const VERT := Color("43aa8b")
const ROSE := Color("f78fb3")
const VIOLET := Color("7b2cbf")
const ORANGE := Color("f77f00")
const BLANC := Color("f8f4ea")
const BOIS := Color("9c6644")
const METAL := Color("adb5bd")
const GRIS := Color("5c636a")
const NOIR := Color("26262b")
const VIFS := [Color("d62828"), Color("ffc93c"), Color("277da1"), Color("43aa8b"), Color("f78fb3"), Color("7b2cbf"), Color("f77f00"), Color("4cc9f0")]

## Places des visiteurs : modèle → [[x, z, angle, assis]] locaux.
const PLACES := {
	"pk_table_pique": [[-0.55, -0.75, 0.0, true], [0.55, -0.75, 0.0, true], [-0.55, 0.75, PI, true], [0.55, 0.75, PI, true]],
	"pk_gradins": [[-1.6, -0.2, 0.0, true], [-0.5, -0.2, 0.0, true], [0.6, -0.2, 0.0, true], [1.7, -0.2, 0.0, true], [-1.1, 0.7, 0.0, true], [1.1, 0.7, 0.0, true]],
	"pk_transat": [[0.0, 0.0, 0.0, true]],
	"pk_borne_photo": [[0.0, 0.9, PI, false]],
	"pk_ballons": [[0.0, 0.9, PI, false]],
	"pk_maquillage": [[0.0, 0.9, PI, true]],
	"pk_friterie": [[0.0, 1.4, PI, false]],
	"pk_barbe_papa": [[0.0, 1.1, PI, false]],
	"pk_food_truck": [[0.0, 2.0, PI, false]],
	"pk_photo_frisson": [[0.0, 1.0, PI, false]],
	"pk_orgue": [[0.0, 1.1, PI, false]],
}


static func _roue(k: LpKit, p: Vector3, r: float, col := NOIR) -> void:
	k.tube(p + Vector3(-0.04, 0, 0), p + Vector3(0.04, 0, 0), r, r, 10, col)


static func dessiner(k: LpKit, nom: String, _teinte := Color.WHITE) -> void:
	match nom:
		# --- Billetterie -------------------------------------------------------------------
		"pk_borne_billets":
			k.box(Vector3(0, 0.7, 0), Vector3(0.55, 1.4, 0.45), ROUGE)
			k.box(Vector3(0, 1.45, 0), Vector3(0.6, 0.1, 0.5), JAUNE)
			k.box(Vector3(0, 1.05, 0.23), Vector3(0.4, 0.3, 0.02), NOIR, 0.0, false)
			k.layer = "lumiere"
			k.box(Vector3(0, 1.05, 0.24), Vector3(0.34, 0.24, 0.01), CIEL, 0.0, false)
			k.layer = "base"
			k.box(Vector3(0, 0.7, 0.23), Vector3(0.2, 0.05, 0.02), GRIS, 0.0, false)
		"pk_plan_parc":
			k.tube(Vector3(-0.8, 0, 0), Vector3(-0.8, 2.0, 0), 0.05, 0.05, 6, GRIS)
			k.tube(Vector3(0.8, 0, 0), Vector3(0.8, 2.0, 0), 0.05, 0.05, 6, GRIS)
			k.box(Vector3(0, 1.4, 0), Vector3(1.8, 1.1, 0.06), Color("7fb069"))
			for i in 6:
				k.box(Vector3(-0.6 + (i % 3) * 0.6, 1.2 + (i / 3) * 0.45, 0.04), Vector3(0.3, 0.2, 0.02), VIFS[i], 0.0, false)
			k.box(Vector3(0, 1.4, 0.04), Vector3(1.6, 0.05, 0.02), Color("e9d8a6"), 0.0, false)
			k.box(Vector3(0, 2.05, 0), Vector3(1.9, 0.16, 0.08), ROUGE)
		"pk_poussettes":
			for i in 3:
				var x := -0.7 + i * 0.7
				k.box(Vector3(x, 0.55, 0), Vector3(0.45, 0.35, 0.7), VIFS[(i + 2) % 8])
				k.box(Vector3(x, 0.85, -0.2), Vector3(0.45, 0.35, 0.25), VIFS[(i + 2) % 8].darkened(0.2))
				for sz in [-0.25, 0.25]:
					_roue(k, Vector3(x - 0.22, 0.12, sz), 0.12)
					_roue(k, Vector3(x + 0.22, 0.12, sz), 0.12)
				k.beam(Vector3(x, 0.7, 0.35), Vector3(x, 1.0, 0.5), 0.03, 0.03, GRIS)
		"pk_mascotte":
			# Un gros ours en costume, qui fait coucou.
			var poil := Color("c68642")
			k.blob(Vector3(0, 0.75, 0), Vector3(0.45, 0.6, 0.4), poil, poil, 0.05, 1)
			k.blob(Vector3(0, 1.55, 0), Vector3(0.38, 0.36, 0.36), poil, poil, 0.05, 1)
			k.blob(Vector3(0, 1.48, 0.3), Vector3(0.16, 0.12, 0.1), Color("f3d2a7"), Color("f3d2a7"), 0.0, 0)
			for sx in [-0.26, 0.26]:
				k.blob(Vector3(sx, 1.88, 0), Vector3(0.12, 0.12, 0.08), poil.darkened(0.15), poil.darkened(0.15), 0.0, 0)
				k.blob(Vector3(sx * 0.5, 1.62, 0.32), Vector3(0.04, 0.05, 0.02), NOIR, NOIR, 0.0, 0)
				k.blob(Vector3(sx * 0.7, 0.12, 0.08), Vector3(0.16, 0.12, 0.22), poil.darkened(0.2), poil.darkened(0.2), 0.0, 0)
			k.beam(Vector3(0.38, 1.05, 0), Vector3(0.62, 1.6, 0.1), 0.16, 0.16, poil)
			k.beam(Vector3(-0.38, 1.05, 0), Vector3(-0.5, 0.6, 0.15), 0.16, 0.16, poil)
			k.box(Vector3(0, 0.9, 0.38), Vector3(0.5, 0.35, 0.04), ROUGE, 0.0, false)
		"pk_comptoir_pass":
			k.box(Vector3(0, 0.55, 0), Vector3(1.6, 1.1, 0.6), Color("1d3557"))
			k.box(Vector3(0, 1.12, 0), Vector3(1.7, 0.05, 0.7), JAUNE)
			k.box(Vector3(0, 0.6, 0.31), Vector3(1.2, 0.3, 0.02), JAUNE, 0.0, false)
			k.box(Vector3(0, 2.0, -0.3), Vector3(1.4, 0.4, 0.05), JAUNE, 0.0, false)
			k.tube(Vector3(0, 1.1, -0.3), Vector3(0, 1.8, -0.3), 0.03, 0.03, 5, GRIS)
		# --- Files d'attente ---------------------------------------------------------------
		"pk_file_ombre":
			for sx in [-2.0, 2.0]:
				for sz in [-0.6, 0.6]:
					k.tube(Vector3(sx, 0, sz), Vector3(sx, 2.4, sz), 0.05, 0.05, 6, BOIS)
			k.box(Vector3(0, 2.45, 0), Vector3(4.4, 0.06, 1.6), Color("f2e8cf"))
			for i in 9:
				k.box(Vector3(-2.0 + i * 0.5, 2.5, 0), Vector3(0.1, 0.04, 1.62), VERT if i % 2 == 0 else BLANC, 0.0, false)
			for i in 4:
				k.blob(Vector3(-1.5 + i * 1.0, 2.6, 0.8), Vector3(0.25, 0.18, 0.2), Color("2f6b35"), Color("4f9d45"), 0.2, 0)
		"pk_ecran_attente":
			k.tube(Vector3.ZERO, Vector3(0, 1.8, 0), 0.06, 0.06, 6, GRIS)
			k.box(Vector3(0, 2.1, 0), Vector3(1.4, 0.7, 0.12), NOIR)
			k.layer = "lumiere"
			k.box(Vector3(0, 2.1, 0.07), Vector3(1.26, 0.56, 0.01), Color("1b4332"), 0.0, false)
			k.box(Vector3(-0.3, 2.2, 0.08), Vector3(0.5, 0.14, 0.01), Color("80ed99"), 0.0, false)
			k.box(Vector3(0.35, 2.0, 0.08), Vector3(0.35, 0.18, 0.01), JAUNE, 0.0, false)
			k.layer = "base"
		"pk_ballons":
			k.box(Vector3(0, 0.45, 0), Vector3(0.5, 0.9, 0.4), BLEU)
			for i in 9:
				var a := i * TAU / 9.0
				var top := Vector3(cos(a) * 0.45, 2.1 + 0.25 * sin(i * 1.7), sin(a) * 0.35)
				k.beam(Vector3(0, 0.9, 0), top - Vector3(0, 0.25, 0), 0.01, 0.01, BLANC)
				k.blob(top, Vector3(0.18, 0.22, 0.18), VIFS[i % 8], VIFS[i % 8].lightened(0.25), 0.0, 0)
		"pk_orgue":
			k.box(Vector3(0, 0.75, 0), Vector3(1.0, 0.9, 0.6), Color("7b2d26"))
			k.box(Vector3(0, 1.25, 0.0), Vector3(1.05, 0.1, 0.65), JAUNE)
			for i in 6:
				k.tube(Vector3(-0.35 + i * 0.14, 1.3, -0.1), Vector3(-0.35 + i * 0.14, 1.55 + i * 0.05, -0.1), 0.04, 0.04, 6, Color("d4af37"))
			for sx in [-0.45, 0.45]:
				_roue(k, Vector3(sx, 0.3, 0.0), 0.3, BOIS)
			k.beam(Vector3(0.5, 0.95, 0.0), Vector3(0.65, 0.95, 0.15), 0.03, 0.03, GRIS)
		"pk_borne_photo":
			k.box(Vector3(0, 0.9, 0), Vector3(0.9, 1.8, 0.5), JAUNE)
			k.box(Vector3(0, 1.5, 0.26), Vector3(0.5, 0.35, 0.02), NOIR, 0.0, false)
			k.layer = "lumiere"
			k.box(Vector3(0, 1.5, 0.27), Vector3(0.44, 0.29, 0.01), Color("a8dadc"), 0.0, false)
			k.layer = "base"
			k.box(Vector3(0, 0.6, 0.26), Vector3(0.3, 0.05, 0.02), GRIS, 0.0, false)
			k.box(Vector3(0, 1.95, 0), Vector3(1.0, 0.3, 0.55), ROUGE)
		"pk_coupe_file":
			k.box(Vector3(0, 0.6, 0), Vector3(0.5, 1.2, 0.4), VIOLET)
			k.box(Vector3(0, 1.25, 0), Vector3(0.55, 0.1, 0.45), JAUNE)
			k.layer = "lumiere"
			k.box(Vector3(0, 0.95, 0.21), Vector3(0.36, 0.2, 0.01), Color("80ed99"), 0.0, false)
			k.layer = "base"
			k.box(Vector3(0, 1.8, 0), Vector3(0.7, 0.45, 0.05), VIOLET, 0.0, false)
			k.box(Vector3(0, 1.8, 0.03), Vector3(0.5, 0.15, 0.02), JAUNE, 0.0, false)
			k.tube(Vector3(0, 1.3, 0), Vector3(0, 1.6, 0), 0.03, 0.03, 5, GRIS)
		"pk_brumisateur":
			k.tube(Vector3.ZERO, Vector3(0, 2.6, 0), 0.05, 0.05, 6, METAL)
			k.beam(Vector3(-0.8, 2.55, 0), Vector3(0.8, 2.55, 0), 0.04, 0.04, METAL)
			k.layer = "verre"
			for sx in [-0.7, 0.0, 0.7]:
				k.blob(Vector3(sx, 2.1, 0), Vector3(0.3, 0.4, 0.3), Color(0.85, 0.95, 1.0, 0.35), Color(0.85, 0.95, 1.0, 0.35), 0.1, 0)
			k.layer = "base"
		"pk_photo_frisson":
			k.box(Vector3(0, 0.55, 0), Vector3(1.8, 1.1, 0.6), NOIR)
			k.box(Vector3(0, 1.12, 0), Vector3(1.9, 0.05, 0.7), VIOLET)
			for i in 3:
				k.box(Vector3(-0.6 + i * 0.6, 1.8, -0.2), Vector3(0.5, 0.36, 0.04), GRIS, 0.0, false)
				k.layer = "lumiere"
				k.box(Vector3(-0.6 + i * 0.6, 1.8, -0.17), Vector3(0.44, 0.3, 0.01), [Color("ffb4a2"), Color("a8dadc"), Color("ffe066")][i], 0.0, false)
				k.layer = "base"
			k.box(Vector3(0, 2.3, -0.2), Vector3(1.9, 0.3, 0.06), VIOLET, 0.0, false)
		"pk_wagonnet":
			k.box(Vector3(0, 0.55, 0), Vector3(0.9, 0.6, 1.4), BOIS)
			k.box(Vector3(0, 0.88, 0), Vector3(0.95, 0.06, 1.45), GRIS, 0.0, false)
			for sx in [-0.42, 0.42]:
				for sz in [-0.45, 0.45]:
					_roue(k, Vector3(sx, 0.2, sz), 0.18, GRIS)
			for i in 4:
				k.stone(Vector3(-0.2 + (i % 2) * 0.35, 0.95, -0.35 + (i / 2) * 0.55), Vector3(0.3, 0.2, 0.3), Color("6d6875"))
			k.beam(Vector3(-0.9, 0.02, -1.2), Vector3(-0.9, 0.02, 1.2), 0.08, 0.04, GRIS)
			k.beam(Vector3(0.9, 0.02, -1.2), Vector3(0.9, 0.02, 1.2), 0.08, 0.04, GRIS)
		# --- Plage et rivière --------------------------------------------------------------
		"pk_transat":
			k.box(Vector3(0, 0.25, 0.3), Vector3(0.6, 0.06, 1.1), BLANC)
			k.beam(Vector3(0, 0.27, -0.25), Vector3(0, 0.75, -0.6), 0.6, 0.06, BLANC)
			for i in 5:
				k.box(Vector3(-0.2 + i * 0.1, 0.29, 0.3), Vector3(0.05, 0.01, 1.05), BLEU if i % 2 == 0 else BLANC, 0.0, false)
			for sx in [-0.28, 0.28]:
				k.box(Vector3(sx, 0.12, 0.7), Vector3(0.04, 0.24, 0.04), METAL, 0.0, false)
				k.box(Vector3(sx, 0.12, -0.2), Vector3(0.04, 0.24, 0.04), METAL, 0.0, false)
		"pk_chaise_mn":
			for sx in [-0.4, 0.4]:
				for sz in [-0.3, 0.3]:
					k.beam(Vector3(sx, 0, sz), Vector3(sx * 0.6, 1.8, sz * 0.6), 0.06, 0.06, BLANC)
			k.box(Vector3(0, 1.85, 0), Vector3(0.6, 0.06, 0.5), ROUGE)
			k.box(Vector3(0, 2.2, -0.24), Vector3(0.6, 0.6, 0.05), ROUGE)
			k.lathe(Vector3(0, 2.6, 0), [Vector2(0.0, 0.0), Vector2(0.8, 0.0), Vector2(0.0, 0.3)], 8, JAUNE)
			k.tube(Vector3(0, 1.85, 0), Vector3(0, 2.6, 0), 0.03, 0.03, 5, METAL)
			for i in 5:
				k.box(Vector3(0.45, 0.3 + i * 0.32, 0.3), Vector3(0.3, 0.04, 0.06), BLANC, 0.0, false)
		# --- Les petits ---------------------------------------------------------------------
		"pk_maquillage":
			k.box(Vector3(0, 0.4, -0.3), Vector3(1.0, 0.8, 0.5), BLANC)
			for i in 6:
				k.box(Vector3(-0.35 + i * 0.14, 0.82, -0.3), Vector3(0.1, 0.04, 0.1), VIFS[i], 0.0, false)
			k.box(Vector3(0, 1.4, -0.5), Vector3(0.6, 0.8, 0.04), Color("cfe8ef"), 0.0, false)
			k.box(Vector3(0, 0.25, 0.5), Vector3(0.4, 0.5, 0.4), ROSE)
			k.lathe(Vector3(0, 2.0, -0.2), [Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(0.0, 0.35)], 8, ROSE)
			k.tube(Vector3(0.55, 0, -0.2), Vector3(0, 2.0, -0.2), 0.03, 0.03, 5, GRIS)
		"pk_petit_train":
			k.box(Vector3(0, 0.45, 0.9), Vector3(0.7, 0.6, 1.0), ROUGE)
			k.tube(Vector3(0, 0.75, 1.1), Vector3(0, 1.15, 1.1), 0.12, 0.1, 8, NOIR)
			k.box(Vector3(0, 1.0, 0.55), Vector3(0.7, 0.5, 0.4), ROUGE.darkened(0.2))
			k.box(Vector3(0, 1.28, 0.55), Vector3(0.8, 0.06, 0.5), JAUNE)
			for i in 2:
				var z := -0.3 - i * 1.0
				k.box(Vector3(0, 0.4, z), Vector3(0.7, 0.4, 0.8), [BLEU, VERT][i])
				k.box(Vector3(0, 0.62, z), Vector3(0.6, 0.06, 0.7), JAUNE, 0.0, false)
			for z in [1.1, 0.6, -0.1, -0.6, -1.1, -1.6]:
				_roue(k, Vector3(-0.38, 0.15, z), 0.15)
				_roue(k, Vector3(0.38, 0.15, z), 0.15)
			k.beam(Vector3(-0.45, 0.01, -2.2), Vector3(-0.45, 0.01, 1.6), 0.05, 0.03, GRIS)
			k.beam(Vector3(0.45, 0.01, -2.2), Vector3(0.45, 0.01, 1.6), 0.05, 0.03, GRIS)
		# --- Restauration ------------------------------------------------------------------
		"pk_friterie":
			k.box(Vector3(0, 0.55, 0), Vector3(2.0, 1.1, 1.2), Color("ffb703"))
			k.box(Vector3(0, 1.12, 0.1), Vector3(2.1, 0.05, 1.3), Color("f2e8cf"))
			k.box(Vector3(0, 2.2, 0), Vector3(2.2, 0.12, 1.4), ROUGE)
			for sx in [-1.0, 1.0]:
				k.box(Vector3(sx, 1.65, -0.5), Vector3(0.08, 1.1, 0.08), BOIS)
			# Le cornet de frites géant sur le toit (en résine).
			k.lathe(Vector3(0, 2.26, 0), [Vector2(0.0, 0.0), Vector2(0.25, 0.0), Vector2(0.45, 0.8), Vector2(0.0, 0.8)], 8, ROUGE)
			for i in 7:
				var a := i * TAU / 7.0
				k.box(Vector3(cos(a) * 0.22, 3.2, sin(a) * 0.22), Vector3(0.1, 0.45, 0.1), JAUNE, 0.0, false)
		"pk_table_pique":
			k.box(Vector3(0, 0.72, 0), Vector3(1.8, 0.06, 0.8), BOIS)
			for sz in [-0.75, 0.75]:
				k.box(Vector3(0, 0.42, sz), Vector3(1.8, 0.05, 0.3), BOIS.darkened(0.1))
			for sx in [-0.7, 0.7]:
				k.beam(Vector3(sx, 0, -0.8), Vector3(sx, 0.72, 0), 0.06, 0.06, BOIS.darkened(0.2))
				k.beam(Vector3(sx, 0, 0.8), Vector3(sx, 0.72, 0), 0.06, 0.06, BOIS.darkened(0.2))
		"pk_barbe_papa":
			k.box(Vector3(0, 0.5, 0), Vector3(1.2, 1.0, 0.7), ROSE)
			k.lathe(Vector3(0, 1.0, 0), [Vector2(0.0, 0.0), Vector2(0.35, 0.0), Vector2(0.35, 0.25), Vector2(0.0, 0.25)], 10, METAL)
			for i in 4:
				k.blob(Vector3(-0.4 + i * 0.27, 1.65, -0.25), Vector3(0.12, 0.16, 0.12), [ROSE, CIEL, BLANC, ROSE][i], [ROSE, CIEL, BLANC, ROSE][i], 0.15, 0)
				k.beam(Vector3(-0.4 + i * 0.27, 1.5, -0.25), Vector3(-0.4 + i * 0.27, 1.05, -0.25), 0.02, 0.02, BLANC)
			for i in 3:
				k.blob(Vector3(0.45, 1.15 + i * 0.12, 0.2 - i * 0.1), Vector3(0.08, 0.08, 0.08), ROUGE, ROUGE, 0.0, 0)
			k.lathe(Vector3(0, 2.1, 0), [Vector2(0.0, 0.0), Vector2(0.9, 0.0), Vector2(0.0, 0.3)], 8, BLANC)
			k.tube(Vector3(0.5, 1.0, -0.2), Vector3(0, 2.1, 0), 0.03, 0.03, 5, GRIS)
		"pk_food_truck":
			k.box(Vector3(0, 1.1, 0), Vector3(2.0, 1.6, 4.0), Color("2a9d8f"))
			k.box(Vector3(0, 1.95, 0), Vector3(2.05, 0.1, 4.05), BLANC)
			k.box(Vector3(1.01, 1.3, -0.3), Vector3(0.02, 0.8, 2.2), NOIR, 0.0, false)
			k.box(Vector3(1.3, 1.75, -0.3), Vector3(0.6, 0.05, 2.4), ORANGE)
			k.box(Vector3(1.05, 0.85, -0.3), Vector3(0.12, 0.05, 2.2), BLANC, 0.0, false)
			k.layer = "verre"
			k.box(Vector3(0, 1.4, 1.95), Vector3(1.8, 0.6, 0.05), Color(0.55, 0.7, 0.82, 0.75), 0.0, false)
			k.layer = "base"
			for sz in [-1.3, 1.3]:
				for sx in [-0.95, 0.95]:
					_roue(k, Vector3(sx, 0.32, sz), 0.32)
		# --- Spectacles ---------------------------------------------------------------------
		"pk_gradins":
			for j in 2:
				var z := -0.2 + j * 0.9
				k.box(Vector3(0, 0.25 + j * 0.4, z), Vector3(4.4 - j * 1.2, 0.5 + j * 0.8, 0.85), Color("adb5bd").darkened(0.1 * j))
				k.box(Vector3(0, 0.52 + j * 0.8, z), Vector3(4.4 - j * 1.2, 0.05, 0.6), BLEU if j == 0 else ROUGE, 0.0, false)
		"pk_projecteurs":
			k.tube(Vector3.ZERO, Vector3(0, 3.2, 0), 0.06, 0.06, 6, NOIR)
			k.beam(Vector3(-0.5, 3.2, 0), Vector3(0.5, 3.2, 0), 0.06, 0.06, NOIR)
			for sx in [-0.4, 0.4]:
				k.tube(Vector3(sx, 3.05, 0), Vector3(sx, 2.85, 0.35), 0.14, 0.12, 8, NOIR)
				k.layer = "lumiere"
				k.lathe(Vector3(sx, 2.84, 0.36), [Vector2(0.0, 0.0), Vector2(0.11, 0.0), Vector2(0.0, 0.02)], 8, Color("fff3c4"))
				k.layer = "base"
		"pk_fumee":
			k.box(Vector3(0, 0.2, 0), Vector3(0.6, 0.4, 0.4), NOIR)
			k.tube(Vector3(0, 0.25, 0.2), Vector3(0, 0.3, 0.4), 0.06, 0.06, 6, GRIS)
			k.layer = "verre"
			k.blob(Vector3(0, 0.45, 0.9), Vector3(0.6, 0.3, 0.5), Color(0.9, 0.9, 0.95, 0.4), Color(0.9, 0.9, 0.95, 0.4), 0.2, 0)
			k.layer = "base"
		"pk_confettis":
			k.box(Vector3(0, 0.15, 0), Vector3(0.5, 0.3, 0.5), NOIR)
			k.tube(Vector3(0, 0.3, 0), Vector3(0, 1.3, 0.3), 0.12, 0.14, 8, Color("d4af37"))
			for i in 8:
				var a := i * TAU / 8.0
				k.box(Vector3(cos(a) * 0.3, 1.55 + 0.2 * sin(i * 2.3), 0.35 + sin(a) * 0.3), Vector3(0.06, 0.06, 0.01), VIFS[i], 0.0, false)
		# --- Atelier ------------------------------------------------------------------------
		"pk_chariot_proprete":
			k.box(Vector3(0, 0.5, 0), Vector3(0.5, 0.5, 0.8), JAUNE)
			k.lathe(Vector3(0, 0.75, -0.2), [Vector2(0.0, 0.0), Vector2(0.2, 0.0), Vector2(0.22, 0.4), Vector2(0.0, 0.4)], 8, VERT)
			k.tube(Vector3(0.15, 0.75, 0.25), Vector3(0.2, 1.5, 0.3), 0.02, 0.02, 4, BOIS)
			k.box(Vector3(0.2, 1.52, 0.3), Vector3(0.3, 0.05, 0.08), ROUGE, 0.0, false)
			for sz in [-0.3, 0.3]:
				_roue(k, Vector3(-0.27, 0.12, sz), 0.12)
				_roue(k, Vector3(0.27, 0.12, sz), 0.12)
		"pk_nacelle":
			k.box(Vector3(0, 0.35, 0), Vector3(1.0, 0.5, 2.0), ORANGE)
			for sz in [-0.7, 0.7]:
				_roue(k, Vector3(-0.5, 0.2, sz), 0.2)
				_roue(k, Vector3(0.5, 0.2, sz), 0.2)
			for i in 3:
				var y := 0.7 + i * 0.6
				k.beam(Vector3(-0.4, y, -0.6), Vector3(-0.4, y + 0.6, 0.6), 0.06, 0.06, GRIS)
				k.beam(Vector3(-0.4, y, 0.6), Vector3(-0.4, y + 0.6, -0.6), 0.06, 0.06, GRIS)
				k.beam(Vector3(0.4, y, -0.6), Vector3(0.4, y + 0.6, 0.6), 0.06, 0.06, GRIS)
				k.beam(Vector3(0.4, y, 0.6), Vector3(0.4, y + 0.6, -0.6), 0.06, 0.06, GRIS)
			k.box(Vector3(0, 2.6, 0), Vector3(1.1, 0.08, 1.4), ORANGE)
			for sx in [-0.5, 0.5]:
				k.box(Vector3(sx, 3.0, 0), Vector3(0.04, 0.8, 1.4), JAUNE, 0.0, false)
		"pk_balayeuse":
			k.box(Vector3(0, 0.6, 0), Vector3(1.0, 0.8, 1.6), Color("f8f9fa"))
			k.box(Vector3(0, 1.2, -0.3), Vector3(0.9, 0.5, 0.6), VERT)
			k.layer = "verre"
			k.box(Vector3(0, 1.3, 0.2), Vector3(0.85, 0.45, 0.5), Color(0.55, 0.7, 0.82, 0.7), 0.0, false)
			k.layer = "base"
			for sx in [-0.45, 0.45]:
				_roue(k, Vector3(sx, 0.25, -0.5), 0.25)
			k.lathe(Vector3(-0.35, 0.1, 0.75), [Vector2(0.0, 0.0), Vector2(0.25, 0.0), Vector2(0.25, 0.12), Vector2(0.0, 0.12)], 10, ORANGE)
			k.lathe(Vector3(0.35, 0.1, 0.75), [Vector2(0.0, 0.0), Vector2(0.25, 0.0), Vector2(0.25, 0.12), Vector2(0.0, 0.12)], 10, ORANGE)
		# --- Parking ------------------------------------------------------------------------
		"pk_borne_parking":
			k.box(Vector3(0, 0.6, 0), Vector3(0.5, 1.2, 0.45), Color("1d3557"))
			k.box(Vector3(0, 0.95, 0.23), Vector3(0.3, 0.2, 0.02), JAUNE, 0.0, false)
			k.beam(Vector3(0.25, 0.95, 0), Vector3(0.25, 0.95, 3.0), 0.08, 0.08, BLANC)
			for i in 5:
				k.box(Vector3(0.25, 0.95, 0.4 + i * 0.6), Vector3(0.09, 0.09, 0.25), ROUGE, 0.0, false)
		"pk_ombriere":
			for sz in [-1.6, 1.6]:
				k.tube(Vector3(0, 0, sz), Vector3(0, 2.6, sz), 0.08, 0.08, 6, METAL)
			k.box(Vector3(0, 2.7, 0), Vector3(5.0, 0.1, 4.0), Color("1d3557"))
			for i in 8:
				k.box(Vector3(-2.2 + i * 0.63, 2.76, 0), Vector3(0.58, 0.02, 3.8), Color("33415c"), 0.0, false)
		"pk_autocar":
			k.box(Vector3(0, 1.45, 0), Vector3(2.4, 2.5, 10.0), BLANC)
			k.box(Vector3(0, 1.0, 0), Vector3(2.45, 0.5, 10.05), ORANGE, 0.0, false)
			k.layer = "verre"
			k.box(Vector3(0, 2.0, 0), Vector3(2.46, 0.8, 9.0), Color(0.45, 0.6, 0.72, 0.8), 0.0, false)
			k.box(Vector3(0, 1.8, 4.99), Vector3(2.2, 1.2, 0.05), Color(0.45, 0.6, 0.72, 0.8), 0.0, false)
			k.layer = "base"
			for sz in [-3.4, 3.0]:
				for sx in [-1.15, 1.15]:
					_roue(k, Vector3(sx, 0.45, sz), 0.45)
