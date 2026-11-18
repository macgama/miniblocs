extends SceneTree
## Captures des nouveautés du parc : nouvelles attractions de la recherche
## (looping, tour panoramique, rivière rapide, palais des glaces, cinéma 4D),
## feu d'artifice, drones et lasers la nuit, onglets Publicité, Recherche et
## Soirées du panneau.
## Usage : godot --path . --script res://tests/parc_soirees_vitrine.gd -- --dossier captures/parc-soirees

## Samedi 18 juillet 2026, 9 h.
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
	ReglagesPartie.actuel.recherche_parc = true
	for id in ["feux_couleurs", "eclairage_feerique", "spectacle_laser", "pyromelodie", "drones_lumineux", "revision_preventive",
		"palais_glaces", "montagnes_russes", "grande_roue_parc", "tour_panoramique", "looping_express", "bateaux_tamponneurs",
		"autos_tamponneuses", "riviere_rapide", "cinema_dynamique"]:
		parc.recherche.faits[id] = 1
	parc.set_process(false)
	parc.ignore_staff = true
	scene.production.set_process(false)
	scene.dechets.set_process(false)
	var c0 := Vector2i(0, -14)
	var e := bs.place("entree_parc", c0, bs.best_rotation("entree_parc", c0))
	for spec in [["looping_express", 0, -150], ["tour_panoramique", 60, -60], ["riviere_rapide", -70, -110], ["palais_glaces", -40, -45],
		["cinema_dynamique", 40, -30], ["carrousel_parc", -10, -70], ["grande_roue_parc", 75, -110], ["friterie_parc", 10, -42],
		["buvette_parc", 16, -60], ["toilettes_parc", -20, -30], ["aire_repos_parc", 20, -95], ["atelier_parc", 100, -40]]:
		if bs.place(String(spec[0]), Vector2i(int(spec[1]), int(spec[2])), 0) < 0:
			push_warning("pose impossible : %s" % spec[0])
	parc._sync()
	parc.renommer(e, "Parc des Merveilles")
	parc.recherche.set_budget(2)
	parc.recherche.ajouter("tour_chute")
	parc.recherche.ajouter("coupe_file")
	parc.recherche.points = 74.0
	parc.set_soiree(e, "pyromelodique", 2, "samedis")
	parc.clock = SAMEDI
	parc.last_day = int(parc._now(parc.clock).day)
	parc.parcs[e].note = 4.2
	parc.lancer_campagne(e, "television", "touristes", 4)
	parc.lancer_campagne(e, "reseaux_sociaux", "sensations", 2)
	for i in 6:
		parc.new_day()
	for i in 5 * 60:
		parc.clock += ParcLoisirs.STEP
		parc.step(ParcLoisirs.STEP)
	amb.unix_time = parc.clock
	parc.visuels._rebuild_t = 0.0
	var rig: Node3D = scene.get_node("CameraRig")
	rig.position = Vector3(0, y, -100)
	rig._target_distance = 240.0
	rig.set_pitch(36.0, true)
	rig.rotation_degrees.y = 0.0
	await _shot(dir.path_join("nouvelles-attractions.png"), 60)
	rig.position = Vector3(8, y + 8, -150)
	rig._target_distance = 95.0
	rig.set_pitch(18.0, true)
	rig.rotation_degrees.y = -20.0
	await _shot(dir.path_join("looping.png"))
	rig.position = Vector3(-60, y, -100)
	rig._target_distance = 80.0
	rig.set_pitch(30.0, true)
	rig.rotation_degrees.y = 30.0
	await _shot(dir.path_join("riviere-palais.png"))
	rig.position = Vector3(55, y + 20, -55)
	rig._target_distance = 95.0
	rig.set_pitch(14.0, true)
	rig.rotation_degrees.y = 160.0
	await _shot(dir.path_join("tour-cinema.png"))
	# Le soir : feu pyromélodique.
	for i in int(8.75 * 60):
		parc.clock += ParcLoisirs.STEP
		parc.step(ParcLoisirs.STEP)
	amb.unix_time = parc.clock
	print("spectacle : ", parc.parcs[e].show, " spectateurs ", parc.parcs[e].jour.spectateurs)
	EchelleTemps.force = 1.0
	rig.position = Vector3(0, y + 20, -60)
	rig._target_distance = 330.0
	rig.set_pitch(8.0, true)
	rig.rotation_degrees.y = 0.0
	await _shot(dir.path_join("feu-artifice.png"), 120)
	var p: Dictionary = parc.parcs[e]
	p.show = {"type": "drones", "taille": 2, "t0": parc.clock - 60.0, "t1": parc.clock + 900.0, "id": 9001}
	await _shot(dir.path_join("drones.png"), 150)
	p.show = {"type": "laser", "taille": 2, "t0": parc.clock - 60.0, "t1": parc.clock + 900.0, "id": 9002}
	rig._target_distance = 200.0
	await _shot(dir.path_join("laser.png"), 60)
	p.show = {}
	EchelleTemps.force = -1.0
	amb.unix_time = SAMEDI + 5 * 3600.0
	parc.clock = amb.unix_time
	scene.parc_panel.set_open(true)
	for v in ["publicite", "recherche", "soirees"]:
		scene.parc_panel.show_view(v)
		await _shot(dir.path_join("panneau-%s.png" % v))
	quit()
