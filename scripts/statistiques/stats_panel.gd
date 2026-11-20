class_name StatsPanel
extends CanvasLayer
## Panneau « Statistiques » (Maj+I, menu Infos) : tableau de bord en vignettes
## (chiffre du jour, évolution sur 30 jours, mini-courbe), courbes dans le temps de
## chaque ville et du pays, pyramide des âges, et l'onglet Conseiller (portrait,
## problèmes repérés et quoi faire).

## Le conseiller propose d'ouvrir un panneau (id de la barre du bas : budget, avis…).
signal panneau_requested(id: String)

const W := 540.0
const H := 600.0
const PERIODES := [["30 jours", 30], ["1 an", 365], ["Toute la partie", -1]]
## Couleurs des villes quand on les compare (la première est celle du lieu choisi).
const PALETTE := [Color("ffd166"), Color("7cc7ff"), Color("9fe3b0"), Color("ff8a7a"), Color("c9a7ff"), Color("f5a3d0"), Color("b7c4bb")]
const NOMS_PANNEAUX := {"budget": "Budget (M)", "avis": "Avis (Y)", "construire": "Construire (B)", "trafic": "Trafic (Maj+L)",
	"dechets": "Déchets (X)", "reseaux": "Réseaux (O)", "services": "Services (Maj+U)", "cartes": "Cartes (N)", "lignes": "Lignes (L)",
	"pays": "Pays (Maj+P)", "production": "Production (P)", "objectifs": "Objectifs (Maj+J)",
	"sante": "Santé (F7)", "immobilier": "Immobilier (F11)", "urgences": "Urgences (U)", "education": "Éducation (Maj+K)"}

var stats: Statistiques
var view := "tableau"
## Onglets : [vue, nom, icône].
const ONGLETS := [["tableau", "Tableau de bord", "details"], ["courbes", "Courbes", "courbe"],
	["ages", "Âges", "habitants"], ["conseiller", "Conseiller", "mairie"]]
const COLONNES := 3
var lieu := ""
var ind := "habitants"
var periode := 365
var comparer := false
var _panel: PanelContainer
var _title: Label
var _body: VBoxContainer
var _scroll: ScrollContainer
var _tab_conseil: Button
var _tabs := {}


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
	for o in ONGLETS:
		_tabs[o[0]] = _onglet(tabs, String(o[1]), String(o[0]), String(o[2]))
	_tab_conseil = _tabs.conseiller
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


func _onglet(parent: Control, texte: String, v: String, icone: String) -> Button:
	var b := Button.new()
	b.text = texte
	b.icon = Icones.get_icon(icone, 16, UiStyle.TEXT)
	b.add_theme_font_size_override("font_size", 13)
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
	for v in _tabs:
		(_tabs[v] as Button).set_pressed_no_signal(view == v)
	_maj_onglets()
	_choix_lieu()
	match view:
		"conseiller":
			_view_conseiller()
		"tableau":
			_view_tableau()
		"ages":
			_view_ages()
		_:
			_view_courbes()


# --- Choix du lieu ---------------------------------------------------------------------------

func _choix_lieu() -> void:
	var lieux := stats.lieux()
	var row := HBoxContainer.new()
	_body.add_child(row)
	var l := Label.new()
	l.text = "Lieu :"
	row.add_child(l)
	var opt := ChoixVisuel.new()
	opt.icone = "village"
	opt.gradue = 0
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


# --- Tableau de bord ---------------------------------------------------------------------------

func _view_tableau() -> void:
	var fin := stats.dernier_jour()
	var info := Label.new()
	info.text = "Chiffres du %s · évolution sur 30 jours · clic sur une vignette pour sa courbe" % Statistiques.date(fin) \
		if not stats.historique.is_empty() else "Premier relevé à minuit (heure de la partie) : les vignettes se rempliront."
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_font_size_override("font_size", 12)
	info.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	_body.add_child(info)
	for national in [false, true]:
		if national:
			var sep := Label.new()
			sep.text = "Pour tout le pays" if lieu != Statistiques.PAYS else "Réseaux, santé, secours, circulation, climat"
			sep.add_theme_font_size_override("font_size", 13)
			sep.add_theme_color_override("font_color", UiStyle.ACCENT)
			_body.add_child(sep)
		var grille := GridContainer.new()
		grille.columns = COLONNES
		grille.add_theme_constant_override("h_separation", 6)
		grille.add_theme_constant_override("v_separation", 6)
		_body.add_child(grille)
		for di in Statistiques.INDICATEURS:
			if (String(di.portee) == "pays") != national:
				continue
			var l := Statistiques.PAYS if national else lieu
			if is_nan(stats.dernier(l, String(di.id))):
				continue
			grille.add_child(_vignette(di, l, fin))


