class_name MeublesModeles
extends RefCounted
## Modèles low-poly des meubles, entièrement en code (LpKit : faces plates,
## teintes qui varient un peu d'une face à l'autre, ombres peintes).
##
## Repère d'un meuble : centre de son emprise au sol en (0, 0, 0), largeur w le
## long de x, profondeur d le long de z, dos vers −Z (contre le mur), avant
## vers +Z. Les couleurs viennent de la palette du style (bois, tissu, métal…).
## Couches : "base" (opaque), "verre" (transparent), "lumiere" (sans ombre,
## pour les abat-jour, écrans et flammes).

static var _materials: Dictionary = {}


static func materials() -> Dictionary:
	if _materials.is_empty():
		_materials["base"] = LpKit.vertex_material(0.85)
		var g := LpKit.vertex_material(0.1)
		g.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		g.albedo_color = Color(1, 1, 1, 0.38)
		g.cull_mode = BaseMaterial3D.CULL_DISABLED
		_materials["verre"] = g
		var l := StandardMaterial3D.new()
		l.vertex_color_use_as_albedo = true
		l.vertex_color_is_srgb = true
		l.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_materials["lumiere"] = l
	return _materials


static func _c(pal: Dictionary, k: String) -> Color:
	return Color(String(pal.get(k, "888888")))


