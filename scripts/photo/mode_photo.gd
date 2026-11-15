class_name ModePhoto
extends Node
## Mode photo (F6) : le temps se fige, l'interface disparaît, une caméra libre
## se promène partout (même au ras des toits), on choisit un filtre, l'heure du
## jour, le cadrage (paysage, vertical 9:16 pour TikTok, carré, cinéma) et on
## prend la photo en PNG, en HD ou en 4K, sans l'interface.
##
## Caméra libre : ZQSD / WASD pour avancer, A / E (Q / E en QWERTY) pour
## descendre et monter, clic droit glissé pour regarder, molette pour zoomer,
## Maj pour aller vite, Ctrl pour aller lentement. Espace : photo. H : masquer
## le panneau. Échap ou F6 : quitter. Voir docs/photo.md.

signal message(text: String)
## Le joueur veut le time-lapse (bouton du panneau, Maj+F6).
signal timelapse_requested
## « Filmer ce cadrage en time-lapse » : la vue de la caméra libre.
signal cadrage_timelapse(xform: Transform3D, fov: float, format: String)
signal ouvert_change(on: bool)

const FILTRES := [
	["Aucun", 0], ["Noir et blanc", 1], ["Sépia (années 1800)", 2], ["Vintage", 3],
	["Chaud", 4], ["Froid", 5], ["Vif", 6], ["Délavé", 7], ["Nuit bleue", 8],
	["Maquette (tilt-shift)", 9], ["Carte postale", 10], ["Néon", 11],
]
## Cadrages : rapport largeur / hauteur (0 : celui de l'écran).
const FORMATS := [
	{"id": "ecran", "nom": "Écran", "r": 0.0},
	{"id": "paysage", "nom": "Paysage 16:9 (YouTube)", "r": 16.0 / 9.0},
	{"id": "vertical", "nom": "Vertical 9:16 (TikTok, Reels)", "r": 9.0 / 16.0},
	{"id": "carre", "nom": "Carré 1:1 (Instagram)", "r": 1.0},
	{"id": "portrait", "nom": "Portrait 4:5", "r": 4.0 / 5.0},
	{"id": "cinema", "nom": "Cinéma 2,39:1", "r": 2.39},
]
## Définition : nombre de pixels du petit côté de la photo.
const DEFINITIONS := [["HD (1080 px)", 1080], ["2K (1440 px)", 1440], ["4K (2160 px)", 2160]]
const PANEL_W := 300.0

var rig: Node3D
var ambiance: DayNight
## Callable(x, z) -> hauteur du sol (NAN si inconnue) : la caméra ne passe pas sous terre.
var ground_height: Callable
## Appelé juste avant d'entrer (terre_main : range l'outil en cours).
var avant_entree: Callable
## Nom du lieu pour le nom des fichiers.
var nom_lieu := ""

var actif := false
var figer := true
var filtre := 0
var force := 1.0
var luminosite := 0.0
var contraste := 1.0
var saturation := 1.0
var vignette := 0.0
var grain := 0.0
var format := "ecran"
var definition := 1080
var grille := false
var flou := false
var mise_au_point := 60.0
var force_flou := 0.12
var roulis := 0.0
## Dernière photo enregistrée (chemin complet).
var derniere_photo := ""

var camera: Camera3D
var _attrs: CameraAttributesPractical
var _yaw := 0.0
var _pitch := 0.0
var _regard := false
var _cam_avant: Camera3D
var _calques_caches: Array = []
var _etiquettes_cachees: Array = []
var _pause_avant := false
var _shift_avant := 0.0
var _modes_avant := {}
var _filtre_layer: CanvasLayer
var _filtre_rect: ColorRect
var _materiau: ShaderMaterial
var _layer: CanvasLayer
var _panel: PanelContainer
var _guides: Control
var _flash: ColorRect
var _heure: HSlider
var _heure_txt: Label
var _figer_box: CheckBox
var _info: Label
var _fov: HSlider
var _en_capture := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_materiau = ShaderMaterial.new()
	_materiau.shader = load("res://scripts/photo/filtre_photo.gdshader")
	_filtre_layer = CanvasLayer.new()
	_filtre_layer.layer = 110
	_filtre_layer.visible = false
	add_child(_filtre_layer)
	_filtre_rect = ColorRect.new()
	_filtre_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_filtre_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_filtre_rect.material = _materiau
	_filtre_layer.add_child(_filtre_rect)
	_construire_ui()
	_appliquer_filtre()


