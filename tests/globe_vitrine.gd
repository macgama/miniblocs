extends SceneTree
## Vitrine du globe : recherche d'une ville, choix du lieu de départ, puis les
## étapes de l'assistant de nouvelle partie (type de carte, réglages, tutoriel, résumé).
## Usage (avec affichage) :
##   godot --path . --rendering-driver opengl3 --script res://tests/globe_vitrine.gd -- --dossier /chemin/captures


func _initialize() -> void:
	_run.call_deferred()


func _shot(path: String, frames := 12) -> void:
	for i in frames:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(path)
	print("capture : ", path)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var dir := "."
	for i in args.size() - 1:
		if args[i] == "--dossier":
			dir = args[i + 1]
	for i in args.size() - 1:
		if args[i] == "--langue":
			Langue.activer(args[i + 1])
	root.size = Vector2i(1600, 900)
	var scene = load("res://scenes/globe.tscn").instantiate()
	scene.offline = not args.has("--planete")
	root.add_child(scene)
	if args.has("--planete"):
		var t0 := Time.get_ticks_msec()
		while scene._planet == null and Time.get_ticks_msec() - t0 < 90_000:
			await process_frame
	await _shot(dir.path_join("globe-depart.png"), 60)
	scene._search.text = "lau"
	scene._refresh_list()
	await _shot(dir.path_join("globe-recherche.png"), 20)
	scene._search.text = "lausanne"
	scene._refresh_list()
	scene._list.select(0)
	scene._list.item_selected.emit(0)
	await _shot(dir.path_join("assistant-1-lieu.png"), 120)
	scene.suivant()
	await _shot(dir.path_join("assistant-2-type-de-carte.png"))
	scene._mode_btns[1].button_pressed = true
	await _shot(dir.path_join("assistant-2-entre-amis.png"))
	scene._mode_btns[0].button_pressed = true
	scene.suivant()
	scene._epoque_opt.select(1)
	scene._epoque_opt.item_selected.emit(1)
	await _shot(dir.path_join("assistant-3-reglages.png"))
	scene._defilement.scroll_vertical = 10000
	await _shot(dir.path_join("assistant-3-reglages-bas.png"))
	scene.suivant()
	await _shot(dir.path_join("assistant-4-tutoriel.png"))
	scene.suivant()
	await _shot(dir.path_join("assistant-5-resume.png"))
	quit()
