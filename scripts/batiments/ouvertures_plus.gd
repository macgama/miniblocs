class_name OuverturesPlus
extends RefCounted
## Ouvertures ajoutées aux murs fins (troisième version de l'atelier) :
## portes et fenêtres cintrées ou gothiques, œil-de-bœuf, porte d'entrée à
## imposte, porte double, porte de garage, porte de grange, baie coulissante,
## fenêtre d'atelier, bandeau, mur-rideau, meurtrière, claustra, et les
## accessoires côté rue (volets, balconnet, store).
##
## Repère du mur (comme PlanEditor._wbox) : u le long du mur (0 → 1), y en
## mètres, w à travers (négatif : côté a). Une ouverture « large » posée sur
## plusieurs morceaux alignés ne fait qu'une : les morceaux se rejoignent au
## sommet commun (PlanEditor._post_gap coupe le poteau).

const HALF := PlanEditor.HALF


static func _pt(k: Vector4i, u: float, y: float, w: float) -> Vector3:
	return Vector3(k.x + u, y, k.z + w) if k.w == 0 else Vector3(k.x + w, y, k.z + u)


## Polygone convexe en repère du mur ; n : normale (u, y, w).
static func _q(m: BlocMesher, k: Vector4i, pts: Array, n: Vector3, code: int) -> void:
	var wp := []
	for p in pts:
		var v: Vector3 = p
		wp.append(_pt(k, v.x, v.y, v.z))
	var wn := Vector3(n.x, n.y, n.z) if k.w == 0 else Vector3(n.z, n.y, n.x)
	var mat := BlocFormes.mat_of(code)
	m.face(wp, wn.normalized(), BlocMateriaux.layer(mat), BlocMateriaux.tint_color(BlocFormes.tint_of(code)), BlocMateriaux.is_glass(mat))


static func _bx(m: BlocMesher, k: Vector4i, u0: float, u1: float, y0: float, y1: float, w0: float, w1: float, code: int) -> void:
	PlanEditor._wbox(m, k, u0, u1, y0, y1, w0, w1, [code, code, code, code, code, code])


## Remplit [ua, ub] × [s, t] (toute l'épaisseur du mur) sauf le trou entre
## u = h0 et h1, de y = lo(u) à hi(u). Faces côté a (code a) et côté b (code b),
## tableau du trou dans le code rv.
static func fill_hole(m: BlocMesher, k: Vector4i, ua: float, ub: float, s: float, t: float, h0: float, h1: float,
		lo: Callable, hi: Callable, n: int, a: int, b: int, rv: int) -> void:
	for pair in [[ua, h0], [h1, ub]]:
		var u0: float = pair[0]
		var u1: float = pair[1]
		if u1 - u0 > 1e-4:
			PlanEditor._wbox(m, k, u0, u1, s, t, -HALF, HALF, [rv, rv, -1, -1, a, b])
	for i in n:
		var xa := h0 + (h1 - h0) * i / n
		var xb := h0 + (h1 - h0) * (i + 1) / n
		var la: float = lo.call(xa)
		var lb: float = lo.call(xb)
		var ha: float = hi.call(xa)
		var hb: float = hi.call(xb)
		for side in [[-HALF, a, -1.0], [HALF, b, 1.0]]:
			var w: float = side[0]
			var c: int = side[1]
			var nw := Vector3(0, 0, side[2])
			if la > s + 1e-4 or lb > s + 1e-4:
				_q(m, k, [Vector3(xa, s, w), Vector3(xb, s, w), Vector3(xb, lb, w), Vector3(xa, la, w)], nw, c)
			if ha < t - 1e-4 or hb < t - 1e-4:
				_q(m, k, [Vector3(xa, ha, w), Vector3(xb, hb, w), Vector3(xb, t, w), Vector3(xa, t, w)], nw, c)
		if la > s + 1e-4 or lb > s + 1e-4:
			_q(m, k, [Vector3(xa, la, -HALF), Vector3(xb, lb, -HALF), Vector3(xb, lb, HALF), Vector3(xa, la, HALF)], Vector3(-(lb - la), xb - xa, 0), rv)
		if ha < t - 1e-4 or hb < t - 1e-4:
			_q(m, k, [Vector3(xa, ha, -HALF), Vector3(xb, hb, -HALF), Vector3(xb, hb, HALF), Vector3(xa, ha, HALF)], Vector3(hb - ha, -(xb - xa), 0), rv)
	# Côtés du trou.
	var l0: float = lo.call(h0)
	var t0: float = hi.call(h0)
	var l1: float = lo.call(h1)
	var t1: float = hi.call(h1)
	if t0 - l0 > 1e-4 and h0 > ua + 1e-4:
		_q(m, k, [Vector3(h0, l0, -HALF), Vector3(h0, l0, HALF), Vector3(h0, t0, HALF), Vector3(h0, t0, -HALF)], Vector3(1, 0, 0), rv)
	if t1 - l1 > 1e-4 and h1 < ub - 1e-4:
		_q(m, k, [Vector3(h1, l1, -HALF), Vector3(h1, l1, HALF), Vector3(h1, t1, HALF), Vector3(h1, t1, -HALF)], Vector3(-1, 0, 0), rv)


