class_name ImmobilierPanel
extends CanvasLayer
## Panneau « Immobilier » (F11, menu Ville) : marché de chaque ville (prix,
## loyers, vacance, taux d'effort), promoteurs et permis de construire,
## secteurs qui s'embourgeoisent ou se paupérisent, bidonvilles et ce que le
## maire peut y faire, règles (permis, encadrement des loyers, quota social).

signal carte_requested
signal lieu_requested(p: Vector3)

const W := 400.0
const H := 560.0
const VERT := Color("7bd389")
const ROUGE := Color("ff8c8c")
const BLEU := Color("8ab4ff")

var immo: Immobilier
var view := "marche"
var _panel: PanelContainer
var _title: Label
var _body: VBoxContainer
var _scroll: ScrollContainer
var _tick := 0.0


func setup(i: Immobilier) -> void:
	immo = i
	_build()
	immo.changed.connect(func() -> void:
		if is_open():
			_rafraichir_garde())


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
	icon.texture = Icones.get_icon("logement", 22, UiStyle.ACCENT)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	head.add_child(icon)
	_title = Label.new()
	_title.text = "Immobilier"
	_title.add_theme_font_size_override("font_size", 16)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	var x := UiStyle.icon_button("fermer", "Fermer", "F11", 18, 32)
	x.pressed.connect(func() -> void: set_open(false))
	head.add_child(x)
	var tabs := HBoxContainer.new()
	outer.add_child(tabs)
	for spec in [["Marché", "marche"], ["Promoteurs", "promoteurs"], ["Quartiers", "quartiers"], ["Bidonvilles", "bidonvilles"]]:
		var b := Button.new()
		b.text = spec[0]
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 12)
		var v: String = spec[1]
		b.pressed.connect(func() -> void: show_view(v))
		tabs.add_child(b)
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(W, H)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(_scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 3)
	_scroll.add_child(_body)


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
	if k and k.pressed and not k.echo and k.physical_keycode == KEY_F11 and not k.shift_pressed and not k.ctrl_pressed and not k.alt_pressed:
		if get_viewport().gui_get_focus_owner() is LineEdit:
			return
		toggle()
		get_viewport().set_input_as_handled()


func show_view(v: String) -> void:
	view = v
	refresh()
	_scroll.scroll_vertical = 0


func _process(delta: float) -> void:
	if not is_open():
		return
	_tick += delta
	if _tick >= 3.0:
		_tick = 0.0
		_rafraichir_garde()


func _rafraichir_garde() -> void:
	var keep := _scroll.scroll_vertical
	refresh()
	_scroll.set_deferred("scroll_vertical", keep)


func refresh() -> void:
	if immo == null or immo.population == null:
		return
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	match view:
		"promoteurs": _view_promoteurs()
		"quartiers": _view_quartiers()
		"bidonvilles": _view_bidonvilles()
		_: _view_marche()


# --- Petits outils ---------------------------------------------------------------------

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


func _section(t: String) -> void:
	_body.add_child(HSeparator.new())
	var l := _text(t, false, 15)
	l.add_theme_color_override("font_color", UiStyle.ACCENT)


func _button(t: String, cb: Callable, tip := "", parent: Control = null) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = tip
	b.add_theme_font_size_override("font_size", 12)
	b.pressed.connect(cb)
	(parent if parent != null else _body).add_child(b)
	return b


func _row() -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 6)
	_body.add_child(r)
	return r


## Choix entre plusieurs valeurs (boutons, celui en cours en couleur).
func _choix(titre: String, noms: Array, actuel: int, cb: Callable, actif := true) -> void:
	_text(titre, false, 13)
	var r := _row()
	for i in noms.size():
		var b := Button.new()
		b.text = String(noms[i])
		b.focus_mode = Control.FOCUS_NONE
		b.toggle_mode = true
		b.button_pressed = i == actuel
		b.disabled = not actif
		b.add_theme_font_size_override("font_size", 12)
		var v := i
		b.pressed.connect(func() -> void:
			cb.call(v)
			refresh())
		r.add_child(b)


static func _pct(v: float, signe := false) -> String:
	var p := roundi(v * 100.0)
	return ("%+d %%" if signe else "%d %%") % p


static func _eur(v: float) -> String:
	return BuildingSystem.format_money(roundi(v))


## Villes à montrer : [vid, nom] (une seule entrée « la ville » sans village).
func _villes() -> Array:
	var out := []
	if Communes.instance != null and not Communes.instance.villages.is_empty():
		for vid in Communes.instance.villages:
			out.append([int(vid), String(Communes.instance.villages[vid].nom)])
	else:
		out.append([-1, Avis.ville()])
	return out


