class_name HabitantsPanel
extends CanvasLayer
## Panneau « Habitants » (touche H) : la ville en chiffres, la liste des
## habitants, un bâtiment (qui y vit, y travaille, y étudie, qui y est en ce
## moment) et le profil complet d'un habitant. Tout nom est cliquable.

signal focus_requested(pos: Vector3)
## Boutons de la fiche d'un bâtiment : personnaliser (catalogue), aménager (murs fins).
signal customize_requested(bid: int)
## Mode gestion « tycoon » (Gestion, GestionVue).
signal gestion_requested(bid: int)
signal furnish_requested(bid: int)
## « Aménager l'intérieur » d'un bâtiment du catalogue : il est d'abord ouvert en murs fins.
signal interior_requested(bid: int)

const W := 348.0
const H := 560.0

var pop: Population
## Vrai quand une autre action garde la touche F (poser des blocs : F renverse la forme).
var f_key_taken := func() -> bool: return false
var _panel: PanelContainer
var _title: Label
var _back: Button
var _body: VBoxContainer
var _scroll: ScrollContainer
## Vue affichée : "ville", "liste", "batiment", "profil".
var view := "ville"
var view_arg := -1
var _history: Array = []
var _filter := ""
var _search := ""
var _tick := 0.0
var _popups: Array = []
## Carte de l'habitant suivi (en bas à gauche, même panneau fermé).
var _card: PanelContainer
var _card_text: Label
var _card_cam: Button
var _card_tick := 0.0
## Question posée au joueur pour son personnage principal (en haut au centre).
var _ask: PanelContainer
var _ask_text: Label
var _ask_buttons: HFlowContainer
## Onglets Ville / Habitants / Funéraire (cachés sur la fiche d'un bâtiment).
var _tabs: HBoxContainer
## Fiche d'un bâtiment : rubriques repliables (id -> ouverte), gardées dans
## user://interface.cfg [fiche]. Toutes repliées au départ : le clic montre
## d'abord l'essentiel (type, jauges, réseaux en pastilles).
var ouvertes := {}
## Conteneur où les petits outils (_text, _link…) ajoutent leurs lignes : le
## corps de la rubrique dépliée en cours, sinon le corps du panneau.
var _dest: Control = null
## Bâtiment isolé (IsolementBatiment, posé par terre_main) : bouton « Toute la ville ».
var isolement: Node = null
const CFG := "user://interface.cfg"


func setup(p: Population) -> void:
	pop = p
	_build()
	_build_card()
	_build_ask()
	pop.follow_changed.connect(_refresh_card)
	pop.questions_changed.connect(_refresh_ask)
	pop.person_clicked.connect(func(pid: int) -> void:
		_panel.visible = true
		show_view("profil", pid))
	pop.building_selected.connect(func(bid: int) -> void:
		if bid >= 0:
			_panel.visible = true
			show_view("batiment", bid))


func _build() -> void:
	layer = 6
	_panel = PanelContainer.new()
	# À droite, à la place commune des panneaux (un seul ouvert à la fois).
	UiStyle.place_right(_panel)
	_panel.custom_minimum_size = Vector2(W, 0)
	UiStyle.style_panel(_panel)
	_panel.visible = false
	add_child(_panel)
	var outer := VBoxContainer.new()
	_panel.add_child(outer)
	var head := HBoxContainer.new()
	outer.add_child(head)
	_back = UiStyle.icon_button("retour", "Retour", "", 18, 32)
	_back.pressed.connect(go_back)
	head.add_child(_back)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 16)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.clip_text = true
	head.add_child(_title)
	var x := UiStyle.icon_button("fermer", "Fermer", "H", 18, 32)
	x.pressed.connect(func() -> void: set_open(false))
	head.add_child(x)
	var tabs := HBoxContainer.new()
	_tabs = tabs
	outer.add_child(tabs)
	for spec in [["Ville", "ville", "budget"], ["Habitants", "liste", "habitants"], ["Funéraire", "funeraire", "funeraire"]]:
		var b := Button.new()
		b.text = spec[0]
		b.icon = Icones.get_icon(spec[2], 18)
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v: String = spec[1]
		b.pressed.connect(func() -> void:
			_history.clear()
			show_view(v, -1, false))
		tabs.add_child(b)
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(W, H)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(_scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 3)
	_scroll.add_child(_body)
	var cfg := ConfigFile.new()
	if cfg.load(CFG) == OK:
		for k in cfg.get_section_keys("fiche") if cfg.has_section("fiche") else []:
			ouvertes[k] = bool(cfg.get_value("fiche", k, false))


func is_open() -> bool:
	return _panel.visible


func set_open(on: bool) -> void:
	_panel.visible = on
	if on:
		refresh()
	elif pop != null:
		pop.select_building(-1)


func toggle() -> void:
	set_open(not _panel.visible)


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.physical_keycode == KEY_H and not k.shift_pressed and not k.ctrl_pressed:
		toggle()
		get_viewport().set_input_as_handled()
	elif k and k.pressed and not k.echo and k.physical_keycode == KEY_F and not k.shift_pressed and not k.ctrl_pressed \
			and pop.followed() >= 0 and not f_key_taken.call():
		_toggle_camera()
		get_viewport().set_input_as_handled()


func show_view(v: String, arg := -1, remember := true) -> void:
	if remember and (v != view or arg != view_arg):
		_history.append([view, view_arg])
		if _history.size() > 30:
			_history.pop_front()
	view = v
	view_arg = arg
	if v != "batiment" and pop.selected() >= 0 and v != "profil":
		pop.select_building(-1)
	refresh()
	_scroll.scroll_vertical = 0


func go_back() -> void:
	if _history.is_empty():
		show_view("ville", -1, false)
		return
	var h: Array = _history.pop_back()
	view = h[0]
	view_arg = h[1]
	refresh()


func _process(delta: float) -> void:
	_card_tick -= delta
	if _card_tick <= 0.0 and _card.visible:
		_card_tick = 0.5
		_refresh_card()
	if not is_open():
		return
	_tick += delta
	# Les activités changent avec l'heure : on rafraîchit régulièrement
	# (sauf la liste, où l'on tape une recherche, et pendant qu'un menu est ouvert).
	if view == "liste" or _tick < (1.0 if view != "ville" else 3.0):
		return
	for o in _popups:
		if is_instance_valid(o) and (((o as ChoixVisuel).est_ouvert()) if o is ChoixVisuel else (o.call("get_popup") as PopupMenu).visible):
			return
	if true:
		_tick = 0.0
		var keep := _scroll.scroll_vertical
		refresh()
		_scroll.set_deferred("scroll_vertical", keep)


func refresh() -> void:
	if pop == null:
		return
	_popups.clear()
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	_back.disabled = _history.is_empty() and view == "ville"
	_tabs.visible = view != "batiment"
	_dest = null
	_scroll.custom_minimum_size.y = H
	match view:
		"ville":
			_view_city()
		"liste":
			_view_list()
		"funeraire":
			FuneraireVue.remplir(self)
		"batiment":
			if pop.known.has(view_arg):
				_view_building(view_arg)
			else:
				view = "ville"
				_view_city()
		"profil":
			if pop.persons.has(view_arg):
				_view_profile(view_arg)
			elif pop.vie.archive.has(view_arg):
				_view_archive(view_arg)
			else:
				_title.text = "Habitant parti"
				_text("Cet habitant n'est plus dans la ville.", true)
	# Fiche d'un bâtiment : le panneau s'arrête sous la dernière rubrique (pas de
	# grand vide sous une fiche courte).
	if view == "batiment":
		_ajuster_hauteur.call_deferred()


