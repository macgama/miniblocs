class_name ZooPanel
extends CanvasLayer
## Menu « Zoo » (Maj+Z, menu Loisirs de la barre du bas) : tout pour créer et
## gérer un zoo, onglet par onglet.
## - Zoo : note, visiteurs, prix, comptes, personnel, conseils, ce que disent les visiteurs ;
## - Enclos : tracer, barrières, liste des enclos et fiche de l'enclos choisi
##   (contenu, animaux, besoins de chaque espèce, problèmes) ;
## - Terrain : sols des habitats, bassins, relief, arbres ;
## - Animaux : le catalogue des espèces et leurs besoins ;
## - Bâtiments : abris, soigneurs, cuisine, clinique, atelier ;
## - Visiteurs : entrée, chemins, belvédères, kiosque, restaurants, boutiques ;
## - Objets : jouets et objets d'enclos, panneaux, longues-vues ;
## - Échanges : réseau d'élevage (offres et demandes), échanges avec les autres zoos
##   de la carte (autres joueurs), arrivées à placer (expéditions), remises en liberté.

signal building_chosen(id: String)
## Outil de la barre du bas à prendre (TerreHud.TOOLS), pour les chemins.
signal hud_tool_requested(tool: int)
signal decors_requested
signal focus_requested(pos: Vector3)
signal opened(on: bool)

const W := 400.0
const H := 600.0
const ONGLETS := [["zoo", "Zoo", "zoo"], ["enclos", "Enclos", "enclos"], ["terrain", "Terrain", "paysage"],
	["animaux", "Animaux", "agriculture"], ["batiments", "Bâtiments", "construire"], ["visiteurs", "Visiteurs", "habitants"],
	["objets", "Objets", "decors"], ["echanges", "Échanges", "partage"]]

var zoo: ZooSysteme
var outils: ZooOutils
var view := "zoo"
var choisi := -1
var enclos_vu := -1
var continent := ""
## Animal à proposer à un autre zoo (onglet Échanges).
var echange_animal := -1
var _panel: PanelContainer
var _title: Label
var _body: VBoxContainer
var _scroll: ScrollContainer
var _onglets := {}
var _tick := 0.0
var _vignettes: Vignettes


func setup(z: ZooSysteme, o: ZooOutils) -> void:
	zoo = z
	outils = o
	_build()
	outils.enclos_choisi.connect(func(id: int) -> void:
		enclos_vu = id
		if view != "enclos" and outils.outil == ZooOutils.Outil.CHOISIR:
			show_view("enclos")
		elif view == "enclos":
			refresh())


func _build() -> void:
	layer = 6
	_vignettes = Vignettes.new()
	_vignettes.name = "Vignettes"
	add_child(_vignettes)
	_panel = PanelContainer.new()
	_panel.offset_left = 10
	_panel.offset_top = UiStyle.SIDE_TOP
	_panel.custom_minimum_size = Vector2(W, 0)
	UiStyle.style_panel(_panel)
	_panel.visible = false
	add_child(_panel)
	var outer := VBoxContainer.new()
	_panel.add_child(outer)
	var head := HBoxContainer.new()
	outer.add_child(head)
	var icon := TextureRect.new()
	icon.texture = Icones.get_icon("zoo", 22, UiStyle.ACCENT)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	head.add_child(icon)
	_title = Label.new()
	_title.text = "Zoo"
	_title.add_theme_font_size_override("font_size", 16)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	var x := UiStyle.icon_button("fermer", "Fermer", "Maj+Z", 18, 32)
	x.pressed.connect(func() -> void: set_open(false))
	head.add_child(x)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 2)
	outer.add_child(tabs)
	for o in ONGLETS:
		var b := Button.new()
		b.icon = Icones.get_icon(String(o[2]), 20)
		b.tooltip_text = String(o[1])
		b.text = String(o[1]) if String(o[0]) in ["zoo", "enclos", "animaux"] else ""
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 12)
		var v := String(o[0])
		b.pressed.connect(func() -> void: show_view(v))
		tabs.add_child(b)
		_onglets[v] = b
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
	elif outils != null:
		outils.set_inactive()
	opened.emit(on)


func toggle() -> void:
	set_open(not _panel.visible)


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.keycode == KEY_Z and k.shift_pressed and not k.ctrl_pressed and not k.alt_pressed:
		toggle()
		get_viewport().set_input_as_handled()


func show_view(v: String) -> void:
	view = v
	for k in _onglets:
		(_onglets[k] as Button).set_pressed_no_signal(k == v)
	if outils != null:
		match v:
			"enclos":
				if outils.outil == ZooOutils.Outil.AUCUN or not (outils.outil in [ZooOutils.Outil.ENCLOS, ZooOutils.Outil.BARRIERE, ZooOutils.Outil.SUPPRIMER]):
					outils.set_outil(ZooOutils.Outil.CHOISIR)
			"zoo", "batiments", "visiteurs":
				outils.set_inactive()
	refresh()
	_scroll.scroll_vertical = 0


func _process(delta: float) -> void:
	if not is_open():
		return
	_tick += delta
	if _tick >= 1.5:
		_tick = 0.0
		if view in ["terrain", "animaux", "batiments", "visiteurs", "objets", "echanges"]:
			return
		var f := get_viewport().gui_get_focus_owner()
		if f != null and _body.is_ancestor_of(f):
			return
		var keep := _scroll.scroll_vertical
		refresh()
		_scroll.set_deferred("scroll_vertical", keep)


func _zoo_courant() -> int:
	if zoo == null or zoo.zoos.is_empty():
		return -1
	if not zoo.zoos.has(choisi):
		choisi = int(zoo.zoos.keys()[0])
	return choisi


func refresh() -> void:
	if zoo == null:
		return
	for c in _body.get_children():
		c.queue_free()
	_vignettes.cancel_all()
	var e := _zoo_courant()
	_title.text = String(zoo.zoos[e].nom) if e >= 0 else "Zoo"
	for k in _onglets:
		(_onglets[k] as Button).set_pressed_no_signal(k == view)
	match view:
		"zoo": _vue_zoo(e)
		"enclos": _vue_enclos()
		"terrain": _vue_terrain()
		"animaux": _vue_animaux()
		"batiments": _vue_batiments(["abri", "soigneurs", "cuisine", "clinique", "atelier"])
		"visiteurs": _vue_visiteurs()
		"objets": _vue_objets()
		"echanges": _vue_echanges(e)


