class_name FermeModeles
extends RefCounted
## Modèles de la démo « ferme low-poly », construits avec LpKit.
## Chaque fonction ajoute ses faces au kit, dans le repère `k.xf` courant
## (on pose donc un objet en réglant `k.xf` avant l'appel).

# Palette : peu de couleurs, chacune déclinée par face (LpKit.vary).
const CHAUME := Color("b8964f")
const CHAUME_VIEUX := Color("85693d")
const CHAUME_FAITAGE := Color("8b7440")
const MOUSSE := Color("6f7b3a")
const ENDUIT := Color("dccdaa")
const BOIS_SOMBRE := Color("4a3324")
const BOIS := Color("7b5a3c")
const BOIS_GRIS := Color("8a8172")
const BOIS_CLAIR := Color("b08a5c")
const BOIS_COUPE := Color("d8b886")
const PIERRE := Color("a39b8b")
const PIERRE_OCRE := Color("b09a76")
const MORTIER := Color("6e675b")
const TUILE := Color("b0573a")
const TUILE_SOMBRE := Color("7f3f2c")
const FER := Color("3a3a3c")
const VERRE := Color("2c3a44")
const VOLET := Color("5f7f6e")
const PAILLE := Color("d9bb6b")


static func _rot(y_deg: float, pos: Vector3) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, deg_to_rad(y_deg)), pos)


# --- Murs de pierre ---------------------------------------------------------

## Mur de pierres sèches le long de l'axe X local, de x0 à x1, face avant vers +Z.
## `skip` : liste de Vector2(xa, xb) laissés vides (portes).
static func mur_pierres(k: LpKit, x0: float, x1: float, y0: float, y1: float, z: float, ep: float, skip: Array = []) -> void:
	# Fond de mortier sombre : les joints entre pierres paraissent profonds.
	var saved := k.jitter
	k.jitter = 0.03
	var y := y0
	var row := 0
	while y < y1 - 0.05:
		var rh := minf(k.rng.randf_range(0.22, 0.34), y1 - y)
		var x := x0 - (0.0 if row % 2 == 0 else 0.25)
		while x < x1:
			var w := k.rng.randf_range(0.32, 0.72)
			var xa := maxf(x, x0)
			var xb := minf(x + w, x1)
			var blocked := false
			for s in skip:
				if xb > s.x and xa < s.y:
					blocked = true
			if xb - xa > 0.08 and not blocked:
				var col := PIERRE if k.rng.randf() < 0.75 else PIERRE_OCRE
				var out := k.rng.randf_range(0.0, 0.05)
				k.stone(Vector3((xa + xb) * 0.5, y + rh * 0.5, z - ep * 0.5 + out * 0.5), Vector3(xb - xa - 0.035, rh - 0.035, ep + out), col)
			x += w
		y += rh
		row += 1
	k.jitter = saved
	k.box(Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, z - ep * 0.5 - 0.03), Vector3(x1 - x0 - 0.02, y1 - y0 - 0.02, ep - 0.06), MORTIER, 0.0, false)


# --- Fenêtres, portes ---------------------------------------------------------

## Fenêtre à petits carreaux posée sur un mur de normale +Z (repère courant).
static func fenetre(k: LpKit, cx: float, y0: float, w: float, h: float, z: float, volets := true, jardiniere := false) -> void:
	var f := 0.09
	# Vitre en retrait (couche « verre » : elle s'allume le soir).
	var saved := k.layer
	k.layer = "verre"
	k.box(Vector3(cx, y0 + h * 0.5, z + 0.005), Vector3(w, h, 0.02), VERRE, 0.0, false)
	k.layer = saved
	var fr := BOIS_SOMBRE
	k.box(Vector3(cx, y0 - f * 0.5, z + 0.07), Vector3(w + f * 2.6, f * 1.2, 0.18), BOIS_CLAIR.darkened(0.2))
	k.box(Vector3(cx, y0 + h + f * 0.5, z + 0.05), Vector3(w + f * 2, f, 0.1), fr)
	k.box(Vector3(cx - w * 0.5 - f * 0.5, y0 + h * 0.5, z + 0.05), Vector3(f, h, 0.1), fr)
	k.box(Vector3(cx + w * 0.5 + f * 0.5, y0 + h * 0.5, z + 0.05), Vector3(f, h, 0.1), fr)
	# Croisillons.
	k.box(Vector3(cx, y0 + h * 0.5, z + 0.03), Vector3(0.045, h, 0.04), fr)
	for i in range(1, 3):
		k.box(Vector3(cx, y0 + h * i / 3.0, z + 0.03), Vector3(w, 0.04, 0.04), fr)
	if volets:
		for side in [-1.0, 1.0]:
			var vx: float = cx + side * (w * 0.5 + f + w * 0.27)
			var ang := k.rng.randf_range(-8.0, 8.0)
			var sk := k.xf
			k.xf = sk * _rot(ang, Vector3(vx, y0 + h * 0.5, z + 0.06))
			var vc := k.vary(VOLET, 0.08)
			for p in 3:
				k.box(Vector3(-w * 0.18 + p * w * 0.18, 0, 0), Vector3(w * 0.17, h + 0.06, 0.04), k.vary(vc, 0.04))
			k.beam(Vector3(-w * 0.22, -h * 0.35, 0.03), Vector3(w * 0.22, h * 0.35, 0.03), 0.07, 0.025, vc.darkened(0.15), Vector3.BACK)
			k.box(Vector3(0, h * 0.4, 0.035), Vector3(w * 0.5, 0.06, 0.02), vc.darkened(0.12))
			k.box(Vector3(0, -h * 0.4, 0.035), Vector3(w * 0.5, 0.06, 0.02), vc.darkened(0.12))
			k.xf = sk
	if jardiniere:
		k.box(Vector3(cx, y0 - 0.2, z + 0.24), Vector3(w + 0.1, 0.2, 0.22), BOIS)
		for i in 7:
			var fx := cx - w * 0.5 + (i + 0.5) * w / 7.0
			var fc := [Color("c8323a"), Color("e05a7a"), Color("f0f0e8"), Color("c8323a")][k.rng.randi() % 4] as Color
			k.blob(Vector3(fx, y0 - 0.05, z + 0.26), Vector3(0.1, 0.09, 0.1), Color("3f6b2a"), Color("5f8f3a"), 0.3, 0)
			k.blob(Vector3(fx + k.rng.randf_range(-0.05, 0.05), y0 + 0.03, z + 0.3), Vector3(0.05, 0.04, 0.05), fc.darkened(0.2), fc, 0.3, 0)