func _ajuster_hauteur() -> void:
	if view != "batiment" or not is_instance_valid(_body):
		return
	_scroll.custom_minimum_size.y = clampf(_body.get_combined_minimum_size().y + 6.0, 120.0, H)
	_panel.reset_size()


# --- Petits outils d'interface ----------------------------------------------------

func _text(t: String, dim := false, size := 13) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(W - 30, 0)
	l.add_theme_font_size_override("font_size", size)
	if dim:
		l.add_theme_color_override("font_color", Color(1, 1, 1, 0.65))
	_cible().add_child(l)
	return l


func _cible() -> Control:
	return _dest if _dest != null and is_instance_valid(_dest) else _body


## Rubrique repliable de la fiche d'un bâtiment : une ligne-titre cliquable
## (flèche, titre, résumé en gris). Rend vrai si elle est dépliée : les lignes
## suivantes vont alors dans son corps, jusqu'à _fin_repli().
func _repli(id: String, titre: String, resume := "") -> bool:
	_dest = null
	var ouverte := bool(ouvertes.get(id, false))
	var b := Button.new()
	b.name = "Repli_" + id
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.custom_minimum_size = Vector2(W - 30, 30)
	b.icon = Icones.get_icon("bas" if ouverte else "suivant", 16, Color("ffd166"))
	b.text = titre + (("  ·  " + resume) if resume != "" else "")
	b.tooltip_text = ("Clic : replier" if ouverte else "Clic : voir le détail") + ((" (%s)" % resume) if resume != "" else "")
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_color_override("font_color", Color("ffd166"))
	b.add_theme_color_override("font_hover_color", Color("ffe29a"))
	b.add_theme_stylebox_override("normal", UiStyle.flat_box(Color(1, 1, 1, 0.05), 6, 4))
	b.add_theme_stylebox_override("hover", UiStyle.flat_box(Color(1, 1, 1, 0.11), 6, 4))
	b.add_theme_stylebox_override("pressed", UiStyle.flat_box(Color(1, 1, 1, 0.11), 6, 4))
	b.pressed.connect(func() -> void: basculer_rubrique(id))
	_body.add_child(b)
	if not ouverte:
		return false
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 10)
	m.add_theme_constant_override("margin_bottom", 4)
	_body.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	m.add_child(v)
	_dest = v
	return true


func _fin_repli() -> void:
	_dest = null


## Déplie ou replie une rubrique de la fiche (choix gardé pour les autres bâtiments).
func basculer_rubrique(id: String) -> void:
	ouvertes[id] = not bool(ouvertes.get(id, false))
	var cfg := ConfigFile.new()
	cfg.load(CFG)
	cfg.set_value("fiche", id, ouvertes[id])
	cfg.save(CFG)
	var keep := _scroll.scroll_vertical
	refresh()
	_scroll.set_deferred("scroll_vertical", keep)


func _section(t: String) -> void:
	_cible().add_child(HSeparator.new())
	var l := _text(t, false, 15)
	l.add_theme_color_override("font_color", Color("ffd166"))


func _link(t: String, cb: Callable, tip := "") -> Button:
	var b := Button.new()
	b.text = t
	b.flat = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = tip
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.custom_minimum_size = Vector2(W - 30, 0)
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_color_override("font_color", Color("a8dadc"))
	b.pressed.connect(cb)
	_cible().add_child(b)
	return b


func _person_link(pid: int, extra := "") -> void:
	if not pop.persons.has(pid):
		var f: Dictionary = pop.vie.archive.get(pid, {})
		if f.is_empty():
			return
		var dead: bool = String(f.fin) == "deces"
		var t2 := "%s %s%s%s" % [f.p, f.n, (", mort%s à %d ans" % [CycleVie.g(f, "", "e"), floori(pop.vie.age_of(f))]) if dead
			else " · a quitté la ville", (" · " + extra) if extra != "" else ""]
		_link(("† " if dead else "→ ") + t2, func() -> void: show_view("profil", pid)).add_theme_color_override("font_color", Color(0.75, 0.8, 0.85))
		return
	var p: Dictionary = pop.persons[pid]
	var t := "%s %s, %d ans · %s" % [p.p, p.n, pop.age_years(p), pop.stage_label(p)]
	if extra != "":
		t += " · " + extra
	_link(("★ " if pop.followed() == pid else ("♀ " if p.s == "F" else "♂ ")) + t, func() -> void: show_view("profil", pid))


func _building_link(prefix: String, bid: int) -> void:
	if bid < 0 or not pop.known.has(bid):
		_text(prefix + "—", true)
		return
	_link(prefix + pop.building_name(bid) + "  ↗", func() -> void:
		focus_requested.emit(pop.building_pos(bid))
		show_view("batiment", bid)
		pop.select_building(bid), "Voir le bâtiment et y aller")


## Jauge de la fiche : « Logements  ▓▓▓▓░  12/12 ».
func _gauge(parent: Control, label: String, value: int, total: int) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(74, 0)
	l.add_theme_font_size_override("font_size", 13)
	row.add_child(l)
	var bar := ProgressBar.new()
	bar.max_value = maxi(total, 1)
	bar.value = value
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(90, 10)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_theme_stylebox_override("background", UiStyle.flat_box(Color(1, 1, 1, 0.12), 5, 0))
	var fill := UiStyle.flat_box(UiStyle.GOOD if value < total or total == 0 else Color("6fcf8b"), 5, 0)
	bar.add_theme_stylebox_override("fill", fill)
	row.add_child(bar)
	var v := Label.new()
	v.text = "%d/%d" % [value, total]
	v.custom_minimum_size = Vector2(52, 0)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_theme_font_size_override("font_size", 13)
	row.add_child(v)


static func money(v: float) -> String:
	return BuildingSystem.format_money(roundi(v))


# --- Vues --------------------------------------------------------------------------

