class_name MenuPrincipal
extends Node3D
## Écran titre et menu principal : une île low-poly qui tourne doucement, et à
## gauche le menu (Continuer, Nouvelle partie, Charger, Atelier, Options,
## Crédits, Quitter). C'est la scène de départ du jeu.

const SCENE := "res://scenes/menu_principal.tscn"
const TERRE := "res://scenes/terre.tscn"
const GLOBE := "res://scenes/globe.tscn"

const DEVISES := [
	"Le city builder où la Terre entière est ton chantier.",
	"Construire une ville, c'est facile. Trouver une place de parking, moins.",
	"Relief réel, habitants exigeants, budget limité. Bonne chance, Monsieur le Maire.",
	"Aucun nid-de-poule n'a été maltraité pendant le développement.",
	"Ici, les travaux finissent à l'heure. Enfin, presque.",
	"Bâtis, gère, et explique au conseil municipal pourquoi le pont mène dans un champ.",
	"1 m² par case, 510 millions de km² à aménager. On commence quand ?",
]

const CREDITS := "MiniBlocs, un jeu de Gaël, fait avec Godot Engine (MIT).\n\n" \
	+ "Relief : Mapzen Terrain Tiles (AWS Open Data) : SRTM, GMTED, ETOPO1, EU-DEM.\n" \
	+ "Biomes : © ESA WorldCover 2021 (CC BY 4.0).\n" \
	+ "Villes : GeoNames (CC BY 4.0). Drapeaux : flag-icons (MIT).\n" \
	+ "Recherche en ligne : © contributeurs OpenStreetMap (Nominatim).\n\n" \
	+ "Modèles, sons et musique : faits maison, en code.\n" \
	+ "Merci aux habitants virtuels, qui n'ont jamais demandé à naître dans un embouteillage."

