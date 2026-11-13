class_name AvisPanel
extends CanvasLayer
## Panneau « Avis » (touche Y, ou clic sur la satisfaction en haut) :
##
## - Avis : satisfaction moyenne et sa courbe, note de chaque thème (emploi,
##   logement, écoles et santé, environnement, transports, impôts…) avec ce
##   qui pèse le plus, effets en cours (promesses, manifestations).
## - Quartiers : satisfaction par quartier, carte de couleur sur la ville.
## - Paroles : ce que disent quelques habitants (les plus mécontents d'abord).
## - Élections : maire, date du vote, bilan des promesses, campagne (listes,
##   sondage, tes promesses), résultats.
## - Manifs : manifestations en cours et réponses (négocier, ignorer, police).

signal focus_requested(pos: Vector3)
signal person_requested(pid: int)

const W := 380.0
const H := 560.0

var avis: Avis
var carte: AvisCarte
var view := "avis"
var _panel: PanelContainer
var _body: VBoxContainer
var _scroll: ScrollContainer
var _tabs := {}
var _tick := 0.0
var _dirty := false


func setup(a: Avis, c: AvisCarte = null) -> void:
	avis = a
	carte = c
	layer = 6
	_panel = PanelContainer.new()
	_panel.name = "PanneauAvis"
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
	icon.texture = Icones.get_icon("urne", 22, UiStyle.ACCENT)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	head.add_child(icon)
	var title := Label.new()
	title.text = "Avis des habitants"
	title.add_theme_font_size_override("font_size", 16)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var x := UiStyle.icon_button("fermer", "Fermer", "Y", 18, 32)
	x.pressed.connect(func() -> void: set_open(false))
	head.add_child(x)
	var tabs := HBoxContainer.new()
	outer.add_child(tabs)
	for spec in [["Avis", "avis", "sourire"], ["Quartiers", "quartiers", "lieu"], ["Paroles", "paroles", "habitants"],
			["Élections", "elections", "urne"], ["Manifs", "manifs", "pancarte"]]:
		var b := Button.new()
		b.text = spec[0]
		b.icon = Icones.get_icon(spec[2], 16)
		b.focus_mode = Control.FOCUS_NONE
		b.toggle_mode = true
		b.add_theme_font_size_override("font_size", 11)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v: String = spec[1]
		b.pressed.connect(func() -> void: show_view(v))
		tabs.add_child(b)
		_tabs[v] = b
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(W, H)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(_scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 4)
	_scroll.add_child(_body)
	avis.changed.connect(func() -> void: _dirty = true)


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
	if k and k.pressed and not k.echo and k.physical_keycode == KEY_Y and not k.shift_pressed and not k.ctrl_pressed and not k.alt_pressed:
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
	# Rafraîchi quand quelque chose change, et toutes les 3 s (sauf saisie en cours).
	if (_dirty and _tick >= 0.5) or _tick >= 3.0:
		if view == "elections" and get_viewport().gui_get_focus_owner() is LineEdit:
			return
		_tick = 0.0
		_dirty = false
		var keep := _scroll.scroll_vertical
		refresh()
		_scroll.set_deferred("scroll_vertical", keep)


func refresh() -> void:
	if avis == null:
		return
	for v in _tabs:
		(_tabs[v] as Button).set_pressed_no_signal(v == view)
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	if avis.population == null or avis.population.persons.is_empty():
		_section("Personne n'habite encore ici", "habitants")
		_text("Construis des logements (Construire → Logement) : les habitants donneront leur avis dès leur arrivée. Les élections municipales commencent à %d habitants." % Elections.MIN_HABITANTS, true)
		return
	match view:
		"quartiers":
			_view_quartiers()
		"paroles":
			_view_paroles()
		"elections":
			_view_elections()
		"manifs":
			_view_manifs()
		_:
			_view_avis()


# --- Petits outils -------------------------------------------------------------------

