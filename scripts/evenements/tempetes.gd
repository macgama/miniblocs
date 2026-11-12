class_name Tempetes
extends RefCounted
## Tempêtes : vent violent et orage pendant quelques heures.
##
## - Au hasard (réglage Admin), plus souvent quand la météo tourne à l'orage,
##   ou à la main (panneau Infos). La météo passe en « Orage » le temps de la
##   tempête, puis revient comme avant.
## - Arbres tombés qui bloquent les routes (les itinéraires les contournent)
##   jusqu'à ce que les pompiers les dégagent.
## - Toits abîmés : bâches bleues, dégâts à réparer.
## - Coupures d'électricité par quartier : fenêtres et lampadaires éteints.
## - Inondations le long des rivières proches de la ville : eau qui monte,
##   routes coupées, bâtiments bas abîmés, puis décrue.
## - La foudre peut mettre le feu à un bâtiment.

const RISQUE_JOUR := 1.0 / 45.0
const ARBRES_MAX := 6
const PANNE_RAYON := 260.0
const CRUE_DISTANCE := 1200.0

var ev: Evenements
## Arbres tombés : incident id -> {eid, node}
var arbres: Dictionary = {}
var _mode_avant := -1
var _acc := 0.0


func _init(e: Evenements) -> void:
	ev = e


func clear() -> void:
	for k in arbres:
		var a: Dictionary = arbres[k]
		if a.get("node") != null and is_instance_valid(a.node):
			(a.node as Node).queue_free()
		if ev.transport != null:
			ev.transport.network.closed_edges.erase(int(a.eid))
	arbres.clear()


func roll_day(n: Dictionary) -> void:
	if ev.buildings == null or ev.buildings.buildings.size() < 5:
		return
	if not ev.en_cours("tempete").is_empty() or not ev.prevus("tempete").is_empty():
		return
	var p := RISQUE_JOUR * ev.frequence()
	# Saisons des tempêtes (automne, hiver) et des orages (été).
	if int(n.month) in [10, 11, 12, 1, 2]:
		p *= 1.6
	if ev.ambiance != null and ev.ambiance.weather != null and ev.ambiance.weather.storm > 0.4:
		p *= 4.0
	if ev.rng.randf() < p:
		var h := ev.rng.randf_range(10.0, 20.0)
		start(ev.unix_at(int(n.day), h), ev.rng.randf_range(3.0, 6.0), true)


## Prévoit une tempête à l'instant debut, pour `heures` heures.
func start(debut: float, heures: float, auto: bool) -> int:
	for e in ev.en_cours("tempete"):
		return int(e.id)
	var id := ev.ajouter("tempete", "Tempête", debut, debut + heures * 3600.0, ev.building_pos(_centre_ville()), -1,
		{"arbres": 0, "toits": 0, "pannes": [], "crue": [], "niveau": 0.0, "fin_crue": 0.0, "foudre": 0}, auto)
	if debut > ev.now() + 60.0:
		ev.news("Alerte météo : tempête attendue %s." % ev.heure_texte(debut), Vector3.INF, "tempete", id)
	return id


func _centre_ville() -> int:
	var keys := ev.buildings.buildings.keys()
	if keys.is_empty():
		return -1
	var sum := Vector3.ZERO
	for bid in keys:
		sum += ev.building_pos(bid)
	sum /= keys.size()
	var best := -1
	var bd := INF
	for bid in keys:
		var d := ev.building_pos(bid).distance_to(sum)
		if d < bd:
			bd = d
			best = bid
	return best


func on_start(e: Dictionary) -> void:
	var w: Meteo = ev.ambiance.weather if ev.ambiance != null else null
	if w != null:
		_mode_avant = int(w.mode)
		w.mode = Meteo.Mode.ORAGE
	e.data.mode_avant = _mode_avant
	ev.news("Tempête sur la ville : vent violent et orages !", e.pos, "tempete", int(e.id))
	_prepare_crue(e)


