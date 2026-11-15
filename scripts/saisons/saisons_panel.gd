class_name SaisonsPanel
extends CanvasLayer
## Panneau « Saisons et risques » (Maj+R, menu Infos) : saison en cours,
## prévisions, records ; vigilances neige, crues, sécheresse, canicule ;
## déneigement (centres techniques, chasse-neige, sel) ; calendrier des
## cultures du lieu.

signal focus_requested(pos: Vector3)
signal build_requested(type_id: String)

const W := 400.0
const H := 560.0
const VERT := Color("7bd389")
const ROUGE := Color("ff8c8c")
const MOIS := ["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"]
const MOIS_LONGS := ["janvier", "février", "mars", "avril", "mai", "juin", "juillet", "août", "septembre", "octobre", "novembre", "décembre"]

var sa: Saisons
var view := "meteo"
var _panel: PanelContainer
var _title: Label
var _body: VBoxContainer
var _scroll: ScrollContainer
var _tick := 0.0


func setup(s: Saisons) -> void:
	sa = s
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
	icon.texture = Icones.get_icon("saisons", 22, UiStyle.ACCENT)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	head.add_child(icon)
	_title = Label.new()
	_title.text = "Saisons et risques"
	_title.add_theme_font_size_override("font_size", 16)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	var x := UiStyle.icon_button("fermer", "Fermer", "Maj+R", 18, 32)
	x.pressed.connect(func() -> void: set_open(false))
	head.add_child(x)
	var tabs := HBoxContainer.new()
	outer.add_child(tabs)
	for spec in [["Météo", "meteo"], ["Risques", "risques"], ["Déneigement", "neige"], ["Cultures", "cultures"]]:
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
	if k and k.pressed and not k.echo and k.physical_keycode == KEY_R and k.shift_pressed and not k.ctrl_pressed and not k.alt_pressed:
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
	if sa == null:
		return
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	match view:
		"risques": _view_risques()
		"neige": _view_neige()
		"cultures": _view_cultures()
		_: _view_meteo()


# --- Petits outils ---------------------------------------------------------------------

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
	var r := _row()
	if icon != "":
		var ic := TextureRect.new()
		ic.texture = Icones.get_icon(icon, 18, UiStyle.ACCENT)
		ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		r.add_child(ic)
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", UiStyle.ACCENT)
	r.add_child(l)


func _row() -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 4)
	_body.add_child(r)
	return r


func _button(t: String, icon: String, cb: Callable, tip := "") -> Button:
	var b := Button.new()
	b.text = t
	if icon != "":
		b.icon = Icones.get_icon(icon, 16)
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = tip
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 12)
	b.pressed.connect(cb)
	_body.add_child(b)
	return b


func _bar(v: float, col := Color.TRANSPARENT) -> void:
	var p := ProgressBar.new()
	p.min_value = 0.0
	p.max_value = 1.0
	p.value = clampf(v, 0.0, 1.0)
	p.show_percentage = false
	p.custom_minimum_size = Vector2(W - 30, 7)
	if col.a > 0.0:
		var sb := StyleBoxFlat.new()
		sb.bg_color = col
		sb.set_corner_radius_all(3)
		p.add_theme_stylebox_override("fill", sb)
	_body.add_child(p)


## Ligne « pastille de couleur + titre + valeur ».
func _jauge(titre: String, valeur: String, col: Color) -> void:
	var r := _row()
	var dot := ColorRect.new()
	dot.color = col
	dot.custom_minimum_size = Vector2(12, 12)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.add_child(dot)
	var a := Label.new()
	a.text = titre
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	a.add_theme_font_size_override("font_size", 13)
	r.add_child(a)
	var b := Label.new()
	b.text = valeur
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_color_override("font_color", col)
	r.add_child(b)


static func _n(x: float) -> String:
	return Saisons._num(x)


func _date_txt(j: int) -> String:
	if j < 0:
		return "—"
	var d := Time.get_datetime_dict_from_unix_time(j * 86400)
	return "%d %s %d" % [int(d.day), MOIS_LONGS[int(d.month) - 1], int(d.year)]


# --- Météo ---------------------------------------------------------------------------------

