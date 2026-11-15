class_name TourismePanel
extends CanvasLayer
## Menu « Tourisme » (barre du bas → Loisirs, ou Maj+D) :
## - En bref : touristes en ville, arrivées, nuitées, refus, réputation, attrait,
##   accès, dépenses dans la ville et ce que la caisse en touche, conseils.
## - Hébergements : chaque hôtel, camping, gîte… (étoiles, lits, remplissage,
##   prix de la nuit, comptes) ; fermer ou rouvrir.
## - Attractions : les sites qui attirent les touristes et leurs visites.
## - Publicité : campagnes pour faire venir plus de monde.
## - Bâtir : les bâtiments du tourisme (catégorie Construire « Hôtels et tourisme »).
## - Avis : ce que disent les touristes.

signal focus_requested(pos: Vector3)
signal building_chosen(id: String)

const W := 390.0
const H := 560.0
const TABS := [["En bref", "bref", "valise"], ["Hébergements", "heb", "lit"], ["Attractions", "sites", "appareil_photo"],
	["Publicité", "pub", "megaphone"], ["Bâtir", "batir", "construire"], ["Avis des touristes", "avis", "habitants"]]
const KINDS := {"parc": "Parc de loisirs", "zoo": "Zoo", "musee": "Musée", "spectacles": "Spectacle", "patrimoine": "Patrimoine"}

var tour: Tourisme
var view := "bref"
var _panel: PanelContainer
var _body: VBoxContainer
var _scroll: ScrollContainer
var _tab_buttons := {}
var _tick := 0.0
var prepare: Callable


