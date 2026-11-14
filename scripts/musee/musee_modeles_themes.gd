class_name MuseeModelesThemes
extends RefCounted
## Modèles des collections à thème du musée (transports, automobile, air et
## espace, marine, cinéma, sport, mode, musique, jouets, préhistoire, bande
## dessinée, gastronomie, horlogerie), en low-poly avec LpKit. Appelés par
## MuseeModeles.build pour les clés qu'il ne connaît pas.
##
## Repère : centre de l'emprise, w sur X, d sur Z ; un objet « mur » a le dos
## en Z = -d/2 ; un objet accroché (couche mur) se plaque en Z ≈ -0.46.

const GOLD := MuseeModeles.GOLD
const DARK := MuseeModeles.DARK
const WOOD := MuseeModeles.WOOD
const WOOD2 := MuseeModeles.WOOD2
const RED := MuseeModeles.RED
const WHITE := MuseeModeles.WHITE
const GLASS := MuseeModeles.GLASS
const BRONZE := MuseeModeles.BRONZE
const BONE := MuseeModeles.BONE
const LIGHT := MuseeModeles.LIGHT
const CEIL := MuseeModeles.CEIL
const STEEL := Color("9aa3ab")
const COPPER := Color("b87333")
const BLACK := Color("1c1c1c")
const SKIN := Color("d8b08c")


