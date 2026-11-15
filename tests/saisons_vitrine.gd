extends SceneTree
## Vitrine des saisons : village sous la neige, chasse-neige en tournée,
## routes déneigées, crue de la rivière, panneau Saisons et risques.
## Usage (avec affichage) :
##   godot --path . --rendering-driver opengl3 --script res://tests/saisons_vitrine.gd -- --dossier /chemin/captures


func _initialize() -> void:
	_run.call_deferred()


func _flat_tile(_t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(40.0)
	return a


func _shot(path: String) -> void:
	for i in 14:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(path)
	print("capture : ", path)


func _place(bs: BuildingSystem, id: String, x: int, north := true, z := 0) -> int:
	var d := int(BuildingCatalog.get_type(id).d)
	var c := Vector2i(x, (-(d / 2 + 6) if north else d / 2 + 6) + z)
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
	world.view_radius_override = 800.0
	world.set_origin(46.2, 6.9)
	for i in 150:
		await process_frame
	amb.set_speed(0)
	amb.unix_time = Time.get_unix_time_from_datetime_string("2026-12-18T10:30:00")
	bs.unlimited_money = true
	var y := world.cell_height(Vector2i(0, 0))
	transport.build_segment("route", Vector3(-500, y, 0), Vector3(500, y, 0))
	transport.build_segment("rue", Vector3(-120, y, 0), Vector3(-120, y, 260))
	transport.build_segment("rue", Vector3(60, y, 0), Vector3(60, y, -220))
	for i in 12:
		_place(bs, "maison", -300 + i * 14)
	for i in 8:
		_place(bs, "maison", -260 + i * 16, false)
	_place(bs, "immeuble", -40, false)
	_place(bs, "immeuble", -10, false)
	var ct := _place(bs, "centre_technique", 120)
	_place(bs, "station_meteo", 170)
	var sa: Saisons = scene.saisons
	var tf := transport.traffic
	sa.set_process(false)
	scene.production.set_process(false)
	scene.population.set_process(false)
	scene.dechets.set_process(false)
	sa.forcer = 0
	tf.set_enabled(true)
	var w: Meteo = amb.weather
	w.mode = Meteo.Mode.NEIGE
	w.settle(amb.unix_time, 10.5)
	world.neige = 0.95
	sa.clock = amb.unix_time
	sa.neige.clear()
	for eid in sa._routes():
		sa.neige[eid] = 12.0
	sa._rebuild_mesh()
	for i in 200:
		tf.step(0.25)
	var rig: Node3D = scene.get_node("CameraRig")
	rig.position = Vector3(-200, y, 0)
	rig._target_distance = 90.0
	rig.set_pitch(30.0, true)
	rig.rotation_degrees.y = 20.0
	await _shot(dir.path_join("saisons-village-sous-la-neige.png"))

	# Les chasse-neige partent : on avance un peu, on suit le premier.
	sa._dispatch(sa.clock)
	for i in 120:
		tf.step(0.25)
	var p := Vector3(120, y, 0)
	for v in tf.vehicles:
		if int(v.get("delivery", -1)) >= Saisons.TAG:
			p = tf.vehicle_position(v)
			break
	w.mode = Meteo.Mode.NEIGE
	w.settle(amb.unix_time, 10.5)
	rig.position = p
	rig._target_distance = 28.0
	rig.set_pitch(20.0, true)
	rig.rotation_degrees.y = -35.0
	await _shot(dir.path_join("saisons-chasse-neige.png"))
	# Tournées finies : routes déneigées et salées, la neige reste dans les champs.
	for i in 400:
		sa.clock += 120.0
		sa._avance_tournees(sa.clock)
		if sa.missions.is_empty():
			break
	sa._rebuild_mesh()
	w.mode = Meteo.Mode.COUVERT
	w.settle(amb.unix_time, 10.5)
	rig.position = Vector3(120, y, -10)
	rig._target_distance = 70.0
	rig.set_pitch(35.0, true)
	rig.rotation_degrees.y = 0.0
	await _shot(dir.path_join("saisons-centre-technique.png"))

	# Panneau : risques et déneigement.
	scene.saisons_panel.set_open(true)
	scene.saisons_panel.show_view("neige")
	rig.position = Vector3(-60, y, 0)
	rig._target_distance = 160.0
	rig.set_pitch(40.0, true)
	await _shot(dir.path_join("saisons-panneau-deneigement.png"))
	scene.saisons_panel.show_view("meteo")
	await _shot(dir.path_join("saisons-panneau-meteo.png"))
	scene.saisons_panel.show_view("cultures")
	await _shot(dir.path_join("saisons-panneau-cultures.png"))
	scene.saisons_panel.set_open(false)

	# Printemps : la neige fond, la rivière déborde.
	amb.unix_time = Time.get_unix_time_from_datetime_string("2027-03-28T14:00:00")
	sa.clock = amb.unix_time
	world.neige = 0.0
	sa.neige.clear()
	sa.sel.clear()
	sa._rebuild_mesh()
	w.mode = Meteo.Mode.PLUIE
	w.settle(amb.unix_time, 14.0)
	var ev: Evenements = scene.evenements
	var river := [[[-420.0, y, -42.0], [-280.0, y, -40.0], 10.0], [[-280.0, y, -40.0], [-140.0, y, -46.0], 10.0]]
	var eid := ev.ajouter("crue", "Crue", amb.unix_time, amb.unix_time + 8.0 * 3600.0, Vector3(-280, y, -60), -1,
		{"crue": river, "niveau": 0.0, "fin_crue": 0.0, "vigilance": 3, "montee_h": 6.0}, false)
	ev._update_events(amb.unix_time)
	var e: Dictionary = ev.events[eid]
	for i in 60:
		sa._monte(e, amb.unix_time)
	rig.position = Vector3(-250, y, -25)
	rig._target_distance = 120.0
	rig.set_pitch(38.0, true)
	rig.rotation_degrees.y = 15.0
	await _shot(dir.path_join("saisons-crue.png"))
	scene.saisons_panel.set_open(true)
	scene.saisons_panel.show_view("risques")
	await _shot(dir.path_join("saisons-panneau-risques.png"))
	quit()