# --- Entrer / sortir -------------------------------------------------------------

func toggle() -> void:
	if actif:
		quitter()
	else:
		entrer()


## Le temps peut-il se figer ? Pas sur une carte entre amis : les autres jouent.
static func figeable() -> bool:
	return Multijoueur.role == Multijoueur.Role.SOLO


func entrer() -> void:
	if actif or not is_inside_tree():
		return
	if avant_entree.is_valid():
		avant_entree.call()
	actif = true
	_cam_avant = get_viewport().get_camera_3d()
	camera = Camera3D.new()
	camera.name = "CameraPhoto"
	add_child(camera)
	if _cam_avant != null:
		camera.global_transform = _cam_avant.global_transform
		camera.fov = _cam_avant.fov
		camera.near = _cam_avant.near
		camera.far = _cam_avant.far
		camera.environment = _cam_avant.environment
		if _cam_avant.attributes is CameraAttributesPractical:
			_attrs = (_cam_avant.attributes as CameraAttributesPractical).duplicate()
	if _attrs == null:
		_attrs = CameraAttributesPractical.new()
		var w := get_viewport().find_world_3d()
		if w != null and w.camera_attributes is CameraAttributesPractical:
			_attrs = (w.camera_attributes as CameraAttributesPractical).duplicate()
	camera.attributes = _attrs
	var e := camera.global_transform.basis.get_euler()
	_pitch = e.x
	_yaw = e.y
	roulis = 0.0
	camera.current = true
	_fov.set_value_no_signal(camera.fov)
	# Plus rien ne bouge en dessous : caméra de gestion, vue au sol.
	_modes_avant.clear()
	for n in [rig, get_parent().get_node_or_null("VueSol") if get_parent() != null else null]:
		if n != null:
			_modes_avant[n] = (n as Node).process_mode
			(n as Node).process_mode = Node.PROCESS_MODE_DISABLED
	# L'interface du jeu disparaît (tous les calques, sauf ceux du mode photo).
	_calques_caches.clear()
	for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
		var cl := c as CanvasLayer
		if cl == _layer or cl == _filtre_layer or not cl.visible:
			continue
		cl.visible = false
		_calques_caches.append(cl)
	# Étiquettes flottantes (noms des villages, habitant suivi) : pas sur la photo.
	_etiquettes_cachees.clear()
	if get_parent() != null:
		for l in get_parent().find_children("*", "Label3D", true, false):
			if (l as Label3D).visible:
				(l as Label3D).visible = false
				_etiquettes_cachees.append(l)
	_pause_avant = get_tree().paused
	if ambiance != null:
		_shift_avant = ambiance._shift
	figer = figer and figeable()
	_figer_box.disabled = not figeable()
	_figer_box.set_pressed_no_signal(figer)
	_appliquer_figer()
	_filtre_layer.visible = true
	_layer.visible = true
	_panel.visible = true
	_guides.visible = true
	_maj_heure_ui()
	_appliquer_camera()
	Son.jouer("ui_ouvrir", -3.0, 0.0, "Interface")
	ouvert_change.emit(true)


func quitter() -> void:
	if not actif:
		return
	actif = false
	_regard = false
	if ambiance != null:
		ambiance._shift = _shift_avant
		ambiance._apply()
	get_tree().paused = _pause_avant
	for cl in _calques_caches:
		if is_instance_valid(cl):
			(cl as CanvasLayer).visible = true
	_calques_caches.clear()
	for l in _etiquettes_cachees:
		if is_instance_valid(l):
			(l as Label3D).visible = true
	_etiquettes_cachees.clear()
	for n in _modes_avant:
		if is_instance_valid(n):
			(n as Node).process_mode = _modes_avant[n]
	_modes_avant.clear()
	if is_instance_valid(_cam_avant):
		_cam_avant.current = true
	if camera != null:
		camera.queue_free()
		camera = null
	_attrs = null
	_layer.visible = false
	_filtre_layer.visible = false
	Son.jouer("ui_fermer", -3.0, 0.0, "Interface")
	ouvert_change.emit(false)


