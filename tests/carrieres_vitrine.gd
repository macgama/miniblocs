extends SceneTree
## Vitrine des carrières et des mines : carrière en gradins avec sa verse, mine
## à ciel ouvert, terril d'une mine souterraine, engins au travail, tir de mine
## et panneau P → Mines.
## Usage (avec affichage) :
##   godot --path . --rendering-driver opengl3 --script res://tests/carrieres_vitrine.gd -- --dossier /chemin/captures


func _initialize() -> void:
	_run.call_deferred()


func _tile(t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	for j in 256:
		for i in 256:
			a[i + j * 256] = 40.0 + 5.0 * sin((t.x * 256 + i) * 0.012) * cos((t.y * 256 + j) * 0.01)
	return a


func _shot(path: String, frames := 14) -> void:
	for i in frames:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(path)
	print("capture : ", path)


func _staff(pop: Population, bid: int, id: String) -> void:
	var fake := []
	for i in int(BuildingCatalog.get_type(id).get("emplois", 1)):
		fake.append(900000 + bid * 1000 + i)
	pop.by_job[bid] = fake


func _wait_terrain(world: TerrainWorld) -> void:
	for i in 2000:
		await process_frame
		if i >= 60 and world.missing_chunk_count() == 0 and world._dirty.is_empty() and world._jobs.is_empty():
			break


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
	world.tiles.offline_generator = _tile
	world.land.offline_generator = func(_lat: float, lon: float) -> int: return 60 if lon < 6.75 else 30
	world.view_radius_override = 900.0
	world.set_origin(49.15, 6.75)
	await _wait_terrain(world)
	amb.set_speed(0)
	amb.unix_time = Time.get_unix_time_from_datetime_string("2026-06-10T08:30:00")
	bs.unlimited_money = true
	var prod: Production = scene.production
	var pop: Population = scene.population
	var car: Carrieres = scene.carrieres
	var y := world.cell_height(Vector2i(0, 0))
	transport.build_segment("route", Vector3(-700, y, 0), Vector3(700, y, 0))
	var q := bs.place("carriere", Vector2i(-260, -24), bs.best_rotation("carriere", Vector2i(-260, -24)))
	var best := -1.0
	var bx := 200
	for i in 10:
		var x := 120 + i * 50
		var r := prod.carte.mean_in("charbon", Rect2i(x - 100, -330, 200, 200))
		if r > best:
			best = r
			bx = x
	var m := bs.place("mine_ciel_ouvert", Vector2i(bx, -28), bs.best_rotation("mine_ciel_ouvert", Vector2i(bx, -28)))
	var u := bs.place("mine", Vector2i(-80, 26), bs.best_rotation("mine", Vector2i(-80, 26)))
	print("carrière ", q, " mine ", m, " (charbon %.2f) mine souterraine " % best, u)
	for i in 6:
		await process_frame
	prod._sync()
	for i in 4:
		await process_frame
	for bid in [q, m, u]:
		if bid > 0:
			_staff(pop, bid, bs.buildings[bid].t)
	prod.step_hours(1.0)
	# Quelques années d'exploitation d'un coup.
	if car.sites.has(q) and car.sites[q].fosse != null:
		var f: Fosse = car.sites[q].fosse
		car._on_extrait(q, "pierre", Carrieres.reserve_de("carriere", f, float(prod.sites[q].rich)) * 0.45)
	if m > 0 and car.sites.has(m) and car.sites[m].fosse != null:
		var fm: Fosse = car.sites[m].fosse
		car._on_extrait(m, "charbon", Carrieres.reserve_de("mine_ciel_ouvert", fm, float(prod.sites[m].rich)) * 0.3)
	if u > 0 and car.sites.has(u):
		car._on_extrait(u, "charbon", 900000.0)
	car.flush()
	await _wait_terrain(world)
	var rig: Node3D = scene.get_node("CameraRig")
	var fq: Fosse = car.sites[q].fosse
	var c := fq.rect.get_center()
	rig.position = Vector3(c.x, y, c.y + 10)
	rig._target_distance = 210.0
	rig.rotation_degrees.y = 25.0
	rig.set_pitch(42.0, true)
	await _shot(dir.path_join("apercu-carriere-gradins.png"), 40)
	rig._target_distance = 90.0
	rig.position = Vector3(float(fq.front.x), y, float(fq.front.y) + 6)
	rig.set_pitch(30.0, true)
	await _shot(dir.path_join("apercu-carriere-engins.png"), 30)
	amb.unix_time = Time.get_unix_time_from_datetime_string("2026-06-10T10:00:30")
	await process_frame
	await _shot(dir.path_join("apercu-carriere-tir.png"), 12)
	if m > 0 and car.sites[m].fosse != null:
		var mc := (car.sites[m].fosse as Fosse).rect.get_center()
		rig.position = Vector3(mc.x, y, mc.y)
		rig._target_distance = 380.0
		rig.rotation_degrees.y = -20.0
		rig.set_pitch(45.0, true)
		await _shot(dir.path_join("apercu-mine-ciel-ouvert.png"), 40)
	rig.position = Vector3(c.x, y, c.y)
	rig._target_distance = 260.0
	rig.rotation_degrees.y = 25.0
	scene.production_panel.set_open(true)
	scene.production_panel.show_view("mines")
	await _shot(dir.path_join("apercu-panneau-mines.png"), 20)
	quit()
