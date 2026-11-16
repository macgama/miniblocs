class_name BuildingPanel
extends CanvasLayer
## Panneau « Construire » (à droite de l'écran) : catégories en icônes,
## bâtiments en vignettes, démolition ; « Règles » ouvre le panneau Admin.
## B ou le bouton Construire de la barre du bas : afficher ou masquer.

signal building_chosen(id: String)
signal demolish_chosen
## Bouton « Règles » : ouvrir le panneau Admin (réglages de la partie).
signal admin_requested
signal zone_chosen(kind: String)
signal zone_remove_chosen
signal growth_toggled(on: bool)
signal block_tool_chosen(tool: int)
signal block_material_chosen(material: int)
signal block_shape_chosen(shape: int)
signal block_tint_chosen(tint: int)
## Orientation de la forme : "tourner", "renverser", "coucher" ou "redresser".
signal block_orient(action: String)
signal wall_height_changed(height: int)
## Grandes pièces : diamètre ou largeur (m), et hauteur ou longueur (m).
signal block_piece_changed(size: int, count: int)
signal zone_style_chosen(style: String)
signal capture_name_changed(name: String)
signal creation_deleted(id: String)
## Mode « Murs et étages » de l'éditeur libre.
signal plan_tool_chosen(tool: int)
signal plan_opening_chosen(kind: String)
## Aménagement choisi (bassin, voie, gradins, terrain de sport).
signal plan_amenagement_chosen(kind: String)
signal plan_amenagement_material(on: bool)
signal plan_level_step(delta: int)
signal plan_cutaway_toggled(on: bool)
signal plan_copy_level(count: int)
signal plan_roof(kind: String)
signal plan_wall_levels(count: int)
signal plan_reseat
## Échelle des étages : clic sur un étage.
signal plan_level_set(level: int)
## « Enregistrer mon bâtiment » (parcours guidé de l'Atelier).
signal save_requested
## « Créer un nouveau bâtiment » (Mes modèles) : ouvrir l'Atelier.
signal atelier_requested

var _panel: PanelContainer
var _list: VBoxContainer
var _money_label: Label
var _summary_label: Label
var _cat_buttons: Dictionary = {}
var _item_group := ButtonGroup.new()
var _item_buttons: Array[Control] = []
var _demolish_button: Button
var _category := "logement"
var _zone_label: Label
var _growth := true
var _block_label: Label
var _block_material := 0
var _block_shape := 0
var _block_tint := 0
var _mat_family := ""
var _mat_search := ""
var _plan_tab := "portes"
var _block_tab := "formes"
var _icons := {}
var _wall_height := 3
var _piece_d := 6
var _piece_n := 4
var _region := ""
var _era := ""
var _search := ""
var _zone_style := ""
var _filters: HFlowContainer
var _capture_name := ""
var _cat_title: Label
var _rules_button: Button
var _vignettes: Vignettes
## "blocs" (blocs de 1 m) ou "plans" (murs fins, étages, intérieurs).
var _block_mode := "plans"
var _level_label: Label
var _level_text := "Rez-de-chaussée"
var _copy_count := 1
var _wall_levels := 1
var _cutaway := true
var _opening := "porte"
var _amenag := ""
var _amenag_own_mat := false
## Mode Créer (atelier) : seuls l'éditeur libre, l'intérieur et Mes créations
## sont proposés. Mode Gérer : catalogue et zonage, sans l'éditeur libre.
var workshop := false
## Création dont on choisit la fonction (onglet Mes créations).
var _creation_choosing := ""
const WORKSHOP_TABS := ["blocs", "creations", "interieur", "banque"]
var _head_icon: TextureRect
## Mode Gérer : recherche dans tout le catalogue et thèmes nommés (voir THEMES).
var _global_search: LineEdit
var _local_search: LineEdit
var _themes_scroll: ScrollContainer
var _themes_box: VBoxContainer
var _theme_open := "logement"
var _head_title: Label
var _cats_grid: GridContainer
var _foot: HBoxContainer
## Échelle des étages : {étage: murs} du bâtiment visé, et l'étage actif.
var _ladder_box: VBoxContainer
var _ladder_counts := {}
var _ladder_level := 0

## Icône de chaque onglet.
const CAT_ICONS := {"logement": "logement", "commerce": "commerce", "industrie": "industrie", "production": "ressources", "reseaux": "reseaux",
	"services": "services", "dechets": "dechets", "funeraire": "funeraire", "loisirs": "loisirs", "sport": "sport", "parc": "parc", "zoo": "zoo", "spectacles": "masques", "tourisme": "valise", "espaces": "publics", "patrimoine": "patrimoine",
	"zones": "zonage", "blocs": "editeur", "creations": "creations", "interieur": "interieur", "banque": "banque", "mes_modeles": "atelier"}

## Thèmes du catalogue (mode Gérer) : nom écrit, icône, catégories du catalogue.
## « favoris » et « recents » sont des listes du joueur (FavorisConstruire).
const THEMES := [
	{"id": "favoris", "name": "Favoris", "icon": "etoile", "cats": ["favoris"]},
	{"id": "recents", "name": "Récents", "icon": "horloge", "cats": ["recents"]},
	{"id": "logement", "name": "Logement", "icon": "logement", "cats": ["logement"], "head": "Thèmes"},
	{"id": "commerce", "name": "Commerce et bureaux", "icon": "commerce", "cats": ["commerce"]},
	{"id": "industrie", "name": "Industrie et production", "icon": "industrie", "cats": ["industrie", "production"]},
	{"id": "services", "name": "Services publics", "icon": "services", "cats": ["services", "funeraire"]},
	{"id": "reseaux", "name": "Réseaux et déchets", "icon": "reseaux", "cats": ["reseaux", "dechets"]},
	{"id": "loisirs", "name": "Loisirs et culture", "icon": "loisirs", "cats": ["loisirs", "parc", "zoo", "spectacles", "espaces"]},
	{"id": "sport", "name": "Sport", "icon": "sport", "cats": ["sport"]},
	{"id": "tourisme", "name": "Tourisme", "icon": "valise", "cats": ["tourisme"]},
	{"id": "mes_modeles", "name": "Mes modèles", "icon": "atelier", "cats": ["mes_modeles"]},
	{"id": "zones", "name": "Zonage", "icon": "zonage", "cats": ["zones"], "head": "Outils"},
]
## Nom court des sous-thèmes (sous un thème ouvert).
const SUB_NAMES := {"industrie": "Industrie", "production": "Production et ressources", "services": "Services publics", "funeraire": "Funéraire",
	"reseaux": "Électricité, eau, égouts", "dechets": "Déchets et propreté", "loisirs": "Loisirs", "parc": "Parc d'attractions", "zoo": "Zoo",
	"spectacles": "Spectacles et musées", "espaces": "Places et jardins"}

## Onglet Intérieur : fonction (BuildingPanel) qui remplit la liste (voir InterieurPanel).
var interieur_builder: Callable
## Onglet Banque de modèles (voir BanquePanel).
var banque_builder: Callable


