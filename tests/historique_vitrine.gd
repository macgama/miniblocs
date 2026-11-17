extends SceneTree
## Vitrine d'annuler / mode plan : une rue réelle, un quartier en projet (fantômes
## bleus) avec l'encadré du mode plan, puis le quartier construit.
## Usage (avec affichage) :
##   godot --path . --rendering-driver opengl3 --script res://tests/historique_vitrine.gd -- --dossier /chemin/captures


func _initialize() -> void:
	_run.call_deferred()


func _flat_tile(_t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(40.0)
	return a


func _shot(path: String, n := 20) -> void:
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
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var bs: BuildingSystem = scene.get_node("Batiments")
	var tr: TransportSystem = scene.get_node("Transport")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.set_origin(46.5197, 6.6323)
	for i in 60:
		await process_frame
	var amb: DayNight = scene.get_node("Ambiance")
	amb.set_speed(0)
	amb.unix_time = Time.get_unix_time_from_datetime_string("2026-05-12T10:00:00")
	BatimentsVie.chantiers = false
	var gy := world.cell_height(Vector2i(0, 0))
	tr.build_segment("route", Vector3(-120, gy, 0), Vector3(120, gy, 0))
	for i in 6:
		bs.place("maison", Vector2i(-90 + i * 30, -14), 2)
	var mp: ModePlan = scene.mode_plan
	mp.set_actif(true)
	mp.capter_voie("route", {}, PackedVector2Array([Vector2(0, 0), Vector2(0, 110)]))
	mp.capter_voie("route", {}, PackedVector2Array([Vector2(-80, 110), Vector2(80, 110)]))
	for i in 3:
		mp.capter_batiment("maison", Vector2i(-14, 25 + i * 26), 1)
		mp.capter_batiment("maison", Vector2i(14, 25 + i * 26), 3)
	mp.capter_batiment("ecole", Vector2i(-45, 130), 2)
	scene.rig.global_position = Vector3(0, gy, 50)
	scene.rig._target_distance = 190.0
	scene.rig.set_pitch(-52.0, true)
	await _shot(dir.path_join("mode-plan-projets.png"), 60)
	mp.valider()
	mp.set_actif(false)
	await _shot(dir.path_join("mode-plan-construit.png"), 40)
	scene.historique.annuler()
	await _shot(dir.path_join("mode-plan-annule.png"), 40)
	print("VITRINE OK")
	quit(0)
