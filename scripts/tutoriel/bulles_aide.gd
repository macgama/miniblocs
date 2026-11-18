class_name BullesAide
extends CanvasLayer
## Bulles d'aide au centre de l'écran, une information à la fois.
##
## Chaque bulle a un titre, deux ou trois phrases simples et, si possible, une
## **cible** : l'élément de l'écran dont elle parle (un bouton de la barre, une
## section d'un panneau…). La cible est encadrée en surbrillance, le reste de
## l'écran est un peu assombri, et un trait relie la bulle à la cible. Les clics
## passent à travers le voile : on peut cliquer sur ce qui est montré.
##
## Une bulle (Dictionary) :
##   titre, texte, touches (facultatif)
##   panneau : propriété de la scène à ouvrir (« zoo_panel ») ; c'est aussi là
##             qu'on cherche la cible. Sans panneau, on cherche dans la barre (hud).
##   cible   : texte d'un Label ou d'un Button (début du texte), début d'une
##             infobulle ou nom d'un nœud. Une liste : la première trouvée.
##   racine  : autre propriété de la scène où chercher la cible (« tuto_carte »).
##   creer   : true : passe en mode Créer (Atelier) avant de chercher.
##   section : true (défaut) : une cible titre de section s'étend jusqu'à la
##             section suivante.
##   action  : [texte du bouton, id] envoyé par le signal `action`.
## Les textes sont en français : la traduction automatique (TraductionAuto)
## les traduit à l'affichage.

signal action(id: String)
## La suite de bulles est finie (dernière bulle validée) ou fermée.
signal termine(id: String, jusqu_au_bout: bool)

const W := 440.0
const VOILE := Color(0, 0, 0, 0.34)
const CADRE := Color("ffb347")
const MARGE := 8.0

## Scène Terre : on y trouve les panneaux et la barre (hud).
var scene: Node
var id := ""
var titre_suite := ""
var bulles: Array = []
var index := 0
## Texte du bouton de la dernière bulle.
var fin_texte := "Terminer"
var actif := false

var _voile: Control
var _bulle: PanelContainer
var _entete_l: Label
var _titre_l: Label
var _texte_l: Label
var _touches_l: Label
var _points: HBoxContainer
var _prec_b: Button
var _action_b: Button
var _suiv_b: Button
## Cible trouvée (nœud) et son rectangle à l'écran.
var _cible: Control
var _rect := Rect2()
var _cherche := 0.0
var _t := 0.0


func _ready() -> void:
	layer = 40
	_build()
	_montrer(false)


func _build() -> void:
	_voile = Control.new()
	_voile.name = "VoileAide"
	_voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	_voile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_voile.draw.connect(_dessiner_voile)
	add_child(_voile)

	_bulle = PanelContainer.new()
	_bulle.name = "BulleAide"
	var sb := UiStyle.panel_box(0.96, 16, 18)
	sb.border_color = Color(CADRE, 0.85)
	sb.set_border_width_all(2)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 14
	_bulle.add_theme_stylebox_override("panel", sb)
	_bulle.custom_minimum_size = Vector2(W, 0)
	_bulle.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bulle)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_bulle.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	v.add_child(head)
	var ic := TextureRect.new()
	ic.texture = Icones.get_icon("aide", 20, UiStyle.ACCENT)
	ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	head.add_child(ic)
	_entete_l = _label("", 12, UiStyle.TEXT_DIM)
	_entete_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_entete_l)
	var x := UiStyle.icon_button("fermer", "Fermer les bulles", "", 16, 28)
	x.pressed.connect(fermer)
	head.add_child(x)
	_titre_l = _label("", 21, UiStyle.ACCENT)
	v.add_child(_titre_l)
	_texte_l = _label("", 16)
	v.add_child(_texte_l)
	_touches_l = _label("", 13, UiStyle.GOOD)
	v.add_child(_touches_l)
	_points = HBoxContainer.new()
	_points.alignment = BoxContainer.ALIGNMENT_CENTER
	_points.add_theme_constant_override("separation", 6)
	v.add_child(_points)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	_prec_b = _bouton("◂ Précédent", func() -> void: aller(index - 1))
	row.add_child(_prec_b)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)
	_action_b = _bouton("", func() -> void:
		var b: Dictionary = bulle()
		if b.has("action"):
			action.emit(String(b.action[1])))
	row.add_child(_action_b)
	_suiv_b = _bouton("Suivant ▸", suivant)
	_suiv_b.add_theme_stylebox_override("normal", UiStyle.flat_box(UiStyle.ACCENT, 8, 8))
	_suiv_b.add_theme_stylebox_override("hover", UiStyle.flat_box(UiStyle.ACCENT.lightened(0.15), 8, 8))
	_suiv_b.add_theme_stylebox_override("pressed", UiStyle.flat_box(UiStyle.ACCENT.darkened(0.1), 8, 8))
	_suiv_b.add_theme_color_override("font_color", UiStyle.ACCENT_INK)
	_suiv_b.add_theme_color_override("font_hover_color", UiStyle.ACCENT_INK)
	_suiv_b.add_theme_color_override("font_pressed_color", UiStyle.ACCENT_INK)
	row.add_child(_suiv_b)


