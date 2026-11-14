class_name FormesPlus
extends RefCounted
## Formes ajoutées à l'éditeur libre (troisième version) : arrondis, arcs,
## dômes, détails d'architecture (corniche, créneaux, balustrade, lucarne…),
## nouvelles fenêtres et portes, et les grandes pièces de taille réglable
## (coupole, bulbe, toit conique, flèche, tour ronde, cylindre, pyramide,
## voûte en berceau, grande arche, arc brisé, demi-coupole).
##
## Même repère que BlocFormes : case unité [0, 1]³, rotation 0 = la façade
## regarde vers −Z, une pente monte vers +Z.
##
## Une grande pièce occupe plusieurs cases : chaque case est un bloc qui porte
## son morceau (dx, dy, dz) et la taille de la pièce (BlocFormes.encode_part).
## La géométrie de la pièce entière est calculée une fois (cache), puis chaque
## morceau ne dessine que les faces dont le centre tombe dans sa case.

const S := BlocFormes.S
const WHITE := Color(1, 1, 1)
const DARK := Color(0.22, 0.24, 0.27)
const GLASS_M := 10
const VITRAIL_M := 51


# --- Aides ------------------------------------------------------------------------------

static func _f(ctx: Dictionary, pts: Array, n: Vector3, layer := -1, glass := -1, col: Variant = null) -> void:
	BlocFormes._face(ctx, pts, n, layer, glass, col)


static func _b(ctx: Dictionary, x0: float, y0: float, z0: float, x1: float, y1: float, z1: float, skip := 0, layer := -1, glass := -1, col: Variant = null) -> void:
	BlocFormes._box(ctx, x0, y0, z0, x1, y1, z1, skip, layer, glass, col)


## Surface de révolution : profil [Vector2(rayon, hauteur)] de bas en haut,
## autour de l'axe vertical (cx, cz), de l'angle a0 à a1 en n morceaux.
## flip : normales vers l'axe (face intérieure).
static func revolve(ctx: Dictionary, prof: Array, cx: float, cz: float, n: int, flip := false, a0 := 0.0, a1 := TAU, layer := -1, glass := -1, col: Variant = null) -> void:
	for i in n:
		var aa := a0 + (a1 - a0) * i / n
		var ab := a0 + (a1 - a0) * (i + 1) / n
		var am := (aa + ab) / 2.0
		for j in prof.size() - 1:
			var p0: Vector2 = prof[j]
			var p1: Vector2 = prof[j + 1]
			var d := p1 - p0
			var nr := d.y
			var ny := -d.x
			var l := sqrt(nr * nr + ny * ny)
			if l < 1e-6:
				continue
			var nn := Vector3(cos(am) * nr / l, ny / l, sin(am) * nr / l)
			if flip:
				nn = -nn
			var pts := []
			for q in [[p0, aa], [p0, ab], [p1, ab], [p1, aa]]:
				var pp: Vector2 = q[0]
				var a: float = q[1]
				var v := Vector3(cx + cos(a) * pp.x, pp.y, cz + sin(a) * pp.x)
				if pts.is_empty() or not (pts[-1] as Vector3).is_equal_approx(v):
					pts.append(v)
			if pts.size() == 4 and (pts[0] as Vector3).is_equal_approx(pts[3]):
				pts.pop_back()
			if pts.size() >= 3:
				_f(ctx, pts, nn, layer, glass, col)


## Disque horizontal (ou secteur) de rayon r à la hauteur y.
static func disc(ctx: Dictionary, cx: float, y: float, cz: float, r: float, n: int, up: bool, a0 := 0.0, a1 := TAU, layer := -1, col: Variant = null) -> void:
	var c := Vector3(cx, y, cz)
	for i in n:
		var aa := a0 + (a1 - a0) * i / n
		var ab := a0 + (a1 - a0) * (i + 1) / n
		_f(ctx, [c, Vector3(cx + cos(aa) * r, y, cz + sin(aa) * r), Vector3(cx + cos(ab) * r, y, cz + sin(ab) * r)],
			Vector3.UP if up else Vector3.DOWN, layer, -1, col)


## Prisme couché le long de x (0 → 1) sous une courbe y = c(z), z de z0 à z1 :
## dessus courbe, deux bouts, dessous, et les faces avant/arrière s'il y a une hauteur.
static func extrude_x(ctx: Dictionary, zs: Array, ys: Array, x0 := 0.0, x1 := 1.0, ybase := 0.0) -> void:
	var n := zs.size()
	for i in n - 1:
		var za: float = zs[i]
		var zb: float = zs[i + 1]
		var ya: float = ys[i]
		var yb: float = ys[i + 1]
		var nn := Vector3(0, zb - za, -(yb - ya)).normalized()
		_f(ctx, [Vector3(x0, ya, za), Vector3(x1, ya, za), Vector3(x1, yb, zb), Vector3(x0, yb, zb)], nn)
		if absf(ya - ybase) + absf(yb - ybase) > 1e-4:
			_f(ctx, [Vector3(x0, ybase, za), Vector3(x0, ybase, zb), Vector3(x0, yb, zb), Vector3(x0, ya, za)], Vector3.LEFT)
			_f(ctx, [Vector3(x1, ybase, za), Vector3(x1, ybase, zb), Vector3(x1, yb, zb), Vector3(x1, ya, za)], Vector3.RIGHT)
	var z0: float = zs[0]
	var z1: float = zs[n - 1]
	_f(ctx, [Vector3(x0, ybase, z0), Vector3(x1, ybase, z0), Vector3(x1, ybase, z1), Vector3(x0, ybase, z1)], Vector3.DOWN)
	if float(ys[0]) > ybase + 1e-4:
		_f(ctx, [Vector3(x0, ybase, z0), Vector3(x1, ybase, z0), Vector3(x1, ys[0], z0), Vector3(x0, ys[0], z0)], Vector3.FORWARD)
	if float(ys[n - 1]) > ybase + 1e-4:
		_f(ctx, [Vector3(x0, ybase, z1), Vector3(x1, ybase, z1), Vector3(x1, ys[n - 1], z1), Vector3(x0, ys[n - 1], z1)], Vector3.BACK)


