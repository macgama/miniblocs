class_name ParcPanel
extends CanvasLayer
## Panneau « Parc de loisirs » (Maj+G) : note en étoiles, visiteurs, prix des
## billets, recettes ; attractions (files, fiabilité, pannes) ; ce que disent
## les visiteurs ; conseils ; publicité (ParcPublicite), bureau d'études
## (ParcRecherche) et soirées (ParcSoirees : feux d'artifice, spectacles du soir).

signal focus_requested(pos: Vector3)
## « Gérer le parc » : la maquette du mode gestion (GestionVue), ouverte depuis l'entrée.
signal gestion_requested(bid: int)

const W := 360.0
const H := 560.0

var parc: ParcLoisirs
var view := "parc"
## Entrée du parc affiché (−1 : le premier).
var choisi := -1
var _panel: PanelContainer
var _title: Label
var _body: VBoxContainer
var _scroll: ScrollContainer
var _tick := 0.0


func setup(p: ParcLoisirs) -> void:
	parc = p
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
	icon.texture = Icones.get_icon("parc", 22, UiStyle.ACCENT)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	head.add_child(icon)
	_title = Label.new()
	_title.text = "Parc de loisirs"
	_title.add_theme_font_size_override("font_size", 16)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	var x := UiStyle.icon_button("fermer", "Fermer", "Maj+G", 18, 32)
	x.pressed.connect(func() -> void: set_open(false))
	head.add_child(x)
	var tabs := HBoxContainer.new()
	var tabs2 := HBoxContainer.new()
	outer.add_child(tabs)
	outer.add_child(tabs2)
	var n_tab := 0
	for spec in [["Parc", "parc", "parc"], ["Attractions", "attractions", "loisirs"], ["Visiteurs", "visiteurs", "habitants"],
		["Publicité", "publicite", "megaphone"], ["Recherche", "recherche", "lampe"], ["Soirées", "soirees", "lune"]]:
		var b := Button.new()
		b.name = "Onglet_" + String(spec[1])
		b.text = spec[0]
		b.icon = Icones.get_icon(spec[2], 18)
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v: String = spec[1]
		b.pressed.connect(func() -> void: show_view(v))
		(tabs if n_tab < 3 else tabs2).add_child(b)
		n_tab += 1
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


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.physical_keycode == KEY_G and k.shift_pressed and not k.ctrl_pressed and not k.alt_pressed:
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
	if _tick >= 1.0:
		_tick = 0.0
		# Ne pas tout refaire pendant qu'on tape un nom ou un prix.
		var f := get_viewport().gui_get_focus_owner()
		if f != null and _body.is_ancestor_of(f):
			return
		var keep := _scroll.scroll_vertical
		refresh()
		_scroll.set_deferred("scroll_vertical", keep)


func _parc_courant() -> int:
	if parc == null or parc.parcs.is_empty():
		return -1
	if not parc.parcs.has(choisi):
		choisi = int(parc.parcs.keys()[0])
	return choisi


func refresh() -> void:
	if parc == null:
		return
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	var e := _parc_courant()
	if e < 0:
		_title.text = "Parc de loisirs"
		_text("Aucun parc. Pose une Entrée du parc au bord d'une route (Construire → Parc de loisirs), puis des attractions, des stands et des toilettes à moins de 250 m derrière elle.", true)
		_text("Conseil : commence par un carrousel, une friterie, une buvette, des toilettes et un atelier d'entretien. Les touristes viennent pour les attractions ; ils restent pour les frites.", true)
		return
	if parc.parcs.size() > 1:
		var ob := ChoixVisuel.new()
		ob.icone = "parc"
		ob.gradue = 0
		ob.focus_mode = Control.FOCUS_NONE
		var i := 0
		for k in parc.parcs:
			ob.add_item(String(parc.parcs[k].nom), int(k))
			if int(k) == e:
				ob.select(i)
			i += 1
		ob.item_selected.connect(func(idx: int) -> void:
			choisi = ob.get_item_id(idx)
			refresh())
		_body.add_child(ob)
	match view:
		"attractions": _view_attractions(e)
		"visiteurs": _view_visiteurs(e)
		"publicite": _view_publicite(e)
		"recherche": _view_recherche(e)
		"soirees": _view_soirees(e)
		_: _view_parc(e)


