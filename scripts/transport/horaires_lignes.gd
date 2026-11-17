class_name HorairesLignes
extends RefCounted
## Horaires des lignes (panneau L, « Horaire ▸ ») : heures de service, cadence,
## fiche horaire et ponctualité.
##
## Une ligne sans horaire roule comme avant : ses véhicules font la navette sans
## s'arrêter la nuit. Avec un horaire :
## - Service : hors des heures choisies, les véhicules restent au terminus
##   (remisés) ; ils ne repartent qu'à la première heure.
## - Cadence : « un départ toutes les N minutes ». Il faut assez de véhicules
##   pour la tenir : besoin = aller-retour ÷ cadence. Les véhicules en trop
##   restent en réserve au terminus ; s'il en manque, la cadence réelle est plus
##   lâche (le panneau le dit).
## - Les départs du terminus sont espacés régulièrement (cadencement) : les
##   véhicules ne se suivent plus en paquets.
## - Les habitants attendent en moyenne une demi-cadence (TransitPlanner).
## - Fiche horaire : prochains passages à chaque arrêt, à l'heure du jeu, d'après
##   les temps de parcours réels (longueur des voies, vitesse du modèle).
## - Ponctualité : chaque arrivée est comparée au temps prévu ; les attentes
##   aux signaux (Signalisation) sont la première cause de retard.
##
## Les heures de la fiche sont des heures « réelles » : à la vitesse de 1 jour
## par minute, un trajet de 10 minutes dure 10 minutes sur la fiche, pas à l'écran.

signal changed

const CADENCES := [2, 3, 5, 10, 15, 20, 30, 45, 60, 90, 120, 180, 240]
const DEBUT := 5.0
const FIN := 24.0
const CADENCE := 30
## Retard toléré (s) pour compter une arrivée « à l'heure ».
const A_L_HEURE := 120.0
## Poids des anciens trajets dans la ponctualité (moyenne glissante).
const OUBLI := 0.98

var stations: StationSystem
## Heure locale imposée (tests) ; négative : l'horloge du jeu.
var heure_forcee := -1.0
var _dern_dep: Dictionary = {}


func _init(s: StationSystem) -> void:
	stations = s


static func defaut() -> Dictionary:
	return {"on": true, "debut": DEBUT, "fin": FIN, "cadence": CADENCE}


func horaire(lid: int) -> Dictionary:
	var l: Dictionary = stations.lines.get(lid, {})
	return l.get("horaire", {})


func actif(lid: int) -> bool:
	return bool(horaire(lid).get("on", false))


## Règle l'horaire d'une ligne (clés on, debut, fin, cadence ; les autres restent).
func regler(lid: int, h: Dictionary) -> void:
	if not stations.lines.has(lid):
		return
	var l: Dictionary = stations.lines[lid]
	var cur: Dictionary = defaut()
	cur.on = false
	cur.merge(l.get("horaire", {}), true)
	cur.merge(h, true)
	cur.debut = clampf(snappedf(float(cur.debut), 0.5), 0.0, 23.5)
	cur.fin = clampf(snappedf(float(cur.fin), 0.5), float(cur.debut) + 0.5, 24.0)
	cur.cadence = clampi(int(cur.cadence), 1, 480)
	l.horaire = cur
	if stations.planner != null:
		stations.planner.invalidate()
	changed.emit()


func heure() -> float:
	if heure_forcee >= 0.0:
		return heure_forcee
	var h: DayNight = EchelleTemps.horloge
	if h != null and is_instance_valid(h):
		return h.local_hour()
	return 12.0


func en_service(lid: int, h := -1.0) -> bool:
	if not actif(lid):
		return true
	if h < 0.0:
		h = heure()
	var hr := horaire(lid)
	return h >= float(hr.debut) and h < float(hr.fin)


## Heures de service par jour (-1 : pas d'horaire).
func heures_service(lid: int) -> float:
	if not actif(lid):
		return -1.0
	var hr := horaire(lid)
	return float(hr.fin) - float(hr.debut)


## Temps de parcours entre arrêts successifs (s), arrêts compris.
func _hops(lid: int) -> Array:
	if stations.planner == null or not stations.lines.has(lid):
		return []
	return stations.planner._line_info(lid).get("hops", [])


## Aller-retour d'un véhicule (s).
func cycle_s(lid: int) -> float:
	var t := 0.0
	for h in _hops(lid):
		t += float(h)
	return t * 2.0