func _view_meteo() -> void:
	var d := sa.date_locale(sa.now())
	_title.text = "Saisons et risques"
	var r := _row()
	var ic := TextureRect.new()
	ic.texture = Icones.get_icon(sa.icone_saison(), 40, UiStyle.ACCENT)
	r.add_child(ic)
	var v := VBoxContainer.new()
	r.add_child(v)
	var l1 := Label.new()
	l1.text = "%s · %d %s" % [sa.nom_saison(), int(d.day), MOIS_LONGS[int(d.month) - 1]]
	l1.add_theme_font_size_override("font_size", 18)
	v.add_child(l1)
	var l2 := Label.new()
	l2.text = "Climat %s · hémisphère %s" % [Plantes.CLIMAT_NOMS[sa.climat()], "nord" if sa.lat() >= 0.0 else "sud"]
	l2.add_theme_font_size_override("font_size", 12)
	l2.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	v.add_child(l2)
	if not sa.tropical():
		var av := sa.avancement_saison()
		_bar(av.x)
		_text("Encore %d jours avant la saison suivante." % int(av.y), true, 11)
	var w := sa.meteo()
	_section("Aujourd'hui", "meteo")
	if w != null:
		_text("%s · %s · humidité du climat %d %%" % [w.describe(), Saisons._deg(w.temperature), roundi(w.humidity * 100.0)])
	var a := sa.aujourdhui
	if not a.is_empty():
		_text("Depuis minuit : %s mm de pluie%s, de %s à %s." % [_n(float(a.pluie)),
			(", %s cm de neige" % _n(float(a.neige))) if float(a.neige) >= 0.5 else "", Saisons._deg(float(a.tmin)), Saisons._deg(float(a.tmax))], true, 12)
	if sa.world != null and sa.world.neige > 0.05:
		_text("Neige au sol : %d %% du paysage blanc." % roundi(sa.world.neige * 100.0), true, 12)
	var nb := sa.jours_previsions()
	_section("Prévisions sur %d jours" % nb, "nuage")
	if nb < 7:
		_text("Une station météo (Construire → Services publics) donne 7 jours.", true, 11)
	for p in sa.previsions():
		var rr := _row()
		var pi := TextureRect.new()
		pi.texture = Icones.get_icon(String(p.icone), 18)
		pi.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		rr.add_child(pi)
		var lj := Label.new()
		lj.text = String(p.nom)
		lj.custom_minimum_size = Vector2(90, 0)
		lj.add_theme_font_size_override("font_size", 12)
		rr.add_child(lj)
		var lc := Label.new()
		lc.text = String(p.ciel)
		lc.custom_minimum_size = Vector2(80, 0)
		lc.add_theme_font_size_override("font_size", 12)
		rr.add_child(lc)
		var lt := Label.new()
		var extra := ""
		if float(p.neige) >= 1.0:
			extra = " · %s cm" % _n(float(p.neige))
		elif float(p.pluie) >= 1.0:
			extra = " · %s mm" % _n(float(p.pluie))
		lt.text = "%d° / %d°%s" % [roundi(float(p.tmin)), roundi(float(p.tmax)), extra]
		lt.add_theme_font_size_override("font_size", 12)
		lt.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
		rr.add_child(lt)
	var b := sa.bilan(30)
	_section("Les 30 derniers jours", "courbe")
	if b.is_empty():
		_text("Pas encore de relevés : la station note le temps chaque jour.", true, 12)
	else:
		_text("%s mm de pluie (%d jours de pluie), %s cm de neige (%d jours), de %s à %s." % [_n(float(b.pluie)), int(b.jours_pluie),
			_n(float(b.neige)), int(b.jours_neige), Saisons._deg(float(b.tmin)), Saisons._deg(float(b.tmax))], false, 12)
		_courbe()
	var rc := sa.records
	_section("Records de la partie", "trophee")
	if int(rc.tmax_j) < 0:
		_text("Aucun record pour l'instant.", true, 12)
	else:
		_text("Chaleur : %s (%s)\nFroid : %s (%s)\nPluie : %s mm en un jour (%s)\nNeige : %s cm en un jour (%s)" % [
			Saisons._deg(float(rc.tmax)), _date_txt(int(rc.tmax_j)), Saisons._deg(float(rc.tmin)), _date_txt(int(rc.tmin_j)),
			_n(float(rc.pluie)), _date_txt(int(rc.pluie_j)), _n(float(rc.neige)), _date_txt(int(rc.neige_j))], false, 12)


