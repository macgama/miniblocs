extends SceneTree
## Vitrine : pose tout le catalogue le long de deux routes et prend une capture.
## Usage (avec affichage) :
##   godot --path . --script res://tests/batiments_vitrine.gd -- --screenshot vitrine.png [--distance 220] [--yaw 30] [--zones]
## --blocs : une maison construite bloc par bloc.
## --styles a,b,c : seulement les bâtiments de ces styles (bible, voir Styles.STYLES).
## --arch culte,palais : seulement ces archétypes. --zone-style japonais : style du zonage.
## --cat espaces : seulement une catégorie.
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
	var bloc_mode := args.has("--blocs") or args.has("--maison") or args.has("--murs")
	var maison := args.has("--maison") or args.has("--murs")
	var murs := args.has("--murs")
	var coupe := -100
	var pitch := -1.0
	var only_styles: PackedStringArray = []
	var only_archs: PackedStringArray = []
	var zone_style := ""
	var only_cat := ""
	for i in args.size():
		if args[i] == "--screenshot" and i + 1 < args.size():
			shot = args[i + 1]
		if args[i] == "--distance" and i + 1 < args.size():
			dist = args[i + 1].to_float()
		if args[i] == "--yaw" and i + 1 < args.size():
			yaw = args[i + 1].to_float()
		if args[i] == "--styles" and i + 1 < args.size():
			only_styles = args[i + 1].split(",")
		if args[i] == "--arch" and i + 1 < args.size():
			only_archs = args[i + 1].split(",")
		if args[i] == "--cat" and i + 1 < args.size():
			only_cat = args[i + 1]
		if args[i] == "--zone-style" and i + 1 < args.size():
			zone_style = args[i + 1]
		if args[i] == "--pitch" and i + 1 < args.size():
			pitch = args[i + 1].to_float()
		if args[i] == "--coupe" and i + 1 < args.size():
			coupe = args[i + 1].to_int()
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
			scene.get_node("Zones").current_style = zone_style
			await _zoning(scene, world, transport, bs)
		else:
			if murs:
				_murs(scene, world, coupe)
			elif maison:
				_maison(scene, world)
			else:
				_blocks_house(scene, world)
			if not murs:
				scene.get_node("Blocs").set_tool(BlockEditor.Tool.BLOCK)
		var rig0 = scene.get_node("CameraRig")
		rig0.position = Vector3(focus.x, 42.0, focus.y)
		rig0._distance = dist
		rig0._target_distance = dist
		rig0.rotation_degrees.y = yaw
		if pitch > 0.0 and "pitch_degrees" in rig0:
			rig0.pitch_degrees = pitch
		scene.get_node("PanneauConstruction").show_category("zones" if zoning else "blocs")
		if maison:
			scene.get_node("PanneauConstruction").visible = not args.has("--sans-panneau")
			if murs and not args.has("--sans-panneau"):
				scene.get_node("PanneauConstruction").set_open(true)
			if args.has("--defiler"):
				for i in 3:
					await process_frame
				for sc in scene.get_node("PanneauConstruction").find_children("*", "ScrollContainer", true, false):
					(sc as ScrollContainer).scroll_vertical = 260
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
	var ids: Array = []
	for id in BuildingCatalog.all_types():
		var tt := BuildingCatalog.get_type(id)
		if not only_styles.is_empty() and not String(tt.get("style", "")) in only_styles:
			continue
		if not only_archs.is_empty() and not String(tt.get("arch", "")) in only_archs:
			continue
		if only_cat != "" and String(tt.cat) != only_cat:
			continue
		ids.append(id)
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
		var cz := road_z + side * (7.0 + fp.y / 2.0)
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
	scene.get_node("PanneauConstruction").show_category(only_cat if only_cat != "" else "sport")
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


