extends SceneTree
## Test de la manette : curseur au stick gauche, clic avec A (et glisser), croix dans
## les menus, B = Échap, Select = Tab, caméra au stick droit, aux gâchettes et aux
## bosses, outils à la croix, vue au sol (marcher), retour à la souris.
## Usage : godot --headless --path . --script res://tests/manette_test.gd

var ok := true
var man: Manette


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


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _axe(a: JoyAxis, v: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.axis = a
	e.axis_value = v
	Input.parse_input_event(e)


func _bouton(b: JoyButton, p: bool) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = b
	e.pressed = p
	Input.parse_input_event(e)


func _appui(b: JoyButton) -> void:
	_bouton(b, true)
	await _frames(2)
	_bouton(b, false)
	await _frames(2)


## Position dans la fenêtre d'un point de l'interface.
func _fenetre(p: Vector2) -> Vector2:
	return root.get_final_transform() * p


func _run() -> void:
	Succes.persist = false
	Succes.reinitialiser()
	man = root.get_node_or_null("ManetteAuto") as Manette
	_check(man != null and Manette.instance == man, "nœud global de la manette")
	if man == null:
		quit(1)
		return

	print("Curseur et clic :")
	var ui := CanvasLayer.new()
	root.add_child(ui)
	var box := VBoxContainer.new()
	box.position = Vector2(200, 200)
	ui.add_child(box)
	var b1 := Button.new()
	b1.text = "Premier"
	b1.custom_minimum_size = Vector2(240, 50)
	box.add_child(b1)
	var b2 := Button.new()
	b2.text = "Second"
	b2.custom_minimum_size = Vector2(240, 50)
	box.add_child(b2)
	var presses := {"b1": 0, "b2": 0}
	b1.pressed.connect(func() -> void: presses.b1 += 1)
	b2.pressed.connect(func() -> void: presses.b2 += 1)
	await _frames(3)
	var p0 := man.position_curseur()
	_axe(JOY_AXIS_LEFT_X, 1.0)
	await _frames(10)
	_axe(JOY_AXIS_LEFT_X, 0.0)
	await _frames(2)
	_check(Manette.actif, "la manette prend la main au premier mouvement")
	_check(man.position_curseur().x > p0.x + 20.0, "stick gauche : le curseur avance (%.0f → %.0f px)" % [p0.x, man.position_curseur().x])
	_check(man._curseur.visible, "curseur dessiné")
	_check(man._aide_boite.visible and man._aide.text.contains("cliquer"), "aides des boutons en bas de l'écran")
	man.placer_curseur(_fenetre(b1.get_global_rect().get_center()))
	_axe(JOY_AXIS_LEFT_Y, 0.3)
	await _frames(1)
	_axe(JOY_AXIS_LEFT_Y, 0.0)
	await _frames(2)
	await _appui(JOY_BUTTON_A)
	_check(presses.b1 == 1, "A sur un bouton : il est pressé (clic de souris)")

	print("Croix dans un menu :")
	b1.grab_focus()
	await _frames(1)
	await _appui(JOY_BUTTON_DPAD_DOWN)
	_check(root.gui_get_focus_owner() == b2, "croix bas : le focus passe au bouton suivant")
	_check(not man._curseur.visible, "curseur caché pendant la navigation à la croix")
	await _appui(JOY_BUTTON_A)
	_check(presses.b2 == 1, "A valide le bouton qui a le focus")
	ui.queue_free()
	await _frames(2)
	_axe(JOY_AXIS_LEFT_X, 0.6)
	await _frames(3)
	_axe(JOY_AXIS_LEFT_X, 0.0)
	await _frames(1)
	_check(not man._focus_mode and man._curseur.visible, "stick gauche : retour au curseur")

	print("Dans une partie :")
	Creations.persist = false
	ReglagesPartie.prochaine = ReglagesPartie.preset("normal")
	GameStart.mode = GameStart.Mode.BAC_A_SABLE
	GameStart.load_slot = ""
	var scene: Node = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.set_origin(48.8584, 2.2945)
	await _frames(60)
	root.gui_release_focus()
	var rig: Node3D = scene.rig
	var pos0: Vector3 = rig.position
	_axe(JOY_AXIS_RIGHT_X, 1.0)
	await _frames(20)
	_axe(JOY_AXIS_RIGHT_X, 0.0)
	await _frames(2)
	_check(rig.position.distance_to(pos0) > 1.0 and Manette.pan == Vector2.ZERO, "stick droit : la caméra se déplace (%.1f m)" % rig.position.distance_to(pos0))
	var r0: float = rig.rotation_degrees.y
	_bouton(JOY_BUTTON_RIGHT_SHOULDER, true)
	await _frames(15)
	_bouton(JOY_BUTTON_RIGHT_SHOULDER, false)
	await _frames(2)
	_check(absf(rig.rotation_degrees.y - r0) > 2.0, "RB : la caméra tourne")
	var d0: float = rig._target_distance
	_axe(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	await _frames(15)
	_axe(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	await _frames(2)
	_check(rig._target_distance < d0 - 0.5, "RT : zoom avant (%.1f → %.1f)" % [d0, rig._target_distance])
	var pitch0: float = rig.get_target_pitch()
	_bouton(JOY_BUTTON_DPAD_UP, true)
	await _frames(10)
	_bouton(JOY_BUTTON_DPAD_UP, false)
	await _frames(2)
	_check(rig.get_target_pitch() < pitch0 - 1.0, "croix haut : la caméra s'incline")
	var outil0: int = scene.hud._current_tool
	await _appui(JOY_BUTTON_DPAD_RIGHT)
	_check(scene.hud._current_tool != outil0, "croix droite : outil suivant (%d → %d)" % [outil0, scene.hud._current_tool])
	await _appui(JOY_BUTTON_DPAD_LEFT)
	_check(scene.hud._current_tool == outil0, "croix gauche : retour à l'outil précédent")
	await _appui(JOY_BUTTON_BACK)
	await _frames(2)
	_check(scene.hud.create_mode, "Vue (Select) : mode Créer (Tab)")
	await _appui(JOY_BUTTON_BACK)
	await _frames(2)
	_check(not scene.hud.create_mode, "Vue (Select) : retour au mode Gérer")
	await _appui(JOY_BUTTON_START)
	await _frames(3)
	_check(scene.pause_menu != null, "Menu (Start) : menu pause")
	await _appui(JOY_BUTTON_B)
	await _frames(3)
	_check(scene.pause_menu == null, "B : ferme le menu pause (Échap)")

	print("Vue au sol :")
	var vs: VueSol = scene.get_node("VueSol")
	await _appui(JOY_BUTTON_Y)
	await _frames(20)
	_check(vs.vue != VueSol.Vue.DESSUS and Manette.au_sol, "Y : vue au sol")
	var perso: Node3D = vs.personnage
	var pp: Vector3 = perso.global_position
	_axe(JOY_AXIS_LEFT_Y, -1.0)
	await _frames(40)
	_check(Manette.marche.y > 0.5, "stick gauche : marcher")
	_axe(JOY_AXIS_LEFT_Y, 0.0)
	await _frames(2)
	_check(Vector2(perso.global_position.x - pp.x, perso.global_position.z - pp.z).length() > 0.3, "le personnage a marché (%.1f m)" % Vector2(perso.global_position.x - pp.x, perso.global_position.z - pp.z).length())
	var cap0: float = vs._cap
	_axe(JOY_AXIS_RIGHT_X, 1.0)
	await _frames(10)
	_axe(JOY_AXIS_RIGHT_X, 0.0)
	await _frames(2)
	_check(absf(vs._cap - cap0) > 0.1, "stick droit : regarder autour")
	vs.set_vue(VueSol.Vue.DESSUS)
	await _frames(5)
	_check(not Manette.au_sol, "retour à la vue de dessus")

	print("Retour à la souris :")
	var mm := InputEventMouseMotion.new()
	mm.position = Vector2(300, 300)
	mm.relative = Vector2(40, 10)
	Input.parse_input_event(mm)
	await _frames(2)
	_check(not Manette.actif and not man._curseur.visible and not man._aide_boite.visible, "la souris reprend la main : curseur et aides cachés")

	print("Réglages :")
	_check(OptionsPanel.BOUTONS_MANETTE.size() >= 10, "liste des boutons dans Options → Manette")
	var op := OptionsPanel.new()
	root.add_child(op)
	await _frames(2)
	_check(op._tabs.get_child_count() == 5 and op._tabs.get_child(4).name == "Manette", "onglet Manette dans les options")
	op.queue_free()
	OptionsJeu.prereglage_steam_deck()
	_check(OptionsJeu.fenetre == 1 and OptionsJeu.fps_max == 60 and OptionsJeu.echelle_3d < 1.0, "préréglage Steam Deck : plein écran, 60 images/s, 3D allégée")

	scene.queue_free()
	await _frames(3)
	print("RÉSULTAT : ", "OK" if ok else "ÉCHEC")
	quit(0 if ok else 1)
