class_name Funeraire
extends Node3D
## Obsèques, cimetières, crématorium et pompes funèbres.
##
## - À chaque décès (Population.person_died), on organise les obsèques :
##   inhumation ou crémation selon la région d'origine du défunt (ou le
##   réglage Admin), une place dans un cimetière (le caveau familial s'il y a
##   de la place, sinon la tombe libre du cimetière le plus proche), une case
##   au columbarium ou le jardin du souvenir pour les cendres.
## - Les obsèques ont lieu 1 à 3 jours plus tard, du lundi au samedi, de 9 h 30
##   à 16 h. Le corbillard part des pompes funèbres, prend le défunt chez lui ou
##   à l'hôpital, passe au lieu de culte (cérémonie religieuse si la ville en a
##   un), puis au cimetière ou au crématorium. Les voitures de la famille le
##   suivent. Le corbillard roule vraiment sur les routes (Traffic).
## - Au cimetière, les proches se rassemblent autour de la fosse (figurines),
##   puis la pierre tombale apparaît, fleurie pendant quelques semaines. Le
##   cimetière se remplit ; plein, les défunts attendent à la chambre
##   funéraire, puis sont enterrés dans une commune voisine (plus cher, et les
##   familles sont mécontentes).
## - Concessions de 30 ans (de vie) : renouvelées par un proche qui vit en
##   ville, sinon la place est reprise (les restes vont à l'ossuaire).
## - La famille paie les obsèques ; la commune encaisse les concessions et la
##   redevance du crématorium, et paie l'entretien.
## - Liens par groupes de nœuds (aucune dépendance) : "avis_sources",
##   "budget_entretien", "budget_recettes", "pollution_sources", "fiche_batiment".

signal changed
signal message(text: String)

static var instance: Funeraire

## Délai minimal entre le décès et les obsèques (s de jeu).
const DELAI := 86400.0 * 1.2
## Heures des obsèques (heure locale), du lundi au samedi.
const HEURE_MIN := 9.5
const HEURE_MAX := 16.0
## Attente maximale d'une place avant d'enterrer dans une commune voisine.
const ATTENTE_MAX := 86400.0 * 6.0
## Durée d'une concession (années de vie).
const CONCESSION_ANS := 30.0
## Places d'un caveau familial.
const CAVEAU := 3
## Distance maximale à un cimetière ou un crématorium de la ville.
const RAYON := 25000.0
## Lieu de culte pris pour la cérémonie s'il est assez près.
const RAYON_CULTE := 8000.0
const LEVEE_S := 1200.0
const CULTE_S := 2700.0
const CEREMONIE_S := 1800.0
const STEP := 900.0
const TAG := 3_000_000
## Porteurs nécessaires pour un convoi.
const PORTEURS := 2
## Jours (de jeu) où une tombe récente reste fleurie.
const FLEURS_S := 86400.0 * 20.0

## Prix (€), ordres de grandeur français.
const PRIX_INHUMATION := 3800.0
const PRIX_CREMATION := 3300.0
const PRIX_CONCESSION := 450.0
const PRIX_CASE := 400.0
const REDEVANCE_CREMATION := 650.0
const SURCOUT_PF := 900.0
const SURCOUT_CREMATORIUM := 600.0
const SURCOUT_EXPORT := 1500.0
const ENTRETIEN := 0.001

## Part de crémations selon la région d'origine (ordre de grandeur actuel).
const CREMATION := {"europe": 0.42, "mediterranee": 0.15, "moyen_orient": 0.0, "afrique": 0.05, "asie_est": 0.92,
	"asie_sud": 0.8, "ameriques": 0.5, "oceanie": 0.65}
## Part de cérémonies religieuses selon la région d'origine.
const CULTE := {"europe": 0.45, "mediterranee": 0.75, "moyen_orient": 0.95, "afrique": 0.85, "asie_est": 0.5,
	"asie_sud": 0.85, "ameriques": 0.6, "oceanie": 0.4}
## Cimetière préféré selon la région (distance comptée trois fois moins).
const STYLE_REGION := {"cimetiere_asie": "asie_est", "cimetiere_musulman": "moyen_orient"}
## Devenir des cendres : columbarium, jardin du souvenir, gardées par la famille.
const CENDRES := {"case": 0.45, "jardin": 0.35}

var buildings: BuildingSystem
var population: Population
var transport: TransportSystem
var production: Production
var ambiance: DayNight

var ignore_hours := false
var ignore_crew := false
var rng := RandomNumberGenerator.new()

## bid → {role, tombes: {slot: {occ: [pid], noms: [texte], fin: jour de vie, t: unix}}, units: [{pid}], status}
var sites: Dictionary = {}
## pid → obsèques en préparation ou en cours (voir _organise).
var obseques: Dictionary = {}
## pid → {bid, slot, texte, mode} : où repose chaque défunt.
var sepultures: Dictionary = {}
## pid → [{d, txt, fin}] : ce que ressentent les proches (avis des habitants).
var ressentis: Dictionary = {}
## Urnes à placer : [{pid, t, dest, kind}]
var urnes: Array = []
var today := {}
var yesterday := {}
var totaux := {}
var recents: Array = []
var clock := -1.0
var last_unix := -1.0
var last_day := -1
var _money_frac := 0.0
var _acc: Dictionary = {}
var _dirty := true
var _vis_dirty: Dictionary = {}
var _vis: Dictionary = {}
var _cer: Dictionary = {}
var _cer_t := 0.0
var _warned: Dictionary = {}
var _prev_pick: Callable
var _prev_satisfaction: Callable
var _spawn_queue: Array = []


func _init() -> void:
	instance = self
	rng.seed = 4242
	today = _empty_stats()
	yesterday = _empty_stats()
	totaux = _empty_stats()
	add_to_group("avis_sources")
	add_to_group("budget_entretien")
	add_to_group("budget_recettes")
	add_to_group("pollution_sources")
	add_to_group("fiche_batiment")


static func _empty_stats() -> Dictionary:
	return {"deces": 0, "inhumations": 0, "cremations": 0, "exportes": 0, "renouvellements": 0, "reprises": 0,
		"convois": 0, "familles": 0.0, "commune": 0.0}


static func actif() -> bool:
	return ReglagesPartie.actuel == null or ReglagesPartie.actuel.funeraire


func setup(b: BuildingSystem, p: Population, t: TransportSystem, prod: Production, a: DayNight) -> void:
	buildings = b
	population = p
	transport = t
	production = prod
	ambiance = a
	if buildings != null:
		buildings.changed.connect(func() -> void: _dirty = true)
	if transport != null:
		transport.network_changed.connect(func() -> void: _acc.clear())
	if population != null:
		population.person_died.connect(_on_death)
		_prev_pick = population.extra_person_pick
		population.extra_person_pick = pick
	# Sans le fil « Avis » (qui lit le groupe avis_sources), on s'ajoute à la
	# satisfaction des habitants.
	if population != null:
		_prev_satisfaction = population.extra_satisfaction
		population.extra_satisfaction = _satisfaction_chainee


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _satisfaction_chainee(p: Dictionary) -> Array:
	var out: Array = [0.0, []]
	if _prev_satisfaction.is_valid():
		var r: Array = _prev_satisfaction.call(p)
		if r.size() >= 2:
			out = [float(r[0]), (r[1] as Array).duplicate()]
	var mine := satisfaction_of(p)
	out[0] = float(out[0]) + float(mine[0])
	(out[1] as Array).append_array(mine[1])
	return out