func setup(t: Tourisme, prep: Callable = Callable()) -> void:
	tour = t
	prepare = prep
	_build()
	if tour != null:
		tour.changed.connect(func() -> void:
			if is_open() and view in ["bref", "heb", "sites"]:
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
	icon.texture = Icones.get_icon("valise", 22, UiStyle.ACCENT)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	head.add_child(icon)
	var title := Label.new()
	title.text = "Tourisme"
	title.add_theme_font_size_override("font_size", 16)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var x := UiStyle.icon_button("fermer", "Fermer", "Maj+D", 18, 32)
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
	if k and k.pressed and not k.echo and k.physical_keycode == KEY_D and k.shift_pressed and not k.ctrl_pressed and not k.alt_pressed:
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
	if _tick >= 3.0 and view in ["bref", "heb", "sites", "avis"]:
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


static func etoiles(n: float) -> String:
	var s := ""
	for i in 5:
		s += "★" if n >= i + 0.75 else ("⯪" if n >= i + 0.25 else "☆")
	return s


static func _euros(x: float) -> String:
	return BuildingSystem.format_money(int(x))


func refresh() -> void:
	if tour == null:
		return
	for v in _tab_buttons:
		(_tab_buttons[v] as Button).set_pressed_no_signal(v == view)
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	match view:
		"bref": _vue_bref()
		"heb": _vue_heb()
		"sites": _vue_sites()
		"pub": _vue_pub()
		"batir": _vue_batir()
		"avis": _vue_avis()


# --- En bref ------------------------------------------------------------------------------------

func _vue_bref() -> void:
	var r := tour.reputation
	var l := _label("Réputation  %s  %.1f / 5" % [etoiles(r), r], 18)
	l.add_theme_color_override("font_color", UiStyle.ACCENT)
	var c := tour.clients_total()
	var lt := tour.lits_total()
	_label("%d touristes dorment en ville ce soir · %d lits%s" % [c, lt, (" (%d %% occupés)" % roundi(100.0 * c / lt)) if lt > 0 else ""], 13)
	var h := tour.hier
	_titre("Hier")
	_ligne("Arrivées", "%d" % int(h.arrivees))
	_ligne("Nuitées", "%d" % int(h.nuitees))
	if int(h.refus) > 0:
		_ligne("Refusés faute de lits", "%d" % int(h.refus))
	_ligne("Touristes dans les attractions", "%d (avec les excursionnistes)" % int(h.excursions))
	if int(h.autocars) > 0:
		_ligne("Voyages organisés", "%d autocars" % int(h.autocars))
	_titre("Ce qu'ils ont dépensé hier")
	_ligne("Hébergements", _euros(float(h.hebergement)))
	_ligne("Restaurants et cafés", _euros(float(h.restaurants)))
	_ligne("Commerces", _euros(float(h.commerces)))
	_ligne("Souvenirs", _euros(float(h.souvenirs)))
	_ligne("Total", _euros(Tourisme.depenses(h)))
	_ligne("Pour la caisse de la ville", "%s (taxe de séjour %s, impôts %s)" % [_euros(float(h.ville)), _euros(float(h.taxe)), _euros(float(h.impots))])
	_titre("Pourquoi ils viennent")
	_ligne("Attrait de la ville", "%.1f points (%d sites)" % [tour.attrait_total, tour.sites.size()])
	var acc := tour.acces()
	var acc_txt: Array = ["routes"]
	if int(acc.gare) > 0:
		acc_txt.append("gare")
	if int(acc.aeroport) > 0:
		acc_txt.append("aéroport")
	if int(acc.port) > 0:
		acc_txt.append("port")
	if int(acc.autocars) > 0:
		acc_txt.append("autocars")
	_ligne("Accès", "%s (×%.2f)" % [", ".join(acc_txt), float(acc.f)])
	if tour.campagne != "":
		_ligne("Publicité", "%s, encore %d jours (×%.2f)" % [String(Tourisme.CAMPAGNES[tour.campagne].name), tour.jours_campagne(), tour.campagne_effet()])
	if not tour.services("office").is_empty():
		_ligne("Office de tourisme", "×%.2f, séjours plus longs" % tour.office_effet())
	if tour.ambiance != null:
		var now := tour._now(tour.ambiance.unix_time)
		_ligne("Demande du jour", "%d touristes voudraient venir (saison ×%.2f)" % [roundi(tour.demande(now)), float(Tourisme.SAISON.get(int(now.month), 1.0))])
	_historique()
	var cs := tour.conseils()
	if not cs.is_empty():
		_titre("Conseils")
		for t in cs:
			_label("• " + String(t), 12, true)


## Petites barres des nuitées des 30 derniers jours.
func _historique() -> void:
	if tour.historique.size() < 2:
		return
	_titre("Nuitées des derniers jours")
	var vals: Array = []
	var mx := 1
	for e in tour.historique.slice(maxi(0, tour.historique.size() - 30)):
		vals.append(int(e[2]))
		mx = maxi(mx, int(e[2]))
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(W - 40, 60)
	row.add_theme_constant_override("separation", 1)
	row.alignment = BoxContainer.ALIGNMENT_END
	for v in vals:
		var col := VBoxContainer.new()
		col.custom_minimum_size = Vector2(9, 60)
		col.alignment = BoxContainer.ALIGNMENT_END
		var bar := ColorRect.new()
		bar.color = UiStyle.ACCENT
		bar.custom_minimum_size = Vector2(8, maxf(1.0, 58.0 * float(v) / float(mx)))
		bar.tooltip_text = "%d nuitées" % int(v)
		bar.mouse_filter = Control.MOUSE_FILTER_PASS
		col.add_child(bar)
		row.add_child(col)
	_body.add_child(row)
	_label("Plus haut : %d nuitées en un jour" % mx, 11, true)


# --- Hébergements --------------------------------------------------------------------------------

func _vue_heb() -> void:
	var l := tour.list_hebergements()
	if l.is_empty():
		_label("Pas encore d'hébergement.", 14)
		_label("Sans lits, les touristes viennent à la journée et repartent le soir. Onglet Bâtir : camping, gîte, chambres d'hôtes, auberge de jeunesse, hôtels de 2 à 5 étoiles, résidence, village vacances. Les hôtels de la bible (motel, hôtel de chaîne, palace, ryokan…) comptent aussi.", 12, true)
		_bouton("Bâtir un hébergement", "construire", "Ouvre l'onglet Bâtir.", func() -> void: show_view("batir"))
		return
	var month := 1
	if tour.ambiance != null:
		month = int(tour._now(tour.ambiance.unix_time).month)
	for bid in l:
		var b := int(bid)
		var st: Dictionary = tour.heb[b]
		var sp := tour.spec(b)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		_body.add_child(box)
		var head := HBoxContainer.new()
		box.add_child(head)
		var nb := _bouton("%s  %s" % [String(st.nom), "★".repeat(int(sp.get("etoiles", 2)))], "lit", "Aller voir", func() -> void: focus_requested.emit(tour.pos_of(b)), head)
		nb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var genre := String(TourismeTypes.GENRES.get(String(sp.get("genre", "hotel")), "Hébergement"))
		var tname := String(BuildingCatalog.get_type(tour._type_of(b)).get("name", ""))
		_label("%s · %s%s" % [genre, tname, " · municipal" if tour.est_municipal(b) else ""], 11, true, box)
		var etat := ""
		if not bool(st.ouvert):
			etat = "fermé par toi"
		elif tour.buildings.en_chantier(b):
			etat = "en chantier"
		elif not tour.en_saison(b, month):
			etat = "fermé hors saison"
		elif tour.personnel(b) <= 0.0:
			etat = "fermé : pas de personnel"
		elif not tour.relie(b):
			etat = "pas relié à une route"
		var occ := tour.occupation(b)
		_label("%d / %d lits occupés (%d %%) · note %.1f ★%s" % [tour.clients(b), tour.lits(b), roundi(occ * 100.0), tour.note(b), (" · " + etat) if etat != "" else ""], 12, false, box)
		var hh: Dictionary = st.hier
		_label("Hier : %d arrivées, %d nuitées · recettes %s, charges %s" % [int(hh.arrivees), int(hh.nuitees), _euros(float(hh.ca)), _euros(float(hh.charges))], 11, true, box)
		if not tour.ignore_staff and tour.personnel(b) < 1.0:
			_label("Personnel : %d %%" % roundi(tour.personnel(b) * 100.0), 11, true, box)
		var row := HBoxContainer.new()
		box.add_child(row)
		var pl := Label.new()
		pl.text = "Nuit / personne"
		pl.add_theme_font_size_override("font_size", 12)
		row.add_child(pl)
		var spin := SpinBox.new()
		spin.min_value = 2
		spin.max_value = 2000
		spin.step = 1
		spin.value = float(st.prix)
		spin.suffix = "€"
		spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spin.value_changed.connect(func(v: float) -> void: tour.set_prix(b, v))
		row.add_child(spin)
		var ob := Button.new()
		ob.text = "Fermer" if bool(st.ouvert) else "Rouvrir"
		ob.focus_mode = Control.FOCUS_NONE
		ob.pressed.connect(func() -> void:
			tour.set_ouvert(b, not bool(tour.heb[b].ouvert))
			refresh())
		row.add_child(ob)
		_label("Prix conseillé : %s" % _euros(float(sp.get("prix", TourismeTypes.prix_ref(int(sp.get("etoiles", 2)))))), 11, true, box)
		box.add_child(HSeparator.new())


# --- Attractions -----------------------------------------------------------------------------------

func _vue_sites() -> void:
	if tour.sites.is_empty():
		_label("Rien à visiter pour l'instant.", 14)
		_label("Les touristes viennent pour les parcs de loisirs (Maj+A, Maj+G), les zoos (Maj+Z), les musées (Maj+C), les salles de spectacle (Maj+X) et le patrimoine (châteaux, cathédrales, temples, phares de la bible de Construire).", 12, true)
		return
	_label("Chaque site compte selon sa taille et sa note. Plusieurs genres de visites (parc, zoo, musée…) : +12 % d'attrait par genre en plus.", 11, true)
	var l := tour.sites.duplicate()
	l.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.pts) > float(b.pts))
	for s in l:
		var k := "%s:%s" % [String(s.kind), str(s.key)]
		var v := float(tour.visites_jour.get(k, 0.0))
		var pos: Vector3 = s.pos
		var b := _bouton("%s · %s" % [String(KINDS.get(String(s.kind), s.kind)), String(s.nom)], "appareil_photo", "Aller voir", func() -> void: focus_requested.emit(pos))
		b.clip_text = true
		_label("  %.1f points · note %.1f ★ · %d clients des hôtels attendus aujourd'hui" % [float(s.pts), float(s.note), roundi(v)], 11, true)