## Vitre (ou panneau plein) mince sous une courbe : de y = lo(u) à hi(u), en w0 → w1.
static func pane(m: BlocMesher, k: Vector4i, h0: float, h1: float, lo: Callable, hi: Callable, n: int, w0: float, w1: float, code: int) -> void:
	for i in n:
		var xa := h0 + (h1 - h0) * i / n
		var xb := h0 + (h1 - h0) * (i + 1) / n
		var la: float = lo.call(xa)
		var lb: float = lo.call(xb)
		var ha: float = hi.call(xa)
		var hb: float = hi.call(xb)
		if ha - la + hb - lb < 1e-4:
			continue
		_q(m, k, [Vector3(xa, la, w0), Vector3(xb, lb, w0), Vector3(xb, hb, w0), Vector3(xa, ha, w0)], Vector3(0, 0, -1), code)
		_q(m, k, [Vector3(xa, la, w1), Vector3(xb, lb, w1), Vector3(xb, hb, w1), Vector3(xa, ha, w1)], Vector3(0, 0, 1), code)


## Dessine l'ouverture ; renvoie faux si le dessin ordinaire doit continuer
## (accessoires seulement : volets, balconnet, store).
static func emit(pe: PlanEditor, m: BlocMesher, k: Vector4i, w: Dictionary, o: Dictionary, s: float, t: float, by: float, p: Dictionary) -> bool:
	var a := int(w.a)
	var b := int(w.b)
	var fm := int(w.om)
	var large: bool = o.get("large", false)
	var jp := large and pe._wide_joined(p, k, -1)
	var jn := large and pe._wide_joined(p, k, 1)
	var ua := 0.0 if jp else HALF
	var ub := 1.0 if jn else 1.0 - HALF
	var out := pe.outside_sign(p, k)
	var glass := BlocFormes.encode(PlanEditor.VITRAIL_MAT if o.get("vitrail", false) else PlanEditor.GLASS_MAT)
	var opened := bool(w.op)
	var forme := String(o.get("forme", ""))
	var special := String(o.get("special", ""))
	_extras(m, k, o, s, t, ua, ub, out, fm, jp, jn)
	if forme != "":
		_shaped(m, k, o, forme, s, t, ua, ub, a, b, fm, glass, opened)
		return true
	match special:
		"entree":
			_entree(m, k, s, t, ua, ub, fm, glass, opened)
		"double", "grange":
			_double(m, k, s, t, ua, ub, fm, glass, opened, jp, jn, special == "grange", out)
		"garage":
			_garage(m, k, s, t, ua, ub, fm, opened, jp, jn, out)
		"coulissante":
			_sliding(m, k, s, t, ua, ub, fm, glass, jp, jn)
		"rideau", "bandeau", "atelier":
			_glazing(m, k, s, t, ua, ub, fm, glass, jp, jn, special)
		"grille":
			_grid_window(m, k, s, t, ua, ub, fm, glass)
		"fente":
			var mid := 0.5
			fill_hole(m, k, ua, ub, s, t, mid - 0.06, mid + 0.06, func(_u: float) -> float: return s, func(_u: float) -> float: return t, 1, a, b, a)
		"claustra":
			_claustra(m, k, s, t, ua, ub, a, b)
		_:
			return false
	return true


# --- Formes cintrées, brisées, rondes ------------------------------------------------------