func _text(t: String, dim := false, size := 13, color := Color.TRANSPARENT, parent: Control = null) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(W - 30, 0) if parent == null else Vector2.ZERO
	l.add_theme_font_size_override("font_size", size)
	if color.a > 0.0:
		l.add_theme_color_override("font_color", color)
	elif dim:
		l.add_theme_color_override("font_color", Color(1, 1, 1, 0.65))
	(parent if parent != null else _body).add_child(l)
	return l


func _section(t: String, icon := "") -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	if icon != "":
		var ic := TextureRect.new()
		ic.texture = Icones.get_icon(icon, 18, UiStyle.ACCENT)
		ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		h.add_child(ic)
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", UiStyle.ACCENT)
	h.add_child(l)
	_body.add_child(h)


func _button(text: String, icon: String, cb: Callable, tip := "", enabled := true, parent: Control = null) -> Button:
	var b := Button.new()
	b.text = text
	if icon != "":
		b.icon = Icones.get_icon(icon, 18)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = tip
	b.disabled = not enabled
	b.add_theme_font_size_override("font_size", 13)
	b.pressed.connect(cb)
	(parent if parent != null else _body).add_child(b)
	return b


## Couleur d'une note : rouge (0) → jaune (50) → vert (100).
static func couleur(note: float) -> Color:
	var t := clampf(note / 100.0, 0.0, 1.0)
	if t < 0.5:
		return Color("ef476f").lerp(Color("ffd166"), t * 2.0)
	return Color("ffd166").lerp(Color("06d6a0"), (t - 0.5) * 2.0)


## Barre de note (0-100) avec son chiffre.
func _barre(note: int, parent: Control, largeur := 150.0) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var bg := PanelContainer.new()
	bg.custom_minimum_size = Vector2(largeur, 10)
	bg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bg.add_theme_stylebox_override("panel", UiStyle.flat_box(Color(1, 1, 1, 0.08), 5, 0))
	h.add_child(bg)
	var fill := ColorRect.new()
	fill.color = couleur(note)
	fill.custom_minimum_size = Vector2(maxf(2.0, largeur * note / 100.0), 10)
	fill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	bg.add_child(fill)
	var l := Label.new()
	l.text = "%d" % note
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", couleur(note))
	h.add_child(l)
	parent.add_child(h)


func _carte_ligne(col: Color) -> VBoxContainer:
	var box := PanelContainer.new()
	var sb := UiStyle.flat_box(Color(1, 1, 1, 0.05), 8, 6)
	sb.border_width_left = 3
	sb.border_color = col
	box.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	box.add_child(v)
	_body.add_child(box)
	return v


func _go(pos: Vector3, parent: Control) -> void:
	if not pos.is_finite():
		return
	var go := UiStyle.icon_button("oeil", "Aller voir", "", 16, 28)
	go.pressed.connect(func() -> void: focus_requested.emit(pos))
	parent.add_child(go)


# --- Vues ------------------------------------------------------------------------------

