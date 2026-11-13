extends SceneTree
## Vitrine des services publics : un centre avec école, hôpital et commissariat,
## un hameau sans liaison routière ; calques de couverture et panneau (Maj+U).
## Usage (avec affichage) :
##   godot --path . --rendering-driver opengl3 --script res://tests/services_vitrine.gd -- --dossier /chemin/captures


func _initialize() -> void:
	_run.call_deferred()


func _shot(path: String) -> void:
	for i in 12:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(path)
	print("capture : ", path)


func _flat_tile(_t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(40.0)
	return a


func _place(bs: BuildingSystem, id: String, z: int) -> int:
	var d := int(BuildingCatalog.get_type(id).d)
	for dx in [d / 2 + 6, d / 2 + 4, int(BuildingCatalog.get_type(id).w) / 2 + 6]:
		var c := Vector2i(-dx, z)
		var r := bs.best_rotation(id, c)
		var bid := bs.place(id, c, r)
		if bid > 0:
			return bid
		print("    ", id, " : ", bs.check_place(id, c, r).reason)
	return -1


func _at(date: String, hour: float) -> float:
	return Time.get_unix_time_from_datetime_string(date + "T00:00:00") + (hour - 1.0) * 3600.0


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
	var rig: Node3D = scene.get_node("CameraRig")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.view_radius_override = 1200.0
	world.set_origin(48.8584, 2.2945)
	for i in 3000:
		await process_frame
		if i >= 120 and world.missing_chunk_count() == 0 and world._dirty.is_empty() and world._jobs.is_empty():
			break
	var pop: Population = scene.population
	var sp: ServicesPublics = scene.services
	sp.delits_actifs = false
	scene.urgences.random_calls = false
	amb.set_speed(0)
	amb.unix_time = _at("2026-06-10", 11.0)
	bs.unlimited_money = true
	var y := world.cell_height(Vector2i(0, 0))
	transport.build_segment("departementale", Vector3(0, y, -300), Vector3(0, y, 300))
	transport.build_segment("route", Vector3(300, y, -300), Vector3(300, y, 300))
	bs.place("ecole", Vector2i(-30, 0), 1)
	_place(bs, "hopital", -150)
	_place(bs, "police", 150)
	for i in 8:
		bs.place("immeuble", Vector2i(16, -200 + i * 22), 3)
	bs.place("bureaux", Vector2i(20, 200), 3)
	for i in 8:
		bs.place("maison", Vector2i(312, -120 + i * 16), 3)
	pop._sync_buildings()
	for i in 96:
		pop.advance(300.0)
	sp.rebuild()
	pop.follow(-1)
	pop.follow_camera = false
	rig.position = Vector3(215, y, 0)
	rig._target_distance = 380.0
	rig.set_pitch(62.0, true)
	rig.rotation_degrees.y = 0.0
	scene.services_panel.set_open(true)
	scene.services_panel.show_view("ecole")
	Calques.afficher("services_ecole")
	await _shot(dir.path_join("services-ecole.png"))
	scene.services_panel.show_view("police")
	Calques.afficher("services_police")
	await _shot(dir.path_join("services-police.png"))
	transport.build_segment("route", Vector3(0, y, 300), Vector3(300, y, 300))
	await process_frame
	pop._match_all()
	sp.rebuild()
	scene.services_panel.show_view("hopital")
	Calques.afficher("services_hopital")
	await _shot(dir.path_join("services-hopital-relie.png"))
	quit()
