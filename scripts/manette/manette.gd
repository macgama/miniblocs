class_name Manette
extends CanvasLayer
## Manette et Steam Deck (autoload « ManetteAuto ») : le jeu se joue entièrement à la
## manette, sans rien changer aux panneaux. Le stick gauche promène un curseur qui
## agit comme la souris (survol, clic, glisser) ; les autres boutons envoient les
## touches du clavier que le jeu connaît déjà (Échap, Tab, V, R, F1, T…).
##
## Vue de dessus (gestion)
##   Stick gauche : curseur (au bord de l'écran, la caméra suit)
##   Stick droit  : déplacer la caméra        LB / RB : tourner
##   LT / RT      : dézoomer / zoomer          Croix haut / bas : incliner
##   Croix gauche / droite : outil précédent / suivant (dans un menu : se déplacer)
##   A : cliquer (maintenir pour glisser : tracer, peindre)   B : annuler (Échap)
##   X : tourner le bâtiment (R)   Y : vue au sol (V)
##   Menu (Start) : menu pause     Vue (Select) : Gérer / Créer (Tab)
##   Stick gauche enfoncé : aide (F1)   Stick droit enfoncé : pause du temps (T)
## Vue au sol : stick gauche marcher, stick droit regarder, A sauter, X interagir /
##   monter à bord (E), LB courir, RT cliquer, Y vue suivante, B libérer la vue.
##
## Les panneaux suivent la croix quand un bouton a le focus (menus) : A valide.

## Une commande de jeu demandée à la manette (la scène de jeu l'écoute).
signal commande(nom: String)

const ZONE_MORTE := 0.2
## Vitesse du curseur (pixels de fenêtre par seconde, pour une fenêtre de 900 px de haut).
const VITESSE_CURSEUR := 950.0
const BORD := 10.0

## La dernière entrée vient de la manette (aides affichées, curseur visible).
static var actif := false
## Lus par la caméra (CameraRig) et la vue au sol (VueSol), entre -1 et 1.
static var pan := Vector2.ZERO
static var tourne := 0.0
static var zoom := 0.0
static var incline := 0.0
static var marche := Vector2.ZERO
static var regard := Vector2.ZERO
static var course := false
## Vue au sol en cours (VueSol le dit) : les sticks marchent et regardent.
static var au_sol := false
## Options (Options → Manette), gardées dans user://options.cfg.
static var sensibilite := 1.0
static var inverser_y := false
static var vibrations := true
static var aides := true
static var instance: Manette

## Minutes jouées à la manette (succès « Pouces verts »).
var _minutes_acc := 0.0
var _axes := {}
var _pos := Vector2(800, 450)
var _focus_mode := false
var _a_souris := false
var _rt_souris := false
var _curseur: Control
var _aide: Label
var _aide_boite: PanelContainer
var _dernier_warp := Vector2(-1, -1)


func _ready() -> void:
	instance = self
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	charger()
	_curseur = Curseur.new()
	_curseur.visible = false
	add_child(_curseur)
	# Rappel des boutons : au-dessus de la barre du bas, centré, sur un fond sombre.
	_aide_boite = PanelContainer.new()
	_aide_boite.name = "AidesManette"
	_aide_boite.visible = false
	_aide_boite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aide_boite.add_theme_stylebox_override("panel", UiStyle.flat_box(Color(0.05, 0.07, 0.06, 0.78), 8, 6))
	_aide_boite.anchor_left = 0.5
	_aide_boite.anchor_right = 0.5
	_aide_boite.anchor_top = 1.0
	_aide_boite.anchor_bottom = 1.0
	_aide_boite.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_aide_boite.grow_vertical = Control.GROW_DIRECTION_BEGIN
	# Au-dessus de la barre du bas et de la ligne d'aide de l'outil en cours.
	_aide_boite.offset_top = -UiStyle.DOCK_HEIGHT - 110.0
	_aide_boite.offset_bottom = -UiStyle.DOCK_HEIGHT - 60.0
	add_child(_aide_boite)
	_aide = Label.new()
	_aide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aide.add_theme_font_size_override("font_size", 13)
	_aide.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	_aide_boite.add_child(_aide)
	var vp := get_viewport()
	if vp != null:
		_pos = _fenetre() * 0.5
		vp.gui_focus_changed.connect(_on_focus)
	Input.joy_connection_changed.connect(func(_dev: int, connected: bool) -> void:
		if not connected and Input.get_connected_joypads().is_empty():
			_set_actif(false))
	# Steam Deck : la manette d'abord, en plein écran au premier lancement.
	if SteamPont.steam_deck():
		_set_actif(true)


