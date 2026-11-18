class_name VoieMesh
extends RefCounted
## Dessin des attractions sur voie : rails (acier tubulaire, bois, mine),
## canaux (bûches, rivière, bateau splash), tube de toboggan, piliers jusqu'au
## sol, tunnels, chaînes, freins ; gares (bâtiments du catalogue) et voitures.
##
## Tout est en couleurs par sommet (même matériau que les autres objets du parc).

const COULEURS := {
	"rail": [Color("d62828"), Color("277da1"), Color("ffc93c"), Color("43aa8b"), Color("7b2cbf"), Color("f77f00"), Color("f8f4ea"), Color("2b2d42")],
	"support": [Color("f8f4ea"), Color("adb5bd"), Color("2b2d42"), Color("ffc93c"), Color("9c6644"), Color("277da1")],
	"train": [Color("ffc93c"), Color("d62828"), Color("277da1"), Color("43aa8b"), Color("f78fb3"), Color("2b2d42"), Color("f8f4ea")],
}
const BOIS := Color("a5794f")
const BOIS_F := Color("7a5534")
const BETON := Color("bdb6a8")
const EAU := Color("3f9ed8")
const ECUME := Color("e8f6ff")
const ACIER := Color("8d99ae")
const NOIR := Color("2b2d42")
const PEAUX := [Color("f6dccb"), Color("e5b48f"), Color("c98f67"), Color("a06743"), Color("75472d")]


static func couleur(design: Dictionary, quoi: String) -> Color:
	var pal: Array = COULEURS[quoi]
	var defaut := {"rail": 0, "support": 0, "train": 0}
	var fam := VoiePieces.style(String(design.get("famille", "acier")))
	if quoi == "support" and fam in ["bois", "mine"]:
		return BOIS
	return pal[clampi(int(design.get("c_" + quoi, defaut[quoi])), 0, pal.size() - 1)]


## Maillage de la voie (repère de la gare). sol : Callable(Vector3 local) -> float, hauteur
## locale du sol sous ce point (NAN si inconnue : pas de piliers).
static func voie(design: Dictionary, tr: Dictionary, sim: Dictionary, sol: Callable, fantome := false) -> ArrayMesh:
	var k := BlocMesh.new()
	var fam := VoiePieces.famille(String(design.get("famille", "acier")))
	var fam_id := VoiePieces.style(String(design.get("famille", "acier")))
	var P: PackedVector3Array = tr.P
	var n := P.size()
	if n < 2:
		return k.to_mesh()
	var U: PackedVector3Array = sim.get("Ub", tr.U)
	var R: PackedVector3Array = sim.get("Rb", tr.R)
	if U.size() != n:
		U = tr.U
		R = tr.R
	var c_rail := couleur(design, "rail")
	var c_sup := couleur(design, "support")
	if fantome:
		c_rail = Color("ffd166")
		c_sup = Color("ffe8a3")
	var genre := String(fam.genre)
	var pas := 2  # un anneau tous les 2 échantillons (1 m)
	var idx := []
	for i in range(0, n, pas):
		idx.append(i)
	if idx[idx.size() - 1] != n - 1:
		idx.append(n - 1)
	match genre:
		"eau":
			_canal(k, tr, P, U, R, idx, fam, c_rail)
		"glisse":
			_tube(k, P, U, R, idx, 0.95, c_rail, PI * 0.95, true)
		_:
			_rails(k, tr, P, U, R, idx, fam_id, fam, c_rail)
	_speciaux(k, tr, P, U, R, idx, fam, genre)
	if sol.is_valid():
		_piliers(k, tr, P, U, R, fam_id, fam, c_sup, sol)
	return k.to_mesh(ParcTypes.material())


## Anneau de `sides` points autour de c dans le plan (u, r).
static func _anneau(c: Vector3, u: Vector3, r: Vector3, rayon: float, sides: int, a0 := 0.0, ouverture := TAU) -> Array:
	var out := []
	for s in sides + (1 if ouverture < TAU else 0):
		var a := a0 + ouverture * s / sides
		out.append(c + (u * cos(a) + r * sin(a)) * rayon)
	return out