## Véhicules nécessaires pour tenir la cadence.
func besoin(lid: int, cycle := -1.0) -> int:
	if cycle < 0.0:
		cycle = cycle_s(lid)
	var c := float(horaire(lid).get("cadence", CADENCE)) * 60.0
	return maxi(1, ceili(cycle / c - 0.001))


## Véhicules en ligne (les autres sont en réserve).
func en_ligne(lid: int, cycle := -1.0) -> int:
	var n := int(stations.lines.get(lid, {}).get("count", 1))
	return mini(n, besoin(lid, cycle)) if actif(lid) else n


## Intervalle réel entre deux départs (s) : la cadence, ou plus si des véhicules manquent.
func intervalle_s(lid: int, cycle := -1.0) -> float:
	if cycle < 0.0:
		cycle = cycle_s(lid)
	var n := maxf(1.0, float(stations.lines.get(lid, {}).get("count", 1)))
	if not actif(lid):
		return cycle / n
	return maxf(float(horaire(lid).cadence) * 60.0, cycle / n)


# --- Simulation ------------------------------------------------------------------------------

## Fin d'un arrêt (Traffic.line_gate) : secondes d'attente en plus, 0 pour partir.
func porte(v: Dictionary) -> float:
	var lid := int(v.line)
	if not stations.lines.has(lid):
		return 0.0
	var t := stations.traffic.sim_t
	var stops: Array[int] = v.stops
	var terminus: bool = int(v.node) == stops[0] or int(v.node) == stops[stops.size() - 1]
	if actif(lid) and terminus:
		if not en_service(lid):
			v.remise = "nuit"
			return 2.0
		var cycle := cycle_s(lid)
		var n := en_ligne(lid, cycle)
		if _rang(v) >= n:
			v.remise = "reserve"
			return 3.0
		# Départs réguliers : un toutes les (aller-retour ÷ véhicules en ligne).
		var key := "%d:%d" % [lid, int(v.node)]
		var ecart := cycle / float(maxi(n, 1))
		var depuis := t - float(_dern_dep.get(key, -INF))
		if depuis < ecart * 0.97:
			v.remise = "cadence"
			return minf(ecart - depuis, 4.0)
		_dern_dep[key] = t
	v.erase("remise")
	v.dep_t = t
	v.dep_n = int(v.node)
	return 0.0


## Rang du véhicule parmi ceux de sa ligne (les premiers roulent, les autres attendent).
func _rang(v: Dictionary) -> int:
	var r := 0
	for o in stations.traffic.vehicles:
		if o.has("line") and int(o.line) == int(v.line) and int(o.get("uid", 0)) < int(v.get("uid", 0)):
			r += 1
	return r


## Arrivée à un arrêt (Traffic.line_stop) : ponctualité et attentes aux signaux.
func sur_arret(v: Dictionary) -> void:
	var lid := int(v.line)
	if not stations.lines.has(lid) or not v.has("dep_t"):
		return
	var stops: Array[int] = v.stops
	var i_to := int(v.stop_i)
	var i_from := i_to - int(v.step)
	if i_from < 0 or i_from >= stops.size() or stops[i_from] != int(v.get("dep_n", -1)):
		v.erase("dep_t")
		return
	var hops := _hops(lid)
	var k := mini(i_from, i_to)
	if k < 0 or k >= hops.size():
		return
	var prevu := float(hops[k]) - StationSystem.DWELL
	var reel := stations.traffic.sim_t - float(v.dep_t)
	var attente := 0.0
	if v.has("sig"):
		attente = float(v.sig.attente)
		v.sig.attente = 0.0
	var l: Dictionary = stations.lines[lid]
	var p: Array = l.get("ponct", [0.0, 0.0, 0.0, 0.0])
	var retard := maxf(0.0, reel - prevu)
	p = [float(p[0]) * OUBLI + 1.0, float(p[1]) * OUBLI + (1.0 if retard <= A_L_HEURE else 0.0),
		float(p[2]) * OUBLI + retard, float(p[3]) * OUBLI + attente]
	l.ponct = p
	v.erase("dep_t")


## {trajets, ponctualite (0-1), retard (s moyen), signaux (s moyen par trajet)} ou {}.
func ponctualite(lid: int) -> Dictionary:
	var p: Array = stations.lines.get(lid, {}).get("ponct", [])
	if p.size() < 4 or float(p[0]) < 0.5:
		return {}
	var n := float(p[0])
	return {"trajets": n, "ponctualite": float(p[1]) / n, "retard": float(p[2]) / n, "signaux": float(p[3]) / n}


