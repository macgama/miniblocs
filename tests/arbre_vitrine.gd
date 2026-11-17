extends SceneTree
## Captures de l'arbre de progression (panneau Maj+F10, catalogue verrouillé).
## Usage : xvfb-run godot --path . --rendering-driver opengl3 --script res://tests/arbre_vitrine.gd -- --dossier <dossier>


func _initialize() -> void:
	_run.call_deferred()


func _flat_tile(_t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(40.0)
	return a


func _shot(path: String) -> void:
	for i in 8:
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
	ReglagesPartie.prochaine = ReglagesPartie.preset("difficile")
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var transport: TransportSystem = scene.get_node("Transport")
	var bs: BuildingSystem = scene.get_node("Batiments")
	var amb: DayNight = scene.get_node("Ambiance")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.set_origin(46.52, 6.63)
	for i in 60:
		await process_frame
	amb.set_speed(0)
	amb.unix_time = Time.get_unix_time_from_datetime_string("2026-06-10T10:00:00")
	var y := world.cell_height(Vector2i(0, 0))
	transport.build_segment("route", Vector3(0, y, -160), Vector3(0, y, 140))
	for i in 4:
		bs.place("maison", Vector2i(-12, -150 + i * 16), 1)
	var r := ReglagesPartie.actuel
	r.note_population(1200)
	ArbreProgression.rang_atteint("Village", "Beauvallon")
	ArbreProgression.rang_atteint("Bourg", "Beauvallon")
	ArbreProgression.mission_reussie("Construire une école")
	for b in ["logement", "logement", "services", "commerce", "transports"]:
		ArbreProgression.acheter(r, b)
	scene.arbre_panel._selection = "logement"
	scene.arbre_panel.set_open(true)
	await _shot(dir.path_join("arbre-panneau.png"))
	scene.arbre_panel.set_open(false)
	scene.build_panel.set_open(true)
	scene.build_panel.show_category("logement")
	await _shot(dir.path_join("arbre-construire.png"))
	quit(0)
