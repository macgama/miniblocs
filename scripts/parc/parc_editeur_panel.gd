class_name ParcEditeurPanel
extends CanvasLayer
## Menu « Créer un parc » (barre du bas → Loisirs, ou Maj+A) : tout ce qu'il
## faut pour construire un parc d'attractions soi-même.
##
## Onglets : Grands-huit, Aquatiques, Manèges, Boutiques, Allées et files,
## Décors à thème, Mes attractions. Pendant le tracé d'une attraction, le
## panneau devient l'éditeur de voie : pièces (avec leur petit dessin), chaîne,
## chiffres du tour (vitesse, G, notes), erreurs, couleurs, construire.

signal poser_batiment(id: String)
signal poser_decor(id: String, outil: int)
signal focus_requested(pos: Vector3)
signal ferme

const W := 440.0
const H := 600.0
const ONGLETS := [
	["rail", "Grands-huit", "parc"], ["eau", "Aquatiques", "eau"], ["manege", "Manèges", "loisirs"],
	["boutique", "Boutiques", "commerce"], ["allees", "Allées et files", "chemin"], ["decors", "Décors", "decors"],
	["mes", "Mes attractions", "creations"],
]

var attractions: AttractionsPerso
var allees: ParcAllees
var parc: ParcLoisirs
var onglet := "rail"
var theme_decor := "theme_parc"
var _panel: PanelContainer
var _title: Label
var _tabs: HBoxContainer
var _scroll: ScrollContainer
var _body: VBoxContainer
var _vignettes: Vignettes
var _a_refaire := false
var _tick := 0.0


func setup(a: AttractionsPerso, al: ParcAllees, p: ParcLoisirs) -> void:
	attractions = a
	allees = al
	parc = p
	_build()
	a.changed.connect(_plus_tard)
	al.changed.connect(_plus_tard)


func _build() -> void:
	layer = 6
	_vignettes = Vignettes.new()
	_vignettes.name = "VignettesParc"
	add_child(_vignettes)
	_panel = PanelContainer.new()
	UiStyle.place_right(_panel)
	_panel.offset_left = UiStyle.SIDE_RIGHT - W - 12.0
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
	_title.text = "Créer un parc"
	_title.add_theme_font_size_override("font_size", 16)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	var x := UiStyle.icon_button("fermer", "Fermer", "Maj+A", 18, 32)
	x.pressed.connect(func() -> void: set_open(false))
	head.add_child(x)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 2)
	outer.add_child(_tabs)
	for o in ONGLETS:
		var b := Button.new()
		b.icon = Icones.get_icon(o[2], 20)
		b.tooltip_text = o[1]
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(56, 34)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var id: String = o[0]
		b.set_meta("id", id)
		b.pressed.connect(func() -> void: show_onglet(id))
		_tabs.add_child(b)
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(W, H)
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
		attractions.apercu("")
		if attractions.outil == "gare":
			attractions.annuler()
		if allees.outil != "":
			allees.set_outil("")
		_vignettes.cancel_all()
		ferme.emit()


func toggle() -> void:
	set_open(not _panel.visible)


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.physical_keycode == KEY_A and k.shift_pressed and not k.ctrl_pressed and not k.alt_pressed:
		toggle()
		get_viewport().set_input_as_handled()


func show_onglet(o: String) -> void:
	onglet = o
	refresh()
	_scroll.scroll_vertical = 0


func _plus_tard() -> void:
	_a_refaire = true


func _process(delta: float) -> void:
	if not is_open():
		return
	_tick += delta
	if _a_refaire and _tick > 0.05:
		_a_refaire = false
		_tick = 0.0
		var f := get_viewport().gui_get_focus_owner()
		if f != null and _body.is_ancestor_of(f) and f is LineEdit:
			return
		var keep := _scroll.scroll_vertical
		refresh()
		_scroll.set_deferred("scroll_vertical", keep)