# --- Petits outils ---------------------------------------------------------------------

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


func _bar(frac: float, col: Color, label := "") -> void:
	var row := HBoxContainer.new()
	if label != "":
		var l := Label.new()
		l.text = label
		l.custom_minimum_size = Vector2(110, 0)
		l.add_theme_font_size_override("font_size", 12)
		row.add_child(l)
	var p := ProgressBar.new()
	p.min_value = 0.0
	p.max_value = 1.0
	p.value = clampf(frac, 0.0, 1.0)
	p.show_percentage = false
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.custom_minimum_size = Vector2(0, 8)
	var fill := StyleBoxFlat.new()
	fill.bg_color = col
	p.add_theme_stylebox_override("fill", fill)
	row.add_child(p)
	_body.add_child(row)


func _link(t: String, pos: Vector3) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 12)
	b.custom_minimum_size = Vector2(W - 30, 0)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.text = t
	b.tooltip_text = "Clique pour y aller."
	b.pressed.connect(func() -> void: focus_requested.emit(pos))
	_body.add_child(b)
	return b


static func euros(v: float) -> String:
	return BuildingSystem.format_money(roundi(v))


func _prix_row(label: String, value: float, maxv: float, step: float, cb: Callable, tip: String) -> void:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", 13)
	row.add_child(l)
	var sb := SpinBox.new()
	sb.min_value = 0.0
	sb.max_value = maxv
	sb.step = step
	sb.value = value
	sb.suffix = "€"
	sb.tooltip_text = tip
	sb.custom_minimum_size = Vector2(110, 0)
	sb.value_changed.connect(cb)
	row.add_child(sb)
	_body.add_child(row)


# --- Parc --------------------------------------------------------------------------------

