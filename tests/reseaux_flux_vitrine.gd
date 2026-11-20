extends SceneTree
## Captures du flux des réseaux sur les routes.
## Usage : godot --path . --script res://tests/reseaux_flux_vitrine.gd -- --dossier captures
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
	ReglagesPartie.actuel.deblocage = "tout"
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
	ReglagesPartie.actuel.deblocage = "tout"
	amb.set_speed(0)
	if Guide.instance != null:
		Guide.instance.proposer = false
	amb.unix_time = Time.get_unix_time_from_datetime_string("2026-06-10T15:00:00")
	bs.unlimited_money = true
	bs.require_access = false
	var res: Reseaux = scene.reseaux
	var pop: Population = scene.population
	var y := world.cell_height(Vector2i(0, 0))
	transport.build_segment("route", Vector3(-200, y, 0), Vector3(200, y, 0))
	transport.build_segment("route", Vector3(0, y, 0), Vector3(0, y, 160))
	for i in 8:
		_place(bs, "maison", -180 + i * 22, 1)
	for i in 3:
		_place(bs, "immeuble", -60 + i * 30, -1)
	for i in 3:
		bs.place("maison", Vector2i(16, 40 + i * 30), 0)
	# Quartier à part : sa route ne touche pas les autres, il reste coupé.
	transport.build_segment("route", Vector3(-300, y, 120), Vector3(-160, y, 120))
	for i in 4:
		_place(bs, "maison", -290 + i * 30, 1, 120)
	# Poste électrique loin dans les champs, relié par une ligne à travers champs ;
	# forage d'eau relié par une conduite enterrée.
	var poste := bs.place("poste_national", Vector2i(260, -170), 0)
	bs.place("forage_eau", Vector2i(-230, -120), 0)
	res.poser("ligne_mt", res.trace_sur_relief(Vector3(260, y, -170), Vector3(200, y, 0)), false)
	res.poser("conduite_eau", res.trace_sur_relief(Vector3(-230, y, -120), Vector3(-200, y, 0)), false)
	res.poser("ligne_mt", res.trace_sur_relief(Vector3(-200, y, 0), Vector3(-230, y, -120)), false)
	for rr in ["elec", "eau"]:
		for id in res.reseau(rr).troncons:
			res.reseau(rr).terminer_troncon(id)
	if SuiviChantiers.instance:
		SuiviChantiers.instance.terminer_tout()
	await process_frame
	pop._sync_buildings()
	pop.follow_camera = false
	res.recalculer_topologie()
	res.simuler(0.0)
	res.simuler(0.0)
	pop.vie.follow(-1)
	var rig: Node3D = scene.get_node("CameraRig")
	rig.position = Vector3(20, y, -10)
	rig._target_distance = 330.0
	rig.set_pitch(55.0, true)
	rig.rotation_degrees.y = 0.0
	var maison := bs.building_at(Vector2i(16, 70))
	pop.select_building(maison)
	res.flux.basculer_batiment(maison)
	print("flux : ", res.flux.reseaux_montres, " ", res.flux.stats)
	await _shot(dir.path_join("flux-maison-tous-reseaux.png"))
	pop.select_building(poste)
	res.flux.basculer_batiment(poste)
	await _shot(dir.path_join("flux-centrale-champs.png"))
	rig.position = Vector3(-40, y, 40)
	rig._target_distance = 120.0
	rig.set_pitch(40.0, true)
	pop.select_building(maison)
	res.flux.basculer_batiment(maison)
	await _shot(dir.path_join("flux-zoom.png"))
	# Vue O, onglet Électricité, clic sur une route ; le réseau est saturé.
	pop.select_building(-1)
	scene.habitants_panel.set_open(false)
	scene.reseaux_panel.set_open(true)
	scene.reseaux_panel.show_view("elec")
	await process_frame
	res.reseau("elec").set_demande(maison, 200.0)
	res.reseau("elec").rebilan()
	rig.position = Vector3(20, y, -10)
	rig._target_distance = 330.0
	rig.set_pitch(55.0, true)
	res.flux.montrer_ligne("elec", res.flux.ligne_pres("elec", Vector3(0, y, 1)))
	await _shot(dir.path_join("flux-vue-o-sature.png"))
	print("vue O : ", res.flux.reseaux_montres, " ", res.flux.stats)
	quit(0)
