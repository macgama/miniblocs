class_name BudgetPanel
extends CanvasLayer
## Panneau « Budget de la commune » (touche M, comme Mairie) : bilan du mois,
## impôts votés, emprunts, entretien et état des voies.

signal focus_requested(pos: Vector3)

const W := 360.0
const H := 560.0
const KEY := KEY_M

var budget: BudgetCommunal
var view := "bilan"
var _panel: PanelContainer
var _title: Label
var _body: VBoxContainer
var _scroll: ScrollContainer
var _tick := 0.0
## Choix du prochain emprunt.
var _montant := 2
var _duree := 1


func setup(b: BudgetCommunal) -> void:
	budget = b
	_build()


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
	icon.texture = Icones.get_icon("budget", 22, UiStyle.ACCENT)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	head.add_child(icon)
	_title = Label.new()
	_title.text = "Budget de la commune"
	_title.add_theme_font_size_override("font_size", 16)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	var x := UiStyle.icon_button("fermer", "Fermer", "M", 18, 32)
	x.pressed.connect(func() -> void: set_open(false))
	head.add_child(x)
	var tabs := HBoxContainer.new()
	outer.add_child(tabs)
	for spec in [["Bilan", "bilan"], ["Impôts", "impots"], ["Emprunts", "emprunts"], ["Entretien", "entretien"]]:
		var b := Button.new()
		b.text = spec[0]
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	elif budget != null and budget.vue != null and budget.vue.carte:
		budget.vue.set_carte(false)


func toggle() -> void:
	set_open(not _panel.visible)


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.physical_keycode == KEY and not k.shift_pressed and not k.ctrl_pressed:
		toggle()
		get_viewport().set_input_as_handled()


func show_view(v: String) -> void:
	view = v
	if budget.vue != null and v != "entretien" and budget.vue.carte:
		budget.vue.set_carte(false)
	refresh()
	_scroll.scroll_vertical = 0


func _process(delta: float) -> void:
	if not is_open():
		return
	_tick += delta
	if _tick >= 1.5:
		_tick = 0.0
		# Pas de rafraîchissement pendant qu'on tire un curseur.
		var focus := get_viewport().gui_get_focus_owner()
		if focus is Slider:
			return
		var keep := _scroll.scroll_vertical
		refresh()
		_scroll.set_deferred("scroll_vertical", keep)


func refresh() -> void:
	if budget == null:
		return
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	match view:
		"impots": _view_taxes()
		"emprunts": _view_loans()
		"entretien": _view_upkeep()
		_: _view_summary()
	# Plusieurs villes : chaque ville a son budget (Maj+P pour en changer).
	if BudgetCommunal.multi():
		_title.text = "%s · %s" % [Pays.instance.nom_de(budget.cle), _title.text.trim_prefix("Budget · ")]


# --- Petits outils ---------------------------------------------------------------------

static func money(v: float) -> String:
	return BuildingSystem.format_money(roundi(v))


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
	l.add_theme_color_override("font_color", UiStyle.ACCENT)


func _line(label: String, v: float, color := Color.WHITE) -> void:
	var r := HBoxContainer.new()
	_body.add_child(r)
	var a := Label.new()
	a.text = label
	a.add_theme_font_size_override("font_size", 12)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	a.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.add_child(a)
	var b := Label.new()
	b.text = money(v)
	b.add_theme_font_size_override("font_size", 12)
	b.add_theme_color_override("font_color", color)
	r.add_child(b)


func _button(t: String, cb: Callable, disabled := false) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.disabled = disabled
	b.add_theme_font_size_override("font_size", 12)
	b.pressed.connect(cb)
	return b


func _row() -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 4)
	_body.add_child(r)
	return r