func refresh() -> void:
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	_vignettes.cancel_all()
	var edition := attractions != null and attractions.actif()
	for b: Button in _tabs.get_children():
		b.set_pressed_no_signal(not edition and String(b.get_meta("id")) == onglet)
		b.disabled = edition
	if edition:
		_title.text = "Tracé : " + String(attractions.design().get("nom", ""))
		_vue_trace()
		return
	_title.text = "Créer un parc"
	match onglet:
		"rail": _vue_familles(VoiePieces.ORDRE_RAIL, "Grands-huit", "Choisis un type de grand-huit, pose sa gare, puis ajoute les pièces une à une depuis la gare. Les virages se relèvent tout seuls selon la vitesse.")
		"eau":
			_vue_familles(VoiePieces.ORDRE_EAU, "Attractions sur l'eau", "Canal, tapis qui monte, chutes et éclaboussures. Le toboggan est un parcours ouvert : il finit par un bassin d'arrivée.")
			_section("Bassins et attractions aquatiques")
			_grille_batiments(ParcExtras.ORDER.filter(func(id: String) -> bool: return String(ParcExtras.TYPES[id].groupe) == "eau"))
		"manege":
			_section("Manèges")
			_texte("Attractions toutes faites, à poser derrière l'entrée du parc (à moins de 250 m).", true)
			var ids := []
			for id in ParcTypes.ORDER:
				if String(ParcTypes.TYPES[id].parc.role) == "attraction":
					ids.append(id)
			_grille_batiments(ids)
		"boutique": _vue_boutiques()
		"allees": _vue_allees()
		"decors": _vue_decors()
		"mes": _vue_mes()


# --- Petits outils --------------------------------------------------------------------------

func _texte(t: String, dim := false, size := 13, col := Color.TRANSPARENT) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(W - 30, 0)
	l.add_theme_font_size_override("font_size", size)
	if col != Color.TRANSPARENT:
		l.add_theme_color_override("font_color", col)
	elif dim:
		l.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	_body.add_child(l)
	return l


func _section(t: String) -> void:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", UiStyle.ACCENT)
	_body.add_child(l)


func _bouton(t: String, icon: String, cb: Callable, tip := "") -> Button:
	var b := Button.new()
	b.text = t
	if icon != "":
		b.icon = Icones.get_icon(icon, 18)
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = tip
	b.pressed.connect(cb)
	return b


func _rangee() -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	_body.add_child(h)
	return h


func _grille(cols := 4) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", 4)
	g.add_theme_constant_override("v_separation", 4)
	_body.add_child(g)
	return g


func _carte(titre: String, tip: String, w := 100.0, h := 104.0) -> Button:
	var b := Button.new()
	b.text = titre
	b.tooltip_text = tip
	b.custom_minimum_size = Vector2(w, h)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.expand_icon = true
	b.add_theme_font_size_override("font_size", 11)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.focus_mode = Control.FOCUS_NONE
	b.clip_text = false
	return b


func _barre(label: String, x: float, col: Color) -> void:
	var h := _rangee()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(110, 0)
	l.add_theme_font_size_override("font_size", 13)
	h.add_child(l)
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 10.0
	bar.value = x
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(200, 14)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill := StyleBoxFlat.new()
	fill.bg_color = col
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill)
	h.add_child(bar)
	var v := Label.new()
	v.text = "%.1f (%s)" % [x, VoiePhysique.mot(x)]
	v.add_theme_font_size_override("font_size", 12)
	h.add_child(v)


static func _euros(v: float) -> String:
	return BuildingSystem.format_money(int(v))


# --- Familles d'attractions sur voie -------------------------------------------------------------