func clear() -> void:
	for pid in obseques.keys():
		_drop_visual(int(pid))
	for bid in _vis.keys():
		_free_vis(int(bid))
	for pid in _cer.keys():
		_end_ceremony_visual(int(pid))
	sites.clear()
	obseques.clear()
	sepultures.clear()
	ressentis.clear()
	urnes.clear()
	recents.clear()
	_spawn_queue.clear()
	today = _empty_stats()
	yesterday = _empty_stats()
	totaux = _empty_stats()
	clock = -1.0
	last_unix = -1.0
	last_day = -1
	_acc.clear()
	_dirty = true
	changed.emit()


# --- Bâtiments ----------------------------------------------------------------------------------

func _sync() -> void:
	_dirty = false
	if buildings == null:
		return
	for bid in sites.keys():
		if not buildings.buildings.has(bid) or FuneraireTypes.role_of(String(buildings.buildings[bid].t)) != String(sites[bid].role):
			_remove_site(int(bid))
	for bid in buildings.buildings:
		var t := String(buildings.buildings[bid].t)
		var role := FuneraireTypes.role_of(t)
		if role == "" or sites.has(bid) or buildings.en_chantier(bid):
			continue
		var s := {"role": role, "tombes": {}, "units": [], "status": "", "file": []}
		if role == "pompes_funebres":
			for i in int(FuneraireTypes.spec_of(t).get("corbillards", 2)):
				(s.units as Array).append({"pid": -1})
		sites[bid] = s
		_vis_dirty[bid] = true


func _remove_site(bid: int) -> void:
	var s: Dictionary = sites[bid]
	# Les tombes d'un cimetière démoli : les défunts sont transférés à l'ossuaire.
	for slot in s.tombes:
		for pid in s.tombes[slot].occ:
			if sepultures.has(int(pid)):
				sepultures[int(pid)].texte = "Restes transférés à l'ossuaire (cimetière démoli)"
				sepultures[int(pid)].bid = -1
	for pid in obseques:
		var o: Dictionary = obseques[pid]
		if int(o.dest) == bid:
			o.dest = -1
			o.slot = -1
			if String(o.etat) == "prevu":
				o.etat = "attente"
		if int(o.pf) == bid:
			o.pf = -1
	_free_vis(bid)
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
	if bid < 0:
		return "—"
	if population != null and population.known.has(bid):
		return population.building_name(bid)
	return String(BuildingCatalog.get_type(_type_of(bid)).get("name", "—"))


## Repère monde d'un bâtiment (comme son nœud dans BuildingSystem).
func _xform(bid: int) -> Transform3D:
	var b: Dictionary = buildings.buildings[bid]
	var pos := BuildingSystem.rect_center(buildings._rect_of(b)) + Vector3(0, float(b.get("h", 0.0)), 0)
	return Transform3D(Basis(Vector3.UP, -int(b.r) * PI / 2.0 + float(b.get("a", 0.0))), pos)


func slot_world(bid: int, slot: int) -> Transform3D:
	var sl: Array = FuneraireTypes.slots(_type_of(bid))
	if slot < 0 or slot >= sl.size():
		return _xform(bid)
	return _xform(bid) * (sl[slot] as Transform3D)


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


## Trajet par la route (s) ; à vol d'oiseau (36 km/h) sans route.
func _route_s(a: int, b: int) -> float:
	if a < 0 or b < 0:
		return 900.0
	var p := access_of(a)
	var q := access_of(b)
	if not p.is_empty() and not q.is_empty() and production != null:
		var s := float(production.route_pts(p, q).s)
		if s < INF:
			return s
	return _pos_of(a).distance_to(_pos_of(b)) / 10.0 + 60.0


# --- Places libres --------------------------------------------------------------------------------

func capacity(bid: int) -> int:
	return FuneraireTypes.slots(_type_of(bid)).size()


func used(bid: int) -> int:
	return (sites[bid].tombes as Dictionary).size() if sites.has(bid) else 0


## Places réservées par des obsèques à venir.
func _reserved(bid: int) -> Dictionary:
	var out := {}
	for pid in obseques:
		var o: Dictionary = obseques[pid]
		if int(o.dest) == bid and int(o.slot) >= 0:
			out[int(o.slot)] = true
	for u in urnes:
		if int(u.dest) == bid and int(u.get("slot", -1)) >= 0:
			out[int(u.slot)] = true
	return out


func free_places(bid: int) -> int:
	return maxi(0, capacity(bid) - used(bid) - _reserved(bid).size())


func _free_slot(bid: int) -> int:
	var res := _reserved(bid)
	var t: Dictionary = sites[bid].tombes
	for i in capacity(bid):
		if not t.has(i) and not res.has(i):
			return i
	return -1


func free_total(role: String) -> int:
	var n := 0
	for bid in sites_of(role):
		n += free_places(bid)
	return n


## Caveau d'un proche (conjoint, parent, enfant) avec encore de la place : [bid, slot] ou [].
func _family_tomb(rel: Array, pid := -1) -> Array:
	var cands := rel.duplicate()
	# Le conjoint mort avant (sa fiche garde le lien, celle du vivant non).
	if pid >= 0 and population != null:
		for k in sepultures:
			if int(population.vie.archive.get(int(k), {}).get("cj", -2)) == pid and not cands.has(int(k)):
				cands.push_front(int(k))
	for r in cands:
		if not sepultures.has(int(r)):
			continue
		var sp: Dictionary = sepultures[int(r)]
		var bid := int(sp.bid)
		if bid < 0 or not sites.has(bid) or String(sites[bid].role) != "cimetiere":
			continue
		var tb: Dictionary = sites[bid].tombes.get(int(sp.slot), {})
		if not tb.is_empty() and (tb.occ as Array).size() < CAVEAU:
			return [bid, int(sp.slot)]
	return []


## Cimetière de la ville le plus proche (avec préférence de style) qui a une place libre.
func _pick_cemetery(near: Vector3, region: String) -> int:
	var best := -1
	var best_d := INF
	for bid in sites_of("cimetiere"):
		if free_places(bid) <= 0:
			continue
		var d := _pos_of(bid).distance_to(near)
		if d > RAYON:
			continue
		var t := _type_of(bid)
		if STYLE_REGION.has(t):
			d *= 0.33 if String(STYLE_REGION[t]) == region else 2.5
		elif t == "cimetiere_militaire" or t == "cimetiere_juif":
			d *= 3.0
		if d < best_d:
			best_d = d
			best = bid
	return best


func _nearest(role: String, near: Vector3, need_free := false) -> int:
	var best := -1
	var best_d := INF
	for bid in sites_of(role):
		if need_free and free_places(bid) <= 0:
			continue
		var d := _pos_of(bid).distance_to(near)
		if d < best_d and d <= RAYON:
			best_d = d
			best = bid
	return best


