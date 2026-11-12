class_name EvVisuels
extends RefCounted
## Décors des événements, fabriqués en code (low-poly) : étals du marché,
## tables et guirlandes de la fête, foule, joueurs, feu et fumée, ruines,
## arbres tombés, eau des inondations.

const PEAU := [Color("f1c7a5"), Color("d9a37e"), Color("a86f4c"), Color("6b4430"), Color("e8b996")]
const HABITS := [Color("e76f51"), Color("2a9d8f"), Color("e9c46a"), Color("264653"), Color("f4a261"), Color("8ab17d"),
	Color("6d597a"), Color("b56576"), Color("4ea8de"), Color("f1faee"), Color("1d3557"), Color("ffb703")]
const AUVENTS := [[Color("e63946"), Color("f1faee")], [Color("2a9d8f"), Color("f1faee")], [Color("f4a261"), Color("fefae0")],
	[Color("457b9d"), Color("f1faee")], [Color("6a994e"), Color("f2e8cf")]]
const PRODUITS := [Color("e63946"), Color("ffb703"), Color("8ac926"), Color("fb8500"), Color("6a4c93"), Color("f4f1de"), Color("bc6c25")]

static var _mat: StandardMaterial3D
static var _glow: StandardMaterial3D
static var _water: StandardMaterial3D
static var _people := {}


static func material() -> StandardMaterial3D:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.vertex_color_use_as_albedo = true
		_mat.vertex_color_is_srgb = true
		_mat.roughness = 0.85
	return _mat


## Ampoules des guirlandes : elles brillent un peu, plus la nuit (DayNight n'a pas à s'en occuper).
static func glow_material() -> StandardMaterial3D:
	if _glow == null:
		_glow = StandardMaterial3D.new()
		_glow.vertex_color_use_as_albedo = true
		_glow.vertex_color_is_srgb = true
		_glow.emission_enabled = true
		_glow.emission = Color("ffe8a3")
		_glow.emission_energy_multiplier = 1.6
	return _glow


static func water_material() -> StandardMaterial3D:
	if _water == null:
		_water = StandardMaterial3D.new()
		_water.albedo_color = Color(0.32, 0.42, 0.38, 0.78)
		_water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_water.roughness = 0.08
		_water.metallic_specular = 0.8
		_water.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _water


