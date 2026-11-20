extends SceneTree
## Test des chantiers en temps réel : horaires des équipes, durées réalistes,
## étapes des bâtiments, paiement au fil des travaux, chantiers de routes,
## réparations, construction instantanée et sauvegarde.
## Usage : godot --headless --path . --script res://tests/chantiers_test.gd

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


## Secondes Unix d'un lundi 7 h 30 en heure locale (offset en heures).
func _lundi(offset: float) -> float:
	# 2 mars 2026 était un lundi.
	return float(Time.get_unix_time_from_datetime_string("2026-03-02T07:30:00")) - offset * 3600.0


func _run() -> void:
	Creations.persist = false
	ReglagesPartie.actuel = ReglagesPartie.preset("normal")
	ReglagesPartie.actuel.deblocage = "tout"  # (ce test ne porte pas sur l'arbre de progression)
	print("Règles :")
	var lundi := _lundi(0.0)
	# Départ rapide : chantiers ×3 jusqu'à 200 habitants, effacé à 400.
	_check(is_equal_approx(Chantiers.bonus_depart_pour(0), 3.0) and is_equal_approx(Chantiers.bonus_depart_pour(200), 3.0), "départ rapide : ×3 jusqu'à 200 habitants")
	_check(is_equal_approx(Chantiers.bonus_depart_pour(300), 2.0) and is_equal_approx(Chantiers.bonus_depart_pour(400), 1.0) and is_equal_approx(Chantiers.bonus_depart_pour(5000), 1.0), "départ rapide : s'efface entre 200 et 400 habitants")
	_check(Chantiers.bonus_depart(null) == 1.0, "sans population : pas de coup de pouce")
	_check(Chantiers.jour_semaine(lundi) == 0, "le 2 mars 2026 est un lundi")
	_check(is_equal_approx(Chantiers.heures_ouvrees(lundi, lundi + 86400.0, 0.0, "semaine"), 8.0), "une journée d'équipe = 8 h")
	var sem := Chantiers.heures_ouvrees(lundi, lundi + 7.0 * 86400.0, 0.0, "semaine")
	_check(is_equal_approx(sem, 40.0), "une semaine = 40 h (pas de travail le week-end) : %.1f h" % sem)
	_check(is_equal_approx(Chantiers.heures_ouvrees(lundi, lundi + 7.0 * 86400.0, 0.0, "tous_les_jours"), 56.0), "tous les jours : 56 h")
	_check(is_equal_approx(Chantiers.heures_ouvrees(lundi, lundi + 86400.0, 0.0, "continu"), 24.0), "jour et nuit : 24 h")
	var nuit := lundi + 14.0 * 3600.0 # 21 h 30
	_check(Chantiers.heures_ouvrees(nuit, nuit + 9.0 * 3600.0, 0.0, "semaine") == 0.0, "rien la nuit")
	var paris := _lundi(1.0)
	_check(is_equal_approx(Chantiers.heures_ouvrees(paris, paris + 3600.0, 1.0, "semaine"), 1.0), "heure locale (fuseau du lieu)")
	var fin := Chantiers.date_apres(lundi, 40.0, 0.0, "semaine")
	_check(absf(fin - (lundi + 4.0 * 86400.0 + 9.0 * 3600.0)) < 1.0, "40 h de travail finissent le vendredi à 16 h 30")
	var m_maison := Chantiers.mois_batiment("colombages__maison", 2025)
	var m_imm := Chantiers.mois_batiment("international__immeuble", 2025)
	_check(m_maison >= 4.0 and m_maison <= 6.5, "maison : %.1f mois réels (4 à 6)" % m_maison)
	_check(m_imm >= 12.0 and m_imm <= 24.0, "immeuble : %.1f mois réels (12 à 24)" % m_imm)
	var m_ecole := Chantiers.mois_batiment("ecole", 2025)
	var m_hop := Chantiers.mois_batiment("hopital", 2025)
	var m_stade := Chantiers.mois_batiment("stade_lugano", 2025)
	var m_kiosque := Chantiers.mois_batiment("kiosque_presse", 2025)
	_check(m_ecole >= 9.0 and m_ecole <= 24.0, "école : %.1f mois réels" % m_ecole)
	_check(m_hop >= 24.0 and m_hop <= 60.0, "hôpital : %.1f mois réels (plusieurs années)" % m_hop)
	_check(m_stade >= 20.0 and m_stade <= 48.0, "stade : %.1f mois réels (plusieurs années)" % m_stade)
	_check(m_kiosque < m_maison, "un kiosque va plus vite qu'une maison : %.1f mois" % m_kiosque)
	_check(Chantiers.mois_batiment("colombages__maison", 1810) > m_maison * 1.4, "en 1810, à la main, la même maison est plus longue : %.1f mois" % Chantiers.mois_batiment("colombages__maison", 1810))
	_check(Chantiers.mois_batiment("hopital", 1810) <= Chantiers.MOIS_MAX, "plafond des bâtiments ordinaires")
	var h100 := Chantiers.heures_voie("departementale", 100.0, 8.0)
	_check(h100 > 40.0 and h100 < 160.0, "100 m de départementale : %d h réelles" % roundi(h100))
	var et := Chantiers.etape(Chantiers.ETAPES_BATIMENT, 0.5)
	_check(String(et[1]) == "murs", "à 50 %, on monte les murs")

	print("Bâtiments :")
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
	var vie: BatimentsVie = scene.get_node("VieBatiments")
	var suivi: SuiviChantiers = scene.get_node("Chantiers")
	var cv: ChantiersVoies = scene.get_node("ChantiersVoies")
	var amb: DayNight = scene.get_node("Ambiance")
	_check(suivi != null and cv != null and SuiviChantiers.instance == suivi, "nœuds Chantiers et ChantiersVoies")
	amb.set_speed(0)
	var off := amb.utc_offset()
	amb.unix_time = _lundi(off)
	vie._t_prev = amb.unix_time
	suivi._t_prev = amb.unix_time
	BatimentsVie.chantiers = true
	bs.require_access = false
	bs.unlimited_money = false
	bs.money = 10_000_000
	var m0 := bs.money
	# Surcoût des matériaux importés (pas de carrière sur cette carte) : payé en plus du prix.
	var sc0 := MateriauxChantiers.surcout_total
	var bid := bs.place("colombages__maison", Vector2i(-60, 60), 0)
	_check(bid > 0 and bs.en_chantier(bid), "maison posée : chantier ouvert")
	var cost := int(bs.buildings[bid].cost)
	_check(bs.money == m0 and int(bs.buildings[bid].du) == cost, "rien payé à la pose (%s dus)" % BuildingSystem.format_money(cost))
	var node := bs.node_of(bid)
	vie._update_chantiers()
	_check(node.get_node("Fouille").visible and not node.get_node("Echafaudage").visible, "étape 1 : fouille, pas encore d'échafaudage")
	_check(node.get_node("Engins/Pelleteuse").visible, "pelleteuse dans la fouille")
	_camions(scene, bs, vie, node)
	_check(node.find_children("*", "Label3D", true, false).is_empty(), "plus de texte flottant au-dessus du chantier")
	_check(vie.texte_chantier(bid).contains("Terrassement"), "détail du chantier (info-bulle) : « Terrassement »")
	vie.marqueurs.maj()
	var mq: Array = vie.marqueurs.marqueurs.filter(func(m: Dictionary) -> bool: return int(m.bid) == bid)
	_check(mq.size() == 1 and String(mq[0].genre) == "chantier" and float(mq[0].pos.y) > float(node.global_position.y) + 3.0, "marqueur au-dessus du chantier")
	# Un bâtiment sans électricité (panne de réseau) garde l'aspect du chantier.
	node.set_meta("res_panne", true)
	BatimentsVie.refresh_material(node)
	_check((node as MeshInstance3D).material_override is ShaderMaterial and (node as MeshInstance3D).material_override.get_shader_parameter("chantier_h") != null, "sans courant, le chantier reste un chantier (pas un bâtiment fini)")
	node.remove_meta("res_panne")

	var hjeu := float(bs.buildings[bid].hr) / Chantiers.rythme(vie.population)
	var jours := (vie.fin_prevue(bid) - amb.unix_time) / 86400.0
	_check(jours > 1.5 and jours < 40.0, "maison finie en %.0f jours de jeu (≈ 2 semaines à ×3, 1 an de vie = 1 mois)" % jours)
	# La nuit et le week-end, rien n'avance.
	amb.unix_time = _lundi(off) + 4.0 * 86400.0 + 10.0 * 3600.0 # vendredi 17 h 30
	vie._t_prev = amb.unix_time
	vie._update_chantiers()
	var av_ven := vie.progress(bid)
	amb.unix_time += 2.5 * 86400.0
	vie._update_chantiers()
	_check(is_equal_approx(vie.progress(bid), av_ven), "le week-end, le chantier ne bouge pas")
	_check(not vie.au_travail, "équipe au repos le dimanche soir")
	# Lundi suivant : la moitié du travail.
	amb.unix_time = _lundi(off) + 7.0 * 86400.0
	vie._t_prev = amb.unix_time
	var reste := (0.5 - vie.progress(bid)) * hjeu
	amb.unix_time = Chantiers.date_apres(amb.unix_time, reste, off)
	vie._update_chantiers()
	_check(absf(vie.progress(bid) - 0.5) < 0.02, "chantier à mi-parcours (%d %%)" % roundi(vie.progress(bid) * 100.0))
	_check(String(vie.etape_de(bid)[1]) == "murs" and node.get_node("Echafaudage").visible and not node.get_node("Fouille").visible, "murs derrière les échafaudages")
	var paye := m0 - bs.money
	_check(absf(float(paye - (MateriauxChantiers.surcout_total - sc0)) - cost * 0.5) <= cost * 0.03, "la moitié du prix payée (%s)" % BuildingSystem.format_money(paye))
	# Caisse vide : le chantier s'arrête.
	bs.money = 0
	var av_stop := vie.progress(bid)
	amb.unix_time = Chantiers.date_apres(amb.unix_time, hjeu * 0.1, off)
	vie._update_chantiers()
	_check(is_equal_approx(vie.progress(bid), av_stop) and bool(bs.buildings[bid].get("attente", false)), "caisse vide : chantier arrêté")
	_check(vie.texte_chantier(bid).contains("argent") and vie.statut_de(bid) == "argent", "le détail le dit (pastille rouge)")
	bs.money = 10_000_000
	var m1 := bs.money
	amb.unix_time = Chantiers.date_apres(amb.unix_time, hjeu * 0.6, off)
	vie._update_chantiers()
	await process_frame
	_check(not bs.en_chantier(bid) and node.get_node_or_null("Echafaudage") == null and node.get_node_or_null("Engins") == null, "maison finie, chantier démonté")
	var sc := MateriauxChantiers.surcout_total - sc0
	_check(m1 - bs.money + paye == cost + sc and not bs.buildings[bid].has("du"),
		"prix total payé exactement, plus %s de surcoût d'import" % BuildingSystem.format_money(sc))
	# Ouvriers près de la caméra pendant les heures de travail.
	var b2 := bs.place("colombages__grande_maison", Vector2i(-100, 60), 0)
	amb.unix_time = _lundi(off) + 14.0 * 86400.0 + 3600.0 # lundi 8 h 30
	vie._t_prev = amb.unix_time
	vie._update_chantiers()
	var cam := Camera3D.new()
	scene.add_child(cam)
	cam.global_position = bs.node_of(b2).global_position + Vector3(0, 30, 30)
	cam.make_current()
	vie._animer_chantiers()
	var n_ouv := 0
	for c in bs.node_of(b2).get_children():
		if c is Figurine:
			n_ouv += 1
	_check(vie.au_travail and n_ouv >= 2, "%d ouvriers au travail, en gilet orange" % n_ouv)
	amb.unix_time += 12.0 * 3600.0 # 20 h 30
	vie._update_chantiers()
	vie._animer_chantiers()
	await process_frame
	n_ouv = 0
	for c in bs.node_of(b2).get_children():
		if c is Figurine and not c.is_queued_for_deletion():
			n_ouv += 1
	_check(n_ouv == 0, "le soir, les ouvriers sont rentrés")
	# Sauvegarde : avancement et reste dû.
	amb.unix_time = Chantiers.date_apres(_lundi(off) + 21.0 * 86400.0, 0.3 * float(bs.buildings[b2].hr) / Chantiers.rythme(vie.population), off)
	vie._t_prev = _lundi(off) + 21.0 * 86400.0
	vie._update_chantiers()
	var saved := bs.to_dict()
	var row: Dictionary = (saved.buildings as Array).filter(func(e: Dictionary) -> bool: return int(e.id) == b2)[0]
	_check(row.has("av") and float(row.av) > 0.2 and row.has("hr") and int(row.get("du", 0)) > 0, "sauvegarde : avancement %d %% et reste dû" % roundi(float(row.get("av", 0)) * 100.0))
	bs.from_dict(saved)
	await process_frame
	_check(bs.en_chantier(b2) and absf(vie.progress(b2) - float(row.av)) < 0.001, "chargement : le chantier reprend où il en était")
	# Construction instantanée (Admin).
	ReglagesPartie.actuel.construction_instantanee = true
	vie._update_chantiers()
	_check(not bs.en_chantier(b2), "construction instantanée : les chantiers en cours finissent")
	var b3 := bs.place("colombages__maison", Vector2i(-140, 60), 0)
	_check(b3 > 0 and not bs.en_chantier(b3) and not bs.buildings[b3].has("du"), "construction instantanée : bâtiment fini et payé d'un coup")
	ReglagesPartie.actuel.construction_instantanee = false
	var r := ReglagesPartie.new()
	r.from_dict({"construction_instantanee": true, "horaires_chantiers": "continu"})
	_check(r.construction_instantanee and r.horaires_chantiers == "continu" and r.to_dict().has("horaires_chantiers"), "réglages Admin sauvegardés")

	print("Routes :")
	var ya := world.cell_height(Vector2i(0, 0))
	var road := transport.build_segment("departementale", Vector3(40, ya, -100), Vector3(40, ya, 100))
	_check(road.ok, "départementale posée")
	cv.commencer(road.edges)
	var eid: int = road.edges[0]
	var net := transport.network
	_check(cv.en_chantier(eid) and float(net.edges[eid].chr) > 0.0, "la route commence par un chantier (%d h réelles)" % roundi(float(net.edges[eid].chr)))
	_check(net.find_route(road.start_node, road.end_node).is_empty(), "pas de circulation sur une route en chantier")
	amb.unix_time = _lundi(off) + 28.0 * 86400.0
	off = amb.utc_offset() # heure d'été possible
	amb.unix_time = _lundi(off) + 28.0 * 86400.0
	suivi._t_prev = amb.unix_time
	var hr_jeu := float(net.edges[eid].chr) / Chantiers.rythme(vie.population)
	amb.unix_time = Chantiers.date_apres(amb.unix_time, hr_jeu * 0.5, off)
	suivi.mettre_a_jour()
	_check(absf(cv.avancement(eid) - 0.5) < 0.02, "route à mi-chantier (%d %%)" % roundi(cv.avancement(eid) * 100.0))
	var m := ChantiersVoies.chantier_mesh(net.edges[eid], 0.5, transport.ground_height)
	_check(m.get_surface_count() > 0, "terre et grave dessinées")
	var m_fin := ChantiersVoies.chantier_mesh(net.edges[eid], 0.95, transport.ground_height)
	_check(m_fin.get_surface_count() == 2, "au marquage : voie finie + enrobé qui reste")
	cv._vus[eid] = {"engins": null, "ouvriers": [], "etape": ""}
	cv._placer(eid)
	_check(cv._vus[eid].engins != null and (cv._vus[eid].engins as Node).get_child_count() > 0, "engins au front des travaux (%s)" % String(cv._vus[eid].etape))
	# Une route qui en croise une autre en chantier : les deux moitiés gardent l'avancement.
	var av_avant := cv.avancement(eid)
	var cross := transport.build_segment("departementale", Vector3(-20, ya, 0), Vector3(100, ya, 0))
	_check(cross.ok, "route qui croise le chantier")
	var halves := 0
	for k in net.edges:
		if net.edges[k].has("ch") and absf(float(net.edges[k].ch) - av_avant) < 0.001:
			halves += 1
	_check(halves == 2, "le tronçon coupé garde son avancement (2 moitiés)")
	var tsave := transport.to_dict()
	_check((tsave.edges as Array).any(func(e: Dictionary) -> bool: return e.has("ch")), "sauvegarde du réseau : chantiers gardés")
	amb.unix_time = Chantiers.date_apres(amb.unix_time, hr_jeu, off)
	suivi.mettre_a_jour()
	await process_frame
	var reste_ch := 0
	for k in net.edges:
		if net.edges[k].has("ch"):
			reste_ch += 1
	_check(reste_ch == 0, "travaux terminés")
	_check(not net.find_route(road.start_node, road.end_node).is_empty(), "route ouverte à la circulation")
	# Réparation.
	var some: int = net.edges.keys()[0]
	var fini_ok := [false]
	_check(cv.chantier_reparation(some, 16.0, 1000, func() -> void: fini_ok[0] = true), "réparation lancée")
	_check(net.closed_edges.has(some), "tronçon fermé pendant la réparation")
	amb.unix_time = Chantiers.date_apres(amb.unix_time, 16.0 / Chantiers.rythme(vie.population) + 0.1, off)
	suivi.mettre_a_jour()
	_check(not net.closed_edges.has(some) and fini_ok[0], "réparation finie : tronçon rouvert")

	bs.unlimited_money = true
	var mc := bs.place("maison_commune", Vector2i(-400, 400), 0)
	_check(mc > 0 and bs.en_chantier(mc), "la Maison de commune se construit aussi par étapes (%s)" % bs.check_place("maison_commune", Vector2i(-400, 400), 0).reason)
	print("CHANTIERS TEST OK" if ok else "CHANTIERS TEST ÉCHEC")
	quit(0 if ok else 1)


