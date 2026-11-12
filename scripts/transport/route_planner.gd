class_name RoutePlanner
extends RefCounted
## Calcule le tracé d'un tronçon posé sur le relief réel.
##
## 1. Le tracé en plan (droit ou courbe) est rééchantillonné tous les 2 m et
##    son rayon de courbure est comparé au rayon minimal de la classe.
## 2. Le sol est lu sous chaque point, puis lissé (une route ne suit pas
##    chaque bosse) ; la pente maximale de la classe est imposée en gardant
##    les hauteurs des raccords (nœuds existants).
## 3. Chaque point reçoit sa structure : au sol (avec remblai / déblai et
##    talus), pont (trop haut au-dessus du sol, ou au-dessus de la mer) ou tunnel.

const MAX_LENGTH := 3000.0
const MIN_LENGTH := 3.0
## Hauteur minimale d'un tablier au-dessus de la mer (m).
const SEA_CLEARANCE := 3.0
## Hauteur libre d'un pont au-dessus d'une rivière ou d'un ruisseau (m).
const RIVER_CLEARANCE := 1.5
const SEA_LEVEL := 0.0
## Pente des talus de remblai / déblai (horizontal pour 1 m de vertical).
const TALUS := 1.5
const TALUS_MAX := 14.0


# --- Géométrie en plan -------------------------------------------------------------

## Courbe de Bézier quadratique a -> b, tirée vers le point de contrôle c.
static func bezier(a: Vector2, c: Vector2, b: Vector2, n: int = 96) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n + 1:
		var t := float(i) / float(n)
		out.append(a.lerp(c, t).lerp(c.lerp(b, t), t))
	return out


static func polyline_length(p: PackedVector2Array) -> float:
	var l := 0.0
	for i in range(1, p.size()):
		l += p[i].distance_to(p[i - 1])
	return l


## Rééchantillonne une ligne brisée à pas régulier (le dernier pas s'ajuste).
static func resample(p: PackedVector2Array, step: float) -> PackedVector2Array:
	var total := polyline_length(p)
	var n := maxi(2, ceili(total / step) + 1)
	var spacing := total / float(n - 1)
	var out := PackedVector2Array()
	out.append(p[0])
	var seg := 0
	var seg_start := 0.0
	for k in range(1, n - 1):
		var target := spacing * k
		while seg < p.size() - 2 and seg_start + p[seg].distance_to(p[seg + 1]) < target:
			seg_start += p[seg].distance_to(p[seg + 1])
			seg += 1
		var sl := p[seg].distance_to(p[seg + 1])
		var u := 0.0 if sl <= 0.0 else clampf((target - seg_start) / sl, 0.0, 1.0)
		out.append(p[seg].lerp(p[seg + 1], u))
	out.append(p[p.size() - 1])
	return out


## Plus petit rayon de courbure d'une ligne échantillonnée (INF si droite).
static func min_radius(xz: PackedVector2Array) -> float:
	var n := xz.size()
	var k := clampi(roundi(6.0 / TransportTypes.STEP), 1, maxi(1, (n - 1) / 2))
	var r := INF
	for i in range(k, n - k):
		var a := xz[i - k]
		var b := xz[i]
		var c := xz[i + k]
		var cross := absf((b - a).cross(c - a))
		if cross < 1e-6:
			continue
		var rr := a.distance_to(b) * b.distance_to(c) * c.distance_to(a) / (2.0 * cross)
		r = minf(r, rr)
	return r


# --- Profil en long ------------------------------------------------------------------

