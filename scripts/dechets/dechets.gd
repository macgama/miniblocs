class_name Dechets
extends Node3D
## Déchets de la ville : production, tri, collecte en camion-benne sur les
## routes, décharge, incinération, centre de tri, recyclage, déchèterie, compost.
##
## - Chaque bâtiment habité ou occupé remplit ses bacs (ordures ménagères,
##   recyclables, verre) selon ses habitants et ses employés (KG_HAB,
##   KG_EMPLOI). On ne trie que si la ville a un centre de tri (TRI_BASE), et
##   mieux près d'une déchèterie (TRI_DECHETERIE).
## - Un bac plein déborde : des sacs s'entassent devant la porte (visibles),
##   les habitants sont mécontents et la rue est sale (sources de nuisances).
## - Les camions-bennes partent des dépôts de collecte, le matin, avec leur
##   équipage d'éboueurs de service (EQUIPAGE). Une tournée vide les bacs les
##   plus pleins autour du dépôt, porte à porte, jusqu'à remplir la benne
##   (BENNE_T), décharge à l'usine qui traite ce flux, puis rentre. Le camion
##   roule vraiment sur les routes (Traffic.add_delivery_vehicle).
## - Traitement : décharge (se remplit, pleine elle refuse ; on la recouvre en
##   colline verte), incinérateur (brûle, produit de l'électricité), centre de
##   tri (balles de tri et verre qui entrent dans l'économie : l'usine de
##   recyclage et les usines les achètent), déchèterie et compost.
## - Liens avec les autres systèmes, par groupes de nœuds (aucune dépendance) :
##   "pollution_sources", "electricite_sources", "avis_sources",
##   "budget_entretien", "budget_recettes".

signal changed
signal message(text: String)

const FLUX := ["om", "rec", "verre"]
const FLUX_NAMES := {"om": "Ordures ménagères", "rec": "Recyclables", "verre": "Verre"}
const FLUX_COLORS := {"om": Color("6c757d"), "rec": Color("ffd166"), "verre": Color("52b788")}
## Déchets d'un habitant par jour (kg) avant le tri : 1,4 kg en tout, comme en France.
const KG_HAB := {"om": 0.80, "rec": 0.45, "verre": 0.15}
## Déchets d'un emploi par jour (kg) ; commerces, cafés et loisirs : ×2,5.
const KG_EMPLOI := {"om": 0.30, "rec": 0.17, "verre": 0.03}
const COMMERCE_X := 2.5
## Les bacs tiennent BAC_JOURS jours de déchets (au moins BAC_MIN kg, comme un bac de 240 l).
const BAC_JOURS := 5.0
const BAC_MIN := 15.0
## Un bac vaut le détour quand il est rempli à SEUIL (ou contient SEUIL_KG kg).
const SEUIL := 0.3
const SEUIL_KG := 60.0
## Part des recyclables et du verre mise dans le bon bac.
const TRI_BASE := 0.55
const TRI_DECHETERIE := 0.15
## Encombrants et déchets verts apportés à la déchèterie (kg par habitant et par jour).
const DECHETERIE_KG := {"verts": 0.12, "encombrants": 0.13}
## Benne à ordures : charge (t), arrêt devant un bâtiment (s), vidage à l'usine (s).
const BENNE_T := 8.0
const ARRET_S := 40.0
const VIDAGE_S := 900.0
const MAX_ARRETS := 45
const EQUIPAGE := 3
## Distance maximale (m, à vol d'oiseau) entre un dépôt et un bâtiment desservi.
const RAYON := 8000.0
## Stock maximal (jours de capacité) devant un incinérateur ou un centre de tri.
const STOCK_JOURS := 3.0
## Pas de simulation (s) : comme la logistique de l'économie.
const STEP := 900.0
## Numéro des camions dans Traffic (les livraisons de Production sont en dessous).
const TAG := 1_000_000
## Coûts et recettes pour la ville (euros par mois).
const COUT_BENNE := 2500.0
const ENTRETIEN := 0.001
const TEOM := 12.0
const PRIX_COMPOST := 15.0
const COUT_RECOUVRIR := 1_500_000
const MAX_VISIBLE := 60

var buildings: BuildingSystem
var population: Population
var transport: TransportSystem
var production: Production
var ambiance: DayNight
## Tests : l'équipage ne manque jamais, les tournées partent à toute heure.
var ignore_crew := false
var ignore_hours := false

## Bacs : bid -> {om, rec, verre (kg), deb (kg de sacs débordés), last (heure du dernier passage), res (tournée)}.
var bacs: Dictionary = {}
## Installations : bid -> {role, st: {flux: t}, total (t enfouies), plein, units: [{mid}], mw, status}.
var sites: Dictionary = {}
## Tournées en cours : mid -> dictionnaire (voir _start_tour).
var missions: Dictionary = {}
var next_mission := 1
var today := {}
var yesterday := {}
var totaux := {}
var clock := -1.0
var last_unix := -1.0
var last_day := -1
var _n := 0
var _money_frac := 0.0
var _acc: Dictionary = {}
var _tri_cache: Dictionary = {}
var _dirty := true
var _bags: MultiMeshInstance3D
var _bags_dirty := true
var _warned: Dictionary = {}


func _init() -> void:
	today = _empty_stats()
	yesterday = _empty_stats()
	totaux = _empty_stats()
	add_to_group("pollution_sources")
	add_to_group("electricite_sources")
	add_to_group("avis_sources")
	add_to_group("budget_entretien")
	add_to_group("budget_recettes")


static func _empty_stats() -> Dictionary:
	return {"produit": {"om": 0.0, "rec": 0.0, "verre": 0.0}, "collecte": {"om": 0.0, "rec": 0.0, "verre": 0.0},
		"enfoui": 0.0, "brule": 0.0, "trie": 0.0, "recycle": 0.0, "composte": 0.0, "mwh": 0.0, "tournees": 0, "debordes": 0}


func setup(b: BuildingSystem, p: Population, t: TransportSystem, prod: Production, a: DayNight) -> void:
	buildings = b
	population = p
	transport = t
	production = prod
	ambiance = a
	if buildings != null:
		buildings.changed.connect(func() -> void: _dirty = true)
	if transport != null:
		transport.network_changed.connect(func() -> void:
			_acc.clear()
			_dirty = true)


