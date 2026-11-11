class_name ClockHud
extends CanvasLayer
## Petit panneau en bas à droite : heure du lieu, date, lever et coucher du
## Soleil, phase de la Lune, vitesse du temps et réglage de l'heure.
## Touche T : pause / reprise. Touche Maj+T : vitesse suivante.

const MONTHS := ["janv.", "févr.", "mars", "avr.", "mai", "juin", "juil.", "août", "sept.", "oct.", "nov.", "déc."]

var clock: DayNight
var _time_label: Label
var _info_label: Label
var _slider: HSlider
var _speed_buttons: Array[Button] = []
var _updating := false


func _ready() -> void:
	layer = 2
	var anchor := Control.new()
	# En bas à droite, au-dessus de la barre d'outils (libre dans l'interface actuelle).
	anchor.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(anchor)
	var panel := PanelContainer.new()
	panel.position = Vector2(-562, -200)
	panel.custom_minimum_size = Vector2(550, 0)
	anchor.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)

	var top := HBoxContainer.new()
	box.add_child(top)
	var prev := Button.new()
	prev.text = "◀"
	prev.tooltip_text = "Reculer d'un mois"
	prev.pressed.connect(func() -> void: clock.shift_days(-30))
	top.add_child(prev)
	_time_label = Label.new()
	_time_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_time_label.add_theme_font_size_override("font_size", 18)
	top.add_child(_time_label)
	var next := Button.new()
	next.text = "▶"
	next.tooltip_text = "Avancer d'un mois"
	next.pressed.connect(func() -> void: clock.shift_days(30))
	top.add_child(next)

	_info_label = Label.new()
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.add_theme_font_size_override("font_size", 12)
	box.add_child(_info_label)

	_slider = HSlider.new()
	_slider.min_value = 0.0
	_slider.max_value = 24.0
	_slider.step = 0.25
	_slider.tooltip_text = "Heure du jour"
	_slider.focus_mode = Control.FOCUS_NONE
	_slider.value_changed.connect(func(v: float) -> void:
		if not _updating:
			clock.set_local_hour(v))
	box.add_child(_slider)

	var speeds := HBoxContainer.new()
	speeds.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(speeds)
	var group := ButtonGroup.new()
	for i in DayNight.SPEEDS.size():
		var b := Button.new()
		b.text = DayNight.SPEED_NAMES[i]
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 12)
		var idx := i
		b.pressed.connect(func() -> void: clock.set_speed(idx))
		speeds.add_child(b)
		_speed_buttons.append(b)
	clock.time_changed.connect(refresh)
	refresh()


static func format_hour(h: float) -> String:
	var m := int(roundf(h * 60.0)) % (24 * 60)
	return "%02d:%02d" % [m / 60, m % 60]


static func moon_phase_name(age: float) -> String:
	var names := ["nouvelle lune", "premier croissant", "premier quartier", "lune gibbeuse croissante",
		"pleine lune", "lune gibbeuse décroissante", "dernier quartier", "dernier croissant"]
	return names[int(floorf(fposmod(age + 1.0 / 16.0, 1.0) * 8.0)) % 8]


func refresh() -> void:
	if clock == null or _time_label == null:
		return
	var d := clock.local_datetime()
	var h := clock.local_hour()
	var icon := "☀" if clock.sun_horiz.x > 0.0 else "☾"
	_time_label.text = "%s  %s   ·   %d %s %d" % [icon, format_hour(h), d.day, MONTHS[int(d.month) - 1], d.year]
	var rs := clock.rise_set()
	var sun_txt: String
	if rs.x == -1.0:
		sun_txt = "nuit polaire"
	elif rs.x == -2.0:
		sun_txt = "soleil de minuit"
	else:
		sun_txt = "lever %s · coucher %s" % [format_hour(rs.x) if rs.x >= 0.0 else "—", format_hour(rs.y) if rs.y >= 0.0 else "—"]
	var off := clock.utc_offset()
	_info_label.text = "%s   ·   soleil %d°   ·   %s   ·   UTC%s%d (approx.)" % [
		sun_txt, roundi(clock.sun_horiz.x), moon_phase_name(Astro.moon_age(clock.unix_time)),
		"+" if off >= 0.0 else "−", absi(int(off))]
	_updating = true
	_slider.value = h
	_updating = false
	for i in _speed_buttons.size():
		_speed_buttons[i].set_pressed_no_signal(i == clock.speed_index)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.physical_keycode == KEY_T:
		if key.shift_pressed:
			clock.set_speed((clock.speed_index + 1) % DayNight.SPEEDS.size())
		else:
			clock.toggle_pause()
		get_viewport().set_input_as_handled()
