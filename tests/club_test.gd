extends SceneTree
## Test du club de sport : calendrier aller-retour, fondation (stade, effectif
## avec des habitants bénévoles, subvention), saison complète (matchs, classement,
## recettes, location du stade versée à la ville), match visible au stade,
## transferts, fin de saison (montée/descente, contrats), sauvegarde, menu.
## Usage : godot --headless --path . --script res://tests/club_test.gd

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
	return Time.get_unix_time_from_datetime_string(date + "T00:00:00") + (hour - 2.0) * 3600.0


func _run() -> void:
	_donnees_tests()
	await _ville_tests()
	print("TEST OK" if ok else "TEST ÉCHEC")
	quit(0 if ok else 1)


func _donnees_tests() -> void:
	print("Données :")
	var noms := []
	for i in 12:
		noms.append("C%d" % i)
	var rr := ClubDonnees.round_robin(noms, true)
	_check(rr.size() == 22, "22 journées pour 12 clubs")
	var dom := {}
	var paires := {}
	var bon := true
	for r in rr:
		var vus := {}
		for m in r:
			bon = bon and not vus.has(m[0]) and not vus.has(m[1])
			vus[m[0]] = true
			vus[m[1]] = true
			dom[m[0]] = int(dom.get(m[0], 0)) + 1
			paires["%s>%s" % [m[0], m[1]]] = true
		bon = bon and vus.size() == 12
	_check(bon, "chaque club joue une fois par journée")
	_check(paires.size() == 132, "chaque club reçoit chacun des autres une fois (%d affiches)" % paires.size())
	var eq := true
	for k in dom:
		eq = eq and int(dom[k]) == 11
	_check(eq, "11 matchs à domicile pour chacun")
	var serie_max := 0
	for k in dom:
		var cur := 0
		var prev := ""
		for r2 in rr:
			var h := "D" if r2.any(func(m: Array) -> bool: return m[0] == k) else "E"
			cur = cur + 1 if h == prev else 1
			prev = h
			serie_max = maxi(serie_max, cur)
	_check(serie_max <= 3, "domicile et extérieur alternent (au plus %d de suite)" % serie_max)
	_check(ClubDonnees.salaire(46) < 1000.0 and ClubDonnees.salaire(74) > 15000.0, "salaires : %s en Régionale, %s en Première Ligue" % [ClubDonnees.salaire(46), ClubDonnees.salaire(74)])
	_check(ClubDonnees.valeur(70, 20, 85) > ClubDonnees.valeur(70, 33, 70), "un jeune vaut plus cher qu'un vétéran")
	var trouve := false
	for c in TerreHud.CATEGORIES:
		if String(c.id) == "club" and String(c.get("group", "")) == "loisirs" and String(c.key) == "Maj+B":
			trouve = true
	_check(trouve, "bouton Club de sport (Maj+B) dans le menu Loisirs")
	var aide := false
	for s in AidePanel.SECTIONS:
		aide = aide or String(s[0]) == "Club de sport"
	_check(aide, "section « Club de sport » dans l'aide F1")


