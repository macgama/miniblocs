class_name EvolutionVoies
extends Node
## Faire évoluer une route posée, sans la démolir : passer de 2 à 4 voies
## (rue → avenue, départementale → route à 2 × 2 voies), changer la largeur
## des voies, mettre ou enlever les trottoirs, ajouter un terre-plein central,
## des couloirs de bus ou une plate-forme de tramway au milieu.
##
## Le tracé, les nœuds et les carrefours ne bougent pas : les bâtiments, leurs
## accès et les réseaux posés sous la route (eau, égouts, électricité) restent
## raccordés. On refuse un élargissement qui toucherait un bâtiment.
##
## Le nouveau profil est posé tout de suite (l'emprise est réservée), puis un
## chantier de requalification (« evolution:<id> ») avance au rythme des
## équipes, payé au fil des travaux : la route reste ouverte, avec une file
## sur deux (Trafic.capacity), des cônes et un rouleau. L'état des travaux est
## gardé dans le tronçon (clé "evo" : h, av, cout), donc dans la sauvegarde.
##
## Tramway : à la fin des travaux, une vraie voie de tram (classe « tram »,
## marquée "sr") est posée dans l'axe de la route, entre les mêmes carrefours :
## on peut y mettre des arrêts de tram et des lignes. sync_tram() la garde
## d'accord avec la route (coupée, démolie, rechargée).

## Prix de référence (France, ordre de grandeur), avant le réglage Admin des coûts.
const PRIX_CHAUSSEE := 130.0 # € / m² de chaussée neuve (élargissement)
const PRIX_DEPOSE := 30.0 # € / m² rendu (rétrécissement)
const PRIX_BORDS := {"trottoir": 90.0, "accotement": 40.0, "aucun": 25.0, "bau": 60.0}
const PRIX_DEPOSE_BORDS := 20.0
const PRIX_TERRE_PLEIN := 70.0
const PRIX_TRAM := 5000.0 # € / m de plate-forme à deux voies (rails, gazon, caténaire)
const PRIX_DEPOSE_TRAM := 600.0
const PRIX_MARQUAGE := 8.0 # € / m de route (signalisation refaite)
## Heures de travail réelles par m² refait, et par m de tram posé.
const HEURES_M2 := 0.1
const HEURES_TRAM := 1.2

static var instance: EvolutionVoies

var transport: TransportSystem
var network: TransportNetwork
var suivi: SuiviChantiers
var trafic: Trafic
## eid -> Node3D (cônes et rouleau)
var _decors := {}
var _sync_en_cours := false


func setup(t: TransportSystem, s: SuiviChantiers, tr: Trafic = null) -> void:
	transport = t
	network = t.network
	suivi = s
	trafic = tr
	instance = self
	network.changed.connect(_sync)
	_sync()


func _exit_tree() -> void:
	if instance == self:
		instance = null


static func cle(eid: int) -> String:
	return "evolution:%d" % eid


func en_travaux(eid: int) -> bool:
	return network.edges.has(eid) and network.edges[eid].has("evo")


# --- Devis ------------------------------------------------------------------------------------

