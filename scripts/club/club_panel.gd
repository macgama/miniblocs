class_name ClubPanel
extends CanvasLayer
## Menu « Club de sport » (barre du bas → Loisirs, ou Maj+B).
## En haut, le sport : football, basket, handball, hockey, rugby, tennis ;
## chaque sport a son club (sa section), ses onglets ci-dessous.
## - Club : fonder le club (nom, couleurs, stade), puis le tableau de bord :
##   division, rang, caisse, supporters, prochain match, billet, subvention.
## - Effectif : formation, tactique, entraînement, les joueurs (note, forme,
##   blessures, contrat), repos, prolonger, vendre, libérer.
## - Calendrier : les journées, les résultats.
## - Classement : le championnat de la saison.
## - Transferts : le marché (renouvelé chaque lundi).
## - Formation : centre de formation (niveau, coût), espoirs, promotions.
## - Supporters : habitants supporters, humeur, abonnements, drapeaux en ville.
## - Finances : recettes et dépenses de la saison, historique, palmarès, supporters.

signal focus_requested(pos: Vector3)
signal building_chosen(id: String)

const W := 400.0
const H := 560.0
const TABS := [["Club", "club", "sport"], ["Effectif", "effectif", "habitants"], ["Calendrier", "calendrier", "horloge"],
	["Classement", "classement", "trophee"], ["Transferts", "transferts", "emploi"], ["Formation", "formation", "ecole"],
	["Supporters", "supporters", "fete"], ["Finances", "finances", "budget"]]

var cs: ClubSport
## sport → section.
var sections: Dictionary = {}
var _sport_buttons := {}
var view := "club"
var _form := {"nom": "", "couleurs": 0, "stade": -1}
var _panel: PanelContainer
var _title: Label
var _body: VBoxContainer
var _scroll: ScrollContainer
var _tab_buttons := {}
var _tick := 0.0
var _msg := ""


func setup(c: ClubSport, toutes: Dictionary = {}) -> void:
	cs = c
	sections = toutes if not toutes.is_empty() else {c.sport: c}
	_build()
	for s in sections:
		var sec: ClubSport = sections[s]
		sec.changed.connect(func() -> void:
			if sec == cs:
				_tick = 10.0)


## Change de sport (de section).
func choisir_sport(s: String) -> void:
	if not sections.has(s):
		return
	cs = sections[s]
	_form = {"nom": "", "couleurs": 0, "stade": -1}
	_msg = ""
	refresh()
	_scroll.scroll_vertical = 0


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
	icon.texture = Icones.get_icon("sport", 22, UiStyle.ACCENT)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	head.add_child(icon)
	_title = Label.new()
	_title.text = "Club de sport"
	_title.add_theme_font_size_override("font_size", 16)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.clip_text = true
	head.add_child(_title)
	var x := UiStyle.icon_button("fermer", "Fermer", "Maj+B", 18, 32)
	x.pressed.connect(func() -> void: set_open(false))
	head.add_child(x)
	var sports := HBoxContainer.new()
	sports.add_theme_constant_override("separation", 2)
	outer.add_child(sports)
	for s in ClubSports.ORDRE:
		if not sections.has(s):
			continue
		var sb := Button.new()
		sb.text = String(ClubSports.sport(s).court)
		sb.tooltip_text = String(ClubSports.sport(s).nom)
		sb.toggle_mode = true
		sb.focus_mode = Control.FOCUS_NONE
		sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sb.add_theme_font_size_override("font_size", 11)
		sb.clip_text = true
		var ss: String = s
		sb.pressed.connect(func() -> void: choisir_sport(ss))
		sports.add_child(sb)
		_sport_buttons[s] = sb
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
	return _panel.visible


func set_open(on: bool) -> void:
	_panel.visible = on
	if on:
		refresh()


func toggle() -> void:
	set_open(not _panel.visible)


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.keycode == KEY_B and k.shift_pressed and not k.ctrl_pressed and not k.alt_pressed:
		toggle()
		get_viewport().set_input_as_handled()


