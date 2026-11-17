class_name ArbrePanel
extends CanvasLayer
## Panneau « Arbre de progression » (Maj+F10, menu Infos) : points de progrès
## gagnés et à dépenser, 9 branches de 4 niveaux (ArbreProgression), ce que
## chaque niveau ouvre, et les derniers points gagnés.

signal changed

const W := 430.0
const H := 600.0
const VERT := Color("7bd389")

var _panel: PanelContainer
var _body: VBoxContainer
var _scroll: ScrollContainer
var _selection := "logement"
var _tick := 0.0


func _ready() -> void:
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
	icon.texture = Icones.get_icon("etoile", 22, UiStyle.ACCENT)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	head.add_child(icon)
	var title := Label.new()
	title.text = "Arbre de progression"
	title.add_theme_font_size_override("font_size", 16)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var x := UiStyle.icon_button("fermer", "Fermer", "Maj+F10", 18, 32)
	x.pressed.connect(func() -> void: set_open(false))
	head.add_child(x)
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(W, H)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(_scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 4)
	_scroll.add_child(_body)


func is_open() -> bool:
	return _panel != null and _panel.visible


func set_open(on: bool) -> void:
	_panel.visible = on
	if on:
		refresh()


func toggle() -> void:
	set_open(not _panel.visible)


func _input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.keycode == KEY_F10 and k.shift_pressed and not k.ctrl_pressed and not k.alt_pressed:
		if get_viewport().gui_get_focus_owner() is LineEdit:
			return
		toggle()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not is_open():
		return
	_tick += delta
	if _tick >= 2.0:
		_tick = 0.0
		var keep := _scroll.scroll_vertical
		refresh()
		_scroll.set_deferred("scroll_vertical", keep)


# --- Contenu ----------------------------------------------------------------------------

func refresh() -> void:
	if _body == null:
		return
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	var r := ReglagesPartie.actuel
	var actif := r.deblocage == "arbre"
	var dispo := ArbreProgression.points_disponibles(r)
	var pts := _text("%d point%s à dépenser" % [dispo, "s" if absi(dispo) > 1 else ""], false, 20)
	pts.add_theme_color_override("font_color", UiStyle.ACCENT if dispo > 0 else UiStyle.TEXT)
	var seuil := ArbreProgression.prochain_seuil(r.record_habitants)
	_text("%d gagnés, %d dépensés. Record : %d habitants%s." % [ArbreProgression.points_gagnes(r),
		ArbreProgression.points_depenses(r), r.record_habitants,
		" (prochain point à %d)" % seuil if seuil > 0 else ""], true, 12)
	if not actif:
		var l := _text("Cette partie a tout débloqué (bac à sable) : l'arbre ne verrouille rien. L'admin peut choisir « Arbre de progression » dans les réglages (F10).", false, 13)
		l.add_theme_color_override("font_color", Color("ffb36b"))
	if Epoques.actif():
		_text("Partie en %d : l'époque passe avant l'arbre, ce qui n'est pas encore inventé reste grisé." % Epoques.annee(), true, 12)
	_body.add_child(HSeparator.new())
	for b in ArbreProgression.BRANCHES:
		_ligne_branche(b, r, actif)
	_body.add_child(HSeparator.new())
	_detail(_selection, r)
	_body.add_child(HSeparator.new())
	_text("Gagner des points", false, 15)
	_text("+1 par record de population (50, 100, 250, 500, 1 000, 2 000, 5 000… habitants), +2 à +5 quand une ville monte de rang (Village, Bourg, Ville…), +1 par mission réussie et par succès (Maj+J).", true, 12)
	if not r.journal_points.is_empty():
		_text("Derniers points gagnés", false, 14)
		var j := r.journal_points.duplicate()
		j.reverse()
		for e in j.slice(0, 6):
			_text("+%d  %s" % [int(e.n), String(e.raison)], true, 12)
	if ReglagesPartie.admin_ici():
		var bt := Button.new()
		bt.text = "+5 points (admin)"
		bt.tooltip_text = "Pour tester : se donner des points de progrès"
		bt.focus_mode = Control.FOCUS_NONE
		bt.pressed.connect(func() -> void:
			ArbreProgression.gagner(ReglagesPartie.actuel, 5, "Cadeau de l'admin")
			changed.emit()
			refresh())
		_body.add_child(bt)


