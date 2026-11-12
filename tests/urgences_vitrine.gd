extends SceneTree
## Vitrine des urgences : avenue avec carrefour à feux, circulation, caserne,
## commissariat et hôpital ; un accident, les secours en route (gyrophares,
## voitures rangées), puis la carte de couverture et le panneau Urgences.
## Usage (avec affichage) :
##   godot --path . --rendering-driver opengl3 --script res://tests/urgences_vitrine.gd -- --dossier /chemin/captures


func _initialize() -> void:
	_run.call_deferred()


func _flat_tile(_t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(40.0)
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
	BatimentsVie.chantiers = false
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var transport: TransportSystem = scene.get_node("Transport")
	var bs: BuildingSystem = scene.get_node("Batiments")
	var amb: DayNight = scene.get_node("Ambiance")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 40
	world.view_radius_override = 700.0
	world.set_origin(46.2, 6.9)
	for i in 150:
		await process_frame
	amb.set_speed(0)
	amb.unix_time = Time.get_unix_time_from_datetime_string("2026-06-10T08:00:00")
	bs.unlimited_money = true
	var y := world.cell_height(Vector2i(0, 0))
	transport.build_segment("departementale", Vector3(-500, y, 0), Vector3(500, y, 0))
	transport.build_segment("departementale", Vector3(60, y, -300), Vector3(60, y, 300))
	_place(bs, "pompiers", -330)
	_place(bs, "police", -200, false)
	_place(bs, "hopital", 300, false)
	for x in [-260, -120, 150, 220]:
		_place(bs, "maison", x)
	var urg: Urgences = scene.urgences
	urg.ignore_crew = true
	urg.random_calls = false
	urg._sync_stations()
	var tf := transport.traffic
	for i in 40:
		tf.spawn(TransportTypes.Mode.ROAD)
	for i in 300:
		tf.step(0.1)
	urg.declare("accident", "Accident de la route", Vector3(150, y, 4), ["pompiers", "ambulance", "police"], 2)
	# On suit le fourgon des pompiers jusqu'au carrefour.
	var fpt: Dictionary = {}
	for u in urg.stations.values()[0].units:
		if u.out and String(u.model) == "fpt":
			fpt = u.v
	for i in 90:
		tf.step(0.1)
		urg.step(0.1)
	var rig: Node3D = scene.get_node("CameraRig")
	var p := tf.vehicle_position(fpt) if not fpt.is_empty() else Vector3(-150, y, 0)
	rig.position = p
	rig._target_distance = 55.0
	rig.set_pitch(28.0, true)
	rig.rotation_degrees.y = -35.0
	await _shot(dir.path_join("urgences-en-route.png"))
	for i in 400:
		tf.step(0.1)
		urg.step(0.1)
	rig.position = Vector3(150, y, 4)
	rig._target_distance = 70.0
	rig.rotation_degrees.y = 20.0
	await _shot(dir.path_join("urgences-sur-place.png"))
	urg.set_coverage("pompiers")
	scene.urgences_panel.set_open(true)
	scene.urgences_panel.show_view("bilan")
	rig.position = Vector3(0, y, 0)
	rig._target_distance = 520.0
	rig.set_pitch(55.0, true)
	await _shot(dir.path_join("urgences-couverture.png"))
	urg.set_coverage("")
	scene.urgences_panel.show_view("appels")
	await _shot(dir.path_join("urgences-panneau.png"))
	quit()
