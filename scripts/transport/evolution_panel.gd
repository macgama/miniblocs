class_name EvolutionPanel
extends CanvasLayer
## Panneau « Faire évoluer la route » : s'ouvre quand on clique sur une route
## avec l'outil Faire évoluer (bouton du panneau Route, ou fiche d'une route
## dans le panneau Trafic). On choisit la classe, le nombre de voies, leur
## largeur, les trottoirs, le terre-plein, les couloirs de bus et le tramway ;
## le devis (prix, durée, nouvelle largeur) se met à jour, puis « Lancer les
## travaux » (EvolutionVoies.lancer).

const W := 380.0

var evolution: EvolutionVoies
var eid := -1
## Réglages en cours d'édition.
var t := ""
var w := {}
var _panel: PanelContainer
var _title: Label
var _now: Label
var _class: ChoixVisuel
var _vignettes: Vignettes
var _class_ids: Array = []
var _lanes: SpinBox
var _lane_w: SpinBox
var _bords: ChoixVisuel
var _bords_ids: Array = []
var _tp: CheckBox
var _bus: CheckBox
var _tram: CheckBox
var _devis: Label
var _go: Button
var _filling := false


func setup(ev: EvolutionVoies) -> void:
	evolution = ev
	_build()
	evolution.transport.upgrade_picked.connect(open_for)


func _build() -> void:
	layer = 6
	_panel = PanelContainer.new()
	UiStyle.place_right(_panel)
	_panel.custom_minimum_size = Vector2(W, 0)
	UiStyle.style_panel(_panel)
	_panel.visible = false
	add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var icon := TextureRect.new()
	icon.texture = Icones.get_icon("route", 22, UiStyle.ACCENT)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	head.add_child(icon)
	_title = Label.new()
	_title.text = "Faire évoluer la route"
	_title.add_theme_font_size_override("font_size", 16)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	var x := UiStyle.icon_button("fermer", "Fermer", "Échap", 18, 32)
	x.pressed.connect(close)
	head.add_child(x)
	_now = _label("", 12, true)
	v.add_child(_now)
	_vignettes = Vignettes.new()
	add_child(_vignettes)
	_class = ChoixVisuel.new()
	_class.tile_size = Vector2(150, 142)
	_class.image_height = 96.0
	_class.max_columns = 4
	_class.titre = "Nouvelle classe de la route"
	_class.illustrer = func(i: int, cible: TextureRect) -> void:
		if i >= 0 and i < _class_ids.size():
			VignettesVoies.demander(_vignettes, String(_class_ids[i]), cible)
	_class.item_selected.connect(func(i: int) -> void:
		if _filling:
			return
		var nt: String = _class_ids[i]
		w = _garder(nt, w)
		t = nt
		_fill())
	v.add_child(_row("Classe", _class))
	_class.custom_minimum_size = Vector2(190, 44)
	_lanes = _spin(1, 4, 1)
	_lanes.value_changed.connect(func(n: float) -> void: _on_lanes(int(n)))
	v.add_child(_row("Voies par sens", _lanes))
	_lane_w = _spin(2.75, 3.5, 0.05)
	_lane_w.value_changed.connect(func(x2: float) -> void:
		if not _filling:
			w.lane_w = x2
			_update())
	v.add_child(_row("Largeur d'une voie (m)", _lane_w))
	_bords = ChoixVisuel.new()
	_bords.titre = "Bords de la route"
	_bords.item_selected.connect(func(i: int) -> void:
		if not _filling:
			w.bords = _bords_ids[i]
			_update())
	v.add_child(_row("Bords", _bords))
	_bords.custom_minimum_size = Vector2(190, 44)
	_tp = _check("Terre-plein central", "tp")
	v.add_child(_tp)
	_bus = _check("Couloirs de bus (un par sens, à droite)", "bus")
	v.add_child(_bus)
	_tram = _check("Tramway au milieu (deux voies, arrêts et lignes possibles)", "tram")
	v.add_child(_tram)
	v.add_child(HSeparator.new())
	_devis = _label("", 12, false)
	v.add_child(_devis)
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 6)
	v.add_child(r)
	_go = Button.new()
	_go.text = "Lancer les travaux"
	_go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_go.pressed.connect(_on_go)
	r.add_child(_go)
	var c := Button.new()
	c.text = "Annuler"
	c.pressed.connect(close)
	r.add_child(c)


