class_name HabitantsPanel
extends CanvasLayer
## Panneau « Habitants » (touche H) : la ville en chiffres, la liste des
## habitants, un bâtiment (qui y vit, y travaille, y étudie, qui y est en ce
## moment) et le profil complet d'un habitant. Tout nom est cliquable.

signal focus_requested(pos: Vector3)
## Boutons de la fiche d'un bâtiment : personnaliser (catalogue), aménager (murs fins).
signal customize_requested(bid: int)
signal furnish_requested(bid: int)

const W := 348.0
const H := 560.0

var pop: Population
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
	outer.add_child(tabs)
	for spec in [["Ville", "ville", "budget"], ["Habitants", "liste", "habitants"]]:
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
			and pop.followed() >= 0:
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
		if is_instance_valid(o) and (o.call("get_popup") as PopupMenu).visible:
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
	match view:
		"ville":
			_view_city()
		"liste":
			_view_list()
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


# --- Petits outils d'interface ----------------------------------------------------

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


func _section(t: String) -> void:
	_body.add_child(HSeparator.new())
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
	_body.add_child(b)
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
	for row in [["bebe", "Bébés (0-2 ans)"], ["eleve", "Élèves (3-17 ans)"], ["etudiant", "Étudiants (université hors de la ville)"],
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
	var pick := OptionButton.new()
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
	var pick := OptionButton.new()
	pick.focus_mode = Control.FOCUS_NONE
	var keys := ["", "bebe", "eleve", "etudiant", "actif", "chomeur", "retraite", "defunts"]
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


func _view_building(bid: int) -> void:
	var info: Dictionary = pop.known[bid]
	_title.text = pop.building_name(bid)
	var t := BuildingCatalog.get_type(String(info.t))
	var cat := BuildingCatalog.category(String(info.cat))
	_text("%s · %s" % [String(cat.get("name", info.cat)), String(t.get("desc", ""))], true, 12)
	if info.has("conf"):
		_text("Intérieur aménagé · confort %d · attractivité %d · valeur %s" % [int(info.conf), int(info.attr), BuildingSystem.format_money(int(info.valeur))], true, 12)
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
	var go := Button.new()
	go.text = "Aller voir"
	go.icon = Icones.get_icon("lieu", 18)
	go.focus_mode = Control.FOCUS_NONE
	go.pressed.connect(func() -> void: focus_requested.emit(info.pos))
	var acts := HBoxContainer.new()
	acts.add_child(go)
	if info.has("plan"):
		var fu := Button.new()
		fu.text = "Aménager"
		fu.icon = Icones.get_icon("interieur", 18)
		fu.focus_mode = Control.FOCUS_NONE
		fu.tooltip_text = "Meubles, pièces, murs : ouvre l'onglet Intérieur sur ce bâtiment (et l'enregistrer dans la banque de modèles)."
		fu.pressed.connect(func() -> void: furnish_requested.emit(bid))
		acts.add_child(fu)
	elif Personnalisation.can_customize(String(info.t)):
		var cu := Button.new()
		cu.text = "Personnaliser"
		cu.icon = Icones.get_icon("peinture", 18)
		cu.focus_mode = Control.FOCUS_NONE
		cu.tooltip_text = "Couleurs, toit, étages ; ouvrir l'intérieur ; enregistrer dans la banque de modèles."
		cu.pressed.connect(func() -> void: customize_requested.emit(bid))
		acts.add_child(cu)
	_body.add_child(acts)
	if int(info.log) > 0:
		var homes: Array = pop.by_home.get(bid, [])
		var n := 0
		for hid in homes:
			n += (pop.households[hid].m as Array).size()
		_section("Habitants : %d dans %d logement%s sur %d" % [n, homes.size(), "s" if homes.size() > 1 else "", int(info.log)])
		var shown := 0
		for hid in homes:
			if shown >= 60:
				_text("… et d'autres foyers.", true)
				break
			var h: Dictionary = pop.households[hid]
			var bud := pop.household_budget(hid)
			_text("Foyer %s · %s/mois de revenus · épargne %s" % [pop.persons[h.m[0]].n if not (h.m as Array).is_empty() else "",
				money(bud.revenus), money(h.ep)], true, 12)
			for pid in h.m:
				_person_link(pid, String(pop.activity(pop.persons[pid]).text))
			shown += 1
		if homes.is_empty():
			_text("Personne n'a encore emménagé. Laisse avancer le temps (T, Maj + T).", true)
	if int(info.seats) > 0:
		var pupils: Array = pop.by_school.get(bid, [])
		var at_school := 0
		for pid in pupils:
			if pop.activity(pop.persons[pid]).kind == "ecole":
				at_school += 1
		_section("Élèves : %d inscrits sur %d places · %d en classe maintenant" % [pupils.size(), int(info.seats), at_school])
		var levels := {}
		for pid in pupils:
			var lv := Metiers.school_level(pop.age_years(pop.persons[pid]))
			levels[lv] = int(levels.get(lv, 0)) + 1
		var parts := []
		for lv in ["maternelle", "élémentaire", "collège", "lycée"]:
			if levels.has(lv):
				parts.append("%s : %d" % [lv, levels[lv]])
		if not parts.is_empty():
			_text(" · ".join(parts), true, 12)
		var shown := 0
		for pid in pupils:
			if shown >= 120:
				_text("… et %d autres." % (pupils.size() - shown), true)
				break
			_person_link(pid, String(pop.activity(pop.persons[pid]).text))
			shown += 1
	if int(info.emp) > 0:
		var staff: Array = pop.by_job.get(bid, [])
		_section("Employés : %d sur %d postes" % [staff.size(), int(info.emp)])
		var shown := 0
		for pid in staff:
			if shown >= 120:
				_text("… et %d autres." % (staff.size() - shown), true)
				break
			_person_link(pid, String(pop.activity(pop.persons[pid]).text))
			shown += 1
		if staff.is_empty():
			_text("Aucun employé : il faut des habitants sans emploi en ville.", true)
	var visitors := []
	for pid in here:
		var k := String(pop.activity(pop.persons[pid]).kind)
		if k == "loisir" or k == "courses":
			visitors.append(pid)
	if not visitors.is_empty():
		_section("Visiteurs en ce moment : %d" % visitors.size())
		for i in mini(visitors.size(), 60):
			_person_link(visitors[i], String(pop.activity(pop.persons[visitors[i]]).text))
	if int(info.log) == 0 and int(info.seats) == 0 and int(info.emp) == 0 and visitors.is_empty():
		_text("Ce bâtiment n'accueille ni habitants, ni employés, ni élèves.", true)


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
	if int(a.bid) >= 0 and pop.known.has(int(a.bid)):
		_building_link("Où : ", int(a.bid))
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
	_text("Budget du foyer par mois : revenus %s · loyer %s · courses %s%s" % [money(bud.revenus), money(bud.loyer), money(bud.courses),
		(" · voiture%s %s" % ["s" if int(h.car) > 1 else "", money(bud.voitures)]) if int(h.car) > 0 else ""], true, 12)
	var sol: float = bud.solde
	_text("Reste %s%s par mois · épargne %s · %s" % ["+" if sol >= 0 else "", money(sol), money(h.ep),
		"%d voiture%s" % [int(h.car), "s" if int(h.car) > 1 else ""] if int(h.car) > 0 else "pas de voiture"], true, 12)

	var st := pop.stage(p)
	if st == "eleve":
		_section("École")
		if int(p.sch) >= 0:
			_building_link("", int(p.sch))
			_text("Classe : %s (%s)" % [Metiers.school_class(age), Metiers.school_level(age)])
			var c := pop.commute(p, int(h.b), int(p.sch))
			_text("Trajet : %d min %s" % [int(c.min), c.mode], true)
			if c.has("detail"):
				_text("Itinéraire : " + String(c.detail), true, 12)
			_text("Lundi, mardi, jeudi, vendredi de 8 h 30 à 16 h 30, mercredi matin.", true, 12)
		else:
			_text("Aucune place libre dans une école : construis une école (B → Services publics).", true)
	elif st == "actif" or st == "chomeur":
		_section("Travail")
		if int(p.job) >= 0:
			var j := Metiers.job(String(p.met))
			_text("%s · %s net par mois%s" % [j.name, money(float(j.salaire) * ReglagesPartie.actuel.salaires),
				" (payé par l'État)" if bool(j.get("etat", false)) else (" (payé par la ville)" if bool(j.get("public", false)) else "")])
			_building_link("Lieu : ", int(p.job))
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
	inc.tooltip_text = "L'incarner en 3e personne et le diriger toi-même (V pour revenir)."
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
	var bits := ["Diplôme : %s" % CycleVie.DIPLOMES.get(String(p.get("dip", "")), "aucun")]
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
		_text("Sa fiche reste consultable (un cimetière viendra plus tard dans le catalogue).", true, 12)
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
