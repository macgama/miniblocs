extends SceneTree
## Base économique : la ville ne paie que voies, réseaux et services publics.
## Logements, commerces, industrie, production, hébergements, cafés et restaurants
## sont financés par des promoteurs privés (zonage, catalogue B, Atelier, blocs,
## murs fins, meubles, agrandissements, façade) : rien pour la caisse de la ville.
## Réglage Admin ReglagesPartie.promoteurs_prives (coché par défaut, gardé dans la sauvegarde).
## Usage : godot --headless --path . --script res://tests/promoteurs_test.gd

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


func _run() -> void:
	Creations.persist = false
	print("Qui paie quoi :")
	_check(ReglagesPartie.new().promoteurs_prives, "réglage coché par défaut")
	for id in ["maison", "villa", "tour_habitation", "residence_standing", "boulangerie", "supermarche", "bureaux",
			"usine", "ferme", "entreprise_btp", "ferme_cereales", "carriere", "hotel_3", "camping", "cafe", "haussmann__restaurant",
			"japonais__maison", "haussmann__immeuble"]:
		_check(BuildingCatalog.est_prive(id), "%s : financé par le privé" % id)
	for id in ["maison_commune", "mairie", "ecole", "hopital", "pompiers", "police", "chateau_eau", "parc", "musee",
			"hlm_barre", "hbm", "campement", "office_tourisme", "entree_zoo", "entree_parc", "foot", "centrale_gaz", "depot_collecte"]:
		_check(not BuildingCatalog.est_prive(id), "%s : payé par la ville" % id)
	_check(BuildingCatalog.prix_ville("maison") == 0 and BuildingCatalog.prix_ville("ecole") == ReglagesPartie.prix(BuildingCatalog.cost("ecole")),
		"prix pour la ville : maison 0 €, école %s" % BuildingSystem.format_money(BuildingCatalog.prix_ville("ecole")))
	_check(ZoneSystem.prix_zonage(Rect2i(0, 0, 40, 40)) == 0, "zonage gratuit")

	print("En jeu :")
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var transport: TransportSystem = scene.get_node("Transport")
	var bs: BuildingSystem = scene.get_node("Batiments")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.set_origin(46.2, 6.15)
	for i in 90:
		await process_frame
	ReglagesPartie.actuel.promoteurs_prives = true
	bs.unlimited_money = false
	var ya := world.cell_height(Vector2i(0, 0))
	_check(transport.build_segment("route", Vector3(0, ya, -150), Vector3(0, ya, 150)).ok, "route posée")
	var m0 := 20_000_000
	bs.money = m0

	var chk := bs.check_place("maison", Vector2i(12, 0), 3)
	_check(chk.ok and int(chk.cost) == 0 and bool(chk.get("prive", false)) and int(chk.get("valeur", 0)) >= BuildingCatalog.cost("maison"),
		"maison du catalogue : 0 € pour la ville (valeur %s)" % BuildingSystem.format_money(int(chk.get("valeur", 0))))
	_check(String(chk.get("info", "")).contains("privé"), "l'aperçu dit qui paie (« %s »)" % String(chk.get("info", "")))
	var hid := bs.place("maison", Vector2i(12, 0), 3)
	_check(hid > 0 and bs.money == m0 and int(bs.buildings[hid].get("du", 0)) == 0, "maison posée à la main : la caisse ne bouge pas, rien à payer au chantier")
	bs.money = 1000
	var ca := bs.check_place("atelier", Vector2i(20, 40), 3)
	_check(ca.ok, "caisse presque vide : un atelier privé se pose quand même (%s)" % String(ca.reason))
	var ce := bs.check_place("ecole", Vector2i(-25, 60), 1)
	_check(not ce.ok and String(ce.reason).contains("argent"), "caisse presque vide : une école est refusée (%s)" % String(ce.reason))
	bs.money = m0
	var eid := bs.place("ecole", Vector2i(-25, 60), 1)
	var du := int(bs.buildings.get(eid, {}).get("du", 0)) if eid > 0 else 0
	_check(eid > 0 and (du >= BuildingCatalog.cost("ecole") or bs.money < m0), "l'école reste payée par la ville (%s dus%s)" % [
		BuildingSystem.format_money(du), "" if eid > 0 else ", " + String(bs.check_place("ecole", Vector2i(-25, 60), 1).reason)])

	var zs: ZoneSystem = scene.get_node("Zones")
	zs.growth = false
	var mz := bs.money
	var zid := zs.add_zone("R", Rect2i(-60, -80, 40, 60))
	_check(zid > 0 and bs.money == mz, "zone résidentielle peinte gratuitement")

	var am: Ameliorations = scene.get_node_or_null("Ameliorations") as Ameliorations
	if am == null:
		for n in scene.get_children():
			if n is Ameliorations:
				am = n
	if am != null:
		_check(am.prive(hid) and not am.prive(eid), "agrandir : la maison est privée, l'école publique")
		_check(am.refus_agrandir(hid) == "" or not am.refus_agrandir(hid).contains("argent"), "agrandir une maison n'exige rien de la caisse")

	var be: BlockEditor = scene.get_node("Blocs")
	var g := world.cell_height(Vector2i(-120, -100))
	var mb := bs.money
	_check(be.place_blocks([Vector3i(-120, roundi(g / BlockEditor.UNIT_Y), -100)], 0) == 1 and bs.money == mb, "éditeur libre : bloc posé sans payer")

	var mob: Mobilier = null
	for n in scene.get_children():
		if n is Mobilier:
			mob = n
	if mob != null:
		mob.usages["plan_test"] = "logement"
		_check(not mob.ville_paie_plan("plan_test"), "murs fins d'un logement : payés par le promoteur")
		mob.usages["plan_test"] = "ecole"
		_check(mob.ville_paie_plan("plan_test"), "murs fins d'une école : payés par la ville")
		mob.usages.erase("plan_test")

	print("Réglage coupé (la ville paie tout) :")
	ReglagesPartie.actuel.promoteurs_prives = false
	var chk2 := bs.check_place("villa", Vector2i(16, -60), 3)
	_check(chk2.ok and int(chk2.cost) >= BuildingCatalog.cost("villa") and not chk2.has("prive"), "villa payée par la ville : %s" % BuildingSystem.format_money(int(chk2.cost)))
	_check(ZoneSystem.prix_zonage(Rect2i(0, 0, 10, 10)) == ReglagesPartie.prix(100 * ZoneSystem.PRICE_M2), "zonage payant")
	_check(not BlockEditor.gratuit(), "blocs payants")

	var d := ReglagesPartie.actuel.to_dict()
	var r := ReglagesPartie.new()
	r.from_dict(d)
	_check(not r.promoteurs_prives, "réglage gardé dans la sauvegarde")
	d.erase("promoteurs_prives")
	r.from_dict(d)
	_check(r.promoteurs_prives, "ancienne sauvegarde : promoteurs privés activés")
	ReglagesPartie.actuel.promoteurs_prives = true

	print("PROMOTEURS TEST " + ("OK" if ok else "ÉCHEC"))
	quit(0 if ok else 1)
