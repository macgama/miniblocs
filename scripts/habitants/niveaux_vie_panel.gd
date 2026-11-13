class_name NiveauxViePanel
extends CanvasLayer
## Panneau « Niveaux de vie » (Maj+N) : combien de foyers à chaque niveau, ce qui
## les empêche de monter (avec un conseil), ce que change chaque niveau, et la
## liste des foyers d'un niveau.

signal person_requested(pid: int)
signal carte_requested

const W := 390.0
const H := 560.0
const VERT := Color("7bd389")
const ROUGE := Color("ff8c8c")

var nv: NiveauxVie
var view := "ville"
var niveau_liste := 2
var _panel: PanelContainer
var _title: Label
var _body: VBoxContainer
var _scroll: ScrollContainer
var _tick := 0.0


func setup(n: NiveauxVie) -> void:
	nv = n
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
	icon.texture = Icones.get_icon("logement", 22, UiStyle.ACCENT)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	head.add_child(icon)
	_title = Label.new()
	_title.text = "Niveaux de vie"
	_title.add_theme_font_size_override("font_size", 16)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	var x := UiStyle.icon_button("fermer", "Fermer", "Maj+N", 18, 32)
	x.pressed.connect(func() -> void: set_open(false))
	head.add_child(x)
	var tabs := HBoxContainer.new()
	outer.add_child(tabs)
	for spec in [["La ville", "ville"], ["Besoins", "besoins"], ["Foyers", "foyers"]]:
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
	# Maj+N (N seul ouvre le panneau Cartes).
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.physical_keycode == KEY_N and k.shift_pressed and not k.ctrl_pressed and not k.alt_pressed:
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
	if nv == null or nv.population == null:
		return
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	match view:
		"besoins": _view_besoins()
		"foyers": _view_foyers()
		_: _view_ville()


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


func _button(t: String, cb: Callable, tip := "") -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = tip
	b.add_theme_font_size_override("font_size", 12)
	b.pressed.connect(cb)
	return b


## Une ligne : pastille de couleur, nom, barre et nombre.
func _barre(n: int, count: int, total: int, hab: int) -> void:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 6)
	_body.add_child(r)
	var dot := ColorRect.new()
	dot.color = NiveauxVie.couleur(n)
	dot.custom_minimum_size = Vector2(12, 12)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.add_child(dot)
	var l := Label.new()
	l.text = NiveauxVie.nom(n)
	l.custom_minimum_size = Vector2(110, 0)
	l.add_theme_font_size_override("font_size", 13)
	r.add_child(l)
	var bg := ColorRect.new()
	bg.color = Color(1, 1, 1, 0.08)
	bg.custom_minimum_size = Vector2(150, 12)
	bg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.add_child(bg)
	var fg := ColorRect.new()
	fg.color = NiveauxVie.couleur(n)
	fg.size = Vector2(150.0 * (float(count) / maxf(1.0, float(total))), 12)
	bg.add_child(fg)
	var c := Label.new()
	c.text = "%d foyer%s · %d hab." % [count, "s" if count > 1 else "", hab]
	c.add_theme_font_size_override("font_size", 11)
	c.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	r.add_child(c)


# --- La ville ----------------------------------------------------------------------------

func _view_ville() -> void:
	var b := nv.bilan()
	var total := int(b.total)
	_title.text = "Niveaux de vie"
	if total == 0:
		_text("Personne n'habite encore la ville. Les foyers arrivent dans les logements libres (B → Logements).", true)
		return
	var moy := float(b.moyenne)
	_text("%d foyers · niveau moyen : %s" % [total, NiveauxVie.nom(roundi(moy))], false, 14)
	_section("Répartition des foyers")
	for i in range(NiveauxVie.NIVEAUX.size() - 1, -1, -1):
		_barre(i, int(b.foyers[i]), total, int(b.habitants[i]))
	_text("En train de monter : %d · en train de redescendre : %d · depuis le début : %d montées, %d descentes, %d déménagements." % [
		int(b.montent), int(b.descendent), int(nv.totaux.montees), int(nv.totaux.descentes), int(nv.totaux.demenagements)], true, 12)
	_section("Ce qui bloque la montée")
	var bl: Dictionary = b.bloques
	if bl.is_empty():
		_text("Rien ne bloque : les foyers montent dès que leurs revenus le permettent.", false, 12).add_theme_color_override("font_color", VERT)
	else:
		var keys: Array = bl.keys()
		keys.sort_custom(func(a, c) -> bool: return int(bl[a]) > int(bl[c]))
		for k in keys.slice(0, 7):
			var l := _text("%s : %d foyer%s" % [NiveauxVie.nom_besoin(String(k)), int(bl[k]), "s" if int(bl[k]) > 1 else ""], false, 13)
			l.add_theme_color_override("font_color", ROUGE)
			_text(NiveauxVie.conseil(String(k)), true, 11)
	var r := HBoxContainer.new()
	_body.add_child(HSeparator.new())
	_body.add_child(r)
	r.add_child(_button("Voir sur la carte", func() -> void: carte_requested.emit(), "Carte « Niveaux de vie » (panneau Cartes, N)"))
	_section("Ce que change le niveau")
	_text("Plus un foyer est aisé, plus il paie de taxe foncière, plus il achète dans les commerces (vêtements, électronique, meubles…) et plus il dépense en sorties. À partir d'« Aisé », il place son épargne. Il lui faut aussi un logement à sa mesure : il déménage vers une maison ou un quartier recherché quand il en trouve un libre.", true, 12)
	for i in NiveauxVie.NIVEAUX.size():
		_text("%s : taxe foncière ×%s · achats ×%s · sorties %s par adulte" % [NiveauxVie.nom(i),
			_f(NiveauxVie.TAXE[i]), _f(NiveauxVie.CONSO_BIENS[i]), BuildingSystem.format_money(roundi(NiveauxVie.SORTIES[i]))], true, 11)


