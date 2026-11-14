class_name StationPanel
extends CanvasLayer
## Panneau « Transports publics » (touche L) : poser des stations, tracer des
## lignes, choisir le véhicule et le nombre de véhicules de chaque ligne, et
## suivre le bilan de chaque ligne (recettes, coûts, âge des véhicules).

signal station_chosen(type_id: String)
signal demolish_chosen
signal line_tool_chosen

var stations: StationSystem
var _panel: PanelContainer
var _lines_box: VBoxContainer
var _group := ButtonGroup.new()
var _buttons: Array[Button] = []
var _summaries: Dictionary = {} # id de ligne -> Label
var _tick := 0.0
## Compte d'exploitation des lignes (peut manquer dans les tests anciens).
var eco: ExploitationLignes
var _bilans: Dictionary = {} # id de ligne -> Label (résumé du bilan)
var _details: Dictionary = {} # id de ligne -> VBoxContainer (bilan détaillé)
var _open: Dictionary = {} # lignes dont le bilan détaillé est ouvert
var _total: Label
var _scroll: ScrollContainer
## Ligne dont le bilan vient d'être ouvert : on fait défiler le panneau jusqu'à lui.
var _focus := -1


func setup(s: StationSystem) -> void:
	stations = s
	stations.lines_changed.connect(_refresh_lines)
	_build()
	_refresh_lines()


func set_eco(e: ExploitationLignes) -> void:
	eco = e
	eco.changed.connect(_refresh_eco)
	_refresh_lines()


