extends SceneTree
## Vitrine de l'économie locale : une petite ville, ses fermes et usines, et
## les camions de livraison sur la route ; le panneau Production (camions, sites).
## Usage (avec affichage) :
##   godot --path . --rendering-driver opengl3 --script res://tests/economie_vitrine.gd -- --dossier /chemin/captures


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
	world.land.offline_generator = func(_lat: float, lon: float) -> int: return 10 if lon < 6.7485 else 40
	world.view_radius_override = 700.0
	world.set_origin(49.15, 6.75)
	for i in 400:
		await process_frame
		if i > 120 and world.missing_chunk_count() == 0:
			break
	amb.set_speed(0)
	amb.unix_time = Time.get_unix_time_from_datetime_string("2026-06-09T09:00:00")
	bs.unlimited_money = true
	var y := world.cell_height(Vector2i(0, 0))
	transport.build_segment("route", Vector3(-420, y, 0), Vector3(420, y, 0))
	_place(bs, "exploitation_forestiere", -330)
	_place(bs, "scierie", -270)
	_place(bs, "ferme_cereales", 300)
	_place(bs, "ferme_maraichere", 240)
	_place(bs, "moulin", 190)
	_place(bs, "fournil", 150)
	_place(bs, "transporteur", 90)
	_place(bs, "superette", 20, false)
	_place(bs, "boulangerie", 50, false)
	_place(bs, "station_service", 80, false)
	_place(bs, "pharmacie", -10, false)
	for i in 6:
		_place(bs, "immeuble", -230 + i * 30, false)
	transport.stations.place("depot", Vector3(400, 0, 6))
	var pop: Population = scene.population
	var prod: Production = scene.production
	pop._sync_buildings()
	for i in 96:
		pop.advance(300.0)
	prod.clock = -1.0
	prod.last_day = prod._day_of(amb.unix_time)
	# Premier matin : les chauffeurs prennent leur service, les rayons sont vides,
	# les tournées partent de partout.
	for k in 40:
		amb.unix_time += Production.LOG_STEP
		prod.advance(Production.LOG_STEP)
		if k >= 3 and prod.missions.size() >= 2:
			break
	for i in 600:
		await process_frame
		if i > 300:
			break
	print("camions sur la route : ", transport.traffic.delivery_count(), " · livraisons : ", prod.missions.size())
	var rig: Node3D = scene.get_node("CameraRig")
	var target := Vector3(60, y, 0)
	for v in transport.traffic.vehicles:
		if v.has("delivery") and v.has("body"):
			target = (v.body as Node3D).global_position
			break
	rig.position = target
	rig._target_distance = 70.0
	rig.rotation_degrees.y = 30.0
	await _shot(dir.path_join("apercu-economie-camion.png"))
	rig.position = Vector3(30, y, 0)
	rig._target_distance = 300.0
	scene.production_panel.set_open(true)
	scene.production_panel.show_view("camions")
	await _shot(dir.path_join("apercu-economie-camions.png"))
	scene.production_panel.show_view("sites")
	await _shot(dir.path_join("apercu-economie-sites.png"))
	quit()
