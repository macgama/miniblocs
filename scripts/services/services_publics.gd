class_name ServicesPublics
extends Node
## Couverture des services publics : écoles, hôpitaux, police.
##
## Chaque logement est relié au service le plus rapide à rejoindre par les
## routes et chemins (temps de trajet réel), puis on regarde si ce service a
## encore de la place :
##   - école : pupitres (places), seuils de trajet par niveau (maternelle et
##     élémentaire 15 min, collège 25 min, lycée 40 min, à pied ou en car) ;
##     au-delà du double du seuil, l'élève reste « sans école » ;
##   - hôpital : lits (3 pour 1 000 habitants, comme en France), 30 min en voiture ;
##   - police : agents (1 pour 400 habitants), 10 min d'intervention.
## Un service saturé couvre moins bien (qualité × capacité / besoin).
##
## Conséquences : santé des habitants (CycleVie.health), satisfaction (Avis ou
## Population.extra_satisfaction), petits délits plus fréquents dans les
## quartiers sans police (cambriolages déclarés aux Urgences).
##
## Pour les autres systèmes :
##   ServicesPublics.couverture(pos, type) -> 0..1  (type "ecole", "hopital", "police" ou "" = moyenne)
##   ServicesPublics.instance.couverture_bid(bid, type)
##   ServicesPublics.instance.detail(bid, type) -> {q, min, via, charge, why}
##   ServicesPublics.instance.bilan(type) -> chiffres du panneau

signal changed

static var instance: ServicesPublics

const TYPES := ["ecole", "hopital", "police"]
const NOMS := {"ecole": "Écoles", "hopital": "Hôpitaux", "police": "Police"}
const NOM_UN := {"ecole": "école", "hopital": "hôpital", "police": "commissariat"}
## Mots-clés du catalogue (Metiers.keys_of) qui désignent chaque service.
const CLES := {
	"ecole": ["ecole", "college", "lycee", "maternelle", "universite"],
	"hopital": ["hopital", "clinique", "sante", "medecin"],
	"police": ["police", "commissariat", "gendarmerie"],
}
## Seuil de trajet (minutes) : jusque-là, bien couvert ; au double, plus rien.
const SEUIL := {"ecole": 15.0, "hopital": 30.0, "police": 10.0}
const SEUIL_NIVEAU := {"maternelle": 15.0, "élémentaire": 15.0, "collège": 25.0, "lycée": 40.0}
## Vitesses (m/min) : marche, voiture, véhicule de police en intervention.
const MARCHE := 80.0
const VOITURE := 500.0
const PATROUILLE := 650.0
## Attente du car scolaire ou du départ en voiture (min).
const ATTENTE_CAR := 5.0
## Besoins : lits par habitant (3 ‰), habitants par agent de police.
const LITS_PAR_HAB := 0.003
const HAB_PAR_AGENT := 400.0
## Lits par emploi prévu quand le catalogue n'en donne pas.
const LITS_PAR_EMPLOI := 0.75
## Petits délits par heure réelle et par habitant sans police.
const DELITS_PAR_HAB := 0.02
## Calques communs (panneau Cartes).
const COULEURS := [Color(0.25, 0.85, 0.4, 0.8), Color(1.0, 0.85, 0.25, 0.8), Color(1.0, 0.55, 0.15, 0.8), Color(0.9, 0.2, 0.2, 0.8)]

var population: Population
var buildings: BuildingSystem
var transport: TransportSystem
var urgences: Urgences
var rng := RandomNumberGenerator.new()
## Petits délits dans les quartiers mal couverts (désactivable pour les tests).
var delits_actifs := true
## Besoins (réglables) : lits par habitant, habitants par agent.
var lits_par_hab := LITS_PAR_HAB
var hab_par_agent := HAB_PAR_AGENT
## Bilan des délits : {total, sans_police, mois: {jour0, n}}.
var delits := {"total": 0, "sans_police": 0, "mois": 0, "mois_debut": -1}

## Couverture par service : type -> bid du logement -> {q, min, via, charge, why}.
var cov := {"ecole": {}, "hopital": {}, "police": {}}
## Chiffres par service : type -> {lieux: [{bid, nom, cap, use, charge, ferme}], hab, couverts, loin, rien, sature}.
var resume := {}