## Véhicules d'une ligne qui attendent au terminus : {"nuit": n, "reserve": n, "cadence": n}.
func remises(lid: int) -> Dictionary:
	var out := {"nuit": 0, "reserve": 0, "cadence": 0}
	for v in stations.traffic.vehicles:
		if v.has("line") and int(v.line) == lid and v.has("remise") and float(v.get("dwell", 0.0)) > 0.0:
			out[String(v.remise)] = int(out.get(String(v.remise), 0)) + 1
	return out


# --- Fiche horaire ---------------------------------------------------------------------------

static func hhmm(h: float) -> String:
	var m := roundi(fposmod(h, 24.0) * 60.0) % 1440
	return "%02d:%02d" % [m / 60, m % 60]


## « 5 h », « 23 h 30 ».
static func heure_txt(h: float) -> String:
	var m := roundi(h * 60.0)
	return "%d h" % (m / 60) if m % 60 == 0 else "%d h %02d" % [m / 60, m % 60]


static func duree(s: float) -> String:
	var m := roundi(s / 60.0)
	if m < 60:
		return "%d min" % maxi(m, 1)
	return "%d h %02d" % [m / 60, m % 60]


## Fiche horaire d'un sens (0 : aller, 1 : retour) : {"titre", "lignes": [[nom, [heures]]]}
## avec les nb prochains départs du terminus à partir de l'heure h.
func fiche(lid: int, sens := 0, nb := 4, h := -1.0) -> Dictionary:
	var l: Dictionary = stations.lines.get(lid, {})
	var hops := _hops(lid)
	if l.is_empty() or hops.is_empty():
		return {}
	if h < 0.0:
		h = heure()
	var ids: Array = (l.stops as Array).duplicate()
	var hs: Array = hops.duplicate()
	if sens == 1:
		ids.reverse()
		hs.reverse()
	var hr: Dictionary = horaire(lid) if actif(lid) else {"debut": 0.0, "fin": 24.0}
	var pas := intervalle_s(lid) / 3600.0
	var debut := float(hr.debut)
	var fin := float(hr.fin)
	var deps: Array = []
	var jour := 0.0
	while deps.size() < nb and jour < 2.0:
		var d := debut
		while d < fin - 0.0001 and deps.size() < nb:
			if d + jour * 24.0 >= h - 0.0001:
				deps.append(d + jour * 24.0)
			d += maxf(pas, 1.0 / 60.0)
		jour += 1.0
	var rows: Array = []
	var cum := 0.0
	for i in ids.size():
		var st: Dictionary = stations.stations.get(int(ids[i]), {})
		var times: Array = []
		for d in deps:
			times.append(hhmm(float(d) + cum / 3600.0))
		rows.append([String(st.get("name", "?")), times])
		if i < hs.size():
			cum += float(hs[i])
	var a: Dictionary = stations.stations.get(int(ids[0]), {})
	var b: Dictionary = stations.stations.get(int(ids[ids.size() - 1]), {})
	return {"titre": "%s → %s" % [a.get("name", "?"), b.get("name", "?")], "lignes": rows}


## Résumé de l'horaire pour le panneau.
func resume(lid: int) -> String:
	var l: Dictionary = stations.lines.get(lid, {})
	if l.is_empty():
		return ""
	var cycle := cycle_s(lid)
	if not actif(lid):
		return "Sans horaire : les véhicules font la navette jour et nuit (un départ toutes les %s environ)." % duree(intervalle_s(lid, cycle))
	var hr := horaire(lid)
	var nom := String(StationSystem.KIND_NAMES.get(String(l.kind), "véhicule")).to_lower()
	var txt := "Un départ toutes les %s, de %s à %s · aller-retour %s · %d nécessaire%s" % [
		duree(float(hr.cadence) * 60.0), heure_txt(float(hr.debut)), heure_txt(float(hr.fin)),
		duree(cycle), besoin(lid, cycle), "s" if besoin(lid, cycle) > 1 else ""]
	var n := int(l.count)
	var need := besoin(lid, cycle)
	if n < need:
		txt += "\nIl manque %d %s : un départ toutes les %s seulement." % [need - n, nom, duree(intervalle_s(lid, cycle))]
	elif n > need:
		txt += " · %d en réserve au terminus" % (n - need)
	if not en_service(lid):
		txt += "\nHors service : reprise à %s." % heure_txt(float(hr.debut))
	return txt

