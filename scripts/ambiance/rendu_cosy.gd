class_name RenduCosy
extends RefCounted
## Rendu « cosy » : la ville comme une maquette douce et chaleureuse.
##
## Par-dessus le rendu poussé (DayNight.rendu_pousse), sans rien changer aux
## modèles :
## - le jour : soleil crème, ombres bleutées et claires (lumière du ciel), occlusion
##   ambiante qui marque les coins et le pied des murs, ciel pastel, brume légère
##   bleu lavande au loin, tons ACES (couleurs franches) ;
## - les heures dorées et le crépuscule : orangé et rose, longues ombres ;
## - la nuit : bleu nuit clair au lieu du noir, fenêtres et lampadaires plus
##   chauds avec un halo (bloom) ;
## - le sol : champs et terre un peu moins saturés et moins sombres, quadrillage
##   plus discret (voir terrain.gdshader, uniforme `douceur`) ;
## - en option, l'effet maquette (tilt-shift) : flou au premier plan et au loin,
##   net là où regarde la caméra.
##
## Coût : réglages d'environnement seulement, sauf l'éclairage indirect (SSIL)
## réservé à la qualité « Haute » et l'effet maquette (flou de profondeur).
## Désactivé : rendu d'avant exactement (rendu poussé seul).

## Rendu cosy allumé (OptionsJeu.rendu_cosy).
static var actif := true
## 0 = léger (sans éclairage indirect), 1 = haut (SSIL, ombres plus douces).
static var qualite := 0
## Effet maquette (tilt-shift) en vue de dessus.
static var maquette := false
## Force de l'effet maquette (0 à 1).
static var maquette_force := 0.6

## Réglages fins (modifiables pour essayer : tests/cosy_vitrine.gd --variantes).
static var tonemap := Environment.TONE_MAPPER_ACES
static var saturation := 1.14
static var contraste := 1.05
static var exposition := 1.04
static var douceur_sol := 1.0

