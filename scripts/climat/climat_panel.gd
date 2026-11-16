class_name ClimatPanel
extends CanvasLayer
## Panneau « Climat et pollution » (Maj+F7, menu Infos) : bilan carbone par secteur,
## réchauffement et montée de la mer, mix électrique, sols pollués, et mesures
## du plan climat (datées selon l'époque).

signal focus_requested(pos: Vector3)

const W := 420.0
const H := 560.0
const VERT := Color("7bd389")
const ROUGE := Color("ff8c8c")

var cl: Climat
var view := "bilan"
var _panel: PanelContainer
var _body: VBoxContainer
var _scroll: ScrollContainer
var _tick := 0.0


func setup(c: Climat) -> void:
	cl = c
	_build()
	cl.changed.connect(func() -> void:
		if is_open():
			_tick = 1.9)


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
	icon.texture = Icones.get_icon("climat", 22, UiStyle.ACCENT)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	head.add_child(icon)
	var title := Label.new()
	title.text = "Climat et pollution"
	title.add_theme_font_size_override("font_size", 16)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var x := UiStyle.icon_button("fermer", "Fermer", "Maj+F7", 18, 32)
	x.pressed.connect(func() -> void: set_open(false))
	head.add_child(x)
	var tabs := HBoxContainer.new()
	outer.add_child(tabs)
	for spec in [["Bilan", "bilan"], ["Climat", "climat"], ["Énergie", "energie"], ["Sols", "sols"], ["Mesures", "mesures"]]:
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
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.keycode == KEY_F7 and k.shift_pressed and not k.ctrl_pressed and not k.alt_pressed:
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
	if cl == null:
		return
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	match view:
		"climat": _view_climat()
		"energie": _view_energie()
		"sols": _view_sols()
		"mesures": _view_mesures()
		_: _view_bilan()


# --- Bilan ------------------------------------------------------------------------------------

func _view_bilan() -> void:
	var m := cl.moyenne()
	var tot := Climat.total(m.t)
	_section("Bilan carbone", "climat")
	if cl.jours.is_empty():
		_text("Le premier bilan arrive à minuit (heure du jeu).", true)
		return
	_text("%s t de CO₂ par jour (moyenne de la semaine), %s t par habitant et par an." % [_n(tot), _d(cl.par_habitant())], false, 14)
	var ref := ClimatTypes.courbe(ClimatTypes.INTENSITE_EPOQUE, Climat.annee_en_cours())
	var ph := cl.par_habitant()
	if ph > 0.0:
		_text("Un pays industrialisé de l'époque : %s t par habitant. %s" % [_d(ref),
			"Vos villes font mieux." if ph < ref * 0.9 else ("Vos villes font pire." if ph > ref * 1.1 else "Vos villes sont dans la moyenne.")], true)
	var maxi := 0.0
	for k in m.t:
		maxi = maxf(maxi, absf(float(m.t[k])))
	for k in ClimatTypes.ORDRE_SECTEURS:
		var v := float(m.t.get(k, 0.0))
		if absf(v) < 0.05:
			continue
		var s: Dictionary = ClimatTypes.SECTEURS[k]
		_jauge(String(s.nom), "%s t/j" % _n(v), s.couleur)
		_bar(absf(v) / maxf(maxi, 0.001), s.couleur)
	_section("Depuis le début", "courbe")
	_text("%s t de CO₂ émises (net) depuis le début de la partie." % _n(cl.cumul))
	var cles := cl.annees.keys()
	cles.sort_custom(func(p, q) -> bool: return int(p) > int(q))
	for c in cles.slice(0, 6):
		var an: Dictionary = cl.annees[c]
		var f := 365.0 / maxf(float(an.get("jours", 1)), 1.0)
		_text("%s : %s t/an (%d habitants)" % [c, _n(Climat.total(an.t) * f), int(an.get("pop", 0))], true, 12)


# --- Climat -----------------------------------------------------------------------------------