func _view_parc(e: int) -> void:
	var p: Dictionary = parc.parcs[e]
	_title.text = String(p.nom)
	var nom := LineEdit.new()
	nom.text = String(p.nom)
	nom.tooltip_text = "Nom du parc (Entrée pour valider)."
	nom.text_submitted.connect(func(t: String) -> void:
		_faire("renommer", [e, t], e)
		nom.release_focus()
		refresh())
	_body.add_child(nom)
	var note := float(p.note)
	var l := _text("%s  %.1f / 5" % [ParcLoisirs.etoiles(note), note], false, 20)
	l.add_theme_color_override("font_color", Color("ffd166"))
	var now := parc._now(parc.clock if parc.clock > 0.0 else 0.0)
	var hr := ParcLoisirs.horaires(int(now.month))
	if parc.en_chantier(e):
		_text("Entrée en chantier : le parc ouvrira à la fin des travaux.", true)
	elif bool(p.ouvert):
		_text("Ouvert jusqu'à %d h · %d visiteurs en ce moment" % [int(hr.y), parc.presents(e)])
	else:
		_text("Fermé · ouvre de %d h à %d h ce mois-ci" % [int(hr.x), int(hr.y)], true)
	_link("Aller à l'entrée", parc._center(e))
	if not parc.en_chantier(e):
		var g := _bouton("Gérer le parc (maquette)", func() -> void: gestion_requested.emit(e),
			"Entre dans le parc en vue isométrique : aménage les zones, équipe-les, règle les demandes des visiteurs et répare les pannes.")
		g.name = "GererParc"
		g.icon = Icones.get_icon("parc", 18, UiStyle.ACCENT)
	_section("Billets")
	_prix_row("Entrée", float(p.prix), 120.0, 1.0, func(v: float) -> void: _faire("set_prix", [e, v, float(parc.parcs[e].prix_tour)], e),
		"Prix du billet d'entrée. Trop cher, les visiteurs râlent ou font demi-tour ; pas assez, la caisse en pâtit.")
	_prix_row("Par tour de manège", float(p.prix_tour), 15.0, 0.5, func(v: float) -> void: _faire("set_prix", [e, float(parc.parcs[e].prix), v], e),
		"0 € : attractions comprises dans l'entrée (comme dans les grands parcs).")
	_text("Le parc vaut environ %d € l'entrée aux yeux des visiteurs (selon ses attractions)." % roundi(parc.valeur(e)), true)
	var j: Dictionary = p.jour
	var y: Dictionary = p.hier
	_section("Aujourd'hui")
	_text("%d visiteurs (%d touristes, %d habitants) · %d tours de manège" % [int(j.visiteurs), int(j.touristes), int(j.habitants), int(j.tours)])
	_text("Recettes : %s (billets %s, stands %s%s)" % [euros(float(j.billets) + float(j.stands) + float(j.tours_argent)), euros(float(j.billets)),
		euros(float(j.stands)), (", tours %s" % euros(float(j.tours_argent))) if float(j.tours_argent) > 0.0 else ""])
	if int(j.refus) > 0:
		_text("%d personnes ont fait demi-tour devant le prix." % int(j.refus), true)
	_section("Hier")
	var rec := float(y.billets) + float(y.stands) + float(y.tours_argent)
	_text("%d visiteurs · recettes %s · charges %s" % [int(y.visiteurs), euros(rec), euros(float(y.depenses))])
	if int(y.sortis) > 0:
		_text("Humeur à la sortie : %d / 100 · pannes : %d" % [roundi(float(y.humeur) / int(y.sortis)), int(y.pannes)], true)
	var tot: Dictionary = p.total
	if int(tot.get("visiteurs", 0)) > 0:
		_text("Depuis l'ouverture : %d visiteurs, %s de recettes" % [int(tot.visiteurs), euros(float(tot.billets) + float(tot.stands) + float(tot.tours_argent))], true)
	_section("Note du parc")
	var d := parc.detail_note(e)
	for spec in [["variete", "Variété"], ["humeur", "Humeur"], ["proprete", "Propreté"], ["attente", "Files d'attente"], ["prix", "Prix"],
		["fiabilite", "Fiabilité"], ["services", "Services"]]:
		var v := float(d[spec[0]])
		_bar(v, Color("52b788") if v >= 0.6 else (Color("ffd166") if v >= 0.35 else Color("e63946")), spec[1])
	if float(d.get("gestion", 0.0)) > 0.0:
		_text("Aménagements (Gérer le parc) : +%.2f étoile" % float(d.gestion), true)
	_text("Propreté : %d / 100 · attente moyenne : %d min · techniciens : %.1f · agents de propreté : %.1f" % [roundi(parc.proprete(e)),
		roundi(float(p.attente)), float(p.techs), float(p.agents_propre)], true)
	_section("Conseils")
	for c in parc.conseils(e):
		_text("• " + c, true)


# --- Attractions -----------------------------------------------------------------------

