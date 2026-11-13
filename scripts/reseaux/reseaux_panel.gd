class_name ReseauxPanel
extends CanvasLayer
## Panneau « Réseaux » (touche O) : électricité, eau potable, égouts, gaz et chauffage.
## Bilan production / demande, sources et leur état, bâtiments coupés, outils de
## pose des lignes et conduites, calque de couverture, pannes en cours et
## tronçons usés, sécheresse et restrictions d'eau, comptes du mois.
## D'autres réseaux (télécoms…) peuvent y ajouter leur onglet : ajouter_onglet().

signal focus_requested(pos: Vector3)

const W := 348.0
const H := 520.0

var reseaux: Reseaux
var view := "elec"
var _panel: PanelContainer
var _body: VBoxContainer
var _scroll: ScrollContainer
var _tabs: HBoxContainer
var _extra := {}
var _tick := 0.0


func setup(r: Reseaux) -> void:
	reseaux = r
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
	icon.texture = Icones.get_icon("reseaux", 22, UiStyle.ACCENT)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	head.add_child(icon)
	var title := Label.new()
	title.text = "Réseaux"
	title.add_theme_font_size_override("font_size", 16)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var x := UiStyle.icon_button("fermer", "Fermer", "O", 18, 32)
	x.pressed.connect(func() -> void: set_open(false))
	head.add_child(x)
	_tabs = HBoxContainer.new()
	outer.add_child(_tabs)
	for spec in [["Courant", "elec"], ["Eau", "eau"], ["Égouts", "egout"], ["Chauffage", "gaz"], ["Comptes", "comptes"]]:
		_add_tab(spec[0], spec[1])
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(W, H)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(_scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 4)
	_scroll.add_child(_body)


func _add_tab(text: String, v: String) -> void:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(func() -> void: show_view(v))
	_tabs.add_child(b)


## Onglet d'un autre système (Télécom…) : son contrôle remplace le contenu.
func ajouter_onglet(titre: String, control: Control) -> void:
	var v := "x:" + titre
	_extra[v] = control
	_add_tab(titre, v)


func is_open() -> bool:
	return _panel.visible


func set_open(on: bool) -> void:
	_panel.visible = on
	if on:
		refresh()
	elif reseaux:
		reseaux.set_inactive()
		for r in Reseaux.RES:
			reseaux.vue.set_calque(r, false)


func toggle() -> void:
	set_open(not _panel.visible)


func show_view(v: String) -> void:
	view = v
	if reseaux and Reseaux.RES.has(v):
		for r in Reseaux.RES:
			reseaux.vue.set_calque(r, r == v)
	refresh()


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.physical_keycode == KEY_O and not k.shift_pressed and not k.ctrl_pressed and not k.alt_pressed:
		toggle()
		if is_open() and Reseaux.RES.has(view):
			show_view(view)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not is_open():
		return
	_tick += delta
	if _tick >= 1.0:
		_tick = 0.0
		if not view.begins_with("x:"):
			refresh()


func refresh() -> void:
	if _body == null or reseaux == null:
		return
	var keep := _scroll.scroll_vertical
	for c in _body.get_children():
		if _extra.values().has(c):
			_body.remove_child(c)
		else:
			c.queue_free()
	if view.begins_with("x:"):
		var c: Control = _extra[view]
		_body.add_child(c)
		return
	if view == "comptes":
		_comptes()
	else:
		_reseau(view)
	_scroll.set_deferred("scroll_vertical", keep)


func _label(t: String, size := 13, col := UiStyle.TEXT) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(W - 20, 0)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	_body.add_child(l)
	return l