## Construit l'objet ; false si la clé est inconnue.
static func build(kit: LpKit, e: Dictionary) -> bool:
	var w := float(e.w)
	var d := float(e.d)
	var k := String(e.k)
	var c := String(e.get("c", ""))
	match k:
		# --- Horlogerie --------------------------------------------------------------------------
		"comtoise":
			kit.box(Vector3(0, 0.15, -0.25), Vector3(0.5, 0.3, 0.35), WOOD)
			kit.lathe(Vector3(0, 0.3, -0.25), [Vector2(0.18, 0.0), Vector2(0.24, 0.9), Vector2(0.2, 1.35)], 8, WOOD2)
			kit.box(Vector3(0, 1.85, -0.25), Vector3(0.52, 0.6, 0.32), WOOD)
			kit.lathe(Vector3(0, 1.85, -0.08), [Vector2(0.2, 0.0), Vector2(0.2, 0.02)], 12, WHITE)
			kit.box(Vector3(0, 1.95, -0.06), Vector3(0.02, 0.15, 0.01), BLACK)
			kit.box(Vector3(0.04, 1.85, -0.06), Vector3(0.1, 0.02, 0.01), BLACK)
			kit.blob(Vector3(0, 1.0, -0.06), Vector3(0.1, 0.1, 0.02), GOLD, GOLD.lightened(0.2), 0.0, 0)
			kit.box(Vector3(0, 1.3, -0.07), Vector3(0.02, 0.6, 0.01), GOLD)
			kit.blob(Vector3(0, 2.2, -0.25), Vector3(0.18, 0.08, 0.16), WOOD, WOOD2, 0.05, 0)
		"coucou":
			kit.box(Vector3(0, 1.75, -0.4), Vector3(0.4, 0.42, 0.18), WOOD)
			kit.beam(Vector3(-0.28, 1.92, -0.4), Vector3(0, 2.1, -0.4), 0.05, 0.2, WOOD.darkened(0.2))
			kit.beam(Vector3(0.28, 1.92, -0.4), Vector3(0, 2.1, -0.4), 0.05, 0.2, WOOD.darkened(0.2))
			kit.lathe(Vector3(0, 1.7, -0.3), [Vector2(0.11, 0.0), Vector2(0.11, 0.01)], 10, WHITE)
			kit.box(Vector3(0, 1.88, -0.3), Vector3(0.08, 0.06, 0.02), BLACK)
			for sx in [-0.06, 0.06]:
				kit.tube(Vector3(sx, 1.55, -0.38), Vector3(sx, 1.25, -0.38), 0.005, 0.005, 3, GOLD)
				kit.lathe(Vector3(sx, 1.12, -0.38), [Vector2(0.025, 0.0), Vector2(0.03, 0.08), Vector2(0.01, 0.13)], 6, GOLD.darkened(0.2))
		# --- Transports --------------------------------------------------------------------------
		"locomotive":
			_locomotive(kit, w)
		"grand_bi":
			kit.tube(Vector3(-0.04, 0.75, 0.35), Vector3(0.04, 0.75, 0.35), 0.72, 0.72, 16, BLACK, false)
			kit.tube(Vector3(-0.03, 0.75, 0.35), Vector3(0.03, 0.75, 0.35), 0.66, 0.66, 16, Color("3a3a3a"))
			kit.tube(Vector3(-0.03, 0.2, -0.6), Vector3(0.03, 0.2, -0.6), 0.2, 0.2, 10, BLACK)
			kit.beam(Vector3(0, 1.45, 0.25), Vector3(0, 0.25, -0.6), 0.05, 0.05, Color("2a2a2a"))
			kit.box(Vector3(0, 1.52, 0.2), Vector3(0.12, 0.05, 0.25), Color("5a3a22"))
			kit.beam(Vector3(-0.25, 1.55, 0.4), Vector3(0.25, 1.55, 0.4), 0.03, 0.03, STEEL)
			kit.box(Vector3(0, 0.03, 0), Vector3(0.6, 0.06, 1.8), Color("54585e"))
		"moto":
			kit.box(Vector3(0, 0.03, 0), Vector3(0.6, 0.06, 1.8), Color("54585e"))
			for z in [-0.6, 0.6]:
				kit.tube(Vector3(-0.05, 0.36, z), Vector3(0.05, 0.36, z), 0.3, 0.3, 12, BLACK)
				kit.tube(Vector3(-0.06, 0.36, z), Vector3(0.06, 0.36, z), 0.08, 0.08, 6, STEEL)
			kit.box(Vector3(0, 0.6, 0.05), Vector3(0.22, 0.25, 0.5), Color("5a1a1a"))
			kit.box(Vector3(0, 0.45, -0.1), Vector3(0.25, 0.22, 0.3), Color("4a4a4a"))
			kit.box(Vector3(0, 0.78, -0.3), Vector3(0.2, 0.06, 0.3), Color("3a2a1e"))
			kit.beam(Vector3(0, 0.7, 0.35), Vector3(0, 0.36, 0.6), 0.04, 0.04, STEEL)
			kit.beam(Vector3(-0.3, 0.95, 0.4), Vector3(0.3, 0.95, 0.4), 0.03, 0.03, STEEL)
			kit.beam(Vector3(0, 0.95, 0.4), Vector3(0, 0.7, 0.35), 0.04, 0.04, STEEL)
		"maquette_train":
			_table_maquette(kit, w, d, c == "jouet")
		"horloge_gare":
			kit.box(Vector3(0, 2.0, -0.4), Vector3(0.06, 0.06, 0.2), DARK)
			kit.tube(Vector3(0, 2.0, -0.32), Vector3(0, 2.0, -0.18), 0.3, 0.3, 14, DARK)
			kit.lathe(Vector3(0, 2.0, -0.17), [Vector2(0.27, 0.0), Vector2(0.27, 0.005)], 14, WHITE)
			kit.box(Vector3(0, 2.07, -0.16), Vector3(0.025, 0.16, 0.01), BLACK)
			kit.box(Vector3(0.06, 2.0, -0.16), Vector3(0.14, 0.02, 0.01), BLACK)
		"signal":
			kit.box(Vector3(0, 0.1, 0), Vector3(0.5, 0.2, 0.5), Color("54585e"))
			kit.tube(Vector3(0, 0.2, 0), Vector3(0, 2.4, 0), 0.05, 0.05, 6, Color("3a3d42"))
			kit.box(Vector3(0, 2.1, 0.08), Vector3(0.9, 0.18, 0.04), RED)
			kit.box(Vector3(-0.3, 2.1, 0.11), Vector3(0.12, 0.12, 0.01), WHITE)
			kit.layer = "lumiere"
			kit.tube(Vector3(0.1, 2.35, 0.05), Vector3(0.1, 2.35, 0.12), 0.06, 0.06, 6, Color("ff4030"))
			kit.layer = "base"
			kit.box(Vector3(0.2, 0.6, 0.12), Vector3(0.18, 0.25, 0.18), Color("2a3a2a"))
			kit.layer = "lumiere"
			kit.box(Vector3(0.2, 0.6, 0.22), Vector3(0.1, 0.12, 0.01), Color("ffd060"))
			kit.layer = "base"
		"draisienne":
			kit.box(Vector3(0, 0.03, 0), Vector3(1.8, 0.06, 0.6), Color("54585e"))
			for x in [-0.55, 0.55]:
				kit.tube(Vector3(x, 0.38, -0.03), Vector3(x, 0.38, 0.03), 0.34, 0.34, 12, WOOD)
				kit.tube(Vector3(x, 0.38, -0.04), Vector3(x, 0.38, 0.04), 0.06, 0.06, 6, WOOD.darkened(0.2))
			kit.beam(Vector3(-0.55, 0.72, 0), Vector3(0.6, 0.72, 0), 0.08, 0.08, WOOD2)
			kit.box(Vector3(-0.1, 0.8, 0), Vector3(0.3, 0.06, 0.16), Color("5a3a22"))
			kit.beam(Vector3(0.55, 0.72, 0), Vector3(0.6, 1.0, 0), 0.04, 0.04, WOOD2)
			kit.beam(Vector3(0.6, 1.0, -0.2), Vector3(0.6, 1.0, 0.2), 0.03, 0.03, WOOD2)
		# --- Automobile --------------------------------------------------------------------------
		"voiture_course":
			_voiture(kit, d, Color("b3121c"), 0.55, 0.32, true, false)
		"limousine":
			_voiture(kit, d, Color("1c2430"), 0.75, 0.4, false, true)
		"citadine":
			_voiture(kit, d, Color("7fb8a8"), 0.7, 0.3, false, false)
		"monoplace":
			_monoplace(kit, d)
		"moteur":
			kit.box(Vector3(0, 0.3, 0), Vector3(0.8, 0.6, 0.8), Color("54585e"))
			kit.box(Vector3(0, 0.85, 0), Vector3(0.6, 0.5, 0.5), STEEL)
			kit.box(Vector3(0.12, 0.85, 0.26), Vector3(0.36, 0.48, 0.02), RED)
			for i in 4:
				kit.box(Vector3(-0.2 + i * 0.13, 1.15, 0), Vector3(0.08, 0.1, 0.4), Color("3a3d42"))
				kit.tube(Vector3(-0.2 + i * 0.13, 0.75, 0.25), Vector3(-0.2 + i * 0.13, 0.95, 0.25), 0.04, 0.04, 6, Color("c0c4c8"))
		"pompe":
			kit.box(Vector3(0, 0.08, 0), Vector3(0.5, 0.16, 0.5), Color("3a3d42"))
			kit.tube(Vector3(0, 0.16, 0), Vector3(0, 1.5, 0), 0.2, 0.18, 8, Color("d62828"))
			kit.box(Vector3(0, 1.1, 0.17), Vector3(0.22, 0.25, 0.02), WHITE)
			kit.layer = "lumiere"
			kit.blob(Vector3(0, 1.75, 0), Vector3(0.18, 0.2, 0.18), WHITE, Color("fff6e0"), 0.0, 1)
			kit.layer = "base"
			kit.beam(Vector3(0.18, 0.9, 0), Vector3(0.3, 0.6, 0.1), 0.03, 0.03, BLACK)
			kit.box(Vector3(0.3, 0.55, 0.12), Vector3(0.06, 0.15, 0.06), STEEL)
		"plateau":
			kit.lathe(Vector3(0, 0, 0), [Vector2(minf(w, d) * 0.5 - 0.1, 0.0), Vector2(minf(w, d) * 0.5 - 0.1, 0.12)], 24, Color("cfd3d8"))
			kit.lathe(Vector3(0, 0.12, 0), [Vector2(minf(w, d) * 0.5 - 0.3, 0.0), Vector2(minf(w, d) * 0.5 - 0.3, 0.01)], 24, Color("e9ecef"))
		# --- Air et espace -----------------------------------------------------------------------
		"module_lunaire":
			_module_lunaire(kit)
		"capsule":
			kit.box(Vector3(0, 0.1, 0), Vector3(1.8, 0.2, 1.8), Color("54585e"))
			kit.lathe(Vector3(0, 0.2, 0), [Vector2(0.85, 0.0), Vector2(0.88, 0.15), Vector2(0.5, 1.4), Vector2(0.25, 1.75), Vector2(0.18, 2.0)], 12, Color("4a4a48"))
			kit.lathe(Vector3(0, 0.15, 0), [Vector2(0.8, 0.0), Vector2(0.86, 0.06)], 12, Color("8a5a3a"))
			kit.box(Vector3(0, 0.9, 0.6), Vector3(0.4, 0.5, 0.15), Color("2b2f33"))
			kit.layer = "verre"
			kit.box(Vector3(0.25, 1.35, 0.4), Vector3(0.15, 0.15, 0.1), GLASS)
			kit.layer = "base"
		"combinaison":
			kit.box(Vector3(0, 0.05, 0), Vector3(0.7, 0.1, 0.7), DARK)
			_astronaute(kit, Vector3(0, 0.1, 0))
		"satellite":
			var ys := CEIL - 0.9
			kit.tube(Vector3(0, CEIL, 0), Vector3(0, ys + 0.35, 0), 0.01, 0.01, 3, DARK)
			kit.box(Vector3(0, ys, 0), Vector3(0.7, 0.7, 0.7), GOLD)
			for sx in [-1, 1]:
				kit.beam(Vector3(sx * 0.35, ys, 0), Vector3(sx * 0.6, ys, 0), 0.04, 0.04, STEEL)
				kit.box(Vector3(sx * 1.25, ys, 0), Vector3(1.3, 0.03, 0.8), Color("1d3a6e"))
			kit.lathe(Vector3(0, ys - 0.35, 0), [Vector2(0.02, 0.0), Vector2(0.35, -0.2)], 10, WHITE)
		"planeur":
			var yp := CEIL - 0.9
			for sx in [-1.5, 1.5]:
				kit.tube(Vector3(sx, CEIL, 0), Vector3(sx, yp + 0.05, 0), 0.01, 0.01, 3, DARK)
			kit.tube(Vector3(0, yp, -1.3), Vector3(0, yp, 1.2), 0.1, 0.25, 8, WHITE)
			kit.box(Vector3(0, yp + 0.15, 0.3), Vector3(5.8, 0.04, 0.5), WHITE)
			kit.box(Vector3(0, yp + 0.05, -1.25), Vector3(1.0, 0.03, 0.25), WHITE)
			kit.box(Vector3(0, yp + 0.25, -1.25), Vector3(0.03, 0.45, 0.3), RED)
			kit.layer = "verre"
			kit.blob(Vector3(0, yp + 0.2, 0.75), Vector3(0.18, 0.12, 0.35), GLASS, GLASS, 0.0, 1)
			kit.layer = "base"
		"montgolfiere":
			var ym := CEIL - 1.3
			kit.tube(Vector3(0, CEIL, 0), Vector3(0, ym + 0.95, 0), 0.01, 0.01, 3, DARK)
			kit.lathe(Vector3(0, ym, 0), [Vector2(0.12, 0.0), Vector2(0.45, 0.35), Vector2(0.55, 0.7), Vector2(0.35, 0.95), Vector2(0.0, 1.0)], 10, Color("e9c46a"),
				false, true, func(i: int, _r: int) -> Color: return Color("d62828") if i % 2 == 0 else Color("e9c46a"))
			kit.box(Vector3(0, ym - 0.35, 0), Vector3(0.22, 0.16, 0.22), WOOD2)
			for sx in [-0.09, 0.09]:
				for sz in [-0.09, 0.09]:
					kit.beam(Vector3(sx, ym - 0.27, sz), Vector3(sx * 1.2, ym, sz * 1.2), 0.008, 0.008, DARK)
		"moteur_fusee":
			kit.box(Vector3(0, 0.1, 0), Vector3(1.8, 0.2, 1.8), Color("54585e"))
			kit.lathe(Vector3(0, 0.2, 0), [Vector2(0.75, 0.0), Vector2(0.45, 0.9), Vector2(0.25, 1.2)], 14, Color("3a3d42"))
			kit.tube(Vector3(0, 1.4, 0), Vector3(0, 2.2, 0), 0.4, 0.4, 10, STEEL)
			for i in 6:
				var a := float(i) * TAU / 6.0
				kit.tube(Vector3(cos(a) * 0.42, 1.3, sin(a) * 0.42), Vector3(cos(a) * 0.42, 2.3, sin(a) * 0.42), 0.05, 0.05, 4, COPPER)
			kit.lathe(Vector3(0, 2.2, 0), [Vector2(0.4, 0.0), Vector2(0.15, 0.3)], 10, STEEL)
		# --- Marine ------------------------------------------------------------------------------
		"galion":
			kit.box(Vector3(0, 0.45, 0), Vector3(1.8, 0.9, 0.8), WOOD)
			kit.box(Vector3(0, 0.92, 0), Vector3(1.7, 0.04, 0.7), Color("1f3b5a"))
			var sg := kit.xf
			kit.xf = sg * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, 0.94, 0))
			_bateau(kit, Vector3.ZERO, 0.9)
			kit.xf = sg
			kit.layer = "verre"
			kit.box(Vector3(0, 1.4, 0), Vector3(1.8, 0.95, 0.8), GLASS)
			kit.layer = "base"
		"figure_proue":
			kit.box(Vector3(0, 0.15, 0), Vector3(0.7, 0.3, 1.6), Color("54585e"))
			kit.beam(Vector3(0, 0.3, -0.6), Vector3(0, 1.6, 0.4), 0.3, 0.35, WOOD.darkened(0.1))
			var fc := Color("e8d5b0")
			kit.blob(Vector3(0, 1.3, 0.5), Vector3(0.2, 0.45, 0.18), fc, fc.lightened(0.1), 0.06, 1)
			kit.blob(Vector3(0, 1.85, 0.62), Vector3(0.12, 0.14, 0.12), fc, fc.lightened(0.1), 0.04, 1)
			kit.blob(Vector3(0, 0.85, 0.4), Vector3(0.25, 0.3, 0.2), Color("2a5a8a"), Color("3a6a9a"), 0.08, 1)
			kit.blob(Vector3(0, 1.95, 0.55), Vector3(0.14, 0.1, 0.14), GOLD, GOLD.lightened(0.2), 0.05, 0)
		"scaphandre":
			kit.box(Vector3(0, 0.05, 0), Vector3(0.7, 0.1, 0.7), DARK)
			var tc := Color("8a7a5a")
			for sx in [-0.12, 0.12]:
				kit.box(Vector3(sx, 0.18, 0.05), Vector3(0.18, 0.16, 0.3), Color("4a4a4a"))
				kit.beam(Vector3(sx, 0.25, 0), Vector3(sx, 0.9, 0), 0.17, 0.17, tc)
			kit.blob(Vector3(0, 1.2, 0), Vector3(0.28, 0.35, 0.2), tc, tc.lightened(0.1), 0.06, 1)
			for sx2 in [-0.32, 0.32]:
				kit.beam(Vector3(sx2, 1.4, 0), Vector3(sx2 * 1.1, 0.9, 0.05), 0.12, 0.12, tc)
			kit.blob(Vector3(0, 1.75, 0), Vector3(0.26, 0.26, 0.26), COPPER, COPPER.lightened(0.2), 0.0, 1)
			kit.layer = "verre"
			kit.tube(Vector3(0, 1.75, 0.2), Vector3(0, 1.75, 0.27), 0.11, 0.11, 8, GLASS)
			kit.layer = "base"
			kit.box(Vector3(0, 1.48, 0), Vector3(0.5, 0.06, 0.4), COPPER)
		"ancre":
			kit.box(Vector3(0, 0.08, 0), Vector3(0.8, 0.16, 0.6), Color("54585e"))
			var ac := Color("2b2f33")
			kit.beam(Vector3(0, 0.35, 0), Vector3(0, 1.8, 0), 0.08, 0.08, ac)
			kit.beam(Vector3(-0.35, 1.6, 0), Vector3(0.35, 1.6, 0), 0.06, 0.06, WOOD)
			kit.beam(Vector3(0, 0.35, 0), Vector3(-0.35, 0.6, 0), 0.07, 0.07, ac)
			kit.beam(Vector3(0, 0.35, 0), Vector3(0.35, 0.6, 0), 0.07, 0.07, ac)
			kit.tube(Vector3(0, 1.9, -0.05), Vector3(0, 1.9, 0.05), 0.1, 0.1, 8, ac)
		"lentille":
			kit.box(Vector3(0, 0.3, 0), Vector3(1.2, 0.6, 1.2), Color("54585e"))
			kit.lathe(Vector3(0, 0.6, 0), [Vector2(0.55, 0.0), Vector2(0.55, 0.06)], 12, COPPER)
			kit.layer = "verre"
			kit.lathe(Vector3(0, 0.66, 0), [Vector2(0.5, 0.0), Vector2(0.58, 0.6), Vector2(0.5, 1.2), Vector2(0.2, 1.5)], 12, Color(0.85, 0.95, 0.9))
			kit.layer = "lumiere"
			kit.blob(Vector3(0, 1.3, 0), Vector3(0.12, 0.12, 0.12), LIGHT, LIGHT, 0.0, 1)
			kit.layer = "base"
			for i in 6:
				kit.lathe(Vector3(0, 0.75 + i * 0.2, 0), [Vector2(0.56, 0.0), Vector2(0.57, 0.02)], 12, COPPER)
			kit.lathe(Vector3(0, 2.15, 0), [Vector2(0.25, 0.0), Vector2(0.05, 0.25)], 8, COPPER)
		"barre":
			kit.tube(Vector3(0, 1.6, -0.46), Vector3(0, 1.6, -0.36), 0.08, 0.08, 6, WOOD)
			kit.tube(Vector3(0, 1.6, -0.42), Vector3(0, 1.6, -0.38), 0.32, 0.32, 14, WOOD2, false)
			for i in 8:
				var a2 := float(i) * TAU / 8.0
				kit.beam(Vector3(0, 1.6, -0.4), Vector3(cos(a2) * 0.45, 1.6 + sin(a2) * 0.45, -0.4), 0.04, 0.04, WOOD)
		"canot":
			kit.box(Vector3(0, 0.15, -1.2), Vector3(0.8, 0.3, 0.3), Color("54585e"))
			kit.box(Vector3(0, 0.15, 1.2), Vector3(0.8, 0.3, 0.3), Color("54585e"))
			_coque(kit, Vector3(0, 0.3, 0), 1.6, 4.4, 0.9, Color("e8e2d0"), Color("d65a2a"))
		"aquarium":
			kit.box(Vector3(0, 0.4, -0.15), Vector3(w - 0.1, 0.8, 0.65), DARK)
			kit.layer = "verre"
			kit.box(Vector3(0, 1.4, -0.15), Vector3(w - 0.1, 1.2, 0.65), Color(0.35, 0.65, 0.85))
			kit.layer = "base"
			kit.box(Vector3(0, 0.84, -0.15), Vector3(w - 0.2, 0.08, 0.55), Color("e8d8a8"))
			var cc := [Color("ff6f3c"), Color("f2d024"), Color("2a9df4"), Color("e84a8a"), Color("7a4af0")]
			for i in 7:
				kit.blob(Vector3(-1.1 + i * 0.37, 1.1 + float(i % 3) * 0.25, -0.15 + float(i % 2) * 0.12), Vector3(0.07, 0.05, 0.03), cc[i % cc.size()] as Color, (cc[i % cc.size()] as Color).lightened(0.3), 0.0, 0)
			for i in 4:
				kit.tube(Vector3(-1.0 + i * 0.6, 0.88, -0.3), Vector3(-1.0 + i * 0.6 + 0.05, 1.25, -0.3), 0.05, 0.01, 5, [Color("e86a5a"), Color("f2a0c0"), Color("6ac08a"), Color("e8b04a")][i] as Color)
			kit.layer = "lumiere"
			kit.box(Vector3(0, 2.02, -0.15), Vector3(w - 0.3, 0.02, 0.4), LIGHT)
			kit.layer = "base"
		# --- Cinéma et photographie -----------------------------------------------------------------
		"camera":
			_trepied(kit, 1.15)
			kit.box(Vector3(0, 1.35, 0), Vector3(0.3, 0.4, 0.55), BLACK)
			kit.tube(Vector3(0, 1.35, 0.27), Vector3(0, 1.35, 0.45), 0.07, 0.06, 8, Color("3a3a3a"))
			for z in [-0.12, 0.18]:
				kit.tube(Vector3(-0.03, 1.72, z), Vector3(0.03, 1.72, z), 0.17, 0.17, 12, Color("2b2b2b"))
		"projecteur_film":
			kit.box(Vector3(0, 0.4, 0), Vector3(0.5, 0.8, 0.5), Color("3a3d42"))
			kit.box(Vector3(0, 1.05, 0), Vector3(0.35, 0.5, 0.6), Color("4a5a6a"))
			kit.tube(Vector3(0, 1.0, 0.3), Vector3(0, 1.0, 0.45), 0.07, 0.07, 8, BLACK)
			for z in [-0.2, 0.2]:
				kit.tube(Vector3(-0.03, 1.5, z), Vector3(0.03, 1.5, z), 0.2, 0.2, 12, Color("8a8f94"))
		"clap":
			kit.box(Vector3(0, 0.08, 0), Vector3(0.6, 0.16, 0.6), DARK)
			kit.box(Vector3(0, 0.75, 0), Vector3(0.8, 0.6, 0.06), BLACK)
			kit.box(Vector3(0, 0.75, 0.035), Vector3(0.7, 0.02, 0.01), WHITE)
			kit.box(Vector3(0, 0.6, 0.035), Vector3(0.7, 0.02, 0.01), WHITE)
			var saved := kit.xf
			kit.xf = saved * Transform3D(Basis(Vector3.BACK, 0.25), Vector3(-0.38, 1.08, 0))
			kit.box(Vector3(0.4, 0.06, 0), Vector3(0.82, 0.12, 0.06), WHITE)
			for i in 4:
				kit.box(Vector3(0.12 + i * 0.2, 0.06, 0.035), Vector3(0.09, 0.12, 0.01), BLACK)
			kit.xf = saved
		"fauteuils_cine":
			for x in [-0.9, 0.0, 0.9]:
				kit.box(Vector3(x, 0.42, 0.05), Vector3(0.75, 0.15, 0.6), RED)
				kit.box(Vector3(x, 0.75, -0.28), Vector3(0.75, 0.75, 0.15), RED)
			for x2 in [-1.35, -0.45, 0.45, 1.35]:
				kit.box(Vector3(x2, 0.35, -0.05), Vector3(0.08, 0.6, 0.75), DARK)
		"appareil_photo":
			_trepied(kit, 1.1)
			kit.box(Vector3(0, 1.3, -0.1), Vector3(0.3, 0.32, 0.12), WOOD)
			kit.box(Vector3(0, 1.3, 0.2), Vector3(0.24, 0.26, 0.1), WOOD)
			kit.beam(Vector3(0, 1.3, -0.04), Vector3(0, 1.3, 0.15), 0.24, 0.26, BLACK)
			kit.tube(Vector3(0, 1.3, 0.25), Vector3(0, 1.3, 0.32), 0.05, 0.05, 8, GOLD)
			kit.box(Vector3(0, 1.38, -0.3), Vector3(0.5, 0.3, 0.3), BLACK)
		"costume_film":
			kit.box(Vector3(0, 0.05, 0), Vector3(0.7, 0.1, 0.7), DARK)
			var gc := Color("d9a520")
			for sx in [-0.11, 0.11]:
				kit.tube(Vector3(sx, 0.1, 0), Vector3(sx, 0.95, 0), 0.08, 0.09, 6, gc)
			kit.box(Vector3(0, 1.3, 0), Vector3(0.42, 0.6, 0.24), gc)
			kit.box(Vector3(0, 1.3, 0.13), Vector3(0.2, 0.25, 0.02), Color("b0b4b8"))
			for sx2 in [-0.27, 0.27]:
				kit.tube(Vector3(sx2, 1.55, 0), Vector3(sx2 * 1.05, 0.95, 0.05), 0.06, 0.05, 6, gc)
			kit.blob(Vector3(0, 1.82, 0), Vector3(0.14, 0.17, 0.14), gc, gc.lightened(0.2), 0.0, 1)
			kit.layer = "lumiere"
			for sx3 in [-0.05, 0.05]:
				kit.box(Vector3(sx3, 1.85, 0.13), Vector3(0.04, 0.03, 0.01), Color("ffcc33"))
			kit.layer = "base"
		"decor_film":
			kit.box(Vector3(0, 1.35, -0.45), Vector3(w - 0.1, 2.7, 0.08), Color("a86a3a"))
			for i in 9:
				kit.box(Vector3(-1.3 + i * 0.33, 1.35, -0.4), Vector3(0.02, 2.6, 0.01), Color("7a4a2a"))
			kit.box(Vector3(0, 2.45, -0.38), Vector3(1.6, 0.35, 0.03), Color("e8d8a8"))
			kit.box(Vector3(0, 2.45, -0.36), Vector3(1.3, 0.08, 0.01), Color("5a2a1a"))
			for sx in [-0.25, 0.25]:
				kit.box(Vector3(sx, 0.8, -0.38), Vector3(0.45, 0.7, 0.03), Color("6a3a1a"))
			for sx2 in [-1.0, 1.0]:
				kit.box(Vector3(sx2, 1.4, -0.39), Vector3(0.5, 0.6, 0.02), Color("2b3a4a"))
			kit.box(Vector3(0, 1.55, 0.0), Vector3(w - 0.2, 0.06, 0.8), Color("8a5a3a"))
			for sx3 in [-1.3, 1.3]:
				kit.box(Vector3(sx3, 0.78, 0.35), Vector3(0.08, 1.56, 0.08), Color("7a4a2a"))
			for sx4 in [-1.3, -0.4, 0.4, 1.3]:
				kit.box(Vector3(sx4, 0.35, -0.38), Vector3(0.08, 0.7, 0.08), Color("7a4a2a"))
		# --- Sport -------------------------------------------------------------------------------
		"velo":
			kit.box(Vector3(0, 0.03, 0), Vector3(0.6, 0.06, 1.8), Color("54585e"))
			for z in [-0.52, 0.52]:
				kit.tube(Vector3(-0.02, 0.4, z), Vector3(0.02, 0.4, z), 0.34, 0.34, 14, BLACK, false)
				kit.tube(Vector3(-0.015, 0.4, z), Vector3(0.015, 0.4, z), 0.31, 0.31, 14, Color("c0c4c8"), false)
			var vc := Color("f2d024")
			kit.beam(Vector3(0, 0.4, -0.52), Vector3(0, 0.45, 0.0), 0.03, 0.03, vc)
			kit.beam(Vector3(0, 0.45, 0.0), Vector3(0, 0.88, -0.18), 0.035, 0.035, vc)
			kit.beam(Vector3(0, 0.88, -0.18), Vector3(0, 0.84, 0.42), 0.035, 0.035, vc)
			kit.beam(Vector3(0, 0.45, 0.0), Vector3(0, 0.84, 0.42), 0.035, 0.035, vc)
			kit.beam(Vector3(0, 0.84, 0.42), Vector3(0, 0.4, 0.52), 0.03, 0.03, vc)
			kit.box(Vector3(0, 0.95, -0.2), Vector3(0.1, 0.04, 0.22), BLACK)
			kit.beam(Vector3(-0.2, 0.95, 0.48), Vector3(0.2, 0.95, 0.48), 0.025, 0.025, BLACK)
			kit.box(Vector3(0, 1.2, 0.0), Vector3(0.5, 0.35, 0.02), vc)
		"skis":
			for i in 4:
				var sx := -0.6 + i * 0.22
				kit.box(Vector3(sx, 1.0, -0.45), Vector3(0.07, 1.8, 0.02), [WOOD2, WOOD, RED, Color("1d3557")][i] as Color)
				kit.box(Vector3(sx, 1.9, -0.43), Vector3(0.07, 0.08, 0.04), [WOOD2, WOOD, RED, Color("1d3557")][i] as Color)
			kit.beam(Vector3(0.45, 0.6, -0.4), Vector3(0.45, 1.6, -0.4), 0.05, 0.03, WOOD)
			kit.beam(Vector3(0.75, 0.7, -0.4), Vector3(0.75, 1.5, -0.4), 0.03, 0.03, WOOD)
			kit.beam(Vector3(0.68, 1.5, -0.4), Vector3(0.85, 1.5, -0.4), 0.025, 0.04, STEEL)
		"flambeau":
			kit.box(Vector3(0, 0.45, 0), Vector3(0.5, 0.9, 0.5), WHITE)
			kit.lathe(Vector3(0, 0.9, 0), [Vector2(0.03, 0.0), Vector2(0.05, 0.4), Vector2(0.09, 0.55)], 8, Color("c8ccd0"))
			kit.layer = "verre"
			kit.box(Vector3(0, 1.25, 0), Vector3(0.48, 0.7, 0.48), GLASS)
			kit.layer = "lumiere"
			kit.lathe(Vector3(0, 1.45, 0), [Vector2(0.07, 0.0), Vector2(0.03, 0.12)], 6, Color("ffa040"))
			kit.layer = "base"
		"champion":
			kit.box(Vector3(0, 0.35, 0), Vector3(0.75, 0.7, 0.75), Color("3a3d42"))
			MuseeModeles._figure(kit, Vector3(0, 0.7, 0), 1.0, BRONZE, false)
			kit.beam(Vector3(0.17, 1.95, 0), Vector3(0.25, 2.3, 0.05), 0.07, 0.07, BRONZE)
			kit.lathe(Vector3(0.25, 2.25, 0.05), [Vector2(0.03, 0.0), Vector2(0.09, 0.12)], 6, GOLD)
		"podium_sport":
			kit.box(Vector3(0, 0.4, 0), Vector3(0.9, 0.8, 0.8), WHITE)
			kit.box(Vector3(-0.9, 0.28, 0), Vector3(0.9, 0.56, 0.8), WHITE)
			kit.box(Vector3(0.9, 0.18, 0), Vector3(0.9, 0.36, 0.8), WHITE)
			kit.box(Vector3(0, 0.55, 0.41), Vector3(0.25, 0.3, 0.01), GOLD)
			kit.box(Vector3(-0.9, 0.35, 0.41), Vector3(0.25, 0.3, 0.01), Color("c0c4c8"))
			kit.box(Vector3(0.9, 0.2, 0.41), Vector3(0.25, 0.25, 0.01), Color("b0703a"))
		# --- Mode --------------------------------------------------------------------------------
		"robe":
			_robe(kit, c)
		"machine_coudre":
			kit.box(Vector3(0, 0.38, 0), Vector3(0.7, 0.04, 0.45), WOOD)
			for sx in [-0.3, 0.3]:
				kit.box(Vector3(sx, 0.18, 0), Vector3(0.05, 0.36, 0.4), BLACK)
			kit.box(Vector3(0, 0.75, 0), Vector3(0.75, 0.04, 0.45), WOOD2)
			kit.box(Vector3(0.15, 0.85, 0), Vector3(0.35, 0.15, 0.12), BLACK)
			kit.box(Vector3(0.28, 1.0, 0), Vector3(0.1, 0.3, 0.12), BLACK)
			kit.box(Vector3(-0.05, 1.08, 0), Vector3(0.5, 0.1, 0.1), BLACK)
			kit.box(Vector3(-0.22, 0.92, 0), Vector3(0.06, 0.22, 0.06), BLACK)
			kit.tube(Vector3(0.34, 1.0, -0.06), Vector3(0.34, 1.0, 0.06), 0.07, 0.07, 8, STEEL)
			kit.box(Vector3(0.05, 0.92, 0.065), Vector3(0.3, 0.04, 0.005), GOLD)
		"podium_defile":
			kit.box(Vector3(0, 0.2, 0), Vector3(w - 0.4, 0.4, d - 0.2), BLACK)
			kit.box(Vector3(0, 0.405, 0), Vector3(w - 0.6, 0.01, d - 0.4), WHITE)
			kit.layer = "lumiere"
			for sx in [-1, 1]:
				kit.box(Vector3(sx * (w * 0.5 - 0.21), 0.38, 0), Vector3(0.02, 0.03, d - 0.3), Color("fff6e0"))
			kit.layer = "base"
		# --- Musique -----------------------------------------------------------------------------
		"piano":
			_piano(kit)
		"harpe":
			kit.box(Vector3(0, 0.08, 0), Vector3(0.5, 0.16, 0.6), GOLD.darkened(0.2))
			kit.beam(Vector3(0, 0.16, -0.2), Vector3(0, 1.85, -0.15), 0.08, 0.08, GOLD)
			kit.beam(Vector3(0, 0.16, -0.2), Vector3(0, 1.3, 0.35), 0.16, 0.12, WOOD2)
			kit.beam(Vector3(0, 1.85, -0.15), Vector3(0, 1.3, 0.35), 0.06, 0.06, GOLD)
			for i in 8:
				var t := float(i) / 8.0
				var a3 := Vector3(0, 0.16, -0.2).lerp(Vector3(0, 1.3, 0.35), t + 0.06)
				var b3 := Vector3(0, 1.85, -0.15).lerp(Vector3(0, 1.3, 0.35), t + 0.06)
				kit.beam(a3, b3, 0.006, 0.006, WHITE)
		"guitares":
			var gcols := [RED, Color("f2f0ea"), Color("1d3557")]
			for i in 3:
				var gx := -0.6 + i * 0.6
				kit.blob(Vector3(gx, 1.15, -0.42), Vector3(0.17, 0.22, 0.04), gcols[i] as Color, (gcols[i] as Color).lightened(0.15), 0.03, 0)
				kit.box(Vector3(gx, 1.62, -0.42), Vector3(0.05, 0.6, 0.03), WOOD2)
				kit.box(Vector3(gx, 1.95, -0.42), Vector3(0.08, 0.12, 0.03), BLACK)
				kit.box(Vector3(gx, 1.15, -0.39), Vector3(0.12, 0.04, 0.01), STEEL)
		"juke_box":
			kit.box(Vector3(0, 0.55, 0), Vector3(0.8, 1.1, 0.55), Color("8e1e24"))
			kit.lathe(Vector3(0, 1.1, 0), [Vector2(0.4, 0.0), Vector2(0.38, 0.25), Vector2(0.2, 0.42)], 10, Color("8e1e24"))
			kit.layer = "lumiere"
			for sx in [-0.34, 0.34]:
				kit.box(Vector3(sx, 0.8, 0.28), Vector3(0.06, 1.0, 0.02), Color("ffb347"))
			kit.lathe(Vector3(0, 1.12, 0.2), [Vector2(0.3, 0.0), Vector2(0.18, 0.28)], 10, Color("ffe08a"))
			kit.layer = "base"
			kit.layer = "verre"
			kit.box(Vector3(0, 1.0, 0.27), Vector3(0.5, 0.3, 0.02), GLASS)
			kit.layer = "base"
			kit.box(Vector3(0, 0.45, 0.28), Vector3(0.55, 0.3, 0.02), STEEL)
		"gramophone":
			kit.box(Vector3(0, 0.35, 0), Vector3(0.5, 0.7, 0.5), WOOD)
			kit.box(Vector3(0, 0.82, 0), Vector3(0.45, 0.24, 0.45), WOOD2)
			kit.lathe(Vector3(0, 0.95, 0), [Vector2(0.18, 0.0), Vector2(0.18, 0.01)], 12, BLACK)
			kit.beam(Vector3(0.15, 0.95, -0.15), Vector3(0.1, 1.1, -0.1), 0.03, 0.03, GOLD)
			var saved2 := kit.xf
			kit.xf = saved2 * Transform3D(Basis(Vector3.RIGHT, -1.0), Vector3(0.1, 1.1, -0.1))
			kit.lathe(Vector3.ZERO, [Vector2(0.03, 0.0), Vector2(0.08, 0.25), Vector2(0.32, 0.5)], 10, GOLD, false, false)
			kit.xf = saved2
		"batterie":
			kit.box(Vector3(0, 0.05, 0), Vector3(1.8, 0.1, 1.8), Color("3a3d42"))
			kit.tube(Vector3(0, 0.45, -0.2), Vector3(0, 0.45, 0.15), 0.35, 0.35, 12, Color("1d3557"))
			kit.lathe(Vector3(0, 0.45, 0.16), [Vector2(0.33, 0.0), Vector2(0.33, 0.005)], 12, WHITE)
			for p in [Vector3(-0.5, 0.65, 0.2), Vector3(0.45, 0.7, 0.1), Vector3(0.6, 0.5, -0.4)]:
				kit.tube(Vector3(p.x, 0.1, p.z), Vector3(p.x, p.y - 0.12, p.z), 0.015, 0.015, 3, STEEL)
				kit.tube(Vector3(p.x, p.y - 0.12, p.z), Vector3(p.x, p.y + 0.06, p.z), 0.16, 0.16, 10, Color("1d3557"))
			for p2 in [Vector3(-0.65, 1.2, -0.3), Vector3(0.6, 1.25, -0.5)]:
				kit.tube(Vector3(p2.x, 0.1, p2.z), Vector3(p2.x, p2.y, p2.z), 0.012, 0.012, 3, STEEL)
				kit.lathe(Vector3(p2.x, p2.y, p2.z), [Vector2(0.3, 0.0), Vector2(0.03, 0.04)], 12, GOLD)
			kit.lathe(Vector3(0.2, 0, -0.65), [Vector2(0.18, 0.0), Vector2(0.18, 0.5)], 8, BLACK)
		"orgue_barbarie":
			kit.box(Vector3(0, 0.3, 0), Vector3(0.6, 0.06, 0.4), DARK)
			for sx in [-0.25, 0.25]:
				kit.tube(Vector3(sx, 0.2, -0.22), Vector3(sx, 0.2, 0.22), 0.2, 0.2, 10, RED)
			kit.box(Vector3(0, 0.85, 0), Vector3(0.7, 1.0, 0.5), Color("8e1e24"))
			kit.box(Vector3(0, 0.95, 0.26), Vector3(0.6, 0.6, 0.02), GOLD.darkened(0.1))
			for i in 7:
				kit.tube(Vector3(-0.24 + i * 0.08, 0.75, 0.28), Vector3(-0.24 + i * 0.08, 0.95 + float(3 - absi(i - 3)) * 0.06, 0.28), 0.025, 0.025, 5, GOLD)
			kit.beam(Vector3(0.36, 0.85, 0), Vector3(0.48, 0.85, 0), 0.03, 0.03, BLACK)
			kit.beam(Vector3(0.48, 0.85, 0), Vector3(0.48, 0.72, 0.1), 0.03, 0.03, BLACK)
		"cor_alpes":
			for z in [-1.4, 1.5]:
				kit.box(Vector3(0, 0.2, z), Vector3(0.3, 0.4, 0.2), WOOD)
			kit.tube(Vector3(0, 0.62, -1.7), Vector3(0, 0.45, 1.3), 0.025, 0.08, 8, WOOD2)
			var saved3 := kit.xf
			kit.xf = saved3 * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.45, 1.3))
			kit.lathe(Vector3.ZERO, [Vector2(0.08, 0.0), Vector2(0.12, 0.25), Vector2(0.24, 0.45)], 10, WOOD2, false, false)
			kit.xf = saved3
			kit.lathe(Vector3(0, 0.45, 1.75), [Vector2(0.23, 0.0), Vector2(0.23, 0.01)], 10, WOOD)
		# --- Jouets ------------------------------------------------------------------------------
		"maison_poupee":
			kit.box(Vector3(0, 0.3, 0), Vector3(1.7, 0.6, 0.7), WOOD)
			kit.box(Vector3(0, 0.95, -0.15), Vector3(1.4, 0.7, 0.4), Color("f2d8c8"))
			for i0 in 3:
				var x0 := -0.45 + i0 * 0.45
				kit.box(Vector3(x0, 0.95, 0.06), Vector3(0.3, 0.6, 0.02), [Color("e8b4b8"), Color("b8d8e8"), Color("e8e0a8")][i0] as Color)
				kit.box(Vector3(x0, 0.72, 0.1), Vector3(0.14, 0.1, 0.08), RED)
			kit.box(Vector3(0, 1.31, -0.15), Vector3(1.45, 0.02, 0.42), WOOD2)
			kit.beam(Vector3(-0.75, 1.32, -0.15), Vector3(0, 1.7, -0.15), 0.05, 0.42, Color("6a2a2a"))
			kit.beam(Vector3(0.75, 1.32, -0.15), Vector3(0, 1.7, -0.15), 0.05, 0.42, Color("6a2a2a"))
		"cheval_bascule":
			for sx in [-0.18, 0.18]:
				var saved4 := kit.xf
				kit.xf = saved4 * Transform3D(Basis.IDENTITY, Vector3(sx, 0, 0))
				for i in 6:
					var a4 := -0.9 + float(i) * 0.36
					var a5 := a4 + 0.36
					kit.beam(Vector3(0, 0.75 - cos(a4) * 0.7, sin(a4) * 0.8), Vector3(0, 0.75 - cos(a5) * 0.7, sin(a5) * 0.8), 0.05, 0.06, RED)
				kit.xf = saved4
			var hc := Color("f3f1ec")
			for sz in [-0.3, 0.3]:
				for sx2 in [-0.12, 0.12]:
					kit.beam(Vector3(sx2, 0.1, sz), Vector3(sx2, 0.5, sz * 0.8), 0.06, 0.06, hc)
			kit.blob(Vector3(0, 0.62, 0), Vector3(0.18, 0.17, 0.4), hc, hc, 0.05, 1)
			kit.beam(Vector3(0, 0.7, 0.3), Vector3(0, 1.0, 0.45), 0.13, 0.12, hc)
			kit.blob(Vector3(0, 1.0, 0.55), Vector3(0.09, 0.09, 0.17), hc, hc, 0.03, 0)
			kit.beam(Vector3(0, 1.05, 0.38), Vector3(0, 0.65, 0.18), 0.04, 0.1, Color("6b4a2f"))
			kit.box(Vector3(0, 0.79, -0.05), Vector3(0.36, 0.04, 0.3), RED)
			for i2 in 3:
				kit.blob(Vector3(0, 0.62 + float(i2) * 0.03, -0.1 + float(i2) * 0.12), Vector3(0.05, 0.05, 0.05), Color("1d3557"), Color("1d3557"), 0.0, 0)
		"peluche":
			kit.box(Vector3(0, 0.15, 0), Vector3(0.7, 0.3, 0.7), WHITE)
			var pc := Color("b07a44")
			kit.blob(Vector3(0, 0.55, 0), Vector3(0.24, 0.27, 0.2), pc, pc.lightened(0.1), 0.08, 1)
			kit.blob(Vector3(0, 0.95, 0.02), Vector3(0.18, 0.17, 0.16), pc, pc.lightened(0.1), 0.05, 1)
			for sx in [-0.13, 0.13]:
				kit.blob(Vector3(sx, 1.1, 0), Vector3(0.06, 0.06, 0.04), pc, pc, 0.0, 0)
				kit.blob(Vector3(sx * 1.6, 0.55, 0.05), Vector3(0.07, 0.15, 0.07), pc, pc, 0.04, 0)
				kit.blob(Vector3(sx, 0.32, 0.12), Vector3(0.08, 0.06, 0.13), pc, pc, 0.04, 0)
			kit.blob(Vector3(0, 0.92, 0.16), Vector3(0.07, 0.05, 0.05), Color("e8c8a0"), Color("e8c8a0"), 0.0, 0)
			kit.box(Vector3(0, 0.78, 0.15), Vector3(0.2, 0.05, 0.03), RED)
		"arcade":
			kit.box(Vector3(0, 0.45, 0), Vector3(0.7, 0.9, 0.65), Color("2a2a5a"))
			kit.box(Vector3(0, 0.95, 0.1), Vector3(0.7, 0.12, 0.45), Color("1a1a3a"))
			kit.beam(Vector3(0, 1.0, 0.15), Vector3(0, 1.55, -0.05), 0.68, 0.2, Color("2a2a5a"))
			kit.layer = "lumiere"
			kit.box(Vector3(0, 1.3, 0.07), Vector3(0.5, 0.4, 0.02).rotated(Vector3.UP, 0.0), Color("40e0ff"))
			kit.box(Vector3(0, 1.7, 0.0), Vector3(0.6, 0.15, 0.04), Color("ff40c0"))
			kit.layer = "base"
			kit.box(Vector3(0, 1.75, -0.15), Vector3(0.7, 0.2, 0.4), Color("2a2a5a"))
			kit.tube(Vector3(-0.15, 1.02, 0.15), Vector3(-0.15, 1.12, 0.15), 0.015, 0.015, 4, BLACK)
			kit.blob(Vector3(-0.15, 1.13, 0.15), Vector3(0.03, 0.03, 0.03), RED, RED, 0.0, 0)
			for i in 3:
				kit.tube(Vector3(0.05 + i * 0.08, 1.01, 0.15), Vector3(0.05 + i * 0.08, 1.03, 0.15), 0.025, 0.025, 6, [Color("f2d024"), Color("2a9df4"), Color("2ab04a")][i] as Color)
		"toupies":
			kit.box(Vector3(0, 0.3, 0), Vector3(0.7, 0.6, 0.7), WHITE)
			kit.lathe(Vector3(-0.15, 0.6, -0.1), [Vector2(0.0, 0.0), Vector2(0.12, 0.08), Vector2(0.02, 0.16)], 8, RED,
				true, true, func(_i: int, r: int) -> Color: return Color("f2d024") if r == 1 else RED)
			for i in 3:
				kit.box(Vector3(0.12, 0.65 + i * 0.1, 0.12), Vector3(0.1, 0.1, 0.1), [Color("2a9df4"), Color("f2d024"), Color("2ab04a")][i] as Color)
			for i2 in 3:
				kit.lathe(Vector3(-0.2 + i2 * 0.1, 0.6, 0.18), [Vector2(0.03, 0.0), Vector2(0.03, 0.12), Vector2(0.02, 0.16)], 6, WOOD2)
		# --- Préhistoire -------------------------------------------------------------------------
		"paroi_grotte":
			kit.stone(Vector3(0, 1.25, -0.35), Vector3(w - 0.1, 2.5, 0.35), Color("a08060"))
			kit.box(Vector3(0, 1.4, -0.17), Vector3(w - 0.4, 1.6, 0.02), Color("c8a07a"))
			var ani := [Vector3(-0.9, 1.6, 0), Vector3(0.1, 1.85, 0), Vector3(0.8, 1.3, 0), Vector3(-0.3, 1.1, 0)]
			for i in ani.size():
				var p3: Vector3 = ani[i]
				var col3 := Color("7a2a1a") if i % 2 == 0 else Color("2a1a14")
				kit.blob(Vector3(p3.x, p3.y, -0.15), Vector3(0.28, 0.12, 0.01), col3, col3, 0.05, 0)
				kit.blob(Vector3(p3.x + 0.28, p3.y + 0.07, -0.15), Vector3(0.08, 0.06, 0.01), col3, col3, 0.0, 0)
				for lx in [-0.15, 0.15]:
					kit.box(Vector3(p3.x + lx, p3.y - 0.17, -0.15), Vector3(0.03, 0.15, 0.01), col3)
			for i2 in 3:
				kit.blob(Vector3(-1.2 + i2 * 0.15, 0.9, -0.15), Vector3(0.05, 0.07, 0.01), Color("c03a2a"), Color("c03a2a"), 0.0, 0)
		"chasseur":
			kit.box(Vector3(0, 0.05, 0), Vector3(0.8, 0.1, 0.8), Color("6a5a40"))
			var sc := SKIN.darkened(0.15)
			for sx in [-0.09, 0.09]:
				kit.beam(Vector3(sx, 0.1, 0), Vector3(sx, 0.85, 0), 0.1, 0.1, sc)
			kit.blob(Vector3(0, 0.9, 0), Vector3(0.22, 0.2, 0.15), Color("8a6a4a"), Color("9a7a5a"), 0.1, 1)
			kit.blob(Vector3(0, 1.25, 0), Vector3(0.18, 0.25, 0.13), sc, sc, 0.05, 1)
			kit.blob(Vector3(0, 1.62, 0), Vector3(0.11, 0.13, 0.11), sc, sc, 0.04, 1)
			kit.blob(Vector3(0, 1.7, -0.02), Vector3(0.13, 0.1, 0.12), Color("3a2a1e"), Color("4a3a2a"), 0.08, 0)
			kit.beam(Vector3(0.2, 1.4, 0), Vector3(0.25, 1.0, 0.1), 0.07, 0.07, sc)
			kit.beam(Vector3(0.25, 0.15, 0.12), Vector3(0.3, 1.95, 0.1), 0.025, 0.025, WOOD)
			kit.tube(Vector3(0.3, 1.95, 0.1), Vector3(0.31, 2.1, 0.1), 0.04, 0.0, 4, Color("5a5a5a"))
		"hutte":
			kit.box(Vector3(0, 0.03, 0), Vector3(2.8, 0.06, 2.8), Color("8a7a5a"))
			kit.lathe(Vector3(0, 0.06, 0), [Vector2(1.25, 0.0), Vector2(1.1, 1.0), Vector2(0.6, 1.9), Vector2(0.1, 2.25)], 10, Color("6a4a30"), false, true)
			for i in 10:
				var a6 := float(i) * TAU / 10.0
				kit.blob(Vector3(cos(a6) * 1.25, 0.25, sin(a6) * 1.25), Vector3(0.18, 0.25, 0.18), BONE, BONE.lightened(0.1), 0.1, 0)
				kit.beam(Vector3(cos(a6) * 1.2, 0.3, sin(a6) * 1.2), Vector3(cos(a6) * 0.2, 2.2, sin(a6) * 0.2), 0.07, 0.07, BONE)
			kit.box(Vector3(0, 0.45, 1.18), Vector3(0.7, 0.9, 0.2), Color("2a1a14"))
		"foyer":
			for i in 8:
				var a7 := float(i) * TAU / 8.0
				kit.stone(Vector3(cos(a7) * 0.35, 0.08, sin(a7) * 0.35), Vector3(0.16, 0.14, 0.16), Color("7a7a72"))
			for i2 in 3:
				kit.beam(Vector3(-0.2 + i2 * 0.2, 0.05, -0.2), Vector3(0.2 - i2 * 0.2, 0.15, 0.2), 0.06, 0.06, Color("3a2414"))
			kit.layer = "lumiere"
			kit.lathe(Vector3(0, 0.08, 0), [Vector2(0.18, 0.0), Vector2(0.08, 0.3), Vector2(0.02, 0.45)], 6, Color("ff8a2a"))
			kit.layer = "base"
		"menhir":
			kit.stone(Vector3(0, 1.2, 0), Vector3(0.65, 2.4, 0.45), Color("8a8a80"))
			for i in 4:
				kit.box(Vector3(0, 0.8 + i * 0.35, 0.23), Vector3(0.35 - i * 0.04, 0.03, 0.01), Color("5a5a52"))
		# --- Bande dessinée ----------------------------------------------------------------------
		"heros":
			kit.box(Vector3(0, 0.1, 0), Vector3(0.7, 0.2, 0.7), Color("f2d024"))
			_heros(kit, Vector3(0, 0.2, 0))
		"bulle":
			kit.blob(Vector3(0, 1.75, -0.44), Vector3(0.8, 0.4, 0.03), WHITE, WHITE, 0.0, 1)
			kit.tri(Vector3(-0.3, 1.45, -0.42), Vector3(-0.05, 1.45, -0.42), Vector3(-0.5, 1.15, -0.42), WHITE, Vector3.BACK)
			for i in 3:
				kit.box(Vector3(-0.4 + i * 0.38, 1.78, -0.405), Vector3(0.3, 0.1, 0.005), BLACK)
			kit.box(Vector3(0, 1.62, -0.405), Vector3(0.9, 0.05, 0.005), BLACK)
		"table_dessin":
			kit.box(Vector3(0, 0.35, 0.1), Vector3(0.08, 0.7, 0.6), WOOD)
			kit.box(Vector3(0, 0.03, 0.1), Vector3(1.4, 0.06, 0.6), WOOD)
			var saved5 := kit.xf
			kit.xf = saved5 * Transform3D(Basis(Vector3.RIGHT, -0.5), Vector3(0, 0.85, 0.05))
			kit.box(Vector3.ZERO, Vector3(1.6, 0.05, 0.85), WOOD2)
			kit.box(Vector3(0, 0.03, 0), Vector3(0.9, 0.01, 0.6), WHITE)
			for i in 6:
				kit.box(Vector3(-0.3 + float(i % 3) * 0.3, 0.035, -0.18 + float(i / 3) * 0.36), Vector3(0.26, 0.005, 0.3), Color("f8f4e8"))
			kit.xf = saved5
			kit.layer = "lumiere"
			kit.blob(Vector3(0.7, 1.45, -0.1), Vector3(0.1, 0.06, 0.1), LIGHT, LIGHT, 0.0, 0)
			kit.layer = "base"
			kit.beam(Vector3(0.75, 0.9, -0.3), Vector3(0.7, 1.4, -0.1), 0.02, 0.02, DARK)
			kit.box(Vector3(-0.35, 0.72, 0.45), Vector3(0.4, 0.05, 0.3), WOOD)
		"coin_lecture":
			for sx in [-0.5, 0.5]:
				kit.lathe(Vector3(sx, 0, 0.4), [Vector2(0.3, 0.0), Vector2(0.32, 0.2), Vector2(0.25, 0.38), Vector2(0.0, 0.4)], 10, [Color("e76f51"), Color("2a9d8f")][int(sx + 0.5)] as Color)
			kit.box(Vector3(0, 0.3, -0.6), Vector3(1.6, 0.6, 0.5), WOOD2)
			var bc := [Color("e9c46a"), Color("1d3557"), Color("d62828"), Color("2a9d8f"), Color("f4a261")]
			for i in 10:
				kit.box(Vector3(-0.7 + i * 0.155, 0.7, -0.6), Vector3(0.12, 0.2, 0.35), bc[i % bc.size()] as Color)
		"fusee_bd":
			kit.box(Vector3(0, 0.05, 0), Vector3(1.8, 0.1, 1.8), Color("3a3d42"))
			for i in 3:
				var a8 := float(i) * TAU / 3.0
				kit.beam(Vector3(cos(a8) * 0.3, 1.1, sin(a8) * 0.3), Vector3(cos(a8) * 0.75, 0.1, sin(a8) * 0.75), 0.06, 0.4, RED)
			kit.lathe(Vector3(0, 0.3, 0), [Vector2(0.15, 0.0), Vector2(0.42, 0.3), Vector2(0.45, 1.2), Vector2(0.3, 2.0), Vector2(0.0, 2.55)], 12, WHITE,
				true, true, func(i: int, r: int) -> Color: return RED if (i + r) % 2 == 0 else WHITE)
			kit.layer = "verre"
			kit.tube(Vector3(0, 1.6, 0.4), Vector3(0, 1.6, 0.47), 0.12, 0.12, 8, GLASS)
			kit.layer = "base"
		# --- Vin et gastronomie ------------------------------------------------------------------
		"alambic":
			kit.box(Vector3(0, 0.25, 0), Vector3(0.9, 0.5, 0.9), Color("7a4a3a"))
			kit.blob(Vector3(0, 0.85, 0), Vector3(0.5, 0.4, 0.5), COPPER, COPPER.lightened(0.2), 0.0, 1)
			kit.tube(Vector3(0, 1.2, 0), Vector3(0, 1.55, 0), 0.15, 0.06, 8, COPPER)
			kit.beam(Vector3(0, 1.55, 0), Vector3(0.6, 1.25, 0.3), 0.05, 0.05, COPPER)
			kit.tube(Vector3(0.65, 0.0, 0.35), Vector3(0.65, 1.2, 0.35), 0.28, 0.28, 10, WOOD)
			for i in 3:
				kit.lathe(Vector3(0.65, 0.2 + i * 0.4, 0.35), [Vector2(0.29, 0.0), Vector2(0.29, 0.04)], 10, DARK)
		"tonneaux":
			for x in [-0.45, 0.45]:
				kit.box(Vector3(x, 0.08, 0), Vector3(0.2, 0.16, 0.7), WOOD.darkened(0.3))
				var saved6 := kit.xf
				kit.xf = saved6 * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(x, 0.5, -0.35))
				kit.lathe(Vector3.ZERO, [Vector2(0.3, 0.0), Vector2(0.38, 0.35), Vector2(0.3, 0.7)], 10, WOOD2)
				kit.xf = saved6
				for z in [-0.25, 0.25]:
					kit.tube(Vector3(x, 0.5, z - 0.02), Vector3(x, 0.5, z + 0.02), 0.37, 0.37, 10, DARK, false)
			kit.blob(Vector3(0, 1.0, 0), Vector3(0.1, 0.1, 0.1), WOOD2, WOOD2, 0.0, 0)
		"pressoir":
			kit.box(Vector3(0, 0.3, 0), Vector3(1.8, 0.6, 1.8), WOOD.darkened(0.15))
			kit.tube(Vector3(0, 0.6, 0), Vector3(0, 1.1, 0), 0.6, 0.6, 12, WOOD2, false)
			for i in 12:
				var a9 := float(i) * TAU / 12.0
				kit.box(Vector3(cos(a9) * 0.6, 0.85, sin(a9) * 0.6), Vector3(0.06, 0.5, 0.06), WOOD)
			kit.lathe(Vector3(0, 0.62, 0), [Vector2(0.55, 0.0), Vector2(0.55, 0.3)], 10, Color("5a1a3a"))
			kit.tube(Vector3(0, 1.1, 0), Vector3(0, 2.1, 0), 0.08, 0.08, 6, DARK)
			for sx in [-0.8, 0.8]:
				kit.box(Vector3(sx, 1.3, 0), Vector3(0.15, 1.6, 0.2), WOOD)
			kit.box(Vector3(0, 2.05, 0), Vector3(1.75, 0.18, 0.22), WOOD)
			kit.beam(Vector3(-0.6, 1.5, 0), Vector3(0.6, 1.5, 0), 0.08, 0.08, WOOD2)
		"fourneau":
			kit.box(Vector3(0, 0.45, -0.15), Vector3(1.8, 0.9, 0.65), BLACK)
			kit.box(Vector3(0, 0.91, -0.15), Vector3(1.85, 0.03, 0.7), STEEL)
			for sx in [-0.5, 0.0, 0.5]:
				kit.box(Vector3(sx, 0.45, 0.18), Vector3(0.38, 0.35, 0.02), Color("3a3a3a"))
				kit.box(Vector3(sx, 0.55, 0.2), Vector3(0.15, 0.03, 0.03), GOLD)
			kit.lathe(Vector3(-0.45, 0.93, -0.1), [Vector2(0.18, 0.0), Vector2(0.18, 0.2)], 10, COPPER)
			kit.lathe(Vector3(0.35, 0.93, -0.15), [Vector2(0.14, 0.0), Vector2(0.16, 0.25), Vector2(0.06, 0.32)], 10, COPPER)
			kit.tube(Vector3(0.7, 0.93, -0.35), Vector3(0.7, 2.6, -0.35), 0.1, 0.1, 6, BLACK)
			for i in 4:
				kit.blob(Vector3(-0.6 + i * 0.4, 1.4, -0.45), Vector3(0.1, 0.1, 0.03), COPPER, COPPER.lightened(0.2), 0.0, 0)
		"chaudron":
			kit.box(Vector3(0, 0.2, 0), Vector3(1.0, 0.4, 1.0), Color("6a6a62"))
			kit.lathe(Vector3(0, 0.4, 0), [Vector2(0.15, 0.0), Vector2(0.48, 0.3), Vector2(0.5, 0.7)], 12, COPPER, true, false)
			kit.beam(Vector3(-0.5, 1.3, 0), Vector3(0.5, 1.3, 0), 0.06, 0.06, WOOD)
			kit.beam(Vector3(-0.55, 0.0, 0), Vector3(-0.5, 1.35, 0), 0.08, 0.08, WOOD)
			for i in 3:
				kit.lathe(Vector3(0.7, 0.0 + i * 0.16, 0.6), [Vector2(0.25, 0.0), Vector2(0.26, 0.08), Vector2(0.25, 0.15)], 10, Color("e8c860"))
			kit.lathe(Vector3(-0.7, 0.0, 0.65), [Vector2(0.25, 0.0), Vector2(0.26, 0.08), Vector2(0.25, 0.15)], 10, Color("e8c860"))
		_:
			return false
	return true


