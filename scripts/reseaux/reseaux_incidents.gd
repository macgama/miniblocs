class_name ReseauxIncidents
extends RefCounted
## Usure, pannes et crises des réseaux (électricité, eau, égouts, gaz).
##
## - Usure : chaque tronçon posé vieillit (état 1 → 0) au rythme du réglage Admin
##   « usure » ; plus il est usé, plus il casse souvent. « Rénover » le remet à neuf.
## - Pannes : un tronçon cassé (câble, conduite éventrée, collecteur bouché) est
##   hors service jusqu'à sa réparation ; dans les rues, des fuites d'eau (le
##   réseau perd une part de sa production) et des transformateurs grillés (un
##   pâté de maisons dans le noir). Une équipe de la ville répare au bout de
##   quelques heures, et la ville paie.
## - Orages : le vent abat des arbres sur les lignes aériennes.
##   Pour les autres systèmes (tempêtes, crues) : Reseaux.instance.endommager(pos, rayon, cause).
## - Canicule (30 °C et plus) : la climatisation fait grimper le courant, on boit
##   et on arrose plus.
## - Sécheresse : après une douzaine de jours sans pluie, les rivières et les
##   nappes baissent (captages, forages, barrages, refroidissement des centrales).
##   La ville peut imposer des restrictions d'eau (−20 % de consommation).

## Durée de vie (ans) des tronçons, au réglage d'usure normal.
const DUREE_VIE := {"ligne_ht": 60.0, "ligne_mt": 40.0, "conduite_eau": 50.0, "collecteur": 70.0, "conduite_gaz": 50.0}
## Pannes par km de tronçon et par jour, pour un tronçon neuf (×4 quand il est usé).
const PANNES_KM_JOUR := 0.004
## Part de la production d'eau perdue par une fuite dans une rue.
const PERTE_FUITE := 0.15
## Seuils de la canicule et de la sécheresse.
const CANICULE := 30.0
const JOURS_SECS_DEBUT := 12.0
const JOURS_SECS_PLEIN := 30.0
## Restrictions d'eau : part de la consommation gardée.
const RESTRICTION := 0.8

const NOMS := {"usure": "usure", "tempete": "tempête", "orage": "orage", "crue": "crue", "test": "essai"}

var r: Reseaux
## [{id, kind ("troncon", "fuite", "transfo"), res, tid, p, c, bids, fin, cout, cause}]
var incidents: Array = []
var jours_secs := 0.0
var secheresse := 0.0
var canicule := false
var restrictions := false
var rng := RandomNumberGenerator.new()
var _next := 1
var _precip_max := 0.0
var _t_max := -100.0
var _clock := 0.0


func _init(owner: Reseaux) -> void:
	r = owner
	rng.randomize()


func clear() -> void:
	incidents.clear()
	jours_secs = 0.0
	secheresse = 0.0
	canicule = false
	restrictions = false
	_precip_max = 0.0
	_t_max = -100.0


func now() -> float:
	return r.ambiance.unix_time if r.ambiance != null else _clock


static func vitesse() -> float:
	return ReglagesPartie.actuel.usure


# --- Facteurs lus par la simulation ------------------------------------------------------------

## Courant en plus pour la climatisation (1 = rien).
static func facteur_clim(t: float) -> float:
	return clampf(1.0 + 0.04 * maxf(t - 27.0, 0.0), 1.0, 1.4)


## Eau en plus quand il fait chaud (boire, arroser, se doucher).
func facteur_eau(t: float) -> float:
	var f := clampf(1.0 + 0.025 * maxf(t - 25.0, 0.0), 1.0, 1.3)
	return f * (RESTRICTION if restrictions else 1.0)


## Ce qu'une source d'eau (ou une centrale qui en a besoin) garde pendant la sécheresse.
func facteur_secheresse(info: Dictionary) -> float:
	if secheresse <= 0.0:
		return 1.0
	match String(info.get("source", "")):
		"riviere":
			return 1.0 - 0.6 * secheresse
		"nappe":
			return 1.0 - 0.35 * secheresse
	if info.has("pres_eau"):
		return 1.0 - 0.4 * secheresse
	return 1.0


## Part de l'eau perdue par les fuites d'un réseau d'eau (composante c).
func perte_eau(c: int) -> float:
	var p := 0.0
	for inc in incidents:
		if String(inc.kind) == "fuite" and not (inc.bids as Array).is_empty() and r.eau.composante_de(int(inc.bids[0])) == c:
			p += PERTE_FUITE
	return minf(p, 0.6)


## Bâtiments dans le noir à cause d'un transformateur grillé.
func coupe(bid: int) -> bool:
	for inc in incidents:
		if String(inc.kind) == "transfo" and (inc.bids as Array).has(bid):
			return true
	return false


