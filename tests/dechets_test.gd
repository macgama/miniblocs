extends SceneTree
## Test des déchets : catalogue, benne à ordures, bacs qui se remplissent et
## débordent, tournée des bennes sur la route, décharge, centre de tri (balles
## dans l'économie), incinérateur (électricité), recouvrir une décharge,
## liens avec les nuisances et l'avis des habitants, réglage Admin, sauvegarde.
## Usage : godot --headless --path . --script res://tests/dechets_test.gd

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


func _place(bs: BuildingSystem, id: String, x: int, north := true) -> int:
	var d := int(BuildingCatalog.get_type(id).d)
	var c := Vector2i(x, -(d / 2 + 6) if north else d / 2 + 6)
	return bs.place(id, c, bs.best_rotation(id, c))


func _run() -> void:
	_catalog_tests()
	await _city_tests()
	print("TEST OK" if ok else "TEST ÉCHEC")
	quit(0 if ok else 1)


func _catalog_tests() -> void:
	print("Catalogue :")
	var ids := BuildingCatalog.ids_in("dechets")
	_check(ids.size() == 7, "7 bâtiments dans la catégorie Déchets (%d)" % ids.size())
	_check(not ids.has("decharge_fermee"), "la décharge recouverte n'est pas au catalogue")
	_check(not BuildingCatalog.category("dechets").is_empty(), "onglet Déchets dans Construire")
	for id in DechetsTypes.ORDER:
		var m := BuildingCatalog.build_mesh(id)
		_check(m != null and m.get_surface_count() > 0, "modèle de %s" % id)
		for j in Metiers.jobs_for(id):
			_check(Metiers.METIERS.has(String(j[0])), "%s : métier %s connu" % [id, j[0]])
	_check(Production.kind_of("centre_tri") == "transformation" and Production.kind_of("usine_recyclage") == "transformation",
		"centre de tri et usine de recyclage sont des sites de l'économie")
	_check(Ressources.MARCHANDISES.has("balles_tri"), "marchandise « balles de tri »")
	_check(DechetsTypes.role_of("incinerateur") == "incinerateur", "l'usine d'incinération de la bible Blender brûle aussi les ordures")
	var bom := VehicleCatalog.get_type("benne_om")
	_check(not bom.is_empty() and bool(bom.get("livraison", false)), "benne à ordures au catalogue des véhicules")
	_check(not Traffic._no_service(VehicleCatalog.for_track("route")).has("benne_om"), "pas de benne dans la circulation d'ambiance")
	_check(VehicleCatalog.build_mesh("benne_om") != null, "modèle de la benne")
	_check(Icones.get_icon("dechets", 22) != null, "icône Déchets")


