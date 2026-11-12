class_name RessourcesOverlay
extends MeshInstance3D
## Carte d'une ressource posée sur le relief autour de la caméra : plus la
## couleur est franche, plus la ressource est riche. Rien n'est dessiné là où
## elle est absente.

## Rayon couvert (m) et pas de la grille (m).
const RADIUS := 700.0
const STEP := 10.0
## On redessine quand la caméra a bougé de plus de tant de mètres.
const MOVE := 80.0

var carte: CarteRessources
var world: TerrainWorld
## Nœud qui donne le centre (le pivot de la caméra).
var focus: Node3D
## Ressource affichée ("" = rien).
var res := ""
var _center := Vector2(INF, INF)
var _unknown := false
var _retry := 0.0
var _mat: StandardMaterial3D


func _ready() -> void:
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.vertex_color_use_as_albedo = true
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.render_priority = 2
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false


func show_resource(id: String) -> void:
	res = id
	visible = id != ""
	_center = Vector2(INF, INF)
	if not visible:
		mesh = null


func _process(delta: float) -> void:
	if res == "" or focus == null or carte == null:
		return
	var c := Vector2(focus.global_position.x, focus.global_position.z)
	_retry -= delta
	if c.distance_to(_center) > MOVE or (_unknown and _retry <= 0.0):
		_retry = 1.5
		rebuild(c)


## Redessine la carte autour du point c (x, z).
func rebuild(c: Vector2) -> void:
	_center = c
	var n := int(RADIUS * 2.0 / STEP)
	var x0 := snappedf(c.x - RADIUS, STEP)
	var z0 := snappedf(c.y - RADIUS, STEP)
	var env := carte.sample_env(x0, z0, n, n, STEP)
	var v := carte.evaluate(res, env)
	var h: PackedFloat32Array = env.h
	var col: Color = Ressources.naturelle(res).get("color", Color.WHITE)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_unknown = false
	# Hauteur posée sur l'eau, puis hauteur des coins (la plus haute des mailles voisines).
	var top := PackedFloat32Array()
	top.resize(n * n)
	for j in n:
		for i in n:
			var k := i + j * n
			var hh := h[k]
			if is_nan(hh):
				hh = 0.0
			elif hh < 0.0:
				hh = maxf(hh, world.water_surface_at(x0 + (i + 0.5) * STEP, z0 + (j + 0.5) * STEP))
			top[k] = hh
	var corners := PackedFloat32Array()
	corners.resize((n + 1) * (n + 1))
	for j in n + 1:
		for i in n + 1:
			var m := -INF
			for d: Vector2i in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)]:
				var a := i + d.x
				var b := j + d.y
				if a >= 0 and b >= 0 and a < n and b < n:
					m = maxf(m, top[a + b * n])
			corners[i + j * (n + 1)] = m + 0.8
	var count := 0
	for j in n:
		for i in n:
			var k := i + j * n
			var r := v[k]
			if r < 0.0:
				_unknown = true
				continue
			if r < 0.03:
				continue
			var xa := x0 + i * STEP
			var za := z0 + j * STEP
			var p00 := Vector3(xa, corners[i + j * (n + 1)], za)
			var p10 := Vector3(xa + STEP, corners[i + 1 + j * (n + 1)], za)
			var p11 := Vector3(xa + STEP, corners[i + 1 + (j + 1) * (n + 1)], za + STEP)
			var p01 := Vector3(xa, corners[i + (j + 1) * (n + 1)], za + STEP)
			count += 1
			st.set_color(Color(col.r, col.g, col.b, 0.18 + 0.6 * r))
			st.add_vertex(p00)
			st.add_vertex(p10)
			st.add_vertex(p11)
			st.add_vertex(p00)
			st.add_vertex(p11)
			st.add_vertex(p01)
	mesh = st.commit() if count > 0 else null
