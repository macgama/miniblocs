extends SceneTree
## Vitrine : pose tout le catalogue le long de deux routes et prend une capture.
## Usage (avec affichage) :
##   godot --path . --script res://tests/batiments_vitrine.gd -- --screenshot vitrine.png [--distance 220] [--yaw 30]


func _initialize() -> void:
	_run.call_deferred()


func _flat_tile(t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	for y in 256:
		for x in 256:
			var gx := t.x * 256 + x
			var gy := t.y * 256 + y
			# Légères ondulations pour voir le terrassement.
			a[y * 256 + x] = 40.0 + sin(gx * 0.05) * 1.5 + cos(gy * 0.04) * 1.5
	return a


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var shot := "vitrine.png"
	var dist := 220.0
	var yaw := 30.0
	var focus := Vector2(0, 0)
	for i in args.size():
		if args[i] == "--screenshot" and i + 1 < args.size():
			shot = args[i + 1]
		if args[i] == "--distance" and i + 1 < args.size():
			dist = args[i + 1].to_float()
		if args[i] == "--yaw" and i + 1 < args.size():
			yaw = args[i + 1].to_float()
		if args[i] == "--focus" and i + 1 < args.size():
			var p := args[i + 1].split(",")
			focus = Vector2(p[0].to_float(), p[1].to_float())

	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var transport: TransportSystem = scene.get_node("Transport")
	var bs: BuildingSystem = scene.get_node("Batiments")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.set_origin(48.8584, 2.2945)
	for i in 60:
		await process_frame
	bs.unlimited_money = true

	# Deux routes Est-Ouest ; les bâtiments s'alignent des deux côtés.
	for z in [0.0, 150.0]:
		var y := world.cell_height(Vector2i(0, int(z)))
		var rr := transport.build_segment("route", Vector3(-260, y, z), Vector3(260, y, z))
		print("route : ", rr.ok, " ", rr.get("reason", ""))
	var ids: Array = BuildingCatalog.TYPES.keys()
	var rows := [[0.0, -1.0], [0.0, 1.0], [150.0, -1.0], [150.0, 1.0]]
	var row := 0
	var x := -240.0
	for id in ids:
		var t := BuildingCatalog.get_type(id)
		var side: float = rows[row][1]
		var r := 0 if side > 0 else 2
		var fp := BuildingCatalog.footprint(id, r)
		if x + fp.x > 250.0:
			row += 1
			x = -240.0
			if row >= rows.size():
				break
			side = rows[row][1]
			r = 0 if side > 0 else 2
			fp = BuildingCatalog.footprint(id, r)
		var road_z: float = rows[row][0]
		var cz := road_z + side * (5.0 + fp.y / 2.0)
		var placed := bs.place(id, Vector2i(int(x + fp.x / 2.0), int(cz)), r)
		if placed < 0:
			print("non posé : ", id, " ", bs.check_place(id, Vector2i(int(x + fp.x / 2.0), int(cz)), r).reason)
		x += fp.x + 4.0
	print(bs.summary())

	var rig = scene.get_node("CameraRig")
	rig.position = Vector3(focus.x, 42.0, focus.y)
	rig._distance = dist
	rig._target_distance = dist
	rig.rotation_degrees.y = yaw
	for i in 90:
		await process_frame
	scene.get_node("PanneauConstruction").show_category("sport")
	for i in 5:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(shot)
	print("Capture : ", shot)
	quit(0)
