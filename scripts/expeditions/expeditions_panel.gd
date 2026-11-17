class_name ExpeditionsPanel
extends CanvasLayer
## Menu « Expéditions » (barre du bas → Loisirs, ou Maj+F4) :
## - En cours : chaque expédition (étape, jours restants, santé, moral, butin),
##   l'événement qui attend une décision (choix avec leur chance de réussite),
##   le carnet de route, « le chef décide », rappeler l'équipe.
## - Préparer : la Société qui part, la destination, le chef, les membres, les
##   provisions ; qualités de l'équipe, durée, prix et conseils ; Partir.
## - Réserve : objets rares (musée, cabinet de curiosités, enchères, restitution),
##   animaux (enclos du zoo, autre zoo), spécialistes (ville où ils s'installent).
## - Récits : renommée et expéditions terminées.

signal focus_requested(pos: Vector3)
signal building_chosen(id: String)

const W := 420.0
const H := 580.0
const TABS := [["En cours", "cours", "boussole"], ["Préparer une expédition", "preparer", "construire"],
	["Réserve : objets, animaux, spécialistes", "reserve", "musee"], ["Récits et renommée", "recits", "journal"]]

var ex: Expeditions
var view := "cours"
var plan := {"dest": "egee", "chef": -1, "membres": {"guide": 1, "archeologue": 1, "porteur": 2}, "provisions": [], "auto": false}
var soc := -1
var _panel: PanelContainer
var _body: VBoxContainer
var _scroll: ScrollContainer
var _tab_buttons := {}
var _tick := 0.0
var _info: Label


func setup(e: Expeditions) -> void:
	ex = e
	_build()
	if ex != null:
		ex.changed.connect(func() -> void:
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
	icon.texture = Icones.get_icon("boussole", 22, UiStyle.ACCENT)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	head.add_child(icon)
	var title := Label.new()
	title.text = "Expéditions"
	title.add_theme_font_size_override("font_size", 16)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var x := UiStyle.icon_button("fermer", "Fermer", "Maj+F4", 18, 32)
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
	_info = Label.new()
	_info.add_theme_font_size_override("font_size", 12)
	_info.add_theme_color_override("font_color", Color("ffd27a"))
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.visible = false
	outer.add_child(_info)
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
		if ex != null and view == "cours" and ex.en_cours().is_empty():
			view = "preparer"
		refresh()


func toggle() -> void:
	set_open(not _panel.visible)


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.keycode == KEY_F4 and k.shift_pressed and not k.ctrl_pressed and not k.alt_pressed:
		if EditionDemo.panneau_verrouille("expeditions"):
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
	if _tick >= 2.0 and view == "cours":
		_tick = 0.0
		_refresh_keep()


func _refresh_keep() -> void:
	var f := get_viewport().gui_get_focus_owner()
	if f != null and _body.is_ancestor_of(f):
		return
	var keep := _scroll.scroll_vertical
	refresh()
	_scroll.set_deferred("scroll_vertical", keep)


# --- Petits outils ------------------------------------------------------------------------------

func _label(text: String, size := 12, dim := false, parent: Control = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(W - 40, 0)
	if dim:
		l.add_theme_color_override("font_color", Color(1, 1, 1, 0.62))
	(parent if parent != null else _body).add_child(l)
	return l


func _titre(text: String) -> void:
	var l := _label(text, 14)
	l.add_theme_color_override("font_color", UiStyle.ACCENT)


func _button(text: String, f: Callable, tip := "", parent: Control = null) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 12)
	b.pressed.connect(f)
	(parent if parent != null else _body).add_child(b)
	return b


func _row(parent: Control = null) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 4)
	(parent if parent != null else _body).add_child(r)
	return r


func _sep() -> void:
	var s := HSeparator.new()
	_body.add_child(s)