func en_panne(res: String, tid: int) -> bool:
	return bool(r.reseau(res).troncons.get(tid, {}).get("hs", false))


func etat_troncon(res: String, tid: int) -> float:
	return float(r.reseau(res).troncons.get(tid, {}).get("u", 1.0))


# --- Chaque pas de simulation ---------------------------------------------------------------------

## Réparations finies, orages, canicule ; mémorise la météo du jour.
func maj(heures: float, t: float) -> void:
	_clock += heures * 3600.0
	_t_max = maxf(_t_max, t)
	var storm := 0.0
	if r.ambiance != null and r.ambiance.weather != null:
		_precip_max = maxf(_precip_max, r.ambiance.weather.precip)
		storm = r.ambiance.weather.storm
	if storm > 0.3 and heures > 0.0:
		orage(heures, storm)
	var maintenant := now()
	for inc in incidents.duplicate():
		if maintenant >= float(inc.fin):
			reparer(int(inc.id))
	var chaud := t >= CANICULE
	if chaud != canicule:
		canicule = chaud
		if chaud:
			r.message.emit("Canicule : %d °C. La climatisation fait grimper la demande d'électricité, on boit et on arrose plus." % roundi(t))
		else:
			r.message.emit("Fin de la canicule.")


## Une fois par jour : usure, pannes au hasard, sécheresse.
func nouveau_jour() -> void:
	vieillir(1.0)
	tirage_pannes()
	_maj_secheresse()


func vieillir(jours: float) -> void:
	var v := vitesse()
	if v <= 0.0:
		return
	for res in Reseaux.RES:
		var rs := r.reseau(res)
		for id in rs.troncons:
			var e: Dictionary = rs.troncons[id]
			if not bool(e.ok):
				continue
			var vie := float(DUREE_VIE.get(String(e.t), 50.0))
			e["u"] = clampf(float(e.get("u", 1.0)) - v * jours / (vie * 365.0), 0.0, 1.0)


func tirage_pannes() -> void:
	var v := vitesse()
	if v <= 0.0 or not ReglagesPartie.actuel.reseaux_obligatoires:
		return
	for res in Reseaux.RES:
		var rs := r.reseau(res)
		for id in rs.troncons.keys():
			var e: Dictionary = rs.troncons[id]
			if not bool(e.ok) or bool(e.get("hs", false)):
				continue
			var km := ReseauBase.longueur(e.pts) / 1000.0
			var use := 1.0 - float(e.get("u", 1.0))
			if rng.randf() < PANNES_KM_JOUR * km * (1.0 + 3.0 * use * use) * v:
				provoquer(res, id, "usure")
	# Dans les rues : une fuite d'eau, un transformateur.
	var neau := r.eau.consos.size()
	if neau > 0 and rng.randf() < clampf(0.004 * neau / 10.0, 0.0, 0.25) * v:
		var bids := r.eau.consos.keys()
		var bid: int = bids[rng.randi() % bids.size()]
		if r.eau.est_raccorde(bid):
			fuite(bid)
	var nel := r.elec.consos.size()
	if nel > 0 and rng.randf() < clampf(0.002 * nel / 10.0, 0.0, 0.15) * v:
		var bids2 := r.elec.consos.keys()
		var bid2: int = bids2[rng.randi() % bids2.size()]
		if r.elec.est_raccorde(bid2):
			transfo(bid2)


func _maj_secheresse() -> void:
	if _t_max < -50.0:
		return
	var avant := secheresse
	if _precip_max >= 0.15:
		jours_secs = maxf(jours_secs - 4.0, 0.0)
	elif _precip_max >= 0.05:
		jours_secs = maxf(jours_secs - 1.0, 0.0)
	elif _t_max > 15.0:
		jours_secs += 1.0
	_precip_max = 0.0
	_t_max = -100.0
	secheresse = clampf((jours_secs - JOURS_SECS_DEBUT) / JOURS_SECS_PLEIN, 0.0, 1.0)
	if avant <= 0.0 and secheresse > 0.0:
		r.message.emit("Sécheresse : %d jours sans pluie. Les rivières et les nappes baissent ; pense aux restrictions d'eau (panneau O, onglet Eau)." % int(jours_secs))
	elif avant < 0.5 and secheresse >= 0.5:
		r.message.emit("Sécheresse sévère : les captages et les barrages tournent au ralenti.")
	elif avant > 0.0 and secheresse <= 0.0:
		r.message.emit("La pluie est revenue : fin de la sécheresse.")


