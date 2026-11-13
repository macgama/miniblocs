extends SceneTree
## Test des fondateurs du village : arrivée avec la Maison de commune (100 par
## défaut, réglage Admin), campement, ouvriers répartis entre les chantiers
## (équipes, attente, pause, « En premier »), chantiers qui avancent selon
## l'équipe, fondateurs affectés à n'importe quel métier puis rappelés, maisons
## finies où ils emménagent, vivres puis ravitaillement, campement protégé,
## budget sous la tente, sauvegarde, panneau Maj+H, réglages Admin.
## Usage : godot --headless --path . --script res://tests/fondateurs_test.gd

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


func _lundi(offset: float) -> float:
	# 2 mars 2026 était un lundi.
	return float(Time.get_unix_time_from_datetime_string("2026-03-02T07:30:00")) - offset * 3600.0


func _run() -> void:
	Creations.persist = false
	BatimentsVie.chantiers = true
	GameStart.chosen = true
	GameStart.place_name = "Valfleuri, Savoie"
	ReglagesPartie.prochaine = ReglagesPartie.preset("normal")
	print("Règles :")
	_check(ReglagesPartie.prochaine.fondateurs == 100 and ReglagesPartie.prochaine.vivres_jours == 90 and ReglagesPartie.prochaine.main_oeuvre,
		"par défaut : 100 fondateurs, 90 jours de vivres, chantiers avec ouvriers")
	_check(not ReglagesPartie.preset("libre").main_oeuvre, "bac à sable libre : chantiers sans ouvriers")
	var e_maison := Chantiers.equipe_batiment("colombages__maison")
	var e_mc := Chantiers.equipe_batiment("maison_commune")
	_check(e_maison >= 5 and e_maison <= 14, "équipe d'une maison : %d ouvriers" % e_maison)
	_check(e_mc >= 6 and e_mc <= 16, "équipe de la Maison de commune : %d ouvriers" % e_mc)
	_check(Chantiers.equipe_batiment("usine") > e_maison, "une usine demande plus d'ouvriers (%d)" % Chantiers.equipe_batiment("usine"))
	_check(Chantiers.equipe_travaux(80.0) >= 3 and Chantiers.equipe_travaux(80.0) <= 6, "100 m de route : %d ouvriers" % Chantiers.equipe_travaux(80.0))
	_check(Metiers.METIERS.has("ouvrier_btp") and Metiers.jobs_for("entreprise_btp")[0][0] == "ouvrier_btp", "métier « ouvrier du bâtiment » et entreprise du bâtiment")
	_check(BuildingCatalog.get_type("campement").get("cache", false) and not BatimentsVie.aura_chantier("campement"), "campement : hors catalogue, sans chantier")

	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
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
	var fd: Fondateurs = scene.fondateurs
	var pop: Population = scene.population
	var vie: BatimentsVie = scene.vie_batiments
	var amb: DayNight = scene.ambiance
	_check(fd != null and Fondateurs.instance == fd and scene.fondateurs_panel != null, "fondateurs et panneau branchés")
	amb.set_speed(0)
	var off := amb.utc_offset()
	amb.unix_time = _lundi(off)
	vie._t_prev = amb.unix_time
	scene.chantiers._t_prev = amb.unix_time
	pop.arrivals = false
	bs.require_access = false

	print("Arrivée avec la Maison de commune :")
	_check(not fd.arrives and pop.persons.is_empty(), "avant la fondation : personne")
	bs.unlimited_money = true
	cm.nom_en_attente = "Valfleuri"
	var mc := bs.place("maison_commune", Vector2i(-1000, 0), 0)
	_check(mc > 0 and bs.en_chantier(mc), "Maison de commune posée, en chantier")
	await process_frame
	await process_frame
	_check(fd.arrives, "les fondateurs sont arrivés")
	_check(fd.camp >= 0 and bs.buildings.has(fd.camp) and String(bs.buildings[fd.camp].t) == "campement", "campement planté")
	_check(not bs.en_chantier(fd.camp), "le campement est monté tout de suite (pas de chantier)")
	var cr := bs._rect_of(bs.buildings[fd.camp])
	var mr := bs._rect_of(bs.buildings[mc])
	_check(BuildingSystem.rect_center(cr).distance_to(BuildingSystem.rect_center(mr)) < 160.0, "à côté de la Maison de commune")
	_check(pop.persons.size() == 100 and fd.vivants().size() == 100, "100 fondateurs")
	var adultes := true
	var au_chantier := 0
	for pid in pop.persons:
		var p: Dictionary = pop.persons[pid]
		if pop.age_of(p) < 18.0 or pop.age_of(p) > 60.0:
			adultes = false
		if int(p.job) == fd.camp and String(p.met) == "ouvrier_btp":
			au_chantier += 1
	_check(adultes, "tous en âge de travailler")
	_check(au_chantier == 100, "tous ouvriers du bâtiment à la base de chantier")
	_check(fd.au_campement() == 100, "tous dorment sous la tente")
	_check(int(pop.known[fd.camp].log) == (pop.by_home[fd.camp] as Array).size() and int(pop.known[fd.camp].emp) == 100,
		"places du campement : %d tentes, 100 postes" % int(pop.known[fd.camp].log))
	_check(pop.free_homes(fd.camp) == 0, "pas de tente libre pour les nouveaux arrivants")
	cm.calculer_stats()
	_check(int(cm.stats[cm.principal()].hab) == 0, "sous la tente, ils ne comptent pas encore comme habitants du village")
	var hid0: int = pop.by_home[fd.camp][0]
	var bud := pop.household_budget(hid0)
	_check(float(bud.loyer) == 0.0 and float(bud.courses) == 0.0, "sous la tente : ni loyer ni courses")
	_check(Fondateurs.nourris(fd.camp), "le campement est nourri par les vivres")
	_check(is_equal_approx(fd.vivres, 100.0 * 90.0), "vivres : 90 jours pour 100 fondateurs")

	print("Les chantiers se partagent les ouvriers :")
	fd.repartir()
	_check(fd.total_ouvriers == 100, "100 ouvriers disponibles")
	var eq_mc := fd.equipe_de(Fondateurs.cle_batiment(mc))
	_check(int(eq_mc[0]) == int(eq_mc[1]) and is_equal_approx(fd.facteur(Fondateurs.cle_batiment(mc)), 1.0), "Maison de commune : équipe complète (%d)" % int(eq_mc[0]))
	var maisons := []
	var x := -1000 + 60
	while maisons.size() < 14 and x < -500:
		for z in [-60, 60]:
			var c := Vector2i(x, z)
			if bs.check_place("colombages__maison", c, 0).ok:
				var b := bs.place("colombages__maison", c, 0)
				if b > 0:
					maisons.append(b)
		x += 22
	_check(maisons.size() >= 12, "%d maisons en chantier" % maisons.size())
	fd.repartir()
	var somme := 0
	for k in fd.repartition:
		somme += int(fd.repartition[k])
	var besoin := 0
	for k in fd.besoins:
		besoin += int(fd.besoins[k])
	_check(besoin > 100 and somme == 100 and fd.libres == 0, "trop de chantiers : les 100 ouvriers sont tous pris (%d demandés)" % besoin)
	var premiere: int = maisons[0]
	var derniere: int = maisons[maisons.size() - 1]
	_check(is_equal_approx(fd.facteur(Fondateurs.cle_batiment(premiere)), 1.0), "la première maison a son équipe")
	_check(fd.facteur(Fondateurs.cle_batiment(derniere)) == 0.0, "la dernière attend des ouvriers")
	# Une journée de travail : la première avance, la dernière non.
	amb.unix_time = _lundi(off) + 8.5 * 3600.0
	vie._update_chantiers()
	_check(vie.progress(premiere) > 0.0, "la première maison avance (%.1f %%)" % (vie.progress(premiere) * 100.0))
	_check(vie.progress(derniere) == 0.0 and bool(bs.buildings[derniere].get("sans_ouvriers", false)), "la dernière n'a pas bougé : en attente d'ouvriers")
	_check(String((bs.node_of(derniere).get_node("PanneauChantier") as Label3D).text).contains("ouvriers"), "le panneau du chantier le dit")

	print("Doser : pause et « En premier » :")
	fd.basculer_pause(Fondateurs.cle_batiment(premiere))
	_check(fd.facteur(Fondateurs.cle_batiment(premiere)) == 0.0 and bs.buildings[premiere].get("pause", false), "première maison en pause")
	fd.prioriser(Fondateurs.cle_batiment(derniere))
	_check(is_equal_approx(fd.facteur(Fondateurs.cle_batiment(derniere)), 1.0), "la dernière passe en premier : équipe complète")
	var av_p := vie.progress(premiere)
	amb.unix_time = _lundi(off) + 86400.0 + 2.0 * 3600.0 # mardi 9 h 30
	vie._update_chantiers()
	_check(is_equal_approx(vie.progress(premiere), av_p), "la maison en pause ne bouge pas")
	_check(vie.progress(derniere) > 0.0, "la maison passée en premier avance")
	fd.basculer_pause(Fondateurs.cle_batiment(premiere))
	_check(not bs.buildings[premiere].get("pause", false), "reprise")
	# Équipe incomplète : le chantier avance moins vite.
	var partiel := ""
	for k in fd.repartition:
		if int(fd.repartition[k]) > 0 and int(fd.repartition[k]) < int(fd.besoins[k]):
			partiel = String(k)
	_check(partiel == "" or (fd.facteur(partiel) > 0.0 and fd.facteur(partiel) < 1.0), "équipe incomplète : %s" % ("aucune" if partiel == "" else "%.0f %%" % (fd.facteur(partiel) * 100.0)))
	# Règle coupée dans l'Admin : tout le monde a son équipe.
	ReglagesPartie.actuel.main_oeuvre = false
	_check(is_equal_approx(fd.facteur(Fondateurs.cle_batiment(maisons[5])), 1.0), "Admin : chantiers sans ouvriers")
	ReglagesPartie.actuel.main_oeuvre = true

	print("Des maisons finies : les fondateurs emménagent :")
	vie.finish_all()
	await process_frame
	pop._sync_buildings()
	fd.reloger()
	var dans_maisons := 0
	for b in maisons:
		dans_maisons += (pop.by_home.get(b, []) as Array).size()
	_check(dans_maisons > 0, "%d foyers de fondateurs dans les maisons" % dans_maisons)
	_check(fd.au_campement() < 100 and (pop.by_home.get(fd.camp, []) as Array).size() == fd.foyers_depart - dans_maisons, "le campement se vide (%d encore sous la tente)" % fd.au_campement())
	_check(int(pop.known[fd.camp].log) == (pop.by_home.get(fd.camp, []) as Array).size(), "moins de tentes au campement")
	_check(int(bs.buildings[fd.camp].get("v", 0)) > 0, "le campement a perdu des tentes (variante %d)" % int(bs.buildings[fd.camp].get("v", 0)))
	cm.calculer_stats()
	_check(int(cm.stats[cm.principal()].hab) == pop.persons.size() - fd.au_campement(), "logés, ils comptent comme habitants (%d)" % int(cm.stats[cm.principal()].hab))

	print("N'importe quel métier :")
	var ferme := -1
	for c in [Vector2i(-1000, 160), Vector2i(-900, 160), Vector2i(-1100, 160)]:
		if ferme < 0 and bs.check_place("ferme", c, 0).ok:
			ferme = bs.place("ferme", c, 0)
	_check(ferme > 0, "ferme posée")
	vie.finish_all()
	pop._sync_buildings()
	_check(fd.postes_libres().has(ferme), "la ferme a des postes libres")
	var n0 := fd.au_chantier().size()
	var k := fd.affecter(ferme, 2, "agriculteur")
	_check(k == 2, "2 fondateurs envoyés à la ferme")
	var agri := 0
	for pid in pop.by_job.get(ferme, []):
		if String(pop.persons[pid].met) == "agriculteur" and fd.membres.has(pid):
			agri += 1
	_check(agri == 2, "ils y sont agriculteurs")
	_check(fd.au_chantier().size() == n0 - 2 and int(pop.known[fd.camp].emp) == n0 - 2, "2 ouvriers de moins au chantier")
	fd.repartir()
	_check(fd.total_ouvriers == n0 - 2, "moins d'ouvriers pour les chantiers")
	_check(fd.rappeler(ferme, 1) == 1 and fd.au_chantier().size() == n0 - 1, "un fondateur rappelé au chantier")
	_check(String(pop.persons[fd.au_chantier()[fd.au_chantier().size() - 1]].met) == "ouvrier_btp", "redevenu ouvrier du bâtiment")

	print("Vivres puis ravitaillement :")
	var n_tente := fd.au_campement()
	if n_tente > 0:
		fd.vivres = n_tente * 3.0
		fd.nouveau_jour()
		_check(is_equal_approx(fd.vivres, n_tente * 2.0), "un jour : %d rations mangées" % n_tente)
		bs.unlimited_money = false
		bs.money = 1_000_000
		fd.vivres = 0.0
		fd.nouveau_jour()
		_check(bs.money == 1_000_000 - roundi(n_tente * Fondateurs.RATION) and fd.ravitaillement > 0, "vivres épuisés : ravitaillement payé (%s)" % BuildingSystem.format_money(1_000_000 - bs.money))
		bs.money = 0
		fd.nouveau_jour()
		_check(fd.affame and not Fondateurs.nourris(fd.camp), "caisse vide : le campement a faim")
		bs.money = 1_000_000
		fd.nouveau_jour()
		_check(not fd.affame, "ravitaillement repris")
		bs.unlimited_money = true
		var nb := bs.buildings.size()
		bs.demolish(fd.camp)
		_check(bs.buildings.size() == nb and bs.buildings.has(fd.camp), "on ne démonte pas le campement habité")

	print("Sauvegarde :")
	var sec: Dictionary = scene.save_sections()
	_check(sec.has("fondateurs") and bool(sec.fondateurs.arrives), "section « fondateurs »")
	var bsec: Array = sec.batiments.buildings
	var camp_e := {}
	for e in bsec:
		if int(e.id) == fd.camp:
			camp_e = e
	_check(camp_e.has("nlog") and camp_e.has("nemp"), "les places du campement sont sauvegardées")
	var camp := fd.camp
	var nm := fd.membres.size()
	var viv := fd.vivres
	fd.clear()
	_check(not fd.arrives and fd.camp < 0, "vidé")
	fd.from_dict(JSON.parse_string(JSON.stringify(sec.fondateurs)))
	_check(fd.arrives and fd.camp == camp and fd.membres.size() == nm and is_equal_approx(fd.vivres, viv), "rechargé : campement, %d fondateurs, vivres" % nm)
	var r2 := ReglagesPartie.new()
	var d := ReglagesPartie.actuel.to_dict()
	d.fondateurs = 250
	d.vivres_jours = 30
	d.main_oeuvre = false
	r2.from_dict(d)
	_check(r2.fondateurs == 250 and r2.vivres_jours == 30 and not r2.main_oeuvre, "réglages Admin sauvegardés")

	print("Panneau Maj+H :")
	var panel: FondateursPanel = scene.fondateurs_panel
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.physical_keycode = KEY_H
	ev.shift_pressed = true
	panel._unhandled_key_input(ev)
	_check(panel.is_open(), "Maj+H ouvre le panneau")
	_check(panel._body.get_child_count() > 8, "panneau rempli (%d lignes)" % panel._body.get_child_count())
	_check(not scene.habitants_panel.is_open(), "Maj+H n'ouvre pas le panneau Habitants")
	var cat_ok := false
	for c in TerreHud.CATEGORIES:
		if String(c.id) == "fondateurs" and String(c.get("group", "")) == "ville":
			cat_ok = true
	_check(cat_ok, "bouton Fondateurs dans le menu Ville")
	panel.set_open(false)

	print("Ancienne partie, bac à sable :")
	fd.clear()
	_check(is_equal_approx(fd.facteur("voie:1"), 1.0), "sans fondateurs arrivés, les chantiers ont toujours leur équipe")
	GameStart.chosen = false

	print("TEST OK" if ok else "TEST ÉCHEC")
	quit(0 if ok else 1)
