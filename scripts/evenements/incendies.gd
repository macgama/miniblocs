class_name Incendies
extends RefCounted
## Incendies.
##
## - Départ de feu au hasard (réglage Admin « catastrophes ») : plus souvent dans
##   l'industrie, les vieux bâtiments et en hiver (cheminées), par la foudre
##   pendant une tempête ; ou à la main (panneau Infos, I, puis clic).
## - Le feu grandit tant que les pompiers ne sont pas là, abîme le bâtiment, et
##   s'étend aux voisins proches quand il est fort (comme dans la vraie vie).
## - Les pompiers sur place (incident « pris ») font baisser le feu ; une fois
##   l'incident résolu, il est éteint. Restent des dégâts à réparer (suie), ou
##   une ruine à reconstruire si le bâtiment a entièrement brûlé.
## - Un événement « incendie » regroupe tous les bâtiments touchés par le même
##   feu, et un seul incident pour les secours (gravité = étendue du feu).

## Probabilité de départ de feu par bâtiment et par jour (fréquence normale).
const RISQUE_JOUR := 1.0 / 5000.0
## Croissance du feu sans pompiers (par heure de jeu) et dégâts (par heure, à plein feu).
const CROISSANCE := 0.9
const DEGATS_H := 0.45
## Les pompiers font baisser le feu de tant par heure.
const EXTINCTION := 1.6
## Distance (m) entre deux bâtiments pour que le feu passe de l'un à l'autre.
const PORTEE := 6.0
const PROPAGATION_H := 0.3

var ev: Evenements
## bid -> {ev, i (intensité 0 à 1), d0 (dégâts au départ), node}
var feux: Dictionary = {}


func _init(e: Evenements) -> void:
	ev = e


func brule(bid: int) -> bool:
	return feux.has(bid)


func oublie(bid: int) -> void:
	if feux.has(bid):
		var f: Dictionary = feux[bid]
		if f.get("node") != null and is_instance_valid(f.node):
			(f.node as Node).queue_free()
		feux.erase(bid)
		var e: Dictionary = ev.events.get(int(f.ev), {})
		if not e.is_empty():
			(e.data.batiments as Array).erase(bid)


## Tirage du jour : départs de feu au hasard.
func roll_day(n: Dictionary) -> void:
	if ev.buildings == null:
		return
	var winter := int(n.month) in [11, 12, 1, 2, 3]
	var f := ev.frequence()
	for bid in ev.buildings.buildings.keys():
		var b: Dictionary = ev.buildings.buildings[bid]
		if b.get("chantier", false) or feux.has(bid):
			continue
		var p := RISQUE_JOUR * f * _facteur(b, winter)
		# Détecteurs de fumée obligatoires dans le quartier.
		if Quartiers.instance != null and Quartiers.instance.en_vigueur("detecteurs_fumee"):
			p *= Quartiers.instance.facteur_feu(ev.building_pos(bid))
		if ev.rng.randf() < p:
			# À une heure au hasard du jour : on démarre maintenant, c'est plus simple à suivre.
			start_fire(bid, "hasard")


func _facteur(b: Dictionary, winter: bool) -> float:
	var t := BuildingCatalog.get_type(String(b.t))
	var cat := String(t.get("cat", ""))
	var k := 1.0
	if cat == "industrie" or cat == "production":
		k *= 3.0
	if int(t.get("logements", 0)) > 0 and winter:
		k *= 1.6
	if t.has("stade") or cat == "espaces":
		k *= 0.1
	return k


func start_random() -> int:
	var list := []
	for bid in ev.buildings.buildings:
		var b: Dictionary = ev.buildings.buildings[bid]
		if not b.get("chantier", false) and not feux.has(bid) and String(BuildingCatalog.get_type(String(b.t)).get("cat", "")) != "espaces":
			list.append(bid)
	if list.is_empty():
		ev.buildings.message.emit("Aucun bâtiment où déclencher un incendie.")
		return -1
	return start_fire(list[ev.rng.randi() % list.size()], "manuel")