func _culte_near(near: Vector3) -> int:
	if population == null:
		return -1
	var best := -1
	var best_d := RAYON_CULTE
	for bid in population.known:
		if not Metiers.keys_of(String(population.known[bid].t)).has("culte"):
			continue
		var d := (population.known[bid].pos as Vector3).distance_to(near)
		if d < best_d:
			best_d = d
			best = int(bid)
	return best


func _hospital_near(near: Vector3) -> int:
	if population == null:
		return -1
	var best := -1
	var best_d := 15000.0
	for bid in population.known:
		var keys := Metiers.keys_of(String(population.known[bid].t))
		if not (keys.has("hopital") or keys.has("clinique")):
			continue
		var d := (population.known[bid].pos as Vector3).distance_to(near)
		if d < best_d:
			best_d = d
			best = int(bid)
	return best


# --- Décès ------------------------------------------------------------------------------------------

func _now(t: float) -> Dictionary:
	if production != null:
		return production.local_time(t)
	return {"h": fposmod(t, 86400.0) / 3600.0, "wd": 2, "day": int(t / 86400.0)}


func _time_now() -> float:
	if clock >= 0.0:
		return clock
	return ambiance.unix_time if ambiance != null else 0.0


## Part de crémations pour un défunt de cette région.
static func part_cremation(region: String) -> float:
	var r := ReglagesPartie.actuel.cremation if ReglagesPartie.actuel != null else -1.0
	if r >= 0.0:
		return r
	return float(CREMATION.get(region, 0.4))


## Population.person_died : le défunt est encore dans pop.persons, son foyer aussi.
func _on_death(pid: int, home: int) -> void:
	if not actif() or population == null or not population.persons.has(pid):
		return
	if _dirty:
		_sync()
	var p: Dictionary = population.persons[pid]
	var h: Dictionary = population.households.get(int(p.f), {})
	var region := String(h.get("reg", "europe"))
	var vie := population.vie
	var proches: Array = []
	if int(p.get("cj", -1)) >= 0 and population.persons.has(int(p.cj)):
		proches.append(int(p.cj))
	for k in vie.children_of(pid):
		if population.persons.has(k) and not proches.has(k):
			proches.append(k)
	for par in vie.parents_of(p):
		if population.persons.has(par) and not proches.has(par):
			proches.append(par)
	for m in h.get("m", []):
		if int(m) != pid and not proches.has(int(m)):
			proches.append(int(m))
	var rel: Array = []
	if int(p.get("cj", -1)) >= 0:
		rel.append(int(p.cj))
	rel.append_array(vie.parents_of(p))
	rel.append_array(vie.children_of(pid))
	var t := _time_now()
	var near := _pos_of(home) if home >= 0 else Vector3.ZERO
	var cause := String(vie.archive.get(pid, {}).get("cause", ""))
	var lieu := home
	var hop := _hospital_near(near)
	if hop >= 0 and (cause.contains("maladie") or cause.contains("suites") or cause.contains("vasculaire") or rng.randf() < 0.3):
		lieu = hop
	var mode := "cremation" if rng.randf() < part_cremation(region) else "inhumation"
	var o := {"pid": pid, "nom": CycleVie.full_name(p), "s": String(p.get("s", "H")), "region": region, "t_mort": t,
		"lieu": lieu, "home": home, "mode": mode, "etat": "attente", "dest": -1, "slot": -1, "caveau": false,
		"pf": -1, "culte": -1, "t_prevu": 0.0, "proches": proches.slice(0, 12), "rel": rel, "cout": 0.0,
		"payeur": -1, "t0": 0.0, "t_levee": 0.0, "t_dep": 0.0, "t_culte": 0.0, "t_dest": 0.0, "t_fin": 0.0, "t_end": 0.0,
		"cortege": false, "religieux": rng.randf() < float(CULTE.get(region, 0.5)), "exterieur": "", "cendres": ""}
	if mode == "cremation":
		var r := rng.randf()
		o.cendres = "case" if r < float(CENDRES.case) else ("jardin" if r < float(CENDRES.case) + float(CENDRES.jardin) else "famille")
	# Qui paie : le conjoint, sinon un enfant qui vit en ville, sinon l'épargne du défunt.
	var payer := -1
	if int(p.get("cj", -1)) >= 0 and population.persons.has(int(p.cj)):
		payer = int(population.persons[int(p.cj)].f)
	if payer < 0:
		for k in vie.children_of(pid):
			if population.persons.has(k) and int(population.persons[k].f) != int(p.f):
				payer = int(population.persons[k].f)
				break
	if payer < 0:
		payer = int(p.f)
	o.payeur = payer
	today.deces = int(today.deces) + 1
	obseques[pid] = o
	_try_book(o)


## Réserve une place et fixe la date des obsèques (sinon le défunt attend).
func _try_book(o: Dictionary) -> bool:
	var near := _pos_of(int(o.home)) if int(o.home) >= 0 else Vector3.ZERO
	if String(o.mode) == "inhumation":
		var fam := _family_tomb(o.rel, int(o.pid))
		if not fam.is_empty():
			o.dest = int(fam[0])
			o.slot = int(fam[1])
			o.caveau = true
		else:
			var c := _pick_cemetery(near, String(o.region))
			if c < 0:
				return false
			o.dest = c
			o.slot = _free_slot(c)
			if int(o.slot) < 0:
				o.dest = -1
				return false
	else:
		o.dest = _nearest("crematorium", near)
		if int(o.dest) < 0:
			o.exterieur = "crematorium"
	o.etat = "prevu"
	o.t_prevu = _next_slot(maxf(float(o.t_mort) + DELAI, _time_now() + 3600.0))
	return true


## Prochain créneau d'obsèques : du lundi au samedi, entre 9 h 30 et 16 h.
func _next_slot(t: float) -> float:
	if ignore_hours:
		return t
	var tt := t
	for i in 200:
		var n := _now(tt)
		if int(n.wd) != 0 and float(n.h) >= HEURE_MIN and float(n.h) <= HEURE_MAX:
			return tt
		tt += 1800.0
	return t


# --- Temps --------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_cer_t += delta
	_update_ceremonies()
	_run_spawn_queue()
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


func step(_dt: float) -> void:
	if _dirty:
		_sync()
	var d := int(_now(clock).day)
	if d > last_day:
		last_day = d
		new_day()
	for pid in obseques.keys():
		_advance(obseques[pid])
	_place_urns()
	for bid in _vis_dirty.keys():
		_rebuild_vis(int(bid))
	_vis_dirty.clear()
	changed.emit()


## Une étape des obsèques d'un défunt.
func _advance(o: Dictionary) -> void:
	var pid := int(o.pid)
	match String(o.etat):
		"attente":
			if _try_book(o):
				return
			if clock - float(o.t_mort) > ATTENTE_MAX:
				_export(o)
			elif clock - float(o.t_mort) > 86400.0 * 2.0:
				_warn("attente", "%s attend ses obsèques : plus de place au cimetière (panneau Habitants, onglet Funéraire)." % o.nom, 86400.0)
		"prevu":
			if clock >= float(o.t_prevu):
				_start(o)
		"convoi":
			if not bool(o.cortege) and clock >= float(o.t_dep):
				o.cortege = true
				_spawn_cortege(o)
			if clock >= float(o.t_dest):
				o.etat = "ceremonie"
				_log_proches(o)
		"ceremonie":
			if clock >= float(o.t_fin):
				_finish(o)
		"retour":
			if clock >= float(o.t_end):
				_release_hearse(o)
				obseques.erase(pid)