func show_view(v: String) -> void:
	view = v
	_msg = ""
	refresh()
	_scroll.scroll_vertical = 0


func _process(delta: float) -> void:
	if not is_open():
		return
	_tick += delta
	if _tick >= 3.0 and view in ["club", "calendrier", "classement", "finances", "effectif"]:
		_tick = 0.0
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


func _petit(text: String, tip: String, cb: Callable, parent: Control) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 11)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _option(items: Array, current: String, cb: Callable) -> OptionButton:
	var opt := OptionButton.new()
	opt.focus_mode = Control.FOCUS_NONE
	opt.clip_text = true
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for it in items:
		opt.add_item(String(it[1]))
		opt.set_item_metadata(opt.item_count - 1, it[0])
		if str(it[0]) == current:
			opt.select(opt.item_count - 1)
	opt.item_selected.connect(func(i: int) -> void: cb.call(opt.get_item_metadata(i)))
	return opt


func _ligne(label: String, ctrl: Control) -> void:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(110, 0)
	l.add_theme_font_size_override("font_size", 12)
	row.add_child(l)
	ctrl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(ctrl)
	_body.add_child(row)


static func _euros(x: float) -> String:
	return BuildingSystem.format_money(int(x))


## Carte entre amis : la décision part au serveur, qui renvoie l'état du club (renvoie "") ;
## en solo, elle est faite ici. stade : celui choisi pour fonder le club.
func _faire(f: String, args: Array = [], stade := -1) -> Variant:
	if SystemesGeres.relayer("club", f, args, SystemesGeres.point_du_club(cs, stade), {"sport": cs.sport}):
		return ""
	return cs.callv(f, args)


func _resultat(why: String) -> void:
	_msg = why
	refresh()


func refresh() -> void:
	if cs == null:
		return
	for v in _tab_buttons:
		(_tab_buttons[v] as Button).set_pressed_no_signal(v == view)
	for s in _sport_buttons:
		var b: Button = _sport_buttons[s]
		b.set_pressed_no_signal(s == cs.sport)
		var sec: ClubSport = sections[s]
		b.text = String(ClubSports.sport(s).court) + (" ●" if sec.fonde() else "")
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	_title.text = String(cs.club.nom) if cs.fonde() else "Club de sport · %s" % String(ClubSports.sport(cs.sport).court)
	if _msg != "":
		var l := _label(_msg, 12)
		l.add_theme_color_override("font_color", Color("ff9f80"))
	if not cs.fonde() and view != "club":
		_label("Fonde d'abord ton club (onglet Club).", 13)
		_bouton("Fonder un club", "sport", "", func() -> void: show_view("club"))
		return
	match view:
		"club": _vue_club()
		"effectif": _vue_effectif()
		"calendrier": _vue_calendrier()
		"classement": _vue_classement()
		"transferts": _vue_transferts()
		"formation": _vue_formation()
		"supporters": _vue_supporters()
		"finances": _vue_finances()


# --- Club -------------------------------------------------------------------------------------