func _barre(nom: String, v: float, parent: Control = null) -> void:
	var r := _row(parent)
	var l := Label.new()
	l.text = nom
	l.custom_minimum_size = Vector2(70, 0)
	l.add_theme_font_size_override("font_size", 12)
	r.add_child(l)
	var p := ProgressBar.new()
	p.min_value = 0
	p.max_value = 100
	p.value = v
	p.show_percentage = false
	p.custom_minimum_size = Vector2(220, 12)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.add_child(p)
	var n := Label.new()
	n.text = "%d %%" % roundi(v)
	n.add_theme_font_size_override("font_size", 12)
	r.add_child(n)


func _dire(t: String) -> void:
	_info.text = t
	_info.visible = t != ""


## Fait une action (relayée au serveur sur une carte entre amis) ; affiche la raison d'un refus.
func _faire(f: String, args: Array) -> Variant:
	var p := ex.pos_of(soc) if soc >= 0 else Vector3.INF
	if SystemesGeres.relayer("expeditions", f, args, p if p != Vector3.INF else null):
		return ""
	var r: Variant = ex.callv(f, args)
	if r is String and String(r) != "":
		_dire(String(r).substr(0, 1).to_upper() + String(r).substr(1) + ".")
	else:
		_dire("")
	refresh()
	return r


func refresh() -> void:
	if _body == null or ex == null:
		return
	for c in _body.get_children():
		c.queue_free()
	for v in _tab_buttons:
		(_tab_buttons[v] as Button).set_pressed_no_signal(v == view)
	match view:
		"cours":
			_vue_cours()
		"preparer":
			_vue_preparer()
		"reserve":
			_vue_reserve()
		"recits":
			_vue_recits()


# --- En cours ------------------------------------------------------------------------------------

func _vue_cours() -> void:
	var ids := ex.en_cours()
	if ids.is_empty():
		_label("Aucune expédition en route.", 13)
		_label("Construis une Société des explorateurs, puis prépare une expédition : objets rares pour tes musées, animaux pour ton zoo, spécialistes pour tes villes.", 12, true)
		_button("Préparer une expédition", func() -> void: show_view("preparer"))
		return
	for id in ids:
		_carte_expedition(int(id))
		_sep()


