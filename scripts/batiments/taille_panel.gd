class_name TaillePanel
extends CanvasLayer
## Carte « Taille du bâtiment », en bas de l'écran pendant qu'on pose un
## bâtiment du catalogue dont la taille se règle (TaillesBatiments) :
##
##   1. Emprise au sol : Petite, Normale, Grande, Très grande, dessinées en plan à
##      la même échelle, puis largeur et profondeur au mètre près (− / +).
##   2. Hauteur : silhouettes de 1 à N niveaux à la même échelle (bornes réalistes
##      du type et de l'époque), puis − / +.
##
## Le fantôme sur la carte change tout de suite, la ligne du bas donne ce que
## la taille change : logements ou emplois, prix, durée du chantier. Elle suit
## l'outil de pose (BuildingSystem) : quel que soit le menu qui l'a lancé.

const W := 560.0
## Proportions de l'emprise proposées en vignettes (côtés multipliés).
const EMPRISES := [["Petite", 0.75], ["Normale", 1.0], ["Grande", 1.25], ["Très grande", 1.5]]
const MAX_VIGNETTES_ETAGES := 7

var bs: BuildingSystem
## Type du catalogue en cours (origine) et taille choisie.
var origine := ""
var w := 0
var d := 0
var e := 0
var etape := 1

var _panel: PanelContainer
var _titre: Label
var _onglets: Array[Button] = []
var _corps: VBoxContainer
var _resume: Label
var _suivant: Button
var _dernier_type := ""
## Carte repliée : la taille se choisit au geste (glisser au sol, puis monter la
## souris) ; dépliée, les vignettes et − / + servent de secours. Gardé pour la session.
static var replie := true
var _menu: Button
var _aide: Label
var _rz: Button
var _annee := -2


func setup(b: BuildingSystem) -> void:
	bs = b
	layer = 5
	name = "PanneauTaille"
	_panel = PanelContainer.new()
	_panel.name = "Carte"
	UiStyle.style_panel(_panel)
	_panel.custom_minimum_size = Vector2(W, 0)
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -W / 2.0
	_panel.offset_right = W / 2.0
	_panel.offset_bottom = -UiStyle.DOCK_HEIGHT - 76.0
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.visible = false
	add_child(_panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 6)
	_panel.add_child(outer)
	var head := HBoxContainer.new()
	outer.add_child(head)
	var ic := TextureRect.new()
	ic.texture = Icones.get_icon("construire", 22, UiStyle.ACCENT)
	ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	head.add_child(ic)
	_titre = Label.new()
	_titre.add_theme_font_size_override("font_size", 15)
	_titre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_titre.clip_text = true
	head.add_child(_titre)
	for i in 2:
		var o := Button.new()
		o.name = "Etape%d" % (i + 1)
		o.text = ["1  Emprise au sol", "2  Hauteur"][i]
		o.toggle_mode = true
		o.focus_mode = Control.FOCUS_NONE
		o.add_theme_font_size_override("font_size", 13)
		UiStyle.style_icon_button(o)
		var n := i + 1
		o.pressed.connect(func() -> void: montrer_etape(n))
		head.add_child(o)
		_onglets.append(o)
	var rz := UiStyle.icon_button("annuler" if Icones.has_icon("annuler") else "rotation", "Taille du catalogue", "", 18, 32)
	rz.name = "TailleCatalogue"
	rz.pressed.connect(func() -> void:
		var b0 := TaillesBatiments.dims(origine)
		choisir(int(b0.w), int(b0.d), int(b0.e)))
	head.add_child(rz)
	_rz = rz
	_menu = Button.new()
	_menu.name = "Menu"
	_menu.focus_mode = Control.FOCUS_NONE
	_menu.add_theme_font_size_override("font_size", 13)
	_menu.tooltip_text = "Régler la taille avec des vignettes et des boutons − / +"
	UiStyle.style_icon_button(_menu)
	_menu.pressed.connect(func() -> void:
		replie = not replie
		_appliquer_repli())
	head.add_child(_menu)
	_aide = Label.new()
	_aide.name = "Aide"
	_aide.text = "Glisse au sol pour tracer l'emprise, relâche, puis monte la souris (ou molette) pour les niveaux. Un clic pose."
	_aide.add_theme_font_size_override("font_size", 12)
	_aide.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	_aide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outer.add_child(_aide)
	_corps = VBoxContainer.new()
	_corps.add_theme_constant_override("separation", 6)
	outer.add_child(_corps)
	var pied := HBoxContainer.new()
	outer.add_child(pied)
	_resume = Label.new()
	_resume.name = "Resume"
	_resume.add_theme_font_size_override("font_size", 13)
	_resume.add_theme_color_override("font_color", UiStyle.TEXT)
	_resume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_resume.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pied.add_child(_resume)
	_suivant = Button.new()
	_suivant.name = "Suivant"
	_suivant.focus_mode = Control.FOCUS_NONE
	_suivant.add_theme_font_size_override("font_size", 13)
	UiStyle.style_icon_button(_suivant)
	_suivant.pressed.connect(func() -> void:
		if etape == 1 and TaillesBatiments.hauteur_reglable(origine):
			montrer_etape(2)
		else:
			_panel.visible = false)
	pied.add_child(_suivant)


