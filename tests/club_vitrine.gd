extends SceneTree
## Vitrine du club de sport : un match à domicile au stade, le menu du club.
## Usage (avec affichage) :
##   godot --path . --script res://tests/club_vitrine.gd -- --screenshot c.png --vue match|pres|club|effectif|classement|finances


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
	var shot := "club.png"
	var vue := "match"
	for i in args.size():
		if args[i] == "--screenshot" and i + 1 < args.size():
			shot = args[i + 1]
		if args[i] == "--vue" and i + 1 < args.size():
			vue = args[i + 1]
	root.msaa_3d = Viewport.MSAA_DISABLED
	root.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	Creations.persist = false
	BatimentsVie.chantiers = false
	GameStart.place_name = "Lausanne, Vaud"
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var bs: BuildingSystem = scene.get_node("Batiments")
	var amb: DayNight = scene.get_node("Ambiance")
	var transport: TransportSystem = scene.get_node("Transport")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.set_origin(46.52, 6.63)
	for i in 90:
		await process_frame
	bs.unlimited_money = true
	amb.set_speed(0)
	amb.unix_time = _at("2026-07-25", 10.0)
	if amb.weather != null:
		amb.weather.set_process(false)
		amb.weather.precip = 0.0
		amb.weather.fog = 0.0
	var cs: ClubSport = scene.club
	cs.set_process(false)
	var rig: Node3D = scene.get_node("CameraRig")
	var pop: Population = scene.population
	var y := world.cell_height(Vector2i(0, 0))
	transport.build_segment("departementale", Vector3(-400, y, 0), Vector3(400, y, 0))
	var homes := []
	for i in 24:
		var c := Vector2i(-380 + i * 14, 12)
		homes.append(bs.place("maison", c, bs.best_rotation("maison", c)))
	pop._sync_buildings()
	for b in homes:
		if int(b) > 0:
			pop.spawn_household(int(b), "famille")
	var stade := -1
	bs.require_access = false
	for r in [2, 0]:
		var fp := BuildingCatalog.footprint("stade_tuiliere", r)
		for side in [-1, 1]:
			var c := Vector2i(150, side * (fp.y / 2 + 6))
			if stade < 0 and bs.check_place("stade_tuiliere", c, r).ok:
				stade = bs.place("stade_tuiliere", c, r)
	bs.require_access = true
	cs.fans_force = 3500
	cs.fonder("FC Lausanne", 1, stade)
	cs.ligue.clubs["FC Lausanne"].moi = true
	# Quelques journées déjà jouées.
	var t := amb.unix_time
	cs.clock = t
	var premier := {}
	var n := 0
	for j in cs.ligue.journees:
		var m := cs.mon_match(j)
		if String(m[0]) == "FC Lausanne":
			n += 1
			if n == 3:
				premier = j
				break
	while cs.today() < int(premier.d):
		t += 3600.0 * 6.0
		amb.unix_time = t
		cs.advance(3600.0 * 6.0)
	# Pendant le match.
	var kick: float = scene.evenements.unix_at(int(premier.d), float(premier.h))
	amb.unix_time = kick + 25.0 * 60.0
	var c := Stades.pelouse_monde(bs, stade).centre as Vector3
	match vue:
		"match":
			_cam(rig, Vector3(c.x, 40, c.z), 260.0, 200.0, 42.0)
		"pres":
			_cam(rig, Vector3(c.x, 20, c.z), 95.0, 160.0, 30.0)
		_:
			_cam(rig, Vector3(c.x, 40, c.z), 240.0, 200.0, 45.0)
			var panel: ClubPanel = scene.club_panel
			panel.set_open(true)
			panel.show_view(vue)
	for i in 160:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(shot)
	print("capture : ", shot, " (", cs.summary(), ")")
	for e in cs.journal.slice(0, 8):
		print("   ", e.t)
	print("   prevus ", scene.evenements.prevus("match").size(), " en cours ", scene.evenements.en_cours("match").size(), " premier ", premier.get("ev", -1), " d=", premier.d, " today=", cs.today())
	quit(0)
