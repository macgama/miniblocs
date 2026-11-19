class_name ChoixVisuel
extends Button
## Liste de choix en images : remplace une OptionButton (liste de textes) par un
## bouton qui montre l'image et le nom du choix actuel, et qui ouvre une grille
## de vignettes (image + nom dessous, détails dans l'infobulle).
##
## Même façon de faire qu'une OptionButton : add_item(), select(), selected,
## get_selected_id(), clear(), signal item_selected(index).
## Les images viennent de trois sources, au choix :
## - set_item_icon(i, texture) : une texture déjà prête (pictogramme, drapeau…) ;
## - add_item(texte, id, "icone") : une icône du jeu (Icones) ;
## - illustrer : Callable(index, cible: TextureRect) appelé pour chaque image à
##   afficher (vignette 3D rendue plus tard par Vignettes, par exemple).
## Voir docs/menus-en-images.md.

signal item_selected(index: int)

## Taille d'une vignette de la grille (image + nom).
var tile_size := Vector2(118, 112)
## Hauteur de l'image dans une vignette.
var image_height := 70.0
## Nombre maximal de colonnes de la grille.
var max_columns := 5
## Taille de l'image dans le bouton.
var face_image := Vector2(54, 38):
	set(v):
		face_image = v
		if _face_rect != null:
			_face_rect.custom_minimum_size = v
## Callable(index: int, cible: TextureRect) : pose l'image du choix `index`.
var illustrer: Callable
## Titre de la grille (vide : pas de titre).
var titre := ""
## Début ajouté au nom dans le bouton seulement (« Météo : » + « Pluie »).
var prefixe := ""
## Infobulle imposée au bouton (sinon : nom et détails du choix actuel).
var infobulle := ""

var selected := -1
var item_count: int:
	get:
		return _items.size()

## [{text, id, icon (Texture2D ou null), tip, disabled}]
var _items: Array = []
var _face_rect: TextureRect
var _face_label: Label
var _popup: PopupPanel
var _grid: GridContainer
var _tiles: Array = []


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	clip_text = true
	custom_minimum_size = Vector2(230, 44)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 4
	row.offset_right = -6
	row.add_theme_constant_override("separation", 6)
	add_child(row)
	_face_rect = TextureRect.new()
	_face_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_face_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_face_rect.custom_minimum_size = face_image
	_face_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_face_rect)
	_face_label = Label.new()
	_face_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_face_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_face_label.size_flags_vertical = Control.SIZE_FILL
	_face_label.clip_text = true
	_face_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_face_label.add_theme_font_size_override("font_size", 13)
	row.add_child(_face_label)
	var arrow := Label.new()
	arrow.text = "▾"
	arrow.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	arrow.size_flags_vertical = Control.SIZE_FILL
	row.add_child(arrow)
	pressed.connect(ouvrir)


# --- Même interface qu'une OptionButton -------------------------------------------------------

## Ajoute un choix. `icone` : nom d'une icône du jeu (Icones), facultatif.
func add_item(text: String, id := -1, icone := "") -> void:
	var tex: Texture2D = Icones.get_icon(icone, 64) if icone != "" and Icones.has_icon(icone) else null
	_items.append({"text": text, "id": id if id >= 0 else _items.size(), "icon": tex, "tip": "", "disabled": false})
	if selected < 0:
		select(0)
	_close()


func clear() -> void:
	_items.clear()
	selected = -1
	_face_label.text = ""
	_face_rect.texture = null
	_close()


func select(i: int) -> void:
	if i < 0 or i >= _items.size():
		return
	selected = i
	_refresh_face()
	for k in _tiles.size():
		(_tiles[k] as Button).set_pressed_no_signal(k == i)


func get_selected_id() -> int:
	return get_item_id(selected) if selected >= 0 else -1


func get_item_id(i: int) -> int:
	return int(_items[i].id) if i >= 0 and i < _items.size() else -1


func get_item_index(id: int) -> int:
	for i in _items.size():
		if int(_items[i].id) == id:
			return i
	return -1


func get_item_text(i: int) -> String:
	return String(_items[i].text) if i >= 0 and i < _items.size() else ""


func set_item_text(i: int, text: String) -> void:
	if i >= 0 and i < _items.size():
		_items[i].text = text
		if i == selected:
			_refresh_face()


func set_item_tooltip(i: int, tip: String) -> void:
	if i >= 0 and i < _items.size():
		_items[i].tip = tip
		if i == selected:
			_refresh_face()


func get_item_tooltip(i: int) -> String:
	return String(_items[i].tip) if i >= 0 and i < _items.size() else ""


func set_item_icon(i: int, tex: Texture2D) -> void:
	if i >= 0 and i < _items.size():
		_items[i].icon = tex
		if i == selected:
			_refresh_face()
		if i < _tiles.size():
			_tile_rect(i).texture = tex


func get_item_icon(i: int) -> Texture2D:
	return _items[i].icon if i >= 0 and i < _items.size() else null


func set_item_disabled(i: int, on: bool) -> void:
	if i >= 0 and i < _items.size():
		_items[i].disabled = on


func is_item_disabled(i: int) -> bool:
	return bool(_items[i].disabled) if i >= 0 and i < _items.size() else false


## Choisit comme le ferait un clic sur la vignette `i` (émet item_selected).
func choisir(i: int) -> void:
	if i < 0 or i >= _items.size() or is_item_disabled(i):
		return
	select(i)
	_close()
	item_selected.emit(i)