## Fait passer `jours` jours sans pluie (essais, scénarios).
func forcer_secheresse(jours: float) -> void:
	jours_secs = jours
	secheresse = clampf((jours_secs - JOURS_SECS_DEBUT) / JOURS_SECS_PLEIN, 0.0, 1.0)


# --- Pannes ---------------------------------------------------------------------------------------

func _ajouter(inc: Dictionary) -> int:
	inc["id"] = _next
	_next += 1
	incidents.append(inc)
	r._topo_sale = true
	r.changed.emit()
	return int(inc.id)


func _delai(h: float) -> float:
	return now() + h * 3600.0


## Casse un tronçon : hors service jusqu'à la réparation. Renvoie l'id de l'incident.
func provoquer(res: String, tid: int, cause := "usure") -> int:
	var rs := r.reseau(res)
	if not rs.troncons.has(tid) or bool(rs.troncons[tid].get("hs", false)):
		return -1
	var e: Dictionary = rs.troncons[tid]
	e["hs"] = true
	var tr := ReseauxTypes.troncon(String(e.t))
	var l := ReseauBase.longueur(e.pts)
	var heures := 4.0 + l / 1000.0 * 6.0
	if cause in ["tempete", "orage", "crue"]:
		heures *= 1.5
	var cout := ReglagesPartie.prix(maxi(2000, roundi(float(e.get("cost", ReseauxTypes.prix_troncon(String(e.t), l))) * 0.04)))
	var pts: PackedVector3Array = e.pts
	var p := pts[rng.randi() % pts.size()]
	var quoi := "câble arraché" if res == "elec" else ("conduite éventrée" if res == "eau" else ("collecteur bouché" if res == "egout" else "fuite de gaz, conduite fermée"))
	var id := _ajouter({"kind": "troncon", "res": res, "tid": tid, "p": p, "c": -1, "bids": [], "fin": _delai(heures), "cout": cout, "cause": cause})
	r.message.emit("Panne (%s) : %s, %s. Équipe sur place dans %d h." % [NOMS.get(cause, cause), String(tr.get("name", "tronçon")).to_lower(), quoi, roundi(heures)])
	if r.vue:
		r.vue.refaire_troncon(res, tid)
	return id


## Fuite sur la conduite de la rue d'un bâtiment.
func fuite(bid: int) -> int:
	var c := r.eau.composante_de(bid)
	if c < 0:
		return -1
	var p: Vector3 = r.eau.consos[bid].p
	var id := _ajouter({"kind": "fuite", "res": "eau", "tid": -1, "p": p, "c": c, "bids": [bid], "fin": _delai(rng.randf_range(4.0, 12.0)),
		"cout": ReglagesPartie.prix(3000), "cause": "usure"})
	r.message.emit("Fuite d'eau dans une rue : le réseau perd %d %% de sa production jusqu'à la réparation." % roundi(PERTE_FUITE * 100.0))
	return id


## Transformateur de quartier grillé : les bâtiments voisins (60 m) n'ont plus de courant.
func transfo(bid: int) -> int:
	var p: Vector3 = r.elec.consos[bid].p
	var c := r.elec.composante_de(bid)
	var bids := []
	for b in r.elec.consos:
		if r.elec.composante_de(b) == c and Vector2(p.x, p.z).distance_to(Vector2(r.elec.consos[b].p.x, r.elec.consos[b].p.z)) < 60.0:
			bids.append(b)
	var id := _ajouter({"kind": "transfo", "res": "elec", "tid": -1, "p": p, "c": c, "bids": bids, "fin": _delai(rng.randf_range(2.0, 6.0)),
		"cout": ReglagesPartie.prix(8000), "cause": "usure"})
	r.message.emit("Transformateur grillé : %d bâtiment%s dans le noir." % [bids.size(), "s" if bids.size() > 1 else ""])
	return id


## Dégâts d'une tempête ou d'une crue : les lignes aériennes à moins de `rayon`
## mètres tombent (et les conduites si la cause est une crue). Renvoie le nombre de tronçons cassés.
func endommager(pos: Vector3, rayon: float, cause := "tempete") -> int:
	var n := 0
	var lst := ["elec"] if cause != "crue" else Reseaux.RES
	for res in lst:
		var rs := r.reseau(res)
		for id in rs.troncons.keys():
			var pts: PackedVector3Array = rs.troncons[id].pts
			for i in range(pts.size() - 1):
				if ReseauBase.dist_seg(pos, pts[i], pts[i + 1]) <= rayon:
					if provoquer(res, id, cause) >= 0:
						n += 1
					break
	return n


