extends SceneTree
## Test de la journée visible : vitesses du temps, habitants dessinés qui vont
## au travail par les voies, ordres donnés aux habitants, personnage principal
## du joueur (naissance, questions, héritier), incarnation en vue au sol.
## Usage : godot --headless --path . --script res://tests/journee_test.gd

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
	pop.rng.seed = 99
	amb.set_speed(0)
	amb.unix_time = _at("2026-03-10", 10.0)

	print("Vitesses du temps :")
	_check(DayNight.SPEEDS.slice(2) == [60.0, 600.0, 6000.0], "1 min/s, 10 min/s, 100 min/s")
	_check(DayNight.SPEED_NAMES[4] == "100 min/s", "nom : 100 min/s")
	_check(Population.LIFE_SPEEDS[Population.DEFAULT_LIFE_SPEED] == 12.0, "vie : 1 an = 1 mois de jeu par défaut")

	print("Une ville :")
	bs.unlimited_money = true
	var y := world.cell_height(Vector2i(0, 0))
	transport.build_segment("departementale", Vector3(0, y, -300), Vector3(0, y, 300))
	transport.build_segment("departementale", Vector3(0, y, 0), Vector3(300, y, 0))
	var homes := []
	for i in 5:
		homes.append(bs.place("immeuble", Vector2i(-16, -250 + i * 22), 1))
	var office := bs.place("bureaux", Vector2i(200, 16), 0)
	var shop := bs.place("superette", Vector2i(16, 120), 3)
	var gym := bs.place("gymnase", Vector2i(-24, 160), 1)
	_check(office > 0 and gym > 0 and not homes.has(-1), "logements, bureaux, gymnase")
	pop._sync_buildings()
	pop.arrivals = true
	for i in 72:
		pop.advance(300.0)
	pop.arrivals = false
	_check(pop.persons.size() > 30, "%d habitants" % pop.persons.size())
	var spare := bs.place("maison", Vector2i(16, -200), 3)
	pop._sync_buildings()
	_check(spare > 0 and pop.free_homes(spare) > 0, "une maison libre")

	print("Personnage principal :")
	var me := pop.principal.mine()
	_check(me >= 0, "ton personnage est né en ville")
	if me >= 0:
		var p: Dictionary = pop.persons[me]
		_check(String(p.joueur) == pop.player_id() and pop.age_of(p) < 0.1, "il a 0 an et t'appartient")
		_check(int(p.pa[0]) >= 0 and int(p.pa[1]) >= 0, "il a une mère et un père")
		_check(pop.followed() == me, "il est suivi d'office")

	print("Habitants visibles (8 h 15, un mardi) :")
	var worker := -1
	for pid in pop.by_job.get(office, []):
		worker = pid
		break
	_check(worker >= 0, "un employé des bureaux")
	amb.unix_time = _at("2026-03-10", 7.0)
	pop._now = {}
	var plan := pop.day_plan(pop.persons[worker])
	var go := -1.0
	for seg in plan:
		if String(seg[2]) == "trajet" and int(seg[3]) == office:
			go = (float(seg[0]) + float(seg[1])) * 0.5
	_check(go > 0.0, "son trajet vers les bureaux est prévu à %.2f h" % go)
	pop.follow(worker)
	pop.follow_camera = false
	amb.unix_time = _at("2026-03-10", go)
	pop._now = {}
	scene.rig.position = Vector3(0, scene.rig.position.y, 0)
	pop.passants._cand_timer = 0.0
	for i in 4:
		await process_frame
	var a: Dictionary = pop.passants.agents.get(worker, {})
	_check(not a.is_empty(), "il est dessiné dans la rue pendant son trajet (%d passants en tout)" % pop.passants.agents.size())
	if not a.is_empty():
		var pos: Vector3 = (a.body as Node3D).global_position
		var snap := transport.network.find_snap(pos, TransportTypes.Mode.ROAD, 6.0)
		_check(not snap.is_empty(), "il suit la route (%.0f, %.0f)" % [pos.x, pos.z])
		var cam := root.get_viewport().get_camera_3d()
		var spot := cam.unproject_position((a.body as Node3D).global_position + Vector3(0, 1.0, 0))
		_check(pop.passants.pick(spot, cam) == worker or cam.is_position_behind(pos), "clic sur lui : on le reconnaît")
		var before := pos
		amb.unix_time += 120.0
		pop._now = {}
		await process_frame
		await process_frame
		var after: Vector3 = (pop.passants.agents[worker].body as Node3D).global_position if pop.passants.agents.has(worker) else before
		_check(after.distance_to(before) > 1.0, "deux minutes plus tard, il a avancé (%.0f m)" % after.distance_to(before))
	amb.unix_time = _at("2026-03-10", 11.0)
	pop._now = {}
	await process_frame
	_check(not pop.passants.agents.has(worker), "11 h : il est au travail, plus dans la rue")

	print("Ordres :")
	var r := pop.give_order(worker, "loisir", "musculation" if Ordres.hobby_venues(pop, pop.persons[worker]).has("musculation") else null)
	_check(bool(r.ok), "ordre « loisir » : %s" % r.text)
	pop._now = {}
	var act := pop.activity(pop.persons[worker])
	_check(String(act.kind) == "trajet", "il part tout de suite (%s)" % act.text)
	amb.unix_time = _at("2026-03-10", 12.5)
	pop._now = {}
	act = pop.activity(pop.persons[worker])
	_check(String(act.kind) == "loisir" and String(act.text).contains("sur ton ordre"), "12 h 30 : %s" % act.text)
	amb.unix_time = _at("2026-03-10", 20.0)
	pop._now = {}
	act = pop.activity(pop.persons[worker])
	_check(int(act.bid) == pop.home_of(pop.persons[worker]), "le soir, il est rentré chez lui")
	amb.unix_time = _at("2026-03-11", 11.0)
	pop._now = {}
	act = pop.activity(pop.persons[worker])
	_check(not pop.persons[worker].has("ord") and int(act.bid) == office, "le lendemain, il reprend sa journée")
	pop.order_pick = worker
	r = pop.give_order(worker, "aller", gym)
	_check(bool(r.ok) and int(pop.persons[worker].ord.b) == gym, "ordre « aller à » le gymnase")
	r = pop.give_order(worker, "dormir")
	_check(bool(r.ok), "ordre « dormir »")
	pop._now = {}
	var later := pop.day_plan(pop.persons[worker])
	_check(String(later[-1][2]) == "dort" and int(later[-1][3]) == pop.home_of(pop.persons[worker]), "il rentre se coucher")
	r = pop.give_order(worker, "demission")
	_check(bool(r.ok) and int(pop.persons[worker].job) < 0, "démission : %s" % r.text)
	r = pop.give_order(worker, "emploi")
	_check(bool(r.ok) and int(pop.persons[worker].job) >= 0, "nouvel emploi : %s" % r.text)
	var hid := int(pop.persons[worker].f)
	var old_home := int(pop.households[hid].b)
	r = pop.give_order(worker, "demenager", spare)
	_check(bool(r.ok) and int(pop.households[hid].b) == spare and old_home != spare, "déménagement : %s" % r.text)
	var single := -1
	for pid in pop.persons:
		var q: Dictionary = pop.persons[pid]
		if pop.age_of(q) > 22.0 and pop.age_of(q) < 40.0 and int(q.cj) < 0 and String(q.get("joueur", "")) == "":
			single = pid
			break
	if single >= 0:
		r = pop.give_order(single, "rencontre")
		print("    ", r.text)
		if bool(r.ok):
			_check(int(pop.persons[single].cj) >= 0, "rencontre : en couple")
			r = pop.give_order(single, "mariage")
			_check(bool(r.ok) and String(pop.persons[single].un) == "mariage", "mariage : %s" % r.text)
			var mom := Ordres.mother_for(pop, pop.persons[single])
			if mom >= 0:
				var kids_before := pop.vie.children_of(mom).size()
				r = pop.give_order(single, "enfant")
				_check(bool(r.ok) and pop.vie.children_of(mom).size() == kids_before + 1, "enfant : %s" % r.text)
			r = pop.give_order(single, "separation")
			_check(bool(r.ok) and int(pop.persons[single].cj) < 0, "séparation : %s" % r.text)
	var senior := -1
	for pid in pop.persons:
		if pop.stage(pop.persons[pid]) == "actif" and pop.age_of(pop.persons[pid]) >= 60.0:
			senior = pid
	if senior < 0:
		senior = worker
		pop.persons[senior].nj = pop.life_clock - 61.0 * 365.25
	r = pop.give_order(senior, "retraite")
	_check(bool(r.ok) and pop.stage(pop.persons[senior]) == "retraite", "retraite anticipée : %s" % r.text)
	var baby := -1
	for pid in pop.persons:
		if pop.age_of(pop.persons[pid]) < 2.0:
			baby = pid
	if baby >= 0:
		_check(Ordres.check(pop, pop.persons[baby], "courses") != "", "un bébé ne reçoit pas d'ordre de sortie")
	pop.persons[worker].joueur = "un-autre-joueur"
	r = pop.give_order(worker, "rentrer")
	_check(not bool(r.ok), "pas d'ordre au personnage principal d'un autre joueur")
	pop.persons[worker].erase("joueur")

	print("Questions du personnage principal :")
	if me >= 0 and pop.persons.has(me):
		var p: Dictionary = pop.persons[me]
		amb.set_speed(2)
		pop.principal.ask_studies(p)
		_check(pop.principal.questions.size() == 1 and amb.speed_index == 0, "question posée : le temps se met en pause")
		var panel: HabitantsPanel = scene.habitants_panel
		await process_frame
		_check(panel._ask.visible and panel._ask_buttons.get_child_count() == 4, "carte de la question avec 4 choix")
		pop.principal.answer(int(pop.principal.questions[0].id), 1)
		_check(String(p.etd) == "licence" and amb.speed_index == 2, "réponse « licence » : études choisies, le temps repart")
		await process_frame
		_check(not panel._ask.visible, "la carte disparaît")
		var saved: Dictionary = JSON.parse_string(JSON.stringify(pop.to_dict()))
		pop.from_dict(saved)
		_check(pop.principal.mine() == me, "sauvegarde : ton personnage est toujours à toi")
		amb.set_speed(0)
		pop.vie.die(me, "dans un accident")
		_check(pop.principal.questions.size() == 1 and String(pop.principal.questions[0].kind) == "heritier",
			"à sa mort : avec qui continuer ?")
		var opts: Array = pop.principal.questions[0].options
		pop.principal.answer(int(pop.principal.questions[0].id), opts.size() - 1)
		var me2 := pop.principal.mine()
		_check(me2 >= 0 and me2 != me, "« nouveau personnage » : un autre bébé naît (%s)" % (CycleVie.full_name(pop.persons[me2]) if me2 >= 0 else "—"))

	print("Incarner un habitant :")
	var walker: int = pop.persons.keys()[0]
	for pid in pop.persons:
		if pop.age_of(pop.persons[pid]) > 20.0:
			walker = pid
			break
	_check(pop.incarnate(walker), "prendre sa place")
	var vs: VueSol = scene.get_node("VueSol")
	await process_frame
	_check(vs.vue == VueSol.Vue.TROISIEME and pop.incarnated() == walker, "vue au sol, en 3e personne")
	_check(String(pop.activity(pop.persons[walker]).text).begins_with("Dirigé"), "sa fiche : dirigé par toi")
	vs.set_vue(VueSol.Vue.DESSUS)
	await process_frame
	_check(pop.incarnated() == -1, "V : il reprend sa journée")

	print("JOURNEE TEST OK" if ok else "JOURNEE TEST ÉCHEC")
	quit(0 if ok else 1)
