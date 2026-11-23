class_name DecorsSupermarche
extends RefCounted
## Décors de base des pièces du supermarché (GestionDiorama) : gondoles,
## caisses, étals, meubles froids, réserve, parking… Plus le niveau monte,
## plus il y a de rayons et de caisses. Rend les places des clients.

const Y := 0.066


static func dessiner(d: GestionDiorama, k: LpKit, decor: String, r: Array, n: int) -> Array:
	match decor:
		"smk_entree":
			return _entree(d, k, r, n)
		"smk_caisses":
			return _caisses(d, k, r, n)
		"smk_rayons":
			return _rayons(d, k, r, n)
		"smk_fruits":
			return _fruits(d, k, r, n)
		"smk_frais":
			return _frais(d, k, r, n)
		"smk_boucherie":
			return _boucherie(d, k, r, n)
		"smk_boulangerie":
			return _boulangerie(d, k, r, n)
		"smk_reserve":
			return _reserve(d, k, r, n)
		"smk_bureau":
			return _bureau(d, k, r, n)
		"smk_pause":
			return _pause(d, k, r, n)
		"smk_bazar":
			return _bazar(d, k, r, n)
		"smk_accueil":
			return _accueil(d, k, r, n)
		"smk_parking":
			return _parking(d, k, r, n)
		"smk_drive":
			return _drive(d, k, r, n)
		"smk_quai":
			return _quai(d, k, r, n)
	return DecorsImmeuble.dessiner(d, k, decor, r, n)


## Un objet du supermarché posé dans la maquette (x, z absolus).
static func _obj(k: LpKit, nom: String, p: Vector3, rot := 0.0, teinte := Color.WHITE) -> void:
	var xf := k.xf
	k.xf = xf * Transform3D(Basis(Vector3.UP, rot), p)
	ModelesSupermarche.dessiner(k, nom, teinte)
	k.xf = xf


static func _neon(k: LpKit, p: Vector3, l: float, axe_x := true) -> void:
	k.layer = "lumiere"
	k.box(p, Vector3(l, 0.05, 0.15) if axe_x else Vector3(0.15, 0.05, l), Color("f1faee"), 0.0, false)
	k.layer = "base"


# --- Pièces ------------------------------------------------------------------------------------

