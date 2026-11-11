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
		var g := BuildingCatalog.GLASS
		_material.set_shader_parameter("window_color", Vector3(g.r, g.g, g.b))
	return _material


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
