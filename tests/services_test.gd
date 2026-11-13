extends SceneTree
## Test des services publics : couverture des écoles, hôpitaux et police selon
## le trajet par les routes et les places, élèves trop loin, saturation, santé,
## petits délits, calques, panneau, sauvegarde.
## Usage : godot --headless --path . --script res://tests/services_test.gd

var ok := true


func _initialize() -> void:
	_run.call_deferred()
	# Garde-fou : une erreur de script ne doit pas bloquer le test.
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


func _place(bs: BuildingSystem, id: String, z: int) -> int:
	var d := int(BuildingCatalog.get_type(id).d)
	for dx in [d / 2 + 6, d / 2 + 4, int(BuildingCatalog.get_type(id).w) / 2 + 6]:
		var c := Vector2i(-dx, z)
		var r := bs.best_rotation(id, c)
		var bid := bs.place(id, c, r)
		if bid > 0:
			return bid
		print("    ", id, " : ", bs.check_place(id, c, r).reason)
	return -1


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
	world.view_radius_override = 1200.0
	world.set_origin(48.8584, 2.2945)
	for i in 3000:
		await process_frame
		if i >= 120 and world.missing_chunk_count() == 0 and world._dirty.is_empty() and world._jobs.is_empty():
			break
	var pop: Population = scene.population
	var sp: ServicesPublics = scene.services
	_check(sp != null and scene.services_panel != null and ServicesPublics.instance == sp, "services publics et panneau branchés")
	_check(pop.school_ok.is_valid(), "les inscriptions à l'école passent par la couverture")
	sp.delits_actifs = false
	scene.urgences.random_calls = false
	amb.set_speed(0)
	amb.unix_time = _at("2026-03-10", 10.0)
	bs.unlimited_money = true
	var y := world.cell_height(Vector2i(0, 0))

	print("Deux quartiers, un seul relié aux services :")
	_check(transport.build_segment("departementale", Vector3(0, y, -300), Vector3(0, y, 300)).ok, "route du centre")
	_check(transport.build_segment("route", Vector3(800, y, -300), Vector3(800, y, 300)).ok, "route du hameau, à 800 m, sans liaison")
	var school := bs.place("ecole", Vector2i(-30, 0), 1)
	var hosp := _place(bs, "hopital", -150)
	var cop := _place(bs, "police", 150)
	var centre := []
	for i in 8:
		centre.append(bs.place("immeuble", Vector2i(16, -200 + i * 22), 3))
	var office := bs.place("bureaux", Vector2i(20, 200), 3)
	var hameau := []
	for i in 6:
		hameau.append(bs.place("maison", Vector2i(812, -100 + i * 16), 3))
	_check(school > 0 and hosp > 0 and cop > 0 and office > 0 and not centre.has(-1) and not hameau.has(-1), "école, hôpital, commissariat, 8 immeubles, bureaux, 6 maisons")
	print("    ids : école %d, hôpital %d, police %d, bureaux %d, centre %s, hameau %s" % [school, hosp, cop, office, centre, hameau])
	if hosp < 0:
		print("    hôpital : ", bs.check_place("hopital", Vector2i(-36, -150), 1).reason)
	if cop < 0:
		print("    police : ", bs.check_place("police", Vector2i(-24, 150), 1).reason)
	pop._sync_buildings()
	for i in 96:
		pop.advance(300.0)
	_check(pop.persons.size() > 50, "%d habitants" % pop.persons.size())
	sp.rebuild()

	var a_c := sp.minutes(centre[0], school, "ecole")
	_check(a_c < 15.0, "centre → école : %.1f min" % a_c)
	var a_h := sp.minutes(hameau[0], school, "ecole")
	_check(a_h == INF, "hameau → école : non relié par la route")
	var kids_hameau := 0
	var sans := 0
	for h in hameau:
		for hid in pop.by_home.get(h, []):
			for pid in pop.households[hid].m:
				var p: Dictionary = pop.persons[pid]
				if pop.stage(p) == "eleve":
					kids_hameau += 1
					if int(p.sch) < 0:
						sans += 1
	_check(kids_hameau > 0 and sans == kids_hameau, "élèves du hameau sans école (%d sur %d), même s'il reste des places" % [sans, kids_hameau])
	_check(pop.free_seats(school) > 0, "il reste %d places à l'école" % pop.free_seats(school))
	var why: Array = pop.satisfaction(pop.persons[pop.households[pop.by_home[hameau[0]][0]].m[0]]).why
	_check(why.size() > 0, "satisfaction calculée au hameau")
	for s in ServicesPublics.TYPES:
		_check(sp.couverture_bid(hameau[0], s) == 0.0, "%s : hameau non couvert" % s)
	_check(sp.couverture_bid(centre[0], "ecole") > 0.9, "école : centre couvert (%.2f)" % sp.couverture_bid(centre[0], "ecole"))
	var hq := sp.couverture_bid(centre[0], "hopital")
	var cap_h := sp.capacite(hosp, "hopital")
	print("    hôpital : %d lits, couverture %.2f, fermé %s" % [cap_h, hq, sp._ferme(hosp)])
	_check(sp._ferme(hosp) or hq > 0.5, "hôpital : centre couvert s'il a son personnel")
	var bp := sp.bilan("police")
	_check(int(bp.hab) == pop.persons.size(), "bilan police : %d habitants comptés" % int(bp.hab))
	_check(int(bp.rien) >= kids_hameau, "bilan police : %d sans service" % int(bp.rien))
	_check(ServicesPublics.couverture(Vector3(0, y, 0), "ecole") > 0.4, "couverture en un point du centre (valeur foncière)")
	_check(ServicesPublics.couverture(Vector3(800, y, 0), "ecole") == 0.0, "couverture en un point du hameau : 0")

	print("Santé :")
	var p_c: Dictionary = pop.persons[pop.households[pop.by_home[centre[0]][0]].m[0]]
	var p_h: Dictionary = pop.persons[pop.households[pop.by_home[hameau[0]][0]].m[0]]
	var hc: Dictionary = pop.vie.health(p_c)
	var hh: Dictionary = pop.vie.health(p_h)
	print("    centre : ", hc.why[0], " · hameau : ", hh.why[0])
	_check(String(hh.why[0]).begins_with("−") and String(hh.why[0]).contains("hôpital"), "hameau : pas d'hôpital accessible")
	_check(float(hc.f) <= float(hh.f) or sp._ferme(hosp), "risque plus faible au centre (%.2f contre %.2f)" % [float(hc.f), float(hh.f)])

	print("Petits délits :")
	var n0 := int(scene.urgences.incidents.size())
	var bid := sp.delit()
	_check(hameau.has(bid), "un délit a lieu dans le quartier sans police")
	_check(int(sp.delits.total) == 1, "délit compté")
	_check(scene.urgences.incidents.size() > n0 or int(sp.delits.sans_police) == 1, "cambriolage signalé aux urgences")

	print("Calques et panneau :")
	var ids := []
	for c in Calques.liste():
		ids.append(String(c.id))
	_check(ids.has("services_ecole") and ids.has("services_hopital") and ids.has("services_police"), "trois calques dans le groupe Services")
	Calques.afficher("services_ecole")
	_check(sp.calque() == "ecole" and sp._layer.visible and sp._layer.mesh != null, "calque École affiché")
	Calques.afficher("services_police")
	_check(sp.calque() == "police", "calque Police à la place")
	Calques.eteindre()
	_check(sp.calque() == "" and not sp._layer.visible, "calque éteint")
	var panel: ServicesPanel = scene.services_panel
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.physical_keycode = KEY_U
	ev.shift_pressed = true
	panel._unhandled_key_input(ev)
	_check(panel.is_open(), "Maj+U ouvre le panneau")
	for s in ServicesPublics.TYPES:
		panel.show_view(s)
		_check(panel._body.get_child_count() > 4, "onglet %s rempli" % s)
	panel.set_open(false)

	print("On relie le hameau :")
	_check(transport.build_segment("route", Vector3(0, y, 300), Vector3(800, y, 300)).ok, "route de liaison de 800 m")
	await process_frame
	pop._match_all()
	var t2 := sp.minutes(hameau[0], school, "ecole")
	_check(t2 < 30.0, "hameau → école : %.1f min (car ou à pied)" % t2)
	var with_school := 0
	for h in hameau:
		for hid in pop.by_home.get(h, []):
			for pid in pop.households[hid].m:
				var p: Dictionary = pop.persons[pid]
				if pop.stage(p) == "eleve" and int(p.sch) >= 0:
					with_school += 1
	_check(with_school == kids_hameau, "les élèves du hameau ont une école (%d)" % with_school)
	sp.rebuild()
	_check(sp.couverture_bid(hameau[0], "police") > 0.0, "police : le hameau est couvert (%.2f)" % sp.couverture_bid(hameau[0], "police"))

	print("Saturation :")
	# Un hôpital de 2 lits, 1 lit pour 100 habitants : il ne suffit plus pour toute la ville.
	pop.known[hosp].lits = 2
	sp.lits_par_hab = 0.01
	sp.marquer()
	sp.rebuild()
	var dh := sp.detail(centre[0], "hopital")
	if not sp._ferme(hosp):
		_check(float(dh.charge) > 1.0 and float(dh.q) < 0.5, "hôpital saturé : charge %d %%, couverture %.2f" % [roundi(float(dh.charge) * 100.0), float(dh.q)])
		_check(int(sp.bilan("hopital").sature) > 0, "bilan : habitants avec un hôpital saturé")
	else:
		print("    (hôpital fermé faute de médecin : test de saturation sauté)")

	print("Sauvegarde :")
	var sec: Dictionary = scene.save_sections()
	_check(sec.has("services") and int(sec.services.delits.total) == 1, "section « services » dans la sauvegarde")
	sp.from_dict({"v": 1, "delits": {"total": 7, "sans_police": 2, "mois": 3, "mois_debut": 0}})
	_check(int(sp.delits.total) == 7, "bilan des délits rechargé")

	print("TEST OK" if ok else "TEST ÉCHEC")
	quit(0 if ok else 1)
