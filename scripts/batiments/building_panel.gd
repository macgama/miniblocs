class_name BuildingPanel
extends CanvasLayer
## Panneau « Construire » (à droite de l'écran) : catégories en icônes,
## bâtiments en vignettes, démolition et règles du bac à sable.
## B ou le bouton Construire de la barre du bas : afficher ou masquer.

signal building_chosen(id: String)
signal demolish_chosen
signal rules_changed(require_access: bool, unlimited_money: bool)
signal zone_chosen(kind: String)
signal zone_remove_chosen
signal growth_toggled(on: bool)
signal block_tool_chosen(tool: int)
signal block_material_chosen(material: int)
signal block_shape_chosen(shape: int)
signal block_tint_chosen(tint: int)
signal wall_height_changed(height: int)
signal zone_style_chosen(style: String)
signal capture_name_changed(name: String)
signal creation_deleted(id: String)

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
var _block_shape := 0
var _block_tint := 0
var _mat_family := ""
var _icons := {}
var _wall_height := 3
var _region := ""
var _era := ""
var _search := ""
var _zone_style := ""
var _filters: HFlowContainer
var _capture_name := ""
var _cat_title: Label
var _rules_box: VBoxContainer
var _vignettes: Vignettes

## Icône de chaque onglet.
const CAT_ICONS := {"logement": "logement", "commerce": "commerce", "industrie": "industrie",
	"services": "services", "loisirs": "loisirs", "sport": "sport", "espaces": "publics",
	"zones": "zonage", "blocs": "editeur", "creations": "creations"}


