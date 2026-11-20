extends SceneTree
## Mini-carte vue du dessus (scripts/interface/mini_carte.gd) : place en bas à
## droite, fond calculé, clic = caméra, zoom, Ctrl+M, alertes cliquables,
## couleurs de P et de N, villages, coût par image.
## Usage : godot --headless --path . --script res://tests/mini_carte_test.gd

var ok := true


func _initialize() -> void:
	_run.call_deferred()


func _check(cond: bool, what: String) -> void:
	if not cond:
		push_error("ÉCHEC : " + what)
		ok = false
	else:
		print("  ok  ", what)


func _relief(t: Vector2i) -> PackedFloat32Array:
	# Une pente douce et des bosses : le relief ombré a de quoi faire.
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	for j in 256:
		for i in 256:
			a[i + j * 256] = 300.0 + 40.0 * sin((t.x * 256 + i) * 0.05) + 30.0 * cos((t.y * 256 + j) * 0.04)
	return a


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	Creations.persist = false
	AffichagePanneaux.persist = false
	BatimentsVie.chantiers = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(MiniCarte.PREFS))
	var game: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = game.get_node("Terrain")
	root.add_child(game)
	world.tiles.offline_generator = _relief
	world.land.offline_generator = func(lat: float, _lon: float) -> int: return 10 if fmod(absf(lat) * 1000.0, 2.0) < 1.0 else 40
	world.set_origin(45.8992, 6.1294)
	await _frames(30)
	var hud: TerreHud = game.hud
	var mc: MiniCarte = game.mini_carte
	var rig: Node3D = game.rig

	print("Place :")
	_check(mc != null and mc.est_montree(), "mini-carte montrée en mode Gérer")
	await _frames(3)
	var r := mc._cadre.get_global_rect()
	var vp := root.get_visible_rect().size
	_check(r.end.x <= vp.x - 4.0 and r.end.x >= vp.x - 40.0, "collée au bord droit (%d → %d)" % [int(r.position.x), int(r.end.x)])
	_check(r.end.y <= hud._dock.get_global_rect().position.y, "au-dessus de la barre des catégories")
	_check(not r.intersects(hud._cell_card.get_global_rect()), "ne touche pas la carte de la case")
	hud._request_mode(true)
	await _frames(2)
	_check(not mc.is_visible_in_tree(), "mode Créer : cachée")
	hud._request_mode(false)
	await _frames(2)
	_check(mc.is_visible_in_tree(), "retour en Gérer : revenue")

	print("Fond :")
	var attente := 0
	while mc._fond_tex == null and attente < 120:
		await process_frame
		attente += 1
	_check(mc._fond_tex != null, "relief et sol calculés peu après l'arrivée (%d images de plus)" % attente)
	# Coût : on refait le fond d'un coup, image par image, en chronométrant.
	mc._commencer_fond(mc.centre, mc.etendue() * MiniCarte.FOND_MARGE)
	var n := 0
	var pire := 0
	var total := 0
	while not mc._calcul.is_empty() and n < 100:
		var a := Time.get_ticks_usec()
		mc._avancer_fond()
		var d := Time.get_ticks_usec() - a
		pire = maxi(pire, d)
		total += d
		n += 1
	_check(n == ceili(float(MiniCarte.FOND_PX) / MiniCarte.LIGNES_PAR_IMAGE), "fond refait en %d images" % n)
	_check(pire < 8000, "image la plus lente : %.1f ms (total %.1f ms)" % [pire / 1000.0, total / 1000.0])
	_check(mc._fond_rect.has_point(mc.centre), "le fond couvre la caméra")
	var img := mc._fond_tex.get_image()
	var c := img.get_pixel(64, 64)
	_check(c.a > 0.99 and c != MiniCarte.COULEUR_INCONNU, "pixel du milieu coloré (%s)" % c.to_html(false))
	var t1 := Time.get_ticks_usec()
	for i in 10:
		mc._process(0.016)
	_check(mc._calcul.is_empty(), "rien à recalculer quand la caméra ne bouge pas")
	print("     (%.2f ms par image une fois prête)" % ((Time.get_ticks_usec() - t1) / 10000.0))

	print("Caméra :")
	rig.position = Vector3(0, rig.position.y, 0)
	await _frames(1)
	var e := mc.etendue()
	mc.cliquer(Vector2(MiniCarte.TAILLE * 0.75, MiniCarte.TAILLE * 0.5))
	_check(absf(rig.position.x - e * 0.25) < 1.0 and absf(rig.position.z) < 1.0, "clic à droite du centre : la caméra va %d m à l'est" % int(rig.position.x))
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = true
	mb.position = Vector2(MiniCarte.TAILLE * 0.5, MiniCarte.TAILLE * 0.25)
	await _frames(1)
	mc._vue._gui_input(mb)
	_check(rig.position.z < -e * 0.2, "clic en haut (nord) : la caméra monte vers le nord (z = %d)" % int(rig.position.z))
	mb.pressed = false
	mc._vue._gui_input(mb)
	_check(not mc._glisse, "bouton relâché : on ne glisse plus")
	rig.position = Vector3(0, rig.position.y, 0)
	var z0 := mc.zoom
	var w := InputEventMouseButton.new()
	w.button_index = MOUSE_BUTTON_WHEEL_DOWN
	w.pressed = true
	mc._vue._gui_input(w)
	_check(mc.zoom == z0 + 1 and mc._titre.text.contains("8 km"), "molette : plus large (%s)" % mc._titre.text)
	w.button_index = MOUSE_BUTTON_WHEEL_UP
	mc._vue._gui_input(w)
	mc._vue._gui_input(w)
	_check(mc.zoom == z0 - 1, "molette : plus près (%s)" % mc._titre.text)
	mc.set_zoom(z0)
	var cf := ConfigFile.new()
	_check(cf.load(MiniCarte.PREFS) == OK and int(cf.get_value("carte", "zoom", -1)) == z0, "zoom gardé pour la prochaine partie")
	var poly := mc.champ_camera(rig.get_node("Camera3D"))
	_check(poly.size() == 4, "champ de la caméra : 4 coins au sol")

	print("Ctrl+M :")
	var k := InputEventKey.new()
	k.keycode = KEY_M
	k.physical_keycode = KEY_M
	k.ctrl_pressed = true
	k.pressed = true
	root.push_input(k)
	await _frames(2)
	_check(not mc.est_montree() and game.affichage.est_masque("mini_carte"), "Ctrl+M : masquée (menu Affichage, œil)")
	_check(not game.mairie_panel.visible or not game.mairie_panel.is_open(), "Ctrl+M n'ouvre pas la Mairie")
	root.push_input(k)
	await _frames(2)
	_check(mc.est_montree() and not game.affichage.est_masque("mini_carte"), "Ctrl+M : réaffichée")
	game.affichage.masquer("mini_carte", true)
	await _frames(2)
	_check(not mc.est_montree(), "croix / menu Affichage : masquée")
	game.affichage.masquer("mini_carte", false)
	await _frames(2)
	_check(mc.est_montree(), "menu Affichage : réaffichée")

	print("Alertes :")
	var ev := Evenements.instance
	var iid := ev.declarer({"type": "incendie", "position": Vector3(600, 0, -300), "gravite": 2, "besoin": ["pompiers"]})
	mc._t_alertes = 0.0
	await _frames(2)
	var trouvee := {}
	for a in mc.alertes:
		if a.genre == "incident":
			trouvee = a
	_check(not trouvee.is_empty(), "incendie déclaré : point rouge sur la carte")
	var p := mc.vers_carte(Vector2(600, -300))
	var pres := mc.alerte_sous(p + Vector2(3, 2))
	_check(not pres.is_empty() and pres.genre == "incident", "le point se trouve sous la souris")
	_check(mc.infobulle(p).contains("Clic : y aller"), "infobulle : %s" % mc.infobulle(p).replace("\n", " · "))
	mc.cliquer(p + Vector2(3, 2))
	_check(absf(rig.position.x - 600.0) < 1.0 and absf(rig.position.z + 300.0) < 1.0, "clic sur l'alerte : la caméra va pile dessus")
	ev.resoudre(iid)
	mc._t_alertes = 0.0
	await _frames(2)
	var reste := false
	for a in mc.alertes:
		reste = reste or a.genre == "incident"
	_check(not reste, "incendie éteint : le point disparaît")
	game.buildings.require_access = false
	var bid: int = game.buildings.place("maison", Vector2i(120, 40), 0)
	if bid < 0:
		print("  --  maison non posée : test « non raccordé » sauté")
	if bid >= 0:
		# Le calcul des réseaux est testé ailleurs : ici, la maison est déclarée sans électricité.
		game.reseaux.raccordements.manques[bid] = [["elec", Raccordements.NON_RACCORDE]]
		mc._t_alertes = 0.0
		await _frames(2)
		var nr := false
		for a in mc.alertes:
			nr = nr or (a.genre == "non_raccorde" and int(a.bid) == bid)
		_check(nr, "maison isolée : point « non raccordé »")

	print("Couleurs de P et N :")
	game.resource_overlay.show_resource("bois")
	mc._process(0.016)
	_check(mc._donnees_cle == "res:bois" and mc._legende.visible and mc._legende.text.contains("Forêt"), "P → bois : %s" % mc._legende.text)
	_check(mc._donnees_tex != null, "carte du bois calculée")
	game.resource_overlay.show_resource("")
	mc._process(0.016)
	_check(not mc._legende.visible, "P éteint : plus de légende")
	var id_couleur := ""
	for cq in Calques.liste():
		if String(cq.id).begins_with("nuisances_") or String(cq.id) == "immobilier_valeur":
			id_couleur = String(cq.id)
			break
	_check(id_couleur != "", "un calque en couleur existe (%s)" % id_couleur)
	Calques.afficher(id_couleur, true)
	await _frames(1)
	mc._process(0.016)
	_check(mc._donnees_cle == "calque:" + id_couleur and mc._legende.text.contains(mc.calque_nom) and mc.calque_nom != "", "N → %s repris sur la mini-carte" % mc.calque_nom)
	Calques.eteindre()
	await _frames(1)
	mc._process(0.016)
	_check(mc._donnees_cle == "", "N éteint : couleurs retirées")

	print("Villages :")
	rig.position = Vector3(0, rig.position.y, 0)
	var vid: int = game.communes.fonder_au_point("Bourg-Test", Vector2(0, 0))
	var yr := world.cell_height(Vector2i(0, 0))
	var route: Dictionary = game.transport.build_segment("route", Vector3(-80, yr, 30), Vector3(80, yr, 30))
	_check(bool(route.get("ok", false)), "une route posée (%s)" % route.get("reason", "ok"))
	mc._t_statique = 0.0
	await _frames(3)
	var milieu := Vector2(MiniCarte.TAILLE, MiniCarte.TAILLE) * 0.5
	_check(mc.infobulle(milieu + Vector2(-6, 6)).begins_with("Bourg-Test"), "survol du territoire : nom du village")
	_check(mc.nom_village(vid) == "Bourg-Test", "en solo : pas de mention « voisine »")
	_check(not mc._statique_sale, "frontières dessinées")

	print("Vue au sol :")
	var vue: Node = game.get_node_or_null("VueSol")
	if vue != null and vue.has_method("vue_suivante"):
		vue.vue_suivante()
		await _frames(3)
		_check(not mc.est_montree(), "vue au sol : mini-carte cachée")
		while int(vue.vue) != 0:
			vue.vue_suivante()
			await _frames(2)
		await _frames(2)
		_check(mc.est_montree(), "retour en vue de dessus : revenue")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(MiniCarte.PREFS))
	print("MINI-CARTE TEST OK" if ok else "MINI-CARTE TEST ÉCHEC")
	quit(0 if ok else 1)
