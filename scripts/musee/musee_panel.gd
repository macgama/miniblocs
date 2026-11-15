class_name MuseePanel
extends CanvasLayer
## Menu « Musée » (barre du bas → Loisirs, ou Maj+C) : tout pour créer et
## gérer un musée.
## - Mon musée : réputation en étoiles et son détail, visiteurs, recettes,
##   prix du billet, nom, collections, conseils.
## - Bâtir : musées prêts à poser (salles déjà aménagées), dessiner ses salles,
##   faire d'un bâtiment un musée, sols et murs de musée (parquet Versailles,
##   marbre, velours, feuille d'or, cimaise).
## - Salles : la fonction de chaque salle (galerie de peinture, salle
##   égyptienne, galerie des dinosaures…) et son aménagement automatique.
## - Objets : les ingrédients en vignettes 3D, par famille (vitrines, socles,
##   peinture, sculpture, antiquités, histoire naturelle, sciences, histoire,
##   arts du monde, éclairage, parcours, services), avec recherche.
## - Expositions : expositions temporaires à faire venir.
## - Visiteurs : ce qu'ils disent, la journée d'hier, depuis l'ouverture.

signal focus_requested(pos: Vector3)
## Le joueur veut dessiner ses salles : passer en mode Créer, Murs et étages.
signal draw_requested

const W := 380.0
const H := 560.0
const TABS := [["Mon musée", "musee", "musee"], ["Bâtir", "batir", "construire"], ["Salles", "salles", "piece"],
	["Objets", "objets", "vitrine"], ["Expositions", "expos", "tableau"], ["Visiteurs", "visiteurs", "habitants"]]

var musee: Musee
var mob: Mobilier
## Appelée avant de prendre un outil (range les autres outils).
var prepare: Callable
var view := "musee"
var famille := "vitrines"
var choisi := ""
var _search := ""
var _panel: PanelContainer
var _title: Label
var _body: VBoxContainer
var _scroll: ScrollContainer
var _tab_buttons := {}
var _vignettes: Vignettes
var _tick := 0.0
var _group := ButtonGroup.new()


func setup(m: Musee, prep: Callable = Callable()) -> void:
	musee = m
	mob = m.mob
	prepare = prep
	_build()
	if mob != null:
		mob.plan_selected.connect(func(id: String) -> void:
			if musee.musees.has(id):
				choisi = id)


func _build() -> void:
	layer = 6
	_vignettes = Vignettes.new()
	_vignettes.name = "VignettesMusee"
	add_child(_vignettes)
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
	icon.texture = Icones.get_icon("musee", 22, UiStyle.ACCENT)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	head.add_child(icon)
	_title = Label.new()
	_title.text = "Musée"
	_title.add_theme_font_size_override("font_size", 16)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.clip_text = true
	head.add_child(_title)
	var x := UiStyle.icon_button("fermer", "Fermer", "Maj+C", 18, 32)
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
	return _panel.visible


func set_open(on: bool) -> void:
	_panel.visible = on
	if on:
		refresh()
	else:
		_vignettes.cancel_all()


func toggle() -> void:
	set_open(not _panel.visible)


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.physical_keycode == KEY_C and k.shift_pressed and not k.ctrl_pressed and not k.alt_pressed:
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
	if _tick >= 1.5 and view in ["musee", "visiteurs", "expos"]:
		_tick = 0.0
		var f := get_viewport().gui_get_focus_owner()
		if f != null and _body.is_ancestor_of(f):
			return
		var keep := _scroll.scroll_vertical
		refresh()
		_scroll.set_deferred("scroll_vertical", keep)


func courant() -> String:
	if musee == null:
		return ""
	var l := musee.list()
	if l.is_empty():
		return ""
	if not l.has(choisi):
		choisi = String(l[0])
	return choisi


# --- Petits outils d'interface ---------------------------------------------------------------------