## Porte de planches (repère : bas au centre en (cx, y0), face vers +Z).
static func porte(k: LpKit, cx: float, y0: float, w: float, h: float, z: float) -> void:
	var n := 5
	var pw := w / n
	for i in n:
		k.box(Vector3(cx - w * 0.5 + pw * (i + 0.5), y0 + h * 0.5, z + 0.03), Vector3(pw - 0.012, h, 0.06), k.vary(BOIS, 0.12))
	for yy in [0.25, 0.75]:
		k.box(Vector3(cx, y0 + h * yy, z + 0.075), Vector3(w * 0.92, 0.07, 0.025), FER)
	k.tube(Vector3(cx + w * 0.32, y0 + h * 0.48, z + 0.07), Vector3(cx + w * 0.32, y0 + h * 0.48, z + 0.14), 0.035, 0.035, 6, FER)
	k.box(Vector3(cx, y0 + h + 0.08, z + 0.07), Vector3(w + 0.3, 0.18, 0.18), BOIS_SOMBRE)
	k.stone(Vector3(cx, y0 - 0.08, z + 0.35), Vector3(w + 0.4, 0.18, 0.7), PIERRE)


## Lanterne murale (la flamme est dans la couche « flamme »).
static func lanterne(k: LpKit, p: Vector3) -> void:
	k.beam(p + Vector3(0, 0.25, -0.25), p + Vector3(0, 0.25, 0.02), 0.04, 0.04, FER)
	k.box(p + Vector3(0, 0.0, 0), Vector3(0.2, 0.04, 0.2), FER)
	k.box(p + Vector3(0, 0.3, 0), Vector3(0.24, 0.05, 0.24), FER)
	k.tube(p + Vector3(0, 0.32, 0), p + Vector3(0, 0.42, 0), 0.1, 0.0, 4, FER, false)
	for c in [Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(1, 0, 1), Vector3(-1, 0, 1)]:
		k.box(p + c * 0.09 + Vector3(0, 0.15, 0), Vector3(0.025, 0.28, 0.025), FER)
	var saved := k.layer
	k.layer = "flamme"
	k.box(p + Vector3(0, 0.15, 0), Vector3(0.15, 0.24, 0.15), Color("ffd28a"), 0.0, false)
	k.layer = saved


# --- Toit de chaume -----------------------------------------------------------------

## Toit de chaume épais, à deux pans, faîtage le long de X.
## Le repère : murs de x = ±L/2 et z = ±D/2, égout à la hauteur ye.
static func toit_chaume(k: LpKit, L: float, D: float, ye: float, pente_deg: float, debord := 0.75, debord_pignon := 0.55) -> float:
	var a := deg_to_rad(pente_deg)
	var rise := D * 0.5 * tan(a)
	var yr := ye + rise
	var u0 := -L * 0.5 - debord_pignon
	var u1 := L * 0.5 + debord_pignon
	var courses := 10
	var t0 := 0.22
	for side in [1.0, -1.0]:
		var s: float = side
		var n := Vector3(0, cos(a), s * sin(a))
		var down := Vector3(0, -sin(a), s * cos(a))
		var eave := Vector3(0, ye, s * D * 0.5) + down * debord
		var ridge := Vector3(0, yr, 0)
		var span := ridge - eave
		# Couche de fond (sous-face sombre + rive épaisse aux pignons).
		var e0 := Vector3(u0, 0, 0) + eave
		var e1 := Vector3(u1, 0, 0) + eave
		var r0 := Vector3(u0, 0, 0) + ridge
		var r1 := Vector3(u1, 0, 0) + ridge
		k.quad(e0, e1, r1, r0, CHAUME_VIEUX.darkened(0.45), -n)
		k.quad(e0 + n * t0, e1 + n * t0, r1 + n * t0, r0 + n * t0, CHAUME_VIEUX, n)
		k.quad(e0, e1, e1 + n * t0, e0 + n * t0, CHAUME_VIEUX.darkened(0.1), down)
		k.quad(e0, r0, r0 + n * t0, e0 + n * t0, CHAUME_VIEUX.darkened(0.05), Vector3.LEFT)
		k.quad(e1, r1, r1 + n * t0, e1 + n * t0, CHAUME_VIEUX.darkened(0.05), Vector3.RIGHT)
		# Rangs de bottes qui se chevauchent, du bas vers le haut. Le bord bas
		# de chaque rang ondule (points partagés entre segments) et le dessus
		# est bombé : on lit des couches de paille épaisses, pas des tuiles.
		for c in courses:
			var v0 := float(c) / courses * 0.94
			var v1 := minf(v0 + 1.75 / courses, 1.0)
			var lower := 1.0 - float(c) / courses
			var us: Array[float] = []
			var dvs: Array[float] = []
			var los: Array[float] = []
			var u := u0
			while u < u1 - 0.2:
				us.append(u)
				dvs.append(k.rng.randf_range(-0.01, 0.022))
				los.append(t0 + (0.3 if c == 0 else k.rng.randf_range(0.11, 0.17)))
				u += k.rng.randf_range(0.55, 1.0)
			us.append(u1)
			dvs.append(k.rng.randf_range(-0.01, 0.022))
			los.append(t0 + (0.3 if c == 0 else 0.14))
			var hi := t0 + 0.02
			var vm := (v0 + v1) * 0.5
			for i in us.size() - 1:
				var col := CHAUME.lerp(CHAUME_VIEUX, lower * 0.5 + k.rng.randf() * 0.2)
				if c < 3 and k.rng.randf() < 0.25:
					col = col.lerp(MOUSSE, k.rng.randf_range(0.2, 0.5))
				col = k.vary(col, 0.05)
				var pa := eave + span * (v0 - dvs[i]) + Vector3(us[i], 0, 0)
				var pb := eave + span * (v0 - dvs[i + 1]) + Vector3(us[i + 1], 0, 0)
				var pc := eave + span * v1 + Vector3(us[i + 1], 0, 0) + n * hi
				var pd := eave + span * v1 + Vector3(us[i], 0, 0) + n * hi
				var la := pa + n * los[i]
				var lb := pb + n * los[i + 1]
				var ma := eave + span * vm + Vector3(us[i], 0, 0) + n * ((los[i] + hi) * 0.5 + 0.05)
				var mb := eave + span * vm + Vector3(us[i + 1], 0, 0) + n * ((los[i + 1] + hi) * 0.5 + 0.05)
				# Dessus bombé (deux pans), puis la tranche (le « nez » des bottes).
				k.quad(la, lb, mb, ma, col.darkened(0.04), n)
				k.quad(ma, mb, pc, pd, col.lightened(0.04), n)
				k.quad(pa + n * t0, pb + n * t0, lb, la, col.darkened(0.28), down)
				if i == 0:
					k.quad(pa + n * t0, la, ma, pd, col.darkened(0.15), Vector3.LEFT)
				if i == us.size() - 2:
					k.quad(pb + n * t0, lb, mb, pc, col.darkened(0.15), Vector3.RIGHT)
	# Faîtage : une « selle » de paille plus sombre posée à cheval sur le haut,
	# bord inférieur festonné en pointes, tenue par des lisses et des
	# brochettes croisées ; rives arrondies aux pignons.
	var hb := t0 + 0.3
	for side in [1.0, -1.0]:
		var s: float = side
		var n := Vector3(0, cos(a), s * sin(a))
		var down := Vector3(0, -sin(a), s * cos(a))
		var ridge := Vector3(0, yr, 0)
		var eave := Vector3(0, ye, s * D * 0.5) + down * debord
		for uu in [u0, u1]:
			k.tube(eave + n * (t0 + 0.1) + Vector3(uu, 0, 0), ridge + n * (t0 + 0.1) + Vector3(uu, 0, 0), 0.2, 0.2, 6, CHAUME_VIEUX, false)
		var step := 0.55
		var u := u0 - 0.05
		while u < u1 + 0.04:
			var ub := minf(u + step, u1 + 0.05)
			var um := (u + ub) * 0.5
			var col := k.vary(CHAUME_FAITAGE, 0.06)
			var ta := ridge + n * hb + Vector3(u, 0, 0)
			var tb := ridge + n * hb + Vector3(ub, 0, 0)
			var la := ridge + down * 0.95 + n * hb + Vector3(u, 0, 0)
			var lb := ridge + down * 0.95 + n * hb + Vector3(ub, 0, 0)
			var pt := ridge + down * 1.3 + n * hb + Vector3(um, 0, 0)
			k.quad(ta, tb, lb, la, col, n)
			k.tri(la, lb, pt, col.darkened(0.04), n)
			var base := n * (t0 + 0.12) - n * hb
			k.quad(la, pt, pt + base, la + base, col.darkened(0.3), down)
			k.quad(pt, lb, lb + base, pt + base, col.darkened(0.3), down)
			# Brochettes croisées entre les deux lisses.
			var b0 := ridge + down * 0.3 + n * (hb + 0.02)
			var b1 := ridge + down * 0.8 + n * (hb + 0.02)
			k.beam(b0 + Vector3(u, 0, 0), b1 + Vector3(ub, 0, 0), 0.035, 0.03, BOIS_CLAIR, n)
			k.beam(b0 + Vector3(ub, 0, 0), b1 + Vector3(u, 0, 0), 0.035, 0.03, BOIS_CLAIR, n)
			u = ub
		for d: float in [0.3, 0.8]:
			var p := ridge + down * d + n * (hb + 0.04)
			k.tube(p + Vector3(u0 - 0.05, 0, 0), p + Vector3(u1 + 0.05, 0, 0), 0.035, 0.035, 5, BOIS)
		# Bouts de la selle aux pignons.
		for uu in [u0 - 0.05, u1 + 0.05]:
			k.quad(ridge + Vector3(uu, 0, 0) + n * (t0 + 0.1), ridge + down * 0.95 + Vector3(uu, 0, 0) + n * (t0 + 0.1),
				ridge + down * 0.95 + Vector3(uu, 0, 0) + n * hb, ridge + Vector3(uu, 0, 0) + n * hb, CHAUME_FAITAGE.darkened(0.15), Vector3(uu, 0, 0))
	# Boudin du sommet.
	var cap_c := Vector3(0, yr + cos(a) * hb - 0.04, 0)
	k.tube(cap_c + Vector3(u0 - 0.1, 0, 0), cap_c + Vector3(u1 + 0.1, 0, 0), sin(a) * hb + 0.1, sin(a) * hb + 0.1, 8, CHAUME_FAITAGE.darkened(0.05))
	return yr


