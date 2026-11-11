extends SceneTree
## Test des transports : graphe, tracé sur le relief (pentes, ponts, tunnels),
## carrefours automatiques, terrassement, véhicules, sauvegarde.
## Fonctionne sans réseau (relief synthétique).
## Usage : godot --headless --path . --script res://tests/transport_test.gd
## Capture (nécessite un affichage) : ... -- --screenshot chemin.png

var ok := true
var world: TerrainWorld


func _initialize() -> void:
	_run.call_deferred()


func _check(cond: bool, what: String) -> void:
	if not cond:
		push_error("ÉCHEC : " + what)
		ok = false
	else:
		print("  ok  ", what)


## Relief synthétique en mètres locaux : plaine à 20 m, colline de 45 m en x = 200,
## vallée en x = -100, mer au-delà de x = -300.
static func terrain_at(x: float, z: float) -> float:
	if x < -300.0:
		return -10.0
	var h := 20.0
	h += 45.0 * exp(-((x - 200.0) * (x - 200.0) + z * z) / 3600.0)
	h -= 16.0 * exp(-((x + 100.0) * (x + 100.0)) / 400.0)
	return h


func _fake_tile(t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	for y in 256:
		for x in 256:
			var gx := float(t.x * 256 + x)
			var gy := float(t.y * 256 + y)
			var lx := (gx - world._px0) / world._px_per_m
			var lz := (gy - Geo.lat_to_pixel_y(world.origin_lat, 15)) / world._px_per_m
			a[y * 256 + x] = terrain_at(lx, lz)
	return a


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var shot := ""
	for i in args.size():
		if args[i] == "--screenshot" and i + 1 < args.size():
			shot = args[i + 1]

	print("Graphe :")
	var net := TransportNetwork.new()
	var a := net.add_node(Vector3(0, 0, 0), TransportTypes.Mode.ROAD)
	var b := net.add_node(Vector3(100, 0, 0), TransportTypes.Mode.ROAD)
	var c := net.add_node(Vector3(100, 0, 100), TransportTypes.Mode.ROAD)
	var e1 := net.add_edge(a, b, "route", _line(Vector3(0, 0, 0), Vector3(100, 0, 0)), _flat(51))
	net.add_edge(b, c, "route", _line(Vector3(100, 0, 0), Vector3(100, 0, 100)), _flat(51))
	_check(is_equal_approx(float(net.edges[e1].len), 100.0), "longueur d'un tronçon (100 m)")
	_check(net.find_route(a, c).size() == 2, "itinéraire A* sur 2 tronçons")
	var mid := net.split_edge(e1, 40.0)
	_check(net.degree(mid) == 2 and net.edges.size() == 3, "couper un tronçon crée un nœud")
	_check(net.node_pos(mid).distance_to(Vector3(40, 0, 0)) < 0.01, "nœud de coupe au bon endroit")
	_check(net.find_route(a, c).size() == 3, "itinéraire après la coupe")
	var snap := net.find_snap(Vector3(70, 0, 1.5), TransportTypes.Mode.ROAD, 3.0)
	_check(not snap.is_empty() and int(snap.edge) >= 0 and absf(float(snap.s) - 30.0) < 0.5, "accroche au milieu d'une route")
	_check(net.find_snap(Vector3(70, 0, 1.5), TransportTypes.Mode.RAIL, 3.0).is_empty(), "pas d'accroche entre modes différents")
	var copy := TransportNetwork.new()
	copy.from_dict(JSON.parse_string(JSON.stringify(net.to_dict())))
	_check(copy.edges.size() == 3 and copy.nodes.size() == 4 and copy.find_route(a, c).size() == 3, "sauvegarde JSON du graphe")
	net.remove_edge(net.adjacency[c][0])
	_check(not net.nodes.has(c), "démolir retire les nœuds isolés")

	print("Tracé sur le relief :")
	var g := func(x: float, z: float) -> float: return terrain_at(x, z)
	var flat := _p("route", -20, -50, -20, 50, g)
	_check(flat.ok and float(flat.bridge_len) == 0.0 and float(flat.tunnel_len) == 0.0, "route en plaine, au sol")
	var valley := _p("route", -170, 0, -30, 0, g)
	_check(valley.ok and float(valley.bridge_len) > 10.0, "pont au-dessus de la vallée (%d m)" % roundi(valley.get("bridge_len", 0.0)))
	_check(valley.ok and float(valley.max_grade) <= 0.0701, "pente maxi de la départementale respectée (%.1f %%)" % (float(valley.max_grade) * 100.0))
	var hill := _p("rail", 60, 0, 340, 0, g)
	_check(hill.ok and float(hill.tunnel_len) > 20.0, "tunnel ferroviaire sous la colline (%d m)" % roundi(hill.get("tunnel_len", 0.0)))
	_check(hill.ok and float(hill.max_grade) <= 0.0251, "rail : rampe ≤ 25 ‰ (%.1f %%)" % (float(hill.max_grade) * 100.0))

	print("Gabarits et courbes :")
	_check(is_equal_approx(TransportTypes.width_of("departementale", {}), 9.5), "départementale : 2 × 3,00 m + accotements 1,75 m = 9,50 m")
	_check(is_equal_approx(TransportTypes.width_of("autoroute", {"lanes": 2}), 23.0), "autoroute 2 × 2 voies : 23 m (voies 3,50, TPC 3, BAU 3)")
	_check(TransportTypes.normalize("avenue", {"lanes": 5, "lane_w": 4.2}) == {"lanes": 3, "lane_w": 3.5}, "réglages ramenés aux limites réglementaires")
	_check(is_equal_approx(TransportTypes.width_of("avenue", {"lanes": 1, "lane_w": 3.0}), 10.0), "avenue 2 × 1 voie sans terre-plein : 10 m")
	_check(TransportTypes.resolve("route") == "departementale", "anciennes sauvegardes : « route » devient départementale")
	var bend := RoutePlanner.bezier(Vector2(-20, -60), Vector2(40, -60), Vector2(40, 0))
	var c_rue := RoutePlanner.plan("rue", bend, NAN, NAN, g)
	_check(c_rue.ok and float(c_rue.min_radius) < 80.0, "rue en courbe (rayon %d m)" % roundi(c_rue.get("min_radius", 0.0)))
	var c_auto := RoutePlanner.plan("autoroute", bend, NAN, NAN, g)
	_check(not c_auto.ok and String(c_auto.reason).begins_with("Virage trop serré"), "autoroute : virage trop serré refusé")
	_check(c_auto.pts.size() > 10, "le tracé refusé reste affiché en aperçu")
	var steep := _p("route", 60, 0, 200, 0, g)
	_check(not steep.ok and String(steep.reason).begins_with("Pente trop forte"), "refus si la pente est trop forte")
	var sea := _p("voie_eau", -400, 0, -350, 60, g)
	_check(sea.ok, "voie navigable sur la mer")
	var land := _p("voie_eau", -400, 0, -200, 0, g)
	_check(not land.ok, "voie navigable refusée sur la terre")
	var coast := _p("rue", -200, 0, -420, 0, g)
	_check(coast.ok and float(coast.bridge_len) > 40.0, "pont au-dessus de la mer")

	print("Mode Terre :")
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	world = scene.get_node("Terrain")
	var tr: TransportSystem = scene.get_node("Transport")
	root.add_child(scene)
	world.tiles.offline_generator = _fake_tile
	world.set_origin(48.8584, 2.2945)
	for i in 30:
		await process_frame
	_check(absf(world.raw_height(-20.5, 0.5) - terrain_at(-20.5, 0.5)) < 0.5, "relief synthétique chargé")

	var r1 := tr.build_segment("route", Vector3(-20, 0, -60), Vector3(-20, 0, 60))
	_check(r1.ok and tr.network.edges.size() == 1, "poser une route")
	var par := tr.build_segment("route", Vector3(-14, 0, -40), Vector3(-14, 0, -10))
	_check(not par.ok and String(par.reason).begins_with("Chevauche"), "refus d'une route qui en chevauche une autre")
	var under := world.cell_height(Vector2i(-20, 0))
	var deck := tr.network.point_at(r1.edges[0], 60.0).y
	_check(under <= deck + 0.01 and deck - under < 0.6, "la chaussée repose sur les cases (%.2f / %.2f)" % [deck, under])
	var r2 := tr.build_segment("route", Vector3(-60, 0, 0), Vector3(30, 0, 0))
	_check(r2.ok and int(r2.junctions) == 1, "carrefour automatique au croisement")
	var cross := -1
	for id in tr.network.nodes:
		if tr.network.degree(id) == 4:
			cross = id
	_check(cross >= 0 and tr.network.edges.size() == 4, "carrefour à 4 branches")
	await process_frame
	var trims := TransportView.compute_trims(tr.network)
	var trimmed := 0
	for eid in tr.network.adjacency[cross]:
		var tv: Vector2 = trims.get(eid, Vector2.ZERO)
		if tv.x > 4.0 or tv.y > 4.0:
			trimmed += 1
	_check(trimmed == 4, "les 4 branches s'arrêtent au bord du carrefour")
	_check(tr.view.junction_count() >= 1, "plateau de carrefour dessiné")
	_check(tr.is_cell_occupied(Vector2i(-20, 10)) and world.tree_blocker.call(Vector2i(-20, 10)), "pas d'arbre sur la route")
	_check(not world.tree_blocker.call(Vector2i(-80, 80)), "arbres possibles loin des voies")
	var r3 := tr.build_segment("route", Vector3(30.5, 0, 0.8), Vector3(30, 0, 50))
	_check(r3.ok and int(r3.start_node) == int(r2.end_node), "raccord sur l'extrémité d'une route")
	var r4 := tr.build_segment("route", Vector3(-20, 0, 30), Vector3(-60, 0, 70))
	_check(r4.ok and tr.network.degree(int(r4.start_node)) == 3, "raccord au milieu d'une route (T)")
	var rr := tr.build_segment("rail", Vector3(60, 0, -20), Vector3(340, 0, -20))
	_check(rr.ok and float(rr.tunnel_len) > 0.0, "voie ferrée avec tunnel")
	var rail2 := tr.build_segment("rail", Vector3(-5, 0, -40), Vector3(60, 0, -20))
	_check(rail2.ok and int(rail2.end_node) == int(rr.start_node), "rail prolongé")
	var rail_x := tr.build_segment("rail", Vector3(-40, 0, -80), Vector3(-40, 0, 20))
	_check(rail_x.ok and int(rail_x.junctions) == 0, "rail qui traverse une route : passage à niveau sans carrefour")
	var p1 := tr.build_segment("chemin", Vector3(-30, 0, -50), Vector3(-30, 0, 50))
	_check(p1.ok, "chemin piéton")
	var w1 := tr.build_segment("voie_eau", Vector3(-420, 0, -80), Vector3(-380, 0, 120))
	_check(w1.ok, "voie navigable")
	var curve_path := TransportSystem.make_path(Vector2(60, 60), Vector2(120, 120), Vector2(120, 60), Vector2.ZERO, true)
	var cv := tr.build_path("rue", {}, curve_path)
	_check(cv.ok and tr.network.edges[cv.edges[0]].pts.size() > 30, "poser une rue en courbe")
	var talus := tr.build_segment("rue", Vector3(-110, 0, -80), Vector3(-110, 0, -30))
	var core := RoutePlanner.footprint(TransportTypes.width_of("rue", {}), talus.pts, talus.st)
	_check(talus.ok and int(talus.earthworks) > core.size(), "talus en pente douce de part et d'autre (%d cases, dont %d sous la rue)" % [talus.get("earthworks", 0), core.size()])
	_check(world.modifications.size() > 50, "remblais et déblais sous les voies (%d cases)" % world.modifications.size())

	await process_frame
	_check(tr.view.edge_mesh_count() == tr.network.edges.size(), "un maillage par tronçon (%d)" % tr.view.edge_mesh_count())

	print("Catalogue de véhicules :")
	var n_types := 0
	var all_ok := true
	var era_ids: Array = Styles.ERAS.map(func(e: Dictionary) -> String: return e.id)
	var region_ids: Array = Styles.REGIONS.map(func(r: Dictionary) -> String: return r.id)
	for id in VehicleCatalog.TYPES:
		var vt := VehicleCatalog.get_type(id)
		n_types += 1
		var m := VehicleCatalog.build_mesh(id)
		if m.get_surface_count() == 0 or not era_ids.has(vt.era) or not region_ids.has(vt.region) or VehicleCatalog.category(vt.cat).is_empty():
			all_ok = false
			push_error("véhicule incomplet : " + id)
		for wid in vt.get("consist", []):
			if VehicleCatalog.get_type(wid).is_empty():
				all_ok = false
				push_error("voiture attelée inconnue : %s dans %s" % [wid, id])
	_check(all_ok and n_types >= 100, "%d modèles, chacun avec maillage, époque, région et catégorie" % n_types)
	for vc in VehicleCatalog.CATEGORIES:
		_check(VehicleCatalog.ids_in(vc.id).size() >= 4, "catégorie %s : %d modèles" % [vc.name, VehicleCatalog.ids_in(vc.id).size()])
	for cls in TransportTypes.CLASSES:
		_check(not VehicleCatalog.for_track(cls).is_empty(), "des véhicules pour la classe %s (%d)" % [cls, VehicleCatalog.for_track(cls).size()])
	_check(VehicleCatalog.for_track("tram").has("tram_moderne") and not VehicleCatalog.for_track("tram").has("tgv"), "les tramways vont sur les voies de tram, pas les TGV")
	_check(not VehicleCatalog.for_track("canal").has("croisiere") and VehicleCatalog.for_track("chenal").has("croisiere"), "les grands navires restent dans les chenaux")
	var old_ids := VehicleCatalog.for_track("departementale", "classique", "europe")
	var only_old := not old_ids.is_empty()
	for id in old_ids:
		only_old = only_old and VehicleCatalog.get_type(id).era == "classique"
	_check(only_old, "filtre époque et région (%d modèles européens d'avant 1945)" % old_ids.size())

	print("Véhicules :")
	tr.traffic.clear()
	for i in 6:
		tr.traffic.spawn(TransportTypes.Mode.ROAD)
	tr.traffic.spawn(TransportTypes.Mode.RAIL)
	tr.traffic.spawn(TransportTypes.Mode.PATH)
	tr.traffic.spawn(TransportTypes.Mode.WATER)
	_check(tr.traffic.count_mode(TransportTypes.Mode.ROAD) == 6, "6 voitures sur les routes")
	_check(tr.traffic.count_mode(TransportTypes.Mode.RAIL) == 1, "un train sur le rail")
	_check(tr.traffic.count_mode(TransportTypes.Mode.WATER) == 1, "un bateau sur l'eau")
	var car: Dictionary = tr.traffic.vehicles[0]
	_check(String(car.model) != "" and VehicleCatalog.get_type(car.model).mode == TransportTypes.Mode.ROAD, "modèle routier tiré du catalogue (%s)" % car.model)
	var train: Dictionary = {}
	for v in tr.traffic.vehicles:
		if int(v.mode) == TransportTypes.Mode.RAIL:
			train = v
	_check(not train.is_empty() and (train.wagons as Array).size() == (VehicleCatalog.get_type(train.model).get("consist", []) as Array).size(), "le train tire ses voitures (%s)" % train.get("model", "?"))
	var before: Vector3 = (car.body as Node3D).position
	tr.traffic.enabled = false
	for i in 20:
		tr.traffic.step(0.1)
	var after: Vector3 = (car.body as Node3D).position
	_check(before.distance_to(after) > 4.0, "un véhicule avance (%.1f m en 2 s)" % before.distance_to(after))
	var on_road := false
	for id in tr.network.edges:
		if TransportTypes.mode_of(tr.network.edges[id].t) == TransportTypes.Mode.ROAD:
			if float(tr.network.nearest_on_edge(id, after).dist) < tr.network.half_width(id):
				on_road = true
	_check(on_road, "la voiture reste sur la chaussée")
	for i in 600:
		tr.traffic.step(0.1)
	_check(tr.traffic.vehicles.size() >= 8, "les véhicules repartent vers de nouvelles destinations (%d)" % tr.traffic.vehicles.size())
	tr.traffic.set_filters("classique", "")
	for i in 5:
		tr.traffic.spawn(TransportTypes.Mode.ROAD)
	var all_classic := tr.traffic.vehicles.size() == 5
	for v in tr.traffic.vehicles:
		all_classic = all_classic and VehicleCatalog.get_type(v.model).era == "classique"
	_check(all_classic, "filtre de la circulation : 5 véhicules de 1800-1945")
	tr.traffic.set_filters("", "")
	tr.traffic.enabled = true

	print("Stations et lignes :")
	tr.traffic.clear()
	var st := tr.stations
	var bus1 := st.place("arret_bus", Vector3(-20, 0, -30))
	var bus2 := st.place("arret_bus", Vector3(-20, 0, 50))
	_check(bus1.ok and bus2.ok, "deux arrêts de bus posés sur la route")
	_check(st.stations[bus1.id].node >= 0 and tr.network.degree(st.stations[bus1.id].node) == 2, "l'arrêt coupe la route en deux tronçons")
	var too_close := st.place("arret_bus", Vector3(-20, 0, -24))
	_check(not too_close.ok, "refus d'un arrêt trop près d'un autre (« %s »)" % too_close.get("reason", ""))
	var bad_tram := st.place("arret_tram", Vector3(150, 0, -20))
	_check(not bad_tram.ok and String(bad_tram.reason).contains("tram"), "pas d'arrêt de tram sur une ligne classique (« %s »)" % bad_tram.get("reason", ""))
	var g1 := st.place("gare", Vector3(80, 0, -20))
	var g2 := st.place("gare", Vector3(320, 0, -20))
	_check(g1.ok and g2.ok, "deux gares sur la voie ferrée (%s / %s)" % [g1.get("reason", "ok"), g2.get("reason", "ok")])
	var port1 := st.place("port", Vector3(-418, 0, -60))
	var port2 := st.place("port", Vector3(-383, 0, 100))
	_check(port1.ok and port2.ok, "deux ports sur la voie navigable (%s / %s)" % [port1.get("reason", "ok"), port2.get("reason", "ok")])
	var on_hill := st.check_air("aeroport", Vector3(200, 0, 0), 0.0)
	_check(not on_hill.ok, "pas d'aéroport sur la colline (« %s »)" % on_hill.reason)
	for i in 240:
		if not String(st.check_air("aeroport", Vector3(420, 0, 650), 0.0).reason).contains("chargement") \
				and not String(st.check_air("heliport", Vector3(10, 0, 250), 0.0).reason).contains("chargement"):
			break
		await process_frame
	var heli := st.place("heliport", Vector3(10, 0, 250))
	var apt := st.place("aeroport", Vector3(420, 0, 650), 0.0)
	_check(heli.ok and apt.ok, "héliport et aéroport posés (%s / %s)" % [heli.get("reason", "ok"), apt.get("reason", "ok")])
	_check(tr.is_cell_occupied(Vector2i(420, 650)) and tr.is_cell_occupied(Vector2i(620, 650)) and not tr.is_cell_occupied(Vector2i(700, 650)), "piste et installations réservées")
	_check((tr.is_cell_occupied(Vector2i(-16, -30)) and world.tree_blocker.call(Vector2i(-16, -30))) or (tr.is_cell_occupied(Vector2i(-24, -30)) and world.tree_blocker.call(Vector2i(-24, -30))), "quai de l'arrêt de bus réservé")
	_check(absf(world.cell_height(Vector2i(420, 300)) - float(st.stations[apt.id].pos.y)) < 0.01, "piste aplanie")
	var bl := st.create_line([bus1.id, bus2.id], "", 2)
	_check(bl.ok and VehicleCatalog.get_type(st.lines[bl.id].model).cat == "bus", "ligne de bus (%s)" % st.lines.get(bl.get("id", -1), {}).get("model", bl.get("reason", "")))
	var tl := st.create_line([g1.id, g2.id], "vapeur_pacific", 1)
	var bt := st.create_line([port1.id, port2.id], "bateau_bus", 1)
	_check(tl.ok and bt.ok, "ligne de train et ligne de bateau")
	var mixed := st.create_line([bus1.id, g1.id])
	_check(not mixed.ok, "refus d'une ligne qui mélange bus et train")
	var al := st.create_line([heli.id, apt.id])
	_check(al.ok and String(VehicleCatalog.get_type(st.lines[al.id].model).kind) in ["helico", "multirotor", "ballon"], "ligne aérienne depuis un héliport : hélicoptère (%s)" % st.lines.get(al.get("id", -1), {}).get("model", al.get("reason", "")))
	var line_vehicles := 0
	for v in tr.traffic.vehicles:
		if v.has("line"):
			line_vehicles += 1
	_check(line_vehicles == 6, "6 véhicules de ligne en service : 2 bus, 1 train, 1 bateau, 2 hélicoptères (%d)" % line_vehicles)
	st.set_line(bl.id, "imperiale", 3)
	var buses := 0
	var all_imp := true
	for v in tr.traffic.vehicles:
		if v.has("line") and int(v.line) == int(bl.id):
			buses += 1
			all_imp = all_imp and v.model == "imperiale"
	_check(buses == 3 and all_imp, "changer le modèle et le nombre : 3 bus à impériale")
	var bus_v: Dictionary = {}
	var air_v: Dictionary = {}
	for v in tr.traffic.vehicles:
		if v.has("line") and int(v.line) == int(bl.id) and bus_v.is_empty():
			bus_v = v
		if int(v.mode) == TransportTypes.Mode.AIR:
			air_v = v
	var max_alt := 0.0
	var dwelled := false
	var bus_start: Vector3 = (bus_v.body as Node3D).position
	var bus_far := 0.0
	tr.traffic.enabled = false
	for i in 900:
		tr.traffic.step(0.1)
		max_alt = maxf(max_alt, (air_v.body as Node3D).position.y - 20.0)
		dwelled = dwelled or float(bus_v.get("dwell", 0.0)) > 1.0
		bus_far = maxf(bus_far, (bus_v.body as Node3D).position.distance_to(bus_start))
	tr.traffic.enabled = true
	_check(max_alt > 100.0, "l'hélicoptère décolle et vole (%d m)" % roundi(max_alt))
	_check(bus_far > 40.0 and dwelled, "le bus roule d'arrêt en arrêt et marque l'arrêt (%d m)" % roundi(bus_far))
	var n_lines := st.lines.size()
	st.remove_station(port1.id)
	_check(st.lines.size() == n_lines - 1, "supprimer un port supprime sa ligne devenue inutile")
	var n_stations := st.stations.size()

	print("Souris :")
	var cam: Camera3D = scene.get_node("CameraRig/Camera3D")
	var n_edges := tr.network.edges.size()
	root.size = Vector2i(1600, 900)
	var rig0 = scene.get_node("CameraRig")
	rig0.position = Vector3(100, rig0.position.y, 110)
	for i in 10:
		await process_frame
	tr.set_build("route")
	tr.message.connect(func(t: String) -> void: print("      message : ", t))
	var vp := root.get_visible_rect().size
	for pos in [vp * Vector2(0.45, 0.5), vp * Vector2(0.55, 0.62)]:
		var mv := InputEventMouseMotion.new()
		mv.position = pos
		root.push_input(mv)
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = pos
		click.pressed = true
		root.push_input(click)
		click = click.duplicate()
		click.pressed = false
		root.push_input(click)
		await process_frame
	_check(tr.network.edges.size() > n_edges, "deux clics posent une route (%d -> %d tronçons)" % [n_edges, tr.network.edges.size()])
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	root.push_input(esc)
	_check(tr._start.is_empty(), "Échap arrête le tracé")
	tr.set_inactive()
	if cam == null:
		ok = false

	print("Carrefours :")
	await _junction_tests()
	var gx1 := tr.build_segment("route", Vector3(60, 0, 300), Vector3(240, 0, 300))
	var gx2 := tr.build_segment("route", Vector3(150, 0, 210), Vector3(150, 0, 390))
	var gnode := -1
	for id in tr.network.nodes:
		if tr.network.node_pos(id).distance_to(Vector3(150, tr.network.node_pos(id).y, 300)) < 1.0:
			gnode = id
	_check(gx1.ok and gx2.ok and gnode >= 0 and tr.network.degree(gnode) == 4, "croisement de deux départementales")
	var gres := tr.make_roundabout(gnode)
	var ring := 0
	var entries := 0
	for id in tr.network.edges:
		if tr.network.edges[id].t == "giratoire":
			ring += 1
	for n in gres.get("nodes", []):
		if tr.junctions.kind(n) == "giratoire":
			entries += 1
	_check(gres.ok and ring == 4 and entries == 4 and not tr.network.nodes.has(gnode), "giratoire de %d m de rayon : 4 arcs, 4 entrées en cédez-le-passage" % roundi(gres.get("radius", 0)))
	_check(tr.roundabouts.size() == 1, "îlot central")
	var west := -1
	var north := -1
	for id in tr.network.nodes:
		var q := tr.network.node_pos(id)
		if q.distance_to(Vector3(60, q.y, 300)) < 1.0:
			west = id
		if q.distance_to(Vector3(150, q.y, 210)) < 1.0:
			north = id
	var forward_only := true
	var used_ring := 0
	for pair in [[west, north], [north, west]]:
		var cur: int = pair[0]
		for eid in tr.network.find_route(pair[0], pair[1]):
			var e: Dictionary = tr.network.edges[eid]
			if e.t == "giratoire":
				used_ring += 1
				forward_only = forward_only and e.a == cur
			cur = tr.network.other_end(eid, cur)
	_check(west >= 0 and north >= 0 and used_ring >= 4 and forward_only, "on tourne dans le bon sens (%d arcs empruntés à l'aller et au retour)" % used_ring)
	_check(not tr.make_roundabout(gres.nodes[0]).ok, "pas de giratoire sur un giratoire")
	tr.traffic.enabled = false
	tr.traffic.clear()
	var wrong := 0
	var on_ring := {}
	for i in 1200:
		if tr.traffic.vehicles.size() < 30:
			tr.traffic.spawn(TransportTypes.Mode.ROAD)
		tr.traffic.step(0.1)
		for v in tr.traffic.vehicles:
			if int(v.mode) != TransportTypes.Mode.ROAD or int(v.leg) >= (v.route as Array).size():
				continue
			var e: Dictionary = tr.network.edges.get(v.route[v.leg], {})
			if e.get("t", "") == "giratoire":
				on_ring[int(v.uid)] = true
				if int(v.node) != int(e.a):
					wrong += 1
	_check(on_ring.size() >= 3 and wrong == 0, "la circulation tourne dans le giratoire (%d véhicules, %d à contresens)" % [on_ring.size(), wrong])
	tr.traffic.clear()
	var pk := tr.stations.place("parking", Vector3(92, 0, 300))
	_check(pk.ok and tr.traffic.parkings.size() == 1 and (tr.traffic.parkings.values()[0].spots as Array).size() == 26, "parking de 26 places (%s)" % pk.get("reason", "ok"))
	_check(tr.is_cell_occupied(Vector2i(92, 300 - 12)) or tr.is_cell_occupied(Vector2i(92, 300 + 12)), "emprise du parking réservée")
	_check(not tr.stations.create_line([pk.get("id", -1), pk.get("id", -1)]).ok, "pas de ligne vers un parking")
	var max_parked := 0
	var left := 0
	var twice := 0
	var was_parked := {}
	for i in 3000:
		if tr.traffic.vehicles.size() < 40:
			tr.traffic.spawn(TransportTypes.Mode.ROAD)
		tr.traffic.step(0.1)
		max_parked = maxi(max_parked, tr.traffic.parked_count())
		var seen_spot := {}
		for v in tr.traffic.vehicles:
			var uid := int(v.get("uid", 0))
			if v.get("parked", false):
				was_parked[uid] = true
				if seen_spot.has(int(v.spot)):
					twice += 1
				seen_spot[int(v.spot)] = true
			elif was_parked.has(uid):
				was_parked.erase(uid)
				left += 1
	_check(max_parked >= 4 and twice == 0, "des voitures se garent (jusqu'à %d à la fois, une par place)" % max_parked)
	_check(left >= 2, "et repartent (%d départs)" % left)
	tr.traffic.clear()
	tr.traffic.enabled = true

	print("Démolition et sauvegarde :")
	var edges_before := tr.network.edges.size()
	tr.demolish(int(p1.edges[0]))
	_check(tr.network.edges.size() == edges_before - 1, "démolir un tronçon")
	var mods := world.modifications.size()
	_check(world.save_world({"transport": tr.to_dict()}), "sauvegarde")
	world.set_origin(45.8326, 6.8652)
	_check(tr.network.edges.is_empty(), "changer de lieu repart d'un réseau vierge")
	_check(world.load_world(), "chargement")
	tr.from_dict(world.loaded_data.get("transport", {}))
	_check(tr.network.edges.size() == edges_before - 1 and world.modifications.size() == mods, "réseau et terrassement restaurés")
	_check(tr.roundabouts.size() == 1 and tr.junctions.kind(gres.nodes[0]) == "giratoire", "giratoire restauré")
	_check(tr.stations.stations.size() == n_stations + 1 and tr.stations.lines.size() == n_lines - 1, "stations et lignes restaurées (%d stations, %d lignes)" % [tr.stations.stations.size(), tr.stations.lines.size()])
	_check(tr.traffic.parkings.size() == 1, "parking restauré")

	var place := ""
	for i in args.size():
		if args[i] == "--place" and i + 1 < args.size():
			place = args[i + 1]
	if place != "":
		# Démonstration sur le vrai relief (réseau nécessaire).
		var ll: Vector2 = Geo.parse_lat_lon(place)
		world.tiles.offline_generator = Callable()
		world.set_origin(ll.x, ll.y)
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 60_000:
			await process_frame
			if world.tiles.pending_count() == 0 and world.chunks.size() > 40:
				break
		var demo := [["route", -150, -60, 0, -60], ["route", 0, -60, 150, -40], ["route", 0, -60, 10, 90],
			["route", -140, 60, 10, 90], ["route", 10, 90, 160, 80], ["rail", -250, 20, 250, 0],
			["chemin", -60, -120, -60, 140], ["voie_eau", -200, -150, 200, -150]]
		for d in demo:
			var res := tr.build_segment(d[0], Vector3(d[1], 0, d[2]), Vector3(d[3], 0, d[4]))
			print("  démo %s : %s" % [d[0], tr._describe(res, true) if res.ok else res.reason])
	elif shot != "":
		world.tiles.offline_generator = _fake_tile
		tr.build_segment("route", Vector3(-30, 0, -100), Vector3(-190, 0, -100))
		tr.build_segment("route", Vector3(-30, 0, -100), Vector3(-20, 0, -60))
		tr.build_segment("chemin", Vector3(-35, 0, 60), Vector3(-35, 0, -100))
		tr.build_segment("chemin", Vector3(-35, 0, 60), Vector3(-120, 0, 60))
		# Vitrine : avenue 2 × 2 voies, rue en courbe, départementale, piste cyclable, tramway.
		var demo2 := [
			tr.build_segment("avenue", Vector3(30, 0, 150), Vector3(210, 0, 150), {"lanes": 2}),
			tr.build_path("rue", {}, TransportSystem.make_path(Vector2(140, 150), Vector2(200, 95), Vector2(140, 95), Vector2.ZERO, true)),
			tr.build_segment("departementale", Vector3(80, 0, 95), Vector3(80, 0, 230)),
			tr.build_segment("piste_cyclable", Vector3(30, 0, 175), Vector3(210, 0, 175)),
			tr.build_segment("tram", Vector3(30, 0, 195), Vector3(210, 0, 195)),
			tr.build_segment("autoroute", Vector3(30, 0, 260), Vector3(260, 0, 260), {"lanes": 3}),
		]
		for d in demo2:
			print("  vitrine : ", tr._describe(d, true) if d.ok else d.reason)
		# Arrêts et lignes de la vitrine.
		var sv := tr.stations
		var ta := sv.place("arret_tram", Vector3(60, 0, 195))
		var tb := sv.place("arret_tram", Vector3(180, 0, 195))
		var ba := sv.place("arret_bus", Vector3(50, 0, 150))
		var bb := sv.place("arret_bus", Vector3(195, 0, 150))
		print("  stations vitrine : ", [ta.get("reason", "ok"), tb.get("reason", "ok"), ba.get("reason", "ok"), bb.get("reason", "ok")])
		sv.create_line([ta.id, tb.id], "tram_moderne", 1)
		sv.create_line([ba.id, bb.id], "imperiale", 2)
		tr.traffic.enabled = false
		for i in 1200:
			if tr.traffic.count_mode(TransportTypes.Mode.ROAD) < 50:
				tr.traffic.spawn(TransportTypes.Mode.ROAD)
			tr.traffic.step(0.1)
		tr.traffic.enabled = true
	if shot != "":
		for i in 60:
			await process_frame
		var rig = scene.get_node("CameraRig")
		var cam_args := [-10.0, 0.0, 150.0, 35.0]
		for i in args.size():
			if args[i] == "--cam" and i + 1 < args.size():
				cam_args = Array(args[i + 1].split(",")).map(func(x: String) -> float: return x.to_float())
		rig.position = Vector3(cam_args[0], 20, cam_args[1])
		rig._distance = cam_args[2]
		rig._target_distance = cam_args[2]
		rig.rotation_degrees.y = cam_args[3]
		for i in 90:
			await process_frame
		var im := root.get_viewport().get_texture().get_image()
		im.save_png(shot)
		print("Capture : ", shot)

	print("TRANSPORT TEST OK" if ok else "TRANSPORT TEST ÉCHEC")
	quit(0 if ok else 1)


## Carrefours sur un réseau synthétique : régimes, feux, files d'attente.
func _junction_tests() -> void:
	var net := TransportNetwork.new()
	var M := TransportTypes.Mode.ROAD
	var c := net.add_node(Vector3(0, 0, 0), M)
	var arms: Array[int] = []
	for d in [Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, 0, -1)]:
		var n := net.add_node(d * 150.0, M)
		arms.append(net.add_edge(c, n, "avenue", _line(Vector3.ZERO, d * 150.0), _flat(51)))
	# Une rue en T sur la branche est (priorité : cédez-le-passage sur la rue).
	var t_node := net.split_edge(arms[0], 90.0)
	var side := net.add_node(Vector3(90, 0, -80), M)
	net.add_edge(t_node, side, "rue", _line(net.node_pos(t_node), Vector3(90, 0, -80)), _flat(51))
	# Un carrefour de rues (priorité à droite) au bout de la rue.
	var s_end := side
	for d in [Vector3(60, 0, 0), Vector3(-60, 0, 0)]:
		var q: Vector3 = net.node_pos(s_end) + d
		net.add_edge(s_end, net.add_node(q, M), "rue", _line(net.node_pos(s_end), q), _flat(51))
	var holder := Node3D.new()
	root.add_child(holder)
	var jc := JunctionControl.new()
	holder.add_child(jc)
	jc.setup(net)
	var tf := Traffic.new()
	holder.add_child(tf)
	tf.setup(net)
	tf.junctions = jc
	tf.enabled = false
	_check(jc.kind(c) == "feux", "feux tricolores au croisement de deux avenues")
	_check(jc.kind(t_node) == "cedez", "cédez-le-passage pour la rue qui débouche sur l'avenue")
	_check(jc.kind(s_end) == "droite", "priorité à droite entre rues")
	var cross_arms: Array = net.adjacency[c]
	var opposite_same := true
	var conflict := false
	var saw := {JunctionControl.VERT: false, JunctionControl.ORANGE: false, JunctionControl.RED: false}
	for i in 400:
		jc.time = i * 0.25
		var l := []
		for eid in cross_arms:
			l.append(jc.light(c, eid))
			saw[l[l.size() - 1]] = true
		var dirs := []
		for eid in cross_arms:
			dirs.append(net.leave_dir(eid, c))
		for a in cross_arms.size():
			for b in range(a + 1, cross_arms.size()):
				var aligned := absf((dirs[a] as Vector3).dot(dirs[b])) > 0.7
				if aligned and l[a] != l[b]:
					opposite_same = false
				if not aligned and l[a] != JunctionControl.RED and l[b] != JunctionControl.RED:
					conflict = true
	_check(opposite_same and not conflict and saw[JunctionControl.ORANGE], "feux : deux phases, jamais de vert croisé, orange entre les deux")
	var heads := 0
	for ch in jc.get_children():
		heads += ch.get_child_count()
	_check(heads > 20, "feux, panneaux et lignes d'arrêt posés (%d éléments)" % heads)
	jc.time = 0.0
	for i in 60:
		tf.spawn(M)
	var crossed := 0
	var waited := 0
	var overlap := 0
	var last_node := {}
	for step_i in 1500:
		tf.step(0.1)
		for v in tf.vehicles:
			var uid := int(v.uid)
			if last_node.has(uid) and int(last_node[uid]) != int(v.node) and int(v.node) == c:
				crossed += 1
			last_node[uid] = v.node
			if float(v.speed) < 0.05 and float(v.get("wait", 0.0)) > 2.0:
				waited += 1
		if step_i % 10 == 0:
			tf._build_index()
			for k in tf._index:
				var q: Array = tf._index[k]
				for a in q.size():
					for b in q.size():
						if a == b:
							continue
						var va: Dictionary = q[a]
						var vb: Dictionary = q[b]
						var gap := float(vb.s) - float(va.s)
						if gap > 0.0 and gap < float(va.half) + float(vb.rear) - 0.5:
							overlap += 1
		if tf.vehicles.size() < 40:
			tf.spawn(M)
	_check(crossed > 25, "la circulation traverse le carrefour à feux (%d passages en 150 s)" % crossed)
	_check(waited > 50, "les véhicules s'arrêtent aux feux et aux priorités")
	_check(overlap == 0, "les véhicules gardent leurs distances dans les files (%d chevauchements)" % overlap)
	jc.cycle(c)
	_check(jc.cycle(c) == "stop" and jc.kind(c) == "stop", "l'outil Carrefour impose un stop")
	var saved := jc.to_dict()
	jc.clear()
	_check(jc.kind(c) == "feux", "retour au régime automatique")
	jc.from_dict(saved)
	_check(jc.kind(c) == "stop", "régime imposé sauvegardé")
	tf.clear()
	holder.queue_free()
	await process_frame


static func _p(t: String, x0: float, z0: float, x1: float, z1: float, g: Callable) -> Dictionary:
	return RoutePlanner.plan(t, PackedVector2Array([Vector2(x0, z0), Vector2(x1, z1)]), NAN, NAN, g)


static func _line(a: Vector3, b: Vector3) -> PackedVector3Array:
	var p := PackedVector3Array()
	for i in 51:
		p.append(a.lerp(b, i / 50.0))
	return p


static func _flat(n: int) -> PackedByteArray:
	var s := PackedByteArray()
	s.resize(n)
	return s
