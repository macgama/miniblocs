class_name ParcPanel
extends CanvasLayer
## Panneau « Parc de loisirs » (Maj+G) : note en étoiles, visiteurs, prix des
## billets, recettes ; attractions (files, fiabilité, pannes) ; ce que disent
## les visiteurs ; conseils.

signal focus_requested(pos: Vector3)

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
	outer.add_child(tabs)
	for spec in [["Parc", "parc", "parc"], ["Attractions", "attractions", "loisirs"], ["Visiteurs", "visiteurs", "habitants"]]:
		var b := Button.new()
		b.text = spec[0]
		b.icon = Icones.get_icon(spec[2], 18)
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
		var ob := OptionButton.new()
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
		parc.renommer(e, t)
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
	_section("Billets")
	_prix_row("Entrée", float(p.prix), 120.0, 1.0, func(v: float) -> void: parc.set_prix(e, v),
		"Prix du billet d'entrée. Trop cher, les visiteurs râlent ou font demi-tour ; pas assez, la caisse en pâtit.")
	_prix_row("Par tour de manège", float(p.prix_tour), 15.0, 0.5, func(v: float) -> void: parc.set_prix(e, float(parc.parcs[e].prix), v),
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
