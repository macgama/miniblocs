extends SceneTree
## Vitrine « Taille du bâtiment » : une rue de maisons et d'immeubles à
## plusieurs tailles, et la carte Taille pendant la pose (étape 1 emprise,
## étape 2 hauteur) avec le fantôme.
## Usage (avec affichage) :
##   godot --path . --script res://tests/tailles_vitrine.gd -- --screenshot a.png --vue etape1|etape2|rangee


func _initialize() -> void:
	_run.call_deferred()


func _flat_tile(_t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(40.0)
	return a


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var shot := "tailles.png"
	var vue := "etape1"
	for i in args.size():
		if args[i] == "--screenshot" and i + 1 < args.size():
			shot = args[i + 1]
		if args[i] == "--vue" and i + 1 < args.size():
			vue = args[i + 1]
	Langue.activer("fr")
	root.size = Vector2i(1600, 900)
	root.msaa_3d = Viewport.MSAA_DISABLED
	root.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	Creations.persist = false
	BanqueModeles.persist = false
	GameStart.chosen = true
	ReglagesPartie.prochaine = ReglagesPartie.preset("normal")
	ReglagesPartie.prochaine.deblocage = "tout"
	ReglagesPartie.prochaine.services_fondation = false
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var bs: BuildingSystem = scene.get_node("Batiments")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.set_origin(46.2, 6.1)
	for i in 60:
		await process_frame
	var amb: DayNight = scene.get_node("Ambiance")
	amb.set_speed(0)
	amb.unix_time = Time.get_unix_time_from_datetime_string("2027-06-20T00:00:00")
	if amb.weather != null:
		amb.weather.set_process(false)
		amb.weather.precip = 0.0
		amb.weather.fog = 0.0
	scene.communes.nom_en_attente = "Valfleuri"
	bs.require_access = false
	bs.place("maison_commune", Vector2i(-40, -60), 0)
	for i in 4:
		await process_frame
	bs.unlimited_money = false
	bs.money = 30_000_000
	bs.require_access = false
	var rig = scene.get_node("CameraRig")
	var y := world.cell_height(Vector2i(0, 0))
	scene.get_node("Transport").build_segment("route", Vector3(-50, y, 2), Vector3(50, y, 2))
	var rangee := ["maison@8x10x1", "maison", "maison@13x15x2", "maison@14x16x4", "immeuble@18x14x2", "immeuble", "immeuble@22x16x10"]
	var ids := []
	var x := -46
	for id in rangee:
		var t := BuildingCatalog.get_type(id)
		var c := Vector2i(x + int(t.w) / 2, -int(t.d) / 2 - 6)
		var bid := bs.place(id, c, 2)
		print(id, " : ", bid, " ", bs.check_place(id, c, 2).get("reason", ""))
		ids.append(bid)
		x += int(t.w) + 3
	amb.unix_time += 86400.0 * 60 + 14.0 * 3600.0
	for i in 30:
		await process_frame
	for b in ids:
		if int(b) >= 0:
			bs.buildings[b]["chantier"] = false
			bs.rafraichir_modele(int(b))
	scene.population._sync_buildings()
	rig.position = Vector3(-2, 40.0, 4)
	rig._distance = 104.0
	rig._target_distance = 104.0
	rig.rotation_degrees.y = 0.0
	if "pitch_degrees" in rig:
		rig.pitch_degrees = 24.0
	if scene.get("tutoriel") != null:
		scene.tutoriel.arreter()
	for b in scene.find_children("*", "BullesAide", true, false):
		(b as BullesAide).fermer()
	if vue != "rangee":
		bs.set_place("maison")
		for i in 3:
			await process_frame
		var tp: TaillePanel = scene.taille_panel
		tp.choisir(13, 15, 2)
		if vue == "etape2":
			tp.montrer_etape(2)
			tp.choisir(13, 15, 3)
		bs.rot = 0
		bs._cursor = Vector2i(40, 14)
		bs._cursor_valid = true
		bs._refresh()
	for i in 90:
		await process_frame
	if amb.weather != null:
		amb.weather.precip = 0.0
		amb.weather.fog = 0.0
	root.get_viewport().get_texture().get_image().save_png(shot)
	print("Capture : ", shot)
	quit(0)