func _view_attractions(e: int) -> void:
	var p: Dictionary = parc.parcs[e]
	_title.text = "%s · attractions" % String(p.nom)
	var any := false
	for role in ["attraction", "stand", "toilettes", "repos", "atelier"]:
		var list: Array = []
		for bid in p.items:
			if parc.items.has(bid) and String(parc.items[bid].role) == role:
				list.append(int(bid))
		if list.is_empty():
			continue
		any = true
		_section({"attraction": "Attractions", "stand": "Stands", "toilettes": "Toilettes", "repos": "Aires de repos", "atelier": "Ateliers"}[role])
		for bid in list:
			var it: Dictionary = parc.items[bid]
			var t := parc._type_of(bid)
			var spec := ParcTypes.spec_of(t)
			var staff: Array = parc.personnel(bid)
			var line := parc.nom_de(bid)
			if parc.en_chantier(bid):
				line += " — en chantier"
			elif role == "attraction":
				var etat := "en marche" if float(it.fin) > 0.0 else "à l'arrêt"
				if bool(it.panne):
					etat = "EN PANNE (%s)" % ("dépanneur extérieur" if bool(it.dep) else "les techniciens réparent")
				line += " — %s\nFile : %d min · %d tours aujourd'hui · %s · sensations %d/10" % [etat, roundi(parc.attente(bid)),
					int(it.tours), "fiabilité %d %%" % roundi(float(it.fiab)), roundi(float(spec.exc))]
			elif role == "stand":
				line += " — %s le passage, %s aujourd'hui · %d en file" % [euros(float(spec.prix)), euros(float(it.argent)), (it.file as Array).size()]
			elif role == "toilettes":
				line += " — %d en file" % (it.file as Array).size()
			if int(BuildingCatalog.get_type(t).get("emplois", 0)) > 0 and not parc.en_chantier(bid):
				line += "\nPersonnel : %d %%%s" % [roundi(float(staff[0]) * 100.0), (" dont %d saisonnier%s" % [int(staff[1]), "s" if int(staff[1]) > 1 else ""]) if int(staff[1]) > 0 else ""]
			_link(line, parc._center(bid))
			if role == "attraction" and not parc.en_chantier(bid):
				_bar(float(it.fiab) / 100.0, Color("52b788") if float(it.fiab) > 60.0 else (Color("ffd166") if float(it.fiab) > 35.0 else Color("e63946")))
	if not any:
		_text("Rien encore dans ce parc.", true)
	var hp := parc.hors_parc()
	if not hp.is_empty():
		_section("Hors du parc")
		for bid in hp:
			_link("%s — trop loin d'une entrée (plus de 250 m) : il ne sert à rien." % parc.nom_de(int(bid)), parc._center(int(bid)))


# --- Visiteurs ----------------------------------------------------------------------------

func _view_visiteurs(e: int) -> void:
	var p: Dictionary = parc.parcs[e]
	_title.text = "%s · visiteurs" % String(p.nom)
	var n := 0
	var w := 0
	var acc := {"humeur": 0.0, "faim": 0.0, "soif": 0.0, "fatigue": 0.0, "vessie": 0.0, "argent": 0.0}
	var etats := {}
	for a in parc.agents.values():
		if int(a.parc) != e:
			continue
		n += 1
		w += int(a.w)
		for k in acc:
			acc[k] = float(acc[k]) + float(a[k])
		etats[String(a.etat)] = int(etats.get(String(a.etat), 0)) + int(a.w)
	if n == 0:
		_text("Personne en ce moment." if not bool(p.ouvert) else "Les premiers visiteurs arrivent.", true)
	else:
		_text("%d visiteurs dans le parc" % w)
		var parts: Array = []
		for k in [["file", "font la queue"], ["bord", "sont sur un manège"], ["marche", "se promènent"], ["repos", "se reposent"], ["sortie", "repartent"]]:
			if etats.has(k[0]):
				parts.append("%d %s" % [int(etats[k[0]]), k[1]])
		_text(", ".join(parts), true)
		if int(p.w) > 1:
			_text("(chaque petit personnage en représente jusqu'à %d)" % int(p.w), true)
		_section("En moyenne")
		_bar(float(acc.humeur) / n / 100.0, Color("52b788"), "Humeur")
		_bar(float(acc.faim) / n / 100.0, Color("f4a261"), "Faim")
		_bar(float(acc.soif) / n / 100.0, Color("4cc9f0"), "Soif")
		_bar(float(acc.fatigue) / n / 100.0, Color("adb5bd"), "Fatigue")
		_bar(float(acc.vessie) / n / 100.0, Color("cdb4db"), "Toilettes")
		_text("Il leur reste en moyenne %d € en poche." % roundi(float(acc.argent) / n), true)
	_section("Ce que disent les visiteurs")
	var d: Array = p.dernieres
	if d.is_empty():
		_text("Rien pour l'instant.", true)
	for t in d:
		_text("« %s »" % String(t), false, 12)
	var pens: Dictionary = p.pensees
	if not pens.is_empty():
		_section("Ce qui revient le plus")
		var keys := pens.keys()
		keys.sort_custom(func(a: String, b: String) -> bool: return int(pens[a]) > int(pens[b]))
		for i in mini(keys.size(), 6):
			var k := String(keys[i])
			var txt := String(ParcLoisirs.PENSEES.get(k, k)).replace("%s", "…").replace("%d", "…")
			_text("%d × « %s »" % [int(pens[k]), txt], true, 12)


