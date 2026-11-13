class_name FondateursPanel
extends CanvasLayer
## Panneau « Fondateurs et chantiers » (Maj+H) : la réserve des fondateurs,
## les chantiers en cours et leurs équipes (pause, passer en premier), et
## l'affectation des fondateurs à n'importe quel métier des bâtiments finis.

signal focus_requested(pos: Vector3)

const W := 380.0
const H := 560.0
## Bâtiments à postes libres montrés au plus (les plus proches du campement).
const MAX_POSTES := 25

var fd: Fondateurs
var _panel: PanelContainer
var _body: VBoxContainer
var _scroll: ScrollContainer
var _tick := 0.0
## Métier choisi pour chaque bâtiment (bid -> clé de métier, "" = au choix du bâtiment).
var _metier := {}


func setup(f: Fondateurs) -> void:
	fd = f
	_build()
	fd.changed.connect(func() -> void:
		if is_open():
			_refresh_keep())


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
	icon.texture = Icones.get_icon("emploi", 22, UiStyle.ACCENT)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	head.add_child(icon)
	var title := Label.new()
	title.text = "Fondateurs et chantiers"
	title.add_theme_font_size_override("font_size", 16)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var x := UiStyle.icon_button("fermer", "Fermer", "Maj+H", 18, 32)
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


func is_open() -> bool:
	return _panel.visible


func set_open(on: bool) -> void:
	_panel.visible = on
	if on:
		refresh()


func toggle() -> void:
	set_open(not _panel.visible)


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.physical_keycode == KEY_H and k.shift_pressed and not k.ctrl_pressed and not k.alt_pressed:
		toggle()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not is_open():
		return
	_tick += delta
	if _tick >= 2.0:
		_tick = 0.0
		_refresh_keep()


func _refresh_keep() -> void:
	var keep := _scroll.scroll_vertical
	refresh()
	_scroll.set_deferred("scroll_vertical", keep)


# --- Contenu -----------------------------------------------------------------------------

func _text(t: String, dim := false, size := 13, parent: Control = null) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(W - 30, 0)
	l.add_theme_font_size_override("font_size", size)
	if dim:
		l.add_theme_color_override("font_color", Color(1, 1, 1, 0.65))
	(parent if parent != null else _body).add_child(l)
	return l


func _section(t: String, col := UiStyle.ACCENT) -> void:
	_body.add_child(HSeparator.new())
	var l := _text(t, false, 15)
	l.add_theme_color_override("font_color", col)


func _button(t: String, tip: String, f: Callable, parent: Control = null) -> Button:
	var b := Button.new()
	b.text = t
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 12)
	b.pressed.connect(f)
	(parent if parent != null else _body).add_child(b)
	return b


func _row() -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	_body.add_child(h)
	return h


func refresh() -> void:
	if fd == null:
		return
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	if not fd.arrives:
		_section("Pas encore de fondateurs")
		if ReglagesPartie.actuel.fondateurs > 0:
			_text("Ils arrivent avec ton premier village : pose sa Maison de commune (Maj+M). %d fondateurs planteront leur campement à côté et construiront les premiers bâtiments." % ReglagesPartie.actuel.fondateurs)
		else:
			_text("Réglage Admin (F10) : la partie commence sans fondateurs.", true)
		_regles()
		return
	fd.repartir()
	_resume()
	_chantiers()
	_affecter()
	_regles()


