extends SceneTree
## Vitrine du compte des lignes : un quartier de tours, des bureaux, une ligne
## de bus (vieux bus), un tramway et une ligne de camions entre deux dépôts ;
## panneau Lignes (L) avec le bilan détaillé de chaque ligne.
## Usage (avec affichage) :
##   godot --path . --rendering-driver opengl3 --script res://tests/lignes_eco_vitrine.gd -- --dossier /chemin/captures


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
	for i in 6:
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
	for i in 150:
		pop.advance(300.0)
		if pop.households.size() >= logements:
			break
	print("%d habitants, %d foyers / %d logements" % [pop.persons.size(), pop.households.size(), logements])
	var st := transport.stations
	var eco: ExploitationLignes = scene.lignes_eco
	eco.set_process(false)
	var b1 := st.place("arret_bus", Vector3(-300, y, -520))
	var b2 := st.place("arret_bus", Vector3(880, y, 0))
	var bus := st.create_line([b1.id, b2.id], "bus_urbain", 3)
	transport.build_segment("tram", Vector3(-600, y, 60), Vector3(1000, y, 60))
	var t1 := st.place("arret_tram", Vector3(-500, y, 60))
	var t2 := st.place("arret_tram", Vector3(900, y, 60))
	print("tram : ", t1.get("reason", "ok"), " ", t2.get("reason", "ok"))
	var tram := st.create_line([t1.get("id", -1), t2.get("id", -1)], "tram_moderne", 2)
	var d1 := st.place("depot", Vector3(-420, y, 0))
	var d2 := st.place("depot", Vector3(1000, y, 0))
	print("dépôts : ", d1.get("reason", "ok"), " ", d2.get("reason", "ok"))
	var fret := st.create_line([d1.get("id", -1), d2.get("id", -1)], "semi", 2)
	print("lignes : ", bus.get("reason", "ok"), " ", tram.get("reason", "ok"), " ", fret.get("reason", "ok"))
	for i in 6:
		tf.run_cycle()
	tf.set_process(false)
	# Les bus ont 13 ans : l'un a passé sa durée de vie.
	if bus.ok:
		eco.flottes[int(bus.id)].ages = [4900.0, 4300.0, 1200.0]
	var prod: Production = scene.production
	for d in 12:
		prod.yesterday = Production._empty_flows()
		prod.yesterday.export = {"bois": 240.0}
		if fret.ok:
			st.lines[int(fret.id)].tonnes = float(st.lines[int(fret.id)].tonnes) + 180.0
		eco.new_day()
	var tr := transport.traffic
	for i in 900:
		tr._process(0.1)
	var rig: Node3D = scene.get_node("CameraRig")
	rig.position = Vector3(100, y, -250)
	rig._target_distance = 900.0
	rig.set_pitch(55.0, true)
	rig.rotation_degrees.y = 0.0
	var panel: StationPanel = scene.transit_panel
	panel.set_open(true)
	if bus.ok:
		panel._open[int(bus.id)] = true
		panel._focus = int(bus.id)
	panel._refresh_lines()
	await _shot(dir.path_join("lignes-bilan-bus.png"))
	panel._open.clear()
	if tram.ok:
		panel._open[int(tram.id)] = true
	if fret.ok:
		panel._open[int(fret.id)] = true
		panel._focus = int(fret.id)
	panel._refresh_lines()
	await _shot(dir.path_join("lignes-bilan-tram-fret.png"))
	quit()
