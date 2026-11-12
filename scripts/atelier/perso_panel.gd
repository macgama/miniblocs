class_name PersoPanel
extends CanvasLayer
## Panneau « Personnaliser » d'un bâtiment du catalogue posé : couleurs (murs,
## toit, boiseries, volets, porte, vitres), forme du toit, étages, pente,
## variante. Les changements se voient tout de suite. Boutons : remettre
## d'origine, appliquer aux bâtiments du même modèle, ouvrir l'intérieur
## (reconstruit en murs fins et meublé) et enregistrer dans la banque.

signal opened_interior(plan_id: String)
signal saved_model(model_id: String)

const W := 360.0
const H := 600.0

var bs: BuildingSystem
var mob: Mobilier
var bid := -1

var _panel: PanelContainer
var _title: Label
var _body: VBoxContainer


func setup(b: BuildingSystem, m: Mobilier) -> void:
	bs = b
	mob = m
	layer = 6
	_panel = PanelContainer.new()
	UiStyle.place_right(_panel)
	_panel.custom_minimum_size = Vector2(W, 0)
	UiStyle.style_panel(_panel)
	_panel.visible = false
	add_child(_panel)
	var outer := VBoxContainer.new()
	_panel.add_child(outer)
	var head := HBoxContainer.new()
	outer.add_child(head)
	var ic := TextureRect.new()
	ic.texture = Icones.get_icon("peinture" if Icones.has_icon("peinture") else "construire", 22, UiStyle.ACCENT)
	ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	head.add_child(ic)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 16)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.clip_text = true
	head.add_child(_title)
	var x := UiStyle.icon_button("fermer", "Fermer", "", 18, 32)
	x.pressed.connect(func() -> void: set_open(false))
	head.add_child(x)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(W, H)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 4)
	scroll.add_child(_body)
	bs.removed.connect(func(b2: int) -> void:
		if b2 == bid and is_open() and not bs.buildings.has(b2):
			set_open(false))


func is_open() -> bool:
	return _panel != null and _panel.visible


func set_open(on: bool) -> void:
	_panel.visible = on


## Ouvre le panneau sur un bâtiment posé.
func edit(b: int) -> void:
	if not bs.buildings.has(b) or not Personnalisation.can_customize(String(bs.buildings[b].t)):
		return
	bid = b
	set_open(true)
	refresh()


func _perso() -> Dictionary:
	return bs.perso_of(bid).duplicate()


func _type_id() -> String:
	return String(bs.buildings[bid].t)


func _variant() -> int:
	return int(bs.buildings[bid].get("v", 0))


func _apply(perso: Dictionary, v := -1) -> void:
	bs.set_perso(bid, Personnalisation.clean(perso), v)