var _dirty := true
var _t_rebuild := 0.0
var _t_delit := 30.0
## Distances (m) par les routes depuis chaque lieu : "mode:bid" -> {noeud: m}.
var _dij := {}
## Point d'accroche au réseau : "mode:bid" -> {edge, s, d} (ou {} : aucun).
var _accroche := {}
var _pos_cache := {}
var _layer: MeshInstance3D
var _layer_type := ""


func _init() -> void:
	rng.randomize()
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func setup(p: Population, b: BuildingSystem, t: TransportSystem, u: Urgences = null) -> void:
	population = p
	buildings = b
	transport = t
	urgences = u
	if population != null:
		population.school_ok = ecole_possible
		population.changed.connect(marquer)
		# Satisfaction : par Avis s'il existe, sinon en chaîne avec les commerces.
		var avant: Callable = population.extra_satisfaction
		population.extra_satisfaction = func(pp: Dictionary) -> Array:
			var d := 0.0
			var why := []
			if avant.is_valid():
				var ex: Array = avant.call(pp)
				if ex.size() >= 2:
					d += float(ex[0])
					why.append_array(ex[1])
			if not _avis_present():
				for f in avis_facteurs():
					var r: Array = (f.f as Callable).call(pp)
					if r.size() >= 2 and float(r[0]) != 0.0:
						d += float(r[0])
						why.append_array(r[1])
			return [d, why]
	if buildings != null:
		buildings.changed.connect(marquer)
	if transport != null:
		transport.network_changed.connect(func() -> void:
			_dij.clear()
			_accroche.clear()
			marquer())
	add_to_group("avis_sources")
	_inscrire_calques()


func _ready() -> void:
	_layer = MeshInstance3D.new()
	_layer.name = "CalqueServices"
	_layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	_layer.material_override = m
	_layer.visible = false
	add_child(_layer)


func clear() -> void:
	cov = {"ecole": {}, "hopital": {}, "police": {}}
	resume.clear()
	_dij.clear()
	_accroche.clear()
	_pos_cache.clear()
	delits = {"total": 0, "sans_police": 0, "mois": 0, "mois_debut": -1}
	_dirty = true


func marquer() -> void:
	_dirty = true


func _avis_present() -> bool:
	return is_inside_tree() and get_tree().root.get_node_or_null("Avis") != null


# --- Lieux et capacités -----------------------------------------------------------

## Le bâtiment rend-il ce service ?
static func rend(type_id: String, service: String) -> bool:
	for k in Metiers.keys_of(type_id):
		if (CLES[service] as Array).has(k):
			return true
	return false


func lieux(service: String) -> Array:
	var out := []
	if population == null:
		return out
	for bid in population.known:
		if rend(String(population.known[bid].t), service):
			out.append(bid)
	return out


func _ferme(bid: int) -> bool:
	return population.effectif != null and population.effectif.ferme(bid)


func _taux(bid: int) -> float:
	return population.effectif.taux(bid) if population.effectif != null else 1.0


## Capacité d'un lieu : pupitres, lits ou agents (selon le personnel embauché).
func capacite(bid: int, service: String) -> int:
	var info: Dictionary = population.known.get(bid, {})
	if info.is_empty():
		return 0
	match service:
		"ecole":
			return int(info.seats)
		"hopital":
			var t := BuildingCatalog.get_type(String(info.t))
			var lits := int(info.get("lits", t.get("lits", roundi(float(info.emp) * LITS_PAR_EMPLOI))))
			if lits <= 0:
				lits = 10
			return 0 if _ferme(bid) else maxi(1, roundi(lits * minf(1.0, _taux(bid))))
		"police":
			if _ferme(bid):
				return 0
			return maxi(1, (population.by_job.get(bid, []) as Array).size()) if population.persons.size() > 0 else int(info.emp)
	return 0


## Habitants qu'un lieu peut couvrir.
func capacite_hab(bid: int, service: String) -> float:
	var c := float(capacite(bid, service))
	match service:
		"hopital": return c / lits_par_hab
		"police": return c * hab_par_agent
	return c


# --- Temps de trajet ----------------------------------------------------------------

func _modes_de(mode: String) -> Array:
	return [TransportTypes.Mode.ROAD, TransportTypes.Mode.PATH] if mode == "pied" else [TransportTypes.Mode.ROAD]