func _vue_familles(ordre: Array, titre: String, aide: String) -> void:
	_section(titre)
	_texte(aide, true)
	var g := _grille(2)
	for fam_id in ordre:
		var f := VoiePieces.famille(String(fam_id))
		var b := _carte("%s\ngare %s · voie %s/m" % [String(f.nom), _euros(float(f.gare_prix)), _euros(float(f.m_prix))], String(f.desc), 206.0, 132.0)
		var id := String(fam_id)
		var modele := _modele_de(id)
		if not modele.is_empty():
			_vignettes.request_mesh("voie_modele_" + id, func() -> Mesh: return _maquette(modele), b, 160)
		else:
			b.icon = Icones.get_icon("parc", 40)
		var ep := EpoquesObjets.raison(EpoquesObjets.annee_famille_voie(id))
		if ep != "":
			b.disabled = true
			b.tooltip_text = "%s\n%s" % [String(f.desc), ep]
		b.pressed.connect(func() -> void:
			attractions.nouveau(id)
			refresh())
		g.add_child(b)
	_section("Modèles prêts à poser")
	_texte("Des attractions complètes, déjà bouclées : pose la gare, retouche si tu veux, puis Construire.", true)
	var g2 := _grille(2)
	for m: Dictionary in AttractionsPerso.modeles():
		if not String(m.famille) in ordre:
			continue
		if EpoquesObjets.annee_famille_voie(String(m.famille)) > EpoquesObjets.annee_partie():
			continue
		var b := _carte(String(m.nom), "Modèle « %s » (%s). Clic : poser la gare." % [String(m.nom), String(VoiePieces.famille(String(m.famille)).nom)], 206.0, 120.0)
		_vignettes.request_mesh("voie_pret_" + String(m.nom).md5_text(), func() -> Mesh: return _maquette(m), b, 160)
		var mm := m
		b.pressed.connect(func() -> void:
			attractions.nouveau(String(mm.famille), mm)
			refresh())
		g2.add_child(b)


func _modele_de(fam_id: String) -> Dictionary:
	for m: Dictionary in AttractionsPerso.modeles():
		if String(m.famille) == fam_id:
			return m
	var base := {"acier": "acier", "suspendu": "acier", "lance": "acier", "bois": "mine", "familial": "mine", "splash": "buches"}
	if base.has(fam_id):
		for m: Dictionary in AttractionsPerso.modeles():
			if String(m.famille) == String(base[fam_id]):
				var d := m.duplicate(true)
				d.famille = fam_id
				if fam_id == "lance":
					d.pieces = [{"p": "droit"}, {"p": "lanceur"}, {"p": "montee"}, {"p": "raidir_haut"}, {"p": "vertical_haut"}, {"p": "sommet"},
						{"p": "quitter_vertical_bas"}, {"p": "adoucir_bas"}, {"p": "fin_descente"}, {"p": "virage_g_large"}, {"p": "virage_g_large"}, {"p": "freins"}]
				return d
	return {}


## Maquette (voie + gare) d'un dessin, pour les vignettes.
static func _maquette(m: Dictionary) -> Mesh:
	var d := m.duplicate(true)
	d.erase("id")
	var tr := VoiePieces.trace(d)
	var sim := VoiePhysique.simule(d, tr)
	var voie := VoieMesh.voie(d, tr, sim, func(p: Vector3) -> float: return minf(0.0, p.y))
	return voie


# --- Éditeur de tracé ----------------------------------------------------------------------------

