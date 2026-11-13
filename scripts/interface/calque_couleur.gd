class_name CalqueCouleur
extends MeshInstance3D
## Carte de couleur posée sur le relief autour de la caméra, réutilisable par
## tous les systèmes (pollution, bruit, valeur des terrains, services, avis…).
##
## Deux façons de la remplir :
## - valeur : Callable(x: float, z: float) -> float entre 0 et 1 (< 0 : rien),
##   échantillonnée tous les STEP mètres ;
## - rects : Callable() -> Array de [Rect2i (cases), float 0..1] : un aplat par
##   bâtiment (loyers, satisfaction par logement…).
## La couleur vient du dégradé (0 → 1). Appeler rafraichir() quand les valeurs
## changent ; la carte se redessine aussi quand la caméra bouge.

const RADIUS := 900.0
const STEP := 20.0
const MOVE := 100.0

var world: TerrainWorld
## Nœud qui donne le centre (le pivot de la caméra).
var focus: Node3D
var valeur: Callable
var rects: Callable
var degrade: Gradient
## Opacité (min, max) selon la valeur.
var alpha := Vector2(0.5, 0.85)
## Ne rien dessiner sous ce seuil (0 : tout dessiner).
var seuil := 0.0
var _center := Vector2(INF, INF)
var _retry := 0.0
var _unknown := false


## Dégradé jaune pâle → orange → rouge → violet (nuisances : rien de dessiné là où c'est propre).
static func degrade_nuisance() -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 0.7, 1.0])
	g.colors = PackedColorArray([Color("fff59d"), Color("ff9800"), Color("e53935"), Color("6a1b9a")])
	return g


## Dégradé rouge → jaune → vert → bleu (valeur : bas en rouge, haut en bleu).
static func degrade_valeur() -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.3, 0.55, 1.0])
	g.colors = PackedColorArray([Color("d84315"), Color("fdd835"), Color("43a047"), Color("1e88e5")])
	return g


func _ready() -> void:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.render_priority = 2
	material_override = m
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false
	if degrade == null:
		degrade = degrade_nuisance()


func montrer(on: bool) -> void:
	visible = on
	_center = Vector2(INF, INF)
	if not on:
		mesh = null


func rafraichir() -> void:
	_center = Vector2(INF, INF)


func _process(delta: float) -> void:
	if not visible or focus == null:
		return
	var c := Vector2(focus.global_position.x, focus.global_position.z)
	_retry -= delta
	if c.distance_to(_center) > MOVE or (_unknown and _retry <= 0.0):
		_retry = 1.5
		rebuild(c)


func _height(x: float, z: float) -> float:
	if world == null:
		return 0.0
	var h := world.raw_height(x, z)
	if is_nan(h):
		return NAN
	if h < 0.0:
		h = maxf(h, world.water_surface_at(x, z))
	return h


func rebuild(c: Vector2) -> void:
	_center = c
	_unknown = false
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := 0
	if rects.is_valid():
		for e in rects.call():
			var r: Rect2i = e[0]
			var v := float(e[1])
			var mid := Vector2(r.position.x + r.size.x * 0.5, r.position.y + r.size.y * 0.5)
			if v < 0.0 or mid.distance_to(c) > RADIUS * 1.5:
				continue
			var h := _height(mid.x, mid.y)
			if is_nan(h):
				h = 0.0
			_quad(st, Vector3(r.position.x, h + 1.2, r.position.y), Vector3(r.end.x, h + 1.2, r.position.y),
				Vector3(r.end.x, h + 1.2, r.end.y), Vector3(r.position.x, h + 1.2, r.end.y), v)
			count += 1
	elif valeur.is_valid():
		var n := int(RADIUS * 2.0 / STEP)
		var x0 := snappedf(c.x - RADIUS, STEP)
		var z0 := snappedf(c.y - RADIUS, STEP)
		var hs := PackedFloat32Array()
		hs.resize((n + 1) * (n + 1))
		for j in n + 1:
			for i in n + 1:
				var h := _height(x0 + i * STEP, z0 + j * STEP)
				if is_nan(h):
					_unknown = true
					h = NAN
				hs[i + j * (n + 1)] = h + 0.8
		for j in n:
			for i in n:
				var v := float(valeur.call(x0 + (i + 0.5) * STEP, z0 + (j + 0.5) * STEP))
				if v < 0.0 or v < seuil:
					continue
				var a := hs[i + j * (n + 1)]
				var b := hs[i + 1 + j * (n + 1)]
				var d := hs[i + 1 + (j + 1) * (n + 1)]
				var e := hs[i + (j + 1) * (n + 1)]
				if is_nan(a) or is_nan(b) or is_nan(d) or is_nan(e):
					continue
				var xa := x0 + i * STEP
				var za := z0 + j * STEP
				_quad(st, Vector3(xa, a, za), Vector3(xa + STEP, b, za), Vector3(xa + STEP, d, za + STEP), Vector3(xa, e, za + STEP), v)
				count += 1
	mesh = st.commit() if count > 0 else null


func _quad(st: SurfaceTool, p00: Vector3, p10: Vector3, p11: Vector3, p01: Vector3, v: float) -> void:
	var col := degrade.sample(clampf(v, 0.0, 1.0))
	col.a = lerpf(alpha.x, alpha.y, clampf(v, 0.0, 1.0))
	st.set_color(col)
	st.add_vertex(p00)
	st.add_vertex(p10)
	st.add_vertex(p11)
	st.add_vertex(p00)
	st.add_vertex(p11)
	st.add_vertex(p01)
