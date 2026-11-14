extends SceneTree
## Test du compte d'exploitation des lignes : prix des véhicules, achats et
## reventes, refus faute d'argent, recettes des tickets, coûts, vieillissement,
## pannes, renouvellement, fret facturé selon la production, budget communal,
## panneau Lignes et sauvegarde.
## Usage : godot --headless --path . --script res://tests/lignes_eco_test.gd

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
	print("Prix des véhicules :")
	var p_bus := ExploitationLignes.prix("bus_urbain")
	var p_tram := ExploitationLignes.prix("tram_moderne")
	var p_avion := ExploitationLignes.prix("court_courrier")
	_check(p_bus > 150000.0 and p_bus < 600000.0, "bus urbain : %s" % ExploitationLignes.euros(p_bus))
	_check(p_tram > 1.0e6 and p_tram < 6.0e6, "tramway moderne : %s" % ExploitationLignes.euros(p_tram))
	_check(p_avion > 2.0e7, "avion court-courrier : %s" % ExploitationLignes.euros(p_avion))
	var all_priced := true
	for id in VehicleCatalog.TYPES:
		if not VehicleCatalog.TYPES[id].get("hidden", false) and ExploitationLignes.prix(id) <= 0.0:
			all_priced = false
	_check(all_priced, "chaque véhicule du catalogue a un prix")
	_check(ExploitationLignes.facteur_age(1.5) > ExploitationLignes.facteur_age(0.2) and ExploitationLignes.p_panne(1.3) > ExploitationLignes.p_panne(0.3) * 10.0,
		"un vieux véhicule coûte plus d'entretien et tombe plus souvent en panne")

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
	var eco: ExploitationLignes = scene.lignes_eco
	_check(eco != null and ExploitationLignes.instance == eco and tf.lignes_eco == eco, "compte des lignes branché")
	tf.set_process(false)
	eco.set_process(false)
	amb.set_speed(0)
	amb.unix_time = _at("2026-03-10", 10.0)
	bs.unlimited_money = true

	print("Quartier :")
	var y := world.cell_height(Vector2i(0, 0))
	var road := transport.build_segment("rue", Vector3(-900, y, 0), Vector3(0, y, 0))
	var road2 := transport.build_segment("rue", Vector3(0, y, 0), Vector3(900, y, 0))
	_check(road.ok and road2.ok, "une rue de 1,8 km")
	var homes := []
	for i in 10:
		homes.append(bs.place("immeuble", Vector2i(-860 + i * 24, 16), bs.best_rotation("immeuble", Vector2i(-860 + i * 24, 16))))
	var jobs := []
	for i in 6:
		jobs.append(bs.place("bureaux", Vector2i(700 + i * 30, -20), bs.best_rotation("bureaux", Vector2i(700 + i * 30, -20))))
	_check(not homes.has(-1) and not jobs.has(-1), "immeubles à l'ouest, bureaux à l'est")
	pop._sync_buildings()
	for i in 72:
		pop.advance(300.0)
	_check(pop.persons.size() > 100, "%d habitants" % pop.persons.size())

	print("Achats :")
	var st := transport.stations
	var b1 := st.place("arret_bus", Vector3(-750, y, 0))
	var b2 := st.place("arret_bus", Vector3(650, y, 0))
	_check(b1.ok and b2.ok, "deux arrêts de bus")
	bs.unlimited_money = false
	bs.money = 100000
	var refus := st.create_line([b1.id, b2.id], "bus_urbain", 2)
	_check(not refus.ok and String(refus.reason).begins_with("Pas assez d'argent"), "refusée sans argent : %s" % refus.get("reason", ""))
	bs.money = 5000000
	var prix := ExploitationLignes.prix_achat("bus_urbain")
	var ln := st.create_line([b1.id, b2.id], "bus_urbain", 2)
	var lid := int(ln.get("id", -1))
	_check(ln.ok and eco.flottes.has(lid), "ligne de bus créée avec sa flotte")
	_check(absi(bs.money - (5000000 - roundi(2.0 * prix))) <= 2, "2 bus achetés : caisse %d € (prix %s chacun)" % [bs.money, ExploitationLignes.euros(prix)])
	var m0 := bs.money
	st.set_line(lid, "bus_urbain", 3)
	_check(absi(m0 - bs.money - roundi(prix)) <= 2 and (eco.flottes[lid].ages as Array).size() == 3, "un 3e bus acheté")
	# Le plus vieux part quand on réduit la flotte.
	eco.flottes[lid].ages = [0.0, 1000.0, 2000.0]
	m0 = bs.money
	st.set_line(lid, "bus_urbain", 2)
	var rv := ExploitationLignes.valeur("bus_urbain", "bus", 2000.0)
	_check(absi(bs.money - m0 - roundi(rv)) <= 2 and not (eco.flottes[lid].ages as Array).has(2000.0), "le plus vieux bus revendu %s" % ExploitationLignes.euros(rv))
	bs.money = 1000
	st.set_line(lid, "bus_urbain", 6)
	_check(int(st.lines[lid].count) == 2, "pas de nouveaux bus sans argent")
	bs.money = 5000000

	print("Recettes et coûts :")
	pop._transit_cache.clear()
	for i in 4:
		tf.run_cycle()
	print("    trafic : %d voyageurs par jour sur la ligne (choix des habitants)" % int(tf.line_load.get(lid, {}).get("riders", 0)))
	# Le choix du bus par les habitants est testé dans trafic_test ; ici on fixe la fréquentation.
	tf.line_load[lid] = {"riders": 300, "load": 0.3}
	var j := eco.journee(lid)
	_check(int(j.voyageurs) > 0 and float(j.tickets) > 0.0, "%d voyageurs par jour, %s de tickets" % [int(j.voyageurs), ExploitationLignes.euros(float(j.tickets))])
	_check(float(j.exploitation) > 0.0 and float(j.entretien) > 0.0, "personnel et énergie %s, entretien %s par jour" % [ExploitationLignes.euros(float(j.exploitation)), ExploitationLignes.euros(float(j.entretien))])
	var km := eco.km_jour(lid)
	_check(km > 50.0 and km < 400.0, "%d km par jour et par bus" % roundi(km))
	var fare0 := float(j.tickets)
	tf.fares[lid] = 3.0
	_check(float(eco.journee(lid).tickets) > fare0 * 1.5, "ticket à 3 € : plus de recettes par voyageur")
	tf.fares.erase(lid)
	var rec := eco.budget_recettes()
	var ent := eco.budget_entretien()
	_check(rec.has("Tickets de transport") and not tf.budget_recettes().has("Tickets de transport"), "les tickets passent par le bilan des lignes (pas deux fois)")
	_check(ent.has("Exploitation des lignes") and ent.has("Entretien des véhicules"), "exploitation et entretien pour le budget")
	var bil: Dictionary = scene.budget.bilan_mensuel()
	_check(bil.depenses.has("Entretien des véhicules") and bil.recettes.has("Tickets de transport"), "dans le bilan du budget communal")

	print("Jours et vieillissement :")
	var b0 := eco.bilan(lid)
	eco.new_day()
	eco.new_day()
	var b2_ := eco.bilan(lid)
	_check(int(b2_.jours_mois) == 2 and float(b2_.mois) != 0.0, "2 jours comptés : %s" % ExploitationLignes.euros(float(b2_.mois)))
	_check(float(b2_.age_moyen) > float(b0.age_moyen), "les bus vieillissent")
	var vie := ExploitationLignes.vie_jours("bus")
	var ent_neuf := float(eco.journee(lid).entretien)
	eco.flottes[lid].ages = [vie + 400.0, vie + 400.0]
	var j_vieux := eco.journee(lid)
	_check(float(j_vieux.entretien) > ent_neuf * 2.0, "bus usés : entretien %s au lieu de %s par jour" % [ExploitationLignes.euros(float(j_vieux.entretien)), ExploitationLignes.euros(ent_neuf)])
	_check(eco.indisponibilite(lid) > 0.02 and float(j_vieux.tickets) < float(j.tickets), "pannes : %d %% du service perdu" % roundi(eco.indisponibilite(lid) * 100.0))
	var msgs: Array[String] = []
	eco.message.connect(func(t: String) -> void: msgs.append(t))
	eco.new_day()
	_check(msgs.size() == 1 and msgs[0].contains("durée de vie"), "alerte : %s" % (msgs[0] if not msgs.is_empty() else "aucune"))
	eco.new_day()
	_check(msgs.size() == 1, "alerte une seule fois")
	m0 = bs.money
	var cout := eco.renouveler(lid)
	_check(cout > 0.0 and absi(m0 - bs.money - roundi(cout)) <= 2 and float(eco.bilan(lid).age_moyen) < 0.01, "2 bus renouvelés pour %s" % ExploitationLignes.euros(cout))
	eco.set_auto(lid, true)
	eco.flottes[lid].ages = [vie + 1.0, 10.0]
	eco.new_day()
	_check(int(eco.bilan(lid).uses) == 0, "renouvellement automatique")

	print("Fret :")
	var d1 := st.place("depot", Vector3(-400, y, 0))
	var d2 := st.place("depot", Vector3(300, y, 0))
	var fl := st.create_line([d1.id, d2.id], "", 2)
	var fid := int(fl.get("id", -1))
	_check(fl.ok and bool(st.lines[fid].fret), "ligne de camions (%s)" % st.lines.get(fid, {}).get("model", "?"))
	var prod: Production = scene.production
	prod.yesterday = Production._empty_flows()
	st.lines[fid].tonnes = float(eco.flottes[fid].t_vu) + 100.0
	var jf := eco.journee(fid)
	_check(float(jf.t_jour) == 100.0 and float(jf.fret) == 0.0, "sans client, les camions roulent à vide : 0 €")
	prod.yesterday.export = {"bois": 80.0}
	eco.flottes[fid].jour = {"t_jour": 100.0}
	jf = eco.journee(fid)
	_check(float(jf.t_fact) > 0.0 and float(jf.fret) > 0.0, "%s facturées aux entreprises : %s" % [StationSystem.format_tonnes(float(jf.t_fact)), ExploitationLignes.euros(float(jf.fret))])
	eco.new_day()
	_check(float(eco.flottes[fid].t_vu) == float(st.lines[fid].tonnes), "compteur de tonnes repris chaque jour")

	print("Panneau Lignes :")
	var panel: StationPanel = scene.transit_panel
	panel.set_open(true)
	panel._open[lid] = true
	panel._refresh_lines()
	_check(panel._bilans.has(lid) and String((panel._bilans[lid] as Label).text).contains("par mois"), "résumé : %s" % (panel._bilans[lid] as Label).text)
	_check(panel._details.has(lid) and (panel._details[lid] as VBoxContainer).get_child_count() >= 6, "bilan détaillé ouvert")
	_check(panel._total != null and panel._total.text.begins_with("Toutes les lignes"), panel._total.text if panel._total != null else "pas de total")
	panel.set_open(false)

	print("Sauvegarde :")
	eco.flottes[lid].ages = [123.0, 456.0]
	eco.flottes[lid].total = 777.0
	var d := eco.to_dict()
	eco.from_dict(JSON.parse_string(JSON.stringify(d)))
	_check(eco.flottes[lid].ages == [123.0, 456.0] and float(eco.flottes[lid].total) == 777.0 and bool(eco.flottes[lid].auto), "âges, comptes et renouvellement automatique gardés")
	m0 = bs.money
	eco.from_dict({})
	_check(eco.flottes.has(lid) and bs.money == m0 and float(eco.bilan(lid).age_moyen) == 0.0, "ancienne partie : bus repris neufs, sans les payer")
	var sec: Dictionary = scene.save_sections()
	_check(sec.has("lignes_eco"), "section « lignes_eco » dans la sauvegarde")

	print("Suppression :")
	m0 = bs.money
	st.remove_line(lid)
	_check(not eco.flottes.has(lid) and bs.money > m0, "ligne supprimée : bus revendus (+%s)" % ExploitationLignes.euros(float(bs.money - m0)))

	print("LIGNES ECO TEST OK" if ok else "TEST ÉCHEC")
	quit(0 if ok else 1)
