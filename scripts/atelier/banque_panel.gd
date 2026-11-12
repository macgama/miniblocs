class_name BanquePanel
extends RefCounted
## Onglet « Banque de modèles » du panneau Construire : les bâtiments
## personnalisés et les bâtiments en murs fins enregistrés, avec leurs
## étiquettes, des filtres (recherche, type, style, époque, couleur), et pour
## chacun : poser, exporter, supprimer. Import des fichiers déposés dans le
## dossier d'échange.

const CATEGORY := "banque"
const MAX_SHOWN := 60

var bs: BuildingSystem
var mob: Mobilier
var pose: BanquePose
var prepare: Callable

var _text := ""
var _type := ""
var _style := ""
var _era := ""
var _color := ""


func setup(b: BuildingSystem, m: Mobilier, p: BanquePose, prep: Callable) -> void:
	bs = b
	mob = m
	pose = p
	prepare = prep


static func _label(text: String, size := 12, dim := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if dim:
		l.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	return l


func build(bp: BuildingPanel) -> void:
	bp.add_control(_label("Tes bâtiments personnalisés et tes bâtiments en murs fins, prêts à reposer. "
		+ "Enregistre un bâtiment depuis « Personnaliser » (clic sur un bâtiment, outil 1) ou depuis l'onglet Intérieur.", 12, true))
	# --- Filtres ---------------------------------------------------------------------
	var search := LineEdit.new()
	search.placeholder_text = "Chercher un modèle…"
	search.clear_button_enabled = true
	search.text = _text
	search.text_submitted.connect(func(t: String) -> void:
		_text = t.strip_edges()
		bp.show_category(CATEGORY))
	bp.add_control(search)
	var frow := HFlowContainer.new()
	frow.add_child(_filter("Type : tous", BanqueModeles.tag_values("type"), _type, BanqueModeles.type_name, func(v: String) -> void:
		_type = v
		bp.show_category(CATEGORY)))
	frow.add_child(_filter("Style : tous", BanqueModeles.tag_values("style"), _style, BanqueModeles.style_name, func(v: String) -> void:
		_style = v
		bp.show_category(CATEGORY)))
	frow.add_child(_filter("Époque : toutes", BanqueModeles.tag_values("epoque"), _era, func(e: String) -> String: return Styles.era_name(e), func(v: String) -> void:
		_era = v
		bp.show_category(CATEGORY)))
	frow.add_child(_filter("Couleur : toutes", BanqueModeles.tag_values("couleurs"), _color, func(c: String) -> String: return c.capitalize(), func(v: String) -> void:
		_color = v
		bp.show_category(CATEGORY)))
	bp.add_control(frow)
	# --- Liste ----------------------------------------------------------------------------
	var ids := BanqueModeles.filtered(_text, _type, _style, _era, _color)
	if BanqueModeles.count() == 0:
		bp.add_control(_label("La banque est vide pour l'instant.", 13, true))
	elif ids.is_empty():
		bp.add_control(_label("Aucun modèle pour ces filtres.", 13, true))
	var shown := 0
	for id in ids:
		if shown >= MAX_SHOWN:
			bp.add_control(_label("… et %d autres : affine les filtres." % (ids.size() - shown), 12, true))
			break
		bp.add_control(_card(String(id), bp))
		shown += 1
	# --- Échanger ------------------------------------------------------------------------
	var xrow := HFlowContainer.new()
	var imp := Button.new()
	imp.text = "Importer"
	imp.tooltip_text = "Importe les modèles (.json) déposés dans le dossier d'échange."
	imp.pressed.connect(func() -> void:
		var n := BanqueModeles.import_shared()
		bs.message.emit("%d modèle%s importé%s." % [n, "s" if n > 1 else "", "s" if n > 1 else ""] if n > 0 else "Aucun nouveau modèle dans le dossier d'échange.")
		bp.show_category(CATEGORY))
	xrow.add_child(imp)
	var open := Button.new()
	open.text = "Dossier d'échange"
	open.tooltip_text = "Ouvre le dossier où arrivent les modèles exportés et où déposer ceux des autres joueurs."
	open.pressed.connect(func() -> void: OS.shell_open(BanqueModeles.share_folder()))
	xrow.add_child(open)
	bp.add_control(xrow)
	bp.add_control(_label("Partage avec les autres joueurs : chaque modèle est rangé comme un objet du Steam Workshop (dossier + aperçu). "
		+ "En attendant la sortie sur Steam, « Exporter » crée un fichier à envoyer, « Importer » lit ceux reçus.", 11, true))


func _filter(all: String, values: Array, cur: String, name_of: Callable, cb: Callable) -> OptionButton:
	var o := OptionButton.new()
	o.custom_minimum_size = Vector2(150, 0)
	o.clip_text = true
	o.add_item(all)
	o.set_item_metadata(0, "")
	for v in values:
		o.add_item(String(name_of.call(String(v))))
		o.set_item_metadata(o.item_count - 1, String(v))
		if String(v) == cur:
			o.select(o.item_count - 1)
	o.item_selected.connect(func(i: int) -> void: cb.call(String(o.get_item_metadata(i))))
	return o


func _card(id: String, bp: BuildingPanel) -> Control:
	var d := BanqueModeles.get_model(id)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiStyle.flat_box(Color(1, 1, 1, 0.06), 8, 6))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)
	var tex := BanqueModeles.preview_of(id)
	var pic := TextureRect.new()
	pic.custom_minimum_size = Vector2(64, 64)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.texture = tex if tex != null else Icones.get_icon("interieur" if String(d.genre) == "plan" else "construire", 40, UiStyle.ACCENT)
	row.add_child(pic)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var title := Label.new()
	title.text = String(d.nom)
	title.clip_text = true
	title.add_theme_font_size_override("font_size", 14)
	col.add_child(title)
	col.add_child(_label(BanqueModeles.describe(d), 11, true))
	col.add_child(_label(("Murs fins, meublé, visitable" if String(d.genre) == "plan" else "Bâtiment du catalogue personnalisé") + " · par " + String(d.get("auteur", "?")), 11, true))
	var btns := HBoxContainer.new()
	col.add_child(btns)
	var put := Button.new()
	put.text = "Poser"
	put.icon = Icones.get_icon("plus", 16)
	put.pressed.connect(func() -> void:
		if prepare.is_valid():
			prepare.call()
		if String(d.genre) == "facade":
			if BuildingCatalog.get_type(String(d.type)).is_empty():
				bs.message.emit("Ce modèle utilise un bâtiment inconnu de cette version du jeu.")
				return
			bs.set_place(String(d.type), Personnalisation.clean(d.get("perso", {})), int(d.get("v", 0)))
		else:
			pose.start(id))
	btns.add_child(put)
	var exp := Button.new()
	exp.text = "Exporter"
	exp.tooltip_text = "Crée un fichier à partager dans le dossier d'échange."
	exp.pressed.connect(func() -> void:
		var path := BanqueModeles.export_model(id)
		bs.message.emit("Modèle exporté : %s" % ProjectSettings.globalize_path(path) if path != "" else "Export impossible."))
	btns.add_child(exp)
	var del := UiStyle.icon_button("gomme", "Retirer de la banque", "", 16, 28)
	del.pressed.connect(func() -> void:
		BanqueModeles.remove(id)
		bp.show_category(CATEGORY))
	btns.add_child(del)
	return card
