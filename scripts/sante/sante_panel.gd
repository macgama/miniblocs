class_name SantePanel
extends CanvasLayer
## Panneau « Santé publique » (F7, menu Infos) : hygiène de la ville, épidémie
## en cours, vaccins, mesures sanitaires et grandes épidémies de l'histoire.

signal focus_requested(pos: Vector3)

const W := 360.0
const H := 540.0
const VUES := [["bilan", "Bilan"], ["vaccins", "Vaccins"], ["mesures", "Mesures"], ["histoire", "Histoire"]]

var sp: SantePublique
var view := "bilan"
var _panel: PanelContainer
var _title: Label
var _body: VBoxContainer
var _scroll: ScrollContainer
var _tick := 0.0


func setup(s: SantePublique) -> void:
	sp = s
	_build()
	sp.changed.connect(func() -> void:
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
	icon.texture = Icones.get_icon("sante", 22, UiStyle.ACCENT)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	head.add_child(icon)
	_title = Label.new()
	_title.text = "Santé publique"
	_title.add_theme_font_size_override("font_size", 16)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	var x := UiStyle.icon_button("fermer", "Fermer", "F7", 18, 32)
	x.pressed.connect(func() -> void: set_open(false))
	head.add_child(x)
	var tabs := HBoxContainer.new()
	outer.add_child(tabs)
	for v in VUES:
		var b := Button.new()
		b.text = String(v[1])
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var id: String = v[0]
		b.pressed.connect(func() -> void: show_view(id))
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
	if k and k.pressed and not k.echo and k.keycode == KEY_F7 and not k.shift_pressed and not k.ctrl_pressed and not k.alt_pressed:
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
		_refresh_keep()


func _refresh_keep() -> void:
	var keep := _scroll.scroll_vertical
	refresh()
	_scroll.set_deferred("scroll_vertical", keep)


func refresh() -> void:
	if sp == null:
		return
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	match view:
		"vaccins": _view_vaccins()
		"mesures": _view_mesures()
		"histoire": _view_histoire()
		_: _view_bilan()


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


func _barre(nom: String, v: float, bon := 0.8) -> void:
	var hb := HBoxContainer.new()
	var l := Label.new()
	l.text = nom
	l.custom_minimum_size = Vector2(150, 0)
	l.add_theme_font_size_override("font_size", 12)
	hb.add_child(l)
	var pb := ProgressBar.new()
	pb.min_value = 0
	pb.max_value = 100
	pb.value = roundi(clampf(v, 0.0, 1.0) * 100.0)
	pb.custom_minimum_size = Vector2(170, 16)
	pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pb.modulate = Color("06d6a0") if v >= bon else (Color("ffd166") if v >= bon * 0.5 else Color("ef476f"))
	hb.add_child(pb)
	_body.add_child(hb)


func _bouton(t: String, f: Callable, on := true, tip := "") -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.disabled = not on
	b.tooltip_text = tip
	b.pressed.connect(f)
	return b


static func euros(v: float) -> String:
	var n := roundi(v)
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = " " + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("−" if n < 0 else "") + s + out + " €"


# --- Bilan -------------------------------------------------------------------------------

func _view_bilan() -> void:
	_title.text = "Santé publique · %d" % SantePublique.annee()
	var b := sp.bilan()
	var ev := sp.ev
	_section("Épidémie")
	if ev != null and ev.epidemies != null and ev.epidemies.active >= 0 and ev.events.has(ev.epidemies.active):
		var e: Dictionary = ev.events[ev.epidemies.active]
		var d: Dictionary = e.data
		var m: Dictionary = Epidemies.MALADIES.get(String(d.maladie), {})
		_text("%s en cours (%s)" % [String(e.nom), {"eau": "passe par l'eau", "air": "passe par l'air", "contact": "passe par les contacts"}.get(String(m.get("mode", "air")), "")])
		_text("%d malades en ce moment, %d en tout, %d cas graves, %d décès." % [ev.epidemies.malades_count(), int(d.total), int(d.graves), int(d.deces)], true)
		if sp.hopitaux_debordes():
			_text("Les hôpitaux sont débordés : %d hospitalisés pour %d lits." % [int(b.hospitalises), int(b.lits)])
		var pos: Vector3 = e.get("pos", Vector3.INF)
		if pos is Vector3 and pos.is_finite():
			_body.add_child(_bouton("Aller au premier foyer", func() -> void: focus_requested.emit(pos)))
		if String(m.get("mode", "")) == "eau":
			_text("Conseil : faire bouillir l'eau (Mesures) ; à long terme, des égouts et de l'eau potable.", true, 11)
		elif not sp.mesures.has("quarantaine"):
			_text("Conseil : quarantaine des malades (Mesures), et vacciner si un vaccin existe.", true, 11)
	else:
		_text("Aucune épidémie en ce moment. Profitez-en, ça ne dure jamais.", true)
	var pd := sp.prochaine_pandemie()
	if not pd.is_empty() and sp.historiques_actifs():
		var etat := String(sp.pandemies.get(str(pd.annee), ""))
		if etat == "rumeur":
			_text("Rumeur : %s" % String(pd.rumeur), true, 12)
	_section("Hygiène des logements")
	if int(b.hab) == 0:
		_text("Personne n'habite encore la ville.", true)
	else:
		_barre("Eau potable", float(b.eau_potable))
		_barre("Égouts traités", float(b.egouts))
		_barre("Hygiène moyenne", float(b.hygiene), 0.75)
		_text("%d %% des habitants boivent l'eau du puits." % roundi(float(b.puits) * 100.0), true, 12)
	_section("Hôpitaux")
	_text("%d lits d'hôpital%s, %d cas graves hospitalisés." % [int(b.lits), " (lazaret compris)" if sp.lazaret() else "", int(b.hospitalises)])
	var tot_deces := 0
	for k in sp.deces:
		tot_deces += int(sp.deces[k])
	if tot_deces > 0:
		_text("Décès par épidémie depuis le début : %d." % tot_deces, true)
	var cs := sp.conseils()
	if not cs.is_empty():
		_section("Conseils")
		for c in cs:
			_text("• " + String(c), false, 12)


# --- Vaccins -------------------------------------------------------------------------------

func _view_vaccins() -> void:
	_title.text = "Santé publique · vaccins"
	var an := SantePublique.annee()
	_text("Doses possibles par jour : %d (plus d'hôpitaux et de médecins, plus de doses). Sans obligation, %d %% des habitants refusent à cette époque." % [
		sp.doses_par_jour(), roundi(SanteDonnees.hesitants(an) * 100.0)], true, 11)
	for v in SanteDonnees.VACCINS:
		var d: Dictionary = SanteDonnees.VACCINS[v]
		_section("%s (%d)" % [String(d.nom), int(d.annee)])
		if not sp.vaccin_disponible(v):
			_text("Arrive en %d. %s" % [int(d.annee), String(d.desc)], true, 12)
			continue
		_text(String(d.desc), true, 12)
		_barre("Vaccinés (%s)" % ("enfants" if String(d.cible) == "enfants" else "tous"), sp.couverture(v), SantePublique.SEUIL_COLLECTIF)
		var hb := HBoxContainer.new()
		var vv: String = v
		if sp.campagnes.has(v):
			hb.add_child(_bouton("Arrêter la campagne", func() -> void: sp.arreter_campagne(vv)))
			var c: Dictionary = sp.campagnes[v]
			_text("Campagne en cours : %d doses, %s." % [int(c.doses), euros(float(c.cout))], false, 12)
		else:
			hb.add_child(_bouton("Campagne (≈ %s)" % euros(sp.cout_campagne(v)), func() -> void: sp.lancer_campagne(vv)))
		var ob := CheckBox.new()
		ob.text = "Obligatoire"
		ob.focus_mode = Control.FOCUS_NONE
		ob.button_pressed = sp.obligatoires.has(v)
		ob.toggled.connect(func(on: bool) -> void: sp.set_obligatoire(vv, on))
		hb.add_child(ob)
		_body.add_child(hb)


# --- Mesures ---------------------------------------------------------------------------------

func _view_mesures() -> void:
	_title.text = "Santé publique · mesures"
	_text("Arrêtés sanitaires du maire. Les mesures marquées ⏳ sont levées une semaine après la fin de l'épidémie.", true, 11)
	for k in SanteDonnees.MESURES:
		var m: Dictionary = SanteDonnees.MESURES[k]
		var cb := CheckBox.new()
		cb.text = "%s%s" % [String(m.nom), " ⏳" if bool(m.get("temporaire", false)) else ""]
		cb.focus_mode = Control.FOCUS_NONE
		cb.button_pressed = sp.mesures.has(k)
		cb.disabled = not sp.mesure_disponible(k)
		var kk: String = k
		cb.toggled.connect(func(on: bool) -> void: sp.set_mesure(kk, on))
		_body.add_child(HSeparator.new())
		_body.add_child(cb)
		if not sp.mesure_disponible(k):
			_text("Possible à partir de %d. %s" % [int(m.annee), String(m.desc)], true, 11)
			continue
		var extra := ""
		var cout := sp.cout_mesure(k)
		if cout > 0.0:
			extra += " %s par jour." % euros(cout)
		if float(m.satisfaction) < 0.0:
			extra += " Satisfaction %d." % roundi(float(m.satisfaction))
		_text(String(m.desc) + extra, true, 11)


# --- Histoire --------------------------------------------------------------------------------

func _view_histoire() -> void:
	_title.text = "Santé publique · histoire"
	var an := SantePublique.annee()
	var cb := CheckBox.new()
	cb.text = "Grandes épidémies de l'histoire à leur date"
	cb.focus_mode = Control.FOCUS_NONE
	cb.button_pressed = sp.historiques
	cb.toggled.connect(func(on: bool) -> void:
		sp.historiques = on
		sp.changed.emit())
	_body.add_child(cb)
	if not Epoques.actif():
		_text("Partie à l'époque actuelle : le calendrier ne joue que si la partie commence dans le passé (Année de départ, Admin F10).", true, 11)
	elif not sp.historiques_actifs() and sp.ev != null and not sp.ev.catastrophes_on():
		_text("Les catastrophes sont désactivées (Admin F10) : le calendrier attend.", true, 11)
	_section("Calendrier")
	for pd in SanteDonnees.PANDEMIES:
		var etat := String(sp.pandemies.get(str(pd.annee), ""))
		var mark: String = {"fait": "✔", "passe": "—", "rumeur": "…"}.get(etat, "○")
		var dim := etat == "passe" or (int(pd.annee) < an - 1 and etat == "")
		_text("%s %d · %s" % [mark, int(pd.annee), String(pd.nom)], dim, 12)
	_section("Épidémies de la partie")
	if sp.historique.is_empty():
		_text("Aucune pour l'instant.", true)
	for h in sp.historique:
		_text("%d · %s : %d malades, %d cas graves, %d décès (%d jours)" % [int(h.annee), String(h.nom), int(h.total), int(h.graves), int(h.deces), int(h.jours)], false, 12)
	_section("Provoquer une épidémie")
	var gf := GridContainer.new()
	gf.columns = 2
	for k in Epidemies.du_moment(an):
		var kk: String = k
		var nom := String(Epidemies.MALADIES[k].nom)
		var b := _bouton(nom.left(1).to_upper() + nom.substr(1), func() -> void:
			if sp.ev != null:
				sp.ev.epidemies.start(kk, false))
		b.disabled = sp.ev == null or sp.ev.epidemies.active >= 0
		b.custom_minimum_size = Vector2(W / 2.0 - 16.0, 0)
		gf.add_child(b)
	_body.add_child(gf)
	_section("Repères de la médecine")
	for r in SanteDonnees.REPERES:
		_text("%d · %s" % [int(r.annee), String(r.texte)], int(r.annee) > an, 11)