## Murs fins et étages : une maison de deux niveaux avec sous-sol et toit,
## et un immeuble de 12 étages. coupe ≥ 0 : vue en coupe à cet étage de la maison.
func _murs(scene: Node, world: TerrainWorld, coupe: int) -> void:
	var pe: PlanEditor = scene.get_node("Plans")
	var id := pe.new_plan(pe.ground_level(Vector2i(2, 2)))
	pe.set_material(27) # Crépi ocre
	pe.add_room(id, Rect2i(0, 0, 10, 8), 0)
	pe.add_walls(id, PlanEditor.wall_line(Vector2i(6, 0), Vector2i(6, 8), 0))
	pe.add_walls(id, PlanEditor.wall_line(Vector2i(0, 5), Vector2i(6, 5), 0))
	pe.set_material(57)
	pe.set_opening_at(id, Vector4i(2, 0, 0, 0), "porte")
	for x in [4, 8]:
		pe.set_opening_at(id, Vector4i(x, 0, 0, 0), "fenetre")
	pe.set_opening_at(id, Vector4i(1, 0, 8, 0), "fenetre")
	pe.set_opening_at(id, Vector4i(7, 0, 8, 0), "porte_fenetre")
	pe.set_opening_at(id, Vector4i(8, 0, 8, 0), "baie")
	pe.set_opening_at(id, Vector4i(6, 0, 3, 1), "passage")
	pe.set_opening_at(id, Vector4i(3, 0, 5, 0), "porte")
	pe.toggle_door(id, Vector4i(3, 0, 5, 0))
	pe.set_opening_at(id, Vector4i(0, 0, 2, 1), "fenetre_haute")
	pe.set_opening_at(id, Vector4i(10, 0, 4, 1), "fenetre")
	# Intérieur : carrelage dans la cuisine, murs intérieurs blancs, parquet foncé au salon.
	pe.set_material(37)
	pe.paint_rect(id, Rect2i(0, 5, 6, 3), 0)
	pe.set_material(36)
	pe.paint_rect(id, Rect2i(6, 0, 4, 8), 0)
	pe.set_material(55)
	pe.tint = 0
	for k in pe.plans[id].walls.keys():
		var kw: Vector4i = k
		var cs := PlanEditor.wall_cells(kw)
		var r := Rect2i(0, 0, 10, 8)
		if r.has_point(cs[0]) and r.has_point(cs[1]):
			pe.paint_wall(id, kw, "a")
			pe.paint_wall(id, kw, "b")
	pe.add_stairs(id, Vector2i(5, 1), 0, 0)
	pe.copy_level_up(id, 0, 1)
	# À l'étage, la porte d'entrée devient une fenêtre.
	pe.set_material(57)
	pe.set_opening_at(id, Vector4i(2, 1, 0, 0), "fenetre")
	pe.plans[id].stairs.erase(Vector3i(5, 1, 1))
	pe.set_material(4)
	pe.add_room(id, Rect2i(1, 1, 5, 4), -1)
	pe.set_material(7)
	pe.add_roof(id, "deux_pans")
	# Immeuble : un étage type recopié 11 fois, toit plat.
	var id2 := pe.new_plan(pe.ground_level(Vector2i(24, 4)))
	pe.set_material(23) # Béton brut
	pe.add_room(id2, Rect2i(20, -2, 8, 10), 0)
	pe.set_material(9)
	for x in range(20, 28):
		pe.set_opening_at(id2, Vector4i(x, 0, -2, 0), "vitrine" if x != 23 else "porte_vitree")
	for z in range(-2, 8):
		pe.set_opening_at(id2, Vector4i(28, 0, z, 1), "vitrine")
	pe.add_stairs(id2, Vector2i(21, 3), 0, 0)
	pe.copy_level_up(id2, 0, 1)
	pe.set_material(57)
	for x in range(20, 28):
		pe.set_opening_at(id2, Vector4i(x, 1, -2, 0), "fenetre")
		pe.set_opening_at(id2, Vector4i(x, 1, 8, 0), "fenetre")
	for z in range(-2, 8):
		pe.set_opening_at(id2, Vector4i(28, 1, z, 1), "fenetre")
	pe.copy_level_up(id2, 1, 10)
	pe.set_material(4)
	pe.add_roof(id2, "plat")
	pe.flush()
	if coupe > -100:
		pe._active = id
		pe.level = coupe
		pe.set_tool(PlanEditor.Tool.WALL)
		pe.flush()