## Tube le long des points (indices idx), décalé de off_u (vers le haut) et off_r (vers la droite).
static func _tube_le_long(k: BlocMesh, P: PackedVector3Array, U: PackedVector3Array, R: PackedVector3Array, idx: Array,
		off_u: float, off_r: float, rayon: float, sides: int, col: Color) -> void:
	var prev := []
	var prev_c := Vector3.ZERO
	for j in idx.size():
		var i: int = idx[j]
		var c := P[i] + U[i] * off_u + R[i] * off_r
		var ring := _anneau(c, U[i], R[i], rayon, sides)
		if j > 0:
			for s in sides:
				var s1 := (s + 1) % sides
				var mid: Vector3 = (prev[s] + ring[s1]) / 2.0
				k.quad(prev[s], prev[s1], ring[s1], ring[s], (mid - (prev_c + c) / 2.0).normalized(), col if s % 2 == 0 else col.darkened(0.08))
		prev = ring
		prev_c = c


static func _rails(k: BlocMesh, tr: Dictionary, P: PackedVector3Array, U: PackedVector3Array, R: PackedVector3Array, idx: Array,
		fam_id: String, fam: Dictionary, col: Color) -> void:
	var susp := bool(fam.get("suspendu", false))
	var ecart := 0.55 if fam_id != "familial" else 0.42
	match fam_id:
		"bois", "mine":
			# Planches et rails plats, traverses en bois.
			var c_bois := BOIS if fam_id == "bois" else BOIS_F
			_ruban(k, P, U, R, idx, -0.18, 1.7, 0.16, c_bois)
			_tube_le_long(k, P, U, R, idx, 0.0, -ecart, 0.07, 4, ACIER)
			_tube_le_long(k, P, U, R, idx, 0.0, ecart, 0.07, 4, ACIER)
			_traverses(k, P, U, R, -0.12, ecart + 0.25, 1.2, BOIS_F if fam_id == "bois" else c_bois.darkened(0.2))
		_:
			var sens := 1.0 if not susp else -1.0
			_tube_le_long(k, P, U, R, idx, 0.0, -ecart, 0.1, 6, col)
			_tube_le_long(k, P, U, R, idx, 0.0, ecart, 0.1, 6, col)
			var spine := 0.32 if fam_id != "familial" else 0.18
			_tube_le_long(k, P, U, R, idx, -0.6 * sens if not susp else 0.55, 0.0, spine, 8, col.darkened(0.12))
			# Traverses : des rails vers la poutre centrale.
			for j in range(0, idx.size(), 2):
				var i: int = idx[j]
				var c := P[i] + U[i] * (-0.6 if not susp else 0.55)
				ParcTypes.beam(k, P[i] - R[i] * ecart, c, 0.1, col.darkened(0.2))
				ParcTypes.beam(k, P[i] + R[i] * ecart, c, 0.1, col.darkened(0.2))


## Ruban plat (planches, fond de canal) : largeur l, épaisseur e, décalé de off_u.
static func _ruban(k: BlocMesh, P: PackedVector3Array, U: PackedVector3Array, R: PackedVector3Array, idx: Array,
		off_u: float, l: float, e: float, col: Color) -> void:
	for j in range(1, idx.size()):
		var a: int = idx[j - 1]
		var b: int = idx[j]
		var ca := P[a] + U[a] * off_u
		var cb := P[b] + U[b] * off_u
		var la := R[a] * (l / 2.0)
		var lb := R[b] * (l / 2.0)
		k.quad(ca - la, ca + la, cb + lb, cb - lb, U[a], col)
		k.quad(ca - la - U[a] * e, ca + la - U[a] * e, cb + lb - U[b] * e, cb - lb - U[b] * e, -U[a], col.darkened(0.15))
		k.quad(ca + la, ca + la - U[a] * e, cb + lb - U[b] * e, cb + lb, R[a], col.darkened(0.08))
		k.quad(ca - la, ca - la - U[a] * e, cb - lb - U[b] * e, cb - lb, -R[a], col.darkened(0.08))


