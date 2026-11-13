extends SceneTree
## Test des carrières et des mines : géologie réelle (calcaire, granite, sel),
## fosse en gradins qui creuse vraiment le terrain, réserve tirée du périmètre,
## épuisement, verse et terril, périmètre dessiné, sondage, réaménagement,
## nouvelles chaînes (cimenterie, sel) et sauvegarde.
## Usage : godot --headless --path . --script res://tests/carrieres_test.gd

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


func _staff(pop: Population, bid: int, id: String) -> void:
	var n := int(BuildingCatalog.get_type(id).get("emplois", 1))
	var fake := []
	for i in n:
		fake.append(900000 + bid * 1000 + i)
	pop.by_job[bid] = fake


func _run() -> void:
	Creations.persist = false
	print("Géologie réelle :")
	var names := {}
	for p in GisementsMonde.PROVINCES:
		names[p[1]] = p[0]
		if not (Ressources.SOUS_SOL.has(p[0]) or Ressources.ROCHES.has(p[0])):
			_check(false, "province de ressource inconnue : %s" % p[1])
	_check(names.get("Jura") == "calcaire" and names.get("Massif armoricain (Bretagne)") == "granite"
		and String(names.get("Bassin salifère lorrain (Varangéville, Dombasle)", "")) == "sel", "provinces : Jura calcaire, Bretagne granite, sel lorrain")
	var c0 := CarteRessources.new(null)
	c0.provinces = GisementsMonde.near(46.8, 6.2, 40.0)
	var jura_cal := c0.lithologie("calcaire", 46.8, 6.2)
	var jura_gra := c0.lithologie("granite", 46.8, 6.2)
	c0.provinces = GisementsMonde.near(48.2, -3.0, 40.0)
	var bzh_gra := c0.lithologie("granite", 48.2, -3.0)
	_check(jura_cal > 0.55 and jura_gra < 0.31, "Jura : calcaire %.2f, granite %.2f" % [jura_cal, jura_gra])
	_check(bzh_gra > 0.55, "Bretagne : granite %.2f" % bzh_gra)
	c0.provinces = GisementsMonde.near(48.62, 6.35, 40.0)
	var sel_best := 0.0
	for i in 30:
		for j in 30:
			sel_best = maxf(sel_best, c0.deposit("sel", 48.5 + i * 0.008, 6.2 + j * 0.01))
	_check(sel_best > 0.4, "sel gemme sous la Lorraine (%.2f)" % sel_best)
	_check(ProductionTypes.prod_of("cimenterie").in.has("calcaire") and ProductionTypes.prod_of("usine_agro").in.has("sel"),
		"cimenterie au calcaire et à l'argile, sel dans l'usine agroalimentaire")

	print("Fosse en gradins :")
	var hs := PackedFloat32Array()
	hs.resize(40 * 30)
	hs.fill(40.0)
	var f := Fosse.new()
	f.gradin = 6.0
	f.risberme = 4
	f.profondeur = 18.0
	f.preparer(Rect2i(100, 100, 40, 30), hs, -1)
	var cap := f.capacite()
	# 3 gradins : 40×30, 32×22, 24×14 cases de 6 m.
	var attendu := 6.0 * (40 * 30 + 32 * 22 + 24 * 14)
	_check(absf(cap - attendu) < 0.1, "capacité %.0f m³ (attendu %.0f)" % [cap, attendu])
	var ch := f.avancer(5.0)
	_check(ch.is_empty() and f.vol == 5.0, "5 m³ : pas encore une passe complète")
	ch = f.avancer(600.0)
	_check(ch.size() == 100, "605 m³ : 100 cases taillées d'un gradin de 6 m (%d)" % ch.size())
	var all_six := true
	for c in ch:
		all_six = all_six and float(ch[c]) == 34.0
	_check(all_six, "les cases taillées descendent à 34 m")
	_check(f.front.y == 100 or f.front.y == 101 or f.front.y == 102, "le front avance depuis le côté nord")
	var g := Fosse.from_dict(f.to_dict())
	_check(g.cur == f.cur and g.passes == f.passes, "rejouée depuis la sauvegarde : même relief")
	f.avancer(1.0e9)
	_check(f.pleine() and absf(f.vol - cap) < 0.1, "fosse pleine : on n'extrait pas plus que sa capacité")
	_check(f.hauteur(Vector2i(120, 115)) == 22.0 and f.hauteur(Vector2i(100, 100)) == 34.0, "fond à 22 m, premier gradin au bord")
	var v := Fosse.new()
	v.gradin = 3.0
	v.risberme = 3
	v.profondeur = 9.0
	v.preparer(Rect2i(0, 0, 20, 20), PackedFloat32Array(Array(range(400)).map(func(_i: int) -> float: return 10.0)), 1)
	v.avancer(1.0e9)
	_check(v.hauteur(Vector2i(10, 10)) == 19.0 and v.hauteur(Vector2i(0, 0)) == 13.0, "verse en tronc de pyramide (19 m au centre, 13 m au bord)")

	print("Dans la scène :")
	BatimentsVie.chantiers = false
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var transport: TransportSystem = scene.get_node("Transport")
	var bs: BuildingSystem = scene.get_node("Batiments")
	var amb: DayNight = scene.get_node("Ambiance")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	const LAT := 49.15
	const LON := 6.75
	# Roche nue à l'ouest de l'origine, champs à l'est.
	world.land.offline_generator = func(_lat: float, lon: float) -> int: return 60 if lon < LON else 40
	world.view_radius_override = 900.0
	world.set_origin(LAT, LON)
	for i in 3000:
		await process_frame
		if i >= 150 and world.missing_chunk_count() == 0 and world._dirty.is_empty() and world._jobs.is_empty():
			break
	var prod: Production = scene.production
	var pop: Population = scene.population
	var car: Carrieres = scene.carrieres
	_check(car != null and prod.extraction_gate.is_valid() and bs.extra_check == Callable(car, "check_place"), "carrières branchées sur la production et la pose")
	amb.set_speed(0)
	amb.unix_time = _at("2026-03-10", 10.0) # un mardi
	bs.money = 1_000_000_000
	var y := world.cell_height(Vector2i(0, 0))
	_check(transport.build_segment("route", Vector3(-700, y, 0), Vector3(700, y, 0)).ok, "route est-ouest")
	var info := bs.check_place("carriere", Vector2i(-300, -25), bs.best_rotation("carriere", Vector2i(-300, -25)))
	_check(info.ok and String(info.get("info", "")).contains("estimée"), "sans sondage, la richesse est estimée : %s" % info.get("info", info.reason))
	var quarry := bs.place("carriere", Vector2i(-300, -25), bs.best_rotation("carriere", Vector2i(-300, -25)))
	_check(quarry > 0, "carrière posée sur la roche")
	# Meilleur point de charbon à l'est (champs), avec sa propre route.
	var best := -1.0
	var mx := 350
	var mz := -420
	for zz in [-500, -420, -340, 340, 420, 500]:
		for xx in range(150, 560, 50):
			var r := prod.carte.mean_in("charbon", Rect2i(xx - 60, zz - 230, 120, 200))
			if r > best:
				best = r
				mx = xx
				mz = zz
	var ym := world.cell_height(Vector2i(mx, mz))
	_check(transport.build_segment("route", Vector3(mx - 250, ym, mz), Vector3(mx + 250, ym, mz)).ok, "route vers le gisement de charbon (%.2f)" % best)
	var mine := bs.place("mine_ciel_ouvert", Vector2i(mx - 60, mz - 26), bs.best_rotation("mine_ciel_ouvert", Vector2i(mx - 60, mz - 26)))
	_check(mine > 0, "mine à ciel ouvert posée %s" % ("" if mine > 0 else bs.check_place("mine_ciel_ouvert", Vector2i(mx - 60, mz - 26), 0).reason))
	var deep := bs.place("mine", Vector2i(mx + 60, mz + 24), bs.best_rotation("mine", Vector2i(mx + 60, mz + 24)))
	_check(deep > 0, "mine souterraine posée en face %s" % ("" if deep > 0 else bs.check_place("mine", Vector2i(mx + 60, mz + 24), 0).reason))
	for i in 5:
		await process_frame
	prod._sync()
	await process_frame
	await process_frame
	_check(car.sites.has(quarry) and car.sites[quarry].fosse != null, "périmètre de la carrière posé tout seul à côté")
	var fq: Fosse = car.sites[quarry].fosse
	var br := bs._rect_of(bs.buildings[quarry])
	_check(not fq.rect.intersects(br) and fq.rect.size.x == 110, "fosse de 110 m, hors des installations (%s)" % str(fq.rect))
	_check(not fq.rect.intersects(Rect2i(-800, -3, 1600, 6)), "la fosse ne touche pas la route")
	_check(car.sites[quarry].verse != null, "verse à stériles posée")
	_check(not bs.check_place("maison", fq.rect.get_center(), 0).ok, "on ne bâtit pas dans le périmètre")
	_check(bool(car.sites[quarry].ok) and float(prod.sites[quarry].reserve) > 100000.0, "réserve tirée du périmètre : %s" % Ressources.format_t(float(prod.sites[quarry].reserve)))
	if mine > 0:
		_check(car.sites.has(mine) and car.sites[mine].fosse != null and car.sites[mine].fosse.rect.size.x >= 100, "fosse de la mine à ciel ouvert")
	if deep > 0:
		_check(car.sites.has(deep) and car.sites[deep].verse != null and car.sites[deep].fosse == null, "terril de la mine souterraine")

	print("Extraction : le terrain se creuse")
	_staff(pop, quarry, "carriere")
	if mine > 0:
		_staff(pop, mine, "mine_ciel_ouvert")
	if deep > 0:
		_staff(pop, deep, "mine")
	var h_before := world.cell_height(fq.rect.get_center())
	var res0 := float(prod.sites[quarry].reserve)
	for d in 20:
		prod.step_hours(24.0)
		# Les camions emportent tout : le stock ne bloque pas l'extraction.
		for bid in [quarry, mine, deep]:
			if bid > 0:
				prod.sites[bid].st = {}
	car.flush()
	_check(String(prod.sites[quarry].status).begins_with("En activité"), "carrière en activité : %s" % prod.sites[quarry].status)
	_check(fq.passes > 50, "%d cases taillées en 20 jours, front en %s" % [fq.passes, str(fq.front)])
	var front_h := world.cell_height(fq.front)
	_check(front_h <= y - fq.gradin + 0.01, "le relief descend au front (%.1f m → %.1f m)" % [y, front_h])
	_check(float(prod.sites[quarry].reserve) < res0, "la réserve baisse (%s)" % Ressources.format_t(float(prod.sites[quarry].reserve)))
	_check(world.biome_paint.get(fq.front, -1.0) == 3.0, "fond de fosse en roche")
	var vq: Fosse = car.sites[quarry].verse
	_check(vq.vol > 0.0, "la verse reçoit les stériles (%.0f m³)" % vq.vol)
	if deep > 0:
		_check((car.sites[deep].verse as Fosse).vol > 0.0, "le terril monte (%.0f m³)" % (car.sites[deep].verse as Fosse).vol)
	if mine > 0:
		_check((car.sites[mine].fosse as Fosse).passes > 0, "la mine à ciel ouvert creuse aussi (%d passes)" % (car.sites[mine].fosse as Fosse).passes)
	var inf := car.info(quarry)
	_check(float(inf.prof) >= 6.0 and int(inf.gradins) >= 2, "fiche : profondeur %.0f m, gradin %d/%d" % [inf.prof, inf.gradin, inf.gradins])

	print("Engins et tir de mine :")
	var rig: Node3D = scene.rig
	rig.position = Vector3(fq.rect.get_center().x, 0, fq.rect.get_center().y)
	amb.unix_time = _at("2026-03-10", 11.9)
	await process_frame
	await process_frame
	_check(car._visuels.has(quarry), "pelle et tombereau au travail")
	var msgs := []
	car.message.connect(func(t: String) -> void: msgs.append(t))
	amb.unix_time = _at("2026-03-10", 12.1)
	await process_frame
	_check(msgs.any(func(t: String) -> bool: return t.begins_with("Tir de mine")), "tir de mine à midi")
	amb.unix_time = _at("2026-03-10", 20.0)
	await process_frame
	_check(not car._visuels.has(quarry), "le soir, les engins sont rangés")
	_check(not car.nuisances().is_empty() and bool(car.nuisances()[0].tir), "nuisances pour le bruit et la poussière")

	print("Épuisement :")
	var save_vol := fq.vol
	prod.sites[quarry].reserve = 10.0
	prod.step_hours(24.0)
	prod.step_hours(24.0)
	_check(String(prod.sites[quarry].status) == "Gisement épuisé", "gisement épuisé : %s" % prod.sites[quarry].status)
	ReglagesPartie.actuel.epuisement = false
	prod.sites[quarry].st = {}
	prod.step_hours(24.0)
	_check(String(prod.sites[quarry].status).begins_with("En activité"), "sans épuisement (Admin), on extrait toujours")
	ReglagesPartie.actuel.epuisement = true
	_check(fq.vol >= save_vol, "volume creusé conservé")

	print("Périmètre dessiné :")
	var bad := car.set_perimetre(quarry, Rect2i(-320, 60, 10, 10))
	_check(bad.contains("petit"), "trop petit : %s" % bad)
	var through := car.set_perimetre(quarry, Rect2i(-350, -20, 60, 60))
	_check(through != "", "refusé sur la route ou les installations : %s" % through)
	var m0 := bs.money
	var newr := Rect2i(fq.rect.position.x - 70, fq.rect.position.y, 60, 60)
	var okp := car.set_perimetre(quarry, newr)
	_check(okp == "" and (car.sites[quarry].fosse as Fosse).rect == newr and bs.money < m0, "nouveau périmètre de 60 × 60 m %s" % okp)
	await process_frame
	_check(bool(car.sites[quarry].ok) and float(prod.sites[quarry].reserve) > 0.0, "nouvelle réserve : %s" % Ressources.format_t(float(prod.sites[quarry].reserve)))

	print("Sondage :")
	var sc := Vector2i(-300, 200)
	_check(car.sonder(sc) == "" and car.sondages.size() == 1, "sondage lancé")
	await process_frame
	_check(car._foreuses.size() == 1 or Vector2(rig.position.x, rig.position.z).distance_to(Vector2(sc)) > Carrieres.VUE, "foreuse sur place")
	amb.unix_time += 3.0 * 86400.0
	car._sondages_tick()
	_check(not (car.sondages[0].res as Dictionary).is_empty(), "résultats : %s" % Carrieres.resume_sondage(car.sondages[0]))
	var near := bs.check_place("carriere", Vector2i(-300, 225), 0)
	_check(String(near.get("info", near.reason)).contains("sondé") or not near.ok, "pose près du sondage : richesse exacte (%s)" % near.get("info", near.reason))

	print("Réaménagement :")
	var fold := Fosse.from_dict(fq.to_dict())
	var lake := car.reamenager(quarry, "lac")
	_check(lake == "" and String(car.sites[quarry].fin) == "lac", "plan d'eau")
	prod.step_hours(24.0)
	_check(String(prod.sites[quarry].status).begins_with("Site fermé"), "site fermé : %s" % prod.sites[quarry].status)
	if mine > 0:
		var fm: Fosse = car.sites[mine].fosse
		var any := fm.cases_modifiees().keys()
		_check(car.reamenager(mine, "remblai") == "", "mine comblée")
		var c1: Vector2i = any[0] if not any.is_empty() else fm.rect.get_center()
		_check(world.cell_height(c1) == y and world.biome_paint.get(c1, -1.0) == 6.0, "remblai : relief d'origine et prairie")

	print("Sauvegarde :")
	car.flush()
	var d := car.to_dict()
	var json: Dictionary = JSON.parse_string(JSON.stringify(d))
	var car2 := Carrieres.new()
	car2.world = world
	car2.buildings = bs
	car2.production = prod
	car2.from_dict(json)
	_check(car2.sites.size() == car.sites.size() and car2.sondages.size() == 1, "sites et sondages relus")
	_check(String(car2.sites[quarry].fin) == "lac", "réaménagement relu")
	_check((car2.sites[quarry].verse as Fosse).cur == vq.cur, "verse relue à l'identique")
	_check(fold.cur == fq.cur, "fosse rejouée à l'identique")
	car2.free()

	pop.by_job.clear()
	print("TEST OK" if ok else "TEST ÉCHEC")
	quit(0 if ok else 1)