func est_ouvert() -> bool:
	return _popup != null and _popup.visible


# --- Bouton ------------------------------------------------------------------------------------

func _refresh_face() -> void:
	if selected < 0 or selected >= _items.size():
		return
	var it: Dictionary = _items[selected]
	_face_label.text = prefixe + String(it.text)
	var tip := prefixe + String(it.text)
	if String(it.tip) != "":
		tip += "\n" + String(it.tip)
	tooltip_text = infobulle if infobulle != "" else tip
	if it.icon != null:
		_face_rect.texture = it.icon
	else:
		_face_rect.texture = null
		if illustrer.is_valid():
			illustrer.call(selected, _face_rect)
	_face_rect.visible = _face_rect.texture != null or illustrer.is_valid()


# --- Grille ------------------------------------------------------------------------------------

## Ouvre la grille de vignettes au-dessus du bouton (ou dessous s'il n'y a pas la place).
func ouvrir() -> void:
	if _items.is_empty():
		return
	if _popup == null:
		_popup = PopupPanel.new()
		_popup.add_theme_stylebox_override("panel", UiStyle.panel_box(0.97, 12, 10))
		_popup.popup_hide.connect(func() -> void: set_pressed_no_signal(false))
		add_child(_popup)
	for c in _popup.get_children():
		_popup.remove_child(c)
		c.queue_free()
	_tiles.clear()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_popup.add_child(box)
	if titre != "":
		var t := Label.new()
		t.text = titre
		t.add_theme_color_override("font_color", UiStyle.ACCENT)
		t.add_theme_font_size_override("font_size", 14)
		box.add_child(t)
	var cols := clampi(ceili(sqrt(float(_items.size()) * 1.7)), 1, max_columns)
	_grid = GridContainer.new()
	_grid.columns = cols
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	var rows := ceili(float(_items.size()) / float(cols))
	var vp := get_viewport_rect().size
	var max_h := maxf(200.0, vp.y - 120.0)
	var grid_h := rows * tile_size.y + (rows - 1) * 6.0
	if grid_h > max_h:
		var sc := ScrollContainer.new()
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		sc.custom_minimum_size = Vector2(cols * tile_size.x + (cols - 1) * 6.0 + 12.0, max_h)
		sc.add_child(_grid)
		box.add_child(sc)
	else:
		box.add_child(_grid)
	for i in _items.size():
		_grid.add_child(_make_tile(i))
	_popup.reset_size()
	var sz := Vector2(_popup.get_contents_minimum_size())
	var r := Rect2(get_screen_position(), size)
	var pos := Vector2(r.position.x, r.position.y - sz.y - 6.0)
	if pos.y < 4.0:
		pos.y = r.end.y + 6.0
	pos.x = clampf(pos.x, 4.0, maxf(4.0, vp.x - sz.x - 4.0))
	_popup.popup(Rect2i(Vector2i(pos), Vector2i(sz)))
	set_pressed_no_signal(true)


func _close() -> void:
	if _popup != null and _popup.visible:
		_popup.hide()


func _make_tile(i: int) -> Button:
	var it: Dictionary = _items[i]
	var b := Button.new()
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = tile_size
	b.add_theme_stylebox_override("normal", UiStyle.flat_box(Color(1, 1, 1, 0.05), 9, 4))
	b.add_theme_stylebox_override("hover", UiStyle.flat_box(Color(1, 1, 1, 0.16), 9, 4))
	b.add_theme_stylebox_override("pressed", UiStyle.flat_box(Color(UiStyle.ACCENT, 0.9), 9, 4))
	b.add_theme_stylebox_override("hover_pressed", UiStyle.flat_box(UiStyle.ACCENT.lightened(0.15), 9, 4))
	b.add_theme_stylebox_override("disabled", UiStyle.flat_box(Color(0, 0, 0, 0.25), 9, 4))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.set_pressed_no_signal(i == selected)
	b.disabled = bool(it.disabled)
	var tip := String(it.text)
	if String(it.tip) != "":
		tip += "\n" + String(it.tip)
	b.tooltip_text = tip
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 4
	col.offset_top = 4
	col.offset_right = -4
	col.offset_bottom = -3
	col.add_theme_constant_override("separation", 2)
	b.add_child(col)
	var img := TextureRect.new()
	img.name = "Image"
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.custom_minimum_size = Vector2(0, image_height)
	col.add_child(img)
	if it.icon != null:
		img.texture = it.icon
	elif illustrer.is_valid():
		illustrer.call(i, img)
	var l := Label.new()
	l.text = String(it.text)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_vertical = Control.SIZE_EXPAND_FILL
	l.max_lines_visible = 2
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_constant_override("line_spacing", -2)
	col.add_child(l)
	var ink := func() -> void:
		l.add_theme_color_override("font_color", UiStyle.ACCENT_INK if b.button_pressed else UiStyle.TEXT)
	ink.call()
	b.toggled.connect(func(_on: bool) -> void: ink.call())
	b.pressed.connect(func() -> void: choisir(i))
	_tiles.append(b)
	return b


func _tile_rect(i: int) -> TextureRect:
	return (_tiles[i] as Button).find_child("Image", true, false) as TextureRect


## La vignette `i` de la grille ouverte (tests, captures).
func tuile(i: int) -> Button:
	return _tiles[i] if i >= 0 and i < _tiles.size() else null