# --- Marché ---------------------------------------------------------------------------------

func _view_marche() -> void:
	_title.text = "Immobilier · marché"
	if immo.population.households.is_empty():
		_text("Personne n'habite encore la ville. Les loyers et les prix apparaîtront avec les premiers foyers.", true)
	for v in _villes():
		var vid := int(v[0])
		var b := immo.bilan(vid)
		if int(b.foyers) + int(b.precaires) == 0 and _villes().size() > 1:
			continue
		_section(String(v[1]))
		var ind := float(b.indice)
		var tendance := "stable"
		var h: Array = immo.histo.get(vid, [])
		if h.size() >= 2:
			var d := float(h[h.size() - 1][1]) / maxf(0.1, float(h[maxi(0, h.size() - 13)][1])) - 1.0
			tendance = ("en hausse (%s sur un an)" % _pct(d, true)) if d > 0.03 else (("en baisse (%s sur un an)" % _pct(d, true)) if d < -0.03 else "stable")
		_text("Indice des prix : %.2f · %s" % [ind, tendance], false, 14)
		_text("Prix moyen : %s/m² · loyer moyen : %s par mois" % [_eur(float(b.prix_m2)).replace(" €", " €"), _eur(float(b.loyer))])
		var vac := float(b.vacance)
		var etat := "marché tendu : peu de logements libres, les prix montent" if vac < 0.02 else ("marché détendu : beaucoup de logements vides" if vac > 0.1 else "marché équilibré")
		_text("Logements vides : %s (%s)" % [_pct(vac), etat], true)
		var l := _text("Loyer moyen : %s des revenus · %d foyer%s paie%s trop cher (plus de 45 %%)" % [
			_pct(float(b.effort)), int(b.cher), "s" if int(b.cher) > 1 else "", "nt" if int(b.cher) > 1 else ""])
		l.add_theme_color_override("font_color", ROUGE if int(b.cher) > 0 else VERT)
		_text("Logements sociaux : %d · de standing : %d · baraques : %d (%d foyers)" % [int(b.sociaux), int(b.standing), int(b.baraques), int(b.precaires)], true)
		if h.size() >= 2:
			_courbe(h)
	_section("Règles du maire")
	var dec := Immobilier.decide(Communes.instance.principal() if Communes.instance != null and not Communes.instance.villages.is_empty() else -1)
	_choix("Encadrement des loyers (plafond selon la valeur du quartier)", Immobilier.ENCADREMENT_NOMS, immo.encadrement,
		func(i: int) -> void: immo.encadrement = i, dec)
	_text("Plus il est strict, moins les loyers font fuir les modestes… et moins les promoteurs construisent.", true, 11)
	_choix("Logements sociaux imposés aux promoteurs", ["Aucun", "20 %", "25 %", "30 %"], immo.quota,
		func(i: int) -> void: immo.quota = i, dec)
	_choix("Permis de construire des promoteurs", Immobilier.PERMIS_NOMS, immo.permis,
		func(i: int) -> void: immo.permis = i, dec)
	if not dec:
		_text("Tu n'es plus maire : le conseil élu applique ses règles.", true, 11)
	var sociaux := ImmobilierTypes.sociaux_disponibles()
	if not sociaux.is_empty():
		_text("Logements sociaux à bâtir à cette époque : %s (B → Logement)." % ", ".join(sociaux.map(func(id: String) -> String: return String(BuildingCatalog.get_type(id).name))), true, 11)
	else:
		_text("Pas encore de logements sociaux à cette époque : la première cité ouvrière date de 1853.", true, 11)
	_button("Carte des quartiers qui changent", func() -> void: carte_requested.emit())
	if not immo.journal.is_empty():
		_section("Dernières nouvelles")
		for i in range(immo.journal.size() - 1, maxi(-1, immo.journal.size() - 9), -1):
			_text("· " + String(immo.journal[i].texte), true, 12)


## Petite courbe de l'indice des prix (une barre par mois).
func _courbe(h: Array) -> void:
	var box := Control.new()
	box.custom_minimum_size = Vector2(W - 30, 44)
	_body.add_child(box)
	var n := mini(h.size(), 36)
	var bw := (W - 40.0) / float(n)
	for i in n:
		var e: Array = h[h.size() - n + i]
		var v := clampf((float(e[1]) - Immobilier.INDICE_MIN) / (Immobilier.INDICE_MAX - Immobilier.INDICE_MIN), 0.03, 1.0)
		var r := ColorRect.new()
		r.color = BLEU if float(e[1]) >= 1.0 else Color("f4a261")
		r.size = Vector2(maxf(2.0, bw - 2.0), 40.0 * v)
		r.position = Vector2(i * bw, 42.0 - 40.0 * v)
		r.tooltip_text = "Indice %.2f · loyer moyen %s" % [float(e[1]), _eur(float(e[2]))]
		r.mouse_filter = Control.MOUSE_FILTER_PASS
		box.add_child(r)


