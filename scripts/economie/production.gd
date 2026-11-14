class_name Production
extends Node
## Économie locale : extraction, transformation, commerces, entrepôts et
## livraisons par camion.
##
## - Chaque bâtiment de la catégorie « Production », chaque commerce et chaque
##   entrepôt est un SITE avec son propre stock. Une ferme remplit son stock de
##   céréales, le moulin a son stock de céréales et de farine, la boulangerie
##   ses rayons de pain.
## - Les marchandises voyagent en CAMION sur les routes : quand un site manque
##   d'un intrant ou qu'un commerce voit ses rayons baisser, la ville envoie une
##   livraison depuis le fournisseur le plus proche qui en a. Il faut un
##   habitant au métier de chauffeur-livreur, au travail à ce moment-là, chez
##   le fournisseur, le client, un entrepôt ou une entreprise de transport.
##   Pas de chauffeur, pas de route : rupture de stock.
## - Les entrepôts servent de relais : le surplus d'un site y part, et on vient
##   s'y servir. Sans fournisseur sur la carte, les camions vont chercher la
##   marchandise hors de la carte (import) par une route qui sort par le bord
##   ou un dépôt, une gare, un port ; le surplus part de même à l'export.
## - Les habitants achètent chaque jour dans les commerces les plus proches de
##   chez eux. Rayons vides : ils sont moins satisfaits.
## - Chaque site est une ENTREPRISE avec sa caisse : elle vend, achète, paie
##   ses salaires et le transport. La ville (ta caisse) touche seulement un
##   impôt sur ses bénéfices.

signal changed
signal message(text: String)
## Une tonne extraite d'un site (les carrières creusent le terrain d'autant).
signal extrait(bid: int, res: String, t: float)
## Une journée vient de se terminer (courses faites, salaires payés).
signal day_passed

## Stock maximal d'un entrepôt (t, toutes marchandises).
const STOCK_ENTREPOT := 20000.0
## Stock maximal d'un site pour chaque marchandise qu'il produit : tant de
## jours de production, et au moins SITE_MIN_T.
const SITE_DAYS := 5.0
const SITE_MIN_T := 20.0
## Jours d'avance visés : intrants des usines, rayons des commerces.
const TARGET_DAYS_SITE := 3.0
const TARGET_DAYS_SHOP := 4.0
## On recommande quand le stock (plus ce qui roule déjà vers le site) passe
## sous cette part de l'objectif.
const REORDER := 0.5
## Le surplus part vers un entrepôt ou l'export au-delà de cette part du stock maximal.
const PUSH := 0.6
## Pas de temps de la logistique (s de jeu).
const LOG_STEP := 900.0
## Chargement ou déchargement d'un camion (s).
const HANDLING := 1200.0
## Un commerce sert les foyers à moins de SHOP_MAX m (à vol d'oiseau).
const SHOP_MAX := 6000.0
## Camions de livraison visibles au plus en même temps.
const MAX_VISIBLE := 60
## Transport facturé au client par un transporteur extérieur (€/km et par course),
## et gazole payé par l'entreprise du chauffeur (€/km).
const FRAIS_KM := 1.8
const FRAIS_COURSE := 20.0
const GAZOLE_KM := 0.6
## Impôt de la ville sur les bénéfices des entreprises (réglage Impôts × ce taux).
const IMPOT_BENEFICES := 0.25
## Export et import par jour pour chaque dépôt de marchandises, gare ou port (t).
const EXPORT_PAR_STATION := 150.0
const EXPORT_STATIONS := ["depot", "gare", "port"]
## Sorties par les bords de la carte : une voie qui arrive à moins de EDGE_M
## du bord de la région exporte tant de tonnes par jour, selon son mode.
const EDGE_M := 300.0
const EDGE_EXPORT := {TransportTypes.Mode.ROAD: 200.0, TransportTypes.Mode.RAIL: 800.0, TransportTypes.Mode.WATER: 1200.0}
## Forêts et poissons : repousse logistique et prélèvement par jour. À plein
## régime, la ressource se stabilise à 1 − PRELEVEMENT / REPOUSSE = 60 %.
const REPOUSSE := 0.02
const PRELEVEMENT := 0.008
const VITALITE_MIN := 0.05
## Charges patronales, comme pour la ville.
const CHARGES := 1.45
const DAYS_PER_MONTH := 30.0
## Camions selon la marchandise : du plus petit au plus gros.
const CAMIONS := {"caisse": ["fourgon", "porteur", "semi"], "liquide": ["citerne"], "vrac": ["benne", "semi"], "grumes": ["grumier"]}

var world: TerrainWorld
var buildings: BuildingSystem
var population: Population
var transport: TransportSystem
var ambiance: DayNight
var carte: CarteRessources
## Agriculture (champs, élevage) : les fermes qu'elle gère produisent par elle,
## et elle dit ce qu'elles fournissent et ce dont elles ont besoin. Objet avec
## manages(bid), outputs(bid), needs(bid), cap(bid, g), status_of(bid).
var agri: Object = null

## Sites : id du bâtiment -> {kind, st (stock), inc (en route vers lui), res,
## rich, reserve, vit, work, eff, status, cash, mois, dem, manque…}.
## kind : "extraction", "transformation", "logistique", "commerce", "entrepot".
var sites: Dictionary = {}
## Livraisons en cours : id -> {from, to, gw, cargo, driver, base, t0, t_unload, t_end, model, km, kind, done}.
var missions: Dictionary = {}
var next_mission := 1
## Chauffeurs occupés : id de l'habitant -> fin de sa tournée (unix).
var busy: Dictionary = {}
## Foyers mal servis hier : id du logement -> {marchandise: t manquantes}.
var manque_foyers: Dictionary = {}
## Flux du jour en cours et de la veille : {prod, conso, vente, export, import, livre} (t par marchandise).
var today := {}
var yesterday := {}
## Comptes de toute l'économie locale : {mois: {poste: €}, precedent: {}, jours}.
var ledger := {"mois": {}, "precedent": {}, "jours": 0}
## Horloge de la logistique (unix) et jour en cours.
var clock := -1.0
var last_unix := -1.0
var last_day := -1
var _log_n := 0
## Import et export déjà faits aujourd'hui (t).
var _gate_used := {"import": 0.0, "export": 0.0}
var _money_frac := 0.0
var _freight_seen := 0.0
var _dirty := true
var _routes: Dictionary = {}
var _gates: Array = []
var _gates_ok := false
var _shop_lists: Dictionary = {}
var _dem_today: Dictionary = {}
var _waiting_driver := 0
## Marchandises commandées au dernier pas de logistique.
var _wanted: Dictionary = {}
## Règle facultative des sites d'extraction (Carrieres) : bid -> raison qui
## empêche d'extraire, "" si tout va bien.
var extraction_gate: Callable


func _init() -> void:
	today = _empty_flows()
	yesterday = _empty_flows()


static func _empty_flows() -> Dictionary:
	return {"prod": {}, "conso": {}, "vente": {}, "export": {}, "import": {}, "livre": {}}


func setup(w: TerrainWorld, b: BuildingSystem, p: Population, t: TransportSystem, a: DayNight) -> void:
	world = w
	buildings = b
	population = p
	transport = t
	ambiance = a
	carte = CarteRessources.new(w)
	buildings.extra_check = check_site
	buildings.changed.connect(func() -> void:
		_dirty = true
		_shop_lists.clear())
	if transport != null:
		transport.network_changed.connect(func(_a = null) -> void: _network_changed())
	if population != null:
		population.extra_satisfaction = satisfaction_of


func _network_changed() -> void:
	for bid in sites:
		sites[bid].erase("acc")
		sites[bid].erase("quai")
	_routes.clear()
	_gates_ok = false


func clear() -> void:
	for mid in missions:
		_drop_visual(int(mid))
	sites.clear()
	missions.clear()
	busy.clear()
	manque_foyers.clear()
	next_mission = 1
	today = _empty_flows()
	yesterday = _empty_flows()
	ledger = {"mois": {}, "precedent": {}, "jours": 0}
	clock = -1.0
	last_unix = -1.0
	last_day = -1
	_log_n = 0
	_gate_used = {"import": 0.0, "export": 0.0}
	_money_frac = 0.0
	_freight_seen = _freight_total()
	_routes.clear()
	_gates_ok = false
	_shop_lists.clear()
	_dem_today.clear()
	_dirty = true
	changed.emit()


# --- Pose : richesse du sol --------------------------------------------------------

## Règle de pose de BuildingSystem : refuse un site d'extraction sans ressource.
func check_site(id: String, rect: Rect2i) -> Dictionary:
	var prod := ProductionTypes.prod_of(id)
	if prod.is_empty():
		return {}
	if prod.kind == "transformation":
		return {"info": recipe_text(id)}
	if prod.kind == "logistique":
		return {"info": "Ses chauffeurs-livreurs livrent toute la ville."}
	if prod.kind == "elevage":
		return {"info": "Élevage : achète les bêtes et nourris-les (Maj+F, Agriculture)."}
	if prod.kind == "service" or prod.kind == "entrepot":
		return {"info": String(BuildingCatalog.get_type(id).get("desc", ""))}
	var best := carte.best_of((prod.res as Dictionary).keys(), rect, float(prod.get("radius", 0.0)))
	if float(best.rich) < 0.0:
		return {"reason": "Ressources en cours de lecture (relief et biomes)…"}
	var need := float(prod.get("min", 0.1))
	if String(best.res) == "" or float(best.rich) < need:
		var names: Array[String] = []
		for r in prod.res:
			names.append(String(Ressources.naturelle(r).name).to_lower())
		var found := 0.0 if String(best.res) == "" else float(best.rich)
		if names.size() > 1:
			return {"reason": "Aucun gisement assez riche ici (%s : %d %%, il faut %d %%). Ouvre la carte des ressources (P)." % [
				", ".join(names).replace("minerai de ", ""), roundi(found * 100.0), roundi(need * 100.0)]}
		return {"reason": "Pas assez de %s ici (%d %%, il faut %d %%). Ouvre la carte des ressources (P)." % [
			names[0], roundi(found * 100.0), roundi(need * 100.0)]}
	var res := String(best.res)
	var t_day := float(prod.res[res]) * float(best.rich)
	var good := _good_of(prod, res)
	var txt := "%s : richesse %d %% · environ %s par jour à plein régime" % [Ressources.naturelle(res).name,
		roundi(float(best.rich) * 100.0), Ressources.format_t(t_day)]
	if prod.has("reserve") and not Ressources.naturelle(res).get("renouvelable", false):
		txt += " · réserve %s" % Ressources.format_t(float(prod.reserve) * float(best.rich))
	if good != res:
		txt += " (%s)" % Ressources.good_name(good).to_lower()
	return {"info": txt}


