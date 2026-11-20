extends SceneTree
## Test du flux des réseaux sur les routes (scripts/reseaux/reseaux_flux.gd) :
## clic sur une maison = électricité, eau, égouts côte à côte ; sens depuis la
## centrale ; vert quand tout est servi, rouge (coupé) sans captage, orange
## (saturé) quand la demande dépasse la production ; partie non reliée en pâle ;
## centrale = son réseau seul ; vue O = réseau de l'onglet ; clic sur une route ;
## égouts à l'envers ; désélection ; temps de calcul.
## Usage : godot --headless --path . --script res://tests/reseaux_flux_test.gd

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


## Distance à la source du nœud le plus proche de p (INF si aucun).
func _dist_pres(fl: ReseauxFlux, res: String, p: Vector3) -> float:
	var best := INF
	var bd := INF
	for k in fl.distances.get(res, {}):
		var q := Vector2(k) / 2.0
		var d := q.distance_to(Vector2(p.x, p.z))
		if d < bd:
			bd = d
			best = float(fl.distances[res][k])
	return best


func _run() -> void:
	Creations.persist = false
	BatimentsVie.chantiers = false
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var transport: TransportSystem = scene.get_node("Transport")
	var bs: BuildingSystem = scene.get_node("Batiments")
	bs.message.connect(func(t: String) -> void: print("  [bâtiments] ", t))
	var amb: DayNight = scene.get_node("Ambiance")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.view_radius_override = 900.0
	world.set_origin(45.75, 4.85)
	for i in 3000:
		await process_frame
		if i >= 150 and world.missing_chunk_count() == 0 and world._dirty.is_empty() and world._jobs.is_empty():
			break
	var res: Reseaux = scene.reseaux
	var fl := res.flux
	_check(fl != null and fl.reseaux == res and fl.get_parent() == res, "flux branché sur les réseaux")
	var r := ReglagesPartie.actuel
	r.reseaux_obligatoires = true
	r.deblocage = "tout"
	r.annee_depart = 0
	r.histoire_saut = 0
	r.histoire_debut = 0.0
	amb.set_speed(0)
	amb.unix_time = Time.get_unix_time_from_datetime_string("2026-06-21T12:00:00")
	bs.money = 5_000_000_000
	bs.require_access = false

	print("Petite ville :")
	var y := world.cell_height(Vector2i(0, 0))
	_check(transport.build_segment("route", Vector3(-300, y, 0), Vector3(300, y, 0)).ok, "route est-ouest")
	_check(transport.build_segment("route", Vector3(100, y, 0), Vector3(100, y, 200)).ok, "rue vers le nord en T")
	_check(transport.build_segment("route", Vector3(-300, y, 600), Vector3(300, y, 600)).ok, "route à part, plus loin")
	var poste := bs.place("poste_national", Vector2i(-220, -22), 0)
	var maison := bs.place("maison", Vector2i(250, 16), 0)
	var rue := bs.place("maison", Vector2i(110, 150), 0)
	var isolee := bs.place("maison", Vector2i(0, 616), 0)
	_check(poste > 0 and maison > 0 and rue > 0 and isolee > 0, "poste national, deux maisons reliées, une maison sur la route à part")
	if not ok:
		quit(1)
		return
	await process_frame
	await process_frame
	res.simuler(0.0)
	res.simuler(0.0)
	var elec := res.reseau("elec")
	_check(elec.composante_de(maison) == elec.composante_de(poste) and elec.composante_de(isolee) != elec.composante_de(poste), "la route à part n'est pas reliée au poste")
	_check(elec.taux_servi(maison) >= 0.95, "la maison a du courant")

	print("Clic sur une maison :")
	scene.population._sync_buildings()
	scene.population.select_building(maison)
	_check(fl.actif() and fl.bid == maison and fl.origine == "batiment", "le flux s'affiche au clic")
	_check(fl.reseaux_montres.has("elec") and fl.reseaux_montres.has("eau") and fl.reseaux_montres.has("egout"), "électricité, eau et égouts côte à côte (%s)" % [fl.reseaux_montres])
	var se: Dictionary = fl.stats.get("elec", {})
	_check(int(se.get("ok", 0)) > 0 and int(se.get("morceaux", 0)) > 0 and fl._mi["elec"].mesh != null, "électricité : ruban vert qui circule (%s)" % [se])
	_check(int(se.get("branchements", 0)) >= 2, "branchements jusqu'aux maisons")
	_check(int(se.get("coupe", 0)) > 0, "la route à part (sans poste) est montrée coupée")
	var sw: Dictionary = fl.stats.get("eau", {})
	_check(int(sw.get("ok", 0)) == 0 and int(sw.get("coupe", 0)) > 0, "eau : pas de captage, tout est rouge")
	var d_pres := _dist_pres(fl, "elec", Vector3(-220, y, 0))
	var d_loin := _dist_pres(fl, "elec", Vector3(250, y, 0))
	var d_rue := _dist_pres(fl, "elec", Vector3(100, y, 190))
	_check(d_pres < d_loin and d_loin > 400.0, "le courant part du poste vers l'est (%.0f m puis %.0f m)" % [d_pres, d_loin])
	_check(absf(d_rue - (22.0 + 320.0 + 190.0)) < 10.0, "dans la rue en T, la distance suit les routes (%.0f m)" % d_rue)
	_check(fl._mats["egout"].get_shader_parameter("sens") < 0.0 and fl._mats["elec"].get_shader_parameter("sens") > 0.0, "les eaux usées vont vers la station (flèches à l'envers)")

	print("Saturation :")
	elec.set_demande(maison, 500.0)
	elec.rebilan()
	fl.refaire()
	se = fl.stats.get("elec", {})
	_check(int(se.get("sature", 0)) > 0 and int(se.get("ok", 0)) == 0, "plus de demande que de production : ruban orange (%s)" % [se])
	_check(ReseauxFlux.etat_de(0.5) == ReseauxFlux.ETAT_SATURE and ReseauxFlux.etat_de(0.0) == ReseauxFlux.ETAT_COUPE and ReseauxFlux.etat_de(1.0) == ReseauxFlux.ETAT_OK, "états vert, orange, rouge")
	res.simuler(0.0)

	print("Clic sur le poste :")
	scene.population.select_building(poste)
	_check(fl.reseaux_montres == ["elec"], "une centrale montre son réseau seul (%s)" % [fl.reseaux_montres])
	_check(_dist_pres(fl, "elec", Vector3(-220, y, 0)) < 30.0, "le flux part du poste")

	print("Vue O :")
	res.vue.set_calque("eau", true)
	scene.population.select_building(maison)
	_check(fl.reseaux_montres == ["eau"], "onglet Eau : seulement l'eau")
	res.vue.set_calque("eau", false)
	res.vue.set_calque("elec", true)
	var li := fl.ligne_pres("elec", Vector3(0, y, 1))
	_check(li >= 0, "clic sur la route : elle porte la desserte")
	fl.montrer_ligne("elec", li)
	_check(fl.origine == "ligne" and fl.reseaux_montres == ["elec"] and int(fl.stats.elec.ok) > 0, "clic sur une route : son réseau circule")
	fl.sur_selection(-1)
	_check(fl.actif(), "le même clic qui ne choisit pas de bâtiment garde la route montrée")
	var li2 := fl.ligne_pres("elec", Vector3(0, y, 601))
	fl.montrer_ligne("elec", li2)
	_check(int(fl.stats.elec.etat_focus) == ReseauxFlux.ETAT_COUPE and int(fl.stats.elec.coupe) > 0, "route à part : coupée, en rouge")
	res.vue.set_calque("elec", false)
	fl._process(0.1)
	_check(not fl.actif(), "en quittant la vue O, le flux d'une route s'efface")

	print("Désélection :")
	scene.population.select_building(maison)
	_check(fl.actif(), "réaffiché")
	scene.population.select_building(-1)
	_check(not fl.actif() and fl._mi["elec"].mesh == null, "fiche fermée : plus de flux")

	print("À travers champs (sans route) :")
	var forage := bs.place("forage_eau", Vector2i(-700, -400), 0)
	var hameau := bs.place("maison", Vector2i(-650, 300), 0)
	_check(forage > 0 and hameau > 0, "forage loin de tout, maison isolée dans les champs")
	var pf := Vector3(-700, y, -400)
	var ph := Vector3(-650, y, 300)
	var bout := Vector3(-300, y, 0)
	var ids := [res.poser("conduite_eau", res.trace_sur_relief(pf, bout)), res.poser("ligne_mt", res.trace_sur_relief(bout, pf)),
		res.poser("conduite_eau", res.trace_sur_relief(bout, ph)), res.poser("ligne_mt", res.trace_sur_relief(bout, ph)),
		res.poser("collecteur", res.trace_sur_relief(ph, bout))]
	_check(not ids.has(-1), "conduites enterrées et lignes aériennes posées à travers champs")
	for rr in ["eau", "elec", "egout"]:
		for id in res.reseau(rr).troncons:
			res.reseau(rr).terminer_troncon(id)
	await process_frame
	res.recalculer_topologie()
	res.simuler(0.0)
	res.simuler(0.0)
	var eau := res.reseau("eau")
	_check(eau.est_raccorde(forage) and elec.est_raccorde(forage), "le forage est relié à l'eau et au courant (pompes) sans route")
	_check(eau.taux_servi(hameau) >= 0.95 and elec.taux_servi(hameau) >= 0.95, "la maison des champs a l'eau et le courant")
	_check(eau.taux_servi(maison) >= 0.95, "l'eau du forage arrive aussi en ville par la conduite")
	scene.population._sync_buildings()
	scene.population.select_building(hameau)
	var d_f := _dist_pres(fl, "eau", Vector3(-700, y, -390))
	var d_h := _dist_pres(fl, "eau", Vector3(-650, y, 300))
	_check(d_f < 30.0 and d_h > 950.0, "l'eau part du forage et suit les conduites dans les champs (%.0f m puis %.0f m)" % [d_f, d_h])
	_check(int(fl.stats.eau.ok) > 0 and int(fl.stats.elec.ok) > 0, "flux vert sur les conduites et la ligne")
	scene.population.select_building(maison)

	print("Temps de calcul (quartier de 20 × 20 rues) :")
	for i in 21:
		transport.build_segment("route", Vector3(-1000 + i * 50, y, -1000), Vector3(-1000 + i * 50, y, -50))
		transport.build_segment("route", Vector3(-1000, y, -1000 + i * 47.5), Vector3(0, y, -1000 + i * 47.5))
	for i in 150:
		bs.place("maison", Vector2i(-990 + (i % 15) * 64, -990 + (i / 15) * 90), 0)
	await process_frame
	res.simuler(0.0)
	res.simuler(0.0)
	scene.population._sync_buildings()
	scene.population.select_building(maison)
	var t0 := Time.get_ticks_msec()
	fl.refaire()
	var ms := Time.get_ticks_msec() - t0
	print("  noeuds élec : %d, morceaux : %d, %d ms pour les 4 réseaux" % [int(fl.stats.elec.noeuds), int(fl.stats.elec.morceaux), ms])
	_check(ms < 400, "calcul du flux en moins de 0,4 s (%d ms)" % ms)

	print("OK" if ok else "ÉCHECS")
	quit(0 if ok else 1)
