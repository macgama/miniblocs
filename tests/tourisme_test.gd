extends SceneTree
## Test du tourisme : bâtiments (hébergements, office, souvenirs, autocars) et
## leurs modèles, hôtels de la bible reconnus, attrait d'un musée, arrivées et
## nuitées, refus faute de lits, taxe de séjour et impôts dans la caisse,
## repas et courses en ville, visites qui s'ajoutent au musée, publicité,
## réputation, sauvegarde, panneau et bouton de la barre du bas.
## Usage : godot --headless --path . --script res://tests/tourisme_test.gd

var ok := true

## Vendredi 17 juillet 2026, midi (UTC+2).
const VENDREDI := 1_784_282_400.0


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
	_catalog_tests()
	await _city_tests()
	print("TEST OK" if ok else "TEST ÉCHEC")
	quit(0 if ok else 1)


func _catalog_tests() -> void:
	print("Catalogue :")
	var found := false
	for c in BuildingCatalog.CATEGORIES:
		if String(c.id) == "tourisme":
			found = true
	_check(found, "catégorie « Hôtels et tourisme » dans Construire")
	var heb := 0
	for id in TourismeTypes.ORDER:
		var t := BuildingCatalog.get_type(String(id))
		_check(not t.is_empty() and String(t.cat) == "tourisme" and t.has("touris"), "%s dans le catalogue (id pas déjà pris)" % id)
		var m := BuildingCatalog.build_mesh(String(id))
		_check(m != null and m.get_surface_count() > 0, "%s a un modèle 3D" % id)
		for j in Metiers.jobs_for(String(id)):
			_check(Metiers.METIERS.has(String(j[0])), "%s : métier %s connu" % [id, j[0]])
		if TourismeTypes.est_hebergement(String(id)):
			heb += 1
			_check(TourismeTypes.lits_de(TourismeTypes.spec_of(String(id))) > 0, "%s a des lits" % id)
	_check(heb >= 12, "%d hébergements" % heb)
	for id in TourismeTypes.AUTRES:
		_check(not BuildingCatalog.get_type(String(id)).is_empty() and TourismeTypes.est_hebergement(String(id)), "hôtel de la bible %s reconnu" % id)
	_check(TourismeTypes.taxe(5) > TourismeTypes.taxe(1), "taxe de séjour plus chère dans un palace")
	for ic in ["valise", "lit", "appareil_photo", "megaphone"]:
		_check(Icones.has_icon(ic), "icône %s" % ic)