func _vue_club() -> void:
	if not cs.fonde():
		_vue_fonder()
		return
	var c: Dictionary = cs.club
	var div := ClubSports.division(cs.sport, int(c.division))
	var l := _label("%s · %de sur %d" % [div.nom, cs.rang(), (cs.ligue.get("clubs", {}) as Dictionary).size()], 18)
	l.add_theme_color_override("font_color", UiStyle.ACCENT)
	_label("Couleurs : %s · sponsor maillot : %s" % [ClubDonnees.NOMS_COULEURS[ClubDonnees.COULEURS.find(c.couleurs)] if ClubDonnees.COULEURS.has(c.couleurs) else "—", String(c.sponsor)], 12, true)
	_label("Caisse du club : %s · ville : %s" % [_euros(float(c.caisse)), _euros(float(cs.caisse_ville()))], 13)
	_label("Supporters : %s · réputation %d / 100 · stade : %s (%s places)" % [Stades._milliers(int(c.supporters)), int(c.reputation),
		cs.nom_stade(), Stades._milliers(cs.places())], 12, true)
	var fe := cs.force_equipe()
	_label("Force de l'équipe : %d (niveau de la division : %d)" % [int(fe.force), int(div.niveau)], 12)
	var serie: Array = c.get("serie", [])
	if not serie.is_empty():
		_label("Derniers résultats : %s" % " ".join(serie.slice(maxi(serie.size() - 8, 0))), 12, true)
	# Prochain match.
	var j := cs.prochaine_journee()
	_titre("Prochain match")
	if j.is_empty():
		_label("Pas de match prévu : intersaison. Le championnat reprend en %s." % _mois_debut() if bool(cs.ligue.get("fini", false)) or (cs.ligue.get("journees", []) as Array).is_empty() else "—", 12, true)
	else:
		var m := cs.mon_match(j)
		var dom := not m.is_empty() and String(m[0]) == String(c.nom)
		_label("%de journée, %s à %d h : %s – %s %s" % [int(j.n), cs.date_texte(int(j.d)), int(j.h), String(m[0]), String(m[1]),
			"(à domicile)" if dom else "(à l'extérieur)"], 12)
		if dom:
			_label("Spectateurs attendus : environ %s" % Stades._milliers(cs.affluence(String(m[1]))), 12, true)
	# Billet.
	var prix := SpinBox.new()
	prix.min_value = 0
	prix.max_value = 250
	prix.step = 1
	prix.value = float(c.prix)
	prix.suffix = "€"
	prix.tooltip_text = "Prix de référence en %s : %d €. Plus cher : moins de monde dans les tribunes." % [div.nom, int(div.prix)]
	prix.value_changed.connect(func(v: float) -> void: _faire("set_prix", [v]))
	_ligne("Billet :", prix)
	# Subvention.
	var sub := HBoxContainer.new()
	_label("Subvention de la ville :", 12, false, sub)
	for v in [10_000, 50_000, 250_000]:
		var vv := float(v)
		_petit("+" + _euros(vv), "La ville verse cette somme au club.", func() -> void: _resultat(_faire("subventionner", [vv])), sub)
	_body.add_child(sub)
	# Nom, couleurs, stade.
	var nrow := HBoxContainer.new()
	var ne := LineEdit.new()
	ne.text = String(c.nom)
	ne.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ne.text_submitted.connect(func(tx: String) -> void:
		_faire("renommer", [tx])
		refresh())
	nrow.add_child(ne)
	var go := Button.new()
	go.icon = Icones.get_icon("lieu", 18)
	go.tooltip_text = "Aller voir le stade"
	go.focus_mode = Control.FOCUS_NONE
	go.pressed.connect(func() -> void:
		if cs.buildings != null and cs.buildings.buildings.has(int(c.stade)):
			focus_requested.emit(BuildingSystem.rect_center(cs.buildings._rect_of(cs.buildings.buildings[int(c.stade)]))))
	nrow.add_child(go)
	_body.add_child(nrow)
	var cols: Array = []
	for i in ClubDonnees.COULEURS.size():
		cols.append([i, ClubDonnees.NOMS_COULEURS[i]])
	_ligne("Couleurs :", _option(cols, str(ClubDonnees.COULEURS.find(c.couleurs)), func(v: Variant) -> void: _faire("set_couleurs", [int(v)])))
	var st := cs.stades_possibles()
	if st.size() > 1 or int(c.stade) < 0:
		var items: Array = []
		for s in st:
			items.append([int(s.bid), "%s (%s places)" % [String(s.nom).split(" (")[0], Stades._milliers(int(s.places))]])
		_ligne("Stade :", _option(items, str(int(c.stade)), func(v: Variant) -> void: _resultat(_faire("changer_stade", [int(v)]))))
	if int(c.stade) < 0:
		_bouton("Bâtir un stade", "construire", "", func() -> void: _batir_stade())
	# Journal.
	_titre("Nouvelles du club")
	for e in cs.journal.slice(0, 10):
		_label("%s · %s" % [cs.date_texte(int(e.d)), String(e.t)], 11, true)
	if not cs.pensees.is_empty():
		_titre("Dans les tribunes")
		var ks := cs.pensees.keys()
		ks.sort_custom(func(a: String, b: String) -> bool: return int(cs.pensees[a]) > int(cs.pensees[b]))
		for k in ks.slice(0, 5):
			_label(String(k), 11, true)