## Contenu d'une vitrine-cloche ; false si inconnu.
static func cloche(kit: LpKit, c: String, at: Vector3) -> bool:
	match c:
		"roche_lunaire":
			kit.stone(at + Vector3(0, 0.1, 0), Vector3(0.22, 0.16, 0.18), Color("8a8a88"))
		"statuette":
			kit.box(at + Vector3(0, 0.04, 0), Vector3(0.12, 0.08, 0.12), BLACK)
			MuseeModeles._figure(kit, at + Vector3(0, 0.08, 0), 0.2, GOLD, false)
		"coupe":
			kit.box(at + Vector3(0, 0.04, 0), Vector3(0.16, 0.08, 0.16), BLACK)
			kit.lathe(at + Vector3(0, 0.08, 0), [Vector2(0.06, 0.0), Vector2(0.02, 0.12), Vector2(0.12, 0.3), Vector2(0.14, 0.42)], 10, GOLD)
			for sx in [-1, 1]:
				kit.beam(at + Vector3(sx * 0.13, 0.4, 0), at + Vector3(sx * 0.2, 0.28, 0), 0.02, 0.02, GOLD)
		"violon":
			var saved := kit.xf
			kit.xf = saved * Transform3D(Basis(Vector3.RIGHT, -0.3), at + Vector3(0, 0.05, 0))
			kit.blob(Vector3(0, 0.13, 0), Vector3(0.1, 0.13, 0.03), Color("8a3a1a"), Color("a8582a"), 0.03, 0)
			kit.box(Vector3(0, 0.36, 0), Vector3(0.03, 0.24, 0.025), BLACK)
			kit.xf = saved
		"robot_jouet":
			var rc := Color("c03a2a")
			kit.box(at + Vector3(0, 0.12, 0), Vector3(0.14, 0.18, 0.1), rc)
			kit.box(at + Vector3(0, 0.27, 0), Vector3(0.1, 0.1, 0.09), STEEL)
			for sx in [-0.04, 0.04]:
				kit.box(at + Vector3(sx, 0.02, 0), Vector3(0.05, 0.05, 0.08), STEEL)
				kit.box(at + Vector3(sx, 0.28, 0.046), Vector3(0.02, 0.02, 0.01), Color("ffd040"))
		"cranes":
			for i in 3:
				var x := -0.15 + i * 0.15
				kit.blob(at + Vector3(x, 0.07, 0), Vector3(0.05, 0.05, 0.065), BONE, BONE.lightened(0.1), 0.03, 0)
				kit.box(at + Vector3(x, 0.05, 0.05), Vector3(0.05, 0.02, 0.02), BONE.darkened(0.2))
		"venus":
			kit.box(at + Vector3(0, 0.03, 0), Vector3(0.14, 0.06, 0.14), BLACK)
			var vc := Color("b0905a")
			kit.blob(at + Vector3(0, 0.15, 0), Vector3(0.06, 0.08, 0.05), vc, vc.lightened(0.1), 0.05, 1)
			kit.blob(at + Vector3(0, 0.25, 0), Vector3(0.03, 0.04, 0.03), vc, vc, 0.05, 0)
		_:
			return false
	return true


