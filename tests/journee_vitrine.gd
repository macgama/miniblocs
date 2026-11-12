extends SceneTree
## Vitrine de la journée visible : le matin, les habitants partent au travail
## dans les rues ; la fiche avec les ordres ; une question du personnage principal.
## Usage (avec affichage) :
##   godot --path . --rendering-driver opengl3 --script res://tests/journee_vitrine.gd -- --dossier /chemin/captures


func _initialize() -> void:
	_run.call_deferred()


func _flat_tile(_t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(40.0)
	return a


func _shot(path: String) -> void:
	for i in 10:
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
	amb.unix_time = Time.get_unix_time_from_datetime_string("2026-03-10T07:00:00")
	bs.unlimited_money = true
	var y := world.cell_height(Vector2i(0, 0))
	transport.build_segment("departementale", Vector3(0, y, -220), Vector3(0, y, 220))
	transport.build_segment("departementale", Vector3(0, y, 0), Vector3(260, y, 0))
	for i in 8:
		bs.place("immeuble", Vector2i(-16, -200 + i * 24), 1)
	for i in 6:
		bs.place("maison", Vector2i(16, -200 + i * 18), 3)
	bs.place("bureaux", Vector2i(120, 16), 0)
	bs.place("bureaux", Vector2i(180, 16), 0)
	bs.place("ecole", Vector2i(30, 120), 3)
	bs.place("superette", Vector2i(80, -16), 2)
	var pop: Population = scene.population
	pop.rng.seed = 7
	pop._sync_buildings()
	for i in 72:
		pop.advance(300.0)
	pop.arrivals = false
	pop.follow(-1)
	# 8 h 25 : départ au travail et à l'école.
	amb.unix_time = Time.get_unix_time_from_datetime_string("2026-03-10T07:25:00")
	pop._now = {}
	scene.rig.position = Vector3(40, scene.rig.position.y, -20)
	scene.rig._distance = 95.0
	scene.rig._target_distance = 95.0
	if scene.rig.has_method("set_pitch"):
		scene.rig.set_pitch(38.0, true)
	for i in 6:
		await process_frame
	# On se place près du passant le plus central de la rue.
	var best := Vector3.ZERO
	var best_n := -1
	for pid in pop.passants.agents:
		var p: Vector3 = (pop.passants.agents[pid].body as Node3D).global_position
		var n := 0
		for q in pop.passants.agents:
			if (pop.passants.agents[q].body as Node3D).global_position.distance_to(p) < 40.0:
				n += 1
		if n > best_n:
			best_n = n
			best = p
	scene.rig.position = Vector3(best.x, scene.rig.position.y, best.z)
	scene.rig._distance = 38.0
	scene.rig._target_distance = 38.0
	await _shot(dir.path_join("journee-rue.png"))
	print("passants : ", pop.passants.agents.size())
	# Fiche avec les ordres.
	var someone := -1
	for pid in pop.passants.agents:
		someone = pid
		break
	if someone < 0:
		someone = pop.persons.keys()[0]
	var panel: HabitantsPanel = scene.habitants_panel
	panel.set_open(true)
	panel.show_view("profil", someone)
	await process_frame
	for c in panel._body.get_children():
		if c is Label and (c as Label).text == "Donner un ordre":
			panel._scroll.scroll_vertical = int((c as Control).position.y) - 20
	await _shot(dir.path_join("journee-ordres.png"))
	# Question du personnage principal.
	panel.set_open(false)
	var me := pop.principal.mine()
	if me >= 0:
		pop.persons[me].nj = pop.life_clock - 18.0 * 365.25
		pop.principal.ask_studies(pop.persons[me])
	await _shot(dir.path_join("journee-question.png"))
	quit(0)
