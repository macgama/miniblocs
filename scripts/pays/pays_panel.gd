class_name PaysPanel
extends CanvasLayer
## Panneau « Pays » (Maj+P) : caisse du pays, impôt national, dotations, et
## toutes les villes avec leur caisse, leur maire et les subventions.

signal focus_requested(pos: Vector3)

const W := 380.0
const H := 560.0

var pays: Pays
var view := "villes"
var _panel: PanelContainer
var _title: Label
var _body: VBoxContainer
var _scroll: ScrollContainer
var _tick := 0.0
var _montant := 1


func setup(p: Pays) -> void:
	pays = p
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
	icon.texture = Icones.get_icon("globe", 22, UiStyle.ACCENT)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	head.add_child(icon)
	_title = Label.new()
	_title.text = "Pays"
	_title.add_theme_font_size_override("font_size", 16)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	var x := UiStyle.icon_button("fermer", "Fermer", "Maj+P", 18, 32)
	x.pressed.connect(func() -> void: set_open(false))
	head.add_child(x)
	var tabs := HBoxContainer.new()
	outer.add_child(tabs)
	for spec in [["Villes", "villes"], ["Caisse du pays", "pays"], ["Virements", "journal"]]:
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


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.physical_keycode == KEY_P and k.shift_pressed and not k.ctrl_pressed and not k.alt_pressed:
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
	if _tick >= 1.5:
		_tick = 0.0
		if get_viewport().gui_get_focus_owner() is Slider or get_viewport().gui_get_focus_owner() is LineEdit:
			return
		var keep := _scroll.scroll_vertical
		refresh()
		_scroll.set_deferred("scroll_vertical", keep)


func refresh() -> void:
	if pays == null:
		return
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	_title.text = "Pays : " + pays.nom_pays()
	match view:
		"pays": _view_pays()
		"journal": _view_journal()
		_: _view_villes()


# --- Petits outils ---------------------------------------------------------------------

static func money(v: float) -> String:
	return BuildingSystem.format_money(roundi(v))


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


func _line(label: String, v: float, color := Color.WHITE) -> void:
	var r := _row()
	var a := Label.new()
	a.text = label
	a.add_theme_font_size_override("font_size", 12)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	a.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.add_child(a)
	var b := Label.new()
	b.text = money(v)
	b.add_theme_font_size_override("font_size", 12)
	b.add_theme_color_override("font_color", color)
	r.add_child(b)


func _button(t: String, cb: Callable, disabled := false, tip := "") -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.disabled = disabled
	b.tooltip_text = tip
	b.add_theme_font_size_override("font_size", 12)
	b.pressed.connect(cb)
	return b


func _row() -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 4)
	_body.add_child(r)
	return r


func _slider(label: String, v: float, lo: float, hi: float, step: float, fmt: Callable, cb: Callable) -> void:
	var r := _row()
	var a := Label.new()
	a.text = label
	a.custom_minimum_size = Vector2(150, 0)
	a.add_theme_font_size_override("font_size", 12)
	a.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.add_child(a)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = v
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.custom_minimum_size = Vector2(110, 0)
	r.add_child(s)
	var l := Label.new()
	l.text = fmt.call(v)
	l.custom_minimum_size = Vector2(50, 0)
	l.add_theme_font_size_override("font_size", 12)
	r.add_child(l)
	s.value_changed.connect(func(x: float) -> void:
		l.text = fmt.call(x)
		cb.call(x))


# --- Villes --------------------------------------------------------------------------------

func _view_villes() -> void:
	var cm := pays.communes
	if cm == null or cm.villages.is_empty():
		_text("Pas encore de ville : pose une Maison de commune pour fonder la première (Maj+M).")
		_text("Caisse du pays : %s" % _solde_txt(Pays.PAYS), false, 15)
		return
	_text("Caisse du pays : %s" % _solde_txt(Pays.PAYS), false, 15)
	_text("Chaque ville a sa propre caisse. Ce qui se construit sur son territoire est payé par elle ; ce qui se construit hors des villes est payé par le pays.", true, 11)
	var r := _row()
	var choix := Label.new()
	choix.text = "Ville gérée : %s%s" % [pays.nom_de(pays.selection), " (épinglée)" if pays.epingle else " (suit la caméra)"]
	choix.add_theme_font_size_override("font_size", 12)
	choix.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(choix)
	if pays.epingle:
		r.add_child(_button("Suivre la caméra", func() -> void:
			pays.liberer()
			refresh()))
	# Montant des subventions.
	var m := _row()
	var ml := Label.new()
	ml.text = "Montant des virements :"
	ml.add_theme_font_size_override("font_size", 12)
	m.add_child(ml)
	var opt := OptionButton.new()
	opt.focus_mode = Control.FOCUS_NONE
	for v in Pays.SUBVENTIONS:
		opt.add_item(money(v))
	opt.selected = clampi(_montant, 0, Pays.SUBVENTIONS.size() - 1)
	opt.item_selected.connect(func(i: int) -> void: _montant = i)
	m.add_child(opt)
	var ids: Array = cm.villages.keys()
	ids.sort()
	for vid in ids:
		_carte_ville(int(vid))


func _solde_txt(k: int) -> String:
	if pays.illimite():
		return "illimitée (Admin)"
	return money(pays.solde(k))