## Contenu d'une vitrine (murale ou de table) pour les nouveaux thèmes.
static func contenu(kit: LpKit, c: String, at: Vector3, w: float, d: float, _h: float) -> void:
	match c:
		"montres":
			for i in 8:
				var p := at + Vector3(-w * 0.42 + (i % 4) * w * 0.27, 0.01, -0.12 + (i / 4) * 0.24)
				kit.lathe(p, [Vector2(0.05, 0.0), Vector2(0.05, 0.015)], 10, GOLD if i % 2 == 0 else STEEL)
				kit.lathe(p + Vector3(0, 0.015, 0), [Vector2(0.04, 0.0), Vector2(0.04, 0.002)], 10, WHITE)
		"medailles":
			for i in 9:
				var col := [GOLD, Color("c0c4c8"), Color("b0703a")][i % 3] as Color
				var p2 := at + Vector3(-w * 0.4 + i * w * 0.1, 0.01, 0.0)
				kit.box(p2 + Vector3(0, 0.0, -0.12), Vector3(0.04, 0.005, 0.2), [Color("1d3557"), RED, WHITE][i % 3] as Color)
				kit.lathe(p2 + Vector3(0, 0.0, 0.05), [Vector2(0.04, 0.0), Vector2(0.04, 0.01)], 8, col)
		"ballons":
			for j in 2:
				for i in 3:
					var bc := [WHITE, Color("8a5a3a"), Color("e9c46a")][(i + j) % 3] as Color
					kit.blob(at + Vector3(-w * 0.33 + i * w * 0.33, 0.13 + j * 0.45, -0.05), Vector3(0.12, 0.12, 0.12), bc, bc.darkened(0.15), 0.02, 1)
			kit.box(at + Vector3(0, 0.42, 0), Vector3(w, 0.02, d), Color("e0e0e0"))
		"chapeaux":
			for j in 2:
				for i in 3:
					var hc := [BLACK, Color("8e1e24"), Color("e6d4b8"), Color("1d3557"), Color("6a8a3a"), WHITE][i + j * 3] as Color
					var p3 := at + Vector3(-w * 0.33 + i * w * 0.33, 0.0 + j * 0.45, -0.05)
					kit.lathe(p3, [Vector2(0.16, 0.0), Vector2(0.16, 0.015), Vector2(0.09, 0.02), Vector2(0.08, 0.12 + float(i) * 0.03)], 10, hc)
			kit.box(at + Vector3(0, 0.42, 0), Vector3(w, 0.02, d), Color("e0e0e0"))
		"chaussures":
			for i in 5:
				var sc := [RED, BLACK, Color("e6d4b8"), Color("c03a8a"), Color("8a5a3a")][i] as Color
				var p4 := at + Vector3(-w * 0.38 + i * w * 0.19, 0.0, 0.0)
				kit.box(p4 + Vector3(0, 0.03, 0.04), Vector3(0.07, 0.05, 0.16), sc)
				kit.box(p4 + Vector3(0, 0.05, -0.08), Vector3(0.06, 0.1, 0.06), sc)
		"consoles":
			for j in 2:
				for i in 3:
					var p5 := at + Vector3(-w * 0.33 + i * w * 0.33, 0.0 + j * 0.45, -0.05)
					kit.box(p5 + Vector3(0, 0.04, 0), Vector3(0.2, 0.07, 0.14), [Color("3a3d42"), WHITE, Color("6a6a9a")][(i + j) % 3] as Color)
					kit.box(p5 + Vector3(0.0, 0.03, 0.12), Vector3(0.1, 0.03, 0.06), BLACK)
			kit.box(at + Vector3(0, 0.42, 0), Vector3(w, 0.02, d), Color("e0e0e0"))
		"soldats":
			for i in 12:
				var col2 := Color("1d3557") if i < 6 else RED
				var p6 := at + Vector3(-w * 0.4 + (i % 6) * w * 0.15, 0.0, -0.12 + (i / 6) * 0.24)
				kit.box(p6 + Vector3(0, 0.04, 0), Vector3(0.03, 0.08, 0.02), col2)
				kit.box(p6 + Vector3(0, 0.1, 0), Vector3(0.025, 0.04, 0.025), BLACK)
		"silex":
			for i in 8:
				var p7 := at + Vector3(-w * 0.4 + (i % 4) * w * 0.26, 0.01, -0.12 + (i / 4) * 0.24)
				kit.tri(p7 + Vector3(-0.05, 0.01, -0.06), p7 + Vector3(0.05, 0.01, -0.06), p7 + Vector3(0, 0.01, 0.08), Color("8a7a6a"), Vector3.UP)
				kit.box(p7 + Vector3(0, 0.005, 0), Vector3(0.07, 0.01, 0.1), Color("6a5a4a"))
		"bouteilles":
			for j in 2:
				for i in 6:
					var p8 := at + Vector3(-w * 0.42 + i * w * 0.17, 0.0 + j * 0.45, -0.05)
					var bc2 := Color("2a3a1a") if (i + j) % 2 == 0 else Color("5a1a2a")
					kit.lathe(p8, [Vector2(0.04, 0.0), Vector2(0.04, 0.2), Vector2(0.015, 0.27), Vector2(0.015, 0.32)], 6, bc2)
					kit.box(p8 + Vector3(0, 0.1, 0.04), Vector3(0.05, 0.06, 0.005), Color("f0e6c8"))
			kit.box(at + Vector3(0, 0.42, 0), Vector3(w, 0.02, d), Color("e0e0e0"))
		_:
			pass


