class_name TerreHud
extends CanvasLayer
## Interface du mode Terre : choix du lieu, outils de terrassement, infos de la case.

signal go_requested(lat: float, lon: float)
signal tool_selected(tool: int)
signal save_requested
signal help_requested
signal load_requested
signal quick_load_requested
signal city_requested
signal globe_requested
signal traffic_toggled(on: bool)
## Époque et région des véhicules de la circulation ("" = toutes).
signal traffic_filter_changed(era: String, region: String)
## Bouton « Lignes » : panneau des transports publics.
signal transit_requested
signal spec_edited(type_id: String, spec: Dictionary)
signal curve_toggled(on: bool)

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
	{"name": "Carrefour", "key": KEY_0},
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
# Panneau de réglage de la voie à poser.
var _spec_panel: PanelContainer
var _class_pick: OptionButton
var _class_ids: Array = []
var _lanes: SpinBox
var _lane_w: SpinBox
var _tracks: SpinBox
var _width: SpinBox
var _curve: Button
var _spec_rows: Dictionary = {}
var _filling := false


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
	var title_row := HBoxContainer.new()
	top_box.add_child(title_row)
	_place_label = Label.new()
	_place_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(_place_label)
	# Menu de la partie : toujours au même endroit, en haut à gauche.
	for spec in [["Sauver", save_requested, "Sauvegarder la partie (F5)"], ["Charger", load_requested, "Parties sauvegardées (F9 : recharger la partie en cours)"],
			["Globe", globe_requested, "Revenir au globe pour changer de lieu"], ["Aide", help_requested, "Toutes les commandes (F1)"]]:
		var mb := Button.new()
		mb.text = spec[0]
		mb.tooltip_text = spec[2]
		mb.focus_mode = Control.FOCUS_NONE
		var sig: Signal = spec[1]
		mb.pressed.connect(func() -> void: sig.emit())
		title_row.add_child(mb)

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
	help.text = "F1 : toutes les commandes   ·   ZQSD : déplacer   ·   Molette : zoom   ·   A / E : tourner   ·   1-9 : outils   ·   B : construire   ·   L : lignes   ·   V : vue   ·   T : pause   ·   Échap : annuler"
	help.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	help.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	help.add_theme_constant_override("outline_size", 4)
	help.add_theme_font_size_override("font_size", 13)
	layout.add_child(help)

	_build_spec_panel(layout)

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
		b.text = "%d · %s" % [(i + 1) % 10, TOOLS[i].name]
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
	bar.add_child(_build_vehicle_menu())
	var transit := Button.new()
	transit.text = "Lignes (L)"
	transit.tooltip_text = "Stations, gares, ports, aéroports et lignes de transport en commun"
	transit.pressed.connect(func() -> void: transit_requested.emit())
	bar.add_child(transit)

	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(fill)
	var credit := Label.new()
	credit.text = "Relief : Mapzen Terrain Tiles\nBiomes : © ESA WorldCover 2021\nRivières : © OpenStreetMap"
	credit.tooltip_text = "Relief : Mapzen Terrain Tiles (AWS Open Data) — SRTM, GMTED, ETOPO1, EU-DEM\nBiomes : © ESA WorldCover 2021, données Copernicus Sentinel (CC BY 4.0)\nRivières : © contributeurs OpenStreetMap (ODbL) si disponible, sinon calculées sur le relief"
	credit.mouse_filter = Control.MOUSE_FILTER_PASS
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	credit.size_flags_vertical = Control.SIZE_SHRINK_END
	credit.add_theme_font_size_override("font_size", 11)
	credit.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	credit.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	credit.add_theme_constant_override("outline_size", 3)
	bottom.add_child(credit)


var _veh_era := ""
var _veh_region := ""


## Menu « Véhicules » : époque et région des modèles qui circulent.
func _build_vehicle_menu() -> MenuButton:
	var mb := MenuButton.new()
	mb.text = "Véhicules ▾"
	mb.flat = false
	var pm := mb.get_popup()
	pm.hide_on_checkable_item_selection = false
	pm.add_separator("Époque")
	var entries: Array = [["era", ""]]
	pm.add_radio_check_item("Toutes les époques", 0)
	for e in Styles.ERAS:
		pm.add_radio_check_item(e.name, entries.size())
		entries.append(["era", e.id])
	pm.add_separator("Région")
	pm.add_radio_check_item("Toutes les régions", entries.size())
	entries.append(["region", ""])
	for r in Styles.REGIONS:
		if r.id == "monde":
			continue
		pm.add_radio_check_item(r.name, entries.size())
		entries.append(["region", r.id])
	var refresh := func() -> void:
		for i in pm.item_count:
			var id := pm.get_item_id(i)
			if pm.is_item_separator(i) or id < 0 or id >= entries.size():
				continue
			var en: Array = entries[id]
			pm.set_item_checked(i, (_veh_era if en[0] == "era" else _veh_region) == en[1])
	refresh.call()
	pm.id_pressed.connect(func(id: int) -> void:
		var en: Array = entries[id]
		if en[0] == "era":
			_veh_era = en[1]
		else:
			_veh_region = en[1]
		refresh.call()
		traffic_filter_changed.emit(_veh_era, _veh_region))
	return mb


