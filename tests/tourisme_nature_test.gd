extends SceneTree
## Test du tourisme v2 (nature) : sites naturels trouvés dans une grille de terrain
## (plage, falaises, lac, rivière, forêt, sommet), puis dans une vraie scène
## (lac et forêt du terrain), saisons, accès par la route, sentiers,
## aménagements (base nautique, parking de randonnée, poste de secours), recettes
## pour la ville, autocars qui roulent sur les routes, promeneurs au bord du lac,
## panneau.
## Usage : godot --headless --path . --script res://tests/tourisme_nature_test.gd

var ok := true

## Vendredi 17 juillet 2026, midi (UTC+2).
const VENDREDI := 1_784_282_400.0
## Vendredi 16 janvier 2026, midi.
const JANVIER := 1_768_561_200.0


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


func _run() -> void:
	_grille_tests()
	await _ville_tests()
	print("TEST OK" if ok else "TEST ÉCHEC")
	quit(0 if ok else 1)


## Une grille de 50 × 50 mailles de 200 m : la mer au sud, une côte basse puis des
## falaises, un lac, une rivière, une forêt, une montagne.
func _grille_tests() -> void:
	print("Grille :")
	var n := 50
	var h := PackedFloat32Array()
	var bio := PackedByteArray()
	h.resize(n * n)
	bio.resize(n * n)
	for j in n:
		for i in n:
			var k := i + j * n
			bio[k] = 40
			h[k] = 30.0
			if j >= 45:
				h[k] = -8.0
				bio[k] = 0
			elif j == 44:
				h[k] = 2.0 if i < 25 else 30.0
			# Le lac (4 × 4) et la rivière (1 × 12).
			if i >= 5 and i < 9 and j >= 5 and j < 9:
				bio[k] = 80
			if i == 20 and j >= 2 and j < 14:
				bio[k] = 80
			if i >= 30 and i < 40 and j >= 20 and j < 30:
				bio[k] = 10
			# Une montagne de 900 m au nord-est.
			var d := Vector2(i - 40, j - 8).length()
			h[k] += 900.0 * exp(-d * d / 18.0)
	var g := {"h": h, "bio": bio, "n": n, "x0": -5000.0, "z0": -5000.0, "pas": 200.0}
	var sites := SitesNaturels.analyser(g)
	var genres := {}
	for s in sites:
		genres[String(s.genre)] = s
	for gr in ["plage", "cote", "lac", "riviere", "foret", "sommet"]:
		_check(genres.has(gr), "%s trouvé(e) %s" % [SitesNaturels.nom_genre(gr), str(genres.get(gr, {}).get("nom", ""))])
	if genres.has("sommet"):
		var p: Vector3 = genres.sommet.pos
		_check(absf(p.x - (-5000.0 + 40.5 * 200.0)) < 1.0 and absf(p.z - (-5000.0 + 8.5 * 200.0)) < 1.0, "le sommet est au point le plus haut")
		_check(float(genres.sommet.taille) > 600.0, "il domine ses environs de %d m" % int(genres.sommet.taille))
	if genres.has("lac"):
		_check(float(genres.lac.taille) > 50.0, "lac de %d ha" % int(genres.lac.taille))
		var bord := true
		for q in genres.lac.points:
			var qi := floori(((q as Vector3).x + 5000.0) / 200.0)
			var qj := floori(((q as Vector3).z + 5000.0) / 200.0)
			bord = bord and (qi == 5 or qi == 8 or qj == 5 or qj == 8)
		_check(bord, "les points du lac sont sur la rive")
	if genres.has("plage") and genres.has("cote"):
		_check(float(genres.plage.base) > 0.5 and float(genres.plage.taille) > 3.0, "plage de %.1f km, %.1f points" % [float(genres.plage.taille), float(genres.plage.base)])
		_check(SitesNaturels.saison("plage", 8) > SitesNaturels.saison("plage", 1) * 5.0, "la plage attire l'été, pas l'hiver")
	var noms := {}
	var uniques := true
	for s in sites:
		uniques = uniques and not noms.has(String(s.nom))
		noms[String(s.nom)] = true
	_check(uniques, "pas deux fois le même nom")
	var again := SitesNaturels.analyser({"h": h, "bio": bio, "n": n, "x0": -5000.0, "z0": -5000.0, "pas": 200.0})
	_check(again.size() == sites.size() and String(again[0].key) == String(sites[0].key) and String(again[0].nom) == String(sites[0].nom), "même terrain, mêmes sites (clés et noms stables)")
	# Une petite forêt (moins de 120 ha) n'est pas un site.
	var bio2 := bio.duplicate()
	for j in n:
		for i in n:
			if bio2[i + j * n] == 10 and (i >= 33 or j >= 23):
				bio2[i + j * n] = 40
	var s2 := SitesNaturels.analyser({"h": h, "bio": bio2, "n": n, "x0": -5000.0, "z0": -5000.0, "pas": 200.0})
	var foret := false
	for s in s2:
		foret = foret or String(s.genre) == "foret"
	_check(not foret, "un petit bois de 36 ha ne fait pas venir les touristes")
	for id in TourismeTypes.NATURE:
		var t := BuildingCatalog.get_type(String(id))
		_check(not t.is_empty() and String(t.cat) == "tourisme", "%s dans Construire → Hôtels et tourisme" % id)
		var m := BuildingCatalog.build_mesh(String(id))
		_check(m != null and m.get_surface_count() > 0, "%s a un modèle 3D" % id)
		for j in Metiers.jobs_for(String(id)):
			_check(Metiers.METIERS.has(String(j[0])), "%s : métier %s connu" % [id, j[0]])
	_check(TourismeTypes.est_hebergement("refuge_montagne"), "le refuge de montagne est un hébergement")


