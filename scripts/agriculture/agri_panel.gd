class_name AgriPanel
extends CanvasLayer
## Panneau « Agriculture » (Maj+F) : les fermes, leurs champs (tracer, choisir
## la culture, suivre les travaux), leurs bêtes, leurs machines, et la
## nourriture de la ville (ce que mangent les habitants, qui a faim).

signal focus_requested(pos: Vector3)
signal outil_demande

const W := 360.0
const H := 560.0

var agri: Agriculture
var _panel: PanelContainer
var _title: Label
var _body: VBoxContainer
var _scroll: ScrollContainer
## Vue : "fermes", "champs", "betes", "machines", "nourriture".
var view := "fermes"
var _tick := 0.0


func setup(a: Agriculture) -> void:
	agri = a
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
	icon.texture = Icones.get_icon("agriculture", 22, UiStyle.ACCENT)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	head.add_child(icon)
	_title = Label.new()
	_title.text = "Agriculture"
	_title.add_theme_font_size_override("font_size", 16)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	var x := UiStyle.icon_button("fermer", "Fermer", "Maj+F", 18, 32)
	x.pressed.connect(func() -> void: set_open(false))
	head.add_child(x)
	var tabs := HBoxContainer.new()
	outer.add_child(tabs)
	for spec in [["Fermes", "fermes"], ["Champs", "champs"], ["Bêtes", "betes"], ["Machines", "machines"], ["Repas", "nourriture"]]:
		var b := Button.new()
		b.text = spec[0]
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 12)
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
		if not agri.est_ferme(agri.ferme_choisie):
			var l := agri.liste_fermes()
			agri.ferme_choisie = int(l[0]) if not l.is_empty() else -1
		refresh()
	elif agri.outil != "":
		agri.set_outil("")


func toggle() -> void:
	set_open(not _panel.visible)


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.physical_keycode == KEY_F and k.shift_pressed and not k.ctrl_pressed:
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
	if _tick >= 2.0:
		_tick = 0.0
		var keep := _scroll.scroll_vertical
		refresh()
		_scroll.set_deferred("scroll_vertical", keep)


func refresh() -> void:
	if agri == null:
		return
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	match view:
		"champs":
			_view_champs()
		"betes":
			_view_betes()
		"machines":
			_view_machines()
		"nourriture":
			_view_nourriture()
		_:
			_view_fermes()


# --- Petits outils ---------------------------------------------------------------------

func _text(t: String, dim := false, size := 13, parent: Control = null) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(W - 30, 0)
	l.add_theme_font_size_override("font_size", size)
	if dim:
		l.add_theme_color_override("font_color", Color(1, 1, 1, 0.65))
	(parent if parent else _body).add_child(l)
	return l


func _section(t: String) -> void:
	_body.add_child(HSeparator.new())
	var l := _text(t, false, 15)
	l.add_theme_color_override("font_color", Color("ffd166"))


func _button(t: String, f: Callable, parent: Control = null, tip := "") -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 12)
	b.tooltip_text = tip
	b.pressed.connect(func() -> void:
		f.call()
		refresh())
	(parent if parent else _body).add_child(b)
	return b


func _row() -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 4)
	_body.add_child(r)
	return r