## Couleurs du ciel du rendu cosy, comme DayNight.SKY_KEYS :
## [hauteur du Soleil, zénith, horizon, ambiance, énergie ambiante, halo].
## Ambiance = couleur des ombres : bleu ciel clair le jour, bleu nuit la nuit.
const SKY_KEYS := [
	[-18.0, Color(0.020, 0.032, 0.085), Color(0.050, 0.070, 0.150), Color(0.32, 0.40, 0.72), 0.46, 0.0],
	[-8.0, Color(0.050, 0.075, 0.190), Color(0.150, 0.140, 0.270), Color(0.36, 0.40, 0.70), 0.44, 0.3],
	[-3.0, Color(0.120, 0.160, 0.380), Color(0.720, 0.420, 0.420), Color(0.50, 0.46, 0.68), 0.38, 0.9],
	[2.0, Color(0.260, 0.380, 0.650), Color(1.000, 0.660, 0.460), Color(0.80, 0.66, 0.66), 0.46, 1.0],
	[10.0, Color(0.360, 0.560, 0.880), Color(0.960, 0.840, 0.740), Color(0.74, 0.78, 0.92), 0.56, 0.4],
	[30.0, Color(0.400, 0.640, 0.940), Color(0.820, 0.900, 0.960), Color(0.70, 0.80, 0.98), 0.62, 0.0],
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


## Couleur du Soleil : crème le jour, abricot puis corail quand il est bas.
static func sun_color_at(elev: float) -> Color:
	var low := Color(1.0, 0.56, 0.36)
	var mid := Color(1.0, 0.80, 0.60)
	var high := Color(1.0, 0.94, 0.84)
	if elev < 8.0:
		return low.lerp(mid, clampf(elev / 8.0, 0.0, 1.0))
	return mid.lerp(high, clampf((elev - 8.0) / 22.0, 0.0, 1.0))


## Réglages fixes (une fois, à la création de l'environnement).
static func init_env(env: Environment, sun: DirectionalLight3D) -> void:
	env.tonemap_mode = tonemap
	env.tonemap_white = 4.0
	# Occlusion ambiante : coins, pied des murs, dessous des toits.
	env.ssao_enabled = true
	env.ssao_radius = 2.2
	env.ssao_intensity = 2.6
	env.ssao_power = 1.4
	env.ssao_detail = 0.6
	env.ssao_horizon = 0.06
	env.ssao_sharpness = 0.98
	# Un peu d'occlusion même au soleil : les volumes se lisent mieux.
	env.ssao_light_affect = 0.18
	env.ssao_ao_channel_affect = 0.0
	# Éclairage indirect (lumière qui rebondit sur les façades) en qualité haute.
	env.ssil_enabled = qualite >= 1
	env.ssil_radius = 6.0
	env.ssil_intensity = 0.8
	env.ssil_sharpness = 0.98
	# Halo doux, large (niveaux 3 à 5), surtout la nuit.
	env.glow_enabled = true
	env.glow_normalized = true
	env.set_glow_level(0, 0.0)
	env.set_glow_level(1, 0.0)
	env.set_glow_level(2, 0.4)
	env.set_glow_level(3, 1.0)
	env.set_glow_level(4, 0.8)
	env.set_glow_level(5, 0.5)
	env.set_glow_level(6, 0.0)
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.glow_hdr_threshold = 0.85
	env.glow_hdr_scale = 2.0
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.0
	env.adjustment_contrast = contraste
	env.adjustment_saturation = saturation
	env.fog_aerial_perspective = 0.5
	env.fog_sky_affect = 0.2
	if sun != null:
		# Ombres aux bords plus doux.
		sun.light_angular_distance = 1.2 if qualite >= 1 else 0.8
		sun.shadow_blur = 1.6


## Couleurs douces du sol (proche et lointain).
static func init_terrain(world: TerrainWorld) -> void:
	if world == null:
		return
	var v := douceur_sol if actif else 0.0
	if world._material != null:
		world._material.set_shader_parameter("douceur", v)
	if world.horizon != null and world.horizon._material != null:
		world.horizon._material.set_shader_parameter("douceur", v)
	# Eau turquoise et claire (rivières, lacs, mer).
	var mats: Array = [world._water_material]
	if world._water != null:
		mats.append(world._water.material_override)
	for m in mats:
		if m is ShaderMaterial:
			(m as ShaderMaterial).set_shader_parameter("deep_color", Color(0.09, 0.40, 0.56) if actif else Color(0.07, 0.30, 0.48))
			(m as ShaderMaterial).set_shader_parameter("shallow_color", Color(0.30, 0.74, 0.76) if actif else Color(0.26, 0.58, 0.66))


## Réglages qui suivent l'heure, la météo et la nuit (à chaque image).
## `k` = sky_at(elev) ; `dim` = voile des nuages et de la pluie.
static func apply(dn: DayNight, k: Array, elev: float, dim: float) -> void:
	var env := dn.env
	var night := dn.night
	var day := smoothstep(-1.5, 6.0, elev)
	var golden := 1.0 - smoothstep(4.0, 24.0, elev)
	if dn.sun != null:
		dn.sun.light_color = sun_color_at(elev)
		dn.sun.light_energy = (1.30 + 0.25 * golden) * day * dim
	if env == null:
		return
	# Brume de l'air : bleu lavande le jour, pêche au coucher, bleu nuit la nuit.
	var cover := dn.weather.cover if dn.weather != null else 0.0
	var haze := Color(0.70, 0.80, 0.98).lerp(Color(1.0, 0.74, 0.60), golden * day)
	haze = haze.lerp(Color(0.10, 0.13, 0.26), night)
	if dn.brume <= 0.01:
		env.fog_light_color = haze.lerp(Color(0.62, 0.65, 0.70).darkened(0.85 * night), cover * 0.6)
	# Exposition : le jour un peu plus clair (AgX est plus sombre qu'ACES), la nuit
	# assez claire pour voir la ville, sans perdre la couleur des fenêtres.
	env.tonemap_exposure = lerpf(exposition, exposition + 0.7, night)
	# Halo : discret le jour (reflets du soleil), large et chaud la nuit.
	env.glow_intensity = lerpf(0.35, 0.9, night)
	env.glow_strength = lerpf(0.9, 1.1, night)
	env.glow_bloom = lerpf(0.02, 0.07, night)
	env.glow_hdr_threshold = lerpf(1.1, 0.7, night)
	env.adjustment_saturation = saturation + 0.1 * night
	NightWindows.set_shared("glow_energy", lerpf(2.4, 3.6, night))
	if dn.street != null:
		dn.street.energie = 4.6
	_maquette(dn)


## Effet maquette (tilt-shift) : net autour du point visé par la caméra de
## gestion, flou devant et derrière. Coupé en vue au sol et en mode photo (qui a
## son propre flou).
static func _maquette(dn: DayNight) -> void:
	var cam := dn.get_viewport().get_camera_3d() if dn.is_inside_tree() else null
	if cam == null:
		return
	var vue_sol := dn._vue_sol != null and int(dn._vue_sol.get("vue")) != 0
	var on := actif and maquette and not vue_sol and cam.name != "CameraPhoto"
	var attrs := cam.attributes as CameraAttributesPractical
	if attrs == null:
		if not on:
			return
		attrs = CameraAttributesPractical.new()
		cam.attributes = attrs
	if not on:
		if attrs.has_meta("maquette"):
			attrs.dof_blur_far_enabled = false
			attrs.dof_blur_near_enabled = false
			attrs.remove_meta("maquette")
		return
	attrs.set_meta("maquette", true)
	# Distance du point visé (centre de l'écran) : le pivot de la caméra.
	var rig := cam.get_parent()
	var d := cam.global_position.distance_to((rig as Node3D).global_position) if rig is Node3D else 150.0
	d = clampf(d, 20.0, 1500.0)
	attrs.dof_blur_far_enabled = true
	attrs.dof_blur_far_distance = d * 1.15
	attrs.dof_blur_far_transition = d * 0.9
	attrs.dof_blur_near_enabled = true
	attrs.dof_blur_near_distance = d * 0.8
	attrs.dof_blur_near_transition = d * 0.5
	attrs.dof_blur_amount = 0.06 + 0.12 * maquette_force