# --- Petits éléments ---------------------------------------------------------------------------------

func _titre(t: String) -> void:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", UiStyle.ACCENT)
	_body.add_child(l)


func _texte(t: String, dim := false, size := 13) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(W - 30, 0)
	l.add_theme_font_size_override("font_size", size)
	if dim:
		l.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	_body.add_child(l)
	return l


func _ligne(gauche: String, droite: String, col := Color.TRANSPARENT) -> void:
	var h := HBoxContainer.new()
	var a := Label.new()
	a.text = gauche
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	a.add_theme_font_size_override("font_size", 13)
	h.add_child(a)
	var b := Label.new()
	b.text = droite
	b.add_theme_font_size_override("font_size", 13)
	if col != Color.TRANSPARENT:
		b.add_theme_color_override("font_color", col)
	h.add_child(b)
	_body.add_child(h)


## Barre de 0 à 1 (besoins, bien-être).
func _barre(nom: String, v: float, parent: Control = null) -> void:
	_barre_val(nom, v, "%d %%" % roundi(v * 100.0), parent)


## Barre avec un texte au bout (« 87 % »).
func _barre_val(nom: String, v: float, texte: String, parent: Control = null) -> HBoxContainer:
	var h := HBoxContainer.new()
	var a := Label.new()
	a.text = nom
	a.custom_minimum_size = Vector2(118, 0)
	a.add_theme_font_size_override("font_size", 12)
	h.add_child(a)
	var pb := ProgressBar.new()
	pb.min_value = 0
	pb.max_value = 100
	pb.value = clampf(v, 0.0, 1.0) * 100.0
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(170, 12)
	pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb := StyleBoxFlat.new()
	sb.bg_color = _couleur(v)
	sb.set_corner_radius_all(3)
	pb.add_theme_stylebox_override("fill", sb)
	h.add_child(pb)
	var c := Label.new()
	c.text = texte
	c.add_theme_font_size_override("font_size", 12)
	h.add_child(c)
	(parent if parent != null else _body).add_child(h)
	return h


static func _couleur(v: float) -> Color:
	if v >= 0.75:
		return Color("6ac46a")
	if v >= 0.5:
		return Color("e8c032")
	return Color("e05a3a")


func _bouton(t: String, icon: String, f: Callable, tip := "") -> Button:
	var b := Button.new()
	b.text = t
	if icon != "":
		b.icon = Icones.get_icon(icon, 18)
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(f)
	_body.add_child(b)
	return b


func _outil_bouton(t: String, icon: String, o: ZooOutils.Outil, tip := "") -> Button:
	var b := _bouton(t, icon, func() -> void:
		outils.set_outil(o)
		refresh(), tip)
	b.toggle_mode = true
	b.set_pressed_no_signal(outils.outil == o)
	return b


func _rangee() -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	_body.add_child(h)
	return h


func _sep() -> void:
	var s := HSeparator.new()
	_body.add_child(s)


# --- Onglet Zoo ----------------------------------------------------------------------------------------

func _vue_zoo(e: int) -> void:
	if e < 0:
		_titre("Fonder un zoo")
		_texte("Un zoo commence par son entrée, posée au bord d'une route. Les enclos et les bâtiments à moins de 400 m en font partie.")
		_bouton("Poser l'entrée du zoo (%s)" % ZooSysteme._euros(float(BuildingCatalog.cost("entree_zoo"))), "construire",
			func() -> void: building_chosen.emit("entree_zoo"))
		_sep()
		_texte("Ensuite :", true)
		for t in ["1. Onglet Enclos : tracer un enclos (clic à chaque coin, ou glisser pour un rectangle) et choisir sa barrière.",
				"2. Onglet Terrain : peindre les sols (herbe, sable, rocher, neige…), creuser un bassin, planter des arbres.",
				"3. Onglet Animaux : choisir une espèce et cliquer dans l'enclos. La fiche dit ce qu'il lui faut.",
				"4. Onglet Bâtiments : un abri dans l'enclos, un poste des soigneurs pas loin.",
				"5. Onglet Visiteurs : restaurants, toilettes, belvédères. Puis on ouvre !"]:
			_texte(t, true, 12)
		return
	var z: Dictionary = zoo.zoos[e]
	if zoo.zoos.size() > 1:
		var ob := ChoixVisuel.new()
		ob.icone = "zoo"
		ob.gradue = 0
		var i := 0
		for k in zoo.zoos:
			ob.add_item(String(zoo.zoos[k].nom))
			ob.set_item_metadata(i, int(k))
			if int(k) == e:
				ob.select(i)
			i += 1
		ob.item_selected.connect(func(j: int) -> void:
			choisi = int(ob.get_item_metadata(j))
			refresh())
		_body.add_child(ob)
	var nom := LineEdit.new()
	nom.text = String(z.nom)
	nom.text_submitted.connect(func(t: String) -> void:
		_faire("set_nom", [e, t], zoo._center(e))
		refresh())
	_body.add_child(nom)
	var note := float(z.note)
	_ligne("Note", "%s  %.1f / 5" % [ParcLoisirs.etoiles(note), note], UiStyle.ACCENT)
	var d := zoo.detail_note(e)
	for k in [["variete", "Variété des espèces"], ["bien", "Bien-être des animaux"], ["vue", "Vue sur les enclos"],
			["services", "Restaurants et toilettes"], ["prix", "Prix de l'entrée"], ["conservation", "Conservation"]]:
		_barre(String(k[1]), float(d[k[0]]))
	_sep()
	var now := zoo._now(zoo.clock if zoo.clock > 0.0 else (zoo.ambiance.unix_time if zoo.ambiance else 0.0))
	var hr := ZooSysteme.horaires(int(now.month))
	_ligne("Ouvert", "%d h – %d h%s" % [int(hr.x), int(hr.y), "" if zoo.est_ouvert(e, now) else " (fermé)"])
	_ligne("Visiteurs en ce moment", str(roundi(float(z.presents))))
	_ligne("Visiteurs hier", "%d (%d touristes)" % [int(z.hier.visiteurs), int(z.hier.touristes)])
	_ligne("Animaux", "%d dans %d enclos" % [zoo.animaux_du_zoo(e).size(), zoo.enclos_du_zoo(e).size()])
	if not zoo.relie(e):
		_texte("L'entrée n'est pas reliée à une route : presque aucun touriste ne trouve le zoo.", false).add_theme_color_override("font_color", Color("ff9a7a"))
	var prix := HBoxContainer.new()
	var pl := Label.new()
	pl.text = "Prix de l'entrée (€)"
	pl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prix.add_child(pl)
	var sp := SpinBox.new()
	sp.min_value = 0
	sp.max_value = 120
	sp.step = 1
	sp.value = float(z.prix)
	sp.value_changed.connect(func(v: float) -> void: _faire("set_prix", [e, v], zoo._center(e)))
	prix.add_child(sp)
	_body.add_child(prix)
	_texte("Les visiteurs estiment le zoo à %s." % ZooSysteme._euros(zoo.valeur(e)), true, 12)
	_sep()
	_titre("Comptes d'hier")
	var h: Dictionary = z.hier
	_ligne("Billets", ZooSysteme._euros(float(h.billets)), Color("9fe3b0"))
	_ligne("Restauration et boutiques", ZooSysteme._euros(float(h.stands)), Color("9fe3b0"))
	_ligne("Dons pour la conservation", ZooSysteme._euros(float(h.dons)), Color("9fe3b0"))
	_ligne("Nourriture des animaux", "− " + ZooSysteme._euros(float(h.nourriture)), Color("ff9a7a"))
	_ligne("Dépenses (salaires, entretien, nourriture)", "− " + ZooSysteme._euros(float(h.depenses)), Color("ff9a7a"))
	_ligne("Naissances / morts / évasions", "%d / %d / %d" % [int(h.naissances), int(h.morts), int(h.evasions)])
	_ligne("Prestige", str(roundi(float(z.prestige))))
	_sep()
	_titre("Personnel")
	_ligne("Soigneurs", "%.0f (pour %d places d'animaux)" % [zoo.soigneurs(e), roundi(zoo.soigneurs(e) * ZooSysteme.PLACES_SOIGNEUR)])
	_ligne("Vétérinaires", "%.0f" % zoo.equipe(e, "clinique", "veterinaire_zoo"))
	_ligne("Techniciens (barrières)", "%.0f" % zoo.equipe(e, "atelier", "technicien_zoo"))
	_sep()
	_titre("Conseils")
	for c in conseils(e):
		_texte("• " + String(c), false, 12)
	if not (z.dernieres as Array).is_empty():
		_sep()
		_titre("Ce que disent les visiteurs")
		for t in z.dernieres:
			_texte("« %s »" % String(t), true, 12)