func _reseau(res: String) -> void:
	var b := reseaux.bilan(res)
	var u: String = ReseauxTypes.UNITES[res]
	_label(ReseauxTypes.RES_NAMES[res], 15, UiStyle.ACCENT)
	if not ReglagesPartie.actuel.reseaux_obligatoires:
		_label("Réseaux non obligatoires (Admin, F10) : tout est desservi d'office.", 12, UiStyle.TEXT_DIM)
	var nom := "traitement" if res == "egout" else "production"
	_label("%s : %s %s (au mieux %s) · demande : %s %s" % [nom.capitalize(), Reseaux._fmt(b.production), u, Reseaux._fmt(b.nominal), Reseaux._fmt(b.demande), u])
	var servi := 1.0 if float(b.demande) <= 0.0 else float(b.servi) / float(b.demande)
	var col := UiStyle.GOOD if servi >= 0.95 else (Color("f4a261") if servi >= 0.5 else Color("e63946"))
	_label("Servi : %d %% · %d bâtiments, %d coupés, %d rationnés" % [roundi(servi * 100.0), int(b.batiments), int(b.coupes), int(b.partiels)], 13, col)
	if res == "eau" and float(b.get("stock_max", 0.0)) > 0.0:
		_label("Châteaux d'eau : %d / %d m³ en réserve" % [roundi(b.stock), roundi(b.stock_max)])
	if res == "elec" and float(b.get("stock_max", 0.0)) > 0.0:
		_label("Batteries : %.1f / %d MWh gardés" % [float(b.stock), roundi(b.stock_max)])
	if res == "egout" and float(b.get("rejets", 0.0)) > 0.0:
		_label("Rejeté sans traitement : %s m³/j (pollue la rivière)" % Reseaux._fmt(b.rejets), 13, Color("f4a261"))
	var inc := reseaux.incidents
	if res == "elec":
		_label("Vent : %d %% · soleil : %d %% · %d °C" % [roundi(reseaux.vent * 100.0), roundi(reseaux.soleil * 100.0), roundi(reseaux.temperature)], 12, UiStyle.TEXT_DIM)
		if inc.canicule:
			_label("Canicule : la climatisation fait grimper la demande (+%d %%)." % roundi((ReseauxIncidents.facteur_clim(reseaux.temperature) - 1.0) * 100.0), 13, Color("f4a261"))
	if res == "gaz":
		_label("%d °C dehors : besoin de chauffage %d %%." % [roundi(reseaux.temperature), roundi(reseaux.besoin * 100.0)], 12, UiStyle.TEXT_DIM)
		if int(b.get("froid", 0)) > 0:
			_label("%d bâtiments ont froid (ni gaz ni assez d'électricité)." % int(b.froid), 13, Color("e63946"))
		_label("Sans gaz ni chaleur, on se chauffe à l'électricité : la demande de courant grimpe en hiver.", 12, UiStyle.TEXT_DIM)
	if res == "eau":
		if inc.secheresse > 0.0:
			_label("Sécheresse : %d jours sans pluie, rivières et nappes à %d %%." % [int(inc.jours_secs), roundi((1.0 - 0.6 * inc.secheresse) * 100.0)], 13, Color("f4a261"))
		elif inc.jours_secs >= 5.0:
			_label("%d jours sans pluie." % int(inc.jours_secs), 12, UiStyle.TEXT_DIM)
		var rb := CheckBox.new()
		rb.text = "Restrictions d'eau (−20 %, les habitants râlent un peu)"
		rb.button_pressed = inc.restrictions
		rb.toggled.connect(func(on: bool) -> void:
			inc.restrictions = on
			reseaux.message.emit("Restrictions d'eau %s." % ("en vigueur : arrosage et piscines interdits" if on else "levées")))
		_body.add_child(rb)
	# Outils.
	var outils := HBoxContainer.new()
	_body.add_child(outils)
	for id in ReseauxTypes.troncons_de(res):
		var tr := ReseauxTypes.troncon(id)
		var bt := Button.new()
		bt.text = String(tr.name).replace("Ligne ", "").replace("Conduite d'eau potable", "Conduite").replace("Collecteur d'égout", "Collecteur").replace("Conduite de gaz ou de chaleur", "Conduite").capitalize()
		bt.tooltip_text = "%s\n%s\n%s par mètre" % [tr.name, tr.desc, BuildingSystem.format_money(ReglagesPartie.prix(int(tr.prix_m)))]
		bt.toggle_mode = true
		bt.button_pressed = reseaux.outil == Reseaux.Outil.TRACER and reseaux.type_troncon == id
		bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tid: String = id
		bt.pressed.connect(func() -> void:
			reseaux.set_outil(Reseaux.Outil.TRACER, tid)
			refresh())
		outils.add_child(bt)
	var gomme := Button.new()
	gomme.text = "Retirer"
	gomme.toggle_mode = true
	gomme.button_pressed = reseaux.outil == Reseaux.Outil.GOMME
	gomme.pressed.connect(func() -> void:
		reseaux.set_outil(Reseaux.Outil.GOMME)
		refresh())
	outils.add_child(gomme)
	var nb := 0
	for id in reseaux.reseau(res).troncons:
		nb += 1
		var ch := reseaux.chantier_de(res, id)
		if not ch.is_empty():
			var et: Array = ch.etape
			_label("Chantier : %s, %d %%%s" % [ReseauxTypes.troncon(String(reseaux.reseau(res).troncons[id].t)).get("name", ""), roundi(float(ch.av) * 100.0),
				(" (%s)" % String(et[2]).to_lower()) if et.size() > 2 else ""], 12, Color("f4a261"))
	_label("%d tronçon%s posé%s, %s · chaque route dessert aussi les bâtiments à moins de 30 m." % [nb, "s" if nb > 1 else "", "s" if nb > 1 else "", TransportSystem._km(float(b.lineaire))], 12, UiStyle.TEXT_DIM)
	_incidents(res)
	# Sources.
	_label("Sources (Construire > Réseaux)" if res != "egout" else "Stations et rejets (Construire > Réseaux)", 14, UiStyle.ACCENT)
	var r := reseaux.reseau(res)
	if r.sources.is_empty():
		_label("Aucune pour l'instant : pose %s dans le panneau Construire, catégorie Réseaux." % {"elec": "une centrale", "eau": "une usine d'eau ou un forage",
			"egout": "une station d'épuration", "gaz": "un poste de gaz, une chaufferie ou une géothermie"}[res], 12, UiStyle.TEXT_DIM)
	for bid in r.sources:
		var inf: Dictionary = reseaux.sources_info.get(bid, {})
		var t := BuildingCatalog.get_type(reseaux._type(bid))
		var nm := String(t.get("name", "Source"))
		var txt := "%s : %s / %s %s" % [nm, Reseaux._fmt(float(inf.get("cap", 0.0))), Reseaux._fmt(float(inf.get("max", 0.0))), u]
		if not r.est_raccorde(bid):
			txt += " · pas raccordé (route ou ligne à moins de 30 m)"
		elif String(inf.get("why", "")) != "":
			txt += " · " + String(inf.why)
		if res == "eau" and reseaux.qualite.has(bid) and float(reseaux.qualite[bid]) < 0.95:
			txt += " · eau polluée (%d %% potable)" % roundi(float(reseaux.qualite[bid]) * 100.0)
		if reseaux.stocks.has(bid):
			if res == "elec":
				txt = "%s : %.1f MWh gardés, %s MW rendus" % [nm, float(reseaux.stocks[bid]), Reseaux._fmt(float(inf.get("cap", 0.0)))]
			else:
				txt = "%s : %d m³ en réserve" % [nm, roundi(float(reseaux.stocks[bid]))]
		var bt := Button.new()
		bt.text = txt
		bt.alignment = HORIZONTAL_ALIGNMENT_LEFT
		bt.clip_text = true
		bt.tooltip_text = txt + "\nClic : y aller"
		bt.custom_minimum_size = Vector2(W - 20, 0)
		var pos: Vector3 = r.sources[bid].p
		bt.pressed.connect(func() -> void: focus_requested.emit(pos))
		_body.add_child(bt)
	# Bâtiments coupés.
	var k: String = Reseaux.CLE[res]
	var coupes := []
	for bid in r.consos:
		if float(reseaux.etat.get(bid, {}).get(k, 1.0)) < 0.5:
			coupes.append(bid)
	if not coupes.is_empty():
		_label("Bâtiments coupés", 14, Color("e63946"))
		for i in mini(coupes.size(), 12):
			var bid: int = coupes[i]
			var nm := String(BuildingCatalog.get_type(reseaux._type(bid)).get("name", "Bâtiment"))
			var why := "pas raccordé" if not r.est_raccorde(bid) else "pas assez de production sur ce réseau"
			var jours := float(reseaux.manque.get(bid, {}).get("e" if res == "elec" else "o", 0.0))
			var bt := Button.new()
			bt.text = "%s : %s%s" % [nm, why, (" · %d j" % roundi(jours)) if jours >= 1.0 else ""]
			bt.alignment = HORIZONTAL_ALIGNMENT_LEFT
			bt.clip_text = true
			bt.custom_minimum_size = Vector2(W - 20, 0)
			var pos: Vector3 = r.consos[bid].p
			bt.pressed.connect(func() -> void: focus_requested.emit(pos))
			_body.add_child(bt)
		if coupes.size() > 12:
			_label("… et %d autres." % (coupes.size() - 12), 12, UiStyle.TEXT_DIM)
	_label("Sans courant : fenêtres noires, usines et commerces au ralenti. Sans eau : maladies, pompiers sans bouches d'incendie. Au bout de 7 jours, les foyers partent. Sans chauffage l'hiver : froid et maladies.", 12, UiStyle.TEXT_DIM)