func on_end(e: Dictionary) -> void:
	var w: Meteo = ev.ambiance.weather if ev.ambiance != null else null
	var before := int(e.data.get("mode_avant", _mode_avant))
	if w != null and int(w.mode) == Meteo.Mode.ORAGE:
		w.mode = (before if before >= 0 else Meteo.Mode.AUTO) as Meteo.Mode
	# Courant rétabli.
	for bid in e.data.get("panne_bats", []):
		ev.set_panne(int(bid), false)
	_set_dark([])
	var d: Dictionary = e.data
	ev.news("Fin de la tempête : %d arbre%s tombé%s, %d toit%s abîmé%s%s." % [int(d.arbres), "s" if int(d.arbres) > 1 else "",
		"s" if int(d.arbres) > 1 else "", int(d.toits), "s" if int(d.toits) > 1 else "", "s" if int(d.toits) > 1 else "",
		", crue en cours de décrue" if float(d.get("niveau", 0.0)) > 0.0 else ""], e.pos, "tempete", int(e.id))
	if float(d.get("niveau", 0.0)) > 0.0:
		# L'eau redescend en quelques heures après la tempête.
		_decrue(e)


## Effets de la tempête, toutes les 10 minutes de jeu.
func step(dt: float, t: float) -> void:
	_step_crues(t)
	var list := ev.en_cours("tempete")
	if list.is_empty():
		return
	_acc += dt
	if _acc < 600.0:
		return
	var steps := mini(int(_acc / 600.0), 6)
	_acc = fmod(_acc, 600.0)
	for e in list:
		for i in steps:
			_effets(e, t)


func _effets(e: Dictionary, t: float) -> void:
	var d: Dictionary = e.data
	var dur := maxf(float(e.fin) - float(e.debut), 3600.0)
	var p_step := 600.0 / dur
	# (a) Arbres tombés sur les routes.
	if int(d.arbres) < ARBRES_MAX and ev.rng.randf() < p_step * 4.0:
		if _arbre(e):
			d.arbres = int(d.arbres) + 1
	# (b) Toits abîmés.
	if ev.rng.randf() < p_step * 6.0:
		var keys := ev.buildings.buildings.keys()
		if not keys.is_empty():
			var bid: int = keys[ev.rng.randi() % keys.size()]
			var tt := BuildingCatalog.get_type(String(ev.buildings.buildings[bid].t))
			if not tt.has("glb") and String(tt.get("cat", "")) != "espaces" and not ev.buildings.en_chantier(bid):
				var old := float(ev.degats.get(bid, {}).get("d", 0.0))
				ev.set_degats(bid, old + ev.rng.randf_range(0.08, 0.25), "tempete", true)
				d.toits = int(d.toits) + 1
				if int(d.toits) <= 3:
					ev.news("Toit arraché : %s." % ev.building_name(bid), ev.building_pos(bid), "tempete", int(e.id))
	# (c) Coupure d'électricité dans un quartier.
	if (d.pannes as Array).size() < 2 and ev.rng.randf() < p_step * 2.0:
		_panne(e)
	# (d) La foudre.
	if int(d.foudre) < 1 and ev.rng.randf() < p_step * 0.6:
		var keys2 := ev.buildings.buildings.keys()
		if not keys2.is_empty():
			var bid2: int = keys2[ev.rng.randi() % keys2.size()]
			if ev.incendies.start_fire(bid2, "foudre") >= 0:
				d.foudre = 1
	# Crue : l'eau monte pendant la tempête.
	if not (d.crue as Array).is_empty():
		d.niveau = minf(float(d.niveau) + 0.25, float(d.get("niveau_max", 1.2)))
		_update_crue(e, t)


# --- Arbres sur la route -------------------------------------------------------------------

func _arbre(e: Dictionary) -> bool:
	if ev.transport == null:
		return false
	var net := ev.transport.network
	var c := ev.building_pos(_centre_ville())
	var cand := []
	for eid in net.edges:
		var ed: Dictionary = net.edges[eid]
		if TransportTypes.mode_of(String(ed.t)) != TransportTypes.mode_of("departementale") or net.closed_edges.has(eid):
			continue
		if float(ed.len) < 20.0:
			continue
		var mid := net.point_at(eid, float(ed.len) * 0.5)
		if mid.distance_to(c) < 1500.0:
			cand.append(eid)
	if cand.is_empty():
		return false
	var eid: int = cand[ev.rng.randi() % cand.size()]
	var ed2: Dictionary = net.edges[eid]
	var s := float(ed2.len) * ev.rng.randf_range(0.25, 0.75)
	var p := net.point_at(eid, s)
	var tg := net.tangent_at(eid, s)
	var node := EvVisuels.arbre_tombe(eid)
	node.position = p
	# En travers de la chaussée.
	node.rotation.y = atan2(-tg.z, tg.x) + PI / 2.0 + ev.rng.randf_range(-0.3, 0.3)
	ev.visuels.add_child(node)
	net.closed_edges[eid] = "arbre"
	ev.reroute()
	var inc := ev.declarer({"type": "arbre", "position": p, "batiment": -1, "gravite": 1, "besoin": ["pompiers"],
		"role": "arbre", "ev": int(e.id), "texte": "Arbre tombé sur la route"})
	arbres[inc] = {"eid": eid, "node": node}
	ev.news("Un arbre est tombé sur la route : elle est coupée.", p, "tempete", int(e.id))
	return true


