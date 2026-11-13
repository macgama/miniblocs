extends SceneTree
## Vitrine de l'agriculture : une ferme céréalière et une ferme laitière avec
## leurs champs à différentes étapes (moisson en cours, labour, colza, chaume
## et bottes, pâture avec les vaches), et le panneau Agriculture.
## Usage (avec affichage) :
##   godot --path . --rendering-driver opengl3 --script res://tests/agriculture_vitrine.gd -- --dossier /chemin/captures


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


func _place(bs: BuildingSystem, id: String, x: int, north := true) -> int:
	var d := int(BuildingCatalog.get_type(id).d)
	var c := Vector2i(x, -(d / 2 + 6) if north else d / 2 + 6)
	return bs.place(id, c, bs.best_rotation(id, c))


func _etat(agri: Agriculture, id: int, etat: String, cult: String, cr: float) -> void:
	var ch: Dictionary = agri.champs[id]
	ch.etat = etat
	ch.cult = cult
	ch.sc = cult if etat in ["pousse", "mur"] else ""
	ch.cr = cr
	ch.eng = true
	ch.tr = true


func _travail(agri: Agriculture, bid: int, id: int, tache: String, part: float) -> void:
	var ch: Dictionary = agri.champs[id]
	ch.tache = tache
	ch.fait = Agriculture.surface(ch) * part
	var cult := String(ch.sc) if String(ch.sc) != "" else String(ch.cult)
	(agri.ferme(bid).travail as Array).append({"champ": id, "tache": tache, "machines": [], "cult": cult})


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var dir := "."
	for i in args.size() - 1:
		if args[i] == "--dossier":
			dir = args[i + 1]
	root.size = Vector2i(1600, 900)
	Creations.persist = false
	BatimentsVie.chantiers = false
	ReglagesPartie.actuel.catastrophes = false
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var transport: TransportSystem = scene.get_node("Transport")
	var bs: BuildingSystem = scene.get_node("Batiments")
	var amb: DayNight = scene.get_node("Ambiance")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.view_radius_override = 450.0
	world.set_origin(49.4, 1.1)
	for i in 500:
		await process_frame
		if i > 150 and world.missing_chunk_count() == 0:
			break
	amb.set_speed(0)
	amb.unix_time = Time.get_unix_time_from_datetime_string("2026-07-18T08:30:00")
	bs.unlimited_money = true
	var y := world.cell_height(Vector2i(0, 0))
	transport.build_segment("route", Vector3(-500, y, 0), Vector3(500, y, 0))
	var farm := _place(bs, "ferme_cereales", 120)
	var dairy := _place(bs, "ferme_laitiere", -120)
	var agri: Agriculture = scene.agriculture
	agri.clock = amb.unix_time
	var ble := agri.ajoute_champ(Rect2i(40, -220, 160, 150), "ble", farm)
	var colza := agri.ajoute_champ(Rect2i(210, -220, 140, 150), "colza", farm)
	var labour := agri.ajoute_champ(Rect2i(40, 20, 160, 120), "orge", farm)
	var chaume := agri.ajoute_champ(Rect2i(210, 20, 140, 120), "ble", farm)
	var pre := agri.ajoute_champ(Rect2i(-230, -200, 180, 130), "paturage", dairy)
	var mais := agri.ajoute_champ(Rect2i(-230, 20, 180, 120), "mais", dairy)
	_etat(agri, ble, "mur", "ble", 1.0)
	_travail(agri, farm, ble, "recolte", 0.45)
	_etat(agri, colza, "pousse", "colza", 0.85)
	_etat(agri, labour, "chaume", "orge", 0.0)
	_travail(agri, farm, labour, "labour", 0.55)
	_etat(agri, chaume, "chaume", "ble", 0.0)
	agri.champs[chaume].bottes = 1
	agri.champs[chaume].paille = 0.0
	_etat(agri, pre, "pousse", "paturage", 0.8)
	_etat(agri, mais, "pousse", "mais", 0.55)
	agri.ferme(dairy).betes = {"vache": 60}
	var rig: Node3D = scene.get_node("CameraRig")
	var vis: AgriVisuels = scene.agri_visuels
	rig.position = Vector3(60, y, -60)
	rig._target_distance = 420.0
	rig.rotation_degrees.y = 20.0
	for i in 60:
		await process_frame
	vis.mise_a_jour()
	await _shot(dir.path_join("agriculture-ensemble.png"))
	# Moisson en cours, de près.
	var pe := AgriVisuels.position_engin(agri.champs[ble])
	var p: Vector2 = pe[0]
	rig.position = Vector3(p.x, y, p.y)
	rig._target_distance = 55.0
	rig.rotation_degrees.y = 210.0
	for i in 30:
		await process_frame
	vis.mise_a_jour()
	await _shot(dir.path_join("agriculture-moisson.png"))
	# Labour.
	pe = AgriVisuels.position_engin(agri.champs[labour])
	p = pe[0]
	rig.position = Vector3(p.x, y, p.y)
	rig._target_distance = 60.0
	rig.rotation_degrees.y = 160.0
	for i in 30:
		await process_frame
	vis.mise_a_jour()
	await _shot(dir.path_join("agriculture-labour.png"))
	# Vaches au pré.
	rig.position = Vector3(-140, y, -135)
	rig._target_distance = 80.0
	rig.rotation_degrees.y = 0.0
	for i in 30:
		await process_frame
	vis.mise_a_jour()
	await _shot(dir.path_join("agriculture-vaches.png"))
	# Panneau.
	rig.position = Vector3(60, y, -60)
	rig._target_distance = 420.0
	agri.ferme_choisie = farm
	scene.agri_panel.set_open(true)
	scene.agri_panel.show_view("champs")
	await _shot(dir.path_join("agriculture-panneau-champs.png"))
	agri.ferme_choisie = dairy
	scene.agri_panel.show_view("betes")
	await _shot(dir.path_join("agriculture-panneau-betes.png"))
	scene.agri_panel.show_view("nourriture")
	await _shot(dir.path_join("agriculture-panneau-repas.png"))
	quit()
