extends SceneTree
## Vitrine de la refonte de l'ergonomie : Atelier vide, fiche « Enregistrer mon
## bâtiment », Construire en thèmes, recherche globale, recherche dans tout le
## jeu (Espace), tableau de bord de la Mairie et fil « À faire ».
## Usage (avec affichage) :
##   godot --path . --rendering-driver opengl3 --script res://tests/ergonomie_vitrine.gd -- --dossier /chemin/captures


func _initialize() -> void:
	_run.call_deferred()


func _flat_tile(_t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(40.0)
	return a


func _shot(path: String, n := 10) -> void:
	for i in n:
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
	BanqueModeles.persist = false
	FavorisConstruire.persist = false
	FavorisConstruire.vider_pour_tests()

	# 1. Atelier : terrain vide, les 3 étapes.
	GameStart.atelier = true
	var at: Node = load("res://scenes/terre.tscn").instantiate()
	root.add_child(at)
	for i in 200:
		await process_frame
	await _shot(dir.path_join("atelier-vide.png"))
	# 2. Un chalet, puis la fiche « Enregistrer mon bâtiment ».
	var aw: TerrainWorld = at.get_node("Terrain")
	var plans: PlanEditor = at.plans
	var y := aw.cell_height(Vector2i(0, 0))
	var pid := plans.new_plan(y)
	plans.add_room(pid, Rect2i(-6, -5, 12, 9), 0, 2)
	plans.add_roof(pid, "gable")
	at.rig.global_position = Vector3(0, y, 0)
	at.rig._target_distance = 45.0
	for i in 40:
		await process_frame
	at.parcours._refresh()
	await _shot(dir.path_join("atelier-construit.png"))
	at.parcours.ouvrir()
	at.parcours._nom = "Chalet du lac"
	(at.parcours._dialog.find_child("Nom", true, false) as LineEdit).text = "Chalet du lac"
	await _shot(dir.path_join("atelier-fiche.png"))
	at.parcours.poser_possible = true
	at.parcours.enregistrer("Chalet du lac", "maison")
	await _shot(dir.path_join("atelier-enregistre.png"))
	at.queue_free()
	for i in 10:
		await process_frame
	GameStart.atelier = false

	# 3. Une partie : Construire, recherche, Mairie.
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var bs: BuildingSystem = scene.get_node("Batiments")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.set_origin(46.5197, 6.6323)
	for i in 60:
		await process_frame
	var amb: DayNight = scene.get_node("Ambiance")
	amb.set_speed(0)
	amb.unix_time = Time.get_unix_time_from_datetime_string("2026-05-12T10:00:00")
	bs.unlimited_money = true
	var gy := world.cell_height(Vector2i(0, 0))
	scene.get_node("Transport").build_segment("route", Vector3(0, gy, -160), Vector3(0, gy, 140))
	for i in 5:
		bs.place("maison", Vector2i(-12, -120 + i * 16), 1)
	bs.place("ecole", Vector2i(-30, 10), 1)
	var bp: BuildingPanel = scene.build_panel
	var first := ""
	for id in BuildingCatalog.ids_in("logement"):
		first = String(id)
		break
	FavorisConstruire.basculer(first)
	FavorisConstruire.noter("ecole")
	bp.set_open(true)
	bp.show_category("zoo")
	await _shot(dir.path_join("construire-themes.png"), 30)
	bp._global_search.text = "piscine"
	bp._global_search.text_changed.emit("piscine")
	await _shot(dir.path_join("construire-recherche.png"), 30)
	bp._global_search.text = ""
	bp._global_search.text_changed.emit("")
	bp.set_open(false)
	var rech: RechercheUniverselle = scene.recherche
	rech.ouvrir("zoo")
	await _shot(dir.path_join("recherche-espace.png"))
	rech.fermer()
	# Mairie avec un relevé inventé (chômage, budget en baisse, coupures).
	var st: Statistiques = scene.statistiques
	for j in 8:
		st.historique.append({"j": 20000 + j, "n": 1, "d": {
			Statistiques.PAYS: {"habitants": 2380.0 + j * 7, "chomage": 12.0, "caisse": 1300000.0 - j * 15000, "solde": -380000.0,
				"satisfaction": 68.0, "logements_libres": 14.0, "emplois_libres": 40.0, "sans_ecole": 32.0, "coupures": 38.0,
				"eau": 92.0, "electricite": 100.0, "congestion": 12.0, "trajet": 14.5, "dechets": 0.0, "recyclage": 31.0}}})
	st.releve_fait.emit()
	await _shot(dir.path_join("fil-alertes.png"))
	scene.mairie_panel.set_open(true)
	await _shot(dir.path_join("mairie.png"))
	quit()
