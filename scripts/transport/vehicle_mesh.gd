class_name VehicleMesh
extends BlocMesh
## Formes en plus de BlocMesh pour les véhicules : volumes à 8 sommets (capots,
## nez, coques), cylindres couchés (roues, chaudières, fuselages), ellipsoïdes
## (ballons, dirigeables), ailes et voiles.
##
## Repère d'un véhicule : 1 unité = 1 m, le sol (ou la ligne de flottaison) est
## en y = 0, le véhicule est centré sur (0, 0) et son avant regarde vers −Z.

const TIRE := Color("26282b")
const RIM := Color("9aa0a6")
const GLASS := Color("2b3d4f")
const LIGHT := Color("fff3c4")
const REAR := Color("c0392b")
const SKIN := Color("e0ac7e")


## Normale d'un polygone (méthode de Newell), tournée à l'opposé de center.
static func _normal(pts: Array, center: Vector3) -> Vector3:
	var n := Vector3.ZERO
	var c := Vector3.ZERO
	for i in pts.size():
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[(i + 1) % pts.size()]
		n.x += (a.y - b.y) * (a.z + b.z)
		n.y += (a.z - b.z) * (a.x + b.x)
		n.z += (a.x - b.x) * (a.y + b.y)
		c += a
	c /= pts.size()
	if n.length_squared() < 1e-12:
		n = c - center
	n = n.normalized()
	if n.dot(c - center) < 0.0:
		n = -n
	return n


## Face plane à 3 ou 4 sommets, orientée vers l'extérieur d'un volume de centre center.
func face(pts: Array, center: Vector3, col: Color) -> void:
	var n := _normal(pts, center)
	if pts.size() == 3:
		tri(pts[0], pts[1], pts[2], n, col)
	else:
		quad(pts[0], pts[1], pts[2], pts[3], n, col)


## Volume convexe à 8 sommets : 4 en bas et 4 en haut, dans le même ordre.
func hull(b: Array, t: Array, col: Color) -> void:
	var c := Vector3.ZERO
	for p in b + t:
		c += p
	c /= 8.0
	var side := col.darkened(0.06)
	face([b[0], b[1], b[2], b[3]], c, side.darkened(0.1))
	face([t[0], t[1], t[2], t[3]], c, col)
	for i in 4:
		var j := (i + 1) % 4
		face([b[i], b[j], t[j], t[i]], c, side)


## Boîte dont le dessus est plus petit (pare-brise, lunette, flancs inclinés).
## Bas : x de ±w0/2, z de z0 à z1. Haut : ±w1/2, de z0 + df à z1 − db.
func taper(cx: float, y0: float, y1: float, z0: float, z1: float, w0: float, w1: float,
		df: float, db: float, col: Color) -> void:
	var b := [Vector3(cx - w0 / 2, y0, z0), Vector3(cx + w0 / 2, y0, z0), Vector3(cx + w0 / 2, y0, z1), Vector3(cx - w0 / 2, y0, z1)]
	var t := [Vector3(cx - w1 / 2, y1, z0 + df), Vector3(cx + w1 / 2, y1, z0 + df), Vector3(cx + w1 / 2, y1, z1 - db), Vector3(cx - w1 / 2, y1, z1 - db)]
	hull(b, t, col)


## Nez en coin : section (w × h, posée en y0) en z1, réduite à (tw × th) en z0.
## lift : hauteur du bout du nez au-dessus de y0.
func nose(cx: float, y0: float, z0: float, z1: float, w: float, h: float, tw: float, th: float, lift: float, col: Color) -> void:
	var b := [Vector3(cx - tw / 2, y0 + lift, z0), Vector3(cx + tw / 2, y0 + lift, z0), Vector3(cx + w / 2, y0, z1), Vector3(cx - w / 2, y0, z1)]
	var t := [Vector3(cx - tw / 2, y0 + lift + th, z0), Vector3(cx + tw / 2, y0 + lift + th, z0), Vector3(cx + w / 2, y0 + h, z1), Vector3(cx - w / 2, y0 + h, z1)]
	hull(b, t, col)