func conseils(e: int) -> Array:
	var out: Array = []
	if zoo.enclos_du_zoo(e).is_empty():
		out.append("Tracez un premier enclos (onglet Enclos).")
	if zoo.animaux_du_zoo(e).is_empty():
		out.append("Pas d'animaux : le zoo reste fermé.")
	var places := 0.0
	for aid in zoo.animaux_du_zoo(e):
		places += float(ZooEspeces.espece(String(zoo.animaux[aid].esp)).get("taille", 1))
	if places > zoo.soigneurs(e) * ZooSysteme.PLACES_SOIGNEUR:
		out.append("Pas assez de soigneurs : les animaux ont faim et les enclos sont sales (poste des soigneurs, onglet Bâtiments).")
	if zoo.items_of(e, "clinique").is_empty() and places > 20.0:
		out.append("Une clinique vétérinaire soignerait vite les malades.")
	if zoo.items_of(e, "atelier").is_empty() and not zoo.enclos_du_zoo(e).is_empty():
		out.append("Sans atelier, les barrières s'usent : gare aux évasions.")
	if zoo.items_of(e, "stand").is_empty():
		out.append("Un restaurant ou une buvette (onglet Visiteurs).")
	if zoo.items_of(e, "toilettes").is_empty():
		out.append("Des toilettes, sinon les familles rentrent tôt.")
	for id in zoo.enclos_du_zoo(e):
		var pb := 0
		for s in zoo.especes_de(int(id)):
			var b := zoo.besoins(String(s), int(id))
			pb += (b.problemes as Array).size()
		if pb > 0:
			out.append("« %s » : %d problème%s (voir l'onglet Enclos)." % [String(zoo.enclos[id].nom), pb, "s" if pb > 1 else ""])
		if zoo.vue(int(id)) < 0.3:
			out.append("« %s » : on ne voit rien à travers le mur. Ajoutez un belvédère ou des vitres." % String(zoo.enclos[id].nom))
		for c in zoo.couples_a_risque(int(id)):
			out.append("« %s » : %s et %s sont proches parents (%s). Contraception, ou un partenaire venu d'ailleurs (onglet Échanges)." % [
				String(zoo.enclos[id].nom), String(zoo.animaux[c[0]].nom), String(zoo.animaux[c[1]].nom), _lien(float(c[2]))])
			break
	if not zoo.arrivees_de(e).is_empty():
		out.append("%d animal%s attend%s un enclos (onglet Échanges)." % [zoo.arrivees_de(e).size(),
			"aux" if zoo.arrivees_de(e).size() > 1 else "", "ent" if zoo.arrivees_de(e).size() > 1 else ""])
	if out.is_empty():
		out.append("Tout va bien. Une espèce menacée de plus ferait venir du monde.")
	return out


# --- Onglet Enclos -------------------------------------------------------------------------------------

