extends Node3D
## Vitrine des plantes et des textures du sol : chaque biome sur sa parcelle
## (texture du sol + plantes du biome), puis une rangée de champs.
## Ouvre scenes/vitrine_plantes.tscn et appuie sur F6.
## Molette : zoom. Clic gauche glissé : tourner. Espace : arrêter / relancer la rotation.
## Touches 1 à 3 : vues (ensemble, forêts, champs).
## Capture : godot --path . res://scenes/vitrine_plantes.tscn -- --screenshot plantes.png [--vue 2]

const TAILLE := 14.0 # côté d'une parcelle de biome (m)
const CHAMP := 10.0

## [titre, couche de sol, couleur du biome (hex), [[espèce, nombre], ...]]
const BIOMES := [
	["Forêt tempérée", "sous_bois", "4c8c3c", [["chene", 2], ["hetre", 1], ["bouleau", 2], ["buisson", 3], ["fougere", 6], ["herbe", 6]]],
	["Forêt boréale et montagne", "sous_bois", "4c8c3c", [["sapin", 2], ["epicea", 2], ["meleze", 1], ["pin", 1], ["fougere", 4], ["rocher", 1]]],
	["Méditerranée", "broussailles", "8d9a58", [["pin_parasol", 1], ["olivier", 2], ["lavande", 6], ["genet", 3], ["buisson_sec", 3]]],
	["Tropiques", "sous_bois", "3b7354", [["tropical", 1], ["palmier", 2], ["fougere", 5], ["buisson", 3]]],
	["Savane", "broussailles", "a8a060", [["acacia", 1], ["baobab", 1], ["hautes_herbes", 18], ["buisson_sec", 3]]],
	["Désert", "sable", "e6d59c", [["cactus_saguaro", 2], ["cactus_raquette", 3], ["agave", 4], ["rocher_desert", 1], ["buisson_sec", 3], ["cailloux", 3]]],
	["Prairie", "herbe", "5d9e47", [["saule", 1], ["peuplier", 1], ["herbe", 20], ["coquelicots", 5], ["marguerites", 5], ["fleurs_jaunes", 4], ["buisson_fleuri", 1]]],
	["Marais et mangrove", "vase", "6c9a7c", [["roseaux", 18], ["paletuvier", 1], ["saule", 1], ["hautes_herbes", 4]]],
	["Toundra", "toundra", "a9a88a", [["saule_nain", 8], ["lichen", 12], ["bouleau", 1], ["cailloux", 5], ["rocher", 1]]],
	["Alpage et roche", "roche", "8e8a82", [["gros_rocher", 1], ["rocher", 2], ["cailloux", 8], ["gentianes", 10], ["lichen", 4]]],
]
## Champs : indice dans Sols.CULTURES.
const CHAMPS := [0, 1, 2, 3, 4, 5, 6, 7, 8]

var _cam: Camera3D
var _yaw := 25.0
var _pitch := 32.0
var _dist := 95.0
var _centre := Vector3.ZERO
var _tourne := true
var _sol_verts := PackedVector3Array()
var _sol_cols := PackedColorArray()
var _sol_uvs := PackedVector2Array()
var _groupes := {} # espèce -> [Array[Transform3D], PackedColorArray]
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 7
	_decor()
	var colonnes := 5
	for b in BIOMES.size():
		var x0 := (b % colonnes) * (TAILLE + 2.0)
		var z0 := (b / colonnes) * (TAILLE + 2.0)
		var biome: Array = BIOMES[b]
		_parcelle(x0, z0, TAILLE, TAILLE, Sols.COUCHES.find(biome[1]), Color(biome[2]), false)
		for e in biome[3]:
			for n in e[1]:
				_ajoute(Plantes.id(e[0]), Vector3(x0 + _rng.randf_range(1.0, TAILLE - 1.0), 0, z0 + _rng.randf_range(1.0, TAILLE - 1.0)), _rng.randf() * TAU, _rng.randf_range(0.8, 1.15))
	var zc := 2.0 * (TAILLE + 2.0) + 2.0
	for n in CHAMPS.size():
		var cu: Array = Sols.CULTURES[CHAMPS[n]]
		var x0 := n * (CHAMP + 1.0)
		var tourne := n % 2 == 1
		_parcelle(x0, zc, CHAMP, CHAMP, cu[1], Color("d2c06a"), tourne)
		if cu[2] == "":
			continue
		var e := Plantes.id(cu[2])
		for i in int(CHAMP):
			for j in int(CHAMP):
				if _rng.randf() > float(cu[3]):
					continue
				var vigne: bool = cu[2] == "vigne"
				if vigne and (i if tourne else j) % 2 != 0:
					continue
				var p := Vector3(x0 + i + 0.5, 0, zc + j + 0.5)
				if vigne:
					p += Vector3(-0.5, 0, 0) if tourne else Vector3(0, 0, -0.5)
				_ajoute(e, p, PI / 2.0 if tourne else 0.0, _rng.randf_range(0.9, 1.1))
	_construit()
	var largeur := colonnes * (TAILLE + 2.0)
	_centre = Vector3(largeur / 2.0, 2.0, zc / 2.0 + 4.0)
	_cam = Camera3D.new()
	_cam.fov = 45
	_cam.far = 2000
	add_child(_cam)
	var args := OS.get_cmdline_user_args()
	var iv := args.find("--vue")
	if iv >= 0 and iv + 1 < args.size():
		_vue(int(args[iv + 1]))
	_place_camera()
	var i := args.find("--screenshot")
	if i >= 0 and i + 1 < args.size():
		_capture(args[i + 1])


