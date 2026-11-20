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
## Terrassement automatique : une extrémité libre (pas raccordée) peut être
## creusée ou remblayée jusqu'à cette profondeur pour adoucir la pente (m).
const TERRASSEMENT_BOUT := 3.0
## Lacets : pente visée (part de la pente de la norme) et largeur maximale du lacet (m).
const LACETS_PENTE := 0.85
const LACETS_LARGEUR_MAX := 600.0


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

## Profondeur imposée (m sous le sol) des voies posées depuis la vue sous terre
## (ConstructionSouterraine) ; NAN : profondeur normale du type.
static var profondeur_forcee := NAN


## path : tracé en plan (au moins 2 points). h0 / h1 : hauteur imposée aux
## extrémités (NAN = hauteur du sol). ground : Callable(x, z) -> float.
## water (optionnel) : Callable(x, z) -> float, surface d'une rivière ou d'un lac
## (NAN = pas d'eau douce) : la voie l'enjambe par un pont.
## Renvoie : ok, reason, type, pts, st, length, max_grade, min_radius,
## bridge_len, tunnel_len ; orange (zone de tolérance : pente au-delà de la norme
## ou virage en épingle), avert (texte), terr_bout (m creusés ou remblayés aux
## extrémités libres).
## bounds (optionnel) : passages imposés au-dessus ou au-dessous d'une autre
## voie, [{s0, s1 (distances le long du tracé), lo, hi (hauteurs permises),
## st (structure imposée)}] ; les rampes d'accès suivent la pente maximale.
static func plan(type_id: String, path: PackedVector2Array, h0: float, h1: float, ground: Callable,
		water: Callable = Callable(), bounds: Array = []) -> Dictionary:
	type_id = TransportTypes.resolve(type_id)
	var ty := TransportTypes.get_type(type_id)
	var res := {"type": type_id, "ok": false, "reason": "", "pts": PackedVector3Array(), "st": PackedByteArray(),
		"length": 0.0, "max_grade": 0.0, "min_radius": INF, "bridge_len": 0.0, "tunnel_len": 0.0,
		"orange": false, "avert": "", "terr_bout": 0.0}
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
	# Entre le rayon d'épingle et le rayon de la norme : zone orange.
	var too_tight := rad < TransportTypes.rayon_tolere(type_id) * 0.97
	var serre := rad < r_min * 0.97 and not too_tight

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

	# Hauteur souhaitée : le sol, ou au-dessus de la mer (le métro : sous le sol).
	var depth := float(ty.get("underground", 0.0))
	# Construction depuis la vue sous terre : voie creusée à la profondeur du niveau.
	if not is_nan(profondeur_forcee):
		depth = profondeur_forcee
	var want := PackedFloat32Array()
	want.resize(n)
	for i in n:
		if depth > 0.0:
			want[i] = g[i] - depth
			continue
		# Au-dessus de la mer : assez haut même à la plus haute marée.
		want[i] = g[i] if g[i] >= SEA_LEVEL else SEA_LEVEL + Maree.high_water + SEA_CLEARANCE
		if not is_nan(ws[i]):
			want[i] = maxf(want[i], ws[i] + RIVER_CLEARANCE)
	if depth > 0.0:
		ws.fill(NAN)
	var libre0 := is_nan(h0)
	var libre1 := is_nan(h1)
	if libre0:
		h0 = g[0] - depth if depth > 0.0 else maxf(g[0], SEA_LEVEL + 0.5)
	if libre1:
		h1 = g[n - 1] - depth if depth > 0.0 else maxf(g[n - 1], SEA_LEVEL + 0.5)

	var grade: float = ty.max_grade
	var hard := TransportTypes.grade_tolere(type_id)
	var need := absf(h1 - h0) / length
	# Terrassement automatique : l'extrémité libre du haut est creusée, celle du
	# bas remblayée (TERRASSEMENT_BOUT au plus), comme sur un vrai chantier.
	res.terr_bout = 0.0
	if need > grade + 1e-4 and depth <= 0.0 and (libre0 or libre1):
		var exces := absf(h1 - h0) - grade * length
		var cap := TERRASSEMENT_BOUT * (int(libre0) + int(libre1))
		var shift := minf(exces, cap)
		var sgn := signf(h1 - h0)
		var s0 := 0.0
		var s1 := 0.0
		if libre0 and libre1:
			s0 = minf(shift * 0.5, TERRASSEMENT_BOUT)
			s1 = shift - s0
		elif libre0:
			s0 = shift
		else:
			s1 = shift
		h0 += sgn * s0
		h1 -= sgn * s1
		res.terr_bout = shift
		need = absf(h1 - h0) / length

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
	var ceil_h := PackedFloat32Array()
	ceil_h.resize(n)
	ceil_h.fill(INF)
	var forced := PackedInt32Array()
	forced.resize(n)
	forced.fill(-1)
	for i in n:
		floor_h[i] = -INF if is_nan(ws[i]) else ws[i] + RIVER_CLEARANCE
	for bd in bounds:
		for i in n:
			var si := float(i) * ds
			if si < float(bd.s0) or si > float(bd.s1):
				continue
			floor_h[i] = maxf(floor_h[i], float(bd.get("lo", -INF)))
			ceil_h[i] = minf(ceil_h[i], float(bd.get("hi", INF)))
			forced[i] = int(bd.get("st", -1))
	for i in n:
		p[i] = minf(maxf(p[i], floor_h[i]), ceil_h[i])
	p[0] = h0
	p[n - 1] = h1
	for _pass in 6:
		for i in range(1, n):
			p[i] = minf(maxf(clampf(p[i], p[i - 1] - step_max, p[i - 1] + step_max), floor_h[i]), ceil_h[i])
		for i in range(n - 2, -1, -1):
			p[i] = minf(maxf(clampf(p[i], p[i + 1] - step_max, p[i + 1] + step_max), floor_h[i]), ceil_h[i])
		p[0] = h0
		p[n - 1] = h1

	# Structure de chaque point.
	var bridge_gap: float = ty.bridge_gap
	var tunnel_depth: float = ty.tunnel_depth
	for i in n:
		var diff := p[i] - g[i]
		if (g[i] < SEA_LEVEL and depth <= 0.0) or diff > bridge_gap:
			st[i] = TransportTypes.Struct.BRIDGE
		elif diff < -tunnel_depth:
			st[i] = TransportTypes.Struct.TUNNEL
		else:
			st[i] = TransportTypes.Struct.GROUND
	_clean_runs(st, maxi(2, roundi(8.0 / ds)))
	# Passages imposés : pont au-dessus de l'autre voie, tunnel dessous.
	for i in n:
		if forced[i] >= 0:
			st[i] = forced[i]
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
	res.need_grade = need
	if need > hard + 1e-4:
		res.reason = "Pente trop forte : %s %% (maximum %s %% pour %s, %s %% en tolérance). Essaie « Lacets » ou un tunnel." % [
			TransportTypes._num(need * 100.0), TransportTypes._num(grade * 100.0), String(ty.name).to_lower(),
			TransportTypes._num(hard * 100.0)]
		return res
	if too_tight:
		res.reason = _radius_reason(ty, rad, type_id)
		return res
	# Zone orange : construit quand même, plus cher, véhicules ralentis.
	var avert := []
	if need > grade + 1e-4:
		avert.append("pente %s %% (norme %s %%)" % [TransportTypes._num(snappedf(need * 100.0, 0.1)), TransportTypes._num(grade * 100.0)])
	if serre:
		avert.append("virage en épingle (rayon %d m, norme %d m)" % [roundi(rad), roundi(r_min)])
	res.orange = not avert.is_empty()
	res.avert = " · ".join(avert)
	res.ok = true
	return res