func _vue_trace() -> void:
	var d := attractions.design()
	var fam := VoiePieces.famille(String(d.famille))
	var nom := LineEdit.new()
	nom.text = String(d.nom)
	nom.placeholder_text = "Nom de l'attraction"
	nom.text_submitted.connect(func(t: String) -> void:
		attractions.regle("nom", t.strip_edges() if t.strip_edges() != "" else String(d.nom)))
	nom.focus_exited.connect(func() -> void:
		if nom.text.strip_edges() != "" and nom.text != String(attractions.design().get("nom", "")):
			attractions.regle("nom", nom.text.strip_edges()))
	_body.add_child(nom)
	_texte(String(fam.nom) + " · " + String(fam.desc), true, 12)
	if attractions.outil == "gare":
		_section("1. Pose la gare")
		_texte("Clique sur le terrain, dans l'enceinte du parc (à moins de 250 m de l'entrée). R : tourner d'un quart de tour. La voie partira vers la droite de la gare, vue depuis l'entrée.", false)
		var h := _rangee()
		h.add_child(_bouton("Annuler", "fermer", func() -> void:
			attractions.annuler()
			refresh()))
		return
	var res := attractions.resultat()
	var sim: Dictionary = res.get("sim", {})
	var tr: Dictionary = res.get("tr", {})
	# Barre d'outils.
	var h := _rangee()
	h.add_child(_bouton("Retirer", "retour", func() -> void: attractions.retire_derniere(), "Retire la dernière pièce (Retour arrière)"))
	if not bool(fam.get("ouvert", false)):
		var bb := _bouton("Boucler", "tourner", func() -> void: attractions.boucler(), "Raccord automatique jusqu'à la gare")
		bb.disabled = bool(d.get("raccord", false))
		h.add_child(bb)
	var essai := _bouton("Arrêter l'essai" if attractions.essai else "Essai", "play", func() -> void:
		attractions.essai = not attractions.essai
		refresh(), "Faire tourner un train à vide")
	h.add_child(essai)
	h.add_child(_bouton("Voir", "oeil", func() -> void: focus_requested.emit(attractions.fin_monde()), "Amener la vue au bout du tracé"))
	var h2 := _rangee()
	var ch := CheckButton.new()
	ch.text = "Chaîne de montée" if String(fam.genre) == "rail" else ("Tapis de montée" if String(fam.genre) == "eau" else "(pas de chaîne)")
	ch.disabled = String(fam.genre) == "glisse" or String(d.famille) == "lance" and false
	ch.button_pressed = attractions.chaine
	ch.focus_mode = Control.FOCUS_NONE
	ch.toggled.connect(func(on: bool) -> void: attractions.chaine = on)
	h2.add_child(ch)
	var pente_l := Label.new()
	pente_l.text = "   Pente : %s" % VoiePieces.nom_pente(attractions.pente())
	pente_l.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	h2.add_child(pente_l)
	# Chiffres du tour.
	_section("Le tour")
	if not sim.is_empty():
		_texte("%d m · %d s · %d km/h au plus · %.0f m de haut · chute %.0f m" % [roundi(float(sim.get("longueur", 0))), roundi(float(sim.get("duree", 0))),
			roundi(float(sim.get("v_max", 0)) * 3.6), float(sim.get("h_max", 0)), float(sim.get("chute", 0))], false, 13)
		_texte("G vertical %.1f à %.1f · G latéral %.1f · %d inversion%s · apesanteur %.1f s" % [float(sim.get("gv_min", 1)), float(sim.get("gv_max", 1)),
			float(sim.get("gl_max", 0)), int(sim.get("inversions", 0)), "s" if int(sim.get("inversions", 0)) > 1 else "", float(sim.get("airtime", 0))], true, 12)
		_barre("Excitation", float(sim.get("exc", 0)), Color("9fe3b0"))
		_barre("Intensité", float(sim.get("int", 0)), Color("ffd166"))
		_barre("Nausée", float(sim.get("nau", 0)), Color("f4978e"))
		var spec := VoiePhysique.spec_parc(d, sim)
		var debit := float(spec.cap) * 60.0 / maxf(float(spec.cycle), 0.1)
		_texte("%d places par départ · environ %d visiteurs par heure · prix %s" % [int(spec.cap), roundi(debit), _euros(VoiePhysique.prix(d, sim))], true, 12)
		for e in sim.get("erreurs", []):
			_texte("✖ " + String(e), false, 12, Color("ff8a80"))
		for a in sim.get("avert", []):
			_texte("⚠ " + String(a), false, 12, Color("ffd166"))
		var conflit := attractions.conflits()
		if conflit != "":
			_texte("✖ " + conflit, false, 12, Color("ff8a80"))
		if bool(tr.get("ferme", false)) and bool(sim.get("ok", false)) and conflit == "":
			_texte("✔ Le circuit est complet : tu peux construire.", false, 12, UiStyle.GOOD)
	# Pièces.
	var pente := attractions.pente()
	var ferme := bool(d.get("raccord", false))
	for grp in VoiePieces.GROUPES:
		var ids := []
		for pid in VoiePieces.PIECES:
			var p := VoiePieces.piece(pid)
			if String(p.groupe) != String(grp[0]):
				continue
			if p.has("genres") and not String(fam.genre) in (p.genres as Array):
				continue
			if int(p.get("inv", 0)) > 0 and not bool(fam.inversions):
				continue
			if p.has("p1") and absi(VoiePieces._norme(int(p.p1))) > int(fam.pente_max):
				continue
			if p.has("p1") and absi(int(p.p1)) > 90 and not bool(fam.inversions):
				continue
			ids.append(pid)
		if ids.is_empty():
			continue
		_section(String(grp[1]))
		var g := _grille(5)
		for pid in ids:
			var p := VoiePieces.piece(pid)
			var refus := VoiePieces.refus(String(d.famille), pente, pid, ferme)
			var b := Button.new()
			b.icon = VoiePieces.vignette(pid, 40, Color.WHITE if refus == "" else Color(1, 1, 1, 0.35))
			b.text = String(p.nom)
			b.tooltip_text = "%s · %d m%s" % [String(p.nom), roundi(float(p.L)), ("\n" + refus) if refus != "" else ""]
			b.custom_minimum_size = Vector2(80, 76)
			b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
			b.add_theme_font_size_override("font_size", 10)
			b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			b.focus_mode = Control.FOCUS_NONE
			b.disabled = refus != ""
			var id := String(pid)
			b.pressed.connect(func() -> void: attractions.ajoute(id))
			b.mouse_entered.connect(func() -> void: attractions.apercu(id))
			b.mouse_exited.connect(func() -> void: attractions.apercu(""))
			g.add_child(b)
	# Réglages.
	_section("Couleurs et trains")
	for q in [["rail", "Voie"], ["support", "Piliers"], ["train", "Train"]]:
		if q[0] == "support" and String(d.famille) in ["bois", "mine"]:
			continue
		var hr := _rangee()
		var l := Label.new()
		l.text = q[1]
		l.custom_minimum_size = Vector2(70, 0)
		hr.add_child(l)
		var pal: Array = VoieMesh.COULEURS[q[0]]
		for i in pal.size():
			var sw := Button.new()
			sw.custom_minimum_size = Vector2(26, 22)
			sw.focus_mode = Control.FOCUS_NONE
			sw.add_theme_stylebox_override("normal", UiStyle.flat_box(pal[i], 4, 2))
			sw.add_theme_stylebox_override("hover", UiStyle.flat_box((pal[i] as Color).lightened(0.2), 4, 2))
			if int(d.get("c_" + q[0], 0)) == i:
				sw.text = "•"
			var cle := "c_" + String(q[0])
			var ii := i
			sw.pressed.connect(func() -> void: attractions.regle(cle, ii))
			hr.add_child(sw)
	var ht := _rangee()
	for q in [["voitures", "Voitures par train", 1, 10], ["trains", "Trains" if String(fam.genre) == "rail" else "Bateaux", 1, 12]]:
		var l := Label.new()
		l.text = q[1]
		ht.add_child(l)
		var sp := SpinBox.new()
		sp.min_value = q[2]
		sp.max_value = q[3]
		sp.value = int(d.get(q[0], 1))
		sp.focus_mode = Control.FOCUS_NONE
		var cle := String(q[0])
		sp.value_changed.connect(func(v: float) -> void: attractions.regle(cle, int(v)))
		ht.add_child(sp)
	# Construire.
	_body.add_child(HSeparator.new())
	var hb := _rangee()
	var nouveau := int(attractions.brouillon.get("bid", -1)) < 0
	var prix := VoiePhysique.prix(d, sim) if not sim.is_empty() else 0
	var cb := _bouton(("Construire (%s)" % _euros(prix)) if nouveau else "Valider le tracé", "construire", func() -> void:
		if attractions.construire():
			refresh())
	cb.disabled = not bool(sim.get("ok", false))
	hb.add_child(cb)
	hb.add_child(_bouton("Annuler", "fermer", func() -> void:
		attractions.annuler()
		refresh()))
	hb.add_child(_bouton("Enregistrer", "sauver", func() -> void:
		AttractionsPerso.biblio_enregistre(attractions.design())
		attractions.message.emit("« %s » rangée dans Mes attractions." % String(attractions.design().nom)), "Ranger ce dessin dans Mes attractions (toutes les parties)"))
	var hv := _rangee()
	hv.add_child(_bouton("Tout effacer", "gomme", func() -> void: attractions.vide()))