func _resume() -> void:
	var viv := fd.vivants()
	var tente := fd.au_campement()
	var o := fd.ouvriers()
	_section("Les fondateurs")
	_text("%s · %d sous la tente · %d logés dans une maison" % [_n(viv.size(), "fondateur"), tente, maxi(0, viv.size() - tente)])
	_text("Ouvriers pour les chantiers : %d (fondateurs %d, entreprises du bâtiment %d) · %s" % [fd.total_ouvriers,
		int(o.fondateurs), int(o.entreprises), "%d sans chantier" % fd.libres if fd.libres > 0 else "tous au travail"], true, 12)
	if not fd.regle_active():
		_text("Réglage Admin : les chantiers n'ont pas besoin d'ouvriers (ou construction instantanée).", true, 12)
	if tente > 0:
		if fd.vivres >= tente:
			_text("Vivres : encore %d jours pour %d personnes sous la tente." % [floori(fd.vivres / tente), tente], false, 12)
		elif fd.affame:
			var l := _text("⚠ Plus de vivres et pas assez d'argent pour le ravitaillement : les fondateurs ont faim.", false, 12)
			l.add_theme_color_override("font_color", Color("ff8c69"))
		else:
			_text("Vivres épuisés : ravitaillement payé par la caisse, %s par jour." % BuildingSystem.format_money(roundi(tente * Fondateurs.RATION)), false, 12)
	if fd.ravitaillement > 0:
		_text("Ravitaillement payé depuis la fin des vivres : %s." % BuildingSystem.format_money(fd.ravitaillement), true, 12)
	if fd.camp >= 0 and fd.buildings.buildings.has(fd.camp):
		var r := _row()
		_button("Voir le campement", "Centrer la vue sur le campement", func() -> void:
			focus_requested.emit(fd.population.building_pos(fd.camp)), r)
	var sans := fd.sans_emploi()
	if not sans.is_empty():
		var r2 := _row()
		var ls := _text("%s sans emploi" % _n(sans.size(), "fondateur"), true, 12, r2)
		ls.custom_minimum_size = Vector2(170, 0)
		if fd.camp >= 0:
			_button("Rappeler au chantier", "Les remettre à la base de chantier du campement", func() -> void:
				fd.rappeler(-1, sans.size()), r2)


func _chantiers() -> void:
	var liste := fd.liste_chantiers()
	_section("Chantiers en cours (%d)" % liste.size())
	if liste.is_empty():
		_text("Aucun chantier : pose des bâtiments ou des voies. Les ouvriers vont aux chantiers dans l'ordre de cette liste.", true, 12)
		return
	_text("Les ouvriers vont aux chantiers dans l'ordre de la liste, chacun jusqu'à son équipe complète. Mets en pause ou passe en premier pour doser.", true, 12)
	for ch in liste:
		var cle := String(ch.cle)
		var eq := fd.equipe_de(cle)
		var etat := ""
		if bool(ch.pause):
			etat = "en pause"
		elif not fd.regle_active():
			etat = "équipe complète"
		elif int(eq[0]) <= 0:
			etat = "en attente d'ouvriers"
		else:
			etat = "%d / %d ouvriers" % [int(eq[0]), int(eq[1])]
		var l := _text("%s · %d %% · %s" % [ch.nom, floori(float(ch.av) * 100.0), etat], false, 12)
		if bool(ch.pause) or (fd.regle_active() and int(eq[0]) <= 0):
			l.add_theme_color_override("font_color", Color("ffb36b"))
		var r := _row()
		_button("Reprendre" if bool(ch.pause) else "Pause", "Mettre en pause libère ses ouvriers pour les autres chantiers",
			func() -> void: fd.basculer_pause(cle), r)
		_button("En premier", "Ce chantier reçoit ses ouvriers avant les autres", func() -> void: fd.prioriser(cle), r)
		var bid := int(ch.bid)
		if bid >= 0:
			_button("Aller", "Centrer la vue sur le chantier", func() -> void:
				if fd.buildings.buildings.has(bid):
					var rect := fd.buildings._rect_of(fd.buildings.buildings[bid])
					focus_requested.emit(BuildingSystem.rect_center(rect)), r)


