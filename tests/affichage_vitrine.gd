extends SceneTree
## Captures « Fermer et réafficher les cartes » : 1) écran chargé avec la croix ronde
## sur chaque carte, 2) menu Affichage ouvert (vignettes), 3) tout masqué (Ctrl+H).
## Usage (avec affichage) :
##   godot --path . --rendering-driver opengl3 --script res://tests/affichage_vitrine.gd -- --dossier /chemin/captures


func _initialize() -> void:
	_run.call_deferred()


func _flat_tile(_t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(40.0)
	return a


func _attendre(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var dir := "."
	for i in args.size() - 1:
		if args[i] == "--dossier":
			dir = args[i + 1]
	root.size = Vector2i(1600, 900)
	Creations.persist = false
	AffichagePanneaux.persist = false
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.set_origin(46.62, 6.79)
	await _attendre(40)
	var hud: TerreHud = scene.hud
	hud._place_label.text = "Vulliens (Vaud), Suisse"
	scene.tutoriel.demarrer()
	var hab: HabitantsPanel = scene.habitants_panel
	hab.set_process(false)
	hab._card.visible = true
	hab._card_text.text = "★ Jeanne Fournier, 0 ans · Bébé\nChez l'assistante maternelle"
	var fil: FilAlertes = scene.fil_alertes
	for t in ["Plus un logement libre", "La grogne monte (48/100)", "4 poubelles débordent"]:
		var b := Button.new()
		b.text = t
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 40)
		fil._list.add_child(b)
	fil._n = 3
	fil._panel.visible = true
	await _attendre(30)
	var aff: AffichagePanneaux = scene.affichage
	root.get_viewport().get_texture().get_image().save_png(dir.path_join("1-croix-sur-les-cartes.png"))
	aff.masquer("habitant", true)
	aff.set_menu(true)
	await _attendre(15)
	root.get_viewport().get_texture().get_image().save_png(dir.path_join("2-menu-affichage.png"))
	aff.set_menu(false)
	aff.tout_masquer()
	await _attendre(15)
	root.get_viewport().get_texture().get_image().save_png(dir.path_join("3-tout-masque.png"))
	print("captures : ", dir)
	quit()
