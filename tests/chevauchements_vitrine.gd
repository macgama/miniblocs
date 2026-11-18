extends SceneTree
## Captures de l'interface sans chevauchement : barre du haut avec une ville au long
## nom, colonne de gauche (tutoriel, habitant suivi, case, « À faire »), à 1600×900.
## Usage (avec affichage) :
##   godot --path . --rendering-driver opengl3 --script res://tests/chevauchements_vitrine.gd -- --dossier /chemin/captures


func _initialize() -> void:
	_run.call_deferred()


func _flat_tile(_t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(40.0)
	return a


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
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.set_origin(46.62, 6.79)
	for i in 40:
		await process_frame
	var hud: TerreHud = scene.hud
	hud.set_process(false)
	hud._place_label.text = "Vulliens (Vaud), Suisse"
	hud.set_stats("Vulliens (Vaud) : Illimitée", 145, 27, "0 %")
	hud.set_process(true)
	scene.tutoriel.demarrer()
	var hab: HabitantsPanel = scene.habitants_panel
	hab.set_process(false)
	hab._card.visible = true
	hab._card_text.text = "★ Jeanne Fournier, 0 ans · Bébé\nChez l'assistante maternelle"
	var fil: FilAlertes = scene.fil_alertes
	for t in ["Électricité : seulement 0 % des bâtiments", "Plus un logement libre", "La grogne monte (48/100)", "4 poubelles débordent"]:
		var b := Button.new()
		b.text = t
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 40)
		fil._list.add_child(b)
	fil._n = 4
	fil._panel.visible = true
	for i in 30:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(dir.path_join("chevauchements-1600x900.png"))
	print("capture : ", dir.path_join("chevauchements-1600x900.png"))
	quit()