static func charger() -> void:
	var cf := ConfigFile.new()
	if cf.load(OptionsJeu.FICHIER) != OK:
		return
	sensibilite = clampf(float(cf.get_value("manette", "sensibilite", sensibilite)), 0.4, 2.5)
	inverser_y = bool(cf.get_value("manette", "inverser_y", inverser_y))
	vibrations = bool(cf.get_value("manette", "vibrations", vibrations))
	aides = bool(cf.get_value("manette", "aides", aides))


static func sauver() -> void:
	OptionsJeu.sauver()


static func vibrer(force := 0.4, duree := 0.2) -> void:
	if not vibrations or not actif:
		return
	for j in Input.get_connected_joypads():
		Input.start_joy_vibration(j, force * 0.6, force, duree)


func _set_actif(on: bool) -> void:
	if actif == on:
		return
	actif = on
	if not on:
		_lacher()
	elif not en_partie():
		# Menus : on commence à la croix si un bouton a déjà le focus.
		var f := get_viewport().gui_get_focus_owner()
		_focus_mode = f != null and f.is_visible_in_tree()
	_maj_affichage()


## Une partie est ouverte (sinon : menu principal, globe, chargement).
func en_partie() -> bool:
	var sc := get_tree().current_scene if get_tree() != null else null
	if sc == null:
		for c in get_tree().root.get_children():
			if c.get("succes_suivi") != null:
				return true
		return false
	return sc.get("succes_suivi") != null


## Relâche tout ce qui est tenu (bouton de souris, sticks).
func _lacher() -> void:
	if _a_souris:
		_clic(false)
	if _rt_souris:
		_rt_souris = false
		_clic(false)
	_axes.clear()
	pan = Vector2.ZERO
	marche = Vector2.ZERO
	regard = Vector2.ZERO
	tourne = 0.0
	zoom = 0.0
	incline = 0.0
	course = false


# --- Entrées ----------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if event.has_meta("manette"):
		return
	if event is InputEventJoypadMotion:
		var m := event as InputEventJoypadMotion
		_axes[m.axis] = m.axis_value
		if absf(m.axis_value) > 0.5:
			_set_actif(true)
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton:
		_set_actif(true)
		_bouton(event as InputEventJoypadButton)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		# Le déplacement que l'on vient de provoquer (warp) ne compte pas.
		var warp := get_viewport().get_final_transform().affine_inverse() * _dernier_warp
		if actif and mm.position.distance_to(warp) > 4.0 and mm.position.distance_to(_dernier_warp) > 4.0 \
				and mm.relative.length() > 3.0:
			_set_actif(false)
	elif event is InputEventKey or event is InputEventMouseButton:
		if actif and event.is_pressed():
			_set_actif(false)


func _bouton(b: InputEventJoypadButton) -> void:
	var p := b.pressed
	if au_sol:
		match b.button_index:
			JOY_BUTTON_A: _touche(KEY_SPACE, p)
			JOY_BUTTON_X: _touche(KEY_E, p)
			JOY_BUTTON_Y: _touche(KEY_V, p)
			JOY_BUTTON_B: _touche(KEY_ESCAPE, p)
			JOY_BUTTON_START: _touche(KEY_ESCAPE, p)
			JOY_BUTTON_LEFT_SHOULDER: course = p
			JOY_BUTTON_LEFT_STICK: _touche(KEY_F1, p)
			JOY_BUTTON_RIGHT_STICK: _touche(KEY_T, p)
		return
	match b.button_index:
		JOY_BUTTON_A:
			var f := get_viewport().gui_get_focus_owner()
			if p and _focus_mode and f != null and f.is_visible_in_tree():
				_touche(KEY_ENTER, true)
				_touche(KEY_ENTER, false)
			elif p:
				_a_souris = true
				_clic(true)
			elif _a_souris:
				_a_souris = false
				_clic(false)
		JOY_BUTTON_B: _touche(KEY_ESCAPE, p)
		JOY_BUTTON_START: _touche(KEY_ESCAPE, p)
		JOY_BUTTON_BACK: _touche(KEY_TAB, p)
		JOY_BUTTON_X: _touche(KEY_R, p)
		JOY_BUTTON_Y: _touche(KEY_V, p)
		JOY_BUTTON_LEFT_STICK: _touche(KEY_F1, p)
		JOY_BUTTON_RIGHT_STICK: _touche(KEY_T, p)
		JOY_BUTTON_LEFT_SHOULDER: tourne = 1.0 if p else 0.0
		JOY_BUTTON_RIGHT_SHOULDER: tourne = -1.0 if p else 0.0
		JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT:
			_croix(b.button_index, p)


