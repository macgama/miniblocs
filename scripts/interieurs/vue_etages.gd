class_name VueEtages
extends CanvasLayer
## Vue par étage en mode Gérer : Page bas enlève l'étage du haut de tous les
## bâtiments en murs fins autour de la caméra (toit compris), Page haut le
## remet, Origine montre tout. Les meubles et les habitants suivent : on voit
## qui dort, mange ou travaille à chaque niveau. Une petite échelle d'étages
## s'affiche en haut de l'écran tant que la vue est coupée.
##
## Les bâtiments du catalogue ne se coupent pas ainsi : « Ouvrir l'intérieur »
## (panneau Personnaliser) les passe en murs fins.

signal message(text: String)

## Rayon autour du point visé par la caméra (m).
const RAYON := 120.0
const REFRESH := 0.5

var pe: PlanEditor
var rig: Node3D

## Étage le plus haut montré (−1 : tout).
var etage := -1
var _plans: Array = []
var _timer := 0.0
var _box: PanelContainer
var _label: Label


func _ready() -> void:
	layer = 6
	_box = PanelContainer.new()
	_box.add_theme_stylebox_override("panel", UiStyle.panel_box(0.9, 10, 6))
	_box.anchor_left = 0.5
	_box.anchor_right = 0.5
	_box.offset_top = 70
	_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_box.visible = false
	add_child(_box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_box.add_child(row)
	var down := _btn("▼", "Étage du dessous (Page bas)")
	down.pressed.connect(func() -> void: step(-1))
	row.add_child(down)
	_label = Label.new()
	_label.custom_minimum_size = Vector2(220, 0)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(_label)
	var up := _btn("▲", "Étage du dessus (Page haut)")
	up.pressed.connect(func() -> void: step(1))
	row.add_child(up)
	var all := _btn("Tout voir", "Remet tous les étages et les toits (Origine)")
	all.pressed.connect(func() -> void: show_all())
	row.add_child(all)


func _btn(text: String, tip: String) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	return b


## Coupe ou recoller les étages : d = −1 enlève un étage, +1 en remet un.
func step(d: int) -> void:
	var c := _centre()
	var ids := pe.plans_near(c, RAYON)
	var top := _top_level(ids)
	if ids.is_empty() or top < 1:
		message.emit("Vue par étage : aucun bâtiment à étages en murs fins par ici. « Ouvrir l'intérieur » (Personnaliser) en crée un depuis le catalogue.")
		return
	var e := top if etage < 0 else etage
	e += d
	if e >= top:
		show_all()
		return
	_apply(maxi(e, 0), ids, top)


func show_all() -> void:
	etage = -1
	_plans = []
	if pe != null:
		pe.set_vue_etage(-1, [])
	_box.visible = false


func _apply(e: int, ids: Array, top: int) -> void:
	etage = e
	_plans = ids
	pe.set_vue_etage(e, ids)
	_label.text = "%s  (%d / %d)" % [floor_name(e), e + 1, top + 1]
	_box.visible = true


static func floor_name(e: int) -> String:
	if e == 0:
		return "Rez-de-chaussée"
	if e == 1:
		return "1er étage"
	return "%de étage" % e


func _top_level(ids: Array) -> int:
	var top := 0
	for id in ids:
		var lv := pe.levels_of(String(id))
		if not lv.is_empty():
			top = maxi(top, int(lv.max()))
	return top


func _centre() -> Vector2:
	if rig == null:
		return Vector2.ZERO
	return Vector2(rig.global_position.x, rig.global_position.z)


## Les outils d'édition (murs fins, meubles) ont leur propre coupe.
func _editing() -> bool:
	return pe == null or pe.tool != PlanEditor.Tool.NONE or pe.cut_override


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo or _editing():
		return
	if k.keycode == KEY_PAGEDOWN:
		step(-1)
		get_viewport().set_input_as_handled()
	elif k.keycode == KEY_PAGEUP:
		step(1)
		get_viewport().set_input_as_handled()
	elif k.keycode == KEY_HOME and etage >= 0:
		show_all()
		get_viewport().set_input_as_handled()


## La caméra bouge : les bâtiments qui entrent dans le rayon sont coupés aussi.
func _process(delta: float) -> void:
	if etage < 0 or pe == null:
		return
	if _editing():
		_box.visible = false
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = REFRESH
	var ids := pe.plans_near(_centre(), RAYON)
	if ids != _plans or pe.vue_etage != etage:
		_apply(etage, ids, maxi(_top_level(ids), etage))
	_box.visible = true