func _carte_ville(vid: int) -> void:
	var cm := pays.communes
	var v: Dictionary = cm.villages[vid]
	var st: Dictionary = cm.stats.get(vid, {})
	_body.add_child(HSeparator.new())
	var t := _text("%s%s" % [String(v.nom), "  ◀ gérée" if vid == pays.selection else ""], false, 14)
	t.add_theme_color_override("font_color", Communes.COULEURS[int(v.couleur) % Communes.COULEURS.size()])
	var pal := String(ReglagesPartie.PALIERS[int(st.get("palier", 0))].nom)
	var maire := pays.joueur_maire(vid)
	_text("%s · %d habitants · %d ha · maire : %s" % [pal, int(st.get("hab", 0)), int(st.get("ha", 0)),
		"toi" if maire else _maire_nom(vid)], true, 12)
	var b := pays.budget
	var e: Dictionary = b.etat_de(vid) if b != null else {}
	var dernier: Dictionary = e.get("dernier", {})
	var solde := float(dernier.get("solde", 0.0))
	var col := Color("7bd389") if pays.solde(vid) >= 0 else Color("ff6b6b")
	_line("Caisse", float(pays.solde(vid)), col)
	if not dernier.is_empty():
		_line("Solde par mois", solde, Color("7bd389") if solde >= 0.0 else Color("ff8c8c"))
	if b != null:
		var f := b.flux_ville(vid)
		_line("Dotation du pays par mois", float(f.dotation), Color(1, 1, 1, 0.8))
		_line("Contribution au pays par mois", -float(f.contribution), Color(1, 1, 1, 0.8))
	if bool(e.get("tutelle", false)):
		var l := _text("Sous tutelle du préfet : caisse dans le rouge trop longtemps.", false, 12)
		l.add_theme_color_override("font_color", Color("ff6b6b"))
	var r := _row()
	r.add_child(_button("Gérer", func() -> void:
		pays.choisir(vid, true)
		var c: Vector2 = v.c
		focus_requested.emit(Vector3(c.x, 0.0, c.y))
		refresh(), false, "Choisir cette ville : sa caisse s'affiche en haut, la touche M ouvre son budget."))
	var montant: int = Pays.SUBVENTIONS[_montant]
	r.add_child(_button("Subvention", func() -> void:
		pays.subventionner(vid, montant)
		refresh(), pays.illimite(), "Le pays verse %s à %s." % [money(montant), String(v.nom)]))
	r.add_child(_button("Reverser au pays", func() -> void:
		pays.reverser(vid, montant)
		refresh(), pays.illimite() or not maire, "%s verse %s au pays (seulement si tu en es le maire)." % [String(v.nom), money(montant)]))


func _maire_nom(vid: int) -> String:
	if Avis.instance != null and Avis.instance.has_method("maire_de"):
		var m: Dictionary = Avis.instance.call("maire_de", vid)
		return String(m.get("tete_nom", m.get("nom", "un autre")))
	return "un autre"


# --- Caisse du pays ---------------------------------------------------------------------------

func _view_pays() -> void:
	var r := _row()
	var l := Label.new()
	l.text = "Nom du pays :"
	l.add_theme_font_size_override("font_size", 12)
	r.add_child(l)
	var ed := LineEdit.new()
	ed.text = pays.nom_pays()
	ed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ed.text_submitted.connect(func(t: String) -> void:
		pays.nom = t.strip_edges()
		ed.release_focus()
		refresh())
	ed.focus_exited.connect(func() -> void: pays.nom = ed.text.strip_edges())
	r.add_child(ed)
	_text("Caisse du pays : %s" % _solde_txt(Pays.PAYS), false, 15)
	if not pays.illimite() and pays.solde(Pays.PAYS) <= 0:
		var w := _text("Le pays est à sec : il ne verse plus de dotation aux villes.", false, 12)
		w.add_theme_color_override("font_color", Color("ff6b6b"))
	_section("Décisions du pays")
	_slider("Impôt national (part des impôts des villes)", pays.taux_national, 0.0, Pays.TAUX_NATIONAL_MAX, 0.01,
		func(x: float) -> String: return "%d %%" % roundi(x * 100.0), pays.set_taux_national)
	_slider("Dotation par habitant", pays.dotation, 0.0, 2.0, 0.05,
		func(x: float) -> String: return "%d %%" % roundi(x * 100.0), pays.set_dotation)
	_text("Un impôt national élevé remplit la caisse du pays mais vide celles des villes. La dotation aide les petites villes à grandir.", true, 11)
	if pays.budget == null or not pays.a_des_villes():
		return
	var b := pays.budget.bilan_mensuel(Pays.PAYS)
	_section("Prévision par mois")
	for k in b.recettes:
		_line(k, float(b.recettes[k]), Color("7bd389"))
	for k in b.depenses:
		_line(k, -float(b.depenses[k]), Color("ff8c8c"))
	_line("Solde du mois", float(b.solde), Color("7bd389") if float(b.solde) >= 0.0 else Color("ff6b6b"))
	_text("Les voies tracées hors des villes sont au pays : il paie leur construction et leur entretien.", true, 11)


func _view_journal() -> void:
	if pays.journal.is_empty():
		_text("Aucun virement pour le moment.", true)
		return
	for i in range(pays.journal.size() - 1, -1, -1):
		var j: Dictionary = pays.journal[i]
		_text("Jour %d · %s : %s → %s, %s" % [int(j.jour), String(j.motif), pays.nom_de(int(j.de)), pays.nom_de(int(j.a)),
			money(float(j.montant))], false, 12)