## Camions du chantier : un seul à la fois, jamais dans la palissade ; garé sur la
## chaussée, le long du trottoir et dans le sens de la route quand elle est proche.
func _camions(scene: Node, bs: BuildingSystem, vie: BatimentsVie, node: Node3D) -> void:
	var t := BuildingCatalog.get_type("colombages__maison")
	var d := float(t.get("d", 8))
	var w := float(t.get("w", 8))
	var vus := 0
	for nom in ["Benne", "Toupie", "Camionnette"]:
		if (node.get_node("Engins/" + nom) as Node3D).visible:
			vus += 1
	_check(vus == 1, "un seul camion devant le chantier (%d)" % vus)
	var benne := node.get_node("Engins/Benne") as Node3D
	_check(benne.transform.origin.z <= -d / 2.0 - 1.2 - 0.3, "sans route, le camion attend devant l'entrée, hors de la palissade (z = %.1f)" % benne.transform.origin.z)
	# Deuxième maison, collée à une route tracée devant elle.
	var transport: TransportSystem = scene.get_node("Transport")
	var bid2 := bs.place("colombages__maison", Vector2i(200, 200), 0)
	if bid2 <= 0:
		_check(false, "deuxième maison posée")
		return
	var n2 := bs.node_of(bid2)
	var ent := n2.global_transform * Vector3(0, 0, -d / 2.0)
	var dir := (n2.global_transform.basis * Vector3(0, 0, -1)).normalized()
	var larg := TransportTypes.width_of("route", {})
	var axe := ent + dir * (larg / 2.0 + 0.3)
	var cote := (n2.global_transform.basis * Vector3(1, 0, 0)).normalized()
	var r := transport.build_segment("route", axe - cote * 40.0, axe + cote * 40.0)
	_check(bool(r.ok), "route devant la deuxième maison")
	vie._update_chantiers()
	vie._garer_camions(vie._chantiers[bid2])
	var b2 := n2.get_node("Engins/Benne") as Node3D
	var p := b2.global_position
	var lat := absf((p - axe).dot(dir))
	var chaussee := larg / 2.0 - TransportTypes.side_of("route", {})
	_check(lat + 1.2 <= chaussee + 0.05 and lat > 0.5, "camion sur la chaussée, le long du trottoir (%.1f m de l'axe, chaussée %.1f m)" % [lat, chaussee])
	var avant := (b2.global_transform.basis * Vector3(0, 0, 1)).normalized()
	_check(absf(avant.dot(cote)) > 0.99, "camion dans le sens de la route")
	_check(avant.cross(Vector3.UP).dot(-dir) > 0.0, "trottoir à droite du camion (circulation à droite)")
	_check(absf((p - ent).dot(cote)) < w / 2.0, "garé devant l'entrée du chantier")
	bs.demolish(bid2)
