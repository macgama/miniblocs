extends SceneTree
## Vitrine des icônes de raccordement : un village desservi le long d'une route
## (centrale, forage, station d'épuration), un hameau sans route (icônes rouges)
## et une rue à part sans ligne (coupée : orange dans la vue O). Captures :
## jeu normal, vue Réseaux (O), fiche du bâtiment, tableau de bord de la Mairie.
## Usage (avec affichage) :
##   godot --path . --rendering-driver opengl3 --script res://tests/raccordements_vitrine.gd -- --dossier /chemin/captures


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


func _place(bs: BuildingSystem, id: String, x: int, side := -1, road_z := 0) -> int:
	var d := int(BuildingCatalog.get_type(id).d)
	var c := Vector2i(x, road_z + side * (d / 2 + 6))
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
	ReglagesPartie.actuel.construction_instantanee = true
	ReglagesPartie.actuel.reseaux_obligatoires = true
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var transport: TransportSystem = scene.get_node("Transport")
	var bs: BuildingSystem = scene.get_node("Batiments")
	var amb: DayNight = scene.get_node("Ambiance")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 40
	world.view_radius_override = 900.0
	world.set_origin(46.2, 6.9)
	for i in 150:
		await process_frame
	amb.set_speed(0)
	amb.unix_time = Time.get_unix_time_from_datetime_string("2026-06-10T15:00:00")
	bs.unlimited_money = true
	bs.require_access = false
	var res: Reseaux = scene.reseaux
	var pop: Population = scene.population
	var y := world.cell_height(Vector2i(0, 0))
	transport.build_segment("route", Vector3(-200, y, 0), Vector3(200, y, 0))
	for i in 8:
		_place(bs, "maison", -180 + i * 22, 1)
	for i in 3:
		_place(bs, "immeuble", -60 + i * 30, -1)
	_place(bs, "poste_national", 120, -1)
	_place(bs, "forage_eau", 160, -1)
	_place(bs, "station_epuration_locale", 150, 1)
	# Hameau sans route, au nord-est : rien n'arrive.
	for c in [Vector2i(60, 90), Vector2i(90, 100), Vector2i(75, 125)]:
		bs.place("maison", c, 0)
	bs.place("ferme", Vector2i(120, 140), 0)
	# Rue à part, à l'ouest, sans ligne ni conduite : raccordée mais coupée.
	transport.build_segment("route", Vector3(-300, y, 90), Vector3(-160, y, 90))
	for i in 4:
		_place(bs, "maison", -290 + i * 30, 1, 90)
	if SuiviChantiers.instance:
		SuiviChantiers.instance.terminer_tout()
	await process_frame
	pop._sync_buildings()
	pop.follow_camera = false
	for i in 30:
		pop.advance(300.0)
	res.simuler(0.0)
	scene.telecom.recalculer()
	res.raccordements.maj()
	print("non raccordés : %d, icônes : %d" % [res.raccordements.nb_non_raccordes, res.raccordements.nb_icones])
	pop.vie.follow(-1)
	pop.follow_camera = false
	var rig: Node3D = scene.get_node("CameraRig")
	rig.position = Vector3(-20, y, 70)
	rig._target_distance = 260.0
	rig.set_pitch(38.0, true)
	rig.rotation_degrees.y = 15.0
	await _shot(dir.path_join("raccordements-jeu.png"))
	# Vue Réseaux (O), onglet Courant : icônes plus grandes, coupés en orange.
	scene.reseaux_panel.set_open(true)
	scene.reseaux_panel.show_view("elec")
	res.raccordements._process(0.1)
	await _shot(dir.path_join("raccordements-vue-reseaux.png"))
	scene.reseaux_panel.set_open(false)
	# Fiche d'une maison du hameau (clic sur le bâtiment).
	scene.statistiques.releve()
	var bid: int = scene.aller_au_non_raccorde()
	rig._target_distance = 120.0
	rig.set_pitch(30.0, true)
	await _shot(dir.path_join("raccordements-fiche.png"))
	scene.habitants_panel.set_open(false)
	scene.mairie_panel.set_open(true)
	await _shot(dir.path_join("raccordements-mairie.png"))
	print("bâtiment montré : ", bid)
	quit(0)