func _view_avis() -> void:
	var s := avis.sondage()
	var v := int(s.valeur)
	var tend := avis.tendance(7)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	var big := Label.new()
	big.text = "%d" % v
	big.add_theme_font_size_override("font_size", 40)
	big.add_theme_color_override("font_color", couleur(v))
	head.add_child(big)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(right)
	_text("Satisfaction moyenne sur 100", false, 14, Color.TRANSPARENT, right)
	var t_txt := "stable sur 7 jours" if tend == 0 else ("%s%d en 7 jours" % ["+" if tend > 0 else "", tend])
	_text("%s · %d content%s, %d mécontent%s" % [t_txt, int(s.contents), "s" if int(s.contents) > 1 else "", int(s.mecontents),
		"s" if int(s.mecontents) > 1 else ""], true, 12, Color.TRANSPARENT, right)
	_body.add_child(head)
	if avis.historique.size() >= 2:
		var c := AvisCourbe.new()
		c.valeurs = avis.historique.map(func(h) -> int: return int(h.valeur))
		c.custom_minimum_size = Vector2(W - 30, 46)
		_body.add_child(c)
	_section("Par thème", "details")
	var ths: Array = (s.themes as Dictionary).keys()
	ths.sort_custom(func(a, b) -> bool: return int(s.themes[a].note) < int(s.themes[b].note))
	for th in ths:
		var e: Dictionary = s.themes[th]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var ic := TextureRect.new()
		ic.texture = Icones.get_icon(Avis.theme_icone(th), 18, couleur(int(e.note)))
		ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		row.add_child(ic)
		var nom := Label.new()
		nom.text = Avis.theme_nom(th)
		nom.custom_minimum_size = Vector2(150, 0)
		nom.add_theme_font_size_override("font_size", 13)
		row.add_child(nom)
		_barre(int(e.note), row, 140.0)
		_body.add_child(row)
		var parts := []
		for r in (e.raisons as Array).slice(0, 2):
			parts.append("%s (%d)" % [String(r[0]), int(r[1])])
		if not parts.is_empty():
			var l := _text("   " + " · ".join(parts), true, 11)
			l.custom_minimum_size = Vector2(W - 30, 0)
	_text("Note d'un thème : 50 = neutre. Les autres systèmes (pollution, déchets, réseaux, budget, trafic…) ajoutent leurs motifs ici.", true, 11)
	var ef := avis.effets_actifs()
	if not ef.is_empty():
		_section("En ce moment", "horloge")
		for e in ef:
			var j := ceili((float(e.fin) - avis.now()) / 86400.0)
			_text("%s %s : %s%d (encore %d jour%s)" % [Avis.theme_nom(String(e.theme)), String(e.raison), "+" if float(e.delta) >= 0 else "",
				roundi(float(e.delta)), j, "s" if j > 1 else ""], true, 12, couleur(50.0 + float(e.delta) * 6.0))


func _view_quartiers() -> void:
	var s := avis.sondage()
	_section("Satisfaction par quartier", "lieu")
	if carte != null:
		var b := Button.new()
		b.text = "Carte de satisfaction sur la ville"
		b.icon = Icones.get_icon("oeil", 18)
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.button_pressed = carte.visible
		b.toggled.connect(func(on: bool) -> void: carte.set_on(on))
		_body.add_child(b)
		_text("Un disque de couleur au-dessus de chaque logement : rouge mécontent, jaune moyen, vert content.", true, 11)
	for q in s.quartiers:
		var v := _carte_ligne(couleur(int(q.valeur)))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 6)
		v.add_child(h)
		var l := Label.new()
		l.text = String(q.nom)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.add_theme_font_size_override("font_size", 13)
		h.add_child(l)
		_barre(int(q.valeur), h, 90.0)
		_go(q.pos, h)
		_text("environ %d habitants" % int(q.n), true, 11, Color.TRANSPARENT, v)


func _view_paroles() -> void:
	_section("Ce que disent les habitants", "habitants")
	var list := avis.paroles(8)
	if list.is_empty():
		_text("Personne ne veut parler pour l'instant.", true)
	for e in list:
		var v := _carte_ligne(couleur(int(e.valeur)))
		_text("« %s »" % String(e.phrase), false, 14, Color.TRANSPARENT, v)
		var h := HBoxContainer.new()
		v.add_child(h)
		var who := _text("%s, %d ans, %s · %d / 100" % [String(e.nom), int(e.age), String(e.etape).to_lower(), int(e.valeur)], true, 11, Color.TRANSPARENT, h)
		who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var pid := int(e.pid)
		var fiche := UiStyle.icon_button("habitants", "Voir sa fiche", "", 14, 26)
		fiche.pressed.connect(func() -> void: person_requested.emit(pid))
		h.add_child(fiche)
		if String(e.motif) != "":
			_text(String(e.motif), true, 11, Color.TRANSPARENT, v)


