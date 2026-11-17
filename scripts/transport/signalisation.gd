class_name Signalisation
extends RefCounted
## Signalisation ferroviaire : cantons, voies uniques, évitements et gares.
##
## Un train ne roule que sur la voie qu'il a réservée (son « autorisation de
## marche »). Il la demande morceau par morceau, un peu avant d'en avoir besoin,
## et s'arrête devant le signal tant qu'on la lui refuse :
##
## - Double voie : chaque sens a sa voie, découpée en cantons (un seul train par
##   canton). La longueur des cantons dépend de l'époque (voir EPOQUES).
## - Voie unique : les deux sens partagent la voie. Un train n'y entre que s'il
##   peut la réserver d'un seul coup jusqu'au prochain point de croisement : une
##   gare (deux voies à quai), ou un tronçon à double voie (un évitement). Deux
##   trains ne se retrouvent donc jamais face à face, et ne se bloquent pas.
## - Aiguillages (nœuds où se rejoignent trois voies ou plus) : un seul train à la
##   fois les traverse.
## - Gares : QUAIS_GARE voies à quai ; le deuxième train s'arrête sur la voie d'à
##   côté (décalée de DECALAGE_QUAI).
##
## Le tramway roule « à vue » sur double voie (il suit celui de devant), mais
## respecte les voies uniques et les aiguillages.
##
## Si des trains restent bloqués plus de INTERBLOCAGE secondes (réseau mal
## conçu : trop de trains pour les voies), le plus ancien passe en marche à vue
## jusqu'à sa prochaine gare, et le joueur est prévenu.
##
## Utilisation (Traffic) :
##   limite = signaux.limite(v, vitesse, fantome, dt)   # place libre devant (m)
##   signaux.avance(v, distance)                        # libère derrière le train
##   signaux.liberer(v)                                 # véhicule retiré

signal interblocage(v: Dictionary)

## Arrêt avant un signal (m).
const MARGE := 8.0
## On demande la suite quand il reste la distance de freinage plus ANTICIPE (m).
const ANTICIPE := 80.0
## Nouvel essai après un refus (s).
const RELANCE := 0.5
## Arrêt au signal (s) au-delà duquel le train passe en marche à vue.
const INTERBLOCAGE := 150.0
## Voies à quai d'une gare (et d'une station de métro).
const QUAIS_GARE := 2
## Décalage latéral de la deuxième voie à quai (m).
const DECALAGE_QUAI := 4.5
## Distance (m) sur laquelle le train rejoint sa voie à quai.
const RAMPE_QUAI := 150.0
## Freinage de service (m/s²), comme Traffic.BRAKE.
const FREIN := 4.5
## Au plus, morceaux de voie regardés devant un train.
const MAX_MORCEAUX := 96
## Au plus, distance regardée devant un train (m).
const MAX_DEVANT := 12000.0

## Les époques de la signalisation (année d'arrivée, en France).
## canton : longueur maximale d'un canton sur double voie (INF : de gare à gare).
const EPOQUES := [
	{"des": 0, "id": "disque", "nom": "Disques et garde-voies",
		"canton": INF, "desc": "Espacement des trains par le temps : un seul train entre deux gares ou deux aiguillages, annoncé par un disque tournant et le drapeau du garde-voie."},
	{"des": 1872, "id": "semaphore", "nom": "Sémaphores et block manuel",
		"canton": 3000.0, "desc": "Sémaphores à bras (système Lartigue) : les postes se répondent par télégraphe, cantons de 3 km au plus."},
	{"des": 1935, "id": "bal", "nom": "Block automatique lumineux (BAL)",
		"canton": 1500.0, "desc": "Feux rouges et verts commandés par les circuits de voie : cantons de 1,5 km, les trains se suivent de près."},
]
## Lignes à grande vitesse : signalisation en cabine (TVM) depuis 1981 ; au
## bord de la voie, de simples repères bleus et jaunes.
const TVM_DES := 1981

