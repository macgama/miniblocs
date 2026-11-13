class_name DechetsPanel
extends CanvasLayer
## Panneau « Déchets » (touche X) : bilan de la ville (production, collecte,
## recyclage, sacs qui débordent), installations et leur état (recouvrir une
## décharge pleine), bennes en tournée.

signal focus_requested(pos: Vector3)

const W := 348.0
const H := 560.0

var dec: Dechets
var view := "ville"
var _panel: PanelContainer
var _title: Label
var _body: VBoxContainer
var _scroll: ScrollContainer
var _tick := 0.0


func setup(d: Dechets) -> void:
	dec = d
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
	icon.texture = Icones.get_icon("dechets", 22, UiStyle.ACCENT)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	head.add_child(icon)
	_title = Label.new()
	_title.text = "Déchets"
	_title.add_theme_font_size_override("font_size", 16)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	var x := UiStyle.icon_button("fermer", "Fermer", "X", 18, 32)
	x.pressed.connect(func() -> void: set_open(false))
	head.add_child(x)
	var tabs := HBoxContainer.new()
	outer.add_child(tabs)
	for spec in [["Ville", "ville", "dechets"], ["Installations", "sites", "industrie"], ["Tournées", "tournees", "vehicules"]]:
		var b := Button.new()
		b.text = spec[0]
		b.icon = Icones.get_icon(spec[2], 18)
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
	if k and k.pressed and not k.echo and k.physical_keycode == KEY_X and not k.shift_pressed and not k.ctrl_pressed and not k.alt_pressed:
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
	if _tick >= 1.0:
		_tick = 0.0
		var keep := _scroll.scroll_vertical
		refresh()
		_scroll.set_deferred("scroll_vertical", keep)


func refresh() -> void:
	if dec == null:
		return
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	match view:
		"sites": _view_sites()
		"tournees": _view_tours()
		_: _view_city()


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
	l.add_theme_color_override("font_color", Color("ffd166"))


func _swatch(c: Color) -> Texture2D:
	var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	img.fill(c)
	return ImageTexture.create_from_image(img)


func _link(t: String, col: Color, pos: Vector3, extra: Control = null) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 12)
	b.custom_minimum_size = Vector2(W - 30, 0)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.text = t
	b.icon = _swatch(col)
	b.tooltip_text = "Clique pour y aller."
	b.pressed.connect(func() -> void: focus_requested.emit(pos))
	_body.add_child(b)
	if extra != null:
		_body.add_child(extra)
	return b


func _bar(frac: float, col: Color) -> void:
	var p := ProgressBar.new()
	p.min_value = 0.0
	p.max_value = 1.0
	p.value = clampf(frac, 0.0, 1.0)
	p.show_percentage = false
	p.custom_minimum_size = Vector2(W - 30, 8)
	var fill := StyleBoxFlat.new()
	fill.bg_color = col
	p.add_theme_stylebox_override("fill", fill)
	_body.add_child(p)


static func t_(v: float) -> String:
	if v >= 100.0:
		return "%d t" % roundi(v)
	if v >= 1.0:
		return "%.1f t" % v
	return "%d kg" % roundi(v * 1000.0)


# --- Ville ---------------------------------------------------------------------------------------

func _view_city() -> void:
	_title.text = "Déchets · la ville"
	if not Dechets.actif():
		_text("Les déchets sont coupés dans les réglages de la partie (Admin, F10) : la ville reste propre toute seule.", true)
		return
	var b := dec.bilan()
	_section("Hier")
	_text("Produits : %s · ramassés : %s · tournées : %d" % [t_(float(b.produit)), t_(float(b.collecte)), int(b.tournees)])
	_text("Enfouis : %s · brûlés : %s · triés : %s · compostés : %s" % [t_(float(b.enfoui)), t_(float(b.brule)), t_(float(b.trie)), t_(float(b.composte))])
	_text("Recyclés et compostés : %d %% des déchets traités" % roundi(float(b.taux_recyclage) * 100.0))
	_bar(float(b.taux_recyclage), Color("52b788"))
	if float(b.mwh) > 0.0:
		_text("Électricité de l'incinération : %.0f MWh" % float(b.mwh), true)
	_section("Dans les bacs en ce moment")
	var w: Dictionary = b.en_attente
	for f in Dechets.FLUX:
		var r := HBoxContainer.new()
		var tr := TextureRect.new()
		tr.texture = _swatch(Dechets.FLUX_COLORS[f])
		tr.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		r.add_child(tr)
		var l := Label.new()
		l.text = "%s : %s" % [String(Dechets.FLUX_NAMES[f]), t_(float(w[f]))]
		l.add_theme_font_size_override("font_size", 13)
		r.add_child(l)
		_body.add_child(r)
	var deb := dec.overflowing()
	if deb.is_empty():
		_text("Aucun sac sur les trottoirs.", true)
	else:
		_section("Poubelles qui débordent (%d)" % deb.size())
		_text("Sacs devant la porte (%s en tout) : habitants mécontents, rue sale." % t_(float(w.sacs)), true)
		deb.sort_custom(func(a: int, c: int) -> bool: return float(dec.bacs[a].deb) > float(dec.bacs[c].deb))
		for i in mini(deb.size(), 12):
			var bid: int = deb[i]
			_link("%s — %s de sacs" % [dec.building_name(bid), t_(float(dec.bacs[bid].deb) / 1000.0)], Color("e63946"), dec._pos_of(bid))
	_section("Conseils")
	for c in conseils():
		_text("• " + c, true)


