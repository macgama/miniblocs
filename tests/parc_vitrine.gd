extends SceneTree
## Captures du parc de loisirs : vue d'ensemble, manèges de près, foule et
## files, panneau. Un samedi de juillet, en milieu de journée.
## Usage : godot --path . --script res://tests/parc_vitrine.gd -- --dossier captures/parc

const SAMEDI := 1_784_358_000.0


func _initialize() -> void:
	_run.call_deferred()


func _flat_tile(_t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(40.0)
	return a


func _shot(path: String, frames := 30) -> void:
	for i in frames:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(path)
	print("capture : ", path)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var dir := "."
	for i in args.size() - 1:
		if args[i] == "--dossier":
			dir = args[i + 1]
	DirAccess.make_dir_recursive_absolute(dir)
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
	world.view_radius_override = 800.0
	world.set_origin(46.2, 6.9)
	for i in 150:
		await process_frame
	amb.set_speed(0)
	amb.unix_time = SAMEDI
	if amb.weather != null:
		amb.weather.mode = Meteo.Mode.SOLEIL
	bs.unlimited_money = true
	var y := world.cell_height(Vector2i(0, 0))
	transport.build_segment("route", Vector3(-400, y, 0), Vector3(400, y, 0))
	var parc: ParcLoisirs = scene.parc
	parc.set_process(false)
	parc.ignore_staff = true
	scene.production.set_process(false)
	scene.dechets.set_process(false)
	var c0 := Vector2i(0, -14)
	var e := bs.place("entree_parc", c0, bs.best_rotation("entree_parc", c0))
	for spec in [["carrousel_parc", -34, -48], ["grande_roue_parc", 24, -46], ["montagnes_russes", 10, -150], ["bateau_pirate", -62, -86],
		["chaises_volantes", 56, -88], ["tasses_parc", -36, -122], ["autos_tamponneuses", 66, -128], ["tour_chute", -70, -150],
		["train_fantome", -6, -96], ["friterie_parc", -10, -42], ["glacier_parc", -4, -32], ["buvette_parc", 6, -60],
		["boutique_souvenirs", 24, -26], ["toilettes_parc", 40, -66], ["aire_repos_parc", -14, -70], ["atelier_parc", 92, -60],
		["aire_repos_parc", 32, -106]]:
		var bid := bs.place(String(spec[0]), Vector2i(int(spec[1]), int(spec[2])), 0)
		if bid < 0:
			push_warning("pose impossible : %s" % spec[0])
	parc._sync()
	parc.renommer(e, "Parc des Merveilles")
	parc.clock = SAMEDI
	parc.last_day = int(parc._now(parc.clock).day)
	# De 9 h à 14 h.
	for i in 5 * 60:
		parc.clock += ParcLoisirs.STEP
		parc.step(ParcLoisirs.STEP)
	amb.unix_time = parc.clock
	parc.visuels._rebuild_t = 0.0
	var rig: Node3D = scene.get_node("CameraRig")
	rig.position = Vector3(10, y, -85)
	rig._target_distance = 230.0
	rig.set_pitch(38.0, true)
	rig.rotation_degrees.y = 0.0
	await _shot(dir.path_join("parc-ensemble.png"), 60)
	rig.position = Vector3(-20, y, -50)
	rig._target_distance = 70.0
	rig.set_pitch(24.0, true)
	rig.rotation_degrees.y = 15.0
	await _shot(dir.path_join("parc-entree-carrousel.png"))
	rig.position = Vector3(10, y + 6, -150)
	rig._target_distance = 85.0
	rig.set_pitch(22.0, true)
	rig.rotation_degrees.y = -25.0
	await _shot(dir.path_join("parc-montagnes-russes.png"))
	rig.position = Vector3(-40, y, -100)
	rig._target_distance = 75.0
	rig.set_pitch(26.0, true)
	rig.rotation_degrees.y = 140.0
	await _shot(dir.path_join("parc-bateau-tour.png"))
	rig.position = Vector3(0, y, -60)
	rig._target_distance = 36.0
	rig.set_pitch(28.0, true)
	rig.rotation_degrees.y = 200.0
	await _shot(dir.path_join("parc-foule.png"))
	scene.parc_panel.set_open(true)
	scene.parc_panel.show_view("parc")
	rig.position = Vector3(10, y, -85)
	rig._target_distance = 230.0
	rig.set_pitch(38.0, true)
	rig.rotation_degrees.y = 0.0
	await _shot(dir.path_join("parc-panneau.png"))
	scene.parc_panel.show_view("attractions")
	await _shot(dir.path_join("parc-panneau-attractions.png"))
	scene.parc_panel.show_view("visiteurs")
	await _shot(dir.path_join("parc-panneau-visiteurs.png"))
	quit()
