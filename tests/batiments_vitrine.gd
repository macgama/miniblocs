extends SceneTree
## Vitrine : pose tout le catalogue le long de deux routes et prend une capture.
## Usage (avec affichage) :
##   godot --path . --script res://tests/batiments_vitrine.gd -- --screenshot vitrine.png [--distance 220] [--yaw 30] [--zones]
## --blocs : une maison construite bloc par bloc.
## --zones : un quartier né du zonage (routes en grille, zones R/C/I) au lieu du catalogue.


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
	var zoning := args.has("--zones")
	var bloc_mode := args.has("--blocs")
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

	if zoning or bloc_mode:
		if zoning:
			await _zoning(scene, world, transport, bs)
		else:
			_blocks_house(scene, world)
			scene.get_node("Blocs").set_tool(BlockEditor.Tool.BLOCK)
		var rig0 = scene.get_node("CameraRig")
		rig0.position = Vector3(focus.x, 42.0, focus.y)
		rig0._distance = dist
		rig0._target_distance = dist
		rig0.rotation_degrees.y = yaw
		scene.get_node("PanneauConstruction").show_category("zones" if zoning else "blocs")
		for i in 90:
			await process_frame
		root.get_viewport().get_texture().get_image().save_png(shot)
		print("Capture : ", shot)
		quit(0)
		return

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


## Quartier en grille : 3 rues Nord-Sud, 3 rues Est-Ouest, zones R, C et I.
func _zoning(scene: Node, world: TerrainWorld, transport: TransportSystem, bs: BuildingSystem) -> void:
	var zs: ZoneSystem = scene.get_node("Zones")
	zs.growth = false
	for x in [-120.0, 0.0, 120.0]:
		var y := world.cell_height(Vector2i(int(x), 0))
		transport.build_segment("route", Vector3(x, y, -180), Vector3(x, y, 180))
	for z in [-120.0, 0.0, 120.0]:
		var y := world.cell_height(Vector2i(0, int(z)))
		transport.build_segment("route", Vector3(-180, y, z), Vector3(180, y, z))
	zs.add_zone("R", Rect2i(-180, -180, 175, 175))
	zs.add_zone("R", Rect2i(5, -180, 175, 175))
	zs.add_zone("C", Rect2i(-180, 5, 175, 110))
	zs.add_zone("I", Rect2i(5, 5, 175, 175))
	# Quelques services posés à la main.
	bs.place("ecole", Vector2i(-60, 150), bs.best_rotation("ecole", Vector2i(-60, 150)))
	bs.place("parc", Vector2i(-60, -60), bs.best_rotation("parc", Vector2i(-60, -60)))
	for i in 600:
		zs.grow_step()
	await process_frame
	print(bs.summary())
	print(zs.summary())


## Petite maison en blocs : plancher, murs de brique, fenêtres, toit en tuiles, un arbre.
func _blocks_house(scene: Node, world: TerrainWorld) -> void:
	var be: BlockEditor = scene.get_node("Blocs")
	var g := world.cell_height(Vector2i(0, 0))
	var y := roundi(maxf(g, 0.0) / BlockEditor.UNIT_Y) + BlockEditor.HU
	var hu := BlockEditor.HU
	# Socle en pierre qui suit le sol.
	var base: Array = []
	for x in range(-1, 11):
		for z in range(-1, 9):
			var c := Vector2i(x, z)
			var gy := roundi(maxf(world.cell_height(c), 0.0) / BlockEditor.UNIT_Y)
			var k := Vector3i(x, gy, z)
			while k.y < y:
				base.append(k)
				k.y += hu
	be.place_blocks(base, 1)
	var floor_keys: Array = be.drag_keys(Vector3i(0, y, 0), Vector3i(9, y, 7), BlockEditor.Tool.RECT)
	be.place_blocks(floor_keys, 3)
	var walls := {}
	for x in range(0, 10):
		for z in range(0, 8):
			if x == 0 or x == 9 or z == 0 or z == 7:
				for h in range(1, 4):
					walls[Vector3i(x, y + h * hu, z)] = 5
	# Porte et fenêtres.
	walls.erase(Vector3i(4, y + hu, 0))
	walls.erase(Vector3i(4, y + 2 * hu, 0))
	for w in [Vector3i(2, y + 2 * hu, 0), Vector3i(7, y + 2 * hu, 0), Vector3i(0, y + 2 * hu, 3), Vector3i(0, y + 2 * hu, 4),
			Vector3i(9, y + 2 * hu, 3), Vector3i(9, y + 2 * hu, 4), Vector3i(3, y + 2 * hu, 7), Vector3i(6, y + 2 * hu, 7)]:
		walls[w] = 10
	for x in [0, 9]:
		for z in [0, 7]:
			for h in range(1, 4):
				walls[Vector3i(x, y + h * hu, z)] = 2
	for m in [5, 2, 10]:
		var ks: Array = []
		for k in walls:
			if walls[k] == m:
				ks.append(k)
		be.place_blocks(ks, m)
	# Toit en escalier.
	for i in 5:
		var ks: Array = be.drag_keys(Vector3i(0, y + (4 + i) * hu, i), Vector3i(9, y + (4 + i) * hu, 7 - i), BlockEditor.Tool.RECT)
		be.place_blocks(ks, 7 if i < 3 else 8)
	# Arbre.
	var ty := roundi(maxf(world.cell_height(Vector2i(14, 4)), 0.0) / BlockEditor.UNIT_Y)
	be.place_blocks(be.drag_keys(Vector3i(14, ty, 4), Vector3i(14, ty, 4), BlockEditor.Tool.WALL), 2)
	for h in range(3, 6):
		var r := 2 if h < 5 else 1
		be.place_blocks(be.drag_keys(Vector3i(14 - r, ty + h * hu, 4 - r), Vector3i(14 + r, ty + h * hu, 4 + r), BlockEditor.Tool.RECT), 13)
	print(be.summary(), " ", be.count_by_material())
