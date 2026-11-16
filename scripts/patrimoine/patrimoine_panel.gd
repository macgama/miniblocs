class_name PatrimoinePanel
extends CanvasLayer
## Menu « Patrimoine et grands monuments » (barre du bas → Loisirs, ou touche Fin) :
## - En bref : rayonnement de la ville, monuments protégés, entretien et
##   subventions, Journées du patrimoine, règles des abords, conseils.
## - Grands chantiers : chaque grand monument (étape, avancement, fin prévue,
##   reste à payer, souscription, mécènes).
## - Classement : les bâtiments protégés et ceux qui pourraient l'être
##   (intérêt, âge, état) : inscrire, classer, déclasser, entretien, restaurer.
## - Bâtir : les 13 grands monuments, datés (verrouillés avant leur époque).

signal focus_requested(pos: Vector3)
signal building_chosen(id: String)

const W := 400.0
const H := 560.0
const TABS := [["En bref", "bref", "patrimoine"], ["Grands chantiers", "chantiers", "grue"],
	["Classement", "classement", "statue"], ["Bâtir un monument", "batir", "construire"]]

var pat: Patrimoine
var view := "bref"
var _panel: PanelContainer
var _body: VBoxContainer
var _scroll: ScrollContainer
var _tab_buttons := {}
var _tick := 0.0


func setup(p: Patrimoine) -> void:
	pat = p
	_build()
	if pat != null:
		pat.changed.connect(func() -> void:
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
	icon.texture = Icones.get_icon("patrimoine", 22, UiStyle.ACCENT)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	head.add_child(icon)
	var title := Label.new()
	title.text = "Patrimoine et grands monuments"
	title.add_theme_font_size_override("font_size", 16)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var x := UiStyle.icon_button("fermer", "Fermer", "Fin", 18, 32)
	x.pressed.connect(func() -> void: set_open(false))
	head.add_child(x)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 2)
	outer.add_child(tabs)
	for spec in TABS:
		var b := Button.new()
		b.icon = Icones.get_icon(spec[2], 20)
		b.tooltip_text = spec[0]
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 34)
		var v: String = spec[1]
		b.pressed.connect(func() -> void: show_view(v))
		tabs.add_child(b)
		_tab_buttons[v] = b
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(W - 20, H)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(_scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 4)
	_scroll.add_child(_body)


func is_open() -> bool:
	return _panel != null and _panel.visible


func set_open(on: bool) -> void:
	_panel.visible = on
	if on:
		refresh()


func toggle() -> void:
	set_open(not _panel.visible)


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.keycode == KEY_END and not k.shift_pressed and not k.ctrl_pressed and not k.alt_pressed:
		if EditionDemo.panneau_verrouille("patrimoine"):
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
	if _tick >= 3.0 and view in ["bref", "chantiers"]:
		_tick = 0.0
		_refresh_keep()


func _refresh_keep() -> void:
	var f := get_viewport().gui_get_focus_owner()
	if f != null and _body.is_ancestor_of(f):
		return
	var keep := _scroll.scroll_vertical
	refresh()
	_scroll.set_deferred("scroll_vertical", keep)


# --- Petits outils ----------------------------------------------------------------------------

