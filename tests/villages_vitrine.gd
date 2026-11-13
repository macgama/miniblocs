extends SceneTree
## Vitrine des villages : fenêtre de fondation, Maison de commune, territoire et
## panneau Maj+M, deux villages avec le calque et l'outil Agrandir.
## Usage (avec affichage) :
##   godot --path . --rendering-driver opengl3 --script res://tests/villages_vitrine.gd -- --dossier /chemin/captures


func _initialize() -> void:
	_run.call_deferred()


func _shot(path: String, frames := 12) -> void:
	for i in frames:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(path)
	print("capture : ", path)


func _flat_tile(t: Vector2i) -> PackedFloat32Array:
	# Douces collines pour voir les frontières suivre le relief.
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	for j in 256:
		for i in 256:
			var x := float(t.x * 256 + i)
			var z := float(t.y * 256 + j)
			a[j * 256 + i] = 40.0 + 6.0 * sin(x * 0.02) * cos(z * 0.017)
	return a


func _at(date: String, hour: float) -> float:
	return Time.get_unix_time_from_datetime_string(date + "T00:00:00") + (hour - 1.0) * 3600.0


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
	GameStart.place_name = "Valfleuri, Savoie"
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var transport: TransportSystem = scene.get_node("Transport")
	var bs: BuildingSystem = scene.get_node("Batiments")
	var amb: DayNight = scene.get_node("Ambiance")
	var rig: Node3D = scene.get_node("CameraRig")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.view_radius_override = 2200.0
	world.set_origin(45.5, 6.4)
	for i in 4000:
		await process_frame
		if i >= 120 and world.missing_chunk_count() == 0 and world._dirty.is_empty() and world._jobs.is_empty():
			break
	scene.urgences.random_calls = false
	amb.set_speed(0)
	amb.unix_time = _at("2026-06-10", 16.0)
	var cm: Communes = scene.communes
	var panel: VillagesPanel = scene.villages_panel

	# 1. Début de partie : bandeau et fenêtre du nom.
	rig.position = Vector3(-1000, 40, 0)
	rig._target_distance = 420.0
	rig.set_pitch(50.0, true)
	await _shot(dir.path_join("villages-fondation.png"), 120)

	# 2. La Maison de commune.
	cm.nom_en_attente = "Valfleuri"
	panel._dialog.hide()
	var y := world.cell_height(Vector2i(-1000, 0))
	var mc := bs.place("maison_commune", Vector2i(-1000, 0), 0)
	rig.position = Vector3(-1000, y, 0)
	rig._target_distance = 42.0
	rig.set_pitch(28.0, true)
	rig.rotation_degrees.y = 200.0
	await _shot(dir.path_join("villages-maison-commune.png"), 40)

	# 3. Le village et son territoire, panneau ouvert.
	bs.unlimited_money = true
	transport.build_segment("route", Vector3(-1300, y, 30), Vector3(-700, y, 30))
	transport.build_segment("route", Vector3(-1000, y, 30), Vector3(-1000, y, 300))
	for i in 10:
		var c := Vector2i(-1250 + i * 26, 46)
		bs.place("maison", c, bs.best_rotation("maison", c))
	for i in 6:
		var c := Vector2i(-1016, 70 + i * 22)
		bs.place("maison", c, bs.best_rotation("maison", c))
	scene.zones.add_zone("R", Rect2i(-990, 60, 40, 200))
	panel.set_open(true)
	rig.position = Vector3(-1000, y, 0)
	rig._target_distance = 1100.0
	rig.set_pitch(58.0, true)
	rig.rotation_degrees.y = 0.0
	await _shot(dir.path_join("villages-territoire.png"), 60)

	# 4. Deux villages, calque des territoires et outil Agrandir.
	cm.nom_en_attente = "Les Granges"
	var mc2 := bs.place("maison_commune", Vector2i(1100, 0), 0)
	print("deuxième village : ", mc2, " ", bs.check_place("maison_commune", Vector2i(1100, 0), 0).reason)
	cm.calculer_stats()
	cm.stats[cm.principal()].palier = 2
	cm.croissance()
	Calques.afficher("territoires")
	cm.set_outil("annexer", cm.principal())
	rig.position = Vector3(50, y, 0)
	rig._target_distance = 2900.0
	rig.set_pitch(62.0, true)
	await _shot(dir.path_join("villages-deux-villages.png"), 30)
	var cam: Camera3D = bs.camera
	var k := Communes.case_de(-1000, 0) + Vector2i(13, 2)
	var m := Communes.centre_case(k)
	cm._survoler(cam.unproject_position(Vector3(m.x, y, m.y)))
	panel.refresh()
	await _shot(dir.path_join("villages-agrandir.png"), 20)
	print("maison commune : ", mc)
	quit()