func _view_climat() -> void:
	var y := Climat.annee_en_cours()
	_section("Réchauffement en %d" % floori(y), "thermometre")
	if Climat.reglage() == 0:
		_text("Réchauffement désactivé (Admin F10) : la météo ne change pas avec les années.", true)
	var e := cl.ecart_monde if not is_nan(cl.ecart_monde) else 0.0
	_text("%s °C par rapport à l'époque préindustrielle (1850-1900)." % _signe(e), false, 15,
		VERT if e < 1.0 else (UiStyle.ACCENT if e < 2.0 else ROUGE))
	_text("Ici, la météo est décalée de %s °C par rapport à aujourd'hui, dont %s °C d'îlot de chaleur urbain." % [_signe(cl.ecart_local), _d(cl.ilot)], true)
	if y > ClimatTypes.ANNEE_PRESENT or Climat.reglage() == 2:
		_text("Le monde suit un scénario %s (vos villes : %s t de CO₂ par habitant et par an)." % [ClimatTypes.nom_scenario(cl.scenario_s),
			_d(cl.intensite if not is_nan(cl.intensite) else 0.0)], true)
	_text("Canicules, sécheresses, crues et feux : ×%s de risques." % String.num(Climat.facteur_extremes(), 2).replace(".", ","), true)
	var g := Graphe.new()
	g.points = _serie("ecart")
	g.unite = "°C"
	g.couleur = Color("e76f51")
	_body.add_child(g)
	_section("La mer monte", "eau")
	_text("+%s depuis 1900 (%s cm de plus qu'aujourd'hui)." % [Climat._cm(cl.mer_cm if not is_nan(cl.mer_cm) else 0.0),
		String.num(cl.hausse_mer_m() * 100.0, 0)])
	if cl.menaces.is_empty():
		_text("Aucun bâtiment n'est assez bas pour être menacé par la mer.", true)
	else:
		_text("%d bâtiment%s trop bas : une grosse tempête peut les inonder (submersions : %d)." % [cl.menaces.size(),
			"s" if cl.menaces.size() > 1 else "", cl.submersions], false, 13, ROUGE)
		var p0: Vector3 = cl.evenements.building_pos(int(cl.menaces[0])) if cl.evenements != null else Vector3.ZERO
		_button("Voir le quartier menacé", "loupe", func() -> void: focus_requested.emit(p0))
	_section("Grandes dates", "journal")
	for h in ClimatTypes.HISTOIRE_CLIMAT:
		if float(h[0]) <= y:
			_text("%d : %s" % [int(h[0]), String(h[1])], true, 12)


func _serie(cle: String) -> PackedVector2Array:
	var out := PackedVector2Array()
	var cles := cl.annees.keys()
	cles.sort_custom(func(p, q) -> bool: return int(p) < int(q))
	for c in cles:
		var an: Dictionary = cl.annees[c]
		if an.has(cle):
			out.append(Vector2(float(c), float(an[cle])))
	return out


# --- Énergie ----------------------------------------------------------------------------------

