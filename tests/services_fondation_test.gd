extends SceneTree
## Test des services de base prêts au premier village (ServicesFondation) et du
## départ au 1er janvier 1800, 1900 ou 2000.
## Usage : godot --headless --path . --script res://tests/services_fondation_test.gd -- 2000
## (année de départ : 1800, 1900 ou 2000 ; « off » : réglage décoché, en 2000).

var ok := true


func _initialize() -> void:
	_run.call_deferred()
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


func _types(bs: BuildingSystem) -> Array:
	var out := []
	for bid in bs.buildings:
		out.append(String(bs.buildings[bid].t))
	return out


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var arg := String(args[0]) if not args.is_empty() else "2000"
	var annee := 2000 if arg == "off" else int(arg)
	Creations.persist = false
	GameStart.chosen = true
	GameStart.place_name = "Valfleuri, Savoie"
	ReglagesPartie.prochaine = ReglagesPartie.preset("normal")
	ReglagesPartie.prochaine.deblocage = "tout"
	ReglagesPartie.prochaine.fondateurs = 20
	ReglagesPartie.prochaine.annee_depart = annee
	ReglagesPartie.prochaine.services_fondation = arg != "off"
	print("Départ en %d (%s) :" % [annee, arg])
	var GlobeMenu: GDScript = load("res://scripts/terre/globe_menu.gd")
	_check(GlobeMenu.EPOQUES.size() == 3 and int(GlobeMenu.EPOQUES[0][0]) == 1800 and int(GlobeMenu.EPOQUES[2][0]) == 2000,
		"assistant : trois départs, 1800, 1900, 2000")
	_check(GlobeMenu.indice_epoque(1850) == 2 and GlobeMenu.indice_epoque(1900) == 1, "autre année → 2000")
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var bs: BuildingSystem = scene.get_node("Batiments")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.view_radius_override = 2000.0
	world.set_origin(45.5, 6.4)
	for i in 3000:
		await process_frame
		if i >= 120 and world.missing_chunk_count() == 0 and world._dirty.is_empty() and world._jobs.is_empty():
			break
	scene.urgences.random_calls = false
	scene.population.arrivals = false
	var amb: DayNight = scene.ambiance
	var d := amb.local_datetime()
	_check(int(d.year) == annee and int(d.month) == 1 and int(d.day) == 1, "la partie commence le 1er janvier %d (%d-%02d-%02d)" % [
		annee, int(d.year), int(d.month), int(d.day)])
	_check(Epoques.annee() == annee, "année de l'histoire : %d" % Epoques.annee())

	var cm: Communes = scene.communes
	var sf: ServicesFondation = scene.services_fondation
	var kit: KitInstallation = scene.kit
	_check(sf != null and ServicesFondation.instance == sf, "services de fondation branchés")
	cm.nom_en_attente = "Valfleuri"
	var mc := bs.place("maison_commune", Vector2i(-1000, 0), 0)
	# Les services se posent juste après (appel différé) : rien de plus à payer.
	var argent := bs.money
	var v1 := cm.principal()
	for i in 6:
		await process_frame
	_check(mc >= 0 and v1 >= 0, "Valfleuri fondé")
	var types := _types(bs)
	var c: Vector2 = cm.villages[v1].c
	var attendus := {1800: [], 1900: ["forage_eau", "exutoire_egout", "depot_collecte", "decharge"],
		2000: ["poste_national", "forage_eau", "station_epuration_locale", "depot_collecte", "decharge"]}
	if arg == "off":
		_check(sf.vid < 0 and not types.has("forage_eau"), "réglage décoché : rien n'est posé")
		_fin()
		return
	for id in attendus[annee]:
		_check(types.has(id), "%s posé" % id)
	if annee == 1800:
		_check(types.size() <= 2, "1800 : rien (bougies, puits) %s" % [types])
		_check(sf.en_attente().size() == 4, "1800 : les quatre réseaux attendent l'époque")
	var loin := true
	var chantier := false
	for bid in bs.buildings:
		var b: Dictionary = bs.buildings[bid]
		if KitInstallation.bon_du_type(String(b.t)) == "":
			continue
		var dist := Vector2(bs._rect_of(b).get_center()).distance_to(c)
		loin = loin and dist > 60.0 and dist < 500.0
		chantier = chantier or bs.en_chantier(bid)
	_check(loin, "un peu à l'écart du centre (60 à 500 m)")
	_check(not chantier, "prêts tout de suite (pas de chantier)")
	# Ce qui a été posé est offert (la Maison de commune se paie au fil de son chantier).
	_check(bs.money >= argent - 1, "rien de payé pour les services (%d → %d)" % [argent, bs.money])
	if annee == 2000:
		_check(kit.restants(v1).is_empty(), "les bons du kit ont servi (pas donnés deux fois)")
		_check(sf.en_attente().is_empty(), "tout est posé en 2000")
	if annee == 1900:
		_check(sf.en_attente() == ["elec"], "1900 : le courant attend 1925 (%s)" % [sf.en_attente()])
		_check(kit.restants(v1) == ["elec"], "1900 : il reste le bon de l'électricité")

	print("Raccordements :")
	var rx: Reseaux = scene.reseaux
	for i in 30:
		await process_frame
	for bid in bs.buildings:
		var t := String(bs.buildings[bid].t)
		var res := KitInstallation.bon_du_type(t)
		if res in ["elec", "eau", "egout"]:
			var net: ReseauBase = rx.get(res)
			_check(net.est_raccorde(bid), "%s raccordé au réseau %s" % [t, res])

	if annee == 1900:
		print("En 1925, le courant arrive tout seul :")
		Epoques.aller_a(1925)
		sf.installer()
		_check(_types(bs).has("poste_national"), "raccordement au réseau national posé en 1925")
		_check(sf.en_attente().is_empty(), "plus rien n'attend")

	print("Deuxième village : rien de plus")
	var n := bs.buildings.size()
	cm.nom_en_attente = "Montclair"
	var mc2 := bs.place("maison_commune", Vector2i(1500, 0), 1)
	for i in 6:
		await process_frame
	_check(mc2 >= 0 and bs.buildings.size() <= n + 2, "Montclair n'a pas de services d'office")

	print("Sauvegarde :")
	var dd := sf.to_dict()
	var sf2 := ServicesFondation.new()
	sf2.from_dict(dd)
	_check(sf2.vid == sf.vid and sf2.poses.size() == sf.poses.size(), "section « services_fondation » relue")
	sf2.free()
	_fin()


func _fin() -> void:
	print("RÉSULTAT : ", "OK" if ok else "ÉCHEC")
	quit(0 if ok else 1)
