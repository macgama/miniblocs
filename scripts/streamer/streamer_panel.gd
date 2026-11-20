class_name StreamerPanel
extends CanvasLayer
## Panneau « Mode streamer » (Maj+F11, menu Infos) et encart du vote à l'écran.
##
## Le panneau règle le mode (chaîne Twitch, rythme des votes, catégories,
## noms d'habitants) ; l'encart, en haut à gauche, montre le vote en cours aux
## spectateurs du live, puis le résultat avec Annuler / Appliquer pour le streamer.

signal focus_requested(pos: Vector3)

const W := 400.0
const H := 560.0
const VERT := Color("7bd389")
const ROUGE := Color("ff8c8c")
const VIOLET := Color("a970ff")
## Distance du bas de l'écran à l'encart du vote.
const ENCART_BAS := 134.0

var ms: ModeStreamer
var _panel: PanelContainer
var _body: VBoxContainer
var _scroll: ScrollContainer
var _encart: PanelContainer
var _encart_box: VBoxContainer
var _tick := 0.0
var _chaine_edit: LineEdit


func setup(m: ModeStreamer) -> void:
	ms = m
	_build()
	ms.vote_change.connect(_maj_encart)
	ms.changed.connect(func() -> void:
		if is_open() and not _occupe():
			refresh())
	_maj_encart()


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
	icon.texture = Icones.get_icon("direct", 22, VIOLET)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	head.add_child(icon)
	var title := Label.new()
	title.text = "Mode streamer (chat Twitch)"
	title.add_theme_font_size_override("font_size", 16)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var x := UiStyle.icon_button("fermer", "Fermer", "Maj+F11", 18, 32)
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
	# Encart du vote (toujours visible pendant un vote, même panneau fermé).
	_encart = PanelContainer.new()
	# En bas à gauche, au-dessus de l'encart d'état : le haut à gauche est
	# pris par les objectifs, et les streamers y placent rarement leur webcam.
	_encart.custom_minimum_size = Vector2(330, 0)
	UiStyle.style_panel(_encart, 0.9, 10, 10)
	_encart.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_encart)
	_encart_box = VBoxContainer.new()
	_encart_box.add_theme_constant_override("separation", 3)
	_encart.add_child(_encart_box)


func is_open() -> bool:
	return _panel.visible


func set_open(on: bool) -> void:
	_panel.visible = on
	if on:
		refresh()


func toggle() -> void:
	set_open(not _panel.visible)


func _input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.keycode == KEY_F11 and k.shift_pressed and not k.ctrl_pressed and not k.alt_pressed:
		toggle()
		get_viewport().set_input_as_handled()


var _tick_panneau := 0.0


func _process(delta: float) -> void:
	_tick += delta
	_tick_panneau += delta
	if _tick < 0.5:
		return
	_tick = 0.0
	_maj_encart()
	if is_open() and _tick_panneau >= 3.0 and not _occupe():
		_tick_panneau = 0.0
		var keep := _scroll.scroll_vertical
		refresh()
		_scroll.set_deferred("scroll_vertical", keep)


## Le joueur est en train de régler quelque chose : on ne reconstruit pas le panneau.
func _occupe() -> bool:
	if _chaine_edit != null and _chaine_edit.has_focus():
		return true
	for c in _body.find_children("*", "Button", true, false):
		if c is ChoixVisuel and (c as ChoixVisuel).est_ouvert():
			return true
	return _panel.get_global_rect().has_point(_panel.get_global_mouse_position())


static func minutes(s: float) -> String:
	var t := int(ceil(s))
	return "%d:%02d" % [t / 60, t % 60]


# --- Encart --------------------------------------------------------------------------------