## Petite courbe : barres de pluie et températures des 30 derniers jours.
func _courbe() -> void:
	var c := Control.new()
	c.custom_minimum_size = Vector2(W - 30, 70)
	var js: Array = sa.jours.slice(maxi(0, sa.jours.size() - 30))
	c.draw.connect(func() -> void:
		var wd := c.size.x
		var hd := c.size.y
		c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(1, 1, 1, 0.05))
		if js.is_empty():
			return
		var bw := wd / 30.0
		var lo := 100.0
		var hi := -100.0
		for j in js:
			lo = minf(lo, float(j.tmin))
			hi = maxf(hi, float(j.tmax))
		hi = maxf(hi, lo + 5.0)
		var pts_max := PackedVector2Array()
		var pts_min := PackedVector2Array()
		for i in js.size():
			var j: Dictionary = js[i]
			var x := (30 - js.size() + i) * bw
			var mm := minf(float(j.pluie) / 30.0, 1.0)
			if mm > 0.0:
				c.draw_rect(Rect2(x + 1, hd - mm * hd, bw - 2, mm * hd), Color("4f8fbf", 0.8))
			if float(j.neige) > 0.5:
				c.draw_rect(Rect2(x + 1, 0, bw - 2, 4), Color(1, 1, 1, 0.9))
			pts_max.append(Vector2(x + bw * 0.5, hd - (float(j.tmax) - lo) / (hi - lo) * (hd - 8) - 4))
			pts_min.append(Vector2(x + bw * 0.5, hd - (float(j.tmin) - lo) / (hi - lo) * (hd - 8) - 4))
		if pts_max.size() >= 2:
			c.draw_polyline(pts_max, Color("f4a259"), 1.5)
			c.draw_polyline(pts_min, Color("6ea8fe"), 1.5))
	_body.add_child(c)
	_text("Barres bleues : pluie · orange : température maximale · bleu clair : minimale · blanc : neige.", true, 10)


# --- Risques -------------------------------------------------------------------------------