func _bar(parent: Control, value: float, col: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.max_value = 1.0
	bar.step = 0.001
	bar.value = clampf(value, 0.0, 1.0)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(70, 10)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_theme_stylebox_override("background", UiStyle.flat_box(Color(1, 1, 1, 0.12), 5, 0))
	bar.add_theme_stylebox_override("fill", UiStyle.flat_box(col, 5, 0))
	parent.add_child(bar)
	return bar


static func _money(v: float) -> String:
	return BuildingSystem.format_money(roundi(v))


## Choix de la ferme (liste déroulante) en haut des vues.
func _choix_ferme() -> int:
	var fermes := agri.liste_fermes()
	if fermes.is_empty():
		_text("Aucune ferme sur la carte. Construis-en une : Construire (B) → Production → Ferme céréalière, Élevage, Ferme laitière, Porcherie…", true)
		return -1
	if not fermes.has(agri.ferme_choisie):
		agri.ferme_choisie = int(fermes[0])
	var ob := OptionButton.new()
	ob.focus_mode = Control.FOCUS_NONE
	ob.add_theme_font_size_override("font_size", 12)
	for i in fermes.size():
		var bid := int(fermes[i])
		ob.add_item("%s · %s ha" % [agri.nom_ferme(bid), Agriculture._ha(agri.surface_ferme(bid))], bid)
		if bid == agri.ferme_choisie:
			ob.select(i)
	ob.item_selected.connect(func(i: int) -> void:
		agri.ferme_choisie = ob.get_item_id(i)
		refresh())
	_body.add_child(ob)
	return agri.ferme_choisie


# --- Fermes ------------------------------------------------------------------------------

func _view_fermes() -> void:
	_title.text = "Agriculture · fermes"
	var bid := _choix_ferme()
	if bid < 0:
		return
	var f := agri.ferme(bid)
	var prod := agri.production
	var s: Dictionary = prod.sites.get(bid, {})
	var r := _row()
	_button("Voir", func() -> void: focus_requested.emit(agri._pos_of(bid)), r)
	_button("Préparer la ferme", func() -> void:
		var n := agri.prepare_ferme(bid)
		agri.message.emit("%d champ%s créé%s autour de la ferme." % [n, "s" if n > 1 else "", "s" if n > 1 else ""]), r,
		"Crée des champs autour de la ferme (sur les terres libres) et ses premières bêtes")
	_text(String(s.get("status", agri.status_of(bid))), true)
	var travailleurs := (agri.population.by_job.get(bid, []) as Array).size() if agri.population else 0
	_text("Employés : %d · Caisse de la ferme : %s · Champs : %d (%s ha)" % [travailleurs, _money(float(s.get("cash", 0.0))),
		agri.champs_de(bid).size(), Agriculture._ha(agri.surface_ferme(bid))])
	var auto := CheckBox.new()
	auto.text = "Louer les machines qui manquent (coopérative)"
	auto.button_pressed = bool(f.get("loc_auto", true))
	auto.focus_mode = Control.FOCUS_NONE
	auto.add_theme_font_size_override("font_size", 12)
	auto.toggled.connect(func(on: bool) -> void: f.loc_auto = on)
	_body.add_child(auto)
	# Travaux en cours.
	_section("Aux champs en ce moment")
	if (f.travail as Array).is_empty():
		_text("Personne aux champs (nuit, pluie, rien à faire ou pas de machine).", true)
	for w in f.travail:
		var ch: Dictionary = agri.champs.get(int(w.champ), {})
		if ch.is_empty():
			continue
		var row := _row()
		var l := Label.new()
		l.text = "%s · %s" % [String(AgriDonnees.TACHES[w.tache].name), agri.nom_champ(int(w.champ))]
		l.add_theme_font_size_override("font_size", 12)
		l.custom_minimum_size = Vector2(190, 0)
		row.add_child(l)
		_bar(row, float(ch.fait) / maxf(Agriculture.surface(ch), 0.0001), Color("e9c46a"))
	# Stock de la ferme.
	_section("Stock de la ferme")
	var st: Dictionary = s.get("st", {})
	if st.is_empty():
		_text("Vide.", true)
	for g in st:
		_text("%s : %s" % [Ressources.good_name(g), Ressources.format_t(float(st[g]))])
	var besoins := agri.besoins_betes(bid)
	if not besoins.is_empty():
		var parts: Array[String] = []
		for g in besoins:
			parts.append("%s de %s" % [Ressources.format_t(float(besoins[g])), Ressources.good_name(g).to_lower()])
		_text("Les bêtes mangent chaque jour : " + ", ".join(parts), true)
	_section("Journal")
	for line in (f.journal as Array).slice(0, 12):
		_text(String(line), true, 12)


# --- Champs ------------------------------------------------------------------------------

func _view_champs() -> void:
	_title.text = "Agriculture · champs"
	var bid := _choix_ferme()
	if bid < 0:
		return
	_text("Culture des nouveaux champs :", true)
	var ob := OptionButton.new()
	ob.focus_mode = Control.FOCUS_NONE
	ob.add_theme_font_size_override("font_size", 12)
	for i in AgriDonnees.ORDRE_CULTURES.size():
		var id: String = AgriDonnees.ORDRE_CULTURES[i]
		var ok := AgriDonnees.convient(id, agri.climat())
		ob.add_item("%s%s · semis %s" % [AgriDonnees.culture_name(id), "" if ok else " (climat défavorable)",
			AgriDonnees.mois_semis_texte(id, agri.lat(), agri.climat())], i)
		if id == agri.culture_choisie:
			ob.select(i)
	ob.item_selected.connect(func(i: int) -> void:
		agri.culture_choisie = AgriDonnees.ORDRE_CULTURES[i]
		if agri.outil == "tracer":
			agri.set_outil("tracer"))
	_body.add_child(ob)
	var r := _row()
	var tr := _button("Tracer un champ" if agri.outil != "tracer" else "Arrêter de tracer", func() -> void:
		outil_demande.emit()
		agri.set_outil("" if agri.outil == "tracer" else "tracer"), r)
	tr.toggle_mode = true
	tr.button_pressed = agri.outil == "tracer"
	var ef := _button("Supprimer un champ", func() -> void:
		outil_demande.emit()
		agri.set_outil("" if agri.outil == "effacer" else "effacer"), r)
	ef.toggle_mode = true
	ef.button_pressed = agri.outil == "effacer"
	var ids := agri.champs_de(bid)
	if ids.is_empty():
		_text("Pas encore de champ. Clique sur « Tracer un champ » puis glisse sur le terrain près de la ferme, ou « Préparer la ferme » dans l'onglet Fermes.", true)
	for id in ids:
		_carte_champ(int(id))


func _etat_texte(ch: Dictionary) -> String:
	var cult := String(ch.sc) if String(ch.sc) != "" else String(ch.cult)
	match String(ch.etat):
		"friche":
			return "En friche"
		"laboure":
			return "Labouré, attend le semis (%s)" % AgriDonnees.mois_semis_texte(String(ch.cult), agri.lat(), agri.climat())
		"pousse":
			if bool(AgriDonnees.culture(cult).get("paturage", false)):
				return "Pâture : herbe à %d %%" % roundi(float(ch.cr) * 100.0)
			return "%s pousse : %d %%" % [AgriDonnees.culture_name(cult), roundi(float(ch.cr) * 100.0)]
		"mur":
			return "%s mûr, à récolter" % AgriDonnees.culture_name(cult)
		"chaume":
			return "Récolté (chaume)" + (", paille à presser" if float(ch.paille) > 0.0 else "")
	return String(ch.etat)


func _carte_champ(id: int) -> void:
	var ch: Dictionary = agri.champs[id]
	_body.add_child(HSeparator.new())
	var head := _row()
	var l := Label.new()
	l.text = "%s · %s ha%s" % [agri.nom_champ(id).capitalize(), Agriculture._ha(Agriculture.surface(ch)), "  ◀" if agri.selection == id else ""]
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", Color("ffd166") if agri.selection == id else Color.WHITE)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(l)
	_button("Voir", func() -> void:
		agri.selection = id
		var c := (ch.r as Rect2i).get_center()
		focus_requested.emit(Vector3(c.x, 0.0, c.y)), head)
	_text(_etat_texte(ch), true, 12)
	if String(ch.etat) in ["pousse", "mur"]:
		var row := _row()
		var t := Label.new()
		t.text = "Croissance"
		t.add_theme_font_size_override("font_size", 12)
		t.custom_minimum_size = Vector2(90, 0)
		row.add_child(t)
		_bar(row, float(ch.cr), Color("90be6d") if String(ch.etat) == "pousse" else Color("e9c46a"))
	var rd := agri.rendement(ch)
	var cult := String(ch.sc) if String(ch.sc) != "" else String(ch.cult)
	var good := String(AgriDonnees.culture(cult).get("good", ""))
	if rd > 0.0 and good != "":
		var done: Array[String] = []
		done.append("engrais ✓" if bool(ch.eng) else "engrais à faire")
		if not bool(AgriDonnees.culture(cult).get("permanente", false)):
			done.append("traitement ✓" if bool(ch.tr) else "traitement à faire")
		_text("Récolte attendue : %s de %s (fertilité %d %%) · %s" % [Ressources.format_t(rd), Ressources.good_name(good).to_lower(),
			roundi(agri.fertilite(ch) * 100.0), ", ".join(done)], true, 12)
	if float(ch.rdt) > 0.0:
		_text("Dernière récolte : %s" % Ressources.format_t(float(ch.rdt)), true, 12)
	if String(ch.tache) != "":
		_text("En cours : %s (%d %%)" % [String(AgriDonnees.TACHES[ch.tache].name),
			roundi(float(ch.fait) / maxf(Agriculture.surface(ch), 0.0001) * 100.0)], false, 12)
	# Culture prévue.
	var row2 := _row()
	var t2 := Label.new()
	t2.text = "Prochaine culture"
	t2.add_theme_font_size_override("font_size", 12)
	row2.add_child(t2)
	var ob := OptionButton.new()
	ob.focus_mode = Control.FOCUS_NONE
	ob.add_theme_font_size_override("font_size", 12)
	ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in AgriDonnees.ORDRE_CULTURES.size():
		var cid: String = AgriDonnees.ORDRE_CULTURES[i]
		ob.add_item(AgriDonnees.culture_name(cid), i)
		if cid == String(ch.cult):
			ob.select(i)
	ob.item_selected.connect(func(i: int) -> void:
		agri.change_culture(id, AgriDonnees.ORDRE_CULTURES[i])
		refresh())
	row2.add_child(ob)
	if String(ch.etat) in ["pousse", "mur", "laboure"] and String(ch.sc) != String(ch.cult) and String(ch.sc) != "":
		_button("Détruire la culture en place et semer %s" % AgriDonnees.culture_name(String(ch.cult)).to_lower(),
			func() -> void: agri.change_culture(id, String(ch.cult), true))


# --- Bêtes ------------------------------------------------------------------------------

func _view_betes() -> void:
	_title.text = "Agriculture · bêtes"
	var bid := _choix_ferme()
	if bid < 0:
		return
	var t := agri._type_of(bid)
	var f := agri.ferme(bid)
	var places: Dictionary = AgriDonnees.FERMES.get(t, {}).get("betes", {})
	if places.is_empty():
		_text("Cette ferme n'a pas de bâtiment pour les bêtes. Construis un élevage, une ferme laitière (Production) ou une ferme de la bible : stabulation, porcherie, poulailler, bergerie, haras, ferme à cour carrée…", true)
		return
	var pre := agri.part_au_pre(bid)
	_text("Pâtures : %s ha · au pré : %d %% du fourrage · nourries à %d %%" % [Agriculture._ha(agri.paturage_ha(bid)),
		roundi(pre * 100.0), roundi(float(f.get("nb", 1.0)) * 100.0)], true)
	for e in AgriDonnees.ORDRE_ESPECES:
		if not places.has(e):
			continue
		var sp := AgriDonnees.espece(e)
		var n := int(f.betes.get(e, 0))
		_body.add_child(HSeparator.new())
		_text("%s : %d / %d" % [sp.name, n, int(places[e])], false, 13)
		var donne: Array[String] = []
		for g in sp.donne:
			if g != "fumier":
				donne.append("%s de %s" % [Ressources.format_t(float(sp.donne[g]) * maxi(n, 1)), Ressources.good_name(g).to_lower()])
		var mange: Array[String] = []
		for g in sp.mange:
			mange.append(Ressources.good_name(g).to_lower())
		_text("%s par jour%s · mangent %s · %s la bête" % [", ".join(donne) if not donne.is_empty() else "Loisir et travail",
			"" if n > 0 else " (pour une bête)", ", ".join(mange), _money(float(sp.prix))], true, 12)
		var r := _row()
		var esp: String = e
		for q in [1, 10, 100]:
			if int(places[e]) >= q:
				var qq: int = q
				_button("+%d" % q, func() -> void: agri.achete_betes(bid, esp, qq), r, "Acheter %d bête%s (%s)" % [q, "s" if q > 1 else "",
					_money(float(sp.prix) * q)])
		if n > 0:
			_button("Vendre 10", func() -> void: agri.vend_betes(bid, esp, 10), r, "À l'abattoir (bétail dans le stock de la ferme)")
		if int(f.faim.get(e, 0)) > 0:
			var w := _text("Elles ont faim depuis %d jour%s : il manque du fourrage !" % [int(f.faim[e]), "s" if int(f.faim[e]) > 1 else ""], false, 12)
			w.add_theme_color_override("font_color", Color("ff6b6b"))


# --- Machines ---------------------------------------------------------------------------

func _view_machines() -> void:
	_title.text = "Agriculture · machines"
	var bid := _choix_ferme()
	if bid < 0:
		return
	var ms := agri.machines_de(bid)
	var remise := agri.remise_concession()
	_text("Achetées avec ta caisse. Gazole, réparations et locations sont payés par la ferme. %s" % (
		"Concession agricole en ville : −10 % sur les achats, réparations moitié prix." if remise > 0.0 else
		"Une concession agricole en ville fait baisser les prix."), true, 12)
	_section("Parc de la ferme")
	if ms.is_empty():
		_text("Aucune machine : la ferme loue à la journée ce qu'il lui faut.", true)
	for i in ms.size():
		var m: Dictionary = ms[i]
		var r := _row()
		var l := Label.new()
		var panne: bool = int(m.panne) >= agri.last_day
		l.text = "%s%s · %d h" % [AgriDonnees.machine_name(String(m.t)), " (en panne)" if panne else "", roundi(float(m.h))]
		l.add_theme_font_size_override("font_size", 12)
		l.custom_minimum_size = Vector2(150, 0)
		r.add_child(l)
		_bar(r, float(m.us), Color("e76f51") if float(m.us) > AgriDonnees.PANNE else Color("90be6d"))
		var idx: int = i
		_button("Réviser", func() -> void: agri.revise_machine(bid, idx), r, "Remet l'usure à 10 % (payé par la ferme)")
		_button("Vendre", func() -> void: agri.vend_machine(bid, idx), r)
	_section("Acheter")
	for t in AgriDonnees.ORDRE_MACHINES:
		var md := AgriDonnees.machine(t)
		var r := _row()
		var l := Label.new()
		l.text = "%s · %s%s" % [md.name, _money(agri.prix_machine(t)),
			(" · %s ha/h" % ("%.1f" % float(md.ha_h)).replace(".", ",")) if float(md.ha_h) > 0.0 else ""]
		l.add_theme_font_size_override("font_size", 12)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.tooltip_text = "Location : %s par jour" % _money(float(md.loc))
		r.add_child(l)
		var typ: String = t
		_button("Acheter", func() -> void: agri.achete_machine(bid, typ), r)


# --- Nourriture --------------------------------------------------------------------------

func _view_nourriture() -> void:
	_title.text = "Agriculture · repas des habitants"
	var b := agri.repas.bilan
	var mode := ReglagesPartie.actuel.faim
	_text("Chaque habitant mange chaque jour ce qu'il trouve dans les commerces proches. Rayons vides : il a faim, il est moins content, sa santé baisse, puis il déménage%s. Réglage Admin (F10) : faim %s." % [
		" (ou meurt)" if mode == "mortelle" else "", {"aucune": "sans effet", "normale": "normale", "mortelle": "mortelle"}[mode]], true, 12)
	var row := _row()
	var l := Label.new()
	l.text = "Repas trouvés hier"
	l.add_theme_font_size_override("font_size", 13)
	l.custom_minimum_size = Vector2(130, 0)
	row.add_child(l)
	_bar(row, float(b.get("part", 1.0)), Color("90be6d") if float(b.get("part", 1.0)) > 0.8 else Color("e76f51"))
	_text("Foyers qui ont faim : %d sur %d%s" % [int(b.get("affames", 0)), int(b.get("foyers", 0)),
		(" · %d partis hier" % int(b.partis)) if int(b.get("partis", 0)) > 0 else ""])
	if int(b.get("morts", 0)) > 0:
		var w := _text("%d mort%s de faim hier." % [int(b.morts), "s" if int(b.morts) > 1 else ""])
		w.add_theme_color_override("font_color", Color("ff6b6b"))
	_section("Aliments (t par jour)")
	_text("Besoin des habitants · vendu hier · produit hier · en stock", true, 12)
	for e in agri.repas.bilan_aliments():
		var r := _row()
		var n := Label.new()
		n.text = Ressources.good_name(String(e.g))
		n.add_theme_font_size_override("font_size", 12)
		n.custom_minimum_size = Vector2(120, 0)
		r.add_child(n)
		var v := Label.new()
		v.text = "%s · %s · %s · %s" % [Ressources.format_t(float(e.besoin)), Ressources.format_t(float(e.vendu)),
			Ressources.format_t(float(e.produit)), Ressources.format_t(float(e.stock))]
		v.add_theme_font_size_override("font_size", 12)
		v.add_theme_color_override("font_color", Color("ff6b6b") if float(e.vendu) < float(e.besoin) * 0.75 and float(e.besoin) > 0.0
			else Color(1, 1, 1, 0.85))
		r.add_child(v)
	_section("La chaîne de la nourriture")
	_text("Champs et bêtes (fermes) → moulin, laiterie, abattoir, sucrerie, huilerie → boulangerie industrielle, usine agroalimentaire → camions → supérettes, supermarchés, marchés, boulangeries → assiettes des habitants. Sans fournisseur sur la carte, les camions vont chercher la marchandise hors de la carte (import).", true, 12)
