class_name StatsPanel
extends CanvasLayer
## Panneau « Statistiques » (Maj+I, menu Infos) : courbes dans le temps de chaque
## ville et du pays, tableau des chiffres du jour avec leur évolution sur 30 jours,
## et l'onglet Conseiller (problèmes repérés et quoi faire).

## Le conseiller propose d'ouvrir un panneau (id de la barre du bas : budget, avis…).
signal panneau_requested(id: String)

const W := 540.0
const H := 600.0
const PERIODES := [["30 jours", 30], ["1 an", 365], ["Toute la partie", -1]]
## Couleurs des villes quand on les compare (la première est celle du lieu choisi).
const PALETTE := [Color("ffd166"), Color("7cc7ff"), Color("9fe3b0"), Color("ff8a7a"), Color("c9a7ff"), Color("f5a3d0"), Color("b7c4bb")]
const NOMS_PANNEAUX := {"budget": "Budget (M)", "avis": "Avis (Y)", "construire": "Construire (B)", "trafic": "Trafic (Maj+L)",
	"dechets": "Déchets (X)", "reseaux": "Réseaux (O)", "services": "Services (Maj+U)", "cartes": "Cartes (N)", "lignes": "Lignes (L)",
	"pays": "Pays (Maj+P)", "production": "Production (P)", "objectifs": "Objectifs (Maj+J)"}

var stats: Statistiques
var view := "courbes"
var lieu := ""
var ind := "habitants"
var periode := 365
var comparer := false
var _panel: PanelContainer
var _title: Label
var _body: VBoxContainer
var _scroll: ScrollContainer
var _tab_conseil: Button
var _tab_courbes: Button


func setup(s: Statistiques) -> void:
	stats = s
	_build()
	stats.releve_fait.connect(func() -> void:
		if is_open():
			var keep := _scroll.scroll_vertical
			refresh()
			_scroll.set_deferred("scroll_vertical", keep)
		_maj_onglets())


func _build() -> void:
	layer = 6
	_panel = PanelContainer.new()
	UiStyle.place_right(_panel)
	_panel.offset_left = UiStyle.SIDE_RIGHT - W - 12.0
	_panel.custom_minimum_size = Vector2(W, 0)
	UiStyle.style_panel(_panel)
	_panel.visible = false
	add_child(_panel)
	var outer := VBoxContainer.new()
	_panel.add_child(outer)
	var head := HBoxContainer.new()
	outer.add_child(head)
	var icon := TextureRect.new()
	icon.texture = Icones.get_icon("courbe", 22, UiStyle.ACCENT)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	head.add_child(icon)
	_title = Label.new()
	_title.text = "Statistiques"
	_title.add_theme_font_size_override("font_size", 16)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	var x := UiStyle.icon_button("fermer", "Fermer", "Maj+I", 18, 32)
	x.pressed.connect(func() -> void: set_open(false))
	head.add_child(x)
	var tabs := HBoxContainer.new()
	outer.add_child(tabs)
	_tab_courbes = _onglet(tabs, "Courbes", "courbes")
	_tab_conseil = _onglet(tabs, "Conseiller", "conseiller")
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(W, H)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(_scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 4)
	# Place de la barre de défilement : rien ne passe dessous.
	var marge := MarginContainer.new()
	marge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	marge.add_theme_constant_override("margin_right", 14)
	_scroll.add_child(marge)
	marge.add_child(_body)


func _onglet(parent: Control, texte: String, v: String) -> Button:
	var b := Button.new()
	b.text = texte
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(func() -> void: show_view(v))
	parent.add_child(b)
	return b


func is_open() -> bool:
	return _panel.visible


func set_open(on: bool) -> void:
	_panel.visible = on
	if on:
		# Par défaut : la ville que l'on gère (ou le pays).
		if lieu == "" or not _lieu_connu(lieu):
			lieu = _lieu_gere()
		refresh()


func toggle() -> void:
	set_open(not _panel.visible)


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.physical_keycode == KEY_I and k.shift_pressed and not k.ctrl_pressed and not k.alt_pressed:
		toggle()
		get_viewport().set_input_as_handled()


func show_view(v: String) -> void:
	view = v
	if not is_open():
		set_open(true)
	else:
		refresh()
	_scroll.scroll_vertical = 0