static func _radius_reason(ty: Dictionary, rad: float, type_id := "") -> String:
	var tol := TransportTypes.rayon_tolere(type_id) if type_id != "" else float(ty.r_min)
	if tol < float(ty.r_min) - 0.5:
		return "Virage trop serré : rayon %d m (minimum %d m pour %s, %d m en épingle)." % [
			roundi(rad), roundi(ty.r_min), String(ty.name).to_lower(), roundi(tol)]
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


# --- Lacets ---------------------------------------------------------------------------

## Tracé en lacets de a (hauteur ha) à b (hauteur hb) pour la classe type_id :
## des branches en travers de la pente reliées par des épingles au rayon
## d'épingle de la classe, assez longues pour monter à LACETS_PENTE × la pente
## de la norme. Renvoie [a, b] si la ligne droite suffit ; un tableau vide si
## même les lacets ne tiennent pas (trop raide pour la place disponible).
static func lacets(a: Vector2, b: Vector2, ha: float, hb: float, type_id: String) -> PackedVector2Array:
	var d := a.distance_to(b)
	var g := TransportTypes.grade_norme(type_id) * LACETS_PENTE
	if g <= 0.0 or d < 1.0 or is_nan(ha) or is_nan(hb):
		return PackedVector2Array([a, b])
	var need_len := absf(hb - ha) / g
	if need_len <= d * 1.02:
		return PackedVector2Array([a, b])
	need_len = minf(need_len, MAX_LENGTH * 0.95)
	var r := TransportTypes.rayon_tolere(type_id) * 1.15
	var u := (b - a) / d
	var v := Vector2(-u.y, u.x)
	var best := PackedVector2Array()
	for n in range(2, 80):
		var adv := d / float(n)
		if adv < 2.2 * r:
			break
		# Les épingles raccourcissent le tracé : on élargit jusqu'à la bonne longueur.
		var cible := need_len
		var line := PackedVector2Array()
		for _essai in 8:
			var w := _largeur_lacets(n, adv, cible)
			if w > LACETS_LARGEUR_MAX or w < 3.0 * r:
				line = PackedVector2Array()
				break
			var corners := PackedVector2Array([a])
			for k in range(1, n):
				var side := 1.0 if k % 2 == 1 else -1.0
				corners.append(a + u * adv * float(k) + v * w * 0.5 * side)
			corners.append(b)
			line = _arrondir(corners, r)
			if line.is_empty():
				break
			var l := polyline_length(line)
			if l >= need_len * 0.98 or l > MAX_LENGTH * 0.95:
				break
			cible *= need_len / maxf(l, 1.0)
		if not line.is_empty() and polyline_length(line) >= need_len * 0.95:
			best = line # on garde le lacet le plus serré qui tient (plus de branches)
	return best