## Pannes en cours et tronçons usés (à rénover).
func _incidents(res: String) -> void:
	var inc := reseaux.incidents
	var lst := inc.de_reseau(res)
	if not lst.is_empty():
		_label("Pannes en cours", 14, Color("e63946"))
		for x in lst:
			var reste := maxf(float(x.fin) - inc.now(), 0.0) / 3600.0
			var row := HBoxContainer.new()
			_body.add_child(row)
			var bt := Button.new()
			bt.text = "%s · réparé dans %d h" % [inc.decrire(x).capitalize(), ceili(reste)]
			bt.alignment = HORIZONTAL_ALIGNMENT_LEFT
			bt.clip_text = true
			bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var pos: Vector3 = x.p
			bt.pressed.connect(func() -> void: focus_requested.emit(pos))
			row.add_child(bt)
			var vite := Button.new()
			vite.text = "Vite"
			vite.tooltip_text = "Réparer tout de suite (heures supplémentaires) : %s" % BuildingSystem.format_money(int(x.cout) * 2)
			var iid := int(x.id)
			vite.pressed.connect(func() -> void:
				inc.reparer_vite(iid)
				refresh())
			row.add_child(vite)
	var uses := []
	var rs := reseaux.reseau(res)
	for id in rs.troncons:
		if bool(rs.troncons[id].ok) and float(rs.troncons[id].get("u", 1.0)) < 0.6:
			uses.append(id)
	if uses.is_empty():
		return
	_label("Tronçons usés (ils cassent plus souvent)", 14, Color("f4a261"))
	for i in mini(uses.size(), 8):
		var tid: int = uses[i]
		var e: Dictionary = rs.troncons[tid]
		var row := HBoxContainer.new()
		_body.add_child(row)
		var l := Label.new()
		l.text = "%s, %d m : état %d %%" % [ReseauxTypes.troncon(String(e.t)).get("name", ""), roundi(ReseauBase.longueur(e.pts)), roundi(float(e.get("u", 1.0)) * 100.0)]
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.clip_text = true
		row.add_child(l)
		var rb := Button.new()
		rb.text = "Rénover"
		rb.tooltip_text = BuildingSystem.format_money(inc.prix_renovation(res, tid))
		rb.pressed.connect(func() -> void:
			inc.renover(res, tid)
			refresh())
		row.add_child(rb)