func _vue_enclos() -> void:
	_titre("Enclos")
	var r := _rangee()
	for spec in [["Choisir", "observer", ZooOutils.Outil.CHOISIR], ["Tracer", "enclos", ZooOutils.Outil.ENCLOS],
			["Barrière", "mur", ZooOutils.Outil.BARRIERE], ["Démolir", "demolir", ZooOutils.Outil.SUPPRIMER]]:
		var b := Button.new()
		b.text = String(spec[0])
		b.icon = Icones.get_icon(String(spec[1]), 18)
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var o: ZooOutils.Outil = spec[2]
		b.set_pressed_no_signal(outils.outil == o)
		b.pressed.connect(func() -> void:
			outils.set_outil(o)
			refresh())
		r.add_child(b)
	if outils.outil in [ZooOutils.Outil.ENCLOS, ZooOutils.Outil.BARRIERE]:
		_texte("Barrière :", true)
		var g := ButtonGroup.new()
		for bid in ZooEspeces.BARRIERES_ORDRE:
			var s: Dictionary = ZooEspeces.BARRIERES[bid]
			var b := Button.new()
			b.toggle_mode = true
			b.button_group = g
			b.focus_mode = Control.FOCUS_NONE
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.text = "%s   niv. %d · %s/m · vue %d %%" % [String(s.nom), int(s.niveau), ZooSysteme._euros(float(s.prix_m)), roundi(float(s.vue) * 100.0)]
			b.tooltip_text = String(s.desc)
			b.add_theme_font_size_override("font_size", 12)
			b.set_pressed_no_signal(outils.barriere == bid)
			var id := String(bid)
			b.pressed.connect(func() -> void:
				outils.barriere = id
				outils._maj_aide())
			_body.add_child(b)
	_sep()
	if zoo.enclos.is_empty():
		_texte("Aucun enclos. « Tracer » : clic à chaque coin puis clic sur le premier point (ou Entrée) ; glisser pour un rectangle.", true)
		return
	if not zoo.enclos.has(enclos_vu):
		enclos_vu = int(zoo.enclos.keys()[0])
	var ob := ChoixVisuel.new()
	ob.icone = "enclos"
	ob.gradue = 0
	var i := 0
	for id in zoo.enclos:
		var n := zoo.animaux_de(int(id)).size()
		ob.add_item("%s  (%d animaux, %d %%)" % [String(zoo.enclos[id].nom), n, roundi(zoo.bien_moyen(zoo.animaux_de(int(id))))])
		ob.set_item_metadata(i, int(id))
		if int(id) == enclos_vu:
			ob.select(i)
		i += 1
	ob.item_selected.connect(func(j: int) -> void:
		enclos_vu = int(ob.get_item_metadata(j))
		var c := zoo._centre_enclos(enclos_vu)
		focus_requested.emit(Vector3(c.x, 0, c.y))
		refresh())
	_body.add_child(ob)
	_fiche_enclos(enclos_vu)


func _fiche_enclos(id: int) -> void:
	var en: Dictionary = zoo.enclos[id]
	var nom := LineEdit.new()
	nom.text = String(en.nom)
	nom.text_submitted.connect(func(t: String) -> void:
		_faire("renommer_enclos", [id, t], zoo._centre_enclos(id))
		refresh())
	_body.add_child(nom)
	var c := zoo.contenu(id)
	_ligne("Surface", "%d m²" % roundi(float(c.aire)))
	_ligne("Barrière", "%s (%d %%)" % [String(ZooEspeces.barriere(String(en.barriere)).nom), roundi(float(en.etat))],
		_couleur(float(en.etat) / 100.0))
	_ligne("Propreté", "%d %%" % roundi(float(en.propre)), _couleur(float(en.propre) / 100.0))
	_ligne("Abris", "%d places%s%s" % [int(c.abri), " · chauffé" if bool(c.chaud) else "", " · réfrigéré" if bool(c.froid) else ""])
	_ligne("Jouets et arbres", "%d objets, %d arbres" % [int(c.jouets), int(float(c.arbres))])
	# Sols de l'enclos.
	var sols: Dictionary = c.sols
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 0)
	bar.custom_minimum_size = Vector2(W - 30, 14)
	var detail: Array = []
	for s in ZooEspeces.SOLS_ORDRE:
		var p := float(sols.get(s, 0.0))
		if p <= 0.005:
			continue
		var cr := ColorRect.new()
		cr.color = ZooEspeces.SOLS[s].couleur
		cr.custom_minimum_size = Vector2(maxf(2.0, (W - 30) * p), 14)
		cr.tooltip_text = "%s : %d %%" % [String(ZooEspeces.SOLS[s].nom), roundi(p * 100.0)]
		bar.add_child(cr)
		detail.append("%s %d %%" % [ZooEspeces.minuscule(String(ZooEspeces.SOLS[s].nom)), roundi(p * 100.0)])
	_body.add_child(bar)
	_texte(", ".join(detail), true, 11)
	var esps := zoo.especes_de(id)
	_sep()
	if esps.is_empty():
		_texte("Aucun animal. Onglet Animaux : choisir une espèce, puis clic dans l'enclos.", true)
		return
	for s in esps:
		var e := ZooEspeces.espece(String(s))
		_titre("%s × %d" % [String(e.nom), int(esps[s])])
		var b := zoo.besoins(String(s), id)
		var ids: Array = []
		var faim := 0.0
		for aid in zoo.animaux_de(id):
			if String(zoo.animaux[aid].esp) == String(s):
				ids.append(aid)
				faim += float(zoo.animaux[aid].faim)
		faim /= maxf(1.0, float(ids.size()))
		_barre("Bien-être", zoo.bien_moyen(ids) / 100.0)
		var zz := int(en.zoo)
		if zoo.zoos.has(zz) and zoo.groupe_espece(zz, String(s)).size() >= 2:
			var dv := zoo.diversite(zz, String(s))
			var bdv := _barre_val("Diversité génétique", clampf((dv - 0.5) * 2.0, 0.0, 1.0), ZooGenetique.pourcent(dv))
			bdv.tooltip_text = "Groupe de l'espèce dans tout le zoo. Plus les animaux sont parents, plus elle baisse :\nles petits naissent fragiles. Des animaux d'autres zoos la font remonter."
		for k in ZooSysteme.POIDS:
			var v := 1.0 - faim / 100.0 if k == "faim" else float(b.get(k, 1.0))
			_barre(String(ZooSysteme.BESOINS_NOMS[k]), v)
		for p in b.problemes:
			var l := _texte("⚠ " + String(p), false, 12)
			l.add_theme_color_override("font_color", Color("ffb38a"))
		for aid in ids:
			_ligne_animal(int(aid))


