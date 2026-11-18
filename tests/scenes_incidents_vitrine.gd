extends SceneTree
## Vitrine des lieux des incidents : accident (épaves, blessé, triangle), puis
## les secours sur place (cordon, brancard, ambulanciers), feu de poubelle avec
## la lance des pompiers, malaise devant une maison, et les icônes avec la
## carte de détail au survol.
## Usage (avec affichage) :
##   xvfb-run godot --path . --rendering-driver opengl3 --script res://tests/scenes_incidents_vitrine.gd -- --dossier /chemin/captures


func _initialize() -> void:
	_run.call_deferred()


func _flat_tile(_t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(40.0)
	return a


func _shot(path: String) -> void:
	for i in 20:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(path)
	print("capture : ", path)


func _place(bs: BuildingSystem, id: String, x: int, north := true) -> int:
	var d := int(BuildingCatalog.get_type(id).d)
	var c := Vector2i(x, -(d / 2 + 6) if north else d / 2 + 6)
	return bs.place(id, c, bs.best_rotation(id, c))


func _avance(urg: Urgences, tf: Traffic, n: int) -> void:
	for i in n:
		tf.step(0.1)
		urg.step(0.1)


func _vise(rig: Node3D, p: Vector3, dist: float, pitch: float, yaw: float) -> void:
	rig.position = p
	rig._target_distance = dist
	rig.set_pitch(pitch, true)
	rig.rotation_degrees.y = yaw


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var dir := "."
	for i in args.size() - 1:
		if args[i] == "--dossier":
			dir = args[i + 1]
	root.size = Vector2i(1600, 900)
	Creations.persist = false
	BatimentsVie.chantiers = false
	ReglagesPartie.actuel.deblocage = "tout"
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var transport: TransportSystem = scene.get_node("Transport")
	var bs: BuildingSystem = scene.get_node("Batiments")
	var amb: DayNight = scene.get_node("Ambiance")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 40
	world.view_radius_override = 700.0
	world.set_origin(46.2, 6.9)
	for i in 150:
		await process_frame
	amb.set_speed(0)
	amb.unix_time = Time.get_unix_time_from_datetime_string("2026-06-10T17:00:00")
	bs.unlimited_money = true
	ReglagesPartie.actuel.deblocage = "tout"
	var y := world.cell_height(Vector2i(0, 0))
	transport.build_segment("departementale", Vector3(-500, y, 0), Vector3(500, y, 0))
	_place(bs, "pompiers", -330)
	_place(bs, "police", -200, false)
	_place(bs, "hopital", 300, false)
	var maison := -1
	for x in [-260, -120, 150, 220]:
		var b := _place(bs, "maison", x)
		if x == 150:
			maison = b
	var urg: Urgences = scene.urgences
	urg.ignore_crew = true
	urg.random_calls = false
	urg._sync_stations()
	var tf := transport.traffic
	tf.siren_sound = false
	var rig: Node3D = scene.get_node("CameraRig")
	var id := urg.declare("accident", "Accident de la route", Vector3(40, y, 2), ["ambulance", "police"], 1)
	var p: Vector3 = urg.incidents[id].scene_pos
	_vise(rig, p, 26.0, 35.0, -30.0)
	await _shot(dir.path_join("1-accident.png"))
	# Les secours arrivent et travaillent.
	for i in 400:
		_avance(urg, tf, 1)
		if urg.incidents.has(id) and (urg.incidents[id].arrived as Dictionary).size() == 2:
			break
	_avance(urg, tf, 30)
	for i in 120:
		await process_frame
	await _shot(dir.path_join("2-accident-secours.png"))
	var fid := urg.declare("feu_poubelle", "Feu de poubelle", Vector3(-60, y, 2), ["pompiers"], 1)
	var mid := urg.declare("malaise", "Malaise", urg._building_pos(maison), ["ambulance"], 1, {"bid": maison})
	_vise(rig, urg.incidents[fid].scene_pos, 22.0, 30.0, 150.0)
	await _shot(dir.path_join("3-poubelle.png"))
	for i in 600:
		_avance(urg, tf, 1)
		if urg.incidents.has(fid) and urg.incidents[fid].arrived.has("pompiers"):
			break
	_avance(urg, tf, 10)
	for i in 120:
		await process_frame
	await _shot(dir.path_join("4-poubelle-lance.png"))
	if urg.incidents.has(mid):
		_vise(rig, urg.incidents[mid].scene_pos, 18.0, 60.0, 0.0)
		await _shot(dir.path_join("5-malaise.png"))
	# Icônes de loin, carte de détail.
	urg.declare("cambriolage", "Cambriolage", Vector3(-150, y, 2), ["police"], 1)
	_vise(rig, Vector3(0, y, 0), 260.0, 50.0, 0.0)
	for i in 60:
		await process_frame
	urg.icones.maj()
	if not urg.icones.icones.is_empty():
		var ic: Dictionary = urg.icones.icones[0]
		var e := urg.icones._ecran(ic)
		if not e.is_empty():
			urg.icones.epingle = int(ic.id)
	await _shot(dir.path_join("6-icones.png"))
	quit()
