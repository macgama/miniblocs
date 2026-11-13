class_name ObjectifsPanel
extends CanvasLayer
## Panneau « Objectifs » (Maj+J) : réputation du pays, missions en cours, rang de
## chaque ville (et ce qui manque pour monter), succès.

signal focus_requested(pos: Vector3)

const W := 380.0
const H := 560.0
const VERT := Color("7bd389")
const ROUGE := Color("ff8c8c")

var obj: Objectifs
var view := "missions"
var _panel: PanelContainer
var _title: Label
var _body: VBoxContainer
var _scroll: ScrollContainer
var _tick := 0.0


func setup(o: Objectifs) -> void:
	obj = o
	_build()


func _build() -> void:
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
	var icon := TextureRect.new()
	icon.texture = Icones.get_icon("trophee", 22, UiStyle.ACCENT)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	head.add_child(icon)
	_title = Label.new()
	_title.text = "Objectifs"
	_title.add_theme_font_size_override("font_size", 16)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	var x := UiStyle.icon_button("fermer", "Fermer", "Maj+J", 18, 32)
	x.pressed.connect(func() -> void: set_open(false))
	head.add_child(x)
	var tabs := HBoxContainer.new()
	outer.add_child(tabs)
	for spec in [["Missions", "missions"], ["Villes", "villes"], ["Succès", "succes"]]:
		var b := Button.new()
		b.text = spec[0]
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v: String = spec[1]
		b.pressed.connect(func() -> void: show_view(v))
		tabs.add_child(b)
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(W, H)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(_scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 3)
	_scroll.add_child(_body)


func is_open() -> bool:
	return _panel.visible


func set_open(on: bool) -> void:
	_panel.visible = on
	if on:
		refresh()


func toggle() -> void:
	set_open(not _panel.visible)


func _input(event: InputEvent) -> void:
	# Maj+J (J seul reste l'outil Carrefour).
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.physical_keycode == KEY_J and k.shift_pressed and not k.ctrl_pressed and not k.alt_pressed:
		if get_viewport().gui_get_focus_owner() is LineEdit:
			return
		toggle()
		get_viewport().set_input_as_handled()


func show_view(v: String) -> void:
	view = v
	refresh()
	_scroll.scroll_vertical = 0


func _process(delta: float) -> void:
	if not is_open():
		return
	_tick += delta
	if _tick >= 2.0:
		_tick = 0.0
		var keep := _scroll.scroll_vertical
		refresh()
		_scroll.set_deferred("scroll_vertical", keep)


func refresh() -> void:
	if obj == null:
		return
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	_title.text = "Objectifs du pays"
	_reputation()
	match view:
		"villes": _view_villes()
		"succes": _view_succes()
		_: _view_missions()


# --- Petits outils ---------------------------------------------------------------------

func _text(t: String, dim := false, size := 13) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(W - 30, 0)
	l.add_theme_font_size_override("font_size", size)
	if dim:
		l.add_theme_color_override("font_color", Color(1, 1, 1, 0.65))
	_body.add_child(l)
	return l


func _section(t: String) -> void:
	_body.add_child(HSeparator.new())
	var l := _text(t, false, 15)
	l.add_theme_color_override("font_color", UiStyle.ACCENT)


func _row() -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 4)
	_body.add_child(r)
	return r


func _button(t: String, cb: Callable, tip := "") -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = tip
	b.add_theme_font_size_override("font_size", 12)
	b.pressed.connect(cb)
	return b


func _bar(v: float) -> void:
	var p := ProgressBar.new()
	p.min_value = 0.0
	p.max_value = 1.0
	p.value = clampf(v, 0.0, 1.0)
	p.show_percentage = false
	p.custom_minimum_size = Vector2(W - 30, 6)
	_body.add_child(p)


static func etoiles_txt(n: int) -> String:
	return "★".repeat(n) + "☆".repeat(5 - n)


func _reputation() -> void:
	var r := _row()
	var a := Label.new()
	a.text = "Réputation du pays : %s  %d / 100" % [etoiles_txt(obj.etoiles()), roundi(obj.reputation)]
	a.add_theme_font_size_override("font_size", 14)
	a.add_theme_color_override("font_color", Color("ffd166"))
	r.add_child(a)
	var bonus := Objectifs.bonus_taux()
	_text("Missions, rangs des villes et succès la font monter ; missions ratées, tutelle et mairies perdues la font baisser.%s" % (
		" Bonus : emprunts à −%.2f point." % (bonus * 100.0) if bonus > 0.0 else " Au-dessus de 20, les emprunts deviennent moins chers."), true, 11)