static func _traverses(k: BlocMesh, P: PackedVector3Array, U: PackedVector3Array, R: PackedVector3Array, off_u: float, demi: float, pas_m: float, col: Color) -> void:
	var step := maxi(1, roundi(pas_m / VoiePieces.PAS))
	for i in range(0, P.size(), step):
		var c := P[i] + U[i] * off_u
		ParcTypes.beam(k, c - R[i] * demi, c + R[i] * demi, 0.16, col)


static func _canal(k: BlocMesh, tr: Dictionary, P: PackedVector3Array, U: PackedVector3Array, R: PackedVector3Array, idx: Array,
		fam: Dictionary, col: Color) -> void:
	var large := 5.6 if bool(fam.get("large", false)) else (4.4 if float(fam.lv) > 6.0 else 2.8)
	var h := 1.1
	var paroi := col.lightened(0.35) if col.v < 0.6 else col
	paroi = BETON.lerp(paroi, 0.35)
	_ruban(k, P, U, R, idx, -0.55, large + 0.4, 0.3, paroi.darkened(0.1))
	for j in range(1, idx.size()):
		var a: int = idx[j - 1]
		var b: int = idx[j]
		for cote: float in [-1.0, 1.0]:
			var oa := P[a] + R[a] * (large / 2.0 * cote) + U[a] * -0.55
			var ob := P[b] + R[b] * (large / 2.0 * cote) + U[b] * -0.55
			var ta := oa + U[a] * h
			var tb := ob + U[b] * h
			k.quad(oa, ob, tb, ta, -R[a] * cote, paroi)
			var ea := R[a] * (0.2 * cote)
			var eb := R[b] * (0.2 * cote)
			k.quad(oa + ea, ob + eb, tb + eb, ta + ea, R[a] * cote, paroi.darkened(0.12))
			k.quad(ta, tb, tb + eb, ta + ea, U[a], paroi.lightened(0.1))
		# Eau.
		var wa := P[a] + U[a] * 0.05
		var wb := P[b] + U[b] * 0.05
		var la := R[a] * (large / 2.0)
		var lb := R[b] * (large / 2.0)
		var sp := String(tr.special[a])
		var ce := ECUME if sp in ["rapides", "eclabousse", "tourbillon"] or absf((tr.F as PackedVector3Array)[a].y) > 0.3 else EAU
		if (tr.chaine as PackedByteArray)[a] == 1:
			ce = NOIR
		k.quad(wa - la, wa + la, wb + lb, wb - lb, U[a], ce)


## Demi-tube (toboggan) : rayon r, ouverture `ouv` (radians) centrée vers le bas.
static func _tube(k: BlocMesh, P: PackedVector3Array, U: PackedVector3Array, R: PackedVector3Array, idx: Array,
		rayon: float, col: Color, ouv: float, interieur: bool) -> void:
	var sides := 10
	var prev := []
	for j in idx.size():
		var i: int = idx[j]
		var c := P[i] + U[i] * (rayon * 0.75)
		var ring := _anneau(c, U[i], R[i], rayon, sides, PI - ouv, ouv * 2.0)
		if j > 0:
			for s in sides:
				var mid: Vector3 = (prev[s] + ring[s + 1]) / 2.0
				var nrm := (mid - c).normalized()
				var cc := col if (s + j / 4) % 2 == 0 else col.lightened(0.25)
				k.quad(prev[s], prev[s + 1], ring[s + 1], ring[s], nrm, cc)
				if interieur:
					k.quad(prev[s], ring[s], ring[s + 1], prev[s + 1], -nrm, EAU.lightened(0.2) if s in [4, 5] else cc.lightened(0.1))
		prev = ring


