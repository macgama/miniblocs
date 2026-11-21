class_name TaillesBatiments
extends RefCounted
## Taille choisie d'un bâtiment du catalogue, avant de le poser : d'abord
## l'emprise au sol (largeur × profondeur), puis la hauteur (nombre d'étages,
## le toit ne compte pas).
##
## Un bâtiment à une autre taille que celle du catalogue a son propre id :
## « <type>@<largeur>x<profondeur>x<étages> » (ex. « maison@8x10x1 »). L'entrée du
## catalogue est fabriquée à la demande (BuildingCatalog.get_type) : emprise,
## logements, emplois, visiteurs, lits, puissance d'un réseau, prix, année… tout
## suit la taille. La durée et les matériaux du chantier suivent tout seuls
## (Chantiers les lit sur la surface de plancher et la hauteur du modèle).
## L'id voyage tel quel dans la sauvegarde et en carte entre amis : chaque
## machine refait la même entrée. Les systèmes qui reconnaissent un bâtiment
## par son id passent par BuildingCatalog.base_of() (comme pour les modèles de
## l'Atelier).

const SEP := "@"
## Hauteur d'un étage (m).
const ETAGE := 3.0
## Emprise réglable de 60 % à 160 % de celle du catalogue sur chaque côté.
const EMPRISE_MIN := 0.6
const EMPRISE_MAX := 1.6
const COTE_MIN := 4
const COTE_MAX := 220

## Bornes réalistes des étages selon la forme (archétype du modèle).
const ETAGES_ARCH := {
	"maison": [1, 4], "grande_maison": [1, 3], "rangee": [1, 6], "immeuble": [2, 12], "tour": [8, 45],
	"gratte_ciel": [20, 100], "boutique": [1, 4], "restaurant": [1, 3], "atelier": [1, 3], "bureaux": [2, 30],
	"ecole": [1, 4], "hopital": [1, 12], "grand_magasin": [1, 6], "palais": [1, 4],
}
## Étages des modèles faits main (sans archétype) et leurs bornes.
const ETAGES_FAITS_MAIN := {
	"villa": [2, 1, 3], "boulangerie": [2, 1, 4], "superette": [1, 1, 2], "supermarche": [1, 1, 2],
	"bureaux": [6, 2, 30], "atelier": [1, 1, 2], "entrepot": [1, 1, 2], "usine": [1, 1, 3], "ferme": [1, 1, 2],
	"entreprise_btp": [1, 1, 3], "maison_commune": [2, 1, 3], "mairie": [2, 1, 5], "ecole": [2, 1, 4],
	"pompiers": [2, 1, 4], "police": [2, 1, 6], "hopital": [4, 2, 14], "cafe": [1, 1, 3], "cinema": [1, 1, 3],
	"musee": [2, 1, 4], "gymnase": [1, 1, 2], "piscine": [1, 1, 2], "maison": [2, 1, 4],
	"immeuble": [4, 2, 12], "tour_habitation": [13, 8, 45],
}
## Étages au plus selon l'année de la partie (avant l'ascenseur et l'acier, on
## ne monte pas haut) : [jusqu'à l'année exclue, étages].
const EPOQUE_ETAGES := [[1860, 6], [1890, 8], [1920, 16], [1950, 30], [1975, 50]]
## Jamais redimensionnés : terrains de sport aux mesures officielles, campement.
const FIXES := ["foot", "tennis", "basket", "campement"]
## Catégories qui ne montent pas en étages (parcs, places, équipements plats).
const CAT_PLATES := ["espaces", "parc", "zoo", "reseaux"]
## Champs du catalogue qui suivent la surface de plancher.
const CAPACITES := ["logements", "emplois", "visiteurs", "lits", "places"]
## Champs du catalogue retirés de l'entrée à une autre taille.
const RETIRES := ["id", "cache", "variantes_de"]

## Rapport de surface au-delà duquel une maison compte un logement de plus.
const MAISON_PARTAGEE := 1.75
const ARCH_MAISONS := ["maison", "grande_maison", "villa", "ferme"]

static var _entrees := {}
static var _etages_base := {}


# --- Ids --------------------------------------------------------------------------------

static func est_taille(id: String) -> bool:
	return id.contains(SEP)