func _ready() -> void:
	_bags = MultiMeshInstance3D.new()
	_bags.name = "Sacs"
	_bags.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var bm := BoxMesh.new()
	bm.size = Vector3(0.7, 0.75, 0.6)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.6
	bm.material = mat
	mm.mesh = bm
	_bags.multimesh = mm
	add_child(_bags)


func clear() -> void:
	for mid in missions.keys():
		_drop_visual(int(mid))
	bacs.clear()
	sites.clear()
	missions.clear()
	next_mission = 1
	today = _empty_stats()
	yesterday = _empty_stats()
	totaux = _empty_stats()
	clock = -1.0
	last_unix = -1.0
	last_day = -1
	_acc.clear()
	_tri_cache.clear()
	_dirty = true
	_bags_dirty = true
	changed.emit()


static func actif() -> bool:
	return ReglagesPartie.actuel.dechets


# --- Bâtiments ------------------------------------------------------------------------------

func _sync() -> void:
	_dirty = false
	if buildings == null:
		return
	for bid in sites.keys():
		if not buildings.buildings.has(bid) or DechetsTypes.role_of(String(buildings.buildings[bid].t)) != String(sites[bid].role):
			_remove_site(int(bid))
	for bid in buildings.buildings:
		var t := String(buildings.buildings[bid].t)
		var role := DechetsTypes.role_of(t)
		# Un bâtiment en chantier ne sert pas encore.
		if role == "" or sites.has(bid) or buildings.en_chantier(bid):
			continue
		var s := {"role": role, "st": {"om": 0.0, "rec": 0.0, "verre": 0.0, "verts": 0.0, "encombrants": 0.0}, "total": 0.0,
			"plein": false, "units": [], "mw": 0.0, "status": "", "jour": 0.0}
		if role == "depot":
			for i in int(DechetsTypes.spec_of(t).get("bennes", 4)):
				(s.units as Array).append({"mid": 0})
		sites[bid] = s
	for bid in bacs.keys():
		if buildings == null or not buildings.buildings.has(bid):
			bacs.erase(bid)
	_tri_cache.clear()
	_bags_dirty = true


func _remove_site(bid: int) -> void:
	for mid in missions.keys():
		var m: Dictionary = missions[mid]
		if int(m.depot) == bid:
			_end_tour(int(mid))
		elif int(m.dest) == bid:
			m.dest = -1
	sites.erase(bid)


func sites_of(role: String) -> Array:
	var out: Array = []
	for bid in sites:
		if String(sites[bid].role) == role:
			out.append(int(bid))
	return out


func _type_of(bid: int) -> String:
	return String(buildings.buildings[bid].t) if buildings != null and buildings.buildings.has(bid) else ""


func _pos_of(bid: int) -> Vector3:
	if population != null and population.known.has(bid):
		return population.building_pos(bid)
	if buildings != null and buildings.buildings.has(bid):
		var b: Dictionary = buildings.buildings[bid]
		return BuildingSystem.rect_center(buildings._rect_of(b)) + Vector3(0, float(b.get("h", 0.0)), 0)
	return Vector3.ZERO


func building_name(bid: int) -> String:
	if population != null and population.known.has(bid):
		return population.building_name(bid)
	return String(BuildingCatalog.get_type(_type_of(bid)).get("name", "—"))


## Point de la route devant la porte : {e, s, a, b, len, pos} ou {}.
func access_of(bid: int) -> Dictionary:
	if _acc.has(bid):
		return _acc[bid]
	var out := {}
	if transport != null and buildings != null and buildings.buildings.has(bid):
		var b: Dictionary = buildings.buildings[bid]
		var door := BuildingSystem.door_point(String(b.t), buildings._rect_of(b), int(b.r), float(b.get("a", 0.0)))
		var best_d := INF
		for eid in transport.edges_near(door, 60.0):
			var e: Dictionary = transport.network.edges[eid]
			if TransportTypes.mode_of(e.t) != TransportTypes.Mode.ROAD or String(e.t) in ["autoroute", "bretelle"]:
				continue
			var hit: Dictionary = transport.network.nearest_on_edge(eid, door)
			if float(hit.dist) < best_d:
				best_d = float(hit.dist)
				out = {"e": int(eid), "s": float(hit.get("s", 0.0)), "a": int(e.a), "b": int(e.b), "len": float(e.len), "pos": hit.pos}
	_acc[bid] = out
	return out


## Trajet par la route (s) entre deux points d'accès ; INF sans chemin.
func _route_s(p: Dictionary, q: Dictionary) -> float:
	if p.is_empty() or q.is_empty():
		return INF
	if production != null:
		return float(production.route_pts(p, q).s)
	return (p.pos as Vector3).distance_to(q.pos) / 10.0


# --- Personnel ----------------------------------------------------------------------------

func _now(t: float) -> Dictionary:
	if production != null:
		return production.local_time(t)
	return {"h": fposmod(t, 86400.0) / 3600.0, "wd": 1, "month": 3, "mday": 10, "day": int(t / 86400.0)}


## Éboueurs de service en ce moment dans un dépôt.
func crew_on_duty(bid: int, t: float) -> int:
	if ignore_crew or population == null:
		return 999
	var n := _now(t)
	var c := 0
	for pid in population.by_job.get(bid, []):
		var p: Dictionary = population.persons.get(pid, {})
		if p.is_empty() or String(p.get("met", "")) != "eboueur":
			continue
		if not population._works_today(p, n) or population._on_leave(p, n):
			continue
		var h: Array = Metiers.job("eboueur").h
		if float(n.h) >= float(h[0]) and float(n.h) < float(h[1]) - 0.5:
			c += 1
	return c


func _staff(bid: int) -> float:
	if ignore_crew or population == null:
		return 1.0
	var jobs := maxi(int(BuildingCatalog.get_type(_type_of(bid)).get("emplois", 1)), 1)
	return clampf(float((population.by_job.get(bid, []) as Array).size()) / jobs, 0.0, 1.0)


func trucks_out(bid: int) -> int:
	var c := 0
	for u in sites[bid].units:
		if int(u.mid) > 0:
			c += 1
	return c


