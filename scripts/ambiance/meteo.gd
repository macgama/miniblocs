class_name Meteo
extends Node3D
## Météo du mode Terre : nuages, pluie, neige, brouillard, orages.
##
## - Climat du lieu : température moyenne selon la latitude, la saison, l'heure
##   et l'altitude ; humidité selon les biomes réels autour du point de départ
##   (forêt, marais : humide ; désert, roche : sec).
## - Le temps qu'il fait vient d'un bruit lissé sur la date et le lieu : il est
##   le même pour tous les joueurs au même endroit au même moment (utile pour
##   le multijoueur), change toutes les quelques heures et passe en douceur
##   d'un état à l'autre.
## - Sous 1 °C, la pluie devient neige. Brouillard surtout le matin, par temps
##   humide et frais. Orages par temps chaud et très pluvieux (éclairs).
## - Mode manuel : on peut forcer un temps (bac à sable).

enum Mode { AUTO, SOLEIL, NUAGEUX, COUVERT, PLUIE, ORAGE, NEIGE, BROUILLARD }
const MODE_NAMES := ["Automatique", "Ensoleillé", "Nuageux", "Couvert", "Pluie", "Orage", "Neige", "Brouillard"]
## Valeurs forcées par mode : [nuages, précipitations, brouillard, orage, neige forcée]
const PRESETS := {
	Mode.SOLEIL: [0.05, 0.0, 0.0, 0.0, false],
	Mode.NUAGEUX: [0.5, 0.0, 0.0, 0.0, false],
	Mode.COUVERT: [0.92, 0.0, 0.1, 0.0, false],
	Mode.PLUIE: [1.0, 0.7, 0.15, 0.0, false],
	Mode.ORAGE: [1.0, 1.0, 0.1, 1.0, false],
	Mode.NEIGE: [1.0, 0.7, 0.2, 0.0, true],
	Mode.BROUILLARD: [0.7, 0.0, 1.0, 0.0, false],
}
## Humidité typique de chaque biome WorldCover.
const BIOME_HUMIDITY := {10: 0.68, 20: 0.35, 30: 0.5, 40: 0.5, 50: 0.5, 60: 0.08, 70: 0.5,
	80: 0.62, 90: 0.78, 95: 0.85, 100: 0.55}

var mode: Mode = Mode.AUTO
## État courant (lissé), lu par DayNight.
var cover := 0.2      ## nuages, 0 à 1
var precip := 0.0     ## intensité de pluie ou de neige, 0 à 1
var snow := 0.0       ## part de neige dans les précipitations, 0 à 1
var fog := 0.0        ## brouillard, 0 à 1
var storm := 0.0      ## orage, 0 à 1
var flash := 0.0      ## éclair en cours, 0 à 1
var temperature := 15.0
var humidity := 0.5
## Décalage des nuages poussés par le vent (pour le ciel).
var cloud_offset := Vector2.ZERO

var world: TerrainWorld
var _lat := 48.85
var _lon := 2.3
var _altitude := 0.0
var _climate_ok := false
var _climate_timer := 0.0
var _rain: GPUParticles3D
var _snow: GPUParticles3D
var _flash_timer := 6.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rain = _make_rain()
	add_child(_rain)
	_snow = _make_snow()
	add_child(_snow)


func set_place(lat: float, lon: float) -> void:
	_lat = lat
	_lon = lon
	_climate_ok = false
	_climate_timer = 0.0
	humidity = default_humidity(lat)
	_snap = true


## Humidité par défaut selon la latitude (avant de connaître les biomes) :
## sec sous les tropiques (déserts), humide à l'équateur et aux latitudes moyennes.
static func default_humidity(lat: float) -> float:
	var a := absf(lat)
	return clampf(0.62 - 0.32 * exp(-pow((a - 25.0) / 8.0, 2.0)), 0.1, 0.9)