# --- Boutiques et services -----------------------------------------------------------------------

func _vue_boutiques() -> void:
	_section("Entrée et services")
	_texte("L'entrée fonde le parc : pose-la au bord d'une route. Tout ce qui est à moins de 250 m derrière elle en fait partie.", true)
	_grille_batiments(["entree_parc", "toilettes_parc", "aire_repos_parc", "atelier_parc"] +
		ParcExtras.ORDER.filter(func(id: String) -> bool: return String(ParcExtras.TYPES[id].groupe) == "service"))
	_section("Manger, boire, souvenirs")
	var ids := []
	for id in ParcTypes.ORDER:
		if String(ParcTypes.TYPES[id].parc.role) == "stand":
			ids.append(id)
	ids += ParcExtras.ORDER.filter(func(id: String) -> bool: return String(ParcExtras.TYPES[id].groupe) == "boutique")
	_grille_batiments(ids)


func _grille_batiments(ids: Array) -> void:
	var g := _grille(4)
	for id in ids:
		var t := BuildingCatalog.get_type(String(id))
		if t.is_empty():
			continue
		var b := _carte(String(t.name), "%s\n%s · %d × %d m\n%s" % [String(t.name), _euros(float(BuildingCatalog.cost(String(id)))), int(t.w), int(t.d), String(t.get("desc", ""))])
		var tid := String(id)
		_vignettes.request_mesh("parc_bat_" + tid, func() -> Mesh: return BuildingCatalog.build_mesh(tid, ParcTypes.material()), b, 110)
		b.pressed.connect(func() -> void: poser_batiment.emit(tid))
		g.add_child(b)