func _ready() -> void:
	_item_group.allow_unpress = true
	_vignettes = Vignettes.new()
	_vignettes.name = "Vignettes"
	add_child(_vignettes)
	_panel = PanelContainer.new()
	UiStyle.place_right(_panel)
	_panel.anchor_bottom = 1.0
	_panel.offset_bottom = -112
	_panel.visible = false
	UiStyle.style_panel(_panel)
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_panel.add_child(box)

	var head := HBoxContainer.new()
	box.add_child(head)
	var hi := TextureRect.new()
	hi.texture = Icones.get_icon("construire", 24, UiStyle.ACCENT)
	hi.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	head.add_child(hi)
	_head_icon = hi
	var title := Label.new()
	title.text = "Construire"
	title.add_theme_font_size_override("font_size", 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_head_title = title
	_money_label = Label.new()
	_money_label.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	head.add_child(_money_label)
	var close := UiStyle.icon_button("fermer", "Fermer", "B", 18, 32)
	close.pressed.connect(func() -> void: set_open(false))
	head.add_child(close)

	var cats := GridContainer.new()
	cats.columns = 5
	cats.add_theme_constant_override("h_separation", 4)
	cats.add_theme_constant_override("v_separation", 4)
	box.add_child(cats)
	_cats_grid = cats
	var cat_group := ButtonGroup.new()
	var tabs: Array = [{"id": "favoris", "name": "Favoris"}, {"id": "recents", "name": "Récents"}]
	tabs.append_array(BuildingCatalog.CATEGORIES.duplicate())
	tabs.append({"id": ModelesJeu.CATEGORY, "name": "Mes modèles : les bâtiments de ton atelier, avec leur fonction", "color": Color("9fe3b0")})
	tabs.append({"id": "zones", "name": "Zonage", "color": Color("ffd166")})
	tabs.append({"id": "blocs", "name": "Éditeur libre", "color": Color("8ecae6")})
	tabs.append({"id": Creations.CATEGORY, "name": "Mes créations", "color": Color("f4a261")})
	tabs.append({"id": "interieur", "name": "Intérieur : meubles, pièces, bâtiments meublés", "color": Color("c9a0dc")})
	tabs.append({"id": "banque", "name": "Banque de modèles : bâtiments personnalisés et meublés", "color": Color("9fe3b0")})
	for c in tabs:
		# Édition démo : parc de loisirs, zoo, spectacles et tourisme dans le jeu complet.
		if EditionDemo.categorie_verrouillee(String(c.id)):
			continue
		var b := UiStyle.icon_button(String(CAT_ICONS.get(c.id, "construire")), c.name, "", 26, 46)
		b.custom_minimum_size = Vector2(70, 46)
		b.toggle_mode = true
		b.button_group = cat_group
		var id: String = c.id
		b.pressed.connect(func() -> void: show_category(id))
		cats.add_child(b)
		_cat_buttons[id] = b
	# Recherche dans tout le catalogue (mode Gérer), au-dessus des thèmes.
	_global_search = LineEdit.new()
	_global_search.name = "RechercheCatalogue"
	_global_search.placeholder_text = "Chercher dans tout le catalogue : piscine, école, gare…"
	_global_search.clear_button_enabled = true
	_global_search.right_icon = Icones.get_icon("chercher", 18, UiStyle.TEXT_DIM)
	_global_search.text_changed.connect(func(txt: String) -> void:
		_search = txt.strip_edges().to_lower()
		show_category(_category))
	box.add_child(_global_search)
	# Thèmes nommés à gauche, bâtiments à droite.
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	box.add_child(body)
	_themes_scroll = ScrollContainer.new()
	_themes_scroll.custom_minimum_size = Vector2(196, 0)
	_themes_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(_themes_scroll)
	_themes_box = VBoxContainer.new()
	_themes_box.name = "Themes"
	_themes_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_themes_box.add_theme_constant_override("separation", 1)
	_themes_scroll.add_child(_themes_box)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	body.add_child(right)
	_cat_title = Label.new()
	_cat_title.add_theme_font_size_override("font_size", 15)
	_cat_title.add_theme_color_override("font_color", UiStyle.ACCENT)
	_cat_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_cat_title)

	# Filtres de la bible : région du monde, époque, recherche par nom.
	_filters = HFlowContainer.new()
	right.add_child(_filters)
	var region_opt := OptionButton.new()
	region_opt.add_item("Toutes les régions")
	region_opt.set_item_metadata(0, "")
	for r in Styles.REGIONS:
		region_opt.add_item(r.name)
		region_opt.set_item_metadata(region_opt.item_count - 1, r.id)
	region_opt.item_selected.connect(func(i: int) -> void:
		_region = String(region_opt.get_item_metadata(i))
		show_category(_category))
	_filters.add_child(region_opt)
	var era_opt := OptionButton.new()
	era_opt.add_item("Toutes les époques")
	era_opt.set_item_metadata(0, "")
	for e in Styles.ERAS:
		era_opt.add_item(e.name)
		era_opt.set_item_metadata(era_opt.item_count - 1, e.id)
	era_opt.item_selected.connect(func(i: int) -> void:
		_era = String(era_opt.get_item_metadata(i))
		show_category(_category))
	_filters.add_child(era_opt)
	var search := LineEdit.new()
	_local_search = search
	search.placeholder_text = "Chercher…"
	search.custom_minimum_size = Vector2(150, 0)
	search.clear_button_enabled = true
	search.text_changed.connect(func(txt: String) -> void:
		_search = txt.strip_edges().to_lower()
		show_category(_category))
	_filters.add_child(search)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 200)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)

	var foot := HBoxContainer.new()
	box.add_child(foot)
	_foot = foot
	_demolish_button = Button.new()
	_demolish_button.text = "Démolir un bâtiment"
	_demolish_button.icon = Icones.get_icon("demolir", 20)
	_demolish_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_demolish_button.toggle_mode = true
	_demolish_button.button_group = _item_group
	_demolish_button.pressed.connect(func() -> void: demolish_chosen.emit())
	foot.add_child(_demolish_button)
	_rules_button = Button.new()
	_rules_button.text = "Règles"
	_rules_button.icon = Icones.get_icon("admin", 20)
	_rules_button.tooltip_text = "Règles de la partie : argent, coûts, accès à une voie, déblocage… (panneau Admin, F10)"
	_rules_button.pressed.connect(func() -> void: admin_requested.emit())
	foot.add_child(_rules_button)

	_summary_label = Label.new()
	_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary_label.add_theme_font_size_override("font_size", 12)
	_summary_label.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	box.add_child(_summary_label)

	show_category(_category)
	set_workshop(false)


## Passe le panneau en atelier (mode Créer) ou en catalogue (mode Gérer).
func set_workshop(on: bool, cat := "") -> void:
	workshop = on
	for id in _cat_buttons:
		(_cat_buttons[id] as Button).visible = WORKSHOP_TABS.has(id) == on
	# En atelier, la barre du bas choisit l'onglet ; en Gérer, les thèmes nommés
	# remplacent l'ancienne grille d'icônes.
	_cats_grid.visible = false
	_themes_scroll.visible = not on
	_global_search.visible = not on
	_local_search.visible = on
	_foot.visible = not on
	# Plus large en Gérer : la colonne des thèmes à gauche des vignettes.
	_panel.offset_left = UiStyle.SIDE_LEFT if on else UiStyle.SIDE_LEFT - 204.0
	_head_title.text = "Atelier" if on else "Construire"
	_head_icon.texture = Icones.get_icon("editeur" if on else "construire", 24, UiStyle.CREATE if on else UiStyle.ACCENT)
	_cat_title.add_theme_color_override("font_color", UiStyle.CREATE if on else UiStyle.ACCENT)
	if on:
		if cat != "":
			show_category(cat)
		elif not WORKSHOP_TABS.has(_category):
			show_category("blocs")
	elif WORKSHOP_TABS.has(_category):
		show_category("logement")


## Murs et étages (« plans ») ou blocs de 1 m, depuis la barre du bas en mode Créer.
func set_block_mode(m: String) -> void:
	if _block_mode != m:
		_block_mode = m
		block_tool_chosen.emit(BlockEditor.Tool.NONE)
	show_category("blocs")


## Échelle des étages : murs par étage du bâtiment visé et étage actif.
func set_ladder(counts: Dictionary, current: int) -> void:
	_ladder_counts = counts
	_ladder_level = current
	_fill_ladder()


## Le bouton « Règles » n'est là que pour qui peut administrer la partie.
func set_admin(on: bool) -> void:
	_rules_button.visible = on


## Réglages changés (coûts, déblocage) : on redessine la liste.
func refresh() -> void:
	if _category != "zones" and _category != "blocs":
		show_category(_category)


## Thème (THEMES) qui contient une catégorie du catalogue.
static func theme_of(cat: String) -> String:
	for t in THEMES:
		if (t.cats as Array).has(cat):
			return String(t.id)
	return ""


## Nombre de bâtiments d'une catégorie (colonne des thèmes).
func _count(cat: String) -> int:
	match cat:
		"favoris", "recents":
			return FavorisConstruire.liste(cat).size()
		ModelesJeu.CATEGORY:
			return ModelesJeu.ids().size() + Creations.ids().size()
		"zones":
			return -1
	return BuildingCatalog.ids_in(cat, _region, _era).size()


## Colonne des thèmes : nom écrit, nombre de bâtiments ; le thème ouvert
## montre ses sous-thèmes.
func _fill_themes() -> void:
	if _themes_box == null:
		return
	for ch in _themes_box.get_children():
		_themes_box.remove_child(ch)
		ch.queue_free()
	for t in THEMES:
		var cats: Array = t.cats
		if EditionDemo.categorie_verrouillee(String(cats[0])) or not _cat_buttons.has(String(cats[0])):
			continue
		if t.has("head"):
			var h := Label.new()
			h.text = String(t.head).to_upper()
			h.add_theme_font_size_override("font_size", 11)
			h.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
			_themes_box.add_child(h)
		var n := 0
		for c in cats:
			n += maxi(0, _count(String(c)))
		var open := String(t.id) == _theme_open and _search == ""
		_themes_box.add_child(_theme_button(String(t.icon), String(t.name), "" if String(t.id) == "zones" else str(n), open and cats.size() == 1, open, String(cats[0]), 0))
		if open and cats.size() > 1:
			for c in cats:
				if EditionDemo.categorie_verrouillee(String(c)) or not _cat_buttons.has(String(c)):
					continue
				_themes_box.add_child(_theme_button("", String(SUB_NAMES.get(c, c)), str(_count(String(c))), String(c) == _category, false, String(c), 1))