## Peinture d'un cadre (affiches, maillots, photos, planches) ; false si inconnu.
static func peinture(kit: LpKit, c: String, inner: Vector3, iw: float, ih: float) -> bool:
	match c:
		"affiche_train":
			kit.box(inner, Vector3(iw, ih, 0.01), Color("f2e6c8"))
			kit.box(inner + Vector3(0, ih * 0.15, 0.004), Vector3(iw * 0.9, ih * 0.5, 0.005), Color("7ab0d8"))
			kit.tri(inner + Vector3(-iw * 0.45, ih * -0.05, 0.007), inner + Vector3(iw * 0.1, ih * -0.05, 0.007), inner + Vector3(-iw * 0.15, ih * 0.3, 0.007), WHITE, Vector3.BACK)
			kit.box(inner + Vector3(iw * 0.1, -ih * 0.05, 0.008), Vector3(iw * 0.6, ih * 0.08, 0.005), RED)
			kit.box(inner + Vector3(0, -ih * 0.35, 0.006), Vector3(iw * 0.8, ih * 0.1, 0.005), Color("1d3557"))
		"affiche", "affiche_pub":
			var bg := Color("1d1d2a") if c == "affiche" else Color("e9c46a")
			kit.box(inner, Vector3(iw, ih, 0.01), bg)
			kit.blob(inner + Vector3(0, ih * 0.1, 0.006), Vector3(iw * 0.25, ih * 0.25, 0.005), RED if c == "affiche" else Color("2a9d8f"), Color("f4a261"), 0.05, 0)
			kit.box(inner + Vector3(0, ih * 0.38, 0.006), Vector3(iw * 0.8, ih * 0.1, 0.005), Color("f2d024") if c == "affiche" else RED)
			kit.box(inner + Vector3(0, -ih * 0.35, 0.006), Vector3(iw * 0.7, ih * 0.06, 0.005), WHITE if c == "affiche" else Color("1d3557"))
		"plaques":
			for i in 3:
				var pc := [Color("1d3557"), RED, Color("2a7a3a")][i] as Color
				kit.box(inner + Vector3(-iw * 0.32 + i * iw * 0.32, 0, 0), Vector3(iw * 0.28, ih * 0.7, 0.01), pc)
				kit.box(inner + Vector3(-iw * 0.32 + i * iw * 0.32, 0, 0.006), Vector3(iw * 0.2, ih * 0.12, 0.005), WHITE)
		"maillot":
			kit.box(inner, Vector3(iw, ih, 0.01), Color("e8e8e8"))
			kit.box(inner + Vector3(0, -ih * 0.05, 0.006), Vector3(iw * 0.45, ih * 0.6, 0.005), Color("1d4e9e"))
			for sx in [-1, 1]:
				kit.box(inner + Vector3(sx * iw * 0.3, ih * 0.15, 0.006), Vector3(iw * 0.2, ih * 0.15, 0.005), Color("1d4e9e"))
			kit.box(inner + Vector3(0, ih * 0.0, 0.008), Vector3(iw * 0.15, ih * 0.2, 0.003), WHITE)
		"photos":
			for i in 3:
				kit.box(inner + Vector3(-iw * 0.32 + i * iw * 0.32, 0, 0), Vector3(iw * 0.28, ih * 0.75, 0.01), WHITE)
				kit.box(inner + Vector3(-iw * 0.32 + i * iw * 0.32, 0, 0.005), Vector3(iw * 0.24, ih * 0.6, 0.005), Color(0.2 + i * 0.15, 0.2 + i * 0.15, 0.2 + i * 0.15))
				kit.blob(inner + Vector3(-iw * 0.32 + i * iw * 0.32, -ih * 0.05, 0.008), Vector3(0.05, 0.1, 0.004), Color(0.75, 0.75, 0.75), WHITE, 0.0, 0)
		"planche", "couverture":
			kit.box(inner, Vector3(iw, ih, 0.01), Color("faf6ea"))
			if c == "planche":
				for j in 3:
					for i in 2:
						kit.box(inner + Vector3(-iw * 0.22 + i * iw * 0.44, ih * 0.28 - j * ih * 0.3, 0.005), Vector3(iw * 0.4, ih * 0.26, 0.004), [Color("8ab4d8"), Color("e9c46a"), Color("f4a261"), Color("b8d8a8")][(i + j) % 4] as Color)
						kit.blob(inner + Vector3(-iw * 0.22 + i * iw * 0.44, ih * 0.26 - j * ih * 0.3, 0.008), Vector3(0.04, 0.06, 0.003), Color("e8c8a0"), Color("e8c8a0"), 0.0, 0)
			else:
				kit.box(inner + Vector3(0, -ih * 0.05, 0.005), Vector3(iw * 0.9, ih * 0.7, 0.004), Color("5a8ac0"))
				kit.box(inner + Vector3(0, ih * 0.4, 0.005), Vector3(iw * 0.8, ih * 0.12, 0.004), RED)
				kit.blob(inner + Vector3(-iw * 0.1, -ih * 0.1, 0.008), Vector3(0.1, 0.22, 0.004), Color("f2d024"), Color("e8c8a0"), 0.0, 0)
				kit.blob(inner + Vector3(iw * 0.2, -ih * 0.2, 0.008), Vector3(0.12, 0.08, 0.004), WHITE, WHITE, 0.0, 0)
		_:
			return false
	return true