func _appliquer_figer() -> void:
	if not actif:
		return
	get_tree().paused = figer or _pause_avant
	_heure.editable = figer
	if not figer and ambiance != null:
		ambiance._shift = _shift_avant
		ambiance._apply()
	_maj_heure_ui()


# --- Caméra libre ----------------------------------------------------------------

func _process(delta: float) -> void:
	if not actif or camera == null:
		return
	var dir := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.z -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.z += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	if Input.is_physical_key_pressed(KEY_E):
		dir.y += 1.0
	if Input.is_physical_key_pressed(KEY_Q):
		dir.y -= 1.0
	if dir == Vector3.ZERO:
		return
	var sol := _sol(camera.global_position)
	var hauteur := camera.global_position.y - (0.0 if is_nan(sol) else sol)
	var vitesse := clampf(hauteur * 0.8, 3.0, 400.0)
	if Input.is_key_pressed(KEY_SHIFT):
		vitesse *= 4.0
	if Input.is_key_pressed(KEY_CTRL):
		vitesse *= 0.2
	# Avancer reste à l'horizontale (comme un drone), monter et descendre à part.
	var b := Basis(Vector3.UP, _yaw)
	var dep := b * Vector3(dir.x, 0.0, dir.z)
	if dep.length() > 0.0:
		dep = dep.normalized()
	dep.y = dir.y
	camera.global_position += dep * vitesse * delta
	_appliquer_camera()


func _sol(p: Vector3) -> float:
	if ground_height.is_valid():
		return float(ground_height.call(p.x, p.z))
	return NAN


func _appliquer_camera() -> void:
	if camera == null:
		return
	var sol := _sol(camera.global_position)
	if not is_nan(sol) and camera.global_position.y < sol + 0.6:
		camera.global_position.y = sol + 0.6
	_pitch = clampf(_pitch, deg_to_rad(-89.0), deg_to_rad(89.0))
	camera.rotation = Vector3(_pitch, _yaw, deg_to_rad(roulis))
	_attrs.dof_blur_far_enabled = flou
	_attrs.dof_blur_near_enabled = flou and mise_au_point > 6.0
	_attrs.dof_blur_far_distance = mise_au_point
	_attrs.dof_blur_far_transition = maxf(mise_au_point * 0.6, 2.0)
	_attrs.dof_blur_near_distance = mise_au_point * 0.35
	_attrs.dof_blur_near_transition = maxf(mise_au_point * 0.25, 1.0)
	_attrs.dof_blur_amount = force_flou
	if _info != null:
		var h := camera.global_position.y - (0.0 if is_nan(sol) else sol)
		_info.text = "Hauteur %d m · champ %d°" % [roundi(h), roundi(camera.fov)]


func _input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		if actif and k != null:
			get_viewport().set_input_as_handled()
		return
	if k.keycode == KEY_F6 and not k.ctrl_pressed and not k.alt_pressed:
		if k.shift_pressed:
			if actif:
				quitter()
			timelapse_requested.emit()
		elif actif or not get_tree().paused:
			toggle()
		get_viewport().set_input_as_handled()
		return
	if not actif:
		return
	get_viewport().set_input_as_handled()
	match k.keycode:
		KEY_ESCAPE:
			quitter()
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			prendre_photo()
		KEY_H:
			_panel.visible = not _panel.visible
			_guides.visible = _panel.visible


func _unhandled_input(event: InputEvent) -> void:
	if not actif or camera == null:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_MIDDLE:
			_regard = mb.pressed
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.fov = clampf(camera.fov - 2.0, 8.0, 110.0)
			_fov.set_value_no_signal(camera.fov)
			_appliquer_camera()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.fov = clampf(camera.fov + 2.0, 8.0, 110.0)
			_fov.set_value_no_signal(camera.fov)
			_appliquer_camera()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		if _regard:
			var mm := event as InputEventMouseMotion
			var k := 0.0035 * clampf(camera.fov / 70.0, 0.15, 1.5)
			_yaw -= mm.relative.x * k
			_pitch -= mm.relative.y * k
			_appliquer_camera()
		get_viewport().set_input_as_handled()