func _view_elections() -> void:
	var el := avis.elections
	if not el.actives():
		_section("Élections", "urne")
		_text("Les élections municipales sont désactivées (Admin, F10 → Événements).", true)
		return
	if el.etat == "attente":
		_section("Bientôt maire", "urne")
		_text("Tu deviens maire à %d habitants (aujourd'hui : %d). Le premier mandat commence alors." % [Elections.MIN_HABITANTS,
			avis.population.persons.size()], true)
		return
	_section("Mairie de %s" % Avis.ville(), "urne")
	var m := el.maire
	if el.joueur_maire():
		_text("Maire : %s (liste « %s »)" % ["toi" if el._tete_joueur() < 0 else el._tete_joueur_nom() + " (toi)", el.ma_liste()])
	else:
		_text("Maire : %s (liste « %s »). Tu gères la ville, mais le conseil suit son programme." % [String(m.get("tete_nom", "?")), String(m.get("nom", "?"))])
	var j := el.jours_avant_vote()
	match el.etat:
		"mandat":
			_text("Prochaines municipales dans %d jour%s (campagne %d jours avant). Mandat : 6 ans de la vie des habitants." % [j, "s" if j > 1 else "", el.duree_campagne()], true, 12)
		"campagne":
			_text("Campagne en cours : 1er tour %s (résultats à 20 h)." % ("aujourd'hui" if j <= 0 else "dans %d jour%s" % [j, "s" if j > 1 else ""]), false, 13, UiStyle.ACCENT)
		"entre_tours":
			_text("Entre les deux tours : 2nd tour %s (résultats à 20 h)." % ("aujourd'hui" if j <= 0 else "dans %d jour%s" % [j, "s" if j > 1 else ""]), false, 13, UiStyle.ACCENT)
	# Promesses et objectifs du mandat.
	if not el.promesses.is_empty():
		_section("Tes promesses du mandat", "details")
		for pr in el.promesses:
			var ok := el.tenue(pr)
			_text("%s %s : %s" % ["✔" if ok else "…", Elections.PROMESSES[pr.id].nom, el.progres(pr)], false, 12, UiStyle.GOOD if ok else Color.TRANSPARENT)
	if not el.objectifs.is_empty():
		_section("Objectifs imposés par le conseil", "cadenas")
		for pr in el.objectifs:
			var ok := el.tenue(pr)
			_text("%s %s : %s" % ["✔" if ok else "…", Elections.PROMESSES[pr.id].nom, el.progres(pr)], false, 12, UiStyle.GOOD if ok else Color.TRANSPARENT)
	if not el.bilan.is_empty():
		_section("Bilan présenté aux électeurs", "details")
		for b in el.bilan:
			_text("%s %s%s" % ["✔" if bool(b.tenu) else "✘", String(b.nom), " (objectif)" if bool(b.objectif) else ""], false, 12,
				UiStyle.GOOD if bool(b.tenu) else Color("ef476f"))
	if el.etat == "campagne" or el.etat == "entre_tours":
		_view_campagne()
	elif el.etat == "mandat":
		_button("Élections anticipées (vote dimanche prochain)", "urne", func() -> void:
			el.anticiper()
			refresh(), "La campagne s'ouvre tout de suite, vote le prochain dimanche (au moins 2 jours)")
	var last := el.dernier_scrutin()
	if not last.is_empty():
		_section("Dernier scrutin (%s tour)" % ("1er" if int(last.tour) == 1 else "2e"), "urne")
		_text("Participation %d %% · %d votants sur %d inscrits" % [roundi(float(last.participation)), int(last.votants), int(last.inscrits)], true, 12)
		for r in last.resultats:
			_ligne_score(String(r.nom) + ("  (toi)" if bool(r.joueur) else ""), float(r.pct), Color(String(r.couleur)), String(r.id) == String(last.elu))


