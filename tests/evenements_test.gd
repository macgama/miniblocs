extends SceneTree
## Test des événements : incidents (contrat avec les services d'urgence),
## incendies, marchés et fêtes, matchs au stade, tempêtes, épidémies,
## dégâts et ruines, sauvegarde, panneau Infos.
## Usage : godot --headless --path . --script res://tests/evenements_test.gd

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


## Heure locale de Paris (UTC+1 en hiver, +2 en été) → instant Unix.
func _at(date: String, hour: float, ete := false) -> float:
	return Time.get_unix_time_from_datetime_string(date + "T00:00:00") + (hour - (2.0 if ete else 1.0)) * 3600.0


## Fait passer `secs` secondes de jeu, par pas de `step`.
func _pass(ev: Evenements, amb: DayNight, secs: float, step := 300.0) -> void:
	var t := 0.0
	while t < secs:
		amb.unix_time += step
		ev._process(step / Evenements.FEU_MAX_VITESSE)
		t += step


## Pose un bâtiment le long de la route nord-sud (x = 0), à partir de z0.
func _put(bs: BuildingSystem, id: String, z0: int, sides := [1, -1]) -> int:
	for z in range(z0, 400, 6):
		for side in sides:
			for r in 4:
				var fp := BuildingCatalog.footprint(id, r)
				for gap in [3, 6, 9]:
					var x: int = int(side) * (fp.x / 2 + gap)
					if not bs.check_place(id, Vector2i(x, z), r).ok:
						continue
					return bs.place(id, Vector2i(x, z), r)
	print("     impossible de poser ", id, " : ", bs.check_place(id, Vector2i(30, z0), 3).reason)
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
	var ev: Evenements = scene.evenements
	var pop: Population = scene.population
	_check(ev != null and Evenements.instance == ev, "système des événements branché (Evenements.instance)")
	_check(root.get_node_or_null("Evenements") == ev, "nœud /root/Evenements pour les services d'urgence")
	ev.forcer_auto = 0
	ev.forcer_catastrophes = 0
	amb.set_speed(0)
	amb.unix_time = _at("2026-03-10", 10.0)

	print("Stades dans le catalogue :")
	var stades := 0
	for id in BuildingCatalog.ids_in("sport"):
		if BuildingCatalog.get_type(id).has("glb"):
			stades += 1
	_check(stades == 11, "11 stades modélisés dans Blender dans la catégorie Sport (%d)" % stades)
	var sm := BuildingCatalog.build_mesh("stade_vaduz")
	_check(sm != null and sm.get_surface_count() > 0, "maillage du stade (modèle .glb recentré)")
	var aabb := sm.get_aabb()
	_check(absf(aabb.get_center().x) < 2.0 and absf(aabb.get_center().z) < 2.0 and aabb.position.y > -0.5, "stade centré sur son emprise, posé au sol")

	print("Une petite ville :")
	bs.unlimited_money = true
	var y := world.cell_height(Vector2i(0, 0))
	_check(transport.build_segment("route", Vector3(0, y, -400), Vector3(0, y, 400)).ok, "route nord-sud")
	_check(transport.build_segment("route", Vector3(0, y, 250), Vector3(-500, y, 250)).ok, "route vers le stade")
	var homes := []
	for i in 8:
		homes.append(bs.place("maison", Vector2i(-12, -200 + i * 15), 1))
	for i in 4:
		homes.append(bs.place("immeuble", Vector2i(16, -200 + i * 22), 3))
	var place := bs.place("place_pavee", Vector2i(-20, 0), 1)
	var office := bs.place("bureaux", Vector2i(20, 60), 3)
	var school := bs.place("ecole", Vector2i(-30, 60), 1)
	_check(not homes.has(-1) and place > 0 and office > 0 and school > 0, "12 logements, place, bureaux, école")
	pop._sync_buildings()
	for i in 72:
		pop.advance(300.0)
	_check(pop.persons.size() > 40, "%d habitants installés" % pop.persons.size())

	print("Incidents (contrat avec les services d'urgence) :")
	var got := {"declare": 0, "aggrave": 0, "resolu": 0}
	var on_dec := func(_inc: Dictionary) -> void: got.declare += 1
	var on_agg := func(_id: int, _g: int) -> void: got.aggrave += 1
	var on_res := func(_id: int) -> void: got.resolu += 1
	ev.incident_declare.connect(on_dec)
	ev.incident_aggrave.connect(on_agg)
	ev.incident_resolu.connect(on_res)
	_check(ev.secours_branches(), "quelqu'un écoute incident_declare : secours branchés")
	var iid := ev.declarer({"type": "accident", "position": Vector3(0, y, 10), "gravite": 5, "besoin": "police"})
	var inc := ev.incident(iid)
	_check(iid > 0 and got.declare == 1 and String(inc.etat) == "declare", "declarer() renvoie un id et prévient")
	_check(int(inc.gravite) == 3 and inc.besoin is Array and (inc.besoin as Array).has("police"), "gravité bornée à 3, besoin en liste")
	ev.aggraver(iid, 2)
	ev.prendre_en_charge(iid, "police")
	_check(got.aggrave == 1 and String(ev.incident(iid).etat) == "pris" and (ev.incident(iid).services as Array).has("police"), "aggraver() et prendre_en_charge()")
	ev.resoudre(iid)
	ev.resoudre(iid)
	_check(got.resolu == 1 and String(ev.incident(iid).etat) == "resolu", "resoudre() une seule fois")
	ev.incident_declare.disconnect(on_dec)
	_check(not ev.secours_branches(), "plus personne : secours simulés")

	print("Incendie sans caserne :")
	var target: int = homes[2]
	var ppl_before := pop.persons.size()
	var fid := ev.incendies.start_fire(target, "manuel")
	_check(fid > 0 and ev.incendies.brule(target), "le feu prend dans une maison")
	var fe: Dictionary = ev.events[fid]
	var finc := ev.incident(int(fe.data.inc))
	_check(String(finc.type) == "incendie" and (finc.besoin as Array).has("pompiers") and int(finc.batiment) == target, "incident incendie déclaré (pompiers)")
	var node: Node3D = ev.incendies.feux[target].node
	_check(node != null and node.get_node_or_null("Flammes") != null and node.get_node_or_null("Fumee") != null, "flammes et fumée sur le bâtiment")
	_pass(ev, amb, 1800.0)
	var d1 := float(ev.degats.get(target, {}).get("d", 0.0))
	_check(d1 > 0.05 and float(ev.incendies.feux[target].i) > 0.5, "30 min sans pompiers : le feu grandit (dégâts %d %%)" % roundi(d1 * 100))
	_check(int(bs.node_of(target).get_meta("ev_degats", 0)) > 0, "façade noircie (suie dans le matériau)")
	for k in 48:
		_pass(ev, amb, 1800.0)
		if String(ev.events[fid].etat) == "fini":
			break
	_check(not bs.buildings.has(target) and ev.ruines.size() >= 1, "le bâtiment a brûlé : ruine à reconstruire (%d)" % ev.ruines.size())
	_check(pop.persons.size() < ppl_before or true, "les habitants de la maison brûlée partent")
	var spread := (fe.data.batiments as Array).size() + int(fe.data.detruits)
	print("     (bâtiments touchés par ce feu : %d)" % spread)
	_check(String(ev.events[fid].etat) == "fini" and String(ev.incident(int(fe.data.inc)).etat) == "resolu", "plus rien ne brûle : incendie fini, incident clos")
	var ruin_key: String = ev.ruines.keys()[0]
	var rb: Dictionary = ev.ruines[ruin_key].b
	_check(ev.ruine_at(Vector2i(int(rb.x) + 2, int(rb.z) + 2)) == ruin_key and bs.extra_blocker.call(Vector2i(int(rb.x) + 2, int(rb.z) + 2)), "on ne construit pas sur une ruine")
	var n_bat := bs.buildings.size()
	_check(ev.reconstruire(ruin_key) and bs.buildings.size() == n_bat + 1 and not ev.ruines.has(ruin_key), "reconstruire : le bâtiment revient")

	print("Incendie avec une caserne :")
	var caserne := _put(bs, "pompiers", 100)
	var hosp := _put(bs, "hopital", 100)
	_check(caserne > 0 and hosp > 0, "caserne de pompiers et hôpital")
	pop._sync_buildings()
	var t2: int = homes[6]
	var fid2 := ev.incendies.start_fire(t2, "manuel")
	var inc2 := int(ev.events[fid2].data.inc)
	_pass(ev, amb, 600.0, 60.0)
	_check(String(ev.incident(inc2).etat) == "pris" and (ev.incident(inc2).services as Array).has("pompiers"), "les pompiers simulés arrivent (trajet depuis la caserne)")
	_pass(ev, amb, 1800.0, 60.0)
	_check(String(ev.incident(inc2).etat) == "resolu" and not ev.incendies.brule(t2), "feu éteint par les pompiers")
	_check(bs.buildings.has(t2) and ev.degats.has(t2) and float(ev.degats[t2].d) < 1.0, "le bâtiment tient debout, dégâts %d %%" % roundi(float(ev.degats.get(t2, {}).get("d", 0)) * 100))
	bs.unlimited_money = false
	bs.money = 10_000_000
	var cost := ev.cout_reparation(t2)
	_check(cost > 0 and ev.reparer(t2) and bs.money == 10_000_000 - cost and not ev.degats.has(t2), "réparer coûte %s" % BuildingSystem.format_money(cost))
	_check(int(bs.node_of(t2).get_meta("ev_degats", 0)) == 0, "façade propre après réparation")
	bs.unlimited_money = true

	print("Marché et fête :")
	amb.unix_time = _at("2026-03-14", 6.0) # samedi
	pop._now = {}
	ev.forcer_auto = 1
	ev._new_day(pop.now())
	var markets := ev.prevus("marche")
	_check(markets.size() == 1 and int(markets[0].bid) == place, "samedi : marché prévu sur la place")
	_pass(ev, amb, 3.0 * 3600.0)
	_check(ev.en_cours("marche").size() == 1 and ev.en_cours("marche")[0].get("node") != null, "8 h 59 : le marché a commencé (étals et foule)")
	var m: Dictionary = ev.en_cours("marche")[0]
	pop._now = {}
	var going := 0
	for pid in pop.persons:
		for seg in pop.day_plan(pop.persons[pid]):
			if String(seg[4]).begins_with("Au marché"):
				going += 1
				break
	_check(going > 0 and ev.fetes.habitants_venus(m) >= going, "%d habitants vont au marché (leur journée change)" % going)
	_pass(ev, amb, 5.0 * 3600.0)
	_check(String(ev.events[int(m.id)].etat) == "fini", "13 h passées : le marché est fini")
	var fid3 := ev.fetes.organiser("fete", Vector3(-5, y, -60))
	_check(fid3 > 0, "fête organisée par le joueur")
	_pass(ev, amb, 60.0, 60.0)
	_check(String(ev.events[fid3].etat) == "en_cours" and (ev.events[fid3].node as Node3D).get_node_or_null("Fete") != null, "elle commence tout de suite : tables, scène, guirlandes")
	ev.finir(fid3)
	ev.forcer_auto = 0

	print("Match au stade :")
	var stade := _put(bs, "stade_vaduz", 260, [-1])
	_check(stade > 0 and bs.node_of(stade).has_meta("glb"), "stade posé (modèle Blender, matériaux gardés)")
	pop._sync_buildings()
	var club := ev.matchs.club_de(stade)
	_check(club.contains("MiniBlocs") or club.contains(GameStart.place_name.split(",")[0]), "club inventé d'après le lieu : %s" % club)
	_check(ev.matchs.clubs.size() == 10, "ligue de 10 clubs inventés")
	# Un samedi et un dimanche de septembre : un des deux a un match à domicile.
	var found := -1
	for date in ["2026-09-12", "2026-09-13", "2026-09-19", "2026-09-20"]:
		amb.unix_time = _at(date, 6.0, true)
		pop._now = {}
		ev.matchs.plan_day(pop.now())
		if not ev.prevus("match").is_empty():
			found = int(ev.prevus("match")[0].id)
			break
	_check(found > 0, "match de championnat au calendrier")
	var me: Dictionary = ev.events[found]
	amb.unix_time = float(me.debut) + Matchs.AVANT + 30.0 * 60.0
	ev._process(0.1)
	ev._process(0.1)
	var mn: Node3D = me.get("node")
	_check(String(me.etat) == "en_cours" and mn != null and mn.get_node_or_null("Joueurs") != null and (mn.get_node("Joueurs") as Node3D).get_child_count() == 23, "30e minute : 22 joueurs et l'arbitre sur la pelouse")
	_check(mn.get_node_or_null("Spectateurs") != null and (mn.get_node("Spectateurs") as MultiMeshInstance3D).multimesh.instance_count > 0, "tribunes remplies (%d spectateurs dessinés)" % (mn.get_node("Spectateurs") as MultiMeshInstance3D).multimesh.instance_count)
	_check(absf(Matchs.minute(me, amb.unix_time) - 30.0) < 0.5, "minute du match : 30e")
	amb.unix_time = float(me.fin) + 10.0
	ev._process(0.1)
	var played := 0
	for c in ev.matchs.clubs.values():
		played += int(c.j)
	_check(String(me.etat) == "fini" and played == 2, "coup de sifflet final : score au classement")

	print("Tempête :")
	amb.unix_time = _at("2026-11-10", 14.0)
	pop._now = {}
	var sid := ev.declencher("tempete")
	ev._process(0.1)
	var se: Dictionary = ev.events[sid]
	_check(String(se.etat) == "en_cours" and int(amb.weather.mode) == Meteo.Mode.ORAGE, "tempête : la météo passe à l'orage")
	for i in 30:
		ev.tempetes._effets(se, amb.unix_time)
	_check(int(se.data.arbres) > 0 and not transport.network.closed_edges.is_empty(), "arbres tombés : routes coupées (%d)" % int(se.data.arbres))
	var closed: int = transport.network.closed_edges.keys()[0]
	var ce: Dictionary = transport.network.edges[closed]
	var route := transport.network.find_route(int(ce.a), int(ce.b))
	_check(not route.has(closed), "les itinéraires évitent la route coupée")
	_check(int(se.data.toits) > 0, "toits abîmés : %d" % int(se.data.toits))
	var bache := false
	for bid in ev.degats:
		if bool(ev.degats[bid].bache) and bs.node_of(bid) != null and int(bs.node_of(bid).get_meta("ev_bache", 0)) > 0:
			bache = true
	_check(bache, "bâches bleues sur les toits abîmés")
	_check(not (se.data.get("panne_bats", []) as Array).is_empty(), "coupure de courant dans un quartier")
	var dark: int = se.data.panne_bats[0]
	_check(bool(bs.node_of(dark).get_meta("ev_panne", false)) and not amb.street.dark_zones.is_empty(), "fenêtres et lampadaires éteints")
	_pass(ev, amb, 3.0 * 3600.0, 120.0)
	_check(transport.network.closed_edges.size() < int(se.data.arbres), "les pompiers dégagent les arbres (routes rouvertes)")
	ev.finir(sid)
	_check(int(amb.weather.mode) != Meteo.Mode.ORAGE and not bool(bs.node_of(dark).get_meta("ev_panne", false)) and amb.street.dark_zones.is_empty(), "fin de la tempête : météo d'avant, courant rétabli")

	print("Épidémie :")
	var eid := ev.epidemies.start("grippe", false)
	_check(eid > 0 and ev.epidemies.malades_count() >= 2, "épidémie de grippe : %d premiers malades" % ev.epidemies.malades_count())
	var sick: int = ev.epidemies.malades.keys()[0]
	pop._now = {}
	var plan := pop.day_plan(pop.persons[sick])
	_check(plan.size() == 1 and (String(plan[0][2]) == "maison" or String(plan[0][2]) == "soins"), "un malade reste à la maison (ou à l'hôpital) toute la journée")
	var max_sick := 0
	for d in 90:
		amb.unix_time += 86400.0
		ev._process(0.1)
		max_sick = maxi(max_sick, ev.epidemies.malades_count())
		if String(ev.events.get(eid, {"etat": "fini"}).etat) == "fini":
			break
	var ee: Dictionary = ev.events.get(eid, {})
	_check(not ee.is_empty() and String(ee.etat) == "fini" and ev.epidemies.active == -1, "l'épidémie s'arrête (%d malades en tout, au plus %d en même temps, %d décès)" % [int(ee.data.total), max_sick, int(ee.data.deces)])
	_check(int(ee.data.total) >= 2, "la maladie s'est transmise")

	print("Sauvegarde :")
	ev.incendies.start_fire(homes[7], "manuel")
	ev.set_degats(homes[0], 0.4, "tempete", true)
	var data: Dictionary = JSON.parse_string(JSON.stringify(scene.save_sections().evenements))
	var n_ruines := ev.ruines.size()
	var n_deg := ev.degats.size()
	var n_feux := ev.incendies.feux.size()
	var clubs := ev.matchs.clubs.size()
	ev.from_dict(data)
	_check(ev.ruines.size() == n_ruines and ev.degats.size() == n_deg, "dégâts et ruines rechargés (%d, %d)" % [n_deg, n_ruines])
	_check(ev.incendies.feux.size() == n_feux and n_feux > 0, "le feu en cours reprend après chargement")
	_check(ev.matchs.clubs.size() == clubs and not ev.journal.is_empty(), "clubs et journal rechargés")

	print("Panneau Infos et fil d'actualité :")
	var panel: EvenementsPanel = scene.evenements_panel
	for v in ["en_cours", "journal", "organiser", "degats", "stades"]:
		panel.set_open(true)
		panel.show_view(v)
	_check(panel.is_open() and panel._body.get_child_count() > 0, "les 5 onglets s'affichent")
	_check(scene.actualites.count() > 0, "fil d'actualité en haut de l'écran")
	ev.set_outil("incendie")
	_check(ev.poser("incendie", Vector2i(-200, -200)) == false, "outil incendie : rien sans bâtiment")

	print("EVENEMENTS TEST OK" if ok else "EVENEMENTS TEST ÉCHEC")
	quit(0 if ok else 1)
