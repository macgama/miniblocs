class_name DecorsAuto
extends RefCounted
## Décors des genres « en kit » (GenresAuto) : des pièces qui s'adaptent à
## leur taille, quel que soit le genre. Le nom du décor peut porter des
## réglages après « : » (« auto_enclos:lion,lionne:savane » : les animaux,
## puis le sol). Chaque fonction meuble la pièce selon son niveau (plus de
## monde, plus d'équipement) et l'époque de la partie (tableau noir ou écran,
## train à vapeur ou TGV…), et renvoie les places des visiteurs.
## Les animaux, tracteurs et objets de la rue viennent des modèles de la
## touche G (Decors.mesh), posés en plus du maillage de la pièce.
## Coordonnées absolues du plan (r = [x, z, largeur, profondeur]).

const BOIS := Color("8d6e63")
const BOIS_C := Color("c8a27a")
const BLANC := Color("f6f4ef")
const GRIS := Color("6c757d")
const NOIR := Color("26262b")
const INOX := Color("c9ced3")
const VERT := Color("2d6a4f")
const HERBE := Color("6fa85a")
const TERRE := Color("a27b5c")
const SABLE := Color("dcc69a")
const EAU := Color("4a90b8")
const Y := 0.066
const COULEURS := [Color("e63946"), Color("457b9d"), Color("f4a261"), Color("2a9d8f"), Color("e9c46a"), Color("8338ec")]


static func dessiner(d: GestionDiorama, k: LpKit, decor: String, r: Array, n: int) -> Array:
	var bouts := decor.split(":")
	var nom := String(bouts[0])
	var a1 := String(bouts[1]) if bouts.size() > 1 else ""
	var a2 := String(bouts[2]) if bouts.size() > 2 else ""
	match nom:
		"auto_accueil":
			return _accueil(d, k, r, n, a1)
		"auto_classe":
			return _classe(d, k, r, n)
		"auto_amphi":
			return _amphi(d, k, r, n, a1)
		"auto_bureaux":
			return _bureaux(d, k, r, n)
		"auto_guichets":
			return _guichets(d, k, r, n)
		"auto_vitrines":
			return _vitrines(d, k, r, n, a1)
		"auto_boutique":
			return _boutique(d, k, r, n)
		"auto_cafe":
			return _cafe(d, k, r, n, a1)
		"auto_cuisine":
			return _cuisine(d, k, r, n)
		"auto_atelier":
			return _atelier(d, k, r, n)
		"auto_labo":
			return _labo(d, k, r, n)
		"auto_soins":
			return _soins(d, k, r, n)
		"auto_reserve":
			return _reserve(d, k, r, n)
		"auto_biblio":
			return _biblio(d, k, r, n)
		"auto_vestiaires":
			return _vestiaires(d, k, r, n)
		"auto_dortoir":
			return _dortoir(d, k, r, n)
		"auto_quai":
			return _quai(d, k, r, n, a1)
		"auto_enclos":
			return _enclos(d, k, r, n, a1, a2)
		"auto_bassin":
			return _bassin(d, k, r, n, a1)
		"auto_serre":
			return _serre(d, k, r, n, a1)
		"auto_terrain":
			return _terrain(d, k, r, n, a1)
		"auto_champ":
			return _champ(d, k, r, n, a1)
		"auto_etable":
			return _etable(d, k, r, n, a1)
		"auto_cour":
			return _cour(d, k, r, n)
		"auto_jardin":
			return _jardin(d, k, r, n)
		"auto_parking":
			return _parking(d, k, r, n)
		"auto_cuves":
			return _cuves(d, k, r, n)
		"auto_vigne":
			return _vigne(d, k, r, n)
		"auto_machines":
			return _machines(d, k, r, n, a1)
		"auto_scene":
			return _scene(d, k, r, n)
	return []


# --- Outils ------------------------------------------------------------------------------------

static func _an() -> int:
	return GestionEpoques.annee()


## Pose un modèle de la touche G (animal, tracteur, banc…) dans la maquette.
static func deco(d: GestionDiorama, id: String, p: Vector3, rot := 0.0, s := 1.0) -> void:
	if not EpoquesObjets.decor_disponible(id):
		return
	var m := Decors.mesh(id)
	if m == null:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = m
	if not Decors.procedural(id):
		mi.material_override = _materiau()
	mi.position = p
	mi.rotation.y = rot
	mi.scale = Vector3.ONE * s
	d._statique.add_child(mi)


static var _mat: StandardMaterial3D


## Palette des modèles de la touche G, sans les lumières de nuit (la maquette
## a son propre éclairage).
static func _materiau() -> StandardMaterial3D:
	if _mat == null:
		_mat = Decors.materiau().duplicate() as StandardMaterial3D
		_mat.emission_enabled = false
	return _mat


static func _ids(arg: String, defaut: Array) -> Array:
	if arg == "":
		return defaut
	return Array(arg.split(","))


static func _table(k: LpKit, c: Vector3, l: float, p: float, col: Color) -> void:
	k.box(c + Vector3(0, 0.74, 0), Vector3(l, 0.05, p), col)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			k.box(c + Vector3(sx * (l * 0.5 - 0.06), 0.36, sz * (p * 0.5 - 0.06)), Vector3(0.05, 0.72, 0.05), col.darkened(0.3), 0.0, false)


static func _comptoir(k: LpKit, c: Vector3, l: float, col: Color) -> void:
	k.box(c + Vector3(0, 0.55, 0), Vector3(l, 1.1, 0.6), col)
	k.box(c + Vector3(0, 1.12, 0), Vector3(l + 0.1, 0.05, 0.7), col.lightened(0.3))
	k.box(c + Vector3(0, 0.6, 0.31), Vector3(l, 0.12, 0.02), col.darkened(0.3), 0.0, false)


## Panneau mural (affiche, tableau, plan) sur le mur du fond.
static func _panneau(k: LpKit, p: Vector3, l: float, h: float, col: Color) -> void:
	k.box(p, Vector3(l + 0.08, h + 0.08, 0.04), BOIS.darkened(0.2), 0.0, false)
	k.box(p + Vector3(0, 0, 0.025), Vector3(l, h, 0.01), col, 0.0, false)


static func _cloture(k: LpKit, r: Array, col: Color, h := 1.1, ouverture := 2.0) -> void:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var x1 := x0 + float(r[2])
	var z1 := z0 + float(r[3])
	var milieu_bas := (z0 + z1) * 0.5
	for c in [[Vector2(x0, z0), Vector2(x1, z0)], [Vector2(x1, z0), Vector2(x1, z1)], [Vector2(x1, z1), Vector2(x0, z1)], [Vector2(x0, z1), Vector2(x0, z0)]]:
		var a: Vector2 = c[0]
		var b: Vector2 = c[1]
		var lg := a.distance_to(b)
		var nb := maxi(1, int(lg / 1.6))
		for i in nb:
			var p0 := a.lerp(b, float(i) / nb)
			var p1 := a.lerp(b, float(i + 1) / nb)
			var m := (p0 + p1) * 0.5
			# Ouverture côté gauche (vers l'allée), au milieu.
			if absf(m.x - x0) < 0.05 and absf(m.y - milieu_bas) < ouverture * 0.5:
				continue
			k.box(Vector3(p0.x, h * 0.5, p0.y), Vector3(0.1, h, 0.1), col.darkened(0.25))
			k.beam(Vector3(p0.x, h * 0.85, p0.y), Vector3(p1.x, h * 0.85, p1.y), 0.05, 0.07, col)
			k.beam(Vector3(p0.x, h * 0.4, p0.y), Vector3(p1.x, h * 0.4, p1.y), 0.05, 0.07, col)


