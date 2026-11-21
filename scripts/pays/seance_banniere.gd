class_name SeanceBanniere
extends CanvasLayer
## Récompense visible d'un palier de séance : une bannière au centre de l'écran
## (médaille de la couleur du palier, but, prime), qui grossit, reste un moment
## puis s'efface. Elle ne bloque pas la souris.

const DUREE := 4.0

var _panel: PanelContainer
var _medaille: Label
var _titre: Label
var _texte: Label
var _tween: Tween


func _ready() -> void:
	layer = 20
	_panel = PanelContainer.new()
	_panel.name = "BannierePalier"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.22
	_panel.anchor_bottom = 0.22
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.custom_minimum_size = Vector2(420, 0)
	UiStyle.style_panel(_panel, 0.94, 16, 16)
	add_child(_panel)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(v)
	_medaille = _label(44)
	v.add_child(_medaille)
	_titre = _label(22)
	v.add_child(_titre)
	_texte = _label(14, UiStyle.TEXT)
	_texte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Largeur fixée : sans elle, le texte à la ligne fait une bannière démesurément haute.
	_texte.custom_minimum_size = Vector2(388, 0)
	v.add_child(_texte)
	_panel.visible = false


func _label(size: int, col := UiStyle.ACCENT) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func montrer(n: int, s: Dictionary) -> void:
	if _panel == null or n < 1 or n > 3:
		return
	var col: Color = Seance.COULEURS_PALIERS[n - 1]
	_medaille.text = "●" if n < 3 else "★"
	_medaille.add_theme_color_override("font_color", col)
	_titre.text = "Palier %s !" % Seance.nom_palier(n - 1) if n < 3 else "Séance réussie : médaille d'or !"
	_titre.add_theme_color_override("font_color", col)
	var prime := roundi(float(s.get("prime", 0)) * float(Seance.PARTS[n - 1]))
	_texte.text = "%s\n+%s dans la caisse" % [String(s.get("titre", "")), BuildingSystem.format_money(prime)] \
		+ (" et 1 point de progrès" if n == 3 else "")
	_panel.visible = true
	_panel.size = Vector2.ZERO
	_panel.reset_size()
	_panel.pivot_offset = _panel.size * 0.5
	_panel.modulate.a = 0.0
	_panel.scale = Vector2(0.7, 0.7)
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_panel, "modulate:a", 1.0, 0.25)
	_tween.tween_property(_panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.chain().tween_interval(DUREE)
	_tween.chain().tween_property(_panel, "modulate:a", 0.0, 0.6)
	_tween.chain().tween_callback(func() -> void: _panel.visible = false)


func visible_maintenant() -> bool:
	return _panel != null and _panel.visible