func _view_city() -> void:
	_title.text = "Habitants · la ville"
	var s := pop.stats()
	var n: Dictionary = pop.now()
	_text("%d habitants dans %d foyers · satisfaction moyenne %d / 100" % [s.habitants, s.foyers, s.satisfaction], false, 14)
	_text("Clique un bâtiment de la carte (outil 1 · Observer) pour voir qui y vit, y travaille ou y étudie.", true, 12)
	_section("Population")
	var adults: int = s.actif + s.chomeur
	for row in [["bebe", "Bébés (0-2 ans)"], ["eleve", "Élèves"], ["apprenti", "Apprentis (CFC, CAP)"], ["etudiant", "Étudiants (hautes écoles, université)"],
			["actif", "Actifs avec emploi"], ["chomeur", "Sans emploi"], ["retraite", "Retraités (64 ans et plus)"]]:
		var key: String = row[0]
		var cnt: int = s[key]
		_link("%s : %d" % [row[1], cnt], func() -> void:
			_filter = key
			show_view("liste"), "Voir la liste")
	_text("Chômage : %s · enfants sans école : %d" % ["—" if adults == 0 else "%d %%" % roundi(100.0 * s.chomeur / adults), s.sans_ecole])
	_text("Logements : %d occupés sur %d · emplois : %d pourvus sur %d · places d'école : %d sur %d" % [
		s.foyers, s.logements, s.actif, s.emplois, s.eleve - s.sans_ecole, s.places], true)
	_section("La vie en ville")
	var t: Dictionary = pop.vie.totals
	_text("Naissances : %d · décès : %d%s" % [int(t.naissances), int(t.deces),
		(" · âge moyen au décès : %d ans" % roundi(float(t.age_deces) / int(t.deces))) if int(t.deces) > 0 else ""])
	_text("Couples formés : %d · mariages : %d · PACS : %d · séparations : %d · départs : %d" % [int(t.couples), int(t.mariages),
		int(t.pacs), int(t.separations), int(t.departs)], true, 12)
	var me := pop.principal.mine()
	if me >= 0:
		var mp: Dictionary = pop.persons[me]
		_link("★ Ton personnage : %s, %d ans" % [CycleVie.full_name(mp), pop.age_years(mp)], func() -> void: show_view("profil", me))
	elif pop.principal.enabled:
		_text("Ton personnage naîtra dans la première famille installée en ville (un couple avec une femme de 18 à 45 ans).", true, 12)
	if pop.followed() >= 0:
		var fp: Dictionary = pop.persons[pop.followed()]
		_link("★ Tu suis %s %s" % [fp.p, fp.n], func() -> void: show_view("profil", pop.followed()))
	else:
		_text("Ouvre la fiche d'un habitant et clique « ☆ Suivre » pour vivre sa vie de près.", true, 12)
	_link("Défunts et anciens habitants : %d" % pop.vie.archive.size(), func() -> void:
		_filter = "defunts"
		show_view("liste"), "Leurs fiches restent consultables")
	_section("Budget de la ville (par mois)")
	var b := pop.city_budget()
	for k in b.recettes:
		_text("+ %s : %s" % [k, money(b.recettes[k])])
	for k in b.depenses:
		_text("− %s : %s" % [k, money(b.depenses[k])])
	var sol: float = b.solde
	var l := _text("Solde : %s%s par mois" % ["+" if sol >= 0 else "", money(sol)], false, 14)
	l.add_theme_color_override("font_color", Color("95d5b2") if sol >= 0 else Color("ff8f8f"))
	if pop.buildings != null and pop.buildings.unlimited_money:
		_text("Argent illimité : la caisse ne bouge pas.", true, 12)
	else:
		_text("Le solde est versé chaque jour de jeu dans la caisse (jour %d du mois de comptes)." % int(pop.ledger.jours), true, 12)
	var prev: Dictionary = pop.ledger.precedent
	if not prev.is_empty():
		var tot := 0.0
		for k in prev:
			tot += float(prev[k])
		_text("Mois précédent : %s%s" % ["+" if tot >= 0 else "", money(tot)], true)
	_section("Réglages")
	var row := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = "Vitesse de la vie :"
	row.add_child(lbl)
	var pick := ChoixVisuel.new()
	pick.icone = "horloge"
	pick.gradue = 1
	pick.focus_mode = Control.FOCUS_NONE
	for i in Population.LIFE_SPEED_NAMES.size():
		pick.add_item(Population.LIFE_SPEED_NAMES[i], i)
	pick.select(pop.life_speed_index)
	pick.fit_to_longest_item = false
	pick.clip_text = true
	pick.custom_minimum_size = Vector2(180, 0)
	pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pick.tooltip_text = "Vieillissement, naissances et décès. Les horaires suivent toujours l'horloge du jeu."
	pick.item_selected.connect(func(i: int) -> void: pop.life_speed_index = i)
	_popups.append(pick)
	row.add_child(pick)
	_body.add_child(row)
	var arr := CheckBox.new()
	arr.text = "Nouveaux habitants dans les logements libres"
	arr.focus_mode = Control.FOCUS_NONE
	arr.button_pressed = pop.arrivals
	arr.toggled.connect(func(on: bool) -> void: pop.arrivals = on)
	_body.add_child(arr)
	const DAYS := ["dimanche", "lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi"]
	_text("Nous sommes %s, %02d h %02d. Le mercredi après-midi, les week-ends, juillet et août, pas d'école." % [
		DAYS[int(n.wd)], int(n.h), int(fmod(float(n.h), 1.0) * 60.0)], true, 12)


func _view_list() -> void:
	_title.text = "Habitants · liste"
	var row := HBoxContainer.new()
	var pick := ChoixVisuel.new()
	pick.gradue = 0
	pick.focus_mode = Control.FOCUS_NONE
	var keys := ["", "bebe", "eleve", "apprenti", "etudiant", "actif", "chomeur", "retraite", "defunts"]
	for i in keys.size():
		pick.add_item("Tout le monde" if keys[i] == "" else ("Défunts et partis" if keys[i] == "defunts" else String(Population.STAGE_NAMES[keys[i]])), i)
		if keys[i] == _filter:
			pick.select(i)
	pick.item_selected.connect(func(i: int) -> void:
		_filter = keys[i]
		refresh())
	row.add_child(pick)
	var search := LineEdit.new()
	search.placeholder_text = "Nom ou prénom…"
	search.text = _search
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.text_submitted.connect(func(t: String) -> void:
		_search = t
		refresh())
	row.add_child(search)
	_body.add_child(row)
	var shown := 0
	var total := 0
	var needle := _search.to_lower()
	if _filter == "defunts":
		var ids: Array = pop.vie.archive.keys()
		for i in range(ids.size() - 1, -1, -1):
			var f: Dictionary = pop.vie.archive[ids[i]]
			if needle != "" and not ("%s %s" % [f.p, f.n]).to_lower().contains(needle):
				continue
			total += 1
			if shown < 150:
				_person_link(int(ids[i]))
				shown += 1
		if total == 0:
			_text("Personne n'est encore mort ni parti.", true)
		elif total > shown:
			_text("… et %d autres (affine la recherche)." % (total - shown), true)
		return
	for pid in pop.persons:
		var p: Dictionary = pop.persons[pid]
		if _filter != "" and pop.stage(p) != _filter:
			continue
		if needle != "" and not ("%s %s" % [p.p, p.n]).to_lower().contains(needle):
			continue
		total += 1
		if shown < 150:
			_person_link(pid, String(pop.activity(p).text))
			shown += 1
	if total == 0:
		_text("Personne pour l'instant. Construis des logements (B) : les habitants emménagent quand le temps avance.", true)
	elif total > shown:
		_text("… et %d autres (affine la recherche)." % (total - shown), true)


## Deux grandes tuiles illustrées sous la fiche : « Modifier la façade » (style,
## couleurs, toit, étages, avec un devis) et « Aménager l'intérieur » (pièces et
## meubles ; un bâtiment du catalogue est d'abord ouvert en murs fins).
func _tuiles_travaux(bid: int, info: Dictionary) -> void:
	var tid := String(info.t)
	var b: Dictionary = pop.buildings.buildings.get(bid, {}) if pop.buildings != null else {}
	var facade := not info.has("plan") and Personnalisation.can_customize(tid)
	var interieur := info.has("plan") or Conversion.can_open(tid, b.get("perso", {}))
	var genre := GestionTypes.genre_de(tid) if not info.has("plan") else ""
	if genre != "" and pop.buildings != null and not pop.buildings.en_chantier(bid):
		var gd := GestionTypes.genre(genre)
		var g := _tuile(String(gd.get("titre", "Gérer")), "Mode gestion", String(gd.get("icone", "lit")),
			String(gd.get("tuile_tip", "Entre dans le bâtiment en vue isométrique : améliore les pièces, regarde le personnel et les clients, règle leurs demandes.\nLes résultats comptent dans la ville (lits, note, étoiles, taxe de séjour, impôts).")))
		g.name = "TuileGestion"
		g.pressed.connect(func() -> void: gestion_requested.emit(bid))
		_body.add_child(g)
	if not facade and not interieur:
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_body.add_child(row)
	if facade:
		var f := _tuile("Modifier la façade", "Style, couleurs, toit, étages", "peinture",
			"Change le style, les couleurs (murs, toit, volets, porte…), la forme du toit et les étages de ce bâtiment.\nTu vois le résultat tout de suite, avec le devis des travaux à valider.")
		f.name = "TuileFacade"
		f.pressed.connect(func() -> void: customize_requested.emit(bid))
		row.add_child(f)
	if interieur:
		var sous := "Pièces, murs, meubles" if info.has("plan") else "Ouvrir et meubler"
		var tip := "Meubles, pièces, murs : ouvre l'onglet Intérieur sur ce bâtiment." if info.has("plan") else \
			"Le bâtiment est refait en vrais murs (portes, escaliers, toit) avec ses couleurs, découpé en pièces et meublé.\nLe prix du bâtiment est repris ; tu paies les murs et les meubles. Ensuite : onglet Intérieur, entre avec V."
		var i := _tuile("Aménager l'intérieur", sous, "interieur", tip)
		i.name = "TuileInterieur"
		i.pressed.connect(func() -> void:
			if info.has("plan"):
				furnish_requested.emit(bid)
			else:
				interior_requested.emit(bid))
		row.add_child(i)


