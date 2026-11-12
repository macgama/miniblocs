class_name EvenementsPanel
extends CanvasLayer
## Panneau « Infos » (touche I) : ce qui se passe en ville.
##
## - En cours : événements en cours et à venir (marchés, fêtes, matchs,
##   incendies, tempêtes, épidémies), incidents ouverts pour les secours.
## - Journal : toutes les nouvelles, clic pour aller voir.
## - Organiser : poser un marché ou une fête (clic sur la carte), et
##   déclencher une catastrophe (incendie, tempête, épidémie).
## - Dégâts : bâtiments abîmés à réparer, ruines à reconstruire ou déblayer.
## - Stades : clubs de la ville, prochain match, classement.

signal focus_requested(pos: Vector3)
## Le panneau prend la main (outil de pose) : les autres outils se rangent.
signal tool_requested

const W := 360.0
const H := 560.0

var ev: Evenements
var _panel: PanelContainer
var _body: VBoxContainer
var _scroll: ScrollContainer
var view := "en_cours"
var _tick := 0.0
var _tabs := {}


func setup(e: Evenements) -> void:
	ev = e
	layer = 6
	_panel = PanelContainer.new()
	_panel.name = "PanneauInfos"
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
	icon.texture = Icones.get_icon("infos", 22, UiStyle.ACCENT)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	head.add_child(icon)
	var title := Label.new()
	title.text = "Infos : la vie de la ville"
	title.add_theme_font_size_override("font_size", 16)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var x := UiStyle.icon_button("fermer", "Fermer", "I", 18, 32)
	x.pressed.connect(func() -> void: set_open(false))
	head.add_child(x)
	var tabs := HBoxContainer.new()
	outer.add_child(tabs)
	for spec in [["En cours", "en_cours", "horloge"], ["Journal", "journal", "infos"], ["Organiser", "organiser", "fete"],
			["Dégâts", "degats", "feu"], ["Stades", "stades", "sport"]]:
		var b := Button.new()
		b.text = spec[0]
		b.icon = Icones.get_icon(spec[2], 16)
		b.focus_mode = Control.FOCUS_NONE
		b.toggle_mode = true
		b.add_theme_font_size_override("font_size", 12)
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
	ev.changed.connect(func() -> void:
		if is_open() and view != "journal":
			_tick = 1.6)
	ev.outil_change.connect(func(_t: String) -> void:
		if is_open():
			refresh())


func is_open() -> bool:
	return _panel.visible


func set_open(on: bool) -> void:
	_panel.visible = on
	if on:
		refresh()
	elif ev.outil != "":
		ev.set_outil("")


func toggle() -> void:
	set_open(not _panel.visible)


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.physical_keycode == KEY_I and not k.shift_pressed and not k.ctrl_pressed and not k.alt_pressed:
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
	if ev == null:
		return
	for v in _tabs:
		(_tabs[v] as Button).set_pressed_no_signal(v == view)
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	match view:
		"journal":
			_view_journal()
		"organiser":
			_view_organiser()
		"degats":
			_view_degats()
		"stades":
			_view_stades()
		_:
			_view_en_cours()


# --- Petits outils -------------------------------------------------------------------

func _text(t: String, dim := false, size := 13, color := Color.TRANSPARENT) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(W - 30, 0)
	l.add_theme_font_size_override("font_size", size)
	if color.a > 0.0:
		l.add_theme_color_override("font_color", color)
	elif dim:
		l.add_theme_color_override("font_color", Color(1, 1, 1, 0.65))
	_body.add_child(l)
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


func _button(text: String, icon: String, cb: Callable, tip := "", enabled := true) -> Button:
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
	_body.add_child(b)
	return b