## Largeur w (m) du lacet à n branches qui avance de adv par branche et mesure
## total m : 2 demi-branches au bout, n − 2 branches entières.
static func _largeur_lacets(n: int, adv: float, total: float) -> float:
	var lo := 0.0
	var hi := LACETS_LARGEUR_MAX * 2.0
	for _i in 40:
		var w := (lo + hi) * 0.5
		var l := 2.0 * sqrt(adv * adv + w * w * 0.25) + float(n - 2) * sqrt(adv * adv + w * w)
		if l < total:
			lo = w
		else:
			hi = w
	return (lo + hi) * 0.5


## Route tracée au geste (piste CityRT 7) : la souris a dessiné `brut` (points au
## sol, dans l'ordre). On garde l'allure du geste mais on la rend conforme : les
## tremblements sont gommés (Ramer-Douglas-Peucker), puis chaque angle devient un
## arc de cercle au rayon minimal de la classe de voie (un peu plus, par confort).
## Si un virage n'a pas la place, on simplifie davantage ; au pire, une droite.
static func trace_geste(brut: PackedVector2Array, type_id: String) -> PackedVector2Array:
	if brut.size() < 2:
		return brut
	var ty := TransportTypes.get_type(type_id)
	var r := float(ty.get("r_min", 15.0)) * 1.15
	var long := polyline_length(brut)
	if long < 1.0:
		return PackedVector2Array([brut[0], brut[brut.size() - 1]])
	var tol := maxf(1.5, TransportTypes.width_of(type_id, TransportTypes.default_spec(type_id)) * 0.4)
	for essai in 8:
		var coins := simplifier(brut, tol)
		if coins.size() <= 2:
			return PackedVector2Array([brut[0], brut[brut.size() - 1]])
		var arc := _arrondir(coins, r)
		if not arc.is_empty() and min_radius(resample(arc, TransportTypes.STEP)) >= float(ty.get("r_min", 15.0)) - 0.5:
			return arc
		tol *= 1.7
	return PackedVector2Array([brut[0], brut[brut.size() - 1]])


