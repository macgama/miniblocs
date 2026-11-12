extends SceneTree
## Vitrine des menus : un petit quartier, puis trois captures de l'interface :
## outil Route (barre de catégories et plateau), Construire en vignettes, fiche
## d'un bâtiment. Usage (avec affichage) :
##   godot --path . --rendering-driver opengl3 --script res://tests/interface_vitrine.gd -- --dossier /chemin/captures


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
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var transport: TransportSystem = scene.get_node("Transport")
	var bs: BuildingSystem = scene.get_node("Batiments")
	var amb: DayNight = scene.get_node("Ambiance")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.set_origin(48.8584, 2.2945)
	for i in 60:
		await process_frame
	amb.set_speed(0)
	amb.unix_time = Time.get_unix_time_from_datetime_string("2026-03-10T09:00:00") # mardi 10 h à Paris
	bs.unlimited_money = true
	var y := world.cell_height(Vector2i(0, 0))
	transport.build_segment("route", Vector3(0, y, -160), Vector3(0, y, 140))
	var school := bs.place("ecole", Vector2i(-30, 0), 1)
	for i in 6:
		bs.place("immeuble", Vector2i(16, -150 + i * 22), 3)
	for i in 4:
		bs.place("maison", Vector2i(-12, -150 + i * 16), 1)
	bs.place("bureaux", Vector2i(20, 80), 3)
	bs.place("cafe", Vector2i(-14, 60), 1)
	bs.place("parc", Vector2i(-24, 110), 1)
	var pop: Population = scene.population
	pop._sync_buildings()
	for i in 72:
		pop.advance(300.0)
	var rig: Node3D = scene.get_node("CameraRig")
	rig.position = Vector3(-10, y, -60)
	rig._target_distance = 150.0
	var hud: TerreHud = scene.hud
	# 1. Outil Route : catégorie Voies, plateau des outils et réglage de la voie.
	hud._buttons[4].button_pressed = true
	hud._set_current_tool(4)
	hud.tool_selected.emit(4)
	await _shot(dir.path_join("apercu-menus-voies.png"))
	# 2. Construire : catégories en icônes, bâtiments en vignettes.
	hud._buttons[0].button_pressed = true
	hud._set_current_tool(0)
	hud.tool_selected.emit(0)
	scene.build_panel.set_open(true)
	scene.build_panel.show_category("logement")
	for i in 90:
		await process_frame
	await _shot(dir.path_join("apercu-menus-construire.png"))
	# 3. Fiche d'un bâtiment (clic avec Observer).
	pop.select_building(school)
	rig.position = Vector3(-30, y, 0)
	await _shot(dir.path_join("apercu-menus-fiche.png"))
	# 4. Lignes (panneau de droite, ne doit pas sortir de l'écran).
	scene.transit_panel.set_open(true)
	await _shot(dir.path_join("apercu-menus-lignes.png"))
	quit()
