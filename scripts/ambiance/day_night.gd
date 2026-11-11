class_name DayNight
extends Node
## Cycle jour/nuit du mode Terre.
##
## - Une horloge de jeu (date et heure réelles, en UTC) avance à la vitesse
##   choisie : pause, temps réel, 1 min/s, 10 min/s ou 1 h/s.
## - Le Soleil et la Lune sont placés à leur vraie position dans le ciel pour la
##   latitude et la longitude du lieu choisi sur le globe (saisons, nuits
##   polaires, phases de la Lune comprises).
## - Ciel, brume, lumière ambiante et couleur du soleil suivent la hauteur du
##   Soleil (aube, journée, coucher, crépuscule, nuit étoilée).
## - La nuit : lampadaires le long des voies et fenêtres allumées.
## - Les ombres s'adaptent au zoom de la caméra.

signal time_changed

## Vitesses proposées (secondes de jeu par seconde réelle).
const SPEEDS := [0.0, 1.0, 60.0, 600.0, 3600.0]
const SPEED_NAMES := ["Pause", "Temps réel", "1 min/s", "10 min/s", "1 h/s"]
const DEFAULT_SPEED := 2
const START_HOUR := 10.0

@export var sun_path: NodePath
@export var environment_path: NodePath
@export var transport_path: NodePath
@export var world_path: NodePath

var sun: DirectionalLight3D
var moon: DirectionalLight3D
var env: Environment
var world: TerrainWorld
var street: StreetLights
var sky_material: ShaderMaterial
var hud: ClockHud

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


## Démarre aujourd'hui (date de l'ordinateur), à 10 h, heure du lieu.
func _start_today() -> void:
	var now := Time.get_unix_time_from_system()
	var off := Astro.utc_offset(lat, lon, now) * 3600.0
	var local_midnight := floorf((now + off) / 86400.0) * 86400.0
	unix_time = local_midnight + START_HOUR * 3600.0 - off


func set_place(a: float, o: float) -> void:
	lat = a
	lon = o
	_rise_set_day = -1
	_apply()


## Décalage horaire du lieu (heures).
func utc_offset() -> float:
	return Astro.utc_offset(lat, lon, unix_time)


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
	_apply()


## Avance ou recule la date d'un nombre de jours (même heure).
func shift_days(days: int) -> void:
	unix_time += days * 86400.0
	_apply()


func set_speed(i: int) -> void:
	speed_index = clampi(i, 0, SPEEDS.size() - 1)
	time_changed.emit()


func toggle_pause() -> void:
	if speed_index == 0:
		set_speed(DEFAULT_SPEED)
	else:
		set_speed(0)


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
		_apply()
	_adapt_shadows()


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
	sun_horiz = Astro.sun_horizontal(unix_time, lat, lon)
	moon_horiz = Astro.moon_horizontal(unix_time, lat, lon)
	sun_dir = Astro.direction(sun_horiz)
	moon_dir = Astro.direction(moon_horiz)
	var elev := sun_horiz.x
	night = night_factor(elev)
	var illum := Astro.moon_illumination(unix_time)

	if sun != null:
		var day := smoothstep(-1.5, 6.0, elev)
		sun.visible = day > 0.001
		if sun.visible:
			_aim(sun, sun_dir)
		sun.light_color = sun_color_at(elev)
		sun.light_energy = 1.05 * day
		sun.shadow_enabled = day > 0.05

	# La Lune éclaire faiblement, surtout pleine et quand le Soleil est couché.
	var moon_up := smoothstep(-1.0, 5.0, moon_horiz.x)
	moon_light = (0.06 + 0.22 * illum) * moon_up * night
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
		sky_material.set_shader_parameter("star_basis", _star_basis())
	if env != null:
		env.ambient_light_color = k[3]
		env.ambient_light_energy = k[4]
		env.fog_light_color = (k[2] as Color).lerp(k[1], 0.25)
		env.glow_intensity = lerpf(0.25, 1.1, night)
		env.glow_strength = lerpf(0.8, 1.15, night)
		env.tonemap_exposure = lerpf(1.0, 1.35, night)

	var mat := NightWindows.building_material()
	mat.set_shader_parameter("night", night)
	mat.set_shader_parameter("lit_ratio", NightWindows.lit_ratio_at(local_hour()))
	if street != null:
		street.set_night(smoothstep(0.25, 0.75, night))
	time_changed.emit()


## Oriente une lumière directionnelle pour qu'elle vienne de la direction `toward`.
static func _aim(light: DirectionalLight3D, toward: Vector3) -> void:
	var fwd := -toward.normalized()
	var up := Vector3.UP if absf(fwd.y) < 0.99 else Vector3.FORWARD
	light.global_basis = Basis.looking_at(fwd, up)


## Rotation du ciel étoilé : les étoiles tournent autour du pôle céleste
## (hauteur = latitude), une fois par jour sidéral.
func _star_basis() -> Basis:
	var n := Astro.days_j2000(unix_time)
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
	return {"unix": unix_time, "vitesse": speed_index}


func from_dict(d: Dictionary) -> void:
	if d.has("unix"):
		unix_time = float(d.unix)
	if d.has("vitesse"):
		speed_index = clampi(int(d.vitesse), 0, SPEEDS.size() - 1)
	_rise_set_day = -1
	_apply()
