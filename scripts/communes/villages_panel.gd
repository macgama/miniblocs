class_name VillagesPanel
extends CanvasLayer
## Panneau « Villages et territoire » (Maj+M) : la liste des villages, leurs
## chiffres, et les outils pour fonder, agrandir, céder, renommer, fusionner.
## Montre aussi le bandeau « Fonde ton village » tant qu'il n'y en a pas.

signal focus_requested(pos: Vector3)
## Le joueur veut poser le bâtiment fondateur (nom du futur village).
signal fonder_requested(nom: String)

const W := 360.0
const H := 540.0

var cm: Communes
var _panel: PanelContainer
var _body: VBoxContainer
var _scroll: ScrollContainer
var _banner: PanelContainer
var _banner_label: Label
var _dialog: ConfirmationDialog
var _dialog_edit: LineEdit
var _dialog_drapeau: OptionButton
var _drapeau_dialog: ConfirmationDialog
var _drapeau_choix: OptionButton
var _drapeau_vid := -1
var _tick := 0.0
var _renommer := -1


func setup(c: Communes) -> void:
	cm = c
	_build()
	cm.changed.connect(func() -> void:
		if is_open():
			refresh())


func _build() -> void:
	layer = 6
	_panel = PanelContainer.new()
	UiStyle.place_right(_panel)
	_panel.custom_minimum_size = Vector2(W, 0)
	UiStyle.style_panel(_panel)
	_panel.visible = false
	add_child(_panel)
	var outer := VBoxContainer.new()
	_panel.add_child(outer)
	var head := HBoxContainer.new()
	outer.add_child(head)
	var icon := TextureRect.new()
	icon.texture = Icones.get_icon("village", 22, UiStyle.ACCENT)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	head.add_child(icon)
	var title := Label.new()
	title.text = "Villages et territoire"
	title.add_theme_font_size_override("font_size", 16)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var x := UiStyle.icon_button("fermer", "Fermer", "Maj+M", 18, 32)
	x.pressed.connect(func() -> void: set_open(false))
	head.add_child(x)
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(W, H)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(_scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 4)
	_scroll.add_child(_body)

	# Bandeau en haut de l'écran tant qu'aucun village n'est fondé.
	_banner = PanelContainer.new()
	UiStyle.style_panel(_banner, 0.92, 10, 10)
	_banner.anchor_left = 0.5
	_banner.anchor_right = 0.5
	_banner.offset_top = 80
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.visible = false
	add_child(_banner)
	var bh := HBoxContainer.new()
	bh.add_theme_constant_override("separation", 10)
	_banner.add_child(bh)
	var bi := TextureRect.new()
	bi.texture = Icones.get_icon("village", 28, UiStyle.ACCENT)
	bi.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	bh.add_child(bi)
	_banner_label = Label.new()
	_banner_label.text = "Fonde ton village : pose sa Maison de commune où tu veux sur la carte.\nAvant, on ne peut que regarder et modeler le paysage."
	_banner_label.add_theme_font_size_override("font_size", 14)
	bh.add_child(_banner_label)
	var bb := Button.new()
	bb.text = "Fonder mon village"
	bb.focus_mode = Control.FOCUS_NONE
	bb.pressed.connect(func() -> void: demander_nom())
	bh.add_child(bb)

	# Fenêtre du nom du village.
	_dialog = ConfirmationDialog.new()
	_dialog.title = "Fonder un village"
	_dialog.ok_button_text = "Choisir l'emplacement"
	_dialog.cancel_button_text = "Plus tard"
	var dv := VBoxContainer.new()
	var dl := Label.new()
	dl.text = "Nom du village :"
	dv.add_child(dl)
	_dialog_edit = LineEdit.new()
	_dialog_edit.custom_minimum_size = Vector2(320, 0)
	_dialog_edit.text_submitted.connect(func(_t: String) -> void:
		_dialog.hide()
		_valider_nom())
	dv.add_child(_dialog_edit)
	var df := HBoxContainer.new()
	var dfl := Label.new()
	dfl.text = "Drapeau :"
	df.add_child(dfl)
	_dialog_drapeau = choix_drapeau()
	_dialog_drapeau.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	df.add_child(_dialog_drapeau)
	dv.add_child(df)
	var dh := Label.new()
	dh.text = "Ensuite, pose la Maison de commune (300 000 €, pas besoin de route).\nElle donne au village un territoire d'environ 500 m autour d'elle,\nqui grandira avec la population."
	dh.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	dh.add_theme_font_size_override("font_size", 12)
	dv.add_child(dh)
	_dialog.add_child(dv)
	_dialog.confirmed.connect(_valider_nom)
	add_child(_dialog)

	# Fenêtre « Changer de drapeau » d'un village existant.
	_drapeau_dialog = ConfirmationDialog.new()
	_drapeau_dialog.title = "Drapeau du village"
	_drapeau_dialog.ok_button_text = "Hisser"
	_drapeau_dialog.cancel_button_text = "Annuler"
	_drapeau_choix = choix_drapeau()
	_drapeau_choix.custom_minimum_size = Vector2(320, 0)
	_drapeau_dialog.add_child(_drapeau_choix)
	_drapeau_dialog.confirmed.connect(func() -> void:
		if cm.villages.has(_drapeau_vid):
			cm.set_drapeau(_drapeau_vid, code_choisi(_drapeau_choix))
		refresh())
	add_child(_drapeau_dialog)