func _comptes() -> void:
	_label("Comptes des réseaux (ce mois-ci, jour %d)" % int(reseaux.compta.jours), 15, UiStyle.ACCENT)
	var any := false
	for src in [reseaux.compta.mois, reseaux.compta.precedent]:
		if src == reseaux.compta.precedent:
			if (src as Dictionary).is_empty():
				break
			_label("Mois précédent", 14, UiStyle.ACCENT)
		var tot := 0.0
		for poste in src:
			var v := float(src[poste])
			tot += v
			any = true
			_label("%s : %s%s" % [poste, "+" if v >= 0.0 else "", BuildingSystem.format_money(roundi(v))], 13, UiStyle.GOOD if v >= 0.0 else Color("f4a261"))
		if not (src as Dictionary).is_empty():
			_label("Solde : %s" % BuildingSystem.format_money(roundi(tot)), 13, UiStyle.TEXT)
	if not any:
		_label("Rien encore : les factures arrivent quand le temps passe.", 12, UiStyle.TEXT_DIM)
	_label("Prix : %s € le kWh, %s € le m³ d'eau, %s € le m³ d'assainissement, %s € le kWh de gaz ou de chaleur (×%s, réglage Admin F10)." % [
		String.num(Reseaux.PRIX_KWH, 2).replace(".", ","), String.num(Reseaux.PRIX_M3_EAU, 2).replace(".", ","),
		String.num(Reseaux.PRIX_M3_ASSAINISSEMENT, 2).replace(".", ","), String.num(Reseaux.PRIX_KWH_GAZ, 2).replace(".", ","),
		ReglagesPartie._fmt(ReglagesPartie.actuel.prix_services)], 12, UiStyle.TEXT_DIM)
	_label("Entretien prévu : " + ", ".join(_fmt_ent(reseaux.budget_entretien())), 12, UiStyle.TEXT_DIM)


static func _fmt_ent(d: Dictionary) -> Array:
	var out := []
	for k in d:
		out.append("%s %s/mois" % [String(k).to_lower(), BuildingSystem.format_money(int(d[k]))])
	return out
