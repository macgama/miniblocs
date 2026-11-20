extends Node3D
## Écran de départ : un globe 3D coloré par le vrai relief.
## Le joueur cherche la ville de son premier village (135 000 villes du monde,
## ou des coordonnées, ou un clic sur la Terre), voit un aperçu du relief, puis
## commence sa partie.

## Pour les tests : pas de réseau, planète synthétique.
@export var offline := false

const GLOBE_ZOOM := 3 # 8 × 8 tuiles, assemblées en une texture de 2048 × 2048
const MIN_DIST := 1.18
const MAX_DIST := 4.0

var view_lat := 46.0
var view_lon := 7.0
var distance := 2.6
var selected := false
var sel_lat := 0.0
var sel_lon := 0.0
var sel_name := ""
## Pays du lieu choisi (code ISO en minuscules) : drapeau proposé au village.
var sel_pays := ""

var _target_dist := 2.6
var _globe: MeshInstance3D
var _globe_mat: ShaderMaterial
var _marker: Node3D
var _camera: Camera3D
var _globe_tiles: ElevationTiles
var _detail_tiles: ElevationTiles
var _planet: Image
var _biome_tex: Texture2D
var _biome_img: Image
var _press_pos := Vector2.ZERO
var _pressing := false
var _dragged := false
var _tween: Tween

# Interface
var _search: LineEdit
var _list: ItemList
var _loading_label: Label
var _place_label: Label
var _detail_label: Label
## Réglages de la nouvelle partie (bouton « Réglages avancés… »).
var _settings_label: Label
var _settings_panel: AdminPanel
## Bouton Suivant, puis « Commencer la partie » à la dernière étape.
var _start_btn: Button
## Résultats affichés dans la liste ({nom, pays, pays_nom, pop, lat, lon}).
var _filtered: Array = []
var _search_timer: Timer
var _online_btn: Button
var _online: HTTPRequest

# Assistant de nouvelle partie : une étape à la fois.
const ETAPES := ["Lieu", "Type de carte", "Réglages", "Tutoriel", "Résumé"]
const ETAPES_TITRES := ["Où fonder ton village ?", "Seul ou à plusieurs ?", "Quelle partie veux-tu ?",
	"Un coup de main pour commencer ?", "Prêt à fonder ta ville ?"]
const LARGEUR_ASSISTANT := 430.0
## Préréglages proposés, avec leur phrase.
const DIFFICULTES := {
	"facile": "Facile : 100 M€, constructions à moitié prix, tout débloqué, pas d'épuisement des ressources.",
	"normal": "Normal : 30 M€, prix réels, arbre de progression, ressources qui s'épuisent.",
	"difficile": "Difficile : 5 M€, constructions deux fois plus chères, impôts plus bas, salaires plus hauts.",
	"libre": "Bac à sable libre : argent illimité, tout débloqué, pas de route ni de réseaux obligatoires.",
}
const ARGENTS := [1_000_000, 5_000_000, 10_000_000, 30_000_000, 100_000_000]
## [année (0 : aujourd'hui, -1 : autre année), nom].
const EPOQUES := [[0, "Aujourd'hui : tout est déjà inventé"], [1800, "1800 : diligences, puits et lampes à huile"],
	[1850, "1850 : vapeur et chemin de fer"], [1900, "1900 : tramways et premières lignes électriques"],
	[1950, "1950 : voitures et grands ensembles"], [-1, "Autre année…"]]

var etape := 0
var mode_carte: int = GameStart.Mode.BAC_A_SABLE
var _ui: CanvasLayer
var _left: Control
var _assistant: PanelContainer
var _credit: Label
var _defilement: ScrollContainer
var _pages: Array[VBoxContainer] = []
var _etape_btns: Array[Button] = []
var _etape_label: Label
var _titre_etape: Label
var _prev_btn: Button
var _mode_btns: Array[Button] = []
var _amis_box: VBoxContainer
var _pseudo_edit: LineEdit
var _amis_panel: MultijoueurPanel
var _preset_btns := {}
var _preset_info: Label
var _epoque_opt: ChoixVisuel
var _vignettes: Vignettes
## Véhicule du jeu qui illustre chaque époque de départ ("" : dessin).
const EPOQUES_VEHICULES := ["electrique", "diligence_messageries", "loco_crampton", "tram_1900", "populaire_ronde", ""]
var _epoque_ligne: Control
var _annee_spin: SpinBox
var _rythme_opt: ChoixVisuel
var _epoque_info: Label
## « Autre année… » choisie : l'année se tape dans la case.
var _epoque_autre := false
var _argent_opt: ChoixVisuel
var _options := {}
var _remplissage := false
var _tuto_oui: Button
var _tuto_non: Button
var _tuto_note: Label
var _objectifs_check: CheckBox
var _resume_box: GridContainer
var _resume_note: Label


var _continue_btn: Button
var _saves_panel: PartiesPanel


func _ready() -> void:
	Son.ici()
	_camera = Camera3D.new()
	_camera.fov = 40.0
	_camera.near = 0.01
	add_child(_camera)

	_globe = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 128
	sphere.rings = 64
	_globe.mesh = sphere
	_globe_mat = ShaderMaterial.new()
	_globe_mat.shader = preload("res://scripts/terre/globe.gdshader")
	_biome_tex = load("res://assets/biomes_monde.png")
	if _biome_tex:
		_globe_mat.set_shader_parameter("biomes", _biome_tex)
		_globe_mat.set_shader_parameter("has_biomes", true)
		_biome_img = _biome_tex.get_image()
	_globe.material_override = _globe_mat
	add_child(_globe)

	var atmo := MeshInstance3D.new()
	var atmo_mesh := SphereMesh.new()
	atmo_mesh.radius = 1.035
	atmo_mesh.height = 2.07
	atmo_mesh.radial_segments = 96
	atmo_mesh.rings = 48
	atmo.mesh = atmo_mesh
	var am := ShaderMaterial.new()
	am.shader = preload("res://scripts/terre/atmosphere.gdshader")
	atmo.material_override = am
	atmo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(atmo)

	_marker = _make_marker()
	_marker.visible = false
	_globe.add_child(_marker)

	_build_ui()
	_apply_view()

	_detail_tiles = ElevationTiles.new()
	add_child(_detail_tiles)
	_detail_tiles.tile_ready.connect(func(_t: Vector2i) -> void: _update_detail())

	if offline:
		_detail_tiles.offline_generator = func(_t: Vector2i) -> PackedFloat32Array:
			var a := PackedFloat32Array()
			a.resize(256 * 256)
			a.fill(500.0)
			return a
		_set_planet(_synthetic_planet())
	else:
		_globe_tiles = ElevationTiles.new()
		_globe_tiles.zoom = GLOBE_ZOOM
		_globe_tiles.keep_images = true
		add_child(_globe_tiles)
		_globe_tiles.tile_ready.connect(func(_t: Vector2i) -> void: _check_globe_tiles())
		var n := 1 << GLOBE_ZOOM
		for x in n:
			for y in n:
				_globe_tiles.request_tile(Vector2i(x, y))
		_check_globe_tiles()

	if GameStart.chosen:
		select_place(GameStart.lat, GameStart.lon, GameStart.place_name, true, GameStart.pays)


