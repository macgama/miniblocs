extends Node3D
## Écran de départ : un globe 3D coloré par le vrai relief.
## Le joueur fait tourner la Terre, choisit un lieu (clic, recherche,
## coordonnées ou hasard), voit un aperçu du relief, puis commence sa partie.

## Pour les tests : pas de réseau, planète synthétique.
@export var offline := false

const GLOBE_ZOOM := 3 # 8 × 8 tuiles, assemblées en une texture de 2048 × 2048
const MIN_DIST := 1.18
const MAX_DIST := 4.0

const PLACES := [
	["Zurich", 47.3769, 8.5417], ["Genève", 46.2044, 6.1432], ["Lausanne", 46.5197, 6.6323],
	["Interlaken", 46.6863, 7.8632], ["Cervin (Zermatt)", 45.9763, 7.6586],
	["Paris", 48.8566, 2.3522], ["Tour Eiffel", 48.85826, 2.2945], ["Mont Blanc", 45.8326, 6.8652],
	["Annecy", 45.8992, 6.1294], ["Lyon", 45.7640, 4.8357], ["Marseille", 43.2965, 5.3698],
	["Calanques de Marseille", 43.2105, 5.4489], ["Bordeaux", 44.8378, -0.5792],
	["Dune du Pilat", 44.5895, -1.2128], ["Étretat", 49.7070, 0.2016],
	["Mont-Saint-Michel", 48.6361, -1.5115], ["Bonifacio (Corse)", 41.3874, 9.1592],
	["Bruxelles", 50.8503, 4.3517], ["Londres", 51.5074, -0.1278], ["Amsterdam", 52.3676, 4.9041],
	["Berlin", 52.5200, 13.4050], ["Rome", 41.9028, 12.4964], ["Venise", 45.4408, 12.3155],
	["Barcelone", 41.3874, 2.1686], ["Madrid", 40.4168, -3.7038], ["Lisbonne", 38.7223, -9.1393],
	["Santorin", 36.3932, 25.4615], ["Reykjavik (Islande)", 64.1466, -21.9426],
	["Fjord de Geiranger", 62.1008, 7.2059], ["New York", 40.7128, -74.0060],
	["Grand Canyon", 36.0610, -112.1080], ["Yosemite", 37.7456, -119.5936],
	["San Francisco", 37.7749, -122.4194], ["Montréal", 45.5017, -73.5673], ["Québec", 46.8139, -71.2080],
	["Mexico", 19.4326, -99.1332], ["Rio de Janeiro", -22.9068, -43.1729],
	["Machu Picchu", -13.1631, -72.5450], ["Buenos Aires", -34.6037, -58.3816],
	["Patagonie (Fitz Roy)", -49.2714, -73.0431], ["Pyramides de Gizeh", 29.9792, 31.1342],
	["Sahara (Erg Chebbi)", 31.1450, -4.0150], ["Kilimandjaro", -3.0674, 37.3556],
	["Le Cap", -33.9249, 18.4241], ["Dakar", 14.7167, -17.4677], ["Abidjan", 5.3600, -4.0083],
	["Antananarivo", -18.8792, 47.5079], ["Dubaï", 25.2048, 55.2708], ["Everest", 27.9881, 86.9250],
	["Tokyo", 35.6762, 139.6503], ["Mont Fuji", 35.3606, 138.7274], ["Pékin", 39.9042, 116.4074],
	["Baie d'Ha Long", 20.9101, 107.1839], ["Bali", -8.3405, 115.0920], ["Sydney", -33.8688, 151.2093],
	["Uluru", -25.3444, 131.0369], ["Milford Sound (Nouvelle-Zélande)", -44.6414, 167.8974],
	["Maui (Hawaï)", 20.7984, -156.3319], ["Bora-Bora", -16.5004, -151.7415],
]

var view_lat := 46.0
var view_lon := 7.0
var distance := 2.6
var selected := false
var sel_lat := 0.0
var sel_lon := 0.0
var sel_name := ""

var _target_dist := 2.6
var _globe: MeshInstance3D
var _globe_mat: ShaderMaterial
var _marker: Node3D
var _camera: Camera3D
var _globe_tiles: ElevationTiles
var _detail_tiles: ElevationTiles
var _planet: Image
var _press_pos := Vector2.ZERO
var _pressing := false
var _dragged := false
var _tween: Tween

