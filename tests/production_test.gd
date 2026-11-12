extends SceneTree
## Test des ressources et de l'économie locale : carte des ressources, vraies
## régions minières, pose des sites, chaînes (bois → planches, céréales →
## farine → pain) livrées par camion avec des chauffeurs-livreurs, commerces,
## rayons vides, import et export, comptes des entreprises, sauvegarde.
## Usage : godot --headless --path . --script res://tests/production_test.gd

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


func _at(date: String, hour: float) -> float:
	return Time.get_unix_time_from_datetime_string(date + "T00:00:00") + (hour - 1.0) * 3600.0


## Pose au nord (côté < 0) ou au sud de la route z = 0, orientation vers la route.
func _place(bs: BuildingSystem, id: String, x: int, north := true) -> int:
	var d := int(BuildingCatalog.get_type(id).d)
	var c := Vector2i(x, -(d / 2 + 6) if north else d / 2 + 6)
	return bs.place(id, c, bs.best_rotation(id, c))


func _run() -> void:
	Creations.persist = false
	print("Régions minières réelles :")
	var lorraine := GisementsMonde.near(49.30, 5.95, 0.0)
	var names := []
	for p in lorraine:
		names.append(p.name)
	_check(names.has("Bassin ferrifère lorrain"), "Lorraine : bassin ferrifère trouvé")
	_check(absf(GisementsMonde.distance_km(48.8566, 2.3522, 45.7640, 4.8357) - 392.0) < 5.0, "distance Paris-Lyon ≈ 392 km")
	_check(GisementsMonde.near(46.5, -30.0, 100.0).is_empty(), "milieu de l'Atlantique : aucune province")
	for p in GisementsMonde.PROVINCES:
		if not Ressources.SOUS_SOL.has(p[0]):
			_check(false, "province de ressource inconnue : %s" % p[1])

	# Bâtiments prêts tout de suite (les chantiers sont testés dans batiments_test).
	BatimentsVie.chantiers = false
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var transport: TransportSystem = scene.get_node("Transport")
	var bs: BuildingSystem = scene.get_node("Batiments")
	var amb: DayNight = scene.get_node("Ambiance")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	# Forêt à l'ouest de l'origine, champs à l'est.
	const LAT := 49.15
	const LON := 6.75
	world.land.offline_generator = func(_lat: float, lon: float) -> int: return 10 if lon < LON else 40
	world.view_radius_override = 1100.0
	world.set_origin(LAT, LON)
	# Attend que le relief soit chargé partout (plus long avec les plantes).
	for i in 3000:
		await process_frame
		if i >= 150 and world.missing_chunk_count() == 0 and world._dirty.is_empty() and world._jobs.is_empty():
			break
	var prod: Production = scene.production
	var pop: Population = scene.population
	_check(prod != null and prod.population == pop and bs.extra_check.is_valid(), "production branchée dans la scène")
	amb.set_speed(0)
	amb.unix_time = _at("2026-03-10", 10.0)

	print("Carte des ressources :")
	var carte := prod.carte
	var here := carte.region_provinces()
	var coal := false
	for p in here:
		coal = coal or p.res == "charbon"
	_check(coal, "bassin houiller lorrain dans la région (%d provinces proches)" % here.size())
	var west := carte.all_at(Vector2i(-300, 50))
	var east := carte.all_at(Vector2i(300, 50))
	_check(float(west.bois) > 0.8 and float(east.bois) < 0.1, "bois : forêt à l'ouest (%.2f), rien dans les champs (%.2f)" % [west.bois, east.bois])
	_check(float(east.fertilite) > 0.8, "champs cultivables à l'est (%.2f)" % east.fertilite)
	_check(float(east.poisson) == 0.0 and float(east.bauxite) == 0.0, "ni poisson ni bauxite en Lorraine")
	# Le meilleur point de charbon dans 1,6 × 1,6 km autour de l'origine.
	var v := carte.sample("charbon", -800, -800, 16, 16, 100.0)
	var best := 0.0
	var best_i := 0
	for i in v.size():
		if v[i] > best:
			best = v[i]
			best_i = i
	_check(best > 0.25, "gisement de charbon trouvé près de l'origine (richesse %.2f)" % best)
	var v2 := carte.sample("charbon", -800, -800, 16, 16, 100.0)
	_check(v == v2, "gisements déterministes (même tirage à chaque fois)")
	var pilbara := CarteRessources.new(null)
	var pil_best := 0.0
	var paris_best := 0.0
	for i in 40:
		for j in 40:
			pil_best = maxf(pil_best, _deposit_at(pilbara, "fer", -22.5 + i * 0.01, 118.5 + j * 0.01, -22.5, 118.5))
			paris_best = maxf(paris_best, _deposit_at(pilbara, "fer", 48.85 + i * 0.01, 2.35 + j * 0.01, 48.85, 2.35))
	_check(pil_best > 0.6 and paris_best <= 0.31, "fer : riche au Pilbara (%.2f), petits gisements au plus à Paris (%.2f)" % [pil_best, paris_best])

	print("Pose des sites :")
	bs.money = 1_000_000_000
	var y := world.cell_height(Vector2i(0, 0))
	var road := transport.build_segment("route", Vector3(-600, y, 0), Vector3(600, y, 0))
	_check(road.ok, "route est-ouest %s" % str(road.get("reason", road.get("error", ""))))
	var forest := _place(bs, "exploitation_forestiere", -250)
	_check(forest > 0, "exploitation forestière dans la forêt")
	_check(_place(bs, "exploitation_forestiere", 560) == -1, "exploitation forestière refusée au milieu des champs")
	var t := BuildingCatalog.get_type("port_peche")
	_check(not bs.check_place("port_peche", Vector2i(100, 30), 0).ok, "port de pêche refusé loin de l'eau")
	var sawmill := _place(bs, "scierie", -150)
	var farm := _place(bs, "ferme_cereales", 300)
	var mill := _place(bs, "moulin", 200)
	var bakery := _place(bs, "fournil", 130)
	_check(sawmill > 0 and farm > 0 and mill > 0 and bakery > 0, "scierie, ferme céréalière, moulin, boulangerie industrielle")
	var shop := _place(bs, "superette", 40, false)
	var homes := []
	for i in 9:
		homes.append(_place(bs, "immeuble", -500 + i * 50, false))
	_check(shop > 0 and not homes.has(-1), "supérette et 9 immeubles")
	var depot: Dictionary = transport.stations.place("depot", Vector3(470, 0, 6))
	_check(not depot.is_empty() and prod.export_stations() == 1, "dépôt de marchandises pour l'export")
	var boulanger := _place(bs, "boulangerie", 90, false)
	var carrier := _place(bs, "transporteur", -40, false)
	_check(boulanger > 0 and carrier > 0, "boulangerie de quartier et entreprise de transport routier")
	# Une supérette sur une route isolée : aucun camion ne peut l'atteindre.
	var yi := world.cell_height(Vector2i(0, 400))
	_check(transport.build_segment("route", Vector3(-120, yi, 400), Vector3(120, yi, 400)).ok, "route isolée")
	var lost := bs.place("superette", Vector2i(0, 414), bs.best_rotation("superette", Vector2i(0, 414)))
	_check(lost > 0, "supérette sur la route isolée")
	await process_frame
	prod._sync()
	var n_prod := 0
	for k in prod.sites:
		if String(prod.sites[k].kind) in ["extraction", "transformation"]:
			n_prod += 1
	_check(n_prod == 5, "5 sites de production (%d)" % n_prod)
	_check(String(prod.sites[shop].kind) == "commerce" and String(prod.sites[carrier].kind) == "logistique", "supérette = commerce, transporteur = logistique")
	_check(prod.node_of(shop) >= 0 and prod.node_of(lost) >= 0, "les commerces ont un quai sur la route")
	_check(not prod.gateways().is_empty(), "porte d'import et d'export : le dépôt")
	_check(float(prod.sites[forest].rich) > 0.8 and String(prod.sites[forest].res) == "bois", "la forêt est mesurée sous l'exploitation")

	print("Sans habitants, rien ne se produit :")
	prod.step_hours(24.0)
	_check(prod.total_stock().is_empty(), "stock vide")
	_check(String(prod.sites[forest].status).begins_with("Personne"), "statut : personne n'y travaille")

	print("Habitants et emplois :")
	pop._sync_buildings()
	for i in 96:
		pop.advance(300.0)
	var staff := (pop.by_job.get(forest, []) as Array).size()
	_check(staff > 0, "bûcherons embauchés : %d / 12" % staff)
	var jobs_ok := true
	for pid in pop.by_job.get(forest, []):
		jobs_ok = jobs_ok and ["bucheron", "conducteur_engins", "chauffeur"].has(String(pop.persons[pid].met))
	_check(jobs_ok, "métiers de l'exploitation forestière")

	print("Sans chauffeur-livreur, rien ne roule :")
	var saved_met := {}
	for pid in pop.persons:
		if String(pop.persons[pid].met) == "chauffeur":
			saved_met[pid] = "chauffeur"
			pop.persons[pid].met = "ouvrier"
	amb.unix_time = _at("2026-03-10", 0.5) # un mardi
	prod.clock = -1.0
	prod.last_day = prod._day_of(amb.unix_time)
	for h in 12:
		amb.unix_time += 3600.0
		prod.advance(3600.0)
	_check(prod.missions.is_empty(), "aucune livraison sans chauffeur")
	_check(String(prod.site_info(shop).status).contains("chauffeur"), "supérette : %s" % prod.site_info(shop).status)
	_check(float(prod.stock_of(farm, "cereales")) > 0.0, "les céréales restent à la ferme (%s)" % Ressources.format_t(prod.stock_of(farm, "cereales")))
	for pid in saved_met:
		pop.persons[pid].met = "chauffeur"
	var ds := prod.driver_stats()
	_check(int(ds.total) >= 1, "chauffeurs-livreurs en ville : %d" % int(ds.total))

	print("Économie locale :")
	var money0 := bs.money
	var max_trucks := 0
	var max_missions := 0
	for h in 24 * 8:
		amb.unix_time += 3600.0
		prod.advance(3600.0)
		transport.traffic.step(0.5)
		max_trucks = maxi(max_trucks, transport.traffic.delivery_count())
		max_missions = maxi(max_missions, prod.missions.size())
	var yd: Dictionary = prod.yesterday
	_check(max_missions > 0 and max_trucks > 0, "livraisons en cours (jusqu'à %d) et camions visibles sur la route (jusqu'à %d)" % [max_missions, max_trucks])
	_check(float(prod.yesterday.prod.get("planches", 0.0)) > 0.0, "la scierie fait des planches (%.1f t hier)" % float(prod.yesterday.prod.get("planches", 0.0)))
	_check(float(prod.yesterday.prod.get("cereales", 0.0)) > 0.0, "la ferme récolte des céréales (%.2f t hier)" % float(prod.yesterday.prod.get("cereales", 0.0)))
	_check(prod.stock_of(sawmill, "bois") > 0.0 or float(yd.conso.get("bois", 0.0)) > 0.0, "le bois arrive à la scierie par camion")
	_check(prod.stock_of(mill, "cereales") > 0.0 or float(yd.conso.get("cereales", 0.0)) > 0.0, "les céréales arrivent au moulin")
	_check(prod.stock_of(shop, "pain") > 0.0 or float(yd.vente.get("pain", 0.0)) > 0.0, "le pain de la boulangerie industrielle arrive à la supérette")
	_check(prod.stock_of(boulanger, "farine") > 0.0 or prod.stock_of(boulanger, "pain") > 0.0, "le boulanger reçoit sa farine et cuit son pain")
	_check(float(yd.vente.get("pain", 0.0)) > 0.0, "les habitants achètent le pain (%s hier)" % Ressources.format_t(float(yd.vente.get("pain", 0.0))))
	_check(float(yd.import.get("laitages", 0.0)) + float(prod.today.import.get("laitages", 0.0)) > 0.0 or prod.stock_of(shop, "laitages") > 0.0,
		"les laitages sans ferme laitière arrivent par import")
	var exported := 0.0
	for g in yd.export:
		exported += float(yd.export[g])
	for g in prod.today.export:
		exported += float(prod.today.export[g])
	_check(exported > 0.0 or prod.ledger.mois.has("Exportations") or prod.ledger.precedent.has("Exportations"), "le surplus part à l'export par camion")
	_check(String(prod.site_info(lost).status).contains("Rayons vides") and String(prod.site_info(lost).status).contains("Aucun fournisseur"),
		"supérette isolée : %s" % prod.site_info(lost).status)
	_check(float(prod.sites[farm].cash) > 0.0, "la ferme gagne de l'argent (%s)" % BuildingSystem.format_money(roundi(float(prod.sites[farm].cash))))
	_check(float(prod.sites[shop].mois.get("Ventes aux habitants", 0.0)) > 0.0 and float(prod.sites[shop].mois.get("Salaires", 0.0)) < 0.0,
		"comptes de la supérette : ventes et salaires")
	var tax := float(prod.ledger.mois.get("Impôt sur les bénéfices (pour la ville)", 0.0))
	_check(tax > 0.0, "la ville touche l'impôt sur les bénéfices (%s)" % BuildingSystem.format_money(roundi(tax)))
	_check(bs.money != money0, "la caisse de la ville bouge (%s)" % BuildingSystem.format_money(bs.money - money0))
	var why_all := []
	for pid in pop.persons:
		why_all.append_array(pop.satisfaction(pop.persons[pid]).why)
	var shops_reason := false
	for w in why_all:
		shops_reason = shops_reason or String(w).contains("commerces") or String(w).contains("rayons vides")
	_check(shops_reason, "la satisfaction des habitants dépend des commerces")

	print("Gisement non renouvelable :")
	var gx := float(best_i % 16) * 100.0 - 800.0 + 50.0
	var gz := float(best_i / 16) * 100.0 - 800.0 + 50.0
	var gy := world.cell_height(Vector2i(int(gx), int(gz)))
	_check(transport.build_segment("route", Vector3(gx - 120, gy, gz), Vector3(gx + 120, gy, gz)).ok, "route vers le gisement de charbon")
	var mc := Vector2i(int(gx), int(gz) - 26)
	var mine := bs.place("mine", mc, bs.best_rotation("mine", mc))
	_check(mine > 0, "mine posée sur le gisement")
	prod._sync()
	if mine > 0:
		_check(String(prod.sites[mine].res) == "charbon" and float(prod.sites[mine].reserve) > 0.0,
			"la mine extrait du charbon, réserve %s" % Ressources.format_t(float(prod.sites[mine].reserve)))
	var refused := ""
	for i in 16:
		for j in 16:
			var rect := Rect2i(Vector2i(-800 + i * 100, -800 + j * 100), Vector2i(40, 36))
			if refused == "" and float(carte.best_of(Ressources.MINERAIS, rect, 60.0).rich) == 0.0:
				refused = String(prod.check_site("mine", rect).get("reason", ""))
	_check(refused != "", "mine refusée sans gisement : « %s »" % refused)

	print("Repousse et bords de la carte :")
	var fs: Dictionary = prod.sites[forest]
	for d in 400:
		fs.work = 1.0
		prod._regrow()
	_check(absf(float(fs.vit) - 0.6) < 0.05, "forêt exploitée à plein : se stabilise vers 60 %% (%d %%)" % roundi(float(fs.vit) * 100.0))
	for d in 400:
		prod._regrow()
	_check(float(fs.vit) > 0.95, "forêt laissée tranquille : elle repousse (%d %%)" % roundi(float(fs.vit) * 100.0))
	var cap0 := prod.export_capacity()
	var nid := transport.network.add_node(Vector3(GameStart.REGION_SIZE * 0.5 - 100.0, 0, 0), TransportTypes.Mode.RAIL)
	_check(int(prod.edge_exits().get(TransportTypes.Mode.RAIL, 0)) == 1 and prod.export_capacity() >= cap0 + 799.0,
		"un rail qui sort par le bord de la carte exporte 800 t par jour")
	transport.network.nodes.erase(nid)

	print("Carte et panneau :")
	var overlay: RessourcesOverlay = scene.resource_overlay
	overlay.show_resource("bois")
	overlay.rebuild(Vector2(0, 0))
	_check(overlay.mesh != null and overlay.mesh.get_surface_count() == 1, "carte du bois dessinée sur le terrain")
	overlay.show_resource("")
	var panel: ProductionPanel = scene.production_panel
	for view in ["ressources", "stocks", "sites", "camions"]:
		panel.set_open(true)
		panel.show_view(view)
	_check(panel.is_open(), "panneau Production : ressources, stocks, sites")
	panel.set_open(false)

	print("Sauvegarde :")
	for h in 30:
		if not prod.missions.is_empty():
			break
		amb.unix_time += 3600.0
		prod.advance(3600.0)
	var n_sites := prod.sites.size()
	var n_missions := prod.missions.size()
	var d := prod.to_dict()
	var json := JSON.parse_string(JSON.stringify(d)) as Dictionary
	var stock_before: Dictionary = prod.total_stock()
	var reserve_before := float(prod.sites[mine].reserve) if mine > 0 else 0.0
	prod.from_dict(json)
	var same := true
	for g in stock_before:
		same = same and absf(float(prod.total_stock().get(g, 0.0)) - float(stock_before[g])) < 0.01
	_check(same and prod.sites.size() == n_sites, "stocks et sites relus (%d sites)" % prod.sites.size())
	_check(n_missions > 0 and prod.missions.size() == n_missions, "livraisons en cours relues (%d)" % n_missions)
	if mine > 0:
		_check(absf(float(prod.sites[mine].reserve) - reserve_before) < 1.0, "réserve de la mine relue")
	_check(scene.save_sections().has("production"), "section « production » dans la sauvegarde")

	print("PRODUCTION TEST OK" if ok else "PRODUCTION TEST ÉCHEC")
	quit(0 if ok else 1)


func _deposit_at(c: CarteRessources, res: String, lat: float, lon: float, olat: float, olon: float) -> float:
	c.provinces = GisementsMonde.near(olat, olon, CarteRessources.SEARCH_KM)
	return c.deposit(res, lat, lon)
