extends SceneTree
## Vitrine de la production : forêt à l'ouest, champs à l'est, quelques sites,
## la carte du bois sur le terrain et le panneau Production.
## Usage (avec affichage) :
##   godot --path . --rendering-driver opengl3 --script res://tests/production_vitrine.gd -- --dossier /chemin/captures


func _initialize() -> void:
	_run.call_deferred()


func _flat_tile(t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	for j in 256:
		for i in 256:
			a[i + j * 256] = 40.0 + 6.0 * sin((t.x * 256 + i) * 0.02) * cos((t.y * 256 + j) * 0.017)
	return a


func _shot(path: String) -> void:
	for i in 12:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(path)
	print("capture : ", path)


func _place(bs: BuildingSystem, id: String, x: int, north := true) -> int:
	var d := int(BuildingCatalog.get_type(id).d)
	var c := Vector2i(x, -(d / 2 + 6) if north else d / 2 + 6)
	return bs.place(id, c, bs.best_rotation(id, c))


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var dir := "."
	for i in args.size() - 1:
		if args[i] == "--dossier":
			dir = args[i + 1]
	root.size = Vector2i(1600, 900)
	Creations.persist = false
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var transport: TransportSystem = scene.get_node("Transport")
	var bs: BuildingSystem = scene.get_node("Batiments")
	var amb: DayNight = scene.get_node("Ambiance")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, lon: float) -> int: return 10 if lon < 6.7485 else 40
	world.view_radius_override = 700.0
	world.set_origin(49.15, 6.75)
	for i in 120:
		await process_frame
	amb.set_speed(0)
	amb.unix_time = Time.get_unix_time_from_datetime_string("2026-06-10T09:00:00")
	bs.unlimited_money = true
	var y := world.cell_height(Vector2i(0, 0))
	transport.build_segment("route", Vector3(-320, y, 0), Vector3(320, y, 0))
	_place(bs, "exploitation_forestiere", -230)
	_place(bs, "scierie", -170)
	_place(bs, "menuiserie", -120)
	_place(bs, "ferme_cereales", 160)
	_place(bs, "moulin", 105)
	_place(bs, "fournil", 70)
	_place(bs, "elevage", 230)
	_place(bs, "briqueterie", -40, false)
	_place(bs, "acierie", 60, false)
	_place(bs, "mine", 150, false)
	_place(bs, "puits", 210, false)
	_place(bs, "raffinerie", -130, false)
	var rig: Node3D = scene.get_node("CameraRig")
	rig.position = Vector3(0, y, 0)
	rig._target_distance = 260.0
	rig.rotation_degrees.y = 20.0
	await _shot(dir.path_join("apercu-production-sites.png"))
	scene.resource_overlay.show_resource("bois")
	scene.production_panel.set_open(true)
	scene.production_panel.show_view("ressources")
	await _shot(dir.path_join("apercu-production-carte-bois.png"))
	quit()
