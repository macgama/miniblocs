class_name ReseauBase
extends RefCounted
## Mécanique commune à tous les réseaux « de service » : électricité, eau,
## égouts, et plus tard fibre, gaz…
##
## - Tronçon : un tracé posé par le joueur (ligne HT, conduite, égout, câble),
##   en mètres comme les voies. Un tronçon en chantier (ok = false) ne porte rien.
## - Routes : si suit_routes, chaque route porte aussi la desserte locale
##   (basse tension, petites conduites), comme dans les city builders récents.
## - Source : un bâtiment qui fournit (centrale, usine d'eau, station d'épuration
##   qui reçoit). Consommateur : un bâtiment qui demande.
## - Un bâtiment est raccordé s'il est à moins de rayon_raccord d'un tracé.
##   Deux tracés se touchent si l'extrémité de l'un est à moins de SNAP de l'autre.
## - Dans chaque composante connexe, la production est partagée entre les
##   consommateurs : taux = min(1, production / demande).
##
## Unités libres (MW, m³/j…) : la base ne fait que des sommes.

signal changed

const SNAP := 4.0
const CELL := 32.0

var kind := ""
var rayon_raccord := 30.0
var suit_routes := true

## id -> {"pts": PackedVector3Array, "t": String, "ok": bool}
var troncons: Dictionary = {}
var next_id := 1
## bid -> {"p": Vector3, "cap": float}
var sources: Dictionary = {}
## bid -> {"p": Vector3, "d": float}
var consos: Dictionary = {}

# Résultats du dernier recalculer()
var _comp_of_bid: Dictionary = {}
## composante -> {"prod": float, "dem": float, "taux": float}
var composantes: Dictionary = {}
## Tracés du dernier calcul (tronçons en service puis routes) et leur composante.
var lignes: Array = []
var lignes_comp := PackedInt32Array()


func _init(k := "") -> void:
	kind = k


func clear() -> void:
	troncons.clear()
	sources.clear()
	consos.clear()
	_comp_of_bid.clear()
	composantes.clear()
	next_id = 1


# --- Pose ------------------------------------------------------------------

func poser_troncon(pts: PackedVector3Array, type_id: String, en_service := true) -> int:
	var id := next_id
	next_id += 1
	troncons[id] = {"pts": pts, "t": type_id, "ok": en_service}
	return id


func retirer_troncon(id: int) -> void:
	troncons.erase(id)


func terminer_troncon(id: int) -> void:
	if troncons.has(id):
		troncons[id].ok = true


static func longueur(pts: PackedVector3Array) -> float:
	var l := 0.0
	for i in range(1, pts.size()):
		l += pts[i].distance_to(pts[i - 1])
	return l


## marge : demi-taille du bâtiment (m), ajoutée au rayon de raccordement.
func ajouter_source(bid: int, pos: Vector3, capacite: float, marge := 0.0) -> void:
	sources[bid] = {"p": pos, "cap": capacite, "x": marge}


func retirer_source(bid: int) -> void:
	sources.erase(bid)


func set_capacite(bid: int, cap: float) -> void:
	if sources.has(bid):
		sources[bid].cap = cap


func ajouter_conso(bid: int, pos: Vector3, demande: float, marge := 0.0) -> void:
	consos[bid] = {"p": pos, "d": demande, "x": marge}


func set_demande(bid: int, demande: float) -> void:
	if consos.has(bid):
		consos[bid].d = demande


func retirer_conso(bid: int) -> void:
	consos.erase(bid)


# --- Calcul ----------------------------------------------------------------

## routes : tracés (PackedVector3Array) qui portent la desserte locale.
## Refait le raccordement (qui touche quoi), puis le partage (rebilan).
func recalculer(routes: Array = []) -> void:
	var lines: Array = []  # PackedVector3Array
	for id in troncons:
		if troncons[id].ok:
			lines.append(troncons[id].pts)
	if suit_routes:
		for r in routes:
			if (r as PackedVector3Array).size() >= 2:
				lines.append(r)
	var n := lines.size()
	var parent := PackedInt32Array()
	parent.resize(n)
	for i in n:
		parent[i] = i
	# Index spatial des segments : clé de case -> [ligne, segment]
	var grid := {}
	for li in n:
		var pts: PackedVector3Array = lines[li]
		for si in range(pts.size() - 1):
			for key in _cells_of_seg(pts[si], pts[si + 1], SNAP):
				if not grid.has(key):
					grid[key] = []
				grid[key].append(Vector2i(li, si))
	# Extrémités proches d'un autre tracé : union
	for li in n:
		var pts: PackedVector3Array = lines[li]
		for p in [pts[0], pts[pts.size() - 1]]:
			for hit in _near(grid, lines, p, SNAP):
				_union(parent, li, hit)
	lignes = lines
	lignes_comp.resize(n)
	for li in n:
		lignes_comp[li] = _find(parent, li)
	# Bâtiments -> tracé le plus proche
	_comp_of_bid.clear()
	composantes.clear()
	for dict in [sources, consos]:
		for bid in dict:
			var e: Dictionary = dict[bid]
			var li := _closest(grid, lines, e.p, rayon_raccord + float(e.get("x", 0.0)))
			if li >= 0:
				_comp_of_bid[bid] = _find(parent, li)
	rebilan()


## Refait seulement les sommes (capacités et demandes changées, mêmes raccordements).
func rebilan() -> void:
	composantes.clear()
	for bid in sources:
		var c: int = _comp_of_bid.get(bid, -1)
		if c < 0:
			continue
		_comp(c).prod += float(sources[bid].cap)
	for bid in consos:
		var c: int = _comp_of_bid.get(bid, -1)
		if c < 0:
			continue
		_comp(c).dem += float(consos[bid].d)
	for c in composantes:
		var k: Dictionary = composantes[c]
		k.taux = 1.0 if k.dem <= 0.0 else clampf(k.prod / k.dem, 0.0, 1.0)
	changed.emit()