## Marchandise que tire un site d'extraction de la ressource naturelle res.
static func _good_of(prod: Dictionary, res: String) -> String:
	if prod.has("good"):
		return String(prod.good)
	return String(Ressources.naturelle(res).get("good", res))


## « 30 t de bois → 18 t de planches par jour ».
static func recipe_text(id: String) -> String:
	var prod := ProductionTypes.prod_of(id)
	if prod.is_empty():
		var shop := Ressources.commerce_of(id)
		if shop.has("vend"):
			var g: Array[String] = []
			for x in shop.vend:
				g.append(Ressources.good_name(x).to_lower())
			return "Vend : " + ", ".join(g)
		if shop.has("consomme"):
			return "Sert des repas et des boissons (livré en boissons, pain, viande, légumes…)"
		return ""
	if prod.kind == "logistique":
		return "Chauffeurs-livreurs pour toute la ville"
	if prod.kind == "elevage":
		return "Élevage : bêtes, fourrage et produits (Maj+F)"
	if prod.kind == "service":
		return "Machines agricoles : vente, location, réparations"
	if prod.kind == "entrepot":
		return "Entrepôt : stocke les récoltes et les marchandises"
	if prod.kind == "extraction":
		var names: Array[String] = []
		for r in prod.res:
			names.append(String(Ressources.naturelle(r).name).to_lower())
		var out := "Extrait : " + ", ".join(names)
		if prod.has("good"):
			out += " → " + Ressources.good_name(String(prod.good)).to_lower()
		return out
	var a: Array[String] = []
	for g in prod.in:
		a.append("%s de %s" % [Ressources.format_t(float(prod.in[g])), Ressources.good_name(g).to_lower()])
	var b: Array[String] = []
	for g in prod.out:
		b.append("%s de %s" % [Ressources.format_t(float(prod.out[g])), Ressources.good_name(g).to_lower()])
	if b.is_empty():
		return "Brûle %s par jour" % " + ".join(a)
	return "%s → %s par jour" % [" + ".join(a), " + ".join(b)]


# --- Sites ------------------------------------------------------------------------------

## Genre de site d'un type de bâtiment ("" : pas un site).
static func kind_of(type_id: String) -> String:
	var prod := ProductionTypes.prod_of(type_id)
	if not prod.is_empty():
		return String(prod.kind)
	# Fermes de la bible (bergerie, porcherie, ferme à cour carrée…) : élevage et champs.
	if AgriDonnees.est_ferme(type_id):
		return "elevage"
	var t := BuildingCatalog.get_type(type_id)
	if type_id == "entrepot" or String(t.get("arch", "")) == "entrepot":
		return "entrepot"
	if not Ressources.commerce_of(type_id).is_empty():
		return "commerce"
	return ""


func _sync() -> void:
	_dirty = false
	if buildings == null:
		return
	for bid in sites.keys():
		if not buildings.buildings.has(bid) or kind_of(String(buildings.buildings[bid].t)) != String(sites[bid].kind):
			_remove_site(bid)
	for bid in buildings.buildings:
		var b: Dictionary = buildings.buildings[bid]
		var kind := kind_of(String(b.t))
		if kind == "":
			continue
		if not sites.has(bid):
			sites[bid] = _new_site(kind)
			_shop_lists.clear()
		var s: Dictionary = sites[bid]
		var prod := ProductionTypes.prod_of(String(b.t))
		if kind == "extraction" and float(s.rich) < 0.0:
			var best := carte.best_of((prod.res as Dictionary).keys(), buildings._rect_of(b), float(prod.get("radius", 0.0)))
			if float(best.rich) >= 0.0:
				s.res = String(best.res)
				s.rich = float(best.rich)
				var nat := Ressources.naturelle(s.res)
				if prod.has("reserve") and not nat.get("renouvelable", false) and not nat.get("infini", false):
					s.reserve = float(prod.reserve) * float(s.rich)


static func _new_site(kind: String) -> Dictionary:
	return {"kind": kind, "st": {}, "inc": {}, "res": "", "rich": -1.0, "reserve": -1.0, "eff": 0.0, "status": "", "vit": 1.0,
		"work": 0.0, "cash": 0.0, "mois": {}, "prec": {}, "dem": {}, "manque": {}, "attente": ""}


## Un site disparaît (démoli) : ses livraisons en cours sont annulées.
func _remove_site(bid: int) -> void:
	sites.erase(bid)
	_shop_lists.clear()
	for mid in missions.keys():
		var m: Dictionary = missions[mid]
		if int(m.from) == bid or int(m.to) == bid:
			_cancel(int(mid))


func _type_of(bid: int) -> String:
	return String(buildings.buildings.get(bid, {}).get("t", ""))


func _workers(bid: int) -> int:
	if population == null:
		return 0
	return (population.by_job.get(bid, []) as Array).size()


func _staff(bid: int) -> float:
	var jobs := maxi(int(BuildingCatalog.get_type(_type_of(bid)).get("emplois", 1)), 1)
	return clampf(float(_workers(bid)) / jobs, 0.0, 1.0) * _rendement(bid)


## Rendement d'une entreprise selon les autres systèmes (courant, eau, internet…) :
## produit des valeurs des nœuds du groupe "rendement_sources" (1 = normal).
func _rendement(bid: int) -> float:
	if not is_inside_tree():
		return 1.0
	var r := 1.0
	var nodes: Array
	if _pas > 0:
		if _rendement_nodes == null:
			_rendement_nodes = get_tree().get_nodes_in_group("rendement_sources")
		nodes = _rendement_nodes
	else:
		nodes = get_tree().get_nodes_in_group("rendement_sources")
	for n in nodes:
		if n.has_method("rendement"):
			r *= clampf(float(n.rendement(bid)), 0.0, 1.0)
	return r


func _has_access(bid: int) -> bool:
	var s: Dictionary = sites[bid]
	if not s.has("acc"):
		var b: Dictionary = buildings.buildings[bid]
		var t := BuildingCatalog.get_type(String(b.t))
		s.acc = (t.get("access", []) as Array).is_empty() or not buildings.find_access(String(b.t), buildings._rect_of(b), int(b.r), float(b.get("a", 0.0))).is_empty()
	return bool(s.acc)


## Quai d'un site : le point de la route devant sa porte, où les camions
## chargent et déchargent : {e (tronçon), s (distance depuis son nœud a), a, b,
## len, pos} ; {} si aucune route n'arrive devant.
func access_of(bid: int) -> Dictionary:
	if not sites.has(bid) or transport == null:
		return {}
	var st: Dictionary = sites[bid]
	if st.has("quai"):
		return st.quai
	st.quai = {}
	var b: Dictionary = buildings.buildings.get(bid, {})
	if b.is_empty():
		return {}
	var door := BuildingSystem.door_point(String(b.t), buildings._rect_of(b), int(b.r), float(b.get("a", 0.0)))
	var best_d := INF
	for eid in transport.edges_near(door, 60.0):
		var e: Dictionary = transport.network.edges[eid]
		if TransportTypes.mode_of(e.t) != TransportTypes.Mode.ROAD:
			continue
		var hit: Dictionary = transport.network.nearest_on_edge(eid, door)
		if float(hit.dist) >= best_d:
			continue
		best_d = float(hit.dist)
		st.quai = {"e": int(eid), "s": float(hit.get("s", 0.0)), "a": int(e.a), "b": int(e.b), "len": float(e.len), "pos": hit.pos}
	return st.quai


## Nœud de route le plus proche du quai d'un site (-1 : aucun).
func node_of(bid: int) -> int:
	var q := access_of(bid)
	if q.is_empty():
		return -1
	return int(q.a) if float(q.s) <= float(q.len) * 0.5 else int(q.b)


## Point de chargement d'un site (son quai) ou d'une porte d'import (un nœud).
func _pt(bid: int, gw := -1) -> Dictionary:
	if bid >= 0:
		return access_of(bid)
	return {"n": gw} if gw >= 0 else {}


## Bouts de route d'un point : [[nœud, mètres jusqu'au nœud]].
static func _ends(p: Dictionary) -> Array:
	if p.has("n"):
		return [[int(p.n), 0.0]]
	return [[int(p.a), float(p.s)], [int(p.b), float(p.len) - float(p.s)]]


## Trajet par la route entre deux points (quais ou nœuds) : {m, s} ; m = INF sans chemin.
func route_pts(p: Dictionary, q: Dictionary) -> Dictionary:
	if p.is_empty() or q.is_empty():
		return {"m": INF, "s": INF}
	if p.has("e") and q.has("e") and int(p.e) == int(q.e):
		var d := absf(float(p.s) - float(q.s))
		return {"m": d, "s": d / 12.0}
	var best := {"m": INF, "s": INF}
	for x in _ends(p):
		for y in _ends(q):
			var r := route_between(int(x[0]), int(y[0]))
			var m := float(x[1]) + float(r.m) + float(y[1])
			if m < float(best.m):
				best = {"m": m, "s": float(r.s) + (float(x[1]) + float(y[1])) / 12.0}
	return best