static func _sol(k: LpKit, r: Array, col: Color, marge := 0.0) -> void:
	k.box(Vector3(float(r[0]) + float(r[2]) * 0.5, Y * 0.5, float(r[1]) + float(r[3]) * 0.5), Vector3(float(r[2]) - marge * 2.0, 0.02, float(r[3]) - marge * 2.0), col, 0.0, false)


## Visiteurs le long du bord gauche (côté allée), regard vers l'intérieur.
static func _bord(d: GestionDiorama, r: Array, nb: int, recul := 0.6) -> Array:
	var out: Array = []
	var dz := float(r[3])
	for i in nb:
		out.append(d._place(Vector3(float(r[0]) + recul, 0, float(r[1]) + dz * (0.2 + 0.6 * float(i) / maxf(1.0, float(nb - 1)))), PI * 0.5, false))
	return out


# --- Le hall d'entrée --------------------------------------------------------------------------

static func _accueil(d: GestionDiorama, k: LpKit, r: Array, n: int, style: String) -> Array:
	var gd := GestionTypes.genre(d.genre)
	var x0 := float(r[0])
	var z0 := float(r[1])
	var w := float(r[2])
	var dp := float(r[3])
	var c: Vector2 = gd.get("comptoir", Vector2(x0 + w * 0.5 - 2.4, z0 + 1.9))
	var teinte := Color(String(gd.get("teinte", "1d3557")))
	var out: Array = []
	# Comptoir (guichet, billetterie, loge) face à la porte, et son enseigne.
	_comptoir(k, Vector3(c.x, 0, c.y), 3.0 if n < 3 else 4.0, teinte)
	_panneau(k, Vector3(c.x, 2.3, z0 + 0.1), 2.6, 0.6, teinte.lightened(0.15))
	for i in mini(n, 2):
		d._chaise(k, Vector3(c.x - 0.8 + i * 1.6, 0, c.y - 0.9), 0.0, Color("2b2d42"))
	# Tapis d'entrée, plan affiché, plantes.
	k.box(Vector3(x0 + w * 0.5, Y, z0 + dp - 1.0), Vector3(2.2, 0.01, 1.4), Color("7d2d26") if style != "gare" else NOIR, 0.0, false)
	_panneau(k, Vector3(x0 + w * 0.5 + 2.6, 1.6, z0 + 0.1), 1.6, 1.0, Color("f1faee"))
	out.append(d._place(Vector3(x0 + w * 0.5 + 2.6, 0, z0 + 1.0), PI, false))
	GestionModeles.dessiner(k, "plante_grande", Vector3(x0 + 0.8, 0, z0 + dp - 0.8), 0.0)
	GestionModeles.dessiner(k, "plante_grande", Vector3(x0 + w - 0.8, 0, z0 + dp - 0.8), 0.0)
	# Bancs d'attente : un de plus par niveau.
	for i in mini(n + 1, 6):
		var bx := x0 + 1.6 + float(i) * 2.4
		if bx > c.x - 2.0 and bx < x0 + w * 0.5 + 3.6:
			bx = x0 + w * 0.5 + 4.2 + float(i) * 2.4
		if bx > x0 + w - 1.4:
			break
		GestionModeles.dessiner(k, "banc", Vector3(bx, 0, z0 + dp * 0.55), 0.0)
		for lp in GestionModeles.places("banc"):
			out.append(d._place(Vector3(bx + float(lp[0]), 0, z0 + dp * 0.55 + float(lp[1])), 0.0, true))
	if style == "gare" or n >= 3:
		# Tableau des horaires / des activités, bien en vue.
		var tx := x0 + w * 0.5 - 0.2
		k.box(Vector3(tx, 2.6, z0 + 0.12), Vector3(2.4, 0.9, 0.06), NOIR, 0.0, false)
		k.layer = "lumiere"
		for j in 4:
			k.box(Vector3(tx, 2.92 - j * 0.2, z0 + 0.16), Vector3(2.2, 0.08, 0.01), Color("ffd166") if _an() < 1990 else Color("80ed99"), 0.0, false)
		k.layer = "base"
	if n >= 5:
		GestionModeles.dessiner(k, "lustre", Vector3(x0 + w * 0.5, 0, z0 + dp * 0.5), 0.0)
	return out


# --- Salles ------------------------------------------------------------------------------------