# --- Toit de tuiles ---------------------------------------------------------------

static func toit_tuiles(k: LpKit, L: float, D: float, ye: float, pente_deg: float, debord := 0.45) -> float:
	var a := deg_to_rad(pente_deg)
	var rise := D * 0.5 * tan(a)
	var yr := ye + rise
	var u0 := -L * 0.5 - 0.35
	var u1 := L * 0.5 + 0.35
	for side in [1.0, -1.0]:
		var s: float = side
		var n := Vector3(0, cos(a), s * sin(a))
		var down := Vector3(0, -sin(a), s * cos(a))
		var eave := Vector3(0, ye, s * D * 0.5) + down * debord
		var ridge := Vector3(0, yr, 0)
		var span := ridge - eave
		var slope_len := span.length()
		# Voligeage (dessous) et chevrons apparents.
		k.quad(eave + Vector3(u0, 0, 0), eave + Vector3(u1, 0, 0), ridge + Vector3(u1, 0, 0), ridge + Vector3(u0, 0, 0), BOIS_SOMBRE, -n)
		k.quad(eave + Vector3(u0, 0, 0) + n * 0.04, eave + Vector3(u1, 0, 0) + n * 0.04, ridge + Vector3(u1, 0, 0) + n * 0.04, ridge + Vector3(u0, 0, 0) + n * 0.04, TUILE_SOMBRE.darkened(0.3), n)
		var row_step := 0.3
		var rows := int(slope_len / row_step)
		var tile_w := 0.26
		var tilt := Basis(Vector3.RIGHT, s * a)
		for r in rows:
			var v := (r * row_step + 0.18) / slope_len
			var u := u0 + (0.0 if r % 2 == 0 else tile_w * 0.5)
			var mossy := r < 3
			while u < u1 - tile_w * 0.4:
				var col := TUILE.lerp(TUILE_SOMBRE, k.rng.randf() * 0.6)
				if mossy and k.rng.randf() < 0.25:
					col = col.lerp(MOUSSE, 0.5)
				var p := eave + span * v + Vector3(u + tile_w * 0.5, 0, 0) + n * (0.07 + k.rng.randf_range(0, 0.015))
				var sk := k.xf
				var wob := Basis(Vector3.UP, k.rng.randf_range(-0.05, 0.05))
				k.xf = sk * Transform3D(tilt * wob * Basis(Vector3.RIGHT, s * 0.08), p)
				k.box(Vector3.ZERO, Vector3(tile_w - 0.02, 0.045, 0.4), col, 0.0)
				k.xf = sk
				u += tile_w
		# Rive (planche de bord) aux pignons.
		for uu in [u0, u1]:
			k.beam(eave + Vector3(uu, 0, 0) + n * 0.05, ridge + Vector3(uu, 0, 0) + n * 0.05, 0.06, 0.22, BOIS_GRIS.darkened(0.2), n)
	# Faîtières rondes.
	var u := u0
	while u < u1:
		k.tube(Vector3(u, yr + 0.12, 0), Vector3(minf(u + 0.42, u1), yr + 0.12, 0), 0.16, 0.14, 6, k.vary(TUILE_SOMBRE, 0.1))
		u += 0.4
	return yr


