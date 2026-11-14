class_name SpectaclesModeles
extends RefCounted
## Modèles low-poly des objets de spectacle (SpectaclesObjets), en code, avec
## le kit des meubles (LpKit). Repère : centre de l'emprise au sol, largeur w
## le long de x, profondeur d le long de z, dos vers −Z (contre le mur ou vers
## la scène), avant vers +Z. Couches « base », « verre » et « lumiere » (écrans,
## lampes : sans ombre). Les objets suspendus sont dessinés sous un plafond à 3 m.

const RED := Color("8e1e24")
const RED2 := Color("6d151b")
const GOLD := Color("c9a227")
const BLACK := Color("1c1d20")
const DARK := Color("2b2f33")
const GREY := Color("5e6b73")
const STEEL := Color("9aa3ab")
const WOOD := Color("6b4a2f")
const WOOD2 := Color("b08a5a")
const BOARD := Color("3b3029")
const WHITE := Color("f3f1ec")
const CREAM := Color("e9e1d3")
const LIGHT := Color("fff1c8")
const SCREEN := Color("dfe8f0")
const GREEN := Color("2fae4a")
const LEATHER := Color("3a2a22")
const CEIL := 2.85


static func build(kit: LpKit, e: Dictionary) -> void:
	var w := float(e.w)
	var d := float(e.d)
	var h := float(e.h)
	var k := String(e.k)
	var c := String(e.get("c", ""))
	match k:
		# --- Scène ------------------------------------------------------------------------------
		"plancher_scene":
			kit.box(Vector3(0, h * 0.5 - 0.01, 0), Vector3(w, h - 0.02, d), BLACK, 0.0, false)
			kit.box(Vector3(0, h - 0.01, 0), Vector3(w, 0.02, d), BOARD)
			for i in int(w * 4.0):
				kit.box(Vector3(-w * 0.5 + (i + 0.5) * 0.25, h + 0.001, 0), Vector3(0.01, 0.002, d - 0.02), Color("2a221d"), 0.0, false)
		"rideau_fond":
			# Velours noir plissé, perche de projecteurs au-dessus.
			for i in int(w * 3.0):
				var x: float = -w * 0.5 + (i + 0.5) / 3.0
				kit.box(Vector3(x, h * 0.48, -0.42 + (0.03 if i % 2 == 0 else 0.0)), Vector3(0.34, h * 0.92, 0.06), Color("23242a") if i % 2 == 0 else BLACK)
			kit.tube(Vector3(-w * 0.5 + 0.05, 2.75, -0.2), Vector3(w * 0.5 - 0.05, 2.75, -0.2), 0.025, 0.025, 6, STEEL)
			for i in int(w):
				var x2: float = -w * 0.5 + i + 0.5
				kit.box(Vector3(x2, 2.62, -0.15), Vector3(0.18, 0.2, 0.24), BLACK)
				kit.layer = "lumiere"
				kit.box(Vector3(x2, 2.6, -0.025), Vector3(0.12, 0.12, 0.01), LIGHT)
				kit.layer = "base"
		"rideau_scene":
			# Lambrequin en haut, rideau rouge relevé en drapé de chaque côté.
			kit.box(Vector3(0, h - 0.2, -0.3), Vector3(w, 0.4, 0.12), RED2)
			kit.box(Vector3(0, h - 0.42, -0.24), Vector3(w, 0.05, 0.02), GOLD)
			for sx in [-1.0, 1.0]:
				var x: float = sx * (w * 0.5 - 0.35)
				kit.lathe(Vector3(x, 0, -0.3), [Vector2(0.32, 0.0), Vector2(0.18, 0.9), Vector2(0.12, 1.2), Vector2(0.3, h - 0.4)], 8, RED)
				kit.tube(Vector3(x, 1.15, -0.3), Vector3(x, 1.15, -0.3), 0.15, 0.15, 6, GOLD)
				kit.box(Vector3(x, 1.15, -0.15), Vector3(0.3, 0.06, 0.04), GOLD)
		"decor_theatre":
			kit.box(Vector3(0, 0.03, -0.2), Vector3(w - 0.1, 0.06, 0.5), WOOD)
			if c == "foret":
				kit.box(Vector3(0, h * 0.5, -0.4), Vector3(w - 0.1, h, 0.05), Color("5c7f4a"))
				for i in 4:
					var x: float = -w * 0.5 + 0.4 + i * (w - 0.8) / 3.0
					kit.tube(Vector3(x, 0.05, -0.32), Vector3(x, h * 0.7, -0.32), 0.12, 0.08, 6, Color("5a3d26"))
					kit.blob(Vector3(x, h * 0.78, -0.3), Vector3(0.5, 0.45, 0.25), Color("2f5a2a"), Color("4f8a3a"), 0.2)
			else:
				kit.box(Vector3(0, h * 0.5, -0.4), Vector3(w - 0.1, h, 0.05), Color("b98f6a"))
				kit.box(Vector3(0, 0.45, -0.37), Vector3(w - 0.12, 0.9, 0.02), Color("7a2e2e"))
				kit.box(Vector3(-0.7, 1.4, -0.36), Vector3(0.7, 0.9, 0.02), Color("bcd3e0"))
				kit.box(Vector3(-0.7, 1.4, -0.355), Vector3(0.75, 0.04, 0.01), WHITE)
				kit.box(Vector3(0.8, 1.45, -0.36), Vector3(0.6, 0.45, 0.02), GOLD)
				kit.box(Vector3(0.3, 0.25, 0.1), Vector3(1.2, 0.5, 0.5), RED)
				kit.box(Vector3(0.3, 0.6, -0.1), Vector3(1.2, 0.4, 0.12), RED)
		"projecteurs_scene":
			kit.box(Vector3(0, 2.55, -0.44), Vector3(w - 0.2, 0.06, 0.06), STEEL)
			for i in 3:
				var x: float = -w * 0.5 + 0.35 + i * (w - 0.7) / 2.0
				kit.beam(Vector3(x, 2.5, -0.38), Vector3(x, 2.35, -0.05), 0.2, 0.22, BLACK)
				kit.layer = "lumiere"
				kit.box(Vector3(x, 2.33, -0.02), Vector3(0.14, 0.14, 0.01), LIGHT)
				kit.layer = "base"
		"poursuite":
			_trepied(kit, 1.2, DARK)
			kit.beam(Vector3(0, 1.35, -0.35), Vector3(0, 1.4, 0.4), 0.3, 0.3, BLACK)
			kit.layer = "lumiere"
			kit.box(Vector3(0, 1.4, 0.41), Vector3(0.2, 0.2, 0.01), LIGHT)
			kit.layer = "base"
		"pupitres":
			for x in [-0.5, 0.5]:
				_chaise(kit, Vector3(x, 0, 0.15), BLACK)
				kit.tube(Vector3(x, 0, -0.3), Vector3(x, 1.0, -0.3), 0.015, 0.015, 4, BLACK)
				kit.beam(Vector3(x, 1.0, -0.33), Vector3(x, 1.2, -0.27), 0.4, 0.02, BLACK)
				kit.box(Vector3(x, 1.1, -0.27), Vector3(0.3, 0.2, 0.005), WHITE)
		"podium_chef":
			kit.box(Vector3(0, 0.12, 0), Vector3(0.8, 0.24, 0.8), RED2)
			kit.tube(Vector3(0, 0.24, -0.25), Vector3(0, 1.1, -0.25), 0.02, 0.02, 4, BLACK)
			kit.beam(Vector3(0, 1.1, -0.3), Vector3(0, 1.25, -0.2), 0.5, 0.03, WOOD)
			kit.tube(Vector3(-0.35, 0.24, 0.3), Vector3(-0.35, 0.95, 0.3), 0.02, 0.02, 4, GOLD)
			kit.tube(Vector3(0.35, 0.24, 0.3), Vector3(0.35, 0.95, 0.3), 0.02, 0.02, 4, GOLD)
			kit.tube(Vector3(-0.35, 0.95, 0.3), Vector3(0.35, 0.95, 0.3), 0.02, 0.02, 4, GOLD)
		# --- Sièges -----------------------------------------------------------------------------
		"fauteuils":
			var n := 2 if c == "premium" else 3
			var col := LEATHER if c == "premium" else RED
			var step := w / float(n)
			for i in n:
				var x: float = -w * 0.5 + (i + 0.5) * step
				var sw := step - 0.16
				kit.box(Vector3(x, 0.42, 0.08 if c == "premium" else 0.05), Vector3(sw, 0.16, 0.7 if c == "premium" else 0.55), col)
				kit.box(Vector3(x, 0.8, -0.3), Vector3(sw, 0.8 if c == "premium" else 0.75, 0.16), col)
				if c == "premium":
					kit.box(Vector3(x, 0.32, 0.5), Vector3(sw, 0.24, 0.2), col)
				else:
					kit.box(Vector3(x, 1.12, -0.3), Vector3(sw * 0.7, 0.04, 0.17), GOLD)
			for j in n + 1:
				var x2: float = -w * 0.5 + j * step + (0.06 if j == 0 else (-0.06 if j == n else 0.0))
				kit.box(Vector3(x2, 0.36, -0.05), Vector3(0.1, 0.62, 0.7), DARK if c != "premium" else BLACK)
		"gradins":
			kit.box(Vector3(0, 0.42, 0.0), Vector3(w - 0.04, 0.06, 0.5), WOOD2)
			for x in [-w * 0.5 + 0.2, 0.0, w * 0.5 - 0.2]:
				kit.box(Vector3(x, 0.2, 0.0), Vector3(0.08, 0.4, 0.4), WOOD)
		"table_cabaret":
			kit.lathe(Vector3(0, 0, 0), [Vector2(0.25, 0.0), Vector2(0.04, 0.05), Vector2(0.04, 0.72), Vector2(0.4, 0.74), Vector2(0.4, 0.78)], 10, BLACK)
			kit.box(Vector3(0, 0.79, 0), Vector3(0.7, 0.01, 0.7), RED)
			kit.layer = "lumiere"
			kit.lathe(Vector3(0.12, 0.79, 0.05), [Vector2(0.04, 0.0), Vector2(0.03, 0.1)], 6, LIGHT)
			kit.layer = "base"
			for p in [Vector3(-0.55, 0, 0.35), Vector3(0.55, 0, 0.35)]:
				_chaise(kit, p, RED2, PI)
			_chaise(kit, Vector3(0, 0, -0.6), RED2)
		"barriere":
			for x in [-0.8, 0.8]:
				kit.box(Vector3(x, 0.03, 0.15), Vector3(0.12, 0.06, 0.8), STEEL)
				kit.beam(Vector3(x, 0.05, 0.45), Vector3(x, 1.1, -0.05), 0.08, 0.08, STEEL)
			kit.box(Vector3(0, 1.1, -0.05), Vector3(w - 0.05, 0.06, 0.08), STEEL)
			kit.box(Vector3(0, 0.6, -0.05), Vector3(w - 0.05, 0.9, 0.02), GREY)
		# --- Cinéma -----------------------------------------------------------------------------
		"ecran":
			kit.box(Vector3(0, 1.62, -0.47), Vector3(w - 0.05, 2.5, 0.04), BLACK)
			kit.layer = "lumiere"
			kit.box(Vector3(0, 1.65, -0.445), Vector3(w - 0.35, 2.1, 0.01), SCREEN)
			kit.box(Vector3(-w * 0.15, 1.4, -0.44), Vector3(w * 0.3, 0.7, 0.005), Color("e9c46a"))
			kit.box(Vector3(w * 0.2, 1.9, -0.44), Vector3(w * 0.25, 0.5, 0.005), Color("5a8ac0"))
			kit.layer = "base"
			kit.box(Vector3(0, 0.3, -0.38), Vector3(w, 0.6, 0.2), RED2)
		"projecteur_numerique":
			kit.box(Vector3(0, 0.45, 0), Vector3(0.8, 0.9, 0.7), DARK)
			kit.box(Vector3(0, 1.15, 0), Vector3(0.7, 0.5, 0.75), Color("3a3d42"))
			kit.tube(Vector3(0, 1.15, 0.38), Vector3(0, 1.15, 0.48), 0.09, 0.08, 8, BLACK)
			kit.layer = "lumiere"
			kit.box(Vector3(0, 1.15, 0.485), Vector3(0.1, 0.1, 0.01), LIGHT)
			kit.layer = "base"
		"enceinte_murale":
			kit.box(Vector3(0, 2.25, -0.38), Vector3(0.45, 0.6, 0.22), BLACK)
			kit.lathe(Vector3(0, 2.15, -0.26), [Vector2(0.12, 0.0), Vector2(0.12, 0.01)], 10, GREY)
		"comptoir_confiserie":
			kit.box(Vector3(0, 0.55, 0.05), Vector3(w - 0.1, 1.1, 0.6), RED)
			kit.box(Vector3(0, 1.12, 0.05), Vector3(w - 0.05, 0.05, 0.7), WHITE)
			kit.layer = "verre"
			kit.box(Vector3(0.6, 1.35, 0.1), Vector3(1.2, 0.4, 0.45), Color(0.8, 0.9, 1.0))
			kit.layer = "base"
			for i in 6:
				kit.box(Vector3(0.15 + (i % 3) * 0.3, 1.2 + (i / 3) * 0.15, 0.05), Vector3(0.22, 0.1, 0.25), [Color("e9c46a"), Color("e76f51"), Color("2a9d8f")][i % 3])
			kit.box(Vector3(-0.8, 1.6, -0.42), Vector3(1.1, 0.6, 0.04), DARK)
			kit.layer = "lumiere"
			kit.box(Vector3(-0.8, 1.6, -0.395), Vector3(1.0, 0.5, 0.01), Color("f4a261"))
			kit.layer = "base"
		"machine_popcorn":
			kit.box(Vector3(0, 0.45, 0), Vector3(0.6, 0.9, 0.5), RED)
			kit.layer = "verre"
			kit.box(Vector3(0, 1.2, 0), Vector3(0.55, 0.6, 0.45), Color(0.95, 0.95, 1.0))
			kit.layer = "base"
			kit.box(Vector3(0, 1.0, 0), Vector3(0.5, 0.16, 0.4), Color("f6e3a1"))
			kit.box(Vector3(0, 1.54, 0), Vector3(0.62, 0.08, 0.52), RED)
			kit.box(Vector3(0, 1.62, 0), Vector3(0.4, 0.08, 0.06), GOLD)
		"borne_billets":
			kit.box(Vector3(0, 0.6, -0.1), Vector3(0.5, 1.2, 0.4), DARK)
			kit.beam(Vector3(0, 1.2, -0.25), Vector3(0, 1.5, -0.1), 0.5, 0.08, DARK)
			kit.layer = "lumiere"
			kit.box(Vector3(0, 1.36, -0.13), Vector3(0.38, 0.26, 0.01), Color("7ad0f0"))
			kit.layer = "base"
		"affiche_lumineuse":
			kit.box(Vector3(0, 1.3, -0.45), Vector3(0.8, 1.15, 0.08), GREY)
			kit.layer = "lumiere"
			kit.box(Vector3(0, 1.3, -0.405), Vector3(0.7, 1.05, 0.01), Color("f1e0b0"))
			kit.box(Vector3(0, 1.45, -0.4), Vector3(0.5, 0.45, 0.005), Color("1d3557"))
			kit.box(Vector3(0, 0.98, -0.4), Vector3(0.55, 0.12, 0.005), RED)
			kit.layer = "base"
		# --- Musique et sono --------------------------------------------------------------------
		"console_son":
			kit.box(Vector3(0, 0.4, 0), Vector3(w - 0.1, 0.8, 0.7), DARK)
			kit.beam(Vector3(0, 0.82, 0.3), Vector3(0, 0.98, -0.3), w - 0.15, 0.06, Color("3a3d42"))
			for i in 16:
				kit.box(Vector3(-0.8 + i * 0.107, 0.93, -0.05), Vector3(0.03, 0.03, 0.25), STEEL)
			kit.layer = "lumiere"
			kit.box(Vector3(-0.45, 1.12, -0.32), Vector3(0.5, 0.3, 0.01), Color("7ad0f0"))
			kit.box(Vector3(0.45, 1.12, -0.32), Vector3(0.5, 0.3, 0.01), Color("e9c46a"))
			kit.layer = "base"
		"colonne_son":
			_trepied(kit, 1.2, BLACK)
			for i in 4:
				kit.beam(Vector3(0, 1.3 + i * 0.22, -0.2 + i * 0.03), Vector3(0, 1.3 + i * 0.22, 0.25 - i * 0.02), 0.65, 0.2, BLACK)
				kit.box(Vector3(0, 1.3 + i * 0.22, 0.26 - i * 0.02), Vector3(0.55, 0.12, 0.01), GREY)
		"amplis":
			kit.box(Vector3(-0.5, 0.45, -0.15), Vector3(0.75, 0.9, 0.45), BLACK)
			kit.box(Vector3(-0.5, 0.45, 0.085), Vector3(0.65, 0.6, 0.01), GREY)
			kit.box(Vector3(-0.5, 1.0, -0.15), Vector3(0.75, 0.2, 0.45), Color("3a3d42"))
			kit.box(Vector3(0.5, 0.4, -0.15), Vector3(0.7, 0.8, 0.45), BLACK)
			kit.box(Vector3(0.5, 0.4, 0.085), Vector3(0.6, 0.55, 0.01), Color("4a3d33"))
			kit.box(Vector3(0.5, 0.86, -0.15), Vector3(0.7, 0.12, 0.45), GOLD)
			kit.beam(Vector3(0.95, 0.0, 0.2), Vector3(0.9, 1.0, 0.0), 0.35, 0.06, Color("b5402a"))
		"micro_pied":
			kit.lathe(Vector3.ZERO, [Vector2(0.2, 0.0), Vector2(0.2, 0.02)], 8, BLACK)
			kit.tube(Vector3(0, 0.02, 0), Vector3(0, 1.4, 0), 0.012, 0.012, 4, BLACK)
			kit.tube(Vector3(0, 1.4, 0), Vector3(0, 1.5, 0.15), 0.01, 0.01, 4, BLACK)
			kit.tube(Vector3(0, 1.5, 0.15), Vector3(0, 1.52, 0.22), 0.025, 0.03, 6, STEEL)
		"retours":
			for x in [-0.5, 0.5]:
				kit.beam(Vector3(x, 0.0, -0.25), Vector3(x, 0.35, 0.05), 0.7, 0.3, BLACK)
		"platines":
			kit.box(Vector3(0, 0.45, 0), Vector3(w - 0.1, 0.9, 0.6), BLACK)
			kit.box(Vector3(0, 0.92, 0), Vector3(w - 0.1, 0.04, 0.6), DARK)
			for x in [-0.55, 0.55]:
				kit.lathe(Vector3(x, 0.94, 0.0), [Vector2(0.17, 0.0), Vector2(0.17, 0.01)], 12, BLACK)
				kit.lathe(Vector3(x, 0.951, 0.0), [Vector2(0.04, 0.0), Vector2(0.04, 0.005)], 8, RED)
			kit.layer = "lumiere"
			kit.box(Vector3(0, 0.6, 0.305), Vector3(w - 0.3, 0.06, 0.01), Color("c77dff"))
			kit.layer = "base"
			kit.box(Vector3(0, 1.05, -0.2), Vector3(0.35, 0.22, 0.25), STEEL)
		"contrebasse":
			kit.lathe(Vector3(0, 0.05, 0), [Vector2(0.02, 0.0), Vector2(0.3, 0.1), Vector2(0.26, 0.5), Vector2(0.18, 0.62), Vector2(0.24, 0.8), Vector2(0.15, 1.05), Vector2(0.03, 1.1)], 10,
				Color("8a4b22"))
			kit.beam(Vector3(0, 1.1, 0), Vector3(0, 1.75, 0.0), 0.06, 0.05, BLACK)
			kit.tube(Vector3(0, 0, 0), Vector3(0, 0.08, 0), 0.01, 0.01, 4, STEEL)
		"panneaux_acoustiques":
			for i in 2:
				var x: float = -0.5 + i
				kit.box(Vector3(x, 1.5, -0.45), Vector3(0.9, 1.4, 0.08), Color("4a5560") if i == 0 else Color("6b4a5a"))
				for j in 3:
					kit.box(Vector3(x, 1.0 + j * 0.45, -0.405), Vector3(0.85, 0.05, 0.01), BLACK)
		"boule_facettes":
			kit.tube(Vector3(0, 3.0, 0), Vector3(0, CEIL - 0.1, 0), 0.01, 0.01, 3, STEEL)
			kit.layer = "lumiere"
			kit.lathe(Vector3(0, CEIL - 0.45, 0), [Vector2(0.02, 0.0), Vector2(0.2, 0.08), Vector2(0.25, 0.18), Vector2(0.2, 0.28), Vector2(0.02, 0.36)], 10, Color("d8dde2"))
			kit.layer = "base"
		# --- Tournage ---------------------------------------------------------------------------
		"camera_studio":
			_trepied(kit, 1.1, BLACK)
			kit.box(Vector3(0, 1.3, 0), Vector3(0.26, 0.3, 0.6), DARK)
			kit.tube(Vector3(0, 1.3, 0.3), Vector3(0, 1.3, 0.48), 0.08, 0.1, 8, BLACK)
			kit.box(Vector3(0.2, 1.38, -0.1), Vector3(0.06, 0.18, 0.24), DARK)
			kit.layer = "lumiere"
			kit.box(Vector3(0.232, 1.38, -0.1), Vector3(0.005, 0.14, 0.2), Color("7ad0f0"))
			kit.layer = "base"
			kit.lathe(Vector3(0, 1.45, -0.05), [Vector2(0.12, 0.0), Vector2(0.12, 0.05)], 10, BLACK)
		"travelling":
			for z in [-0.3, 0.3]:
				kit.box(Vector3(0, 0.04, z), Vector3(w - 0.05, 0.05, 0.05), STEEL)
			for i in 6:
				kit.box(Vector3(-w * 0.5 + 0.25 + i * (w - 0.5) / 5.0, 0.01, 0), Vector3(0.08, 0.02, 0.75), WOOD)
			kit.box(Vector3(-0.6, 0.2, 0), Vector3(0.8, 0.2, 0.7), GREY)
			kit.tube(Vector3(-0.6, 0.3, 0), Vector3(-0.6, 1.1, 0), 0.05, 0.05, 6, BLACK)
			kit.box(Vector3(-0.6, 1.25, 0.1), Vector3(0.24, 0.28, 0.5), DARK)
			kit.tube(Vector3(-0.6, 1.25, 0.35), Vector3(-0.6, 1.25, 0.48), 0.07, 0.08, 8, BLACK)
			_chaise(kit, Vector3(-0.6, 0.3, -0.25), BLACK)
		"grue":
			kit.box(Vector3(0, 0.15, 0), Vector3(1.4, 0.3, 1.4), GREY)
			kit.tube(Vector3(0, 0.3, 0), Vector3(0, 1.4, 0), 0.08, 0.08, 6, DARK)
			kit.beam(Vector3(-0.5, 1.45, -0.6), Vector3(0.6, 2.5, 0.8), 0.12, 0.12, STEEL)
			kit.box(Vector3(-0.55, 1.4, -0.65), Vector3(0.3, 0.3, 0.3), BLACK)
			kit.box(Vector3(0.62, 2.35, 0.82), Vector3(0.22, 0.24, 0.45), DARK)
			kit.tube(Vector3(0.62, 2.35, 1.05), Vector3(0.62, 2.35, 1.15), 0.06, 0.07, 8, BLACK)
		"fresnel":
			_trepied(kit, 1.7, STEEL)
			kit.tube(Vector3(0, 1.85, -0.18), Vector3(0, 1.85, 0.18), 0.17, 0.17, 10, BLACK)
			kit.layer = "lumiere"
			kit.lathe(Vector3(0, 1.85, 0.19), [Vector2(0.14, 0.0), Vector2(0.14, 0.01)], 10, LIGHT)
			kit.layer = "base"
			for sx in [-1.0, 1.0]:
				kit.beam(Vector3(sx * 0.17, 1.85, 0.2), Vector3(sx * 0.3, 1.85, 0.35), 0.01, 0.3, BLACK)
		"softbox":
			_trepied(kit, 1.4, STEEL)
			kit.lathe(Vector3(0, 1.6, -0.15), [Vector2(0.06, 0.0), Vector2(0.4, 0.35)], 4, BLACK, true, false, Callable(), PI * 0.25)
			kit.layer = "lumiere"
			kit.box(Vector3(0, 1.6, 0.21), Vector3(0.52, 0.52, 0.01), WHITE)
			kit.layer = "base"
		"grill":
			for x in [-0.8, 0.8]:
				kit.box(Vector3(x, CEIL - 0.08, 0), Vector3(0.05, 0.05, d - 0.2), STEEL)
			for z in [-0.6, 0.0, 0.6]:
				kit.box(Vector3(0, CEIL - 0.08, z), Vector3(w - 0.2, 0.04, 0.04), STEEL)
				for x2 in [-0.5, 0.5]:
					kit.box(Vector3(x2, CEIL - 0.28, z), Vector3(0.18, 0.24, 0.2), BLACK)
					kit.layer = "lumiere"
					kit.box(Vector3(x2, CEIL - 0.405, z), Vector3(0.12, 0.01, 0.12), LIGHT)
					kit.layer = "base"
		"perche":
			kit.lathe(Vector3.ZERO, [Vector2(0.25, 0.0), Vector2(0.25, 0.03)], 6, DARK)
			kit.tube(Vector3(0, 0.03, 0), Vector3(0, 1.8, 0), 0.02, 0.02, 4, STEEL)
			kit.tube(Vector3(0, 1.8, 0), Vector3(0, 2.1, 0.45), 0.015, 0.015, 4, STEEL)
			kit.tube(Vector3(0, 2.1, 0.45), Vector3(0, 2.0, 0.55), 0.05, 0.05, 6, Color("8a8f94"))
		"chaise_realisateur":
			for sx in [-0.25, 0.25]:
				kit.beam(Vector3(sx, 0, -0.2), Vector3(sx, 0.75, 0.2), 0.04, 0.04, WOOD2)
				kit.beam(Vector3(sx, 0, 0.2), Vector3(sx, 0.75, -0.2), 0.04, 0.04, WOOD2)
			kit.box(Vector3(0, 0.75, 0), Vector3(0.52, 0.03, 0.42), BLACK)
			kit.box(Vector3(0, 1.05, -0.22), Vector3(0.52, 0.28, 0.03), BLACK)
			kit.box(Vector3(0, 1.05, -0.24), Vector3(0.34, 0.08, 0.005), WHITE)
			for sx2 in [-0.25, 0.25]:
				kit.tube(Vector3(sx2, 0.75, -0.2), Vector3(sx2, 1.2, -0.2), 0.02, 0.02, 4, WOOD2)
		"moniteurs":
			kit.box(Vector3(0, 0.45, 0), Vector3(0.6, 0.9, 0.5), DARK)
			kit.box(Vector3(0, 1.2, -0.05), Vector3(0.7, 0.45, 0.12), BLACK)
			kit.layer = "lumiere"
			kit.box(Vector3(0, 1.2, 0.015), Vector3(0.62, 0.36, 0.01), Color("5a8ac0"))
			kit.layer = "base"
		"fond_vert":
			kit.box(Vector3(0, h * 0.5, -0.45), Vector3(w, h, 0.05), GREEN)
			# Raccord arrondi au sol (cyclo).
			kit.beam(Vector3(0, 0.0, -0.05), Vector3(0, 0.35, -0.43), w, 0.03, GREEN)
			kit.box(Vector3(0, 0.005, 0.2), Vector3(w, 0.01, 0.5), GREEN)
		"decor_chambre":
			kit.box(Vector3(0, 0.02, 0), Vector3(w, 0.04, d), Color("9b7b5b"))
			kit.box(Vector3(0, h * 0.5, -d * 0.5 + 0.05), Vector3(w, h, 0.1), Color("d9c7a3"))
			kit.box(Vector3(-w * 0.5 + 0.05, h * 0.5, 0), Vector3(0.1, h, d), Color("c9b58f"))
			kit.box(Vector3(w * 0.5 - 0.05, h * 0.5, 0), Vector3(0.1, h, d), Color("c9b58f"))
			kit.box(Vector3(-0.5, 0.25, -0.5), Vector3(1.4, 0.5, 1.8), Color("e9e1d3"))
			kit.box(Vector3(-0.5, 0.55, -1.25), Vector3(1.4, 0.6, 0.2), Color("6b4a2f"))
			kit.box(Vector3(0.9, 0.35, 0.6), Vector3(0.9, 0.7, 0.8), Color("2a6f97"))
			kit.box(Vector3(0.0, 1.6, -1.39), Vector3(0.8, 0.6, 0.02), Color("bcd3e0"))
			kit.lathe(Vector3(1.1, 0, -1.1), [Vector2(0.12, 0.0), Vector2(0.03, 0.05), Vector2(0.03, 1.4), Vector2(0.18, 1.45), Vector2(0.12, 1.7)], 6, CREAM)
		"decor_rue":
			kit.box(Vector3(0, h * 0.5, -0.4), Vector3(w, h, 0.1), Color("b85c38"))
			for x in [-1.0, 0.0, 1.0]:
				kit.box(Vector3(x, 1.9, -0.34), Vector3(0.55, 0.8, 0.02), Color("324a5f"))
				kit.box(Vector3(x, 1.48, -0.3), Vector3(0.65, 0.05, 0.1), WHITE)
			kit.box(Vector3(-0.5, 0.65, -0.34), Vector3(0.9, 1.3, 0.02), Color("324a5f"))
			kit.box(Vector3(0.8, 0.55, -0.34), Vector3(0.7, 1.1, 0.03), WOOD)
			kit.box(Vector3(0, 1.38, -0.2), Vector3(w, 0.06, 0.4), Color("1d3557"))
			for i in 3:
				kit.beam(Vector3(-w * 0.5 + 0.2, 0.05, -0.1 - i * 0.05), Vector3(-w * 0.5 + 0.2, 2.6, -0.1 - i * 0.05), 0.08, 0.08, WOOD2)
		"decor_vaisseau":
			kit.box(Vector3(0, 0.05, 0), Vector3(w, 0.1, d), Color("4f5d75"))
			kit.beam(Vector3(0, 0.1, -0.3), Vector3(0, 0.9, -0.9), w - 0.2, 0.1, Color("3a4456"))
			kit.layer = "lumiere"
			for i in 8:
				kit.box(Vector3(-1.1 + i * 0.32, 0.72, -0.6), Vector3(0.12, 0.02, 0.08), [Color("2ec4f1"), Color("e76f51"), Color("e9c46a")][i % 3])
			kit.box(Vector3(0, 1.7, -0.95), Vector3(w - 0.4, 0.9, 0.02), Color("0b1d33"))
			kit.layer = "base"
			kit.box(Vector3(0, 1.7, -0.98), Vector3(w - 0.2, 1.1, 0.05), Color("8fa3b3"))
			for x in [-0.6, 0.6]:
				kit.box(Vector3(x, 0.3, 0.35), Vector3(0.5, 0.4, 0.5), WHITE)
				kit.box(Vector3(x, 0.8, 0.6), Vector3(0.5, 0.7, 0.1), WHITE)
		"decor_remparts":
			kit.box(Vector3(0, h * 0.42, -0.3), Vector3(w, h * 0.84, 0.35), Color("9c9284"))
			for i in 4:
				kit.box(Vector3(-w * 0.5 + 0.35 + i * (w - 0.7) / 3.0, h * 0.92, -0.3), Vector3(0.45, h * 0.16, 0.35), Color("8a8072"))
			kit.box(Vector3(0, 0.9, -0.12), Vector3(0.9, 1.8, 0.02), Color("3b2a1f"))
			kit.box(Vector3(0, 1.8, -0.12), Vector3(0.9, 0.1, 0.03), Color("6b6158"))
			for x in [-1.1, 1.1]:
				kit.box(Vector3(x, 1.6, -0.11), Vector3(0.12, 0.4, 0.02), BLACK)
		"decor_saloon":
			kit.box(Vector3(0, 0.55, 0.2), Vector3(w - 0.2, 1.1, 0.6), Color("7a4a2a"))
			kit.box(Vector3(0, 1.12, 0.2), Vector3(w - 0.1, 0.05, 0.7), Color("4a2e1a"))
			kit.box(Vector3(0, 1.4, -0.85), Vector3(w - 0.2, 1.6, 0.1), Color("6b4a2f"))
			for i in 6:
				kit.lathe(Vector3(-1.0 + i * 0.4, 1.15, 0.2), [Vector2(0.04, 0.0), Vector2(0.04, 0.18), Vector2(0.015, 0.26)], 6, Color("8a6d2a") if i % 2 == 0 else Color("3e5c3a"))
			kit.box(Vector3(0, 1.9, -0.78), Vector3(1.2, 0.6, 0.02), Color("c9a777"))
			for x in [-0.8, 0.8]:
				kit.lathe(Vector3(x, 0, 0.75), [Vector2(0.16, 0.0), Vector2(0.03, 0.05), Vector2(0.03, 0.7), Vector2(0.18, 0.72)], 8, WOOD)
		"cuve":
			kit.box(Vector3(0, 0.5, -d * 0.5 + 0.1), Vector3(w, 1.0, 0.2), GREY)
			kit.box(Vector3(0, 0.5, d * 0.5 - 0.1), Vector3(w, 1.0, 0.2), GREY)
			kit.box(Vector3(-w * 0.5 + 0.1, 0.5, 0), Vector3(0.2, 1.0, d - 0.4), GREY)
			kit.box(Vector3(w * 0.5 - 0.1, 0.5, 0), Vector3(0.2, 1.0, d - 0.4), GREY)
			kit.box(Vector3(0, 0.4, 0), Vector3(w - 0.4, 0.8, d - 0.4), Color("1f5f7a"))
			kit.beam(Vector3(-0.6, 0.85, 0.3), Vector3(0.6, 0.95, -0.2), 0.4, 0.15, WOOD)
		# --- Coulisses --------------------------------------------------------------------------
		"maquillage":
			kit.box(Vector3(0, 0.75, -0.2), Vector3(w - 0.1, 0.05, 0.55), WHITE)
			for x in [-0.85, 0.85]:
				kit.box(Vector3(x, 0.37, -0.2), Vector3(0.12, 0.74, 0.5), WHITE)
			kit.box(Vector3(0, 1.4, -0.46), Vector3(w - 0.2, 1.0, 0.04), Color("dde6ec"))
			kit.layer = "lumiere"
			for i in 7:
				var x: float = -0.8 + i * 0.267
				kit.lathe(Vector3(x, 1.92, -0.43), [Vector2(0.04, 0.0), Vector2(0.04, 0.05)], 6, LIGHT)
			for j in 3:
				kit.lathe(Vector3(-0.85, 1.05 + j * 0.28, -0.43), [Vector2(0.04, 0.0), Vector2(0.04, 0.05)], 6, LIGHT)
				kit.lathe(Vector3(0.85, 1.05 + j * 0.28, -0.43), [Vector2(0.04, 0.0), Vector2(0.04, 0.05)], 6, LIGHT)
			kit.layer = "base"
			for x2 in [-0.45, 0.45]:
				_chaise(kit, Vector3(x2, 0, 0.45), BLACK, PI)
		"portant_costumes":
			for x in [-0.9, 0.9]:
				kit.tube(Vector3(x, 0, 0), Vector3(x, 1.7, 0), 0.02, 0.02, 4, STEEL)
				kit.box(Vector3(x, 0.03, 0), Vector3(0.08, 0.06, 0.5), STEEL)
			kit.tube(Vector3(-0.9, 1.7, 0), Vector3(0.9, 1.7, 0), 0.015, 0.015, 4, STEEL)
			var cols := [RED, Color("1d3557"), GOLD, Color("2a9d8f"), Color("6b4a5a"), WHITE, Color("e76f51")]
			for i in 7:
				var x2: float = -0.75 + i * 0.25
				kit.lathe(Vector3(x2, 0.55, 0), [Vector2(0.14, 0.0), Vector2(0.11, 0.6), Vector2(0.09, 1.1)], 5, cols[i % cols.size()])
		"mannequin":
			kit.lathe(Vector3.ZERO, [Vector2(0.2, 0.0), Vector2(0.2, 0.03), Vector2(0.02, 0.05), Vector2(0.02, 0.85)], 8, WOOD)
			kit.lathe(Vector3(0, 0.85, 0), [Vector2(0.12, 0.0), Vector2(0.17, 0.15), Vector2(0.14, 0.4), Vector2(0.19, 0.62), Vector2(0.06, 0.75)], 8, CREAM)
			kit.lathe(Vector3(0, 0.8, 0), [Vector2(0.2, 0.0), Vector2(0.15, 0.35)], 8, RED)
		"table_coupe":
			for sx in [-1.3, 1.3]:
				for sz in [-0.8, 0.8]:
					kit.box(Vector3(sx, 0.45, sz), Vector3(0.08, 0.9, 0.08), WOOD)
			kit.box(Vector3(0, 0.92, 0), Vector3(w - 0.1, 0.05, d - 0.2), WOOD2)
			kit.box(Vector3(-0.3, 0.95, 0.1), Vector3(1.4, 0.01, 0.9), Color("9c2a4a"))
			kit.box(Vector3(0.9, 0.95, -0.3), Vector3(0.6, 0.01, 0.5), Color("e9e1d3"))
		"banc_montage":
			kit.box(Vector3(0, 0.74, -0.15), Vector3(w - 0.1, 0.05, 0.65), DARK)
			for x in [-0.9, 0.9]:
				kit.box(Vector3(x, 0.37, -0.15), Vector3(0.06, 0.74, 0.6), DARK)
			for i in 3:
				var x2: float = -0.6 + i * 0.6
				kit.box(Vector3(x2, 1.08, -0.35), Vector3(0.56, 0.36, 0.04), BLACK)
				kit.layer = "lumiere"
				kit.box(Vector3(x2, 1.08, -0.325), Vector3(0.5, 0.3, 0.01), [Color("5a8ac0"), Color("2a9d8f"), Color("e9c46a")][i])
				kit.layer = "base"
			kit.box(Vector3(0, 0.78, 0.0), Vector3(0.9, 0.03, 0.25), Color("3a3d42"))
			_chaise(kit, Vector3(0, 0, 0.28), BLACK, PI)
		"etabli":
			kit.box(Vector3(0, 0.9, -0.15), Vector3(w - 0.1, 0.08, 0.65), WOOD2)
			for x in [-0.85, 0.85]:
				kit.box(Vector3(x, 0.45, -0.15), Vector3(0.1, 0.9, 0.6), WOOD)
			kit.box(Vector3(0, 1.4, -0.46), Vector3(w - 0.2, 0.9, 0.03), Color("8a6d4a"))
			for i in 5:
				kit.box(Vector3(-0.7 + i * 0.35, 1.45, -0.42), Vector3(0.05, 0.3, 0.03), STEEL)
			kit.box(Vector3(-0.4, 0.98, 0.0), Vector3(0.5, 0.06, 0.25), Color("2a9d8f"))
			kit.lathe(Vector3(0.5, 0.94, -0.05), [Vector2(0.1, 0.0), Vector2(0.1, 0.16)], 8, Color("e76f51"))
		"flight_cases":
			kit.box(Vector3(0, 0.3, 0), Vector3(0.85, 0.6, 0.7), BLACK)
			kit.box(Vector3(0, 0.85, 0), Vector3(0.75, 0.5, 0.6), BLACK)
			for y in [0.02, 0.58, 0.62, 1.08]:
				kit.box(Vector3(0, y, 0), Vector3(0.87 if y < 0.6 else 0.77, 0.03, 0.72 if y < 0.6 else 0.62), STEEL)
		# --- Foyer ------------------------------------------------------------------------------
		"bar_foyer":
			kit.box(Vector3(0, 0.53, 0.0), Vector3(w - 0.1, 1.06, 0.6), WOOD)
			kit.box(Vector3(0, 1.09, 0.0), Vector3(w - 0.05, 0.06, 0.7), Color("e8e2d6"))
			kit.box(Vector3(0, 0.3, 0.31), Vector3(w - 0.2, 0.04, 0.02), GOLD)
			kit.box(Vector3(0, 1.6, -0.42), Vector3(w - 0.2, 0.9, 0.12), WOOD)
			for i in 9:
				kit.lathe(Vector3(-1.2 + i * 0.3, 1.38, -0.38), [Vector2(0.04, 0.0), Vector2(0.04, 0.2), Vector2(0.015, 0.28)], 6, [Color("3e5c3a"), Color("8a6d2a"), Color("6d151b")][i % 3])
			for j in 4:
				kit.lathe(Vector3(-0.4 + j * 0.25, 1.12, 0.1), [Vector2(0.035, 0.0), Vector2(0.01, 0.06), Vector2(0.04, 0.14)], 6, Color(0.9, 0.95, 1.0))
		"guichet":
			kit.box(Vector3(0, 0.55, 0.0), Vector3(w - 0.1, 1.1, 0.6), RED2)
			kit.box(Vector3(0, 1.12, 0.0), Vector3(w - 0.05, 0.05, 0.7), WOOD)
			for x in [-0.9, 0.9]:
				kit.box(Vector3(x, 1.65, -0.05), Vector3(0.1, 1.1, 0.5), WOOD)
			kit.box(Vector3(0, 2.15, -0.05), Vector3(w - 0.05, 0.12, 0.55), WOOD)
			kit.box(Vector3(0, 2.1, 0.23), Vector3(1.2, 0.18, 0.02), GOLD)
			kit.layer = "verre"
			kit.box(Vector3(0, 1.7, 0.1), Vector3(w - 0.3, 0.8, 0.02), Color(0.85, 0.92, 1.0))
			kit.layer = "base"
		"affiche_spectacle":
			kit.box(Vector3(0, 1.3, -0.47), Vector3(0.75, 1.05, 0.04), GOLD)
			kit.box(Vector3(0, 1.3, -0.445), Vector3(0.65, 0.95, 0.01), [Color("1d3557"), Color("8e1e24"), Color("2a9d8f")][absi(hash(String(e.id))) % 3])
			kit.box(Vector3(0, 1.55, -0.44), Vector3(0.45, 0.12, 0.005), CREAM)
			kit.box(Vector3(0, 1.15, -0.44), Vector3(0.3, 0.35, 0.005), Color("e9c46a"))
		_:
			kit.box(Vector3(0, h * 0.5, 0), Vector3(w * 0.8, h, d * 0.8), GREY)


