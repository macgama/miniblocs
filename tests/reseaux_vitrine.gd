extends SceneTree
## Vitrine des réseaux : un quartier le long d'une route, une petite centrale au
## charbon reliée par une ligne haute tension, un hameau desservi par une ligne
## moyenne tension, un forage et une station d'épuration ; puis le calque
## électricité (un quartier coupé en rouge) et le panneau Réseaux (O).
## Usage (avec affichage) :
##   godot --path . --rendering-driver opengl3 --script res://tests/reseaux_vitrine.gd -- --dossier /chemin/captures


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


func _place(bs: BuildingSystem, id: String, x: int, side := -1, road_z := 0) -> int:
	var d := int(BuildingCatalog.get_type(id).d)
	var c := Vector2i(x, road_z + side * (d / 2 + 6))
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
	ReglagesPartie.actuel.construction_instantanee = true
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var transport: TransportSystem = scene.get_node("Transport")
	var bs: BuildingSystem = scene.get_node("Batiments")
	var amb: DayNight = scene.get_node("Ambiance")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 40
	world.view_radius_override = 900.0
	world.set_origin(46.2, 6.9)
	for i in 150:
		await process_frame
	amb.set_speed(0)
	amb.unix_time = Time.get_unix_time_from_datetime_string("2026-06-10T15:00:00")
	bs.unlimited_money = true
	var res: Reseaux = scene.reseaux
	var pop: Population = scene.population
	var y := world.cell_height(Vector2i(0, 0))
	transport.build_segment("route", Vector3(-260, y, 0), Vector3(260, y, 0))
	for i in 10:
		_place(bs, "maison", -240 + i * 22, 1)
	for i in 4:
		_place(bs, "immeuble", -60 + i * 30, -1)
	_place(bs, "forage_eau", 100, -1)
	_place(bs, "station_epuration_locale", 160, 1)
	_place(bs, "poste_gaz", 220, -1)
	# Centrale au loin, sur sa propre route, reliée par une ligne HT.
	transport.build_segment("route", Vector3(-200, y, -520), Vector3(220, y, -520))
	var cent := _place(bs, "centrale_charbon_locale", -60, 1, -520)
	_place(bs, "centrale_solaire", 120, 1, -520)
	var pc: Vector3 = BuildingSystem.rect_center(bs._rect_of(bs.buildings[cent]))
	res.poser("ligne_ht", res.trace_sur_relief(Vector3(pc.x, y, pc.z), Vector3(200, y, 0)), false)
	# Hameau isolé au sud, ligne MT depuis la route.
	transport.build_segment("route", Vector3(-80, y, 320), Vector3(80, y, 320))
	for i in 3:
		_place(bs, "maison", -40 + i * 30, 1, 320)
	res.poser("ligne_mt", res.trace_sur_relief(Vector3(-120, y, 0), Vector3(-60, y, 320)), false)
	# Quartier coupé : route à part, sans ligne.
	transport.build_segment("route", Vector3(320, y, 160), Vector3(460, y, 160))
	for i in 4:
		_place(bs, "maison", 340 + i * 30, 1, 160)
	if SuiviChantiers.instance:
		SuiviChantiers.instance.terminer_tout()
	await process_frame
	pop._sync_buildings()
	pop.follow_camera = false
	for i in 40:
		pop.advance(300.0)
	# La centrale a besoin de charbon : on lui en donne pour la vitrine.
	scene.production._sync()
	if scene.production.sites.has(cent):
		scene.production.sites[cent].st["charbon"] = 500.0
		scene.production.step_hours(1.0)
	res.simuler(0.0)
	pop.vie.follow(-1)
	pop.follow_camera = false
	var rig: Node3D = scene.get_node("CameraRig")
	rig.position = Vector3(110, y, -280)
	rig._target_distance = 110.0
	rig.set_pitch(14.0, true)
	rig.rotation_degrees.y = -40.0
	await _shot(dir.path_join("reseaux-ligne-ht.png"))
	rig.position = Vector3(-85, y, 200)
	rig._target_distance = 90.0
	rig.set_pitch(14.0, true)
	rig.rotation_degrees.y = 100.0
	await _shot(dir.path_join("reseaux-ligne-mt.png"))
	res.vue.set_calque("elec", true)
	rig.position = Vector3(60, y, -60)
	rig._target_distance = 650.0
	rig.set_pitch(60.0, true)
	rig.rotation_degrees.y = 0.0
	await _shot(dir.path_join("reseaux-calque.png"))
	scene.reseaux_panel.set_open(true)
	scene.reseaux_panel.show_view("elec")
	await _shot(dir.path_join("reseaux-panneau.png"))
	# Chauffage par grand froid.
	res.temperature_forcee = -4.0
	res.simuler(0.0)
	scene.reseaux_panel.show_view("gaz")
	await _shot(dir.path_join("reseaux-chauffage.png"))
	# Sécheresse et restrictions.
	res.temperature_forcee = 31.0
	res.incidents.forcer_secheresse(36.0)
	res.incidents.restrictions = true
	res.simuler(0.0)
	scene.reseaux_panel.show_view("eau")
	await _shot(dir.path_join("reseaux-secheresse.png"))
	# Une tempête abat la ligne haute tension.
	scene.reseaux_panel.set_open(false)
	res.vue.set_calque("eau", false)
	var lht: int = res.elec.troncons.keys()[0]
	var pts: PackedVector3Array = res.elec.troncons[lht].pts
	var mid := pts[pts.size() / 2]
	res.endommager(mid, 30.0, "tempete")
	res.simuler(0.0)
	await process_frame
	res.vue._process(2.0)
	rig.position = Vector3(mid.x + 20, y, mid.z + 10)
	rig._target_distance = 110.0
	rig.set_pitch(18.0, true)
	rig.rotation_degrees.y = -40.0
	await _shot(dir.path_join("reseaux-panne.png"))
	quit()