func _label(text: String, size: int, dim: bool) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	if dim:
		l.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(W - 24.0, 0)
	return l


func _row(name_: String, c: Control) -> HBoxContainer:
	var r := HBoxContainer.new()
	var l := _label(name_, 13, false)
	l.custom_minimum_size = Vector2(150, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(l)
	c.custom_minimum_size = Vector2(190, 0)
	r.add_child(c)
	return r


func _spin(lo: float, hi: float, step: float) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	return s


func _check(text: String, key: String) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.toggled.connect(func(on: bool) -> void:
		if not _filling:
			w[key] = on
			_update())
	return c


func is_open() -> bool:
	return _panel.visible


func close() -> void:
	_panel.visible = false
	eid = -1


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.keycode == KEY_ESCAPE and is_open():
		close()
		get_viewport().set_input_as_handled()


## Ouvre le panneau pour la route eid.
func open_for(id: int) -> void:
	var net: TransportNetwork = evolution.network
	if not net.edges.has(id) or TransportTypes.mode_of(net.edges[id].t) != TransportTypes.Mode.ROAD:
		return
	eid = id
	var e: Dictionary = net.edges[id]
	t = String(e.t)
	w = _complet(t, e.w)
	_panel.visible = true
	_fill()


## Réglages complets (avec les aménagements de la classe), pour les cases.
static func _complet(id: String, spec: Dictionary) -> Dictionary:
	var s := TransportTypes.normalize(id, spec)
	s.bords = TransportTypes.side_kind_of(id, s)
	s.tp = TransportTypes.tp_of(id, s) > 0.0
	s.bus = TransportTypes.bus_of(id, s) > 0.0
	s.tram = TransportTypes.has_tram(id, s)
	return s


## En changeant de classe : on garde ce qui a un sens dans la nouvelle.
static func _garder(nt: String, s: Dictionary) -> Dictionary:
	var c := TransportTypes.get_type(nt)
	var o := s.duplicate()
	if c.has("lanes"):
		o.lanes = clampi(int(s.get("lanes", 1)), int(c.lanes[0]), int(c.lanes[1]))
		o.lane_w = clampf(float(s.get("lane_w", c.lane_w[2])), float(c.lane_w[0]), float(c.lane_w[1]))
	var opt := TransportTypes.options_of(nt)
	if not opt.bords:
		o.erase("bords")
	o.erase("tp")
	var auto := float(c.get("median", 0.0)) > 0.0 and int(o.get("lanes", 1)) >= int(c.get("median_from", 9))
	o.tp = auto or bool(s.get("tp", false))
	return o


## Plus de voies que la classe n'en permet : on prend la classe suivante de la
## famille (rue → avenue, pour passer de 2 à 4 voies).
func _on_lanes(n: int) -> void:
	if _filling:
		return
	var c := TransportTypes.get_type(t)
	if n > int(c.lanes[1]) or n < int(c.lanes[0]):
		for nt in TransportTypes.evolutions_of(t):
			var cc := TransportTypes.get_type(nt)
			if n >= int(cc.lanes[0]) and n <= int(cc.lanes[1]):
				var keep_tp := bool(w.get("tp", false))
				w.lanes = n
				w = _garder(nt, w)
				var auto := float(cc.get("median", 0.0)) > 0.0 and n >= int(cc.get("median_from", 9))
				w.tp = keep_tp or auto
				t = nt
				break
	else:
		var was_auto := float(c.get("median", 0.0)) > 0.0 and int(w.get("lanes", 1)) >= int(c.get("median_from", 9))
		var auto2 := float(c.get("median", 0.0)) > 0.0 and n >= int(c.get("median_from", 9))
		if auto2 != was_auto:
			w.tp = auto2
	w.lanes = n
	_fill()


func _fill() -> void:
	_filling = true
	var e: Dictionary = evolution.network.edges.get(eid, {})
	if e.is_empty():
		_filling = false
		close()
		return
	_now.text = "Aujourd'hui : %s, %d m · %s" % [String(TransportTypes.get_type(e.t).name).to_lower(), roundi(float(e.len)), TransportTypes.describe(e.t, e.w)]
	_class_ids = TransportTypes.evolutions_of(String(e.t))
	_class.clear()
	for id in _class_ids:
		_class.add_item(String(TransportTypes.get_type(id).name))
		_class.set_item_tooltip(_class.item_count - 1, VignettesVoies.details(String(id)))
	_class.select(maxi(0, _class_ids.find(t)))
	var c := TransportTypes.get_type(t)
	var lo := 9
	var hi := 1
	for id in _class_ids:
		var cc := TransportTypes.get_type(id)
		lo = mini(lo, int(cc.lanes[0]))
		hi = maxi(hi, int(cc.lanes[1]))
	_lanes.min_value = lo
	_lanes.max_value = hi
	_lanes.value = int(w.get("lanes", 1))
	_lane_w.min_value = float(c.lane_w[0])
	_lane_w.max_value = float(c.lane_w[1])
	_lane_w.value = float(w.get("lane_w", c.lane_w[2]))
	_lane_w.editable = float(c.lane_w[0]) != float(c.lane_w[1])
	var opt := TransportTypes.options_of(t)
	_bords.clear()
	_bords_ids = []
	for k in TransportTypes.BORDS:
		_bords_ids.append(k)
		_bords.add_item(String(TransportTypes.BORDS_NOMS[k]))
		_bords.set_item_icon(_bords.item_count - 1, Pictos.get_picto("bords_" + String(k), 120))
	var bk := TransportTypes.side_kind_of(t, w) if w.has("bords") else String(c.get("side_kind", ""))
	_bords.select(maxi(0, _bords_ids.find(bk)))
	_bords.disabled = not opt.bords
	_tp.disabled = not opt.tp
	_bus.disabled = not opt.bus
	_tram.disabled = not opt.tram
	_tp.button_pressed = bool(w.get("tp", false)) and opt.tp
	_bus.button_pressed = bool(w.get("bus", false)) and opt.bus
	_tram.button_pressed = bool(w.get("tram", false)) and opt.tram
	_filling = false
	_update()


## Réglages à envoyer (normalisés : seulement ce qui diffère de la classe).
func reglages() -> Dictionary:
	return TransportTypes.normalize(t, w)


func _update() -> void:
	if eid < 0:
		return
	var d: Dictionary = evolution.devis(eid, t, reglages())
	var txt := "Après : %s m de large (aujourd'hui %s m)\n%s" % [TransportTypes._num(snappedf(float(d.apres), 0.05)),
		TransportTypes._num(snappedf(float(d.avant), 0.05)), TransportTypes.describe(t, reglages())]
	if d.ok:
		for l in d.lignes:
			txt += "\n· " + String(l)
		txt += "\nTotal : %s, payé au fil des travaux · environ %s de chantier ; la route reste ouverte avec une file sur deux." % [
			BuildingSystem.format_money(int(d.cout)), _duree(float(d.heures))]
	else:
		txt += "\n" + String(d.reason)
	_devis.text = txt
	_go.disabled = not d.ok


func _duree(heures: float) -> String:
	var pop: Population = evolution.suivi.population if evolution.suivi != null else null
	var h_jeu := heures / maxf(Chantiers.rythme(pop), 0.01)
	# Équipes en semaine, 9 h par jour : environ 6,3 h de travail par jour de calendrier.
	return Chantiers.duree_texte(h_jeu / 6.3 * 86400.0)


func _on_go() -> void:
	var res: Dictionary = evolution.lancer(eid, t, reglages())
	if not res.ok:
		_devis.text += "\n" + String(res.reason)
		return
	close()