# --- Planète --------------------------------------------------------------

func _check_globe_tiles() -> void:
	if _planet != null:
		return
	var n := 1 << GLOBE_ZOOM
	var count := _globe_tiles.loaded_count()
	if count < n * n:
		_loading_label.text = "Chargement de la planète… %d / %d" % [count, n * n]
		return
	var img := Image.create(256 * n, 256 * n, false, Image.FORMAT_RGB8)
	for x in n:
		for y in n:
			var tile := _globe_tiles.get_image(Vector2i(x, y))
			if tile != null and tile.get_width() == 256:
				img.blit_rect(tile, Rect2i(0, 0, 256, 256), Vector2i(x * 256, y * 256))
			else:
				img.fill_rect(Rect2i(x * 256, y * 256, 256, 256), Color8(127, 255, 0)) # -1 m
	_set_planet(img)


func _set_planet(img: Image) -> void:
	_planet = img
	_globe_mat.set_shader_parameter("merc", ImageTexture.create_from_image(img))
	_globe_mat.set_shader_parameter("has_data", true)
	_loading_label.text = ""


## Planète de test : un continent entre 36° O et 72° E, océan ailleurs.
func _synthetic_planet() -> Image:
	var img := Image.create(256, 256, false, Image.FORMAT_RGB8)
	img.fill(Color8(127, 0, 0)) # -256 m
	img.fill_rect(Rect2i(102, 0, 77, 256), Color8(129, 244, 0)) # 500 m
	return img


## Altitude grossière (≈ 20 km par pixel) lue sur la texture du globe.
func planet_height(lat: float, lon: float) -> float:
	if _planet == null:
		return NAN
	var w := _planet.get_width()
	var px := clampi(int((lon + 180.0) / 360.0 * w), 0, w - 1)
	var py := clampi(int(Geo.lat_to_pixel_y(lat, 0) / 256.0 * w), 0, w - 1)
	var c := _planet.get_pixel(px, py)
	return c.r8 * 256.0 + c.g8 + c.b8 / 256.0 - 32768.0


const BIOME_NAMES := {10: "Forêt", 20: "Broussailles", 30: "Prairie", 40: "Champs", 50: "Prairie",
	60: "Désert ou roche", 70: "Glacier", 80: "Lacs et rivières", 90: "Marais", 95: "Mangrove", 100: "Toundra"}


## Biome dominant (≈ 10 km) autour d'un point, d'après la carte mondiale.
func planet_biome(lat: float, lon: float) -> String:
	if _biome_img == null:
		return ""
	var w := _biome_img.get_width()
	var hgt := _biome_img.get_height()
	var x := clampi(int((lon + 180.0) / 360.0 * w), 0, w - 1)
	var y := clampi(int((90.0 - lat) / 180.0 * hgt), 0, hgt - 1)
	var code := roundi(_biome_img.get_pixel(x, y).r * 255.0)
	return BIOME_NAMES.get(code, "")


# --- Géométrie du globe -----------------------------------------------------

static func lat_lon_to_point(lat: float, lon: float) -> Vector3:
	var la := deg_to_rad(lat)
	var lo := deg_to_rad(lon)
	return Vector3(cos(la) * sin(lo), sin(la), cos(la) * cos(lo))


static func point_to_lat_lon(p: Vector3) -> Vector2:
	var n := p.normalized()
	return Vector2(rad_to_deg(asin(clampf(n.y, -1.0, 1.0))), rad_to_deg(atan2(n.x, n.z)))


func _apply_view() -> void:
	_globe.basis = Basis(Vector3.RIGHT, deg_to_rad(view_lat)) * Basis(Vector3.UP, deg_to_rad(-view_lon))
	_camera.position = Vector3(0.0, 0.0, distance)
	_camera.look_at(Vector3.ZERO, Vector3.UP)
	var s := clampf((distance - 1.0) * 0.6, 0.04, 1.0)
	_marker.scale = Vector3.ONE * s


## Point du globe sous la souris, en (lat, lon), ou null.
func pick(screen_pos: Vector2) -> Variant:
	var o := _camera.project_ray_origin(screen_pos)
	var d := _camera.project_ray_normal(screen_pos)
	var b := o.dot(d)
	var c := o.length_squared() - 1.0
	var disc := b * b - c
	if disc < 0.0:
		return null
	var t := -b - sqrt(disc)
	if t < 0.0:
		return null
	var local := _globe.global_transform.basis.inverse() * (o + d * t)
	return point_to_lat_lon(local)


func _process(delta: float) -> void:
	if not is_equal_approx(distance, _target_dist):
		distance = lerpf(distance, _target_dist, clampf(delta * 8.0, 0.0, 1.0))
		_apply_view()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_target_dist = clampf(1.0 + (_target_dist - 1.0) * 0.85, MIN_DIST, MAX_DIST)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_target_dist = clampf(1.0 + (_target_dist - 1.0) / 0.85, MIN_DIST, MAX_DIST)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_pressing = true
				_dragged = false
				_press_pos = mb.position
			else:
				_pressing = false
				if not _dragged:
					var ll: Variant = pick(mb.position)
					if ll != null:
						select_place(ll.x, ll.y, "")
	elif event is InputEventMouseMotion and _pressing:
		var mm := event as InputEventMouseMotion
		if mm.position.distance_to(_press_pos) > 4.0:
			_dragged = true
		if _dragged:
			if _tween:
				_tween.kill()
			var k := (distance - 1.0) * 0.12
			view_lon = wrapf(view_lon - mm.relative.x * k, -180.0, 180.0)
			view_lat = clampf(view_lat + mm.relative.y * k, -80.0, 80.0)
			_apply_view()


func back_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/menu_principal.tscn")


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.keycode == KEY_ESCAPE and _saves_panel == null and _settings_panel == null \
			and _amis_panel == null:
		get_viewport().set_input_as_handled()
		back_to_menu()


## Tourne le globe pour amener (lat, lon) face à la caméra.
func fly_to(lat: float, lon: float, dist: float, instant := false) -> void:
	var target_lon := view_lon + wrapf(lon - view_lon, -180.0, 180.0)
	var target_lat := clampf(lat, -80.0, 80.0)
	_target_dist = dist
	if instant:
		view_lat = target_lat
		view_lon = wrapf(target_lon, -180.0, 180.0)
		distance = dist
		_apply_view()
		return
	if _tween:
		_tween.kill()
	var start_lat := view_lat
	var start_lon := view_lon
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_method(func(t: float) -> void:
		view_lat = lerpf(start_lat, target_lat, t)
		view_lon = wrapf(lerpf(start_lon, target_lon, t), -180.0, 180.0)
		_apply_view(), 0.0, 1.0, 0.9)