## Liste déroulante de tous les drapeaux (taper une lettre pour sauter au pays).
static func choix_drapeau() -> OptionButton:
	var o := OptionButton.new()
	o.focus_mode = Control.FOCUS_ALL
	o.add_item("Aucun drapeau")
	o.set_item_metadata(0, "")
	for e in Drapeaux.liste():
		var ic := Drapeaux.icone(String(e[0]), 18)
		if ic:
			o.add_icon_item(ic, String(e[1]))
		else:
			o.add_item(String(e[1]))
		o.set_item_metadata(o.item_count - 1, String(e[0]))
	o.get_popup().max_size = Vector2i(0, 480)
	return o


static func choisir_code(o: OptionButton, code: String) -> void:
	for i in o.item_count:
		if String(o.get_item_metadata(i)) == code.to_lower():
			o.select(i)
			return
	o.select(0)


static func code_choisi(o: OptionButton) -> String:
	return String(o.get_item_metadata(o.selected)) if o.selected >= 0 else ""


## Ouvre la fenêtre pour changer le drapeau d'un village.
func changer_drapeau(vid: int) -> void:
	if not cm.villages.has(vid):
		return
	_drapeau_vid = vid
	_drapeau_dialog.title = "Drapeau de %s" % cm.villages[vid].nom
	choisir_code(_drapeau_choix, String(cm.villages[vid].get("drapeau", "")))
	_drapeau_dialog.popup_centered()


func is_open() -> bool:
	return _panel.visible


func set_open(on: bool) -> void:
	_panel.visible = on
	cm.montre = on
	if on:
		refresh()
	elif cm.outil != "":
		cm.set_outil("")


func toggle() -> void:
	set_open(not _panel.visible)


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.physical_keycode == KEY_M and k.shift_pressed and not k.ctrl_pressed and not k.alt_pressed:
		toggle()
		get_viewport().set_input_as_handled()


## Ouvre la fenêtre du nom du village (premier village ou nouveau village).
func demander_nom() -> void:
	_dialog.title = "Fonder ton village" if cm.villages.is_empty() else "Fonder un nouveau village"
	_dialog_edit.text = cm.nom_auto()
	choisir_code(_dialog_drapeau, cm.drapeau_en_attente if cm.drapeau_en_attente != "" else Communes.drapeau_du_lieu())
	_dialog.popup_centered()
	_dialog_edit.grab_focus()
	_dialog_edit.select_all()


func _valider_nom() -> void:
	var nom := _dialog_edit.text.strip_edges()
	if nom == "":
		nom = cm.nom_auto()
	cm.nom_en_attente = nom
	cm.drapeau_en_attente = code_choisi(_dialog_drapeau)
	if cm.drapeau_en_attente == "":
		cm.drapeau_en_attente = "-"
	fonder_requested.emit(nom)


