class_name StreetLights
extends Node3D
## Lampadaires le long des routes et des chemins, allumés la nuit.
##
## - Les poteaux sont posés automatiquement : un tous les 32 m sur les routes
##   (en quinconce, un côté puis l'autre), un tous les 24 m sur les chemins.
##   Rien dans les tunnels ni sur les voies ferrées et les voies d'eau.
## - Tous les poteaux sont dessinés en une seule fois (MultiMesh) : quelques
##   milliers ne coûtent presque rien.
## - Les têtes brillent la nuit. Seuls les lampadaires les plus proches de la
##   caméra projettent une vraie lumière au sol (projecteurs recyclés), pour
##   garder un jeu fluide même avec des kilomètres de routes.

const ROAD_SPACING := 32.0
const PATH_SPACING := 24.0
const PATH_SCALE := 0.55
## Nombre maximal de vraies lumières au sol.
const MAX_LIGHTS := 48
const LIGHT_RADIUS := 260.0
## Hauteur et portée du bras (repère du poteau, bras vers +X).
const HEAD := Vector3(1.6, 7.45, 0.0)

var transport: TransportSystem
## Position de chaque tête de lampadaire (repère du monde).
var heads := PackedVector3Array()
var night := 0.0

var _multimesh: MultiMesh
var _mm_instance: MultiMeshInstance3D
var _head_material: StandardMaterial3D
var _lights: Array[SpotLight3D] = []
var _timer := 0.0
var _dirty := true


func _ready() -> void:
	var pole_mat := StandardMaterial3D.new()
	pole_mat.vertex_color_use_as_albedo = true
	pole_mat.vertex_color_is_srgb = true
	pole_mat.roughness = 0.6
	pole_mat.metallic = 0.4
	_head_material = StandardMaterial3D.new()
	_head_material.albedo_color = Color("d8d2c0")
	_head_material.emission_enabled = true
	_head_material.emission = Color(1.0, 0.8, 0.5)
	_head_material.emission_energy_multiplier = 0.0
	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.mesh = lamp_mesh(pole_mat, _head_material)
	_mm_instance = MultiMeshInstance3D.new()
	_mm_instance.name = "Lampadaires"
	_mm_instance.multimesh = _multimesh
	add_child(_mm_instance)
	for i in MAX_LIGHTS:
		var l := SpotLight3D.new()
		l.light_color = Color(1.0, 0.82, 0.58)
		l.spot_range = 17.0
		l.spot_angle = 62.0
		l.spot_attenuation = 0.8
		l.spot_angle_attenuation = 1.6
		l.shadow_enabled = false
		l.light_energy = 0.0
		l.rotation_degrees = Vector3(-90, 0, 0)
		l.visible = false
		add_child(l)
		_lights.append(l)
	if transport != null:
		transport.network_changed.connect(func() -> void: _dirty = true)


## Modèle d'un lampadaire : poteau + bras (surface 0), tête lumineuse (surface 1).
static func lamp_mesh(pole_mat: Material, head_mat: Material) -> ArrayMesh:
	var k := BlocMesh.new()
	var grey := Color("5d6168")
	k.box(0, 0, 0, 0.36, 0.5, 0.36, grey.darkened(0.2))
	k.box(0, 0.5, 0, 0.18, 7.3, 0.18, grey)
	k.box(HEAD.x / 2.0, 7.65, 0, HEAD.x + 0.1, 0.12, 0.12, grey)
	var mesh := k.to_mesh(pole_mat)
	var h := BlocMesh.new()
	h.box(HEAD.x, 7.42, 0, 0.75, 0.22, 0.38, Color.WHITE, true)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = h.verts
	arrays[Mesh.ARRAY_NORMAL] = h.normals
	arrays[Mesh.ARRAY_INDEX] = h.indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(1, head_mat)
	return mesh


## Calcule les emplacements des lampadaires pour tout le réseau.
## Renvoie la liste des transformations (poteau au sol, bras tourné vers la voie).
static func layout(net: TransportNetwork) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	for id in net.edges:
		var e: Dictionary = net.edges[id]
		var mode := TransportTypes.mode_of(e.t)
		var spacing: float
		var scale := 1.0
		if mode == TransportTypes.Mode.ROAD:
			spacing = ROAD_SPACING
		elif mode == TransportTypes.Mode.PATH:
			spacing = PATH_SPACING
			scale = PATH_SCALE
		else:
			continue
		var width := TransportTypes.width_of(e.t, e.get("w", {}))
		var length := float(e.len)
		if length < 8.0:
			continue
		var count := maxi(1, floori((length - 8.0) / spacing) + 1)
		var start := (length - (count - 1) * spacing) / 2.0
		for i in count:
			var s := start + i * spacing
			if net.struct_at(id, s) == TransportTypes.Struct.TUNNEL:
				continue
			var p := net.point_at(id, s)
			var t := net.tangent_at(id, s)
			t.y = 0.0
			if t.length_squared() < 0.0001:
				continue
			t = t.normalized()
			var right := Vector3(-t.z, 0.0, t.x)
			# En quinconce sur les routes, toujours à droite sur les chemins.
			var side := 1.0 if mode == TransportTypes.Mode.PATH or (int(id) + i) % 2 == 0 else -1.0
			var n := right * side
			# Routes : au bord du trottoir. Chemins : juste à côté.
			var pos := p + n * (width / 2.0 + (0.5 if mode == TransportTypes.Mode.PATH else -0.4))
			# Bras (+X local) vers l'axe de la voie.
			var x_axis := -n
			var basis := Basis(x_axis, Vector3.UP, x_axis.cross(Vector3.UP)).scaled(Vector3.ONE * scale)
			out.append(Transform3D(basis, pos))
	return out


func rebuild() -> void:
	_dirty = false
	var list: Array[Transform3D] = []
	if transport != null:
		list = layout(transport.network)
	_multimesh.instance_count = list.size()
	heads.resize(list.size())
	for i in list.size():
		_multimesh.set_instance_transform(i, list[i])
		heads[i] = list[i] * (HEAD - Vector3(0, 0.2, 0))
	_timer = 0.0


func count() -> int:
	return heads.size()


func set_night(f: float) -> void:
	if (f > 0.02) != (night > 0.02):
		_timer = 0.0 # allumage / extinction tout de suite
	night = f
	_head_material.emission_energy_multiplier = 6.0 * f
	_head_material.albedo_color = Color("d8d2c0").lerp(Color("fff1d6"), f)


func _process(delta: float) -> void:
	if _dirty:
		rebuild()
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 0.25
	var cam := get_viewport().get_camera_3d()
	var on := night > 0.02 and cam != null
	if not on:
		for l in _lights:
			l.visible = false
		return
	# Les lampadaires les plus proches de ce que regarde la caméra.
	var focus := cam.global_position
	var fwd := -cam.global_transform.basis.z
	if fwd.y < -0.2:
		# Vue plongeante : on vise le point du sol au centre de l'écran.
		var dist := -focus.y / fwd.y if fwd.y < 0.0 else 0.0
		focus = focus + fwd * clampf(dist * 0.85, 0.0, 400.0)
	var near: Array = []
	var r2 := LIGHT_RADIUS * LIGHT_RADIUS
	for i in heads.size():
		var d2 := heads[i].distance_squared_to(focus)
		if d2 < r2:
			near.append(Vector2(d2, i))
	near.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	for k in _lights.size():
		var l := _lights[k]
		if k < near.size():
			l.position = heads[int(near[k].y)]
			l.light_energy = 3.2 * night
			l.visible = true
		else:
			l.visible = false