func _label(t: String, size: int, col := UiStyle.TEXT) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(W - 40, 0)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


func _bouton(t: String, f: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 14)
	b.custom_minimum_size = Vector2(0, 34)
	b.pressed.connect(f)
	return b


# --- Suite de bulles ---------------------------------------------------------------------

## Montre une suite de bulles. nom : titre de la suite (« Le zoo »), en en-tête.
func lancer(suite_id: String, nom: String, liste: Array, fin := "Terminer", depart := 0) -> void:
	if liste.is_empty():
		return
	id = suite_id
	titre_suite = nom
	bulles = liste
	fin_texte = fin
	actif = true
	_montrer(true)
	aller(clampi(depart, 0, liste.size() - 1))


func bulle() -> Dictionary:
	return bulles[index] if actif and index >= 0 and index < bulles.size() else {}


func suivant() -> void:
	if index + 1 >= bulles.size():
		_finir(true)
	else:
		aller(index + 1)


func aller(i: int) -> void:
	if not actif:
		return
	index = clampi(i, 0, bulles.size() - 1)
	var b := bulle()
	_ouvrir_panneau(b)
	_entete_l.text = "%s · %d / %d" % [titre_suite, index + 1, bulles.size()] if bulles.size() > 1 else titre_suite
	_titre_l.text = String(b.get("titre", ""))
	_texte_l.text = String(b.get("texte", ""))
	_touches_l.text = String(b.get("touches", ""))
	_touches_l.visible = _touches_l.text != ""
	_prec_b.visible = index > 0
	_action_b.visible = b.has("action")
	if b.has("action"):
		_action_b.text = String(b.action[0])
	_suiv_b.text = fin_texte if index + 1 >= bulles.size() else "Suivant ▸"
	for c in _points.get_children():
		c.queue_free()
	if bulles.size() > 1:
		for k in bulles.size():
			var p := ColorRect.new()
			p.custom_minimum_size = Vector2(18 if k == index else 8, 8)
			p.color = UiStyle.ACCENT if k == index else Color(1, 1, 1, 0.25)
			p.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_points.add_child(p)
	_points.visible = bulles.size() > 1
	_cible = null
	_rect = Rect2()
	_cherche = 99.0
	_bulle.reset_size()


func fermer() -> void:
	_finir(false)


func _finir(au_bout: bool) -> void:
	if not actif:
		return
	actif = false
	_cible = null
	_montrer(false)
	termine.emit(id, au_bout)


func _montrer(on: bool) -> void:
	visible = on
	if _voile != null:
		_voile.queue_redraw()


func _ouvrir_panneau(b: Dictionary) -> void:
	if scene == null:
		return
	if bool(b.get("creer", false)) and scene.has_method("set_create_mode"):
		var hud = scene.get("hud")
		if hud != null and not bool(hud.get("create_mode")):
			scene.set_create_mode(true)
	var p := String(b.get("panneau", ""))
	if p == "" or not bool(b.get("ouvrir", true)):
		return
	var n = scene.get(p)
	if n is Node and is_instance_valid(n) and not est_ouvert(n):
		ouvrir(n)