# --- Morceaux --------------------------------------------------------------------------------------

static func _locomotive(kit: LpKit, w: float) -> void:
	var l := w - 0.4
	kit.box(Vector3(0, 0.05, 0), Vector3(w - 0.1, 0.1, 1.6), Color("6a5a48"))
	for sz in [-0.72, 0.72]:
		kit.box(Vector3(0, 0.14, sz), Vector3(w - 0.2, 0.08, 0.08), STEEL)
	var body := Color("1f3d2a")
	kit.box(Vector3(0, 0.8, 0), Vector3(l, 0.25, 1.7), BLACK)
	kit.tube(Vector3(-l * 0.5 + 0.6, 1.45, 0), Vector3(l * 0.5 - 2.4, 1.45, 0), 0.62, 0.62, 12, body)
	kit.tube(Vector3(-l * 0.5 + 0.5, 1.45, 0), Vector3(-l * 0.5 + 0.62, 1.45, 0), 0.55, 0.55, 12, BLACK)
	kit.tube(Vector3(-l * 0.5 + 1.0, 2.05, 0), Vector3(-l * 0.5 + 1.0, 2.75, 0), 0.16, 0.24, 8, BLACK)
	kit.blob(Vector3(-l * 0.5 + 2.2, 2.08, 0), Vector3(0.22, 0.18, 0.22), GOLD, GOLD.lightened(0.2), 0.0, 1)
	kit.box(Vector3(l * 0.5 - 1.6, 1.65, 0), Vector3(1.5, 1.6, 1.8), body)
	kit.box(Vector3(l * 0.5 - 1.6, 2.5, 0), Vector3(1.7, 0.1, 2.0), BLACK)
	for sz2 in [-0.91, 0.91]:
		kit.box(Vector3(l * 0.5 - 1.6, 1.95, sz2), Vector3(0.7, 0.55, 0.02), Color("c8d8e0"))
	kit.box(Vector3(l * 0.5 - 0.4, 1.0, 0), Vector3(0.8, 0.8, 1.7), BLACK)
	for i in 3:
		var x := -l * 0.5 + 1.6 + float(i) * 1.15
		for sz3 in [-0.82, 0.82]:
			kit.tube(Vector3(x, 0.62, sz3 - 0.05), Vector3(x, 0.62, sz3 + 0.05), 0.55, 0.55, 14, RED)
			kit.tube(Vector3(x, 0.62, sz3 - 0.06), Vector3(x, 0.62, sz3 + 0.06), 0.12, 0.12, 6, BLACK)
	for sz4 in [-0.9, 0.9]:
		kit.beam(Vector3(-l * 0.5 + 1.6, 0.62, sz4), Vector3(-l * 0.5 + 3.9, 0.62, sz4), 0.06, 0.1, STEEL)
	kit.box(Vector3(-l * 0.5 + 0.2, 0.55, 0), Vector3(0.3, 0.5, 1.6), RED)
	kit.layer = "lumiere"
	kit.tube(Vector3(-l * 0.5 + 0.48, 2.05, 0), Vector3(-l * 0.5 + 0.4, 2.05, 0), 0.12, 0.12, 8, LIGHT)
	kit.layer = "base"


