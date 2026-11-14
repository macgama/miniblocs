extends SceneTree
## Test des musées : bible des objets et leurs modèles, musées prêts à poser
## (murs, salles, meubles), analyse et note, visiteurs et billets dans la caisse,
## expositions, charges, sauvegarde, panneau et bouton de la barre du bas.
## Usage : godot --headless --path . --script res://tests/musee_test.gd

var ok := true

## Samedi 18 juillet 2026, 9 h (UTC+2).
const SAMEDI := 1_784_358_000.0


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
	print("Bible des objets :")
	var n := 0
	var vides := []
	var fams := {}
	for e in MuseeObjets.entries():
		var id := String(e.id)
		if Meubles.get_entry(id).is_empty():
			_check(false, "%s dans la bible des meubles" % id)
		var m := MeublesModeles.mesh_of(id)
		if m == null or m.get_surface_count() == 0:
			vides.append(id)
		fams[String(e.p[1])] = true
		n += 1
	_check(n >= 100, "%d objets de musée" % n)
	_check(vides.is_empty(), "chaque objet a un modèle 3D %s" % str(vides))
	_check(fams.size() == MuseeObjets.FAMILLE_ORDER.size(), "%d familles remplies" % fams.size())
	for fam in MuseeObjets.FAMILLE_ORDER:
		_check(not MuseeObjets.of_famille(String(fam)).is_empty(), "famille %s" % fam)
		_check(Icones.has_icon(String(MuseeObjets.FAMILLES[fam].icon)), "icône de la famille %s" % fam)
	for fn in MuseeObjets.SALLE_ORDER:
		_check(MuseeObjets.LAYOUTS.has(fn), "aménagement de la salle %s" % fn)
		for row in MuseeObjets.LAYOUTS[fn]:
			for mid in row[0]:
				if Meubles.get_entry(String(mid)).is_empty():
					_check(false, "%s : %s existe" % [fn, mid])
	_check(Mobilier.USAGE_ORDER.has("musee"), "usage Musée pour les bâtiments meublés")
	_check(BuildingCatalog.get_type("musee") != null and not BuildingCatalog.get_type("musee").is_empty(), "musée dans le catalogue Construire")
	var bm := BuildingCatalog.build_mesh("musee")
	_check(bm != null and bm.get_surface_count() > 0, "modèle du musée du catalogue")
	for j in Metiers.jobs_for("musee"):
		_check(Metiers.METIERS.has(String(j[0])), "métier %s connu" % j[0])
	for kind in MuseeGabarits.ORDER:
		_check(Gabarits.has_kind(String(kind)), "gabarit %s" % kind)
		var lv := MuseeGabarits.levels_of(String(kind))
		_check(lv.size() == (MuseeGabarits.KINDS[kind].salles as Array).size(), "%s : %d niveau(x)" % [kind, lv.size()])
	var sp := MuseeGabarits.spec("musee_beaux_arts")
	_check(int(sp.wall_mat) >= 0 and int((sp.floors as Dictionary).get("galerie_peinture", -1)) >= 0, "pierre de taille et parquet Versailles trouvés")
	_check(Icones.has_icon("musee"), "icône du musée")