# --- Heure du jour (temps figé) --------------------------------------------------

## Heure affichée (Soleil, ciel) en heures locales.
func heure_affichee() -> float:
	if ambiance == null:
		return 12.0
	return fposmod(ambiance.display_time() + ambiance.utc_offset() * 3600.0, 86400.0) / 3600.0


## Règle la lumière comme à l'heure h (le temps du jeu, lui, ne bouge pas).
func set_heure(h: float) -> void:
	if ambiance == null or not figer:
		return
	ambiance._shift += (clampf(h, 0.0, 23.99) - heure_affichee()) * 3600.0
	ambiance._apply()
	_maj_heure_ui()


func _maj_heure_ui() -> void:
	if _heure == null:
		return
	var h := heure_affichee()
	_heure.set_value_no_signal(h)
	_heure_txt.text = "%02dh%02d" % [int(h), int(fmod(h, 1.0) * 60.0)] + ("" if figer else " (figez le temps pour la changer)")


# --- Filtres ---------------------------------------------------------------------

func _appliquer_filtre() -> void:
	_materiau.set_shader_parameter("filtre", filtre)
	_materiau.set_shader_parameter("force", force)
	_materiau.set_shader_parameter("luminosite", luminosite)
	_materiau.set_shader_parameter("contraste", contraste)
	_materiau.set_shader_parameter("saturation", saturation)
	_materiau.set_shader_parameter("vignette", vignette)
	_materiau.set_shader_parameter("grain", grain)
	_materiau.set_shader_parameter("graine", randf() * 100.0)
	_filtre_rect.visible = filtre != 0 or absf(luminosite) > 0.001 or absf(contraste - 1.0) > 0.001 \
		or absf(saturation - 1.0) > 0.001 or vignette > 0.001 or grain > 0.001


# --- Cadrage et photo ------------------------------------------------------------

static func rapport_format(id: String, ecran: Vector2) -> float:
	for f in FORMATS:
		if f.id == id:
			return float(f.r) if float(f.r) > 0.0 else ecran.x / maxf(ecran.y, 1.0)
	return ecran.x / maxf(ecran.y, 1.0)


## Zone de l'écran gardée par le cadrage (le reste est assombri).
static func rect_cadre(ecran: Vector2, r: float) -> Rect2:
	var re := ecran.x / maxf(ecran.y, 1.0)
	if r >= re:
		var h := ecran.x / r
		return Rect2(0.0, (ecran.y - h) * 0.5, ecran.x, h)
	var w := ecran.y * r
	return Rect2((ecran.x - w) * 0.5, 0.0, w, ecran.y)


## Taille de la photo : le petit côté vaut `def` pixels.
static func taille_sortie(r: float, def: int) -> Vector2i:
	if r >= 1.0:
		return Vector2i(roundi(def * r / 2.0) * 2, def)
	return Vector2i(def, roundi(def / r / 2.0) * 2)


## Champ vertical de la photo pour qu'elle montre exactement le cadre vu à l'écran.
static func fov_sortie(fov: float, ecran: Vector2, r: float) -> float:
	var re := ecran.x / maxf(ecran.y, 1.0)
	if r <= re:
		return fov
	var t := tan(deg_to_rad(fov) * 0.5) * re / r
	return rad_to_deg(atan(t) * 2.0)


## Dossier des photos : Images/MiniBlocs/Photos (sinon dans les données du jeu).
static func dossier_photos() -> String:
	var base := OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
	var d := base.path_join("MiniBlocs").path_join("Photos") if base != "" else "user://photos"
	if DirAccess.make_dir_recursive_absolute(d) != OK and base != "":
		d = "user://photos"
		DirAccess.make_dir_recursive_absolute(d)
	return d


static func nom_fichier(lieu: String, quand: Dictionary, ext := "png") -> String:
	var l := lieu.strip_edges()
	for ch in ["/", "\\", ":", "*", "?", "\"", "<", ">", "|"]:
		l = l.replace(ch, " ")
	l = l.strip_edges()
	if l.length() > 40:
		l = l.substr(0, 40).strip_edges()
	return "MiniBlocs %s%04d-%02d-%02d %02d-%02d-%02d.%s" % [l + " " if l != "" else "",
		int(quand.year), int(quand.month), int(quand.day), int(quand.hour), int(quand.minute), int(quand.second), ext]