func _ready() -> void:
	_item_group.allow_unpress = true
	_vignettes = Vignettes.new()
	_vignettes.name = "Vignettes"
	add_child(_vignettes)
	_panel = PanelContainer.new()
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = UiStyle.SIDE_LEFT
	_panel.offset_right = UiStyle.SIDE_RIGHT
	_panel.offset_top = UiStyle.SIDE_TOP
	_panel.offset_bottom = -112
	_panel.visible = false
	UiStyle.style_panel(_panel)
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_panel.add_child(box)

	var head := HBoxContainer.new()
	box.add_child(head)
	var hi := TextureRect.new()
	hi.texture = Icones.get_icon("construire", 24, UiStyle.ACCENT)
	hi.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	head.add_child(hi)
	var title := Label.new()
	title.text = "Construire"
	title.add_theme_font_size_override("font_size", 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_money_label = Label.new()
	_money_label.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	head.add_child(_money_label)
	var close := UiStyle.icon_button("fermer", "Fermer", "B", 18, 32)
	close.pressed.connect(func() -> void: set_open(false))
	head.add_child(close)

	var cats := GridContainer.new()
	cats.columns = 5
	cats.add_theme_constant_override("h_separation", 4)
	cats.add_theme_constant_override("v_separation", 4)
	box.add_child(cats)
	var cat_group := ButtonGroup.new()
	var tabs: Array = BuildingCatalog.CATEGORIES.duplicate()
	tabs.append({"id": "zones", "name": "Zonage", "color": Color("ffd166")})
	tabs.append({"id": "blocs", "name": "Éditeur libre", "color": Color("8ecae6")})
	tabs.append({"id": Creations.CATEGORY, "name": "Mes créations", "color": Color("f4a261")})
	for c in tabs:
		var b := UiStyle.icon_button(String(CAT_ICONS.get(c.id, "construire")), c.name, "", 26, 46)
		b.custom_minimum_size = Vector2(70, 46)
		b.toggle_mode = true
		b.button_group = cat_group
		var id: String = c.id
		b.pressed.connect(func() -> void: show_category(id))
		cats.add_child(b)
		_cat_buttons[id] = b
	_cat_title = Label.new()
	_cat_title.add_theme_font_size_override("font_size", 15)
	_cat_title.add_theme_color_override("font_color", UiStyle.ACCENT)
	box.add_child(_cat_title)

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
	scroll.custom_minimum_size = Vector2(0, 200)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)

	var foot := HBoxContainer.new()
	box.add_child(foot)
	_demolish_button = Button.new()
	_demolish_button.text = "Démolir un bâtiment"
	_demolish_button.icon = Icones.get_icon("demolir", 20)
	_demolish_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_demolish_button.toggle_mode = true
	_demolish_button.button_group = _item_group
	_demolish_button.pressed.connect(func() -> void: demolish_chosen.emit())
	foot.add_child(_demolish_button)
	var rules := Button.new()
	rules.text = "Règles"
	rules.icon = Icones.get_icon("details", 20)
	rules.tooltip_text = "Règles du bac à sable : accès à une voie, argent illimité"
	rules.toggle_mode = true
	rules.toggled.connect(func(on: bool) -> void: _rules_box.visible = on)
	foot.add_child(rules)

	_rules_box = VBoxContainer.new()
	_rules_box.visible = false
	box.add_child(_rules_box)
	var rl := Label.new()
	rl.text = "Règles du bac à sable"
	_rules_box.add_child(rl)
	_access_box = CheckBox.new()
	_access_box.text = "Accès à une voie obligatoire"
	_access_box.button_pressed = true
	_access_box.toggled.connect(func(_on: bool) -> void: _emit_rules())
	_rules_box.add_child(_access_box)
	_money_box = CheckBox.new()
	_money_box.text = "Argent illimité"
	_money_box.toggled.connect(func(_on: bool) -> void: _emit_rules())
	_rules_box.add_child(_money_box)

	_summary_label = Label.new()
	_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary_label.add_theme_font_size_override("font_size", 12)
	_summary_label.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
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
	_cat_title.text = (_cat_buttons[cat] as Button).tooltip_text
	if _vignettes:
		_vignettes.cancel_all()
	for b in _item_buttons:
		b.queue_free()
	_item_buttons.clear()
	if cat == "zones":
		_show_zones()
		return
	if cat == "blocs":
		_show_blocks()
		return
	if cat == Creations.CATEGORY:
		_show_creations()
		return
	_filters.visible = true
	var shown := 0
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	_list.add_child(grid)
	_item_buttons.append(grid)
	for id in BuildingCatalog.ids_in(cat, _region, _era):
		var t := BuildingCatalog.get_type(id)
		if _search != "" and not (String(t.name) + " " + String(t.desc)).to_lower().contains(_search):
			continue
		shown += 1
		grid.add_child(_card(id, String(CAT_ICONS.get(cat, "construire"))))
	_cat_title.text += "  ·  %d" % shown
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
	var tools := [["Poser", BlockEditor.Tool.BLOCK, "Un clic = un élément de la forme choisie, contre le sol ou contre un autre bloc. R : tourner."],
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
	# Formes : blocs, toits, ouvertures.
	var shape_group := ButtonGroup.new()
	for fam in [["formes", "Formes"], ["toits", "Toits"], ["ouvertures", "Portes et fenêtres"]]:
		var fl := Label.new()
		fl.text = fam[1]
		fl.add_theme_font_size_override("font_size", 12)
		_list.add_child(fl)
		_item_buttons.append(fl)
		var srow := HFlowContainer.new()
		_list.add_child(srow)
		_item_buttons.append(srow)
		for sh in BlocFormes.ORDER:
			var info: Dictionary = BlocFormes.INFO[sh]
			if info.fam != fam[0]:
				continue
			var sb := Button.new()
			sb.text = info.name
			sb.tooltip_text = info.desc
			sb.toggle_mode = true
			sb.button_group = shape_group
			sb.add_theme_font_size_override("font_size", 12)
			sb.button_pressed = sh == _block_shape
			var shid: int = sh
			sb.pressed.connect(func() -> void:
				_block_shape = shid
				block_shape_chosen.emit(shid))
			srow.add_child(sb)
	# Matériaux (textures), par famille.
	var frow := HBoxContainer.new()
	var flab := Label.new()
	flab.text = "Matériau :"
	frow.add_child(flab)
	var fam_opt := OptionButton.new()
	for f in BlocMateriaux.FAMILIES:
		fam_opt.add_item(f.name)
		fam_opt.set_item_metadata(fam_opt.item_count - 1, f.id)
		if f.id == _mat_family:
			fam_opt.select(fam_opt.item_count - 1)
	fam_opt.item_selected.connect(func(i: int) -> void:
		_mat_family = String(fam_opt.get_item_metadata(i))
		show_category("blocs"))
	frow.add_child(fam_opt)
	_list.add_child(frow)
	_item_buttons.append(frow)
	var grid := GridContainer.new()
	grid.columns = 8
	_list.add_child(grid)
	_item_buttons.append(grid)
	var mat_group := ButtonGroup.new()
	for i in BlockEditor.MATERIALS.size():
		var m: Dictionary = BlockEditor.MATERIALS[i]
		if _mat_family != "" and m.fam != _mat_family:
			continue
		var b := Button.new()
		b.custom_minimum_size = Vector2(38, 38)
		b.toggle_mode = true
		b.button_group = mat_group
		b.tooltip_text = "%s · %d € le bloc" % [m.name, m.price]
		b.icon = _material_icon(i)
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		for state in ["pressed", "hover_pressed"]:
			var sbx := StyleBoxFlat.new()
			sbx.bg_color = Color(1, 1, 1, 0.9)
			sbx.set_corner_radius_all(4)
			b.add_theme_stylebox_override(state, sbx)
		b.button_pressed = i == _block_material
		var mi := i
		b.pressed.connect(func() -> void:
			_block_material = mi
			block_material_chosen.emit(mi))
		grid.add_child(b)
	# Teintes.
	var tl := Label.new()
	tl.text = "Teinte (peinture) :"
	tl.add_theme_font_size_override("font_size", 12)
	_list.add_child(tl)
	_item_buttons.append(tl)
	var trow := HFlowContainer.new()
	_list.add_child(trow)
	_item_buttons.append(trow)
	var tint_group := ButtonGroup.new()
	for ti in BlocMateriaux.TINTS.size():
		var tb := Button.new()
		tb.custom_minimum_size = Vector2(22, 22)
		tb.toggle_mode = true
		tb.button_group = tint_group
		tb.tooltip_text = BlocMateriaux.TINT_NAMES[ti]
		var col: Color = BlocMateriaux.TINTS[ti]
		for state in ["normal", "hover", "pressed", "hover_pressed"]:
			var sbt := StyleBoxFlat.new()
			sbt.bg_color = col
			sbt.set_corner_radius_all(11)
			if ti == 0:
				sbt.bg_color = Color(0.85, 0.85, 0.85)
				sbt.set_border_width_all(2)
				sbt.border_color = Color(0.4, 0.4, 0.4)
			if state.contains("pressed"):
				sbt.set_border_width_all(3)
				sbt.border_color = Color.WHITE
			tb.add_theme_stylebox_override(state, sbt)
		tb.button_pressed = ti == _block_tint
		var tid := ti
		tb.pressed.connect(func() -> void:
			_block_tint = tid
			block_tint_chosen.emit(tid))
		trow.add_child(tb)
	# Enregistrer une construction comme bâtiment de « Mes créations ».
	_list.add_child(HSeparator.new())
	var crow := HBoxContainer.new()
	var cname := LineEdit.new()
	cname.placeholder_text = "Nom de la création"
	cname.text = _capture_name
	cname.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cname.text_changed.connect(func(txt: String) -> void:
		_capture_name = txt
		capture_name_changed.emit(txt))
	crow.add_child(cname)
	var cap := Button.new()
	cap.text = "Enregistrer"
	cap.tooltip_text = "Clic glissé autour de ta construction : elle devient un bâtiment de l'onglet Mes créations, à poser où tu veux."
	cap.toggle_mode = true
	cap.button_group = _item_group
	cap.pressed.connect(func() -> void: block_tool_chosen.emit(BlockEditor.Tool.CAPTURE))
	crow.add_child(cap)
	_list.add_child(crow)
	_item_buttons.append(crow)
	_block_label = Label.new()
	_block_label.add_theme_font_size_override("font_size", 12)
	_block_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_block_label.text = "Clic droit : retirer un bloc · Ctrl+Z : annuler"
	_list.add_child(_block_label)
	_item_buttons.append(_block_label)


func _material_icon(i: int) -> Texture2D:
	if not _icons.has(i):
		var img: Image = BlocMateriaux.image(i).duplicate()
		img.clear_mipmaps()
		img.resize(32, 32, Image.INTERPOLATE_BILINEAR)
		if BlocMateriaux.is_glass(i):
			# Le verre sur un fond sombre pour qu'il se voie.
			var bg := Image.create(32, 32, false, Image.FORMAT_RGBA8)
			bg.fill(Color(0.25, 0.3, 0.35))
			bg.blend_rect(img, Rect2i(0, 0, 32, 32), Vector2i.ZERO)
			img = bg
		_icons[i] = ImageTexture.create_from_image(img)
	return _icons[i]


func _show_creations() -> void:
	_filters.visible = false
	var ids := Creations.ids()
	if ids.is_empty():
		var none := Label.new()
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.text = "Aucune création pour l'instant. Construis avec l'Éditeur libre, puis « Enregistrer » et un clic glissé autour de ta construction."
		_list.add_child(none)
		_item_buttons.append(none)
		return
	for id in ids:
		var t := BuildingCatalog.get_type(id)
		var row := HBoxContainer.new()
		var b := Button.new()
		b.text = "%s  ·  %d × %d m  ·  %s" % [t.name, t.w, t.d, BuildingSystem.format_short(BuildingCatalog.cost(id))]
		b.tooltip_text = String(t.desc)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		b.toggle_mode = true
		b.button_group = _item_group
		var type_id: String = id
		b.pressed.connect(func() -> void: building_chosen.emit(type_id))
		row.add_child(b)
		var del := Button.new()
		del.text = "✕"
		del.tooltip_text = "Supprimer cette création de la bibliothèque (les exemplaires déjà posés restent)."
		del.pressed.connect(func() -> void:
			creation_deleted.emit(type_id)
			show_category(Creations.CATEGORY))
		row.add_child(del)
		_list.add_child(row)
		_item_buttons.append(row)


func set_block_info(text: String) -> void:
	if is_instance_valid(_block_label) and not _block_label.is_queued_for_deletion():
		_block_label.text = text + "\nClic droit : retirer un bloc · Ctrl+Z : annuler"


func set_zone_info(text: String) -> void:
	if is_instance_valid(_zone_label) and not _zone_label.is_queued_for_deletion():
		_zone_label.text = text


## Carte d'un bâtiment : vignette, nom, taille et prix. Clic : le poser.
func _card(id: String, fallback_icon: String) -> Button:
	var t := BuildingCatalog.get_type(id)
	var b := Button.new()
	b.custom_minimum_size = Vector2(168, 150)
	b.toggle_mode = true
	b.button_group = _item_group
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = "%s · %d × %d m · %s\n%s\nPrix : %s (hors terrassement)" % [t.name, t.w, t.d,
		BuildingSystem.format_short(BuildingCatalog.cost(id)), t.desc, BuildingSystem.format_money(BuildingCatalog.cost(id))]
	var sel := UiStyle.flat_box(Color(1, 0.82, 0.4, 0.16), 10, 6)
	sel.border_color = UiStyle.ACCENT
	sel.set_border_width_all(2)
	b.add_theme_stylebox_override("normal", UiStyle.flat_box(Color(1, 1, 1, 0.05), 10, 6))
	b.add_theme_stylebox_override("hover", UiStyle.flat_box(Color(1, 1, 1, 0.11), 10, 6))
	b.add_theme_stylebox_override("pressed", sel)
	b.add_theme_stylebox_override("hover_pressed", sel)
	var type_id := id
	b.pressed.connect(func() -> void: building_chosen.emit(type_id))
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(box)
	var pic := TextureRect.new()
	pic.custom_minimum_size = Vector2(156, 92)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.texture = Icones.get_icon(fallback_icon, 48, Color(1, 1, 1, 0.35))
	box.add_child(pic)
	if _vignettes:
		_vignettes.request(id, pic)
	var name_l := Label.new()
	name_l.text = String(t.name)
	name_l.clip_text = true
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_l.custom_minimum_size = Vector2(156, 0)
	name_l.add_theme_font_size_override("font_size", 13)
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(name_l)
	var meta := Label.new()
	meta.text = "%d × %d m  ·  %s" % [t.w, t.d, BuildingSystem.format_short(BuildingCatalog.cost(id))]
	meta.add_theme_font_size_override("font_size", 12)
	meta.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(meta)
	return b


func is_open() -> bool:
	return _panel.visible


func set_open(on: bool) -> void:
	_panel.visible = on


func toggle() -> void:
	set_open(not _panel.visible)


func set_growth(on: bool) -> void:
	_growth = on


## Plus rien de sélectionné dans le panneau (un autre outil a été choisi).
func clear_selection() -> void:
	var pressed := _item_group.get_pressed_button()
	if pressed:
		pressed.set_pressed_no_signal(false)


func set_money(text: String) -> void:
	_money_label.text = text.replace("Caisse : ", "")


func set_summary(text: String) -> void:
	_summary_label.text = text


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.physical_keycode == KEY_B:
		toggle()
