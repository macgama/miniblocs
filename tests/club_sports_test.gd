extends SceneTree
## Test du club multisport (v2) : données des sports, salles et patinoire au
## catalogue, fondation d'un club par sport, matchs (scores, prolongations,
## bonus, nuls), saison complète, matchs visibles, centre de formation
## (jeunes de la ville, promotions), supporters (humeur, drapeaux, abonnements,
## fête), sauvegarde et menu.
## Usage : godot --headless --path . --script res://tests/club_sports_test.gd

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
	var bon := true
	for s in ClubSports.ORDRE:
		var S := ClubSports.sport(s)
		var n := ClubSports.titulaires(s, String(S.formation))
		bon = bon and (S.effectif as Array).size() >= n and int(S.min) <= (S.effectif as Array).size() and int(S.max) > int(S.min)
		bon = bon and (S.divisions as Array).size() == ClubSports.nb_divisions(s)
		for f in S.formations:
			var b := ClubSports.besoins(s, String(f))
			for k in b:
				bon = bon and (S.postes as Dictionary).has(k)
		for p in S.effectif + S.marche + S.jeunes:
			bon = bon and (S.postes as Dictionary).has(p)
		bon = bon and Metiers.LOISIRS.has(String(S.hobby))
	_check(bon, "6 sports : postes, compositions, effectifs, divisions, loisir des habitants")
	_check(ClubSports.titulaires("basket", "1-2-2") == 5 and ClubSports.titulaires("handball", "Classique") == 7
		and ClubSports.titulaires("rugby", "Jeu d'avants") == 15 and ClubSports.titulaires("tennis", "4 simples et 2 doubles") == 4, "5 au basket, 7 au hand, 15 au rugby, 4 joueurs au tennis")
	_check(ClubSports.titulaires("football", "4-4-2") == 11, "le foot garde son onze")
	# Chronomètre.
	var mono := true
	for s in ClubSports.ORDRE:
		var prev := -2.0
		var d := ClubSports.duree(s)
		var t := -60.0
		while t <= d + 120.0:
			var c := ClubSports.chrono(s, t)
			mono = mono and float(c.m) >= prev
			prev = float(c.m)
			t += 30.0
		var fin := ClubSports.chrono(s, d + 60.0)
		mono = mono and String(fin.per) == "fin"
	_check(mono, "chronomètre de chaque sport : le temps de jeu avance, puis « fin »")
	_check(String(ClubSports.chrono("basket", 30.0 * 60.0).per) == "2e quart-temps" and String(ClubSports.chrono("hockey", 36.0 * 60.0).per) == "pause",
		"basket en quart-temps, hockey en tiers-temps avec pauses")
	_check(absf(ClubSports.duree("tennis") / 3600.0 - 5.67) < 0.1, "rencontre de tennis : %.1f h" % (ClubSports.duree("tennis") / 3600.0))
	_check(ClubSports.division("basket", 3).nom == "Élite" and float(ClubSports.division("basket", 3).tv) < float(ClubDonnees.division(3).tv), "Élite du basket : moins de droits télé que le foot")
	_check(ClubSports.salaire("tennis", 60.0) < ClubSports.salaire("football", 60.0), "salaires plus bas au tennis")
	# Bâtiments.
	var types_ok := true
	for id in ClubTypes.ORDER:
		var t := BuildingCatalog.get_type(id)
		types_ok = types_ok and String(t.get("cat", "")) == "sport" and BuildingCatalog.cost(id) > 0
		var m := BuildingCatalog.build_mesh(id)
		var ab := m.get_aabb()
		types_ok = types_ok and m.get_surface_count() > 0 and ab.size.x <= float(t.w) + 0.05 and ab.size.z <= float(t.d) + 0.05
		if not types_ok:
			print("    ", id, " ", ab)
	_check(types_ok, "salle omnisports, palais des sports, patinoire, centre de tennis, centre de formation au catalogue Sport")
	_check(ClubSports.accueille("basket", "salle_omnisports") and ClubSports.accueille("handball", "palais_sports") and not ClubSports.accueille("hockey", "salle_omnisports"),
		"basket et hand en salle, pas le hockey")
	_check(ClubSports.accueille("hockey", "patinoire_hockey") and ClubSports.accueille("hockey", "patinoire") and ClubSports.accueille("tennis", "centre_tennis") and ClubSports.accueille("tennis", "tennis")
		and ClubSports.accueille("basket", "gymnase") and ClubSports.accueille("rugby", "foot") and ClubSports.accueille("rugby", "stade_vaduz"),
		"patinoire, courts, gymnase, terrains et stades pour les bons sports")
	_check(ClubSports.places_lieu("patinoire_hockey") == 4000 and ClubSports.places_lieu("gymnase") == 200, "places : 4 000 à la patinoire, 200 au gymnase")