var network: TransportNetwork
var actif := true
## Callable(nœud: int) -> int : voies à quai à ce nœud (0 : pas une gare).
var quais: Callable
## Année imposée (tests, vitrines) ; 0 : l'année de la partie (Epoques).
var annee_forcee := 0
## Morceaux réservés : clé -> {"uid", "v" (véhicule), "from" (nœud d'entrée), "d0" (odo du début)}.
var tenus: Dictionary = {}
## Voies à quai réservées : nœud -> {voie (int) : uid}.
var quais_tenus: Dictionary = {}
## Compteurs depuis le début de la partie.
var nb_interblocages := 0
## Temps de simulation (s), avancé par Traffic.
var temps := 0.0
var _canton_vu := -1.0


func _init(net: TransportNetwork = null) -> void:
	network = net


# --- Époque --------------------------------------------------------------------------------------

func annee() -> int:
	return annee_forcee if annee_forcee > 0 else Epoques.annee()


## Époque de la signalisation pour une année : un élément de EPOQUES.
static func epoque_pour(y: int) -> Dictionary:
	var best: Dictionary = EPOQUES[0]
	for ep in EPOQUES:
		if y >= int(ep.des):
			best = ep
	return best


func epoque() -> Dictionary:
	return epoque_pour(annee())


## Style des signaux d'un tronçon : disque, semaphore, bal ou tvm.
func style(cls: String) -> String:
	var y := annee()
	if cls == "lgv" and y >= TVM_DES:
		return "tvm"
	return String(epoque_pour(y).id)


func canton_max() -> float:
	return float(epoque().canton)


## Nombre de cantons d'un tronçon à double voie.
func blocs(e: Dictionary) -> int:
	var c := canton_max()
	if c == INF:
		return 1
	return maxi(1, ceili(float(e.len) / c - 0.001))


static func double_voie(e: Dictionary) -> bool:
	return int(TransportTypes.normalize(e.t, e.w).get("tracks", 1)) >= 2


## L'époque a changé la longueur des cantons : toutes les réservations sont refaites.
func verifier_epoque(vehicules: Array) -> void:
	var c := canton_max()
	if _canton_vu < 0.0:
		_canton_vu = c
	elif c != _canton_vu:
		_canton_vu = c
		reset(vehicules)


func _cap(nid: int) -> int:
	return int(quais.call(nid)) if quais.is_valid() else 0


# --- Réservations ----------------------------------------------------------------------------------

## Oublie toutes les réservations (réseau modifié, chargement) : chaque train
## redemande sa voie là où il est.
func reset(vehicules: Array = []) -> void:
	tenus.clear()
	quais_tenus.clear()
	for v in vehicules:
		if (v as Dictionary).has("sig"):
			(v.sig.res as Dictionary).clear()
			v.sig.retry = 0.0


static func _etat(v: Dictionary) -> Dictionary:
	if not v.has("sig"):
		v.sig = {"odo": 0.0, "res": {}, "retry": 0.0, "attente": 0.0, "bloque": false, "force": false, "qn": -1, "qoff": 0.0}
	return v.sig


## Longueur du train, de l'avant de la locomotive à l'arrière de la dernière voiture.
static func longueur(v: Dictionary) -> float:
	return float(v.get("half", 2.0)) + float(v.get("rear", 2.0))