func _ville_tests() -> void:
	print("Ville :")
	Creations.persist = false
	BatimentsVie.chantiers = false
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var bs: BuildingSystem = scene.get_node("Batiments")
	var transport: TransportSystem = scene.get_node("Transport")
	root.add_child(scene)
	ReglagesPartie.actuel.construction_instantanee = true
	world.tiles.offline_generator = _flat_tile
	var olat := 46.2
	var olon := 6.9
	# Un lac à l'est (x de 1 000 à 1 800 m), une forêt à l'ouest (x de −4 000 à −2 000 m).
	world.land.offline_generator = func(lat: float, lon: float) -> int:
		var z := deg_to_rad(olat - lat) * Geo.EARTH_RADIUS
		var x := deg_to_rad(lon - olon) * Geo.EARTH_RADIUS * cos(deg_to_rad(olat))
		if x >= 1000.0 and x < 1800.0 and z >= -600.0 and z < 600.0:
			return 80
		if x >= -4000.0 and x < -2000.0 and z >= -2000.0 and z < 2000.0:
			return 10
		return 40
	world.view_radius_override = 400.0
	world.set_origin(olat, olon)
	for i in 3000:
		await process_frame
		if i >= 120 and world.missing_chunk_count() == 0 and world._dirty.is_empty() and world._jobs.is_empty():
			break
	var tour: Tourisme = scene.tourisme
	var pop: Population = scene.population
	var prod: Production = scene.production
	for nd in [transport.traffic, tour, pop, scene.parc, scene.zoo, scene.musee, scene.spectacles, scene.dechets, prod]:
		nd.set_process(false)
	scene.urgences.set_process(false)
	scene.urgences.random_calls = false
	if scene.ambiance.weather != null:
		scene.ambiance.weather.set_process(false)
		scene.ambiance.weather.precip = 0.0
	bs.unlimited_money = false
	bs.money = 200_000_000
	var y := world.cell_height(Vector2i(0, 0))
	var road := transport.build_segment("route", Vector3(-600, y, 0), Vector3(600, y, 0))
	_check(road.ok, "route de 1,2 km")
	var poser := func(id: String, c: Vector2i) -> int:
		var sn := bs.road_snap(id, c)
		if sn.is_empty():
			return -1
		return bs.place(id, sn.center, int(sn.r), 0, float(sn.get("a", 0.0)))
	var hotel: int = poser.call("hotel_3", Vector2i(0, -14))
	tour.ignore_staff = true
	tour._sync()
	_check(hotel > 0 and tour.heb.has(hotel), "un hôtel en ville")

	# Le relevé du terrain trouve le lac et la forêt.
	var now := tour._now(VENDREDI)
	tour.clock = VENDREDI
	tour.last_day = int(now.day)
	tour.maj_nature(true)
	_check(tour.nature_ok, "relevé du terrain fait (%d sites)" % tour.nature.size())
	var lac := {}
	var foret := {}
	for s in tour.nature:
		if String(s.genre) == "lac":
			lac = s
		elif String(s.genre) == "foret":
			foret = s
	_check(not lac.is_empty() and not foret.is_empty(), "le lac (%s) et la forêt (%s) des environs" % [str(lac.get("nom", "")), str(foret.get("nom", ""))])
	if lac.is_empty() or foret.is_empty():
		scene.queue_free()
		return
	tour._maj_sites()
	var st_lac := _site(tour, String(lac.key))
	var st_foret := _site(tour, String(foret.key))
	_check(not st_lac.is_empty() and float(st_lac.pts) > 0.0, "le lac est un site touristique (%.2f points)" % float(st_lac.get("pts", 0.0)))
	_check(bool(st_lac.acces), "le lac est à moins de %d m de la route" % int(Tourisme.ACCES_ROUTE))
	_check(not bool(st_foret.acces), "la forêt, loin de la route, est difficile d'accès")
	var conseil := false
	for c in tour.conseils():
		conseil = conseil or String(c).contains(String(foret.nom))
	_check(conseil, "un conseil propose une route ou un parking de randonnée pour la forêt")
	_check(tour.demande(now) > 1.0, "la nature seule fait venir %d touristes ce vendredi" % roundi(tour.demande(now)))
	var pts_ete := float(st_lac.pts)
	tour.clock = JANVIER
	tour._maj_sites()
	var pts_hiver := float(_site(tour, String(lac.key)).pts)
	_check(pts_hiver < pts_ete * 0.5, "le lac attire moins en janvier (%.2f contre %.2f)" % [pts_hiver, pts_ete])
	tour.clock = VENDREDI

	# Aménagements : base nautique au bout de la route, parking de randonnée côté forêt.
	var base: int = poser.call("base_nautique", Vector2i(560, -14))
	var parking_rando: int = poser.call("parking_randonnee", Vector2i(-560, -12))
	_check(base > 0 and parking_rando > 0, "base nautique et parking de randonnée posés")
	tour._maj_sites()
	st_lac = _site(tour, String(lac.key))
	st_foret = _site(tour, String(foret.key))
	_check((st_lac.amenag as Array).has(base) and float(st_lac.pts) > pts_ete * 1.4, "la base nautique sert le lac (%.2f points)" % float(st_lac.pts))
	_check(bool(st_foret.acces) and (st_foret.amenag as Array).has(parking_rando), "le parking de randonnée rend la forêt accessible")
	# Des sentiers vers la forêt.
	var p0 := float(st_foret.pts)
	var sentier := transport.build_segment("chemin", Vector3(-600, y, 0), Vector3(-1950, y, -900))
	_check(sentier.ok, "un sentier de 1,6 km vers la forêt %s" % str(sentier.get("reason", "")))
	tour._maj_sites()
	st_foret = _site(tour, String(foret.key))
	_check(float(st_foret.sentiers) > 0.1 and float(st_foret.pts) > p0, "les sentiers rendent la forêt plus attirante (%.1f km, %.2f points)" % [float(st_foret.sentiers), float(st_foret.pts)])

	# Des journées d'été : visites du lac, recettes des locations.
	var caisse0 := bs.money
	var loc := 0.0
	for i in 3:
		var t := VENDREDI + 86400.0 * (i + 1)
		tour.last_day = int(tour._now(t).day)
		tour.clock = t
		prod.clock = t
		tour.new_day(tour._now(t))
		loc += float(tour.jour.get("nature", 0.0))
	var vis_lac := float(tour.visites_jour.get("nature:%s" % String(lac.key), 0.0))
	_check(tour.clients_total() > 0 and vis_lac > 1.0, "%d touristes en ville, %d au bord du lac aujourd'hui" % [tour.clients_total(), roundi(vis_lac)])
	_check(loc > 0.0, "locations de la base nautique : %s pour la ville" % BuildingSystem.format_money(int(loc)))
	_check(bs.money > caisse0, "la caisse de la ville monte")
	var dit := false
	for k in tour.pensees:
		dit = dit or String(k) in ["lac", "foret", "sentiers"]
	_check(dit, "les touristes parlent de la nature : %s" % str(tour.pensees.keys()))

	# Les promeneurs au bord du lac.
	scene.ambiance.unix_time = VENDREDI + 86400.0 * 3.0
	var rive: Vector3 = st_lac.points[0]
	tour.visuels._peupler_nature(rive)
	tour.visuels._dessiner()
	_check(tour.visuels.count_nature() > 0, "%d promeneurs dessinés au bord du lac" % tour.visuels.count_nature())
	var au_sec := true
	for k in tour.visuels.nature_agents:
		for a in tour.visuels.nature_agents[k].liste:
			au_sec = au_sec and is_nan(world.water_surface_at((a.p as Vector3).x, (a.p as Vector3).z))
	_check(au_sec, "aucun promeneur dans l'eau")

	# Autocars : ils roulent vraiment sur les routes.
	var pk: int = poser.call("parking_autocars", Vector2i(-300, 22))
	_check(pk > 0, "parking d'autocars posé")
	var tr: Traffic = transport.traffic
	_check(tr != null and tr.enabled, "la circulation tourne")
	var avant := tr.vehicles.size()
	_check(tour.lancer_autocar(pk, st_lac.pos), "un autocar part vers le lac")
	_check(tour.autocars_visibles() == 1 and tr.vehicles.size() == avant + 1, "il est sur la route")
	var car: Dictionary = tr.vehicles[tr.vehicles.size() - 1]
	_check(String(car.model) == "autocar" and (car.halts as Array).size() >= 2, "un autocar de tourisme, %d étapes (parking, site, sortie)" % (car.halts as Array).size())
	var entree := tour.entree_ville(int(car.node))
	_check(entree >= 0 and transport.network.degree(entree) == 1, "il vient de l'entrée de la ville (bout de route)")
	tr.set_process(true)
	var p_dep: Vector3 = (car.body as Node3D).global_position if car.has("body") and car.body != null else Vector3.ZERO
	for i in 600:
		await process_frame
	var p_ap: Vector3 = (car.body as Node3D).global_position if car.has("body") and is_instance_valid(car.body) else p_dep
	_check(p_ap.distance_to(p_dep) > 1.0 or not tr.vehicles.has(car), "il avance (%.0f m)" % p_ap.distance_to(p_dep))
	tr.set_process(false)
	tour.cars_prevus.clear()
	tour._sync()
	tour._maj_sites()
	tour._autocars(tour._now(VENDREDI))
	_check(not tour.cars_prevus.is_empty(), "%d cars prévus dans la matinée" % tour.cars_prevus.size())
	var n0 := tour.autocars_visibles()
	tour._rouler_autocars(13.0)
	_check(tour.cars_prevus.is_empty() and tour.autocars_visibles() > n0, "ils partent au fil de la matinée (%d sur les routes)" % tour.autocars_visibles())
	_check(tour.autocars_visibles() <= Tourisme.AUTOCARS_VISIBLES, "pas plus de %d à la fois" % Tourisme.AUTOCARS_VISIBLES)

	# Poste de secours : seulement pour une plage ou un lac, et l'été.
	var poste: int = poser.call("poste_secours_plage", Vector2i(520, 16))
	tour._maj_sites()
	_check(poste > 0 and bool(_site(tour, String(lac.key)).surveille), "le poste de secours surveille la baignade au lac en juillet")
	tour.clock = JANVIER
	tour._maj_sites()
	_check(not bool(_site(tour, String(lac.key)).surveille), "pas de maître-nageur en janvier")
	tour.clock = VENDREDI
	tour._maj_sites()

	# Panneau : onglet Attractions et Bâtir.
	var panel: TourismePanel = scene.tourisme_panel
	panel.set_open(true)
	panel.show_view("sites")
	_check(_texte(panel).contains("Nature des environs") and _texte(panel).contains(String(lac.nom)), "l'onglet Attractions montre la nature des environs")
	panel.show_view("batir")
	_check(_texte(panel).contains("Base nautique") and _texte(panel).contains("Belvédère"), "l'onglet Bâtir propose les aménagements de la nature")
	panel.set_open(false)
	scene.queue_free()
	await process_frame


func _site(tour: Tourisme, key: String) -> Dictionary:
	for s in tour.sites:
		if String(s.kind) == "nature" and String(s.key) == key:
			return s
	return {}


func _texte(n: Node) -> String:
	var t := ""
	if n is Label:
		t += (n as Label).text + "\n"
	elif n is Button:
		t += (n as Button).text + "\n"
	for c in n.get_children():
		t += _texte(c)
	return t
