class_name RechercheUniverselle
extends CanvasLayer
## Recherche dans tout le jeu (touche Espace, ou tuile « Chercher ») : on tape
## « zoo », « budget », « route », « hôpital »… et elle propose à la fois les
## bâtiments à poser, les outils et les panneaux de gestion. Flèches pour
## choisir, Entrée pour valider, Échap pour fermer.

## Un résultat est choisi : {genre: "batiment"|"outil"|"panneau"|"action", id}.
signal choisi(entree: Dictionary)

const MAX_RESULTATS := 12

## Vrai si la recherche peut s'ouvrir maintenant (pas en vue au sol, pas de fenêtre).
var peut_ouvrir: Callable
## Entrées en plus des bâtiments, outils et panneaux : [{genre, id, nom, mots, cle}].
var extras: Array = []

var _panel: PanelContainer
var _edit: LineEdit
var _list: VBoxContainer
var _resultats: Array = []
var _sel := 0
var _index: Array = []


func _ready() -> void:
	layer = 20
	var dim := ColorRect.new()
	dim.name = "Voile"
	dim.color = Color(0, 0, 0, 0.35)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
			fermer())
	add_child(dim)
	_panel = PanelContainer.new()
	_panel.name = "Recherche"
	_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.offset_top = 120
	_panel.custom_minimum_size = Vector2(620, 0)
	UiStyle.style_panel(_panel, 0.97, 14, 12)
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	_panel.add_child(col)
	_edit = LineEdit.new()
	_edit.placeholder_text = "Chercher dans tout le jeu : zoo, budget, route, hôpital, piscine…"
	_edit.right_icon = Icones.get_icon("chercher", 20, UiStyle.TEXT_DIM)
	_edit.add_theme_font_size_override("font_size", 18)
	_edit.custom_minimum_size = Vector2(0, 42)
	_edit.text_changed.connect(func(_t: String) -> void:
		_sel = 0
		_remplir())
	_edit.gui_input.connect(_clavier)
	_edit.text_submitted.connect(func(_t: String) -> void: valider())
	col.add_child(_edit)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 2)
	col.add_child(_list)
	var aide := Label.new()
	aide.text = "↑ ↓ choisir  ·  Entrée valider  ·  Échap fermer"
	aide.add_theme_font_size_override("font_size", 11)
	aide.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	col.add_child(aide)
	visible = false


func est_ouverte() -> bool:
	return visible


func ouvrir(texte := "") -> void:
	_construire_index()
	visible = true
	_edit.text = texte
	_sel = 0
	_remplir()
	_edit.grab_focus()
	_edit.caret_column = texte.length()


func fermer() -> void:
	visible = false
	if _edit.has_focus():
		_edit.release_focus()


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if visible and k.keycode == KEY_ESCAPE:
		fermer()
		get_viewport().set_input_as_handled()
		return
	if not visible and k.keycode == KEY_SPACE and not k.shift_pressed and not k.ctrl_pressed and not k.alt_pressed:
		if peut_ouvrir.is_valid() and not peut_ouvrir.call():
			return
		ouvrir()
		get_viewport().set_input_as_handled()


func _clavier(e: InputEvent) -> void:
	var k := e as InputEventKey
	if k == null or not k.pressed:
		return
	match k.keycode:
		KEY_DOWN:
			_sel = mini(_sel + 1, _resultats.size() - 1)
			_marquer()
			_edit.accept_event()
		KEY_UP:
			_sel = maxi(_sel - 1, 0)
			_marquer()
			_edit.accept_event()
		KEY_ESCAPE:
			fermer()
			_edit.accept_event()


# --- Index ----------------------------------------------------------------------