# --- Temps ------------------------------------------------------------------------------------

func _process(_delta: float) -> void:
	if ambiance == null:
		return
	var t := ambiance.unix_time
	if last_unix < 0.0:
		last_unix = t
		return
	var dt := clampf(t - last_unix, 0.0, 86400.0 * 3.0)
	last_unix = t
	if dt > 0.0:
		advance(dt)


## Fait avancer les déchets de dt secondes de jeu (pas de 15 min).
func advance(dt: float) -> void:
	if _dirty:
		_sync()
	var end_t := (ambiance.unix_time if ambiance != null else clock + dt)
	if clock < 0.0 or absf(end_t - dt - clock) > 86400.0 * 4.0:
		clock = end_t - dt
	if last_day < 0:
		last_day = int(_now(clock).day)
	var n := 0
	while clock + STEP <= end_t + 0.001 and n < 400:
		clock += STEP
		n += 1
		step(STEP)
	if clock < end_t - 86400.0:
		clock = end_t


## Un pas : déchets produits, tournées qui avancent, nouvelles tournées,
## traitement dans les usines (toutes les heures), bilan (chaque jour).
func step(dt: float) -> void:
	if _dirty:
		_sync()
	_n += 1
	var d := int(_now(clock).day)
	if d > last_day:
		last_day = d
		new_day()
	if actif():
		_produce(dt / 86400.0)
	_advance_tours(clock)
	if actif():
		_dispatch(clock)
	if _n % 4 == 0:
		_treat(1.0 / 24.0 * (dt * 4.0 / 3600.0))
		_update_bags()
	changed.emit()


# --- Production des déchets ---------------------------------------------------------------

## Habitants et employés d'un bâtiment : [habitants, emplois, facteur emplois].
func _occupants(bid: int) -> Array:
	var hab := 0
	var emp := 0
	var info: Dictionary = population.known.get(bid, {})
	for hid in population.by_home.get(bid, []):
		if population.households.has(hid):
			hab += (population.households[hid].m as Array).size()
	emp = (population.by_job.get(bid, []) as Array).size()
	var x := COMMERCE_X if String(info.get("cat", "")) in ["commerce", "loisirs"] else 1.0
	return [hab, emp, x]


## Part triée chez un bâtiment (0 sans centre de tri).
func tri_rate(bid: int) -> float:
	if _tri_cache.has(bid):
		var rc := float(_tri_cache[bid])
		if Quartiers.instance != null and rc > 0.0:
			return Quartiers.instance.bonus_tri(_pos_of(bid), rc)
		return rc
	var r := 0.0
	if not sites_of("tri").is_empty():
		r = TRI_BASE
		var p := _pos_of(bid)
		for dbid in sites_of("decheterie"):
			var rayon := float(DechetsTypes.spec_of(_type_of(dbid)).get("rayon", 4000.0))
			if _pos_of(dbid).distance_to(p) <= rayon:
				r += TRI_DECHETERIE
				break
	_tri_cache[bid] = r
	# Tri obligatoire dans le quartier (hors cache : l'arrêté peut changer).
	if Quartiers.instance != null and r > 0.0:
		return Quartiers.instance.bonus_tri(_pos_of(bid), r)
	return r


func capacity_of(bid: int, f: String) -> float:
	var o := _occupants(bid) if population != null else [0, 0, 1.0]
	var per := float(KG_HAB[f]) * float(o[0]) + float(KG_EMPLOI[f]) * float(o[1]) * float(o[2])
	return maxf(per * BAC_JOURS * ReglagesPartie.actuel.dechets_quantite, BAC_MIN if f == "om" else BAC_MIN * 0.5)


func _produce(frac: float) -> void:
	if population == null:
		return
	var q := ReglagesPartie.actuel.dechets_quantite
	for bid in population.known:
		if not (bid is int) or not buildings.buildings.has(bid) or sites.has(bid):
			continue
		var o := _occupants(bid)
		if int(o[0]) == 0 and int(o[1]) == 0:
			continue
		var raw := {}
		for f in FLUX:
			raw[f] = (float(KG_HAB[f]) * float(o[0]) + float(KG_EMPLOI[f]) * float(o[1]) * float(o[2])) * frac * q
		var tri := tri_rate(bid)
		var add := {"om": float(raw.om) + (float(raw.rec) + float(raw.verre)) * (1.0 - tri), "rec": float(raw.rec) * tri, "verre": float(raw.verre) * tri}
		if not bacs.has(bid):
			bacs[bid] = {"om": 0.0, "rec": 0.0, "verre": 0.0, "deb": 0.0, "last": clock, "res": 0}
		var bac: Dictionary = bacs[bid]
		for f in FLUX:
			var cap := capacity_of(bid, f)
			var v := float(bac[f]) + float(add[f])
			if v > cap:
				if float(bac.deb) <= 0.0:
					_bags_dirty = true
				bac.deb = float(bac.deb) + v - cap
				v = cap
			bac[f] = v
			today.produit[f] = float(today.produit[f]) + float(add[f]) / 1000.0


## Bâtiments dont les sacs débordent sur le trottoir.
func overflowing() -> Array:
	var out: Array = []
	for bid in bacs:
		if float(bacs[bid].deb) > 0.5:
			out.append(int(bid))
	return out


## Taux de remplissage d'un bac (0 à 1, plus si les sacs débordent).
func fill_of(bid: int) -> float:
	if not bacs.has(bid):
		return 0.0
	var best := 0.0
	for f in FLUX:
		best = maxf(best, float(bacs[bid][f]) / capacity_of(bid, f))
	return best + (1.0 if float(bacs[bid].deb) > 0.5 else 0.0)


# --- Tournées ---------------------------------------------------------------------------------