func _pos(bid: int) -> Vector3:
	return population.building_pos(bid)


## Point du réseau le plus proche d'un bâtiment (mis en cache).
func _accroche_de(bid: int, mode: String) -> Dictionary:
	var key := "%s:%d" % [mode, bid]
	if _accroche.has(key):
		return _accroche[key]
	var r := _accroche_pos(_pos(bid), mode)
	_accroche[key] = r
	return r


func _accroche_pos(p: Vector3, mode: String) -> Dictionary:
	if transport == null or transport.network.edges.is_empty():
		return {}
	var ok := _modes_de(mode)
	var best := {}
	for rad in [60.0, 250.0]:
		for eid in transport.edges_near(p, rad):
			var e: Dictionary = transport.network.edges[eid]
			if not ok.has(TransportTypes.mode_of(e.t)):
				continue
			if mode == "pied" and String(e.t) in ["autoroute", "bretelle"]:
				continue
			var hit := transport.network.nearest_on_edge(eid, p)
			if best.is_empty() or float(hit.dist) < float(best.d):
				best = {"edge": eid, "s": float(hit.s), "d": float(hit.dist)}
		if not best.is_empty():
			return best
	return best


## Distances (m) par le réseau depuis le lieu bid jusqu'à chaque nœud.
func _dijkstra(bid: int, mode: String) -> Dictionary:
	var key := "%s:%d" % [mode, bid]
	if _dij.has(key):
		return _dij[key]
	var out := {}
	var a := _accroche_de(bid, mode)
	if a.is_empty():
		_dij[key] = out
		return out
	var net := transport.network
	var ok := _modes_de(mode)
	var e0: Dictionary = net.edges[int(a.edge)]
	var heap: Array = []
	for pair in [[int(e0.a), float(a.s)], [int(e0.b), float(e0.len) - float(a.s)]]:
		if float(pair[1]) < float(out.get(pair[0], INF)):
			out[pair[0]] = float(pair[1])
			_heap_push(heap, [float(pair[1]), int(pair[0])])
	while not heap.is_empty():
		var cur: Array = _heap_pop(heap)
		var n := int(cur[1])
		if float(cur[0]) > float(out.get(n, INF)):
			continue
		for eid in net.adjacency.get(n, []):
			var e: Dictionary = net.edges[eid]
			if not ok.has(TransportTypes.mode_of(e.t)):
				continue
			if mode == "pied" and String(e.t) in ["autoroute", "bretelle"]:
				continue
			var o := net.other_end(eid, n)
			var d := float(cur[0]) + float(e.len)
			if d < float(out.get(o, INF)):
				out[o] = d
				_heap_push(heap, [d, o])
	_dij[key] = out
	return out


static func _heap_push(h: Array, item: Array) -> void:
	h.append(item)
	var i := h.size() - 1
	while i > 0:
		var p := (i - 1) / 2
		if float(h[p][0]) <= float(h[i][0]):
			break
		var tmp: Array = h[p]
		h[p] = h[i]
		h[i] = tmp
		i = p


static func _heap_pop(h: Array) -> Array:
	var top: Array = h[0]
	var last: Array = h.pop_back()
	if h.is_empty():
		return top
	h[0] = last
	var i := 0
	while true:
		var l := i * 2 + 1
		var r := l + 1
		var m := i
		if l < h.size() and float(h[l][0]) < float(h[m][0]):
			m = l
		if r < h.size() and float(h[r][0]) < float(h[m][0]):
			m = r
		if m == i:
			break
		var tmp: Array = h[m]
		h[m] = h[i]
		h[i] = tmp
		i = m
	return top


## Distance (m) par le réseau entre un point accroché et le lieu, INF si non relié.
## Sans réseau (ou loin de toute voie), à vol d'oiseau × 1,3.
func _distance(depuis: Dictionary, p_depuis: Vector3, lieu: int, mode: String) -> float:
	var al := _accroche_de(lieu, mode)
	if depuis.is_empty() or al.is_empty():
		var a := p_depuis
		var b := _pos(lieu)
		return Vector2(a.x - b.x, a.z - b.z).length() * 1.3
	var net := transport.network
	var bout := float(depuis.d) + float(al.d)
	if int(depuis.edge) == int(al.edge):
		return absf(float(depuis.s) - float(al.s)) + bout
	var dist := _dijkstra(lieu, mode)
	var e: Dictionary = net.edges[int(depuis.edge)]
	var best := minf(float(dist.get(int(e.a), INF)) + float(depuis.s),
		float(dist.get(int(e.b), INF)) + float(e.len) - float(depuis.s))
	return best + bout