# Interface
var _search: LineEdit
var _list: ItemList
var _coords: LineEdit
var _loading_label: Label
var _place_label: Label
var _detail_label: Label
var _mode: OptionButton
var _start_btn: Button
var _random_btn: Button
var _filtered: Array = []


func _ready() -> void:
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
	_random_btn.disabled = false


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

func select_place(lat: float, lon: float, place_name: String, instant := false) -> void:
	selected = true
	sel_lat = lat
	sel_lon = wrapf(lon, -180.0, 180.0)
	sel_name = place_name
	var p := lat_lon_to_point(sel_lat, sel_lon)
	_marker.transform = Transform3D(Basis(Quaternion(Vector3.UP, p)), p)
	_apply_view()
	_marker.visible = true
	if place_name != "":
		fly_to(sel_lat, sel_lon, minf(_target_dist, 1.7), instant)
	_coords.text = "%.5f, %.5f" % [sel_lat, sel_lon]
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
	if d.height < 0.0:
		txt += "\nAttention : tu commenceras sous l'eau."
	txt += "\nRégion de jeu : %d × %d km" % [int(GameStart.REGION_SIZE / 1000.0), int(GameStart.REGION_SIZE / 1000.0)]
	_detail_label.text = txt


func pick_random_land() -> bool:
	if _planet == null:
		return false
	for i in 2000:
		var lat := rad_to_deg(asin(randf_range(-0.9, 0.93)))
		var lon := randf_range(-180.0, 180.0)
		if planet_height(lat, lon) > 5.0:
			select_place(lat, lon, "Lieu au hasard")
			return true
	return false


func start_game() -> void:
	if not selected:
		return
	GameStart.chosen = true
	GameStart.lat = sel_lat
	GameStart.lon = sel_lon
	GameStart.place_name = sel_name
	GameStart.mode = GameStart.Mode.BAC_A_SABLE
	get_tree().change_scene_to_file("res://scenes/terre.tscn")


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
	lv.add_child(_panel_label("Choisis ton point de départ sur la Terre.", 15, 0.85))
	_search = LineEdit.new()
	_search.placeholder_text = "Rechercher un lieu…"
	_search.clear_button_enabled = true
	_search.text_changed.connect(func(_t: String) -> void: _refresh_list())
	lv.add_child(_search)
	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(0, 260)
	_list.item_selected.connect(func(i: int) -> void:
		var p: Array = _filtered[i]
		select_place(p[1], p[2], p[0]))
	lv.add_child(_list)
	_refresh_list()
	lv.add_child(_panel_label("Ou des coordonnées (copiées depuis Google Maps) :", 12, 0.75))
	var row := HBoxContainer.new()
	lv.add_child(row)
	_coords = LineEdit.new()
	_coords.placeholder_text = "46.2044, 6.1432"
	_coords.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_coords.text_submitted.connect(func(_t: String) -> void: _on_coords())
	row.add_child(_coords)
	var go := Button.new()
	go.text = "Aller"
	go.pressed.connect(_on_coords)
	row.add_child(go)
	_random_btn = Button.new()
	_random_btn.text = "Lieu au hasard"
	_random_btn.disabled = true
	_random_btn.pressed.connect(pick_random_land)
	lv.add_child(_random_btn)
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
	_start_btn = Button.new()
	_start_btn.text = "Commencer la partie"
	_start_btn.custom_minimum_size = Vector2(0, 44)
	_start_btn.disabled = true
	_start_btn.pressed.connect(start_game)
	rv.add_child(_start_btn)

	var proto := Button.new()
	proto.text = "Ville prototype"
	proto.anchor_left = 1.0
	proto.anchor_right = 1.0
	proto.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	proto.offset_right = -16
	proto.offset_top = 16
	proto.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/main.tscn"))
	ui.add_child(proto)

	var credit := _panel_label("Relief : Mapzen Terrain Tiles (AWS Open Data) — SRTM, GMTED, ETOPO1, EU-DEM et autres sources publiques", 11, 0.6)
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


func _refresh_list() -> void:
	var q := _search.text.strip_edges().to_lower()
	_filtered.clear()
	_list.clear()
	for p in PLACES:
		if q == "" or (p[0] as String).to_lower().contains(q):
			_filtered.append(p)
			_list.add_item(p[0])


func _on_coords() -> void:
	var v: Variant = Geo.parse_lat_lon(_coords.text)
	_coords.release_focus()
	if v == null:
		_place_label.text = "Coordonnées non comprises. Exemple : 46.2044, 6.1432"
		return
	select_place(v.x, v.y, "Coordonnées")
