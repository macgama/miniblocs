class_name DecorsParc
extends RefCounted
## Décors de base des zones du parc de loisirs (GestionDiorama les appelle au
## bout de la chaîne DecorsRestaurant → … → DecorsHopital pour les décors
## « parc_… »). Chaque fonction aménage la zone selon son niveau et renvoie
## les places des visiteurs ({pos, rot, assis, avant}). Les vraies
## attractions du parc sont posées à part, en miniature
## (GestionDiorama._miniatures).
## Coordonnées absolues du plan (r = [x, z, largeur, profondeur]).

const ROUGE := Color("d62828")
const JAUNE := Color("ffc93c")
const BLEU := Color("277da1")
const VERT := Color("43aa8b")
const ROSE := Color("f78fb3")
const VIOLET := Color("7b2cbf")
const ORANGE := Color("f77f00")
const BLANC := Color("f8f4ea")
const BOIS := Color("9c6644")
const METAL := Color("adb5bd")
const GRIS := Color("5c636a")
const NOIR := Color("26262b")
const VIFS := [Color("d62828"), Color("ffc93c"), Color("277da1"), Color("43aa8b"), Color("f78fb3"), Color("7b2cbf"), Color("f77f00"), Color("4cc9f0")]
const Y := 0.066


static func dessiner(d: GestionDiorama, k: LpKit, decor: String, r: Array, n: int) -> Array:
	match decor:
		"parc_accueil":
			return _accueil(d, k, r, n)
		"parc_direction":
			return _direction(d, k, r, n)
		"parc_infirmerie":
			return _infirmerie(d, k, r, n)
		"parc_manege":
			return _zone_attractions(d, k, r, n, "MANÈGES", [ROUGE, JAUNE], false)
		"parc_sensations":
			return _zone_attractions(d, k, r, n, "GRANDS FRISSONS", [VIOLET, NOIR], false)
		"parc_aquatique":
			return _zone_attractions(d, k, r, n, "RIVIÈRE", [BLEU, Color("4cc9f0")], true)
		"parc_enfants":
			return _enfants(d, k, r, n)
		"parc_restauration":
			return _restauration(d, k, r, n)
		"parc_boutique":
			return _boutique(d, k, r, n)
		"parc_spectacles":
			return _spectacles(d, k, r, n)
		"parc_toilettes":
			return _toilettes(d, k, r, n)
		"parc_atelier":
			return _atelier(d, k, r, n)
		"parc_parking":
			return _parking(d, k, r, n)
	return DecorsAuto.dessiner(d, k, decor, r, n)


# --- Petits éléments ---------------------------------------------------------------------------

## Poteau et corde de file d'attente.
static func _potelet(k: LpKit, p: Vector3, col: Color) -> void:
	k.tube(p, p + Vector3(0, 0.95, 0), 0.04, 0.04, 6, METAL)
	k.lathe(p, [Vector2(0.0, 0.0), Vector2(0.14, 0.0), Vector2(0.14, 0.04), Vector2(0.0, 0.04)], 8, GRIS)
	k.blob(p + Vector3(0, 0.98, 0), Vector3(0.06, 0.06, 0.06), col, col, 0.0, 0)


static func _corde(k: LpKit, a: Vector3, b: Vector3, col: Color) -> void:
	k.beam(a + Vector3(0, 0.82, 0), b + Vector3(0, 0.82, 0), 0.05, 0.05, col)


## Fanions en guirlande entre deux mâts.
static func fanions(k: LpKit, a: Vector3, b: Vector3, h: float, nb: int) -> void:
	k.tube(a, a + Vector3(0, h + 0.2, 0), 0.05, 0.05, 6, BLANC)
	k.tube(b, b + Vector3(0, h + 0.2, 0), 0.05, 0.05, 6, BLANC)
	k.beam(a + Vector3(0, h, 0), b + Vector3(0, h, 0), 0.02, 0.02, GRIS)
	for i in nb:
		var t := (i + 0.5) / float(nb)
		var p := a.lerp(b, t) + Vector3(0, h - 0.06 - 0.25 * sin(t * PI) * 0.4, 0)
		var dir := (b - a).normalized()
		var c: Color = VIFS[i % VIFS.size()]
		k.tri(p - dir * 0.16, p + dir * 0.16, p + Vector3(0, -0.34, 0), c, Vector3(dir.z, 0, -dir.x))
		k.tri(p + dir * 0.16, p - dir * 0.16, p + Vector3(0, -0.34, 0), c, Vector3(-dir.z, 0, dir.x))