func _lieu_gere() -> String:
	if stats.pays != null and stats.pays.a_des_villes() and stats.pays.selection != Pays.PAYS:
		return str(stats.pays.selection)
	return Statistiques.PAYS


func _lieu_connu(l: String) -> bool:
	for e in stats.lieux():
		if e[0] == l:
			return true
	return false


func _maj_onglets() -> void:
	var n := 0
	var g := 0
	for a in Conseiller.analyser(stats, lieu if lieu != "" else Statistiques.PAYS):
		if int(a.gravite) >= 1:
			n += 1
			g = maxi(g, int(a.gravite))
	_tab_conseil.text = "Conseiller" + (" (%d)" % n if n > 0 else "")
	_tab_conseil.add_theme_color_override("font_color", Conseiller.COULEURS[g] if n > 0 else UiStyle.TEXT)


func refresh() -> void:
	if stats == null:
		return
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	_tab_courbes.set_pressed_no_signal(view == "courbes")
	_tab_conseil.set_pressed_no_signal(view == "conseiller")
	_maj_onglets()
	_choix_lieu()
	if view == "conseiller":
		_view_conseiller()
	else:
		_view_courbes()


# --- Choix du lieu ---------------------------------------------------------------------------

func _choix_lieu() -> void:
	var lieux := stats.lieux()
	var row := HBoxContainer.new()
	_body.add_child(row)
	var l := Label.new()
	l.text = "Lieu :"
	row.add_child(l)
	var opt := OptionButton.new()
	opt.focus_mode = Control.FOCUS_NONE
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in lieux.size():
		var e: Array = lieux[i]
		opt.add_item(("Tout le pays : " if e[0] == Statistiques.PAYS else "") + String(e[1]), i)
		if e[0] == lieu:
			opt.select(i)
	opt.item_selected.connect(func(i: int) -> void:
		lieu = String(lieux[i][0])
		refresh())
	row.add_child(opt)


# --- Courbes -----------------------------------------------------------------------------------

func _view_courbes() -> void:
	var d := Statistiques.indicateur(ind)
	var national := String(d.get("portee", "ville")) == "pays"
	var l_serie := Statistiques.PAYS if national else lieu
	# Titre de la courbe et période.
	var row := HBoxContainer.new()
	_body.add_child(row)
	var t := Label.new()
	t.text = String(d.nom) + (" (tout le pays)" if national and lieu != Statistiques.PAYS else "")
	t.add_theme_font_size_override("font_size", 14)
	t.add_theme_color_override("font_color", UiStyle.ACCENT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.clip_text = true
	row.add_child(t)
	for p in PERIODES:
		var b := Button.new()
		b.text = p[0]
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.button_pressed = periode == int(p[1])
		var v := int(p[1])
		b.pressed.connect(func() -> void:
			periode = v
			refresh())
		row.add_child(b)
	var fin := float(stats.dernier_jour())
	var debut := NAN if periode < 0 else fin - periode + 1
	var series := []
	var villes := stats.lieux().filter(func(e) -> bool: return e[0] != Statistiques.PAYS)
	if comparer and not national and villes.size() > 1:
		var i := 0
		for e in villes:
			series.append({"nom": String(e[1]), "couleur": PALETTE[i % PALETTE.size()], "points": stats.serie(String(e[0]), ind, -1 if periode < 0 else int(debut))})
			i += 1
	else:
		series.append({"nom": _nom_lieu(l_serie), "couleur": PALETTE[0], "points": stats.serie(l_serie, ind, -1 if periode < 0 else int(debut))})
	var c := Courbe.new()
	c.custom_minimum_size = Vector2(0, 230)
	c.definir(ind, series, debut if periode > 0 else NAN, fin if periode > 0 else NAN)
	_body.add_child(c)
	if villes.size() > 1 and not national:
		var cb := CheckBox.new()
		cb.text = "Comparer les villes"
		cb.focus_mode = Control.FOCUS_NONE
		cb.button_pressed = comparer
		cb.toggled.connect(func(on: bool) -> void:
			comparer = on
			refresh())
		_body.add_child(cb)
		if comparer:
			var leg := HFlowContainer.new()
			_body.add_child(leg)
			for s in series:
				var ll := Label.new()
				ll.text = "● " + String(s.nom) + "   "
				ll.add_theme_color_override("font_color", s.couleur)
				ll.add_theme_font_size_override("font_size", 12)
				leg.add_child(ll)
	_body.add_child(HSeparator.new())
	var info := Label.new()
	info.text = "Chiffres du %s · évolution sur 30 jours · clic pour tracer la courbe" % Statistiques.date(fin)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_font_size_override("font_size", 12)
	info.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	_body.add_child(info)
	var pays_seul := false
	for di in Statistiques.INDICATEURS:
		var nat := String(di.portee) == "pays"
		if nat and lieu != Statistiques.PAYS and not pays_seul:
			pays_seul = true
			var sep := Label.new()
			sep.text = "Pour tout le pays"
			sep.add_theme_font_size_override("font_size", 12)
			sep.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
			_body.add_child(sep)
		_ligne(di, Statistiques.PAYS if nat else lieu)


func _nom_lieu(l: String) -> String:
	for e in stats.lieux():
		if e[0] == l:
			return String(e[1])
	return l


## Une ligne du tableau : icône, nom, valeur du jour, évolution colorée.
func _ligne(di: Dictionary, l: String) -> void:
	var id := String(di.id)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.toggle_mode = true
	b.button_pressed = id == ind
	b.custom_minimum_size = Vector2(0, 28)
	b.icon = Icones.get_icon(String(di.icone), 16, UiStyle.TEXT)
	b.text = String(di.nom)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 13)
	b.pressed.connect(func() -> void:
		ind = id
		refresh())
	_body.add_child(b)
	var v := stats.dernier(l, id)
	var ev := stats.evolution(l, id, 30)
	var box := HBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_right = -8
	box.alignment = BoxContainer.ALIGNMENT_END
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(box)
	var lv := Label.new()
	lv.text = Statistiques.format(id, v)
	lv.add_theme_font_size_override("font_size", 13)
	lv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(lv)
	var le := Label.new()
	le.custom_minimum_size = Vector2(86, 0)
	le.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	le.add_theme_font_size_override("font_size", 12)
	le.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not is_nan(ev) and absf(ev) >= 0.5:
		le.text = Statistiques.format_ecart(id, ev)
		var sens := int(di.sens)
		var col := UiStyle.TEXT_DIM
		if sens != 0:
			col = Conseiller.COULEURS[0] if (ev > 0.0) == (sens > 0) else Conseiller.COULEURS[2]
		le.add_theme_color_override("font_color", col)
	box.add_child(le)