# --- Sélection --------------------------------------------------------------

func select_place(lat: float, lon: float, place_name: String, instant := false, pays := "") -> void:
	# Clic sur la Terre : la ville la plus proche donne le nom et le pays.
	if place_name == "" and pays == "":
		var v := Villes.plus_proche(lat, lon)
		if not v.is_empty():
			place_name = "Près de %s, %s" % [v.nom, v.pays_nom]
			pays = String(v.pays)
	selected = true
	sel_pays = pays
	sel_lat = lat
	sel_lon = wrapf(lon, -180.0, 180.0)
	sel_name = place_name
	var p := lat_lon_to_point(sel_lat, sel_lon)
	_marker.transform = Transform3D(Basis(Quaternion(Vector3.UP, p)), p)
	_apply_view()
	_marker.visible = true
	if place_name != "":
		fly_to(sel_lat, sel_lon, minf(_target_dist, 1.7), instant)
	_place_label.text = (place_name + "\n" if place_name != "" else "") + _format_lat_lon(sel_lat, sel_lon)
	_maj_navigation()
	var px := Geo.lon_to_pixel_x(sel_lon, ElevationTiles.ZOOM)
	var py := Geo.lat_to_pixel_y(sel_lat, ElevationTiles.ZOOM)
	_detail_tiles.request_tile(ElevationTiles.tile_of_pixel(px, py))
	_update_detail()


static func _format_lat_lon(lat: float, lon: float) -> String:
	return "%.4f° %s, %.4f° %s" % [absf(lat), "N" if lat >= 0.0 else "S", absf(lon), "E" if lon >= 0.0 else "O"]


## Résumé du relief autour du point choisi (tuile d'environ 1 km).
func describe_selection() -> Dictionary:
	var px := Geo.lon_to_pixel_x(sel_lon, ElevationTiles.ZOOM)
	var py := Geo.lat_to_pixel_y(sel_lat, ElevationTiles.ZOOM)
	var t := ElevationTiles.tile_of_pixel(px, py)
	if not _detail_tiles.has_tile(t):
		return {}
	var h := _detail_tiles.height_at(px, py)
	var arr: PackedFloat32Array = _detail_tiles._tiles[t]
	var lo := INF
	var hi := -INF
	var water := 0
	for v in arr:
		lo = minf(lo, v)
		hi = maxf(hi, v)
		if v < 0.0:
			water += 1
	var kind := "Plaine"
	if h < 0.0:
		kind = "Mer ou océan"
	elif water > 0 and water < arr.size():
		kind = "Côte"
	elif hi - lo > 300.0:
		kind = "Montagne"
	elif hi - lo > 60.0:
		kind = "Collines"
	return {"height": h, "min": lo, "max": hi, "kind": kind}


func _update_detail() -> void:
	if not selected:
		return
	var d := describe_selection()
	if d.is_empty():
		_detail_label.text = "Lecture du relief…"
		return
	var txt := "Altitude : %d m\nRelief : %s (de %d à %d m sur ~1 km)" % [roundi(d.height), d.kind, roundi(d.min), roundi(d.max)]
	var biome := planet_biome(sel_lat, sel_lon)
	if biome != "" and d.height >= 0.0:
		txt += "\nBiome dominant : " + biome
	if d.height < 0.0:
		txt += "\nAttention : tu commenceras sous l'eau."
	txt += "\nRégion de jeu : %d × %d km" % [int(GameStart.REGION_SIZE / 1000.0), int(GameStart.REGION_SIZE / 1000.0)]
	_detail_label.text = txt


func start_game() -> void:
	if not selected:
		return
	GameStart.chosen = true
	GameStart.lat = sel_lat
	GameStart.lon = sel_lon
	GameStart.place_name = sel_name
	GameStart.pays = sel_pays
	GameStart.load_slot = ""
	GameStart.slot_id = ""
	if mode_carte == GameStart.Mode.ENTRE_AMIS:
		heberger_nouvelle_carte()
		return
	GameStart.mode = GameStart.Mode.BAC_A_SABLE
	EcranChargement.aller("res://scenes/terre.tscn", sel_name if sel_name != "" else "Nouvelle partie")


## Entre amis : le serveur de la nouvelle carte démarre sur ce PC (un processus
## à part, avec le lieu et les réglages choisis), puis on y entre en créateur.
func heberger_nouvelle_carte() -> void:
	var r := ReglagesPartie.prochaine.duplicate_settings()
	r.tutoriel = false
	var p := ouvrir_amis()
	var pid := Multijoueur.lancer_nouvelle_carte(sel_lat, sel_lon, sel_name, sel_pays, r, Protocole.PORT_DEFAUT)
	p.attendre_serveur_local(pid, Protocole.PORT_DEFAUT, _pseudo_edit.text if _pseudo_edit != null else "")


## Panneau des réglages de la nouvelle partie (le même que le panneau Admin).
func open_settings(ui: CanvasLayer) -> void:
	if _settings_panel != null:
		return
	GameStart.mode = mode_carte as GameStart.Mode
	_settings_panel = AdminPanel.new(ReglagesPartie.prochaine, true, true)
	_settings_panel.settings_changed.connect(_remplir_reglages)
	_settings_panel.closed.connect(func() -> void:
		_settings_panel = null
		_remplir_reglages())
	ui.add_child(_settings_panel)


func _update_settings_label() -> void:
	if _settings_label and ReglagesPartie.prochaine != null:
		_settings_label.text = "Réglages : " + ReglagesPartie.prochaine.summary()


## Ouvre l'atelier (retour au globe en le quittant).
func open_atelier() -> void:
	GameStart.atelier = true
	GameStart.retour_slot = ""
	EcranChargement.aller("res://scenes/terre.tscn", "Atelier")


## Ouvre une partie sauvegardée dans la scène Terre.
func load_saved_game(slot_id: String) -> void:
	var m := SaveGame.read_manifest(slot_id)
	if m.is_empty():
		return
	var lieu: Dictionary = m.get("lieu", {})
	GameStart.chosen = true
	GameStart.lat = float(lieu.get("lat", GameStart.lat))
	GameStart.lon = float(lieu.get("lon", GameStart.lon))
	GameStart.place_name = String(lieu.get("nom", ""))
	GameStart.load_slot = slot_id
	EcranChargement.aller("res://scenes/terre.tscn", String(m.get("nom", slot_id)))


func _open_saves(ui: CanvasLayer) -> void:
	if _saves_panel != null:
		return
	_saves_panel = PartiesPanel.new(false)
	ui.add_child(_saves_panel)
	_saves_panel.closed.connect(func() -> void: _saves_panel = null)
	_saves_panel.load_chosen.connect(load_saved_game)


# --- Interface --------------------------------------------------------------

