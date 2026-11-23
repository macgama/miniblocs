extends SceneTree
## Test des ajouts de l'atelier : formes arrondies et détails (blocs), grandes
## pièces de taille réglable (coupole, tour ronde, voûte…), nouvelles portes et
## fenêtres des murs fins, nouveaux toits et nouveaux matériaux.
## Usage : godot --headless --path . --script res://tests/atelier_plus_test.gd

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


func _tris(mesh: ArrayMesh) -> int:
	var n := 0
	for s in mesh.get_surface_count():
		n += (mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	return n


func _run() -> void:
	Creations.persist = false
	BanqueModeles.persist = false

	print("Matériaux :")
	_check(BlocMateriaux.LIST.size() >= 350 and BlocMateriaux.LIST.size() <= 4096, "%d matériaux (codés sur 12 bits)" % BlocMateriaux.LIST.size())
	_check(String(BlocMateriaux.LIST[115].name) == "Cuir", "les matériaux de l'atelier enrichi gardent leur place")
	var big_m := BlocMateriaux.LIST.size() - 1
	var bc := BlocFormes.encode(big_m, BlocFormes.S.DOOR, 3, 9, true, true)
	_check(BlocFormes.mat_of(bc) == big_m and BlocFormes.shape_of(bc) == BlocFormes.S.DOOR and BlocFormes.rot_of(bc) == 3
		and BlocFormes.tint_of(bc) == 9 and BlocFormes.is_open(bc), "un matériau au-delà de 255 se code et se relit (%d)" % big_m)
	var pc := BlocFormes.encode_part(BlocFormes.encode(300, BlocFormes.S.P_DOME), Vector3i(3, 2, 5), 10)
	_check(BlocFormes.mat_of(pc) == 300 and BlocFormes.size_of(pc) == 10 and BlocFormes.part_of(pc) == Vector3i(3, 2, 5)
		and BlocFormes.mat_of(BlocFormes.base_code(pc)) == 300 and pc < (1 << 53), "grande pièce en matériau 300 : morceau gardé, code sûr en JSON")
	var parsed: Variant = JSON.parse_string(JSON.stringify([pc]))
	_check(parsed is Array and int(parsed[0]) == pc, "le code survit à la sauvegarde JSON")
	var fam_n := {}
	for m in BlocMateriaux.LIST:
		fam_n[m.fam] = int(fam_n.get(m.fam, 0)) + 1
	for fid in ["monde", "attractions", "zoo", "sport", "musee", "evenements"]:
		_check(int(fam_n.get(fid, 0)) >= 12, "famille %s : %d matériaux" % [fid, int(fam_n.get(fid, 0))])
	_check(String(BlocMateriaux.LIST[57].name) == "Bois peint blanc" and String(BlocMateriaux.LIST[51].name) == "Vitrail", "l'ordre des anciens matériaux ne change pas (sauvegardes)")
	var names := {}
	for m in BlocMateriaux.LIST:
		names[m.name] = true
	_check(names.size() == BlocMateriaux.LIST.size(), "aucun nom de matériau en double")
	var fams := {}
	for f in BlocMateriaux.FAMILIES:
		fams[f.id] = true
	var bad_fam := 0
	for m in BlocMateriaux.LIST:
		if not fams.has(String(m.fam)):
			bad_fam += 1
	_check(bad_fam == 0, "chaque matériau est rangé dans une famille du panneau")
	var arr := BlocMateriaux.texture_array()
	_check(arr != null and arr.get_layers() == BlocMateriaux.LIST.size() + 1, "textures dessinées pour tous les matériaux (%d couches)" % arr.get_layers())
	var img := BlocMateriaux.image(BlocMateriaux.index_of("Brique flamande"))
	var c0 := img.get_pixel(3, 3)
	var varied := false
	for i in 64:
		if img.get_pixel(i, 20).is_equal_approx(c0) == false:
			varied = true
	_check(varied, "le motif « Brique flamande » n'est pas uni")
	# Chaque motif est vraiment dessiné (pas la couleur de repli).
	var flat := []
	for mi in BlocMateriaux.LIST.size():
		var pat := String(BlocMateriaux.LIST[mi].pat)
		if pat == "uni":
			continue
		var im := BlocMateriaux.image(mi)
		var cols := {}
		for k in 64:
			cols[im.get_pixel((k * 7) % 64, (k * 13) % 64).to_html()] = true
		if cols.size() < 3:
			flat.append(pat)
	_check(flat.is_empty(), "tous les motifs sont dessinés %s" % [flat])

	print("Formes d'une case :")
	var empty := func(_o: Vector3i) -> int: return -1
	var bad := []
	var count := 0
	for sh in BlocFormes.ORDER:
		if not BlocFormes.INFO.has(sh):
			_check(false, "forme %d décrite" % sh)
		if BlocFormes.is_piece(sh):
			continue
		for rot in 4:
			var mesher := BlocMesher.new()
			BlocFormes.emit(mesher, BlocFormes.encode(1, sh, rot), Vector3.ZERO, empty)
			if mesher.is_empty():
				bad.append(BlocFormes.shape_name(sh))
		count += 1
	_check(bad.is_empty(), "%d formes dessinées dans les 4 orientations %s" % [count, "" if bad.is_empty() else str(bad)])
	_check(BlocFormes.S.P_HALFDOME < 64, "les formes tiennent sur 6 bits (%d)" % (BlocFormes.S.P_HALFDOME + 1))
	var cyl := BlocMesher.new()
	BlocFormes.emit(cyl, BlocFormes.encode(1, BlocFormes.S.CYLINDER), Vector3.ZERO, empty)
	var aabb := cyl.to_mesh().get_aabb()
	_check(absf(aabb.size.x - 1.0) < 0.02 and absf(aabb.size.y - 1.0) < 0.02, "le cylindre fait 1 m de diamètre et de haut")

	print("Codes des grandes pièces :")
	var code := BlocFormes.encode_part(BlocFormes.encode(47, BlocFormes.S.P_DOME, 2, 5), Vector3i(7, 3, 11), 16)
	_check(BlocFormes.shape_of(code) == BlocFormes.S.P_DOME and BlocFormes.mat_of(code) == 47 and BlocFormes.rot_of(code) == 2 and BlocFormes.tint_of(code) == 5, "matériau, forme, rotation et teinte relus")
	_check(BlocFormes.part_of(code) == Vector3i(7, 3, 11) and BlocFormes.size_of(code) == 16, "morceau (7, 3, 11) et taille 16 relus")
	_check(code < (1 << 53), "code exact en JSON (< 2^53)")
	var back := int(JSON.parse_string(JSON.stringify([code]))[0])
	_check(back == code, "le code survit à un aller-retour JSON")
	for sh in [BlocFormes.S.P_DOME, BlocFormes.S.P_ONION, BlocFormes.S.P_CONE, BlocFormes.S.P_SPIRE, BlocFormes.S.P_TOWER, BlocFormes.S.P_CYL,
			BlocFormes.S.P_PYRAMID, BlocFormes.S.P_VAULT, BlocFormes.S.P_ARCH, BlocFormes.S.P_GOTHIC, BlocFormes.S.P_HALFDOME]:
		var parts := FormesPlus.piece_parts(sh, 8, 1)
		var ext := FormesPlus.piece_extent(sh, 8)
		var inside := true
		for pp in parts:
			var p: Vector3i = pp
			if p.x < 0 or p.z < 0 or p.x >= ext.y or p.z >= ext.x:
				inside = false
		_check(not parts.is_empty() and inside, "%s de 8 m : %d morceaux, tous dans l'emprise tournée" % [BlocFormes.shape_name(sh), parts.size()])

	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var bs: BuildingSystem = scene.get_node("Batiments")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.set_origin(48.8584, 2.2945)
	for i in 60:
		await process_frame
	bs.unlimited_money = false
	bs.money = 50_000_000
	bs.require_access = false
	var be: BlockEditor = scene.get_node("Blocs")
	var pe: PlanEditor = scene.get_node("Plans")

	print("Poser des grandes pièces :")
	var gy := roundi(world.cell_height(Vector2i(60, 60)) / BlockEditor.UNIT_Y)
	be.material = 47
	be.shape = BlocFormes.S.P_DOME
	be.set_piece(10, 1)
	var dome := be.current_code()
	var anchors := be.piece_anchors(Vector3i(60, gy, 60), dome)
	_check(anchors.size() == 1 and anchors[0] == Vector3i(55, gy, 55), "coupole centrée sur la case visée")
	# Ce test vérifie le prix des blocs : la ville paie tout (sans promoteurs privés).
	ReglagesPartie.actuel.promoteurs_prives = false
	var m0 := bs.money
	var n := be.place_blocks(anchors, dome)
	_check(n > 20, "coupole de 10 m posée : %d morceaux" % n)
	_check(bs.money < m0, "coupole payée %s" % BuildingSystem.format_money(m0 - bs.money))
	var top := 0
	for k in be.blocks:
		top = maxi(top, (k as Vector3i).y)
	_check((top - gy) * BlockEditor.UNIT_Y >= 4.0, "la coupole monte à %.1f m" % ((top - gy) * BlockEditor.UNIT_Y))
	await process_frame
	await process_frame
	var tri := 0
	for c in be.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh is ArrayMesh and String(c.name).begins_with("Blocs_"):
			tri += _tris((c as MeshInstance3D).mesh)
	_check(tri > 200 and tri < 20000, "coupole dessinée en low-poly : %d triangles" % tri)
	var one: Vector3i = be.blocks.keys()[0]
	_check(be.group_of(one).size() == n, "un morceau retrouve toute sa pièce")
	var removed := be.remove_blocks([one])
	_check(removed == n and be.blocks.is_empty(), "clic droit sur un morceau : toute la coupole est retirée")
	be.undo()
	_check(be.blocks.size() == n, "Ctrl+Z la remet")
	be.remove_blocks([one])
	# Tour ronde empilée sur 6 m.
	be.shape = BlocFormes.S.P_TOWER
	be.set_piece(6, 6)
	var tower := be.current_code()
	var ta := be.piece_anchors(Vector3i(60, gy, 60), tower)
	_check(ta.size() == 6, "tour ronde de 6 m de haut : 6 étages de 1 m")
	var nt := be.place_blocks(ta, tower)
	_check(nt > 6 * 8, "tour posée : %d morceaux" % nt)
	_check(not be.blocks.has(Vector3i(60, gy, 60)) or BlocFormes.shape_of(be.blocks.get(Vector3i(60, gy, 60), 0)) == BlocFormes.S.P_TOWER, "le centre de la tour reste creux ou fait partie de la tour")
	var saved := be.to_dict()
	be.from_dict(JSON.parse_string(JSON.stringify(saved)))
	_check(be.blocks.size() == nt, "sauvegarde relue : %d morceaux de tour" % be.blocks.size())
	be.clear()
	# Voûte de 8 m sur 5 m de long, tournée.
	be.shape = BlocFormes.S.P_VAULT
	be.rot_offset = 1
	be.set_piece(8, 5)
	var vault := be.current_code()
	var va := be.piece_anchors(Vector3i(60, gy, 60), vault)
	_check(va.size() == 5, "voûte répétée sur 5 m")
	_check(be.place_blocks(va, vault) > 20, "voûte en berceau posée")
	be.clear()
	be.rot_offset = 0

	print("Portes et fenêtres des murs fins :")
	var y0 := pe.ground_level(Vector2i(80, 80))
	var id := pe.new_plan(y0)
	_check(pe.add_room(id, Rect2i(80, 80, 8, 6), 0), "pièce de 8 × 6 m")
	var p: Dictionary = pe.plans[id]
	var placed := 0
	var x := 80
	for kind in ["porte_entree", "porte_cintree", "fenetre_cintree", "fenetre_gothique", "oeil_de_boeuf", "fenetre_volets", "fenetre_petits_bois", "meurtriere"]:
		if pe.set_opening_at(id, Vector4i(x, 0, 80, 0), kind):
			placed += 1
		x += 1
	_check(placed == 8, "8 nouvelles ouvertures posées sur la façade")
	x = 80
	for kind in ["porte_garage", "porte_garage", "porte_garage", "mur_rideau", "mur_rideau", "porte_double", "porte_double", "claustra"]:
		pe.set_opening_at(id, Vector4i(x, 0, 86, 0), kind)
		x += 1
	_check(pe._post_gap(p, Vector2i(81, 86), 0, 0.0) != null, "porte de garage de 3 m : pas de poteau entre deux morceaux")
	_check(pe._post_gap(p, Vector2i(83, 86), 0, 0.0) == null, "garage et mur-rideau restent séparés")
	_check(pe._wide_run(p, Vector4i(81, 0, 86, 0)).size() == 3, "les trois morceaux du garage se retrouvent")
	_check(pe.toggle_door(id, Vector4i(80, 0, 86, 0)) and bool(p.walls[Vector4i(82, 0, 86, 0)].op), "la porte de garage s'ouvre d'un bloc")
	_check(pe.toggle_door(id, Vector4i(85, 0, 86, 0)) and bool(p.walls[Vector4i(86, 0, 86, 0)].op), "la porte double s'ouvre à deux battants")
	for kind in ["porte_grange", "baie_coulissante", "arcade", "fenetre_atelier", "bandeau", "porte_balcon", "vitrine_store"]:
		_check(pe.set_opening_at(id, Vector4i(80, 0, 81, 1), kind), "« %s » posée" % PlanEditor.OPENINGS[kind].name)
		pe.flush()
	_check(pe.outside_sign(p, Vector4i(81, 0, 80, 0)) == -1 and pe.outside_sign(p, Vector4i(81, 0, 86, 0)) == 1, "côté rue de chaque façade trouvé (volets, store, balconnet)")
	pe.flush()
	var nodes: Dictionary = pe._nodes.get(id, {})
	_check(nodes.has(0), "étage dessiné avec les nouvelles ouvertures")
	for k in PlanEditor.OPENING_ORDER:
		if not PlanEditor.OPENINGS.has(k):
			_check(false, "ouverture %s décrite" % k)
	_check(PlanEditor.OPENING_ORDER.size() == PlanEditor.OPENINGS.size(), "%d portes et fenêtres dans le panneau" % PlanEditor.OPENING_ORDER.size())
	var d2 := pe.to_dict()
	pe.from_dict(JSON.parse_string(JSON.stringify(d2)))
	_check(String(pe.plans[id].walls[Vector4i(84, 0, 80, 0)].o) == "oeil_de_boeuf", "ouvertures relues après sauvegarde")

	print("Toits :")
	for r in PlanEditor.ROOFS:
		var kind: String = r[0]
		var n2 := pe.add_roof(id, kind)
		_check(n2 > 0, "toit « %s » : %d blocs" % [r[1], n2])
	pe.add_roof(id, "coupole")
	var has_dome := false
	for k in be.blocks:
		if BlocFormes.shape_of(be.blocks[k]) == BlocFormes.S.P_DOME:
			has_dome = true
	_check(has_dome, "le toit en coupole utilise la grande pièce Coupole")
	pe.add_roof(id, "voute")
	var has_vault := false
	for k in be.blocks:
		if BlocFormes.shape_of(be.blocks[k]) == BlocFormes.S.P_VAULT:
			has_vault = true
	_check(has_vault, "le toit en voûte utilise la voûte en berceau")

	print("Banque de modèles :")
	var saved_model := BanqueModeles.save_plan(scene.mobilier, id, "Chapelle test")
	_check(saved_model.get("ok", false), "bâtiment avec voûte et ouvertures enregistré dans la banque")
	if saved_model.get("ok", false):
		var dm := BanqueModeles.get_model(String(saved_model.id))
		var ba: Array = dm.get("blocs", [])
		var found := false
		var i := 0
		while i + 3 < ba.size():
			if BlocFormes.shape_of(int(ba[i + 3])) == BlocFormes.S.P_VAULT and BlocFormes.size_of(int(ba[i + 3])) >= 2:
				found = true
			i += 4
		_check(found, "la voûte est gardée dans le modèle (morceau et taille)")

	print("ATELIER PLUS TEST OK" if ok else "ATELIER PLUS TEST ÉCHEC")
	quit(0 if ok else 1)
