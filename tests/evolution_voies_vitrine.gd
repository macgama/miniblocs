extends SceneTree
## Vitrine « Faire évoluer une route » : une rue de quartier, puis la même rue
## devenue avenue 2 × 2 voies avec couloirs de bus et tramway au milieu ; une
## départementale passée à 2 × 2 voies ; une rue sans trottoirs.
## Usage (avec affichage) :
##   godot --path . --rendering-driver opengl3 --script res://tests/evolution_voies_vitrine.gd -- --dossier /chemin/captures


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


func _put(bs: BuildingSystem, id: String, c: Vector2i) -> int:
	var r := bs.best_rotation(id, c)
	var b := bs.place(id, c, r)
	if b < 0:
		print("refus ", id, " ", c, " : ", bs.check_place(id, c, r).reason)
	return b


func _edge_between(net: TransportNetwork, p: Vector3, q: Vector3) -> int:
	for id in net.edges:
		var e: Dictionary = net.edges[id]
		var a := net.node_pos(e.a)
		var b := net.node_pos(e.b)
		if (a.distance_to(p) < 1.0 and b.distance_to(q) < 1.0) or (a.distance_to(q) < 1.0 and b.distance_to(p) < 1.0):
			return id
	return -1


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
	world.view_radius_override = 1200.0
	world.set_origin(46.2, 6.9)
	for i in 3000:
		await process_frame
		if i >= 120 and world.missing_chunk_count() == 0 and world._dirty.is_empty() and world._jobs.is_empty():
			break
	amb.set_speed(0)
	amb.unix_time = Time.get_unix_time_from_datetime_string("2026-06-09T09:30:00")
	bs.unlimited_money = true
	# Maisons en retrait de 20 m : sans la règle d'accès à 10 m de la route.
	ReglagesPartie.actuel.acces_route = false
	bs.require_access = false
	var ev: EvolutionVoies = scene.get_node("EvolutionVoies")
	var panel: EvolutionPanel = scene.get_node("PanneauEvolution")
	var net := transport.network
	var y := world.cell_height(Vector2i(0, 0))
	# Une rue nord-sud, coupée par deux rues est-ouest.
	transport.build_segment("rue", Vector3(0, y, -160), Vector3(0, y, 160))
	transport.build_segment("rue", Vector3(-120, y, -60), Vector3(120, y, -60))
	transport.build_segment("rue", Vector3(-120, y, 60), Vector3(120, y, 60))
	# Maisons en retrait (assez de place pour élargir).
	for z in range(-140, 150, 24):
		if absi(z + 60) < 18 or absi(z - 60) < 18:
			continue
		_put(bs, "maison", Vector2i(-30, z))
		_put(bs, "maison", Vector2i(30, z))
	await process_frame
	var rig: Node3D = scene.get_node("CameraRig")
	rig.position = Vector3(0, y, 0)
	rig._target_distance = 150.0
	rig.set_pitch(48.0, true)
	rig.rotation_degrees.y = 30.0
	await _shot(dir.path_join("evolution-avant.png"))
	# Le tronçon central devient une avenue 2 × 2 voies, couloirs de bus et tram.
	var mid := _edge_between(net, Vector3(0, y, -60), Vector3(0, y, 60))
	panel.open_for(mid)
	panel._lanes.value = 2
	panel._bus.button_pressed = true
	panel._tram.button_pressed = true
	await _shot(dir.path_join("evolution-panneau.png"))
	panel._on_go()
	ev.finir_tout()
	await process_frame
	await process_frame
	var tid := ev.tram_de(mid)
	if tid >= 0:
		transport.stations.place("arret_tram", net.point_at(tid, float(net.edges[tid].len) * 0.5))
	await _shot(dir.path_join("evolution-apres.png"))
	rig.position = Vector3(0, y, 10)
	rig._target_distance = 60.0
	rig.set_pitch(35.0, true)
	await _shot(dir.path_join("evolution-apres-pres.png"))
	# Au nord : rue sans trottoirs, avec terre-plein.
	var north := _edge_between(net, Vector3(0, y, 60), Vector3(0, y, 160))
	ev.lancer(north, "rue", {"bords": "aucun", "tp": true})
	ev.finir_tout()
	rig.position = Vector3(0, y, 110)
	rig._target_distance = 70.0
	rig.set_pitch(42.0, true)
	await _shot(dir.path_join("evolution-sans-trottoirs.png"))
	quit(0)
