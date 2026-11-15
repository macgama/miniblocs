extends SceneTree
## Vitrine du menu Commerce (Maj+S) : 90 jours de marché, un choc pétrolier en
## cours, un accord signé, puis l'onglet choisi.
## Usage (avec affichage) :
##   godot --path . --script res://tests/commerce_vitrine.gd -- --screenshot c.png --vue marche|petrole|offres|accords|crises|villes


func _initialize() -> void:
	_run.call_deferred()


func _flat_tile(_t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(40.0)
	return a


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var shot := "commerce.png"
	var vue := "marche"
	for i in args.size():
		if args[i] == "--screenshot" and i + 1 < args.size():
			shot = args[i + 1]
		if args[i] == "--vue" and i + 1 < args.size():
			vue = args[i + 1]
	Creations.persist = false
	Langue.activer("fr")
	GameStart.chosen = true
	GameStart.place_name = "Bâle"
	GameStart.lat = 47.56
	GameStart.lon = 7.59
	ReglagesPartie.prochaine = ReglagesPartie.preset("normal")
	ReglagesPartie.prochaine.fondateurs = 0
	ReglagesPartie.prochaine.tutoriel = false
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.view_radius_override = 900.0
	world.set_origin(47.56, 7.59)
	for i in 300:
		await process_frame
		if i >= 60 and world.missing_chunk_count() == 0:
			break
	var cm: CommerceMondial = scene.commerce_mondial
	var prod: Production = scene.production
	ReglagesPartie.actuel.crises_economiques = false
	if prod.last_day < 0:
		prod.last_day = 20000
	cm.graine = 2027
	cm._initialiser(prod.last_day)
	for d in 90:
		prod.last_day += 1
		cm._on_day()
		if d == 70:
			cm.declencher_crise("choc_petrolier", 80)
	var pid: int = cm.partenaires.keys()[1]
	cm.signer({"id": "v", "partenaire": pid, "sens": "import", "g": "carburant", "t": 12.0, "prix": snappedf(Ressources.prix_import("carburant") * 0.7, 0.01),
		"duree": 90, "expire": cm.jour + 5}, Pays.PAYS)
	var a: Dictionary = cm.accords.values()[0]
	a.livre = 96.0
	a.valeur = 96.0 * float(a.prix)
	a.jour_t = 7.5
	cm.signer({"id": "w", "partenaire": cm.partenaires.keys()[0], "sens": "export", "g": "planches", "t": 6.0, "prix": 410.0,
		"duree": 60, "expire": cm.jour + 5}, Pays.PAYS)
	for dlg in scene.find_children("*", "ConfirmationDialog", true, false):
		(dlg as Window).hide()
	var amb: DayNight = scene.ambiance
	amb.unix_time = Time.get_unix_time_from_datetime_string("2026-06-15T10:00:00")
	var panel: CommercePanel = scene.commerce_panel
	panel.set_open(true)
	if vue == "petrole":
		panel.show_view("marche")
		panel.detail = "petrole"
		panel.refresh()
	else:
		panel.show_view(vue)
	for i in 30:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(shot)
	print("Capture : ", shot)
	quit(0)