static func _entree(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	# Tapis d'entrée et enseigne au-dessus des portes.
	k.box(Vector3(x0 + 4.0, Y, z0 + 5.2), Vector3(2.4, 0.01, 1.2), Color("343a40"), 0.0, false)
	k.box(Vector3(x0 + 4.0, 2.7, z0 + 5.9), Vector3(3.0, 0.4, 0.05), ModelesSupermarche.ROUGE, 0.0, false)
	if n >= 3:
		_neon(k, Vector3(x0 + 4.0, 2.9, z0 + 3.0), 3.0)
	return []


static func _caisses(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var out: Array = []
	# Une caisse par niveau (jusqu'à 4), les clients font la queue derrière.
	for i in mini(n, 3):
		var x := x0 + 2.8 + i * 3.2
		_obj(k, "caisse_tapis", Vector3(x, 0, z0 + 3.0))
		out.append(d._place(Vector3(x + 0.7, 0, z0 + 1.4), 0.0, false))
		out.append(d._place(Vector3(x + 0.7, 0, z0 + 0.7), 0.0, false))
	if n >= 4:
		_neon(k, Vector3(x0 + 8.0, 2.9, z0 + 3.0), 12.0)
	return out


static func _rayons(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var out: Array = []
	# Gondoles parallèles au fond : 2 au niveau 1, jusqu'à 6.
	var nb := mini(1 + n, 5)
	var xs := [5.5, 10.5, 3.0, 13.0, 8.0]
	var cols := [Color("e63946"), Color("1d6fa3"), Color("2a9d8f"), Color("f4a261"), Color("6d597a"), Color("e9c46a")]
	for i in nb:
		var x := x0 + float(xs[i])
		var xf := k.xf
		k.xf = xf * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(x, 0, z0 + 8.2))
		ModelesSupermarche.gondole(k, 7.0, cols[i], i)
		k.xf = xf
		out.append(d._place(Vector3(x - 0.9, 0, z0 + 7.0), PI * 0.5, false))
		out.append(d._place(Vector3(x + 0.9, 0, z0 + 9.4), -PI * 0.5, false))
	if n >= 2:
		for i in 2:
			_neon(k, Vector3(x0 + 4.0 + i * 8.0, 2.95, z0 + 8.0), 10.0, false)
	return out


static func _fruits(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var out: Array = []
	# Îlots de fruits au milieu : un par niveau (3 au plus).
	for i in mini(n, 3):
		var p := Vector3(x0 + 5.0, 0, z0 + 2.4 + i * 3.4)
		k.box(p + Vector3(0, 0.4, 0), Vector3(1.6, 0.8, 2.2), ModelesSupermarche.BOIS)
		for j in 4:
			var c: Color = ModelesSupermarche.PRODUITS[(i * 4 + j) % ModelesSupermarche.PRODUITS.size()]
			k.blob(p + Vector3(-0.4 + (j % 2) * 0.8, 0.92, -0.5 + (j / 2) * 1.0), Vector3(0.35, 0.12, 0.45), c, c.lightened(0.2), 0.3, 0)
		out.append(d._place(p + Vector3(1.3, 0, 0), -PI * 0.5, false))
	k.box(Vector3(x0 + 4.0, Y, z0 + 13.0), Vector3(7.0, 0.01, 1.4), Color("c2b280"), 0.0, false)
	return out


static func _frais(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var out: Array = []
	# Meubles froids le long du mur du fond, un de plus par niveau.
	var ps := [Vector3(x0 + 1.6, 0, z0 + 0.6), Vector3(x0 + 6.4, 0, z0 + 0.6), Vector3(x0 + 4.0, 0, z0 + 6.4)]
	for i in mini(n + 1, 3):
		_obj(k, "meuble_froid", ps[i], 0.0)
		out.append(d._place(ps[i] + Vector3(0, 0, 1.0), PI, false))
	if n >= 3:
		_obj(k, "bac_surgele", Vector3(x0 + 4.0, 0, z0 + 9.6))
		out.append(d._place(Vector3(x0 + 4.0, 0, z0 + 10.5), PI, false))
	return out


static func _boucherie(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var out: Array = []
	# Billot et crochets derrière le comptoir.
	k.box(Vector3(x0 + 7.2, 0.45, z0 + 6.4), Vector3(0.8, 0.9, 0.8), Color("8d6e63"))
	for i in 3:
		k.tube(Vector3(x0 + 7.85, 2.1, z0 + 2.0 + i * 0.6), Vector3(x0 + 7.85, 1.7, z0 + 2.0 + i * 0.6), 0.02, 0.02, 3, ModelesSupermarche.GRIS)
	out.append(d._place(Vector3(x0 + 3.8, 0, z0 + 3.4), PI * 0.5, false))
	out.append(d._place(Vector3(x0 + 3.8, 0, z0 + 4.6), PI * 0.5, false))
	if n >= 3:
		_neon(k, Vector3(x0 + 4.0, 2.9, z0 + 4.0), 5.0)
	return out


static func _boulangerie(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var out: Array = []
	# Comptoir à pains.
	k.box(Vector3(x0 + 4.0, 0.5, z0 + 2.6), Vector3(4.0, 1.0, 0.6), ModelesSupermarche.BOIS)
	for i in 6:
		k.tube(Vector3(x0 + 2.4 + i * 0.6, 1.05, z0 + 2.5), Vector3(x0 + 2.4 + i * 0.6, 1.05, z0 + 2.75), 0.06, 0.05, 5, Color("d4a373"))
	out.append(d._place(Vector3(x0 + 3.0, 0, z0 + 3.6), PI, false))
	out.append(d._place(Vector3(x0 + 5.0, 0, z0 + 3.6), PI, false))
	return out


static func _reserve(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	# Palettes filmées, une de plus par niveau.
	var xs := [2.4, 4.0, 11.0, 12.6, 5.6]
	for i in mini(n + 1, 5):
		var p := Vector3(x0 + float(xs[i]), 0, z0 + 3.0)
		k.box(p + Vector3(0, 0.07, 0), Vector3(1.2, 0.14, 1.0), ModelesSupermarche.BOIS)
		k.box(p + Vector3(0, 0.6, 0), Vector3(1.1, 0.9, 0.9), ModelesSupermarche.CARTON)
	return []


static func _bureau(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	k.box(Vector3(x0 + 4.0, 0.37, z0 + 2.4), Vector3(1.8, 0.74, 0.8), ModelesSupermarche.BOIS)
	k.box(Vector3(x0 + 4.0, 0.8, z0 + 2.3), Vector3(0.5, 0.06, 0.35), ModelesSupermarche.NOIR, 0.0, false)
	return []


static func _pause(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	k.box(Vector3(x0 + 5.6, 0.37, z0 + 2.4), Vector3(0.9, 0.74, 1.4), BLANC_T)
	d._chaise(k, Vector3(x0 + 4.8, 0, z0 + 2.4), PI * 0.5, Color("e76f51"))
	d._chaise(k, Vector3(x0 + 6.4, 0, z0 + 2.4), -PI * 0.5, Color("e76f51"))
	return []


const BLANC_T := Color("efe6d8")


static func _bazar(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var out: Array = []
	for i in mini(n, 2):
		var xf := k.xf
		k.xf = xf * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(x0 + 4.6, 0, z0 + 4.4 + i * 4.0))
		ModelesSupermarche.gondole(k, 3.0, Color("ff9f1c"), 5 + i)
		k.xf = xf
		out.append(d._place(Vector3(x0 + 3.6, 0, z0 + 4.4 + i * 4.0), PI * 0.5, false))
	return out


static func _accueil(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	k.box(Vector3(x0 + 4.0, 2.6, z0 + 0.1), Vector3(2.4, 0.4, 0.04), ModelesSupermarche.BLEU, 0.0, false)
	return [d._place(Vector3(x0 + 4.0, 0, z0 + 3.4), PI, false), d._place(Vector3(x0 + 4.0, 0, z0 + 4.2), PI, false)]


static func _parking(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var w := float(r[2])
	# Places peintes, une rangée de voitures garées selon le niveau.
	var nb := int(w / 2.6)
	for i in nb:
		k.box(Vector3(x0 + 0.3 + i * 2.6, Y, z0 + 2.6), Vector3(0.1, 0.01, 4.4), Color("f6f4ef"), 0.0, false)
	for i in mini(n + 1, nb - 1):
		if i % 2 == 1 and n < 3:
			continue
		d._m(k, "voiture", x0 + 1.6 + i * 2.6, z0 + 2.6, 0.0)
	return []


static func _drive(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	for i in 3:
		k.box(Vector3(x0 + 1.5 + i * 3.0, Y, z0 + 4.6), Vector3(0.1, 0.01, 4.0), Color("f2b705"), 0.0, false)
	k.box(Vector3(x0 + 5.0, 2.8, z0 + 0.2), Vector3(3.0, 0.5, 0.06), ModelesSupermarche.VERT, 0.0, false)
	return [d._place(Vector3(x0 + 5.0, 0, z0 + 2.0), PI, false)]


static func _quai(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	# Bande jaune et palettes en attente.
	for i in 10:
		k.box(Vector3(x0 + 0.5 + i, Y, z0 + 1.6), Vector3(0.48, 0.01, 0.2), ModelesSupermarche.JAUNE if i % 2 == 0 else ModelesSupermarche.NOIR, 0.0, false)
	for i in mini(n, 3):
		var p := Vector3(x0 + 1.4 + i * 1.6, 0, z0 + 2.8)
		k.box(p + Vector3(0, 0.07, 0), Vector3(1.2, 0.14, 1.0), ModelesSupermarche.BOIS)
		k.box(p + Vector3(0, 0.55, 0), Vector3(1.1, 0.8, 0.9), ModelesSupermarche.PRODUITS[i])
	return []
