extends SceneTree
## Test des intérieurs : bible des meubles, pose case par case, pièces et
## mobilier généré, bâtiments meublés, habitants dans les pièces à leurs
## heures, effets (confort, valeur, attractivité), sauvegarde, panneau.
## Usage : godot --headless --path . --script res://tests/interieurs_test.gd

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


func _at(date: String, hour: float) -> float:
	return Time.get_unix_time_from_datetime_string(date + "T00:00:00") + (hour - 1.0) * 3600.0


func _count_type(mob: Mobilier, id: String, tag: String) -> int:
	var n := 0
	for k in mob.items.get(id, {}):
		var e := Meubles.get_entry(String(mob.items[id][k].m))
		if (e.tags as Array).has(tag) or String(e.type) == tag:
			n += 1
	return n


func _run() -> void:
	Creations.persist = false
	print("Bible des meubles :")
	_check(Meubles.count() >= 1500, "%d meubles dans la bible" % Meubles.count())
	_check(Meubles.STYLES.size() >= 30, "%d styles de mobilier" % Meubles.STYLES.size())
	var regions := {}
	var eras := {}
	for sid in Meubles.STYLES:
		regions[String(Meubles.STYLES[sid].region)] = true
		eras[String(Meubles.STYLES[sid].era)] = true
	_check(regions.size() == Styles.REGIONS.size(), "toutes les régions du monde ont leur mobilier (%d)" % regions.size())
	_check(eras.size() == Styles.ERAS.size(), "toutes les époques, de l'Antiquité au futur (%d)" % eras.size())
	_check(Meubles.has("japonais/lit_double") and String(Meubles.get_entry("japonais/lit_double").name) == "Futon double", "Japon : futon")
	_check(Meubles.has("rustique/lit_double") and String(Meubles.get_entry("rustique/lit_double").k) == "lit_clos", "Bretagne : lit clos")
	_check(not Meubles.has("romain/refrigerateur") and Meubles.has("romain/garde_manger"), "pas de réfrigérateur chez les Romains")
	_check(Meubles.has("marocain/canape") and String(Meubles.get_entry("marocain/canape").name).begins_with("Sedari"), "Maroc : sedari")
	_check(Meubles.has("futuriste/lit_double") and String(Meubles.get_entry("futuriste/lit_double").k) == "capsule", "futur : lit capsule")
	var bad_mesh := 0
	for id in ["contemporain/canape", "japonais/table_basse", "indien/canape", "louis_xv/lit_double", "futuriste/fauteuil", "afrique_ouest/chaise", "romain/jarre"]:
		var m := MeublesModeles.mesh_of(id)
		if m == null or m.get_surface_count() == 0:
			bad_mesh += 1
	_check(bad_mesh == 0, "modèles low-poly construits")
	_check(Meubles.filtered("cuisine", "japonais").size() > 3 and Meubles.filtered("", "", "", "", "hamac").size() > 2, "filtres du catalogue (pièce, style, nom)")

	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var bs: BuildingSystem = scene.get_node("Batiments")
	var amb: DayNight = scene.get_node("Ambiance")
	var transport: TransportSystem = scene.get_node("Transport")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.set_origin(48.8584, 2.2945)
	for i in 60:
		await process_frame
	var pe: PlanEditor = scene.get_node("Plans")
	var mob: Mobilier = scene.mobilier
	var pop: Population = scene.population
	_check(mob != null and mob.pe == pe and pop.extra_buildings.is_valid(), "intérieurs branchés dans la scène")
	amb.set_speed(0)
	amb.unix_time = _at("2026-03-10", 10.0)
	bs.unlimited_money = false
	bs.money = 20_000_000

	print("Pièces et pose case par case :")
	var c0 := Vector2i(60, 60)
	var id := pe.new_plan(pe.ground_level(c0))
	_check(pe.add_room(id, Rect2i(60, 60, 8, 5), 0), "pièce de 8 × 5 m")
	pe.add_walls(id, PlanEditor.wall_line(Vector2i(64, 60), Vector2i(64, 65), 0))
	pe.set_opening_at(id, Vector4i(64, 0, 62, 1), "porte")
	pe.set_opening_at(id, Vector4i(61, 0, 60, 0), "porte")
	pe.set_opening_at(id, Vector4i(66, 0, 65, 0), "fenetre")
	var rs := mob.rooms(id, 0)
	_check(rs.size() == 2 and int(rs[0].area) == 20 and int(rs[1].area) == 20, "deux pièces de 20 m² trouvées (la porte sépare les pièces)")
	var m0 := bs.money
	var bed := "contemporain/lit_double"
	_check(mob.place(id, 0, Vector2i(60, 63), 0, bed) == "", "lit double posé (2 × 2 cases)")
	_check(bs.money == m0 - int(Meubles.get_entry(bed).prix), "lit payé %s" % BuildingSystem.format_money(int(Meubles.get_entry(bed).prix)))
	_check(mob.place(id, 0, Vector2i(61, 63), 0, "contemporain/fauteuil") != "", "pas deux meubles sur la même case")
	_check(mob.place(id, 0, Vector2i(63, 61), 0, "contemporain/canape") != "", "un meuble ne traverse pas un mur")
	_check(mob.place(id, 0, Vector2i(70, 61), 0, "contemporain/chaise") != "", "pas de meuble sans plancher")
	_check(mob.place(id, 0, Vector2i(61, 61), 0, "contemporain/tapis") == "" and mob.place(id, 0, Vector2i(61, 61), 0, "contemporain/table_basse") == "", "un tapis sous la table basse (couches sol et meuble)")
	_check(mob.place(id, 0, Vector2i(62, 62), 0, "contemporain/cadre") != "", "un tableau s'accroche à un mur")
	_check(mob.place(id, 0, Vector2i(62, 60), 0, "contemporain/cadre") == "", "tableau accroché au mur du fond")
	var k_bed: Variant = mob.item_at(id, 0, Vector2i(61, 64))
	var m1 := bs.money
	_check(k_bed != null and mob.remove(id, k_bed), "lit retiré")
	_check(bs.money == m1 + roundi(int(Meubles.get_entry(bed).prix) * Mobilier.REFUND), "moitié du prix remboursée")
	_check(mob.undo() and mob.item_at(id, 0, Vector2i(61, 64)) != null, "Ctrl+Z : le lit revient")

	print("Mobilier généré selon la fonction :")
	_check(mob.set_room_function(id, 0, Vector2i(65, 62), "cuisine"), "la pièce de droite devient une cuisine")
	var n := mob.furnish_room(id, 0, Vector2i(65, 62), "japonais")
	_check(n >= 4, "cuisine japonaise meublée : %d meubles" % n)
	_check(_count_type(mob, id, "cuisson") >= 1 and _count_type(mob, id, "eau") >= 1 and _count_type(mob, id, "froid") >= 1, "de quoi cuisiner, un évier, de quoi garder au frais")
	var door_free := mob.item_at(id, 0, Vector2i(64, 62), 1) == null and mob.item_at(id, 0, Vector2i(63, 62), 1) == null
	if not door_free:
		for cc in [Vector2i(64, 62), Vector2i(63, 62)]:
			var kd: Variant = mob.item_at(id, 0, cc, 1)
			if kd != null:
				print("    sur ", cc, " : ", mob.items[id][kd])
	_check(door_free, "les deux côtés de la porte restent libres")
	var front_free := mob.item_at(id, 0, Vector2i(61, 60), 1) == null
	_check(front_free, "l'entrée reste libre")
	mob.set_room_function(id, 0, Vector2i(61, 62), "chambre")
	mob.furnish_room(id, 0, Vector2i(61, 62), "contemporain")
	_check(_count_type(mob, id, "lit") >= 1, "chambre : un lit")
	mob.flush()
	var nodes: Dictionary = mob._nodes.get(id, {})
	_check(nodes.has(0) and (nodes[0] as Node3D).get_child_count() >= 2, "meubles affichés et solides (maillage + collisions)")
	# Le mur de la cuisine disparaît : ses meubles accrochés ou coupés sont rangés.
	var before := (mob.items[id] as Dictionary).size()
	pe.erase_rect(id, Rect2i(64, 60, 4, 5), 0)
	_check((mob.items[id] as Dictionary).size() < before, "plancher retiré : les meubles de la cuisine sont rangés (%d → %d)" % [before, (mob.items[id] as Dictionary).size()])

	print("Bâtiments meublés prêts à visiter :")
	mob.set_style("contemporain")
	var placed := {}
	var x := -120
	for kind in Gabarits.ORDER:
		var res := Gabarits.build(mob, kind, Vector2i(x, -40), 0, "contemporain" if kind != "maison" else "rustique")
		_check(res.ok, "%s posé (%s)" % [Gabarits.KINDS[kind].name, BuildingSystem.format_money(int(res.get("cost", 0))) if res.ok else String(res.get("error", ""))])
		if res.ok:
			placed[kind] = String(res.id)
		x += 24
	pe.flush()
	mob.flush()
	if placed.has("maison"):
		var s := mob.stats(placed.maison)
		_check(int(s.logements) == 1 and int(s.lits) >= 3, "maison : 1 logement, %d lits" % int(s.lits))
		_check(int(s.conf) >= 55 and (s.manques as Array).is_empty(), "maison confortable (%d), rien ne manque" % int(s.conf))
		_check(int(s.valeur) > 100_000, "valeur de la maison : %s" % BuildingSystem.format_money(int(s.valeur)))
		_check(pe.levels_of(placed.maison).size() == 2 and not pe.plans[placed.maison].stairs.is_empty(), "deux niveaux reliés par un escalier")
		var doors := 0
		for k in pe.plans[placed.maison].walls:
			if Mobilier.is_door(pe.plans[placed.maison].walls[k]) and String(pe.plans[placed.maison].walls[k].o) != "passage":
				doors += 1
		_check(doors >= 5, "%d portes qui s'ouvrent" % doors)
		var styles_ok := true
		for k in mob.items[placed.maison]:
			styles_ok = styles_ok and Meubles.get_entry(String(mob.items[placed.maison][k].m)).region == "europe"
		_check(styles_ok, "maison meublée en rustique européen")
	if placed.has("immeuble"):
		var s2 := mob.stats(placed.immeuble)
		_check(int(s2.logements) == 4, "immeuble : 4 appartements (une cuisine par étage)")
	if placed.has("ecole"):
		var s3 := mob.stats(placed.ecole)
		_check(int(s3.places) >= 20 and int(s3.emplois) >= 3, "école : %d places d'élèves, %d emplois" % [int(s3.places), int(s3.emplois)])
		_check(_count_type(mob, placed.ecole, "tableau") == 2, "deux classes, deux tableaux")
	for k2 in ["boutique", "bureaux", "cafe"]:
		if placed.has(k2):
			var s4 := mob.stats(placed[k2])
			_check(int(s4.emplois) >= 1 and (s4.manques as Array).is_empty(), "%s : %d emplois, rien ne manque" % [Gabarits.KINDS[k2].name, int(s4.emplois)])
	var cut_ok := false
	if placed.has("maison"):
		var shop_attr := int(mob.stats(placed.get("boutique", placed.maison)).attr)
		_check(shop_attr > 20, "la boutique et ses vitrines attirent (attractivité %d)" % shop_attr)

	print("Habitants dans les pièces :")
	pop._sync_buildings()
	var home_bid := mob.bid_of(placed.get("maison", ""))
	var school_bid := mob.bid_of(placed.get("ecole", ""))
	_check(pop.known.has(home_bid) and int(pop.known[home_bid].log) == 1, "les habitants voient la maison meublée")
	_check(pop.known.has(school_bid) and int(pop.known[school_bid].seats) == int(mob.stats(placed.ecole).places), "l'école a autant de places que de pupitres")
	var y := world.cell_height(Vector2i(0, 0))
	transport.build_segment("route", Vector3(-140, y, -50), Vector3(40, y, -50))
	for i in 72:
		pop.advance(300.0)
	var n_homes := (pop.by_home.get(home_bid, []) as Array).size() + (pop.by_home.get(mob.bid_of(placed.get("immeuble", "")), []) as Array).size()
	_check(n_homes >= 2, "%d foyers ont emménagé dans la maison et l'immeuble" % n_homes)
	var workers := 0
	for k3 in placed:
		workers += (pop.by_job.get(mob.bid_of(placed[k3]), []) as Array).size()
	_check(workers > 0, "%d habitants travaillent dans les bâtiments meublés" % workers)
	var fam: Array = pop.by_home.get(home_bid, [])
	if not fam.is_empty():
		var p0: Dictionary = pop.persons[(pop.households[fam[0]].m as Array)[0]]
		var sat := pop.satisfaction(p0)
		var has_conf := false
		for w in sat.why:
			has_conf = has_conf or String(w).contains("confort")
		_check(has_conf, "le confort du logement compte dans la satisfaction")
		# Loyer du logement aménagé × valeur du quartier (pollution, bruit, parcs : Nuisances).
		var quartier := Nuisances.instance.coef_foncier(home_bid) if Nuisances.instance != null else 1.0
		_check(absf(float(pop.household_budget(fam[0]).loyer) - float(mob.stats(placed.maison).loyer) * quartier) < 0.5,
			"le loyer suit la valeur du logement (%s × quartier %.2f)" % [BuildingSystem.format_money(roundi(float(mob.stats(placed.maison).loyer))), quartier])
	var occ: Occupants = scene.occupants
	occ.camera = null
	var cam: Camera3D = scene.get_node("CameraRig/Camera3D")
	cam.global_position = Vector3(-100, 60, -20)
	amb.unix_time = _at("2026-03-11", 3.0)
	pop._now = {}
	occ.refresh()
	var lying := 0
	for f in occ.shown:
		if String(f.plan) == placed.get("maison", "") and String(f.pose) == "couche":
			lying += 1
	_check(lying >= 1, "3 h du matin : %d habitant%s couché%s dans les lits de la maison" % [lying, "s" if lying > 1 else "", "s" if lying > 1 else ""])
	amb.unix_time = _at("2026-03-10", 10.0)
	pop._now = {}
	occ.refresh()
	var at_desk := 0
	var in_class := 0
	for f in occ.shown:
		if String(f.plan) == placed.get("ecole", "") and String(f.kind) == "pupitre":
			in_class += 1
		if String(f.kind) in ["poste", "comptoir", "tableau"]:
			at_desk += 1
	_check(in_class >= 1, "mardi 10 h : %d élèves assis à leur pupitre" % in_class)
	_check(at_desk >= 1, "mardi 10 h : %d employés à leur poste, au tableau ou au comptoir" % at_desk)

	print("Vue au sol :")
	if placed.has("maison"):
		var pm: Dictionary = pe.plans[placed.maison]
		var front: Vector4i = PlanEditor.wall_line(Vector2i(-115, -40), Vector2i(-114, -40), 0)[0]
		var by := pe.base_y(placed.maison, 0)
		_check(pe.interact_ray(Vector3(-114.5, by + 1.5, -41.5), Vector3(0, 0, 1), 3.0) and bool(pm.walls[front].op), "E : la porte d'entrée s'ouvre")
		var msg := [""]
		mob.message.connect(func(t: String) -> void: msg[0] = t)
		var kk: Variant = null
		for k in mob.items[placed.maison]:
			if (k as Vector4i).y == 0 and (k as Vector4i).w == 1:
				kk = k
				break
		if kk != null:
			var it: Dictionary = mob.items[placed.maison][kk]
			var ent := Meubles.get_entry(String(it.m))
			var cpt := Vector3((kk as Vector4i).x + 0.5, by + 0.3, (kk as Vector4i).z + 0.5)
			_check(mob.interact_ray(cpt + Vector3(0, 0.5, -1.0), Vector3(0, -0.3, 1.0), 3.0) and msg[0].contains(String(ent.name)), "E sur un meuble : « %s »" % msg[0])

	print("Sauvegarde :")
	var d := mob.to_dict()
	var count0 := 0
	for pid in mob.items:
		count0 += (mob.items[pid] as Dictionary).size()
	var json := JSON.stringify(d)
	mob.from_dict(JSON.parse_string(json))
	var count1 := 0
	for pid in mob.items:
		count1 += (mob.items[pid] as Dictionary).size()
	_check(count1 == count0 and count0 > 50, "%d meubles relus après sauvegarde" % count1)
	_check(mob.usage_of(placed.get("ecole", "")) == "ecole" and mob.stats(placed.get("ecole", "")).places > 0, "usages et fonctions des pièces relus")
	var secs: Dictionary = scene.save_sections()
	_check(secs.has("mobilier"), "section « mobilier » dans la sauvegarde")

	print("Panneau Intérieur :")
	var bp: BuildingPanel = scene.get_node("PanneauConstruction")
	bp.set_open(true)
	bp.show_category("interieur")
	await process_frame
	var buttons := 0
	for c in bp._item_buttons:
		if c is Button:
			buttons += 1
	_check(buttons >= 50, "onglet Intérieur : %d boutons (outils, gabarits, meubles)" % buttons)
	_check(Icones.has_icon("interieur"), "icône de l'onglet")

	print("INTERIEURS TEST OK" if ok else "INTERIEURS TEST ÉCHEC")
	quit(0 if ok else 1)
