class_name Production
extends Node
## Chaînes de production : extraction, transformation, stocks, ventes, export.
##
## - Chaque bâtiment de la catégorie « Production » est un site. Un site
##   d'extraction tire une ressource naturelle du sol (richesse mesurée par
##   CarteRessources à la pose) ; un site de transformation prend des
##   marchandises dans le stock et en fabrique d'autres.
## - Façon Anno : tous les bâtiments desservis par une voie partagent le stock
##   de la ville (un entrepôt agrandit sa capacité).
## - Il faut des habitants : la production suit la part des emplois pourvus.
## - Chaque jour, les habitants achètent pain, viande, poisson, meubles, biens
##   et carburant dans les commerces de la ville (s'il y en a), et le surplus
##   part à l'export par les dépôts de marchandises, gares et ports, plus le
##   fret que transportent tes lignes. La caisse paie les salaires.

signal changed
signal message(text: String)

## Capacité de stockage par marchandise (t), et ce qu'ajoute un entrepôt.
const STOCK_BASE := 2000.0
const STOCK_ENTREPOT := 20000.0
## Export par jour pour chaque dépôt de marchandises, gare ou port (t).
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
## Stock gardé pour la ville avant d'exporter : jours de consommation et d'intrants.
const KEEP_DAYS := 3.0

var world: TerrainWorld
var buildings: BuildingSystem
var population: Population
var transport: TransportSystem
var ambiance: DayNight
var carte: CarteRessources

## Stock de la ville : marchandise -> tonnes.
var stock: Dictionary = {}
## Sites : id du bâtiment -> {res, rich, reserve (-1 = inépuisable), eff, status, acc}.
var sites: Dictionary = {}
## Flux du jour en cours et de la veille : {prod, conso, vente, export} (t par marchandise).
var today := {}
var yesterday := {}
## Comptes : {mois: {poste: €}, precedent: {}, jours}.
var ledger := {"mois": {}, "precedent": {}, "jours": 0}
var last_unix := -1.0
var last_day := -1
var _hour_acc := 0.0
var _money_frac := 0.0
var _freight_seen := 0.0
var _dirty := true


func _init() -> void:
	today = _empty_flows()
	yesterday = _empty_flows()


static func _empty_flows() -> Dictionary:
	return {"prod": {}, "conso": {}, "vente": {}, "export": {}}


func setup(w: TerrainWorld, b: BuildingSystem, p: Population, t: TransportSystem, a: DayNight) -> void:
	world = w
	buildings = b
	population = p
	transport = t
	ambiance = a
	carte = CarteRessources.new(w)
	buildings.extra_check = check_site
	buildings.changed.connect(func() -> void: _dirty = true)
	if transport != null:
		transport.network_changed.connect(func(_a = null) -> void:
			for bid in sites:
				sites[bid].erase("acc"))


func clear() -> void:
	stock.clear()
	sites.clear()
	today = _empty_flows()
	yesterday = _empty_flows()
	ledger = {"mois": {}, "precedent": {}, "jours": 0}
	last_unix = -1.0
	last_day = -1
	_hour_acc = 0.0
	_money_frac = 0.0
	_freight_seen = _freight_total()
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
	var good := String(Ressources.naturelle(res).good)
	var txt := "%s : richesse %d %% · environ %s par jour à plein régime" % [Ressources.naturelle(res).name,
		roundi(float(best.rich) * 100.0), Ressources.format_t(t_day)]
	if prod.has("reserve") and not Ressources.naturelle(res).get("renouvelable", false):
		txt += " · réserve %s" % Ressources.format_t(float(prod.reserve) * float(best.rich))
	if good != res:
		txt += " (%s)" % Ressources.good_name(good).to_lower()
	return {"info": txt}


## « 30 t de bois → 18 t de planches par jour ».
static func recipe_text(id: String) -> String:
	var prod := ProductionTypes.prod_of(id)
	if prod.is_empty():
		return ""
	if prod.kind == "extraction":
		var names: Array[String] = []
		for r in prod.res:
			names.append(String(Ressources.naturelle(r).name).to_lower())
		return "Extrait : " + ", ".join(names)
	var a: Array[String] = []
	for g in prod.in:
		a.append("%s de %s" % [Ressources.format_t(float(prod.in[g])), Ressources.good_name(g).to_lower()])
	var b: Array[String] = []
	for g in prod.out:
		b.append("%s de %s" % [Ressources.format_t(float(prod.out[g])), Ressources.good_name(g).to_lower()])
	return "%s → %s par jour" % [" + ".join(a), " + ".join(b)]


# --- Sites ------------------------------------------------------------------------------