func _ligne_animal(aid: int) -> void:
	var a: Dictionary = zoo.animaux[aid]
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	var l := Label.new()
	var age := zoo.age_ans(a)
	var etat := ""
	if bool(a.evade):
		etat = " · ÉVADÉ"
	elif bool(a.malade):
		etat = " · malade"
	elif float(a.gest) >= 0.0:
		etat = " · attend un petit"
	if String(a.get("tare", "")) != "":
		etat += " · tare"
	l.text = "%s %s, %s · santé %d · %d %%%s" % [String(a.nom), "♀" if bool(a.f) else "♂",
		("%d an%s" % [int(age), "s" if age >= 2.0 else ""]) if age >= 1.0 else "%d mois" % int(age * 12.0), roundi(float(a.sante)), roundi(float(a.bien)), etat]
	l.add_theme_font_size_override("font_size", 12)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.clip_text = true
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	l.tooltip_text = fiche_genetique(aid)
	col.add_child(l)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 2)
	var g := Label.new()
	g.text = "gènes : %s" % _resume_genes(a)
	g.add_theme_font_size_override("font_size", 10)
	g.modulate = Color(1, 1, 1, 0.65)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.clip_text = true
	g.mouse_filter = Control.MOUSE_FILTER_PASS
	g.tooltip_text = l.tooltip_text
	h.add_child(g)
	h.add_child(_petit_bouton("Vendre", "Vendre à un autre zoo (moitié du prix)", func() -> void:
		_faire("vendre", [aid], _point_animal(aid))
		refresh()))
	h.add_child(_petit_bouton("Échanger", "Proposer à un autre zoo de la carte (onglet Échanges)", func() -> void:
		echange_animal = aid
		show_view("echanges")))
	var c := _petit_bouton("Contra.", "Contraception : pas de petits (évite la consanguinité sans séparer le groupe)", func() -> void:
		_faire("set_contraception", [aid, not bool(zoo.animaux[aid].get("contra", false))], _point_animal(aid))
		refresh())
	c.toggle_mode = true
	c.set_pressed_no_signal(bool(a.get("contra", false)))
	h.add_child(c)
	if ZooEspeces.uicn_bonus(String(a.esp)) > 0.0:
		var raison := zoo.raison_pas_relacher(aid)
		var r := _petit_bouton("Relâcher", ("Rendre à la nature : prestige du zoo. Chance de s'adapter : %d %%" % roundi(zoo.chance_relache(aid) * 100.0))
			if raison == "" else raison, func() -> void:
				_faire("relacher", [aid], _point_animal(aid))
				refresh())
		r.disabled = raison != ""
		h.add_child(r)
	col.add_child(h)
	_body.add_child(col)