func _view_risques() -> void:
	_title.text = "Risques naturels"
	# Neige.
	_section("Neige et verglas", "neige")
	var et := sa.etat_routes()
	var vn := 0
	if float(et.moyenne) >= 8.0:
		vn = 3
	elif float(et.moyenne) >= 3.0:
		vn = 2
	elif float(et.part) > 0.0:
		vn = 1
	_jauge("Routes enneigées", "%d %% · %s cm en moyenne" % [roundi(float(et.part) * 100.0), _n(float(et.moyenne))], Saisons.COULEURS_VIGILANCE[vn])
	if not Saisons.neige_active():
		_text("La neige ne tient pas sur les routes (réglage Admin, F10).", true, 11)
	else:
		_text("Sur la neige, tout le monde roule moins vite (−8 % par cm, jusqu'à −70 %), secours compris, et les voitures glissent.", true, 11)
	# Crues.
	_section("Crues", "eau")
	var vc := sa.vigilance_crue
	_jauge("Vigilance crues", Saisons.NOMS_VIGILANCE[vc], Saisons.COULEURS_VIGILANCE[vc])
	_text("Pluie sur 3 jours : %s mm (jaune dès %d mm, orange %d, rouge %d). La fonte rapide des neiges compte aussi." % [
		_n(sa.pluie_jours(3)), int(Saisons.CRUE_JAUNE), int(Saisons.CRUE_ORANGE), int(Saisons.CRUE_ROUGE)], true, 11)
	for e in sa._crues_en_cours():
		var dd: Dictionary = e.data
		_text("Crue en cours : eau à %s m (maximum %s m), %d bâtiments inondés." % [_n(float(dd.niveau)), _n(float(dd.get("niveau_max", 0.0))),
			(dd.get("inondes", []) as Array).size()], false, 12, ROUGE)
		var pos: Vector3 = e.pos
		_button("Aller voir", "lieu", func() -> void: focus_requested.emit(pos))
	var nb := 0
	if sa.buildings != null:
		for bid in sa.buildings.buildings:
			if SaisonsTypes.role_of(String(sa.buildings.buildings[bid].t)) == "retention":
				nb += 1
	_text("Bassins de rétention : %d (chacun −25 %% de hauteur d'eau à moins de 3 km)." % nb, true, 11)
	# Sécheresse.
	_section("Sécheresse", "soleil")
	var ns := sa.niveau_secheresse
	var cs: Color = [Saisons.COULEURS_VIGILANCE[0], Saisons.COULEURS_VIGILANCE[1], Saisons.COULEURS_VIGILANCE[2], Color("f77f00"), Saisons.COULEURS_VIGILANCE[3]][ns]
	_jauge("Niveau de l'arrêté", Saisons.NIVEAUX_SECHERESSE[ns], cs)
	_bar(float(ns) / 4.0, cs)
	_text("%d jours sans vraie pluie. Dès l'alerte, la préfecture impose les restrictions d'eau ; les cultures et les prés souffrent ; en alerte renforcée, feux de broussailles au bord des bois." % int(sa.jours_sans_pluie()), true, 11)
	var r := Reseaux.instance
	if r != null and is_instance_valid(r):
		var on := r.incidents.restrictions
		_button("Restrictions d'eau : %s (cliquer pour %s)" % ["oui" if on else "non", "lever" if on else "imposer"], "eau", func() -> void:
			r.incidents.restrictions = not r.incidents.restrictions
			refresh(), "−20 % d'eau consommée ; les habitants n'aiment pas.")
	# Canicule.
	_section("Canicule", "thermometre")
	var vk := 0
	if sa.canicule:
		vk = 2
	elif sa.jours_chauds > 0:
		vk = 1
	_jauge("Vigilance canicule", ["Verte", "Jaune", "Orange"][vk], Saisons.COULEURS_VIGILANCE[vk])
	_text("%d jour%s de suite à 33 °C ou plus (canicule à partir de 3)." % [sa.jours_chauds, "s" if sa.jours_chauds > 1 else ""], true, 11)
	# Bilan.
	var t: Dictionary = sa.totaux
	_section("Depuis le début de la partie", "infos")
	_text("%d crue%s, %d feu%s de broussailles, %d gelée%s tardive%s, %d accident%s sur la neige." % [
		int(t.crues), "s" if int(t.crues) > 1 else "", int(t.feux), "x" if int(t.feux) > 1 else "", int(t.gels), "s" if int(t.gels) > 1 else "",
		"s" if int(t.gels) > 1 else "", int(t.accidents), "s" if int(t.accidents) > 1 else ""], false, 12)
	_section("Provoquer (bac à sable)", "tempete")
	_text("Pour voir comment la ville s'en sort. Au hasard, ils arrivent selon la météo et le réglage Admin « Catastrophes ».", true, 11)
	_button("Chute de neige (5 cm, puis 3 h de neige)", "neige", func() -> void:
		sa.chute_de_neige(5.0, 3.0)
		refresh())
	_button("Crue de la rivière (vigilance rouge)", "eau", func() -> void:
		sa.declencher_crue(3, false)
		refresh())
	_button("Sécheresse (alerte renforcée)", "soleil", func() -> void:
		sa.forcer_secheresse(3)
		refresh())
	_button("Canicule", "thermometre", func() -> void:
		sa.forcer_canicule()
		refresh())
	_button("Feu de broussailles", "feu", func() -> void:
		sa.feu_de_broussailles()
		refresh())


# --- Déneigement ---------------------------------------------------------------------------