# --- Bâtiments -----------------------------------------------------------------------

## Longère à colombages, soubassement de pierre et toit de chaume.
## Repère : centre au sol, façade principale vers +Z, longueur 15 m sur X.
static func maison(k: LpKit) -> Dictionary:
	var L := 15.0
	var D := 7.0
	var ys := 0.9
	var ye := 3.6
	var door_x := -0.75
	var door_w := 1.1
	# Soubassement de pierre (descend sous le sol pour épouser le relief).
	mur_pierres(k, -L * 0.5, L * 0.5, -0.4, ys, D * 0.5 + 0.06, 0.6, [Vector2(door_x - door_w * 0.5 - 0.05, door_x + door_w * 0.5 + 0.05)])
	mur_pierres(k, -L * 0.5, L * 0.5, -0.4, ys, -D * 0.5 + 0.54, 0.6)
	var sk := k.xf
	k.xf = sk * _rot(90, Vector3.ZERO)
	mur_pierres(k, -D * 0.5 + 0.55, D * 0.5 - 0.55, -0.4, ys, L * 0.5 + 0.06, 0.6)
	mur_pierres(k, -D * 0.5 + 0.55, D * 0.5 - 0.55, -0.4, ys, -L * 0.5 + 0.54, 0.6)
	k.xf = sk
	# Enduit : un panneau par travée, chacun d'une teinte un peu différente.
	var posts: Array[float] = []
	var x := -L * 0.5
	while x <= L * 0.5 + 0.01:
		posts.append(x)
		x += 1.5
	var fenetres_av := {0: true, 2: true, 6: true, 8: true}
	var fenetres_ar := {1: true, 4: true, 7: true}
	for face in [1.0, -1.0]:
		var f: float = face
		var sk2 := k.xf
		k.xf = sk * Transform3D(Basis(Vector3.UP, 0.0 if f > 0 else PI), Vector3.ZERO)
		var zf := D * 0.5
		for i in posts.size() - 1:
			var xa: float = posts[i]
			var xb: float = posts[i + 1]
			k.quad(Vector3(xa, ys, zf), Vector3(xb, ys, zf), Vector3(xb, ye, zf), Vector3(xa, ye, zf), k.vary(ENDUIT, 0.05), Vector3.BACK)
		# Colombages : sablière basse, haute, poteaux, lisse et décharges.
		var tw := 0.2
		var tz := zf + 0.05
		if f > 0:
			k.box(Vector3((-L * 0.5 - 1.5) * 0.5, ys + 0.1, tz), Vector3(L * 0.5 - 1.5 + 0.05, tw, 0.14), BOIS_SOMBRE)
			k.box(Vector3(L * 0.25, ys + 0.1, tz), Vector3(L * 0.5 + 0.05, tw, 0.14), BOIS_SOMBRE)
		else:
			k.box(Vector3(0, ys + 0.1, tz), Vector3(L + 0.1, tw, 0.14), BOIS_SOMBRE)
		k.box(Vector3(0, ye - 0.1, tz), Vector3(L + 0.1, tw, 0.14), BOIS_SOMBRE)
		var wins: Dictionary = fenetres_av if f > 0 else fenetres_ar
		for i in posts.size():
			k.box(Vector3(posts[i], (ys + ye) * 0.5, tz), Vector3(tw, ye - ys, 0.14), k.vary(BOIS_SOMBRE, 0.1))
		for i in posts.size() - 1:
			var xa: float = posts[i] + tw * 0.5
			var xb: float = posts[i + 1] - tw * 0.5
			var cx := (xa + xb) * 0.5
			var is_door := f > 0 and door_x > xa - 0.5 and door_x < xb + 0.5
			if is_door:
				porte(k, cx, ys - 0.75, door_w, 2.85, zf)
				k.box(Vector3(cx, 3.35, tz), Vector3(xb - xa, 0.16, 0.12), BOIS_SOMBRE)
				continue
			if wins.has(i):
				fenetre(k, cx, 1.65, 0.85, 1.15, zf + 0.02, true, f > 0 and (i == 2 or i == 6))
				k.box(Vector3(cx, 1.5, tz), Vector3(xb - xa, 0.15, 0.12), BOIS_SOMBRE)
				continue
			k.box(Vector3(cx, 2.25, tz), Vector3(xb - xa, 0.16, 0.12), BOIS_SOMBRE)
			# Croix de Saint-André ou décharge simple, selon la travée.
			if i % 3 == 1:
				k.beam(Vector3(xa, ys + 0.15, tz), Vector3(xb, 2.2, tz), 0.15, 0.12, BOIS_SOMBRE, Vector3.BACK)
				k.beam(Vector3(xb, ys + 0.15, tz), Vector3(xa, 2.2, tz), 0.15, 0.12, BOIS_SOMBRE, Vector3.BACK)
			elif i % 2 == 0:
				k.beam(Vector3(xa, 2.3, tz), Vector3(xb, ye - 0.15, tz), 0.15, 0.12, BOIS_SOMBRE, Vector3.BACK)
			else:
				k.beam(Vector3(xb, ys + 0.15, tz), Vector3(xa, 2.2, tz), 0.15, 0.12, BOIS_SOMBRE, Vector3.BACK)
		k.xf = sk2
	# Pignons (murs + triangle sous le toit).
	var pente := 52.0
	var rise := D * 0.5 * tan(deg_to_rad(pente))
	for face in [1.0, -1.0]:
		var f: float = face
		var sk3 := k.xf
		k.xf = sk * Transform3D(Basis(Vector3.UP, PI * 0.5 if f > 0 else -PI * 0.5), Vector3.ZERO)
		var zf := L * 0.5
		var hz := D * 0.5
		k.quad(Vector3(-hz, ys, zf), Vector3(hz, ys, zf), Vector3(hz, ye, zf), Vector3(-hz, ye, zf), k.vary(ENDUIT, 0.05), Vector3.BACK)
		k.tri(Vector3(-hz, ye, zf), Vector3(hz, ye, zf), Vector3(0, ye + rise, zf), k.vary(ENDUIT, 0.05), Vector3.BACK)
		var tz := zf + 0.05
		k.box(Vector3(0, ys + 0.1, tz), Vector3(D + 0.1, 0.2, 0.14), BOIS_SOMBRE)
		k.box(Vector3(0, ye - 0.05, tz), Vector3(D + 0.3, 0.22, 0.16), BOIS_SOMBRE)
		for px in [-hz, -1.2, 1.2, hz]:
			k.box(Vector3(px, (ys + ye) * 0.5, tz), Vector3(0.2, ye - ys, 0.14), BOIS_SOMBRE)
		k.beam(Vector3(-hz, ys + 0.2, tz), Vector3(-1.3, ye - 0.2, tz), 0.15, 0.12, BOIS_SOMBRE, Vector3.BACK)
		k.beam(Vector3(hz, ys + 0.2, tz), Vector3(1.3, ye - 0.2, tz), 0.15, 0.12, BOIS_SOMBRE, Vector3.BACK)
		# Poinçon, entrait retroussé et arbalétriers du pignon.
		k.box(Vector3(0, ye + rise * 0.5, tz), Vector3(0.2, rise, 0.14), BOIS_SOMBRE)
		k.box(Vector3(0, ye + rise * 0.45, tz), Vector3(D * 0.55, 0.18, 0.14), BOIS_SOMBRE)
		k.beam(Vector3(-hz + 0.2, ye + 0.1, tz), Vector3(-0.1, ye + rise - 0.2, tz), 0.18, 0.13, BOIS_SOMBRE, Vector3.BACK)
		k.beam(Vector3(hz - 0.2, ye + 0.1, tz), Vector3(0.1, ye + rise - 0.2, tz), 0.18, 0.13, BOIS_SOMBRE, Vector3.BACK)
		if f > 0:
			fenetre(k, 0, 0.0 + 1.6, 0.8, 1.1, zf + 0.02, true, false)
			fenetre(k, -0.85, ye + rise * 0.12, 0.45, 0.6, zf + 0.02, false)
			fenetre(k, 0.85, ye + rise * 0.12, 0.45, 0.6, zf + 0.02, false)
		else:
			fenetre(k, 0.0, ye + rise * 0.55, 0.5, 0.55, zf + 0.02, false)
		k.xf = sk3
	var yr := toit_chaume(k, L, D, ye, pente)
	# Cheminée de pierre traversant le chaume.
	var cx := 4.6
	var cz := -0.4
	var y := ye + 1.0
	while y < yr + 1.4:
		var rh := k.rng.randf_range(0.22, 0.3)
		for side in 4:
			var sk4 := k.xf
			k.xf = sk * _rot(90.0 * side, Vector3(cx, 0, cz))
			var xx := -0.45
			while xx < 0.45:
				var w := minf(k.rng.randf_range(0.25, 0.5), 0.45 - xx)
				k.stone(Vector3(xx + w * 0.5, y + rh * 0.5, 0.4), Vector3(w - 0.03, rh - 0.03, 0.18), PIERRE)
				xx += w
			k.xf = sk4
		y += rh
	k.box(Vector3(cx, y, cz), Vector3(1.05, 0.12, 1.05), PIERRE.darkened(0.15))
	k.box(Vector3(cx, y - 0.3, cz), Vector3(0.75, 0.6, 0.75), Color("1c1a18"), 0.0, false)
	# Lanterne, banc et appentis bois.
	lanterne(k, Vector3(door_x + 1.0, 2.55, D * 0.5 + 0.3))
	k.xf = sk * _rot(0, Vector3(3.2, 0, D * 0.5 + 0.55))
	k.box(Vector3(0, 0.45, 0), Vector3(1.8, 0.07, 0.36), BOIS_CLAIR)
	for lx in [-0.75, 0.75]:
		k.box(Vector3(lx, 0.2, 0), Vector3(0.08, 0.45, 0.3), BOIS)
	k.xf = sk
	return {"faitage": yr, "cheminee": Vector3(cx, y + 0.1, cz), "lanterne": Vector3(door_x + 1.0, 2.55, D * 0.5 + 0.3)}


