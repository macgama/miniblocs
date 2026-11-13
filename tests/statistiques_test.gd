extends SceneTree
## Test des statistiques et du conseiller : relevé quotidien par ville et pour le
## pays, séries pour les courbes, regroupement des vieux jours, évolution sur 30
## jours, conseils (caisse dans le rouge, chômage, logements, réseaux…), alerte,
## sauvegarde et chargement, panneau Maj+I (courbes, comparaison, conseiller).
## Usage : godot --headless --path . --script res://tests/statistiques_test.gd

var ok := true


func _initialize() -> void:
	_run.call_deferred()
	create_timer(400.0).timeout.connect(func() -> void:
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


func _ids(liste: Array) -> Array:
	return liste.map(func(a) -> String: return String(a.id))


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
	var st: Statistiques = scene.statistiques
	var cm: Communes = scene.communes
	var p: Pays = scene.pays
	var pop: Population = scene.population
	var amb: DayNight = scene.ambiance
	p.foyer = func() -> Vector2: return Vector2(0, 5000)
	st.auto = false
	_check(st != null and Statistiques.instance == st and scene.stats_panel != null, "statistiques et panneau branchés")
	var y := world.cell_height(Vector2i(0, 0))

	print("Deux villes avec des habitants :")
	cm.nom_en_attente = "Valfleuri"
	var mc := bs.place("maison_commune", Vector2i(-1000, 0), 0)
	var v1 := cm.principal()
	cm.nom_en_attente = "Les Granges"
	var mc2 := bs.place("maison_commune", Vector2i(1100, 0), 0)
	var v2 := cm.village_du_batiment(mc2)
	_check(mc > 0 and mc2 > 0 and v1 != v2, "Valfleuri et Les Granges fondés")
	transport.build_segment("route", Vector3(-1300, y, 40), Vector3(-700, y, 40))
	transport.build_segment("route", Vector3(800, y, 40), Vector3(1400, y, 40))
	var maisons := []
	for x in [-1200, -1150, -1100, -900, -850]:
		var b := bs.place("immeuble", Vector2i(x, 56), bs.best_rotation("immeuble", Vector2i(x, 56)))
		if b < 0:
			b = bs.place("maison", Vector2i(x, 56), bs.best_rotation("maison", Vector2i(x, 56)))
		if b > 0:
			maisons.append(b)
	var m2 := bs.place("maison", Vector2i(1200, 56), bs.best_rotation("maison", Vector2i(1200, 56)))
	await process_frame
	await process_frame
	for b in maisons:
		for _k in 3:
			pop.spawn_household(b, "couple")
	if m2 > 0:
		pop.spawn_household(m2, "famille")
	_check(maisons.size() >= 3 and pop.persons.size() > 6, "%d bâtiments, %d habitants" % [maisons.size(), pop.persons.size()])

	print("Relevés quotidiens :")
	st.clear()
	var j0 := st.jour()
	for k in 40:
		st.releve()
		amb.unix_time += 86400.0
		if k == 20:
			# Quelques foyers de plus à Valfleuri : la population grimpe.
			for b in maisons:
				pop.spawn_household(b, "seul")
	_check(st.historique.size() == 40, "40 relevés (%d)" % st.historique.size())
	_check(int(st.historique[0].j) == j0 and int(st.historique[-1].j) == j0 + 39, "un relevé par jour de jeu")
	var hp := st.dernier(Statistiques.PAYS, "habitants")
	var h1 := st.dernier(str(v1), "habitants")
	var h2 := st.dernier(str(v2), "habitants")
	_check(hp == float(pop.persons.size()), "habitants du pays : %d" % hp)
	_check(h1 > 0.0 and h1 <= hp and h1 + maxf(h2, 0.0) <= hp, "habitants par ville : Valfleuri %d, Les Granges %d" % [h1, h2])
	_check(st.dernier(str(v1), "caisse") == float(p.solde(v1)), "caisse de Valfleuri relevée")
	_check(st.dernier(Statistiques.PAYS, "caisse") == float(p.solde(Pays.PAYS)), "caisse du pays relevée")
	_check(not is_nan(st.dernier(str(v1), "chomage")), "chômage de Valfleuri : %s" % Statistiques.format("chomage", st.dernier(str(v1), "chomage")))
	_check(not is_nan(st.dernier(str(v1), "solde")), "solde du mois : %s" % Statistiques.format("solde", st.dernier(str(v1), "solde")))
	_check(not is_nan(st.dernier(Statistiques.PAYS, "satisfaction")), "satisfaction : %d/100" % st.dernier(Statistiques.PAYS, "satisfaction"))
	_check(st.serie(str(v1), "habitants").size() == 40 and st.serie(str(v1), "habitants", j0 + 30).size() == 10, "séries pour les courbes (40 points, 10 depuis le 30e jour)")
	var ev := st.evolution(str(v1), "habitants", 30)
	_check(not is_nan(ev) and ev > 0.0, "évolution sur 30 jours : %s" % Statistiques.format_ecart("habitants", ev))
	var noms := st.lieux().map(func(e) -> String: return String(e[1]))
	_check(noms.has("Valfleuri") and noms.has("Les Granges") and st.lieux()[0][0] == Statistiques.PAYS, "lieux : %s" % ", ".join(noms))

	print("Le conseiller :")
	var a := Conseiller.analyser(st, str(v1))
	_check(not a.is_empty(), "avis pour Valfleuri : %s" % ", ".join(_ids(a)))
	for x in a:
		_check(String(x.titre) != "" and String(x.texte) != "" and String(x.conseil) != "", "« %s » a un texte et un conseil" % x.titre)
	# Caisse dans le rouge.
	var avant := p.solde(v1)
	p.choisir(v1)
	bs.money = -500_000
	var alertes := []
	st.alerte.connect(func(t: String, _l: String) -> void: alertes.append(t))
	st.releve()
	a = Conseiller.analyser(st, str(v1))
	_check(_ids(a).has("caisse_rouge") and int(a[0].gravite) == 2, "caisse dans le rouge : urgent et en tête")
	_check(String(a[0].panneau) == "budget", "il propose d'ouvrir le budget")
	_check(alertes.any(func(t: String) -> bool: return t.contains("rouge")), "alerte en haut de l'écran : %s" % (alertes[0] if not alertes.is_empty() else "aucune"))
	var n_alertes := alertes.size()
	amb.unix_time += 86400.0
	st.releve()
	_check(alertes.size() == n_alertes, "l'alerte ne se répète pas le lendemain")
	bs.money = avant
	# Chômage, réseaux, bouchons, déchets : on force les chiffres du dernier relevé.
	var d: Dictionary = st.historique[-1].d
	d[str(v1)]["chomage"] = 25.0
	d[Statistiques.PAYS]["electricite"] = 70.0
	d[Statistiques.PAYS]["congestion"] = 40.0
	d[Statistiques.PAYS]["dechets"] = 4.0
	d[str(v1)]["satisfaction"] = 30.0
	d[str(v1)]["sans_ecole"] = 5.0
	a = Conseiller.analyser(st, str(v1))
	var ids := _ids(a)
	for id in ["chomage", "electricite", "bouchons", "dechets", "colere", "ecole"]:
		_check(ids.has(id), "problème repéré : %s" % id)
	var g := 2
	var trie := true
	for x in a:
		trie = trie and int(x.gravite) <= g
		g = int(x.gravite)
	_check(trie, "les plus urgents d'abord")
	d[str(v2)] = {"habitants": 0.0}
	_check(_ids(Conseiller.analyser(st, str(v2))).has("vide") or not Conseiller.analyser(st, str(v2)).is_empty(), "ville vide : un conseil quand même")

	print("Regroupement des vieux jours :")
	var st2 := Statistiques.new()
	for k in 500:
		st2.historique.append({"j": 1000 + k, "n": 1, "d": {"pays": {"habitants": float(k)}}})
	st2._compacter()
	var detail := st2.historique.filter(func(e) -> bool: return int(e.n) == 1).size()
	var total := 0
	for e in st2.historique:
		total += int(e.n)
	_check(detail <= Statistiques.JOURS_DETAIL and total == 500, "%d jours en détail, %d points en tout, 500 jours couverts" % [detail, st2.historique.size()])
	_check(is_equal_approx(float(st2.historique[0].d.pays.habitants), 14.5), "un point regroupé = la moyenne de ses jours")
	_check(st2.serie("pays", "habitants").size() == st2.historique.size(), "la courbe passe par les points regroupés")
	st2.free()

	print("Sauvegarde :")
	var sec: Dictionary = scene.save_sections()
	_check(sec.has("statistiques"), "section « statistiques »")
	var json: Dictionary = JSON.parse_string(JSON.stringify(sec.statistiques))
	var nb := st.historique.size()
	var hab_v1 := st.dernier(str(v1), "habitants")
	st.clear()
	st.from_dict(json)
	_check(st.historique.size() == nb and st.dernier(str(v1), "habitants") == hab_v1, "relevés rechargés (%d)" % nb)
	_check(st.lieux().size() == 3, "noms des villes rechargés")

	print("Panneau Maj+I :")
	var panel: StatsPanel = scene.stats_panel
	var ev_key := InputEventKey.new()
	ev_key.physical_keycode = KEY_I
	ev_key.shift_pressed = true
	ev_key.pressed = true
	panel._unhandled_key_input(ev_key)
	_check(panel.is_open(), "Maj+I ouvre le panneau")
	_check(panel.lieu == str(v1), "il montre la ville gérée (Valfleuri)")
	await process_frame
	var courbes := _find(panel, "Courbe")
	_check(courbes.size() == 1 and (courbes[0] as Courbe).series.size() == 1, "une courbe")
	panel.comparer = true
	panel.refresh()
	await process_frame
	courbes = _find(panel, "Courbe")
	_check(courbes.size() == 1 and (courbes[0] as Courbe).series.size() == 2, "comparer les villes : une courbe par ville")
	panel.ind = "electricite"
	panel.refresh()
	await process_frame
	courbes = _find(panel, "Courbe")
	_check((courbes[0] as Courbe).series.size() == 1, "électricité : une seule courbe (tout le pays)")
	panel.show_view("conseiller")
	await process_frame
	var boutons := _find(panel, "Button").filter(func(b) -> bool: return String((b as Button).text).begins_with("Ouvrir"))
	_check(not boutons.is_empty(), "cartes du conseiller avec un bouton « Ouvrir … »")
	(boutons[0] as Button).pressed.emit()
	await process_frame
	await process_frame
	_check(scene.budget_panel.is_open() or scene.avis_panel.is_open() or scene.build_panel.is_open(), "le bouton ouvre le panneau conseillé")
	panel.set_open(false)

	print("STATISTIQUES TEST OK" if ok else "STATISTIQUES TEST ÉCHEC")
	quit(0 if ok else 1)


func _find(n: Node, cls: String) -> Array:
	var out := []
	for c in n.get_children():
		if c.get_class() == cls or (c.get_script() != null and (c.get_script() as Script).get_global_name() == cls):
			out.append(c)
		out.append_array(_find(c, cls))
	return out
