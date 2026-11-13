class_name PartiesPanel
extends Control
## Fenêtre « Parties sauvegardées » : liste, charger, supprimer, et (en jeu)
## sauvegarder sous un nouveau nom. Utilisée sur le globe et dans la partie.

signal load_chosen(slot_id: String)
signal save_as_requested(title: String)
signal closed

var _list: ItemList
var _info: Label
var _load_btn: Button
var _delete_btn: Button
var _name_edit: LineEdit
var _preview: TextureRect
var _rename_btn: Button
var _rename_edit: LineEdit
var _saves: Array[Dictionary] = []
var _confirm_delete := ""
var _allow_save := false


## allow_save : affiche la ligne « Sauvegarder sous » (en jeu).
func _init(allow_save := false) -> void:
	_allow_save = allow_save


func _ready() -> void:
	# Fond assombri plein écran (bloque les clics vers la carte), fenêtre centrée.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(860, 460)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.11, 0.13, 0.96)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var title := Label.new()
	title.text = "Parties sauvegardées"
	title.add_theme_font_size_override("font_size", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := Button.new()
	close.text = "Fermer (Échap)"
	close.pressed.connect(close_panel)
	head.add_child(close)

	# À gauche la liste, à droite l'aperçu de la partie choisie et sa fiche.
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)
	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(420, 280)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(func(_i: int) -> void: _on_select())
	_list.item_activated.connect(func(_i: int) -> void: _on_load())
	body.add_child(_list)
	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(384, 0)
	side.add_theme_constant_override("separation", 6)
	body.add_child(side)
	_preview = TextureRect.new()
	_preview.custom_minimum_size = Vector2(384, 216)
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var frame := PanelContainer.new()
	var fsb := StyleBoxFlat.new()
	fsb.bg_color = Color(0.05, 0.06, 0.07)
	fsb.set_corner_radius_all(6)
	frame.add_theme_stylebox_override("panel", fsb)
	frame.add_child(_preview)
	side.add_child(frame)
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.add_theme_font_size_override("font_size", 13)
	_info.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	_info.custom_minimum_size = Vector2(384, 0)
	side.add_child(_info)
	var rrow := HBoxContainer.new()
	side.add_child(rrow)
	_rename_edit = LineEdit.new()
	_rename_edit.placeholder_text = "Nouveau nom"
	_rename_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rename_edit.text_submitted.connect(func(_t: String) -> void: _on_rename())
	rrow.add_child(_rename_edit)
	_rename_btn = Button.new()
	_rename_btn.text = "Renommer"
	_rename_btn.pressed.connect(_on_rename)
	rrow.add_child(_rename_btn)

	var row := HBoxContainer.new()
	v.add_child(row)
	_load_btn = Button.new()
	_load_btn.text = "Charger"
	_load_btn.custom_minimum_size = Vector2(120, 36)
	_load_btn.pressed.connect(_on_load)
	row.add_child(_load_btn)
	_delete_btn = Button.new()
	_delete_btn.text = "Supprimer"
	_delete_btn.pressed.connect(_on_delete)
	row.add_child(_delete_btn)

	if _allow_save:
		v.add_child(HSeparator.new())
		var srow := HBoxContainer.new()
		v.add_child(srow)
		_name_edit = LineEdit.new()
		_name_edit.placeholder_text = "Nom de la nouvelle sauvegarde"
		_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_name_edit.text_submitted.connect(func(_t: String) -> void: _on_save_as())
		srow.add_child(_name_edit)
		var save := Button.new()
		save.text = "Sauvegarder sous ce nom"
		save.pressed.connect(_on_save_as)
		srow.add_child(save)
	refresh()


