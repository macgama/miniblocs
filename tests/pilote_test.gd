extends SceneTree
## Test du pilote automatique d'une ville (Pays). D'après le test du pays :
## Test du pays et des caisses des villes : caisse du pays avant la première
## ville, capital de départ, bâtiment fondateur payé par le pays, chaque ville
## paie ce qui se construit chez elle, voies hors des villes au pays, ville gérée
## qui suit la caméra, subventions et reversements, budget propre à chaque ville
## (impôts, emprunts), impôt national et dotation, fusion, sauvegarde, ancienne
## partie, panneau Maj+P.
## Usage : godot --headless --path . --script res://tests/pilote_test.gd

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


func _run() -> void:
	Creations.persist = false
	BatimentsVie.chantiers = false
	GameStart.chosen = true
	GameStart.place_name = "Valfleuri, Savoie"
	ReglagesPartie.prochaine = ReglagesPartie.preset("normal")
	ReglagesPartie.prochaine.fondateurs = 0
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var transport: TransportSystem = scene.get_node("Transport")
	var bs: BuildingSystem = scene.get_node("Batiments")
	var zones: ZoneSystem = scene.get_node("Zones")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.view_radius_override = 1200.0
	world.set_origin(45.5, 6.4)
	for i in 3000:
		await process_frame
		if i >= 120 and world.missing_chunk_count() == 0 and world._dirty.is_empty() and world._jobs.is_empty():
			break
	scene.urgences.random_calls = false
	var cm: Communes = scene.communes
	var p: Pays = scene.pays
	var bud: BudgetCommunal = scene.budget
	var y := world.cell_height(Vector2i(0, 0))
	# La caméra regarde loin des villages : la ville gérée ne bouge que quand on le veut.
	p.foyer = func() -> Vector2: return Vector2(0, 5000)
	_check(p != null and Pays.instance == p and scene.pays_panel != null, "pays et panneau branchés")

	var pa: PiloteAuto = scene.pilote
	_check(pa != null and PiloteAuto.instance == pa, "pilote automatique branché")
	cm.nom_en_attente = "Valfleuri"
	var mc := bs.place("maison_commune", Vector2i(-1000, 0), 0)
	var v1 := cm.principal()
	_check(mc > 0 and v1 >= 0, "Valfleuri fondé")
	p.choisir(v1)

	print("Activer :")
	pa.activer(v1, true)
	_check(pa.actif(v1), "pilote en marche")
	_check(pa._voies(v1).is_empty(), "pas encore de rue")

	print("Première semaine : une rue")
	var s0 := p.solde(v1)
	var t := pa.semaine(v1)
	_check(t.begins_with("Première rue"), "décision : %s" % t)
	_check(not pa._voies(v1).is_empty(), "la ville a sa rue")
	_check(p.solde(v1) <= s0, "payée par Valfleuri")

	print("Logements :")
	var t2 := pa.semaine(v1)
	_check(t2.begins_with("Zone résidentielle"), "décision : %s" % t2)
	_check(pa.zones_de(v1, "R") == 1, "une zone résidentielle le long de la rue")
	var zr: Rect2i = Rect2i()
	for zid in zones.zones:
		zr = ZoneSystem.zone_rect(zones.zones[zid])
	_check(cm.rect_dans_territoire(zr) and p.payeur_du_rect(zr) == v1, "sur le territoire de Valfleuri")

	print("Services :")
	bs.unlimited_money = true
	var ecole := pa._poser(v1, "ecole")
	_check(ecole > 0 and cm.village_du_batiment(ecole) == v1, "école posée le long d'une rue de Valfleuri")
	_check(pa.compter(v1, "ecole") == 1, "comptée")
	var n_voies := pa._voies(v1).size()
	var t3 := pa._prolonger(v1)
	_check(t3 != "" and pa._voies(v1).size() > n_voies, "plus de place : %s" % t3)
	bs.unlimited_money = false

	print("Réserve :")
	p._poser(v1, 100_000)
	_check(pa.dispo(v1) < 0, "caisse sous la réserve : rien de cher")
	var n_bat := bs.buildings.size()
	pa.construire(v1)
	_check(bs.buildings.size() == n_bat, "pas de bâtiment sans argent")

	print("Mairie perdue :")
	var el: Elections = scene.avis.elections_de(v1)
	el.forcer_mode = "mairie"
	el.maire = {"joueur": false, "nom": "Autre liste", "tendance": "ecologie"}
	_check(pa.semaine(v1) == "", "le pilote ne décide plus pour une ville perdue")
	el.maire = {"joueur": true}

	print("Sauvegarde :")
	var d := pa.to_dict()
	pa.from_dict(d)
	_check(pa.actif(v1) and not (pa.journal.get(v1, []) as Array).is_empty(), "pilote et journal retrouvés")
	scene.pays_panel.set_open(true)
	var bouton := false
	for c in scene.pays_panel._body.get_children():
		if c is HBoxContainer:
			for b in c.get_children():
				if b is Button and (b as Button).text == "Arrêter":
					bouton = true
	_check(bouton, "bouton du pilote dans Maj+P")
	scene.pays_panel.set_open(false)
	pa.activer(v1, false)
	_check(not pa.actif(v1), "pilote arrêté")

	print("RÉSULTAT : ", "OK" if ok else "ÉCHEC")
	quit(0 if ok else 1)
