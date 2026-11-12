extends SceneTree
## Test des services d'urgence : modèles, conduite prioritaire (on se range,
## on double par la voie d'en face, on passe les feux), casernes et équipages,
## envoi des véhicules, arrivée, hôpital, retour, couverture, liaison avec
## l'autoload Evenements, sauvegarde.
## Usage : godot --headless --path . --script res://tests/urgences_test.gd

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


func _place(bs: BuildingSystem, id: String, x: int, north := true) -> int:
	var d := int(BuildingCatalog.get_type(id).d)
	var c := Vector2i(x, -(d / 2 + 6) if north else d / 2 + 6)
	return bs.place(id, c, bs.best_rotation(id, c))


static func _line(a: Vector3, b: Vector3) -> PackedVector3Array:
	var p := PackedVector3Array()
	for i in 51:
		p.append(a.lerp(b, i / 50.0))
	return p


static func _flat(n: int) -> PackedByteArray:
	var s := PackedByteArray()
	s.resize(n)
	return s


func _run() -> void:
	print("Modèles :")
	for s in ["pompiers", "ambulance", "police"]:
		var ids := VehicleCatalog.for_service(s, "", "europe")
		_check(ids.size() >= 2, "%s : %d modèles en Europe" % [s, ids.size()])
	_check(VehicleCatalog.for_service("police", "", "ameriques").has("police_us"), "police américaine pour les Amériques")
	_check(VehicleCatalog.beacons(VehicleCatalog.get_type("police_nationale")).size() == 2, "deux gyrophares sur le toit")
	var pool := Traffic._no_service(VehicleCatalog.for_track("route"))
	_check(not pool.has("fpt") and not pool.has("ambulance") and pool.has("berline"), "pas de véhicule d'urgence dans la circulation d'ambiance")

	_driving_tests()
	await _city_tests()
	print("TEST OK" if ok else "TEST ÉCHEC")
	quit(0 if ok else 1)


## Une route droite : la voiture lente se range, l'ambulance la double.
func _driving_tests() -> void:
	print("Conduite prioritaire :")
	var net := TransportNetwork.new()
	var M := TransportTypes.Mode.ROAD
	var a := net.add_node(Vector3(0, 0, 0), M)
	var b := net.add_node(Vector3(800, 0, 0), M)
	var c := net.add_node(Vector3(800, 0, 300), M)
	var e := net.add_edge(a, b, "departementale", _line(Vector3.ZERO, Vector3(800, 0, 0)), _flat(51))
	net.add_edge(b, c, "departementale", _line(Vector3(800, 0, 0), Vector3(800, 0, 300)), _flat(51))
	var holder := Node3D.new()
	root.add_child(holder)
	var tf := Traffic.new()
	holder.add_child(tf)
	tf.setup(net)
	tf.set_process(false)
	tf.siren_sound = false
	# Voiture lente devant (20 km/h).
	tf.spawn(M)
	var slow: Dictionary = tf.vehicles[0]
	slow.node = a
	slow.route = [e] as Array[int]
	slow.leg = 0
	slow.s = 60.0
	slow.own_speed = 0.0
	slow.max_speed = 20.0 / 3.6
	slow.factor = 1.0
	slow.lane_idx = 0
	var arrived := [false]
	var amb := tf.add_emergency("ambulance", {"edge": e, "s": 5.0}, {"edge": e, "s": 700.0}, true,
		func(_v: Dictionary) -> void: arrived[0] = true)
	_check(not amb.is_empty() and amb.get("siren", false), "l'ambulance part, sirène allumée")
	_check((amb.get("beacon_nodes", []) as Array).size() == 2, "gyrophares posés sur l'ambulance")
	var pulled := false
	var passed := false
	var max_speed := 0.0
	for i in 600:
		tf.step(0.1)
		pulled = pulled or float(slow.get("pull", 0.0)) > 0.3
		passed = passed or float(amb.get("pass", 0.0)) > 0.9
		max_speed = maxf(max_speed, float(amb.speed))
		if arrived[0]:
			break
	_check(pulled, "la voiture lente se range à droite")
	_check(passed, "l'ambulance double par la voie d'en face")
	_check(arrived[0], "l'ambulance arrive au bout de la route")
	_check(max_speed > TransportTypes.speed_of("departementale") * 1.05, "sirène : un peu au-dessus de la limite (%.0f km/h)" % (max_speed * 3.6))
	_check(absf(float(amb.s) - 700.0) < 3.0 and amb.get("on_site", false), "arrêt au bon endroit (%.1f m)" % float(amb.s))
	# Voiture en face : on ne double pas.
	var back := tf.reroute_emergency(amb, {"edge": e, "s": 10.0}, false, Callable())
	_check(back and not amb.get("on_site", false) and not amb.get("siren", true), "demi-tour pour rentrer, sirène coupée")
	tf.remove_emergency(amb)
	_check(tf.emergency_vehicles().is_empty(), "rentrée au garage : le véhicule disparaît")
	holder.queue_free()


