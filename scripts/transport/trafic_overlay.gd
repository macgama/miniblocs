class_name TraficOverlay
extends MeshInstance3D
## Carte du trafic posée sur les routes : chaque tronçon prend la couleur de sa
## saturation (vert fluide → rouge bouché), les parkings celle de leur
## remplissage, les voies de bus un liseré bleu, les routes fermées du violet.

const COLORS := [[0.0, Color("3fbf6f")], [0.5, Color("a7d948")], [0.8, Color("f2c14e")], [1.0, Color("f08a24")],
	[1.3, Color("d62828")], [2.0, Color("7a0b0b")]]
const BUS := Color("3a86ff")
const CLOSED := Color("9d4edd")
const LIFT := 0.35

var trafic: Trafic
## « maintenant » (heure du jeu) ou « pointe » (heure de pointe du matin).
var moment := "maintenant"
var _timer := 0.0
var _mat: StandardMaterial3D


func setup(t: Trafic) -> void:
	trafic = t
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.vertex_color_use_as_albedo = true
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.render_priority = 2
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false
	trafic.changed.connect(func() -> void:
		if visible:
			rebuild())


func set_shown(on: bool) -> void:
	visible = on
	if on:
		rebuild()


static func color_for(r: float) -> Color:
	if r <= 0.0:
		return COLORS[0][1]
	for i in range(1, COLORS.size()):
		if r <= float(COLORS[i][0]):
			var a: Array = COLORS[i - 1]
			var b: Array = COLORS[i]
			return (a[1] as Color).lerp(b[1], (r - float(a[0])) / (float(b[0]) - float(a[0])))
	return COLORS[COLORS.size() - 1][1]


func _process(delta: float) -> void:
	if not visible:
		return
	_timer += delta
	if _timer >= 2.0:
		_timer = 0.0
		rebuild()


func _ratio(eid: int) -> float:
	return trafic.ratio(eid) if moment == "pointe" else trafic.ratio_now(eid)


func rebuild() -> void:
	if trafic == null or trafic.transport == null:
		return
	var net := trafic.transport.network
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 0
	for eid in net.edges:
		var e: Dictionary = net.edges[eid]
		if TransportTypes.mode_of(e.t) != TransportTypes.Mode.ROAD:
			continue
		# Assez large pour se voir de haut, sans déborder en vue rapprochée.
		var hw := maxf(net.half_width(eid) * 0.8, 3.0)
		var c := CLOSED if net.closed_edges.has(eid) else color_for(_ratio(eid))
		c.a = 0.82
		_ribbon(st, e.pts, -hw, hw, c)
		if trafic.bus_lanes.has(eid):
			var b := BUS
			b.a = 0.95
			_ribbon(st, e.pts, hw * 0.75, hw * 1.05, b, 0.05)
		n += 1
	# Parkings construits.
	if trafic.transport.traffic != null:
		for node in trafic.transport.traffic.parkings:
			var p := net.node_pos(int(node))
			var occ := trafic.parking_occupancy(int(node))
			var c2 := color_for(occ)
			c2.a = 0.9
			_disc(st, p + Vector3(0, LIFT + 0.6, 0), 6.0, c2)
	if n == 0:
		mesh = null
		return
	mesh = st.commit()


func _ribbon(st: SurfaceTool, pts: PackedVector3Array, a: float, b: float, c: Color, dy := 0.0) -> void:
	if pts.size() < 2:
		return
	var step := maxi(1, pts.size() / 60)
	var idx: Array[int] = []
	var i := 0
	while i < pts.size() - 1:
		idx.append(i)
		i += step
	idx.append(pts.size() - 1)
	var prev_l := Vector3.ZERO
	var prev_r := Vector3.ZERO
	for k in idx.size():
		var j := idx[k]
		var t := (pts[mini(j + 1, pts.size() - 1)] - pts[maxi(j - 1, 0)])
		t.y = 0.0
		if t.length_squared() < 1e-6:
			t = Vector3.FORWARD
		var side := t.normalized().cross(Vector3.UP)
		var base := pts[j] + Vector3(0, LIFT + dy, 0)
		var l := base + side * a
		var r := base + side * b
		if k > 0:
			st.set_color(c)
			st.add_vertex(prev_l)
			st.add_vertex(prev_r)
			st.add_vertex(r)
			st.add_vertex(prev_l)
			st.add_vertex(r)
			st.add_vertex(l)
		prev_l = l
		prev_r = r


func _disc(st: SurfaceTool, p: Vector3, r: float, c: Color) -> void:
	var seg := 16
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		st.set_color(c)
		st.add_vertex(p)
		st.add_vertex(p + Vector3(cos(a0), 0, sin(a0)) * r)
		st.add_vertex(p + Vector3(cos(a1), 0, sin(a1)) * r)