func _make_marker() -> Node3D:
	var root := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("ff5a3c")
	mat.emission_enabled = true
	mat.emission = Color("ff5a3c")
	mat.emission_energy_multiplier = 0.6
	var stick := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.004
	cyl.bottom_radius = 0.004
	cyl.height = 0.08
	stick.mesh = cyl
	stick.position.y = 0.04
	stick.material_override = mat
	root.add_child(stick)
	var head := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.016
	ball.height = 0.032
	head.mesh = ball
	head.position.y = 0.085
	head.material_override = mat
	root.add_child(head)
	return root


func _panel_label(text: String, size := 14, alpha := 1.0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(1, 1, 1, alpha))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _build_ui() -> void:
	var ui := CanvasLayer.new()
	_ui = ui
	add_child(ui)
	if ReglagesPartie.prochaine == null:
		ReglagesPartie.prochaine = ReglagesPartie.load_defaults()

	# Étape 1, panneau de gauche : recherche du lieu.
	var left := PanelContainer.new()
	left.position = Vector2(16, 16)
	left.custom_minimum_size = Vector2(340, 0)
	ui.add_child(left)
	_left = left
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 8)
	left.add_child(lv)
	lv.add_child(_panel_label("MiniBlocs", 30))
	lv.add_child(_panel_label("Cherche la ville de ton premier village.", 15, 0.85))
	_search = LineEdit.new()
	_search.placeholder_text = "Nom d'une ville, ou coordonnées…"
	_search.clear_button_enabled = true
	_search.right_icon = Icones.get_icon("chercher", 18)
	_search_timer = Timer.new()
	_search_timer.one_shot = true
	_search_timer.wait_time = 0.25
	_search_timer.timeout.connect(_refresh_list)
	add_child(_search_timer)
	_search.text_changed.connect(func(_t: String) -> void: _search_timer.start())
	_search.text_submitted.connect(func(_t: String) -> void:
		_refresh_list()
		if not _filtered.is_empty():
			_choose(0))
	lv.add_child(_search)
	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(0, 300)
	_list.fixed_icon_size = Vector2i(24, 18)
	_list.item_selected.connect(_choose)
	lv.add_child(_list)
	_online_btn = Button.new()
	_online_btn.text = "Chercher en ligne (petits villages, lieux-dits…)"
	_online_btn.tooltip_text = "Recherche OpenStreetMap (Nominatim) : tous les lieux du monde, il faut Internet"
	_online_btn.visible = false
	_online_btn.pressed.connect(_search_online)
	lv.add_child(_online_btn)
	_refresh_list()
	lv.add_child(_panel_label("Glisser : tourner la Terre   ·   Molette : zoom   ·   Clic : choisir", 12, 0.7))
	_loading_label = _panel_label("", 13, 0.9)
	lv.add_child(_loading_label)

	# Les étapes, en haut au milieu (un clic revient à une étape déjà vue).
	var top := PanelContainer.new()
	UiStyle.style_panel(top, 0.85, 10, 6)
	top.anchor_left = 0.5
	top.anchor_right = 0.5
	top.grow_horizontal = Control.GROW_DIRECTION_BOTH
	top.offset_top = 16
	ui.add_child(top)
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 4)
	top.add_child(th)
	for i in ETAPES.size():
		if i > 0:
			var fl := _panel_label("›", 18, 0.5)
			fl.autowrap_mode = TextServer.AUTOWRAP_OFF
			fl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			fl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			th.add_child(fl)
		var b := Button.new()
		b.text = "%d · %s" % [i + 1, ETAPES[i]]
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_stylebox_override("normal", UiStyle.flat_box(Color(0, 0, 0, 0)))
		b.add_theme_stylebox_override("disabled", UiStyle.flat_box(Color(0, 0, 0, 0)))
		b.add_theme_stylebox_override("hover", UiStyle.flat_box(Color(1, 1, 1, 0.12)))
		UiStyle.tint_pressed(b, UiStyle.ACCENT, UiStyle.ACCENT_INK)
		var idx := i
		b.pressed.connect(func() -> void: aller_a(idx))
		th.add_child(b)
		_etape_btns.append(b)

	# L'assistant, à droite : titre, page de l'étape (qui défile), Précédent / Suivant.
	var right := PanelContainer.new()
	UiStyle.style_panel(right, 0.9, 12, 14)
	right.anchor_left = 1.0
	right.anchor_right = 1.0
	right.anchor_bottom = 1.0
	right.offset_left = -16 - LARGEUR_ASSISTANT
	right.offset_right = -16
	right.offset_top = 70
	right.offset_bottom = -40
	ui.add_child(right)
	_assistant = right
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 10)
	right.add_child(rv)
	_etape_label = _panel_label("", 13, 0.7)
	rv.add_child(_etape_label)
	_titre_etape = _panel_label("", 22)
	_titre_etape.add_theme_color_override("font_color", UiStyle.ACCENT)
	rv.add_child(_titre_etape)
	var sc := ScrollContainer.new()
	sc.name = "Defilement"
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.follow_focus = true
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rv.add_child(sc)
	_defilement = sc
	var pages := VBoxContainer.new()
	pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(pages)
	for f in [_page_lieu, _page_carte, _page_reglages, _page_tutoriel, _page_resume]:
		var p := VBoxContainer.new()
		p.add_theme_constant_override("separation", 10)
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pages.add_child(p)
		(f as Callable).call(p)
		_pages.append(p)
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 8)
	rv.add_child(nav)
	_prev_btn = Button.new()
	_prev_btn.text = "◂ Précédent"
	_prev_btn.custom_minimum_size = Vector2(130, 44)
	_prev_btn.pressed.connect(precedent)
	nav.add_child(_prev_btn)
	_start_btn = Button.new()
	_start_btn.custom_minimum_size = Vector2(0, 44)
	_start_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_start_btn.add_theme_font_size_override("font_size", 17)
	_start_btn.add_theme_stylebox_override("normal", UiStyle.flat_box(UiStyle.ACCENT))
	_start_btn.add_theme_stylebox_override("hover", UiStyle.flat_box(UiStyle.ACCENT.lightened(0.15)))
	_start_btn.add_theme_stylebox_override("pressed", UiStyle.flat_box(UiStyle.ACCENT.darkened(0.1)))
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		_start_btn.add_theme_color_override(k, UiStyle.ACCENT_INK)
	_start_btn.pressed.connect(suivant)
	nav.add_child(_start_btn)

	# Parties sauvegardées : reprendre la dernière, ou choisir dans la liste (en bas à gauche).
	var saves := SaveGame.list_saves()
	var bas := PanelContainer.new()
	UiStyle.style_panel(bas, 0.85, 10, 6)
	bas.anchor_top = 1.0
	bas.anchor_bottom = 1.0
	bas.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bas.offset_left = 16
	bas.offset_bottom = -16
	ui.add_child(bas)
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 6)
	bas.add_child(srow)
	_continue_btn = Button.new()
	_continue_btn.custom_minimum_size = Vector2(0, 36)
	if saves.is_empty():
		_continue_btn.text = "Aucune partie sauvegardée"
		_continue_btn.disabled = true
	else:
		var nom_partie := String(saves[0].get("nom", saves[0].id))
		if nom_partie.length() > 36:
			nom_partie = nom_partie.substr(0, 35) + "…"
		_continue_btn.text = "Continuer : " + nom_partie
		_continue_btn.tooltip_text = PartiesPanel.format_date(int(saves[0].get("modifie", 0)))
		var last_id := String(saves[0].id)
		_continue_btn.pressed.connect(func() -> void: load_saved_game(last_id))
	srow.add_child(_continue_btn)
	var all_btn := Button.new()
	all_btn.text = "Parties…"
	all_btn.pressed.connect(func() -> void: _open_saves(ui))
	srow.add_child(all_btn)
	var atelier_btn := Button.new()
	atelier_btn.text = "Atelier"
	atelier_btn.icon = Icones.get_icon("atelier", 18)
	atelier_btn.tooltip_text = "Créer et personnaliser des bâtiments sur un terrain plat, sans habitants ni argent, et les ranger dans la banque de modèles."
	atelier_btn.pressed.connect(open_atelier)
	srow.add_child(atelier_btn)

	var back := Button.new()
	back.text = "Menu principal"
	back.tooltip_text = "Retour à l'écran titre (Échap)"
	back.anchor_left = 1.0
	back.anchor_right = 1.0
	back.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	back.offset_right = -16
	back.offset_top = 16
	back.pressed.connect(back_to_menu)
	ui.add_child(back)

	var credit := _panel_label("Relief : Mapzen Terrain Tiles (AWS Open Data) — SRTM, GMTED, ETOPO1, EU-DEM · Biomes : © ESA WorldCover 2021 (CC BY 4.0) · Villes : GeoNames (CC BY 4.0) · Drapeaux : flag-icons (MIT)", 11, 0.6)
	credit.autowrap_mode = TextServer.AUTOWRAP_OFF
	credit.anchor_left = 1.0
	credit.anchor_right = 1.0
	credit.anchor_top = 1.0
	credit.anchor_bottom = 1.0
	credit.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	credit.grow_vertical = Control.GROW_DIRECTION_BEGIN
	credit.offset_right = -16
	credit.offset_bottom = -12
	ui.add_child(credit)
	_credit = credit

	_remplir_reglages()
	aller_a(0)