## Type du catalogue dont ce bâtiment est une autre taille (ou l'id lui-même).
static func origine(id: String) -> String:
	return id.get_slice(SEP, 0) if est_taille(id) else id


## Taille de l'id : {"w", "d", "e"} (celle du catalogue pour un id normal).
static func dims(id: String) -> Dictionary:
	var o := origine(id)
	var t := BuildingCatalog.get_type(o)
	var out := {"w": int(t.get("w", 1)), "d": int(t.get("d", 1)), "e": etages_base(o)}
	if est_taille(id):
		var p := id.get_slice(SEP, 1).split("x")
		if p.size() == 3 and p[0].is_valid_int() and p[1].is_valid_int() and p[2].is_valid_int():
			out = {"w": int(p[0]), "d": int(p[1]), "e": int(p[2])}
	return out


## Id d'un type à la taille demandée (l'id du catalogue si c'est sa taille).
static func id_pour(type_id: String, w: int, d: int, e: int) -> String:
	var o := origine(type_id)
	var b := dims(o)
	if w == int(b.w) and d == int(b.d) and e == int(b.e):
		return o
	return "%s%s%dx%dx%d" % [o, SEP, w, d, e]


# --- Ce qui se règle ----------------------------------------------------------------------

## L'emprise de ce type se choisit-elle ?
static func reglable(type_id: String) -> bool:
	var o := origine(type_id)
	var t := BuildingCatalog.get_type(o)
	if t.is_empty() or o in FIXES:
		return false
	for k in ["blocks", "modele", "creation", "stade", "monument", "campement", "glb_fixe", "attraction_perso"]:
		if t.has(k) and t[k]:
			return false
	# Mobilier urbain et petits objets (bancs, lampadaires, arbres) : taille fixe.
	if mini(int(t.get("w", 1)), int(t.get("d", 1))) < COTE_MIN:
		return false
	return String(t.get("cat", "")) != "patrimoine"


## Sa hauteur (étages) se choisit-elle ? Les bâtiments où l'on vit, travaille
## ou reçoit du monde ; pas les parcs, places, enclos ni ouvrages de réseau.
static func hauteur_reglable(type_id: String) -> bool:
	var o := origine(type_id)
	if not reglable(o):
		return false
	var t := BuildingCatalog.get_type(o)
	if String(t.get("cat", "")) in CAT_PLATES or t.get("espace", false) or t.has("reseau") or t.has("telecom"):
		return false
	var e := _bornes_etages(o)
	return e.y > e.x


## Maison individuelle (une famille, quelle que soit la taille) ?
static func est_maison(type_id: String) -> bool:
	var o := origine(type_id)
	var t := BuildingCatalog.get_type(o)
	return o in ARCH_MAISONS or String(t.get("arch", t.get("role", ""))) in ARCH_MAISONS


## Archétype qui décide de la forme (modèle d'un style, ou modèle classique).
static func _arch(o: String) -> String:
	var t := BuildingCatalog.get_type(o)
	if t.has("arch"):
		return String(t.arch)
	return String(Personnalisation.CLASSIQUES.get(o, ""))


## Étages du type au catalogue (toit non compris).
static func etages_base(type_id: String) -> int:
	var o := origine(type_id)
	if _etages_base.has(o):
		return int(_etages_base[o])
	var e := 1
	var t := BuildingCatalog.get_type(o)
	if ETAGES_FAITS_MAIN.has(o) and not t.has("arch"):
		e = int(ETAGES_FAITS_MAIN[o][0])
	elif t.has("arch") and Styles.STYLES.has(String(t.get("style", ""))):
		e = StyleBuilder.floors_of(Styles.STYLES[t.style], String(t.arch))
	elif t.has("glb"):
		e = int(BibleGlb.volume(o).get("etages", 1))
	elif not t.is_empty():
		var m := BuildingCatalog.build_mesh(o, null, false)
		if m != null and m.get_surface_count() > 0:
			var h := BatimentsVie.body_bounds(m).end.y
			e = clampi(roundi((h * 0.8) / 3.4), 1, 80)
	e = maxi(1, e)
	_etages_base[o] = e
	return e