## Petite maison en blocs : plancher, murs de brique, fenêtres, toit en tuiles, un arbre.
## Maison réaliste : formes, textures, portes et fenêtres de l'éditeur libre.
func _maison(scene: Node, world: TerrainWorld) -> void:
	var be: BlockEditor = scene.get_node("Blocs")
	var F := BlocFormes
	var S := BlocFormes.S
	var hu := BlockEditor.HU
	var g := world.cell_height(Vector2i(4, 3))
	var y := roundi(maxf(g, 0.0) / BlockEditor.UNIT_Y) + hu
	var put := func(keys: Array, code: int) -> void: be.place_blocks(keys, code)
	# Socle en pierre de taille qui suit le sol.
	var base: Array = []
	for x in range(-1, 11):
		for z in range(-2, 9):
			var gy := roundi(maxf(world.cell_height(Vector2i(x, z)), 0.0) / BlockEditor.UNIT_Y)
			var k := Vector3i(x, gy, z)
			while k.y < y:
				base.append(k)
				k.y += hu
	put.call(base, F.encode(16))
	put.call(be.drag_keys(Vector3i(1, y, 1), Vector3i(8, y, 6), BlockEditor.Tool.RECT), F.encode(35))
	var ring: Array = []
	for x in range(0, 10):
		for z in range(0, 8):
			if x == 0 or x == 9 or z == 0 or z == 7:
				ring.append(Vector3i(x, y, z))
	put.call(ring, F.encode(16))
	# Murs en crépi ocre, chaînages d'angle en pierre.
	var walls: Array = []
	var corners: Array = []
	for x in range(0, 10):
		for z in range(0, 8):
			if x == 0 or x == 9 or z == 0 or z == 7:
				for h in range(1, 4):
					var k := Vector3i(x, y + h * hu, z)
					if (x == 0 or x == 9) and (z == 0 or z == 7):
						corners.append(k)
					else:
						walls.append(k)
	var holes := {}
	var openings := [
		[Vector3i(4, y + hu, 0), F.encode(2, S.DOOR, 0, 4)],
		[Vector3i(2, y + 2 * hu, 0), F.encode(58, S.WINDOW_SHUTTERS, 0, 8)],
		[Vector3i(7, y + 2 * hu, 0), F.encode(58, S.WINDOW_SHUTTERS, 0, 8)],
		[Vector3i(0, y + 2 * hu, 3), F.encode(58, S.WINDOW, 3)],
		[Vector3i(0, y + 2 * hu, 5), F.encode(58, S.WINDOW, 3)],
		[Vector3i(9, y + hu, 3), F.encode(9, S.DOOR_GLASS, 1, 3)],
		[Vector3i(3, y + hu, 7), F.encode(9, S.BAY, 2, 3)], [Vector3i(4, y + hu, 7), F.encode(9, S.BAY, 2, 3)],
		[Vector3i(3, y + 2 * hu, 7), F.encode(9, S.BAY, 2, 3)], [Vector3i(4, y + 2 * hu, 7), F.encode(9, S.BAY, 2, 3)],
	]
	for o in openings:
		holes[o[0]] = true
		if F.cells(F.shape_of(o[1])) == 2:
			holes[o[0] + Vector3i(0, hu, 0)] = true
	put.call(walls.filter(func(k: Vector3i) -> bool: return not holes.has(k)), F.encode(27))
	put.call(corners, F.encode(16))
	for o in openings:
		put.call([o[0]], o[1])
	# Toit à deux pans en tuiles, débord de 1 m, pignons en crépi.
	for i in 4:
		var lv := y + (4 + i) * hu
		var front: Array = []
		var back: Array = []
		for x in range(-1, 11):
			front.append(Vector3i(x, lv, i - 1 + 1))
			back.append(Vector3i(x, lv, 7 - i))
		put.call(front, F.encode(7, S.SLOPE, 0))
		put.call(back, F.encode(7, S.SLOPE, 2))
		var gable: Array = []
		for z in range(i + 1, 7 - i):
			gable.append(Vector3i(0, lv, z))
			gable.append(Vector3i(9, lv, z))
		put.call(gable, F.encode(27))
	be.remove_blocks([Vector3i(6, y + 5 * hu, 1)])
	put.call([Vector3i(6, y + 5 * hu, 1)], F.encode(7, S.SKYLIGHT, 0))
	# Cheminée en brique.
	var chim: Array = []
	for h in range(4, 10):
		var k := Vector3i(7, y + h * hu, 5)
		if be.blocks.has(k):
			be.remove_blocks([k])
		chim.append(k)
	put.call(chim, F.encode(0))
	# Perron : marches, colonnes et auvent en zinc.
	put.call([Vector3i(2, y, -1), Vector3i(3, y, -1), Vector3i(5, y, -1), Vector3i(6, y, -1)], F.encode(16))
	put.call([Vector3i(4, y, -1)], F.encode(16, S.STAIRS, 0))
	for x in [3, 5]:
		put.call([Vector3i(x, y + hu, -1), Vector3i(x, y + 2 * hu, -1)], F.encode(5, S.COLUMN))
	put.call(be.drag_keys(Vector3i(2, y + 3 * hu, -1), Vector3i(6, y + 3 * hu, -1), BlockEditor.Tool.RECT), F.encode(46, S.SLAB))
	# Clôture blanche.
	var fence: Array = []
	for x in range(-2, 12):
		if x == 4:
			continue
		var gy := roundi(maxf(world.cell_height(Vector2i(x, -4)), 0.0) / BlockEditor.UNIT_Y)
		fence.append(Vector3i(x, gy, -4))
	put.call(fence, F.encode(58, S.FENCE, 0))
	# Allée en pavés.
	for z in range(-4, -1):
		var gy := roundi(maxf(world.cell_height(Vector2i(4, z)), 0.0) / BlockEditor.UNIT_Y)
		put.call([Vector3i(4, gy, z)], F.encode(21, S.FLOOR_THIN))
	be.toggle_open(Vector3i(9, y + hu, 3))


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