## Cylindre couché le long de X (roues, essieux).
func x_cyl(cx: float, cy: float, cz: float, r: float, w: float, sides: int, col: Color) -> void:
	var c := Vector3(cx, cy, cz)
	var x0 := cx - w / 2
	var x1 := cx + w / 2
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var p0 := Vector3(0, cos(a0) * r, sin(a0) * r)
		var p1 := Vector3(0, cos(a1) * r, sin(a1) * r)
		var a := c + p0
		var b := c + p1
		face([Vector3(x0, a.y, a.z), Vector3(x0, b.y, b.z), Vector3(x1, b.y, b.z), Vector3(x1, a.y, a.z)], c, col)
		face([Vector3(x0, cy, cz), Vector3(x0, a.y, a.z), Vector3(x0, b.y, b.z)], c, col.lightened(0.1))
		face([Vector3(x1, cy, cz), Vector3(x1, a.y, a.z), Vector3(x1, b.y, b.z)], c, col.lightened(0.1))


## Roue : pneu et jante. Repère : centre en (cx, r, cz).
func wheel(cx: float, cz: float, r: float, w := 0.24, col := TIRE) -> void:
	x_cyl(cx, r, cz, r, w, 8, col)
	x_cyl(cx, r, cz, r * 0.55, w + 0.04, 6, RIM)


## Paire de roues de part et d'autre (x = ±half).
func axle(half: float, cz: float, r: float, w := 0.24, col := TIRE) -> void:
	wheel(-half, cz, r, w, col)
	wheel(half, cz, r, w, col)


## Cylindre (ou cône) couché le long de Z, rayon r0 en z0 et r1 en z1.
## squash < 1 aplatit la section en hauteur.
func z_cyl(cx: float, cy: float, z0: float, z1: float, r0: float, r1: float, sides: int, col: Color, squash := 1.0) -> void:
	var c := Vector3(cx, cy, (z0 + z1) / 2.0)
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var p0 := Vector3(cos(a0), sin(a0) * squash, 0)
		var p1 := Vector3(cos(a1), sin(a1) * squash, 0)
		var q := [Vector3(cx, cy, z0) + p0 * r0, Vector3(cx, cy, z0) + p1 * r0, Vector3(cx, cy, z1) + p1 * r1, Vector3(cx, cy, z1) + p0 * r1]
		if r0 <= 0.001:
			face([q[0], q[2], q[3]], c, col)
		elif r1 <= 0.001:
			face([q[0], q[1], q[2]], c, col)
		else:
			face(q, c, col)
		if r0 > 0.001:
			face([Vector3(cx, cy, z0), q[0], q[1]], c, col.lightened(0.08))
		if r1 > 0.001:
			face([Vector3(cx, cy, z1), q[3], q[2]], c, col.lightened(0.08))


## Ellipsoïde à facettes (ballon, dirigeable, tête).
func ellipsoid(c: Vector3, rx: float, ry: float, rz: float, rings: int, segs: int, col: Color) -> void:
	for i in rings:
		var t0 := PI * i / rings
		var t1 := PI * (i + 1) / rings
		for j in segs:
			var p0 := TAU * j / segs
			var p1 := TAU * (j + 1) / segs
			var pts := [_ell(c, rx, ry, rz, t0, p0), _ell(c, rx, ry, rz, t0, p1), _ell(c, rx, ry, rz, t1, p1), _ell(c, rx, ry, rz, t1, p0)]
			var shade := col.darkened(0.12 * float(i) / rings)
			if i == 0:
				face([pts[0], pts[2], pts[3]], c, shade)
			elif i == rings - 1:
				face([pts[0], pts[1], pts[2]], c, shade)
			else:
				face(pts, c, shade)


static func _ell(c: Vector3, rx: float, ry: float, rz: float, theta: float, phi: float) -> Vector3:
	return c + Vector3(sin(theta) * cos(phi) * rx, cos(theta) * ry, sin(theta) * sin(phi) * rz)


## Paire d'ailes (ou d'empennages) symétriques.
## Emplanture en x = ±x0, centrée en z, corde cr ; saumon à ±(x0 + span), reculé de sweep, corde ct.
func wings(y: float, z: float, x0: float, span: float, cr: float, ct: float, sweep: float, th: float,
		col: Color, dihedral := 0.0) -> void:
	for s in [-1.0, 1.0]:
		var xr: float = x0 * s
		var xt: float = (x0 + span) * s
		var yt := y + dihedral
		var b := [Vector3(xr, y, z - cr / 2), Vector3(xt, yt, z + sweep - ct / 2), Vector3(xt, yt, z + sweep + ct / 2), Vector3(xr, y, z + cr / 2)]
		var t := [Vector3(xr, y + th, z - cr / 2), Vector3(xt, yt + th * 0.5, z + sweep - ct / 2), Vector3(xt, yt + th * 0.5, z + sweep + ct / 2), Vector3(xr, y + th, z + cr / 2)]
		hull(b, t, col)


