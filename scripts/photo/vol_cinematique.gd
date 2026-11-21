class_name VolCinematique
extends Node
## Vol cinématique : la caméra survole un lieu comme un drone de télévision
## (grand cercle en hauteur, puis descente en spirale), avec bandes noires de
## cinéma, un titre et un sous-titre. Il part tout seul :
##   - à chaque nouveau palier d'une ville (Objectifs : Village, Bourg, Ville…),
##     avec un petit feu d'artifice au-dessus de la mairie ;
##   - aux grands événements (scripts/evenements/grands_evenements.gd) : fête
##     de la ville, inauguration d'un grand monument, premier train.
## On peut aussi le lancer à la main sur un événement en cours (Infos, I →
## « Filmer »).
##
## Passer : un clic n'importe où, Échap, Espace ou le bouton « Passer ».
## « ● Filmer » enregistre le vol en vidéo AVI (Images/MiniBlocs/Vidéos).
## « Vols automatiques » (case à cocher, réglage du joueur dans
## user://cinematique.cfg) : décochée, plus aucun vol ne part tout seul.
##
## Pendant le vol, la vitesse du temps passe au plus à « 10 min/s » pour que
## l'événement ne finisse pas avant la caméra, puis revient comme avant.
##
##   vol.lancer({"centre": Vector3, "rayon": 120.0, "titre": "…", "sous_titre": "…",
##               "duree": 14.0, "suivre": Callable (-> Vector3, INF si perdu), "auto": true})

signal message(text: String)
## Un vol commence (true) ou finit (false).
signal en_vol(on: bool)
## Le vol est fini : passe = le joueur l'a passé.
signal fini(passe: bool)

const CONFIG := "user://cinematique.cfg"
const DUREE := 14.0
## Vitesse du temps la plus rapide pendant un vol (indice de DayNight.SPEEDS : 10 min/s).
const VITESSE_MAX := 3
const IPS_VIDEO := 24
const FILE_MAX := 3

var rig: Node3D
var ambiance: DayNight
## Callable(x, z) -> hauteur du sol (NAN si inconnue).
var ground_height: Callable
## Rien ne part si ce Callable renvoie vrai (Atelier, visite, mode photo…).
var bloque: Callable
## Vols automatiques (réglage du joueur).
var auto := true

var actif := false
var plan: Dictionary = {}
var file: Array = []
var camera: Camera3D
var t := 0.0

var _cam_avant: Camera3D
var _calques_caches: Array = []
var _etiquettes_cachees: Array = []
var _modes_avant := {}
var _vitesse_avant := -1
var _layer: CanvasLayer
var _haut: ColorRect
var _bas: ColorRect
var _titre: Label
var _sous_titre: Label
var _bulle: Label
var _commandes: HBoxContainer
var _auto_box: CheckBox
var _filmer_btn: Button
var _avi: AviMjpeg
var _avi_chemin := ""
var _vise := Vector3.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_charger_reglage()
	_construire_ui()


# --- Lancer / passer -------------------------------------------------------------

## Lance un vol (ou le met en file s'il y en a déjà un). Renvoie vrai s'il part
## ou attend son tour. plan.auto : vol automatique (ignoré si « Vols
## automatiques » est décoché).
func lancer(p: Dictionary) -> bool:
	if bool(p.get("auto", false)) and not auto:
		return false
	if not is_inside_tree() or not (p.get("centre", Vector3.INF) as Vector3).is_finite():
		return false
	if bloque.is_valid() and bool(bloque.call()):
		return false
	if actif:
		if file.size() < FILE_MAX:
			file.append(p)
		return true
	_demarrer(p)
	return true


func passer() -> void:
	if actif:
		_terminer(true)