static func _mesh_instance(k: BlocMesh, mat: Material = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = k.to_mesh(mat if mat != null else material())
	mi.visibility_range_end = 900.0
	return mi


static func _kit() -> BlocMesh:
	var k := BlocMesh.new()
	k.details = false
	return k


# --- Personnages ----------------------------------------------------------------------

## Un habitant debout (1,75 m) : jambes, buste, tête. Repère : pieds en 0, regard vers −Z.
static func person_mesh(habit: Color, peau: Color, pantalon := Color("2b2d42")) -> ArrayMesh:
	var key := "%s|%s|%s" % [habit.to_html(), peau.to_html(), pantalon.to_html()]
	if _people.has(key):
		return _people[key]
	var k := _kit()
	k.box(-0.11, 0.0, 0.0, 0.16, 0.85, 0.2, pantalon)
	k.box(0.11, 0.0, 0.0, 0.16, 0.85, 0.2, pantalon)
	k.box(0.0, 0.85, 0.0, 0.46, 0.6, 0.26, habit)
	k.box(-0.29, 0.9, 0.0, 0.11, 0.52, 0.14, habit)
	k.box(0.29, 0.9, 0.0, 0.11, 0.52, 0.14, habit)
	k.box(0.0, 1.47, 0.0, 0.24, 0.28, 0.24, peau)
	var m := k.to_mesh(material())
	_people[key] = m
	return m


static func random_person(rng: RandomNumberGenerator) -> ArrayMesh:
	return person_mesh(HABITS[rng.randi() % HABITS.size()], PEAU[rng.randi() % PEAU.size()],
		[Color("2b2d42"), Color("3d405b"), Color("6c584c"), Color("1d3557")][rng.randi() % 4])


## Foule : n personnes dans un rectangle (repère local, centre en 0), un peu
## tournées vers `vers` (point local) si donné.
static func foule(n: int, size: Vector2, seed: int, vers := Vector3.INF) -> Node3D:
	var root := Node3D.new()
	root.name = "Foule"
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for i in n:
		var mi := MeshInstance3D.new()
		mi.mesh = random_person(rng)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = 600.0
		var p := Vector3(rng.randf_range(-size.x, size.x) * 0.5, 0.0, rng.randf_range(-size.y, size.y) * 0.5)
		mi.position = p
		if vers.is_finite() and p.distance_to(vers) > 0.5:
			mi.rotation.y = atan2(-(vers.x - p.x), -(vers.z - p.z)) + rng.randf_range(-0.6, 0.6)
		else:
			mi.rotation.y = rng.randf() * TAU
		mi.scale = Vector3.ONE * rng.randf_range(0.82, 1.06)
		root.add_child(mi)
	return root


# --- Marché et fête ------------------------------------------------------------------

## Un étal de marché de 3 × 2 m (auvent rayé, table, cageots), façade vers −Z.
static func etal(k: BlocMesh, cx: float, cz: float, v: int) -> void:
	var a: Array = AUVENTS[v % AUVENTS.size()]
	var bois := Color("8d6346")
	for sx in [-1.4, 1.4]:
		for sz in [-0.9, 0.9]:
			k.box(cx + sx, 0.0, cz + sz, 0.08, 2.3, 0.08, bois)
	k.box(cx, 0.0, cz - 0.5, 2.9, 0.85, 0.9, Color("c9b79c"))
	# Cageots de fruits et légumes.
	for i in 4:
		var col: Color = PRODUITS[(v * 3 + i) % PRODUITS.size()]
		k.box(cx - 1.05 + i * 0.7, 0.85, cz - 0.55, 0.6, 0.18, 0.5, Color("a47148"))
		k.box(cx - 1.05 + i * 0.7, 1.03, cz - 0.55, 0.52, 0.12, 0.42, col)
	# Auvent à rayures.
	for i in 6:
		k.box(cx - 1.25 + i * 0.5, 2.3, cz, 0.5, 0.08, 2.2, a[i % 2])
	k.box(cx, 2.05, cz - 1.12, 3.0, 0.25, 0.04, a[0])


## Marché : n étals en rangées autour du centre (repère local).
static func marche(n: int, seed: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Marche"
	var k := _kit()
	var cols := clampi(ceili(sqrt(float(n))), 2, 6)
	var i := 0
	for r in range(ceili(float(n) / cols)):
		for c in cols:
			if i >= n:
				break
			var x := (c - (cols - 1) * 0.5) * 4.0
			var z := (r - (ceili(float(n) / cols) - 1) * 0.5) * 5.0
			# Une rangée sur deux tournée vers l'allée.
			etal(k, x, z if r % 2 == 0 else z, posmod(seed + i, 97))
			i += 1
	root.add_child(_mesh_instance(k))
	return root


## Fête de quartier : longues tables et bancs, petite scène, guirlandes d'ampoules.
static func fete(seed: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Fete"
	var k := _kit()
	var bois := Color("b08968")
	var nappe := [Color("f1faee"), Color("e63946"), Color("f1faee")]
	for r in 3:
		var z := -4.0 + r * 4.0
		k.box(0.0, 0.72, z, 9.0, 0.06, 0.9, nappe[r % 3])
		for x in [-4.0, 0.0, 4.0]:
			k.box(x, 0.0, z, 0.1, 0.72, 0.7, bois)
		for side in [-0.8, 0.8]:
			k.box(0.0, 0.42, z + side, 8.8, 0.05, 0.3, bois)
	# Scène et enceintes.
	k.box(0.0, 0.0, -9.0, 6.0, 0.6, 3.0, Color("3d405b"))
	k.box(-2.6, 0.6, -10.0, 0.6, 1.4, 0.5, Color("1b1b1b"))
	k.box(2.6, 0.6, -10.0, 0.6, 1.4, 0.5, Color("1b1b1b"))
	k.box(0.0, 0.6, -10.4, 6.0, 2.6, 0.1, Color("e9c46a"))
	# Buvette.
	k.box(7.5, 0.0, -2.0, 1.2, 1.1, 4.0, Color("8d6346"))
	k.box(7.5, 2.4, -2.0, 2.0, 0.08, 4.6, Color("2a9d8f"))
	for z in [-4.0, 0.0]:
		k.box(8.2, 0.0, z, 0.08, 2.4, 0.08, bois)
	# Mâts des guirlandes.
	for p in [Vector2(-6, -7), Vector2(6, -7), Vector2(-6, 6), Vector2(6, 6)]:
		k.box(p.x, 0.0, p.y, 0.12, 4.2, 0.12, Color("6c584c"))
	root.add_child(_mesh_instance(k))
	# Guirlandes (ampoules lumineuses).
	var g := _kit()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for line in [[Vector3(-6, 4.1, -7), Vector3(6, 4.1, 6)], [Vector3(6, 4.1, -7), Vector3(-6, 4.1, 6)],
			[Vector3(-6, 4.1, -7), Vector3(6, 4.1, -7)], [Vector3(-6, 4.1, 6), Vector3(6, 4.1, 6)]]:
		var a: Vector3 = line[0]
		var b: Vector3 = line[1]
		for i in 15:
			var t := (i + 0.5) / 15.0
			var p := a.lerp(b, t)
			p.y -= sin(t * PI) * 0.8
			var col: Color = [Color("ffd166"), Color("ef476f"), Color("06d6a0"), Color("118ab2"), Color("fff3b0")][rng.randi() % 5]
			g.box(p.x, p.y - 0.12, p.z, 0.16, 0.2, 0.16, col)
	var bulbs := _mesh_instance(g, glow_material())
	bulbs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(bulbs)
	var light := OmniLight3D.new()
	light.position = Vector3(0, 4.5, 0)
	light.light_color = Color("ffd59a")
	light.omni_range = 18.0
	light.light_energy = 1.2
	light.name = "Lumiere"
	root.add_child(light)
	return root


# --- Feu et fumée ---------------------------------------------------------------------

static var _flame_mat: StandardMaterial3D
static var _smoke_mat: StandardMaterial3D


static func _particle_material(col: Color, additive: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_color = col
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_texture = _soft_dot()
	return m


static var _dot: GradientTexture2D


## Tache ronde et douce (flammes et fumée sans bords carrés).
static func _soft_dot() -> GradientTexture2D:
	if _dot == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.45, Color(1, 1, 1, 0.75))
		_dot = GradientTexture2D.new()
		_dot.gradient = g
		_dot.fill = GradientTexture2D.FILL_RADIAL
		_dot.fill_from = Vector2(0.5, 0.5)
		_dot.fill_to = Vector2(1.0, 0.5)
		_dot.width = 64
		_dot.height = 64
	return _dot


## Feu sur un bâtiment (boîte de taille `size`, repère au sol au centre).
static func feu(size: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "Feu"
	if _flame_mat == null:
		_flame_mat = _particle_material(Color(1.0, 0.55, 0.15), true)
		_smoke_mat = _particle_material(Color(0.12, 0.11, 0.1, 0.55), false)
	var flames := GPUParticles3D.new()
	flames.name = "Flammes"
	flames.amount = 90
	flames.lifetime = 1.1
	flames.visibility_aabb = AABB(Vector3(-size.x, 0, -size.z), Vector3(size.x * 2, size.y + 20, size.z * 2))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(size.x * 0.45, 0.5, size.z * 0.45)
	pm.direction = Vector3.UP
	pm.spread = 15.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 5.0
	pm.gravity = Vector3(0, 2.0, 0)
	pm.scale_min = 1.2
	pm.scale_max = 2.6
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.85, 0.3, 1.0))
	ramp.set_color(1, Color(0.8, 0.12, 0.02, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = ramp
	pm.color_ramp = gt
	flames.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(1.6, 2.2)
	q.material = _flame_mat
	flames.draw_pass_1 = q
	flames.position = Vector3(0, size.y * 0.55, 0)
	root.add_child(flames)
	var smoke := GPUParticles3D.new()
	smoke.name = "Fumee"
	smoke.amount = 60
	smoke.lifetime = 7.0
	smoke.visibility_aabb = AABB(Vector3(-60, 0, -60), Vector3(120, 120, 120))
	var sm := ParticleProcessMaterial.new()
	sm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	sm.emission_box_extents = Vector3(size.x * 0.35, 0.5, size.z * 0.35)
	sm.direction = Vector3(0.25, 1, 0.1)
	sm.spread = 12.0
	sm.initial_velocity_min = 3.0
	sm.initial_velocity_max = 5.0
	sm.gravity = Vector3(1.0, 1.0, 0.3)
	sm.scale_min = 3.0
	sm.scale_max = 6.0
	var sramp := Gradient.new()
	sramp.set_color(0, Color(0.2, 0.18, 0.16, 0.75))
	sramp.set_color(1, Color(0.5, 0.5, 0.5, 0.0))
	var st := GradientTexture1D.new()
	st.gradient = sramp
	sm.color_ramp = st
	var scurve := Curve.new()
	scurve.add_point(Vector2(0, 0.5))
	scurve.add_point(Vector2(1, 2.0))
	var sct := CurveTexture.new()
	sct.curve = scurve
	sm.scale_curve = sct
	smoke.process_material = sm
	var sq := QuadMesh.new()
	sq.size = Vector2(3.0, 3.0)
	sq.material = _smoke_mat
	smoke.draw_pass_1 = sq
	smoke.position = Vector3(0, size.y + 1.0, 0)
	root.add_child(smoke)
	var light := OmniLight3D.new()
	light.name = "Lueur"
	light.light_color = Color(1.0, 0.5, 0.15)
	light.omni_range = maxf(size.x, size.z) * 1.6 + 10.0
	light.light_energy = 3.0
	light.position = Vector3(0, size.y * 0.7, 0)
	root.add_child(light)
	return root


## Intensité du feu (0 à 1) : plus ou moins de flammes.
static func regle_feu(node: Node3D, i: float) -> void:
	var f := node.get_node_or_null("Flammes") as GPUParticles3D
	if f != null:
		f.amount_ratio = clampf(0.15 + i, 0.0, 1.0)
	var s := node.get_node_or_null("Fumee") as GPUParticles3D
	if s != null:
		s.amount_ratio = clampf(0.3 + i * 0.7, 0.0, 1.0)
	var l := node.get_node_or_null("Lueur") as OmniLight3D
	if l != null:
		l.light_energy = (1.0 + 3.0 * i) * (0.85 + 0.3 * randf())


## Fumée seule (feu éteint, le bâtiment fume encore un moment).
static func fumee_seule(node: Node3D) -> void:
	var f := node.get_node_or_null("Flammes") as GPUParticles3D
	if f != null:
		f.emitting = false
	var l := node.get_node_or_null("Lueur") as OmniLight3D
	if l != null:
		l.visible = false
	var s := node.get_node_or_null("Fumee") as GPUParticles3D
	if s != null:
		s.amount_ratio = 0.35


# --- Ruines, arbres, eau -------------------------------------------------------------

## Ruine d'un bâtiment de taille size (cases) : dalle noircie, pans de murs, gravats.
static func ruine(size: Vector2i, cause: String, seed: int) -> MeshInstance3D:
	var k := _kit()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var w := float(size.x) - 1.0
	var d := float(size.y) - 1.0
	var mur := Color("2b2522") if cause == "incendie" else Color("8a817c")
	var gravats := Color("4a403a") if cause == "incendie" else Color("a39e93")
	k.plate(0, 0, w, d, Color("3a3532"), 0.0, 0.12)
	var bw := minf(w, 16.0) * 0.8
	var bd := minf(d, 16.0) * 0.8
	for side in 4:
		var n := 3 + rng.randi() % 3
		for i in n:
			var t := (i + 0.5) / n
			var h := rng.randf_range(0.4, 3.2)
			if side < 2:
				var z := (-bd if side == 0 else bd) * 0.5
				k.box(lerpf(-bw * 0.5, bw * 0.5, t), 0.0, z, bw / n * 0.9, h, 0.3, mur)
			else:
				var x := (-bw if side == 2 else bw) * 0.5
				k.box(x, 0.0, lerpf(-bd * 0.5, bd * 0.5, t), 0.3, h, bd / n * 0.9, mur)
	for i in 14:
		k.box(rng.randf_range(-bw, bw) * 0.45, 0.0, rng.randf_range(-bd, bd) * 0.45, rng.randf_range(0.4, 1.6),
			rng.randf_range(0.2, 0.7), rng.randf_range(0.4, 1.6), gravats.lerp(Color("1b1b1b"), rng.randf() * 0.4))
	# Ruban de chantier autour.
	for p in [[0.0, -d * 0.5, w, 0.06], [0.0, d * 0.5, w, 0.06], [-w * 0.5, 0.0, 0.06, d], [w * 0.5, 0.0, 0.06, d]]:
		k.box(p[0], 0.9, p[1], p[2], 0.08, p[3], Color("ff3b30"))
	var mi := _mesh_instance(k)
	mi.visibility_range_end = 1400.0
	return mi


## Arbre couché en travers de la route (longueur ~9 m), dans l'axe X local.
static func arbre_tombe(seed: int) -> MeshInstance3D:
	var k := _kit()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var tronc := Color("6b4f3a")
	for i in 8:
		k.box(-4.0 + i * 1.0, 0.0, 0.0, 1.05, 0.55, 0.55, tronc.lerp(Color("4a3728"), rng.randf() * 0.3))
	k.box(-4.6, 0.0, 0.0, 0.6, 1.2, 1.4, Color("5a4030"))
	var vert := Color("4c8c3f")
	for i in 7:
		k.box(rng.randf_range(1.5, 5.5), rng.randf_range(0.0, 0.8), rng.randf_range(-1.8, 1.8),
			rng.randf_range(1.2, 2.2), rng.randf_range(1.0, 1.8), rng.randf_range(1.2, 2.2), vert.lerp(Color("2d6a4f"), rng.randf()))
	return _mesh_instance(k)


## Nappe d'eau d'une inondation : bandes autour de segments (points 3D au niveau de l'eau).
static func nappe(segments: Array, half_width: float) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for s in segments:
		var a: Vector3 = s[0]
		var b: Vector3 = s[1]
		var dir := Vector3(b.x - a.x, 0, b.z - a.z)
		if dir.length() < 0.01:
			continue
		var side := Vector3(-dir.z, 0, dir.x).normalized() * half_width
		var ext := dir.normalized() * half_width * 0.6
		var p0 := a - ext - side
		var p1 := a - ext + side
		var p2 := b + ext + side
		var p3 := b + ext - side
		st.set_normal(Vector3.UP)
		for p in [p0, p1, p2, p0, p2, p3]:
			st.add_vertex(p)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = water_material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 3000.0
	return mi


# --- Stade : joueurs, ballon, tribunes pleines ---------------------------------------------

## Un joueur (maillot, short, chaussettes de la couleur de l'équipe).
static func joueur_mesh(maillot: Color, short: Color, peau: Color) -> ArrayMesh:
	var key := "j|%s|%s|%s" % [maillot.to_html(), short.to_html(), peau.to_html()]
	if _people.has(key):
		return _people[key]
	var k := _kit()
	k.box(-0.11, 0.0, 0.0, 0.15, 0.12, 0.26, Color("1b1b1b"))
	k.box(0.11, 0.0, 0.0, 0.15, 0.12, 0.26, Color("1b1b1b"))
	k.box(-0.11, 0.12, 0.0, 0.14, 0.4, 0.16, maillot)
	k.box(0.11, 0.12, 0.0, 0.14, 0.4, 0.16, maillot)
	k.box(-0.11, 0.52, 0.0, 0.14, 0.33, 0.16, peau)
	k.box(0.11, 0.52, 0.0, 0.14, 0.33, 0.16, peau)
	k.box(0.0, 0.8, 0.0, 0.4, 0.22, 0.24, short)
	k.box(0.0, 1.02, 0.0, 0.44, 0.48, 0.25, maillot)
	k.box(-0.28, 1.05, 0.0, 0.1, 0.42, 0.13, maillot)
	k.box(0.28, 1.05, 0.0, 0.1, 0.42, 0.13, maillot)
	k.box(0.0, 1.5, 0.0, 0.22, 0.26, 0.22, peau)
	var m := k.to_mesh(material())
	_people[key] = m
	return m


static func ballon_mesh() -> ArrayMesh:
	var k := _kit()
	k.box(0.0, 0.0, 0.0, 0.24, 0.24, 0.24, Color("f8f9fa"))
	return k.to_mesh(material())


## Spectateurs assis dans un bol de tribunes (repère local de la pelouse, longueur selon X).
## bol : demi-longueur et demi-largeur du bord des tribunes ; tribune : profondeur et hauteur.
## remplissage 0 à 1. Un seul MultiMesh, couleurs par spectateur.
static func spectateurs(bol: Vector2, tribune: Vector2, remplissage: float, couleurs: Array, seed: int) -> MultiMeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var depth := maxf(tribune.x * 0.8, 6.0)
	var height := maxf(tribune.y * 0.7, 3.0)
	var rows := clampi(int(depth / 1.6), 4, 22)
	var pts: Array[Transform3D] = []
	var cols: Array[Color] = []
	var step := 1.4
	for side in 4:
		var along := bol.x * 2.0 if side < 2 else bol.y * 2.0
		var n := int(along / step)
		for r in rows:
			var f := float(r) / rows
			var off := 1.5 + f * depth
			var y := 1.0 + f * height
			for i in n:
				if rng.randf() > remplissage:
					continue
				var t := -along * 0.5 + (i + 0.5) * step + rng.randf_range(-0.2, 0.2)
				var p: Vector3
				var rot := 0.0
				match side:
					0:
						p = Vector3(t, y, -(bol.y + off))
						rot = 0.0
					1:
						p = Vector3(t, y, bol.y + off)
						rot = PI
					2:
						p = Vector3(-(bol.x + off), y, t)
						rot = -PI / 2.0
					_:
						p = Vector3(bol.x + off, y, t)
						rot = PI / 2.0
				pts.append(Transform3D(Basis(Vector3.UP, rot), p))
				var c: Color
				if rng.randf() < 0.6 and not couleurs.is_empty():
					c = Color(String(couleurs[rng.randi() % couleurs.size()]))
				else:
					c = HABITS[rng.randi() % HABITS.size()]
				cols.append(c)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var k := _kit()
	k.box(0.0, 0.0, 0.0, 0.5, 0.55, 0.4, Color.WHITE)
	k.box(0.0, 0.55, 0.0, 0.24, 0.24, 0.24, Color("f1c7a5"))
	mm.mesh = k.to_mesh()
	mm.instance_count = pts.size()
	for i in pts.size():
		mm.set_instance_transform(i, pts[i])
		mm.set_instance_color(i, cols[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Spectateurs"
	mmi.multimesh = mm
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.9
	mmi.material_override = m
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = 1200.0
	return mmi
