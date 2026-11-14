extends SceneTree
## Test du trafic : formule des bouchons, trajets des habitants affectés au
## réseau, voitures visibles ralenties, stationnement, remplissage des lignes,
## voies de bus, fermetures, tarifs, flux pour les autres systèmes, panneau,
## carte et sauvegarde.
## Usage : godot --headless --path . --script res://tests/trafic_test.gd

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


func _run() -> void:
	print("Formules :")
	_check(is_equal_approx(Trafic.bpr(0.0), 1.0) and absf(Trafic.bpr(1.0) - 1.15) < 0.001, "BPR : 1 à vide, 1,15 à saturation")
	_check(Trafic.bpr(2.0) > 3.0, "BPR : très lent à 200 %% (×%.1f)" % Trafic.bpr(2.0))
	_check(Trafic.hour_profile(8.0) > 0.95 and Trafic.hour_profile(3.0) < 0.1 and Trafic.hour_profile(17.5) > 0.85, "pointes du matin et du soir, nuit calme")
	_check(TraficOverlay.color_for(0.1).g > TraficOverlay.color_for(0.1).r and TraficOverlay.color_for(1.4).r > 0.6, "couleurs : vert fluide, rouge bouché")

	Creations.persist = false
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
	world.set_origin(48.8584, 2.2945)
	for i in 3000:
		await process_frame
		if i >= 120 and world.missing_chunk_count() == 0 and world._dirty.is_empty() and world._jobs.is_empty():
			break
	var pop: Population = scene.population
	var tf: Trafic = scene.trafic
	_check(tf != null and pop.trafic == tf and transport.traffic.model == tf, "trafic branché (habitants, circulation)")
	_check(scene.trafic_panel != null and scene.trafic_overlay != null, "panneau et carte du trafic")
	tf.set_process(false)
	amb.set_speed(0)
	amb.unix_time = _at("2026-03-10", 10.0)
	bs.unlimited_money = true

	print("Quartier :")
	var y := world.cell_height(Vector2i(0, 0))
	var road := transport.build_segment("rue", Vector3(-900, y, 0), Vector3(0, y, 0))
	var road2 := transport.build_segment("rue", Vector3(0, y, 0), Vector3(900, y, 0))
	_check(road.ok and road2.ok, "une rue de 1,8 km (%s)" % road.get("reason", ""))
	var homes := []
	for i in 10:
		homes.append(bs.place("immeuble", Vector2i(-860 + i * 24, 16), bs.best_rotation("immeuble", Vector2i(-860 + i * 24, 16))))
	var jobs := []
	for i in 6:
		jobs.append(bs.place("bureaux", Vector2i(700 + i * 30, -20), bs.best_rotation("bureaux", Vector2i(700 + i * 30, -20))))
	_check(not homes.has(-1) and not jobs.has(-1), "10 immeubles à l'ouest, 6 immeubles de bureaux à l'est")
	if homes.has(-1) or jobs.has(-1):
		print("TEST ÉCHEC")
		quit(1)
		return
	pop._sync_buildings()
	for i in 72:
		pop.advance(300.0)
	_check(pop.persons.size() > 100, "%d habitants" % pop.persons.size())
	var a_home := tf.access_of(int(homes[0]))
	_check(not a_home.is_empty() and float(a_home.walk) < 60.0, "chaque bâtiment trouve sa rue (%d m)" % roundi(float(a_home.get("walk", -1))))

	print("Trajets et bouchons :")
	for i in 3:
		tf.run_cycle()
	var s := tf.stats
	_check(int(s.get("trips", 0)) > 50, "%d trajets domicile-travail relevés" % int(s.get("trips", 0)))
	_check(int(s.modes.voiture) > 0, "%d en voiture, %d à vélo, %d à pied, %d en commun" % [s.modes.voiture, s.modes.velo, s.modes.pied, s.modes.commun])
	var loaded := 0
	var e_main := -1
	for eid in transport.network.edges:
		if tf.edge_flow(eid) > 0.0:
			loaded += 1
			if e_main < 0 or tf.edge_flow(eid) > tf.edge_flow(e_main):
				e_main = eid
	_check(loaded > 0 and e_main >= 0, "les voitures sont affectées à la rue (%d tronçons, %d véh/h au plus chargé)" % [loaded, roundi(tf.edge_flow(e_main))])
	_check(absf(tf.capacity(e_main) - 500.0) < 1.0, "capacité d'une rue : 500 véh/h par sens")
	# Un habitant qui va au travail en voiture.
	var driver := {}
	for pid in pop.persons:
		var p: Dictionary = pop.persons[pid]
		if pop.stage(p) == "actif" and String(pop.commute(p, pop.home_of(p), int(p.job)).mode).begins_with("en voiture"):
			driver = p
			break
	_check(not driver.is_empty(), "au moins un automobiliste")
	var c0 := pop.commute(driver, pop.home_of(driver), int(driver.job))
	# Embouteillage : la rue reçoit trois fois sa capacité.
	for k in tf.flow.keys():
		tf.flow[k] = float(tf.flow[k]) * 0.0 + 1500.0
	tf._edge_cost.clear()
	tf._prepare_assign()
	while tf._phase == "affectation":
		tf._assign_one()
	for k in tf._new_time:
		tf.od_time[k] = tf._new_time[k]
	var c1 := pop.commute(driver, pop.home_of(driver), int(driver.job))
	var t1 := tf.car_trip(pop.home_of(driver), int(driver.job), float(c1.m))
	_check(float(t1.delay) > 5.0, "rue saturée : %d min perdues dans les bouchons (avant %d min de trajet)" % [roundi(float(t1.delay)), int(c0.min)])
	amb.unix_time = _at("2026-03-10", 8.0)
	pop._now = {}
	var v := {"node": int(transport.network.edges[e_main].a)}
	var f8 := tf._visible_factor(e_main, v)
	amb.unix_time = _at("2026-03-10", 3.0)
	pop._now = {}
	var f3 := tf._visible_factor(e_main, v)
	_check(f8 < 0.5 and is_equal_approx(f3, 1.0), "voitures visibles : %.0f %% de la vitesse à 8 h, 100 %% à 3 h" % (f8 * 100.0))
	_check(transport.traffic.speed_factor(e_main, v) == f3, "facteur branché dans la circulation")
	amb.unix_time = _at("2026-03-10", 8.0)
	pop._now = {}
	_check(transport.traffic.flux(e_main) > 1000.0 and transport.traffic.flux_all().has(e_main), "flux pour la pollution : %d véh/h" % roundi(transport.traffic.flux(e_main)))
	_check(transport.traffic.flux_lourds(e_main) > 0.0, "poids lourds pour le bruit")

	print("Stationnement :")
	tf.run_cycle()
	_check(float(tf.stats.get("parking_places", 0.0)) > 100.0, "%d places le long des trottoirs" % roundi(float(tf.stats.parking_places)))
	var pk := tf.parking_for(int(jobs[0]))
	_check(pk.has("search"), "temps pour se garer devant les bureaux : %.1f min" % float(pk.search))
	var st := transport.stations
	var jp: Vector3 = pop.known[int(jobs[0])].pos
	var p1 := st.place("parking", Vector3(jp.x + 15.0, y, 0))
	_check(p1.ok and transport.traffic.parkings.size() == 1, "parking construit (%s)" % p1.get("reason", "ok"))
	tf.parking_fares[int(p1.id)] = 4.0
	# Tout le quartier vient se garer : il faut payer.
	var cell := tf._park_cell(int(jobs[0]))
	tf._acc.arrive = {int(jobs[0]): 2000}
	tf._compute_parking(1.0)
	var pc: Dictionary = tf.park_cells.get(cell, {})
	_check(float(pc.get("occ", 0.0)) > 1.0 and float(pc.get("search", 0.0)) > 6.0, "quartier plein : %.0f min pour trouver une place" % float(pc.get("search", 0.0)))
	_check(float(pc.get("cost", 0.0)) > 0.0 and float(tf.stats.parking_revenue_day) > 0.0, "parking payant : %.2f € par jour encaissés" % float(tf.stats.parking_revenue_day))

	print("Transports en commun :")
	var b1 := st.place("arret_bus", Vector3(-750, y, 0))
	var b2 := st.place("arret_bus", Vector3(650, y, 0))
	_check(b1.ok and b2.ok, "deux arrêts de bus aux deux bouts")
	var ln := st.create_line([b1.id, b2.id], "bus_urbain", 2)
	_check(ln.ok, "ligne de bus urbain, 2 bus")
	tf.run_cycle()
	tf.run_cycle()
	var ll: Dictionary = tf.line_load.get(int(ln.id), {})
	_check(not ll.is_empty() and int(ll.places) == 100 and float(ll.cap) > 100.0, "capacité de la ligne : %d places/h (bus de %d places)" % [roundi(float(ll.get("cap", 0))), int(ll.get("places", 0))])
	_check(int(tf.stats.modes.commun) > 0, "%d habitants prennent le bus" % int(tf.stats.modes.commun))
	_check(float(tf.stats.get("fare_day", 0.0)) > 0.0, "tickets : %.2f € par jour" % float(tf.stats.fare_day))
	# Bus bondé : attente en plus.
	tf._acc.riders = {int(ln.id): 20000}
	tf._compute_lines()
	_check(float(st.planner.extra_wait.get(int(ln.id), 0.0)) > 60.0, "bus plein : %d min d'attente en plus" % roundi(float(st.planner.extra_wait.get(int(ln.id), 0.0)) / 60.0))
	# Voie de bus : le bus échappe aux bouchons, les voitures perdent une voie.
	var bus_edge := -1
	for eid in tf._route_edges(int(ln.id)):
		bus_edge = eid
		break
	_check(bus_edge >= 0, "la ligne roule sur la rue")
	tf.flow[bus_edge * 2] = 1500.0
	tf.flow[bus_edge * 2 + 1] = 1500.0
	e_main = bus_edge
	var before := tf.bus_factor(bus_edge)
	tf.set_bus_lane(bus_edge, true)
	_check(before > 2.0 and is_equal_approx(tf.bus_factor(bus_edge), 1.0), "voie de bus : ×%.1f → ×1 dans les bouchons" % before)
	var line_v := {"node": int(transport.network.edges[bus_edge].a), "line": int(ln.id)}
	_check(is_equal_approx(tf._visible_factor(bus_edge, line_v), 1.0), "le bus visible roule à pleine vitesse sur sa voie")
	tf.set_bus_lane(bus_edge, false)
	# Ticket plus cher : moins de voyageurs.
	tf._acc.riders = {}
	tf.fares[int(ln.id)] = 0.0
	pop._transit_cache.clear()
	tf.run_cycle()
	var free_riders := int(tf.stats.modes.commun)
	tf.fares[int(ln.id)] = 8.0
	pop._transit_cache.clear()
	tf.run_cycle()
	_check(int(tf.stats.modes.commun) <= free_riders, "ticket à 8 € : %d voyageurs au lieu de %d gratuit" % [int(tf.stats.modes.commun), free_riders])
	tf.fares.erase(int(ln.id))

	print("Fermeture :")
	tf.fermer(e_main, "manifestation")
	_check(transport.network.closed_edges.has(e_main) and tf.closures.has(e_main), "route fermée pour une manifestation")
	tf.rouvrir(e_main)
	_check(not transport.network.closed_edges.has(e_main), "route rouverte")

	print("Avis et budget :")
	_check(tf.is_in_group("avis_sources") and (tf.avis_facteurs()[0].f as Callable).is_valid(), "source d'avis « transports »")
	var av: Array = tf.avis_de(driver)
	_check(av.size() == 2, "avis d'un automobiliste : %s" % str(av[1]))
	var eco_ent: Dictionary = scene.lignes_eco.budget_entretien()
	_check(tf.budget_entretien().is_empty() and float(eco_ent.get("Exploitation des lignes", 0.0)) >= 12000.0,
		"exploitation des 2 bus comptée par le bilan des lignes : %d € par mois" % roundi(float(eco_ent.get("Exploitation des lignes", 0.0))))

	print("Panneau et carte :")
	var panel: TraficPanel = scene.trafic_panel
	panel.set_open(true)
	for vw in ["bilan", "bouchons", "parkings", "lignes"]:
		panel.show_view(vw)
	panel.picked = e_main
	panel.show_view("bouchons")
	_check(panel.is_open() and panel._body.get_child_count() > 3, "quatre onglets affichés")
	scene.trafic_overlay.set_shown(true)
	_check(scene.trafic_overlay.mesh != null, "carte du trafic dessinée sur les routes")
	scene.trafic_overlay.set_shown(false)
	panel.set_open(false)

	print("Sauvegarde :")
	tf.fares[int(ln.id)] = 2.0
	tf.set_bus_lane(bus_edge, true)
	tf.fermer(e_main, "travaux")
	var d := tf.to_dict()
	tf.from_dict(JSON.parse_string(JSON.stringify(d)))
	_check(is_equal_approx(tf.fare_of(int(ln.id)), 2.0) and tf.bus_lanes.has(bus_edge) and tf.closures.has(e_main), "tarifs, voies de bus et fermetures retrouvés")
	_check(scene.save_sections().has("trafic"), "section « trafic » dans la sauvegarde")
	scene.queue_free()
	print("TEST OK" if ok else "TEST ÉCHEC")
	quit(0 if ok else 1)
