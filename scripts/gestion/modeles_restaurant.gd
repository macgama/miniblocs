class_name ModelesRestaurant
extends RefCounted
## Objets low-poly du restaurant (cuisine, salle, bar, cave, pâtisserie,
## terrasse, potager, livraison), mêmes conventions que GestionModeles :
## origine au sol au centre de l'objet, face avant vers +Z, le kit est déjà
## placé (k.xf) par GestionModeles.dessiner().

const INOX := Color("c9ced3")
const INOX_FONCE := Color("8d949b")
const BOIS := Color("8a5a3b")
const BOIS_FONCE := Color("5c4033")
const BOIS_CLAIR := Color("c8a27a")
const NOIR := Color("26262b")
const BLANC := Color("f6f4ef")
const OR := Color("d4af37")
const CUIVRE := Color("b87333")

## Places des clients : modèle → [[x, z, angle, assis]] locaux.
const PLACES := {
	"table_bistrot": [[-0.65, 0.0, PI * 0.5, true], [0.65, 0.0, -PI * 0.5, true]],
	"babyfoot": [[0.0, 0.75, PI, false], [0.0, -0.75, 0.0, false]],
	"tonneau_table": [[-0.7, 0.0, PI * 0.5, true], [0.7, 0.0, -PI * 0.5, true]],
	"vitrine_gateaux": [[-0.5, 1.0, PI, false], [0.5, 1.0, PI, false]],
	"comptoir_glaces": [[0.0, 0.9, PI, false]],
	"theieres": [[0.0, 0.9, PI, false]],
	"vitrine_fromages": [],
}


