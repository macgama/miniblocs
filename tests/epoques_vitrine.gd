extends SceneTree
## Vitrine des époques : une rue de 1800 (maison d'école, Hôtel-Dieu, remise des
## pompes, maisons à colombages, charrettes), le catalogue des services en 1800
## et le panneau Admin. Usage (avec affichage) :
##   godot --path . --rendering-driver opengl3 --script res://tests/epoques_vitrine.gd -- --dossier /chemin/captures


func _initialize() -> void:
	_run.call_deferred()


func _flat_tile(_t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(40.0)
	return a


func _shot(path: String) -> void:
	for i in 8:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(path)
	print("capture : ", path)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var dir := "."
	for i in args.size() - 1:
		if args[i] == "--dossier":
			dir = args[i + 1]
	root.size = Vector2i(1600, 900)
	Creations.persist = false
	BatimentsVie.chantiers = false
	var pre := ReglagesPartie.preset("libre")
	pre.annee_depart = 1800
	pre.tutoriel = false
	ReglagesPartie.prochaine = pre
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
	amb.unix_time = Time.get_unix_time_from_datetime_string("2026-06-10T09:00:00")
	var y := world.cell_height(Vector2i(0, 0))
	transport.build_segment("rue", Vector3(0, y, -120), Vector3(0, y, 120))
	transport.build_segment("rue", Vector3(-120, y, 0), Vector3(120, y, 0))
	var gauche := ["ecole_communale", "colombages__maison", "colombages__rangee", "colombages__maison", "colombages__boutique"]
	var droite := ["hotel_dieu", "remise_pompes", "brigade_gendarmerie"]
	var z := -100
	for id in gauche:
		var t := BuildingCatalog.get_type(id)
		var c := Vector2i(-6 - int(t.d) / 2, z + int(t.w) / 2)
		var bid := bs.place(id, c, 1)
		print(id, " -> ", bid, " ", bs.check_place(id, c, 1).get("reason", "") if bid < 0 else "")
		z += int(t.w) + 3
	z = -100
	for id in droite:
		var t := BuildingCatalog.get_type(id)
		var c := Vector2i(6 + int(t.d) / 2, z + int(t.w) / 2)
		var bid := bs.place(id, c, 3)
		print(id, " -> ", bid, " ", bs.check_place(id, c, 3).get("reason", "") if bid < 0 else "")
		z += int(t.w) + 4
	for i in 40:
		var tr: Traffic = transport.traffic
		if tr != null and tr.has_method("spawn_one"):
			tr.spawn_one()
	for i in 200:
		await process_frame
	var rig: Node3D = scene.get_node("CameraRig")
	rig.position = Vector3(0, y, -40)
	rig._target_distance = 90.0
	rig.set_pitch(40.0, true)
	for i in 30:
		await process_frame
	print("année : ", Epoques.annee(), " · ", scene.hud.get_node_or_null("Horloge"))
	await _shot(dir.path_join("epoques-rue-1800.png"))
	scene.build_panel.set_open(true)
	scene.build_panel.show_category("services")
	await _shot(dir.path_join("epoques-catalogue-1800.png"))
	scene.build_panel.set_open(false)
	scene.toggle_admin()
	await _shot(dir.path_join("epoques-admin.png"))
	quit(0)
