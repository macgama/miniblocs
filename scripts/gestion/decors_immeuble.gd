class_name DecorsImmeuble
extends RefCounted
## Décors de base des pièces de l'immeuble (GestionDiorama) : hall, escalier,
## appartements meublés (plus nombreux et plus beaux à chaque niveau), caves,
## loge, buanderie, jardin, parking, aire de jeux, toit. Rend les places des
## habitants et des visiteurs.

const Y := 0.066


static func dessiner(d: GestionDiorama, k: LpKit, decor: String, r: Array, n: int) -> Array:
	match decor:
		"imm_hall":
			return _hall(d, k, r, n)
		"imm_escalier":
			return _escalier(d, k, r, n)
		"imm_appart_a":
			return _appart(d, k, r, n, 3)
		"imm_appart_b":
			return _appart(d, k, r, n, 2)
		"imm_caves":
			return _caves(d, k, r, n)
		"imm_loge":
			return _loge(d, k, r, n)
		"imm_velos":
			return _velos(d, k, r, n)
		"imm_combles":
			return _combles(d, k, r, n)
		"imm_buanderie":
			return _buanderie(d, k, r, n)
		"imm_jardin":
			return _jardin(d, k, r, n)
		"imm_parking":
			return _parking(d, k, r, n)
		"imm_jeux":
			return _jeux(d, k, r, n)
		"imm_toit":
			return _toit(d, k, r, n)
	return DecorsParc.dessiner(d, k, decor, r, n)


static func _obj(k: LpKit, nom: String, p: Vector3, rot := 0.0, teinte := Color.WHITE) -> void:
	var xf := k.xf
	k.xf = xf * Transform3D(Basis(Vector3.UP, rot), p)
	ModelesImmeuble.dessiner(k, nom, teinte)
	k.xf = xf


static func _canape(k: LpKit, p: Vector3, col: Color) -> void:
	k.box(p + Vector3(0, 0.22, 0), Vector3(1.6, 0.44, 0.7), col)
	k.box(p + Vector3(0, 0.55, -0.28), Vector3(1.6, 0.5, 0.16), col.darkened(0.15))


# --- Pièces ------------------------------------------------------------------------------------