## Croix : dans un menu (un bouton a le focus), elle déplace le focus ; sinon elle
## incline la caméra (haut / bas) et change d'outil (gauche / droite).
func _croix(btn: int, p: bool) -> void:
	var f := get_viewport().gui_get_focus_owner()
	var menu := f != null and f.is_visible_in_tree() and not (f is LineEdit)
	if menu or not p and _focus_mode:
		if p:
			_focus_mode = true
			_curseur.visible = false
		var k: Key = {JOY_BUTTON_DPAD_UP: KEY_UP, JOY_BUTTON_DPAD_DOWN: KEY_DOWN,
			JOY_BUTTON_DPAD_LEFT: KEY_LEFT, JOY_BUTTON_DPAD_RIGHT: KEY_RIGHT}[btn]
		_touche(k, p)
		return
	match btn:
		JOY_BUTTON_DPAD_UP: incline = -1.0 if p else 0.0
		JOY_BUTTON_DPAD_DOWN: incline = 1.0 if p else 0.0
		JOY_BUTTON_DPAD_LEFT:
			if p:
				commande.emit("outil_precedent")
		JOY_BUTTON_DPAD_RIGHT:
			if p:
				commande.emit("outil_suivant")


func _axe(a: int) -> float:
	var v := float(_axes.get(a, 0.0))
	return 0.0 if absf(v) < ZONE_MORTE else signf(v) * (absf(v) - ZONE_MORTE) / (1.0 - ZONE_MORTE)


func _stick(ax: int, ay: int) -> Vector2:
	var s := Vector2(float(_axes.get(ax, 0.0)), float(_axes.get(ay, 0.0)))
	var l := s.length()
	if l < ZONE_MORTE:
		return Vector2.ZERO
	return s / l * minf((l - ZONE_MORTE) / (1.0 - ZONE_MORTE), 1.0)


func _process(delta: float) -> void:
	if not actif:
		return
	_minutes_acc += delta
	if _minutes_acc >= 60.0:
		_minutes_acc -= 60.0
		Succes.ajouter("manette_min")
		Succes.sauver_si_besoin()
	var g := _stick(JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y)
	var d := _stick(JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y)
	var lt := _axe(JOY_AXIS_TRIGGER_LEFT)
	var rt := _axe(JOY_AXIS_TRIGGER_RIGHT)
	if au_sol:
		marche = Vector2(g.x, -g.y)
		regard = Vector2(d.x, d.y * (-1.0 if inverser_y else 1.0)) * sensibilite
		pan = Vector2.ZERO
		zoom = 0.0
		# RT : clic (interagir) ; on garde la souris capturée par la vue au sol.
		if rt > 0.5 and not _rt_souris:
			_rt_souris = true
			_clic(true)
		elif rt < 0.3 and _rt_souris:
			_rt_souris = false
			_clic(false)
		_maj_affichage()
		return
	marche = Vector2.ZERO
	regard = Vector2.ZERO
	pan = Vector2(d.x, d.y * (-1.0 if inverser_y else 1.0))
	zoom = lt - rt
	if g != Vector2.ZERO:
		if _focus_mode:
			_focus_mode = false
		var win := _fenetre()
		var v := g * g.length() * VITESSE_CURSEUR * sensibilite * maxf(win.y, 400.0) / 900.0 * delta
		var avant := _pos
		_pos = (_pos + v).clamp(Vector2.ZERO, win - Vector2.ONE)
		# Au bord de l'écran, la caméra suit le curseur.
		var bord := Vector2.ZERO
		if _pos.x <= BORD and g.x < 0.0 or _pos.x >= win.x - BORD - 1.0 and g.x > 0.0:
			bord.x = g.x
		if _pos.y <= BORD and g.y < 0.0 or _pos.y >= win.y - BORD - 1.0 and g.y > 0.0:
			bord.y = g.y
		pan += bord
		if _pos != avant:
			_bouger(_pos - avant)
	_maj_affichage()