func _vue_fonder() -> void:
	var S := ClubSports.sport(cs.sport)
	_label("Fonder un club de %s" % String(S.nom).to_lower(), 16)
	_label("Tu en es le président : effectif, tactique, transferts, billetterie, centre de formation. Le club commence en %s avec des joueurs du coin, puis peut monter jusqu'en %s. Il a sa propre caisse ; la ville verse %s au départ et touche la location du lieu à chaque match." % [
		ClubSports.division(cs.sport, 0).nom, ClubSports.division(cs.sport, ClubSports.nb_divisions(cs.sport) - 1).nom, _euros(cs.subvention_depart())], 12, true)
	var st := cs.stades_possibles()
	if st.is_empty():
		_label("Il faut d'abord %s dans la ville (Construire → Sport)." % String(S.lieu), 13)
		_bouton("Bâtir : %s" % String(BuildingCatalog.get_type(String(S.batir)).get("name", "")).split(" (")[0].to_lower(), "construire", "Ouvre le catalogue Sport.", func() -> void: _batir_stade())
		return
	if String(_form.nom) == "":
		_form.nom = cs.nom_propose()
	var ok := false
	for s in st:
		ok = ok or int(s.bid) == int(_form.stade)
	if not ok:
		_form.stade = int(st[0].bid)
	var ne := LineEdit.new()
	ne.text = String(_form.nom)
	ne.text_changed.connect(func(tx: String) -> void: _form.nom = tx)
	_ligne("Nom :", ne)
	var cols: Array = []
	for i in ClubDonnees.COULEURS.size():
		cols.append([i, ClubDonnees.NOMS_COULEURS[i]])
	_ligne("Couleurs :", _option(cols, str(int(_form.couleurs)), func(v: Variant) -> void: _form.couleurs = int(v)))
	var items: Array = []
	for s in st:
		items.append([int(s.bid), "%s (%s places)" % [String(s.nom).split(" (")[0], Stades._milliers(int(s.places))]])
	_ligne("Stade :", _option(items, str(int(_form.stade)), func(v: Variant) -> void: _form.stade = int(v)))
	_bouton("Fonder le club", "sport", "La ville verse la subvention de départ.", func() -> void:
		_resultat(_faire("fonder", [String(_form.nom), int(_form.couleurs), int(_form.stade)], int(_form.stade))))


func _batir_stade() -> void:
	building_chosen.emit(String(ClubSports.sport(cs.sport).batir))


func _mois_debut() -> String:
	const M := ["janvier", "février", "mars", "avril", "mai", "juin", "juillet", "août", "septembre", "octobre", "novembre", "décembre"]
	return M[int(ClubSports.sport(cs.sport).debut[0]) - 1]


func _unite(n: int) -> String:
	var u: Array = ClubSports.sport(cs.sport).unite
	return String(u[0] if n <= 1 else u[1])


# --- Centre de formation ----------------------------------------------------------------------