## Le convoi part des pompes funèbres.
func _start(o: Dictionary) -> void:
	var near := _pos_of(int(o.lieu))
	var pf := -1
	var best_d := INF
	var pfs := sites_of("pompes_funebres")
	for b in pfs:
		if _free_hearse(b) < 0 or (not ignore_crew and _porteurs(b) < PORTEURS):
			continue
		var dd := _pos_of(b).distance_to(near)
		if dd < best_d:
			best_d = dd
			pf = b
	if pf < 0 and not pfs.is_empty() and clock - float(o.t_prevu) < 86400.0 * 2.0:
		# Les corbillards de la ville sont tous pris : un peu plus tard.
		o.t_prevu = _next_slot(clock + 3600.0 * 2.0)
		sites[pfs[0]].status = "Tous les corbillards sont en route"
		return
	if pf < 0:
		o.exterieur = "pf" if String(o.exterieur) == "" else String(o.exterieur) + ",pf"
	o.pf = pf
	if pf >= 0:
		sites[pf].units[_free_hearse(pf)].pid = int(o.pid)
	if bool(o.religieux):
		o.culte = _culte_near(near)
	var t := clock
	o.t0 = t
	o.t_levee = t + (_route_s(pf, int(o.lieu)) if pf >= 0 else 1500.0)
	o.t_dep = float(o.t_levee) + LEVEE_S
	var prev := int(o.lieu)
	var tt := float(o.t_dep)
	if int(o.culte) >= 0:
		o.t_culte = tt + _route_s(prev, int(o.culte))
		tt = float(o.t_culte) + CULTE_S
		prev = int(o.culte)
	o.t_dest = tt + (_route_s(prev, int(o.dest)) if int(o.dest) >= 0 else 1800.0)
	o.t_fin = float(o.t_dest) + CEREMONIE_S
	o.t_end = float(o.t_fin) + (_route_s(int(o.dest), pf) if pf >= 0 and int(o.dest) >= 0 else 0.0)
	o.etat = "convoi"
	_charge(o)
	today.convois = int(today.convois) + 1
	if pf >= 0:
		_spawn_hearse(o)


func _free_hearse(pf: int) -> int:
	var u: Array = sites[pf].units
	for i in u.size():
		if int(u[i].pid) < 0:
			return i
	return -1


func _release_hearse(o: Dictionary) -> void:
	_drop_visual(int(o.pid))
	var pf := int(o.pf)
	if pf >= 0 and sites.has(pf):
		for u in sites[pf].units:
			if int(u.pid) == int(o.pid):
				u.pid = -1


## Porteurs (et conseillers) de service aux pompes funèbres.
func _porteurs(bid: int) -> int:
	if ignore_crew or population == null:
		return 99
	var n := _now(clock)
	var c := 0
	for pid in population.by_job.get(bid, []):
		var p: Dictionary = population.persons.get(pid, {})
		if p.is_empty() or not String(p.get("met", "")) in ["porteur_funeraire", "conseiller_funeraire"]:
			continue
		if not population._works_today(p, n) or population._on_leave(p, n):
			continue
		var h: Array = Metiers.job(String(p.met)).h
		if float(n.h) >= float(h[0]) and float(n.h) < float(h[1]):
			c += 1
	return c


## La famille paie ; la commune encaisse concession et redevance.
func _charge(o: Dictionary) -> void:
	var cout := PRIX_INHUMATION if String(o.mode) == "inhumation" else PRIX_CREMATION
	var commune := 0.0
	var ext := String(o.exterieur)
	if ext.contains("pf"):
		cout += SURCOUT_PF
	if ext.contains("crematorium"):
		cout += SURCOUT_CREMATORIUM
	if String(o.mode) == "inhumation" and not bool(o.caveau) and int(o.dest) >= 0:
		cout += PRIX_CONCESSION
		commune += PRIX_CONCESSION
	if String(o.mode) == "cremation" and int(o.dest) >= 0:
		commune += REDEVANCE_CREMATION
	o.cout = cout
	var h: Dictionary = population.households.get(int(o.payeur), {}) if population != null else {}
	var pris := cout
	if not h.is_empty():
		pris = clampf(float(h.ep), 0.0, cout)
		h.ep = float(h.ep) - pris
	today.familles = float(today.familles) + pris
	# Obsèques d'une personne sans ressources : la commune paie le reste.
	if cout - pris > 1.0:
		_depense("Obsèques prises en charge par la commune", cout - pris)
	if commune > 0.0:
		_recette("Concessions et crématorium", commune)


## Fin de la cérémonie : le défunt repose (ou part au four).
func _finish(o: Dictionary) -> void:
	var pid := int(o.pid)
	var vie := population.vie if population != null else null
	var f: Dictionary = vie.archive.get(pid, {}) if vie != null else {}
	var g := CycleVie.g(f, "", "e") if not f.is_empty() else ""
	if String(o.mode) == "inhumation":
		_bury(pid, String(o.nom), int(o.dest), int(o.slot))
		var txt := "Inhumé%s %s %s, tombe n° %d" % [g, "dans le caveau familial du" if bool(o.caveau) else "au", building_name(int(o.dest)), int(o.slot) + 1]
		sepultures[pid] = {"bid": int(o.dest), "slot": int(o.slot), "texte": txt, "mode": "inhumation"}
		if vie != null and not f.is_empty():
			vie.log_event(f, "obseques", txt + (" après une cérémonie à %s" % building_name(int(o.culte)) if int(o.culte) >= 0 else ""), int(o.dest))
		today.inhumations = int(today.inhumations) + 1
	else:
		var where := building_name(int(o.dest)) if int(o.dest) >= 0 else "un crématorium d'une commune voisine"
		var txt := "Incinéré%s à %s" % [g, where]
		sepultures[pid] = {"bid": -1, "slot": -1, "texte": txt, "mode": "cremation"}
		if vie != null and not f.is_empty():
			vie.log_event(f, "obseques", txt, int(o.dest))
		today.cremations = int(today.cremations) + 1
		urnes.append({"pid": pid, "t": clock + 86400.0, "dest": -1, "slot": -1, "kind": String(o.cendres), "nom": String(o.nom),
			"pres": int(o.dest) if int(o.dest) >= 0 else int(o.home)})
	recents.push_front(pid)
	if recents.size() > 40:
		recents.pop_back()
	for q in o.proches:
		var bon := 3.0 if String(o.exterieur) == "" else 1.0
		var reasons := "+ Belles obsèques pour %s" % o.nom if String(o.exterieur) == "" else "± Obsèques de %s organisées par une commune voisine" % o.nom
		_feel(int(q), bon, reasons, 86400.0 * 20.0)
	o.etat = "retour"
	if int(o.pf) < 0:
		obseques.erase(pid)


