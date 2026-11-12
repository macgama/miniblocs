extends SceneTree
## Vitrine du cycle de vie : un quartier vit 60 ans (60 jours de jeu), puis
## captures : la fiche d'un habitant suivi (frise, famille, CV), la fiche d'un
## défunt et la ville (naissances, décès, mariages).
## Usage (avec affichage) :
##   godot --path . --rendering-driver opengl3 --script res://tests/cycle_vie_vitrine.gd -- --dossier /chemin/captures


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
	amb.unix_time = Time.get_unix_time_from_datetime_string("2026-03-10T09:00:00")
	bs.unlimited_money = true
	var y := world.cell_height(Vector2i(0, 0))
	transport.build_segment("departementale", Vector3(0, y, -260), Vector3(0, y, 280))
	bs.place("ecole", Vector2i(-30, 0), 1)
	for i in 6:
		bs.place("immeuble", Vector2i(16, -150 + i * 22), 3)
	for i in 6:
		bs.place("maison", Vector2i(-12, -150 + i * 16), 1)
	bs.place("bureaux", Vector2i(20, 80), 3)
	bs.place("cafe", Vector2i(-14, 60), 1)
	bs.place("gymnase", Vector2i(-24, 130), 1)
	bs.place("hopital", Vector2i(30, 250), 3)
	var pop: Population = scene.population
	pop.rng.seed = 2026
	pop._sync_buildings()
	for i in 72:
		pop.advance(300.0)
	for day in 60:
		amb.unix_time += 86400.0
		pop.advance(86400.0)
		if day % 10 == 9:
			for i in 12:
				pop.advance(300.0)
	amb.unix_time = Time.get_unix_time_from_datetime_string("2026-05-12T09:00:00") # un mardi, 10 h
	pop._now = {}
	# L'habitant le plus riche en souvenirs, né en ville.
	var star := -1
	var best := 0
	for pid in pop.persons:
		var p: Dictionary = pop.persons[pid]
		var n := (p.cv as Array).size()
		if String(p.cv[0][2]).begins_with("Naît à") and pop.stage(p) == "actif" and n > best:
			best = n
			star = pid
	if star < 0:
		star = pop.persons.keys()[0]
	pop.follow(star)
	scene.rig.position = pop.vie.position_of(star)
	scene.rig._distance = 260.0
	scene.rig._target_distance = 260.0
	var panel: HabitantsPanel = scene.habitants_panel
	panel.set_open(true)
	panel.show_view("profil", star)
	await _shot(dir.path_join("cycle-vie-fiche.png"))
	panel._scroll.scroll_vertical = 100000
	await _shot(dir.path_join("cycle-vie-cv.png"))
	var dead := -1
	best = 0
	for pid in pop.vie.archive:
		var f: Dictionary = pop.vie.archive[pid]
		if String(f.fin) == "deces" and (f.cv as Array).size() > best:
			best = (f.cv as Array).size()
			dead = pid
	panel.show_view("profil", dead)
	panel._scroll.scroll_vertical = 0
	await _shot(dir.path_join("cycle-vie-defunt.png"))
	panel.show_view("ville")
	await _shot(dir.path_join("cycle-vie-ville.png"))
	quit(0)