# --- Assistant de nouvelle partie --------------------------------------------

## Étape suivante (ou, à la dernière, commencer la partie).
func suivant() -> void:
	if etape >= ETAPES.size() - 1:
		start_game()
	else:
		aller_a(etape + 1)


func precedent() -> void:
	aller_a(etape - 1)


## Étape la plus loin qu'on peut atteindre : tant qu'aucun lieu n'est choisi, la première.
func etape_max() -> int:
	return ETAPES.size() - 1 if selected else 0


func aller_a(i: int) -> void:
	etape = clampi(i, 0, etape_max())
	for k in _pages.size():
		_pages[k].visible = k == etape
	if _left != null:
		_left.visible = etape == 0
	if etape == ETAPES.size() - 1:
		_maj_resume()
	if etape == 2:
		_remplir_reglages()
	if etape == 3:
		_maj_tutoriel()
	if _defilement != null:
		_defilement.scroll_vertical = 0
	_maj_navigation()


func _maj_navigation() -> void:
	if _start_btn == null:
		return
	_etape_label.text = "Étape %d sur %d" % [etape + 1, ETAPES.size()]
	_titre_etape.text = ETAPES_TITRES[etape]
	for k in _etape_btns.size():
		_etape_btns[k].set_pressed_no_signal(k == etape)
		_etape_btns[k].disabled = k > etape_max()
	_prev_btn.disabled = etape == 0
	if etape < ETAPES.size() - 1:
		_start_btn.text = "Suivant ▸"
		_start_btn.disabled = etape == 0 and not selected
	else:
		_start_btn.text = "Créer la carte et la rejoindre" if mode_carte == GameStart.Mode.ENTRE_AMIS else "Commencer la partie"
		_start_btn.disabled = not selected


func _titre_section(parent: Control, texte: String, icone := "") -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	if icone != "":
		var ic := TextureRect.new()
		ic.texture = Icones.get_icon(icone, 18, UiStyle.ACCENT)
		ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		h.add_child(ic)
	var l := _panel_label(texte, 16)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.add_theme_color_override("font_color", UiStyle.ACCENT)
	h.add_child(l)
	parent.add_child(h)


## Grand bouton à choisir (titre + une phrase), dans un groupe.
func _carte_choix(parent: Control, titre: String, texte: String, groupe: ButtonGroup, icone := "") -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.button_group = groupe
	b.text = titre + "\n" + texte
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(0, 64)
	b.focus_mode = Control.FOCUS_NONE
	if icone != "":
		b.icon = Icones.get_icon(icone, 24)
		b.expand_icon = false
	UiStyle.tint_pressed(b, UiStyle.ACCENT, UiStyle.ACCENT_INK)
	parent.add_child(b)
	return b


func _page_lieu(p: VBoxContainer) -> void:
	_place_label = _panel_label("Cherche une ville à gauche, ou clique sur la Terre.", 15, 0.95)
	p.add_child(_place_label)
	_detail_label = _panel_label("", 13, 0.8)
	p.add_child(_detail_label)
	p.add_child(_panel_label("Ta région de jeu fera 40 × 40 km autour de ce point, avec le vrai relief. Tu pourras fonder d'autres villes plus tard.", 12, 0.65))


func _page_carte(p: VBoxContainer) -> void:
	var g := ButtonGroup.new()
	_mode_btns.clear()
	_mode_btns.append(_carte_choix(p, "Seul (bac à sable)", "Ta carte, hors ligne. Tu es maire et admin : tu règles tout.", g, "construire"))
	_mode_btns.append(_carte_choix(p, "Entre amis", "Une carte sur invitation, hébergée sur ce PC. Chacun a sa caisse et fonde ses villes.", g, "habitants"))
	_mode_btns.append(_carte_choix(p, "Carte mondiale (bientôt)", "Une seule Terre pour tous les joueurs. Elle ouvrira avec un serveur en ligne.", g, "globe"))
	_mode_btns[2].disabled = true
	if EditionDemo.active():
		_mode_btns[1].disabled = true
		_mode_btns[1].tooltip_text = "La carte entre amis est dans le jeu complet."
	for i in _mode_btns.size():
		var m := i
		_mode_btns[i].toggled.connect(func(on: bool) -> void:
			if on:
				choisir_mode(m))
	_mode_btns[0].set_pressed_no_signal(true)
	_amis_box = VBoxContainer.new()
	_amis_box.add_theme_constant_override("separation", 6)
	_amis_box.visible = false
	p.add_child(_amis_box)
	_amis_box.add_child(_panel_label("Le serveur de la carte tourne sur ce PC tant qu'il est allumé. Une fois dedans, F3 affiche le code d'invitation à donner à tes amis.", 13, 0.8))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	_amis_box.add_child(h)
	var lp := _panel_label("Ton pseudo", 14)
	lp.autowrap_mode = TextServer.AUTOWRAP_OFF
	h.add_child(lp)
	_pseudo_edit = LineEdit.new()
	var s := Multijoueur.souvenirs()
	_pseudo_edit.text = String(s.get("pseudo", "")) if String(s.get("pseudo", "")) != "" else OS.get_environment("USERNAME")
	_pseudo_edit.placeholder_text = "le nom que voient les autres"
	_pseudo_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(_pseudo_edit)
	var rej := Button.new()
	rej.text = "Rejoindre plutôt la carte d'un ami…"
	rej.tooltip_text = "Avec l'adresse de son serveur et son code d'invitation"
	rej.pressed.connect(ouvrir_amis)
	p.add_child(rej)