func _build() -> void:
	layer = 5
	_panel = PanelContainer.new()
	# À droite, à la place commune des panneaux (un seul ouvert à la fois).
	UiStyle.place_right(_panel)
	_panel.custom_minimum_size = Vector2(360, 0)
	_panel.visible = false
	UiStyle.style_panel(_panel)
	add_child(_panel)
	var scroll := ScrollContainer.new()
	_scroll = scroll
	scroll.custom_minimum_size = Vector2(360, 560)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 4)
	scroll.add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	var ti := TextureRect.new()
	ti.texture = Icones.get_icon("lignes", 24, UiStyle.ACCENT)
	ti.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	head.add_child(ti)
	var title := Label.new()
	title.text = "Transports publics"
	title.add_theme_font_size_override("font_size", 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := UiStyle.icon_button("fermer", "Fermer", "L", 18, 32)
	close.pressed.connect(toggle)
	head.add_child(close)
	var hint := Label.new()
	hint.text = "1. Pose des stations sur tes voies.\n2. Nouvelle ligne : clique les stations dans l'ordre.\n3. Choisis le véhicule et leur nombre.\nFret : dépôts de marchandises pour les camions ; case « Fret » pour les trains et les bateaux."
	hint.add_theme_font_size_override("font_size", 12)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(340, 0)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	box.add_child(hint)
	var grid := GridContainer.new()
	grid.columns = 2
	box.add_child(grid)
	for id in StationSystem.ORDER:
		var b := _tool_button(StationSystem.get_type(id).name)
		b.tooltip_text = StationSystem.get_type(id).desc
		var tid: String = id
		b.pressed.connect(func() -> void: station_chosen.emit(tid))
		grid.add_child(b)
	var del := _tool_button("Supprimer une station")
	del.pressed.connect(func() -> void: demolish_chosen.emit())
	grid.add_child(del)
	box.add_child(HSeparator.new())
	var nl := _tool_button("Nouvelle ligne")
	nl.pressed.connect(func() -> void: line_tool_chosen.emit())
	box.add_child(nl)
	_lines_box = VBoxContainer.new()
	box.add_child(_lines_box)


func _tool_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_group = _group
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.custom_minimum_size = Vector2(160, 0)
	b.add_theme_font_size_override("font_size", 14)
	b.tooltip_text = text
	_buttons.append(b)
	return b


func clear_selection() -> void:
	for b in _buttons:
		b.set_pressed_no_signal(false)


func set_open(on: bool) -> void:
	_panel.visible = on


func toggle() -> void:
	_panel.visible = not _panel.visible


func is_open() -> bool:
	return _panel.visible


## Les tonnes transportées changent sans cesse : on met les résumés à jour chaque seconde.
func _process(delta: float) -> void:
	_tick += delta
	if _tick < 1.0 or not is_open():
		return
	_tick = 0.0
	for lid in _summaries:
		if stations.lines.has(lid) and is_instance_valid(_summaries[lid]):
			(_summaries[lid] as Label).text = stations.line_summary(lid)
	_refresh_eco(false)


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.physical_keycode == KEY_L and not k.shift_pressed:
		toggle()
		get_viewport().set_input_as_handled()


func _refresh_lines() -> void:
	if _lines_box == null:
		return
	for c in _lines_box.get_children():
		c.queue_free()
	_summaries.clear()
	_bilans.clear()
	_details.clear()
	_total = null
	if stations.lines.is_empty():
		var l := Label.new()
		l.text = "Aucune ligne."
		l.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
		_lines_box.add_child(l)
		return
	if eco != null:
		_total = Label.new()
		_total.add_theme_font_size_override("font_size", 13)
		_total.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_total.custom_minimum_size = Vector2(330, 0)
		_lines_box.add_child(_total)
	for lid in stations.lines:
		var line: Dictionary = stations.lines[lid]
		var head := HBoxContainer.new()
		var sw := ColorRect.new()
		sw.color = line.color
		sw.custom_minimum_size = Vector2(12, 12)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(sw)
		var name_ := Label.new()
		name_.text = stations.line_summary(lid)
		name_.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_.custom_minimum_size = Vector2(280, 0)
		name_.add_theme_font_size_override("font_size", 13)
		head.add_child(name_)
		_summaries[lid] = name_
		var x := Button.new()
		x.text = "✕"
		x.tooltip_text = "Supprimer la ligne"
		var id_: int = lid
		x.pressed.connect(func() -> void: stations.remove_line(id_))
		head.add_child(x)
		_lines_box.add_child(head)
		var row := HBoxContainer.new()
		var pick := OptionButton.new()
		pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pick.fit_to_longest_item = false
		pick.custom_minimum_size = Vector2(150, 0)
		pick.clip_text = true
		var models := stations.models_for(line.kind, line.stops, bool(line.get("fret", false)))
		for i in models.size():
			var t := VehicleCatalog.get_type(models[i])
			var label := "%s (%d)" % [t.name, int(t.year)]
			if eco != null:
				label += " · " + ExploitationLignes.euros(ExploitationLignes.prix_achat(models[i]))
			pick.add_item(label, i)
			if models[i] == line.model:
				pick.select(i)
		row.add_child(pick)
		var count := SpinBox.new()
		count.min_value = 1
		count.max_value = 30
		count.value = int(line.count)
		count.tooltip_text = "Nombre de véhicules"
		row.add_child(count)
		if StationSystem.FREIGHT_KINDS.has(String(line.kind)) and line.kind != "camion":
			var fret := CheckBox.new()
			fret.text = "Fret"
			fret.tooltip_text = "Ligne de marchandises : trains de fret, péniches, cargos"
			fret.button_pressed = bool(line.get("fret", false))
			fret.toggled.connect(func(on: bool) -> void: stations.set_fret.call_deferred(id_, on))
			row.add_child(fret)
		pick.item_selected.connect(func(i: int) -> void: stations.set_line(id_, models[i], int(count.value)))
		count.value_changed.connect(func(v: float) -> void: stations.set_line(id_, String(stations.lines[id_].model), int(v)))
		_lines_box.add_child(row)
		if eco != null:
			_add_bilan(id_)
	_refresh_eco()


# --- Bilan des lignes -----------------------------------------------------------------------

func _add_bilan(id_: int) -> void:
	var r := HBoxContainer.new()
	var b := Label.new()
	b.add_theme_font_size_override("font_size", 12)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(250, 0)
	r.add_child(b)
	_bilans[id_] = b
	var more := Button.new()
	more.text = "Bilan ▾" if _open.has(id_) else "Bilan ▸"
	more.tooltip_text = "Recettes, coûts et véhicules de la ligne"
	more.add_theme_font_size_override("font_size", 12)
	more.pressed.connect(func() -> void:
		if _open.has(id_):
			_open.erase(id_)
		else:
			_open[id_] = true
			_focus = id_
		_refresh_lines())
	r.add_child(more)
	_lines_box.add_child(r)
	if _open.has(id_):
		var d := VBoxContainer.new()
		d.add_theme_constant_override("separation", 2)
		_lines_box.add_child(d)
		_details[id_] = d
		if _focus == id_:
			_focus = -1
			_show_details.call_deferred(d)
	_lines_box.add_child(HSeparator.new())


## Met à jour les résumés (et, si full, les bilans détaillés ouverts).
func _refresh_eco(full := true) -> void:
	if eco == null or not is_instance_valid(_lines_box):
		return
	if _total != null and is_instance_valid(_total):
		var t := eco.bilan_total()
		_total.text = "Toutes les lignes : %s de recettes, %s de dépenses, résultat %s par mois." % [
			ExploitationLignes.euros(float(t.recettes)), ExploitationLignes.euros(float(t.depenses)), _signed(float(t.resultat))]
		_total.add_theme_color_override("font_color", _color(float(t.resultat)))
	for lid in _bilans:
		var lab: Label = _bilans[lid]
		if not is_instance_valid(lab):
			continue
		var b := eco.bilan(lid)
		if b.is_empty():
			lab.text = ""
			continue
		lab.text = "%s par mois · %s · fiabilité %d %%" % [_signed(float(b.resultat)), _ages(b), roundi(float(b.fiabilite) * 100.0)]
		lab.add_theme_color_override("font_color", _color(float(b.resultat)))
	if not full:
		return
	for lid in _details:
		var d: VBoxContainer = _details[lid]
		if is_instance_valid(d):
			_fill_details(lid, d)


func _show_details(d: VBoxContainer) -> void:
	await get_tree().process_frame
	if is_instance_valid(d) and _scroll != null:
		_scroll.ensure_control_visible(d)


func _fill_details(lid: int, d: VBoxContainer) -> void:
	for c in d.get_children():
		c.queue_free()
	var b := eco.bilan(lid)
	if b.is_empty():
		return
	var l: Dictionary = stations.lines[lid]
	var fret := bool(l.get("fret", false))
	var eu := ExploitationLignes.euros
	if fret:
		_line(d, "Fret : %s par jour, dont %s pour les entreprises de la région (%d %% trouvent un client) · %s la tonne" % [
			StationSystem.format_tonnes(float(b.t_jour)), StationSystem.format_tonnes(float(b.t_fact)),
			roundi(float(b.remplissage) * 100.0), eu.call(float(b.tarif_t))])
		_line(d, "Recettes du fret : %s par mois" % eu.call(float(b.fret)))
	else:
		var tf := eco.trafic
		var fare := tf.fare_of(lid) if tf != null else Trafic.DEFAULT_FARE
		_line(d, "%d voyageurs par jour · pointe remplie à %d %%" % [int(b.voyageurs), roundi(float(b.remplissage) * 100.0)])
		var r := HBoxContainer.new()
		var fl := Label.new()
		fl.text = "Ticket : %s · %s par mois" % ["gratuit" if fare <= 0.0 else ("%.2f €" % fare).replace(".", ","), eu.call(float(b.tickets))]
		fl.add_theme_font_size_override("font_size", 12)
		fl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(fl)
		if tf != null:
			for step in [-0.5, 0.5]:
				var bt := Button.new()
				bt.text = ("− 0,50 €" if step < 0.0 else "+ 0,50 €")
				bt.add_theme_font_size_override("font_size", 12)
				var st_: float = step
				bt.pressed.connect(func() -> void:
					tf.fares[lid] = maxf(0.0, tf.fare_of(lid) + st_)
					if tf.population != null:
						tf.population._transit_cache.clear()
					_refresh_eco())
				r.add_child(bt)
		d.add_child(r)
	_line(d, "Personnel et énergie : %s par mois (%d km par jour et par véhicule, ligne de %s km)" % [
		eu.call(float(b.exploitation)), roundi(float(b.km_jour)), ("%.1f" % (float(b.longueur) / 1000.0)).replace(".", ",")])
	_line(d, "Entretien et réparations : %s par mois (%s panne%s par mois)" % [eu.call(float(b.entretien)),
		("%.1f" % float(b.pannes_mois)).replace(".", ","), "s" if float(b.pannes_mois) >= 2.0 else ""])
	var res := _line(d, "Résultat estimé : %s par mois" % _signed(float(b.resultat)))
	res.add_theme_color_override("font_color", _color(float(b.resultat)))
	_line(d, "Ce mois (%d j) : %s · mois dernier : %s · depuis la création : %s, plus %s de véhicules" % [int(b.jours_mois),
		_signed(float(b.mois)), _signed(float(b.precedent)), _signed(float(b.total)), eu.call(float(b.achats))], true)
	var vt := VehicleCatalog.get_type(String(l.model))
	_line(d, "Flotte : %d × %s, %s (durée de vie %d ans) · neuf %s · revente de la flotte %s" % [int(b.n), String(vt.get("name", l.model)).to_lower(),
		_ages(b), int(b.vie), eu.call(float(b.prix)), eu.call(float(b.valeur))], true)
	var r2 := HBoxContainer.new()
	var ren := Button.new()
	ren.text = "Renouveler les usés (%d)" % int(b.uses)
	ren.tooltip_text = "Remplace les véhicules qui ont dépassé leur durée de vie par des neufs (reprise des anciens déduite)"
	ren.disabled = int(b.uses) == 0
	ren.add_theme_font_size_override("font_size", 12)
	ren.pressed.connect(func() -> void: eco.renouveler(lid, true))
	r2.add_child(ren)
	var auto := CheckBox.new()
	auto.text = "Automatique"
	auto.tooltip_text = "Renouvelle seul chaque véhicule à la fin de sa vie"
	auto.button_pressed = bool(b.auto)
	auto.add_theme_font_size_override("font_size", 12)
	auto.toggled.connect(func(on: bool) -> void: eco.set_auto(lid, on))
	r2.add_child(auto)
	d.add_child(r2)


func _line(d: VBoxContainer, text: String, dim := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 12)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(330, 0)
	if dim:
		l.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	d.add_child(l)
	return l


static func _ages(b: Dictionary) -> String:
	var a := float(b.age_moyen)
	var txt := "neufs" if a < 0.1 else ("%s an%s en moyenne" % [("%.1f" % a).replace(".", ",").replace(",0", ""), "s" if a >= 2.0 else ""])
	if int(b.uses) > 0:
		txt += ", %d usé%s" % [int(b.uses), "s" if int(b.uses) > 1 else ""]
	return txt


static func _signed(x: float) -> String:
	return ("+" if x >= 0.0 else "") + ExploitationLignes.euros(x)


static func _color(x: float) -> Color:
	return Color("8ce99a") if x >= 0.0 else Color("ff8787")
