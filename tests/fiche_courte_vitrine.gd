extends SceneTree
## Captures de la fiche courte d'un bâtiment (clic sur une maison) : l'essentiel
## en tête (jauges, réseaux en pastilles), le détail en rubriques repliées, le
## flux des réseaux seulement sur demande (« Sur les routes »), et le panneau des
## coordonnées qui pousse les cartes de gauche au lieu de passer dessous.
## Usage (avec affichage) :
##   godot --path . --rendering-driver opengl3 --script res://tests/fiche_courte_vitrine.gd -- --dossier /chemin/captures


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
	Langue.activer("fr")
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
	_place(bs, "bureaux", 120, -1)
	bs.place("poste_national", Vector2i(260, -170), 0)
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
	for i in 72:
		pop.advance(300.0)
	pop.vie.follow(-1)
	var rig: Node3D = scene.get_node("CameraRig")
	rig.position = Vector3(20, y, 30)
	rig._target_distance = 200.0
	rig.set_pitch(50.0, true)
	rig.rotation_degrees.y = 0.0
	var hp: HabitantsPanel = scene.habitants_panel
	hp.ouvertes.clear()
	var maison := bs.building_at(Vector2i(16, 70))
	pop.select_building(maison)
	await _shot(dir.path_join("1-clic-maison-fiche-courte.png"))
	hp.basculer_rubrique("habitants")
	await _shot(dir.path_join("2-rubrique-habitants-depliee.png"))
	hp.basculer_rubrique("habitants")
	hp.basculer_rubrique("reseaux")
	res.flux.basculer_batiment(maison)
	hp.refresh()
	await _shot(dir.path_join("3-sur-les-routes-et-reseaux.png"))
	res.flux.basculer_batiment(maison)
	hp.basculer_rubrique("reseaux")
	hp.ouvertes.clear()
	var cfg := ConfigFile.new()
	if cfg.load("user://interface.cfg") == OK and cfg.has_section("fiche"):
		cfg.erase_section("fiche")
		cfg.save("user://interface.cfg")
	hp.set_open(false)
	scene.hud._coords_go.button_pressed = true
	await _shot(dir.path_join("4-coordonnees-sans-chevauchement.png"))
	quit(0)
