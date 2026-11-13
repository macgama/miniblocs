extends SceneTree
## Test des réseaux : électricité, eau potable, égouts.
## - ReseauBase seul : raccordement, tronçons qui se touchent, partage de la production.
## - Dans la scène Terre : routes qui portent la desserte, bâtiments des réseaux,
##   solaire jour/nuit, ligne MT vers un hameau isolé, coupures (fenêtres noires,
##   satisfaction, usines au ralenti), rejet d'égout qui pollue le captage,
##   départ des foyers après 7 jours, factures, sauvegarde, réglage Admin.
## Usage : godot --headless --path . --script res://tests/reseaux_test.gd

var ok := true


class SourceTest:
	extends Node
	var bid := -1
	var mw := 0.0
	func electricite_sources() -> Array:
		return [{"bid": bid, "mw": mw, "nom": "Test"}] if bid >= 0 else []


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


func _place(bs: BuildingSystem, id: String, x: int, z_side := -1, road_z := 0) -> int:
	var d := int(BuildingCatalog.get_type(id).d)
	var c := Vector2i(x, road_z + z_side * (d / 2 + 6))
	return bs.place(id, c, bs.best_rotation(id, c))


func _base() -> void:
	print("ReseauBase :")
	var r := ReseauBase.new("test")
	var a := r.poser_troncon(PackedVector3Array([Vector3(0, 0, 0), Vector3(100, 0, 0)]), "x")
	# Un second tronçon qui part du milieu du premier (en T).
	r.poser_troncon(PackedVector3Array([Vector3(50, 0, 2), Vector3(50, 0, 200)]), "x")
	# Un tronçon isolé.
	r.poser_troncon(PackedVector3Array([Vector3(500, 0, 0), Vector3(600, 0, 0)]), "x")
	r.ajouter_source(1, Vector3(0, 0, 10), 10.0)
	r.ajouter_conso(2, Vector3(60, 0, 190), 4.0)
	r.ajouter_conso(3, Vector3(100, 0, -20), 4.0)
	r.ajouter_conso(4, Vector3(550, 0, 10), 4.0)
	r.ajouter_conso(5, Vector3(300, 0, 300), 4.0)
	r.recalculer()
	_check(r.est_raccorde(2) and r.est_raccorde(3) and r.composante_de(2) == r.composante_de(1), "tronçons en T : même réseau")
	_check(r.taux_servi(2) == 1.0 and r.taux_servi(3) == 1.0, "10 pour 8 demandés : tout le monde servi")
	_check(r.est_raccorde(4) and r.taux_servi(4) == 0.0, "tronçon isolé sans source : coupé")
	_check(not r.est_raccorde(5), "loin de tout : pas raccordé")
	r.set_capacite(1, 4.0)
	r.rebilan()
	_check(absf(r.taux_servi(2) - 0.5) < 0.001, "4 pour 8 demandés : chacun reçoit la moitié")
	var routes := [PackedVector3Array([Vector3(500, 0, 0), Vector3(500, 0, -300), Vector3(0, 0, -300), Vector3(0, 0, 0)])]
	r.recalculer(routes)
	_check(r.composante_de(4) == r.composante_de(1), "une route relie le tronçon isolé au réseau")
	r.terminer_troncon(a)
	var d := r.to_dict()
	var r2 := ReseauBase.new("test")
	r2.from_dict(JSON.parse_string(JSON.stringify(d)))
	_check(r2.troncons.size() == 3 and (r2.troncons[a].pts as PackedVector3Array).size() == 2 and r2.next_id == r.next_id, "sauvegarde des tronçons")


