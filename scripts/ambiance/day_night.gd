class_name DayNight
extends Node
## Cycle jour/nuit du mode Terre.
##
## - Une horloge de jeu (date et heure réelles, en UTC) avance à la vitesse
##   choisie : pause, temps réel, 1 min/s, 10 min/s ou 100 min/s.
## - Le Soleil et la Lune sont placés à leur vraie position dans le ciel pour la
##   latitude et la longitude du lieu choisi sur le globe (saisons, nuits
##   polaires, phases de la Lune comprises).
## - Ciel, brume, lumière ambiante et couleur du soleil suivent la hauteur du
##   Soleil (aube, journée, coucher, crépuscule, nuit étoilée).
## - La nuit : lampadaires le long des voies et fenêtres allumées.
## - Les ombres s'adaptent au zoom de la caméra.

signal time_changed

## Vitesses proposées (secondes de jeu par seconde réelle).
const SPEEDS := [0.0, 1.0, 60.0, 600.0, 6000.0]
const SPEED_NAMES := ["Pause", "Réel", "1 min/s", "10 min/s", "100 min/s"]
const DEFAULT_SPEED := 2
const START_HOUR := 10.0

@export var sun_path: NodePath
@export var environment_path: NodePath
@export var transport_path: NodePath
@export var world_path: NodePath
@export var vue_sol_path: NodePath

var sun: DirectionalLight3D
var moon: DirectionalLight3D
var env: Environment
var world: TerrainWorld
var street: StreetLights
var sky_material: ShaderMaterial
var hud: ClockHud
var weather: Meteo
var headlights: Headlights
## Vue au sol (facultative) : elle règle son propre brouillard.
var _vue_sol: Node

## Instant du jeu (secondes Unix, UTC).
var unix_time := 0.0
var speed_index := DEFAULT_SPEED
var lat := 48.8584
var lon := 2.2945
## Valeurs calculées à chaque image (lecture seule).
var sun_horiz := Vector2.ZERO
var moon_horiz := Vector2.ZERO
var sun_dir := Vector3.UP
var moon_dir := Vector3.DOWN
var night := 0.0
var moon_light := 0.0
var _rise_set := Vector2.ZERO
var _rise_set_day := -1

## Rendu « poussé » (voir docs/demo-low-poly.md) : tons ACES, ombres douces,
## lumière dorée aux heures basses, brume au ras du sol le matin et par
## brouillard, rayons de soleil dans la brume. false = rendu d'avant.
static var rendu_pousse := true
## Brume du matin (0 à 1), calculée à chaque image.
var brume := 0.0

## Jour permanent (Ctrl + T, ou clic sur le Soleil de l'horloge) : l'image reste
## de jour pour construire, mais l'horloge, les habitants et la production
## continuent. Le jour, le Soleil suit l'heure ; le soir, il s'arrête sur
## l'après-midi, puis repart du matin à minuit. Quand le Soleil du jour reste
## trop bas (hiver polaire), on prend la lumière d'un jour plus proche de
## l'équinoxe.
signal jour_permanent_changed(on: bool)
## Jour permanent choisi par le joueur (toujours, même hors construction).
var jour_permanent := false
## Jour permanent automatique quand Construire ou l'éditeur libre est ouvert
## (réglable dans le panneau Horloge, gardé dans la sauvegarde).
var jour_auto := true
## Construire ou l'éditeur libre est ouvert (réglé par terre_main).
var _construction := false
## Le joueur a coupé le jour automatique pendant cette séance de construction.
var _auto_off := false
## Hauteur minimale du Soleil affiché en jour permanent (degrés).
const JOUR_MIN_ELEV := 20.0
## Écart (secondes) entre l'instant affiché (Soleil, Lune, ciel) et l'horloge.
var _shift := 0.0
var _snap := true
var _jp_day := -2147483648
## Fenêtre de lumière du jour : (heure de début, heure de fin, décalage en jours).
var _jp_window := Vector3(0.0, 24.0, 0.0)
## Hauteur du vrai Soleil (degrés), même en jour permanent.
var real_sun_elev := 0.0