static func dessiner(k: LpKit, nom: String, teinte := Color.WHITE) -> void:
	match nom:
		# --- Accueil -------------------------------------------------------------------
		"ardoise":
			for sx in [-0.3, 0.3]:
				k.beam(Vector3(sx, 0, -0.25), Vector3(sx * 0.8, 1.2, 0.0), 0.06, 0.06, BOIS)
				k.beam(Vector3(sx, 0, 0.25), Vector3(sx * 0.8, 1.2, 0.0), 0.06, 0.06, BOIS)
			k.box(Vector3(0, 0.75, 0.12), Vector3(0.6, 0.8, 0.04), Color("2b2d2f"))
			for i in 4:
				k.box(Vector3(-0.05 + (i % 2) * 0.08, 0.98 - i * 0.14, 0.145), Vector3(0.36 - (i % 2) * 0.1, 0.03, 0.01), BLANC, 0.0, false)
		"porte_manteaux":
			k.tube(Vector3.ZERO, Vector3(0, 1.8, 0), 0.04, 0.035, 6, BOIS_FONCE)
			k.lathe(Vector3.ZERO, [Vector2(0.0, 0.0), Vector2(0.3, 0.0), Vector2(0.25, 0.05), Vector2(0.0, 0.06)], 8, BOIS_FONCE)
			var cols := [Color("1d3557"), Color("9c4f3a"), Color("6a994e"), Color("e9c46a")]
			for i in 4:
				var a := TAU * i / 4.0 + 0.4
				k.box(Vector3(cos(a) * 0.18, 1.35, sin(a) * 0.18), Vector3(0.26, 0.6, 0.18), cols[i])
		"tablette_resa":
			k.box(Vector3(0, 0.55, 0), Vector3(0.9, 1.1, 0.45), BOIS_FONCE)
			k.box(Vector3(0, 1.12, 0), Vector3(1.0, 0.05, 0.55), Color("3d2b20"))
			k.box(Vector3(-0.15, 1.16, 0.05), Vector3(0.36, 0.03, 0.26), NOIR)
			k.layer = "lumiere"
			k.box(Vector3(-0.15, 1.18, 0.05), Vector3(0.32, 0.01, 0.22), Color("8ecae6"), 0.0, false)
			k.layer = "base"
			k.box(Vector3(0.28, 1.18, 0.04), Vector3(0.3, 0.06, 0.22), Color("9b2226"))
		# --- Salle ---------------------------------------------------------------------
		"bouquet_table":
			k.lathe(Vector3(0, 0.77, 0), [Vector2(0.0, 0.0), Vector2(0.06, 0.0), Vector2(0.05, 0.16), Vector2(0.0, 0.16)], 8, Color("a8dadc"))
			k.blob(Vector3(0, 1.0, 0), Vector3(0.12, 0.1, 0.12), Color("2f6b35"), [Color("ef476f"), Color("f4d35e"), Color("ffffff")][int(absf(k.xf.origin.x * 3.0)) % 3], 0.25, 0)
		"table_bistrot":
			k.lathe(Vector3.ZERO, [Vector2(0.0, 0.0), Vector2(0.25, 0.0), Vector2(0.05, 0.05), Vector2(0.04, 0.72), Vector2(0.38, 0.73), Vector2(0.38, 0.77), Vector2(0.0, 0.77)], 12, Color("3d3a36"))
			k.lathe(Vector3(0, 0.73, 0), [Vector2(0.0, 0.0), Vector2(0.37, 0.0), Vector2(0.37, 0.04), Vector2(0.0, 0.04)], 12, Color("e9e4da"))
			for sx in [-0.65, 0.65]:
				k.lathe(Vector3(sx, 0, 0), [Vector2(0.0, 0.0), Vector2(0.18, 0.0), Vector2(0.03, 0.04), Vector2(0.03, 0.44), Vector2(0.2, 0.45), Vector2(0.2, 0.48), Vector2(0.0, 0.48)], 8, Color("9c4f3a"))
				k.box(Vector3(sx * 1.25, 0.72, 0), Vector3(0.05, 0.5, 0.38), Color("9c4f3a"), 0.0, false)
		# --- Cuisine -------------------------------------------------------------------
		"friteuse":
			k.box(Vector3(0, 0.45, 0), Vector3(0.8, 0.9, 0.7), INOX)
			k.box(Vector3(0, 0.91, 0.05), Vector3(0.7, 0.03, 0.5), Color("e9c46a"), 0.0, false)
			for sx in [-0.17, 0.17]:
				k.box(Vector3(sx, 1.0, 0.05), Vector3(0.28, 0.12, 0.38), Color("adb5bd"), 0.0, false)
				k.box(Vector3(sx, 1.0, 0.38), Vector3(0.04, 0.04, 0.3), NOIR, 0.0, false)
		"robot":
			k.box(Vector3(0, 0.45, 0), Vector3(0.7, 0.9, 0.6), INOX_FONCE)
			k.box(Vector3(0, 1.0, -0.1), Vector3(0.22, 0.2, 0.3), Color("e63946"))
			k.box(Vector3(0, 1.28, -0.02), Vector3(0.2, 0.36, 0.2), Color("e63946"))
			k.box(Vector3(0, 1.4, 0.15), Vector3(0.24, 0.14, 0.34), Color("e63946"))
			k.lathe(Vector3(0, 0.92, 0.12), [Vector2(0.0, 0.0), Vector2(0.1, 0.0), Vector2(0.15, 0.2), Vector2(0.0, 0.2)], 10, INOX, true, false)
		"trancheuse":
			k.box(Vector3(0, 0.45, 0), Vector3(0.7, 0.9, 0.6), INOX_FONCE)
			k.box(Vector3(0, 0.95, 0), Vector3(0.5, 0.1, 0.4), Color("e63946"))
			k.lathe(Vector3(0, 1.0, 0.0), [Vector2(0.0, 0.0), Vector2(0.18, 0.0), Vector2(0.18, 0.02), Vector2(0.0, 0.02)], 12, INOX)
			k.box(Vector3(0.18, 1.08, 0.05), Vector3(0.28, 0.12, 0.14), Color("bc4749"))
		"lave_vaisselle":
			k.box(Vector3(0, 0.45, 0), Vector3(0.75, 0.9, 0.7), INOX)
			k.box(Vector3(0, 1.3, 0), Vector3(0.72, 0.8, 0.68), INOX)
			k.box(Vector3(0, 1.75, 0.3), Vector3(0.5, 0.05, 0.1), NOIR, 0.0, false)
			k.layer = "lumiere"
			k.box(Vector3(0.25, 0.8, 0.36), Vector3(0.08, 0.04, 0.01), Color("57cc99"), 0.0, false)
			k.layer = "base"
		"four_mixte":
			k.box(Vector3(0, 0.3, 0), Vector3(0.9, 0.6, 0.8), INOX_FONCE)
			k.box(Vector3(0, 1.1, 0), Vector3(0.95, 1.0, 0.85), INOX)
			k.box(Vector3(-0.08, 1.1, 0.43), Vector3(0.65, 0.75, 0.02), NOIR)
			k.layer = "lumiere"
			k.box(Vector3(-0.08, 1.1, 0.445), Vector3(0.55, 0.6, 0.01), Color("ffb347"), 0.0, false)
			k.box(Vector3(0.36, 1.3, 0.44), Vector3(0.12, 0.2, 0.01), Color("7cc7ff"), 0.0, false)
			k.layer = "base"
		"plancha":
			k.box(Vector3(0, 0.45, 0), Vector3(1.2, 0.9, 0.75), INOX)
			k.box(Vector3(0, 0.93, 0), Vector3(1.1, 0.05, 0.65), Color("3d3a36"), 0.0, false)
			for i in 4:
				k.box(Vector3(-0.35 + i * 0.22, 0.97, -0.05 + (i % 2) * 0.15), Vector3(0.14, 0.03, 0.1), [Color("bc6c25"), Color("90be6d"), Color("e76f51"), Color("f4d35e")][i], 0.0, false)
		"rotissoire":
			k.box(Vector3(0, 0.45, 0), Vector3(1.1, 0.9, 0.6), INOX_FONCE)
			k.box(Vector3(0, 1.4, 0), Vector3(1.1, 1.0, 0.6), INOX)
			k.layer = "lumiere"
			k.box(Vector3(0, 1.4, 0.31), Vector3(0.95, 0.85, 0.01), Color("ff9f1c"), 0.0, false)
			k.layer = "base"
			for j in 3:
				for i in 3:
					k.blob(Vector3(-0.3 + i * 0.3, 1.15 + j * 0.27, 0.32), Vector3(0.11, 0.08, 0.06), Color("9c6644"), Color("d68c45"), 0.1, 0)
		"machine_pates":
			k.box(Vector3(0, 0.45, 0), Vector3(0.9, 0.9, 0.6), BOIS)
			k.box(Vector3(0, 0.92, 0), Vector3(0.95, 0.04, 0.65), BOIS_CLAIR, 0.0, false)
			k.box(Vector3(-0.2, 1.05, 0), Vector3(0.28, 0.22, 0.24), INOX)
			k.tube(Vector3(-0.06, 1.1, 0.0), Vector3(0.08, 1.1, 0.12), 0.02, 0.02, 4, NOIR)
			for i in 6:
				k.box(Vector3(0.12 + i * 0.05, 0.96, 0.0), Vector3(0.02, 0.02, 0.5), Color("f4e285"), 0.0, false)
		"armoire_froide":
			k.box(Vector3(0, 1.0, 0), Vector3(0.8, 2.0, 0.7), INOX)
			k.box(Vector3(0, 1.0, 0.36), Vector3(0.7, 1.85, 0.02), INOX.lightened(0.1), 0.0, false)
			k.box(Vector3(0.3, 1.1, 0.39), Vector3(0.04, 0.5, 0.04), NOIR, 0.0, false)
			k.layer = "lumiere"
			k.box(Vector3(0, 1.9, 0.38), Vector3(0.2, 0.06, 0.01), Color("7cc7ff"), 0.0, false)
			k.layer = "base"
		"piano_cuisson":
			# Grand fourneau du chef : cuivre, laiton et six feux.
			k.box(Vector3(0, 0.45, 0), Vector3(3.0, 0.9, 0.9), Color("1d3557"))
			k.box(Vector3(0, 0.92, 0), Vector3(3.1, 0.06, 1.0), INOX)
			k.box(Vector3(0, 0.45, 0.46), Vector3(2.8, 0.06, 0.04), OR, 0.0, false)
			for i in 3:
				k.box(Vector3(-1.0 + i * 1.0, 0.5, 0.47), Vector3(0.7, 0.5, 0.02), NOIR, 0.0, false)
				k.box(Vector3(-1.0 + i * 1.0, 0.7, 0.5), Vector3(0.5, 0.04, 0.04), OR, 0.0, false)
			for i in 6:
				k.lathe(Vector3(-1.2 + i * 0.48, 0.96, 0.0), [Vector2(0.0, 0.0), Vector2(0.14, 0.0), Vector2(0.14, 0.02), Vector2(0.0, 0.02)], 8, NOIR)
			for i in 3:
				k.lathe(Vector3(-0.96 + i * 0.96, 0.98, 0.0), [Vector2(0.0, 0.0), Vector2(0.16, 0.0), Vector2(0.17, 0.2), Vector2(0.0, 0.2)], 10, CUIVRE, true, false)
		# --- Plonge et réserve ---------------------------------------------------------
		"bac_plonge":
			k.box(Vector3(0, 0.45, 0), Vector3(1.8, 0.9, 0.7), INOX_FONCE)
			k.box(Vector3(0, 0.92, 0), Vector3(1.85, 0.04, 0.75), INOX, 0.0, false)
			k.layer = "eau"
			for sx in [-0.45, 0.45]:
				k.box(Vector3(sx, 0.9, 0.02), Vector3(0.7, 0.02, 0.5), Color(0.6, 0.8, 0.9, 0.7), 0.0, false)
			k.layer = "base"
			k.tube(Vector3(0, 0.94, -0.3), Vector3(0, 1.5, -0.25), 0.03, 0.03, 6, INOX)
			k.tube(Vector3(0, 1.5, -0.25), Vector3(0, 1.45, 0.1), 0.03, 0.03, 6, INOX)
			for i in 5:
				k.lathe(Vector3(0.75, 0.94 + i * 0.04, 0.0), [Vector2(0.0, 0.0), Vector2(0.15, 0.0), Vector2(0.16, 0.03), Vector2(0.0, 0.03)], 8, BLANC)
		"etagere_inox":
			for j in 4:
				k.box(Vector3(0, 0.3 + j * 0.45, 0), Vector3(1.6, 0.04, 0.45), INOX, 0.0, false)
				for i in 7:
					k.lathe(Vector3(-0.66 + i * 0.22, 0.32 + j * 0.45, 0.0), [Vector2(0.0, 0.0), Vector2(0.09, 0.0), Vector2(0.1, 0.03), Vector2(0.0, 0.03)] if j % 2 == 0 else [Vector2(0.0, 0.0), Vector2(0.05, 0.0), Vector2(0.06, 0.16), Vector2(0.0, 0.16)], 6, BLANC if j % 2 == 0 else Color("dff3f8"))
			for sx in [-0.78, 0.78]:
				for sz in [-0.2, 0.2]:
					k.box(Vector3(sx, 0.95, sz), Vector3(0.03, 1.9, 0.03), INOX_FONCE, 0.0, false)
		"poubelles_tri":
			var cols := [Color("f4d35e"), Color("2a9d8f"), Color("6c757d")]
			for i in 3:
				k.box(Vector3(-0.5 + i * 0.5, 0.45, 0), Vector3(0.44, 0.9, 0.5), cols[i])
				k.box(Vector3(-0.5 + i * 0.5, 0.92, 0), Vector3(0.46, 0.05, 0.52), cols[i].darkened(0.25), 0.0, false)
		"chambre_froide":
			k.box(Vector3(0, 1.2, 0), Vector3(2.4, 2.4, 2.4), Color("e9ecef"))
			k.box(Vector3(0.3, 1.0, 1.21), Vector3(1.0, 2.0, 0.04), Color("dee2e6"), 0.0, false)
			k.box(Vector3(0.7, 1.0, 1.25), Vector3(0.08, 0.4, 0.06), INOX_FONCE, 0.0, false)
			k.box(Vector3(0, 2.42, 0), Vector3(2.0, 0.05, 2.0), INOX, 0.0, false)
			k.box(Vector3(-0.6, 2.6, -0.6), Vector3(0.8, 0.35, 0.5), INOX_FONCE)
			k.layer = "lumiere"
			k.box(Vector3(-0.5, 1.9, 1.22), Vector3(0.3, 0.12, 0.01), Color("7cc7ff"), 0.0, false)
			k.layer = "base"
		"sacs":
			for i in 4:
				var p := Vector3(-0.45 + (i % 2) * 0.9, 0.22 + (i / 2) * 0.42, 0.0 + (i / 2) * 0.05)
				k.blob(p, Vector3(0.42, 0.22, 0.3), Color("d8c8a8"), Color("efe3c8"), 0.1, 0)
		"vitrine_fromages":
			k.box(Vector3(0, 0.45, 0), Vector3(1.2, 0.9, 0.6), BOIS)
			k.layer = "verre"
			k.box(Vector3(0, 1.2, 0), Vector3(1.15, 0.6, 0.55), Color(0.75, 0.88, 0.95, 0.35), 0.0, false)
			k.layer = "base"
			for i in 4:
				k.lathe(Vector3(-0.4 + i * 0.27, 0.92, 0), [Vector2(0.0, 0.0), Vector2(0.12, 0.0), Vector2(0.12, 0.1), Vector2(0.0, 0.1)], 10, [Color("f4d35e"), Color("ffe8a3"), Color("e9c46a"), Color("fff3b0")][i])
		# --- Bar -----------------------------------------------------------------------
		"tireuse":
			k.box(Vector3(0, 1.18, 0), Vector3(0.7, 0.14, 0.18), INOX)
			for i in 3:
				k.box(Vector3(-0.22 + i * 0.22, 1.42, 0.0), Vector3(0.05, 0.36, 0.05), OR, 0.0, false)
				k.box(Vector3(-0.22 + i * 0.22, 1.62, 0.0), Vector3(0.08, 0.1, 0.06), [Color("e63946"), Color("f4d35e"), Color("1d3557")][i], 0.0, false)
		"expresso":
			k.box(Vector3(0, 1.3, -0.05), Vector3(0.6, 0.42, 0.42), Color("9b2226"))
			k.box(Vector3(0, 1.53, -0.05), Vector3(0.62, 0.04, 0.44), INOX, 0.0, false)
			for sx in [-0.15, 0.15]:
				k.box(Vector3(sx, 1.2, 0.18), Vector3(0.08, 0.06, 0.12), INOX_FONCE, 0.0, false)
			for i in 4:
				k.lathe(Vector3(-0.2 + i * 0.13, 1.55, -0.05), [Vector2(0.0, 0.0), Vector2(0.04, 0.0), Vector2(0.045, 0.05), Vector2(0.0, 0.05)], 6, BLANC)
		"tele_pied":
			k.lathe(Vector3.ZERO, [Vector2(0.0, 0.0), Vector2(0.3, 0.0), Vector2(0.25, 0.05), Vector2(0.0, 0.06)], 8, NOIR)
			k.tube(Vector3.ZERO, Vector3(0, 1.5, 0), 0.04, 0.04, 6, NOIR)
			k.box(Vector3(0, 1.75, 0.05), Vector3(1.2, 0.72, 0.06), NOIR)
			k.layer = "lumiere"
			k.box(Vector3(0, 1.75, 0.09), Vector3(1.1, 0.62, 0.01), Color("52b788"), 0.0, false)
			k.box(Vector3(0, 1.75, 0.1), Vector3(0.02, 0.6, 0.005), BLANC, 0.0, false)
			k.layer = "base"
		"babyfoot":
			k.box(Vector3(0, 0.78, 0), Vector3(1.3, 0.25, 0.75), BOIS)
			k.box(Vector3(0, 0.9, 0), Vector3(1.2, 0.02, 0.65), Color("2d6a4f"), 0.0, false)
			for sx in [-0.55, 0.55]:
				for sz in [-0.3, 0.3]:
					k.box(Vector3(sx, 0.35, sz), Vector3(0.08, 0.7, 0.08), BOIS_FONCE, 0.0, false)
			for i in 8:
				var x := -0.52 + i * 0.15
				k.tube(Vector3(x, 0.95, -0.55), Vector3(x, 0.95, 0.55), 0.012, 0.012, 4, INOX)
				k.box(Vector3(x, 0.93, 0.0), Vector3(0.04, 0.1, 0.04), Color("e63946") if i % 2 == 0 else Color("1d3557"), 0.0, false)
		# --- Toilettes -----------------------------------------------------------------
		"seche_mains":
			k.box(Vector3(0, 1.25, 0.1), Vector3(0.3, 0.32, 0.2), BLANC)
			k.box(Vector3(0, 1.1, 0.17), Vector3(0.12, 0.04, 0.06), INOX_FONCE, 0.0, false)
		"table_langer":
			k.box(Vector3(0, 0.45, 0), Vector3(0.8, 0.9, 0.5), BLANC)
			k.box(Vector3(0, 0.95, 0), Vector3(0.75, 0.1, 0.45), Color("a8dadc"))
			k.blob(Vector3(0.2, 1.06, 0.0), Vector3(0.1, 0.06, 0.08), Color("ffd6a5"), Color("ffafcc"), 0.1, 0)
		"bouquet":
			k.box(Vector3(0, 0.45, 0), Vector3(0.4, 0.9, 0.4), Color("e9e4da"))
			k.lathe(Vector3(0, 0.9, 0), [Vector2(0.0, 0.0), Vector2(0.08, 0.0), Vector2(0.07, 0.25), Vector2(0.0, 0.25)], 8, Color("a8dadc"))
			k.blob(Vector3(0, 1.25, 0), Vector3(0.2, 0.16, 0.2), Color("2f6b35"), Color("ffafcc"), 0.25, 0)
		"vasques":
			k.box(Vector3(0, 0.42, 0), Vector3(2.4, 0.84, 0.6), Color("efe7da"))
			k.box(Vector3(0, 0.86, 0), Vector3(2.5, 0.05, 0.65), Color("f8f9fa"), 0.0, false)
			for sx in [-0.7, 0.0, 0.7]:
				k.lathe(Vector3(sx, 0.88, 0.05), [Vector2(0.0, 0.0), Vector2(0.18, 0.0), Vector2(0.22, 0.12), Vector2(0.0, 0.12)], 10, BLANC, true, false)
				k.tube(Vector3(sx, 0.9, -0.2), Vector3(sx, 1.12, -0.1), 0.02, 0.02, 4, OR)
			k.box(Vector3(0, 1.6, -0.27), Vector3(2.3, 0.8, 0.03), Color("cfe8ef"))
			k.box(Vector3(0, 1.6, -0.285), Vector3(2.4, 0.9, 0.02), OR, 0.0, false)
		# --- Salon privé ----------------------------------------------------------------
		"piece_montee":
			for i in 4:
				k.lathe(Vector3(0, 0.78 + i * 0.12, 0), [Vector2(0.0, 0.0), Vector2(0.24 - i * 0.05, 0.0), Vector2(0.24 - i * 0.05, 0.12), Vector2(0.0, 0.12)], 10, Color("f4d6a0") if i % 2 == 0 else Color("e8b86d"))
			k.box(Vector3(0, 1.3, 0), Vector3(0.06, 0.1, 0.03), BLANC, 0.0, false)
			for i in 3:
				k.tube(Vector3(0.4 + i * 0.12, 0.78, 0.15), Vector3(0.4 + i * 0.12, 1.08, 0.15), 0.03, 0.025, 6, Color("2d6a4f"))
		"estrade":
			k.box(Vector3(0, 0.15, 0), Vector3(1.6, 0.3, 1.1), BOIS_FONCE)
			k.box(Vector3(0, 0.31, 0), Vector3(1.5, 0.02, 1.0), Color("9b2226"), 0.0, false)
			k.tube(Vector3(-0.3, 0.3, 0.2), Vector3(-0.3, 1.5, 0.25), 0.015, 0.015, 4, NOIR)
			k.blob(Vector3(-0.3, 1.52, 0.26), Vector3(0.05, 0.06, 0.05), NOIR, Color("6c757d"), 0.05, 0)
			k.box(Vector3(0.35, 0.75, -0.2), Vector3(0.55, 0.8, 0.2), NOIR)
			k.box(Vector3(0.35, 0.75, -0.09), Vector3(0.46, 0.06, 0.02), BLANC, 0.0, false)
			k.lathe(Vector3(0.45, 0.3, 0.25), [Vector2(0.0, 0.0), Vector2(0.18, 0.0), Vector2(0.18, 0.22), Vector2(0.0, 0.22)], 10, Color("e63946"))
		"ecran_pied":
			for sx in [-0.6, 0.6]:
				k.tube(Vector3(sx, 0, 0), Vector3(sx, 1.9, 0), 0.025, 0.025, 4, NOIR)
			k.box(Vector3(0, 1.5, 0.03), Vector3(1.6, 0.95, 0.04), BLANC)
			k.layer = "lumiere"
			k.box(Vector3(0, 1.5, 0.06), Vector3(1.5, 0.85, 0.01), Color("bde0fe"), 0.0, false)
			k.layer = "base"
			k.box(Vector3(-0.3, 1.65, 0.07), Vector3(0.6, 0.25, 0.01), Color("ffd166"), 0.0, false)
		# --- Cave ----------------------------------------------------------------------
		"tonneaux":
			for i in 3:
				var p := Vector3(-0.55 + i * 0.55, 0.32, 0.0) if i < 2 else Vector3(-0.27, 0.86, 0.0)
				if i == 2:
					p = Vector3(0.0, 0.86, 0.0)
				var sauve := k.xf
				k.xf = sauve * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), p)
				k.lathe(Vector3(0, -0.4, 0), [Vector2(0.24, 0.0), Vector2(0.3, 0.4), Vector2(0.24, 0.8)], 10, Color("8a5a3b"))
				k.lathe(Vector3(0, -0.4, 0), [Vector2(0.0, 0.0), Vector2(0.24, 0.0), Vector2(0.0, 0.0)], 10, BOIS_FONCE)
				k.xf = sauve
			k.box(Vector3(0, 0.03, 0), Vector3(1.4, 0.06, 0.9), BOIS_FONCE, 0.0, false)
		"tonneau_table":
			k.lathe(Vector3.ZERO, [Vector2(0.28, 0.0), Vector2(0.36, 0.5), Vector2(0.28, 1.0), Vector2(0.0, 1.0)], 12, Color("8a5a3b"))
			for y in [0.15, 0.85]:
				k.lathe(Vector3(0, y, 0), [Vector2(0.31, 0.0), Vector2(0.33, 0.04), Vector2(0.31, 0.08)], 12, Color("495057"), false, false)
			k.lathe(Vector3(0, 1.0, 0), [Vector2(0.0, 0.0), Vector2(0.06, 0.0), Vector2(0.05, 0.22), Vector2(0.0, 0.24)], 6, Color("6a040f"))
			for sx in [-0.7, 0.7]:
				k.lathe(Vector3(sx, 0, 0), [Vector2(0.0, 0.0), Vector2(0.18, 0.0), Vector2(0.03, 0.05), Vector2(0.03, 0.66), Vector2(0.2, 0.67), Vector2(0.2, 0.72), Vector2(0.0, 0.72)], 8, BOIS_FONCE)
		# --- Pâtisserie ----------------------------------------------------------------
		"vitrine_gateaux":
			k.box(Vector3(0, 0.45, 0), Vector3(2.0, 0.9, 0.7), Color("f2dfe2"))
			k.box(Vector3(0, 0.46, 0.36), Vector3(1.9, 0.1, 0.02), OR, 0.0, false)
			k.layer = "verre"
			k.box(Vector3(0, 1.18, 0.05), Vector3(1.95, 0.55, 0.6), Color(0.8, 0.9, 0.97, 0.3), 0.0, false)
			k.layer = "base"
			var cols := [Color("6f1d1b"), Color("ffafcc"), Color("f4a261"), Color("fefae0"), Color("90be6d"), Color("e63946")]
			for i in 6:
				k.lathe(Vector3(-0.75 + i * 0.3, 0.92, 0.05), [Vector2(0.0, 0.0), Vector2(0.12, 0.0), Vector2(0.12, 0.1), Vector2(0.0, 0.12)], 8, cols[i])
				k.blob(Vector3(-0.75 + i * 0.3, 1.06, 0.05), Vector3(0.04, 0.03, 0.04), Color("e63946"), Color("ffffff"), 0.1, 0)
		"theieres":
			k.box(Vector3(0, 0.45, 0), Vector3(1.4, 0.9, 0.5), BOIS_CLAIR)
			for i in 4:
				var x := -0.5 + i * 0.33
				k.lathe(Vector3(x, 0.9, 0), [Vector2(0.0, 0.0), Vector2(0.1, 0.0), Vector2(0.12, 0.08), Vector2(0.06, 0.18), Vector2(0.0, 0.2)], 8, [Color("e9ecef"), Color("a8dadc"), Color("ffafcc"), Color("f4d35e")][i])
				k.tube(Vector3(x + 0.1, 1.0, 0.0), Vector3(x + 0.18, 1.06, 0.0), 0.015, 0.01, 4, Color("e9ecef"))
			_etageres_mur(k, 1.4, [Color("bc6c25"), Color("2a9d8f"), Color("e9c46a"), Color("9b2226")])
		"comptoir_glaces":
			k.box(Vector3(0, 0.45, 0), Vector3(1.4, 0.9, 0.7), Color("a8dadc"))
			k.layer = "verre"
			k.box(Vector3(0, 1.05, 0.1), Vector3(1.35, 0.3, 0.5), Color(0.8, 0.92, 0.97, 0.35), 0.0, false)
			k.layer = "base"
			var cols := [Color("fefae0"), Color("ffafcc"), Color("6f1d1b"), Color("90be6d"), Color("f4d35e")]
			for i in 5:
				k.box(Vector3(-0.52 + i * 0.26, 0.93, 0.1), Vector3(0.22, 0.05, 0.4), cols[i], 0.0, false)
			k.lathe(Vector3(0.45, 1.25, 0.0), [Vector2(0.0, 0.0), Vector2(0.04, 0.0), Vector2(0.08, 0.2), Vector2(0.0, 0.22)], 8, Color("e9c46a"))
		"macarons":
			k.lathe(Vector3.ZERO, [Vector2(0.0, 0.0), Vector2(0.2, 0.0), Vector2(0.04, 0.05), Vector2(0.04, 0.8), Vector2(0.0, 0.8)], 8, OR)
			var cols := [Color("ffafcc"), Color("cdb4db"), Color("a8dadc"), Color("f4d35e"), Color("90be6d")]
			for i in 5:
				k.lathe(Vector3(0, 0.82 + i * 0.1, 0), [Vector2(0.0, 0.0), Vector2(0.28 - i * 0.05, 0.0), Vector2(0.27 - i * 0.05, 0.08), Vector2(0.0, 0.08)], 10, cols[i])
		# --- Terrasse ------------------------------------------------------------------
		"jardiniere":
			k.box(Vector3(0, 0.3, 0), Vector3(1.6, 0.6, 0.5), Color("6b4a32"))
			for i in 4:
				k.blob(Vector3(-0.6 + i * 0.4, 0.75, 0), Vector3(0.25, 0.25, 0.22), Color("2f6b35"), [Color("e76f51"), Color("f4d35e"), Color("ef476f"), Color("ffffff")][i], 0.2, 0)
		"brasero":
			k.lathe(Vector3.ZERO, [Vector2(0.0, 0.0), Vector2(0.3, 0.0), Vector2(0.06, 0.08), Vector2(0.06, 2.0), Vector2(0.0, 2.0)], 8, Color("495057"))
			k.lathe(Vector3(0, 2.0, 0), [Vector2(0.0, 0.0), Vector2(0.45, 0.15), Vector2(0.0, 0.2)], 8, INOX)
			k.layer = "lumiere"
			k.lathe(Vector3(0, 1.75, 0), [Vector2(0.0, 0.0), Vector2(0.12, 0.0), Vector2(0.12, 0.2), Vector2(0.0, 0.2)], 8, Color("ff7b00"))
			k.layer = "base"
		"guirlande":
			for sx in [-5.6, 5.6]:
				k.tube(Vector3(sx, 0, 0.1), Vector3(sx, 2.8, 0.1), 0.04, 0.04, 6, NOIR)
				k.tube(Vector3(sx, 0, 6.8), Vector3(sx, 2.8, 6.8), 0.04, 0.04, 6, NOIR)
			k.layer = "lumiere"
			for f in 3:
				var z := 0.1 + f * 3.35
				for i in 16:
					var t := float(i) / 15.0
					var x := lerpf(-5.6, 5.6, t)
					var y := 2.7 - sin(t * PI) * 0.45
					k.box(Vector3(x, y, z), Vector3(0.09, 0.12, 0.09), [Color("ffe066"), Color("ffb4a2"), Color("bde0fe")][i % 3], 0.0, false)
			k.layer = "base"
		"pergola":
			for sx in [-5.5, 5.5]:
				for sz in [-3.2, 3.2]:
					k.box(Vector3(sx, 1.35, sz), Vector3(0.18, 2.7, 0.18), BOIS)
			for sz in [-3.2, 3.2]:
				k.box(Vector3(0, 2.75, sz), Vector3(11.4, 0.16, 0.16), BOIS)
			for i in 12:
				k.box(Vector3(-5.5 + i * 1.0, 2.88, 0), Vector3(0.08, 0.1, 6.8), BOIS_CLAIR, 0.0, false)
			for i in 9:
				k.blob(Vector3(-4.8 + i * 1.2, 3.0, -2.6 + float((i * 5) % 6)), Vector3(0.7, 0.18, 0.6), Color("2d6a4f"), Color("74c69d"), 0.25, 0)
			for i in 4:
				k.blob(Vector3(-4.0 + i * 2.6, 2.75, 0.5), Vector3(0.12, 0.2, 0.12), Color("5a189a"), Color("7b2cbf"), 0.1, 0)
		# --- Potager -------------------------------------------------------------------
		"carre_potager":
			k.box(Vector3(0, 0.2, 0), Vector3(2.4, 0.4, 2.4), BOIS_CLAIR)
			k.box(Vector3(0, 0.38, 0), Vector3(2.2, 0.04, 2.2), Color("5c3d2e"), 0.0, false)
			var cols := [Color("e63946"), Color("f4a261"), Color("90be6d"), Color("ffffff")]
			for i in 3:
				for j in 3:
					var p := Vector3(-0.7 + i * 0.7, 0.55, -0.7 + j * 0.7)
					k.blob(p, Vector3(0.26, 0.2, 0.26), Color("2d6a4f"), Color("52b788"), 0.25, 0)
					if (i + j) % 2 == 0:
						k.blob(p + Vector3(0.08, 0.1, 0.08), Vector3(0.07, 0.07, 0.07), cols[(i * 3 + j) % 4], cols[(i * 3 + j) % 4], 0.05, 0)
		"poulailler":
			k.box(Vector3(0, 0.55, 0), Vector3(1.6, 0.7, 1.2), Color("bc6c25"))
			k.quad(Vector3(-0.9, 0.9, -0.7), Vector3(0.9, 0.9, -0.7), Vector3(0.9, 1.35, 0.0), Vector3(-0.9, 1.35, 0.0), Color("7f5539"))
			k.quad(Vector3(-0.9, 1.35, 0.0), Vector3(0.9, 1.35, 0.0), Vector3(0.9, 0.9, 0.7), Vector3(-0.9, 0.9, 0.7), Color("7f5539"))
			for sx in [-0.7, 0.7]:
				for sz in [-0.5, 0.5]:
					k.box(Vector3(sx, 0.1, sz), Vector3(0.08, 0.2, 0.08), BOIS_FONCE, 0.0, false)
			k.box(Vector3(0, 0.45, 0.61), Vector3(0.3, 0.35, 0.02), NOIR, 0.0, false)
			for i in 3:
				var p := Vector3(-0.6 + i * 0.6, 0.0, 1.1 + (i % 2) * 0.3)
				k.blob(p + Vector3(0, 0.16, 0), Vector3(0.13, 0.12, 0.18), Color("f8f9fa") if i != 1 else Color("9c6644"), Color("ffffff") if i != 1 else Color("bc6c25"), 0.1, 0)
				k.box(p + Vector3(0, 0.3, 0.14), Vector3(0.05, 0.07, 0.05), Color("e63946"), 0.0, false)
		"serre":
			k.box(Vector3(0, 0.15, 0), Vector3(3.2, 0.3, 2.4), Color("6c757d"))
			k.layer = "verre"
			k.box(Vector3(0, 1.05, 0), Vector3(3.1, 1.5, 2.3), Color(0.82, 0.93, 0.9, 0.35), 0.0, false)
			k.quad(Vector3(-1.55, 1.8, -1.15), Vector3(1.55, 1.8, -1.15), Vector3(1.55, 2.4, 0.0), Vector3(-1.55, 2.4, 0.0), Color(0.82, 0.93, 0.9, 0.35))
			k.quad(Vector3(-1.55, 2.4, 0.0), Vector3(1.55, 2.4, 0.0), Vector3(1.55, 1.8, 1.15), Vector3(-1.55, 1.8, 1.15), Color(0.82, 0.93, 0.9, 0.35))
			k.layer = "base"
			for i in 4:
				k.blob(Vector3(-1.1 + i * 0.73, 0.55, -0.5), Vector3(0.28, 0.25, 0.25), Color("2d6a4f"), Color("74c69d"), 0.25, 0)
				k.blob(Vector3(-1.1 + i * 0.73, 0.55, 0.5), Vector3(0.28, 0.3, 0.25), Color("2d6a4f"), Color("e63946") if i % 2 == 0 else Color("52b788"), 0.25, 0)
			for sx in [-1.55, 0.0, 1.55]:
				k.box(Vector3(sx, 1.2, 1.16), Vector3(0.05, 1.8, 0.05), Color("dee2e6"), 0.0, false)
		"ruche":
			k.box(Vector3(0, 0.2, 0), Vector3(0.6, 0.4, 0.5), BOIS_FONCE)
			for j in 3:
				k.box(Vector3(0, 0.5 + j * 0.22, 0), Vector3(0.55, 0.2, 0.48), [Color("f4d35e"), Color("e9c46a"), Color("f4d35e")][j])
			k.box(Vector3(0, 1.17, 0), Vector3(0.66, 0.06, 0.56), Color("adb5bd"), 0.0, false)
		"compost":
			k.box(Vector3(0, 0.45, 0), Vector3(1.0, 0.9, 1.0), Color("2d6a4f"))
			k.box(Vector3(0, 0.92, 0), Vector3(1.05, 0.05, 1.05), Color("1b4332"), 0.0, false)
			for i in 4:
				k.box(Vector3(0, 0.2 + i * 0.2, 0.51), Vector3(0.9, 0.04, 0.02), Color("40916c"), 0.0, false)
		# --- Livraison -----------------------------------------------------------------
		"cagettes":
			k.box(Vector3(0, 0.07, 0), Vector3(1.2, 0.14, 0.8), BOIS_CLAIR)
			var cols := [Color("e63946"), Color("f4a261"), Color("90be6d"), Color("f4d35e")]
			for i in 6:
				var p := Vector3(-0.3 + (i % 2) * 0.6, 0.3 + (i / 2) * 0.3, 0.0)
				k.box(p, Vector3(0.55, 0.28, 0.75), BOIS_CLAIR)
				k.blob(p + Vector3(0, 0.12, 0), Vector3(0.22, 0.06, 0.3), cols[i % 4], cols[(i + 1) % 4], 0.3, 0)
		"transpalette":
			for sx in [-0.2, 0.2]:
				k.box(Vector3(sx, 0.06, 0.2), Vector3(0.16, 0.08, 1.1), Color("e63946"))
			k.box(Vector3(0, 0.25, -0.4), Vector3(0.55, 0.35, 0.15), Color("e63946"))
			k.tube(Vector3(0, 0.4, -0.45), Vector3(0, 1.1, -0.75), 0.03, 0.03, 4, NOIR)
			k.box(Vector3(0, 1.12, -0.77), Vector3(0.35, 0.05, 0.05), NOIR, 0.0, false)
		"scooter":
			var c := Color("e63946") if teinte == Color.WHITE else teinte
			k.box(Vector3(0, 0.5, 0), Vector3(0.35, 0.35, 1.1), c)
			k.box(Vector3(0, 0.78, -0.15), Vector3(0.3, 0.12, 0.6), NOIR)
			k.box(Vector3(0, 0.85, 0.45), Vector3(0.3, 0.6, 0.12), c)
			k.tube(Vector3(-0.3, 1.15, 0.5), Vector3(0.3, 1.15, 0.5), 0.02, 0.02, 4, NOIR)
			for sz in [-0.45, 0.5]:
				var sauve := k.xf
				k.xf = sauve * Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(0, 0.22, sz))
				k.lathe(Vector3(0, -0.05, 0), [Vector2(0.2, 0.0), Vector2(0.22, 0.05), Vector2(0.2, 0.1)], 10, NOIR)
				k.xf = sauve
			k.box(Vector3(0, 1.05, -0.55), Vector3(0.45, 0.4, 0.45), Color("f4d35e"))
		"camionnette":
			var c := Color("f8f9fa") if teinte == Color.WHITE else teinte
			k.box(Vector3(0, 0.55, 0), Vector3(1.8, 0.7, 4.6), c)
			k.box(Vector3(0, 1.4, -0.4), Vector3(1.78, 1.2, 3.6), c)
			k.box(Vector3(0, 1.15, 1.75), Vector3(1.7, 0.75, 1.0), c)
			k.layer = "verre"
			k.box(Vector3(0, 1.25, 2.1), Vector3(1.6, 0.5, 0.4), Color(0.55, 0.7, 0.82, 0.75), 0.0, false)
			k.layer = "base"
			k.box(Vector3(0.9, 1.35, -0.4), Vector3(0.02, 0.6, 2.4), Color("9c4f3a"), 0.0, false)
			k.box(Vector3(-0.9, 1.35, -0.4), Vector3(0.02, 0.6, 2.4), Color("9c4f3a"), 0.0, false)
			for sx in [-0.82, 0.82]:
				for sz in [-1.5, 1.5]:
					k.box(Vector3(sx, 0.32, sz), Vector3(0.24, 0.64, 0.64), NOIR)
		# --- Pour les décors de base ---------------------------------------------------
		"fourneau":
			k.box(Vector3(0, 0.45, 0), Vector3(1.0, 0.9, 0.75), INOX)
			k.box(Vector3(0, 0.92, 0), Vector3(0.95, 0.04, 0.7), Color("343a40"), 0.0, false)
			k.box(Vector3(0, 0.45, 0.38), Vector3(0.7, 0.45, 0.02), NOIR, 0.0, false)
			for sx in [-0.22, 0.22]:
				k.lathe(Vector3(sx, 0.94, 0.0), [Vector2(0.0, 0.0), Vector2(0.13, 0.0), Vector2(0.13, 0.02), Vector2(0.0, 0.02)], 8, NOIR)
		"wc":
			k.lathe(Vector3(0, 0, 0.1), [Vector2(0.0, 0.0), Vector2(0.15, 0.0), Vector2(0.2, 0.35), Vector2(0.22, 0.42), Vector2(0.0, 0.42)], 10, BLANC)
			k.box(Vector3(0, 0.6, -0.2), Vector3(0.4, 0.4, 0.18), BLANC)
		"lavabo":
			k.box(Vector3(0, 0.42, 0), Vector3(0.12, 0.84, 0.12), BLANC, 0.0, false)
			k.lathe(Vector3(0, 0.78, 0.05), [Vector2(0.0, 0.0), Vector2(0.16, 0.0), Vector2(0.22, 0.12), Vector2(0.0, 0.12)], 10, BLANC, true, false)
			k.tube(Vector3(0, 0.88, -0.18), Vector3(0, 1.0, -0.05), 0.02, 0.02, 4, INOX)
			k.box(Vector3(0, 1.45, -0.22), Vector3(0.55, 0.7, 0.03), Color("cfe8ef"))


## Petites étagères murales derrière un meuble (boîtes de thé, pots).
static func _etageres_mur(k: LpKit, l: float, cols: Array) -> void:
	for j in 2:
		k.box(Vector3(0, 1.4 + j * 0.4, -0.2), Vector3(l, 0.04, 0.2), BOIS_FONCE, 0.0, false)
		for i in 6:
			k.box(Vector3(-l * 0.4 + i * l * 0.16, 1.5 + j * 0.4, -0.2), Vector3(0.12, 0.16, 0.12), cols[(i + j) % cols.size()], 0.0, false)