func _build_spec_panel(layout: Control) -> void:
	_spec_panel = PanelContainer.new()
	_spec_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_spec_panel.visible = false
	layout.add_child(_spec_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_spec_panel.add_child(row)
	_class_pick = OptionButton.new()
	_class_pick.custom_minimum_size = Vector2(260, 0)
	_class_pick.item_selected.connect(func(i: int) -> void:
		if _filling:
			return
		var id: String = _class_ids[i]
		spec_edited.emit(id, TransportTypes.default_spec(id)))
	row.add_child(_class_pick)
	_lanes = _spin(row, "lanes", "Voies par sens", 1, 4, 1)
	_lane_w = _spin(row, "lane_w", "Largeur d'une voie (m)", 2.75, 3.5, 0.05)
	_tracks = _spin(row, "tracks", "Voies ferrées", 1, 2, 1)
	_width = _spin(row, "width", "Largeur (m)", 1.0, 60.0, 0.1)
	_curve = Button.new()
	_curve.text = "Courbe (C)"
	_curve.toggle_mode = true
	_curve.toggled.connect(func(on: bool) -> void:
		if not _filling:
			curve_toggled.emit(on))
	row.add_child(_curve)


func _spin(row: Control, key: String, label: String, lo: float, hi: float, step: float) -> SpinBox:
	var box := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	box.add_child(l)
	var sb := SpinBox.new()
	sb.min_value = lo
	sb.max_value = hi
	sb.step = step
	sb.custom_minimum_size = Vector2(90, 0)
	sb.value_changed.connect(func(_v: float) -> void: _emit_spec())
	box.add_child(sb)
	row.add_child(box)
	_spec_rows[key] = box
	return sb


func _emit_spec() -> void:
	if _filling or _class_ids.is_empty():
		return
	var id: String = _class_ids[_class_pick.selected]
	var s := {"lanes": int(_lanes.value), "lane_w": _lane_w.value, "tracks": int(_tracks.value), "width": _width.value}
	spec_edited.emit(id, TransportTypes.normalize(id, s))


## Affiche le panneau de réglage pour une classe de voie (null : le cacher).
func show_spec(type_id: String, spec: Dictionary, curve: bool) -> void:
	if type_id == "":
		_spec_panel.visible = false
		return
	_filling = true
	var c := TransportTypes.get_type(type_id)
	_class_ids = TransportTypes.BY_MODE.get(int(c.mode), [type_id])
	_class_pick.clear()
	for id in _class_ids:
		_class_pick.add_item(TransportTypes.get_type(id).name)
	_class_pick.select(maxi(0, _class_ids.find(type_id)))
	_spec_rows.lanes.visible = c.has("lanes")
	_spec_rows.lane_w.visible = c.has("lanes")
	_spec_rows.tracks.visible = c.has("tracks")
	_spec_rows.width.visible = c.has("width")
	if c.has("lanes"):
		_lanes.min_value = c.lanes[0]
		_lanes.max_value = c.lanes[1]
		_lanes.value = spec.lanes
		_lanes.editable = int(c.lanes[0]) != int(c.lanes[1])
		_lane_w.min_value = c.lane_w[0]
		_lane_w.max_value = c.lane_w[1]
		_lane_w.value = spec.lane_w
		_lane_w.editable = float(c.lane_w[0]) != float(c.lane_w[1])
	if c.has("tracks"):
		_tracks.min_value = c.tracks[0]
		_tracks.max_value = c.tracks[1]
		_tracks.value = spec.tracks
		_tracks.editable = int(c.tracks[0]) != int(c.tracks[1])
	if c.has("width"):
		_width.min_value = c.width[0]
		_width.max_value = c.width[1]
		_width.value = spec.width
	_curve.button_pressed = curve
	_spec_panel.visible = true
	_filling = false


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
	if key.keycode == KEY_F1:
		help_requested.emit()
	elif key.keycode == KEY_F5:
		save_requested.emit()
	elif key.keycode == KEY_F9:
		quick_load_requested.emit()


## Enfonce le bouton d'un outil sans prévenir (un autre système a pris la main).
func select_tool_silently(i: int) -> void:
	_buttons[i].set_pressed_no_signal(true)


func show_message(text: String) -> void:
	_message_label.text = text
	_message_timer = 3.0


func set_place(lat: float, lon: float) -> void:
	var where := GameStart.place_name if GameStart.place_name != "" else "%.4f, %.4f" % [lat, lon]
	_place_label.text = "MiniBlocs  ·  " + where
	_place_label.tooltip_text = "Région de 10 × 10 km centrée sur %.5f, %.5f (1 case = 1 m × 1 m)" % [lat, lon]
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