func _label(text: String, size := 12, dim := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(W - 40, 0)
	if dim:
		l.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	_body.add_child(l)
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
	b.pressed.connect(cb)
	(parent if parent != null else _body).add_child(b)
	return b


func _prep() -> void:
	if prepare.is_valid():
		prepare.call()


static func etoiles(n: float) -> String:
	var s := ""
	for i in 5:
		s += "★" if n >= i + 0.75 else ("⯪" if n >= i + 0.25 else "☆")
	return s


func refresh() -> void:
	if musee == null:
		return
	for v in _tab_buttons:
		(_tab_buttons[v] as Button).set_pressed_no_signal(v == view)
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	var key := courant()
	_title.text = musee.nom(key) if key != "" else "Musée"
	match view:
		"musee": _vue_musee(key)
		"batir": _vue_batir(key)
		"salles": _vue_salles(key)
		"objets": _vue_objets()
		"expos": _vue_expos(key)
		"visiteurs": _vue_visiteurs(key)


func _choix_musee(key: String) -> void:
	var l := musee.list()
	if l.size() < 2:
		return
	var opt := OptionButton.new()
	opt.focus_mode = Control.FOCUS_NONE
	for k in l:
		opt.add_item(musee.nom(String(k)))
		opt.set_item_metadata(opt.item_count - 1, k)
		if String(k) == key:
			opt.select(opt.item_count - 1)
	opt.item_selected.connect(func(i: int) -> void:
		choisi = String(opt.get_item_metadata(i))
		refresh())
	_body.add_child(opt)


# --- Mon musée -------------------------------------------------------------------------------------

func _vue_musee(key: String) -> void:
	if key == "":
		_label("Pas encore de musée.", 14)
		_label("Onglet Bâtir : pose un musée prêt à visiter, ou fais d'un bâtiment en murs fins un musée. Tu peux aussi poser le « Musée » du catalogue (B → Loisirs).", 12, true)
		_bouton("Bâtir un musée", "construire", "Ouvre l'onglet Bâtir.", func() -> void: show_view("batir"))
		return
	_choix_musee(key)
	var st: Dictionary = musee.musees[key]
	var a := musee.analyse(key)
	var note := float(a.note)
	var l := _label("%s  %.1f / 5" % [etoiles(note), note], 18)
	l.add_theme_color_override("font_color", UiStyle.ACCENT)
	var det: Dictionary = a.detail
	if not det.is_empty():
		_label("Collections %.1f · confort %.1f · services %+.1f · variété %.1f · exposition %.1f · dégâts %.1f" % [
			float(det.collections), float(det.confort), float(det.services), float(det.variete), float(det.expo), float(det.degats)], 11, true)
	var now := musee._now(musee.clock if musee.clock > 0.0 else (musee.ambiance.unix_time if musee.ambiance != null else 0.0))
	var ouvert := musee.est_ouvert(key, now)
	_label(("Ouvert" if ouvert else "Fermé") + " · 10 h – %d h, fermé le lundi · %d visiteurs en ce moment" % [int(Musee.horaires(int(now.month)).y), musee.presents(key)], 12, true)
	var h: Dictionary = st.hier
	_label("Hier : %d visiteurs (%d habitants, %d touristes)%s" % [int(h.visiteurs), int(h.habitants), int(h.touristes),
		(", %d refoulés faute de place" % int(h.refus)) if int(h.refus) > 0 else ""], 12)
	_label("Recettes d'hier : %s (billets %s, boutique %s, café %s) · dépenses %s" % [BuildingSystem.format_money(int(musee.recettes(h))),
		BuildingSystem.format_money(int(h.billets)), BuildingSystem.format_money(int(h.boutique)), BuildingSystem.format_money(int(h.cafe)),
		BuildingSystem.format_money(int(h.depenses))], 12, true)
	# Billet et nom.
	var row := HBoxContainer.new()
	var pl := Label.new()
	pl.text = "Billet :"
	row.add_child(pl)
	var prix := SpinBox.new()
	prix.min_value = 0
	prix.max_value = 60
	prix.step = 1
	prix.value = float(st.prix)
	prix.suffix = "€"
	prix.value_changed.connect(func(v: float) -> void: _faire("set_prix", [key, v], key))
	row.add_child(prix)
	var gd := CheckBox.new()
	gd.text = "Gratuit le 1er dimanche"
	gd.button_pressed = bool(st.gratuit_dimanche)
	gd.focus_mode = Control.FOCUS_NONE
	gd.toggled.connect(func(on: bool) -> void: _faire("set_gratuit_dimanche", [key, on], key))
	row.add_child(gd)
	_body.add_child(row)
	var nrow := HBoxContainer.new()
	var ne := LineEdit.new()
	ne.text = musee.nom(key)
	ne.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ne.text_submitted.connect(func(t: String) -> void:
		_faire("renommer", [key, t], key)
		refresh())
	nrow.add_child(ne)
	var go := Button.new()
	go.icon = Icones.get_icon("lieu", 18)
	go.tooltip_text = "Aller voir le musée"
	go.focus_mode = Control.FOCUS_NONE
	go.pressed.connect(func() -> void: focus_requested.emit(musee.centre(key)))
	nrow.add_child(go)
	_body.add_child(nrow)
	# Collections.
	_titre("Collections")
	var th: Array = []
	for t in a.themes:
		th.append("%s %d" % [MuseeObjets.theme_name(String(t)), int(a.themes[t])])
	_label("%d œuvres · valeur assurée %s · prestige %d%s" % [int(a.oeuvres), BuildingSystem.format_money(int(a.valeur)), roundi(float(a.prestige)),
		(" · " + ", ".join(th)) if not th.is_empty() else ""], 12)
	if not (a.stars as Array).is_empty():
		_label("Les stars : " + ", ".join(a.stars), 12, true)
	_label("Surface %d m² · %d visiteurs à la fois · éclairage %d %% · confort de visite %d %%" % [int(a.area), int(a.capacite),
		roundi(minf(float(a.lumiere), 1.0) * 100.0), roundi(float(a.confort) * 100.0)], 12, true)
	var sv: Dictionary = a.services
	var noms := {"billetterie": "billetterie", "vestiaire": "vestiaire", "toilettes": "toilettes", "boutique": "boutique", "cafe": "café", "audioguide": "audioguides"}
	var have: Array = []
	var miss: Array = []
	for s in noms:
		(have if sv.has(s) else miss).append(noms[s])
	_label("Services : %s%s" % [", ".join(have) if not have.is_empty() else "aucun", (" · manque : " + ", ".join(miss)) if not miss.is_empty() else ""], 12, true)
	if musee.is_plan(key) and mob != null:
		var ms := mob.stats(key)
		_label("Personnel : %d emplois (gardiens, accueil, guides, conservateur)" % int(ms.emplois), 12, true)
	if not (a.conseils as Array).is_empty():
		_titre("Conseils")
		for c in a.conseils:
			_label("• " + String(c), 12)


# --- Bâtir -----------------------------------------------------------------------------------------

func _vue_batir(key: String) -> void:
	_titre("Musées prêts à visiter")
	_label("Clic sur un terrain libre, R pour tourner. Murs en pierre, salles à thème déjà aménagées, billetterie, boutique et café.", 11, true)
	for k in MuseeGabarits.ORDER:
		var g: Dictionary = MuseeGabarits.KINDS[k]
		var kind := String(k)
		var b := _bouton("%s · %d × %d m · %s" % [g.name, int(g.w), int(g.d), BuildingSystem.format_money(int(g.budget))], "musee", String(g.desc), func() -> void:
			_prep()
			mob.set_template(kind))
		b.clip_text = true
	_titre("Mes salles")
	_bouton("Dessiner mes salles (mode Créer, murs et étages)", "mur", "Passe en mode Créer pour tracer murs, pièces, portes et étages. Reviens ici (Tab) pour aménager.", func() -> void: draw_requested.emit())
	_bouton("Faire du bâtiment visé un musée", "musee", "Le bâtiment en murs fins visé devient un musée (usage Musée). Vise-le d'abord avec un outil de pose.", func() -> void:
		var id := mob.focus_id()
		if id == "":
			mob.message.emit("Vise d'abord un bâtiment en murs fins (survole-le avec un outil de pose, ou clic dessus avec l'outil Fonction).")
			return
		mob.set_usage(id, "musee")
		musee._dirty = true
		choisi = id
		mob.message.emit("%s est maintenant un musée." % mob.plan_name(id))
		refresh())
	_bouton("Aménager tout le musée (chaque salle selon sa fonction)", "interieur", "Pose le mobilier du musée dans toutes les salles du bâtiment visé.", func() -> void:
		var id := mob.focus_id() if mob.focus_id() != "" else (key if musee.is_plan(key) else "")
		if id == "":
			mob.message.emit("Vise d'abord un bâtiment en murs fins.")
			return
		var n := mob.furnish_plan(id, "contemporain")
		mob.message.emit("%d objets posés dans %s." % [n, mob.plan_name(id)]))
	_titre("Sols et murs de musée")
	_label("Choisis un matériau, puis clic sur un mur ou un sol (glissé : toute la pièce).", 11, true)
	var grid := GridContainer.new()
	grid.columns = 4
	_body.add_child(grid)
	for i in BlocMateriaux.LIST.size():
		var m: Dictionary = BlocMateriaux.LIST[i]
		if String(m.get("fam", "")) != "musee" and not String(m.name) in ["Marbre de Carrare", "Marbre noir", "Pierre de taille", "Terrazzo", "Béton ciré gris"]:
			continue
		var idx := i
		var b := Button.new()
		b.custom_minimum_size = Vector2(82, 30)
		b.text = String(m.name)
		b.clip_text = true
		b.tooltip_text = "%s · %d €" % [m.name, int(m.price)]
		b.add_theme_font_size_override("font_size", 10)
		b.focus_mode = Control.FOCUS_NONE
		var sw := Image.create(14, 14, false, Image.FORMAT_RGBA8)
		sw.fill(Color(String(m.c1)))
		b.icon = ImageTexture.create_from_image(sw)
		b.pressed.connect(func() -> void:
			_prep()
			if mob.pe != null:
				mob.pe.set_material(idx)
				mob.pe.set_tool(PlanEditor.Tool.PAINT))
		grid.add_child(b)


# --- Salles ----------------------------------------------------------------------------------------

func _vue_salles(key: String) -> void:
	_titre("Fonction des salles")
	_label("Choisis une fonction, puis clic dans une salle du musée. Les œuvres rangées dans la salle de leur thème valent plus (une momie dans la salle égyptienne, oui ; au café, non).", 11, true)
	for fn in MuseeObjets.SALLE_ORDER:
		var s: Dictionary = MuseeObjets.SALLES[fn]
		var f := String(fn)
		var row := HBoxContainer.new()
		_body.add_child(row)
		var b := _bouton(String(s.name), "piece", "%s\nClic dans une salle pour lui donner cette fonction." % s.desc, func() -> void:
			_prep()
			mob.set_room_fn(f)
			mob.set_tool(Mobilier.Tool.ROOM_FN), row)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var am := Button.new()
		am.icon = Icones.get_icon("interieur", 16)
		am.tooltip_text = "Aménager : clic dans une salle, elle reçoit le mobilier de « %s »." % s.name
		am.focus_mode = Control.FOCUS_NONE
		am.pressed.connect(func() -> void:
			_prep()
			mob.set_room_fn(f)
			mob.set_tool(Mobilier.Tool.ROOM_FN)
			mob.message.emit("Clic dans une salle pour lui donner la fonction « %s », puis « Aménager une salle »." % s.name))
		row.add_child(am)
	_bouton("Aménager une salle (selon sa fonction)", "interieur", "Clic dans une salle : elle est aménagée selon sa fonction.", func() -> void:
		_prep()
		mob.set_tool(Mobilier.Tool.FURNISH))
	_bouton("Retirer des objets", "gomme", "Clic sur un objet (ou glissé : tout un rectangle). La moitié du prix est remboursée.", func() -> void:
		_prep()
		mob.set_tool(Mobilier.Tool.ERASE))
	if key != "" and musee.is_plan(key):
		_titre("Les salles de ce musée")
		var a := musee.analyse(key)
		for s2 in a.salles:
			var nm := Mobilier.fn_name(String(s2.fn))
			_label("%s (%s, %d m²) : %d œuvres, prestige %d%s" % [nm, PlanEditor.level_name(int(s2.e)), int(s2.area), int(s2.oeuvres), roundi(float(s2.prestige)),
				(" · éclairage %d %%" % roundi(minf(float(s2.get("eclairage", 1.0)), 1.0) * 100.0)) if int(s2.oeuvres) > 0 else ""], 12, true)


# --- Objets ----------------------------------------------------------------------------------------

func _vue_objets() -> void:
	var fams := HFlowContainer.new()
	fams.add_theme_constant_override("h_separation", 2)
	fams.add_theme_constant_override("v_separation", 2)
	_body.add_child(fams)
	for f in MuseeObjets.FAMILLE_ORDER:
		var spec: Dictionary = MuseeObjets.FAMILLES[f]
		var b := Button.new()
		b.icon = Icones.get_icon(String(spec.icon), 18, UiStyle.ACCENT if f == famille else Color.WHITE)
		b.tooltip_text = "%s\n%s" % [spec.name, spec.desc]
		b.toggle_mode = true
		b.button_pressed = f == famille
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(54, 30)
		var ff := String(f)
		b.pressed.connect(func() -> void:
			famille = ff
			_search = ""
			refresh())
		fams.add_child(b)
	var fs: Dictionary = MuseeObjets.FAMILLES[famille]
	_titre(String(fs.name))
	_label(String(fs.desc), 11, true)
	var se := LineEdit.new()
	se.placeholder_text = "Chercher dans tout le musée…"
	se.text = _search
	se.clear_button_enabled = true
	se.text_submitted.connect(func(t: String) -> void:
		_search = t
		refresh())
	_body.add_child(se)
	var ids: Array = []
	if _search.strip_edges() != "":
		var t := _search.strip_edges().to_lower()
		for f2 in MuseeObjets.FAMILLE_ORDER:
			for id in MuseeObjets.of_famille(String(f2)):
				if String(Meubles.get_entry(String(id)).name).to_lower().contains(t):
					ids.append(id)
	else:
		ids = MuseeObjets.of_famille(famille)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	_body.add_child(grid)
	_vignettes.cancel_all()
	for id in ids:
		grid.add_child(_carte(String(id)))
	_label("R : tourner · clic droit : retirer · Page haut / bas : étage · Échap : arrêter", 11, true)


func _carte(id: String) -> Button:
	var e := Meubles.get_entry(id)
	var b := Button.new()
	b.custom_minimum_size = Vector2(84, 104)
	b.focus_mode = Control.FOCUS_NONE
	b.toggle_mode = true
	b.button_group = _group
	b.button_pressed = mob != null and mob.meuble == id and mob.tool == Mobilier.Tool.PLACE
	b.text = "%s\n%s" % [e.name, BuildingSystem.format_money(int(e.prix))]
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.clip_text = true
	b.add_theme_constant_override("icon_max_width", 60)
	b.add_theme_font_size_override("font_size", 10)
	b.add_theme_constant_override("line_spacing", -3)
	var tip := "%s\n%s · %d × %d m" % [e.name, Meubles.describe(id), int(e.w), int(e.d)]
	if String(e.get("theme", "")) != "":
		tip += "\n%s · prestige %d · valeur %s" % [MuseeObjets.theme_name(String(e.theme)), int(e.get("prestige", 0)), BuildingSystem.format_money(int(e.get("valeur", 0)))]
	if bool(e.get("fragile", false)):
		tip += "\nFragile : à protéger (vitrine, cordon)."
	if bool(e.get("protege", false)):
		tip += "\nProtège les œuvres fragiles de la salle."
	if int(e.get("lumiere", 0)) > 0:
		tip += "\nÉclairage +%d" % int(e.lumiere)
	if String(e.couche) == "mur":
		tip += "\nS'accroche sur un mur plein."
	elif bool(e.get("suspendu", false)):
		tip += "\nSuspendu au plafond."
	b.tooltip_text = tip
	_vignettes.request_mesh("musee:" + id, func() -> Mesh: return MeublesModeles.mesh_of(id), b, 72)
	b.pressed.connect(func() -> void:
		_prep()
		mob.set_meuble(id))
	return b


# --- Expositions -----------------------------------------------------------------------------------

func _vue_expos(key: String) -> void:
	if key == "":
		_label("Il faut d'abord un musée.", 13)
		return
	_choix_musee(key)
	var st: Dictionary = musee.musees[key]
	if String(st.expo) != "":
		var ex: Dictionary = Musee.EXPOS.get(String(st.expo), {})
		_titre("En ce moment")
		_label("« %s » : encore %d jours. Prestige +%d." % [ex.get("name", ""), musee.jours_expo(key), roundi(musee.expo_bonus(key))], 13)
	_titre("Faire venir une exposition")
	_label("Une exposition attire les touristes et les habitants pendant quelques semaines. Elle s'installe mieux dans une « Salle d'exposition temporaire » (sinon, effet réduit de moitié).", 11, true)
	for k in Musee.EXPO_ORDER:
		var ex2: Dictionary = Musee.EXPOS[k]
		var kk := String(k)
		var b := _bouton("%s · %d jours · %s" % [ex2.name, int(ex2.jours), BuildingSystem.format_money(int(ex2.prix))], "tableau",
			"Thème : %s · prestige +%d" % [MuseeObjets.theme_name(String(ex2.theme)), int(ex2.bonus)], func() -> void:
				var why := String(_faire("lancer_expo", [key, kk], key))
				if why != "":
					musee.message.emit("Impossible : %s." % why)
				refresh())
		b.disabled = String(st.expo) != ""
		b.clip_text = true


# --- Visiteurs -------------------------------------------------------------------------------------

func _vue_visiteurs(key: String) -> void:
	if key == "":
		_label("Il faut d'abord un musée.", 13)
		return
	_choix_musee(key)
	var st: Dictionary = musee.musees[key]
	_titre("Ce que disent les visiteurs")
	var d: Array = st.dernieres
	if d.is_empty():
		_label("Personne n'est encore venu. Le gardien s'ennuie.", 12, true)
	for t in d:
		_label("« %s »" % String(t), 12)
	_titre("Depuis l'ouverture")
	var tot: Dictionary = st.total
	_label("%d visiteurs (%d touristes) · recettes %s · dépenses %s · %d dégâts" % [int(tot.visiteurs), int(tot.touristes),
		BuildingSystem.format_money(int(musee.recettes(tot))), BuildingSystem.format_money(int(tot.depenses)), int(tot.degats)], 12, true)


## Carte entre amis : la décision part au serveur (le maire de la ville du musée décide,
## renvoie "") ; en solo, elle est faite ici.
func _faire(f: String, args: Array, key: String) -> Variant:
	if SystemesGeres.relayer("musee", f, args, musee.centre(key)):
		return ""
	var r: Variant = musee.callv(f, args)
	return r if r != null else ""