## Temps de trajet (min) d'un logement vers un lieu pour un service.
func minutes(home: int, lieu: int, service: String) -> float:
	return _minutes_depuis(home, Vector3.INF, lieu, service)


func _minutes_depuis(home: int, pos: Vector3, lieu: int, service: String) -> float:
	var p := _pos(home) if home >= 0 else pos
	var acc := func(mode: String) -> Dictionary:
		return _accroche_de(home, mode) if home >= 0 else _accroche_pos(pos, mode)
	match service:
		"ecole":
			var pied := _distance(acc.call("pied"), p, lieu, "pied") / MARCHE
			var car := _distance(acc.call("auto"), p, lieu, "auto") / VOITURE + ATTENTE_CAR
			return minf(pied, car)
		"hopital":
			return _distance(acc.call("auto"), p, lieu, "auto") / VOITURE + 3.0
		"police":
			return _distance(acc.call("auto"), p, lieu, "auto") / PATROUILLE + 2.0
	return INF


static func qualite_temps(t: float, seuil: float) -> float:
	if t <= seuil:
		return 1.0
	if t >= seuil * 2.0:
		return 0.0
	return 1.0 - (t - seuil) / seuil


## Population : l'élève peut-il aller dans cette école ? (trajet ≤ 2 × seuil de son niveau)
func ecole_possible(p: Dictionary, school: int) -> bool:
	var home := population.home_of(p)
	if not population.known.has(home):
		return true
	var lvl := Metiers.school_level(population.age_years(p))
	return minutes(home, school, "ecole") <= float(SEUIL_NIVEAU.get(lvl, 15.0)) * 2.0


# --- Calcul de la couverture --------------------------------------------------------

func _process(delta: float) -> void:
	_t_rebuild -= delta
	if _dirty and _t_rebuild <= 0.0:
		rebuild()
	if delits_actifs:
		_t_delit -= delta
		if _t_delit <= 0.0:
			_tirer_delit()


func _habitants(bid: int) -> int:
	var n := 0
	for hid in population.by_home.get(bid, []):
		n += (population.households[hid].m as Array).size()
	return n


func _logements() -> Array:
	var out := []
	for bid in population.known:
		if int(population.known[bid].log) > 0:
			out.append(bid)
	return out


## Recalcule toute la couverture (appelé quand la ville change, au plus toutes les 2 s).
func rebuild() -> void:
	_dirty = false
	_t_rebuild = 2.0
	_pos_cache.clear()
	if population == null:
		return
	var homes := _logements()
	for s in TYPES:
		_rebuild_service(s, homes)
	if _layer_type != "":
		_build_layer()
	changed.emit()