func _ville_tests() -> void:
	print("Ville :")
	Creations.persist = false
	BatimentsVie.chantiers = false
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var bs: BuildingSystem = scene.get_node("Batiments")
	var transport: TransportSystem = scene.get_node("Transport")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 40
	world.view_radius_override = 700.0
	world.set_origin(46.2, 6.9)
	for i in 3000:
		await process_frame
		if i >= 120 and world.missing_chunk_count() == 0 and world._dirty.is_empty() and world._jobs.is_empty():
			break
	var cs: ClubSport = scene.club
	_check(cs != null and scene.club_panel != null and ClubSport.instance == cs, "club et menu branchés dans la scène")
	_check(scene.save_sections().has("club"), "section « club » dans la sauvegarde")
	var pop: Population = scene.population
	var amb: DayNight = scene.ambiance
	for n in [transport.traffic, cs, pop, scene.spectacles, scene.parc, scene.zoo, scene.musee, scene.dechets, scene.production, amb]:
		n.set_process(false)
	scene.urgences.set_process(false)
	scene.urgences.random_calls = false
	var ev: Evenements = scene.evenements
	ev.set_process(false)
	if amb.weather != null:
		amb.weather.set_process(false)
	bs.unlimited_money = false
	bs.money = 200_000_000
	amb.unix_time = _at("2026-07-20", 9.0)
	var y := world.cell_height(Vector2i(0, 0))
	var road := transport.build_segment("departementale", Vector3(-600, y, 0), Vector3(600, y, 0))
	_check(road.ok, "route de 1,2 km")
	var homes: Array[int] = []
	for i in 30:
		var c := Vector2i(-560 + i * 14, 12)
		homes.append(bs.place("maison", c, bs.best_rotation("maison", c)))
	pop._sync_buildings()
	for bid in homes:
		pop.spawn_household(bid, "famille")
	# Quelques jeunes fans de foot pour l'équipe amateur.
	var fans := 0
	for pid in pop.persons:
		var p: Dictionary = pop.persons[pid]
		var a := pop.age_of(p)
		if String(p.s) == "H" and a >= 18.0 and a <= 34.0:
			if not (p.hob as Array).has("football"):
				(p.hob as Array).append("football")
			fans += 1
	_check(fans >= 3, "%d jeunes habitants fans de foot" % fans)

	_check(cs.fonder("FC Test", 0, -1) != "", "pas de club sans stade")
	var stade := -1
	bs.require_access = false
	for r in 4:
		var fp := BuildingCatalog.footprint("stade_vaduz", r)
		for gap in [3, 6, 9]:
			for side in [1, -1]:
				var c := Vector2i(250, side * (fp.y / 2 + gap))
				if stade < 0 and bs.check_place("stade_vaduz", c, r).ok:
					stade = bs.place("stade_vaduz", c, r)
	bs.require_access = true
	if stade < 0:
		for r in 4:
			print("    r=%d " % r, bs.check_place("stade_vaduz", Vector2i(250, -70), r).reason, " ", bs.check_place("stade_vaduz", Vector2i(250, 70), r).reason)
	_check(stade > 0, "stade posé au bord de la route")
	_check(cs.stades_possibles().size() == 1 and int(cs.stades_possibles()[0].places) == 6441, "le stade est proposé (6 441 places)")
	var avant := bs.money
	_check(cs.fonder("FC Test", 1, stade) == "", "club fondé")
	_check(cs.fonde() and cs.joueurs.size() == 20, "20 joueurs au départ (%d)" % cs.joueurs.size())
	_check(absf(float(cs.club.caisse) - ClubSport.SUBVENTION_DEPART) < 1.0, "caisse du club : %s" % BuildingSystem.format_money(int(cs.club.caisse)))
	_check(avant - bs.money >= int(ClubSport.SUBVENTION_DEPART) - 1, "la ville a versé la subvention de départ")
	var benevoles := 0
	for id in cs.joueurs:
		if bool(cs.joueurs[id].benevole):
			benevoles += 1
			_check(int(cs.joueurs[id].pid) >= 0 and float(cs.joueurs[id].salaire) == 0.0, "%s : habitant bénévole" % ClubSport.nom_joueur(cs.joueurs[id])) if benevoles == 1 else null
	_check(benevoles >= 3, "%d habitants du coin dans l'équipe" % benevoles)
	_check(cs.onze().size() == 11, "onze titulaires")
	_check(cs.marche.size() == 14, "14 joueurs sur le marché")
	var js: Array = cs.ligue.journees
	_check(js.size() == 22 and (cs.ligue.clubs as Dictionary).size() == 12, "saison 2026-2027 : 22 journées, 12 clubs")
	var dates_ok := true
	var treve := false
	for j in js:
		var d := cs.date_of(int(j.d))
		dates_ok = dates_ok and int(d.wd) == 6 and int(j.d) >= ClubSport.day_of(2026, 8, 8) and int(j.d) <= ClubSport.day_of(2027, 5, 31)
		treve = treve or (int(j.d) >= ClubSport.day_of(2026, 12, 18) and int(j.d) <= ClubSport.day_of(2027, 1, 20))
		dates_ok = dates_ok and cs.mon_match(j).size() == 2
	_check(dates_ok and not treve, "samedis d'août à mai, hors trêve, le club joue chaque journée")

	# Effectif : formation, repos, force.
	var f0 := float(cs.force_equipe().force)
	var meilleur: Dictionary = cs.liste_joueurs("A")[0]
	cs.set_repos(int(meilleur.id), true)
	_check(not cs.titulaires().has(int(meilleur.id)), "un joueur au repos n'est pas aligné")
	cs.set_repos(int(meilleur.id), false)
	cs.set_formation("4-3-3")
	_check(cs.onze().filter(func(o: Dictionary) -> bool: return String(o.poste) == "A").size() == 3, "4-3-3 : trois attaquants")
	cs.set_formation("4-4-2")
	_check(f0 > 35.0 and f0 < 60.0, "force de l'équipe : %.1f" % f0)
	# Un club plus fort gagne plus souvent.
	var r := RandomNumberGenerator.new()
	r.seed = 5
	var noms_adv: Array = (cs.ligue.clubs as Dictionary).keys().filter(func(n: String) -> bool: return n != "FC Test")
	cs.ligue.clubs[noms_adv[0]].force = 70.0
	cs.ligue.clubs[noms_adv[1]].force = 40.0
	var gagne := 0
	var buts := 0
	for i in 200:
		var res := cs.simuler(noms_adv[0], noms_adv[1], r)
		if int(res.score[0]) > int(res.score[1]):
			gagne += 1
		buts += int(res.score[0]) + int(res.score[1])
	_check(gagne > 130, "le fort bat le faible %d fois sur 200" % gagne)
	cs.ligue.clubs[noms_adv[0]].force = 46.0
	cs.ligue.clubs[noms_adv[1]].force = 46.0
	buts = 0
	for i in 400:
		var res := cs.simuler(noms_adv[0], noms_adv[1], r)
		buts += int(res.score[0]) + int(res.score[1])
	_check(buts > 400 * 2.2 and buts < 400 * 3.4, "entre équipes égales : %.1f buts par match" % (buts / 400.0))

	# Transferts.
	print("Transferts :")
	var libre := {}
	for p in cs.marche:
		if bool(p.get("libre", false)) and cs.peut_acheter(p) == "":
			libre = p
			break
	if libre.is_empty():
		cs.marche[0].libre = true
		cs.marche[0].prix = 0.0
		cs.marche[0].note = 45.0
		cs.marche[0].salaire = 500.0
		libre = cs.marche[0]
	var c0 := float(cs.club.caisse)
	_check(cs.acheter(int(libre.id)) == "" and cs.joueurs.has(int(libre.id)), "joueur libre recruté")
	_check(float(cs.club.caisse) < c0, "prime à la signature payée")
	var star: Dictionary = cs.marche[0].duplicate()
	star.note = 80.0
	star.prix = 2_000_000.0
	cs.marche[0] = star
	_check(cs.peut_acheter(star) != "", "une star refuse la Régionale : %s" % cs.peut_acheter(star))
	var vend: Dictionary = cs.liste_joueurs("D").filter(func(p: Dictionary) -> bool: return not bool(p.benevole))[0]
	var c1 := float(cs.club.caisse)
	_check(cs.vendre(int(vend.id)) == "" and not cs.joueurs.has(int(vend.id)) and float(cs.club.caisse) > c1, "défenseur vendu")
	var pro: Dictionary = cs.liste_joueurs("M")[0]
	var ct := int(pro.contrat)
	_check(cs.prolonger(int(pro.id)) == "" and int(cs.joueurs[int(pro.id)].contrat) >= ct + 2, "contrat prolongé")
	_check(cs.subventionner(20_000.0) == "", "subvention de la ville")

	# Une saison complète.
	print("Saison :")
	cs.fans_force = 400
	var t := _at("2026-07-21", 0.0)
	amb.unix_time = t
	cs.clock = t
	cs.last_day = -1
	cs.advance(1.0)
	var premier := {}
	for j in js:
		var m := cs.mon_match(j)
		if String(m[0]) == "FC Test":
			premier = j
			break
	_check(not premier.is_empty(), "au moins un match à domicile")
	var ville_avant := bs.money
	var vu_match := false
	var couleurs_ok := false
	var jour_fin := ClubSport.day_of(2027, 7, 2)
	while int(cs._now(t).day) < jour_fin:
		t += 3600.0 * 3.0
		amb.unix_time = t
		cs.advance(3600.0 * 3.0)
		if not vu_match and int(cs._now(t).day) == int(premier.d) and float(cs._now(t).h) >= float(premier.h) + 0.5:
			ev._update_events(t)
			ev.matchs.step(t, 0.1)
			for e in ev.en_cours("match"):
				if bool(e.data.get("club", false)) and int(e.bid) == stade:
					vu_match = e.get("node", null) != null
					couleurs_ok = e.data.cdom == cs.club.couleurs
	_check(vu_match, "match à domicile visible au stade (joueurs, foule, tableau)")
	_check(couleurs_ok, "aux couleurs du club")
	_check(int(premier.get("affluence", 0)) > 100, "%d spectateurs au premier match" % int(premier.get("affluence", 0)))
	var hist: Array = cs.club.historique
	_check(hist.size() == 1 and String(hist[0].saison) == "2026-2027", "saison 2026-2027 terminée (%de, %d pts, %s)" % [int(hist[0].rang) if not hist.is_empty() else 0,
		int(hist[0].pts) if not hist.is_empty() else 0, String(hist[0].issue) if not hist.is_empty() else ""])
	var prec := cs.bilan(true)
	var postes: Dictionary = prec.postes
	_check(float(postes.get("Billetterie", 0.0)) > 0.0 and float(postes.get("Buvette", 0.0)) > 0.0, "billetterie %s, buvette %s" % [BuildingSystem.format_money(int(postes.get("Billetterie", 0))), BuildingSystem.format_money(int(postes.get("Buvette", 0)))])
	_check(float(postes.get("Salaires des joueurs", 0.0)) < 0.0 and float(postes.get("Location du stade (à la ville)", 0.0)) < 0.0, "salaires et location du stade payés")
	_check(float(postes.get("Prime de classement", 0.0)) > 0.0, "prime de classement")
	print("    bilan de la saison : recettes %s, dépenses %s, caisse %s" % [BuildingSystem.format_money(int(prec.recettes)), BuildingSystem.format_money(int(prec.depenses)), BuildingSystem.format_money(int(cs.club.caisse))])
	_check(bs.money > ville_avant, "la ville touche la location du stade (+%s)" % BuildingSystem.format_money(bs.money - ville_avant))
	_check(String(cs.ligue.saison) == "2027-2028", "nouvelle saison 2027-2028")
	var div_att := 1 if String(hist[0].issue) == "montee" else 0
	_check(int(cs.club.division) == div_att and int(cs.ligue.division) == div_att, "division de la nouvelle saison : %s" % ClubDonnees.division(int(cs.club.division)).nom)
	_check((cs.ligue.journees as Array).size() == 22, "nouveau calendrier de 22 journées")
	var tous := true
	for j in js:
		tous = tous and bool(j.joue)
	_check(tous, "toutes les journées de l'ancienne saison jouées")
	_check(cs.joueurs.size() >= ClubSport.MIN_JOUEURS, "effectif complet (%d)" % cs.joueurs.size())
	# Classement : 22 matchs chacun pendant la saison passée (vérifié sur une saison jouée à part).
	var lg_test := cs.ligue.duplicate(true)
	_check((lg_test.clubs as Dictionary).values().all(func(c: Dictionary) -> bool: return int(c.j) == 0), "classement remis à zéro")

	# Matchs (événements) : le club fixe les matchs de son stade.
	var nn := {"day": ClubSport.day_of(2027, 9, 4), "month": 9, "mday": 4, "wd": 6}
	ev.matchs.plan_day(nn)
	var autre := false
	for e in ev.prevus("match"):
		if int(e.bid) == stade and not bool(e.data.get("club", false)):
			autre = true
	_check(not autre, "pas de match inventé de plus au stade du club")

	# Sauvegarde.
	print("Sauvegarde :")
	var d := cs.to_dict()
	var back: Dictionary = JSON.parse_string(JSON.stringify(d))
	var nom := String(cs.club.nom)
	var nj := cs.joueurs.size()
	var caisse := int(cs.club.caisse)
	var rang := cs.rang()
	cs.clear()
	_check(not cs.fonde(), "club effacé")
	cs.from_dict(back)
	_check(cs.fonde() and String(cs.club.nom) == nom and cs.joueurs.size() == nj and int(cs.club.caisse) == caisse and cs.rang() == rang, "club rechargé à l'identique")
	_check(cs.onze().size() == 11 and (cs.ligue.journees as Array).size() == 22, "onze et calendrier rechargés")
	var jj: Dictionary = cs.ligue.journees[0]
	_check(jj.d is int and cs.joueurs.keys()[0] is int, "nombres entiers après rechargement")

	# Menu.
	print("Menu :")
	var panel: ClubPanel = scene.club_panel
	panel.set_open(true)
	for v in ["club", "effectif", "calendrier", "classement", "transferts", "finances"]:
		panel.show_view(v)
		_check(panel._body.get_child_count() > 2, "onglet %s (%d lignes)" % [v, panel._body.get_child_count()])
	panel.set_open(false)
	scene.queue_free()
	await process_frame