static func _bornes_etages(o: String) -> Vector2i:
	var e0 := etages_base(o)
	var lo := e0
	var hi := e0
	var t := BuildingCatalog.get_type(o)
	if String(t.get("cat", "")) in CAT_PLATES or t.get("espace", false):
		return Vector2i(e0, e0)
	if ETAGES_FAITS_MAIN.has(o) and not t.has("arch"):
		lo = int(ETAGES_FAITS_MAIN[o][1])
		hi = int(ETAGES_FAITS_MAIN[o][2])
	elif ETAGES_ARCH.has(_arch(o)):
		lo = int(ETAGES_ARCH[_arch(o)][0])
		hi = int(ETAGES_ARCH[_arch(o)][1])
	elif int(t.get("logements", 0)) + int(t.get("emplois", 0)) > 0:
		# Bâtiment sans forme connue : d'un étage à presque le double.
		lo = 1
		hi = e0 + maxi(1, roundi(e0 * 0.8))
	return Vector2i(mini(lo, e0), maxi(hi, e0))


## Étages au plus à l'année de la partie (0 : pas de limite).
static func plafond_epoque(annee := -1) -> int:
	if annee < 0:
		if not Epoques.actif():
			return 0
		annee = Epoques.annee()
	for p in EPOQUE_ETAGES:
		if annee < int(p[0]):
			return int(p[1])
	return 0


## Bornes du type : {"w": Vector2i(min, max), "d": …, "e": …}. Les étages
## tiennent compte de l'époque (annee : année de la partie, -1 = celle en cours).
static func bornes(type_id: String, annee := -1) -> Dictionary:
	var o := origine(type_id)
	var t := BuildingCatalog.get_type(o)
	var w0 := int(t.get("w", 1))
	var d0 := int(t.get("d", 1))
	var bw := Vector2i(clampi(roundi(w0 * EMPRISE_MIN), COTE_MIN, w0), clampi(roundi(w0 * EMPRISE_MAX), w0, COTE_MAX))
	var bd := Vector2i(clampi(roundi(d0 * EMPRISE_MIN), COTE_MIN, d0), clampi(roundi(d0 * EMPRISE_MAX), d0, COTE_MAX))
	var be := _bornes_etages(o)
	if not hauteur_reglable(o):
		be = Vector2i(etages_base(o), etages_base(o))
	var cap := plafond_epoque(annee)
	if cap > 0:
		be.y = maxi(mini(be.y, cap), mini(etages_base(o), be.y))
		be.x = mini(be.x, be.y)
	return {"w": bw, "d": bd, "e": be}


## La taille de l'id est-elle permise pour son type (hors époque) ?
static func valide(id: String) -> bool:
	if not est_taille(id):
		return true
	var o := origine(id)
	if not reglable(o):
		return false
	var p := id.get_slice(SEP, 1).split("x")
	if p.size() != 3 or not (p[0].is_valid_int() and p[1].is_valid_int() and p[2].is_valid_int()):
		return false
	var z := dims(id)
	var b := bornes(o, 3000)
	var be: Vector2i = b.e if hauteur_reglable(o) else Vector2i(etages_base(o), etages_base(o))
	return int(z.w) >= b.w.x and int(z.w) <= b.w.y and int(z.d) >= b.d.x and int(z.d) <= b.d.y \
		and int(z.e) >= be.x and int(z.e) <= be.y


## Rapport de surface de plancher avec le modèle du catalogue.
static func rapport(id: String) -> float:
	var o := origine(id)
	var z := dims(id)
	var b := dims(o)
	var r := float(int(z.w) * int(z.d)) / maxf(1.0, float(int(b.w) * int(b.d)))
	if hauteur_reglable(o):
		r *= float(z.e) / maxf(1.0, float(b.e))
	return r


## Prix d'un type à cette taille : une part fixe (raccordements, fondations,
## études), le reste au mètre carré ; les tours paient l'ascenseur et la structure.
static func prix(id: String) -> int:
	var o := origine(id)
	var c0 := float(BuildingCatalog.cost(o))
	if c0 <= 0.0:
		return 0
	var z := dims(id)
	var k := 0.2 + 0.8 * rapport(id)
	if int(z.e) > 8:
		k *= 1.0 + 0.015 * float(int(z.e) - 8)
	return maxi(5_000, int(snappedf(c0 * k, 1_000.0)))


