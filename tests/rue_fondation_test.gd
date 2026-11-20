extends SceneTree
## Test de la rue en T offerte à la fondation d'une ville : posée devant la façade
## de la Maison de commune, gratuite, sans chantier, avec un carrefour en T ; une
## maison peut se poser tout de suite le long ; une 2e ville a la sienne ; réglage
## Admin décoché : rien ; mairie déjà desservie : rien ; sauvegarde ; tutoriel
## (les mètres offerts ne valident pas l'étape « route »).
## Usage : godot --headless --path . --script res://tests/rue_fondation_test.gd

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


## Tronçons routiers à moins de rayon m du point (x, z).
func _troncons(tr: TransportSystem, x: float, z: float, rayon: float) -> Array:
	var out := []
	for eid in tr.network.edges:
		var hit := tr.network.nearest_on_edge(eid, Vector3(x, 0, z))
		if float(hit.dist) <= rayon:
			out.append(eid)
	return out


func _run() -> void:
	Creations.persist = false
	GameStart.chosen = true
	GameStart.place_name = "Valfleuri, Savoie"
	ReglagesPartie.prochaine = ReglagesPartie.preset("normal")
	ReglagesPartie.prochaine.deblocage = "tout"  # (ce test ne porte pas sur l'arbre de progression)
	ReglagesPartie.prochaine.fondateurs = 20
	ReglagesPartie.prochaine.services_fondation = false  # (services posés d'office : tests/services_fondation_test.gd)
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var tr: TransportSystem = scene.get_node("Transport")
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
	var cm: Communes = scene.communes
	var rf: RueFondation = scene.rue_fondation
	_check(rf != null and RueFondation.instance == rf, "rue offerte branchée")
	_check(ReglagesPartie.actuel.rue_fondation, "réglage activé par défaut")
	_check(cm.actif and cm.fondation_requise(), "partie avec fondation")
	_check(tr.network.edges.is_empty(), "terre vierge : aucune voie")

	print("Première ville :")
	cm.nom_en_attente = "Valfleuri"
	var mc := bs.place("maison_commune", Vector2i(-1000, 0), 0)
	var v1 := cm.principal()
	for i in 4:
		await process_frame
	_check(mc >= 0 and v1 >= 0, "Valfleuri fondé")
	var m1 := float(rf.offertes.get(v1, 0.0))
	_check(is_equal_approx(m1, 160.0), "T de 100 + 60 m offert (%s m)" % m1)
	var edges := tr.network.edges.keys()
	_check(edges.size() == 3, "3 tronçons : barre coupée en deux + jambe (%d)" % edges.size())
	var rues := true
	var chantier := false
	for eid in edges:
		rues = rues and String(tr.network.edges[eid].t) == "rue"
		chantier = chantier or (tr.network.edges[eid] as Dictionary).has("ch")
	_check(rues, "ce sont des rues de desserte")
	_check(not chantier, "pas de chantier : la rue est prête tout de suite")
	var carrefour := false
	for nid in tr.network.nodes:
		carrefour = carrefour or (tr.network.adjacency.get(nid, []) as Array).size() == 3
	_check(carrefour, "un carrefour en T")
	# La barre longe la façade (−Z pour une rotation 0), la jambe part droit devant.
	var door := BuildingSystem.door_point("maison_commune", bs._rect_of(bs.buildings[mc]), 0)
	_check(not _troncons(tr, door.x, door.z, 12.0).is_empty(), "la porte de la mairie donne sur la rue")
	_check(not _troncons(tr, -1000.0, -70.0, 2.0).is_empty(), "la jambe part devant la façade")
	_check(_troncons(tr, -1000.0, 30.0, 10.0).is_empty(), "rien derrière la mairie")
	# Une maison se pose tout de suite le long de la rue, avec son accès.
	var pose := -1
	for x in range(-1045, -954, 3):
		for z in [-28, -4]:
			for r in 4:
				var chk := bs.check_place("maison", Vector2i(x, z), r)
				if pose < 0 and chk.ok and not (chk.access as Dictionary).is_empty():
					pose = bs.place("maison", Vector2i(x, z), r)
	_check(pose >= 0, "une maison posée le long de la rue offerte")
	# Le campement des fondateurs n'est pas sur la rue.
	var fd: Fondateurs = scene.fondateurs
	_check(fd.arrives and fd.camp >= 0, "campement planté à côté")

	print("Tutoriel :")
	var tuto: Tutoriel = scene.tutoriel
	if tuto != null:
		_check(tuto.metres_traces() < 1.0, "la rue offerte ne compte pas comme route tracée (%s m)" % tuto.metres_traces())
		var e := {}
		for x in tuto.etapes():
			if String(x.id) == "route":
				e = x
		_check(Tutoriel.texte_de(e).contains("rue en T"), "étape « route » : texte de la rue offerte")

	print("Deuxième ville, à 2,1 km :")
	cm.nom_en_attente = "Montclair"
	var mc2 := bs.place("maison_commune", Vector2i(1100, 0), 1)
	for i in 4:
		await process_frame
	var v2 := cm.village_du_batiment(mc2)
	_check(mc2 >= 0 and v2 >= 0 and v2 != v1, "Montclair fondé")
	_check(float(rf.offertes.get(v2, 0.0)) > 0.0, "Montclair a sa rue en T")
	_check(tr.network.edges.size() == 6, "6 tronçons en tout (%d)" % tr.network.edges.size())
	# Rotation 1 : la façade regarde une autre direction, la rue la suit.
	var door2 := BuildingSystem.door_point("maison_commune", bs._rect_of(bs.buildings[mc2]), 1)
	_check(not _troncons(tr, door2.x, door2.z, 12.0).is_empty(), "devant la porte de Montclair aussi")

	print("Ville au bord d'une route existante :")
	var y := world.cell_height(Vector2i(0, 1900))
	_check(bool(tr.build_segment("route", Vector3(-100, y, 1920), Vector3(100, y, 1920)).ok), "route posée à la main")
	var n0 := tr.network.edges.size()
	cm.nom_en_attente = "Bordeloup"
	var mc3 := bs.place("maison_commune", Vector2i(0, 1906), 2)
	for i in 4:
		await process_frame
	var v3 := cm.village_du_batiment(mc3)
	_check(mc3 >= 0 and v3 >= 0, "Bordeloup fondé")
	_check(not rf.offertes.has(v3) and tr.network.edges.size() == n0, "déjà desservie : pas de rue offerte")

	print("Réglage Admin décoché :")
	ReglagesPartie.actuel.rue_fondation = false
	var n1 := tr.network.edges.size()
	cm.nom_en_attente = "Sansrue"
	var mc4 := bs.place("maison_commune", Vector2i(0, -1900), 0)
	for i in 4:
		await process_frame
	var v4 := cm.village_du_batiment(mc4)
	_check(mc4 >= 0 and v4 >= 0, "Sansrue fondé")
	_check(not rf.offertes.has(v4) and tr.network.edges.size() == n1, "pas de rue : on part de rien")
	ReglagesPartie.actuel.rue_fondation = true
	var d := ReglagesPartie.actuel.to_dict()
	_check(d.has("rue_fondation"), "réglage sauvegardé")
	var rp := ReglagesPartie.new()
	d.rue_fondation = false
	rp.from_dict(d)
	_check(not rp.rue_fondation, "réglage relu")

	print("Sauvegarde :")
	var sd := rf.to_dict()
	rf.clear()
	_check(RueFondation.metres_offerts() == 0.0, "vidé")
	rf.from_dict(JSON.parse_string(JSON.stringify(sd)))
	_check(rf.offertes.has(v1) and rf.offertes.has(v2) and rf.offertes.size() == 2, "relu : 2 villes avec leur rue")

	print("TEST OK" if ok else "TEST ÉCHEC")
	quit(0 if ok else 1)