# --- Allées et files -------------------------------------------------------------------------------

func _vue_allees() -> void:
	_section("Allées")
	_texte("Clic glissé pour tracer ; les bouts proches se soudent. Dès que tu traces tes allées, le parc n'en dessine plus tout seul et les visiteurs suivent les tiennes.", true)
	var hg := _rangee()
	for g in ParcAllees.GENRES:
		var b := Button.new()
		b.text = String(ParcAllees.GENRES[g].nom)
		b.toggle_mode = true
		b.button_pressed = allees.genre == g
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 11)
		var gg := String(g)
		b.pressed.connect(func() -> void:
			allees.genre = gg
			allees.set_outil("allee")
			refresh())
		hg.add_child(b)
	var hl := _rangee()
	var l := Label.new()
	l.text = "Largeur"
	hl.add_child(l)
	for w in ParcAllees.LARGEURS:
		var b := Button.new()
		b.text = "%.1f m" % w
		b.toggle_mode = true
		b.button_pressed = is_equal_approx(allees.largeur, w)
		b.focus_mode = Control.FOCUS_NONE
		var ww := float(w)
		b.pressed.connect(func() -> void:
			allees.largeur = ww
			allees.set_outil("allee")
			refresh())
		hl.add_child(b)
	var ho := _rangee()
	for o in [["allee", "Tracer une allée", "chemin"], ["file", "File d'attente", "habitants"], ["gomme", "Gomme", "gomme"]]:
		var b := _bouton(o[1], o[2], func() -> void: pass)
		b.toggle_mode = true
		b.button_pressed = allees.outil == o[0]
		var oo := String(o[0])
		b.pressed.connect(func() -> void:
			allees.set_outil("" if allees.outil == oo else oo)
			refresh())
		ho.add_child(b)
	_section("Files d'attente")
	_texte("Glisse depuis l'entrée d'une attraction ou d'un stand, puis depuis le bout de la file pour la prolonger en zigzag. Les visiteurs y font la queue, garde-corps compris.", true)
	if allees.files.is_empty():
		_texte("Aucune file dessinée : les visiteurs attendent en rangs devant l'entrée.", true, 12)
	for f in allees.files:
		var long := 0.0
		var pts: Array = f.pts
		for i in range(1, pts.size()):
			long += (pts[i - 1] as Vector2).distance_to(pts[i])
		_texte("• %s : %d m, environ %d places" % [parc.nom_de(int(f.bid)), roundi(long), roundi(long / 0.8)], false, 12)
	_texte("%d morceaux d'allée posés." % allees.allees.size(), true, 12)


# --- Décors à thème --------------------------------------------------------------------------------