func _tuile(titre: String, sous: String, icone: String, tip: String) -> Button:
	var t := Button.new()
	t.text = "%s\n%s" % [titre, sous]
	t.icon = Icones.get_icon(icone if Icones.has_icon(icone) else "construire", 34, UiStyle.ACCENT)
	t.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	t.expand_icon = false
	t.custom_minimum_size = Vector2(0, 78)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.add_theme_font_size_override("font_size", 13)
	t.focus_mode = Control.FOCUS_NONE
	t.tooltip_text = tip
	return t


## Agrandissement (3 niveaux) et rénovation d'un bâtiment (Ameliorations).
func _fiche_amelioration(bid: int) -> void:
	var am := Ameliorations.instance
	if am == null or not am.buildings.buildings.has(bid):
		return
	var b: Dictionary = am.buildings.buildings[bid]
	var tid := String(b.t)
	var niv := Ameliorations.niveau(b)
	var ok_type := Ameliorations.ameliorable(tid)
	if not ok_type and am.usure(bid) < Ameliorations.USURE_RENOV:
		return
	var usure := am.usure(bid)
	var etat := "neuf" if usure < 0.1 else ("bon" if usure < 0.3 else ("usé" if usure < 0.6 else "très usé"))
	var a := am.en_cours(bid)
	var resume := "état %s" % etat
	if not a.is_empty():
		resume = "%s %d %%" % ["agrandissement" if String(a.op) == "niv" else "rénovation", floori(float(a.av) * 100.0)]
	if not _repli("travaux", ("Agrandissement · niveau %d sur %d" % [niv, Ameliorations.NIVEAU_MAX]) if ok_type else "Entretien", resume):
		return
	if ok_type:
		_text("Capacité : %s%s" % [am.texte_capacites(bid), " (×%s)" % str(Ameliorations.facteur(b)).replace(".", ",") if niv > 1 else ""], true, 12)
	if TaillesBatiments.est_taille(String(b.t)):
		_text("Taille choisie : %s" % TaillesBatiments.texte_taille(String(b.t)), true, 12)
	_text("État : %s" % etat, true, 12)
	if not a.is_empty():
		var quoi := "Agrandissement au niveau %d" % int(a.cible) if String(a.op) == "niv" else "Rénovation"
		var txt := "%s : %d %%" % [quoi, floori(float(a.av) * 100.0)]
		if a.get("attente", false):
			txt += " · arrêté, la caisse est vide"
		else:
			txt += " · fin vers le %s" % am._date_fin(bid)
		if bool(a.get("prive", false)):
			txt += " · payé par les propriétaires"
		_text(txt, false, 13)
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	if ok_type and niv < Ameliorations.NIVEAU_MAX:
		var cible := niv + 1
		var up := Button.new()
		up.text = "Agrandir · %s" % ("payé par le propriétaire" if am.prive(bid) else BuildingSystem.format_money(am.cout(bid, cible)))
		up.icon = Icones.get_icon("construire", 18)
		up.focus_mode = Control.FOCUS_NONE
		var why := am.refus_agrandir(bid)
		up.disabled = why != ""
		up.tooltip_text = "Niveau %d : %s (au lieu de %s).\nUn étage de plus, chantier d'environ %s, %s. Le bâtiment reste ouvert pendant les travaux.%s" % [
			cible, am.texte_capacites(bid, cible), am.texte_capacites(bid), Chantiers.duree_texte(am.duree_prevue(bid, cible)),
			"payé par son propriétaire privé (rien pour la ville)" if am.prive(bid) else "payé au fil des travaux", ("\n" + why) if why != "" else ""]
		up.pressed.connect(func() -> void:
			am.agrandir(bid)
			refresh())
		row.add_child(up)
	var why_r := am.refus_renover(bid)
	if usure >= Ameliorations.USURE_RENOV:
		var re := Button.new()
		re.text = "Rénover · %s" % ("payé par le propriétaire" if am.prive(bid) else BuildingSystem.format_money(am.cout(bid, 0)))
		re.icon = Icones.get_icon("peinture", 18)
		re.focus_mode = Control.FOCUS_NONE
		re.disabled = why_r != ""
		re.tooltip_text = "Façade et toit refaits à neuf : l'usure repart de zéro. Chantier d'environ %s.%s" % [
			Chantiers.duree_texte(am.duree_prevue(bid, 0)), ("\n" + why_r) if why_r != "" else ""]
		re.pressed.connect(func() -> void:
			am.renover(bid)
			refresh())
		row.add_child(re)
	if row.get_child_count() > 0:
		_cible().add_child(row)
	elif niv >= Ameliorations.NIVEAU_MAX:
		_text("Agrandi au maximum.", true, 12)


