class_name RoutePlanner
extends RefCounted
## Calcule le tracé d'un tronçon posé sur le relief réel.
##
## 1. Échantillonne le sol tous les 2 m entre A et B.
## 2. Lisse ce profil (une route ne suit pas chaque bosse).
## 3. Impose la pente maximale du type (route 10 %, rail 4 %…) en gardant
##    les hauteurs imposées aux extrémités (raccord sur un nœud existant).
## 4. Décide la structure de chaque point : au sol (avec remblai / déblai),
##    pont (trop haut au-dessus du sol, ou au-dessus de la mer) ou tunnel.

const MAX_LENGTH := 1500.0
const MIN_LENGTH := 3.0
## Hauteur minimale d'un tablier au-dessus de la mer (m).
const SEA_CLEARANCE := 3.0
const SEA_LEVEL := 0.0


## a, b : extrémités. Si a.y (ou b.y) est NAN, la hauteur vient du sol.
## ground : Callable(x: float, z: float) -> float (NAN si pas encore chargé).
## Renvoie un dictionnaire : ok, reason, pts, st, length, max_grade,
## bridge_len, tunnel_len.
static func plan(type_id: String, a: Vector3, b: Vector3, ground: Callable) -> Dictionary:
	var ty := TransportTypes.get_type(type_id)
	var res := {"type": type_id, "ok": false, "reason": "", "pts": PackedVector3Array(), "st": PackedByteArray(),
		"length": 0.0, "max_grade": 0.0, "bridge_len": 0.0, "tunnel_len": 0.0}
	if ty.is_empty():
		res.reason = "Type de voie inconnu."
		return res
	var a2 := Vector2(a.x, a.z)
	var b2 := Vector2(b.x, b.z)
	var length := a2.distance_to(b2)
	res.length = length
	if length < MIN_LENGTH:
		res.reason = "Trop court."
		return res
	if length > MAX_LENGTH:
		res.reason = "Trop long : %d m (maximum %d m par tronçon)." % [roundi(length), roundi(MAX_LENGTH)]
		return res

	var n := maxi(2, ceili(length / TransportTypes.STEP) + 1)
	var ds := length / float(n - 1)
	var g := PackedFloat32Array()
	g.resize(n)
	var xz := PackedVector2Array()
	xz.resize(n)
	for i in n:
		var p := a2.lerp(b2, float(i) / float(n - 1))
		xz[i] = p
		var h: float = ground.call(p.x, p.y)
		if is_nan(h):
			res.reason = "Relief pas encore chargé à cet endroit."
			return res
		g[i] = h

	var pts := PackedVector3Array()
	pts.resize(n)
	var st := PackedByteArray()
	st.resize(n)

	# Voie navigable : uniquement sur l'eau, au niveau de la mer.
	if int(ty.mode) == TransportTypes.Mode.WATER:
		for i in n:
			if g[i] > SEA_LEVEL - 0.3:
				res.reason = "Une voie navigable doit rester sur l'eau."
				return res
			pts[i] = Vector3(xz[i].x, SEA_LEVEL, xz[i].y)
			st[i] = TransportTypes.Struct.WATER
		res.ok = true
		res.pts = pts
		res.st = st
		return res

	# Hauteur souhaitée : le sol, ou au-dessus de la mer.
	var want := PackedFloat32Array()
	want.resize(n)
	for i in n:
		want[i] = g[i] if g[i] >= SEA_LEVEL else SEA_LEVEL + SEA_CLEARANCE
	var h0: float = a.y if not is_nan(a.y) else maxf(g[0], SEA_LEVEL + 0.5)
	var h1: float = b.y if not is_nan(b.y) else maxf(g[n - 1], SEA_LEVEL + 0.5)

	var grade: float = ty.max_grade
	var need := absf(h1 - h0) / length
	if need > grade + 1e-4:
		res.reason = "Pente trop forte : %d %% (maximum %d %% pour %s)." % [
			roundi(need * 100.0), roundi(grade * 100.0), String(ty.name).to_lower()]
		res.max_grade = need
		return res

	# Lissage (moyenne glissante).
	var r := maxi(0, roundi(float(ty.smooth) / ds))
	var p := PackedFloat32Array()
	p.resize(n)
	for i in n:
		var acc := 0.0
		var cnt := 0
		for k in range(maxi(0, i - r), mini(n - 1, i + r) + 1):
			acc += want[k]
			cnt += 1
		p[i] = acc / float(cnt)

	# Pente maximale : enveloppe autour des extrémités, puis passes avant / arrière.
	var step_max := grade * ds
	for i in n:
		var s := float(i) * ds
		var hi := minf(h0 + grade * s, h1 + grade * (length - s))
		var lo := maxf(h0 - grade * s, h1 - grade * (length - s))
		p[i] = clampf(p[i], lo, hi)
	p[0] = h0
	p[n - 1] = h1
	for _pass in 4:
		for i in range(1, n):
			p[i] = clampf(p[i], p[i - 1] - step_max, p[i - 1] + step_max)
		for i in range(n - 2, -1, -1):
			p[i] = clampf(p[i], p[i + 1] - step_max, p[i + 1] + step_max)
		p[0] = h0
		p[n - 1] = h1

	# Structure de chaque point.
	var bridge_gap: float = ty.bridge_gap
	var tunnel_depth: float = ty.tunnel_depth
	for i in n:
		var diff := p[i] - g[i]
		if g[i] < SEA_LEVEL or diff > bridge_gap:
			st[i] = TransportTypes.Struct.BRIDGE
		elif diff < -tunnel_depth:
			st[i] = TransportTypes.Struct.TUNNEL
		else:
			st[i] = TransportTypes.Struct.GROUND
	_clean_runs(st, maxi(2, roundi(8.0 / ds)))

	var max_g := 0.0
	var bridge := 0.0
	var tunnel := 0.0
	for i in n:
		pts[i] = Vector3(xz[i].x, p[i], xz[i].y)
		if i > 0:
			max_g = maxf(max_g, absf(p[i] - p[i - 1]) / ds)
			if st[i] == TransportTypes.Struct.BRIDGE:
				bridge += ds
			elif st[i] == TransportTypes.Struct.TUNNEL:
				tunnel += ds
	res.ok = true
	res.pts = pts
	res.st = st
	res.max_grade = max_g
	res.bridge_len = bridge
	res.tunnel_len = tunnel
	return res