# --- Publicité ---------------------------------------------------------------------------

## Choix en cours dans l'onglet Publicité (avant de lancer).
var _pub_support := "affiches"
var _pub_cible := "tous"
var _pub_semaines := 2
var _retour := ""


func _option(items: Array, ids: Array, choisi_id: String, cb: Callable, desactives: Array = []) -> ChoixVisuel:
	var ob := ChoixVisuel.new()
	ob.focus_mode = Control.FOCUS_NONE
	ob.custom_minimum_size = Vector2(W - 30, 0)
	for i in items.size():
		ob.add_item(String(items[i]), i)
		if desactives.has(ids[i]):
			ob.set_item_disabled(i, true)
		if String(ids[i]) == choisi_id:
			ob.select(i)
	ob.item_selected.connect(func(i: int) -> void: cb.call(String(ids[i])))
	_body.add_child(ob)
	return ob


func _bouton(t: String, cb: Callable, tip := "") -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = tip
	b.pressed.connect(cb)
	_body.add_child(b)
	return b


func _afficher_retour() -> void:
	if _retour != "":
		var l := _text(_retour, false, 12)
		l.add_theme_color_override("font_color", Color("ffd166"))
		_retour = ""


func _view_publicite(e: int) -> void:
	var p: Dictionary = parc.parcs[e]
	_title.text = "%s · publicité" % String(p.nom)
	var noto: Dictionary = p.get("noto", ParcPublicite.vide())
	_section("Notoriété")
	_bar(float(noto.ville), Color("4cc9f0"), "En ville")
	_bar(float(noto.region), Color("52b788"), "Dans la région")
	var eff := ParcPublicite.effet(noto)
	_text("Effet : +%d %% de touristes, +%d %% d'habitants. Elle retombe de %d %% par jour sans publicité." % [roundi((float(eff[0]) - 1.0) * 100.0),
		roundi((float(eff[1]) - 1.0) * 100.0), roundi(ParcPublicite.OUBLI * 100.0)], true)
	if float(noto.familles) > 0.05 or float(noto.sensations) > 0.05:
		_text("Public attiré : %d %% de familles, %d %% d'amateurs de sensations en plus." % [roundi(float(noto.familles) * 50.0),
			roundi(float(noto.sensations) * 50.0)], true)
	_section("Campagnes en cours")
	var camps: Array = p.get("campagnes", [])
	if camps.is_empty():
		_text("Aucune.", true)
	for c in camps:
		var s: Dictionary = ParcPublicite.SUPPORTS.get(String(c.support), {})
		var reste := int(c.fin) - parc.last_day
		var row := HBoxContainer.new()
		var l := Label.new()
		l.text = "%s → %s\n%s par semaine · encore %d jour%s · %s dépensés" % [String(s.get("nom", c.support)),
			String(ParcPublicite.CIBLES.get(String(c.cible), {}).get("nom", c.cible)).to_lower(), euros(float(s.get("semaine", 0.0))),
			maxi(reste, 0), "s" if reste > 1 else "", euros(float(c.get("depense", 0.0)))]
		l.add_theme_font_size_override("font_size", 12)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var stop := Button.new()
		stop.text = "Arrêter"
		stop.focus_mode = Control.FOCUS_NONE
		var sup := String(c.support)
		stop.pressed.connect(func() -> void:
			_faire("arreter_campagne", [e, sup], e)
			refresh())
		row.add_child(stop)
		_body.add_child(row)
	if float(p.hier.get("pub", 0.0)) > 0.0:
		_text("Hier : %s de publicité." % euros(float(p.hier.pub)), true)
	_section("Nouvelle campagne")
	var possibles := ParcPublicite.supports_possibles()
	if not possibles.has(_pub_support) and not possibles.is_empty():
		_pub_support = String(possibles[0])
	var noms: Array = []
	var bloques: Array = []
	for id in ParcPublicite.SUPPORTS_ORDRE:
		var sp: Dictionary = ParcPublicite.SUPPORTS[id]
		if ParcPublicite.disponible(id):
			noms.append("%s · %s/sem." % [String(sp.nom), BuildingSystem.format_short(roundi(float(sp.semaine)))])
		else:
			noms.append("%s · en %d" % [String(sp.nom), int(sp.annee)])
			bloques.append(id)
	_option(noms, ParcPublicite.SUPPORTS_ORDRE, _pub_support, func(id: String) -> void:
		_pub_support = id
		refresh(), bloques)
	_text(String(ParcPublicite.SUPPORTS[_pub_support].desc), true, 12)
	var cnoms: Array = []
	for id in ParcPublicite.CIBLES_ORDRE:
		cnoms.append("Cible : " + String(ParcPublicite.CIBLES[id].nom).to_lower())
	_option(cnoms, ParcPublicite.CIBLES_ORDRE, _pub_cible, func(id: String) -> void:
		_pub_cible = id
		refresh())
	var dnoms: Array = []
	var dids: Array = []
	for n in ParcPublicite.DUREES:
		dnoms.append("%d semaine%s · %s" % [n, "s" if n > 1 else "", euros(ParcPublicite.cout(_pub_support, n))])
		dids.append(str(n))
	_option(dnoms, dids, str(_pub_semaines), func(id: String) -> void:
		_pub_semaines = int(id)
		refresh())
	_bouton("Lancer la campagne", func() -> void:
		var why := _faire_r("lancer_campagne", [e, _pub_support, _pub_cible, _pub_semaines], e)
		_retour = why if why != "" else "Campagne lancée : %s." % String(ParcPublicite.SUPPORTS[_pub_support].nom).to_lower()
		refresh(), "Payée chaque jour par la caisse de la ville du parc.")
	_afficher_retour()
	_text("Une pub pour un parc mal noté marche moitié moins. Les familles dépensent aux stands ; les amateurs de sensations veulent des grands frissons.", true, 12)


