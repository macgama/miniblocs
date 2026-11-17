class_name MeublesModelesPlus
extends RefCounted
## Modèles des meubles ajoutés pour étoffer le catalogue à toutes les époques
## (17 novembre 2026) : machine à coudre, phonographe, poste de TSF, juke-box,
## téléviseur à tube, ordinateur personnel, écran plat, robot aspirateur…
##
## Même repère que MeublesModeles : centre de l'emprise au sol en (0, 0, 0),
## dos vers −Z (contre le mur), avant vers +Z. c : couleurs de la palette du
## style (bois, bois2, tissu, tissu2, metal, accent, pierre, blanc).
## Rend faux si le modèle k n'est pas d'ici.

const NOIR := Color("26272b")
const ECRAN := Color("1d2b3a")
const ECRAN_ALLUME := Color("6fb7e8")
const PLASTIQUE := Color("e4e2dc")
const LAITON := Color("c9a227")


static func build(kit: LpKit, k: String, w: float, d: float, h: float, c: Dictionary) -> bool:
	var wood: Color = c.bois
	var wood2: Color = c.bois2
	var cloth: Color = c.tissu
	var cloth2: Color = c.tissu2
	var metal: Color = c.metal
	var accent: Color = c.accent
	var white: Color = c.blanc
	match k:
		# --- XIXe siècle ---------------------------------------------------------------
		"machine_coudre":
			kit.box(Vector3(0, 0.74, -0.1), Vector3(0.8, 0.05, 0.45), wood)
			for sx in [-0.33, 0.33]:
				kit.box(Vector3(sx, 0.36, -0.1), Vector3(0.05, 0.72, 0.4), metal)
			kit.box(Vector3(0, 0.08, -0.05), Vector3(0.45, 0.04, 0.25), metal)
			kit.box(Vector3(0.05, 0.84, -0.12), Vector3(0.36, 0.14, 0.12), NOIR)
			kit.box(Vector3(0.19, 0.95, -0.12), Vector3(0.08, 0.32, 0.12), NOIR)
			kit.box(Vector3(0.0, 1.06, -0.12), Vector3(0.42, 0.08, 0.1), NOIR)
			kit.tube(Vector3(-0.2, 1.06, -0.18), Vector3(-0.2, 1.06, -0.06), 0.06, 0.06, 8, LAITON)
			_chaise(kit, Vector3(0, 0, 0.32), PI, wood, cloth)
		"secretaire":
			kit.box(Vector3(0, 0.4, -0.2), Vector3(0.85, 0.8, 0.5), wood)
			kit.beam(Vector3(0, 0.82, 0.05), Vector3(0, 1.0, -0.2), 0.85, 0.04, wood2)
			kit.box(Vector3(0, 1.25, -0.3), Vector3(0.85, 0.5, 0.3), wood)
			for i in 3:
				kit.box(Vector3(0, 0.15 + i * 0.22, 0.06), Vector3(0.7, 0.16, 0.01), wood2)
				kit.box(Vector3(0, 0.15 + i * 0.22, 0.07), Vector3(0.08, 0.03, 0.02), LAITON)
		"meridienne":
			kit.box(Vector3(0, 0.3, 0), Vector3(w - 0.15, 0.2, 0.7), wood)
			kit.box(Vector3(0, 0.44, 0.02), Vector3(w - 0.25, 0.12, 0.62), cloth)
			kit.box(Vector3(-w * 0.5 + 0.15, 0.62, 0), Vector3(0.18, 0.55, 0.7), cloth)
			kit.beam(Vector3(-w * 0.5 + 0.2, 0.85, -0.3), Vector3(w * 0.15, 0.6, -0.3), 0.12, 0.3, cloth)
			for sx in [-1, 1]:
				for sz in [-1, 1]:
					kit.box(Vector3(sx * (w * 0.5 - 0.15), 0.1, sz * 0.28), Vector3(0.06, 0.2, 0.06), wood.darkened(0.1))
		"phonographe":
			kit.box(Vector3(0, 0.38, 0), Vector3(0.5, 0.76, 0.5), wood)
			kit.box(Vector3(0, 0.84, 0), Vector3(0.36, 0.14, 0.36), wood.darkened(0.15))
			kit.lathe(Vector3(0, 0.91, 0), [Vector2(0.15, 0.0), Vector2(0.15, 0.01)], 12, NOIR)
			kit.tube(Vector3(0.12, 0.92, 0.1), Vector3(0.05, 1.05, -0.05), 0.02, 0.025, 6, LAITON)
			kit.tube(Vector3(0.05, 1.05, -0.05), Vector3(-0.05, 1.2, -0.15), 0.03, 0.28, 10, LAITON)
		"lampe_petrole":
			kit.box(Vector3(0, 0.3, 0), Vector3(0.45, 0.6, 0.45), wood)
			kit.lathe(Vector3(0, 0.6, 0), [Vector2(0.09, 0.0), Vector2(0.11, 0.08), Vector2(0.03, 0.14), Vector2(0.03, 0.18)], 8, LAITON)
			kit.layer = "lumiere"
			kit.lathe(Vector3(0, 0.78, 0), [Vector2(0.05, 0.0), Vector2(0.07, 0.06), Vector2(0.035, 0.2)], 8, Color("ffd27a"))
			kit.layer = "base"
		"glaciere":
			kit.box(Vector3(0, 0.65, -0.2), Vector3(0.8, 1.3, 0.55), wood)
			for y in [0.95, 0.4]:
				kit.box(Vector3(0, y, 0.085), Vector3(0.65, 0.42, 0.02), wood2)
				kit.box(Vector3(0.25, y, 0.1), Vector3(0.05, 0.08, 0.03), LAITON)
		"telephone_mural":
			kit.box(Vector3(0, 1.4, -0.42), Vector3(0.25, 0.45, 0.14), wood)
			kit.tube(Vector3(-0.09, 1.55, -0.35), Vector3(-0.09, 1.55, -0.28), 0.04, 0.03, 6, NOIR)
			kit.box(Vector3(0.15, 1.42, -0.38), Vector3(0.04, 0.16, 0.06), NOIR)
			for x in [-0.06, 0.06]:
				kit.lathe(Vector3(x, 1.6, -0.35), [Vector2(0.035, 0.0), Vector2(0.035, 0.05)], 8, LAITON)
		"poele_faience":
			kit.box(Vector3(0, 0.1, -0.15), Vector3(0.85, 0.2, 0.75), c.pierre)
			kit.box(Vector3(0, 0.95, -0.15), Vector3(0.75, 1.5, 0.65), cloth2.lerp(Color("eae4d4"), 0.5))
			for i in 5:
				kit.box(Vector3(0, 0.35 + i * 0.3, 0.18), Vector3(0.76, 0.02, 0.02), accent)
			kit.box(Vector3(0, 1.8, -0.15), Vector3(0.82, 0.12, 0.72), cloth2.lerp(Color("eae4d4"), 0.3))
			kit.box(Vector3(0, 0.45, 0.19), Vector3(0.28, 0.24, 0.02), metal)
		"rouet":
			kit.beam(Vector3(-0.35, 0.25, 0), Vector3(0.35, 0.35, 0), 0.08, 0.08, wood)
			for sx in [-0.3, 0.3]:
				kit.beam(Vector3(sx, 0.0, 0.15), Vector3(sx, 0.3, 0.0), 0.04, 0.04, wood)
				kit.beam(Vector3(sx, 0.0, -0.15), Vector3(sx, 0.3, 0.0), 0.04, 0.04, wood)
			kit.box(Vector3(-0.15, 0.55, 0), Vector3(0.04, 0.5, 0.04), wood)
			kit.tube(Vector3(-0.15, 0.75, -0.02), Vector3(-0.15, 0.75, 0.02), 0.3, 0.3, 14, wood2, true)
			kit.box(Vector3(0.3, 0.55, 0), Vector3(0.04, 0.4, 0.04), wood)
			kit.tube(Vector3(0.2, 0.75, 0), Vector3(0.4, 0.75, 0), 0.04, 0.03, 6, cloth2)
		"metier_tisser":
			for sx in [-1, 1]:
				for sz in [-1, 1]:
					kit.box(Vector3(sx * 0.8, 0.9, sz * 0.7), Vector3(0.08, 1.8, 0.08), wood)
			for z in [-0.7, 0.7]:
				kit.box(Vector3(0, 1.75, z), Vector3(1.7, 0.08, 0.08), wood)
			kit.box(Vector3(0, 0.8, 0.0), Vector3(1.4, 0.04, 1.2), cloth)
			kit.box(Vector3(0, 1.1, 0.2), Vector3(1.5, 0.3, 0.06), wood2)
			kit.box(Vector3(0, 0.45, 0.85), Vector3(1.0, 0.06, 0.3), wood)
		"fauteuil_club":
			kit.box(Vector3(0, 0.22, 0), Vector3(0.85, 0.36, 0.8), cloth.darkened(0.2))
			kit.box(Vector3(0, 0.44, 0.06), Vector3(0.6, 0.12, 0.62), cloth.darkened(0.1))
			kit.box(Vector3(0, 0.62, -0.3), Vector3(0.85, 0.55, 0.22), cloth.darkened(0.2))
			for sx in [-1, 1]:
				kit.lathe(Vector3(sx * 0.36, 0.0, 0.0), [Vector2(0.14, 0.0), Vector2(0.14, 0.6), Vector2(0.12, 0.64)], 8, cloth.darkened(0.2))
		"radio":
			kit.box(Vector3(0, 0.3, -0.2), Vector3(0.55, 0.6, 0.4), wood.darkened(0.1))
			kit.box(Vector3(0, 0.7, -0.22), Vector3(0.5, 0.4, 0.32), wood)
			kit.lathe(Vector3(0, 0.9, -0.22), [Vector2(0.25, 0.0), Vector2(0.18, 0.12), Vector2(0.0, 0.18)], 10, wood)
			kit.box(Vector3(0, 0.78, -0.05), Vector3(0.34, 0.2, 0.01), cloth2)
			kit.layer = "lumiere"
			kit.box(Vector3(0, 0.6, -0.055), Vector3(0.2, 0.04, 0.01), Color("ffd27a"))
			kit.layer = "base"
			for x in [-0.12, 0.12]:
				kit.tube(Vector3(x, 0.55, -0.06), Vector3(x, 0.55, -0.02), 0.03, 0.03, 6, LAITON)
		"lessiveuse":
			kit.lathe(Vector3(-0.15, 0.0, 0.0), [Vector2(0.3, 0.0), Vector2(0.32, 0.5), Vector2(0.32, 0.52)], 10, metal.lightened(0.3), true, false)
			kit.tube(Vector3(-0.15, 0.5, 0), Vector3(-0.15, 0.85, 0), 0.04, 0.03, 6, metal.lightened(0.3))
			kit.beam(Vector3(0.3, 0.0, -0.1), Vector3(0.35, 0.8, -0.25), 0.3, 0.03, wood2)
		# --- Après-guerre -------------------------------------------------------------
		"juke_box":
			kit.box(Vector3(0, 0.65, -0.15), Vector3(0.85, 1.3, 0.6), wood)
			kit.lathe(Vector3(0, 1.3, -0.15), [Vector2(0.42, 0.0), Vector2(0.3, 0.2), Vector2(0.0, 0.3)], 12, wood)
			kit.layer = "lumiere"
			kit.box(Vector3(0, 1.05, 0.155), Vector3(0.6, 0.35, 0.02), Color("ffd27a"))
			for sx in [-0.38, 0.38]:
				kit.box(Vector3(sx, 0.7, 0.155), Vector3(0.06, 1.1, 0.02), [Color("ff6f91"), Color("6fe3ff")][0 if sx < 0 else 1] as Color)
			kit.layer = "base"
			kit.box(Vector3(0, 0.45, 0.155), Vector3(0.6, 0.4, 0.02), metal.lightened(0.4))
		"flipper":
			for sx in [-1, 1]:
				for sz in [-1, 1]:
					kit.box(Vector3(sx * 0.28, 0.4, sz * 0.75), Vector3(0.05, 0.8, 0.05), metal)
			kit.beam(Vector3(0, 0.85, 0.85), Vector3(0, 1.0, -0.65), 0.65, 0.18, accent)
			kit.layer = "lumiere"
			kit.beam(Vector3(0, 0.95, 0.8), Vector3(0, 1.1, -0.6), 0.55, 0.02, Color("6fe3ff"))
			kit.box(Vector3(0, 1.4, -0.85), Vector3(0.6, 0.6, 0.06), Color("ff6f91"))
			kit.layer = "base"
			kit.box(Vector3(0, 1.4, -0.9), Vector3(0.66, 0.66, 0.08), accent.darkened(0.2))
		"baby_foot":
			for sx in [-1, 1]:
				for sz in [-1, 1]:
					kit.box(Vector3(sx * 0.6, 0.38, sz * 0.25), Vector3(0.08, 0.76, 0.08), wood)
			kit.box(Vector3(0, 0.82, 0), Vector3(1.3, 0.2, 0.7), wood)
			kit.box(Vector3(0, 0.9, 0), Vector3(1.2, 0.02, 0.6), Color("3f8f4a"))
			for i in 8:
				var x := -0.52 + i * 0.15
				kit.tube(Vector3(x, 0.96, -0.5), Vector3(x, 0.96, 0.5), 0.012, 0.012, 5, metal.lightened(0.4))
				kit.box(Vector3(x, 0.93, -0.1 + (i % 3) * 0.1), Vector3(0.03, 0.1, 0.04), Color("d64933") if i % 2 == 0 else Color("2e86ab"))
		"lave_linge", "seche_linge":
			kit.box(Vector3(0, 0.43, -0.15), Vector3(0.6, 0.85, 0.6), white)
			kit.lathe(Vector3(0, 0.42, 0.15), [Vector2(0.2, 0.0), Vector2(0.2, 0.02)], 14, metal.lightened(0.3))
			kit.layer = "verre"
			kit.lathe(Vector3(0, 0.42, 0.16), [Vector2(0.16, 0.0), Vector2(0.14, 0.02)], 14, Color(0.6, 0.8, 0.95) if k == "lave_linge" else Color(0.85, 0.85, 0.85))
			kit.layer = "base"
			kit.box(Vector3(0, 0.78, 0.155), Vector3(0.55, 0.1, 0.02), PLASTIQUE.darkened(0.1))
			kit.tube(Vector3(0.18, 0.78, 0.16), Vector3(0.18, 0.78, 0.18), 0.03, 0.03, 8, NOIR)
		"micro_ondes":
			kit.box(Vector3(0, 0.45, -0.15), Vector3(0.7, 0.9, 0.6), wood2)
			kit.box(Vector3(0, 1.05, -0.2), Vector3(0.5, 0.3, 0.38), white)
			kit.box(Vector3(-0.06, 1.05, -0.005), Vector3(0.32, 0.22, 0.01), ECRAN)
			kit.box(Vector3(0.18, 1.05, -0.005), Vector3(0.1, 0.22, 0.01), NOIR)
		"tv_tube":
			kit.box(Vector3(0, 0.25, -0.15), Vector3(0.7, 0.5, 0.5), wood)
			kit.box(Vector3(0, 0.75, -0.2), Vector3(0.62, 0.5, 0.45), wood.darkened(0.1))
			kit.box(Vector3(-0.06, 0.75, 0.03), Vector3(0.42, 0.36, 0.02), ECRAN)
			kit.box(Vector3(0.24, 0.8, 0.03), Vector3(0.08, 0.2, 0.02), PLASTIQUE)
			kit.tube(Vector3(0, 1.0, -0.2), Vector3(-0.2, 1.35, -0.25), 0.008, 0.008, 4, metal)
			kit.tube(Vector3(0, 1.0, -0.2), Vector3(0.2, 1.35, -0.25), 0.008, 0.008, 4, metal)
		"hifi":
			kit.box(Vector3(0, 0.3, -0.2), Vector3(0.6, 0.6, 0.45), wood.darkened(0.15))
			for i in 3:
				kit.box(Vector3(0, 0.66 + i * 0.12, -0.2), Vector3(0.48, 0.1, 0.36), NOIR.lightened(0.1 * i))
				kit.box(Vector3(0.1, 0.66 + i * 0.12, -0.015), Vector3(0.2, 0.03, 0.01), metal.lightened(0.5))
			kit.box(Vector3(0, 1.03, -0.2), Vector3(0.45, 0.02, 0.36), Color(0.4, 0.4, 0.42))
			kit.lathe(Vector3(0, 1.04, -0.2), [Vector2(0.15, 0.0), Vector2(0.15, 0.01)], 12, NOIR)
		"ordinateur":
			kit.box(Vector3(0, 0.72, -0.1), Vector3(1.5, 0.05, 0.65), wood2)
			for sx in [-0.7, 0.7]:
				kit.box(Vector3(sx, 0.36, -0.1), Vector3(0.05, 0.72, 0.6), wood2.darkened(0.1))
			kit.box(Vector3(0, 0.8, -0.22), Vector3(0.45, 0.1, 0.38), PLASTIQUE)
			kit.box(Vector3(0, 1.03, -0.22), Vector3(0.38, 0.34, 0.34), PLASTIQUE)
			kit.box(Vector3(0, 1.04, -0.045), Vector3(0.28, 0.22, 0.01), Color("2f5d3a"))
			kit.box(Vector3(0, 0.76, 0.12), Vector3(0.42, 0.03, 0.15), PLASTIQUE.darkened(0.08))
			_chaise(kit, Vector3(0, 0, 0.45), PI, metal, cloth)
		"minitel":
			kit.box(Vector3(0, 0.35, -0.2), Vector3(0.5, 0.7, 0.45), wood2)
			kit.beam(Vector3(0, 0.72, -0.05), Vector3(0, 1.0, -0.2), 0.3, 0.26, Color("6b5f53"))
			kit.box(Vector3(0, 0.88, -0.05), Vector3(0.2, 0.16, 0.01), Color("27413a"))
			kit.box(Vector3(0, 0.73, 0.05), Vector3(0.28, 0.03, 0.14), Color("6b5f53"))
		"fauteuil_oeuf":
			kit.lathe(Vector3(0, 0.0, 0.0), [Vector2(0.22, 0.0), Vector2(0.03, 0.03), Vector2(0.03, 0.3)], 8, metal)
			kit.lathe(Vector3(0, 0.3, -0.05), [Vector2(0.15, 0.0), Vector2(0.42, 0.25), Vector2(0.45, 0.6), Vector2(0.35, 0.95), Vector2(0.0, 1.05)], 10, white)
			kit.box(Vector3(0, 0.5, 0.12), Vector3(0.5, 0.15, 0.4), cloth)
			kit.box(Vector3(0, 0.8, -0.25), Vector3(0.5, 0.45, 0.12), cloth)
		"lampe_lave":
			kit.box(Vector3(0, 0.25, 0), Vector3(0.45, 0.5, 0.45), wood2)
			kit.lathe(Vector3(0, 0.5, 0), [Vector2(0.08, 0.0), Vector2(0.05, 0.08)], 8, metal.lightened(0.4))
			kit.layer = "lumiere"
			kit.lathe(Vector3(0, 0.58, 0), [Vector2(0.05, 0.0), Vector2(0.07, 0.15), Vector2(0.04, 0.3)], 8, accent.lerp(Color("ff5fa2"), 0.6))
			kit.layer = "base"
		"borne_arcade":
			kit.box(Vector3(0, 0.9, -0.1), Vector3(0.7, 1.8, 0.6), NOIR)
			kit.box(Vector3(0, 0.95, 0.205), Vector3(0.6, 0.12, 0.2), accent)
			kit.layer = "lumiere"
			kit.beam(Vector3(0, 1.15, 0.18), Vector3(0, 1.5, 0.08), 0.5, 0.02, ECRAN_ALLUME)
			kit.box(Vector3(0, 1.72, 0.205), Vector3(0.6, 0.12, 0.02), Color("ffd27a"))
			kit.layer = "base"
			for x in [-0.15, 0.1, 0.2]:
				kit.tube(Vector3(x, 1.01, 0.22), Vector3(x, 1.06, 0.22), 0.025, 0.025, 6, Color("d64933"))
		# --- Aujourd'hui -------------------------------------------------------------
		"canape_angle":
			kit.box(Vector3(0, 0.22, -0.5), Vector3(w - 0.1, 0.4, 0.9), cloth)
			kit.box(Vector3(w * 0.5 - 0.5, 0.22, 0.35), Vector3(0.9, 0.4, 0.9), cloth)
			kit.box(Vector3(0, 0.6, -0.88), Vector3(w - 0.1, 0.4, 0.16), cloth.darkened(0.08))
			kit.box(Vector3(-w * 0.5 + 0.12, 0.5, -0.5), Vector3(0.18, 0.2, 0.9), cloth.darkened(0.08))
			for i in 3:
				kit.box(Vector3(-0.9 + i * 0.85, 0.5, -0.72), Vector3(0.45, 0.35, 0.12), cloth2)
		"ecran_plat":
			kit.box(Vector3(0, 0.22, -0.25), Vector3(1.8, 0.44, 0.42), wood2)
			kit.box(Vector3(0.55, 0.47, -0.2), Vector3(0.35, 0.06, 0.28), NOIR)
			kit.box(Vector3(0, 0.5, -0.3), Vector3(0.3, 0.1, 0.2), NOIR)
			kit.box(Vector3(0, 0.95, -0.32), Vector3(1.4, 0.8, 0.05), NOIR)
			kit.layer = "lumiere"
			kit.box(Vector3(0, 0.95, -0.29), Vector3(1.32, 0.72, 0.01), ECRAN_ALLUME)
			kit.layer = "base"
		"home_cinema":
			kit.box(Vector3(0, 0.22, -0.25), Vector3(2.4, 0.44, 0.42), wood)
			kit.box(Vector3(0, 1.1, -0.42), Vector3(2.0, 1.15, 0.06), NOIR)
			kit.layer = "lumiere"
			kit.box(Vector3(0, 1.1, -0.385), Vector3(1.92, 1.07, 0.01), ECRAN_ALLUME.darkened(0.2))
			kit.layer = "base"
			for sx in [-1.35, 1.35]:
				kit.box(Vector3(sx, 0.6, -0.25), Vector3(0.25, 1.2, 0.3), NOIR)
				kit.lathe(Vector3(sx, 0.8, -0.095), [Vector2(0.08, 0.0), Vector2(0.08, 0.01)], 10, metal)
			kit.box(Vector3(0, 0.5, -0.2), Vector3(0.9, 0.12, 0.2), NOIR)
		"bureau_debout":
			for sx in [-0.7, 0.7]:
				kit.box(Vector3(sx, 0.55, -0.1), Vector3(0.06, 1.1, 0.06), metal)
				kit.box(Vector3(sx, 0.02, -0.1), Vector3(0.06, 0.04, 0.6), metal)
			kit.box(Vector3(0, 1.1, -0.1), Vector3(1.6, 0.04, 0.7), wood2)
			kit.box(Vector3(0, 1.12, 0.05), Vector3(0.36, 0.02, 0.25), metal.lightened(0.4))
			kit.beam(Vector3(0, 1.13, -0.08), Vector3(0, 1.36, -0.13), 0.36, 0.01, metal.lightened(0.4))
			kit.box(Vector3(-0.4, 1.38, -0.3), Vector3(0.6, 0.38, 0.03), NOIR)
			kit.layer = "lumiere"
			kit.box(Vector3(-0.4, 1.38, -0.28), Vector3(0.56, 0.33, 0.01), ECRAN_ALLUME)
			kit.layer = "base"
		"fauteuil_gamer":
			kit.lathe(Vector3(0, 0.0, 0.0), [Vector2(0.3, 0.0), Vector2(0.03, 0.06), Vector2(0.03, 0.42)], 5, NOIR)
			kit.box(Vector3(0, 0.48, 0.05), Vector3(0.55, 0.12, 0.5), NOIR)
			kit.box(Vector3(0, 0.95, -0.22), Vector3(0.52, 0.85, 0.12), NOIR)
			kit.box(Vector3(0, 0.95, -0.15), Vector3(0.12, 0.8, 0.02), accent)
			for sx in [-1, 1]:
				kit.box(Vector3(sx * 0.3, 0.68, 0.0), Vector3(0.06, 0.04, 0.35), NOIR)
		"robot_aspi":
			kit.lathe(Vector3(0, 0.0, 0.1), [Vector2(0.17, 0.0), Vector2(0.17, 0.08), Vector2(0.15, 0.09)], 14, NOIR)
			kit.box(Vector3(0, 0.03, -0.3), Vector3(0.4, 0.06, 0.2), PLASTIQUE)
			kit.layer = "lumiere"
			kit.lathe(Vector3(0, 0.09, 0.1), [Vector2(0.03, 0.0), Vector2(0.03, 0.005)], 8, Color("6fe3ff"))
			kit.layer = "base"
		"enceinte":
			kit.box(Vector3(0, 0.3, 0), Vector3(0.35, 0.6, 0.35), wood2)
			kit.lathe(Vector3(0, 0.6, 0), [Vector2(0.08, 0.0), Vector2(0.08, 0.2), Vector2(0.07, 0.21)], 12, cloth2.darkened(0.3))
			kit.layer = "lumiere"
			kit.lathe(Vector3(0, 0.81, 0), [Vector2(0.05, 0.0), Vector2(0.05, 0.005)], 12, Color("6fb7e8"))
			kit.layer = "base"
		"tapis_course":
			kit.box(Vector3(0, 0.12, 0.15), Vector3(0.75, 0.2, 1.5), NOIR)
			kit.box(Vector3(0, 0.23, 0.2), Vector3(0.55, 0.02, 1.3), Color("3a3b3f"))
			for sx in [-0.33, 0.33]:
				kit.beam(Vector3(sx, 0.2, -0.5), Vector3(sx, 1.2, -0.65), 0.05, 0.05, metal)
			kit.box(Vector3(0, 1.25, -0.65), Vector3(0.75, 0.1, 0.25), NOIR)
			kit.layer = "lumiere"
			kit.box(Vector3(0, 1.31, -0.65), Vector3(0.3, 0.01, 0.15), ECRAN_ALLUME)
			kit.layer = "base"
		"velo_appart":
			kit.box(Vector3(0, 0.03, 0), Vector3(0.5, 0.06, 0.9), NOIR)
			kit.beam(Vector3(0, 0.05, -0.3), Vector3(0, 0.75, -0.1), 0.08, 0.08, accent)
			kit.beam(Vector3(0, 0.05, 0.3), Vector3(0, 1.0, 0.2), 0.08, 0.08, accent)
			kit.box(Vector3(0, 0.8, -0.12), Vector3(0.22, 0.06, 0.3), NOIR)
			kit.box(Vector3(0, 1.02, 0.22), Vector3(0.45, 0.04, 0.06), NOIR)
			kit.tube(Vector3(-0.04, 0.35, 0.3), Vector3(0.04, 0.35, 0.3), 0.22, 0.22, 12, metal.lightened(0.3))
		"imprimante_3d":
			kit.box(Vector3(0, 0.35, 0), Vector3(0.7, 0.7, 0.6), wood2)
			for sx in [-0.25, 0.25]:
				for sz in [-0.2, 0.2]:
					kit.box(Vector3(sx, 0.95, sz), Vector3(0.03, 0.5, 0.03), NOIR)
			kit.box(Vector3(0, 1.2, 0), Vector3(0.55, 0.04, 0.45), NOIR)
			kit.box(Vector3(0, 0.72, 0), Vector3(0.45, 0.02, 0.38), metal.lightened(0.3))
			kit.box(Vector3(0.05, 0.82, 0.02), Vector3(0.12, 0.18, 0.12), Color("e76f51"))
			kit.box(Vector3(0.05, 1.05, 0.02), Vector3(0.08, 0.1, 0.08), metal)
		"ilot":
			kit.box(Vector3(0, 0.45, 0), Vector3(w - 0.1, 0.9, 0.9), white)
			kit.box(Vector3(0, 0.92, 0), Vector3(w - 0.05, 0.04, 0.95), c.pierre)
			kit.box(Vector3(-0.35, 0.945, 0), Vector3(0.6, 0.01, 0.5), NOIR)
			kit.box(Vector3(0.45, 0.945, 0.05), Vector3(0.4, 0.02, 0.35), metal.lightened(0.4))
			kit.tube(Vector3(0.45, 0.94, -0.25), Vector3(0.45, 1.25, -0.2), 0.02, 0.02, 6, metal.lightened(0.4))
		"cave_vin":
			kit.box(Vector3(0, 0.7, -0.2), Vector3(0.6, 1.4, 0.55), NOIR)
			kit.layer = "verre"
			kit.box(Vector3(0, 0.75, 0.085), Vector3(0.5, 1.2, 0.02), Color(0.5, 0.55, 0.6))
			kit.layer = "base"
			for i in 6:
				kit.box(Vector3(0, 0.25 + i * 0.19, -0.1), Vector3(0.48, 0.06, 0.3), Color("5a1f2b"))
		"poele_granules":
			kit.box(Vector3(0, 0.55, -0.15), Vector3(0.55, 1.1, 0.55), NOIR.lightened(0.15))
			kit.box(Vector3(0, 0.7, 0.13), Vector3(0.36, 0.36, 0.02), Color("3a2a22"))
			kit.layer = "lumiere"
			kit.box(Vector3(0, 0.62, 0.14), Vector3(0.24, 0.14, 0.01), Color("ff9a3c"))
			kit.layer = "base"
			kit.tube(Vector3(0, 1.1, -0.3), Vector3(0, 1.6, -0.3), 0.07, 0.07, 8, NOIR)
		"lit_escamotable":
			kit.box(Vector3(0, 1.1, -0.82), Vector3(w - 0.1, 2.2, 0.3), wood2)
			kit.box(Vector3(0, 0.2, 0.15), Vector3(w - 0.3, 0.3, d - 0.6), wood2)
			kit.box(Vector3(0, 0.4, 0.15), Vector3(w - 0.4, 0.12, d - 0.7), white)
			kit.box(Vector3(0, 0.48, 0.35), Vector3(w - 0.38, 0.04, d * 0.5), cloth)
			for px in [-0.45, 0.45]:
				kit.box(Vector3(px, 0.52, -0.5), Vector3(0.6, 0.1, 0.3), cloth2.lightened(0.2))
		# --- Futur -------------------------------------------------------------------
		"hologramme":
			kit.lathe(Vector3.ZERO, [Vector2(0.3, 0.0), Vector2(0.3, 0.08), Vector2(0.25, 0.1)], 16, white)
			kit.layer = "verre"
			kit.lathe(Vector3(0, 0.1, 0), [Vector2(0.25, 0.0), Vector2(0.05, 1.0)], 12, Color(0.4, 0.9, 1.0))
			kit.layer = "lumiere"
			kit.blob(Vector3(0, 0.7, 0), Vector3(0.15, 0.15, 0.15), Color("6fe3ff"), Color("c8f7ff"), 0.0, 1)
			kit.layer = "base"
		"robot":
			kit.lathe(Vector3.ZERO, [Vector2(0.22, 0.0), Vector2(0.25, 0.1), Vector2(0.2, 0.75), Vector2(0.15, 0.8)], 12, white)
			kit.box(Vector3(0, 1.0, 0), Vector3(0.3, 0.25, 0.28), white)
			kit.layer = "lumiere"
			kit.box(Vector3(0, 1.02, 0.145), Vector3(0.22, 0.08, 0.01), Color("6fe3ff"))
			kit.layer = "base"
			for sx in [-1, 1]:
				kit.beam(Vector3(sx * 0.24, 0.7, 0), Vector3(sx * 0.3, 0.4, 0.15), 0.07, 0.07, metal.lightened(0.4))
		# --- Lot 4 : début du XIXe siècle -------------------------------------------------
		"harpe":
			kit.box(Vector3(0, 0.08, 0), Vector3(0.4, 0.16, 0.5), wood)
			kit.beam(Vector3(0, 0.15, 0.2), Vector3(0, 1.72, 0.12), 0.09, 0.09, LAITON)
			kit.beam(Vector3(0, 0.16, -0.2), Vector3(0, 1.5, -0.12), 0.14, 0.16, wood2)
			kit.beam(Vector3(0, 1.5, -0.12), Vector3(0, 1.7, 0.12), 0.08, 0.1, wood2)
			for i in 7:
				var z := -0.12 + i * 0.04
				kit.tube(Vector3(0, 0.25, z * 1.4), Vector3(0, 1.45 + i * 0.03, z), 0.004, 0.004, 4, Color("e9e2c8"), false)
		"lit_bateau":
			kit.box(Vector3(0, 0.3, 0), Vector3(w - 0.2, 0.3, d - 0.4), wood)
			kit.box(Vector3(0, 0.5, 0), Vector3(w - 0.3, 0.14, d - 0.5), white)
			kit.box(Vector3(0, 0.58, 0.2), Vector3(w - 0.28, 0.04, d * 0.5), cloth)
			for sz in [-1, 1]:
				kit.beam(Vector3(-w * 0.5 + 0.1, 0.95, sz * (d * 0.5 - 0.12)), Vector3(w * 0.5 - 0.1, 0.95, sz * (d * 0.5 - 0.12)), 0.18, 0.12, wood.darkened(0.1))
				kit.box(Vector3(0, 0.55, sz * (d * 0.5 - 0.12)), Vector3(w - 0.3, 0.8, 0.1), wood)
			for px in [-0.3, 0.3]:
				kit.box(Vector3(px, 0.65, -d * 0.5 + 0.35), Vector3(0.5, 0.1, 0.25), cloth2.lightened(0.2))
		"psyche":
			kit.box(Vector3(0, 0.05, 0), Vector3(0.7, 0.1, 0.35), wood)
			for sx in [-1, 1]:
				kit.box(Vector3(sx * 0.31, 0.85, 0), Vector3(0.06, 1.6, 0.06), wood)
				kit.lathe(Vector3(sx * 0.31, 1.65, 0), [Vector2(0.05, 0.0), Vector2(0.05, 0.05), Vector2(0.0, 0.1)], 8, LAITON)
			kit.box(Vector3(0, 0.95, 0), Vector3(0.56, 1.3, 0.05), wood2)
			kit.layer = "verre"
			kit.box(Vector3(0, 0.95, 0.03), Vector3(0.48, 1.2, 0.01), Color(0.75, 0.82, 0.88))
			kit.layer = "base"
		"baignoire_zinc":
			kit.box(Vector3(0, 0.33, 0), Vector3(w - 0.4, 0.5, 0.7), Color("9aa3a8"))
			kit.box(Vector3(0, 0.55, 0), Vector3(w - 0.55, 0.1, 0.55), Color("9fc3d6"))
			kit.beam(Vector3(-w * 0.5 + 0.2, 0.45, 0), Vector3(-w * 0.5 + 0.08, 0.7, 0), 0.68, 0.06, Color("9aa3a8"))
			for sx in [-1, 1]:
				for sz in [-1, 1]:
					kit.lathe(Vector3(sx * (w * 0.5 - 0.3), 0.0, sz * 0.28), [Vector2(0.04, 0.0), Vector2(0.03, 0.08)], 6, LAITON)
		"cuisiniere_fonte":
			kit.box(Vector3(0, 0.42, -0.15), Vector3(w - 0.3, 0.84, 0.6), NOIR.lightened(0.1))
			kit.box(Vector3(0, 0.86, -0.15), Vector3(w - 0.25, 0.04, 0.65), NOIR)
			for x in [-0.4, 0.0, 0.4]:
				kit.lathe(Vector3(x, 0.88, -0.15), [Vector2(0.11, 0.0), Vector2(0.11, 0.01)], 10, NOIR.lightened(0.25))
			for x in [-0.4, 0.2]:
				kit.box(Vector3(x, 0.45, 0.16), Vector3(0.4, 0.3, 0.02), NOIR.lightened(0.2))
				kit.box(Vector3(x, 0.62, 0.18), Vector3(0.3, 0.03, 0.03), LAITON)
			kit.tube(Vector3(0.7, 0.86, -0.38), Vector3(0.7, 2.0, -0.38), 0.07, 0.07, 8, NOIR)
		"lanterne_magique":
			kit.box(Vector3(0, 0.38, 0), Vector3(0.5, 0.76, 0.5), wood)
			kit.box(Vector3(0, 0.88, 0), Vector3(0.24, 0.22, 0.24), metal.darkened(0.2))
			kit.tube(Vector3(0, 0.88, 0.12), Vector3(0, 0.88, 0.3), 0.05, 0.06, 8, LAITON)
			kit.tube(Vector3(0, 0.99, 0), Vector3(0, 1.12, 0), 0.04, 0.03, 6, metal.darkened(0.2))
			kit.layer = "lumiere"
			kit.lathe(Vector3(0, 0.88, 0.3), [Vector2(0.05, 0.0), Vector2(0.05, 0.005)], 8, Color("ffe7a0"))
			kit.layer = "base"
		"chambre_photo":
			for a in [0.0, 2.1, 4.2]:
				kit.beam(Vector3(0, 1.15, 0), Vector3(sin(a) * 0.35, 0.0, cos(a) * 0.35), 0.04, 0.04, wood)
			kit.box(Vector3(0, 1.22, 0), Vector3(0.32, 0.06, 0.4), wood)
			kit.box(Vector3(0, 1.38, -0.12), Vector3(0.3, 0.3, 0.08), wood2)
			kit.tube(Vector3(0, 1.38, -0.08), Vector3(0, 1.38, 0.15), 0.13, 0.08, 4, NOIR)
			kit.box(Vector3(0, 1.38, 0.17), Vector3(0.18, 0.18, 0.04), wood2)
			kit.tube(Vector3(0, 1.38, 0.19), Vector3(0, 1.38, 0.26), 0.05, 0.05, 8, LAITON)
			kit.box(Vector3(0, 1.45, -0.2), Vector3(0.36, 0.5, 0.02), NOIR)
		# --- Lot 4 : maison d'aujourd'hui et de demain ---------------------------------------
		"frigo_connecte":
			kit.box(Vector3(0, 0.95, -0.15), Vector3(0.85, 1.9, 0.65), metal.lightened(0.45))
			kit.box(Vector3(0, 1.15, 0.18), Vector3(0.01, 1.4, 0.02), NOIR)
			kit.box(Vector3(0, 0.25, 0.18), Vector3(0.8, 0.02, 0.02), NOIR)
			kit.layer = "lumiere"
			kit.box(Vector3(0.2, 1.3, 0.185), Vector3(0.26, 0.4, 0.01), ECRAN_ALLUME)
			kit.layer = "base"
		"realite_virtuelle":
			kit.box(Vector3(0, 0.01, 0), Vector3(1.6, 0.02, 1.6), Color("3b3f46"))
			for sx in [-1, 1]:
				kit.tube(Vector3(sx * 0.75, 0.0, -0.75), Vector3(sx * 0.75, 1.8, -0.75), 0.02, 0.02, 6, NOIR)
				kit.box(Vector3(sx * 0.75, 1.8, -0.75), Vector3(0.1, 0.08, 0.08), NOIR)
			kit.box(Vector3(0, 1.5, 0), Vector3(0.22, 0.12, 0.14), white)
			kit.box(Vector3(0, 1.5, -0.1), Vector3(0.24, 0.04, 0.12), NOIR)
		"mur_vegetal":
			kit.box(Vector3(0, 1.1, -0.44), Vector3(w - 0.1, 2.2, 0.08), Color("3b3f46"))
			for i in 6:
				for j in 8:
					var g := Color("4f8a3a").lerp(Color("8cbf5a"), float((i * 7 + j * 3) % 5) / 4.0)
					kit.box(Vector3(-w * 0.5 + 0.2 + j * (w - 0.3) / 8.0, 0.25 + i * 0.33, -0.36), Vector3(0.24, 0.28, 0.1), g)
		"potager_interieur":
			kit.box(Vector3(0, 0.9, -0.25), Vector3(0.75, 1.8, 0.4), white)
			kit.layer = "lumiere"
			for y in [0.55, 1.05, 1.55]:
				kit.box(Vector3(0, y + 0.18, -0.08), Vector3(0.65, 0.02, 0.05), Color("e67bff"))
			kit.layer = "base"
			for y in [0.35, 0.85, 1.35]:
				kit.box(Vector3(0, y, -0.18), Vector3(0.65, 0.06, 0.3), Color("3b3f46"))
				for x in [-0.22, 0.0, 0.22]:
					kit.blob(Vector3(x, y + 0.1, -0.18), Vector3(0.09, 0.08, 0.09), Color("4f8a3a"), Color("8cbf5a"), 0.2, 1)
		"batterie_domestique":
			kit.box(Vector3(0, 0.6, -0.38), Vector3(0.7, 1.15, 0.18), white)
			kit.layer = "lumiere"
			kit.box(Vector3(0, 0.95, -0.285), Vector3(0.3, 0.02, 0.01), Color("6fe39a"))
			kit.layer = "base"
			kit.tube(Vector3(0.25, 0.05, -0.4), Vector3(0.25, 0.0, -0.45), 0.02, 0.02, 4, NOIR)
		"capsule_sommeil":
			kit.box(Vector3(0, 0.15, 0), Vector3(0.95, 0.3, d - 0.1), white)
			kit.box(Vector3(0, 0.38, 0.05), Vector3(0.8, 0.14, d - 0.3), cloth)
			kit.beam(Vector3(0, 0.75, -d * 0.5 + 0.1), Vector3(0, 0.95, 0.2), 0.95, 0.06, white)
			kit.layer = "verre"
			kit.beam(Vector3(0, 0.95, 0.2), Vector3(0, 0.4, d * 0.5 - 0.05), 0.9, 0.03, Color(0.55, 0.8, 0.95))
			kit.layer = "lumiere"
			kit.box(Vector3(0, 0.3, d * 0.5 - 0.04), Vector3(0.8, 0.02, 0.01), Color("6fe3ff"))
			kit.layer = "base"
			kit.box(Vector3(0, 0.55, -d * 0.5 + 0.25), Vector3(0.5, 0.1, 0.25), cloth2.lightened(0.2))
		"mur_ecran":
			kit.box(Vector3(0, 1.1, -0.45), Vector3(w - 0.1, 2.2, 0.06), NOIR)
			kit.layer = "lumiere"
			kit.box(Vector3(0, 1.1, -0.415), Vector3(w - 0.2, 2.05, 0.01), Color("4fa3d9"))
			kit.layer = "base"
			kit.box(Vector3(0, 0.15, -0.3), Vector3(w - 0.4, 0.3, 0.35), wood2)
		"robot_cuisinier":
			kit.box(Vector3(0, 0.45, -0.2), Vector3(w - 0.15, 0.9, 0.6), white)
			kit.box(Vector3(0, 0.91, -0.2), Vector3(w - 0.1, 0.03, 0.62), Color("3b3f46"))
			kit.box(Vector3(0, 1.85, -0.25), Vector3(w - 0.2, 0.08, 0.15), metal.lightened(0.3))
			for sx in [-1, 1]:
				var a := Vector3(sx * 0.4, 1.8, -0.25)
				var b := Vector3(sx * 0.45, 1.35, -0.05)
				var c2 := Vector3(sx * 0.25, 1.05, 0.0)
				kit.beam(a, b, 0.07, 0.07, white)
				kit.beam(b, c2, 0.06, 0.06, white)
				kit.lathe(c2, [Vector2(0.05, 0.0), Vector2(0.05, 0.04)], 8, metal)
			kit.lathe(Vector3(-0.3, 0.93, -0.2), [Vector2(0.14, 0.0), Vector2(0.14, 0.12)], 12, metal.lightened(0.4), true, false)
		"imprimante_repas":
			kit.box(Vector3(0, 0.45, -0.15), Vector3(0.7, 0.9, 0.6), white)
			kit.box(Vector3(0, 1.2, -0.15), Vector3(0.7, 0.6, 0.6), white)
			kit.layer = "verre"
			kit.box(Vector3(0, 1.2, 0.16), Vector3(0.6, 0.5, 0.01), Color(0.6, 0.75, 0.85))
			kit.layer = "base"
			kit.lathe(Vector3(0, 0.95, -0.1), [Vector2(0.16, 0.0), Vector2(0.17, 0.02)], 12, white.darkened(0.1))
			kit.blob(Vector3(0, 1.0, -0.1), Vector3(0.08, 0.05, 0.08), Color("c96f3c"), Color("e9b26f"), 0.1, 0)
			kit.tube(Vector3(0, 1.45, -0.1), Vector3(0, 1.15, -0.1), 0.02, 0.01, 6, metal)
			kit.layer = "lumiere"
			kit.box(Vector3(0.25, 1.48, 0.165), Vector3(0.12, 0.06, 0.01), ECRAN_ALLUME)
			kit.layer = "base"

		_:
			return false
	return true


static func _chaise(kit: LpKit, at: Vector3, cap: float, wood: Color, cloth: Color) -> void:
	var saved := kit.xf
	kit.xf = saved * Transform3D(Basis(Vector3.UP, cap), at)
	kit.box(Vector3(0, 0.45, 0), Vector3(0.42, 0.05, 0.42), wood)
	kit.box(Vector3(0, 0.485, 0.01), Vector3(0.36, 0.03, 0.36), cloth)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			kit.box(Vector3(sx * 0.18, 0.225, sz * 0.18), Vector3(0.04, 0.45, 0.04), wood)
	kit.box(Vector3(0, 0.72, -0.19), Vector3(0.42, 0.45, 0.04), wood)
	kit.xf = saved