## Portique d'entrée d'une zone, avec son nom.
static func portique(d: GestionDiorama, k: LpKit, c: Vector3, larg: float, cols: Array, texte: String) -> void:
	for sx in [-0.5, 0.5]:
		var p := c + Vector3(sx * larg, 0, 0)
		k.box(p + Vector3(0, 1.3, 0), Vector3(0.35, 2.6, 0.35), cols[0])
		k.lathe(p + Vector3(0, 2.6, 0), [Vector2(0.0, 0.0), Vector2(0.28, 0.0), Vector2(0.0, 0.5)], 8, cols[1])
	k.box(c + Vector3(0, 2.45, 0), Vector3(larg + 0.2, 0.55, 0.2), cols[1])
	k.box(c + Vector3(0, 2.45, 0.11), Vector3(larg - 0.3, 0.38, 0.02), BLANC, 0.0, false)
	d.texte_sol(c + Vector3(0, 2.45, 0.14), texte, cols[0].darkened(0.3))


## Lampadaire du parc (boule blanche, allumée la nuit).
static func reverbere(k: LpKit, p: Vector3) -> void:
	k.tube(p, p + Vector3(0, 2.6, 0), 0.06, 0.05, 6, Color("2d3a3a"))
	k.layer = "lumiere"
	k.blob(p + Vector3(0, 2.75, 0), Vector3(0.2, 0.2, 0.2), Color("fff3c4"), Color("fff3c4"), 0.0, 0)
	k.layer = "base"


static func massif(k: LpKit, p: Vector3, l: float) -> void:
	k.box(p + Vector3(0, 0.15, 0), Vector3(l, 0.3, 0.7), Color("8d6e63"))
	var nb := maxi(2, int(l / 0.45))
	for i in nb:
		var x := -l * 0.5 + (i + 0.5) * l / nb
		k.blob(p + Vector3(x, 0.42, 0), Vector3(0.22, 0.2, 0.22), Color("2f6b35"), [ROUGE, JAUNE, ROSE, ORANGE][i % 4], 0.2, 0)


static func poubelle(k: LpKit, p: Vector3) -> void:
	k.lathe(p, [Vector2(0.0, 0.0), Vector2(0.22, 0.0), Vector2(0.25, 0.75), Vector2(0.0, 0.75)], 8, VERT.darkened(0.2))
	k.box(p + Vector3(0, 0.78, 0), Vector3(0.36, 0.05, 0.36), GRIS, 0.0, false)


# --- Bâtiment de l'entrée ------------------------------------------------------------------------

