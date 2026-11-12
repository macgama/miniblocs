class_name UiStyle
extends RefCounted
## Style commun des menus : panneaux sombres arrondis, accent ambre, boutons à
## icône avec la touche en pastille. Voir docs/interface.md.

const ACCENT := Color("ffd166")
const ACCENT_INK := Color("2a2414")
const TEXT := Color("eef3ee")
const TEXT_DIM := Color("b7c4bb")
const GOOD := Color("9fe3b0")
const PANEL_BG := Color(0.08, 0.10, 0.09, 0.88)
## Panneaux de droite (Construire, Lignes, Habitants) : même place, un à la fois.
const SIDE_LEFT := -392.0
const SIDE_RIGHT := -12.0
const SIDE_TOP := 78.0
## Haut de la barre de catégories (depuis le bas de l'écran).
const DOCK_HEIGHT := 100.0


static func panel_box(alpha := 0.88, radius := 12, margin := 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(PANEL_BG, alpha)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	sb.border_color = Color(1, 1, 1, 0.08)
	sb.set_border_width_all(1)
	return sb


static func flat_box(color: Color, radius := 9, margin := 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	return sb


static func style_panel(p: PanelContainer, alpha := 0.88, radius := 12, margin := 10) -> void:
	p.add_theme_stylebox_override("panel", panel_box(alpha, radius, margin))


## Bouton à icône : transparent, survol clair, enfoncé en ambre (icône et texte foncés).
static func style_icon_button(b: Button) -> void:
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", flat_box(Color(1, 1, 1, 0.0)))
	b.add_theme_stylebox_override("hover", flat_box(Color(1, 1, 1, 0.10)))
	b.add_theme_stylebox_override("pressed", flat_box(ACCENT))
	b.add_theme_stylebox_override("hover_pressed", flat_box(ACCENT.lightened(0.15)))
	b.add_theme_stylebox_override("disabled", flat_box(Color(1, 1, 1, 0.0)))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", ACCENT_INK)
	b.add_theme_color_override("font_hover_pressed_color", ACCENT_INK)
	b.add_theme_color_override("icon_normal_color", TEXT)
	b.add_theme_color_override("icon_hover_color", Color.WHITE)
	b.add_theme_color_override("icon_pressed_color", ACCENT_INK)
	b.add_theme_color_override("icon_hover_pressed_color", ACCENT_INK)


## Grand bouton de catégorie ou d'outil : icône au-dessus, nom dessous, touche en haut à droite.
static func tile_button(icon: String, label: String, key := "", size := Vector2(82, 70), icon_px := 30) -> Button:
	var b := Button.new()
	b.icon = Icones.get_icon(icon, icon_px)
	b.text = label
	b.custom_minimum_size = size
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_constant_override("icon_max_width", icon_px)
	style_icon_button(b)
	if key != "":
		add_key_badge(b, key)
	return b


## Petit bouton carré à icône seule (barre du haut, en-têtes de panneaux).
## La touche est rappelée dans l'infobulle.
static func icon_button(icon: String, tooltip: String, key := "", px := 22, side := 40) -> Button:
	var b := Button.new()
	b.icon = Icones.get_icon(icon, px)
	b.tooltip_text = tooltip if key == "" else "%s (%s)" % [tooltip, key]
	b.custom_minimum_size = Vector2(side, side)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.expand_icon = false
	style_icon_button(b)
	return b


## Pastille de touche (« 5 », « F1 ») posée dans un coin du bouton.
static func add_key_badge(b: Control, key: String) -> Label:
	var l := key_label(key)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	l.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	l.offset_right = -4
	l.offset_top = 4
	b.add_child(l)
	return l


static func key_label(key: String) -> Label:
	var l := Label.new()
	l.text = key
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", Color("1d2320"))
	var sb := flat_box(Color("e9efe6"), 4, 0)
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	l.add_theme_stylebox_override("normal", sb)
	return l


## Étiquette « chiffre de la ville » : icône ambre + valeur, cliquable.
static func stat_chip(icon: String, tooltip: String) -> Button:
	var b := Button.new()
	b.icon = Icones.get_icon(icon, 20, ACCENT)
	b.tooltip_text = tooltip
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", flat_box(Color(1, 1, 1, 0.07), 9, 7))
	b.add_theme_stylebox_override("hover", flat_box(Color(1, 1, 1, 0.14), 9, 7))
	b.add_theme_stylebox_override("pressed", flat_box(Color(1, 1, 1, 0.18), 9, 7))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_font_size_override("font_size", 15)
	return b


static func vsep() -> Control:
	var c := ColorRect.new()
	c.color = Color(1, 1, 1, 0.14)
	c.custom_minimum_size = Vector2(1, 0)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c