func _rebuild_service(s: String, homes: Array) -> void:
	var out := {}
	var places := lieux(s)
	var ouverts := []
	for bid in places:
		if s == "ecole" or not _ferme(bid):
			ouverts.append(bid)
	# 1) Chaque logement va au lieu le plus rapide.
	var servis := {}
	for h in homes:
		var best := -1
		var bt := INF
		for l in ouverts:
			var t := minutes(h, l, s)
			if t < bt:
				bt = t
				best = l
		out[h] = {"via": best, "min": bt, "q": 0.0, "charge": 0.0, "why": ""}
		if best >= 0 and bt < float(SEUIL[s]) * 2.0:
			servis[best] = float(servis.get(best, 0.0)) + float(_habitants(h))
	# 2) Charge de chaque lieu.
	var liste := []
	var charge := {}
	for l in places:
		var cap := capacite_hab(l, s)
		var use := float(servis.get(l, 0.0))
		if s == "ecole":
			use = float((population.by_school.get(l, []) as Array).size())
		var c := use / cap if cap > 0.0 else (INF if use > 0.0 else 0.0)
		charge[l] = c
		liste.append({"bid": l, "nom": population.building_name(l), "cap": capacite(l, s), "cap_hab": cap,
			"use": use, "charge": c, "ferme": _ferme(l)})
	# 3) Qualité de chaque logement : trajet × place disponible.
	var tot := {"hab": 0, "couverts": 0, "loin": 0, "rien": 0, "sature": 0}
	for h in homes:
		var c: Dictionary = out[h]
		var n := _habitants(h)
		tot.hab += n
		if int(c.via) < 0:
			c.why = "aucun%s en ville" % (" " + String(NOM_UN[s]) if s != "ecole" else "e école")
			tot.rien += n
			continue
		var q := qualite_temps(float(c.min), float(SEUIL[s]))
		var ch := float(charge.get(int(c.via), 0.0))
		c.charge = ch
		if s == "ecole":
			q = _qualite_ecole(h, q)
		elif ch > 1.0:
			q /= ch
		c.q = clampf(q, 0.0, 1.0)
		if float(c.q) <= 0.0:
			c.why = "%s à %d min (trop loin)" % [String(NOM_UN[s]), roundi(float(c.min))] if float(c.min) < INF else "%s non relié par la route" % String(NOM_UN[s])
			tot.rien += n
		elif float(c.min) > float(SEUIL[s]):
			c.why = "%s à %d min" % [String(NOM_UN[s]), roundi(float(c.min))]
			tot.loin += n
		elif ch > 1.0 or (s == "ecole" and float(c.q) < 1.0):
			c.why = "%s saturé%s (%d %%)" % [String(NOM_UN[s]), "e" if s == "ecole" else "", roundi(ch * 100.0)]
			tot.sature += n
		else:
			c.why = "%s à %d min" % [String(NOM_UN[s]), roundi(float(c.min))]
			tot.couverts += n
	cov[s] = out
	tot.lieux = liste
	resume[s] = tot


## École : les élèves du logement ont-ils tous une place ? Sinon la couverture baisse.
func _qualite_ecole(home: int, q_temps: float) -> float:
	var eleves := 0
	var inscrits := 0
	var tps := []
	for hid in population.by_home.get(home, []):
		for pid in population.households[hid].m:
			var p: Dictionary = population.persons[pid]
			if population.stage(p) != "eleve":
				continue
			eleves += 1
			if int(p.sch) >= 0:
				inscrits += 1
				var lvl := Metiers.school_level(population.age_years(p))
				tps.append(qualite_temps(minutes(home, int(p.sch), "ecole"), float(SEUIL_NIVEAU.get(lvl, 15.0))))
	if eleves == 0:
		return q_temps
	var q := 0.0
	for x in tps:
		q += float(x)
	return q / float(eleves)


# --- Lecture pour les autres systèmes -----------------------------------------------

## Couverture 0..1 d'un logement (type "" : moyenne des trois services).
func couverture_bid(bid: int, service := "") -> float:
	if _dirty and population != null:
		rebuild()
	if service == "":
		var s := 0.0
		for t in TYPES:
			s += couverture_bid(bid, t)
		return s / TYPES.size()
	var c: Dictionary = (cov.get(service, {}) as Dictionary).get(bid, {})
	if c.is_empty():
		return _couverture_pos(_pos(bid) if population != null and population.known.has(bid) else Vector3.ZERO, service)
	return float(c.q)


func detail(bid: int, service: String) -> Dictionary:
	if _dirty and population != null:
		rebuild()
	return (cov.get(service, {}) as Dictionary).get(bid, {})


## Couverture 0..1 en un point quelconque (pour la valeur foncière). 0 sans système.
static func couverture(pos: Vector3, service := "") -> float:
	if instance == null or instance.population == null:
		return 0.0
	if service == "":
		var s := 0.0
		for t in TYPES:
			s += instance._couverture_pos(pos, t)
		return s / TYPES.size()
	return instance._couverture_pos(pos, service)