func _view_energie() -> void:
	var y := Climat.annee_en_cours()
	var m := cl.moyenne()
	_section("Mix électrique", "reseaux")
	var tot := 0.0
	for f in m.mix:
		tot += float(m.mix[f])
	if tot <= 0.0:
		_text("Pas encore d'électricité produite ou achetée." if y >= 1882.0 else "L'électricité n'est pas encore inventée : lampes à huile, bougies et poêles à bois.", true)
	else:
		_text("%s MWh par jour, %s g de CO₂ par kWh, %d %% bas carbone." % [_n(tot), _n(cl.intensite_elec()), roundi(cl.part_bas_carbone() * 100.0)], false, 14)
		for f in ClimatTypes.ORDRE_FILIERES:
			var v := float(m.mix.get(f, 0.0))
			if v <= 0.0:
				continue
			var fi: Dictionary = ClimatTypes.FILIERES[f]
			_jauge(String(fi.nom), "%d %%" % roundi(v / tot * 100.0), fi.couleur)
			_bar(v / tot, fi.couleur)
	_text("Réseau national (%s) : %s g de CO₂ par kWh en %d." % [GameStart.pays.to_upper() if GameStart.pays != "" else "pays",
		_n(ClimatTypes.intensite_nationale(y, GameStart.pays, cl.scenario_s) * 1000.0), floori(y)], true)
	_section("Ce que chaque filière émet", "industrie")
	for f in ClimatTypes.ORDRE_FILIERES:
		if f in ["national", "autre"]:
			continue
		_text("%s : %s g/kWh" % [String(ClimatTypes.FILIERES[f].nom), _n(float(ClimatTypes.FILIERES[f].co2) * 1000.0)], true, 12)
	_text("Les centrales arrivent avec leur époque : charbon dès 1882, barrages, gaz, nucléaire en 1960, éoliennes en 1990, solaire ensuite (Construire → Réseaux).", true, 12)


# --- Sols -------------------------------------------------------------------------------------

func _view_sols() -> void:
	_section("Sols pollués", "climat")
	if not ReglagesPartie.actuel.sols_pollues:
		_text("Désactivé dans l'Admin (F10).", true)
		return
	var ha := cl.sols_pollues_ha()
	_text("%s ha de sols pollués." % _d(ha), false, 14, VERT if ha < 1.0 else (UiStyle.ACCENT if ha < 20.0 else ROUGE))
	_text("Usines, mines, décharges et pesticides salissent le sol pendant des années : récoltes plus maigres (jusqu'à −50 %), habitants plus souvent malades, terrains moins chers. Carte « Sols pollués » dans N.", true)
	var pts := cl.points_noirs()
	if pts.is_empty():
		_text("Aucun point noir.", true)
	for p in pts:
		var pos: Vector3 = p.pos
		_button("%d %% de pollution près de (%d, %d)" % [roundi(float(p.v) * 100.0), roundi(pos.x), roundi(pos.z)], "loupe",
			func() -> void: focus_requested.emit(pos))
	if not cl.a("depollution"):
		_text("La mesure « Dépollution des sols » (onglet Mesures) les fait guérir dix fois plus vite.", true)


# --- Mesures ----------------------------------------------------------------------------------

func _view_mesures() -> void:
	var y := Epoques.annee()
	_section("Plan climat", "urne")
	_text("Coûts payés chaque jour par la caisse de la ville (panneau Budget, M).", true)
	for id in ClimatTypes.ORDRE_MESURES:
		var m: Dictionary = ClimatTypes.MESURES[id]
		var on := cl.a(id)
		var dispo := ClimatTypes.mesure_disponible(id, y)
		_body.add_child(HSeparator.new())
		_text(String(m.nom), false, 14, VERT if on else (UiStyle.TEXT if dispo else UiStyle.TEXT_DIM))
		_text(String(m.desc), true, 12)
		var c := cl.cout_mesure(id)
		if not dispo:
			_text("Pas encore possible : arrive en %d." % int(m.annee), true, 12)
			continue
		var prix := "gratuit" if c <= 0.0 else "%s/mois" % BuildingSystem.format_money(roundi(c))
		var mid: String = id
		if on:
			_button("En vigueur depuis %d (%s) · abandonner" % [int(cl.mesures[id]), prix], "fermer", func() -> void:
				cl.abandonner(mid)
				refresh())
		else:
			_button("Adopter (%s)" % prix, "ok", func() -> void:
				cl.adopter(mid)
				refresh())


# --- Petits outils ----------------------------------------------------------------------------

func _text(t: String, dim := false, size := 13, color := Color.TRANSPARENT) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(W - 30, 0)
	l.add_theme_font_size_override("font_size", size)
	if dim:
		l.add_theme_color_override("font_color", Color(1, 1, 1, 0.65))
	if color.a > 0.0:
		l.add_theme_color_override("font_color", color)
	_body.add_child(l)
	return l