# --- Entrée du catalogue -----------------------------------------------------------------

## Entrée du catalogue d'un id à une autre taille ({} si l'id n'est pas valable).
static func entree(id: String) -> Dictionary:
	if _entrees.has(id):
		return _entrees[id]
	if not valide(id):
		return {}
	var o := origine(id)
	var ref := BuildingCatalog.get_type(o)
	var t := ref.duplicate(true)
	for k in RETIRES:
		t.erase(k)
	var z := dims(id)
	var r := rapport(id)
	for k in CAPACITES:
		if t.has(k) and (t[k] is int or t[k] is float) and int(t[k]) > 0:
			t[k] = maxi(1, roundi(float(t[k]) * r))
	# Une maison plus grande loge toujours une famille ; très grande, elle se
	# partage en appartements.
	if est_maison(o) and int(ref.get("logements", 0)) > 0:
		t["logements"] = maxi(int(ref.logements), floori(float(ref.logements) * r / MAISON_PARTAGEE))
	if t.get("reseau") is Dictionary and float((t.reseau as Dictionary).get("cap", 0.0)) > 0.0:
		t.reseau["cap"] = snappedf(float(t.reseau.cap) * r, 0.1)
	# Les bâtiments faits main se reconnaissent à leur id : le rôle le garde pour
	# les systèmes qui lisent arch ou role (comme les modèles de l'Atelier).
	if not t.has("arch") and not t.has("role"):
		t["role"] = o
	t["base"] = BuildingCatalog.base_of(o)
	t["taille_de"] = o
	t["w"] = int(z.w)
	t["d"] = int(z.d)
	t["etages"] = int(z.e)
	t["cost"] = prix(id)
	t["annee"] = Epoques.annee_batiment(o)
	t["desc"] = "%s · %s" % [texte_taille(id), String(ref.get("desc", ""))]
	_entrees[id] = t
	return t


## « 8 × 10 m, 1 étage »
static func texte_taille(id: String) -> String:
	var z := dims(id)
	var s := "%d × %d m" % [int(z.w), int(z.d)]
	if hauteur_reglable(origine(id)):
		s += ", " + texte_etages(int(z.e))
	return s


static func texte_etages(e: int) -> String:
	if e <= 1:
		return "plain-pied"
	return "%d niveaux" % e


## Chiffres d'un id pour l'affichage : {"logements", "emplois", "visiteurs", "prix", "mois"}.
static func chiffres(id: String) -> Dictionary:
	var t := BuildingCatalog.get_type(id)
	return {"logements": int(t.get("logements", 0)), "emplois": int(t.get("emplois", 0)),
		"visiteurs": int(t.get("visiteurs", 0)), "prix": BuildingCatalog.cost(id),
		"mois": Chantiers.mois_batiment(id)}


# --- Maillage ------------------------------------------------------------------------------

## Le modèle de l'origine se dessine-t-il par StyleBuilder (forme réglable) ?
static func _par_style(o: String, perso: Dictionary) -> bool:
	var t := BuildingCatalog.get_type(o)
	for k in ["modele", "monument", "epoque_bat", "blocks", "glb", "boutique_eco", "reseau", "telecom", "funeraire",
			"expedition", "zoo", "club_bat", "spect", "immo", "touris", "saisons", "dechets", "parc", "prod"]:
		if t.has(k):
			return false
	if t.get("espace", false):
		return false
	return Personnalisation.can_shape(o, perso)