func _ready() -> void:
	sun = get_node_or_null(sun_path) as DirectionalLight3D
	var we := get_node_or_null(environment_path) as WorldEnvironment
	if we != null:
		env = we.environment
	world = get_node_or_null(world_path) as TerrainWorld
	if world != null:
		world.origin_changed.connect(func(a: float, o: float) -> void: set_place(a, o))
		lat = world.origin_lat
		lon = world.origin_lon
	elif GameStart.chosen:
		lat = GameStart.lat
		lon = GameStart.lon

	moon = DirectionalLight3D.new()
	moon.name = "Lune"
	moon.light_color = Color(0.62, 0.72, 1.0)
	moon.light_energy = 0.0
	moon.shadow_enabled = false
	moon.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(moon)

	if sun != null:
		sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
		sun.shadow_enabled = true
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		sun.directional_shadow_blend_splits = true
		sun.shadow_blur = 1.2
		sun.shadow_bias = 0.04
		sun.shadow_normal_bias = 1.2

	if env != null:
		sky_material = ShaderMaterial.new()
		sky_material.shader = load("res://scripts/ambiance/ciel.gdshader")
		var sky := Sky.new()
		sky.sky_material = sky_material
		sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
		sky.radiance_size = Sky.RADIANCE_SIZE_128
		env.sky = sky
		env.background_mode = Environment.BG_SKY
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
		env.glow_enabled = true
		env.glow_hdr_threshold = 1.0
		env.glow_bloom = 0.0
		env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		if rendu_pousse:
			_rendu_pousse_init()

	weather = Meteo.new()
	weather.name = "Meteo"
	weather.world = world
	add_child(weather)
	weather.set_place(lat, lon)
	_vue_sol = get_node_or_null(vue_sol_path)

	headlights = Headlights.new()
	headlights.name = "Phares"
	var tr := get_node_or_null(transport_path) as TransportSystem
	if tr != null:
		headlights.traffic = tr.traffic
	add_child(headlights)

	street = StreetLights.new()
	street.name = "Eclairage"
	street.transport = get_node_or_null(transport_path) as TransportSystem
	add_child(street)

	hud = ClockHud.new()
	hud.name = "Horloge"
	hud.clock = self
	add_child(hud)

	_start_today()
	_apply()


## Réglages fixes du rendu poussé (les réglages qui varient sont dans _apply).
func _rendu_pousse_init() -> void:
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	env.ssao_enabled = true
	env.ssao_radius = 1.6
	env.ssao_intensity = 2.2
	env.ssao_power = 1.5
	env.fog_aerial_perspective = 0.35
	env.fog_sky_affect = 0.15
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.05
	env.adjustment_saturation = 1.08
	env.volumetric_fog_length = 180.0
	env.volumetric_fog_detail_spread = 2.0
	env.volumetric_fog_anisotropy = 0.6
	if sun != null:
		# Ombres aux bords doux (la taille apparente du Soleil).
		sun.light_angular_distance = 0.6


## Brume du matin (0 à 1) : un jour sur deux environ, du lever à 3 h après,
## et toujours par temps de brouillard.
func brume_du_matin() -> float:
	var rs := rise_set()
	var b := 0.0
	if rs.x >= 0.0:
		var h := local_hour()
		var day := int(floorf((unix_time + utc_offset() * 3600.0) / 86400.0))
		var chance := fposmod(sin(day * 12.9898) * 43758.5453, 1.0)
		if chance < 0.55:
			b = (1.0 - smoothstep(rs.x + 0.5, rs.x + 3.0, h)) * smoothstep(rs.x - 2.0, rs.x - 0.5, h)
			b *= lerpf(0.6, 1.0, chance / 0.55)
	if weather != null:
		b = maxf(b, weather.fog)
		# Le vent et la pluie dissipent la brume au sol.
		b *= lerpf(1.0, 0.3, weather.precip)
	return clampf(b, 0.0, 1.0)


