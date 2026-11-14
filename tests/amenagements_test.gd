extends SceneTree
## Test des aménagements de l'atelier : bassins, rails et quais, gradins,
## terrains de sport (mode Murs et étages), et leur lien avec les fonctions de
## bâtiment (piscine, stade…) une fois enregistrés dans la banque.
## Usage : godot --headless --path . --script res://tests/amenagements_test.gd

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

	print("Catalogue des aménagements :")
	var fams := {}
	for f in Amenagements.FAMILLES:
		fams[f[0]] = 0
	var all_ok := true
	var heavy := ""
	for kind in Amenagements.KINDS:
		var k: Dictionary = Amenagements.KINDS[kind]
		fams[k.fam] = int(fams.get(k.fam, 0)) + 1
		if not kind in Amenagements.ORDER:
			all_ok = false
			print("    pas dans ORDER : ", kind)
		for key in ["wall", "floor", "rim", "water", "ties", "rail", "paving", "top", "side", "tread", "riser", "seat", "surf", "around", "roof", "frame", "canopy"]:
			var nm := String(k.get(key, ""))
			if nm != "" and BlocMateriaux.index_of(nm) < 0:
				all_ok = false
				print("    matériau inconnu : %s (%s)" % [nm, kind])
		var mesh := VignettesAtelier.amenagement_mesh(kind)
		var n := _tris(mesh)
		if n < 4:
			all_ok = false
			print("    maquette vide : ", kind)
		if n > 60000:
			heavy += " %s (%d)" % [kind, n]
		var s: Vector2i = k.size
		if Amenagements.size_problem(kind, s.x, s.y) != "":
			all_ok = false
			print("    taille du modèle refusée : ", kind)
	_check(all_ok, "%d aménagements : matériaux connus, maquettes 3D, taille du modèle permise" % Amenagements.KINDS.size())
	_check(heavy == "", "maquettes légères (moins de 60 000 triangles)%s" % heavy)
	for f in fams:
		_check(int(fams[f]) >= 5, "onglet %s : %d modèles" % [f, int(fams[f])])
	_check(Amenagements.KINDS.size() == Amenagements.ORDER.size(), "ordre des vignettes complet")

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
	var mob: Mobilier = scene.mobilier
	var pe: PlanEditor = mob.pe

	print("Piscine posée au sol :")
	var c0 := Vector2i(40, 40)
	var g0 := world.cell_height(c0 + Vector2i(2, 4))
	var id := pe.new_plan(pe.ground_level(c0))
	pe.add_floors(id, Rect2i(c0 - Vector2i(2, 2), Vector2i(8, 12)), 0)
	bs.unlimited_money = false
	bs.money = 10_000_000
	var m0 := bs.money
	pe.amenag = "piscine"
	var prect := pe.amenag_rect(c0, c0, 0)
	_check(prect.size == Vector2i(4, 8), "un clic : piscine de 4 × 8 m")
	prect = Rect2i(c0, Vector2i(4, 8))
	_check(pe.add_amenagement(id, prect, 0, "piscine", 0), "posée")
	_check(bs.money < m0, "payée : %s" % BuildingSystem.format_money(m0 - bs.money))
	bs.unlimited_money = true
	var p: Dictionary = pe.plans[id]
	_check((p.am as Dictionary).size() == 1, "gardée dans le bâtiment")
	_check(world.cell_height(c0 + Vector2i(2, 4)) < g0 - 1.4, "terrain creusé sous le bassin (%.1f m)" % (g0 - world.cell_height(c0 + Vector2i(2, 4))))
	_check(not pe._has_floor_render(p, Vector3i(c0.x + 1, 0, c0.y + 1)) and pe._has_floor_render(p, Vector3i(c0.x - 1, 0, c0.y)), "pas de plancher sur l'eau, plancher autour")
	_check(not pe.add_amenagement(id, Rect2i(c0 + Vector2i(1, 1), Vector2i(3, 3)), 0, "spa"), "refusé : un autre aménagement est déjà là")
	_check(not pe.add_amenagement(id, Rect2i(c0 + Vector2i(-2, 9), Vector2i(1, 1)), 0, "bassin_nage"), "refusé : trop petit pour un bassin de nage")
	pe.flush()
	var node: Node3D = pe._nodes[id][0]
	var mi := node.get_child(0) as MeshInstance3D
	var box := mi.mesh.get_aabb()
	_check(box.position.y < pe.base_y(id, 0) - 1.5, "le bassin descend sous le plancher (fond à %.1f m)" % (box.position.y - pe.base_y(id, 0)))
	_check(mi.mesh.get_surface_count() == 2, "l'eau est transparente (surface vitrée)")

	print("Gomme, annuler, sauvegarde :")
	var hit := {"e": 0, "cell": c0 + Vector2i(1, 1), "edge": null}
	_check(pe.erase_at(id, hit), "gomme : la piscine part d'un clic")
	_check((p.am as Dictionary).is_empty() or (pe.plans[id].am as Dictionary).is_empty(), "plus d'aménagement")
	_check(pe.undo() and (pe.plans[id].am as Dictionary).size() == 1, "Ctrl+Z : elle revient")
	var saved := pe.to_dict()
	var parsed: Variant = JSON.parse_string(JSON.stringify(saved))
	pe.from_dict(parsed)
	_check(pe.plans.has(id) and (pe.plans[id].am as Dictionary).size() == 1, "relue après sauvegarde (JSON)")
	var a0: Dictionary = (pe.plans[id].am as Dictionary).values()[0]
	_check(String(a0.k) == "piscine" and int(a0.w) == 4 and int(a0.d) == 8, "type et taille gardés")

	print("Gradins :")
	var n_seats := Amenagements.seats("gradins_beton", 20, 8, 0)
	_check(Amenagements.rows("gradins_beton", 20, 8, 0) == 10 and n_seats == 400, "20 × 8 m : 10 rangs, 400 places")
	_check(Amenagements.rows("gradins_beton", 20, 8, 1) == 25, "tournés d'un quart : les rangs suivent l'autre côté (25 rangs)")
	var tm := BlocMesher.new()
	Amenagements.emit(tm, Vector3i(0, 0, 0), {"k": "tribune_couverte", "w": 30, "d": 12, "r": 0, "m": -1}, 0.0)
	var tbox := tm.to_mesh().get_aabb()
	_check(tbox.size.y > 8.0 and tbox.size.y < 12.0, "tribune couverte : %.1f m de haut avec son toit" % tbox.size.y)
	var gm := BlocMesher.new()
	Amenagements.emit(gm, Vector3i(0, 0, 0), {"k": "gradins_beton", "w": 10, "d": 4, "r": 0, "m": -1}, 0.0)
	var gmesh := gm.to_mesh()
	var hi_z := -INF
	var lo_z := INF
	var arr: PackedVector3Array = gmesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for v in arr:
		if v.y > 1.8:
			hi_z = maxf(hi_z, v.z)
			lo_z = minf(lo_z, v.z)
	_check(lo_z > 2.0, "r = 0 : les rangs montent vers +z")

	print("Terrains et rails :")
	var fm := BlocMesher.new()
	Amenagements.emit(fm, Vector3i(0, 0, 0), {"k": "foot", "w": 74, "d": 111, "r": 0, "m": -1}, 0.0)
	var fbox := fm.to_mesh().get_aabb()
	_check(absf(fbox.size.x - 74.0) < 0.6 and absf(fbox.size.z - 111.0) < 0.6 and fbox.size.y > 2.4, "football : 74 × 111 m avec ses buts")
	var small := BlocMesher.new()
	Amenagements.emit(small, Vector3i(0, 0, 0), {"k": "foot", "w": 30, "d": 45, "r": 0, "m": -1}, 0.0)
	var sbox := small.to_mesh().get_aabb()
	_check(sbox.size.x <= 30.6 and sbox.size.z <= 46.0, "terrain réduit : il tient dans 30 × 45 m")
	_check(Amenagements.tracks("voie_normale", 9, 40) == 2 and Amenagements.tracks("voie_normale", 4, 40) == 1, "voie normale : 2 voies sur 9 m de large, 1 sur 4 m")
	var rm := BlocMesher.new()
	Amenagements.emit(rm, Vector3i(0, 0, 0), {"k": "voie_normale", "w": 4, "d": 30, "r": 0, "m": -1}, 0.0)
	var rbox := rm.to_mesh().get_aabb()
	_check(rbox.size.z >= 29.9 and rbox.size.x < 4.1, "les rails suivent le grand côté (z)")
	var rid := pe.new_plan(pe.ground_level(Vector2i(-80, -80)))
	_check(pe.add_amenagement(rid, Rect2i(-80, -80, 4, 30), 0, "voie_normale"), "voie posée")
	_check(pe.add_amenagement(rid, Rect2i(-79, -52, 2, 2), 0, "butoir", 0), "heurtoir posé au bout de la voie")
	_check(not pe.add_amenagement(rid, Rect2i(-80, -60, 3, 3), 0, "spa"), "mais pas un spa sur les rails")
	var hk: Variant = Amenagements.at(pe.plans[rid].am, Vector2i(-78, -51), 0)
	_check(hk != null and String(pe.plans[rid].am[hk].k) == "butoir", "un clic sur le heurtoir vise le heurtoir")
	var am_test := {Vector3i(0, 0, 0): {"k": "foot", "w": 74, "d": 111, "r": 0, "m": -1}, Vector3i(0, 0, -12): {"k": "gradins_beton", "w": 74, "d": 10, "r": 2, "m": -1}}
	_check(Amenagements.suggest_fonction(am_test) == "foot", "un terrain de foot propose la fonction Terrain de football")
	_check(Amenagements.suggest_fonction({Vector3i.ZERO: {"k": "bassin_nage", "w": 13, "d": 25, "r": 0, "m": -1}}) == "piscine", "un bassin de nage propose la Piscine")

	print("Un petit stade dans la banque :")
	var sid := pe.new_plan(pe.ground_level(Vector2i(-150, 60)))
	var fo := Vector2i(-150, 60)
	_check(pe.add_amenagement(sid, Rect2i(fo, Vector2i(24, 44)), 0, "handball", 0), "terrain de handball")
	pe.amenag = "foot5"
	_check(pe.add_amenagement(sid, Rect2i(fo + Vector2i(0, 44), Vector2i(24, 6)), 0, "gradins_beton", 0), "gradins derrière le but")
	_check(pe.add_amenagement(sid, Rect2i(fo + Vector2i(24, 0), Vector2i(6, 44)), 0, "tribune_couverte", 3), "tribune couverte sur le côté")
	pe.flush()
	var places := Amenagements.seats_of(pe.plans[sid].am)
	var r1 := BanqueModeles.save_plan(mob, sid, "Petit stade")
	_check(r1.ok, "enregistré dans la banque")
	var d := BanqueModeles.get_model(String(r1.id))
	_check(String(d.fonction) == "gymnase", "fonction proposée par le terrain : %s" % String(d.fonction))
	_check(int(d.places) == places and places > 300, "%d places assises gardées" % places)
	BanqueModeles.set_fonction(String(r1.id), "foot")
	var cid := ModelesJeu.catalog_id(String(r1.id))
	var t := BuildingCatalog.get_type(cid)
	_check(int(t.w) == 30 and int(t.d) == 50, "emprise %d × %d m" % [int(t.w), int(t.d)])
	_check(int(t.visiteurs) >= places and Stades.places(cid) == places, "en stade : %d visiteurs, %d places aux matchs" % [int(t.visiteurs), Stades.places(cid)])
	var smesh := BuildingCatalog.build_mesh(cid)
	var sb := smesh.get_aabb()
	_check(smesh.get_surface_count() > 0 and sb.size.x <= 30.6 and sb.size.z <= 50.6, "maillage cuit dans l'emprise")
	print("Posé et tourné, visitable :")
	var bid := bs.place(cid, Vector2i(150, -120), 1)
	_check(bid >= 0, "posé tourné d'un quart")
	var amb: DayNight = scene.get_node("Ambiance")
	amb.unix_time += 86400.0 * 120
	for i in 40:
		await process_frame
	var mv: ModelesVisites = scene.modeles_visites
	mv.sync()
	var pid := mv.plan_of(bid)
	_check(pid != "" and pe.plans.has(pid), "aménagements posés à la fin du chantier")
	if pid != "" and pe.plans.has(pid):
		var am2: Dictionary = pe.plans[pid].am
		var rect: Rect2i = bs._rect_of(bs.buildings[bid])
		var inside := am2.size() == 3
		var rots := []
		for k in am2:
			inside = inside and rect.encloses(Amenagements.rect_of(k, am2[k]))
			rots.append(int(am2[k].r))
		_check(inside, "les 3 aménagements tournés restent dans l'emprise %s" % str(rect))
		_check(rots.has(1) and rots.has(0), "les gradins ont tourné avec le bâtiment (%s)" % str(rots))
		_check(Amenagements.seats_of(am2) == places, "mêmes places une fois tourné")
		bs.demolish(bid)
		mv.sync()
		_check(not pe.plans.has(pid), "démoli : aménagements partis")

	print("Panneau de l'atelier :")
	var panel: BuildingPanel = scene.build_panel
	panel._block_mode = "plans"
	var tabs := []
	for tb in panel._catalog_tabs():
		tabs.append(tb[0])
	_check(tabs.has("am_bassins") and tabs.has("am_rails") and tabs.has("am_gradins") and tabs.has("am_terrains"), "onglets Bassins, Rails et quais, Gradins, Terrains de sport")
	var box2 := VBoxContainer.new()
	panel._fill_catalog_tab("am_terrains", box2)
	var cards := 0
	for c in box2.get_children():
		if c is GridContainer:
			cards += c.get_child_count()
	_check(cards == Amenagements.of_family("terrains").size(), "%d vignettes de terrains" % cards)
	box2.free()

	print("AMÉNAGEMENTS TEST OK" if ok else "AMÉNAGEMENTS TEST ÉCHEC")
	quit(0 if ok else 1)