func _vue_decors() -> void:
	_section("Décors à thème")
	_texte("Clic pour poser (R pour tourner), glisser pour une rangée. Les décors se gomment avec la gomme des décors (touche G).", true)
	var ht := HFlowContainer.new()
	_body.add_child(ht)
	for th in ParcThemes.THEMES:
		var b := Button.new()
		b.text = String(th[1]).replace("Parc : ", "")
		b.toggle_mode = true
		b.button_pressed = theme_decor == th[0]
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 12)
		var tid := String(th[0])
		b.pressed.connect(func() -> void:
			theme_decor = tid
			refresh())
		ht.add_child(b)
	var g := _grille(4)
	for id in ParcThemes.PROPS:
		var p: Array = ParcThemes.PROPS[id]
		if String(p[1]) != theme_decor:
			continue
		var b := _carte(String(p[0]), String(p[0]))
		var did := String(id)
		_vignettes.request_mesh("parc_decor_" + did, func() -> Mesh: return ParcThemes.mesh(did), b, 110)
		b.pressed.connect(func() -> void: poser_decor.emit(did, DecorSystem.Outil.POSER))
		g.add_child(b)
	var hp := _rangee()
	hp.add_child(_bouton("Pinceau", "paysage", func() -> void: poser_decor.emit("", DecorSystem.Outil.PINCEAU), "Semer le décor choisi au hasard"))
	hp.add_child(_bouton("Gomme", "gomme", func() -> void: poser_decor.emit("", DecorSystem.Outil.GOMME)))
	_texte("Les autres décors du jeu (bancs, fontaines, clôtures, rochers, animaux…) sont dans le panneau Décors (touche G).", true, 12)


# --- Mes attractions --------------------------------------------------------------------------------

func _vue_mes() -> void:
	_section("Attractions posées")
	var n := 0
	if attractions.buildings:
		for bid in attractions.buildings.buildings:
			var t := String(attractions.buildings.buildings[bid].t)
			if not AttractionsPerso.is_atr(t):
				continue
			var d := AttractionsPerso.design_of_type(t)
			if d.is_empty():
				continue
			n += 1
			var sim: Dictionary = AttractionsPerso.calcule(d).sim
			var h := _rangee()
			var l := Label.new()
			l.text = "%s · %s · exc. %.1f" % [String(d.nom), String(VoiePieces.famille(String(d.famille)).nom), float(sim.get("exc", 0))]
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l.clip_text = true
			l.add_theme_font_size_override("font_size", 12)
			h.add_child(l)
			var b2 := int(bid)
			h.add_child(_bouton("", "oeil", func() -> void: focus_requested.emit(parc._center(b2)), "Aller voir"))
			h.add_child(_bouton("", "editeur", func() -> void:
				attractions.modifier(b2)
				refresh(), "Modifier le tracé"))
			h.add_child(_bouton("", "sauver", func() -> void:
				AttractionsPerso.biblio_enregistre(d)
				attractions.message.emit("« %s » rangée dans Mes attractions." % String(d.nom)), "Ranger dans Mes attractions"))
	if n == 0:
		_texte("Aucune attraction créée dans cette partie. Commence par l'onglet Grands-huit ou Aquatiques.", true, 12)
	_section("Mes attractions (toutes les parties)")
	var bib := AttractionsPerso.biblio()
	if bib.is_empty():
		_texte("Vide pour l'instant : le bouton Enregistrer de l'éditeur y range un tracé.", true, 12)
	for id in bib:
		var d: Dictionary = bib[id]
		var h := _rangee()
		var l := Label.new()
		l.text = "%s · %s" % [String(d.get("nom", "?")), String(VoiePieces.famille(String(d.get("famille", "acier"))).nom)]
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.clip_text = true
		l.add_theme_font_size_override("font_size", 12)
		h.add_child(l)
		var dd := d
		h.add_child(_bouton("Poser", "construire", func() -> void:
			attractions.nouveau(String(dd.famille), dd)
			refresh()))
		var iid := String(id)
		h.add_child(_bouton("", "demolir", func() -> void:
			AttractionsPerso.biblio_retire(iid)
			refresh(), "Retirer de Mes attractions"))