func _view_building(bid: int) -> void:
	var info: Dictionary = pop.known[bid]
	_title.text = pop.building_name(bid)
	var t := BuildingCatalog.get_type(String(info.t))
	var cat := BuildingCatalog.category(String(info.cat))
	_text("%s · %s" % [String(cat.get("name", info.cat)), String(t.get("desc", ""))], true, 12)
	if info.has("conf"):
		_text("Intérieur aménagé · confort %d · attractivité %d · valeur %s" % [int(info.conf), int(info.attr), BuildingSystem.format_money(int(info.valeur))], true, 12)
	# Lignes ajoutées par d'autres systèmes (cimetière : tombes et défunts…).
	for n in get_tree().get_nodes_in_group("fiche_batiment"):
		for l in n.fiche_lignes(bid):
			if int(l[1]) >= 0:
				var who := int(l[1])
				_link(String(l[0]), func() -> void: show_view("profil", who))
			else:
				var lb := _text(String(l[0]), false, 13)
				if l.size() > 2 and l[2] is Color:
					lb.add_theme_color_override("font_color", l[2])
	var here := pop.present_in(bid)
	# Fiche : icône de la catégorie, jauges d'occupation, bouton « Aller voir ».
	var card := HBoxContainer.new()
	card.add_theme_constant_override("separation", 10)
	_body.add_child(card)
	var ic := TextureRect.new()
	ic.texture = Icones.get_icon(String(BuildingPanel.CAT_ICONS.get(String(info.cat), "construire")), 40, UiStyle.ACCENT)
	ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	ic.custom_minimum_size = Vector2(52, 52)
	card.add_child(ic)
	var gauges := VBoxContainer.new()
	gauges.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gauges.add_theme_constant_override("separation", 4)
	card.add_child(gauges)
	if int(info.log) > 0:
		_gauge(gauges, "Logements", (pop.by_home.get(bid, []) as Array).size(), int(info.log))
	if int(info.emp) > 0:
		_gauge(gauges, "Employés", (pop.by_job.get(bid, []) as Array).size(), int(info.emp))
	if int(info.seats) > 0:
		_gauge(gauges, "Élèves", (pop.by_school.get(bid, []) as Array).size(), int(info.seats))
	var now_l := Label.new()
	now_l.text = "En ce moment : %d personne%s" % [here.size(), "s" if here.size() > 1 else ""]
	now_l.add_theme_font_size_override("font_size", 13)
	gauges.add_child(now_l)
	_pastilles_reseaux(gauges, bid)
	var go := Button.new()
	go.text = "Aller voir"
	go.icon = Icones.get_icon("lieu", 18)
	go.focus_mode = Control.FOCUS_NONE
	go.pressed.connect(func() -> void: focus_requested.emit(info.pos))
	var acts := HBoxContainer.new()
	acts.add_child(go)
	if isolement != null and is_instance_valid(isolement):
		var iso := Button.new()
		iso.name = "Isoler"
		var seul := bool(isolement.call("actif"))
		iso.text = "Toute la ville" if seul else "Isoler"
		iso.icon = Icones.get_icon("oeil", 18)
		iso.focus_mode = Control.FOCUS_NONE
		iso.tooltip_text = "Revoir toute la ville autour (Échap ferme la fiche et rétablit tout)" if seul \
			else "Ne voir que ce bâtiment : la ville pâlit, les cartes se rangent"
		iso.pressed.connect(func() -> void: isolement.call("basculer"))
		acts.add_child(iso)
	_body.add_child(acts)
	_tuiles_travaux(bid, info)
	# Le détail, rubrique par rubrique (repliées au départ : un clic sur le titre déplie).
	if Reseaux.instance != null and Reseaux.instance.raccordements != null and is_instance_valid(Reseaux.instance):
		var rac := Reseaux.instance.raccordements
		var etats := rac.etat_reseaux(bid)
		if not etats.is_empty():
			var mal := 0
			for e in etats:
				if e[2] == Raccordements.COULEUR_NON or e[2] == Raccordements.COULEUR_COUPE or e[2] == Color("e63946"):
					mal += 1
			if _repli("reseaux", "Réseaux", "tout va bien" if mal == 0 else ("%d souci%s" % [mal, "s" if mal > 1 else ""])):
				rac.remplir_fiche(_cible(), bid, W - 10)
			_fin_repli()
	_fiche_amelioration(bid)
	_fin_repli()
	if int(info.log) > 0:
		var homes: Array = pop.by_home.get(bid, [])
		var n := 0
		for hid in homes:
			n += (pop.households[hid].m as Array).size()
		if _repli("habitants", "Habitants", "%d dans %d logement%s sur %d" % [n, homes.size(), "s" if homes.size() > 1 else "", int(info.log)]):
			var shown := 0
			for hid in homes:
				if shown >= 60:
					_text("… et d'autres foyers.", true)
					break
				var h: Dictionary = pop.households[hid]
				var bud := pop.household_budget(hid)
				_text("Foyer %s · %s/mois de revenus · épargne %s%s" % [pop.persons[h.m[0]].n if not (h.m as Array).is_empty() else "",
					money(bud.revenus), money(h.ep), (" · " + NiveauxVie.nom(NiveauxVie.niveau(h)).to_lower()) if NiveauxVie.niveau(h) >= 0 else ""], true, 12)
				for pid in h.m:
					_person_link(pid, String(pop.activity(pop.persons[pid]).text))
				shown += 1
			if homes.is_empty():
				_text("Personne n'a encore emménagé. Laisse avancer le temps (T, Maj + T).", true)
		_fin_repli()
	if int(info.seats) > 0:
		var pupils: Array = pop.by_school.get(bid, [])
		var at_school := 0
		for pid in pupils:
			if pop.activity(pop.persons[pid]).kind == "ecole":
				at_school += 1
		if _repli("eleves", "Élèves", "%d inscrits sur %d · %d en classe" % [pupils.size(), int(info.seats), at_school]):
			var levels := {}
			var sys := pop.edu.systeme_batiment(bid)
			for pid in pupils:
				var lv := pop.edu.cycle(pop.persons[pid])
				levels[lv] = int(levels.get(lv, 0)) + 1
			var parts := []
			for lv in SystemesScolaires.CYCLES:
				if levels.has(lv):
					parts.append("%s : %d" % [pop.edu.nom_cycle(lv, sys), levels[lv]])
			if not parts.is_empty():
				_text(" · ".join(parts), true, 12)
			var shown := 0
			for pid in pupils:
				if shown >= 120:
					_text("… et %d autres." % (pupils.size() - shown), true)
					break
				_person_link(pid, String(pop.activity(pop.persons[pid]).text))
				shown += 1
		_fin_repli()
	if int(info.emp) > 0:
		var staff: Array = pop.by_job.get(bid, [])
		if _repli("employes", "Employés", "%d sur %d postes" % [staff.size(), int(info.emp)]):
			if pop.effectif != null and pop.effectif.concerne(bid):
				_text(pop.effectif.resume(bid), true, 13)
				for c in pop.effectif.consequences(bid):
					_text("  " + String(c), true, 12)
			var shown := 0
			for pid in staff:
				if shown >= 120:
					_text("… et %d autres." % (staff.size() - shown), true)
					break
				var g := Gestes.de_personne(pop, pid)
				_person_link(pid, String(pop.activity(pop.persons[pid]).text) + ((" · " + g) if g != "" else ""))
				shown += 1
			if staff.is_empty():
				var fd := Fondateurs.instance
				if fd != null and fd.regle_active() and fd.camp >= 0 and Fondateurs.est_vital(info):
					_text("Aucun employé : des fondateurs du campement viennent le tenir dès demain matin (Maj+H pour en envoyer tout de suite).", true)
				elif fd != null and fd.regle_active() and fd.camp >= 0:
					_text("Aucun employé : il faut des habitants sans emploi en ville, ou des fondateurs sans chantier (Maj+H → Affecter les fondateurs).", true)
				else:
					_text("Aucun employé : il faut des habitants sans emploi en ville.", true)
		_fin_repli()
	var visitors := []
	for pid in here:
		var k := String(pop.activity(pop.persons[pid]).kind)
		if k == "loisir" or k == "courses":
			visitors.append(pid)
	if not visitors.is_empty():
		if _repli("visiteurs", "Visiteurs", "%d en ce moment" % visitors.size()):
			for i in mini(visitors.size(), 60):
				_person_link(visitors[i], String(pop.activity(pop.persons[visitors[i]]).text))
		_fin_repli()
	if int(info.log) == 0 and int(info.seats) == 0 and int(info.emp) == 0 and visitors.is_empty():
		_text("Ce bâtiment n'accueille ni habitants, ni employés, ni élèves.", true)


## Fiche courte : une pastille par réseau (couleur de son état, détail en
## infobulle) et le bouton qui montre le flux sur les routes.
func _pastilles_reseaux(parent: Control, bid: int) -> void:
	if Reseaux.instance == null or not is_instance_valid(Reseaux.instance) or Reseaux.instance.raccordements == null:
		return
	var rac := Reseaux.instance.raccordements
	if rac.etat_reseaux(bid).is_empty():
		return
	var row := HBoxContainer.new()
	row.name = "PastillesReseaux"
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)
	rac.remplir_pastilles(row, bid)
	var fl := Reseaux.instance.flux
	if fl == null or fl.reseaux_de(bid).is_empty():
		return
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)
	var b := Button.new()
	b.name = "VoirFlux"
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.set_pressed_no_signal(fl.montre_batiment(bid))
	b.text = "Sur les routes"
	b.icon = Icones.get_icon("reseaux", 16)
	b.add_theme_font_size_override("font_size", 12)
	b.tooltip_text = ("Cacher le flux des réseaux sur les routes" if b.button_pressed else "Voir le courant, l'eau et les égouts circuler sur les routes jusqu'à ce bâtiment") \
		+ "\n" + Raccordements.LEGENDE_FLUX
	b.toggled.connect(func(_on: bool) -> void:
		fl.basculer_batiment(bid)
		refresh())
	row.add_child(b)