## Feu dans un bâtiment. Renvoie l'id de l'événement (nouveau ou celui du feu voisin).
func start_fire(bid: int, cause := "hasard", into := -1) -> int:
	if not ev.buildings.buildings.has(bid) or feux.has(bid):
		return -1
	if ev.buildings.en_chantier(bid):
		return -1
	var pos := ev.building_pos(bid)
	var id := into
	if id < 0 or not ev.events.has(id):
		var name := ev.building_name(bid)
		id = ev.ajouter("incendie", "Incendie : %s" % name, ev.now(), 0.0, pos, bid, {"batiments": [], "cause": cause, "detruits": 0})
		var e: Dictionary = ev.events[id]
		e.etat = "en_cours"
		var besoin := ["pompiers"]
		if _occupants(bid) > 0:
			besoin.append("ambulance")
		var inc := ev.declarer({"type": "incendie", "position": pos, "batiment": bid, "gravite": 1, "besoin": besoin,
			"role": "feu", "ev": id, "texte": "Incendie : %s" % name})
		e.data.inc = inc
		var why := " (foudre)" if cause == "foudre" else ""
		ev.news("Incendie%s : %s ! Les pompiers sont appelés." % [why, name], pos, "incendie", id)
	var e2: Dictionary = ev.events[id]
	(e2.data.batiments as Array).append(bid)
	var d0 := float(ev.degats.get(bid, {}).get("d", 0.0))
	feux[bid] = {"ev": id, "i": 0.25, "d0": d0, "node": _feu_node(bid)}
	if into >= 0:
		var n := (e2.data.batiments as Array).size()
		ev.aggraver(int(e2.data.inc), 1 + n / 2)
		ev.news("Le feu gagne %s." % ev.building_name(bid), pos, "incendie", id)
	return id


func _occupants(bid: int) -> int:
	if ev.population == null:
		return 0
	return (ev.population.present_in(bid) as Array).size() if ev.population.known.has(bid) else 0


func _feu_node(bid: int) -> Node3D:
	var mi := ev.buildings.node_of(bid)
	var size := Vector3(10, 8, 10)
	if mi != null and mi.mesh != null:
		size = mi.mesh.get_aabb().size
	var node := EvVisuels.feu(Vector3(minf(size.x, 40.0), minf(size.y, 30.0), minf(size.z, 40.0)))
	node.position = ev.building_pos(bid)
	ev.visuels.add_child(node)
	return node


## Le feu avance (dt en secondes de jeu, déjà limité).
func step(dt: float) -> void:
	if feux.is_empty() or dt <= 0.0:
		return
	var h := dt / 3600.0
	var spread := []
	var tempete := not ev.en_cours("tempete").is_empty()
	for bid in feux.keys():
		if not feux.has(bid):
			continue
		var f: Dictionary = feux[bid]
		var e: Dictionary = ev.events.get(int(f.ev), {})
		var inc := ev.incident(int(e.get("data", {}).get("inc", -1))) if not e.is_empty() else {}
		var pris := not inc.is_empty() and String(inc.etat) == "pris"
		if pris:
			f.i = maxf(float(f.i) - EXTINCTION * h * _pression(bid), 0.05)
		else:
			f.i = minf(float(f.i) + CROISSANCE * h * (1.4 if tempete else 1.0), 1.0)
		var d := float(ev.degats.get(bid, {}).get("d", f.d0)) + DEGATS_H * float(f.i) * h * (0.4 if pris else 1.0)
		if f.node != null and is_instance_valid(f.node):
			EvVisuels.regle_feu(f.node, float(f.i))
		if d >= 1.0:
			var evid := int(f.ev)
			oublie(bid)
			if not e.is_empty():
				e.data.detruits = int(e.data.get("detruits", 0)) + 1
			ev.detruire(bid, "incendie")
			_maybe_end(evid)
			continue
		ev.degats[bid] = {"d": d, "cause": "incendie", "bache": bool(ev.degats.get(bid, {}).get("bache", false))}
		ev._apply_look(bid)
		# Propagation aux voisins quand le feu est fort et que personne ne l'arrose.
		if not pris and float(f.i) > 0.55:
			for nb in _voisins(bid):
				if not feux.has(nb) and ev.rng.randf() < PROPAGATION_H * h * float(f.i) * (2.0 if tempete else 1.0):
					spread.append([nb, int(f.ev)])
	for s in spread:
		start_fire(int(s[0]), "propagation", int(s[1]))


