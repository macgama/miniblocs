extends SceneTree
## Menu principal, options, emplacements de sauvegarde avec aperçu, menu pause
## (Échap) et écran de chargement.
## Usage : godot --headless --path . --script res://tests/menu_test.gd

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
	print("Options :")
	var keep_opts := FileAccess.get_file_as_string(OptionsJeu.FICHIER) if FileAccess.file_exists(OptionsJeu.FICHIER) else ""
	var keep_son := FileAccess.get_file_as_string(OptionsJeu.FICHIER_SON) if FileAccess.file_exists(OptionsJeu.FICHIER_SON) else ""
	OptionsJeu.autosave_min = 10
	OptionsJeu.ombres = 2
	OptionsJeu.echelle_3d = 0.75
	OptionsJeu.sauver()
	OptionsJeu.autosave_min = 5
	OptionsJeu.ombres = 1
	OptionsJeu.charger()
	_check(OptionsJeu.autosave_min == 10 and OptionsJeu.ombres == 2 and is_equal_approx(OptionsJeu.echelle_3d, 0.75), "options gardées dans options.cfg")
	OptionsJeu.set_volume("musique", 0.3)
	_check(is_equal_approx(OptionsJeu.volume("musique"), 0.3), "volume Musique gardé dans son.cfg (le fichier du panneau F2)")
	var cf := ConfigFile.new()
	cf.load(OptionsJeu.FICHIER_SON)
	_check(is_equal_approx(float(cf.get_value("volumes", "musique", 0.0)), 0.3), "son.cfg : section volumes, clé musique")
	var op := OptionsPanel.new()
	root.add_child(op)
	await _frames(2)
	_check(op._tabs.get_tab_count() == 4, "fenêtre Options : 4 onglets (Graphismes, Son, Jeu, Touches)")
	_check(op._volumes.size() == 5, "5 curseurs de volume")
	await _key(KEY_ESCAPE)
	_check(not is_instance_valid(op) or op.is_queued_for_deletion(), "Échap ferme les options")
	await _frames(1)

	print("Sauvegardes : aperçu, renommer, la plus récente :")
	var slot := SaveGame.make_slot_id("test menu")
	_check(SaveGame.write(slot, {"nom": "Test menu", "lieu": {"lat": 45.0, "lon": 6.0, "nom": "Annecy"}, "resume": {"habitants": 12}},
		{"terrain": {"version": 2, "lat": 45.0, "lon": 6.0, "modifs": {}}}) == "", "partie écrite")
	var img := Image.create(800, 600, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.2, 0.6, 0.3))
	_check(SaveGame.save_preview(slot, img), "aperçu enregistré")
	var tex := SaveGame.load_preview(slot)
	_check(tex != null and tex.get_width() == SaveGame.PREVIEW_SIZE.x and tex.get_height() == SaveGame.PREVIEW_SIZE.y, "aperçu recadré en 384 × 216")
	_check(SaveGame.rename(slot, "Ma belle ville"), "partie renommée")
	_check(String(SaveGame.read_manifest(slot).get("nom", "")) == "Ma belle ville", "nouveau nom dans la fiche")
	_check(SaveGame.read(slot).ok, "la partie renommée se lit toujours (empreintes intactes)")
	_check(String(SaveGame.latest().get("id", "")) == slot, "la plus récente : celle qu'on vient d'écrire")
	var pp := PartiesPanel.new(false)
	root.add_child(pp)
	await _frames(2)
	var idx := -1
	for i in pp._saves.size():
		if String(pp._saves[i].id) == slot:
			idx = i
	pp._list.select(idx)
	pp._on_select()
	_check(pp._preview.texture != null, "fenêtre Parties : aperçu affiché")
	_check(pp._rename_edit.text == "Ma belle ville", "fenêtre Parties : nom prêt à être modifié")
	pp.close_panel()
	await _frames(1)

	print("Menu principal :")
	var menu: MenuPrincipal = load("res://scenes/menu_principal.tscn").instantiate()
	root.add_child(menu)
	await _frames(3)
	_check(String(ProjectSettings.get_setting("application/run/main_scene")) == MenuPrincipal.SCENE, "le jeu démarre sur le menu principal")
	for id in ["continuer", "nouvelle", "charger", "atelier", "options", "credits", "quitter"]:
		_check(menu._boutons.has(id), "bouton %s" % id)
	_check(menu._carte.visible and menu._carte_img.texture != null, "carte « Dernière partie » avec son aperçu")
	_check(menu.diorama.stats.triangles > 5000, "île low-poly : %d triangles" % menu.diorama.stats.triangles)
	_check(menu.diorama.nacelles.size() == 10, "grande roue : 10 nacelles")
	var a0: float = menu.diorama.roue.rotation.z
	await _frames(5)
	_check(menu.diorama.roue.rotation.z != a0, "la grande roue tourne")
	menu.ouvrir_options()
	await _frames(1)
	_check(menu._sub is OptionsPanel, "Options depuis le menu")
	(menu._sub as OptionsPanel).close_panel()
	await _frames(1)
	menu.ouvrir_credits()
	await _frames(1)
	_check(menu._sub != null, "crédits ouverts")
	await _key(KEY_ESCAPE)
	_check(menu._sub == null, "Échap ferme les crédits")
	menu.queue_free()
	await _frames(2)

	print("Partie : menu pause (Échap) :")
	Creations.persist = false
	BatimentsVie.chantiers = false
	GameStart.load_slot = ""
	GameStart.slot_id = ""
	var game: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = game.get_node("Terrain")
	root.add_child(game)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.set_origin(45.8992, 6.1294)
	await _frames(20)
	# Ferme une éventuelle fenêtre de fondation du village.
	await _frames(1)
	var hud: TerreHud = game.hud
	await _key(KEY_5)
	_check(hud._current_tool == 4, "outil Route choisi")
	await _key(KEY_ESCAPE)
	_check(game.pause_menu == null and hud._current_tool == 0, "Échap avec un outil : retour à Observer, pas de pause")
	await _key(KEY_ESCAPE)
	_check(game.pause_menu != null and paused, "Échap sans outil : menu pause, le jeu est arrêté")
	var t0: float = game.ambiance.unix_time
	await _frames(5)
	_check(game.ambiance.unix_time == t0, "le temps de la partie ne passe plus")
	game.pause_menu.open_options()
	await _frames(1)
	_check(game.pause_menu._sub is OptionsPanel, "Options depuis la pause")
	await _key(KEY_ESCAPE)
	_check(game.pause_menu != null and game.pause_menu._sub == null, "Échap ferme d'abord les options")
	game.pause_menu.unsaved = true
	game.pause_menu._ask_quit(false)
	_check(game.pause_menu._confirm.visible, "quitter avec des changements : on demande s'il faut sauvegarder")
	await _key(KEY_ESCAPE)
	_check(not game.pause_menu._confirm.visible, "Échap annule la question")
	await _key(KEY_ESCAPE)
	_check(game.pause_menu == null and not paused, "Échap reprend la partie")
	OptionsJeu.autosave_min = 0
	game._unsaved = true
	game._autosave(10000.0)
	_check(game._unsaved, "sauvegarde automatique coupée (Jamais) : rien n'est écrit")
	game.queue_free()
	await _frames(3)

	print("Écran de chargement :")
	EcranChargement.aller(MenuPrincipal.SCENE, "Test")
	await _frames(2)
	_check(EcranChargement.actif != null, "écran de chargement affiché")
	var t := Time.get_ticks_msec()
	while EcranChargement.actif != null and Time.get_ticks_msec() - t < 15000:
		await process_frame
	_check(EcranChargement.actif == null, "écran de chargement effacé une fois la scène prête")
	_check(current_scene is MenuPrincipal, "scène ouverte derrière l'écran : menu principal")

	SaveGame.delete(slot)
	_restore(OptionsJeu.FICHIER, keep_opts)
	_restore(OptionsJeu.FICHIER_SON, keep_son)
	if current_scene:
		current_scene.queue_free()
	await _frames(2)
	print("MENU TEST OK" if ok else "MENU TEST ÉCHEC")
	quit(0 if ok else 1)


func _restore(path: String, text: String) -> void:
	if text == "":
		DirAccess.remove_absolute(path)
	else:
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(text)
		f.close()