static func _accueil(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	# Guichets vitrés (un de plus par niveau, jusqu'à 4).
	var nb := mini(1 + n, 4)
	k.box(Vector3(x0 + 4.5, 0.55, z0 + 2.3), Vector3(7.6, 1.1, 0.5), Color("c1440e"))
	k.box(Vector3(x0 + 4.5, 1.13, z0 + 2.3), Vector3(7.8, 0.06, 0.62), Color("f2e8cf"))
	for i in nb:
		var x := x0 + 1.4 + i * (6.2 / maxf(1.0, float(nb - 1)) if nb > 1 else 0.0)
		if nb == 1:
			x = x0 + 4.5
		k.layer = "verre"
		k.box(Vector3(x, 1.6, z0 + 2.3), Vector3(1.2, 0.9, 0.03), Color(0.7, 0.85, 0.95, 0.5), 0.0, false)
		k.layer = "base"
		k.box(Vector3(x, 2.1, z0 + 2.3), Vector3(1.3, 0.1, 0.1), JAUNE, 0.0, false)
		k.box(Vector3(x, 1.18, z0 + 2.15), Vector3(0.3, 0.03, 0.2), NOIR, 0.0, false)
	# Tourniquets (le passage du milieu reste libre pour la file).
	for x in [x0 + 1.6, x0 + 2.8, x0 + 6.2, x0 + 7.4]:
		k.box(Vector3(x, 0.45, z0 + 6.2), Vector3(0.3, 0.9, 0.8), METAL)
		for j in 3:
			var a := j * TAU / 3.0
			k.beam(Vector3(x + 0.15, 0.85, z0 + 6.2), Vector3(x + 0.15 + 0.5 * cos(a) * 0.6, 0.85 + 0.2 * sin(a), z0 + 6.2 + 0.5 * sin(a) * 0.6), 0.04, 0.04, GRIS)
	# Panneau des tarifs au mur du fond.
	k.box(Vector3(x0 + 4.5, 2.2, z0 + 0.12), Vector3(3.0, 1.0, 0.05), Color("1d3557"), 0.0, false)
	for i in 4:
		k.box(Vector3(x0 + 3.4 + (i % 2) * 2.1, 2.42 - (i / 2) * 0.4, z0 + 0.15), Vector3(1.6, 0.12, 0.02), BLANC, 0.0, false)
	if n >= 3:
		fanions(k, Vector3(x0 + 0.4, 0, z0 + 9.7), Vector3(x0 + 8.6, 0, z0 + 9.7), 2.6, 12)
	if n >= 4:
		d._m(k, "plante_grande", x0 + 0.6, z0 + 9.3)
		d._m(k, "plante_grande", x0 + 8.4, z0 + 9.3)
	return []


static func _direction(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	k.box(Vector3(x0 + 2.5, 0.37, z0 + 2.3), Vector3(1.8, 0.74, 0.8), BOIS)
	k.box(Vector3(x0 + 2.5, 0.76, z0 + 2.3), Vector3(1.9, 0.04, 0.9), BOIS.lightened(0.2), 0.0, false)
	d._chaise(k, Vector3(x0 + 2.5, 0, z0 + 1.5), 0.0, Color("2b2d42"))
	d._chaise(k, Vector3(x0 + 2.0, 0, z0 + 3.3), PI, Color("6d597a"))
	d._chaise(k, Vector3(x0 + 3.0, 0, z0 + 3.3), PI, Color("6d597a"))
	if n >= 2:
		d._m(k, "plante", x0 + 0.5, z0 + 4.4)
	if n >= 3:
		# Grande affiche du parc.
		k.box(Vector3(x0 + 0.12, 1.7, z0 + 2.0), Vector3(0.05, 1.0, 1.5), JAUNE, 0.0, false)
		k.box(Vector3(x0 + 0.15, 1.7, z0 + 2.0), Vector3(0.02, 0.6, 1.0), ROUGE, 0.0, false)
	return [d._place(Vector3(x0 + 2.0, 0, z0 + 3.3), PI, true), d._place(Vector3(x0 + 3.0, 0, z0 + 3.3), PI, true)]


static func _infirmerie(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	# Armoire à pharmacie et croix verte.
	k.box(Vector3(x0 + 2.5, 0.9, z0 + 0.3), Vector3(1.6, 1.8, 0.45), BLANC)
	k.box(Vector3(x0 + 2.5, 1.95, z0 + 0.08), Vector3(0.5, 0.16, 0.02), VERT, 0.0, false)
	k.box(Vector3(x0 + 2.5, 1.95, z0 + 0.08), Vector3(0.16, 0.5, 0.02), VERT, 0.0, false)
	d._chaise(k, Vector3(x0 + 1.4, 0, z0 + 4.4), PI, Color("90be6d"))
	d._chaise(k, Vector3(x0 + 2.0, 0, z0 + 4.4), PI, Color("90be6d"))
	if n >= 3:
		d._m(k, "plante", x0 + 4.5, z0 + 4.5)
	return [d._place(Vector3(x0 + 1.4, 0, z0 + 4.4), PI, true), d._place(Vector3(x0 + 2.0, 0, z0 + 4.4), PI, true)]


# --- Zones des attractions (rangée du fond) --------------------------------------------------------

## Manèges, grands frissons, rivière : l'emplacement des attractions au fond
## (GestionDiorama._miniatures), la file d'attente en zigzag devant, le
## portique sur l'allée. Plus de niveau : files plus longues et mieux tenues,
## lampadaires, massifs, fanions.
static func _zone_attractions(d: GestionDiorama, k: LpKit, r: Array, n: int, nom: String, cols: Array, eau: bool) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var w := float(r[2])
	var dp := float(r[3])
	var out: Array = []
	# Le terrain des attractions : gazon (ou plage pour l'aquatique).
	var fond := Color("e9d8a6") if eau else Color("7fb069")
	k.box(Vector3(x0 + w * 0.5, Y + 0.004, z0 + 4.5), Vector3(w - 0.6, 0.01, 8.4), fond, 0.0, false)
	if eau:
		# Bassin bleu derrière les attractions.
		k.layer = "eau"
		k.box(Vector3(x0 + w * 0.5, Y + 0.012, z0 + 1.0), Vector3(w - 1.2, 0.02, 1.2), Color(0.25, 0.6, 0.85, 0.8), 0.0, false)
		k.layer = "base"
	# Bordure.
	k.box(Vector3(x0 + w * 0.5, 0.12, z0 + 8.75), Vector3(w - 0.6, 0.18, 0.12), BLANC.darkened(0.15), 0.0, false)
	# File d'attente en zigzag (rangées de potelets ; une de plus par niveau, jusqu'à 3).
	var rangs := mini(1 + n / 2, 3)
	var xa := x0 + 1.6
	var xb := x0 + w - 1.6
	for i in rangs:
		var z := z0 + 9.8 + i * 1.1
		var nbp := int((xb - xa) / 1.6) + 1
		for j in nbp:
			var x := xa + j * (xb - xa) / maxf(1.0, nbp - 1)
			_potelet(k, Vector3(x, 0, z), cols[0])
			if j > 0:
				_corde(k, Vector3(x - (xb - xa) / maxf(1.0, nbp - 1), 0, z), Vector3(x, 0, z), cols[0] if n >= 3 else ROUGE.darkened(0.2))
	# Places dans la file (debout, regardant les attractions).
	for i in rangs:
		var z := z0 + 9.25 + i * 1.1
		for j in 6:
			out.append(d._place(Vector3(xa + 0.8 + j * (xb - xa - 1.6) / 5.0, 0, z), PI, false))
	# Portique sur l'allée.
	portique(d, k, Vector3(x0 + w * 0.5, 0, z0 + dp - 0.35), 2.8, cols, nom)
	if n >= 2:
		reverbere(k, Vector3(x0 + 0.5, 0, z0 + dp - 0.5))
		reverbere(k, Vector3(x0 + w - 0.5, 0, z0 + dp - 0.5))
	if n >= 3:
		massif(k, Vector3(x0 + w * 0.5 - 3.4, 0, z0 + dp - 0.55), 2.4)
		massif(k, Vector3(x0 + w * 0.5 + 3.4, 0, z0 + dp - 0.55), 2.4)
	if n >= 4:
		fanions(k, Vector3(x0 + 0.4, 0, z0 + 8.9), Vector3(x0 + w - 0.4, 0, z0 + 8.9), 3.0, int(w / 0.8))
	if n >= 5:
		poubelle(k, Vector3(x0 + 1.0, 0, z0 + dp - 1.4))
		poubelle(k, Vector3(x0 + w - 1.0, 0, z0 + dp - 1.4))
	return out


# --- Zones de la rangée de devant ------------------------------------------------------------------

static func _enfants(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var out: Array = []
	# Sol souple de couleur sous les attractions des petits.
	for i in 4:
		k.box(Vector3(x0 + 4.8 + i * 1.5, Y + 0.004, z0 + 6.4), Vector3(1.45, 0.01, 5.8), [ROSE, JAUNE, Color("4cc9f0"), VERT][i], 0.0, false)
	# Petite barrière en bois tout autour.
	for i in 12:
		var x := x0 + 0.4 + i * 0.9
		k.box(Vector3(x, 0.3, z0 + 9.7), Vector3(0.08, 0.6, 0.08), BOIS)
	k.beam(Vector3(x0 + 0.4, 0.5, z0 + 9.7), Vector3(x0 + 10.3, 0.5, z0 + 9.7), 0.06, 0.05, VIFS[n % VIFS.size()])
	portique(d, k, Vector3(x0 + 5.5, 0, z0 + 0.35), 2.4, [ROSE, JAUNE], "LES PETITS")
	for i in 3:
		out.append(d._place(Vector3(x0 + 1.8 + i * 3.2, 0, z0 + 3.0), PI * (0.9 + 0.1 * i), false))
	out.append(d._place(Vector3(x0 + 3.4, 0, z0 + 6.6), PI * 0.5, false))
	if n >= 2:
		d._m(k, "banc", x0 + 9.6, z0 + 3.0, -PI * 0.5)
		out.append(d._place(Vector3(x0 + 9.4, 0, z0 + 3.0), -PI * 0.5, true))
	if n >= 4:
		fanions(k, Vector3(x0 + 0.4, 0, z0 + 0.8), Vector3(x0 + 10.6, 0, z0 + 0.8), 2.4, 12)
	return out


static func _restauration(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var out: Array = []
	# Kiosque de base (toujours là) : la buvette.
	var b := Vector3(x0 + 10.2, 0, z0 + 1.6)
	k.box(b + Vector3(0, 0.55, 0), Vector3(2.0, 1.1, 1.1), Color("e9c46a"))
	k.box(b + Vector3(0, 1.12, 0.1), Vector3(2.1, 0.05, 1.3), Color("f2e8cf"))
	k.box(b + Vector3(0, 2.15, 0), Vector3(2.2, 0.12, 1.4), ROUGE)
	for i in 5:
		k.box(b + Vector3(-0.88 + i * 0.44, 1.95, 0.7), Vector3(0.42, 0.3, 0.02), ROUGE if i % 2 == 0 else BLANC, 0.0, false)
	k.box(b + Vector3(-1.0, 1.6, 0), Vector3(0.08, 1.0, 0.08), BOIS)
	k.box(b + Vector3(1.0, 1.6, 0), Vector3(0.08, 1.0, 0.08), BOIS)
	k.box(b + Vector3(0, 2.4, 0), Vector3(1.4, 0.35, 0.08), BLEU, 0.0, false)
	# Clients au comptoir.
	for x in [x0 + 2.0, x0 + 6.0, x0 + 9.6, x0 + 10.6]:
		out.append(d._place(Vector3(x, 0, z0 + 3.1), PI, false))
	# Bancs devant (et plus de bancs avec les niveaux).
	for i in mini(n, 3):
		var p := Vector3(x0 + 1.6 + i * 3.6, 0, z0 + 9.2)
		d._m(k, "banc", p.x, p.z, PI)
		out.append(d._place(p + Vector3(0, 0, 0.15), PI, true))
	if n >= 2:
		fanions(k, Vector3(x0 + 0.4, 0, z0 + 4.4), Vector3(x0 + 11.6, 0, z0 + 4.4), 2.8, 14)
	if n >= 3:
		poubelle(k, Vector3(x0 + 11.4, 0, z0 + 9.3))
		poubelle(k, Vector3(x0 + 0.6, 0, z0 + 4.8))
	if n >= 4:
		# Fontaine au milieu de la place.
		var f := Vector3(x0 + 5.2, 0, z0 + 8.6)
		k.lathe(f, [Vector2(0.0, 0.0), Vector2(0.8, 0.0), Vector2(0.8, 0.35), Vector2(0.7, 0.35), Vector2(0.0, 0.3)], 12, Color("c9c2b4"))
		k.layer = "eau"
		k.lathe(f + Vector3(0, 0.31, 0), [Vector2(0.0, 0.0), Vector2(0.68, 0.0), Vector2(0.0, 0.02)], 12, Color(0.3, 0.6, 0.85, 0.8))
		k.layer = "base"
		k.tube(f, f + Vector3(0, 1.0, 0), 0.08, 0.06, 6, Color("c9c2b4"))
	return out


static func _boutique(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var w := float(r[2])
	var dp := float(r[3])
	var mur := Color("f4a261")
	# Murs bas (on voit dedans), ouverts sur l'allée.
	k.box(Vector3(x0 + 0.1, 0.45, z0 + dp * 0.5), Vector3(0.2, 0.9, dp), mur)
	k.box(Vector3(x0 + w - 0.1, 0.45, z0 + dp * 0.5), Vector3(0.2, 0.9, dp), mur)
	k.box(Vector3(x0 + w * 0.5, 0.45, z0 + dp - 0.1), Vector3(w, 0.9, 0.2), mur)
	for x in [x0 + 0.1, x0 + w - 0.1]:
		k.box(Vector3(x, 1.2, z0 + 0.2), Vector3(0.3, 2.4, 0.3), mur.darkened(0.2))
	# Auvent rayé et enseigne.
	for i in int(w / 0.5):
		k.box(Vector3(x0 + 0.25 + i * 0.5, 2.35, z0 + 0.4), Vector3(0.5, 0.08, 0.9), ROUGE if i % 2 == 0 else BLANC, 0.0, false)
	k.box(Vector3(x0 + w * 0.5, 2.7, z0 + 0.2), Vector3(3.4, 0.5, 0.1), BLEU, 0.0, false)
	d.texte_sol(Vector3(x0 + w * 0.5, 2.7, z0 + 0.27), "SOUVENIRS", BLANC)
	# Comptoir et caisse.
	k.box(Vector3(x0 + 6.6, 0.5, z0 + 6.4), Vector3(0.6, 1.0, 2.0), BOIS)
	k.box(Vector3(x0 + 6.6, 1.05, z0 + 6.0), Vector3(0.35, 0.12, 0.3), NOIR, 0.0, false)
	var out: Array = []
	for z in [z0 + 2.2, z0 + 5.0, z0 + 7.8]:
		out.append(d._place(Vector3(x0 + 2.6, 0, z), -PI * 0.5 if z < z0 + 5.0 else PI * 0.5, false))
	out.append(d._place(Vector3(x0 + 5.6, 0, z0 + 6.4), PI * 0.5, false))
	if n >= 3:
		d._m(k, "plante", x0 + 0.6, z0 + 0.8)
	return out


static func _spectacles(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var out: Array = []
	# Scène surélevée côté allée, tournée vers le public.
	var c := Vector3(x0 + 8.0, 0, z0 + 2.0)
	k.box(c + Vector3(0, 0.3, 0), Vector3(9.0, 0.6, 3.4), Color("5c4033"))
	k.box(c + Vector3(0, 0.62, 0), Vector3(8.8, 0.04, 3.2), Color("8d6748"), 0.0, false)
	# Décor de fond et rideaux (rouges, puis velours au niveau 3).
	var rideau := Color("9d0208") if n >= 3 else ROUGE
	k.box(c + Vector3(0, 2.3, -1.6), Vector3(9.0, 3.4, 0.15), Color("1d3557"))
	for sx in [-1.0, 1.0]:
		k.box(c + Vector3(sx * 4.0, 2.2, -1.3), Vector3(1.0, 3.2, 0.2), rideau)
	k.box(c + Vector3(0, 3.9, -1.3), Vector3(9.2, 0.35, 0.3), rideau.darkened(0.2))
	k.layer = "lumiere"
	for i in 5:
		k.box(c + Vector3(-3.0 + i * 1.5, 0.66, 1.55), Vector3(0.3, 0.06, 0.1), Color("fff3c4"), 0.0, false)
	k.layer = "base"
	# Bancs du public (si pas de gradins).
	for i in 2:
		for j in 2:
			var p := Vector3(x0 + 4.0 + i * 8.0, 0, z0 + 6.0 + j * 1.6)
			d._m(k, "banc", p.x - 0.9, p.z, PI)
			d._m(k, "banc", p.x + 0.9, p.z, PI)
			out.append(d._place(p + Vector3(-0.9, 0, 0.1), PI, true))
			out.append(d._place(p + Vector3(0.9, 0, 0.1), PI, true))
	if n >= 2:
		fanions(k, Vector3(x0 + 0.4, 0, z0 + 4.6), Vector3(x0 + 15.6, 0, z0 + 4.6), 3.2, 18)
	if n >= 4:
		reverbere(k, Vector3(x0 + 0.5, 0, z0 + 9.4))
		reverbere(k, Vector3(x0 + 15.5, 0, z0 + 9.4))
	return out


# --- Services ----------------------------------------------------------------------------------

static func _toilettes(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var w := float(r[2])
	# Petit bâtiment carrelé, deux portes (une de plus au niveau 3).
	k.box(Vector3(x0 + w * 0.5, 1.2, z0 + 1.8), Vector3(w - 0.4, 2.4, 3.2), Color("dfe7ec"))
	k.box(Vector3(x0 + w * 0.5, 2.48, z0 + 1.8), Vector3(w - 0.2, 0.16, 3.4), BLEU)
	var portes := 2 if n < 3 else 3
	for i in portes:
		var x := x0 + 1.0 + i * (w - 2.0) / maxf(1.0, portes - 1)
		k.box(Vector3(x, 1.0, z0 + 3.42), Vector3(0.8, 2.0, 0.04), [BLEU, ROSE, VERT][i], 0.0, false)
		k.box(Vector3(x, 2.15, z0 + 3.44), Vector3(0.3, 0.3, 0.02), BLANC, 0.0, false)
	var out: Array = []
	for i in portes:
		out.append(d._place(Vector3(x0 + 1.0 + i * (w - 2.0) / maxf(1.0, portes - 1), 0, z0 + 4.2), PI, false))
	if n >= 2:
		d._m(k, "lavabo", x0 + w - 0.6, z0 + 4.8, -PI * 0.5)
	return out


static func _atelier(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var w := float(r[2])
	var dp := float(r[3])
	# Hangar en tôle ondulée, porte roulante ouverte côté allée.
	var tole := Color("7d8a96")
	k.box(Vector3(x0 + 0.12, 1.5, z0 + dp * 0.5), Vector3(0.2, 3.0, dp), tole)
	k.box(Vector3(x0 + w * 0.5, 1.5, z0 + 0.12), Vector3(w, 3.0, 0.2), tole)
	for i in int(dp / 0.4):
		k.box(Vector3(x0 + 0.24, 1.5, z0 + 0.2 + i * 0.4), Vector3(0.04, 2.9, 0.06), tole.darkened(0.2), 0.0, false)
	k.box(Vector3(x0 + w * 0.5, 2.9, z0 + dp - 0.2), Vector3(w, 0.4, 0.3), JAUNE)
	for i in int(w / 0.6):
		k.box(Vector3(x0 + 0.3 + i * 0.6, 2.9, z0 + dp - 0.04), Vector3(0.3, 0.38, 0.02), NOIR if i % 2 == 0 else JAUNE, 0.0, false)
	if n >= 3:
		k.layer = "lumiere"
		k.box(Vector3(x0 + w * 0.5, 2.8, z0 + dp * 0.5), Vector3(0.15, 0.05, dp - 1.0), Color("f1faee"), 0.0, false)
		k.layer = "base"
	return []


static func _parking(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var w := float(r[2])
	var dp := float(r[3])
	# Places marquées, voitures garées (plus de monde avec la note).
	var places := 8
	for i in places + 1:
		k.box(Vector3(x0 + 0.6 + i * (w - 1.2) / places, Y + 0.004, z0 + 2.4), Vector3(0.08, 0.01, 4.0), BLANC, 0.0, false)
	k.box(Vector3(x0 + w * 0.5, Y + 0.004, z0 + 4.4), Vector3(w - 1.0, 0.01, 0.1), BLANC, 0.0, false)
	var garees := mini(places, 2 + n * 2)
	for i in garees:
		var x := x0 + 0.6 + (i + 0.5) * (w - 1.2) / places
		GestionModeles.voiture(k, Vector3(x, 0, z0 + 2.4), VIFS[(i * 3 + 1) % VIFS.size()].lightened(0.1))
	# Allée vers l'entrée.
	k.box(Vector3(x0 + w - 0.8, Y + 0.002, z0 + dp * 0.5), Vector3(1.2, 0.01, dp), Color("c9c2b4"), 0.0, false)
	# Panneau « P ».
	k.box(Vector3(x0 + w - 0.4, 1.6, z0 + 0.4), Vector3(0.8, 0.8, 0.06), BLEU, 0.0, false)
	k.box(Vector3(x0 + w - 0.4, 1.6, z0 + 0.44), Vector3(0.3, 0.5, 0.02), BLANC, 0.0, false)
	k.tube(Vector3(x0 + w - 0.4, 0, z0 + 0.35), Vector3(x0 + w - 0.4, 1.2, z0 + 0.35), 0.04, 0.04, 6, GRIS)
	if n >= 2:
		for i in 3:
			reverbere(k, Vector3(x0 + 1.0 + i * (w - 2.0) * 0.5, 0, z0 + 6.4))
	return []
