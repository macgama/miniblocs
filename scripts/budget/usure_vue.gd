class_name UsureVue
extends Node3D
## Usure visible des voies : nids-de-poule et rustines sur les routes abîmées,
## et carte de l'état des réseaux (vert = neuf, orange = abîmé, rouge = hors d'usage).

const POTHOLE_STEP := 6.0
const MAP_LIFT := 0.35
## Juste au-dessus de la chaussée (0,08 m) et du marquage (0,10 m).
const HOLE_LIFT := 0.11

var budget: BudgetCommunal
var carte := false
var _holes: MultiMeshInstance3D
var _map: MeshInstance3D
var _dirty := true
var _timer := 0.0


func setup(b: BudgetCommunal) -> void:
	budget = b
	_holes = MultiMeshInstance3D.new()
	_holes.name = "NidsDePoule"
	_holes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	# Nid-de-poule : disque plat à 7 côtés (style low-poly).
	var quad := CylinderMesh.new()
	quad.top_radius = 0.5
	quad.bottom_radius = 0.45
	quad.height = 0.02
	quad.radial_segments = 7
	quad.rings = 1
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	quad.material = mat
	mm.mesh = quad
	_holes.multimesh = mm
	add_child(_holes)
	_map = MeshInstance3D.new()
	_map.name = "CarteEtat"
	_map.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_map.visible = false
	add_child(_map)
	var net := b.network()
	if net != null:
		net.changed.connect(rebuild)


func rebuild() -> void:
	_dirty = true


func set_carte(on: bool) -> void:
	carte = on
	_map.visible = on
	_dirty = true


func _process(delta: float) -> void:
	_timer += delta
	if _dirty and _timer > 0.5:
		flush()


## Reconstruit tout de suite les nids-de-poule (et la carte si elle est affichée).
func flush() -> void:
	_timer = 0.0
	_dirty = false
	_build_holes()
	if carte:
		_build_map()


## Couleur de la carte selon l'état.
static func couleur(u: float) -> Color:
	if u <= 0.0:
		return Color(0.85, 0.1, 0.1)
	if u < 0.5:
		return Color(0.95, 0.35, 0.1).lerp(Color(1.0, 0.75, 0.15), u / 0.5)
	return Color(1.0, 0.75, 0.15).lerp(Color(0.2, 0.8, 0.3), (u - 0.5) / 0.5)


## Nombre de nids-de-poule posés (tests).
func hole_count() -> int:
	return _holes.multimesh.instance_count


func _build_holes() -> void:
	var net := budget.network()
	var xs: Array[Transform3D] = []
	var cs: Array[Color] = []
	if net != null:
		for eid in net.edges:
			var e: Dictionary = net.edges[eid]
			if TransportTypes.mode_of(String(e.t)) != TransportTypes.Mode.ROAD:
				continue
			var u := budget.etat(eid)
			if u >= BudgetCommunal.SEUIL_ABIME:
				continue
			var rng := RandomNumberGenerator.new()
			rng.seed = int(eid) * 7919
			var hw := float(e.width) * 0.5
			var density := (BudgetCommunal.SEUIL_ABIME - u) / BudgetCommunal.SEUIL_ABIME
			var s := rng.randf_range(1.0, POTHOLE_STEP)
			while s < float(e.len) - 1.0:
				if rng.randf() < 0.25 + 0.75 * density:
					var p := net.point_at(eid, s)
					var tg := net.tangent_at(eid, s)
					var side := Vector3(-tg.z, 0.0, tg.x).normalized()
					p += side * rng.randf_range(-hw * 0.6, hw * 0.6)
					var r := rng.randf_range(0.35, 0.9) * (0.6 + density)
					var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(r, 1.0, r * rng.randf_range(0.6, 1.2)))
					xs.append(Transform3D(basis, p + Vector3.UP * HOLE_LIFT))
					# Nids sombres, et rustines de goudron plus claires.
					cs.append(Color(0.09, 0.08, 0.07) if rng.randf() < 0.7 else Color(0.2, 0.2, 0.21))
				s += rng.randf_range(POTHOLE_STEP * 0.5, POTHOLE_STEP * 1.5) / (0.5 + density)
	var mm := _holes.multimesh
	mm.instance_count = xs.size()
	for i in xs.size():
		mm.set_instance_transform(i, xs[i])
		mm.set_instance_color(i, cs[i])


func _build_map() -> void:
	var net := budget.network()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any := false
	if net != null:
		for eid in net.edges:
			var e: Dictionary = net.edges[eid]
			if BudgetCommunal.voie_of(String(e.t)) == "":
				continue
			var c := couleur(budget.etat(eid))
			var pts: PackedVector3Array = e.pts
			var hw := maxf(1.2, float(e.width) * 0.5)
			for i in pts.size() - 1:
				var a := pts[i] + Vector3.UP * MAP_LIFT
				var b := pts[i + 1] + Vector3.UP * MAP_LIFT
				var d := b - a
				d.y = 0.0
				if d.length() < 0.01:
					continue
				var side := Vector3(-d.z, 0.0, d.x).normalized() * hw
				st.set_color(c)
				st.add_vertex(a - side)
				st.add_vertex(a + side)
				st.add_vertex(b + side)
				st.add_vertex(a - side)
				st.add_vertex(b + side)
				st.add_vertex(b - side)
				any = true
	if not any:
		_map.mesh = null
		return
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1, 1, 1, 0.85)
	mat.no_depth_test = false
	var m := st.commit()
	m.surface_set_material(0, mat)
	_map.mesh = m