## Altitude du sol sous la caméra (pour poser la brume au ras du sol).
func _sol_camera() -> float:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null or world == null:
		return 0.0
	var p := cam.global_position
	var f := -cam.global_basis.z
	# Point visé au sol (approché) : là où regarde la caméra.
	if f.y < -0.05:
		var g := world.cell_height(Vector2i(int(floor(p.x)), int(floor(p.z))))
		var t := (p.y - g) / -f.y
		p += f * minf(t, 2000.0)
	return world.cell_height(Vector2i(int(floor(p.x)), int(floor(p.z))))


## Démarre aujourd'hui (date de l'ordinateur), à 10 h, heure du lieu.
func _start_today() -> void:
	var now := Time.get_unix_time_from_system()
	var off := Fuseaux.utc_offset(lat, lon, now) * 3600.0
	var local_midnight := floorf((now + off) / 86400.0) * 86400.0
	unix_time = local_midnight + START_HOUR * 3600.0 - off


func set_place(a: float, o: float) -> void:
	lat = a
	lon = o
	_rise_set_day = -1
	_jp_day = -2147483648
	_snap = true
	if weather != null:
		weather.set_place(a, o)
	_apply()


## Décalage horaire du lieu (heures).
func utc_offset() -> float:
	return Fuseaux.utc_offset(lat, lon, unix_time)


## Heure locale en heures décimales (0 à 24).
func local_hour() -> float:
	var local := unix_time + utc_offset() * 3600.0
	return fposmod(local, 86400.0) / 3600.0


## Règle l'heure locale du jour en cours (heures décimales).
func set_local_hour(h: float) -> void:
	var off := utc_offset() * 3600.0
	var local := unix_time + off
	var midnight := floorf(local / 86400.0) * 86400.0
	unix_time = midnight + clampf(h, 0.0, 23.999) * 3600.0 - off
	_snap = true
	_apply()


## Avance ou recule la date d'un nombre de jours (même heure).
func shift_days(days: int) -> void:
	unix_time += days * 86400.0
	_snap = true
	_apply()


func set_speed(i: int) -> void:
	speed_index = clampi(i, 0, SPEEDS.size() - 1)
	time_changed.emit()


func toggle_pause() -> void:
	if speed_index == 0:
		set_speed(DEFAULT_SPEED)
	else:
		set_speed(0)


## Vrai si l'image est en jour permanent (choisi, ou automatique en construction).
func jour_actif() -> bool:
	return jour_permanent or (jour_auto and _construction and not _auto_off)


## Allume ou éteint le jour permanent (bouton Soleil, Ctrl + T). L'éteindre
## pendant la construction coupe aussi le jour automatique jusqu'à la
## fermeture de Construire.
func set_jour_permanent(on: bool) -> void:
	var before := jour_actif()
	if on:
		_auto_off = false
		if not jour_actif():
			jour_permanent = true
	else:
		jour_permanent = false
		if _construction:
			_auto_off = true
	_changed_jour(before)


func toggle_jour_permanent() -> void:
	set_jour_permanent(not jour_actif())


func set_jour_auto(on: bool) -> void:
	var before := jour_actif()
	jour_auto = on
	_changed_jour(before)


## Construire ou l'éditeur libre s'ouvre ou se ferme.
func set_construction(on: bool) -> void:
	if on == _construction:
		return
	var before := jour_actif()
	_construction = on
	if not on:
		_auto_off = false
	_changed_jour(before)


func _changed_jour(before: bool) -> void:
	if jour_actif() != before:
		_snap = true
		_apply()
		jour_permanent_changed.emit(jour_actif())
	else:
		time_changed.emit()


## Instant utilisé pour le Soleil, la Lune et le ciel (= l'horloge, sauf en
## jour permanent).
func display_time() -> float:
	return unix_time + _shift


## Écart voulu entre l'instant affiché et l'horloge.
func _target_shift() -> float:
	if not jour_actif():
		return 0.0
	var off := utc_offset() * 3600.0
	var day := int(floorf((unix_time + off) / 86400.0))
	if day != _jp_day:
		_jp_day = day
		_jp_window = day_window(unix_time)
	var h := local_hour()
	var hd := clampf(h, _jp_window.x, _jp_window.y)
	return _jp_window.z * 86400.0 + (hd - h) * 3600.0