## Supprime les très courts passages au sol coincés entre deux ponts (ou deux
## tunnels), et les ponts / tunnels minuscules : le tracé reste lisible.
static func _clean_runs(st: PackedByteArray, min_run: int) -> void:
	var n := st.size()
	var i := 0
	while i < n:
		var j := i
		while j + 1 < n and st[j + 1] == st[i]:
			j += 1
		var run := j - i + 1
		if run < min_run and i > 0 and j < n - 1:
			var before := st[i - 1]
			var after := st[j + 1]
			var fill := -1
			if before == after:
				fill = before
			elif st[i] != TransportTypes.Struct.GROUND:
				fill = TransportTypes.Struct.GROUND
			if fill >= 0:
				for k in range(i, j + 1):
					st[k] = fill
		i = j + 1


## Cases à terrasser sous les parties au sol : cellule -> hauteur.
## step : pas de hauteur du terrain (0,5 m) ; la case passe juste sous la chaussée.
static func earthworks(type_id: String, pts: PackedVector3Array, st: PackedByteArray, step: float) -> Dictionary:
	var ty := TransportTypes.get_type(type_id)
	var out := {}
	if ty.is_empty() or int(ty.mode) == TransportTypes.Mode.WATER:
		return out
	var hw: float = float(ty.width) * 0.5 + 0.6
	for i in pts.size() - 1:
		if st[i] != TransportTypes.Struct.GROUND or st[i + 1] != TransportTypes.Struct.GROUND:
			continue
		var a := pts[i]
		var b := pts[i + 1]
		var a2 := Vector2(a.x, a.z)
		var b2 := Vector2(b.x, b.z)
		var ab := b2 - a2
		var x0 := floori(minf(a.x, b.x) - hw)
		var x1 := floori(maxf(a.x, b.x) + hw)
		var z0 := floori(minf(a.z, b.z) - hw)
		var z1 := floori(maxf(a.z, b.z) + hw)
		for x in range(x0, x1 + 1):
			for z in range(z0, z1 + 1):
				var q := Vector2(x + 0.5, z + 0.5)
				var u := 0.0
				if ab.length_squared() > 1e-8:
					u = clampf((q - a2).dot(ab) / ab.length_squared(), 0.0, 1.0)
				if q.distance_to(a2 + ab * u) > hw:
					continue
				var y := lerpf(a.y, b.y, u)
				var target := floorf((y + 0.001) / step) * step
				var c := Vector2i(x, z)
				out[c] = minf(float(out.get(c, target)), target)
	return out