func _theme_button(icon: String, label: String, count: String, on: bool, open: bool, cat: String, depth: int) -> Button:
	var b := Button.new()
	b.name = "Theme_" + cat
	b.text = label
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.clip_text = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 30 if depth == 0 else 24)
	b.add_theme_font_size_override("font_size", 14 if depth == 0 else 12)
	if icon != "":
		b.icon = Icones.get_icon(icon, 18, UiStyle.ACCENT if open else Color.WHITE)
	if depth > 0:
		b.add_theme_constant_override("h_separation", 0)
	var normal := UiStyle.flat_box(Color(UiStyle.ACCENT, 0.16) if on or (open and depth == 0) else Color(0, 0, 0, 0), 7, 4)
	normal.content_margin_left = 6 + depth * 22
	var hover := UiStyle.flat_box(Color(1, 1, 1, 0.08), 7, 4)
	hover.content_margin_left = normal.content_margin_left
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", normal)
	var col := UiStyle.ACCENT if on or open else (UiStyle.TEXT_DIM if depth > 0 else Color.WHITE)
	for k in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(k, col)
	if count != "":
		b.tooltip_text = "%s · %s bâtiment%s" % [label, count, "s" if count != "1" else ""]
	b.pressed.connect(func() -> void:
		if _search != "":
			_global_search.text = ""
			_search = ""
		show_category(cat))
	return b


func show_category(cat: String) -> void:
	if not _cat_buttons.has(cat):
		cat = "logement"
	_category = cat
	(_cat_buttons[cat] as Button).button_pressed = true
	_cat_title.text = (_cat_buttons[cat] as Button).tooltip_text
	if _vignettes:
		_vignettes.cancel_all()
	for b in _item_buttons:
		b.queue_free()
	_item_buttons.clear()
	if not workshop:
		if theme_of(cat) != "":
			_theme_open = theme_of(cat)
		_fill_themes()
		if _search != "" and cat != "zones":
			_show_search_results()
			return
		if cat == "favoris" or cat == "recents":
			_show_list(FavorisConstruire.liste(cat), "Clique l'étoile d'une vignette pour la garder ici." if cat == "favoris" else "Les bâtiments que tu choisis s'ajoutent ici.")
			return
	if cat == "zones":
		_show_zones()
		return
	if cat == "blocs":
		_show_blocks()
		return
	if cat == Creations.CATEGORY:
		_show_creations()
		return
	if cat == ModelesJeu.CATEGORY:
		_show_models()
		return
	if cat == "interieur":
		_filters.visible = false
		if interieur_builder.is_valid():
			interieur_builder.call(self)
		return
	if cat == "banque":
		_filters.visible = false
		if banque_builder.is_valid():
			banque_builder.call(self)
		return
	_filters.visible = true
	var shown := 0
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	_list.add_child(grid)
	_item_buttons.append(grid)
	var ids := BuildingCatalog.ids_in(cat, _region, _era)
	# Partie historique : d'abord ce qui existe déjà, puis ce qui arrive, par année.
	if Epoques.actif():
		var y := Epoques.annee()
		var cle := func(id: String) -> int:
			var a := Epoques.annee_batiment(id)
			return -1 if a <= y else a
		var rangs := {}
		for i in ids.size():
			rangs[ids[i]] = i
		ids.sort_custom(func(p: String, q: String) -> bool:
			var kp: int = cle.call(p)
			var kq: int = cle.call(q)
			return kp < kq if kp != kq else int(rangs[p]) < int(rangs[q]))
	for id in ids:
		var t := BuildingCatalog.get_type(id)
		if _search != "" and not (String(t.name) + " " + String(t.desc)).to_lower().contains(_search):
			continue
		shown += 1
		grid.add_child(_card(id, String(CAT_ICONS.get(cat, "construire"))))
	_cat_title.text += "  ·  %d" % shown
	if shown == 0:
		var none := Label.new()
		none.text = "Aucun bâtiment pour ces filtres."
		_list.add_child(none)
		_item_buttons.append(none)


## Recherche (mode Gérer) : dans tout le catalogue, toutes catégories et Mes modèles.
func _show_search_results() -> void:
	_filters.visible = true
	var q: String = FavorisConstruire.plier(_search)
	var ids: Array[String] = []
	var seen := {}
	var cats: Array = []
	for t in THEMES:
		for c in t.cats:
			if not ["favoris", "recents", "zones"].has(String(c)) and not EditionDemo.categorie_verrouillee(String(c)):
				cats.append(String(c))
	for c in cats:
		var pool: Array = (ModelesJeu.ids() + Creations.ids()) if c == ModelesJeu.CATEGORY else BuildingCatalog.ids_in(String(c), _region, _era)
		for id in pool:
			var t := BuildingCatalog.get_type(String(id))
			if t.is_empty() or seen.has(id) or t.get("cache", false):
				continue
			if FavorisConstruire.plier(String(t.name) + " " + String(t.get("desc", ""))).contains(q):
				seen[id] = true
				ids.append(String(id))
	# Les noms qui commencent par le mot cherché d'abord.
	ids.sort_custom(func(a: String, b: String) -> bool:
		var pa: bool = FavorisConstruire.plier(String(BuildingCatalog.get_type(a).name)).begins_with(q)
		var pb: bool = FavorisConstruire.plier(String(BuildingCatalog.get_type(b).name)).begins_with(q)
		return pa and not pb)
	_cat_title.text = "« %s » dans tout le catalogue" % _search
	_show_list(ids, "Aucun bâtiment ne correspond. Essaie un autre mot (école, piscine, gare…).")


## Vignettes d'une liste d'ids, avec un message si elle est vide.
func _show_list(ids: Array, empty_text: String) -> void:
	_filters.visible = _search != ""
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	_list.add_child(grid)
	_item_buttons.append(grid)
	var shown := 0
	for id in ids:
		if shown >= 80:
			break
		var t := BuildingCatalog.get_type(String(id))
		grid.add_child(_card(String(id), String(CAT_ICONS.get(String(t.get("cat", "")), "construire"))))
		shown += 1
	_cat_title.text += "  ·  %d" % ids.size()
	if shown == 0:
		var none := Label.new()
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.text = empty_text
		none.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
		_list.add_child(none)
		_item_buttons.append(none)


## Mes modèles (mode Gérer) : les modèles de la banque et les créations en blocs,
## posés comme les autres bâtiments.
func _show_models() -> void:
	_filters.visible = true
	var neu := Button.new()
	neu.name = "CreerBatiment"
	neu.text = "Créer un nouveau bâtiment dans l'Atelier"
	neu.icon = Icones.get_icon("plus", 20, UiStyle.CREATE)
	neu.tooltip_text = "Ouvre l'Atelier (terrain vide). Une fois ton bâtiment enregistré, tu reviens ici avec lui en main."
	neu.add_theme_color_override("font_color", UiStyle.CREATE)
	var nsb := UiStyle.flat_box(Color(UiStyle.CREATE, 0.08), 10, 10)
	nsb.border_color = Color(UiStyle.CREATE, 0.7)
	nsb.set_border_width_all(2)
	neu.add_theme_stylebox_override("normal", nsb)
	neu.add_theme_stylebox_override("hover", UiStyle.flat_box(Color(UiStyle.CREATE, 0.18), 10, 10))
	neu.custom_minimum_size = Vector2(0, 48)
	neu.pressed.connect(func() -> void: atelier_requested.emit())
	_add(neu)
	var ids: Array = ModelesJeu.ids()
	ids.append_array(Creations.ids())
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	_list.add_child(grid)
	_item_buttons.append(grid)
	var shown := 0
	for id in ids:
		var t := BuildingCatalog.get_type(String(id))
		if t.is_empty() or (_search != "" and not (String(t.name) + " " + String(t.desc)).to_lower().contains(_search)):
			continue
		shown += 1
		grid.add_child(_card(String(id), "atelier"))
	_cat_title.text += "  ·  %d" % shown
	if shown == 0:
		var none := Label.new()
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.text = ("Aucun modèle pour l'instant. Dans l'Atelier, construis un bâtiment puis clique « Enregistrer mon bâtiment » "
			+ "en haut de l'écran : il apparaît ici.") if _search == "" else "Aucun modèle pour cette recherche."
		_list.add_child(none)
		_item_buttons.append(none)


func _show_zones() -> void:
	_filters.visible = false
	# Style que suivra le zonage (les bâtiments qui poussent).
	var srow := HBoxContainer.new()
	var sl := Label.new()
	sl.text = "Style :"
	srow.add_child(sl)
	var style_opt := OptionButton.new()
	style_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	style_opt.fit_to_longest_item = false
	style_opt.clip_text = true
	style_opt.custom_minimum_size = Vector2(220, 0)
	style_opt.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	style_opt.add_item("Classique MiniBlocs")
	style_opt.set_item_metadata(0, "")
	style_opt.add_item("Mélange de tous les styles")
	style_opt.set_item_metadata(1, "mix")
	style_opt.add_item("Bâtiments Blender (bible)")
	style_opt.set_item_metadata(2, ZoneSystem.STYLE_BIBLE)
	for sid in Styles.STYLES:
		var st: Dictionary = Styles.STYLES[sid]
		style_opt.add_item("%s (%s, %s)" % [st.name, Styles.region_name(st.region), Styles.era_name(st.era).to_lower()])
		style_opt.set_item_metadata(style_opt.item_count - 1, sid)
	for i in style_opt.item_count:
		if String(style_opt.get_item_metadata(i)) == _zone_style:
			style_opt.select(i)
	style_opt.item_selected.connect(func(i: int) -> void:
		_zone_style = String(style_opt.get_item_metadata(i))
		zone_style_chosen.emit(_zone_style))
	srow.add_child(style_opt)
	_list.add_child(srow)
	_item_buttons.append(srow)
	for k in ZoneSystem.KINDS:
		var b := Button.new()
		b.text = "Zone %s  ·  %d €/m²" % [String(ZoneSystem.KINDS[k].name).to_lower(), ZoneSystem.PRICE_M2]
		b.tooltip_text = "Clic gauche glissé pour peindre. Des bâtiments poussent le long des routes selon la demande."
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.toggle_mode = true
		b.button_group = _item_group
		b.add_theme_color_override("font_pressed_color", (ZoneSystem.KINDS[k].color as Color).lightened(0.4))
		var kk: String = k
		b.pressed.connect(func() -> void: zone_chosen.emit(kk))
		_list.add_child(b)
		_item_buttons.append(b)
	var rm := Button.new()
	rm.text = "Retirer des zones"
	rm.alignment = HORIZONTAL_ALIGNMENT_LEFT
	rm.toggle_mode = true
	rm.button_group = _item_group
	rm.pressed.connect(func() -> void: zone_remove_chosen.emit())
	_list.add_child(rm)
	_item_buttons.append(rm)
	var grow := CheckBox.new()
	grow.text = "Croissance automatique"
	grow.button_pressed = _growth
	grow.toggled.connect(func(on: bool) -> void:
		_growth = on
		growth_toggled.emit(on))
	_list.add_child(grow)
	_item_buttons.append(grow)
	_zone_label = Label.new()
	_zone_label.add_theme_font_size_override("font_size", 12)
	_zone_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_list.add_child(_zone_label)
	_item_buttons.append(_zone_label)