# --- Promoteurs ------------------------------------------------------------------------------

func _view_promoteurs() -> void:
	_title.text = "Immobilier · promoteurs"
	if not Immobilier.reglages_actifs():
		_text("Les promoteurs privés sont coupés dans les réglages de la partie (Admin, F10 → Immobilier).", true)
		return
	if not immo.demandes.is_empty():
		_section("Permis de construire à signer")
		for dm in immo.demandes:
			var d: Dictionary = dm
			_text("%s · %s" % [immo.nom_promoteur(String(d.prom)), String(Immobilier.GENRES.get(String(d.genre), ""))], false, 13)
			var det := "%s · %d logement%s" % [String(d.lieu), int(d.log), "s" if int(d.log) > 1 else ""]
			if int(d.get("soc", 0)) > 0:
				det += " dont %d sociaux" % int(d.soc)
			det += " · taxe d'aménagement : %s" % _eur(float(d.cout) * Immobilier.TAXE_AMENAGEMENT)
			if String(d.genre) == "renover":
				det += " · les loyers monteront de 30 %"
			elif String(d.genre) == "densifier":
				det += " · les habitants de la maison devront partir"
			_text(det, true, 12)
			var r := _row()
			var id := int(d.id)
			var ok := _button("Accorder", func() -> void: immo.accepter(id), "Le promoteur bâtit à ses frais ; la ville touche la taxe d'aménagement.", r)
			ok.add_theme_color_override("font_color", VERT)
			_button("Refuser", func() -> void: immo.refuser(id), "", r)
			var jours := 30 - (immo.jour() - int(d.jour))
			var reste := Label.new()
			reste.text = "%d j pour répondre" % maxi(0, jours)
			reste.add_theme_font_size_override("font_size", 11)
			reste.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
			r.add_child(reste)
	elif immo.permis == 1:
		_text("Aucune demande de permis en attente. Les promoteurs cherchent une affaire chaque semaine.", true)
	elif immo.permis == 0:
		_text("Permis libre : les promoteurs bâtissent sans demander.", true)
	else:
		_text("Permis gelés : les promoteurs attendent des jours meilleurs.", true)
	_section("Les sociétés")
	for p in Immobilier.PROMOTEURS:
		var st: Dictionary = immo.promoteurs.get(String(p.id), {})
		_text("%s — « %s »" % [String(p.nom), String(p.devise)], false, 13)
		_text("%s · %d projet%s, %d logements · caisse : %s" % [String(Immobilier.GENRES.get(String(p.genre), "")), int(st.get("projets", 0)),
			"s" if int(st.get("projets", 0)) > 1 else "", int(st.get("logements", 0)), _eur(float(st.get("caisse", 0.0)))], true, 12)
	_section("Ce qu'ils cherchent")
	_text("Immo Prestige : un quartier cher (terrain ×1,2 au moins) avec de la demande de logements.", true, 12)
	_text("Les Bâtisseurs Réunis : des maisons dans les quartiers moyens.", true, 12)
	_text("Béton & Fils : une maison du zonage sur un terrain très cher, à raser pour un immeuble.", true, 12)
	_text("Pierre & Rendement : un immeuble dans un quartier qui monte, à rénover en haut de gamme. C'est la gentrification.", true, 12)


# --- Quartiers ------------------------------------------------------------------------------