func _petit_bouton(t: String, tip: String, f: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.tooltip_text = tip
	b.add_theme_font_size_override("font_size", 11)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(f)
	return b


## « T+ S= F- L+ » : les quatre gènes d'un coup d'œil.
static func _resume_genes(a: Dictionary) -> String:
	var parts: Array = []
	for k in ZooGenetique.GENES:
		var v := ZooGenetique.effectif(a, String(k))
		parts.append("%s %s" % [String(ZooGenetique.NOMS[k]).substr(0, 4).to_lower(), "+" if v >= 0.15 else ("−" if v <= -0.15 else "=")])
	var t := ", ".join(parts)
	var f := float(a.get("consang", 0.0))
	if f > 0.0:
		t += " · consanguinité %s" % ZooGenetique.pourcent(f)
	return t


static func _lien(k: float) -> String:
	if k >= 0.25:
		return "parent et petit, ou frère et sœur"
	if k >= 0.125:
		return "demi-frère et demi-sœur, ou grand-parent"
	if k >= 0.0625:
		return "cousins"
	return "parenté lointaine"


## Fiche génétique d'un animal (infobulle).
func fiche_genetique(aid: int) -> String:
	var a: Dictionary = zoo.animaux[aid]
	var lignes: Array = []
	for k in ZooGenetique.GENES:
		var v := ZooGenetique.effectif(a, String(k))
		lignes.append("%s : %s (%+.2f)" % [String(ZooGenetique.NOMS[k]), ZooGenetique.qualite(v), v])
	var pere := int(a.get("pere", -1))
	var mere := int(a.get("mere", -1))
	var parents := "lignée inconnue (fondateur)"
	if pere >= 0 or mere >= 0:
		parents = "%s et %s" % [_nom_ancetre(pere), _nom_ancetre(mere)]
	lignes.append("Parents : " + parents)
	lignes.append("Origine : " + String({"elevage": "élevage", "reseau": "réseau d'élevage", "sauvage": "nature", "expedition": "expédition",
		"sauvetage": "sauvetage"}.get(String(a.get("origine", "elevage")), String(a.get("origine", "")))))
	lignes.append("Consanguinité : %s" % ZooGenetique.pourcent(float(a.get("consang", 0.0))))
	if String(a.get("tare", "")) != "":
		lignes.append("Tare héréditaire : " + String(a.tare))
	lignes.append("Valeur pour l'élevage : %s" % ("précieux (lignée rare)" if zoo.valeur_genetique(aid) >= 1.15 else
		("courante" if zoo.valeur_genetique(aid) >= 0.85 else "faible (lignée très représentée)")))
	return "\n".join(lignes)


func _nom_ancetre(id: int) -> String:
	if zoo.animaux.has(id):
		return String(zoo.animaux[id].nom)
	var g: Dictionary = zoo.genealogie.get(id, {})
	return String(g.get("nom", "")) if String(g.get("nom", "")) != "" else "inconnu"


# --- Onglet Terrain ------------------------------------------------------------------------------------

func _vue_terrain() -> void:
	_titre("Sols des habitats")
	_texte("Chaque espèce aime un mélange de sols : la fiche de l'espèce et celle de l'enclos le disent.", true, 12)
	var g := GridContainer.new()
	g.columns = 2
	_body.add_child(g)
	for s in ZooEspeces.SOLS_ORDRE:
		var b := Button.new()
		b.text = String(ZooEspeces.SOLS[s].nom)
		var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		img.fill(ZooEspeces.SOLS[s].couleur)
		b.icon = ImageTexture.create_from_image(img)
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.set_pressed_no_signal(outils.outil == ZooOutils.Outil.SOL and outils.sol == s)
		var sid := String(s)
		b.pressed.connect(func() -> void:
			outils.sol = sid
			outils.set_outil(ZooOutils.Outil.SOL)
			refresh())
		g.add_child(b)
	_sep()
	_titre("Eau, relief et arbres")
	_outil_bouton("Creuser un bassin", "bassin", ZooOutils.Outil.EAU, "Plan d'eau pour les hippopotames, manchots, otaries…")
	_outil_bouton("Combler l'eau", "aplanir", ZooOutils.Outil.REMBLAI)
	_outil_bouton("Butte (Maj : aplanir)", "monter", ZooOutils.Outil.RELIEF, "Relief pour les ours, les chèvres, les points de vue")
	_outil_bouton("Planter des arbres", "agriculture", ZooOutils.Outil.ARBRES, "Ombre et enrichissement")
	_outil_bouton("Arracher les arbres", "demolir", ZooOutils.Outil.ARRACHER)
	var r := HBoxContainer.new()
	var l := Label.new()
	l.text = "Rayon : %d m" % outils.rayon
	l.custom_minimum_size = Vector2(110, 0)
	r.add_child(l)
	var s := HSlider.new()
	s.min_value = 1
	s.max_value = 12
	s.step = 1
	s.value = outils.rayon
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.value_changed.connect(func(v: float) -> void:
		outils.rayon = int(v)
		l.text = "Rayon : %d m" % int(v)
		outils._maj_aide())
	r.add_child(s)
	_body.add_child(r)


# --- Onglet Animaux -------------------------------------------------------------------------------------

func _vue_animaux() -> void:
	_titre("Marché aux animaux")
	var ob := ChoixVisuel.new()
	ob.icone = "globe"
	ob.modele_meta = "continent"
	ob.max_columns = 4
	ob.add_item("Tous les continents")
	ob.set_item_metadata(0, "")
	var i := 1
	for c in ZooEspeces.CONTINENTS:
		ob.add_item(String(ZooEspeces.CONTINENTS[c]))
		ob.set_item_metadata(i, String(c))
		if String(c) == continent:
			ob.select(i)
		i += 1
	ob.item_selected.connect(func(j: int) -> void:
		continent = String(ob.get_item_metadata(j))
		refresh())
	_body.add_child(ob)
	_texte("Clic sur une espèce, puis clic dans un enclos (Maj+clic : un groupe).", true, 12)
	for id in ZooEspeces.ORDRE:
		var e: Dictionary = ZooEspeces.ESPECES[id]
		if continent != "" and String(e.cont) != continent:
			continue
		var b := Button.new()
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.set_pressed_no_signal(outils.outil == ZooOutils.Outil.ANIMAL and outils.espece == id)
		var g: Array = e.groupe
		var sols: Array = []
		for s in e.sols:
			if float(e.sols[s]) >= 0.2:
				sols.append(ZooEspeces.minuscule(String(ZooEspeces.SOLS[s].nom)))
		b.text = "%s — %s\n%s · %d à %d · %d m²/animal · barrière niv. %d, %.1f m%s" % [String(e.nom), ZooSysteme._euros(float(e.prix)),
			String(ZooEspeces.UICN[String(e.uicn)].nom), int(g[0]), int(g[1]), int(e.m2), int(e.niveau), float(e.h),
			" · nage" if bool(e.get("nage", false)) else ""]
		b.tooltip_text = "%s\n\nSols : %s\nEau : %d %%\nClimat : %d à %d °C%s\nNourriture : %s, %.1f kg par jour\nVie : %d ans" % [
			String(e.desc), ", ".join(sols), roundi(float(e.eau) * 100.0), int(e.climat[0]), int(e.climat[1]),
			"\nA besoin d'un abri" if bool(e.get("abri", false)) else "", String(ZooEspeces.REGIMES[String(e.regime)].nom).to_lower(),
			float(e.kg), int(e.vie)]
		b.add_theme_font_size_override("font_size", 12)
		var sid := String(id)
		b.pressed.connect(func() -> void:
			outils.espece = sid
			outils.set_outil(ZooOutils.Outil.ANIMAL)
			refresh())
		_body.add_child(b)
		var did := String(e.decors[0])
		_vignettes.request_mesh("zoo_" + did, func() -> Mesh: return mesh_colore(did), b, 56)


## Maillage d'un décor avec son matériau (palette), pour les vignettes.
static func mesh_colore(did: String) -> Mesh:
	var m := Decors.mesh(did)
	if m == null:
		return null
	var c := m.duplicate() as Mesh
	for i in c.get_surface_count():
		c.surface_set_material(i, Decors.materiau())
	return c


# --- Onglets Bâtiments et Visiteurs ----------------------------------------------------------------------

func _vue_batiments(roles: Array) -> void:
	var titres := {"abri": "Abris (à poser dans l'enclos)", "soigneurs": "Soins des animaux", "cuisine": "", "clinique": "",
		"atelier": "", "entree": "Entrée", "vue": "Points de vue", "pedago": "Conservation", "stand": "Restaurants et boutiques",
		"toilettes": "Services", "repos": ""}
	for role in roles:
		if String(titres.get(role, "")) != "":
			_titre(String(titres[role]))
		for id in ZooTypes.of_role(String(role)):
			var t: Dictionary = BuildingCatalog.get_type(String(id))
			var b := _bouton("%s — %s" % [String(t.name), ZooSysteme._euros(float(BuildingCatalog.cost(String(id))))], "construire",
				func() -> void: building_chosen.emit(String(id)), String(t.get("desc", "")))
			b.add_theme_font_size_override("font_size", 12)


func _vue_visiteurs() -> void:
	_vue_batiments(["entree"])
	_titre("Allées")
	_bouton("Tracer un chemin piéton", "chemin", func() -> void: hud_tool_requested.emit(6),
		"Les visiteurs longent les enclos depuis l'entrée ; les chemins rendent la visite plus belle.")
	_vue_batiments(["vue", "pedago", "stand", "toilettes", "repos"])
	_sep()
	_titre("Objets pour les visiteurs")
	for id in ["panneau_espece", "longue_vue", "banc_bois", "poubelle", "table_pique_nique", "fontaine_boire"]:
		if Decors.existe(id):
			_objet_bouton(id)


# --- Onglet Objets ---------------------------------------------------------------------------------------

func _vue_objets() -> void:
	_titre("Objets des enclos")
	_texte("Jouets et abris légers : ils comptent pour l'enrichissement de l'enclos où ils sont posés. R : tourner.", true, 12)
	for e: Dictionary in Decors.de_categorie("zoo_objets"):
		_objet_bouton(String(e.id))
	_sep()
	_titre("Rochers et bois")
	for e: Dictionary in Decors.de_categorie("rochers"):
		_objet_bouton(String(e.id))
	_sep()
	_bouton("Tous les décors (G)…", "decors", func() -> void: decors_requested.emit())


func _objet_bouton(id: String) -> void:
	var b := Button.new()
	b.text = Decors.nom(id)
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 12)
	b.set_pressed_no_signal(outils.outil == ZooOutils.Outil.OBJET and outils.objet == id)
	b.pressed.connect(func() -> void:
		outils.objet = id
		outils.set_outil(ZooOutils.Outil.OBJET)
		refresh())
	_body.add_child(b)