# --- Recherche --------------------------------------------------------------------------

func _view_recherche(e: int) -> void:
	var r := parc.recherche
	_title.text = "Bureau d'études des parcs"
	_section("Budget")
	var bnoms: Array = []
	var bids: Array = []
	for i in ParcRecherche.BUDGETS.size():
		bnoms.append(String(ParcRecherche.BUDGET_NOMS[i]))
		bids.append(str(i))
	_option(bnoms, bids, str(r.budget), func(id: String) -> void:
		_faire("recherche_budget", [e, int(id)], e)
		refresh())
	var vis := 0.0
	for k in parc.parcs:
		vis += float(parc.parcs[k].hier.visiteurs)
	_text("%.1f points par jour (dont %.1f grâce aux %d visiteurs d'hier) · %d points en réserve." % [r.points_jour() + vis * ParcRecherche.POINTS_VISITEUR,
		vis * ParcRecherche.POINTS_VISITEUR, roundi(vis), roundi(r.points)], true)
	if parc.parcs.size() > 1:
		_text("Le budget est partagé entre les caisses des villes de tes %d parcs." % parc.parcs.size(), true, 12)
	_section("En cours")
	if r.en_cours == "":
		_text("Aucun projet. Choisis-en un ci-dessous.", true)
	else:
		var pr: Dictionary = ParcRecherche.PROJETS[r.en_cours]
		var req := r.points_requis(r.en_cours)
		_text("%s — %d / %d points" % [String(pr.nom), roundi(minf(r.points, req)), roundi(req)])
		_bar(r.points / maxf(req, 1.0), Color("ffd166"))
		var j := r.jours_restants(vis)
		_text("Encore environ %s." % ("∞ (aucun budget)" if is_inf(j) else ("%d jour%s" % [ceili(j), "s" if ceili(j) > 1 else ""])), true)
	if not r.file.is_empty():
		_section("Ensuite")
		for id in r.file:
			var row := HBoxContainer.new()
			var l := Label.new()
			l.text = String(ParcRecherche.PROJETS[String(id)].nom)
			var why := r.raison(String(id))
			if why != "":
				l.text += " (%s)" % why
			l.add_theme_font_size_override("font_size", 12)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			row.add_child(l)
			var x := Button.new()
			x.text = "Retirer"
			x.focus_mode = Control.FOCUS_NONE
			var pid := String(id)
			x.pressed.connect(func() -> void:
				_faire("recherche_retirer", [e, pid], e)
				refresh())
			row.add_child(x)
			_body.add_child(row)
	for typ in [["attraction", "Nouvelles attractions"], ["amelioration", "Améliorations"]]:
		var list: Array = r.proposables().filter(func(id: String) -> bool: return String(ParcRecherche.PROJETS[id].type) == typ[0])
		if list.is_empty():
			continue
		_section(String(typ[1]))
		for id in list:
			if id == r.en_cours or r.file.has(id):
				continue
			var pr: Dictionary = ParcRecherche.PROJETS[id]
			var why := r.raison(String(id))
			var row := HBoxContainer.new()
			var l := Label.new()
			l.text = "%s · %d pts%s" % [String(pr.nom), int(pr.points), ("\n" + why) if why != "" else ""]
			if pr.has("desc"):
				l.tooltip_text = String(pr.desc)
				l.mouse_filter = Control.MOUSE_FILTER_PASS
			l.add_theme_font_size_override("font_size", 12)
			if why != "":
				l.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			row.add_child(l)
			var pid := String(id)
			var go := Button.new()
			go.text = "Chercher"
			go.focus_mode = Control.FOCUS_NONE
			go.disabled = not r.possible(pid)
			go.tooltip_text = "Lancer ce projet tout de suite (le projet en cours passe après)."
			go.pressed.connect(func() -> void:
				_faire("recherche_lancer", [e, pid], e)
				refresh())
			row.add_child(go)
			var q := Button.new()
			q.text = "+"
			q.focus_mode = Control.FOCUS_NONE
			q.disabled = r.file.size() >= ParcRecherche.FILE_MAX
			q.tooltip_text = "Ajouter à la file d'attente."
			q.pressed.connect(func() -> void:
				_faire("recherche_ajouter", [e, pid], e)
				refresh())
			row.add_child(q)
			_body.add_child(row)
	if not r.faits.is_empty():
		_section("Déjà trouvé")
		var noms: Array = []
		for id in ParcRecherche.ORDRE:
			if r.faits.has(id):
				noms.append(String(ParcRecherche.PROJETS[id].nom))
		_text(", ".join(noms) + ".", true, 12)
	if not ParcRecherche.attractions_a_chercher():
		_text("Réglage de partie : toutes les attractions de l'époque se posent d'office (Admin F10 → Parc de loisirs). Le bureau d'études sert aux améliorations.", true, 12)