## Heures du jour (locales) où le Soleil est assez haut pour bien voir :
## Vector3(début, fin, décalage en jours). Calculé une fois par jour.
func day_window(t: float) -> Vector3:
	# Le jour même si le Soleil y monte à 12° au moins ; sinon le jour le plus
	# proche où il monte à 20°, sinon à 12°.
	var w := _window_for(t, 12.0)
	if w.y >= w.x:
		return Vector3(w.x, w.y, 0.0)
	for need in [20.0, 12.0]:
		for k in [7, -7, 14, -14, 30, -30, 45, -45, 60, -60, 75, -75, 91, -91, 105, -105, 120, -120, 150, -150, 182]:
			w = _window_for(t + float(k) * 86400.0, need)
			if w.y >= w.x:
				return Vector3(w.x, w.y, float(k))
	return Vector3(12.0, 12.0, 182.0)


## Heures (locales) du jour de `t` où le Soleil dépasse JOUR_MIN_ELEV (ou la
## moitié de sa hauteur maximale, s'il monte peu). Renvoie début > fin si le
## Soleil ne monte pas jusqu'à `need` degrés ce jour-là.
func _window_for(t: float, need: float) -> Vector2:
	var off := Fuseaux.utc_offset(lat, lon, t) * 3600.0
	var midnight := floorf((t + off) / 86400.0) * 86400.0 - off
	var elevs := PackedFloat32Array()
	var best := -90.0
	for i in 96:
		var e := Astro.sun_horizontal(midnight + i * 900.0, lat, lon).x
		elevs.append(e)
		best = maxf(best, e)
	if best < need:
		return Vector2(1.0, 0.0)
	var limit := minf(JOUR_MIN_ELEV, best * 0.5)
	var a := 24.0
	var b := -1.0
	for i in 96:
		if elevs[i] >= limit:
			a = minf(a, i * 0.25)
			b = maxf(b, i * 0.25)
	return Vector2(a, b)


func local_datetime() -> Dictionary:
	return Time.get_datetime_dict_from_unix_time(int(unix_time + utc_offset() * 3600.0))


## Lever et coucher du Soleil du jour (heures locales), voir Astro.sun_rise_set.
func rise_set() -> Vector2:
	var day := int(floorf((unix_time + utc_offset() * 3600.0) / 86400.0))
	if day != _rise_set_day:
		_rise_set_day = day
		_rise_set = Astro.sun_rise_set(unix_time, lat, lon, utc_offset())
	return _rise_set


func _process(delta: float) -> void:
	var s: float = SPEEDS[speed_index]
	if s > 0.0:
		unix_time += delta * s
	# Jour permanent, à minuit : le Soleil repart du matin en glissant (1 à 2 s)
	# au lieu de sauter.
	var target := _target_shift()
	if absf(target - _shift) > 1800.0 and not _snap:
		_shift = lerpf(_shift, target, clampf(delta * 3.0, 0.0, 1.0))
	weather.update_weather(delta, unix_time, local_hour())
	_apply()
	_adapt_shadows()
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		var g := NAN
		if world != null:
			g = world.cell_height(Vector2i(floori(cam.global_position.x), floori(cam.global_position.z)))
		weather.follow(cam, 0.0 if is_nan(g) else maxf(g, 0.0))


# --- Lumières -------------------------------------------------------------------

## Couleurs du ciel selon la hauteur du Soleil (degrés) :
## [hauteur, zénith, horizon, ambiance, énergie ambiante, halo]
const SKY_KEYS := [
	[-18.0, Color(0.008, 0.012, 0.035), Color(0.02, 0.03, 0.07), Color(0.20, 0.26, 0.45), 0.22, 0.0],
	[-8.0, Color(0.03, 0.05, 0.14), Color(0.10, 0.10, 0.20), Color(0.24, 0.28, 0.48), 0.24, 0.25],
	[-3.0, Color(0.08, 0.12, 0.30), Color(0.55, 0.32, 0.30), Color(0.40, 0.38, 0.55), 0.30, 0.8],
	[2.0, Color(0.20, 0.32, 0.58), Color(0.98, 0.62, 0.40), Color(0.75, 0.62, 0.58), 0.38, 1.0],
	[10.0, Color(0.32, 0.52, 0.84), Color(0.88, 0.80, 0.72), Color(0.82, 0.82, 0.88), 0.42, 0.35],
	[30.0, Color(0.42, 0.64, 0.92), Color(0.78, 0.86, 0.93), Color(0.85, 0.88, 0.95), 0.45, 0.0],
]