## Carte entre amis : la décision part au serveur (le maire de la ville du zoo décide) ;
## en solo, elle est faite ici.
func _faire(f: String, args: Array, p: Variant) -> void:
	if SystemesGeres.relayer("zoo", f, args, p):
		return
	zoo.callv(f, args)


func _point_animal(aid: int) -> Variant:
	if not zoo.animaux.has(aid) or not zoo.enclos.has(int(zoo.animaux[aid].enclos)):
		return null
	return zoo._centre_enclos(int(zoo.animaux[aid].enclos))


# --- Onglet Échanges ---------------------------------------------------------------------------------------

func _vue_echanges(e: int) -> void:
	if e < 0:
		_titre("Échanges d'animaux")
		_texte("Fondez d'abord un zoo (onglet Zoo).", true)
		return
	if zoo.animaux.has(echange_animal):
		_proposer(e, echange_animal)
		_sep()
	else:
		echange_animal = -1
	var arr := zoo.arrivees_de(e)
	if not arr.is_empty():
		_titre("Arrivées à placer")
		_texte("Expéditions, sauvetages : des animaux sauvages, aux gènes neufs. Choisissez leur enclos.", true, 12)
		for rid in arr:
			var r: Dictionary = zoo.arrivees[rid]
			var an: Dictionary = r.animal
			_texte("%s %s, %s · %s" % [String(an.nom), "♀" if bool(an.f) else "♂", ZooEspeces.nom(String(r.esp)),
				{"expedition": "retour d'expédition", "sauvetage": "sauvetage"}.get(String(r.origine), String(r.origine))], false, 12)
			var h := _rangee()
			var ob := _choix_enclos(e, String(r.esp))
			h.add_child(ob)
			var rr := int(rid)
			h.add_child(_petit_bouton("Placer", "Installer dans l'enclos choisi", func() -> void:
				if ob.selected >= 0:
					var id := int(ob.get_item_metadata(ob.selected))
					_faire("placer_arrivee", [rr, id], zoo._centre_enclos(id))
				refresh()))
			h.add_child(_petit_bouton("Céder", "Confier au réseau d'élevage (moitié du prix de l'espèce)", func() -> void:
				_faire("ceder_arrivee", [rr], zoo._center(e))
				refresh()))
		_sep()
	# Propositions des autres zoos de la carte (et les nôtres).
	var recues: Array = []
	var envoyees: Array = []
	var reseau_v: Array = []
	var reseau_d: Array = []
	for oid in zoo.offres_pour(e):
		var o: Dictionary = zoo.offres[oid]
		match String(o.sorte):
			"joueur":
				if int(o.vers) == e:
					recues.append(oid)
				else:
					envoyees.append(oid)
			"vente":
				reseau_v.append(oid)
			"demande":
				reseau_d.append(oid)
	if not recues.is_empty() or not envoyees.is_empty():
		_titre("Propositions des autres zoos")
		for oid in recues:
			var o: Dictionary = zoo.offres[oid]
			var aid := int(o.aid)
			if not zoo.animaux.has(aid):
				continue
			var a: Dictionary = zoo.animaux[aid]
			var t := _texte("%s propose %s %s (%s, %d ans) · %s" % [String(o.partenaire), String(a.nom), "♀" if bool(a.f) else "♂",
				ZooEspeces.nom_bas(String(a.esp)), int(zoo.age_ans(a)), ZooSysteme._euros(float(o.prix)) if float(o.prix) > 0.0 else "don"], false, 12)
			t.tooltip_text = fiche_genetique(aid)
			t.mouse_filter = Control.MOUSE_FILTER_PASS
			_alerte_parente(zoo.parente_offre(int(oid), e))
			_accepter(e, int(oid), String(a.esp), "Accepter")
		for oid in envoyees:
			var o: Dictionary = zoo.offres[oid]
			var nom := String(zoo.animaux[int(o.aid)].nom) if zoo.animaux.has(int(o.aid)) else "?"
			var h := _rangee()
			var l := Label.new()
			l.text = "%s proposé à %s, en attente" % [nom, zoo._nom_zoo(int(o.vers))]
			l.add_theme_font_size_override("font_size", 12)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l.clip_text = true
			h.add_child(l)
			var oo := int(oid)
			h.add_child(_petit_bouton("Retirer", "Retirer la proposition", func() -> void:
				_faire("refuser_offre", [oo], _point_animal(int(o.aid)))
				refresh()))
		_sep()
	_titre("Réseau d'élevage")
	_texte("Les zoos partenaires proposent des animaux de lignées différentes (la diversité génétique remonte) et en demandent : envoyer un animal rare rapporte de l'argent et du prestige.", true, 12)
	if reseau_v.is_empty() and reseau_d.is_empty():
		_texte("Pas d'offre pour le moment : le réseau en publie tous les quelques jours.", true, 12)
	for oid in reseau_v:
		var o: Dictionary = zoo.offres[oid]
		var an: Dictionary = o.animal
		var ans := maxf(0.0, (zoo.jour_courant() - float(an.naiss)) / 365.25)
		var tx := _texte("%s : %s %s, %s, %d ans · %s" % [String(o.partenaire), String(an.nom), "♀" if int(o.f) == 1 else "♂",
			ZooEspeces.nom_bas(String(o.esp)), int(ans), ZooSysteme._euros(float(o.prix))], false, 12)
		var faux := {"genes": an.genes}
		tx.tooltip_text = "Gènes : %s\nPlus que %d jours" % [_resume_genes(faux), maxi(0, int(float(o.expire) - zoo.jour_courant()))]
		tx.mouse_filter = Control.MOUSE_FILTER_PASS
		_alerte_parente(zoo.parente_offre(int(oid), e))
		_accepter(e, int(oid), String(o.esp), "Acheter")
	for oid in reseau_d:
		var o: Dictionary = zoo.offres[oid]
		var sexe := "" if int(o.f) < 0 else (" (femelle)" if int(o.f) == 1 else " (mâle)")
		_texte("%s cherche : %s%s · jusqu'à %s, prestige +%d" % [String(o.partenaire), ZooEspeces.nom_bas(String(o.esp)), sexe,
			ZooSysteme._euros(float(o.prix) * 1.3), roundi(float(o.prestige) * 1.3)], false, 12)
		var h := _rangee()
		var ob := ChoixVisuel.new()
		ob.icone = "zoo"
		ob.gradue = 0
		ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ob.add_theme_font_size_override("font_size", 11)
		var i := 0
		for aid in zoo.groupe_espece(e, String(o.esp)):
			var a: Dictionary = zoo.animaux[aid]
			if int(o.f) >= 0 and bool(a.f) != (int(o.f) == 1):
				continue
			ob.add_item("%s %s, %d ans · valeur %s" % [String(a.nom), "♀" if bool(a.f) else "♂", int(zoo.age_ans(a)),
				ZooSysteme._euros(float(o.prix) * zoo.valeur_genetique(int(aid)))])
			ob.set_item_metadata(i, int(aid))
			i += 1
		h.add_child(ob)
		var oo := int(oid)
		var env := _petit_bouton("Envoyer", "Envoyer l'animal choisi au zoo partenaire", func() -> void:
			if ob.selected >= 0:
				var aid := int(ob.get_item_metadata(ob.selected))
				_faire("repondre_demande", [oo, aid], _point_animal(aid))
			refresh())
		env.disabled = i == 0
		h.add_child(env)
		h.add_child(_petit_bouton("Non", "Ignorer cette demande", func() -> void:
			_faire("refuser_offre", [oo], zoo._center(e))
			refresh()))
	if not zoo.relaches.is_empty():
		_sep()
		_titre("Remises en liberté")
		for r in zoo.relaches:
			var st := String({"suivi": "suivi par collier émetteur", "reussi": "adapté à la vie sauvage", "perdu": "trace perdue"}.get(String(r.statut), ""))
			_ligne("%s (%s)" % [String(r.nom), ZooEspeces.nom_bas(String(r.esp))], st,
				Color("9fe3b0") if String(r.statut) == "reussi" else (Color("ff9a7a") if String(r.statut) == "perdu" else Color.TRANSPARENT))


