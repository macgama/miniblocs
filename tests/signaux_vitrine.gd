extends SceneTree
## Vitrine de la signalisation et des horaires : une voie unique entre deux
## gares avec un évitement au milieu ; deux trains s'y croisent. Captures des
## signaux de chaque époque (disques 1850, sémaphores 1900, feux BAL 1960,
## repères TVM sur LGV) et du panneau Lignes avec l'horaire ouvert.
## Usage (avec affichage) :
##   godot --path . --rendering-driver opengl3 --script res://tests/signaux_vitrine.gd -- --dossier /chemin/captures


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
	# Pas d'arbres devant l'entrée ouest de l'évitement (x = -250).
	var blk: Callable = world.tree_blocker
	world.tree_blocker = func(c: Vector2i) -> bool: return blk.call(c) or (absi(c.x + 250) < 90 and absi(c.y) < 60)
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.view_radius_override = 1200.0
	world.set_origin(46.2, 6.9)
	for i in 3000:
		await process_frame
		if i >= 120 and world.missing_chunk_count() == 0 and world._dirty.is_empty() and world._jobs.is_empty():
			break
	amb.set_speed(0)
	amb.unix_time = Time.get_unix_time_from_datetime_string("2026-06-09T08:00:00")
	bs.unlimited_money = true
	var y := world.cell_height(Vector2i(0, 0))
	var st := transport.stations
	var tr := transport.traffic
	tr.set_process(false)
	transport.build_segment("train", Vector3(-1000, y, 0), Vector3(1000, y, 0), {"tracks": 1})
	var g1 := st.place("gare", Vector3(-900, y, 0))
	var g2 := st.place("gare", Vector3(900, y, 0))
	var ev := st.creer_evitement(Vector3(0, y, 0), 500.0)
	print("évitement : ", ev.get("reason", "ok"))
	# Une LGV à côté, pour les repères TVM.
	var lgv := transport.build_segment("lgv", Vector3(-1100, y, 220), Vector3(1100, y, 220))
	print("LGV : ", lgv.get("reason", "ok"))
	var rig: Node3D = scene.get_node("CameraRig")
	var hz := st.horaires
	var ee: Dictionary = transport.network.edges[int(ev.get("edge", -1))]
	var xa := transport.network.node_pos(int(ee.a))
	var xb := transport.network.node_pos(int(ee.b))
	var X := xa if xa.x < xb.x else xb
	for era in [[1850, "vapeur_pacific", "signaux-1850-disques.png"], [1900, "vapeur_pacific", "signaux-1900-semaphores.png"],
			[1960, "regional", "signaux-1960-bal.png"]]:
		tr.signaux.annee_forcee = int(era[0])
		tr.signaux.reset(tr.vehicles)
		for lid in st.lines.keys():
			st.remove_line(lid)
		st.create_line([g1.id, g2.id], String(era[1]), 2)
		# Le train de l'est part d'abord : celui de l'ouest l'attend à l'entrée de l'évitement.
		for v in tr.vehicles:
			v.dwell = 1.0 if int(v.node) == int(st.stations[g2.id].node) else 14.0
		transport.signaux_vue.rebuild()
		var best := -1
		for i in 4000:
			tr.step(0.05)
			var pres := false
			for v in tr.vehicles:
				var p := tr.vehicle_position(v)
				if p.x < X.x + 5.0 and p.x > X.x - 140.0:
					pres = true
			if pres and i > 200:
				best = i
				break
		print("%d : arrêt de la simulation à %d" % [int(era[0]), best])
		transport.signaux_vue.maj_etats()
		rig.position = X + Vector3(6, 3, 4)
		rig._target_distance = 26.0
		rig.set_pitch(10.0, true)
		rig.rotation_degrees.y = -58.0
		await _shot(dir.path_join(String(era[2])))
	tr.signaux.annee_forcee = 1995
	transport.signaux_vue.rebuild()
	print("signaux : ", transport.signaux_vue.count())
	rig.position = Vector3(-1080, y, 220)
	rig._target_distance = 30.0
	rig.set_pitch(15.0, true)
	rig.rotation_degrees.y = -70.0
	await _shot(dir.path_join("signaux-lgv-tvm.png"))
	tr.signaux.annee_forcee = 1960
	transport.signaux_vue.rebuild()
	var lid: int = st.lines.keys()[0]
	hz.regler(lid, {"on": true, "cadence": 15, "debut": 5.5, "fin": 23.0})
	for i in 1200:
		tr.step(0.1)
	var panel: StationPanel = scene.transit_panel
	panel.set_open(true)
	panel._h_open[lid] = true
	panel._focus = lid
	panel._refresh_lines()
	rig.position = Vector3(-250, y, 0)
	rig._target_distance = 700.0
	rig.set_pitch(50.0, true)
	rig.rotation_degrees.y = 0.0
	await _shot(dir.path_join("horaires-panneau.png"))
	quit()
