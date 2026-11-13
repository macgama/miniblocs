extends SceneTree
## Vitrine de l'avis des habitants : une petite ville avec sa mairie, puis des
## captures du panneau Avis (thèmes, quartiers, paroles, campagne électorale,
## manifestation) et du cortège devant la mairie.
## Usage (avec affichage) :
##   godot --path . --script res://tests/avis_vitrine.gd -- --dossier captures/avis


class SourceDemo extends Node:
	func avis_facteurs() -> Array:
		return [{"id": "demo_bruit", "theme": "environnement", "f": func(p: Dictionary) -> Array:
					return [-16.0, ["− trop de bruit la nuit"]] if int(p.id) % 3 != 0 else [-4.0, ["− un peu de bruit"]]},
			{"id": "demo_bus", "theme": "transports", "f": func(p: Dictionary) -> Array:
					return [-8.0, ["− bus bondés"]] if int(p.id) % 2 == 0 else [4.0, ["+ arrêt de bus tout près"]]}]


func _initialize() -> void:
	_run.call_deferred()


func _flat_tile(_t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(40.0)
	return a


func _put(bs: BuildingSystem, id: String, from: int, h := false, zr := 0, sides := [1, -1]) -> int:
	for k in range(from, from + 400, 4):
		for side in sides:
			for r in 4:
				var fp := BuildingCatalog.footprint(id, r)
				for gap in [3, 6, 9]:
					var c := Vector2i(int(side) * (fp.x / 2 + gap), k)
					if h:
						c = Vector2i(k, zr + int(side) * (fp.y / 2 + gap))
					if bs.check_place(id, c, r).ok:
						return bs.place(id, c, r)
	print("non posé : ", id)
	return -1


func _cam(rig: Node3D, p: Vector3, dist: float, yaw: float, pitch: float) -> void:
	rig.position = p
	rig._distance = dist
	rig._target_distance = dist
	rig.rotation_degrees.y = yaw
	rig.set_pitch(pitch, true)


func _shot(dir: String, name: String) -> void:
	for i in 40:
		await process_frame
	var path := dir.path_join("avis-%s.png" % name)
	root.get_viewport().get_texture().get_image().save_png(path)
	print("Capture : ", path)


func _hours(scene: Node, n: int, step := 3600.0) -> void:
	var amb: DayNight = scene.get_node("Ambiance")
	for i in n:
		amb.unix_time += step
		scene.population._process(0.016)
		scene.evenements._process(0.016)
		scene.avis._process(0.016)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var dir := "."
	for i in args.size():
		if args[i] == "--dossier" and i + 1 < args.size():
			dir = args[i + 1]
	DirAccess.make_dir_recursive_absolute(dir)
	Creations.persist = false
	BatimentsVie.chantiers = false
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var transport: TransportSystem = scene.get_node("Transport")
	var bs: BuildingSystem = scene.get_node("Batiments")
	var amb: DayNight = scene.get_node("Ambiance")
	var rig: Node3D = scene.get_node("CameraRig")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.set_origin(46.5197, 6.6323)
	GameStart.place_name = "Lausanne"
	for i in 60:
		await process_frame
	var ev: Evenements = scene.evenements
	var pop: Population = scene.population
	var avis: Avis = scene.avis
	ev.forcer_auto = 0
	ev.forcer_catastrophes = 0
	avis.manifs.forcer = 0
	amb.set_speed(0)
	amb.weather.mode = Meteo.Mode.SOLEIL
	amb.unix_time = Time.get_unix_time_from_datetime_string("2026-09-08T08:00:00")
	bs.unlimited_money = true
	var y := world.cell_height(Vector2i(0, 0))
	transport.build_segment("route", Vector3(0, y, -300), Vector3(0, y, 300))
	transport.build_segment("route", Vector3(0, y, 0), Vector3(-400, y, 0))
	for i in 10:
		_put(bs, "maison", -230 + i * 16, false, 0, [1])
		_put(bs, "maison", -230 + i * 16, false, 0, [-1])
	for i in 3:
		_put(bs, "immeuble", -300 + i * 30, true, 0, [-1])
	_put(bs, "boulangerie", -200, true, 0, [1])
	_put(bs, "cafe", -170, true, 0, [1])
	_put(bs, "ecole", 30, false, 0, [-1])
	_put(bs, "bureaux", 60, false, 0, [1])
	var mairie := _put(bs, "mairie", -120, true, 0, [1])
	pop._sync_buildings()
	for i in 72:
		pop.advance(300.0)
	scene.get_node("PanneauConstruction").set_open(false)
	var src := SourceDemo.new()
	src.add_to_group("avis_sources")
	scene.add_child(src)
	# Quelques jours de sondages pour la courbe.
	_hours(scene, 24 * 6)
	amb.set_local_hour(11.0)
	var panel: AvisPanel = scene.avis_panel
	panel.set_open(true)
	_cam(rig, Vector3(-60, y, -60), 260.0, 30.0, 50.0)
	panel.show_view("avis")
	await _shot(dir, "panneau")
	panel.show_view("paroles")
	await _shot(dir, "paroles")
	scene.avis_carte.set_on(true)
	panel.show_view("quartiers")
	await _shot(dir, "carte")
	scene.avis_carte.set_on(false)
	# Campagne électorale.
	avis.elections.anticiper()
	avis.elections.promettre("transports")
	avis.elections.promettre("environnement")
	panel.show_view("elections")
	await _shot(dir, "campagne")
	# Manifestation devant la mairie.
	var mid := avis.manifs.annoncer("environnement", true)
	_hours(scene, 1, 1200.0)
	_hours(scene, 2, 600.0)
	var m: Dictionary = avis.manifs.liste[mid]
	var node: Node3D = avis.manifs._nodes.get(mid, null)
	panel.show_view("manifs")
	amb.set_local_hour(15.2)
	if node != null:
		_cam(rig, node.position, 34.0, 200.0, 24.0)
	else:
		_cam(rig, m.pos, 40.0, 200.0, 26.0)
	await _shot(dir, "manif-panneau")
	panel.set_open(false)
	await _shot(dir, "manif")
	print("VITRINE OK")
	quit()