func _maj_encart() -> void:
	if _encart_box == null:
		return
	for c in _encart_box.get_children():
		_encart_box.remove_child(c)
		c.queue_free()
	if ms == null or not ms.actif:
		_encart.visible = false
		return
	_encart.visible = true
	if ms.vote.is_empty():
		var l := _lab("", 13, UiStyle.TEXT_DIM)
		var bits := []
		if ms.intervalle > 0:
			bits.append("Prochain vote du chat dans %s" % minutes(ms.secondes_avant_vote()))
		else:
			bits.append("Votes du chat à la demande")
		if ms.noms_habitants:
			bits.append("tapez !habitant pour habiter la ville")
		l.text = " · ".join(bits)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(310, 0)
		_encart_box.add_child(l)
		_placer_encart()
		return
	var ouvert := String(ms.vote.etat) == "ouvert"
	var head := HBoxContainer.new()
	_encart_box.add_child(head)
	var ic := TextureRect.new()
	ic.texture = Icones.get_icon("direct", 18, VIOLET)
	ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	head.add_child(ic)
	var t := _lab("Le chat vote !" if ouvert else "Le chat a choisi", 15, UiStyle.ACCENT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(_lab(minutes(ms.secondes_restantes()), 15, UiStyle.TEXT))
	var c := ms.decompte()
	var total := 0
	for v in c:
		total += int(v)
	var opts: Array = ms.vote.options
	for i in opts.size():
		var id := String(opts[i])
		var gagne := not ouvert and i == int(ms.vote.gagnant)
		var row := HBoxContainer.new()
		_encart_box.add_child(row)
		var oi := TextureRect.new()
		oi.texture = Icones.get_icon(String(ModeStreamer.ACTIONS[id].icone), 16, UiStyle.ACCENT if gagne else UiStyle.TEXT)
		oi.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		row.add_child(oi)
		var nl := _lab("%d · %s" % [i + 1, ModeStreamer.nom_action(id)], 13, UiStyle.ACCENT if gagne else (UiStyle.TEXT if ouvert else UiStyle.TEXT_DIM))
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nl.clip_text = true
		row.add_child(nl)
		row.add_child(_lab("%d" % int(c[i]), 13, UiStyle.TEXT))
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(310, 6)
		bar.max_value = maxi(total, 1)
		bar.value = int(c[i])
		var fill := StyleBoxFlat.new()
		fill.bg_color = UiStyle.ACCENT if gagne else VIOLET
		fill.set_corner_radius_all(3)
		bar.add_theme_stylebox_override("fill", fill)
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(1, 1, 1, 0.08)
		bg.set_corner_radius_all(3)
		bar.add_theme_stylebox_override("background", bg)
		_encart_box.add_child(bar)
	if ouvert:
		_encart_box.add_child(_lab("Tapez 1, 2 ou 3 dans le chat · %d voix" % total, 12, UiStyle.TEXT_DIM))
		var b := Button.new()
		b.text = "Clore le vote"
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func() -> void: ms.clore_maintenant())
		_encart_box.add_child(b)
	else:
		_encart_box.add_child(_lab("S'applique dans %s, sauf veto du maire." % minutes(ms.secondes_restantes()), 12, UiStyle.TEXT_DIM))
		var rowb := HBoxContainer.new()
		_encart_box.add_child(rowb)
		var veto := Button.new()
		veto.text = "Veto"
		veto.focus_mode = Control.FOCUS_NONE
		veto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		veto.pressed.connect(func() -> void: ms.annuler())
		rowb.add_child(veto)
		var go := Button.new()
		go.text = "Appliquer"
		go.focus_mode = Control.FOCUS_NONE
		go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		go.pressed.connect(func() -> void: ms.appliquer_resultat())
		rowb.add_child(go)
	_placer_encart()


## Bas de l'encart calé à ENCART_BAS du bas de l'écran, quelle que soit sa hauteur.
func _placer_encart() -> void:
	_encart.reset_size()
	var zone := _encart.get_parent_area_size()
	_encart.position = Vector2(12.0, zone.y - ENCART_BAS - _encart.get_combined_minimum_size().y)


# --- Panneau -------------------------------------------------------------------------------