func _log_proches(o: Dictionary) -> void:
	if population == null:
		return
	var where := building_name(int(o.dest)) if int(o.dest) >= 0 else "une commune voisine"
	for q in o.proches:
		if population.persons.has(int(q)):
			var who: Dictionary = population.persons[int(q)]
			var f: Dictionary = population.vie.person(int(o.pid))
			if f.is_empty():
				continue
			var rel := population.vie.relation(who, f)
			if rel == "colocataire":
				rel = ""
			population.vie.log_event(who, "obseques", "Assiste aux obsèques de %s%s (%s)" % [rel + " " if rel != "" else "", o.nom, where], int(o.dest))


func _bury(pid: int, nom: String, bid: int, slot: int) -> void:
	if bid < 0 or not sites.has(bid) or slot < 0:
		return
	var tb: Dictionary = sites[bid].tombes
	if not tb.has(slot):
		tb[slot] = {"occ": [], "noms": [], "fin": 0.0, "t": clock}
	var e: Dictionary = tb[slot]
	(e.occ as Array).append(pid)
	(e.noms as Array).append(nom)
	e.fin = _life() + CONCESSION_ANS * 365.25
	e.t = clock
	_vis_dirty[bid] = true


func _life() -> float:
	return population.life_clock if population != null else clock / 86400.0


## Pas de place : enterré dans une commune voisine.
func _export(o: Dictionary) -> void:
	var pid := int(o.pid)
	o.exterieur = "export"
	var h: Dictionary = population.households.get(int(o.payeur), {}) if population != null else {}
	var cout := (PRIX_INHUMATION + SURCOUT_EXPORT)
	if not h.is_empty():
		h.ep = float(h.ep) - minf(maxf(float(h.ep), 0.0), cout)
	today.familles = float(today.familles) + cout
	today.exportes = int(today.exportes) + 1
	var f: Dictionary = population.vie.archive.get(pid, {}) if population != null else {}
	var txt := "Inhumé%s dans une commune voisine, faute de place en ville" % (CycleVie.g(f, "", "e") if not f.is_empty() else "")
	sepultures[pid] = {"bid": -1, "slot": -1, "texte": txt, "mode": "export"}
	if not f.is_empty():
		population.vie.log_event(f, "obseques", txt, -1)
	for q in o.proches:
		_feel(int(q), -8.0, "− %s enterré%s loin d'ici, faute de place au cimetière" % [o.nom, "e" if String(o.s) == "F" else ""], 86400.0 * 60.0)
	_warn("export", "Plus de place : %s a été enterré%s dans une commune voisine. Construis ou agrandis un cimetière." % [o.nom, "e" if String(o.s) == "F" else ""], 86400.0)
	obseques.erase(pid)


## Urnes : columbarium, jardin du souvenir ou famille, le lendemain de la crémation.
func _place_urns() -> void:
	for u in urnes.duplicate():
		if clock < float(u.t):
			continue
		urnes.erase(u)
		var pid := int(u.pid)
		var near := _pos_of(int(u.pres)) if int(u.pres) >= 0 else Vector3.ZERO
		var kind := String(u.kind)
		var txt := ""
		if kind == "case":
			var c := _nearest("columbarium", near, true)
			if c >= 0:
				var slot := _free_slot(c)
				_bury(pid, String(u.nom), c, slot)
				_recette("Concessions et crématorium", PRIX_CASE)
				txt = "Urne déposée au %s, case n° %d" % [building_name(c), slot + 1]
				sepultures[pid] = {"bid": c, "slot": slot, "texte": txt, "mode": "case"}
			else:
				kind = "jardin"
		if kind == "jardin":
			var j := -1
			for role in ["columbarium", "crematorium", "cimetiere"]:
				for b in sites_of(role):
					if bool(FuneraireTypes.spec_of(_type_of(b)).get("jardin", false)) and (j < 0 or _pos_of(b).distance_to(near) < _pos_of(j).distance_to(near)):
						j = b
			if j >= 0:
				txt = "Cendres dispersées au jardin du souvenir (%s)" % building_name(j)
				sepultures[pid] = {"bid": j, "slot": -1, "texte": txt, "mode": "jardin"}
			else:
				kind = "famille"
		if kind == "famille":
			txt = "Urne gardée par la famille"
			sepultures[pid] = {"bid": -1, "slot": -1, "texte": txt, "mode": "famille"}
		if population != null and population.vie.archive.has(pid):
			population.vie.log_event(population.vie.archive[pid], "cendres", txt, -1)


# --- Chaque jour ------------------------------------------------------------------------------------

func new_day() -> void:
	if actif():
		_concessions()
	for k in today:
		totaux[k] = totaux[k] + today[k]
	yesterday = today
	today = _empty_stats()
	for pid in ressentis.keys():
		var l: Array = ressentis[pid]
		for e in l.duplicate():
			if float(e.fin) < clock:
				l.erase(e)
		if l.is_empty() or (population != null and not population.persons.has(int(pid))):
			ressentis.erase(pid)
	_pay_day()


## Concessions échues : un proche qui vit en ville renouvelle, sinon la place est reprise.
func _concessions() -> void:
	var life := _life()
	for bid in sites:
		var tb: Dictionary = sites[bid].tombes
		for slot in tb.keys():
			var e: Dictionary = tb[slot]
			if float(e.fin) > life:
				continue
			var heir := _living_relative(e.occ)
			if heir >= 0:
				e.fin = life + CONCESSION_ANS * 365.25
				var prix := PRIX_CASE if String(sites[bid].role) == "columbarium" else PRIX_CONCESSION
				var h: Dictionary = population.households.get(int(population.persons[heir].f), {})
				if not h.is_empty():
					h.ep = float(h.ep) - prix
				_recette("Concessions et crématorium", prix)
				population.vie.log_event(population.persons[heir], "concession", "Renouvelle la concession de %s (%s)" % [", ".join(e.noms), building_name(int(bid))], int(bid))
				today.renouvellements = int(today.renouvellements) + 1
			else:
				for pid in e.occ:
					if sepultures.has(int(pid)):
						sepultures[int(pid)].texte = String(sepultures[int(pid)].texte) + " ; concession reprise, restes à l'ossuaire"
						sepultures[int(pid)].bid = -1
				tb.erase(slot)
				today.reprises = int(today.reprises) + 1
				_vis_dirty[bid] = true


## Un vivant de la ville proche d'un des défunts (conjoint, enfant, petit-enfant) ; -1 sinon.
func _living_relative(occ: Array) -> int:
	if population == null:
		return -1
	var dead := {}
	for pid in occ:
		dead[int(pid)] = true
	for pid in population.persons:
		var p: Dictionary = population.persons[pid]
		if dead.has(int(p.get("cj", -1))):
			return int(pid)
		for par in p.get("pa", []):
			if dead.has(int(par)):
				return int(pid)
			var f: Dictionary = population.vie.person(int(par))
			for gp in f.get("pa", []):
				if dead.has(int(gp)):
					return int(pid)
	return -1