## Ce que coûterait le passage du tronçon eid à la classe t et aux réglages w :
## {ok, reason, cout, heures, avant (m), apres (m), lignes: [String]}.
func devis(eid: int, t: String, w: Dictionary) -> Dictionary:
	var out := {"ok": false, "reason": "", "cout": 0, "heures": 0.0, "avant": 0.0, "apres": 0.0, "lignes": []}
	if not network.edges.has(eid):
		out.reason = "Cette route n'existe plus."
		return out
	var e: Dictionary = network.edges[eid]
	var t0 := String(e.t)
	t = TransportTypes.resolve(t)
	if TransportTypes.mode_of(t0) != TransportTypes.Mode.ROAD:
		out.reason = "Seules les routes peuvent évoluer."
		return out
	if not TransportTypes.evolutions_of(t0).has(t):
		out.reason = "Une %s ne peut pas devenir une %s." % [String(TransportTypes.get_type(t0).name).to_lower(), String(TransportTypes.get_type(t).name).to_lower()]
		return out
	var w0 := TransportTypes.normalize(t0, e.w)
	var w1 := TransportTypes.normalize(t, w)
	out.avant = TransportTypes.width_of(t0, w0)
	out.apres = TransportTypes.width_of(t, w1)
	if t == t0 and w0.hash() == w1.hash():
		out.reason = "Rien ne change."
		return out
	var L := float(e.len)
	var ouvrage := _part_ouvrage(e.st)
	var cout := 0.0
	var m2 := 0.0
	var lignes: Array[String] = []
	# Chaussée (voies et couloirs de bus).
	var ch0 := _chaussee(t0, w0)
	var ch1 := _chaussee(t, w1)
	var d := ch1 - ch0
	if d > 0.01:
		var c := d * L * PRIX_CHAUSSEE * (1.0 + ouvrage * 4.0)
		cout += c
		m2 += d * L
		lignes.append("Chaussée élargie de %s m : %s" % [TransportTypes._num(snappedf(d, 0.05)), _eur(c)])
	elif d < -0.01:
		var c2 := -d * L * PRIX_DEPOSE
		cout += c2
		m2 += -d * L * 0.5
		lignes.append("Chaussée rétrécie de %s m : %s" % [TransportTypes._num(snappedf(-d, 0.05)), _eur(c2)])
	if t != t0 or int(w0.get("lanes", 1)) != int(w1.get("lanes", 1)) or float(w0.get("lane_w", 0)) != float(w1.get("lane_w", 0)) \
			or TransportTypes.bus_of(t0, w0) != TransportTypes.bus_of(t, w1):
		var cm := L * PRIX_MARQUAGE
		cout += cm
		lignes.append("Marquage et panneaux : %s" % _eur(cm))
	# Bords (trottoirs, accotements, bordures).
	var k0 := TransportTypes.side_kind_of(t0, w0)
	var k1 := TransportTypes.side_kind_of(t, w1)
	var s0 := TransportTypes.side_of(t0, w0)
	var s1 := TransportTypes.side_of(t, w1)
	if k0 != k1 or absf(s0 - s1) > 0.01 or absf(d) > 0.01:
		var neuf := 2.0 * s1 * L * float(PRIX_BORDS.get(k1, 40.0))
		var depose := 2.0 * s0 * L * PRIX_DEPOSE_BORDS
		cout += neuf + depose
		m2 += 2.0 * s1 * L
		lignes.append("%s : %s" % [_nom_bords(k1, k0), _eur(neuf + depose)])
	# Terre-plein central.
	var tp0 := TransportTypes.tp_of(t0, w0)
	var tp1 := TransportTypes.tp_of(t, w1)
	if absf(tp1 - tp0) > 0.01:
		var ct := (tp1 * PRIX_TERRE_PLEIN if tp1 > tp0 else tp0 * PRIX_DEPOSE_BORDS) * L
		cout += ct
		m2 += absf(tp1 - tp0) * L
		lignes.append("%s : %s" % ["Terre-plein central de %s m" % TransportTypes._num(tp1) if tp1 > tp0 else "Terre-plein central enlevé", _eur(ct)])
	# Tramway.
	var tr0 := TransportTypes.has_tram(t0, w0)
	var tr1 := TransportTypes.has_tram(t, w1)
	var h_tram := 0.0
	if tr1 and not tr0:
		var raison := Epoques.raison_voie("tram")
		if raison != "":
			out.reason = raison
			return out
		var cr := L * PRIX_TRAM * (1.0 + ouvrage)
		cout += cr
		h_tram = L * HEURES_TRAM
		lignes.append("Plate-forme de tramway à deux voies (%d m) : %s" % [roundi(L), _eur(cr)])
	elif tr0 and not tr1:
		var cd := L * PRIX_DEPOSE_TRAM
		cout += cd
		h_tram = L * HEURES_TRAM * 0.3
		lignes.append("Dépose du tramway : %s" % _eur(cd))
	if t != t0:
		var raison2 := Epoques.raison_voie(t)
		if raison2 != "":
			out.reason = raison2
			return out
	if cout <= 0.0:
		cout = L * PRIX_MARQUAGE
		lignes.append("Réglages et signalisation : %s" % _eur(cout))
	out.cout = ReglagesPartie.prix(roundi(cout))
	out.heures = maxf(8.0, m2 * HEURES_M2 * (1.0 + ouvrage * 4.0) + h_tram)
	out.lignes = lignes
	# Contrôles de la nouvelle emprise : bâtiments et autres voies.
	if out.apres > out.avant + 0.05:
		var gene := _gene(eid, t, w1)
		if gene != "":
			out.reason = gene
			return out
	out.ok = true
	return out