# --- Missions --------------------------------------------------------------------------

func _view_missions() -> void:
	if obj.communes == null or obj.communes.villages.is_empty():
		_section("Missions du pays")
		_text("Fonde ta première ville (une Maison de commune, Maj+M) : le pays te confiera alors ses missions.")
		return
	_section("Missions en cours (%d / %d)" % [obj.missions.size(), Objectifs.MISSIONS_MAX])
	if obj.missions.is_empty():
		_text("Pas de mission pour le moment : de nouvelles arrivent chaque jour.", true)
	var d := obj.jour()
	for m in obj.missions:
		_body.add_child(HSeparator.new())
		_text(String(m.texte), false, 13)
		var reste := int(m.fin) - d
		var duree := maxi(1, int(m.fin) - int(m.debut))
		_text("%s · encore %d jour%s · prime %s, réputation +%d" % [obj.progres(m), maxi(reste, 0), "s" if reste > 1 else "",
			BuildingSystem.format_money(int(m.prime)), roundi(float(m.rep))], true, 11)
		_bar(1.0 - float(maxi(reste, 0)) / float(duree))
		var r := _row()
		var vid := int(m.vid)
		if vid >= 0 and obj.communes.villages.has(vid):
			var c: Vector2 = obj.communes.villages[vid].c
			r.add_child(_button("Voir la ville", func() -> void: focus_requested.emit(Vector3(c.x, 0.0, c.y))))
		var id := int(m.id)
		r.add_child(_button("Abandonner", func() -> void:
			obj.abandonner(id)
			refresh(), "Une autre mission la remplace demain (réputation −1)."))
	if not obj.historique.is_empty():
		_section("Dernières missions")
		var h: Array = obj.historique.duplicate()
		h.reverse()
		for e in h.slice(0, 8):
			var l := _text("%s %s" % ["✔" if bool(e.reussie) else "✘", String(e.texte)], false, 12)
			l.add_theme_color_override("font_color", VERT if bool(e.reussie) else ROUGE)
	_text("Réussies : %d." % obj.reussies, true, 11)


# --- Rangs des villes ------------------------------------------------------------------

func _view_villes() -> void:
	var cm := obj.communes
	if cm == null or cm.villages.is_empty():
		_section("Rangs des villes")
		_text("Pas encore de ville.")
		return
	_section("Rangs des villes")
	_text("Chaque rang demande des habitants, des habitants contents et des services. Il rapporte une prime au pays et ne se perd jamais.", true, 11)
	var ids: Array = cm.villages.keys()
	ids.sort()
	for vid in ids:
		var v := int(vid)
		_body.add_child(HSeparator.new())
		var i := obj.palier_de(v)
		var t := _text("%s : %s" % [String(cm.villages[v].nom), String(Objectifs.PALIERS[i].nom)], false, 14)
		t.add_theme_color_override("font_color", Communes.COULEURS[int(cm.villages[v].couleur) % Communes.COULEURS.size()])
		if i + 1 >= Objectifs.PALIERS.size():
			_text("Rang le plus haut atteint.", true, 12)
			continue
		var p: Dictionary = Objectifs.PALIERS[i + 1]
		var hab := int(cm.stats.get(v, {}).get("hab", 0))
		_text("Prochain rang : %s (prime %s)" % [String(p.nom), BuildingSystem.format_money(ReglagesPartie.prix(int(p.prime)))], false, 12)
		_bar(float(hab) / maxf(1.0, float(p.hab)))
		var manque := obj.manques(v)
		if manque.is_empty():
			_text("Tout est prêt : le rang arrive demain.", false, 12).add_theme_color_override("font_color", VERT)
		else:
			_text("Il manque : " + ", ".join(manque) + ".", true, 12)
		var c: Vector2 = cm.villages[v].c
		_row().add_child(_button("Voir la ville", func() -> void: focus_requested.emit(Vector3(c.x, 0.0, c.y))))


# --- Succès ----------------------------------------------------------------------------

func _view_succes() -> void:
	_section("Succès (%d / %d)" % [obj.succes.size(), Objectifs.SUCCES.size()])
	for id in Objectifs.SUCCES:
		var ok := obj.succes.has(id)
		var l := _text("%s %s" % ["🏆" if ok else "·", String(Objectifs.SUCCES[id][0])], false, 13)
		if not ok:
			l.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
		_text(String(Objectifs.SUCCES[id][1]), true, 11)