## Une ligne : icône colorée, titre, détail, bouton « Voir ».
func _row(icon: String, col: Color, title: String, detail: String, pos: Vector3, extra: Control = null) -> void:
	var box := PanelContainer.new()
	var sb := UiStyle.flat_box(Color(1, 1, 1, 0.05), 8, 6)
	sb.border_width_left = 3
	sb.border_color = col
	box.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	box.add_child(h)
	var ic := TextureRect.new()
	ic.texture = Icones.get_icon(icon, 20, col)
	ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	h.add_child(ic)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var l := Label.new()
	l.text = title
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 13)
	v.add_child(l)
	if detail != "":
		var l2 := Label.new()
		l2.text = detail
		l2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l2.add_theme_font_size_override("font_size", 12)
		l2.add_theme_color_override("font_color", Color(1, 1, 1, 0.65))
		v.add_child(l2)
	if extra != null:
		v.add_child(extra)
	if pos.is_finite():
		var go := UiStyle.icon_button("oeil", "Aller voir", "", 16, 28)
		go.pressed.connect(func() -> void: focus_requested.emit(pos))
		h.add_child(go)
	_body.add_child(box)


func _type(e: Dictionary) -> Dictionary:
	return Evenements.TYPES.get(String(e.type), {"icone": "infos", "couleur": UiStyle.ACCENT})


# --- Vues ------------------------------------------------------------------------------

func _view_en_cours() -> void:
	var now := ev.now()
	var running := ev.en_cours()
	var planned := ev.prevus()
	planned.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.debut) < float(b.debut))
	_section("En ce moment", "horloge")
	if running.is_empty():
		_text("Rien de spécial en ville. Les marchés ont lieu le samedi matin, les fêtes de quartier l'été, les matchs le week-end.", true)
	for e in running:
		var t := _type(e)
		_row(String(t.icone), t.couleur, String(e.nom), _detail(e, now), e.pos)
	if not planned.is_empty():
		_section("À venir", "precedent")
		for e in planned.slice(0, 8):
			var t := _type(e)
			_row(String(t.icone), t.couleur, String(e.nom), "%s · %s" % [ev.heure_texte(float(e.debut)), _lieu(e)], e.pos)
	var open := ev.incidents_ouverts()
	_section("Secours", "services")
	if open.is_empty():
		_text("Aucune intervention en cours.", true)
	for inc in open:
		var etat := "en attente des secours" if String(inc.etat) == "declare" else "secours sur place (%s)" % ", ".join(inc.services)
		var besoin := ", ".join(inc.besoin)
		var col := Color("ef476f") if int(inc.gravite) >= 3 else (Color("f4a259") if int(inc.gravite) == 2 else Color("e9c46a"))
		_row("feu" if String(inc.type) == "incendie" else "services", col, "%s (gravité %d)" % [String(inc.texte), int(inc.gravite)],
			"%s · besoin : %s · depuis %s" % [etat, besoin, ev.heure_courte(float(inc.debut))], inc.position)
	if not ev.secours_branches():
		_text("Les secours sont simulés : la caserne, l'hôpital ou le commissariat le plus proche intervient après le trajet. Sans caserne, un feu brûle jusqu'au bout.", true, 12)


func _lieu(e: Dictionary) -> String:
	return ev.building_name(int(e.bid)) if int(e.bid) >= 0 and ev.buildings.buildings.has(int(e.bid)) else "en ville"


func _detail(e: Dictionary, now: float) -> String:
	var d: Dictionary = e.data
	match String(e.type):
		"match":
			var per := Matchs.periode(e, now)
			var sc: Array = d.score
			if per == "avant":
				return "Coup d'envoi à %s · %d spectateurs attendus" % [ev.heure_courte(float(e.debut) + Matchs.AVANT), int(d.affluence)]
			return "%s %d – %d %s · %s · %d spectateurs" % [String(d.home), int(sc[0]), int(sc[1]), String(d.away),
				"mi-temps" if per == "mi-temps" else ("%d'" % int(Matchs.minute(e, now)) if per != "fin" else "terminé"), int(d.affluence)]
		"marche", "fete":
			return "%s · jusqu'à %s · %d habitants y vont" % [_lieu(e), ev.heure_courte(float(e.fin)), ev.fetes.habitants_venus(e)]
		"incendie":
			var bats: Array = d.get("batiments", [])
			var parts := []
			for bid in bats:
				var f: Dictionary = ev.incendies.feux.get(bid, {})
				var dg := float(ev.degats.get(bid, {}).get("d", 0.0))
				parts.append("%s : feu %d %%, dégâts %d %%" % [ev.building_name(bid), roundi(float(f.get("i", 0.0)) * 100.0), roundi(dg * 100.0)])
			return "\n".join(parts) if not parts.is_empty() else "Éteint"
		"tempete":
			var s := "jusqu'à %s · %d arbres tombés, %d toits abîmés" % [ev.heure_courte(float(e.fin)), int(d.arbres), int(d.toits)]
			if not (d.get("panne_bats", []) as Array).is_empty():
				s += ", %d bâtiments sans courant" % (d.panne_bats as Array).size()
			if float(d.get("niveau", 0.0)) > 0.0:
				s += " · crue de %s m" % str(snappedf(float(d.niveau), 0.1)).replace(".", ",")
			return s
		"epidemie":
			return "%d malades en ce moment, %d en tout, %d cas graves, %d décès" % [ev.epidemies.malades_count(), int(d.total), int(d.graves), int(d.deces)]
	return ""