## Largeur des voies de circulation et des couloirs de bus (m).
static func _chaussee(t: String, w: Dictionary) -> float:
	var c := TransportTypes.get_type(t)
	var n := float(w.get("lanes", 1)) * float(w.get("lane_w", 3.0))
	if not c.get("single", false):
		n *= 2.0
	return n + 2.0 * TransportTypes.bus_of(t, w)


static func _part_ouvrage(st: PackedByteArray) -> float:
	if st.is_empty():
		return 0.0
	var n := 0
	for v in st:
		if v == TransportTypes.Struct.BRIDGE or v == TransportTypes.Struct.TUNNEL:
			n += 1
	return float(n) / float(st.size())


static func _nom_bords(k1: String, k0: String) -> String:
	if k1 == k0:
		return "Bords refaits (%s)" % String(TransportTypes.BORDS_NOMS.get(k1, k1)).to_lower()
	match k1:
		"trottoir": return "Trottoirs construits"
		"aucun": return "Trottoirs supprimés (simple bordure)"
		"accotement": return "Accotements à la place des trottoirs" if k0 == "trottoir" else "Accotements refaits"
	return "Bords refaits"


static func _eur(v: float) -> String:
	return BuildingSystem.format_money(ReglagesPartie.prix(roundi(v)))


## Raison qui empêche d'élargir la route (bâtiment, autre voie), ou "".
func _gene(eid: int, t: String, w: Dictionary) -> String:
	var e: Dictionary = network.edges[eid]
	var largeur := TransportTypes.width_of(t, w)
	if transport.blocker.is_valid():
		var n := 0
		for c in RoutePlanner.footprint(largeur, e.pts, e.st):
			if transport.blocker.call(c):
				n += 1
		if n > 0:
			return "Pas assez de place : un bâtiment touche la nouvelle emprise (%s m de large). On ne démolit rien pour élargir." % TransportTypes._num(snappedf(largeur, 0.05))
	# Autres voies trop proches (hors des carrefours de ses deux bouts).
	var hw := largeur * 0.5
	var pts: PackedVector3Array = e.pts
	var st: PackedByteArray = e.st
	var bouts := [network.node_pos(int(e.a)), network.node_pos(int(e.b))]
	var voisins := {}
	for nid in [int(e.a), int(e.b)]:
		for o in network.adjacency.get(nid, []):
			voisins[int(o)] = true
	var pas := maxi(1, pts.size() / 60)
	for i in range(0, pts.size(), pas):
		if st[i] == TransportTypes.Struct.TUNNEL:
			continue
		var p := pts[i]
		for other in transport.edges_near(p, hw + 30.0):
			if other == eid or voisins.has(other):
				continue
			var oe: Dictionary = network.edges[other]
			if bool((oe.w as Dictionary).get("sr", false)) or TransportTypes.mode_of(oe.t) == TransportTypes.Mode.WATER:
				continue
			var h := network.nearest_on_edge(other, p)
			if float(h.dist) >= hw + float(oe.width) * 0.5 - 0.2:
				continue
			var q := network.point_at(other, float(h.s))
			if absf(q.y - p.y) >= TransportSystem.CLEARANCE:
				continue
			var pres := false
			for bp in bouts:
				if Vector2(p.x, p.z).distance_to(Vector2((bp as Vector3).x, (bp as Vector3).z)) < (hw + float(oe.width) * 0.5) * 2.5 + 2.0:
					pres = true
			if pres:
				continue
			return "Pas assez de place : la route élargie toucherait %s." % String(TransportTypes.get_type(oe.t).name).to_lower()
	return ""