# --- Publicité ----------------------------------------------------------------------------------------

func _vue_pub() -> void:
	_label("Une campagne fait venir plus de touristes pendant quelques semaines. Une seule à la fois ; elle n'a d'effet que s'il y a des choses à voir et des lits.", 12, true)
	if tour.campagne != "":
		_titre("En cours : %s" % String(Tourisme.CAMPAGNES[tour.campagne].name))
		_label("Encore %d jours · arrivées ×%.2f" % [tour.jours_campagne(), tour.campagne_effet()])
	for id in Tourisme.CAMPAGNE_ORDER:
		var c: Dictionary = Tourisme.CAMPAGNES[id]
		var cid := String(id)
		var b := _bouton("%s — %s" % [String(c.name), _euros(float(c.prix))], "megaphone", "%d jours, arrivées ×%.2f" % [int(c.jours), float(c.effet)], func() -> void:
			var err := tour.lancer_campagne(cid)
			if err != "":
				tour.message.emit(err)
			refresh())
		b.disabled = tour.campagne != ""
		_label("  %d jours · arrivées ×%.2f" % [int(c.jours), float(c.effet)], 11, true)


# --- Bâtir --------------------------------------------------------------------------------------------

func _vue_batir() -> void:
	_label("Clic sur un bâtiment, puis sur la carte (au bord d'une route ; R pour tourner). Aussi dans Construire (B) → Hôtels et tourisme.", 12, true)
	var groupes := [["Plein air", ["aire_camping_cars", "camping", "camping_club"]], ["Chez l'habitant", ["gite_rural", "chambres_hotes", "auberge_jeunesse"]],
		["Hôtels", ["hotel_2", "hotel_3", "hotel_4", "palace"]], ["Séjours", ["residence_tourisme", "village_vacances"]],
		["Accueil et services", ["office_tourisme", "boutique_souvenirs_ville", "parking_autocars"]], ["Hôtels de la bible", TourismeTypes.AUTRES.keys()]]
	for g in groupes:
		_titre(String(g[0]))
		for id in g[1]:
			var t := BuildingCatalog.get_type(String(id))
			if t.is_empty():
				continue
			var sp := TourismeTypes.spec_of(String(id))
			var info := ""
			if String(sp.get("role", "")) == "hebergement":
				info = " · %s · %d lits" % ["★".repeat(int(sp.get("etoiles", 1))), TourismeTypes.lits_de(sp)]
			var tid := String(id)
			_bouton("%s — %s%s" % [String(t.name), _euros(float(BuildingCatalog.cost(tid))), info], "valise", String(t.get("desc", "")), func() -> void:
				if prepare.is_valid():
					prepare.call()
				building_chosen.emit(tid))


# --- Avis ---------------------------------------------------------------------------------------------

func _vue_avis() -> void:
	_label("Réputation : %s %.1f / 5" % [etoiles(tour.reputation), tour.reputation], 14)
	_label("Elle suit l'avis des touristes qui repartent : leur hôtel (confort et prix), les repas trouvés, ce qu'il y avait à voir, les courses, les souvenirs et la foule.", 11, true)
	if tour.dernieres.is_empty():
		_label("Aucun touriste n'a encore rien dit.", 12, true)
		return
	_titre("Ce qu'ils disent")
	for t in tour.dernieres:
		_label("« %s »" % String(t), 12)
	var keys := tour.pensees.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return int(tour.pensees[a]) > int(tour.pensees[b]))
	if not keys.is_empty():
		_titre("Ce qui revient le plus")
		for k in keys.slice(0, 6):
			var txt := String(Tourisme.PENSEES.get(k, k))
			if txt.contains("%d"):
				txt = txt.replace("%d", "…")
			_label("%d × %s" % [int(tour.pensees[k]), txt], 11, true)