func _section(t: String, icon := "") -> void:
	_body.add_child(HSeparator.new())
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 4)
	_body.add_child(r)
	if icon != "" and Icones.SVG.has(icon):
		var ic := TextureRect.new()
		ic.texture = Icones.get_icon(icon, 18, UiStyle.ACCENT)
		ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		r.add_child(ic)
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", UiStyle.ACCENT)
	r.add_child(l)


func _button(t: String, icon: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	if icon != "" and Icones.SVG.has(icon):
		b.icon = Icones.get_icon(icon, 16)
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 12)
	b.pressed.connect(cb)
	_body.add_child(b)
	return b


func _bar(v: float, col: Color) -> void:
	var p := ProgressBar.new()
	p.min_value = 0.0
	p.max_value = 1.0
	p.value = clampf(v, 0.0, 1.0)
	p.show_percentage = false
	p.custom_minimum_size = Vector2(W - 30, 7)
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(3)
	p.add_theme_stylebox_override("fill", sb)
	_body.add_child(p)


func _jauge(titre: String, valeur: String, col: Color) -> void:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 4)
	_body.add_child(r)
	var dot := ColorRect.new()
	dot.color = col
	dot.custom_minimum_size = Vector2(10, 10)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.add_child(dot)
	var l := Label.new()
	l.text = titre
	l.add_theme_font_size_override("font_size", 13)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(l)
	var v := Label.new()
	v.text = valeur
	v.add_theme_font_size_override("font_size", 13)
	r.add_child(v)


static func _n(v: float) -> String:
	var s := String.num(absf(v), 1 if absf(v) < 10.0 else 0).replace(".", ",")
	var i := s.find(",")
	var entier := s if i < 0 else s.substr(0, i)
	var reste := "" if i < 0 else s.substr(i)
	var out := ""
	while entier.length() > 3:
		out = " " + entier.substr(entier.length() - 3) + out
		entier = entier.substr(0, entier.length() - 3)
	return ("−" if v < 0.0 else "") + entier + out + reste


static func _d(v: float) -> String:
	return String.num(v, 1).replace(".", ",")


static func _signe(v: float) -> String:
	return ("+" if v >= 0.0 else "−") + String.num(absf(v), 2).replace(".", ",")


## Petit graphique d'une série (année, valeur).
class Graphe:
	extends Control
	var points := PackedVector2Array()
	var unite := ""
	var couleur := Color.WHITE

	func _init() -> void:
		custom_minimum_size = Vector2(380, 120)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.04))
		var font := get_theme_default_font()
		if points.size() < 2:
			draw_string(font, Vector2(8, size.y / 2.0), "La courbe se dessine au fil des années.", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.6))
			return
		var x0 := points[0].x
		var x1 := points[points.size() - 1].x
		var y0 := INF
		var y1 := -INF
		for p in points:
			y0 = minf(y0, p.y)
			y1 = maxf(y1, p.y)
		if y1 - y0 < 0.2:
			y0 -= 0.1
			y1 += 0.1
		var m := Vector2(34, 14)
		var w := size.x - m.x - 6
		var h := size.y - m.y - 6
		var to := func(p: Vector2) -> Vector2:
			return Vector2(m.x + (p.x - x0) / maxf(x1 - x0, 0.001) * w, 6 + h - (p.y - y0) / (y1 - y0) * h)
		var pl := PackedVector2Array()
		for p in points:
			pl.append(to.call(p))
		draw_polyline(pl, couleur, 2.0, true)
		draw_string(font, Vector2(2, 14), String.num(y1, 1) + unite, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.6))
		draw_string(font, Vector2(2, 6 + h), String.num(y0, 1) + unite, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.6))
		draw_string(font, Vector2(m.x, size.y - 1), str(int(x0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.6))
		draw_string(font, Vector2(size.x - 34, size.y - 1), str(int(x1)), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.6))