## Taille de la fenêtre en pixels (sans fenêtre, en test : celle de la vue).
func _fenetre() -> Vector2:
	var w := Vector2(DisplayServer.window_get_size())
	if w.x < 2.0 or w.y < 2.0:
		var vp := get_viewport()
		w = vp.get_visible_rect().size * vp.get_final_transform().get_scale() if vp != null else Vector2(1600, 900)
	return w


# --- Événements fabriqués ------------------------------------------------------------------

func _envoyer(e: InputEvent) -> void:
	e.set_meta("manette", true)
	Input.parse_input_event(e)


func _touche(k: Key, p: bool) -> void:
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.pressed = p
	_envoyer(e)


func _bouger(rel: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = _pos
	e.global_position = _pos
	e.relative = rel
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if _a_souris or _rt_souris else 0
	_envoyer(e)
	if DisplayServer.get_name() != "headless" and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		_dernier_warp = _pos
		Input.warp_mouse(_pos)


func _clic(p: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = p
	e.position = _pos
	e.global_position = _pos
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if p else 0
	_envoyer(e)


## Position du curseur (pixels de la fenêtre).
func position_curseur() -> Vector2:
	return _pos


func placer_curseur(p: Vector2) -> void:
	_pos = p


# --- Affichage ----------------------------------------------------------------------------

func _maj_affichage() -> void:
	if _curseur == null:
		return
	var vp := get_viewport()
	_curseur.visible = actif and not au_sol and not _focus_mode and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED
	if _curseur.visible and vp != null:
		_curseur.position = vp.get_final_transform().affine_inverse() * _pos
	_aide_boite.visible = actif and aides
	if _aide_boite.visible:
		var t := texte_aides()
		if _aide.text != t:
			_aide.text = t
			var w := _aide.get_minimum_size().x + 16.0
			_aide_boite.offset_left = -w * 0.5
			_aide_boite.offset_right = w * 0.5


## Aides des boutons, selon ce que l'on fait.
func texte_aides() -> String:
	if au_sol:
		return "Stick G marcher · Stick D regarder · Ⓐ sauter · Ⓧ interagir · LB courir · RT cliquer · Ⓨ vue · Ⓑ libérer"
	if _focus_mode:
		return "Croix se déplacer · Ⓐ valider · Ⓑ fermer · Stick G curseur"
	if not en_partie():
		return "Stick G curseur · Ⓐ cliquer · Croix choisir · Ⓑ retour"
	return "Ⓐ cliquer · Ⓑ annuler · Stick D caméra · LB RB tourner · LT RT zoom · Croix incliner / outil\nⓍ tourner le bâtiment · Ⓨ vue au sol · ☰ menu · ⧉ Gérer / Créer · Stick G enfoncé : aide"


## Champ de texte pris à la manette : le clavier à l'écran de Steam (Steam Deck).
func _on_focus(c: Control) -> void:
	if actif and c is LineEdit and c.is_visible_in_tree():
		SteamPont.clavier(c.get_global_rect(), c is TextEdit)


class Curseur:
	extends Control

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(28, 28)

	func _draw() -> void:
		var pts := PackedVector2Array([Vector2(0, 0), Vector2(0, 22), Vector2(6, 17), Vector2(10, 26), Vector2(14, 24), Vector2(10, 16), Vector2(18, 16)])
		draw_colored_polygon(pts, Color("ffd166"))
		var contour := pts.duplicate()
		contour.append(pts[0])
		draw_polyline(contour, Color("2a2414"), 2.0, true)