# --- Soirées ---------------------------------------------------------------------------

func _view_soirees(e: int) -> void:
	var p: Dictionary = parc.parcs[e]
	var prog: Dictionary = p.soiree
	_title.text = "%s · soirées" % String(p.nom)
	var now := parc._now(parc.clock if parc.clock > 0.0 else 0.0)
	var show := parc.spectacle_en_cours(e)
	if not show.is_empty():
		var l := _text("En ce moment : %s !" % String(ParcSoirees.TYPES[String(show.type)].nom), false, 15)
		l.add_theme_color_override("font_color", Color("ffd166"))
		_link("Aller voir (ralentis le temps avec T pour en profiter)", parc.centre(e))
	elif parc.soiree_ce_jour(e, now) and int(p.get("show_jour", -1)) != int(now.day):
		_text("Ce soir à %s : %s. Le parc ferme après le spectacle." % [_heure(ParcSoirees.heure(int(now.month))),
			String(ParcSoirees.TYPES[String(prog.type)].nom).to_lower()])
	elif int(p.get("annule_jour", -1)) == int(now.day):
		_text("Ce soir : annulé à cause de la pluie.", true)
	_section("Spectacle")
	var noms: Array = []
	var bloques: Array = []
	for id in ParcSoirees.TYPES_ORDRE:
		var t: Dictionary = ParcSoirees.TYPES[id]
		var why := ParcSoirees.raison(id)
		noms.append(String(t.nom) + ("" if why == "" else " · verrouillé"))
		if why != "":
			bloques.append(id)
	_option(noms, ParcSoirees.TYPES_ORDRE, String(prog.type), func(id: String) -> void:
		_faire("set_soiree", [e, id, int(prog.taille), String(prog.quand)], e)
		refresh(), bloques)
	var td: Dictionary = ParcSoirees.TYPES[String(prog.type)]
	_text(String(td.desc), true, 12)
	var why_t := ParcSoirees.raison(String(prog.type))
	if why_t != "":
		_text(why_t, true, 12)
	if String(prog.type) in ["feu_artifice", "pyromelodique"]:
		_text("Couleurs : %s." % ("dorées seulement (les feux en couleurs sont à inventer au bureau d'études)" if not ParcSoirees.couleurs() else "rouge, vert" + (", bleu et violet" if ParcSoirees.palette().size() > 5 else "")), true, 12)
	var tnoms: Array = []
	var tids: Array = []
	for i in 3:
		var pr := ParcSoirees.prix({"type": prog.type, "taille": i})
		tnoms.append("%s · %s · %d min" % [ParcSoirees.TAILLES[i], euros(pr), roundi(float(td.duree[i]))])
		tids.append(str(i))
	_option(tnoms, tids, str(int(prog.taille)), func(id: String) -> void:
		_faire("set_soiree", [e, String(prog.type), int(id), String(prog.quand)], e)
		refresh())
	_section("Quand")
	var qnoms: Array = []
	for q in ParcSoirees.QUAND_ORDRE:
		qnoms.append(String(ParcSoirees.QUAND[q]))
	_option(qnoms, ParcSoirees.QUAND_ORDRE, String(prog.quand), func(id: String) -> void:
		_faire("set_soiree", [e, String(prog.type), int(prog.taille), id], e)
		refresh())
	_text("Début à la nuit tombée : %s ce mois-ci." % _heure(ParcSoirees.heure(int(now.month))), true, 12)
	_bouton("Un spectacle ce soir", func() -> void:
		var why := _faire_r("soiree_ce_soir", [e], e)
		_retour = why if why != "" else "C'est noté : spectacle ce soir à %s." % _heure(ParcSoirees.heure(int(now.month)))
		refresh(), "En plus du programme, une seule fois.")
	_afficher_retour()
	_section("Effet")
	_text("+%d %% de visiteurs ce jour-là (surtout en fin d'après-midi), +%d d'humeur pour ceux qui le voient. Annulé sous la pluie%s (20 %% du prix payé quand même)." % [
		roundi(ParcSoirees.bonus(prog) * 100.0), roundi(ParcSoirees.humeur(prog)), "" if bool(td.pluie) else " (sauf celui-ci)"], true, 12)
	var y: Dictionary = p.hier
	if int(y.get("spectacles", 0)) > 0:
		_text("Hier soir : %d spectateurs." % int(y.spectateurs), true)
	var tot: Dictionary = p.total
	if int(tot.get("spectacles", 0)) > 0:
		_text("Depuis l'ouverture : %d spectacles, %d spectateurs." % [int(tot.spectacles), int(tot.spectateurs)], true)


static func _heure(h: float) -> String:
	var hh := int(h)
	var mm := roundi((h - hh) * 60.0)
	return "%d h %02d" % [hh, mm] if mm > 0 else "%d h" % hh


## Comme _faire, mais renvoie la raison d'un refus (en solo seulement).
func _faire_r(f: String, args: Array, e: int) -> String:
	if SystemesGeres.relayer("parc", f, args, parc._center(e)):
		return ""
	var r = parc.callv(f, args)
	return String(r) if r is String else ""


## Carte entre amis : la décision part au serveur (le maire de la ville du parc décide) ;
## en solo, elle est faite ici.
func _faire(f: String, args: Array, e: int) -> void:
	if SystemesGeres.relayer("parc", f, args, parc._center(e)):
		return
	parc.callv(f, args)