func _city_tests() -> void:
	print("Ville :")
	Creations.persist = false
	BatimentsVie.chantiers = false
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var bs: BuildingSystem = scene.get_node("Batiments")
	var transport: TransportSystem = scene.get_node("Transport")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 40
	world.view_radius_override = 600.0
	world.set_origin(46.2, 6.9)
	for i in 3000:
		await process_frame
		if i >= 120 and world.missing_chunk_count() == 0 and world._dirty.is_empty() and world._jobs.is_empty():
			break
	var tour: Tourisme = scene.tourisme
	_check(tour != null and scene.tourisme_panel != null and Tourisme.instance == tour, "tourisme et menu branchés dans la scène")
	_check(scene.save_sections().has("tourisme"), "section « tourisme » dans la sauvegarde")
	var pop: Population = scene.population
	var prod: Production = scene.production
	for n in [transport.traffic, tour, pop, scene.parc, scene.zoo, scene.musee, scene.spectacles, scene.dechets, prod]:
		n.set_process(false)
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
	var homes: Array[int] = []
	for i in 20:
		var c := Vector2i(-560 + i * 14, 12)
		homes.append(bs.place("maison", c, bs.best_rotation("maison", c)))
	pop._sync_buildings()
	for bid in homes:
		pop.spawn_household(bid, "famille")
	var poser := func(id: String, c: Vector2i) -> int:
		var sn := bs.road_snap(id, c)
		if sn.is_empty():
			return -1
		return bs.place(id, sn.center, int(sn.r), 0, float(sn.get("a", 0.0)))

	# Bouton de la barre du bas.
	var hud: TerreHud = scene.hud
	var bouton := false
	for c in hud.CATEGORIES:
		if String(c.id) == "tourisme":
			bouton = String(c.group) == "loisirs"
	_check(bouton, "bouton Tourisme dans le menu Loisirs de la barre du bas")
	scene.tourisme_panel.set_open(false)
	hud._on_category("tourisme")
	_check(scene.tourisme_panel.is_open(), "le bouton ouvre le menu Tourisme")
	scene.tourisme_panel.set_open(false)

	# Rien à voir : pas de touristes.
	var now := tour._now(VENDREDI)
	_check(int(now.wd) == 5 and int(now.month) == 7, "vendredi de juillet")
	tour.clock = VENDREDI
	tour.last_day = int(now.day)
	tour.new_day(now)
	_check(tour.sites.is_empty() and tour.demande(now) == 0.0, "sans rien à visiter, personne ne vient")
	_check(not tour.conseils().is_empty(), "conseil : « %s »" % String(tour.conseils()[0]))

	# Un musée, des hébergements, un café, une supérette, des souvenirs.
	var musee_bid: int = poser.call("musee", Vector2i(-100, -16))
	var hotel: int = poser.call("hotel_3", Vector2i(0, -14))
	var camping: int = poser.call("camping", Vector2i(90, -30))
	var cafe: int = poser.call("cafe", Vector2i(-40, -10))
	var superette: int = poser.call("superette", Vector2i(-60, -10))
	var souvenirs: int = poser.call("boutique_souvenirs_ville", Vector2i(40, -8))
	var office: int = poser.call("office_tourisme", Vector2i(150, -9))
	_check(musee_bid > 0 and hotel > 0 and camping > 0 and cafe > 0 and superette > 0 and souvenirs > 0 and office > 0,
		"musée, hôtel, camping, café, supérette, souvenirs et office posés %s" % str([musee_bid, hotel, camping, cafe, superette, souvenirs, office]))
	var palace: int = poser.call("palace_belle_epoque", Vector2i(330, -22))
	tour.ignore_staff = true
	tour._sync()
	_check(tour.heb.has(hotel) and tour.heb.has(camping), "l'hôtel et le camping sont des hébergements")
	_check(palace > 0 and tour.heb.has(palace) and tour.etoiles(palace) == 5, "le palace de la bible est un hôtel 5 étoiles")
	_check(tour.relie(hotel) and tour.relie(palace), "l'hôtel et le palace sont reliés à la route")
	_check(tour.est_municipal(camping) and not tour.est_municipal(hotel), "le camping est municipal, l'hôtel privé")
	_check(tour.lits(hotel) == 120 and tour.lits(camping) == 210, "lits : hôtel %d, camping %d" % [tour.lits(hotel), tour.lits(camping)])
	# Café et supérette ouverts : un employé chacun, des rayons remplis.
	prod._dirty = true
	prod._sync()
	var pids := pop.persons.keys()
	pop.by_job[cafe] = [int(pids[0])]
	pop.by_job[superette] = [int(pids[1])]
	for g in ["boissons", "pain", "viande", "fruits_legumes", "laitages", "epicerie", "hygiene"]:
		prod._put(cafe, g, 1.0)
		prod._put(superette, g, 2.0)
	_check(prod.sites.has(cafe) and prod.sites.has(superette), "café et supérette sont des commerces de l'économie")

	# Repas et courses en direct.
	var r := prod.repas_touristes(tour.pos_of(hotel), 40.0)
	_check(float(r[1]) > 10.0 and float(r[0]) > 100.0, "les touristes déjeunent au café : %d repas, %s" % [roundi(float(r[1])), BuildingSystem.format_money(int(r[0]))])
	var a2 := prod.achats_touristes(tour.pos_of(hotel), {"boissons": 0.05, "pain": 0.01})
	_check(float(a2[0]) > 0.0 and float(a2[1]) > 0.9, "et font leurs courses à la supérette (%s)" % BuildingSystem.format_money(int(a2[0])))
	_check(prod._dem_touristes.has(superette), "la demande des touristes compte pour les livraisons")

	# Une journée d'été.
	scene.musee._dirty = true
	scene.musee.list()
	tour._maj_sites()
	_check(tour.sites.size() == 1 and String(tour.sites[0].kind) == "musee", "le musée est un site touristique")
	_check(tour.attrait_total > 0.5, "attrait de la ville : %.1f points" % tour.attrait_total)
	var d := tour.demande(now)
	_check(d > 5.0, "%d touristes veulent venir ce vendredi" % roundi(d))
	_check(tour.attrait_heb(hotel, 7) > 0.0 and tour.attrait_heb(palace, 7) > 0.0, "les deux hôtels attirent des clients")
	var p0 := tour.attrait_heb(hotel, 7)
	tour.set_prix(hotel, 250.0)
	_check(tour.attrait_heb(hotel, 7) < p0 * 0.5, "un prix trop cher fait fuir")
	tour.set_prix(hotel, 70.0)
	var caisse0 := bs.money
	var nuitees := 0
	var arrivees := 0
	for i in 4:
		var t := VENDREDI + 86400.0 * (i + 1)
		tour.last_day = int(tour._now(t).day)
		tour.clock = t
		prod.clock = t
		tour.new_day(tour._now(t))
		nuitees += int(tour.jour.nuitees)
		arrivees += int(tour.jour.arrivees)
	_check(arrivees > 10, "%d arrivées en 4 jours" % arrivees)
	_check(tour.clients_total() > 5 and nuitees > 10, "%d touristes en ville, %d nuitées" % [tour.clients_total(), nuitees])
	_check(tour.clients(hotel) > 0, "l'hôtel a des clients (%d)" % tour.clients(hotel))
	_check(float(tour.jour.taxe) > 0.0, "taxe de séjour du jour : %s" % BuildingSystem.format_money(int(tour.jour.taxe)))
	_check(float(tour.jour.restaurants) > 0.0, "repas en ville : %s" % BuildingSystem.format_money(int(tour.jour.restaurants)))
	_check(float(tour.jour.souvenirs) > 0.0, "souvenirs : %s" % BuildingSystem.format_money(int(tour.jour.souvenirs)))
	_check(float(tour.jour.hebergement) > 0.0, "nuitées payées : %s" % BuildingSystem.format_money(int(tour.jour.hebergement)))
	_check(bs.money > caisse0, "la ville encaisse (+%s)" % BuildingSystem.format_money(bs.money - caisse0))
	_check(float(tour.heb[hotel].jour.ca) > 0.0, "l'hôtel a un chiffre d'affaires (%s)" % BuildingSystem.format_money(int(tour.heb[hotel].jour.ca)))
	# Les clients vont au musée.
	var mk := String(tour.sites[0].key)
	var v := Tourisme.visites("musee", mk)
	_check(v > 1.0, "%d clients des hôtels attendus au musée" % roundi(v))
	var att_avec: Array = scene.musee.attendus(mk, scene.musee._now(VENDREDI + 86400.0 * 4))
	var sauve := tour.visites_jour.duplicate()
	tour.visites_jour.clear()
	var att_sans: Array = scene.musee.attendus(mk, scene.musee._now(VENDREDI + 86400.0 * 4))
	tour.visites_jour = sauve
	_check(float(att_avec[1]) > float(att_sans[1]), "le musée reçoit plus de touristes grâce aux hôtels (%d → %d)" % [roundi(float(att_sans[1])), roundi(float(att_avec[1]))])
	_check(not tour.dernieres.is_empty(), "les touristes parlent : « %s »" % String(tour.dernieres[0]))
	_check(tour.reputation > 0.5 and tour.reputation <= 5.0, "réputation : %.2f" % tour.reputation)

	# Pas assez de lits : des touristes refusés.
	tour.set_ouvert(hotel, false)
	tour.set_ouvert(camping, false)
	tour.set_ouvert(palace, false)
	var gite: int = poser.call("gite_rural", Vector2i(-200, -10))
	tour._sync()
	var t5 := VENDREDI + 86400.0 * 7
	tour.last_day = int(tour._now(t5).day)
	tour.new_day(tour._now(t5))
	_check(gite > 0 and tour.clients(gite) <= tour.lits(gite), "le gîte ne déborde pas (%d / %d)" % [tour.clients(gite), tour.lits(gite)])
	_check(int(tour.jour.refus) > 0, "%d touristes refusés faute de lits" % int(tour.jour.refus))
	tour.set_ouvert(hotel, true)
	tour.set_ouvert(camping, true)

	# Publicité.
	var m0 := bs.money
	var err := tour.lancer_campagne("regionale")
	_check(err == "" and tour.campagne == "regionale", "campagne régionale lancée")
	_check(bs.money < m0, "la campagne est payée (%s)" % BuildingSystem.format_money(m0 - bs.money))
	_check(tour.lancer_campagne("nationale") != "", "une seule campagne à la fois")
	var d2 := tour.demande(now)
	_check(d2 > d, "la publicité fait venir plus de monde (%d → %d)" % [roundi(d), roundi(d2)])

	# Petits touristes devant l'hôtel.
	scene.ambiance.unix_time = VENDREDI
	tour.visuels._peupler()
	tour.visuels._bouger(0.5)
	tour.visuels._dessiner()
	_check(tour.visuels.count() > 0, "%d touristes dessinés devant les hébergements" % tour.visuels.count())

	# Sauvegarde.
	var data := tour.to_dict()
	var c0 := tour.clients_total()
	var rep0 := tour.reputation
	var data2: Dictionary = JSON.parse_string(JSON.stringify(data))
	tour.from_dict(data2)
	_check(tour.clients_total() == c0, "clients retrouvés après chargement (%d)" % tour.clients_total())
	_check(absf(tour.reputation - rep0) < 0.001 and tour.campagne == "regionale", "réputation et campagne retrouvées")
	_check(not tour.historique.is_empty(), "historique gardé (%d jours)" % tour.historique.size())

	# Le menu, onglet par onglet.
	var panel: TourismePanel = scene.tourisme_panel
	panel.set_open(true)
	for v2 in ["bref", "heb", "sites", "pub", "batir", "avis"]:
		panel.show_view(v2)
		_check(panel._body.get_child_count() > 2, "onglet %s rempli (%d éléments)" % [v2, panel._body.get_child_count()])
	panel.set_open(false)
	scene.queue_free()
	await process_frame
