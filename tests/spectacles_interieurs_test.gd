extends SceneTree
## Test de l'intérieur des salles de spectacle et des studios : objets (bible
## des meubles, modèles), salles prêtes à poser (murs, scène, fauteuils face à
## la scène, foyer), chiffres (places, emplois, manques), reconnaissance par le
## menu Spectacles, une soirée et une séance dans une salle en murs fins, un
## film tourné dans un studio en murs fins, sauvegarde et menu.
## Usage : godot --headless --path . --script res://tests/spectacles_interieurs_test.gd

var ok := true

## Samedi 18 juillet 2026, 9 h (heure de Suisse romande, UTC+2).
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
	_objets_tests()
	await _ville_tests()
	print("TEST OK" if ok else "TEST ÉCHEC")
	quit(0 if ok else 1)


func _objets_tests() -> void:
	print("Objets :")
	var n := 0
	var mauvais := []
	for e in SpectaclesObjets.entries():
		var id := String(e.id)
		if not Meubles.has(id):
			mauvais.append(id)
			continue
		var m := MeublesModeles.mesh_of(id)
		if m == null or m.get_surface_count() == 0:
			mauvais.append(id + " (pas de modèle)")
			continue
		var bb := m.get_aabb()
		if not bool(e.get("suspendu", false)) and (bb.size.x > float(e.w) + 0.15 or bb.size.z > float(e.d) + 0.15):
			mauvais.append("%s déborde (%.2f × %.2f)" % [id, bb.size.x, bb.size.z])
		n += 1
	_check(mauvais.is_empty(), "%d objets de spectacle dans la bible, avec leur modèle %s" % [n, str(mauvais)])
	_check(n == SpectaclesObjets.count() and n >= 50, "au moins 50 objets (%d)" % n)
	var inconnus := []
	for fn in SpectaclesObjets.LAYOUTS:
		for req in SpectaclesObjets.LAYOUTS[fn]:
			if Meubles.pick_any(req[0], "contemporain") == "":
				inconnus.append("%s : %s" % [fn, str(req[0])])
	for fn in SpectaclesObjets.SCENES:
		var sg := String(SpectaclesObjets.SCENES[fn].siege)
		if sg != "" and not Meubles.has(sg):
			inconnus.append(sg)
	for f in SpectaclesObjets.AUSSI:
		for id in SpectaclesObjets.AUSSI[f]:
			if not Meubles.has(String(id)):
				inconnus.append(String(id))
	_check(inconnus.is_empty(), "tous les objets des salles existent %s" % str(inconnus))
	for fn in SpectaclesObjets.SALLE_ORDER:
		_check(Mobilier.fn_name(String(fn)) == SpectaclesObjets.salle_name(String(fn)), "fonction %s nommée" % fn) if Mobilier.fn_name(String(fn)) != SpectaclesObjets.salle_name(String(fn)) else null
	for u in ["cinema", "theatre", "concert", "studio_cine"]:
		_check(Mobilier.USAGES.has(u) and Mobilier.USAGE_ORDER.has(u), "usage %s dans l'Intérieur" % u)
		_check(not BuildingCatalog.get_type(String(Mobilier.USAGES[u].t)).is_empty(), "usage %s : bâtiment %s connu" % [u, Mobilier.USAGES[u].t])
	_check(Meubles.style_of("spectacle").name == "Spectacle", "style Spectacle")