static func _shaped(m: BlocMesher, k: Vector4i, o: Dictionary, forme: String, s: float, t: float, ua: float, ub: float, a: int, b: int, fm: int, glass: int, opened: bool) -> void:
	var mid := (ua + ub) / 2.0
	var wd := ub - ua
	var n := 10
	if forme == "oeil":
		var rr := minf(wd, t - s) / 2.0 - 0.02
		var cy := (s + t) / 2.0
		var lo := func(u: float) -> float: return cy - sqrt(maxf(rr * rr - (u - mid) * (u - mid), 0.0))
		var hi := func(u: float) -> float: return cy + sqrt(maxf(rr * rr - (u - mid) * (u - mid), 0.0))
		fill_hole(m, k, ua, ub, s, t, mid - rr, mid + rr, lo, hi, 12, a, b, fm)
		pane(m, k, mid - rr, mid + rr, lo, hi, 12, -0.008, 0.008, glass)
		_bx(m, k, mid - 0.02, mid + 0.02, cy - rr, cy + rr, -0.025, 0.025, fm)
		_bx(m, k, mid - rr, mid + rr, cy - 0.02, cy + 0.02, -0.025, 0.025, fm)
		return
	var spring := t - wd / 2.0
	var curve: Callable
	if forme == "brise":
		spring = t - wd * 0.866
		curve = func(u: float) -> float:
			var c := ub if u <= mid else ua
			return spring + sqrt(maxf(wd * wd - (u - c) * (u - c), 0.0))
	else:
		var rr2 := wd / 2.0
		curve = func(u: float) -> float: return spring + sqrt(maxf(rr2 * rr2 - (u - mid) * (u - mid), 0.0))
	# Écoinçons (le mur entre l'arc et le haut de l'ouverture) et l'intrados.
	fill_hole(m, k, ua, ub, s, t, ua, ub, func(_u: float) -> float: return s, curve, n, a, b, fm)
	if o.get("passage", false):
		return
	var jamb := 0.05
	var fd := 0.05
	var fr := fm
	_bx(m, k, ua, ua + jamb, s, spring, -fd, fd, fr)
	_bx(m, k, ub - jamb, ub, s, spring, -fd, fd, fr)
	var inner_lo := func(_u: float) -> float: return s + (0.0 if o.get("leaf", false) else jamb)
	var inner_hi := func(u: float) -> float: return maxf(float(curve.call(u)) - jamb, s + jamb)
	if o.get("window", false):
		_bx(m, k, ua + jamb, ub - jamb, s, s + jamb, -fd, fd, fr)
		_bx(m, k, ua - 0.02, ub + 0.02, s - 0.04, s, -HALF - 0.04, HALF + 0.04, fr)
		# Cadre le long de l'arc.
		pane(m, k, ua + jamb * 0.5, ub - jamb * 0.5, inner_hi, func(u: float) -> float: return curve.call(u), n, -fd, fd, fr)
		pane(m, k, ua + jamb, ub - jamb, inner_lo, inner_hi, n, -0.008, 0.008, glass)
		var top_mid: float = inner_hi.call(mid)
		_bx(m, k, mid - 0.02, mid + 0.02, s + jamb, top_mid, -0.025, 0.025, fr)
		_bx(m, k, ua + jamb, ub - jamb, spring - 0.02, spring + 0.02, -0.025, 0.025, fr)
		return
	# Porte cintrée : battant qui suit l'arc.
	var lu0 := ua + jamb
	var lu1 := ub - jamb
	if opened:
		_bx(m, k, lu0, lu0 + 0.045, s, spring + (t - spring) * 0.7, 0.03, 0.03 + (lu1 - lu0), fr)
		return
	pane(m, k, ua + jamb * 0.5, ub - jamb * 0.5, inner_hi, func(u: float) -> float: return curve.call(u), n, -fd, fd, fr)
	_bx(m, k, lu0, lu1, s, spring, -0.022, 0.022, fr)
	pane(m, k, lu0, lu1, func(_u: float) -> float: return spring, inner_hi, n, -0.022, 0.022, fr)
	for side in [-1.0, 1.0]:
		var w0 := 0.022 if side > 0 else -0.032
		var w1 := 0.032 if side > 0 else -0.022
		_bx(m, k, lu0 + 0.08, lu1 - 0.08, s + 0.15, s + 0.95, w0, w1, fr)
		_bx(m, k, lu0 + 0.08, lu1 - 0.08, s + 1.1, spring - 0.05, w0, w1, fr)
	_handle(m, k, lu1 - 0.1, s + 1.0)