static func _speciaux(k: BlocMesh, tr: Dictionary, P: PackedVector3Array, U: PackedVector3Array, R: PackedVector3Array, idx: Array,
		fam: Dictionary, genre: String) -> void:
	var sp: Array = tr.special
	var ch: PackedByteArray = tr.chaine
	for i in range(0, P.size(), 2):
		var s := String(sp[i])
		if genre == "rail" and ch[i] == 1:
			ParcTypes.beam(k, P[i] - (tr.F as PackedVector3Array)[i] * 0.5 + U[i] * 0.05, P[i] + (tr.F as PackedVector3Array)[i] * 0.5 + U[i] * 0.05, 0.12, NOIR)
		match s:
			"freins":
				ParcTypes.beam(k, P[i] + U[i] * 0.12 - R[i] * 0.2, P[i] + U[i] * 0.12 + R[i] * 0.2, 0.18, Color("ffc93c"))
			"lanceur":
				ParcTypes.beam(k, P[i] + U[i] * 0.12 - R[i] * 0.25, P[i] + U[i] * 0.12 + R[i] * 0.25, 0.14, Color("4cc9f0"))
			"tunnel":
				if i % 4 == 0:
					var arc := _anneau(P[i] + U[i] * 0.8, U[i], R[i], 2.8, 6, -PI / 2.0, PI)
					var nx := mini(i + 4, P.size() - 1)
					var arc2 := _anneau(P[nx] + U[nx] * 0.8, U[nx], R[nx], 2.8, 6, -PI / 2.0, PI)
					for a in 6:
						var mid: Vector3 = (arc[a] + arc2[a + 1]) / 2.0
						var nrm := (mid - P[i]).normalized()
						k.quad(arc[a], arc[a + 1], arc2[a + 1], arc2[a], nrm, Color("6b705c") if a % 2 == 0 else Color("5c6150"))
						k.quad(arc[a], arc2[a], arc2[a + 1], arc[a + 1], -nrm, Color("3d405b"))
			"rapides":
				if i % 6 == 0:
					var off := R[i] * (sin(i * 1.7) * 1.4)
					k.box(P[i].x + off.x, P[i].y - 0.3, P[i].z + off.z, 0.8, 0.5, 0.7, Color("8d8d8d"))
			"arrivee":
				if i % 20 == 0:
					var c := P[i]
					k.cylinder(c.x, c.y - 0.9, c.z, 6.0, 6.0, 0.9, 16, Color("e9ecef"))
					k.cylinder(c.x, c.y - 0.05, c.z, 5.6, 5.6, 0.06, 16, EAU)


