class_name ServicesPanel
extends CanvasLayer
## Panneau « Services publics » (Maj+U) : couverture des écoles, hôpitaux et
## police, places restantes, habitants non couverts, carte colorée.

signal focus_requested(pos: Vector3)

const W := 348.0
const H := 540.0

var sp: ServicesPublics
var view := "ecole"
var _panel: PanelContainer
var _title: Label
var _body: VBoxContainer
var _scroll: ScrollContainer
var _tick := 0.0


func setup(s: ServicesPublics) -> void:
	sp = s
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
	icon.texture = Icones.get_icon("publics", 22, UiStyle.ACCENT)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	head.add_child(icon)
	_title = Label.new()
	_title.text = "Services publics"
	_title.add_theme_font_size_override("font_size", 16)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	var x := UiStyle.icon_button("fermer", "Fermer", "Maj+U", 18, 32)
	x.pressed.connect(func() -> void: set_open(false))
	head.add_child(x)
	var tabs := HBoxContainer.new()
	outer.add_child(tabs)
	for s in ServicesPublics.TYPES:
		var b := Button.new()
		b.text = String(ServicesPublics.NOMS[s])
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v: String = s
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
	elif sp != null and sp.calque() != "":
		Calques.eteindre()
		sp.montrer("")


func toggle() -> void:
	set_open(not _panel.visible)


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.physical_keycode == KEY_U and k.shift_pressed and not k.ctrl_pressed:
		toggle()
		get_viewport().set_input_as_handled()


func show_view(v: String) -> void:
	view = v
	# Le calque suit l'onglet s'il est affiché.
	if sp.calque() != "" and sp.calque() != v:
		Calques.afficher("services_" + v, true)
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
	if sp == null:
		return
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	_view_service(view)


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


func _swatch(c: Color) -> Texture2D:
	var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	img.fill(c)
	return ImageTexture.create_from_image(img)


static func pct(a: float, b: float) -> String:
	return "%d %%" % roundi(100.0 * a / b) if b > 0.0 else "—"


# --- Vue d'un service --------------------------------------------------------------------

func _view_service(s: String) -> void:
	_title.text = "Services publics · %s" % String(ServicesPublics.NOMS[s]).to_lower()
	var b := Button.new()
	b.toggle_mode = true
	b.button_pressed = sp.calque() == s
	b.text = "Voir la couverture sur la carte"
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func() -> void:
		Calques.afficher("services_" + s, sp.calque() != s)
		refresh())
	_body.add_child(b)
	var r := sp.bilan(s)
	var hab := float(r.get("hab", 0))
	_section("Habitants")
	if hab <= 0.0:
		_text("Personne n'habite encore la ville.", true)
	else:
		for row in [["Bien couverts", "couverts", ServicesPublics.COULEURS[0]], ["Service loin", "loin", ServicesPublics.COULEURS[1]],
				["Service saturé", "sature", ServicesPublics.COULEURS[2]], ["Sans service", "rien", ServicesPublics.COULEURS[3]]]:
			var hb := HBoxContainer.new()
			var tr := TextureRect.new()
			tr.texture = _swatch(row[2])
			tr.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
			hb.add_child(tr)
			var l := Label.new()
			l.text = "%s : %d (%s)" % [row[0], int(r.get(row[1], 0)), pct(float(r.get(row[1], 0)), hab)]
			l.add_theme_font_size_override("font_size", 13)
			hb.add_child(l)
			_body.add_child(hb)
	match s:
		"ecole":
			_text("Seuils de trajet (à pied ou en car) : maternelle et élémentaire 15 min, collège 25 min, lycée 40 min. Au-delà du double, l'élève reste sans école.", true, 11)
			var sans := 0
			for pid in sp.population.persons:
				var p: Dictionary = sp.population.persons[pid]
				if sp.population.stage(p) == "eleve" and int(p.sch) < 0:
					sans += 1
			if sans > 0:
				_text("%d élève%s sans école proche avec de la place." % [sans, "s" if sans > 1 else ""])
		"hopital":
			_text("Bien couvert : hôpital à moins de 30 min en voiture et un lit pour 333 habitants (3 ‰).", true, 11)
		"police":
			_text("Bien couvert : intervention en moins de 10 min et un agent pour %d habitants." % roundi(ServicesPublics.HAB_PAR_AGENT), true, 11)
			_text("Petits délits ce mois : %d (en tout : %d, %d sans intervention faute de commissariat)." % [int(sp.delits.mois), int(sp.delits.total), int(sp.delits.sans_police)])
	_section("%s (%d)" % [ServicesPublics.NOMS[s], (r.get("lieux", []) as Array).size()])
	if (r.get("lieux", []) as Array).is_empty():
		_text("Aucun bâtiment. Pose-en un depuis Construire → Services, au bord d'une route.", true)
	for e in r.get("lieux", []):
		var bt := Button.new()
		bt.focus_mode = Control.FOCUS_NONE
		bt.alignment = HORIZONTAL_ALIGNMENT_LEFT
		bt.add_theme_font_size_override("font_size", 12)
		bt.custom_minimum_size = Vector2(W - 30, 0)
		var unite: String = {"ecole": "places", "hopital": "lits", "police": "agents"}[s]
		var ligne := ""
		if s == "ecole":
			ligne = "%d / %d élèves" % [roundi(float(e.use)), int(e.cap)]
		else:
			ligne = "%d %s · %d habitants pour %d possibles" % [int(e.cap), unite if int(e.cap) > 1 else unite.trim_suffix("s"), roundi(float(e.use)), roundi(float(e.cap_hab))]
		var etat := ""
		if bool(e.ferme):
			etat = " · fermé (personnel)"
		elif float(e.charge) > 1.0:
			etat = " · saturé (%d %%)" % roundi(float(e.charge) * 100.0)
		bt.text = "%s\n%s%s" % [String(e.nom), ligne, etat]
		var col := ServicesPublics.COULEURS[0]
		if bool(e.ferme):
			col = ServicesPublics.COULEURS[3]
		elif float(e.charge) > 1.0:
			col = ServicesPublics.COULEURS[2]
		elif float(e.charge) > 0.85:
			col = ServicesPublics.COULEURS[1]
		bt.icon = _swatch(col)
		var pos := sp.population.building_pos(int(e.bid))
		bt.pressed.connect(func() -> void: focus_requested.emit(pos))
		bt.tooltip_text = "Clique pour y aller."
		_body.add_child(bt)
