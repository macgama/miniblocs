class_name FilAlertes
extends CanvasLayer
## Fil d'alertes à gauche de l'écran : ce que le Conseiller juge urgent ou à
## surveiller, du plus grave au moins grave, avec un bouton qui ouvre le bon
## panneau. Replié, c'est une cloche avec le nombre d'alertes.

signal panneau_requested(id: String)

const MAX_LIGNES := 5

var mairie: MairiePanel
var replie := false

var _panel: PanelContainer
var _head: Button
var _list: VBoxContainer
var _n := 0
var _montre := true
## Trop peu de place dans la colonne de gauche (PileGauche) : la liste se replie,
## seul le titre « À faire · n » reste, sans toucher au choix du joueur (replie).
var _serre := false
## Pas même la place du titre : le fil se cache (les alertes restent dans la Mairie, M).
var _sans_place := false


func _ready() -> void:
	_panel = PanelContainer.new()
	_panel.name = "FilAlertes"
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = 10
	_panel.offset_top = -152
	_panel.offset_bottom = -152
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.custom_minimum_size = Vector2(300, 0)
	UiStyle.style_panel(_panel, 0.88, 10, 8)
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	_panel.add_child(col)
	_head = Button.new()
	_head.flat = true
	_head.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_head.focus_mode = Control.FOCUS_NONE
	_head.icon = Icones.get_icon("cloche", 18, UiStyle.ACCENT)
	_head.tooltip_text = "Replier ou déplier les alertes (M : tableau de bord de la Mairie)"
	_head.pressed.connect(func() -> void:
		replie = not replie
		refresh())
	col.add_child(_head)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	col.add_child(_list)
	_panel.visible = false
	_panel.set_meta("place", Callable(self, "set_place"))


## Hauteur disponible au-dessus de la carte de la case (PileGauche).
func set_place(h: float) -> void:
	var plein := _panel.get_theme_stylebox("panel").get_minimum_size().y + _head.get_combined_minimum_size().y \
		+ 4.0 + _list.get_combined_minimum_size().y
	var serre := plein > h
	if serre != _serre:
		_serre = serre
		_list.visible = not replie and not _serre
	var titre := _panel.get_theme_stylebox("panel").get_minimum_size().y + _head.get_combined_minimum_size().y
	var sans := titre > h
	if sans != _sans_place:
		_sans_place = sans
		_panel.visible = _montre and _n > 0 and not _sans_place


func setup(m: MairiePanel) -> void:
	mairie = m
	if m.stats != null:
		m.stats.releve_fait.connect(refresh)
	refresh()


func set_shown(on: bool) -> void:
	_montre = on
	_panel.visible = on and _n > 0 and not _sans_place


func nombre() -> int:
	return _n


func refresh() -> void:
	for ch in _list.get_children():
		_list.remove_child(ch)
		ch.queue_free()
	var al := []
	if mairie != null:
		for a in mairie.alertes(MAX_LIGNES):
			if int(a.gravite) >= 1:
				al.append(a)
	_n = al.size()
	_head.text = "À faire  ·  %d" % _n + ("   ▸" if replie else "   ▾")
	_list.visible = not replie and not _serre
	for a in al:
		_list.add_child(MairiePanel.carte_alerte(a, func(id: String) -> void: panneau_requested.emit(id), true))
	_panel.visible = _montre and _n > 0 and not _sans_place
	_panel.reset_size()
