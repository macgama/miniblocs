class_name ChoixVisuel
extends Button
## Liste de choix en images : remplace une OptionButton (liste de textes) par un
## bouton qui montre l'image et le nom du choix actuel, et qui ouvre une grille
## de vignettes (image + nom dessous, détails dans l'infobulle).
##
## Même façon de faire qu'une OptionButton : add_item(), select(), selected,
## get_selected_id(), clear(), signal item_selected(index).
## Les images viennent, dans cet ordre :
## - set_item_icon(i, texture) : une texture déjà prête (pictogramme, drapeau…) ;
## - add_item(texte, id, "icone") : une icône du jeu (Icones) ;
## - set_item_modele(i, sorte, id) : un vrai modèle du jeu (bâtiment, véhicule,
##   meuble, décor, animal…), voir Illustrations ;
## - illustrer : Callable(index, cible: TextureRect) appelé pour chaque image à
##   afficher (vignette 3D rendue plus tard par Vignettes, par exemple) ;
## - sinon une vignette dessinée d'office (Pictos.auto) : icône du thème
##   (`icone`) sur une couleur propre à chaque choix, ou une jauge pour les
##   listes graduées (nombres, niveaux).
## Voir docs/menus-en-images.md.

signal item_selected(index: int)

## Taille d'une vignette de la grille (image + nom).
var tile_size := Vector2(118, 112)
## Hauteur de l'image dans une vignette.
var image_height := 70.0
## Nombre maximal de colonnes de la grille.
var max_columns := 5
## Taille de l'image dans le bouton (petite d'office : le bouton garde la
## hauteur d'une liste de texte ; plus grande pour les outils de voies).
var face_image := Vector2(36, 24):
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
## Icône du thème (Icones) pour les vignettes dessinées d'office
## (vide : devinée d'après le nom de chaque choix, voir Pictos.icone_pour).
var icone := ""
## Vignettes d'office en jauge (1 : oui, 0 : non, -1 : oui si les choix sont des nombres).
var gradue := -1
## Sorte d'image (Illustrations) donnée par la métadonnée de chaque choix :
## avec « toit », un choix dont la métadonnée vaut "hip" montre le toit à quatre pans.
var modele_meta := ""
## Gardé pour remplacer une OptionButton sans rien changer (sans effet).
var fit_to_longest_item := false

var selected := -1:
	set(v):
		if v == selected or _dans_select:
			selected = v
			return
		_dans_select = true
		selected = v
		select(v)
		_dans_select = false
var _dans_select := false
var _tip_auto := ""
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