func _process(delta: float) -> void:
	_banner.visible = cm != null and cm.fondation_requise() and not _dialog.visible
	if not is_open():
		return
	_tick += delta
	if _tick >= 2.0:
		_tick = 0.0
		if _renommer >= 0 or _drapeau_dialog.visible:
			return
		var keep := _scroll.scroll_vertical
		refresh()
		_scroll.set_deferred("scroll_vertical", keep)


# --- Contenu -----------------------------------------------------------------------------

func _text(t: String, dim := false, size := 13) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(W - 30, 0)
	l.add_theme_font_size_override("font_size", size)
	if dim:
		l.add_theme_color_override("font_color", Color(1, 1, 1, 0.65))
	_body.add_child(l)
	return l


func _section(t: String, col := UiStyle.ACCENT) -> void:
	_body.add_child(HSeparator.new())
	var l := _text(t, false, 15)
	l.add_theme_color_override("font_color", col)


func _button(t: String, tip: String, f: Callable, parent: Control = null, toggled := false) -> Button:
	var b := Button.new()
	b.text = t
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 12)
	if toggled:
		b.toggle_mode = true
		b.button_pressed = true
	b.pressed.connect(f)
	(parent if parent != null else _body).add_child(b)
	return b


func refresh() -> void:
	if cm == null:
		return
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	var vb := Button.new()
	vb.toggle_mode = true
	vb.button_pressed = cm.calque
	vb.text = "Voir les territoires sur la carte (aussi dans N)"
	vb.focus_mode = Control.FOCUS_NONE
	vb.pressed.connect(func() -> void:
		Calques.afficher("territoires", not cm.calque)
		refresh())
	_body.add_child(vb)
	if cm.villages.is_empty():
		_section("Aucun village")
		if cm.fondation_requise():
			_text("Une partie commence par la fondation d'un village. Choisis son nom, puis pose sa Maison de commune n'importe où sur la carte : pas besoin de route, c'est la première pierre.")
		else:
			_text("Pose une Maison de commune (Construire → Services) pour fonder un village et lui donner un territoire.", true)
		_button("Fonder mon village…", "Choisir le nom, puis poser la Maison de commune", demander_nom)
		_regles()
		return
	var ids := cm.villages.keys()
	ids.sort()
	for vid in ids:
		_carte_village(int(vid), ids)
	_section("Nouveau village")
	_text("Pose une Maison de commune (ou une Mairie) hors de tout territoire, à %.0f km au moins d'un autre centre." % (Communes.DIST_MIN / 1000.0), true)
	_button("Fonder un nouveau village…", "Choisir le nom, puis poser la Maison de commune", demander_nom)
	_regles()


func _regles() -> void:
	_section("Règles")
	var r := ReglagesPartie.actuel
	_text("• Territoire en carrés de 100 × 100 m (1 ha). Il grandit tout seul avec la population : Hameau 500 m, Village (100 hab.) 800 m, Bourg (500) 1,2 km, Ville (2 000) 2 km, Grande ville (10 000) 3 km autour de la mairie.", true, 12)
	_text("• Agrandir : acheter un carré voisin %s. Céder : rendre un carré vide." % BuildingSystem.format_money(cm.prix_case()), true, 12)
	if r.territoire:
		_text("• Bâtiments et zonage seulement sur le territoire. Voies, réseaux et lignes permis partout pour relier les villages.", true, 12)
	else:
		_text("• Réglage Admin : construction permise partout (le territoire sert aux chiffres).", true, 12)
	_text("• Une seule caisse pour tous tes villages (Budget, M). Les élections se font au nom du premier village.", true, 12)


