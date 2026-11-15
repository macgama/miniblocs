extends SceneTree
## Test des saisons et des risques naturels : saisons et hémisphères,
## prévisions, neige sur les routes (ralentit, accidents, chasse-neige du
## centre technique, sel), crue lente (bassins de rétention, bâtiments
## inondés, champs), sécheresse (niveaux, restrictions, prés, feux de
## broussailles), canicule, gel tardif, calendrier des cultures, avis,
## réglage Admin, panneau, sauvegarde.
## Usage : godot --headless --path . --script res://tests/saisons_test.gd

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
	_static_tests()
	await _city_tests()
	print("TEST OK" if ok else "TEST ÉCHEC")
	quit(0 if ok else 1)


func _static_tests() -> void:
	print("Catalogue et règles :")
	for id in SaisonsTypes.ORDER:
		var t := BuildingCatalog.get_type(id)
		_check(not t.is_empty() and String(t.cat) == "services", "%s au catalogue (Services publics)" % id)
		var m := BuildingCatalog.build_mesh(id)
		_check(m != null and m.get_surface_count() > 0, "modèle de %s" % id)
		for j in Metiers.jobs_for(id):
			_check(Metiers.METIERS.has(String(j[0])), "%s : métier %s connu" % [id, j[0]])
	_check(SaisonsTypes.role_of("centre_technique") == "deneigement" and SaisonsTypes.role_of("bassin_retention") == "retention",
		"rôles des bâtiments")
	var cn := VehicleCatalog.get_type("chasse_neige")
	_check(not cn.is_empty() and bool(cn.get("livraison", false)), "chasse-neige au catalogue des véhicules")
	_check(not Traffic._no_service(VehicleCatalog.for_track("route")).has("chasse_neige"), "pas de chasse-neige dans la circulation d'ambiance")
	_check(VehicleCatalog.build_mesh("chasse_neige") != null, "modèle du chasse-neige")
	for ic in ["neige", "pluie", "nuage", "fleur", "feuille", "thermometre", "saisons", "chasse_neige"]:
		_check(Icones.SVG.has(ic), "icône %s" % ic)
	# Saisons : 15 janvier, 15 avril, 15 juillet, 15 octobre.
	_check(Saisons.saison_de(14, 46.0) == 0 and Saisons.saison_de(104, 46.0) == 1 and Saisons.saison_de(195, 46.0) == 2
		and Saisons.saison_de(287, 46.0) == 3, "saisons de l'hémisphère nord")
	_check(Saisons.saison_de(14, -34.0) == 2 and Saisons.saison_de(195, -34.0) == 0, "hémisphère sud : été en janvier, hiver en juillet")
	_check(Saisons.saison_pluies(7, 12.0) and not Saisons.saison_pluies(1, 12.0) and Saisons.saison_pluies(1, -12.0), "saison des pluies sous les tropiques")
	_check(Saisons.vigilance_de(20.0) == 0 and Saisons.vigilance_de(50.0) == 1 and Saisons.vigilance_de(80.0) == 2 and Saisons.vigilance_de(120.0) == 3,
		"vigilance crues verte, jaune, orange, rouge")
	_check(Saisons.niveau_de(3.0, 0.0) == 0 and Saisons.niveau_de(9.0, 0.0) == 1 and Saisons.niveau_de(14.0, 0.05) == 2
		and Saisons.niveau_de(25.0, 0.5) == 3 and Saisons.niveau_de(40.0, 0.9) == 4, "niveaux des arrêtés sécheresse")
	_check(Saisons.facteur_neige(0.2) == 1.0 and absf(Saisons.facteur_neige(5.0) - 0.6) < 0.01 and Saisons.facteur_neige(30.0) == 0.3,
		"la neige ralentit : −8 % par cm, au plus −70 %")
	_check(ReglagesPartie.new().neige_routes, "réglage Admin « neige sur les routes » (oui par défaut)")
	var r := ReglagesPartie.new()
	r.neige_routes = false
	_check(not r.duplicate_settings().neige_routes, "le réglage est sauvegardé")


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
	var sa: Saisons = scene.saisons
	var ev: Evenements = scene.evenements
	_check(sa != null and scene.saisons_panel != null and Saisons.instance == sa, "saisons et panneau branchés dans la scène")
	_check(scene.save_sections().has("saisons"), "section « saisons » dans la sauvegarde")
	_check(ev.modules.get("crue") == sa, "les crues passent par les événements")
	var tf := transport.traffic
	var pop: Population = scene.population
	for n in [sa, tf, pop, scene.production, scene.dechets, scene.agriculture]:
		n.set_process(false)
	ev.set_process(false)
	scene.urgences.set_process(false)
	scene.urgences.random_calls = false
	bs.unlimited_money = true
	sa.forcer = 0
	var y := world.cell_height(Vector2i(0, 0))
	var road := transport.build_segment("route", Vector3(-700, y, 0), Vector3(700, y, 0))
	_check(road.ok, "route de 1,4 km")
	var rue := transport.build_segment("rue", Vector3(200, y, 0), Vector3(200, y, 400))
	_check(rue.ok, "rue de 400 m")
	var homes: Array[int] = []
	for i in 8:
		homes.append(_place(bs, "maison", -300 + i * 14))
	_check(not homes.has(-1), "8 maisons posées")
	pop._sync_buildings()
	for bid in homes:
		pop.spawn_household(bid, "famille")
	sa.clock = 1_800_000_000.0

	# --- Saisons et prévisions.
	sa.saison = -1
	sa._saison_du_jour({"doy": 100, "month": 4})
	_check(sa.saison == 1, "printemps en avril à Genève")
	var nj := ev.journal.size()
	sa._saison_du_jour({"doy": 180, "month": 6})
	_check(sa.saison == 2 and ev.journal.size() == nj + 1 and String(ev.journal[0].genre) == "saison", "changement de saison annoncé : %s" % ev.journal[0].texte)
	var pv := sa.previsions()
	_check(pv.size() == 3, "prévisions sur 3 jours sans station météo")
	_check(float(pv[0].tmax) >= float(pv[0].tmin) and String(pv[0].ciel) != "", "prévision : %s, %d° / %d°" % [pv[0].ciel, roundi(float(pv[0].tmin)), roundi(float(pv[0].tmax))])
	var sm := _place(bs, "station_meteo", 150)
	_check(sm > 0 and sa.jours_previsions() == 7, "une station météo donne 7 jours")
	var cal := sa.calendrier()
	var ble := {}
	for c in cal:
		if String(c.id) == "ble":
			ble = c
	_check(not ble.is_empty() and (ble.semis as Array).has(10) and (ble.recolte as Array).has(7), "calendrier : blé semé en octobre, moissonné en juillet")

	# --- Relevés : une heure de neige, un nouveau jour.
	var w: Meteo = scene.ambiance.weather
	w.mode = Meteo.Mode.NEIGE
	w.settle(sa.clock, 8.0)
	sa.aujourdhui = {}
	sa._jour = int(sa.date_locale(sa.clock).j)
	sa._heure(sa.clock)
	_check(float(sa.aujourdhui.neige) > 0.5 and not sa.neige.is_empty(), "une heure de neige : %s cm, et elle tient sur les routes" % Saisons._num(float(sa.aujourdhui.neige)))
	w.mode = Meteo.Mode.SOLEIL
	w.settle(sa.clock, 12.0)
	sa._heure(sa.clock + 86400.0)
	_check(sa.jours.size() == 1 and float(sa.jours[0].neige) > 0.5, "le jour est noté dans l'historique")
	_check(int(sa.records.neige_j) >= 0, "record de neige retenu")

	# --- Neige sur les routes, sans chasse-neige.
	sa.neige.clear()
	sa.chute_de_neige(10.0, 0.0)
	var et := sa.etat_routes()
	_check(absf(float(et.moyenne) - 10.0) < 0.6 and float(et.part) > 0.99, "10 cm sur toutes les routes")
	var eid0: int = sa.neige.keys()[0]
	_check(absf(tf.speed_factor(eid0, {"mode": 0}) - 0.3) < 0.01, "la circulation roule à 30 % de sa vitesse")
	sa._rebuild_mesh()
	_check(sa._mesh.mesh != null, "neige blanche visible sur les routes")
	sa._dispatch(sa.clock)
	_check(sa.missions.is_empty(), "sans centre technique, personne ne déneige")
	var p0: Dictionary = pop.persons[pop.households[pop.by_home[homes[0]][0]].m[0]]
	var av: Array = sa._avis_neige(p0)
	_check(float(av[0]) < 0.0, "habitant mécontent : %s" % ", ".join(av[1]))
	var inc := sa.accident(eid0)
	_check(inc > 0 and String(ev.incident(inc).type) == "accident" and (ev.incident(inc).besoin as Array).has("ambulance"),
		"accident sur la neige : police et ambulance appelées")

	# --- Centre technique : les chasse-neige déneigent et salent.
	var ct := _place(bs, "centre_technique", 0)
	_check(ct > 0 and sa.centres.has(ct), "centre technique posé")
	var sel0 := float(sa.centres[ct].sel)
	sa._dispatch(sa.clock)
	_check(sa.missions.size() >= 1, "les chasse-neige partent (%d tournée%s)" % [sa.missions.size(), "s" if sa.missions.size() > 1 else ""])
	var first: Dictionary = sa.missions.values()[0]
	var prem := int(first.parcours[0].e)
	_check(String(transport.network.edges[prem].t) != "rue", "la route principale passe avant la rue")
	for i in 400:
		sa.clock += 120.0
		sa._avance_tournees(sa.clock)
		if sa.missions.is_empty():
			break
	et = sa.etat_routes()
	_check(sa.missions.is_empty() and float(et.part) < 0.01, "routes déneigées (%d %% encore sous la neige)" % roundi(float(et.part) * 100.0))
	_check(float(sa.centres[ct].sel) < sel0 and float(et.km_sel) > 1.5, "routes salées : %s t de sel" % Saisons._num(sel0 - float(sa.centres[ct].sel)))
	_check(float(sa.totaux.km_deneiges) > 1.5, "%s km déneigés" % Saisons._num(float(sa.totaux.km_deneiges)))
	sa.chute_de_neige(4.0, 0.0)
	_check(sa.etat_routes().part < 0.01, "sur les routes salées, la nouvelle neige ne tient pas")
	var acc := sa.acces(homes[0])
	_check(float(sa._avis_neige(p0)[0]) > 0.0, "habitant content : rue déneigée et salée (%s, sel %s, maintenant %s)" % [str(acc.get("e", -1)), str(sa.sel.get(int(acc.get("e", -1)), 0.0)), str(sa.now())])
	var be := sa.budget_entretien()
	_check(not be.is_empty() and sa.get_groups().has("budget_entretien") and sa.get_groups().has("avis_sources"), "entretien au budget, avis des habitants")
	sa.centres[ct].sel = 10.0
	sa._achat_sel()
	_check(float(sa.centres[ct].sel) >= 149.0, "le dôme de sel est racheté")
	# Fonte.
	sa.sel.clear()
	sa.neige.clear()
	sa.chute_de_neige(2.0, 0.0)
	sa._froid_fin = 0.0
	sa._neige_routes(0.0, 8.0, sa.clock)
	_check(sa.neige.is_empty(), "à 8 °C, 2 cm fondent en une heure")
	# Réglage Admin.
	sa.chute_de_neige(3.0, 0.0)
	ReglagesPartie.actuel.neige_routes = false
	sa._neige_routes(0.0, -2.0, sa.clock)
	_check(sa.neige.is_empty(), "réglage coupé : pas de neige sur les routes")
	ReglagesPartie.actuel.neige_routes = true

	# --- Crue : une rivière fictive au nord des maisons.
	var river := [[[-360.0, y, -32.0], [-180.0, y, -32.0], 8.0]]
	var eid := ev.ajouter("crue", "Crue", sa.clock, sa.clock + 6.0 * 3600.0, Vector3(-300, y, -32), -1,
		{"crue": river, "niveau": 0.0, "fin_crue": 0.0, "vigilance": 3, "montee_h": 6.0}, false)
	ev._update_events(sa.clock)
	var e: Dictionary = ev.events[eid]
	_check(String(e.etat) == "en_cours" and float(e.data.niveau_max) >= 1.2, "crue rouge : l'eau va monter de %s m" % Saisons._num(float(e.data.niveau_max)))
	for i in 60:
		sa._monte(e, sa.clock)
	_check(absf(float(e.data.niveau) - float(e.data.niveau_max)) < 0.01, "l'eau monte jusqu'au maximum")
	_check((e.data.get("inondes", []) as Array).size() >= 5, "%d maisons inondées" % (e.data.get("inondes", []) as Array).size())
	_check(ev.degats.has(homes[0]) and String(ev.degats[homes[0]].cause) == "inondation", "dégâts d'inondation à réparer")
	# Un champ de jeunes pousses au bord de l'eau.
	var agri: Agriculture = scene.agriculture
	agri.champs[999] = {"id": 999, "r": Rect2i(-300, -80, 40, 30), "etat": "pousse", "sc": "mais", "cult": "mais", "cr": 0.1, "met": 1.0, "pertes": 0.0, "f": -1}
	ev.finir(eid)
	_check(float(agri.champs[999].pertes) >= 0.6, "le champ au bord de la rivière perd 60 % de sa récolte")
	# Bassin de rétention.
	var bas := _place(bs, "bassin_retention", -250, false)
	_check(bas > 0 and absf(sa.facteur_retention(Vector3(-300, y, -32)) - 0.75) < 0.01, "un bassin de rétention : l'eau monte 25 % moins haut")
	_check(sa.declencher_crue(3, false) == -1, "pas de rivière dans ce paysage plat : pas de crue au hasard")

	# --- Gel tardif.
	agri.champs[999] = {"id": 999, "r": Rect2i(-300, -80, 40, 30), "etat": "pousse", "sc": "mais", "cult": "mais", "cr": 0.1, "met": 1.0, "pertes": 0.0, "f": -1}
	sa._gel_tardif({"tmin": -3.0}, {"month": 4})
	_check(absf(float(agri.champs[999].met) - 0.85) < 0.001, "gelée tardive en avril : −15 % sur les jeunes pousses")
	sa._gel_tardif({"tmin": -3.0}, {"month": 8})
	_check(absf(float(agri.champs[999].met) - 0.85) < 0.001, "pas de gelée tardive en août")

	# --- Sécheresse.
	var res: Reseaux = scene.reseaux
	res.incidents.restrictions = false
	sa.forcer_secheresse(3)
	_check(sa.niveau_secheresse == 3, "sécheresse : alerte renforcée")
	_check(res.incidents.restrictions, "la préfecture impose les restrictions d'eau")
	_check(absf(agri.herbe_facteur - 0.6) < 0.01, "les prés donnent 40 % d'herbe en moins")
	_check(float(agri.champs[999].met) < 0.85, "les cultures souffrent de la sécheresse")
	_check(float(sa._avis_secheresse()[0]) < 0.0, "habitants mécontents des restrictions")
	var feu := sa.feu_de_broussailles()
	_check(feu >= 0 and int(sa.totaux.feux) == 1, "feu de broussailles : un bâtiment prend feu")
	sa.forcer_secheresse(0)
	_check(sa.niveau_secheresse == 0 and not res.incidents.restrictions, "la pluie revient : restrictions levées")
	agri.champs.erase(999)

	# --- Canicule.
	sa.jours_chauds = 0
	for i in 3:
		sa._canicule({"tmax": 35.0})
	_check(sa.canicule and float(sa._avis_canicule()[0]) < 0.0, "canicule après 3 jours à 35 °C")
	sa._canicule({"tmax": 25.0})
	_check(not sa.canicule, "fin de la canicule")

	# --- Panneau.
	var panel: SaisonsPanel = scene.saisons_panel
	for v in ["meteo", "risques", "neige", "cultures"]:
		panel.set_open(true)
		panel.show_view(v)
		_check(panel._body.get_child_count() > 3, "onglet %s du panneau" % v)
	panel.set_open(false)

	# --- Sauvegarde.
	sa.chute_de_neige(6.0, 0.0)
	sa.centres[ct].sel = 77.0
	var d := sa.to_dict()
	var txt := JSON.stringify(d)
	var back: Dictionary = JSON.parse_string(txt)
	sa.from_dict(back)
	_check(not sa.neige.is_empty() and absf(float(sa.centres[ct].sel) - 77.0) < 0.2 and sa.jours.size() == 1,
		"neige, sel et relevés rechargés")
	scene.queue_free()
	await process_frame