func _dispatch(t: float) -> void:
	for dep in sites_of("depot"):
		var s: Dictionary = sites[dep]
		s.status = ""
		if access_of(dep).is_empty():
			s.status = "Pas d'accès à une route"
			continue
		var crew := crew_on_duty(dep, t)
		if not ignore_hours and crew <= 0:
			var h := float(_now(t).h)
			s.status = "Tournées de 5 h à 12 h, du lundi au samedi" if (h < 5.0 or h >= 11.5) else "Aucun éboueur de service"
			continue
		var busy_crew := trucks_out(dep) * EQUIPAGE
		var started := 0
		for u in s.units:
			if int(u.mid) > 0:
				continue
			if crew - busy_crew < EQUIPAGE:
				if trucks_out(dep) == 0:
					s.status = "Pas assez d'éboueurs (%d de service, %d par benne)" % [crew, EQUIPAGE]
				break
			var mid := _plan_tour(dep, t)
			if mid <= 0:
				break
			u.mid = mid
			busy_crew += EQUIPAGE
			started += 1
		if trucks_out(dep) > 0:
			s.status = "%d benne%s en tournée" % [trucks_out(dep), "s" if trucks_out(dep) > 1 else ""]
		elif String(s.status) == "":
			s.status = "Rien à ramasser pour l'instant"


## Flux à ramasser autour d'un dépôt : celui qui a le plus de bacs pleins et
## une usine pour le recevoir.
func _pick_flux(dep: int) -> String:
	var here := _pos_of(dep)
	var score := {"om": 0.0, "rec": 0.0, "verre": 0.0}
	for bid in bacs:
		var bac: Dictionary = bacs[bid]
		if int(bac.res) > 0 or _pos_of(bid).distance_to(here) > RAYON:
			continue
		for f in FLUX:
			var cap := capacity_of(bid, f)
			if float(bac[f]) >= minf(SEUIL * cap, SEUIL_KG) or float(bac.deb) > 0.5:
				score[f] = float(score[f]) + float(bac[f]) + (float(bac.deb) if f == "om" else 0.0)
	var best := ""
	var best_v := 0.0
	for f in FLUX:
		if float(score[f]) > best_v and _dest_for(f, here) >= 0:
			best_v = float(score[f])
			best = f
	return best


## Usine qui reçoit un flux, la plus proche d'un point (-1 : aucune).
func _dest_for(f: String, near: Vector3) -> int:
	var roles: Array = ["incinerateur", "decharge"] if f == "om" else ["tri"]
	var best := -1
	var best_d := INF
	for bid in sites:
		var s: Dictionary = sites[bid]
		if not String(s.role) in roles or access_of(int(bid)).is_empty():
			continue
		if String(s.role) == "decharge" and bool(s.plein):
			continue
		if String(s.role) in ["incinerateur", "tri"]:
			var cap := float(DechetsTypes.spec_of(_type_of(int(bid))).get("t_jour", 100.0)) * STOCK_JOURS
			var st := float(s.st.om) if f == "om" else float(s.st.rec) + float(s.st.verre)
			if st >= cap:
				continue
		var d := _pos_of(int(bid)).distance_to(near)
		if d < best_d:
			best_d = d
			best = int(bid)
	if best < 0 and f != "om":
		return -1
	return best


## Prépare et lance une tournée depuis un dépôt. Renvoie son numéro (0 : rien à faire).
func _plan_tour(dep: int, t: float) -> int:
	var f := _pick_flux(dep)
	if f == "":
		return 0
	var here := _pos_of(dep)
	var cands: Array = []
	for bid in bacs:
		var bac: Dictionary = bacs[bid]
		if int(bac.res) > 0:
			continue
		var p := _pos_of(int(bid))
		if p.distance_to(here) > RAYON:
			continue
		var kg := float(bac[f]) + (float(bac.deb) if f == "om" else 0.0)
		if kg < minf(SEUIL * capacity_of(int(bid), f), SEUIL_KG) and float(bac.deb) <= 0.5:
			continue
		if access_of(int(bid)).is_empty():
			continue
		cands.append([int(bid), p, kg])
	if cands.is_empty():
		return 0
	# Plus proche voisin, en commençant par le dépôt.
	var stops: Array = []
	var load := 0.0
	var pos := here
	while not cands.is_empty() and stops.size() < MAX_ARRETS and load < BENNE_T * 1000.0:
		var bi := 0
		var bd := INF
		for i in cands.size():
			var dd := (cands[i][1] as Vector3).distance_squared_to(pos)
			if dd < bd:
				bd = dd
				bi = i
		var c: Array = cands[bi]
		cands.remove_at(bi)
		if load + float(c[2]) > BENNE_T * 1000.0 * 1.05 and not stops.is_empty():
			continue
		stops.append({"bid": int(c[0]), "t": 0.0, "done": false})
		load += float(c[2])
		pos = c[1]
	var dest := _dest_for(f, pos)
	if dest < 0 or stops.is_empty():
		return 0
	# Pas de sortie pour quelques sacs : il faut un quart de benne, un bac
	# presque plein ou des sacs sur le trottoir.
	if load < BENNE_T * 1000.0 * 0.25:
		var urgent := false
		for st in stops:
			urgent = urgent or fill_of(int(st.bid)) >= 0.8
		if not urgent:
			return 0
	# Horaire : trajets par la route, arrêts devant chaque porte.
	var p_dep := access_of(dep)
	var prev := p_dep
	var tt := t
	var kept: Array = []
	for st in stops:
		var q := access_of(int(st.bid))
		var s := _route_s(prev, q)
		if s == INF:
			continue
		tt += s + ARRET_S
		st.t = tt
		kept.append(st)
		prev = q
	if kept.is_empty():
		return 0
	var to_dest := _route_s(prev, access_of(dest))
	if to_dest == INF:
		return 0
	var t_dest := tt + to_dest + VIDAGE_S
	var back := _route_s(access_of(dest), p_dep)
	var mid := next_mission
	next_mission += 1
	var m := {"id": mid, "depot": dep, "flux": f, "stops": kept, "dest": dest, "t0": t, "t_dest": t_dest,
		"t_end": t_dest + (back if back < INF else to_dest), "kg": 0.0, "unloaded": false}
	missions[mid] = m
	for st in kept:
		bacs[int(st.bid)].res = mid
	today.tournees = int(today.tournees) + 1
	_spawn_visual(mid)
	return mid


func _advance_tours(t: float) -> void:
	for mid in missions.keys():
		var m: Dictionary = missions[mid]
		for st in m.stops:
			if not bool(st.done) and float(st.t) <= t:
				st.done = true
				_collect(m, int(st.bid))
		if not bool(m.unloaded) and float(m.t_dest) <= t:
			_unload(m)
		if float(m.t_end) <= t:
			_end_tour(int(mid))