func _carte_expedition(id: int) -> void:
	var x: Dictionary = ex.expeditions[id]
	var d := ExpeditionsDonnees.destination(String(x.dest))
	_titre("%s · %s" % [String(d.nom), ex.nom_chef(int(x.chef))])
	var etape := {"aller": "En route vers la destination", "exploration": "En exploration", "retour": "Sur le chemin du retour"}
	var reste := maxi(0, int(x.fin_etape) - ex.last_day)
	_label("%s : encore %d jour%s." % [String(etape.get(String(x.etat), "")), reste, "s" if reste > 1 else ""], 12)
	_barre("Santé", float(x.sante))
	_barre("Moral", float(x.moral))
	var eq := []
	for m in x.membres:
		eq.append("%d %s" % [int(x.membres[m]), String(ExpeditionsDonnees.membre(String(m)).nom).to_lower()])
	_label("Équipe : %s." % (", ".join(eq) if not eq.is_empty() else "le chef, tout seul"), 11, true)
	var b: Dictionary = x.butin
	var bt := []
	for o in b.objets:
		bt.append(String(ExpeditionsDonnees.objet(String(o)).nom))
	for a in b.animaux:
		bt.append("un couple de " + ZooEspeces.minuscule(ZooEspeces.nom(String(a))))
	for s in b.specialistes:
		bt.append(String(ExpeditionsDonnees.specialiste(String(s)).nom))
	_label("Butin : %s." % (", ".join(bt) if not bt.is_empty() else "rien pour l'instant"), 11, true)
	var ev: Dictionary = x.evenement
	if not ev.is_empty():
		var e: Dictionary = ExpeditionsDonnees.EVENEMENTS[String(ev.id)]
		var box := PanelContainer.new()
		box.add_theme_stylebox_override("panel", UiStyle.flat_box(Color(0.35, 0.25, 0.08, 0.6)))
		_body.add_child(box)
		var v := VBoxContainer.new()
		box.add_child(v)
		_label(String(e.titre), 13, false, v)
		_label(String(e.texte), 12, true, v)
		var ch: Array = e.choix
		for i in ch.size():
			var c: Dictionary = ch[i]
			var qn := String(c.get("q", ""))
			var tip := "Sans épreuve." if qn == "" else "Épreuve : %s. Chance de réussite : %d %%." % [String(ExpeditionsDonnees.QUALITES_NOMS[qn]).to_lower(), roundi(ex.chance(id, i) * 100.0)]
			var txt := String(c.t) + ("" if qn == "" else "  (%s, %d %%)" % [String(ExpeditionsDonnees.QUALITES_NOMS[qn]), roundi(ex.chance(id, i) * 100.0)])
			var ii := i
			_button(txt, func() -> void: _faire("choisir", [id, ii]), tip, v)
		var lim := maxi(0, int(ev.limite) - ex.last_day)
		_label("Sans réponse, le chef décidera dans %d jour%s." % [lim, "s" if lim > 1 else ""], 11, true, v)
	var r := _row()
	var auto := CheckBox.new()
	auto.text = "Le chef décide"
	auto.tooltip_text = "Le chef répond seul aux événements, au mieux de ce qu'il sait."
	auto.button_pressed = bool(x.auto)
	auto.focus_mode = Control.FOCUS_NONE
	auto.toggled.connect(func(on: bool) -> void: _faire("set_auto", [id, on]))
	r.add_child(auto)
	if String(x.etat) != "retour":
		_button("Rappeler l'équipe", func() -> void: _faire("rappeler", [id]), "L'équipe rentre tout de suite, avec ce qu'elle a trouvé.", r)
	var pos := ex.pos_of(int(x.soc))
	if pos != Vector3.INF:
		_button("Voir la Société", func() -> void: focus_requested.emit(pos), "", r)
	_label("Carnet de route", 12)
	var n := 0
	for l in x.log:
		_label("Jour %d · %s" % [int(l.jour) - int(x.depart), String(l.t)], 11, true)
		n += 1
		if n >= 6:
			break


# --- Préparer ------------------------------------------------------------------------------------