# --- Travaux ------------------------------------------------------------------------------------

## Lance l'évolution : nouveau profil tout de suite, chantier payé au fil des
## travaux. Renvoie le devis (ok, reason, cout…).
func lancer(eid: int, t: String, w: Dictionary) -> Dictionary:
	if transport.bloque_reseau() or transport.verrou_reseau:
		return {"ok": false, "reason": "Sur une carte entre amis, les routes n'évoluent pas encore : démolis et repose-la."}
	if network.edges.has(eid):
		var e0: Dictionary = network.edges[eid]
		if e0.has("ch"):
			return {"ok": false, "reason": "Cette route est encore en construction."}
		if e0.has("evo"):
			return {"ok": false, "reason": "Des travaux sont déjà en cours sur cette route."}
	var d := devis(eid, t, w)
	if not d.ok:
		return d
	var e: Dictionary = network.edges[eid]
	t = TransportTypes.resolve(t)
	var neuf := e.duplicate()
	neuf.t = t
	neuf.w = TransportTypes.normalize(t, w)
	TransportNetwork._measure(neuf)
	neuf["evo"] = {"h": snappedf(float(d.heures), 0.01), "av": 0.0, "cout": int(d.cout)}
	# Un nouveau dictionnaire : emprise, carrefours et dessin sont recalculés.
	network.edges[eid] = neuf
	# Couloir de bus construit : plus besoin de prendre une voie aux voitures.
	if trafic != null and TransportTypes.bus_of(t, neuf.w) > 0.0:
		trafic.bus_lanes.erase(eid)
	network.changed.emit()
	transport.message.emit("Travaux lancés : %s (%s), %s." % [String(TransportTypes.get_type(t).name).to_lower(),
		TransportTypes.describe(t, neuf.w), BuildingSystem.format_money(int(d.cout))])
	Son.jouer("pose_route", -3.0, 0.08)
	return d


## Termine tout de suite les travaux en cours (tests, captures).
func finir_tout() -> void:
	for eid in network.edges.keys():
		if network.edges.has(eid) and network.edges[eid].has("evo") and suivi != null:
			suivi.terminer(cle(eid))


## Met les chantiers d'accord avec le réseau (lancés, coupés, démolis, chargés),
## puis les tramways posés dans les routes.
func _sync() -> void:
	if _sync_en_cours:
		return
	_sync_en_cours = true
	if suivi != null:
		for k in suivi.chantiers.keys():
			var ks := String(k)
			if not ks.begins_with("evolution:"):
				continue
			var eid := int(ks.substr(10))
			if not network.edges.has(eid) or not network.edges[eid].has("evo"):
				suivi.annuler(ks)
				_oublier(eid)
		for eid in network.edges.keys():
			var e: Dictionary = network.edges[eid]
			if not e.has("evo") or suivi.en_cours(cle(eid)):
				continue
			var evo: Dictionary = e.evo
			var id: int = eid
			if not _decors.has(id) and ChantiersVoies.instance != null:
				_decors[id] = ChantiersVoies.instance._decor_reparation(id)
			suivi.commencer(cle(id), float(evo.get("h", 8.0)), func(av: float, _et: Array) -> void: _maj(id, av),
				func() -> void: _fini(id), float(evo.get("av", 0.0)), int(evo.get("cout", 0)), Chantiers.ETAPES_VOIE)
	for eid in _decors.keys():
		if not en_travaux(eid):
			_oublier(eid)
	_sync_en_cours = false
	sync_tram()