## Les éboueurs vident les bacs d'un bâtiment dans la benne.
func _collect(m: Dictionary, bid: int) -> void:
	if not bacs.has(bid):
		return
	var bac: Dictionary = bacs[bid]
	if int(bac.res) == int(m.id):
		bac.res = 0
	var f := String(m.flux)
	var room := BENNE_T * 1000.0 * 1.05 - float(m.kg)
	var take := minf(float(bac[f]), room)
	bac[f] = float(bac[f]) - take
	room -= take
	if f == "om" and float(bac.deb) > 0.0:
		var sacs := minf(float(bac.deb), room)
		bac.deb = float(bac.deb) - sacs
		take += sacs
		if float(bac.deb) <= 0.5:
			bac.deb = 0.0
			_bags_dirty = true
	m.kg = float(m.kg) + take
	bac.last = clock
	today.collecte[f] = float(today.collecte[f]) + take / 1000.0


## La benne vide son chargement à l'usine (ou à la décharge).
func _unload(m: Dictionary) -> void:
	m.unloaded = true
	var t := float(m.kg) / 1000.0
	var dest := int(m.dest)
	var f := String(m.flux)
	if dest < 0 or not sites.has(dest):
		dest = _dest_for("om" if f == "om" else f, _pos_of(int(m.depot)))
	if dest < 0 or not sites.has(dest):
		_warn("sans_usine", "Une benne rentre pleine : aucune usine pour ses déchets.")
		return
	_receive(dest, f, t)


## Une usine reçoit des tonnes d'un flux.
func _receive(dest: int, f: String, t: float) -> void:
	var s: Dictionary = sites[dest]
	match String(s.role):
		"decharge":
			_bury(dest, t)
		_:
			s.st[f] = float(s.st.get(f, 0.0)) + t


func _bury(bid: int, t: float) -> void:
	var s: Dictionary = sites[bid]
	var cap := float(DechetsTypes.spec_of(_type_of(bid)).get("capacite", 100000.0))
	s.total = float(s.total) + t
	today.enfoui = float(today.enfoui) + t
	if float(s.total) >= cap and not bool(s.plein):
		s.plein = true
		message.emit("%s est pleine : il faut la recouvrir et en construire une autre (panneau Déchets, X)." % building_name(bid))


func _end_tour(mid: int) -> void:
	if not missions.has(mid):
		return
	var m: Dictionary = missions[mid]
	if not bool(m.unloaded) and float(m.kg) > 0.0:
		_unload(m)
	for st in m.stops:
		if bacs.has(int(st.bid)) and int(bacs[int(st.bid)].res) == mid:
			bacs[int(st.bid)].res = 0
	if sites.has(int(m.depot)):
		for u in sites[int(m.depot)].units:
			if int(u.mid) == mid:
				u.mid = 0
	_drop_visual(mid)
	missions.erase(mid)


# --- Camions à l'écran ---------------------------------------------------------------------------

func _traffic() -> Traffic:
	if transport == null or transport.traffic == null or not transport.traffic.enabled:
		return null
	return transport.traffic


static func _halt(p: Dictionary) -> Dictionary:
	return {"e": int(p.e), "s": float(p.s)}


func _spawn_visual(mid: int) -> void:
	var tr := _traffic()
	if tr == null or tr.delivery_count() >= MAX_VISIBLE:
		return
	var m: Dictionary = missions[mid]
	var p := access_of(int(m.depot))
	if p.is_empty():
		return
	var start := int(p.a) if float(p.s) <= float(p.len) * 0.5 else int(p.b)
	var halts: Array = []
	for st in m.stops:
		halts.append(_halt(access_of(int(st.bid))))
	if int(m.dest) >= 0:
		halts.append(_halt(access_of(int(m.dest))))
	halts.append(_halt(p))
	m.visual = tr.add_delivery_vehicle(TAG + mid, "benne_om", start, halts)


func _drop_visual(mid: int) -> void:
	var tr := _traffic()
	if tr == null:
		return
	for i in range(tr.vehicles.size() - 1, -1, -1):
		var v: Dictionary = tr.vehicles[i]
		if int(v.get("delivery", -1)) == TAG + mid:
			tr._free_vehicle(v)
			tr.vehicles.remove_at(i)


## Bennes visibles sur la route.
func trucks_on_road() -> int:
	var tr := _traffic()
	if tr == null:
		return 0
	var c := 0
	for v in tr.vehicles:
		if int(v.get("delivery", -1)) >= TAG:
			c += 1
	return c


func _update_bags() -> void:
	if _bags == null or not _bags_dirty:
		return
	_bags_dirty = false
	var xf: Array[Transform3D] = []
	var cols: Array[Color] = []
	for bid in overflowing():
		if not buildings.buildings.has(bid):
			continue
		var b: Dictionary = buildings.buildings[bid]
		var rect := buildings._rect_of(b)
		var door := BuildingSystem.door_point(String(b.t), rect, int(b.r), float(b.get("a", 0.0)))
		var center := BuildingSystem.rect_center(rect)
		var out := Vector3(door.x - center.x, 0, door.z - center.z).normalized()
		var side := out.cross(Vector3.UP)
		var n := clampi(2 + ceili(float(bacs[bid].deb) / 6.0), 3, 12)
		for i in n:
			var off := side * (1.6 + float(i % 5) * 0.6) + out * (0.6 + float(i / 5) * 0.55)
			var y := float(b.get("h", 0.0)) + 0.37 + (0.6 if i >= 10 else 0.0)
			var tr := Transform3D(Basis(Vector3.UP, float(i) * 0.7), Vector3(door.x, y, door.z) + off)
			xf.append(tr)
			cols.append(Color("22252a") if i % 3 != 2 else Color("3a5a40"))
	var mm := _bags.multimesh
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
		mm.set_instance_color(i, cols[i])


# --- Usines ------------------------------------------------------------------------------------

