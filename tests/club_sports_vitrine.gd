extends SceneTree
## Vitrine du club multisport : un match à domicile (basket, handball, hockey,
## rugby, tennis), les drapeaux des supporters en ville, le menu du club.
## Usage (avec affichage) :
##   godot --path . --script res://tests/club_sports_vitrine.gd -- --screenshot c.png --sport basket --vue match|pres|ville|club|formation|supporters|effectif


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


const LIEUX := {"basket": "salle_omnisports", "handball": "palais_sports", "hockey": "patinoire_hockey", "rugby": "stade_tuiliere", "tennis": "centre_tennis", "football": "stade_tuiliere"}


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var shot := "club.png"
	var vue := "match"
	var sport := "basket"
	for i in args.size():
		if args[i] == "--screenshot" and i + 1 < args.size():
			shot = args[i + 1]
		if args[i] == "--vue" and i + 1 < args.size():
			vue = args[i + 1]
		if args[i] == "--sport" and i + 1 < args.size():
			sport = args[i + 1]
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
	var cs: ClubSport = scene.clubs[sport]
	for s in scene.clubs:
		scene.clubs[s].set_process(false)
	var rig: Node3D = scene.get_node("CameraRig")
	var pop: Population = scene.population
	pop.principal.enabled = false
	var y := world.cell_height(Vector2i(0, 0))
	transport.build_segment("departementale", Vector3(-400, y, 0), Vector3(400, y, 0))
	var homes := []
	for i in 26:
		var c := Vector2i(-380 + i * 14, 12)
		homes.append(bs.place("maison", c, bs.best_rotation("maison", c)))
	for i in 12:
		var c := Vector2i(-380 + i * 14, 34)
		homes.append(bs.place("maison", c, bs.best_rotation("maison", c)))
	pop._sync_buildings()
	for b in homes:
		if int(b) > 0:
			pop.spawn_household(int(b), "famille")
	for pid in pop.persons:
		var p: Dictionary = pop.persons[pid]
		if pop.age_of(p) >= 12.0 and pop.age_of(p) <= 40.0 and posmod(int(pid), 2) == 0 and not (p.hob as Array).has(ClubSports.hobby(sport)):
			(p.hob as Array).append(ClubSports.hobby(sport))
	var lieu := -1
	var id: String = LIEUX[sport]
	bs.require_access = false
	for r in [2, 0]:
		var fp := BuildingCatalog.footprint(id, r)
		for side in [-1, 1]:
			var c := Vector2i(120, side * (fp.y / 2 + 7))
			if lieu < 0 and bs.check_place(id, c, r).ok:
				lieu = bs.place(id, c, r)
	var cf := -1
	for gap in [7, 10]:
		var fp2 := BuildingCatalog.footprint("centre_formation", 0)
		var c2 := Vector2i(-80, -(fp2.y / 2 + gap))
		if cf < 0 and bs.check_place("centre_formation", c2, 0).ok:
			cf = bs.place("centre_formation", c2, 0)
	bs.require_access = true
	cs.fans_force = 1800
	var nom := ClubSports.nom_propose(sport, "Lausanne")
	var err := cs.fonder(nom, 1, lieu)
	if err != "":
		print("fondation impossible : ", err)
	cs.set_academie(2)
	# On avance jusqu'au 3e match à domicile.
	var t := amb.unix_time
	cs.clock = t
	var premier := {}
	var n := 0
	for j in cs.ligue.journees:
		var m := cs.mon_match(j)
		if String(m[0]) == nom:
			n += 1
			if n == 3:
				premier = j
				break
	# Pour la photo : match en plein jour.
	if float(premier.h) > 16.0:
		premier.h = 14.5
	while cs.today() < int(premier.d):
		t += 3600.0 * 6.0
		amb.unix_time = t
		cs.advance(3600.0 * 6.0)
	var kick: float = scene.evenements.unix_at(int(premier.d), float(premier.h))
	amb.unix_time = kick + 25.0 * 60.0
	cs.club.humeur = 0.9
	pop.follow(-1)
	scene.club_supporters.refresh(true)
	var c := Stades.pelouse_monde(bs, lieu).centre as Vector3
	match vue:
		"match":
			_cam(rig, Vector3(c.x, 10, c.z), 95.0 if sport != "rugby" else 230.0, 200.0, 48.0)
		"pres":
			_cam(rig, Vector3(c.x, 6, c.z), 45.0 if sport != "rugby" else 90.0, 160.0, 38.0)
		"ville":
			amb.unix_time = kick - 3.0 * 3600.0
			_cam(rig, Vector3(-150, 6, 20), 160.0, 160.0, 40.0)
		_:
			_cam(rig, Vector3(c.x, 10, c.z), 140.0, 200.0, 45.0)
			var panel: ClubPanel = scene.club_panel
			panel.set_open(true)
			panel.choisir_sport(sport)
			panel.show_view(vue)
	for i in 160:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(shot)
	print("capture : ", shot, " (", cs.summary(), ") drapeaux ", scene.club_supporters.drapeaux)
	for e in cs.journal.slice(0, 6):
		print("   ", e.t)
	quit(0)