func _demarrer(p: Dictionary) -> void:
	plan = p.duplicate()
	plan.duree = maxf(float(p.get("duree", DUREE)), 3.0)
	plan.rayon = clampf(float(p.get("rayon", 120.0)), 25.0, 900.0)
	actif = true
	t = 0.0
	_cam_avant = get_viewport().get_camera_3d()
	camera = Camera3D.new()
	camera.name = "CameraVol"
	add_child(camera)
	if _cam_avant != null:
		camera.fov = 50.0
		camera.near = _cam_avant.near
		camera.far = _cam_avant.far
		camera.environment = _cam_avant.environment
		camera.attributes = _cam_avant.attributes
	camera.current = true
	_vise = _cible()
	_appliquer_camera(0.0)
	# La caméra de gestion et la vue au sol ne bougent plus.
	_modes_avant.clear()
	var parent := get_parent()
	for n in [rig, parent.get_node_or_null("VueSol") if parent != null else null]:
		if n != null:
			_modes_avant[n] = (n as Node).process_mode
			(n as Node).process_mode = Node.PROCESS_MODE_DISABLED
	# L'interface du jeu disparaît.
	_calques_caches.clear()
	for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
		var cl := c as CanvasLayer
		if cl == _layer or not cl.visible:
			continue
		cl.visible = false
		_calques_caches.append(cl)
	_etiquettes_cachees.clear()
	if parent != null:
		for l in get_tree().root.find_children("*", "Label3D", true, false):
			_etiquettes_cachees.append([l, (l as Label3D).visible])
			(l as Label3D).visible = false
	# Le temps ralentit (sans reprendre s'il était en pause).
	_vitesse_avant = -1
	if ambiance != null and ambiance.speed_index > VITESSE_MAX:
		_vitesse_avant = ambiance.speed_index
		ambiance.set_speed(VITESSE_MAX)
	_titre.text = String(p.get("titre", ""))
	_sous_titre.text = String(p.get("sous_titre", ""))
	_bulle.text = String(p.get("bulle", ""))
	_titre.modulate.a = 0.0
	_sous_titre.modulate.a = 0.0
	_bulle.modulate.a = 0.0
	_auto_box.set_pressed_no_signal(auto)
	_filmer_btn.set_pressed_no_signal(false)
	_commandes.visible = true
	_layer.visible = true
	_bandes(0.0)
	Son.jouer(String(p.get("son", "palier")), -2.0, 0.0, "Effets")
	en_vol.emit(true)


func _terminer(passe: bool) -> void:
	if not actif:
		return
	actif = false
	_arreter_video()
	if ambiance != null and _vitesse_avant >= 0 and ambiance.speed_index == VITESSE_MAX:
		ambiance.set_speed(_vitesse_avant)
	_vitesse_avant = -1
	for cl in _calques_caches:
		if is_instance_valid(cl):
			(cl as CanvasLayer).visible = true
	_calques_caches.clear()
	for e in _etiquettes_cachees:
		if is_instance_valid(e[0]):
			(e[0] as Label3D).visible = bool(e[1])
	_etiquettes_cachees.clear()
	for n in _modes_avant:
		if is_instance_valid(n):
			(n as Node).process_mode = _modes_avant[n]
	_modes_avant.clear()
	if is_instance_valid(_cam_avant):
		_cam_avant.current = true
	_cam_avant = null
	if camera != null:
		camera.queue_free()
		camera = null
	_layer.visible = false
	en_vol.emit(false)
	fini.emit(passe)
	if not file.is_empty():
		var p: Dictionary = file.pop_front()
		_demarrer.call_deferred(p)


# --- Trajectoire -----------------------------------------------------------------

## Point regardé : la cible suivie (train…) si on l'a encore, sinon le centre.
func _cible() -> Vector3:
	var c: Vector3 = plan.centre
	var s: Callable = plan.get("suivre", Callable())
	if s.is_valid():
		var p = s.call()
		if p is Vector3 and (p as Vector3).is_finite():
			return p
	return c


