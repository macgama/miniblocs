class_name DecorsCaserne
extends RefCounted
## Décors de base des pièces de la caserne de pompiers (GestionDiorama les
## appelle par DecorsRestaurant pour les décors « caserne_… »). Chaque
## fonction meuble la pièce selon son niveau et renvoie les places des
## visiteurs ({pos, rot, assis, avant}). Les engins de la remise ne sont pas
## ici : la maquette les place à part (GestionDiorama.placer_engins), car ils
## partent et reviennent avec les vraies interventions.
## Coordonnées absolues du plan (r = [x, z, largeur, profondeur]).

const ROUGE := Color("c1121f")
const JAUNE := Color("ffd60a")
const INOX := Color("c9ced3")
const GRIS := Color("5c636a")
const NOIR := Color("26262b")
const BOIS := Color("8a5a3b")
const BOIS_F := Color("5c4033")
const BLANC := Color("f6f4ef")
const Y := 0.066


static func dessiner(d: GestionDiorama, k: LpKit, decor: String, r: Array, n: int) -> Array:
	match decor:
		"caserne_accueil":
			return _accueil(d, k, r, n)
		"caserne_remise":
			return _remise(d, k, r, n)
		"caserne_alerte":
			return _alerte(d, k, r, n)
		"caserne_bureau":
			return _bureau(d, k, r, n)
		"caserne_reserve":
			return _reserve(d, k, r, n)
		"caserne_formation":
			return _formation(d, k, r, n)
		"caserne_cuisine":
			return _cuisine(d, k, r, n)
		"caserne_sport":
			return _sport(d, k, r, n)
		"caserne_dortoir":
			return _dortoir(d, k, r, n)
		"caserne_vestiaires":
			return _vestiaires(d, k, r, n)
		"caserne_atelier":
			return _atelier(d, k, r, n)
		"caserne_cour":
			return _cour(d, k, r, n)
		"caserne_tour":
			return _tour(d, k, r, n)
		"caserne_lavage":
			return _lavage(d, k, r, n)
	return []


static func _a(d: GestionDiorama, pid: String, oid: String) -> bool:
	return oid in (d.objets.get(pid, []) as Array)


## Bureau avec écran, clavier et chaise (face à -Z quand rot = 0).
static func _poste(d: GestionDiorama, k: LpKit, p: Vector3, ecrans: int, col := Color("d9d4c7")) -> void:
	k.box(p + Vector3(0, 0.74, 0), Vector3(1.6, 0.05, 0.75), col)
	for sx in [-0.72, 0.72]:
		k.box(p + Vector3(sx, 0.37, 0), Vector3(0.05, 0.74, 0.7), GRIS, 0.0, false)
	for i in ecrans:
		var x := (float(i) - float(ecrans - 1) * 0.5) * 0.5
		k.box(p + Vector3(x, 1.0, -0.2), Vector3(0.46, 0.3, 0.03), NOIR, 0.0, false)
		k.layer = "lumiere"
		k.box(p + Vector3(x, 1.0, -0.18), Vector3(0.42, 0.26, 0.01), [Color("8ecae6"), Color("90be6d"), Color("f4a261")][i % 3], 0.0, false)
		k.layer = "base"
	k.box(p + Vector3(0, 0.78, 0.12), Vector3(0.5, 0.02, 0.16), Color("495057"), 0.0, false)
	d._chaise(k, p + Vector3(0, 0, 0.75), PI, Color("2b2d42"))


# --- Pièces ------------------------------------------------------------------------------------

