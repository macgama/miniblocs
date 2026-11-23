class_name DecorsUsine
extends RefCounted
## Décors de base des pièces de l'usine (GestionDiorama les appelle par
## DecorsRestaurant → DecorsCaserne → DecorsCommissariat → DecorsHopital pour
## les décors « usine_… »). Chaque fonction meuble la pièce selon son niveau et
## renvoie les places des visiteurs ({pos, rot, assis, avant}).
## Coordonnées absolues du plan (r = [x, z, largeur, profondeur]).

const ACIER := Color("8d99a6")
const ACIER_C := Color("c3ccd4")
const GRIS := Color("5c636a")
const NOIR := Color("26262b")
const BLANC := Color("f6f4ef")
const JAUNE := Color("f2b705")
const ORANGE := Color("e76f51")
const BLEU := Color("1d6fa3")
const VERT := Color("2a9d8f")
const BOIS := Color("b08968")
const CARTON := Color("c9a46c")
const Y := 0.066


static func dessiner(d: GestionDiorama, k: LpKit, decor: String, r: Array, n: int) -> Array:
	match decor:
		"usine_accueil":
			return _accueil(d, k, r, n)
		"usine_atelier":
			return _atelier(d, k, r, n)
		"usine_chaine":
			return _chaine(d, k, r, n)
		"usine_stock":
			return _stock(d, k, r, n)
		"usine_entrepot":
			return _entrepot(d, k, r, n)
		"usine_labo":
			return _labo(d, k, r, n)
		"usine_etudes":
			return _etudes(d, k, r, n)
		"usine_refectoire":
			return _refectoire(d, k, r, n)
		"usine_direction":
			return _direction(d, k, r, n)
		"usine_showroom":
			return _showroom(d, k, r, n)
		"usine_infirmerie":
			return _infirmerie(d, k, r, n)
		"usine_quai":
			return _quai(d, k, r, n)
		"usine_epuration":
			return _epuration(d, k, r, n)
		"usine_energie":
			return _energie(d, k, r, n)
	return DecorsSupermarche.dessiner(d, k, decor, r, n)


## Bande de sécurité jaune et noire au sol.
static func _bande(k: LpKit, a: Vector3, b: Vector3, l := 0.18) -> void:
	var dlt := b - a
	var long := dlt.length()
	var nb := maxi(1, int(long / 0.5))
	for i in nb:
		var p := a + dlt * ((i + 0.5) / nb)
		var sz := Vector3(long / nb * 0.98, 0.01, l) if absf(dlt.x) > absf(dlt.z) else Vector3(l, 0.01, long / nb * 0.98)
		k.box(Vector3(p.x, Y, p.z), sz, JAUNE if i % 2 == 0 else NOIR, 0.0, false)


## Poste de travail : établi métallique avec une machine dessus.
static func _machine(k: LpKit, p: Vector3, col: Color, haute := false) -> void:
	k.box(p + Vector3(0, 0.45, 0), Vector3(1.6, 0.9, 0.8), col)
	k.box(p + Vector3(0, 0.92, 0), Vector3(1.7, 0.05, 0.9), ACIER_C, 0.0, false)
	k.box(p + Vector3(-0.3, 1.2 if not haute else 1.5, -0.1), Vector3(0.6, 0.5 if not haute else 1.1, 0.5), GRIS)
	k.tube(p + Vector3(0.35, 0.95, 0.0), p + Vector3(0.35, 1.5, -0.2), 0.05, 0.05, 4, NOIR)
	k.layer = "lumiere"
	k.box(p + Vector3(-0.3, 1.5 if not haute else 2.08, 0.16), Vector3(0.1, 0.06, 0.01), Color("57cc99"), 0.0, false)
	k.layer = "base"


static func _palette(k: LpKit, p: Vector3, col: Color, h := 0.8) -> void:
	k.box(p + Vector3(0, 0.07, 0), Vector3(1.2, 0.14, 1.0), BOIS)
	k.box(p + Vector3(0, 0.14 + h * 0.5, 0), Vector3(1.1, h, 0.9), col)
	k.box(p + Vector3(0, 0.15 + h * 0.5, 0.455), Vector3(0.4, 0.2, 0.01), BLANC, 0.0, false)


# --- Pièces ------------------------------------------------------------------------------------

