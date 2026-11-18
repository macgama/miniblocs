extends SceneTree
## Vitrine des allées et venues : un habitant sort de chez lui (porte ouverte),
## marche jusqu'à sa voiture garée ; un autre arrive à pied à la supérette.
## Usage (avec affichage) :
##   godot --path . --rendering-driver opengl3 --script res://tests/allees_venues_vitrine.gd -- --dossier /chemin/captures


func _initialize() -> void:
	_run.call_deferred()


func _flat_tile(_t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(40.0)
	return a


func _shot(path: String) -> void:
	for i in 6:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(path)
	print("capture : ", path)


func _avancer(ps: Passants, n: int, dt: float) -> void:
	for i in n:
		ps._animer(dt)
		ps.portes.avancer(dt)


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
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.set_origin(48.8584, 2.2945)
	for i in 60:
		await process_frame
	amb.set_speed(0)
	amb.unix_time = Time.get_unix_time_from_datetime_string("2026-06-10T07:00:00")
	bs.unlimited_money = true
	var y := world.cell_height(Vector2i(0, 0))
	transport.build_segment("departementale", Vector3(0, y, -200), Vector3(0, y, 200))
	var home := bs.place("maison", Vector2i(-14, -20), 1)
	var home2 := bs.place("maison", Vector2i(-14, 0), 1)
	var shop := bs.place("superette", Vector2i(16, 0), 3)
	var pop: Population = scene.population
	pop._sync_buildings()
	var h1 := pop.spawn_household(home)
	var h2 := pop.spawn_household(home2)
	var ps := pop.passants
	ps.set_process(false)
	var day := int(pop.now().day)
	ps._h = 8.0
	ps._day = day
	var p1 := int(pop.households[h1].m[0])
	var p2 := int(pop.households[h2].m[0])
	var rig: Node3D = scene.rig
	rig.position = Vector3(-4, y, -12)
	if "_distance" in rig:
		rig._distance = 18.0
		rig._target_distance = 18.0
	for i in 20:
		await process_frame
	ps._nouveau(p1, home, shop, "voiture", 8.0, 8.3, day, 8.0)
	_avancer(ps, 12, 0.1)
	await _shot(dir.path_join("1-sortie-porte-ouverte.png"))
	_avancer(ps, 30, 0.1)
	await _shot(dir.path_join("2-vers-la-voiture.png"))
	ps._nouveau(p2, home2, shop, "pied", 8.0, 8.2, day, 8.0)
	ps._h = 8.25
	for i in 400:
		ps._animer(0.1)
		ps.portes.avancer(0.1)
		if ps.agents.has(p2) and String(ps.agents[p2].phase) == "entree" and ps.portes.portes.size() > 0:
			break
	_avancer(ps, 6, 0.1)
	rig.position = Vector3(10, y, 4)
	await _shot(dir.path_join("3-arrivee-superette.png"))
	quit(0)
