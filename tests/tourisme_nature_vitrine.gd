extends SceneTree
## Vitrine du tourisme v2 sur le vrai terrain (téléchargé) : une plage avec ses
## baigneurs et parasols, un poste de secours, des autocars sur la route du bord
## de mer, le menu Tourisme → Attractions.
## Usage (avec affichage, réseau nécessaire pour le relief et les biomes) :
##   godot --path . --script res://tests/tourisme_nature_vitrine.gd -- --screenshot n.png --vue plage|autocars|panneau [--lieu lat,lon]


func _initialize() -> void:
	_run.call_deferred()


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
	var shot := "nature.png"
	var vue := "plage"
	var lieu := Vector2(43.4832, -1.5586) # Biarritz
	for i in args.size():
		if args[i] == "--screenshot" and i + 1 < args.size():
			shot = args[i + 1]
		if args[i] == "--vue" and i + 1 < args.size():
			vue = args[i + 1]
		if args[i] == "--lieu" and i + 1 < args.size():
			var p := args[i + 1].split(",")
			lieu = Vector2(float(p[0]), float(p[1]))
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
	ReglagesPartie.actuel.construction_instantanee = true
	world.set_origin(lieu.x, lieu.y)
	var tour: Tourisme = scene.tourisme
	tour.set_process(false)
	tour.ignore_staff = true
	var r := {}
	for i in 3000:
		await process_frame
		if i % 30 == 0:
			r = SitesNaturels.scanner(world, [Vector2.ZERO])
			if bool(r.ok):
				break
	var plage := {}
	for s in r.get("sites", []):
		if String(s.genre) == "plage" and (plage.is_empty() or float(s.base) > float(plage.base)):
			plage = s
	if plage.is_empty():
		print("Vitrine : pas de plage ici.")
		quit(1)
		return
	# On recentre la carte sur la plage.
	var ll := world.local_to_lat_lon((plage.pos as Vector3).x, (plage.pos as Vector3).z)
	world.set_origin(ll.x, ll.y)
	for i in 400:
		await process_frame
		if i >= 120 and world.missing_chunk_count() == 0 and world._jobs.is_empty():
			break
	bs.unlimited_money = true
	amb.set_speed(0)
	amb.unix_time = _at("2026-08-07", 15.0)
	if amb.weather != null:
		amb.weather.set_process(false)
		amb.weather.precip = 0.0
		amb.weather.fog = 0.0
	# La route du bord de mer : du côté de la terre, parallèle à la côte.
	var mer := Vector3.ZERO
	for a in 16:
		var d := Vector3(cos(a * TAU / 16.0), 0, sin(a * TAU / 16.0))
		var h := world.raw_height(d.x * 120.0, d.z * 120.0)
		if not is_nan(h) and h < world.sea_level():
			mer += d
	if mer.length() < 0.01:
		mer = Vector3(0, 0, 1)
	mer = mer.normalized()
	var long := Vector3(-mer.z, 0, mer.x)
	var c0 := -mer * 70.0
	var y0 := world.cell_height(Vector2i(floori(c0.x), floori(c0.z)))
	var rd := transport.build_segment("route", c0 - long * 250.0 + Vector3(0, y0, 0), c0 + long * 250.0 + Vector3(0, y0, 0))
	var rd2 := transport.build_segment("route", c0 + Vector3(0, y0, 0), c0 - mer * 500.0 + Vector3(0, y0, 0))
	var poser := func(id: String, p: Vector3) -> int:
		var sn := bs.road_snap(id, Vector2i(floori(p.x), floori(p.z)))
		if sn.is_empty():
			return -1
		return bs.place(id, sn.center, int(sn.r), 0, float(sn.get("a", 0.0)))
	var poste: int = poser.call("poste_secours_plage", c0 + mer * 12.0 + long * 40.0)
	var base: int = poser.call("base_nautique", c0 + mer * 18.0 - long * 120.0)
	var hotel: int = poser.call("hotel_4", c0 - mer * 20.0 + long * 120.0)
	var pk: int = poser.call("parking_autocars", c0 - mer * 25.0 - long * 60.0)
	tour._sync()
	tour.maj_nature(true)
	var site := {}
	for s in tour.nature:
		if String(s.genre) == "plage" and (site.is_empty() or (s.pos as Vector3).length() < (site.pos as Vector3).length()):
			site = s
	tour.clock = amb.unix_time
	tour.last_day = int(tour._now(amb.unix_time).day)
	tour._maj_sites()
	for s in tour.sites:
		if String(s.kind) == "nature":
			tour.visites_jour["nature:%s" % String(s.key)] = 400.0
	var rig: Node3D = scene.get_node("CameraRig")
	match vue:
		"plage":
			_cam(rig, c0 + mer * 60.0, 70.0, rad_to_deg(atan2(-mer.x, -mer.z)) + 180.0, 32.0)
		"autocars":
			var tr: Traffic = transport.traffic
			if pk > 0:
				for i in 3:
					tour.lancer_autocar(pk, site.get("pos", Vector3.INF))
					for f in 90:
						await process_frame
			_cam(rig, c0 - long * 30.0, 70.0, rad_to_deg(atan2(-mer.x, -mer.z)) + 150.0, 30.0)
			print("Autocars sur la route : %d" % tour.autocars_visibles())
		"panneau":
			_cam(rig, c0 + mer * 60.0, 90.0, rad_to_deg(atan2(-mer.x, -mer.z)) + 180.0, 40.0)
			var panel: TourismePanel = scene.tourisme_panel
			panel.set_open(true)
			panel.show_view("sites")
	for i in 40:
		await process_frame
	tour.visuels._peupler_nature(c0 + mer * 40.0)
	tour.visuels._peupler()
	if vue == "plage":
		# On regarde les baigneurs.
		var centre := Vector3.ZERO
		var nb := 0
		for k in tour.visuels.nature_agents:
			for a in tour.visuels.nature_agents[k].liste:
				centre += a.p
				nb += 1
		if nb > 0:
			_cam(rig, centre / nb, 75.0, rad_to_deg(atan2(-mer.x, -mer.z)) + 160.0, 38.0)
	for i in 40:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(shot)
	print("Vitrine : %s, route %s/%s, poste %d, base %d, hôtel %d, parking %d, %d baigneurs → %s" % [String(site.get("nom", "")), rd.ok, rd2.ok, poste, base, hotel, pk, tour.visuels.count_nature(), shot])
	quit(0)