func choisir_mode(m: int) -> void:
	mode_carte = m
	if m < _mode_btns.size():
		_mode_btns[m].set_pressed_no_signal(true)
	if _amis_box != null:
		_amis_box.visible = m == GameStart.Mode.ENTRE_AMIS
	_maj_navigation()


## Panneau « Carte entre amis » (rejoindre avec un code).
func ouvrir_amis() -> MultijoueurPanel:
	if _amis_panel != null:
		return _amis_panel
	_amis_panel = MultijoueurPanel.new()
	_amis_panel.closed.connect(func() -> void: _amis_panel = null)
	_ui.add_child(_amis_panel)
	return _amis_panel


func _page_reglages(p: VBoxContainer) -> void:
	var r := ReglagesPartie.prochaine
	_titre_section(p, "Difficulté", "etoile")
	var grille := GridContainer.new()
	grille.columns = 2
	grille.add_theme_constant_override("h_separation", 6)
	grille.add_theme_constant_override("v_separation", 6)
	p.add_child(grille)
	var g := ButtonGroup.new()
	g.allow_unpress = true
	for id in DIFFICULTES:
		var b := Button.new()
		b.text = String(ReglagesPartie.PRESETS[id].nom)
		b.toggle_mode = true
		b.button_group = g
		b.custom_minimum_size = Vector2(0, 36)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		b.tooltip_text = String(DIFFICULTES[id])
		UiStyle.tint_pressed(b, UiStyle.ACCENT, UiStyle.ACCENT_INK)
		var pid: String = id
		b.pressed.connect(func() -> void: choisir_difficulte(pid))
		grille.add_child(b)
		_preset_btns[id] = b
	_preset_info = _panel_label("", 13, 0.8)
	p.add_child(_preset_info)

	_titre_section(p, "Époque de départ", "horloge")
	_vignettes = Vignettes.new()
	add_child(_vignettes)
	_epoque_opt = ChoixVisuel.new()
	_epoque_opt.face_image = Vector2(54, 38)
	_epoque_opt.titre = "Époque de départ"
	_epoque_opt.max_columns = 3
	_epoque_opt.tile_size = Vector2(170, 136)
	_epoque_opt.image_height = 92.0
	_epoque_opt.custom_minimum_size = Vector2(0, 46)
	_epoque_opt.illustrer = func(i: int, cible: TextureRect) -> void:
		var vid: String = EPOQUES_VEHICULES[i] if i < EPOQUES_VEHICULES.size() else ""
		if vid == "":
			cible.texture = Pictos.get_picto("autre_annee", 120)
		else:
			_vignettes.request_mesh("epoque:" + vid, func() -> Mesh: return VehicleCatalog.build_mesh(vid, 0, TransportView.make_material()),
				cible, 168, Vector3(1.0, 0.55, 0.8), 0.55, 112)
	for e in EPOQUES:
		_epoque_opt.add_item(String(e[1]))
	_epoque_opt.item_selected.connect(func(_i: int) -> void: _changer_epoque())
	p.add_child(_epoque_opt)
	var he := HBoxContainer.new()
	he.add_theme_constant_override("separation", 8)
	p.add_child(he)
	_annee_spin = SpinBox.new()
	_annee_spin.min_value = Epoques.ANNEE_MIN
	_annee_spin.max_value = 2100
	_annee_spin.step = 1
	_annee_spin.value = 1800
	_annee_spin.custom_minimum_size = Vector2(110, 0)
	_annee_spin.value_changed.connect(func(_v: float) -> void: _changer_epoque())
	he.add_child(_annee_spin)
	_rythme_opt = ChoixVisuel.new()
	_rythme_opt.icone = "horloge"
	_rythme_opt.gradue = 1
	for n in Epoques.RYTHME_NOMS:
		_rythme_opt.add_item(String(n))
	_rythme_opt.tooltip_text = "Années d'histoire par année de jeu : ×10, on traverse un siècle en dix ans de jeu."
	_rythme_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rythme_opt.clip_text = true
	_rythme_opt.item_selected.connect(func(_i: int) -> void: _changer_epoque())
	var lr := _panel_label("Rythme de l'histoire", 13, 0.8)
	lr.autowrap_mode = TextServer.AUTOWRAP_OFF
	lr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	he.add_child(lr)
	he.add_child(_rythme_opt)
	_epoque_ligne = he
	_epoque_info = _panel_label("", 12, 0.7)
	p.add_child(_epoque_info)
	if EditionDemo.active():
		_epoque_opt.disabled = true
		_epoque_opt.infobulle = "Partir de 1800 et traverser les époques : dans le jeu complet"

	_titre_section(p, "Argent", "budget")
	var ha := HBoxContainer.new()
	ha.add_theme_constant_override("separation", 8)
	p.add_child(ha)
	var la := _panel_label("Argent de départ", 14)
	la.autowrap_mode = TextServer.AUTOWRAP_OFF
	ha.add_child(la)
	_argent_opt = ChoixVisuel.new()
	_argent_opt.icone = "billet"
	_argent_opt.gradue = 1
	_argent_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_argent_opt.item_selected.connect(func(i: int) -> void:
		if _remplissage or i >= ARGENTS.size():
			return
		ReglagesPartie.prochaine.argent_depart = ARGENTS[i]
		_reglages_changes())
	ha.add_child(_argent_opt)
	_option(p, "argent_illimite", "Argent illimité", "Pour construire sans compter (les prix restent affichés).")

	_titre_section(p, "Construction", "construire")
	_option(p, "chantiers", "Chantiers en temps réel (ouvriers, étapes)", "Sinon, les bâtiments apparaissent d'un coup.")
	_option(p, "acces_route", "Une route devant chaque bâtiment", "Un bâtiment doit toucher une route pour être posé.")
	_option(p, "arbre", "Débloquer les bâtiments avec l'arbre de progression", "Sinon, tout le catalogue est ouvert dès le départ.")

	_titre_section(p, "Ville et habitants", "habitants")
	_option(p, "reseaux_obligatoires", "Courant, eau et égouts obligatoires", "Sinon, tout est desservi d'office.")
	_option(p, "dechets", "Poubelles à ramasser", "Collecte, décharges et incinérateurs.")
	_option(p, "catastrophes", "Catastrophes (incendies, tempêtes, épidémies)", "Au hasard, de temps en temps.")

	var adv := Button.new()
	adv.text = "Réglages avancés…"
	adv.icon = Icones.get_icon("admin", 18)
	adv.tooltip_text = "Tous les réglages : impôts, salaires, temps, ressources, pollution, immobilier… (aussi en partie avec F10)"
	adv.pressed.connect(func() -> void: open_settings(_ui))
	p.add_child(adv)
	_settings_label = _panel_label("", 12, 0.65)
	p.add_child(_settings_label)
	p.add_child(_panel_label("Tout reste modifiable en partie : F10 (Admin).", 12, 0.65))
	if r != null:
		_remplir_reglages()


