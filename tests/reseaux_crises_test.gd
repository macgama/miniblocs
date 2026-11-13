extends SceneTree
## Test du chauffage (gaz et chaleur), de l'usure et des pannes des réseaux, et
## des crises (canicule, sécheresse, restrictions d'eau).
## Usage : godot --headless --path . --script res://tests/reseaux_crises_test.gd

var ok := true
var messages: Array[String] = []


class SourceTest:
	extends Node
	var bid := -1
	var mw := 0.0
	func electricite_sources() -> Array:
		return [{"bid": bid, "mw": mw, "nom": "Test"}] if bid >= 0 else []


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


func _place(bs: BuildingSystem, id: String, x: int, z_side := -1, road_z := 0) -> int:
	var d := int(BuildingCatalog.get_type(id).d)
	var c := Vector2i(x, road_z + z_side * (d / 2 + 6))
	return bs.place(id, c, bs.best_rotation(id, c))


func _a_dit(mot: String) -> bool:
	for m in messages:
		if m.contains(mot):
			return true
	return false


func _run() -> void:
	Creations.persist = false
	BatimentsVie.chantiers = false
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var transport: TransportSystem = scene.get_node("Transport")
	var bs: BuildingSystem = scene.get_node("Batiments")
	var amb: DayNight = scene.get_node("Ambiance")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.view_radius_override = 900.0
	world.set_origin(45.75, 4.85)
	for i in 3000:
		await process_frame
		if i >= 150 and world.missing_chunk_count() == 0 and world._dirty.is_empty() and world._jobs.is_empty():
			break
	var res: Reseaux = scene.reseaux
	var pop: Population = scene.population
	res.message.connect(func(t: String) -> void: messages.append(t))
	ReglagesPartie.actuel.reseaux_obligatoires = true
	ReglagesPartie.actuel.construction_instantanee = true
	ReglagesPartie.actuel.usure = 1.0
	amb.set_speed(0)
	amb.unix_time = _at("2026-01-15", 13.0)
	bs.money = 5_000_000_000
	res.incidents.rng.seed = 42

	print("Bâtiments du chauffage :")
	for id in ["poste_gaz", "chaufferie_bois", "geothermie"]:
		var m := BuildingCatalog.build_mesh(id)
		_check(String(BuildingCatalog.get_type(id).cat) == "reseaux" and m != null and m.get_surface_count() > 0, "%s : catégorie Réseaux et modèle" % id)
	_check(ReseauxTypes.troncons_de("gaz").has("conduite_gaz"), "conduite de gaz ou de chaleur")

	var y := world.cell_height(Vector2i(0, 0))
	_check(transport.build_segment("route", Vector3(-400, y, 0), Vector3(400, y, 0)).ok, "route est-ouest")
	var homes := []
	for i in 6:
		homes.append(_place(bs, "immeuble", -300 + i * 40, 1))
	var hote := _place(bs, "scierie", 250, -1)
	var forage := _place(bs, "forage_eau", -100, -1)
	var station := _place(bs, "station_epuration_locale", 60, -1)
	_check(not homes.has(-1) and hote > 0 and forage > 0 and station > 0, "6 immeubles, une scierie, un forage, une station d'épuration")
	var src := SourceTest.new()
	src.add_to_group("electricite_sources")
	scene.add_child(src)
	src.bid = hote
	src.mw = 50.0
	await process_frame
	pop._sync_buildings()
	for i in 60:
		pop.advance(300.0)
	res._sync_sale = true

	print("Chauffage :")
	res.temperature_forcee = 18.0
	res.simuler(0.0)
	var dem_doux := float(res.bilan("elec").demande)
	res.temperature_forcee = -5.0
	res.simuler(0.0)
	var dem_froid := float(res.bilan("elec").demande)
	_check(res.besoin > 1.0, "par −5 °C, besoin de chauffage %d %%" % roundi(res.besoin * 100.0))
	_check(res.taux(homes[0], "gaz") == 0.0 and res.chauffe(homes[0]) >= 0.95, "sans gaz, on se chauffe à l'électricité")
	_check(dem_froid > dem_doux * 1.5, "pointe d'hiver : %s MW au lieu de %s" % [Reseaux._fmt(dem_froid), Reseaux._fmt(dem_doux)])
	src.mw = 0.0
	res.simuler(0.0)
	var home0 := -1
	for hid in pop.households:
		var hb := int(pop.households[hid].get("b", -1))
		if homes.has(hb):
			home0 = hb
			break
	_check(res.chauffe(home0) < 0.5 and res.bilan("gaz").froid > 0, "ni gaz ni courant : %d bâtiments ont froid" % int(res.bilan("gaz").froid))
	var froid_sat := false
	for pid in pop.persons:
		var p: Dictionary = pop.persons[pid]
		if pop.home_of(p) == home0:
			froid_sat = (res.satisfaction_of(p)[1] as Array).has("− pas d'électricité ni de chauffage : il fait froid")
			break
	_check(froid_sat, "les habitants ont froid (satisfaction)")
	_check(res.risque_sante(home0) > 0.2, "le froid rend malade : risque %.2f" % res.risque_sante(home0))
	var poste := _place(bs, "poste_gaz", 140, -1)
	_check(poste > 0, "poste de livraison de gaz au bord de la route")
	await process_frame
	res._sync_sale = true
	res.simuler(0.0)
	_check(res.taux(home0, "gaz") >= 0.95 and res.chauffe(home0) >= 0.95, "le gaz chauffe les immeubles, même sans courant")
	src.mw = 50.0
	res.simuler(0.0)
	var dem_gaz := float(res.bilan("elec").demande)
	_check(dem_gaz < dem_froid * 0.6, "avec le gaz, la pointe électrique retombe (%s MW)" % Reseaux._fmt(dem_gaz))
	var gaz_mois0 := float(res.compta.mois.get("Factures de gaz et de chauffage", 0.0))
	res.simuler(6.0)
	_check(float(res.compta.mois.get("Factures de gaz et de chauffage", 0.0)) > gaz_mois0, "les habitants paient leur gaz")
	_check(float(res.compta.mois.get("Gaz acheté au gazoduc", 0.0)) < 0.0, "la ville achète le gaz au gazoduc")

	print("Pannes d'un tronçon :")
	var y2 := world.cell_height(Vector2i(0, 300))
	_check(transport.build_segment("route", Vector3(-80, y2, 300), Vector3(80, y2, 300)).ok, "route du hameau")
	var hameau := _place(bs, "maison", 0, 1, 300)
	await process_frame
	res._sync_sale = true
	var lid := res.poser("ligne_mt", res.trace_sur_relief(Vector3(0, y, 0), Vector3(0, y2, 300)))
	res.simuler(0.0)
	_check(lid > 0 and res.taux(hameau, "elec") >= 0.95, "ligne MT : le hameau a du courant")
	var money0 := bs.money
	var iid := res.incidents.provoquer("elec", lid, "test")
	res.simuler(0.0)
	_check(iid > 0 and res.incidents.en_panne("elec", lid) and res.taux(hameau, "elec") == 0.0, "câble arraché : le hameau est dans le noir")
	_check(ReseauxVue.ligne_aerienne(res.elec.troncons[lid].pts, "ligne_mt", 1.0, true).get_surface_count() > 0, "câbles tombés au sol visibles")
	amb.unix_time += 20.0 * 3600.0
	res.simuler(0.0)
	_check(not res.incidents.en_panne("elec", lid) and res.taux(hameau, "elec") >= 0.95, "l'équipe a réparé : courant revenu")
	_check(bs.money < money0, "la ville paie la réparation (%s)" % BuildingSystem.format_money(money0 - bs.money))
	var n := res.endommager(Vector3(0, y, 150), 20.0, "tempete")
	res.simuler(0.0)
	_check(n == 1 and res.taux(hameau, "elec") == 0.0, "une tempête abat la ligne")
	res.incidents.reparer_vite(int(res.incidents.de_reseau("elec")[0].id))
	res.simuler(0.0)
	_check(res.taux(hameau, "elec") >= 0.95 and res.incidents.incidents.is_empty(), "réparation express")

	print("Usure :")
	res.incidents.vieillir(365.0 * 20.0)
	var u := res.incidents.etat_troncon("elec", lid)
	_check(u < 0.6, "20 ans plus tard, la ligne est usée : %d %%" % roundi(u * 100.0))
	money0 = bs.money
	_check(res.incidents.renover("elec", lid) and res.incidents.etat_troncon("elec", lid) == 1.0 and bs.money < money0, "rénovation : à neuf (%s)" % BuildingSystem.format_money(money0 - bs.money))
	ReglagesPartie.actuel.usure = 3.0
	for d in 400:
		res.incidents.tirage_pannes()
		if not res.incidents.incidents.is_empty():
			break
	_check(not res.incidents.incidents.is_empty(), "avec le temps, des pannes arrivent toutes seules")
	for x in res.incidents.incidents.duplicate():
		res.incidents.reparer(int(x.id))
	ReglagesPartie.actuel.usure = 1.0

	print("Fuites et transformateurs :")
	res.temperature_forcee = 15.0
	res.simuler(0.0)
	var ce := res.eau.composante_de(homes[0])
	var prod0 := float(res.eau.composantes[ce].prod)
	var fid := res.incidents.fuite(homes[0])
	res.simuler(0.0)
	ce = res.eau.composante_de(homes[0])
	_check(fid > 0 and float(res.eau.composantes[ce].prod) < prod0 * 0.9, "fuite dans une rue : le réseau perd de l'eau (%d → %d m³/j)" % [roundi(prod0), roundi(float(res.eau.composantes[ce].prod))])
	res.incidents.reparer(fid)
	var tid := res.incidents.transfo(homes[0])
	res.simuler(0.0)
	_check(tid > 0 and res.taux(homes[0], "elec") == 0.0 and res.taux(homes[5], "elec") >= 0.95, "transformateur grillé : seul le pâté de maisons est coupé")
	res.incidents.reparer(tid)
	res.simuler(0.0)
	_check(res.taux(homes[0], "elec") >= 0.95, "transformateur changé")

	print("Canicule :")
	res.temperature_forcee = 22.0
	res.simuler(0.0)
	var e22 := float(res.bilan("elec").demande)
	var o22 := float(res.bilan("eau").demande)
	res.temperature_forcee = 36.0
	res.simuler(0.0)
	_check(res.incidents.canicule and _a_dit("Canicule"), "canicule annoncée")
	_check(float(res.bilan("elec").demande) > e22 * 1.2 and float(res.bilan("eau").demande) > o22 * 1.15, "la clim et la soif font grimper la demande")

	print("Sécheresse :")
	res.temperature_forcee = 25.0
	res.simuler(0.0)
	var cap0 := float(res.sources_info[forage].cap)
	res.incidents.forcer_secheresse(42.0)
	res.simuler(0.0)
	_check(float(res.sources_info[forage].cap) < cap0 * 0.75 and String(res.sources_info[forage].why) == "sécheresse", "la nappe baisse : forage à %d m³/j" % roundi(float(res.sources_info[forage].cap)))
	var o25 := float(res.bilan("eau").demande)
	res.incidents.restrictions = true
	res.simuler(0.0)
	_check(float(res.bilan("eau").demande) < o25 * 0.85, "restrictions d'eau : −20 %")
	var restr := false
	for pid in pop.persons:
		var p: Dictionary = pop.persons[pid]
		if pop.home_of(p) == home0:
			restr = (res.satisfaction_of(p)[1] as Array).has("− restrictions d'eau (arrosage, piscines)")
			break
	_check(restr, "les habitants râlent un peu")
	# La pluie revient : jours de pluie.
	for d in 12:
		res.incidents._precip_max = 0.5
		res.incidents._t_max = 18.0
		res.incidents._maj_secheresse()
	_check(res.incidents.secheresse == 0.0, "la pluie met fin à la sécheresse")

	print("Sauvegarde :")
	res.incidents.provoquer("elec", lid, "test")
	var d := res.to_dict()
	res.from_dict(JSON.parse_string(JSON.stringify(d)))
	await process_frame
	res.simuler(0.0)
	_check(res.incidents.incidents.size() == 1 and res.incidents.en_panne("elec", lid) and res.incidents.restrictions, "pannes et restrictions gardées")
	_check(res.gaz.sources.has(poste) and res.taux(home0, "gaz") >= 0.95, "réseau de gaz reconstruit")

	print("Panneau :")
	var panel: ReseauxPanel = scene.reseaux_panel
	panel.set_open(true)
	for v in ["elec", "eau", "egout", "gaz", "comptes"]:
		panel.show_view(v)
	_check(panel.is_open(), "onglets Courant, Eau, Égouts, Chauffage, Comptes")
	panel.set_open(false)

	print("TEST OK" if ok else "TEST ÉCHEC")
	quit(0 if ok else 1)