func _vue(n: int) -> void:
	match n:
		1:
			_yaw = 25.0; _pitch = 32.0; _dist = 95.0; _centre = Vector3(40.0, 2.0, 21.0)
		2:
			_yaw = 15.0; _pitch = 18.0; _dist = 42.0; _centre = Vector3(24.0, 4.0, 7.0)
		3:
			_yaw = 0.0; _pitch = 50.0; _dist = 42.0; _centre = Vector3(49.0, 0.0, 37.0)


func _ajoute(e: int, p: Vector3, angle: float, sc: float) -> void:
	if e < 0:
		return
	if not _groupes.has(e):
		var l: Array[Transform3D] = []
		_groupes[e] = [l, PackedColorArray()]
	_groupes[e][0].append(Transform3D(Basis(Vector3.UP, angle).scaled(Vector3.ONE * sc), p))
	var s := _rng.randf_range(0.9, 1.1)
	var dh := _rng.randf_range(-0.05, 0.05)
	_groupes[e][1].append(Color(s * (1.0 + dh), s, s * (1.0 - dh)))


func _parcelle(x0: float, z0: float, lx: float, lz: float, couche: int, couleur: Color, tourne: bool) -> void:
	var c := couleur.srgb_to_linear()
	var uv := Vector2(couche, 1.0 if tourne else 0.0)
	for p in [Vector3(x0, 0, z0), Vector3(x0 + lx, 0, z0), Vector3(x0 + lx, 0, z0 + lz),
			Vector3(x0, 0, z0), Vector3(x0 + lx, 0, z0 + lz), Vector3(x0, 0, z0 + lz)]:
		_sol_verts.append(p)
		_sol_cols.append(c)
		_sol_uvs.append(uv)


func _construit() -> void:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _sol_verts
	var normales := PackedVector3Array()
	normales.resize(_sol_verts.size())
	normales.fill(Vector3.UP)
	arrays[Mesh.ARRAY_NORMAL] = normales
	arrays[Mesh.ARRAY_COLOR] = _sol_cols
	arrays[Mesh.ARRAY_TEX_UV] = _sol_uvs
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var sol := MeshInstance3D.new()
	sol.mesh = m
	sol.position.y = 0.01
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://scripts/terre/terrain.gdshader")
	mat.set_shader_parameter("sols", Sols.texture())
	mat.set_shader_parameter("avec_textures", true)
	mat.set_shader_parameter("premiere_couleur", Sols.PREMIERE_COULEUR)
	mat.set_shader_parameter("grid_strength", 0.12)
	sol.material_override = mat
	add_child(sol)
	for e: int in _groupes:
		var mesh := Plantes.mesh(e)
		if mesh == null:
			continue
		var liste: Array[Transform3D] = _groupes[e][0]
		var cols: PackedColorArray = _groupes[e][1]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = mesh
		mm.instance_count = liste.size()
		for n in liste.size():
			mm.set_instance_transform(n, liste[n])
			var c := cols[n]
			mm.set_instance_custom_data(n, Color(c.r, c.g, c.b, Plantes.vent(e)))
		var inst := MultiMeshInstance3D.new()
		inst.multimesh = mm
		inst.material_override = Plantes.materiau()
		add_child(inst)


func _decor() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var ciel := ProceduralSkyMaterial.new()
	ciel.sky_top_color = Color("6f9fd8")
	ciel.sky_horizon_color = Color("cfdbe6")
	env.sky = Sky.new()
	env.sky.sky_material = ciel
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.ssao_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var soleil := DirectionalLight3D.new()
	soleil.rotation_degrees = Vector3(-50, -40, 0)
	soleil.light_energy = 1.3
	soleil.shadow_enabled = true
	soleil.directional_shadow_max_distance = 250.0
	add_child(soleil)
	var fond := MeshInstance3D.new()
	var plan := PlaneMesh.new()
	plan.size = Vector2(1200, 1200)
	fond.mesh = plan
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("7a8a6a")
	mat.roughness = 1.0
	fond.material_override = mat
	add_child(fond)


func _place_camera() -> void:
	var dir := Vector3(
		sin(deg_to_rad(_yaw)) * cos(deg_to_rad(_pitch)),
		sin(deg_to_rad(_pitch)),
		cos(deg_to_rad(_yaw)) * cos(deg_to_rad(_pitch)))
	_cam.position = _centre + dir * _dist
	_cam.look_at(_centre)


func _process(delta: float) -> void:
	if _tourne:
		_yaw += delta * 6.0
		_place_camera()


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_dist = maxf(4.0, _dist * 0.9)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_dist = minf(400.0, _dist * 1.1)
		_place_camera()
	elif e is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var mm := e as InputEventMouseMotion
		_yaw -= mm.relative.x * 0.3
		_pitch = clampf(_pitch + mm.relative.y * 0.3, 3.0, 85.0)
		_place_camera()
	elif e is InputEventKey and e.pressed:
		var k := (e as InputEventKey).keycode
		if k == KEY_SPACE:
			_tourne = not _tourne
		elif k >= KEY_1 and k <= KEY_3:
			_tourne = false
			_vue(k - KEY_0)
			_place_camera()


func _capture(chemin: String) -> void:
	_tourne = false
	for _i in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(chemin)
	print("CAPTURE OK ", chemin)
	get_tree().quit()
