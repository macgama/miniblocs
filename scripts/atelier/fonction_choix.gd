class_name FonctionChoix
extends VBoxContainer
## Choix de la fonction d'un modèle ou d'une création : le bâtiment du jeu dont
## il prend le rôle (catégorie, recherche, liste). Voir ModelesJeu.

signal picked(fonction: String)

const MAX_SHOWN := 40

var current := ""
var _cat := ""
var _text := ""
var _results: VBoxContainer
var _groups: Array = []


func _init(cur := "") -> void:
	current = cur
	add_theme_constant_override("separation", 4)
	var t := BuildingCatalog.get_type(cur)
	_cat = String(t.get("cat", ""))
	_groups = ModelesJeu.fonctions()
	var row := HBoxContainer.new()
	var cat := ChoixVisuel.new()
	cat.modele_meta = "categorie"
	cat.icone = "construire"
	cat.custom_minimum_size = Vector2(150, 0)
	cat.clip_text = true
	cat.add_item("Toutes les catégories")
	cat.set_item_metadata(0, "")
	for g in _groups:
		cat.add_item(String(g.name))
		cat.set_item_metadata(cat.item_count - 1, String(g.cat))
		if String(g.cat) == _cat:
			cat.select(cat.item_count - 1)
	cat.item_selected.connect(func(i: int) -> void:
		_cat = String(cat.get_item_metadata(i))
		_fill())
	row.add_child(cat)
	var search := LineEdit.new()
	search.placeholder_text = "Centrale, stade, piscine…"
	search.clear_button_enabled = true
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.text_changed.connect(func(txt: String) -> void:
		_text = txt.strip_edges().to_lower()
		_fill())
	row.add_child(search)
	add_child(row)
	_results = VBoxContainer.new()
	_results.add_theme_constant_override("separation", 2)
	add_child(_results)
	_fill()


## Fonctions qui passent le filtre (catégorie, texte).
func matches() -> Array:
	var out := []
	for g in _groups:
		if _cat != "" and String(g.cat) != _cat:
			continue
		for id in g.ids:
			var t := BuildingCatalog.get_type(String(id))
			if _text != "" and not (String(t.name) + " " + String(t.get("desc", "")) + " " + String(id)).to_lower().contains(_text):
				continue
			out.append(String(id))
	return out


func _fill() -> void:
	for c in _results.get_children():
		c.queue_free()
	var ids := matches()
	for i in mini(ids.size(), MAX_SHOWN):
		var id: String = ids[i]
		var t := BuildingCatalog.get_type(id)
		var b := Button.new()
		b.text = String(t.name) + ("  ✓" if id == current else "")
		b.tooltip_text = _resume(t)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.pressed.connect(func() -> void: picked.emit(id))
		_results.add_child(b)
	if ids.size() > MAX_SHOWN:
		_results.add_child(_dim("… et %d autres : précise la recherche." % (ids.size() - MAX_SHOWN)))
	elif ids.is_empty():
		_results.add_child(_dim("Aucun bâtiment ne correspond."))


static func _resume(t: Dictionary) -> String:
	var parts: Array[String] = [String(t.get("desc", ""))]
	for k in [["logements", "logements"], ["emplois", "emplois"], ["visiteurs", "visiteurs"]]:
		if int(t.get(k[0], 0)) > 0:
			parts.append("%d %s" % [int(t[k[0]]), k[1]])
	parts.append("%d × %d m" % [int(t.get("w", 0)), int(t.get("d", 0))])
	return " · ".join(parts)


static func _dim(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l
