extends SceneTree
## Vitrine de la pollution, du bruit et de la valeur des terrains : une petite
## ville entre une aciérie et un parc, une autoroute au sud, et les cartes du
## panneau Cartes (touche N) : air, bruit la nuit, valeur du terrain, loyers.
## Usage (avec affichage) :
##   godot --path . --rendering-driver opengl3 --script res://tests/nuisances_vitrine.gd -- --dossier /chemin/captures


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


func _place(bs: BuildingSystem, id: String, x: int, z: int, north := true) -> int:
	var d := int(BuildingCatalog.get_type(id).d)
	var c := Vector2i(x, z - (d / 2 + 6) if north else z + d / 2 + 6)
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
	ReglagesPartie.actuel = ReglagesPartie.preset("normal")
	ReglagesPartie.actuel.construction_instantanee = true
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var transport: TransportSystem = scene.get_node("Transport")
	var bs: BuildingSystem = scene.get_node("Batiments")
	var amb: DayNight = scene.get_node("Ambiance")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, lon: float) -> int: return 10 if lon > 6.907 else 40
	world.view_radius_override = 900.0
	world.set_origin(46.2, 6.9)
	for i in 3000:
		await process_frame
		if i >= 150 and world.missing_chunk_count() == 0 and world._dirty.is_empty() and world._jobs.is_empty():
			break
	amb.set_speed(0)
	amb.unix_time = Time.get_unix_time_from_datetime_string("2026-06-10T09:00:00")
	bs.unlimited_money = true
	var y := world.cell_height(Vector2i(0, 0))
	for z in [0, 160]:
		transport.build_segment("rue", Vector3(-620, y, z), Vector3(620, y, z))
	transport.build_segment("departementale", Vector3(-620, y, -200), Vector3(620, y, -200))
	transport.build_segment("autoroute", Vector3(-700, y, 420), Vector3(700, y, 420))
	_place(bs, "acierie", -460, -200)
	_place(bs, "usine", -300, -200)
	_place(bs, "parc", 420, 0)
	_place(bs, "parc", 470, 160, false)
	for x in range(-560, 600, 26):
		_place(bs, "maison" if x > 0 else "immeuble", x, 0, false)
		_place(bs, "villa" if x > 250 else "maison", x, 160)
	for i in 30:
		await process_frame
	var pop: Population = scene.population
	pop._sync_buildings()
	for i in 40:
		pop.advance(3600.0)
	var nz: Nuisances = scene.nuisances
	nz.recalculer()
	for i in 10:
		nz.jour_suivant()
	var rig: Node3D = scene.get_node("CameraRig")
	rig.position = Vector3(0, y, 80)
	rig._target_distance = 800.0
	rig.set_pitch(52.0, true)
	rig.rotation_degrees.y = 0.0
	pop.follow(-1)
	var panel: CartesPanel = scene.cartes_panel
	panel.set_open(true)
	for spec in [["nuisances_air", "nuisances-air.png"], ["nuisances_nuit", "nuisances-bruit-nuit.png"],
			["immobilier_valeur", "nuisances-valeur.png"], ["immobilier_loyers", "nuisances-loyers.png"]]:
		Calques.afficher(spec[0], true)
		panel.refresh()
		await _shot(dir.path_join(spec[1]))
	quit(0)
