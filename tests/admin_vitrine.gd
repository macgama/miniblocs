extends SceneTree
## Vitrine du panneau Admin : une capture du panneau ouvert sur une petite ville,
## et une du panneau Construire avec le déblocage par paliers. Usage (avec affichage) :
##   godot --path . --rendering-driver opengl3 --script res://tests/admin_vitrine.gd -- --dossier /chemin/captures


func _initialize() -> void:
	_run.call_deferred()


func _flat_tile(_t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(40.0)
	return a


func _shot(path: String) -> void:
	for i in 8:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(path)
	print("capture : ", path)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var dir := "."
	for i in args.size() - 1:
		if args[i] == "--dossier":
			dir = args[i + 1]
	root.size = Vector2i(1600, 900)
	Creations.persist = false
	var pre := ReglagesPartie.preset("difficile")
	ReglagesPartie.prochaine = pre
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var transport: TransportSystem = scene.get_node("Transport")
	var bs: BuildingSystem = scene.get_node("Batiments")
	var amb: DayNight = scene.get_node("Ambiance")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.set_origin(48.8584, 2.2945)
	for i in 60:
		await process_frame
	amb.set_speed(0)
	amb.unix_time = Time.get_unix_time_from_datetime_string("2026-03-10T09:00:00")
	var y := world.cell_height(Vector2i(0, 0))
	transport.build_segment("route", Vector3(0, y, -160), Vector3(0, y, 140))
	for i in 4:
		bs.place("maison", Vector2i(-12, -150 + i * 16), 1)
	scene.build_panel.set_open(true)
	scene.build_panel.show_category("services")
	await _shot(dir.path_join("admin-construire-paliers.png"))
	scene.build_panel.set_open(false)
	scene.toggle_admin()
	await _shot(dir.path_join("admin-panneau.png"))
	quit(0)
