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
var _mode: OptionButton
## Réglages de la nouvelle partie (bouton « Réglages de la partie »).
var _settings_label: Label
var _settings_panel: AdminPanel
var _start_btn: Button
## Case « Tutoriel guidé » (suit aussi le réglage du panneau Réglages…).
var _tuto_check: CheckBox
## Résultats affichés dans la liste ({nom, pays, pays_nom, pop, lat, lon}).
var _filtered: Array = []
var _search_timer: Timer
var _online_btn: Button
var _online: HTTPRequest


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
		select_place(GameStart.lat, GameStart.lon, GameStart.place_name, true)


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
	if k and k.pressed and not k.echo and k.keycode == KEY_ESCAPE and _saves_panel == null and _settings_panel == null:
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
	_start_btn.disabled = false
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
	GameStart.mode = GameStart.Mode.BAC_A_SABLE
	GameStart.load_slot = ""
	GameStart.slot_id = ""
	EcranChargement.aller("res://scenes/terre.tscn", sel_name if sel_name != "" else "Nouvelle partie")


## Panneau des réglages de la nouvelle partie (le même que le panneau Admin).
func open_settings(ui: CanvasLayer) -> void:
	if _settings_panel != null:
		return
	GameStart.mode = _mode.selected as GameStart.Mode
	_settings_panel = AdminPanel.new(ReglagesPartie.prochaine, true, true)
	_settings_panel.settings_changed.connect(_update_settings_label)
	_settings_panel.closed.connect(func() -> void:
		_settings_panel = null
		_update_settings_label())
	ui.add_child(_settings_panel)


func _update_settings_label() -> void:
	if _settings_label and ReglagesPartie.prochaine != null:
		_settings_label.text = "Réglages : " + ReglagesPartie.prochaine.summary()
	if _tuto_check and ReglagesPartie.prochaine != null:
		_tuto_check.set_pressed_no_signal(ReglagesPartie.prochaine.tutoriel)


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
	add_child(ui)

	# Panneau de gauche : recherche.
	var left := PanelContainer.new()
	left.position = Vector2(16, 16)
	left.custom_minimum_size = Vector2(340, 0)
	ui.add_child(left)
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

	# Panneau de droite : le lieu choisi.
	var right := PanelContainer.new()
	right.custom_minimum_size = Vector2(320, 0)
	right.anchor_left = 1.0
	right.anchor_right = 1.0
	right.anchor_top = 1.0
	right.anchor_bottom = 1.0
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.grow_vertical = Control.GROW_DIRECTION_BEGIN
	right.offset_right = -16
	right.offset_bottom = -40
	ui.add_child(right)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 8)
	right.add_child(rv)
	rv.add_child(_panel_label("Lieu choisi", 18))
	_place_label = _panel_label("Clique sur la Terre ou choisis un lieu dans la liste.", 14, 0.9)
	rv.add_child(_place_label)
	_detail_label = _panel_label("", 13, 0.8)
	rv.add_child(_detail_label)
	_mode = OptionButton.new()
	_mode.add_item("Bac à sable : seul, hors ligne")
	_mode.add_item("Entre amis : sur invitation (bientôt)")
	_mode.add_item("Carte mondiale : tous les joueurs (bientôt)")
	_mode.set_item_disabled(1, true)
	_mode.set_item_disabled(2, true)
	rv.add_child(_mode)
	if ReglagesPartie.prochaine == null:
		ReglagesPartie.prochaine = ReglagesPartie.load_defaults()
	var set_row := HBoxContainer.new()
	rv.add_child(set_row)
	_settings_label = _panel_label("", 12, 0.8)
	_settings_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	set_row.add_child(_settings_label)
	var set_btn := Button.new()
	set_btn.text = "Réglages…"
	set_btn.icon = Icones.get_icon("admin", 18)
	set_btn.tooltip_text = "Réglages de la partie : argent de départ, coûts, règles, économie, temps, ressources, déblocage"
	set_btn.pressed.connect(func() -> void: open_settings(ui))
	set_row.add_child(set_btn)
	_update_settings_label()
	var tuto := CheckBox.new()
	tuto.text = "Tutoriel guidé (conseillé pour une première partie)"
	tuto.tooltip_text = "Une étape à la fois en haut à gauche : fonder le village, tracer une route, zoner, courant et eau… Se coupe à tout moment (F10 → Aide)."
	tuto.focus_mode = Control.FOCUS_NONE
	tuto.button_pressed = ReglagesPartie.prochaine.tutoriel
	tuto.toggled.connect(func(on: bool) -> void:
		if ReglagesPartie.prochaine != null:
			ReglagesPartie.prochaine.tutoriel = on)
	rv.add_child(tuto)
	_tuto_check = tuto
	_start_btn = Button.new()
	_start_btn.text = "Commencer la partie"
	_start_btn.custom_minimum_size = Vector2(0, 44)
	_start_btn.disabled = true
	_start_btn.pressed.connect(start_game)
	rv.add_child(_start_btn)

	# Parties sauvegardées : reprendre la dernière, ou choisir dans la liste.
	var saves := SaveGame.list_saves()
	var srow := HBoxContainer.new()
	rv.add_child(srow)
	_continue_btn = Button.new()
	_continue_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_continue_btn.custom_minimum_size = Vector2(0, 36)
	if saves.is_empty():
		_continue_btn.text = "Aucune partie sauvegardée"
		_continue_btn.disabled = true
	else:
		_continue_btn.text = "Continuer : " + String(saves[0].get("nom", saves[0].id))
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
	back.offset_right = -150
	back.offset_top = 16
	back.pressed.connect(back_to_menu)
	ui.add_child(back)

	var proto := Button.new()
	proto.text = "Ville prototype"
	proto.anchor_left = 1.0
	proto.anchor_right = 1.0
	proto.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	proto.offset_right = -16
	proto.offset_top = 16
	proto.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/main.tscn"))
	ui.add_child(proto)

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