func _feel(pid: int, d: float, txt: String, dur: float) -> void:
	if population == null or not population.persons.has(pid):
		return
	if not ressentis.has(pid):
		ressentis[pid] = []
	(ressentis[pid] as Array).append({"d": d, "txt": txt, "fin": clock + dur})
	while (ressentis[pid] as Array).size() > 3:
		(ressentis[pid] as Array).pop_front()


func _warn(key: String, text: String, every := 3600.0 * 6.0) -> void:
	if clock - float(_warned.get(key, -INF)) < every:
		return
	_warned[key] = clock
	message.emit(text)


# --- Argent --------------------------------------------------------------------------------------------

func _recette(poste: String, v: float) -> void:
	today.commune = float(today.commune) + v
	if BudgetCommunal.instance != null:
		BudgetCommunal.instance.recette(poste, v)
	elif buildings != null and not buildings.unlimited_money:
		buildings.money += roundi(v)


func _depense(poste: String, v: float) -> void:
	today.commune = float(today.commune) - v
	if BudgetCommunal.instance != null:
		BudgetCommunal.instance.depense(poste, v)
	elif buildings != null and not buildings.unlimited_money:
		buildings.money -= roundi(v)


func budget_entretien() -> Dictionary:
	var c := 0.0
	for bid in sites:
		if String(sites[bid].role) != "pompes_funebres":
			c += float(BuildingCatalog.cost(_type_of(int(bid)))) * ENTRETIEN
	return {"Cimetières et crématorium": c} if c > 0.0 else {}


func budget_recettes() -> Dictionary:
	return {}


func _pay_day() -> void:
	if buildings == null or buildings.unlimited_money or BudgetCommunal.instance != null:
		return
	var net := 0.0
	var e := budget_entretien()
	for k in e:
		net -= float(e[k])
	_money_frac += net / 30.0
	var whole := int(_money_frac)
	if whole != 0:
		buildings.money += whole
		_money_frac -= whole


# --- Liens avec les autres systèmes -------------------------------------------------------------------

func pollution_sources() -> Array:
	var out: Array = []
	for bid in sites_of("crematorium"):
		out.append({"pos": _pos_of(bid), "rayon": 300.0, "air": 0.2, "odeur": 0.1, "nom": building_name(bid), "bid": bid})
	return out


func avis_facteurs() -> Array:
	return [{"id": "funeraire", "theme": "services", "f": satisfaction_of}]


## Ce que les obsèques font à un habitant : [delta, raisons].
func satisfaction_of(p: Dictionary) -> Array:
	if population == null or not actif():
		return [0.0, []]
	var d := 0.0
	var why: Array = []
	var pid := int(p.get("id", -1))
	for e in ressentis.get(pid, []):
		if float(e.fin) >= clock:
			d += float(e.d)
			why.append(String(e.txt))
	# Un proche qui attend ses obsèques.
	for q in obseques:
		var o: Dictionary = obseques[q]
		if String(o.etat) == "attente" and (o.proches as Array).has(pid) and clock - float(o.t_mort) > 86400.0 * 2.0:
			d -= 6.0
			why.append("− %s attend ses obsèques depuis %d jours" % [o.nom, int((clock - float(o.t_mort)) / 86400.0)])
			break
	if population.age_of(p) >= 65.0 and sites_of("cimetiere").is_empty() and population.persons.size() >= 150:
		d -= 3.0
		why.append("− Pas de cimetière dans la ville")
	var home := population.home_of(p)
	if home >= 0:
		for c in sites_of("crematorium"):
			if _pos_of(c).distance_to(_pos_of(home)) < 250.0:
				d -= 2.0
				why.append("− Je vis à côté du crématorium")
				break
	return [d, why]


## Lignes de la fiche d'un bâtiment (panneau Habitants) : [[texte, pid ou -1]].
func fiche_lignes(bid: int) -> Array:
	if not sites.has(bid):
		return []
	var s: Dictionary = sites[bid]
	var out: Array = []
	match String(s.role):
		"cimetiere", "columbarium":
			out.append(["%s : %d / %d places occupées, %d libres" % ["Tombes" if String(s.role) == "cimetiere" else "Cases",
				used(bid), capacity(bid), free_places(bid)], -1])
			var list: Array = []
			for slot in s.tombes:
				var e: Dictionary = s.tombes[slot]
				for i in (e.occ as Array).size():
					list.append([float(e.t), int(e.occ[i]), String(e.noms[i]), int(slot)])
			list.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
			for x in list.slice(0, 12):
				out.append(["† %s (n° %d)" % [x[2], int(x[3]) + 1], int(x[1])])
		"crematorium":
			out.append(["Crémations hier : %d" % int(yesterday.cremations), -1])
		"pompes_funebres":
			var busy := 0
			for u in s.units:
				if int(u.pid) >= 0:
					busy += 1
			out.append(["Corbillards : %d en convoi sur %d" % [busy, (s.units as Array).size()], -1])
			for u in s.units:
				if int(u.pid) >= 0 and obseques.has(int(u.pid)):
					out.append(["Convoi de %s" % obseques[int(u.pid)].nom, int(u.pid)])
	return out


## Où repose un défunt ("" : inconnu).
func sepulture_text(pid: int) -> String:
	if sepultures.has(pid):
		return String(sepultures[pid].texte)
	if obseques.has(pid):
		var o: Dictionary = obseques[pid]
		match String(o.etat):
			"attente":
				return "Attend ses obsèques : plus de place au cimetière"
			"prevu":
				return "Obsèques prévues %s" % _when(float(o.t_prevu))
			_:
				return "Obsèques en cours"
	return ""


func _when(t: float) -> String:
	var n := _now(t)
	var dd := int(n.day) - int(_now(clock).day)
	var j := "aujourd'hui" if dd <= 0 else ("demain" if dd == 1 else "dans %d jours" % dd)
	return "%s à %d h %02d" % [j, int(n.h), int(fmod(float(n.h), 1.0) * 60.0)]


func etat_text(o: Dictionary) -> String:
	match String(o.etat):
		"attente":
			return "en attente d'une place (%d j)" % int((clock - float(o.t_mort)) / 86400.0)
		"prevu":
			return "%s, %s" % ["inhumation" if String(o.mode) == "inhumation" else "crémation", _when(float(o.t_prevu))]
		"convoi":
			if clock < float(o.t_dep):
				return "levée du corps"
			if int(o.culte) >= 0 and clock < float(o.t_culte) + CULTE_S:
				return "cérémonie à %s" % building_name(int(o.culte))
			return "cortège vers %s" % (building_name(int(o.dest)) if int(o.dest) >= 0 else "la commune voisine")
		"ceremonie":
			return "%s à %s" % ["mise en terre" if String(o.mode) == "inhumation" else "cérémonie d'adieu",
				building_name(int(o.dest)) if int(o.dest) >= 0 else "la commune voisine"]
		"retour":
			return "terminées"
	return ""


func bilan() -> Dictionary:
	var att := 0
	for pid in obseques:
		if String(obseques[pid].etat) == "attente":
			att += 1
	return {"deces": int(yesterday.deces), "inhumations": int(yesterday.inhumations), "cremations": int(yesterday.cremations),
		"exportes": int(totaux.exportes) + int(today.exportes), "attente": att, "tombes_libres": free_total("cimetiere"),
		"cases_libres": free_total("columbarium"), "en_cours": obseques.size()}