func on_resolu(inc: Dictionary) -> void:
	var id := int(inc.id)
	if String(inc.get("role", "")) == "arbre" and arbres.has(id):
		var a: Dictionary = arbres[id]
		if a.get("node") != null and is_instance_valid(a.node):
			(a.node as Node).queue_free()
		if ev.transport != null:
			ev.transport.network.closed_edges.erase(int(a.eid))
			ev.reroute()
		arbres.erase(id)
		ev.news("Route dégagée : l'arbre tombé a été enlevé.", inc.position, "tempete")


# --- Coupures d'électricité ------------------------------------------------------------------

func _panne(e: Dictionary) -> void:
	var keys := ev.buildings.buildings.keys()
	if keys.is_empty():
		return
	var center := ev.building_pos(keys[ev.rng.randi() % keys.size()])
	var bats: Array = e.data.get("panne_bats", [])
	var n := 0
	for bid in keys:
		if ev.building_pos(bid).distance_to(center) < PANNE_RAYON:
			ev.set_panne(bid, true)
			if not bats.has(bid):
				bats.append(bid)
				n += 1
	e.data.panne_bats = bats
	(e.data.pannes as Array).append(Evenements.v3(center))
	var zones := []
	for z in e.data.pannes:
		zones.append(Evenements.to_v3(z))
	_set_dark(zones)
	ev.news("Coupure de courant : %d bâtiment%s dans le noir." % [n, "s" if n > 1 else ""], center, "tempete", int(e.id))


func _set_dark(zones: Array) -> void:
	if ev.ambiance == null or ev.ambiance.street == null:
		return
	var sl: StreetLights = ev.ambiance.street
	sl.dark_zones.clear()
	for z in zones:
		sl.dark_zones.append(Vector4(z.x, z.y, z.z, PANNE_RAYON))


# --- Inondations ---------------------------------------------------------------------------

## Tronçons de rivière près de la ville (au niveau de l'eau).
func _prepare_crue(e: Dictionary) -> void:
	var wm: WaterMap = ev.world.water if ev.world != null else null
	if wm == null or wm.seg_a.is_empty():
		return
	var pts := []
	for bid in ev.buildings.buildings:
		pts.append(ev.building_pos(bid))
	if pts.is_empty():
		return
	var segs := []
	for i in wm.seg_a.size():
		if wm.seg_w[i] < 3.0:
			continue
		var a := wm.seg_a[i]
		var b := wm.seg_b[i]
		var mid := (a + b) * 0.5
		var near := false
		for p in pts:
			if Vector2(p.x, p.z).distance_to(mid) < CRUE_DISTANCE:
				near = true
				break
		if near:
			var ya := ev.ground(a.x, a.y)
			var yb := ev.ground(b.x, b.y)
			segs.append([[a.x, ya, a.y], [b.x, yb, b.y], wm.seg_w[i]])
			if segs.size() >= 400:
				break
	if segs.is_empty():
		return
	e.data.crue = segs
	e.data.niveau_max = ev.rng.randf_range(0.8, 1.8)
	ev.news("Les rivières montent : risque d'inondation.", Vector3(segs[0][0][0], segs[0][0][1], segs[0][0][2]), "tempete", int(e.id))


