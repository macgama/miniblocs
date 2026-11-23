class_name DecorsRestaurant
extends RefCounted
## Décors de base des pièces du restaurant (GestionDiorama les appelle pour
## les décors qu'il n'a pas lui-même). Chaque fonction meuble la pièce selon
## son niveau et renvoie les places des clients ({pos, rot, assis, avant}).
## Coordonnées absolues du plan (r = [x, z, largeur, profondeur]).

const INOX := Color("c9ced3")
const BOIS := Color("8a5a3b")
const BOIS_FONCE := Color("5c4033")


static func dessiner(d: GestionDiorama, k: LpKit, decor: String, r: Array, n: int) -> Array:
	match decor:
		"resto_accueil":
			return _accueil(d, k, r, n)
		"resto_salle":
			return _salle(d, k, r, n)
		"resto_cuisine":
			return _cuisine(d, k, r, n)
		"resto_plonge":
			return _plonge(d, k, r, n)
		"resto_reserve":
			return _reserve(d, k, r, n)
		"resto_bureau":
			return _bureau(d, k, r, n)
		"resto_bar":
			return _bar(d, k, r, n)
		"resto_toilettes":
			return _toilettes(d, k, r, n)
		"resto_salon":
			return _salon(d, k, r, n)
		"resto_cave":
			return _cave(d, k, r, n)
		"resto_patisserie":
			return _patisserie(d, k, r, n)
		"resto_terrasse":
			return _terrasse(d, k, r, n)
		"resto_potager":
			return _potager(d, k, r, n)
		"resto_livraison":
			return _livraison(d, k, r, n)
	return DecorsCaserne.dessiner(d, k, decor, r, n)


static func _a(d: GestionDiorama, pid: String, oid: String) -> bool:
	return oid in (d.objets.get(pid, []) as Array)


static func _couleur(n: int, cols: Array) -> Color:
	return cols[clampi(n, 0, cols.size() - 1)]


## Table carrée avec nappe, couverts et deux ou quatre chaises.
static func _table(d: GestionDiorama, k: LpKit, t: Vector3, n: int, nappe: Color, chaise: Color, quatre := false) -> Array:
	var out: Array = []
	k.box(t + Vector3(0, 0.74, 0), Vector3(1.1, 0.06, 1.1), nappe)
	k.box(t + Vector3(0, 0.6, 0), Vector3(1.14, 0.22, 1.14), nappe.darkened(0.06), 0.0, false)
	k.box(t + Vector3(0, 0.3, 0), Vector3(0.12, 0.6, 0.12), Color("3d2b20"), 0.0, false)
	k.lathe(t + Vector3(0, 0.77, 0), [Vector2(0.0, 0.0), Vector2(0.05, 0.0), Vector2(0.03, 0.18), Vector2(0.0, 0.2)], 6, Color("e9c46a") if n >= 3 else Color("ffffff"))
	if n >= 3:
		d._lampe(k, t + Vector3(0.3, 0.77, -0.3), 0.18)
	var cotes := [[Vector3(-0.8, 0, 0), PI * 0.5], [Vector3(0.8, 0, 0), -PI * 0.5]]
	if quatre:
		cotes.append_array([[Vector3(0, 0, -0.8), 0.0], [Vector3(0, 0, 0.8), PI]])
	for c in cotes:
		var off: Vector3 = c[0]
		k.lathe(t + Vector3(0, 0.77, 0) + off * 0.38, [Vector2(0.0, 0.0), Vector2(0.15, 0.0), Vector2(0.16, 0.02), Vector2(0.0, 0.02)], 8, Color("ffffff"))
		if n >= 2:
			# Verre à pied.
			k.lathe(t + Vector3(0, 0.77, 0) + off * 0.2 + Vector3(0, 0, 0.2), [Vector2(0.0, 0.0), Vector2(0.03, 0.0), Vector2(0.01, 0.06), Vector2(0.04, 0.14), Vector2(0.0, 0.14)], 6, Color("dff3f8"))
		d._chaise(k, t + off, float(c[1]), chaise)
		out.append(d._place(t + off, float(c[1]), true))
	return out


# --- Pièces ----------------------------------------------------------------------------------------

