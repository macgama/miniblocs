class_name DemoBilan
extends CanvasLayer
## Bilan de fin de la démo guidée : temps joué, ville, chiffres, et deux
## boutons (continuer à jouer, menu principal). Au-dessus du jeu, qui
## continue derrière.

signal menu_demande
signal ferme

var chiffres := {}
var _panel: PanelContainer


func _init(c: Dictionary) -> void:
	chiffres = c
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	var voile := ColorRect.new()
	voile.color = Color(0, 0, 0, 0.45)
	voile.anchor_right = 1.0
	voile.anchor_bottom = 1.0
	add_child(voile)
	var centre := CenterContainer.new()
	centre.anchor_right = 1.0
	centre.anchor_bottom = 1.0
	add_child(centre)
	_panel = PanelContainer.new()
	_panel.name = "BilanDemo"
	UiStyle.style_panel(_panel, 0.95, 16, 22)
	_panel.custom_minimum_size = Vector2(620, 0)
	centre.add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_panel.add_child(v)
	v.add_child(_label("Fin de la démo", 30, UiStyle.ACCENT))
	v.add_child(_label("Merci d'avoir joué à MiniBlocs ! Voici ce que %s est devenue en %s." % [
		String(chiffres.get("nom", "ta ville")), Demo.duree(int(chiffres.get("minutes", 0)))], 16))
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 28)
	g.add_theme_constant_override("v_separation", 6)
	v.add_child(g)
	for l in lignes():
		g.add_child(_label(String(l[0]), 15, UiStyle.TEXT_DIM, 200.0))
		g.add_child(_label(String(l[1]), 15, UiStyle.TEXT, 340.0))
	v.add_child(_label("Dans le jeu complet : le parc de loisirs, le zoo, les musées et salles de spectacle déjà là, puis le club de sport et les cartes à plusieurs. Ajoute MiniBlocs à ta liste de souhaits pour suivre la suite.", 13, UiStyle.TEXT_DIM))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	var menu := Button.new()
	menu.name = "Menu"
	menu.text = "Menu principal"
	menu.pressed.connect(func() -> void: menu_demande.emit())
	row.add_child(menu)
	var cont := Button.new()
	cont.name = "Continuer"
	cont.text = "Continuer à jouer"
	cont.pressed.connect(fermer)
	row.add_child(cont)
	cont.grab_focus.call_deferred()


## Lignes du tableau : [libellé, valeur].
func lignes() -> Array:
	var c := chiffres
	return [
		["Temps de jeu", Demo.duree(int(c.get("minutes", 0))) + (" (%d jours en ville)" % int(c.jours) if int(c.get("jours", 0)) > 0 else "")],
		["Rang", String(c.get("rang", "Hameau"))],
		["Habitants", str(int(c.get("habitants", 0)))],
		["Bâtiments", str(int(c.get("batiments", 0)))],
		["Routes", "%.1f km" % float(c.get("routes_km", 0.0))],
		["Lignes de transport", str(int(c.get("lignes", 0)))],
		["Caisse", BuildingSystem.format_money(int(c.get("caisse", 0)))],
		["Réputation du pays", "★".repeat(int(c.get("etoiles", 0))) if int(c.get("etoiles", 0)) > 0 else "☆"],
		["Étapes de la démo", "%d / %d" % [mini(int(c.get("etapes", 0)), int(c.get("total", 0))), int(c.get("total", 0))]],
	]


func fermer() -> void:
	ferme.emit()
	queue_free()


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and k.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		fermer()


func _label(t: String, size := 14, col := UiStyle.TEXT, w := 576.0) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(w, 0)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l