func _city_tests() -> void:
	print("Ville :")
	Creations.persist = false
	BatimentsVie.chantiers = false
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	var bs: BuildingSystem = scene.get_node("Batiments")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 40
	world.view_radius_override = 600.0
	world.set_origin(46.2, 6.9)
	for i in 3000:
		await process_frame
		if i >= 120 and world.missing_chunk_count() == 0 and world._dirty.is_empty() and world._jobs.is_empty():
			break
	var musee: Musee = scene.musee
	var mob: Mobilier = scene.mobilier
	var pe: PlanEditor = scene.get_node("Plans")
	_check(musee != null and scene.musee_panel != null, "musée et panneau branchés dans la scène")
	_check(scene.save_sections().has("musee"), "section « musee » dans la sauvegarde")
	musee.set_process(false)
	scene.population.set_process(false)
	scene.urgences.set_process(false)
	scene.urgences.random_calls = false
	bs.unlimited_money = false
	bs.money = 50_000_000

	# Bouton de la barre du bas.
	var hud: TerreHud = scene.hud
	var found := false
	for c in hud.CATEGORIES:
		if String(c.id) == "musee":
			found = String(c.group) == "loisirs"
	_check(found, "bouton Musée dans le menu Loisirs de la barre du bas")
	scene.musee_panel.set_open(false)
	hud._on_category("musee")
	_check(scene.musee_panel.is_open(), "le bouton ouvre le panneau du musée")

	print("Musées prêts à poser :")
	mob.set_style("contemporain")
	var keys := {}
	var x := -80
	for kind in MuseeGabarits.ORDER:
		var res := Gabarits.build(mob, String(kind), Vector2i(x, 40), 0, "contemporain")
		_check(res.ok, "%s posé (%s)" % [MuseeGabarits.KINDS[kind].name, BuildingSystem.format_money(int(res.get("cost", 0))) if res.ok else String(res.get("error", ""))])
		if res.ok:
			keys[kind] = String(res.id)
		x += 36
	pe.flush()
	mob.flush()
	musee._dirty = true
	var l := musee.list()
	_check(l.size() == keys.size(), "%d musées reconnus" % l.size())
	var ba := String(keys.get("musee_beaux_arts", ""))
	_check(ba != "" and mob.usage_of(ba) == "musee", "usage Musée")
	_check(pe.levels_of(ba).size() == 2 and not pe.plans[ba].stairs.is_empty(), "beaux-arts : deux niveaux et un escalier")
	var a := musee.analyse(ba)
	_check(int(a.oeuvres) > 15, "%d œuvres exposées" % int(a.oeuvres))
	_check(bool(a.billetterie), "billetterie dans le hall")
	_check((a.services as Dictionary).has("toilettes") and (a.services as Dictionary).has("boutique") and (a.services as Dictionary).has("cafe"), "toilettes, boutique et café : %s" % str((a.services as Dictionary).keys()))
	_check((a.themes as Dictionary).size() >= 2, "plusieurs collections : %s" % str((a.themes as Dictionary).keys()))
	_check(float(a.note) >= 2.5, "note : %.1f étoiles %s" % [float(a.note), str(a.detail)])
	_check(int(a.capacite) > 50, "capacité : %d visiteurs" % int(a.capacite))
	var sal := 0
	for s in a.salles:
		if MuseeObjets.SALLES.has(String(s.fn)):
			sal += 1
	_check(sal >= 8, "%d salles de musée" % sal)
	var stats := mob.stats(ba)
	_check(int(stats.emplois) >= 4, "%d emplois au musée" % int(stats.emplois))
	for kind in keys:
		var ak := musee.analyse(String(keys[kind]))
		print("    %s : %.1f ★, %d œuvres, prestige %d" % [kind, float(ak.note), int(ak.oeuvres), roundi(float(ak.prestige))])
		_check(float(ak.note) >= 2.0, "%s ouvre avec une note correcte" % kind)
	var dn := String(keys.get("museum_nature", ""))
	_check(dn != "" and bool(musee.analyse(dn).dinos), "le muséum expose des dinosaures")

	# Une œuvre posée à la main dans une salle vide : coup de pouce à la note.
	var village := String(keys.get("musee_village", ""))
	var n0 := int(musee.analyse(village).oeuvres)
	var pr0 := float(musee.analyse(village).prestige)
	var placed := false
	for z in range(45, 50):
		for xx in range(-79, -67):
			if not placed:
				var why := mob.place(village, 0, Vector2i(xx, z), 0, "musee/statue_antique")
				placed = why == ""
	mob.flush()
	_check(placed and int(musee.analyse(village).oeuvres) == n0 + 1, "un chef-d'œuvre posé à la main compte (%d → %d)" % [n0, int(musee.analyse(village).oeuvres)])
	_check(float(musee.analyse(village).prestige) > pr0, "et le prestige monte (%d → %d)" % [roundi(pr0), roundi(float(musee.analyse(village).prestige))])

	print("Visiteurs et caisse :")
	musee.clock = SAMEDI - 3600.0
	musee.last_day = int(musee._now(musee.clock).day)
	var now := musee._now(SAMEDI + 3 * 3600.0)
	_check(int(now.wd) == 6 and int(now.month) == 7, "samedi de juillet à %.0f h" % float(now.h))
	_check(musee.est_ouvert(ba, now), "ouvert à midi")
	_check(not musee.est_ouvert(ba, musee._now(SAMEDI + 2 * 86400.0 + 3 * 3600.0)), "fermé le lundi")
	var att := musee.attendus(ba, now)
	_check(float(att[0]) + float(att[1]) > 100.0, "visiteurs attendus : %d habitants, %d touristes" % [roundi(float(att[0])), roundi(float(att[1]))])
	var caisse0 := bs.money
	for i in 12:
		musee.clock += Musee.STEP
		musee.step(Musee.STEP)
		if i == 4:
			_check(musee.presents(ba) > 0, "%d visiteurs dans le musée à 14 h" % musee.presents(ba))
			musee.visuels._peupler()
			_check(musee.visuels.count() > 0, "%d visiteurs dessinés dans les salles" % musee.visuels.count())
			var c := musee.visuels.carte(ba)
			_check(c.has(0) and not (c[0].spots as Array).is_empty(), "points de vue devant les œuvres (%d)" % (c[0].spots as Array).size())
			var path: Array = musee.visuels.chemin(ba, 0, (c[0].walk as Dictionary).keys()[0], (c[0].spots as Array)[0][0])
			_check(not path.is_empty(), "les visiteurs passent de salle en salle (%d cases)" % path.size())
			for k in 120:
				musee.visuels._bouger(0.1)
	var st: Dictionary = musee.musees[ba]
	_check(int(st.jour.visiteurs) > 100, "%d visiteurs ce samedi" % int(st.jour.visiteurs))
	_check(float(st.jour.billets) > 500.0, "billets : %s" % BuildingSystem.format_money(int(st.jour.billets)))
	_check(float(st.jour.boutique) > 0.0 and float(st.jour.cafe) > 0.0, "boutique et café encaissent")
	_check(bs.money > caisse0, "les recettes arrivent dans la caisse (+%s)" % BuildingSystem.format_money(bs.money - caisse0))
	_check(not (st.dernieres as Array).is_empty(), "les visiteurs parlent : « %s »" % String((st.dernieres as Array)[0]))
	_check(musee.presents(ba) == 0, "fermé le soir, plus personne")
	# Prix du billet : plus cher = moins de monde.
	var att_cher: Array
	musee.set_prix(ba, 30.0)
	att_cher = musee.attendus(ba, now)
	musee.set_prix(ba, Musee.PRIX_BILLET)
	_check(float(att_cher[0]) + float(att_cher[1]) < float(att[0]) + float(att[1]), "un billet à 30 € fait fuir des visiteurs")

	print("Expositions :")
	var avant := float(musee.analyse(ba).note)
	var err := musee.lancer_expo(ba, "impressionnistes")
	_check(err == "", "exposition lancée %s" % err)
	_check(musee.jours_expo(ba) > 0, "%d jours d'exposition" % musee.jours_expo(ba))
	_check(float(musee.analyse(ba).note) >= avant, "l'exposition fait monter la note (%.1f → %.1f)" % [avant, float(musee.analyse(ba).note)])
	_check(musee.lancer_expo(ba, "dinosaures") != "", "une seule exposition à la fois")
	var caisse1 := bs.money
	musee.new_day(musee._now(musee.clock))
	_check(bs.money < caisse1, "salaires et assurance payés chaque jour (-%s)" % BuildingSystem.format_money(caisse1 - bs.money))
	_check(int(musee.musees[ba].hier.visiteurs) > 100, "bilan d'hier gardé")

	print("Sauvegarde :")
	musee.renommer(ba, "Musée du Lac")
	var d: Dictionary = JSON.parse_string(JSON.stringify(musee.to_dict()))
	musee.from_dict(d)
	musee._sync()
	_check(musee.nom(ba) == "Musée du Lac", "le nom revient")
	_check(String(musee.musees[ba].expo) == "impressionnistes", "l'exposition revient")
	_check(int(musee.musees[ba].hier.visiteurs) > 100, "les chiffres reviennent")

	print("Panneau :")
	var panel: MuseePanel = scene.musee_panel
	panel.set_open(true)
	panel.choisi = ba
	for v in MuseePanel.TABS:
		panel.show_view(String(v[1]))
		await process_frame
		_check(panel._body.get_child_count() > 0, "onglet %s" % v[0])
	panel.famille = "peinture"
	panel.show_view("objets")
	await process_frame
	_check(panel._body.get_child_count() > 2, "cartes d'objets de la peinture")

	# Bâtiment du catalogue.
	var y := world.cell_height(Vector2i(0, -200))
	var road: Dictionary = scene.get_node("Transport").build_segment("route", Vector3(-200, y, -200), Vector3(200, y, -200))
	var c0 := Vector2i(0, -180)
	var bid := bs.place("musee", c0, bs.best_rotation("musee", c0))
	if bid < 0:
		print("    pose du musée : ", bs.check_place("musee", c0, bs.best_rotation("musee", c0)).reason)
	musee._dirty = true
	_check(bid > 0 and musee.list().has("bat_%d" % bid), "un musée du catalogue est un musée géré")
	if bid > 0:
		_check(float(musee.analyse("bat_%d" % bid).note) > 2.0, "avec une collection déjà installée")
	scene.queue_free()
	await process_frame