static func _doux(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


## Position de la caméra à l'avancement u (0 à 1) autour du point visé :
## grand cercle haut et loin, puis spirale qui descend et se rapproche.
static func position_vol(vise: Vector3, rayon: float, u: float, depart := 0.0) -> Vector3:
	var e := _doux(u)
	var angle := depart + deg_to_rad(-30.0 + 230.0 * u)
	var dist := lerpf(rayon * 2.4, rayon * 1.05, e)
	var haut := lerpf(rayon * 1.5 + 40.0, rayon * 0.35 + 12.0, e)
	return vise + Vector3(cos(angle) * dist, haut, sin(angle) * dist)


func _appliquer_camera(delta: float) -> void:
	if camera == null:
		return
	var u := clampf(t / float(plan.duree), 0.0, 1.0)
	var vise := _cible()
	# La cible bouge (train) : la caméra la suit en douceur.
	_vise = vise if delta <= 0.0 else _vise.lerp(vise, clampf(delta * 3.0, 0.0, 1.0))
	var p := position_vol(_vise, float(plan.rayon), u, float(plan.get("angle", 0.0)))
	if ground_height.is_valid():
		var g := float(ground_height.call(p.x, p.z))
		if not is_nan(g) and p.y < g + 8.0:
			p.y = g + 8.0
	camera.global_position = p
	var regard := _vise + Vector3(0, 4.0, 0)
	if regard.distance_to(p) > 0.5:
		camera.look_at(regard, Vector3.UP)


func _process(delta: float) -> void:
	if not actif:
		return
	# Image lente (grosse ville) : le vol ne saute pas. En tournage, chaque
	# image du jeu est une image de la vidéo : le film reste fluide.
	delta = 1.0 / IPS_VIDEO if _avi != null else minf(delta, 0.1)
	t += delta
	var d := float(plan.duree)
	_appliquer_camera(delta)
	# Certaines étiquettes se rallument toutes seules (habitant suivi) : on les garde éteintes.
	for e in _etiquettes_cachees:
		if is_instance_valid(e[0]):
			(e[0] as Label3D).visible = false
	# Bandes, titre (de 1 s à 2 s avant la fin), bulle (au milieu).
	_bandes(minf(t / 0.8, 1.0) * minf((d - t) / 0.8 + 0.0, 1.0))
	var a := clampf((t - 1.0) / 0.8, 0.0, 1.0) * clampf((d - 1.2 - t) / 0.8, 0.0, 1.0)
	_titre.modulate.a = a
	_sous_titre.modulate.a = clampf((t - 1.6) / 0.8, 0.0, 1.0) * clampf((d - 1.2 - t) / 0.8, 0.0, 1.0)
	_bulle.modulate.a = clampf((t - d * 0.45) / 0.6, 0.0, 1.0) * clampf((d - 1.5 - t) / 0.6, 0.0, 1.0)
	if _avi != null:
		_image_video()
	if t >= d:
		_terminer(false)


func _input(event: InputEvent) -> void:
	if not actif:
		return
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo and (k.keycode == KEY_ESCAPE or k.keycode == KEY_SPACE):
		passer()
		get_viewport().set_input_as_handled()
		return
	# Le reste (touches, molette) ne commande pas la ville pendant le vol.
	if event is InputEventKey or (event is InputEventMouseButton and (event as InputEventMouseButton).button_index > MOUSE_BUTTON_MIDDLE):
		get_viewport().set_input_as_handled()


# --- Vidéo -----------------------------------------------------------------------

static func dossier_videos() -> String:
	var base := OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
	var d := base.path_join("MiniBlocs").path_join("Vidéos") if base != "" else "user://videos"
	if DirAccess.make_dir_recursive_absolute(d) != OK and base != "":
		d = "user://videos"
		DirAccess.make_dir_recursive_absolute(d)
	return d


func _filmer(on: bool) -> void:
	if not on:
		_arreter_video()
		return
	if DisplayServer.get_name() == "headless":
		_filmer_btn.set_pressed_no_signal(false)
		message.emit("Vidéo impossible ici (pas d'affichage).")
		return
	var taille := Vector2i(get_viewport().get_visible_rect().size)
	taille = Vector2i(taille.x - taille.x % 2, taille.y - taille.y % 2)
	if taille.y > 1080:
		taille = Vector2i(roundi(taille.x * 1080.0 / taille.y) & ~1, 1080)
	_avi = AviMjpeg.new()
	var nom := ModePhoto.nom_fichier(String(plan.get("titre", "vol")), Time.get_datetime_dict_from_system(), "avi")
	_avi_chemin = dossier_videos().path_join(nom)
	if not _avi.ouvrir(_avi_chemin, taille.x, taille.y, IPS_VIDEO):
		message.emit("Vidéo non enregistrée : %s." % _avi.erreur)
		_avi = null
		_filmer_btn.set_pressed_no_signal(false)
		return
	_filmer_btn.text = "● Ça tourne"


func _image_video() -> void:
	var img := get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		return
	if img.get_width() != _avi._largeur or img.get_height() != _avi._hauteur:
		img.resize(_avi._largeur, _avi._hauteur, Image.INTERPOLATE_BILINEAR)
	_avi.ajouter_image(img, 0.85)


func _arreter_video() -> void:
	_filmer_btn.text = "● Filmer"
	if _avi == null:
		return
	var n := _avi.images
	_avi.fermer()
	_avi = null
	if n > 0:
		message.emit("Vol filmé (%d images) : %s" % [n, ProjectSettings.globalize_path(_avi_chemin)])


# --- Réglage du joueur -----------------------------------------------------------

func _charger_reglage() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG) == OK:
		auto = bool(cfg.get_value("vols", "auto", true))