## Salle de classe : pupitres en rangs face au tableau (noir avant 1990, puis
## blanc, écran après 2010).
static func _classe(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var w := float(r[2])
	var dp := float(r[3])
	var out: Array = []
	var an := _an()
	var tab := Color("2f4f3a") if an < 1990 else (BLANC if an < 2010 else NOIR)
	_panneau(k, Vector3(x0 + w * 0.5, 1.6, z0 + 0.1), minf(w - 1.6, 3.6), 1.2, tab)
	if an >= 2010:
		k.layer = "lumiere"
		k.box(Vector3(x0 + w * 0.5, 1.6, z0 + 0.14), Vector3(minf(w - 1.8, 3.4), 1.0, 0.01), Color("8ecae6"), 0.0, false)
		k.layer = "base"
	_table(k, Vector3(x0 + w * 0.5 - 1.0, 0, z0 + 1.4), 1.4, 0.7, BOIS)
	var cols := maxi(2, int((w - 1.6) / 1.4))
	var rangs := clampi(1 + n, 2, int((dp - 3.2) / 1.25))
	for j in rangs:
		for i in cols:
			var p := Vector3(x0 + 1.0 + (float(i) + 0.5) * (w - 2.0) / cols, 0, z0 + 3.0 + j * 1.25)
			_table(k, p, 0.9, 0.5, BOIS_C if an < 1970 else Color("d9d4c7"))
			d._chaise(k, p + Vector3(0, 0, 0.5), 0.0, COULEURS[(i + j) % COULEURS.size()].darkened(0.2))
			if (i + j) % 2 == 0:
				out.append(d._place(p + Vector3(0, 0, 0.5), PI, true))
	return out


## Amphithéâtre, salle du conseil ou salle de spectacle : gradins face à une estrade.
static func _amphi(d: GestionDiorama, k: LpKit, r: Array, n: int, style: String) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var w := float(r[2])
	var dp := float(r[3])
	var out: Array = []
	k.box(Vector3(x0 + w * 0.5, 0.15, z0 + 1.0), Vector3(w - 1.0, 0.3, 1.6), BOIS)
	if style == "conseil":
		# Table du conseil en U et drapeau.
		_table(k, Vector3(x0 + w * 0.5, 0.3, z0 + 1.0), w * 0.5, 0.8, BOIS.darkened(0.2))
		GestionModeles.dessiner(k, "drapeau", Vector3(x0 + w - 1.0, 0, z0 + 0.7), 0.0)
	else:
		GestionModeles.dessiner(k, "pupitre", Vector3(x0 + w * 0.5, 0.3, z0 + 1.0), 0.0)
		_panneau(k, Vector3(x0 + w * 0.5, 2.0, z0 + 0.1), minf(w - 2.0, 4.0), 1.4, BLANC)
	var rangs := clampi(2 + n, 3, int((dp - 2.6) / 0.95))
	for j in rangs:
		var z := z0 + 2.6 + j * 0.95
		var y := 0.12 * j
		k.box(Vector3(x0 + w * 0.5, y * 0.5 + 0.02, z), Vector3(w - 1.2, y + 0.04, 0.95), Color("a68a64").darkened(0.05 * j), 0.0, false)
		var nb := int((w - 2.0) / 0.6)
		for i in nb:
			var p := Vector3(x0 + 1.0 + (i + 0.5) * (w - 2.0) / nb, y, z)
			k.box(p + Vector3(0, 0.42, 0), Vector3(0.48, 0.06, 0.45), Color("9d0208") if style != "conseil" else Color("1d3557"))
			k.box(p + Vector3(0, 0.66, 0.2), Vector3(0.48, 0.45, 0.06), Color("9d0208").darkened(0.2) if style != "conseil" else Color("1d3557").darkened(0.2))
			if (i + j) % 3 == 0:
				out.append(d._place(p, PI, true))
	return out


## Bureaux : postes de travail (papier avant 1980, ordinateurs ensuite).
static func _bureaux(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var w := float(r[2])
	var dp := float(r[3])
	var out: Array = []
	var nb := clampi(1 + n, 2, maxi(2, int((w - 1.0) / 2.0) * 2))
	for i in nb:
		var cx := x0 + 1.4 + float(i / 2) * 2.0
		var cz := z0 + 2.2 + float(i % 2) * 3.0
		if cx > x0 + w - 1.0:
			break
		if _an() >= 1980:
			DecorsCaserne._poste(d, k, Vector3(cx, 0, cz), 1 + (i % 2))
		else:
			_table(k, Vector3(cx, 0, cz), 1.5, 0.75, BOIS)
			k.box(Vector3(cx - 0.3, 0.8, cz), Vector3(0.4, 0.05, 0.3), BLANC, 0.0, false)
			d._chaise(k, Vector3(cx, 0, cz + 0.75), PI, Color("2b2d42"))
		out.append(d._place(Vector3(cx + 0.6, 0, cz - 0.9), 0.0, false))
	d._etagere(k, Vector3(x0 + w - 0.4, 0, z0 + dp * 0.5), -PI * 0.5, minf(dp - 2.0, 3.0), 1.8, BOIS, [Color("e9c46a"), Color("457b9d"), Color("e76f51")])
	return out


## Guichets alignés (état civil, billets, inscriptions) et leur file.
static func _guichets(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var w := float(r[2])
	var dp := float(r[3])
	var out: Array = []
	var nb := clampi(1 + n, 2, int((w - 1.0) / 2.0))
	for i in nb:
		var cx := x0 + 1.0 + (float(i) + 0.5) * (w - 2.0) / nb
		_comptoir(k, Vector3(cx, 0, z0 + 2.4), 1.7, Color("457b9d"))
		k.layer = "verre"
		k.box(Vector3(cx, 1.55, z0 + 2.4), Vector3(1.6, 0.8, 0.02), Color(0.75, 0.88, 0.95, 0.4), 0.0, false)
		k.layer = "base"
		d._chaise(k, Vector3(cx, 0, z0 + 1.6), 0.0, Color("2b2d42"))
		k.box(Vector3(cx, 2.3, z0 + 2.4), Vector3(0.5, 0.3, 0.05), Color("ffd166"), 0.0, false)
		out.append(d._place(Vector3(cx, 0, z0 + 3.3), PI, false))
		out.append(d._place(Vector3(cx, 0, z0 + 4.3), PI, false))
	# Machine à tickets d'attente.
	GestionModeles.dessiner(k, "borne", Vector3(x0 + w - 0.7, 0, z0 + dp - 1.0), -PI * 0.5)
	return out


## Vitrines et œuvres : tableaux aux murs, vitrines au centre, bancs.
static func _vitrines(d: GestionDiorama, k: LpKit, r: Array, n: int, theme: String) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var w := float(r[2])
	var dp := float(r[3])
	var out: Array = []
	var nb := clampi(n + 1, 2, int((w - 1.0) / 1.6))
	for i in nb:
		var tx := x0 + 1.0 + (float(i) + 0.5) * (w - 2.0) / nb
		var col: Color = COULEURS[(i * 3 + theme.length()) % COULEURS.size()]
		k.box(Vector3(tx, 1.7, z0 + 0.12), Vector3(1.1, 0.85, 0.05), Color("b08d57"), 0.0, false)
		k.box(Vector3(tx, 1.7, z0 + 0.15), Vector3(0.95, 0.7, 0.01), col.lerp(Color("f1e3c6"), 0.35), 0.0, false)
		k.box(Vector3(tx, 0.02, z0 + 1.0), Vector3(1.2, 0.01, 0.06), Color("9a958c"), 0.0, false)
		out.append(d._place(Vector3(tx, 0, z0 + 1.5), PI, false))
	# Vitrines au centre : un objet sous verre chacune (amphore, buste, fossile…).
	var nv := clampi(n, 1, int((w - 2.0) / 2.2))
	for i in nv:
		var vx := x0 + 1.0 + (float(i) + 0.5) * (w - 2.0) / nv
		var vz := z0 + dp * 0.58
		k.box(Vector3(vx, 0.45, vz), Vector3(0.9, 0.9, 0.9), BLANC)
		match (i + theme.length()) % 4:
			0:
				k.lathe(Vector3(vx, 0.9, vz), [Vector2(0.0, 0.0), Vector2(0.12, 0.0), Vector2(0.2, 0.2), Vector2(0.1, 0.45), Vector2(0.14, 0.55), Vector2(0.0, 0.55)], 10, Color("c1663a"))
			1:
				k.box(Vector3(vx, 1.05, vz), Vector3(0.22, 0.3, 0.2), Color("d9d4c7"))
				k.lathe(Vector3(vx, 1.2, vz), [Vector2(0.0, 0.0), Vector2(0.12, 0.05), Vector2(0.11, 0.25), Vector2(0.0, 0.3)], 8, Color("d9d4c7"))
			2:
				k.box(Vector3(vx, 0.95, vz), Vector3(0.6, 0.08, 0.3), Color("cdb38b"))
			_:
				k.box(Vector3(vx, 1.0, vz), Vector3(0.3, 0.2, 0.3), Color("d4af37"))
		k.layer = "verre"
		k.box(Vector3(vx, 1.2, vz), Vector3(0.86, 0.6, 0.86), Color(0.8, 0.9, 1.0, 0.25), 0.0, false)
		k.layer = "base"
		out.append(d._place(Vector3(vx, 0, vz + 0.95), PI, false))
	if n >= 2:
		GestionModeles.dessiner(k, "banc", Vector3(x0 + w * 0.5, 0, z0 + dp - 1.4), PI)
	return out


## Boutique : rayonnages aux murs, table au centre, caisse près de la porte.
static func _boutique(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var w := float(r[2])
	var dp := float(r[3])
	var out: Array = []
	d._etagere(k, Vector3(x0 + w * 0.5, 0, z0 + 0.3), 0.0, w - 1.0, 1.8, BOIS_C, COULEURS)
	d._etagere(k, Vector3(x0 + 0.3, 0, z0 + dp * 0.45), PI * 0.5, dp * 0.5, 1.6, BOIS_C, COULEURS)
	for i in clampi(n, 1, 3):
		var tx := x0 + 1.6 + float(i) * 1.8
		if tx > x0 + w - 1.2:
			break
		_table(k, Vector3(tx, 0, z0 + dp * 0.45), 1.2, 0.8, BOIS_C)
		for j in 4:
			k.box(Vector3(tx - 0.4 + j * 0.27, 0.82, z0 + dp * 0.45), Vector3(0.2, 0.12, 0.3), COULEURS[(i + j) % COULEURS.size()], 0.0, false)
		out.append(d._place(Vector3(tx, 0, z0 + dp * 0.45 + 0.8), PI, false))
	_comptoir(k, Vector3(x0 + w - 1.4, 0, z0 + dp - 2.0), 1.6, BOIS)
	out.append(d._place(Vector3(x0 + w - 1.4, 0, z0 + dp - 1.1), PI, false))
	out.append(d._place(Vector3(x0 + 1.0, 0, z0 + 1.0), PI, false))
	return out


## Café, buvette ou cantine : comptoir au fond, tables rondes (ou longues).
static func _cafe(d: GestionDiorama, k: LpKit, r: Array, n: int, style: String) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var w := float(r[2])
	var dp := float(r[3])
	var out: Array = []
	_comptoir(k, Vector3(x0 + w * 0.5, 0, z0 + 1.0), minf(w - 1.6, 3.6), BOIS)
	GestionModeles.dessiner(k, "machine_cafe" if _an() >= 1950 else "fourneau", Vector3(x0 + w * 0.5 + 1.0, 1.12, z0 + 0.9), 0.0)
	if style == "cantine":
		var nb := clampi(n, 1, int((dp - 3.0) / 1.8))
		for j in nb:
			var z := z0 + 3.0 + j * 1.8
			_table(k, Vector3(x0 + w * 0.5, 0, z), w - 2.4, 0.8, BOIS_C)
			var nc := int((w - 2.6) / 0.7)
			for i in nc:
				var x := x0 + 1.6 + (i + 0.5) * (w - 3.2) / nc
				d._chaise(k, Vector3(x, 0, z - 0.6), 0.0, Color("e76f51"))
				d._chaise(k, Vector3(x, 0, z + 0.6), PI, Color("e76f51"))
				if i % 2 == 0:
					out.append(d._place(Vector3(x, 0, z + 0.6), PI, true))
		return out
	var nt := clampi(n + 1, 2, maxi(2, int((w - 1.0) / 2.0) * maxi(1, int((dp - 3.0) / 2.2))))
	var par_rang := maxi(1, int((w - 1.0) / 2.0))
	for i in nt:
		var p := Vector3(x0 + 1.4 + float(i % par_rang) * 2.0, 0, z0 + 3.2 + float(i / par_rang) * 2.2)
		if p.z > z0 + dp - 1.0:
			break
		d._table_ronde(k, p, 0.4, BOIS_C)
		d._chaise(k, p + Vector3(-0.6, 0, 0), PI * 0.5, Color("264653"))
		d._chaise(k, p + Vector3(0.6, 0, 0), -PI * 0.5, Color("264653"))
		out.append(d._place(p + Vector3(-0.6, 0, 0), PI * 0.5, true))
		out.append(d._place(p + Vector3(0.6, 0, 0), -PI * 0.5, true))
	return out


static func _cuisine(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var w := float(r[2])
	var dp := float(r[3])
	for i in int((w - 1.0) / 1.0):
		k.box(Vector3(x0 + 1.0 + i * 1.0, 0.45, z0 + 0.5), Vector3(0.95, 0.9, 0.7), INOX)
	GestionModeles.dessiner(k, "piano_cuisson" if _an() >= 1950 else "fourneau", Vector3(x0 + w * 0.5, 0, z0 + dp * 0.5), 0.0)
	if n >= 3:
		GestionModeles.dessiner(k, "armoire_froide" if _an() >= 1930 else "etagere_inox", Vector3(x0 + w - 0.6, 0, z0 + dp - 1.2), -PI * 0.5)
	return []


static func _atelier(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var w := float(r[2])
	var dp := float(r[3])
	var out: Array = []
	for i in clampi(n + 1, 2, int((w - 1.0) / 1.8)):
		var p := Vector3(x0 + 1.2 + i * 1.8, 0, z0 + 0.6)
		GestionModeles.dessiner(k, "etabli", p, 0.0)
		out.append(d._place(p + Vector3(0, 0, 0.9), PI, false))
	d._etagere(k, Vector3(x0 + 0.3, 0, z0 + dp * 0.6), PI * 0.5, dp * 0.5, 1.8, GRIS, [Color("e9c46a"), GRIS, Color("e76f51")])
	return out


static func _labo(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var w := float(r[2])
	var dp := float(r[3])
	var out: Array = []
	for j in clampi(n, 1, 2):
		var z := z0 + 2.4 + j * 2.6
		k.box(Vector3(x0 + w * 0.5, 0.45, z), Vector3(w - 2.0, 0.9, 0.9), BLANC)
		k.box(Vector3(x0 + w * 0.5, 0.92, z), Vector3(w - 1.9, 0.04, 1.0), NOIR)
		for i in int((w - 2.0) / 0.6):
			k.lathe(Vector3(x0 + 1.3 + i * 0.6, 0.94, z), [Vector2(0.0, 0.0), Vector2(0.07, 0.0), Vector2(0.07, 0.12), Vector2(0.02, 0.2), Vector2(0.0, 0.2)], 6, COULEURS[i % COULEURS.size()].lightened(0.3))
		out.append(d._place(Vector3(x0 + w * 0.5, 0, z + 0.9), PI, false))
	if n >= 3:
		GestionModeles.dessiner(k, "microscope", Vector3(x0 + 1.0, 0.92, z0 + 2.4), 0.0)
	return out


static func _soins(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var w := float(r[2])
	var out: Array = []
	for i in clampi(n, 1, int((w - 0.6) / 1.6)):
		var p := Vector3(x0 + 1.0 + i * 1.6, 0, z0 + 1.4)
		GestionModeles.dessiner(k, "lit_hopital", p, 0.0)
		out.append(d._place(p + Vector3(0, 0, 0.1), 0.0, true))
	GestionModeles.dessiner(k, "chariot_soins", Vector3(x0 + w - 0.8, 0, z0 + 4.0), -PI * 0.5)
	return out


static func _reserve(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var w := float(r[2])
	var dp := float(r[3])
	for j in clampi(n, 1, int((dp - 1.5) / 2.2)):
		d._etagere(k, Vector3(x0 + w * 0.5, 0, z0 + 0.5 + j * 2.2), 0.0, w - 1.6, 2.2, GRIS, [Color("cdb38b"), Color("a68a64"), Color("e9c46a")])
	return []


static func _biblio(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var w := float(r[2])
	var dp := float(r[3])
	var out: Array = []
	d._etagere(k, Vector3(x0 + w * 0.5, 0, z0 + 0.3), 0.0, w - 0.8, 2.4, BOIS, COULEURS)
	d._etagere(k, Vector3(x0 + 0.3, 0, z0 + dp * 0.5), PI * 0.5, dp - 3.0, 2.0, BOIS, COULEURS)
	for i in clampi(n, 1, 3):
		var p := Vector3(x0 + 2.2 + i * 2.0, 0, z0 + dp * 0.55)
		if p.x > x0 + w - 1.0:
			break
		_table(k, p, 1.6, 0.9, BOIS_C)
		d._lampe(k, p + Vector3(0, 0.76, 0))
		d._chaise(k, p + Vector3(0, 0, 0.75), PI, BOIS)
		out.append(d._place(p + Vector3(0, 0, 0.75), PI, true))
	return out


static func _vestiaires(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var w := float(r[2])
	var dp := float(r[3])
	for i in int((w - 1.0) / 0.5):
		var c: Color = COULEURS[(i / 4) % COULEURS.size()]
		k.box(Vector3(x0 + 0.8 + i * 0.5, 0.9, z0 + 0.35), Vector3(0.46, 1.8, 0.5), c.darkened(0.1))
	k.box(Vector3(x0 + w * 0.5, 0.22, z0 + dp * 0.45), Vector3(w - 2.0, 0.08, 0.4), BOIS_C)
	if n >= 2:
		for i in mini(n, 4):
			k.box(Vector3(x0 + w - 0.4, 1.8, z0 + 1.5 + i * 1.2), Vector3(0.1, 0.1, 0.1), INOX, 0.0, false)
	return [d._place(Vector3(x0 + w * 0.5, 0, z0 + dp * 0.45 + 0.4), PI, true)]


static func _dortoir(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var w := float(r[2])
	for i in clampi(n + 1, 2, int((w - 0.6) / 1.4)):
		GestionModeles.dessiner(k, "lits_superposes", Vector3(x0 + 0.9 + i * 1.4, 0, z0 + 1.2), 0.0)
	return []


static func _scene(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var w := float(r[2])
	k.box(Vector3(x0 + w * 0.5, 0.35, z0 + 1.4), Vector3(w - 1.0, 0.7, 2.6), BOIS)
	k.box(Vector3(x0 + 0.6, 2.0, z0 + 1.4), Vector3(0.5, 3.6, 2.6), Color("9d0208"))
	k.box(Vector3(x0 + w - 0.6, 2.0, z0 + 1.4), Vector3(0.5, 3.6, 2.6), Color("9d0208"))
	if n >= 3:
		GestionModeles.dessiner(k, "enceinte", Vector3(x0 + 1.2, 0.7, z0 + 2.4), 0.0)
		GestionModeles.dessiner(k, "enceinte", Vector3(x0 + w - 1.2, 0.7, z0 + 2.4), 0.0)
	return _amphi_rangs(d, k, r, n)


static func _amphi_rangs(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var w := float(r[2])
	var dp := float(r[3])
	var out: Array = []
	for j in clampi(n + 1, 2, int((dp - 3.4) / 0.9)):
		var nb := int((w - 2.0) / 0.6)
		for i in nb:
			var p := Vector3(x0 + 1.0 + (i + 0.5) * (w - 2.0) / nb, 0, z0 + 3.6 + j * 0.9)
			d._chaise(k, p, PI, Color("9d0208"))
			if (i + j) % 3 == 0:
				out.append(d._place(p, PI, true))
	return out


# --- Gare --------------------------------------------------------------------------------------

## Quai et voies, avec le train de l'époque (vapeur, autorail, TGV…).
static func _quai(d: GestionDiorama, k: LpKit, r: Array, n: int, style: String) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var w := float(r[2])
	var dp := float(r[3])
	var out: Array = []
	# Quai sur le devant, voies au fond.
	k.box(Vector3(x0 + w * 0.5, 0.45, z0 + dp - 1.6), Vector3(w, 0.9, 3.2), Color("bdb5a6"))
	k.box(Vector3(x0 + w * 0.5, 0.92, z0 + dp - 3.1), Vector3(w, 0.03, 0.2), Color("f4d35e"), 0.0, false)
	var voies := clampi(1 + n / 2, 1, int((dp - 3.6) / 3.2))
	var an := _an()
	for v in voies:
		var vz := z0 + dp - 4.8 - v * 3.2
		k.box(Vector3(x0 + w * 0.5, 0.05, vz), Vector3(w, 0.1, 2.6), Color("8d8478"), 0.0, false)
		for i in int(w / 0.6):
			k.box(Vector3(x0 + 0.3 + i * 0.6, 0.12, vz), Vector3(0.22, 0.06, 2.2), BOIS.darkened(0.3), 0.0, false)
		for sz in [-0.72, 0.72]:
			k.box(Vector3(x0 + w * 0.5, 0.18, vz + sz), Vector3(w, 0.08, 0.08), INOX.darkened(0.3), 0.0, false)
		if v == 0 and style != "vide":
			_train(k, Vector3(x0 + 1.0, 0.2, vz), minf(w - 2.0, 6.0 + 4.0 * n), an)
		if an >= 1920:
			# Caténaire des lignes électrifiées.
			for i in int(w / 8.0) + 1:
				k.box(Vector3(x0 + 0.5 + i * 8.0, 2.6, vz - 1.4), Vector3(0.12, 5.2, 0.12), GRIS, 0.0, false)
			k.box(Vector3(x0 + w * 0.5, 5.0, vz), Vector3(w, 0.03, 0.03), NOIR, 0.0, false)
	# Abri de quai, bancs, horloge.
	for i in clampi(n, 1, int(w / 6.0)):
		var bx := x0 + 3.0 + i * 6.0
		GestionModeles.dessiner(k, "banc", Vector3(bx, 0.9, z0 + dp - 0.9), PI)
		for lp in GestionModeles.places("banc"):
			out.append(d._place(Vector3(bx - float(lp[0]), 0.9, z0 + dp - 0.9), PI, true))
		out.append(d._place(Vector3(bx + 1.6, 0.9, z0 + dp - 2.4), PI, false))
	k.box(Vector3(x0 + w * 0.5, 3.2, z0 + dp - 1.6), Vector3(w, 0.12, 3.4), Color("7b8a8b"))
	for i in int(w / 6.0) + 1:
		k.box(Vector3(x0 + 0.3 + i * 6.0, 2.05, z0 + dp - 0.6), Vector3(0.14, 2.3, 0.14), Color("5c636a"), 0.0, false)
	return out


static func _train(k: LpKit, p: Vector3, l: float, an: int) -> void:
	var c := Color("1d3557")
	if an < 1940:
		# Locomotive à vapeur et voitures en bois.
		k.lathe(p + Vector3(2.2, 1.5, 0), [Vector2(0.0, -1.6), Vector2(0.8, -1.6), Vector2(0.8, 1.6), Vector2(0.0, 1.6)], 12, NOIR)
		k.box(p + Vector3(0.6, 1.6, 0), Vector3(1.3, 2.0, 2.0), NOIR)
		k.tube(p + Vector3(3.4, 2.2, 0), p + Vector3(3.4, 3.1, 0), 0.22, 0.28, 8, NOIR)
		c = Color("6b3e26")
		p.x += 4.2
		l -= 4.2
	elif an < 1981:
		c = Color("2a7d4f") if an < 1965 else Color("c1121f")
	else:
		c = BLANC
	var nb := maxi(1, int(l / 5.2))
	for i in nb:
		var cx := p.x + 2.5 + i * 5.2
		k.box(Vector3(cx, p.y + 1.6, p.z), Vector3(5.0, 2.6, 2.6), c)
		k.layer = "verre"
		k.box(Vector3(cx, p.y + 2.0, p.z + 1.31), Vector3(4.4, 0.7, 0.02), Color(0.5, 0.65, 0.8, 0.7), 0.0, false)
		k.layer = "base"
		if an >= 1981:
			k.box(Vector3(cx, p.y + 1.1, p.z + 1.31), Vector3(5.0, 0.25, 0.02), Color("1d3557"), 0.0, false)


# --- Dehors ------------------------------------------------------------------------------------

## Enclos : sol, clôture, point d'eau, rochers et animaux (un de plus par niveau).
static func _enclos(d: GestionDiorama, k: LpKit, r: Array, n: int, betes: String, sol: String) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var w := float(r[2])
	var dp := float(r[3])
	var col := {"savane": Color("c9b26a"), "roche": Color("9c9488"), "neige": Color("eef4f7"), "foret": Color("4f7d3a"), "boue": Color("7a6244")}.get(sol, HERBE) as Color
	_sol(k, r, col, 0.1)
	_cloture(k, r, BOIS if sol != "neige" else INOX)
	# Point d'eau et rochers.
	k.layer = "eau"
	k.box(Vector3(x0 + w * 0.7, Y + 0.02, z0 + dp * 0.3), Vector3(w * 0.3, 0.02, dp * 0.25), EAU, 0.0, false)
	k.layer = "base"
	k.stone(Vector3(x0 + w * 0.82, 0.4, z0 + dp * 0.7), Vector3(1.4, 0.8, 1.1), Color("8e8a82"))
	k.stone(Vector3(x0 + w * 0.35, 0.3, z0 + dp * 0.2), Vector3(1.0, 0.6, 0.9), Color("8e8a82"))
	if sol != "neige":
		d._arbre(k, Vector3(x0 + w * 0.2, 0, z0 + 1.4), 0.8)
	var ids := _ids(betes, ["zebre"])
	var nb := clampi(n + 1, 1, 7)
	for i in nb:
		var id := String(ids[i % ids.size()])
		var s := clampf(2.4 / maxf(1.0, Decors.emprise(id)), 0.35, 1.0)
		var p := Vector3(x0 + w * (0.3 + 0.5 * fmod(float(i) * 0.37, 1.0)), 0, z0 + dp * (0.3 + 0.5 * fmod(float(i) * 0.61 + 0.2, 1.0)))
		deco(d, id, p, float(i) * 1.7, s)
	# Panneau de l'espèce et visiteurs au bord.
	deco(d, "panneau_espece", Vector3(x0 - 0.4, 0, z0 + dp * 0.3), PI * 0.5)
	return _bord(d, r, 3, -0.6)


## Bassin (otaries, manchots, poissons) avec rochers et plage.
static func _bassin(d: GestionDiorama, k: LpKit, r: Array, n: int, betes: String) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var w := float(r[2])
	var dp := float(r[3])
	_sol(k, r, SABLE, 0.1)
	k.box(Vector3(x0 + w * 0.55, 0.3, z0 + dp * 0.5), Vector3(w * 0.8, 0.6, dp * 0.8), Color("8e9aa3"))
	k.layer = "eau"
	k.box(Vector3(x0 + w * 0.55, 0.55, z0 + dp * 0.5), Vector3(w * 0.75, 0.04, dp * 0.75), EAU, 0.0, false)
	k.layer = "base"
	k.stone(Vector3(x0 + w * 0.75, 0.8, z0 + dp * 0.35), Vector3(1.6, 0.8, 1.4), Color("9c9488"))
	var ids := _ids(betes, ["otarie"])
	for i in clampi(n + 1, 1, 8):
		var id := String(ids[i % ids.size()])
		deco(d, id, Vector3(x0 + w * (0.3 + 0.5 * fmod(float(i) * 0.43, 1.0)), 0.6, z0 + dp * (0.25 + 0.5 * fmod(float(i) * 0.71, 1.0))), float(i) * 2.1, 0.9)
	if n >= 3:
		# Gradins pour le spectacle.
		for j in 3:
			k.box(Vector3(x0 + 0.5 + j * 0.5, 0.2 + j * 0.2, z0 + dp * 0.5), Vector3(0.5, 0.4 + j * 0.4, dp * 0.7), Color("adb5bd"), 0.0, false)
	return _bord(d, r, 4, -0.5)


## Serre (vivarium tropical, serre de la ferme) : verrière et plantes.
static func _serre(d: GestionDiorama, k: LpKit, r: Array, n: int, betes: String) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var w := float(r[2])
	var dp := float(r[3])
	_sol(k, r, Color("6b8f47"), 0.1)
	for i in int(w / 1.5) + 1:
		k.box(Vector3(x0 + i * 1.5, 1.4, z0 + 0.1), Vector3(0.08, 2.8, 0.08), BLANC, 0.0, false)
		k.box(Vector3(x0 + i * 1.5, 1.4, z0 + dp - 0.1), Vector3(0.08, 2.8, 0.08), BLANC, 0.0, false)
	k.layer = "verre"
	k.box(Vector3(x0 + w * 0.5, 1.4, z0 + 0.1), Vector3(w, 2.8, 0.03), Color(0.8, 0.95, 0.9, 0.3), 0.0, false)
	k.box(Vector3(x0 + w - 0.05, 1.4, z0 + dp * 0.5), Vector3(0.03, 2.8, dp), Color(0.8, 0.95, 0.9, 0.3), 0.0, false)
	k.layer = "base"
	for i in clampi(3 + n * 2, 4, 14):
		var p := Vector3(x0 + 1.0 + fmod(float(i) * 1.37, w - 2.0), 0, z0 + 1.0 + fmod(float(i) * 2.11, dp - 2.0))
		k.blob(p + Vector3(0, 0.5, 0), Vector3(0.6, 0.6, 0.6), Color("2d6a4f"), Color("52b788"), 0.25, 0)
	if betes != "":
		var ids := _ids(betes, [])
		for i in clampi(n, 1, 4):
			deco(d, String(ids[i % ids.size()]), Vector3(x0 + w * (0.3 + 0.15 * i), 0, z0 + dp * 0.55), float(i), 0.8)
	return _bord(d, r, 3, 0.8)


## Terrain de sport et tribunes : la taille des tribunes suit la capacité.
static func _terrain(d: GestionDiorama, k: LpKit, r: Array, n: int, sport: String) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var w := float(r[2])
	var dp := float(r[3])
	var out: Array = []
	var tri := 2.0 + 0.4 * n
	var px0 := x0 + tri
	var pw := w - tri * 2.0
	var pz0 := z0 + 0.5
	var pd := dp - tri - 0.5
	var pelouse := Color("4f9d4a") if sport != "athle" else Color("4f9d4a")
	k.box(Vector3(px0 + pw * 0.5, Y * 0.6, pz0 + pd * 0.5), Vector3(pw, 0.02, pd), pelouse, 0.0, false)
	for i in int(pw / 1.5):
		if i % 2 == 0:
			k.box(Vector3(px0 + 0.75 + i * 1.5, Y * 0.6 + 0.004, pz0 + pd * 0.5), Vector3(1.5, 0.01, pd), pelouse.lightened(0.08), 0.0, false)
	if sport == "athle":
		k.box(Vector3(px0 + pw * 0.5, Y * 0.6 + 0.006, pz0 + 0.4), Vector3(pw, 0.012, 0.8), Color("b5523b"), 0.0, false)
		k.box(Vector3(px0 + pw * 0.5, Y * 0.6 + 0.006, pz0 + pd - 0.4), Vector3(pw, 0.012, 0.8), Color("b5523b"), 0.0, false)
	# Lignes blanches.
	var y := Y * 0.6 + 0.012
	k.box(Vector3(px0 + pw * 0.5, y, pz0 + 0.9), Vector3(pw - 1.6, 0.01, 0.06), BLANC, 0.0, false)
	k.box(Vector3(px0 + pw * 0.5, y, pz0 + pd - 0.9), Vector3(pw - 1.6, 0.01, 0.06), BLANC, 0.0, false)
	k.box(Vector3(px0 + 0.8, y, pz0 + pd * 0.5), Vector3(0.06, 0.01, pd - 1.8), BLANC, 0.0, false)
	k.box(Vector3(px0 + pw - 0.8, y, pz0 + pd * 0.5), Vector3(0.06, 0.01, pd - 1.8), BLANC, 0.0, false)
	k.box(Vector3(px0 + pw * 0.5, y, pz0 + pd * 0.5), Vector3(0.06, 0.01, pd - 1.8), BLANC, 0.0, false)
	k.lathe(Vector3(px0 + pw * 0.5, y, pz0 + pd * 0.5), [Vector2(0.9, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 0.01), Vector2(0.9, 0.01)], 20, BLANC)
	match sport:
		"basket":
			deco(d, "panier_basket", Vector3(px0 + 1.0, 0, pz0 + pd * 0.5), PI * 0.5)
			deco(d, "panier_basket", Vector3(px0 + pw - 1.0, 0, pz0 + pd * 0.5), -PI * 0.5)
		"rugby":
			for sx in [px0 + 0.9, px0 + pw - 0.9]:
				for sz in [-0.5, 0.5]:
					k.box(Vector3(sx, 1.6, pz0 + pd * 0.5 + sz), Vector3(0.08, 3.2, 0.08), BLANC, 0.0, false)
				k.box(Vector3(sx, 1.0, pz0 + pd * 0.5), Vector3(0.08, 0.08, 1.0), BLANC, 0.0, false)
		_:
			deco(d, "cage_foot", Vector3(px0 + 0.9, 0, pz0 + pd * 0.5), PI * 0.5, 0.8)
			deco(d, "cage_foot", Vector3(px0 + pw - 0.9, 0, pz0 + pd * 0.5), -PI * 0.5, 0.8)
	# Tribunes en gradins sur trois côtés (devant, gauche, droite).
	var rangs := int(tri / 0.5)
	var coul := Color(String(GestionTypes.genre(d.genre).get("teinte", "1d3557")))
	for j in rangs:
		var h := 0.35 + j * 0.35
		var c := coul.lightened(0.08 * (j % 2))
		k.box(Vector3(px0 + pw * 0.5, h * 0.5, pz0 + pd + 0.25 + j * 0.5), Vector3(pw + j * 1.0, h, 0.5), c)
		k.box(Vector3(px0 - 0.25 - j * 0.5, h * 0.5, pz0 + pd * 0.5), Vector3(0.5, h, pd), c)
		k.box(Vector3(px0 + pw + 0.25 + j * 0.5, h * 0.5, pz0 + pd * 0.5), Vector3(0.5, h, pd), c)
	for i in clampi(4 + n * 2, 4, 16):
		var x := px0 + 1.0 + fmod(float(i) * 1.73, pw - 2.0)
		var j := i % rangs
		out.append(d._place(Vector3(x, 0.35 + j * 0.35, pz0 + pd + 0.25 + j * 0.5), PI, true))
	if n >= 3:
		# Projecteurs aux coins.
		for c2 in [Vector2(x0 + 0.4, z0 + 0.4), Vector2(x0 + w - 0.4, z0 + 0.4)]:
			k.box(Vector3(c2.x, 4.0, c2.y), Vector3(0.2, 8.0, 0.2), GRIS, 0.0, false)
			k.layer = "lumiere"
			k.box(Vector3(c2.x, 8.1, c2.y), Vector3(1.0, 0.5, 0.2), Color("fff3b0"), 0.0, false)
			k.layer = "base"
	if n >= 4:
		# Toit des tribunes.
		k.box(Vector3(px0 + pw * 0.5, 0.35 + rangs * 0.35 + 1.6, pz0 + pd + tri * 0.5), Vector3(pw + rangs, 0.1, tri), INOX.darkened(0.1))
	return out


## Champ : rangs d'une culture (blé, maïs, betteraves, légumes…).
static func _champ(d: GestionDiorama, k: LpKit, r: Array, n: int, culture: String) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var w := float(r[2])
	var dp := float(r[3])
	_sol(k, r, TERRE, 0.1)
	var col := {"ble": Color("e9c46a"), "mais": Color("90be6d"), "legumes": Color("52b788"), "betteraves": Color("6a994e"), "lin": Color("8ecae6"), "colza": Color("ffd60a"), "foin": Color("b5c99a")}.get(culture, Color("e9c46a")) as Color
	for i in int((dp - 0.6) / 0.7):
		k.box(Vector3(x0 + w * 0.5, 0.12 + 0.03 * n, z0 + 0.6 + i * 0.7), Vector3(w - 0.8, 0.2 + 0.06 * n, 0.4), col.darkened(0.05 * (i % 3)))
	if n >= 2:
		deco(d, _tracteur(), Vector3(x0 + w - 2.0, 0, z0 + dp * 0.5), PI * 0.5, 0.8)
	if culture == "legumes" and n >= 3:
		deco(d, "epouvantail", Vector3(x0 + w * 0.4, 0, z0 + dp * 0.4))
	return _bord(d, r, 2, -0.6)


static func _tracteur() -> String:
	var an := _an()
	if an < 1920:
		return "charrette"
	if an < 1960:
		return "tracteur_ancien"
	if an < 2015:
		return "tracteur_rouge"
	return "tracteur_gps"


## Étable ouverte : stalles, foin, animaux de la ferme.
static func _etable(d: GestionDiorama, k: LpKit, r: Array, n: int, betes: String) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var w := float(r[2])
	var dp := float(r[3])
	_sol(k, r, Color("b59a6d"), 0.1)
	# Toit sur poteaux.
	for i in int(w / 3.0) + 1:
		for z in [z0 + 0.2, z0 + dp - 0.2]:
			k.box(Vector3(x0 + 0.2 + i * 3.0, 1.5, z), Vector3(0.2, 3.0, 0.2), BOIS, 0.0, false)
	k.box(Vector3(x0 + w * 0.5, 3.1, z0 + dp * 0.5), Vector3(w + 0.4, 0.15, dp + 0.4), Color("7b2d26"))
	deco(d, "ratelier", Vector3(x0 + w * 0.5, 0, z0 + 0.8))
	deco(d, "abreuvoir", Vector3(x0 + w - 1.2, 0, z0 + dp * 0.5), PI * 0.5)
	var ids := _ids(betes, ["vache_pie_noire", "vache_rousse"])
	for i in clampi(n + 2, 2, 9):
		deco(d, String(ids[i % ids.size()]), Vector3(x0 + 1.4 + fmod(float(i) * 1.9, w - 2.8), 0, z0 + 2.0 + fmod(float(i) * 1.3, dp - 3.2)), PI * (0.5 if i % 2 == 0 else -0.5))
	if n >= 3:
		deco(d, "bidons_lait" if _an() < 1970 else "citerne", Vector3(x0 + 1.0, 0, z0 + dp - 1.0))
	return _bord(d, r, 2, -0.6)


static func _cour(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var w := float(r[2])
	var dp := float(r[3])
	_sol(k, r, Color("b7b0a3"), 0.05)
	# Marelle, préau, panier de basket, arbres.
	for i in 6:
		k.box(Vector3(x0 + 2.0, Y + 0.01, z0 + 1.5 + i * 0.6), Vector3(0.55, 0.01, 0.55), BLANC if i % 2 == 0 else Color("ffd166"), 0.0, false)
	deco(d, "panier_basket", Vector3(x0 + w - 1.2, 0, z0 + dp * 0.5), -PI * 0.5)
	d._arbre(k, Vector3(x0 + w * 0.5, 0, z0 + 1.2), 0.9)
	if n >= 2:
		deco(d, "balancoire", Vector3(x0 + w * 0.5, 0, z0 + dp - 2.0))
	if n >= 3:
		k.box(Vector3(x0 + w * 0.3, 2.8, z0 + 1.6), Vector3(w * 0.5, 0.12, 3.0), Color("7b2d26"))
		for sx in [x0 + 0.6, x0 + w * 0.55 - 0.1]:
			k.box(Vector3(sx, 1.4, z0 + 2.9), Vector3(0.15, 2.8, 0.15), GRIS, 0.0, false)
	if n >= 4:
		deco(d, "ping_pong", Vector3(x0 + w * 0.5, 0, z0 + dp * 0.55))
	var out: Array = []
	for i in 4:
		out.append(d._place(Vector3(x0 + 1.5 + i * (w - 3.0) / 3.0, 0, z0 + dp * 0.6), float(i) * 1.6, false))
	return out


static func _jardin(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var w := float(r[2])
	var dp := float(r[3])
	_sol(k, r, HERBE, 0.05)
	k.box(Vector3(x0 + w * 0.5, Y + 0.01, z0 + dp * 0.5), Vector3(w - 1.0, 0.01, 1.0), Color("e3d5b8"), 0.0, false)
	for i in clampi(n + 1, 2, 6):
		d._arbre(k, Vector3(x0 + 1.0 + fmod(float(i) * 2.7, w - 2.0), 0, z0 + (1.2 if i % 2 == 0 else dp - 1.2)), 0.8)
	var out: Array = []
	for i in clampi(n, 1, 3):
		var bx := x0 + 2.0 + i * 2.6
		if bx > x0 + w - 1.5:
			break
		GestionModeles.dessiner(k, "banc", Vector3(bx, 0, z0 + dp * 0.5 - 1.0), 0.0)
		out.append(d._place(Vector3(bx - 0.4, 0, z0 + dp * 0.5 - 1.0), 0.0, true))
	if n >= 3:
		deco(d, "fontaine", Vector3(x0 + w * 0.5, 0, z0 + dp * 0.5))
	if n >= 4:
		deco(d, "kiosque_musique", Vector3(x0 + w - 2.5, 0, z0 + 2.5), 0.0, 0.7)
	return out


static func _parking(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var w := float(r[2])
	var dp := float(r[3])
	_sol(k, r, Color("5f6368"), 0.05)
	var nb := int((w - 0.6) / 2.6)
	for i in nb + 1:
		k.box(Vector3(x0 + 0.3 + i * 2.6, Y + 0.01, z0 + 2.2), Vector3(0.08, 0.01, 3.6), BLANC, 0.0, false)
	var an := _an()
	for i in clampi(n + 1, 1, nb):
		var p := Vector3(x0 + 1.6 + i * 2.6, 0, z0 + 2.2)
		if an < 1905:
			deco(d, "charrette", p, PI * 0.5, 0.8)
		else:
			GestionModeles.dessiner(k, "voiture", p, PI * 0.5, COULEURS[i % COULEURS.size()])
	if n >= 3 and an >= 1950:
		deco(d, "abribus" if an < 2000 else "abribus_moderne", Vector3(x0 + w * 0.5, 0, z0 + dp - 1.0), PI)
	return []


## Chai : cuves (inox après 1960, bois avant) et rangées de tonneaux.
static func _cuves(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var w := float(r[2])
	var dp := float(r[3])
	var out: Array = []
	var inox := _an() >= 1960
	for i in clampi(n + 1, 2, int((w - 1.0) / 1.5)):
		var p := Vector3(x0 + 1.0 + i * 1.5, 0, z0 + 1.0)
		if inox:
			k.lathe(p, [Vector2(0.0, 0.0), Vector2(0.6, 0.0), Vector2(0.6, 2.4), Vector2(0.3, 2.7), Vector2(0.0, 2.7)], 12, INOX)
		else:
			k.lathe(p, [Vector2(0.0, 0.0), Vector2(0.65, 0.0), Vector2(0.72, 1.0), Vector2(0.65, 2.0), Vector2(0.0, 2.0)], 12, BOIS)
	for i in clampi(n, 1, int((w - 1.0) / 1.4)):
		deco(d, "tonneaux", Vector3(x0 + 1.0 + i * 1.4, 0, z0 + dp - 1.6))
	out.append(d._place(Vector3(x0 + w * 0.5, 0, z0 + dp * 0.55), PI, false))
	return out


static func _vigne(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var w := float(r[2])
	var dp := float(r[3])
	_sol(k, r, Color("a68a64"), 0.1)
	for j in int((dp - 0.6) / 1.2):
		for i in int((w - 0.8) / 1.9):
			deco(d, "vigne_piquets", Vector3(x0 + 1.2 + i * 1.9, 0, z0 + 0.8 + j * 1.2), 0.0)
	if n >= 3:
		deco(d, "vendangeuse" if _an() >= 1975 else "charrette", Vector3(x0 + w - 1.5, 0, z0 + dp - 1.2), PI * 0.5, 0.7)
	return _bord(d, r, 2, -0.6)


## Hangar à machines : les engins de l'époque.
static func _machines(d: GestionDiorama, k: LpKit, r: Array, n: int, ids_txt: String) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var w := float(r[2])
	var dp := float(r[3])
	_sol(k, r, Color("8d8478"), 0.05)
	k.box(Vector3(x0 + w * 0.5, 3.6, z0 + dp * 0.5), Vector3(w, 0.12, dp), Color("6c757d"))
	for c in [Vector2(x0 + 0.2, z0 + 0.2), Vector2(x0 + w - 0.2, z0 + 0.2), Vector2(x0 + 0.2, z0 + dp - 0.2), Vector2(x0 + w - 0.2, z0 + dp - 0.2)]:
		k.box(Vector3(c.x, 1.8, c.y), Vector3(0.2, 3.6, 0.2), GRIS, 0.0, false)
	var ids := _ids(ids_txt, [_tracteur(), "remorque_foin", "moissonneuse", "charrue"])
	for i in clampi(n, 1, ids.size()):
		deco(d, String(ids[i]) if i > 0 else _tracteur(), Vector3(x0 + 2.0 + i * 3.2, 0, z0 + dp * 0.5), PI * 0.5, 0.8)
	return []