static func _handle(m: BlocMesher, k: Vector4i, u: float, y: float) -> void:
	_bx(m, k, u, u + 0.05, y, y + 0.05, -0.07, 0.07, BlocFormes.encode(PlanEditor.BRASS_MAT))


# --- Portes -----------------------------------------------------------------------------------

static func _entree(m: BlocMesher, k: Vector4i, s: float, t: float, ua: float, ub: float, fm: int, glass: int, opened: bool) -> void:
	var jamb := 0.05
	var fd := 0.05
	var tr := t - 0.45
	_bx(m, k, ua, ua + jamb, s, t, -fd, fd, fm)
	_bx(m, k, ub - jamb, ub, s, t, -fd, fd, fm)
	_bx(m, k, ua + jamb, ub - jamb, t - jamb, t, -fd, fd, fm)
	_bx(m, k, ua + jamb, ub - jamb, tr, tr + 0.06, -fd, fd, fm)
	_bx(m, k, ua + jamb, ub - jamb, tr + 0.06, t - jamb, -0.008, 0.008, glass)
	# Petits bois en éventail dans l'imposte.
	for i in 3:
		var u := ua + jamb + (ub - ua - 2 * jamb) * (i + 1) / 4.0
		_bx(m, k, u - 0.012, u + 0.012, tr + 0.06, t - jamb, -0.02, 0.02, fm)
	var lu0 := ua + jamb
	var lu1 := ub - jamb
	if opened:
		_bx(m, k, lu0, lu0 + 0.05, s, tr, 0.03, 0.03 + (lu1 - lu0), fm)
		return
	_bx(m, k, lu0, lu1, s, tr, -0.025, 0.025, fm)
	for side in [-1.0, 1.0]:
		var w0 := 0.025 if side > 0 else -0.04
		var w1 := 0.04 if side > 0 else -0.025
		_bx(m, k, lu0 + 0.07, lu1 - 0.07, s + 0.12, s + 0.7, w0, w1, fm)
		_bx(m, k, lu0 + 0.07, lu1 - 0.07, s + 0.85, tr - 0.1, w0, w1, fm)
		_bx(m, k, lu0 + 0.05, lu1 - 0.05, s + 0.74, s + 0.8, w0, w1 + side * 0.01, fm)
	_handle(m, k, lu1 - 0.11, s + 1.0)


static func _double(m: BlocMesher, k: Vector4i, s: float, t: float, ua: float, ub: float, fm: int, glass: int, opened: bool, jp: bool, jn: bool, barn: bool, out: int) -> void:
	var jamb := 0.05
	var fd := 0.05
	if not jp:
		_bx(m, k, ua, ua + jamb, s, t, -fd, fd, fm)
	if not jn:
		_bx(m, k, ub - jamb, ub, s, t, -fd, fd, fm)
	_bx(m, k, ua, ub, t - jamb, t, -fd, fd, fm)
	var lu0 := ua + (0.003 if jp else jamb)
	var lu1 := ub - (0.003 if jn else jamb)
	var ly1 := t - jamb
	# Le gond est du côté qui ne touche pas l'autre battant.
	var hinge_low := not (jp and not jn)
	if opened:
		var inside := -out
		var w0 := 0.03 if inside > 0 else -0.03 - (lu1 - lu0)
		var w1 := 0.03 + (lu1 - lu0) if inside > 0 else -0.03
		if hinge_low:
			_bx(m, k, lu0, lu0 + 0.05, s, ly1, w0, w1, fm)
		else:
			_bx(m, k, lu1 - 0.05, lu1, s, ly1, w0, w1, fm)
		return
	_bx(m, k, lu0, lu1, s, ly1, -0.025, 0.025, fm)
	var dark := BlocFormes.encode(PlanEditor.IRON_MAT)
	if barn:
		# Planches, traverses et écharpe en Z sur la face extérieure.
		var wo := float(out) * 0.025
		var wf := float(out) * 0.045
		var w0b := minf(wo, wf)
		var w1b := maxf(wo, wf)
		for i in 4:
			var u := lu0 + (lu1 - lu0) * (i + 1) / 5.0
			_bx(m, k, u - 0.006, u + 0.006, s, ly1, minf(wo, float(out) * 0.03), maxf(wo, float(out) * 0.03), dark)
		_bx(m, k, lu0 + 0.03, lu1 - 0.03, s + 0.2, s + 0.32, w0b, w1b, fm)
		_bx(m, k, lu0 + 0.03, lu1 - 0.03, ly1 - 0.32, ly1 - 0.2, w0b, w1b, fm)
		var y0 := s + 0.32
		var y1 := ly1 - 0.32
		var x0 := lu0 + 0.05 if hinge_low else lu1 - 0.05
		var x1 := lu1 - 0.05 if hinge_low else lu0 + 0.05
		var wm := (w0b + w1b) / 2.0
		var d := 0.06
		_q(m, k, [Vector3(x0, y0 - d, wm + 0.01 * out), Vector3(x1, y1 - d, wm + 0.01 * out), Vector3(x1, y1 + d, wm + 0.01 * out), Vector3(x0, y0 + d, wm + 0.01 * out)], Vector3(0, 0, out), fm)
		return
	# Porte double vitrée en partie haute.
	_bx(m, k, lu0 + 0.1, lu1 - 0.1, s + 1.05, ly1 - 0.12, -0.03, 0.03, glass)
	for side in [-1.0, 1.0]:
		var w0 := 0.025 if side > 0 else -0.035
		var w1 := 0.035 if side > 0 else -0.025
		_bx(m, k, lu0 + 0.08, lu1 - 0.08, s + 0.15, s + 0.9, w0, w1, fm)
	_handle(m, k, (lu1 - 0.08) if hinge_low else (lu0 + 0.03), s + 1.0)