## Ajoute le meuble e (entrée de Meubles) au kit, posé par xf.
static func build(kit: LpKit, e: Dictionary, xf: Transform3D) -> void:
	var st := Meubles.style_of(String(e.style))
	var pal: Dictionary = st.pal
	kit.xf = xf
	kit.layer = "base"
	kit.rng.seed = hash(String(e.id))
	var w := float(e.w)
	var d := float(e.d)
	var h := float(e.h)
	var era := Meubles.era_index(String(e.era))
	var wood := _c(pal, "bois")
	var wood2 := _c(pal, "bois2")
	var cloth := _c(pal, "tissu")
	var cloth2 := _c(pal, "tissu2")
	var metal := _c(pal, "metal")
	var accent := _c(pal, "accent")
	var stone := _c(pal, "pierre")
	var white := Color("eeeae2")
	var k := String(e.k)
	match k:
		"lit", "baldaquin", "lit_clos", "charpai", "capsule":
			var hw := w * 0.5 - 0.05
			var hd := d * 0.5 - 0.05
			if k == "charpai":
				for sx in [-1, 1]:
					for sz in [-1, 1]:
						kit.box(Vector3(sx * (hw - 0.04), 0.22, sz * (hd - 0.04)), Vector3(0.08, 0.44, 0.08), wood)
				kit.box(Vector3(0, 0.42, 0), Vector3(hw * 2, 0.06, hd * 2), wood2)
				kit.box(Vector3(0, 0.47, 0), Vector3(hw * 1.8, 0.04, hd * 1.8), cloth2)
				kit.box(Vector3(0, 0.52, -hd + 0.25), Vector3(hw * 1.4, 0.08, 0.3), cloth)
			elif k == "capsule":
				kit.box(Vector3(0, 0.25, 0), Vector3(hw * 2, 0.5, hd * 2), white)
				kit.box(Vector3(0, 0.55, 0.05), Vector3(hw * 1.8, 0.12, hd * 1.7), cloth2)
				kit.layer = "verre"
				kit.box(Vector3(0, 0.95, 0), Vector3(hw * 2, 0.7, hd * 2), Color(0.6, 0.85, 1.0))
				kit.layer = "lumiere"
				kit.box(Vector3(0, 0.52, hd - 0.03), Vector3(hw * 1.8, 0.04, 0.03), accent)
				kit.layer = "base"
			else:
				kit.box(Vector3(0, 0.2, 0), Vector3(hw * 2, 0.3, hd * 2), wood)
				kit.box(Vector3(0, 0.43, 0.02), Vector3(hw * 2 - 0.06, 0.18, hd * 2 - 0.08), white)
				kit.box(Vector3(0, 0.53, 0.25), Vector3(hw * 2 - 0.02, 0.05, hd * 1.4), cloth)
				var pillows := 2 if w >= 2.0 else 1
				for i in pillows:
					var px := 0.0 if pillows == 1 else (-0.45 if i == 0 else 0.45)
					kit.box(Vector3(px, 0.58, -hd + 0.3), Vector3(0.7 if pillows == 2 else 0.6, 0.12, 0.35), cloth2.lightened(0.2))
				kit.box(Vector3(0, 0.55, -hd + 0.04), Vector3(hw * 2 + 0.04, 0.9 if k != "lit_clos" else 0.4, 0.08), wood.darkened(0.1))
				if k == "baldaquin":
					for sx in [-1, 1]:
						for sz in [-1, 1]:
							kit.box(Vector3(sx * hw, 1.05, sz * hd), Vector3(0.08, 2.1, 0.08), wood)
					kit.box(Vector3(0, 2.1, 0), Vector3(hw * 2 + 0.1, 0.12, hd * 2 + 0.1), cloth)
					for sx2 in [-1, 1]:
						kit.box(Vector3(sx2 * hw, 1.4, -hd + 0.3), Vector3(0.04, 1.3, 0.5), cloth.darkened(0.1))
				elif k == "lit_clos":
					kit.box(Vector3(0, 1.0, -hd + 0.02), Vector3(hw * 2 + 0.06, 2.0, 0.05), wood)
					kit.box(Vector3(0, 2.0, 0), Vector3(hw * 2 + 0.06, 0.08, hd * 2), wood)
					for sx3 in [-1, 1]:
						kit.box(Vector3(sx3 * (hw + 0.01), 1.0, 0), Vector3(0.05, 2.0, hd * 2), wood.darkened(0.05))
					kit.box(Vector3(-hw * 0.5, 1.1, hd), Vector3(hw, 1.8, 0.05), wood2)
					kit.box(Vector3(-hw * 0.5, 1.25, hd + 0.03), Vector3(hw * 0.6, 0.5, 0.02), wood.darkened(0.3))
					kit.box(Vector3(0, 0.25, hd + 0.2), Vector3(hw * 2, 0.4, 0.35), wood)
				else:
					kit.box(Vector3(0, 0.35, hd - 0.03), Vector3(hw * 2 + 0.04, 0.4, 0.06), wood.darkened(0.1))
		"lit_superpose":
			var hw2 := w * 0.5 - 0.05
			var hd2 := d * 0.5 - 0.05
			for sx in [-1, 1]:
				for sz in [-1, 1]:
					kit.box(Vector3(sx * hw2, 0.85, sz * hd2), Vector3(0.07, 1.7, 0.07), wood)
			for y in [0.3, 1.4]:
				kit.box(Vector3(0, y, 0), Vector3(hw2 * 2, 0.12, hd2 * 2), wood)
				kit.box(Vector3(0, y + 0.12, 0), Vector3(hw2 * 2 - 0.08, 0.14, hd2 * 2 - 0.08), white)
				kit.box(Vector3(0, y + 0.21, 0.25), Vector3(hw2 * 2 - 0.04, 0.04, hd2 * 1.4), cloth)
			for i in 4:
				kit.box(Vector3(hw2 + 0.02, 0.4 + i * 0.32, hd2 - 0.25), Vector3(0.04, 0.04, 0.35), wood2)
			kit.box(Vector3(0, 1.65, 0), Vector3(0.05, 0.2, hd2 * 2), wood)
		"berceau":
			kit.box(Vector3(0, 0.3, 0), Vector3(0.75, 0.06, 0.5), wood)
			for sx in [-1, 1]:
				for sz in [-1, 1]:
					kit.box(Vector3(sx * 0.35, 0.35, sz * 0.22), Vector3(0.05, 0.7, 0.05), wood)
			for i in 7:
				kit.box(Vector3(-0.33 + i * 0.11, 0.55, 0.22), Vector3(0.025, 0.45, 0.025), wood2)
				kit.box(Vector3(-0.33 + i * 0.11, 0.55, -0.22), Vector3(0.025, 0.45, 0.025), wood2)
			kit.box(Vector3(0, 0.38, 0), Vector3(0.68, 0.08, 0.44), cloth2.lightened(0.3))
		"chevet":
			kit.box(Vector3(0, 0.28, -0.2), Vector3(0.45, 0.5, 0.4), wood)
			kit.box(Vector3(0, 0.36, 0.005), Vector3(0.36, 0.14, 0.01), wood2)
			_lamp_small(kit, Vector3(0.08, 0.53, -0.25), cloth2)
		"armoire", "tansu_escalier":
			if k == "tansu_escalier":
				for i in 4:
					var ww := w - i * 0.45
					kit.box(Vector3(-w * 0.5 + ww * 0.5 + 0.05, 0.25 + i * 0.5, -0.2), Vector3(ww - 0.1, 0.48, 0.5), wood)
					kit.box(Vector3(-w * 0.5 + ww * 0.5 + 0.05, 0.25 + i * 0.5, 0.06), Vector3(ww - 0.2, 0.3, 0.02), wood2)
			else:
				kit.box(Vector3(0, h * 0.5, -0.18), Vector3(w - 0.15, h, 0.6), wood)
				kit.box(Vector3(0, h + 0.03, -0.18), Vector3(w - 0.05, 0.08, 0.66), wood.darkened(0.15))
				for sx in [-1, 1]:
					kit.box(Vector3(sx * (w - 0.15) * 0.25, h * 0.52, 0.125), Vector3((w - 0.15) * 0.5 - 0.06, h * 0.85, 0.02), wood2)
					kit.box(Vector3(sx * 0.06, h * 0.52, 0.14), Vector3(0.03, 0.18, 0.03), metal)
		"commode", "coiffeuse", "dossiers", "casiers":
			var cw := w - 0.12
			var ch := minf(h, 0.95) if k != "dossiers" else h
			if k == "casiers":
				ch = h
			kit.box(Vector3(0, ch * 0.5, -0.22), Vector3(cw, ch, 0.5), wood if k != "dossiers" and k != "casiers" else metal.lightened(0.35))
			var rows := 3 if k != "casiers" else 1
			for i in rows:
				kit.box(Vector3(0, ch * (0.2 + i * 0.28), 0.035), Vector3(cw - 0.08, ch * 0.22, 0.02), wood2 if k == "commode" or k == "coiffeuse" else metal.lightened(0.5))
			if k == "casiers":
				for i in int(w * 3):
					kit.box(Vector3(-cw * 0.5 + 0.16 + i * 0.32, ch * 0.5, 0.04), Vector3(0.28, ch - 0.1, 0.02), accent.lightened(0.15 * (i % 2)))
			if k == "coiffeuse":
				kit.box(Vector3(0, 1.25, -0.42), Vector3(0.6, 0.6, 0.04), wood)
				kit.layer = "verre"
				kit.box(Vector3(0, 1.25, -0.39), Vector3(0.5, 0.5, 0.01), Color(0.8, 0.9, 1.0))
				kit.layer = "base"
		"coffre":
			kit.box(Vector3(0, 0.25, -0.05), Vector3(0.8, 0.45, 0.5), wood)
			kit.box(Vector3(0, 0.5, -0.05), Vector3(0.84, 0.08, 0.54), wood.darkened(0.15))
			for sx in [-0.3, 0.3]:
				kit.box(Vector3(sx, 0.28, -0.05), Vector3(0.05, 0.5, 0.56), metal)
			kit.box(Vector3(0, 0.4, 0.22), Vector3(0.1, 0.1, 0.03), accent)
		"jouets":
			kit.box(Vector3(0, 0.2, 0), Vector3(0.7, 0.4, 0.45), accent)
			kit.box(Vector3(-0.15, 0.45, 0), Vector3(0.18, 0.18, 0.18), Color("e63946"))
			kit.box(Vector3(0.12, 0.47, 0.05), Vector3(0.14, 0.22, 0.14), Color("457b9d"))
			kit.blob(Vector3(0.25, 0.48, -0.1), Vector3(0.1, 0.1, 0.1), Color("f4a261"), Color("f4a261"), 0.0, 0)
		"canape", "banquette", "meridienne", "triclinium":
			var sw := w - 0.1
			var seat_h := 0.42 if k != "triclinium" else 0.6
			kit.box(Vector3(0, seat_h * 0.5, 0), Vector3(sw, seat_h, 0.85), cloth if k != "banquette" else cloth.darkened(0.1))
			kit.box(Vector3(0, seat_h + 0.06, 0.05), Vector3(sw - 0.25, 0.12, 0.7), cloth.lightened(0.1))
			kit.box(Vector3(0, seat_h + 0.25, -0.33), Vector3(sw, 0.5 if k != "banquette" else 0.65, 0.2), cloth.darkened(0.05))
			if k != "triclinium":
				for sx in [-1, 1]:
					kit.box(Vector3(sx * (sw * 0.5 - 0.08), seat_h + 0.12, 0.02), Vector3(0.16, 0.3, 0.8), cloth.darkened(0.08))
			for i in 2:
				kit.box(Vector3(-0.4 + i * 0.8, seat_h + 0.3, -0.18), Vector3(0.35, 0.3, 0.12), cloth2)
			for sx2 in [-1, 1]:
				kit.box(Vector3(sx2 * (sw * 0.5 - 0.06), 0.04, 0.35), Vector3(0.06, 0.08, 0.06), wood)
		"banquette_basse":
			kit.box(Vector3(0, 0.15, -0.05), Vector3(w - 0.05, 0.3, 0.8), wood.darkened(0.2))
			kit.box(Vector3(0, 0.36, -0.03), Vector3(w - 0.1, 0.12, 0.75), cloth)
			kit.box(Vector3(0, 0.6, -0.4), Vector3(w - 0.1, 0.4, 0.15), cloth.darkened(0.1))
			for i in int(w * 2):
				kit.box(Vector3(-w * 0.5 + 0.25 + i * 0.5, 0.62, -0.28), Vector3(0.35, 0.3, 0.1), cloth2 if i % 2 == 0 else accent)
		"fauteuil", "zaisu", "chaise_palabre":
			if k == "zaisu":
				kit.box(Vector3(0, 0.05, 0), Vector3(0.55, 0.1, 0.55), cloth)
				kit.box(Vector3(0, 0.3, -0.24), Vector3(0.5, 0.45, 0.06), wood)
			elif k == "chaise_palabre":
				kit.beam(Vector3(0, 0.35, 0.3), Vector3(0, 0.2, -0.25), 0.42, 0.04, wood2)
				kit.beam(Vector3(0, 0.0, -0.2), Vector3(0, 0.9, -0.35), 0.42, 0.05, wood)
				kit.beam(Vector3(0, 0.0, 0.3), Vector3(0, 0.36, 0.3), 0.42, 0.05, wood)
			else:
				kit.box(Vector3(0, 0.22, 0), Vector3(0.75, 0.3, 0.75), cloth)
				kit.box(Vector3(0, 0.42, 0.04), Vector3(0.55, 0.1, 0.62), cloth.lightened(0.12))
				kit.box(Vector3(0, 0.65, -0.3), Vector3(0.75, 0.55, 0.15), cloth.darkened(0.05))
				for sx in [-1, 1]:
					kit.box(Vector3(sx * 0.32, 0.5, 0.0), Vector3(0.12, 0.25, 0.7), cloth.darkened(0.1))
					kit.box(Vector3(sx * 0.3, 0.035, 0.3), Vector3(0.05, 0.07, 0.05), wood)
		"rocking":
			for sx in [-0.25, 0.25]:
				kit.beam(Vector3(sx, 0.02, -0.4), Vector3(sx, 0.08, 0.4), 0.04, 0.05, wood)
				kit.box(Vector3(sx, 0.25, 0), Vector3(0.04, 0.4, 0.04), wood)
				kit.box(Vector3(sx, 0.7, -0.22), Vector3(0.04, 0.6, 0.04), wood)
			kit.box(Vector3(0, 0.45, 0), Vector3(0.55, 0.05, 0.5), wood2)
			kit.box(Vector3(0, 0.75, -0.22), Vector3(0.5, 0.5, 0.04), wood2)
			kit.box(Vector3(0, 0.5, 0.02), Vector3(0.45, 0.06, 0.42), cloth)
		"oeuf":
			kit.blob(Vector3(0, 0.75, -0.05), Vector3(0.45, 0.55, 0.42), white.darkened(0.1), white, 0.02, 1)
			kit.box(Vector3(0, 0.55, 0.15), Vector3(0.55, 0.12, 0.4), cloth)
			kit.box(Vector3(0, 0.1, 0), Vector3(0.1, 0.2, 0.1), metal)
			kit.box(Vector3(0, 0.02, 0), Vector3(0.5, 0.04, 0.5), metal)
		"pouf":
			kit.lathe(Vector3.ZERO, [Vector2(0.28, 0.0), Vector2(0.32, 0.12), Vector2(0.3, 0.3), Vector2(0.22, 0.38)], 8, cloth)
		"coussins":
			kit.box(Vector3(0, 0.07, 0), Vector3(0.6, 0.14, 0.6), cloth, 0.04)
			kit.box(Vector3(0.05, 0.18, -0.05), Vector3(0.45, 0.1, 0.45), cloth2, 0.05)
		"table_basse", "plateau", "kotatsu", "holo":
			if k == "plateau":
				for i in 6:
					var a := TAU * i / 6.0
					kit.beam(Vector3(cos(a) * 0.22, 0.0, sin(a) * 0.22), Vector3(cos(a) * 0.3, 0.32, sin(a) * 0.3), 0.03, 0.03, wood)
				kit.lathe(Vector3(0, 0.32, 0), [Vector2(0.38, 0.0), Vector2(0.4, 0.04)], 12, metal)
			elif k == "kotatsu":
				kit.box(Vector3(0, 0.2, 0), Vector3(0.9, 0.3, 0.9), cloth, 0.04)
				kit.box(Vector3(0, 0.4, 0), Vector3(0.8, 0.05, 0.8), wood)
			elif k == "holo":
				kit.lathe(Vector3.ZERO, [Vector2(0.25, 0.0), Vector2(0.12, 0.3), Vector2(0.45, 0.4), Vector2(0.45, 0.44)], 12, white)
				kit.layer = "lumiere"
				kit.blob(Vector3(0, 0.75, 0), Vector3(0.2, 0.2, 0.2), accent, accent.lightened(0.4), 0.05, 0)
				kit.layer = "base"
			else:
				kit.box(Vector3(0, 0.4, 0), Vector3(0.8, 0.05, 0.55), wood2)
				for sx in [-1, 1]:
					for sz in [-1, 1]:
						kit.box(Vector3(sx * 0.35, 0.19, sz * 0.22), Vector3(0.05, 0.38, 0.05), wood)
				kit.box(Vector3(0.1, 0.45, 0.05), Vector3(0.25, 0.04, 0.18), accent)
		"table_repas", "repas_sol":
			if k == "repas_sol":
				kit.box(Vector3(0, 0.01, 0), Vector3(1.8, 0.02, 1.8), cloth2)
				kit.box(Vector3(0, 0.2, 0), Vector3(0.9, 0.05, 0.6), wood)
				for sx in [-1, 1]:
					kit.box(Vector3(sx * 0.4, 0.1, 0), Vector3(0.05, 0.18, 0.5), wood)
				for i in 4:
					var px: float = [-0.45, 0.45, -0.45, 0.45][i]
					var pz: float = [-0.75, -0.75, 0.75, 0.75][i]
					kit.box(Vector3(px, 0.06, pz), Vector3(0.45, 0.1, 0.4), cloth)
				kit.lathe(Vector3(0.1, 0.23, 0), [Vector2(0.06, 0.0), Vector2(0.14, 0.08), Vector2(0.14, 0.1)], 8, accent)
			else:
				kit.box(Vector3(0, 0.74, 0), Vector3(1.6, 0.06, 0.9), wood2)
				for sx in [-1, 1]:
					for sz in [-1, 1]:
						kit.box(Vector3(sx * 0.72, 0.36, sz * 0.38), Vector3(0.07, 0.72, 0.07), wood)
				for i in 4:
					var cx: float = [-0.45, 0.45, -0.45, 0.45][i]
					var cz: float = [-0.75, -0.75, 0.75, 0.75][i]
					_chair(kit, Vector3(cx, 0, cz), 0.0 if cz < 0 else PI, wood, cloth)
				kit.lathe(Vector3(0, 0.77, 0), [Vector2(0.06, 0.0), Vector2(0.09, 0.12), Vector2(0.05, 0.25)], 6, accent)
		"chaise":
			_chair(kit, Vector3.ZERO, 0.0, wood, cloth)
		"tabouret", "tabouret_sculpte":
			if k == "tabouret_sculpte":
				kit.box(Vector3(0, 0.05, 0), Vector3(0.5, 0.1, 0.3), wood)
				kit.box(Vector3(0, 0.22, 0), Vector3(0.18, 0.26, 0.18), wood2)
				kit.beam(Vector3(-0.28, 0.42, 0), Vector3(0.28, 0.42, 0), 0.3, 0.06, wood)
			else:
				kit.lathe(Vector3.ZERO, [Vector2(0.18, 0.0), Vector2(0.04, 0.05), Vector2(0.04, 0.68), Vector2(0.2, 0.7), Vector2(0.2, 0.76)], 8, metal)
				kit.box(Vector3(0, 0.75, 0), Vector3(0.34, 0.05, 0.34), cloth)
		"buffet", "meuble_tv", "vaisselier", "maie":
			kit.box(Vector3(0, 0.42, -0.2), Vector3(w - 0.12, 0.8, 0.5), wood)
			kit.box(Vector3(0, 0.84, -0.2), Vector3(w - 0.06, 0.05, 0.54), wood.darkened(0.12))
			for i in 3:
				kit.box(Vector3(-0.55 + i * 0.55, 0.42, 0.055), Vector3(0.48, 0.62, 0.02), wood2)
			if k == "vaisselier":
				kit.box(Vector3(0, 1.4, -0.38), Vector3(w - 0.15, 1.1, 0.25), wood)
				for y in [1.1, 1.45, 1.8]:
					kit.box(Vector3(0, y, -0.25), Vector3(w - 0.25, 0.03, 0.06), wood2)
					for i in 6:
						kit.lathe(Vector3(-0.7 + i * 0.28, y + 0.02, -0.3), [Vector2(0.1, 0.0), Vector2(0.11, 0.02)], 8, white)
			elif k == "meuble_tv":
				var sw := 1.25 if era < 5 else 1.8
				if era == 3:
					kit.box(Vector3(0, 1.13, -0.25), Vector3(0.75, 0.6, 0.5), Color("3a3a3a"))
					kit.layer = "lumiere"
					kit.box(Vector3(-0.05, 1.13, 0.005), Vector3(0.52, 0.42, 0.01), Color("6f8fa8"))
				else:
					kit.box(Vector3(0, 1.25, -0.38), Vector3(sw, 0.72, 0.04), Color("1a1a1e"))
					kit.layer = "lumiere"
					kit.box(Vector3(0, 1.25, -0.355), Vector3(sw - 0.06, 0.66, 0.01), Color("44607a"))
				kit.layer = "base"
		"bibliotheque", "etagere":
			kit.box(Vector3(0, h * 0.5, -0.33), Vector3(w - 0.1, h, 0.04), wood.darkened(0.1))
			for sx in [-1, 1]:
				kit.box(Vector3(sx * (w * 0.5 - 0.07), h * 0.5, -0.17), Vector3(0.04, h, 0.36), wood)
			var shelves := 5
			for i in shelves + 1:
				var y := 0.05 + i * (h - 0.1) / shelves
				kit.box(Vector3(0, y, -0.17), Vector3(w - 0.12, 0.03, 0.36), wood)
				if i < shelves:
					if k == "bibliotheque":
						var x := -w * 0.5 + 0.12
						while x < w * 0.5 - 0.2:
							var bw := kit.rng.randf_range(0.04, 0.09)
							var bh := kit.rng.randf_range(0.2, 0.3)
							var col := [cloth, cloth2, accent, wood2, Color("2f4858"), Color("7a3b3b")][kit.rng.randi() % 6] as Color
							kit.box(Vector3(x + bw * 0.5, y + 0.015 + bh * 0.5, -0.2), Vector3(bw, bh, 0.24), col, 0.0, false)
							x += bw + 0.005
					else:
						for j in int(w * 2):
							kit.box(Vector3(-w * 0.5 + 0.3 + j * 0.45, y + 0.15, -0.18), Vector3(0.36, 0.26, 0.3), wood2.lightened(0.1), 0.05)
		"cheminee":
			kit.box(Vector3(0, 0.55, -0.3), Vector3(1.5, 1.1, 0.4), stone)
			kit.box(Vector3(0, 1.15, -0.25), Vector3(1.7, 0.1, 0.5), stone.darkened(0.1))
			kit.box(Vector3(0, 0.4, -0.1), Vector3(0.85, 0.7, 0.02), Color("1d1a18"))
			kit.layer = "lumiere"
			kit.blob(Vector3(0, 0.25, -0.2), Vector3(0.25, 0.18, 0.12), Color("ff7a1a"), Color("ffd24a"), 0.2, 0)
			kit.layer = "base"
			kit.box(Vector3(-0.2, 0.1, -0.2), Vector3(0.4, 0.08, 0.08), wood)
		"poele":
			kit.lathe(Vector3(0, 0, -0.05), [Vector2(0.28, 0.0), Vector2(0.3, 0.1), Vector2(0.3, 0.8), Vector2(0.24, 0.9), Vector2(0.08, 0.95), Vector2(0.08, h)], 8, metal)
			kit.layer = "lumiere"
			kit.box(Vector3(0, 0.4, 0.24), Vector3(0.22, 0.18, 0.04), Color("ff8a2a"))
			kit.layer = "base"
		"piano":
			kit.box(Vector3(0, 0.65, -0.25), Vector3(1.5, 1.25, 0.5), Color("1c1714") if era >= 2 else wood)
			kit.box(Vector3(0, 0.75, 0.05), Vector3(1.4, 0.06, 0.2), Color("1c1714"))
			kit.box(Vector3(0, 0.79, 0.08), Vector3(1.3, 0.02, 0.14), white)
			kit.box(Vector3(0, 0.28, 0.45), Vector3(0.7, 0.05, 0.32), Color("1c1714"))
			for sx in [-0.3, 0.3]:
				kit.box(Vector3(sx, 0.14, 0.45), Vector3(0.05, 0.28, 0.05), Color("1c1714"))
		"horloge":
			kit.box(Vector3(0, 0.95, -0.25), Vector3(0.45, 1.9, 0.35), wood)
			kit.box(Vector3(0, 1.95, -0.25), Vector3(0.55, 0.15, 0.4), wood.darkened(0.15))
			kit.lathe(Vector3(0, 1.6, -0.06), [Vector2(0.0, 0.0), Vector2(0.15, 0.0)], 12, white)
			kit.box(Vector3(0, 0.9, -0.06), Vector3(0.04, 0.5, 0.02), accent)
			kit.lathe(Vector3(0, 0.6, -0.07), [Vector2(0.0, 0.0), Vector2(0.08, 0.0)], 8, accent)
		"bureau", "poste", "secretaire":
			var dw := w - 0.15
			kit.box(Vector3(0, 0.74, -0.2), Vector3(dw, 0.05, 0.6), wood2)
			if k == "poste":
				kit.box(Vector3(0, 1.0, -0.48), Vector3(dw, 0.5, 0.03), cloth2)
			for sx in [-1, 1]:
				kit.box(Vector3(sx * (dw * 0.5 - 0.04), 0.37, -0.2), Vector3(0.05, 0.72, 0.55), wood)
			kit.box(Vector3(dw * 0.25, 0.55, -0.2), Vector3(dw * 0.4, 0.35, 0.5), wood)
			if era >= 3:
				kit.box(Vector3(0, 0.95, -0.38), Vector3(0.55 if era < 5 else 0.8, 0.35, 0.03), Color("202226"))
				kit.box(Vector3(0, 0.79, -0.33), Vector3(0.08, 0.1, 0.06), Color("202226"))
				kit.box(Vector3(0, 0.775, -0.12), Vector3(0.4, 0.02, 0.14), Color("2c2e33"))
				kit.layer = "lumiere"
				kit.box(Vector3(0, 0.96, -0.36), Vector3(0.5 if era < 5 else 0.75, 0.3, 0.01), Color("7aa5c9") if era < 5 else accent)
				kit.layer = "base"
			else:
				kit.box(Vector3(-0.15, 0.775, -0.15), Vector3(0.3, 0.01, 0.22), white)
				kit.lathe(Vector3(0.2, 0.765, -0.3), [Vector2(0.03, 0.0), Vector2(0.035, 0.06)], 6, Color("1d2b3a"))
				_lamp_small(kit, Vector3(-dw * 0.4, 0.765, -0.35), accent)
			_chair(kit, Vector3(0, 0, 0.3), PI, wood if era < 3 else metal, cloth)
		"pupitre":
			kit.box(Vector3(0, 0.7, -0.15), Vector3(0.75, 0.04, 0.45), wood2)
			kit.box(Vector3(0, 0.6, -0.15), Vector3(0.7, 0.12, 0.4), wood)
			for sx in [-1, 1]:
				kit.box(Vector3(sx * 0.33, 0.33, -0.15), Vector3(0.04, 0.66, 0.4), metal if era >= 3 else wood)
			kit.box(Vector3(-0.1, 0.73, -0.12), Vector3(0.25, 0.02, 0.18), white)
			_chair(kit, Vector3(0, 0, 0.25), PI, metal if era >= 3 else wood, accent, 0.42)
		"tableau":
			var board := Color("2f4f3a") if era < 4 else white
			kit.box(Vector3(0, 1.45, -0.46), Vector3(w - 0.1, 1.1, 0.05), wood)
			kit.box(Vector3(0, 1.45, -0.43), Vector3(w - 0.2, 1.0, 0.02), board)
			kit.box(Vector3(0, 0.9, -0.4), Vector3(w - 0.2, 0.04, 0.08), wood)
			if era >= 5:
				kit.layer = "lumiere"
				kit.box(Vector3(0, 1.45, -0.415), Vector3(w - 0.25, 0.95, 0.01), accent.lightened(0.3))
				kit.layer = "base"
			else:
				kit.box(Vector3(-0.3, 1.6, -0.415), Vector3(0.5, 0.02, 0.005), white if era < 4 else Color("1f4e9a"))
				kit.box(Vector3(0.1, 1.35, -0.415), Vector3(0.7, 0.02, 0.005), white if era < 4 else Color("1f4e9a"))
		"globe":
			kit.lathe(Vector3.ZERO, [Vector2(0.2, 0.0), Vector2(0.04, 0.05), Vector2(0.03, 0.55)], 6, wood)
			kit.blob(Vector3(0, 0.75, 0), Vector3(0.22, 0.22, 0.22), Color("2e6f9e"), Color("5aa469"), 0.0, 1)
		"comptoir", "bar":
			kit.box(Vector3(0, 0.5, 0.18), Vector3(w - 0.05, 1.0, 0.45), wood)
			kit.box(Vector3(0, 1.03, 0.15), Vector3(w + 0.02, 0.06, 0.55), wood2 if k == "comptoir" else stone)
			kit.box(Vector3(0, 0.5, 0.41), Vector3(w - 0.15, 0.8, 0.02), accent.darkened(0.2))
			if k == "comptoir":
				kit.box(Vector3(0.4, 1.12, 0.1), Vector3(0.35, 0.14, 0.3), Color("2b2d31"))
				kit.box(Vector3(0.4, 1.25, 0.0), Vector3(0.3, 0.2, 0.04), Color("2b2d31"))
			else:
				for i in 4:
					kit.lathe(Vector3(-0.6 + i * 0.3, 1.06, 0.05), [Vector2(0.03, 0.0), Vector2(0.04, 0.15), Vector2(0.015, 0.25)], 6, Color("4a7a3a").lightened(0.1 * i))
				kit.box(Vector3(0, 1.4, -0.45), Vector3(w - 0.2, 0.03, 0.12), wood2)
		"rayonnage", "vitrine_froide", "etal", "presentoir", "portant":
			if k == "portant":
				for sx in [-1, 1]:
					kit.box(Vector3(sx * 0.8, 0.8, 0), Vector3(0.04, 1.6, 0.04), metal)
					kit.box(Vector3(sx * 0.8, 0.02, 0), Vector3(0.06, 0.04, 0.5), metal)
				kit.box(Vector3(0, 1.55, 0), Vector3(1.64, 0.03, 0.03), metal)
				for i in 9:
					kit.box(Vector3(-0.7 + i * 0.175, 1.1, 0), Vector3(0.05, 0.85, 0.42), [cloth, cloth2, accent][i % 3] as Color, 0.0, false)
			elif k == "presentoir":
				kit.box(Vector3(0, 0.45, 0), Vector3(0.8, 0.9, 0.8), wood2)
				kit.box(Vector3(0, 0.92, 0), Vector3(0.85, 0.04, 0.85), wood)
				for i in 4:
					kit.box(Vector3(-0.25 + (i % 2) * 0.5, 1.0, -0.2 + (i / 2) * 0.4), Vector3(0.18, 0.12, 0.18), [accent, cloth, cloth2, Color("e9c46a")][i] as Color)
			elif k == "etal":
				kit.box(Vector3(0, 0.72, 0.05), Vector3(w - 0.1, 0.06, 0.8), wood2)
				for sx in [-1, 1]:
					kit.box(Vector3(sx * (w * 0.5 - 0.1), 0.36, 0.05), Vector3(0.06, 0.72, 0.7), wood)
					kit.box(Vector3(sx * (w * 0.5 - 0.1), 1.3, -0.35), Vector3(0.05, 1.2, 0.05), wood)
				kit.box(Vector3(0, 1.9, 0.05), Vector3(w, 0.03, 1.0), cloth)
				for i in 8:
					kit.blob(Vector3(-0.7 + i * 0.2, 0.82, 0.05 + (i % 2) * 0.2), Vector3(0.08, 0.07, 0.08), Color("c0392b").lerp(Color("f39c12"), (i % 3) * 0.5), Color("e74c3c").lerp(Color("2ecc71"), (i % 2) * 1.0), 0.1, 0)
			else:
				kit.box(Vector3(0, h * 0.5, -0.38), Vector3(w - 0.1, h, 0.05), metal.lightened(0.4) if k == "rayonnage" else white)
				for sx in [-1, 1]:
					kit.box(Vector3(sx * (w * 0.5 - 0.07), h * 0.5, -0.2), Vector3(0.04, h, 0.4), metal.lightened(0.3))
				for i in 5:
					var y2 := 0.1 + i * (h - 0.2) / 4.0
					kit.box(Vector3(0, y2, -0.2), Vector3(w - 0.14, 0.03, 0.4), metal.lightened(0.5))
					if i < 4:
						for j in 7:
							var pc := [accent, cloth, cloth2, Color("e9c46a"), Color("2a9d8f"), Color("e76f51")][(i * 7 + j) % 6] as Color
							kit.box(Vector3(-w * 0.5 + 0.2 + j * (w - 0.35) / 6.5, y2 + 0.12, -0.2), Vector3(0.18, 0.2, 0.3), pc, 0.0, false)
				if k == "vitrine_froide":
					kit.layer = "verre"
					kit.box(Vector3(0, h * 0.5, 0.01), Vector3(w - 0.12, h - 0.1, 0.02), Color(0.75, 0.9, 1.0))
					kit.layer = "lumiere"
					kit.box(Vector3(0, h - 0.04, -0.2), Vector3(w - 0.2, 0.03, 0.3), Color("e8f4ff"))
					kit.layer = "base"
		"mannequin":
			kit.lathe(Vector3.ZERO, [Vector2(0.18, 0.0), Vector2(0.02, 0.04), Vector2(0.02, 0.8)], 6, metal)
			kit.lathe(Vector3(0, 0.8, 0), [Vector2(0.14, 0.0), Vector2(0.17, 0.25), Vector2(0.2, 0.5), Vector2(0.12, 0.65), Vector2(0.05, 0.7)], 8, cloth)
			kit.blob(Vector3(0, 1.62, 0), Vector3(0.09, 0.11, 0.09), white, white, 0.0, 0)
		"caisses":
			kit.box(Vector3(-0.12, 0.2, -0.1), Vector3(0.45, 0.4, 0.45), wood2, 0.03)
			kit.box(Vector3(0.18, 0.18, 0.15), Vector3(0.35, 0.36, 0.35), wood2.darkened(0.1), 0.03)
			kit.box(Vector3(-0.1, 0.55, -0.1), Vector3(0.35, 0.3, 0.35), wood2.lightened(0.1), 0.03)
			kit.blob(Vector3(0.2, 0.5, 0.15), Vector3(0.15, 0.13, 0.12), Color("c8b48a"), Color("d8c49a"), 0.15, 0)
		"plan_travail", "evier", "cuisiniere", "lave_vaisselle", "fourneau", "frigo", "garde_manger":
			var top := white.darkened(0.05) if era >= 3 else wood2
			if k == "frigo":
				kit.box(Vector3(0, h * 0.5, -0.12), Vector3(0.75, h, 0.7), white if era < 5 else metal.lightened(0.3))
				kit.box(Vector3(0, h * 0.62, 0.235), Vector3(0.7, 0.02, 0.01), Color("bbbbbb"))
				kit.box(Vector3(0.3, h * 0.75, 0.24), Vector3(0.03, 0.3, 0.03), metal)
			elif k == "garde_manger":
				kit.box(Vector3(0, h * 0.5, -0.15), Vector3(0.8, h, 0.6), wood)
				for i in 3:
					kit.box(Vector3(0, h * (0.25 + i * 0.27), 0.16), Vector3(0.6, 0.25, 0.01), wood2.darkened(0.2))
			elif k == "fourneau":
				kit.box(Vector3(0, 0.4, -0.15), Vector3(0.9, 0.8, 0.65), Color("2b2b2b"))
				kit.box(Vector3(0, 0.82, -0.15), Vector3(0.94, 0.04, 0.69), metal.lightened(0.2))
				kit.box(Vector3(0.25, 0.4, 0.18), Vector3(0.3, 0.3, 0.02), metal.lightened(0.3))
				kit.lathe(Vector3(-0.3, 0.84, -0.4), [Vector2(0.06, 0.0), Vector2(0.06, 1.5)], 6, Color("2b2b2b"))
				kit.lathe(Vector3(-0.15, 0.84, -0.1), [Vector2(0.14, 0.0), Vector2(0.15, 0.18), Vector2(0.15, 0.2)], 8, accent.darkened(0.3))
			else:
				kit.box(Vector3(0, 0.44, -0.12), Vector3(0.95, 0.84, 0.66), wood if era < 3 else wood2.lightened(0.15))
				kit.box(Vector3(0, 0.88, -0.1), Vector3(1.0, 0.04, 0.7), top)
				kit.box(Vector3(0, 0.45, 0.215), Vector3(0.85, 0.7, 0.01), wood2 if era < 3 else cloth2)
				if k == "evier":
					kit.box(Vector3(0, 0.89, -0.1), Vector3(0.6, 0.02, 0.45), metal.lightened(0.35))
					kit.box(Vector3(0, 1.0, -0.38), Vector3(0.04, 0.22, 0.04), metal)
					kit.box(Vector3(0, 1.1, -0.3), Vector3(0.04, 0.04, 0.18), metal)
				elif k == "cuisiniere":
					kit.box(Vector3(0, 0.45, 0.22), Vector3(0.7, 0.55, 0.02), Color("222222"))
					for i in 4:
						kit.lathe(Vector3(-0.2 + (i % 2) * 0.4, 0.9, -0.25 + (i / 2) * 0.3), [Vector2(0.0, 0.0), Vector2(0.1, 0.0)], 8, Color("1a1a1a"))
					kit.lathe(Vector3(0.18, 0.92, -0.08), [Vector2(0.12, 0.0), Vector2(0.13, 0.12), Vector2(0.13, 0.14)], 8, accent)
				elif k == "lave_vaisselle":
					kit.box(Vector3(0, 0.82, 0.225), Vector3(0.7, 0.06, 0.01), Color("333333"))
				else:
					kit.box(Vector3(-0.2, 0.91, -0.15), Vector3(0.4, 0.02, 0.28), wood2)
					kit.blob(Vector3(0.25, 0.97, -0.2), Vector3(0.09, 0.07, 0.09), Color("c0392b"), Color("e67e22"), 0.1, 0)
		"foyer_feu", "tajine":
			for i in 6:
				var a2 := TAU * i / 6.0
				kit.stone(Vector3(cos(a2) * 0.3, 0.1, sin(a2) * 0.3), Vector3(0.18, 0.18, 0.18), stone)
			kit.layer = "lumiere"
			kit.blob(Vector3(0, 0.12, 0), Vector3(0.14, 0.1, 0.14), Color("ff6a10"), Color("ffcf40"), 0.2, 0)
			kit.layer = "base"
			kit.lathe(Vector3(0, 0.2, 0), [Vector2(0.18, 0.0), Vector2(0.22, 0.1), Vector2(0.1, 0.28), Vector2(0.02, 0.36)], 8, Color("a0522d"))
		"jarre", "amphore", "djembe", "samovar":
			if k == "djembe":
				kit.lathe(Vector3.ZERO, [Vector2(0.1, 0.0), Vector2(0.12, 0.05), Vector2(0.07, 0.3), Vector2(0.17, 0.55), Vector2(0.17, 0.62)], 8, wood)
				kit.lathe(Vector3(0, 0.62, 0), [Vector2(0.17, 0.0), Vector2(0.0, 0.01)], 8, cloth2.lightened(0.3))
			elif k == "samovar":
				kit.lathe(Vector3.ZERO, [Vector2(0.15, 0.0), Vector2(0.06, 0.08), Vector2(0.2, 0.15), Vector2(0.22, 0.45), Vector2(0.12, 0.6), Vector2(0.05, 0.75)], 8, metal)
			else:
				var jc := Color("b5653a") if k == "jarre" else accent.lerp(stone, 0.4)
				kit.lathe(Vector3.ZERO, [Vector2(0.12, 0.0), Vector2(0.28, 0.25), Vector2(0.3, 0.45), Vector2(0.15, 0.68), Vector2(0.1, 0.75), Vector2(0.13, 0.8)], 10, jc)
		"baignoire", "baquet":
			if k == "baquet":
				kit.lathe(Vector3.ZERO, [Vector2(0.38, 0.0), Vector2(0.42, 0.55), Vector2(0.44, 0.58)], 12, wood2, true, false)
				kit.lathe(Vector3(0, 0.5, 0), [Vector2(0.0, 0.0), Vector2(0.38, 0.0)], 12, Color("8fb8c8"))
			else:
				kit.box(Vector3(0, 0.3, -0.05), Vector3(1.75, 0.6, 0.8), white)
				kit.box(Vector3(0, 0.55, -0.05), Vector3(1.55, 0.02, 0.6), Color("9cc9db"))
				kit.box(Vector3(-0.8, 0.85, -0.4), Vector3(0.04, 0.3, 0.04), metal)
		"douche":
			kit.box(Vector3(0, 0.05, -0.05), Vector3(0.9, 0.1, 0.85), white)
			kit.layer = "verre"
			kit.box(Vector3(0, 1.1, 0.4), Vector3(0.9, 2.0, 0.02), Color(0.8, 0.92, 1.0))
			kit.box(Vector3(0.44, 1.1, 0.0), Vector3(0.02, 2.0, 0.8), Color(0.8, 0.92, 1.0))
			kit.layer = "base"
			kit.box(Vector3(0, 1.9, -0.35), Vector3(0.04, 0.04, 0.25), metal)
			kit.lathe(Vector3(0, 1.85, -0.23), [Vector2(0.0, 0.0), Vector2(0.1, 0.0), Vector2(0.1, 0.03)], 8, metal)
		"lavabo", "vasque", "table_toilette":
			if k == "table_toilette":
				kit.box(Vector3(0, 0.75, -0.15), Vector3(0.75, 0.05, 0.5), wood2)
				for sx in [-1, 1]:
					kit.box(Vector3(sx * 0.33, 0.37, -0.15), Vector3(0.05, 0.75, 0.45), wood)
				kit.lathe(Vector3(0, 0.78, -0.15), [Vector2(0.12, 0.0), Vector2(0.22, 0.1), Vector2(0.23, 0.11)], 10, white)
				kit.lathe(Vector3(0.22, 0.78, -0.25), [Vector2(0.06, 0.0), Vector2(0.09, 0.12), Vector2(0.05, 0.25), Vector2(0.07, 0.3)], 8, white)
			else:
				var vw := w - 0.2
				if k == "vasque":
					kit.box(Vector3(0, 0.45, -0.2), Vector3(vw, 0.5, 0.5), wood2)
				else:
					kit.lathe(Vector3(0, 0, -0.3), [Vector2(0.09, 0.0), Vector2(0.06, 0.6), Vector2(0.1, 0.75)], 8, white)
				kit.box(Vector3(0, 0.82, -0.22), Vector3(vw * 0.75 if k == "vasque" else 0.55, 0.12, 0.42), white)
				kit.box(Vector3(0, 0.95, -0.4), Vector3(0.04, 0.15, 0.04), metal)
				kit.box(Vector3(0, 1.4, -0.47), Vector3(vw * 0.7 if k == "vasque" else 0.5, 0.6, 0.03), wood)
				kit.layer = "verre"
				kit.box(Vector3(0, 1.4, -0.45), Vector3(vw * 0.65 if k == "vasque" else 0.45, 0.55, 0.01), Color(0.85, 0.92, 1.0))
				kit.layer = "base"
		"wc", "chaise_percee":
			if k == "chaise_percee":
				kit.box(Vector3(0, 0.45, -0.1), Vector3(0.55, 0.06, 0.5), wood2)
				kit.box(Vector3(0, 0.22, -0.1), Vector3(0.5, 0.42, 0.45), wood)
				kit.box(Vector3(0, 0.75, -0.33), Vector3(0.5, 0.55, 0.05), wood)
			else:
				kit.lathe(Vector3(0, 0, -0.05), [Vector2(0.13, 0.0), Vector2(0.15, 0.3), Vector2(0.2, 0.4), Vector2(0.18, 0.42)], 10, white)
				kit.box(Vector3(0, 0.6, -0.35), Vector3(0.42, 0.4, 0.18), white)
				kit.box(Vector3(0, 0.43, 0.0), Vector3(0.38, 0.03, 0.42), white.darkened(0.05))
		"porte_manteau":
			kit.lathe(Vector3(0, 0, -0.2), [Vector2(0.2, 0.0), Vector2(0.03, 0.04), Vector2(0.03, 1.75), Vector2(0.06, 1.8)], 6, wood)
			for i in 4:
				var a3 := TAU * i / 4.0
				kit.beam(Vector3(0, 1.6, -0.2), Vector3(cos(a3) * 0.18, 1.7, -0.2 + sin(a3) * 0.18), 0.03, 0.03, wood)
			kit.box(Vector3(0.12, 1.25, -0.2), Vector3(0.2, 0.7, 0.12), cloth)
		"banc":
			kit.box(Vector3(0, 0.44, 0), Vector3(w - 0.15, 0.06, 0.38), wood2)
			for sx in [-1, 1]:
				kit.box(Vector3(sx * (w * 0.5 - 0.2), 0.21, 0), Vector3(0.06, 0.42, 0.34), wood)
		"miroir", "cadre":
			var fy := 1.5
			var fw := 0.7 if k == "cadre" else 0.55
			var fh := 0.55 if k == "cadre" else 0.9
			kit.box(Vector3(0, fy, -0.46), Vector3(fw, fh, 0.04), accent if k == "cadre" else wood)
			if k == "cadre":
				kit.box(Vector3(0, fy, -0.435), Vector3(fw - 0.1, fh - 0.1, 0.01), cloth.lerp(cloth2, 0.5))
				kit.box(Vector3(-0.08, fy - 0.05, -0.43), Vector3(0.25, 0.18, 0.005), cloth2)
				kit.box(Vector3(0.12, fy + 0.08, -0.43), Vector3(0.15, 0.12, 0.005), wood2)
			else:
				kit.layer = "verre"
				kit.box(Vector3(0, fy, -0.435), Vector3(fw - 0.08, fh - 0.08, 0.01), Color(0.85, 0.92, 1.0))
				kit.layer = "base"
		"etagere_murale":
			kit.box(Vector3(0, 1.4, -0.38), Vector3(0.85, 0.03, 0.22), wood2)
			for i in 3:
				kit.lathe(Vector3(-0.25 + i * 0.25, 1.415, -0.38), [Vector2(0.05, 0.0), Vector2(0.06, 0.12), Vector2(0.03, 0.16)], 6, [accent, cloth, cloth2][i] as Color)
		"photocopieur", "fontaine":
			if k == "fontaine":
				kit.box(Vector3(0, 0.45, -0.25), Vector3(0.35, 0.9, 0.35), white)
				kit.layer = "verre"
				kit.lathe(Vector3(0, 0.9, -0.25), [Vector2(0.14, 0.0), Vector2(0.15, 0.3), Vector2(0.05, 0.4)], 8, Color(0.55, 0.8, 1.0))
				kit.layer = "base"
			else:
				kit.box(Vector3(0, 0.45, -0.15), Vector3(0.75, 0.9, 0.6), Color("d8d8d4"))
				kit.box(Vector3(0, 0.95, -0.15), Vector3(0.7, 0.1, 0.55), Color("b8b8b4"))
				kit.box(Vector3(0.3, 0.92, 0.12), Vector3(0.2, 0.05, 0.05), Color("2b2d31"))
		"tapis", "tatami":
			var rw := w - 0.15
			var rd := d - 0.15
			if k == "tatami":
				var n := int(w) * int(d) / 2
				for i in maxi(n, 1):
					var cols := int(w)
					var ix := i % cols
					var iz := i / cols
					kit.box(Vector3(-w * 0.5 + 0.5 + ix, 0.03, -d * 0.5 + 1.0 + iz * 2.0 - (1.0 if d < 2 else 0.0)), Vector3(0.97, 0.06, 1.95 if d >= 2 else 0.97), Color("c9c08a"), 0.0)
					kit.box(Vector3(-w * 0.5 + 0.5 + ix - 0.47, 0.062, -d * 0.5 + 1.0 + iz * 2.0 - (1.0 if d < 2 else 0.0)), Vector3(0.03, 0.005, 1.9 if d >= 2 else 0.9), Color("1f2a3a"), 0.0, false)
			else:
				kit.box(Vector3(0, 0.01, 0), Vector3(rw, 0.02, rd), cloth, 0.0, false)
				kit.box(Vector3(0, 0.022, 0), Vector3(rw - 0.25, 0.004, rd - 0.25), cloth2, 0.0, false)
				kit.box(Vector3(0, 0.026, 0), Vector3(rw - 0.6, 0.004, rd - 0.6), accent.lerp(cloth, 0.4), 0.0, false)
		"plante", "grande_plante":
			var big := k == "grande_plante"
			kit.lathe(Vector3.ZERO, [Vector2(0.14 if not big else 0.2, 0.0), Vector2(0.18 if not big else 0.25, 0.3 if not big else 0.4), Vector2(0.19 if not big else 0.26, 0.32 if not big else 0.42)], 8, accent.lerp(Color("b5653a"), 0.5))
			if String(e.style) == "futuriste":
				kit.layer = "lumiere"
				kit.box(Vector3(0, 0.33, 0), Vector3(0.3, 0.02, 0.3), accent)
				kit.layer = "base"
			if big:
				kit.tube(Vector3(0, 0.4, 0), Vector3(0.05, 1.2, 0), 0.03, 0.02, 5, Color("6b4a2f"))
				kit.blob(Vector3(0.05, 1.4, 0), Vector3(0.38, 0.4, 0.38), Color("2e6b35"), Color("5aa04a"), 0.25, 1)
			else:
				kit.blob(Vector3(0, 0.6, 0), Vector3(0.28, 0.3, 0.28), Color("2e6b35"), Color("6ab04c"), 0.3, 1)
		"lampadaire", "lustre_cristal", "lanterne", "andon":
			if k == "lanterne":
				kit.lathe(Vector3.ZERO, [Vector2(0.15, 0.0), Vector2(0.03, 0.05), Vector2(0.03, 0.9)], 6, metal)
				kit.layer = "lumiere"
				kit.lathe(Vector3(0, 0.9, 0), [Vector2(0.1, 0.0), Vector2(0.2, 0.15), Vector2(0.18, 0.4), Vector2(0.05, 0.55)], 8, accent.lerp(Color("ffd27a"), 0.5))
				kit.layer = "base"
			elif k == "andon":
				kit.box(Vector3(0, 0.05, 0), Vector3(0.4, 0.1, 0.4), wood)
				kit.layer = "lumiere"
				kit.box(Vector3(0, 0.55, 0), Vector3(0.36, 0.9, 0.36), Color("fff1cc"))
				kit.layer = "base"
				for sx in [-1, 1]:
					for sz in [-1, 1]:
						kit.box(Vector3(sx * 0.19, 0.55, sz * 0.19), Vector3(0.03, 1.0, 0.03), wood)
			else:
				kit.lathe(Vector3.ZERO, [Vector2(0.18, 0.0), Vector2(0.18, 0.03), Vector2(0.025, 0.05), Vector2(0.025, h - 0.3)], 8, metal)
				kit.layer = "lumiere"
				kit.lathe(Vector3(0, h - 0.35, 0), [Vector2(0.22, 0.0), Vector2(0.14, 0.3)], 8, cloth2.lightened(0.35), false, false)
				kit.layer = "base"
		"statue":
			kit.box(Vector3(0, 0.45, 0), Vector3(0.45, 0.9, 0.45), stone.darkened(0.1))
			kit.blob(Vector3(0, 1.15, 0), Vector3(0.17, 0.25, 0.14), stone, stone.lightened(0.15), 0.12, 1)
			kit.blob(Vector3(0, 1.48, 0), Vector3(0.1, 0.12, 0.1), stone, stone.lightened(0.15), 0.05, 0)
		"aquarium":
			kit.box(Vector3(0, 0.38, -0.2), Vector3(1.4, 0.75, 0.5), wood)
			kit.layer = "verre"
			kit.box(Vector3(0, 1.05, -0.2), Vector3(1.3, 0.6, 0.45), Color(0.4, 0.75, 0.95))
			kit.layer = "base"
			for i in 4:
				kit.box(Vector3(-0.4 + i * 0.25, 0.95 + (i % 2) * 0.15, -0.2), Vector3(0.1, 0.06, 0.03), [Color("ff8c1a"), Color("f2d024"), Color("e84a5f"), Color("2ec4b6")][i] as Color)
			kit.box(Vector3(0, 1.38, -0.2), Vector3(1.35, 0.05, 0.48), wood.darkened(0.2))
		"paravent":
			for i in 4:
				var px2 := -0.75 + i * 0.5
				var rz := 0.12 if i % 2 == 0 else -0.12
				kit.box(Vector3(px2, h * 0.5, rz), Vector3(0.48, h, 0.04), wood)
				kit.box(Vector3(px2, h * 0.52, rz + 0.025), Vector3(0.4, h * 0.85, 0.01), cloth2 if i % 2 == 0 else cloth2.darkened(0.08))
		"hamac":
			for sz in [-1, 1]:
				kit.box(Vector3(0, 0.7, sz * 0.9), Vector3(0.1, 1.4, 0.1), wood)
			kit.beam(Vector3(0, 1.2, -0.85), Vector3(0, 0.55, -0.3), 0.5, 0.03, cloth)
			kit.beam(Vector3(0, 0.55, -0.3), Vector3(0, 0.55, 0.3), 0.55, 0.03, cloth)
			kit.beam(Vector3(0, 0.55, 0.3), Vector3(0, 1.2, 0.85), 0.5, 0.03, cloth)
			kit.beam(Vector3(0.2, 0.57, -0.25), Vector3(0.2, 0.57, 0.25), 0.05, 0.02, cloth2)
		"futon":
			var fw2 := w - 0.15
			var fd := d - 0.15
			kit.box(Vector3(0, 0.06, 0), Vector3(fw2, 0.12, fd), white.darkened(0.03), 0.0)
			kit.box(Vector3(0, 0.15, 0.2), Vector3(fw2 - 0.04, 0.06, fd * 0.7), cloth)
			kit.box(Vector3(0, 0.17, -fd * 0.5 + 0.25), Vector3(minf(fw2 - 0.2, 0.6), 0.1, 0.3), cloth2)
		"balancoire":
			for sx in [-1, 1]:
				kit.box(Vector3(sx * 0.9, 1.3, -0.1), Vector3(0.08, 2.6, 0.08), wood)
			kit.box(Vector3(0, 2.6, -0.1), Vector3(1.9, 0.1, 0.1), wood)
			kit.box(Vector3(0, 0.45, 0), Vector3(1.4, 0.08, 0.6), wood2)
			kit.box(Vector3(0, 0.5, 0), Vector3(1.3, 0.06, 0.55), cloth)
			for sx2 in [-0.65, 0.65]:
				kit.box(Vector3(sx2, 1.55, 0), Vector3(0.02, 2.1, 0.02), metal)
		_:
			kit.box(Vector3(0, h * 0.5, 0), Vector3(w - 0.2, h, d - 0.2), wood)


