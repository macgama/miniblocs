class_name StationPanel
extends CanvasLayer
## Panneau « Transports publics » (touche T) : poser des stations, tracer des
## lignes, choisir le véhicule et le nombre de véhicules de chaque ligne.

signal station_chosen(type_id: String)
signal demolish_chosen
signal line_tool_chosen

var stations: StationSystem
var _panel: PanelContainer
var _lines_box: VBoxContainer
var _group := ButtonGroup.new()
var _buttons: Array[Button] = []


func setup(s: StationSystem) -> void:
	stations = s
	stations.lines_changed.connect(_refresh_lines)
	_build()
	_refresh_lines()


func _build() -> void:
	layer = 5
	_panel = PanelContainer.new()
	_panel.anchor_top = 0.0
	_panel.offset_left = 10
	_panel.offset_top = 250
	_panel.custom_minimum_size = Vector2(330, 0)
	_panel.visible = false
	add_child(_panel)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(330, 430)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 4)
	scroll.add_child(box)
	var title := Label.new()
	title.text = "Transports publics   (T : masquer)"
	title.add_theme_font_size_override("font_size", 16)
	box.add_child(title)
	var hint := Label.new()
	hint.text = "1. Pose des stations sur tes voies.\n2. Nouvelle ligne : clique les stations dans l'ordre.\n3. Choisis le véhicule et leur nombre."
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	box.add_child(hint)
	var grid := GridContainer.new()
	grid.columns = 2
	box.add_child(grid)
	for id in StationSystem.ORDER:
		var b := _tool_button(StationSystem.get_type(id).name)
		b.tooltip_text = StationSystem.get_type(id).desc
		var tid: String = id
		b.pressed.connect(func() -> void: station_chosen.emit(tid))
		grid.add_child(b)
	var del := _tool_button("Supprimer une station")
	del.pressed.connect(func() -> void: demolish_chosen.emit())
	grid.add_child(del)
	box.add_child(HSeparator.new())
	var nl := _tool_button("Nouvelle ligne")
	nl.pressed.connect(func() -> void: line_tool_chosen.emit())
	box.add_child(nl)
	_lines_box = VBoxContainer.new()
	box.add_child(_lines_box)


func _tool_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_group = _group
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_buttons.append(b)
	return b


func clear_selection() -> void:
	for b in _buttons:
		b.set_pressed_no_signal(false)


func toggle() -> void:
	_panel.visible = not _panel.visible


func is_open() -> bool:
	return _panel.visible


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.keycode == KEY_T:
		toggle()
		get_viewport().set_input_as_handled()


func _refresh_lines() -> void:
	if _lines_box == null:
		return
	for c in _lines_box.get_children():
		c.queue_free()
	if stations.lines.is_empty():
		var l := Label.new()
		l.text = "Aucune ligne."
		l.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
		_lines_box.add_child(l)
		return
	for lid in stations.lines:
		var line: Dictionary = stations.lines[lid]
		var head := HBoxContainer.new()
		var sw := ColorRect.new()
		sw.color = line.color
		sw.custom_minimum_size = Vector2(12, 12)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(sw)
		var name_ := Label.new()
		name_.text = stations.line_summary(lid)
		name_.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_.custom_minimum_size = Vector2(240, 0)
		name_.add_theme_font_size_override("font_size", 13)
		head.add_child(name_)
		var x := Button.new()
		x.text = "✕"
		x.tooltip_text = "Supprimer la ligne"
		var id_: int = lid
		x.pressed.connect(func() -> void: stations.remove_line(id_))
		head.add_child(x)
		_lines_box.add_child(head)
		var row := HBoxContainer.new()
		var pick := OptionButton.new()
		pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pick.fit_to_longest_item = false
		pick.custom_minimum_size = Vector2(220, 0)
		var models := stations.models_for(line.kind, line.stops)
		for i in models.size():
			var t := VehicleCatalog.get_type(models[i])
			pick.add_item("%s (%d)" % [t.name, int(t.year)], i)
			if models[i] == line.model:
				pick.select(i)
		row.add_child(pick)
		var count := SpinBox.new()
		count.min_value = 1
		count.max_value = 30
		count.value = int(line.count)
		count.tooltip_text = "Nombre de véhicules"
		row.add_child(count)
		pick.item_selected.connect(func(i: int) -> void: stations.set_line(id_, models[i], int(count.value)))
		count.value_changed.connect(func(v: float) -> void: stations.set_line(id_, String(stations.lines[id_].model), int(v)))
		_lines_box.add_child(row)