## Une case à cocher d'un thème (clé de OPTIONS_SIMPLES).
func _option(parent: Control, cle: String, texte: String, aide: String) -> void:
	var c := CheckBox.new()
	c.text = texte
	c.tooltip_text = aide
	c.focus_mode = Control.FOCUS_NONE
	c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.toggled.connect(func(on: bool) -> void:
		if _remplissage:
			return
		regler_option(cle, on))
	parent.add_child(c)
	_options[cle] = c


## Lit une case simple dans les réglages de la prochaine partie.
static func lire_option(r: ReglagesPartie, cle: String) -> bool:
	match cle:
		"chantiers":
			return not r.construction_instantanee
		"arbre":
			return r.deblocage == "arbre"
	return bool(r.get(cle))


func regler_option(cle: String, on: bool) -> void:
	var r := ReglagesPartie.prochaine
	match cle:
		"chantiers":
			r.construction_instantanee = not on
		"arbre":
			r.deblocage = "arbre" if on else "tout"
		_:
			r.set(cle, on)
	if _options.has(cle):
		(_options[cle] as CheckBox).set_pressed_no_signal(on)
	_reglages_changes()


func choisir_difficulte(id: String) -> void:
	var r := ReglagesPartie.prochaine
	# Le préréglage ne touche ni l'époque ni le tutoriel.
	var an := r.annee_depart
	var ry := r.rythme_histoire
	var tu := r.tutoriel
	r.apply_preset(id)
	r.annee_depart = an
	r.rythme_histoire = ry
	r.tutoriel = tu
	_remplir_reglages()
	_reglages_changes()


func _changer_epoque() -> void:
	if _remplissage:
		return
	var r := ReglagesPartie.prochaine
	var i := _epoque_opt.selected
	var annee := int(EPOQUES[i][0]) if i >= 0 else 0
	_epoque_autre = annee < 0
	if annee < 0:
		annee = int(_annee_spin.value)
	r.annee_depart = annee
	r.rythme_histoire = float(Epoques.RYTHMES[maxi(0, _rythme_opt.selected)])
	_remplir_reglages()
	_reglages_changes()


## Remet les contrôles des réglages à jour (après un préréglage ou les réglages avancés).
func _remplir_reglages() -> void:
	var r := ReglagesPartie.prochaine
	if r == null or _argent_opt == null:
		return
	_remplissage = true
	var nom := r.preset_name()
	for id in _preset_btns:
		(_preset_btns[id] as Button).set_pressed_no_signal(String(ReglagesPartie.PRESETS[id].nom) == nom)
	var cur := ""
	for id in DIFFICULTES:
		if String(ReglagesPartie.PRESETS[id].nom) == nom:
			cur = id
	_preset_info.text = String(DIFFICULTES[cur]) if cur != "" else "Personnalisé : tes propres réglages."
	_argent_opt.clear()
	var trouve := -1
	for i in ARGENTS.size():
		_argent_opt.add_item(BuildingSystem.format_short(ARGENTS[i]))
		if ARGENTS[i] == r.argent_depart:
			trouve = i
	if trouve < 0:
		_argent_opt.add_item(BuildingSystem.format_short(r.argent_depart))
		trouve = ARGENTS.size()
	_argent_opt.select(trouve)
	_argent_opt.disabled = r.argent_illimite
	for cle in _options:
		(_options[cle] as CheckBox).set_pressed_no_signal(lire_option(r, cle))
	var e := 0
	if r.annee_depart > 0:
		e = EPOQUES.size() - 1
		if not _epoque_autre:
			for i in EPOQUES.size():
				if int(EPOQUES[i][0]) == r.annee_depart:
					e = i
		_annee_spin.value = r.annee_depart
	_epoque_opt.select(e)
	_epoque_ligne.visible = r.annee_depart > 0
	_annee_spin.visible = int(EPOQUES[e][0]) < 0
	_rythme_opt.select(AdminPanel._indice_rythme(r.rythme_histoire))
	_epoque_info.text = _texte_epoque(r)
	_remplissage = false
	_update_settings_label()


func _texte_epoque(r: ReglagesPartie) -> String:
	if r.annee_depart <= 0:
		return "Époque actuelle : tout est disponible d'office."
	var nxt: Array[String] = []
	for inv in Epoques.prochaines(r.annee_depart, 3):
		nxt.append("%d %s" % [int(inv.annee), String(inv.nom).to_lower()])
	return ("Bâtiments, véhicules, voies, réseaux et matériaux de l'Atelier suivent l'année. "
		+ "À venir : %s." % (", ".join(nxt) if not nxt.is_empty() else "le futur reste à écrire"))


func _reglages_changes() -> void:
	if not _remplissage:
		_remplir_reglages()
	if etape == ETAPES.size() - 1:
		_maj_resume()


func _page_tutoriel(p: VBoxContainer) -> void:
	var g := ButtonGroup.new()
	_tuto_oui = _carte_choix(p, "Oui, guide-moi", "Une étape à la fois en haut à gauche : fonder le village, tracer une route, zoner, courant et eau… Conseillé pour une première partie.", g, "aide")
	_tuto_non = _carte_choix(p, "Non merci, je connais", "Tu commences directement. Le tutoriel se rallume à tout moment (F10 → Aide).", g, "play")
	_tuto_oui.toggled.connect(func(on: bool) -> void:
		if on:
			choisir_tutoriel(true))
	_tuto_non.toggled.connect(func(on: bool) -> void:
		if on:
			choisir_tutoriel(false))
	_objectifs_check = CheckBox.new()
	_objectifs_check.text = "Objectifs à l'écran (rang de la ville, missions)"
	_objectifs_check.focus_mode = Control.FOCUS_NONE
	_objectifs_check.toggled.connect(func(on: bool) -> void:
		ReglagesPartie.prochaine.objectifs_ecran = on)
	p.add_child(_objectifs_check)
	_tuto_note = _panel_label("", 13, 0.75)
	p.add_child(_tuto_note)


func choisir_tutoriel(on: bool) -> void:
	ReglagesPartie.prochaine.tutoriel = on
	_maj_tutoriel()