## Température de l'air (°C) : latitude, saison, heure, altitude.
static func air_temperature(lat: float, unix: float, local_hour: float, altitude: float) -> float:
	var a := absf(lat)
	var mean := 27.0 - 0.45 * maxf(a - 12.0, 0.0)
	var amp := 0.18 * a
	var day_of_year := fposmod(unix / 86400.0 - 14.0, 365.25) # 0 vers le 15 janvier
	var season := -cos(day_of_year / 365.25 * TAU) # -1 au cœur de l'hiver boréal
	if lat < 0.0:
		season = -season
	var daily := 4.0 * cos((local_hour - 15.0) / 24.0 * TAU)
	return mean + amp * season + daily - 6.5 * maxf(altitude, 0.0) / 1000.0


## Bruit lissé à une dimension (0 à 1), reproductible.
static func smooth_noise(t: float, seed: int) -> float:
	var i := floori(t)
	var f := t - i
	f = f * f * (3.0 - 2.0 * f)
	return lerpf(_hash01(i, seed), _hash01(i + 1, seed), f)


static func _hash01(i: int, seed: int) -> float:
	var h := hash(Vector2i(i, seed))
	return float(h & 0xFFFF) / 65535.0


## Temps « naturel » à un instant : [nuages, précipitations, brouillard, orage].
static func natural(unix: float, lat: float, lon: float, hum: float, temp: float, local_hour: float) -> Array:
	var seed := hash(Vector2i(roundi(lat * 2.0), roundi(lon * 2.0)))
	var hours := unix / 3600.0
	var big := smooth_noise(hours / 30.0, seed)
	var mid := smooth_noise(hours / 9.0, seed + 1)
	var small := smooth_noise(hours / 3.0, seed + 2)
	var w := big * 0.5 + mid * 0.35 + small * 0.15 + (hum - 0.5) * 0.7
	var cov := smoothstep(0.28, 0.72, w)
	var pr := smoothstep(0.6, 0.85, w) * clampf(hum * 1.6, 0.0, 1.0)
	var morning := 1.0 - smoothstep(0.0, 4.0, absf(local_hour - 6.5))
	var fg := smoothstep(0.55, 0.85, smooth_noise(hours / 14.0, seed + 3) + hum * 0.25) * morning
	fg *= 1.0 - smoothstep(14.0, 22.0, temp)
	var st := smoothstep(0.75, 0.95, pr) * smoothstep(17.0, 24.0, temp)
	return [cov, pr, fg, st]


## Passe tout de suite au temps voulu (début de partie, changement de lieu, tests).
func settle(unix: float, local_hour: float) -> void:
	_snap = true
	update_weather(0.0, unix, local_hour)


var _snap := true


func update_weather(delta: float, unix: float, local_hour: float) -> void:
	_update_climate(delta)
	temperature = air_temperature(_lat, unix, local_hour, _altitude)
	var target: Array
	var force_snow := false
	if mode == Mode.AUTO:
		target = natural(unix, _lat, _lon, humidity, temperature, local_hour)
	else:
		var p: Array = PRESETS[mode]
		target = [p[0], p[1], p[2], p[3]]
		force_snow = p[4]
	var k := 1.0 if _snap else clampf(delta * 0.6, 0.0, 1.0)
	_snap = false
	cover = lerpf(cover, target[0], k)
	precip = lerpf(precip, target[1], k)
	fog = lerpf(fog, target[2], k)
	storm = lerpf(storm, target[3], k)
	if force_snow:
		temperature = minf(temperature, -1.0) # neige forcée : il fait froid
	var want_snow := 1.0 if force_snow else 1.0 - smoothstep(0.0, 2.0, temperature)
	if mode in [Mode.PLUIE, Mode.ORAGE]:
		want_snow = 0.0
	snow = lerpf(snow, want_snow, k)
	cloud_offset += Vector2(0.004, 0.0015) * delta * (1.0 + storm * 2.0)
	_update_flash(delta)


func _update_climate(delta: float) -> void:
	if _climate_ok or world == null:
		return
	_climate_timer -= delta
	if _climate_timer > 0.0:
		return
	_climate_timer = 2.0
	var alt := world.raw_height(0.5, 0.5)
	if not is_nan(alt):
		_altitude = alt
	var total := 0.0
	var n := 0
	for i in range(-4, 5):
		for j in range(-4, 5):
			var b := world.cell_biome(Vector2i(i * 500, j * 500))
			if BIOME_HUMIDITY.has(b):
				total += float(BIOME_HUMIDITY[b])
				n += 1
	if n >= 20:
		# Biomes réels, tempérés par la latitude (déserts tropicaux).
		humidity = clampf(lerpf(total / n, default_humidity(_lat), 0.3), 0.05, 0.95)
		_snap = true
		_climate_ok = not is_nan(alt)


