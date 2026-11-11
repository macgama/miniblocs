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
	for id in BuildingCatalog.ids_in(cat):
		var t := BuildingCatalog.get_type(id)
		var b := Button.new()
		b.text = "%s  ·  %d × %d m  ·  %s" % [t.name, t.w, t.d, BuildingSystem.format_short(BuildingCatalog.cost(id))]
		b.tooltip_text = "%s\nPrix : %s (hors terrassement)" % [t.desc, BuildingSystem.format_money(BuildingCatalog.cost(id))]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.toggle_mode = true
		b.button_group = _item_group
		var type_id: String = id
		b.pressed.connect(func() -> void: building_chosen.emit(type_id))
		_list.add_child(b)
		_item_buttons.append(b)


func _show_zones() -> void:
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
