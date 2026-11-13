class_name ClockHud
extends CanvasLayer
## Horloge au centre de la barre du haut : heure du lieu, date, lever et coucher du
## Soleil, phase de la Lune, vitesse du temps et réglage de l'heure.
## Touche T : pause / reprise. Touche Maj+T : vitesse suivante.
## Ctrl+T, ou clic sur le Soleil / la Lune : jour permanent (l'image reste de
## jour, le temps continue).

const MONTHS := ["janv.", "févr.", "mars", "avr.", "mai", "juin", "juil.", "août", "sept.", "oct.", "nov.", "déc."]

const SPEED_ICONS := ["pause", "play", "fast", "fast", "faster", "fastest"]

var clock: DayNight
var _time_label: Label
var _date_label: Label
var _sky_icon: Button
var _jour_check: CheckButton
var _auto_check: CheckButton
var _info_label: Label
var _slider: HSlider
var _weather_pick: OptionButton
var _speed_buttons: Array[Button] = []
var _details: PanelContainer
var _updating := false
var _night := false


func _ready() -> void:
	layer = 2
	var anchor := Control.new()
	# Au centre de la barre du haut (TerreHud), entre la partie et les chiffres de la ville.
	anchor.set_anchors_preset(Control.PRESET_CENTER_TOP)
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(anchor)
	var row := HBoxContainer.new()
	row.name = "Horloge"
	row.add_theme_constant_override("separation", 8)
	row.position = Vector2(-235, 18)
	row.custom_minimum_size = Vector2(470, 42)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	anchor.add_child(row)

	_sky_icon = UiStyle.icon_button("soleil", "", "", 22, 34)
	_sky_icon.toggle_mode = true
	_sky_icon.focus_mode = Control.FOCUS_NONE
	_sky_icon.icon = Icones.get_icon("soleil", 22, UiStyle.ACCENT)
	_sky_icon.toggled.connect(func(on: bool) -> void: clock.set_jour_permanent(on))
	row.add_child(_sky_icon)
	_time_label = Label.new()
	_time_label.add_theme_font_size_override("font_size", 20)
	_time_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_time_label)
	_date_label = Label.new()
	_date_label.add_theme_font_size_override("font_size", 13)
	_date_label.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	_date_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_date_label.custom_minimum_size = Vector2(130, 0)
	_date_label.clip_text = true
	_date_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(_date_label)

	var speeds := PanelContainer.new()
	speeds.add_theme_stylebox_override("panel", UiStyle.flat_box(Color(0, 0, 0, 0.3), 9, 3))
	row.add_child(speeds)
	var sbox := HBoxContainer.new()
	sbox.add_theme_constant_override("separation", 2)
	speeds.add_child(sbox)
	var group := ButtonGroup.new()
	for i in DayNight.SPEEDS.size():
		var b := UiStyle.icon_button(SPEED_ICONS[mini(i, SPEED_ICONS.size() - 1)], DayNight.SPEED_NAMES[i], "", 16, 32)
		b.custom_minimum_size = Vector2(32, 30)
		b.tooltip_text = "%s (T : pause, Maj + T : vitesse suivante)" % DayNight.SPEED_NAMES[i]
		b.toggle_mode = true
		b.button_group = group
		var idx := i
		b.pressed.connect(func() -> void: clock.set_speed(idx))
		sbox.add_child(b)
		_speed_buttons.append(b)
	var more := UiStyle.icon_button("details", "Soleil, Lune, heure, date et météo")
	more.custom_minimum_size = Vector2(34, 34)
	more.toggle_mode = true
	more.toggled.connect(func(on: bool) -> void: _details.visible = on)
	row.add_child(more)

	# Détails (bouton « … ») : soleil, lune, fuseau, curseur de l'heure, mois, météo.
	_details = PanelContainer.new()
	_details.position = Vector2(-235, 74)
	_details.custom_minimum_size = Vector2(470, 0)
	_details.visible = false
	UiStyle.style_panel(_details)
	anchor.add_child(_details)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_details.add_child(box)
	_info_label = Label.new()
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.add_theme_font_size_override("font_size", 12)
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label.custom_minimum_size = Vector2(440, 0)
	box.add_child(_info_label)
	var hrow := HBoxContainer.new()
	box.add_child(hrow)
	var prev := UiStyle.icon_button("precedent", "Reculer d'un mois", "", 18, 32)
	prev.pressed.connect(func() -> void: clock.shift_days(-30))
	hrow.add_child(prev)
	_slider = HSlider.new()
	_slider.min_value = 0.0
	_slider.max_value = 24.0
	_slider.step = 0.25
	_slider.tooltip_text = "Heure du jour"
	_slider.focus_mode = Control.FOCUS_NONE
	_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_slider.value_changed.connect(func(v: float) -> void:
		if not _updating:
			clock.set_local_hour(v))
	hrow.add_child(_slider)
	var next := UiStyle.icon_button("suivant", "Avancer d'un mois", "", 18, 32)
	next.pressed.connect(func() -> void: clock.shift_days(30))
	hrow.add_child(next)
	_weather_pick = OptionButton.new()
	_weather_pick.focus_mode = Control.FOCUS_NONE
	_weather_pick.add_theme_font_size_override("font_size", 12)
	for n in Meteo.MODE_NAMES:
		_weather_pick.add_item("Météo : " + n)
	_weather_pick.tooltip_text = "Automatique : le temps suit le climat réel du lieu et la saison."
	_weather_pick.item_selected.connect(func(i: int) -> void:
		clock.weather.mode = i as Meteo.Mode)
	box.add_child(_weather_pick)
	_jour_check = CheckButton.new()
	_jour_check.text = "Jour permanent : toujours clair pour construire, le temps continue (Ctrl + T)"
	_jour_check.focus_mode = Control.FOCUS_NONE
	_jour_check.add_theme_font_size_override("font_size", 12)
	_jour_check.toggled.connect(func(on: bool) -> void: clock.set_jour_permanent(on))
	box.add_child(_jour_check)
	_auto_check = CheckButton.new()
	_auto_check.text = "Jour permanent tout seul quand Construire ou l'éditeur libre est ouvert"
	_auto_check.focus_mode = Control.FOCUS_NONE
	_auto_check.add_theme_font_size_override("font_size", 12)
	_auto_check.toggled.connect(func(on: bool) -> void: clock.set_jour_auto(on))
	box.add_child(_auto_check)
	clock.time_changed.connect(refresh)
	refresh()


