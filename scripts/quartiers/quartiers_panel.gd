class_name QuartiersPanel
extends CanvasLayer
## Panneau « Quartiers » (Maj+Y) : les quartiers de la ville gérée, le pinceau
## pour les tracer, et les arrêtés municipaux de chacun (coûts, effets).
## Mairie perdue : tout est en lecture seule, le conseil élu décide.

signal focus_requested(pos: Vector3)

const W := 380.0
const H := 560.0
const VERT := Color("7bd389")
const ROUGE := Color("ff8c8c")
const TAILLES := ["1 îlot", "3 × 3", "5 × 5", "9 × 9"]

var q: Quartiers
var _panel: PanelContainer
var _title: Label
var _body: VBoxContainer
var _scroll: ScrollContainer
var _tick := 0.0


func setup(quartiers: Quartiers) -> void:
	q = quartiers
	_build()
	q.changed.connect(func() -> void:
		if is_open():
			_refresh_keep())


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
	icon.texture = Icones.get_icon("pancarte", 22, UiStyle.ACCENT)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	head.add_child(icon)
	_title = Label.new()
	_title.text = "Quartiers et arrêtés"
	_title.add_theme_font_size_override("font_size", 16)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	var x := UiStyle.icon_button("fermer", "Fermer", "Maj+Y", 18, 32)
	x.pressed.connect(func() -> void: set_open(false))
	head.add_child(x)
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
	if q != null:
		q.montre = on
		if not on:
			q.set_outil("")
		else:
			q.calculer_stats()
	if on:
		refresh()


func toggle() -> void:
	set_open(not _panel.visible)


func _input(event: InputEvent) -> void:
	# Maj+Y (Y seul reste le panneau Avis).
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.physical_keycode == KEY_Y and k.shift_pressed and not k.ctrl_pressed and not k.alt_pressed:
		if get_viewport().gui_get_focus_owner() is LineEdit:
			return
		toggle()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not is_open():
		return
	_tick += delta
	if _tick >= 3.0:
		_tick = 0.0
		if not (get_viewport().gui_get_focus_owner() is LineEdit):
			_refresh_keep()


func _refresh_keep() -> void:
	var keep := _scroll.scroll_vertical
	refresh()
	_scroll.set_deferred("scroll_vertical", keep)


func refresh() -> void:
	if q == null:
		return
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	if q.selection >= 0 and q.quartiers.has(q.selection):
		_view_quartier(q.selection)
	else:
		q.selection = -1
		_view_liste()


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


func _swatch(col: Color) -> ColorRect:
	var c := ColorRect.new()
	c.color = col
	c.custom_minimum_size = Vector2(12, 12)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return c


func _dire(t: String) -> void:
	if t != "":
		q.message.emit(t)


static func euros_mois(v: float) -> String:
	if v < 0.0:
		return "%s d'économie / mois" % BuildingSystem.format_money(roundi(-v))
	return "%s / mois" % BuildingSystem.format_money(roundi(v))


func _ville() -> int:
	return q._ville_choisie()


func _bandeau_mairie(vid: int) -> bool:
	if q.decide(vid):
		return false
	var l := _text("Tu n'es plus maire de %s : %s trace ses quartiers et décide de ses arrêtés, selon son programme. Reprends la mairie aux prochaines municipales (Y)." % [
		q.nom_ville(vid), q.maire_txt(vid)], false, 12)
	l.add_theme_color_override("font_color", ROUGE)
	return true


func _pinceau() -> void:
	var r := _row()
	var l := Label.new()
	l.text = "Pinceau :"
	l.add_theme_font_size_override("font_size", 12)
	r.add_child(l)
	for i in TAILLES.size():
		var b := _button(TAILLES[i], func() -> void:
			q.rayon = i
			q._survol_k = Vector2i(1 << 30, 0)
			refresh())
		b.toggle_mode = true
		b.button_pressed = q.rayon == i
		r.add_child(b)
	var g := _button("Gomme", func() -> void:
		q.set_outil("" if q.outil == "gommer" else "gommer")
		refresh(), "Retirer des îlots de leur quartier")
	g.toggle_mode = true
	g.button_pressed = q.outil == "gommer"
	r.add_child(g)


# --- Liste des quartiers ----------------------------------------------------------------

func _view_liste() -> void:
	var vid := _ville()
	_title.text = "Quartiers de %s" % q.nom_ville(vid)
	var bloque := _bandeau_mairie(vid)
	_text("Peins tes quartiers sur la carte (îlots de 50 × 50 m), donne-leur un nom, puis prends des arrêtés : zone 30, rues piétonnes, calme la nuit, tri obligatoire…", true, 12)
	if not bloque:
		var r := _row()
		r.add_child(_button("Nouveau quartier", func() -> void:
			var id := q.creer("", vid)
			if id >= 0:
				q.set_outil("peindre", id)
			refresh(), "Crée un quartier et prend le pinceau"))
		_pinceau()
	var ids := q.quartiers_de(vid)
	_section("Quartiers (%d)" % ids.size())
	if ids.is_empty():
		_text("Aucun quartier pour le moment.", true)
	var total := 0.0
	for qid in ids:
		var s: Dictionary = q.stats.get(qid, {})
		var n := (q.quartiers[qid].arretes as Dictionary).size()
		var c := q.cout_mois(qid)
		total += c
		var r := _row()
		r.add_child(_swatch(q.couleur(qid)))
		var b := _button(String(q.quartiers[qid].nom), func() -> void:
			q.selection = qid
			q._sale = true
			refresh(), "Ouvrir le quartier et ses arrêtés")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		r.add_child(b)
		if not bloque:
			var p := _button("Peindre", func() -> void:
				q.set_outil("peindre", qid)
				refresh())
			p.toggle_mode = true
			p.button_pressed = q.outil == "peindre" and q.outil_q == qid
			r.add_child(p)
		r.add_child(_button("Voir", func() -> void: _voir(qid)))
		_text("   %s ha · %d habitants · %d arrêté%s%s" % [_ha_txt(q.ha(qid)), int(s.get("hab", 0)), n, "s" if n > 1 else "",
			(" · " + euros_mois(c)) if n > 0 else ""], true, 11)
	if total != 0.0:
		_text("Arrêtés de la ville : %s" % euros_mois(total), false, 12)
	var j := q.journal.filter(func(e: Dictionary) -> bool: return int(e.vid) == vid)
	if not j.is_empty():
		_section("Dernières décisions")
		for e in j.slice(maxi(0, j.size() - 6)):
			_text("Jour %d : %s" % [int(e.jour), String(e.texte)], true, 11)