## Une vignette : icône et nom, chiffre du jour, évolution colorée, mini-courbe sur 90 jours.
func _vignette(di: Dictionary, l: String, fin: int) -> Control:
	var id := String(di.id)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2((W - 30.0) / COLONNES - 6.0, 92)
	b.tooltip_text = String(di.nom) + " : clic pour la courbe"
	b.pressed.connect(func() -> void:
		ind = id
		show_view("courbes"))
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 6
	v.offset_right = -6
	v.offset_top = 4
	v.offset_bottom = -4
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(head)
	var ic := TextureRect.new()
	ic.texture = Icones.get_icon(String(di.icone), 14, UiStyle.TEXT_DIM)
	ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(ic)
	var nom := Label.new()
	nom.text = String(di.nom)
	nom.clip_text = true
	nom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nom.add_theme_font_size_override("font_size", 11)
	nom.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	nom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(nom)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(row)
	var val := Label.new()
	val.text = Statistiques.format(id, stats.dernier(l, id))
	val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	val.clip_text = true
	val.add_theme_font_size_override("font_size", 17)
	val.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(val)
	var ev := stats.evolution(l, id, 30)
	var col := UiStyle.TEXT_DIM
	if not is_nan(ev) and absf(ev) >= 0.5:
		var sens := int(di.sens)
		if sens != 0:
			col = Conseiller.COULEURS[0] if (ev > 0.0) == (sens > 0) else Conseiller.COULEURS[2]
		var le := Label.new()
		le.text = Statistiques.format_ecart(id, ev)
		le.add_theme_font_size_override("font_size", 11)
		le.add_theme_color_override("font_color", col)
		le.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(le)
	var mc := MiniCourbe.new()
	mc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mc.definir(stats.serie(l, id, fin - 90), col if col != UiStyle.TEXT_DIM else UiStyle.ACCENT)
	v.add_child(mc)
	return b


# --- Pyramide des âges -------------------------------------------------------------------------

func _view_ages() -> void:
	var t := stats.pyramide(lieu)
	var total := 0
	var jeunes := 0
	var vieux := 0
	for i in t.size():
		var n := int(t[i].h) + int(t[i].f)
		total += n
		if i < 2:
			jeunes += n
		if i >= 7:
			vieux += n
	var titre := Label.new()
	titre.text = "Pyramide des âges · " + _nom_lieu(lieu)
	titre.add_theme_font_size_override("font_size", 14)
	titre.add_theme_color_override("font_color", UiStyle.ACCENT)
	_body.add_child(titre)
	if total == 0:
		var vide := Label.new()
		vide.text = "Personne n'habite encore ici : la pyramide attend ses premiers bébés."
		vide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_body.add_child(vide)
		return
	var p := PyramideAges.new()
	p.definir(t)
	_body.add_child(p)
	var resume := Label.new()
	resume.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	resume.add_theme_font_size_override("font_size", 13)
	var am := stats.dernier(lieu, "age_moyen")
	resume.text = "%s habitants · moins de 20 ans : %d %% · 70 ans et plus : %d %%%s" % [Statistiques._milliers(total),
		roundi(100.0 * jeunes / total), roundi(100.0 * vieux / total), (" · âge moyen : %.1f ans" % am) if not is_nan(am) else ""]
	_body.add_child(resume)
	var forme := Label.new()
	forme.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	forme.add_theme_font_size_override("font_size", 12)
	forme.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	forme.text = forme_pyramide(t)
	_body.add_child(forme)


## Lecture de la forme : jeune (base large), vieillissante (sommet lourd) ou équilibrée.
static func forme_pyramide(t: Array) -> String:
	var total := 0
	var bas := 0
	var haut := 0
	for i in t.size():
		var n := int(t[i].h) + int(t[i].f)
		total += n
		if i < 3:
			bas += n
		elif i >= 6:
			haut += n
	if total == 0:
		return ""
	if bas > 2 * haut:
		return "Base large : une ville jeune. Les écoles vont avoir du travail, les maternités aussi."
	if haut > bas:
		return "Sommet lourd : la ville vieillit. Pense aux soins, et à attirer des familles."
	return "Forme équilibrée : chaque génération a sa place (pour l'instant)."


# --- Conseiller --------------------------------------------------------------------------------

func _view_conseiller() -> void:
	var avis := Conseiller.analyser(stats, lieu)
	var h := Conseiller.humeur(avis) if not stats.historique.is_empty() else 0
	var tete := HBoxContainer.new()
	tete.add_theme_constant_override("separation", 10)
	_body.add_child(tete)
	var portrait := TextureRect.new()
	portrait.texture = PortraitConseiller.get_portrait(h, 72)
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	portrait.tooltip_text = "Ton conseiller municipal : %s" % Langue.t(Conseiller.HUMEURS[h]).to_lower()
	tete.add_child(portrait)
	var cote := VBoxContainer.new()
	cote.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cote.alignment = BoxContainer.ALIGNMENT_CENTER
	tete.add_child(cote)
	var hum := Label.new()
	hum.text = "Humeur : %s" % Langue.t(Conseiller.HUMEURS[h])
	hum.add_theme_font_size_override("font_size", 14)
	hum.add_theme_color_override("font_color", Conseiller.COULEURS[h])
	cote.add_child(hum)
	var intro := Label.new()
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_font_size_override("font_size", 12)
	intro.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	intro.text = "Ton conseiller relit les chiffres chaque jour. Il ne se trompe pas souvent, et il le sait." if not stats.historique.is_empty() \
		else "Le conseiller attend le premier relevé (à minuit, heure de la partie)."
	cote.add_child(intro)
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
	var ic := TextureRect.new()
	ic.texture = Icones.get_icon(String(Conseiller.ICONES_THEMES.get(String(a.theme), "infos")), 18, Conseiller.COULEURS[g])
	ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	head.add_child(ic)
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
