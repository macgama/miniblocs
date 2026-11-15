extends SceneTree
## Vitrine du tourisme : les hébergements et services, une rue d'hôtels avec ses
## touristes, le menu Tourisme.
## Usage (avec affichage) :
##   godot --path . --script res://tests/tourisme_vitrine.gd -- --screenshot t.png --vue batiments|plein_air|rue|panneau|hebergements


func _initialize() -> void:
	_run.call_deferred()


func _flat_tile(_t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(40.0)
	return a


func _at(date: String, hour: float) -> float:
	return Time.get_unix_time_from_datetime_string(date + "T00:00:00") + (hour - 2.0) * 3600.0


func _cam(rig: Node3D, p: Vector3, dist: float, yaw: float, pitch: float) -> void:
	rig.position = p
	rig.set("_distance", dist)
	rig.set("_target_distance", dist)
	rig.rotation_degrees.y = yaw
	if "pitch_degrees" in rig:
		rig.set("pitch_degrees", pitch)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var shot := "tourisme.png"
	var vue := "batiments"
	for i in args.size():
		if args[i] == "--screenshot" and i + 1 < args.size():
			shot = args[i + 1]
		if args[i] == "--vue" and i + 1 < args.size():
			vue = args[i + 1]
	root.msaa_3d = Viewport.MSAA_DISABLED
	root.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	Creations.persist = false
	BatimentsVie.chantiers = false
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var bs: BuildingSystem = scene.get_node("Batiments")
	var amb: DayNight = scene.get_node("Ambiance")
	var transport: TransportSystem = scene.get_node("Transport")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.set_origin(46.2, 6.9)
	for i in 90:
		await process_frame
	bs.unlimited_money = true
	amb.set_speed(0)
	amb.unix_time = _at("2026-07-17", 11.0)
	if amb.weather != null:
		amb.weather.set_process(false)
		amb.weather.precip = 0.0
		amb.weather.fog = 0.0
	var tour: Tourisme = scene.tourisme
	tour.ignore_staff = true
	tour.set_process(false)
	var rig: Node3D = scene.get_node("CameraRig")
	var y := world.cell_height(Vector2i(0, 0))
	transport.build_segment("route", Vector3(-330, y, 0), Vector3(330, y, 0))
	transport.build_segment("route", Vector3(-330, y, 150), Vector3(330, y, 150))
	var poser := func(id: String, c: Vector2i) -> int:
		var sn := bs.road_snap(id, c)
		if sn.is_empty():
			return bs.place(id, c, 0)
		return bs.place(id, sn.center, int(sn.r), 0, float(sn.get("a", 0.0)))
	var bids := {}
	# Rue des hôtels (au sud de la première avenue), services en face.
	var x := -300.0
	for id in ["gite_rural", "chambres_hotes", "auberge_jeunesse", "hotel_2", "hotel_3", "hotel_4", "palace", "residence_tourisme"]:
		var t := BuildingCatalog.get_type(String(id))
		x += float(t.w) / 2.0 + 5.0
		bids[id] = poser.call(String(id), Vector2i(int(x), -int(float(t.d) / 2.0) - 8))
		x += float(t.w) / 2.0
	x = -200.0
	for id in ["office_tourisme", "boutique_souvenirs_ville", "cafe", "boutique_souvenirs_ville", "parking_autocars", "musee", "superette"]:
		var t := BuildingCatalog.get_type(String(id))
		x += float(t.w) / 2.0 + 6.0
		bids[id + str(x)] = poser.call(String(id), Vector2i(int(x), int(float(t.d) / 2.0) + 8))
		x += float(t.w) / 2.0
	# Plein air au nord de la seconde avenue.
	x = -300.0
	for id in ["aire_camping_cars", "camping", "camping_club", "village_vacances"]:
		var t := BuildingCatalog.get_type(String(id))
		x += float(t.w) / 2.0 + 8.0
		bids[id] = poser.call(String(id), Vector2i(int(x), 150 + int(float(t.d) / 2.0) + 8))
		x += float(t.w) / 2.0
	tour._sync()
	scene.musee._dirty = true
	scene.musee.list()
	# Quelques jours d'été : les hôtels se remplissent.
	tour.clock = amb.unix_time - 86400.0 * 5
	tour.last_day = int(tour._now(tour.clock).day)
	for i in 5:
		var t := amb.unix_time - 86400.0 * (4 - i)
		tour.clock = t
		tour.last_day = int(tour._now(t).day)
		tour.new_day(tour._now(t))
	# Assez de monde pour la photo.
	for bid in tour.heb:
		var l := tour.lits(int(bid))
		tour.heb[bid].clients = [[int(l * 0.8), 2, 3.8]]
	match vue:
		"batiments":
			_cam(rig, Vector3(-120, 30, -20), 150.0, 0.0, 45.0)
		"rue":
			var c := tour.pos_of(int(bids.get("hotel_4", -1)))
			_cam(rig, Vector3(c.x - 10.0, 10, c.z + 10.0), 60.0, 20.0, 30.0)
		"plein_air":
			_cam(rig, Vector3(-150, 20, 200), 150.0, 180.0, 50.0)
		"panneau", "hebergements":
			_cam(rig, Vector3(-120, 30, -20), 150.0, 0.0, 45.0)
			var panel: TourismePanel = scene.tourisme_panel
			panel.set_open(true)
			panel.show_view("bref" if vue == "panneau" else "heb")
	for i in 60:
		await process_frame
	tour.visuels._peupler()
	for i in 30:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(shot)
	print("Vitrine : %d bâtiments posés, %d touristes dessinés → %s" % [bids.size(), tour.visuels.count(), shot])
	quit(0)
