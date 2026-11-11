class_name BuildingPanel
extends CanvasLayer
## Panneau « Construire » (à droite de l'écran) : catégories, catalogue,
## démolition et règles du bac à sable. B : afficher ou masquer.

signal building_chosen(id: String)
signal demolish_chosen
signal rules_changed(require_access: bool, unlimited_money: bool)
signal zone_chosen(kind: String)
signal zone_remove_chosen
signal growth_toggled(on: bool)
signal block_tool_chosen(tool: int)
signal block_material_chosen(material: int)
signal wall_height_changed(height: int)
signal zone_style_chosen(style: String)

var _panel: PanelContainer
var _list: VBoxContainer
var _money_label: Label
var _summary_label: Label
var _access_box: CheckBox
var _money_box: CheckBox
var _cat_buttons: Dictionary = {}
var _item_group := ButtonGroup.new()
var _item_buttons: Array[Control] = []
var _demolish_button: Button
var _category := "logement"
var _zone_label: Label
var _growth := true
var _block_label: Label
var _block_material := 0
var _wall_height := 3
var _region := ""
var _era := ""
var _search := ""
var _zone_style := ""
var _filters: HFlowContainer


func _ready() -> void:
	_item_group.allow_unpress = true
	_panel = PanelContainer.new()
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.offset_left = -372
	_panel.offset_right = -12
	_panel.offset_top = 12
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_panel.add_child(box)

	var title := Label.new()
	title.text = "Construire   (B : masquer)"
	title.add_theme_font_size_override("font_size", 17)
	box.add_child(title)
	_money_label = Label.new()
	box.add_child(_money_label)

	var cats := HFlowContainer.new()
	box.add_child(cats)
	var cat_group := ButtonGroup.new()
	var tabs: Array = BuildingCatalog.CATEGORIES.duplicate()
	tabs.append({"id": "zones", "name": "Zonage", "color": Color("ffd166")})
	tabs.append({"id": "blocs", "name": "Éditeur libre", "color": Color("8ecae6")})
	for c in tabs:
		var b := Button.new()
		b.text = c.name
		b.toggle_mode = true
		b.button_group = cat_group
		b.add_theme_color_override("font_pressed_color", c.color.lightened(0.3))
		var id: String = c.id
		b.pressed.connect(func() -> void: show_category(id))
		cats.add_child(b)
		_cat_buttons[id] = b

	# Filtres de la bible : région du monde, époque, recherche par nom.
	_filters = HFlowContainer.new()
	box.add_child(_filters)
	var region_opt := OptionButton.new()
	region_opt.add_item("Toutes les régions")
	region_opt.set_item_metadata(0, "")
	for r in Styles.REGIONS:
		region_opt.add_item(r.name)
		region_opt.set_item_metadata(region_opt.item_count - 1, r.id)
	region_opt.item_selected.connect(func(i: int) -> void:
		_region = String(region_opt.get_item_metadata(i))
		show_category(_category))
	_filters.add_child(region_opt)
	var era_opt := OptionButton.new()
	era_opt.add_item("Toutes les époques")
	era_opt.set_item_metadata(0, "")
	for e in Styles.ERAS:
		era_opt.add_item(e.name)
		era_opt.set_item_metadata(era_opt.item_count - 1, e.id)
	era_opt.item_selected.connect(func(i: int) -> void:
		_era = String(era_opt.get_item_metadata(i))
		show_category(_category))
	_filters.add_child(era_opt)
	var search := LineEdit.new()
	search.placeholder_text = "Chercher…"
	search.custom_minimum_size = Vector2(150, 0)
	search.clear_button_enabled = true
	search.text_changed.connect(func(txt: String) -> void:
		_search = txt.strip_edges().to_lower()
		show_category(_category))
	_filters.add_child(search)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)

	_demolish_button = Button.new()
	_demolish_button.text = "Démolir un bâtiment"
	_demolish_button.toggle_mode = true
	_demolish_button.button_group = _item_group
	_demolish_button.pressed.connect(func() -> void: demolish_chosen.emit())
	box.add_child(_demolish_button)

	box.add_child(HSeparator.new())
	var rules := Label.new()
	rules.text = "Règles du bac à sable"
	box.add_child(rules)
	_access_box = CheckBox.new()
	_access_box.text = "Accès à une voie obligatoire"
	_access_box.button_pressed = true
	_access_box.toggled.connect(func(_on: bool) -> void: _emit_rules())
	box.add_child(_access_box)
	_money_box = CheckBox.new()
	_money_box.text = "Argent illimité"
	_money_box.toggled.connect(func(_on: bool) -> void: _emit_rules())
	box.add_child(_money_box)

	_summary_label = Label.new()
	_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary_label.add_theme_font_size_override("font_size", 12)
	box.add_child(_summary_label)

	show_category(_category)