func block_mode() -> String:
	return _block_mode


func set_level_label(text: String) -> void:
	_level_text = text
	if is_instance_valid(_level_label):
		_level_label.text = text


## Ajoute un contrôle à la liste de l'onglet (il disparaît au changement d'onglet).
func add_control(c: Control) -> void:
	_add(c)


func item_group() -> ButtonGroup:
	return _item_group


func category() -> String:
	return _category


func _add(c: Control) -> void:
	_list.add_child(c)
	_item_buttons.append(c)


func _small_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 12)
	return l


func _show_blocks() -> void:
	_filters.visible = false
	# Deux façons de construire : blocs de 1 m, ou murs fins et étages.
	var mrow := HBoxContainer.new()
	var mode_group := ButtonGroup.new()
	for md in [["plans", "Murs et étages", "Murs de 20 cm posés sur les lignes de la grille, pièces, étages, sous-sols, portes et fenêtres, escaliers, toit automatique."],
			["blocs", "Blocs", "Blocs de 1 m façon jeu de cubes : formes, pentes, portes et fenêtres en blocs, pour le massif et les détails."]]:
		var mb := Button.new()
		mb.text = md[1]
		mb.tooltip_text = md[2]
		mb.toggle_mode = true
		mb.button_group = mode_group
		mb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mb.button_pressed = md[0] == _block_mode
		var mid: String = md[0]
		mb.pressed.connect(func() -> void:
			if _block_mode != mid:
				_block_mode = mid
				# Changer de mode range l'outil en cours.
				block_tool_chosen.emit(BlockEditor.Tool.NONE)
				show_category("blocs"))
		mrow.add_child(mb)
	_add(mrow)
	# Mode Créer : la barre du bas choisit déjà entre murs et blocs.
	mrow.visible = not workshop
	if workshop:
		_cat_title.text = "Murs et étages" if _block_mode == "plans" else "Blocs de 1 m"
	if _block_mode == "plans":
		_show_plan_tools()
	else:
		_show_block_tools()
	_show_catalog()
	if _block_mode == "blocs":
		_show_capture()
	_block_label = Label.new()
	_block_label.add_theme_font_size_override("font_size", 12)
	_block_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_block_label.text = "Clic droit : retirer · Ctrl+Z : annuler"
	_add(_block_label)


func _show_plan_tools() -> void:
	var tools := [["Mur", "mur", PlanEditor.Tool.WALL, "Clic glissé d'un coin de case à l'autre : mur de 20 cm sur la ligne."],
		["Pièce", "piece", PlanEditor.Tool.ROOM, "Clic glissé en rectangle : quatre murs et le plancher."],
		["Sol", "sol", PlanEditor.Tool.FLOOR, "Clic glissé en rectangle : plancher, terrasse, balcon."],
		["Escalier", "escalier", PlanEditor.Tool.STAIRS, "Clic : escalier de 4 cases vers l'étage du dessus (R : tourner)."],
		["Peinture", "peinture", PlanEditor.Tool.PAINT, "Clic sur un côté de mur ou un sol ; glissé : toute la pièce, dans le matériau et la teinte choisis."],
		["Gomme", "gomme", PlanEditor.Tool.ERASE, "Clic sur un mur, un sol ou un escalier ; glissé : tout un rectangle de l'étage."]]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	for t in tools:
		var b := UiStyle.tile_button(t[1], t[0], "", Vector2(56, 58), 24)
		b.add_theme_font_size_override("font_size", 11)
		UiStyle.tint_pressed(b, UiStyle.CREATE, UiStyle.CREATE_INK)
		b.tooltip_text = t[3]
		b.toggle_mode = true
		b.button_group = _item_group
		var tool_id: int = t[2]
		b.pressed.connect(func() -> void: plan_tool_chosen.emit(tool_id))
		row.add_child(b)
	_add(row)
	# Échelle des étages : on voit tous les niveaux, un clic pour y aller.
	var lhead := HBoxContainer.new()
	var lt := _small_label("ÉTAGES")
	lt.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	lt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lhead.add_child(lt)
	_level_label = _small_label(_level_text)
	_level_label.add_theme_color_override("font_color", UiStyle.CREATE)
	lhead.add_child(_level_label)
	var down := UiStyle.icon_button("bas", "Étage du dessous : jusqu'à 5 sous-sols", "Page bas", 16, 26)
	down.pressed.connect(func() -> void: plan_level_step.emit(-1))
	lhead.add_child(down)
	var up := UiStyle.icon_button("haut", "Étage du dessus : jusqu'à 59 étages", "Page haut", 16, 26)
	up.pressed.connect(func() -> void: plan_level_step.emit(1))
	lhead.add_child(up)
	_add(lhead)
	var lscroll := ScrollContainer.new()
	lscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lscroll.custom_minimum_size = Vector2(0, 150)
	_ladder_box = VBoxContainer.new()
	_ladder_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ladder_box.add_theme_constant_override("separation", 3)
	lscroll.add_child(_ladder_box)
	_add(lscroll)
	_fill_ladder()
	# Hauteur des murs et des pièces : plusieurs étages d'un coup.
	var hrow := HBoxContainer.new()
	var hl := Label.new()
	hl.text = "Murs et pièces sur"
	hrow.add_child(hl)
	var hspin := SpinBox.new()
	hspin.min_value = 1
	hspin.max_value = 60
	hspin.value = _wall_levels
	hspin.suffix = "étage(s)"
	hspin.custom_minimum_size = Vector2(120, 0)
	hspin.tooltip_text = "Les outils Mur et Pièce montent les murs (et les planchers des pièces) sur ce nombre d'étages d'un coup, à partir de l'étage actif."
	hspin.value_changed.connect(func(v: float) -> void:
		_wall_levels = int(v)
		plan_wall_levels.emit(int(v)))
	hrow.add_child(hspin)
	_add(hrow)
	var crow := HBoxContainer.new()
	var cut := CheckBox.new()
	cut.text = "Vue en coupe"
	cut.tooltip_text = "Masquer les étages au-dessus de l'étage actif pendant l'édition."
	cut.button_pressed = _cutaway
	cut.toggled.connect(func(on: bool) -> void:
		_cutaway = on
		plan_cutaway_toggled.emit(on))
	crow.add_child(cut)
	var copy := Button.new()
	copy.text = "Copier l'étage ↑"
	copy.tooltip_text = "Recopie l'étage actif (murs, ouvertures, sols, escaliers) au-dessus, autant de fois que demandé."
	copy.pressed.connect(func() -> void: plan_copy_level.emit(_copy_count))
	crow.add_child(copy)
	var spin := SpinBox.new()
	spin.min_value = 1
	spin.max_value = 50
	spin.value = _copy_count
	spin.tooltip_text = "Nombre d'étages à créer"
	spin.value_changed.connect(func(v: float) -> void: _copy_count = int(v))
	crow.add_child(spin)
	_add(crow)