func _view_profile(pid: int) -> void:
	var p: Dictionary = pop.persons[pid]
	var h: Dictionary = pop.households[int(p.f)]
	var age := pop.age_years(p)
	_title.text = "%s %s" % [p.p, p.n]
	_follow_row(pid)
	_text("%s · %d ans · %s" % ["Femme" if p.s == "F" and age >= 18 else ("Fille" if p.s == "F" else ("Homme" if age >= 18 else "Garçon")),
		age, pop.stage_label(p)], false, 14)
	var a := pop.activity(p)
	_text("Maintenant : %s" % a.text, false, 14)
	var geste := Gestes.de_personne(pop, pid)
	if geste != "":
		_text("À son poste, %s %s." % [String(p.p), geste], true, 13)
	if int(a.bid) >= 0 and pop.known.has(int(a.bid)):
		_building_link("Où : ", int(a.bid))
		if pop.effectif != null and pop.effectif.concerne(int(a.bid)) and String(a.kind) == "travail":
			_text("Personnel : " + pop.effectif.resume(int(a.bid)), true, 12)
	var sat := pop.satisfaction(p)
	_text("Satisfaction : %d / 100" % int(sat.value))
	if not (sat.why as Array).is_empty():
		_text("  " + "\n  ".join(sat.why), true, 12)

	_section("Foyer")
	_building_link("Logement : ", int(h.b))
	for m in h.m:
		if m == pid:
			continue
		var q: Dictionary = pop.persons[m]
		var rel := _relation(p, q)
		_person_link(m, rel)
	if (h.m as Array).size() == 1:
		_text("Vit seul·e.", true)
	var bud := pop.household_budget(int(p.f))
	_text("Budget du foyer par mois : revenus %s · loyer %s · courses %s%s%s" % [money(bud.revenus), money(bud.loyer), money(bud.courses),
		(" · voiture%s %s" % ["s" if int(h.car) > 1 else "", money(bud.voitures)]) if int(h.car) > 0 else "",
		(" · sorties %s" % money(float(bud.get("sorties", 0.0)))) if float(bud.get("sorties", 0.0)) > 0.0 else ""], true, 12)
	var sol: float = bud.solde
	_text("Reste %s%s par mois · épargne %s · %s" % ["+" if sol >= 0 else "", money(sol), money(h.ep),
		"%d voiture%s" % [int(h.car), "s" if int(h.car) > 1 else ""] if int(h.car) > 0 else "pas de voiture"], true, 12)
	if NiveauxVie.instance != null and NiveauxVie.instance.population == pop:
		var nl := _text(NiveauxVie.instance.texte_foyer(int(p.f)), false, 12)
		nl.add_theme_color_override("font_color", NiveauxVie.couleur(NiveauxVie.niveau(h)))
		var mq := NiveauxVie.instance.texte_manques(int(p.f))
		if mq != "":
			_text(mq, true, 11)

	var st := pop.stage(p)
	if st == "eleve":
		_section("École")
		if int(p.sch) >= 0:
			_building_link("", int(p.sch))
			_text("Classe : %s (%s)" % [pop.edu.classe(p), pop.edu.nom_cycle(pop.edu.cycle(p), pop.edu.systeme(p))])
			var c := pop.commute(p, int(h.b), int(p.sch))
			_text("Trajet : %d min %s" % [int(c.min), c.mode], true)
			if c.has("detail"):
				_text("Itinéraire : " + String(c.detail), true, 12)
			_text("Lundi, mardi, jeudi, vendredi de 8 h 30 à 16 h 30, mercredi matin.", true, 12)
		else:
			_text(pop.edu.libelle(p), true)
			if pop.edu.sans_ecole(p):
				_text("Aucune place libre pour ce degré (%s) : construis l'école qui l'accueille (B → Services publics)." % pop.edu.nom_cycle(pop.edu.cycle(p), pop.edu.systeme(p)), true)
	elif st == "apprenti" or st == "etudiant":
		_section("Formation")
		_text(pop.edu.libelle(p), true)
		if int(p.job) >= 0:
			_building_link("Entreprise formatrice : ", int(p.job))
			_text("Salaire d'apprenti : %s net par mois · 4 jours chez l'employeur, le mardi à l'école professionnelle." % money(pop.income_of(p)), true, 12)
		if int(p.sch) >= 0:
			_building_link("École : ", int(p.sch))
		var fin := float(p.get("apf", -1.0)) if st == "apprenti" else float(p.get("etu", -1.0))
		if fin > pop.life_clock:
			_text("Diplôme prévu dans %.1f an%s." % [(fin - pop.life_clock) / 365.25, "s" if (fin - pop.life_clock) / 365.25 >= 2.0 else ""], true, 12)
	elif st == "actif" or st == "chomeur":
		_section("Travail")
		if int(p.job) >= 0:
			var j := Metiers.job(String(p.met))
			_text("%s · %s net par mois%s" % [j.name, money(float(j.salaire) * ReglagesPartie.actuel.salaires),
				" (payé par l'État)" if bool(j.get("etat", false)) else (" (payé par la ville)" if bool(j.get("public", false)) else "")])
			_building_link("Lieu : ", int(p.job))
			_text("Diplôme exigé : %s%s" % [SystemesScolaires.texte_exigence(String(p.met), pop.edu.annee()),
				" · embauché%s sans ce diplôme : travaille moins vite" % CycleVie.g(p, "", "e") if bool(p.get("nq", false)) else ""], true, 12)
			const JOURS := {"semaine": "du lundi au vendredi", "lunsam": "du lundi au samedi", "marsam": "du mardi au samedi",
				"tous": "tous les jours", "garde": "un jour sur deux (gardes de 12 h)", "ecole": "les jours d'école"}
			_text("Horaires : %s, %s" % [_hours(float(j.h[0]), float(j.h[1])), JOURS.get(String(j.j), "")], true)
			var c := pop.commute(p, int(h.b), int(p.job))
			_text("Trajet : %d min %s (%.1f km)" % [int(c.min), c.mode, float(c.m) / 1000.0], true)
			if c.has("detail"):
				_text("Itinéraire : " + String(c.detail), true, 12)
		else:
			_text("Cherche un emploi (allocation %s par mois). Construis des commerces, bureaux, usines ou services." % money(Population.ALLOCATION), true)
	elif st == "retraite":
		_section("Retraite")
		_text("Pension : %s par mois." % money(Population.PENSION), true)

	_section("Loisirs")
	if (p.hob as Array).is_empty():
		_text("Aucun loisir.", true)
	for hb in p.hob:
		var lo: Dictionary = Metiers.LOISIRS[hb]
		if (lo.lieux as Array).is_empty():
			_text("%s · à la maison" % lo.name)
			continue
		var v := pop.venue_for(p, hb)
		if v >= 0:
			_building_link("%s · " % lo.name, v)
		else:
			_text("%s · pas de lieu en ville pour l'instant" % lo.name, true)

	_section("Sa journée d'aujourd'hui")
	var n := pop.now()
	for seg in pop.day_plan(p, n):
		if float(seg[1]) - float(seg[0]) < 0.01:
			continue
		var now_mark: bool = n.h >= float(seg[0]) and n.h < float(seg[1])
		var l := _text("%s%s  %s" % ["▶ " if now_mark else "   ", _hours(float(seg[0]), float(seg[1])), seg[4]], not now_mark, 12)
		if now_mark:
			l.add_theme_color_override("font_color", Color("ffd166"))
	_orders_section(pid)
	_life_sections(p)