## Nappe d'eau, routes coupées et bâtiments inondés selon le niveau.
func _update_crue(e: Dictionary, _t: float) -> void:
	var d: Dictionary = e.data
	var level := float(d.niveau)
	var node = e.get("crue_node", null)
	if node != null and is_instance_valid(node):
		(node as Node).queue_free()
	var segs := []
	var half := 0.0
	for s in d.crue:
		var a := Vector3(float(s[0][0]), float(s[0][1]) + level, float(s[0][2]))
		var b := Vector3(float(s[1][0]), float(s[1][1]) + level, float(s[1][2]))
		segs.append([a, b])
		half = maxf(half, float(s[2]) * 0.5)
	var spread := half + 6.0 + level * 18.0
	var mi := EvVisuels.nappe(segs, spread)
	ev.visuels.add_child(mi)
	e.crue_node = mi
	# Bâtiments bas au bord de l'eau.
	var hit := 0
	var inondes: Array = d.get("inondes", [])
	for bid in ev.buildings.buildings.keys():
		if inondes.has(bid):
			continue
		var p := ev.building_pos(bid)
		for s in segs:
			var a: Vector3 = s[0]
			var b: Vector3 = s[1]
			var q := Geometry3D.get_closest_point_to_segment(Vector3(p.x, 0, p.z), Vector3(a.x, 0, a.z), Vector3(b.x, 0, b.z))
			if q.distance_to(Vector3(p.x, 0, p.z)) < spread and p.y < lerpf(a.y, b.y, 0.5) + 0.2:
				inondes.append(bid)
				var old := float(ev.degats.get(bid, {}).get("d", 0.0))
				ev.set_degats(bid, old + ev.rng.randf_range(0.15, 0.4), "inondation")
				hit += 1
				break
	d.inondes = inondes
	if hit > 0 and not d.has("inc_crue"):
		var p0: Vector3 = segs[0][0]
		d.inc_crue = ev.declarer({"type": "inondation", "position": p0, "batiment": -1, "gravite": clampi(1 + hit / 4, 1, 3),
			"besoin": ["pompiers"], "role": "inondation", "ev": int(e.id), "texte": "Inondation"})
		ev.news("Inondation : %d bâtiment%s les pieds dans l'eau." % [hit, "s" if hit > 1 else ""], p0, "tempete", int(e.id))
	# Routes sous l'eau : coupées.
	if ev.transport != null:
		var net := ev.transport.network
		var closed: Array = d.get("routes", [])
		for eid in net.edges:
			if net.closed_edges.has(eid):
				continue
			var mid := net.point_at(eid, float(net.edges[eid].len) * 0.5)
			for s in segs:
				var a2: Vector3 = s[0]
				var b2: Vector3 = s[1]
				var q2 := Geometry3D.get_closest_point_to_segment(Vector3(mid.x, 0, mid.z), Vector3(a2.x, 0, a2.z), Vector3(b2.x, 0, b2.z))
				if q2.distance_to(Vector3(mid.x, 0, mid.z)) < spread * 0.8 and mid.y < a2.y and net.struct_at(eid, float(net.edges[eid].len) * 0.5) == 0:
					net.closed_edges[eid] = "inondation"
					closed.append(eid)
					break
		d.routes = closed
		if not closed.is_empty():
			ev.reroute()


## Décrue : l'eau baisse en 6 heures après la tempête.
func _decrue(e: Dictionary) -> void:
	e.data.fin_crue = ev.now() + 6.0 * 3600.0
	_crues[int(e.id)] = e


var _crues := {}


func _step_crues(t: float) -> void:
	for id in _crues.keys():
		var e: Dictionary = _crues[id]
		var d: Dictionary = e.data
		var left := float(d.fin_crue) - t
		if left <= 0.0:
			var node = e.get("crue_node", null)
			if node != null and is_instance_valid(node):
				(node as Node).queue_free()
			if ev.transport != null:
				for eid in d.get("routes", []):
					if String(ev.transport.network.closed_edges.get(int(eid), "")) == "inondation":
						ev.transport.network.closed_edges.erase(int(eid))
				ev.reroute()
			d.niveau = 0.0
			_crues.erase(id)
			if d.has("inc_crue") and not ev.incident(int(d.inc_crue)).is_empty() and String(ev.incident(int(d.inc_crue)).etat) != "resolu":
				ev.resoudre(int(d.inc_crue))
			ev.news("Fin de l'inondation : l'eau est redescendue.", Vector3.INF, "tempete", int(id))
			continue
		var node2 = e.get("crue_node", null)
		if node2 != null and is_instance_valid(node2):
			var k := clampf(left / (6.0 * 3600.0), 0.0, 1.0)
			(node2 as Node3D).position.y = -float(d.niveau) * (1.0 - k)
			(node2 as Node3D).scale = Vector3(1.0, 1.0, 1.0)


func niveau_crue() -> float:
	var best := 0.0
	for e in ev.en_cours("tempete"):
		best = maxf(best, float(e.data.get("niveau", 0.0)))
	for id in _crues:
		best = maxf(best, float(_crues[id].data.get("niveau", 0.0)))
	return best