static func sky_at(elev: float) -> Array:
	if elev <= SKY_KEYS[0][0]:
		return SKY_KEYS[0]
	for i in range(1, SKY_KEYS.size()):
		var b: Array = SKY_KEYS[i]
		if elev <= b[0]:
			var a: Array = SKY_KEYS[i - 1]
			var t := (elev - float(a[0])) / (float(b[0]) - float(a[0]))
			return [elev, (a[1] as Color).lerp(b[1], t), (a[2] as Color).lerp(b[2], t),
				(a[3] as Color).lerp(b[3], t), lerpf(a[4], b[4], t), lerpf(a[5], b[5], t)]
	return SKY_KEYS[SKY_KEYS.size() - 1]


## Couleur de la lumière du Soleil selon sa hauteur (degrés).
static func sun_color_at(elev: float) -> Color:
	var low := Color(1.0, 0.52, 0.28)
	var mid := Color(1.0, 0.84, 0.66)
	var high := Color(1.0, 0.96, 0.9)
	if elev < 6.0:
		return low.lerp(mid, clampf(elev / 6.0, 0.0, 1.0))
	return mid.lerp(high, clampf((elev - 6.0) / 24.0, 0.0, 1.0))


## 0 en plein jour, 1 en pleine nuit (le Soleil est 6° sous l'horizon).
static func night_factor(elev: float) -> float:
	return 1.0 - smoothstep(-6.0, 3.0, elev)


