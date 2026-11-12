extends SceneTree
## Parcours complet comme un joueur, avec de vraies touches (sans réseau) :
## globe -> partie -> outils 0-9, J -> B, L, T, V, F1 -> voie, bâtiment -> F5 -> globe
## -> Continuer -> la partie revient. Vérifie aussi qu'aucune touche n'en déclenche deux.
## Usage : godot --headless --path . --script res://tests/parcours_test.gd

var ok := true


func _initialize() -> void:
	_run.call_deferred()


func _check(cond: bool, what: String) -> void:
	if not cond:
		push_error("ÉCHEC : " + what)
		ok = false
	else:
		print("  ok  ", what)


func _flat_tile(t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(35.0)
	return a


## Appuie sur une touche (physique = position QWERTY, comme le jeu la lit), puis la relâche.
func _key(k: Key, shift := false) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = k
		e.physical_keycode = k
		e.pressed = pressed
		e.shift_pressed = shift
		root.push_input(e)
		await process_frame


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _offline(scene: Node) -> void:
	var world: TerrainWorld = scene.get_node("Terrain")
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30


func _run() -> void:
	print("Globe :")
	change_scene_to_file("res://scenes/globe.tscn")
	await _frames(5)
	var globe: Node = current_scene
	_check(globe != null and globe.has_method("start_game"), "le globe s'ouvre")
	globe.select_place(45.8992, 6.1294, "Annecy (test)", true)
	globe.start_game()
	await _frames(3)
	var game: Node = current_scene
	_check(game != null and game.name == "Terre", "Commencer la partie ouvre la scène Terre")
	_offline(game)
	game.get_node("Terrain").set_origin(45.8992, 6.1294)
	GameStart.place_name = "Annecy (test)"
	await _frames(40)

	var hud = game.hud
	var world: TerrainWorld = game.world
	print("Touches :")
	for i in TerreHud.TOOLS.size():
		var k: Key = TerreHud.TOOLS[i].key
		await _key(k)
		_check(hud._buttons[i].button_pressed, "touche %s : outil « %s »" % [OS.get_keycode_string(k), TerreHud.TOOLS[i].name])
	await _key(KEY_1)

	var panel_vis: bool = game.build_panel._panel.visible
	await _key(KEY_B)
	_check(game.build_panel._panel.visible != panel_vis, "B : panneau Construire")
	await _key(KEY_B)

	var speed: int = game.ambiance.speed_index
	var lines_open: bool = game.transit_panel.is_open()
	await _key(KEY_T)
	_check(game.ambiance.speed_index != speed, "T : pause du temps")
	_check(game.transit_panel.is_open() == lines_open, "T n'ouvre plus le panneau des lignes")
	await _key(KEY_T)
	_check(game.ambiance.speed_index == speed, "T : le temps repart")
	await _key(KEY_L)
	_check(game.transit_panel.is_open() != lines_open, "L : panneau des lignes")
	_check(game.ambiance.speed_index == speed, "L ne touche pas au temps")
	await _key(KEY_L)

	await _key(KEY_F1)
	_check(game._help != null, "F1 : aide ouverte")
	await _key(KEY_F1)
	await _frames(1)
	_check(game._help == null, "F1 : aide refermée")

	var vue: Node = game.get_node("VueSol")
	await _key(KEY_V)
	_check(int(vue.vue) != 0, "V : vue au sol")
	await _key(KEY_V)
	await _key(KEY_V)
	_check(int(vue.vue) == 0, "V, V : retour à la vue de dessus")

	print("Construire et sauvegarder :")
	var y := world.cell_height(Vector2i(0, 0))
	_check(game.transport.build_segment("route", Vector3(-60, y, 0), Vector3(60, y, 0)).ok, "route posée")
	game.buildings.unlimited_money = true
	_check(game.buildings.place("maison", Vector2i(0, 14), game.buildings.best_rotation("maison", Vector2i(0, 14))) >= 0, "maison posée")
	await _key(KEY_F5)
	await _frames(2)
	var slot := GameStart.slot_id
	_check(slot != "" and SaveGame.exists(slot), "F5 : partie sauvegardée (%s)" % slot)
	_check(String(SaveGame.read_manifest(slot).get("nom", "")) == "Annecy (test)", "la partie porte le nom du lieu")

	print("Globe puis Continuer :")
	hud.globe_requested.emit()
	await _frames(3)
	globe = current_scene
	_check(globe.has_method("load_saved_game") and globe._continue_btn != null and not globe._continue_btn.disabled, "bouton Continuer actif")
	_check(globe._continue_btn.text.contains("Annecy (test)"), "Continuer propose la dernière partie (%s)" % globe._continue_btn.text)
	globe.load_saved_game(slot)
	await _frames(2)
	game = current_scene
	_offline(game)
	await _frames(10)
	_check(game.name == "Terre" and game.buildings.buildings.size() == 1 and game.transport.network.edges.size() >= 1, "la partie revient avec sa route et sa maison")
	_check(GameStart.slot_id == slot, "la partie en cours est la même")

	SaveGame.delete(slot)
	print("PARCOURS TEST OK" if ok else "PARCOURS TEST ÉCHEC")
	quit(0 if ok else 1)