## path : tracé en plan (au moins 2 points). h0 / h1 : hauteur imposée aux
## extrémités (NAN = hauteur du sol). ground : Callable(x, z) -> float.
## water (optionnel) : Callable(x, z) -> float, surface d'une rivière ou d'un lac
## (NAN = pas d'eau douce) : la voie l'enjambe par un pont.
## Renvoie : ok, reason, type, pts, st, length, max_grade, min_radius,
## bridge_len, tunnel_len.
static func plan(type_id: String, path: PackedVector2Array, h0: float, h1: float, ground: Callable,
		water: Callable = Callable()) -> Dictionary:
	type_id = TransportTypes.resolve(type_id)
	var ty := TransportTypes.get_type(type_id)
	var res := {"type": type_id, "ok": false, "reason": "", "pts": PackedVector3Array(), "st": PackedByteArray(),
		"length": 0.0, "max_grade": 0.0, "min_radius": INF, "bridge_len": 0.0, "tunnel_len": 0.0}
	if ty.is_empty() or path.size() < 2:
		res.reason = "Type de voie inconnu."
		return res
	var length := polyline_length(path)
	res.length = length
	if length < MIN_LENGTH:
		res.reason = "Trop court."
		return res
	if length > MAX_LENGTH:
		res.reason = "Trop long : %d m (maximum %d m par tronçon)." % [roundi(length), roundi(MAX_LENGTH)]
		return res

	var xz := resample(path, TransportTypes.STEP)
	var n := xz.size()
	var ds := length / float(n - 1)
	var r_min: float = ty.r_min
	var rad := min_radius(xz)
	res.min_radius = rad
	# Tolérance : la courbe est échantillonnée, on accepte 3 % d'écart.
	var too_tight := rad < r_min * 0.97

	var g := PackedFloat32Array()
	g.resize(n)
	for i in n:
		var h: float = ground.call(xz[i].x, xz[i].y)
		if is_nan(h):
			res.reason = "Relief pas encore chargé à cet endroit."
			return res
		g[i] = h
	# Eau douce : on regarde aussi entre deux points (un ruisseau fait 1 m, un pas 2 m).
	var ws := PackedFloat32Array()
	ws.resize(n)
	ws.fill(NAN)
	if water.is_valid():
		for i in n:
			var dir := (xz[mini(i + 1, n - 1)] - xz[maxi(i - 1, 0)]).normalized()
			for t in [0.0, -0.25, 0.25, -0.5, 0.5]:
				var q: Vector2 = xz[i] + dir * ds * t
				var wv: float = water.call(q.x, q.y)
				if not is_nan(wv):
					ws[i] = wv if is_nan(ws[i]) else maxf(ws[i], wv)

	var pts := PackedVector3Array()
	pts.resize(n)
	var st := PackedByteArray()
	st.resize(n)

	# Voie navigable : uniquement sur l'eau, au niveau de la mer.
	if int(ty.mode) == TransportTypes.Mode.WATER:
		for i in n:
			pts[i] = Vector3(xz[i].x, SEA_LEVEL if is_nan(ws[i]) else ws[i], xz[i].y)
			st[i] = TransportTypes.Struct.WATER
		res.pts = pts
		res.st = st
		for i in n:
			if g[i] > SEA_LEVEL - 0.3 and is_nan(ws[i]):
				res.reason = "Une voie navigable doit rester sur l'eau."
				return res
		if too_tight:
			res.reason = _radius_reason(ty, rad)
			return res
		res.ok = true
		return res

	# Hauteur souhaitée : le sol, ou au-dessus de la mer.
	var want := PackedFloat32Array()
	want.resize(n)
	for i in n:
		# Au-dessus de la mer : assez haut même à la plus haute marée.
		want[i] = g[i] if g[i] >= SEA_LEVEL else SEA_LEVEL + Maree.high_water + SEA_CLEARANCE
		if not is_nan(ws[i]):
			want[i] = maxf(want[i], ws[i] + RIVER_CLEARANCE)
	if is_nan(h0):
		h0 = maxf(g[0], SEA_LEVEL + 0.5)
	if is_nan(h1):
		h1 = maxf(g[n - 1], SEA_LEVEL + 0.5)

	var grade: float = ty.max_grade
	var need := absf(h1 - h0) / length

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
	var eff_grade := maxf(grade, need)
	var step_max := eff_grade * ds
	for i in n:
		var s := float(i) * ds
		var hi := minf(h0 + eff_grade * s, h1 + eff_grade * (length - s))
		var lo := maxf(h0 - eff_grade * s, h1 - eff_grade * (length - s))
		p[i] = clampf(p[i], lo, hi)
	# Plancher : le tablier passe au-dessus des rivières (les rampes suivent).
	var floor_h := PackedFloat32Array()
	floor_h.resize(n)
	for i in n:
		floor_h[i] = -INF if is_nan(ws[i]) else ws[i] + RIVER_CLEARANCE
		p[i] = maxf(p[i], floor_h[i])
	p[0] = h0
	p[n - 1] = h1
	for _pass in 4:
		for i in range(1, n):
			p[i] = maxf(clampf(p[i], p[i - 1] - step_max, p[i - 1] + step_max), floor_h[i])
		for i in range(n - 2, -1, -1):
			p[i] = maxf(clampf(p[i], p[i + 1] - step_max, p[i + 1] + step_max), floor_h[i])
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
	# Au-dessus d'une rivière, toujours un pont (avec un appui de chaque côté).
	for i in n:
		if not is_nan(ws[i]):
			for k in range(maxi(0, i - 1), mini(n - 1, i + 1) + 1):
				st[k] = TransportTypes.Struct.BRIDGE

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
	res.pts = pts
	res.st = st
	res.max_grade = max_g
	res.bridge_len = bridge
	res.tunnel_len = tunnel
	if need > grade + 1e-4:
		res.reason = "Pente trop forte : %s %% (maximum %s %% pour %s)." % [
			TransportTypes._num(need * 100.0), TransportTypes._num(grade * 100.0), String(ty.name).to_lower()]
		return res
	if too_tight:
		res.reason = _radius_reason(ty, rad)
		return res
	res.ok = true
	return res