func _apply() -> void:
	var target := _target_shift()
	if _snap or absf(target - _shift) <= 1800.0:
		_shift = target
	_snap = false
	var t := display_time()
	sun_horiz = Astro.sun_horizontal(t, lat, lon)
	real_sun_elev = sun_horiz.x if _shift == 0.0 else Astro.sun_horizontal(unix_time, lat, lon).x
	moon_horiz = Astro.moon_horizontal(t, lat, lon)
	sun_dir = Astro.direction(sun_horiz)
	moon_dir = Astro.direction(moon_horiz)
	var elev := sun_horiz.x
	night = night_factor(elev)
	var illum := Astro.moon_illumination(t)

	# Météo : nuages qui voilent le Soleil, pluie et brouillard qui assombrissent.
	var cover := weather.cover if weather != null else 0.0
	var wet := maxf(weather.precip, weather.fog) if weather != null else 0.0
	var dim := lerpf(1.0, 0.22, pow(cover, 1.6)) * lerpf(1.0, 0.75, wet)
	if sun != null:
		var day := smoothstep(-1.5, 6.0, elev)
		sun.visible = day > 0.001
		if sun.visible:
			_aim(sun, sun_dir)
		sun.light_color = sun_color_at(elev)
		sun.light_energy = 1.05 * day * dim
		if rendu_pousse:
			# Heures dorées : soleil plus chaud et un peu plus fort quand il est bas.
			var golden := 1.0 - smoothstep(4.0, 22.0, elev)
			sun.light_color = sun.light_color.lerp(Color(1.0, 0.72, 0.45), golden * 0.45 * day)
			sun.light_energy = (1.15 + 0.35 * golden) * day * dim
		sun.shadow_enabled = day > 0.05
		sun.shadow_opacity = lerpf(1.0, 0.2, cover)

	# La Lune éclaire faiblement, surtout pleine et quand le Soleil est couché.
	var moon_up := smoothstep(-1.0, 5.0, moon_horiz.x)
	moon_light = (0.06 + 0.22 * illum) * moon_up * night * lerpf(1.0, 0.3, cover)
	moon.visible = moon_light > 0.002
	if moon.visible:
		_aim(moon, moon_dir)
	moon.light_energy = moon_light
	moon.shadow_enabled = moon_light > 0.08 and (sun == null or not sun.shadow_enabled)

	var k := sky_at(elev)
	if sky_material != null:
		sky_material.set_shader_parameter("zenith_color", k[1])
		sky_material.set_shader_parameter("horizon_color", k[2])
		sky_material.set_shader_parameter("ground_color", (k[2] as Color).darkened(0.45))
		sky_material.set_shader_parameter("glow_color", Color(1.0, 0.45, 0.22).lerp(Color(0.95, 0.6, 0.45), clampf((elev + 3.0) / 10.0, 0.0, 1.0)))
		sky_material.set_shader_parameter("glow_strength", k[5])
		sky_material.set_shader_parameter("sun_dir", sun_dir)
		sky_material.set_shader_parameter("sun_color", sun_color_at(elev))
		sky_material.set_shader_parameter("sun_visible", smoothstep(-1.5, 0.5, elev))
		sky_material.set_shader_parameter("moon_dir", moon_dir)
		sky_material.set_shader_parameter("moon_visible", smoothstep(-1.0, 1.0, moon_horiz.x) * lerpf(0.55, 1.0, night))
		sky_material.set_shader_parameter("stars", smoothstep(0.55, 1.0, night))
		sky_material.set_shader_parameter("star_basis", _star_basis(t))
		if weather != null:
			sky_material.set_shader_parameter("cloud_cover", weather.cover)
			sky_material.set_shader_parameter("cloud_dark", clampf(weather.precip * 0.8 + weather.storm * 0.4, 0.0, 1.0))
			sky_material.set_shader_parameter("cloud_offset", weather.cloud_offset)
			sky_material.set_shader_parameter("flash", weather.flash)
			sky_material.set_shader_parameter("haze", clampf(weather.fog + weather.precip * 0.5, 0.0, 1.0))
	if env != null:
		var grey := Color(0.62, 0.65, 0.7).darkened(0.85 * night)
		env.ambient_light_color = (k[3] as Color).lerp(grey, cover * 0.6)
		env.ambient_light_energy = float(k[4]) * lerpf(1.0, 1.25, cover) * lerpf(1.0, 0.8, wet)
		if weather != null and weather.flash > 0.0:
			env.ambient_light_energy += 2.5 * weather.flash
			env.ambient_light_color = env.ambient_light_color.lerp(Color(0.8, 0.85, 1.0), weather.flash)
		env.fog_light_color = (k[2] as Color).lerp(k[1], 0.25).lerp(grey, clampf(cover * 0.5 + wet, 0.0, 1.0))
		env.fog_density = maxf(_base_fog(), weather_fog())
		env.glow_intensity = lerpf(0.25, 1.1, night)
		env.glow_strength = lerpf(0.8, 1.15, night)
		env.tonemap_exposure = lerpf(1.0, 1.35, night)
		if rendu_pousse:
			_rendu_pousse_apply(k, elev)

	NightWindows.set_shared("night", night)
	NightWindows.set_shared("lit_ratio", NightWindows.lit_ratio_at(local_hour()))
	# Lampadaires et phares : la nuit, et aussi par brouillard ou grosse pluie.
	var dark := maxf(night, smoothstep(0.4, 0.9, wet) * 0.7)
	if street != null:
		street.set_night(smoothstep(0.25, 0.75, dark))
	if headlights != null:
		headlights.set_on(smoothstep(0.2, 0.6, dark))
	time_changed.emit()


