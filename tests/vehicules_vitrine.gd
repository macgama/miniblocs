extends SceneTree
## Vitrine du catalogue de véhicules : aligne les modèles d'une ou plusieurs
## catégories et prend une capture.
## Usage (avec affichage) :
##   godot --path . --rendering-driver opengl3 --script res://tests/vehicules_vitrine.gd -- --screenshot v.png --cat voiture,bus [--yaw 35] [--pitch 30] [--zoom 1.0]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var shot := "vehicules.png"
	var cats: PackedStringArray = ["voiture"]
	var yaw := 35.0
	var pitch := 28.0
	var zoom := 1.0
	var only := ""
	for i in args.size():
		if i + 1 >= args.size():
			break
		match args[i]:
			"--screenshot": shot = args[i + 1]
			"--cat": cats = args[i + 1].split(",")
			"--yaw": yaw = args[i + 1].to_float()
			"--pitch": pitch = args[i + 1].to_float()
			"--zoom": zoom = args[i + 1].to_float()
			"--ids": only = args[i + 1]
	root.size = Vector2i(1600, 900)
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("bfe3f5")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.78, 0.85)
	env.environment.ambient_light_energy = 0.7
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	world.add_child(sun)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.6
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var ids: Array[String] = []
	if only != "":
		for s in only.split(","):
			ids.append(s)
	else:
		for c in cats:
			ids.append_array(VehicleCatalog.ids_in(c, true))
	var water := false
	# Rangées : on remplit de gauche à droite jusqu'à une largeur cible.
	var total := 0.0
	for id in ids:
		total += float(VehicleCatalog.get_type(id).W) + 2.0
	var row_w := maxf(30.0, sqrt(total * 12.0))
	var x := 0.0
	var z := 0.0
	var row_depth := 0.0
	var max_x := 0.0
	for id in ids:
		var t := VehicleCatalog.get_type(id)
		var w := float(t.W) + 2.0
		if t.mode == TransportTypes.Mode.WATER:
			water = true
		if x > 0.0 and x + w > row_w:
			x = 0.0
			z += row_depth + 4.0
			row_depth = 0.0
		var mi := MeshInstance3D.new()
		mi.mesh = VehicleCatalog.build_mesh(id, ids.find(id))
		mi.material_override = mat
		# Avant vers la caméra (−Z vers +Z vu de dessus) : on fait pivoter.
		mi.rotation_degrees.y = 180.0
		mi.position = Vector3(x + w / 2.0, 0, z + float(t.L) / 2.0)
		world.add_child(mi)
		x += w
		max_x = maxf(max_x, x)
		row_depth = maxf(row_depth, float(t.L))
	var depth := z + row_depth
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(max_x + 200, depth + 200)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("3d7ea6") if water else Color("8a9a5b")
	ground.material_override = gm
	ground.position = Vector3(max_x / 2.0, -0.01 if not water else 0.0, depth / 2.0)
	world.add_child(ground)

	var cam := Camera3D.new()
	world.add_child(cam)
	var center := Vector3(max_x / 2.0, 0, depth / 2.0)
	var radius := maxf(max_x, depth) * 0.62 / zoom
	var dir := Vector3(sin(deg_to_rad(yaw)), 0, cos(deg_to_rad(yaw))) * cos(deg_to_rad(pitch)) + Vector3(0, sin(deg_to_rad(pitch)), 0)
	cam.position = center + dir * radius * 1.6 + Vector3(0, 2, 0)
	cam.look_at(center, Vector3.UP)
	cam.fov = 45.0
	cam.far = 4000.0
	cam.current = true
	sun.directional_shadow_max_distance = radius * 4.0
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(shot)
	print("Vitrine : %d véhicules, capture %s" % [ids.size(), shot])
	quit()