## Remplit l'échelle : « Ajouter un étage » en haut, puis chaque niveau du toit
## au sous-sol, l'étage actif en bleu.
func _fill_ladder() -> void:
	if not is_instance_valid(_ladder_box):
		return
	for c in _ladder_box.get_children():
		c.queue_free()
	var top := maxi(_ladder_level, 0)
	var bottom := mini(_ladder_level, 0)
	for e in _ladder_counts:
		top = maxi(top, int(e))
		bottom = mini(bottom, int(e))
	var add := Button.new()
	add.text = "Ajouter un étage"
	add.icon = Icones.get_icon("plus", 16, UiStyle.CREATE)
	add.tooltip_text = "Monter à l'étage au-dessus du dernier pour y tracer les murs"
	add.focus_mode = Control.FOCUS_NONE
	var dashed := UiStyle.flat_box(Color(0, 0, 0, 0), 8, 5)
	dashed.border_color = Color(UiStyle.CREATE, 0.5)
	dashed.set_border_width_all(1)
	add.add_theme_stylebox_override("normal", dashed)
	add.add_theme_color_override("font_color", UiStyle.CREATE)
	var target := mini(top + 1, PlanEditor.MAX_LEVEL)
	if _ladder_counts.is_empty():
		target = mini(_ladder_level + 1, PlanEditor.MAX_LEVEL)
	add.pressed.connect(func() -> void: plan_level_set.emit(target))
	_ladder_box.add_child(add)
	for e in range(top, bottom - 1, -1):
		var b := Button.new()
		var n: int = int(_ladder_counts.get(e, -1))
		var what := "vide" if n < 0 else ("plancher" if n == 0 else "%d mur%s" % [n, "s" if n > 1 else ""])
		b.text = "%s  ·  %s" % [PlanEditor.level_name(e), what]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 13)
		b.add_theme_stylebox_override("normal", UiStyle.flat_box(Color(1, 1, 1, 0.05), 8, 5))
		b.add_theme_stylebox_override("hover", UiStyle.flat_box(Color(1, 1, 1, 0.12), 8, 5))
		b.add_theme_stylebox_override("pressed", UiStyle.flat_box(UiStyle.CREATE, 8, 5))
		b.add_theme_stylebox_override("hover_pressed", UiStyle.flat_box(UiStyle.CREATE.lightened(0.15), 8, 5))
		b.add_theme_color_override("font_pressed_color", UiStyle.CREATE_INK)
		b.add_theme_color_override("font_hover_pressed_color", UiStyle.CREATE_INK)
		b.set_pressed_no_signal(e == _ladder_level)
		var lv := e
		b.pressed.connect(func() -> void: plan_level_set.emit(lv))
		_ladder_box.add_child(b)


func _show_block_tools() -> void:
	var tools := [["Poser", BlockEditor.Tool.BLOCK, "Un clic = un élément de la forme choisie, contre le sol ou contre un autre bloc. R : tourner, F : renverser, C : coucher."],
		["Rectangle", BlockEditor.Tool.RECT, "Clic glissé : dalle, plancher ou toit plat."],
		["Mur", BlockEditor.Tool.WALL, "Clic glissé en ligne : mur de la hauteur choisie."],
		["Gomme", BlockEditor.Tool.ERASE, "Clic sur un bloc, ou glissé pour effacer un étage."]]
	var row := HFlowContainer.new()
	_list.add_child(row)
	_item_buttons.append(row)
	for t in tools:
		var b := Button.new()
		b.text = t[0]
		b.tooltip_text = t[2]
		b.toggle_mode = true
		b.button_group = _item_group
		var tool_id: int = t[1]
		b.pressed.connect(func() -> void: block_tool_chosen.emit(tool_id))
		row.add_child(b)
	var hrow := HBoxContainer.new()
	var hl := Label.new()
	hl.text = "Hauteur des murs (blocs) :"
	hrow.add_child(hl)
	var spin := SpinBox.new()
	spin.min_value = 1
	spin.max_value = 30
	spin.value = _wall_height
	spin.value_changed.connect(func(v: float) -> void:
		_wall_height = int(v)
		wall_height_changed.emit(int(v)))
	hrow.add_child(spin)
	_list.add_child(hrow)
	_item_buttons.append(hrow)
	# Orientation de la forme posée (mêmes effets que R, F et C au clavier).
	var orow := HFlowContainer.new()
	var ol := Label.new()
	ol.text = "Orientation :"
	orow.add_child(ol)
	for o in [["↻ Tourner (R)", "tourner", "Quart de tour à plat. Sans rien toucher, la forme se tourne face à la caméra."],
			["⇅ Renverser (F)", "renverser", "Tête en bas : une pente devient un dessous de toit, un arrondi part vers le bas."],
			["⤵ Coucher (C)", "coucher", "Couchée sur le côté, contre un mur : combine avec R pour choisir le côté, F pour l'autre sens."],
			["Redresser", "redresser", "Remet la forme debout, face à la caméra."]]:
		var ob := Button.new()
		ob.text = o[0]
		ob.tooltip_text = o[2]
		ob.focus_mode = Control.FOCUS_NONE
		var act: String = o[1]
		ob.pressed.connect(func() -> void: block_orient.emit(act))
		orow.add_child(ob)
	_list.add_child(orow)
	_item_buttons.append(orow)


## Réglages des grandes pièces : diamètre (ou largeur) et hauteur (ou longueur).
func _piece_row() -> Control:
	var row := HFlowContainer.new()
	var l1 := Label.new()
	l1.text = "Diamètre / largeur"
	l1.add_theme_font_size_override("font_size", 12)
	row.add_child(l1)
	var d := SpinBox.new()
	d.min_value = BlocFormes.PIECE_MIN
	d.max_value = BlocFormes.PIECE_MAX
	d.value = _piece_d
	d.suffix = "m"
	d.tooltip_text = "Taille de la coupole, de la tour, de la voûte… (2 à 32 m)."
	row.add_child(d)
	var l2 := Label.new()
	l2.text = "Hauteur / longueur"
	l2.add_theme_font_size_override("font_size", 12)
	row.add_child(l2)
	var n := SpinBox.new()
	n.min_value = 1
	n.max_value = 60
	n.value = _piece_n
	n.suffix = "m"
	n.tooltip_text = "Hauteur d'une tour ronde ou d'un cylindre, longueur d'une voûte ou d'une arche."
	row.add_child(n)
	d.value_changed.connect(func(v: float) -> void:
		_piece_d = int(v)
		block_piece_changed.emit(_piece_d, _piece_n))
	n.value_changed.connect(func(v: float) -> void:
		_piece_n = int(v)
		block_piece_changed.emit(_piece_d, _piece_n))
	return row


## Onglets de l'atelier : Portes, Fenêtres, Baies, Passages, Toits (murs fins) ou
## familles de formes (blocs), puis Matériaux. Un seul onglet ouvert à la fois,
## en vignettes avec leur nom.
func _catalog_tabs() -> Array:
	var tabs := []
	if _block_mode == "plans":
		for ot in VignettesAtelier.OPENING_TABS:
			tabs.append([ot[0], ot[1]])
		tabs.append(["toits", "Toits"])
		for fam in Amenagements.FAMILLES:
			tabs.append(["am_" + String(fam[0]), fam[1]])
	else:
		for fam in BlocFormes.FAMILLES:
			if fam[0] == "ouvertures":
				tabs.append(["b_portes", "Portes"])
				tabs.append(["b_fenetres", "Fenêtres"])
			elif fam[0] == "grandes":
				tabs.append(["grandes", "Grandes pièces"])
			elif fam[0] == "details":
				tabs.append(["details", "Détails"])
			else:
				tabs.append([fam[0], fam[1]])
	tabs.append(["materiaux", "Matériaux"])
	return tabs


func _show_catalog() -> void:
	var tabs := _catalog_tabs()
	var ids := []
	for tb in tabs:
		ids.append(tb[0])
	var cur := _plan_tab if _block_mode == "plans" else _block_tab
	if not cur in ids:
		cur = ids[0]
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 4)
	chips.add_theme_constant_override("v_separation", 4)
	_add(chips)
	# Matériau en cours, rappelé au-dessus des vignettes (un clic : onglet Matériaux).
	var strip := Button.new()
	strip.alignment = HORIZONTAL_ALIGNMENT_LEFT
	strip.focus_mode = Control.FOCUS_NONE
	strip.add_theme_constant_override("icon_max_width", 22)
	strip.add_theme_font_size_override("font_size", 12)
	strip.add_theme_stylebox_override("normal", UiStyle.flat_box(Color(1, 1, 1, 0.04), 8, 4))
	strip.add_theme_stylebox_override("hover", UiStyle.flat_box(Color(1, 1, 1, 0.12), 8, 4))
	strip.tooltip_text = "Changer de matériau"
	_add(strip)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	_add(content)
	var chip_group := ButtonGroup.new()
	var open_tab := func(id: String) -> void:
		if _block_mode == "plans":
			_plan_tab = id
		else:
			_block_tab = id
		for c in content.get_children():
			c.queue_free()
		var m := clampi(_block_material, 0, BlockEditor.MATERIALS.size() - 1)
		strip.icon = _material_icon(m)
		strip.text = "Matériau : %s  ›" % BlockEditor.MATERIALS[m].name
		strip.visible = id != "materiaux"
		if id == "materiaux":
			_show_materials(content)
		else:
			_fill_catalog_tab(id, content)
		for ch in chips.get_children():
			(ch as Button).set_pressed_no_signal(String(ch.get_meta("tab")) == id)
	for tb in tabs:
		var chip := _chip(String(tb[1]))
		chip.button_group = chip_group
		chip.set_meta("tab", tb[0])
		var tid: String = tb[0]
		chip.pressed.connect(func() -> void: open_tab.call(tid))
		chips.add_child(chip)
	strip.pressed.connect(func() -> void: open_tab.call("materiaux"))
	open_tab.call(cur)