## Partie variable du rendu poussé : exposition, brume au sol, rayons.
func _rendu_pousse_apply(k: Array, elev: float) -> void:
	env.tonemap_exposure = lerpf(1.08, 2.1, night)
	env.glow_bloom = 0.03
	brume = brume_du_matin()
	var sol := _sol_camera()
	var vue_sol := _vue_sol != null and int(_vue_sol.get("vue")) != 0
	if brume > 0.01:
		# Quantité de brume = 1 - exp(-(fog_height - y) × densité) : environ 45 %
		# au sol, rien au-dessus de 5 m. Sa couleur n'est pas éclairée : on la
		# règle sur la lumière du moment (blanc doré au lever, gris le jour).
		env.fog_height = sol + 1.0 + 4.0 * brume
		env.fog_height_density = 0.15 * brume
		var lum := Color(0.95, 0.88, 0.8).lerp(Color(0.86, 0.88, 0.91), clampf(elev / 15.0, 0.0, 1.0))
		lum = lum * lerpf(0.3, 1.0, smoothstep(-4.0, 8.0, elev))
		env.fog_light_color = Color(lum.r, lum.g, lum.b, 1.0)
		env.fog_sun_scatter = 0.35
	else:
		env.fog_height = -10000.0
		env.fog_height_density = 0.0
		env.fog_sun_scatter = 0.15
	# Rayons de soleil dans la brume (Forward+ seulement), en vue au sol
	# uniquement : vue de haut, la brume volumétrique ne fait qu'assombrir.
	env.volumetric_fog_enabled = vue_sol
	env.volumetric_fog_density = 0.0015 + 0.008 * brume
	env.volumetric_fog_albedo = Color(1.0, 0.95, 0.88)


## Brume de l'air par beau temps, vue de dessus : la moitié du paysage est
## voilée vers 4 km, l'horizon (10 km) se fond dans le ciel.
const HAZE_FOG := 0.00018


## Brouillard demandé par la météo (densité de l'environnement).
func weather_fog() -> float:
	if weather == null:
		return 0.0
	return HAZE_FOG + weather.fog * weather.fog * 0.014 + weather.precip * 0.0022


## Brouillard de base : celui de la vue au sol quand elle est active.
func _base_fog() -> float:
	if _vue_sol != null and int(_vue_sol.get("vue")) != 0:
		return float(_vue_sol.get("brouillard_sol"))
	return HAZE_FOG


## Oriente une lumière directionnelle pour qu'elle vienne de la direction `toward`.
static func _aim(light: DirectionalLight3D, toward: Vector3) -> void:
	var fwd := -toward.normalized()
	var up := Vector3.UP if absf(fwd.y) < 0.99 else Vector3.FORWARD
	light.global_basis = Basis.looking_at(fwd, up)


## Rotation du ciel étoilé : les étoiles tournent autour du pôle céleste
## (hauteur = latitude), une fois par jour sidéral.
func _star_basis(t: float) -> Basis:
	var n := Astro.days_j2000(t)
	var lst := deg_to_rad(Astro.local_sidereal(n, lon))
	# Axe du pôle Nord céleste dans le repère local (Nord = −Z).
	var phi := deg_to_rad(lat)
	var pole := Vector3(0.0, sin(phi), -cos(phi))
	return Basis(pole, lst)


## Les ombres couvrent ce que montre la caméra : plus loin quand on dézoome.
func _adapt_shadows() -> void:
	var lit := sun if sun != null and sun.shadow_enabled else moon
	if lit == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var h := cam.global_position.y
	if world != null:
		var g := world.cell_height(Vector2i(floori(cam.global_position.x), floori(cam.global_position.z)))
		if not is_nan(g):
			h -= maxf(g, 0.0)
	var want := clampf(h * 3.2 + 60.0, 90.0, 650.0)
	lit.directional_shadow_max_distance = lerpf(lit.directional_shadow_max_distance, want, 0.15)


# --- Sauvegarde -----------------------------------------------------------------

func to_dict() -> Dictionary:
	return {"unix": unix_time, "vitesse": speed_index, "meteo": weather.to_dict(), "jour_permanent": jour_permanent, "jour_auto": jour_auto}


func from_dict(d: Dictionary) -> void:
	if d.has("unix"):
		unix_time = float(d.unix)
	if d.has("vitesse"):
		speed_index = clampi(int(d.vitesse), 0, SPEEDS.size() - 1)
	if d.has("meteo"):
		weather.from_dict(d.meteo)
	var before := jour_actif()
	jour_permanent = bool(d.get("jour_permanent", false))
	jour_auto = bool(d.get("jour_auto", true))
	if jour_actif() != before:
		jour_permanent_changed.emit(jour_actif())
	_rise_set_day = -1
	_jp_day = -2147483648
	_snap = true
	_apply()
