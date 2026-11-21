extends SceneTree
## Test du sélecteur de villes : boutons ◀ drapeau ▶ dans la barre du haut dès la
## 2e ville, ville suivante / précédente (boutons et Ctrl+Tab / Ctrl+Maj+Tab) qui
## font sauter la caméra sur la mairie et changent la ville gérée (caisse), bande
## des villes en vignettes (une carte par ville, clic = y aller), blocage en vue
## au sol, nouvelle partie.
## Usage : godot --headless --path . --script res://tests/selecteur_villes_test.gd

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


func _ctrl_tab(sel: SelecteurVilles, maj := false) -> void:
	var e := InputEventKey.new()
	e.keycode = KEY_TAB
	e.ctrl_pressed = true
	e.shift_pressed = maj
	e.pressed = true
	sel._input(e)


func _run() -> void:
	Creations.persist = false
	BatimentsVie.chantiers = false
	GameStart.chosen = true
	GameStart.place_name = "Valfleuri, Savoie"
	ReglagesPartie.prochaine = ReglagesPartie.preset("normal")
	ReglagesPartie.prochaine.deblocage = "tout"
	ReglagesPartie.prochaine.fondateurs = 0
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
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
	var rig: Node3D = scene.rig
	var sel: SelecteurVilles = scene.selecteur_villes
	_check(sel != null and SelecteurVilles.instance == sel, "sélecteur branché")
	_check(sel.barre.get_parent() != null and sel.barre.get_parent().get_node_or_null("Chercher") != null,
		"boutons dans la barre du haut, à côté de Chercher")
	_check(sel.barre.get_index() == sel.barre.get_parent().get_node("Chercher").get_index() + 1, "juste après Chercher")

	print("Une seule ville :")
	var v1 := cm.fonder_au_point("Valfleuri", Vector2(-1000, 0))
	for i in 3:
		await process_frame
	sel._sale = true
	await process_frame
	_check(not sel.disponible() and not sel.barre.visible, "pas de sélecteur avec une seule ville")
	_check(sel.passer(1) == -1, "rien à faire avec une seule ville")

	print("Trois villes :")
	var v2 := cm.fonder_au_point("Montbrison", Vector2(3000, 0))
	var v3 := cm.fonder_au_point("Lac-Bleu", Vector2(-1000, 6000))
	rig.position = Vector3(-1000, rig.position.y, 0)
	p.choisir(v1)
	for i in 3:
		await process_frame
	sel._sale = true
	await process_frame
	_check(sel.disponible() and sel.barre.visible, "sélecteur visible dès la 2e ville")
	_check(sel.villes() == [v1, v2, v3], "villes dans l'ordre de fondation")
	_check(sel.actuelle() == v1, "ville actuelle : Valfleuri")
	_check(sel._suiv.tooltip_text.contains("Montbrison") and sel._prec.tooltip_text.contains("Lac-Bleu"),
		"bulles : suivante Montbrison, précédente Lac-Bleu")

	print("Ville suivante (bouton) :")
	p.solde(v2)
	sel._suiv.pressed.emit()
	for i in 40:
		await process_frame
	_check(p.selection == v2 and p.actif == v2, "Montbrison gérée (caisse active)")
	_check(Vector2(rig.position.x, rig.position.z).distance_to(Vector2(3000, 0)) < 1.0, "caméra sur la mairie de Montbrison")
	await create_timer(0.6).timeout
	_check(p.selection == v2, "la ville gérée reste Montbrison (la caméra y est)")

	print("Ctrl+Tab / Ctrl+Maj+Tab :")
	_ctrl_tab(sel)
	for i in 3:
		await process_frame
	_check(p.selection == v3, "Ctrl+Tab : Lac-Bleu")
	_check(rig.position.distance_to(Vector3(-1000, rig.position.y, 6000)) < 1.0, "saut direct au-delà de 2,5 km")
	_check(sel.is_open(), "la bande des villes s'affiche un instant")
	_ctrl_tab(sel)
	await process_frame
	_check(p.selection == v1, "Ctrl+Tab : on revient à la première")
	_ctrl_tab(sel, true)
	await process_frame
	_check(p.selection == v3, "Ctrl+Maj+Tab : précédente (Lac-Bleu)")
	await create_timer(SelecteurVilles.BANDE_FLASH + 0.3).timeout
	_check(not sel.is_open(), "la bande se referme seule")

	print("Bande des villes en vignettes :")
	sel._ici.button_pressed = true
	await process_frame
	_check(sel.is_open(), "clic sur le drapeau : bande ouverte")
	_check(sel._cartes.get_child_count() == 3, "une carte par ville")
	var carte := sel._cartes.get_node_or_null("Ville%d" % v2) as Button
	_check(carte != null and carte.find_child("Photo", true, false) != null, "carte de Montbrison avec photo")
	var ch := sel.chiffres(v2)
	_check(ch.has("hab") and String(ch.caisse) != "" and String(ch.palier) != "" and String(ch.etat).contains("maire"),
		"chiffres : %s hab., %s, %s, %s" % [ch.hab, ch.palier, ch.caisse, ch.etat])
	await create_timer(SelecteurVilles.BANDE_FLASH + 0.3).timeout
	_check(sel.is_open(), "ouverte au clic, elle reste ouverte")
	_check(is_instance_valid(carte), "les cartes ne sont pas refaites sous la souris sans raison")
	carte = sel._cartes.get_node("Ville%d" % v2) as Button
	carte.pressed.emit()
	for i in 40:
		await process_frame
	_check(p.selection == v2 and not sel.is_open(), "clic sur une carte : on y va, la bande se ferme")
	sel.ouvrir()
	var e := InputEventKey.new()
	e.keycode = KEY_ESCAPE
	e.pressed = true
	sel._input(e)
	_check(not sel.is_open(), "Échap ferme la bande")

	print("Bloqué en vue au sol :")
	var vs := scene.get_node("VueSol") as VueSol
	vs.vue = VueSol.Vue.TROISIEME
	_check(not sel.aller(v1) and p.selection == v2, "pas de saut en vue au sol")
	vs.vue = VueSol.Vue.DESSUS
	_check(sel.aller(v1) and p.selection == v1, "de retour en vue de dessus : on saute")

	print("Nouvelle partie :")
	sel.photos[v1] = ImageTexture.new()
	sel.clear()
	_check(sel.photos.is_empty() and not sel.is_open(), "photos oubliées")

	print("RÉSULTAT : ", "OK" if ok else "ÉCHEC")
	quit(0 if ok else 1)