static func _garage(m: BlocMesher, k: Vector4i, s: float, t: float, ua: float, ub: float, fm: int, opened: bool, jp: bool, jn: bool, out: int) -> void:
	var jamb := 0.05
	if not jp:
		_bx(m, k, ua, ua + jamb, s, t, -0.06, 0.06, fm)
	if not jn:
		_bx(m, k, ub - jamb, ub, s, t, -0.06, 0.06, fm)
	_bx(m, k, ua, ub, t - jamb, t, -0.06, 0.06, fm)
	var lu0 := ua + (0.0 if jp else jamb)
	var lu1 := ub - (0.0 if jn else jamb)
	if opened:
		# Relevée sous le plafond, côté intérieur.
		var inside := float(-out)
		var w0 := minf(inside * 0.05, inside * 2.2)
		var w1 := maxf(inside * 0.05, inside * 2.2)
		_bx(m, k, lu0, lu1, t - 0.1, t - 0.05, w0, w1, fm)
		return
	_bx(m, k, lu0, lu1, s, t - jamb, -0.03, 0.03, fm)
	var nb := int((t - s) / 0.5)
	for j in nb:
		var y := s + 0.5 * (j + 1)
		if y >= t - jamb - 0.02:
			break
		_bx(m, k, lu0, lu1, y - 0.03, y, -0.045, 0.045, fm)
	_bx(m, k, lu0, lu1, s, s + 0.04, -0.05, 0.05, BlocFormes.encode(PlanEditor.IRON_MAT))


static func _sliding(m: BlocMesher, k: Vector4i, s: float, t: float, ua: float, ub: float, fm: int, glass: int, jp: bool, jn: bool) -> void:
	var f := 0.035
	_bx(m, k, ua, ub, s, s + f, -0.05, 0.05, fm)
	_bx(m, k, ua, ub, t - f, t, -0.05, 0.05, fm)
	if not jp:
		_bx(m, k, ua, ua + f, s, t, -0.05, 0.05, fm)
	if not jn:
		_bx(m, k, ub - f, ub, s, t, -0.05, 0.05, fm)
	# Un vantail par mètre, en quinconce dans l'épaisseur.
	var front := (k.x + k.z) % 2 == 0
	var w0 := -0.035 if front else 0.005
	var w1 := -0.005 if front else 0.035
	var u0 := ua + (0.0 if jp else f) - 0.04
	var u1 := ub - (0.0 if jn else f) + 0.04
	u0 = maxf(u0, ua)
	u1 = minf(u1, ub)
	_bx(m, k, u0, u0 + 0.05, s + f, t - f, w0, w1, fm)
	_bx(m, k, u1 - 0.05, u1, s + f, t - f, w0, w1, fm)
	_bx(m, k, u0 + 0.05, u1 - 0.05, s + f, s + f + 0.06, w0, w1, fm)
	_bx(m, k, u0 + 0.05, u1 - 0.05, t - f - 0.06, t - f, w0, w1, fm)
	var wm := (w0 + w1) / 2.0
	_bx(m, k, u0 + 0.05, u1 - 0.05, s + f + 0.06, t - f - 0.06, wm - 0.006, wm + 0.006, glass)