static func _lamp_small(kit: LpKit, at: Vector3, shade: Color) -> void:
	kit.lathe(at, [Vector2(0.06, 0.0), Vector2(0.02, 0.02), Vector2(0.02, 0.22)], 6, Color("8a7a5a"))
	var saved := kit.layer
	kit.layer = "lumiere"
	kit.lathe(at + Vector3(0, 0.2, 0), [Vector2(0.12, 0.0), Vector2(0.07, 0.15)], 8, shade.lightened(0.4), false, false)
	kit.layer = saved


## Chaise dont l'assise est en at, qui regarde vers cap (0 = +Z).
static func _chair(kit: LpKit, at: Vector3, cap: float, wood: Color, cloth: Color, seat := 0.45) -> void:
	var saved := kit.xf
	kit.xf = saved * Transform3D(Basis(Vector3.UP, cap), at)
	kit.box(Vector3(0, seat, 0), Vector3(0.42, 0.05, 0.42), wood)
	kit.box(Vector3(0, seat + 0.035, 0.01), Vector3(0.36, 0.03, 0.36), cloth)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			kit.box(Vector3(sx * 0.18, seat * 0.5, sz * 0.18), Vector3(0.04, seat, 0.04), wood)
	kit.box(Vector3(0, seat + 0.27, -0.19), Vector3(0.42, 0.45, 0.04), wood)
	kit.xf = saved


## Maillage d'un seul meuble (aperçus, tests).
static func mesh_of(id: String) -> ArrayMesh:
	var e := Meubles.get_entry(id)
	if e.is_empty():
		return null
	var kit := LpKit.new()
	build(kit, e, Transform3D.IDENTITY)
	return kit.commit(materials())