func _appliquer_repli() -> void:
	_menu.text = "Menu  ▾" if replie else "Replier  ▴"
	_aide.visible = replie
	_corps.visible = not replie
	_suivant.visible = not replie
	_rz.visible = not replie
	for i in _onglets.size():
		_onglets[i].visible = not replie and (i == 0 or TaillesBatiments.hauteur_reglable(origine))


func is_open() -> bool:
	return _panel != null and _panel.visible


## Suit l'outil de pose : ouvre la carte pour un type réglable, la ferme sinon.
func _process(_delta: float) -> void:
	if bs == null:
		return
	var pose := bs.mode == BuildingSystem.Mode.PLACE and TaillesBatiments.reglable(bs.type_id)
	if not pose:
		if _panel.visible:
			_panel.visible = false
		_dernier_type = ""
		return
	if bs.type_id == _dernier_type:
		return
	_dernier_type = bs.type_id
	var o := TaillesBatiments.origine(bs.type_id)
	if o != origine or not _panel.visible:
		ouvrir(bs.type_id)
	else:
		# Taille changée au geste : la carte suit.
		var z := TaillesBatiments.dims(bs.type_id)
		w = int(z.w)
		d = int(z.d)
		e = int(z.e)
		_remplir()


## Ouvre la carte sur un type (id du catalogue ou à une autre taille).
func ouvrir(type_id: String) -> void:
	var o := TaillesBatiments.origine(type_id)
	var nouveau := o != origine
	origine = o
	var z := TaillesBatiments.dims(type_id)
	w = int(z.w)
	d = int(z.d)
	e = int(z.e)
	_dernier_type = type_id
	_titre.text = "Taille : %s" % String(BuildingCatalog.get_type(o).get("name", o))
	_onglets[1].visible = TaillesBatiments.hauteur_reglable(o)
	_panel.visible = true
	if nouveau or _annee != Epoques.annee():
		_annee = Epoques.annee()
	montrer_etape(1 if nouveau else etape)
	_appliquer_repli()


func montrer_etape(n: int) -> void:
	etape = n if TaillesBatiments.hauteur_reglable(origine) else 1
	for i in _onglets.size():
		_onglets[i].set_pressed_no_signal(i + 1 == etape)
	_remplir()


## Change la taille : le fantôme de l'outil de pose suit.
func choisir(nw: int, nd: int, ne: int) -> void:
	var b := TaillesBatiments.bornes(origine)
	w = clampi(nw, b.w.x, b.w.y)
	d = clampi(nd, b.d.x, b.d.y)
	e = clampi(ne, b.e.x, b.e.y) if TaillesBatiments.hauteur_reglable(origine) else TaillesBatiments.etages_base(origine)
	var id := id_choisi()
	_dernier_type = id
	if bs != null and bs.type_id != id:
		bs.set_place(id, bs.place_perso, bs.place_variant)
	_remplir()


func id_choisi() -> String:
	return TaillesBatiments.id_pour(origine, w, d, e)


func _remplir() -> void:
	for c in _corps.get_children():
		_corps.remove_child(c)
		c.queue_free()
	var b := TaillesBatiments.bornes(origine)
	var b0 := TaillesBatiments.dims(origine)
	if etape == 1:
		var rang := HBoxContainer.new()
		rang.add_theme_constant_override("separation", 6)
		_corps.add_child(rang)
		var grand := maxf(float(b.w.y), float(b.d.y))
		for p in EMPRISES:
			var tw := clampi(roundi(float(b0.w) * float(p[1])), b.w.x, b.w.y)
			var td := clampi(roundi(float(b0.d) * float(p[1])), b.d.x, b.d.y)
			var nom := String(p[0])
			var on := tw == w and td == d
			var carte := _vignette(nom, "%d × %d m" % [tw, td], on, DessinTaille.plan(float(tw) / grand, float(td) / grand))
			carte.name = "Emprise" + nom.replace(" ", "")
			carte.pressed.connect(func() -> void: choisir(tw, td, e))
			rang.add_child(carte)
		var fin := HBoxContainer.new()
		fin.add_theme_constant_override("separation", 10)
		_corps.add_child(fin)
		fin.add_child(_reglage("Largeur", "%d m" % w, func(s: int) -> void: choisir(w + s, d, e), w > b.w.x, w < b.w.y))
		fin.add_child(_reglage("Profondeur", "%d m" % d, func(s: int) -> void: choisir(w, d + s, e), d > b.d.x, d < b.d.y))
		_suivant.text = "Suivant : la hauteur  ▸" if TaillesBatiments.hauteur_reglable(origine) else "C'est bon"
	else:
		var rang := HBoxContainer.new()
		rang.add_theme_constant_override("separation", 6)
		_corps.add_child(rang)
		var choix := _etages_proposes(b.e)
		for n in choix:
			var ne := int(n)
			var carte := _vignette("Plain-pied" if ne <= 1 else "%d niveaux" % ne,
				"%d m" % roundi(ne * TaillesBatiments.ETAGE), ne == e, DessinTaille.facade(ne, b.e.y, float(w) / maxf(float(w), float(d) + float(w))))
			carte.name = "Etages%d" % ne
			carte.pressed.connect(func() -> void: choisir(w, d, ne))
			rang.add_child(carte)
		var fin := HBoxContainer.new()
		_corps.add_child(fin)
		fin.add_child(_reglage("Niveaux", "%d" % e, func(s: int) -> void: choisir(w, d, e + s), e > b.e.x, e < b.e.y))
		var note := Label.new()
		note.text = "Le toit ne compte pas comme niveau."
		var cap := TaillesBatiments.plafond_epoque()
		if cap > 0 and cap < TaillesBatiments._bornes_etages(origine).y:
			note.text += " En %d, on ne monte pas au-delà de %d niveaux." % [Epoques.annee(), b.e.y]
		note.add_theme_font_size_override("font_size", 12)
		note.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
		note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		fin.add_child(note)
		_suivant.text = "C'est bon"
	_resume.text = resume()