## Panneau ouvert ? (is_open(), sinon la visibilité de la couche : Décors).
static func est_ouvert(n: Node) -> bool:
	if n.has_method("is_open"):
		return bool(n.is_open())
	if n is CanvasLayer:
		return (n as CanvasLayer).visible
	if n is CanvasItem:
		return (n as CanvasItem).visible
	return false


static func ouvrir(n: Node) -> void:
	if n.has_method("set_open"):
		n.set_open(true)
	elif n.has_method("set_shown"):
		n.set_shown(true)


# --- Cible ---------------------------------------------------------------------------------

## Racine où chercher la cible de la bulle.
func _racine(b: Dictionary) -> Node:
	if scene == null:
		return null
	if b.has("racine"):
		var r = scene.get(String(b.racine))
		return r if r is Node and is_instance_valid(r) else null
	var p := String(b.get("panneau", ""))
	if p != "":
		var n = scene.get(p)
		if n is Node and is_instance_valid(n):
			return n
		return null
	return scene.get("hud") as Node


static func _cibles(b: Dictionary) -> Array:
	var c = b.get("cible", [])
	if c is String:
		return [] if c == "" else [c]
	return c as Array


## Trouve le contrôle visible dont parle la bulle (null : rien à montrer).
func trouver_cible(b: Dictionary) -> Control:
	var racine := _racine(b)
	if racine == null:
		return null
	var cibles := _cibles(b)
	for c in cibles:
		var n := _chercher(racine, String(c))
		if n != null:
			return n
	# Pas de cible précise (ou pas encore à l'écran) : tout le panneau, s'il est ouvert.
	if String(b.get("panneau", "")) != "" or bool(b.get("panneau_entier", false)):
		return _premier_visible(racine)
	return null


static func _premier_visible(n: Node) -> Control:
	for c in n.get_children():
		if c is Control and (c as Control).is_visible_in_tree() and (c as Control).size.x > 40.0:
			return c
	return null


static func _chercher(n: Node, cle: String) -> Control:
	for c in n.get_children():
		if c is Control:
			var ctl := c as Control
			if not ctl.is_visible_in_tree():
				continue
			if _correspond(ctl, cle):
				return ctl
		elif c is CanvasLayer and not (c as CanvasLayer).visible:
			continue
		var r := _chercher(c, cle)
		if r != null:
			return r
	return null


static func _correspond(c: Control, cle: String) -> bool:
	if String(c.name) == cle:
		return true
	var t := ""
	if c is Label:
		t = (c as Label).text
	elif c is Button:
		t = (c as Button).text
	elif c is LineEdit:
		t = (c as LineEdit).placeholder_text
	if t != "" and t.begins_with(cle):
		return true
	return c.tooltip_text != "" and c.tooltip_text.begins_with(cle)


## Rectangle à encadrer : le contrôle, ou toute la section qu'il ouvre (un titre
## de section s'étend jusqu'au séparateur ou au titre suivant), coupé à la zone
## visible du défilement.
func rect_de(c: Control, b: Dictionary) -> Rect2:
	var r := c.get_global_rect()
	var parent := c.get_parent()
	if c is Label and bool(b.get("section", true)) and parent is BoxContainer:
		var taille := c.get_theme_font_size("font_size")
		var vu := false
		for s in parent.get_children():
			if s == c:
				vu = true
				continue
			if not vu or not (s is Control) or not (s as Control).visible:
				continue
			if s is HSeparator or (s is Label and (s as Label).get_theme_font_size("font_size") >= taille):
				break
			r = r.merge((s as Control).get_global_rect())
	var p := c.get_parent()
	while p != null:
		if p is ScrollContainer:
			r = r.intersection((p as Control).get_global_rect())
			break
		p = p.get_parent()
	return r.grow(MARGE)


func _faire_defiler(c: Control) -> void:
	var p := c.get_parent()
	while p != null:
		if p is ScrollContainer:
			(p as ScrollContainer).ensure_control_visible(c)
			return
		p = p.get_parent()


