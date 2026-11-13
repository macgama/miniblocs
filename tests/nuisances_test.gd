extends SceneTree
## Test de la pollution (air, eau), du bruit et de la valeur des terrains :
## sources (usine, routes, autoroute, autres systèmes), arbres et parcs, santé,
## satisfaction, loyers, déménagements, zonage, réglage Admin, cartes (touche N),
## sauvegarde.
## Usage : godot --headless --path . --script res://tests/nuisances_test.gd

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


func _place(bs: BuildingSystem, id: String, x: int, north := true, off := 6) -> int:
	var d := int(BuildingCatalog.get_type(id).d)
	var c := Vector2i(x, -(d / 2 + off) if north else d / 2 + off)
	return bs.place(id, c, bs.best_rotation(id, c))


class SourceTest:
	extends Node
	var pos := Vector3.ZERO
	func pollution_sources() -> Array:
		return [{"pos": pos, "rayon": 300.0, "air": 0.0, "eau": 0.0, "bruit": 0.0, "odeur": 0.9, "nom": "décharge d'essai"}]


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
	var nz: Nuisances = scene.nuisances
	var pop: Population = scene.population
	_check(nz != null and Nuisances.instance == nz, "module Nuisances dans la scène")
	_check(pop.attrait_logement.is_valid() and scene.zones.extra_chance.is_valid() and scene.vie_batiments.extra_usure.is_valid(),
		"branché aux arrivées, au zonage et à l'usure")
	pop.arrivals = false

	print("Sources :")
	bs.money = 2_000_000_000
	var y := world.cell_height(Vector2i(0, 0))
	var road := transport.build_segment("departementale", Vector3(-950, y, 0), Vector3(950, y, 0))
	_check(road.ok, "départementale est-ouest %s" % str(road.get("reason", road.get("error", ""))))
	var hw := transport.build_segment("autoroute", Vector3(-600, y, 800), Vector3(600, y, 800))
	_check(hw.ok, "autoroute au sud %s" % str(hw.get("reason", hw.get("error", ""))))
	var steel := _place(bs, "acierie", -780)
	var near := _place(bs, "maison", -780, false)
	var far := _place(bs, "maison", 780, false)
	var park := _place(bs, "parc", 780)
	var flats := _place(bs, "immeuble", 450, false)
	_check(steel > 0 and near > 0 and far > 0 and park > 0 and flats > 0, "aciérie, deux maisons, un parc, un immeuble")
	pop._sync_buildings()
	nz.recalculer()
	print("  premier calcul en %d ms (%d sources, %d tuiles)" % [nz.last_ms, nz.stats.sources, nz.stats.tuiles])
	nz.recalculer()
	print("  calcul suivant en %d ms" % nz.last_ms)
	_check(nz.last_ms < 400, "calcul assez rapide")
	var pn := nz._centre(near)
	var pf := nz._centre(far)
	_check(nz.air(pn) > 0.3 and nz.air(pn) > nz.air(pf) + 0.25, "air pollué près de l'aciérie (%.2f), propre loin (%.2f)" % [nz.air(pn), nz.air(pf)])
	_check(nz.eau(pn) > nz.eau(pf) + 0.1, "eau polluée près de l'aciérie (%.2f contre %.2f)" % [nz.eau(pn), nz.eau(pf)])
	var on_hw := Vector3(0, y, 825)
	var quiet := Vector3(0, y, 420)
	_check(nz.bruit(on_hw) > nz.bruit(quiet) + 0.3, "bruit au bord de l'autoroute (%d dB) contre %d dB au calme" % [Nuisances.decibels(nz.bruit(on_hw)), Nuisances.decibels(nz.bruit(quiet))])
	_check(nz.bruit(on_hw, 1) < nz.bruit(on_hw, 0) and nz.bruit(on_hw, 1) > 0.2, "moins de bruit la nuit, mais encore (%d dB)" % Nuisances.decibels(nz.bruit(on_hw, 1)))
	_check(nz.bruit(Vector3(0, y, 30)) > nz.bruit(quiet), "la départementale fait du bruit")
	_check(Nuisances.emission_of("centrale_charbon").air == 1.0 and Nuisances.emission_of("centrale_solaire").air == 0.0
		and Nuisances.emission_of("maison").is_empty(), "table des émissions (charbon, solaire, maison)")
	_check(float(Nuisances.emission_of("porcherie").odeur) > 0.5 and float(Nuisances.emission_of("discotheque").bruit) > 0.3, "porcherie : odeur ; discothèque : bruit")

	print("Autres systèmes :")
	var spot := Vector3(-300, y, 400)
	var before := nz.bruit(spot)
	nz.ajouter_source("essai", "bruit", spot, 1.0, 200.0)
	nz.recalculer()
	_check(nz.bruit(spot) > before + 0.4, "ajouter_source : bruit d'un chantier d'essai (%.2f)" % nz.bruit(spot))
	nz.retirer_source("essai")
	nz.recalculer()
	_check(absf(nz.bruit(spot) - before) < 0.01, "retirer_source : le bruit s'en va")
	var src := SourceTest.new()
	src.pos = spot
	src.add_to_group("pollution_sources")
	scene.add_child(src)
	nz.recalculer()
	_check(float(nz.au_point(spot).gene) > 0.4, "groupe pollution_sources : odeur d'une décharge (%.2f)" % float(nz.au_point(spot).gene))
	src.queue_free()
	await process_frame
	nz.recalculer()

	print("Arbres et parcs :")
	var by_park := Vector3(780, y, -40)
	_check(float(nz.au_point(by_park).vert) > 0.5, "verdure autour du parc (%.2f)" % float(nz.au_point(by_park).vert))

	print("Valeur des terrains :")
	var vn := nz.valeur(pn)
	var vf := nz.valeur(pf)
	_check(vf > vn + 0.4, "terrain cher près du parc (%.2f) et bon marché près de l'aciérie (%.2f)" % [vf, vn])
	_check(nz.prix_m2(pf) > 3000.0 and nz.prix_m2(pn) < 2000.0, "prix : %d €/m² contre %d €/m²" % [roundi(nz.prix_m2(pf)), roundi(nz.prix_m2(pn))])
	_check(nz.loyer(far) > nz.loyer(near) * 1.5, "loyers : %d € contre %d €" % [roundi(nz.loyer(far)), roundi(nz.loyer(near))])
	_check(nz.usure_rythme(near) > 1.0 and nz.usure_rythme(far) < 1.0, "le quartier dévalué s'use plus vite")
	_check(nz.attrait(far) > nz.attrait(near) + 0.3, "les arrivants préfèrent le quartier agréable (%.2f contre %.2f)" % [nz.attrait(far), nz.attrait(near)])

	print("Habitants :")
	var h_near := pop.spawn_household(near)
	var h_far := pop.spawn_household(far)
	_check(h_near >= 0 and h_far >= 0, "un foyer dans chaque maison")
	var pn_id: int = pop.households[h_near].m[0]
	var p_near: Dictionary = pop.persons[pn_id]
	_check(absf(pop.vie.pollution_at(near) - nz.sante(near)) < 0.0001 and nz.sante(near) > 0.3, "santé : pollution au logement %.2f" % nz.sante(near))
	var f_near := float(pop.vie.health(p_near).f)
	var f_far := float(pop.vie.health(pop.persons[pop.households[h_far].m[0]]).f)
	_check(f_near > f_far, "plus de risques de maladie près de l'aciérie (%.2f contre %.2f)" % [f_near, f_far])
	var sat: Dictionary = pop.satisfaction(p_near)
	var has_air := false
	for w in sat.why:
		has_air = has_air or String(w).contains("air pollué")
	_check(has_air, "satisfaction : « air pollué » parmi les raisons")
	_check(nz.avis_facteurs().size() == 3 and nz.is_in_group("avis_sources"), "facteurs pour l'avis des habitants")
	var bud := pop.household_budget(h_far)
	_check(absf(float(bud.loyer) - nz.loyer(far)) < 1.0, "le budget du foyer paie le loyer du quartier (%d €)" % roundi(float(bud.loyer)))
	var tf_before := float(pop.city_budget().recettes["Taxe foncière"])
	var keep := float(nz.coef_bat[far])
	nz.coef_bat[far] = keep * 2.0
	_check(float(pop.city_budget().recettes["Taxe foncière"]) > tf_before, "la taxe foncière suit la valeur")
	nz.coef_bat[far] = keep

	print("Valeur qui évolue, déménagements :")
	nz.coef_bat[near] = 2.5
	for i in 30:
		nz.jour_suivant()
	_check(absf(nz.coef_foncier(near) - float(nz._cible[near])) < 0.2, "la valeur rejoint celle du quartier en un mois (%.2f)" % nz.coef_foncier(near))
	# Loyer hors de prix : le foyer part dans un logement moins cher (l'immeuble est vide).
	nz._cible[far] = 3.0
	nz.coef_bat[far] = 3.0
	nz._cible[flats] = 0.5
	nz.coef_bat[flats] = 0.5
	if int(pop.households[h_far].b) != far:
		pop.move_household(h_far, far)
	nz._cher.clear()
	# Loyer de base du logement à hauteur des revenus du foyer : loyer = 3 × revenus.
	pop.known[far]["loyer"] = maxf(500.0, nz._revenus(h_far))
	var te := nz.taux_effort(h_far)
	for i in Nuisances.JOURS_AVANT_DEMENAGER + 2:
		nz.jour_suivant()
	pop.known[far].erase("loyer")
	_check(te > Nuisances.TAUX_EFFORT_MAX and int(pop.households[h_far].b) != far,
		"loyer à %d %% des revenus : le foyer déménage (dans %s)" % [roundi(te * 100.0), pop.building_name(int(pop.households[h_far].b))])

	print("Zonage :")
	var cheap := Vector3(-780, y, 60)
	var chic := Vector3(780, y, 60)
	var types := {"maison": 4, "villa": 2, "tour_habitation": 1, "immeuble": 2}
	_check(nz.chance_pousse("villa", chic, types) > nz.chance_pousse("villa", cheap, types),
		"les villas poussent plutôt dans le quartier cher (%.2f contre %.2f)" % [nz.chance_pousse("villa", chic, types), nz.chance_pousse("villa", cheap, types)])

	print("Cartes (touche N) :")
	var ids := []
	for c in Calques.liste():
		ids.append(c.id)
	for id in ["nuisances_air", "nuisances_eau", "nuisances_bruit", "nuisances_nuit", "immobilier_valeur", "immobilier_loyers"]:
		_check(ids.has(id), "calque %s" % id)
	var panel: CartesPanel = scene.cartes_panel
	panel.set_open(true)
	panel.choisir("nuisances_air")
	var calque: CalqueCouleur = scene.get_node("CalqueAir")
	scene.rig.position = Vector3(-780, y, 0)
	calque.rebuild(Vector2(-780, 0))
	_check(Calques.actif() == "nuisances_air" and calque.visible and calque.mesh != null, "carte de l'air dessinée")
	panel.choisir("immobilier_loyers")
	var cl: CalqueCouleur = scene.get_node("CalqueLoyers")
	cl.rebuild(Vector2(0, 0))
	_check(not calque.visible and cl.visible and cl.mesh != null, "une seule carte à la fois (loyers)")
	_check(panel._resume.text.contains("Loyer moyen"), "résumé sous les cartes")
	panel.set_open(false)
	_check(Calques.actif() == "" and not cl.visible, "fermer le panneau éteint la carte")

	print("Admin :")
	ReglagesPartie.actuel.pollution = 0
	nz.recalculer()
	_check(nz.air(pn) == 0.0 and nz.bruit(on_hw) == 0.0, "pollution désactivée : ni air pollué ni bruit")
	ReglagesPartie.actuel.pollution = 2
	ReglagesPartie.actuel.pollution_sante = false
	nz.recalculer()
	_check(nz.sante(near) == 0.0 and nz.air(pn) > 0.3, "santé non touchée, mais la pollution reste visible")
	ReglagesPartie.actuel.pollution_sante = true
	var r := ReglagesPartie.new()
	r.from_dict({"pollution": 3, "pollution_sante": false})
	_check(r.pollution == 3 and not r.pollution_sante and r.to_dict().has("pollution"), "réglages lus et écrits")

	print("Sauvegarde :")
	_check(scene.save_sections().has("nuisances"), "section « nuisances » dans la sauvegarde")
	var d := JSON.parse_string(JSON.stringify(nz.to_dict())) as Dictionary
	var c_near := nz.coef_foncier(near)
	nz.from_dict(d)
	_check(absf(nz.coef_foncier(near) - c_near) < 0.01, "valeurs des bâtiments relues")
	nz.recalculer()
	_check(nz.air(pn) > 0.3, "tout se recalcule après le chargement")

	print("NUISANCES TEST OK" if ok else "NUISANCES TEST ÉCHEC")
	quit(0 if ok else 1)
