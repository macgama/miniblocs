extends SceneTree
## Fermer et réafficher les cartes d'information (AffichagePanneaux) : croix sur
## chaque carte, menu Affichage en vignettes (bouton œil de la barre du haut),
## Ctrl+H, cartes qui restent fermées même si leur code les remontre, barres du
## haut et du bas jamais touchées, colonne de gauche qui se resserre.
## Usage : godot --headless --path . --script res://tests/affichage_test.gd

var ok := true
var scene: Node
var hud: TerreHud
var aff: AffichagePanneaux


func _initialize() -> void:
	_run.call_deferred()


func _check(cond: bool, what: String) -> void:
	if not cond:
		push_error("ÉCHEC : " + what)
		ok = false
	else:
		print("  ok  ", what)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _flat_tile(_t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(40.0)
	return a


func _touche(code: Key, ctrl := false) -> void:
	var k := InputEventKey.new()
	k.keycode = code
	k.physical_keycode = code
	k.ctrl_pressed = ctrl
	k.pressed = true
	root.push_input(k)
	await process_frame
	k = k.duplicate()
	k.pressed = false
	root.push_input(k)
	await process_frame


func _run() -> void:
	print("Fermer et réafficher les cartes d'information")
	Creations.persist = false
	AffichagePanneaux.persist = false
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.content_scale_size = Vector2i(1600, 900)
	root.size = Vector2i(1600, 900)
	scene = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.set_origin(48.8584, 2.2945)
	await _frames(30)
	hud = scene.hud
	aff = scene.affichage
	_check(aff != null, "le gestionnaire d'affichage existe")
	var attendus := ["objectifs", "scenario", "habitant", "personnage", "fil_habitants", "bulles", "a_faire", "case", "jauges", "mini_carte"]
	for id in attendus:
		_check(aff.ids().has(id), "carte « %s » fermable" % id)
	_check(aff.nb_masques() == 0, "tout est visible au départ")

	# Bouton œil dans la barre du haut, à côté de l'aide.
	var barre := hud.find_child("BarreHaut", true, false) as Control
	_check(aff.bouton != null and barre.is_ancestor_of(aff.bouton), "bouton œil dans la barre du haut")

	# Croix sur la carte de la case (toujours visible en mode Gérer).
	var case_c := hud._cell_card
	await _frames(3)
	var croix: Button = aff._badges["case"]
	_check(case_c.is_visible_in_tree() and croix.visible, "croix ronde visible sur la carte de la case")
	var r := case_c.get_global_rect()
	_check(croix.get_global_rect().intersects(r.grow(2.0)), "la croix est posée sur le coin de la carte")
	croix.pressed.emit()
	await _frames(2)
	_check(not case_c.visible and aff.est_masque("case"), "clic sur la croix : carte de la case fermée")
	_check(not croix.visible, "la croix disparaît avec la carte")
	# Son code la remontre : elle reste fermée.
	case_c.visible = true
	await _frames(2)
	_check(not case_c.visible, "la carte reste fermée même si le jeu la remontre")
	_check(aff._compte.visible and aff._compte.text == "1", "pastille « 1 » sur l'œil")

	# Menu Affichage en vignettes.
	aff.bouton.button_pressed = true
	await _frames(3)
	_check(aff.menu_ouvert(), "clic sur l'œil : menu Affichage ouvert")
	_check(aff._tuiles.size() == attendus.size(), "une vignette par carte")
	for id in aff._tuiles:
		var t: Button = aff._tuiles[id]
		_check(t.icon != null and t.text != "", "vignette « %s » en image avec son nom" % id)
	_check(not (aff._tuiles["case"] as Button).button_pressed, "vignette de la case éteinte (masquée)")
	_check(aff._menu.get_global_rect().position.y >= barre.get_global_rect().end.y, "le menu s'ouvre sous la barre du haut")
	(aff._tuiles["case"] as Button).button_pressed = true
	await _frames(2)
	_check(case_c.visible and not aff.est_masque("case"), "vignette rallumée : carte de la case réaffichée")
	(aff._tuiles["jauges"] as Button).button_pressed = false
	await _frames(2)
	_check(not scene.jauges.visible, "vignette éteinte : jauges fermées")
	await _touche(KEY_ESCAPE)
	_check(not aff.menu_ouvert() and not aff.bouton.button_pressed, "Échap ferme le menu")

	# Ctrl+H : tout masquer, puis revenir comme avant (jauges toujours masquées).
	await _touche(KEY_H, true)
	await _frames(2)
	_check(aff.nb_masques() == attendus.size(), "Ctrl+H : tout masqué")
	_check(not case_c.visible and not scene.tuto_carte._col.visible, "carte de la case et objectifs cachés")
	_check(barre.is_visible_in_tree(), "la barre du haut reste")
	var dock := hud._dock
	_check(dock.is_visible_in_tree(), "la barre du bas reste")
	_check(hud.gauche_libre, "la barre du bas récupère la place de gauche")
	await _touche(KEY_H, true)
	await _frames(2)
	_check(aff.nb_masques() == 1 and aff.est_masque("jauges"), "Ctrl+H encore : retour à l'état d'avant (jauges masquées)")
	_check(case_c.visible and scene.tuto_carte._col.visible, "carte de la case et objectifs revenus")
	_check(not hud.gauche_libre, "la barre du bas laisse de nouveau la place à gauche")

	# Tout afficher.
	aff.tout_afficher()
	await _frames(2)
	_check(aff.nb_masques() == 0 and scene.jauges.visible, "« Tout afficher » : jauges revenues")
	_check(not aff._compte.visible, "plus de pastille sur l'œil")

	# Colonne de gauche : carte de la case fermée, « À faire » descend en bas de l'écran.
	scene.fil_alertes._n = 2
	scene.fil_alertes.set_shown(true)
	await _frames(3)
	var af: Control = scene.fil_alertes._panel
	if af.is_visible_in_tree():
		aff.masquer("case", true)
		await _frames(3)
		var vue := root.get_visible_rect().size.y
		_check(absf(af.get_global_rect().end.y - (vue - PileGauche.MARGE_BAS)) < 2.0,
			"carte de la case fermée : « À faire » descend en bas de l'écran")
		aff.masquer("case", false)
		await _frames(3)
		_check(af.get_global_rect().end.y <= case_c.get_global_rect().position.y + 1.0,
			"carte de la case revenue : « À faire » repasse au-dessus")
	else:
		print("  (fil « À faire » vide dans cette partie, vérification de la colonne sautée)")

	# Mode Créer puis Gérer : une carte fermée ne revient pas toute seule.
	aff.masquer("jauges", true)
	scene.set_create_mode(true)
	await _frames(3)
	scene.set_create_mode(false)
	await _frames(3)
	_check(not scene.jauges.visible, "jauges fermées : restent fermées après Créer → Gérer")
	aff.masquer("jauges", false)
	await _frames(2)
	_check(scene.jauges.visible, "jauges réaffichées en mode Gérer")

	print("RÉSULTAT : ", "OK" if ok else "ÉCHEC")
	quit(0 if ok else 1)
