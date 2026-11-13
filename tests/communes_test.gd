extends SceneTree
## Test des villages et de leur territoire : fondation obligatoire (rien avant la
## Maison de commune), territoire de départ, construction et zonage limités au
## territoire, voies permises partout, agrandir et céder un carré, second village
## (distance minimale), croissance avec la population, fusion, renommage,
## sauvegarde, ancienne partie, calque, panneau Maj+M, réglages Admin.
## Usage : godot --headless --path . --script res://tests/communes_test.gd

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
	# Partie lancée depuis le globe : la fondation est exigée.
	GameStart.chosen = true
	GameStart.place_name = "Valfleuri, Savoie"
	ReglagesPartie.prochaine = ReglagesPartie.preset("normal")
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
	var y := world.cell_height(Vector2i(0, 0))
	_check(cm != null and Communes.instance == cm and scene.villages_panel != null, "villages et panneau branchés")

	print("Avant la fondation :")
	_check(cm.actif and cm.fondation_requise(), "partie du globe : il faut fonder un village")
	_check(cm.raison_voie() != "", "pas de voie avant la fondation")
	_check(bs.place("maison", Vector2i(-970, 30), 0) < 0, "pas de maison avant la fondation")
	_check(bs.check_place("maison", Vector2i(-970, 30), 0).reason == Communes.MSG_FONDER, "raison : « %s »" % Communes.MSG_FONDER)
	_check(zones.add_zone("R", Rect2i(-980, 20, 30, 30)) < 0, "pas de zonage avant la fondation")
	var m0 := bs.money
	cm.nom_en_attente = "Valfleuri"
	cm.drapeau_en_attente = "ch"
	var mc := bs.place("maison_commune", Vector2i(-1000, 0), 0)
	_check(mc > 0, "Maison de commune posée sans route")
	_check(cm.villages.size() == 1, "un village fondé")
	var v1 := cm.principal()
	var vill: Dictionary = cm.villages[v1]
	_check(String(vill.nom) == "Valfleuri" and int(vill.bid) == mc, "nom « Valfleuri », siège = la Maison de commune")
	var ha := (vill.cases as Dictionary).size()
	_check(ha >= 70 and ha <= 90, "territoire de départ : %d ha (500 m de rayon)" % ha)
	_check(m0 - bs.money >= ReglagesPartie.prix(300_000), "la Maison de commune a coûté %s" % BuildingSystem.format_money(m0 - bs.money))
	_check(not cm.fondation_requise() and cm.raison_voie() == "", "voies débloquées")
	_check(Avis.ville() == "Valfleuri", "la commune s'appelle Valfleuri (avis, élections)")
	_check(scene.avis.mairie() == mc, "la mairie des manifestations est la Maison de commune")
	_check(String(vill.drapeau) == "ch", "drapeau choisi : Suisse")
	cm._maj_drapeaux(true)
	var mat_node := bs.node_of(mc)
	var fl: MeshInstance3D = mat_node.get_node_or_null("Drapeau") if mat_node else null
	_check(fl != null and String(fl.get_meta("code", "")) == "ch", "le drapeau suisse flotte sur le mât")
	_check(Drapeaux.existe("ch") and Drapeaux.existe("jp") and Drapeaux.existe("br") and Drapeaux.liste().size() > 240, "%d drapeaux disponibles" % Drapeaux.liste().size())
	_check(Drapeaux.icone("fr") != null and Drapeaux.materiau("fr") != null, "icône et tissu du drapeau français")
	var vp: VillagesPanel = scene.villages_panel
	vp.demander_nom()
	VillagesPanel.choisir_code(vp._dialog_drapeau, "jp")
	vp._dialog.hide()
	vp._valider_nom()
	_check(cm.drapeau_en_attente == "jp", "fenêtre de fondation : drapeau japonais choisi")
	VillagesPanel.choisir_code(vp._dialog_drapeau, "")
	vp._valider_nom()
	_check(cm.drapeau_en_attente == "-", "fenêtre de fondation : aucun drapeau")

	print("Construire dans le territoire :")
	bs.unlimited_money = true
	_check(transport.build_segment("route", Vector3(-1300, y, 40), Vector3(-200, y, 40)).ok, "route qui sort du territoire (%s)" % transport.build_segment("route", Vector3(-1300, y, 40), Vector3(-200, y, 40)).get("reason", ""))
	var dedans := bs.place("maison", Vector2i(-900, 56), bs.best_rotation("maison", Vector2i(-900, 56)))
	if dedans < 0:
		dedans = bs.place("maison", Vector2i(-900, 24), bs.best_rotation("maison", Vector2i(-900, 24)))
	_check(dedans > 0, "maison dans le territoire (%s)" % bs.check_place("maison", Vector2i(-900, 56), bs.best_rotation("maison", Vector2i(-900, 56))).reason)
	var dehors := bs.check_place("maison", Vector2i(-300, 56), bs.best_rotation("maison", Vector2i(-300, 56)))
	_check(not dehors.ok and String(dehors.reason).begins_with("Hors du territoire"), "maison à 900 m refusée : %s" % dehors.reason)
	_check(zones.add_zone("R", Rect2i(-1200, 60, 100, 60)) > 0, "zonage dans le territoire")
	_check(zones.add_zone("R", Rect2i(-300, 60, 100, 60)) < 0, "zonage hors du territoire refusé")
	_check(cm.village_du_batiment(dedans) == v1, "la maison est à Valfleuri")

	print("Agrandir et céder :")
	bs.unlimited_money = false
	var k_out := Communes.case_de(-1000, 0) + Vector2i(4, 0)
	while cm.proprio.has(k_out):
		k_out.x += 1
	_check(cm.raison_annexer(v1, k_out + Vector2i(2, 0)) != "", "un carré qui ne touche pas est refusé")
	var m1 := bs.money
	_check(cm.annexer(v1, k_out) == "", "carré %s annexé" % k_out)
	_check(m1 - bs.money == cm.prix_case(), "payé %s" % BuildingSystem.format_money(cm.prix_case()))
	_check(int(cm.proprio.get(k_out, -1)) == v1, "le carré est à Valfleuri")
	_check(cm.raison_ceder(v1, Communes.case_de(-1000, 0)) != "", "on ne cède pas le carré de la mairie")
	var k_bat := Communes.case_de(cm._centre_bat(dedans).x, cm._centre_bat(dedans).y)
	_check(cm.raison_ceder(v1, k_bat).contains("bâtiments"), "on ne cède pas un carré bâti")
	_check(cm.ceder(v1, k_out) == "" and not cm.proprio.has(k_out), "carré cédé")
	bs.unlimited_money = true

	print("Un deuxième village :")
	var trop_pres := bs.check_place("maison_commune", Vector2i(200, 0), 0)
	_check(not trop_pres.ok and String(trop_pres.reason).begins_with("Trop près"), "à 1,2 km : %s" % trop_pres.reason)
	cm.nom_en_attente = "Les Granges"
	var mc2 := bs.place("maison_commune", Vector2i(1100, 0), 0)
	_check(mc2 > 0 and cm.villages.size() == 2, "Les Granges fondé à 2,1 km (%s)" % bs.check_place("maison_commune", Vector2i(1100, 0), 0).reason)
	var v2 := cm.village_du_batiment(mc2)
	_check(v2 >= 0 and v2 != v1 and String(cm.villages[v2].nom) == "Les Granges", "deuxième village distinct")
	_check(bs.check_place("maison", Vector2i(1100, 120), 0).reason != Communes.MSG_FONDER, "on construit aussi aux Granges")
	_check(not cm.voisins(v1, v2), "les deux villages ne se touchent pas encore")
	_check(Avis.ville() == "Valfleuri", "le chef-lieu reste Valfleuri")
	_check(String(cm.villages[v2].drapeau) == "", "Les Granges : sans drapeau, comme choisi")
	cm.set_drapeau(v2, "IT")
	_check(String(cm.villages[v2].drapeau) == "it", "Les Granges hisse le drapeau italien")

	print("Croissance avec la population :")
	cm.calculer_stats()
	cm.stats[v1].palier = 3
	cm.croissance()
	_check(float(cm.villages[v1].rayon) >= 2000.0, "Ville : rayon 2 km")
	var ha2 := (cm.villages[v1].cases as Dictionary).size()
	_check(ha2 > ha * 3, "territoire agrandi : %d ha" % ha2)
	_check(cm.voisins(v1, v2), "les deux territoires se touchent maintenant")

	print("Panneau, calque et frontières :")
	var panel: VillagesPanel = scene.villages_panel
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.physical_keycode = KEY_M
	ev.shift_pressed = true
	panel._unhandled_key_input(ev)
	_check(panel.is_open() and cm.montre, "Maj+M ouvre le panneau")
	_check(panel._body.get_child_count() > 10, "panneau rempli (%d lignes)" % panel._body.get_child_count())
	var fus := false
	for c in panel._body.get_children():
		if c is Button and (c as Button).text.begins_with("Fusionner"):
			fus = true
	_check(fus, "bouton « Fusionner » proposé")
	await process_frame
	await process_frame
	_check(cm._bordure.visible and cm._bordure.mesh != null, "frontières dessinées")
	var ids := []
	for c in Calques.liste():
		ids.append(String(c.id))
	_check(ids.has("territoires"), "calque « Territoires » dans les cartes (N)")
	Calques.afficher("territoires")
	_check(cm.calque, "calque affiché")
	Calques.eteindre()
	var cat_ok := false
	for c in TerreHud.CATEGORIES:
		if String(c.id) == "villages" and String(c.get("group", "")) == "ville":
			cat_ok = true
	_check(cat_ok, "bouton Villages dans le menu Ville de la barre du bas")
	cm.set_outil("annexer", v1)
	await process_frame
	_check(cm._remplissage.visible and cm._survol.visible, "outil Agrandir : carrés et survol visibles")
	cm.set_outil("")
	panel.set_open(false)

	print("Fusion et renommage :")
	cm.calculer_stats()
	var keep := cm.fusionner(v1, v2)
	_check(keep >= 0 and cm.villages.size() == 1, "une seule commune après la fusion")
	_check((cm.villages[keep].annexes as Array).has(mc2) or (cm.villages[keep].annexes as Array).has(mc), "l'autre mairie devient une mairie annexe")
	cm.renommer(keep, "Valfleuri-les-Granges")
	cm.set_drapeau(keep, "br")
	_check(Avis.ville() == "Valfleuri-les-Granges", "renommée")

	print("Siège démoli et reconstruit :")
	var siege := int(cm.villages[keep].bid)
	bs.demolish(siege)
	_check(int(cm.villages[keep].bid) >= 0 and int(cm.villages[keep].bid) != siege, "la mairie annexe devient le siège")

	print("Sauvegarde :")
	var sec: Dictionary = scene.save_sections()
	_check(sec.has("communes") and (sec.communes.villages as Array).size() == 1, "section « communes »")
	var n_cases := cm.proprio.size()
	cm.clear()
	_check(cm.villages.is_empty() and cm.proprio.is_empty(), "vidé")
	cm.from_dict(JSON.parse_string(JSON.stringify(sec.communes)))
	_check(cm.villages.size() == 1 and cm.proprio.size() == n_cases, "rechargé : 1 village, %d ha" % cm.proprio.size())
	_check(String(cm.villages[keep].nom) == "Valfleuri-les-Granges", "nom rechargé")
	_check(String(cm.villages[keep].drapeau) == "br", "drapeau rechargé")

	print("Ancienne partie sans villages :")
	cm.clear()
	var vid := cm.adopter_ancienne_partie()
	_check(vid >= 0, "village créé automatiquement")
	var tous := true
	for bid in bs.buildings:
		var r := bs._rect_of(bs.buildings[bid])
		if not cm.rect_dans_territoire(r):
			tous = false
	_check(tous, "tous les bâtiments existants sont dans le territoire")

	print("Réglages Admin :")
	ReglagesPartie.actuel.territoire = false
	_check(cm.raison_batiment("maison", Rect2i(9000, 0, 10, 12)) == "", "territoire coupé : construction partout")
	ReglagesPartie.actuel.territoire = true
	cm.clear()
	ReglagesPartie.actuel.fondation = false
	_check(not cm.fondation_requise() and cm.raison_batiment("maison", Rect2i(30, 30, 10, 12)) == "", "fondation coupée : on construit tout de suite")
	_check(not ReglagesPartie.preset("libre").fondation and ReglagesPartie.preset("normal").fondation, "bac à sable libre : sans fondation")
	var d := ReglagesPartie.actuel.to_dict()
	var r2 := ReglagesPartie.new()
	r2.from_dict(d)
	_check(r2.fondation == false and r2.territoire == true, "réglages sauvegardés")
	ReglagesPartie.actuel.fondation = true
	GameStart.chosen = false

	print("TEST OK" if ok else "TEST ÉCHEC")
	quit(0 if ok else 1)