func _construire_index() -> void:
	_index.clear()
	for c in TerreHud.CATEGORIES:
		if c.get("cache", false) or c.get("mode", "gerer") == "creer":
			continue
		if c.has("tools") and (c.tools as Array).size() == 1 and int(c.tools[0]) == 0:
			continue
		if c.get("panel", false):
			_index.append({"genre": "panneau", "id": String(c.id), "nom": String(c.name).get_slice(" (", 0), "detail": String(c.name),
				"mots": String(c.name), "cle": String(c.key), "icone": String(c.icon)})
	for i in TerreHud.TOOLS.size():
		if i == 0:
			continue
		_index.append({"genre": "outil", "id": str(i), "nom": String(TerreHud.TOOLS[i].name), "detail": "Outil",
			"mots": String(TerreHud.TOOLS[i].name) + " " + String(TerreHud.TOOL_SHORT[i]), "cle": OS.get_keycode_string(TerreHud.TOOLS[i].key),
			"icone": String(TerreHud.TOOL_ICONS[i])})
	_index.append_array(extras)
	var all := BuildingCatalog.all_types()
	for id in all:
		var t: Dictionary = all[id]
		if t.get("cache", false) or EditionDemo.categorie_verrouillee(String(t.get("cat", ""))):
			continue
		var cat := String(t.get("cat", ""))
		var theme := BuildingPanel.theme_of(cat)
		var tname := ""
		for th in BuildingPanel.THEMES:
			if String(th.id) == theme:
				tname = String(th.name)
		var sub := String(BuildingPanel.SUB_NAMES.get(cat, ""))
		_index.append({"genre": "batiment", "id": String(id), "nom": String(t.name),
			"detail": ("%s › %s" % [tname, sub]) if sub != "" and sub != tname else tname,
			"mots": "%s %s %s %s" % [t.name, t.get("desc", ""), tname, sub], "cle": "",
			"icone": String(BuildingPanel.CAT_ICONS.get(cat, "construire"))})


## Résultats pour un texte : les noms qui commencent par le mot, puis ceux qui
## le contiennent, puis les descriptions. Panneaux et outils avant les bâtiments
## à score égal.
func chercher(texte: String) -> Array:
	if _index.is_empty():
		_construire_index()
	var q: String = FavorisConstruire.plier(texte.strip_edges())
	if q == "":
		return []
	var notes := []
	for e in _index:
		var nom: String = FavorisConstruire.plier(String(e.nom))
		var s := 0
		if nom.begins_with(q):
			s = 4
		elif (" " + nom).contains(" " + q):
			s = 3
		elif nom.contains(q):
			s = 2
		elif FavorisConstruire.plier(String(e.mots)).contains(q):
			s = 1
		if s == 0:
			continue
		if e.genre != "batiment":
			s += 1
		notes.append([s, e])
	notes.sort_custom(func(a: Array, b: Array) -> bool:
		if a[0] != b[0]:
			return a[0] > b[0]
		return String(a[1].nom).length() < String(b[1].nom).length())
	var out := []
	for n in notes:
		if out.size() >= MAX_RESULTATS:
			break
		out.append(n[1])
	return out


const TITRES := {"panneau": "Gérer", "outil": "Outils", "action": "Actions", "batiment": "Bâtiments"}


func _remplir() -> void:
	for ch in _list.get_children():
		_list.remove_child(ch)
		ch.queue_free()
	_resultats = chercher(_edit.text)
	if _edit.text.strip_edges() == "":
		var l := Label.new()
		l.text = "Tape un mot : un bâtiment, un outil ou un menu de gestion."
		l.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
		_list.add_child(l)
		return
	if _resultats.is_empty():
		var l := Label.new()
		l.text = "Rien trouvé pour « %s »." % _edit.text.strip_edges()
		l.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
		_list.add_child(l)
		return
	var last := ""
	for i in _resultats.size():
		var e: Dictionary = _resultats[i]
		var g := String(e.genre)
		var titre := String(TITRES.get(g, ""))
		if titre != last:
			var h := Label.new()
			h.text = titre.to_upper()
			h.add_theme_font_size_override("font_size", 11)
			h.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
			_list.add_child(h)
			last = titre
		var b := Button.new()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.icon = Icones.get_icon(String(e.get("icone", "construire")), 18)
		b.text = "%s   %s" % [e.nom, e.detail] if String(e.detail) != "" and String(e.detail) != String(e.nom) else String(e.nom)
		if String(e.get("cle", "")) != "":
			b.text += "   (%s)" % e.cle
		b.clip_text = true
		var idx := i
		b.pressed.connect(func() -> void:
			_sel = idx
			valider())
		b.mouse_entered.connect(func() -> void:
			_sel = idx
			_marquer())
		_list.add_child(b)
	_marquer()


func _marquer() -> void:
	var i := -1
	for ch in _list.get_children():
		if ch is Button:
			i += 1
			var b := ch as Button
			var on := i == _sel
			b.add_theme_stylebox_override("normal", UiStyle.flat_box(Color(UiStyle.ACCENT, 0.18) if on else Color(0, 0, 0, 0), 7, 5))
			b.add_theme_color_override("font_color", UiStyle.ACCENT if on else Color.WHITE)


func valider() -> void:
	if _resultats.is_empty():
		return
	var e: Dictionary = _resultats[clampi(_sel, 0, _resultats.size() - 1)]
	fermer()
	choisi.emit(e)
