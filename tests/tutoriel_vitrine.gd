extends SceneTree
## Vitrine du tutoriel : la première étape sur une terre vierge, puis l'étape
## « Tracer une route » avec les objectifs à l'écran, et la case du globe.
## Usage (avec affichage) :
##   godot --path . --rendering-driver opengl3 --script res://tests/tutoriel_vitrine.gd -- --dossier /chemin/captures


func _initialize() -> void:
	_run.call_deferred()


func _flat_tile(_t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(40.0)
	return a


func _shot(path: String) -> void:
	for i in 10:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(path)
	print("capture : ", path)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var dir := "."
	for i in args.size() - 1:
		if args[i] == "--dossier":
			dir = args[i + 1]
	root.size = Vector2i(1600, 900)
	Creations.persist = false
	BatimentsVie.chantiers = false
	GameStart.chosen = true
	GameStart.load_slot = ""
	GameStart.place_name = "Valfleuri, Savoie"
	ReglagesPartie.prochaine = ReglagesPartie.preset("normal")
	ReglagesPartie.prochaine.fondateurs = 0
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var transport: TransportSystem = scene.get_node("Transport")
	var bs: BuildingSystem = scene.get_node("Batiments")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.view_radius_override = 1200.0
	world.set_origin(45.5, 6.4)
	for i in 3000:
		await process_frame
		if i >= 120 and world.missing_chunk_count() == 0 and world._dirty.is_empty() and world._jobs.is_empty():
			break
	scene.urgences.random_calls = false
	var t: Tutoriel = scene.tutoriel
	await _shot(dir + "/tutoriel-bienvenue.png")
	scene.rig.position.x += 60.0
	t.verifier()
	scene.communes.nom_en_attente = "Valfleuri"
	bs.place("maison_commune", Vector2i(0, 0), 0)
	var y := world.cell_height(Vector2i(0, 0))
	transport.build_segment("route", Vector3(0, y, 12), Vector3(0, y, 30))
	t.verifier()
	scene.objectifs.nouveau_jour()
	scene.rig.position = Vector3(0, y, 20)
	await _shot(dir + "/tutoriel-route-objectifs.png")
	quit(0)
