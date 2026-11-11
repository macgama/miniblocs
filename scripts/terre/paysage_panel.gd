class_name PaysagePanel
extends CanvasLayer
## Panneau « Paysage » (outil 0) : façonner la terre au pinceau rond.
## Colline, lisser, creuser un lac ou un canal, combler l'eau, peindre un biome,
## planter ou arracher des arbres. La taille du pinceau se règle ici.

signal tool_chosen(tool: int)
signal radius_changed(radius: int)
signal biome_chosen(kind: int)

const TOOLS := [
	{"tool": TerrainWorld.Tool.HILL, "name": "Colline", "tip": "Glisser : fait monter une colline arrondie (jusqu'à 1,5 m par passage)."},
	{"tool": TerrainWorld.Tool.SMOOTH, "name": "Lisser", "tip": "Glisser : adoucit les marches et les bosses."},
	{"tool": TerrainWorld.Tool.DIG_WATER, "name": "Lac / canal", "tip": "Glisser : creuse et remplit d'eau. L'eau garde le niveau du premier clic : un canal qui monte est creusé plus profond."},
	{"tool": TerrainWorld.Tool.FILL_WATER, "name": "Combler l'eau", "tip": "Glisser : rebouche un lac ou un canal creusé."},
	{"tool": TerrainWorld.Tool.BIOME, "name": "Peindre un biome", "tip": "Glisser : change le sol (forêt, champs, désert, neige…). Les forêts se remplissent d'arbres."},
	{"tool": TerrainWorld.Tool.PLANT, "name": "Planter des arbres", "tip": "Glisser : plante des arbres, même sur un terrain terrassé."},
	{"tool": TerrainWorld.Tool.CLEAR_TREES, "name": "Arracher les arbres", "tip": "Glisser : enlève arbres et buissons."},
]

var current_tool: int = TerrainWorld.Tool.HILL
var radius := 3
var kind := 4
var _panel: PanelContainer
var _group := ButtonGroup.new()
var _buttons: Array[Button] = []
var _radius_label: Label
var _biome_pick: OptionButton
var _tip: Label


func _ready() -> void:
	_panel = PanelContainer.new()
	_panel.offset_left = 12
	_panel.offset_top = 230
	_panel.custom_minimum_size = Vector2(250, 0)
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_panel.add_child(box)

	var title := Label.new()
	title.text = "Paysage"
	title.add_theme_font_size_override("font_size", 17)
	box.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 2
	box.add_child(grid)
	for t in TOOLS:
		var b := Button.new()
		b.text = t.name
		b.tooltip_text = t.tip
		b.toggle_mode = true
		b.button_group = _group
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var id: int = t.tool
		b.pressed.connect(func() -> void: select_tool(id))
		grid.add_child(b)
		_buttons.append(b)

	var row := HBoxContainer.new()
	box.add_child(row)
	_radius_label = Label.new()
	_radius_label.custom_minimum_size = Vector2(110, 0)
	row.add_child(_radius_label)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 15
	slider.step = 1
	slider.value = radius
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(v: float) -> void:
		radius = int(v)
		_update_radius_label()
		radius_changed.emit(radius))
	row.add_child(slider)
	_update_radius_label()

	var brow := HBoxContainer.new()
	box.add_child(brow)
	var bl := Label.new()
	bl.text = "Biome :"
	brow.add_child(bl)
	_biome_pick = OptionButton.new()
	_biome_pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for k: int in TerrainWorld.PAINTABLE_KINDS:
		_biome_pick.add_item(TerrainWorld.KIND_NAMES[k], k)
	_biome_pick.item_selected.connect(func(i: int) -> void:
		kind = _biome_pick.get_item_id(i)
		biome_chosen.emit(kind)
		select_tool(TerrainWorld.Tool.BIOME))
	brow.add_child(_biome_pick)

	_tip = Label.new()
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip.custom_minimum_size = Vector2(250, 0)
	_tip.add_theme_font_size_override("font_size", 12)
	_tip.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	box.add_child(_tip)
	_refresh()


func _update_radius_label() -> void:
	var d := radius * 2 + 1
	_radius_label.text = "Pinceau : %d m" % d


## Choisit un outil du panneau (et prévient le terrain).
func select_tool(t: int) -> void:
	current_tool = t
	_refresh()
	tool_chosen.emit(t)


func _refresh() -> void:
	for i in TOOLS.size():
		if TOOLS[i].tool == current_tool:
			_buttons[i].set_pressed_no_signal(true)
			_tip.text = TOOLS[i].tip


func set_shown(on: bool) -> void:
	visible = on