func _vue_formation() -> void:
	var a := cs.academie()
	_label("Centre de formation : %s" % String(a.nom), 16)
	_label(String(a.desc), 12, true)
	var items: Array = []
	for i in ClubSports.ACADEMIE.size():
		var n: Dictionary = ClubSports.ACADEMIE[i]
		var cout := cs.cout_academie(i)
		items.append([i, "%s%s%s" % [String(n.nom), "" if cout <= 0.0 else " (%s / mois)" % _euros(cout), " · bâtiment requis" if bool(n.bati) and not cs.centre_bati() else ""]])
	_ligne("Niveau :", _option(items, str(int(cs.club.get("academie", 0))), func(v: Variant) -> void: _resultat(_faire("set_academie", [int(v)]))))
	if cs.centre_bati():
		_label("Un centre de formation est bâti en ville : les jeunes y progressent plus vite.", 11, true)
	else:
		_label("Pas encore de centre de formation en ville : les niveaux 2 et 3 en demandent un.", 11, true)
		_bouton("Bâtir un centre de formation", "construire", "Ouvre le catalogue Sport.", func() -> void: building_chosen.emit("centre_formation"))
	_label("Chaque début de saison, de nouveaux jeunes arrivent, d'abord les enfants de la ville qui pratiquent le sport. À 19 ans, un espoir signe pro ou s'en va.", 11, true)
	var es := cs.liste_espoirs()
	_titre("Espoirs (%d)" % es.size())
	if es.is_empty():
		_label("Aucun jeune au centre pour le moment." if int(cs.club.get("academie", 0)) > 0 else "Ouvre une école de sport pour accueillir des jeunes.", 12, true)
	var S := ClubSports.sport(cs.sport)
	for p in es:
		var l := _label("%s · %s · %d ans · note %d · potentiel %d%s" % [ClubSport.nom_joueur(p), String(S.postes[String(p.poste)]).to_lower(),
			int(cs.age(p)), int(p.note), int(p.pot), " · de la ville" if int(p.pid) >= 0 else ""], 12)
		if float(p.pot) >= float(ClubSports.division(cs.sport, int(cs.club.division)).niveau) + 8.0:
			l.add_theme_color_override("font_color", UiStyle.GOOD)
		var row := HBoxContainer.new()
		var id := int(p.id)
		_label("Note de la division : %d" % int(ClubSports.division(cs.sport, int(cs.club.division)).niveau), 11, true, row)
		_petit("Passer pro", "Premier contrat pro de trois saisons, petit salaire.", func() -> void: _resultat(_faire("promouvoir", [id])), row)
		_petit("Libérer", "Il quitte le centre.", func() -> void: _resultat(_faire("liberer_espoir", [id])), row)
		_body.add_child(row)


# --- Supporters -------------------------------------------------------------------------------

func _vue_supporters() -> void:
	var c: Dictionary = cs.club
	_label("Supporters : %s · humeur : %s" % [Stades._milliers(int(c.supporters)), cs.humeur_texte()], 16)
	_label("Habitants de la ville qui soutiennent le club : %s (surtout ceux qui pratiquent le %s). Ils vont aux matchs, sortent les drapeaux quand ça gagne et sont plus contents de leur ville quand le club va bien (et moins quand il perd)." % [
		Stades._milliers(cs.supporters_habitants()), String(ClubSports.sport(cs.sport).court).to_lower()], 12, true)
	var drap := 0
	var parent := get_parent()
	if parent != null and "club_supporters" in parent and parent.club_supporters != null:
		drap = int(parent.club_supporters.par_sport.get(cs.sport, 0))
	_label("Drapeaux aux couleurs du club dans les rues : %d" % drap, 12)
	_titre("Abonnements")
	var n := cs.nb_domicile()
	_label("%s abonnés cette saison · %d matchs à domicile · prix conseillé : %s" % [Stades._milliers(int(c.get("abo", 0))), n, _euros(cs.abo_prix_ref())], 12)
	var abo := SpinBox.new()
	abo.min_value = 0
	abo.max_value = 20000
	abo.step = 5
	abo.value = float(c.get("abo_prix", 0.0)) if float(c.get("abo_prix", 0.0)) > 0.0 else cs.abo_prix_ref()
	abo.suffix = "€"
	abo.tooltip_text = "Vendu en début de saison. Les abonnés paient d'avance et viennent à tous les matchs à domicile."
	abo.value_changed.connect(func(v: float) -> void: _faire("set_abo_prix", [v]))
	_ligne("Abonnement :", abo)
	_label("À ce prix : environ %s abonnés (vente à la prochaine saison)." % Stades._milliers(cs.abonnes_attendus(abo.value)), 11, true)
	if not cs.pensees.is_empty():
		_titre("Ce que disent les supporters")
		var ks := cs.pensees.keys()
		ks.sort_custom(func(x: String, y: String) -> bool: return int(cs.pensees[x]) > int(cs.pensees[y]))
		for k in ks.slice(0, 8):
			_label(String(k), 11, true)