func set_auto(on: bool) -> void:
	auto = on
	var cfg := ConfigFile.new()
	cfg.set_value("vols", "auto", on)
	cfg.save(CONFIG)
	message.emit("Vols cinématiques automatiques : %s." % ("oui" if on else "non (Infos, I → Filmer pour en lancer un)"))


# --- Interface -------------------------------------------------------------------

func _construire_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "CalqueVol"
	_layer.layer = 115
	_layer.visible = false
	add_child(_layer)
	# Un clic n'importe où passe le vol (les boutons gardent le leur).
	var fond := Control.new()
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	fond.mouse_filter = Control.MOUSE_FILTER_STOP
	fond.gui_input.connect(func(e: InputEvent) -> void:
		var mb := e as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index <= MOUSE_BUTTON_RIGHT:
			passer())
	_layer.add_child(fond)
	_haut = ColorRect.new()
	_haut.color = Color.BLACK
	_haut.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_haut.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_layer.add_child(_haut)
	_bas = ColorRect.new()
	_bas.color = Color.BLACK
	_bas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bas.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_layer.add_child(_bas)
	var boite := VBoxContainer.new()
	boite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boite.set_anchors_preset(Control.PRESET_FULL_RECT)
	boite.alignment = BoxContainer.ALIGNMENT_END
	boite.offset_bottom = -130
	boite.add_theme_constant_override("separation", 4)
	_layer.add_child(boite)
	_bulle = _label(boite, 18, Color(1, 1, 1))
	_bulle.add_theme_stylebox_override("normal", UiStyle.flat_box(Color(0.08, 0.08, 0.12, 0.75), 14, 10))
	_bulle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_bulle.autowrap_mode = TextServer.AUTOWRAP_OFF
	_titre = _label(boite, 40, Color(1, 0.96, 0.85))
	_titre.add_theme_constant_override("outline_size", 8)
	_titre.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_sous_titre = _label(boite, 18, Color(1, 1, 1, 0.9))
	_sous_titre.add_theme_constant_override("outline_size", 5)
	_sous_titre.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_commandes = HBoxContainer.new()
	_commandes.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_commandes.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_commandes.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_commandes.offset_right = -16
	_commandes.offset_bottom = -12
	_commandes.add_theme_constant_override("separation", 10)
	_layer.add_child(_commandes)
	_auto_box = CheckBox.new()
	_auto_box.text = "Vols automatiques"
	_auto_box.focus_mode = Control.FOCUS_NONE
	_auto_box.add_theme_font_size_override("font_size", 13)
	_auto_box.toggled.connect(set_auto)
	_commandes.add_child(_auto_box)
	_filmer_btn = Button.new()
	_filmer_btn.text = "● Filmer"
	_filmer_btn.toggle_mode = true
	_filmer_btn.focus_mode = Control.FOCUS_NONE
	_filmer_btn.tooltip_text = "Enregistre le vol en vidéo AVI (Images/MiniBlocs/Vidéos)."
	_filmer_btn.toggled.connect(_filmer)
	_commandes.add_child(_filmer_btn)
	var passer_btn := Button.new()
	passer_btn.name = "Passer"
	passer_btn.text = "Passer ▸  (Échap)"
	passer_btn.focus_mode = Control.FOCUS_NONE
	passer_btn.pressed.connect(passer)
	_commandes.add_child(passer_btn)


func _label(parent: Control, taille: int, col: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l)
	return l


## Bandes noires de cinéma (0 : aucune, 1 : 11 % de l'écran en haut et en bas).
func _bandes(k: float) -> void:
	var h := get_viewport().get_visible_rect().size.y * 0.11 * clampf(k, 0.0, 1.0)
	_haut.offset_bottom = h
	_bas.offset_top = -h