static func _accueil(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var out: Array = []
	# Guichet vitré, face à la porte.
	var g := Vector3(x0 + 2.5, 0, z0 + 8.95)
	k.box(g + Vector3(0, 0.55, 0), Vector3(1.9, 1.1, 0.5), ROUGE if n < 3 else Color("9b2226"))
	k.box(g + Vector3(0, 1.12, 0), Vector3(2.0, 0.05, 0.6), INOX)
	k.layer = "verre"
	k.box(g + Vector3(0, 1.55, -0.05), Vector3(1.9, 0.8, 0.03), Color(0.8, 0.9, 1.0, 0.3), 0.0, false)
	k.layer = "base"
	k.box(g + Vector3(-0.5, 1.17, 0.1), Vector3(0.4, 0.04, 0.3), BLANC, 0.0, false)
	# Bande rouge au sol vers le couloir, logo au mur.
	k.box(Vector3(x0 + 2.5, Y, z0 + 4.0), Vector3(0.35, 0.01, 7.0), ROUGE, 0.0, false)
	k.box(Vector3(x0 + 0.12, 1.7, z0 + 3.0), Vector3(0.04, 0.9, 0.9), ROUGE, 0.0, false)
	k.box(Vector3(x0 + 0.15, 1.7, z0 + 3.0), Vector3(0.02, 0.5, 0.5), JAUNE, 0.0, false)
	# Chaises d'attente.
	for i in 2 + mini(n, 3):
		d._chaise(k, Vector3(x0 + 4.4, 0, z0 + 5.6 + i * 0.6), -PI * 0.5, Color("457b9d"))
	out.append(d._place(Vector3(x0 + 4.4, 0, z0 + 5.6), -PI * 0.5, true))
	if n >= 3:
		# Panneau des volontaires et présentoir.
		k.box(Vector3(x0 + 0.12, 1.5, z0 + 7.6), Vector3(0.04, 1.0, 1.4), Color("e9ecef"), 0.0, false)
		for i in 3:
			k.box(Vector3(x0 + 0.15, 1.75 - i * 0.25, z0 + 7.6), Vector3(0.02, 0.12, 1.1), [ROUGE, Color("1d3557"), JAUNE][i], 0.0, false)
	if n >= 4:
		d._m(k, "plante_grande", x0 + 0.6, z0 + 0.6)
	if n >= 5:
		d._m(k, "lustre", x0 + 2.5, z0 + 6.0)
	return out


static func _remise(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var w := float(r[2])
	var dp := float(r[3])
	var out: Array = []
	# Marquages des baies (jaune) et seuils rouges et blancs devant les portes.
	for i in 5:
		var x := x0 + i * w / 4.0
		if i > 0 and i < 4:
			k.box(Vector3(x, Y, z0 + dp * 0.5), Vector3(0.12, 0.01, dp - 0.6), JAUNE, 0.0, false)
	for i in 4:
		var cx := x0 + (i + 0.5) * w / 4.0
		for j in 8:
			k.box(Vector3(cx - 1.6 + j * 0.46, Y, z0 + dp - 0.25), Vector3(0.44, 0.012, 0.4), ROUGE if j % 2 == 0 else BLANC, 0.0, false)
		# Numéro de la baie au sol.
		k.box(Vector3(cx, Y, z0 + dp * 0.5), Vector3(0.6, 0.01, 0.6), Color("8d949b"), 0.0, false)
	# Allée centrale entre les rangées.
	k.box(Vector3(x0 + w * 0.5, Y + 0.001, z0 + 7.05), Vector3(w - 0.4, 0.01, 0.9), Color("b8bec4"), 0.0, false)
	# Dévidoir mural et panneaux d'outils.
	k.lathe(Vector3(x0 + 0.25, 1.4, z0 + 9.0), [Vector2(0.0, -0.15), Vector2(0.4, -0.15), Vector2(0.4, 0.15), Vector2(0.0, 0.15)], 12, ROUGE)
	if n >= 2:
		# Extraction des gaz d'échappement au-dessus de chaque baie.
		for i in 4:
			var cx := x0 + (i + 0.5) * w / 4.0
			k.tube(Vector3(cx + 1.6, 3.3, z0 + 1.2), Vector3(cx + 1.6, 3.3, z0 + dp - 1.0), 0.06, 0.06, 6, INOX)
			k.tube(Vector3(cx + 1.6, 3.3, z0 + dp * 0.5 + 1.5), Vector3(cx + 1.6, 1.6, z0 + dp * 0.5 + 1.6), 0.09, 0.09, 6, JAUNE)
	if n >= 3:
		for i in 3:
			var x := x0 + 4.5 * (i + 1)
			k.box(Vector3(x, 1.6, z0 + 0.12), Vector3(1.1, 1.0, 0.04), Color("adb5bd"), 0.0, false)
	if n >= 4:
		# Grand écusson sur le mur du fond.
		k.box(Vector3(x0 + 6.75 + 2.25, 2.3, z0 + 0.1), Vector3(1.4, 1.4, 0.05), ROUGE, 0.0, false)
		k.box(Vector3(x0 + 9.0, 2.3, z0 + 0.13), Vector3(0.9, 0.9, 0.02), Color("d4af37"), 0.0, false)
	# Aire devant les portes jusqu'à la rue : on n'y stationne pas.
	var plan_z := z0 + dp
	var fin := plan_z + 11.0
	k.box(Vector3(x0 + w * 0.5, 0.035, (plan_z + fin) * 0.5), Vector3(w + 1.0, 0.03, fin - plan_z), Color("6c7075"), 0.0, false)
	for i in 9:
		var x := x0 + 1.0 + i * 2.0
		k.box(Vector3(x, 0.052, plan_z + 3.0), Vector3(1.0, 0.01, 0.25), JAUNE, 0.0, false)
	k.box(Vector3(x0 + w * 0.5, 0.052, plan_z + 1.2), Vector3(w, 0.01, 0.12), JAUNE, 0.0, false)
	k.box(Vector3(x0 + w * 0.5, 0.052, fin - 0.4), Vector3(w, 0.01, 0.12), JAUNE, 0.0, false)
	# Visiteurs dans l'allée (portes ouvertes, écoles).
	for x in [4.5, 9.0, 13.5]:
		out.append(d._place(Vector3(x0 + x, 0, z0 + 7.05), PI if x > 8.0 else 0.0, false))
	return out


static func _alerte(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	# Consoles (une de plus au niveau 3) face au mur de la carte.
	var nb := 2 if n < 3 else 3
	var xs := [3.2, 7.4, 5.3]
	for i in nb:
		var p := Vector3(x0 + float(xs[i]), 0, z0 + (1.9 if i < 2 else 4.6))
		_poste(d, k, p, 2 + mini(n, 3) / 2, Color("343a40"))
	# Témoin d'alerte rouge au mur et horloge.
	k.layer = "lumiere"
	k.box(Vector3(x0 + 10.8, 2.2, z0 + 0.3), Vector3(0.12, 0.3, 0.3), Color("ff4d4d"), 0.0, false)
	k.layer = "base"
	k.lathe(Vector3(x0 + 9.0, 2.2, z0 + 0.05), [Vector2(0.0, 0.0), Vector2(0.25, 0.0), Vector2(0.25, 0.05), Vector2(0.0, 0.05)], 12, BLANC)
	if n >= 4:
		d._m(k, "plante", x0 + 0.6, z0 + 6.4)
	return []


static func _bureau(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	_poste(d, k, Vector3(x0 + 3.0, 0, z0 + 2.0 + 0.0), 1, BOIS if n >= 3 else Color("d9d4c7"))
	k.box(Vector3(x0 + 0.4, 0.9, z0 + 1.2), Vector3(0.6, 1.8, 1.4), Color("adb5bd"))
	for i in 2:
		d._chaise(k, Vector3(x0 + 2.5 + i, 0, z0 + 4.0), 0.0, Color("6c757d"))
	if n >= 4:
		d._m(k, "canape", x0 + 3.0, z0 + 6.2, PI, Color("7b2d26"))
	return []


static func _reserve(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	d._etagere(k, Vector3(x0 + 2.5, 0, z0 + 0.35), 0.0, 3.0, 1.9, Color("adb5bd"), [ROUGE, Color("2a9d8f"), BLANC, JAUNE])
	if n >= 3:
		d._etagere(k, Vector3(x0 + 2.5, 0, z0 + 3.6), 0.0, 2.4, 1.4, Color("adb5bd"), [Color("ffd166"), INOX, ROUGE])
	return []


static func _formation(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var out: Array = []
	# Bureau du formateur.
	k.box(Vector3(x0 + 1.6, 0.4, z0 + 1.0), Vector3(1.2, 0.8, 0.6), BOIS)
	# Rangées de tables pour les stagiaires (plus nombreuses à chaque niveau).
	var rangs := [3.0, 4.6, 6.2]
	var nr: int = [0, 1, 2, 2, 3, 3][clampi(n, 0, 5)]
	for j in nr:
		for tx in [1.6, 4.4]:
			var t := Vector3(x0 + tx, 0, z0 + float(rangs[j]))
			k.box(t + Vector3(0, 0.72, 0), Vector3(2.0, 0.05, 0.6), Color("e9ecef"))
			for sx in [-0.9, 0.9]:
				k.box(t + Vector3(sx, 0.36, 0), Vector3(0.05, 0.72, 0.55), GRIS, 0.0, false)
			for sx in [-0.5, 0.5]:
				var c := t + Vector3(sx, 0, 0.55)
				d._chaise(k, c, PI, Color("c1121f") if n >= 3 else Color("457b9d"))
				out.append(d._place(c, PI, true))
	if n >= 5:
		d._m(k, "plante", x0 + 5.5, z0 + 7.4)
	return out


static func _cuisine(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	# Plan de travail le long du mur du fond.
	k.box(Vector3(x0 + 2.5, 0.45, z0 + 0.35), Vector3(4.6, 0.9, 0.6), INOX)
	# Grande table du réfectoire et ses bancs.
	var lt := 2.6 + 0.5 * mini(n, 3)
	var t := Vector3(x0 + 2.5, 0, z0 + 4.2)
	k.box(t + Vector3(0, 0.74, 0), Vector3(1.1, 0.06, lt), BOIS)
	for sz in [-lt * 0.4, lt * 0.4]:
		k.box(t + Vector3(0, 0.37, sz), Vector3(0.9, 0.74, 0.1), BOIS_F, 0.0, false)
	for sx in [-0.85, 0.85]:
		k.box(t + Vector3(sx, 0.24, 0), Vector3(0.35, 0.06, lt - 0.2), BOIS_F)
	for i in int(lt / 0.7):
		for sx in [-0.3, 0.3]:
			k.lathe(t + Vector3(sx, 0.77, -lt * 0.5 + 0.4 + i * 0.7), [Vector2(0.0, 0.0), Vector2(0.13, 0.0), Vector2(0.14, 0.02), Vector2(0.0, 0.02)], 8, BLANC)
	return []


static func _sport(_d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	k.box(Vector3(x0 + 2.5, Y, z0 + 4.0), Vector3(3.6, 0.03, 3.0), Color("2b2d42"), 0.0, false)
	if n >= 2:
		k.box(Vector3(x0 + 2.5, 1.3, z0 + 0.1), Vector3(3.5, 1.6, 0.04), Color("cfe8ef"), 0.0, false)
	return []


static func _dortoir(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	# Lits simples le long des murs : un de plus à chaque niveau.
	var lits := [[0.55, 1.4, PI * 0.5], [6.45, 3.4, -PI * 0.5], [0.55, 3.8, PI * 0.5], [6.45, 5.8, -PI * 0.5], [0.55, 6.2, PI * 0.5], [3.5, 0.6, 0.0]]
	for i in mini(1 + n, lits.size()):
		var l: Array = lits[i]
		_lit(k, Vector3(x0 + float(l[0]), 0, z0 + float(l[1])), float(l[2]), n)
	if n >= 2:
		for i in 2:
			k.box(Vector3(x0 + 0.4, 0.3, z0 + 2.6 + i * 2.4), Vector3(0.4, 0.6, 0.4), BOIS)
	if n >= 3:
		k.box(Vector3(x0 + 3.5, Y, z0 + 4.0), Vector3(2.4, 0.01, 2.6), Color("6d597a"), 0.0, false)
	return []


## Lit simple, tête contre le mur (rot : vers où pointe le pied du lit, +Z local).
static func _lit(k: LpKit, p: Vector3, rot: float, n: int) -> void:
	var sauve := k.xf
	k.xf = sauve * Transform3D(Basis(Vector3.UP, rot - PI * 0.5), p)
	k.box(Vector3(0.95, 0.22, 0), Vector3(1.9, 0.3, 0.9), GRIS)
	k.box(Vector3(0.95, 0.42, 0), Vector3(1.85, 0.12, 0.85), Color("e9ecef"))
	k.box(Vector3(1.15, 0.5, 0), Vector3(1.3, 0.06, 0.87), [Color("1d3557"), Color("1d3557"), Color("457b9d"), Color("9b2226"), Color("2a9d8f"), Color("6d597a")][clampi(n, 0, 5)], 0.0, false)
	k.box(Vector3(0.2, 0.52, 0), Vector3(0.32, 0.1, 0.55), BLANC)
	k.xf = sauve


static func _vestiaires(_d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	# Banc central.
	k.box(Vector3(x0 + 2.5, 0.22, z0 + 3.5), Vector3(0.45, 0.06, 3.0), BOIS)
	for sz in [-1.2, 1.2]:
		k.box(Vector3(x0 + 2.5, 0.1, z0 + 3.5 + sz), Vector3(0.35, 0.2, 0.08), GRIS, 0.0, false)
	# Patères avec casques (et bottes) au mur de droite.
	for i in 2 + n:
		var z := z0 + 0.8 + i * 0.75
		if z > z0 + 7.2:
			break
		k.box(Vector3(x0 + 4.85, 1.6, z), Vector3(0.1, 0.05, 0.05), INOX, 0.0, false)
		k.blob(Vector3(x0 + 4.75, 1.75, z), Vector3(0.15, 0.12, 0.16), Color("e9ecef"), Color("f8f9fa"), 0.04, 0)
		k.box(Vector3(x0 + 4.7, 0.15, z), Vector3(0.28, 0.3, 0.16), NOIR)
	return []


static func _atelier(_d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	# Fûts d'huile et taches au sol.
	for i in 2:
		k.lathe(Vector3(x0 + 0.5 + i * 0.65, 0, z0 + 0.5), [Vector2(0.0, 0.0), Vector2(0.3, 0.0), Vector2(0.3, 0.9), Vector2(0.0, 0.9)], 10, [Color("1d3557"), ROUGE][i])
	k.box(Vector3(x0 + 3.0, Y, z0 + 5.0), Vector3(1.0, 0.01, 0.7), Color("3d3a36"), 0.0, false)
	if n >= 3:
		k.box(Vector3(x0 + 5.85, 1.6, z0 + 5.5), Vector3(0.04, 1.2, 2.0), Color("adb5bd"), 0.0, false)
	return []


static func _cour(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var out: Array = []
	# Bordures et pavés plus clairs au centre.
	k.box(Vector3(x0 + 5.25, Y, z0 + 3.25), Vector3(6.0, 0.01, 3.0), Color("ddd6c8"), 0.0, false)
	for i in 4:
		k.box(Vector3(x0 + 0.2 + i * 3.4, 0.15, z0 + 6.3), Vector3(0.3, 0.3, 0.3), Color("bdb5a6"))
	if n >= 4:
		k.box(Vector3(x0 + 5.25, Y + 0.002, z0 + 3.25), Vector3(1.2, 0.01, 1.2), ROUGE, 0.0, false)
	# Visiteurs : photos devant la stèle, le camion ancien.
	out.append(d._place(Vector3(x0 + 3.0, 0, z0 + 3.6), 0.0, false))
	out.append(d._place(Vector3(x0 + 7.6, 0, z0 + 4.4), PI, false))
	return out


static func _tour(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var out: Array = []
	# La tour : un étage de plus tous les deux niveaux, fenêtres ouvertes.
	var etages := 3 + (n - 1) / 2
	var t := Vector3(x0 + 2.2, 0, z0 + 2.2)
	var hz := 2.8
	k.box(t + Vector3(0, etages * hz * 0.5, 0), Vector3(3.2, etages * hz, 3.2), Color("b5332e"))
	for e in etages:
		var y := 1.4 + e * hz
		for c in [Vector3(0, y, 1.61), Vector3(1.61, y, 0)]:
			var sz := Vector3(1.1, 1.3, 0.04) if c.x == 0.0 else Vector3(0.04, 1.3, 1.1)
			k.box(t + c, sz, NOIR, 0.0, false)
		k.box(t + Vector3(0, (e + 1) * hz, 0), Vector3(3.3, 0.12, 3.3), Color("8d0f17"), 0.0, false)
	k.box(t + Vector3(0, etages * hz + 0.5, 0), Vector3(3.4, 0.9, 3.4), Color("6c757d"))
	# Garde-corps et échelle fixe sur le côté.
	k.beam(t + Vector3(-1.75, 0, 1.4), t + Vector3(-1.75, etages * hz + 1.0, 1.4), 0.05, 0.05, INOX)
	k.beam(t + Vector3(-1.75, 0, 1.0), t + Vector3(-1.75, etages * hz + 1.0, 1.0), 0.05, 0.05, INOX)
	for j in int(etages * hz / 0.4):
		k.beam(t + Vector3(-1.75, 0.3 + j * 0.4, 1.0), t + Vector3(-1.75, 0.3 + j * 0.4, 1.4), 0.03, 0.03, INOX)
	# Matelas de réception au pied.
	k.box(t + Vector3(0, 0.25, 2.6), Vector3(2.6, 0.5, 1.6), Color("ffb703"))
	# Visiteurs (jeunes sapeurs-pompiers, curieux) au bord de la piste.
	for i in 3:
		out.append(d._place(Vector3(x0 + 5.0 + i * 1.2, 0, z0 + 9.4), PI, false))
	return out


static func _lavage(_d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	# Dalle de béton, grille d'évacuation, flaque.
	k.box(Vector3(x0 + 5.0, Y, z0 + 5.25), Vector3(6.4, 0.01, 8.0), Color("9aa0a6"), 0.0, false)
	k.box(Vector3(x0 + 5.0, Y + 0.002, z0 + 5.25), Vector3(0.4, 0.01, 7.0), NOIR, 0.0, false)
	k.layer = "eau"
	k.box(Vector3(x0 + 4.2, Y + 0.004, z0 + 6.6), Vector3(2.2, 0.01, 1.6), Color(0.45, 0.6, 0.75, 0.6), 0.0, false)
	k.layer = "base"
	if n >= 2:
		k.lathe(Vector3(x0 + 9.4, 0, z0 + 5.0), [Vector2(0.0, 0.0), Vector2(0.35, 0.0), Vector2(0.35, 1.0), Vector2(0.0, 1.0)], 10, Color("2a9d8f"))
	return []
