extends SceneTree
## Orientation des formes de l'éditeur libre : tourner (R), renverser (F),
## coucher (C), boutons du panneau, et clavier rendu au jeu après une recherche.
## Usage : godot --headless --path . --script res://tests/orientation_blocs_test.gd

var ok := true


func _initialize() -> void:
	_run.call_deferred()


func _check(cond: bool, what: String) -> void:
	if not cond:
		push_error("ÉCHEC : " + what)
		ok = false
	else:
		print("  ok  ", what)


func _flat_tile(_t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(40.0)
	return a


## Sommets (arrondis) d'une forme posée seule, triés : signature de sa géométrie.
func _sig(code: int) -> Array:
	var m := BlocMesher.new()
	BlocFormes.emit(m, code, Vector3.ZERO, func(_o: Vector3i) -> int: return -1)
	var u := {}
	for s in 2:
		for v in (m._v[s] as PackedVector3Array):
			u["%.2f,%.2f,%.2f" % [v.x, v.y, v.z]] = true
	var k := u.keys()
	k.sort()
	return k


## Éloignement maximal des sommets au centre de la case (gardé par une vraie rotation).
func _reach(code: int) -> float:
	var m := BlocMesher.new()
	BlocFormes.emit(m, code, Vector3.ZERO, func(_o: Vector3i) -> int: return -1)
	var d := 0.0
	for s in 2:
		for v in (m._v[s] as PackedVector3Array):
			d = maxf(d, v.distance_to(Vector3(0.5, 0.5, 0.5)))
	return d


func _key(code: Key, uni := 0) -> void:
	for p in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.unicode = uni
		e.pressed = p
		Input.parse_input_event(e)
		await process_frame


func _click(pos: Vector2, button := MOUSE_BUTTON_MIDDLE) -> void:
	for p in [true, false]:
		var c := InputEventMouseButton.new()
		c.button_index = button
		c.position = pos
		c.pressed = p
		Input.parse_input_event(c)
		await process_frame


func _run() -> void:
	print("Géométrie :")
	var slope := BlocFormes.encode(3, BlocFormes.S.SLOPE)
	var all := {}
	for pose in 4:
		for r in 4:
			all[str(_sig(BlocFormes.with_pose(BlocFormes.encode(3, BlocFormes.S.SLOPE, r), pose)))] = true
	_check(all.size() >= 8, "pente : %d orientations différentes (debout, renversée, couchée × 4 quarts de tour)" % all.size())
	_check(_sig(BlocFormes.with_pose(slope, BlocFormes.POSE_RENVERSE)) != _sig(slope), "pente renversée ≠ pente debout")
	_check(_sig(BlocFormes.with_pose(slope, BlocFormes.POSE_COUCHE)) != _sig(BlocFormes.with_pose(slope, BlocFormes.POSE_COUCHE_INV)), "les deux sens couchés diffèrent")
	_check(_sig(BlocFormes.with_pose(slope, 0)) == _sig(slope), "position 0 = forme d'avant (sauvegardes inchangées)")
	var out := []
	for sh in BlocFormes.ORDER:
		if not BlocFormes.can_tilt(sh):
			continue
		var d0 := _reach(BlocFormes.encode(3, sh))
		for pose in 4:
			for r in 4:
				if absf(_reach(BlocFormes.with_pose(BlocFormes.encode(3, sh, r), pose)) - d0) > 0.01:
					out.append(BlocFormes.shape_name(sh))
	_check(out.is_empty(), "toutes les formes d'une case tournent autour du centre de leur case, dans les 16 orientations %s" % str(out))
	_check(not BlocFormes.can_tilt(BlocFormes.S.DOOR) and not BlocFormes.can_tilt(BlocFormes.S.P_DOME), "portes (2 cases) et grandes pièces : pas de renversement")
	var big := BlocFormes.with_pose(BlocFormes.encode(300, BlocFormes.S.CURVE_IN, 3, 5), 3)
	_check(BlocFormes.mat_of(big) == 300 and BlocFormes.rot_of(big) == 3 and BlocFormes.tint_of(big) == 5 and big < (1 << 53),
		"la position ne touche ni au matériau, ni à la rotation, ni à la teinte, et le code reste exact en JSON")

	print("Dans le jeu :")
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var bs: BuildingSystem = scene.get_node("Batiments")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.set_origin(48.8584, 2.2945)
	for i in 60:
		await process_frame
	bs.unlimited_money = true
	bs.require_access = false
	var be: BlockEditor = scene.get_node("Blocs")
	var panel = scene.get("build_panel")
	var info := [""]
	be.info_changed.connect(func(t: String) -> void: info[0] = t)
	panel.set_open(true)
	panel.set_workshop(true, "blocs")
	panel.set_block_mode("blocs")
	panel._block_tab = "materiaux"
	panel.show_category("blocs")
	await process_frame
	panel.block_shape_chosen.emit(BlocFormes.S.SLOPE)
	await process_frame
	_check(be.tool == BlockEditor.Tool.BLOCK, "choisir une forme prend l'outil Poser")
	var mm := InputEventMouseMotion.new()
	mm.position = Vector2(800, 450)
	Input.parse_input_event(mm)
	await process_frame
	_check(not be._target.is_empty(), "une case est visée")
	var c0 := be.current_code(be._target)
	await _key(KEY_R, 114)
	var c1 := be.current_code(be._target)
	_check(BlocFormes.rot_of(c1) == (BlocFormes.rot_of(c0) + 1) % 4, "R : quart de tour")
	_check(info[0].contains("F : renverser") and info[0].contains("C : coucher"), "la barre du bas annonce R, F et C")
	await _key(KEY_F, 102)
	_check(BlocFormes.pose_of(be.current_code(be._target)) == BlocFormes.POSE_RENVERSE, "F : renversée")
	_check(info[0].contains("renversé"), "la barre du bas dit « renversé »")
	await _key(KEY_C, 99)
	_check(BlocFormes.pose_of(be.current_code(be._target)) == BlocFormes.POSE_COUCHE, "C : couchée")
	await _key(KEY_F, 102)
	_check(BlocFormes.pose_of(be.current_code(be._target)) == BlocFormes.POSE_COUCHE_INV, "F sur une forme couchée : l'autre sens")
	var gk := be._ghost_key
	_check(gk.begins_with(str(be.current_code(be._target))), "l'aperçu jaune suit l'orientation")
	panel.block_orient.emit("redresser")
	_check(be.pose == 0 and be.rot_offset == 0, "bouton Redresser")
	panel.block_orient.emit("tourner")
	panel.block_orient.emit("coucher")
	_check(be.rot_offset == 1 and be.pose == BlocFormes.POSE_COUCHE, "boutons Tourner et Coucher du panneau")
	var found := 0
	for b in panel.find_children("*", "Button", true, false):
		if String((b as Button).text).contains("Renverser"):
			found += 1
	_check(found == 1, "bouton Renverser visible dans le panneau")

	# Poser la forme couchée : la position est gardée.
	var code := be.current_code(be._target)
	var place: Vector3i = be._target.place
	be.place_blocks([place], code)
	_check(be.blocks.has(place) and BlocFormes.pose_of(be.blocks[place]) == BlocFormes.POSE_COUCHE, "forme couchée posée telle quelle")

	# Clavier rendu au jeu après une recherche de matériau.
	var search: LineEdit = null
	for n in panel.find_children("*", "LineEdit", true, false):
		if String((n as LineEdit).placeholder_text).begins_with("Chercher un matériau"):
			search = n
	_check(search != null, "champ de recherche des matériaux")
	if search:
		search.grab_focus()
		await process_frame
		await _click(Vector2(800, 450))
		_check(root.gui_get_focus_owner() == null, "un clic dans le monde rend le clavier au jeu")
		var r0 := be.rot_offset
		await _key(KEY_R, 114)
		_check(be.rot_offset == (r0 + 1) % 4, "R tourne ensuite la forme (au lieu d'écrire dans la recherche)")
		search = null
		for n in panel.find_children("*", "LineEdit", true, false):
			if String((n as LineEdit).placeholder_text).begins_with("Chercher un matériau"):
				search = n
		search.grab_focus()
		await process_frame
		panel.block_material_chosen.emit(5)
		_check(root.gui_get_focus_owner() == null, "choisir un matériau rend aussi le clavier au jeu")

	print("RÉSULTAT : ", "OK" if ok else "ÉCHEC")
	quit(0 if ok else 1)
