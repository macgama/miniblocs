extends SceneTree
## Test « Faire évoluer une route » : gabarits (bus, tram, trottoirs, terre-plein),
## devis, travaux sur place (nœuds et carrefours gardés), refus si un bâtiment
## gêne, tramway dans l'axe (vraie voie de tram), coupe, sauvegarde, démolition
## et panneau.
## Usage : godot --headless --path . --script res://tests/evolution_voies_test.gd

var ok := true


func _initialize() -> void:
	_run.call_deferred()


func _check(cond: bool, what: String) -> void:
	if not cond:
		push_error("ÉCHEC : " + what)
		ok = false
	else:
		print("  ok  ", what)


func _fake_tile(_t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(40.0)
	return a


func _sr_count(net: TransportNetwork) -> int:
	var n := 0
	for id in net.edges:
		if bool((net.edges[id].w as Dictionary).get("sr", false)):
			n += 1
	return n


func _run() -> void:
	Creations.persist = false
	ReglagesPartie.actuel = ReglagesPartie.preset("normal")
	var T := TransportTypes
	print("Gabarits :")
	_check(is_equal_approx(T.width_of("rue", {}), 9.0), "rue : 9 m")
	_check(is_equal_approx(T.width_of("rue", {"bus": true}), 16.0), "rue + couloirs de bus : 16 m")
	_check(is_equal_approx(T.width_of("rue", {"tram": true}), 16.0), "rue + tram au milieu : 16 m")
	_check(is_equal_approx(T.width_of("rue", {"bords": "aucun"}), 6.6), "rue sans trottoirs : 6,6 m")
	_check(is_equal_approx(T.width_of("departementale", {"lanes": 2}), 17.5), "départementale 2 × 2 voies : 17,5 m (terre-plein 2 m)")
	_check(is_equal_approx(T.width_of("avenue", {"lanes": 2, "tp": false}), 17.0), "avenue 2 × 2 sans terre-plein : 17 m")
	_check(not T.normalize("rue", {"bords": "trottoir", "tp": false}).has("bords"), "les réglages égaux à la classe ne sont pas gardés")
	_check(not T.normalize("autoroute", {"bus": true, "tram": true, "bords": "aucun"}).has("bus"), "pas de bus ni de tram sur l'autoroute")
	_check(T.evolutions_of("rue").has("avenue") and not T.evolutions_of("rue").has("autoroute"), "une rue peut devenir une avenue, pas une autoroute")
	_check(T.bus_lane_offset("avenue", {"lanes": 1, "lane_w": 3.0, "bus": true}) > 3.0, "couloir de bus à droite des voitures")
	var m := TransportView.build_mesh("avenue", {"lanes": 2, "bus": true, "tram": true}, PackedVector3Array([Vector3(0, 40, 0), Vector3(0, 40, 40)]),
		PackedByteArray([0, 0]), Callable())
	_check(m.get_surface_count() > 0, "avenue avec bus et tram dessinée")

	print("Partie :")
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var transport: TransportSystem = scene.get_node("Transport")
	var bs: BuildingSystem = scene.get_node("Batiments")
	root.add_child(scene)
	world.tiles.offline_generator = _fake_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.set_origin(48.8584, 2.2945)
	for i in 90:
		await process_frame
	var ev: EvolutionVoies = scene.get_node("EvolutionVoies")
	var panel: EvolutionPanel = scene.get_node("PanneauEvolution")
	var suivi: SuiviChantiers = scene.get_node("Chantiers")
	var trafic: Trafic = scene.get_node("Trafic")
	_check(ev != null and panel != null and EvolutionVoies.instance == ev, "nœuds EvolutionVoies et PanneauEvolution")
	_check(not Chantiers.instantanes(), "chantiers en temps réel")
	var net := transport.network
	var ya := world.cell_height(Vector2i(0, 0))
	var a := transport.build_segment("rue", Vector3(0, ya, -100), Vector3(0, ya, 100))
	var b := transport.build_segment("rue", Vector3(-100, ya, 0), Vector3(100, ya, 0))
	_check(a.ok and b.ok, "deux rues qui se croisent")
	await process_frame
	var junction := -1
	for nid in net.nodes:
		if net.degree(nid) == 4:
			junction = nid
	_check(junction >= 0, "carrefour à 4 branches")
	var eid: int = (net.adjacency[junction] as Array)[0]
	var e0: Dictionary = net.edges[eid]
	var ends := [int(e0.a), int(e0.b)]
	var others := {}
	for o in net.edges:
		if o != eid:
			others[o] = net.edges[o]

	print("Devis :")
	var d := ev.devis(eid, "rue", e0.w)
	_check(not d.ok and String(d.reason).contains("Rien"), "rien à changer : pas de devis")
	d = ev.devis(eid, "avenue", {"lanes": 2})
	_check(d.ok and int(d.cout) > 0 and float(d.apres) > float(d.avant), "rue → avenue 2 × 2 voies : %s, %s m → %s m" % [BuildingSystem.format_money(int(d.cout)), d.avant, d.apres])
	_check(not ev.devis(eid, "autoroute", {}).ok, "une rue ne devient pas une autoroute")
	var d_tram := ev.devis(eid, "rue", {"tram": true})
	_check(d_tram.ok and int(d_tram.cout) > int(d.cout), "le tramway coûte plus cher (%s)" % BuildingSystem.format_money(int(d_tram.cout)))

	print("Travaux :")
	bs.unlimited_money = false
	bs.money = 50_000_000
	var cap0 := trafic.capacity(eid)
	var res := ev.lancer(eid, "avenue", {"lanes": 2, "bus": true})
	_check(res.ok, "travaux lancés (%s)" % String(res.get("reason", "")))
	var e1: Dictionary = net.edges[eid]
	_check(String(e1.t) == "avenue" and int(e1.w.lanes) == 2 and bool(e1.w.get("bus", false)), "nouveau profil posé tout de suite")
	_check(int(e1.a) == ends[0] and int(e1.b) == ends[1] and net.degree(junction) == 4, "mêmes nœuds : carrefour gardé")
	var same := true
	for o in others:
		if not net.edges.has(o) or not is_same(net.edges[o], others[o]):
			same = false
	_check(same, "les autres tronçons ne bougent pas")
	_check(ev.en_travaux(eid) and suivi.en_cours(EvolutionVoies.cle(eid)), "chantier en cours")
	_check(not net.find_route(ends[0], ends[1]).is_empty(), "la route reste ouverte pendant les travaux")
	_check(trafic.capacity(eid) < trafic.capacity(eid) * 2.0 and trafic.has_bus_lane(eid), "couloir de bus reconnu par le trafic")
	_check(not ev.lancer(eid, "avenue", {"lanes": 1}).ok, "pas deux chantiers à la fois")
	var tsave := transport.to_dict()
	_check((tsave.edges as Array).any(func(r: Dictionary) -> bool: return r.has("evo")), "travaux gardés dans la sauvegarde")
	var argent := bs.money
	suivi.terminer(EvolutionVoies.cle(eid))
	await process_frame
	_check(not ev.en_travaux(eid), "travaux terminés")
	_check(bs.money < argent, "payé : %s" % BuildingSystem.format_money(argent - bs.money))
	_check(trafic.capacity(eid) > cap0, "plus de capacité qu'avant (%d → %d véh/h)" % [roundi(cap0), roundi(trafic.capacity(eid))])

	print("Tramway :")
	var eid2: int = -1
	for o in net.adjacency[junction]:
		var dir := net.node_pos(net.other_end(o, junction)) - net.node_pos(junction)
		if dir.x > 50.0:
			eid2 = o
	_check(eid2 >= 0, "rue est-ouest choisie")
	res = ev.lancer(eid2, "rue", {"tram": true})
	_check(res.ok, "tramway lancé")
	_check(_sr_count(net) == 0, "pas de tram avant la fin des travaux")
	suivi.terminer(EvolutionVoies.cle(eid2))
	await process_frame
	var tid := ev.tram_de(eid2)
	_check(tid >= 0 and String(net.edges[tid].t) == "tram", "voie de tram posée dans l'axe de la rue")
	var te: Dictionary = net.edges[tid]
	_check(net.node_mode(int(te.a)) == TransportTypes.Mode.RAIL and not net.find_route(int(te.a), int(te.b)).is_empty(), "les trams peuvent y rouler")
	var stop := transport.stations.place("arret_tram", net.point_at(tid, float(te.len) * 0.5))
	_check(bool(stop.get("ok", false)), "arrêt de tram posé sur la rue (%s)" % String(stop.get("reason", "")))
	# Une rue qui coupe la rue du tram : deux tronçons, deux voies de tram.
	var cut := transport.build_segment("rue", Vector3(60, ya, -40), Vector3(60, ya, 40))
	_check(cut.ok, "rue qui coupe la rue du tram (%s)" % String(cut.get("reason", "")))
	await process_frame
	_check(_sr_count(net) == 2, "le tram suit la coupe (%d voies)" % _sr_count(net))

	print("Bâtiment gênant :")
	var eid3 := -1
	for o in net.adjacency[junction]:
		var dir2 := net.node_pos(net.other_end(o, junction)) - net.node_pos(junction)
		if dir2.z > 50.0:
			eid3 = o
	bs.unlimited_money = true
	var p3 := net.point_at(eid3, float(net.edges[eid3].len) * 0.5)
	var bid := -1
	for dx in range(8, 20):
		bid = bs.place("maison", Vector2i(roundi(p3.x) + dx, roundi(p3.z)), 0)
		if bid > 0:
			break
	_check(bid > 0, "maison au bord de la rue")
	var gene := ev.devis(eid3, "avenue", {"lanes": 3, "bus": true, "tram": true})
	_check(not gene.ok and String(gene.reason).contains("bâtiment"), "élargissement refusé : %s" % String(gene.reason))
	_check(ev.devis(eid3, "rue", {"bords": "aucun"}).ok, "rétrécir reste possible")

	print("Panneau :")
	panel.open_for(eid3)
	_check(panel.is_open() and panel.t == "rue", "panneau ouvert sur la rue (%s, %s)" % [panel.is_open(), panel.t])
	panel._lanes.value = 2
	_check(panel.t == "avenue" and int(panel.reglages().lanes) == 2, "2 voies par sens : la rue devient une avenue")
	panel._bords.select(2)
	panel._bords.item_selected.emit(2)
	_check(String(panel.reglages().get("bords", "")) == "aucun", "trottoirs supprimés dans le panneau")
	panel.close()
	transport.set_upgrade()
	_check(transport.tool == TransportSystem.Tool.UPGRADE, "outil Faire évoluer")
	transport.set_inactive()

	print("Démolition et chargement :")
	var nb_sr := _sr_count(net)
	for o in net.edges.keys():
		if net.edges.has(o) and T.has_tram(String(net.edges[o].t), net.edges[o].w):
			transport.demolish(o)
			break
	await process_frame
	_check(_sr_count(net) == nb_sr - 1, "route démolie : son tram aussi")
	res = ev.lancer(eid3, "rue", {"bus": false, "bords": "accotement"})
	_check(res.ok, "nouveau chantier avant sauvegarde")
	var data := transport.to_dict()
	transport.from_dict(JSON.parse_string(JSON.stringify(data)))
	await process_frame
	_check(ev.en_travaux(eid3) and suivi.en_cours(EvolutionVoies.cle(eid3)), "chantier repris au chargement")
	ev.finir_tout()
	await process_frame
	_check(not ev.en_travaux(eid3) and T.side_kind_of(String(net.edges[eid3].t), net.edges[eid3].w) == "accotement", "fini après chargement")

	print("EVOLUTION VOIES TEST OK" if ok else "EVOLUTION VOIES TEST ÉCHEC")
	quit(0 if ok else 1)