func _couverture_pos(pos: Vector3, service: String) -> float:
	var key := "%s:%d:%d" % [service, roundi(pos.x / 20.0), roundi(pos.z / 20.0)]
	if _pos_cache.has(key):
		return _pos_cache[key]
	var best := 0.0
	for l in lieux(service):
		if service != "ecole" and _ferme(l):
			continue
		var q := qualite_temps(_minutes_depuis(-1, pos, l, service), float(SEUIL[service]))
		var cap := capacite_hab(l, service)
		var res: Dictionary = resume.get(service, {})
		for e in res.get("lieux", []):
			if int(e.bid) == l and float(e.charge) > 1.0 and service != "ecole":
				q /= float(e.charge)
		if service == "ecole" and population.free_seats(l) <= 0:
			q *= 0.5
		if cap <= 0.0:
			q = 0.0
		best = maxf(best, q)
	_pos_cache[key] = best
	return best


func bilan(service: String) -> Dictionary:
	if _dirty and population != null:
		rebuild()
	return resume.get(service, {"hab": 0, "couverts": 0, "loin": 0, "rien": 0, "sature": 0, "lieux": []})


# --- Santé et satisfaction ----------------------------------------------------------

## Pour CycleVie.health : {f (multiplicateur du risque), why} ou {} si pas d'avis.
func sante(p: Dictionary) -> Dictionary:
	var home := population.home_of(p)
	var c := detail(home, "hopital")
	if c.is_empty():
		return {}
	var q := float(c.q)
	var f := lerpf(1.15, 0.82, q)
	var why := ""
	if q >= 0.99:
		why = "+ hôpital à %d min" % roundi(float(c.min))
	elif q > 0.0:
		why = "− %s" % String(c.why)
	else:
		why = "− pas d'hôpital à moins d'une heure" if int(c.via) < 0 or float(c.min) >= 60.0 else "− hôpital débordé"
	return {"f": f, "why": why}


## Facteurs de satisfaction (contrat Avis, groupe "avis_sources").
func avis_facteurs() -> Array:
	return [
		{"id": "services_ecole", "theme": "services", "f": _avis_ecole},
		{"id": "services_hopital", "theme": "services", "f": _avis_hopital},
		{"id": "services_police", "theme": "securite", "f": _avis_police},
	]


func _avis_ecole(p: Dictionary) -> Array:
	# « Pas de place à l'école » est déjà compté par Population.satisfaction.
	if population.stage(p) == "eleve" and int(p.sch) >= 0:
		var home := population.home_of(p)
		var lvl := Metiers.school_level(population.age_years(p))
		var t := minutes(home, int(p.sch), "ecole")
		if t > float(SEUIL_NIVEAU.get(lvl, 15.0)):
			return [-5.0, ["− école loin (%d min)" % roundi(t)]]
		return [0.0, []]
	# Parents : un enfant sans école.
	if population.stage(p) in ["actif", "chomeur"] and households_has_child_without_school(int(p.f)):
		return [-8.0, ["− un enfant du foyer n'a pas d'école proche"]]
	return [0.0, []]


func households_has_child_without_school(hid: int) -> bool:
	for pid in population.households.get(hid, {}).get("m", []):
		var c: Dictionary = population.persons.get(pid, {})
		if not c.is_empty() and population.stage(c) == "eleve" and int(c.sch) < 0:
			return true
	return false


func _avis_hopital(p: Dictionary) -> Array:
	var c := detail(population.home_of(p), "hopital")
	if c.is_empty():
		return [0.0, []]
	var q := float(c.q)
	if q <= 0.0:
		return [-8.0, ["− pas d'hôpital accessible"]]
	if float(c.charge) > 1.0:
		return [-5.0, ["− hôpital saturé (%d %%)" % roundi(float(c.charge) * 100.0)]]
	if q < 1.0:
		return [-3.0, ["− hôpital loin (%d min)" % roundi(float(c.min))]]
	return [3.0, ["+ hôpital à %d min" % roundi(float(c.min))]]


func _avis_police(p: Dictionary) -> Array:
	var c := detail(population.home_of(p), "police")
	if c.is_empty():
		return [0.0, []]
	var q := float(c.q)
	if q <= 0.0:
		return [-6.0, ["− quartier sans police"]]
	if float(c.charge) > 1.0:
		return [-3.0, ["− police débordée (%d %%)" % roundi(float(c.charge) * 100.0)]]
	if q < 1.0:
		return [-2.0, ["− police loin (%d min)" % roundi(float(c.min))]]
	return [3.0, ["+ quartier sûr"]]


# --- Petits délits ------------------------------------------------------------------