func refresh() -> void:
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	if not bs.buildings.has(bid):
		set_open(false)
		return
	var tid := _type_id()
	var t := BuildingCatalog.get_type(tid)
	var perso := _perso()
	_title.text = "Personnaliser : %s" % String(t.get("name", tid))
	_label(String(t.get("desc", "")), true, 12)
	_label("Les changements ne touchent que ce bâtiment. Ils sont gardés dans la partie.", true, 12)
	# --- Couleurs ---------------------------------------------------------------------
	_section("Couleurs")
	for key in Personnalisation.COLOR_ORDER:
		_color_row(String(key), tid, perso)
	# --- Forme --------------------------------------------------------------------------
	if Personnalisation.can_shape(tid):
		_section("Forme")
		var row := HBoxContainer.new()
		row.add_child(_small("Toit"))
		var roof := OptionButton.new()
		roof.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var base_roof := Personnalisation.base_roof(tid)
		roof.add_item("Comme le modèle (%s)" % String(Personnalisation.ROOFS.get(base_roof, base_roof)).to_lower())
		roof.set_item_metadata(0, "")
		for k in Personnalisation.ROOF_ORDER:
			roof.add_item(String(Personnalisation.ROOFS[k]))
			roof.set_item_metadata(roof.item_count - 1, k)
			if String(perso.get("toit", "")) == String(k):
				roof.select(roof.item_count - 1)
		roof.item_selected.connect(func(i: int) -> void:
			var p := _perso()
			var v := String(roof.get_item_metadata(i))
			if v == "":
				p.erase("toit")
			else:
				p["toit"] = v
			_apply(p))
		row.add_child(roof)
		_body.add_child(row)
		var frow := HBoxContainer.new()
		frow.add_child(_small("Étages"))
		var fl := SpinBox.new()
		fl.min_value = 1
		fl.max_value = Personnalisation.max_floors(tid)
		fl.value = int(perso.get("etages", Personnalisation.base_floors(tid)))
		fl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fl.value_changed.connect(func(v: float) -> void:
			var p := _perso()
			if int(v) == Personnalisation.base_floors(tid):
				p.erase("etages")
			else:
				p["etages"] = int(v)
			_apply(p))
		frow.add_child(fl)
		_body.add_child(frow)
		var prow := HBoxContainer.new()
		prow.add_child(_small("Pente du toit"))
		var sl := HSlider.new()
		sl.min_value = 0.5
		sl.max_value = 1.8
		sl.step = 0.05
		sl.value = float(perso.get("pente", 1.0))
		sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sl.drag_ended.connect(func(_c: bool) -> void:
			var p := _perso()
			if absf(sl.value - 1.0) < 0.03:
				p.erase("pente")
			else:
				p["pente"] = sl.value
			_apply(p))
		prow.add_child(sl)
		_body.add_child(prow)
	var n := BuildingCatalog.variants_of(tid)
	if n > 1:
		var vrow := HBoxContainer.new()
		vrow.add_child(_small("Variante du modèle"))
		var vs := SpinBox.new()
		vs.min_value = 0
		vs.max_value = n - 1
		vs.value = _variant()
		vs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vs.value_changed.connect(func(v: float) -> void:
			bs.set_perso(bid, _perso(), int(v))
			refresh.call_deferred())
		vrow.add_child(vs)
		_body.add_child(vrow)
	# --- Actions -------------------------------------------------------------------------
	_section("Et ensuite")
	var reset := _button("Remettre d'origine", "rafraichir", "Retire toute la personnalisation de ce bâtiment.")
	reset.pressed.connect(func() -> void:
		bs.set_perso(bid, {})
		refresh())
	var same := _same_model()
	if same.size() > 0:
		var all := _button("Appliquer aux %d autres « %s »" % [same.size(), String(t.get("name", tid))], "copier",
			"Donne les mêmes couleurs et la même forme à tous les bâtiments de ce modèle.")
		all.pressed.connect(func() -> void:
			var p := _perso()
			for o in same:
				bs.set_perso(int(o), p)
			bs.message.emit("%d bâtiment%s personnalisé%s comme celui-ci." % [same.size(), "s" if same.size() > 1 else "", "s" if same.size() > 1 else ""])
			refresh())
	if Conversion.can_open(tid) and mob != null:
		var open := _button("Ouvrir l'intérieur", "interieur",
			"Le bâtiment est reconstruit en murs fins avec ses couleurs, découpé en pièces et meublé dans un style proche du sien. "
			+ "On peut ensuite y entrer (V), le meubler et déplacer ses murs. Les petits ornements du modèle (corniches, cheminée…) disparaissent.")
		open.pressed.connect(func() -> void:
			var res := Conversion.open_interior(mob, bid)
			if not res.ok:
				bs.message.emit("Impossible d'ouvrir l'intérieur : %s." % String(res.error))
				return
			set_open(false)
			bs.message.emit("Intérieur ouvert : %s, meublé. Entre avec V, aménage avec l'onglet Intérieur." % mob.plan_name(String(res.id)))
			opened_interior.emit(String(res.id)))
	_section("Banque de modèles")
	var nrow := HBoxContainer.new()
	var nm := LineEdit.new()
	nm.placeholder_text = "Nom du modèle"
	nm.text = String(t.get("name", ""))
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nrow.add_child(nm)
	var save := Button.new()
	save.text = "Enregistrer"
	save.icon = Icones.get_icon("sauver", 18)
	save.tooltip_text = "Range ce bâtiment personnalisé dans ta banque de modèles, avec ses étiquettes (type, style, époque, couleurs)."
	save.pressed.connect(func() -> void:
		var r := BanqueModeles.save_building(bs, bid, nm.text, get_viewport())
		if r.ok:
			bs.message.emit("Modèle « %s » enregistré dans la banque." % String(r.nom))
			saved_model.emit(String(r.id))
		else:
			bs.message.emit(String(r.error)))
	nrow.add_child(save)
	_body.add_child(nrow)


func _same_model() -> Array:
	var out := []
	var tid := _type_id()
	for o in bs.buildings:
		if int(o) != bid and String(bs.buildings[o].t) == tid:
			out.append(o)
	return out


func _color_row(key: String, tid: String, perso: Dictionary) -> void:
	var cur := Personnalisation.color_of(tid, _variant(), perso, key)
	var head := HBoxContainer.new()
	var l := _small(String(Personnalisation.COLORS[key][0]))
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(l)
	var pick := ColorPickerButton.new()
	pick.color = cur
	pick.edit_alpha = false
	pick.custom_minimum_size = Vector2(44, 22)
	pick.tooltip_text = "Couleur libre"
	pick.popup_closed.connect(func() -> void: _pick(key, pick.color))
	head.add_child(pick)
	if perso.has(key):
		var undo := UiStyle.icon_button("retour", "Couleur du modèle", "", 14, 24)
		undo.pressed.connect(func() -> void:
			var p := _perso()
			p.erase(key)
			_apply(p)
			refresh())
		head.add_child(undo)
	_body.add_child(head)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 3)
	for hex in Personnalisation.swatches(tid, key):
		var b := Button.new()
		b.custom_minimum_size = Vector2(20, 20)
		b.focus_mode = Control.FOCUS_NONE
		b.tooltip_text = Personnalisation.color_name(Color(String(hex))).capitalize()
		var sb := UiStyle.flat_box(Color(String(hex)), 4, 0)
		if Color(String(hex)).to_html(false) == cur.to_html(false):
			sb.border_color = UiStyle.ACCENT
			sb.set_border_width_all(2)
		for st in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(st, sb)
		var c := Color(String(hex))
		b.pressed.connect(func() -> void: _pick(key, c))
		flow.add_child(b)
	_body.add_child(flow)


func _pick(key: String, c: Color) -> void:
	var p := _perso()
	p[key] = c.to_html(false)
	_apply(p)
	refresh.call_deferred()


func _section(t: String) -> void:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", UiStyle.ACCENT)
	_body.add_child(l)


func _label(t: String, dim := false, size := 13) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	if dim:
		l.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	_body.add_child(l)
	return l


func _small(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.custom_minimum_size = Vector2(110, 0)
	l.add_theme_font_size_override("font_size", 13)
	return l


func _button(t: String, icon: String, tip: String) -> Button:
	var b := Button.new()
	b.text = t
	if Icones.has_icon(icon):
		b.icon = Icones.get_icon(icon, 18)
	b.tooltip_text = tip
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.clip_text = true
	b.focus_mode = Control.FOCUS_NONE
	_body.add_child(b)
	return b
