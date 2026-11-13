class_name MenuPause
extends CanvasLayer
## Menu pause de la partie (Échap) : le jeu entier s'arrête (get_tree().paused),
## seuls ce menu et ses fenêtres continuent de tourner.
##
## Échap ferme d'abord ce qui est ouvert (outil, fenêtre) ; le menu ne s'ouvre que
## si rien d'autre n'a pris la touche (voir terre_main._input / _unhandled_key_input).

signal resume_requested
signal save_requested
signal load_requested
signal help_requested
## Retour au menu principal ou fermeture du jeu, après la question « sauvegarder ? ».
signal quit_requested(to_desktop: bool, save_first: bool)

var unsaved := false
var place := ""
var _box: VBoxContainer
var _confirm: VBoxContainer
var _confirm_label: Label
var _confirm_desktop := false
var _sub: Control
var _status: Label


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.03, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(360, 0)
	UiStyle.style_panel(panel, 0.96, 14, 20)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var t := Label.new()
	t.text = "Pause"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 30)
	t.add_theme_color_override("font_color", UiStyle.ACCENT)
	v.add_child(t)
	var sub := Label.new()
	sub.text = (place + "\n" if place != "" else "") + "Le temps est suspendu. Les impôts aussi."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	v.add_child(sub)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 8)
	v.add_child(_box)
	_bouton("Reprendre", "Échap", func() -> void: resume_requested.emit())
	_bouton("Sauvegarder", "F5", func() -> void: save_requested.emit())
	_bouton("Charger / sauvegarder sous…", "", func() -> void: load_requested.emit())
	_bouton("Options", "", open_options)
	_bouton("Aide et commandes", "F1", func() -> void: help_requested.emit())
	_box.add_child(HSeparator.new())
	_bouton("Menu principal", "", func() -> void: _ask_quit(false))
	_bouton("Quitter le jeu", "", func() -> void: _ask_quit(true))
	# Question « sauvegarder avant de partir ? ».
	_confirm = VBoxContainer.new()
	_confirm.add_theme_constant_override("separation", 8)
	_confirm.visible = false
	v.add_child(_confirm)
	_confirm_label = Label.new()
	_confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm_label.custom_minimum_size = Vector2(320, 0)
	_confirm.add_child(_confirm_label)
	for o in [["Sauvegarder et partir", true], ["Partir sans sauvegarder", false]]:
		var b := Button.new()
		b.text = String(o[0])
		b.custom_minimum_size = Vector2(0, 38)
		var save_first: bool = o[1]
		b.pressed.connect(func() -> void: quit_requested.emit(_confirm_desktop, save_first))
		_confirm.add_child(b)
	var back := Button.new()
	back.text = "Annuler"
	back.pressed.connect(_cancel_quit)
	_confirm.add_child(back)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 13)
	_status.add_theme_color_override("font_color", UiStyle.GOOD)
	v.add_child(_status)


func _bouton(texte: String, touche: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = texte
	b.custom_minimum_size = Vector2(0, 40)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if touche != "":
		UiStyle.add_key_badge(b, touche)
	b.pressed.connect(cb)
	_box.add_child(b)
	return b


func set_status(text: String) -> void:
	if _status:
		_status.text = text


func open_options() -> void:
	if _sub != null:
		return
	var o := OptionsPanel.new()
	o.closed.connect(func() -> void: _sub = null)
	_sub = o
	add_child(o)


func _ask_quit(desktop: bool) -> void:
	if not unsaved:
		quit_requested.emit(desktop, false)
		return
	_confirm_desktop = desktop
	_confirm_label.text = "Des changements ne sont pas sauvegardés. Les habitants ne se souviendront de rien, et c'est peut-être mieux pour la voirie. On sauvegarde ?"
	_box.visible = false
	_confirm.visible = true


func _cancel_quit() -> void:
	_confirm.visible = false
	_box.visible = true


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if _confirm.visible:
			_cancel_quit()
		else:
			resume_requested.emit()
	elif k.keycode == KEY_F5:
		get_viewport().set_input_as_handled()
		save_requested.emit()
	elif k.keycode == KEY_F1:
		get_viewport().set_input_as_handled()
		help_requested.emit()