## Pose un bâtiment près de la route (côté sud), en cherchant une place libre.
func _poser(bs: BuildingSystem, id: String, x0: int) -> int:
	bs.require_access = false
	var bid := -1
	for r in [0, 2, 1, 3]:
		var fp := BuildingCatalog.footprint(id, r)
		for dx in range(0, 400, 10):
			for gap in [6, 9, 12]:
				if bid > 0:
					break
				var c := Vector2i(x0 + dx, -(fp.y / 2 + gap))
				if bs.check_place(id, c, r).ok:
					bid = bs.place(id, c, r)
		if bid > 0:
			break
	bs.require_access = true
	if bid < 0:
		var fp := BuildingCatalog.footprint(id, 0)
		print("    pas de place pour ", id, " : ", bs.check_place(id, Vector2i(x0, -(fp.y / 2 + 4)), 0).reason)
	return bid


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
	world.view_radius_override = 900.0
	world.set_origin(46.2, 6.9)
	for i in 3000:
		await process_frame
		if i >= 120 and world.missing_chunk_count() == 0 and world._dirty.is_empty() and world._jobs.is_empty():
			break
	var clubs: Dictionary = scene.clubs
	_check(clubs.size() == 6 and ClubSport.section("hockey") == clubs.hockey and scene.club == clubs.football, "six sections dans la scène (football = ClubSport.instance)")
	var pop: Population = scene.population
	var amb: DayNight = scene.ambiance
	for n in [transport.traffic, pop, scene.spectacles, scene.parc, scene.zoo, scene.musee, scene.dechets, scene.production, amb, scene.club_supporters]:
		n.set_process(false)
	for s in clubs:
		(clubs[s] as ClubSport).set_process(false)
	scene.urgences.set_process(false)
	scene.urgences.random_calls = false
	var ev: Evenements = scene.evenements
	ev.set_process(false)
	if amb.weather != null:
		amb.weather.set_process(false)
	bs.unlimited_money = false
	bs.money = 400_000_000
	amb.unix_time = _at("2026-07-20", 9.0)
	var y := world.cell_height(Vector2i(0, 0))
	_check(transport.build_segment("departementale", Vector3(-700, y, 0), Vector3(700, y, 0)).ok, "route de 1,4 km")
	var homes: Array[int] = []
	for i in 40:
		var c := Vector2i(-660 + i * 14, 12)
		homes.append(bs.place("maison", c, bs.best_rotation("maison", c)))
	pop._sync_buildings()
	for bid in homes:
		pop.spawn_household(bid, "famille")
	# Des habitants qui pratiquent chaque sport (jeunes adultes et ados).
	var ados := 0
	var i_p := 0
	for pid in pop.persons:
		var p: Dictionary = pop.persons[pid]
		var a := pop.age_of(p)
		if String(p.s) == "H" and a >= 13.5 and a <= 34.0:
			for h in ["basket", "handball", "hockey", "rugby", "tennis"]:
				if (i_p + h.length()) % 2 == 0 and not (p.hob as Array).has(h):
					(p.hob as Array).append(h)
			if not (p.hob as Array).has("basket"):
				(p.hob as Array).append("basket")
			if a < 17.5:
				ados += 1
			i_p += 1
	_check(i_p >= 8, "%d jeunes habitants sportifs (%d ados)" % [i_p, ados])

	# Bâtiments et fondation.
	var salle := _poser(bs, "salle_omnisports", -650)
	var pat := _poser(bs, "patinoire_hockey", -540)
	var ten := _poser(bs, "centre_tennis", -420)
	var stade := _poser(bs, "stade_vaduz", -300)
	_check(salle > 0 and pat > 0 and ten > 0 and stade > 0, "salle omnisports, patinoire, centre de tennis et stade posés")
	var bk: ClubSport = clubs.basket
	var hb: ClubSport = clubs.handball
	var hk: ClubSport = clubs.hockey
	var rg: ClubSport = clubs.rugby
	var tn: ClubSport = clubs.tennis
	_check(hk.fonder("HC Test", 0, salle) != "", "pas de hockey dans une salle de basket : « %s »" % hk.fonder("HC Test", 0, salle))
	_check(bk.stades_possibles().size() == 1 and int(bk.stades_possibles()[0].places) == 2500, "la salle est proposée au basket (2 500 places)")
	var avant := bs.money
	_check(bk.fonder("BC Test", 2, salle) == "" and hb.fonder("HBC Test", 3, salle) == "" and hk.fonder("HC Test", 4, pat) == ""
		and rg.fonder("RC Test", 6, stade) == "" and tn.fonder("TC Test", 8, ten) == "", "cinq clubs fondés")
	_check(avant - bs.money >= int(bk.subvention_depart() + hk.subvention_depart() + tn.subvention_depart()) and bk.subvention_depart() < ClubSport.SUBVENTION_DEPART,
		"subventions de départ versées (basket : %s)" % BuildingSystem.format_money(int(bk.subvention_depart())))
	_check(bk.joueurs.size() == 12 and bk.onze().size() == 5 and hk.onze().size() == 16 and rg.onze().size() == 15 and tn.onze().size() == 4 and hb.onze().size() == 7,
		"effectifs : 12 au basket, alignements 5 / 7 / 16 / 15 / 4")
	var benev := 0
	for id in bk.joueurs:
		if int(bk.joueurs[id].pid) >= 0:
			benev += 1
	_check(benev >= 3, "%d habitants de la ville dans l'équipe de basket" % benev)
	_check(clubs.football.fonder("FC Test", 1, stade) == "", "le club de foot partage le stade du rugby")
	_check(ClubSport.lieu_pris(stade) != "" and ClubSport.lieu_pris(stade, "football") == "rugby" and ClubSport.lieu_pris(salle) != "", "stade et salle réservés aux clubs")
	# Calendriers.
	var jb: Array = bk.ligue.journees
	var sam := true
	for j in jb:
		var d := bk.date_of(int(j.d))
		sam = sam and int(d.wd) == 6 and int(j.d) >= ClubSport.day_of(2026, 10, 1) and int(j.d) <= ClubSport.day_of(2027, 5, 15)
	_check(jb.size() == 22 and sam, "basket : 22 journées le samedi, d'octobre à mi-mai")
	var jh: Array = hb.ligue.journees
	_check(jh.size() == 22 and int(hb.date_of(int(jh[0].d)).wd) == 5, "handball : le vendredi soir")
	var jt: Array = tn.ligue.journees
	var dim := true
	for j in jt:
		dim = dim and int(tn.date_of(int(j.d)).wd) == 0 and int(j.d) >= ClubSport.day_of(2027, 3, 1) and int(j.d) <= ClubSport.day_of(2027, 6, 28)
	_check(jt.size() == 7 and (tn.ligue.clubs as Dictionary).size() == 8 and dim, "tennis : poule de 8, 7 dimanches de mars à juin")
	var jk: Array = hk.ligue.journees
	var jr: Array = rg.ligue.journees
	_check(jr.size() == 22 and int(rg.date_of(int(jr[0].d)).wd) == 0, "rugby : le dimanche (le foot garde le samedi)")
	_check(hk.ligue.journees.size() == 22 and int(hk.date_of(int(hk.ligue.journees[-1].d)).month) <= 3, "hockey : saison finie en mars")

	# Scores.
	print("Matchs :")
	var r := RandomNumberGenerator.new()
	r.seed = 9
	for c in [bk, hb, hk, rg, tn]:
		var noms: Array = (c.ligue.clubs as Dictionary).keys().filter(func(n: String) -> bool: return not bool(c.ligue.clubs[n].moi))
		c.ligue.clubs[noms[0]].force = 50.0
		c.ligue.clubs[noms[1]].force = 50.0
	var nuls := 0
	var pts := 0
	var prol := 0
	var noms_b: Array = (bk.ligue.clubs as Dictionary).keys().filter(func(n: String) -> bool: return not bool(bk.ligue.clubs[n].moi))
	for i in 300:
		var res := bk.simuler(noms_b[0], noms_b[1], r)
		nuls += 1 if int(res.score[0]) == int(res.score[1]) else 0
		pts += int(res.score[0]) + int(res.score[1])
		prol += 1 if bool(res.get("prol", false)) else 0
		var somme := 0
		for g in res.buts:
			somme += int(g.pts)
		if somme != int(res.score[0]) + int(res.score[1]):
			nuls += 1000
	_check(nuls == 0, "basket : jamais de nul, les paniers font le score")
	_check(pts / 300.0 > 140.0 and pts / 300.0 < 180.0 and prol > 0, "basket : %.0f points par match, %d prolongations sur 300" % [pts / 300.0, prol])
	var noms_k: Array = (hk.ligue.clubs as Dictionary).keys().filter(func(n: String) -> bool: return not bool(hk.ligue.clubs[n].moi))
	var tab := 0
	nuls = 0
	var buts := 0
	for i in 300:
		var res := hk.simuler(noms_k[0], noms_k[1], r)
		nuls += 1 if int(res.score[0]) == int(res.score[1]) else 0
		buts += int(res.score[0]) + int(res.score[1])
		tab += 1 if String(res.get("suffixe", "")) == "t.a.b." else 0
	_check(nuls == 0 and tab > 5 and buts / 300.0 > 4.5 and buts / 300.0 < 8.0, "hockey : %.1f buts par match, pas de nul (%d tirs au but)" % [buts / 300.0, tab])
	var noms_r: Array = (rg.ligue.clubs as Dictionary).keys().filter(func(n: String) -> bool: return not bool(rg.ligue.clubs[n].moi))
	var bonus := 0
	var total := 0
	for i in 200:
		var res := rg.simuler(noms_r[0], noms_r[1], r)
		bonus += int(res.bonus[0]) + int(res.bonus[1])
		total += int(res.score[0]) + int(res.score[1])
	_check(bonus > 10 and total / 200.0 > 25.0 and total / 200.0 < 60.0, "rugby : %.0f points par match, %d points de bonus" % [total / 200.0, bonus])
	var noms_t: Array = (tn.ligue.clubs as Dictionary).keys().filter(func(n: String) -> bool: return not bool(tn.ligue.clubs[n].moi))
	var six := true
	var nul_t := 0
	for i in 200:
		var res := tn.simuler(noms_t[0], noms_t[1], r)
		six = six and int(res.score[0]) + int(res.score[1]) == 6 and (res.buts as Array).size() == 6
		nul_t += 1 if int(res.score[0]) == 3 else 0
	_check(six and nul_t > 0, "tennis : 6 parties par rencontre, le 3 – 3 existe (%d)" % nul_t)
	var noms_h: Array = (hb.ligue.clubs as Dictionary).keys().filter(func(n: String) -> bool: return not bool(hb.ligue.clubs[n].moi))
	var hand := 0
	for i in 200:
		var res := hb.simuler(noms_h[0], noms_h[1], r)
		hand += int(res.score[0]) + int(res.score[1])
	_check(hand / 200.0 > 45.0 and hand / 200.0 < 65.0, "handball : %.0f buts par match" % (hand / 200.0))
	# Classement : points du hockey (victoire après prolongation : 2, défaite : 1).
	var fiche := ClubSport._fiche("X", ["000000", "ffffff"], 50.0, false)
	hk.ligue.clubs["X"] = fiche
	hk._compter("X", 3, 2, true)
	hk._compter("X", 1, 2, true)
	hk._compter("X", 4, 1, false)
	_check(int(fiche.pts) == 6, "hockey : 2 + 1 + 3 points (%d)" % int(fiche.pts))
	hk.ligue.clubs.erase("X")

	# Centre de formation.
	print("Centre de formation :")
	_check(bk.set_academie(2) != "", "niveau 2 refusé sans bâtiment")
	_check(bk.set_academie(1) == "" and bk.espoirs.size() == 3, "école de sport : 3 jeunes (%d)" % bk.espoirs.size())
	var de_la_ville := 0
	for id in bk.espoirs:
		if int(bk.espoirs[id].pid) >= 0:
			de_la_ville += 1
	_check(de_la_ville >= 2, "%d jeunes de la ville au centre" % de_la_ville)
	var cf := _poser(bs, "centre_formation", -180)
	_check(cf > 0 and bk.centre_bati(), "centre de formation bâti")
	_check(bk.set_academie(3) == "", "académie de haut niveau ouverte")
	var e0: Dictionary = bk.liste_espoirs()[0]
	var n0 := float(e0.note)
	for w in 10:
		bk._semaine_espoirs(1.0)
	_check(float(bk.espoirs[int(e0.id)].note) > n0 + 2.0, "les espoirs progressent (%d → %d)" % [int(n0), int(bk.espoirs[int(e0.id)].note)])
	var nj := bk.joueurs.size()
	_check(bk.promouvoir(int(e0.id)) == "" and bk.joueurs.size() == nj + 1 and bool(bk.joueurs[int(e0.id)].forme_club), "un espoir signe pro (formé au club)")

	# Saison complète des cinq sports.
	print("Saison :")
	for c in [bk, hb, hk, rg, tn]:
		c.fans_force = 300
	var t := _at("2026-07-21", 0.0)
	amb.unix_time = t
	for c in [bk, hb, hk, rg, tn]:
		c.clock = t
		c.last_day = -1
		c.advance(1.0)
	var dom_b := {}
	for j in jb:
		if String(bk.mon_match(j)[0]) == "BC Test":
			dom_b = j
			break
	var vu := false
	var tableau := ""
	var jour_fin := ClubSport.day_of(2027, 7, 2)
	while int(bk._now(t).day) < jour_fin:
		t += 3600.0 * 3.0
		amb.unix_time = t
		for c in [bk, hb, hk, rg, tn]:
			c.advance(3600.0 * 3.0)
		if not vu and int(bk._now(t).day) == int(dom_b.d) and bool(dom_b.get("prepare", false)):
			var tt := ev.unix_at(int(dom_b.d), float(dom_b.h)) + 30.0 * 60.0
			ev._update_events(tt)
			ev.matchs.step(tt, 0.1)
			for e in ev.en_cours("match"):
				if bool(e.data.get("club", false)) and int(e.bid) == salle and String(e.data.get("sport", "")) == "basket":
					vu = e.get("node", null) != null
					if vu:
						tableau = String((e.anim.label as Label3D).text)
	_check(vu, "match de basket visible dans la salle (joueurs, tribunes, tableau)")
	_check(tableau.contains("quart-temps"), "tableau d'affichage : « %s »" % tableau.replace("\n", " · "))
	for c: ClubSport in [bk, hb, hk, rg, tn]:
		var h: Array = c.club.historique
		var bil: Dictionary = c.bilan(true)
		_check(h.size() == 1 and float(bil.postes.get("Billetterie", 0.0)) > 0.0 and String(c.ligue.saison) == "2027-2028",
			"%s : saison jouée (%se, %d pts), billetterie %s" % [c.sport, str(h[0].rang) if not h.is_empty() else "?", int(h[0].pts) if not h.is_empty() else 0,
			BuildingSystem.format_money(int(bil.postes.get("Billetterie", 0)))])
	var g_tot := 0
	var nuls_k := 0
	for j in jk:
		for sc in j.scores:
			g_tot += 1
			nuls_k += 1 if int(sc[0]) == int(sc[1]) else 0
	_check(g_tot == 22 * 6 and nuls_k == 0, "hockey : un vainqueur à chacun des %d matchs de la saison" % g_tot)
	_check(float(bk.bilan(true).postes.get("Centre de formation", 0.0)) < 0.0, "le centre de formation coûte chaque mois")
	_check(int(bk.club.abo) > 0 and float(bk.bilan().postes.get("Abonnements", 0.0)) > 0.0, "abonnements vendus pour 2027-2028 : %d" % int(bk.club.abo))
	_check(bk.espoirs.size() >= 3, "nouvelle promotion de jeunes (%d espoirs)" % bk.espoirs.size())

	# Supporters.
	print("Supporters :")
	bk._supporters_cache = -1
	_check(bk.supporters_habitants() > 5, "%d habitants supporters du basket" % bk.supporters_habitants())
	var fan := {}
	for pid in pop.persons:
		if bk.est_supporter(pop.persons[pid]):
			fan = pop.persons[pid]
			break
	bk.club.humeur = 0.8
	var sat := bk.satisfaction_of(fan)
	_check(float(sat[0]) > 3.0 and String(sat[1][0]).contains("BC Test"), "supporter content quand le club gagne : %s" % str(sat[1]))
	bk.club.humeur = -0.8
	_check(float(bk.satisfaction_of(fan)[0]) < -2.0, "et déçu quand il perd")
	bk.club.humeur = 0.5
	var ids := []
	for f in bk.avis_facteurs():
		ids.append(String(f.id))
	_check(ids.has("club_basket"), "facteur d'avis des habitants (thème loisirs)")
	var dr: ClubSupporters = scene.club_supporters
	dr.refresh(true)
	_check(dr.drapeaux > 5 and int(dr.par_sport.get("basket", 0)) + int(dr.par_sport.get("handball", 0)) + int(dr.par_sport.get("rugby", 0)) > 0,
		"%d drapeaux de supporters dans les rues (%s)" % [dr.drapeaux, str(dr.par_sport)])
	var nf := ev.prevus("fete").size()
	bk._fete_supporters("montee")
	_check(ev.prevus("fete").size() == nf + 1, "fête des supporters prévue après une montée")
	# Matchs inventés : pas au stade du club de rugby.
	ev.matchs.plan_day({"day": ClubSport.day_of(2027, 9, 4), "month": 9, "mday": 4, "wd": 6})
	var autre := false
	for e in ev.prevus("match"):
		if int(e.bid) == stade and not bool(e.data.get("club", false)):
			autre = true
	_check(not autre, "pas de match inventé au stade du club de rugby")

	# Sauvegarde.
	print("Sauvegarde :")
	var sec: Dictionary = scene.save_sections()
	_check((sec.get("clubs_sports", {}) as Dictionary).size() == 5, "section « clubs_sports » (5 clubs)")
	var back: Dictionary = JSON.parse_string(JSON.stringify(bk.to_dict()))
	var nom := String(bk.club.nom)
	var ne := bk.espoirs.size()
	var nb := bk.joueurs.size()
	var rang := bk.rang()
	bk.clear()
	bk.from_dict(back)
	_check(bk.fonde() and String(bk.club.nom) == nom and bk.espoirs.size() == ne and bk.joueurs.size() == nb and bk.rang() == rang and int(bk.club.academie) == 3,
		"club de basket rechargé (espoirs, centre de formation)")
	_check(bk.onze().size() == 5 and String(bk.club.sport) == "basket", "alignement rechargé")

	# Menu.
	print("Menu :")
	var panel: ClubPanel = scene.club_panel
	panel.set_open(true)
	var vues_ok := true
	for s in ClubSports.ORDRE:
		panel.choisir_sport(s)
		for v in ["club", "effectif", "calendrier", "classement", "transferts", "formation", "supporters", "finances"]:
			panel.show_view(v)
			if panel._body.get_child_count() <= 2:
				vues_ok = false
				print("    vide : ", s, " ", v)
	_check(vues_ok, "8 onglets remplis pour chacun des 6 sports")
	panel.choisir_sport("hockey")
	_check(panel._title.text == "HC Test", "le menu suit le sport choisi")
	panel.set_open(false)
	scene.queue_free()
	await process_frame