func summary() -> String:
	if sites.is_empty() and obseques.is_empty():
		return ""
	return "Cimetières : %d places libres" % free_total("cimetiere")


# --- À l'écran : pierres tombales -------------------------------------------------------------------

func _free_vis(bid: int) -> void:
	for n in _vis.get(bid, []):
		if is_instance_valid(n):
			(n as Node).queue_free()
	_vis.erase(bid)


func _rebuild_vis(bid: int) -> void:
	_free_vis(bid)
	if not sites.has(bid) or not is_inside_tree():
		return
	var s: Dictionary = sites[bid]
	if not String(s.role) in ["cimetiere", "columbarium"] or (s.tombes as Dictionary).is_empty():
		return
	var t := _type_of(bid)
	var style := String(FuneraireTypes.spec_of(t).get("stele", "dalle")) if String(s.role) == "cimetiere" else "plaque"
	var sl: Array = FuneraireTypes.slots(t)
	var xf := _xform(bid)
	var groups := {}
	var fleurs: Array = []
	for slot in s.tombes:
		var i := int(slot)
		if i < 0 or i >= sl.size():
			continue
		var v := absi(hash(i * 7919 + bid)) % 4
		var key := "%s:%d" % [style, v]
		if not groups.has(key):
			groups[key] = []
		(groups[key] as Array).append(xf * (sl[i] as Transform3D))
		if style != "plaque" and clock - float(s.tombes[slot].t) < FLEURS_S:
			fleurs.append(xf * (sl[i] as Transform3D))
	var nodes: Array = []
	for key in groups:
		var parts := String(key).split(":")
		nodes.append(_mm(FuneraireTypes.tomb_mesh(parts[0], int(parts[1])), groups[key]))
	if not fleurs.is_empty():
		nodes.append(_mm(FuneraireTypes.tomb_mesh("fleurs", bid % 5), fleurs))
	_vis[bid] = nodes


func _mm(mesh: Mesh, xfs: Array) -> MultiMeshInstance3D:
	var mmi := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	mmi.multimesh = mm
	mmi.visibility_range_end = 900.0
	add_child(mmi)
	return mmi


## Pierres tombales visibles (tests).
func tombs_shown(bid: int) -> int:
	var n := 0
	for m in _vis.get(bid, []):
		if is_instance_valid(m) and (m as MultiMeshInstance3D).multimesh.mesh != FuneraireTypes.tomb_mesh("fleurs", bid % 5):
			n += (m as MultiMeshInstance3D).multimesh.instance_count
	return n


# --- À l'écran : corbillard, cortège et cérémonie ---------------------------------------------------

func _traffic() -> Traffic:
	if transport == null or transport.traffic == null or not transport.traffic.enabled:
		return null
	return transport.traffic


static func _halt(p: Dictionary) -> Dictionary:
	return {"e": int(p.e), "s": float(p.s)}


func _halts(ids: Array) -> Array:
	var out: Array = []
	for b in ids:
		if int(b) < 0:
			continue
		var a := access_of(int(b))
		if not a.is_empty():
			out.append(_halt(a))
	return out


func _start_node(bid: int) -> int:
	var p := access_of(bid)
	if p.is_empty():
		return -1
	return int(p.a) if float(p.s) <= float(p.len) * 0.5 else int(p.b)


func _spawn_hearse(o: Dictionary) -> void:
	var tr := _traffic()
	var pf := int(o.pf)
	if tr == null or pf < 0:
		return
	var start := _start_node(pf)
	var halts := _halts([int(o.lieu), int(o.culte), int(o.dest), pf])
	if start < 0 or halts.is_empty():
		return
	tr.add_delivery_vehicle(TAG + int(o.pid) * 8, "corbillard", start, halts)


## Les voitures de la famille suivent le corbillard depuis la levée du corps.
func _spawn_cortege(o: Dictionary) -> void:
	var tr := _traffic()
	if tr == null:
		return
	var start := _start_node(int(o.lieu))
	var halts := _halts([int(o.culte), int(o.dest), int(o.home)])
	if start < 0 or halts.is_empty():
		return
	var n := clampi((o.proches as Array).size() / 2 + 1, 1, 4)
	var models := ["berline", "citadine", "monospace", "suv"]
	for i in n:
		_spawn_queue.append({"at": Time.get_ticks_msec() + 1600 * (i + 1), "tag": TAG + int(o.pid) * 8 + 1 + i,
			"model": models[(int(o.pid) + i) % models.size()], "start": start, "halts": halts.duplicate(true)})


func _run_spawn_queue() -> void:
	if _spawn_queue.is_empty():
		return
	var tr := _traffic()
	var now := Time.get_ticks_msec()
	for e in _spawn_queue.duplicate():
		if now >= int(e.at):
			_spawn_queue.erase(e)
			if tr != null:
				tr.add_delivery_vehicle(int(e.tag), String(e.model), int(e.start), e.halts)


func _drop_visual(pid: int) -> void:
	var tr := _traffic()
	if tr == null:
		return
	var lo := TAG + pid * 8
	for i in range(tr.vehicles.size() - 1, -1, -1):
		var v: Dictionary = tr.vehicles[i]
		var tag := int(v.get("delivery", -1))
		if tag >= lo and tag < lo + 8:
			tr._free_vehicle(v)
			tr.vehicles.remove_at(i)


## Corbillards et voitures du cortège sur la route.
func vehicles_on_road() -> Dictionary:
	var out := {"corbillards": 0, "cortege": 0}
	var tr := _traffic()
	if tr == null:
		return out
	for v in tr.vehicles:
		var tag := int(v.get("delivery", -1))
		if tag >= TAG and tag < TAG * 2:
			if (tag - TAG) % 8 == 0:
				out.corbillards += 1
			else:
				out.cortege += 1
	return out


## Cérémonies au cimetière : fosse, cercueil et proches debout autour.
func _update_ceremonies() -> void:
	for pid in obseques:
		var o: Dictionary = obseques[pid]
		var on := String(o.etat) == "ceremonie" and int(o.dest) >= 0 and sites.has(int(o.dest))
		if on and not _cer.has(pid):
			_begin_ceremony_visual(o)
		elif not on and _cer.has(pid):
			_end_ceremony_visual(int(pid))
	for pid in _cer.keys():
		if not obseques.has(pid):
			_end_ceremony_visual(int(pid))
	for pid in _cer:
		for f in _cer[pid].figs:
			if is_instance_valid(f):
				(f as Figurine).animer(_cer_t)


