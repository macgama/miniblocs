extends SceneTree
## Test du kit d'installation de l'État : bons de la première ville d'un pays,
## renfort de fondateurs, remise sur un bâtiment des réseaux ou des déchets
## (une fois par bon, plafonnée), rien pour une 2e ville du même pays, nouveau
## kit dans un autre pays (renfort au campement), sauvegarde, panneau Maj+P.
## Usage : godot --headless --path . --script res://tests/kit_test.gd

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
	ReglagesPartie.prochaine.fondateurs = 20
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
	
	var kit: KitInstallation = scene.kit
	_check(kit != null and KitInstallation.instance == kit, "kit branché")
	var codes := {}
	kit.pays_de = func(v: int) -> String: return String(codes.get(v, "fr"))
	var fd: Fondateurs = scene.fondateurs
	bs.require_access = false
	scene.population.arrivals = false

	print("Première ville en France :")
	cm.nom_en_attente = "Valfleuri"
	var mc := bs.place("maison_commune", Vector2i(-1000, 0), 0)
	var v1 := cm.principal()
	for i in 4:
		await process_frame
	_check(mc > 0 and v1 >= 0, "Valfleuri fondé")
	_check(kit.restants(v1) == ["elec", "eau", "egout", "dechets"], "4 bons : %s" % str(kit.restants(v1)))
	_check(kit.pays_servis.get("fr", -1) == v1, "la France est servie")
	_check(fd.arrives and fd.renfort_total == KitInstallation.RENFORT and fd.vivants().size() == 20 + KitInstallation.RENFORT,
		"%d fondateurs dont %d envoyés par l'État" % [fd.vivants().size(), fd.renfort_total])
	_check(KitInstallation.bon_du_type("forage_eau") == "eau" and KitInstallation.bon_du_type("lagunage") == "egout"
		and KitInstallation.bon_du_type("decheterie") == "dechets" and KitInstallation.bon_du_type("centrale_biomasse") == "elec", "types des bons")
	_check(KitInstallation.bon_du_type("ecole") == "" and KitInstallation.bon_du_type("chateau_eau_champignon") == "", "pas de bon pour une école ni un château d'eau")

	print("Remise :")
	var pos := _spot(bs, "forage_eau", Vector2i(-1000, 0))
	var res := bs.check_place("forage_eau", pos, 0)
	var plein := ReglagesPartie.prix(BuildingCatalog.cost("forage_eau"))
	_check(res.ok and int(res.get("remise", 0)) >= plein and String(res.get("info", "")).contains("Kit de l'État"),
		"forage : %s offerts (%s)" % [BuildingSystem.format_money(int(res.get("remise", 0))), String(res.get("info", ""))])
	var s0 := p.solde(v1)
	var f1 := bs.place("forage_eau", pos, 0)
	_check(f1 > 0 and p.solde(v1) == s0, "posé sans rien payer (caisse %s)" % BuildingSystem.format_money(p.solde(v1)))
	_check(not kit.a_le_bon(v1, "eau") and kit.restants(v1).size() == 3, "bon « eau » utilisé")
	var pos2 := _spot(bs, "forage_eau", Vector2i(-1000, 0))
	_check(int(bs.check_place("forage_eau", pos2, 0).get("remise", 0)) == 0, "un 2e forage se paie")
	var pos3 := _spot(bs, "ecole", Vector2i(-1000, 0))
	_check(int(bs.check_place("ecole", pos3, 0).get("remise", 0)) == 0, "une école se paie")
	# Plafond : au-delà, la ville paie la différence.
	var big := kit.remise("station_epuration_locale", Rect2i(Vector2i(-1000, 40), Vector2i(10, 10)), 999_000_000)
	_check(big == kit.plafond("egout"), "grosse station d'épuration : %s offerts, le reste payé par la ville" % BuildingSystem.format_money(big))
	_check(kit.remise("lagunage", Rect2i(Vector2i(-1000, 9000), Vector2i(10, 10)), 1_000_000) == 0, "loin de toute ville : pas de bon")

	print("Deuxième ville, même pays :")
	cm.nom_en_attente = "Montclair"
	var mc2 := bs.place("maison_commune", Vector2i(1100, 0), 0)
	await process_frame
	var v2 := -1
	for v in cm.villages:
		if int(v) != v1:
			v2 = int(v)
	_check(mc2 > 0 and v2 >= 0, "Montclair fondé")
	_check(kit.restants(v2).is_empty() and kit.resume(v2) == "", "pas de kit en France une 2e fois")

	print("Nouveau pays :")
	var n0 := fd.vivants().size()
	codes[v2] = "ch"
	kit.accorder(v2, "ch")
	await process_frame
	_check(kit.restants(v2).size() == 4 and kit.pays_servis.get("ch", -1) == v2, "kit pour Montclair, première ville en Suisse")
	_check(fd.vivants().size() == n0 + KitInstallation.RENFORT and fd.au_campement() >= KitInstallation.RENFORT,
		"renfort au campement : %d → %d fondateurs" % [n0, fd.vivants().size()])

	print("Sauvegarde :")
	var d := kit.to_dict()
	kit.from_dict(JSON.parse_string(JSON.stringify(d)))
	_check(kit.restants(v1).size() == 3 and kit.restants(v2).size() == 4 and kit.pays_servis.get("fr", -1) == v1
		and (kit.utilises.get(v1, {}) as Dictionary).has("eau"), "bons et pays servis rechargés")
	_check(scene.save_sections().has("kit"), "section « kit » dans la sauvegarde")
	var fdd := fd.to_dict()
	_check(int(fdd.get("renfort_total", 0)) == 2 * KitInstallation.RENFORT, "renfort des fondateurs sauvegardé")

	print("Panneau Maj+P :")
	scene.pays_panel.set_open(true)
	var vu := false
	for c in scene.pays_panel._body.get_children():
		if c is Label and (c as Label).text.begins_with("Kit de l'État à poser"):
			vu = true
	_check(vu, "bons restants affichés sous la ville")
	scene.pays_panel.set_open(false)

	print("RÉSULTAT : ", "OK" if ok else "ÉCHEC")
	quit(0 if ok else 1)


## Une place libre pour ce bâtiment près d'un point.
func _spot(bs: BuildingSystem, id: String, c: Vector2i) -> Vector2i:
	for dist in [60, 90, 120, 160, 200, 250, 300]:
		for i in 16:
			var a := float(i) / 16.0 * TAU
			var q := c + Vector2i(roundi(cos(a) * dist), roundi(sin(a) * dist))
			if bs.check_place(id, q, 0).ok:
				return q
	return c