static func _accueil(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var out: Array = []
	# Loge du gardien vitrée, devant la file.
	var g := Vector3(x0 + 1.6, 0, z0 + 1.95)
	k.box(g + Vector3(0, 0.55, 0), Vector3(1.8, 1.1, 0.5), GRIS)
	k.box(g + Vector3(0, 1.12, 0), Vector3(1.9, 0.05, 0.6), ACIER_C)
	k.layer = "verre"
	k.box(g + Vector3(0, 1.6, 0.0), Vector3(1.8, 0.9, 0.03), Color(0.75, 0.88, 0.95, 0.35), 0.0, false)
	k.layer = "base"
	k.box(g + Vector3(0.6, 1.2, 0.15), Vector3(0.2, 0.1, 0.25), NOIR, 0.0, false)
	# Consignes de sécurité au mur du fond (EPI obligatoires).
	for i in 3:
		k.box(Vector3(x0 + 3.4 + i * 0.5, 1.6, z0 + 0.1), Vector3(0.4, 0.4, 0.02), [Color("1d6fa3"), Color("1d6fa3"), Color("d62828")][i], 0.0, false)
	_bande(k, Vector3(x0 + 0.2, 0, z0 + 6.6), Vector3(x0 + 2.2, 0, z0 + 6.6))
	# Banc d'attente des visiteurs.
	if n >= 2:
		d._m(k, "banc", x0 + 4.4, z0 + 4.6, -PI * 0.5)
		out.append(d._place(Vector3(x0 + 4.4, 0, z0 + 4.2), -PI * 0.5, true))
		out.append(d._place(Vector3(x0 + 4.4, 0, z0 + 5.0), -PI * 0.5, true))
	if n >= 4:
		k.layer = "lumiere"
		k.box(Vector3(x0 + 3.0, 2.9, z0 + 3.5), Vector3(2.5, 0.05, 0.3), Color("f1faee"), 0.0, false)
		k.layer = "base"
	return out


static func _atelier(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var w := float(r[2])
	var out: Array = []
	# Allée piétonne peinte, des portes à la ligne de machines.
	_bande(k, Vector3(x0 + 0.4, 0, z0 + 8.6), Vector3(x0 + w - 0.4, 0, z0 + 8.6))
	if "marquage" in (d.objets.get("atelier", []) as Array):
		k.box(Vector3(x0 + w * 0.5, Y, z0 + 9.4), Vector3(w - 1.0, 0.01, 1.2), Color("2a9d8f"), 0.0, false)
		_bande(k, Vector3(x0 + 0.4, 0, z0 + 10.1), Vector3(x0 + w - 0.4, 0, z0 + 10.1))
	# Première ligne : une machine par poste (plus nombreuses à chaque niveau).
	var cols := [BLEU, Color("457b9d"), Color("2a9d8f"), Color("6d597a"), ORANGE]
	var xs := [3.2, 8.0, 12.8]
	for i in mini(n + 1, 3):
		_machine(k, Vector3(x0 + float(xs[i]), 0, z0 + 4.8), cols[i % cols.size()], n >= 4)
	# Deuxième ligne à partir du niveau 2.
	if n >= 2:
		for x in [5.0, 11.0]:
			_machine(k, Vector3(x0 + x, 0, z0 + 12.2), cols[(int(x) + n) % cols.size()], n >= 5)
	# Bacs de pièces et palettes entre les machines.
	for i in mini(n, 3):
		k.box(Vector3(x0 + 5.6 + i * 4.8, 0.3, z0 + 6.2), Vector3(0.6, 0.6, 0.5), ORANGE if i % 2 == 0 else BLEU)
	if n >= 3:
		_palette(k, Vector3(x0 + 1.2, 0, z0 + 2.0), CARTON, 0.6)
	# Éclairage industriel.
	if n >= 2:
		k.layer = "lumiere"
		for i in 3:
			k.box(Vector3(x0 + 3.0 + i * 5.0, 3.9, z0 + 8.0), Vector3(1.4, 0.06, 0.3), Color("f1faee"), 0.0, false)
		k.layer = "base"
	# Visiteurs : derrière la ligne jaune, près de la porte.
	out.append(d._place(Vector3(x0 + w - 1.0, 0, z0 + 9.0), -PI * 0.5, false))
	out.append(d._place(Vector3(x0 + w - 2.4, 0, z0 + 9.3), PI, false))
	out.append(d._place(Vector3(x0 + w - 1.0, 0, z0 + 14.6), -PI * 0.5, false))
	return out


static func _chaine(_d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var w := float(r[2])
	# Grillage de sécurité autour des robots, avec un passage à la porte.
	for i in 8:
		var x := x0 + 0.5 + i * 2.0
		if absf(x + 1.0 - (x0 + 8.0)) < 1.2:
			continue
		k.box(Vector3(x + 1.0, 0.9, z0 + 5.6), Vector3(1.9, 1.8, 0.03), Color("ffd166") if i % 2 == 0 else Color("e9c46a"), 0.0, false)
	_bande(k, Vector3(x0 + 0.4, 0, z0 + 4.2), Vector3(x0 + w - 0.4, 0, z0 + 4.2))
	if n >= 2:
		k.layer = "lumiere"
		for i in 4:
			k.box(Vector3(x0 + 2.0 + i * 4.0, 3.2, z0 + 3.0), Vector3(0.3, 0.06, 1.4), Color("caf0f8"), 0.0, false)
		k.layer = "base"
	if n >= 4:
		# Feu de signalisation de la ligne : vert = tout va bien.
		k.box(Vector3(x0 + w - 0.4, 1.4, z0 + 0.3), Vector3(0.12, 2.8, 0.12), GRIS, 0.0, false)
		k.layer = "lumiere"
		k.box(Vector3(x0 + w - 0.4, 2.9, z0 + 0.3), Vector3(0.2, 0.2, 0.2), Color("57cc99"), 0.0, false)
		k.layer = "base"
	return []


static func _stock(_d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	# Matières premières en vrac et sur palettes, selon le niveau.
	_palette(k, Vector3(x0 + 2.4, 0, z0 + 8.2), Color("a3b18a"), 0.7)
	if n >= 2:
		_palette(k, Vector3(x0 + 1.3, 0, z0 + 8.2), Color("d8c3a5"), 0.9)
	if n >= 3:
		k.box(Vector3(x0 + 3.0, 0.4, z0 + 1.8), Vector3(1.2, 0.8, 0.9), Color("adb5bd"))
		k.box(Vector3(x0 + 3.0, 0.82, z0 + 1.8), Vector3(1.0, 0.04, 0.7), Color("6c757d"), 0.0, false)
	_bande(k, Vector3(x0 + 1.5, 0, z0 + 0.4), Vector3(x0 + 1.5, 0, z0 + 8.6), 0.12)
	return []


static func _entrepot(_d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	_palette(k, Vector3(x0 + 5.0, 0, z0 + 6.2), ORANGE, 0.8)
	_palette(k, Vector3(x0 + 2.0, 0, z0 + 6.2), CARTON, 0.6 + 0.15 * mini(n, 4))
	if n >= 3:
		_palette(k, Vector3(x0 + 5.0, 0, z0 + 2.6), CARTON, 1.0)
	_bande(k, Vector3(x0 + 0.4, 0, z0 + 5.3), Vector3(x0 + 6.0, 0, z0 + 5.3), 0.12)
	return []


static func _labo(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	# Paillasse centrale blanche, fioles colorées.
	var p := Vector3(x0 + 2.8, 0, z0 + 3.4)
	k.box(p + Vector3(0, 0.45, 0), Vector3(1.6, 0.9, 0.7), BLANC)
	k.box(p + Vector3(0, 0.92, 0), Vector3(1.7, 0.04, 0.8), Color("343a40"), 0.0, false)
	for i in 2 + mini(n, 3):
		k.lathe(p + Vector3(-0.6 + i * 0.3, 0.94, 0.1), [Vector2(0.0, 0.0), Vector2(0.06, 0.0), Vector2(0.02, 0.14), Vector2(0.02, 0.2), Vector2(0.0, 0.2)], 6,
			[Color("90e0ef"), Color("ffafcc"), Color("caffbf"), Color("ffd6a5"), Color("bdb2ff")][i % 5])
	# Blouses accrochées.
	for i in 2:
		k.box(Vector3(x0 + 5.85, 1.4, z0 + 5.2 - i * 0.5), Vector3(0.06, 0.9, 0.4), BLANC, 0.0, false)
	if n >= 3:
		k.layer = "lumiere"
		k.box(Vector3(x0 + 3.0, 2.8, z0 + 3.0), Vector3(1.6, 0.05, 0.4), Color("f1faee"), 0.0, false)
		k.layer = "base"
	return [d._place(Vector3(x0 + 2.6, 0, z0 + 4.5), PI, false), d._place(Vector3(x0 + 3.4, 0, z0 + 4.5), PI, false)]


static func _etudes(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var out: Array = []
	# Petite table de réunion et plans au mur.
	var t := Vector3(x0 + 1.6, 0, z0 + 4.4)
	d._table_ronde(k, t, 0.55, Color("e9ecef"))
	for c in [[Vector3(-0.8, 0, 0), PI * 0.5], [Vector3(0.8, 0, 0), -PI * 0.5]]:
		d._chaise(k, t + (c[0] as Vector3), float(c[1]), Color("457b9d"))
		out.append(d._place(t + (c[0] as Vector3), float(c[1]), true))
	k.box(t + Vector3(0, 0.77, 0), Vector3(0.5, 0.01, 0.35), Color("bde0fe"), 0.0, false)
	for i in 2 + mini(n, 2):
		k.box(Vector3(x0 + 0.1, 1.5, z0 + 1.0 + i * 0.9), Vector3(0.02, 0.6, 0.8), Color("caf0f8") if i % 2 == 0 else BLANC, 0.0, false)
	return out


static func _refectoire(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var out: Array = []
	var tables := [Vector3(x0 + 2.4, 0, z0 + 5.4), Vector3(x0 + 4.6, 0, z0 + 5.4)]
	if n >= 3:
		tables.append(Vector3(x0 + 2.4, 0, z0 + 7.4))
	for t in tables:
		k.box(t + Vector3(0, 0.74, 0), Vector3(1.2, 0.05, 0.8), Color("e9c46a"))
		k.box(t + Vector3(0, 0.37, 0), Vector3(0.08, 0.74, 0.08), GRIS, 0.0, false)
		for c in [[Vector3(-0.75, 0, 0), PI * 0.5], [Vector3(0.75, 0, 0), -PI * 0.5]]:
			d._chaise(k, t + (c[0] as Vector3), float(c[1]), Color("e76f51"))
			out.append(d._place(t + (c[0] as Vector3), float(c[1]), true))
	if n >= 2:
		d._m(k, "plante", x0 + 6.4, z0 + 6.4)
	return out


static func _direction(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var out: Array = []
	DecorsCaserne._poste(d, k, Vector3(x0 + 3.5, 0, z0 + 1.9), 2 if n >= 3 else 1, BOIS if n >= 3 else Color("d9d4c7"))
	for x in [3.0, 4.0]:
		d._chaise(k, Vector3(x0 + x, 0, z0 + 3.8), PI, Color("6c757d"))
		out.append(d._place(Vector3(x0 + x, 0, z0 + 3.8), PI, true))
	if n >= 4:
		d._m(k, "plante_grande", x0 + 0.6, z0 + 5.4)
	return out


static func _showroom(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var out: Array = []
	# Comptoir de vente.
	var c := Vector3(x0 + 3.5, 0, z0 + 1.7)
	k.box(c + Vector3(0, 0.5, 0), Vector3(1.8, 1.0, 0.5), BOIS)
	k.box(c + Vector3(0, 1.02, 0), Vector3(1.9, 0.04, 0.6), BLANC, 0.0, false)
	k.box(c + Vector3(0.6, 1.1, 0), Vector3(0.3, 0.12, 0.25), NOIR, 0.0, false)
	out.append(d._place(c + Vector3(-0.5, 0, 0.9), PI, false))
	out.append(d._place(c + Vector3(0.5, 0, 0.9), PI, false))
	# Podiums de produits (palettes décorées).
	for i in mini(n, 3):
		var p := Vector3(x0 + 1.4 + i * 2.0, 0, z0 + 3.6)
		if i == 1:
			continue
		k.box(p + Vector3(0, 0.15, 0), Vector3(1.0, 0.3, 1.0), Color("343a40"))
		k.box(p + Vector3(0, 0.5, 0), Vector3(0.6, 0.4, 0.5), ORANGE if i == 0 else BLEU)
		out.append(d._place(p + Vector3(0, 0, 0.9), PI, false))
	if n >= 3:
		k.layer = "lumiere"
		k.box(Vector3(x0 + 3.5, 2.9, z0 + 3.5), Vector3(3.0, 0.05, 0.2), Color("fff3b0"), 0.0, false)
		k.layer = "base"
	return out


static func _infirmerie(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	k.box(Vector3(x0 + 3.5, 0.37, z0 + 1.9), Vector3(1.4, 0.74, 0.6), BLANC)
	# Armoire à pharmacie, croix verte.
	k.box(Vector3(x0 + 1.6, 1.4, z0 + 0.2), Vector3(0.8, 0.8, 0.3), BLANC)
	k.box(Vector3(x0 + 1.6, 1.4, z0 + 0.36), Vector3(0.3, 0.1, 0.01), VERT, 0.0, false)
	k.box(Vector3(x0 + 1.6, 1.4, z0 + 0.36), Vector3(0.1, 0.3, 0.01), VERT, 0.0, false)
	if n >= 3:
		d._chaise(k, Vector3(x0 + 4.4, 0, z0 + 4.4), PI, Color("90be6d"))
	return []


static func _quai(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var w := float(r[2])
	var dp := float(r[3])
	var out: Array = []
	# Dalle du quai et portes sectionnelles (une de plus par niveau, jusqu'à 3).
	k.box(Vector3(x0 + w * 0.5, 0.06, z0 + 0.55), Vector3(w, 0.12, 1.1), Color("adb5bd"), 0.0, false)
	var nb := mini(n, 3)
	for i in nb:
		var x := x0 + 3.0 + i * 4.5
		k.box(Vector3(x, 1.6, z0 + 0.05), Vector3(2.8, 3.2, 0.1), GRIS)
		for j in 6:
			k.box(Vector3(x, 0.3 + j * 0.5, z0 + 0.11), Vector3(2.6, 0.04, 0.02), ACIER_C, 0.0, false)
		k.layer = "lumiere"
		k.box(Vector3(x + 1.6, 2.6, z0 + 0.12), Vector3(0.14, 0.14, 0.02), Color("ff4d4d") if i == 1 else Color("57cc99"), 0.0, false)
		k.layer = "base"
	# Marquage des places de camions.
	for i in nb + 1:
		k.box(Vector3(x0 + 0.75 + i * 4.5, 0.05, z0 + dp * 0.55), Vector3(0.12, 0.01, dp * 0.8), JAUNE, 0.0, false)
	out.append(d._place(Vector3(x0 + 10.0, 0, z0 + 1.8), PI, false))
	out.append(d._place(Vector3(x0 + 9.0, 0, z0 + 2.2), PI * 0.8, false))
	out.append(d._place(Vector3(x0 + 4.0, 0, z0 + 1.8), PI, false))
	return out


static func _epuration(_d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var w := float(r[2])
	var dp := float(r[3])
	# Clôture et canalisations qui viennent de l'usine.
	for i in int(w / 1.5):
		k.box(Vector3(x0 + 0.75 + i * 1.5, 0.6, z0 + dp - 0.1), Vector3(1.4, 1.2, 0.03), Color("adb5bd"), 0.0, false)
	k.tube(Vector3(x0 - 2.0, 0.4, z0 + 4.5), Vector3(x0 + 3.6, 0.4, z0 + 4.5), 0.18, 0.18, 6, Color("6c757d"))
	if n >= 3:
		k.tube(Vector3(x0 - 2.0, 1.0, z0 + 1.0), Vector3(x0 + 1.0, 1.0, z0 + 1.0), 0.14, 0.14, 6, VERT)
	return []


static func _energie(_d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	# Local technique et transformateur.
	k.box(Vector3(x0 + 9.2, 1.1, z0 + 9.6), Vector3(2.6, 2.2, 2.0), Color("adb5bd"))
	k.box(Vector3(x0 + 9.2, 1.0, z0 + 10.61), Vector3(0.9, 1.8, 0.02), GRIS, 0.0, false)
	k.box(Vector3(x0 + 9.6, 1.7, z0 + 10.62), Vector3(0.3, 0.3, 0.01), JAUNE, 0.0, false)
	if n >= 2:
		k.tube(Vector3(x0 - 2.0, 2.6, z0 + 9.6), Vector3(x0 + 8.0, 2.6, z0 + 9.6), 0.08, 0.08, 4, NOIR)
	return []
