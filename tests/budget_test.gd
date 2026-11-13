extends SceneTree
## Test du budget communal : impôts votés, emprunts, tutelle, usure et entretien
## des voies, nids-de-poule, panneau (M), sauvegarde.
## Usage : godot --headless --path . --script res://tests/budget_test.gd

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


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _key(k: Key) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = k
		e.physical_keycode = k
		e.pressed = pressed
		root.push_input(e)
		await process_frame


func _run() -> void:
	Creations.persist = false
	ReglagesPartie.prochaine = ReglagesPartie.preset("normal")
	GameStart.mode = GameStart.Mode.BAC_A_SABLE
	GameStart.load_slot = ""
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var bs: BuildingSystem = scene.get_node("Batiments")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.set_origin(48.8584, 2.2945)
	await _frames(60)
	var b: BudgetCommunal = scene.budget
	var pop: Population = scene.population
	pop.arrivals = false

	print("Nœud Budget :")
	_check(b != null and BudgetCommunal.instance == b, "nœud Budget créé, BudgetCommunal.instance")
	_check(root.get_tree().get_first_node_in_group("budget_communal") == b, "groupe budget_communal")
	_check(pop.city_pay.is_valid(), "le versement quotidien de la ville passe par le budget")

	print("Impôts votés :")
	pop.households[999] = {"id": 999, "b": -1, "reg": "fr", "ep": 0.0, "car": 0, "m": []}
	var tf1 := float(b.bilan_mensuel().recettes["Taxe foncière"])
	b.set_taux("foncier", 2.0)
	var tf2 := float(b.bilan_mensuel().recettes["Taxe foncière"])
	_check(is_equal_approx(tf2, tf1 * 2.0) and tf1 > 0.0, "taxe foncière à 200 %% : %s → %s par mois" % [BudgetPanel.money(tf1), BudgetPanel.money(tf2)])
	_check(b.pression_fiscale() > 1.4, "pression fiscale ressentie : %d %%" % roundi(b.pression_fiscale() * 100.0))
	var mood: Array = b._avis_impots()
	_check(float(mood[0]) < 0.0 and String(mood[1][0]).begins_with("−"), "les habitants râlent : " + String(mood[1][0]))
	b.set_taux("foncier", 9.0)
	_check(float(b.taux.foncier) == BudgetCommunal.TAUX_MAX, "taux borné à 200 %")
	b.set_taux("foncier", 0.5)
	_check(float(b._avis_impots()[0]) > 0.0, "impôts bas : habitants contents")
	b.set_taux("foncier", 1.0)
	_check(is_equal_approx(BudgetCommunal.facteur("benefices"), 1.0), "impôt sur les bénéfices : facteur 1 par défaut")
	b.set_taux("benefices", 1.5)
	_check(is_equal_approx(BudgetCommunal.facteur("benefices"), 1.5), "facteur lu par la production")
	b.set_taux("benefices", 1.0)

	print("Versement quotidien :")
	var m0 := bs.money
	var bil := b.bilan_mensuel()
	b.pay_day()
	var expect := float(bil.solde) / BudgetCommunal.DAYS_PER_MONTH
	_check(absi(bs.money - m0 - roundi(expect)) <= 1, "un jour : caisse %+d € (attendu %+d)" % [bs.money - m0, roundi(expect)])
	_check(b.mois.has("Taxe foncière") and b.jours_mois == 1, "inscrit aux comptes du mois")

	print("Groupes budget_entretien / budget_recettes :")
	var gs := GDScript.new()
	gs.source_code = "extends Node\nfunc budget_entretien() -> Dictionary:\n\treturn {\"Entretien réseau d'eau\": 3044.0}\nfunc budget_recettes() -> Dictionary:\n\treturn {\"Tickets de transport\": 1522.0}\n"
	gs.reload()
	var ext := Node.new()
	ext.set_script(gs)
	ext.add_to_group("budget_entretien")
	ext.add_to_group("budget_recettes")
	scene.add_child(ext)
	var bil2 := b.bilan_mensuel()
	_check(float(bil2.depenses.get("Entretien réseau d'eau", 0.0)) == 3044.0, "coût d'un autre système dans le bilan")
	_check(float(bil2.recettes.get("Tickets de transport", 0.0)) == 1522.0, "recette d'un autre système dans le bilan")
	m0 = bs.money
	b.recette("Amendes", 500.0)
	b.depense("Fête", 200.0)
	_check(bs.money - m0 == 300 and float(b.mois.Amendes) == 500.0, "recette() et depense() ponctuelles")
	ext.queue_free()
	await _frames(1)

	print("Emprunts :")
	m0 = bs.money
	var t5 := b.taux_propose(1_000_000, 5)
	var t30 := b.taux_propose(1_000_000, 30)
	_check(t5 >= BudgetCommunal.TAUX_BASE and t30 > t5, "taux 5 ans %s %%, 30 ans %s %%" % [BudgetCommunal._pct(t5), BudgetCommunal._pct(t30)])
	var e := b.emprunter(1_000_000, 10)
	_check(not e.is_empty() and bs.money - m0 == 1_000_000, "emprunt de 1 M€ versé en caisse")
	var mens := BudgetCommunal.mensualite_de(1_000_000, float(e.taux), 10)
	_check(absf(float(e.mensualite) - mens) < 0.01 and mens > 1_000_000.0 / 120.0, "mensualité %s (plus que le capital seul)" % BudgetPanel.money(mens))
	for i in 30:
		b._pay_loans(1.0)
	var rest := float(b.emprunts[0].restant)
	_check(rest < 1_000_000.0 and rest > 1_000_000.0 - mens, "un mois remboursé : reste %s" % BudgetPanel.money(rest))
	_check(b.mois.has("Intérêts des emprunts"), "intérêts inscrits au budget")
	var big := b.plafond_dette() + 1.0
	_check(b.refus_emprunt(big, 10).begins_with("Plafond"), "au-delà du plafond : refusé")
	m0 = bs.money
	_check(b.rembourser(int(e.id)) and b.emprunts.is_empty(), "remboursement anticipé")
	_check(m0 - bs.money >= roundi(rest), "le capital restant est payé (avec pénalité)")
	b.emprunter(100_000, 5)
	for i in 5 * 365 + 10:
		b._pay_loans(1.0)
	_check(b.emprunts.is_empty(), "emprunt de 5 ans soldé à l'échéance")

	print("Tutelle du préfet :")
	bs.money = -1_000_000
	for i in BudgetCommunal.JOURS_ROUGE_TUTELLE:
		b._check_tutelle()
	_check(b.tutelle, "90 jours dans le rouge : tutelle")
	_check(is_equal_approx(b.taux_effectif("foncier"), BudgetCommunal.TAUX_TUTELLE), "impôts relevés d'office")
	_check(b.refus_emprunt(100_000, 5) != "", "plus d'emprunts")
	var pub := ""
	for id in BuildingCatalog.all_types():
		if String(BuildingCatalog.get_type(id).get("cat", "")) == "services":
			pub = id
			break
	_check(pub != "" and ReglagesPartie.actuel.raison_blocage(pub).contains("tutelle"), "bâtiment public bloqué (%s)" % pub)
	_check(ReglagesPartie.actuel.raison_blocage("maison") == "", "une maison reste permise")
	bs.money = 5_000_000
	for i in BudgetCommunal.JOURS_VERT_SORTIE:
		b._check_tutelle()
	_check(not b.tutelle, "30 jours sans dette : sortie de tutelle")

	print("Usure des voies :")
	var y := world.cell_height(Vector2i(0, 0))
	scene.transport.build_segment("route", Vector3(0, y, -100), Vector3(0, y, 100))
	await _frames(2)
	var net: TransportNetwork = scene.transport.network
	var eid := -1
	for id in net.edges:
		if BudgetCommunal.voie_of(String(net.edges[id].t)) == "route":
			eid = id
	_check(eid >= 0 and is_equal_approx(b.etat(eid), 1.0), "route neuve à 100 %")
	_check(b.cout_entretien("route") > 0.0, "entretien conseillé des routes : %s/mois" % BudgetPanel.money(b.cout_entretien("route")))
	_check(b.bilan_mensuel().depenses.has("Entretien : routes"), "entretien des routes dans le bilan")
	b.set_entretien("route", "auto", false)
	b.set_entretien("route", "taux", 0.0)
	b._wear_day()
	var u0 := b.etat(eid)
	b.set_entretien("route", "taux", 1.0)
	b.set_etat(eid, 1.0)
	b._wear_day()
	var u1 := b.etat(eid)
	_check(u0 < 1.0 and u1 > u0, "l'entretien freine l'usure (sans : %.5f, avec : %.5f)" % [1.0 - u0, 1.0 - u1])
	ReglagesPartie.actuel.usure = 0.0
	b.set_etat(eid, 1.0)
	b._wear_day()
	_check(is_equal_approx(b.etat(eid), 1.0), "usure coupée dans l'Admin : rien ne s'use")
	ReglagesPartie.actuel.usure = 1.0
	_check(BudgetCommunal.poids("porteur", 0) > 5.0 * BudgetCommunal.poids("citadine", 0), "un camion use bien plus qu'une voiture")
	# Trafic : un camion arrêté sur la route pendant 24 h.
	var tf: Traffic = scene.transport.traffic
	b.set_etat(eid, 1.0)
	var keep: Array[Dictionary] = tf.vehicles.duplicate()
	tf.vehicles.clear()
	var r: Array[int] = [eid]
	tf.vehicles.append({"route": r, "leg": 0, "model": "porteur", "mode": 0})
	b.sample_traffic(24.0)
	_check(b.etat(eid) < 1.0, "le passage d'un camion use la route (%.5f)" % (1.0 - b.etat(eid)))
	tf.vehicles = keep
	b.set_etat(eid, 0.3)
	_check(b.vitesse_facteur(eid) < 1.0 and b.vitesse_facteur(eid) >= BudgetCommunal.VITESSE_MIN, "route à 30 %% : vitesse ×%.2f" % b.vitesse_facteur(eid))
	b.vue.flush()
	_check(b.vue.hole_count() > 0, "nids-de-poule visibles (%d)" % b.vue.hole_count())
	b.vue.set_carte(true)
	b.vue.flush()
	_check(b.vue._map.mesh != null and b.vue._map.visible, "carte de l'état des voies")
	b.vue.set_carte(false)
	b.set_etat(eid, 0.0)
	_check(String(net.closed_edges.get(eid, "")) == "usure", "route à 0 % : fermée")
	var cost := b.prix_reparation(eid)
	m0 = bs.money
	_check(b.reparer(eid), "réparation lancée (%s)" % BudgetPanel.money(cost))
	await _frames(2)
	if is_equal_approx(b.etat(eid), 1.0):
		_check(not net.closed_edges.has(eid), "route refaite et rouverte")
	else:
		print("    (chantier visible en cours : la route rouvrira à la fin)")
	_check(cost > 0 and b.mois.has("Réparations des voies"), "réparation inscrite au budget")
	b.set_etat(eid, 0.2)
	b.set_entretien("route", "auto", true)
	b._auto_repairs()
	await _frames(2)
	_check(b.mois.get("Réparations des voies", 0.0) < -float(cost) or b.etat(eid) > 0.2, "réparation automatique sous le seuil")

	print("Découpe et sauvegarde :")
	for id in net.edges.keys():
		b.set_etat(id, 0.4)
	var mid := net.split_edge(net.edges.keys()[0], 30.0)
	var all_04 := true
	for id in net.edges:
		if not is_equal_approx(b.etat(id), 0.4):
			all_04 = false
	_check(mid >= 0 and all_04, "un tronçon coupé en deux garde son usure")
	var nd := net.to_dict()
	var net2 := TransportNetwork.new()
	net2.from_dict(nd)
	var same := true
	for id in net.edges:
		if not net2.edges.has(id) or absf(float(net2.edges[id].get("u", 1.0)) - b.etat(id)) > 0.001:
			same = false
	_check(same, "usure des voies sauvegardée avec le réseau")
	b.set_taux("entreprises", 1.3)
	b.emprunter(500_000, 20)
	b.register("eau", "t1", 250.0)
	b.user("eau", "t1", 0.2)
	var d := b.to_dict()
	var j: Dictionary = JSON.parse_string(JSON.stringify(d))
	b.clear()
	_check(b.emprunts.is_empty() and float(b.taux.entreprises) == 1.0, "clear() remet à zéro")
	b.from_dict(j)
	_check(is_equal_approx(float(b.taux.entreprises), 1.3) and b.emprunts.size() == 1 and int(b.emprunts[0].annees) == 20, "taux et emprunts relus")
	_check(absf(b.etat_ext("eau", "t1") - 0.8) < 0.001, "usure d'un autre réseau relue")
	_check(scene.save_sections().has("budget"), "section « budget » dans la sauvegarde")

	print("Avis des habitants :")
	_check(root.get_tree().get_nodes_in_group("avis_sources").has(b), "groupe avis_sources")
	var fs: Array = b.avis_facteurs()
	_check(fs.size() == 2 and (fs[0].f as Callable).call() is Array, "facteurs impôts et routes")
	for id in net.edges:
		b.set_etat(id, 0.1)
	_check(float(b._avis_routes()[0]) < 0.0, "routes abîmées : habitants mécontents")

	print("Panneau Budget :")
	await _key(KEY_M)
	await _frames(2)
	var panel: BudgetPanel = scene.budget_panel
	_check(panel.is_open(), "M ouvre le panneau")
	for v in ["bilan", "impots", "emprunts", "entretien"]:
		panel.show_view(v)
		await _frames(1)
		_check(panel._body.get_child_count() > 2, "onglet %s (%d lignes)" % [v, panel._body.get_child_count()])
	await _key(KEY_M)
	_check(not panel.is_open(), "M le referme")
	var aide := FileAccess.get_file_as_string("res://scripts/interface/aide_panel.gd")
	_check(aide.contains("panneau Budget"), "aide F1 à jour")

	print("TEST OK" if ok else "TEST ÉCHOUÉ")
	quit(0 if ok else 1)