## Ce qui manque à la ville, en phrases simples.
func conseils() -> Array[String]:
	var out: Array[String] = []
	if dec.sites_of("depot").is_empty():
		out.append("Aucun dépôt de collecte : personne ne ramasse les poubelles (Construire → Déchets).")
	if dec.sites_of("decharge").is_empty() and dec.sites_of("incinerateur").is_empty():
		out.append("Ni décharge ni incinérateur : les bennes n'ont nulle part où vider les ordures.")
	else:
		var open := false
		for bid in dec.sites_of("decharge"):
			open = open or not bool(dec.sites[bid].plein)
		if not open and dec.sites_of("incinerateur").is_empty():
			out.append("Toutes les décharges sont pleines : recouvre-les et construis-en une autre, ou un incinérateur.")
	if dec.sites_of("tri").is_empty():
		out.append("Sans centre de tri, les habitants ne trient pas : tout part à la décharge.")
	elif dec.sites_of("decheterie").is_empty():
		out.append("Une déchèterie fait mieux trier les habitants à moins de 4 km.")
	if not dec.sites_of("tri").is_empty() and dec.sites_of("recyclage").is_empty():
		out.append("Une usine de recyclage transforme les balles du centre de tri en papier, plastique et acier.")
	for bid in dec.sites_of("depot"):
		if String(dec.sites[bid].status).begins_with("Aucun éboueur") or String(dec.sites[bid].status).begins_with("Pas assez"):
			out.append("Dépôt sans éboueurs de service : il faut des habitants pour ces emplois.")
			break
	if out.is_empty():
		out.append("Tout va bien : les bennes passent et les déchets sont traités.")
	return out


# --- Installations ----------------------------------------------------------------------------------

const ROLE_ORDER := ["depot", "decheterie", "tri", "recyclage", "compost", "incinerateur", "decharge", "decharge_fermee"]
const ROLE_COLORS := {"depot": Color("43aa8b"), "decheterie": Color("90be6d"), "tri": Color("ffd166"), "recyclage": Color("4895ef"),
	"compost": Color("6f4e37"), "incinerateur": Color("e76f51"), "decharge": Color("8a7458"), "decharge_fermee": Color("6aa84f")}


func _view_sites() -> void:
	_title.text = "Déchets · installations"
	if dec.sites.is_empty():
		_text("Aucune installation. Pose un dépôt de collecte et une décharge au bord d'une route (Construire → Déchets).", true)
		return
	for role in ROLE_ORDER:
		for bid in dec.sites_of(role):
			var s: Dictionary = dec.sites[bid]
			var spec := DechetsTypes.spec_of(dec._type_of(bid))
			var line := "%s\n%s" % [dec.building_name(bid), String(s.status) if String(s.status) != "" else "—"]
			match role:
				"depot":
					line += "\nBennes : %d dehors sur %d · éboueurs de service : %s" % [dec.trucks_out(bid), (s.units as Array).size(),
						"tous" if dec.crew_on_duty(bid, dec.clock) >= 999 else str(dec.crew_on_duty(bid, dec.clock))]
				"incinerateur":
					line += "\nEn attente : %s" % t_(float(s.st.om))
				"tri":
					line += "\nEn attente : %s de recyclables, %s de verre" % [t_(float(s.st.rec)), t_(float(s.st.verre))]
				"compost":
					line += "\nEn attente : %s de déchets verts" % t_(float(s.st.verts))
				"decharge", "decharge_fermee":
					line += "\nEnfoui : %s" % t_(float(s.total))
			var extra: Control = null
			if role == "decharge":
				var cap := float(spec.get("capacite", 100000.0))
				var row := HBoxContainer.new()
				var p := ProgressBar.new()
				p.max_value = 1.0
				p.value = clampf(float(s.total) / cap, 0.0, 1.0)
				p.show_percentage = false
				p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				p.custom_minimum_size = Vector2(0, 8)
				row.add_child(p)
				var b := Button.new()
				b.text = "Recouvrir (%s)" % BuildingSystem.format_short(ReglagesPartie.prix(Dechets.COUT_RECOUVRIR))
				b.focus_mode = Control.FOCUS_NONE
				b.add_theme_font_size_override("font_size", 12)
				b.tooltip_text = "Fermer la décharge : terre, herbe et arbustes. Elle ne reçoit plus rien et pollue beaucoup moins."
				var id: int = bid
				b.pressed.connect(func() -> void:
					dec.recouvrir(id)
					refresh())
				row.add_child(b)
				extra = row
			_link(line, ROLE_COLORS.get(role, Color.WHITE), dec._pos_of(bid), extra)


# --- Tournées -------------------------------------------------------------------------------------

func _view_tours() -> void:
	_title.text = "Déchets · tournées"
	if dec.missions.is_empty():
		_text("Aucune benne dehors. Les tournées partent des dépôts entre 5 h et 12 h, du lundi au samedi, quand les bacs se remplissent.", true)
	for mid in dec.missions:
		var m: Dictionary = dec.missions[mid]
		var done := 0
		for st in m.stops:
			if bool(st.done):
				done += 1
		var phase := "porte à porte" if done < (m.stops as Array).size() else ("vers %s" % dec.building_name(int(m.dest)) if not bool(m.unloaded) else "rentre au dépôt")
		var pos := dec._pos_of(int(m.depot))
		for st in m.stops:
			if not bool(st.done):
				pos = dec._pos_of(int(st.bid))
				break
		_link("Benne %s — %s\n%d arrêts sur %d · %s chargés" % [String(Dechets.FLUX_NAMES[m.flux]).to_lower(), phase, done,
			(m.stops as Array).size(), t_(float(m.kg) / 1000.0)], Dechets.FLUX_COLORS[m.flux], pos)
	_section("Sur la route")
	_text("%d benne%s visible%s dans la circulation." % [dec.trucks_on_road(), "s" if dec.trucks_on_road() > 1 else "", "s" if dec.trucks_on_road() > 1 else ""], true)