## Grange en planches sur soubassement de pierre, toit de tuiles.
## Repère : centre au sol, grande porte vers +Z, longueur sur X.
static func grange(k: LpKit) -> Dictionary:
	var L := 14.0
	var D := 10.0
	var ys := 0.55
	var ye := 4.4
	mur_pierres(k, -L * 0.5, L * 0.5, -0.4, ys, D * 0.5 + 0.06, 0.5, [Vector2(-2.2, 2.2)])
	mur_pierres(k, -L * 0.5, L * 0.5, -0.4, ys, -D * 0.5 + 0.44, 0.5)
	var sk := k.xf
	k.xf = sk * _rot(90, Vector3.ZERO)
	mur_pierres(k, -D * 0.5 + 0.45, D * 0.5 - 0.45, -0.4, ys, L * 0.5 + 0.06, 0.5)
	mur_pierres(k, -D * 0.5 + 0.45, D * 0.5 - 0.45, -0.4, ys, -L * 0.5 + 0.44, 0.5)
	k.xf = sk
	var pente := 38.0
	var rise := D * 0.5 * tan(deg_to_rad(pente))
	# Bardage : planches verticales, chacune sa teinte (bois plus ou moins grisé).
	for wall in 4:
		var long := wall < 2
		var half := (L if long else D) * 0.5
		var zf := (D if long else L) * 0.5
		var ang := [0.0, 180.0, 90.0, -90.0][wall] as float
		var sk2 := k.xf
		k.xf = sk * _rot(ang, Vector3.ZERO)
		# Fond sombre (l'intérieur de la grange vu entre les planches).
		if wall != 0:
			k.box(Vector3(0, (ys + ye) * 0.5 + 0.5, zf - 0.08), Vector3(half * 2 - 0.1, ye - ys + 1.0, 0.04), Color("2a211a"), 0.0, false)
		var x := -half
		while x < half - 0.01:
			var pw := minf(k.rng.randf_range(0.22, 0.32), half - x)
			var cx := x + pw * 0.5
			var top := ye
			if not long:
				top = ye + rise * (1.0 - absf(cx) / half) - 0.05
			var door := wall == 0 and absf(cx) < 2.2
			if not door:
				var col := BOIS.lerp(BOIS_GRIS, k.rng.randf_range(0.2, 0.9))
				k.box(Vector3(cx, (ys + top) * 0.5, zf), Vector3(pw - 0.015, top - ys, 0.05), k.vary(col, 0.1))
			elif wall == 0:
				# Linteau au-dessus de la grande porte.
				k.box(Vector3(cx, (3.9 + top) * 0.5, zf), Vector3(pw - 0.015, top - 3.9, 0.05), k.vary(BOIS_GRIS, 0.1))
			x += pw
		# Couvre-joints et lisses.
		k.box(Vector3(0, ys + 0.1, zf + 0.05), Vector3(half * 2, 0.14, 0.06), BOIS_SOMBRE)
		if long:
			k.box(Vector3(0, ye - 0.1, zf + 0.05), Vector3(half * 2 + 0.1, 0.18, 0.08), BOIS_SOMBRE)
		k.xf = sk2
	# Grande porte : un battant ouvert, l'autre fermé ; foin à l'intérieur.
	var zf0 := D * 0.5
	k.box(Vector3(0, 3.95, zf0 + 0.06), Vector3(4.6, 0.2, 0.14), BOIS_SOMBRE)
	k.box(Vector3(-2.2, 2.2, zf0 + 0.06), Vector3(0.2, 3.5, 0.14), BOIS_SOMBRE)
	k.box(Vector3(2.2, 2.2, zf0 + 0.06), Vector3(0.2, 3.5, 0.14), BOIS_SOMBRE)
	for leaf in [-1.0, 1.0]:
		var lf: float = leaf
		var sk3 := k.xf
		var hinge := Vector3(lf * 2.1, 0, zf0 + 0.1)
		var opened := 105.0 if lf > 0 else 4.0
		k.xf = sk * _rot(-lf * opened, hinge)
		var n := 8
		for i in n:
			var px := -lf * (i + 0.5) * 2.0 / n
			k.box(Vector3(px, 2.05, 0.03), Vector3(2.0 / n - 0.015, 3.3, 0.06), k.vary(BOIS.lerp(BOIS_GRIS, 0.4), 0.12))
		k.box(Vector3(-lf * 1.0, 3.3, 0.08), Vector3(1.9, 0.12, 0.05), BOIS_SOMBRE)
		k.box(Vector3(-lf * 1.0, 0.8, 0.08), Vector3(1.9, 0.12, 0.05), BOIS_SOMBRE)
		k.beam(Vector3(-lf * 0.1, 0.85, 0.09), Vector3(-lf * 1.9, 3.25, 0.09), 0.12, 0.05, BOIS_SOMBRE, Vector3.BACK)
		k.xf = sk3
	k.box(Vector3(0, 0.02, 0), Vector3(L - 1.0, 0.1, D - 1.0), Color("6e5a40"))
	for i in 14:
		k.blob(Vector3(k.rng.randf_range(-5.5, 5.5), 0.4, k.rng.randf_range(-3.8, 0.5)), Vector3(1.4, 1.0, 1.2), PAILLE.darkened(0.35), PAILLE, 0.25, 1)
	var yr := toit_tuiles(k, L, D, ye, pente)
	# Lucarne à foin au pignon est, avec sa poulie.
	k.xf = sk * _rot(90, Vector3.ZERO)
	k.box(Vector3(0, ye + 1.1, L * 0.5 + 0.03), Vector3(1.3, 1.4, 0.06), Color("1e1813"), 0.0, false)
	k.box(Vector3(0, ye + 1.85, L * 0.5 + 0.08), Vector3(1.5, 0.12, 0.12), BOIS_SOMBRE)
	k.beam(Vector3(0, yr - 0.4, L * 0.5 - 0.2), Vector3(0, yr - 0.4, L * 0.5 + 1.0), 0.18, 0.18, BOIS_SOMBRE)
	k.tube(Vector3(0, yr - 0.5, L * 0.5 + 0.9), Vector3(0, ye + 0.8, L * 0.5 + 0.9), 0.015, 0.015, 4, Color("8a7a5a"), false)
	k.xf = sk
	lanterne(k, Vector3(2.75, 3.3, D * 0.5 + 0.3))
	return {"faitage": yr, "lanterne": Vector3(2.75, 3.3, D * 0.5 + 0.3)}


