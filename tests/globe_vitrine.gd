extends SceneTree
## Vitrine du globe : recherche d'une ville et choix du lieu de départ.
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
	root.size = Vector2i(1600, 900)
	var scene = load("res://scenes/globe.tscn").instantiate()
	scene.offline = true
	root.add_child(scene)
	await _shot(dir.path_join("globe-depart.png"), 60)
	scene._search.text = "lau"
	scene._refresh_list()
	await _shot(dir.path_join("globe-recherche.png"), 20)
	scene._search.text = "tokyo"
	scene._refresh_list()
	scene._list.select(0)
	scene._list.item_selected.emit(0)
	await _shot(dir.path_join("globe-tokyo.png"), 120)
	quit()