func _city_tests() -> void:
	print("Ville :")
	Creations.persist = false
	BatimentsVie.chantiers = false
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var transport: TransportSystem = scene.get_node("Transport")
	var bs: BuildingSystem = scene.get_node("Batiments")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 40
	world.view_radius_override = 900.0
	world.set_origin(46.2, 6.9)
	for i in 3000:
		await process_frame
		if i >= 120 and world.missing_chunk_count() == 0 and world._dirty.is_empty() and world._jobs.is_empty():
			break
	var dec: Dechets = scene.dechets
	_check(dec != null and scene.dechets_panel != null, "déchets et panneau branchés dans la scène")
	_check(scene.save_sections().has("dechets"), "section « dechets » dans la sauvegarde")
	var pop: Population = scene.population
	var prod: Production = scene.production
	var tf := transport.traffic
	for n in [tf, dec, prod, pop]:
		n.set_process(false)
	scene.urgences.set_process(false)
	scene.urgences.random_calls = false
	bs.unlimited_money = true
	var y := world.cell_height(Vector2i(0, 0))
	var road := transport.build_segment("route", Vector3(-700, y, 0), Vector3(700, y, 0))
	_check(road.ok, "route de 1,4 km")
	var homes: Array[int] = []
	for i in 8:
		homes.append(_place(bs, "maison", -300 + i * 14))
	var imm := _place(bs, "immeuble", -150, false)
	_check(imm > 0 and not homes.has(-1), "8 maisons et un immeuble posés")
	pop._sync_buildings()
	for bid in homes:
		pop.spawn_household(bid, "famille")
	for i in 10:
		pop.spawn_household(imm)
	var n_hab := pop.persons.size()
	_check(n_hab >= 20, "%d habitants" % n_hab)

	dec.ignore_crew = true
	dec.ignore_hours = true
	dec._sync()
	dec.clock = 1_800_000_000.0
	dec.last_day = int(dec._now(dec.clock).day)
	var t := func(hours: float) -> void:
		for i in int(hours * 4.0):
			dec.clock += 900.0
			dec.step(900.0)
			tf.step(0.5)

	# Sans dépôt : les bacs se remplissent puis débordent.
	t.call(24.0 * 7.0)
	var kg := 0.0
	for f in Dechets.FLUX:
		kg += float(dec.totaux.produit[f])
	_check(absf(kg * 1000.0 / (n_hab * 6.0) - 1.4) < 0.35, "environ 1,4 kg par habitant et par jour (%.2f)" % (kg * 1000.0 / (n_hab * 6.0)))
	_check(float(dec.totaux.produit.rec) < 0.001, "sans centre de tri, personne ne trie")
	_check(dec.overflowing().size() >= 5, "les poubelles débordent sans collecte (%d)" % dec.overflowing().size())
	_check(dec._bags.multimesh.instance_count > 0, "sacs visibles devant les portes (%d)" % dec._bags.multimesh.instance_count)
	var p0: Dictionary = pop.persons[pop.households[pop.by_home[homes[0]][0]].m[0]]
	var sat: Array = dec.satisfaction_of(p0)
	_check(float(sat[0]) < 0.0 and not (sat[1] as Array).is_empty(), "habitant mécontent : %s" % ", ".join(sat[1]))
	var dirty := false
	for s in dec.pollution_sources():
		dirty = dirty or s.has("salete")
	_check(dirty, "rues sales déclarées aux nuisances")
	_check(dec.get_groups().has("pollution_sources") and dec.get_groups().has("avis_sources") and dec.get_groups().has("budget_entretien"),
		"groupes des autres systèmes")

	# Dépôt et décharge : la tournée part, roule, vide les bacs et décharge.
	var dep := _place(bs, "depot_collecte", 100)
	var dch := _place(bs, "decharge", 300, false)
	_check(dep > 0 and dch > 0, "dépôt de collecte et décharge posés")
	dec._sync()
	_check(dec.sites.size() == 2 and (dec.sites[dep].units as Array).size() == 4, "4 bennes au dépôt")
	_check(not dec.access_of(dep).is_empty() and not dec.access_of(homes[0]).is_empty(), "accès à la route")
	t.call(0.5)
	_check(not dec.missions.is_empty(), "une tournée part (%d)" % dec.missions.size())
	var m: Dictionary = dec.missions.values()[0]
	_check(String(m.flux) == "om" and int(m.dest) == dch, "benne d'ordures vers la décharge")
	_check(dec.trucks_on_road() >= 1, "la benne roule dans la circulation")
	_check(float(m.t_dest) > float(m.t0) + 120.0, "horaire de la tournée calculé par la route")
	t.call(12.0)
	_check(float(dec.sites[dch].total) > 0.1, "ordures enfouies : %.2f t" % float(dec.sites[dch].total))
	_check(dec.overflowing().size() <= 1, "trottoirs nettoyés (%d)" % dec.overflowing().size())
	sat = dec.satisfaction_of(p0)
	_check(float(sat[0]) >= 0.0, "plus de reproche sur les poubelles")

	# Tri : centre de tri + usine de recyclage.
	var tri := _place(bs, "centre_tri", 450, false)
	var rec := _place(bs, "usine_recyclage", 560, false)
	_check(tri > 0 and rec > 0, "centre de tri et usine de recyclage posés")
	prod._dirty = true
	prod._sync()
	dec._sync()
	_check(dec.tri_rate(homes[0]) >= Dechets.TRI_BASE, "les habitants trient (%d %%)" % roundi(dec.tri_rate(homes[0]) * 100.0))
	t.call(24.0 * 9.0)
	_check(float(dec.totaux.produit.rec) > 0.01, "recyclables dans les bacs jaunes")
	_check(float(dec.totaux.collecte.rec) > 0.0 or float(dec.totaux.collecte.verre) > 0.0, "bennes de recyclables")
	_check(float(dec.totaux.trie) > 0.0, "le centre de tri trie (%.2f t)" % float(dec.totaux.trie))
	_check(float(dec.totaux.recycle) > 0.0 and prod.sites.has(tri), "balles de tri et verre dans l'économie (%.2f t)" % float(dec.totaux.recycle))
	_check(dec.bilan().taux_recyclage >= 0.0, "taux de recyclage calculé (%d %%)" % roundi(float(dec.bilan().taux_recyclage) * 100.0))

	# Incinérateur : électricité.
	var inc := _place(bs, "usine_incineration", -500, false)
	_check(inc > 0, "incinérateur posé")
	dec._sync()
	dec._receive(inc, "om", 50.0)
	t.call(2.0)
	_check(not dec.electricite_sources().is_empty() and float(dec.sites[inc].mw) > 0.5,
		"électricité de l'incinération : %.1f MW" % float(dec.sites[inc].mw))

	# Budget : entretien et taxe d'ordures ménagères.
	var e := dec.budget_entretien()
	var r := dec.budget_recettes()
	_check(float(e.get("Collecte des déchets", 0.0)) > 0.0 and float(r.get("Taxe d'ordures ménagères", 0.0)) > 0.0, "coûts et recettes pour le budget")

	# Sauvegarde.
	var d := dec.to_dict()
	var back: Dictionary = JSON.parse_string(JSON.stringify(d))
	var before := float(dec.sites[dch].total)
	var n_bacs := dec.bacs.size()
	dec.from_dict(back)
	_check(absf(float(dec.sites[dch].total) - before) < 0.01 and dec.bacs.size() == n_bacs, "sauvegarde relue (décharge, bacs)")

	# Décharge pleine, puis recouverte.
	dec._bury(dch, 200_000.0)
	_check(bool(dec.sites[dch].plein), "décharge pleine")
	_check(dec._dest_for("om", dec._pos_of(dep)) == inc, "les ordures partent à l'incinérateur")
	_check(dec.recouvrir(dch), "recouvrir la décharge")
	_check(String(bs.buildings[dch].t) == "decharge_fermee" and String(dec.sites[dch].role) == "decharge_fermee", "colline verte à la place")

	# Panneau.
	var panel: DechetsPanel = scene.dechets_panel
	for v in ["ville", "sites", "tournees"]:
		panel.view = v
		panel.set_open(true)
		_check(panel._body.get_child_count() > 0, "panneau, vue %s" % v)
	panel.set_open(false)

	# Admin : déchets coupés.
	ReglagesPartie.actuel.dechets = false
	var prod_before := float(dec.today.produit.om)
	t.call(6.0)
	_check(absf(float(dec.today.produit.om) - prod_before) < 0.0001 or dec.today.produit.om == 0.0, "réglage Admin : plus de déchets")
	ReglagesPartie.actuel.dechets = true
	var rg := ReglagesPartie.new()
	rg.dechets = false
	rg.dechets_quantite = 2.5
	var rg2 := ReglagesPartie.new()
	rg2.from_dict(rg.to_dict())
	_check(not rg2.dechets and absf(rg2.dechets_quantite - 2.5) < 0.001, "réglages Admin sauvegardés")
	scene.queue_free()
	await process_frame