func _vue_preparer() -> void:
	var socs := ex.societes()
	if socs.is_empty():
		_label("Il faut d'abord une Société des explorateurs.", 13)
		_label("Salle des cartes, bibliothèque et cabinet de curiosités, au bord d'une route. Une Société prépare une expédition à la fois.", 12, true)
		_button("Construire une Société des explorateurs", func() -> void:
			set_open(false)
			building_chosen.emit("societe_explorateurs"))
		return
	if soc < 0 or not socs.has(soc) or ex.expedition_de(soc) >= 0:
		var libre := ex.societe_libre()
		soc = libre if libre >= 0 else int(socs[0])
	if ex.expedition_de(soc) >= 0:
		_label("Toutes les Sociétés ont une expédition en route. Construis-en une autre pour en lancer plusieurs à la fois.", 12, true)
		_button("Construire une Société des explorateurs", func() -> void:
			set_open(false)
			building_chosen.emit("societe_explorateurs"))
		return
	# Destination.
	_titre("Destination")
	var opt := OptionButton.new()
	opt.focus_mode = Control.FOCUS_NONE
	var ouvertes := ex.destinations_ouvertes()
	if not ouvertes.has(String(plan.dest)):
		plan.dest = String(ouvertes[0])
	for i in ouvertes.size():
		var dd := ExpeditionsDonnees.destination(String(ouvertes[i]))
		opt.add_item("%s (%s) · difficulté %d" % [String(dd.nom), String(dd.pays), int(dd.diff)], i)
		if String(ouvertes[i]) == String(plan.dest):
			opt.select(i)
	opt.item_selected.connect(func(i: int) -> void:
		plan.dest = String(ouvertes[i])
		refresh())
	_body.add_child(opt)
	var d := ExpeditionsDonnees.destination(String(plan.dest))
	_label(String(d.desc), 12, true)
	var th := []
	for t in d.themes:
		th.append({"objet": "objets rares", "animal": "animaux", "savoir": "spécialistes"}.get(String(t), String(t)))
	_label("Climat : %s. On peut y trouver : %s." % [String(ExpeditionsDonnees.CLIMAT_NOMS.get(String(d.climat), "")), ", ".join(th)], 11, true)
	var restants := 0
	for o in ExpeditionsDonnees.objets_de(String(plan.dest)):
		if not ex.objets.has(String(o)):
			restants += 1
	if (d.themes as Array).has("objet"):
		_label("Objets encore à découvrir ici : %d." % restants, 11, true)
	# Chef.
	_titre("Chef d'expédition")
	var libres := ex.chefs_libres()
	if libres.is_empty():
		_button("Recruter un chef", func() -> void: _faire("recruter_chef", []))
		return
	if not libres.has(int(plan.chef)):
		plan.chef = int(libres[0])
	var co := OptionButton.new()
	co.focus_mode = Control.FOCUS_NONE
	for i in libres.size():
		var c: Dictionary = ex.chefs[int(libres[i])]
		co.add_item("%s · niveau %d (%d expédition%s)" % [String(c.nom), ex.niveau_chef(int(libres[i])), int(c.faites), "s" if int(c.faites) > 1 else ""], i)
		if int(libres[i]) == int(plan.chef):
			co.select(i)
	co.item_selected.connect(func(i: int) -> void:
		plan.chef = int(libres[i])
		refresh())
	_body.add_child(co)
	# Membres.
	_titre("Équipe (%d / %d)" % [ex.taille_equipe(plan), ExpeditionsDonnees.EQUIPE_MAX])
	for m in ExpeditionsDonnees.MEMBRES_ORDRE:
		if not ex.membre_disponible(String(m)):
			continue
		var md := ExpeditionsDonnees.membre(String(m))
		var r := _row()
		var n := int((plan.membres as Dictionary).get(m, 0))
		var l := Label.new()
		var qs := []
		for q in (md.q as Dictionary):
			qs.append("%s +%d" % [String(ExpeditionsDonnees.QUALITES_NOMS[q]).substr(0, 4), int(md.q[q])])
		l.text = "%s ×%d  (%s)" % [String(md.nom), n, ", ".join(qs)]
		l.tooltip_text = "%s %d € par jour." % [String(md.desc), roundi(float(md.salaire))]
		l.mouse_filter = Control.MOUSE_FILTER_PASS
		l.add_theme_font_size_override("font_size", 12)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(l)
		var mm := String(m)
		var moins := _button("−", func() -> void: _changer_membre(mm, -1), "", r)
		moins.disabled = n <= 0
		var plus := _button("+", func() -> void: _changer_membre(mm, 1), "", r)
		plus.disabled = n >= int(md.max) or ex.taille_equipe(plan) >= ExpeditionsDonnees.EQUIPE_MAX
	# Provisions.
	_titre("Provisions et matériel")
	for p in ExpeditionsDonnees.PROVISIONS_ORDRE:
		var pd: Dictionary = ExpeditionsDonnees.PROVISIONS[p]
		var cb := CheckBox.new()
		cb.text = "%s · %s" % [String(pd.nom), BuildingSystem.format_money(int(pd.prix))]
		cb.tooltip_text = String(pd.desc)
		cb.button_pressed = (plan.provisions as Array).has(p)
		cb.focus_mode = Control.FOCUS_NONE
		cb.add_theme_font_size_override("font_size", 12)
		var pp := String(p)
		cb.toggled.connect(func(on: bool) -> void:
			var arr: Array = plan.provisions
			if on and not arr.has(pp):
				arr.append(pp)
			elif not on:
				arr.erase(pp)
			refresh())
		_body.add_child(cb)
	# Bilan.
	_titre("Bilan")
	var q := ex.qualites(plan)
	var qt := []
	for k in ExpeditionsDonnees.QUALITES:
		qt.append("%s %d" % [String(ExpeditionsDonnees.QUALITES_NOMS[k]), int(q[k])])
	_label("Qualités : " + ", ".join(qt) + ".", 12)
	var du := ex.durees(plan)
	var tr := ExpeditionsDonnees.transport(ex.annee())
	_label("Durée : %d jours (%d de voyage %s, %d d'exploration, %d de retour)." % [int(du.total), int(du.aller), String(tr[0]), int(du.explo), int(du.retour)], 12)
	var pr := ex.prix(plan)
	_label("Prix : %s (destination %s, salaires %s, voyage %s, provisions %s)." % [BuildingSystem.format_money(int(pr.total)),
		BuildingSystem.format_money(int(pr.base)), BuildingSystem.format_money(int(pr.salaires)),
		BuildingSystem.format_money(int(pr.voyage)), BuildingSystem.format_money(int(pr.provisions))], 12)
	for w in ex.avertissements(plan):
		var l2 := _label("· " + String(w), 11)
		l2.add_theme_color_override("font_color", Color("ffb36b"))
	var auto := CheckBox.new()
	auto.text = "Le chef décide seul en route"
	auto.button_pressed = bool(plan.auto)
	auto.focus_mode = Control.FOCUS_NONE
	auto.toggled.connect(func(on: bool) -> void: plan.auto = on)
	_body.add_child(auto)
	_button("Partir !", func() -> void:
		var r: Variant = _faire("partir", [soc, plan.duplicate(true)])
		if r is String and String(r) == "":
			show_view("cours"))


