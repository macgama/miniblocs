class_name MultijoueurPanel
extends Control
## Menu principal → « Entre amis » : rejoindre une carte (adresse, code, pseudo)
## ou héberger une de ses parties sur ce PC (un serveur sans écran qui continue
## de tourner quand on ferme le jeu). Voir docs/multijoueur.md.

signal closed

var _adresse: LineEdit
var _code: LineEdit
var _pseudo: LineEdit
var _etat: Label
var _rejoindre: Button
var _parties: OptionButton
var _port: SpinBox
var _ids: Array = []
var _essais := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 0)
	UiStyle.style_panel(panel, 0.96, 10, 16)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var t := Label.new()
	t.text = "Carte entre amis"
	t.add_theme_font_size_override("font_size", 22)
	t.add_theme_color_override("font_color", UiStyle.ACCENT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var x := Button.new()
	x.text = "Fermer (Échap)"
	x.pressed.connect(fermer)
	head.add_child(x)
	v.add_child(_texte("Une carte partagée sur invitation : elle tourne sur un serveur, même quand son créateur n'est pas là. Chacun a sa caisse et devient maire des villes qu'il fonde.", UiStyle.TEXT_DIM))

	var s := Multijoueur.souvenirs()
	v.add_child(_titre("Rejoindre une carte"))
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 10)
	v.add_child(g)
	_adresse = _champ(g, "Adresse du serveur", s.adresse, "ex. 192.168.1.20 ou monserveur.fr:24680")
	_code = _champ(g, "Code d'invitation", s.code, "ex. ABCD-EFGH (pas besoin si tu es déjà membre)")
	_pseudo = _champ(g, "Ton pseudo", s.pseudo if s.pseudo != "" else OS.get_environment("USERNAME"), "le nom que voient les autres")
	_rejoindre = Button.new()
	_rejoindre.text = "Rejoindre"
	_rejoindre.custom_minimum_size = Vector2(0, 40)
	_rejoindre.pressed.connect(rejoindre)
	var hj := HBoxContainer.new()
	hj.add_theme_constant_override("separation", 6)
	v.add_child(hj)
	_rejoindre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hj.add_child(_rejoindre)
	var vis := Button.new()
	vis.text = "Visiter (sans construire)"
	vis.tooltip_text = "Se promener sur la carte en visiteur : pas de caisse, pas de construction, des cartes postales pour les joueurs."
	vis.custom_minimum_size = Vector2(0, 40)
	vis.pressed.connect(func() -> void: rejoindre(true))
	hj.add_child(vis)
	_etat = _texte("", UiStyle.GOOD)
	v.add_child(_etat)

	v.add_child(_titre("Héberger une de mes parties sur ce PC"))
	v.add_child(_texte("Une copie de la partie devient la carte entre amis (ta partie solo ne change pas). Le serveur continue tant que ce PC est allumé ; pour une carte ouverte jour et nuit, voir docs/multijoueur.md (petit serveur gratuit).", UiStyle.TEXT_DIM))
	var h := HBoxContainer.new()
	v.add_child(h)
	_parties = OptionButton.new()
	_parties.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for m in SaveGame.list_saves():
		if String(m.get("mode", "")) == "entre_amis" and String(m.id).begins_with("amis-") and m.has("serveur"):
			continue
		_parties.add_item(String(m.get("nom", m.id)))
		_ids.append(String(m.id))
	h.add_child(_parties)
	_port = SpinBox.new()
	_port.min_value = 1024
	_port.max_value = 65535
	_port.value = Protocole.PORT_DEFAUT
	_port.tooltip_text = "Port UDP du serveur"
	h.add_child(_port)
	var heb := Button.new()
	heb.text = "Héberger et rejoindre"
	heb.disabled = _ids.is_empty()
	heb.pressed.connect(heberger)
	h.add_child(heb)


func _titre(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 17)
	l.add_theme_color_override("font_color", UiStyle.ACCENT)
	return l


func _texte(t: String, c: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(580, 0)
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", c)
	return l


func _champ(g: GridContainer, nom: String, val: String, aide: String) -> LineEdit:
	var l := Label.new()
	l.text = nom
	g.add_child(l)
	var e := LineEdit.new()
	e.text = val
	e.placeholder_text = aide
	e.custom_minimum_size = Vector2(400, 0)
	e.text_submitted.connect(func(_s: String) -> void: rejoindre())
	g.add_child(e)
	return e


func rejoindre(en_visiteur := false) -> void:
	var c := Multijoueur.nouveau_client(get_tree())
	c.etat_change.connect(func(_e: String, texte: String) -> void:
		if not is_instance_valid(_etat):
			return
		_etat.text = texte
		_rejoindre.disabled = _e in ["connexion", "attente", "chargement"]
		# Serveur qui vient d'être lancé ici : il lui faut parfois quelques secondes de plus.
		if _e == "deconnecte" and texte.begins_with("Pas de réponse") and _essais > 0 and _essais < 6:
			_essais += 1
			_etat.text = "Le serveur démarre… (essai %d)" % _essais
			get_tree().create_timer(2.0).timeout.connect(rejoindre))
	var err := c.connecter(_adresse.text, _code.text, _pseudo.text, en_visiteur)
	if err != "":
		_etat.text = err


func heberger() -> void:
	var i := _parties.selected
	if i < 0 or i >= _ids.size():
		return
	var erreur := []
	var slot := Multijoueur.copier_en_carte(String(_ids[i]), erreur)
	if slot == "":
		_etat.text = "Copie impossible : %s" % (erreur[0] if not erreur.is_empty() else "?")
		return
	var port := int(_port.value)
	var pid := Multijoueur.lancer_serveur_local(slot, port)
	if pid < 0:
		_etat.text = "Le serveur n'a pas pu démarrer."
		return
	_etat.text = "Serveur lancé (processus %d). Connexion…" % pid
	_adresse.text = "127.0.0.1:%d" % port if port != Protocole.PORT_DEFAUT else "127.0.0.1"
	# Le temps que le serveur ouvre la carte.
	_essais = 1
	get_tree().create_timer(4.0).timeout.connect(rejoindre)


## Nouvelle carte créée dans l'assistant : le serveur vient d'être lancé sur ce
## PC (processus pid), on y entre dès qu'il répond.
func attendre_serveur_local(pid: int, port: int, pseudo_: String) -> void:
	if not is_node_ready():
		await ready
	if pid < 0:
		_etat.text = "Le serveur n'a pas pu démarrer."
		return
	if pseudo_.strip_edges() != "":
		_pseudo.text = pseudo_.strip_edges()
	_code.text = ""
	_adresse.text = "127.0.0.1:%d" % port if port != Protocole.PORT_DEFAUT else "127.0.0.1"
	_etat.text = "Serveur de ta nouvelle carte lancé (processus %d). Connexion…" % pid
	_essais = 1
	get_tree().create_timer(4.0).timeout.connect(rejoindre)


func fermer() -> void:
	closed.emit()
	queue_free()


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo and k.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		fermer()
