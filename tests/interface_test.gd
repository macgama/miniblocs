extends SceneTree
## Menus (direction A) : icônes, barre de catégories et plateau d'outils,
## panneaux de droite un seul à la fois, chiffres de la barre du haut,
## cartes de Construire, fiche d'un bâtiment.
## Usage : godot --headless --path . --script res://tests/interface_test.gd

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
	a.fill(35.0)
	return a


func _key(k: Key) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = k
		e.physical_keycode = k
		e.pressed = pressed
		root.push_input(e)
		await process_frame


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	print("Icônes :")
	var bad := []
	for name in Icones.SVG:
		var t := Icones.get_icon(name, 32)
		var img := t.get_image()
		if img == null or img.get_width() != 32 or img.is_invisible():
			bad.append(name)
	_check(bad.is_empty(), "%d icônes rendues en 32 px%s" % [Icones.SVG.size(), "" if bad.is_empty() else " (vides : %s)" % ", ".join(bad)])
	for i in TerreHud.TOOLS.size():
		_check(Icones.has_icon(TerreHud.TOOL_ICONS[i]), "icône de l'outil %s" % TerreHud.TOOLS[i].name)
	for c in TerreHud.CATEGORIES:
		_check(Icones.has_icon(c.icon), "icône de la catégorie %s" % c.name)
	for id in BuildingPanel.CAT_ICONS:
		_check(Icones.has_icon(BuildingPanel.CAT_ICONS[id]), "icône de l'onglet %s" % id)

	Creations.persist = false
	# Bâtiments prêts tout de suite (les chantiers sont testés dans batiments_test).
	BatimentsVie.chantiers = false
	var game: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = game.get_node("Terrain")
	root.add_child(game)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.set_origin(45.8992, 6.1294)
	await _frames(30)
	var hud: TerreHud = game.hud

	print("Barre de catégories :")
	_check(not hud._tray.visible, "Observer : pas de plateau d'outils")
	await _key(KEY_6)
	_check(hud._cat_buttons.voies.button_pressed and hud._buttons[5].button_pressed, "touche 6 : Voies allumée, outil Rail")
	_check(hud._tray.visible and hud._buttons[4].visible and hud._buttons[8].visible and not hud._buttons[1].visible, "plateau : outils des voies seulement")
	_check(hud._spec_panel.visible, "réglage de la voie dans le plateau")
	hud._cat_buttons.terrain.pressed.emit()
	await _frames(1)
	_check(hud._buttons[1].button_pressed and hud._cat_buttons.terrain.button_pressed, "clic Terrain : outil Aplanir")
	hud._buttons[3].pressed.emit()
	hud._buttons[3].button_pressed = true
	await _frames(1)
	hud._cat_buttons.voies.pressed.emit()
	await _frames(1)
	_check(hud._buttons[5].button_pressed, "clic Voies : retour au dernier outil des voies (Rail)")
	hud._cat_buttons.terrain.pressed.emit()
	await _frames(1)
	_check(hud._buttons[3].button_pressed, "clic Terrain : retour au dernier outil du terrain (Creuser)")
	hud._cat_buttons.terrain.pressed.emit()
	await _frames(1)
	_check(hud._buttons[0].button_pressed and not hud._tray.visible, "second clic sur la catégorie : retour à Observer")
	await _key(KEY_0)
	_check(hud._cat_buttons.paysage.button_pressed and game.landscape.visible, "touche 0 : Paysage et ses pinceaux")
	await _key(KEY_1)

	print("Panneaux de droite :")
	_check(not game.build_panel.is_open(), "Construire fermé au départ")
	hud._cat_buttons.construire.pressed.emit()
	await _frames(2)
	_check(game.build_panel.is_open() and hud._cat_buttons.construire.button_pressed, "bouton Construire : panneau ouvert, bouton allumé")
	await _key(KEY_H)
	await _frames(2)
	_check(game.habitants_panel.is_open() and not game.build_panel.is_open(), "H : Habitants s'ouvre, Construire se ferme")
	await _key(KEY_L)
	await _frames(2)
	_check(game.transit_panel.is_open() and not game.habitants_panel.is_open(), "L : Lignes s'ouvre, Habitants se ferme")
	_check(hud._cat_buttons.lignes.button_pressed and not hud._cat_buttons.habitants.button_pressed, "seul le bouton Lignes est allumé")
	await _key(KEY_L)
	await _frames(2)

	print("Construire en cartes :")
	game.build_panel.set_open(true)
	game.build_panel.show_category("logement")
	await _frames(1)
	var cards := 0
	for c in game.build_panel._item_buttons:
		if c is GridContainer:
			cards += c.get_child_count()
	_check(cards == BuildingCatalog.ids_in("logement").size(), "une carte par logement (%d)" % cards)
	_check(game.build_panel._cat_title.text.begins_with("Logement"), "titre de la catégorie : %s" % game.build_panel._cat_title.text)

	print("Barre du haut :")
	game.buildings.unlimited_money = false
	game._refresh_stats()
	_check((hud._chips.caisse as Button).text == BuildingSystem.format_money(game.buildings.money), "caisse : %s" % hud._chips.caisse.text)
	_check((hud._chips.habitants as Button).text == "0", "habitants : 0")
	hud._chips.habitants.pressed.emit()
	await _frames(2)
	_check(game.habitants_panel.is_open(), "clic sur un chiffre : panneau Habitants")
	game.habitants_panel.set_open(false)

	print("Vue :")
	hud.view_requested.emit()
	await _frames(2)
	_check(hud._view_button.text == "3e pers.", "bouton Vue : 3e personne")
	hud.view_requested.emit()
	hud.view_requested.emit()
	await _frames(2)
	_check(hud._view_button.text == "Dessus", "retour à la vue de dessus")

	print("Fiche d'un bâtiment :")
	game.buildings.unlimited_money = true
	var y := world.cell_height(Vector2i(0, 0))
	game.transport.build_segment("route", Vector3(0, y, -60), Vector3(0, y, 60))
	var bid: int = game.buildings.place("immeuble", Vector2i(14, 0), 3)
	_check(bid >= 0, "immeuble posé")
	var pop: Population = game.population
	pop._sync_buildings()
	pop.select_building(bid)
	await _frames(2)
	_check(game.habitants_panel.is_open() and game.habitants_panel.view == "batiment", "clic sur un bâtiment : fiche ouverte")
	var bars := 0
	var stack: Array = [game.habitants_panel._body]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is ProgressBar:
			bars += 1
		stack.append_array(n.get_children())
	_check(bars >= 1, "fiche : jauge des logements")

	print("Panneaux dans l'écran :")
	var view := root.get_visible_rect()
	for id in ["construire", "lignes", "habitants", "production"]:
		var panel = {"construire": game.build_panel, "lignes": game.transit_panel, "habitants": game.habitants_panel, "production": game.production_panel}[id]
		if panel == null:
			continue
		panel.set_open(true)
		await _frames(3)
		var r: Rect2 = panel._panel.get_global_rect()
		_check(r.position.x >= 0.0 and r.end.x <= view.size.x + 0.5, "%s : dans l'écran (%d → %d sur %d px)" % [id, int(r.position.x), int(r.end.x), int(view.size.x)])
		panel.set_open(false)
		await _frames(1)

	game.queue_free()
	await _frames(2)
	print("INTERFACE TEST OK" if ok else "INTERFACE TEST ÉCHEC")
	quit(0 if ok else 1)