# --- Effectif ---------------------------------------------------------------------------------

func _vue_effectif() -> void:
	var c: Dictionary = cs.club
	var f: Array = []
	for k in ClubSports.sport(cs.sport).formations:
		f.append([k, k])
	_ligne("Formation :", _option(f, String(c.formation), func(v: Variant) -> void: _faire("set_formation", [String(v)])))
	var t: Array = []
	for k in ClubDonnees.TACTIQUES:
		t.append([k, ClubDonnees.TACTIQUES[k][2]])
	_ligne("Tactique :", _option(t, String(c.tactique), func(v: Variant) -> void: _faire("set_tactique", [String(v)])))
	var e: Array = []
	for k in ClubDonnees.ENTRAINEMENTS:
		e.append([k, ClubDonnees.ENTRAINEMENTS[k][3]])
	var opt := _option(e, String(c.entrainement), func(v: Variant) -> void: _faire("set_entrainement", [String(v)]))
	opt.tooltip_text = "Intense : les jeunes progressent plus vite, mais fatigue et blessures."
	_ligne("Entraînement :", opt)
	var fe := cs.force_equipe()
	var S := ClubSports.sport(cs.sport)
	var parts := ["Force %d" % int(fe.force)]
	for k in S.ordre:
		if fe.has(k) and (S.ordre as Array).size() > 1:
			parts.append("%s %d" % [String(S.postes[k]).to_lower() + "s", int(fe[k])])
	_label(" · ".join(parts), 12)
	_label("%d joueurs · salaires %s par mois · ★ = titulaire" % [cs.joueurs.size(), _euros(cs.masse_salariale())], 11, true)
	var fins := 0
	for id in cs.joueurs:
		if int(cs.joueurs[id].contrat) <= cs._annee_saison() + 1 and not bool(cs.joueurs[id].benevole):
			fins += 1
	if fins > 0:
		_label("%d contrat%s se termine%s en juin : prolonge ceux que tu veux garder." % [fins, "s" if fins > 1 else "", "nt" if fins > 1 else ""], 12)
	var xi := cs.titulaires()
	for poste in S.ordre:
		_titre(String(S.postes[poste]) + "s")
		for p in cs.liste_joueurs(poste):
			_carte_joueur(p, xi.has(int(p.id)))


func _carte_joueur(p: Dictionary, titulaire: bool) -> void:
	var etat := ""
	if int(p.blesse) > 0:
		etat = " · blessé %d j" % int(p.blesse)
	elif bool(p.repos):
		etat = " · au repos"
	var l := _label("%s%s · %d ans · note %d (pot. %d) · forme %d %% · fatigue %d %%%s" % ["★ " if titulaire else "", ClubSport.nom_joueur(p),
		int(cs.age(p)), int(p.note), int(p.pot), roundi(float(p.forme) * 100.0), roundi(float(p.fatigue) * 100.0), etat], 12)
	if titulaire:
		l.add_theme_color_override("font_color", UiStyle.GOOD)
	var row := HBoxContainer.new()
	var fin := int(p.contrat) <= cs._annee_saison() + 1
	var lc := _label("%s · %s · %d m, %d %s%s" % ["bénévole" if bool(p.benevole) else _euros(float(p.salaire)) + "/mois",
		"fin de contrat en juin %d" % int(p.contrat) if fin else "contrat jusqu'en %d" % int(p.contrat),
		int(p.matchs_saison), int(p.buts_saison), _unite(int(p.buts_saison)), (" · formé au club" if bool(p.get("forme_club", false)) else "") + (" · habitant" if int(p.pid) >= 0 else "")], 11, not fin, row)
	if fin:
		lc.add_theme_color_override("font_color", Color("ffcf80"))
	var id := int(p.id)
	_petit("Repos" if not bool(p.repos) else "Aligner", "Le laisser hors du onze (ou l'aligner de nouveau).", func() -> void:
		_faire("set_repos", [id, not bool(p.repos)])
		refresh(), row)
	_petit("Prolonger", "+2 saisons ; salaire revu selon sa note.", func() -> void: _resultat(_faire("prolonger", [id])), row)
	_petit("Vendre ≈" + _euros(cs.valeur_de(p)), "Le vendre à un autre club.", func() -> void: _resultat(_faire("vendre", [id])), row)
	_body.add_child(row)


