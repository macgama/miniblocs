class_name ScenarioCarte
extends CanvasLayer
## Carte du scénario en haut à gauche : nom, jour sur la date limite, objectifs
## (✓ remplis, ○ à faire, avec le progrès), bonus, contraintes rappelées,
## boutons « Histoire » et « Abandonner ». Repliable. Lit tout dans
## ScenarioPartie (rien n'est calculé ici). Cachée en mode Créer.

const W := 340.0
const VERT := Color("7bd389")
const ORANGE := Color("ffb86b")

var sc: ScenarioPartie
var cachee := false
## Hauteur déjà prise en haut à gauche (carte du personnage suivi…) : la carte se pose dessous.
var decalage: Callable
var replie := false

var _panel: PanelContainer
var _titre_l: Label
var _jour_l: Label
var _barre: ProgressBar
var _corps: VBoxContainer
var _replier_b: Button
var _abandon_b: Button
var _confirmer := false
var _tick := 99.0


func setup(s: ScenarioPartie) -> void:
	sc = s
	_build()
	sc.changed.connect(func() -> void: _tick = 99.0)


func _build() -> void:
	layer = 5
	_panel = PanelContainer.new()
	_panel.name = "CarteScenario"
	UiStyle.style_panel(_panel, 0.92, 12, 12)
	_panel.position = Vector2(10, UiStyle.SIDE_TOP)
	_panel.custom_minimum_size = Vector2(W, 0)
	add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	_panel.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	v.add_child(head)
	var ic := TextureRect.new()
	ic.texture = Icones.get_icon("trophee", 20, UiStyle.ACCENT)
	ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	head.add_child(ic)
	_titre_l = _label("", 16, UiStyle.ACCENT)
	_titre_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_titre_l.custom_minimum_size = Vector2(0, 0)
	head.add_child(_titre_l)
	_replier_b = UiStyle.icon_button("moins", "Replier / déplier", "", 16, 28)
	_replier_b.pressed.connect(func() -> void:
		replie = not replie
		_tick = 99.0)
	head.add_child(_replier_b)
	_jour_l = _label("", 12, UiStyle.TEXT_DIM)
	v.add_child(_jour_l)
	_barre = ProgressBar.new()
	_barre.show_percentage = false
	_barre.custom_minimum_size = Vector2(W - 24, 6)
	_barre.max_value = 1.0
	v.add_child(_barre)
	_corps = VBoxContainer.new()
	_corps.add_theme_constant_override("separation", 3)
	v.add_child(_corps)


func _process(delta: float) -> void:
	if sc == null:
		return
	var vis := sc.id != "" and sc.actif and not cachee
	_panel.visible = vis
	if not vis:
		return
	_panel.position.y = UiStyle.SIDE_TOP + (float(decalage.call()) if decalage.is_valid() else 0.0)
	_tick += delta
	if _tick < 1.0:
		return
	_tick = 0.0
	rafraichir()


func rafraichir() -> void:
	var s := sc.donnees()
	_titre_l.text = String(s.get("nom", "Scénario"))
	if sc.fini:
		var r := sc.resultat
		_jour_l.text = ("Réussi en %d jours · %d points" if bool(r.get("victoire", false)) else "Terminé · %d jours · %d points") % [
			int(r.get("jours", 0)), int(r.get("score", 0))]
		_barre.value = 1.0
	else:
		_jour_l.text = "Jour %d sur %d · encore %d jours" % [sc.jour(), sc.jours_max(), sc.jours_restants()]
		_barre.value = float(sc.jour()) / maxf(float(sc.jours_max()), 1.0)
	_replier_b.icon = Icones.get_icon("plus" if replie else "moins", 16)
	# La carte reprend la taille de son contenu (repliée, moins de lignes).
	_panel.reset_size.call_deferred()
	for c in _corps.get_children():
		_corps.remove_child(c)
		c.queue_free()
	if replie:
		return
	if sc.jour_fondation < 0 and not sc.fini:
		_corps.add_child(_label("Pour commencer : fonde ta ville (Maison de commune, Maj + M).", 13, ORANGE))
	for o in s.get("objectifs", []):
		_ligne(o, false)
	var bonus: Array = s.get("bonus", [])
	if not bonus.is_empty():
		_corps.add_child(_label("Bonus", 12, UiStyle.TEXT_DIM))
		for o in bonus:
			_ligne(o, true)
	var rappel := _rappel_contraintes(s.get("contraintes", {}))
	if rappel != "" and not sc.fini:
		_corps.add_child(_label(rappel, 12, UiStyle.TEXT_DIM))
	if sc.triche and not sc.fini:
		_corps.add_child(_label("Réglages changés : pas de classement pour cette partie.", 12, ORANGE))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_corps.add_child(row)
	var hist := Button.new()
	hist.text = "Histoire"
	hist.focus_mode = Control.FOCUS_NONE
	hist.tooltip_text = String(s.get("histoire", ""))
	hist.pressed.connect(func() -> void: sc.message.emit(String(s.get("histoire", ""))))
	row.add_child(hist)
	if not sc.fini:
		_abandon_b = Button.new()
		_abandon_b.name = "Abandonner"
		_abandon_b.text = "Confirmer l'abandon" if _confirmer else "Abandonner"
		_abandon_b.focus_mode = Control.FOCUS_NONE
		_abandon_b.pressed.connect(func() -> void:
			if _confirmer:
				_confirmer = false
				sc.terminer(false, true)
			else:
				_confirmer = true
				_tick = 99.0)
		row.add_child(_abandon_b)


func _ligne(o: Dictionary, bonus: bool) -> void:
	var ok := sc.rempli(o)
	var col := VERT if ok else (UiStyle.TEXT_DIM if bonus else UiStyle.TEXT)
	var l := _label("%s %s · %s" % ["✓" if ok else "○", String(o.get("texte", "")), sc.progres(o)], 13, col)
	_corps.add_child(l)


static func _rappel_contraintes(c: Dictionary) -> String:
	var t := []
	if c.has("routes"):
		if (c.routes as Array).is_empty():
			t.append("aucune route")
		elif c.has("routes_max_m"):
			t.append("%d m de petites rues au plus" % roundi(float(c.routes_max_m)))
		else:
			t.append("routes limitées")
	if not (c.get("interdits", []) as Array).is_empty():
		t.append("%d bâtiments interdits" % (c.interdits as Array).size())
	if bool(c.get("sans_emprunt", false)):
		t.append("pas d'emprunt")
	return "Règles : " + ", ".join(t) + "." if not t.is_empty() else ""


func _label(t: String, size := 14, col := UiStyle.TEXT) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(W - 24, 0)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l
