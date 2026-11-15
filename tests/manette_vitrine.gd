extends SceneTree
## Vitrine Steam Deck (1280 × 800) : menu principal à la manette, fenêtre des succès,
## partie avec curseur et aides des boutons, carte « Succès débloqué », options Manette.
## Usage (avec affichage) :
##   godot --path . --rendering-driver opengl3 --script res://tests/manette_vitrine.gd -- --dossier /chemin/captures


func _initialize() -> void:
	_run.call_deferred()


func _flat_tile(_t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(40.0)
	return a


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(path: String) -> void:
	await _frames(8)
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)
	print("capture : ", path)


## Fenêtre sans focus sous Xvfb : Godot y ignore la manette, on allume le mode à la main.
func _axe(_a: JoyAxis, _v: float) -> void:
	var man := root.get_node("ManetteAuto") as Manette
	man._set_actif(true)
	man._focus_mode = false
	man._maj_affichage()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var dir := "."
	for i in args.size() - 1:
		if args[i] == "--dossier":
			dir = args[i + 1]
	DisplayServer.window_set_size(Vector2i(1280, 800))
	root.size = Vector2i(1280, 800)
	OptionsJeu.charger()
	OptionsJeu.langue = "fr"
	Langue.activer("fr")
	Succes.persist = false
	Succes.reinitialiser()
	for id in ["premier_village", "route_nulle_part", "premier_coup_de_pelle", "pied_au_plancher", "pompier_de_service", "les_pieds_sur_terre"]:
		Succes.debloquer(id)
	Succes.noter("batiments", 62)
	Succes.noter("route_m", 14_800)
	Succes.ajouter("incendies", 25)
	var notif := root.get_node("SuccesNotif")
	notif._file.clear()
	if notif._carte != null:
		notif._carte.queue_free()
		notif._carte = null
	var man := root.get_node("ManetteAuto") as Manette

	var menu: Node = load("res://scenes/menu_principal.tscn").instantiate()
	root.add_child(menu)
	await _frames(30)
	_axe(JOY_AXIS_LEFT_X, 0.2)
	await _frames(2)
	_axe(JOY_AXIS_LEFT_X, 0.0)
	var b: Button = menu._boutons.succes
	man.placer_curseur(root.get_final_transform() * (b.get_global_rect().get_center() + Vector2(60, 4)))
	_axe(JOY_AXIS_LEFT_Y, 0.25)
	await _frames(2)
	_axe(JOY_AXIS_LEFT_Y, 0.0)
	await _shot(dir.path_join("deck-menu-principal.png"))
	menu.ouvrir_succes()
	await _shot(dir.path_join("deck-succes.png"))
	menu._sub.close_panel()
	menu.ouvrir_options()
	await _frames(3)
	menu._sub._tabs.current_tab = 4
	await _shot(dir.path_join("deck-options-manette.png"))
	menu._sub.close_panel()
	menu.queue_free()
	await _frames(3)

	Creations.persist = false
	ReglagesPartie.prochaine = ReglagesPartie.preset("normal")
	GameStart.mode = GameStart.Mode.BAC_A_SABLE
	GameStart.load_slot = ""
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var bs: BuildingSystem = scene.get_node("Batiments")
	var amb: DayNight = scene.get_node("Ambiance")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.set_origin(46.64, 6.63)
	await _frames(60)
	amb.set_speed(0)
	amb.unix_time = Time.get_unix_time_from_datetime_string("2026-06-10T16:00:00")
	var y := world.cell_height(Vector2i(0, 0))
	scene.transport.build_segment("route", Vector3(0, y, -160), Vector3(0, y, 140))
	scene.transport.build_segment("route", Vector3(-120, y, 0), Vector3(0, y, 0))
	for i in 8:
		bs.place("maison", Vector2i(-12, -150 + i * 16), 1)
		bs.place("maison", Vector2i(12, -150 + i * 16), 3)
	scene.rig.position = Vector3(0, y, -80)
	scene.rig._target_distance = 70.0
	scene.build_panel.set_open(true)
	scene.build_panel.building_chosen.emit("maison")
	_axe(JOY_AXIS_LEFT_X, 0.2)
	await _frames(2)
	_axe(JOY_AXIS_LEFT_X, 0.0)
	man.placer_curseur(Vector2(560, 430))
	_axe(JOY_AXIS_LEFT_Y, 0.25)
	await _frames(2)
	_axe(JOY_AXIS_LEFT_Y, 0.0)
	Succes.debloquer("cent_toits")
	await _frames(20)
	await _shot(dir.path_join("deck-partie-manette.png"))
	scene.build_panel.set_open(false)
	scene.toggle_succes()
	await _shot(dir.path_join("deck-partie-succes.png"))
	quit(0)