## Piliers du sol jusqu'à la voie (tous les 6 à 8 m).
static func _piliers(k: BlocMesh, tr: Dictionary, P: PackedVector3Array, U: PackedVector3Array, R: PackedVector3Array,
		fam_id: String, fam: Dictionary, col: Color, sol: Callable) -> void:
	var genre := String(fam.genre)
	var bois := fam_id in ["bois", "mine"]
	var pas_m := 4.0 if bois else (6.0 if genre != "rail" else 7.0)
	var step := maxi(1, roundi(pas_m / VoiePieces.PAS))
	var susp := bool(fam.get("suspendu", false))
	var sp: Array = tr.special
	for i in range(step / 2, P.size(), step):
		if String(sp[i]) == "gare" or String(sp[i]) == "tunnel":
			continue
		var bas := P[i] + U[i] * (-0.95 if not susp else 0.9)
		if genre == "eau":
			bas = P[i] - U[i] * 0.85
		elif genre == "glisse":
			bas = P[i] - U[i] * 0.3
		if U[i].y < 0.0 and not susp:
			bas = P[i] + U[i] * 0.6  # à l'envers : le pilier prend la poutre par en haut
		var g: float = sol.call(bas)
		if is_nan(g):
			continue
		var h := bas.y - g
		if h < 0.6:
			continue
		if susp:
			# Pilier sur le côté, bras au-dessus du rail.
			var cote := Vector3(R[i].x, 0, R[i].z).normalized() * 2.8
			var pied := Vector3(P[i].x + cote.x, g, P[i].z + cote.z)
			var haut := P[i] + U[i] * 1.2
			k.cylinder(pied.x, g, pied.z, 0.32, 0.26, maxf(haut.y - g, 0.5), 6, col)
			ParcTypes.beam(k, Vector3(pied.x, haut.y, pied.z), haut, 0.3, col)
			k.box(pied.x, g - 0.2, pied.z, 1.0, 0.4, 1.0, BETON)
		elif bois:
			# Chevalet : deux poteaux et une croix de Saint-André.
			var lat := Vector3(R[i].x, 0, R[i].z).normalized() * (1.3 + h * 0.08)
			var a := Vector3(bas.x, g, bas.z) - lat
			var b := Vector3(bas.x, g, bas.z) + lat
			ParcTypes.beam(k, a, bas - lat * 0.6, 0.22, col)
			ParcTypes.beam(k, b, bas + lat * 0.6, 0.22, col)
			var etages := maxi(1, int(h / 4.0))
			for e in etages:
				var y0 := g + h * e / etages
				var y1 := g + h * (e + 1) / etages
				var f0 := 1.0 - 0.4 * (y0 - g) / h
				var f1 := 1.0 - 0.4 * (y1 - g) / h
				var p0 := Vector3(bas.x, y0, bas.z)
				var p1 := Vector3(bas.x, y1, bas.z)
				ParcTypes.beam(k, p0 - lat * f0, p1 + lat * f1, 0.12, col.darkened(0.15))
				ParcTypes.beam(k, p0 + lat * f0, p1 - lat * f1, 0.12, col.darkened(0.15))
				ParcTypes.beam(k, p1 - lat * f1, p1 + lat * f1, 0.14, col.darkened(0.1))
		else:
			var r := 0.36 if genre == "rail" else (0.5 if genre == "eau" else 0.2)
			k.cylinder(bas.x, g, bas.z, r, r * 0.85, h, 8, col if genre != "eau" else BETON)
			k.box(bas.x, g - 0.25, bas.z, r * 3.0, 0.45, r * 3.0, BETON)


# --- Gares (bâtiments du catalogue) -------------------------------------------------------------

## Emprise de la gare (cases) : la voie la traverse sur sa longueur.
static func emprise(fam_id: String) -> Vector2i:
	var f := VoiePieces.famille(fam_id)
	var w := ceili(float(f.gare)) + 4
	var d := 12 if String(f.genre) == "rail" else 14
	return Vector2i(w, d)


