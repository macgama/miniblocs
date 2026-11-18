extends SceneTree
## Test des allées et venues (Passants + Portes) : l'habitant sort de chez lui
## par une porte qui s'ouvre, marche jusqu'au trottoir ou jusqu'à sa voiture
## garée, roule, se gare à l'arrivée et entre ; la pause arrête tout ; niveaux de
## détail et plafonds ; trajets visibles vers les courses et les loisirs ; bus.
## Usage : godot --headless --path . --script res://tests/allees_venues_test.gd

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


## Fait avancer les scènes d'un passant à la main (dt visible) jusqu'à cond, au plus n pas.
func _pas(ps: Passants, n: int, dt: float, cond: Callable) -> int:
	for i in n:
		ps._animer(EchelleTemps.dt(dt))
		ps.portes.avancer(EchelleTemps.dt(dt))
		if cond.call():
			return i
	return -1


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
	var ps: Passants = pop.passants
	pop.rng.seed = 7
	amb.set_speed(0)
	amb.unix_time = _at("2026-03-10", 10.0)

	print("Une rue :")
	bs.unlimited_money = true
	var y := world.cell_height(Vector2i(0, 0))
	transport.build_segment("departementale", Vector3(0, y, -300), Vector3(0, y, 300))
	var home := bs.place("maison", Vector2i(-14, -60), 1)
	var office := bs.place("superette", Vector2i(16, 140), 3)
	var shop := bs.place("superette", Vector2i(-16, 40), 1)
	print("    bâtiments : ", home, " ", office, " ", shop)
	_check(home > 0 and office > 0 and shop > 0, "une maison et deux supérettes le long de la rue")
	pop._sync_buildings()
	scene.rig.position = Vector3(0, scene.rig.position.y, -60)
	for i in 3:
		await process_frame
	var cam := root.get_viewport().get_camera_3d()
	var pid := -1
	var hh := pop.spawn_household(home)
	if hh >= 0:
		pid = int(pop.households[hh].m[0])
	_check(pid >= 0, "un habitant dans la maison")
	if pid < 0:
		quit(1)
		return

	print("La porte d'entrée :")
	var cadre := ps._cadre(home, Vector3(0, y, -60))
	var r: Rect2i = pop.known[home].rect
	_check(cadre.n == Vector3.RIGHT and float(cadre.face.x) <= float(r.end.x) + 0.01, "sur la façade côté rue (x = %.1f, parcelle jusqu'à %d)" % [float(cadre.face.x), r.end.x])
	_check(float(cadre.bord.x) >= float(r.end.x), "il traverse le jardin jusqu'au bord de la parcelle")
	var cs := ps._cadre(shop, Vector3(0, y, 40))
	var rs: Rect2i = pop.known[shop].rect
	print("    supérette : parcelle x %d → %d, porte à x = %.1f" % [rs.position.x, rs.end.x, float(cs.face.x)])
	_check(Rect2(r).has_point(Vector2(cadre.dedans.x, cadre.dedans.z)), "le personnage part de l'intérieur (caché par les murs)")
	_check(bool(cadre.porte), "un vantail est dessiné")

	print("Il sort de chez lui à pied (scène pas à pas, 1 jour/min) :")
	ps.set_process(false)
	ps.clear()
	EchelleTemps.force = 1.0
	var day := int(pop.now().day)
	ps._h = 8.0
	ps._day = day
	ps._nouveau(pid, home, shop, "pied", 8.0, 8.2, day, 8.0)
	var a: Dictionary = ps.agents.get(pid, {})
	_check(not a.is_empty() and String(a.phase) == "sortie", "nouveau passant : scène de sortie")
	_check(ps.portes.portes.size() == 1, "la porte s'ouvre")
	var w: Node3D = a.walker
	var p0 := w.position
	_pas(ps, 5, 0.1, func() -> bool: return false)
	var porte: Dictionary = ps.portes.portes.values()[0]
	_check(float(porte.ouv) > 0.5, "la porte est ouverte (%.0f %%)" % (float(porte.ouv) * 100.0))
	_check(w.position.distance_to(p0) > 0.5, "il avance vers la porte")
	print("Pause :")
	EchelleTemps.force = 0.0
	var p1 := w.position
	var o1 := float(porte.ouv)
	_pas(ps, 20, 0.1, func() -> bool: return false)
	_check(w.position == p1 and float(porte.ouv) == o1, "en pause, il ne bouge plus et la porte reste figée")
	EchelleTemps.force = 1.0
	var n := _pas(ps, 200, 0.1, func() -> bool: return String(a.phase) == "route")
	_check(n >= 0, "arrivé sur le trottoir, il part (%.1f s)" % ((n + 6) * 0.1))
	var road: PackedVector3Array = a.itin.legs[0].path
	_check(w.position.distance_to(road[0]) < 1.0, "il est au début de son chemin sur le trottoir")
	_pas(ps, 40, 0.1, func() -> bool: return false)
	_check(ps.portes.portes.is_empty(), "derrière lui, la porte se referme et disparaît")
	ps._h = 8.1
	_pas(ps, 1, 0.1, func() -> bool: return false)
	var mid := (a.itin.legs[0].d as PackedFloat32Array)[-1] * 0.5
	_check(absf(float(a.q) - 0.5) < 0.05, "à mi-trajet à l'horloge, il est à mi-chemin (q = %.2f, %.0f m)" % [float(a.q), mid])
	print("Il arrive à la supérette et entre :")
	ps._h = 8.25
	n = _pas(ps, 30, 0.1, func() -> bool: return String(a.phase) == "entree")
	_check(n >= 0 and n <= 10, "trajet fini à l'horloge : il rattrape et arrive (%d pas)" % n)
	n = _pas(ps, 200, 0.1, func() -> bool: return ps.portes.portes.size() == 1)
	_check(n >= 0, "la porte de la supérette s'ouvre devant lui")
	n = _pas(ps, 200, 0.1, func() -> bool: return not ps.agents.has(pid))
	_check(n >= 0, "il entre et disparaît à l'intérieur")

	print("En voiture :")
	ps.clear()
	ps._h = 7.5
	ps._nouveau(pid, home, office, "voiture", 7.5, 7.7, day, 7.5)
	a = ps.agents[pid]
	_check(String(a.phase) == "sortie" and a.veh != null and (a.veh as Node3D).visible, "sa voiture l'attend, garée devant chez lui")
	var car: Node3D = a.veh
	var park: Vector3 = car.position
	_check(not transport.network.find_snap(park, TransportTypes.Mode.ROAD, 4.0).is_empty() and absf(park.x) > 1.8, "au bord de la rue, côté maison (x = %.1f)" % park.x)
	n = _pas(ps, 200, 0.1, func() -> bool: return String(a.phase) == "route")
	_check(n >= 0 and not (a.walker as Node3D).visible and a.body == car, "il monte : on ne voit plus que la voiture")
	_check((a.walker as Node3D).position.distance_to(park) < 1.6, "il a marché jusqu'à la portière")
	ps._h = 7.6
	_pas(ps, 1, 0.1, func() -> bool: return false)
	_check(car.position.distance_to(park) > 30.0, "la voiture roule (%.0f m)" % car.position.distance_to(park))
	ps._h = 7.72
	n = _pas(ps, 30, 0.1, func() -> bool: return String(a.phase) == "entree")
	_check(n >= 0, "elle arrive à l'autre supérette")
	n = _pas(ps, 200, 0.1, func() -> bool: return not ps.agents.has(pid))
	_check(n >= 0 and ps.garees.has(pid), "il se gare, descend et entre ; la voiture reste garée")
	var g: Node3D = ps.garees.get(pid, {}).get("node") if ps.garees.has(pid) else null
	_check(g != null and g.visible and is_instance_valid(g), "voiture garée devant le magasin")
	ps._h = 17.0
	ps._nouveau(pid, office, home, "voiture", 17.0, 17.2, day, 17.0)
	_check(ps.agents[pid].veh == g and not ps.garees.has(pid), "le soir, il reprend la même voiture")

	print("Niveaux de détail :")
	ps.clear()
	scene.rig.position = Vector3(0, scene.rig.position.y, 280)
	await process_frame
	ps._nouveau(pid, home, shop, "pied", 8.0, 8.2, day, 8.0)
	a = ps.agents[pid]
	_check(not bool(a.proche) and String(a.phase) == "route", "loin de la caméra : pas de scène de porte, juste en route")
	_check(a.walker is MeshInstance3D, "loin de la caméra : simple bloc")
	_check(ps.portes.portes.is_empty(), "aucune porte ouverte au loin")
	scene.rig.position = Vector3(0, scene.rig.position.y, -60)
	await process_frame
	ps.clear()
	ps._nouveau(pid, home, shop, "pied", 8.0, 8.2, day, 8.0)
	_check(bool(ps.agents[pid].proche), "près de la caméra : personnage détaillé")
	ps.clear()
	# Plafond des scènes : 60 départs simultanés devant la caméra.
	var pids: Array = pop.persons.keys()
	var faux := 900000
	for i in 60:
		var q: Dictionary = pop.persons[pids[0]].duplicate()
		q.id = faux + i
		pop.persons[faux + i] = q
		ps._nouveau(faux + i, home, shop, "pied", 8.0, 8.2, day, 8.0)
	_check(ps.scenes() <= Passants.MAX_SCENES, "au plus %d scènes de porte à la fois (%d)" % [Passants.MAX_SCENES, ps.scenes()])
	_check(ps.proches() <= Passants.MAX_PROCHES, "au plus %d personnages détaillés (%d)" % [Passants.MAX_PROCHES, ps.proches()])
	_check(ps.portes.portes.size() <= Portes.MAX, "portes plafonnées")
	for i in 60:
		pop.persons.erase(faux + i)
	ps.clear()

	print("Courses et loisirs visibles :")
	var plan := [[0.0, 7.0, "dort", home, "Dort"], [7.0, 10.0, "maison", home, "À la maison"],
		[10.0, 11.0, "courses", shop, "Fait les courses"], [11.0, 22.0, "maison", home, "À la maison"]]
	var vu := ps._avec_trajets(pop.persons[pid], plan)
	var aller := -1
	var retour := -1
	for i in vu.size():
		if String(vu[i][2]) == "trajet":
			if int(vu[i][3]) == shop:
				aller = i
			elif int(vu[i][3]) == home:
				retour = i
	_check(aller > 0 and float(vu[aller][0]) == 10.0, "il va faire les courses (trajet à 10 h)")
	_check(retour > aller and float(vu[retour][0]) == 11.0, "et il rentre (trajet à 11 h)")
	_check(plan.size() == 4, "l'emploi du temps de la simulation n'est pas modifié")

	print("Bus, tram, train :")
	_check(Passants._mode_of("En route en bus (Ligne 1)") == "tc" and Passants._mode_of("Rentre en tram (T2) + 1 correspondance") == "tc", "reconnus dans l'emploi du temps")
	_check(Passants._mode_of("Rentre à pied (long trajet)") == "pied" and Passants._mode_of("En route en voiture") == "voiture", "les autres modes aussi")
	var it := ps._itin(home, shop, "tc")
	_check(String(it.mode) == "pied", "sans ligne, il y va à pied")

	print("En jeu (horloge, 1 min/s) :")
	EchelleTemps.force = -1.0
	ps.set_process(true)
	ps.clear()
	amb.unix_time = _at("2026-03-10", 10.0)
	pop._now = {}
	pop.order_pick = pid
	var ordre := pop.give_order(pid, "aller", office)
	print("    ordre : ", ordre.text)
	ps.forget(pid)
	var go := -1.0
	var dest := -1
	var plan2 := ps._plan_of(pid, pop.now())
	for i in plan2.size():
		if String(plan2[i][2]) == "trajet" and i > 0 and int(plan2[i - 1][3]) == home:
			go = float(plan2[i][0])
			dest = int(plan2[i][3])
			break
	_check(go >= 0.0, "il sort de chez lui à %.2f h" % go)
	if go >= 0.0:
		amb.unix_time = _at("2026-03-10", go + 0.005)
		pop._now = {}
		amb.set_speed(2)
		ps._cand_timer = 0.0
		var seen := false
		for i in 30:
			await process_frame
			if ps.agents.has(pid) and String(ps.agents[pid].phase) == "sortie":
				seen = true
				break
		_check(seen, "on le voit sortir de chez lui (porte : %d)" % ps.portes.portes.size())
		amb.set_speed(0)
		await process_frame
		if ps.agents.has(pid):
			var b: Node3D = ps.agents[pid].body
			var pb := b.position
			for i in 10:
				await process_frame
			_check(b.position == pb, "pause : il s'arrête net")
	EchelleTemps.force = -1.0

	print("")
	print("ALLEES VENUES OK" if ok else "ALLEES VENUES ÉCHEC")
	quit(0 if ok else 1)
