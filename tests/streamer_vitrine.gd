extends SceneTree
## Vitrine du mode streamer : vote du chat en cours à l'écran, résultat avec
## veto, panneau F7 (réglages, habitants du chat).
## Usage (avec affichage) :
##   godot --path . --rendering-driver opengl3 --script res://tests/streamer_vitrine.gd -- --dossier /chemin/captures


func _initialize() -> void:
	_run.call_deferred()


func _flat_tile(_t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(40.0)
	return a


func _shot(path: String) -> void:
	for i in 14:
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
	Langue.activer("fr")
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
	world.view_radius_override = 800.0
	world.set_origin(46.2, 6.9)
	for i in 150:
		await process_frame
	Langue.activer("fr")
	amb.set_speed(0)
	amb.unix_time = Time.get_unix_time_from_datetime_string("2026-06-18T16:30:00")
	bs.unlimited_money = true
	var y := world.cell_height(Vector2i(0, 0))
	transport.build_segment("route", Vector3(-500, y, 0), Vector3(500, y, 0))
	transport.build_segment("rue", Vector3(-60, y, 0), Vector3(-60, y, 200))
	var homes := []
	for i in 14:
		homes.append(_place(bs, "maison", -260 + i * 14))
	for i in 8:
		homes.append(_place(bs, "maison", -220 + i * 16, false))
	_place(bs, "immeuble", 40, false)
	_place(bs, "immeuble", 70, false)
	var pop: Population = scene.population
	pop.set_process(false)
	scene.production.set_process(false)
	pop._sync_buildings()
	var ms: ModeStreamer = scene.mode_streamer
	ms.fichier = "user://streamer_vitrine.cfg"
	ms.chat.url = "ws://127.0.0.1:1"
	ms.activer(true, "gael_tv")
	ms.chat.deconnecter()
	for n in ["Zoé_Builds", "Kevin2Lyon", "Pixel_Mamie", "CaptainTartiflette", "Rafa_Geneve"]:
		ms.ajouter_pseudo(n)
	for i in 6:
		pop.spawn_household(homes[i], "famille")
	await process_frame
	var rig: Node3D = scene.get_node("CameraRig")
	rig.position = Vector3(-120, y, 0)
	rig._target_distance = 110.0
	rig.set_pitch(32.0, true)
	rig.rotation_degrees.y = 15.0
	ms.duree = 60
	ms.lancer_vote(["tempete", "impots_baisse", "calme"])
	var votes := [1, 1, 2, 1, 2, 2, 1, 3, 1, 1, 2, 1, 3, 1, 2, 1, 1]
	for i in votes.size():
		ms.recevoir("v%d" % i, "v%d" % i, str(votes[i]))
	ms._horloge += 18.0
	await _shot(dir.path_join("streamer-vote.png"))
	ms.clore_maintenant()
	await _shot(dir.path_join("streamer-resultat.png"))
	ms.annuler()
	scene.streamer_panel.set_open(true)
	await _shot(dir.path_join("streamer-panneau.png"))
	DirAccess.remove_absolute(ms.fichier)
	quit(0)
