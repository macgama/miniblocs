extends SceneTree
## Test des élections par ville et de la mairie perdue (Pays). Ancien en-tête :
## Test du pays et des caisses des villes : caisse du pays avant la première
## ville, capital de départ, bâtiment fondateur payé par le pays, chaque ville
## paie ce qui se construit chez elle, voies hors des villes au pays, ville gérée
## qui suit la caméra, subventions et reversements, budget propre à chaque ville
## (impôts, emprunts), impôt national et dotation, fusion, sauvegarde, ancienne
## partie, panneau Maj+P.
## Usage : godot --headless --path . --script res://tests/mairie_test.gd

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

	print("Deux villes :")
	cm.nom_en_attente = "Valfleuri"
	var mc := bs.place("maison_commune", Vector2i(-1000, 0), 0)
	var v1 := cm.principal()
	cm.nom_en_attente = "Les Granges"
	var mc2 := bs.place("maison_commune", Vector2i(1100, 0), 0)
	var v2 := cm.village_du_batiment(mc2)
	_check(mc > 0 and mc2 > 0 and v1 != v2 and v2 >= 0, "Valfleuri et Les Granges fondés")
	var av: Avis = scene.avis
	p.choisir(v1)
	await process_frame
	_check(av.ville_vid == v1 and Avis.ville() == "Valfleuri", "Avis examine la ville gérée")
	p.choisir(v2)
	await process_frame
	_check(av.ville_vid == v2 and Avis.ville() == "Les Granges", "et suit le changement de ville")
	_check(av.elections_de(v1) != av.elections_de(v2) and av.elections_de(v2).vid == v2, "une élection par ville")
	_check(av.joueur_maire_de(v1) and av.joueur_decide_de(v1), "au départ, tu es maire partout")

	print("Mairie perdue :")
	var el := av.elections_de(v1)
	el.forcer_mode = "mairie"
	el.etat = "mandat"
	el.mandat_debut = av.jour()
	el.vote_jour = av.jour() + 30
	p.choisir(v1)
	var b_av := bud.taux.duplicate()
	av.examiner(v1)
	el._elire({"id": "contribuables", "nom": "Moins d'impôts pour Valfleuri", "couleur": "f8961e", "tendance": "contribuables",
		"themes": ["impots"], "promesses": ["impots_baisse", "dette"], "joueur": false, "sortant": false, "tete": -1, "tete_nom": "Jeanne Martin"},
		55.0, "test", 60.0)
	av.examiner(av.ville_par_defaut())
	_check(not av.joueur_maire_de(v1) and not av.joueur_decide_de(v1), "la liste « contribuables » a pris Valfleuri")
	_check(not p.joueur_maire(v1) and p.joueur_maire(v2), "tu restes maire des Granges")
	_check(is_equal_approx(float(bud.taux.foncier), GestionAuto.politique("contribuables").taux), "son programme : impôts à 80 %% (avant %d %%)" % roundi(float(b_av.foncier) * 100.0))
	_check(el.objectifs.size() == 2, "ses promesses deviennent les objectifs du mandat")
	bud.set_taux("foncier", 1.6)
	_check(not is_equal_approx(float(bud.taux.foncier), 1.6), "tu ne fixes plus les impôts de Valfleuri")
	_check(bud.emprunter(500_000, 10).is_empty(), "ni ses emprunts")
	bud.set_entretien("route", "taux", 2.0)
	_check(not is_equal_approx(float(bud.entretien.route.taux), 2.0), "ni son entretien")
	_check(p.reverser(v1, 100_000) != "", "ni reverser son argent au pays")
	var n0 := bs.buildings.size()
	var maison := bs.place("maison", Vector2i(-900, 56), bs.best_rotation("maison", Vector2i(-900, 56)))
	if maison < 0:
		transport.build_segment("route", Vector3(-1300, y, 40), Vector3(-700, y, 40))
		maison = bs.place("maison", Vector2i(-900, 56), bs.best_rotation("maison", Vector2i(-900, 56)))
	_check(maison > 0 and bs.buildings.size() > n0, "mais tu construis toujours à Valfleuri")
	p.choisir(v2)
	bud.set_taux("foncier", 1.3)
	_check(is_equal_approx(float(bud.taux.foncier), 1.3), "aux Granges, tu décides encore")

	print("Le maire élu gère son budget :")
	p._poser(v1, -2_000_000)
	var bt := 0.0
	GestionAuto.gerer_budget(v1, "contribuables")
	p.choisir(v1)
	bt = float(bud.taux.foncier)
	_check(bt > GestionAuto.politique("contribuables").taux + 0.01, "caisse dans le rouge : il relève les impôts (%d %%)" % roundi(bt * 100.0))
	_check(bud.emprunts.size() == 1, "et emprunte 500 k€")
	_check(p.solde(v1) > -2_000_000, "la caisse remonte")
	var j := av.jour()
	var vu := false
	for jj in range(j, j + 7):
		if posmod(jj + v1, GestionAuto.JOURS_ENTRE) == 0:
			vu = true
	_check(vu, "il passe une fois par semaine")

	print("Pétition et reconquête :")
	_check(not el.petition() or av.moyenne() < Elections.SEUIL_PETITION, "pétition seulement si les habitants sont mécontents")
	av.examiner(v1)
	el._elire({"id": "joueur", "nom": "Ensemble pour Valfleuri", "couleur": Elections.COULEUR_JOUEUR, "tendance": "", "themes": [],
		"promesses": [], "joueur": true, "sortant": false, "tete": -1, "tete_nom": "toi"}, 52.0, "test", 61.0)
	av.examiner(av.ville_par_defaut())
	_check(av.joueur_maire_de(v1) and p.joueur_maire(v1), "tu reprends Valfleuri")
	p.choisir(v1)
	bud.set_taux("foncier", 1.1)
	_check(is_equal_approx(float(bud.taux.foncier), 1.1), "et tu décides de nouveau de ses impôts")

	print("Sauvegarde des élections par ville :")
	av.examiner(v2)
	av.elections_de(v2).forcer_mode = "mairie"
	av.elections_de(v2)._elire({"id": "ecologie", "nom": "Respirer aux Granges", "couleur": "57cc99", "tendance": "ecologie",
		"themes": ["environnement"], "promesses": ["environnement"], "joueur": false, "sortant": false, "tete": -1, "tete_nom": "Paul"}, 51.0, "t", 50.0)
	av.examiner(av.ville_par_defaut())
	var d := av.to_dict()
	av.from_dict(d)
	_check(not av.joueur_maire_de(v2) and av.joueur_maire_de(v1), "Les Granges restent à « Respirer aux Granges », Valfleuri à toi")
	_check(String(av.maire_de(v2).get("tendance", "")) == "ecologie", "programme du maire retrouvé")
	var vieux := d.duplicate(true)
	vieux.erase("villes")
	av.from_dict(vieux)
	_check(av.elections_villes.has(cm.principal()), "ancienne sauvegarde : les élections vont au chef-lieu")

	print("Panneaux :")
	av.from_dict(d)
	p.choisir(v2)
	await process_frame
	scene.avis_panel.set_open(true)
	scene.avis_panel.show_view("elections")
	_check(scene.avis_panel._body.get_child_count() >= 2, "panneau Avis rempli (sans habitants dans ce test)")
	scene.avis_panel.set_open(false)
	scene.budget_panel.set_open(true)
	var bandeau := false
	for c in scene.budget_panel._body.get_children():
		if c is Label and (c as Label).text.begins_with("Tu n'es plus maire"):
			bandeau = true
	_check(bandeau, "panneau Budget : bandeau « Tu n'es plus maire »")
	scene.budget_panel.set_open(false)
	scene.pays_panel.set_open(true)
	_check(scene.pays_panel._body.get_child_count() > 6, "panneau Pays rempli")
	scene.pays_panel.set_open(false)
	_check(Elections.MODES.has("mairie") and ReglagesPartie.new().elections == "mairie", "réglage « mairie perdue » par défaut")

	print("RÉSULTAT : ", "OK" if ok else "ÉCHEC")
	quit(0 if ok else 1)