static func _ha_txt(h: float) -> String:
	return ("%.2f" % h).rstrip("0").rstrip(".").replace(".", ",")


func _voir(qid: int) -> void:
	var cs := q.cases_de(qid)
	if cs.is_empty():
		return
	var c := Vector2.ZERO
	for k in cs:
		c += Quartiers.centre_case(k)
	c /= cs.size()
	focus_requested.emit(Vector3(c.x, 0, c.y))


# --- Un quartier et ses arrêtés ------------------------------------------------------------

func _view_quartier(qid: int) -> void:
	var info: Dictionary = q.quartiers[qid]
	var vid := q.ville_de(qid)
	var bloque := not q.decide(vid)
	_title.text = String(info.nom)
	var top := _row()
	top.add_child(_button("← Quartiers", func() -> void:
		q.selection = -1
		q._sale = true
		refresh()))
	top.add_child(_button("Voir", func() -> void: _voir(qid)))
	if not bloque:
		var p := _button("Peindre", func() -> void:
			q.set_outil("" if q.outil == "peindre" and q.outil_q == qid else "peindre", qid)
			refresh())
		p.toggle_mode = true
		p.button_pressed = q.outil == "peindre" and q.outil_q == qid
		top.add_child(p)
		top.add_child(_button("Supprimer", func() -> void:
			_dire(q.supprimer(qid))
			refresh(), "Efface le quartier et ses arrêtés"))
	_bandeau_mairie(vid)
	if not bloque:
		_pinceau()
		var r := _row()
		var e := LineEdit.new()
		e.text = String(info.nom)
		e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		e.add_theme_font_size_override("font_size", 12)
		e.text_submitted.connect(func(t: String) -> void:
			_dire(q.renommer(qid, t))
			e.release_focus()
			refresh())
		r.add_child(e)
		r.add_child(_button("Renommer", func() -> void:
			_dire(q.renommer(qid, e.text))
			refresh()))
	var s: Dictionary = q.stats.get(qid, {})
	_text("%s · %s ha · %d habitants · %d logements · %d emplois" % [q.nom_ville(vid), _ha_txt(q.ha(qid)), int(s.get("hab", 0)),
		int(s.get("logements", 0)), int(s.get("emplois", 0))], true, 12)
	if int(s.get("hab", 0)) > 0:
		var sat := q.satisfaction(qid)
		_text("Bruit chez les habitants : %d dB le jour, %d dB la nuit%s" % [Nuisances.decibels(float(s.get("bruit", 0.0))),
			Nuisances.decibels(float(s.get("nuit", 0.0))), (" · satisfaction %d / 100" % roundi(sat)) if sat >= 0.0 else ""], true, 12)
	var h := q.ha(qid)
	var ar: Dictionary = info.arretes
	_section("Arrêtés en vigueur : %d%s" % [ar.size(), (" · " + euros_mois(q.cout_mois(qid))) if not ar.is_empty() else ""])
	if h <= 0.0:
		_text("Peins le quartier sur la carte pour pouvoir y prendre des arrêtés.", true)
	for a in Arretes.LISTE:
		var aid := String(a.id)
		var on := ar.has(aid)
		var r := _row()
		var ic := TextureRect.new()
		ic.texture = Icones.get_icon(String(a.icone), 18, VERT if on else UiStyle.TEXT_DIM)
		ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		r.add_child(ic)
		var cb := CheckButton.new()
		cb.text = String(a.nom)
		cb.button_pressed = on
		cb.focus_mode = Control.FOCUS_NONE
		cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cb.add_theme_font_size_override("font_size", 13)
		cb.disabled = bloque or h <= 0.0
		cb.tooltip_text = String(a.desc)
		cb.toggled.connect(func(v: bool) -> void:
			var why := q.adopter(qid, aid) if v else q.abroger(qid, aid)
			if why != "":
				_dire(why)
			else:
				_dire("« %s » %s à %s." % [String(a.nom), "en vigueur" if v else "abrogé", String(q.quartiers[qid].nom)])
			refresh.call_deferred())
		r.add_child(cb)
		var cout := "Mise en place %s · %s" % [BuildingSystem.format_money(Arretes.cout_pose(aid, h)), euros_mois(Arretes.cout_mois(aid, h))]
		if on:
			cout = "Depuis le jour %d · %s" % [int(ar[aid]), euros_mois(Arretes.cout_mois(aid, h))]
		_text("   %s" % String(a.desc), true, 11)
		var l := _text("   %s · %s" % [" · ".join(a.effets), cout], false, 11)
		l.add_theme_color_override("font_color", VERT if on else UiStyle.TEXT_DIM)
		var ex := Arretes.exclut(aid)
		if not on and ex != "" and ar.has(ex):
			_text("   Incompatible avec « %s »." % Arretes.nom(ex), true, 11)
