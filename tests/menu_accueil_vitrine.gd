extends SceneTree
## Vitrine de l'écran d'accueil à plusieurs tailles de fenêtre : vérifie à l'œil que
## tous les boutons tiennent à l'écran, sans chevaucher la version ni l'aide.
## Usage : xvfb-run godot --path . --script res://tests/menu_accueil_vitrine.gd -- --dossier captures/accueil

const TAILLES := [Vector2i(1600, 900), Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1920, 1080),
	Vector2i(2560, 1080), Vector2i(1280, 1024), Vector2i(1280, 800)]

var dir := "."


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size() - 1:
		if args[i] == "--dossier":
			dir = args[i + 1]
	DirAccess.make_dir_recursive_absolute(dir)
	OptionsJeu.charger()
	OptionsJeu.anticrenelage = 0
	OptionsJeu.titre_fixe = true
	root.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	# Une partie sauvegardée, pour avoir « Continuer » et la carte « Dernière partie ».
	var slot := SaveGame.make_slot_id("vitrine accueil")
	SaveGame.write(slot, {"nom": "Atelier", "lieu": {"lat": 45.9, "lon": 6.13, "nom": "Annecy"},
		"resume": {"habitants": 0, "batiments": 0}}, {"terrain": {"version": 2, "lat": 45.9, "lon": 6.13, "modifs": {}}})
	for t in TAILLES:
		root.size = t
		var menu: MenuPrincipal = load("res://scenes/menu_principal.tscn").instantiate()
		root.add_child(menu)
		root.msaa_3d = Viewport.MSAA_DISABLED
		for i in 25:
			await process_frame
		var b: Button = menu._boutons.get("options")
		if b != null:
			b.grab_focus()
		for i in 5:
			await process_frame
		var path := dir.path_join("accueil-%dx%d.png" % [t.x, t.y])
		root.get_viewport().get_texture().get_image().save_png(path)
		print("capture : ", path)
		menu.queue_free()
		await process_frame
	SaveGame.delete(slot)
	quit()
