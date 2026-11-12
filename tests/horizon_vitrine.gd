extends SceneTree
## Vitrine de la caméra rasante : un vrai lieu (relief téléchargé), vu de haut
## puis à l'horizontale jusqu'à 10 km.
## Usage (avec affichage et réseau) :
##   godot --path . --rendering-driver opengl3 --script res://tests/horizon_vitrine.gd -- --dossier /chemin/captures [--lieu 45.86,6.17] [--angle 200]


func _initialize() -> void:
	_run.call_deferred()


func _shot(path: String) -> void:
	for i in 20:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(path)
	print("Capture : ", path)


func _wait_loaded(world: TerrainWorld, max_ms: int) -> void:
	var t0 := Time.get_ticks_msec()
	var stable := 0
	var last := -1
	while Time.get_ticks_msec() - t0 < max_ms:
		await process_frame
		var n := world.horizon.patches.size()
		var busy := world.tiles.pending_count() + world.horizon.tiles.pending_count() + world.land.pending_count()
		stable = stable + 1 if n == last and busy == 0 and world.missing_chunk_count() == 0 else 0
		last = n
		if stable > 60:
			break
	print("Plaques : %d, blocs : %d (%d ms)" % [world.horizon.patches.size(), world.chunks.size(), Time.get_ticks_msec() - t0])


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var dir := "user://captures"
	var lieu := Vector2(45.8992, 6.1294) # Annecy, vers le lac et ses montagnes
	var angle := 225.0
	for i in args.size():
		if args[i] == "--dossier" and i + 1 < args.size():
			dir = args[i + 1]
		elif args[i] == "--lieu" and i + 1 < args.size():
			lieu = Geo.parse_lat_lon(args[i + 1])
		elif args[i] == "--angle" and i + 1 < args.size():
			angle = args[i + 1].to_float()
	DirAccess.make_dir_recursive_absolute(dir)
	root.size = Vector2i(1600, 900)
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	root.add_child(scene)
	var world: TerrainWorld = scene.get_node("Terrain")
	var rig = scene.get_node("CameraRig")
	var ambiance = scene.get_node("Ambiance")
	if ambiance.has_method("set_local_hour"):
		ambiance.set_local_hour(15.0)
	world.set_origin(lieu.x, lieu.y)
	rig.rotation_degrees.y = angle
	rig._target_distance = 250.0
	rig.set_pitch(55.0, true)
	await _wait_loaded(world, 60_000)
	await _shot(dir.path_join("horizon-avant-55deg.png"))
	rig.set_pitch(12.0, true)
	await _wait_loaded(world, 30_000)
	await _shot(dir.path_join("horizon-rasant-12deg.png"))
	rig._target_distance = 900.0
	rig.set_pitch(20.0, true)
	await _wait_loaded(world, 60_000)
	await _shot(dir.path_join("horizon-haut-20deg.png"))
	quit(0)