## Curseur de pourcentage : [slider, label].
func _pct_slider(label: String, v: float, lo: float, hi: float, cb: Callable) -> HSlider:
	var r := _row()
	var a := Label.new()
	a.text = label
	a.custom_minimum_size = Vector2(150, 0)
	a.add_theme_font_size_override("font_size", 12)
	a.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.add_child(a)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.05
	s.value = v
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.custom_minimum_size = Vector2(120, 0)
	r.add_child(s)
	var l := Label.new()
	l.text = "%d %%" % roundi(v * 100.0)
	l.custom_minimum_size = Vector2(44, 0)
	l.add_theme_font_size_override("font_size", 12)
	r.add_child(l)
	s.value_changed.connect(func(x: float) -> void:
		l.text = "%d %%" % roundi(x * 100.0)
		cb.call(x))
	return s


# --- Bilan ---------------------------------------------------------------------------------

func _view_summary() -> void:
	_title.text = "Budget · bilan"
	var bs := budget.buildings
	var unlimited := bs != null and bs.unlimited_money
	_text("Caisse : %s" % ("illimitée (Admin)" if unlimited else money(budget.caisse())), false, 15)
	if budget.tutelle:
		var l := _text("Ville sous tutelle du préfet : impôts relevés à %d %%, plus d'emprunts ni de bâtiments publics. Elle en sort après %d jours sans dette en caisse (%d/%d)." % [
			roundi(BudgetCommunal.TAUX_TUTELLE * 100.0), BudgetCommunal.JOURS_VERT_SORTIE, budget.jours_vert, BudgetCommunal.JOURS_VERT_SORTIE])
		l.add_theme_color_override("font_color", Color("ff6b6b"))
	elif budget.jours_rouge > 0:
		var l := _text("Caisse dans le rouge depuis %d jours : tutelle du préfet au bout de %d jours." % [budget.jours_rouge, BudgetCommunal.JOURS_ROUGE_TUTELLE])
		l.add_theme_color_override("font_color", Color("ffb347"))
	var b := budget.bilan_mensuel()
	_section("Prévision par mois")
	var keys: Array = (b.recettes as Dictionary).keys()
	keys.sort()
	for k in keys:
		if absf(float(b.recettes[k])) >= 0.5:
			_line(k, b.recettes[k], Color("7bd389"))
	keys = (b.depenses as Dictionary).keys()
	keys.sort()
	for k in keys:
		if absf(float(b.depenses[k])) >= 0.5:
			_line(k, -float(b.depenses[k]), Color("ff8c8c"))
	_line("Solde du mois", b.solde, Color("7bd389") if float(b.solde) >= 0.0 else Color("ff6b6b"))
	_text("Sans l'impôt sur les bénéfices des entreprises, versé chaque jour selon leurs ventes.", true, 11)
	_section("Ce mois-ci (jour %d sur 30)" % budget.jours_mois)
	_ledger(budget.mois)
	if not budget.historique.is_empty():
		_section("Mois dernier")
		_ledger(budget.historique[budget.historique.size() - 1])


func _ledger(m: Dictionary) -> void:
	if m.is_empty():
		_text("Rien encore.", true)
		return
	var keys: Array = m.keys()
	keys.sort_custom(func(a, b) -> bool: return float(m[a]) > float(m[b]))
	var tot := 0.0
	for k in keys:
		var v := float(m[k])
		tot += v
		if absf(v) >= 0.5:
			_line(k, v, Color("7bd389") if v >= 0.0 else Color("ff8c8c"))
	_line("Total", tot, Color("7bd389") if tot >= 0.0 else Color("ff6b6b"))


# --- Impôts ----------------------------------------------------------------------------------

