extends SceneTree
## Vitrine des scénarios : la fenêtre « Scénarios et défis » du menu (avec un
## classement inventé), puis une partie « Reconstruire après l'inondation »
## avec sa carte à l'écran, puis l'écran de fin d'une victoire.
## Usage (avec affichage) :
##   godot --path . --rendering-driver opengl3 --script res://tests/scenarios_vitrine.gd -- --dossier /chemin/captures


func _initialize() -> void:
	_run.call_deferred()


func _flat_tile(_t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(40.0)
	return a


func _shot(path: String) -> void:
	for i in 12:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(path)
	print("capture : ", path)


func _run() -> void:
	var dossier := "user://"
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--dossier" and i + 1 < args.size():
			dossier = args[i + 1]
	Creations.persist = false
	BatimentsVie.chantiers = false
	Langue.activer("fr")
	Classement.chemin = "user://vitrine_scenarios_classement.json"
	Classement.recharger()
	Classement.effacer()
	for e in [["Margaux", 11200, 64, 3], ["Yanis", 9800, 71, 2], ["Le maire de Lunel", 8100, 88, 2], ["Inès", 6400, 102, 1]]:
		Classement.ajouter("crue", {"nom": e[0], "score": e[1], "jours": e[2], "medaille": e[3]})
	Classement.ajouter("course_bourg", {"nom": "Margaux", "score": 6900, "jours": 41, "medaille": 3})

	# Fenêtre du menu, sur un fond sombre.
	var fond := ColorRect.new()
	fond.color = Color("1d2b24")
	fond.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(fond)
	var panel := ScenariosPanel.new()
	root.add_child(panel)
	await process_frame
	panel.choisir("crue")
	await _shot(dossier.path_join("scenarios-menu.png"))
	panel.choisir("sans_voiture")
	await _shot(dossier.path_join("scenarios-menu-sans-voiture.png"))
	panel.queue_free()
	fond.queue_free()

	# Partie en scénario.
	Scenarios.preparer("crue")
	ReglagesPartie.prochaine.fondateurs = 0
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var transport: TransportSystem = scene.get_node("Transport")
	var bs: BuildingSystem = scene.get_node("Batiments")
	var zones: ZoneSystem = scene.get_node("Zones")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.view_radius_override = 1200.0
	world.set_origin(43.7847, 4.0894)
	for i in 3000:
		await process_frame
		if i >= 120 and world.missing_chunk_count() == 0 and world._dirty.is_empty() and world._jobs.is_empty():
			break
	scene.urgences.random_calls = false
	var y := world.cell_height(Vector2i(0, 0))
	scene.communes.nom_en_attente = "Sommières"
	bs.place("maison_commune", Vector2i(0, 0), 0)
	scene.villages_panel._dialog.hide()
	transport.build_segment("route", Vector3(0, y, 12), Vector3(0, y, 220))
	zones.add_zone("R", Rect2i(6, 30, 16, 60))
	bs.place("pompiers", Vector2i(-26, 60), 1)
	var s: ScenarioPartie = scene.scenario
	s.suivre()
	s.jour0 -= 23
	s.suivre()
	scene.rig.position = Vector3(0, 0, 110)
	scene.rig._target_distance = 260.0
	scene.scenario_carte.rafraichir()
	await _shot(dossier.path_join("scenarios-carte.png"))

	s.terminer(true)
	for i in 4:
		await process_frame
	await _shot(dossier.path_join("scenarios-bilan.png"))
	Classement.effacer()
	quit(0)