# --- Calendrier -------------------------------------------------------------------------------

func _vue_calendrier() -> void:
	var js: Array = cs.ligue.get("journees", [])
	_label("Saison %s · %s" % [String(cs.ligue.get("saison", "")), ClubSports.division(cs.sport, int(cs.ligue.get("division", 0))).nom], 14)
	if js.is_empty():
		_label("Pas de calendrier cette saison : le club jouera dès la prochaine (août).", 12, true)
		return
	for j in js:
		var m := cs.mon_match(j)
		var txt := "J%d · %s · %s – %s" % [int(j.n), cs.date_texte(int(j.d)), String(m[0]), String(m[1])] if not m.is_empty() else "J%d · %s · exempt" % [int(j.n), cs.date_texte(int(j.d))]
		if bool(j.joue) and not (j.mon as Dictionary).is_empty():
			var sc: Array = j.mon.score
			var dom := String(m[0]) == String(cs.club.nom)
			var pour := int(sc[0]) if dom else int(sc[1])
			var contre := int(sc[1]) if dom else int(sc[0])
			txt += "  %d – %d%s  %s" % [int(sc[0]), int(sc[1]), " (%s)" % String(j.mon.suffixe) if String(j.mon.get("suffixe", "")) != "" else "",
				"V" if pour > contre else ("N" if pour == contre else "D")]
			var l := _label(txt, 12)
			l.add_theme_color_override("font_color", UiStyle.GOOD if pour > contre else (UiStyle.TEXT if pour == contre else Color("ff9f80")))
		else:
			_label(txt + (" · %d h" % int(j.h)), 12, true)


# --- Classement -------------------------------------------------------------------------------

func _vue_classement() -> void:
	var div := ClubSports.division(cs.sport, int(cs.ligue.get("division", 0)))
	_label("%s, saison %s" % [div.nom, String(cs.ligue.get("saison", ""))], 14)
	var regle := "Les %d premiers montent" % int(div.monte) if int(div.monte) > 0 else "Le premier est champion de la plus haute division"
	regle += ", les %d derniers descendent." % int(div.descend) if int(div.descend) > 0 else " (pas de descente depuis la Régionale)."
	_label(regle, 11, true)
	var cl := cs.classement()
	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 8)
	for h in ["", "Club", "Pts", "J", "G", "N", "P", "Diff"]:
		var lh := Label.new()
		lh.text = h
		lh.add_theme_font_size_override("font_size", 11)
		lh.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
		grid.add_child(lh)
	for i in cl.size():
		var c: Dictionary = cl[i]
		var vals := [str(i + 1), String(c.nom), str(int(c.pts)), str(int(c.j)), str(int(c.g)), str(int(c.n)), str(int(c.p)), "%+d" % (int(c.bp) - int(c.bc))]
		for k in vals.size():
			var lv := Label.new()
			lv.text = vals[k]
			lv.add_theme_font_size_override("font_size", 11)
			if k == 1:
				lv.custom_minimum_size = Vector2(150, 0)
				lv.clip_text = true
			if bool(c.moi):
				lv.add_theme_color_override("font_color", UiStyle.ACCENT)
			elif i < int(div.monte):
				lv.add_theme_color_override("font_color", UiStyle.GOOD)
			elif i >= cl.size() - int(div.descend):
				lv.add_theme_color_override("font_color", Color("ff9f80"))
			grid.add_child(lv)
	_body.add_child(grid)
	# Meilleurs buteurs du club.
	var b := cs.liste_joueurs()
	b.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return int(x.buts_saison) > int(y.buts_saison))
	if not b.is_empty() and int(b[0].buts_saison) > 0:
		_titre("Meilleurs marqueurs du club" if cs.sport != "tennis" else "Meilleurs joueurs du club")
		for p in b.slice(0, 5):
			if int(p.buts_saison) > 0:
				_label("%s : %d %s" % [ClubSport.nom_joueur(p), int(p.buts_saison), _unite(int(p.buts_saison))], 12)


