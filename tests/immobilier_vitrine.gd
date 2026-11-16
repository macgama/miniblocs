extends SceneTree
## Vitrine de l'immobilier : un bidonville en bord de ville, les logements sociaux
## de chaque époque et la résidence de standing, le panneau Immobilier (F7).
## Usage (avec affichage) :
##   godot --path . --rendering-driver opengl3 --script res://tests/immobilier_vitrine.gd -- --dossier /chemin/captures


func _initialize() -> void:
	_run.call_deferred()


func _flat_tile(_t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(40.0)
	return a


func _shot(path: String) -> void:
	for i in 14:
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
	BatimentsVie.chantiers = false
	GameStart.chosen = true
	Langue.activer("fr")
	var pre := ReglagesPartie.preset("libre")
	pre.tutoriel = false
	pre.catastrophes = false
	ReglagesPartie.prochaine = pre
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var transport: TransportSystem = scene.get_node("Transport")
	var bs: BuildingSystem = scene.get_node("Batiments")
	var amb: DayNight = scene.get_node("Ambiance")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.view_radius_override = 450.0
	world.set_origin(45.5, 6.4)
	for i in 500:
		await process_frame
		if i > 150 and world.missing_chunk_count() == 0:
			break
	amb.set_speed(0)
	amb.unix_time = Time.get_unix_time_from_datetime_string("2026-06-12T16:30:00")
	bs.unlimited_money = true
	bs.require_access = false
	scene.population.arrivals = false
	var im: Immobilier = scene.immobilier
	im.actif = false
	var y := world.cell_height(Vector2i(0, 0))
	transport.build_segment("route", Vector3(-300, y, 0), Vector3(300, y, 0))
	scene.communes.nom_en_attente = "Valfleuri"
	bs.place("maison_commune", Vector2i(200, 40), 0)
	for i in 4:
		await process_frame
	# Logements sociaux de chaque époque et résidence de standing, au nord de la rue.
	var x := -200
	for id in ["cite_ouvriere", "hbm", "hlm_barre", "residence_sociale", "residence_standing"]:
		var t := BuildingCatalog.get_type(id)
		var c := Vector2i(x + int(t.w) / 2, -(int(t.d) / 2 + 6))
		bs.place(id, c, bs.best_rotation(id, c))
		x += int(t.w) + 12
	# Un bidonville au sud.
	var bv := 1
	im.bidonvilles[bv] = {"id": bv, "nom": "La Zone", "vid": -1, "c": Vector2(20, 70), "baraques": [], "viab": false, "ne": 0}
	im.next_bv = 2
	for i in 11:
		im._ajouter_baraque(bv)
	scene.population._sync_buildings()
	for bq in im.bidonvilles[bv].baraques:
		scene.population.spawn_household(int(bq), "famille")
	var rig: Node3D = scene.get_node("CameraRig")
	rig.position = Vector3(20, y, 70)
	rig._target_distance = 90.0
	rig.rotation_degrees.y = 200.0
	for i in 60:
		await process_frame
	await _shot(dir.path_join("immobilier-bidonville.png"))
	rig.position = Vector3(-40, y, -20)
	rig._target_distance = 170.0
	rig.rotation_degrees.y = 0.0
	await _shot(dir.path_join("immobilier-logements-sociaux.png"))
	rig.position = Vector3(-20, y, 20)
	rig._target_distance = 260.0
	scene.immobilier_panel.set_open(true)
	scene.immobilier_panel.show_view("bidonvilles")
	await _shot(dir.path_join("immobilier-panneau-bidonvilles.png"))
	scene.immobilier_panel.show_view("marche")
	await _shot(dir.path_join("immobilier-panneau-marche.png"))
	quit()