## Rend la vue de la caméra libre (avec le filtre, sans l'interface) dans une
## image de la taille choisie. Renvoie null sans rendu (serveur, tests).
func rendre(taille: Vector2i) -> Image:
	if DisplayServer.get_name() == "headless" or camera == null:
		return null
	var ecran := get_viewport().get_visible_rect().size
	var r := float(taille.x) / float(taille.y)
	var sv := SubViewport.new()
	sv.size = taille
	sv.world_3d = get_viewport().find_world_3d()
	sv.render_target_update_mode = SubViewport.UPDATE_ONCE
	sv.msaa_3d = get_viewport().msaa_3d
	sv.screen_space_aa = get_viewport().screen_space_aa
	sv.use_taa = false
	sv.positional_shadow_atlas_size = 4096
	var c := Camera3D.new()
	c.fov = fov_sortie(camera.fov, ecran, r)
	c.near = camera.near
	c.far = camera.far
	c.environment = camera.environment
	c.attributes = _attrs
	sv.add_child(c)
	if _filtre_rect.visible:
		var fr := ColorRect.new()
		fr.material = _materiau
		fr.size = Vector2(taille)
		sv.add_child(fr)
	add_child(sv)
	c.global_transform = camera.global_transform
	c.current = true
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = sv.get_texture().get_image() if is_instance_valid(sv) else null
	sv.queue_free()
	return img


## Prend la photo et l'enregistre en PNG. Renvoie le chemin (vide en cas d'échec).
func prendre_photo() -> String:
	if not actif or _en_capture:
		return ""
	_en_capture = true
	var ecran := get_viewport().get_visible_rect().size
	var r := rapport_format(format, ecran)
	var taille := taille_sortie(r, definition)
	_flash.color.a = 0.7
	create_tween().tween_property(_flash, "color:a", 0.0, 0.35)
	Son.jouer("ui_clic", 0.0, 0.0, "Interface")
	var img: Image = await rendre(taille)
	_en_capture = false
	if img == null or img.is_empty():
		message.emit("Photo impossible ici (pas d'affichage).")
		return ""
	var chemin := dossier_photos().path_join(nom_fichier(nom_lieu, Time.get_datetime_dict_from_system()))
	var err := img.save_png(chemin)
	if err != OK:
		message.emit("Photo non enregistrée : %s." % error_string(err))
		return ""
	derniere_photo = ProjectSettings.globalize_path(chemin)
	_toast("Photo enregistrée (%d × %d) : %s" % [taille.x, taille.y, derniere_photo])
	return derniere_photo


func ouvrir_dossier() -> void:
	OS.shell_open(ProjectSettings.globalize_path(dossier_photos()))


func _toast(t: String) -> void:
	message.emit(t)
	if _info != null:
		_info.text = t


# --- Panneau ---------------------------------------------------------------------