func _sync() -> void:
	_dirty = false
	if buildings == null:
		return
	for bid in sites.keys():
		if not buildings.buildings.has(bid) or ProductionTypes.prod_of(String(buildings.buildings[bid].t)).is_empty():
			sites.erase(bid)
	for bid in buildings.buildings:
		var b: Dictionary = buildings.buildings[bid]
		var prod := ProductionTypes.prod_of(String(b.t))
		if prod.is_empty():
			continue
		if not sites.has(bid):
			sites[bid] = {"res": "", "rich": -1.0, "reserve": -1.0, "eff": 0.0, "status": "", "vit": 1.0, "work": 0.0}
		var s: Dictionary = sites[bid]
		if prod.kind == "extraction" and float(s.rich) < 0.0:
			var best := carte.best_of((prod.res as Dictionary).keys(), buildings._rect_of(b), float(prod.get("radius", 0.0)))
			if float(best.rich) >= 0.0:
				s.res = String(best.res)
				s.rich = float(best.rich)
				var nat := Ressources.naturelle(s.res)
				if prod.has("reserve") and not nat.get("renouvelable", false) and not nat.get("infini", false):
					s.reserve = float(prod.reserve) * float(s.rich)


func capacity() -> float:
	var c := STOCK_BASE
	if buildings != null:
		for b in buildings.buildings.values():
			if String(b.t) == "entrepot" or String(BuildingCatalog.get_type(String(b.t)).get("arch", "")) == "entrepot":
				c += STOCK_ENTREPOT
	return c


func _workers(bid: int) -> int:
	if population == null:
		return 0
	return (population.by_job.get(bid, []) as Array).size()


func _has_access(bid: int) -> bool:
	var s: Dictionary = sites[bid]
	if not s.has("acc"):
		var b: Dictionary = buildings.buildings[bid]
		var t := BuildingCatalog.get_type(String(b.t))
		s.acc = (t.get("access", []) as Array).is_empty() or not buildings.find_access(String(b.t), buildings._rect_of(b), int(b.r), float(b.get("a", 0.0))).is_empty()
	return bool(s.acc)


# --- Temps -------------------------------------------------------------------------------

func _day_of(unix: float) -> int:
	return int(floorf((unix + ambiance.utc_offset() * 3600.0) / 86400.0))


func _process(_delta: float) -> void:
	if _dirty:
		_sync()
	if ambiance == null:
		return
	var t := ambiance.unix_time
	if last_unix < 0.0:
		last_unix = t
		last_day = _day_of(t)
		_freight_seen = _freight_total()
		return
	var dt := clampf(t - last_unix, 0.0, 86400.0 * 3.0)
	last_unix = t
	if dt > 0.0:
		advance(dt)


## Fait avancer la production de dt secondes de jeu (pas d'une heure).
func advance(dt: float) -> void:
	if _dirty:
		_sync()
	_hour_acc += dt / 3600.0
	var n := 0
	while _hour_acc >= 1.0 and n < 96:
		_hour_acc -= 1.0
		n += 1
		step_hours(1.0)
	if ambiance != null:
		var d := _day_of(ambiance.unix_time)
		if last_day < 0:
			last_day = d
		var k := 0
		while last_day < d and k < 3:
			last_day += 1
			k += 1
			new_day()
		if last_day < d:
			last_day = d