func _run() -> void:
	Creations.persist = false
	_base()

	BatimentsVie.chantiers = false
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var transport: TransportSystem = scene.get_node("Transport")
	var bs: BuildingSystem = scene.get_node("Batiments")
	var amb: DayNight = scene.get_node("Ambiance")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.view_radius_override = 900.0
	world.set_origin(45.75, 4.85)
	for i in 3000:
		await process_frame
		if i >= 150 and world.missing_chunk_count() == 0 and world._dirty.is_empty() and world._jobs.is_empty():
			break
	var res: Reseaux = scene.reseaux
	var pop: Population = scene.population
	_check(res != null and Reseaux.instance == res and res.population == pop, "réseaux branchés dans la scène")
	var n_bible := 0
	for id in ReseauxTypes.BIBLE:
		if BuildingCatalog.get_type(id).has("glb"):
			n_bible += 1
			_check(String(BuildingCatalog.get_type(id).cat) == "reseaux" and not BuildingCatalog.get_type(id).has("zone"), "%s (modèle Blender) devient un bâtiment des réseaux" % id)
	_check(BuildingCatalog.ids_in("reseaux").size() == ReseauxTypes.ORDER.size() + n_bible, "%d bâtiments dans la catégorie Réseaux" % BuildingCatalog.ids_in("reseaux").size())
	_check(not ReseauxTypes.info("chateau_eau").is_empty(), "le château d'eau des services publics sert de réserve")
	for id in ReseauxTypes.ORDER:
		var m := BuildingCatalog.build_mesh(id)
		if m == null or m.get_surface_count() == 0:
			_check(false, "modèle de %s" % id)
	ReglagesPartie.actuel.reseaux_obligatoires = true
	amb.set_speed(0)
	amb.unix_time = _at("2026-06-21", 13.0)
	bs.money = 5_000_000_000

	print("Règles de pose :")
	_check(not bs.check_place("captage_eau", Vector2i(0, -40), 0).ok and String(bs.check_place("captage_eau", Vector2i(0, -40), 0).reason).contains("rivière"), "captage refusé loin de l'eau")
	_check(String(bs.check_place("poste_national", Vector2i(0, -40), 0).reason).contains("bord"), "raccordement national refusé au milieu de la carte")

	print("Ville sans réseau :")
	var y := world.cell_height(Vector2i(0, 0))
	_check(transport.build_segment("route", Vector3(-400, y, 0), Vector3(400, y, 0)).ok, "route est-ouest")
	var homes := []
	for i in 6:
		homes.append(_place(bs, "immeuble", -300 + i * 40, 1))
	var usine := _place(bs, "scierie", 200, -1)
	var forage := _place(bs, "forage_eau", -100, -1)
	var rejet := _place(bs, "exutoire_egout", -150, -1)
	_check(not homes.has(-1) and usine > 0 and forage > 0 and rejet > 0, "6 immeubles, une scierie, un forage, un rejet d'égout")
	await process_frame
	pop._sync_buildings()
	for i in 60:
		pop.advance(300.0)
	_check(pop.households.size() > 0, "des foyers emménagent : %d" % pop.households.size())
	res.simuler(0.0)
	_check(res.taux(homes[0], "elec") == 0.0, "pas de centrale : pas de courant")
	_check(res.taux(homes[0], "eau") == 0.0, "le forage n'a pas de courant pour pomper : pas d'eau")
	_check(res.taux(homes[0], "egout") == 1.0 and res.bilan("egout").rejets > 0.0, "égouts : tout part à la rivière sans traitement")
	var mi := bs.node_of(homes[0])
	_check(mi != null and bool(mi.get_meta("res_panne", false)), "fenêtres noires sans courant")
	var p0: Dictionary = pop.persons[pop.households[pop.by_home[homes[0]][0]].m[0]]
	var sat := res.satisfaction_of(p0)
	_check(float(sat[0]) <= -25.0 and (sat[1] as Array).has("− pas d'électricité à la maison"), "habitants mécontents : %s" % ", ".join(sat[1]))
	_check(res.rendement(usine) < 0.15, "la scierie est presque à l'arrêt sans courant")
	_check(res.eau_incendie(homes[0]) == 0.0, "bouches d'incendie à sec")

	print("Parc solaire :")
	var solaire := _place(bs, "centrale_solaire", 0, -1)
	_check(solaire > 0, "parc solaire au bord de la route")
	await process_frame
	await process_frame
	res.simuler(0.0)
	var cap_jour := float(res.sources_info.get(solaire, {}).get("cap", 0.0))
	_check(cap_jour > 0.3, "en plein soleil de juin : %.1f MW" % cap_jour)
	_check(res.taux(homes[0], "elec") >= 0.95 and res.taux(homes[0], "eau") >= 0.95, "courant et eau au robinet")
	_check(mi != null and not bool(mi.get_meta("res_panne", false)), "les fenêtres se rallument")
	_check(res.rendement(usine) > 0.9, "la scierie tourne")
	amb.unix_time = _at("2026-06-21", 23.5)
	await process_frame
	await process_frame
	res.simuler(0.0)
	_check(float(res.sources_info[solaire].cap) == 0.0 and res.taux(homes[0], "elec") == 0.0, "la nuit, le solaire ne produit rien")

	print("Château d'eau :")
	var chateau := _place(bs, "chateau_eau", 260, -1)
	_check(chateau > 0, "château d'eau posé")
	await process_frame
	amb.unix_time = _at("2026-06-22", 12.0)
	await process_frame
	await process_frame
	for i in 6:
		res.simuler(1.0)
	var plein := float(res.stocks.get(chateau, 0.0))
	_check(plein > 750.0, "le château d'eau se remplit le jour : %d m³" % roundi(plein))
	amb.unix_time = _at("2026-06-22", 23.5)
	await process_frame
	await process_frame
	res.simuler(1.0)
	_check(res.taux(homes[0], "eau") >= 0.95 and float(res.stocks[chateau]) < plein, "la nuit, le château d'eau donne encore de l'eau (%d m³)" % roundi(res.stocks[chateau]))

	print("Source extérieure (groupe electricite_sources) :")
	var src := SourceTest.new()
	src.add_to_group("electricite_sources")
	scene.add_child(src)
	src.bid = usine
	src.mw = 50.0
	res._sync_sale = true
	res.simuler(0.0)
	_check(res.elec.sources.has(usine) and res.taux(homes[0], "elec") >= 0.95, "une centrale d'un autre système alimente la ville la nuit")

	print("Hameau hors des routes, relié par une ligne MT :")
	var y2 := world.cell_height(Vector2i(0, 300))
	_check(transport.build_segment("route", Vector3(-80, y2, 300), Vector3(80, y2, 300)).ok, "route isolée au sud")
	var hameau := _place(bs, "maison", 0, 1, 300)
	await process_frame
	res.simuler(0.0)
	_check(res.taux(hameau, "elec") == 0.0, "le hameau n'a pas de courant")
	var money0 := bs.money
	var pts := res.trace_sur_relief(Vector3(0, y, 0), Vector3(0, y2, 300))
	ReglagesPartie.actuel.construction_instantanee = false
	var lid := res.poser("ligne_mt", pts)
	_check(lid > 0 and bs.money < money0, "ligne MT posée et payée (%s)" % BuildingSystem.format_money(money0 - bs.money))
	_check(not bool(res.elec.troncons[lid].ok) and not res.chantier_de("elec", lid).is_empty(), "la ligne commence par un chantier")
	res.simuler(0.0)
	_check(res.taux(hameau, "elec") == 0.0, "pendant le chantier, toujours pas de courant au hameau")
	SuiviChantiers.instance.terminer(Reseaux._cle("elec", lid))
	_check(bool(res.elec.troncons[lid].ok), "chantier terminé : ligne en service")
	res.simuler(0.0)
	_check(res.taux(hameau, "elec") >= 0.95, "la ligne MT apporte le courant au hameau")
	var mesh := ReseauxVue.ligne_aerienne(pts, "ligne_mt")
	_check(mesh.get_surface_count() > 0, "poteaux et câbles visibles")
	_check(res.troncon_pres(Vector3(2, y, 150), 8.0).get("id", -1) == lid, "on retrouve la ligne sous la souris")

	print("Pollution : rejet d'égout en amont d'un captage :")
	res.qualite.clear()
	res._maj_qualite()
	_check(float(res.qualite.get(forage, 1.0)) < 0.9, "le forage près du rejet donne une eau polluée (%d %%)" % roundi(float(res.qualite.get(forage, 1.0)) * 100.0))
	res.simuler(0.0)
	_check(res.risque_sante(homes[0]) > 0.05, "risque pour la santé des habitants : %.2f" % res.risque_sante(homes[0]))
	var station := _place(bs, "station_epuration_locale", 120, 1)
	await process_frame
	res.simuler(0.0)
	res.simuler(0.0)
	_check(station > 0 and res.bilan("egout").rejets < 1.0, "avec une station d'épuration, plus rien ne part sans traitement")
	_check(float(res.qualite.get(forage, 0.0)) > 0.95, "l'eau redevient potable")

	print("Factures :")
	var foyer: Dictionary = pop.households[pop.by_home[homes[1]][0]]
	var ep0 := float(foyer.ep)
	var caisse0 := bs.money
	res.compta = {"mois": {}, "precedent": {}, "jours": 0}
	res.simuler(24.0)
	_check(float(foyer.ep) < ep0, "le foyer paie son eau et son électricité (%.2f €)" % (ep0 - float(foyer.ep)))
	_check(float(res.compta.mois.get("Factures d'eau et d'électricité", 0.0)) > 0.0, "la ville touche les factures")
	_check(res.budget_entretien().size() == 3, "entretien des 3 réseaux pour le budget")

	print("Coupure longue :")
	src.bid = -1
	bs.demolish(solaire)
	await process_frame
	res._sync_sale = true
	amb.unix_time = _at("2026-06-23", 23.0)
	await process_frame
	res.simuler(0.0)
	_check(res.taux(homes[2], "elec") == 0.0, "plus de centrale : coupure")
	var avant := pop.households.size()
	for d in 8:
		res.simuler(24.0)
	_check(pop.households.size() < avant and not pop.by_home.has(homes[2]) or (pop.by_home.get(homes[2], []) as Array).is_empty(), "après 7 jours sans courant, les foyers partent (%d → %d)" % [avant, pop.households.size()])

	print("Sauvegarde :")
	var d := res.to_dict()
	var n_t := res.elec.troncons.size()
	res.from_dict(JSON.parse_string(JSON.stringify(d)))
	_check(res.elec.troncons.size() == n_t and res.elec.troncons.has(lid), "tronçons gardés")
	_check(scene.save_sections().has("reseaux"), "section « reseaux » dans la sauvegarde")
	var r := ReglagesPartie.new()
	r.prix_services = 2.5
	r.reseaux_obligatoires = false
	var r2 := ReglagesPartie.new()
	r2.from_dict(r.to_dict())
	_check(r2.prix_services == 2.5 and not r2.reseaux_obligatoires, "réglages Admin des réseaux gardés")
	_check(ReglagesPartie.preset("libre").reseaux_obligatoires == false and ReglagesPartie.preset("normal").reseaux_obligatoires, "bac à sable libre : réseaux non obligatoires")

	print("Réseaux non obligatoires :")
	ReglagesPartie.actuel.reseaux_obligatoires = false
	res.simuler(0.0)
	_check(res.taux(homes[3], "elec") == 1.0 and res.taux(homes[3], "eau") == 1.0, "tout est desservi d'office")
	ReglagesPartie.actuel.reseaux_obligatoires = true

	print("Panneau :")
	var panel: ReseauxPanel = scene.reseaux_panel
	panel.set_open(true)
	for v in ["elec", "eau", "egout", "comptes"]:
		panel.show_view(v)
	var lbl := Label.new()
	panel.ajouter_onglet("Télécom", lbl)
	panel.show_view("x:Télécom")
	_check(lbl.get_parent() != null, "onglet ajouté par un autre système")
	panel.show_view("elec")
	_check(panel.is_open(), "panneau ouvert")
	panel.set_open(false)

	print("TEST OK" if ok else "TEST ÉCHEC")
	quit(0 if ok else 1)