var diorama: TitreDiorama
var camera: Camera3D
var _angle := 0.6
var _ui: CanvasLayer
var _menu: VBoxContainer
var _carte: PanelContainer
var _carte_img: TextureRect
var _carte_txt: Label
var _sub: Control
var _derniere := {}
var _boutons := {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	OptionsJeu.appliquer(get_tree())
	OptionsJeu.musique("menu")
	_rng.randomize()
	GameStart.atelier = false
	_scene_3d()
	_build_ui()
	_maj_camera(0.0)


func _process(delta: float) -> void:
	_maj_camera(delta)


func _maj_camera(delta: float) -> void:
	if not OptionsJeu.titre_fixe:
		_angle += delta * 0.035
	var r := 112.0
	camera.position = Vector3(sin(_angle) * r, 34.0 + sin(_angle * 0.7) * 4.0, cos(_angle) * r)
	camera.look_at(Vector3(0, -7.0, 0), Vector3.UP)


func _scene_3d() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("4f7fb8")
	sm.sky_horizon_color = Color("f0c89a")
	sm.ground_horizon_color = Color("e8c9a2")
	sm.ground_bottom_color = Color("6d86a8")
	sm.sun_angle_max = 20.0
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.05
	env.fog_enabled = true
	env.fog_light_color = Color("e8cfb0")
	env.fog_density = 0.0005
	env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("ffd8a6")
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 220.0
	sun.rotation_degrees = Vector3(-32.0, -50.0, 0.0)
	add_child(sun)
	diorama = TitreDiorama.new()
	diorama.name = "Diorama"
	add_child(diorama)
	camera = Camera3D.new()
	camera.fov = 42.0
	camera.far = 900.0
	# L'île à droite de l'écran : le menu occupe la gauche.
	camera.h_offset = -26.0
	add_child(camera)
	camera.current = true


# --- Interface ---------------------------------------------------------------------------

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	add_child(_ui)
	# Dégradé sombre à gauche pour que le menu se lise sur le ciel.
	var grad := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.03, 0.05, 0.05, 0.82))
	g.set_color(1, Color(0.03, 0.05, 0.05, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_to = Vector2(1, 0)
	gt.width = 256
	gt.height = 4
	grad.texture = gt
	grad.anchor_bottom = 1.0
	grad.offset_right = 720
	grad.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	grad.stretch_mode = TextureRect.STRETCH_SCALE
	grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(grad)

	var col := VBoxContainer.new()
	col.position = Vector2(80, 90)
	col.custom_minimum_size = Vector2(420, 0)
	col.add_theme_constant_override("separation", 6)
	_ui.add_child(col)
	var logo := Label.new()
	logo.text = "MiniBlocs"
	logo.add_theme_font_size_override("font_size", 76)
	logo.add_theme_color_override("font_color", UiStyle.ACCENT)
	logo.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	logo.add_theme_constant_override("shadow_offset_x", 3)
	logo.add_theme_constant_override("shadow_offset_y", 4)
	col.add_child(logo)
	var devise := Label.new()
	devise.name = "Devise"
	devise.text = String(DEVISES[_rng.randi() % DEVISES.size()])
	devise.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	devise.custom_minimum_size = Vector2(440, 0)
	devise.add_theme_font_size_override("font_size", 17)
	devise.add_theme_color_override("font_color", UiStyle.TEXT)
	col.add_child(devise)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 28)
	col.add_child(sp)

	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 8)
	col.add_child(_menu)
	_derniere = SaveGame.latest()
	if not _derniere.is_empty():
		var b := _bouton("continuer", "Continuer", "Reprendre « %s »" % String(_derniere.get("nom", _derniere.id)), continuer)
		b.mouse_entered.connect(func() -> void: _carte.visible = true)
	_bouton("nouvelle", "Nouvelle partie", "Choisir un lieu sur le globe, n'importe où sur Terre", nouvelle_partie)
	_bouton("charger", "Charger une partie", "Toutes les parties sauvegardées, avec leur aperçu", ouvrir_parties)
	_bouton("atelier", "Atelier", "Créer des bâtiments sur un terrain plat, sans habitants ni argent", ouvrir_atelier)
	_bouton("options", "Options", "Graphismes, son, sauvegarde automatique, touches", ouvrir_options)
	_bouton("credits", "Crédits", "Qui a fait quoi, et avec quelles données", ouvrir_credits)
	_bouton("quitter", "Quitter", "Fermer le jeu (les habitants ne t'en voudront pas… trop)", func() -> void: get_tree().quit())
	var first: Button = _boutons.get("continuer", _boutons.nouvelle)
	first.grab_focus.call_deferred()

	# Carte « dernière partie » à droite, en bas.
	_carte = PanelContainer.new()
	UiStyle.style_panel(_carte, 0.86, 12, 10)
	_carte.anchor_left = 1.0
	_carte.anchor_right = 1.0
	_carte.anchor_top = 1.0
	_carte.anchor_bottom = 1.0
	_carte.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_carte.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_carte.offset_right = -40
	_carte.offset_bottom = -48
	_ui.add_child(_carte)
	var cv := VBoxContainer.new()
	_carte.add_child(cv)
	var ct := Label.new()
	ct.text = "Dernière partie"
	ct.add_theme_color_override("font_color", UiStyle.ACCENT)
	cv.add_child(ct)
	_carte_img = TextureRect.new()
	_carte_img.custom_minimum_size = Vector2(320, 180)
	_carte_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_carte_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	cv.add_child(_carte_img)
	_carte_txt = Label.new()
	_carte_txt.add_theme_font_size_override("font_size", 13)
	_carte_txt.custom_minimum_size = Vector2(320, 0)
	_carte_txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cv.add_child(_carte_txt)
	_maj_carte()

	var version := Label.new()
	var ver := String(ProjectSettings.get_setting("application/config/version", ""))
	version.text = "Démo%s · Godot %s" % [" " + ver if ver != "" else "", Engine.get_version_info().string]
	version.add_theme_font_size_override("font_size", 12)
	version.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	version.anchor_top = 1.0
	version.anchor_bottom = 1.0
	version.grow_vertical = Control.GROW_DIRECTION_BEGIN
	version.offset_left = 80
	version.offset_bottom = -20
	_ui.add_child(version)