static func _f(v: float) -> String:
	return ("%.2f" % v).trim_suffix("0").trim_suffix("0").trim_suffix(".").replace(".", ",")


# --- Besoins ------------------------------------------------------------------------------

func _view_besoins() -> void:
	_title.text = "Niveaux de vie · besoins"
	_text("Pour monter, un foyer doit avoir tous les besoins du niveau visé (et ceux d'en dessous) pendant quelques jours, et un revenu suffisant par personne. S'il perd un besoin de son niveau, il redescend au bout de %d jours." % roundi(NiveauxVie.JOURS_DESCENTE), true, 12)
	for i in range(1, NiveauxVie.NIVEAUX.size()):
		_section("%s" % NiveauxVie.nom(i))
		var rev := float(NiveauxVie.NIVEAUX[i].revenu) * ReglagesPartie.actuel.salaires
		var t := "En %d jours" % int(NiveauxVie.NIVEAUX[i].jours)
		if rev > 0.0:
			t += " · revenu de %s par mois et par part (1 pour le premier adulte, 0,5 par personne de 14 ans ou plus, 0,3 par enfant)" % BuildingSystem.format_money(roundi(rev))
		if i == 4:
			t += ", ou celui d'Aisé avec %s d'épargne" % BuildingSystem.format_money(roundi(NiveauxVie.EPARGNE_TRES_AISE))
		_text(t + ".", true, 11)
		for bid in NiveauxVie.BESOINS_NIVEAU[i]:
			_text("• %s" % NiveauxVie.nom_besoin(String(bid)), false, 12)
			_text("   " + NiveauxVie.conseil(String(bid)), true, 11)


# --- Foyers --------------------------------------------------------------------------------

func _view_foyers() -> void:
	_title.text = "Niveaux de vie · foyers"
	var r := HBoxContainer.new()
	_body.add_child(r)
	for i in NiveauxVie.NIVEAUX.size():
		var n := i
		var b := _button(NiveauxVie.nom(i), func() -> void:
			niveau_liste = n
			refresh())
		b.toggle_mode = true
		b.button_pressed = i == niveau_liste
		b.add_theme_font_size_override("font_size", 11)
		r.add_child(b)
	var pop := nv.population
	var shown := 0
	var total := 0
	for hid in pop.households:
		var h: Dictionary = pop.households[hid]
		if NiveauxVie.niveau(h) != niveau_liste or (h.m as Array).is_empty():
			continue
		total += 1
		if shown >= 40:
			continue
		shown += 1
		_body.add_child(HSeparator.new())
		var first := int(h.m[0])
		var p: Dictionary = pop.persons[first]
		var bud := pop.household_budget(int(hid))
		var b := _button("Foyer %s · %d pers. · %s/mois" % [String(p.n), (h.m as Array).size(), BuildingSystem.format_money(roundi(float(bud.revenus)))],
			func() -> void: person_requested.emit(first), "Voir la fiche")
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_body.add_child(b)
		_text(nv.texte_foyer(int(hid)), true, 11)
		var m := nv.texte_manques(int(hid))
		if m != "":
			_text(m, true, 11)
	if total == 0:
		_text("Aucun foyer à ce niveau.", true)
	elif total > shown:
		_text("… et %d autres foyers." % (total - shown), true, 11)
