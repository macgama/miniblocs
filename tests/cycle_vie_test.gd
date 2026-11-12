extends SceneTree
## Test du cycle de vie : 1 an = 1 jour, naissances avec parents, couples,
## mariages, décès archivés, héritage, CV, santé selon la ville, suivi d'un
## habitant, sauvegarde.
## Usage : godot --headless --path . --script res://tests/cycle_vie_test.gd

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
	world.set_origin(48.8584, 2.2945)
	for i in 60:
		await process_frame
	var pop: Population = scene.population
	pop.rng.seed = 12345
	amb.set_speed(0)
	amb.unix_time = _at("2026-03-10", 10.0)

	print("Réglage par défaut :")
	_check(Population.LIFE_SPEEDS[Population.DEFAULT_LIFE_SPEED] == 12.0, "par défaut, 1 an de vie = 1 mois de jeu")
	_check(ReglagesPartie.new().vitesse_vie == Population.DEFAULT_LIFE_SPEED, "réglage de partie par défaut : 1 an = 1 mois")

	print("Une ville :")
	bs.unlimited_money = true
	var y := world.cell_height(Vector2i(0, 0))
	transport.build_segment("departementale", Vector3(0, y, -400), Vector3(0, y, 400))
	var school := bs.place("ecole", Vector2i(-30, 0), 1)
	var homes := []
	for i in 8:
		homes.append(bs.place("immeuble", Vector2i(16, -200 + i * 22), 3))
	for i in 8:
		homes.append(bs.place("maison", Vector2i(-12, -200 + i * 16), 1))
	var office := bs.place("bureaux", Vector2i(20, 80), 3)
	var gym := bs.place("gymnase", Vector2i(-24, 130), 1)
	var pool := bs.place("piscine", Vector2i(24, 160), 3)
	_check(school > 0 and office > 0 and gym > 0 and pool > 0 and not homes.has(-1), "école, 16 logements, bureaux, gymnase, piscine")
	pop._sync_buildings()
	pop.life_speed_index = 2
	for i in 72:
		pop.advance(300.0)
	_check(pop.persons.size() > 50, "%d habitants installés" % pop.persons.size())

	print("Arrivée et familles :")
	var all_cv := true
	var linked_kids := 0
	var kids := 0
	var cj_ok := true
	for pid in pop.persons:
		var p: Dictionary = pop.persons[pid]
		all_cv = all_cv and not (p.cv as Array).is_empty() and String(p.cv[0][1]) == "naissance"
		if String(p.r) == "enfant":
			kids += 1
			if (p.pa as Array).has(-1) == false or int(p.pa[0]) >= 0 or int(p.pa[1]) >= 0:
				linked_kids += 1
		if int(p.cj) >= 0:
			cj_ok = cj_ok and pop.persons.has(int(p.cj)) and int(pop.persons[int(p.cj)].cj) == pid
	_check(all_cv, "chaque habitant a un CV qui commence par sa naissance")
	_check(kids > 0 and linked_kids == kids, "%d enfants, tous reliés à leurs parents" % kids)
	_check(cj_ok, "les couples sont réciproques")
	var some_kid := -1
	var some_parent := -1
	for pid in pop.persons:
		var p: Dictionary = pop.persons[pid]
		if String(p.r) == "enfant" and int(p.pa[0]) >= 0:
			some_kid = pid
			some_parent = int(p.pa[0])
			break
	_check(pop.vie.relation(pop.persons[some_kid], pop.persons[some_parent]) == "sa mère", "relation : « sa mère »")
	_check(pop.vie.children_of(some_parent).has(some_kid), "la mère voit son enfant dans sa famille")

	print("Santé selon la ville :")
	var adult := -1
	for pid in pop.persons:
		if pop.age_of(pop.persons[pid]) > 40.0:
			adult = pid
			break
	var f_before := float(pop.vie.health(pop.persons[adult]).f)
	var hosp := bs.place("hopital", Vector2i(30, 250), 3)
	pop._sync_buildings()
	var f_after := float(pop.vie.health(pop.persons[adult]).f)
	_check(hosp > 0 and f_after < f_before, "un hôpital proche réduit le risque (%.2f → %.2f)" % [f_before, f_after])
	var e_before := pop.vie.life_expectancy(pop.persons[adult])
	var plant := bs.place("usine", Vector2i(-30, -262), 1)
	pop._sync_buildings()
	var pol := pop.vie.pollution_at(pop.home_of(pop.persons[adult]))
	_check(plant > 0 and pol > 0.0, "une usine pollue l'air des logements voisins (%d %%)" % roundi(pol * 100.0))
	_check(pop.vie.life_expectancy(pop.persons[adult]) <= e_before, "la pollution n'allonge pas la vie (%.1f → %.1f ans)" % [e_before, pop.vie.life_expectancy(pop.persons[adult])])
	bs.demolish(plant)
	pop._sync_buildings()

	print("Suivre un habitant :")
	var star := -1
	for pid in pop.persons:
		var p: Dictionary = pop.persons[pid]
		if pop.stage(p) == "actif" and int(p.cj) >= 0:
			star = pid
			break
	_check(star >= 0, "un actif en couple à suivre")
	pop.follow(star)
	_check(pop.followed() == star and pop.follow_camera, "suivi : %s %s, caméra active" % [pop.persons[star].p, pop.persons[star].n])
	amb.unix_time = _at("2026-03-10", 11.0)
	pop._now = {}
	var at_work: Vector3 = pop.vie.position_of(star)
	_check(at_work.distance_to(pop.known[int(pop.persons[star].job)].pos) < 1.0, "mardi 11 h : le repère est sur son lieu de travail")
	scene.rig.position = Vector3(500, scene.rig.position.y, 500)
	pop._follow_set = Vector3.INF
	await process_frame
	for i in 60:
		pop._update_follow(0.1)
	var d := Vector2(scene.rig.position.x - at_work.x, scene.rig.position.z - at_work.z).length()
	_check(d < 30.0, "la caméra rejoint l'habitant suivi (%.0f m)" % d)
	_check(pop._follow_marker.visible and pop._follow_label.text.contains(String(pop.persons[star].p)), "repère et nom au-dessus de lui")
	_check(scene.habitants_panel._card.visible, "carte « habitant suivi » affichée")
	pop.follow_camera = true
	pop._follow_set = scene.rig.position
	scene.rig.position.x += 40.0
	await process_frame
	await process_frame
	_check(not pop.follow_camera, "le joueur déplace la caméra : elle devient libre")

	print("Une vie entière (80 jours = 80 ans) :")
	pop.rng.seed = 777
	var first_ids: Array = pop.persons.keys()
	for day in 80:
		amb.unix_time += 86400.0
		pop.advance(86400.0)
		if day % 10 == 9:
			for i in 12:
				pop.advance(300.0)
	var t: Dictionary = pop.vie.totals
	_check(int(t.naissances) > 0, "%d naissances" % int(t.naissances))
	_check(int(t.deces) > 0, "%d décès" % int(t.deces))
	var mean := float(t.age_deces) / maxi(int(t.deces), 1)
	_check(mean > 55.0 and mean < 100.0, "âge moyen au décès : %d ans" % roundi(mean))
	_check(int(t.couples) > 0, "%d couples formés" % int(t.couples))
	_check(int(t.mariages) + int(t.pacs) > 0, "%d mariages et %d PACS" % [int(t.mariages), int(t.pacs)])
	var gone := 0
	for pid in first_ids:
		if not pop.persons.has(pid):
			gone += 1
	_check(gone > first_ids.size() / 2, "au bout de 80 ans, %d habitants du début sur %d sont morts ou partis" % [gone, first_ids.size()])
	var archived := 0
	var causes := true
	for pid in pop.vie.archive:
		var fi: Dictionary = pop.vie.archive[pid]
		archived += 1
		if String(fi.fin) == "deces":
			var good: bool = String(fi.cause) != "" and String(fi.cv[-1][1]) in ["deces", "depart"]
			if not good:
				print("    détail défunt ", fi.p, " ", fi.cause, " ", fi.cv.slice(-3))
			causes = causes and good
	_check(archived > 0 and causes, "%d fiches de défunts et d'anciens habitants, avec la cause" % archived)
	var born_here := 0
	var born_ok := true
	for pid in pop.persons:
		var p: Dictionary = pop.persons[pid]
		if String(p.cv[0][2]).begins_with("Naît à"):
			born_here += 1
			born_ok = born_ok and int(p.pa[0]) >= 0
	_check(born_here > 0 and born_ok, "%d habitants nés en ville, avec leur mère connue" % born_here)
	var codes := {}
	for src in [pop.persons, pop.vie.archive]:
		for pid in src:
			for e in src[pid].cv:
				codes[String(e[1])] = true
	for c in ["naissance", "ecole", "diplome", "emploi", "couple", "enfant", "retraite", "deces", "permis", "loisir"]:
		_check(codes.has(c), "étape « %s » présente dans des CV" % c)
	print("    étapes vues : ", ", ".join(codes.keys()))
	var sorted := true
	for pid in pop.persons:
		var cv: Array = pop.persons[pid].cv
		for i in range(1, cv.size()):
			sorted = sorted and float(cv[i][0]) >= float(cv[i - 1][0])
	_check(sorted, "les CV sont dans l'ordre chronologique")
	var coherent := true
	var orphan_homes := 0
	for hid in pop.households:
		var h: Dictionary = pop.households[hid]
		var adults := 0
		for m in h.m:
			coherent = coherent and pop.persons.has(m) and int(pop.persons[m].f) == hid
			if String(pop.persons[m].r) == "adulte":
				adults += 1
		if adults == 0:
			orphan_homes += 1
			for m in h.m:
				var q: Dictionary = pop.persons[m]
				print("    détail foyer ", hid, " ", q.p, " ", q.r, " ", pop.age_of(q), " ", q.cv.slice(-3))
	for pid in pop.persons:
		var p: Dictionary = pop.persons[pid]
		coherent = coherent and pop.households.has(int(p.f))
		if int(p.cj) >= 0:
			coherent = coherent and pop.persons.has(int(p.cj)) and int(pop.persons[int(p.cj)].cj) == pid
	_check(coherent, "foyers et couples toujours cohérents")
	_check(orphan_homes == 0, "aucun foyer sans adulte (héritage du logement, enfants recueillis)")
	_check(pop.persons.size() > 20, "la ville vit toujours : %d habitants" % pop.persons.size())

	print("Héritage :")
	var heir_case := -1
	for pid in pop.persons:
		var p: Dictionary = pop.persons[pid]
		if String(p.r) == "adulte" and pop.age_of(p) > 50.0 and int(p.cj) < 0:
			var h: Dictionary = pop.households[int(p.f)]
			for m in h.m:
				if m != pid and String(pop.persons[m].r) == "enfant" and pop.age_of(pop.persons[m]) >= 18.0:
					heir_case = pid
	if heir_case < 0:
		# On fabrique le cas : un parent seul avec un enfant majeur.
		for pid in pop.persons:
			var p: Dictionary = pop.persons[pid]
			if String(p.r) == "adulte" and pop.age_of(p) > 45.0:
				var hid := int(p.f)
				for m in pop.households[hid].m.duplicate():
					if m != pid and String(pop.persons[m].r) == "adulte":
						pop._remove_person(m, false, "Test")
				var kid := pop._add_person(hid, "F", 22.0, "enfant", String(p.n))
				pop.persons[kid].pa = [-1, pid]
				p.cj = -1
				heir_case = pid
				break
	var hh := int(pop.persons[heir_case].f)
	var home := int(pop.households[hh].b)
	pop.vie.die(heir_case, "de vieillesse")
	_check(pop.vie.archive.has(heir_case) and String(pop.vie.archive[heir_case].cause) == "de vieillesse", "le défunt garde sa fiche")
	_check(pop.households.has(hh) and int(pop.households[hh].b) == home, "le foyer garde la maison familiale")
	var inherited := false
	for m in pop.households.get(hh, {"m": []}).m:
		for e in pop.persons[m].cv:
			if String(e[1]) == "heritage":
				inherited = true
	_check(inherited, "l'enfant majeur hérite du logement (noté dans son CV)")

	print("Suivi après un décès :")
	var parent := -1
	for pid in pop.persons:
		if not pop.vie.children_of(pid).is_empty() and pop.persons.has(pop.vie.children_of(pid)[0]):
			parent = pid
			break
	if parent >= 0:
		pop.follow(parent)
		pop.vie.die(parent, "de vieillesse")
		_check(pop.followed() >= 0 and pop.followed() != parent, "le suivi passe à un proche (façon Sims)")

	print("Sauvegarde :")
	var someone: int = pop.persons.keys()[0]
	var cv_before: Array = pop.persons[someone].cv.duplicate(true)
	var pa_before: Array = pop.persons[someone].pa.duplicate()
	var arch_before := pop.vie.archive.size()
	var fol := pop.followed()
	var data: Dictionary = JSON.parse_string(JSON.stringify(pop.to_dict()))
	pop.from_dict(data)
	_check(pop.persons.has(someone) and (pop.persons[someone].cv as Array).size() == cv_before.size()
		and String(pop.persons[someone].cv[-1][2]) == String(cv_before[-1][2]), "CV rechargé à l'identique")
	_check(pop.persons[someone].pa == pa_before, "parents rechargés")
	_check(pop.vie.archive.size() == arch_before, "fiches des défunts rechargées (%d)" % arch_before)
	_check(pop.followed() == fol, "habitant suivi rechargé")
	# Ancienne sauvegarde (version 1, sans familles).
	var old := data.duplicate(true)
	old.version = 1
	old.erase("vie")
	for e in old.habitants:
		(e as Array).resize(11)
	pop.from_dict(old)
	var any_link := false
	for pid in pop.persons:
		any_link = any_link or int(pop.persons[pid].cj) >= 0
	_check(any_link and pop.persons[someone].cv.size() >= 1, "ancienne sauvegarde : couples devinés, CV commencé")
	pop.from_dict(data)

	print("Panneau :")
	var panel: HabitantsPanel = scene.habitants_panel
	panel.set_open(true)
	panel.show_view("profil", someone)
	await process_frame
	var has_frise := false
	for c in panel._body.get_children():
		has_frise = has_frise or c is FriseVie
	_check(has_frise, "fiche : frise chronologique de la vie")
	var dead_id: int = pop.vie.archive.keys()[-1]
	panel.show_view("profil", dead_id)
	await process_frame
	_check(panel._title.text.contains(String(pop.vie.archive[dead_id].p)), "fiche d'un défunt consultable")
	panel._filter = "defunts"
	panel.show_view("liste")
	await process_frame
	_check(panel._body.get_child_count() > 1, "liste des défunts et anciens habitants")
	panel._filter = ""
	panel.show_view("ville")
	await process_frame
	panel.set_open(false)

	print("CYCLE DE VIE TEST OK" if ok else "CYCLE DE VIE TEST ÉCHEC")
	quit(0 if ok else 1)
