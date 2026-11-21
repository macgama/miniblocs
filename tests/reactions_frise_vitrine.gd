extends SceneTree
## Vitrine des bulles des habitants et de la frise avant / après : un village qui
## pousse (une vraie image par étape), la frise exportée depuis l'écran du
## time-lapse, puis une bulle d'habitant au-dessus d'un bâtiment posé.
## Usage (avec affichage) :
##   godot --path . --script res://tests/reactions_frise_vitrine.gd -- --sortie dossier [--langue en]


func _initialize() -> void:
	_run.call_deferred()


func _flat_tile(_t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(40.0)
	return a


func _at(date: String, hour: float) -> float:
	return Time.get_unix_time_from_datetime_string(date + "T00:00:00") + (hour - 2.0) * 3600.0


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	print("capture : ", path)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var sortie := "user://vitrine_reactions"
	var langue := "fr"
	for i in args.size():
		if args[i] == "--sortie" and i + 1 < args.size():
			sortie = args[i + 1]
		if args[i] == "--langue" and i + 1 < args.size():
			langue = args[i + 1]
	DirAccess.make_dir_recursive_absolute(sortie)
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
	await _frames(90)
	Langue.activer(langue)
	bs.unlimited_money = true
	amb.set_speed(0)
	amb.unix_time = _at("2026-05-04", 12.0)
	if amb.weather != null:
		amb.weather.set_process(false)
		amb.weather.precip = 0.0
	amb._apply()
	var tl: TimeLapse = scene.timelapse
	tl.set_process(false)
	var rig: Node3D = scene.rig
	rig.position = Vector3(0, 40, 0)
	if scene.tutoriel != null:
		scene.tutoriel.clear()
	var mairie := bs.place("maison_commune", Vector2i(0, -14), 0)
	scene.communes.actif = true
	var vid: int = scene.communes.fonder_au_point("Valbelle", Vector2(0, 0), mairie)
	if tl.cameras.is_empty():
		tl.camera_village(vid)
	var c: Dictionary = tl.cameras[0]
	var y := world.cell_height(Vector2i(0, 0))
	await _frames(30)
	await tl.filmer(c)
	var maisons := func(depart: Vector2i, pas: Vector2i, n: int, t := "maison") -> void:
		for i in n:
			var cc: Vector2i = depart + pas * i
			bs.place(t, cc, bs.best_rotation(t, cc))
	var etapes := [
		func() -> void: transport.build_segment("rue", Vector3(-90, y, 0), Vector3(90, y, 0)),
		func() -> void: maisons.call(Vector2i(-80, 10), Vector2i(14, 0), 6),
		func() -> void: maisons.call(Vector2i(8, 10), Vector2i(14, 0), 6),
		func() -> void: transport.build_segment("rue", Vector3(0, y, 0), Vector3(0, y, 120)),
		func() -> void: maisons.call(Vector2i(-80, -12), Vector2i(14, 0), 6),
		func() -> void:
			maisons.call(Vector2i(12, 24), Vector2i(0, 16), 5)
			maisons.call(Vector2i(-12, 24), Vector2i(0, 16), 5),
		func() -> void: maisons.call(Vector2i(8, -12), Vector2i(16, 0), 5, "immeuble"),
	]
	for e in etapes:
		e.call()
		amb.shift_days(3)
		amb.set_local_hour(12.0)
		await _frames(40)
		await tl.filmer(c)
	# Une partie commencée en 1800 : années et habitants comme dans une vraie partie.
	var imgs: Array = c.images
	var hab := [0, 12, 40, 85, 140, 260, 480, 900]
	for i in imgs.size():
		imgs[i]["an"] = 1800 + roundi(i * 46.0 / (imgs.size() - 1))
		imgs[i]["hab"] = hab[mini(i, hab.size() - 1)]
	print("images : ", imgs.size())
	var p: TimeLapsePanel = scene.timelapse_panel
	p.set_open(true)
	p._choisir(int(c.id))
	await _frames(10)
	var chemin: String = await p.exporter_frise()
	await _frames(5)
	await _shot(sortie.path_join("frise-apercu.png"))
	if chemin != "":
		var img := Image.load_from_file(chemin)
		img.save_png(sortie.path_join("frise-avant-apres.png"))
		DirAccess.remove_absolute(chemin)
		print("frise : ", sortie.path_join("frise-avant-apres.png"))
	p._apercu.visible = false
	p.set_open(false)
	await _frames(10)
	# Une bulle d'habitant : on pose une école au bout de la rue.
	var pop: Population = scene.population
	var pid := 990001
	pop.persons[pid] = {"id": pid, "p": "Lucie", "n": "Morand", "s": "f", "nj": pop.life_clock - 9 * 365.25, "f": -1,
		"r": "enfant", "job": -1, "met": "", "sch": -1, "hob": []}
	rig.position = Vector3(0, 40, 40)
	rig.set("_distance", 140.0)
	rig.set("_target_distance", 140.0)
	rig.rotation_degrees.y = 20.0
	rig.set_pitch(40.0, true)
	var ecole := -1
	for cur in [Vector2i(60, -30), Vector2i(-50, -30), Vector2i(60, 30), Vector2i(-40, 50)]:
		var sn := bs.road_snap("ecole", cur)
		if not sn.is_empty():
			ecole = bs.place("ecole", sn.center, int(sn.r), 0, float(sn.get("a", 0.0)))
		if ecole >= 0:
			break
	await _frames(40)
	var re: ReactionsHabitants = scene.reactions
	re.rng.seed = 5
	re.clear()
	var pos := re._pos_batiment(bs.buildings[ecole]) if ecole >= 0 else Vector3(30, y + 8, 60)
	print("école : ", ecole, " bulle : ", re.reagir("ecole", pos, true), " ", re.bulle, " visible ", re.is_visible_in_tree(), " ", re.carte().visible)
	for i in 6:
		await process_frame
	print("bulle à ", re.carte().position, " ", re.carte().size, " ", re.carte().modulate)
	await _shot(sortie.path_join("bulle-ecole.png"))
	pop.persons.erase(pid)
	quit(0)