## Proposer un animal à un autre zoo de la carte.
func _proposer(e: int, aid: int) -> void:
	var a: Dictionary = zoo.animaux[aid]
	_titre("Proposer %s (%s)" % [String(a.nom), ZooEspeces.nom_bas(String(a.esp))])
	var autres := zoo.autres_zoos(zoo.zoo_de_animal(aid))
	if autres.is_empty():
		_texte("Aucun autre zoo sur la carte. Le réseau d'élevage reprend vos animaux quand il en demande (ci-dessous), sinon « Vendre ».", true, 12)
		_bouton("Annuler", "fermer", func() -> void:
			echange_animal = -1
			refresh())
		return
	_texte("Sur une carte entre amis, le maire de l'autre ville accepte ou refuse. Prix 0 : don (prêt pour l'élevage).", true, 12)
	var ob := ChoixVisuel.new()
	ob.icone = "zoo"
	ob.gradue = 0
	for i in autres.size():
		ob.add_item(String(autres[i][1]))
		ob.set_item_metadata(i, int(autres[i][0]))
	_body.add_child(ob)
	var h := _rangee()
	var l := Label.new()
	l.text = "Prix (€)"
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	var sp := SpinBox.new()
	sp.min_value = 0
	sp.max_value = 500000
	sp.step = 100
	sp.value = roundf(float(ZooEspeces.espece(String(a.esp)).get("prix", 0)) * 0.5 / 100.0) * 100.0
	h.add_child(sp)
	var h2 := _rangee()
	h2.add_child(_petit_bouton("Proposer", "Envoyer la proposition", func() -> void:
		var vers := int(ob.get_item_metadata(ob.selected))
		_faire("proposer_echange", [aid, vers, sp.value], _point_animal(aid))
		echange_animal = -1
		refresh()))
	h2.add_child(_petit_bouton("Annuler", "", func() -> void:
		echange_animal = -1
		refresh()))


## Liste des enclos d'un zoo, le meilleur pour l'espèce choisi d'avance.
func _choix_enclos(e: int, esp: String) -> ChoixVisuel:
	var ob := ChoixVisuel.new()
	ob.icone = "enclos"
	ob.gradue = 0
	ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ob.add_theme_font_size_override("font_size", 11)
	var best := zoo._meilleur_enclos(e, esp)
	var i := 0
	for id in zoo.enclos_du_zoo(e):
		ob.add_item(String(zoo.enclos[id].nom))
		ob.set_item_metadata(i, int(id))
		if int(id) == best:
			ob.select(i)
		i += 1
	return ob


func _accepter(e: int, oid: int, esp: String, texte: String) -> void:
	var h := _rangee()
	var ob := _choix_enclos(e, esp)
	h.add_child(ob)
	var b := _petit_bouton(texte, "L'animal arrive dans l'enclos choisi", func() -> void:
		if ob.selected >= 0:
			var id := int(ob.get_item_metadata(ob.selected))
			_faire("acheter_offre", [oid, id], zoo._centre_enclos(id))
		refresh())
	b.disabled = ob.item_count == 0
	h.add_child(b)
	h.add_child(_petit_bouton("Non", "Refuser", func() -> void:
		_faire("refuser_offre", [oid], zoo._center(e))
		refresh()))


func _alerte_parente(k: float) -> void:
	if k >= 0.03:
		var l := _texte("⚠ Apparenté à vos animaux (parenté moyenne %s) : peu utile pour la diversité." % ZooGenetique.pourcent(k), false, 11)
		l.add_theme_color_override("font_color", Color("ffb38a"))