# --- Conseiller --------------------------------------------------------------------------------

func _view_conseiller() -> void:
	var avis := Conseiller.analyser(stats, lieu)
	var intro := Label.new()
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_font_size_override("font_size", 12)
	intro.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	intro.text = "Ton conseiller relit les chiffres chaque jour. Il ne se trompe pas souvent, et il le sait." if not stats.historique.is_empty() \
		else "Le conseiller attend le premier relevé (à minuit, heure de la partie)."
	_body.add_child(intro)
	for a in avis:
		_carte(a)


func _carte(a: Dictionary) -> void:
	var g := int(a.gravite)
	var p := PanelContainer.new()
	var sb := UiStyle.flat_box(Color(Conseiller.COULEURS[g], 0.10), 8, 8)
	sb.border_color = Conseiller.COULEURS[g]
	sb.border_width_left = 4
	p.add_theme_stylebox_override("panel", sb)
	_body.add_child(p)
	var v := VBoxContainer.new()
	p.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var t := Label.new()
	t.text = String(a.titre)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.add_theme_font_size_override("font_size", 14)
	t.add_theme_color_override("font_color", Conseiller.COULEURS[g])
	head.add_child(t)
	var gl := Label.new()
	gl.text = Conseiller.GRAVITES[g]
	gl.add_theme_font_size_override("font_size", 11)
	gl.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	head.add_child(gl)
	for spec in [[String(a.texte), UiStyle.TEXT], ["→ " + String(a.conseil), UiStyle.TEXT_DIM]]:
		var l := Label.new()
		l.text = spec[0]
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_size_override("font_size", 13)
		l.add_theme_color_override("font_color", spec[1])
		v.add_child(l)
	var pid := String(a.panneau)
	if pid != "":
		var b := Button.new()
		b.text = "Ouvrir " + String(NOMS_PANNEAUX.get(pid, pid))
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_SHRINK_END
		b.pressed.connect(func() -> void: panneau_requested.emit(pid))
		v.add_child(b)