## Eau aux bouches d'incendie (groupe "eau_incendie", 1 = normale) : sans eau,
## les pompiers n'ont que la citerne de leurs camions et éteignent trois fois moins vite.
func _pression(bid: int) -> float:
	if not ev.is_inside_tree():
		return 1.0
	var e := 1.0
	for n in ev.get_tree().get_nodes_in_group("eau_incendie"):
		if n.has_method("eau_incendie"):
			e = minf(e, clampf(float(n.eau_incendie(bid)), 0.0, 1.0))
	return lerpf(0.35, 1.0, e)


## Bâtiments à moins de PORTEE mètres (bords des emprises).
func _voisins(bid: int) -> Array:
	var out := []
	var b: Dictionary = ev.buildings.buildings.get(bid, {})
	if b.is_empty():
		return out
	var r := ev.buildings._rect_of(b).grow(int(PORTEE))
	var seen := {}
	for x in range(r.position.x, r.end.x, 2):
		for z in range(r.position.y, r.end.y, 2):
			var o := ev.buildings.building_at(Vector2i(x, z))
			if o >= 0 and o != bid and not seen.has(o):
				seen[o] = true
				var t := BuildingCatalog.get_type(String(ev.buildings.buildings[o].t))
				if String(t.get("cat", "")) != "espaces" and not ev.buildings.en_chantier(o):
					out.append(o)
	return out


func _maybe_end(evid: int) -> void:
	var e: Dictionary = ev.events.get(evid, {})
	if e.is_empty():
		return
	if not (e.data.batiments as Array).is_empty():
		return
	# Plus rien ne brûle (tout a brûlé) : l'incident est clos.
	var inc := int(e.data.get("inc", -1))
	if not ev.incident(inc).is_empty() and String(ev.incident(inc).etat) != "resolu":
		ev.resoudre(inc)
	else:
		_close(e)


## Les pompiers ont fini : le feu est éteint, les dégâts restent.
func on_resolu(inc: Dictionary) -> void:
	var evid := int(inc.get("ev", -1))
	var e: Dictionary = ev.events.get(evid, {})
	if e.is_empty():
		return
	for bid in (e.data.batiments as Array).duplicate():
		var f: Dictionary = feux.get(bid, {})
		if f.get("node") != null and is_instance_valid(f.node):
			EvVisuels.fumee_seule(f.node)
			var n: Node = f.node
			n.get_tree().create_timer(25.0).timeout.connect(func() -> void:
				if is_instance_valid(n):
					n.queue_free())
		feux.erase(bid)
	_close(e)


func _close(e: Dictionary) -> void:
	if String(e.etat) == "fini":
		return
	var bats: Array = []
	for bid in ev.degats:
		if String(ev.degats[bid].cause) == "incendie":
			bats.append(bid)
	var detruits := int(e.data.get("detruits", 0))
	var txt := "Incendie éteint"
	if detruits > 0:
		txt += " : %d bâtiment%s détruit%s" % [detruits, "s" if detruits > 1 else "", "s" if detruits > 1 else ""]
	var touch := 0
	for bid in ev.degats:
		if String(ev.degats[bid].cause) == "incendie":
			touch += 1
	if touch > 0:
		txt += "%s %d bâtiment%s à réparer (panneau Infos)" % [" ;" if detruits > 0 else " :", touch, "s" if touch > 1 else ""]
	ev.news(txt + ".", e.pos, "incendie", int(e.id))
	e.data.batiments = []
	ev.finir(int(e.id))


## Partie rechargée : les bâtiments encore en feu reprennent.
func restore(e: Dictionary) -> void:
	var list: Array = e.data.get("batiments", [])
	var keep := []
	for v in list:
		var bid := int(v)
		if ev.buildings.buildings.has(bid):
			keep.append(bid)
			feux[bid] = {"ev": int(e.id), "i": 0.5, "d0": float(ev.degats.get(bid, {}).get("d", 0.0)), "node": _feu_node(bid)}
	e.data.batiments = keep
	e.data.inc = int(e.data.get("inc", -1))
	e.data.detruits = int(e.data.get("detruits", 0))