## Morceaux de voie devant le train, depuis sa position, dans l'ordre :
## [{k, d0, e, from, arret, chaine, q, cap}] (d0, e : odomètre du début et de la
## fin ; arret : le train peut s'arrêter au bout ; k vide : voie à vue).
func devant(v: Dictionary) -> Array:
	var out: Array = []
	var sig := _etat(v)
	var route: Array[int] = v.route
	var odo := float(sig.odo)
	var node := int(v.node)
	var acc := odo - float(v.s)
	for i in range(int(v.leg), route.size()):
		var eid: int = route[i]
		if not network.edges.has(eid) or not network.nodes.has(node):
			break
		var e: Dictionary = network.edges[eid]
		var L := float(e.len)
		var forward: bool = int(e.a) == node
		var nxt := int(e.b) if forward else int(e.a)
		if double_voie(e):
			if String(e.t) == "tram":
				out.append({"k": "", "d0": acc, "e": acc + L, "from": node, "arret": true, "chaine": false})
			else:
				var nb := blocs(e)
				var bl := L / float(nb)
				for j in nb:
					var fin := acc + float(j + 1) * bl
					if fin < odo - 0.01:
						continue
					var jj := j if forward else nb - 1 - j
					out.append({"k": "d:%d:%d:%d" % [eid, 0 if forward else 1, jj], "d0": acc + float(j) * bl, "e": fin,
						"from": node, "arret": true, "chaine": false})
		else:
			out.append({"k": "v:%d" % eid, "d0": acc, "e": acc + L, "from": node, "arret": false, "chaine": true})
		acc += L
		var cap := _cap(nxt)
		if cap > 0:
			out.append({"k": "q:%d" % nxt, "q": nxt, "cap": cap, "d0": acc, "e": acc, "from": nxt, "arret": true, "chaine": false})
		elif network.degree(nxt) >= 3:
			out.append({"k": "n:%d" % nxt, "d0": acc, "e": acc, "from": nxt, "arret": false, "chaine": false})
		node = nxt
		if out.size() >= MAX_MORCEAUX or acc - odo > MAX_DEVANT:
			break
	# Voie unique suivie d'une double voie (ou d'une voie à vue) : on peut attendre
	# au bout, l'autre sens passe sur sa propre voie.
	for i in out.size() - 1:
		var u: Dictionary = out[i]
		var w: Dictionary = out[i + 1]
		if bool(u.chaine) and not bool(w.chaine) and not String(w.k).begins_with("n:") and not w.has("q"):
			u.arret = true
	if not out.is_empty():
		(out[out.size() - 1] as Dictionary).arret = true
	return out


func _a_moi(u: Dictionary, uid: int) -> bool:
	if u.has("q"):
		return (quais_tenus.get(int(u.q), {}) as Dictionary).values().has(uid)
	var t: Dictionary = tenus.get(String(u.k), {})
	return not t.is_empty() and int(t.uid) == uid


## Le morceau est-il libre pour ce train ?
func _libre(u: Dictionary, uid: int) -> bool:
	var k := String(u.k)
	if k == "":
		return true
	if u.has("q"):
		var h: Dictionary = quais_tenus.get(int(u.q), {})
		return h.values().has(uid) or h.size() < int(u.cap)
	var t: Dictionary = tenus.get(k, {})
	return t.is_empty() or int(t.uid) == uid


func _prendre(u: Dictionary, v: Dictionary) -> void:
	var k := String(u.k)
	if k == "":
		return
	var sig: Dictionary = v.sig
	var uid := int(v.uid)
	(sig.res as Dictionary)[k] = float(u.e)
	if u.has("q"):
		var nid := int(u.q)
		if not quais_tenus.has(nid):
			quais_tenus[nid] = {}
		var h: Dictionary = quais_tenus[nid]
		if not h.values().has(uid):
			var slot := 0
			while h.has(slot):
				slot += 1
			h[slot] = uid
			sig.qn = nid
			sig.qoff = 0.0 if slot == 0 else DECALAGE_QUAI * (1.0 if slot % 2 == 1 else -1.0) * float((slot + 1) / 2)
		return
	tenus[k] = {"uid": uid, "v": v, "from": int(u.from), "d0": float(u.d0)}


func _rendre(k: String, uid: int) -> void:
	if k.begins_with("q:"):
		var nid := int(k.substr(2))
		var h: Dictionary = quais_tenus.get(nid, {})
		for slot in h.keys():
			if int(h[slot]) == uid:
				h.erase(slot)
		if h.is_empty():
			quais_tenus.erase(nid)
		return
	var t: Dictionary = tenus.get(k, {})
	if not t.is_empty() and int(t.uid) == uid:
		tenus.erase(k)