# --- Mise en page -------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not actif:
		return
	_t += delta
	_cherche += delta
	if _cherche >= 0.25:
		_cherche = 0.0
		var b := bulle()
		var avant := _cible
		_cible = trouver_cible(b)
		if _cible != null and _cible != avant:
			_faire_defiler(_cible)
	_rect = rect_de(_cible, bulle()) if _cible != null and is_instance_valid(_cible) and _cible.is_visible_in_tree() else Rect2()
	_placer()
	_voile.queue_redraw()


## Bulle au centre ; si elle cache la cible, de l'autre côté de l'écran.
func _placer() -> void:
	var vp := _voile.get_rect()
	var s := _bulle.get_combined_minimum_size()
	s.x = maxf(s.x, W)
	var pos := (vp.size - s) * 0.5
	pos.y -= vp.size.y * 0.06
	if _rect.size != Vector2.ZERO and Rect2(pos, s).grow(16).intersects(_rect):
		var gauche := _rect.get_center().x > vp.size.x * 0.5
		var place_g := _rect.position.x - 32.0 - s.x
		var place_d := _rect.end.x + 32.0
		if gauche and place_g >= 16.0:
			pos.x = place_g
		elif not gauche and place_d + s.x <= vp.size.x - 16.0:
			pos.x = place_d
		elif gauche:
			pos.x = 24.0
		else:
			pos.x = vp.size.x - s.x - 24.0
		if Rect2(pos, s).grow(16).intersects(_rect):
			# Cible très large (barre du bas) : au-dessus ou au-dessous.
			pos.x = (vp.size.x - s.x) * 0.5
			pos.y = _rect.position.y - s.y - 32.0 if _rect.get_center().y > vp.size.y * 0.5 else _rect.end.y + 32.0
	pos.x = clampf(pos.x, 12.0, maxf(12.0, vp.size.x - s.x - 12.0))
	pos.y = clampf(pos.y, 12.0, maxf(12.0, vp.size.y - s.y - 12.0))
	_bulle.position = pos
	_bulle.size = s


func cible_rect() -> Rect2:
	return _rect


func bulle_rect() -> Rect2:
	return _bulle.get_global_rect()


func _dessiner_voile() -> void:
	if not actif:
		return
	var vp := _voile.get_rect()
	if _rect.size == Vector2.ZERO:
		_voile.draw_rect(Rect2(Vector2.ZERO, vp.size), Color(VOILE, VOILE.a * 0.6))
		return
	var r := _rect
	# Voile autour du trou.
	_voile.draw_rect(Rect2(0, 0, vp.size.x, r.position.y), VOILE)
	_voile.draw_rect(Rect2(0, r.end.y, vp.size.x, vp.size.y - r.end.y), VOILE)
	_voile.draw_rect(Rect2(0, r.position.y, r.position.x, r.size.y), VOILE)
	_voile.draw_rect(Rect2(r.end.x, r.position.y, vp.size.x - r.end.x, r.size.y), VOILE)
	# Cadre qui respire.
	var a := 0.65 + 0.35 * sin(_t * 4.0)
	var g := 3.0 + 3.0 * (0.5 + 0.5 * sin(_t * 4.0))
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(3)
	sb.border_color = Color(CADRE, a)
	sb.shadow_color = Color(CADRE, 0.35 * a)
	sb.shadow_size = int(g * 2.0)
	sb.draw(_voile.get_canvas_item(), r)
	# Trait de la bulle à la cible.
	var br := _bulle.get_rect()
	var c := r.get_center()
	var depart := Vector2(clampf(c.x, br.position.x + 20, br.end.x - 20), clampf(c.y, br.position.y + 20, br.end.y - 20))
	if depart.x <= br.position.x + 20 or depart.x >= br.end.x - 20:
		depart.x = br.position.x if c.x < br.position.x else (br.end.x if c.x > br.end.x else depart.x)
	if c.y < br.position.y:
		depart.y = br.position.y
	elif c.y > br.end.y:
		depart.y = br.end.y
	var arrivee := Vector2(clampf(depart.x, r.position.x, r.end.x), clampf(depart.y, r.position.y, r.end.y))
	if not br.has_point(arrivee) and depart.distance_to(arrivee) > 6.0:
		_voile.draw_line(depart, arrivee, Color(CADRE, 0.9), 3.0, true)
		_voile.draw_circle(arrivee, 5.0, Color(CADRE, 0.95))