static func _hall(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	k.box(Vector3(x0 + 4.0, Y, z0 + 5.2), Vector3(2.0, 0.01, 1.0), Color("6c584c"), 0.0, false)
	if n >= 2:
		d._m(k, "banc", x0 + 6.6, z0 + 3.2, -PI * 0.5)
	if n >= 3:
		k.layer = "lumiere"
		k.box(Vector3(x0 + 4.0, 2.9, z0 + 3.0), Vector3(2.0, 0.05, 0.2), Color("fff3b0"), 0.0, false)
		k.layer = "base"
	return [d._place(Vector3(x0 + 1.6, 0, z0 + 1.0), PI, false), d._place(Vector3(x0 + 3.0, 0, z0 + 3.2), PI * 0.5, false)]


static func _escalier(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	# Volée de marches qui monte vers le fond, rampe.
	var marche := Color("b7a99a") if n < 3 else Color("9c6644")
	for i in 10:
		k.box(Vector3(x0 + 2.0, 0.09 + i * 0.17, z0 + 8.8 - i * 0.45), Vector3(1.8, 0.18 + i * 0.34, 0.45), marche)
	k.beam(Vector3(x0 + 3.0, 1.0, z0 + 9.0), Vector3(x0 + 3.0, 2.7, z0 + 4.6), 0.05, 0.05, Color("343a40"))
	if n >= 2:
		k.box(Vector3(x0 + 2.0, 1.8, z0 + 9.4), Vector3(1.6, 0.02, 0.5), Color("9b2226"), 0.0, false)
	return [d._place(Vector3(x0 + 4.4, 0, z0 + 8.4), PI, false), d._place(Vector3(x0 + 5.0, 0, z0 + 3.0), 0.0, false)]


## Appartements meublés : chaque niveau en ouvre et en embellit un de plus.
static func _appart(d: GestionDiorama, k: LpKit, r: Array, n: int, cases: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var w := float(r[2])
	var dz := float(r[3]) / cases
	var out: Array = []
	var murs := Color(String(GestionTypes.genre("immeuble").get("murs", "f2e8d8")))
	var cols := [Color("457b9d"), Color("e76f51"), Color("2a9d8f"), Color("6d597a"), Color("bc6c25")]
	for i in cases:
		var cz0 := z0 + i * dz
		if i > 0:
			k.box(Vector3(x0 + (w - 1.6) * 0.5, 0.6, cz0), Vector3(w - 1.6, 1.2, 0.12), murs, 0.0, false)
		var ouvert := i < n
		if not ouvert:
			# Logement pas encore rénové : bâche et pots de peinture.
			k.box(Vector3(x0 + w * 0.45, 0.08, cz0 + dz * 0.5), Vector3(w * 0.7, 0.04, dz - 0.8), Color("7d7466"), 0.0, false)
			k.box(Vector3(x0 + 3.0, 0.2, cz0 + dz * 0.5), Vector3(0.4, 0.4, 0.4), Color("e9c46a"))
			continue
		var col: Color = cols[(i + n) % cols.size()]
		# Lit, canapé, table et tapis.
		_obj(k, "lit_double", Vector3(x0 + 1.4, 0, cz0 + dz * 0.5), PI * 0.5, col)
		_canape(k, Vector3(x0 + w * 0.55, 0, cz0 + dz - 0.7), col.lightened(0.3))
		_obj(k, "table_salle", Vector3(x0 + w * 0.55, 0, cz0 + dz * 0.42))
		k.box(Vector3(x0 + w * 0.55, Y + 0.004, cz0 + dz * 0.45), Vector3(2.2, 0.01, 1.6), col.lightened(0.5), 0.0, false)
		out.append(d._place(Vector3(x0 + w * 0.55, 0, cz0 + dz - 0.6), PI, true))
		out.append(d._place(Vector3(x0 + w * 0.55 - 0.9, 0, cz0 + dz * 0.42), PI * 0.5, true))
	return out


static func _caves(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	# Portes de caves grillagées le long du fond.
	for i in 4 + mini(n, 3):
		k.box(Vector3(x0 + 1.0 + i * 1.4, 1.0, z0 + 3.2), Vector3(1.2, 2.0, 0.05), Color("8d99ae") if n >= 2 else Color("6c584c"), 0.0, false)
	return []


static func _loge(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	d._chaise(k, Vector3(x0 + 2.5, 0, z0 + 0.6), 0.0, Color("588157"))
	return [d._place(Vector3(x0 + 2.5, 0, z0 + 2.6), PI, false)]


static func _velos(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	k.box(Vector3(x0 + 3.0, 0.45, z0 + 5.4), Vector3(1.0, 0.9, 0.6), Color("adb5bd"))
	return [d._place(Vector3(x0 + 1.6, 0, z0 + 2.2), PI * 0.5, false)]


static func _combles(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	# Poutres du toit.
	for i in 3:
		k.box(Vector3(x0 + 1.5 + i * 2.5, 2.6, z0 + 3.0), Vector3(0.2, 0.2, 5.6), Color("7f5539"))
	if n >= 1:
		_canape(k, Vector3(x0 + 2.4, 0, z0 + 2.0), Color("ddb892"))
	return [d._place(Vector3(x0 + 2.4, 0, z0 + 2.2), PI, true)]


static func _buanderie(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	d._m(k, "lave_linge", x0 + 6.4, z0 + 0.6, 0.0)
	if n >= 2:
		d._m(k, "lave_linge", x0 + 7.6, z0 + 0.6, 0.0)
	return [d._place(Vector3(x0 + 6.4, 0, z0 + 1.6), PI, false), d._place(Vector3(x0 + 3.0, 0, z0 + 3.4), PI * 0.5, false)]


static func _jardin(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	d._arbre(k, Vector3(x0 + 1.4, 0, z0 + 4.4), 0.8)
	if n >= 2:
		d._arbre(k, Vector3(x0 + 10.4, 0, z0 + 3.4), 0.7)
	for i in 6:
		k.box(Vector3(x0 + 3.0 + i * 0.9, Y, z0 + 4.4), Vector3(0.6, 0.01, 0.6), Color("d6ccc2"), 0.0, false)
	return [d._place(Vector3(x0 + 4.0, 0, z0 + 3.4), PI, false), d._place(Vector3(x0 + 8.0, 0, z0 + 4.6), 0.0, false)]


static func _parking(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	for i in 2:
		k.box(Vector3(x0 + 6.4 + i * 2.6, Y, z0 + 4.0), Vector3(0.1, 0.01, 4.6), Color("f6f4ef"), 0.0, false)
	d._m(k, "voiture", x0 + 7.7, z0 + 4.2, 0.0)
	return []


static func _jeux(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	k.box(Vector3(x0 + 4.5, Y, z0 + 4.0), Vector3(8.6, 0.01, 7.6), Color("f4a261"), 0.0, false)
	d._m(k, "banc", x0 + 8.4, z0 + 4.0, -PI * 0.5)
	return [d._place(Vector3(x0 + 8.0, 0, z0 + 4.0), -PI * 0.5, true), d._place(Vector3(x0 + 4.2, 0, z0 + 4.0), 0.0, false)]


static func _toit(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	# Acrotère et gravier.
	k.box(Vector3(x0 + 5.0, 0.3, z0 + 0.1), Vector3(10.0, 0.6, 0.2), Color("8d99ae"))
	k.box(Vector3(x0 + 0.1, 0.3, z0 + 5.0), Vector3(0.2, 0.6, 10.0), Color("8d99ae"))
	return [d._place(Vector3(x0 + 6.0, 0, z0 + 6.4), PI, false)]
