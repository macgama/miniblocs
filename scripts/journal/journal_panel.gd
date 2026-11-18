class_name JournalPanel
extends CanvasLayer
## Le journal de la ville à l'écran (F4, menu Infos) : une page de journal sur
## papier, à la mise en page de son époque. Flèches : éditions précédentes.
## Un titre souligné emmène la caméra sur place ; un nom d'habitant ouvre sa fiche.

signal focus_requested(pos: Vector3)
signal person_requested(pid: int)

const W := 1040.0
## Hauteur : entre la barre du haut (68 px) et celle des catégories (en bas, ≈ 794 px).
const H := 700.0
const COL_DROITE := 300.0
const JOURS_FR := ["dimanche", "lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi"]
const MOIS_FR := ["janvier", "février", "mars", "avril", "mai", "juin", "juillet", "août", "septembre", "octobre", "novembre", "décembre"]
const JOURS_EN := ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
const MOIS_EN := ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
## Autres langues : [jours, mois, format] ; format reçoit jour de semaine, jour, mois, année.
const DATES := {
	"de": [["Sonntag", "Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag"],
		["Januar", "Februar", "März", "April", "Mai", "Juni", "Juli", "August", "September", "Oktober", "November", "Dezember"],
		"%s, %d. %s %d"],
	"it": [["domenica", "lunedì", "martedì", "mercoledì", "giovedì", "venerdì", "sabato"],
		["gennaio", "febbraio", "marzo", "aprile", "maggio", "giugno", "luglio", "agosto", "settembre", "ottobre", "novembre", "dicembre"],
		"%s %d %s %d"],
	"es": [["domingo", "lunes", "martes", "miércoles", "jueves", "viernes", "sábado"],
		["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"],
		"%s, %d de %s de %d"],
}

var journal: Journal
## Édition affichée (indice dans journal.editions ; -1 = la dernière).
var index := -1
var _panel: PanelContainer
var _scroll: ScrollContainer
var _page: VBoxContainer
var _prec: Button
var _suiv: Button
var _num: Label
var _der: Button
var _fermer: Button
var _fonts := {}
var _ep: Dictionary = {}


func setup(j: Journal) -> void:
	journal = j
	_build()
	journal.edition_parue.connect(func(_ed: Dictionary) -> void:
		if is_open() and index < 0:
			refresh())


func _font(gras := false, italique := false) -> Font:
	var cle := "%s%s" % [gras, italique]
	if _fonts.has(cle):
		return _fonts[cle]
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Georgia", "Times New Roman", "Liberation Serif", "DejaVu Serif", "Noto Serif", "serif"])
	f.font_weight = 700 if gras else 400
	f.font_italic = italique
	_fonts[cle] = f
	return f


func _build() -> void:
	layer = 7
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -W / 2.0
	_panel.offset_right = W / 2.0
	_panel.offset_top = -H / 2.0 - 10.0
	_panel.offset_bottom = H / 2.0 - 10.0
	_panel.visible = false
	add_child(_panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 4)
	_panel.add_child(outer)
	# Barre d'outils (hors de la page) : éditions et fermeture.
	var bar := HBoxContainer.new()
	outer.add_child(bar)
	_prec = UiStyle.icon_button("precedent", "Édition précédente", "", 18, 30)
	_prec.pressed.connect(func() -> void: _aller(-1))
	bar.add_child(_prec)
	_num = Label.new()
	_num.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_num.add_theme_font_size_override("font_size", 13)
	bar.add_child(_num)
	_suiv = UiStyle.icon_button("suivant", "Édition suivante", "", 18, 30)
	_suiv.pressed.connect(func() -> void: _aller(1))
	bar.add_child(_suiv)
	_der = Button.new()
	_der.text = "Aujourd'hui"
	_der.flat = true
	_der.focus_mode = Control.FOCUS_NONE
	_der.pressed.connect(func() -> void:
		index = -1
		refresh())
	bar.add_child(_der)
	var esp := Control.new()
	esp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(esp)
	_fermer = UiStyle.icon_button("fermer", "Fermer", "F4", 18, 30)
	_fermer.pressed.connect(func() -> void: set_open(false))
	bar.add_child(_fermer)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(_scroll)
	var marge := MarginContainer.new()
	marge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for c in ["margin_left", "margin_right"]:
		marge.add_theme_constant_override(c, 26)
	marge.add_theme_constant_override("margin_top", 14)
	marge.add_theme_constant_override("margin_bottom", 18)
	_scroll.add_child(marge)
	_page = VBoxContainer.new()
	_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page.add_theme_constant_override("separation", 6)
	marge.add_child(_page)


