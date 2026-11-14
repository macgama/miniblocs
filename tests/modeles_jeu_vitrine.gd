extends SceneTree
## Vitrine des modèles de l'atelier devenus bâtiments du jeu : une maison en
## murs fins enregistrée, reposée le long d'une route comme un bâtiment du
## catalogue (tournée, avec une autre fonction), l'onglet Mes modèles et la
## Banque avec le choix de la fonction.
## Usage (avec affichage) :
##   godot --path . --script res://tests/modeles_jeu_vitrine.gd -- --screenshot a.png --vue rue|banque


func _initialize() -> void:
	_run.call_deferred()


func _flat_tile(_t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(40.0)
	return a


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var shot := "modeles.png"
	var vue := "rue"
	for i in args.size():
		if args[i] == "--screenshot" and i + 1 < args.size():
			shot = args[i + 1]
		if args[i] == "--vue" and i + 1 < args.size():
			vue = args[i + 1]
	root.msaa_3d = Viewport.MSAA_DISABLED
	root.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	Creations.persist = false
	BanqueModeles.persist = false
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var bs: BuildingSystem = scene.get_node("Batiments")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.set_origin(48.8584, 2.2945)
	for i in 60:
		await process_frame
	var amb: DayNight = scene.get_node("Ambiance")
	amb.set_speed(0)
	bs.unlimited_money = true
	var mob: Mobilier = scene.mobilier
	var rig = scene.get_node("CameraRig")
	var y := world.cell_height(Vector2i(0, 0))
	scene.get_node("Transport").build_segment("route", Vector3(-70, y, 2), Vector3(70, y, 2))
	# La maison d'origine, en murs fins, construite dans l'atelier.
	var h := bs.place("hollandais__maison", Vector2i(-50, -12), 0)
	var conv := Conversion.open_interior(mob, h)
	mob.pe.flush()
	mob.flush()
	var r := BanqueModeles.save_plan(mob, String(conv.id), "Maison n° 1")
	var r2 := BanqueModeles.save_plan(mob, String(conv.id), "Ma petite centrale")
	BanqueModeles.set_fonction(String(r2.id), "centrale_gaz")
	var cid := ModelesJeu.catalog_id(String(r.id))
	var cid2 := ModelesJeu.catalog_id(String(r2.id))
	# Reposée comme un bâtiment : des deux côtés de la route, tournée vers elle.
	for i in 4:
		bs.place(cid, Vector2i(-30 + i * 14, -6), 2)
	bs.place(cid2, Vector2i(26, -6), 2)
	for i in 3:
		bs.place(cid, Vector2i(-24 + i * 14, 10), 0)
	amb.unix_time += 86400.0 * 60
	for i in 30:
		await process_frame
	rig.position = Vector3(-8, 40.0, 0)
	rig._distance = 70.0
	rig._target_distance = 70.0
	rig.rotation_degrees.y = 20.0
	if "pitch_degrees" in rig:
		rig.pitch_degrees = 38.0
	var bp: BuildingPanel = scene.get_node("PanneauConstruction")
	match vue:
		"rue":
			bp.set_open(true)
			bp.set_workshop(false)
			bp.show_category(ModelesJeu.CATEGORY)
		"banque":
			scene.set_create_mode(true)
			scene.hud.set_create_category("banque")
			scene._on_create_requested("banque")
			scene.banque_panel._choosing = String(r2.id)
			bp.show_category("banque")
	for i in 90:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(shot)
	print("Capture : ", shot)
	quit(0)