## Une tranche de production de `h` heures : l'extraction d'abord, puis la
## transformation (dans l'ordre des chaînes : grumes avant planches avant meubles).
func step_hours(h: float) -> void:
	var frac := h / 24.0
	var cap := capacity()
	var order := sites.keys()
	order.sort_custom(func(a: int, b: int) -> bool: return _rank(a) < _rank(b))
	for bid in order:
		if not buildings.buildings.has(bid):
			continue
		var s: Dictionary = sites[bid]
		var type_id := String(buildings.buildings[bid].t)
		var t := BuildingCatalog.get_type(type_id)
		var prod: Dictionary = t.prod
		var jobs := maxi(int(t.get("emplois", 1)), 1)
		var staff := clampf(float(_workers(bid)) / jobs, 0.0, 1.0)
		s.eff = 0.0
		if not _has_access(bid):
			s.status = "Pas d'accès à une voie"
			continue
		if staff <= 0.0:
			s.status = "Personne n'y travaille : il faut des habitants"
			continue
		if prod.kind == "extraction":
			if String(s.res) == "":
				s.status = "Lecture du sol…" if float(s.rich) < 0.0 else "Aucune ressource ici"
				continue
			var good := String(Ressources.naturelle(s.res).good)
			var amount := float(prod.res[s.res]) * float(s.rich) * float(s.get("vit", 1.0)) * staff * frac
			if float(s.reserve) >= 0.0:
				if float(s.reserve) <= 0.0:
					s.status = "Gisement épuisé"
					continue
				amount = minf(amount, float(s.reserve))
			var space := cap - float(stock.get(good, 0.0))
			if space <= 0.0:
				s.status = "Stock de %s plein" % Ressources.good_name(good).to_lower()
				continue
			amount = minf(amount, space)
			if float(s.reserve) >= 0.0:
				s.reserve = float(s.reserve) - amount
				if float(s.reserve) <= 0.0:
					s.reserve = 0.0
					message.emit("%s : gisement de %s épuisé." % [t.name, Ressources.naturelle(s.res).name.to_lower()])
			_add(good, amount, "prod")
			s.work = float(s.get("work", 0.0)) + staff * frac
			s.eff = staff
			s.status = "En activité" if staff >= 0.999 else "En activité (%d %% des emplois pourvus)" % roundi(staff * 100.0)
		else:
			var f := staff
			var missing: Array[String] = []
			for g in prod.in:
				var need := float(prod.in[g]) * frac * staff
				var have := float(stock.get(g, 0.0))
				if have < need:
					missing.append(Ressources.good_name(g).to_lower())
					f = minf(f, staff * have / need)
			for g in prod.out:
				var room := cap - float(stock.get(g, 0.0))
				f = minf(f, room / (float(prod.out[g]) * frac))
			f = maxf(f, 0.0)
			if f <= 0.0:
				s.status = ("Manque : " + ", ".join(missing)) if not missing.is_empty() else "Stock plein"
				continue
			for g in prod.in:
				_add(g, -float(prod.in[g]) * frac * f, "conso")
			for g in prod.out:
				_add(g, float(prod.out[g]) * frac * f, "prod")
			s.eff = f
			if not missing.is_empty():
				s.status = "Au ralenti (%d %%), manque : %s" % [roundi(f * 100.0), ", ".join(missing)]
			else:
				s.status = "En activité" if f >= 0.999 else "En activité (%d %%)" % roundi(f * 100.0)


## Rang dans la chaîne : extraction (0), puis transformation des matières
## brutes (1), puis des produits déjà transformés (2).
func _rank(bid: int) -> int:
	var prod := ProductionTypes.prod_of(String(buildings.buildings.get(bid, {}).get("t", "")))
	if prod.is_empty() or prod.kind == "extraction":
		return 0
	for g in prod.in:
		if Ressources.source_of(g) == "":
			return 2
	return 1


func _add(good: String, t: float, flow: String) -> void:
	stock[good] = maxf(float(stock.get(good, 0.0)) + t, 0.0)
	var f: Dictionary = today[flow]
	f[good] = float(f.get(good, 0.0)) + absf(t)


# --- Chaque jour : ventes, export, salaires -------------------------------------------

## Il y a au moins un commerce : les habitants peuvent acheter.
func has_shops() -> bool:
	if buildings == null:
		return false
	for b in buildings.buildings.values():
		if String(BuildingCatalog.get_type(String(b.t)).get("cat", "")) == "commerce":
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
		out[g] = float(Ressources.CONSO_HABITANT[g]) * people
	for g in Ressources.CONSO_VOITURE:
		out[g] = float(Ressources.CONSO_VOITURE[g]) * cars
	return out


## Intrants consommés par jour par les transformations à plein régime.
func daily_inputs() -> Dictionary:
	var out := {}
	for bid in sites:
		if not buildings.buildings.has(bid):
			continue
		var prod := ProductionTypes.prod_of(String(buildings.buildings[bid].t))
		if prod.get("kind", "") != "transformation":
			continue
		for g in prod.in:
			out[g] = float(out.get(g, 0.0)) + float(prod.in[g])
	return out


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


## Capacité d'export du jour (t) : stations, bords de la carte, fret des lignes.
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
		v += REPOUSSE * v * (1.0 - v) - PRELEVEMENT * v * w
		s.vit = clampf(v, VITALITE_MIN, 1.0)