static func _glazing(m: BlocMesher, k: Vector4i, s: float, t: float, ua: float, ub: float, fm: int, glass: int, jp: bool, jn: bool, kind: String) -> void:
	var f := 0.035
	var fd := 0.05
	# Montants : au bout de l'ouverture (cadre) ou au sommet commun (meneau fin).
	if jp:
		_bx(m, k, ua, ua + 0.025, s, t, -fd, fd, fm)
	else:
		_bx(m, k, ua, ua + f, s, t, -fd, fd, fm)
	if jn:
		_bx(m, k, ub - 0.025, ub, s, t, -fd, fd, fm)
	else:
		_bx(m, k, ub - f, ub, s, t, -fd, fd, fm)
	_bx(m, k, ua, ub, t - f, t, -fd, fd, fm)
	_bx(m, k, ua, ub, s, s + f, -fd, fd, fm)
	if kind == "bandeau":
		_bx(m, k, ua - (0.0 if jp else 0.02), ub + (0.0 if jn else 0.02), s - 0.04, s, -HALF - 0.04, HALF + 0.04, fm)
	_bx(m, k, ua + 0.02, ub - 0.02, s + f, t - f, -0.008, 0.008, glass)
	var mid := (ua + ub) / 2.0
	match kind:
		"rideau":
			# Traverse à hauteur d'allège et meneau au milieu du mètre.
			_bx(m, k, ua, ub, s + 0.95, s + 1.0, -0.035, 0.035, fm)
			_bx(m, k, mid - 0.015, mid + 0.015, s, t, -0.035, 0.035, fm)
		"atelier":
			var cols := 3
			for i in cols:
				var u := ua + (ub - ua) * (i + 1) / float(cols + 1)
				_bx(m, k, u - 0.01, u + 0.01, s, t, -0.02, 0.02, fm)
			var rows := maxi(2, int((t - s) / 0.3))
			for j in rows:
				var y := s + (t - s) * (j + 1) / float(rows + 1)
				_bx(m, k, ua, ub, y - 0.01, y + 0.01, -0.02, 0.02, fm)
		"bandeau":
			_bx(m, k, mid - 0.012, mid + 0.012, s, t, -0.025, 0.025, fm)


static func _grid_window(m: BlocMesher, k: Vector4i, s: float, t: float, ua: float, ub: float, fm: int, glass: int) -> void:
	var jamb := 0.06
	var fd := 0.05
	_bx(m, k, ua, ua + jamb, s, t, -fd, fd, fm)
	_bx(m, k, ub - jamb, ub, s, t, -fd, fd, fm)
	_bx(m, k, ua + jamb, ub - jamb, t - jamb, t, -fd, fd, fm)
	_bx(m, k, ua + jamb, ub - jamb, s, s + jamb, -fd, fd, fm)
	_bx(m, k, ua - 0.02, ub + 0.02, s - 0.04, s, -HALF - 0.04, HALF + 0.04, fm)
	_bx(m, k, ua + jamb, ub - jamb, s + jamb, t - jamb, -0.008, 0.008, glass)
	var u0 := ua + jamb
	var u1 := ub - jamb
	for i in 2:
		var u := u0 + (u1 - u0) * (i + 1) / 3.0
		_bx(m, k, u - 0.015, u + 0.015, s + jamb, t - jamb, -0.022, 0.022, fm)
	for j in 3:
		var y := s + jamb + (t - s - 2 * jamb) * (j + 1) / 4.0
		_bx(m, k, u0, u1, y - 0.015, y + 0.015, -0.022, 0.022, fm)


static func _claustra(m: BlocMesher, k: Vector4i, s: float, t: float, ua: float, ub: float, a: int, b: int) -> void:
	var mats := [a, a, a, a, a, b]
	var cols := 4
	var bar := 0.07
	for i in cols + 1:
		var u := ua + (ub - ua) * i / float(cols)
		PlanEditor._wbox(m, k, clampf(u - bar / 2.0, ua, ub), clampf(u + bar / 2.0, ua, ub), s, t, -HALF, HALF, mats)
	var rows := int((t - s) / 0.2)
	for j in rows + 1:
		var y := s + (t - s) * j / float(rows)
		PlanEditor._wbox(m, k, ua, ub, clampf(y - bar / 2.0, s, t), clampf(y + bar / 2.0, s, t), -HALF * 0.6, HALF * 0.6, mats)


