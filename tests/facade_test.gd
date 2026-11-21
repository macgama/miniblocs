extends SceneTree
## Test « Modifier la façade » et « Aménager l'intérieur » depuis la fiche d'un
## bâtiment classique (la maison de base du zonage) : style du monde, couleurs,
## étages, devis payé ou annulé, tuiles illustrées de la fiche, intérieur ouvert
## en murs fins et meublé. Chaque modèle classique se dessine dans chacun de ses
## styles.
## Usage : godot --headless --path . --script res://tests/facade_test.gd

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


func _spot(bs: BuildingSystem, id: String, c: Vector2i) -> Vector2i:
	for dist in [0, 40, 60, 90, 120, 160, 200]:
		for i in 16:
			var a := float(i) / 16.0 * TAU
			var q := c + Vector2i(roundi(cos(a) * dist), roundi(sin(a) * dist))
			if bs.check_place(id, q, 0).ok:
				return q
	return c


func _cols(bs: BuildingSystem, bid: int) -> PackedColorArray:
	return (bs.node_of(bid).mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_COLOR] as PackedColorArray


func _run() -> void:
	Creations.persist = false
	BatimentsVie.chantiers = false
	GameStart.chosen = true
	GameStart.place_name = "Valfleuri, Savoie"
	ReglagesPartie.prochaine = ReglagesPartie.preset("normal")
	ReglagesPartie.prochaine.deblocage = "tout"
	ReglagesPartie.prochaine.services_fondation = false

	print("Modèles classiques dans chaque style :")
	var n_mesh := 0
	var vides := []
	for tid in Personnalisation.CLASSIQUES:
		if BuildingCatalog.get_type(tid).is_empty():
			continue
		_check(Personnalisation.is_classic(tid) and Personnalisation.can_customize(tid), "%s : façade modifiable" % tid)
		var styles := Personnalisation.styles_for(tid)
		_check(styles.size() >= 3, "%s : %d styles proposés" % [tid, styles.size()])
		for sid in styles:
			var m := BuildingCatalog.build_mesh(tid, null, true, 0, {"style": sid})
			n_mesh += 1
			if m == null or m.get_surface_count() == 0:
				vides.append("%s/%s" % [tid, sid])
	_check(vides.is_empty(), "%d maquettes dessinées, aucune vide %s" % [n_mesh, vides])
	_check(not Personnalisation.is_classic("longere") and not Personnalisation.is_classic("colombages__maison"), "seuls les modèles classiques changent de style")
	_check(Conversion.can_open("maison") and Conversion.can_open("immeuble") and Conversion.can_open("boulangerie"), "maison, immeuble, boulangerie s'ouvrent")
	var c0 := Personnalisation.cout_travaux("maison", {}, {"mur": "3d6fa8"}, 280_000)
	var c1 := Personnalisation.cout_travaux("maison", {}, {"style": "alpin"}, 280_000)
	var c2 := Personnalisation.cout_travaux("maison", {}, {"style": "alpin", "etages": 4}, 280_000)
	_check(c0 > 0 and c1 > c0 and c2 > c1, "devis : peinture %s < style %s < style et étages %s" % [
		BuildingSystem.format_money(c0), BuildingSystem.format_money(c1), BuildingSystem.format_money(c2)])
	_check(c0 == 8_400, "repeindre les murs : 3 %% du prix (%s)" % BuildingSystem.format_money(c0))
	_check(Personnalisation.cout_travaux("maison", {}, {"style": Personnalisation.style_defaut("maison"), "toit": "gable"}.merged(Personnalisation.CLASSIQUE_COULEURS), 280_000) == 0,
		"le style posé d'office n'est pas facturé")
	_check(Personnalisation.cout_travaux("maison", {"mur": "3d6fa8"}, {"mur": "3d6fa8"}, 280_000) == 0, "rien changé, rien à payer")

	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var bs: BuildingSystem = scene.get_node("Batiments")
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
	scene.population.arrivals = false
	bs.require_access = false
	bs.unlimited_money = false
	bs.money = 5_000_000
	scene.communes.nom_en_attente = "Valfleuri"
	bs.place("maison_commune", Vector2i(-60, -60), 0)
	for i in 4:
		await process_frame

	print("Fiche d'une maison classique :")
	var m1 := bs.place("maison", _spot(bs, "maison", Vector2i(0, 0)), 0)
	var m2 := bs.place("maison", _spot(bs, "maison", Vector2i(30, 0)), 0)
	_check(m1 >= 0 and m2 >= 0, "deux maisons posées")
	for i in 4:
		await process_frame
	var pop: Population = scene.population
	bs.buildings[m1]["chantier"] = false
	pop._sync_buildings()
	var hp: HabitantsPanel = scene.habitants_panel
	hp.set_open(true)
	hp.show_view("batiment", m1)
	await process_frame
	var tf: Button = hp._body.find_child("TuileFacade", true, false)
	var ti: Button = hp._body.find_child("TuileInterieur", true, false)
	_check(tf != null and tf.icon != null and tf.text.begins_with("Modifier la façade"), "tuile illustrée « Modifier la façade »")
	_check(ti != null and ti.icon != null and ti.text.begins_with("Aménager l'intérieur"), "tuile illustrée « Aménager l'intérieur »")

	print("Modifier la façade :")
	var pp: PersoPanel = scene.perso_panel
	if tf != null:
		tf.pressed.emit()
	await process_frame
	_check(pp.is_open() and pp.bid == m1, "la tuile ouvre le panneau sur cette maison")
	_check(pp.devis() == 0 and not pp.a_des_changements(), "devis vide à l'ouverture")
	var cols0 := _cols(bs, m1)
	pp._pick("mur", Color("3d6fa8"))
	await process_frame
	var p1 := bs.perso_of(m1)
	_check(String(p1.get("style", "")) == Personnalisation.style_defaut("maison") and String(p1.get("mur", "")) == "3d6fa8"
		and String(p1.get("toit_c", "")) == "c8553d", "murs en bleu : style par défaut posé, toit d'origine gardé (%s)" % str(p1))
	_check(_cols(bs, m1) != cols0, "la maison change tout de suite")
	var prix := pp.devis()
	_check(prix > 0, "devis des travaux : %s" % BuildingSystem.format_money(prix))
	pp.fermer()
	await process_frame
	_check(bs.perso_of(m1).is_empty() and _cols(bs, m1) == cols0, "fermer sans valider : la maison redevient comme avant")
	var argent0 := bs.money
	pp.edit(m1)
	pp._apply({"style": "alpin"})
	await process_frame
	var p2 := Personnalisation.completer("maison", pp._perso())
	p2["etages"] = Personnalisation.base_floors("maison", p2) + 1
	pp._apply(p2)
	await process_frame
	var h_avant := bs.node_of(m2).mesh.get_aabb().size.y
	var h_apres := bs.node_of(m1).mesh.get_aabb().size.y
	_check(String(bs.perso_of(m1).get("style", "")) == "alpin" and h_apres > h_avant, "chalet alpin avec un étage de plus (%.1f m → %.1f m)" % [h_avant, h_apres])
	prix = pp.devis()
	_check(pp.valider() and bs.money == argent0 - prix, "travaux validés et payés : %s" % BuildingSystem.format_money(prix))
	_check(pp.devis() == 0, "devis remis à zéro")
	pp.fermer()
	_check(String(bs.perso_of(m1).get("style", "")) == "alpin", "fermer après validation garde les travaux")
	bs.money = 100
	pp.edit(m1)
	pp._pick("porte", Color("c2453a"))
	_check(not pp.valider(), "caisse vide : travaux refusés")
	pp.fermer()
	bs.money = 5_000_000
	_check(String(bs.perso_of(m1).get("porte", "")) != "c2453a" and String(bs.perso_of(m1).get("style", "")) == "alpin",
		"porte refusée : pas gardée, le chalet reste")

	print("Aménager l'intérieur :")
	var mob: Mobilier = scene.mobilier
	var nb_plans := mob.pe._bbox.size()
	hp.set_open(true)
	hp.show_view("batiment", m2)
	await process_frame
	ti = hp._body.find_child("TuileInterieur", true, false)
	if ti != null:
		ti.pressed.emit()
	for i in 4:
		await process_frame
	_check(not bs.buildings.has(m2) and mob.pe._bbox.size() == nb_plans + 1, "la maison classique est refaite en murs fins")
	var hud: TerreHud = scene.hud
	_check(hud.create_mode, "l'onglet Intérieur s'ouvre (mode Créer)")
	var meubles := 0
	for pid in mob.items:
		meubles = maxi(meubles, (mob.items[pid] as Dictionary).size())
	_check(meubles > 8, "meublée (%d meubles)" % meubles)

	print("Aménager l'intérieur d'une maison à une autre taille (10 × 14 m, 3 niveaux) :")
	var tid3 := "maison@10x14x3"
	_check(not BuildingCatalog.get_type(tid3).is_empty(), "type %s connu" % tid3)
	var m3 := bs.place(tid3, _spot(bs, tid3, Vector2i(-40, 40)), 0)
	_check(m3 >= 0, "maison de 3 niveaux posée")
	if m3 >= 0:
		for i in 4:
			await process_frame
		var h3 := bs.node_of(m3).mesh.get_aabb().size.y
		var plans0 := mob.pe._bbox.keys()
		var r3 := Conversion.open_interior(mob, m3)
		_check(r3.ok, "intérieur ouvert (%s)" % str(r3))
		if r3.ok:
			var pid3 := String(r3.id)
			mob.pe.flush()
			var niveaux := (mob.pe._nodes.get(pid3, {}) as Dictionary).size()
			_check(niveaux == 3, "toujours 3 niveaux (%d)" % niveaux)
			var bb3: Rect2i = mob.pe._bbox[pid3]
			_check(maxi(bb3.size.x, bb3.size.y) == 9 and mini(bb3.size.x, bb3.size.y) == 8, "même emprise que la façade (%s)" % str(bb3.size))
			_check(not plans0.has(pid3) and h3 > 8.0, "hauteur de la maison d'origine %.1f m" % h3)

	print("FACADE TEST OK" if ok else "FACADE TEST ÉCHEC")
	quit(0 if ok else 1)