func _construire_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 111
	_layer.visible = false
	add_child(_layer)
	_guides = Control.new()
	_guides.set_anchors_preset(Control.PRESET_FULL_RECT)
	_guides.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_guides.draw.connect(_dessiner_guides)
	_guides.resized.connect(_guides.queue_redraw)
	_layer.add_child(_guides)
	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(1, 1, 1, 0)
	_layer.add_child(_flash)
	_panel = PanelContainer.new()
	UiStyle.style_panel(_panel)
	_panel.position = Vector2(12, 12)
	_panel.custom_minimum_size = Vector2(PANEL_W, 0)
	_layer.add_child(_panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 4)
	_panel.add_child(outer)
	var head := HBoxContainer.new()
	outer.add_child(head)
	var icon := TextureRect.new()
	icon.texture = Icones.get_icon("appareil_photo", 22, UiStyle.ACCENT)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	head.add_child(icon)
	var titre := Label.new()
	titre.text = "Mode photo"
	titre.add_theme_font_size_override("font_size", 16)
	titre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(titre)
	var x := UiStyle.icon_button("fermer", "Quitter le mode photo", "Échap", 18, 32)
	x.pressed.connect(quitter)
	head.add_child(x)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(PANEL_W, 560)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 3)
	scroll.add_child(body)

	_section(body, "Temps")
	_figer_box = CheckBox.new()
	_figer_box.text = "Figer le temps"
	_figer_box.button_pressed = figer
	_figer_box.focus_mode = Control.FOCUS_NONE
	_figer_box.tooltip_text = "Tout s'arrête : voitures, habitants, pluie. Pas sur une carte entre amis."
	_figer_box.toggled.connect(func(on: bool) -> void:
		figer = on
		_appliquer_figer())
	body.add_child(_figer_box)
	_heure_txt = Label.new()
	_heure_txt.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	_heure = _curseur(body, "Heure (lumière)", 0.0, 23.99, 0.25, 12.0, func(v: float) -> void: set_heure(v))
	body.add_child(_heure_txt)

	_section(body, "Caméra")
	_fov = _curseur(body, "Zoom (champ de vision, molette)", 8.0, 110.0, 1.0, 70.0, func(v: float) -> void:
		if camera != null:
			camera.fov = v
			_appliquer_camera())
	_curseur(body, "Pencher l'horizon", -35.0, 35.0, 0.5, 0.0, func(v: float) -> void:
		roulis = v
		_appliquer_camera())
	var fl := CheckBox.new()
	fl.text = "Flou de profondeur"
	fl.focus_mode = Control.FOCUS_NONE
	fl.toggled.connect(func(on: bool) -> void:
		flou = on
		_appliquer_camera())
	body.add_child(fl)
	_curseur(body, "Mise au point (m)", 2.0, 800.0, 1.0, mise_au_point, func(v: float) -> void:
		mise_au_point = v
		_appliquer_camera())
	_curseur(body, "Force du flou", 0.02, 0.4, 0.01, force_flou, func(v: float) -> void:
		force_flou = v
		_appliquer_camera())

	_section(body, "Filtre")
	var of := OptionButton.new()
	of.focus_mode = Control.FOCUS_NONE
	for f in FILTRES:
		of.add_item(String(f[0]), int(f[1]))
	of.item_selected.connect(func(i: int) -> void:
		filtre = of.get_item_id(i)
		_appliquer_filtre())
	body.add_child(of)
	_curseur(body, "Force du filtre", 0.0, 1.0, 0.05, 1.0, func(v: float) -> void:
		force = v
		_appliquer_filtre())
	_curseur(body, "Luminosité", -0.4, 0.4, 0.01, 0.0, func(v: float) -> void:
		luminosite = v
		_appliquer_filtre())
	_curseur(body, "Contraste", 0.6, 1.5, 0.01, 1.0, func(v: float) -> void:
		contraste = v
		_appliquer_filtre())
	_curseur(body, "Saturation", 0.0, 2.0, 0.02, 1.0, func(v: float) -> void:
		saturation = v
		_appliquer_filtre())
	_curseur(body, "Vignette", 0.0, 1.0, 0.02, 0.0, func(v: float) -> void:
		vignette = v
		_appliquer_filtre())
	_curseur(body, "Grain", 0.0, 1.0, 0.02, 0.0, func(v: float) -> void:
		grain = v
		_appliquer_filtre())

	_section(body, "Cadrage")
	var ofm := OptionButton.new()
	ofm.focus_mode = Control.FOCUS_NONE
	for f in FORMATS:
		ofm.add_item(String(f.nom))
	ofm.item_selected.connect(func(i: int) -> void:
		format = String(FORMATS[i].id)
		_guides.queue_redraw())
	body.add_child(ofm)
	var od := OptionButton.new()
	od.focus_mode = Control.FOCUS_NONE
	for d in DEFINITIONS:
		od.add_item(String(d[0]))
	od.item_selected.connect(func(i: int) -> void: definition = int(DEFINITIONS[i][1]))
	body.add_child(od)
	var gr := CheckBox.new()
	gr.text = "Grille des tiers"
	gr.focus_mode = Control.FOCUS_NONE
	gr.toggled.connect(func(on: bool) -> void:
		grille = on
		_guides.queue_redraw())
	body.add_child(gr)

	var photo := Button.new()
	photo.text = "Prendre la photo (Espace)"
	photo.icon = Icones.get_icon("appareil_photo", 20, UiStyle.ACCENT_INK)
	photo.focus_mode = Control.FOCUS_NONE
	photo.add_theme_stylebox_override("normal", UiStyle.flat_box(UiStyle.ACCENT, 9, 8))
	photo.add_theme_stylebox_override("hover", UiStyle.flat_box(UiStyle.ACCENT.lightened(0.15), 9, 8))
	photo.add_theme_color_override("font_color", UiStyle.ACCENT_INK)
	photo.add_theme_color_override("font_hover_color", UiStyle.ACCENT_INK)
	photo.pressed.connect(prendre_photo)
	outer.add_child(photo)
	var row := HBoxContainer.new()
	outer.add_child(row)
	for spec in [["Ouvrir le dossier", ouvrir_dossier], ["Time-lapse…", func() -> void:
			quitter()
			timelapse_requested.emit()]]:
		var b := Button.new()
		b.text = spec[0]
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(spec[1])
		row.add_child(b)
	var film := Button.new()
	film.text = "Filmer ce cadrage en time-lapse"
	film.tooltip_text = "Une caméra du time-lapse prend cette vue (une image par jour de jeu)."
	film.focus_mode = Control.FOCUS_NONE
	film.pressed.connect(func() -> void:
		if camera != null:
			var r := rapport_format(format, get_viewport().get_visible_rect().size)
			var f := "vertical" if r < 0.9 else ("carre" if r < 1.2 else "paysage")
			cadrage_timelapse.emit(camera.global_transform, fov_sortie(camera.fov, get_viewport().get_visible_rect().size, r), f))
	outer.add_child(film)
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size = Vector2(PANEL_W, 0)
	_info.add_theme_font_size_override("font_size", 12)
	_info.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	outer.add_child(_info)
	var aide := Label.new()
	aide.text = "ZQSD avancer · A/E descendre/monter · clic droit regarder · Maj vite · Ctrl lent · H masquer"
	aide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	aide.custom_minimum_size = Vector2(PANEL_W, 0)
	aide.add_theme_font_size_override("font_size", 11)
	aide.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	outer.add_child(aide)