func _emit_rules() -> void:
	rules_changed.emit(_access_box.button_pressed, _money_box.button_pressed)


func set_rules(require_access: bool, unlimited_money: bool) -> void:
	_access_box.set_pressed_no_signal(require_access)
	_money_box.set_pressed_no_signal(unlimited_money)


func show_category(cat: String) -> void:
	_category = cat
	(_cat_buttons[cat] as Button).button_pressed = true
	for b in _item_buttons:
		b.queue_free()
	_item_buttons.clear()
	if cat == "zones":
		_show_zones()
		return
	if cat == "blocs":
		_show_blocks()
		return
	_filters.visible = true
	var shown := 0
	for id in BuildingCatalog.ids_in(cat, _region, _era):
		var t := BuildingCatalog.get_type(id)
		if _search != "" and not (String(t.name) + " " + String(t.desc)).to_lower().contains(_search):
			continue
		shown += 1
		var b := Button.new()
		b.text = "%s  ·  %d × %d m  ·  %s" % [t.name, t.w, t.d, BuildingSystem.format_short(BuildingCatalog.cost(id))]
		b.tooltip_text = "%s\n%s\nPrix : %s (hors terrassement)" % [b.text, t.desc, BuildingSystem.format_money(BuildingCatalog.cost(id))]
		# Noms longs (« Maisons de ville (village méditerranéen) ») : coupés « … », complets dans l'infobulle.
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.clip_text = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.toggle_mode = true
		b.button_group = _item_group
		var type_id: String = id
		b.pressed.connect(func() -> void: building_chosen.emit(type_id))
		_list.add_child(b)
		_item_buttons.append(b)
	if shown == 0:
		var none := Label.new()
		none.text = "Aucun bâtiment pour ces filtres."
		_list.add_child(none)
		_item_buttons.append(none)


func _show_zones() -> void:
	_filters.visible = false
	# Style que suivra le zonage (les bâtiments qui poussent).
	var srow := HBoxContainer.new()
	var sl := Label.new()
	sl.text = "Style :"
	srow.add_child(sl)
	var style_opt := OptionButton.new()
	style_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	style_opt.fit_to_longest_item = false
	style_opt.clip_text = true
	style_opt.custom_minimum_size = Vector2(220, 0)
	style_opt.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	style_opt.add_item("Classique MiniBlocs")
	style_opt.set_item_metadata(0, "")
	style_opt.add_item("Mélange de tous les styles")
	style_opt.set_item_metadata(1, "mix")
	for sid in Styles.STYLES:
		var st: Dictionary = Styles.STYLES[sid]
		style_opt.add_item("%s (%s, %s)" % [st.name, Styles.region_name(st.region), Styles.era_name(st.era).to_lower()])
		style_opt.set_item_metadata(style_opt.item_count - 1, sid)
	for i in style_opt.item_count:
		if String(style_opt.get_item_metadata(i)) == _zone_style:
			style_opt.select(i)
	style_opt.item_selected.connect(func(i: int) -> void:
		_zone_style = String(style_opt.get_item_metadata(i))
		zone_style_chosen.emit(_zone_style))
	srow.add_child(style_opt)
	_list.add_child(srow)
	_item_buttons.append(srow)
	for k in ZoneSystem.KINDS:
		var b := Button.new()
		b.text = "Zone %s  ·  %d €/m²" % [String(ZoneSystem.KINDS[k].name).to_lower(), ZoneSystem.PRICE_M2]
		b.tooltip_text = "Clic gauche glissé pour peindre. Des bâtiments poussent le long des routes selon la demande."
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.toggle_mode = true
		b.button_group = _item_group
		b.add_theme_color_override("font_pressed_color", (ZoneSystem.KINDS[k].color as Color).lightened(0.4))
		var kk: String = k
		b.pressed.connect(func() -> void: zone_chosen.emit(kk))
		_list.add_child(b)
		_item_buttons.append(b)
	var rm := Button.new()
	rm.text = "Retirer des zones"
	rm.alignment = HORIZONTAL_ALIGNMENT_LEFT
	rm.toggle_mode = true
	rm.button_group = _item_group
	rm.pressed.connect(func() -> void: zone_remove_chosen.emit())
	_list.add_child(rm)
	_item_buttons.append(rm)
	var grow := CheckBox.new()
	grow.text = "Croissance automatique"
	grow.button_pressed = _growth
	grow.toggled.connect(func(on: bool) -> void:
		_growth = on
		growth_toggled.emit(on))
	_list.add_child(grow)
	_item_buttons.append(grow)
	_zone_label = Label.new()
	_zone_label.add_theme_font_size_override("font_size", 12)
	_zone_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_list.add_child(_zone_label)
	_item_buttons.append(_zone_label)