# --- Petits objets -------------------------------------------------------------------

static func puits(k: LpKit) -> void:
	var rows := 4
	for r in rows:
		var n := 11
		var y := r * 0.22
		for i in n:
			var ang := TAU * (i + 0.5 * (r % 2)) / n
			var sk := k.xf
			k.xf = sk * Transform3D(Basis(Vector3.UP, PI * 0.5 - ang), Vector3(cos(ang), 0, sin(ang)) * 0.82)
			k.stone(Vector3(0, y + 0.11, 0), Vector3(0.44, 0.2, 0.3), PIERRE)
			k.xf = sk
	k.lathe(Vector3(0, 0.6, 0), [Vector2(0.62, 0.0), Vector2(0.62, 0.01)], 10, Color("1b2a2c"), false, true)
	for px in [-0.95, 0.95]:
		k.box(Vector3(px, 1.35, 0), Vector3(0.16, 2.0, 0.16), BOIS_SOMBRE)
	k.tube(Vector3(-1.05, 1.6, 0), Vector3(1.05, 1.6, 0), 0.09, 0.09, 7, BOIS)
	k.beam(Vector3(1.05, 1.6, 0), Vector3(1.12, 1.6, 0.0), 0.04, 0.04, FER)
	k.beam(Vector3(1.12, 1.6, 0), Vector3(1.12, 1.3, 0.1), 0.04, 0.04, FER)
	k.tube(Vector3(0.1, 1.55, 0), Vector3(0.1, 1.05, 0), 0.012, 0.012, 4, Color("8a7a5a"), false)
	k.lathe(Vector3(0.1, 0.78, 0), [Vector2(0.12, 0), Vector2(0.15, 0.26)], 8, BOIS, true, false)
	k.lathe(Vector3(0.1, 0.78, 0), [Vector2(0.155, 0.2), Vector2(0.16, 0.25)], 8, FER, false, false)
	# Petit toit de tuiles.
	var sk2 := k.xf
	k.xf = sk2 * _rot(0, Vector3(0, 2.3, 0))
	toit_tuiles(k, 2.0, 1.4, 0.0, 35, 0.15)
	k.xf = sk2


static func tonneau(k: LpKit) -> void:
	var prof := [Vector2(0.27, 0), Vector2(0.31, 0.2), Vector2(0.33, 0.42), Vector2(0.31, 0.64), Vector2(0.27, 0.84)]
	var cols: Array[Color] = []
	for i in 12:
		cols.append(k.vary(BOIS_CLAIR.lerp(BOIS, 0.5), 0.14))
	k.lathe(Vector3.ZERO, prof, 12, BOIS, true, true, func(i: int, _r: int) -> Color: return cols[i])
	for hy in [0.08, 0.72]:
		var r := 0.29 if hy < 0.5 else 0.295
		k.lathe(Vector3.ZERO, [Vector2(r + 0.012, hy), Vector2(r + 0.025, hy + 0.06)], 12, FER, false, false)
	k.lathe(Vector3(0, 0.84, 0), [Vector2(0.255, -0.04), Vector2(0.255, -0.03)], 12, BOIS.darkened(0.15), false, true)