static func _table_maquette(kit: LpKit, w: float, d: float, jouet: bool) -> void:
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			kit.box(Vector3(sx * (w * 0.5 - 0.2), 0.4, sz * (d * 0.5 - 0.2)), Vector3(0.08, 0.8, 0.08), WOOD)
	kit.box(Vector3(0, 0.82, 0), Vector3(w - 0.2, 0.06, d - 0.2), WOOD)
	kit.box(Vector3(0, 0.86, 0), Vector3(w - 0.3, 0.02, d - 0.3), Color("6a9a4a") if not jouet else Color("8ab4d8"))
	var rx := w * 0.5 - 0.45
	var rz := d * 0.5 - 0.45
	for i in 16:
		var a := float(i) * TAU / 16.0
		var b := float(i + 1) * TAU / 16.0
		kit.beam(Vector3(cos(a) * rx, 0.88, sin(a) * rz), Vector3(cos(b) * rx, 0.88, sin(b) * rz), 0.08, 0.015, Color("5a5a5a"))
	var tc := [RED, Color("1d3557"), Color("f2d024")]
	for i2 in 3:
		var a2 := 0.3 + float(i2) * 0.32
		kit.box(Vector3(cos(a2) * rx, 0.94, sin(a2) * rz), Vector3(0.12, 0.1, 0.22).rotated(Vector3.UP, 0.0), tc[i2] as Color)
	if not jouet:
		kit.lathe(Vector3(-0.4, 0.87, 0), [Vector2(0.35, 0.0), Vector2(0.0, 0.4)], 6, Color("8a8a7a"))
		for i3 in 3:
			kit.box(Vector3(0.2 + i3 * 0.25, 0.92, 0.0), Vector3(0.15, 0.12, 0.12), [WHITE, Color("e8c8a0"), Color("c8a888")][i3] as Color)
	else:
		kit.box(Vector3(0, 0.95, 0), Vector3(0.3, 0.15, 0.2), Color("f4a261"))
	if not jouet:
		kit.layer = "verre"
		kit.box(Vector3(0, 1.0, 0), Vector3(w - 0.2, 0.3, d - 0.2), GLASS)
		kit.layer = "base"


## Voiture ancienne ou de course : longueur d, couleur, hauteur de caisse, rayon des roues.
static func _voiture(kit: LpKit, d: float, col: Color, haut: float, r: float, course: bool, longue: bool) -> void:
	var l := d - 0.3
	kit.box(Vector3(0, 0.03, 0), Vector3(1.8, 0.06, d - 0.1), Color("54585e"))
	if course:
		kit.blob(Vector3(0, 0.45, 0), Vector3(0.7, 0.28, l * 0.5), col, col.lightened(0.15), 0.0, 1)
		kit.box(Vector3(0, 0.62, -0.2), Vector3(0.5, 0.2, 0.6), BLACK)
		kit.blob(Vector3(0, 0.72, -0.6), Vector3(0.2, 0.15, 0.3), col, col, 0.0, 0)
		kit.lathe(Vector3(0, 0.45, l * 0.5 - 0.05), [Vector2(0.18, 0.0), Vector2(0.18, 0.02)], 8, BLACK)
		kit.blob(Vector3(0.3, 0.6, 0.5), Vector3(0.12, 0.12, 0.01) * Vector3(1, 1, 1), WHITE, WHITE, 0.0, 0)
	else:
		kit.box(Vector3(0, r + 0.15, 0), Vector3(1.5, 0.3, l), col)
		kit.box(Vector3(0, r + haut * 0.5 + 0.2, -l * 0.08), Vector3(1.4, haut, l * (0.5 if longue else 0.55)), col.darkened(0.08))
		kit.layer = "verre"
		kit.box(Vector3(0, r + haut * 0.55 + 0.25, -l * 0.08), Vector3(1.42, haut * 0.5, l * (0.48 if longue else 0.53)), GLASS)
		kit.layer = "base"
		kit.box(Vector3(0, r + haut + 0.22, -l * 0.08), Vector3(1.4, 0.06, l * (0.5 if longue else 0.55)), col.darkened(0.08))
		if longue:
			kit.box(Vector3(0, r + 0.42, l * 0.33), Vector3(0.9, 0.3, l * 0.3), col)
			kit.box(Vector3(0, r + 0.42, l * 0.5 - 0.02), Vector3(0.7, 0.4, 0.04), STEEL)
			for sx in [-0.65, 0.65]:
				kit.beam(Vector3(sx, r + 0.1, l * 0.38), Vector3(sx, r + 0.1, -l * 0.2), 0.25, 0.04, col.darkened(0.2))
		for sx2 in [-0.45, 0.45]:
			kit.layer = "lumiere"
			kit.tube(Vector3(sx2, r + 0.35, l * 0.5 - 0.02), Vector3(sx2, r + 0.35, l * 0.5 + 0.03), 0.09, 0.09, 6, LIGHT)
			kit.layer = "base"
	for sx3 in [-0.72, 0.72]:
		for sz in [-l * 0.33, l * 0.33]:
			kit.tube(Vector3(sx3 - 0.09, r + 0.03, sz), Vector3(sx3 + 0.09, r + 0.03, sz), r, r, 12, BLACK)
			kit.tube(Vector3(sx3 - 0.1, r + 0.03, sz), Vector3(sx3 + 0.1, r + 0.03, sz), r * 0.5, r * 0.5, 8, STEEL)


static func _monoplace(kit: LpKit, d: float) -> void:
	var l := d - 0.3
	var col := Color("d4161f")
	kit.box(Vector3(0, 0.03, 0), Vector3(1.9, 0.06, d - 0.1), Color("54585e"))
	kit.beam(Vector3(0, 0.33, -l * 0.42), Vector3(0, 0.25, l * 0.48), 0.5, 0.25, col)
	kit.box(Vector3(0, 0.35, -0.2), Vector3(1.1, 0.3, 1.4), col)
	kit.box(Vector3(0, 0.52, 0.2), Vector3(0.45, 0.12, 0.6), BLACK)
	kit.box(Vector3(0, 0.62, -0.15), Vector3(0.3, 0.3, 0.3), col)
	kit.box(Vector3(0, 0.12, l * 0.5 - 0.1), Vector3(1.7, 0.04, 0.35), col)
	kit.box(Vector3(0, 0.75, -l * 0.5 + 0.15), Vector3(1.0, 0.04, 0.3), col)
	for sx in [-0.45, 0.45]:
		kit.box(Vector3(sx, 0.5, -l * 0.5 + 0.15), Vector3(0.04, 0.5, 0.3), BLACK)
	for sx2 in [-0.78, 0.78]:
		for sz in [-l * 0.33, l * 0.32]:
			kit.tube(Vector3(sx2 - 0.17, 0.34, sz), Vector3(sx2 + 0.17, 0.34, sz), 0.32, 0.32, 12, BLACK)
			kit.beam(Vector3(sx2 * 0.5, 0.35, sz), Vector3(sx2, 0.34, sz), 0.04, 0.04, BLACK)
	kit.blob(Vector3(0, 0.66, 0.2), Vector3(0.12, 0.12, 0.13), Color("f2d024"), WHITE, 0.0, 1)


