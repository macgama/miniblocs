extends SceneTree
## Test de la santé publique : maladies datées par époque, calendrier des
## grandes épidémies (rumeur puis choléra de 1832), contagion par l'eau (puits
## souillés, égouts, eau bouillie), vaccins (campagne, refus, obligation,
## immunité collective), mesures sanitaires (dates, effets, coût, levée
## automatique), traitements de l'époque, sauvegarde, panneau F7.
## Usage : godot --headless --path . --script res://tests/sante_test.gd

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


func _at(date: String, hour: float) -> float:
	return Time.get_unix_time_from_datetime_string(date + "T00:00:00") + (hour - 1.0) * 3600.0


func _annee(r: ReglagesPartie, a: int) -> void:
	r.annee_depart = a
	r.histoire_saut = 0
	r.histoire_debut = 0.0


## Un jour de jeu pour les événements et la santé publique.
func _jour(ev: Evenements, sp: SantePublique, amb: DayNight) -> void:
	amb.unix_time += 86400.0
	ev._process(0.1)
	sp._process(0.0)


func _run() -> void:
	Creations.persist = false
	BatimentsVie.chantiers = false

	print("Données :")
	for pd in SanteDonnees.PANDEMIES:
		_check(Epidemies.MALADIES.has(String(pd.maladie)) and Epidemies.circule(String(pd.maladie), int(pd.annee)),
			"%s : maladie connue et qui circule en %d" % [pd.nom, int(pd.annee)])
	for v in SanteDonnees.VACCINS:
		for m in SanteDonnees.VACCINS[v].maladies:
			_check(Epidemies.MALADIES.has(String(m)), "vaccin %s → %s" % [v, m])
	_check(Epidemies.circule("variole", 1850) and not Epidemies.circule("variole", 2000), "variole jusqu'en 1977 seulement")
	_check(not Epidemies.du_moment(2026).has("cholera") and Epidemies.du_moment(1832).has("cholera"), "choléra en 1832, pas en 2026")
	_check(Epidemies.du_moment(2026).has("grippe") and Epidemies.du_moment(2026).has("rougeole"), "grippe et rougeole de nos jours")
	_check(SanteDonnees.hesitants(1800) > SanteDonnees.hesitants(1960), "on refuse plus le vaccin en 1800 qu'en 1960")

	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var transport: TransportSystem = scene.get_node("Transport")
	var bs: BuildingSystem = scene.get_node("Batiments")
	var amb: DayNight = scene.get_node("Ambiance")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.set_origin(48.8584, 2.2945)
	for i in 60:
		await process_frame
	var ev: Evenements = scene.evenements
	var pop: Population = scene.population
	var sp: SantePublique = scene.sante
	_check(sp != null and SantePublique.instance == sp and sp.ev == ev, "santé publique branchée (SantePublique.instance)")
	ev.forcer_auto = 0
	ev.forcer_catastrophes = 0
	amb.set_speed(0)
	amb.unix_time = _at("2026-03-10", 10.0)
	var r := ReglagesPartie.actuel
	_annee(r, 0)

	print("Une petite ville (bâtie aujourd'hui, puis renvoyée en 1831) :")
	bs.unlimited_money = true
	var y := world.cell_height(Vector2i(0, 0))
	_check(transport.build_segment("route", Vector3(0, y, -400), Vector3(0, y, 400)).ok, "route nord-sud")
	var homes := []
	for i in 8:
		homes.append(bs.place("maison", Vector2i(-12, -200 + i * 15), 1))
	for i in 4:
		homes.append(bs.place("immeuble", Vector2i(16, -200 + i * 22), 3))
	var office := bs.place("bureaux", Vector2i(20, 60), 3)
	var school := bs.place("ecole", Vector2i(-30, 60), 1)
	_check(not homes.has(-1) and office > 0 and school > 0, "12 logements, bureaux, école")
	pop._sync_buildings()
	for i in 72:
		pop.advance(300.0)
	_check(pop.persons.size() > 40, "%d habitants" % pop.persons.size())
	_annee(r, 1831)
	_check(Epoques.annee() == 1831, "partie en 1831")
	sp._process(0.0)

	print("Hygiène :")
	var h := sp.hygiene(int(homes[0]))
	_check(not bool(h.reseau) and float(h.egout) < 0.5, "sans réseau : eau du puits et fosse d'aisance (%s)" % String(h.txt))
	var b := sp.bilan()
	_check(int(b.hab) > 0 and float(b.puits) > 0.99 and float(b.egouts) == 0.0, "bilan : tout le monde boit au puits")
	var someone: Dictionary = pop.persons[pop.persons.keys()[0]]
	var why: Array = pop.vie.health(someone).why
	_check(" ".join(why).contains("fosse d'aisance"), "en 1831, un logement insalubre pèse sur la santé")
	_check(not sp.conseils().is_empty(), "le panneau conseille des égouts et de l'eau potable")

	print("Calendrier des grandes épidémies :")
	sp.forcer_historiques = 1
	var news0 := ev.journal.size()
	_jour(ev, sp, amb)
	_check(String(sp.pandemies.get("1832", "")) == "rumeur" and ev.journal.size() > news0, "1831 : la rumeur du choléra arrive dans la gazette")
	_check(ev.epidemies.active < 0, "pas encore d'épidémie en 1831")
	Epoques.aller_a(1832)
	var eid := -1
	for d in 400:
		_jour(ev, sp, amb)
		if ev.epidemies.active >= 0:
			eid = ev.epidemies.active
			break
	_check(eid > 0 and String(ev.events[eid].data.maladie) == "cholera" and String(ev.events[eid].nom) == "Choléra de 1832", "1832 : le choléra arrive")
	_check(String(sp.pandemies.get("1832", "")) == "fait", "l'épidémie de 1832 est cochée au calendrier")
	var max_sick := 0
	for d in 120:
		_jour(ev, sp, amb)
		max_sick = maxi(max_sick, ev.epidemies.malades_count())
		if ev.epidemies.active < 0:
			break
	var ee: Dictionary = ev.events[eid]
	_check(String(ee.etat) == "fini", "le choléra finit par s'éteindre (%d malades, au plus %d en même temps, %d décès)" % [int(ee.data.total), max_sick, int(ee.data.deces)])
	_check(not sp.historique.is_empty() and String(sp.historique[0].maladie) == "cholera", "l'épidémie entre dans l'histoire de la ville")

	print("Contagion par l'eau (1855, après le docteur Snow) :")
	Epoques.aller_a(1855)
	var malades := {}
	var pids := pop.persons.keys()
	for i in 4:
		malades[int(pids[i * 7])] = {}
	var rng := RandomNumberGenerator.new()
	var sans := 0
	rng.seed = 7
	for t in 30:
		sans += sp.contamines_eau(malades, "cholera", rng).size()
	sp.set_mesure("eau_bouillie", true)
	var bouillie := 0
	rng.seed = 7
	for t in 30:
		bouillie += sp.contamines_eau(malades, "cholera", rng).size()
	sp.set_mesure("eau_bouillie", false)
	_check(sans > 0, "puits souillés : %d contaminations en 30 jours" % sans)
	_check(bouillie < sans, "eau bouillie : %d au lieu de %d" % [bouillie, sans])
	# Tout le monde raccordé aux égouts et à une eau potable (cache d'hygiène).
	for hid in pop.households:
		sp._hyg_cache[int(pop.households[hid].b)] = {"eau": 1.0, "egout": 1.0, "total": 1.0, "reseau": true, "txt": "test"}
	rng.seed = 7
	var egouts := 0
	for t in 30:
		egouts += sp.contamines_eau(malades, "cholera", rng).size()
	_check(egouts == 0, "avec des égouts et de l'eau potable : plus aucune contamination par l'eau")
	sp._caches()

	print("Vaccins :")
	_check(sp.vaccin_disponible("variole") and not sp.vaccin_disponible("diphterie"), "1855 : vaccin contre la variole, pas encore contre la diphtérie")
	bs.unlimited_money = false
	bs.money = 10_000_000
	var m0 := bs.money
	_check(sp.lancer_campagne("variole") and sp.campagnes.has("variole"), "campagne de vaccination lancée")
	for d in 12:
		_jour(ev, sp, amb)
	var cv := sp.couverture("variole")
	_check(cv > 0.4 and cv < 0.85, "campagne : %d %% de vaccinés, une partie refuse" % roundi(cv * 100.0))
	_check(not sp.campagnes.has("variole"), "la campagne se termine quand tous les volontaires sont vaccinés")
	_check(bs.money < m0, "les doses sont payées par la ville (%s)" % BuildingSystem.format_money(m0 - bs.money))
	sp.set_obligatoire("variole", true)
	for d in 6:
		_jour(ev, sp, amb)
	_check(sp.couverture("variole") >= SantePublique.SEUIL_COLLECTIF, "obligation vaccinale : %d %%" % roundi(sp.couverture("variole") * 100.0))
	_check(sp.immunite_collective("variole"), "immunité collective contre la variole")
	var protege := 0
	var vac: Dictionary = sp.vaccins.variole
	for pid in vac:
		if sp.protege(int(pid), "variole"):
			protege += 1
	_check(protege > vac.size() * 0.85, "les vaccinés sont protégés (%d / %d)" % [protege, vac.size()])
	var vid := ev.epidemies.start("variole", false)
	var tv := 0
	for d in 60:
		_jour(ev, sp, amb)
		if ev.epidemies.active < 0:
			break
	tv = int(ev.events[vid].data.total) if ev.events.has(vid) else 0
	_check(tv <= 6, "épidémie de variole dans une ville vaccinée : %d malades seulement" % tv)

	print("Mesures sanitaires :")
	Epoques.aller_a(1832)
	sp.set_mesure("hygiene", true)
	_check(not sp.mesures.has("hygiene"), "pas de campagne d'hygiène avant Semmelweis (1847)")
	sp.set_mesure("chloration", true)
	_check(not sp.mesures.has("chloration"), "pas de chlore dans l'eau avant 1902")
	sp.set_mesure("quarantaine", true)
	sp.set_mesure("ecoles", true)
	_check(absf(sp.facteur_contagion("grippe", "travail") - 1.0 / 3.0) < 0.01 and sp.facteur_contagion("grippe", "foyer") == 1.0, "quarantaine : contagion hors du foyer ÷3")
	_check(sp.facteur_contagion("grippe", "ecole") == 0.0, "écoles fermées : plus de contagion à l'école")
	_check(float(sp.budget_entretien().values()[0]) > 0.0, "les mesures coûtent chaque mois (%s)" % BuildingSystem.format_money(int(sp.budget_entretien().values()[0])))
	var av: Array = sp._avis_mesures()
	_check(float(av[0]) < 0.0 and " ".join(av[1]).contains("écoles"), "les habitants n'aiment pas les écoles fermées (%d)" % roundi(float(av[0])))
	for d in SantePublique.LEVEE_JOURS + 1:
		_jour(ev, sp, amb)
	_check(not sp.mesures.has("quarantaine") and not sp.mesures.has("ecoles"), "mesures temporaires levées une semaine après l'épidémie")
	Epoques.aller_a(1860)
	sp.set_mesure("hygiene", true)
	for d in SantePublique.LEVEE_JOURS + 1:
		_jour(ev, sp, amb)
	_check(sp.mesures.has("hygiene"), "la campagne d'hygiène, elle, reste")

	print("Traitements de l'époque :")
	Epoques.aller_a(1860)
	var f1832 := sp.facteur_letalite("cholera", false, false)
	Epoques.aller_a(1950)
	var f1950 := sp.facteur_letalite("cholera", false, false)
	_check(f1950 < f1832 * 0.3, "en 1950 on soigne le choléra (létalité ×%.2f)" % f1950)
	_check(sp.mesure_disponible("chloration") and sp.vaccin_disponible("diphterie") and not sp.vaccin_disponible("rougeole"), "1950 : chlore et diphtérie, pas encore la rougeole")
	sp._caches()
	var why50: Array = pop.vie.health(someone).why
	_check(not " ".join(why50).contains("fosse d'aisance"), "après 1950, plus de malus d'hygiène (le réseau s'en charge)")

	print("Sauvegarde :")
	var data: Dictionary = JSON.parse_string(JSON.stringify(scene.save_sections().sante))
	var nvac := (sp.vaccins.variole as Dictionary).size()
	var nhist := sp.historique.size()
	sp.clear()
	_check(sp.vaccins.is_empty() and sp.mesures.is_empty(), "remise à zéro")
	sp.from_dict(data)
	_check((sp.vaccins.get("variole", {}) as Dictionary).size() == nvac and sp.obligatoires.has("variole"), "vaccinés et obligation rechargés (%d)" % nvac)
	_check(sp.mesures.has("hygiene") and sp.historique.size() == nhist and String(sp.pandemies.get("1832", "")) == "fait", "mesures, histoire et calendrier rechargés")

	print("Panneau F7 :")
	var panel: SantePanel = scene.sante_panel
	for v in ["bilan", "vaccins", "mesures", "histoire"]:
		panel.set_open(true)
		panel.show_view(v)
		_check(panel._body.get_child_count() > 2, "onglet %s" % v)
	var key := InputEventKey.new()
	key.keycode = KEY_F7
	key.pressed = true
	panel._unhandled_key_input(key)
	_check(not panel.is_open(), "F7 ferme le panneau")
	var found := false
	for c in TerreHud.CATEGORIES:
		if String(c.id) == "sante" and String(c.group) == "infos":
			found = true
	_check(found and scene.hud.has_signal("sante_requested"), "bouton Santé publique dans le menu Infos")

	print("Partie à l'époque actuelle :")
	_annee(r, 0)
	sp.forcer_historiques = -1
	_check(not sp.historiques_actifs(), "pas de calendrier historique sans époque")
	_check(sp.vaccin_disponible("covid") and sp.mesure_disponible("confinement"), "tous les vaccins et toutes les mesures de nos jours")

	print("SANTE TEST OK" if ok else "SANTE TEST ÉCHEC")
	quit(0 if ok else 1)