func _maj(eid: int, av: float) -> void:
	if en_travaux(eid):
		network.edges[eid].evo["av"] = snappedf(av, 0.0001)


func _fini(eid: int) -> void:
	_oublier(eid)
	if not en_travaux(eid):
		return
	var e: Dictionary = network.edges[eid]
	e.erase("evo")
	transport.message.emit("Travaux terminés : %s." % TransportTypes.describe(String(e.t), e.w))
	network.changed.emit()


func _oublier(eid: int) -> void:
	var n: Variant = _decors.get(eid)
	_decors.erase(eid)
	if n != null and is_instance_valid(n):
		(n as Node).queue_free()


# --- Tramway dans la route ------------------------------------------------------------------

## Voie de tram posée dans l'axe de chaque route qui a le tramway (travaux
## finis) ; celles dont la route a changé ou disparu sont enlevées.
func sync_tram() -> void:
	if _sync_en_cours:
		return
	_sync_en_cours = true
	var voulu := {}
	for eid in network.edges:
		var e: Dictionary = network.edges[eid]
		if TransportTypes.mode_of(e.t) == TransportTypes.Mode.ROAD and not e.has("evo") and not e.has("ch") \
				and TransportTypes.has_tram(String(e.t), e.w):
			voulu[_cle_bouts(network.node_pos(int(e.a)), network.node_pos(int(e.b)))] = eid
	var change := false
	var present := {}
	for tid in network.edges.keys():
		var te: Dictionary = network.edges[tid]
		if not bool((te.w as Dictionary).get("sr", false)):
			continue
		var k := _cle_bouts(network.node_pos(int(te.a)), network.node_pos(int(te.b)))
		if voulu.has(k) and not present.has(k):
			present[k] = tid
		else:
			network.remove_edge(tid)
			change = true
	for k in voulu:
		if present.has(k):
			continue
		var e2: Dictionary = network.edges[voulu[k]]
		var na := _noeud_rail(network.node_pos(int(e2.a)))
		var nb := _noeud_rail(network.node_pos(int(e2.b)))
		network.add_edge(na, nb, "tram", (e2.pts as PackedVector3Array).duplicate(), (e2.st as PackedByteArray).duplicate(), {"tracks": 2, "sr": true})
		change = true
	_sync_en_cours = false
	if change:
		network.changed.emit()


static func _cle_bouts(a: Vector3, b: Vector3) -> String:
	var ka := "%d,%d" % [roundi(a.x * 2.0), roundi(a.z * 2.0)]
	var kb := "%d,%d" % [roundi(b.x * 2.0), roundi(b.z * 2.0)]
	return ka + "|" + kb if ka < kb else kb + "|" + ka


## Nœud de rail à cet endroit (celui d'une voie de tram voisine s'il existe).
func _noeud_rail(p: Vector3) -> int:
	for nid in network.nodes:
		if network.node_mode(nid) == TransportTypes.Mode.RAIL and Vector2(p.x, p.z).distance_to(Vector2(network.node_pos(nid).x, network.node_pos(nid).z)) < 0.6:
			return nid
	return network.add_node(p, TransportTypes.Mode.RAIL)


## Voie de tram posée dans la route eid (-1 sans).
func tram_de(eid: int) -> int:
	if not network.edges.has(eid):
		return -1
	var e: Dictionary = network.edges[eid]
	var k := _cle_bouts(network.node_pos(int(e.a)), network.node_pos(int(e.b)))
	for tid in network.edges:
		var te: Dictionary = network.edges[tid]
		if bool((te.w as Dictionary).get("sr", false)) and _cle_bouts(network.node_pos(int(te.a)), network.node_pos(int(te.b))) == k:
			return tid
	return -1