static func build_mesh(id: String, material: Material, details: bool, variant: int, perso: Dictionary) -> ArrayMesh:
	var o := origine(id)
	var z := dims(id)
	var p := perso.duplicate()
	if Personnalisation.is_classic(o) and hauteur_reglable(o):
		p = Personnalisation.completer(o, p, true)
	if _par_style(o, p):
		# Redessiné à la bonne taille : fenêtres, étages et toit à leur place.
		if not p.has("etages"):
			p["etages"] = int(z.e)
		var ts := Personnalisation.type_of(o, p).duplicate()
		ts["w"] = int(z.w)
		ts["d"] = int(z.d)
		var k := BlocMesh.new()
		k.details = details
		k.variant = variant
		k.perso = p
		StyleBuilder.build(k, ts)
		k.fit_xz(float(z.w), float(z.d))
		return k.to_mesh(material)
	# Autres modèles : étirés au sol, étages ajoutés ou retirés.
	var b := dims(o)
	var m := BuildingCatalog.build_mesh(o, material, details, variant, perso)
	m = etirer(m, float(z.w) / maxf(1.0, float(b.w)), float(z.d) / maxf(1.0, float(b.d)))
	if hauteur_reglable(o) and int(z.e) != int(b.e):
		m = changer_etages(m, int(z.e) - int(b.e), int(b.e))
	return m


static func _copie_tableaux(arr: Array) -> Dictionary:
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	if idx.is_empty():
		idx.resize(vs.size())
		for i in vs.size():
			idx[i] = i
	return {"v": vs, "n": arr[Mesh.ARRAY_NORMAL] if arr[Mesh.ARRAY_NORMAL] != null else PackedVector3Array(),
		"c": arr[Mesh.ARRAY_COLOR] if arr[Mesh.ARRAY_COLOR] != null else PackedColorArray(),
		"u": arr[Mesh.ARRAY_TEX_UV] if arr[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array(), "i": idx}


static func _surface(out: ArrayMesh, src: ArrayMesh, s: int, ov: PackedVector3Array, on: PackedVector3Array,
		oc: PackedColorArray, ou: PackedVector2Array, oi := PackedInt32Array()) -> void:
	if ov.is_empty():
		return
	var na := []
	na.resize(Mesh.ARRAY_MAX)
	na[Mesh.ARRAY_VERTEX] = ov
	if not on.is_empty():
		na[Mesh.ARRAY_NORMAL] = on
	if not oc.is_empty():
		na[Mesh.ARRAY_COLOR] = oc
	if not ou.is_empty():
		na[Mesh.ARRAY_TEX_UV] = ou
	if not oi.is_empty():
		na[Mesh.ARRAY_INDEX] = oi
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, na)
	out.surface_set_material(out.get_surface_count() - 1, src.surface_get_material(s))


static func _metas(src: ArrayMesh, out: ArrayMesh, f: Callable) -> void:
	for m in src.get_meta_list():
		out.set_meta(m, src.get_meta(m))
	if src.has_meta("ancres"):
		var anc: Dictionary = (src.get_meta("ancres") as Dictionary).duplicate(true)
		for kind in anc:
			var list: Array = anc[kind]
			for j in list.size():
				if list[j] is Vector3:
					list[j] = f.call(list[j])
		out.set_meta("ancres", anc)