func _changer_membre(m: String, dn: int) -> void:
	var mb: Dictionary = plan.membres
	var n := clampi(int(mb.get(m, 0)) + dn, 0, int(ExpeditionsDonnees.membre(m).max))
	if n == 0:
		mb.erase(m)
	else:
		mb[m] = n
	refresh()


# --- Réserve -------------------------------------------------------------------------------------

func _vue_reserve() -> void:
	_titre("Objets rares")
	var montres := 0
	for lieu in ["reserve", "cabinet", "musee"]:
		for oid in ex.objets_en(lieu):
			_ligne_objet(String(oid), lieu)
			montres += 1
	if montres == 0:
		_label("Aucun objet pour l'instant. Une expédition avec un archéologue en rapportera.", 12, true)
	_sep()
	_titre("Animaux qui attendent un enclos")
	if ex.animaux.is_empty():
		_label("Aucun. Il faut un naturaliste et des caisses de transport pour en ramener.", 12, true)
	var zs := ZooSysteme.instance
	for i in ex.animaux.size():
		var a: Dictionary = ex.animaux[i]
		var r := _row()
		var l := Label.new()
		l.text = "%s (%s)" % [ZooEspeces.nom(String(a.esp)), "femelle" if bool(a.f) else "mâle"]
		l.add_theme_font_size_override("font_size", 12)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(l)
		var ii := i
		if zs != null and is_instance_valid(zs) and not zs.enclos.is_empty():
			var mb := MenuButton.new()
			mb.text = "Enclos ▾"
			mb.flat = false
			var pm := mb.get_popup()
			var ids: Array = zs.enclos.keys()
			ids.sort()
			for k in ids.size():
				pm.add_item(String(zs.enclos[ids[k]].get("nom", "Enclos %d" % int(ids[k]))), k)
			pm.id_pressed.connect(func(k: int) -> void: _faire("placer_animal", [ii, int(ids[k])]))
			r.add_child(mb)
		_button("Autre zoo", func() -> void: _faire("confier_animal", [ii]), "Confié à un autre zoo : 80 % de son prix pour la ville.", r)
	_sep()
	_titre("Spécialistes")
	if ex.specialistes.is_empty():
		_label("Aucun. On les rencontre surtout dans les destinations « spécialistes ».", 12, true)
	var vs := ex.villes()
	var ks: Array = ex.specialistes.keys()
	ks.sort()
	for sid in ks:
		var sd := ExpeditionsDonnees.specialiste(String(sid))
		_label("%s : %s" % [String(sd.nom), String(sd.desc)], 12)
		var r2 := _row()
		var o := OptionButton.new()
		o.focus_mode = Control.FOCUS_NONE
		o.add_item("En réserve (sans effet)", 0)
		var sel := 0
		for k in vs.size():
			o.add_item(String(vs[k][1]), k + 1)
			if int(vs[k][0]) == int(ex.specialistes[sid].ville):
				sel = k + 1
		o.select(sel)
		var s2 := String(sid)
		o.item_selected.connect(func(k: int) -> void: _faire("affecter", [s2, -1 if k == 0 else int(vs[k - 1][0])]))
		r2.add_child(o)