static func _radius_reason(ty: Dictionary, rad: float) -> String:
	return "Virage trop serré : rayon %d m (minimum %d m pour %s à %d km/h)." % [
		roundi(rad), roundi(ty.r_min), String(ty.name).to_lower(), roundi(ty.kmh)]


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


# --- Emprise et terrassement -----------------------------------------------------------

## Cases sous la plate-forme (parties au sol) : cellule -> hauteur de la chaussée.
static func footprint(width: float, pts: PackedVector3Array, st: PackedByteArray) -> Dictionary:
	var out := {}
	var hw := width * 0.5 + 0.6
	for i in pts.size() - 1:
		if st[i] != TransportTypes.Struct.GROUND or st[i + 1] != TransportTypes.Struct.GROUND:
			continue
		var a := pts[i]
		var b := pts[i + 1]
		var a2 := Vector2(a.x, a.z)
		var ab := Vector2(b.x, b.z) - a2
		for x in range(floori(minf(a.x, b.x) - hw), floori(maxf(a.x, b.x) + hw) + 1):
			for z in range(floori(minf(a.z, b.z) - hw), floori(maxf(a.z, b.z) + hw) + 1):
				var q := Vector2(x + 0.5, z + 0.5)
				var u := 0.0
				if ab.length_squared() > 1e-8:
					u = clampf((q - a2).dot(ab) / ab.length_squared(), 0.0, 1.0)
				if q.distance_to(a2 + ab * u) > hw:
					continue
				var c := Vector2i(x, z)
				var y := lerpf(a.y, b.y, u)
				out[c] = minf(float(out.get(c, y)), y)
	return out


## Terrassement : la plate-forme au niveau de la chaussée, puis des talus en
## pente douce (1 pour 1,5) jusqu'au terrain naturel, comme sur un vrai chantier.
## protected : cases à ne pas toucher (sous d'autres voies). Renvoie cellule -> hauteur.
static func earthworks(width: float, pts: PackedVector3Array, st: PackedByteArray, step: float,
		ground: Callable, protected: Dictionary = {}) -> Dictionary:
	var core := footprint(width, pts, st)
	var out := {}
	for c in core:
		if not protected.has(c):
			out[c] = floorf((float(core[c]) + 0.001) / step) * step
	if not ground.is_valid():
		return out
	var hw := width * 0.5 + 0.6
	var best_d := {}
	for i in pts.size() - 1:
		if st[i] != TransportTypes.Struct.GROUND or st[i + 1] != TransportTypes.Struct.GROUND:
			continue
		var a := pts[i]
		var b := pts[i + 1]
		var a2 := Vector2(a.x, a.z)
		var ab := Vector2(b.x, b.z) - a2
		# Étendue utile des talus : d'après l'écart avec le sol de part et d'autre.
		var dir := ab.normalized() if ab.length_squared() > 1e-8 else Vector2.RIGHT
		var nrm := Vector2(-dir.y, dir.x)
		var mid := a2 + ab * 0.5
		var y_mid := (a.y + b.y) * 0.5
		var gap := 0.0
		for off in [hw + 1.0, hw + 4.0, hw + 9.0]:
			for sgn in [-1.0, 1.0]:
				var q: Vector2 = mid + nrm * off * sgn
				var gh: float = ground.call(q.x, q.y)
				if not is_nan(gh):
					gap = maxf(gap, absf(gh - y_mid))
		var reach := minf(TALUS_MAX, gap * TALUS)
		if reach < 0.5:
			continue
		var ext := hw + reach
		for x in range(floori(minf(a.x, b.x) - ext), floori(maxf(a.x, b.x) + ext) + 1):
			for z in range(floori(minf(a.z, b.z) - ext), floori(maxf(a.z, b.z) + ext) + 1):
				var c := Vector2i(x, z)
				if core.has(c) or protected.has(c):
					continue
				var q := Vector2(x + 0.5, z + 0.5)
				var u := 0.0
				if ab.length_squared() > 1e-8:
					u = clampf((q - a2).dot(ab) / ab.length_squared(), 0.0, 1.0)
				var dist := q.distance_to(a2 + ab * u) - hw
				if dist <= 0.0 or dist > reach or dist >= float(best_d.get(c, INF)):
					continue
				var gh: float = ground.call(q.x, q.y)
				if is_nan(gh):
					continue
				var y := lerpf(a.y, b.y, u)
				var span := absf(gh - y) * TALUS
				if span <= dist:
					continue # le talus a déjà rejoint le terrain naturel
				var h := lerpf(y, gh, dist / span)
				best_d[c] = dist
				out[c] = snappedf(h, step)
	return out