## Étape d'un camion à l'écran : devant la porte d'un site, ou sur un nœud.
static func _halt(p: Dictionary) -> Dictionary:
	if p.has("n"):
		return {"n": int(p.n)}
	return {"e": int(p.e), "s": float(p.s)}


func _pos_of(bid: int) -> Vector3:
	var b: Dictionary = buildings.buildings.get(bid, {})
	if b.is_empty():
		return Vector3.ZERO
	return BuildingSystem.rect_center(buildings._rect_of(b))


## Trajet par la route entre deux nœuds : {m, s (secondes)} ; m = INF sans chemin.
func route_between(a: int, b: int) -> Dictionary:
	if a < 0 or b < 0:
		return {"m": INF, "s": INF}
	if a == b:
		return {"m": 0.0, "s": 0.0}
	var key := Vector2i(a, b)
	if _routes.has(key):
		return _routes[key]
	var r := transport.network.find_route(a, b)
	var out := {"m": INF, "s": INF}
	if not r.is_empty():
		var m := 0.0
		var sec := 0.0
		for eid in r:
			var e: Dictionary = transport.network.edges[eid]
			m += float(e.len)
			sec += float(e.len) / maxf(minf(TransportTypes.speed_of(e.t), 25.0) * 0.8, 3.0)
		out = {"m": m, "s": sec}
	_routes[key] = out
	return out


# --- Stocks ------------------------------------------------------------------------------

## Marchandises produites par un site, par jour à plein régime : {marchandise: t}.
func outputs_of(bid: int) -> Dictionary:
	var s: Dictionary = sites[bid]
	var prod := ProductionTypes.prod_of(_type_of(bid))
	if agri != null and agri.manages(bid):
		return agri.outputs(bid)
	match String(s.kind):
		"extraction":
			if String(s.res) == "":
				return {}
			return {_good_of(prod, s.res): float(prod.res[s.res]) * maxf(float(s.rich), 0.0)}
		"transformation":
			return prod.out
		"commerce":
			var shop := Ressources.commerce_of(_type_of(bid))
			if shop.has("fait"):
				var out := {}
				for g in shop.fait.out:
					out[g] = float(_shop_need(bid, g))
				return out
	return {}


## Stock maximal d'un site pour une marchandise.
func cap_of(bid: int, good: String) -> float:
	var s: Dictionary = sites[bid]
	match String(s.kind):
		"entrepot":
			return STOCK_ENTREPOT
		"commerce":
			return maxf(_shop_need(bid, good) * TARGET_DAYS_SHOP * 1.5, 0.05)
	if agri != null and agri.manages(bid):
		var c := float(agri.cap(bid, good))
		if c > 0.0:
			return c
	var out := outputs_of(bid)
	if out.has(good):
		return maxf(float(out[good]) * SITE_DAYS, SITE_MIN_T)
	var prod := ProductionTypes.prod_of(_type_of(bid))
	if prod.get("kind", "") == "transformation" and prod.in.has(good):
		return maxf(float(prod.in[good]) * TARGET_DAYS_SITE * 1.5, 1.0)
	return 0.0


func stock_of(bid: int, good: String) -> float:
	return float(sites[bid].st.get(good, 0.0)) if sites.has(bid) else 0.0


func _stock_total(bid: int) -> float:
	var t := 0.0
	for g in sites[bid].st:
		t += float(sites[bid].st[g])
	return t


## Place libre (t) dans un site pour une marchandise.
func room_of(bid: int, good: String) -> float:
	var s: Dictionary = sites[bid]
	if String(s.kind) == "entrepot":
		var inc := 0.0
		for g in s.inc:
			inc += float(s.inc[g])
		return maxf(STOCK_ENTREPOT - _stock_total(bid) - inc, 0.0)
	return maxf(cap_of(bid, good) - stock_of(bid, good) - float(s.inc.get(good, 0.0)), 0.0)


func _put(bid: int, good: String, t: float) -> void:
	var st: Dictionary = sites[bid].st
	st[good] = maxf(float(st.get(good, 0.0)) + t, 0.0)
	if float(st[good]) < 0.00001:
		st.erase(good)


## Toutes les marchandises de la ville : {marchandise: t} (stocks des sites).
func total_stock() -> Dictionary:
	var out := {}
	for bid in sites:
		for g in sites[bid].st:
			out[g] = float(out.get(g, 0.0)) + float(sites[bid].st[g])
	return out


## Marchandises dans les camions : {marchandise: t}.
func in_transit() -> Dictionary:
	var out := {}
	for m in missions.values():
		if bool(m.get("done", false)):
			continue
		for g in m.cargo:
			out[g] = float(out.get(g, 0.0)) + float(m.cargo[g])
	return out


## Capacité de tous les entrepôts (t).
func capacity() -> float:
	var c := 0.0
	for s in sites.values():
		if String(s.kind) == "entrepot":
			c += STOCK_ENTREPOT
	return c


func _flow(good: String, t: float, flow: String) -> void:
	var f: Dictionary = today[flow]
	f[good] = float(f.get(good, 0.0)) + absf(t)


# --- Comptes des entreprises --------------------------------------------------------------

## Ajoute (ou retire, t < 0) une marchandise dans le stock d'un site.
func put(bid: int, good: String, t: float) -> void:
	if sites.has(bid):
		_put(bid, good, t)
		_flow(good, t, "prod" if t > 0.0 else "conso")


## Paie (amount < 0) ou encaisse une somme pour une entreprise.
func pay(bid: int, poste: String, amount: float) -> void:
	_pay(bid, poste, amount)


## Écrit un mouvement dans la caisse d'une entreprise (et dans les comptes de l'économie).
func _pay(bid: int, poste: String, amount: float) -> void:
	if not sites.has(bid) or absf(amount) < 0.0001:
		return
	var s: Dictionary = sites[bid]
	s.cash = float(s.cash) + amount
	var m: Dictionary = s.mois
	m[poste] = float(m.get(poste, 0.0)) + amount
	s.jour = float(s.get("jour", 0.0)) + amount


func _book(cat: String, amount: float) -> void:
	if absf(amount) < 0.005:
		return
	var m: Dictionary = ledger.mois
	m[cat] = float(m.get(cat, 0.0)) + amount


# --- Temps -------------------------------------------------------------------------------

func _day_of(unix: float) -> int:
	return int(floorf((unix + _utc() * 3600.0) / 86400.0))


func _utc() -> float:
	return ambiance.utc_offset() if ambiance != null else 0.0


func _process(_delta: float) -> void:
	if _dirty:
		_sync()
	if ambiance == null:
		return
	var t := ambiance.unix_time
	if last_unix < 0.0:
		last_unix = t
		if last_day < 0:
			last_day = _day_of(t)
		_freight_seen = _freight_total()
		return
	var dt := clampf(t - last_unix, 0.0, 86400.0 * 3.0)
	last_unix = t
	if dt > 0.0:
		advance(dt)


## Fait avancer l'économie de dt secondes de jeu : logistique toutes les 15 min,
## production toutes les heures, ventes et salaires chaque jour.
func advance(dt: float) -> void:
	if _dirty:
		_sync()
	var end_t := (ambiance.unix_time if ambiance != null else clock + dt)
	if clock < 0.0 or absf(end_t - dt - clock) > 86400.0 * 4.0:
		clock = end_t - dt
	if last_day < 0:
		last_day = _day_of(clock)
	var n := 0
	while clock + LOG_STEP <= end_t + 0.001 and n < 400:
		clock += LOG_STEP
		n += 1
		_log_n += 1
		var d := _day_of(clock)
		if d > last_day:
			last_day = d
			new_day()
		if _log_n % 4 == 0:
			step_hours(1.0)
		logistics(clock)
	if clock < end_t - 86400.0:
		clock = end_t


## Heure locale à l'instant unix : {h, wd, month, mday, day} (comme Population.now).
func local_time(unix: float) -> Dictionary:
	var local := unix + _utc() * 3600.0
	var dt := Time.get_datetime_dict_from_unix_time(int(local))
	return {"h": fposmod(local, 86400.0) / 3600.0, "wd": int(dt.weekday), "month": int(dt.month), "mday": int(dt.day),
		"day": int(floorf(local / 86400.0))}


## Une tranche de production de `h` heures, dans le stock de chaque site.
func step_hours(h: float) -> void:
	if _dirty:
		_sync()
	_debut_pas()
	_step_hours(h)
	_fin_pas()