func refresh() -> void:
	if ms == null:
		return
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	_chaine_edit = null
	var etat := ms.etat_texte()
	_body.add_child(_lab("État : " + etat, 14, VERT if ms.chat.est_connecte() or (ms.simulation and ms.actif) else (ROUGE if ms.chat.etat == "erreur" else UiStyle.TEXT)))
	var actif := CheckButton.new()
	actif.text = "Activer le mode streamer"
	actif.button_pressed = ms.actif
	actif.focus_mode = Control.FOCUS_NONE
	actif.toggled.connect(func(on: bool) -> void:
		ms.activer(on, _chaine_edit.text if _chaine_edit != null else "")
		refresh())
	_body.add_child(actif)
	_body.add_child(_titre("Chaîne Twitch"))
	var row := HBoxContainer.new()
	_body.add_child(row)
	_chaine_edit = LineEdit.new()
	_chaine_edit.placeholder_text = "nom de la chaîne ou lien twitch.tv/…"
	_chaine_edit.text = ms.chaine
	_chaine_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_chaine_edit)
	var co := Button.new()
	co.text = "Se connecter" if not ms.chat.est_connecte() else "Reconnecter"
	co.focus_mode = Control.FOCUS_NONE
	co.pressed.connect(func() -> void:
		ms.activer(true, _chaine_edit.text)
		refresh())
	row.add_child(co)
	var aide := _lab("Lecture seule et anonyme : aucun compte ni clé. Le jeu lit le chat, il n'y écrit jamais.", 12, UiStyle.TEXT_DIM)
	aide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(aide)
	if ms.partage():
		var mj := _lab("Carte partagée : les votes du chat sont réservés aux parties en solo.", 12, ROUGE)
		mj.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_body.add_child(mj)
	_body.add_child(_titre("Votes"))
	_body.add_child(_choix("Un vote toutes les", ModeStreamer.INTERVALLES, ms.intervalle, "min", func(v: int) -> void: ms.set_intervalle(v), "À la main"))
	_body.add_child(_choix("Durée d'un vote", ModeStreamer.DUREES, ms.duree, "s", func(v: int) -> void:
		ms.duree = v
		ms.enregistrer_reglages()))
	_body.add_child(_choix("Délai de veto", ModeStreamer.DELAIS_VETO, ms.delai_veto, "s", func(v: int) -> void:
		ms.delai_veto = v
		ms.enregistrer_reglages(), "Aucun"))
	for cat in ModeStreamer.CATEGORIES:
		var cb := CheckBox.new()
		cb.text = String(ModeStreamer.CATEGORIES[cat])
		cb.button_pressed = bool(ms.categories.get(cat, true))
		cb.focus_mode = Control.FOCUS_NONE
		var k: String = cat
		cb.toggled.connect(func(on: bool) -> void:
			ms.categories[k] = on
			ms.enregistrer_reglages())
		_body.add_child(cb)
	var mods := CheckBox.new()
	mods.text = "Le streamer et ses modos lancent un vote avec !vote"
	mods.button_pressed = ms.commande_vote_mods
	mods.focus_mode = Control.FOCUS_NONE
	mods.toggled.connect(func(on: bool) -> void:
		ms.commande_vote_mods = on
		ms.enregistrer_reglages())
	_body.add_child(mods)
	var rowv := HBoxContainer.new()
	_body.add_child(rowv)
	var lv := Button.new()
	lv.text = "Lancer un vote maintenant"
	lv.disabled = not ms.actif or not ms.vote.is_empty()
	lv.focus_mode = Control.FOCUS_NONE
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lv.pressed.connect(func() -> void:
		ms.lancer_vote()
		refresh())
	rowv.add_child(lv)
	var sim := Button.new()
	sim.text = "Arrêter le faux chat" if ms.simulation else "Simuler le chat"
	sim.tooltip_text = "Des spectateurs imaginaires votent et demandent à habiter la ville : pour essayer sans Twitch."
	sim.disabled = not ms.actif
	sim.focus_mode = Control.FOCUS_NONE
	sim.pressed.connect(func() -> void:
		ms.simuler(not ms.simulation)
		refresh())
	rowv.add_child(sim)
	_body.add_child(_titre("Habitants du chat"))
	var nh := CheckBox.new()
	nh.text = "« !habitant » donne son pseudo au prochain habitant"
	nh.button_pressed = ms.noms_habitants
	nh.focus_mode = Control.FOCUS_NONE
	nh.toggled.connect(func(on: bool) -> void:
		ms.noms_habitants = on
		ms.enregistrer_reglages())
	_body.add_child(nh)
	_body.add_child(_lab("En attente d'un logement : %d pseudo%s%s" % [ms.file_noms.size(), "" if ms.file_noms.size() < 2 else "s",
		"" if ms.file_noms.is_empty() else " (" + ", ".join(ms.file_noms.slice(0, 6)) + ("…" if ms.file_noms.size() > 6 else "") + ")"], 12, UiStyle.TEXT_DIM))
	var liste := ms.liste_habitants()
	if liste.is_empty():
		_body.add_child(_lab("Aucun habitant du chat pour l'instant.", 12, UiStyle.TEXT_DIM))
	for h in liste.slice(0, 40):
		var r := HBoxContainer.new()
		_body.add_child(r)
		var l := _lab("%s · %d ans · %s" % [h.nom, int(h.age), h.logement], 12, UiStyle.TEXT)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.clip_text = true
		r.add_child(l)
		if int(h.bid) >= 0 and ms.evenements != null:
			var go := UiStyle.icon_button("oeil", "Aller voir", "", 14, 26)
			var bid := int(h.bid)
			go.pressed.connect(func() -> void: focus_requested.emit(ms.evenements.building_pos(bid)))
			r.add_child(go)
	if not ms.historique.is_empty():
		_body.add_child(_titre("Derniers votes (%d en tout)" % ms.votes_faits))
		for d in ms.historique.slice(0, 8):
			_body.add_child(_lab("%s · %d voix sur %d%s" % [ModeStreamer.nom_action(String(d.action)), int(d.voix), int(d.total),
				"" if bool(d.get("ok", true)) else " (sans effet)"], 12, UiStyle.TEXT_DIM))


func _choix(texte: String, valeurs: Array, actuel: int, unite: String, cb: Callable, zero := "") -> Control:
	var row := HBoxContainer.new()
	var l := _lab(texte, 13, UiStyle.TEXT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var ob := ChoixVisuel.new()
	ob.gradue = 1
	ob.focus_mode = Control.FOCUS_NONE
	for i in valeurs.size():
		var v := int(valeurs[i])
		ob.add_item(zero if v == 0 and zero != "" else "%d %s" % [v, unite], i)
		if v == actuel:
			ob.select(i)
	if valeurs.has(0) == false and zero != "":
		ob.add_item(zero, valeurs.size())
		if actuel == 0:
			ob.select(valeurs.size())
	ob.item_selected.connect(func(i: int) -> void: cb.call(int(valeurs[i]) if i < valeurs.size() else 0))
	row.add_child(ob)
	return row


func _titre(t: String) -> Label:
	var l := _lab(t, 14, UiStyle.ACCENT)
	return l


func _lab(t: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l
