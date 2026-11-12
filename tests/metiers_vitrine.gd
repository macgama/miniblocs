extends SceneTree
## Vitrine des métiers visibles : un quartier (boulangerie, école, hôpital,
## supérette, ferme), puis des captures de la vue en coupe et des employés.
## Usage (avec affichage) :
##   godot --path . --rendering-driver opengl3 --script res://tests/metiers_vitrine.gd -- --dossier /chemin/captures


func _initialize() -> void:
	_run.call_deferred()


func _flat_tile(_t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(40.0)
	return a


func _shot(path: String) -> void:
	for i in 20:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(path)
	print("capture : ", path)


func _vise(rig: Node3D, mv: MetiersVivants, pos: Vector3, dist: float, pitch: float, yaw: float) -> void:
	rig.position = Vector3(pos.x, pos.y, pos.z)
	rig.set("_distance", dist)
	rig.set("_target_distance", dist)
	rig.rotation.y = deg_to_rad(yaw)
	rig.call("set_pitch", pitch, true)
	for i in 4:
		await process_frame
	mv.refresh()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var dir := "."
	for i in args.size() - 1:
		if args[i] == "--dossier":
			dir = args[i + 1]
	root.size = Vector2i(1600, 900)
	Creations.persist = false
	BatimentsVie.chantiers = false
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
	amb.unix_time = Time.get_unix_time_from_datetime_string("2026-03-10T09:00:00") # mardi 10 h à Paris
	bs.unlimited_money = true
	var y := world.cell_height(Vector2i(0, 0))
	transport.build_segment("departementale", Vector3(0, y, -300), Vector3(0, y, 300))
	var school := bs.place("ecole", Vector2i(-30, 0), 1)
	var bakery := bs.place("boulangerie", Vector2i(-16, -95), 1)
	var shop := bs.place("superette", Vector2i(-14, -60), 1)
	var hospital := bs.place("hopital", Vector2i(30, 40), 3)
	var farm := bs.place("ferme", Vector2i(-24, 140), 1)
	for i in 8:
		bs.place("immeuble", Vector2i(16, -180 + i * 22), 3)
	for i in 4:
		bs.place("maison", Vector2i(-12, -170 + i * 16), 1)
	var pop: Population = scene.population
	pop._sync_buildings()
	for i in 72:
		pop.advance(300.0)
	pop._now = {}
	var rig: Node3D = scene.get_node("CameraRig")
	pop.follow_camera = false
	rig.position.y = y
	var mv: MetiersVivants = scene.metiers_vivants
	var only := ""
	for i in args.size() - 1:
		if args[i] == "--seulement":
			only = args[i + 1]
	if only == "" or only == "boulangerie":
		await _vise(rig, mv, pop.known[bakery].pos, 11.0, 45.0, 30.0)
		await _shot(dir.path_join("metiers-boulangerie.png"))
	if only == "" or only == "ecole":
		await _vise(rig, mv, pop.known[school].pos, 30.0, 60.0, 20.0)
		await _shot(dir.path_join("metiers-ecole.png"))
	if only == "" or only == "hopital":
		await _vise(rig, mv, pop.known[hospital].pos, 32.0, 60.0, -20.0)
		await _shot(dir.path_join("metiers-hopital.png"))
	if only == "" or only == "ferme":
		await _vise(rig, mv, pop.known[farm].pos, 60.0, 50.0, 200.0)
		await _shot(dir.path_join("metiers-ferme.png"))
	if only == "" or only == "superette":
		amb.unix_time = Time.get_unix_time_from_datetime_string("2026-03-11T02:00:00")
		pop._now = {}
		await _vise(rig, mv, pop.known[shop].pos, 30.0, 40.0, 90.0)
		await _shot(dir.path_join("metiers-ferme-la-nuit.png"))
	quit()