## Trépied (caméras, projecteurs) : trois pieds et une colonne jusqu'à top.
static func _trepied(kit: LpKit, top: float, col: Color) -> void:
	for i in 3:
		var a := i * TAU / 3.0
		kit.tube(Vector3(cos(a) * 0.35, 0, sin(a) * 0.35), Vector3(0, top * 0.55, 0), 0.015, 0.015, 3, col)
	kit.tube(Vector3(0, top * 0.5, 0), Vector3(0, top, 0), 0.025, 0.025, 4, col)


## Chaise simple, assise vers +Z (tournée de ang).
static func _chaise(kit: LpKit, p: Vector3, col: Color, ang := 0.0) -> void:
	var b := Basis(Vector3.UP, ang)
	var o := p
	kit.box(o + b * Vector3(0, 0.45, 0), Vector3(0.42, 0.05, 0.42), col)
	for sx in [-0.17, 0.17]:
		for sz in [-0.17, 0.17]:
			kit.box(o + b * Vector3(sx, 0.22, sz), Vector3(0.04, 0.44, 0.04), col)
	var back := o + b * Vector3(0, 0.72, -0.19)
	kit.box(back, Vector3(0.42, 0.5, 0.04) if absf(sin(ang)) < 0.5 else Vector3(0.04, 0.5, 0.42), col)
