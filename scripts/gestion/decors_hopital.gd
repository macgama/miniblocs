class_name DecorsHopital
extends RefCounted
## Décors de base des pièces de l'hôpital (GestionDiorama les appelle par
## DecorsRestaurant → DecorsCaserne → DecorsCommissariat pour les décors
## « hopital_… »). Chaque fonction meuble la pièce selon son niveau et renvoie
## les places des visiteurs ({pos, rot, assis, avant}). Les ambulances du
## garage sont placées à part (GestionDiorama.placer_engins).
## Coordonnées absolues du plan (r = [x, z, largeur, profondeur]).

const VERT := Color("2a9d8f")
const VERT_C := Color("bfe3dc")
const BLANC := Color("f6f4ef")
const ROUGE := Color("d62828")
const JAUNE := Color("ffd60a")
const INOX := Color("c9ced3")
const GRIS := Color("5c636a")
const NOIR := Color("26262b")
const BLEU_C := Color("8ecae6")
const Y := 0.066


static func dessiner(d: GestionDiorama, k: LpKit, decor: String, r: Array, n: int) -> Array:
	match decor:
		"hopital_accueil":
			return _accueil(d, k, r, n)
		"hopital_garage":
			return _garage(d, k, r, n)
		"hopital_regulation":
			return DecorsCaserne._alerte(d, k, r, n)
		"hopital_bureau":
			return DecorsCaserne._bureau(d, k, r, n)
		"hopital_pharmacie":
			return _pharmacie(d, k, r, n)
		"hopital_consultations":
			return _consultations(d, k, r, n)
		"hopital_bloc":
			return _bloc(d, k, r, n)
		"hopital_imagerie":
			return _imagerie(d, k, r, n)
		"hopital_chambres":
			return _chambres(d, k, r, n)
		"hopital_garde":
			return _garde(d, k, r, n)
		"hopital_labo":
			return _labo(d, k, r, n)
		"hopital_jardin":
			return _jardin(d, k, r, n)
		"hopital_helistation":
			return _helistation(d, k, r, n)
		"hopital_parking":
			return _parking(d, k, r, n)
	return DecorsParc.dessiner(d, k, decor, r, n)


static func _croix(k: LpKit, p: Vector3, t: float, col: Color, axe_x := false) -> void:
	var e := 0.02
	if axe_x:
		k.box(p, Vector3(e, t, t * 0.33), col, 0.0, false)
		k.box(p, Vector3(e, t * 0.33, t), col, 0.0, false)
	else:
		k.box(p, Vector3(t, t * 0.33, e), col, 0.0, false)
		k.box(p, Vector3(t * 0.33, t, e), col, 0.0, false)


# --- Pièces ------------------------------------------------------------------------------------