func _hint(text: String) -> Label:
	var l := _small_label(text)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	return l


## Petit onglet arrondi (ambre quand il est choisi).
func _chip(text: String) -> Button:
	var chip := Button.new()
	chip.text = text
	chip.toggle_mode = true
	chip.add_theme_font_size_override("font_size", 12)
	UiStyle.style_icon_button(chip)
	chip.add_theme_stylebox_override("normal", UiStyle.flat_box(Color(1, 1, 1, 0.07), 12, 4))
	chip.add_theme_stylebox_override("hover", UiStyle.flat_box(Color(1, 1, 1, 0.16), 12, 4))
	chip.add_theme_stylebox_override("pressed", UiStyle.flat_box(UiStyle.ACCENT, 12, 4))
	chip.add_theme_stylebox_override("hover_pressed", UiStyle.flat_box(UiStyle.ACCENT.lightened(0.15), 12, 4))
	return chip


func _fill_catalog_tab(id: String, box: VBoxContainer) -> void:
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	if _block_mode == "plans":
		if id == "toits":
			box.add_child(_hint("Un clic pose le toit sur le dernier étage du bâtiment visé (matériau de toit choisi, sinon celui du modèle)."))
			box.add_child(grid)
			for r in PlanEditor.ROOFS:
				var rid: String = r[0]
				# Toit-terrasse, sheds : pas avant leur invention.
				if EpoquesObjets.annee_toit(rid) > EpoquesObjets.annee_partie():
					continue
				var rb := _thumb_card(String(r[1]), "Toit %s sur le dernier étage" % String(r[1]).to_lower(),
					"toit_" + rid, func() -> Mesh: return VignettesAtelier.roof_mesh(rid))
				rb.pressed.connect(func() -> void: plan_roof.emit(rid))
				grid.add_child(rb)
			var seat := Button.new()
			seat.text = "Au ras du sol"
			seat.tooltip_text = "Remet le bâtiment visé de plain-pied : rez-de-chaussée à la hauteur du sol ou de la route voisine (toit compris)."
			seat.add_theme_font_size_override("font_size", 12)
			seat.pressed.connect(func() -> void: plan_reseat.emit())
			box.add_child(seat)
			return
		if id.begins_with("am_"):
			_fill_amenagements(id.trim_prefix("am_"), box, grid)
			return
		box.add_child(_hint("Clic près d'un mur pour poser ; clic droit : retirer."))
		box.add_child(grid)
		for ot in VignettesAtelier.OPENING_TABS:
			if ot[0] != id:
				continue
			for k in ot[2]:
				# Baies vitrées, murs-rideaux, portes de garage : pas avant leur invention.
				if EpoquesObjets.annee_ouverture(String(k)) > EpoquesObjets.annee_partie():
					continue
				var o: Dictionary = PlanEditor.OPENINGS[k]
				var kid: String = k
				var ob := _thumb_card(String(o.name), "%s\n%s · %s" % [o.name, o.desc, BuildingSystem.format_money(int(o.price))],
					"ouv_" + kid, func() -> Mesh: return VignettesAtelier.opening_mesh(kid))
				ob.toggle_mode = true
				ob.button_group = _item_group
				ob.pressed.connect(func() -> void:
					_opening = kid
					plan_opening_chosen.emit(kid))
				grid.add_child(ob)
		return
	# Blocs : formes de la famille choisie.
	box.add_child(grid)
	var fam := id
	if id == "b_portes" or id == "b_fenetres":
		fam = "ouvertures"
	var shape_group := ButtonGroup.new()
	for sh in BlocFormes.ORDER:
		var info: Dictionary = BlocFormes.INFO[sh]
		if info.fam != fam:
			continue
		var is_door := String(info.name).begins_with("Porte")
		if (id == "b_portes" and not is_door) or (id == "b_fenetres" and is_door):
			continue
		var shid: int = sh
		var sb := _thumb_card(String(info.name), "%s\n%s" % [info.name, info.desc],
			"forme_%d" % shid, func() -> Mesh: return VignettesAtelier.shape_mesh(shid))
		sb.toggle_mode = true
		sb.button_group = shape_group
		sb.button_pressed = sh == _block_shape
		sb.pressed.connect(func() -> void:
			_block_shape = shid
			block_shape_chosen.emit(shid))
		grid.add_child(sb)
	if id == "grandes":
		box.add_child(_piece_row())


## Bassins, rails, gradins, terrains : vignettes 3D ; un clic choisit l'outil.
func _fill_amenagements(fam: String, box: VBoxContainer, grid: GridContainer) -> void:
	var hints := {
		"bassins": "Clic : taille du modèle · clic glissé : votre taille. Le terrain est creusé sous le bassin ; sur un étage, il pend dans l'étage du dessous.",
		"rails": "Les rails suivent le grand côté du rectangle ; plus large, plusieurs voies côte à côte. Décor de l'atelier : les trains roulent sur le réseau (touche L).",
		"gradins": "Les rangs montent vers l'arrière, dos à la caméra (R : tourner). Chaque place compte comme visiteur du bâtiment.",
		"terrains": "Lignes réglementaires si le rectangle est assez grand, sinon le terrain est réduit. Clic : taille officielle avec ses abords.",
	}
	box.add_child(_hint(String(hints.get(fam, ""))))
	var own := CheckBox.new()
	own.text = "Avec le matériau choisi"
	own.tooltip_text = "Carrelage du bassin, surface du terrain, marches des gradins… dans le matériau et la teinte choisis (onglet Matériaux)."
	own.add_theme_font_size_override("font_size", 12)
	own.button_pressed = _amenag_own_mat
	own.toggled.connect(func(on: bool) -> void:
		_amenag_own_mat = on
		plan_amenagement_material.emit(on))
	box.add_child(own)
	box.add_child(grid)
	for kind in Amenagements.of_family(fam):
		if EpoquesObjets.annee_amenagement(String(kind)) > EpoquesObjets.annee_partie():
			continue
		var k: Dictionary = Amenagements.KINDS[kind]
		var kid: String = kind
		var sz: Vector2i = k.size
		var tip := "%s\n%s\n%d × %d m · %s le m²" % [k.name, k.desc, sz.x, sz.y, BuildingSystem.format_money(int(k.price))]
		var fn := String(k.get("fn", ""))
		if fn != "" and not BuildingCatalog.get_type(fn).is_empty():
			tip += "\nFonction proposée au modèle : %s" % String(BuildingCatalog.get_type(fn).name)
		var b := _thumb_card(String(k.name), tip, "am_" + kid, func() -> Mesh: return VignettesAtelier.amenagement_mesh(kid))
		b.toggle_mode = true
		b.button_group = _item_group
		b.button_pressed = kid == _amenag
		b.pressed.connect(func() -> void:
			_amenag = kid
			plan_amenagement_chosen.emit(kid))
		grid.add_child(b)


## Vignette de l'atelier : maquette 3D rendue à part, nom dessous.
func _thumb_card(title: String, tip: String, vid: String, builder: Callable) -> Button:
	var b := Button.new()
	_card_look(b)
	b.text = title
	b.tooltip_text = tip
	if _vignettes:
		_vignettes.request_mesh(vid, builder, b)
	return b


## Allure commune des vignettes (matériaux, portes, fenêtres, formes, toits).
func _card_look(b: Button) -> void:
	b.custom_minimum_size = Vector2(80, 98)
	b.focus_mode = Control.FOCUS_NONE
	var states := {"normal": [Color(1, 1, 1, 0.05), Color(1, 1, 1, 0.0)], "hover": [Color(1, 1, 1, 0.14), Color(1, 1, 1, 0.35)],
		"pressed": [Color(UiStyle.ACCENT, 0.22), UiStyle.ACCENT], "hover_pressed": [Color(UiStyle.ACCENT, 0.3), UiStyle.ACCENT]}
	for st in states:
		var sb := UiStyle.flat_box(states[st][0], 8, 3)
		sb.set_border_width_all(2)
		sb.border_color = states[st][1]
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.clip_text = true
	b.add_theme_constant_override("icon_max_width", 64)
	b.add_theme_font_size_override("font_size", 10)
	b.add_theme_constant_override("line_spacing", -3)
	b.add_theme_constant_override("h_separation", 1)
	for cs in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(cs, UiStyle.ACCENT if cs.contains("pressed") else UiStyle.TEXT)