## Panneau [x0, x1] × [y0, y1] d'épaisseur z0 → z1, percé d'un trou entre
## x = h0 et h1, de y = lo(x) à hi(x). Dessine aussi le tableau (l'épaisseur du trou)
## dans la couleur rcol (cadre) et, si glass_z ≥ 0, la vitre au milieu.
static func holed(ctx: Dictionary, x0: float, x1: float, y0: float, y1: float, z0: float, z1: float,
		h0: float, h1: float, lo: Callable, hi: Callable, n: int, rcol: Variant = null, glass_z := -1.0, glass_layer := -1, sides := true) -> void:
	var rl := BlocMateriaux.PLAIN if rcol != null else -1
	# Parties pleines à gauche et à droite du trou.
	for pair in [[x0, h0], [h1, x1]]:
		var a: float = pair[0]
		var b: float = pair[1]
		if b - a > 1e-4:
			_f(ctx, [Vector3(a, y0, z0), Vector3(b, y0, z0), Vector3(b, y1, z0), Vector3(a, y1, z0)], Vector3.FORWARD)
			_f(ctx, [Vector3(a, y0, z1), Vector3(b, y0, z1), Vector3(b, y1, z1), Vector3(a, y1, z1)], Vector3.BACK)
	for i in n:
		var xa := h0 + (h1 - h0) * i / n
		var xb := h0 + (h1 - h0) * (i + 1) / n
		var la: float = lo.call(xa)
		var lb: float = lo.call(xb)
		var ha: float = hi.call(xa)
		var hb: float = hi.call(xb)
		for z in [z0, z1]:
			var nz := Vector3.FORWARD if z == z0 else Vector3.BACK
			if la > y0 + 1e-4 or lb > y0 + 1e-4:
				_f(ctx, [Vector3(xa, y0, z), Vector3(xb, y0, z), Vector3(xb, lb, z), Vector3(xa, la, z)], nz)
			if ha < y1 - 1e-4 or hb < y1 - 1e-4:
				_f(ctx, [Vector3(xa, ha, z), Vector3(xb, hb, z), Vector3(xb, y1, z), Vector3(xa, y1, z)], nz)
		# Tableau : dessous (regarde vers le haut) et dessus du trou (regarde vers le bas).
		if la > y0 + 1e-4 or lb > y0 + 1e-4 or not sides:
			_f(ctx, [Vector3(xa, la, z0), Vector3(xb, lb, z0), Vector3(xb, lb, z1), Vector3(xa, la, z1)],
				Vector3(-(lb - la), xb - xa, 0).normalized(), rl, 0, rcol)
		_f(ctx, [Vector3(xa, ha, z0), Vector3(xb, hb, z0), Vector3(xb, hb, z1), Vector3(xa, ha, z1)],
			Vector3(hb - ha, -(xb - xa), 0).normalized(), rl, 0, rcol)
		if glass_z >= 0.0 and ha - la + hb - lb > 1e-4:
			_f(ctx, [Vector3(xa, la, glass_z), Vector3(xb, lb, glass_z), Vector3(xb, hb, glass_z), Vector3(xa, ha, glass_z)],
				Vector3.FORWARD, BlocMateriaux.layer(GLASS_M) if glass_layer < 0 else glass_layer, 1, WHITE)
	# Côtés du trou.
	var l0: float = lo.call(h0)
	var t0: float = hi.call(h0)
	var l1: float = lo.call(h1)
	var t1: float = hi.call(h1)
	if t0 - l0 > 1e-4:
		_f(ctx, [Vector3(h0, l0, z0), Vector3(h0, l0, z1), Vector3(h0, t0, z1), Vector3(h0, t0, z0)], Vector3.RIGHT, rl, 0, rcol)
	if t1 - l1 > 1e-4:
		_f(ctx, [Vector3(h1, l1, z0), Vector3(h1, l1, z1), Vector3(h1, t1, z1), Vector3(h1, t1, z0)], Vector3.LEFT, rl, 0, rcol)
	if sides:
		_b(ctx, x0, y0, z0, x1, y1, z1, 16 | 32 | (3 if h0 <= x0 + 1e-4 else 0))


static func _circ(c: float, r: float, x: float) -> float:
	return sqrt(maxf(r * r - (x - c) * (x - c), 0.0))


# --- Petites formes (une case) -------------------------------------------------------------