## Une tranche de traitement (frac : part de journée).
func _treat(frac: float) -> void:
	for bid in sites:
		var s: Dictionary = sites[bid]
		var spec := DechetsTypes.spec_of(_type_of(int(bid)))
		var staff := _staff(int(bid))
		match String(s.role):
			"incinerateur":
				var burn := minf(float(s.st.om), float(spec.get("t_jour", 300.0)) * staff * frac)
				s.st.om = float(s.st.om) - burn
				var mwh := burn * float(spec.get("mwh_t", 0.6))
				today.brule = float(today.brule) + burn
				today.mwh = float(today.mwh) + mwh
				s.mw = lerpf(float(s.mw), mwh / (frac * 24.0), 0.3)
				s.status = "Personne n'y travaille" if staff <= 0.0 else ("En attente d'ordures" if burn <= 0.0 else "Brûle %.0f t par jour, %.1f MW" % [burn / frac, s.mw])
			"decharge":
				var cap := float(spec.get("capacite", 100000.0))
				s.status = "Pleine : à recouvrir" if bool(s.plein) else "Remplie à %d %%" % roundi(float(s.total) / cap * 100.0)
			"tri":
				_sort(int(bid), s, spec, staff, frac)
			"compost":
				var c := minf(float(s.st.verts), float(spec.get("t_jour", 30.0)) * staff * frac)
				s.st.verts = float(s.st.verts) - c
				today.composte = float(today.composte) + c
				s.status = "Personne n'y travaille" if staff <= 0.0 else ("En attente de déchets verts" if c <= 0.0 else "Composte %.1f t par jour" % (c / frac))
			"recyclage":
				var ps := _prod_site(int(bid))
				s.status = String(ps.get("status", "")) if not ps.is_empty() else "En attente"
			"depot", "decheterie", "decharge_fermee":
				pass


func _prod_site(bid: int) -> Dictionary:
	if production == null or not production.sites.has(bid):
		return {}
	return production.sites[bid]


## Centre de tri : recyclables → balles de tri (85 %, le reste part en ordures), verre → verre.
func _sort(bid: int, s: Dictionary, spec: Dictionary, staff: float, frac: float) -> void:
	var cap := float(spec.get("t_jour", 60.0)) * staff * frac
	var ps := _prod_site(bid)
	if staff <= 0.0:
		s.status = "Personne n'y travaille : il faut des habitants"
		if not ps.is_empty():
			ps.ext_status = s.status
		return
	var room_b := INF
	var room_v := INF
	if production != null and not ps.is_empty():
		room_b = production.cap_of(bid, "balles_tri") - production.stock_of(bid, "balles_tri")
		room_v = production.cap_of(bid, "verre") - production.stock_of(bid, "verre")
	var rec := minf(minf(float(s.st.rec), cap), maxf(room_b, 0.0) / 0.85)
	var verre := minf(minf(float(s.st.verre), cap - rec), maxf(room_v, 0.0) / 0.97)
	s.st.rec = float(s.st.rec) - rec
	s.st.verre = float(s.st.verre) - verre
	var balles := rec * 0.85
	var calcin := verre * 0.97
	if production != null and not ps.is_empty():
		production._put(bid, "balles_tri", balles)
		production._put(bid, "verre", calcin)
		production._flow("balles_tri", balles, "prod")
		production._flow("verre", calcin, "prod")
	today.trie = float(today.trie) + rec + verre
	today.recycle = float(today.recycle) + balles + calcin
	# Refus de tri : vers l'incinérateur ou la décharge la plus proche.
	var refus := rec * 0.15 + verre * 0.03
	if refus > 0.0:
		var d := _dest_for("om", _pos_of(bid))
		if d >= 0:
			_receive(d, "om", refus)
	if rec + verre <= 0.0 and (float(s.st.rec) + float(s.st.verre)) > 0.01:
		s.status = "Stock plein : aucun camion ne vient chercher les balles"
	elif rec + verre <= 0.0:
		s.status = "En attente des bennes de recyclables"
	else:
		s.status = "Trie %.0f t par jour" % ((rec + verre) / frac)
	if not ps.is_empty():
		ps.ext_status = s.status


# --- Chaque jour ----------------------------------------------------------------------------------

func new_day() -> void:
	_tri_cache.clear()
	if actif():
		_decheteries()
	var deb := 0
	for bid in bacs:
		if float(bacs[bid].deb) > 0.5:
			deb += 1
	today.debordes = deb
	for k in today:
		if today[k] is Dictionary:
			for f in today[k]:
				totaux[k][f] = float(totaux[k][f]) + float(today[k][f])
		else:
			totaux[k] = float(totaux[k]) + float(today[k])
	yesterday = today
	today = _empty_stats()
	_pay_day()
	if deb >= 5:
		_warn("deborde", "%d bâtiments ont des sacs d'ordures qui débordent sur le trottoir." % deb, 86400.0 * 2.0)


## Les habitants apportent encombrants et déchets verts à la déchèterie la plus
## proche ; ses bennes partent au compost et à la décharge.
func _decheteries() -> void:
	var dets := sites_of("decheterie")
	if dets.is_empty() or population == null:
		return
	var q := ReglagesPartie.actuel.dechets_quantite
	for bid in population.by_home:
		var p := _pos_of(int(bid))
		var best := -1
		var best_d := INF
		for d in dets:
			var dd := _pos_of(d).distance_to(p)
			if dd < best_d and dd <= float(DechetsTypes.spec_of(_type_of(d)).get("rayon", 4000.0)):
				best_d = dd
				best = d
		if best < 0:
			continue
		var hab := _occupants(int(bid))[0] as int
		for k in DECHETERIE_KG:
			sites[best].st[k] = float(sites[best].st[k]) + float(DECHETERIE_KG[k]) * hab * q / 1000.0
	for d in dets:
		var s: Dictionary = sites[d]
		var verts := float(s.st.verts)
		var enc := float(s.st.encombrants)
		s.st.verts = 0.0
		s.st.encombrants = 0.0
		var comp := -1
		var best_d := INF
		for c in sites_of("compost"):
			if _pos_of(c).distance_to(_pos_of(d)) < best_d:
				best_d = _pos_of(c).distance_to(_pos_of(d))
				comp = c
		if comp >= 0:
			sites[comp].st.verts = float(sites[comp].st.verts) + verts
		else:
			enc += verts
		var dest := _dest_for("om", _pos_of(d))
		if dest >= 0:
			_receive(dest, "om", enc)
		s.status = "Reçoit %.1f t par jour (encombrants et déchets verts)" % (verts + float(enc))