func _ligne_score(nom: String, pct: float, col: Color, elu := false) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var sw := ColorRect.new()
	sw.color = col
	sw.custom_minimum_size = Vector2(10, 10)
	sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(sw)
	var l := Label.new()
	l.text = ("★ " if elu else "") + nom
	l.custom_minimum_size = Vector2(190, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 12)
	h.add_child(l)
	var bg := ColorRect.new()
	bg.color = col
	bg.custom_minimum_size = Vector2(maxf(2.0, 110.0 * pct / 100.0), 9)
	bg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(bg)
	var p := Label.new()
	p.text = "%.1f %%" % pct
	p.add_theme_font_size_override("font_size", 12)
	h.add_child(p)
	_body.add_child(h)


func _view_campagne() -> void:
	var el := avis.elections
	_section("Les listes", "habitants")
	for l in el.listes:
		var v := _carte_ligne(Color(String(l.couleur)))
		var title := "« %s »%s" % [String(l.nom), "  (ta liste)" if bool(l.joueur) else ""]
		if bool(l.sortant):
			title += " · sortante"
		_text(title, false, 13, Color.TRANSPARENT, v)
		_text("Tête de liste : %s" % String(l.tete_nom), true, 11, Color.TRANSPARENT, v)
		if not (l.promesses as Array).is_empty():
			var noms := []
			for pid in l.promesses:
				noms.append(String(Elections.PROMESSES[pid].nom).to_lower())
			_text("Promet : " + ", ".join(noms), true, 11, Color.TRANSPARENT, v)
	_section("Sondage des intentions de vote", "details")
	var r := el.intentions(el.listes, avis.jour() * 13 + 1)
	for l in el.listes:
		_ligne_score(String(l.nom), float(r.pct.get(l.id, 0.0)), Color(String(l.couleur)))
	_text("Participation attendue : %d %%. Les contents votent pour la liste sortante ; les mécontents pour la liste qui parle de ce qui les gêne." % roundi(float(r.participation)), true, 11)
	if el.etat != "campagne":
		return
	_section("Ta campagne", "urne")
	var champ := LineEdit.new()
	champ.placeholder_text = "Nom de ta liste"
	champ.text = el.ma_liste()
	champ.custom_minimum_size = Vector2(W - 30, 0)
	champ.text_submitted.connect(func(t: String) -> void:
		el.nom_liste = t
		for l in el.listes:
			if bool(l.joueur):
				l.nom = el.ma_liste()
		champ.release_focus()
		refresh())
	champ.focus_exited.connect(func() -> void:
		if champ.text.strip_edges() != el.ma_liste():
			el.nom_liste = champ.text
			for l in el.listes:
				if bool(l.joueur):
					l.nom = el.ma_liste())
	_body.add_child(champ)
	_text("Tes promesses (%d sur %d au plus) : elles attirent les habitants que le thème gêne. Tenues à la fin du mandat, elles comptent pour la prochaine élection ; non tenues, elles coûtent cher." % [el.promesses_campagne.size(), Elections.MAX_PROMESSES], true, 11)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	for id in Elections.PROMESSES:
		var spec: Dictionary = Elections.PROMESSES[id]
		var b := Button.new()
		b.text = String(spec.nom)
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.button_pressed = el.promesses_campagne.has(id)
		b.custom_minimum_size = Vector2((W - 34) / 2.0, 0)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.icon = Icones.get_icon(Avis.theme_icone(String(spec.theme)), 16)
		b.add_theme_font_size_override("font_size", 11)
		b.tooltip_text = Avis.theme_nom(String(spec.theme))
		var pid: String = id
		b.pressed.connect(func() -> void:
			el.promettre(pid)
			refresh())
		grid.add_child(b)
	_body.add_child(grid)