func _affecter() -> void:
	var pop := fd.population
	var dispo := fd.au_chantier().size()
	_section("Affecter les fondateurs")
	_text("%s à la base de chantier. Ils peuvent prendre n'importe quel métier : choisis le poste, puis envoie-en 1 ou 5." % _n(dispo, "fondateur disponible", "fondateurs disponibles"), true, 12)
	# Bâtiments où travaillent déjà des fondateurs : on peut les rappeler.
	var ou := {}
	for pid in fd.vivants():
		var j := int(pop.persons[pid].job)
		if j >= 0 and j != fd.camp and pop.known.has(j):
			ou[j] = int(ou.get(j, 0)) + 1
	if not ou.is_empty():
		_text("Fondateurs déjà affectés :", false, 12)
		for bid in ou:
			var r := _row()
			var lb := _text("%s : %d" % [pop.building_name(bid), int(ou[bid])], false, 12, r)
			lb.custom_minimum_size = Vector2(200, 0)
			var b2 := int(bid)
			_button("Rappeler 1", "Retour à la base de chantier", func() -> void: fd.rappeler(b2, 1), r)
			_button("Tous", "Tous retournent à la base de chantier", func() -> void: fd.rappeler(b2, 1000), r)
	var postes := fd.postes_libres()
	if postes.is_empty():
		_text("Aucun poste libre pour l'instant : les bâtiments finis (ferme, commerces, école…) en proposent.", true, 12)
		return
	var o := pop.building_pos(fd.camp) if fd.camp >= 0 else Vector3.ZERO
	postes.sort_custom(func(a: int, b: int) -> bool:
		return o.distance_squared_to(pop.building_pos(a)) < o.distance_squared_to(pop.building_pos(b)))
	_text("Postes libres :", false, 12)
	for i in mini(postes.size(), MAX_POSTES):
		var bid := int(postes[i])
		var t := String(pop.known[bid].t)
		_text("%s · %s" % [pop.building_name(bid), _n(pop.free_jobs(bid), "poste libre", "postes libres")], false, 12)
		var r := _row()
		var choix := OptionButton.new()
		choix.focus_mode = Control.FOCUS_NONE
		choix.add_theme_font_size_override("font_size", 12)
		choix.add_item("Métier au choix du bâtiment")
		choix.set_item_metadata(0, "")
		var vus := {}
		for e in Metiers.jobs_for(t):
			var m := String(e[0])
			if vus.has(m):
				continue
			vus[m] = true
			choix.add_item(String(Metiers.job(m).name))
			choix.set_item_metadata(choix.item_count - 1, m)
		for k in Effectif.requis_de(t):
			if not vus.has(String(k)):
				choix.add_item(String(Metiers.job(String(k)).name))
				choix.set_item_metadata(choix.item_count - 1, String(k))
		for j in choix.item_count:
			if String(choix.get_item_metadata(j)) == String(_metier.get(bid, "")):
				choix.select(j)
		choix.item_selected.connect(func(idx: int) -> void: _metier[bid] = String(choix.get_item_metadata(idx)))
		choix.custom_minimum_size = Vector2(190, 0)
		r.add_child(choix)
		var b1 := _button("+1", "Envoyer un fondateur", func() -> void: fd.affecter(bid, 1, String(_metier.get(bid, ""))), r)
		var b5 := _button("+5", "Envoyer cinq fondateurs", func() -> void: fd.affecter(bid, 5, String(_metier.get(bid, ""))), r)
		b1.disabled = dispo <= 0
		b5.disabled = dispo <= 0
	if postes.size() > MAX_POSTES:
		_text("… et %d autres bâtiments plus loin." % (postes.size() - MAX_POSTES), true, 12)


func _regles() -> void:
	_section("Règles")
	var r := ReglagesPartie.actuel
	_text("• %d fondateurs arrivent avec le premier village (réglage Admin F10) et campent à côté de la Maison de commune." % r.fondateurs, true, 12)
	_text("• Chaque chantier veut une équipe complète (maison ≈ 8 à 10 ouvriers, Maison de commune ≈ 10, voie 3 à 16) : avec moins d'ouvriers, il avance moins vite ; sans ouvriers, il attend.", true, 12)
	_text("• Plus tard, les entreprises du bâtiment (Construire → Industrie) emploient des habitants qui font avancer les chantiers.", true, 12)
	_text("• Sous la tente, ni loyer ni courses : vivres pour %d jours, puis ravitaillement payé par la caisse (%s par personne et par jour)." % [
		r.vivres_jours, BuildingSystem.format_money(roundi(Fondateurs.RATION))], true, 12)
	_text("• Dès qu'une maison est finie, des fondateurs y emménagent avant tout nouvel arrivant. Logés, ils comptent comme habitants.", true, 12)


static func _n(n: int, un: String, plusieurs := "") -> String:
	return "%d %s" % [n, un if n <= 1 else (plusieurs if plusieurs != "" else un + "s")]