func _view_taxes() -> void:
	_title.text = "Budget · impôts"
	_text("Le conseil municipal vote les taux (100 % = taux habituel). Plus ils sont hauts, plus la caisse se remplit et moins les habitants sont contents.", true)
	var b := budget.bilan_mensuel()
	for k in BudgetCommunal.TAUX_NOMS:
		var key: String = k
		_pct_slider(String(BudgetCommunal.TAUX_NOMS[k]), float(budget.taux[k]), BudgetCommunal.TAUX_MIN, BudgetCommunal.TAUX_MAX,
			func(x: float) -> void: budget.set_taux(key, x))
	_section("Effet")
	_line("Taxe foncière par mois", float(b.recettes.get("Taxe foncière", 0.0)), Color("7bd389"))
	_line("Impôt des entreprises par mois", float(b.recettes.get("Impôts des entreprises", 0.0)), Color("7bd389"))
	var p := budget.pression_fiscale()
	_text("Pression fiscale ressentie : %d %% (réglage Admin des impôts ×%s compris)." % [roundi(p * 100.0), ReglagesPartie._fmt(ReglagesPartie.actuel.impots)])
	var mood: Array = budget._avis_impots()
	_text("Humeur des habitants : %s" % ("rien à redire" if (mood[1] as Array).is_empty() else ", ".join(mood[1])), true)
	if budget.tutelle:
		_text("Sous tutelle, le préfet impose au moins %d %% sur chaque impôt." % roundi(BudgetCommunal.TAUX_TUTELLE * 100.0), true)


# --- Emprunts --------------------------------------------------------------------------------

func _view_loans() -> void:
	_title.text = "Budget · emprunts"
	_text("Dette : %s sur un plafond de %s (%d ans de recettes)." % [money(budget.dette()), money(budget.plafond_dette()), int(BudgetCommunal.PLAFOND_ANNEES)])
	_text("Mensualités : %s par mois." % money(budget.mensualites()))
	_section("Nouvel emprunt")
	var r := _row()
	var amt := OptionButton.new()
	for m in BudgetCommunal.MONTANTS:
		amt.add_item(BuildingSystem.format_short(m))
	amt.select(_montant)
	amt.item_selected.connect(func(i: int) -> void:
		_montant = i
		refresh())
	r.add_child(amt)
	var dur := OptionButton.new()
	for y in BudgetCommunal.DUREES:
		dur.add_item("%d ans" % y)
	dur.select(_duree)
	dur.item_selected.connect(func(i: int) -> void:
		_duree = i
		refresh())
	r.add_child(dur)
	var m := float(BudgetCommunal.MONTANTS[_montant])
	var y: int = BudgetCommunal.DUREES[_duree]
	var t := budget.taux_propose(m, y)
	var mens := BudgetCommunal.mensualite_de(m, t, y)
	_text("La banque propose %s %% : %s par mois pendant %d ans, soit %s d'intérêts en tout." % [
		BudgetCommunal._pct(t), money(mens), y, money(mens * y * 12.0 - m)], true)
	var why := budget.refus_emprunt(m, y)
	if why != "":
		_text(why, true)
	_body.add_child(_button("Emprunter %s" % BuildingSystem.format_short(int(m)), func() -> void:
		budget.emprunter(m, y)
		refresh(), why != ""))
	_section("Emprunts en cours (%d)" % budget.emprunts.size())
	if budget.emprunts.is_empty():
		_text("Aucun. La ville ne doit rien à personne.", true)
	for e in budget.emprunts:
		var restant := float(e.restant)
		_text("%s : %s empruntés à %s %% sur %d ans. Reste %s, %s par mois." % [String(e.nom), money(float(e.capital)),
			BudgetCommunal._pct(float(e.taux)), int(e.annees), money(restant), money(float(e.mensualite))])
		var id := int(e.id)
		_body.add_child(_button("Rembourser tout de suite (%s, pénalité %d %%)" % [money(restant * (1.0 + BudgetCommunal.PENALITE)), roundi(BudgetCommunal.PENALITE * 100.0)],
			func() -> void:
				budget.rembourser(id)
				refresh()))


# --- Entretien --------------------------------------------------------------------------------

