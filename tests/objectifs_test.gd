extends SceneTree
## Test des objectifs du pays (Maj+J) : missions tirées selon les villes, mission
## réussie (prime au pays, réputation), ratée, abandonnée, rang des villes et ce
## qui manque, succès, bonus de taux d'emprunt, sauvegarde, panneau.
## Usage : godot --headless --path . --script res://tests/objectifs_test.gd

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
	
	var o: Objectifs = scene.objectifs
	_check(o != null and Objectifs.instance == o and scene.objectifs_panel != null, "objectifs et panneau branchés")
	o.nouveau_jour()
	_check(o.missions.is_empty() and o.succes.is_empty(), "pas de ville : ni mission ni succès")
	cm.nom_en_attente = "Valfleuri"
	var mc := bs.place("maison_commune", Vector2i(-1000, 0), 0)
	var v1 := cm.principal()
	_check(mc > 0 and v1 >= 0, "Valfleuri fondé")

	print("Missions :")
	o.nouveau_jour()
	_check(o.succes.has("premier_village"), "succès « Première pierre »")
	_check(o.missions.size() >= 2 and o.missions.size() <= Objectifs.MISSIONS_MAX, "%d missions : %s" % [o.missions.size(),
		" / ".join(o.missions.map(func(m) -> String: return String(m.texte)))])
	var types := o.missions.map(func(m) -> String: return String(m.type))
	_check(types.has("habitants") and types.has("fonder"), "faire grandir la ville et fonder une ville")
	# Une mission déjà remplie : prime au pays et réputation.
	o.missions.clear()
	o.missions.append({"id": 900, "type": "fonder", "vid": -1, "vid2": [], "cible": 1, "debut": o.jour(), "fin": o.jour() + 10,
		"prime": 400_000, "rep": 5.0, "texte": "Fonder une ville"})
	var caisse0 := p.solde(Pays.PAYS)
	var rep0 := o.reputation
	o._verifier_missions()
	_check(p.solde(Pays.PAYS) == caisse0 + 400_000, "mission réussie : prime versée au pays (%s)" % BuildingSystem.format_money(p.solde(Pays.PAYS) - caisse0))
	_check(o.reputation > rep0 and o.reussies == 1, "réputation %d → %d" % [roundi(rep0), roundi(o.reputation)])
	# Une mission dont le délai est passé.
	o.missions.append({"id": 901, "type": "habitants", "vid": v1, "vid2": [], "cible": 5000, "debut": o.jour() - 70,
		"fin": o.jour() - 1, "prime": 100_000, "rep": 3.0, "texte": "Faire grandir"})
	var rep1 := o.reputation
	o._verifier_missions()
	_check(o.missions.is_empty() and o.reputation < rep1, "mission ratée : réputation en baisse")
	_check(o.historique.size() == 2 and bool(o.historique[0].reussie) and not bool(o.historique[1].reussie), "historique des missions")
	o._completer_missions()
	_check(o.missions.size() >= 2, "de nouvelles missions remplacent les anciennes")
	var n := o.missions.size()
	o.abandonner(int(o.missions[0].id))
	_check(o.missions.size() == n - 1, "mission abandonnée")

	print("Rangs :")
	_check(o.palier_de(v1) == 0, "Valfleuri est un hameau")
	cm.stats[v1]["hab"] = 600
	var manque := o.manques(v1)
	_check(not " ".join(manque).contains("habitants"), "100 habitants atteints (reste : %s)" % ", ".join(manque))
	o.paliers[v1] = 1
	manque = o.manques(v1)
	_check(manque.has("une école"), "pour être Bourg : %s" % ", ".join(manque))
	o.paliers.erase(v1)

	print("Réputation et emprunts :")
	o.reputation = 20.0
	var t20 := bud.taux_propose(1_000_000, 10)
	o.reputation = 100.0
	var t100 := bud.taux_propose(1_000_000, 10)
	_check(absf(Objectifs.bonus_taux() - 0.01) < 0.0001 and t100 < t20, "5 étoiles : taux %.2f %% au lieu de %.2f %%" % [t100 * 100.0, t20 * 100.0])
	_check(o.etoiles() == 5, "5 étoiles")

	print("Sauvegarde :")
	o.paliers[v1] = 2
	var d := o.to_dict()
	var nm := o.missions.size()
	o.clear()
	_check(o.missions.is_empty() and o.reputation == Objectifs.REP_DEPART, "remise à zéro")
	o.from_dict(JSON.parse_string(JSON.stringify(d)))
	_check(o.palier_de(v1) == 2 and o.missions.size() == nm and o.reussies == 1 and o.succes.has("premier_village") and roundi(o.reputation) == 100,
		"rangs, missions, succès et réputation rechargés")
	_check(scene.save_sections().has("objectifs"), "section « objectifs » dans la sauvegarde")

	print("Panneau :")
	var panel: ObjectifsPanel = scene.objectifs_panel
	for v in ["missions", "villes", "succes"]:
		panel.set_open(true)
		panel.show_view(v)
		_check(panel._body.get_child_count() > 3, "onglet %s (%d éléments)" % [v, panel._body.get_child_count()])
	panel.set_open(false)

	print("RÉSULTAT : ", "OK" if ok else "ÉCHEC")
	quit(0 if ok else 1)