func new_day() -> void:
	var gain_local := 0.0
	var gain_export := 0.0
	var wages := 0.0
	# Ventes aux habitants dans les commerces.
	var needs := daily_needs()
	if has_shops():
		for g in needs:
			var sold := minf(float(needs[g]), float(stock.get(g, 0.0)))
			if sold <= 0.0:
				continue
			_add(g, -sold, "vente")
			gain_local += sold * Ressources.price(g) * Ressources.DETAIL
	# Export : ce qui dépasse les besoins de la ville pour quelques jours.
	var cap := export_capacity()
	_freight_seen = _freight_total()
	if cap > 0.0:
		var inputs := daily_inputs()
		var goods := stock.keys()
		goods.sort_custom(func(a: String, b: String) -> bool: return Ressources.price(a) > Ressources.price(b))
		for g in goods:
			if cap <= 0.0:
				break
			var keep := (float(needs.get(g, 0.0)) + float(inputs.get(g, 0.0))) * KEEP_DAYS
			var surplus := float(stock[g]) - keep
			if surplus <= 0.01:
				continue
			var sent := minf(surplus, cap)
			cap -= sent
			_add(g, -sent, "export")
			gain_export += sent * Ressources.price(g) * Ressources.EXPORT
	# Salaires des employés de la production.
	if population != null:
		for bid in sites:
			for pid in population.by_job.get(bid, []):
				if population.persons.has(pid):
					wages += float(Metiers.job(String(population.persons[pid].met)).salaire) * CHARGES / DAYS_PER_MONTH
	_regrow()
	_book("Ventes aux habitants", gain_local)
	_book("Exportations", gain_export)
	_book("Salaires de la production", -wages)
	if buildings != null and not buildings.unlimited_money:
		_money_frac += gain_local + gain_export - wages
		var whole := int(_money_frac)
		_money_frac -= whole
		buildings.money += whole
	yesterday = today
	today = _empty_flows()
	ledger.jours = int(ledger.jours) + 1
	if int(ledger.jours) >= 30:
		ledger.precedent = ledger.mois
		ledger.mois = {}
		ledger.jours = 0
	changed.emit()


func _book(cat: String, amount: float) -> void:
	if absf(amount) < 0.005:
		return
	var m: Dictionary = ledger.mois
	m[cat] = float(m.get(cat, 0.0)) + amount


# --- Chiffres ------------------------------------------------------------------------------

## Texte court pour la barre d'état.
func summary() -> String:
	if sites.is_empty():
		return "Production : aucun site"
	var active := 0
	for s in sites.values():
		if float(s.get("eff", 0.0)) > 0.0:
			active += 1
	return "Production : %d site%s, %d en activité" % [sites.size(), "s" if sites.size() > 1 else "", active]


## Description d'un site pour le panneau.
func site_info(bid: int) -> Dictionary:
	var b: Dictionary = buildings.buildings.get(bid, {})
	var s: Dictionary = sites.get(bid, {})
	if b.is_empty() or s.is_empty():
		return {}
	var t := BuildingCatalog.get_type(String(b.t))
	var out := {"name": String(t.name), "status": String(s.get("status", "")), "eff": float(s.get("eff", 0.0)),
		"jobs": int(t.get("emplois", 0)), "workers": _workers(bid), "recipe": recipe_text(String(b.t)),
		"pos": BuildingSystem.rect_center(buildings._rect_of(b))}
	if String(s.get("res", "")) != "":
		out["res"] = String(Ressources.naturelle(s.res).name)
		out["rich"] = float(s.rich)
		if float(s.reserve) >= 0.0:
			out["reserve"] = float(s.reserve)
		if Ressources.naturelle(s.res).get("repousse", false):
			out["vit"] = float(s.get("vit", 1.0))
	return out


# --- Sauvegarde ----------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var st := {}
	for g in stock:
		if float(stock[g]) > 0.0005:
			st[g] = snappedf(float(stock[g]), 0.001)
	var si := {}
	for bid in sites:
		var s: Dictionary = sites[bid]
		si[str(bid)] = {"res": s.res, "rich": snappedf(float(s.rich), 0.0001), "reserve": snappedf(float(s.reserve), 0.01),
			"vit": snappedf(float(s.get("vit", 1.0)), 0.0001)}
	return {"version": 1, "stock": st, "sites": si, "comptes": ledger, "veille": yesterday,
		"freight_seen": _freight_seen, "money_frac": _money_frac}


func from_dict(d: Dictionary) -> void:
	clear()
	for g in d.get("stock", {}):
		stock[String(g)] = float(d.stock[g])
	for k in d.get("sites", {}):
		var s: Dictionary = d.sites[k]
		sites[int(k)] = {"res": String(s.get("res", "")), "rich": float(s.get("rich", -1.0)),
			"reserve": float(s.get("reserve", -1.0)), "eff": 0.0, "status": "", "vit": float(s.get("vit", 1.0)), "work": 0.0}
	var c: Dictionary = d.get("comptes", {})
	if not c.is_empty():
		ledger = {"mois": c.get("mois", {}), "precedent": c.get("precedent", {}), "jours": int(c.get("jours", 0))}
	var v: Dictionary = d.get("veille", {})
	if not v.is_empty():
		yesterday = _empty_flows()
		yesterday.merge(v, true)
	_freight_seen = float(d.get("freight_seen", _freight_total()))
	_money_frac = float(d.get("money_frac", 0.0))
	_dirty = true
	_sync()