func _show_materials(box: VBoxContainer) -> void:
	# Matériaux : grandes vignettes avec leur nom, onglets par famille et recherche.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	var cur_pic := TextureRect.new()
	cur_pic.custom_minimum_size = Vector2(52, 52)
	cur_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cur_pic.stretch_mode = TextureRect.STRETCH_SCALE
	head.add_child(cur_pic)
	var cur_box := VBoxContainer.new()
	cur_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cur_box.add_theme_constant_override("separation", 0)
	var cur_name := Label.new()
	cur_name.add_theme_font_size_override("font_size", 15)
	cur_name.add_theme_color_override("font_color", UiStyle.ACCENT)
	cur_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	cur_box.add_child(cur_name)
	var cur_info := Label.new()
	cur_info.add_theme_font_size_override("font_size", 12)
	cur_info.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	cur_box.add_child(cur_info)
	head.add_child(cur_box)
	box.add_child(head)
	var show_current := func(i: int) -> void:
		var m: Dictionary = BlockEditor.MATERIALS[i]
		cur_pic.texture = _material_icon(i)
		cur_name.text = String(m.name)
		cur_info.text = "%s · %d € le bloc" % [_family_name(String(m.fam)), int(m.price)]
	show_current.call(clampi(_block_material, 0, BlockEditor.MATERIALS.size() - 1))

	# Recherche dans tous les matériaux.
	var search := LineEdit.new()
	search.placeholder_text = "Chercher un matériau (%d)…" % BlockEditor.MATERIALS.size()
	search.clear_button_enabled = true
	search.text = _mat_search
	box.add_child(search)

	# Onglets des familles.
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 4)
	chips.add_theme_constant_override("v_separation", 4)
	box.add_child(chips)

	# Grille des vignettes, dans sa propre zone défilante.
	var gscroll := ScrollContainer.new()
	gscroll.custom_minimum_size = Vector2(0, 330)
	gscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(gscroll)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gscroll.add_child(grid)
	var empty := Label.new()
	empty.text = "Aucun matériau ne correspond."
	empty.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	empty.visible = false
	box.add_child(empty)

	var mat_group := ButtonGroup.new()
	var cards: Array[Button] = []
	var fill := func() -> void:
		for c in grid.get_children():
			c.queue_free()
		cards.clear()
		var words := _mat_search.to_lower().split(" ", false)
		for i in BlockEditor.MATERIALS.size():
			var m: Dictionary = BlockEditor.MATERIALS[i]
			if _mat_family != "" and m.fam != _mat_family:
				continue
			# Matériaux pas encore inventés à l'époque de la partie (béton, plastique…).
			if not Epoques.materiau_disponible(i):
				continue
			if not words.is_empty():
				var hay := (String(m.name) + " " + _family_name(String(m.fam))).to_lower()
				var ok := true
				for w in words:
					if not hay.contains(w):
						ok = false
						break
				if not ok:
					continue
			var card := _material_card(i, mat_group)
			var mi := i
			card.pressed.connect(func() -> void:
				_block_material = mi
				show_current.call(mi)
				block_material_chosen.emit(mi))
			grid.add_child(card)
			cards.append(card)
		empty.visible = cards.is_empty()
		gscroll.visible = not cards.is_empty()
		gscroll.scroll_vertical = 0

	var counts := {"": BlockEditor.MATERIALS.size()}
	for m in BlockEditor.MATERIALS:
		counts[m.fam] = int(counts.get(m.fam, 0)) + 1
	var chip_group := ButtonGroup.new()
	for f in BlocMateriaux.FAMILIES:
		var fid := String(f.id)
		var chip := Button.new()
		chip.text = "%s %d" % ["Tous" if fid == "" else String(f.name), int(counts.get(fid, 0))]
		chip.toggle_mode = true
		chip.button_group = chip_group
		chip.add_theme_font_size_override("font_size", 12)
		UiStyle.style_icon_button(chip)
		chip.add_theme_stylebox_override("normal", UiStyle.flat_box(Color(1, 1, 1, 0.07), 12, 4))
		chip.add_theme_stylebox_override("hover", UiStyle.flat_box(Color(1, 1, 1, 0.16), 12, 4))
		chip.add_theme_stylebox_override("pressed", UiStyle.flat_box(UiStyle.ACCENT, 12, 4))
		chip.add_theme_stylebox_override("hover_pressed", UiStyle.flat_box(UiStyle.ACCENT.lightened(0.15), 12, 4))
		chip.button_pressed = fid == _mat_family
		chip.pressed.connect(func() -> void:
			_mat_family = fid
			fill.call())
		chips.add_child(chip)
	search.text_changed.connect(func(txt: String) -> void:
		_mat_search = txt.strip_edges()
		fill.call())
	fill.call()

	# Teintes.
	var tl := Label.new()
	tl.text = "Teinte (peinture) :"
	tl.add_theme_font_size_override("font_size", 12)
	box.add_child(tl)
	var trow := HFlowContainer.new()
	box.add_child(trow)
	var tint_group := ButtonGroup.new()
	for ti in BlocMateriaux.TINTS.size():
		var tb := Button.new()
		tb.custom_minimum_size = Vector2(22, 22)
		tb.toggle_mode = true
		tb.button_group = tint_group
		tb.tooltip_text = BlocMateriaux.TINT_NAMES[ti]
		var col: Color = BlocMateriaux.TINTS[ti]
		for state in ["normal", "hover", "pressed", "hover_pressed"]:
			var sbt := StyleBoxFlat.new()
			sbt.bg_color = col
			sbt.set_corner_radius_all(11)
			if ti == 0:
				sbt.bg_color = Color(0.85, 0.85, 0.85)
				sbt.set_border_width_all(2)
				sbt.border_color = Color(0.4, 0.4, 0.4)
			if state.contains("pressed"):
				sbt.set_border_width_all(3)
				sbt.border_color = Color.WHITE
			tb.add_theme_stylebox_override(state, sbt)
		tb.button_pressed = ti == _block_tint
		var tid := ti
		tb.pressed.connect(func() -> void:
			_block_tint = tid
			block_tint_chosen.emit(tid))
		trow.add_child(tb)


func _show_capture() -> void:
	# Enregistrer : le bouton « Enregistrer mon bâtiment » prend tout le groupe de
	# blocs visé. Le rectangle à tracer reste pour choisir une partie seulement.
	_list.add_child(HSeparator.new())
	var save := Button.new()
	save.text = "Enregistrer mon bâtiment"
	save.icon = Icones.get_icon("banque", 18)
	save.tooltip_text = "Range ta construction dans Mes modèles (nom et usage dans la partie)."
	save.pressed.connect(func() -> void: save_requested.emit())
	_add(save)
	var crow := HBoxContainer.new()
	var cname := LineEdit.new()
	cname.placeholder_text = "Nom de la création"
	cname.text = _capture_name
	cname.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cname.text_changed.connect(func(txt: String) -> void:
		_capture_name = txt
		capture_name_changed.emit(txt))
	crow.add_child(cname)
	var cap := Button.new()
	cap.text = "Une partie seulement"
	cap.tooltip_text = "Clic glissé autour d'une partie de ta construction : elle devient un bâtiment de l'onglet Mes créations, à poser où tu veux."
	cap.toggle_mode = true
	cap.button_group = _item_group
	cap.pressed.connect(func() -> void: block_tool_chosen.emit(BlockEditor.Tool.CAPTURE))
	crow.add_child(cap)
	_list.add_child(crow)
	_item_buttons.append(crow)


## Nom affiché d'une famille de matériaux.
func _family_name(fid: String) -> String:
	for f in BlocMateriaux.FAMILIES:
		if String(f.id) == fid:
			return String(f.name)
	return fid


## Vignette d'un matériau : l'image en grand, son nom dessous, cadre ambré si choisi.
func _material_card(i: int, group: ButtonGroup) -> Button:
	var m: Dictionary = BlockEditor.MATERIALS[i]
	var b := Button.new()
	_card_look(b)
	b.toggle_mode = true
	b.button_group = group
	b.tooltip_text = "%s\n%s · %d € le bloc" % [m.name, _family_name(String(m.fam)), m.price]
	b.icon = _material_icon(i)
	b.text = String(m.name)
	b.button_pressed = i == _block_material
	return b


## Image d'un matériau pour le panneau : 64 px, bord éclairé façon tuile, verre sur fond sombre.
func _material_icon(i: int) -> Texture2D:
	if not _icons.has(i):
		var src: Image = BlocMateriaux.image(i).duplicate()
		src.clear_mipmaps()
		var n := src.get_width()
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.22, 0.27, 0.32) if BlocMateriaux.is_glass(i) else Color(0, 0, 0, 0))
		img.blend_rect(src, Rect2i(0, 0, n, n), Vector2i.ZERO)
		for y in n:
			var xs: Array = range(n) if y < 3 or y >= n - 3 else [0, 1, 2, n - 3, n - 2, n - 1]
			for x: int in xs:
				var c := img.get_pixel(x, y)
				var lit := x < 3 or y < 3
				var f := 1.25 if lit else 0.7
				if x < 3 and n - 1 - y < 3 or y < 3 and n - 1 - x < 3:
					f = 1.0
				img.set_pixel(x, y, Color(clampf(c.r * f, 0, 1), clampf(c.g * f, 0, 1), clampf(c.b * f, 0, 1), 1.0))
		_icons[i] = ImageTexture.create_from_image(img)
	return _icons[i]


## Mes créations en blocs. in_bank : section de l'onglet Mes modèles (Banque).
func show_creations_section() -> void:
	var ids := Creations.ids()
	if ids.is_empty():
		return
	var h := Label.new()
	h.text = "Créations en blocs"
	h.add_theme_font_size_override("font_size", 15)
	h.add_theme_color_override("font_color", UiStyle.CREATE if workshop else UiStyle.ACCENT)
	_add(h)
	_show_creations(false)