func _section(parent: Control, t: String) -> void:
	var l := Label.new()
	l.text = t
	l.add_theme_color_override("font_color", UiStyle.ACCENT)
	l.add_theme_font_size_override("font_size", 14)
	parent.add_child(l)


func _curseur(parent: Control, t: String, mn: float, mx: float, pas: float, v: float, f: Callable) -> HSlider:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 12)
	parent.add_child(l)
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = pas
	s.value = v
	s.focus_mode = Control.FOCUS_NONE
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.value_changed.connect(f)
	parent.add_child(s)
	return s


func _dessiner_guides() -> void:
	var ecran := _guides.size
	var r := rapport_format(format, ecran)
	var c := rect_cadre(ecran, r)
	var ombre := Color(0, 0, 0, 0.55)
	if c.position.y > 0.5:
		_guides.draw_rect(Rect2(0, 0, ecran.x, c.position.y), ombre)
		_guides.draw_rect(Rect2(0, c.end.y, ecran.x, ecran.y - c.end.y), ombre)
	if c.position.x > 0.5:
		_guides.draw_rect(Rect2(0, 0, c.position.x, ecran.y), ombre)
		_guides.draw_rect(Rect2(c.end.x, 0, ecran.x - c.end.x, ecran.y), ombre)
	if format != "ecran":
		_guides.draw_rect(c, Color(1, 1, 1, 0.5), false, 1.5)
	if grille:
		var g := Color(1, 1, 1, 0.35)
		for i in [1, 2]:
			var xx: float = c.position.x + c.size.x * i / 3.0
			var yy: float = c.position.y + c.size.y * i / 3.0
			_guides.draw_line(Vector2(xx, c.position.y), Vector2(xx, c.end.y), g, 1.0)
			_guides.draw_line(Vector2(c.position.x, yy), Vector2(c.end.x, yy), g, 1.0)
