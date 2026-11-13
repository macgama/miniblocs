extends SceneTree
## Test du pays et des caisses des villes : caisse du pays avant la première
## ville, capital de départ, bâtiment fondateur payé par le pays, chaque ville
## paie ce qui se construit chez elle, voies hors des villes au pays, ville gérée
## qui suit la caméra, subventions et reversements, budget propre à chaque ville
## (impôts, emprunts), impôt national et dotation, fusion, sauvegarde, ancienne
## partie, panneau Maj+P.
## Usage : godot --headless --path . --script res://tests/pays_test.gd

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

	print("Avant la première ville :")
	_check(not p.a_des_villes() and p.actif == Pays.PAYS and p.selection == Pays.PAYS, "tout l'argent est au pays")
	var depart := bs.money
	_check(p.solde(Pays.PAYS) == depart, "caisse du pays : %s" % BuildingSystem.format_money(depart))

	print("Fonder la première ville :")
	cm.nom_en_attente = "Valfleuri"
	var mc := bs.place("maison_commune", Vector2i(-1000, 0), 0)
	_check(mc > 0 and cm.villages.size() == 1, "Valfleuri fondé")
	var v1 := cm.principal()
	var prix_mc := ReglagesPartie.prix(BuildingCatalog.cost("maison_commune"))
	var apres_mc := depart - prix_mc
	var capital1 := p.solde(v1)
	_check(absi(capital1 - roundi(apres_mc * Pays.PART_PREMIERE)) <= prix_mc / 5 + 2, "capital de départ : %s (60 %% de la caisse du pays)" % BuildingSystem.format_money(capital1))
	_check(p.solde(Pays.PAYS) + capital1 <= depart - prix_mc / 2, "le pays a payé la Maison de commune")
	_check(p.selection == v1 and p.actif == v1 and bs.money == capital1, "Valfleuri est la ville gérée : sa caisse s'affiche")
	_check(bud.cle == v1, "le budget M est celui de Valfleuri")

	print("Chaque ville paie chez elle :")
	transport.build_segment("route", Vector3(-1300, y, 40), Vector3(-700, y, 40))
	var pays_avant := p.solde(Pays.PAYS)
	var v1_avant := p.solde(v1)
	var maison := bs.place("maison", Vector2i(-900, 56), bs.best_rotation("maison", Vector2i(-900, 56)))
	if maison < 0:
		maison = bs.place("maison", Vector2i(-900, 24), bs.best_rotation("maison", Vector2i(-900, 24)))
	_check(maison > 0, "maison posée à Valfleuri")
	_check(p.solde(v1) < v1_avant and p.solde(Pays.PAYS) == pays_avant, "payée par Valfleuri (%s), pas par le pays" % BuildingSystem.format_money(v1_avant - p.solde(v1)))
	var z_avant := p.solde(v1)
	_check(zones.add_zone("R", Rect2i(-1200, 60, 60, 40)) > 0 and p.solde(v1) < z_avant, "zonage payé par Valfleuri")
	_check(p.payeur_au_point(-1000, 0) == v1 and p.payeur_au_point(500, 0) == Pays.PAYS, "hors des villes, c'est le pays qui paie")

	print("Deuxième ville :")
	p.choisir(v1)
	var pays_av2 := p.solde(Pays.PAYS)
	cm.nom_en_attente = "Les Granges"
	var mc2 := bs.place("maison_commune", Vector2i(1500, 0), 0)
	var v2 := cm.village_du_batiment(mc2)
	_check(mc2 > 0 and v2 >= 0 and v2 != v1, "Les Granges fondé")
	var capital2 := p.solde(v2)
	_check(capital2 == mini(ReglagesPartie.prix(Pays.CAPITAL_VILLE), pays_av2 - prix_mc), "capital des Granges : %s" % BuildingSystem.format_money(capital2))
	_check(pays_av2 - p.solde(Pays.PAYS) == prix_mc + capital2, "le pays paie la Maison de commune + le capital")
	_check(p.selection == v1, "on gère toujours Valfleuri")

	print("La ville gérée suit la caméra :")
	p.foyer = func() -> Vector2: return Vector2(1500, 0)
	p._t = 0.0
	await process_frame
	await process_frame
	_check(p.selection == v2 and bs.money == capital2, "caméra sur Les Granges : sa caisse s'affiche")
	p.choisir(v1, true)
	p._t = 0.0
	await process_frame
	_check(p.selection == v1 and p.epingle, "Valfleuri épinglée : elle ne suit plus la caméra")
	p.liberer()
	p.foyer = func() -> Vector2: return Vector2(0, 5000)

	print("Subventions et reversements :")
	var a1 := p.solde(v1)
	var ap := p.solde(Pays.PAYS)
	_check(p.subventionner(v1, 500_000) == "", "subvention de 500 k€")
	_check(p.solde(v1) == a1 + 500_000 and p.solde(Pays.PAYS) == ap - 500_000, "argent passé du pays à Valfleuri")
	_check(p.reverser(v1, 100_000) == "" and p.solde(Pays.PAYS) == ap - 400_000, "Valfleuri reverse 100 k€")
	_check(p.subventionner(v2, p.solde(Pays.PAYS) + 1) != "", "pas de subvention plus grosse que la caisse")
	_check(p.journal.size() >= 3, "journal des virements (%d)" % p.journal.size())

	print("Un budget par ville :")
	p.choisir(v1)
	bud.set_taux("foncier", 1.5)
	bud.emprunter(500_000, 10)
	_check(bud.emprunts.size() == 1, "Valfleuri emprunte 500 k€")
	p.choisir(v2)
	_check(is_equal_approx(float(bud.taux.foncier), 1.0) and bud.emprunts.is_empty(), "Les Granges : ses propres impôts, sans emprunt")
	p.choisir(v1)
	_check(is_equal_approx(float(bud.taux.foncier), 1.5) and bud.emprunts.size() == 1, "Valfleuri retrouve ses impôts et son emprunt")
	var b1 := bud.bilan_mensuel(v1)
	_check(float(b1.depenses.get("Remboursement des emprunts", 0.0)) > 0.0, "mensualité dans le bilan de Valfleuri")
	var bp := bud.bilan_mensuel(Pays.PAYS)
	_check(bp.has("recettes") and bp.has("depenses"), "bilan du pays")

	print("Une journée :")
	var j0 := bud.jour_total
	var s1 := p.solde(v1)
	bud.pay_day()
	_check(bud.jour_total == j0 + 1, "un jour passé")
	_check(p.selection == v1 and bud.cle == v1 and bs.money == p.solde(v1), "on revient sur la ville gérée")
	_check(p.solde(v1) != s1, "la caisse de Valfleuri a bougé (mensualité)")
	_check(not bud.etat_de(v1).get("mois", {}).is_empty(), "comptes du mois de Valfleuri")

	print("Impôt national et dotation :")
	p.set_taux_national(0.25)
	_check(is_equal_approx(p.taux_national, 0.25), "impôt national à 25 %")
	p.set_taux_national(0.9)
	_check(is_equal_approx(p.taux_national, Pays.TAUX_NATIONAL_MAX), "plafonné à 30 %")
	p.set_dotation(0.0)
	_check(is_zero_approx(float(bud.flux_ville(v1).dotation)), "dotation coupée")
	p.set_dotation(1.0)
	var paie := p.solde(Pays.PAYS)
	p._poser(Pays.PAYS, -1)
	_check(is_zero_approx(p.facteur_dotation()), "pays à sec : plus de dotation")
	p._poser(Pays.PAYS, paie)

	print("Recettes globales partagées :")
	var r1 := p.solde(v1)
	var r2 := p.solde(v2)
	Pays.crediter(bs, 1000)
	_check(p.solde(v1) + p.solde(v2) == r1 + r2 + 1000, "1 000 € partagés entre les villes")

	print("Sauvegarde :")
	var d := p.to_dict()
	var bd := bud.to_dict()
	var soldes := {}
	for k in p.cles():
		soldes[k] = p.solde(k)
	bud.from_dict(bd)
	p.from_dict(d)
	var memes := true
	for k in soldes:
		if p.solde(k) != int(soldes[k]):
			memes = false
	_check(memes, "toutes les caisses retrouvées")
	p.choisir(v1)
	_check(bud.emprunts.size() == 1 and is_equal_approx(float(bud.taux.foncier), 1.5), "budget de Valfleuri retrouvé")
	p.choisir(v2)
	_check(bud.emprunts.is_empty(), "budget des Granges retrouvé")

	print("Ancienne partie (une seule caisse) :")
	var tout := 0
	for k in p.cles():
		tout += p.solde(k)
	p.activer(Pays.PAYS)
	bs.money = tout
	p.from_dict({})
	var villes := 0
	for vid in cm.villages:
		villes += p.solde(int(vid))
	_check(villes + p.solde(Pays.PAYS) == tout and absi(p.solde(Pays.PAYS) - roundi(tout * Pays.PART_PAYS_ANCIENNE)) <= 2, "80 % aux villes, 20 % au pays")

	print("Fusion :")
	cm.calculer_stats()
	cm.stats[v1].palier = 4
	cm.croissance()
	_check(cm.voisins(v1, v2), "les deux villes se touchent")
	var total_avant := p.solde(v1) + p.solde(v2)
	var keep := cm.fusionner(v1, v2)
	var gone := v2 if keep == v1 else v1
	_check(keep >= 0 and p.solde(keep) == total_avant and not p.comptes.has(gone), "les deux caisses n'en font plus qu'une")
	_check(p.selection == keep, "la ville gérée est la commune fusionnée")

	print("Panneau Maj+P :")
	var panel: PaysPanel = scene.pays_panel
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.physical_keycode = KEY_P
	ev.shift_pressed = true
	panel._unhandled_key_input(ev)
	_check(panel.is_open(), "Maj+P ouvre le panneau")
	_check(panel._body.get_child_count() > 6, "onglet Villes rempli")
	panel.show_view("pays")
	_check(panel._body.get_child_count() > 6, "onglet Caisse du pays rempli")
	panel.show_view("journal")
	_check(panel._body.get_child_count() >= 1, "onglet Virements")
	var cat_ok := false
	for c in TerreHud.CATEGORIES:
		if String(c.id) == "pays" and String(c.get("key", "")) == "Maj+P":
			cat_ok = true
	_check(cat_ok, "bouton Pays dans le menu Ville")
	panel.set_open(false)
	scene._refresh_stats()

	print("Nouvelle région :")
	scene._on_origin_changed(45.6, 6.5)
	_check(p.comptes.is_empty() and p.actif == Pays.PAYS, "une seule caisse à nouveau")

	print("RÉSULTAT : ", "OK" if ok else "ÉCHEC")
	quit(0 if ok else 1)