static func emit(ctx: Dictionary, code: int, shape: int, neighbor: Callable) -> void:
	if BlocFormes.is_piece(shape):
		_emit_piece(ctx, code, shape)
		return
	match shape:
		S.ROUND_OUT:
			revolve(ctx, [Vector2(1, 0), Vector2(1, 1)], 1, 1, 6, false, PI, PI * 1.5)
			disc(ctx, 1, 1, 1, 1, 6, true, PI, PI * 1.5)
			disc(ctx, 1, 0, 1, 1, 6, false, PI, PI * 1.5)
			_f(ctx, [Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(1, 1, 0)], Vector3.RIGHT)
			_f(ctx, [Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(0, 1, 1)], Vector3.BACK)
		S.ROUND_IN:
			revolve(ctx, [Vector2(1, 0), Vector2(1, 1)], 1, 1, 6, true, PI, PI * 1.5)
			for i in 6:
				var aa := PI + PI * 0.5 * i / 6
				var ab := PI + PI * 0.5 * (i + 1) / 6
				var pa := Vector3(1 + cos(aa), 0, 1 + sin(aa))
				var pb := Vector3(1 + cos(ab), 0, 1 + sin(ab))
				_f(ctx, [Vector3(0, 1, 0), pa + Vector3(0, 1, 0), pb + Vector3(0, 1, 0)], Vector3.UP)
				_f(ctx, [Vector3(0, 0, 0), pa, pb], Vector3.DOWN)
			_f(ctx, [Vector3(0, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(0, 1, 0)], Vector3.LEFT)
			_f(ctx, [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(0, 1, 0)], Vector3.FORWARD)
		S.CYLINDER:
			revolve(ctx, [Vector2(0.5, 0), Vector2(0.5, 1)], 0.5, 0.5, 12)
			_caps(ctx, code, neighbor, 0.5, 12)
		S.HALF_ROUND:
			var zs := []
			var ys := []
			for i in 9:
				var t := PI * (1.0 - float(i) / 8.0)
				zs.append(0.5 + 0.5 * cos(t))
				ys.append(0.5 * sin(t))
			extrude_x(ctx, zs, ys)
		S.CURVE_UP:
			var zs2 := []
			var ys2 := []
			for i in 9:
				var t := PI - PI * 0.5 * i / 8.0
				zs2.append(1.0 + cos(t))
				ys2.append(sin(t))
			extrude_x(ctx, zs2, ys2)
		S.CURVE_IN:
			var zs3 := []
			var ys3 := []
			for i in 9:
				var t := PI * 0.5 * i / 8.0
				zs3.append(sin(t))
				ys3.append(1.0 - cos(t))
			extrude_x(ctx, zs3, ys3)
		S.DOME_SMALL:
			var prof := []
			for i in 7:
				var t := PI * 0.5 * i / 6.0
				prof.append(Vector2(0.5 * cos(t), 0.5 * sin(t)))
			revolve(ctx, prof, 0.5, 0.5, 12)
			disc(ctx, 0.5, 0, 0.5, 0.5, 12, false)
		S.SPHERE:
			var sp := []
			for i in 9:
				var t := -PI * 0.5 + PI * i / 8.0
				sp.append(Vector2(0.5 * cos(t), 0.5 + 0.5 * sin(t)))
			revolve(ctx, sp, 0.5, 0.5, 12)
		S.CONE_SMALL:
			revolve(ctx, [Vector2(0.56, 0), Vector2(0, 1)], 0.5, 0.5, 12)
			disc(ctx, 0.5, 0, 0.5, 0.56, 12, false)
		S.FINIAL:
			revolve(ctx, [Vector2(0.14, 0), Vector2(0.07, 0.1), Vector2(0.05, 0.33), Vector2(0.11, 0.38), Vector2(0.14, 0.46),
				Vector2(0.11, 0.54), Vector2(0.04, 0.6), Vector2(0.03, 0.72), Vector2(0, 1)], 0.5, 0.5, 8)
			disc(ctx, 0.5, 0, 0.5, 0.14, 8, false)
		S.ARCH_SMALL:
			holed(ctx, 0, 1, 0, 1, 0, 1, 0, 1, func(_x: float) -> float: return 0.0,
				func(x: float) -> float: return _circ(0.5, 0.5, x), 10)
		S.ARCH_HALF:
			holed(ctx, 0, 1, 0, 1, 0, 1, 0.1, 1, func(_x: float) -> float: return 0.0,
				func(x: float) -> float: return _circ(1.0, 0.9, x), 9)
		S.CORNICE:
			_b(ctx, 0, 0, 0, 1, 0.6, 1)
			_b(ctx, 0, 0.6, -0.08, 1, 0.72, 1, 1)
			_b(ctx, 0, 0.72, -0.14, 1, 0.8, 1, 1)
			# Quart de rond.
			var zs4 := []
			var ys4 := []
			for i in 5:
				var t := PI * 0.5 * i / 4.0
				zs4.append(-0.14 - 0.08 * sin(t))
				ys4.append(0.8 + 0.08 * (1.0 - cos(t)))
			for i in 4:
				var za: float = zs4[i]
				var zb: float = zs4[i + 1]
				var ya: float = ys4[i]
				var yb: float = ys4[i + 1]
				var mid := Vector3(0, (ya + yb) / 2.0 - 0.88, (za + zb) / 2.0 + 0.14).normalized()
				_f(ctx, [Vector3(0, ya, za), Vector3(1, ya, za), Vector3(1, yb, zb), Vector3(0, yb, zb)], mid)
			_b(ctx, 0, 0.88, -0.26, 1, 1, 1, 1)
		S.CRENEL:
			_b(ctx, 0, 0, 0.2, 1, 0.5, 0.8)
			_b(ctx, 0, 0.5, 0.2, 0.5, 1, 0.8, 1)
		S.BALUSTRADE:
			_b(ctx, 0, 0, 0.32, 1, 0.12, 0.68)
			_b(ctx, -0.0, 0.86, 0.3, 1, 1, 0.7)
			for i in 4:
				var x := 0.125 + 0.25 * i
				revolve(ctx, [Vector2(0.06, 0.12), Vector2(0.1, 0.3), Vector2(0.11, 0.38), Vector2(0.05, 0.55),
					Vector2(0.07, 0.72), Vector2(0.05, 0.86)], x, 0.5, 6)
		S.CHIMNEY:
			_b(ctx, 0.2, 0, 0.2, 0.8, 0.82, 0.8)
			_b(ctx, 0.14, 0.82, 0.14, 0.86, 0.9, 0.86)
			revolve(ctx, [Vector2(0.09, 0.9), Vector2(0.09, 1.0)], 0.5, 0.5, 8, false, 0, TAU, BlocMateriaux.layer(7), 0, WHITE)
			disc(ctx, 0.5, 1.0, 0.5, 0.09, 8, true, 0, TAU, BlocMateriaux.PLAIN, DARK)
		S.DORMER:
			_dormer(ctx)
		S.AWNING:
			var stripes := 5
			for i in stripes:
				var xa := float(i) / stripes
				var xb := float(i + 1) / stripes
				var c: Color = ctx.col if i % 2 == 0 else WHITE
				var nn := Vector3(0, 0.6, -0.4).normalized()
				_f(ctx, [Vector3(xa, 0.55, -0.6), Vector3(xb, 0.55, -0.6), Vector3(xb, 0.95, 0), Vector3(xa, 0.95, 0)], nn, BlocMateriaux.PLAIN, 0, c)
				_f(ctx, [Vector3(xa, 0.55, -0.6), Vector3(xb, 0.55, -0.6), Vector3(xb, 0.95, 0), Vector3(xa, 0.95, 0)], -nn, BlocMateriaux.PLAIN, 0, c)
				_f(ctx, [Vector3(xa, 0.42, -0.61), Vector3(xb, 0.42, -0.61), Vector3(xb, 0.55, -0.61), Vector3(xa, 0.55, -0.61)], Vector3.FORWARD, BlocMateriaux.PLAIN, 0, c)
			_b(ctx, 0, 0.93, -0.02, 1, 0.98, 0.02, 0, BlocMateriaux.PLAIN, 0, DARK)
		S.BALCONY:
			_b(ctx, 0, 0, 0, 1, 0.14, 1)
			_b(ctx, 0, 0.96, 0, 1, 1.04, 0.06)
			_b(ctx, 0, 0.96, 0, 0.06, 1.04, 1)
			_b(ctx, 0.94, 0.96, 0, 1, 1.04, 1)
			for i in 6:
				var x := 0.08 + i * 0.168
				_b(ctx, x, 0.14, 0.015, x + 0.03, 0.96, 0.045, 3)
			for i in 5:
				var z := 0.2 + i * 0.18
				_b(ctx, 0.015, 0.14, z, 0.045, 0.96, z + 0.03, 3)
				_b(ctx, 0.955, 0.14, z, 0.985, 0.96, z + 0.03, 3)
		S.LATTICE:
			_b(ctx, 0, 0, 0.44, 1, 0.08, 0.56)
			_b(ctx, 0, 0.92, 0.44, 1, 1, 0.56)
			_b(ctx, 0, 0.08, 0.44, 0.08, 0.92, 0.56, 3)
			_b(ctx, 0.92, 0.08, 0.44, 1, 0.92, 0.56, 3)
			for i in 3:
				var t := 0.08 + 0.84 * (i + 1) / 4.0
				_b(ctx, t - 0.035, 0.08, 0.45, t + 0.035, 0.92, 0.55, 3)
				_b(ctx, 0.08, t - 0.035, 0.45, 0.92, t + 0.035, 0.55, 12)
		S.OCULUS:
			holed(ctx, 0, 1, 0, 1, 0.42, 0.58, 0.18, 0.82, func(x: float) -> float: return 0.5 - _circ(0.5, 0.32, x),
				func(x: float) -> float: return 0.5 + _circ(0.5, 0.32, x), 12, WHITE, 0.5)
			_b(ctx, 0.48, 0.2, 0.47, 0.52, 0.8, 0.53, 3, BlocMateriaux.PLAIN, 0, WHITE)
			_b(ctx, 0.2, 0.48, 0.47, 0.8, 0.52, 0.53, 12, BlocMateriaux.PLAIN, 0, WHITE)
		S.WINDOW_ARCH:
			holed(ctx, 0, 1, 0, 1, 0.42, 0.58, 0.12, 0.88, func(_x: float) -> float: return 0.08,
				func(x: float) -> float: return 0.6 + _circ(0.5, 0.38, x), 12, WHITE, 0.5)
			_b(ctx, 0.48, 0.08, 0.47, 0.52, 0.96, 0.53, 3, BlocMateriaux.PLAIN, 0, WHITE)
			_b(ctx, 0.12, 0.58, 0.47, 0.88, 0.62, 0.53, 12, BlocMateriaux.PLAIN, 0, WHITE)
			_b(ctx, -0.03, 0, -0.08, 1.03, 0.06, 0.42)
		S.WINDOW_GOTHIC:
			holed(ctx, 0, 1, 0, 1, 0.42, 0.58, 0.2, 0.8, func(_x: float) -> float: return 0.06,
				func(x: float) -> float: return 0.42 + (_circ(0.8, 0.6, x) if x <= 0.5 else _circ(0.2, 0.6, x)), 12, WHITE, 0.5, BlocMateriaux.layer(VITRAIL_M))
		S.WINDOW_GRID:
			_b(ctx, 0, 0, 0.44, 0.05, 1, 0.56)
			_b(ctx, 0.95, 0, 0.44, 1, 1, 0.56)
			_b(ctx, 0.05, 0.95, 0.44, 0.95, 1, 0.56, 12)
			_b(ctx, 0.05, 0, 0.44, 0.95, 0.05, 0.56, 12)
			_f(ctx, [Vector3(0.05, 0.05, 0.5), Vector3(0.95, 0.05, 0.5), Vector3(0.95, 0.95, 0.5), Vector3(0.05, 0.95, 0.5)], Vector3.FORWARD, BlocMateriaux.layer(GLASS_M), 1, WHITE)
			for i in 3:
				var t := 0.05 + 0.9 * (i + 1) / 4.0
				_b(ctx, t - 0.012, 0.05, 0.48, t + 0.012, 0.95, 0.52, 3, BlocMateriaux.PLAIN, 0, DARK)
				_b(ctx, 0.05, t - 0.012, 0.48, 0.95, t + 0.012, 0.52, 12, BlocMateriaux.PLAIN, 0, DARK)
		S.SLIT:
			holed(ctx, 0, 1, 0, 1, 0, 1, 0.44, 0.56, func(_x: float) -> float: return 0.2,
				func(_x: float) -> float: return 0.85, 1)
			_f(ctx, [Vector3(0.44, 0.2, 0.5), Vector3(0.56, 0.2, 0.5), Vector3(0.56, 0.85, 0.5), Vector3(0.44, 0.85, 0.5)], Vector3.FORWARD, BlocMateriaux.PLAIN, 0, Color(0.08, 0.08, 0.09))
		S.DOOR_ARCH:
			_door_arch(ctx, BlocFormes.is_top(code), BlocFormes.is_open(code))
		S.DOOR_BARN:
			_door_barn(ctx, BlocFormes.is_top(code), BlocFormes.is_open(code))
		_:
			_b(ctx, 0, 0, 0, 1, 1, 1)


## Dessus et dessous d'un cylindre, sauf s'il continue au-dessus ou au-dessous.
static func _caps(ctx: Dictionary, code: int, neighbor: Callable, r: float, n: int) -> void:
	var hu := BlockEditor.HU
	var sh := BlocFormes.shape_of(code)
	var above: int = neighbor.call(Vector3i(0, hu, 0))
	var below: int = neighbor.call(Vector3i(0, -hu, 0))
	if above < 0 or BlocFormes.shape_of(above) != sh:
		disc(ctx, 0.5, 1, 0.5, r, n, true)
	if below < 0 or BlocFormes.shape_of(below) != sh:
		disc(ctx, 0.5, 0, 0.5, r, n, false)


static func _dormer(ctx: Dictionary) -> void:
	BlocFormes._wedge(ctx, 0.0, 1.0)
	var y0 := 0.12
	var y1 := 0.72
	var x0 := 0.15
	var x1 := 0.85
	var zf := 0.12
	# Joues (côtés) jusqu'au pan du toit (y = z).
	_f(ctx, [Vector3(x0, y0, zf), Vector3(x0, y0, y0), Vector3(x0, y1, y1), Vector3(x0, y1, zf)], Vector3.LEFT)
	_f(ctx, [Vector3(x1, y0, zf), Vector3(x1, y0, y0), Vector3(x1, y1, y1), Vector3(x1, y1, zf)], Vector3.RIGHT)
	# Façade : cadre et vitre.
	holed(ctx, x0, x1, y0, y1, zf, zf + 0.06, x0 + 0.1, x1 - 0.1, func(_x: float) -> float: return y0 + 0.08,
		func(_x: float) -> float: return y1 - 0.06, 1, WHITE, zf + 0.03, -1, false)
	# Fronton : triangle et petit toit à deux pans (faîtage le long de z).
	var ridge := y1 + 0.22
	_f(ctx, [Vector3(x0, y1, zf), Vector3(x1, y1, zf), Vector3(0.5, ridge, zf)], Vector3.FORWARD)
	var e0 := x0 - 0.06
	var e1 := x1 + 0.06
	var zb := ridge + 0.05
	var top := zf - 0.05
	_f(ctx, [Vector3(e0, y1 - 0.04, top), Vector3(0.5, ridge + 0.03, top), Vector3(0.5, ridge + 0.03, zb), Vector3(e0, y1 - 0.04, zb)], Vector3(-0.6, 1, 0).normalized(), BlocMateriaux.layer(8), 0, WHITE)
	_f(ctx, [Vector3(e1, y1 - 0.04, top), Vector3(0.5, ridge + 0.03, top), Vector3(0.5, ridge + 0.03, zb), Vector3(e1, y1 - 0.04, zb)], Vector3(0.6, 1, 0).normalized(), BlocMateriaux.layer(8), 0, WHITE)


static func _door_arch(ctx: Dictionary, top: bool, open: bool) -> void:
	var z0 := 0.36
	var z1 := 0.64
	var leaf: Color = Color(0.55, 0.36, 0.22)
	var ll := BlocMateriaux.layer(3)
	if not top:
		_b(ctx, 0, 0, z0, 0.1, 1, z1)
		_b(ctx, 0.9, 0, z0, 1, 1, z1)
		_b(ctx, 0.1, 0, z0 - 0.04, 0.9, 0.03, z1 + 0.04, 12)
		if open:
			_b(ctx, 0.1, 0.03, 0.6, 0.16, 1, 1.38, 0, ll, 0, leaf)
			return
		_b(ctx, 0.1, 0.03, 0.46, 0.9, 1, 0.54, 2, ll, 0, leaf)
		var brass := Color(0.95, 0.8, 0.4)
		_b(ctx, 0.76, 0.95, 0.4, 0.84, 1.0, 0.46, 0, BlocMateriaux.PLAIN, 0, brass)
		for i in 3:
			var x := 0.1 + 0.8 * (i + 1) / 4.0
			_b(ctx, x - 0.01, 0.05, 0.445, x + 0.01, 0.98, 0.46, 3, BlocMateriaux.PLAIN, 0, leaf.darkened(0.35))
		return
	var hi := func(x: float) -> float: return 0.52 + _circ(0.5, 0.4, x)
	holed(ctx, 0, 1, 0, 1, z0, z1, 0.1, 0.9, func(_x: float) -> float: return 0.0, hi, 10)
	if open:
		_b(ctx, 0.1, 0, 0.6, 0.16, 0.85, 1.38, 0, ll, 0, leaf)
		return
	# Battant qui suit le cintre.
	for i in 8:
		var xa := 0.1 + 0.8 * i / 8.0
		var xb := 0.1 + 0.8 * (i + 1) / 8.0
		var ha: float = hi.call(xa) - 0.01
		var hb: float = hi.call(xb) - 0.01
		for z in [0.46, 0.54]:
			_f(ctx, [Vector3(xa, 0, z), Vector3(xb, 0, z), Vector3(xb, hb, z), Vector3(xa, ha, z)], Vector3.FORWARD if z < 0.5 else Vector3.BACK, ll, 0, leaf)


static func _door_barn(ctx: Dictionary, top: bool, open: bool) -> void:
	var z0 := 0.38
	var z1 := 0.62
	var wood: Color = ctx.col
	_b(ctx, 0, 0, z0, 0.06, 1, z1)
	_b(ctx, 0.94, 0, z0, 1, 1, z1)
	if top:
		_b(ctx, 0.06, 0.92, z0, 0.94, 1, z1, 12)
	var y1 := 0.92 if top else 1.0
	if open:
		_b(ctx, 0.06, 0, 0.6, 0.12, y1, 1.48)
		return
	_b(ctx, 0.06, 0, 0.46, 0.94, y1, 0.54, 3)
	for i in 5:
		var x := 0.06 + 0.88 * (i + 1) / 6.0
		_b(ctx, x - 0.008, 0, 0.445, x + 0.008, y1, 0.46, 3, BlocMateriaux.PLAIN, 0, DARK)
	# Traverses et écharpe en Z.
	var rails := [0.78] if top else [0.12]
	for ry in rails:
		_b(ctx, 0.08, ry - 0.06, 0.42, 0.92, ry + 0.06, 0.46)
	var ya := 0.12 if not top else -0.1
	var yb := 1.1 if not top else 0.78
	var d := Vector3(0, 0.06, 0)
	_f(ctx, [Vector3(0.1, ya, 0.415) - d, Vector3(0.9, yb, 0.415) - d, Vector3(0.9, yb, 0.415) + d, Vector3(0.1, ya, 0.415) + d], Vector3.FORWARD)


# --- Grandes pièces ------------------------------------------------------------------------

## Géométrie des pièces : "forme|taille|rotation" -> {Vector3i morceau: [[points, normale], …]}.
static var _cache: Dictionary = {}


## Étendue (en cases) d'une pièce non tournée : Vector2i(largeur x, profondeur z).
static func piece_extent(shape: int, size: int) -> Vector2i:
	match BlocFormes.piece_kind(shape):
		"tranche":
			return Vector2i(size, 1)
		"demi":
			return Vector2i(size, ceili(size / 2.0))
	return Vector2i(size, size)


## Morceaux de la pièce (décalages depuis son coin, en cases ; y en étages de 1 m).
static func piece_parts(shape: int, size: int, rot: int) -> Array:
	return _geo(shape, size, rot).keys()


static func _geo(shape: int, size: int, rot: int) -> Dictionary:
	var key := "%d|%d|%d" % [shape, size, rot]
	if _cache.has(key):
		return _cache[key]
	var faces: Array = []
	var ext := piece_extent(shape, size)
	_build_piece(faces, shape, float(size))
	# Rotation par quarts de tour, en restant dans l'emprise (cases positives).
	var w := float(ext.x)
	var l := float(ext.y)
	for r in rot % 4:
		for f in faces:
			var pts: Array = f[0]
			for i in pts.size():
				var p: Vector3 = pts[i]
				pts[i] = Vector3(l - p.z, p.y, p.x)
			var nn: Vector3 = f[1]
			f[1] = Vector3(-nn.z, nn.y, nn.x)
		var t := w
		w = l
		l = t
	var buckets := {}
	var maxx := int(w) - 1
	var maxz := int(l) - 1
	for f in faces:
		var c := Vector3.ZERO
		for p in f[0]:
			c += p
		c /= float((f[0] as Array).size())
		var k := Vector3i(clampi(floori(c.x), 0, maxx), clampi(floori(c.y - 0.001), 0, 63), clampi(floori(c.z), 0, maxz))
		if not buckets.has(k):
			buckets[k] = []
		(buckets[k] as Array).append(f)
	_cache[key] = buckets
	return buckets


static func _emit_piece(ctx: Dictionary, code: int, shape: int) -> void:
	var part := BlocFormes.part_of(code)
	var geo := _geo(shape, BlocFormes.size_of(code), BlocFormes.rot_of(code))
	var list: Array = geo.get(part, [])
	if list.is_empty():
		return
	var origin: Vector3 = (ctx.base as Vector3) - Vector3(part.x, part.y, part.z)
	var m: BlocMesher = ctx.m
	for f in list:
		var wp := []
		for p in f[0]:
			wp.append((p as Vector3) + origin)
		m.face(wp, f[1], int(ctx.layer), ctx.col, bool(ctx.glass))


## Toute la pièce, dans son repère (coin en (0, 0, 0), sans rotation).
static func _build_piece(out: Array, shape: int, d: float) -> void:
	var r := d / 2.0
	var n := clampi(int(d * 3.0), 12, 48)
	var lat := clampi(int(d * 1.2), 4, 14)
	match shape:
		S.P_DOME:
			var o := []
			var i2 := []
			for i in lat + 1:
				var t := PI * 0.5 * i / lat
				o.append(Vector2(r * cos(t), r * sin(t)))
				i2.append(Vector2((r - 0.2) * cos(t), (r - 0.2) * sin(t)))
			_rev(out, o, r, r, n)
			_rev(out, i2, r, r, n, true)
			_ring(out, r, 0.0, r, r - 0.2, r, n, false)
		S.P_ONION:
			var pr := [Vector2(0.85, 0), Vector2(1.0, 0.3), Vector2(1.04, 0.6), Vector2(0.92, 0.95), Vector2(0.66, 1.28),
				Vector2(0.36, 1.58), Vector2(0.14, 1.84), Vector2(0.05, 2.0), Vector2(0.04, 2.3), Vector2(0, 2.55)]
			var o2 := []
			for p in pr:
				o2.append(Vector2(p.x * r, p.y * r))
			_rev(out, o2, r, r, n)
			_disc(out, r, 0.0, r, 0.85 * r, n, false)
		S.P_CONE:
			var h := minf(r * 1.5, 62.0)
			_rev(out, [Vector2(r + 0.3, 0), Vector2(0, h)], r, r, n)
			_disc(out, r, 0.0, r, r + 0.3, n, false)
		S.P_SPIRE:
			var h2 := minf(d * 2.0, 62.0)
			_rev(out, [Vector2(r, 0), Vector2(0, h2)], r, r, maxi(8, n / 2))
			_disc(out, r, 0.0, r, r, maxi(8, n / 2), false)
		S.P_TOWER:
			var th := 0.35
			_rev(out, [Vector2(r, 0), Vector2(r, 1)], r, r, n)
			_rev(out, [Vector2(r - th, 0), Vector2(r - th, 1)], r, r, n, true)
			_ring(out, r, 1.0, r, r - th, r, n, true)
			_ring(out, r, 0.0, r, r - th, r, n, false)
		S.P_CYL:
			_rev(out, [Vector2(r, 0), Vector2(r, 1)], r, r, n)
			_disc(out, r, 1.0, r, r, n, true)
			_disc(out, r, 0.0, r, r, n, false)
		S.P_PYRAMID:
			var top := Vector3(r, r, r)
			var c := [Vector3(0, 0, 0), Vector3(d, 0, 0), Vector3(d, 0, d), Vector3(0, 0, d)]
			for i in 4:
				var a: Vector3 = c[i]
				var b: Vector3 = c[(i + 1) % 4]
				var nn := (b - a).cross(top - a).normalized()
				if nn.y < 0:
					nn = -nn
				# Découpé en bandes pour que chaque case ait sa part.
				_tri_split(out, a, b, top, nn, maxi(1, int(d)))
			out.append([[c[0], c[1], c[2], c[3]], Vector3.DOWN])
		S.P_VAULT:
			_arch_slice(out, d, "berceau")
		S.P_ARCH:
			_arch_slice(out, d, "plein")
		S.P_GOTHIC:
			_arch_slice(out, d, "brise")
		S.P_HALFDOME:
			var o3 := []
			var i3 := []
			for i in lat + 1:
				var t := PI * 0.5 * i / lat
				o3.append(Vector2(r * cos(t), r * sin(t)))
				i3.append(Vector2((r - 0.2) * cos(t), (r - 0.2) * sin(t)))
			_rev(out, o3, r, 0.0, n / 2, false, 0.0, PI)
			_rev(out, i3, r, 0.0, n / 2, true, 0.0, PI)
			_ring(out, r, 0.0, 0.0, r - 0.2, r, n / 2, false, 0.0, PI)
			# Tranche de l'arc, côté ouvert (vers −Z).
			for i in lat:
				var ta := PI * 0.5 * i / lat
				var tb := PI * 0.5 * (i + 1) / lat
				for s in [-1.0, 1.0]:
					out.append([[Vector3(r + s * r * cos(ta), r * sin(ta), 0), Vector3(r + s * r * cos(tb), r * sin(tb), 0),
						Vector3(r + s * (r - 0.2) * cos(tb), (r - 0.2) * sin(tb), 0), Vector3(r + s * (r - 0.2) * cos(ta), (r - 0.2) * sin(ta), 0)], Vector3.FORWARD])


## Triangle découpé en n bandes parallèles à sa base (pour la répartition par case).
static func _tri_split(out: Array, a: Vector3, b: Vector3, top: Vector3, nn: Vector3, n: int) -> void:
	for i in n:
		var t0 := float(i) / n
		var t1 := float(i + 1) / n
		var a0 := a.lerp(top, t0)
		var b0 := b.lerp(top, t0)
		var a1 := a.lerp(top, t1)
		var b1 := b.lerp(top, t1)
		# Bande découpée aussi en largeur.
		var m := maxi(1, n - i)
		for j in m:
			var u0 := float(j) / m
			var u1 := float(j + 1) / m
			var p0 := a0.lerp(b0, u0)
			var p1 := a0.lerp(b0, u1)
			var q0 := a1.lerp(b1, u0)
			var q1 := a1.lerp(b1, u1)
			if i == n - 1:
				out.append([[p0, p1, top], nn])
			else:
				out.append([[p0, p1, q1, q0], nn])


static func _rev(out: Array, prof: Array, cx: float, cz: float, n: int, flip := false, a0 := 0.0, a1 := TAU) -> void:
	for i in n:
		var aa := a0 + (a1 - a0) * i / n
		var ab := a0 + (a1 - a0) * (i + 1) / n
		var am := (aa + ab) / 2.0
		for j in prof.size() - 1:
			var p0: Vector2 = prof[j]
			var p1: Vector2 = prof[j + 1]
			var dd := p1 - p0
			var l := dd.length()
			if l < 1e-6:
				continue
			var nn := Vector3(cos(am) * dd.y / l, -dd.x / l, sin(am) * dd.y / l)
			if flip:
				nn = -nn
			var pts := []
			for q in [[p0, aa], [p0, ab], [p1, ab], [p1, aa]]:
				var pp: Vector2 = q[0]
				var a: float = q[1]
				var v := Vector3(cx + cos(a) * pp.x, pp.y, cz + sin(a) * pp.x)
				if pts.is_empty() or not (pts[-1] as Vector3).is_equal_approx(v):
					pts.append(v)
			if pts.size() == 4 and (pts[0] as Vector3).is_equal_approx(pts[3]):
				pts.pop_back()
			if pts.size() >= 3:
				out.append([pts, nn])


static func _disc(out: Array, cx: float, y: float, cz: float, r: float, n: int, up: bool) -> void:
	var c := Vector3(cx, y, cz)
	for i in n:
		var aa := TAU * i / n
		var ab := TAU * (i + 1) / n
		out.append([[c, Vector3(cx + cos(aa) * r, y, cz + sin(aa) * r), Vector3(cx + cos(ab) * r, y, cz + sin(ab) * r)], Vector3.UP if up else Vector3.DOWN])


## Couronne horizontale entre les rayons r0 et r1.
static func _ring(out: Array, cx: float, y: float, cz: float, r0: float, r1: float, n: int, up: bool, a0 := 0.0, a1 := TAU) -> void:
	for i in n:
		var aa := a0 + (a1 - a0) * i / n
		var ab := a0 + (a1 - a0) * (i + 1) / n
		out.append([[Vector3(cx + cos(aa) * r0, y, cz + sin(aa) * r0), Vector3(cx + cos(ab) * r0, y, cz + sin(ab) * r0),
			Vector3(cx + cos(ab) * r1, y, cz + sin(ab) * r1), Vector3(cx + cos(aa) * r1, y, cz + sin(aa) * r1)], Vector3.UP if up else Vector3.DOWN])


## Tranche d'arc ou de voûte, de largeur d (le long de x), épaisseur 1 m (z de 0 à 1).
## kind : "berceau" (coque de 25 cm), "plein" (arc en plein cintre plein jusqu'au
## dessus), "brise" (arc gothique en ogive).
static func _arch_slice(out: Array, d: float, kind: String) -> void:
	var r := d / 2.0
	var n := clampi(int(d * 3.0), 10, 48)
	# Intrados : points (x, y) de x = 0 à x = d.
	var pts: Array = []
	if kind == "brise":
		var half := n / 2
		for i in half + 1:
			var phi := PI - (PI / 3.0) * i / half
			pts.append(Vector2(d + d * cos(phi), d * sin(phi)))
		for i in range(half - 1, -1, -1):
			var p: Vector2 = pts[i]
			pts.append(Vector2(d - p.x, p.y))
	else:
		for i in n + 1:
			var t := PI - PI * i / n
			pts.append(Vector2(r + r * cos(t), r * sin(t)))
	if kind == "berceau":
		var th := 0.25
		var outer: Array = []
		for i in n + 1:
			var t := PI - PI * i / n
			outer.append(Vector2(r + (r + th) * cos(t), (r + th) * sin(t)))
		for i in n:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var oa: Vector2 = outer[i]
			var ob: Vector2 = outer[i + 1]
			var no := Vector3((oa.x + ob.x) / 2.0 - r, (oa.y + ob.y) / 2.0, 0).normalized()
			out.append([[Vector3(oa.x, oa.y, 0), Vector3(ob.x, ob.y, 0), Vector3(ob.x, ob.y, 1), Vector3(oa.x, oa.y, 1)], no])
			out.append([[Vector3(a.x, a.y, 0), Vector3(b.x, b.y, 0), Vector3(b.x, b.y, 1), Vector3(a.x, a.y, 1)], -no])
			out.append([[Vector3(a.x, a.y, 0), Vector3(b.x, b.y, 0), Vector3(ob.x, ob.y, 0), Vector3(oa.x, oa.y, 0)], Vector3.FORWARD])
			out.append([[Vector3(a.x, a.y, 1), Vector3(b.x, b.y, 1), Vector3(ob.x, ob.y, 1), Vector3(oa.x, oa.y, 1)], Vector3.BACK])
		for e in [[pts[0], outer[0]], [pts[n], outer[n]]]:
			var p0: Vector2 = e[0]
			var p1: Vector2 = e[1]
			out.append([[Vector3(p0.x, 0, 0), Vector3(p1.x, 0, 0), Vector3(p1.x, 0, 1), Vector3(p0.x, 0, 1)], Vector3.DOWN])
		return
	var peak := 0.0
	for p in pts:
		peak = maxf(peak, (p as Vector2).y)
	var top := ceilf(peak + 0.4)
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		for z in [0.0, 1.0]:
			out.append([[Vector3(a.x, a.y, z), Vector3(b.x, b.y, z), Vector3(b.x, top, z), Vector3(a.x, top, z)], Vector3.FORWARD if z == 0.0 else Vector3.BACK])
		var nn := Vector3(b.y - a.y, -(b.x - a.x), 0).normalized()
		out.append([[Vector3(a.x, a.y, 0), Vector3(b.x, b.y, 0), Vector3(b.x, b.y, 1), Vector3(a.x, a.y, 1)], nn])
		out.append([[Vector3(a.x, top, 0), Vector3(b.x, top, 0), Vector3(b.x, top, 1), Vector3(a.x, top, 1)], Vector3.UP])
	out.append([[Vector3(0, 0, 0), Vector3(0, 0, 1), Vector3(0, top, 1), Vector3(0, top, 0)], Vector3.LEFT])
	out.append([[Vector3(d, 0, 0), Vector3(d, 0, 1), Vector3(d, top, 1), Vector3(d, top, 0)], Vector3.RIGHT])
