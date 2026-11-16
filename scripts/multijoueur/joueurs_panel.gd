class_name JoueursPanel
extends PanelContainer
## Carte entre amis (F3, en jeu) : qui est là, ta caisse, le code d'invitation
## (admin), la discussion et la resynchronisation.

signal closed

var client: ClientAmis
var _liste: VBoxContainer
var _chat: RichTextLabel
var _saisie: LineEdit
var _code: Label
var _etat: Label


func _init(c: ClientAmis) -> void:
	client = c
	name = "PanneauJoueurs"


func _ready() -> void:
	UiStyle.style_panel(self)
	custom_minimum_size = Vector2(380, 0)
	UiStyle.place_right(self)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var t := Label.new()
	t.text = "Carte entre amis"
	t.add_theme_font_size_override("font_size", 18)
	t.add_theme_color_override("font_color", UiStyle.ACCENT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var x := Button.new()
	x.text = "✕"
	x.tooltip_text = "Fermer (F3)"
	x.pressed.connect(fermer)
	head.add_child(x)
	_etat = _label("", 13, UiStyle.TEXT_DIM)
	v.add_child(_etat)
	_code = _label("", 14, UiStyle.TEXT)
	v.add_child(_code)
	if client.admin:
		var hb := HBoxContainer.new()
		v.add_child(hb)
		var copier := Button.new()
		copier.text = "Copier le code"
		copier.pressed.connect(func() -> void: DisplayServer.clipboard_set(client.code_carte))
		hb.add_child(copier)
		var neuf := Button.new()
		neuf.text = "Nouveau code"
		neuf.tooltip_text = "L'ancien code ne marche plus (les membres déjà entrés restent membres)."
		neuf.pressed.connect(func() -> void: client.envoyer_admin("code"))
		hb.add_child(neuf)
		var vis := CheckBox.new()
		vis.text = "Visiteurs sans code"
		vis.tooltip_text = "Les inconnus qui ont l'adresse peuvent se promener sur la carte (sans construire) et laisser des cartes postales."
		vis.button_pressed = client.visites_ouvertes
		vis.toggled.connect(func(on: bool) -> void:
			client.visites_ouvertes = on
			client.envoyer_admin("visites", {"ouvertes": on}))
		hb.add_child(vis)
	v.add_child(_label("Joueurs", 15, UiStyle.ACCENT))
	_liste = VBoxContainer.new()
	v.add_child(_liste)
	v.add_child(_label("Discussion", 15, UiStyle.ACCENT))
	_chat = RichTextLabel.new()
	_chat.custom_minimum_size = Vector2(350, 180)
	_chat.scroll_following = true
	_chat.bbcode_enabled = false
	v.add_child(_chat)
	_saisie = LineEdit.new()
	_saisie.placeholder_text = "Écrire aux autres joueurs (Entrée)"
	_saisie.max_length = 300
	_saisie.text_submitted.connect(func(s: String) -> void:
		if s.strip_edges() != "":
			client.envoyer_chat(s)
		_saisie.clear())
	v.add_child(_saisie)
	var bas := HBoxContainer.new()
	v.add_child(bas)
	var rs := Button.new()
	rs.text = "Resynchroniser"
	rs.tooltip_text = "Redemande la carte entière au serveur (si quelque chose semble différent chez les autres)."
	rs.pressed.connect(client.demander_resync)
	bas.add_child(rs)
	var q := Button.new()
	q.text = "Quitter la carte"
	q.pressed.connect(func() -> void:
		client.deconnecter("Tu as quitté la carte entre amis.")
		get_tree().change_scene_to_file("res://scenes/menu_principal.tscn"))
	bas.add_child(q)
	if client.admin:
		var stop := Button.new()
		stop.text = "Arrêter le serveur"
		stop.tooltip_text = "Sauvegarde la carte et arrête le serveur (plus personne ne peut y jouer)."
		stop.pressed.connect(func() -> void: client.envoyer_admin("arreter"))
		bas.add_child(stop)
	client.joueurs_recus.connect(_maj_joueurs)
	client.chat_recu.connect(func(de: String, texte: String) -> void:
		_chat.append_text(("%s : %s\n" % [de, texte]) if de != "" else "— %s\n" % texte))
	client.info_recue.connect(func(_t: String) -> void: _maj_entete())
	_maj_entete()
	_maj_joueurs(client.joueurs)


func _label(texte: String, taille: int, couleur: Color) -> Label:
	var l := Label.new()
	l.text = texte
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(350, 0)
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", couleur)
	return l


func _maj_entete() -> void:
	_etat.text = "« %s » sur %s:%d · tu es %s%s." % [client.nom_carte, client.hote, client.port, client.pseudo,
		" (admin)" if client.admin else ""]
	_code.visible = client.admin and client.code_carte != ""
	_code.text = "Code d'invitation : %s" % client.code_carte


func _maj_joueurs(liste: Array) -> void:
	for c in _liste.get_children():
		c.queue_free()
	for j in liste:
		var h := HBoxContainer.new()
		_liste.add_child(h)
		var pt := Label.new()
		pt.text = "●" if bool(j.get("en_ligne", false)) else "○"
		pt.add_theme_color_override("font_color", UiStyle.GOOD if bool(j.get("en_ligne", false)) else UiStyle.TEXT_DIM)
		h.add_child(pt)
		var l := Label.new()
		var villes: Array = j.get("villes", [])
		l.text = "%s%s%s" % [j.get("pseudo", "?"), " · admin" if bool(j.get("admin", false)) else "",
			(" · maire de " + ", ".join(villes)) if not villes.is_empty() else ""]
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.clip_text = true
		h.add_child(l)
		if client.admin and not bool(j.get("admin", false)):
			var ex := Button.new()
			ex.text = "Exclure"
			var pid := String(j.get("pid", ""))
			ex.pressed.connect(func() -> void: client.envoyer_admin("exclure", {"pid": pid}))
			h.add_child(ex)


func fermer() -> void:
	closed.emit()
	queue_free()


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo and k.keycode == KEY_ESCAPE and not _saisie.has_focus():
		get_viewport().set_input_as_handled()
		fermer()
