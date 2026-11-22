class_name DecorsCommissariat
extends RefCounted
## Décors de base des pièces du commissariat (GestionDiorama les appelle par
## DecorsRestaurant → DecorsCaserne pour les décors « police_… »). Chaque
## fonction meuble la pièce selon son niveau et renvoie les places des
## visiteurs ({pos, rot, assis, avant}). Comme à la caserne, les voitures du
## garage sont placées à part (GestionDiorama.placer_engins).
## Coordonnées absolues du plan (r = [x, z, largeur, profondeur]).

const BLEU := Color("1d3557")
const BLEU_C := Color("457b9d")
const BLANC := Color("f6f4ef")
const ROUGE := Color("c1121f")
const JAUNE := Color("ffd60a")
const INOX := Color("c9ced3")
const GRIS := Color("5c636a")
const NOIR := Color("26262b")
const BOIS := Color("8a5a3b")
const BETON := Color("b8b4ac")
const Y := 0.066


static func dessiner(d: GestionDiorama, k: LpKit, decor: String, r: Array, n: int) -> Array:
	match decor:
		"police_accueil":
			return _accueil(d, k, r, n)
		"police_garage":
			return _garage(d, k, r, n)
		"police_commandement":
			return _commandement(d, k, r, n)
		"police_bureau":
			return DecorsCaserne._bureau(d, k, r, n)
		"police_armurerie":
			return _armurerie(d, k, r, n)
		"police_plaintes":
			return _plaintes(d, k, r, n)
		"police_enquete":
			return _enquete(d, k, r, n)
		"police_pause":
			return DecorsCaserne._cuisine(d, k, r, n)
		"police_repos":
			return _repos(d, k, r, n)
		"police_cellules":
			return _cellules(d, k, r, n)
		"police_tir":
			return _tir(d, k, r, n)
		"police_parvis":
			return _parvis(d, k, r, n)
		"police_chenil":
			return _chenil(d, k, r, n)
		"police_fourriere":
			return _fourriere(d, k, r, n)
	return DecorsHopital.dessiner(d, k, decor, r, n)


# --- Pièces ------------------------------------------------------------------------------------

