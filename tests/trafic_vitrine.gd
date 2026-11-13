extends SceneTree
## Vitrine du trafic : un quartier de tours relié par une rue à une avenue de
## bureaux ; à 8 h le bas de la rue des tours bouchonne. Carte du trafic,
## panneau Trafic (bilan, bouchons, lignes).
## Usage (avec affichage) :
##   godot --path . --rendering-driver opengl3 --script res://tests/trafic_vitrine.gd -- --dossier /chemin/captures


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


func _put(bs: BuildingSystem, id: String, c: Vector2i) -> int:
	var r := bs.best_rotation(id, c)
	var b := bs.place(id, c, r)
	if b < 0:
		print("refus ", id, " ", c, " : ", bs.check_place(id, c, r).reason)
	return b


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
	world.view_radius_override = 1200.0
	world.set_origin(46.2, 6.9)
	for i in 3000:
		await process_frame
		if i >= 120 and world.missing_chunk_count() == 0 and world._dirty.is_empty() and world._jobs.is_empty():
			break
	amb.set_speed(0)
	amb.unix_time = Time.get_unix_time_from_datetime_string("2026-06-09T06:00:00")
	bs.unlimited_money = true
	var pop: Population = scene.population
	var tf: Trafic = scene.trafic
	var y := world.cell_height(Vector2i(0, 0))
	transport.build_segment("avenue", Vector3(-450, y, 0), Vector3(300, y, 0))
	transport.build_segment("avenue", Vector3(300, y, 0), Vector3(1050, y, 0))
	transport.build_segment("rue", Vector3(-300, y, 0), Vector3(-300, y, -820))
	# Une deuxième rue de tours qui rejoint la première : le bas de la rue
	# des tours (vers l'avenue) prend tout le monde et bouchonne.
	transport.build_segment("rue", Vector3(-300, y, -130), Vector3(-200, y, -130))
	transport.build_segment("rue", Vector3(-200, y, -130), Vector3(-200, y, -820))
	for i in 15:
		var z := -60 - i * 50
		_put(bs, "tour_habitation", Vector2i(-317, z))
		_put(bs, "tour_habitation", Vector2i(-283, z))
		if z < -170:
			_put(bs, "tour_habitation", Vector2i(-217, z))
			_put(bs, "tour_habitation", Vector2i(-183, z))
	for i in 5:
		_put(bs, "bureaux", Vector2i(700 + i * 55, -21))
		_put(bs, "bureaux", Vector2i(700 + i * 55, 21))
	pop._sync_buildings()
	var logements := 0
	for bid in pop.known:
		logements += int(pop.known[bid].log)
	for i in 600:
		pop.advance(300.0)
		if pop.households.size() >= logements:
			break
	print("%d habitants, %d foyers / %d logements" % [pop.persons.size(), pop.households.size(), logements])
	var st := transport.stations
	var b1 := st.place("arret_bus", Vector3(-300, y, -520))
	var b2 := st.place("arret_bus", Vector3(880, y, 0))
	if b1.ok and b2.ok:
		st.create_line([b1.id, b2.id], "bus_urbain", 1)
	for i in 6:
		tf.run_cycle()
	print("modes : ", tf.stats.modes, " retard moyen ", tf.stats.avg_delay, " min, pires : ", tf.stats.worst.slice(0, 3))
	tf.set_process(false)
	var tr := transport.traffic
	for i in 1500:
		tr._process(0.1)
	var rig: Node3D = scene.get_node("CameraRig")
	# 1. Carte du trafic vue de haut : le bas de la rue des tours est rouge.
	scene.trafic_overlay.moment = "pointe"
	scene.trafic_overlay.set_shown(true)
	rig.position = Vector3(-120, y, -260)
	rig._target_distance = 700.0
	rig.set_pitch(62.0, true)
	rig.rotation_degrees.y = 0.0
	await _shot(dir.path_join("trafic-carte.png"))
	# 2. Plus près du carrefour avec l'avenue.
	rig.position = Vector3(-280, y, -60)
	rig._target_distance = 200.0
	rig.set_pitch(50.0, true)
	await _shot(dir.path_join("trafic-carte-carrefour.png"))
	# 3. Panneau : bilan puis lignes.
	var panel: TraficPanel = scene.trafic_panel
	panel.set_open(true)
	panel.show_view("bilan")
	await _shot(dir.path_join("trafic-panneau-bilan.png"))
	panel.show_view("lignes")
	await _shot(dir.path_join("trafic-panneau-lignes.png"))
	quit()
