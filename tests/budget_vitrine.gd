extends SceneTree
## Vitrine du budget communal : route usée avec nids-de-poule, carte de l'état
## des voies et panneau Budget (bilan, emprunts, entretien).
## Usage (avec affichage) :
##   godot --path . --rendering-driver opengl3 --script res://tests/budget_vitrine.gd -- --dossier /chemin/captures


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
	amb.unix_time = Time.get_unix_time_from_datetime_string("2026-06-10T16:00:00")
	ReglagesPartie.actuel.construction_instantanee = false
	var y := world.cell_height(Vector2i(0, 0))
	transport.build_segment("departementale", Vector3(-400, y, 0), Vector3(400, y, 0))
	transport.build_segment("departementale", Vector3(60, y, -300), Vector3(60, y, 300))
	transport.build_segment("train", Vector3(-400, y, 120), Vector3(400, y, 120))
	for x in [-300, -220, -140, 140, 220, 300]:
		_place(bs, "maison", x)
	_place(bs, "mairie", -60, false)
	var b: BudgetCommunal = scene.budget
	var net := transport.network
	# Usure variée : l'avenue est-ouest très abîmée, la nord-sud correcte.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for eid in net.edges:
		var e: Dictionary = net.edges[eid]
		var mid := net.point_at(eid, float(e.len) * 0.5)
		var u := 0.85
		if BudgetCommunal.voie_of(String(e.t)) == "route":
			u = 0.18 if absf(mid.z) < 5.0 else 0.62
			if mid.x > 200.0:
				u = 0.0
		b.set_etat(eid, u + rng.randf_range(-0.05, 0.05) if u > 0.0 else 0.0)
	for k in BudgetCommunal.VOIES:
		b.set_entretien(k, "auto", false)
	b.emprunter(5_000_000, 20)
	b.set_taux("foncier", 1.2)
	for i in 12:
		b.pay_day()
	b.vue.flush()
	var tf := transport.traffic
	for i in 30:
		tf.spawn(TransportTypes.Mode.ROAD)
	for i in 300:
		tf.step(0.1)
	var rig: Node3D = scene.get_node("CameraRig")
	rig.position = Vector3(-110, y, 0)
	rig._target_distance = 38.0
	rig.set_pitch(32.0, true)
	rig.rotation_degrees.y = -25.0
	await _shot(dir.path_join("budget-nids-de-poule.png"))
	b.vue.set_carte(true)
	b.vue.flush()
	scene.budget_panel.set_open(true)
	scene.budget_panel.show_view("entretien")
	rig.position = Vector3(0, y, 40)
	rig._target_distance = 620.0
	rig.set_pitch(60.0, true)
	rig.rotation_degrees.y = 0.0
	await _shot(dir.path_join("budget-carte-etat.png"))
	b.vue.set_carte(false)
	scene.budget_panel.show_view("bilan")
	rig._target_distance = 160.0
	rig.set_pitch(40.0, true)
	await _shot(dir.path_join("budget-bilan.png"))
	scene.budget_panel.show_view("emprunts")
	await _shot(dir.path_join("budget-emprunts.png"))
	scene.budget_panel.show_view("impots")
	await _shot(dir.path_join("budget-impots.png"))
	quit()