func _begin_ceremony_visual(o: Dictionary) -> void:
	var pid := int(o.pid)
	var dest := int(o.dest)
	var root := Node3D.new()
	root.name = "Obseques_%d" % pid
	add_child(root)
	var center: Transform3D
	if String(o.mode) == "inhumation" and int(o.slot) >= 0:
		center = slot_world(dest, int(o.slot))
		var fosse := MeshInstance3D.new()
		fosse.mesh = FuneraireTypes.tomb_mesh("fosse")
		root.add_child(fosse)
		fosse.global_transform = center
		var cer := MeshInstance3D.new()
		cer.mesh = FuneraireTypes.tomb_mesh("cercueil")
		root.add_child(cer)
		cer.global_transform = center.translated(Vector3(0, 0.05, 0))
	else:
		# Crématorium : devant la salle de cérémonie.
		var b: Dictionary = buildings.buildings[dest]
		var door := BuildingSystem.door_point(String(b.t), buildings._rect_of(b), int(b.r), float(b.get("a", 0.0)))
		center = Transform3D(_xform(dest).basis, door + _xform(dest).basis * Vector3(0, 0, 4.0))
	var figs: Array = []
	var who: Array = []
	for q in o.proches:
		if population != null and population.persons.has(int(q)):
			who.append(int(q))
	var n := who.size() + 2
	for i in n:
		var f: Figurine
		if i < who.size():
			var p: Dictionary = population.persons[who[i]]
			f = Figurine.creer(who[i], "", population.age_of(p) < 14.0, population)
		else:
			f = Figurine.creer(900_000 + pid * 4 + i, "porteur_funeraire")
		f.regler("recueillement")
		root.add_child(f)
		# En arc de cercle autour de la fosse, côté allée.
		var a := PI * (0.15 + 0.7 * float(i) / maxf(1.0, float(n - 1)))
		var r := 2.2 + 0.6 * float(i % 2)
		var local := Vector3(cos(a) * r, 0.0, -sin(a) * r * 0.9 - 0.3)
		var pos := center * local
		f.global_position = pos
		f.look_at(center.origin + Vector3(0, 0.0, 0), Vector3.UP, true)
		figs.append(f)
	_cer[pid] = {"node": root, "figs": figs}


func _end_ceremony_visual(pid: int) -> void:
	var c: Dictionary = _cer.get(pid, {})
	if not c.is_empty() and is_instance_valid(c.node):
		(c.node as Node).queue_free()
	_cer.erase(pid)


func ceremonies_shown() -> int:
	return _cer.size()


## Clic sur une tombe (Population.extra_person_pick) : la fiche du défunt.
func pick(screen: Vector2, cam: Camera3D) -> int:
	if _prev_pick.is_valid():
		var w := int(_prev_pick.call(screen, cam))
		if w >= 0:
			return w
	if cam == null:
		return -1
	var best := -1
	var best_d := 22.0
	var eye := cam.global_position
	for bid in sites:
		var s: Dictionary = sites[bid]
		if (s.tombes as Dictionary).is_empty() or _pos_of(int(bid)).distance_to(eye) > 600.0:
			continue
		for slot in s.tombes:
			var xf := slot_world(int(bid), int(slot))
			var p := xf * Vector3(0, 0.6, 0.6)
			if cam.is_position_behind(p):
				continue
			var d := cam.unproject_position(p).distance_to(screen)
			if d < best_d:
				best_d = d
				best = int((s.tombes[slot].occ as Array).back())
	if best >= 0 and population != null and not population.vie.archive.has(best):
		message.emit("Tombe de %s." % _name_in_tomb(best))
		return -1
	return best


func _name_in_tomb(pid: int) -> String:
	for bid in sites:
		for slot in sites[bid].tombes:
			var e: Dictionary = sites[bid].tombes[slot]
			var i := (e.occ as Array).find(pid)
			if i >= 0:
				return String(e.noms[i])
	return "?"


# --- Sauvegarde --------------------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var si := {}
	for bid in sites:
		var tb := {}
		for slot in sites[bid].tombes:
			var e: Dictionary = sites[bid].tombes[slot]
			tb[str(slot)] = {"occ": e.occ, "noms": e.noms, "fin": snappedf(float(e.fin), 0.01), "t": float(e.t)}
		si[str(bid)] = {"tombes": tb}
	var ob := []
	for pid in obseques:
		var o: Dictionary = (obseques[pid] as Dictionary).duplicate(true)
		ob.append(o)
	var sp := {}
	for pid in sepultures:
		sp[str(pid)] = sepultures[pid]
	var re := {}
	for pid in ressentis:
		re[str(pid)] = ressentis[pid]
	return {"version": 1, "sites": si, "obseques": ob, "sepultures": sp, "ressentis": re, "urnes": urnes, "recents": recents,
		"veille": yesterday, "jour": today, "totaux": totaux, "clock": clock, "money_frac": _money_frac}


func from_dict(d: Dictionary) -> void:
	clear()
	_sync()
	for k in d.get("sites", {}):
		var bid := int(k)
		if not sites.has(bid):
			continue
		var tb: Dictionary = sites[bid].tombes
		var src: Dictionary = d.sites[k].get("tombes", {})
		for sk in src:
			var e: Dictionary = src[sk]
			var occ: Array = []
			for x in e.get("occ", []):
				occ.append(int(x))
			tb[int(sk)] = {"occ": occ, "noms": (e.get("noms", []) as Array).duplicate(), "fin": float(e.get("fin", 0.0)), "t": float(e.get("t", 0.0))}
		_vis_dirty[bid] = true
	for x in d.get("obseques", []):
		var o: Dictionary = (x as Dictionary).duplicate(true)
		for k in ["pid", "lieu", "home", "dest", "slot", "pf", "culte", "payeur"]:
			o[k] = int(o.get(k, -1))
		var pr: Array = []
		for q in o.get("proches", []):
			pr.append(int(q))
		o.proches = pr
		var rl: Array = []
		for q in o.get("rel", []):
			rl.append(int(q))
		o.rel = rl
		# Les convois en route au moment de la sauvegarde repartent sans véhicules.
		if String(o.etat) in ["convoi", "ceremonie", "retour"]:
			o.cortege = true
		obseques[int(o.pid)] = o
		if int(o.pf) >= 0 and sites.has(int(o.pf)) and String(o.etat) in ["convoi", "ceremonie", "retour"]:
			var i := _free_hearse(int(o.pf))
			if i >= 0:
				sites[int(o.pf)].units[i].pid = int(o.pid)
	for k in d.get("sepultures", {}):
		var e: Dictionary = d.sepultures[k]
		sepultures[int(k)] = {"bid": int(e.get("bid", -1)), "slot": int(e.get("slot", -1)), "texte": String(e.get("texte", "")), "mode": String(e.get("mode", ""))}
	for k in d.get("ressentis", {}):
		ressentis[int(k)] = (d.ressentis[k] as Array).duplicate(true)
	for u in d.get("urnes", []):
		var e: Dictionary = (u as Dictionary).duplicate()
		for k in ["pid", "dest", "slot", "pres"]:
			e[k] = int(e.get(k, -1))
		urnes.append(e)
	for pid in d.get("recents", []):
		recents.append(int(pid))
	for key in ["veille", "jour", "totaux"]:
		var src: Dictionary = d.get(key, {})
		var dst := _empty_stats()
		for k in dst:
			if src.has(k):
				dst[k] = src[k]
		match key:
			"veille": yesterday = dst
			"jour": today = dst
			"totaux": totaux = dst
	clock = float(d.get("clock", -1.0))
	_money_frac = float(d.get("money_frac", 0.0))
	for bid in _vis_dirty.keys():
		_rebuild_vis(int(bid))
	_vis_dirty.clear()
	changed.emit()