func _step_hours(h: float) -> void:
	var frac := h / 24.0
	for bid in sites:
		if not buildings.buildings.has(bid):
			continue
		var s: Dictionary = sites[bid]
		var kind := String(s.kind)
		var type_id := _type_of(bid)
		var t := BuildingCatalog.get_type(type_id)
		var staff := _staff(bid)
		s.eff = 0.0
		if kind == "logistique" or kind == "entrepot":
			s.status = _logistics_status(bid)
			s.eff = staff
			continue
		if not _has_access(bid):
			s.status = "Pas d'accès à une voie"
			continue
		if staff <= 0.0:
			s.status = "Personne n'y travaille : il faut des habitants"
			continue
		if agri != null and agri.manages(bid):
			s.status = String(agri.status_of(bid))
			s.eff = staff
			continue
		if kind == "elevage":
			s.status = "Ni champ ni bête : trace ses champs ou achète ses bêtes (Agriculture, Maj+F)"
			continue
		if kind == "service":
			s.status = "Ouvert" if staff >= 0.999 else "Ouvert (%d %% des emplois pourvus)" % roundi(staff * 100.0)
			s.eff = staff
			continue
		if kind == "commerce":
			_bake(bid, frac, staff)
			continue
		var prod: Dictionary = t.prod
		if prod.get("externe", false):
			# Site alimenté par un autre système (centre de tri : Dechets).
			s.eff = staff
			s.status = String(s.get("ext_status", "En activité"))
			continue
		if kind == "extraction":
			if extraction_gate.is_valid():
				var why: String = extraction_gate.call(bid)
				if why != "":
					s.status = why
					continue
			if String(s.res) == "":
				s.status = "Lecture du sol…" if float(s.rich) < 0.0 else "Aucune ressource ici"
				continue
			var good := _good_of(prod, s.res)
			var amount := float(prod.res[s.res]) * float(s.rich) * float(s.get("vit", 1.0)) * staff * frac
			var depletes := ReglagesPartie.actuel.epuisement
			if depletes and float(s.reserve) >= 0.0:
				if float(s.reserve) <= 0.0:
					s.status = "Gisement épuisé"
					continue
				amount = minf(amount, float(s.reserve))
			var space := cap_of(bid, good) - stock_of(bid, good)
			if space <= 0.0:
				s.status = "Stock de %s plein : aucun camion ne vient le chercher" % Ressources.good_name(good).to_lower()
				continue
			amount = minf(amount, space)
			if depletes and float(s.reserve) >= 0.0:
				s.reserve = float(s.reserve) - amount
				if float(s.reserve) <= 0.0:
					s.reserve = 0.0
					message.emit("%s : gisement de %s épuisé." % [t.name, Ressources.naturelle(s.res).name.to_lower()])
			_put(bid, good, amount)
			_flow(good, amount, "prod")
			extrait.emit(bid, String(s.res), amount)
			s.work = float(s.get("work", 0.0)) + staff * frac
			s.eff = staff
			s.status = "En activité" if staff >= 0.999 else "En activité (%d %% des emplois pourvus)" % roundi(staff * 100.0)
		else:
			var f := staff
			var missing: Array[String] = []
			for g in prod.in:
				var need := float(prod.in[g]) * frac * staff
				var have := stock_of(bid, g)
				if have < need:
					missing.append(Ressources.good_name(g).to_lower())
					f = minf(f, staff * have / need)
			for g in prod.out:
				var room := cap_of(bid, g) - stock_of(bid, g)
				f = minf(f, room / (float(prod.out[g]) * frac))
			f = maxf(f, 0.0)
			if f <= 0.0:
				s.status = ("Manque : %s (en attente de livraison)" % ", ".join(missing)) if not missing.is_empty() \
					else "Stock plein : aucun camion ne vient le chercher"
				continue
			for g in prod.in:
				_put(bid, g, -float(prod.in[g]) * frac * f)
				_flow(g, float(prod.in[g]) * frac * f, "conso")
			for g in prod.out:
				_put(bid, g, float(prod.out[g]) * frac * f)
				_flow(g, float(prod.out[g]) * frac * f, "prod")
			s.eff = f
			if not missing.is_empty():
				s.status = "Au ralenti (%d %%), manque : %s" % [roundi(f * 100.0), ", ".join(missing)]
			else:
				s.status = "En activité" if f >= 0.999 else "En activité (%d %%)" % roundi(f * 100.0)


## Un commerce qui fabrique (boulangerie) : le boulanger pétrit sa farine.
func _bake(bid: int, frac: float, staff: float) -> void:
	var s: Dictionary = sites[bid]
	var shop := Ressources.commerce_of(_type_of(bid))
	s.eff = staff
	s.status = _shop_status(bid)
	if not shop.has("fait"):
		return
	var fait: Dictionary = shop.fait
	for g in fait.out:
		var want := _shop_need(bid, g) * TARGET_DAYS_SHOP - stock_of(bid, g)
		# Un fournil de quartier cuit au plus 3 jours de ventes par jour.
		var amount := minf(want, _shop_need(bid, g) * 3.0 * frac * staff)
		for i in fait.in:
			var per := float(fait.in[i]) / float(fait.out[g])
			amount = minf(amount, stock_of(bid, i) / per)
		if amount <= 0.0:
			continue
		for i in fait.in:
			var used := amount * float(fait.in[i]) / float(fait.out[g])
			_put(bid, i, -used)
			_flow(i, used, "conso")
		_put(bid, g, amount)
		_flow(g, amount, "prod")


# --- Besoins ------------------------------------------------------------------------------

## Ventes estimées d'un commerce par jour (t), ou sa consommation (cafés).
func _shop_need(bid: int, good: String) -> float:
	var s: Dictionary = sites[bid]
	var t := BuildingCatalog.get_type(_type_of(bid))
	var shop := Ressources.commerce_of(_type_of(bid))
	var vis := float(maxi(int(t.get("visiteurs", 100)), 20))
	if shop.has("consomme"):
		return float(shop.consomme.get(good, 0.0)) * vis
	if s.dem.has(good):
		return maxf(float(s.dem[good]), 0.0005)
	var per := float(Ressources.CONSO_HABITANT.get(good, 0.0))
	if per <= 0.0:
		per = float(Ressources.CONSO_VOITURE.get(good, 0.0)) * 0.5
	return per * vis * 0.3


## Ce dont un site a besoin par jour : {marchandise: t}.
func needs_of(bid: int) -> Dictionary:
	var s: Dictionary = sites[bid]
	if agri != null and agri.manages(bid):
		return agri.needs(bid)
	# Pendant une tournée de livraisons, les besoins ne changent pas : calculés une fois.
	if _needs_cache != null:
		var c = _needs_cache.get(bid)
		if c == null:
			c = _needs_calc(bid, s)
			_needs_cache[bid] = c
		return c
	return _needs_calc(bid, s)


var _needs_cache = null


func _needs_calc(bid: int, s: Dictionary) -> Dictionary:
	var out := {}
	match String(s.kind):
		"transformation":
			var prod := ProductionTypes.prod_of(_type_of(bid))
			for g in prod.in:
				out[g] = float(prod.in[g])
		"commerce":
			var shop := Ressources.commerce_of(_type_of(bid))
			var made := {}
			if shop.has("fait"):
				for g in shop.fait.out:
					made[g] = true
					for i in shop.fait.in:
						out[i] = float(out.get(i, 0.0)) + _shop_need(bid, g) * float(shop.fait.in[i]) / float(shop.fait.out[g])
			for g in shop.get("vend", []):
				out[g] = float(out.get(g, 0.0)) + (0.0 if made.has(g) else _shop_need(bid, g))
			for g in shop.get("consomme", {}):
				out[g] = _shop_need(bid, g)
	return out


## Commandes d'un site : {marchandise: t à faire venir} (vide s'il est bien fourni).
func orders_of(bid: int) -> Dictionary:
	var s: Dictionary = sites[bid]
	var out := {}
	var days := TARGET_DAYS_SHOP if String(s.kind) == "commerce" else TARGET_DAYS_SITE
	var needs := needs_of(bid)
	var shop := Ressources.commerce_of(_type_of(bid))
	for g in needs:
		var need := float(needs[g])
		var have := stock_of(bid, g) + float(s.inc.get(g, 0.0))
		var target := need * days
		# Le boulanger qui manque de farine fait aussi venir du pain.
		if need <= 0.0 and shop.has("fait") and shop.fait.out.has(g):
			var flour := true
			for i in shop.fait.in:
				flour = flour and stock_of(bid, i) + float(s.inc.get(i, 0.0)) > 0.0001
			if flour:
				continue
			target = _shop_need(bid, g) * days
		if target <= 0.0 or have >= target * REORDER:
			continue
		out[g] = target - have
	return out


# --- Logistique ---------------------------------------------------------------------------

## Points d'import et d'export pour les camions : [{node, kind, name}].
func gateways() -> Array:
	if _gates_ok or transport == null or transport.network == null:
		return _gates
	_gates_ok = true
	_gates = []
	var lim := GameStart.REGION_SIZE * 0.5 - EDGE_M
	for nid in transport.network.nodes:
		var n: Dictionary = transport.network.nodes[nid]
		var p: Vector3 = n.p
		if int(n.m) == TransportTypes.Mode.ROAD and (absf(p.x) >= lim or absf(p.z) >= lim):
			_gates.append({"node": int(nid), "kind": "bord", "name": "route qui sort de la carte"})
	if transport.stations != null:
		for s in transport.stations.stations.values():
			if not String(s.get("type", "")) in EXPORT_STATIONS:
				continue
			var nid := int(s.get("node", -1))
			if nid >= 0 and transport.network.nodes.has(nid) and transport.network.node_mode(nid) != TransportTypes.Mode.ROAD:
				# Gare ou port : le camion vient au plus près par la route.
				nid = _road_node_near(transport.network.node_pos(nid), 200.0)
			if nid >= 0:
				_gates.append({"node": nid, "kind": String(s.type), "name": String(s.get("name", s.type))})
	return _gates


func _road_node_near(p: Vector3, radius: float) -> int:
	var best := -1
	var best_d := radius
	for eid in transport.edges_near(p, radius):
		var e: Dictionary = transport.network.edges[eid]
		if TransportTypes.mode_of(e.t) != TransportTypes.Mode.ROAD:
			continue
		for nid in [int(e.a), int(e.b)]:
			var d := transport.network.node_pos(nid).distance_to(p)
			if d < best_d:
				best_d = d
				best = nid
	return best


## Chauffeurs-livreurs : {id de l'employeur: [id des habitants]}.
func drivers() -> Dictionary:
	# Pendant un pas de simulation (tournée, heure), les emplois ne changent pas.
	if _pas > 0:
		if _drivers_cache == null:
			_drivers_cache = _drivers_calc()
		return _drivers_cache
	return _drivers_calc()