static func _accueil(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var out: Array = []
	# Banque d'accueil blanche et verte.
	var g := Vector3(x0 + 2.5, 0, z0 + 8.95)
	k.box(g + Vector3(0, 0.55, 0), Vector3(2.2, 1.1, 0.55), BLANC)
	k.box(g + Vector3(0, 0.6, 0.28), Vector3(2.2, 0.15, 0.02), VERT, 0.0, false)
	k.box(g + Vector3(0, 1.12, 0), Vector3(2.3, 0.05, 0.65), Color("d9d4c7"))
	DecorsCaserne._poste(d, k, g + Vector3(0, 0, -0.9), 1, Color("d9d4c7"))
	# Ligne verte au sol vers le couloir, croix au mur.
	k.box(Vector3(x0 + 2.5, Y, z0 + 4.0), Vector3(0.35, 0.01, 7.0), VERT, 0.0, false)
	_croix(k, Vector3(x0 + 0.13, 1.9, z0 + 3.0), 0.8, VERT, true)
	# Chaises d'attente.
	for i in 2 + mini(n, 3):
		d._chaise(k, Vector3(x0 + 4.4, 0, z0 + 5.6 + i * 0.6), -PI * 0.5, Color("90be6d"))
	out.append(d._place(Vector3(x0 + 4.4, 0, z0 + 5.6), -PI * 0.5, true))
	out.append(d._place(Vector3(x0 + 4.4, 0, z0 + 6.2), -PI * 0.5, true))
	if n >= 4:
		d._m(k, "plante_grande", x0 + 0.6, z0 + 0.6)
	return out


static func _garage(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var w := float(r[2])
	var dp := float(r[3])
	var out: Array = []
	for i in 5:
		var x := x0 + i * w / 4.0
		if i > 0 and i < 4:
			k.box(Vector3(x, Y, z0 + dp * 0.5), Vector3(0.12, 0.01, dp - 0.6), JAUNE, 0.0, false)
	for i in 4:
		var cx := x0 + (i + 0.5) * w / 4.0
		for j in 8:
			k.box(Vector3(cx - 1.6 + j * 0.46, Y, z0 + dp - 0.25), Vector3(0.44, 0.012, 0.4), VERT if j % 2 == 0 else BLANC, 0.0, false)
		# Prise de secteur au mur pour chaque ambulance.
		k.box(Vector3(cx + 1.6, 1.2, z0 + 0.1), Vector3(0.3, 0.4, 0.08), JAUNE, 0.0, false)
	k.box(Vector3(x0 + w * 0.5, Y + 0.001, z0 + 7.05), Vector3(w - 0.4, 0.01, 0.9), Color("b8bec4"), 0.0, false)
	# Grand panneau « SAMU ».
	k.box(Vector3(x0 + 9.0, 2.4, z0 + 0.1), Vector3(2.6, 0.7, 0.05), Color("1d3557"), 0.0, false)
	k.box(Vector3(x0 + 9.0, 2.4, z0 + 0.13), Vector3(2.3, 0.4, 0.02), BLANC, 0.0, false)
	if n >= 2:
		k.layer = "lumiere"
		for i in 4:
			k.box(Vector3(x0 + (i + 0.5) * w / 4.0, 3.4, z0 + dp * 0.5), Vector3(0.15, 0.05, 2.4), Color("f1faee"), 0.0, false)
		k.layer = "base"
	if n >= 4:
		_croix(k, Vector3(x0 + 4.5, 2.3, z0 + 0.13), 1.0, ROUGE)
	# Aire de sortie (rien ne s'y pose) : marquage « Ambulances ».
	var plan_z := z0 + dp
	var fin := plan_z + 11.0
	k.box(Vector3(x0 + w * 0.5, 0.035, (plan_z + fin) * 0.5), Vector3(w + 1.0, 0.03, fin - plan_z), Color("6c7075"), 0.0, false)
	for i in 9:
		k.box(Vector3(x0 + 1.0 + i * 2.0, 0.052, plan_z + 3.0), Vector3(1.0, 0.01, 0.25), JAUNE, 0.0, false)
	k.box(Vector3(x0 + w * 0.5, 0.052, plan_z + 1.2), Vector3(w, 0.01, 0.12), JAUNE, 0.0, false)
	k.box(Vector3(x0 + w * 0.5, 0.052, fin - 0.4), Vector3(w, 0.01, 0.12), JAUNE, 0.0, false)
	for x in [4.5, 9.0, 13.5]:
		out.append(d._place(Vector3(x0 + x, 0, z0 + 7.05), PI if x > 8.0 else 0.0, false))
	return out


static func _pharmacie(_d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	# Comptoir de délivrance et casiers de médicaments au mur du fond.
	k.box(Vector3(x0 + 2.5, 0.5, z0 + 6.4), Vector3(3.2, 1.0, 0.5), BLANC)
	k.box(Vector3(x0 + 2.5, 1.02, z0 + 6.4), Vector3(3.3, 0.04, 0.6), VERT, 0.0, false)
	for i in 6:
		for j in 3:
			k.box(Vector3(x0 + 0.9 + i * 0.65, 0.6 + j * 0.55, z0 + 0.25), Vector3(0.6, 0.5, 0.4), [BLANC, VERT_C, Color("ffe8d6")][(i + j) % 3])
	if n >= 3:
		_croix(k, Vector3(x0 + 2.5, 2.5, z0 + 0.48), 0.6, VERT)
	return []


static func _consultations(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var out: Array = []
	var p := Vector3(x0 + 3.5, 0, z0 + 2.4)
	DecorsCaserne._poste(d, k, p, 1, Color("d9d4c7"))
	d._chaise(k, p + Vector3(-0.4, 0, -0.75), 0.0, VERT)
	out.append(d._place(p + Vector3(-0.4, 0, -0.75), 0.0, true))
	# Paravent.
	k.box(Vector3(x0 + 2.2, 0.85, z0 + 5.6), Vector3(0.05, 1.7, 1.6), Color("e9f5f2"), 0.0, false)
	for i in 2:
		d._chaise(k, Vector3(x0 + 5.4, 0, z0 + 4.6 + i * 0.7), -PI * 0.5, Color("6c757d"))
	out.append(d._place(Vector3(x0 + 5.4, 0, z0 + 4.6), -PI * 0.5, true))
	if n >= 4:
		d._m(k, "plante", x0 + 0.5, z0 + 7.3)
	return out


static func _bloc(_d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	# Sol vert stérile, sas vitré, plan de lavage chirurgical.
	k.box(Vector3(x0 + 2.5, Y, z0 + 3.8), Vector3(4.0, 0.01, 4.6), Color("a8dadc"), 0.0, false)
	k.box(Vector3(x0 + 2.5, 0.5, z0 + 7.6), Vector3(2.0, 0.9, 0.5), INOX)
	k.layer = "verre"
	k.box(Vector3(x0 + 2.5, 1.2, z0 + 6.8), Vector3(4.6, 2.4, 0.04), Color(0.75, 0.9, 0.9, 0.3), 0.0, false)
	k.layer = "base"
	if n >= 3:
		k.layer = "lumiere"
		k.box(Vector3(x0 + 4.7, 2.3, z0 + 0.4), Vector3(0.3, 0.2, 0.05), Color("ff4d4d"), 0.0, false)
		k.layer = "base"
	return []


static func _imagerie(_d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	# Pupitre derrière une vitre plombée, signe « rayons X ».
	k.box(Vector3(x0 + 4.2, 0.45, z0 + 7.4), Vector3(1.2, 0.9, 0.5), GRIS)
	k.layer = "verre"
	k.box(Vector3(x0 + 3.6, 1.2, z0 + 7.0), Vector3(2.6, 1.4, 0.04), Color(0.9, 0.8, 0.5, 0.35), 0.0, false)
	k.layer = "base"
	k.box(Vector3(x0 + 0.12, 1.8, z0 + 7.0), Vector3(0.03, 0.45, 0.45), JAUNE, 0.0, false)
	k.lathe(Vector3(x0 + 0.14, 1.8, z0 + 7.0), [Vector2(0.0, 0.0), Vector2(0.1, 0.0), Vector2(0.1, 0.01), Vector2(0.0, 0.01)], 3, NOIR)
	if n >= 4:
		k.layer = "lumiere"
		k.box(Vector3(x0 + 2.5, 2.6, z0 + 0.1), Vector3(0.8, 0.2, 0.05), Color("ff4d4d"), 0.0, false)
		k.layer = "base"
	return []


## Lit médicalisé (tête contre le mur, pied vers +Z local après rotation).
static func lit(k: LpKit, p: Vector3, rot: float) -> void:
	var sauve := k.xf
	k.xf = sauve * Transform3D(Basis(Vector3.UP, rot), p)
	k.box(Vector3(0, 0.3, 0), Vector3(0.95, 0.12, 2.0), INOX)
	k.box(Vector3(0, 0.45, 0.05), Vector3(0.9, 0.16, 1.9), Color("e9ecef"))
	k.box(Vector3(0, 0.55, -0.7), Vector3(0.6, 0.1, 0.35), BLANC)
	k.box(Vector3(0, 0.55, 0.3), Vector3(0.92, 0.06, 1.2), Color("a8dadc"), 0.0, false)
	k.box(Vector3(0, 0.75, -1.0), Vector3(0.95, 0.6, 0.05), INOX, 0.0, false)
	k.box(Vector3(0, 0.6, 1.0), Vector3(0.95, 0.35, 0.05), INOX, 0.0, false)
	for sx in [-0.4, 0.4]:
		for sz in [-0.9, 0.9]:
			k.box(Vector3(sx, 0.12, sz), Vector3(0.06, 0.24, 0.06), GRIS, 0.0, false)
	k.xf = sauve


static func _chambres(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var out: Array = []
	# Lits tête au mur (ouest ou est), un de plus à chaque niveau, une chaise pour la visite.
	var lits := [[1.1, 1.3, true], [5.9, 1.3, false], [1.1, 4.0, true], [5.9, 4.0, false], [1.1, 6.7, true]]
	for i in mini(1 + n, lits.size()):
		var l: Array = lits[i]
		var ouest := bool(l[2])
		lit(k, Vector3(x0 + float(l[0]), 0, z0 + float(l[1])), PI * 0.5 if ouest else -PI * 0.5)
		if i < 2:
			var cx := x0 + (2.9 if ouest else 4.1)
			var cz := z0 + float(l[1]) + 0.9
			d._chaise(k, Vector3(cx, 0, cz), PI, Color("90be6d"))
			out.append(d._place(Vector3(cx, 0, cz), PI, true))
	return out


static func _garde(d: GestionDiorama, k: LpKit, r: Array, _n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	# Petite table et chaises, tableau des bips.
	k.box(Vector3(x0 + 2.5, 0.74, z0 + 4.2), Vector3(1.2, 0.05, 0.9), Color("b08968"))
	k.box(Vector3(x0 + 2.5, 0.37, z0 + 4.2), Vector3(0.1, 0.74, 0.1), GRIS, 0.0, false)
	for sx in [-0.85, 0.85]:
		d._chaise(k, Vector3(x0 + 2.5 + sx, 0, z0 + 4.2), -PI * 0.5 if sx > 0 else PI * 0.5, Color("457b9d"))
	return []


static func _labo(_d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	# Paillasse le long du mur du fond et une îlot central.
	k.box(Vector3(x0 + 3.0, 0.45, z0 + 0.35), Vector3(5.6, 0.9, 0.6), BLANC)
	k.box(Vector3(x0 + 3.0, 0.92, z0 + 0.35), Vector3(5.7, 0.04, 0.65), Color("343a40"), 0.0, false)
	k.box(Vector3(x0 + 3.0, 0.45, z0 + 3.0), Vector3(2.6, 0.9, 1.0), BLANC)
	k.box(Vector3(x0 + 3.0, 0.92, z0 + 3.0), Vector3(2.7, 0.04, 1.05), Color("343a40"), 0.0, false)
	for i in 6 + n:
		k.lathe(Vector3(x0 + 2.0 + (i % 6) * 0.35, 0.94, z0 + 2.8 + (i / 6) * 0.3), [Vector2(0.0, 0.0), Vector2(0.03, 0.0), Vector2(0.03, 0.12), Vector2(0.0, 0.12)], 6, [Color("e63946"), Color("ffd166"), Color("8ecae6")][i % 3])
	return []


static func _jardin(d: GestionDiorama, k: LpKit, r: Array, _n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var out: Array = []
	# Allée en boucle.
	k.box(Vector3(x0 + 5.25, Y, z0 + 4.4), Vector3(9.0, 0.012, 0.9), Color("e3d5b8"), 0.0, false)
	k.box(Vector3(x0 + 1.2, Y, z0 + 2.6), Vector3(0.9, 0.012, 3.0), Color("e3d5b8"), 0.0, false)
	out.append(d._place(Vector3(x0 + 3.0, 0, z0 + 4.4), 0.0, false))
	out.append(d._place(Vector3(x0 + 7.6, 0, z0 + 4.4), PI, false))
	return out


static func _helistation(_d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	# Dalle surélevée, cercle et grand H.
	var c := Vector3(x0 + 4.5, 0, z0 + 5.0)
	k.box(c + Vector3(0, 0.15, 0), Vector3(8.4, 0.3, 8.4), Color("6c757d"))
	k.lathe(c + Vector3(0, 0.3, 0), [Vector2(3.4, 0.0), Vector2(3.7, 0.0), Vector2(3.7, 0.012), Vector2(3.4, 0.012)], 24, JAUNE)
	k.box(c + Vector3(-1.0, 0.31, 0), Vector3(0.4, 0.01, 3.0), BLANC, 0.0, false)
	k.box(c + Vector3(1.0, 0.31, 0), Vector3(0.4, 0.01, 3.0), BLANC, 0.0, false)
	k.box(c + Vector3(0, 0.31, 0), Vector3(2.0, 0.01, 0.4), BLANC, 0.0, false)
	if n >= 4:
		k.box(c + Vector3(0, 0.31, 3.0), Vector3(1.2, 0.01, 0.4), ROUGE, 0.0, false)
	return []


static func _parking(_d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	for i in 4 + mini(n, 2):
		k.box(Vector3(x0 + 0.7 + i * 1.3 * 1.25, Y + 0.002, z0 + 2.4), Vector3(0.08, 0.012, 3.6), BLANC, 0.0, false)
	k.box(Vector3(x0 + 5.0, Y + 0.002, z0 + 6.2), Vector3(9.0, 0.012, 0.12), BLANC, 0.0, false)
	k.box(Vector3(x0 + 9.6, 1.4, z0 + 9.6), Vector3(0.6, 0.6, 0.05), Color("1d4e89"), 0.0, false)
	k.box(Vector3(x0 + 9.6, 1.4, z0 + 9.63), Vector3(0.2, 0.35, 0.02), BLANC, 0.0, false)
	k.box(Vector3(x0 + 9.6, 0.55, z0 + 9.6), Vector3(0.06, 1.1, 0.06), GRIS, 0.0, false)
	return []
