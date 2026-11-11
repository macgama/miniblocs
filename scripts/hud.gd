extends CanvasLayer
## Interface : barre d'outils, statistiques de la ville et aide des commandes.

signal tool_selected(tool: int)
signal save_requested
signal load_requested
signal clear_requested

const TOOLS := [
	{"name": "Route", "key": KEY_1, "color": Color("4a4d55")},
	{"name": "Résidentiel", "key": KEY_2, "color": Color("5cb85c")},
	{"name": "Commercial", "key": KEY_3, "color": Color("4a90d9")},
	{"name": "Industriel", "key": KEY_4, "color": Color("e0b13a")},
	{"name": "Bulldozer", "key": KEY_5, "color": Color("d9534f")},
]

var _buttons: Array[Button] = []
var _stats_label: Label
var _message_label: Label
var _message_timer := 0.0


func _ready() -> void:
	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		root.add_theme_constant_override("margin_" + side, 12)
	add_child(root)

	var layout := VBoxContainer.new()
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(layout)

	# Bandeau du haut : statistiques.
	var top := PanelContainer.new()
	top.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	layout.add_child(top)
	_stats_label = Label.new()
	top.add_child(_stats_label)

	_message_label = Label.new()
	_message_label.add_theme_color_override("font_color", Color("fff3b0"))
	_message_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_message_label.add_theme_constant_override("outline_size", 6)
	layout.add_child(_message_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(spacer)

	# Aide des commandes.
	var help := Label.new()
	help.text = "ZQSD / flèches : déplacer   ·   Molette : zoom   ·   A / E ou clic molette : tourner   ·   Clic droit glissé : déplacer la carte\n" \
		+ "Clic gauche glissé : construire   ·   1-5 : outils   ·   F5 : sauvegarder   ·   F9 : charger   ·   Échap : annuler"
	help.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	help.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	help.add_theme_constant_override("outline_size", 4)
	help.add_theme_font_size_override("font_size", 13)
	layout.add_child(help)

	# Barre d'outils en bas.
	var bar_panel := PanelContainer.new()
	bar_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	layout.add_child(bar_panel)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	bar_panel.add_child(bar)

	var group := ButtonGroup.new()
	for i in TOOLS.size():
		var t: Dictionary = TOOLS[i]
		var b := Button.new()
		b.text = "%d · %s" % [i + 1, t.name]
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(120, 40)
		b.add_theme_color_override("font_pressed_color", t.color.lightened(0.5))
		b.add_theme_color_override("font_hover_pressed_color", t.color.lightened(0.5))
		var tool_index := i
		b.pressed.connect(func() -> void: tool_selected.emit(tool_index))
		bar.add_child(b)
		_buttons.append(b)
	_buttons[0].button_pressed = true

	bar.add_child(VSeparator.new())
	var save_btn := Button.new()
	save_btn.text = "Sauver"
	save_btn.pressed.connect(func() -> void: save_requested.emit())
	bar.add_child(save_btn)
	var load_btn := Button.new()
	load_btn.text = "Charger"
	load_btn.pressed.connect(func() -> void: load_requested.emit())
	bar.add_child(load_btn)
	var clear_btn := Button.new()
	clear_btn.text = "Tout effacer"
	clear_btn.pressed.connect(func() -> void: clear_requested.emit())
	bar.add_child(clear_btn)


func _process(delta: float) -> void:
	if _message_timer > 0.0:
		_message_timer -= delta
		if _message_timer <= 0.0:
			_message_label.text = ""


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	for i in TOOLS.size():
		if key.keycode == TOOLS[i].key or key.physical_keycode == TOOLS[i].key:
			select_tool(i)
			return
	if key.keycode == KEY_F5:
		save_requested.emit()
	elif key.keycode == KEY_F9:
		load_requested.emit()


func select_tool(i: int) -> void:
	_buttons[i].button_pressed = true
	tool_selected.emit(i)


func show_message(text: String) -> void:
	_message_label.text = text
	_message_timer = 2.5


func update_stats(s: Dictionary) -> void:
	_stats_label.text = "MiniBlocs  ·  Bac à sable\n" \
		+ "Habitants : %d    Emplois : %d    Bâtiments : %d\n" % [s.population, s.jobs, s.buildings] \
		+ "Routes : %d    Zones  R %d · C %d · I %d" % [s.roads, s.res, s.com, s.ind]
