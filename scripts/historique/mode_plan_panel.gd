class_name ModePlanPanel
extends CanvasLayer
## Encadré du mode plan, en haut à gauche : projets posés, total estimé, « Tout
## construire », « Tout effacer », quitter le mode. Visible quand le mode plan est
## ouvert ou qu'il reste des projets.

const MAX_LIGNES := 8

var plan: ModePlan

var _panel: PanelContainer
var _titre: Label
var _liste: VBoxContainer
var _total: Label
var _valider: Button
var _effacer: Button
var _bascule: Button


func _ready() -> void:
	layer = 6
	_panel = PanelContainer.new()
	_panel.name = "ModePlan"
	_panel.position = Vector2(10, UiStyle.SIDE_TOP)
	_panel.custom_minimum_size = Vector2(300, 0)
	UiStyle.style_panel(_panel, 0.9, 10, 10)
	var bord := _panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	if bord != null:
		bord.border_color = ModePlan.COULEUR.lightened(0.2)
		bord.border_color.a = 0.9
		bord.set_border_width_all(2)
		_panel.add_theme_stylebox_override("panel", bord)
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	_panel.add_child(col)
	_titre = Label.new()
	_titre.add_theme_font_size_override("font_size", 16)
	_titre.add_theme_color_override("font_color", ModePlan.COULEUR.lightened(0.45))
	col.add_child(_titre)
	var aide := Label.new()
	aide.text = "Pose bâtiments et voies : ils restent en bleu, sans payer.\nCtrl+Z : retirer le dernier projet."
	aide.add_theme_font_size_override("font_size", 12)
	aide.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	col.add_child(aide)
	_liste = VBoxContainer.new()
	_liste.add_theme_constant_override("separation", 2)
	col.add_child(_liste)
	_total = Label.new()
	_total.add_theme_font_size_override("font_size", 13)
	col.add_child(_total)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	col.add_child(row)
	_valider = Button.new()
	_valider.name = "ToutConstruire"
	_valider.text = "Tout construire"
	_valider.tooltip_text = "Construit tout le plan : les voies d'abord, puis les bâtiments (Ctrl+Z défait la validation)"
	_valider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_valider.pressed.connect(func() -> void:
		if plan != null:
			plan.valider())
	row.add_child(_valider)
	_effacer = Button.new()
	_effacer.text = "Tout effacer"
	_effacer.pressed.connect(func() -> void:
		if plan != null:
			plan.effacer_tout())
	row.add_child(_effacer)
	_bascule = Button.new()
	_bascule.name = "Bascule"
	_bascule.pressed.connect(func() -> void:
		if plan != null:
			plan.basculer())
	col.add_child(_bascule)
	_panel.visible = false


func setup(p: ModePlan) -> void:
	plan = p
	p.changed.connect(refresh)
	refresh()


func refresh() -> void:
	if plan == null or _panel == null:
		return
	_panel.visible = plan.actif or not plan.projets.is_empty()
	_titre.text = "Mode plan" + ("" if plan.actif else " (en pause)")
	for ch in _liste.get_children():
		_liste.remove_child(ch)
		ch.queue_free()
	var n := 0
	for i in range(plan.projets.size() - 1, -1, -1):
		if n >= MAX_LIGNES:
			break
		var p: Dictionary = plan.projets[i]
		_liste.add_child(_ligne(p))
		n += 1
	if plan.projets.size() > MAX_LIGNES:
		var plus := Label.new()
		plus.text = "… et %d autre%s" % [plan.projets.size() - MAX_LIGNES, "s" if plan.projets.size() - MAX_LIGNES > 1 else ""]
		plus.add_theme_font_size_override("font_size", 12)
		plus.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
		_liste.add_child(plus)
	var nb := plan.compte("bat")
	var nv := plan.compte("voie")
	if plan.projets.is_empty():
		_total.text = "Aucun projet pour l'instant."
	else:
		_total.text = "%d bâtiment%s, %d voie%s · environ %s" % [nb, "s" if nb > 1 else "", nv, "s" if nv > 1 else "",
			BuildingSystem.format_money(plan.cout_total())]
	_valider.disabled = plan.projets.is_empty()
	_effacer.disabled = plan.projets.is_empty()
	_bascule.text = "Quitter le mode plan (Ctrl+P)" if plan.actif else "Reprendre le plan (Ctrl+P)"


func _ligne(p: Dictionary) -> Control:
	var row := HBoxContainer.new()
	var l := Label.new()
	var cout := int(p.get("cout", 0))
	l.text = ModePlan.nom_projet(p) + ("" if cout <= 0 else "  ·  " + BuildingSystem.format_short(cout))
	l.add_theme_font_size_override("font_size", 13)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.clip_text = true
	if plan.refus.has(int(p.pid)):
		l.add_theme_color_override("font_color", ModePlan.COULEUR_REFUS.lightened(0.3))
		l.tooltip_text = String(plan.refus[int(p.pid)])
	row.add_child(l)
	var x := Button.new()
	x.text = "✕"
	x.flat = true
	x.tooltip_text = "Retirer ce projet"
	var pid := int(p.pid)
	x.pressed.connect(func() -> void: plan.retirer(pid))
	row.add_child(x)
	return row
