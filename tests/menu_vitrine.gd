extends SceneTree
## Vitrine du menu principal : écran titre, Options, Charger (avec aperçu),
## écran de chargement et menu pause.
## Usage : xvfb-run godot --path . --script res://tests/menu_vitrine.gd -- --dossier captures/menu

var dir := "."


func _initialize() -> void:
	_run.call_deferred()


func _flat_tile(_t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(35.0)
	return a


func _shot(name: String, frames := 10) -> void:
	for i in frames:
		await process_frame
	var path := dir.path_join(name)
	root.get_viewport().get_texture().get_image().save_png(path)
	print("capture : ", path)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size() - 1:
		if args[i] == "--dossier":
			dir = args[i + 1]
	DirAccess.make_dir_recursive_absolute(dir)
	root.size = Vector2i(1600, 900)
	# Le MSAA de lavapipe laisse des pixels parasites : FXAA pour les captures.
	OptionsJeu.charger()
	OptionsJeu.anticrenelage = 0
	OptionsJeu.titre_fixe = true
	root.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA

	# Une partie avec un aperçu, pour la carte « Dernière partie ».
	var slot := SaveGame.make_slot_id("vitrine annecy")
	SaveGame.write(slot, {"nom": "Annecy-le-Vieux", "lieu": {"lat": 45.9, "lon": 6.13, "nom": "Annecy"},
		"resume": {"habitants": 1240, "batiments": 312}}, {"terrain": {"version": 2, "lat": 45.9, "lon": 6.13, "modifs": {}}})

	var menu: MenuPrincipal = load("res://scenes/menu_principal.tscn").instantiate()
	root.add_child(menu)
	OptionsJeu.anticrenelage = 0
	root.msaa_3d = Viewport.MSAA_DISABLED
	await _shot("aperçu-tmp.png", 20)
	# L'aperçu de la partie : une vue de l'île (sans l'interface).
	menu._ui.visible = false
	await _shot("aperçu-tmp.png", 3)
	SaveGame.save_preview(slot, root.get_viewport().get_texture().get_image())
	DirAccess.remove_absolute(dir.path_join("aperçu-tmp.png"))
	menu._ui.visible = true
	menu._maj_carte()
	menu._carte.visible = true
	await _shot("menu-titre.png", 30)
	menu.ouvrir_options()
	await _shot("menu-options.png")
	(menu._sub as OptionsPanel)._tabs.current_tab = 1
	await _shot("menu-options-son.png")
	(menu._sub as OptionsPanel).close_panel()
	menu.ouvrir_parties()
	await process_frame
	var pp := menu._sub as PartiesPanel
	for i in pp._saves.size():
		if String(pp._saves[i].id) == slot:
			pp._list.select(i)
			pp._on_select()
	await _shot("menu-charger.png")
	pp.close_panel()
	menu.ouvrir_credits()
	await _shot("menu-credits.png")
	menu.queue_free()
	await process_frame

	# Écran de chargement (on fige l'image avant la fin).
	var e := EcranChargement.new()
	e.cible = "res://scenes/vide_inexistante.tscn"
	e.titre = "Annecy-le-Vieux"
	root.add_child(e)
	for i in 4:
		await process_frame
	e._progres = 0.55
	e._etape.text = "Téléchargement du relief : 6 tuiles en route…"
	await _shot("menu-chargement.png", 6)
	e.queue_free()

	# Menu pause dans une partie.
	Creations.persist = false
	BatimentsVie.chantiers = false
	GameStart.load_slot = ""
	var game: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = game.get_node("Terrain")
	root.add_child(game)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.set_origin(45.8992, 6.1294)
	root.msaa_3d = Viewport.MSAA_DISABLED
	for i in 90:
		await process_frame
	game.open_pause()
	game.pause_menu.unsaved = true
	await _shot("menu-pause.png")
	game.pause_menu._ask_quit(false)
	await _shot("menu-pause-quitter.png")
	game.close_pause()
	SaveGame.delete(slot)
	quit(0)