func refresh() -> void:
	_saves = SaveGame.list_saves()
	_list.clear()
	_confirm_delete = ""
	for m in _saves:
		var auto := String(m.id) == "sauvegarde-auto"
		var i := _list.add_item("%s%s   ·   %s" % ["⟳ " if auto else "", String(m.get("nom", m.id)), format_date(int(m.get("modifie", 0)))])
		if auto:
			_list.set_item_tooltip(i, "Sauvegarde automatique : écrite toutes les quelques minutes (Options > Jeu), elle n'écrase jamais tes parties.")
	if _saves.is_empty():
		_info.text = "Aucune partie sauvegardée pour l'instant. Une ville sans archives, c'est une ville sans soucis… jusqu'à la panne de courant. En jeu : F5 ou Échap > Sauvegarder."
		_preview.texture = null
	else:
		_list.select(0)
		_on_select()
	_update_buttons()


static func format_date(unix: int) -> String:
	if unix <= 0:
		return "date inconnue"
	var d := Time.get_datetime_dict_from_unix_time(unix + _utc_offset_s())
	return "%02d/%02d/%04d %02dh%02d" % [d.day, d.month, d.year, d.hour, d.minute]


static func _utc_offset_s() -> int:
	return int(Time.get_time_zone_from_system().get("bias", 0)) * 60


func _selected() -> Dictionary:
	var sel := _list.get_selected_items()
	if sel.is_empty() or sel[0] >= _saves.size():
		return {}
	return _saves[sel[0]]


func _on_select() -> void:
	_confirm_delete = ""
	var m := _selected()
	_preview.texture = null if m.is_empty() else SaveGame.load_preview(String(m.id))
	if _rename_edit:
		_rename_edit.text = "" if m.is_empty() else String(m.get("nom", ""))
	if m.is_empty():
		_info.text = ""
	else:
		var lieu: Dictionary = m.get("lieu", {})
		var txt := "Lieu : %s%.4f, %.4f" % ["%s, " % lieu.nom if String(lieu.get("nom", "")) != "" else "", float(lieu.get("lat", 0)), float(lieu.get("lon", 0))]
		var resume: Dictionary = m.get("resume", {})
		if not resume.is_empty():
			txt += "\n%d bâtiments · %d logements · réseau %s · %d blocs posés" % [int(resume.get("batiments", 0)), int(resume.get("logements", 0)),
				String(resume.get("reseau", "0 m")), int(resume.get("blocs", 0))]
		if int(resume.get("habitants", 0)) > 0:
			txt += "\n%d habitants" % int(resume.get("habitants", 0))
		txt += "\nCréée le %s · %d sauvegarde%s" % [format_date(int(m.get("cree", 0))), int(m.get("sauvegardes", 1)), "s" if int(m.get("sauvegardes", 1)) > 1 else ""]
		_info.text = txt
	_update_buttons()


func _update_buttons() -> void:
	var has := not _selected().is_empty()
	_load_btn.disabled = not has
	_delete_btn.disabled = not has
	if _rename_btn:
		_rename_btn.disabled = not has
	_delete_btn.text = "Confirmer la suppression" if _confirm_delete != "" else "Supprimer"


func _on_load() -> void:
	var m := _selected()
	if not m.is_empty():
		load_chosen.emit(String(m.id))


func _on_delete() -> void:
	var m := _selected()
	if m.is_empty():
		return
	if _confirm_delete != String(m.id):
		_confirm_delete = String(m.id)
		_info.text = "Supprimer « %s » ? Clique encore pour confirmer (définitif)." % m.get("nom", m.id)
		_update_buttons()
		return
	SaveGame.delete(String(m.id))
	refresh()


func _on_rename() -> void:
	var m := _selected()
	if m.is_empty() or _rename_edit.text.strip_edges() == "":
		return
	var keep := String(m.id)
	if SaveGame.rename(keep, _rename_edit.text):
		refresh()
		for i in _saves.size():
			if String(_saves[i].id) == keep:
				_list.select(i)
				_on_select()
	_rename_edit.release_focus()


func _on_save_as() -> void:
	var t := _name_edit.text.strip_edges()
	if t == "":
		_info.text = "Donne un nom à la sauvegarde."
		return
	save_as_requested.emit(t)
	_name_edit.text = ""
	_name_edit.release_focus()


func close_panel() -> void:
	closed.emit()
	queue_free()


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close_panel()