func _carte_village(vid: int, ids: Array) -> void:
	var v: Dictionary = cm.villages[vid]
	var s: Dictionary = cm.stats.get(vid, {})
	var col: Color = Communes.COULEURS[int(v.couleur) % Communes.COULEURS.size()]
	var palier := String(ReglagesPartie.PALIERS[int(s.get("palier", 0))].nom)
	_section("%s%s" % [v.nom, "  ·  chef-lieu" if vid == cm.principal() else ""], col)
	var dr := String(v.get("drapeau", ""))
	var fh := HBoxContainer.new()
	fh.add_theme_constant_override("separation", 6)
	var ic := Drapeaux.icone(dr, 16) if dr != "" else null
	if ic:
		var tr := TextureRect.new()
		tr.texture = ic
		tr.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		fh.add_child(tr)
	var fl := _text("Drapeau : " + Drapeaux.nom(dr), true, 12)
	fl.reparent(fh)
	fl.custom_minimum_size = Vector2.ZERO
	fl.autowrap_mode = TextServer.AUTOWRAP_OFF
	_button("Changer…", "Choisir le drapeau hissé sur la mairie", func() -> void: changer_drapeau(vid), fh)
	_body.add_child(fh)
	if _renommer == vid:
		var h := HBoxContainer.new()
		var e := LineEdit.new()
		e.text = String(v.nom)
		e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(e)
		var ok := func() -> void:
			cm.renommer(vid, e.text)
			_renommer = -1
			refresh()
		e.text_submitted.connect(func(_t: String) -> void: ok.call())
		_button("OK", "Valider le nom", ok, h)
		_body.add_child(h)
		e.grab_focus.call_deferred()
	var mairie := "sans mairie"
	if cm.buildings.buildings.has(int(v.bid)):
		mairie = String(BuildingCatalog.get_type(String(cm.buildings.buildings[int(v.bid)].t)).name)
		if cm.buildings.en_chantier(int(v.bid)):
			mairie += " (en chantier)"
	_text("%s · %s · %s" % [palier, _n(int(s.get("hab", 0)), "habitant"), mairie])
	_text("Territoire : %d ha (%s) · rayon automatique %s m" % [int(s.get("ha", 0)), _km2(int(s.get("ha", 0))),
		str(roundi(float(v.rayon)))], true, 12)
	var nann := (v.annexes as Array).size()
	_text("%s · %s · %s%s" % [_n(int(s.get("batiments", 0)), "bâtiment"), _n(int(s.get("logements", 0)), "logement"),
		_n(int(s.get("emplois", 0)), "emploi"), (" · " + _n(nann, "mairie annexe", "mairies annexes")) if nann > 0 else ""], true, 12)
	var p := int(s.get("palier", 0))
	if p + 1 < ReglagesPartie.PALIERS.size():
		var nxt: Dictionary = ReglagesPartie.PALIERS[p + 1]
		_text("Prochain agrandissement : « %s » à %d habitants (%s m)." % [nxt.nom, int(nxt.habitants), str(roundi(float(Communes.RAYONS[p + 1])))], true, 12)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	_body.add_child(row)
	var c: Vector2 = v.c
	_button("Aller", "Centrer la vue sur la mairie", func() -> void: focus_requested.emit(Vector3(c.x, 0, c.y)), row)
	_button("Renommer", "Changer le nom du village", func() -> void:
		_renommer = vid
		refresh(), row)
	var ag := _button("Agrandir", "Acheter des carrés voisins (%s le carré)" % BuildingSystem.format_money(cm.prix_case()), func() -> void:
		cm.set_outil("" if cm.outil == "annexer" and cm.outil_village == vid else "annexer", vid)
		refresh(), row)
	ag.toggle_mode = true
	ag.button_pressed = cm.outil == "annexer" and cm.outil_village == vid
	var ce := _button("Céder", "Rendre des carrés vides du territoire", func() -> void:
		cm.set_outil("" if cm.outil == "ceder" and cm.outil_village == vid else "ceder", vid)
		refresh(), row)
	ce.toggle_mode = true
	ce.button_pressed = cm.outil == "ceder" and cm.outil_village == vid
	for other in ids:
		if int(other) > vid and cm.voisins(vid, int(other)):
			var o := int(other)
			_button("Fusionner avec %s" % cm.villages[o].nom, "Les deux villages se touchent : n'en faire qu'une commune. Le plus peuplé garde son nom et sa mairie.", func() -> void:
				cm.fusionner(vid, o)
				refresh())


static func _n(n: int, un: String, plusieurs := "") -> String:
	return "%d %s" % [n, un if n <= 1 else (plusieurs if plusieurs != "" else un + "s")]


static func _km2(ha: int) -> String:
	return "%.2f km²" % (ha / 100.0)
