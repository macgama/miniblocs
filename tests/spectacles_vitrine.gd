extends SceneTree
## Vitrine des spectacles : les 25 bâtiments, une soirée de spectacle avec son
## public, les studios et leurs décors, le menu.
## Usage (avec affichage) :
##   godot --path . --script res://tests/spectacles_vitrine.gd -- --screenshot s.png --vue salles|scenes|studios|soiree|panneau|programmer


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
	var shot := "spectacles.png"
	var vue := "salles"
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
	amb.unix_time = _at("2026-07-18", 19.6 if vue == "soiree" else 11.0)
	if amb.weather != null:
		amb.weather.set_process(false)
		amb.weather.precip = 0.0
		amb.weather.fog = 0.0
	var spect: Spectacles = scene.spectacles
	spect.ignore_staff = true
	var rig: Node3D = scene.get_node("CameraRig")
	var y := world.cell_height(Vector2i(0, 0))
	# Deux avenues : les salles au sud de la première, les studios au nord de la seconde.
	transport.build_segment("route", Vector3(-330, y, 0), Vector3(330, y, 0))
	transport.build_segment("route", Vector3(-330, y, 160), Vector3(330, y, 160))
	var poser := func(id: String, c: Vector2i) -> int:
		var sn := bs.road_snap(id, c)
		if sn.is_empty():
			return bs.place(id, c, 0)
		return bs.place(id, sn.center, int(sn.r), 0, float(sn.get("a", 0.0)))
	var bids := {}
	var x := -300.0
	for id in SpectaclesTypes.of_famille("cinema") + SpectaclesTypes.of_famille("concert"):
		var t := BuildingCatalog.get_type(String(id))
		x += float(t.w) / 2.0 + 4.0
		bids[id] = poser.call(String(id), Vector2i(int(x), -int(float(t.d) / 2.0) - 8))
		x += float(t.w) / 2.0
	x = -300.0
	for id in SpectaclesTypes.of_famille("theatre"):
		var t := BuildingCatalog.get_type(String(id))
		x += float(t.w) / 2.0 + 6.0
		bids[id] = poser.call(String(id), Vector2i(int(x), int(float(t.d) / 2.0) + 8))
		x += float(t.w) / 2.0
	# Studios et annexes autour.
	var st: int = poser.call("studio_cinema", Vector2i(0, 160 + 45))
	bids["studio_cinema"] = st
	var annexes := {"plateau_tournage": Vector2i(-80, 215), "decor_western": Vector2i(-80, 270), "decor_ville": Vector2i(-10, 270),
		"decor_chateau": Vector2i(60, 275), "decor_spatial": Vector2i(120, 270), "bassin_tournage": Vector2i(120, 215),
		"studio_effets": Vector2i(80, 205), "post_production": Vector2i(-55, 180), "atelier_decors_cinema": Vector2i(-115, 180)}
	for id in annexes:
		bids[id] = bs.place(String(id), annexes[id], 2)
	spect._sync()
	spect.clock = amb.unix_time - 3600.0
	spect.last_day = int(spect._now(amb.unix_time).day)
	spect._nouveau_jour_programmes()
	# Ce soir : des spectacles partout, et un film en tournage.
	var today := spect._today()
	for id in ["theatre_italienne", "opera_coupole", "salle_musiques_actuelles", "auditorium", "club_jazz", "cafe_theatre", "chapiteau_cirque", "theatre_verdure", "scene_contemporaine"]:
		var b := int(bids.get(id, -1))
		if b > 0:
			(spect.salles[b].agenda as Array).append({"d": today, "h": 20, "sp": "cyrano" if id != "salle_musiques_actuelles" else "electrons_libres", "auto": false})
	spect.lancer_film(st, "western", "moyen", "paolo_spaghetti", "bastien_machoire", "Le Shérif de Granit")
	var fid := int(spect.films_du_studio(st)[0])
	spect.films[fid].phase = "tournage"
	spect.visuels._placer()
	match vue:
		"salles":
			_cam(rig, Vector3(-150, 40, -30), 170.0, 0.0, 50.0)
		"scenes":
			_cam(rig, Vector3(-120, 40, 40), 150.0, 180.0, 48.0)
		"studios":
			_cam(rig, Vector3(0, 40, 235), 130.0, 160.0, 50.0)
		"soiree":
			var th := int(bids.get("theatre_italienne", -1))
			var c := spect.centre(th)
			_cam(rig, Vector3(c.x, 40, c.z - 20), 55.0, 200.0, 38.0)
		"panneau", "programmer":
			_cam(rig, Vector3(0, 40, 200), 110.0, 160.0, 52.0)
			var panel: SpectaclesPanel = scene.spectacles_panel
			panel.set_open(true)
			if vue == "programmer":
				panel.choisi = int(bids.get("salle_musiques_actuelles", -1))
				panel.show_view("programmer")
			else:
				panel.studio_choisi = st
				panel.show_view("studios")
	for i in 90:
		await process_frame
	spect.visuels._placer()
	for i in 10:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(shot)
	var poses := 0
	for k in bids:
		if int(bids[k]) > 0:
			poses += 1
	print("Capture : ", shot, " · ", poses, " bâtiments posés sur ", bids.size(), " · ", spect.visuels.compte(), " personnages")
	quit(0)
