class_name ScenarioBilan
extends CanvasLayer
## Écran de fin d'un scénario : réussi ou non, détail du score, médaille, rang
## au classement (avec le nom à changer), et trois boutons : continuer à jouer
## (sans contrainte), rejouer, menu principal. Au-dessus du jeu.

signal menu_demande
signal rejouer_demande
signal ferme

var r := {}
var _nom: LineEdit


func _init(resultat: Dictionary) -> void:
	r = resultat
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
	var panel := PanelContainer.new()
	panel.name = "BilanScenario"
	UiStyle.style_panel(panel, 0.95, 16, 22)
	panel.custom_minimum_size = Vector2(620, 0)
	centre.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var s := Scenarios.donnees(String(r.get("id", "")))
	var victoire := bool(r.get("victoire", false))
	v.add_child(_label(titre(), 30, UiStyle.ACCENT))
	v.add_child(_label(String(s.get("nom", "")), 18))
	v.add_child(_label(phrase(), 15, UiStyle.TEXT_DIM))
	var med := int(r.get("medaille", 0))
	if med > 0:
		var ml := _label("Médaille %s" % String(Scenarios.NOMS_MEDAILLES[med]).to_lower(), 20, Scenarios.COULEURS_MEDAILLES[med])
		ml.name = "Medaille"
		v.add_child(ml)
	var g := GridContainer.new()
	g.name = "Score"
	g.columns = 2
	g.add_theme_constant_override("h_separation", 28)
	g.add_theme_constant_override("v_separation", 4)
	v.add_child(g)
	for l in r.get("lignes", []):
		g.add_child(_label(String(l[0]), 14, UiStyle.TEXT_DIM, 420.0))
		var p := int(l[1])
		var pl := _label(("+%d" % p) if p > 0 else str(p), 14, UiStyle.TEXT, 120.0)
		pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		g.add_child(pl)
	g.add_child(_label("Score", 18, UiStyle.ACCENT, 420.0))
	var tl := _label("%d" % int(r.get("score", 0)), 18, UiStyle.ACCENT, 120.0)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	g.add_child(tl)
	var rang := int(r.get("rang", 0))
	if rang > 0:
		v.add_child(_label("%s au classement de ce scénario !" % ("1re place" if rang == 1 else "%de place" % rang), 16, UiStyle.GOOD))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		v.add_child(row)
		row.add_child(_label("Ton nom :", 14, UiStyle.TEXT, 90.0))
		_nom = LineEdit.new()
		_nom.name = "Nom"
		_nom.text = Classement.nom_joueur()
		_nom.max_length = 24
		_nom.custom_minimum_size = Vector2(260, 0)
		_nom.text_submitted.connect(func(_t: String) -> void: _garder_nom())
		row.add_child(_nom)
	elif bool(r.get("triche", false)) and victoire:
		v.add_child(_label("Les réglages de la partie ont changé en cours de route : ce score ne va pas au classement.", 13, UiStyle.TEXT_DIM))
	elif victoire:
		v.add_child(_label("Pas assez pour entrer dans les 10 meilleurs scores. La prochaine fois !", 13, UiStyle.TEXT_DIM))
	var row2 := HBoxContainer.new()
	row2.alignment = BoxContainer.ALIGNMENT_END
	row2.add_theme_constant_override("separation", 10)
	v.add_child(row2)
	var menu := Button.new()
	menu.name = "Menu"
	menu.text = "Menu principal"
	menu.pressed.connect(func() -> void:
		_garder_nom()
		menu_demande.emit())
	row2.add_child(menu)
	var rej := Button.new()
	rej.name = "Rejouer"
	rej.text = "Rejouer"
	rej.pressed.connect(func() -> void:
		_garder_nom()
		rejouer_demande.emit())
	row2.add_child(rej)
	var cont := Button.new()
	cont.name = "Continuer"
	cont.text = "Continuer à jouer"
	cont.tooltip_text = "La ville reste à toi, sans les règles du scénario."
	cont.pressed.connect(fermer)
	row2.add_child(cont)
	cont.grab_focus.call_deferred()


func titre() -> String:
	if bool(r.get("abandon", false)):
		return "Scénario abandonné"
	return "Scénario réussi !" if bool(r.get("victoire", false)) else "Date limite dépassée"


func phrase() -> String:
	if bool(r.get("abandon", false)):
		return "Tu as rendu l'écharpe au bout de %d jours. Personne ne t'en veut (enfin, presque)." % int(r.get("jours", 0))
	if bool(r.get("victoire", false)):
		return "Tous les objectifs remplis en %d jours, avec %d jours d'avance. Le conseil municipal applaudit (même l'opposition)." % [
			int(r.get("jours", 0)), int(r.get("jours_restants", 0))]
	return "%d objectifs sur %d remplis à la date limite. Le préfet note, soupire, et repassera." % [
		int(r.get("objectifs", 0)), int(r.get("total", 0))]


func _garder_nom() -> void:
	if _nom != null and int(r.get("rang", 0)) > 0:
		Classement.renommer(String(r.id), int(r.rang), _nom.text)


func fermer() -> void:
	_garder_nom()
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