# --- Cycle de vie : suivi, famille, santé, CV ----------------------------------------

func _follow_row(pid: int) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_body.add_child(row)
	var on := pop.followed() == pid
	var b := Button.new()
	b.text = "★ Suivi%s" % CycleVie.g(pop.persons[pid], "", "e") if on else "☆ Suivre"
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = "Suivre cet habitant façon Sims : repère au-dessus de lui, caméra qui l'accompagne, nouvelles de sa vie."
	b.toggle_mode = true
	b.button_pressed = on
	b.pressed.connect(func() -> void:
		pop.follow(-1 if on else pid)
		refresh())
	row.add_child(b)
	var inc := Button.new()
	inc.text = "Prendre sa place (vue au sol)"
	inc.focus_mode = Control.FOCUS_NONE
	inc.disabled = Ordres.protected(pop, pop.persons[pid]) or pop.age_of(pop.persons[pid]) < 3.0
	inc.tooltip_text = "L'incarner en 3e personne et le diriger toi-même (Échap pour revenir)."
	inc.pressed.connect(func() -> void:
		if pop.incarnate(pid):
			set_open(false))
	row.add_child(inc)
	if pop.principal.is_mine(pop.persons[pid]):
		_text("★ Ton personnage principal : c'est toi qui décides de ses grands choix.", false, 12).add_theme_color_override(
			"font_color", Color("ffd166"))
	if on:
		var c := Button.new()
		c.text = _camera_text(pop.persons[pid])
		c.focus_mode = Control.FOCUS_NONE
		c.pressed.connect(func() -> void:
			_toggle_camera()
			refresh())
		row.add_child(c)


func _camera_text(p: Dictionary) -> String:
	return "Caméra : %s (F)" % (CycleVie.g(p, "le suit", "la suit") if pop.follow_camera else "libre")


func _toggle_camera() -> void:
	pop.follow_camera = not pop.follow_camera
	pop._follow_set = Vector3.INF
	_refresh_card()


func _build_card() -> void:
	_card = PanelContainer.new()
	UiStyle.style_panel(_card, 0.88, 10, 8)
	# En haut à gauche, sous la barre du haut (le panneau Habitants est à droite).
	_card.offset_left = 12.0
	_card.offset_top = 80.0
	_card.custom_minimum_size = Vector2(300, 0)
	_card.visible = false
	add_child(_card)
	var v := VBoxContainer.new()
	_card.add_child(v)
	_card_text = Label.new()
	_card_text.add_theme_font_size_override("font_size", 13)
	_card_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_text.custom_minimum_size = Vector2(284, 0)
	v.add_child(_card_text)
	var row := HBoxContainer.new()
	v.add_child(row)
	var sheet := Button.new()
	sheet.text = "Fiche"
	sheet.focus_mode = Control.FOCUS_NONE
	sheet.pressed.connect(func() -> void:
		set_open(true)
		show_view("profil", pop.followed()))
	row.add_child(sheet)
	_card_cam = Button.new()
	_card_cam.focus_mode = Control.FOCUS_NONE
	_card_cam.pressed.connect(_toggle_camera)
	row.add_child(_card_cam)
	var stop := Button.new()
	stop.text = "Ne plus suivre"
	stop.focus_mode = Control.FOCUS_NONE
	stop.pressed.connect(func() -> void:
		pop.follow(-1)
		if is_open():
			refresh())
	row.add_child(stop)


func _build_ask() -> void:
	_ask = PanelContainer.new()
	UiStyle.style_panel(_ask, 0.94, 12, 12)
	_ask.anchor_left = 0.5
	_ask.anchor_right = 0.5
	_ask.offset_left = -300.0
	_ask.offset_right = 300.0
	_ask.offset_top = 110.0
	_ask.visible = false
	add_child(_ask)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_ask.add_child(v)
	var head := Label.new()
	head.text = "★ Ton personnage"
	head.add_theme_color_override("font_color", Color("ffd166"))
	head.add_theme_font_size_override("font_size", 15)
	v.add_child(head)
	_ask_text = Label.new()
	_ask_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ask_text.custom_minimum_size = Vector2(570, 0)
	_ask_text.add_theme_font_size_override("font_size", 15)
	v.add_child(_ask_text)
	_ask_buttons = HFlowContainer.new()
	_ask_buttons.add_theme_constant_override("h_separation", 8)
	_ask_buttons.add_theme_constant_override("v_separation", 6)
	v.add_child(_ask_buttons)


func _refresh_ask() -> void:
	var qs: Array = pop.principal.questions
	_ask.visible = not qs.is_empty()
	if qs.is_empty():
		return
	var q: Dictionary = qs[0]
	_ask_text.text = String(q.text) + ("" if qs.size() == 1 else "\n(%d autres questions ensuite)" % (qs.size() - 1))
	for c in _ask_buttons.get_children():
		c.queue_free()
	var opts: Array = q.options
	for i in opts.size():
		var b := Button.new()
		b.text = String(opts[i][0])
		b.focus_mode = Control.FOCUS_NONE
		var qid := int(q.id)
		b.pressed.connect(func() -> void: pop.principal.answer(qid, i))
		_ask_buttons.add_child(b)


func _refresh_card() -> void:
	if _card == null:
		return
	var pid := pop.followed()
	_card.visible = pid >= 0 and pop.persons.has(pid)
	if not _card.visible:
		return
	var p: Dictionary = pop.persons[pid]
	_card_text.text = "★ %s %s, %d ans · %s\n%s" % [p.p, p.n, pop.age_years(p), pop.stage_label(p), pop.activity(p).text]
	_card_cam.text = _camera_text(p)