static func caisse(k: LpKit, s := 0.6) -> void:
	k.box(Vector3(0, s * 0.5, 0), Vector3(s, s, s) * 0.96, BOIS_CLAIR.darkened(0.1))
	for e in [Vector3(1, 0, 1), Vector3(-1, 0, 1), Vector3(1, 0, -1), Vector3(-1, 0, -1)]:
		k.box(Vector3(e.x * s * 0.47, s * 0.5, e.z * s * 0.47), Vector3(0.07, s, 0.07), BOIS)
	for y in [0.06, s - 0.06]:
		k.box(Vector3(0, y, s * 0.49), Vector3(s, 0.08, 0.03), BOIS)
		k.box(Vector3(0, y, -s * 0.49), Vector3(s, 0.08, 0.03), BOIS)
		k.box(Vector3(s * 0.49, y, 0), Vector3(0.03, 0.08, s), BOIS)
		k.box(Vector3(-s * 0.49, y, 0), Vector3(0.03, 0.08, s), BOIS)


static func roue(k: LpKit, centre: Vector3, r: float) -> void:
	var n := 14
	var pts: Array[Vector3] = []
	for i in n:
		var ang := TAU * i / n
		pts.append(centre + Vector3(0, sin(ang) * r, cos(ang) * r))
	for i in n:
		k.beam(pts[i], pts[(i + 1) % n], 0.09, 0.1, k.vary(BOIS, 0.1), Vector3.RIGHT)
	for i in 7:
		var ang := TAU * i / 7.0
		k.beam(centre, centre + Vector3(0, sin(ang), cos(ang)) * (r - 0.04), 0.05, 0.05, BOIS)
	k.tube(centre + Vector3(-0.12, 0, 0), centre + Vector3(0.12, 0, 0), 0.11, 0.11, 8, BOIS_SOMBRE)
	k.tube(centre + Vector3(-0.06, 0, 0), centre + Vector3(0.06, 0, 0), r + 0.015, r + 0.015, n, FER, false)


static func charrette(k: LpKit) -> void:
	var rr := 0.62
	for sx in [-0.78, 0.78]:
		roue(k, Vector3(sx, rr, 0), rr)
	k.tube(Vector3(-0.85, rr, 0), Vector3(0.85, rr, 0), 0.05, 0.05, 6, BOIS_SOMBRE)
	var y := rr + 0.22
	for i in 6:
		k.box(Vector3(-0.6 + i * 0.24, y, 0), Vector3(0.23, 0.05, 2.4), k.vary(BOIS_CLAIR, 0.12))
	for sx in [-0.7, 0.7]:
		k.box(Vector3(sx, y + 0.25, 0), Vector3(0.05, 0.4, 2.4), k.vary(BOIS, 0.1))
		for z in [-1.1, 0.0, 1.1]:
			k.box(Vector3(sx, y + 0.2, z), Vector3(0.08, 0.5, 0.08), BOIS_SOMBRE)
	k.box(Vector3(0, y + 0.25, -1.18), Vector3(1.45, 0.4, 0.05), BOIS)
	# Brancards posés au sol.
	for sx in [-0.45, 0.45]:
		k.beam(Vector3(sx, y - 0.05, 1.0), Vector3(sx * 0.8, 0.12, 3.3), 0.09, 0.09, BOIS)
	# Chargement : sacs et foin.
	for i in 3:
		k.blob(Vector3(-0.3 + i * 0.3, y + 0.25, -0.6 + k.rng.randf_range(-0.1, 0.1)), Vector3(0.2, 0.22, 0.3), Color("a8987a"), Color("d6c9a8"), 0.12, 1)
	k.blob(Vector3(0.1, y + 0.3, 0.5), Vector3(0.65, 0.4, 0.75), PAILLE.darkened(0.3), PAILLE, 0.3, 1)


static func tas_bois(k: LpKit, longueur := 3.0, rangs := 5) -> void:
	for r in rangs:
		var n := int(longueur / 0.24) - (r % 2)
		for i in n:
			var x := -longueur * 0.5 + 0.12 + i * 0.24 + (0.12 if r % 2 else 0.0)
			var y := 0.11 + r * 0.2
			var rad := k.rng.randf_range(0.08, 0.12)
			var zj := k.rng.randf_range(-0.06, 0.06)
			k.tube(Vector3(x, y, -0.4 + zj), Vector3(x, y, 0.4 + zj), rad, rad, 6, Color("5d4632"), true, k.vary(BOIS_COUPE, 0.12))
	k.box(Vector3(0, rangs * 0.2 + 0.25, 0), Vector3(longueur + 0.4, 0.05, 1.1), BOIS_GRIS.darkened(0.1))
	for px in [-longueur * 0.5 - 0.1, longueur * 0.5 + 0.1]:
		for pz in [-0.45, 0.45]:
			k.box(Vector3(px, (rangs * 0.2 + 0.25) * 0.5, pz), Vector3(0.1, rangs * 0.2 + 0.25, 0.1), BOIS_GRIS)
	# Billot et hache.
	k.tube(Vector3(longueur * 0.5 + 0.8, 0, 0.6), Vector3(longueur * 0.5 + 0.8, 0.5, 0.6), 0.28, 0.26, 8, Color("5d4632"), true, BOIS_COUPE)
	k.beam(Vector3(longueur * 0.5 + 0.75, 0.5, 0.6), Vector3(longueur * 0.5 + 0.55, 1.05, 0.7), 0.04, 0.04, BOIS_CLAIR)
	k.box(Vector3(longueur * 0.5 + 0.77, 0.52, 0.6), Vector3(0.05, 0.08, 0.18), FER)


static func botte_ronde(k: LpKit) -> void:
	var sk := k.xf
	k.xf = sk * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.72, -0.6))
	k.lathe(Vector3.ZERO, [Vector2(0.6, 0), Vector2(0.72, 0.08), Vector2(0.74, 0.6), Vector2(0.72, 1.12), Vector2(0.6, 1.2)], 12, PAILLE.darkened(0.08))
	k.xf = sk


static func botte_carree(k: LpKit) -> void:
	k.box(Vector3(0, 0.23, 0), Vector3(0.95, 0.45, 0.5), PAILLE, 0.03)
	for x in [-0.25, 0.25]:
		k.box(Vector3(x, 0.23, 0), Vector3(0.02, 0.47, 0.52), Color("6b4f2a"), 0.0, false)