func _view_manifs() -> void:
	var mf := avis.manifs
	var cur := mf.en_cours()
	_section("Manifestations", "pancarte")
	if not mf.actives():
		_text("Les manifestations sont désactivées (Admin, F10 → Événements).", true)
	elif cur.is_empty():
		_text("Pas de manifestation en vue. Quand un thème passe sous %d / 100, les mécontents descendent dans la rue (devant la mairie)." % Manifestations.SEUIL, true)
	for m in cur:
		var v := _carte_ligne(Color("f77f00"))
		var h := HBoxContainer.new()
		v.add_child(h)
		var t := _text("« %s » · %s" % [String(m.slogan), Avis.theme_nom(String(m.theme))], false, 13, Color.TRANSPARENT, h)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_go(m.pos, h)
		var quand := "en cours"
		if String(m.etat) != "en_cours":
			quand = "prévue à %s" % avis.evenements.heure_courte(float(m.debut)) if avis.evenements != null else "prévue"
		var lieu := avis.population.building_name(int(m.bid)) if int(m.bid) >= 0 else "en ville"
		_text("%d manifestants · %s · %s" % [int(m.nb), quand, lieu], true, 11, Color.TRANSPARENT, v)
		if String(m.reponse) == "police":
			_text("La police est en route.", false, 12, Color("6ea8fe"), v)
			continue
		var id := int(m.id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		v.add_child(row)
		var cout := mf.cout_negociation(m)
		_button("Négocier (%s)" % BuildingSystem.format_short(cout), "habitants", func() -> void: _repondre(id, "negocier"),
			"Recevoir une délégation : le thème remonte pendant un mois, la colère retombe", true, row)
		_button("Ignorer", "fermer", func() -> void: _repondre(id, "ignorer"),
			"Le thème baisse ; la 2e fois sur le même thème, les agents de la ville font grève", true, row)
		_button("Police", "services", func() -> void: _repondre(id, "police"),
			"Disperser le cortège : calme tout de suite, mais la vie politique baisse" if mf.police_possible() else "Il faut un commissariat", mf.police_possible(), row)
	var greves := 0
	if avis.population != null and avis.population.effectif != null:
		for bid in avis.population.effectif.greve.keys():
			if avis.population.effectif.en_greve(bid):
				greves += 1
	if greves > 0:
		_text("Grève des agents de la ville : %d bâtiments publics fermés aujourd'hui." % greves, false, 12, Color("ef476f"))
	var old := []
	for m in mf.recentes(8):
		if String(m.etat) == "finie":
			old.append(m)
	if not old.is_empty():
		_section("Ces derniers jours", "horloge")
		var noms := {"negocier": "négociation", "ignorer": "ignorée", "police": "dispersée par la police", "sans_reponse": "sans réponse", "": "terminée"}
		for m in old:
			_text("« %s » (%d manifestants) : %s" % [String(m.slogan), int(m.nb), String(noms.get(String(m.reponse), ""))], true, 12)
	if mf.actives() and cur.is_empty():
		var th := mf.pire_theme()
		var s := avis.sondage()
		var worst := ""
		var wn := 101
		for k in s.themes:
			if int(s.themes[k].note) < wn:
				wn = int(s.themes[k].note)
				worst = k
		if worst != "":
			_button("Provoquer une manifestation (essai : %s)" % Avis.theme_nom(th if th != "" else worst).to_lower(), "pancarte", func() -> void:
				mf.annoncer(th if th != "" else worst, true)
				refresh(), "Pour voir tout de suite un cortège (bac à sable)")


func _repondre(id: int, r: String) -> void:
	var msg := avis.manifs.repondre(id, r)
	if msg != "" and avis.buildings != null:
		avis.buildings.message.emit(msg)
	refresh()


## Petite courbe de la satisfaction des derniers jours.
class AvisCourbe extends Control:
	var valeurs: Array = []

	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_rect(Rect2(0, 0, w, h), Color(1, 1, 1, 0.04))
		draw_line(Vector2(0, h * 0.5), Vector2(w, h * 0.5), Color(1, 1, 1, 0.12), 1.0)
		if valeurs.size() < 2:
			return
		var pts := PackedVector2Array()
		for i in valeurs.size():
			pts.append(Vector2(w * i / (valeurs.size() - 1), h - h * clampf(float(valeurs[i]) / 100.0, 0.0, 1.0)))
		draw_polyline(pts, AvisPanel.couleur(float(valeurs[valeurs.size() - 1])), 2.0, true)