func _show_blocks() -> void:
	_filters.visible = false
	var tools := [["Bloc", BlockEditor.Tool.BLOCK, "Un clic = un bloc, contre le sol ou contre un autre bloc."],
		["Rectangle", BlockEditor.Tool.RECT, "Clic glissé : dalle, plancher ou toit plat."],
		["Mur", BlockEditor.Tool.WALL, "Clic glissé en ligne : mur de la hauteur choisie."],
		["Gomme", BlockEditor.Tool.ERASE, "Clic sur un bloc, ou glissé pour effacer un étage."]]
	var row := HFlowContainer.new()
	_list.add_child(row)
	_item_buttons.append(row)
	for t in tools:
		var b := Button.new()
		b.text = t[0]
		b.tooltip_text = t[2]
		b.toggle_mode = true
		b.button_group = _item_group
		var tool_id: int = t[1]
		b.pressed.connect(func() -> void: block_tool_chosen.emit(tool_id))
		row.add_child(b)
	var hrow := HBoxContainer.new()
	var hl := Label.new()
	hl.text = "Hauteur des murs (blocs) :"
	hrow.add_child(hl)
	var spin := SpinBox.new()
	spin.min_value = 1
	spin.max_value = 30
	spin.value = _wall_height
	spin.value_changed.connect(func(v: float) -> void:
		_wall_height = int(v)
		wall_height_changed.emit(int(v)))
	hrow.add_child(spin)
	_list.add_child(hrow)
	_item_buttons.append(hrow)
	var grid := GridContainer.new()
	grid.columns = 7
	_list.add_child(grid)
	_item_buttons.append(grid)
	var mat_group := ButtonGroup.new()
	for i in BlockEditor.MATERIALS.size():
		var m: Dictionary = BlockEditor.MATERIALS[i]
		var b := Button.new()
		b.custom_minimum_size = Vector2(40, 34)
		b.toggle_mode = true
		b.button_group = mat_group
		b.tooltip_text = "%s · %d € le bloc" % [m.name, m.price]
		var col: Color = m.color
		for state in ["normal", "hover", "pressed", "hover_pressed"]:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(col.r, col.g, col.b, 1.0)
			sb.set_corner_radius_all(4)
			if state.contains("pressed"):
				sb.set_border_width_all(3)
				sb.border_color = Color.WHITE
			elif state == "hover":
				sb.set_border_width_all(2)
				sb.border_color = Color(1, 1, 1, 0.6)
			b.add_theme_stylebox_override(state, sb)
		b.button_pressed = i == _block_material
		var mi := i
		b.pressed.connect(func() -> void:
			_block_material = mi
			block_material_chosen.emit(mi))
		grid.add_child(b)
	_block_label = Label.new()
	_block_label.add_theme_font_size_override("font_size", 12)
	_block_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_block_label.text = "Clic droit : retirer un bloc · Ctrl+Z : annuler"
	_list.add_child(_block_label)
	_item_buttons.append(_block_label)


func set_block_info(text: String) -> void:
	if is_instance_valid(_block_label) and not _block_label.is_queued_for_deletion():
		_block_label.text = text + "\nClic droit : retirer un bloc · Ctrl+Z : annuler"


func set_zone_info(text: String) -> void:
	if is_instance_valid(_zone_label) and not _zone_label.is_queued_for_deletion():
		_zone_label.text = text


func set_growth(on: bool) -> void:
	_growth = on


## Plus rien de sélectionné dans le panneau (un autre outil a été choisi).
func clear_selection() -> void:
	var pressed := _item_group.get_pressed_button()
	if pressed:
		pressed.set_pressed_no_signal(false)


func set_money(text: String) -> void:
	_money_label.text = text


func set_summary(text: String) -> void:
	_summary_label.text = text


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.physical_keycode == KEY_B:
		_panel.visible = not _panel.visible