## Profondeur des pas en cours (caches valables tant qu'elle est > 0).
var _pas := 0
var _drivers_cache = null
var _rendement_nodes = null


func _debut_pas() -> void:
	_pas += 1


func _fin_pas() -> void:
	_pas -= 1
	if _pas <= 0:
		_pas = 0
		_drivers_cache = null
		_rendement_nodes = null


func _drivers_calc() -> Dictionary:
	var out := {}
	if population == null:
		return out
	for bid in population.by_job:
		for pid in population.by_job[bid]:
			if population.persons.has(pid) and String(population.persons[pid].get("met", "")) == "chauffeur":
				if not out.has(bid):
					out[bid] = []
				(out[bid] as Array).append(int(pid))
	return out


## Le chauffeur est-il à son poste à cet instant (jour et heures de travail) ?
func on_duty(pid: int, n: Dictionary) -> bool:
	if not population.persons.has(pid):
		return false
	var p: Dictionary = population.persons[pid]
	if not population._works_today(p, n) or population._on_leave(p, n):
		return false
	var h: Array = Metiers.job("chauffeur").h
	# Une tournée commence au plus tard une heure avant la fin du service.
	return float(n.h) >= float(h[0]) and float(n.h) < float(h[1]) - 1.0


func _free_drivers(t: float) -> Dictionary:
	var n := local_time(t)
	var out := {}
	var all := drivers()
	for bid in all:
		for pid in all[bid]:
			if float(busy.get(pid, 0.0)) > t:
				continue
			if on_duty(pid, n):
				if not out.has(bid):
					out[bid] = []
				(out[bid] as Array).append(pid)
	return out


## Choisit un chauffeur libre : chez le fournisseur, chez le client, puis dans
## un entrepôt ou une entreprise de transport (le plus proche du fournisseur).
func _pick_driver(free: Dictionary, src: int, dst: int, near: Vector3) -> Dictionary:
	for bid in [src, dst]:
		if free.has(bid) and not (free[bid] as Array).is_empty():
			return {"pid": int((free[bid] as Array).pop_back()), "base": bid}
	var best := -1
	var best_d := INF
	for bid in free:
		if (free[bid] as Array).is_empty() or not sites.has(bid):
			continue
		if not String(sites[bid].kind) in ["logistique", "entrepot"]:
			continue
		var d := _pos_of(bid).distance_squared_to(near)
		if d < best_d:
			best_d = d
			best = bid
	if best < 0:
		return {}
	return {"pid": int((free[best] as Array).pop_back()), "base": best}


## Un pas de logistique : arrivées des camions, puis nouvelles livraisons.
func logistics(t: float) -> void:
	for mid in missions.keys():
		var m: Dictionary = missions[mid]
		if not bool(m.get("done", false)) and float(m.t_unload) <= t:
			_unload(int(mid))
		if float(m.t_end) <= t:
			busy.erase(int(m.driver))
			missions.erase(mid)
	if buildings == null or population == null or transport == null:
		return
	_dispatch(t)


## Lance les livraisons : d'abord les commandes (les plus pressées d'abord),
## puis le surplus vers les entrepôts et l'export.
func _dispatch(t: float) -> void:
	_src_cache = {}
	_needs_cache = {}
	_debut_pas()
	_dispatch_inner(t)
	_fin_pas()
	_src_cache = null
	_needs_cache = null


## Pendant _dispatch : marchandise → sites qui peuvent la fournir (dans l'ordre de
## `sites`), calculé une fois. Les stocks, eux, sont relus à chaque commande.
var _src_cache = null


func _sources_for(g: String) -> Array:
	if _src_cache != null and _src_cache.has(g):
		return _src_cache[g]
	var out: Array = []
	for bid in sites:
		var kind := String(sites[bid].kind)
		if kind == "entrepot" or (kind in ["extraction", "transformation", "elevage"] and outputs_of(bid).has(g)):
			out.append(bid)
	if _src_cache != null:
		_src_cache[g] = out
	return out


func _dispatch_inner(t: float) -> void:
	var free := _free_drivers(t)
	var n_free := 0
	for bid in free:
		n_free += (free[bid] as Array).size()
	_waiting_driver = 0
	var orders: Array = []
	_wanted.clear()
	for bid in sites:
		var s: Dictionary = sites[bid]
		s.attente = ""
		var managed: bool = agri != null and agri.manages(bid)
		if not (String(s.kind) in ["transformation", "commerce"] or managed) or not buildings.buildings.has(bid):
			continue
		if _workers(bid) <= 0:
			continue
		var o := orders_of(bid)
		var needs := needs_of(bid)
		for g in o:
			_wanted[g] = true
			var need := maxf(float(needs.get(g, 0.0)), 0.0001)
			orders.append({"to": bid, "g": g, "q": float(o[g]), "u": (stock_of(bid, g) + float(s.inc.get(g, 0.0))) / need})
	orders.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.u) < float(b.u))
	var count := 0
	for o in orders:
		if count >= 40:
			break
		var to := int(o.to)
		var g := String(o.g)
		var q := float(orders_of(to).get(g, 0.0))
		if q <= 0.00001:
			continue
		var src := _best_source(to, g)
		if src.is_empty():
			sites[to].attente = "Aucun fournisseur de %s (ni sur la carte, ni par import)" % Ressources.good_name(g).to_lower()
			continue
		if n_free <= 0:
			_waiting_driver += 1
			sites[to].attente = "En attente d'un chauffeur-livreur"
			continue
		var from := int(src.bid)
		var drv := _pick_driver(free, from, to, _pos_of(from) if from >= 0 else _pos_of(to))
		if drv.is_empty():
			_waiting_driver += 1
			sites[to].attente = "En attente d'un chauffeur-livreur"
			continue
		n_free -= 1
		var cargo := _fill(from, to, g, q)
		if cargo.is_empty():
			busy.erase(int(drv.pid))
			continue
		_start(t, from, to, int(src.get("gw", -1)), cargo, drv, "import" if from < 0 else "livraison")
		count += 1
	if n_free > 0:
		_push_surplus(t, free, n_free)


## Meilleur fournisseur d'une marchandise pour un site : {bid, gw} (bid = -1 :
## import par la porte gw). Le plus proche par la route qui en a en stock.
func _best_source(to: int, g: String) -> Dictionary:
	var dst := access_of(to)
	if dst.is_empty():
		return {}
	var here := _pos_of(to)
	var cands: Array = []
	for bid in _sources_for(g):
		if bid == to:
			continue
		if stock_of(bid, g) > 0.001:
			cands.append([_pos_of(bid).distance_squared_to(here), bid])
	cands.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var best := {}
	var best_m := INF
	for i in mini(cands.size(), 5):
		var bid := int(cands[i][1])
		var r := route_pts(access_of(bid), dst)
		if float(r.m) < best_m:
			best_m = float(r.m)
			best = {"bid": bid}
	if not best.is_empty():
		return best
	# Rien sur la carte : import par la porte la plus proche.
	if _gate_left("import") <= 0.0:
		return {}
	var gw := _nearest_gate(dst)
	if gw < 0:
		return {}
	return {"bid": -1, "gw": gw}


func _nearest_gate(p: Dictionary) -> int:
	var best := -1
	var best_m := INF
	for gate in gateways():
		var r := route_pts({"n": int(gate.node)}, p)
		if float(r.m) < best_m:
			best_m = float(r.m)
			best = int(gate.node)
	return best


## Import ou export encore possible aujourd'hui (t).
func _gate_left(kind: String) -> float:
	return export_capacity() - float(_gate_used.get(kind, 0.0))


## Chargement d'un camion : la marchandise demandée, puis ce que le même client
## attend du même fournisseur (même genre de camion).
func _fill(from: int, to: int, g: String, q: float) -> Dictionary:
	var kind := Ressources.truck_kind(g)
	var models: Array = CAMIONS[kind]
	var cap := VehicleCatalog.capacity_t(String(models[models.size() - 1]))
	var cargo := {}
	var load := 0.0
	var wanted := orders_of(to)
	wanted[g] = q
	var list: Array = [g]
	for x in wanted:
		if x != g and Ressources.truck_kind(x) == kind:
			list.append(x)
	for x in list:
		var want := float(wanted[x])
		var avail := INF if from < 0 else stock_of(from, x)
		if from < 0:
			avail = _gate_left("import") - load
		var take := minf(minf(want, avail), cap - load)
		if take <= 0.0001:
			continue
		cargo[x] = take
		load += take
		if load >= cap - 0.001:
			break
	return cargo


## Plus petit camion qui porte la charge.
static func truck_for(cargo: Dictionary) -> String:
	var load := 0.0
	var kind := "caisse"
	for g in cargo:
		load += float(cargo[g])
		kind = Ressources.truck_kind(g)
	var models: Array = CAMIONS[kind]
	for m in models:
		if VehicleCatalog.capacity_t(String(m)) >= load - 0.001:
			return String(m)
	return String(models[models.size() - 1])