## Étages proposés en vignettes : tous s'il y en a peu, sinon répartis.
static func _etages_proposes(be: Vector2i) -> Array:
	var out := []
	var n := be.y - be.x + 1
	if n <= MAX_VIGNETTES_ETAGES:
		for i in range(be.x, be.y + 1):
			out.append(i)
		return out
	for i in MAX_VIGNETTES_ETAGES:
		var v := roundi(lerpf(float(be.x), float(be.y), float(i) / float(MAX_VIGNETTES_ETAGES - 1)))
		if not out.has(v):
			out.append(v)
	return out


## Ligne du bas : ce que la taille change.
func resume() -> String:
	var id := id_choisi()
	var c := TaillesBatiments.chiffres(id)
	var parts := []
	if int(c.logements) > 0:
		parts.append("%d logement%s" % [c.logements, "s" if int(c.logements) > 1 else ""])
	if int(c.emplois) > 0:
		parts.append("%d emploi%s" % [c.emplois, "s" if int(c.emplois) > 1 else ""])
	if int(c.visiteurs) > 0 and int(c.emplois) == 0 and int(c.logements) == 0:
		parts.append("%d visiteurs" % c.visiteurs)
	var z := TaillesBatiments.dims(id)
	parts.push_front("%d × %d m%s" % [int(z.w), int(z.d), (", " + TaillesBatiments.texte_etages(int(z.e))) if TaillesBatiments.hauteur_reglable(origine) else ""])
	if BuildingCatalog.est_prive(id):
		parts.append("payé par un promoteur (%s)" % BuildingSystem.format_short(ReglagesPartie.prix(int(c.prix))))
	else:
		parts.append(BuildingSystem.format_short(ReglagesPartie.prix(int(c.prix))))
	var mois := float(c.mois)
	parts.append("chantier %s mois" % str(snappedf(mois, 0.1)).replace(".", ",") if mois >= 1.0 else "chantier %d semaines" % maxi(1, roundi(mois * 4.3)))
	return "  ·  ".join(parts)


func _vignette(titre: String, sous: String, on: bool, dessin: Control) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(124, 112)
	b.toggle_mode = true
	b.button_pressed = on
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = "%s · %s" % [titre, sous]
	var sel := UiStyle.flat_box(Color(1, 0.82, 0.4, 0.16), 10, 6)
	sel.border_color = UiStyle.ACCENT
	sel.set_border_width_all(2)
	b.add_theme_stylebox_override("normal", UiStyle.flat_box(Color(1, 1, 1, 0.05), 10, 6))
	b.add_theme_stylebox_override("hover", UiStyle.flat_box(Color(1, 1, 1, 0.11), 10, 6))
	b.add_theme_stylebox_override("pressed", sel)
	b.add_theme_stylebox_override("hover_pressed", sel)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 4)
	box.add_theme_constant_override("separation", 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(box)
	dessin.custom_minimum_size = Vector2(114, 66)
	dessin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(dessin)
	for txt in [titre, sous]:
		var l := Label.new()
		l.text = txt
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 13 if txt == titre else 11)
		l.add_theme_color_override("font_color", UiStyle.TEXT if txt == titre else UiStyle.TEXT_DIM)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(l)
	return b


func _reglage(nom: String, valeur: String, pas: Callable, moins: bool, plus: bool) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.name = "Reglage" + nom
	var l := Label.new()
	l.text = nom
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	h.add_child(l)
	for s in [-1, 1]:
		var bt := Button.new()
		bt.name = "Moins" if s < 0 else "Plus"
		bt.text = "−" if s < 0 else "+"
		bt.custom_minimum_size = Vector2(32, 30)
		bt.focus_mode = Control.FOCUS_NONE
		bt.disabled = not (moins if s < 0 else plus)
		UiStyle.style_icon_button(bt)
		var sv: int = s
		bt.pressed.connect(func() -> void: pas.call(sv))
		h.add_child(bt)
		if s < 0:
			var v := Label.new()
			v.text = valeur
			v.custom_minimum_size = Vector2(48, 0)
			v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			v.add_theme_font_size_override("font_size", 14)
			h.add_child(v)
	return h