func _comp(c: int) -> Dictionary:
	if not composantes.has(c):
		composantes[c] = {"prod": 0.0, "dem": 0.0, "taux": 0.0}
	return composantes[c]


func est_raccorde(bid: int) -> bool:
	return _comp_of_bid.has(bid)


func composante_de(bid: int) -> int:
	return _comp_of_bid.get(bid, -1)


## Part de la demande réellement fournie (0 = coupé, 1 = normal).
## État d'une composante : 1 = tout servi, entre les deux = rationné, 0 = rien.
func taux_composante(c: int) -> float:
	var k: Dictionary = composantes.get(c, {})
	if k.is_empty() or float(k.prod) <= 0.0:
		return 0.0
	return float(k.taux)


func taux_servi(bid: int) -> float:
	var c: int = _comp_of_bid.get(bid, -1)
	if c < 0:
		return 0.0
	var k: Dictionary = composantes.get(c, {})
	if k.is_empty() or float(k.prod) <= 0.0:
		return 0.0
	return float(k.taux)


func bilan() -> Dictionary:
	var prod := 0.0
	var dem := 0.0
	var servi := 0.0
	for bid in sources:
		if est_raccorde(bid):
			prod += float(sources[bid].cap)
	for bid in consos:
		dem += float(consos[bid].d)
		servi += float(consos[bid].d) * taux_servi(bid)
	return {"production": prod, "demande": dem, "servi": servi}


# --- Géométrie -------------------------------------------------------------

static func _key(x: float, z: float) -> Vector2i:
	return Vector2i(floori(x / CELL), floori(z / CELL))


static func _cells_of_seg(a: Vector3, b: Vector3, m: float) -> Array:
	var k0 := _key(minf(a.x, b.x) - m, minf(a.z, b.z) - m)
	var k1 := _key(maxf(a.x, b.x) + m, maxf(a.z, b.z) + m)
	var out := []
	for x in range(k0.x, k1.x + 1):
		for z in range(k0.y, k1.y + 1):
			out.append(Vector2i(x, z))
	return out


static func dist_seg(p: Vector3, a: Vector3, b: Vector3) -> float:
	var p2 := Vector2(p.x, p.z)
	var a2 := Vector2(a.x, a.z)
	var b2 := Vector2(b.x, b.z)
	var ab := b2 - a2
	var l2 := ab.length_squared()
	var t := 0.0 if l2 < 1e-6 else clampf((p2 - a2).dot(ab) / l2, 0.0, 1.0)
	return p2.distance_to(a2 + ab * t)


func _candidates(grid: Dictionary, p: Vector3, r: float) -> Array:
	var seen := {}
	var out := []
	var k0 := _key(p.x - r, p.z - r)
	var k1 := _key(p.x + r, p.z + r)
	for x in range(k0.x, k1.x + 1):
		for z in range(k0.y, k1.y + 1):
			for h in grid.get(Vector2i(x, z), []):
				if not seen.has(h):
					seen[h] = true
					out.append(h)
	return out


func _near(grid: Dictionary, lines: Array, p: Vector3, r: float) -> Array:
	var out := []
	for h in _candidates(grid, p, r):
		var pts: PackedVector3Array = lines[h.x]
		if dist_seg(p, pts[h.y], pts[h.y + 1]) <= r:
			out.append(h.x)
	return out


func _closest(grid: Dictionary, lines: Array, p: Vector3, r: float) -> int:
	var best := -1
	var bd := r
	for h in _candidates(grid, p, r):
		var pts: PackedVector3Array = lines[h.x]
		var d := dist_seg(p, pts[h.y], pts[h.y + 1])
		if d <= bd:
			bd = d
			best = h.x
	return best


static func _find(parent: PackedInt32Array, i: int) -> int:
	while parent[i] != i:
		parent[i] = parent[parent[i]]
		i = parent[i]
	return i


static func _union(parent: PackedInt32Array, a: int, b: int) -> void:
	var ra := _find(parent, a)
	var rb := _find(parent, b)
	if ra != rb:
		parent[ra] = rb


# --- Sauvegarde --------------------------------------------------------------
# Les sources et consommateurs viennent des bâtiments : ils sont reconstruits
# au chargement, seuls les tronçons sont gardés.

func to_dict() -> Dictionary:
	var t := {}
	for id in troncons:
		var e: Dictionary = troncons[id]
		var flat := []
		for p in (e.pts as PackedVector3Array):
			flat.append_array([snappedf(p.x, 0.01), snappedf(p.y, 0.01), snappedf(p.z, 0.01)])
		var x := {"t": e.t, "ok": e.ok, "p": flat}
		# Champs ajoutés par les systèmes (prix payé, avancement du chantier…).
		for k in e:
			if not k in ["t", "ok", "pts"]:
				x[k] = e[k]
		t[str(id)] = x
	return {"next": next_id, "troncons": t}


func from_dict(d: Dictionary) -> void:
	troncons.clear()
	next_id = int(d.get("next", 1))
	var t: Dictionary = d.get("troncons", {})
	for k in t:
		var e: Dictionary = t[k]
		var pts := PackedVector3Array()
		var flat: Array = e.get("p", [])
		for i in range(0, flat.size() - 2, 3):
			pts.append(Vector3(flat[i], flat[i + 1], flat[i + 2]))
		var tr := {"pts": pts, "t": String(e.get("t", "")), "ok": bool(e.get("ok", true))}
		for f in e:
			if not f in ["t", "ok", "p"]:
				tr[f] = e[f]
		troncons[int(k)] = tr
		next_id = maxi(next_id, int(k) + 1)
