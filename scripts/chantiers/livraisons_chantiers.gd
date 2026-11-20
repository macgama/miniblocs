class_name LivraisonsChantiers
extends RefCounted
## Camions qui livrent les matériaux aux chantiers (MateriauxChantiers).
##
## Chaque tonne prise pour un chantier est mise de côté par fournisseur
## (carrière, usine, entrepôt… ou la route qui sort de la carte pour les
## imports) et par genre de camion (benne, grumier, camion à caisse). Dès qu'un
## plein est réuni, un camion part de chez le fournisseur, roule jusqu'au
## chantier par la route, décharge et rentre (le même trajet que les livraisons
## de l'économie, Production). Le reste du dernier plein part quand le
## chantier se termine (solder).
##
## Les tonnes et l'argent sont déjà comptés au moment où le chantier les prend :
## les camions montent à l'écran ce qui se passe (pas de chauffeur réservé, pas
## de sauvegarde). Sans route jusqu'au chantier, rien ne part.

## Étiquettes des camions dans Traffic (négatives : pas de conflit avec les
## livraisons de Production, les bennes à ordures ou les corbillards).
const TAG := -5_000_000
## Rayon (m) où l'on cherche une route devant le chantier.
const QUAI_RAYON := 80.0
## Camions au plus envoyés d'un coup pour un même chargement (rattrapage).
const MAX_PAR_APPEL := 3

## clé -> {from, kind, pos, cargo: {g: t}}
static var _attente := {}
## Quai de chaque chantier (clé de position) : {} si aucune route.
static var _quais := {}
static var _prod_id := 0
static var _n := 0
## Camions envoyés depuis le début de la partie (bilans et tests).
static var envoyes := 0


static func _cle_pos(pos: Vector3) -> String:
	return "%d:%d" % [roundi(pos.x), roundi(pos.z)]


## Charge d'un plein pour ce genre de camion (t).
static func plein(kind: String) -> float:
	var models: Array = Production.CAMIONS.get(kind, Production.CAMIONS["caisse"])
	return VehicleCatalog.capacity_t(String(models[models.size() - 1]))


## Met de côté t tonnes de g pour le chantier en pos, venues de from (-1 :
## import). Envoie un camion dès qu'un plein est prêt.
static func noter(prod: Production, from: int, g: String, t: float, pos: Vector3) -> void:
	if prod == null or not is_instance_valid(prod) or t <= 0.0:
		return
	if prod.get_instance_id() != _prod_id:
		_prod_id = prod.get_instance_id()
		_attente = {}
		_quais = {}
	var kind := Ressources.truck_kind(g)
	var cle := "%d|%s|%s" % [from, kind, _cle_pos(pos)]
	if not _attente.has(cle):
		_attente[cle] = {"from": from, "kind": kind, "pos": pos, "cargo": {}}
	var e: Dictionary = _attente[cle]
	e.cargo[g] = float(e.cargo.get(g, 0.0)) + t
	var cap := plein(kind)
	var n := 0
	while _charge(e.cargo) >= cap - 0.001 and n < MAX_PAR_APPEL:
		n += 1
		_envoyer(prod, int(e.from), pos, _prendre(e.cargo, cap))
	# Gros rattrapage (temps accéléré) : on ne garde pas des centaines de pleins en retard.
	if _charge(e.cargo) >= cap:
		_prendre(e.cargo, _charge(e.cargo) - cap * 0.5)


## Le chantier en pos se termine : les derniers chargements partent.
static func solder(pos: Vector3) -> void:
	var prod := Production.instance
	var suffixe := "|" + _cle_pos(pos)
	for cle in _attente.keys():
		if not String(cle).ends_with(suffixe):
			continue
		var e: Dictionary = _attente[cle]
		_attente.erase(cle)
		if prod != null and is_instance_valid(prod) and _charge(e.cargo) >= 0.5:
			_envoyer(prod, int(e.from), pos, e.cargo)
	_quais.erase(_cle_pos(pos))


## Tonnes en attente pour un chantier (tests, info-bulle).
static func en_attente(pos: Vector3) -> float:
	var suffixe := "|" + _cle_pos(pos)
	var out := 0.0
	for cle in _attente:
		if String(cle).ends_with(suffixe):
			out += _charge(_attente[cle].cargo)
	return out


static func _charge(cargo: Dictionary) -> float:
	var out := 0.0
	for g in cargo:
		out += float(cargo[g])
	return out


## Retire q tonnes du chargement, à parts égales entre ses marchandises.
static func _prendre(cargo: Dictionary, q: float) -> Dictionary:
	var tot := _charge(cargo)
	var out := {}
	if tot <= 0.0:
		return out
	var k := clampf(q / tot, 0.0, 1.0)
	for g in cargo.keys():
		var x := float(cargo[g]) * k
		out[g] = x
		cargo[g] = float(cargo[g]) - x
		if float(cargo[g]) < 0.0001:
			cargo.erase(g)
	return out


## Route devant le chantier : {e, s, a, b, len, pos} ; {} sans route proche.
static func _quai(prod: Production, pos: Vector3) -> Dictionary:
	var k := _cle_pos(pos)
	if _quais.has(k):
		return _quais[k]
	var out := {}
	var tr: TransportSystem = prod.transport
	if tr != null and tr.network != null:
		var best := INF
		for eid in tr.edges_near(pos, QUAI_RAYON):
			var e: Dictionary = tr.network.edges[eid]
			# Pas sur un tronçon lui-même en chantier : les camions n'y passent pas encore.
			if TransportTypes.mode_of(e.t) != TransportTypes.Mode.ROAD or e.has("ch"):
				continue
			var hit: Dictionary = tr.network.nearest_on_edge(eid, pos)
			if float(hit.dist) < best:
				best = float(hit.dist)
				out = {"e": int(eid), "s": float(hit.get("s", 0.0)), "a": int(e.a), "b": int(e.b), "len": float(e.len), "pos": hit.pos}
	_quais[k] = out
	return out


## Route qui sort de la carte la plus proche du chantier (imports) : {n} ou {}.
static func _porte(prod: Production, dest: Dictionary) -> Dictionary:
	var best := {}
	var best_m := INF
	for gate in prod.gateways():
		var nid := int(gate.node)
		if prod.transport.network.node_mode(nid) != TransportTypes.Mode.ROAD:
			continue
		var r := prod.route_pts({"n": nid}, dest)
		if float(r.m) < best_m:
			best_m = float(r.m)
			best = {"n": nid}
	return best


static func _envoyer(prod: Production, from: int, pos: Vector3, cargo: Dictionary) -> bool:
	if cargo.is_empty():
		return false
	var tr := prod._traffic()
	if tr == null or tr.delivery_count() >= Production.MAX_VISIBLE:
		return false
	var dest := _quai(prod, pos)
	if dest.is_empty():
		return false
	var depart := prod.access_of(from) if from >= 0 else _porte(prod, dest)
	if depart.is_empty() or float(prod.route_pts(depart, dest).m) == INF:
		return false
	var start := int(depart.n) if depart.has("n") else (int(depart.a) if float(depart.s) <= float(depart.len) * 0.5 else int(depart.b))
	_n = (_n + 1) % 1_000_000
	var ok := tr.add_delivery_vehicle(TAG - _n, Production.truck_for(cargo), start,
		[Production._halt(depart), Production._halt(dest), Production._halt(depart)])
	if ok:
		envoyes += 1
	return ok
