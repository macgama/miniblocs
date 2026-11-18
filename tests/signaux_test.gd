extends SceneTree
## Test de la signalisation ferroviaire et des horaires des lignes :
## voie unique (pas de face-à-face, pas d'interblocage), croisement dans un
## évitement à double voie et dans les gares, cantons de la double voie selon
## l'époque, aiguillages, signaux le long des voies.
## Usage : godot --headless --path . --script res://tests/signaux_test.gd

var ok := true


func _initialize() -> void:
	_run.call_deferred()


func _check(cond: bool, what: String) -> void:
	if not cond:
		push_error("ÉCHEC : " + what)
		ok = false
	else:
		print("  ok  ", what)


static func _pts(a: Vector3, b: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array()
	var n := maxi(2, ceili(a.distance_to(b) / 10.0) + 1)
	for i in n:
		out.append(a.lerp(b, float(i) / float(n - 1)))
	return out


static func _st(n: int) -> PackedByteArray:
	var s := PackedByteArray()
	s.resize(n)
	s.fill(0)
	return s


## Voie ferrée de a à b (nœuds existants), tracks voies.
static func _rail(net: TransportNetwork, a: int, b: int, tracks := 1, cls := "train") -> int:
	var p := _pts(net.node_pos(a), net.node_pos(b))
	return net.add_edge(a, b, cls, p, _st(p.size()), {"tracks": tracks})


## Mise en place : un Traffic seul, sans circulation d'ambiance.
func _traffic(net: TransportNetwork, gares: Array) -> Traffic:
	var tr := Traffic.new()
	root.add_child(tr)
	tr.setup(net)
	tr.set_process(false)
	tr.demand = func() -> Dictionary: return {}
	var g := {}
	for n in gares:
		g[int(n)] = true
	tr.signaux.quais = func(nid: int) -> int: return Signalisation.QUAIS_GARE if g.has(nid) else 0
	return tr


## Trains de ligne présents sur un tronçon, avec leur sens (true : de a vers b).
static func _sur(tr: Traffic, eid: int) -> Array:
	var out: Array = []
	for v in tr.vehicles:
		var r: Array[int] = v.route
		if v.has("line") and int(v.leg) < r.size() and r[v.leg] == eid and float(v.get("dwell", 0.0)) <= 0.0 and float(v.s) > 1.0:
			out.append(int(tr.network.edges[eid].a) == int(v.node))
	return out


func _run() -> void:
	print("Époques de la signalisation :")
	_check(String(Signalisation.epoque_pour(1835).id) == "disque", "1835 : disques et garde-voies")
	_check(String(Signalisation.epoque_pour(1900).id) == "semaphore", "1900 : sémaphores")
	_check(String(Signalisation.epoque_pour(1960).id) == "bal", "1960 : block automatique lumineux")
	var sg := Signalisation.new()
	sg.annee_forcee = 1990
	_check(sg.style("lgv") == "tvm" and sg.style("train") == "bal", "1990 : TVM sur LGV, BAL ailleurs")
	sg.annee_forcee = 1975
	_check(sg.style("lgv") == "bal", "1975 : pas encore de TVM")

	print("Voie unique entre deux gares :")
	var net := TransportNetwork.new()
	var A := net.add_node(Vector3(0, 0, 0), TransportTypes.Mode.RAIL)
	var M := net.add_node(Vector3(700, 0, 0), TransportTypes.Mode.RAIL)
	var B := net.add_node(Vector3(1400, 0, 0), TransportTypes.Mode.RAIL)
	var e1 := _rail(net, A, M)
	var e2 := _rail(net, M, B)
	var tr := _traffic(net, [A, B])
	var stops: Array[int] = [A, B]
	_check(tr.add_line_vehicle(1, "regional", stops, 0, -1.0) and tr.add_line_vehicle(1, "regional", stops, 1, -1.0), "deux trains, un à chaque gare")
	var arrivals := [0]
	tr.line_stop.connect(func(_v: Dictionary) -> void: arrivals[0] += 1)
	var face := 0
	for i in 6000:
		tr.step(0.1)
		for eid in [e1, e2]:
			var dirs := _sur(tr, eid)
			if dirs.has(true) and dirs.has(false):
				face += 1
	_check(face == 0, "jamais deux trains face à face sur la voie unique")
	_check(int(arrivals[0]) >= 8, "les trains se succèdent sans se bloquer (%d arrivées en 10 min)" % int(arrivals[0]))
	_check(tr.signaux.nb_interblocages == 0, "aucun interblocage")
	tr.queue_free()

	print("Croisement dans un évitement à double voie :")
	var net2 := TransportNetwork.new()
	var A2 := net2.add_node(Vector3(0, 0, 0), TransportTypes.Mode.RAIL)
	var X2 := net2.add_node(Vector3(900, 0, 0), TransportTypes.Mode.RAIL)
	var Y2 := net2.add_node(Vector3(1500, 0, 0), TransportTypes.Mode.RAIL)
	var B2 := net2.add_node(Vector3(2400, 0, 0), TransportTypes.Mode.RAIL)
	var s1 := _rail(net2, A2, X2)
	var ev := _rail(net2, X2, Y2, 2)
	var s2 := _rail(net2, Y2, B2)
	var tr2 := _traffic(net2, [A2, B2])
	var stops2: Array[int] = [A2, B2]
	tr2.add_line_vehicle(1, "regional", stops2, 0, -1.0)
	tr2.add_line_vehicle(1, "regional", stops2, 1, -1.0)
	var arr2 := [0]
	tr2.line_stop.connect(func(_v: Dictionary) -> void: arr2[0] += 1)
	var croise := 0
	var face2 := 0
	for i in 6000:
		tr2.step(0.1)
		for eid in [s1, s2]:
			var d := _sur(tr2, eid)
			if d.has(true) and d.has(false):
				face2 += 1
		var de := _sur(tr2, ev)
		if de.has(true) and de.has(false):
			croise += 1
	_check(face2 == 0, "pas de face-à-face sur les voies uniques")
	_check(croise > 0, "les trains se croisent dans l'évitement (%d instants)" % croise)
	_check(int(arr2[0]) >= 8 and tr2.signaux.nb_interblocages == 0, "service régulier, sans interblocage (%d arrivées)" % int(arr2[0]))
	var sigs := tr2.signaux.liste()
	var n_v := 0
	var n_d := 0
	for x in sigs:
		if String(x.k).begins_with("v:"):
			n_v += 1
		else:
			n_d += 1
	_check(n_v == 4 and n_d == 2, "signaux : entrée des deux voies uniques de chaque côté (%d) et des deux voies de l'évitement (%d)" % [n_v, n_d])
	tr2.queue_free()

	print("Cantons de la double voie :")
	var net3 := TransportNetwork.new()
	var A3 := net3.add_node(Vector3(0, 0, 0), TransportTypes.Mode.RAIL)
	var B3 := net3.add_node(Vector3(6000, 0, 0), TransportTypes.Mode.RAIL)
	var d3 := _rail(net3, A3, B3, 2)
	var tr3 := _traffic(net3, [A3, B3])
	tr3.signaux.annee_forcee = 1960
	_check(tr3.signaux.blocs(net3.edges[d3]) == 4, "BAL : 6 km en 4 cantons de 1,5 km")
	tr3.signaux.annee_forcee = 1900
	_check(tr3.signaux.blocs(net3.edges[d3]) == 2, "sémaphores : 2 cantons de 3 km")
	tr3.signaux.annee_forcee = 1850
	_check(tr3.signaux.blocs(net3.edges[d3]) == 1, "1850 : un seul canton de gare à gare")
	tr3.signaux.annee_forcee = 1960
	var stops3: Array[int] = [A3, B3]
	for k in 3:
		tr3.add_line_vehicle(1, "regional", stops3, 0, -1.0 - float(k))
	var min_gap := INF
	var meme_canton := 0
	for i in 3000:
		tr3.step(0.1)
		var pos: Array = []
		for v in tr3.vehicles:
			if int(v.node) == A3 and int(v.leg) == 0 and float(v.get("dwell", 0.0)) <= 0.0 and float(v.s) > 1.0 and float(v.s) < 5990.0:
				pos.append(float(v.s))
		pos.sort()
		for j in pos.size() - 1:
			min_gap = minf(min_gap, float(pos[j + 1]) - float(pos[j]))
			if floori(float(pos[j + 1]) / 1500.0) == floori(float(pos[j]) / 1500.0):
				meme_canton += 1
	_check(meme_canton == 0, "jamais deux trains dans le même canton")
	_check(min_gap < 3000.0 and min_gap > 300.0, "les trains se suivent à un canton d'écart (écart mini %d m)" % roundi(min_gap))
	tr3.queue_free()

	print("Gare de croisement sur une voie unique :")
	var net4 := TransportNetwork.new()
	var A4 := net4.add_node(Vector3(0, 0, 0), TransportTypes.Mode.RAIL)
	var G4 := net4.add_node(Vector3(1200, 0, 0), TransportTypes.Mode.RAIL)
	var B4 := net4.add_node(Vector3(2400, 0, 0), TransportTypes.Mode.RAIL)
	var f1 := _rail(net4, A4, G4)
	var f2 := _rail(net4, G4, B4)
	var tr4 := _traffic(net4, [A4, G4, B4])
	var stops4: Array[int] = [A4, G4, B4]
	tr4.add_line_vehicle(1, "regional", stops4, 0, -1.0)
	tr4.add_line_vehicle(1, "regional", stops4, 2, -1.0)
	var deux_quais := 0
	var face4 := 0
	var arr4 := [0]
	tr4.line_stop.connect(func(_v: Dictionary) -> void: arr4[0] += 1)
	for i in 6000:
		tr4.step(0.1)
		if (tr4.signaux.quais_tenus.get(G4, {}) as Dictionary).size() == 2:
			deux_quais += 1
		for eid in [f1, f2]:
			var d := _sur(tr4, eid)
			if d.has(true) and d.has(false):
				face4 += 1
	_check(face4 == 0 and deux_quais > 0, "les trains se croisent en gare, sur deux voies à quai")
	_check(int(arr4[0]) >= 10 and tr4.signaux.nb_interblocages == 0, "sans interblocage (%d arrivées)" % int(arr4[0]))
	tr4.queue_free()

	print("Aiguillage :")
	var net5 := TransportNetwork.new()
	var A5 := net5.add_node(Vector3(-800, 0, 0), TransportTypes.Mode.RAIL)
	var J5 := net5.add_node(Vector3(0, 0, 0), TransportTypes.Mode.RAIL)
	var B5 := net5.add_node(Vector3(800, 0, 200), TransportTypes.Mode.RAIL)
	var C5 := net5.add_node(Vector3(800, 0, -200), TransportTypes.Mode.RAIL)
	_rail(net5, A5, J5, 2)
	_rail(net5, J5, B5, 2)
	_rail(net5, J5, C5, 2)
	var tr5 := _traffic(net5, [A5, B5, C5])
	var sab: Array[int] = [A5, B5]
	var sac: Array[int] = [A5, C5]
	var scb: Array[int] = [C5, B5]
	tr5.add_line_vehicle(1, "regional", sab, 0, -1.0)
	tr5.add_line_vehicle(2, "regional", sac, 1, -1.0)
	tr5.add_line_vehicle(3, "regional", scb, 0, -1.0)
	var arr5 := [0]
	tr5.line_stop.connect(func(_v: Dictionary) -> void: arr5[0] += 1)
	var double_j := 0
	for i in 6000:
		tr5.step(0.1)
		var t: Dictionary = tr5.signaux.tenus.get("n:%d" % J5, {})
		if not t.is_empty():
			var holders := 0
			for k in tr5.signaux.tenus:
				if String(k) == "n:%d" % J5:
					holders += 1
			double_j = maxi(double_j, holders)
	_check(int(arr5[0]) >= 9 and tr5.signaux.nb_interblocages == 0, "trois lignes se partagent l'aiguillage (%d arrivées, sans interblocage)" % int(arr5[0]))
	tr5.queue_free()

	await _partie()

	print("RÉSULTAT : ", "OK" if ok else "ÉCHEC")
	quit(0 if ok else 1)


func _flat_tile(_t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(40.0)
	return a


## Dans une vraie partie : gares, ligne de train, horaire, évitement, panneau,
## signaux visibles, sauvegarde.
func _partie() -> void:
	print("Dans la partie :")
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
	world.view_radius_override = 900.0
	world.set_origin(48.8584, 2.2945)
	for i in 3000:
		await process_frame
		if i >= 120 and world.missing_chunk_count() == 0 and world._dirty.is_empty() and world._jobs.is_empty():
			break
	amb.set_speed(0)
	bs.unlimited_money = true
	var tr := transport.traffic
	tr.set_process(false)
	var y := world.cell_height(Vector2i(0, 0))
	var r := transport.build_segment("train", Vector3(-800, y, 300), Vector3(800, y, 300), {"tracks": 1})
	_check(r.ok, "voie unique de 1,6 km (%s)" % r.get("reason", "ok"))
	var st := transport.stations
	var g1 := st.place("gare", Vector3(-720, y, 300))
	var g2 := st.place("gare", Vector3(720, y, 300))
	_check(g1.ok and g2.ok, "deux gares")
	_check(st.quais_at(int(st.stations[g1.id].node)) == 2 and st.quais_at(-5) == 0, "deux voies à quai par gare")
	var ev := st.creer_evitement(Vector3(0, y, 300))
	_check(ev.ok and Signalisation.double_voie(transport.network.edges[int(ev.edge)]) and absf(float(ev.len) - StationSystem.EVITEMENT_M) < 5.0,
		"évitement de %d m au milieu de la ligne" % roundi(float(ev.get("len", 0.0))))
	_check(not st.creer_evitement(Vector3(0, y, 300)).ok, "pas d'évitement sur une double voie")
	_check(not st.creer_evitement(Vector3(0, y, -500)).ok, "pas d'évitement hors des voies")
	var ln := st.create_line([g1.id, g2.id], "regional", 2)
	_check(ln.ok, "ligne de train, 2 rames")
	var lid := int(ln.get("id", -1))
	transport.signaux_vue.rebuild()
	_check(transport.signaux_vue.count() >= 6, "%d signaux le long de la ligne" % transport.signaux_vue.count())

	print("Horaire :")
	var hz := st.horaires
	_check(not hz.actif(lid) and hz.resume(lid).begins_with("Sans horaire"), "ligne sans horaire par défaut")
	hz.regler(lid, {"on": true, "cadence": 30, "debut": 6.0, "fin": 22.0})
	var cyc := hz.cycle_s(lid)
	_check(cyc > 60.0 and cyc < 1200.0, "aller-retour %s" % HorairesLignes.duree(cyc))
	_check(hz.besoin(lid) == 1 and hz.en_ligne(lid) == 1, "une rame suffit pour un train toutes les 30 min, l'autre en réserve")
	_check(hz.resume(lid).contains("1 en réserve"), hz.resume(lid))
	hz.regler(lid, {"cadence": 1})
	_check(hz.besoin(lid) > 2 and hz.resume(lid).contains("Il manque"), "toutes les minutes : il manque des rames")
	_check(absf(hz.intervalle_s(lid) - cyc / 2.0) < 1.0, "cadence réelle : aller-retour ÷ 2 rames")
	var wait_info: Dictionary = st.planner._line_info(lid)
	_check(absf(float(wait_info.wait) - cyc / 4.0) < 1.0, "les habitants attendent une demi-cadence")
	hz.regler(lid, {"cadence": 30})
	var f := hz.fiche(lid, 0, 4, 7.2)
	_check(not f.is_empty() and (f.lignes as Array).size() == 2 and (f.lignes[0][1] as Array) == ["07:30", "08:00", "08:30", "09:00"],
		"fiche horaire : départs à %s" % str(f.get("lignes", [[0, []]])[0][1]))
	var arr: String = f.lignes[1][1][0]
	_check(arr > "07:30" and arr < "08:00", "arrivée à l'autre gare à %s" % arr)
	var f2 := hz.fiche(lid, 0, 2, 21.8)
	_check((f2.lignes[0][1] as Array) == ["06:00", "06:30"], "après le dernier train : premiers départs du lendemain")
	var eco := ExploitationLignes.instance
	if eco != null:
		hz.regler(lid, {"on": false})
		var km0 := eco.km_jour(lid)
		hz.regler(lid, {"on": true})
		_check(eco.km_jour(lid) < km0, "service de 6 h à 22 h : moins de km par jour (%d → %d)" % [roundi(km0), roundi(eco.km_jour(lid))])

	print("Nuit et réserve :")
	hz.heure_forcee = 3.0
	st.respawn_all()
	for i in 600:
		tr.step(0.1)
	var rem := hz.remises(lid)
	var moving := 0
	for v in tr.vehicles:
		if v.has("line") and float(v.get("dwell", 0.0)) <= 0.0:
			moving += 1
	_check(moving == 0 and int(rem.nuit) == 2, "à 3 h, les deux rames restent au terminus")
	hz.heure_forcee = 10.0
	var arrivals := [0]
	tr.line_stop.connect(func(_v: Dictionary) -> void: arrivals[0] += 1)
	var en_route := 0
	for i in 3000:
		tr.step(0.1)
		var m := 0
		for v in tr.vehicles:
			if v.has("line") and float(v.get("dwell", 0.0)) <= 0.0:
				m += 1
		en_route = maxi(en_route, m)
	_check(int(arrivals[0]) >= 2 and en_route == 1, "à 10 h, une rame roule, l'autre reste en réserve (%d arrivées)" % int(arrivals[0]))
	var p := hz.ponctualite(lid)
	_check(not p.is_empty() and float(p.ponctualite) > 0.5, "ponctualité mesurée : %d %%" % roundi(float(p.get("ponctualite", 0.0)) * 100.0))
	hz.regler(lid, {"cadence": 1})
	var croise := 0
	for i in 6000:
		tr.step(0.1)
		var both := 0
		for v in tr.vehicles:
			var rt: Array[int] = v.route
			if v.has("line") and int(v.leg) < rt.size() and rt[v.leg] == int(ev.edge) and float(v.get("dwell", 0.0)) <= 0.0:
				both += 1
		if both == 2:
			croise += 1
	_check(croise > 0 and tr.signaux.nb_interblocages == 0, "à la cadence la plus serrée : les deux rames roulent et se croisent dans l'évitement")

	print("Panneau :")
	var panel: StationPanel = scene.transit_panel
	panel.set_open(true)
	panel._h_open[lid] = true
	panel._refresh_lines()
	var labels: Dictionary = panel._horaires.get(lid, {})
	_check(not labels.is_empty() and String((labels.resume as Label).text).begins_with("Un départ toutes les 1 min"), "horaire ouvert : %s" % (labels.resume as Label).text if not labels.is_empty() else "fermé")
	_check(not labels.is_empty() and String((labels.fiche as Label).text).contains("Prochains départs"), "fiche horaire affichée")
	_check(String(panel._sig_label.text).begins_with("Block automatique lumineux"), "signalisation : %s" % panel._sig_label.text)
	panel.set_open(false)

	print("Sauvegarde :")
	var d: Dictionary = JSON.parse_string(JSON.stringify(transport.to_dict()))
	transport.from_dict(d)
	_check(st.lines.has(lid) and hz.actif(lid) and int(hz.horaire(lid).cadence) == 1 and float(hz.horaire(lid).debut) == 6.0, "horaire gardé")
	_check(not hz.ponctualite(lid).is_empty(), "ponctualité gardée")
	var dbl := 0
	for eid in transport.network.edges:
		if Signalisation.double_voie(transport.network.edges[eid]):
			dbl += 1
	_check(dbl == 1, "évitement gardé")
	hz.heure_forcee = -1.0
	scene.queue_free()
	await process_frame