func _view_upkeep() -> void:
	_title.text = "Budget · entretien"
	var carte := budget.vue != null and budget.vue.carte
	var r := _row()
	var cb := _button("Masquer la carte de l'état" if carte else "Carte de l'état des voies", func() -> void:
		budget.vue.set_carte(not budget.vue.carte)
		refresh())
	r.add_child(cb)
	if ReglagesPartie.actuel.usure <= 0.0:
		_text("Usure coupée dans l'Admin (F10) : les voies restent neuves.", true)
	_text("Le budget d'entretien courant freine l'usure (100 % = conseillé). Au-dessus, il répare peu à peu. Les tronçons sous le seuil sont refaits automatiquement (3 par jour et par réseau).", true)
	for k in BudgetCommunal.VOIES:
		var l := budget.longueur(k)
		if l <= 0.0:
			continue
		var key: String = k
		var cfg: Dictionary = budget.entretien[k]
		_section("%s : %s, état %d %%" % [BudgetCommunal.VOIE_NOMS[k], TransportSystem._km(l), roundi(budget.etat_moyen(k) * 100.0)])
		_pct_slider("Entretien courant (%s/mois)" % BuildingSystem.format_short(roundi(budget.cout_entretien(k))), float(cfg.taux), 0.0, 2.0,
			func(x: float) -> void: budget.set_entretien(key, "taux", x))
		var r2 := _row()
		var auto := CheckBox.new()
		auto.text = "Réparer sous %d %%" % roundi(float(cfg.seuil) * 100.0)
		auto.button_pressed = bool(cfg.auto)
		auto.focus_mode = Control.FOCUS_NONE
		auto.add_theme_font_size_override("font_size", 12)
		auto.toggled.connect(func(on: bool) -> void: budget.set_entretien(key, "auto", on))
		r2.add_child(auto)
		var seuil := OptionButton.new()
		for s in [20, 35, 50, 70]:
			seuil.add_item("%d %%" % s)
		var best := 0
		for i in 4:
			if absf([0.2, 0.35, 0.5, 0.7][i] - float(cfg.seuil)) < absf([0.2, 0.35, 0.5, 0.7][best] - float(cfg.seuil)):
				best = i
		seuil.select(best)
		seuil.item_selected.connect(func(i: int) -> void:
			budget.set_entretien(key, "seuil", [0.2, 0.35, 0.5, 0.7][i])
			refresh())
		r2.add_child(seuil)
	for res in budget.reseaux_ext:
		_section("Réseau %s : état %d %%" % [res, roundi(_ext_mean(res) * 100.0)])
		_line("Entretien par mois", -budget.cout_entretien_ext(res), Color("ff8c8c"))
	_section("Tronçons les plus abîmés")
	var worst := budget.pires("", 0.999, 12)
	if worst.is_empty():
		_text("Tout est en bon état.", true)
	var net := budget.network()
	for eid in worst:
		var e: Dictionary = net.edges[eid]
		var row := _row()
		var lab := Label.new()
		lab.text = "%s · %s · %d %%" % [String(TransportTypes.get_type(String(e.t)).get("name", "Voie")), TransportSystem._km(float(e.len)), roundi(budget.etat(eid) * 100.0)]
		lab.add_theme_font_size_override("font_size", 12)
		lab.add_theme_color_override("font_color", UsureVue.couleur(budget.etat(eid)))
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(lab)
		var id := int(eid)
		row.add_child(_button("Voir", func() -> void: focus_requested.emit(net.point_at(id, float(net.edges[id].len) * 0.5))))
		row.add_child(_button("Réparer %s" % BuildingSystem.format_short(budget.prix_reparation(id)), func() -> void:
			budget.reparer(id)
			refresh()))
	if not worst.is_empty():
		_body.add_child(_button("Réparer tout ce qui est sous 50 %", func() -> void:
			for eid in budget.pires("", 0.5, 1000):
				if not budget.reparer(eid, true):
					break
			refresh()))


func _ext_mean(res: String) -> float:
	var s := 0.0
	var l := 0.0
	for id in budget.reseaux_ext[res]:
		var it: Dictionary = budget.reseaux_ext[res][id]
		s += float(it.u) * float(it.l)
		l += float(it.l)
	return 1.0 if l <= 0.0 else s / l
