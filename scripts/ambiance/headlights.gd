class_name Headlights
extends Node3D
## Phares et feux arrière des véhicules, la nuit et par mauvais temps.
##
## - Deux phares blancs à l'avant et deux feux rouges à l'arrière de chaque
##   véhicule à moteur (pas les piétons ni les attelages), placés d'après sa
##   longueur, sa largeur et sa hauteur dans le catalogue des véhicules.
## - Tous les feux sont dessinés en une fois (deux MultiMesh) et suivent les
##   véhicules à chaque image.
## - Les véhicules les plus proches de la caméra éclairent vraiment la route
##   devant eux (projecteurs recyclés).

const MAX_BEAMS := 16
const BEAM_RADIUS := 180.0
## Formes sans phares.
const NO_LIGHTS := ["attelage", "caleche", "charrette", "pousse"]

var traffic: Traffic
var level := 0.0

var _front: MultiMesh
var _rear: MultiMesh
var _front_mat: StandardMaterial3D
var _rear_mat: StandardMaterial3D
var _beams: Array[SpotLight3D] = []


func _ready() -> void:
	_front_mat = _lamp_material(Color(1.0, 0.95, 0.8))
	_rear_mat = _lamp_material(Color(1.0, 0.12, 0.08))
	_front = _make_mm(_front_mat, "PharesAvant")
	_rear = _make_mm(_rear_mat, "FeuxArriere")
	for i in MAX_BEAMS:
		var l := SpotLight3D.new()
		l.light_color = Color(1.0, 0.93, 0.8)
		l.spot_range = 26.0
		l.spot_angle = 28.0
		l.spot_attenuation = 1.2
		l.light_energy = 0.0
		l.visible = false
		add_child(l)
		_beams.append(l)


static func _lamp_material(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	return m


func _make_mm(mat: Material, n: String) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var box := BoxMesh.new()
	box.size = Vector3(0.22, 0.14, 0.06)
	box.material = mat
	mm.mesh = box
	var mi := MultiMeshInstance3D.new()
	mi.name = n
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mm


## Allume (1) ou éteint (0) les feux, avec un fondu.
func set_on(f: float) -> void:
	level = f
	_front_mat.albedo_color = Color(1.0, 0.95, 0.8) * (1.0 + 5.0 * f)
	_rear_mat.albedo_color = Color(1.0, 0.12, 0.08) * (1.0 + 3.0 * f)


## Emplacements des feux d'un véhicule (repère du véhicule, avant vers −Z).
static func lamp_points(t: Dictionary) -> Array:
	var l := float(t.get("L", 4.0))
	var w := float(t.get("W", 1.7))
	var h := float(t.get("H", 1.5))
	var y := clampf(h * 0.38, 0.45, 1.1)
	var x := w * 0.36
	if w < 1.0:
		x = 0.0 # deux-roues : un seul feu au centre
	return [Vector3(-x, y, -l / 2.0 - 0.02), Vector3(x, y, -l / 2.0 - 0.02),
		Vector3(-x, y, l / 2.0 + 0.02), Vector3(x, y, l / 2.0 + 0.02)]


func _process(_delta: float) -> void:
	if traffic == null or level < 0.02:
		_front.instance_count = 0
		_rear.instance_count = 0
		for b in _beams:
			b.visible = false
		return
	var fronts: Array[Transform3D] = []
	var rears: Array[Transform3D] = []
	var cars: Array = []
	for v in traffic.vehicles:
		var model := String(v.get("model", ""))
		if model == "" or not v.has("body"):
			continue
		var t := VehicleCatalog.get_type(model)
		if t.is_empty() or String(t.get("shape", "")) in NO_LIGHTS:
			continue
		var body: Node3D = v.body
		if not body.visible:
			continue
		var tr := body.global_transform
		var pts := lamp_points(t)
		fronts.append(tr * Transform3D(Basis.IDENTITY, pts[0]))
		fronts.append(tr * Transform3D(Basis.IDENTITY, pts[1]))
		rears.append(tr * Transform3D(Basis.IDENTITY, pts[2]))
		rears.append(tr * Transform3D(Basis.IDENTITY, pts[3]))
		cars.append([tr, pts[0].z, pts[0].y])
	_fill(_front, fronts)
	_fill(_rear, rears)

	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var focus := cam.global_position
	var near: Array = []
	for c in cars:
		var d2 := (c[0] as Transform3D).origin.distance_squared_to(focus)
		if d2 < BEAM_RADIUS * BEAM_RADIUS:
			near.append([d2, c])
	near.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for i in _beams.size():
		var b := _beams[i]
		if i < near.size():
			var c: Array = near[i][1]
			var tr: Transform3D = c[0]
			b.global_transform = tr * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-9.0)), Vector3(0, float(c[2]), float(c[1])))
			b.light_energy = 2.2 * level
			b.visible = true
		else:
			b.visible = false


static func _fill(mm: MultiMesh, list: Array[Transform3D]) -> void:
	if mm.instance_count != list.size():
		mm.instance_count = list.size()
	for i in list.size():
		mm.set_instance_transform(i, list[i])