## Place libre devant l'avant du train (m) d'après la signalisation, INF si
## rien ne l'arrête. fantome : le train est bloqué depuis trop longtemps et passe.
func limite(v: Dictionary, vitesse: float, fantome: bool, dt: float) -> float:
	if not actif:
		return INF
	var sig := _etat(v)
	if fantome:
		if not bool(sig.force):
			sig.force = true
			nb_interblocages += 1
			interblocage.emit(v)
		sig.bloque = false
		return INF
	if bool(sig.force):
		return INF
	var uid := int(v.uid)
	var odo := float(sig.odo)
	var units := devant(v)
	var auth := odo
	var fin_quai := false
	var i := 0
	while i < units.size():
		var u: Dictionary = units[i]
		if String(u.k) == "" or _a_moi(u, uid):
			if String(u.k) != "":
				_prendre(u, v) # rafraîchit la fin (demi-tour en gare)
			auth = float(u.e)
			fin_quai = u.has("q")
			i += 1
			continue
		break
	var besoin := vitesse * vitesse / (2.0 * FREIN) + ANTICIPE
	var refus := false
	while i < units.size() and auth - odo - MARGE < besoin:
		if temps < float(sig.retry):
			refus = true
			break
		var etape: Array = []
		for j in range(i, units.size()):
			etape.append(units[j])
			if bool((units[j] as Dictionary).arret):
				break
		var ok := true
		for u in etape:
			if not _libre(u, uid):
				ok = false
				break
		if not ok:
			sig.retry = temps + RELANCE
			refus = true
			break
		for u in etape:
			_prendre(u, v)
		var der: Dictionary = etape[etape.size() - 1]
		auth = float(der.e)
		fin_quai = der.has("q")
		i += etape.size()
	if i >= units.size():
		sig.bloque = false
		return INF
	# Arrêt au signal : au ras du quai en gare, MARGE avant le signal ailleurs.
	var reste := maxf(0.0, auth - odo - (0.0 if fin_quai else MARGE))
	sig.bloque = refus and reste < 1.0 and vitesse < 0.5
	if bool(sig.bloque):
		sig.attente = float(sig.attente) + dt
	return reste


## Le train a avancé de d mètres : il rend ce qu'il a quitté (arrière passé).
func avance(v: Dictionary, d: float) -> void:
	var sig := _etat(v)
	sig.odo = float(sig.odo) + d
	var res: Dictionary = sig.res
	if res.is_empty():
		return
	var queue := float(sig.odo) - longueur(v) - 2.0
	for k in res.keys():
		if float(res[k]) < queue:
			res.erase(k)
			_rendre(String(k), int(v.uid))


## Arrivée en gare : fin de la marche à vue.
## Arrêté à quai, le train est sur sa voie de gare : la ligne derrière lui est libre.
func arrivee(v: Dictionary) -> void:
	if not v.has("sig"):
		return
	v.sig.force = false
	v.sig.bloque = false
	var res: Dictionary = v.sig.res
	var odo := float(v.sig.odo)
	for k in res.keys():
		var e := float(res[k])
		if e <= odo + 0.5 and not (String(k).begins_with("q:") and e >= odo - 0.5):
			res.erase(k)
			_rendre(String(k), int(v.uid))


## Le véhicule disparaît : il rend toute sa voie.
func liberer(v: Dictionary) -> void:
	if not v.has("sig"):
		return
	for k in (v.sig.res as Dictionary).keys():
		_rendre(String(k), int(v.get("uid", -1)))
	(v.sig.res as Dictionary).clear()


