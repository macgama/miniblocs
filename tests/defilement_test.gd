extends SceneTree
## Test des fenêtres trop hautes pour l'écran : Réglages de la partie (globe et F10),
## Aide (F1), Son (F2). Elles doivent tenir dans la vue (base 1600×900 et petite
## fenêtre sans mise à l'échelle), garder titre et pied visibles et laisser
## atteindre la dernière option en faisant défiler (molette, manette).
## Usage : godot --headless --path . --script res://tests/defilement_test.gd

var ok := true


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


func _panel_of(n: Node) -> Control:
	return n.find_children("*", "PanelContainer", true, false)[0]


func _scroll_of(n: Node) -> ScrollContainer:
	var l := n.find_children("Defilement", "ScrollContainer", true, false)
	return l[0] if not l.is_empty() else null


## Ouvre la fenêtre, vérifie qu'elle tient dans la vue et qu'on atteint le bas.
## En hauteur seulement quand `largeur` est faux : avec la mise à l'échelle du projet
## (canvas_items, expand), la vue fait toujours au moins 1600 de large.
func _essai(nom: String, n: Node, vue: Vector2, largeur := true) -> void:
	root.add_child(n)
	await _frames(6)
	var p := _panel_of(n)
	var r := p.get_global_rect()
	var dedans := r.position.y >= -1.0 and r.end.y <= vue.y + 1.0
	if largeur:
		dedans = dedans and Rect2(Vector2.ZERO, vue).grow(1.0).encloses(r)
	_check(dedans, "%s tient dans %s (fenêtre %s)" % [nom, vue, r])
	var sc := _scroll_of(n)
	_check(sc != null, "%s a une zone qui défile" % nom)
	if sc != null:
		var bar := sc.get_v_scroll_bar()
		var contenu: Control = sc.get_child(0)
		var deborde := contenu.get_combined_minimum_size().y > sc.size.y + 1.0
		_check(not deborde or bar.max_value - bar.page > 1.0, "%s : la barre de défilement couvre tout le contenu" % nom)
		if deborde:
			# Molette : quelques crans vers le bas déplacent le contenu.
			var avant := sc.scroll_vertical
			var e := InputEventMouseButton.new()
			e.button_index = MOUSE_BUTTON_WHEEL_DOWN
			e.pressed = true
			e.position = sc.get_global_rect().get_center()
			e.global_position = e.position
			for i in 3:
				root.push_input(e)
				await process_frame
			_check(sc.scroll_vertical > avant, "%s : la molette fait défiler (%d → %d)" % [nom, avant, sc.scroll_vertical])
			# Manette : le stick droit passe par UiStyle.scroll_under.
			sc.scroll_vertical = 0
			var feuille: Control = contenu
			while feuille.get_child_count() > 0 and feuille.get_child(-1) is Control:
				feuille = feuille.get_child(-1)
			_check(UiStyle.scroll_under(feuille, 1e6), "%s : la manette trouve la zone qui défile" % nom)
			await _frames(2)
			_check(sc.scroll_vertical >= int(bar.max_value - bar.page) - 1, "%s : on atteint le bas du contenu" % nom)
			var bas := feuille.get_global_rect()
			_check(sc.get_global_rect().grow(1.0).intersects(bas), "%s : la dernière option est visible en bas" % nom)
	n.queue_free()
	await _frames(2)


func _run() -> void:
	print("Fenêtres qui défilent")
	# 1) Base de l'interface (1600×900, mise à l'échelle du projet).
	root.size = Vector2i(1600, 900)
	root.content_scale_size = Vector2i(1600, 900)
	await _frames(2)
	var vue := root.get_visible_rect().size
	await _essai("Réglages de la nouvelle partie", AdminPanel.new(ReglagesPartie.new(), true, true), vue)
	await _essai("Admin en partie (F10)", AdminPanel.new(ReglagesPartie.new(), false, true, 1_000_000), vue)
	await _essai("Aide (F1)", AidePanel.new(), vue)
	await _essai("Son (F2)", SonPanel.new(), vue)
	# 2) Petite fenêtre sans mise à l'échelle : la zone se recalcule.
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1366, 700)
	await _frames(2)
	vue = root.get_visible_rect().size
	await _essai("Réglages en 1366×700", AdminPanel.new(ReglagesPartie.new(), true, true), vue, false)
	await _essai("Aide en 1366×700", AidePanel.new(), vue)
	# 3) La fenêtre change de taille alors que les réglages sont ouverts.
	var a := AdminPanel.new(ReglagesPartie.new(), true, true)
	root.add_child(a)
	await _frames(4)
	root.size = Vector2i(1366, 600)
	await _frames(4)
	vue = root.get_visible_rect().size
	var ra := _panel_of(a).get_global_rect()
	_check(ra.position.y >= -1.0 and ra.end.y <= vue.y + 1.0,
		"Réglages : la fenêtre se réajuste quand l'écran rapetisse")
	a.queue_free()
	await _frames(2)
	print("TEST OK" if ok else "TEST ÉCHEC")
	quit(0 if ok else 1)