func _maj_tutoriel() -> void:
	var r := ReglagesPartie.prochaine
	var amis := mode_carte == GameStart.Mode.ENTRE_AMIS
	_tuto_oui.disabled = amis
	_tuto_oui.set_pressed_no_signal(r.tutoriel and not amis)
	_tuto_non.set_pressed_no_signal(not r.tutoriel or amis)
	_objectifs_check.set_pressed_no_signal(r.objectifs_ecran)
	_tuto_note.text = "Le tutoriel se joue en solo : sur une carte entre amis, chacun avance à son rythme." if amis else ""
	_tuto_note.visible = amis


func _page_resume(p: VBoxContainer) -> void:
	_resume_box = GridContainer.new()
	_resume_box.columns = 3
	_resume_box.add_theme_constant_override("h_separation", 10)
	_resume_box.add_theme_constant_override("v_separation", 8)
	p.add_child(_resume_box)
	_resume_note = _panel_label("", 13, 0.8)
	p.add_child(_resume_note)


## Lignes du résumé : [nom, valeur, étape à modifier].
func lignes_resume() -> Array:
	var r := ReglagesPartie.prochaine
	var lieu := sel_name if sel_name != "" else _format_lat_lon(sel_lat, sel_lon)
	var types := ["Seul (bac à sable)", "Entre amis, sur ce PC", "Carte mondiale"]
	var argent := "Illimité" if r.argent_illimite else BuildingSystem.format_short(r.argent_depart)
	var epoque := "Aujourd'hui" if r.annee_depart <= 0 else "%d" % r.annee_depart
	if r.annee_depart > 0 and r.rythme_histoire > 1.0:
		epoque += " · histoire " + Epoques.nom_rythme(r.rythme_histoire)
	var tuto := "Oui" if r.tutoriel and mode_carte != GameStart.Mode.ENTRE_AMIS else "Non"
	return [["Lieu", lieu, 0], ["Type de carte", types[mode_carte], 1], ["Difficulté", r.preset_name(), 2],
		["Argent de départ", argent, 2], ["Époque", epoque, 2],
		["Bâtiments", "Arbre de progression" if r.deblocage == "arbre" else "Tout débloqué", 2], ["Tutoriel", tuto, 3]]


func _maj_resume() -> void:
	if _resume_box == null:
		return
	for c in _resume_box.get_children():
		c.queue_free()
	for l in lignes_resume():
		var n := _panel_label(String(l[0]), 14, 0.7)
		n.autowrap_mode = TextServer.AUTOWRAP_OFF
		_resume_box.add_child(n)
		var v := _panel_label(String(l[1]), 15)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_resume_box.add_child(v)
		var b := Button.new()
		b.text = "Modifier"
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		var e := int(l[2])
		b.pressed.connect(func() -> void: aller_a(e))
		_resume_box.add_child(b)
	if mode_carte == GameStart.Mode.ENTRE_AMIS:
		_resume_note.text = "Le serveur de ta carte démarre sur ce PC, puis tu y entres. Tes amis la rejoignent depuis le menu principal → Entre amis, avec ton adresse et le code d'invitation (F3 en partie)."
	else:
		_resume_note.text = "La partie commence en pause, le temps de regarder ton lieu : lance le temps avec ▶ en haut de l'écran (ou T)."


## Résultats de la recherche : des coordonnées, ou les villes de l'index.
func _refresh_list() -> void:
	var q := _search.text.strip_edges()
	_filtered.clear()
	_list.clear()
	if q == "":
		_online_btn.visible = false
		return
	var v: Variant = Geo.parse_lat_lon(q)
	if v != null:
		var near := Villes.plus_proche(v.x, v.y)
		_filtered.append({"nom": "Coordonnées %s" % _format_lat_lon(v.x, v.y), "pays": String(near.get("pays", "")),
			"pays_nom": String(near.get("pays_nom", "")), "pop": 0, "lat": v.x, "lon": v.y, "coord": true})
	else:
		_filtered = Villes.chercher(q, 40)
	for e in _filtered:
		var i := _list.add_item(Villes.libelle(e) if not e.get("coord", false) else String(e.nom))
		var ic := Drapeaux.icone(String(e.get("pays", "")), 18)
		if ic != null:
			_list.set_item_icon(i, ic)
	if _filtered.is_empty():
		var i := _list.add_item("Aucune ville trouvée dans l'index.")
		_list.set_item_disabled(i, true)
	_online_btn.visible = not offline and q.length() >= 3 and v == null


func _choose(i: int) -> void:
	if i < 0 or i >= _filtered.size():
		return
	var e: Dictionary = _filtered[i]
	var nom := String(e.nom)
	if not e.get("coord", false) and String(e.get("pays_nom", "")) != "":
		nom = "%s, %s" % [e.nom, e.pays_nom]
	select_place(float(e.lat), float(e.lon), nom, false, String(e.get("pays", "")))


## Recherche en ligne (OpenStreetMap Nominatim) : tous les lieux, même les hameaux.
func _search_online() -> void:
	var q := _search.text.strip_edges()
	if q.length() < 2:
		return
	if _online == null:
		_online = HTTPRequest.new()
		_online.timeout = 15.0
		add_child(_online)
		_online.request_completed.connect(_on_online)
	_online.cancel_request()
	_online_btn.text = "Recherche en ligne…"
	var url := "https://nominatim.openstreetmap.org/search?format=jsonv2&addressdetails=1&limit=15&accept-language=fr&q=" + q.uri_encode()
	_online.request(url, PackedStringArray(["User-Agent: MiniBlocs/0.1 (jeu video)"]))


func _on_online(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_online_btn.text = "Chercher en ligne (petits villages, lieux-dits…)"
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_list.add_item("Recherche en ligne impossible (pas d'Internet ?).")
		return
	var res := parse_online(body.get_string_from_utf8())
	if res.is_empty():
		_list.add_item("Rien trouvé en ligne.")
		return
	_filtered.clear()
	_list.clear()
	for e in res:
		_filtered.append(e)
		var i := _list.add_item(Villes.libelle(e))
		var ic := Drapeaux.icone(String(e.pays), 18)
		if ic != null:
			_list.set_item_icon(i, ic)


## Réponse JSON de Nominatim -> [{nom, pays, pays_nom, pop, lat, lon}].
static func parse_online(json: String) -> Array:
	var out := []
	var data = JSON.parse_string(json)
	if not data is Array:
		return out
	for r in data:
		if not r is Dictionary or not r.has("lat"):
			continue
		var adr: Dictionary = r.get("address", {})
		var cc := String(adr.get("country_code", "")).to_lower()
		var nom := String(r.get("name", ""))
		if nom == "":
			nom = String(r.get("display_name", "")).split(",")[0]
		var lieu := String(adr.get("state", adr.get("county", "")))
		out.append({"nom": nom + (" (%s)" % lieu if lieu != "" and lieu != nom else ""), "pays": cc,
			"pays_nom": Villes.nom_pays(cc) if cc != "" else String(adr.get("country", "")), "pop": 0,
			"lat": float(r.lat), "lon": float(r.lon)})
	return out