func _update_flash(delta: float) -> void:
	flash = maxf(flash - delta * 6.0, 0.0)
	if storm < 0.3:
		return
	_flash_timer -= delta
	if _flash_timer <= 0.0:
		flash = 1.0
		_flash_timer = _rng.randf_range(3.0, 12.0) / storm


## Fait suivre la pluie et la neige à la caméra.
func follow(cam: Camera3D, ground_y: float) -> void:
	if cam == null:
		return
	var h := maxf(cam.global_position.y - ground_y, 2.0)
	var size := clampf(h * 0.8, 30.0, 140.0)
	var rain_amount := precip * (1.0 - snow)
	var snow_amount := precip * snow
	_rain.emitting = rain_amount > 0.02
	_rain.amount_ratio = clampf(rain_amount, 0.0, 1.0)
	_snow.emitting = snow_amount > 0.02
	_snow.amount_ratio = clampf(snow_amount, 0.0, 1.0)
	var p := cam.global_position
	var top := minf(p.y + 20.0, ground_y + h * 0.5 + 25.0)
	_rain.global_position = Vector3(p.x, top, p.z) - cam.global_basis.z * size * 0.4
	_snow.global_position = _rain.global_position
	(_rain.process_material as ParticleProcessMaterial).emission_box_extents = Vector3(size, 1.0, size)
	(_snow.process_material as ParticleProcessMaterial).emission_box_extents = Vector3(size, 6.0, size)


func describe() -> String:
	if fog > 0.6:
		return "Brouillard"
	if precip > 0.15:
		if snow > 0.5:
			return "Neige" if precip > 0.4 else "Quelques flocons"
		if storm > 0.5:
			return "Orage"
		return "Pluie" if precip > 0.4 else "Bruine"
	if cover > 0.8:
		return "Couvert"
	if cover > 0.4:
		return "Nuageux"
	if cover > 0.15:
		return "Éclaircies"
	return "Dégagé"


func _make_rain() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Pluie"
	p.amount = 9000
	p.lifetime = 2.2
	p.local_coords = false
	p.emitting = false
	p.visibility_aabb = AABB(Vector3(-160, -60, -160), Vector3(320, 80, 320))
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(60, 1, 60)
	m.direction = Vector3(0.08, -1, 0.03)
	m.spread = 2.0
	m.initial_velocity_min = 14.0
	m.initial_velocity_max = 17.0
	m.gravity = Vector3(0, -9.8, 0)
	p.process_material = m
	var q := QuadMesh.new()
	q.size = Vector2(0.025, 0.75)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.75, 0.82, 0.92, 0.38)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mat.billboard_keep_scale = true
	q.material = mat
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


func _make_snow() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Neige"
	p.amount = 7000
	p.lifetime = 14.0
	p.preprocess = 6.0
	p.local_coords = false
	p.emitting = false
	p.visibility_aabb = AABB(Vector3(-160, -60, -160), Vector3(320, 80, 320))
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(60, 6, 60)
	m.direction = Vector3(0.2, -1, 0.1)
	m.spread = 15.0
	m.initial_velocity_min = 1.0
	m.initial_velocity_max = 1.8
	m.gravity = Vector3(0, -0.6, 0)
	m.turbulence_enabled = true
	m.turbulence_noise_strength = 0.6
	m.turbulence_noise_scale = 4.0
	p.process_material = m
	var q := QuadMesh.new()
	q.size = Vector2(0.07, 0.07)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1, 1, 1, 0.9)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	q.material = mat
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


func to_dict() -> Dictionary:
	return {"mode": int(mode)}


func from_dict(d: Dictionary) -> void:
	mode = clampi(int(d.get("mode", 0)), 0, MODE_NAMES.size() - 1) as Mode
