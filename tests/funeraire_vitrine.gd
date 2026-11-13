extends SceneTree
## Vitrine funéraire : les cimetières du catalogue côte à côte, un cimetière
## communal qui se remplit (tombes fleuries récentes), une mise en terre (les
## proches autour de la fosse), le corbillard et le cortège sur la route,
## l'onglet Funéraire du panneau Habitants.
## Usage (avec affichage) :
##   godot --path . --rendering-driver opengl3 --script res://tests/funeraire_vitrine.gd -- --dossier /chemin/captures


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
	ReglagesPartie.actuel.construction_instantanee = true
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
	amb.unix_time = Time.get_unix_time_from_datetime_string("2026-05-12T09:30:00")
	bs.unlimited_money = true
	var y := world.cell_height(Vector2i(0, 0))
	transport.build_segment("route", Vector3(-700, y, 0), Vector3(700, y, 0))
	var homes: Array[int] = []
	for i in 10:
		homes.append(_place(bs, "maison", -560 + i * 14))
	var pop: Population = scene.population
	pop._sync_buildings()
	for bid in homes:
		pop.spawn_household(bid, "famille")
	var fun: Funeraire = scene.funeraire
	var tf := transport.traffic
	for n in [fun, scene.production, pop, tf, scene.dechets]:
		n.set_process(false)
	fun.ignore_crew = true
	fun.ignore_hours = true

	# Le catalogue, le long de la route.
	var com := _place(bs, "cimetiere_communal", 0)
	var vil := _place(bs, "cimetiere_village", -110)
	var mil := _place(bs, "cimetiere_militaire", 120)
	_place(bs, "cimetiere_asie", 210)
	_place(bs, "cimetiere_musulman", 280)
	_place(bs, "cimetiere_juif", 340)
	var pf := _place(bs, "pompes_funebres", -300, false)
	_place(bs, "crematorium", -60, false)
	var col := _place(bs, "columbarium", 0, false)
	_place(bs, "cimetiere_paysager", 180, false)
	pop._sync_buildings()
	fun._sync()
	fun.clock = amb.unix_time
	fun.last_day = int(fun._now(fun.clock).day)
	# Remplir : 45 % du communal (les plus récentes fleuries), le village presque plein.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var noms := ["Martin", "Bernard", "Dubois", "Thomas", "Robert", "Richard", "Petit", "Durand", "Leroy", "Moreau"]
	var n := 0
	for bid in fun.sites:
		if not String(fun.sites[bid].role) in ["cimetiere", "columbarium"]:
			continue
		var share := 0.45 if bid == com else (0.85 if bid == vil else (0.6 if bid == mil else 0.35))
		for i in fun.capacity(bid):
			if rng.randf() < share:
				n += 1
				fun._bury(700000 + n, "%s" % noms[n % noms.size()], int(bid), i)
				fun.sites[bid].tombes[i].t = fun.clock - (86400.0 * 400.0 if rng.randf() < 0.9 else 86400.0 * 5.0)
	fun.step(900.0)

	var rig: Node3D = scene.get_node("CameraRig")
	rig.position = Vector3(110, y, -60)
	rig._target_distance = 330.0
	rig.set_pitch(42.0, true)
	rig.rotation_degrees.y = 0.0
	await _shot(dir.path_join("funeraire-catalogue.png"))
	rig.position = Vector3(0, y, -55)
	rig._target_distance = 95.0
	rig.set_pitch(38.0, true)
	rig.rotation_degrees.y = 15.0
	await _shot(dir.path_join("funeraire-cimetiere-communal.png"))
	rig.position = Vector3(-110, y, -25)
	rig._target_distance = 40.0
	rig.set_pitch(30.0, true)
	rig.rotation_degrees.y = -25.0
	await _shot(dir.path_join("funeraire-cimetiere-village.png"))

	# Un décès : convoi et mise en terre au cimetière communal.
	ReglagesPartie.actuel.cremation = 0.0
	var a := -1
	for pid in pop.persons:
		if int(pop.persons[pid].get("cj", -1)) >= 0 and not pop.vie.children_of(int(pid)).is_empty():
			a = int(pid)
			break
	if a < 0:
		a = int(pop.persons.keys()[0])
	pop.vie.die(a, "de vieillesse")
	var o: Dictionary = fun.obseques[a]
	o.dest = com
	o.slot = fun._free_slot(com)
	o.t_prevu = fun.clock
	fun.step(900.0)
	# Le corbillard en route.
	for i in 90:
		tf.step(0.25)
	var p := Vector3(-300, y, 0)
	for v in tf.vehicles:
		if int(v.get("delivery", -1)) >= Funeraire.TAG:
			p = tf.vehicle_position(v)
			break
	rig.position = p
	rig._target_distance = 22.0
	rig.set_pitch(20.0, true)
	rig.rotation_degrees.y = -35.0
	await _shot(dir.path_join("funeraire-corbillard.png"))
	o.etat = "ceremonie"
	o.t_fin = fun.clock + 3600.0
	fun._update_ceremonies()
	var g := fun.slot_world(com, int(o.slot)).origin
	rig.position = g
	rig._target_distance = 14.0
	rig.set_pitch(28.0, true)
	rig.rotation_degrees.y = 160.0
	for i in 20:
		fun._cer_t += 0.1
		fun._update_ceremonies()
		await process_frame
	await _shot(dir.path_join("funeraire-mise-en-terre.png"))
	fun.clock += 3700.0
	fun.step(900.0)
	fun._update_ceremonies()
	rig._target_distance = 12.0
	await _shot(dir.path_join("funeraire-tombe-fleurie.png"))

	# Columbarium et onglet Funéraire.
	rig.position = fun._pos_of(col)
	rig._target_distance = 32.0
	rig.set_pitch(30.0, true)
	rig.rotation_degrees.y = 180.0
	await _shot(dir.path_join("funeraire-columbarium.png"))
	var panel: HabitantsPanel = scene.habitants_panel
	panel.set_open(true)
	panel.show_view("funeraire")
	rig.position = Vector3(0, y, -40)
	rig._target_distance = 120.0
	rig.set_pitch(40.0, true)
	rig.rotation_degrees.y = 0.0
	await _shot(dir.path_join("funeraire-panneau.png"))
	panel.show_view("profil", a)
	await _shot(dir.path_join("funeraire-fiche-defunt.png"))
	rig.position = fun._pos_of(pf)
	rig._target_distance = 30.0
	rig.set_pitch(25.0, true)
	rig.rotation_degrees.y = 200.0
	panel.set_open(false)
	await _shot(dir.path_join("funeraire-pompes-funebres.png"))
	quit()