## Dérive verticale : pied de corde cr en (y, z), sommet à y + h reculé de sweep, corde ct.
func fin(y: float, z: float, h: float, cr: float, ct: float, sweep: float, th: float, col: Color) -> void:
	var b := [Vector3(-th / 2, y, z - cr / 2), Vector3(th / 2, y, z - cr / 2), Vector3(th / 2, y, z + cr / 2), Vector3(-th / 2, y, z + cr / 2)]
	var t := [Vector3(-th / 4, y + h, z + sweep - ct / 2), Vector3(th / 4, y + h, z + sweep - ct / 2), Vector3(th / 4, y + h, z + sweep + ct / 2), Vector3(-th / 4, y + h, z + sweep + ct / 2)]
	hull(b, t, col)


## Voile triangulaire (deux faces) dans le plan x = cx.
func sail_tri(cx: float, a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	var pa := Vector3(cx, a.y, a.z)
	var pb := Vector3(cx, b.y, b.z)
	var pc := Vector3(cx, c.y, c.z)
	tri(pa, pb, pc, Vector3.RIGHT, col)
	tri(pa, pb, pc, Vector3.LEFT, col.darkened(0.08))


## Voile carrée (deux faces) face à l'avant, en z, de largeur w et de y0 à y1.
func sail_square(z: float, y0: float, y1: float, w: float, col: Color, belly := 0.4) -> void:
	box(0, y0, z + belly / 2, w, y1 - y0, 0.06, col)


## Personnage assis ou debout (conducteur, cycliste, passager).
func person(x: float, y: float, z: float, col: Color, seated := true) -> void:
	if not seated:
		box(x, y, z, 0.34, 0.85, 0.24, Color("2b2d42"))
		y += 0.85
	box(x, y, z, 0.42, 0.6, 0.28, col)
	box(x, y + 0.62, z, 0.24, 0.26, 0.24, SKIN)


## Cheval de trait (avant vers −Z) : centre du corps en (x, z).
func horse(x: float, z: float, col := Color("7b4b2a")) -> void:
	box(x, 0.95, z, 0.55, 0.65, 1.7, col)
	for dx in [-0.18, 0.18]:
		for dz in [-0.65, 0.65]:
			box(x + dx, 0.0, z + dz, 0.14, 1.0, 0.16, col.darkened(0.2))
	taper(x, 1.35, 2.0, z - 1.05, z - 0.6, 0.32, 0.26, 0.25, 0.1, col)
	box(x, 1.75, z - 1.25, 0.24, 0.3, 0.55, col.darkened(0.05))
	box(x, 1.6, z + 0.85, 0.12, 0.5, 0.12, Color("2b1d14"))


## Bogie ferroviaire (châssis et deux essieux), centré en z.
func bogie(cz: float, gauge := 1.435, r := 0.46) -> void:
	box(0, 0.35, cz, gauge + 0.3, 0.4, 2.6, Color("30302e"))
	for dz in [-0.9, 0.9]:
		axle(gauge / 2.0, cz + dz, r, 0.14, Color("3a3a3a"))


## Pantographe en losange sur le toit (y).
func pantograph(y: float, z: float) -> void:
	var col := Color("3d3d3d")
	box(0, y, z, 0.9, 0.12, 0.5, col)
	taper(0, y + 0.12, y + 0.7, z - 0.6, z + 0.2, 0.08, 0.08, 0.5, 0.0, col)
	taper(0, y + 0.7, y + 1.2, z - 0.1, z + 0.4, 0.08, 0.08, 0.0, 0.4, col)
	box(0, y + 1.2, z, 1.6, 0.06, 0.12, col)


## Tige à section carrée de a à b (cadres de vélo, mâts inclinés, perches, rames).
func rod(a: Vector3, b: Vector3, th: float, col: Color) -> void:
	var d := (b - a).normalized()
	var u := d.cross(Vector3.UP)
	if u.length_squared() < 1e-4:
		u = d.cross(Vector3.RIGHT)
	u = u.normalized() * th / 2.0
	var v := d.cross(u).normalized() * th / 2.0
	hull([a - u - v, a + u - v, a + u + v, a - u + v], [b - u - v, b + u - v, b + u + v, b - u + v], col)