func _ligne_branche(b: Dictionary, r: ReglagesPartie, actif: bool) -> void:
	var id := String(b.id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	_body.add_child(row)
	var nom := Button.new()
	nom.flat = true
	nom.focus_mode = Control.FOCUS_NONE
	nom.icon = Icones.get_icon(String(b.icon), 18, UiStyle.ACCENT if _selection == id else UiStyle.TEXT)
	nom.text = String(b.nom)
	nom.alignment = HORIZONTAL_ALIGNMENT_LEFT
	nom.custom_minimum_size = Vector2(170, 32)
	nom.tooltip_text = String(b.desc) + "\nClic : voir ce que chaque niveau ouvre."
	nom.add_theme_font_size_override("font_size", 13)
	if _selection == id:
		nom.add_theme_color_override("font_color", UiStyle.ACCENT)
	nom.pressed.connect(func() -> void:
		_selection = id
		refresh())
	row.add_child(nom)
	var niv := ArbreProgression.niveau(r, id)
	for n in range(1, ArbreProgression.NIVEAU_MAX + 1):
		var bt := Button.new()
		bt.custom_minimum_size = Vector2(52, 32)
		bt.focus_mode = Control.FOCUS_NONE
		bt.add_theme_font_size_override("font_size", 13)
		var cout := int(ArbreProgression.COUTS[n])
		var c := ArbreProgression.contenu(id, n, r)
		var resume := "%s : %s" % [ArbreProgression.nom_niveau(id, n), _resume_contenu(c)]
		if n <= niv:
			bt.text = "✓ " + ArbreProgression.CHIFFRES[n]
			bt.add_theme_stylebox_override("normal", UiStyle.flat_box(Color(0.48, 0.83, 0.54, 0.28), 7, 4))
			bt.add_theme_color_override("font_color", VERT)
			bt.tooltip_text = resume + "\nDébloqué."
		elif n == niv + 1:
			var refus := ArbreProgression.refus_achat(r, id)
			bt.text = "%s · %d" % [ArbreProgression.CHIFFRES[n], cout]
			bt.tooltip_text = resume + "\nCoûte %d point%s. %s" % [cout, "s" if cout > 1 else "", refus if refus != "" else "Clic : débloquer."]
			if refus == "":
				bt.add_theme_stylebox_override("normal", UiStyle.flat_box(Color(1, 0.82, 0.4, 0.30), 7, 4))
				bt.add_theme_color_override("font_color", UiStyle.ACCENT)
			else:
				bt.modulate = Color(1, 1, 1, 0.6)
			var bid := id
			bt.pressed.connect(func() -> void: _acheter(bid))
		else:
			bt.text = "%s · %d" % [ArbreProgression.CHIFFRES[n], cout]
			bt.tooltip_text = resume + "\nCoûte %d points, après le niveau %s." % [cout, ArbreProgression.CHIFFRES[n - 1]]
			bt.modulate = Color(1, 1, 1, 0.35)
		row.add_child(bt)


func _resume_contenu(c: Dictionary) -> String:
	var noms: Array = c.noms
	if noms.is_empty():
		return "rien de plus"
	var t := ", ".join(noms.slice(0, 4))
	if noms.size() > 4:
		t += "… (%d en tout)" % noms.size()
	if int(c.pas_inventes) > 0:
		t += ", dont %d pas encore inventé%s" % [int(c.pas_inventes), "s" if int(c.pas_inventes) > 1 else ""]
	return t


func _detail(id: String, r: ReglagesPartie) -> void:
	var b := ArbreProgression.branche(id)
	if b.is_empty():
		return
	_text(String(b.nom), false, 15)
	_text(String(b.desc), true, 12)
	for n in range(0, ArbreProgression.NIVEAU_MAX + 1):
		var c := ArbreProgression.contenu(id, n, r)
		var noms: Array = c.noms
		var ok := ArbreProgression.niveau(r, id) >= n or r.deblocage != "arbre"
		var tete := "Niveau %s%s" % [ArbreProgression.CHIFFRES[n], " (ouvert d'office)" if n == 0 else " · %d pt%s" % [int(ArbreProgression.COUTS[n]), "s" if int(ArbreProgression.COUTS[n]) > 1 else ""]]
		var l := _text("%s %s : %d %s" % ["✓" if ok else "•", tete, noms.size(), "voies et stations" if id == "transports" else "bâtiments"], false, 13)
		l.add_theme_color_override("font_color", VERT if ok else UiStyle.TEXT)
		if not noms.is_empty():
			var t := ", ".join(noms.slice(0, 10)) + ("…" if noms.size() > 10 else "")
			if int(c.pas_inventes) > 0:
				t += " (%d pas encore inventé%s en %d)" % [int(c.pas_inventes), "s" if int(c.pas_inventes) > 1 else "", Epoques.annee(r)]
			_text(t, true, 11)


func _acheter(id: String) -> void:
	var refus := ArbreProgression.acheter(ReglagesPartie.actuel, id)
	if refus == "":
		Son.jouer("palier")
		changed.emit()
	refresh()


func _text(t: String, dim := false, size := 13) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(W - 30, 0)
	l.add_theme_font_size_override("font_size", size)
	if dim:
		l.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	_body.add_child(l)
	return l