static func _module_lunaire(kit: LpKit) -> void:
	kit.box(Vector3(0, 0.03, 0), Vector3(3.8, 0.06, 3.8), Color("8a8a88"))
	for i in 4:
		var a := float(i) * TAU / 4.0 + PI * 0.25
		var foot := Vector3(cos(a) * 1.6, 0.1, sin(a) * 1.6)
		kit.beam(Vector3(cos(a) * 0.8, 1.1, sin(a) * 0.8), foot + Vector3(0, 0.1, 0), 0.07, 0.07, STEEL)
		kit.lathe(foot, [Vector2(0.25, 0.0), Vector2(0.18, 0.08)], 8, STEEL)
	kit.box(Vector3(0, 0.9, 0), Vector3(1.8, 0.8, 1.8), GOLD)
	kit.box(Vector3(0, 1.75, 0), Vector3(1.5, 0.9, 1.4), Color("c8ccd0"))
	kit.box(Vector3(0, 2.3, 0), Vector3(0.9, 0.3, 0.9), Color("9aa3ab"))
	kit.layer = "verre"
	for sx in [-0.35, 0.35]:
		kit.tri(Vector3(sx - 0.2, 1.6, 0.71), Vector3(sx + 0.2, 1.6, 0.71), Vector3(sx, 1.95, 0.71), Color(0.2, 0.25, 0.3), Vector3.BACK)
	kit.layer = "base"
	kit.lathe(Vector3(0.6, 2.45, -0.4), [Vector2(0.02, 0.0), Vector2(0.3, 0.12)], 8, WHITE)
	kit.box(Vector3(0, 1.2, 0.92), Vector3(0.6, 0.06, 0.6), STEEL)


static func _astronaute(kit: LpKit, at: Vector3) -> void:
	var sc := Color("eeeeea")
	for sx in [-0.12, 0.12]:
		kit.box(at + Vector3(sx, 0.07, 0.04), Vector3(0.17, 0.14, 0.3), Color("9aa3ab"))
		kit.tube(at + Vector3(sx, 0.14, 0), at + Vector3(sx, 0.9, 0), 0.1, 0.1, 6, sc)
	kit.box(at + Vector3(0, 1.2, 0), Vector3(0.5, 0.65, 0.3), sc)
	kit.box(at + Vector3(0, 1.25, -0.25), Vector3(0.45, 0.6, 0.22), Color("d8d8d0"))
	kit.box(at + Vector3(0, 1.2, 0.16), Vector3(0.18, 0.14, 0.03), Color("1d3557"))
	for sx2 in [-0.32, 0.32]:
		kit.tube(at + Vector3(sx2, 1.45, 0), at + Vector3(sx2 * 1.1, 0.95, 0.05), 0.08, 0.08, 6, sc)
		kit.blob(at + Vector3(sx2 * 1.1, 0.9, 0.05), Vector3(0.07, 0.07, 0.07), Color("9aa3ab"), Color("9aa3ab"), 0.0, 0)
	kit.blob(at + Vector3(0, 1.7, 0), Vector3(0.2, 0.2, 0.2), sc, sc, 0.0, 1)
	kit.layer = "verre"
	kit.blob(at + Vector3(0, 1.7, 0.08), Vector3(0.15, 0.13, 0.13), GOLD, GOLD, 0.0, 1)
	kit.layer = "base"


static func _bateau(kit: LpKit, at: Vector3, s: float) -> void:
	_coque(kit, at, 0.32 * s, 1.5 * s, 0.25 * s, WOOD, WOOD.darkened(0.2))
	for i in 3:
		var x := (-0.4 + i * 0.4) * s
		kit.tube(at + Vector3(0, 0.15 * s, x), at + Vector3(0, (0.9 - absf(float(i - 1)) * 0.15) * s, x), 0.012, 0.01, 4, WOOD)
		for j in 2:
			kit.box(at + Vector3(0, (0.4 + j * 0.25) * s, x), Vector3(0.36 * s - j * 0.05, 0.18 * s, 0.01), Color("efe6d0"))


## Coque de bateau (proue vers +Z) : largeur, longueur, hauteur.
static func _coque(kit: LpKit, at: Vector3, larg: float, longueur: float, haut: float, col: Color, bas: Color) -> void:
	kit.blob(at + Vector3(0, haut * 0.55, 0), Vector3(larg * 0.5, haut * 0.6, longueur * 0.5), bas, col, 0.0, 1)
	kit.box(at + Vector3(0, haut * 1.05, 0), Vector3(larg * 0.85, 0.04, longueur * 0.8), WOOD2)
	for i in 3:
		kit.box(at + Vector3(0, haut * 1.1, (-0.25 + i * 0.25) * longueur), Vector3(larg * 0.8, 0.05, 0.12), WOOD)


static func _trepied(kit: LpKit, h: float) -> void:
	for i in 3:
		var a := float(i) * TAU / 3.0
		kit.beam(Vector3(cos(a) * 0.35, 0, sin(a) * 0.35), Vector3(0, h, 0), 0.035, 0.035, WOOD)


static func _robe(kit: LpKit, c: String) -> void:
	var col := {"couture": Color("1c1c1c"), "bal": Color("d8a8c0"), "tailleur": Color("c8b48a"), "smoking": Color("1c1c24")}.get(c, RED) as Color
	kit.box(Vector3(0, 0.04, 0), Vector3(0.6 if c != "bal" else 1.6, 0.08, 0.6 if c != "bal" else 1.6), DARK)
	kit.tube(Vector3(0, 0.08, 0), Vector3(0, 0.5, 0), 0.02, 0.02, 4, DARK)
	match c:
		"bal":
			kit.lathe(Vector3(0, 0.08, 0), [Vector2(0.75, 0.0), Vector2(0.7, 0.3), Vector2(0.45, 0.85), Vector2(0.14, 1.05)], 12, col,
				true, true, func(i: int, _r: int) -> Color: return col if i % 2 == 0 else col.lightened(0.15))
			kit.lathe(Vector3(0, 1.05, 0), [Vector2(0.13, 0.0), Vector2(0.16, 0.25), Vector2(0.17, 0.4)], 8, col.lightened(0.1))
		"smoking":
			for sx in [-0.09, 0.09]:
				kit.tube(Vector3(sx, 0.1, 0), Vector3(sx, 0.95, 0), 0.08, 0.09, 6, col)
			kit.box(Vector3(0, 1.25, 0), Vector3(0.44, 0.6, 0.24), col)
			kit.tri(Vector3(-0.06, 1.5, 0.125), Vector3(0.06, 1.5, 0.125), Vector3(0, 1.15, 0.125), WHITE, Vector3.BACK)
			kit.box(Vector3(0, 1.48, 0.13), Vector3(0.1, 0.03, 0.01), BLACK)
		"tailleur":
			kit.lathe(Vector3(0, 0.45, 0), [Vector2(0.17, 0.0), Vector2(0.22, 0.45), Vector2(0.17, 0.55)], 8, col)
			kit.box(Vector3(0, 1.25, 0), Vector3(0.4, 0.55, 0.22), col)
			kit.box(Vector3(0, 0.98, 0), Vector3(0.36, 0.04, 0.23), BLACK)
		_:
			kit.lathe(Vector3(0, 0.15, 0), [Vector2(0.35, 0.0), Vector2(0.28, 0.4), Vector2(0.15, 0.95)], 10, col)
			kit.lathe(Vector3(0, 1.1, 0), [Vector2(0.14, 0.0), Vector2(0.17, 0.3), Vector2(0.16, 0.4)], 8, col)
			kit.blob(Vector3(0, 1.45, 0.05), Vector3(0.05, 0.05, 0.05), WHITE, WHITE, 0.0, 0)
	if c != "smoking":
		kit.blob(Vector3(0, 1.62, 0), Vector3(0.18, 0.12, 0.12), Color("e8e0d0"), Color("f0e8d8"), 0.02, 0)
	else:
		for sx2 in [-0.27, 0.27]:
			kit.tube(Vector3(sx2, 1.5, 0), Vector3(sx2 * 1.05, 0.95, 0.05), 0.06, 0.05, 6, col)
		kit.blob(Vector3(0, 1.62, 0), Vector3(0.2, 0.08, 0.12), Color("e8e0d0"), Color("f0e8d8"), 0.02, 0)
	kit.blob(Vector3(0, 1.82, 0), Vector3(0.1, 0.13, 0.1), Color("e8e0d0"), Color("f0e8d8"), 0.03, 0)


static func _piano(kit: LpKit) -> void:
	var pc := BLACK
	kit.box(Vector3(0, 0.82, -0.2), Vector3(1.5, 0.35, 1.0), pc)
	kit.beam(Vector3(-0.75, 0.82, 0.3), Vector3(0.0, 0.82, 1.35), 0.35, 0.35, pc)
	kit.beam(Vector3(0.75, 0.82, 0.3), Vector3(0.1, 0.82, 1.35), 0.35, 0.35, pc)
	kit.box(Vector3(0, 0.82, 0.6), Vector3(1.1, 0.35, 0.8), pc)
	kit.box(Vector3(0, 0.72, -0.82), Vector3(1.45, 0.14, 0.3), pc)
	kit.box(Vector3(0, 0.8, -0.82), Vector3(1.35, 0.02, 0.22), WHITE)
	for i in 10:
		kit.box(Vector3(-0.6 + i * 0.13, 0.82, -0.78), Vector3(0.05, 0.02, 0.12), BLACK)
	for p in [Vector3(-0.65, 0, -0.6), Vector3(0.65, 0, -0.6), Vector3(0.0, 0, 1.2)]:
		kit.box(p + Vector3(0, 0.33, 0), Vector3(0.1, 0.66, 0.1), pc)
	var saved := kit.xf
	kit.xf = saved * Transform3D(Basis(Vector3.RIGHT, 0.6), Vector3(0.0, 1.0, -0.65))
	kit.box(Vector3(0, 0.0, 0.75), Vector3(1.45, 0.03, 1.4), pc)
	kit.xf = saved
	kit.box(Vector3(0, 0.5, -1.25), Vector3(0.6, 0.06, 0.35), pc)
	for sx in [-0.25, 0.25]:
		kit.box(Vector3(sx, 0.25, -1.25), Vector3(0.05, 0.5, 0.3), pc)


static func _heros(kit: LpKit, at: Vector3) -> void:
	var peau := Color("f2c8a0")
	for sx in [-0.09, 0.09]:
		kit.box(at + Vector3(sx, 0.05, 0.05), Vector3(0.14, 0.1, 0.25), Color("6b4a2f"))
		kit.tube(at + Vector3(sx, 0.1, 0), at + Vector3(sx, 0.75, 0), 0.08, 0.08, 6, Color("2a5aa0"))
	kit.box(at + Vector3(0, 1.05, 0), Vector3(0.4, 0.6, 0.24), Color("e8e0c8"))
	kit.box(at + Vector3(0, 1.1, 0.13), Vector3(0.06, 0.4, 0.01), Color("2a5aa0"))
	for sx2 in [-0.25, 0.25]:
		kit.tube(at + Vector3(sx2, 1.3, 0), at + Vector3(sx2 * 1.25, 0.95, 0.12), 0.06, 0.05, 6, Color("e8e0c8"))
	kit.blob(at + Vector3(0, 1.55, 0), Vector3(0.2, 0.22, 0.2), peau, peau, 0.0, 1)
	kit.blob(at + Vector3(0, 1.75, 0.05), Vector3(0.14, 0.08, 0.1), Color("e86a2a"), Color("e86a2a"), 0.05, 0)
	for sx3 in [-0.07, 0.07]:
		kit.blob(at + Vector3(sx3, 1.58, 0.18), Vector3(0.03, 0.04, 0.01), BLACK, BLACK, 0.0, 0)
	kit.blob(at + Vector3(0.25, 0.95, 0.35), Vector3(0.14, 0.12, 0.22), WHITE, WHITE, 0.05, 0)
	kit.blob(at + Vector3(0.25, 1.05, 0.48), Vector3(0.06, 0.06, 0.08), WHITE, WHITE, 0.0, 0)
