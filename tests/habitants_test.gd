extends SceneTree
## Test des habitants : foyers, écoles, emplois, emploi du temps, économie, sauvegarde.
## Usage : godot --headless --path . --script res://tests/habitants_test.gd

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


## Heure locale de Paris (UTC+1 en mars) → instant Unix.
func _at(date: String, hour: float) -> float:
	return Time.get_unix_time_from_datetime_string(date + "T00:00:00") + (hour - 1.0) * 3600.0


func _run() -> void:
	Creations.persist = false
	# Bâtiments prêts tout de suite (les chantiers sont testés dans batiments_test).
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
	_check(pop != null and pop.buildings == bs, "système des habitants branché dans la scène")
	amb.set_speed(0)
	amb.unix_time = _at("2026-03-10", 10.0) # un mardi
	_check(int(pop.now().wd) == 2 and absf(float(pop.now().h) - 10.0) < 0.01, "horloge : mardi 10 h")

	print("Construction d'un quartier :")
	bs.unlimited_money = true
	var y := world.cell_height(Vector2i(0, 0))
	_check(transport.build_segment("route", Vector3(0, y, -300), Vector3(0, y, 300)).ok, "route")
	var tr := transport.traffic
	_check(tr.demand.is_valid(), "la circulation est pilotée par les habitants")
	amb.unix_time = _at("2026-03-10", 8.0)
	for i in 120:
		await process_frame
	_check(tr.count_mode(TransportTypes.Mode.ROAD) == 0 and tr.walker_count() == 0, "route sans bâtiment : ni voiture ni piéton (8 h du matin)")
	amb.unix_time = _at("2026-03-10", 10.0)
	var school := bs.place("ecole", Vector2i(-30, 0), 1)
	var homes := []
	for i in 6:
		homes.append(bs.place("immeuble", Vector2i(16, -150 + i * 22), 3))
	for i in 4:
		homes.append(bs.place("maison", Vector2i(-12, -150 + i * 16), 1))
	var office := bs.place("bureaux", Vector2i(20, 80), 3)
	var cafe := bs.place("cafe", Vector2i(-14, 60), 1)
	var park := bs.place("parc", Vector2i(-24, 110), 1)
	_check(school > 0 and office > 0 and cafe > 0 and park > 0 and not homes.has(-1), "école, 6 immeubles, 4 maisons, bureaux, café, parc")
	pop._sync_buildings()
	_check(pop.known.size() == bs.buildings.size(), "bâtiments connus des habitants : %d" % pop.known.size())
	_check(pop.known[school].seats == 300, "l'école a 300 places")

	# Le temps passe (de jour, le mardi) : les foyers emménagent.
	for i in 72:
		pop.advance(300.0)
	var n_log := 0
	for b in homes:
		n_log += int(pop.known[b].log)
	_check(pop.households.size() == n_log, "%d foyers installés dans %d logements" % [pop.households.size(), n_log])
	_check(pop.persons.size() >= n_log, "%d habitants" % pop.persons.size())

	print("École :")
	var pupils: Array = pop.by_school.get(school, [])
	var kids_linked := 0
	var ages_ok := true
	for pid in pop.persons:
		var p: Dictionary = pop.persons[pid]
		if int(p.sch) == school:
			kids_linked += 1
			ages_ok = ages_ok and pop.age_of(p) >= 3.0 and pop.age_of(p) < 18.0
	_check(pupils.size() > 0 and kids_linked == pupils.size(), "%d élèves inscrits = %d profils liés à l'école" % [pupils.size(), kids_linked])
	_check(ages_ok, "tous les élèves ont de 3 à 17 ans")
	var all_schoolkids := true
	for pid in pop.persons:
		var p: Dictionary = pop.persons[pid]
		if pop.stage(p) == "eleve" and int(p.sch) < 0:
			all_schoolkids = false
	_check(all_schoolkids, "chaque enfant de 3 à 17 ans a une école (places suffisantes)")
	pop._now = {}
	var in_class := 0
	for pid in pupils:
		var a := pop.activity(pop.persons[pid])
		if a.kind == "ecole" and int(a.bid) == school:
			in_class += 1
	_check(in_class == pupils.size(), "mardi 10 h : les %d élèves sont en classe" % in_class)
	var here := pop.present_in(school)
	var staff_school: Array = pop.by_job.get(school, [])
	_check(here.size() >= pupils.size(), "présents dans l'école : %d (élèves + personnel)" % here.size())
	var teachers := 0
	for pid in staff_school:
		if pop.persons[pid].met == "enseignant":
			teachers += 1
	_check(staff_school.size() > 0 and teachers > 0, "personnel de l'école : %d dont %d enseignants" % [staff_school.size(), teachers])

	amb.unix_time = _at("2026-03-11", 14.0) # mercredi après-midi
	pop._now = {}
	var wed := 0
	for pid in pupils:
		if pop.activity(pop.persons[pid]).kind == "ecole":
			wed += 1
	_check(wed == 0, "mercredi 14 h : pas d'école")
	amb.unix_time = _at("2026-03-14", 10.0) # samedi
	pop._now = {}
	var sat := 0
	for pid in pupils:
		if pop.activity(pop.persons[pid]).kind == "ecole":
			sat += 1
	_check(sat == 0, "samedi : pas d'école")
	amb.unix_time = _at("2026-03-10", 3.0)
	pop._now = {}
	var sleeping := 0
	for pid in pop.persons:
		var a := pop.activity(pop.persons[pid])
		if a.kind == "dort" or a.kind == "travail":
			sleeping += 1
	_check(sleeping == pop.persons.size(), "3 h du matin : tout le monde dort (ou travaille de nuit)")
	amb.unix_time = _at("2026-03-10", 10.0)
	pop._now = {}

	print("Circulation :")
	amb.unix_time = _at("2026-03-10", 8.2)
	pop._demand_ms = -100000
	var rush: Dictionary = pop.traffic_demand()
	_check(int(rush[TransportTypes.Mode.ROAD]) > 0 and int(rush.walkers) > 0, "8 h 12 : %d voitures et %d piétons dehors d'après les habitants" % [rush[TransportTypes.Mode.ROAD], rush.walkers])
	for i in 200:
		await process_frame
	_check(tr.count_mode(TransportTypes.Mode.ROAD) > 0, "les premiers véhicules arrivent avec les habitants (%d)" % tr.count_mode(TransportTypes.Mode.ROAD))
	amb.unix_time = _at("2026-03-10", 3.0)
	pop._demand_ms = -100000
	var night: Dictionary = pop.traffic_demand()
	_check(int(night[TransportTypes.Mode.ROAD]) < int(rush[TransportTypes.Mode.ROAD]) and int(night.walkers) == 0, "3 h du matin : rues presque vides (%d voitures)" % night[TransportTypes.Mode.ROAD])
	var bus_ambient := false
	for v in tr.vehicles:
		if not v.has("line") and String(v.model) != "" and VehicleCatalog.get_type(v.model).cat == "bus":
			bus_ambient = true
	_check(not bus_ambient, "pas de bus sans ligne")
	amb.unix_time = _at("2026-03-10", 10.0)
	pop._now = {}

	print("Emplois :")
	var workers_ok := true
	var n_workers := 0
	for bid in pop.by_job:
		_check((pop.by_job[bid] as Array).size() <= int(pop.known[bid].emp), "%s : %d postes pourvus sur %d" % [pop.building_name(bid), (pop.by_job[bid] as Array).size(), pop.known[bid].emp])
		for pid in pop.by_job[bid]:
			var p: Dictionary = pop.persons[pid]
			n_workers += 1
			workers_ok = workers_ok and int(p.job) == bid and pop.age_of(p) >= 18.0 and pop.age_of(p) < 64.0 and Metiers.METIERS.has(String(p.met))
	_check(n_workers > 0 and workers_ok, "%d actifs, tous adultes de moins de 64 ans, avec un métier" % n_workers)
	var at_work := 0
	for pid in pop.by_job.get(office, []):
		if pop.activity(pop.persons[pid]).kind == "travail":
			at_work += 1
	_check(at_work > 0, "mardi 10 h : %d employés au bureau" % at_work)
	var some := pop.persons[pupils[0]] as Dictionary
	var plan := pop.day_plan(some)
	var cont := true
	for i in range(1, plan.size()):
		cont = cont and absf(float(plan[i][0]) - float(plan[i - 1][1])) < 0.001
	_check(cont and float(plan[0][0]) == 0.0 and float(plan[-1][1]) == 24.0, "journée d'un élève de 0 h à 24 h sans trou (%d étapes)" % plan.size())
	_check(int(pop.satisfaction(some).value) > 0, "satisfaction calculée")

	print("Économie :")
	var bud := pop.city_budget()
	_check(float(bud.total_recettes) > 0.0 and float(bud.total_depenses) > 0.0, "budget : recettes %s, dépenses %s par mois" % [
		BuildingSystem.format_money(roundi(bud.total_recettes)), BuildingSystem.format_money(roundi(bud.total_depenses))])
	bs.unlimited_money = false
	var m0 := bs.money
	pop._pay_day()
	_check(bs.money != m0, "un jour payé : caisse %+d €" % (bs.money - m0))
	var hb := pop.household_budget(pop.households.keys()[0])
	_check(hb.has("solde") and float(hb.loyer) > 0.0, "budget d'un foyer")
	bs.unlimited_money = true

	print("Sauvegarde :")
	var data: Dictionary = JSON.parse_string(JSON.stringify(pop.to_dict()))
	var names := {}
	for pid in pop.persons:
		names[pid] = "%s %s" % [pop.persons[pid].p, pop.persons[pid].n]
	var n_before := pop.persons.size()
	var pupils_before := pupils.size()
	pop.from_dict(data)
	var same := pop.persons.size() == n_before
	for pid in names:
		same = same and pop.persons.has(pid) and "%s %s" % [pop.persons[pid].p, pop.persons[pid].n] == names[pid]
	_check(same, "habitants rechargés à l'identique (%d)" % pop.persons.size())
	_check((pop.by_school.get(school, []) as Array).size() == pupils_before, "inscriptions à l'école rechargées")
	var sections: Dictionary = scene.save_sections()
	_check(sections.has("habitants"), "section « habitants » dans la sauvegarde")

	print("Panneau :")
	var panel: HabitantsPanel = scene.habitants_panel
	panel.set_open(true)
	pop.select_building(school)
	await process_frame
	_check(panel.view == "batiment" and panel.view_arg == school, "clic sur l'école : le panneau montre l'école")
	var links := 0
	for c in panel._body.get_children():
		if c is Button and (c as Button).flat:
			links += 1
	_check(links >= pupils_before, "%d noms cliquables (élèves et personnel)" % links)
	panel.show_view("profil", pupils[0])
	await process_frame
	_check(panel._title.text == names[pupils[0]], "profil de %s" % names[pupils[0]])
	panel.show_view("ville")
	panel.show_view("liste")
	await process_frame
	_check(panel._body.get_child_count() > 1, "liste des habitants")
	panel.set_open(false)

	print("Transports publics :")
	var road_ok := true
	var rig: Node3D = scene.get_node("CameraRig")
	for k in 8:
		rig.position = Vector3(0, y, 550 + k * 500)
		for w in 400:
			if not is_nan(world.cell_height(Vector2i(0, 800 + k * 500))) and not is_nan(world.cell_height(Vector2i(0, 300 + k * 500))):
				break
			await process_frame
		var seg := transport.build_segment("route", Vector3(0, y, 300 + k * 500), Vector3(0, y, 800 + k * 500))
		if not seg.ok:
			road_ok = false
			print("    route : ", seg.get("reason", ""))
	for i in 30:
		await process_frame
	_check(road_ok, "route de 4 km vers une zone d'activités")
	var far := bs.place("usine", Vector2i(-30, 4050), 1)
	if far < 0:
		print("    usine : ", bs.check_place("usine", Vector2i(-30, 4050), 1).reason)
	pop._sync_buildings()
	var stop_a: Dictionary = transport.stations.place("arret_bus", Vector3(-6, 0, -100))
	var stop_b: Dictionary = transport.stations.place("arret_bus", Vector3(-6, 0, 4030))
	var line: Dictionary = transport.stations.create_line([stop_a.get("id", -1), stop_b.get("id", -1)], "", 3) if stop_a.ok and stop_b.ok else {"ok": false}
	_check(far > 0 and line.ok, "usine à 4 km et ligne de bus jusqu'à elle")
	var rider := {}
	for pid in pop.persons:
		var p: Dictionary = pop.persons[pid]
		if pop.stage(p) == "chomeur" or (pop.stage(p) == "actif" and int(pop.households[int(p.f)].car) == 0):
			rider = p
			break
	if rider.is_empty():
		for pid in pop.persons:
			if pop.stage(pop.persons[pid]) == "actif" and int(pid) % 2 == 0:
				rider = pop.persons[pid]
				break
	pop._join_job(rider, far)
	var c := pop.commute(rider, pop.home_of(rider), far)
	_check(String(c.mode).contains("bus") and c.has("detail"), "%s va à l'usine %s : %s" % [rider.p, c.mode, c.get("detail", "")])
	pop._board_commuters()
	_check(int(transport.stations.lines[line.id].get("passengers", 0)) >= 2, "voyageurs comptés sur la ligne : %d" % int(transport.stations.lines[line.id].get("passengers", 0)))

	print("Démolition :")
	bs.demolish(school)
	pop._sync_buildings()
	var orphans := 0
	for pid in pop.persons:
		if int(pop.persons[pid].sch) == school:
			orphans += 1
	_check(orphans == 0 and not pop.by_school.has(school), "école démolie : plus aucun élève n'y est inscrit")
	var hid0: int = pop.by_home[homes[0]][0]
	var gone: Array = (pop.households[hid0].m as Array).duplicate()
	bs.demolish(homes[0])
	pop._sync_buildings()
	var left := true
	for pid in gone:
		left = left and not pop.persons.has(pid)
	_check(left and not pop.by_home.has(homes[0]), "immeuble démoli : ses habitants quittent la ville")

	print("La vie avance :")
	pop.life_speed_index = 2 # 1 an = 1 jour
	var someone: int = pop.persons.keys()[0]
	var a0 := pop.age_of(pop.persons[someone])
	pop.arrivals = false
	for i in 5:
		amb.unix_time += 86400.0
		pop.advance(86400.0)
	if pop.persons.has(someone):
		_check(absf(pop.age_of(pop.persons[someone]) - a0 - 5.0) < 0.05, "5 jours de jeu : 5 ans de plus")
	_check(pop.persons.size() > 0, "%d habitants après 5 ans (naissances, décès, départs)" % pop.persons.size())
	var coherent := true
	for pid in pop.persons:
		var p: Dictionary = pop.persons[pid]
		coherent = coherent and pop.households.has(int(p.f)) and (pop.households[int(p.f)].m as Array).has(pid)
		if int(p.job) >= 0:
			coherent = coherent and (pop.by_job[int(p.job)] as Array).has(pid)
	_check(coherent, "foyers et emplois toujours cohérents")

	print("HABITANTS TEST OK" if ok else "HABITANTS TEST ÉCHEC")
	quit(0 if ok else 1)
