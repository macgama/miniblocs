extends SceneTree
## Test des quartiers et arrêtés municipaux (Maj+Y) : créer et peindre un quartier
## sur le territoire de sa ville, prendre et abroger des arrêtés (coûts, budget,
## incompatibilités), leurs effets (trajets, vitesse, camions, bruit la nuit,
## stationnement payant, tri, incendies, avis des habitants), mairie perdue
## (lecture seule, le conseil élu décide), pilote automatique, sauvegarde, panneau.
## Usage : godot --headless --path . --script res://tests/quartiers_test.gd

var ok := true


func _initialize() -> void:
	_run.call_deferred()
	create_timer(500.0).timeout.connect(func() -> void:
		push_error("ÉCHEC : délai dépassé")
		quit(1))


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


func _run() -> void:
	Creations.persist = false
	BatimentsVie.chantiers = false
	GameStart.chosen = true
	GameStart.place_name = "Valfleuri, Savoie"
	ReglagesPartie.prochaine = ReglagesPartie.preset("normal")
	ReglagesPartie.prochaine.fondateurs = 0
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var transport: TransportSystem = scene.get_node("Transport")
	var bs: BuildingSystem = scene.get_node("Batiments")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.view_radius_override = 1200.0
	world.set_origin(45.5, 6.4)
	for i in 3000:
		await process_frame
		if i >= 120 and world.missing_chunk_count() == 0 and world._dirty.is_empty() and world._jobs.is_empty():
			break
	scene.urgences.random_calls = false
	var cm: Communes = scene.communes
	var p: Pays = scene.pays
	var bud: BudgetCommunal = scene.budget
	var pop: Population = scene.population
	var y := world.cell_height(Vector2i(0, 0))
	p.foyer = func() -> Vector2: return Vector2(0, 5000)
	var q: Quartiers = scene.quartiers
	_check(q != null and Quartiers.instance == q and scene.quartiers_panel != null, "quartiers et panneau branchés")
	_check(q.is_in_group("avis_sources") and q.is_in_group("budget_ville"), "sources d'avis et comptes des villes")

	print("Une ville et ses rues :")
	cm.nom_en_attente = "Valfleuri"
	var mc := bs.place("maison_commune", Vector2i(-1000, -60), 0)
	var v1 := cm.principal()
	cm.nom_en_attente = "Les Granges"
	var mc2 := bs.place("maison_commune", Vector2i(1100, 0), 0)
	var v2 := cm.village_du_batiment(mc2)
	_check(mc > 0 and v1 >= 0 and mc2 > 0 and v2 >= 0 and v2 != v1, "Valfleuri et Les Granges fondés")
	p.choisir(v1)
	p._poser(v1, 5_000_000)
	_check(transport.build_segment("avenue", Vector3(-1250, y, 40), Vector3(-750, y, 40)).ok, "une avenue à Valfleuri")
	_check(transport.build_segment("rue", Vector3(-1060, y, 40), Vector3(-1060, y, 120)).ok, "et une rue en travers")
	var homes := []
	for x in range(-1150, -850, 30):
		if absi(x + 1060) < 20:
			continue
		for z in [56, 24]:
			var r := bs.best_rotation("maison", Vector2i(x, z))
			var b := bs.place("maison", Vector2i(x, z), r)
			if b > 0:
				homes.append(b)
	_check(homes.size() >= 6, "%d maisons le long de la rue" % homes.size())
	pop._sync_buildings()
	for i in 72:
		pop.advance(300.0)
	_check(pop.persons.size() >= 10, "%d habitants" % pop.persons.size())

	print("Créer et peindre :")
	var qid := q.creer("Les Tilleuls", v1)
	_check(qid > 0 and String(q.quartiers[qid].nom) == "Les Tilleuls" and q.ville_de(qid) == v1, "quartier « Les Tilleuls » à Valfleuri")
	var n := q.peindre_rect(qid, Rect2i(-1200, 0, 400, 100))
	_check(n == 16 and is_equal_approx(q.ha(qid), 4.0), "%d îlots peints (%.2f ha)" % [n, q.ha(qid)])
	_check(q.quartier_au_point(-1000, 40) == qid and q.quartier_au_point(-1000, 400) == -1, "le point de la rue est dans le quartier")
	_check(q.peindre(qid, Quartiers.case_de(5000, 5000), 0) == 0, "hors du territoire : refusé")
	_check(q.peindre(qid, Quartiers.case_de(1100, 0), 0) == 0, "dans une autre ville : refusé")
	_check(q.raison_peindre(qid, Quartiers.case_de(1100, 0)).contains("Les Granges"), "message : %s" % q.raison_peindre(qid, Quartiers.case_de(1100, 0)))
	var q2 := q.creer("", v1)
	_check(q2 > 0 and String(q.quartiers[q2].nom) == "Centre", "nom proposé : %s" % String(q.quartiers[q2].nom))
	q.peindre(q2, Quartiers.case_de(-1000, -100), 1)
	_check(q.ha(q2) > 0.0, "deuxième quartier peint au pinceau (%.2f ha)" % q.ha(q2))
	_check(q.gommer(Quartiers.case_de(-1000, -100), 0) == 1, "la gomme retire un îlot")
	_check(q.renommer(q2, "La Mairie") == "" and String(q.quartiers[q2].nom) == "La Mairie", "renommé « La Mairie »")
	q.calculer_stats()
	_check(int(q.stats[qid].hab) > 0 and int(q.stats[qid].logements) > 0, "%d habitants aux Tilleuls" % int(q.stats[qid].hab))

	print("Arrêtés et budget :")
	var avant := p.solde(v1)
	var cout := Arretes.cout_pose("zone_30", 4.0)
	_check(q.adopter(qid, "zone_30") == "" and q.a_arrete(qid, "zone_30"), "zone 30 en vigueur")
	_check(p.solde(v1) == avant - cout, "mise en place payée par Valfleuri (%s)" % BuildingSystem.format_money(cout))
	var bm := bud.bilan_mensuel(v1)
	_check(is_equal_approx(float(bm.depenses.get("Arrêtés municipaux", 0.0)), Arretes.cout_mois("zone_30", 4.0)),
		"budget de Valfleuri : %s / mois d'arrêtés" % BuildingSystem.format_money(roundi(float(bm.depenses.get("Arrêtés municipaux", 0.0)))))
	_check(not (bud.bilan_mensuel(v2).depenses as Dictionary).has("Arrêtés municipaux"), "rien pour Les Granges")
	_check(q.adopter(qid, "zone_30") != "", "pas deux fois le même arrêté")
	_check(q.adopter(qid, "eclairage_nuit") == "", "éclairage renforcé")
	_check(q.adopter(qid, "extinction_eclairage").begins_with("Incompatible"), "extinction refusée : %s" % q.adopter(qid, "extinction_eclairage"))
	_check(q.abroger(qid, "eclairage_nuit") == "" and q.adopter(qid, "extinction_eclairage") == "", "on éteint à la place")
	bm = bud.bilan_mensuel(v1)
	_check(float(bm.recettes.get("Économies d'éclairage", 0.0)) > 0.0, "économies d'éclairage au budget")
	var vide := q.creer("Vide", v1)
	_check(q.adopter(vide, "zone_30").begins_with("Peins"), "quartier sans îlot : pas d'arrêté")
	p._poser(v1, 100)
	_check(q.adopter(qid, "rue_pietonne").begins_with("Pas assez"), "caisse vide : refusé")
	p._poser(v1, 5_000_000)

	print("Effets :")
	var eid := -1
	var rue := -1
	for e in transport.network.edges:
		if q.quartier_de_voie(e) == qid:
			if String(transport.network.edges[e].t) == "avenue":
				eid = e
			elif String(transport.network.edges[e].t) == "rue":
				rue = e
	_check(eid >= 0 and rue >= 0, "l'avenue et la rue sont dans le quartier")
	_check(is_equal_approx(q.facteur_cout_voie(eid), 50.0 / 30.0), "trajets plus lents sur l'avenue en zone 30 (×%.2f)" % q.facteur_cout_voie(eid))
	_check(is_equal_approx(q.vitesse(eid, {}), 30.0 / 50.0), "voitures visibles à 30 km/h (×%.2f)" % q.vitesse(eid, {}))
	_check(is_equal_approx(q.vitesse(eid, {"urgence": true}), 1.0), "les secours roulent comme avant")
	_check(transport.traffic.speed_factors.has(q.vitesse), "branché sur les véhicules visibles")
	_check(q.adopter(qid, "poids_lourds") == "" and is_equal_approx(q.facteur_lourds(eid), Arretes.LOURDS_RESTANTS), "poids lourds : il en reste %d %%" % roundi(Arretes.LOURDS_RESTANTS * 100))
	_check(q.adopter(qid, "rue_pietonne") == "" and is_equal_approx(q.facteur_cout_voie(rue), Arretes.DETOUR_PIETONNE), "rue piétonne : le transit fait le tour")
	_check(q.vitesse(rue, {}) < 0.5 and is_equal_approx(q.facteur_cout_voie(eid), 50.0 / 30.0), "au pas dans la rue, l'avenue reste en zone 30")
	var nz: Nuisances = scene.nuisances
	var pt := Vector3(-1000, y, 30)
	nz.recalculer()
	var nuit0 := nz.bruit(pt, 1)
	var vert0 := float(nz.au_point(pt).vert)
	q.adopter(qid, "calme_nuit")
	q.adopter(qid, "espaces_verts")
	nz.recalculer()
	_check(nuit0 <= 0.0 or nz.bruit(pt, 1) < nuit0, "bruit la nuit : %d dB → %d dB" % [Nuisances.decibels(nuit0), Nuisances.decibels(nz.bruit(pt, 1))])
	_check(float(nz.au_point(pt).vert) > vert0, "plus de verdure (%.2f → %.2f)" % [vert0, float(nz.au_point(pt).vert)])
	_check(q.adopter(qid, "stationnement_payant") == "" and q.tarif_trottoir(pt) > 0.0 and q.tarif_trottoir(Vector3(-1000, y, 400)) == 0.0,
		"places payantes seulement dans le quartier")
	scene.trafic.run_cycle()
	var paid := 0.0
	for c in scene.trafic.park_cells:
		paid += float(scene.trafic.park_cells[c].paid)
	_check(paid > 0.0, "le trafic compte %d places payantes le long des rues" % roundi(paid))
	q.adopter(qid, "detecteurs_fumee")
	_check(is_equal_approx(q.facteur_feu(pt), Arretes.FEU_DETECTEURS) and is_equal_approx(q.facteur_feu(Vector3(-1000, y, 400)), 1.0), "deux fois moins de départs de feu")
	q.adopter(qid, "tri_obligatoire")
	_check(is_equal_approx(q.bonus_tri(pt, 0.55), 0.80) and is_equal_approx(q.bonus_tri(pt, 0.0), 0.0), "tri : 55 % → 80 % (rien sans centre de tri)")
	var habitant := {}
	for pid in pop.persons:
		var home := pop.home_of(pop.persons[pid])
		if home >= 0 and pop.known.has(home) and q.quartier_au_point(pop.known[home].pos.x, pop.known[home].pos.z) == qid:
			habitant = pop.persons[pid]
			break
	_check(not habitant.is_empty(), "un habitant des Tilleuls")
	if not habitant.is_empty():
		var a_env: Array = q.avis_theme(habitant, "environnement")
		var a_loisirs: Array = q.avis_theme(habitant, "loisirs")
		_check(float(a_env[0]) > 0.0 and not (a_env[1] as Array).is_empty(), "avis environnement : %+.0f (%s)" % [float(a_env[0]), ", ".join(a_env[1])])
		_check(float(a_loisirs[0]) != 0.0, "avis loisirs : %+.0f (%s)" % [float(a_loisirs[0]), ", ".join(a_loisirs[1])])

	print("Mairie perdue :")
	var av: Avis = scene.avis
	var el := av.elections_de(v1)
	el.forcer_mode = "mairie"
	el.etat = "mandat"
	el.mandat_debut = av.jour()
	el.vote_jour = av.jour() + 30
	av.examiner(v1)
	el._elire({"id": "securite", "nom": "Valfleuri tranquille", "couleur": "577590", "tendance": "securite",
		"themes": ["securite"], "promesses": [], "joueur": false, "sortant": false, "tete": -1, "tete_nom": "Paul Girard"}, 55.0, "test", 60.0)
	av.examiner(av.ville_par_defaut())
	_check(not q.decide(v1) and q.decide(v2), "tu ne décides plus à Valfleuri, toujours aux Granges")
	_check(q.abroger(qid, "zone_30").begins_with("Tu n'es plus maire"), "tu ne peux plus abroger : %s" % q.abroger(qid, "zone_30"))
	_check(q.adopter(q2, "zone_30") != "" and q.peindre(qid, Quartiers.case_de(-1000, 150), 0) == 0, "ni prendre d'arrêté, ni peindre")
	_check(q.supprimer(qid) != "" and q.quartiers.has(qid), "ni supprimer le quartier")
	_check(q.creer("Nouveau", v1) == -1, "ni en créer un")
	# Le programme « sécurité » combat l'extinction de l'éclairage : le conseil l'abroge, puis remet la lumière.
	var t1 := q.gerer_conseil(v1, "securite")
	_check(t1.contains("abroge") and not q.a_arrete(qid, "extinction_eclairage"), "conseil : %s" % t1)
	var t2 := q.gerer_conseil(v1, "securite")
	_check(t2.contains("instaure"), "conseil : %s" % t2)
	for i in 12:
		if q.a_arrete(qid, "eclairage_nuit"):
			break
		q.gerer_conseil(v1, "securite")
	_check(q.a_arrete(qid, "eclairage_nuit"), "semaine après semaine, la lumière revient aux Tilleuls")
	var t3 := q.gerer_conseil(v1, "ecologie")
	_check(t3.contains("abroge"), "un conseil écologiste abrogerait l'éclairage renforcé : %s" % t3)
	_check(q.journal.size() >= 3, "décisions au journal")
	var qa := q.creer("Aux Granges", v2)
	_check(qa > 0 and q.peindre(qa, Quartiers.case_de(1100, 100), 0) == 1, "aux Granges, tu peins toujours")

	print("Pilote automatique :")
	var qp := q.creer("Les Prés", v2)
	q.peindre_rect(qp, Rect2i(1000, 50, 200, 100))
	p._poser(v2, 3_000_000)
	var y2 := world.cell_height(Vector2i(1100, 60))
	var rs := transport.build_segment("rue", Vector3(950, y2, 60), Vector3(1250, y2, 60))
	print("    rue des Prés : ", rs.get("ok"), " ", rs.get("reason", ""), " ; maison : ", bs.check_place("maison", Vector2i(1050, 76), bs.best_rotation("maison", Vector2i(1050, 76))).get("reason", ""))
	var maisons := 0
	for x in range(1020, 1190, 30):
		for z in [76, 44]:
			if bs.place("maison", Vector2i(x, z), bs.best_rotation("maison", Vector2i(x, z))) > 0:
				maisons += 1
	_check(maisons > 0, "%d maisons aux Prés" % maisons)
	pop._sync_buildings()
	for i in 72:
		pop.advance(300.0)
	q.calculer_stats()
	var tp := q.piloter(v2)
	_check(int(q.stats[qp].hab) > 0 and tp.contains("Détecteurs") and q.a_arrete(qp, "detecteurs_fumee"), "pilote, %d habitants aux Prés : %s" % [int(q.stats[qp].hab), tp])
	_check(q.adopter(qp, "espaces_verts") == "", "fleurissement aux Prés")
	p._poser(v2, -10_000)
	var tr := q.piloter(v2)
	_check(tr.begins_with("Caisse dans le rouge") and not q.a_arrete(qp, "espaces_verts"), "pilote : %s" % tr)
	p._poser(v2, 3_000_000)

	print("Sauvegarde :")
	var d := q.to_dict()
	var nb := q.quartiers.size()
	var ar := (q.quartiers[qid].arretes as Dictionary).duplicate()
	var j: Dictionary = JSON.parse_string(JSON.stringify(d))
	q.clear()
	_check(q.quartiers.is_empty() and q.cases.is_empty(), "vidé")
	q.from_dict(j)
	_check(q.quartiers.size() == nb and is_equal_approx(q.ha(qid), 4.0), "%d quartiers relus" % nb)
	var k1 := (q.quartiers[qid].arretes as Dictionary).keys()
	var k0 := ar.keys()
	k1.sort()
	k0.sort()
	_check(k1 == k0, "arrêtés relus : %s" % ", ".join(ar.keys()))
	_check(q.en_vigueur("poids_lourds") and q.facteur_lourds(eid) < 1.0, "effets rebranchés")
	_check(scene.save_sections().has("quartiers"), "section « quartiers » dans la sauvegarde")

	print("Panneau :")
	var panel: QuartiersPanel = scene.quartiers_panel
	panel.set_open(true)
	_check(q.montre, "panneau ouvert : quartiers affichés")
	q.selection = -1
	p.choisir(v2)
	panel.refresh()
	_check(panel._title.text.contains("Les Granges"), "liste : %s" % panel._title.text)
	q.selection = qid
	panel.refresh()
	var checks := 0
	var off := 0
	for c in _all(panel._body):
		if c is CheckButton:
			checks += 1
			if (c as CheckButton).disabled:
				off += 1
	_check(checks == Arretes.LISTE.size() and off == checks, "%d arrêtés, tous verrouillés (mairie perdue)" % checks)
	await process_frame
	q._process(0.1)
	_check(q._fill.mesh != null and not q._etiquettes.is_empty(), "quartiers dessinés avec leur nom")
	panel.set_open(false)
	_check(not q.montre, "panneau fermé")

	print("QUARTIERS TEST OK" if ok else "QUARTIERS TEST ÉCHEC")
	quit(0 if ok else 1)


func _all(n: Node) -> Array:
	var out := []
	for c in n.get_children():
		out.append(c)
		out.append_array(_all(c))
	return out