func _ville_tests() -> void:
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
	var spect: Spectacles = scene.spectacles
	var mob: Mobilier = scene.mobilier
	var pe: PlanEditor = scene.get_node("Plans")
	_check(spect.mob == mob, "le menu Spectacles voit l'Intérieur")
	for nd in [spect, scene.population, scene.musee, scene.parc, scene.zoo]:
		nd.set_process(false)
	scene.urgences.set_process(false)
	scene.urgences.random_calls = false
	if scene.ambiance.weather != null:
		scene.ambiance.weather.set_process(false)
		scene.ambiance.weather.precip = 0.0
	bs.unlimited_money = false
	bs.money = 200_000_000
	spect.ignore_staff = true

	print("Salles prêtes à poser :")
	var keys := {}
	var x := -260
	for kind in SpectaclesGabarits.ORDER:
		var g: Dictionary = SpectaclesGabarits.KINDS[kind]
		var res := Gabarits.build(mob, String(kind), Vector2i(x, 40), 0, "contemporain")
		_check(res.ok, "%s posé (%s)" % [g.name, BuildingSystem.format_money(int(res.get("cost", 0))) if res.ok else String(res.get("error", ""))])
		if res.ok:
			keys[kind] = String(res.id)
			_check(int(res.cost) <= int(g.budget), "%s : coût %s dans le budget annoncé (%s)" % [kind, BuildingSystem.format_money(int(res.cost)), BuildingSystem.format_money(int(g.budget))])
		x += int(g.w) + 8
	pe.flush()
	mob.flush()
	var attendu := {"cinema_village": [80, 140], "cinema_quartier": [200, 320], "theatre_poche": [50, 110], "theatre_ville": [400, 520], "opera_lyrique": [250, 550],
		"club_jazz_plan": [12, 60], "salle_musiques_actuelles_plan": [450, 1000], "auditorium_plan": [170, 300]}
	for kind in keys:
		var id := String(keys[kind])
		var st := mob.stats(id)
		_check(mob.usage_of(id) == String(SpectaclesGabarits.KINDS[kind].usage), "%s : usage %s" % [kind, mob.usage_of(id)])
		_check((st.manques as Array).is_empty(), "%s : rien ne manque %s" % [kind, str(st.manques)])
		_check(int(st.emplois) > 0, "%s : %d emplois" % [kind, int(st.emplois)])
		if attendu.has(kind):
			var a: Array = attendu[kind]
			_check(int(st.places) >= int(a[0]) and int(st.places) <= int(a[1]), "%s : %d places (entre %d et %d)" % [kind, int(st.places), int(a[0]), int(a[1])])
	spect._dirty = true
	var salles := spect.list_salles()
	var studios := spect.list_studios()
	_check(salles.size() == 8 and studios.size() == 1, "%d salles et %d studio reconnus par le menu Spectacles" % [salles.size(), studios.size()])
	var bid_of := func(kind: String) -> int: return mob.bid_of(String(keys.get(kind, "")))
	var village: int = bid_of.call("cinema_village")
	var quartier: int = bid_of.call("cinema_quartier")
	var tville: int = bid_of.call("theatre_ville")
	var opera: int = bid_of.call("opera_lyrique")
	var smac: int = bid_of.call("salle_musiques_actuelles_plan")
	var jazz: int = bid_of.call("club_jazz_plan")
	var audi: int = bid_of.call("auditorium_plan")
	var studio: int = bid_of.call("studios_tournage")
	_check(spect.famille_of(village) == "cinema" and spect.famille_of(tville) == "theatre" and spect.famille_of(smac) == "concert", "familles cinéma, théâtre, concert")
	_check(int(spect.spec(quartier).salles) == 3, "cinéma de quartier : %d écrans" % int(spect.spec(quartier).salles))
	_check(spect.places(village) == int(mob.stats(String(keys.cinema_village)).places), "places du menu = fauteuils posés (%d)" % spect.places(village))
	_check((spect.spec(opera).genres as Array).has("opera") and not (spect.spec(tville).genres as Array).has("opera"), "la fosse d'orchestre ouvre l'opéra")
	_check((spect.spec(smac).genres as Array).has("rock") and (spect.spec(audi).genres as Array).has("classique") and (spect.spec(jazz).genres as Array).has("jazz"),
		"rock à la salle de concert, classique à l'auditorium, jazz au club")
	_check(int(spect.spec(smac).debout) > 300, "fosse debout : %d places" % int(spect.spec(smac).debout))
	_check(spect.note(tville) > 2.5, "théâtre municipal : %.1f étoiles (confort %d %%, acoustique %d %%)" % [spect.note(tville),
		roundi(float(spect.spec(tville).confort) * 100.0), roundi(float(spect.spec(tville).acoustique) * 100.0)])
	_check(spect.compatible(tville, "cyrano") == "", "Cyrano peut jouer au théâtre municipal")
	_check(spect.porte(tville).distance_to(spect.centre(tville)) > 5.0 and spect.front(tville).length() > 0.9, "porte d'entrée trouvée sur la façade")

	print("Aménagement :")
	var tid := String(keys.theatre_ville)
	var scenes := 0
	var face := 0
	var sieges := 0
	var batterie_haut := 0.0
	for k in mob.items[tid]:
		var m := String(mob.items[tid][k].m)
		if m == "spectacle/plancher_scene" or m == "spectacle/praticable":
			scenes += 1
		if m == "spectacle/fauteuils_theatre":
			sieges += 1
			# Façade sur z = 0, scène au fond (z grand) : les fauteuils regardent vers +z.
			if Meubles.back_dir(int(mob.items[tid][k].r)) == Vector2i(0, -1):
				face += 1
	_check(scenes >= 20, "théâtre : une scène de %d planchers" % scenes)
	if face != sieges:
		var rs := {}
		for k in mob.items[tid]:
			if String(mob.items[tid][k].m) == "spectacle/fauteuils_theatre":
				rs[str(k) + " r" + str(mob.items[tid][k].r)] = true
		print(rs.keys().slice(0, 12))
	_check(sieges > 60 and face == sieges, "%d rangées de fauteuils, toutes face à la scène" % sieges)
	var sid := String(keys.salle_musiques_actuelles_plan)
	for k in mob.items[sid]:
		if String(mob.items[sid][k].m) == "musee/batterie":
			var kv: Vector4i = k
			batterie_haut = mob.estrade_under(sid, kv.y, Meubles.get_entry("musee/batterie"), Vector2i(kv.x, kv.z), int(mob.items[sid][k].r))
	_check(batterie_haut > 0.5, "la batterie est montée sur la scène (%.1f m)" % batterie_haut)
	var a_ecran := false
	var a_proj := false
	for k in mob.items[String(keys.cinema_village)]:
		var m2 := String(mob.items[String(keys.cinema_village)][k].m)
		a_ecran = a_ecran or m2 == "spectacle/ecran_geant"
		a_proj = a_proj or m2 == "spectacle/projecteur_numerique"
	_check(a_ecran and a_proj, "cinéma : écran panoramique et projecteur")
	# Sans billetterie, la salle ne peut pas ouvrir.
	var jid := String(keys.club_jazz_plan)
	var guichet: Variant = null
	for k in mob.items[jid]:
		if Meubles.get_entry(String(mob.items[jid][k].m)).get("service", "") == "billetterie":
			guichet = k
	if guichet != null:
		mob.remove(jid, guichet)
	spect._plans.clear()
	_check(not (spect.spec(jazz).manques as Array).is_empty() and not spect._ouverte(jazz), "sans billetterie, le club reste fermé")
	mob.undo()
	spect._plans.clear()
	_check(spect._ouverte(jazz), "billetterie remise : le club rouvre")

	print("Une soirée dans le théâtre en murs fins :")
	spect.clock = SAMEDI - 3600.0
	spect.last_day = int(spect._now(SAMEDI).day)
	spect.habitants_force = 15000
	spect._majs_ages()
	spect._nouveau_jour_programmes()
	spect.set_auto(tville, false)
	var argent := bs.money
	var soir := spect._now(SAMEDI + 11 * 3600.0)
	var r := spect.jouer(tville, "cyrano", soir)
	_check(not bool(r.annule) and int(r.public) > 50, "Cyrano : %d spectateurs" % int(r.public))
	_check(int(r.public) <= spect.places(tville), "pas plus de spectateurs que de fauteuils")
	_check(bs.money != argent, "billets et cachet passés dans la caisse")
	var fq := spect.affiche(quartier)
	_check(not fq.is_empty(), "%d films à l'affiche du cinéma de quartier" % fq.size())
	spect._seance(quartier, spect._now(SAMEDI + 11 * 3600.0), 20)
	_check(int(spect.salles[quartier].jour.spectateurs) > 0, "séance de 20 h : %d spectateurs" % int(spect.salles[quartier].jour.spectateurs))

	print("Un film dans le studio en murs fins :")
	_check(spect.plateaux(studio) >= 2, "%d plateaux avec caméra" % spect.plateaux(studio))
	var an := spect.annexes(studio)
	_check(bool(an.vfx) and bool(an.postprod) and bool(an.atelier), "fond vert, montage et ateliers dans le bâtiment")
	var why := spect.lancer_film(studio, "comedie_film", "petit", "bernard_routine", "inconnus", "Le Rideau qui coince")
	_check(why == "", "film lancé : %s" % (why if why != "" else "oui"))
	_check(spect.films_du_studio(studio).size() == 1, "le film est dans la filmographie du studio")

	print("Public visible :")
	scene.ambiance.unix_time = SAMEDI + 10 * 3600.0 + 1800.0
	spect.programmer(tville, "cyrano", 1, spect._today())
	spect.visuels._placer()
	_check(spect.visuels.compte() > 0, "%d personnages devant les salles" % spect.visuels.compte())

	print("Sauvegarde :")
	var d := spect.to_dict()
	var back: Dictionary = JSON.parse_string(JSON.stringify(d))
	var nom := spect.nom(tville)
	spect.from_dict(back)
	spect._sync()
	_check(spect.salles.has(tville) and spect.nom(tville) == nom and spect.studios.has(studio), "salles en murs fins relues")

	print("Menu :")
	var panel: SpectaclesPanel = scene.spectacles_panel
	panel.set_open(true)
	for v in ["batir", "amenager", "salles"]:
		panel.show_view(v)
		_check(panel._body.get_child_count() > 4, "onglet %s" % v)
	panel.famille = "studio"
	panel.show_view("amenager")
	var cartes := 0
	for c in panel._body.get_children():
		if c is GridContainer:
			cartes += c.get_child_count()
	_check(cartes >= 15, "%d objets de tournage à poser" % cartes)
	panel.choisi = tville
	panel.show_view("salles")
	_check(panel._title.text == spect.nom(tville), "fiche de la salle en murs fins")
	panel.set_open(false)
	scene.queue_free()
	await process_frame