## Copie d'un maillage étirée au sol (sx le long de la façade, sz en profondeur).
static func etirer(mesh: ArrayMesh, sx: float, sz: float) -> ArrayMesh:
	if mesh == null or mesh.get_surface_count() == 0 or (is_equal_approx(sx, 1.0) and is_equal_approx(sz, 1.0)):
		return mesh
	var out := ArrayMesh.new()
	for s in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(s)
		var vs: PackedVector3Array = (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).duplicate()
		for i in vs.size():
			vs[i] = Vector3(vs[i].x * sx, vs[i].y, vs[i].z * sz)
		var ns := PackedVector3Array()
		if arr[Mesh.ARRAY_NORMAL] != null:
			ns = (arr[Mesh.ARRAY_NORMAL] as PackedVector3Array).duplicate()
			for i in ns.size():
				ns[i] = Vector3(ns[i].x / sx, ns[i].y, ns[i].z / sz).normalized()
		_surface(out, mesh, s, vs, ns, arr[Mesh.ARRAY_COLOR] if arr[Mesh.ARRAY_COLOR] != null else PackedColorArray(),
			arr[Mesh.ARRAY_TEX_UV] if arr[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array(),
			arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array())
	_metas(mesh, out, func(p: Vector3) -> Vector3: return Vector3(p.x * sx, p.y, p.z * sz))
	return out


## Copie d'un maillage avec delta étages de plus (ou de moins) : le rez-de-chaussée
## reste, l'étage au-dessus est recopié (ou retiré), murs étirés, toit déplacé.
static func changer_etages(mesh: ArrayMesh, delta: int, e0: int) -> ArrayMesh:
	if mesh == null or delta == 0 or mesh.get_surface_count() == 0:
		return mesh
	var H := BatimentsVie.body_bounds(mesh).end.y
	# Hauteur d'un étage du modèle (murs sans le toit, ≈ 80 % de la hauteur).
	var fh := clampf(H * 0.8 / maxf(1.0, float(e0)), 2.8, 6.0)
	var bas := fh # haut du rez-de-chaussée
	const E := 0.02
	var out := ArrayMesh.new()
	if delta < 0:
		# Étages retirés : la bande [bas, bas + n × fh] disparaît, le haut descend.
		var n := mini(-delta, e0 - 1)
		if n <= 0:
			return mesh
		var haut := bas + fh * n
		var dy := -fh * n
		for s in mesh.get_surface_count():
			var a := _copie_tableaux(mesh.surface_get_arrays(s))
			var vs: PackedVector3Array = a.v
			var ov := PackedVector3Array()
			var on := PackedVector3Array()
			var oc := PackedColorArray()
			var ou := PackedVector2Array()
			var idx: PackedInt32Array = a.i
			for k in range(0, idx.size() - 2, 3):
				var tri := [idx[k], idx[k + 1], idx[k + 2]]
				var dans := true
				for i in tri:
					if vs[i].y <= bas + E or vs[i].y >= haut - E:
						dans = false
				if dans:
					continue # fenêtres et bandeaux des étages retirés
				for i in tri:
					var v: Vector3 = vs[i]
					if v.y >= haut - E:
						v.y += dy
					elif v.y > bas:
						v.y = bas
					ov.append(v)
					if not (a.n as PackedVector3Array).is_empty():
						on.append(a.n[i])
					if not (a.c as PackedColorArray).is_empty():
						oc.append(a.c[i])
					if not (a.u as PackedVector2Array).is_empty():
						ou.append(a.u[i])
			_surface(out, mesh, s, ov, on, oc, ou)
		_metas(mesh, out, func(p: Vector3) -> Vector3:
			if p.y >= haut:
				return p + Vector3(0, dy, 0)
			return Vector3(p.x, minf(p.y, bas) if p.y > bas else p.y, p.z))
		return out
	# Étages ajoutés : on recopie l'étage au-dessus du rez-de-chaussée (s'il y en a
	# un), sinon les murs s'étirent.
	var y_c := bas + fh if e0 >= 2 else bas
	var copie := e0 >= 2
	var decal := fh * delta
	for s in mesh.get_surface_count():
		var a := _copie_tableaux(mesh.surface_get_arrays(s))
		var vs: PackedVector3Array = a.v
		var ov := PackedVector3Array()
		var on := PackedVector3Array()
		var oc := PackedColorArray()
		var ou := PackedVector2Array()
		var emit := func(i: int, dy: float) -> void:
			ov.append(vs[i] + Vector3(0, dy, 0))
			if not (a.n as PackedVector3Array).is_empty():
				on.append(a.n[i])
			if not (a.c as PackedColorArray).is_empty():
				oc.append(a.c[i])
			if not (a.u as PackedVector2Array).is_empty():
				ou.append(a.u[i])
		var idx: PackedInt32Array = a.i
		for k in range(0, idx.size() - 2, 3):
			var tri := [idx[k], idx[k + 1], idx[k + 2]]
			var lo := INF
			var hi := -INF
			for i in tri:
				lo = minf(lo, vs[i].y)
				hi = maxf(hi, vs[i].y)
			if hi <= y_c + E:
				for i in tri:
					emit.call(i, 0.0)
				if copie and lo >= y_c - fh - E and hi > 0.6:
					for j in delta:
						for i in tri:
							emit.call(i, fh * (j + 1))
			elif lo >= y_c - E:
				for i in tri:
					emit.call(i, decal)
			else:
				for i in tri:
					emit.call(i, decal if vs[i].y > y_c + E else 0.0)
		_surface(out, mesh, s, ov, on, oc, ou)
	_metas(mesh, out, func(p: Vector3) -> Vector3: return p + Vector3(0, decal, 0) if p.y > y_c else p)
	return out