func _view_journal() -> void:
	_section("Journal de la ville", "infos")
	if ev.journal.is_empty():
		_text("Pas encore de nouvelles.", true)
	for n in ev.journal.slice(0, 120):
		var t: Dictionary = Evenements.TYPES.get(Actualites._type_of(String(n.genre)), {"icone": "infos", "couleur": UiStyle.ACCENT})
		_row(String(t.icone), t.couleur, String(n.texte), ev.heure_texte(float(n.t)), n.pos)


func _view_organiser() -> void:
	_section("Organiser en ville", "fete")
	if ev.outil != "":
		_text("Clique sur la carte pour choisir l'endroit (clic droit ou Échap : annuler).", false, 13, UiStyle.ACCENT)
	_button("Marché (%s) : clic sur une place ou une rue" % BuildingSystem.format_money(ReglagesPartie.prix(FetesMarches.COUT_MARCHE)), "marche", func() -> void:
		tool_requested.emit()
		ev.set_outil("marche"), "Des étals pendant 6 heures, les habitants du coin viennent faire leurs courses. Les droits de place rapportent un peu.")
	_button("Fête de quartier (%s) : clic où la poser" % BuildingSystem.format_money(ReglagesPartie.prix(FetesMarches.COUT_FETE)), "fete", func() -> void:
		tool_requested.emit()
		ev.set_outil("fete"), "Tables, guirlandes et petite scène pendant 8 heures. Les voisins viennent faire la fête.")
	_text("La ville en organise aussi toute seule : marché chaque samedi matin, fête de quartier un samedi par mois de mai à septembre, fête de la musique le 21 juin (réglage Admin, F10).", true, 12)
	_section("Déclencher une catastrophe", "tempete")
	_text("Pour voir comment la ville s'en sort (et tester les secours). Au hasard, elles arrivent selon le réglage Admin « Catastrophes ».", true, 12)
	_button("Incendie : clic sur un bâtiment", "feu", func() -> void:
		tool_requested.emit()
		ev.set_outil("incendie"))
	_button("Incendie dans un bâtiment au hasard", "feu", func() -> void: ev.declencher("incendie"))
	_button("Tempête maintenant (4 heures)", "tempete", func() -> void: ev.declencher("tempete"))
	_button("Épidémie maintenant", "epidemie", func() -> void: ev.declencher("epidemie"),
		"Grippe, gastro, rougeole ou virus respiratoire, au hasard.", ev.population != null and not ev.population.persons.is_empty())