# --- Transferts -------------------------------------------------------------------------------

func _vue_transferts() -> void:
	_label("Caisse du club : %s · %d / %d joueurs" % [_euros(float(cs.club.caisse)), cs.joueurs.size(), cs.max_joueurs()], 13)
	_label("Le marché change chaque lundi. Signer coûte le transfert et deux mois de salaire en prime.", 11, true)
	for p in cs.marche:
		var l := _label("%s · %s · %d ans · note %d (pot. %d)" % [ClubSport.nom_joueur(p), ClubSports.sport(cs.sport).postes[String(p.poste)], int(cs.age(p)), int(p.note), int(p.pot)], 12)
		var why := cs.peut_acheter(p)
		if why != "":
			l.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
		var row := HBoxContainer.new()
		_label("%s · %s/mois%s" % ["libre" if bool(p.get("libre", false)) else _euros(float(p.prix)) + " (" + String(p.get("club_origine", "")) + ")",
			_euros(float(p.salaire)).replace(" €", " €"), "" if why == "" else " · " + why], 11, true, row)
		var id := int(p.id)
		var b := _petit("Signer", "Recruter ce joueur.", func() -> void: _resultat(_faire("acheter", [id])), row)
		b.disabled = why != ""
		_body.add_child(row)


# --- Finances ---------------------------------------------------------------------------------

func _vue_finances() -> void:
	_label("Caisse du club : %s" % _euros(float(cs.club.caisse)), 16)
	_label("Salaires %s / mois · staff %s / mois" % [_euros(cs.masse_salariale()), _euros(cs.staff())], 12, true)
	for prec in [false, true]:
		var b := cs.bilan(prec)
		if prec and (b.postes as Dictionary).is_empty():
			continue
		_titre("Saison passée" if prec else "Saison %s" % String(cs.ligue.get("saison", "")))
		var ks: Array = (b.postes as Dictionary).keys()
		ks.sort_custom(func(x: String, y: String) -> bool: return float(b.postes[x]) > float(b.postes[y]))
		for k in ks:
			var v := float(b.postes[k])
			var l := _label("%s : %s%s" % [k, "+" if v >= 0.0 else "", _euros(v)], 12)
			if v < 0.0:
				l.add_theme_color_override("font_color", Color("ffb59e"))
		_label("Recettes %s · dépenses %s · solde %s%s" % [_euros(float(b.recettes)), _euros(float(b.depenses)), "+" if float(b.solde) >= 0.0 else "", _euros(float(b.solde))], 12)
	var h: Array = cs.club.get("historique", [])
	if not h.is_empty():
		_titre("Historique")
		for e in h:
			_label("%s · %s · %de (%d pts)%s" % [String(e.saison), ClubSports.division(cs.sport, int(e.division)).nom, int(e.rang), int(e.pts),
				" · montée" if String(e.issue) == "montee" else (" · descente" if String(e.issue) == "descente" else "")], 12)
	var pal: Array = cs.club.get("palmares", [])
	if not pal.is_empty():
		_titre("Palmarès")
		for t in pal:
			_label("🏆 " + String(t), 12)