static func _accueil(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var out: Array = []
	# Guichet bleu derrière une vitre, face à la porte.
	var g := Vector3(x0 + 2.5, 0, z0 + 8.95)
	k.box(g + Vector3(0, 0.55, 0), Vector3(1.9, 1.1, 0.5), BLEU if n < 3 else Color("14213d"))
	k.box(g + Vector3(0, 0.75, 0.26), Vector3(1.9, 0.08, 0.02), BLANC, 0.0, false)
	k.box(g + Vector3(0, 1.12, 0), Vector3(2.0, 0.05, 0.6), INOX)
	k.layer = "verre"
	k.box(g + Vector3(0, 1.6, -0.05), Vector3(1.9, 0.9, 0.03), Color(0.8, 0.9, 1.0, 0.3), 0.0, false)
	k.layer = "base"
	k.box(g + Vector3(0.5, 1.17, 0.1), Vector3(0.35, 0.04, 0.25), BLANC, 0.0, false)
	# Bande bleue au sol vers le couloir, blason au mur.
	k.box(Vector3(x0 + 2.5, Y, z0 + 4.0), Vector3(0.35, 0.01, 7.0), BLEU_C, 0.0, false)
	k.box(Vector3(x0 + 0.12, 1.7, z0 + 3.0), Vector3(0.04, 0.9, 0.75), BLEU, 0.0, false)
	k.box(Vector3(x0 + 0.15, 1.75, z0 + 3.0), Vector3(0.02, 0.5, 0.45), BLANC, 0.0, false)
	k.box(Vector3(x0 + 0.16, 1.75, z0 + 3.0), Vector3(0.02, 0.25, 0.25), ROUGE, 0.0, false)
	# Chaises d'attente alignées.
	for i in 2 + mini(n, 3):
		d._chaise(k, Vector3(x0 + 4.4, 0, z0 + 5.6 + i * 0.6), -PI * 0.5, Color("6c757d"))
	out.append(d._place(Vector3(x0 + 4.4, 0, z0 + 5.6), -PI * 0.5, true))
	out.append(d._place(Vector3(x0 + 4.4, 0, z0 + 6.2), -PI * 0.5, true))
	if n >= 3:
		# Panneau « Avis de recherche » et dépliants.
		k.box(Vector3(x0 + 0.12, 1.5, z0 + 8.4), Vector3(0.04, 1.0, 1.4), Color("e9ecef"), 0.0, false)
		for i in 3:
			k.box(Vector3(x0 + 0.15, 1.6, z0 + 7.95 + i * 0.45), Vector3(0.02, 0.5, 0.35), Color("f4e8c1"), 0.0, false)
	if n >= 4:
		d._m(k, "plante_grande", x0 + 0.6, z0 + 0.6)
	if n >= 5:
		d._m(k, "lustre", x0 + 2.5, z0 + 6.0)
	return out


static func _garage(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var w := float(r[2])
	var dp := float(r[3])
	var out: Array = []
	# Places tracées en blanc, numéros, seuils bleus et blancs devant les portes.
	for i in 5:
		var x := x0 + i * w / 4.0
		if i > 0 and i < 4:
			k.box(Vector3(x, Y, z0 + dp * 0.5), Vector3(0.12, 0.01, dp - 0.6), BLANC, 0.0, false)
	for i in 4:
		var cx := x0 + (i + 0.5) * w / 4.0
		for j in 8:
			k.box(Vector3(cx - 1.6 + j * 0.46, Y, z0 + dp - 0.25), Vector3(0.44, 0.012, 0.4), BLEU if j % 2 == 0 else BLANC, 0.0, false)
		k.box(Vector3(cx, Y, z0 + dp * 0.5), Vector3(0.6, 0.01, 0.6), Color("8d949b"), 0.0, false)
	k.box(Vector3(x0 + w * 0.5, Y + 0.001, z0 + 7.05), Vector3(w - 0.4, 0.01, 0.9), Color("b8bec4"), 0.0, false)
	# Panneau « Réservé police » au fond.
	k.box(Vector3(x0 + 9.0, 2.4, z0 + 0.1), Vector3(2.6, 0.6, 0.05), BLEU, 0.0, false)
	k.box(Vector3(x0 + 9.0, 2.4, z0 + 0.13), Vector3(2.3, 0.35, 0.02), BLANC, 0.0, false)
	if n >= 2:
		# Néons au plafond.
		k.layer = "lumiere"
		for i in 4:
			k.box(Vector3(x0 + (i + 0.5) * w / 4.0, 3.4, z0 + dp * 0.5), Vector3(0.15, 0.05, 2.4), Color("f1faee"), 0.0, false)
		k.layer = "base"
	if n >= 3:
		# Station de lavage rapide (tuyau enroulé).
		k.lathe(Vector3(x0 + 0.25, 1.4, z0 + 9.0), [Vector2(0.0, -0.15), Vector2(0.35, -0.15), Vector2(0.35, 0.15), Vector2(0.0, 0.15)], 12, Color("2a9d8f"))
	if n >= 4:
		# Grand écusson tricolore.
		k.box(Vector3(x0 + 4.5, 2.3, z0 + 0.1), Vector3(1.2, 1.2, 0.05), BLEU, 0.0, false)
		k.box(Vector3(x0 + 4.5, 2.3, z0 + 0.13), Vector3(0.8, 0.8, 0.02), Color("d4af37"), 0.0, false)
	# Aire de sortie jusqu'à la rue (rien ne s'y pose).
	var plan_z := z0 + dp
	var fin := plan_z + 11.0
	k.box(Vector3(x0 + w * 0.5, 0.035, (plan_z + fin) * 0.5), Vector3(w + 1.0, 0.03, fin - plan_z), Color("6c7075"), 0.0, false)
	for i in 9:
		k.box(Vector3(x0 + 1.0 + i * 2.0, 0.052, plan_z + 3.0), Vector3(1.0, 0.01, 0.25), BLANC, 0.0, false)
	k.box(Vector3(x0 + w * 0.5, 0.052, plan_z + 1.2), Vector3(w, 0.01, 0.12), BLANC, 0.0, false)
	k.box(Vector3(x0 + w * 0.5, 0.052, fin - 0.4), Vector3(w, 0.01, 0.12), BLANC, 0.0, false)
	for x in [4.5, 9.0, 13.5]:
		out.append(d._place(Vector3(x0 + x, 0, z0 + 7.05), PI if x > 8.0 else 0.0, false))
	return out


static func _commandement(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var nb := 2 if n < 3 else 3
	var xs := [3.2, 7.4, 5.3]
	for i in nb:
		DecorsCaserne._poste(d, k, Vector3(x0 + float(xs[i]), 0, z0 + (1.9 if i < 2 else 4.6)), 2 + mini(n, 3) / 2, Color("343a40"))
	# Voyant bleu « 17 » au mur et horloge.
	k.layer = "lumiere"
	k.box(Vector3(x0 + 10.8, 2.2, z0 + 0.3), Vector3(0.12, 0.3, 0.3), Color("4ea8de"), 0.0, false)
	k.layer = "base"
	k.lathe(Vector3(x0 + 9.0, 2.2, z0 + 0.05), [Vector2(0.0, 0.0), Vector2(0.25, 0.0), Vector2(0.25, 0.05), Vector2(0.0, 0.05)], 12, BLANC)
	if n >= 4:
		d._m(k, "plante", x0 + 0.6, z0 + 6.4)
	return []


static func _armurerie(_d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	# Comptoir de délivrance et grille de sécurité.
	k.box(Vector3(x0 + 2.5, 0.5, z0 + 6.4), Vector3(3.2, 1.0, 0.5), GRIS)
	k.box(Vector3(x0 + 2.5, 1.02, z0 + 6.4), Vector3(3.3, 0.04, 0.6), INOX)
	for i in 9:
		k.beam(Vector3(x0 + 1.0 + i * 0.38, 1.05, z0 + 6.2), Vector3(x0 + 1.0 + i * 0.38, 2.4, z0 + 6.2), 0.03, 0.03, NOIR)
	if n >= 3:
		k.box(Vector3(x0 + 2.5, 2.7, z0 + 0.12), Vector3(1.2, 0.4, 0.04), JAUNE, 0.0, false)
	return []


static func _plaintes(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var out: Array = []
	# Deux bureaux face à face : l'agent tape, le plaignant raconte.
	var nb := 1 if n < 3 else 2
	for i in nb:
		var p := Vector3(x0 + 2.0 + i * 2.4, 0, z0 + 2.4)
		DecorsCaserne._poste(d, k, p, 1, Color("d9d4c7"))
		d._chaise(k, p + Vector3(0, 0, -0.75), 0.0, Color("457b9d"))
		out.append(d._place(p + Vector3(0, 0, -0.75), 0.0, true))
	# Chaises d'attente près de la porte.
	for i in 2:
		d._chaise(k, Vector3(x0 + 0.6, 0, z0 + 5.4 + i * 0.7), PI * 0.5, Color("6c757d"))
	out.append(d._place(Vector3(x0 + 0.6, 0, z0 + 5.4), PI * 0.5, true))
	if n >= 4:
		d._m(k, "plante", x0 + 5.4, z0 + 7.3)
	return out


static func _enquete(d: GestionDiorama, k: LpKit, r: Array, _n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	# Deux bureaux encombrés de dossiers.
	for i in 2:
		var p := Vector3(x0 + 2.5, 0, z0 + 2.2 + i * 2.6)
		DecorsCaserne._poste(d, k, p, 2, Color("b08968"))
		for j in 3:
			k.box(p + Vector3(-0.55, 0.8 + j * 0.06, 0.1), Vector3(0.32, 0.05, 0.24), [Color("f4e8c1"), Color("e9c46a"), Color("bde0fe")][j], 0.0, false)
	return []


static func _repos(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	# Lits de camp comme à la caserne, plus une rangée de casiers bleus.
	DecorsCaserne._dortoir(d, k, r, mini(n, 2))
	for i in 3 + mini(n, 3):
		k.box(Vector3(x0 + 2.2 + i * 0.5, 0.9, z0 + 7.65), Vector3(0.46, 1.8, 0.5), BLEU_C if i % 2 == 0 else BLEU)
	return []


static func _cellules(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	# Deux cellules au fond (trois au niveau 4), banc de béton, porte vitrée.
	var nb := 2 if n < 4 else 3
	var lc := 5.0 / nb
	for i in nb:
		var cx := x0 + (i + 0.5) * lc
		k.box(Vector3(cx, 0.25, z0 + 0.5), Vector3(lc - 0.4, 0.5, 0.7), BETON)
		k.box(Vector3(x0 + (i + 1) * lc, 1.2, z0 + 1.7), Vector3(0.1, 2.4, 3.4), Color("ced4da"), 0.0, false)
		k.layer = "verre"
		k.box(Vector3(cx, 1.2, z0 + 3.4), Vector3(lc - 0.2, 2.4, 0.05), Color(0.75, 0.85, 0.95, 0.35), 0.0, false)
		k.layer = "base"
		k.box(Vector3(cx, 2.42, z0 + 3.4), Vector3(lc - 0.1, 0.06, 0.1), GRIS, 0.0, false)
	return []


static func _tir(_d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	# Trois couloirs séparés par des cloisons, pas de tir et tapis anti-bruit.
	for i in 4:
		k.box(Vector3(x0 + 0.1 + i * 1.95, 1.0, z0 + 2.0), Vector3(0.08, 2.0, 3.6), Color("495057"), 0.0, false)
	k.box(Vector3(x0 + 3.0, 0.55, z0 + 3.9), Vector3(5.8, 1.1, 0.35), Color("6c757d"))
	k.box(Vector3(x0 + 3.0, 0.15, z0 + 0.15), Vector3(5.8, 0.3, 0.3), Color("343a40"))
	if n >= 2:
		k.box(Vector3(x0 + 3.0, Y, z0 + 6.0), Vector3(4.6, 0.02, 2.6), Color("2b6cb0"), 0.0, false)
	return []


static func _parvis(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var out: Array = []
	# Petite piste en boucle avec un passage piéton.
	k.box(Vector3(x0 + 5.25, Y, z0 + 3.25), Vector3(8.6, 0.01, 4.6), Color("495057"), 0.0, false)
	k.box(Vector3(x0 + 5.25, Y + 0.002, z0 + 3.25), Vector3(5.8, 0.012, 1.8), Color("8fbf6a"), 0.0, false)
	for i in 6:
		k.box(Vector3(x0 + 1.4 + i * 0.32, Y + 0.002, z0 + 3.25), Vector3(0.18, 0.012, 1.5), BLANC, 0.0, false)
	for i in 8:
		k.box(Vector3(x0 + 2.0 + i * 1.0, Y + 0.003, z0 + 1.65), Vector3(0.5, 0.012, 0.08), BLANC, 0.0, false)
		k.box(Vector3(x0 + 2.0 + i * 1.0, Y + 0.003, z0 + 4.85), Vector3(0.5, 0.012, 0.08), BLANC, 0.0, false)
	if n >= 4:
		k.box(Vector3(x0 + 9.8, 1.2, z0 + 3.25), Vector3(0.08, 2.4, 0.08), GRIS)
		k.box(Vector3(x0 + 9.8, 2.3, z0 + 3.25), Vector3(0.05, 0.5, 0.5), BLEU, 0.0, false)
	out.append(d._place(Vector3(x0 + 3.0, 0, z0 + 5.6), PI, false))
	out.append(d._place(Vector3(x0 + 7.6, 0, z0 + 5.6), PI, false))
	return out


static func _chenil(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var out: Array = []
	# Enclos grillagé et dalle des niches.
	k.box(Vector3(x0 + 3.0, Y, z0 + 2.0), Vector3(5.6, 0.01, 3.4), BETON, 0.0, false)
	for i in 11:
		k.beam(Vector3(x0 + 0.2 + i * 0.86, 0.0, z0 + 9.6), Vector3(x0 + 0.2 + i * 0.86, 1.4, z0 + 9.6), 0.04, 0.04, GRIS)
	k.beam(Vector3(x0 + 0.2, 1.4, z0 + 9.6), Vector3(x0 + 8.8, 1.4, z0 + 9.6), 0.03, 0.03, GRIS)
	k.layer = "verre"
	k.box(Vector3(x0 + 4.5, 0.7, z0 + 9.6), Vector3(8.6, 1.4, 0.02), Color(0.6, 0.65, 0.7, 0.35), 0.0, false)
	k.layer = "base"
	# Rex, toujours là.
	d._m(k, "chien", x0 + 2.4, z0 + 5.4, -PI * 0.3)
	if n >= 3:
		d._m(k, "chien", x0 + 5.4, z0 + 7.2, PI * 0.6, Color("3b2a1e"))
	for x in [2.0, 6.0]:
		out.append(d._place(Vector3(x0 + x, 0, z0 + 10.2), PI, false))
	return out


static func _fourriere(_d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	# Dalle de bitume avec places numérotées.
	k.box(Vector3(x0 + 5.0, Y, z0 + 5.25), Vector3(9.6, 0.01, 10.0), Color("5c636a"), 0.0, false)
	for i in 4 + mini(n, 2):
		k.box(Vector3(x0 + 0.6 + i * 2.6 * 0.66, Y + 0.002, z0 + 2.4), Vector3(0.08, 0.012, 3.6), BLANC, 0.0, false)
	if n >= 4:
		k.box(Vector3(x0 + 5.0, 2.6, z0 + 0.2), Vector3(3.0, 0.6, 0.05), JAUNE, 0.0, false)
	return []