## Sections communes aux vivants et aux défunts : en bref, santé, famille, CV.
func _life_sections(p: Dictionary) -> void:
	var vie := pop.vie
	var pid := int(p.id)
	var alive := pop.persons.has(pid)
	_section("En bref")
	var noms := []
	for d in Education.diplomes(p):
		noms.append(SystemesScolaires.nom_diplome(String(d)))
	var bits := ["Diplômes : %s" % (", ".join(noms) if not noms.is_empty() else "aucun")]
	bits.append("permis de conduire" if bool(p.get("perm", false)) else "pas de permis")
	if int(p.get("sp", 0)) > 0:
		bits.append("%d distinction%s sportive%s" % [int(p.sp), "s" if int(p.sp) > 1 else "", "s" if int(p.sp) > 1 else ""])
	_text(" · ".join(bits))
	if float(p.get("gain", 0.0)) > 0.0:
		_text("Revenus gagnés depuis son arrivée : %s" % money(float(p.gain)), true, 12)
	if alive:
		_section("Santé")
		var hl := vie.health(p)
		var mal := String(p.get("mal", ""))
		_text("%s · espérance de vie estimée : %d ans" % ["Malade : %s" % CycleVie.MALADIES[mal].name if mal != "" else "En bonne santé",
			roundi(vie.life_expectancy(p))])
		_text("  " + "\n  ".join(hl.why), true, 12)
	_section("Famille")
	var shown := 0
	for par in vie.parents_of(p):
		_person_link(par, _relation(p, vie.person(par)))
		shown += 1
		for gp in vie.parents_of(vie.person(par)):
			_person_link(gp, _relation(p, vie.person(gp)))
			shown += 1
	if int(p.get("cj", -1)) >= 0 and not vie.person(int(p.cj)).is_empty():
		_person_link(int(p.cj), _relation(p, vie.person(int(p.cj))))
		shown += 1
	var exes := {}
	for e in p.get("cv", []):
		if String(e[1]) in ["separation", "veuvage"] and int(e[3]) >= 0 and int(e[3]) != int(p.get("cj", -1)):
			exes[int(e[3])] = String(e[1])
	for x in exes:
		var ex := vie.person(x)
		if not ex.is_empty():
			_person_link(x, (CycleVie.g(ex, "son ex-conjoint", "son ex-conjointe") if exes[x] == "separation"
				else CycleVie.g(ex, "son conjoint (décédé)", "sa conjointe (décédée)")))
			shown += 1
	for k in vie.children_of(pid):
		_person_link(k, _relation(p, vie.person(k)))
		shown += 1
		for gk in vie.children_of(k):
			_person_link(gk, _relation(p, vie.person(gk)))
			shown += 1
	for sib in vie.siblings_of(p):
		_person_link(sib, _relation(p, vie.person(sib)))
		shown += 1
	if shown == 0:
		_text("Pas de famille connue en ville.", true)
	_section("Sa vie")
	var fr := FriseVie.new()
	fr.custom_minimum_size = Vector2(W - 30, 46)
	_body.add_child(fr)
	fr.setup(vie, p)
	var leg := HFlowContainer.new()
	leg.custom_minimum_size = Vector2(W - 30, 0)
	_body.add_child(leg)
	var seen := {}
	for ph in vie.phases_of(p):
		var k := String(ph[2])
		if seen.has(k):
			continue
		seen[k] = true
		var sw := ColorRect.new()
		sw.color = CycleVie.PHASES[k]
		sw.custom_minimum_size = Vector2(10, 10)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		leg.add_child(sw)
		var l := Label.new()
		l.text = CycleVie.PHASE_NAMES[k] + "  "
		l.add_theme_font_size_override("font_size", 11)
		leg.add_child(l)
	var cv: Array = p.get("cv", [])
	for i in range(cv.size() - 1, -1, -1):
		var e: Array = cv[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_body.add_child(row)
		var dot := ColorRect.new()
		dot.color = CycleVie.CODES.get(String(e[1]), Color.WHITE)
		if String(e[1]) == "deces":
			dot.color = Color.WHITE
		dot.custom_minimum_size = Vector2(8, 8)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(dot)
		var at := floori(maxf((float(e[0]) - float(p.nj)) / 365.25, 0.0))
		var l := Label.new()
		l.text = "%d an%s · %s" % [at, "s" if at > 1 else "", e[2]]
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(W - 48, 0)
		l.add_theme_font_size_override("font_size", 12)
		row.add_child(l)
		var ref := int(e[3])
		if String(e[1]) in ["couple", "mariage", "pacs", "separation", "enfant", "veuvage", "deuil", "heritage"] and ref >= 0 \
				and not vie.person(ref).is_empty():
			var go := Button.new()
			go.text = "↗"
			go.flat = true
			go.focus_mode = Control.FOCUS_NONE
			go.tooltip_text = "Voir la fiche"
			go.pressed.connect(func() -> void: show_view("profil", ref))
			row.add_child(go)


## Ordres : journée (aller quelque part, loisir, visite…) et choix de vie.
func _orders_section(pid: int) -> void:
	var p: Dictionary = pop.persons[pid]
	_section("Donner un ordre")
	if Ordres.protected(pop, p):
		_text("C'est le personnage principal d'un autre joueur : lui seul décide de sa vie.", true)
		return
	if p.has("ord") and int(p.ord.d) == int(pop.now().day):
		_text("Ordre en cours : %s" % p.ord.txt, false, 12).add_theme_color_override("font_color", Color("ffd166"))
	for kind in ["jour", "vie"]:
		_text("Sa journée" if kind == "jour" else "Ses choix de vie", true, 12)
		var flow := HFlowContainer.new()
		flow.custom_minimum_size = Vector2(W - 30, 0)
		flow.add_theme_constant_override("h_separation", 4)
		flow.add_theme_constant_override("v_separation", 4)
		_body.add_child(flow)
		for e in Ordres.LISTE:
			if e.type != kind:
				continue
			var id: String = e.id
			var why := Ordres.check(pop, p, id)
			var b: Button
			if id == "loisir" or id == "visite":
				var mb := MenuButton.new()
				mb.flat = false
				var pm := mb.get_popup()
				var choices: Dictionary = Ordres.hobby_venues(pop, p) if id == "loisir" else Ordres.visit_targets(pop, p)
				var keys := choices.keys()
				for i in keys.size():
					var label := ""
					if id == "loisir":
						label = "%s · %s" % [Metiers.LOISIRS[keys[i]].name, pop.building_name(int(choices[keys[i]]))]
					else:
						var q: Dictionary = pop.persons[keys[i]]
						label = "%s %s (%s)" % [q.p, q.n, choices[keys[i]]]
					pm.add_item(label, i)
				pm.id_pressed.connect(func(i: int) -> void:
					pop.give_order(pid, id, keys[i])
					refresh())
				_popups.append(mb)
				b = mb
			else:
				b = Button.new()
				b.pressed.connect(func() -> void:
					if id == "aller":
						pop.order_pick = pid
						pop.message.emit("Clique un bâtiment de la carte où envoyer %s %s (Échap : annuler)." % [p.p, p.n])
						return
					pop.give_order(pid, id)
					refresh())
			b.text = String(e.name).replace("…", "") if id in ["loisir", "visite"] else String(e.name)
			b.focus_mode = Control.FOCUS_NONE
			b.add_theme_font_size_override("font_size", 12)
			b.disabled = why != ""
			b.tooltip_text = why
			flow.add_child(b)


func _view_archive(pid: int) -> void:
	var f: Dictionary = pop.vie.archive[pid]
	var dead: bool = String(f.fin) == "deces"
	_title.text = "%s%s %s" % ["† " if dead else "", f.p, f.n]
	var age := floori(pop.vie.age_of(f))
	if dead:
		_text("%s · mort%s %s à %d ans" % ["Femme" if String(f.s) == "F" else "Homme", CycleVie.g(f, "", "e"), f.cause, age], false, 14)
		_text("Dernier logement : %s%s" % [f.lieu, (" · dernier métier : %s" % f.met) if String(f.met) != "" else ""], true)
		var sep := Funeraire.instance.sepulture_text(pid) if Funeraire.instance != null else ""
		if sep != "":
			_text("Repose : " + sep, false, 13)
			var sp: Dictionary = Funeraire.instance.sepultures.get(pid, {})
			if int(sp.get("bid", -1)) >= 0 and int(sp.get("slot", -1)) >= 0:
				var where: Vector3 = Funeraire.instance.slot_world(int(sp.bid), int(sp.slot)).origin
				_link("Aller sur sa tombe  ↗", func() -> void: focus_requested.emit(where), "Centrer la caméra sur la tombe")
	else:
		_text("%s · %s à %d ans" % [f.p, String(f.cause).to_lower(), age], false, 14)
		_text("Dernier logement : %s" % f.lieu, true)
	_life_sections(f)


func _relation(p: Dictionary, q: Dictionary) -> String:
	return pop.vie.relation(p, q)


static func _hours(a: float, b: float) -> String:
	return "%s – %s" % [_hm(a), _hm(b)]


static func _hm(h: float) -> String:
	var hh := int(h)
	var mm := roundi((h - hh) * 60.0)
	if mm == 60:
		hh += 1
		mm = 0
	return "%d h %02d" % [hh % 24 if hh != 24 else 24, mm]