static func format_hour(h: float) -> String:
	var m := int(roundf(h * 60.0)) % (24 * 60)
	return "%02d:%02d" % [m / 60, m % 60]


## « UTC+1 », « UTC−3:30 », « UTC+5:45 »…
static func format_offset(off: float) -> String:
	var m := roundi(absf(off) * 60.0)
	var s := "UTC%s%d" % ["+" if off >= 0.0 else "−", m / 60]
	if m % 60 != 0:
		s += ":%02d" % (m % 60)
	return s


static func moon_phase_name(age: float) -> String:
	var names := ["nouvelle lune", "premier croissant", "premier quartier", "lune gibbeuse croissante",
		"pleine lune", "lune gibbeuse décroissante", "dernier quartier", "dernier croissant"]
	return names[int(floorf(fposmod(age + 1.0 / 16.0, 1.0) * 8.0)) % 8]


func refresh() -> void:
	if clock == null or _time_label == null:
		return
	var d := clock.local_datetime()
	var h := clock.local_hour()
	var night := clock.real_sun_elev <= 0.0
	if night != _night:
		_night = night
		_sky_icon.icon = Icones.get_icon("lune" if night else "soleil", 22, UiStyle.ACCENT)
	var jour := clock.jour_actif()
	_sky_icon.set_pressed_no_signal(jour)
	_jour_check.set_pressed_no_signal(jour)
	_auto_check.set_pressed_no_signal(clock.jour_auto)
	_sky_icon.tooltip_text = ("Jour permanent activé : l'image reste de jour, le temps continue. Clic pour revenir à la vraie nuit (Ctrl + T)"
		if jour else "Jour permanent : garder l'image de jour pour construire, le temps continue (Ctrl + T)")
	_time_label.text = format_hour(h)
	_date_label.text = "%d %s %d" % [d.day, MONTHS[int(d.month) - 1], d.year]
	var rs := clock.rise_set()
	var sun_txt: String
	if rs.x == -1.0:
		sun_txt = "nuit polaire"
	elif rs.x == -2.0:
		sun_txt = "soleil de minuit"
	else:
		sun_txt = "lever %s · coucher %s" % [format_hour(rs.x) if rs.x >= 0.0 else "—", format_hour(rs.y) if rs.y >= 0.0 else "—"]
	var off := clock.utc_offset()
	_info_label.text = "%s · soleil %d° · %s · %s" % [
		sun_txt, roundi(clock.real_sun_elev), moon_phase_name(Astro.moon_age(clock.unix_time)), format_offset(off)]
	if clock.jour_actif():
		_info_label.text += " · jour permanent"
	if clock.weather != null:
		var w := clock.weather
		_info_label.text += "\n%s · %d °C" % [w.describe(), roundi(w.temperature)]
		_date_label.text += " · %d °C" % roundi(w.temperature)
		_date_label.tooltip_text = w.describe()
		if _weather_pick.selected != int(w.mode):
			_weather_pick.select(int(w.mode))
	_updating = true
	_slider.value = h
	_updating = false
	for i in _speed_buttons.size():
		_speed_buttons[i].set_pressed_no_signal(i == clock.speed_index)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.physical_keycode == KEY_T:
		if key.ctrl_pressed or key.meta_pressed:
			clock.toggle_jour_permanent()
		elif key.shift_pressed:
			clock.set_speed((clock.speed_index + 1) % DayNight.SPEEDS.size())
		else:
			clock.toggle_pause()
		Son.jouer("ui_vitesse", -4.0, 0.0, "Interface")
		get_viewport().set_input_as_handled()