func _label(text: String, size := 12, dim := false, parent: Control = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(W - 40, 0) if parent == null else Vector2.ZERO
	if parent != null:
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if dim:
		l.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	(parent if parent != null else _body).add_child(l)
	return l


func _titre(text: String) -> void:
	var l := _label(text, 14)
	l.add_theme_color_override("font_color", UiStyle.ACCENT)


func _bouton(text: String, icon: String, tip: String, cb: Callable, parent: Control = null) -> Button:
	var b := Button.new()
	b.text = text
	if icon != "":
		b.icon = Icones.get_icon(icon, 18)
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.clip_text = parent != null
	b.pressed.connect(cb)
	(parent if parent != null else _body).add_child(b)
	return b


func _ligne(label: String, valeur: String) -> void:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(190, 0)
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	row.add_child(l)
	var v := Label.new()
	v.text = valeur
	v.add_theme_font_size_override("font_size", 12)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(v)
	_body.add_child(row)


func _barre(v: float) -> void:
	var pb := ProgressBar.new()
	pb.min_value = 0.0
	pb.max_value = 100.0
	pb.value = clampf(v, 0.0, 1.0) * 100.0
	pb.custom_minimum_size = Vector2(W - 40, 14)
	pb.show_percentage = false
	_body.add_child(pb)


static func _euros(x: float) -> String:
	return BuildingSystem.format_money(int(x))


func _sep() -> void:
	_body.add_child(HSeparator.new())


func refresh() -> void:
	if pat == null:
		return
	for v in _tab_buttons:
		(_tab_buttons[v] as Button).set_pressed_no_signal(v == view)
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	match view:
		"bref": _vue_bref()
		"chantiers": _vue_chantiers()
		"classement": _vue_classement()
		"batir": _vue_batir()


# --- En bref ----------------------------------------------------------------------------------

func _vue_bref() -> void:
	var r := pat.rayonnement()
	var l := _label("Rayonnement de la ville : %.1f points" % r, 18)
	l.add_theme_color_override("font_color", UiStyle.ACCENT)
	_label("Chaque point fait venir environ 14 touristes par jour (plus l'été et le vendredi, voir Tourisme, Maj+D).", 11, true)
	var ins := 0
	var cla := 0
	for bid in pat.proteges:
		if int(pat.proteges[bid].niv) >= Patrimoine.CLASSE:
			cla += 1
		else:
			ins += 1
	_titre("Monuments")
	_ligne("Classés monuments historiques", "%d" % cla)
	_ligne("Inscrits au patrimoine", "%d" % ins)
	var en_cours := 0
	var finis := 0
	for bid in pat.grands_monuments():
		if pat.en_chantier(int(bid)):
			en_cours += 1
		else:
			finis += 1
	_ligne("Grands monuments", "%d inaugurés, %d en chantier" % [finis, en_cours])
	_titre("Argent (cette année)")
	_ligne("Entretien des monuments", _euros(float(pat.annee.entretien)))
	_ligne("Part payée par l'État", _euros(float(pat.annee.subvention) + float(pat.annee.aides)))
	_ligne("Dons et mécénat aux chantiers", _euros(float(pat.annee.dons)))
	var net := 0.0
	for bid in pat.proteges:
		net += float(pat.entretien_annuel(int(bid))[1])
	_ligne("Entretien prévu par an (net)", _euros(net))
	_titre("Journées du patrimoine")
	if pat.journees():
		_label("C'est ce week-end ! Les monuments ouverts gratuitement attirent presque deux fois plus de visiteurs.", 12)
	else:
		_label("Le troisième week-end de septembre : les monuments attirent presque deux fois plus de visiteurs.", 12, true)
	_titre("Règles des abords")
	_label("À moins de 100 m d'un bâtiment inscrit : 45 m de haut au plus ; à moins de 200 m d'un classé : 30 m. Pas d'usine ni de déchets aux abords.", 11, true)
	var cb := CheckButton.new()
	cb.text = "Appliquer les règles des abords"
	cb.button_pressed = pat.regles_abords
	cb.focus_mode = Control.FOCUS_NONE
	cb.toggled.connect(func(on: bool) -> void:
		pat.regles_abords = on
		pat.changed.emit())
	_body.add_child(cb)
	var cs := pat.conseils()
	if not cs.is_empty():
		_titre("Conseils")
		for c in cs:
			_label("• " + String(c), 12)


# --- Grands chantiers --------------------------------------------------------------------------

func _vue_chantiers() -> void:
	var liste := pat.grands_monuments()
	if liste.is_empty():
		_label("Aucun grand monument pour l'instant. Onglet Bâtir : cathédrale, opéra, tour de fer, barrage… Leurs chantiers durent des années (et se voient de loin).", 12, true)
		return
	for bid in liste:
		var b := int(bid)
		_titre(pat.nom(b))
		if pat.en_chantier(b):
			var e := pat.etape(b)
			var et := MonumentsTypes.etapes(pat.type_of(b))
			_label("Étape %d sur %d : %s" % [int(e[0]) + 1, et.size(), String(e[2])], 12)
			_barre(pat.avancement(b))
			_ligne("Avancement", "%d %%" % floori(pat.avancement(b) * 100.0))
			if pat.vie != null:
				_ligne("Fin prévue", Chantiers.date_texte(pat.vie.fin_prevue(b), pat.offset_h()))
			_ligne("Reste à payer", _euros(float(pat.reste_du(b))))
			var bb: Dictionary = pat.buildings.buildings[b]
			if bb.get("attente", false):
				_label("Arrêté : la caisse est vide (Budget, M).", 12)
			var s := pat.souscription(b)
			if not s.is_empty():
				_ligne("Dons reçus", "%s (%d mécène%s)" % [_euros(float(s.get("recu", 0))), int(s.get("mecenes", 0)), "s" if int(s.get("mecenes", 0)) > 1 else ""])
			if bool(s.get("actif", false)):
				_ligne("Souscription", "en cours · environ %s par jour" % _euros(pat.dons_du_jour(b)))
			else:
				_bouton("Lancer une souscription populaire", "megaphone", "Les habitants donnent chaque jour (jusqu'à %d %% du prix)." % roundi(Patrimoine.PLAFOND_SOUSCRIPTION * 100.0),
					func() -> void: pat.lancer_souscription(b))
			_label("Les curieux viennent déjà voir le chantier : %.1f points d'attrait." % pat.points_site(b), 11, true)
		else:
			_label("Inauguré · %s · %.1f points d'attrait" % [Patrimoine.NIVEAUX[maxi(pat.niveau(b), Patrimoine.CLASSE)], pat.points_site(b)], 12)
			_ligne("État", "%d %%" % roundi(pat.etat(b) * 100.0))
		_bouton("Voir", "oeil", "Centrer la vue sur le monument", func() -> void: focus_requested.emit(pat.pos_of(b)))
		_sep()


# --- Classement --------------------------------------------------------------------------------

func _vue_classement() -> void:
	_label("Un bâtiment remarquable (église, château, théâtre, phare…), d'architecture ancienne ou vieux d'au moins quelques dizaines d'années se protège : intérêt %.0f pour l'inscrire, %.0f pour le classer." % [Patrimoine.SEUILS[1], Patrimoine.SEUILS[2]], 11, true)
	var liste := pat.candidats(40)
	if liste.is_empty():
		_label("Aucun bâtiment n'a encore assez d'intérêt patrimonial. Le temps fera son œuvre (ou bâtis un grand monument).", 12, true)
		return
	for c in liste:
		var b := int(c.bid)
		var n := pat.niveau(b)
		_titre(pat.nom(b))
		var quoi: String = Patrimoine.NIVEAUX[n] if n > 0 else "Non protégé"
		_label("%s · intérêt %.1f (%s)" % [quoi, float(c.pts), ", ".join(PackedStringArray(c.raisons))], 12)
		_ligne("Âge", "%d ans (fini en %d)" % [pat.age(b), int(pat.nes.get(b, Patrimoine.annee_courante()))])
		_ligne("État", "%d %%" % roundi(pat.etat(b) * 100.0))
		_ligne("Attrait", "%.2f points" % pat.points_site(b))
		var row := HBoxContainer.new()
		_body.add_child(row)
		if n < Patrimoine.INSCRIT and pat.niveau_possible(b) >= Patrimoine.INSCRIT:
			_bouton("Inscrire (%s)" % _euros(Patrimoine.FRAIS[1]), "statue", "Inscrit au patrimoine : abords protégés (100 m), entretien aidé à 30 %.",
				func() -> void: pat.proteger(b, Patrimoine.INSCRIT), row)
		if n < Patrimoine.CLASSE and pat.niveau_possible(b) >= Patrimoine.CLASSE and not Patrimoine.est_grand_monument(pat.type_of(b)):
			_bouton("Classer (%s)" % _euros(Patrimoine.FRAIS[2]), "trophee", "Classé monument historique : attrait ×1,7, abords de 200 m, entretien aidé à 50 %.",
				func() -> void: pat.proteger(b, Patrimoine.CLASSE), row)
		if n > 0:
			var row2 := HBoxContainer.new()
			_body.add_child(row2)
			var e := pat.entretien_annuel(b)
			var cb := CheckButton.new()
			cb.text = "Entretien (%s / an)" % _euros(float(e[1]) if pat.entretenu(b) else pat.valeur(b) * float(Patrimoine.ENTRETIEN[n]) * (1.0 - float(Patrimoine.SUBVENTION[n])))
			cb.button_pressed = pat.entretenu(b)
			cb.focus_mode = Control.FOCUS_NONE
			cb.toggled.connect(func(on: bool) -> void: pat.set_entretien(b, on))
			row2.add_child(cb)
			if Ameliorations.instance != null:
				var why := Ameliorations.instance.refus_renover(b)
				if why == "":
					_bouton("Restaurer", "construire", "Chantier de restauration (l'État en paie %d %%)." % roundi(pat.aide_restauration(b) * 100.0),
						func() -> void: pat.restaurer(b), row2)
			if not Patrimoine.est_grand_monument(pat.type_of(b)):
				_bouton("Déclasser", "fermer", "Retire la protection (il pourra être démoli ou agrandi).", func() -> void: pat.declasser(b), row2)
		_bouton("Voir", "oeil", "Centrer la vue", func() -> void: focus_requested.emit(pat.pos_of(b)))
		_sep()


# --- Bâtir -------------------------------------------------------------------------------------

func _vue_batir() -> void:
	_label("Des chantiers de plusieurs années, payés au fil des travaux : on les voit monter étape par étape. Inaugurés, ils sont classés d'office et attirent les touristes du monde entier.", 11, true)
	for id in MonumentsTypes.ORDER:
		var s := MonumentsTypes.spec(String(id))
		var t := BuildingCatalog.get_type(String(id))
		_titre(String(t.get("name", id)))
		var quand := "de tout temps" if int(s.annee) <= 0 else "dès %d" % int(s.annee)
		_label("%s · %s · %s de travaux d'époque, %d ouvriers · %.0f points d'attrait" % [
			quand, _euros(float(BuildingCatalog.cost(String(id)))), MonumentsTypes.ans_texte(float(s.ans)), int(s.equipe), float(s.prestige)], 12)
		if pat.vie != null:
			_label("Durée dans le jeu : environ %s (vitesse de la vie et rythme des chantiers actuels)." % Chantiers.duree_texte(pat.vie.duree_prevue(String(id))), 11, true)
		var why := Epoques.raison_batiment(String(id))
		if why != "":
			_label("🔒 " + why, 12, true)
		else:
			_bouton("Poser", "construire", String(s.desc), func() -> void:
				building_chosen.emit(String(id))
				set_open(false))