func is_open() -> bool:
	return _panel.visible


func set_open(on: bool) -> void:
	_panel.visible = on
	if on:
		index = -1
		refresh()


func toggle() -> void:
	set_open(not _panel.visible)


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.keycode == KEY_F4 and not k.ctrl_pressed and not k.alt_pressed and not k.shift_pressed:
		toggle()
		get_viewport().set_input_as_handled()
	elif is_open() and k.keycode == KEY_ESCAPE:
		set_open(false)
		get_viewport().set_input_as_handled()


func _aller(d: int) -> void:
	var n := journal.editions.size()
	if n == 0:
		return
	var i := (n - 1 if index < 0 else index) + d
	i = clampi(i, 0, n - 1)
	index = -1 if i == n - 1 else i
	refresh()


func edition() -> Dictionary:
	var n := journal.editions.size()
	if n == 0:
		return {}
	return journal.editions[n - 1 if index < 0 or index >= n else index]


# --- Mise en page ----------------------------------------------------------------------

func _encre(alpha := 1.0) -> Color:
	var c: Color = _ep.get("encre", Color("222222"))
	c.a = alpha
	return c


func _label(t: String, taille := 14, gras := false, italique := false, centre := false, couleur := Color(0, 0, 0, 0)) -> Label:
	var l := Label.new()
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_override("font", _font(gras, italique))
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", couleur if couleur.a > 0.0 else _encre())
	if centre:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _filet(epais := 1.0, couleur := Color(0, 0, 0, 0)) -> ColorRect:
	var r := ColorRect.new()
	r.color = couleur if couleur.a > 0.0 else _encre(0.8)
	r.custom_minimum_size = Vector2(0, epais)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _vfilet() -> ColorRect:
	var r := ColorRect.new()
	r.color = _encre(0.35)
	r.custom_minimum_size = Vector2(1, 0)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Rend un label cliquable (caméra sur place ou fiche d'habitant).
func _cliquable(l: Label, action: Callable, aide: String) -> void:
	l.mouse_filter = Control.MOUSE_FILTER_STOP
	l.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	l.tooltip_text = aide
	l.gui_input.connect(func(e: InputEvent) -> void:
		var mb := e as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			action.call())
	l.mouse_entered.connect(func() -> void: l.add_theme_color_override("font_color", _ep.get("filet", _encre())))
	l.mouse_exited.connect(func() -> void: l.add_theme_color_override("font_color", _encre()))


func date_texte(ed: Dictionary) -> String:
	var js := posmod(int(ed.get("js", 0)), 7)
	var m := clampi(int(ed.get("mois", 1)) - 1, 0, 11)
	if Langue.actuelle == "en":
		return "%s, %s %d, %d" % [JOURS_EN[js], MOIS_EN[m], int(ed.get("jm", 1)), int(ed.get("an", 2026))]
	if DATES.has(Langue.actuelle):
		var d: Array = DATES[Langue.actuelle]
		return String(d[2]) % [d[0][js], int(ed.get("jm", 1)), d[1][m], int(ed.get("an", 2026))]
	var jm := int(ed.get("jm", 1))
	return "%s %s %s %d" % [JOURS_FR[js], "1er" if jm == 1 else str(jm), MOIS_FR[m], int(ed.get("an", 2026))]


func refresh() -> void:
	for c in _page.get_children():
		c.queue_free()
	var ed := edition()
	_ep = JournalEpoques.par_id(String(ed.get("ep", ""))) if not ed.is_empty() else journal.epoque()
	var fond := StyleBoxFlat.new()
	fond.bg_color = _ep.papier
	fond.border_color = _encre(0.5)
	fond.set_border_width_all(1)
	fond.set_corner_radius_all(3)
	fond.shadow_color = Color(0, 0, 0, 0.45)
	fond.shadow_size = 14
	fond.content_margin_left = 8
	fond.content_margin_right = 8
	fond.content_margin_top = 6
	fond.content_margin_bottom = 6
	_panel.add_theme_stylebox_override("panel", fond)
	# Barre d'outils à l'encre du journal (les icônes blanches ne se voient pas sur le papier).
	_num.add_theme_color_override("font_color", _encre(0.8))
	for pair in [[_prec, "precedent"], [_suiv, "suivant"], [_fermer, "fermer"]]:
		var b: Button = pair[0]
		b.icon = Icones.get_icon(String(pair[1]), 18, _encre())
		b.flat = true
		b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		_der.add_theme_color_override(c, _encre(0.85))
	_der.add_theme_font_override("font", _font(true))
	var n := journal.editions.size()
	var i := n - 1 if index < 0 else index
	_num.text = Langue.t("Édition %s sur %s") % [str(i + 1), str(n)] if n > 0 else ""
	_prec.disabled = i <= 0
	_suiv.disabled = i >= n - 1
	if ed.is_empty():
		_entete({"n": 0, "ville": journal.ville(), "an": journal.annee()})
		_page.add_child(_label(Langue.t("Le premier numéro paraîtra demain matin. La rédaction taille ses crayons."), 18, false, true, true))
		return
	if index < 0:
		journal.non_lue = false
	_entete(ed)
	var corps := HBoxContainer.new()
	corps.add_theme_constant_override("separation", 16)
	_page.add_child(corps)
	var gauche := VBoxContainer.new()
	gauche.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gauche.add_theme_constant_override("separation", 6)
	corps.add_child(gauche)
	corps.add_child(_vfilet())
	var droite := VBoxContainer.new()
	droite.custom_minimum_size = Vector2(COL_DROITE, 0)
	droite.add_theme_constant_override("separation", 6)
	corps.add_child(droite)
	_une(gauche, ed.une)
	var autres: Array = ed.get("articles", [])
	if not autres.is_empty():
		gauche.add_child(_filet(2.0))
		var grille := GridContainer.new()
		grille.columns = 2 if bool(_ep.get("colonnes", true)) else 1
		grille.add_theme_constant_override("h_separation", 18)
		grille.add_theme_constant_override("v_separation", 12)
		gauche.add_child(grille)
		for a in autres:
			var col := VBoxContainer.new()
			col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			col.custom_minimum_size = Vector2(300, 0)
			grille.add_child(col)
			_article(col, a)
	_colonne(droite, ed)


func _entete(ed: Dictionary) -> void:
	var titre := Journal.titre_de(ed) if ed.has("ep") else Langue.t(String(_ep.titre)) % String(ed.get("ville", ""))
	_page.add_child(_label(titre, 44, true, false, true))
	_page.add_child(_label(Langue.t(String(_ep.devise)), 14, false, true, true))
	_page.add_child(_filet(3.0))
	var ligne := HBoxContainer.new()
	_page.add_child(ligne)
	var num := _label(Langue.t("N° %s") % str(int(ed.get("n", 0))) if int(ed.get("n", 0)) > 0 else "", 13, true)
	ligne.add_child(num)
	ligne.add_child(_label(date_texte(ed) if ed.has("mois") else "", 13, false, false, true))
	var prix := _label(Langue.t(String(_ep.prix)), 13, true)
	prix.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ligne.add_child(prix)
	_page.add_child(_filet(1.0))


func _rubrique(parent: Control, rub: String) -> void:
	var t := String(Journal.RUBRIQUES.get(rub, ""))
	if t != "":
		parent.add_child(_label(Langue.t(t).to_upper(), 11, true, false, false, _ep.get("filet", _encre())))


func _titre(parent: Control, a: Dictionary, taille: int) -> void:
	var l := _label(Journal.texte(a.titre), taille, true)
	parent.add_child(l)
	var pos := Journal.pos_de(a.get("pos", []))
	if pos.is_finite():
		_cliquable(l, func() -> void: focus_requested.emit(pos), Langue.t("Voir sur la carte"))


func _temoin(parent: Control, tm: Dictionary, taille: int) -> void:
	if tm.is_empty():
		return
	var intro := _label(Langue.t(JournalRedaction.TEMOIN_INTRO) % [String(tm.nom), str(int(tm.age)), Langue.t(String(tm.etape)).to_lower()],
		taille - 1, true)
	parent.add_child(intro)
	var pid := int(tm.get("pid", -1))
	if pid >= 0:
		_cliquable(intro, func() -> void: person_requested.emit(pid), Langue.t("Voir sa fiche"))
	parent.add_child(_label("« %s »" % Langue.t(String(tm.texte)), taille, false, true))


func _une(parent: Control, a: Dictionary) -> void:
	_rubrique(parent, String(a.get("rub", "")))
	_titre(parent, a, 30)
	if not (a.chapo as Array).is_empty():
		parent.add_child(_label(Journal.texte(a.chapo), 17, true, true))
	for c in a.get("corps", []):
		parent.add_child(_label(Journal.texte(c), 15))
	_temoin(parent, a.get("temoin", {}), 15)
	parent.add_child(_label(Langue.t(JournalRedaction.SIGNATURE) % Langue.t(String(_ep.envoye)), 12, false, true, false, _encre(0.7)))


func _article(parent: Control, a: Dictionary) -> void:
	_rubrique(parent, String(a.get("rub", "")))
	_titre(parent, a, 19)
	if not (a.chapo as Array).is_empty():
		parent.add_child(_label(Journal.texte(a.chapo), 13, true, true))
	for c in a.get("corps", []):
		parent.add_child(_label(Journal.texte(c), 13))
	_temoin(parent, a.get("temoin", {}), 13)


func _encadre(parent: Control, titre: String) -> VBoxContainer:
	parent.add_child(_filet(2.0))
	parent.add_child(_label(Langue.t(titre).to_upper(), 12, true, false, false, _ep.get("filet", _encre())))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	parent.add_child(v)
	return v


func _colonne(parent: Control, ed: Dictionary) -> void:
	var m: Dictionary = ed.get("meteo", {})
	if not m.is_empty():
		var v := _encadre(parent, "Météo")
		var h := HBoxContainer.new()
		v.add_child(h)
		var ic := TextureRect.new()
		ic.texture = Icones.get_icon(String(m.get("icone", "soleil")), 30, _encre())
		ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		h.add_child(ic)
		var tx := VBoxContainer.new()
		tx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(tx)
		tx.add_child(_label(Langue.t(String(m.ciel)), 14, true))
		tx.add_child(_label(Langue.t("Demain : de %s à %s °C") % [str(int(m.tmin)), str(int(m.tmax))], 13))
	var ch: Dictionary = ed.get("chiffre", {})
	if not ch.is_empty():
		var v := _encadre(parent, "Le chiffre du jour")
		v.add_child(_label(String(ch.v), 34, true, false, true))
		v.add_child(_label(Langue.t(String(ch.t)), 13, false, true, true))
	var p: Dictionary = ed.get("parole", {})
	if not p.is_empty():
		var v := _encadre(parent, "Micro-trottoir")
		_temoin(v, p, 13)
	var sp: Array = ed.get("sport", [])
	if not sp.is_empty():
		var v := _encadre(parent, "Sports en bref")
		for s in sp:
			v.add_child(_label("• " + Langue.t(String(s)), 12))
	var br: Array = ed.get("breves", [])
	if not br.is_empty():
		var v := _encadre(parent, "En bref")
		for b in br:
			v.add_child(_label("• " + Journal.texte(b), 12))
	_carnet(parent, ed.get("carnet", {}))
	var an: Array = ed.get("annonces", [])
	if not an.is_empty():
		var v := _encadre(parent, "Petites annonces")
		for a in an:
			v.add_child(_label(Journal.texte(a), 12, false, true))


func _carnet(parent: Control, c: Dictionary) -> void:
	var lignes := []
	var nais: Array = c.get("naissance", [])
	if not nais.is_empty():
		lignes.append(Langue.t("Naissances : %s.") % _liste(nais.map(func(e) -> String: return String(e[0])), int(c.get("naissance_n", nais.size()))))
	var mar: Array = c.get("mariage", [])
	if not mar.is_empty():
		lignes.append(Langue.t("Mariages : %s.") % _liste(mar.map(func(e) -> String: return "%s & %s" % [String(e[0]), String(e[1])]), int(c.get("mariage_n", mar.size()))))
	var dec: Array = c.get("deces", [])
	if not dec.is_empty():
		lignes.append(Langue.t("Décès : %s.") % _liste(dec.map(func(e) -> String: return Langue.t("%s (%s ans)") % [String(e[0]), str(int(e[1]))]), int(c.get("deces_n", dec.size()))))
	var med: Array = c.get("sport", [])
	if not med.is_empty():
		lignes.append(Langue.t("Médailles : %s.") % _liste(med.map(func(e) -> String: return String(e[0])), int(c.get("sport_n", med.size()))))
	if lignes.is_empty():
		return
	var v := _encadre(parent, "Carnet")
	for l in lignes:
		v.add_child(_label(l, 12))


func _liste(noms: Array, total: int) -> String:
	var s := ", ".join(noms)
	if total > noms.size():
		s = Langue.t("%s et %s autres") % [s, str(total - noms.size())]
	return s
