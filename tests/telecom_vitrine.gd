extends SceneTree
## Vitrine d'internet et du téléphone : un village avec son central, une rue
## fibrée, un pylône 4G, une antenne 5G, une ferme reliée par des poteaux ;
## puis les calques de couverture mobile et de débit, et le panneau.
## Usage (avec affichage) :
##   godot --path . --rendering-driver opengl3 --script res://tests/telecom_vitrine.gd -- --dossier /chemin/captures


func _initialize() -> void:
	_run.call_deferred()


func _flat_tile(_t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(40.0)
	return a


func _shot(path: String) -> void:
	for i in 12:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(path)
	print("capture : ", path)


func _place(bs: BuildingSystem, id: String, x: int, north := true) -> int:
	var d := int(BuildingCatalog.get_type(id).d)
	var c := Vector2i(x, -(d / 2 + 6) if north else d / 2 + 6)
	return bs.place(id, c, bs.best_rotation(id, c))


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var dir := "."
	for i in args.size() - 1:
		if args[i] == "--dossier":
			dir = args[i + 1]
	root.size = Vector2i(1600, 900)
	Creations.persist = false
	BatimentsVie.chantiers = false
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var transport: TransportSystem = scene.get_node("Transport")
	var bs: BuildingSystem = scene.get_node("Batiments")
	var amb: DayNight = scene.get_node("Ambiance")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 40
	world.view_radius_override = 2800.0
	world.set_origin(46.2, 6.9)
	for i in 3000:
		await process_frame
		if i >= 150 and world.missing_chunk_count() == 0 and world._dirty.is_empty() and world._jobs.is_empty():
			break
	amb.set_speed(0)
	amb.unix_time = Time.get_unix_time_from_datetime_string("2026-06-10T09:00:00")
	bs.unlimited_money = true
	var y := world.cell_height(Vector2i(0, 0))
	transport.build_segment("departementale", Vector3(-600, y, 0), Vector3(600, y, 0))
	transport.build_segment("departementale", Vector3(100, y, -400), Vector3(100, y, 400))
	_place(bs, "central_telephonique", -300)
	for x in [-240, -200, -160, -120, -80, 20, 160, 200, 240, 300, 360, 420, 480]:
		_place(bs, "maison", x)
	for x in [-250, -180, 200, 280]:
		_place(bs, "immeuble", x, false)
	_place(bs, "bureaux", -100, false)
	_place(bs, "pylone_4g", -40, false)
	_place(bs, "antenne_5g", 140, false)
	var tel: Telecom = scene.telecom
	tel.fibrer_rue(Vector3(-200, y, 3))
	# Ferme isolée reliée par des poteaux.
	bs.require_access = false
	var ferme := bs.place("ferme", Vector2i(-380, 160), 0)
	bs.require_access = true
	var dp := tel._pos_of(bs.buildings[ferme])
	var ligne := PackedVector3Array([Vector3(dp.x, y, 4.0)])
	ligne.append_array(tel._segment(Vector3(dp.x, y, 4.0), dp))
	tel.poser_cable("fibre_aerienne", ligne)
	tel.recalculer()
	var rig: Node3D = scene.get_node("CameraRig")
	rig.position = Vector3(-50, y, -10)
	rig._target_distance = 70.0
	rig.set_pitch(22.0, true)
	rig.rotation_degrees.y = 200.0
	await _shot(dir.path_join("telecom-pylone.png"))
	rig.position = Vector3(-380, y, 90)
	rig._target_distance = 75.0
	rig.set_pitch(25.0, true)
	rig.rotation_degrees.y = 120.0
	await _shot(dir.path_join("telecom-poteaux.png"))
	scene.telecom_panel.set_open(true)
	tel.set_calque("debit")
	scene.telecom_panel.vue.survol_bid = 1
	scene.telecom_panel.vue._maj_boutons()
	rig.position = Vector3(0, y, 0)
	rig._target_distance = 420.0
	rig.set_pitch(60.0, true)
	rig.rotation_degrees.y = 0.0
	await _shot(dir.path_join("telecom-debit.png"))
	tel.set_calque("mobile")
	scene.telecom_panel.vue._maj_boutons()
	rig._target_distance = 3600.0
	rig.set_pitch(70.0, true)
	await _shot(dir.path_join("telecom-couverture.png"))
	quit()