func _bouton(id: String, texte: String, aide: String, cb: Callable) -> Button:
	var b := Button.new()
	b.name = id
	b.text = texte
	b.tooltip_text = aide
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(340, 48)
	b.add_theme_font_size_override("font_size", 20)
	var n := UiStyle.flat_box(Color(0.06, 0.08, 0.07, 0.55), 10, 12)
	n.content_margin_left = 20
	var h := UiStyle.flat_box(Color(UiStyle.ACCENT, 0.92), 10, 12)
	h.content_margin_left = 26
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("focus", h)
	b.add_theme_stylebox_override("pressed", h)
	b.add_theme_color_override("font_hover_color", UiStyle.ACCENT_INK)
	b.add_theme_color_override("font_focus_color", UiStyle.ACCENT_INK)
	b.add_theme_color_override("font_pressed_color", UiStyle.ACCENT_INK)
	b.pressed.connect(cb)
	_menu.add_child(b)
	_boutons[id] = b
	return b


func _maj_carte() -> void:
	_derniere = SaveGame.latest()
	_carte.visible = not _derniere.is_empty()
	if _derniere.is_empty():
		return
	var tex := SaveGame.load_preview(String(_derniere.id))
	_carte_img.texture = tex
	_carte_img.visible = tex != null
	var res: Dictionary = _derniere.get("resume", {})
	var txt := "%s\n%s" % [String(_derniere.get("nom", _derniere.id)), PartiesPanel.format_date(int(_derniere.get("modifie", 0)))]
	if not res.is_empty():
		txt += "\n%d habitants · %d bâtiments" % [int(res.get("habitants", 0)), int(res.get("batiments", 0))]
	_carte_txt.text = txt


# --- Actions ----------------------------------------------------------------------------

func continuer() -> void:
	if not _derniere.is_empty():
		charger_partie(String(_derniere.id))


func nouvelle_partie() -> void:
	GameStart.slot_id = ""
	GameStart.load_slot = ""
	get_tree().change_scene_to_file(GLOBE)


## Ouvre une partie sauvegardée derrière l'écran de chargement.
func charger_partie(slot_id: String) -> void:
	var m := SaveGame.read_manifest(slot_id)
	if m.is_empty():
		return
	var lieu: Dictionary = m.get("lieu", {})
	GameStart.chosen = true
	GameStart.atelier = false
	GameStart.lat = float(lieu.get("lat", GameStart.lat))
	GameStart.lon = float(lieu.get("lon", GameStart.lon))
	GameStart.place_name = String(lieu.get("nom", ""))
	GameStart.load_slot = slot_id
	EcranChargement.aller(TERRE, String(m.get("nom", slot_id)))


func ouvrir_parties() -> void:
	if _sub != null:
		return
	var p := PartiesPanel.new(false)
	p.load_chosen.connect(charger_partie)
	p.closed.connect(func() -> void:
		_sub = null
		_maj_carte())
	_sub = p
	_ui.add_child(p)


func ouvrir_atelier() -> void:
	GameStart.atelier = true
	GameStart.retour_slot = ""
	EcranChargement.aller(TERRE, "Atelier")


func ouvrir_options() -> void:
	if _sub != null:
		return
	var o := OptionsPanel.new()
	o.closed.connect(func() -> void: _sub = null)
	_sub = o
	_ui.add_child(o)


func ouvrir_credits() -> void:
	if _sub != null:
		return
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.add_child(center)
	var p := PanelContainer.new()
	UiStyle.style_panel(p, 0.96, 12, 18)
	center.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	var t := Label.new()
	t.text = "Crédits"
	t.add_theme_font_size_override("font_size", 24)
	v.add_child(t)
	var l := Label.new()
	l.text = CREDITS
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(560, 0)
	v.add_child(l)
	var close := Button.new()
	close.text = "Fermer"
	close.pressed.connect(func() -> void:
		_sub = null
		c.queue_free())
	v.add_child(close)
	close.grab_focus.call_deferred()
	_sub = c
	_ui.add_child(c)


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.keycode == KEY_ESCAPE and _sub != null and not (_sub is OptionsPanel or _sub is PartiesPanel):
		get_viewport().set_input_as_handled()
		_sub.queue_free()
		_sub = null