func _view_neige() -> void:
	_title.text = "Déneigement"
	var et := sa.etat_routes()
	_section("Routes", "route")
	_text("%s km de routes · %s km enneigés · %s km salés." % [_n(float(et.km)), _n(float(et.km_neige)), _n(float(et.km_sel))])
	_bar(1.0 - float(et.part), VERT)
	_text("Déneigé depuis le début : %s km, %s t de sel." % [_n(float(sa.totaux.km_deneiges)), _n(float(sa.totaux.sel_t))], true, 11)
	_section("Centres techniques", "chasse_neige")
	if sa.centres.is_empty():
		_text("Aucun centre technique : la neige reste sur les routes jusqu'au redoux. Il en faut un par ville où il neige (2 chasse-neige, 150 t de sel).", false, 12, ROUGE)
	for bid in sa.centres:
		var c: Dictionary = sa.centres[bid]
		var sortis := 0
		for m in c.engins:
			if int(m) > 0:
				sortis += 1
		var cap := sa.sel_max(int(bid))
		_text("%s · %d chasse-neige, %d sur la route · sel %s / %s t" % [sa.evenements.building_name(int(bid)) if sa.evenements != null else "Centre technique",
			(c.engins as Array).size(), sortis, _n(float(c.sel)), _n(cap)], false, 12)
		_bar(float(c.sel) / maxf(cap, 1.0), Color("dee2e6"))
		var pos := sa._pos(int(bid))
		_button("Aller voir", "lieu", func() -> void: focus_requested.emit(pos))
	_button("Construire un centre technique (%s)" % BuildingSystem.format_money(ReglagesPartie.prix(BuildingCatalog.cost("centre_technique"))),
		"construire", func() -> void: build_requested.emit("centre_technique"),
		"Les engins partent dès que la neige tient (1,5 cm), les grands axes d'abord, et salent derrière eux : la neige ne tient plus pendant 12 h.")
	_section("Tournées en cours", "lignes")
	if sa.missions.is_empty():
		_text("Aucun chasse-neige dehors.", true, 12)
	for mid in sa.missions:
		var ms: Dictionary = sa.missions[mid]
		var faits := 0
		for p in ms.parcours:
			if bool(p.fait):
				faits += 1
		_text("Chasse-neige n° %d : %d / %d tronçons, %s km." % [int(mid), faits, (ms.parcours as Array).size(), _n(float(ms.m) / 1000.0)], false, 12)
	_text("Le sel s'achète tout seul (%d € la tonne) quand le dôme est à moitié vide. Entretien : %s par mois et par engin." % [
		int(Saisons.PRIX_SEL_T), BuildingSystem.format_money(int(Saisons.COUT_ENGIN))], true, 11)


# --- Cultures ------------------------------------------------------------------------------

func _view_cultures() -> void:
	_title.text = "Calendrier des cultures"
	var mois := int(sa.date_locale(sa.now()).month)
	_text("Cultures qui poussent ici (climat %s) : quand semer et quand récolter. Les champs suivent ce calendrier tout seuls (Maj+F)." % Plantes.CLIMAT_NOMS[sa.climat()], true, 12)
	var head := _row()
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(130, 0)
	head.add_child(sp)
	for i in 12:
		var l := Label.new()
		l.text = MOIS[i]
		l.custom_minimum_size = Vector2(19, 0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 11)
		if i + 1 == mois:
			l.add_theme_color_override("font_color", UiStyle.ACCENT)
		head.add_child(l)
	for c in sa.calendrier():
		var r := _row()
		var n := Label.new()
		n.text = String(c.nom)
		n.custom_minimum_size = Vector2(130, 0)
		n.clip_text = true
		n.add_theme_font_size_override("font_size", 12)
		r.add_child(n)
		for i in 12:
			var m := i + 1
			var cell := ColorRect.new()
			cell.custom_minimum_size = Vector2(19, 14)
			var se := (c.semis as Array).has(m)
			var re := (c.recolte as Array).has(m)
			cell.color = Color("52b788") if se and not re else (Color("e9c46a") if re and not se else (Color("90be6d") if se else Color(1, 1, 1, 0.06)))
			if m == mois:
				cell.color = cell.color.lightened(0.25)
			cell.tooltip_text = "%s : %s" % [MOIS_LONGS[i], "semis et récolte" if se and re else ("semis" if se else ("récolte" if re else "—"))]
			r.add_child(cell)
	var lg := _row()
	for spec in [[Color("52b788"), "semis"], [Color("e9c46a"), "récolte (ou fauche)"]]:
		var dot := ColorRect.new()
		dot.color = spec[0]
		dot.custom_minimum_size = Vector2(12, 12)
		lg.add_child(dot)
		var l2 := Label.new()
		l2.text = String(spec[1]) + "   "
		l2.add_theme_font_size_override("font_size", 11)
		lg.add_child(l2)
	_section("La météo et les récoltes", "agriculture")
	_text("• Gelée tardive au printemps (−1,5 °C et moins) : les jeunes pousses perdent 15 % de récolte.\n• Grêle sous les orages : 10 à 35 % de perte.\n• Sécheresse : chaque jour en alerte, les cultures perdent un peu (le maïs et le riz deux fois plus) et les prés donnent moins d'herbe.\n• Crue : les champs au bord de la rivière perdent 60 % de leur récolte.\n• Pluie : on ne sème, ne traite ni ne récolte sous l'averse.", false, 12)