func _ligne_objet(oid: String, lieu: String) -> void:
	var o := ExpeditionsDonnees.objet(oid)
	var ou := {"reserve": "en réserve", "cabinet": "au cabinet de curiosités", "musee": "au musée"}
	if lieu == "musee" and Musee.instance != null and is_instance_valid(Musee.instance):
		ou.musee = "à " + Musee.instance.nom(String(ex.objets[oid].musee))
	_label("%s %s · prestige %d · %s" % [String(o.nom), ExpeditionsDonnees.etoiles(int(o.rare)), roundi(float(o.prestige)), String(ou.get(lieu, ""))], 12)
	var r := _row()
	var mu := Musee.instance
	if mu != null and is_instance_valid(mu) and not mu.musees.is_empty():
		var mb := MenuButton.new()
		mb.text = "Musée ▾"
		mb.flat = false
		var pm := mb.get_popup()
		var keys := mu.list()
		for k in keys.size():
			pm.add_item(mu.nom(String(keys[k])), k)
		pm.id_pressed.connect(func(k: int) -> void: _faire("donner_musee", [oid, String(keys[k])]))
		r.add_child(mb)
	if lieu != "cabinet":
		_button("Cabinet", func() -> void: _faire("exposer", [oid, -1]), "Exposé à la Société des explorateurs : attire les touristes.", r)
	_button("Vendre %s" % BuildingSystem.format_money(int(o.valeur)), func() -> void: _faire("vendre", [oid]), "Aux enchères, pour la caisse de la ville.", r)
	_button("Rendre", func() -> void: _faire("rendre", [oid]), "Rendu au pays d'origine : pas d'argent, mais de la renommée.", r)


# --- Récits --------------------------------------------------------------------------------------

func _vue_recits() -> void:
	_titre("Renommée de la ville : %d" % roundi(ex.renommee))
	_label("La renommée attire des touristes vers la Société et rend les habitants fiers. Les objets du cabinet de curiosités attirent aussi.", 12, true)
	if not ex.chefs.is_empty():
		_titre("Chefs d'expédition")
		for i in ex.chefs.size():
			var c: Dictionary = ex.chefs[i]
			_label("%s · niveau %d · %d expédition%s, %d réussie%s%s" % [String(c.nom), ex.niveau_chef(i), int(c.faites), "s" if int(c.faites) > 1 else "",
				int(c.reussies), "s" if int(c.reussies) > 1 else "", "" if bool(c.libre) else " · en route"], 12)
	_titre("Expéditions terminées")
	if ex.recits.is_empty():
		_label("Aucune pour l'instant.", 12, true)
	for r in ex.recits:
		_label(String(r.texte), 12)