## Surplus : ce qui dépasse PUSH du stock maximal part vers l'entrepôt le plus
## proche qui a de la place, sinon à l'export.
func _push_surplus(t: float, free: Dictionary, n_free: int) -> void:
	for bid in sites:
		if n_free <= 0:
			return
		var s: Dictionary = sites[bid]
		if not String(s.kind) in ["extraction", "transformation", "elevage"] or _workers(bid) <= 0:
			continue
		var outs := outputs_of(bid)
		for g in outs:
			var cap := cap_of(bid, g)
			var have := stock_of(bid, g)
			if have <= cap * PUSH:
				continue
			# Quelqu'un en ville en a besoin : on attend sa commande.
			if _somebody_needs(g, bid):
				continue
			var models: Array = CAMIONS[Ressources.truck_kind(g)]
			var q := minf(have - cap * PUSH * 0.5, VehicleCatalog.capacity_t(String(models[models.size() - 1])))
			var dest := _nearest_warehouse(bid, g)
			var gw := -1
			if dest < 0:
				if _gate_left("export") <= 0.0:
					continue
				gw = _nearest_gate(access_of(bid))
				if gw < 0:
					continue
				q = minf(q, _gate_left("export"))
			else:
				q = minf(q, room_of(dest, g))
			if q <= 0.01:
				continue
			var drv := _pick_driver(free, bid, dest, _pos_of(bid))
			if drv.is_empty():
				return
			n_free -= 1
			_start(t, bid, dest, gw, {g: q}, drv, "stock" if dest >= 0 else "export")
			break


func _somebody_needs(g: String, _except: int) -> bool:
	return _wanted.has(g)


func _nearest_warehouse(from: int, g: String) -> int:
	var best := -1
	var best_m := INF
	var a := access_of(from)
	for bid in sites:
		if bid == from or String(sites[bid].kind) != "entrepot" or room_of(bid, g) < 1.0:
			continue
		var r := route_pts(a, access_of(bid))
		if float(r.m) < best_m:
			best_m = float(r.m)
			best = bid
	return best


## Lance une livraison : le chauffeur part de son employeur, charge, livre, rentre.
func _start(t: float, from: int, to: int, gw: int, cargo: Dictionary, drv: Dictionary, kind: String) -> void:
	var base := int(drv.base)
	var p_base := _pt(base)
	var p_from := _pt(from, gw)
	var p_to := _pt(to, gw)
	var r1 := route_pts(p_base, p_from) if base != from else {"m": 0.0, "s": 0.0}
	var r2 := route_pts(p_from, p_to)
	var r3 := route_pts(p_to, p_base)
	if float(r2.m) == INF:
		busy.erase(int(drv.pid))
		return
	var s1 := float(r1.s) if float(r1.s) < INF else 0.0
	var s3 := float(r3.s) if float(r3.s) < INF else float(r2.s)
	var km := (float(r1.m if float(r1.m) < INF else 0.0) + float(r2.m) + float(r3.m if float(r3.m) < INF else r2.m)) / 1000.0
	var mid := next_mission
	next_mission += 1
	var m := {"id": mid, "from": from, "to": to, "gw": gw, "cargo": cargo, "driver": int(drv.pid), "base": base,
		"t0": t, "t_unload": t + s1 + HANDLING + float(r2.s) + HANDLING, "t_end": 0.0, "km": km, "kind": kind,
		"model": truck_for(cargo), "done": false}
	m.t_end = float(m.t_unload) + s3
	missions[mid] = m
	busy[int(drv.pid)] = float(m.t_end)
	for g in cargo:
		var q := float(cargo[g])
		if from >= 0:
			_put(from, g, -q)
		else:
			_gate_used.import = float(_gate_used.import) + q
		if to >= 0:
			sites[to].inc[g] = float(sites[to].inc.get(g, 0.0)) + q
		else:
			_gate_used.export = float(_gate_used.export) + q
	_spawn_visual(mid, p_base if not p_base.is_empty() else p_from, [p_from, p_to, p_base])


## Le camion arrive chez le client : marchandise en rayon, factures payées.
func _unload(mid: int) -> void:
	var m: Dictionary = missions[mid]
	m.done = true
	var from := int(m.from)
	var to := int(m.to)
	var value := 0.0
	for g in m.cargo:
		var q := float(m.cargo[g])
		if to >= 0 and sites.has(to):
			sites[to].inc[g] = maxf(float(sites[to].inc.get(g, 0.0)) - q, 0.0)
			if float(sites[to].inc[g]) < 0.00001:
				sites[to].inc.erase(g)
			_put(to, g, q)
			_flow(g, q, "livre")
		if from < 0:
			_flow(g, q, "import")
			var cost := q * Ressources.price(g) * Ressources.IMPORT
			_pay(to, "Achats importés", -cost)
			_book("Importations", -cost)
		elif to < 0:
			_flow(g, q, "export")
			var gain := q * Ressources.price(g) * Ressources.EXPORT
			_pay(from, "Exportations", gain)
			_book("Exportations", gain)
		elif String(sites.get(to, {}).get("kind", "")) != "entrepot":
			value += q * Ressources.price(g)
	if value > 0.0 and from >= 0 and to >= 0:
		_pay(to, "Achats aux fournisseurs", -value)
		_pay(from, "Ventes aux entreprises", value)
		_book("Échanges entre entreprises", value)
	# L'entrepôt rachète le surplus au prix de l'export, et revend au prix de gros.
	if from >= 0 and to >= 0 and String(sites.get(to, {}).get("kind", "")) == "entrepot":
		var v := 0.0
		for g in m.cargo:
			v += float(m.cargo[g]) * Ressources.price(g) * Ressources.EXPORT
		_pay(to, "Achats aux fournisseurs", -v)
		_pay(from, "Ventes aux entreprises", v)
	# Transport : gazole pour l'employeur du chauffeur, course facturée par un transporteur.
	var base := int(m.base)
	_pay(base, "Gazole", -float(m.km) * GAZOLE_KM)
	_book("Gazole des camions", -float(m.km) * GAZOLE_KM)
	var payer := to if (to >= 0 and String(m.kind) != "stock") else from
	if payer >= 0 and base != payer:
		var fee := float(m.km) * FRAIS_KM + FRAIS_COURSE
		_pay(payer, "Transport", -fee)
		_pay(base, "Courses de livraison", fee)


func _cancel(mid: int) -> void:
	var m: Dictionary = missions[mid]
	if not bool(m.get("done", false)):
		for g in m.cargo:
			var q := float(m.cargo[g])
			if int(m.to) >= 0 and sites.has(int(m.to)):
				sites[int(m.to)].inc[g] = maxf(float(sites[int(m.to)].inc.get(g, 0.0)) - q, 0.0)
			if int(m.from) >= 0 and sites.has(int(m.from)):
				_put(int(m.from), g, q)
	busy.erase(int(m.driver))
	_drop_visual(mid)
	missions.erase(mid)


func _traffic() -> Traffic:
	if transport == null or transport.traffic == null or not transport.traffic.enabled:
		return null
	return transport.traffic


func _spawn_visual(mid: int, start: Dictionary, pts: Array) -> void:
	var tr := _traffic()
	if tr == null or tr.delivery_count() >= MAX_VISIBLE or start.is_empty():
		return
	var start_node := int(_ends(start)[0][0])
	if not start.has("n"):
		# Le camion part du bout de route le plus proche de son dépôt.
		start_node = int(start.a) if float(start.s) <= float(start.len) * 0.5 else int(start.b)
	var halts: Array = []
	for p in pts:
		if not (p as Dictionary).is_empty():
			halts.append(_halt(p))
	missions[mid].visual = tr.add_delivery_vehicle(mid, String(missions[mid].model), start_node, halts)


func _drop_visual(mid: int) -> void:
	var tr := _traffic()
	if tr == null:
		return
	for i in range(tr.vehicles.size() - 1, -1, -1):
		var v: Dictionary = tr.vehicles[i]
		if int(v.get("delivery", -1)) == mid:
			tr._free_vehicle(v)
			tr.vehicles.remove_at(i)


func _logistics_status(bid: int) -> String:
	var all := drivers()
	var n := (all.get(bid, []) as Array).size()
	var out := 0
	for m in missions.values():
		if int(m.base) == bid:
			out += 1
	var txt := "%d chauffeur%s-livreur%s, %d tournée%s en cours" % [n, "s" if n > 1 else "", "s" if n > 1 else "", out, "s" if out > 1 else ""]
	if String(sites[bid].kind) == "entrepot":
		txt = "Stock %s sur %s · " % [Ressources.format_t(_stock_total(bid)), Ressources.format_t(STOCK_ENTREPOT)] + txt
	return txt


func _shop_status(bid: int) -> String:
	var s: Dictionary = sites[bid]
	var empty: Array[String] = []
	for g in s.manque:
		empty.append(Ressources.good_name(g).to_lower())
	# Ce qu'il vend et n'a plus du tout (ni en rayon, ni de quoi le fabriquer).
	var shop := Ressources.commerce_of(_type_of(bid))
	var made: Dictionary = shop.get("fait", {}).get("out", {})
	for g in shop.get("vend", []):
		if s.manque.has(g) or stock_of(bid, g) > 0.0001:
			continue
		if made.has(g):
			var can := true
			for i in shop.fait.in:
				can = can and stock_of(bid, i) > 0.0001
			if can:
				continue
		empty.append(Ressources.good_name(g).to_lower())
	if not empty.is_empty():
		var txt := "Rayons vides : " + ", ".join(empty.slice(0, 3))
		if empty.size() > 3:
			txt += " et %d autre%s" % [empty.size() - 3, "s" if empty.size() > 4 else ""]
		return txt
	return "Ouvert, rayons garnis"


# --- Chaque jour : ventes, salaires, impôts ---------------------------------------------

## Il y a au moins un commerce de détail : les habitants peuvent acheter.
func has_shops() -> bool:
	for s in sites.values():
		if String(s.kind) == "commerce":
			return true
	return false


## Besoins des habitants par jour : {marchandise: t}.
func daily_needs() -> Dictionary:
	var out := {}
	if population == null:
		return out
	var people := population.persons.size()
	var cars := 0
	for h in population.households.values():
		cars += int(h.get("car", 0))
	for g in Ressources.CONSO_HABITANT:
		out[g] = 0.0
	# Les achats suivent le niveau de vie de chaque foyer (NiveauxVie).
	for h in population.households.values():
		var n := float((h.m as Array).size())
		for g in Ressources.CONSO_HABITANT:
			out[g] = float(out[g]) + float(Ressources.CONSO_HABITANT[g]) * n * NiveauxVie.coef_conso(h, String(g))
	for g in Ressources.CONSO_VOITURE:
		out[g] = float(Ressources.CONSO_VOITURE[g]) * cars
	return out