func _city_tests() -> void:
	print("Ville :")
	Creations.persist = false
	BatimentsVie.chantiers = false
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var transport: TransportSystem = scene.get_node("Transport")
	var bs: BuildingSystem = scene.get_node("Batiments")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 40
	world.view_radius_override = 900.0
	world.set_origin(46.2, 6.9)
	for i in 3000:
		await process_frame
		if i >= 120 and world.missing_chunk_count() == 0 and world._dirty.is_empty() and world._jobs.is_empty():
			break
	var urg: Urgences = scene.urgences
	_check(urg != null and scene.urgences_panel != null, "urgences et panneau branchés dans la scène")
	var tf := transport.traffic
	tf.set_process(false)
	urg.set_process(false)
	tf.siren_sound = false
	urg.random_calls = false
	bs.unlimited_money = true
	var y := world.cell_height(Vector2i(0, 0))
	var road := transport.build_segment("route", Vector3(-700, y, 0), Vector3(700, y, 0))
	_check(road.ok, "route de 1,4 km")
	var fire := _place(bs, "pompiers", -400)
	var cop := _place(bs, "police", 0)
	var hosp := _place(bs, "hopital", 400, false)
	_check(fire > 0 and cop > 0 and hosp > 0, "caserne, commissariat et hôpital posés")
	urg._sync_stations()
	_check(urg.stations.size() == 3, "trois bâtiments de secours (%d)" % urg.stations.size())
	var roads_ok := true
	for bid in urg.stations:
		roads_ok = roads_ok and not (urg.stations[bid].road as Dictionary).is_empty()
	_check(roads_ok, "chaque caserne trouve sa route")
	# Sans habitants : personne de garde, personne ne part.
	_check(not urg.unit_ready(fire, urg.stations[fire].units[0]), "caserne sans pompiers de garde : le camion reste au garage")
	urg.ignore_crew = true
	_check(urg.unit_ready(fire, urg.stations[fire].units[0]), "avec son équipage, le camion est prêt")
	_check(urg.model_for("police_nationale") == "gendarmerie", "petite ville : la gendarmerie")
	for i in 25:
		tf.spawn(TransportTypes.Mode.ROAD)

	var id := urg.declare("accident", "Accident de la route", Vector3(150, y, 4), ["pompiers", "ambulance", "police"], 1)
	_check(urg.incidents.has(id), "appel enregistré")
	var inc: Dictionary = urg.incidents[id]
	_check((inc.units as Array).size() == 3, "trois véhicules envoyés (%d)" % (inc.units as Array).size())
	var roles := {}
	for u in inc.units:
		roles[String(u.role)] = String(u.model)
	_check(roles.get("pompiers", "") == "fpt", "pompiers : le fourgon pompe-tonne")
	_check(roles.get("police", "") == "gendarmerie", "police : la gendarmerie")
	var all_arrived := false
	var closed := false
	var saw_hospital := false
	var steps := 0
	for i in 6000:
		tf.step(0.1)
		urg.step(0.1)
		steps = i
		for bid in urg.stations:
			for u in urg.stations[bid].units:
				saw_hospital = saw_hospital or String(u.get("phase", "")) in ["hopital", "pause"]
		if not all_arrived and (inc.arrived as Dictionary).size() == 3:
			all_arrived = true
		if not urg.incidents.has(id):
			closed = true
			break
	_check(all_arrived, "les trois services arrivent sur place")
	_check(closed, "intervention terminée en %d s" % int(steps * 0.1))
	for s in ["pompiers", "ambulance", "police"]:
		_check(int(urg.stats[s].n) == 1 and float(urg.stats[s].best) > 5.0, "temps d'arrivée %s : %s" % [s, Urgences.format_time(float(urg.stats[s].best))])
	var home := false
	for i in 6000:
		tf.step(0.1)
		urg.step(0.1)
		for bid in urg.stations:
			for u in urg.stations[bid].units:
				saw_hospital = saw_hospital or String(u.get("phase", "")) in ["hopital", "pause"]
		var out := 0
		for bid in urg.stations:
			for u in urg.stations[bid].units:
				if u.out:
					out += 1
		if out == 0:
			home = true
			break
	_check(saw_hospital, "l'ambulance passe par l'hôpital")
	_check(home and tf.emergency_vehicles().is_empty(), "tous les véhicules sont rentrés")

	print("Couverture :")
	urg.set_coverage("pompiers")
	var times := urg.coverage_times("pompiers")
	_check(times.size() >= 2 and urg._cover_mesh.visible, "carte de couverture des pompiers (%d nœuds)" % times.size())
	urg.set_coverage("")
	_check(not urg._cover_mesh.visible, "couverture masquée")

	print("Événements de la ville :")
	var ev := _fake_events()
	root.add_child(ev)
	# Dans le jeu, l'autoload existe dès le départ ; ici on le branche à la main.
	urg._connect_events()
	var eid: int = ev.call("declarer", {"type": "incendie", "position": Vector3(-200, y, 6), "gravite": 2, "besoin": ["pompiers"]})
	_check(urg.incidents.has(eid), "incendie déclaré par Evenements : pris en charge")
	_check(int(ev.get("taken")) == eid, "prendre_en_charge appelé")
	_check((urg.incidents[eid].units as Array).size() == 2, "gravité 2 : deux engins de pompiers")
	for i in 6000:
		tf.step(0.1)
		urg.step(0.1)
		if not urg.incidents.has(eid):
			break
	_check(int(ev.get("solved")) == eid, "resoudre appelé après le travail sur place")
	var lid := urg.random_call("malaise", Vector3(0, y, 0))
	_check(lid < 0 or urg.incidents.has(lid), "appel au hasard (passe par Evenements quand il existe)")
	ev.free()

	print("Sauvegarde :")
	var d := urg.to_dict()
	var n_before := int(urg.stats.pompiers.n)
	urg.from_dict(JSON.parse_string(JSON.stringify(d)))
	_check(int(urg.stats.pompiers.n) == n_before and urg.stations.size() == 3, "bilan et casernes retrouvés")
	_check(scene.save_sections().has("urgences"), "section « urgences » dans la sauvegarde")
	scene.queue_free()


## Faux autoload Evenements avec le contrat convenu.
func _fake_events() -> Node:
	var g := GDScript.new()
	g.source_code = """extends Node
signal incident_declare(incident: Dictionary)
signal incident_aggrave(id: int, gravite: int)
signal incident_resolu(id: int)
var next := 1
var taken := -1
var solved := -1
func declarer(inc: Dictionary) -> int:
	var i := next
	next += 1
	inc = inc.duplicate()
	inc.id = i
	incident_declare.emit(inc)
	return i
func prendre_en_charge(id: int, _service: String) -> void:
	taken = id
func resoudre(id: int) -> void:
	solved = id
	incident_resolu.emit(id)
"""
	g.reload()
	var n := Node.new()
	n.set_script(g)
	n.name = "Evenements"
	return n