# --- Accessoires côté rue ----------------------------------------------------------------------

static func _extras(m: BlocMesher, k: Vector4i, o: Dictionary, s: float, t: float, ua: float, ub: float, out: int, fm: int, jp: bool, jn: bool) -> void:
	var sg := float(out)
	if o.get("volets", false):
		var wd := (ub - ua) / 2.0
		var shut := fm
		if BlocFormes.mat_of(fm) == PlanEditor.FRAME_MAT and BlocFormes.tint_of(fm) == 0:
			shut = BlocFormes.encode(PlanEditor.FRAME_MAT, 0, 0, 8)
		var w0 := minf(sg * (HALF + 0.005), sg * (HALF + 0.045))
		var w1 := maxf(sg * (HALF + 0.005), sg * (HALF + 0.045))
		for pair in [[ua - wd - 0.01, ua - 0.01], [ub + 0.01, ub + wd + 0.01]]:
			var u0: float = pair[0]
			var u1: float = pair[1]
			_bx(m, k, u0, u1, s, t, w0, w1, shut)
			# Lames persiennées.
			var nb := int((t - s) / 0.12)
			for j in range(1, nb):
				var y := s + j * (t - s) / nb
				var sa := sg * (HALF + 0.045)
				var sb := sg * (HALF + 0.06)
				_bx(m, k, u0 + 0.03, u1 - 0.03, y - 0.015, y + 0.015, minf(sa, sb), maxf(sa, sb), shut)
	if o.get("balconnet", false):
		var iron := BlocFormes.encode(PlanEditor.IRON_MAT)
		var stone := BlocFormes.encode(16)
		var wa := sg * (HALF + 0.01)
		var wb := sg * (HALF + 0.32)
		_bx(m, k, ua - 0.05, ub + 0.05, s - 0.06, s + 0.02, minf(sg * HALF, wb), maxf(sg * HALF, wb), stone)
		_bx(m, k, ua, ub, s + 0.95, s + 1.0, minf(wb, wb - sg * 0.04), maxf(wb, wb - sg * 0.04), iron)
		_bx(m, k, ua, ub, s + 0.06, s + 0.1, minf(wb, wb - sg * 0.04), maxf(wb, wb - sg * 0.04), iron)
		var n := int((ub - ua) / 0.1)
		for i in n + 1:
			var u := ua + (ub - ua) * i / float(n)
			_bx(m, k, u - 0.01, u + 0.01, s + 0.02, s + 0.95, minf(wb, wb - sg * 0.02), maxf(wb, wb - sg * 0.02), iron)
		for side in [ua, ub]:
			_bx(m, k, float(side) - 0.01, float(side) + 0.01, s + 0.95, s + 1.0, minf(wa, wb), maxf(wa, wb), iron)
			_bx(m, k, float(side) - 0.01, float(side) + 0.01, s + 0.06, s + 0.1, minf(wa, wb), maxf(wa, wb), iron)
	if o.get("store", false):
		var mi := BlocMateriaux.index_of("Toile rayée")
		var cloth := BlocFormes.encode(maxi(mi, 0))
		var y0 := t + 0.25
		var y1 := t - 0.2
		var w0 := sg * HALF
		var w1 := sg * (HALF + 0.95)
		var u0 := ua - (0.0 if jp else 0.05)
		var u1 := ub + (0.0 if jn else 0.05)
		var nn := Vector3(0, absf(w1 - w0), -(y1 - y0) * sg).normalized()
		_q(m, k, [Vector3(u0, y0, w0), Vector3(u1, y0, w0), Vector3(u1, y1, w1), Vector3(u0, y1, w1)], nn, cloth)
		_q(m, k, [Vector3(u0, y0, w0), Vector3(u1, y0, w0), Vector3(u1, y1, w1), Vector3(u0, y1, w1)], -nn, cloth)
		_q(m, k, [Vector3(u0, y1 - 0.18, w1), Vector3(u1, y1 - 0.18, w1), Vector3(u1, y1, w1), Vector3(u0, y1, w1)], Vector3(0, 0, sg), cloth)
		_q(m, k, [Vector3(u0, y1 - 0.18, w1), Vector3(u1, y1 - 0.18, w1), Vector3(u1, y1, w1), Vector3(u0, y1, w1)], Vector3(0, 0, -sg), cloth)