## Commerces qui vendent une marchandise, du plus proche au plus loin d'un logement.
func _shops_for(home: int, g: String) -> Array:
	var key := "%d:%s" % [home, g]
	if _shop_lists.has(key):
		return _shop_lists[key]
	var here := population.building_pos(home)
	var list: Array = []
	for bid in sites:
		if String(sites[bid].kind) != "commerce":
			continue
		var shop := Ressources.commerce_of(_type_of(bid))
		if not (shop.get("vend", []) as Array).has(g):
			continue
		var sp := _pos_of(bid)
		var d := Vector2(sp.x, sp.z).distance_to(Vector2(here.x, here.z))
		if d <= SHOP_MAX:
			list.append([d, bid])
	list.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var out: Array = []
	for e in list:
		out.append(int(e[1]))
	_shop_lists[key] = out
	return out


## Les foyers font leurs courses : chacun dans les commerces ouverts les plus
## proches de chez lui (jusqu'à 3). Ce qui manque est noté pour la satisfaction.
func _shopping() -> float:
	var gain := 0.0
	manque_foyers.clear()
	_dem_today.clear()
	for bid in sites:
		if String(sites[bid].kind) == "commerce":
			sites[bid].manque = {}
	if population == null:
		return 0.0
	var per_home := {}
	# Personnes pondérées par le niveau de vie (NiveauxVie) : x = nourriture, y = autres biens.
	var weight := {}
	for h in population.households.values():
		var hb := int(h.b)
		if not per_home.has(hb):
			per_home[hb] = Vector2i.ZERO
			weight[hb] = Vector2.ZERO
		var n := float((h.m as Array).size())
		per_home[hb] = (per_home[hb] as Vector2i) + Vector2i((h.m as Array).size(), int(h.get("car", 0)))
		weight[hb] = (weight[hb] as Vector2) + Vector2(n * NiveauxVie.coef_conso(h, "pain"), n * NiveauxVie.coef_conso(h, "vetements"))
	for home in per_home:
		var nc: Vector2i = per_home[home]
		var wt: Vector2 = weight[home]
		var want := {}
		for g in Ressources.CONSO_HABITANT:
			want[g] = float(Ressources.CONSO_HABITANT[g]) * (wt.y if NiveauxVie.BIENS_COURANTS.has(g) else wt.x)
		for g in Ressources.CONSO_VOITURE:
			if nc.y > 0:
				want[g] = float(Ressources.CONSO_VOITURE[g]) * nc.y
		for g in want:
			var left := float(want[g])
			var first := true
			var tries := 0
			for bid in _shops_for(home, g):
				if tries >= 3 or left <= 0.0:
					break
				if not sites.has(bid) or _workers(bid) <= 0 or not _has_access(bid):
					continue
				tries += 1
				if first:
					var d: Dictionary = _dem_today.get(bid, {})
					d[g] = float(d.get(g, 0.0)) + left
					_dem_today[bid] = d
					first = false
				var take := minf(left, stock_of(bid, g))
				if take < left:
					sites[bid].manque[g] = true
				if take <= 0.0:
					continue
				_put(bid, g, -take)
				_flow(g, take, "vente")
				var v := take * Ressources.price(g) * Ressources.DETAIL
				_pay(bid, "Ventes aux habitants", v)
				gain += v
				left -= take
			if left > float(want[g]) * 0.25:
				if not manque_foyers.has(home):
					manque_foyers[home] = {}
				manque_foyers[home][g] = left
	# Cafés et restaurants : ils servent leurs clients avec ce qu'ils ont reçu.
	for bid in sites:
		var s: Dictionary = sites[bid]
		var shop := Ressources.commerce_of(_type_of(bid))
		if String(s.kind) != "commerce" or not shop.has("consomme") or _workers(bid) <= 0:
			continue
		var staff := _staff(bid)
		var served := 1.0
		for g in shop.consomme:
			var need := _shop_need(bid, g) * staff
			if need <= 0.0:
				continue
			var take := minf(need, stock_of(bid, g))
			if take < need * 0.999:
				s.manque[g] = true
			served = minf(served, take / need) if g in ["boissons", "viande", "fruits_legumes"] else served
			_put(bid, g, -take)
			_flow(g, take, "vente")
		var vis := float(BuildingCatalog.get_type(_type_of(bid)).get("visiteurs", 100))
		var v := vis * staff * served * Ressources.REPAS
		_pay(bid, "Repas servis", v)
		gain += v
	# Ventes moyennes : l'objectif des rayons suit les achats réels.
	for bid in sites:
		if String(sites[bid].kind) != "commerce":
			continue
		var d: Dictionary = _dem_today.get(bid, {})
		var dem: Dictionary = sites[bid].dem
		var shop := Ressources.commerce_of(_type_of(bid))
		for g in shop.get("vend", []):
			var x := float(d.get(g, 0.0))
			dem[g] = x if not dem.has(g) else lerpf(float(dem[g]), x, 0.3)
	return gain


## Satisfaction d'un habitant liée aux commerces (Population.extra_satisfaction) : [delta, raisons].
func satisfaction_of(p: Dictionary) -> Array:
	if population == null or population.persons.is_empty():
		return [0.0, []]
	# Pas encore de journée de courses : rien à dire.
	if int(ledger.get("jours", 0)) <= 0 and (yesterday.vente as Dictionary).is_empty() and manque_foyers.is_empty():
		return [0.0, []]
	var home := population.home_of(p)
	var miss: Dictionary = manque_foyers.get(home, {})
	if miss.is_empty():
		return [4.0, ["+ commerces bien approvisionnés"]]
	var ess: Array[String] = []
	var other := 0
	for g in miss:
		if Ressources.ESSENTIELS.has(g):
			ess.append(Ressources.good_name(g).to_lower())
		else:
			other += 1
	var delta := -minf(3.0 * ess.size(), 18.0) - minf(float(other), 5.0)
	var why := "− rayons vides près de chez lui"
	if not ess.is_empty():
		why += " : " + ", ".join(ess.slice(0, 4)) + ("…" if ess.size() > 4 else "")
	return [delta, [why]]


## Tonnes transportées depuis le début par les lignes de fret.
func _freight_total() -> float:
	if transport == null or transport.stations == null:
		return 0.0
	var t := 0.0
	for l in transport.stations.lines.values():
		if bool(l.get("fret", false)):
			t += float(l.get("tonnes", 0.0))
	return t


## Stations qui expédient des marchandises (dépôts, gares, ports).
func export_stations() -> int:
	if transport == null or transport.stations == null:
		return 0
	var n := 0
	for s in transport.stations.stations.values():
		if String(s.get("type", "")) in EXPORT_STATIONS:
			n += 1
	return n


## Voies qui sortent de la région : {mode: nombre}.
func edge_exits() -> Dictionary:
	var out := {}
	if transport == null or transport.network == null:
		return out
	var lim := GameStart.REGION_SIZE * 0.5 - EDGE_M
	for n in transport.network.nodes.values():
		var p: Vector3 = n.p
		if absf(p.x) >= lim or absf(p.z) >= lim:
			var m := int(n.m)
			if EDGE_EXPORT.has(m):
				out[m] = int(out.get(m, 0)) + 1
	return out


## Capacité d'export (et d'import) du jour (t) : stations, bords de la carte, fret des lignes.
func export_capacity() -> float:
	var c := EXPORT_PAR_STATION * export_stations() + maxf(_freight_total() - _freight_seen, 0.0)
	var ex := edge_exits()
	for m in ex:
		c += float(EDGE_EXPORT[m]) * int(ex[m])
	return c


## Forêts et bancs de poissons : repousse et prélèvement de la journée.
func _regrow() -> void:
	for s in sites.values():
		var w := float(s.get("work", 0.0))
		s.work = 0.0
		if String(s.get("res", "")) == "" or not Ressources.naturelle(s.res).get("repousse", false):
			continue
		var v := float(s.get("vit", 1.0))
		# Sans épuisement (réglage Admin), l'exploitation n'abîme pas la ressource.
		var take := PRELEVEMENT * v * w if ReglagesPartie.actuel.epuisement else 0.0
		v += REPOUSSE * v * (1.0 - v) - take
		s.vit = clampf(v, VITALITE_MIN, 1.0)