## Décalage latéral (m) du train vers sa voie à quai, près de la gare.
func decalage_quai(v: Dictionary, eid: int) -> float:
	if not v.has("sig") or float(v.sig.qoff) == 0.0 or not network.edges.has(eid):
		return 0.0
	var qn := int(v.sig.qn)
	var e: Dictionary = network.edges[eid]
	var d := INF
	if int(v.node) == qn:
		d = float(v.s)
	elif network.other_end(eid, int(v.node)) == qn:
		d = float(e.len) - float(v.s)
	if d == INF:
		return 0.0
	return float(v.sig.qoff) * clampf(1.0 - d / RAMPE_QUAI, 0.0, 1.0)


# --- Signaux le long des voies --------------------------------------------------------------

## Le nœud n borne-t-il une voie unique (gare, double voie, aiguillage) ?
func _borne(n: int, eid: int) -> bool:
	if _cap(n) > 0 or network.degree(n) >= 3:
		return true
	for o in network.adjacency.get(n, []):
		if int(o) != eid and network.edges.has(o) and double_voie(network.edges[o]):
			return true
	return false


## Signaux à dessiner : [{k, eid, s (depuis le nœud a), dir (1 : vers b), from, style, voies}].
func liste() -> Array:
	var out: Array = []
	for eid in network.edges:
		var e: Dictionary = network.edges[eid]
		if TransportTypes.mode_of(e.t) != TransportTypes.Mode.RAIL or String(e.t) == "tram" or e.has("ch"):
			continue
		if TransportTypes.get_type(e.t).has("underground"):
			continue
		var L := float(e.len)
		if L < 20.0:
			continue
		var st := style(String(e.t))
		if double_voie(e):
			var nb := blocs(e)
			var bl := L / float(nb)
			for fwd in [true, false]:
				for j in nb:
					var jj: int = j if fwd else nb - 1 - j
					var s_trav := float(j) * bl + 6.0
					out.append({"k": "d:%d:%d:%d" % [eid, 0 if fwd else 1, jj], "eid": eid, "s": s_trav if fwd else L - s_trav,
						"dir": 1 if fwd else -1, "from": int(e.a) if fwd else int(e.b), "style": st, "voies": 2})
		else:
			for fwd in [true, false]:
				var n := int(e.a) if fwd else int(e.b)
				if (network.degree(n) < 2 and _cap(n) <= 0) or not _borne(n, eid):
					continue
				out.append({"k": "v:%d" % eid, "eid": eid, "s": 6.0 if fwd else L - 6.0, "dir": 1 if fwd else -1,
					"from": n, "style": st, "voies": 1})
	return out


## État d'un signal : true = voie libre (vert), false = arrêt (rouge).
## Ouvert pour le train qui a réservé la voie depuis ce côté et n'y est pas encore entré.
func ouvert(k: String, from: int) -> bool:
	var t: Dictionary = tenus.get(k, {})
	if t.is_empty():
		return true
	if k.begins_with("v:") and int(t.from) != from:
		return false
	var v: Dictionary = t.v
	return v.has("sig") and float(v.sig.odo) < float(t.d0) - 1.0


# --- Bilan -------------------------------------------------------------------------------------

## Trains arrêtés à un signal en ce moment.
func trains_arretes(vehicules: Array) -> int:
	var n := 0
	for v in vehicules:
		if (v as Dictionary).has("sig") and bool(v.sig.bloque):
			n += 1
	return n


func resume(vehicules: Array = []) -> String:
	var ep := epoque()
	var c := float(ep.canton)
	var txt := "%s (%s)" % [ep.nom, "de gare à gare" if c == INF else "cantons de %s km" % ("%.1f" % (c / 1000.0)).replace(".", ",").replace(",0", "")]
	if annee() >= TVM_DES:
		txt += " · TVM en cabine sur LGV"
	if not vehicules.is_empty():
		var n := trains_arretes(vehicules)
		if n > 0:
			txt += " · %d train%s arrêté%s au signal" % [n, "s" if n > 1 else "", "s" if n > 1 else ""]
	if nb_interblocages > 0:
		txt += " · %d interblocage%s" % [nb_interblocages, "s" if nb_interblocages > 1 else ""]
	return txt