static func poule(k: LpKit, plumage: Color, coq := false) -> void:
	var s := 1.25 if coq else 1.0
	k.blob(Vector3(0, 0.3, 0) * s, Vector3(0.17, 0.15, 0.23) * s, plumage.darkened(0.25), plumage, 0.12, 1)
	k.blob(Vector3(0, 0.48, 0.17) * s, Vector3(0.08, 0.09, 0.08) * s, plumage.darkened(0.1), plumage, 0.1, 0)
	var queue := Color("2a3a2a") if coq else plumage.darkened(0.15)
	k.blob(Vector3(0, 0.42, -0.2) * s, Vector3(0.06, 0.14, 0.1) * s * (1.6 if coq else 1.0), queue, queue.lightened(0.2), 0.2, 0)
	k.box(Vector3(0, 0.58, 0.17) * s, Vector3(0.03, 0.07, 0.1) * s, Color("c42a2a"))
	k.box(Vector3(0, 0.39, 0.22) * s, Vector3(0.025, 0.06, 0.03) * s, Color("c42a2a"))
	k.tube(Vector3(0, 0.47, 0.24) * s, Vector3(0, 0.46, 0.31) * s, 0.025 * s, 0.0, 4, Color("e0a838"), false)
	for lx in [-0.06, 0.06]:
		k.beam(Vector3(lx, 0.17, 0.02) * s, Vector3(lx, 0.0, 0.04) * s, 0.025, 0.025, Color("d89a3a"))


static func chene(k: LpKit, s := 1.0) -> void:
	var tronc := Color("4e3b2b")
	var h := 3.4 * s
	k.tube(Vector3(0, -0.3, 0), Vector3(0.1, h, 0.05) , 0.45 * s, 0.28 * s, 7, tronc)
	for i in 4:
		var ang := TAU * i / 4.0 + k.rng.randf() * 0.6
		k.tube(Vector3(0, 0.05, 0), Vector3(cos(ang), -0.15, sin(ang)) * 0.9 * s, 0.22 * s, 0.05 * s, 5, tronc)
	var tips: Array[Vector3] = []
	for i in 4:
		var ang := TAU * i / 4.0 + k.rng.randf() * 0.8
		var tip := Vector3(cos(ang) * 1.9 * s, h + k.rng.randf_range(0.8, 1.8) * s, sin(ang) * 1.9 * s)
		k.tube(Vector3(0.1, h - 0.6 * s, 0.05), tip, 0.2 * s, 0.07 * s, 5, tronc)
		tips.append(tip)
	var bas := Color("2c4a1f")
	var haut := Color("86a845")
	k.blob(Vector3(0, h + 2.0 * s, 0), Vector3(2.8, 2.2, 2.8) * s, bas, haut, 0.16, 1)
	for t in tips:
		k.blob(t + Vector3(0, 0.6 * s, 0), Vector3(1.9, 1.5, 1.9) * s * k.rng.randf_range(0.85, 1.15), bas, haut, 0.18, 1)
	k.blob(Vector3(0.3, h + 3.4 * s, -0.2), Vector3(1.8, 1.3, 1.8) * s, bas.lerp(haut, 0.3), haut.lightened(0.08), 0.18, 1)


static func fruitier(k: LpKit, s := 1.0) -> void:
	var h := 1.6 * s
	k.tube(Vector3.ZERO, Vector3(0.05, h, 0), 0.14 * s, 0.1 * s, 6, Color("5a4535"))
	for i in 3:
		var ang := TAU * i / 3.0 + k.rng.randf()
		k.tube(Vector3(0.05, h - 0.2, 0), Vector3(cos(ang) * 0.8 * s, h + 0.7 * s, sin(ang) * 0.8 * s), 0.08 * s, 0.03 * s, 5, Color("5a4535"))
	var c := Vector3(0, h + 1.1 * s, 0)
	k.blob(c, Vector3(1.5, 1.15, 1.5) * s, Color("3d6a28"), Color("9cc455"), 0.2, 1)
	for i in 9:
		var d := Vector3(k.rng.randf_range(-1, 1), k.rng.randf_range(-0.6, 0.5), k.rng.randf_range(-1, 1)).normalized()
		k.blob(c + d * Vector3(1.45, 1.1, 1.45) * s, Vector3(0.09, 0.09, 0.09), Color("a8241e"), Color("e04a2c"), 0.1, 0)


static func sapin(k: LpKit, s := 1.0) -> void:
	k.tube(Vector3.ZERO, Vector3(0, 1.2 * s, 0), 0.22 * s, 0.18 * s, 6, Color("4a3a2a"))
	var y := 0.9 * s
	var r := 2.1 * s
	for tier in 4:
		var hh := 2.4 * s - tier * 0.25 * s
		k.lathe(Vector3(0, y, 0), [Vector2(r, 0), Vector2(r * 0.55, hh * 0.45), Vector2(0, hh)], 8, Color("2e4a2c"), true, false,
			Callable(), k.rng.randf() * TAU)
		y += hh * 0.5
		r *= 0.74


static func epouvantail(k: LpKit) -> void:
	k.beam(Vector3(0, -0.3, 0), Vector3(0, 2.1, 0), 0.08, 0.08, BOIS)
	k.beam(Vector3(-0.9, 1.55, 0), Vector3(0.9, 1.6, 0), 0.07, 0.07, BOIS)
	k.box(Vector3(0, 1.35, 0), Vector3(0.6, 0.65, 0.3), Color("7a3d36"), 0.08)
	k.box(Vector3(-0.55, 1.55, 0), Vector3(0.55, 0.2, 0.22), Color("7a3d36"), 0.1)
	k.box(Vector3(0.55, 1.6, 0), Vector3(0.55, 0.2, 0.22), Color("6b5a8a"), 0.1)
	k.box(Vector3(0, 0.85, 0), Vector3(0.5, 0.4, 0.28), Color("4a5a78"), 0.06)
	k.blob(Vector3(0, 1.9, 0), Vector3(0.2, 0.22, 0.2), Color("b8a070"), Color("d8c48e"), 0.1, 1)
	k.lathe(Vector3(0, 2.02, 0), [Vector2(0.42, 0), Vector2(0.4, 0.05), Vector2(0.2, 0.08), Vector2(0.17, 0.28), Vector2(0.0, 0.3)], 9, Color("5a4632"), true, false)
	for side in [-1.0, 1.0]:
		k.blob(Vector3(side * 0.95, 1.55, 0), Vector3(0.1, 0.12, 0.1), PAILLE.darkened(0.2), PAILLE, 0.4, 0)


## Nuage low-poly (grappe de sphères aplaties).
static func nuage(k: LpKit, s := 1.0) -> void:
	var n := k.rng.randi_range(4, 7)
	for i in n:
		var p := Vector3(k.rng.randf_range(-1.6, 1.6) * s * 6.0, k.rng.randf_range(0.0, 1.5) * s * 2.0, k.rng.randf_range(-1.0, 1.0) * s * 4.0)
		var r := k.rng.randf_range(4.0, 7.5) * s
		k.blob(p, Vector3(r * 1.3, r * 0.6, r), Color("c9cdd6"), Color("ffffff"), 0.12, 1)