func new_day() -> void:
	if _dirty:
		_sync()
	var before_empty := _empty_shelves()
	var gain_local := _shopping()
	# Salaires : chaque entreprise paie ses employés.
	var wages := 0.0
	if population != null:
		for bid in sites:
			var w := 0.0
			for pid in population.by_job.get(bid, []):
				if population.persons.has(pid):
					w += float(Metiers.job(String(population.persons[pid].met)).salaire) * ReglagesPartie.actuel.salaires * CHARGES / DAYS_PER_MONTH
			_pay(bid, "Salaires", -w)
			wages += w
	# Impôt de la ville sur les bénéfices du jour.
	var tax := 0.0
	for bid in sites:
		var s: Dictionary = sites[bid]
		var profit := float(s.get("jour", 0.0))
		s.jour = 0.0
		if profit > 0.0:
			var x := profit * IMPOT_BENEFICES * ReglagesPartie.actuel.impots * BudgetCommunal.facteur("benefices")
			_pay(bid, "Impôt sur les bénéfices", -x)
			s.jour = 0.0
			tax += x
		# Mois des entreprises.
		s.jours = int(s.get("jours", 0)) + 1
		if int(s.jours) >= 30:
			s.prec = s.mois
			s.mois = {}
			s.jours = 0
	_regrow()
	_book("Ventes aux habitants", gain_local)
	_book("Salaires des entreprises", -wages)
	_book("Impôt sur les bénéfices (pour la ville)", tax)
	BudgetCommunal.noter("Impôt sur les bénéfices", tax)
	if buildings != null and not buildings.unlimited_money:
		_money_frac += tax
		var whole := int(_money_frac)
		_money_frac -= whole
		# Plusieurs villes : réparti selon leur population (Pays).
		Pays.crediter(buildings, whole)
	_gate_used = {"import": 0.0, "export": 0.0}
	_freight_seen = _freight_total()
	var now_empty := _empty_shelves()
	if now_empty > before_empty and now_empty > 0:
		message.emit("Rayons vides dans %d commerce%s : il faut des livraisons (chauffeurs-livreurs, fournisseurs, routes)." % [
			now_empty, "s" if now_empty > 1 else ""])
	yesterday = today
	today = _empty_flows()
	ledger.jours = int(ledger.jours) + 1
	if int(ledger.jours) >= 30:
		ledger.precedent = ledger.mois
		ledger.mois = {}
		ledger.jours = 0
	changed.emit()
	day_passed.emit()


func _empty_shelves() -> int:
	var n := 0
	for s in sites.values():
		if String(s.kind) == "commerce" and not (s.manque as Dictionary).is_empty():
			n += 1
	return n


# --- Chiffres ------------------------------------------------------------------------------

## Texte court pour la barre d'état.
func summary() -> String:
	if sites.is_empty():
		return "Production : aucun site"
	var active := 0
	var prod_sites := 0
	for s in sites.values():
		if String(s.kind) in ["extraction", "transformation", "elevage"]:
			prod_sites += 1
			if float(s.get("eff", 0.0)) > 0.0:
				active += 1
	var on_road := 0
	for m in missions.values():
		if not bool(m.get("done", false)):
			on_road += 1
	return "Production : %d site%s, %d en activité · %d camion%s en livraison" % [prod_sites, "s" if prod_sites > 1 else "", active,
		on_road, "s" if on_road > 1 else ""]


## Chiffres des chauffeurs : {total, au_travail, libres, en_tournee, attente}.
func driver_stats() -> Dictionary:
	var all := drivers()
	var total := 0
	var duty := 0
	var free := 0
	var t := clock if clock > 0.0 else (ambiance.unix_time if ambiance != null else 0.0)
	var n := local_time(t)
	for bid in all:
		for pid in all[bid]:
			total += 1
			if on_duty(pid, n):
				duty += 1
				if float(busy.get(pid, 0.0)) <= t:
					free += 1
	return {"total": total, "au_travail": duty, "libres": free, "en_tournee": busy.size(), "attente": _waiting_driver}


## Nom court d'un site ou d'une porte d'import/export.
func place_name(bid: int, gw := -1) -> String:
	if bid < 0:
		for g in gateways():
			if int(g.node) == gw:
				return "hors de la carte (%s)" % g.name
		return "hors de la carte"
	return String(BuildingCatalog.get_type(_type_of(bid)).get("name", "?"))


## Description d'un site pour le panneau.
func site_info(bid: int) -> Dictionary:
	var b: Dictionary = buildings.buildings.get(bid, {})
	var s: Dictionary = sites.get(bid, {})
	if b.is_empty() or s.is_empty():
		return {}
	var t := BuildingCatalog.get_type(String(b.t))
	var status := String(s.get("status", ""))
	if String(s.kind) == "commerce" and _workers(bid) > 0:
		status = _shop_status(bid)
	elif _workers(bid) > 0 and status.begins_with("Personne"):
		status = "Embauche en cours"
	if String(s.get("attente", "")) != "":
		status += " · " + String(s.attente)
	var out := {"name": String(t.name), "kind": String(s.kind), "status": status, "eff": float(s.get("eff", 0.0)),
		"jobs": int(t.get("emplois", 0)), "workers": _workers(bid), "recipe": recipe_text(String(b.t)),
		"pos": BuildingSystem.rect_center(buildings._rect_of(b)), "stock": (s.st as Dictionary).duplicate(),
		"inc": (s.inc as Dictionary).duplicate(), "cash": float(s.cash), "mois": (s.mois as Dictionary).duplicate(),
		"drivers": (drivers().get(bid, []) as Array).size()}
	if String(s.get("res", "")) != "":
		out["res"] = String(Ressources.naturelle(s.res).name)
		out["rich"] = float(s.rich)
		if float(s.reserve) >= 0.0:
			out["reserve"] = float(s.reserve)
		if Ressources.naturelle(s.res).get("repousse", false):
			out["vit"] = float(s.get("vit", 1.0))
	return out


# --- Sauvegarde ----------------------------------------------------------------------------

static func _snap_dict(d: Dictionary, step := 0.0001) -> Dictionary:
	var out := {}
	for k in d:
		if absf(float(d[k])) > step * 0.5:
			out[k] = snappedf(float(d[k]), step)
	return out


func to_dict() -> Dictionary:
	var si := {}
	for bid in sites:
		var s: Dictionary = sites[bid]
		si[str(bid)] = {"kind": s.kind, "res": s.res, "rich": snappedf(float(s.rich), 0.0001), "reserve": snappedf(float(s.reserve), 0.01),
			"vit": snappedf(float(s.get("vit", 1.0)), 0.0001), "st": _snap_dict(s.st), "cash": snappedf(float(s.cash), 0.01),
			"mois": _snap_dict(s.mois, 0.01), "prec": _snap_dict(s.prec, 0.01), "jours": int(s.get("jours", 0)),
			"dem": _snap_dict(s.dem, 0.00001)}
	var mi := []
	for m in missions.values():
		mi.append({"id": m.id, "from": m.from, "to": m.to, "gw": m.gw, "cargo": _snap_dict(m.cargo), "driver": m.driver,
			"base": m.base, "t0": m.t0, "t_unload": m.t_unload, "t_end": m.t_end, "km": snappedf(float(m.km), 0.01),
			"kind": m.kind, "model": m.model, "done": m.done})
	var mf := {}
	for home in manque_foyers:
		mf[str(home)] = _snap_dict(manque_foyers[home], 0.00001)
	return {"version": 2, "sites": si, "missions": mi, "next_mission": next_mission, "comptes": ledger, "veille": yesterday,
		"freight_seen": _freight_seen, "money_frac": _money_frac, "clock": clock, "gates": _gate_used, "manque": mf}


func from_dict(d: Dictionary) -> void:
	clear()
	for k in d.get("sites", {}):
		var x: Dictionary = d.sites[k]
		var s := _new_site(String(x.get("kind", "")))
		s.res = String(x.get("res", ""))
		s.rich = float(x.get("rich", -1.0))
		s.reserve = float(x.get("reserve", -1.0))
		s.vit = float(x.get("vit", 1.0))
		s.cash = float(x.get("cash", 0.0))
		s.jours = int(x.get("jours", 0))
		for key in ["st", "mois", "prec", "dem"]:
			var src: Dictionary = x.get(key, {})
			var dst := {}
			for g in src:
				dst[String(g)] = float(src[g])
			s[key] = dst
		sites[int(k)] = s
	_dirty = true
	_sync()
	# Partie d'avant l'économie locale : le stock commun va dans les entrepôts,
	# sinon chez les sites qui produisent chaque marchandise.
	var legacy: Dictionary = d.get("stock", {})
	for g in legacy:
		var left := float(legacy[g])
		for bid in sites:
			if left <= 0.0:
				break
			var kind := String(sites[bid].kind)
			if kind == "entrepot" or (kind in ["extraction", "transformation"] and outputs_of(bid).has(g)):
				var q := minf(left, room_of(bid, g))
				_put(bid, String(g), q)
				left -= q
	var top := 0
	for x in d.get("missions", []):
		var m: Dictionary = (x as Dictionary).duplicate()
		for key in ["id", "from", "to", "gw", "driver", "base"]:
			m[key] = int(m.get(key, -1))
		for key in ["t0", "t_unload", "t_end", "km"]:
			m[key] = float(m.get(key, 0.0))
		var cargo := {}
		for g in m.get("cargo", {}):
			cargo[String(g)] = float(m.cargo[g])
		m.cargo = cargo
		m.done = bool(m.get("done", false))
		if (int(m.from) >= 0 and not sites.has(int(m.from))) or (int(m.to) >= 0 and not sites.has(int(m.to))):
			continue
		missions[int(m.id)] = m
		top = maxi(top, int(m.id))
		busy[int(m.driver)] = float(m.t_end)
		if not m.done and int(m.to) >= 0:
			for g in cargo:
				sites[int(m.to)].inc[g] = float(sites[int(m.to)].inc.get(g, 0.0)) + float(cargo[g])
	next_mission = maxi(int(d.get("next_mission", 1)), top + 1)
	var c: Dictionary = d.get("comptes", {})
	if not c.is_empty():
		ledger = {"mois": c.get("mois", {}), "precedent": c.get("precedent", {}), "jours": int(c.get("jours", 0))}
	var v: Dictionary = d.get("veille", {})
	if not v.is_empty():
		yesterday = _empty_flows()
		yesterday.merge(v, true)
	for home in d.get("manque", {}):
		manque_foyers[int(home)] = d.manque[home]
	_freight_seen = float(d.get("freight_seen", _freight_total()))
	_money_frac = float(d.get("money_frac", 0.0))
	clock = float(d.get("clock", -1.0))
	var gu: Dictionary = d.get("gates", {})
	_gate_used = {"import": float(gu.get("import", 0.0)), "export": float(gu.get("export", 0.0))}