## Taille minimale : l'image du bouton et un nom lisible.
func _get_minimum_size() -> Vector2:
	var w := 0.0
	if _face_label != null and _face_label.text != "":
		var f := _face_label.get_theme_font("font")
		var fs := _face_label.get_theme_font_size("font_size")
		if f != null:
			w = minf(f.get_string_size(_face_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x, 170.0)
	return Vector2(face_image.x + 34.0 + w, face_image.y + 8.0)


# --- Même interface qu'une OptionButton -------------------------------------------------------

## Ajoute un choix. `icone` : nom d'une icône du jeu (Icones), facultatif.
func add_item(text: String, id := -1, icone := "") -> void:
	var tex: Texture2D = Icones.get_icon(icone, 64) if icone != "" and Icones.has_icon(icone) else null
	_items.append({"text": text, "id": id if id >= 0 else _items.size(), "icon": tex, "tip": "", "disabled": false,
		"meta": null, "modele": []})
	if selected < 0:
		select(0)
	_close()


func add_icon_item(tex: Texture2D, text: String, id := -1) -> void:
	add_item(text, id)
	set_item_icon(_items.size() - 1, tex)


func set_item_metadata(i: int, m: Variant) -> void:
	if i >= 0 and i < _items.size():
		_items[i].meta = m


func get_item_metadata(i: int) -> Variant:
	return _items[i].meta if i >= 0 and i < _items.size() else null


## Montre un vrai modèle du jeu pour le choix `i` (voir Illustrations.poser) :
## sorte = "batiment", "vehicule", "meuble", "decor", "animal", "style"…
func set_item_modele(i: int, sorte: String, id: String) -> void:
	if i >= 0 and i < _items.size():
		_items[i].modele = [sorte, id]
		if i == selected:
			_refresh_face()


## Prix affiché sous le nom de la tuile (piste CityRT 5), en couleur d'accent.
func set_item_prix(i: int, prix: String) -> void:
	if i >= 0 and i < _items.size():
		_items[i]["prix"] = prix


func get_item_prix(i: int) -> String:
	return String(_items[i].get("prix", "")) if i >= 0 and i < _items.size() else ""


func get_item_modele(i: int) -> Array:
	return _items[i].modele if i >= 0 and i < _items.size() else []


func show_popup() -> void:
	ouvrir()


func clear() -> void:
	_items.clear()
	_dans_select = true
	selected = -1
	_dans_select = false
	_face_label.text = ""
	_face_rect.texture = null
	_close()


func select(i: int) -> void:
	if i < 0 or i >= _items.size():
		if i == -1:
			_dans_select = true
			selected = -1
			_dans_select = false
		return
	_dans_select = true
	selected = i
	_dans_select = false
	_refresh_face()
	update_minimum_size()
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
	if infobulle != "":
		tooltip_text = infobulle
	elif tooltip_text == "" or tooltip_text == _tip_auto:
		tooltip_text = tip
	_tip_auto = tip
	_face_rect.texture = null
	_poser_image(selected, _face_rect)


## Pose l'image du choix `i` dans `cible` (voir l'ordre en tête du fichier).
func _poser_image(i: int, cible: TextureRect) -> void:
	var it: Dictionary = _items[i]
	if it.icon != null:
		cible.texture = it.icon
		return
	var m: Array = it.modele
	if m.size() == 2 and Illustrations.poser(String(m[0]), String(m[1]), cible):
		return
	if m.is_empty() and modele_meta != "" and it.meta is String and String(it.meta) != "" \
			and Illustrations.poser(modele_meta, String(it.meta), cible):
		return
	if illustrer.is_valid():
		illustrer.call(i, cible)
		return
	var ic := icone if icone != "" else Pictos.icone_pour(String(it.text))
	cible.texture = Pictos.auto(String(it.text), i, _items.size(), ic, _est_gradue())


func _est_gradue() -> bool:
	if gradue >= 0:
		return gradue == 1
	if _items.size() < 2:
		return false
	var n := 0
	for it in _items:
		var t := String(it.text)
		for ch in t:
			if ch >= "0" and ch <= "9":
				n += 1
				break
	return n * 10 >= _items.size() * 6


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
	if _items.size() > 24:
		var cherche := LineEdit.new()
		cherche.placeholder_text = "Chercher…"
		cherche.clear_button_enabled = true
		cherche.text_changed.connect(_filtrer)
		box.add_child(cherche)
		cherche.call_deferred("grab_focus")
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


## Ne garde que les vignettes dont le nom contient `t` (grandes listes).
func _filtrer(t: String) -> void:
	var q := t.strip_edges().to_lower()
	for i in _tiles.size():
		var nom := String(_items[i].text)
		(_tiles[i] as Button).visible = q == "" or nom.to_lower().contains(q) or tr(nom).to_lower().contains(q)


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
	_poser_image(i, img)
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
	var pl: Label = null
	if String(it.get("prix", "")) != "":
		l.max_lines_visible = 1
		pl = Label.new()
		pl.name = "Prix"
		pl.text = String(it.prix)
		pl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pl.clip_text = true
		pl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		pl.add_theme_font_size_override("font_size", 10)
		col.add_child(pl)
		b.tooltip_text += "\n" + String(it.prix)
	var ink := func() -> void:
		l.add_theme_color_override("font_color", UiStyle.ACCENT_INK if b.button_pressed else UiStyle.TEXT)
		if pl != null:
			pl.add_theme_color_override("font_color", UiStyle.ACCENT_INK if b.button_pressed else UiStyle.ACCENT)
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