func _warn(key: String, text: String, every := 3600.0 * 6.0) -> void:
	if clock - float(_warned.get(key, -INF)) < every:
		return
	_warned[key] = clock
	message.emit(text)


# --- Argent (panneau Budget, sinon directement la caisse) ---------------------------------------

func budget_entretien() -> Dictionary:
	if not actif() and sites.is_empty():
		return {}
	var collecte := 0.0
	var traitement := 0.0
	for bid in sites:
		var c := float(BuildingCatalog.cost(_type_of(int(bid)))) * ENTRETIEN
		if String(sites[bid].role) == "depot":
			collecte += c + COUT_BENNE * (sites[bid].units as Array).size()
		else:
			traitement += c
	var out := {}
	if collecte > 0.0:
		out["Collecte des déchets"] = collecte
	if traitement > 0.0:
		out["Traitement des déchets"] = traitement
	return out


func budget_recettes() -> Dictionary:
	var out := {}
	if population == null or sites_of("depot").is_empty() or not actif():
		return out
	out["Taxe d'ordures ménagères"] = float(population.households.size()) * TEOM * ReglagesPartie.actuel.impots
	var comp := float(yesterday.composte) * 30.0 * PRIX_COMPOST
	if comp > 0.0:
		out["Vente du compost"] = comp
	return out


## Sans panneau Budget dans la partie, la caisse paie et touche directement (1/30e par jour).
func _pay_day() -> void:
	if buildings == null or buildings.unlimited_money or _budget_present():
		return
	var net := 0.0
	var e := budget_entretien()
	for k in e:
		net -= float(e[k])
	var r := budget_recettes()
	for k in r:
		net += float(r[k])
	_money_frac += net / 30.0
	var whole := int(_money_frac)
	if whole != 0:
		buildings.money += whole
		_money_frac -= whole


func _budget_present() -> bool:
	if not is_inside_tree():
		return false
	for n in get_tree().get_nodes_in_group("budget"):
		return true
	return get_tree().root.find_child("Budget", true, false) != null


# --- Liens avec les autres systèmes ------------------------------------------------------------------

## Nuisances (groupe "pollution_sources").
func pollution_sources() -> Array:
	var out: Array = []
	for bid in sites:
		var s: Dictionary = sites[bid]
		var p := _pos_of(int(bid))
		var nom := building_name(int(bid))
		match String(s.role):
			"decharge":
				out.append({"pos": p, "rayon": 600.0, "air": 0.3, "eau": 0.8, "odeur": 0.8, "bruit": 0.2, "nom": nom, "bid": int(bid)})
			"decharge_fermee":
				out.append({"pos": p, "rayon": 300.0, "eau": 0.15, "nom": nom, "bid": int(bid)})
			"incinerateur":
				out.append({"pos": p, "rayon": 800.0, "air": 0.6, "bruit": 0.3, "nom": nom, "bid": int(bid)})
			"depot":
				out.append({"pos": p, "rayon": 150.0, "bruit": 0.3, "nom": nom, "bid": int(bid)})
			"tri", "recyclage":
				out.append({"pos": p, "rayon": 200.0, "bruit": 0.4, "odeur": 0.2, "nom": nom, "bid": int(bid)})
			"compost":
				out.append({"pos": p, "rayon": 300.0, "odeur": 0.5, "nom": nom, "bid": int(bid)})
			"decheterie":
				out.append({"pos": p, "rayon": 100.0, "bruit": 0.2, "nom": nom, "bid": int(bid)})
	for bid in overflowing():
		var f := clampf(float(bacs[bid].deb) / 100.0, 0.2, 1.0)
		out.append({"pos": _pos_of(bid), "rayon": 60.0, "salete": f, "odeur": f * 0.5, "nom": "Sacs d'ordures non ramassés"})
	return out


## Réseau électrique (groupe "electricite_sources").
func electricite_sources() -> Array:
	var out: Array = []
	for bid in sites_of("incinerateur"):
		if float(sites[bid].mw) > 0.05:
			out.append({"bid": bid, "mw": float(sites[bid].mw), "nom": building_name(bid)})
	return out


## Avis des habitants (groupe "avis_sources").
func avis_facteurs() -> Array:
	return [{"id": "dechets", "theme": "environnement", "f": satisfaction_of}]


## Effet des déchets sur un habitant : [delta, raisons].
func satisfaction_of(p: Dictionary) -> Array:
	if population == null or not actif():
		return [0.0, []]
	var home := population.home_of(p)
	if home < 0 or not bacs.has(home):
		return [0.0, []]
	var bac: Dictionary = bacs[home]
	if float(bac.deb) > 0.5:
		var d := -4.0 - minf(8.0, float(bac.deb) / 25.0)
		return [d, ["− Les poubelles débordent devant chez moi"]]
	if clock - float(bac.last) < 86400.0 * 4.0 and tri_rate(home) > 0.0:
		return [1.0, ["+ Poubelles ramassées et tri sélectif"]]
	return [0.0, []]


# --- Décharge pleine ---------------------------------------------------------------------------------

## Recouvre une décharge : terre, herbe et arbustes, puits de biogaz. Elle ne
## reçoit plus rien et pollue beaucoup moins.
func recouvrir(bid: int) -> bool:
	if not sites.has(bid) or String(sites[bid].role) != "decharge" or buildings == null:
		return false
	var cost := ReglagesPartie.prix(COUT_RECOUVRIR)
	if not buildings.unlimited_money and buildings.money < cost:
		message.emit("Pas assez d'argent pour recouvrir la décharge (%s)." % BuildingSystem.format_money(cost))
		return false
	var total := float(sites[bid].total)
	var b: Dictionary = (buildings.buildings[bid] as Dictionary).duplicate(true)
	buildings.remove_quietly(bid)
	sites.erase(bid)
	b.t = "decharge_fermee"
	b.erase("v")
	buildings.restore(b)
	if not buildings.unlimited_money:
		buildings.money -= cost
	_sync()
	if sites.has(bid):
		sites[bid].total = total
	message.emit("Décharge recouverte : %s t enfouies sous une colline verte." % _fmt_t(total))
	changed.emit()
	return true