## Habitants mal protégés (somme des habitants × (1 − couverture police)).
func exposes() -> float:
	var s := 0.0
	for h in cov.police:
		s += float(_habitants(h)) * (1.0 - float(cov.police[h].q))
	return s


func _tirer_delit() -> void:
	var ex := exposes()
	var rate := DELITS_PAR_HAB * ex # par heure réelle
	_t_delit = rng.randf_range(0.5, 1.5) * 3600.0 / maxf(rate, 0.05)
	if ex < 1.0:
		return
	delit()


## Un petit délit dans un logement mal couvert (tiré au sort selon l'exposition).
## Renvoie le bid du logement ou -1.
func delit() -> int:
	var tot := exposes()
	if tot <= 0.0:
		return -1
	var x := rng.randf() * tot
	var bid := -1
	for h in cov.police:
		x -= float(_habitants(h)) * (1.0 - float(cov.police[h].q))
		bid = h
		if x <= 0.0:
			break
	if bid < 0:
		return -1
	_compter_delit()
	var police := false
	if urgences != null:
		for st in urgences.stations.values():
			if String(st.t) == "police":
				police = true
	if police and urgences.incidents.size() < Urgences.MAX_ACTIVE:
		urgences.random_call("cambriolage", _pos(bid))
	else:
		delits.sans_police = int(delits.sans_police) + 1
	return bid


func _compter_delit() -> void:
	delits.total = int(delits.total) + 1
	var jour := int(population.now().day) if population != null else 0
	if int(delits.mois_debut) < 0 or jour - int(delits.mois_debut) >= 30:
		delits.mois_debut = jour
		delits.mois = 0
	delits.mois = int(delits.mois) + 1


# --- Calques de carte ---------------------------------------------------------------

func _inscrire_calques() -> void:
	var leg := "vert : bien couvert · jaune : loin · orange : saturé · rouge : rien"
	for s in TYPES:
		var svc: String = s
		Calques.ajouter("services_" + svc, String(NOMS[svc]), "Services", func(on: bool) -> void: montrer(svc if on else ""), leg)


## Montre la couverture d'un service sur les bâtiments ("" : rien).
func montrer(service: String) -> void:
	_layer_type = service
	if service == "":
		if _layer != null:
			_layer.visible = false
		return
	if _dirty:
		rebuild()
	_build_layer()


func calque() -> String:
	return _layer_type


static func couleur(c: Dictionary, seuil: float) -> Color:
	if c.is_empty() or float(c.q) <= 0.0:
		return COULEURS[3]
	if float(c.charge) > 1.0 or float(c.q) < 0.5:
		return COULEURS[2]
	if float(c.min) > seuil or float(c.q) < 1.0:
		return COULEURS[1]
	return COULEURS[0]


func _build_layer() -> void:
	if _layer == null or population == null or buildings == null:
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any := false
	var s := _layer_type
	for bid in population.known:
		var info: Dictionary = population.known[bid]
		var col: Color
		if rend(String(info.t), s):
			col = Color(0.3, 0.6, 1.0, 0.85)
		elif int(info.log) > 0:
			col = couleur((cov[s] as Dictionary).get(bid, {}), float(SEUIL[s]))
		else:
			continue
		var r: Rect2i = info.rect
		var y := float(info.pos.y) + 0.6
		var h := BuildingCatalog.approx_height(String(info.t)) if BuildingCatalog.get_type(String(info.t)).size() > 0 else 6.0
		y += maxf(h, 3.0) + 0.5
		var a := Vector3(r.position.x, y, r.position.y)
		var b := Vector3(r.end.x, y, r.position.y)
		var c := Vector3(r.end.x, y, r.end.y)
		var d := Vector3(r.position.x, y, r.end.y)
		st.set_color(col)
		for q in [a, b, c, a, c, d]:
			st.add_vertex(q)
		any = true
	_layer.mesh = st.commit() if any else null
	_layer.visible = any


# --- Sauvegarde -----------------------------------------------------------------

func to_dict() -> Dictionary:
	return {"v": 1, "delits": delits.duplicate()}


func from_dict(d: Dictionary) -> void:
	clear()
	var dl: Dictionary = d.get("delits", {})
	for k in delits:
		if dl.has(k):
			delits[k] = int(dl[k])
