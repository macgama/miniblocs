class_name NightWindows
extends RefCounted
## Matériau partagé de tous les bâtiments : couleurs par sommet et fenêtres qui
## s'allument la nuit (voir batiment.gdshader). DayNight règle `night` et
## `lit_ratio` à chaque image.

static var _material: ShaderMaterial


static func building_material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = load("res://scripts/ambiance/batiment.gdshader")
		var cols := window_colors()
		var arr := PackedVector3Array()
		for c in cols:
			arr.append(Vector3(c.r, c.g, c.b))
		_material.set_shader_parameter("window_colors", arr)
		_material.set_shader_parameter("window_count", arr.size())
		_material.set_shader_parameter("compat", RenderingServer.get_rendering_device() == null)
	return _material


static var _chantier: ShaderMaterial
## Variantes d'usure : "u|a" -> matériau (usure et abandon en paliers).
static var _variants := {}


## Règle un paramètre partagé (nuit, part des fenêtres allumées) sur le
## matériau des bâtiments et toutes ses variantes d'usure.
static func set_shared(param: String, value: Variant) -> void:
	building_material().set_shader_parameter(param, value)
	for m: ShaderMaterial in _variants.values():
		m.set_shader_parameter(param, value)


## Matériau d'un bâtiment usé : usure en paliers de 0 à 5, abandon de 0 à 4.
## (0, 0) = le matériau commun.
static func variant_material(usure_q: int, abandon_q: int) -> ShaderMaterial:
	if usure_q <= 0 and abandon_q <= 0:
		return building_material()
	var key := "%d|%d" % [usure_q, abandon_q]
	if not _variants.has(key):
		var m := building_material().duplicate() as ShaderMaterial
		m.set_shader_parameter("usure", usure_q / 5.0)
		m.set_shader_parameter("abandon", abandon_q / 4.0)
		_variants[key] = m
	return _variants[key]


## Matériau propre à un chantier (sa hauteur construite lui est propre).
static func chantier_copy() -> ShaderMaterial:
	return chantier_material().duplicate() as ShaderMaterial


## Matériau des bâtiments en chantier : le même, mais les faces arrière sont
## dessinées (on voit l'intérieur brut au-dessus de la partie construite).
## Fenêtres éteintes : personne n'habite encore là.
static func chantier_material() -> ShaderMaterial:
	if _chantier == null:
		var base := building_material()
		var sh := Shader.new()
		sh.code = (base.shader as Shader).code.replace("shader_type spatial;", "shader_type spatial;\nrender_mode cull_disabled;")
		_chantier = ShaderMaterial.new()
		_chantier.shader = sh
		for key in ["window_colors", "window_count", "compat"]:
			_chantier.set_shader_parameter(key, base.get_shader_parameter(key))
		_chantier.set_shader_parameter("interieurs", false)
	return _chantier


## Couleurs de vitres reconnues comme fenêtres (32 au maximum).
static func window_colors() -> Array[Color]:
	var out: Array[Color] = []
	# Vitres du catalogue de base, porte vitrée, façades vitrées de bureaux.
	for c in [BuildingCatalog.GLASS, Color("1d2d3c"), Color("8fb8d8"), Color("6d97b8"), Color("4f6d8f")]:
		_add_unique(out, c)
	# Vitres de chaque style de la bible.
	for sid in Styles.STYLES:
		var g = (Styles.STYLES[sid] as Dictionary).get("glass", null)
		if g != null:
			_add_unique(out, Color(g))
	return out.slice(0, 32)


static func _add_unique(list: Array[Color], c: Color) -> void:
	for o in list:
		if o.is_equal_approx(c):
			return
	list.append(c)


## Part des fenêtres allumées selon l'heure locale (heures décimales).
static func lit_ratio_at(hour: float) -> float:
	# Soirée animée, nuit calme, petit regain au réveil.
	var keys := [[0.0, 0.25], [1.5, 0.12], [5.0, 0.08], [6.5, 0.45], [8.5, 0.3], [17.0, 0.55], [19.5, 0.75], [22.5, 0.55], [24.0, 0.25]]
	for i in range(1, keys.size()):
		if hour <= keys[i][0]:
			var a: Array = keys[i - 1]
			var b: Array = keys[i]
			return lerpf(a[1], b[1], (hour - a[0]) / (b[0] - a[0]))
	return 0.25
