class_name SeanceCarte
extends PanelContainer
## Carte de l'objectif de séance (dans la colonne du tutoriel, en haut à gauche) :
## le but, pourquoi, le temps qui reste, trois médailles (bronze, argent, or) qui
## s'allument, la barre vers le prochain palier et ce qu'il rapporte.

var seance: Seance

var _titre: Label
var _temps: Label
var _pourquoi: Label
var _medailles: Array[Label] = []
var _barre: ProgressBar
var _progres: Label
var _prime: Label
var _suivante: Button
var _tick := 0.0


func setup(s: Seance) -> void:
	seance = s
	name = "CarteSeance"
	UiStyle.style_panel(self, 0.9, 12, 10)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	v.add_child(head)
	var ic := TextureRect.new()
	ic.texture = Icones.get_icon("etoile", 18, UiStyle.ACCENT)
	ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	head.add_child(ic)
	var t := _label("Objectif de la séance", 12, UiStyle.TEXT_DIM)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	_temps = _label("", 12, UiStyle.TEXT_DIM)
	_temps.name = "Temps"
	_temps.tooltip_text = "Temps de jeu restant pour cette séance (20 minutes réelles)"
	_temps.mouse_filter = Control.MOUSE_FILTER_PASS
	head.add_child(_temps)
	_titre = _label("", 16, UiStyle.ACCENT)
	_titre.name = "TitreSeance"
	_titre.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_titre)
	_pourquoi = _label("", 12, UiStyle.TEXT_DIM)
	_pourquoi.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_pourquoi)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	v.add_child(row)
	for i in 3:
		var m := _label("", 12, UiStyle.TEXT_DIM)
		m.name = "Palier%d" % (i + 1)
		m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		m.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		m.mouse_filter = Control.MOUSE_FILTER_PASS
		var sb := UiStyle.flat_box(Color(1, 1, 1, 0.05), 6, 3)
		m.add_theme_stylebox_override("normal", sb)
		row.add_child(m)
		_medailles.append(m)
	_barre = ProgressBar.new()
	_barre.show_percentage = false
	_barre.custom_minimum_size = Vector2(0, 8)
	_barre.max_value = 1.0
	_barre.step = 0.001
	var fond := UiStyle.flat_box(Color(1, 1, 1, 0.08), 4, 0)
	var plein := UiStyle.flat_box(UiStyle.ACCENT, 4, 0)
	_barre.add_theme_stylebox_override("background", fond)
	_barre.add_theme_stylebox_override("fill", plein)
	v.add_child(_barre)
	var bas := HBoxContainer.new()
	v.add_child(bas)
	_progres = _label("", 12, UiStyle.TEXT)
	_progres.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bas.add_child(_progres)
	_prime = _label("", 12, UiStyle.GOOD)
	_prime.name = "Recompense"
	bas.add_child(_prime)
	_suivante = Button.new()
	_suivante.name = "SeanceSuivante"
	_suivante.text = "Encore un objectif ›"
	_suivante.tooltip_text = "Or gagné : lancer tout de suite l'objectif suivant"
	_suivante.focus_mode = Control.FOCUS_NONE
	_suivante.visible = false
	_suivante.pressed.connect(func() -> void:
		seance.suivante()
		rafraichir())
	v.add_child(_suivante)
	s.changed.connect(rafraichir)
	rafraichir()


func _label(t: String, size := 13, col := UiStyle.TEXT) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


func _process(delta: float) -> void:
	_tick += delta
	if _tick < 1.0 or not visible:
		return
	_tick = 0.0
	rafraichir()


func rafraichir() -> void:
	if seance == null:
		return
	var c := seance.courante
	if c.is_empty():
		_titre.text = "Fonde ton village pour recevoir ton premier objectif."
		_pourquoi.visible = false
		_temps.text = ""
		_barre.visible = false
		_progres.text = ""
		_prime.text = ""
		_suivante.visible = false
		for m in _medailles:
			m.visible = false
		return
	var a := int(c.atteints)
	_titre.text = String(c.titre)
	_pourquoi.text = String(c.get("pourquoi", ""))
	_pourquoi.visible = _pourquoi.text != ""
	_temps.text = "⏱ " + seance.texte_restant()
	for i in 3:
		var m := _medailles[i]
		m.visible = true
		var gagne := i < a
		m.text = ("● " if gagne else "○ ") + String(Seance.NOMS_PALIERS[i])
		m.add_theme_color_override("font_color", Seance.COULEURS_PALIERS[i] if gagne else UiStyle.TEXT_DIM)
		m.tooltip_text = "%s : %s · +%s" % [String(Seance.NOMS_PALIERS[i]), seance.texte_palier(i + 1),
			BuildingSystem.format_money(seance.prime_du_palier(i + 1))] + (" et 1 point de progrès" if i == 2 else "")
	_barre.visible = a < 3
	_barre.value = seance.progres()
	if a >= 3:
		_progres.text = "Séance réussie ! Les trois médailles sont à toi."
		_prime.text = ""
	else:
		_progres.text = "%s : %s" % [String(Seance.NOMS_PALIERS[a]), seance.texte_palier(a + 1)] + "  ·  " + seance.texte_progres()
		_prime.text = "+" + BuildingSystem.format_short(seance.prime_du_palier(a + 1))
	_suivante.visible = a >= 3