static func _accueil(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var out: Array = []
	# Pupitre du maître d'hôtel, livre des réservations et lampe.
	var bois := BOIS if n < 3 else Color("3d2b20")
	var p := Vector3(x0 + 2.2, 0, z0 + 1.6)
	k.box(p + Vector3(0, 0.55, 0), Vector3(1.2, 1.1, 0.5), bois)
	k.box(p + Vector3(0, 1.12, 0), Vector3(1.3, 0.05, 0.6), Color("d4af37") if n >= 4 else bois.darkened(0.2))
	k.box(p + Vector3(-0.2, 1.17, 0.05), Vector3(0.5, 0.04, 0.35), Color("9b2226"))
	k.box(p + Vector3(-0.2, 1.2, 0.05), Vector3(0.46, 0.01, 0.32), Color("f8f9fa"), 0.0, false)
	d._lampe(k, p + Vector3(0.4, 1.14, -0.1), 0.25)
	# Tapis d'entrée, puis tapis rouge.
	k.box(Vector3(x0 + 3.0, 0.07, z0 + 4.3), Vector3(1.8, 0.02, 1.0), Color("3d3a36"), 0.0, false)
	if n >= 2:
		d._m(k, "tapis_rouge", x0 + 3.0, z0 + 2.4)
	if n >= 3:
		# Colonnes et cordon.
		for xx in [1.0, 5.0]:
			k.lathe(Vector3(x0 + xx, 0, z0 + 3.2), [Vector2(0.0, 0.0), Vector2(0.14, 0.0), Vector2(0.04, 0.05), Vector2(0.04, 0.9), Vector2(0.07, 0.95), Vector2(0.0, 1.0)], 8, Color("d4af37"))
	if n >= 5:
		d._m(k, "fontaine", x0 + 4.6, z0 + 3.2)
	out.append(d._place(Vector3(x0 + 4.9, 0, z0 + 2.2), -PI * 0.5, false))
	return out


static func _salle(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var out: Array = []
	var nappe := _couleur(n, [Color("ffffff"), Color("f1faee"), Color("ffffff"), Color("e63946"), Color("ffffff"), Color("f6e7a1")])
	var chaise := _couleur(n, [BOIS, BOIS, BOIS, Color("6d2e46"), Color("1d3557"), Color("7b2d26")])
	# Banquette le long du mur du fond (niveau 3).
	if n >= 3:
		for seg in [[x0 + 2.4, x0 + 7.0], [x0 + 9.0, x0 + 13.4]]:
			var l := float(seg[1]) - float(seg[0])
			k.box(Vector3((float(seg[0]) + float(seg[1])) * 0.5, 0.25, z0 + 0.45), Vector3(l, 0.5, 0.7), chaise)
			k.box(Vector3((float(seg[0]) + float(seg[1])) * 0.5, 0.7, z0 + 0.15), Vector3(l, 0.6, 0.15), chaise.darkened(0.15))
	# Grandes tables, en rangées (plus nombreuses à chaque niveau).
	var cols := [x0 + 2.8, x0 + 6.6, x0 + 10.4, x0 + 14.2]
	var rangs := [z0 + 2.0, z0 + 4.6, z0 + 7.2]
	var ordre := [[1, 0], [2, 0], [1, 1], [2, 1], [3, 0], [3, 1], [0, 1], [2, 2], [3, 2], [1, 2], [0, 0]]
	var nb: int = [0, 4, 6, 8, 10, 11][clampi(n, 0, 5)]
	for i in nb:
		var t := Vector3(cols[ordre[i][0]], 0, rangs[ordre[i][1]])
		out.append_array(_table(d, k, t, n, nappe, chaise))
	# Tapis et luminaires au plafond (niveau 4).
	if n >= 4:
		k.box(Vector3(x0 + 8.5, 0.072, z0 + 4.6), Vector3(12.0, 0.02, 6.4), Color("6b2a2a"), 0.0, false)
		k.box(Vector3(x0 + 8.5, 0.074, z0 + 4.6), Vector3(11.4, 0.02, 5.8), Color("8e3b2e"), 0.0, false)
	# Desserte des serveurs.
	k.box(Vector3(x0 + 16.6, 0.45, z0 + 7.8), Vector3(0.6, 0.9, 1.6), BOIS_FONCE)
	for i in 4:
		k.lathe(Vector3(x0 + 16.6, 0.92 + i * 0.04, z0 + 7.5), [Vector2(0.0, 0.0), Vector2(0.15, 0.0), Vector2(0.16, 0.03), Vector2(0.0, 0.03)], 8, Color("ffffff"))
	return out


static func _cuisine(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	# Fourneaux le long du mur du fond (le piano du chef les remplace), hotte.
	if not _a(d, "cuisine", "piano_chef"):
		for i in 3:
			d._m(k, "fourneau", x0 + 1.5 + i * 1.05, z0 + 0.45)
	for i in 2:
		d._m(k, "fourneau", x0 + 5.5 + i * 1.05, z0 + 0.45)
	k.box(Vector3(x0 + 4.0, 2.25, z0 + 0.55), Vector3(6.4, 0.45, 1.0), INOX)
	k.box(Vector3(x0 + 4.0, 2.0, z0 + 1.03), Vector3(6.4, 0.05, 0.05), Color("8d949b"), 0.0, false)
	# Casseroles et poêles sur les feux.
	for i in 5:
		var x := x0 + 1.3 + i * 1.05
		if i % 2 == 0:
			k.lathe(Vector3(x, 0.95, z0 + 0.4), [Vector2(0.0, 0.0), Vector2(0.17, 0.0), Vector2(0.18, 0.2), Vector2(0.0, 0.2)], 8, Color("b87333") if n >= 3 else Color("ced4da"), true, false)
		else:
			k.box(Vector3(x, 0.98, z0 + 0.4), Vector3(0.4, 0.04, 0.4), Color("343a40"), 0.0, false)
			k.box(Vector3(x + 0.3, 0.98, z0 + 0.45), Vector3(0.25, 0.03, 0.05), Color("343a40"), 0.0, false)
	# Îlot de préparation, planches, légumes et batterie suspendue.
	var ilot := Vector3(x0 + 3.75, 0, z0 + 4.6)
	k.box(ilot + Vector3(0, 0.45, 0), Vector3(2.6, 0.9, 1.0), INOX)
	k.box(ilot + Vector3(0, 0.92, 0), Vector3(2.7, 0.04, 1.1), Color("e9ecef"), 0.0, false)
	k.box(ilot + Vector3(-0.6, 0.95, 0.1), Vector3(0.5, 0.03, 0.35), Color("c8a27a"), 0.0, false)
	for i in 4:
		k.blob(ilot + Vector3(0.2 + i * 0.22, 1.0, -0.1 + (i % 2) * 0.2), Vector3(0.07, 0.06, 0.07), Color("2d6a4f"), [Color("e63946"), Color("f4a261"), Color("90be6d"), Color("f4d35e")][i], 0.2, 0)
	k.box(ilot + Vector3(0, 2.1, 0), Vector3(2.4, 0.04, 0.06), Color("8d949b"), 0.0, false)
	for i in 5:
		k.tube(ilot + Vector3(-1.0 + i * 0.5, 2.1, 0), ilot + Vector3(-1.0 + i * 0.5, 1.75, 0), 0.01, 0.01, 4, Color("8d949b"))
		k.lathe(ilot + Vector3(-1.0 + i * 0.5, 1.6, 0), [Vector2(0.0, 0.0), Vector2(0.14, 0.0), Vector2(0.15, 0.08), Vector2(0.0, 0.08)], 8, Color("b87333") if n >= 3 else Color("adb5bd"))
	# Passe : comptoir chauffé où les serveurs prennent les assiettes.
	var px := x0 + 11.3
	k.box(Vector3(px, 0.5, z0 + 3.6), Vector3(0.7, 1.0, 3.6), INOX)
	k.box(Vector3(px, 1.02, z0 + 3.6), Vector3(0.8, 0.04, 3.7), Color("e9ecef"), 0.0, false)
	k.box(Vector3(px, 1.65, z0 + 3.6), Vector3(0.5, 0.08, 3.4), Color("8d949b"), 0.0, false)
	k.layer = "lumiere"
	k.box(Vector3(px, 1.6, z0 + 3.6), Vector3(0.4, 0.03, 3.2), Color("ffb347"), 0.0, false)
	k.layer = "base"
	for i in 4 + mini(n, 3):
		k.lathe(Vector3(px, 1.05, z0 + 2.2 + i * 0.45), [Vector2(0.0, 0.0), Vector2(0.15, 0.0), Vector2(0.16, 0.02), Vector2(0.0, 0.02)], 8, Color("ffffff"))
		k.blob(Vector3(px, 1.1, z0 + 2.2 + i * 0.45), Vector3(0.08, 0.04, 0.08), Color("bc6c25"), [Color("90be6d"), Color("e76f51"), Color("f4d35e")][i % 3], 0.3, 0)
	# Étagère des épices et des bocaux le long du mur de gauche.
	d._etagere(k, Vector3(x0 + 0.3, 0, z0 + 1.6), PI * 0.5, 1.4, 1.6, Color("adb5bd"), [Color("bc6c25"), Color("e9c46a"), Color("90be6d"), Color("9b2226")])
	if n >= 2:
		# Second plan de travail.
		k.box(Vector3(x0 + 7.6, 0.45, z0 + 4.6), Vector3(1.2, 0.9, 1.0), INOX)
		k.box(Vector3(x0 + 7.6, 0.92, z0 + 4.6), Vector3(1.3, 0.04, 1.1), Color("e9ecef"), 0.0, false)
	if n >= 4:
		# Table du chef : quelques clients privilégiés mangent en cuisine.
		k.box(Vector3(x0 + 9.0, 0.74, z0 + 7.8), Vector3(1.6, 0.06, 0.8), Color("3d2b20"))
		for sx in [-0.5, 0.5]:
			d._chaise(k, Vector3(x0 + 9.0 + sx, 0, z0 + 8.5), PI, Color("6d2e46"))
	return []


static func _plonge(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	# Évier simple, chariot de vaisselle sale et piles d'assiettes.
	if not _a(d, "plonge", "bac_plonge"):
		d._m(k, "lavabo", x0 + 3.4, z0 + 0.4)
	k.box(Vector3(x0 + 1.2, 0.45, z0 + 0.45), Vector3(1.6, 0.9, 0.7), INOX)
	k.box(Vector3(x0 + 1.2, 0.92, z0 + 0.45), Vector3(1.65, 0.04, 0.75), Color("e9ecef"), 0.0, false)
	for i in 3 + mini(n, 3):
		k.lathe(Vector3(x0 + 0.7 + (i % 3) * 0.4, 0.94 + (i / 3) * 0.12, z0 + 0.45), [Vector2(0.0, 0.0), Vector2(0.15, 0.0), Vector2(0.16, 0.1), Vector2(0.0, 0.1)], 8, Color("ffffff"))
	k.box(Vector3(x0 + 3.6, 0.5, z0 + 3.8), Vector3(0.7, 0.05, 1.0), INOX, 0.0, false)
	k.box(Vector3(x0 + 3.6, 0.15, z0 + 3.8), Vector3(0.7, 0.05, 1.0), INOX, 0.0, false)
	for i in 4:
		k.lathe(Vector3(x0 + 3.45 + (i % 2) * 0.3, 0.53, z0 + 3.5 + (i / 2) * 0.5), [Vector2(0.0, 0.0), Vector2(0.14, 0.0), Vector2(0.15, 0.08), Vector2(0.0, 0.08)], 8, Color("dee2e6"))
	if n >= 2:
		d._m(k, "lave_vaisselle", x0 + 0.5, z0 + 2.4, PI * 0.5)
	return []


static func _reserve(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	d._etagere(k, Vector3(x0 + 1.8, 0, z0 + 0.3), 0.0, 2.6, 2.0, Color("8d949b"), [Color("e9c46a"), Color("e63946"), Color("f8f9fa"), Color("90be6d"), Color("bc6c25")])
	# Cagettes de légumes et de fruits.
	d._m(k, "cagettes", x0 + 5.3, z0 + 5.0, 0.0)
	if n >= 2:
		d._m(k, "cagettes", x0 + 4.0, z0 + 5.0, 0.0)
	if n >= 3:
		# Jambons et saucissons suspendus.
		k.box(Vector3(x0 + 1.6, 2.1, z0 + 4.0), Vector3(2.2, 0.04, 0.05), BOIS_FONCE, 0.0, false)
		for i in 5:
			k.blob(Vector3(x0 + 0.8 + i * 0.4, 1.8, z0 + 4.0), Vector3(0.1, 0.25 if i % 2 == 0 else 0.15, 0.1), Color("9c4a3c"), Color("bc6c4a"), 0.1, 0)
	return []


static func _bureau(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	if not _a(d, "bureau", "ordinateur"):
		k.box(Vector3(x0 + 3.0, 0.74, z0 + 2.0), Vector3(1.6, 0.06, 0.8), BOIS_FONCE)
		for sx in [-0.7, 0.7]:
			k.box(Vector3(x0 + 3.0 + sx, 0.37, z0 + 2.0), Vector3(0.06, 0.74, 0.7), BOIS_FONCE, 0.0, false)
		k.box(Vector3(x0 + 2.6, 0.8, z0 + 2.0), Vector3(0.4, 0.06, 0.3), Color("f8f9fa"), 0.0, false)
	d._chaise(k, Vector3(x0 + 3.0, 0, z0 + 1.1), 0.0, Color("495057"))
	for i in 2:
		k.box(Vector3(x0 + 6.5, 0.6, z0 + 0.8 + i * 0.6), Vector3(0.5, 1.2, 0.55), Color("8d99ae"))
	d._etagere(k, Vector3(x0 + 5.2, 0, z0 + 0.3), 0.0, 1.6, 1.8, Color("6b4a32"), [Color("e76f51"), Color("2a9d8f"), Color("e9c46a"), Color("264653")])
	if n >= 2:
		d._m(k, "plante", x0 + 0.6, z0 + 0.6)
	if n >= 3:
		d._fauteuil(k, Vector3(x0 + 4.8, 0, z0 + 4.6), PI, Color("6d2e46"))
	if n >= 4:
		for i in 3:
			k.lathe(Vector3(x0 + 4.7 + i * 0.4, 1.82, z0 + 0.3), [Vector2(0.0, 0.0), Vector2(0.08, 0.0), Vector2(0.03, 0.08), Vector2(0.1, 0.25), Vector2(0.0, 0.25)], 8, Color("d4af37"))
	return []


static func _bar(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var out: Array = []
	var cuir := _couleur(n, [Color("8a5a3b"), Color("8a5a3b"), Color("6d2e46"), Color("1d3557"), Color("264653"), Color("7b2d26")])
	# Comptoir face à la salle, étagère de bouteilles derrière.
	var c := Vector3(x0 + 2.6, 0, z0 + 1.7)
	k.box(c + Vector3(0, 0.53, 0), Vector3(4.2, 1.06, 0.7), Color("3d2b20"))
	k.box(c + Vector3(0, 1.09, 0), Vector3(4.4, 0.06, 0.85), Color("d4af37") if n >= 4 else Color("6b4a32"))
	k.box(c + Vector3(0, 0.12, 0.38), Vector3(4.0, 0.04, 0.04), Color("d4af37"), 0.0, false)
	k.box(Vector3(x0 + 2.6, 0.5, z0 + 0.28), Vector3(4.6, 1.0, 0.45), Color("5c4033"))
	for i in 20:
		k.lathe(Vector3(x0 + 0.6 + (i % 10) * 0.42, 1.0 + (i / 10) * 0.0, z0 + 0.28 + (i / 10) * 0.12 - 0.06), [Vector2(0.0, 0.0), Vector2(0.06, 0.0), Vector2(0.06, 0.2), Vector2(0.025, 0.3), Vector2(0.0, 0.32)], 6,
			[Color("2a9d8f"), Color("e9c46a"), Color("e76f51"), Color("8ecae6"), Color("6a994e")][i % 5])
	for i in 4:
		k.lathe(c + Vector3(-1.4 + i * 0.3, 1.12, 0.15), [Vector2(0.0, 0.0), Vector2(0.05, 0.0), Vector2(0.06, 0.14), Vector2(0.0, 0.14)], 6, Color("dff3f8"))
	# Tabourets devant le comptoir.
	for i in mini(2 + n, 5):
		var p := Vector3(x0 + 0.9 + i * 0.9, 0, z0 + 2.5)
		k.lathe(p, [Vector2(0.0, 0.0), Vector2(0.2, 0.0), Vector2(0.04, 0.05), Vector2(0.04, 0.65), Vector2(0.2, 0.68), Vector2(0.2, 0.76), Vector2(0.0, 0.76)], 8, cuir)
		out.append(d._place(p, PI, true))
	# Petite table.
	if n >= 2:
		var t := Vector3(x0 + 4.0, 0, z0 + 4.9)
		d._table_ronde(k, t, 0.42, Color("3d2b20"))
		k.lathe(t + Vector3(0.1, 0.76, 0.05), [Vector2(0.0, 0.0), Vector2(0.04, 0.0), Vector2(0.06, 0.16), Vector2(0.0, 0.16)], 6, Color("f4a261"))
		d._fauteuil(k, t + Vector3(-0.85, 0, 0), PI * 0.5, cuir)
		d._fauteuil(k, t + Vector3(0.85, 0, 0), -PI * 0.5, cuir)
		out.append(d._place(t + Vector3(-0.85, 0, 0), PI * 0.5, true))
		out.append(d._place(t + Vector3(0.85, 0, 0), -PI * 0.5, true))
	return out


static func _toilettes(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var out: Array = []
	var carreau := _couleur(n, [Color("dee2e6"), Color("dee2e6"), Color("a8dadc"), Color("cdb4db"), Color("e9e4da"), Color("1d3557")])
	# Cabines le long du mur du fond, avec leurs portes.
	var nb: int = [0, 2, 3, 3, 3, 3][clampi(n, 0, 5)]
	for i in nb:
		var x := x0 + 0.85 + i * 1.4
		for sx in [-0.7, 0.7]:
			k.box(Vector3(x + sx, 0.9, z0 + 0.8), Vector3(0.06, 1.8, 1.5), carreau)
		k.box(Vector3(x - 0.3, 0.9, z0 + 1.55), Vector3(0.75, 1.7, 0.05), carreau.darkened(0.15))
		d._m(k, "wc", x, z0 + 0.35)
		out.append(d._place(Vector3(x, 0, z0 + 0.55), 0.0, true, [Vector3(x + 0.35, 0, z0 + 2.1)]))
	# Lavabos (les vasques en marbre les remplacent).
	if not _a(d, "toilettes", "marbre"):
		for i in 2:
			d._m(k, "lavabo", x0 + 0.35, z0 + 3.4 + i * 1.0, PI * 0.5)
			out.append(d._place(Vector3(x0 + 1.0, 0, z0 + 3.4 + i * 1.0), -PI * 0.5, false))
	else:
		out.append(d._place(Vector3(x0 + 1.1, 0, z0 + 4.0), -PI * 0.5, false))
	return out


static func _salon(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var out: Array = []
	var nappe := _couleur(n, [Color("ffffff"), Color("ffffff"), Color("fdf0d5"), Color("ffffff"), Color("f6e7a1"), Color("fff8e7")])
	var chaise := _couleur(n, [BOIS, BOIS, Color("9c4f3a"), Color("6d2e46"), Color("7b2d26"), Color("d4af37")])
	# Grande table de banquet (plus longue à chaque niveau).
	var l: float = [0.0, 4.2, 5.0, 5.8, 6.6, 7.0][clampi(n, 0, 5)]
	var xa := x0 + 2.6
	var zc := z0 + 2.5
	k.box(Vector3(xa + l * 0.5, 0.74, zc), Vector3(l, 0.06, 1.2), nappe)
	k.box(Vector3(xa + l * 0.5, 0.58, zc), Vector3(l + 0.04, 0.26, 1.24), nappe.darkened(0.05), 0.0, false)
	for sx in [0.2, l - 0.2]:
		k.box(Vector3(xa + sx, 0.36, zc), Vector3(0.1, 0.72, 1.0), BOIS_FONCE, 0.0, false)
	var places := int(l / 0.9)
	for i in places:
		var x := xa + 0.45 + i * 0.9
		for sz in [-0.85, 0.85]:
			var rot := 0.0 if sz < 0.0 else PI
			k.lathe(Vector3(x, 0.77, zc + sz * 0.4), [Vector2(0.0, 0.0), Vector2(0.15, 0.0), Vector2(0.16, 0.02), Vector2(0.0, 0.02)], 8, Color("ffffff"))
			d._chaise(k, Vector3(x, 0, zc + sz), rot, chaise)
			out.append(d._place(Vector3(x, 0, zc + sz), rot, true))
		if i % 2 == 0:
			k.lathe(Vector3(x + 0.45, 0.77, zc), [Vector2(0.0, 0.0), Vector2(0.05, 0.0), Vector2(0.03, 0.22), Vector2(0.0, 0.24)], 6, Color("e9c46a") if n >= 3 else Color("ffffff"))
	if n >= 2:
		# Chemin de table et bougeoirs.
		k.box(Vector3(xa + l * 0.5, 0.775, zc), Vector3(l - 0.4, 0.005, 0.35), Color("9b2226") if n < 4 else Color("d4af37"), 0.0, false)
	if n >= 3:
		d._m(k, "plante_grande", x0 + 11.4, z0 + 4.4)
	return out


static func _cave(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var out: Array = []
	# Casiers à bouteilles le long du mur de gauche (plus hauts avec le niveau).
	var h: float = [0.0, 1.2, 1.6, 2.0, 2.0, 2.2][clampi(n, 0, 5)]
	k.box(Vector3(x0 + 0.3, h * 0.5, z0 + 2.5), Vector3(0.5, h, 4.6), Color("5c4033"))
	var rangs := int(h / 0.22)
	for j in rangs:
		for i in 18:
			k.box(Vector3(x0 + 0.56, 0.15 + j * 0.22, z0 + 0.4 + i * 0.24), Vector3(0.02, 0.09, 0.09), [Color("6a040f"), Color("e9d8a6"), Color("2d6a4f"), Color("9d0208")][(i + j) % 4], 0.0, false)
	# Lumière tamisée et ardoise des vins.
	d._lampe(k, Vector3(x0 + 3.0, 0, z0 + 0.4), 0.3)
	k.box(Vector3(x0 + 3.0, 0.3, z0 + 0.4), Vector3(0.7, 0.6, 0.4), Color("3d2b20"))
	if n >= 3:
		k.box(Vector3(x0 + 3.0, 0.072, z0 + 2.8), Vector3(2.6, 0.02, 2.2), Color("6b2a2a"), 0.0, false)
	out.append(d._place(Vector3(x0 + 1.2, 0, z0 + 3.2), -PI * 0.5, false))
	out.append(d._place(Vector3(x0 + 1.2, 0, z0 + 1.6), -PI * 0.5, false))
	return out


static func _patisserie(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var out: Array = []
	# Comptoir et caisse (la vitrine de gâteaux s'y ajoute).
	if not _a(d, "patisserie", "vitrine_gateaux"):
		k.box(Vector3(x0 + 4.0, 0.45, z0 + 1.6), Vector3(2.0, 0.9, 0.7), Color("f2dfe2"))
		k.box(Vector3(x0 + 4.0, 0.92, z0 + 1.6), Vector3(2.1, 0.04, 0.8), Color("d4af37"), 0.0, false)
		for i in 3:
			k.lathe(Vector3(x0 + 3.4 + i * 0.6, 0.94, z0 + 1.6), [Vector2(0.0, 0.0), Vector2(0.18, 0.0), Vector2(0.18, 0.12), Vector2(0.0, 0.14)], 8, [Color("6f1d1b"), Color("ffafcc"), Color("f4a261")][i])
		out.append(d._place(Vector3(x0 + 4.0, 0, z0 + 2.6), PI, false))
	k.box(Vector3(x0 + 5.4, 0.98, z0 + 0.6), Vector3(0.35, 0.18, 0.3), Color("343a40"))
	# Tables à thé, chaises bistrot.
	var tables := [Vector3(x0 + 1.6, 0, z0 + 3.8), Vector3(x0 + 4.4, 0, z0 + 3.9)]
	for i in mini(n, 2):
		var t: Vector3 = tables[i]
		d._table_ronde(k, t, 0.4, Color("f8f9fa"), Color("ffafcc") if n >= 3 else Color(0, 0, 0, 0))
		k.lathe(t + Vector3(0, 0.77, 0), [Vector2(0.0, 0.0), Vector2(0.12, 0.0), Vector2(0.1, 0.08), Vector2(0.0, 0.1)], 8, Color("ffafcc"))
		for s in [[Vector3(-0.65, 0, 0), PI * 0.5], [Vector3(0.65, 0, 0), -PI * 0.5]]:
			d._chaise(k, t + (s[0] as Vector3), float(s[1]), Color("f4a6b8"))
			out.append(d._place(t + (s[0] as Vector3), float(s[1]), true))
	return out


static func _terrasse(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var out: Array = []
	# Bordure et petites barrières.
	var bord := Color("6b4a32")
	k.box(Vector3(x0 + float(r[2]) * 0.5, 0.35, z0 + float(r[3]) - 0.1), Vector3(float(r[2]), 0.7, 0.08), bord, 0.0, false)
	k.box(Vector3(x0 + float(r[2]) - 0.05, 0.35, z0 + float(r[3]) * 0.5), Vector3(0.08, 0.7, float(r[3])), bord, 0.0, false)
	# Tables rondes avec quatre chaises (plus nombreuses à chaque niveau).
	var cols := [x0 + 1.7, x0 + 4.5, x0 + 7.3, x0 + 10.1]
	var rangs := [z0 + 1.8, z0 + 4.2, z0 + 6.2]
	var ordre := [[0, 0], [1, 0], [2, 0], [3, 0], [0, 1], [1, 1], [2, 1], [3, 1], [1, 2], [2, 2]]
	var nb: int = [0, 3, 5, 7, 9, 10][clampi(n, 0, 5)]
	var chaise := _couleur(n, [Color("2a9d8f"), Color("2a9d8f"), Color("e76f51"), Color("1d3557"), Color("264653"), Color("6d597a")])
	for i in nb:
		var t := Vector3(cols[ordre[i][0]], 0, rangs[ordre[i][1]])
		d._table_ronde(k, t, 0.45, Color("dee2e6"))
		k.lathe(t + Vector3(0.12, 0.76, 0.0), [Vector2(0.0, 0.0), Vector2(0.04, 0.0), Vector2(0.05, 0.14), Vector2(0.0, 0.14)], 6, Color("f4a261"))
		for s in [[Vector3(-0.75, 0, 0), PI * 0.5], [Vector3(0.75, 0, 0), -PI * 0.5]]:
			d._chaise(k, t + (s[0] as Vector3), float(s[1]), chaise)
			out.append(d._place(t + (s[0] as Vector3), float(s[1]), true))
	return out


static func _potager(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var w := float(r[2])
	var h := float(r[3])
	# Clôture en bois.
	for i in int(w / 1.0) + 1:
		k.box(Vector3(x0 + i * 1.0, 0.4, z0 + 0.05), Vector3(0.08, 0.8, 0.08), Color("a47148"), 0.0, false)
		k.box(Vector3(x0 + i * 1.0, 0.4, z0 + h - 0.05), Vector3(0.08, 0.8, 0.08), Color("a47148"), 0.0, false)
	for j in int(h / 1.0) + 1:
		k.box(Vector3(x0 + 0.05, 0.4, z0 + j * 1.0), Vector3(0.08, 0.8, 0.08), Color("a47148"), 0.0, false)
		k.box(Vector3(x0 + w - 0.05, 0.4, z0 + j * 1.0), Vector3(0.08, 0.8, 0.08), Color("a47148"), 0.0, false)
	for y in [0.3, 0.65]:
		k.box(Vector3(x0 + w * 0.5, y, z0 + 0.05), Vector3(w, 0.06, 0.04), Color("c8a27a"), 0.0, false)
		k.box(Vector3(x0 + w * 0.5, y, z0 + h - 0.05), Vector3(w, 0.06, 0.04), Color("c8a27a"), 0.0, false)
		k.box(Vector3(x0 + 0.05, y, z0 + h * 0.5), Vector3(0.04, 0.06, h), Color("c8a27a"), 0.0, false)
		k.box(Vector3(x0 + w - 0.05, y, z0 + h * 0.5), Vector3(0.04, 0.06, h), Color("c8a27a"), 0.0, false)
	# Rangs de légumes en pleine terre (plus nombreux avec le niveau).
	for i in mini(2 + n, 6):
		var z := z0 + 6.8 + i * 0.0
		var x := x0 + 0.8 + i * 1.0
		k.box(Vector3(x, 0.08, z + 0.7), Vector3(0.6, 0.12, 2.0), Color("5c3d2e"), 0.0, false)
		for j in 4:
			k.blob(Vector3(x, 0.25, z - 0.05 + j * 0.5), Vector3(0.22, 0.18, 0.2), Color("2d6a4f"), Color("52b788") if i % 2 == 0 else Color("95d5b2"), 0.25, 0)
	if n >= 3:
		# Arbres fruitiers.
		d._arbre(k, Vector3(x0 + w - 1.4, 0, z0 + 5.0), 0.7)
	d._m(k, "plante", x0 + 0.7, z0 + h - 0.8)
	return []


static func _livraison(d: GestionDiorama, k: LpKit, r: Array, n: int) -> Array:
	var x0 := float(r[0])
	var z0 := float(r[1])
	var w := float(r[2])
	var h := float(r[3])
	# Bitume, places marquées et quai.
	k.box(Vector3(x0 + w * 0.5, 0.07, z0 + h * 0.5), Vector3(w, 0.02, h), Color("55595f"), 0.0, false)
	for i in 3:
		k.box(Vector3(x0 + 2.5 + i * 3.0, 0.085, z0 + h - 1.8), Vector3(0.12, 0.01, 3.2), Color("f2f2ee"), 0.0, false)
	k.box(Vector3(x0 + 0.5, 0.45, z0 + h * 0.5), Vector3(1.0, 0.9, h - 0.4), Color("9a958c"))
	k.box(Vector3(x0 + 1.02, 0.6, z0 + h * 0.5), Vector3(0.06, 0.2, h - 0.6), Color("f4d35e"), 0.0, false)
	for i in 2:
		k.lathe(Vector3(x0 + w - 0.6, 0, z0 + 1.0 + i * 5.0), [Vector2(0.0, 0.0), Vector2(0.12, 0.0), Vector2(0.12, 0.8), Vector2(0.0, 0.85)], 8, Color("f4d35e"))
	if n >= 2:
		# Camion du fournisseur à quai.
		d._m(k, "camionnette", x0 + w - 2.4, z0 + h - 2.6, -PI * 0.5, Color("2a9d8f"))
	return []