func _view_degats() -> void:
	_section("Bâtiments abîmés", "feu")
	if ev.degats.is_empty():
		_text("Aucun bâtiment abîmé.", true)
	else:
		var total := 0
		for bid in ev.degats:
			total += ev.cout_reparation(bid)
		_button("Tout réparer (%s)" % BuildingSystem.format_money(total), "plus", func() -> void:
			var n := ev.reparer_tout()
			if n > 0:
				ev.buildings.message.emit("%d bâtiment%s réparé%s." % [n, "s" if n > 1 else "", "s" if n > 1 else ""])
			refresh())
	for bid in ev.degats:
		var e: Dictionary = ev.degats[bid]
		var cause: String = {"incendie": "incendie", "tempete": "tempête", "inondation": "inondation"}.get(String(e.cause), String(e.cause))
		var cost := ev.cout_reparation(bid)
		var rep := Button.new()
		rep.text = "Réparer (%s)" % BuildingSystem.format_money(cost)
		rep.focus_mode = Control.FOCUS_NONE
		rep.add_theme_font_size_override("font_size", 12)
		var b := int(bid)
		rep.pressed.connect(func() -> void:
			ev.reparer(b)
			refresh())
		var brule := ev.incendies.brule(b)
		rep.disabled = brule
		_row("feu" if String(e.cause) == "incendie" else ("tempete" if String(e.cause) != "inondation" else "eau"), Color("f4a259"),
			"%s : dégâts %d %%" % [ev.building_name(b), roundi(float(e.d) * 100.0)], "Cause : %s%s" % [cause, " (encore en feu)" if brule else ""],
			ev.building_pos(b), rep)
	_section("Ruines", "demolir")
	if ev.ruines.is_empty():
		_text("Aucune ruine.", true)
	for key in ev.ruines:
		var r: Dictionary = ev.ruines[key]
		var b: Dictionary = r.b
		var t := BuildingCatalog.get_type(String(b.t))
		var row := HBoxContainer.new()
		var k := String(key)
		var rec := Button.new()
		rec.text = "Reconstruire (%s)" % BuildingSystem.format_money(ev.cout_reconstruction(k))
		rec.focus_mode = Control.FOCUS_NONE
		rec.add_theme_font_size_override("font_size", 12)
		rec.pressed.connect(func() -> void:
			ev.reconstruire(k)
			refresh())
		row.add_child(rec)
		var deb := Button.new()
		deb.text = "Déblayer"
		deb.tooltip_text = "Enlever la ruine sans reconstruire : le terrain redevient libre."
		deb.focus_mode = Control.FOCUS_NONE
		deb.add_theme_font_size_override("font_size", 12)
		deb.pressed.connect(func() -> void:
			ev.deblayer(k)
			refresh())
		row.add_child(deb)
		var rect := Rect2i(Vector2i(int(b.x), int(b.z)), BuildingCatalog.footprint(String(b.t), int(b.r)))
		_row("demolir", Color("8a817c"), "Ruine : %s" % String(t.get("name", b.t)), "Détruit par %s, %s" % [ev._cause_texte(String(r.cause)), ev.heure_texte(float(r.t))],
			BuildingSystem.rect_center(rect) + Vector3(0, float(b.h), 0), row)


func _view_stades() -> void:
	var st := ev.matchs.stades()
	_section("Football", "sport")
	if st.is_empty():
		_text("Aucun stade en ville. Construis-en un (Construire, B → Sport) : 11 grands stades et le terrain de foot. Chaque stade a son club, qui joue un samedi ou un dimanche sur deux pendant la saison (mi-juillet à fin mai).", true)
		return
	for bid in st:
		var t := String(ev.buildings.buildings[bid].t)
		var club := ev.matchs.club_de(bid)
		var next := ""
		for e in ev.prevus("match") + ev.en_cours("match"):
			if int(e.bid) == bid:
				next = "%s : %s" % [ev.heure_texte(float(e.debut) + Matchs.AVANT), String(e.nom)]
		_row("sport", Color("9d4edd"), "%s : %s" % [ev.building_name(bid), club if t != "foot" else "matchs amateurs le dimanche"],
			"Prochain match : %s" % (next if next != "" else "pas encore prévu (calendrier fait chaque matin)"), ev.building_pos(bid))
	var table := ev.matchs.classement()
	if table.is_empty():
		return
	_section("Classement %s" % (ev.matchs.saison if ev.matchs.saison != "" else ""), "sport")
	var i := 1
	for c in table:
		var line := "%2d. %s   %d pts   (%d j, %d-%d-%d, %d:%d)" % [i, String(c.nom), int(c.pts), int(c.j), int(c.g), int(c.n), int(c.p), int(c.bp), int(c.bc)]
		_text(line, false, 12, UiStyle.ACCENT if bool(c.get("ville", false)) else Color.TRANSPARENT)
		i += 1