## Ramer-Douglas-Peucker : garde les points qui s'écartent de plus de `tol` mètres.
static func simplifier(p: PackedVector2Array, tol: float) -> PackedVector2Array:
	if p.size() <= 2:
		return p
	var garde := PackedByteArray()
	garde.resize(p.size())
	garde[0] = 1
	garde[p.size() - 1] = 1
	var pile := [[0, p.size() - 1]]
	while not pile.is_empty():
		var seg: Array = pile.pop_back()
		var a: int = seg[0]
		var b: int = seg[1]
		var best := -1
		var best_d := tol
		for i in range(a + 1, b):
			var d := _dist_segment(p[i], p[a], p[b])
			if d > best_d:
				best_d = d
				best = i
		if best >= 0:
			garde[best] = 1
			pile.append([a, best])
			pile.append([best, b])
	var out := PackedVector2Array()
	for i in p.size():
		if garde[i] == 1:
			out.append(p[i])
	return out


static func _dist_segment(q: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 < 1e-9:
		return q.distance_to(a)
	var t := clampf((q - a).dot(ab) / l2, 0.0, 1.0)
	return q.distance_to(a + ab * t)


## Arrondit chaque coin intérieur d'une ligne brisée par un arc de rayon r
## (épingles). Vide si un arc ne tient pas sur ses branches.
static func _arrondir(c: PackedVector2Array, r: float) -> PackedVector2Array:
	var out := PackedVector2Array([c[0]])
	var avail := PackedFloat32Array()
	for i in range(1, c.size()):
		avail.append(c[i].distance_to(c[i - 1]))
	var used := PackedFloat32Array()
	used.resize(avail.size())
	for i in range(1, c.size() - 1):
		var d1 := (c[i] - c[i - 1]).normalized()
		var d2 := (c[i + 1] - c[i]).normalized()
		var phi := d1.angle_to(d2)
		var t := r * tan(absf(phi) * 0.5)
		used[i - 1] += t
		used[i] += t
		var t1 := c[i] - d1 * t
		var t2 := c[i] + d2 * t
		var nrm := d1.rotated(signf(phi) * PI * 0.5)
		var ctr := t1 + nrm * r
		var a0 := (t1 - ctr).angle()
		var steps := maxi(4, ceili(absf(phi) * r / 1.5))
		for k in steps + 1:
			out.append(ctr + Vector2.from_angle(a0 + phi * float(k) / float(steps)) * r)
		if t2.distance_to(out[out.size() - 1]) > 0.01:
			out.append(t2)
	for i in avail.size():
		if used[i] > avail[i] * 0.9:
			return PackedVector2Array()
	out.append(c[c.size() - 1])
	return out


# --- Volumes de terrassement ------------------------------------------------------------

## Volumes (m³) de déblai et de remblai d'une voie au sol, talus compris (estimation
## le long du tracé) ; "gros" : la part au-delà de 1 m de profondeur ou de hauteur,
## facturée en plus (TransportSystem.surcout).
static func volumes(width: float, pts: PackedVector3Array, st: PackedByteArray, ground: Callable) -> Dictionary:
	var out := {"deblai": 0.0, "remblai": 0.0, "gros": 0.0}
	var n := pts.size()
	if n < 2 or not ground.is_valid():
		return out
	for i in n:
		if st[i] != TransportTypes.Struct.GROUND:
			continue
		var gh: float = ground.call(pts[i].x, pts[i].z)
		if is_nan(gh):
			continue
		var ds := 0.0
		if i > 0:
			ds += pts[i].distance_to(pts[i - 1]) * 0.5
		if i < n - 1:
			ds += pts[i].distance_to(pts[i + 1]) * 0.5
		var dh := pts[i].y - gh
		var ah := absf(dh)
		var vol := ah * ds * (width + minf(TALUS_MAX, ah * TALUS))
		if dh > 0.0:
			out["remblai"] += vol
		else:
			out["deblai"] += vol
		if ah > 1.0:
			out["gros"] += (ah - 1.0) * ds * (width + minf(TALUS_MAX, ah * TALUS))
	return out


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