# --- Bilan ----------------------------------------------------------------------------------------------

static func _fmt_t(t: float) -> String:
	if t >= 100.0:
		return "%d" % roundi(t)
	return "%.1f" % t


func summary() -> String:
	if sites.is_empty() and bacs.is_empty():
		return ""
	var y: Dictionary = yesterday
	var prod := 0.0
	for f in FLUX:
		prod += float(y.produit[f])
	return "Déchets %s t/j, %d débordent" % [_fmt_t(prod), overflowing().size()]


## Chiffres du panneau : production, collecte, devenir et taux de recyclage.
func bilan() -> Dictionary:
	var y: Dictionary = yesterday
	var prod := 0.0
	var coll := 0.0
	for f in FLUX:
		prod += float(y.produit[f])
		coll += float(y.collecte[f])
	var traite := float(y.enfoui) + float(y.brule) + float(y.trie) + float(y.composte)
	var valorise := float(y.recycle) + float(y.composte)
	return {"produit": prod, "collecte": coll, "enfoui": float(y.enfoui), "brule": float(y.brule), "trie": float(y.trie),
		"recycle": float(y.recycle), "composte": float(y.composte), "mwh": float(y.mwh), "tournees": int(y.tournees),
		"debordent": overflowing().size(), "taux_recyclage": valorise / traite if traite > 0.0 else 0.0,
		"en_attente": waiting()}


## Déchets dans les bacs (t), par flux.
func waiting() -> Dictionary:
	var out := {"om": 0.0, "rec": 0.0, "verre": 0.0, "sacs": 0.0}
	for bid in bacs:
		for f in FLUX:
			out[f] = float(out[f]) + float(bacs[bid][f]) / 1000.0
		out.sacs = float(out.sacs) + float(bacs[bid].deb) / 1000.0
	return out


# --- Sauvegarde ----------------------------------------------------------------------------------------

static func _snap(d: Dictionary, step := 0.001) -> Dictionary:
	var out := {}
	for k in d:
		out[k] = snappedf(float(d[k]), step) if (d[k] is float or d[k] is int) else d[k]
	return out


func to_dict() -> Dictionary:
	var ba := {}
	for bid in bacs:
		var b: Dictionary = bacs[bid]
		ba[str(bid)] = {"om": snappedf(float(b.om), 0.01), "rec": snappedf(float(b.rec), 0.01), "verre": snappedf(float(b.verre), 0.01),
			"deb": snappedf(float(b.deb), 0.01), "last": float(b.last)}
	var si := {}
	for bid in sites:
		var s: Dictionary = sites[bid]
		si[str(bid)] = {"role": s.role, "st": _snap(s.st), "total": snappedf(float(s.total), 0.001), "plein": s.plein, "mw": snappedf(float(s.mw), 0.001)}
	var mi := []
	for m in missions.values():
		var stops := []
		for st in m.stops:
			stops.append({"bid": int(st.bid), "t": float(st.t), "done": bool(st.done)})
		mi.append({"id": m.id, "depot": m.depot, "flux": m.flux, "stops": stops, "dest": m.dest, "t0": m.t0, "t_dest": m.t_dest,
			"t_end": m.t_end, "kg": snappedf(float(m.kg), 0.01), "unloaded": m.unloaded})
	return {"version": 1, "bacs": ba, "sites": si, "missions": mi, "next_mission": next_mission, "veille": yesterday,
		"jour": today, "totaux": totaux, "clock": clock, "money_frac": _money_frac}


func from_dict(d: Dictionary) -> void:
	clear()
	_sync()
	for k in d.get("bacs", {}):
		var x: Dictionary = d.bacs[k]
		bacs[int(k)] = {"om": float(x.get("om", 0.0)), "rec": float(x.get("rec", 0.0)), "verre": float(x.get("verre", 0.0)),
			"deb": float(x.get("deb", 0.0)), "last": float(x.get("last", 0.0)), "res": 0}
	for k in d.get("sites", {}):
		var bid := int(k)
		if not sites.has(bid):
			continue
		var x: Dictionary = d.sites[k]
		var s: Dictionary = sites[bid]
		for f in x.get("st", {}):
			s.st[String(f)] = float(x.st[f])
		s.total = float(x.get("total", 0.0))
		s.plein = bool(x.get("plein", false))
		s.mw = float(x.get("mw", 0.0))
	var top := 0
	for x in d.get("missions", []):
		var dep := int(x.get("depot", -1))
		if not sites.has(dep):
			continue
		var m := {"id": int(x.id), "depot": dep, "flux": String(x.get("flux", "om")), "stops": [], "dest": int(x.get("dest", -1)),
			"t0": float(x.get("t0", 0.0)), "t_dest": float(x.get("t_dest", 0.0)), "t_end": float(x.get("t_end", 0.0)),
			"kg": float(x.get("kg", 0.0)), "unloaded": bool(x.get("unloaded", false))}
		for st in x.get("stops", []):
			(m.stops as Array).append({"bid": int(st.bid), "t": float(st.t), "done": bool(st.done)})
			if not bool(st.done) and bacs.has(int(st.bid)):
				bacs[int(st.bid)].res = int(m.id)
		var placed := false
		for u in sites[dep].units:
			if int(u.mid) == 0:
				u.mid = int(m.id)
				placed = true
				break
		if not placed:
			continue
		missions[int(m.id)] = m
		top = maxi(top, int(m.id))
	next_mission = maxi(int(d.get("next_mission", 1)), top + 1)
	for key in ["veille", "jour", "totaux"]:
		var src: Dictionary = d.get(key, {})
		var dst := _empty_stats()
		for k in dst:
			if src.has(k):
				if dst[k] is Dictionary:
					for f in dst[k]:
						dst[k][f] = float((src[k] as Dictionary).get(f, 0.0))
				else:
					dst[k] = src[k]
		match key:
			"veille": yesterday = dst
			"jour": today = dst
			"totaux": totaux = dst
	clock = float(d.get("clock", -1.0))
	_money_frac = float(d.get("money_frac", 0.0))
	_bags_dirty = true
	_update_bags()
	changed.emit()