## Modèle de la gare (repère du bâtiment, sol en 0, entrée vers −Z).
static func gare(k: BlocMesh, t: Dictionary) -> void:
	var f := VoiePieces.famille(String(t.get("voie_famille", "acier")))
	var fam_id := VoiePieces.style(String(t.get("voie_famille", "acier")))
	var w := float(t.get("w", 28))
	var d := float(t.get("d", 12))
	var genre := String(f.genre)
	var col: Color = t.get("voie_couleur", Color("d62828"))
	var hq := float(f.h_gare)
	k.plate(0, 0, w, d, Color("d8cbb3"))
	match genre:
		"glisse":
			# Tour de départ : quatre poteaux, plateforme, escalier tournant, toit.
			var h := hq
			for x: float in [-2.6, 2.6]:
				for z: float in [-0.6, 5.2]:
					k.box(x, 0, z, 0.35, h + 2.6, 0.35, Color("f8f4ea"))
			k.box(0, h - 0.4, 2.3, 6.2, 0.4, 6.6, Color("adb5bd"))
			ParcTypes.chapiteau(k, 0, h + 2.6, 2.3, 4.2, 2.0, 8, col, Color("f8f4ea"))
			var marches := int(h / 0.25)
			for m in marches:
				var a := TAU * m / 24.0
				k.box(cos(a) * 2.2 - 0.2, m * 0.25, -3.8 + sin(a) * 1.6, 1.2, 0.12, 0.5, Color("ffc93c"))
			k.box(0, 0, -3.8, 0.4, h, 0.4, Color("f8f4ea"))
			k.cylinder(3.8, 0, -2.0, 0.9, 0.9, 2.2, 8, Color("4fb3d9"))
		"eau":
			# Quai en bois le long du canal, auvent, bassin.
			k.box(0, 0, 2.5, w - 2.0, 0.3, 6.4, BETON)
			k.box(0, 0.3, -1.0, w - 3.0, 0.5, 3.2, BOIS)
			for x in range(int(-w / 2.0 + 2.0), int(w / 2.0 - 1.0), 4):
				k.box(x, 0.8, -2.4, 0.25, 3.4, 0.25, BOIS_F)
				k.box(x, 0.8, 5.2, 0.25, 3.4, 0.25, BOIS_F)
			k.gable(0, 4.2, 1.4, w - 2.0, 9.4, 2.2, col.darkened(0.1), true)
			_panneau(k, -w / 2.0 + 3.0, -d / 2.0 + 0.6, col)
		_:
			# Quai, garde-corps, grand toit sur poteaux, guichet d'entrée.
			var yq := maxf(hq - 0.35, 0.2)
			k.box(0, 0, -0.6, w - 2.0, yq, 3.6, Color("bfb6a3"))
			if hq > 2.0:
				# Gare en hauteur : escalier côté entrée.
				for m in int(yq / 0.3):
					k.box(-w / 2.0 + 3.0, m * 0.3, -5.0 + m * 0.3 * 0.9, 2.2, 0.3, 0.6, Color("adb5bd"))
			for x in range(int(-w / 2.0 + 1.5), int(w / 2.0), 3):
				k.box(x, yq, -2.3, 0.08, 1.0, 0.08, Color("f8f4ea"))
			k.box(0, yq + 0.95, -2.3, w - 3.0, 0.08, 0.08, Color("f8f4ea"))
			var htoit := hq + 4.2
			for x: float in [-w / 2.0 + 1.5, 0.0, w / 2.0 - 1.5]:
				k.box(x, 0, -2.0, 0.3, htoit, 0.3, col.darkened(0.2))
				k.box(x, 0, 5.0, 0.3, htoit, 0.3, col.darkened(0.2))
			k.box(0, htoit, 1.5, w - 1.0, 0.35, 8.6, col)
			k.box(0, htoit + 0.35, 1.5, w - 3.0, 0.6, 6.6, col.lightened(0.2))
			_panneau(k, -w / 2.0 + 3.0, -d / 2.0 + 0.6, col)


static func _panneau(k: BlocMesh, x: float, z: float, col: Color) -> void:
	k.box(x, 0, z, 0.15, 3.2, 0.15, Color("6c757d"))
	k.box(x + 1.4, 0, z, 0.15, 3.2, 0.15, Color("6c757d"))
	k.box(x + 0.7, 2.2, z, 1.9, 1.0, 0.12, col)
	k.box(x + 0.7, 2.45, z - 0.07, 1.4, 0.5, 0.02, Color("f8f4ea"))


# --- Voitures ------------------------------------------------------------------------------------

