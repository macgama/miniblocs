class_name TerreHud
extends CanvasLayer
## Interface du mode Terre : choix du lieu, outils de terrassement, infos de la case.

signal go_requested(lat: float, lon: float)
signal tool_selected(tool: int)
signal save_requested
signal load_requested
signal city_requested
signal globe_requested
signal traffic_toggled(on: bool)

const PLACES := [
	{"name": "Tour Eiffel", "lat": 48.85826, "lon": 2.29450},
	{"name": "Genève (rade)", "lat": 46.20730, "lon": 6.15570},
	{"name": "Mont Blanc", "lat": 45.83260, "lon": 6.86520},
	{"name": "Étretat", "lat": 49.70700, "lon": 0.20160},
	{"name": "Grand Canyon", "lat": 36.06100, "lon": -112.10800},
	{"name": "Mont Fuji", "lat": 35.36060, "lon": 138.72740},
	{"name": "Rio (Pain de Sucre)", "lat": -22.94860, "lon": -43.15660},
]

const TOOLS := [
	{"name": "Observer", "key": KEY_1},
	{"name": "Aplanir", "key": KEY_2},
	{"name": "Monter +1 m", "key": KEY_3},
	{"name": "Creuser −1 m", "key": KEY_4},
	{"name": "Route", "key": KEY_5},
	{"name": "Rail", "key": KEY_6},
	{"name": "Chemin", "key": KEY_7},
	{"name": "Voie d'eau", "key": KEY_8},
	{"name": "Démolir", "key": KEY_9},
]
## Premier outil de transport dans TOOLS (les précédents sont les outils de terrain).
const FIRST_TRANSPORT_TOOL := 4

var coords_edit: LineEdit
var _place_label: Label
var _cell_label: Label
var _status_label: Label
var _network_label: Label
var _tool_label: Label
var _message_label: Label
var _message_timer := 0.0
var _buttons: Array[Button] = []


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

	# Panneau du haut : lieu.
	var top := PanelContainer.new()
	top.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	layout.add_child(top)
	var top_box := VBoxContainer.new()
	top.add_child(top_box)
	_place_label = Label.new()
	top_box.add_child(_place_label)

	var row := HBoxContainer.new()
	top_box.add_child(row)
	var l := Label.new()
	l.text = "Latitude, longitude :"
	row.add_child(l)
	coords_edit = LineEdit.new()
	coords_edit.custom_minimum_size = Vector2(220, 0)
	coords_edit.placeholder_text = "48.8584, 2.2945"
	coords_edit.text_submitted.connect(func(_t: String) -> void: _on_go())
	row.add_child(coords_edit)
	var go := Button.new()
	go.text = "Y aller"
	go.pressed.connect(_on_go)
	row.add_child(go)

	var places := HFlowContainer.new()
	places.custom_minimum_size = Vector2(560, 0)
	top_box.add_child(places)
	for p in PLACES:
		var b := Button.new()
		b.text = p.name
		var lat: float = p.lat
		var lon: float = p.lon
		b.pressed.connect(func() -> void:
			coords_edit.text = "%.5f, %.5f" % [lat, lon]
			go_requested.emit(lat, lon))
		places.add_child(b)

	_cell_label = Label.new()
	top_box.add_child(_cell_label)
	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	top_box.add_child(_status_label)
	_network_label = Label.new()
	top_box.add_child(_network_label)

	_message_label = Label.new()
	_message_label.add_theme_color_override("font_color", Color("fff3b0"))
	_message_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_message_label.add_theme_constant_override("outline_size", 6)
	layout.add_child(_message_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(spacer)

	var help := Label.new()
	help.text = "ZQSD / flèches : déplacer   ·   Molette : zoom   ·   A / E ou clic molette : tourner   ·   Clic droit glissé : déplacer la carte\n" \
		+ "Clic gauche glissé : terrasser (2-4)   ·   5-8 : poser une voie, clic par point, Échap / clic droit pour finir, Maj : angles de 15°   ·   9 : démolir\n" \
		+ "1-9 : outils   ·   F5 : sauvegarder   ·   F9 : charger   ·   Échap : annuler"
	help.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	help.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	help.add_theme_constant_override("outline_size", 4)
	help.add_theme_font_size_override("font_size", 13)
	layout.add_child(help)

	_tool_label = Label.new()
	_tool_label.add_theme_color_override("font_color", Color("d8f3dc"))
	_tool_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_tool_label.add_theme_constant_override("outline_size", 6)
	layout.add_child(_tool_label)

	var bottom := HBoxContainer.new()
	layout.add_child(bottom)
	var bar_panel := PanelContainer.new()
	bottom.add_child(bar_panel)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	bar_panel.add_child(bar)
	var group := ButtonGroup.new()
	for i in TOOLS.size():
		if i == FIRST_TRANSPORT_TOOL:
			bar.add_child(VSeparator.new())
		var b := Button.new()
		b.text = "%d · %s" % [i + 1, TOOLS[i].name]
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(96, 40)
		var tool_index := i
		b.pressed.connect(func() -> void: tool_selected.emit(tool_index))
		bar.add_child(b)
		_buttons.append(b)
	_buttons[0].button_pressed = true
	bar.add_child(VSeparator.new())
	var traffic := Button.new()
	traffic.text = "Circulation"
	traffic.toggle_mode = true
	traffic.button_pressed = true
	traffic.toggled.connect(func(on: bool) -> void: traffic_toggled.emit(on))
	bar.add_child(traffic)
	for spec in [["Sauver", save_requested], ["Charger", load_requested], ["Globe", globe_requested], ["Ville prototype", city_requested]]:
		var b := Button.new()
		b.text = spec[0]
		var sig: Signal = spec[1]
		b.pressed.connect(func() -> void: sig.emit())
		bar.add_child(b)

	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(fill)
	var credit := Label.new()
	credit.text = "Relief : Mapzen Terrain Tiles (AWS Open Data) — SRTM, GMTED, ETOPO1, EU-DEM\nBiomes : © ESA WorldCover 2021, données Copernicus Sentinel (CC BY 4.0)"
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	credit.size_flags_vertical = Control.SIZE_SHRINK_END
	credit.add_theme_font_size_override("font_size", 11)
	credit.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	credit.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	credit.add_theme_constant_override("outline_size", 3)
	bottom.add_child(credit)


func _on_go() -> void:
	var v: Variant = Geo.parse_lat_lon(coords_edit.text)
	coords_edit.release_focus()
	if v == null:
		show_message("Coordonnées non comprises. Exemple : 48.8584, 2.2945")
		return
	go_requested.emit((v as Vector2).x, (v as Vector2).y)


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
			_buttons[i].button_pressed = true
			tool_selected.emit(i)
			return
	if key.keycode == KEY_F5:
		save_requested.emit()
	elif key.keycode == KEY_F9:
		load_requested.emit()


func show_message(text: String) -> void:
	_message_label.text = text
	_message_timer = 3.0


func set_place(lat: float, lon: float) -> void:
	_place_label.text = "MiniBlocs · Terre   —   région centrée sur %.5f, %.5f   (1 case = 1 m × 1 m)" % [lat, lon]
	if not coords_edit.has_focus():
		coords_edit.text = "%.5f, %.5f" % [lat, lon]


func set_cell_info(text: String) -> void:
	_cell_label.text = text


func set_tool_info(text: String) -> void:
	_tool_label.text = text


func set_network_info(text: String) -> void:
	_network_label.text = text


func set_status(text: String) -> void:
	_status_label.text = text