func _show_creations(standalone := true) -> void:
	if standalone:
		_filters.visible = false
	var ids := Creations.ids()
	if ids.is_empty():
		var none := Label.new()
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.text = "Aucune création pour l'instant. Construis avec l'Éditeur libre, puis « Enregistrer » et un clic glissé autour de ta construction."
		_list.add_child(none)
		_item_buttons.append(none)
		return
	for id in ids:
		var t := BuildingCatalog.get_type(id)
		var row := HBoxContainer.new()
		var b := Button.new()
		b.text = "%s  ·  %d × %d m  ·  %s" % [t.name, t.w, t.d, BuildingSystem.format_short(ReglagesPartie.prix(BuildingCatalog.cost(id)))]
		b.tooltip_text = String(t.desc)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		b.toggle_mode = true
		b.button_group = _item_group
		var type_id: String = id
		b.pressed.connect(func() -> void: building_chosen.emit(type_id))
		row.add_child(b)
		var fn := Button.new()
		fn.text = "Fonction"
		fn.toggle_mode = true
		fn.button_pressed = _creation_choosing == type_id
		fn.tooltip_text = "Fonction : %s.\nLe bâtiment du jeu dont cette création prend le rôle (centrale, stade, piscine…)." % (
			ModelesJeu.fonction_name(String(Creations.items[type_id].get("fonction", ""))) if String(Creations.items[type_id].get("fonction", "")) != "" else "aucune (décor)")
		fn.pressed.connect(func() -> void:
			_creation_choosing = "" if _creation_choosing == type_id else type_id
			show_category(_category))
		row.add_child(fn)
		var del := Button.new()
		del.text = "✕"
		del.tooltip_text = "Supprimer cette création de la bibliothèque (les exemplaires déjà posés restent)."
		del.pressed.connect(func() -> void:
			creation_deleted.emit(type_id)
			show_category(_category))
		row.add_child(del)
		_list.add_child(row)
		_item_buttons.append(row)
		if _creation_choosing == type_id:
			var ch := FonctionChoix.new(String(Creations.items[type_id].get("fonction", "")))
			var none := Button.new()
			none.text = "Aucune fonction (simple décor)"
			none.alignment = HORIZONTAL_ALIGNMENT_LEFT
			none.pressed.connect(func() -> void: ch.picked.emit(""))
			ch.add_child(none)
			ch.move_child(none, 1)
			ch.picked.connect(func(f: String) -> void:
				Creations.set_fonction(type_id, f)
				_creation_choosing = ""
				show_category(_category))
			_list.add_child(ch)
			_item_buttons.append(ch)


func set_block_info(text: String) -> void:
	if is_instance_valid(_block_label) and not _block_label.is_queued_for_deletion():
		_block_label.text = text + "\nClic droit : retirer un bloc · Ctrl+Z : annuler"


func set_zone_info(text: String) -> void:
	if is_instance_valid(_zone_label) and not _zone_label.is_queued_for_deletion():
		_zone_label.text = text


## Carte d'un bâtiment : vignette, nom, taille et prix. Clic : le poser.
func _card(id: String, fallback_icon: String) -> Button:
	var t := BuildingCatalog.get_type(id)
	var b := Button.new()
	b.custom_minimum_size = Vector2(168, 150)
	b.toggle_mode = true
	b.button_group = _item_group
	b.focus_mode = Control.FOCUS_NONE
	var price := ReglagesPartie.prix(BuildingCatalog.cost(id))
	var lock := ReglagesPartie.actuel.raison_blocage(id)
	b.tooltip_text = "%s · %d × %d m · %s\n%s\nPrix : %s (hors terrassement)" % [t.name, t.w, t.d,
		BuildingSystem.format_short(price), t.desc, BuildingSystem.format_money(price)]
	if lock != "":
		b.tooltip_text += "\n" + lock
		b.modulate = Color(1, 1, 1, 0.45)
	# Kit de l'État : un bon de la ville paie ce bâtiment (jusqu'au plafond).
	var kit := KitInstallation.instance
	var kit_vid := kit.ville_avec_bon(id) if kit != null and lock == "" else -1
	var offert := 0
	if kit_vid >= 0:
		var bon := KitInstallation.bon_du_type(id)
		offert = mini(price, kit.plafond(bon))
		var ville := String(kit.communes.villages[kit_vid].nom) if kit.communes != null and kit.communes.villages.has(kit_vid) else "ta ville"
		b.tooltip_text += "\nOffert par l'État : le bon « %s » de %s paie jusqu'à %s.%s" % [
			String(KitInstallation.BONS[bon][0]).to_lower(), ville, BuildingSystem.format_money(kit.plafond(bon)),
			" Un seul bâtiment par bon : choisis bien." if offert >= price else " La ville paie le reste."]
	var sel := UiStyle.flat_box(Color(1, 0.82, 0.4, 0.16), 10, 6)
	sel.border_color = UiStyle.ACCENT
	sel.set_border_width_all(2)
	b.add_theme_stylebox_override("normal", UiStyle.flat_box(Color(1, 1, 1, 0.05), 10, 6))
	b.add_theme_stylebox_override("hover", UiStyle.flat_box(Color(1, 1, 1, 0.11), 10, 6))
	b.add_theme_stylebox_override("pressed", sel)
	b.add_theme_stylebox_override("hover_pressed", sel)
	var type_id := id
	b.set_meta("type_id", id)
	b.pressed.connect(func() -> void:
		FavorisConstruire.noter(type_id)
		building_chosen.emit(type_id))
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(box)
	var pic := TextureRect.new()
	pic.custom_minimum_size = Vector2(156, 92)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.texture = Icones.get_icon(fallback_icon, 48, Color(1, 1, 1, 0.35))
	box.add_child(pic)
	if _vignettes:
		_vignettes.request(id, pic)
	if offert > 0:
		var badge := Label.new()
		badge.text = "Offert par l'État" if offert >= price else "Bon de l'État"
		badge.add_theme_font_size_override("font_size", 11)
		badge.add_theme_color_override("font_color", Color(0.1, 0.08, 0.02))
		badge.add_theme_stylebox_override("normal", UiStyle.flat_box(Color("ffd166"), 5, 3))
		badge.position = Vector2(4, 4)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pic.add_child(badge)
	var name_l := Label.new()
	name_l.text = String(t.name)
	name_l.clip_text = true
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_l.custom_minimum_size = Vector2(156, 0)
	name_l.add_theme_font_size_override("font_size", 13)
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(name_l)
	var meta := Label.new()
	meta.text = "%d × %d m  ·  %s" % [t.w, t.d, BuildingSystem.format_short(price)]
	if offert > 0:
		meta.text = "%d × %d m  ·  %s" % [t.w, t.d, "Offert" if offert >= price else "%s à payer" % BuildingSystem.format_short(price - offert)]
	if lock != "":
		if not Epoques.batiment_disponible(id):
			meta.text = "Arrive en %d" % Epoques.annee_batiment(id)
		else:
			meta.text = "Verrouillé · %d hab." % int(ReglagesPartie.PALIERS[ReglagesPartie.palier_requis(id)].habitants)
	meta.add_theme_font_size_override("font_size", 12)
	meta.add_theme_color_override("font_color", Color("ffd166") if offert > 0 and lock == "" else UiStyle.TEXT_DIM)
	meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(meta)
	# Étoile : garder ce bâtiment dans les Favoris.
	var star := Button.new()
	star.name = "Etoile"
	star.flat = true
	star.focus_mode = Control.FOCUS_NONE
	star.toggle_mode = true
	star.button_pressed = FavorisConstruire.est_favori(id)
	star.tooltip_text = "Retirer des favoris" if star.button_pressed else "Ajouter aux favoris"
	star.icon = Icones.get_icon("etoile", 20, UiStyle.ACCENT if star.button_pressed else Color(1, 1, 1, 0.55))
	star.position = Vector2(b.custom_minimum_size.x - 34, 4)
	star.size = Vector2(30, 30)
	star.toggled.connect(func(on: bool) -> void:
		FavorisConstruire.basculer(type_id)
		star.icon = Icones.get_icon("etoile", 20, UiStyle.ACCENT if on else Color(1, 1, 1, 0.55))
		star.tooltip_text = "Retirer des favoris" if on else "Ajouter aux favoris"
		if _category == "favoris" or not workshop:
			_fill_themes())
	b.add_child(star)
	return b


func is_open() -> bool:
	return _panel.visible


## Bord gauche du panneau à l'écran quand il est ouvert, sinon -1.
func bord_gauche() -> float:
	return _panel.get_global_rect().position.x if _panel.visible else -1.0


func set_open(on: bool) -> void:
	_panel.visible = on


func toggle() -> void:
	set_open(not _panel.visible)


func set_growth(on: bool) -> void:
	_growth = on


## Plus rien de sélectionné dans le panneau (un autre outil a été choisi).
func clear_selection() -> void:
	var pressed := _item_group.get_pressed_button()
	if pressed:
		pressed.set_pressed_no_signal(false)


func set_money(text: String) -> void:
	_money_label.text = text.replace("Caisse : ", "")


func set_summary(text: String) -> void:
	_summary_label.text = text


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.physical_keycode == KEY_B and not key.shift_pressed:
		toggle()