func _view_quartiers() -> void:
	_title.text = "Immobilier · quartiers"
	var liste := immo.secteurs_qui_changent()
	if liste.is_empty():
		_text("Il faut au moins deux relevés mensuels pour voir les quartiers changer. Reviens dans quelques mois de jeu.", true)
		return
	_text("Chaque secteur de 200 m garde l'histoire de ses prix et de ses habitants (un relevé par mois).", true, 12)
	_button("Voir la carte", func() -> void: carte_requested.emit())
	var vus := 0
	for e in liste:
		if vus >= 25:
			break
		vus += 1
		var st := String(e.statut)
		var titre := String(e.nom)
		var l := _text(titre, false, 13)
		if st == "embourgeoisement":
			l.add_theme_color_override("font_color", BLEU)
		elif st == "pauperisation":
			l.add_theme_color_override("font_color", ROUGE)
		var etat := "s'embourgeoise" if st == "embourgeoisement" else ("se paupérise" if st == "pauperisation" else "stable")
		var r := _row()
		var t := Label.new()
		t.text = "%s · prix %s · %d foyers, %s modestes" % [etat, _pct(float(e.evol), true), int(e.foyers), _pct(float(e.modestes))]
		t.add_theme_font_size_override("font_size", 12)
		t.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(t)
		var k: Vector2i = e.k
		var p := Vector3((k.x + 0.5) * Immobilier.SECTEUR, 0, (k.y + 0.5) * Immobilier.SECTEUR)
		_button("Aller", func() -> void: lieu_requested.emit(p), "Centrer la vue sur ce secteur", r)
	_section("Ce que ça change")
	_text("Un secteur qui s'embourgeoise : les loyers montent, les foyers modestes ont peur d'être chassés puis partent. L'encadrement des loyers et les logements sociaux les protègent.", true, 12)
	_text("Un secteur qui se paupérise : les immeubles s'usent plus vite, les habitants sont inquiets. Parcs, services et transports font remonter sa valeur.", true, 12)


# --- Bidonvilles ----------------------------------------------------------------------------

func _view_bidonvilles() -> void:
	_title.text = "Immobilier · bidonvilles"
	if not Immobilier.bidonvilles_actifs():
		_text("Les bidonvilles sont coupés dans les réglages de la partie (Admin, F10 → Immobilier).", true)
		return
	if immo.bidonvilles.is_empty():
		_text("Aucun bidonville. Il en apparaît quand des familles ne trouvent plus aucun logement abordable, ou quand des emplois attirent des travailleurs sans logement libre pour eux.", true)
		_text("Pour l'éviter : des logements libres, des loyers abordables, des logements sociaux (B → Logement).", true, 12)
		return
	for id in immo.bidonvilles:
		var b: Dictionary = immo.bidonvilles[id]
		var bv := int(id)
		var foyers := immo.habitants_bidonville(bv)
		var hab := 0
		for hid in foyers:
			hab += (immo.population.households[hid].m as Array).size()
		_section("« %s »" % String(b.nom))
		_text("%d baraque%s · %d foyer%s, %d habitant%s%s" % [(b.baraques as Array).size(), "s" if (b.baraques as Array).size() > 1 else "",
			foyers.size(), "s" if foyers.size() > 1 else "", hab, "s" if hab > 1 else "",
			" · viabilisé (eau, courant)" if bool(b.viab) else " · sans eau ni égouts"], false, 13)
		var libres := 0
		for hid in foyers:
			if immo.logement_abordable(hid) >= 0:
				libres += 1
		_text("Logements abordables libres pour eux : %d sur %d." % [libres, foyers.size()], true, 12)
		var r := _row()
		var c: Vector2 = b.c
		_button("Aller", func() -> void: lieu_requested.emit(Vector3(c.x, 0, c.y)), "Centrer la vue sur le bidonville", r)
		var why := immo.raison_viabiliser(bv)
		var vb := _button("Viabiliser (%s)" % _eur(immo.cout_viabiliser(bv)), func() -> void:
			var w := immo.viabiliser(bv)
			if w != "":
				immo.message.emit(w), "Eau courante, électricité et latrines : plus d'odeurs ni d'eau polluée, les familles peuvent devenir modestes.", r)
		vb.disabled = why != ""
		if why != "" and not bool(b.viab):
			vb.tooltip_text = why
		var r2 := _row()
		var rl := _button("Reloger les familles", func() -> void: immo.reloger(bv),
			"Chaque famille part dans un logement libre à moins de 35 %% de ses revenus (social d'abord). Aide de %s par famille." % _eur(Immobilier.AIDE_RELOGEMENT), r2)
		rl.disabled = libres == 0 or not Immobilier.decide(int(b.vid))
		var rz := _button("Raser", func() -> void: immo.raser(bv), "Les familles sont expulsées et quittent la ville. Les habitants s'en souviendront.", r2)
		rz.add_theme_color_override("font_color", ROUGE)
		rz.disabled = not Immobilier.decide(int(b.vid))
	_section("Ce qu'il faut savoir")
	_text("Pas de loyer ni de taxe, mais des odeurs et de l'eau polluée autour, des terrains voisins dévalués et des familles bloquées au niveau Précaire.", true, 12)
	_text("Une baraque vide depuis %d jours est démontée. Un bidonville dont les familles ont trouvé mieux disparaît tout seul." % Immobilier.JOURS_BARAQUE_VIDE, true, 12)
