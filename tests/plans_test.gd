extends SceneTree
## Test des murs fins, étages, sous-sols et intérieurs (éditeur libre, mode
## « Murs et étages »), sans réseau.
## Usage : godot --headless --path . --script res://tests/plans_test.gd

var ok := true


func _initialize() -> void:
	_run.call_deferred()


func _check(cond: bool, what: String) -> void:
	if not cond:
		push_error("ÉCHEC : " + what)
		ok = false
	else:
		print("  ok  ", what)


## Plaine en pente douce vers l'Est.
func _fake_tile(t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	for y in 256:
		for x in 256:
			var gx := t.x * 256 + x
			a[y * 256 + x] = 40.0 + float(gx - 4_247_700) * 0.6
	return a


func _run() -> void:
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var bs: BuildingSystem = scene.get_node("Batiments")
	var transport: TransportSystem = scene.get_node("Transport")
	root.add_child(scene)
	world.tiles.offline_generator = _fake_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.set_origin(48.8584, 2.2945)
	for i in 90:
		await process_frame
	var pe: PlanEditor = scene.get_node("Plans")
	var be: BlockEditor = scene.get_node("Blocs")
	_check(pe != null and pe.world != null and pe.blocks == be, "éditeur de murs créé et relié")
	bs.unlimited_money = false
	bs.money = 1_000_000

	print("Pièce et murs :")
	var c0 := Vector2i(40, 40)
	var y0 := pe.ground_level(c0)
	_check(fmod(y0, 0.5) == 0.0 and absf(y0 - world.cell_height(c0)) < 0.26, "plancher du rez-de-chaussée au ras du sol : porte de plain-pied (%.1f m, sol %.1f m)" % [y0, world.cell_height(c0)])
	var id := pe.new_plan(y0)
	var room := Rect2i(40, 40, 6, 5)
	var m0 := bs.money
	_check(pe.add_room(id, room, 0), "pièce de 6 × 5 m posée")
	var p: Dictionary = pe.plans[id]
	_check(p.walls.size() == 22 and p.floors.size() == 30, "22 m de murs sur les lignes et 30 m² de plancher")
	_check(bs.money < m0, "pièce payée : %s" % BuildingSystem.format_money(m0 - bs.money))
	_check(p.walls.has(Vector4i(40, 0, 40, 0)) and p.walls.has(Vector4i(46, 0, 42, 1)), "murs sur les deux lignes du contour")
	# Une cloison au milieu : elle ne prend aucune case.
	var n := pe.add_walls(id, PlanEditor.wall_line(Vector2i(43, 40), Vector2i(43, 45), 0))
	_check(n == 5 and p.floors.size() == 30, "cloison de 5 m posée sur la ligne x = 43, les cases restent des cases")
	_check(pe.add_walls(id, PlanEditor.wall_line(Vector2i(43, 40), Vector2i(43, 45), 0)) == 0, "pas deux murs au même endroit")

	print("Ouvertures et peinture :")
	_check(pe.set_opening_at(id, Vector4i(41, 0, 40, 0), "porte"), "porte d'entrée")
	_check(pe.set_opening_at(id, Vector4i(44, 0, 40, 0), "fenetre"), "fenêtre")
	_check(pe.set_opening_at(id, Vector4i(43, 0, 42, 1), "passage"), "passage dans la cloison")
	_check(pe.toggle_door(id, Vector4i(41, 0, 40, 0)) and bool(p.walls[Vector4i(41, 0, 40, 0)].op), "porte ouverte")
	_check(not pe.toggle_door(id, Vector4i(44, 0, 40, 0)), "une fenêtre ne s'ouvre pas comme une porte")
	pe.set_material(37) # Carrelage blanc
	pe.paint_wall(id, Vector4i(40, 0, 41, 1), "b")
	var w: Dictionary = p.walls[Vector4i(40, 0, 41, 1)]
	_check(BlocFormes.mat_of(int(w.b)) == 37 and BlocFormes.mat_of(int(w.a)) != 37, "un seul côté du mur repeint (l'intérieur)")
	pe.set_material(39)
	var np := pe.paint_rect(id, Rect2i(40, 40, 3, 5), 0)
	_check(np > 0 and BlocFormes.mat_of(int(p.floors[Vector3i(41, 0, 42)].t)) == 39, "pièce de gauche : sol en tomettes")
	_check(BlocFormes.mat_of(int(p.floors[Vector3i(44, 0, 42)].t)) != 39, "pièce de droite intacte")
	pe.set_material(5)

	print("Étages, escalier, sous-sol :")
	_check(pe.add_stairs(id, Vector2i(45, 41), 0, 0), "escalier de 4 cases vers le 1er étage")
	_check(pe.copy_level_up(id, 0, 3) == 3, "rez-de-chaussée recopié sur 3 étages")
	_check(pe.levels_of(id) == [0, 1, 2, 3], "4 niveaux : %s" % str(pe.levels_of(id)))
	_check(pe._stair_hole(p, Vector3i(45, 1, 43)) and not pe._stair_hole(p, Vector3i(45, 1, 41)), "trémie au-dessus de l'escalier")
	var hb := world.cell_height(Vector2i(42, 42))
	_check(pe.add_room(id, Rect2i(41, 41, 3, 3), -1), "sous-sol de 3 × 3 m")
	var hd := world.cell_height(Vector2i(42, 42))
	_check(hd <= pe.base_y(id, -1) - PlanEditor.SLAB + 0.001 and hd < hb, "terrain creusé sous le sous-sol (%.1f → %.1f m)" % [hb, hd])
	pe.flush()
	var nodes: Dictionary = pe._nodes[id]
	_check(nodes.size() == 5, "5 étages affichés")
	var mi: MeshInstance3D = (nodes[0] as Node).get_child(0)
	_check(mi.mesh != null and mi.mesh.get_surface_count() == 2, "rez-de-chaussée : surfaces opaques et vitrées")
	var has_body := false
	for c in (nodes[0] as Node).get_children():
		if c is StaticBody3D:
			has_body = true
	_check(has_body, "collisions des murs, sols et de la rampe d'escalier")
	for i in 3:
		await physics_frame
	var space := (scene as Node3D).get_world_3d().direct_space_state
	var by := pe.base_y(id, 0)
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(45.5, by + 2.6, 43.0), Vector3(45.5, by - 1.0, 43.0)))
	_check(not hit.is_empty() and absf(float(hit.position.y) - (by + 1.5)) < 0.1, "rampe d'escalier à mi-hauteur au milieu de l'escalier (%s)" % str(hit.get("position", "rien")))
	var hit2 := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(41.5, by + 1.0, 39.0), Vector3(41.5, by + 1.0, 42.0)))
	_check(hit2.is_empty() or float(hit2.position.z) > 41.0, "porte ouverte : on entre")
	var hit3 := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(40.5, by + 1.0, 39.0), Vector3(40.5, by + 1.0, 42.0)))
	_check(not hit3.is_empty() and absf(float(hit3.position.z) - (40.0 - PlanEditor.HALF)) < 0.02, "le mur arrête à 10 cm de la ligne")

	print("Vue en coupe :")
	pe._active = id
	pe.level = 1
	pe.set_tool(PlanEditor.Tool.WALL)
	_check((nodes[1] as Node3D).visible and not (nodes[2] as Node3D).visible and not (nodes[3] as Node3D).visible, "étages au-dessus du 1er masqués")
	pe.set_tool(PlanEditor.Tool.NONE)
	_check((nodes[3] as Node3D).visible, "tout réapparaît quand l'outil est rangé")

	print("Toit :")
	var nb0 := be.blocks.size()
	var placed := pe.add_roof(id, "deux_pans")
	_check(placed > 0 and be.blocks.size() == nb0 + placed, "toit à deux pans posé en blocs (%d blocs)" % placed)
	var top_y2 := roundi((pe.base_y(id, 3) + PlanEditor.H) / BlockEditor.UNIT_Y)
	_check(be.blocks.has(Vector3i(39, top_y2, 39)), "débord d'une case au coin du toit")
	var placed4 := pe.add_roof(id, "quatre_pans")
	_check(placed4 > 0 and be.blocks.size() == nb0 + placed4, "quatre pans à la place des deux pans : l'ancien toit est remplacé (%d blocs)" % placed4)
	var expect := 0
	for k in be.blocks:
		var kb: Vector3i = k
		if kb.y >= top_y2 and kb.x >= 39 and kb.x <= 46 and kb.z >= 39 and kb.z <= 45:
			expect += 1
	_check(expect == placed4 and be.blocks.has(Vector3i(42, top_y2, 39)) and be.blocks.has(Vector3i(42, top_y2, 45)), "pans avant et arrière complets")
	# Vue en coupe puis outil rangé : tous les morceaux de toit réapparaissent.
	pe._active = id
	pe.level = 0
	pe.set_tool(PlanEditor.Tool.WALL)
	for i in 3:
		await process_frame
	pe.set_tool(PlanEditor.Tool.NONE)
	for i in 3:
		await process_frame
	var shown := 0
	for ck in be._chunks:
		var cm: Mesh = (be._chunks[ck] as MeshInstance3D).mesh
		if cm != null and cm.get_surface_count() > 0:
			shown += 1
	_check(shown == be._chunks.size(), "après la vue en coupe, tout le toit est redessiné")

	print("Construire en hauteur :")
	pe._active = ""
	pe.level = 2
	var aim := Vector3(43.5, pe.base_y(id, 2), 42.5)
	var eye := aim + Vector3(-30, 25, -30)
	var hv := pe.pick(eye, (aim - eye).normalized())
	_check(String(hv.get("id", "")) == id and int(hv.get("e", -1)) == 2 and hv.get("cell") == Vector2i(43, 42), "visée au 2e étage même quand le sol sous le curseur est loin")
	pe.set_wall_levels(3)
	_check(pe._stack(PlanEditor.wall_line(Vector2i(50, 40), Vector2i(53, 40), 4)).size() == 9, "un mur de 3 m tracé sur 3 étages = 9 murs")
	_check(pe.add_room(id, Rect2i(41, 41, 2, 2), 4, 3) and pe.levels_of(id).has(6) and p.floors.has(Vector3i(41, 6, 41)), "pièce montée du 4e au 6e étage d'un coup")
	pe.set_wall_levels(1)
	pe.level = 0

	print("Règles :")
	var yr := world.cell_height(Vector2i(42, 30))
	var road := transport.build_segment("route", Vector3(42.5, yr, 30.0), Vector3(42.5, yr, 50.0))
	_check(not road.ok, "pas de route à travers le bâtiment")
	var yr2 := world.cell_height(Vector2i(70, 30))
	var road2 := transport.build_segment("route", Vector3(70.5, yr2, 20.0), Vector3(70.5, yr2, 60.0))
	var gl := pe.ground_level(Vector2i(74, 40))
	_check(road2.ok and absf(gl - transport.network.nearest_on_edge(transport.edges_near(Vector3(74.5, 0, 40.5), 30.0)[0], Vector3(74.5, 0, 40.5)).pos.y) < 0.26, "près d'une route, le rez-de-chaussée se cale sur la chaussée (%.1f m)" % gl)
	# Maison collée à la route : le débord du toit côté route doit passer (toit fermé).
	var rx := 71
	while transport.is_cell_occupied(Vector2i(rx, 52)):
		rx += 1
	var idr := pe.new_plan(pe.ground_level(Vector2i(rx, 52)))
	pe.add_room(idr, Rect2i(rx, 50, 6, 5), 0)
	var y2r := roundi((pe.base_y(idr, 0) + PlanEditor.H) / BlockEditor.UNIT_Y)
	var nbr := be.blocks.size()
	var pr := pe.add_roof(idr, "quatre_pans")
	_check(pr > 0 and be.blocks.size() == nbr + pr, "toit d'une maison au bord de la route posé en entier (%d blocs)" % pr)
	var front_ok := true
	for z in range(50, 55):
		if not be.blocks.has(Vector3i(rx - 1, y2r, z)):
			front_ok = false
	_check(front_ok, "le débord du toit enjambe le trottoir : pas de trou entre le mur et le toit")
	_check(be.check_block(Vector3i(70, roundi((yr2 + 2.0) / BlockEditor.UNIT_Y), 52)) != "", "pas de bloc bas au-dessus de la chaussée")
	_check(be.check_block(Vector3i(70, roundi((yr2 + 5.0) / BlockEditor.UNIT_Y), 52)) == "", "un bloc au-dessus du gabarit (4,5 m) peut enjamber la route")
	# Débord impossible (un bloc le gêne) : toit au ras des murs, mais fermé.
	var idk := pe.new_plan(pe.ground_level(Vector2i(92, 92)))
	pe.add_room(idk, Rect2i(90, 90, 4, 4), 0)
	var y2k := roundi((pe.base_y(idk, 0) + PlanEditor.H) / BlockEditor.UNIT_Y)
	be.place_blocks([Vector3i(91, y2k - 1, 89)], BlocFormes.encode(5))
	var nbk := be.blocks.size()
	var pk := pe.add_roof(idk, "quatre_pans")
	_check(pk > 0 and be.blocks.size() == nbk + pk and be.blocks.has(Vector3i(90, y2k, 90)) and not be.blocks.has(Vector3i(89, y2k, 89)), "débord gêné : toit posé au ras des murs, sans trou (%d blocs)" % pk)
	_check(not bs.check_place("maison", Vector2i(43, 43), 0).ok, "pas de bâtiment dans le bâtiment")
	var id2 := pe.new_plan(pe.ground_level(Vector2i(80, 40)))
	_check(not pe.add_room(id2, Rect2i(44, 42, 2, 2), 0), "pas un bâtiment dans un autre")
	pe._drop_if_empty(id2)
	bs.money = 10
	_check(not pe.add_room(id, Rect2i(50, 40, 4, 4), 0), "refusé si la caisse est vide")
	bs.money = 1_000_000

	print("Au ras du sol :")
	var c3 := Vector2i(60, 70)
	var id3 := pe.new_plan(pe.ground_level(c3) + 1.0) # ancien calcul : 1 m trop haut
	pe.add_room(id3, Rect2i(60, 70, 4, 4), 0)
	pe.set_opening_at(id3, Vector4i(61, 0, 70, 0), "porte")
	pe.add_roof(id3, "plat")
	var roof_k := Vector3i(61, roundi((pe.base_y(id3, 0) + PlanEditor.H) / BlockEditor.UNIT_Y), 71)
	var had_roof := be.blocks.has(roof_k)
	var dd := pe.reseat(id3)
	_check(had_roof and dd <= -1.0 and absf(float(pe.plans[id3].y0) - pe.ground_level(Vector2i(61, 69))) < 0.01, "bâtiment trop haut remis de plain-pied (%.1f m)" % dd)
	_check(not be.blocks.has(roof_k) and be.blocks.has(roof_k + Vector3i(0, roundi(dd / BlockEditor.UNIT_Y), 0)), "le toit descend avec lui")
	_check(pe.reseat(id3) == 0.0, "une deuxième fois : rien ne bouge")

	print("Annuler, gomme :")
	var nw: int = p.walls.size()
	pe.add_walls(id, PlanEditor.wall_line(Vector2i(40, 48), Vector2i(44, 48), 0))
	_check(p.walls.size() == nw + 4, "4 m de mur en plus")
	var mu := bs.money
	_check(pe.undo() and (pe.plans[id] as Dictionary).walls.size() == nw and bs.money > mu, "Ctrl+Z : le mur disparaît, l'argent revient")
	p = pe.plans[id]
	_check(pe.erase_rect(id, Rect2i(41, 41, 3, 3), -1) > 0 and not pe.levels_of(id).has(-1), "sous-sol effacé")
	_check(absf(world.cell_height(Vector2i(42, 42)) - hb) < 0.01, "terrain rebouché comme avant")

	print("Sauvegarde :")
	var data: Dictionary = JSON.parse_string(JSON.stringify(pe.to_dict()))
	var nwalls: int = p.walls.size()
	var nfloors: int = p.floors.size()
	pe.from_dict(data)
	var q: Dictionary = pe.plans.get(id, {})
	_check(not q.is_empty() and q.walls.size() == nwalls and q.floors.size() == nfloors and q.stairs.size() == 4, "murs, sols et escaliers restaurés")
	_check(String(q.walls[Vector4i(41, 0, 40, 0)].o) == "porte" and BlocFormes.mat_of(int(q.walls[Vector4i(40, 0, 41, 1)].b)) == 37, "ouvertures et peinture restaurées")
	_check(pe.cells.has(Vector2i(42, 42)), "cases occupées restaurées")

	print("PLANS TEST OK" if ok else "PLANS TEST ÉCHEC")
	quit(0 if ok else 1)