## Orage : des arbres tombent sur les lignes aériennes.
func orage(heures: float, storm: float) -> void:
	for id in r.elec.troncons.keys():
		var e: Dictionary = r.elec.troncons[id]
		if not bool(e.ok) or bool(e.get("hs", false)):
			continue
		var km := ReseauBase.longueur(e.pts) / 1000.0
		if rng.randf() < 0.01 * km * storm * heures:
			provoquer("elec", id, "orage")


## Réparation (l'équipe a fini) : la ville paie.
func reparer(iid: int, mult := 1.0) -> void:
	for i in incidents.size():
		var inc: Dictionary = incidents[i]
		if int(inc.id) != iid:
			continue
		incidents.remove_at(i)
		r.depenser("Réparations des réseaux", float(inc.cout) * mult)
		if String(inc.kind) == "troncon":
			var rs := r.reseau(String(inc.res))
			if rs.troncons.has(int(inc.tid)):
				var e: Dictionary = rs.troncons[int(inc.tid)]
				e.erase("hs")
				e["u"] = minf(float(e.get("u", 1.0)) + 0.1, 1.0)
				if r.vue:
					r.vue.refaire_troncon(String(inc.res), int(inc.tid))
		r._topo_sale = true
		r.message.emit("Réparé : %s." % decrire(inc))
		r.changed.emit()
		return


## Réparation immédiate (heures supplémentaires de l'équipe : le double du prix).
func reparer_vite(iid: int) -> void:
	reparer(iid, 2.0)


## Remet un tronçon à neuf (35 % du prix d'un tronçon neuf).
func renover(res: String, tid: int) -> bool:
	var rs := r.reseau(res)
	if not rs.troncons.has(tid):
		return false
	var e: Dictionary = rs.troncons[tid]
	var prix := roundi(float(ReseauxTypes.prix_troncon(String(e.t), ReseauBase.longueur(e.pts))) * 0.35 * (1.0 - float(e.get("u", 1.0))))
	if r.buildings != null and not r.buildings.unlimited_money and r.buildings.money < prix:
		r.message.emit("Pas assez d'argent pour rénover : %s." % BuildingSystem.format_money(prix))
		return false
	r.depenser("Rénovation des réseaux", float(prix))
	e["u"] = 1.0
	r.changed.emit()
	return true


func prix_renovation(res: String, tid: int) -> int:
	var e: Dictionary = r.reseau(res).troncons.get(tid, {})
	if e.is_empty():
		return 0
	return roundi(float(ReseauxTypes.prix_troncon(String(e.t), ReseauBase.longueur(e.pts))) * 0.35 * (1.0 - float(e.get("u", 1.0))))


func decrire(inc: Dictionary) -> String:
	match String(inc.kind):
		"fuite":
			return "fuite d'eau dans une rue"
		"transfo":
			return "transformateur de quartier (%d bâtiments)" % (inc.bids as Array).size()
	var e: Dictionary = r.reseau(String(inc.res)).troncons.get(int(inc.tid), {})
	return "%s (%s)" % [String(ReseauxTypes.troncon(String(e.get("t", ""))).get("name", "tronçon")).to_lower(), NOMS.get(String(inc.cause), String(inc.cause))]


func de_reseau(res: String) -> Array:
	var out := []
	for inc in incidents:
		if String(inc.res) == res:
			out.append(inc)
	return out


# --- Sauvegarde ----------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var lst := []
	for inc in incidents:
		var d: Dictionary = inc.duplicate()
		d.p = [snappedf(inc.p.x, 0.1), snappedf(inc.p.y, 0.1), snappedf(inc.p.z, 0.1)]
		lst.append(d)
	return {"incidents": lst, "next": _next, "jours_secs": jours_secs, "restrictions": restrictions,
		"canicule": canicule, "pmax": _precip_max, "tmax": _t_max}


func from_dict(d: Dictionary) -> void:
	clear()
	_next = int(d.get("next", 1))
	jours_secs = float(d.get("jours_secs", 0.0))
	secheresse = clampf((jours_secs - JOURS_SECS_DEBUT) / JOURS_SECS_PLEIN, 0.0, 1.0)
	restrictions = bool(d.get("restrictions", false))
	canicule = bool(d.get("canicule", false))
	_precip_max = float(d.get("pmax", 0.0))
	_t_max = float(d.get("tmax", -100.0))
	for x in d.get("incidents", []):
		var inc: Dictionary = x.duplicate()
		var p: Array = inc.get("p", [0, 0, 0])
		inc.p = Vector3(float(p[0]), float(p[1]), float(p[2]))
		inc.id = int(inc.id)
		inc.tid = int(inc.get("tid", -1))
		inc.c = int(inc.get("c", -1))
		var bids := []
		for b in inc.get("bids", []):
			bids.append(int(b))
		inc.bids = bids
		incidents.append(inc)