## Maillage d'une voiture (avant vers −Z, roues sur y = 0 = rail). occupe : passagers assis.
static func voiture(design: Dictionary, occupe: bool, tete := false) -> ArrayMesh:
	var k := BlocMesh.new()
	var f := VoiePieces.famille(String(design.get("famille", "acier")))
	var fam_id := VoiePieces.style(String(design.get("famille", "acier")))
	var col := couleur(design, "train")
	var lv := float(f.lv)
	var places := int(f.places)
	var rangs := maxi(1, places / 2) if fam_id != "riviere" else 1
	match String(f.genre):
		"eau":
			match fam_id:
				"buches":
					k.box(0, -0.35, 0, 1.3, 0.7, lv * 0.9, BOIS)
					k.box(0, 0.35, -lv * 0.42, 1.1, 0.25, 0.4, BOIS_F)
					k.box(0, 0.05, 0, 0.9, 0.35, lv * 0.7, BOIS_F)
					if occupe:
						for r in 4:
							_passager(k, 0, 0.1, -lv * 0.3 + r * lv * 0.2, r)
				"riviere":
					k.cylinder(0, -0.3, 0, 1.9, 1.9, 0.75, 12, Color("2b2d42"))
					k.cylinder(0, 0.45, 0, 1.95, 1.8, 0.12, 12, col)
					k.cylinder(0, -0.2, 0, 0.6, 0.6, 0.9, 8, col.lightened(0.2))
					if occupe:
						for r in 8:
							var a := TAU * r / 8.0
							_passager(k, cos(a) * 1.25, 0.0, sin(a) * 1.25, r)
				_:
					k.box(0, -0.5, 0, 3.6, 1.0, lv, col)
					k.box(0, 0.5, -lv / 2.0 + 0.6, 3.4, 0.4, 1.0, col.lightened(0.2))
					for r in 5:
						k.box(0, 0.0, -lv / 2.0 + 1.6 + r * 1.3, 3.2, 0.5, 0.2, col.darkened(0.2))
						if occupe:
							for c in 4:
								_passager(k, -1.2 + c * 0.8, 0.0, -lv / 2.0 + 1.9 + r * 1.3, r * 4 + c)
		"glisse":
			k.box(0, 0.0, 0, 0.8, 0.08, 1.4, col)
			if occupe:
				_passager(k, 0, 0.05, 0.1, int(design.get("graine", 0)))
		_:
			if bool(f.get("suspendu", false)):
				# Sièges pendus sous le rail.
				k.box(0, 0.2, 0, 0.5, 0.5, lv * 0.7, ACIER)
				ParcTypes.beam(k, Vector3(0, 0.2, 0), Vector3(0, -1.6, 0), 0.22, ACIER)
				k.box(0, -2.1, 0, 2.6, 0.5, 0.8, col)
				k.box(0, -2.1, 0.35, 2.6, 1.3, 0.2, col.darkened(0.15))
				if occupe:
					for c in 4:
						_passager(k, -0.95 + c * 0.63, -2.1 + 0.1, 0.0, c, true)
			else:
				var larg := 1.5 if fam_id != "familial" else 1.0
				k.box(0, 0.15, 0, larg * 0.7, 0.35, lv * 0.8, NOIR)
				k.box(0, 0.45, 0, larg, 0.55, lv * 0.9, col)
				for r in rangs:
					var z := -lv * 0.25 + r * (lv * 0.5 / maxf(rangs - 1, 1))
					if rangs == 1:
						z = 0.0
					k.box(0, 1.0, z + 0.35, larg * 0.95, 0.6, 0.15, col.darkened(0.2))
					if occupe:
						for c in 2:
							_passager(k, -larg * 0.25 + c * larg * 0.5, 0.9, z, r * 2 + c)
				if tete:
					k.box(0, 0.45, -lv * 0.48, larg * 0.9, 0.7, 0.4, col.lightened(0.25))
					if fam_id == "familial":
						k.box(-0.25, 1.0, -lv * 0.5, 0.18, 0.18, 0.1, Color.WHITE)
						k.box(0.25, 1.0, -lv * 0.5, 0.18, 0.18, 0.1, Color.WHITE)
				if fam_id == "mine":
					k.box(0, 0.45, 0, larg + 0.1, 0.12, lv * 0.92, BOIS_F)
	return k.to_mesh(ParcTypes.material())


static func _passager(k: BlocMesh, x: float, y: float, z: float, graine: int, pendu := false) -> void:
	var peau: Color = PEAUX[graine % PEAUX.size()]
	var habit: Color = VoieMesh.COULEURS.train[(graine * 3 + 1) % 7]
	if pendu:
		k.box(x, y - 0.6, z - 0.1, 0.16, 0.6, 0.16, Color("2b2d42"))
	k.box(x, y, z, 0.42, 0.55, 0.32, habit)
	k.box(x, y + 0.55, z, 0.26, 0.28, 0.26, peau)
