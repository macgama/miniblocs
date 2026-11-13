extends SceneTree
## Vitrine des déchets : rue de maisons dont les poubelles débordent, dépôt de
## collecte, benne en tournée, installations (décharge, centre de tri,
## incinérateur, déchèterie, compost), décharge recouverte et panneau Déchets.
## Usage (avec affichage) :
##   godot --path . --rendering-driver opengl3 --script res://tests/dechets_vitrine.gd -- --dossier /chemin/captures


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
	world.view_radius_override = 800.0
	world.set_origin(46.2, 6.9)
	for i in 150:
		await process_frame
	amb.set_speed(0)
	amb.unix_time = Time.get_unix_time_from_datetime_string("2026-06-10T08:00:00")
	bs.unlimited_money = true
	var y := world.cell_height(Vector2i(0, 0))
	transport.build_segment("route", Vector3(-600, y, 0), Vector3(600, y, 0))
	var homes: Array[int] = []
	for i in 10:
		homes.append(_place(bs, "maison", -260 + i * 14))
	var imm := _place(bs, "immeuble", -200, false)
	var imm2 := _place(bs, "immeuble", -175, false)
	var pop: Population = scene.population
	pop._sync_buildings()
	for bid in homes:
		pop.spawn_household(bid, "famille")
	for b in [imm, imm2]:
		for i in 12:
			pop.spawn_household(b)
	var dec: Dechets = scene.dechets
	var tf := transport.traffic
	dec.set_process(false)
	scene.production.set_process(false)
	pop.set_process(false)
	tf.set_process(false)
	dec.ignore_crew = true
	dec.ignore_hours = true
	dec._sync()
	dec.clock = amb.unix_time
	dec.last_day = int(dec._now(dec.clock).day)
	var t := func(hours: float, tf_dt := 0.0) -> void:
		for i in int(hours * 4.0):
			dec.clock += 900.0
			dec.step(900.0)
			if tf_dt > 0.0:
				for k in 4:
					tf.step(tf_dt / 4.0)
	t.call(24.0 * 8.0)
	var rig: Node3D = scene.get_node("CameraRig")
	rig.position = Vector3(-215, y, -6)
	rig._target_distance = 32.0
	rig.set_pitch(32.0, true)
	rig.rotation_degrees.y = 0.0
	await _shot(dir.path_join("dechets-poubelles-debordent.png"))

	# Installations le long de la route.
	var dep := _place(bs, "depot_collecte", -40)
	_place(bs, "decheterie", 20)
	_place(bs, "centre_tri", 40, false)
	_place(bs, "usine_recyclage", 100, false)
	_place(bs, "compost", 75)
	var dch := _place(bs, "decharge", 230, false)
	_place(bs, "usine_incineration", 400, false)
	var old := _place(bs, "decharge", 400)
	scene.production._dirty = true
	dec._sync()
	dec._bury(old, 200_000.0)
	dec.recouvrir(old)
	dec._bury(dch, 30_000.0)
	t.call(0.25)
	for i in 60:
		tf.step(0.25)
	# Suivre la benne.
	var p := Vector3(-60, y, 0)
	for v in tf.vehicles:
		if int(v.get("delivery", -1)) >= Dechets.TAG:
			p = tf.vehicle_position(v)
	rig.position = p
	rig._target_distance = 32.0
	rig.set_pitch(22.0, true)
	rig.rotation_degrees.y = -40.0
	await _shot(dir.path_join("dechets-benne-tournee.png"))
	rig.position = Vector3(10, y, 0)
	rig._target_distance = 150.0
	rig.set_pitch(40.0, true)
	rig.rotation_degrees.y = 10.0
	await _shot(dir.path_join("dechets-installations.png"))
	rig.position = Vector3(320, y, 20)
	rig._target_distance = 260.0
	rig.set_pitch(38.0, true)
	rig.rotation_degrees.y = 0.0
	await _shot(dir.path_join("dechets-decharge-incinerateur.png"))
	t.call(24.0 * 3.0)
	scene.dechets_panel.set_open(true)
	scene.dechets_panel.show_view("ville")
	rig.position = Vector3(-150, y, 0)
	rig._target_distance = 120.0
	await _shot(dir.path_join("dechets-panneau.png"))
	scene.dechets_panel.show_view("sites")
	await _shot(dir.path_join("dechets-panneau-installations.png"))
	quit()
