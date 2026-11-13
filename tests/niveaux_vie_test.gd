extends SceneTree
## Test des niveaux de vie (Maj+N) : niveau d'arrivée, besoins qui manquent,
## descente, montée jour après jour, déménagement vers un logement plus cossu,
## effets (courses, sorties, intérêts, taxe foncière, achats dans les commerces),
## avis des habitants, CV, succès, panneau, carte, sauvegarde.
## Usage : godot --headless --path . --script res://tests/niveaux_vie_test.gd

var ok := true


func _initialize() -> void:
	_run.call_deferred()
	create_timer(300.0).timeout.connect(func() -> void:
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


func _place(bs: BuildingSystem, id: String, x: int, north := true, off := 6) -> int:
	var d := int(BuildingCatalog.get_type(id).d)
	var c := Vector2i(x, -(d / 2 + off) if north else d / 2 + off)
	return bs.place(id, c, bs.best_rotation(id, c))


## Une ville où tout est parfait : tous les besoins couverts, revenus suffisants.
class NiveauxParfaits:
	extends NiveauxVie
	var sauf: Array = []

	func besoin(_hid: int, id: String) -> bool:
		return not sauf.has(id)

	func revenu_suffit(_hid: int, _n: int) -> bool:
		return true


func _run() -> void:
	Creations.persist = false
	BatimentsVie.chantiers = false
	ReglagesPartie.actuel = ReglagesPartie.preset("normal")
	ReglagesPartie.actuel.construction_instantanee = true
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var transport: TransportSystem = scene.get_node("Transport")
	var bs: BuildingSystem = scene.get_node("Batiments")
	var amb: DayNight = scene.get_node("Ambiance")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.view_radius_override = 1150.0
	world.set_origin(46.5, 6.6)
	for i in 3000:
		await process_frame
		if i >= 120 and world.missing_chunk_count() == 0 and world._dirty.is_empty() and world._jobs.is_empty():
			break
	amb.set_speed(0)
	var pop: Population = scene.population
	var nvx: NiveauxVie = scene.niveaux_vie
	_check(nvx != null and NiveauxVie.instance == nvx and nvx.is_in_group("avis_sources"), "module NiveauxVie dans la scène, branché à l'avis")
	_check(scene.niveaux_vie_panel != null, "panneau Maj+N créé")
	var ids := Calques.liste().map(func(c) -> String: return String(c.id))
	_check(ids.has("habitants_niveaux"), "carte « Niveaux de vie » dans le panneau Cartes")
	# Le test fait passer les jours lui-même.
	nvx.set_process(false)
	pop.arrivals = false

	print("Arrivée :")
	bs.money = 2_000_000_000
	var y := world.cell_height(Vector2i(0, 0))
	var road := transport.build_segment("departementale", Vector3(-600, y, 0), Vector3(600, y, 0))
	_check(road.ok, "une route")
	var m1 := _place(bs, "maison", -300)
	var m2 := _place(bs, "maison", -200)
	var libre := _place(bs, "maison", 300, false)
	var flats := _place(bs, "immeuble", 100)
	_check(m1 > 0 and m2 > 0 and libre > 0 and flats > 0, "trois maisons et un immeuble")
	pop._sync_buildings()
	var h1 := pop.spawn_household(m1, "couple")
	var h2 := pop.spawn_household(m2, "famille")
	var h3 := pop.spawn_household(flats, "seul")
	_check(h1 >= 0 and h2 >= 0 and h3 >= 0, "trois foyers")
	_check(NiveauxVie.niveau(pop.households[h1]) == -1 and is_equal_approx(NiveauxVie.coef_taxe(pop.households[h1]), 1.0),
		"pas encore évalué : coefficients neutres")
	nvx.evaluer_tout()
	for hid in [h1, h2, h3]:
		var n := NiveauxVie.niveau(pop.households[hid])
		_check(n >= 0 and n <= NiveauxVie.NIVEAU_ARRIVEE_MAX, "foyer %d arrive au niveau « %s »" % [hid, NiveauxVie.nom(n)])
	_check(nvx.manques_pour(h1, 1).has("nourriture"), "sans commerce : « de quoi manger » manque (%s)" % ", ".join(nvx.manques_pour(h1, 1)))
	_check(NiveauxVie.niveau(pop.households[h1]) == 0, "sans commerce, le foyer reste Précaire")
	_check(nvx.manques(h1).has("nourriture") and nvx.texte_manques(h1).contains("de quoi manger"), "ce qui bloque la montée est expliqué")
	_check(nvx.plafond_logement(m1) >= 3 and nvx.plafond_logement(m1) > NiveauxVie.NIVEAU_ARRIVEE_MAX - 1, "une maison permet d'aller au moins jusqu'à Aisé (%d)" % nvx.plafond_logement(m1))
	var ruc := nvx.revenu_uc(h2)
	_check(ruc >= 0.0, "revenu par part de la famille : %d €" % roundi(ruc))

	print("Effets :")
	var h: Dictionary = pop.households[h1]
	h.ep = 100000.0
	h.nv = 0
	var bas := pop.household_budget(h1)
	var tf_bas := float(pop.city_budget().recettes["Taxe foncière"])
	h.nv = 4
	var haut := pop.household_budget(h1)
	var tf_haut := float(pop.city_budget().recettes["Taxe foncière"])
	_check(float(haut.courses) > float(bas.courses) * 1.5, "courses : %d € (précaire) → %d € (très aisé)" % [roundi(float(bas.courses)), roundi(float(haut.courses))])
	_check(float(bas.sorties) == 0.0 and float(haut.sorties) == 900.0, "sorties : 0 € → %d € pour deux adultes" % roundi(float(haut.sorties)))
	_check(float(bas.placements) == 0.0 and absf(float(haut.placements) - 100000.0 * NiveauxVie.PLACEMENT / 12.0) < 0.01,
		"intérêts de l'épargne dès Aisé : %d € par mois" % roundi(float(haut.placements)))
	_check(float(haut.revenus) > float(bas.revenus), "les intérêts comptent dans les revenus")
	_check(tf_haut > tf_bas, "taxe foncière : %d € → %d €" % [roundi(tf_bas), roundi(tf_haut)])
	var prod: Production = scene.production
	h.nv = 0
	var need_bas := float(prod.daily_needs().get("vetements", 0.0))
	h.nv = 4
	var need_haut := float(prod.daily_needs().get("vetements", 0.0))
	_check(need_haut > need_bas, "les foyers aisés achètent plus de vêtements (%.5f t → %.5f t par jour)" % [need_bas, need_haut])
	h.ep = 5000.0

	print("Descente :")
	h.nv = 2
	h.nvp = 0.0
	for i in 9:
		nvx.jour_complet()
	_check(int(h.nv) == 2 and float(h.nvp) < -0.5, "un besoin manque : il recule sans encore descendre (%.2f)" % float(h.nvp))
	nvx.jour_complet()
	_check(int(h.nv) == 1, "au bout de 10 jours, il redescend en « %s »" % NiveauxVie.nom(int(h.nv)))
	_check(int(nvx.totaux.descentes) >= 1 and nvx.recents.has(h1), "descente comptée")
	var adulte: Dictionary = pop.persons[h.m[0]]
	var cv_niveau := false
	for e in adulte.cv:
		if String(e[1]) == "niveau":
			cv_niveau = true
	_check(cv_niveau, "étape « niveau » au CV")
	var av: Array = nvx._f_avis(adulte)
	_check(float(av[0]) < 0.0, "avis : %s" % ", ".join(av[1]))

	print("Montée (ville parfaite) :")
	var parfait := NiveauxParfaits.new()
	parfait.setup(pop, prod, bs)
	var h4: Dictionary = pop.households[h2]
	h4.nv = 0
	h4.nvp = 0.0
	var jours := 0
	var etapes := []
	while int(h4.nv) < 4 and jours < 80:
		parfait.jour_complet()
		jours += 1
		if etapes.size() < int(h4.nv):
			etapes.append(jours)
	_check(int(h4.nv) == 4, "Très aisé en %d jours (étapes aux jours %s)" % [jours, str(etapes)])
	_check(etapes.size() == 4 and int(etapes[0]) == 4 and int(etapes[1]) - int(etapes[0]) == 7, "4 jours pour Modeste, 7 pour Classe moyenne")
	_check(float(parfait._f_avis(pop.persons[h4.m[0]])[0]) > 0.0, "avis : le foyer vit de mieux en mieux")
	_check(parfait.texte_foyer(h2).contains("Très aisé"), "fiche : %s" % parfait.texte_foyer(h2))

	print("Déménagement :")
	var h5: Dictionary = pop.households[h3]
	h5.nv = 2
	h5.nvp = 0.0
	parfait.sauf = ["logement"]
	parfait.evaluer(h3, false)
	_check(parfait.manques(h3) == ["logement"], "seul le logement bloque")
	var moved := parfait._demenager(h3, 3)
	_check(moved and int(h5.b) == libre, "déménage dans la maison libre (%s)" % pop.building_name(int(h5.b)))
	_check(int(parfait.totaux.demenagements) == 1, "déménagement compté")
	parfait.free()

	print("Bilan et panneau :")
	var b := nvx.bilan()
	_check(int(b.total) == 3 and (b.foyers as Array).size() == 5, "bilan : %s" % str(b.foyers))
	_check(nvx.part_au_moins(0) == 1.0, "part des foyers")
	var panel: NiveauxViePanel = scene.niveaux_vie_panel
	panel.set_open(true)
	for v in ["ville", "besoins", "foyers"]:
		panel.show_view(v)
		await process_frame
		_check(panel._body.get_child_count() > 3, "vue « %s » du panneau" % v)
	panel.set_open(false)
	_check(Objectifs.SUCCES.has("classe_moyenne") and Objectifs.SUCCES.has("beaux_quartiers"), "deux succès")

	print("Sauvegarde :")
	_check(scene.save_sections().has("niveaux_vie"), "section « niveaux_vie » dans la sauvegarde")
	var d := JSON.parse_string(JSON.stringify(nvx.to_dict())) as Dictionary
	var avant := int(pop.households[h2].nv)
	pop.households[h2].nv = 0
	nvx.from_dict(d)
	_check(int(pop.households[h2].nv) == avant, "niveau relu (%s)" % NiveauxVie.nom(avant))
	_check(int(nvx.totaux.descentes) >= 1, "totaux relus")

	print("NIVEAUX DE VIE TEST OK" if ok else "NIVEAUX DE VIE TEST ÉCHEC")
	quit(0 if ok else 1)
