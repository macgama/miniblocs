class_name Urgences
extends Node3D
## Services d'urgence : pompiers, ambulances (SAMU, VSAV) et police qui partent
## de leur caserne, de l'hôpital ou du commissariat et roulent vraiment sur les
## routes (Traffic), gyrophares et sirène allumés.
##
## - Les appels viennent des événements de la ville (autoload /root/Evenements :
##   incendies, épidémies, accidents) et de petits appels au hasard (malaise,
##   chute, accident, cambriolage, feu de poubelle), d'autant plus nombreux que
##   la ville est peuplée.
## - Chaque bâtiment de service a sa flotte (FLEETS). Un véhicule ne part que si
##   son équipage est de garde aujourd'hui (employés du bâtiment, Population).
## - On envoie les véhicules disponibles les plus proches ; la gravité (1 à 3)
##   donne leur nombre. Sur place, ils travaillent quelques minutes, puis
##   rentrent (l'ambulance passe d'abord par l'hôpital).
## - Conséquences : un malaise secouru trop tard peut être mortel, un
##   cambriolage non élucidé coûte de l'argent au foyer, un feu de poubelle
##   négligé gagne un bâtiment (incendie, si les événements sont là).
## - Temps d'intervention mesurés et zones de couverture (carte des routes
##   colorée selon le temps pour y arriver).
## - Sur les lieux : épaves, blessé, feu de poubelle… et les équipages qui
##   descendent travailler (ScenesIncidents) ; au-dessus, une petite icône
##   avec le détail au survol (IconesIncidents). Voir docs/incidents.md.

signal message(text: String)
signal changed

## Service rendu par chaque type de bâtiment.
const BUILDING_SERVICE := {"pompiers": "pompiers", "police": "police", "hopital": "ambulance"}
const SERVICES := ["pompiers", "ambulance", "police"]
const SERVICE_NAMES := {"pompiers": "Pompiers", "ambulance": "Secours (SAMU, VSAV)", "police": "Police"}
const SERVICE_COLORS := {"pompiers": Color("e63946"), "ambulance": Color("f4f4f4"), "police": Color("3a86ff")}
## Flotte de chaque bâtiment : [rôle, modèle par défaut]. Le modèle change
## avec la région des véhicules (REGION_MODELS) ; la police devient la
## gendarmerie dans les petites villes (moins de RURAL habitants).
const FLEETS := {
	"pompiers": [["pompiers", "fpt"], ["ambulance", "vsav"], ["pompiers", "pompiers"]],
	"police": [["police", "police_nationale"], ["police", "police_nationale"], ["police", "fourgon_police"]],
	"hopital": [["ambulance", "ambulance"], ["ambulance", "ambulance"], ["ambulance", "smur"]],
}
const REGION_MODELS := {
	"ameriques": {"fpt": "pompiers", "vsav": "ambulance_us", "ambulance": "ambulance_us", "smur": "ambulance_us",
		"police_nationale": "police_us", "fourgon_police": "police_us"},
	"asie_est": {"fpt": "pompiers", "vsav": "ambulance", "smur": "ambulance",
		"police_nationale": "police_japon", "fourgon_police": "police_japon"},
	"autre": {"fpt": "pompiers", "vsav": "ambulance", "smur": "ambulance"},
}
const RURAL := 2000
## Équipage de chaque modèle (personnes de garde nécessaires).
const CREW := {"fpt": 4, "pompiers": 2, "vsav": 3, "ambulance": 2, "ambulance_us": 2, "smur": 2,
	"police_nationale": 2, "gendarmerie": 2, "fourgon_police": 3, "police_us": 2, "police_japon": 2}
## Petits appels au hasard : besoin, lieu ("home" : un logement, "road" : une
## rue), travail sur place (s), délai au-delà duquel c'est trop tard (s).
const CALLS := {
	"malaise": {"name": "Malaise", "besoin": ["ambulance"], "where": "home", "weight": 4.0, "late": 720.0},
	"chute": {"name": "Chute à domicile", "besoin": ["ambulance"], "where": "home", "weight": 2.0, "late": 1500.0},
	"accident": {"name": "Accident de la route", "besoin": ["ambulance", "police"], "where": "road", "weight": 2.0, "late": 900.0},
	"cambriolage": {"name": "Cambriolage", "besoin": ["police"], "where": "home", "weight": 2.0, "late": 900.0},
	"feu_poubelle": {"name": "Feu de poubelle", "besoin": ["pompiers"], "where": "road", "weight": 1.5, "late": 900.0},
}
## Noms des incidents venus des événements.
const EVENT_NAMES := {"incendie": "Incendie", "malades": "Malades", "accident": "Accident", "epidemie": "Épidémie"}
## Travail sur place (s de simulation) par service.
const WORK := {"pompiers": 40.0, "ambulance": 25.0, "police": 30.0}
## Pause à l'hôpital avant de rentrer (s).
const HOSPITAL_STOP := 8.0
## Appels au hasard par heure réelle : base + par habitant. Un hameau n'a
## presque pas d'appels ; les accidents dépendent en plus de la circulation.
const CALL_RATE := [0.0, 0.03]
## En dessous de ce nombre d'habitants, les appels deviennent rares (proportionnels).
const PETITE_VILLE := 400
## Voitures en circulation pour un accident « au tarif plein ».
const TRAFIC_PLEIN := 150.0
## Sans aucun bâtiment pour répondre, un appel ne reste pas ouvert plus de
## ce multiple de son délai « trop tard » : les gens se débrouillent seuls.
const ABANDON := 1.5
## Bâtiment qui envoie chaque service (pour le conseil « construire »).
const BATIMENT_DE := {"pompiers": "pompiers", "police": "police", "ambulance": "hopital"}
const NOM_BATIMENT := {"pompiers": "une caserne de pompiers", "police": "un commissariat", "ambulance": "un hôpital"}
const MAX_ACTIVE := 6
## Couverture : seuils (s) des couleurs vert, jaune, orange ; au-delà rouge.
const COVER_STEPS := [180.0, 360.0, 600.0]
const COVER_COLORS := [Color(0.25, 0.85, 0.4, 0.75), Color(1.0, 0.85, 0.25, 0.75), Color(1.0, 0.55, 0.15, 0.75), Color(0.9, 0.2, 0.2, 0.75)]

var buildings: BuildingSystem
var transport: TransportSystem
var population: Population
## Petits appels au hasard (sinon : seulement les événements et les essais).
var random_calls := true
## Envoi des secours : false = automatique (le plus ancien appel d'abord, un
## clic le fait passer devant) ; true = rien ne part sans un clic du joueur
## sur l'incident (panneau Urgences, U).
## (Réglage de la partie : Admin, F10 ; aussi dans le panneau U.)
var envoi_manuel: bool:
	get:
		return ReglagesPartie.actuel.envoi_secours_manuel if ReglagesPartie.actuel != null else false
	set(v):
		if ReglagesPartie.actuel != null:
			ReglagesPartie.actuel.envoi_secours_manuel = v
## Tests : les équipages ne manquent jamais.
var ignore_crew := false
var rng := RandomNumberGenerator.new()
## Casernes : bid -> {bid, t, road: {edge, s, pos}, units: [{model, role, out, v}], staff, staff_t}.
var stations: Dictionary = {}
## Incidents en cours : id -> dictionnaire (voir _open_incident).
var incidents: Dictionary = {}
## Derniers incidents terminés (pour le panneau), du plus récent au plus ancien.
var history: Array = []
## Bilan : par service {n, total, best, worst} (temps d'arrivée, s) et compteurs.
var stats := {}
## Couverture affichée ("" : aucune).
var coverage := ""

var _t := 0.0
var _next_local := 1
var _call_timer := 20.0
var _retry := 0.0
var _evenements: Node
var _cover_mesh: MeshInstance3D
var _cover_dirty := true
var _no_crew_warned: Dictionary = {}
var _next_uid := 1
## Décor des lieux (voitures accidentées, blessés, équipages…) et icônes.
var scenes: ScenesIncidents
var icones: IconesIncidents
## Portes de garage et sorties/rentrées visibles des véhicules.
var sorties: SortiesCasernes


func _init() -> void:
	rng.randomize()
	_reset_stats()


func setup(b: BuildingSystem, t: TransportSystem, p: Population) -> void:
	buildings = b
	transport = t
	population = p
	if buildings != null:
		buildings.changed.connect(func() -> void: _sync_stations.call_deferred())
	if transport != null:
		transport.network_changed.connect(func() -> void:
			_cover_dirty = true
			_sync_stations.call_deferred())
	_sync_stations()


func _ready() -> void:
	_cover_mesh = MeshInstance3D.new()
	_cover_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cover_mesh.material_override = m
	_cover_mesh.visible = false
	add_child(_cover_mesh)
	scenes = ScenesIncidents.new()
	scenes.urg = self
	add_child(scenes)
	sorties = SortiesCasernes.new()
	sorties.urg = self
	add_child(sorties)
	icones = IconesIncidents.new()
	icones.urg = self
	add_child(icones)
	_connect_events()


func clear() -> void:
	for id in incidents.keys():
		_close(int(id), "annule", false)
	if scenes != null:
		scenes.vider()
	if sorties != null:
		sorties.vider()
	if transport != null and transport.traffic != null:
		for v in transport.traffic.emergency_vehicles():
			transport.traffic.remove_emergency(v)
	incidents.clear()
	history.clear()
	stations.clear()
	_reset_stats()
	_cover_dirty = true
	changed.emit()


func _reset_stats() -> void:
	stats = {"appels": 0, "terminees": 0, "trop_tard": 0, "deces": 0, "sauves": 0, "non_elucides": 0}
	for s in SERVICES:
		stats[s] = {"n": 0, "total": 0.0, "best": INF, "worst": 0.0}


# --- Événements de la ville (autoload Evenements) ---------------------------------

func _connect_events() -> void:
	if _evenements != null or not is_inside_tree():
		return
	_evenements = get_node_or_null("/root/Evenements")
	if _evenements == null:
		return
	if _evenements.has_signal("incident_declare"):
		_evenements.connect("incident_declare", _on_event_declared)
	if _evenements.has_signal("incident_aggrave"):
		_evenements.connect("incident_aggrave", _on_event_worse)
	if _evenements.has_signal("incident_resolu"):
		_evenements.connect("incident_resolu", _on_event_resolved)


func _on_event_declared(inc: Dictionary) -> void:
	var id := int(inc.get("id", -1))
	if id < 0 or incidents.has(id):
		return
	var besoin: Array = []
	var raw = inc.get("besoin", [])
	if raw is String:
		besoin.append(raw)
	else:
		besoin.append_array(raw)
	if besoin.is_empty():
		return
	var pos: Vector3 = inc.get("position", Vector3.ZERO)
	var typ := String(inc.get("type", "incident"))
	var meta: Dictionary = (inc.get("urgences", {}) as Dictionary).duplicate()
	if inc.has("role") and not meta.has("role"):
		meta["role"] = String(inc.role)
	if int(inc.get("batiment", -1)) >= 0 and not meta.has("bid"):
		meta["batiment"] = int(inc.batiment)
	if inc.has("texte") and not meta.has("name") and String(inc.get("origine", "")) != "urgences":
		meta["name"] = String(inc.texte)
	var name_ := String(meta.get("name", EVENT_NAMES.get(typ, typ.capitalize())))
	_open_incident(id, typ, name_, pos, besoin, int(inc.get("gravite", 1)), meta, false)


func _on_event_worse(id: int, gravite: int) -> void:
	if not incidents.has(id):
		return
	var inc: Dictionary = incidents[id]
	if gravite > int(inc.gravite):
		inc.gravite = clampi(gravite, 1, 3)
		message.emit("%s s'aggrave : renforts envoyés." % String(inc.name))
		_dispatch(inc)
		changed.emit()


func _on_event_resolved(id: int) -> void:
	if incidents.has(id) and not incidents[id].get("closing", false):
		_close(id, "termine", false)


# --- Appels ----------------------------------------------------------------------------

## Déclare un incident. Passe par Evenements quand il existe (une seule liste
## d'incidents pour toute la ville), sinon il reste local. Renvoie son id.
func declare(type: String, name_: String, pos: Vector3, besoin: Array, gravite := 1, meta: Dictionary = {}) -> int:
	stats.appels = int(stats.appels) + 1
	meta = meta.duplicate()
	meta["name"] = name_
	meta["type"] = type
	_connect_events()
	if _evenements != null and _evenements.has_method("declarer"):
		var inc := {"type": type, "position": pos, "gravite": gravite, "besoin": besoin, "origine": "urgences", "urgences": meta}
		if meta.has("bid"):
			inc["batiment"] = int(meta.bid)
		var id: int = _evenements.call("declarer", inc)
		# Si Evenements n'a pas émis le signal, on prend l'incident nous-mêmes.
		if id >= 0 and not incidents.has(id):
			inc["id"] = id
			_on_event_declared(inc)
		return id
	var lid := -_next_local
	_next_local += 1
	_open_incident(lid, type, name_, pos, besoin, gravite, meta, true)
	return lid


## Petit appel au hasard dans la ville (kind : "" = tiré au sort). near : point
## autour duquel chercher (sinon partout). Renvoie l'id ou -1.
func random_call(kind := "", near := Vector3.INF) -> int:
	if kind == "":
		var total := 0.0
		for k in CALLS:
			total += call_weight(k)
		if total <= 0.0:
			return -1
		var x := rng.randf() * total
		for k in CALLS:
			x -= call_weight(k)
			kind = k
			if x <= 0.0:
				break
	var c: Dictionary = CALLS[kind]
	var meta := {}
	var pos := Vector3.INF
	if String(c.where) == "home":
		var bid := _pick_home(near)
		if bid >= 0:
			meta["bid"] = bid
			pos = _building_pos(bid)
			var who := _pick_person(bid, kind)
			if who >= 0:
				meta["pid"] = who
			if population != null and population.by_home.has(bid) and not (population.by_home[bid] as Array).is_empty():
				meta["hid"] = int(population.by_home[bid][rng.randi() % (population.by_home[bid] as Array).size()])
	if pos == Vector3.INF:
		var rp := _random_road_point(near)
		if rp.is_empty():
			return -1
		pos = rp.pos
	var grav := 1
	if kind == "accident" and rng.randf() < 0.3:
		grav = 2
	return declare(kind, String(c.name), pos, c.besoin, grav, meta)


## Poids d'un petit appel au hasard : les accidents suivent la circulation
## réelle ; un appel que personne ne peut traiter (aucun bâtiment du service)
## devient rare, pour ne pas remplir la ville d'incidents bloqués.
func call_weight(kind: String) -> float:
	var w := float(CALLS[kind].weight)
	if kind == "accident":
		w *= clampf(_cars_on_road() / TRAFIC_PLEIN, 0.0, 1.5)
	for s in CALLS[kind].besoin:
		if not has_service(String(s)):
			w *= 0.2
	return w


func _cars_on_road() -> float:
	if transport == null or transport.traffic == null:
		return 0.0
	var n := 0
	for v in transport.traffic.vehicles:
		if int(v.get("mode", -1)) == TransportTypes.Mode.ROAD and not v.has("urgence") and not v.has("line"):
			n += 1
	return float(n)


## Un bâtiment de la ville envoie-t-il ce service ?
func has_service(service: String) -> bool:
	for bid in stations:
		for u in stations[bid].units:
			if String(u.role) == service:
				return true
	return false


## Appels au hasard par heure réelle pour la population actuelle.
func call_rate() -> float:
	var n := float(population.persons.size() if population != null else 0)
	var r := float(CALL_RATE[0]) + float(CALL_RATE[1]) * n
	# Petit village : encore moins (un accident par semaine, pas dix à la fois).
	return r * clampf(n / float(PETITE_VILLE), 0.0, 1.0)


func _pick_home(near: Vector3) -> int:
	if population == null or population.by_home.is_empty():
		return -1
	var homes := population.by_home.keys()
	if near == Vector3.INF:
		return int(homes[rng.randi() % homes.size()])
	var best := -1
	var best_d := INF
	for bid in homes:
		var d := _building_pos(int(bid)).distance_to(near) + rng.randf() * 40.0
		if d < best_d:
			best_d = d
			best = int(bid)
	return best


## Habitant concerné : plutôt âgé pour un malaise ou une chute.
func _pick_person(bid: int, kind: String) -> int:
	if population == null:
		return -1
	var best := -1
	var best_score := -INF
	for hid in population.by_home.get(bid, []):
		for pid in population.households[hid].m:
			var a := population.age_of(population.persons[pid])
			var score := rng.randf() * 40.0
			if kind in ["malaise", "chute"]:
				score += a
			if score > best_score:
				best_score = score
				best = int(pid)
	return best


func _building_pos(bid: int) -> Vector3:
	if population != null and population.known.has(bid):
		return population.building_pos(bid)
	if buildings != null and buildings.buildings.has(bid):
		var b: Dictionary = buildings.buildings[bid]
		return BuildingSystem.rect_center(buildings._rect_of(b)) + Vector3(0, float(b.get("h", 0.0)), 0)
	return Vector3.ZERO


func _random_road_point(near: Vector3) -> Dictionary:
	if transport == null:
		return {}
	var net := transport.network
	var ids: Array = []
	if near != Vector3.INF:
		for eid in transport.edges_near(near, 250.0):
			ids.append(eid)
	if ids.is_empty():
		ids = net.edges.keys()
	var roads: Array = []
	for eid in ids:
		if TransportTypes.mode_of(net.edges[eid].t) == TransportTypes.Mode.ROAD and not String(net.edges[eid].t) in ["autoroute", "bretelle"]:
			roads.append(eid)
	if roads.is_empty():
		return {}
	var eid: int = roads[rng.randi() % roads.size()]
	var s := rng.randf_range(0.2, 0.8) * float(net.edges[eid].len)
	return {"edge": eid, "s": s, "pos": net.point_at(eid, s)}


## Point de route le plus proche d'un lieu : {edge, s, pos} ou {}.
func road_point(p: Vector3, radius := 80.0) -> Dictionary:
	if transport == null:
		return {}
	var best := {}
	for r in [radius, radius * 4.0]:
		for eid in transport.edges_near(p, r):
			var e: Dictionary = transport.network.edges[eid]
			if TransportTypes.mode_of(e.t) != TransportTypes.Mode.ROAD:
				continue
			var hit := transport.network.nearest_on_edge(eid, p)
			# Pas d'arrêt sur une autoroute si une autre voie convient.
			var d := float(hit.dist) + (60.0 if String(e.t) in ["autoroute", "bretelle"] else 0.0)
			if best.is_empty() or d < float(best.d):
				best = {"edge": eid, "s": float(hit.s), "pos": hit.pos, "d": d}
		if not best.is_empty():
			return best
	return best


func _open_incident(id: int, type: String, name_: String, pos: Vector3, besoin: Array, gravite: int, meta: Dictionary, local: bool) -> void:
	var road := road_point(pos)
	var inc := {"id": id, "type": type, "name": name_, "pos": pos, "road": road, "gravite": clampi(gravite, 1, 3),
		"besoin": besoin, "t0": _t, "units": [], "arrived": {}, "work": {}, "done": {}, "taken": {}, "meta": meta,
		"local": local, "state": "attente"}
	incidents[id] = inc
	if road.is_empty():
		inc.state = "inaccessible"
	if scenes != null:
		scenes.ouvrir(inc)
	inc.demande = not envoi_manuel
	_dispatch_all()
	var where := _place_name(inc)
	message.emit("Appel : %s%s." % [name_, where])
	changed.emit()


func _place_name(inc: Dictionary) -> String:
	var bid := int(inc.meta.get("bid", inc.meta.get("batiment", -1)))
	if bid >= 0 and population != null and population.known.has(bid):
		return " (%s)" % population.building_name(bid)
	return ""


# --- Casernes et flottes -----------------------------------------------------------------

func _sync_stations() -> void:
	if buildings == null:
		return
	var seen := {}
	for bid in buildings.buildings:
		var b: Dictionary = buildings.buildings[bid]
		# Le bâtiment joue-t-il le rôle d'une caserne, d'un commissariat ou d'un
		# hôpital (versions d'époque, modèles de l'Atelier) ?
		var t := String(b.t)
		if not BUILDING_SERVICE.has(t):
			t = BuildingCatalog.base_of(t)
		if not BUILDING_SERVICE.has(t):
			continue
		seen[bid] = true
		var rect := buildings._rect_of(b)
		var door := BuildingSystem.door_point(String(b.t), rect, int(b.r), float(b.get("a", 0.0)))
		var road := road_point(door, 30.0)
		if not stations.has(bid):
			var units: Array = []
			for f in FLEETS[t]:
				units.append({"role": f[0], "base": f[1], "out": false, "v": {}, "inc": 0})
			stations[bid] = {"bid": bid, "t": t, "units": units, "staff": 0, "staff_t": -INF}
		stations[bid].road = road
		stations[bid].door = door
	for bid in stations.keys():
		if not seen.has(bid):
			for u in stations[bid].units:
				if u.out and not (u.v as Dictionary).is_empty():
					transport.traffic.remove_emergency(u.v)
			stations.erase(bid)
	_cover_dirty = true
	changed.emit()


## Modèle d'un véhicule de flotte selon la région des véhicules (et la
## gendarmerie à la campagne).
func model_for(base: String) -> String:
	var region := ""
	if transport != null and transport.traffic != null:
		region = transport.traffic.region_filter
	var m := base
	if region == "ameriques" or region == "asie_est":
		m = String(REGION_MODELS[region].get(base, base))
	elif region != "" and region != "europe" and region != "monde":
		m = String(REGION_MODELS.autre.get(base, base))
	elif base == "police_nationale" and population != null and population.persons.size() < RURAL:
		m = "gendarmerie"
	# Partie historique : le modèle de l'époque (pompe à bras, ambulance à chevaux…).
	return Epoques.vehicule(m)


func crew_of(model: String) -> int:
	return int(CREW.get(model, 2))


## Personnes de garde aujourd'hui dans un bâtiment (les gardes durent 24 h).
## Sans habitants simulés (tests), l'équipage ne manque jamais.
func staff_of(bid: int) -> int:
	if population == null or ignore_crew:
		return 999
	var st: Dictionary = stations.get(bid, {})
	if not st.is_empty() and _t - float(st.staff_t) < 5.0:
		return int(st.staff)
	var n := population.now()
	var c := 0
	for pid in population.by_job.get(bid, []):
		var p: Dictionary = population.persons.get(pid, {})
		if p.is_empty():
			continue
		if population._works_today(p, n) and not population._on_leave(p, n):
			c += 1
	if not st.is_empty():
		st.staff = c
		st.staff_t = _t
	return c


func crew_busy(bid: int) -> int:
	var c := 0
	for u in stations[bid].units:
		if u.out:
			c += crew_of(String(u.get("model", u.base)))
	return c


## Véhicule libre (avec son équipage) ?
func unit_ready(bid: int, u: Dictionary) -> bool:
	if u.out:
		return false
	return staff_of(bid) - crew_busy(bid) >= crew_of(model_for(String(u.base)))


# --- Envoi des véhicules -------------------------------------------------------------------

func _need(inc: Dictionary, service: String) -> int:
	var g := int(inc.gravite)
	match service:
		"pompiers": return g
		"ambulance": return g
		"police": return 1 if g < 3 else 2
	return 1


func _sent(inc: Dictionary, service: String) -> int:
	var c := 0
	for u in inc.units:
		if String(u.role) == service:
			c += 1
	return c


## Envoie les véhicules libres aux appels, dans l'ordre de la file (appels
## prioritaires d'abord, puis du plus ancien au plus récent).
func _dispatch_all() -> void:
	for id in ordre_file():
		if incidents.has(id):
			_dispatch(incidents[id])


## Ids des appels ouverts, dans l'ordre où ils seront servis.
func ordre_file() -> Array:
	var ids := incidents.keys()
	ids.sort_custom(func(a, b) -> bool:
		var ia: Dictionary = incidents[a]
		var ib: Dictionary = incidents[b]
		if bool(ia.get("prio", false)) != bool(ib.get("prio", false)):
			return bool(ia.get("prio", false))
		return float(ia.t0) < float(ib.t0))
	return ids


## Le service manque-t-il encore à cet appel (rien d'envoyé, ou pas assez) ?
func attend(inc: Dictionary, service: String) -> bool:
	return not bool(inc.done.get(service, false)) and _sent(inc, service) < _need(inc, service) and not inc.get("closing", false)


## File d'attente d'un service : ids des appels qui l'attendent, dans l'ordre
## (en envoi manuel, seulement ceux que le joueur a demandés).
func file(service: String) -> Array:
	var out := []
	for id in ordre_file():
		var inc: Dictionary = incidents[id]
		if (inc.besoin as Array).has(service) and attend(inc, service) and bool(inc.get("demande", true)):
			out.append(id)
	return out


## Place (1 = le prochain servi) d'un appel dans la file d'un service, 0 s'il n'y est pas.
func place_dans_file(inc: Dictionary, service: String) -> int:
	return file(service).find(int(inc.id)) + 1


## Clic du joueur sur un incident : on envoie les secours (en tête de file).
## Renvoie le texte affiché au joueur.
func envoyer(id: int) -> String:
	if not incidents.has(id):
		return ""
	var inc: Dictionary = incidents[id]
	var deja := bool(inc.get("demande", false))
	inc.demande = true
	inc.prio = true
	_dispatch_all()
	var attente: Array[String] = []
	for s in inc.besoin:
		if attend(inc, String(s)):
			var r := raison_attente(inc, String(s))
			var place := place_dans_file(inc, String(s))
			attente.append("%s %s" % [String(SERVICE_NAMES[s]).get_slice(" ", 0), ("(%s)" % r) if not has_service(String(s)) or (inc.road as Dictionary).is_empty()
				else "en sous-effectif : %s dans la file" % _rang(place)])
	var txt := ""
	if attente.is_empty():
		txt = "%s : secours envoyés." % String(inc.name) if not deja or (inc.units as Array).size() > 0 else ""
	else:
		txt = "%s : en attente. %s." % [String(inc.name), ", ".join(attente)]
	if txt != "":
		message.emit(txt)
	changed.emit()
	return txt


static func _rang(n: int) -> String:
	return "1er" if n == 1 else "%de" % n


func _dispatch(inc: Dictionary) -> void:
	if (inc.road as Dictionary).is_empty() or inc.get("closing", false):
		return
	if not bool(inc.get("demande", true)):
		return
	for service in inc.besoin:
		if bool(inc.done.get(service, false)):
			continue
		var want := _need(inc, service) - _sent(inc, service)
		if want <= 0:
			continue
		var cands: Array = []
		for bid in stations:
			var st: Dictionary = stations[bid]
			if (st.road as Dictionary).is_empty():
				continue
			for u in st.units:
				if String(u.role) == service and unit_ready(bid, u):
					cands.append([float((st.road.pos as Vector3).distance_to(inc.pos)), bid, u])
		if cands.is_empty():
			_warn_no_crew(service)
			continue
		cands.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
		for c in cands:
			if want <= 0:
				break
			if _send(inc, int(c[1]), c[2]):
				want -= 1
	changed.emit()


func _warn_no_crew(service: String) -> void:
	var has_station := false
	for bid in stations:
		for u in stations[bid].units:
			if String(u.role) == service:
				has_station = true
	var key := service + ("" if has_station else "_aucun")
	if _t - float(_no_crew_warned.get(key, -INF)) < 120.0:
		return
	_no_crew_warned[key] = _t
	if has_station:
		var n := file(service).size()
		var garde := 0
		var vehicules := 0
		for bid in stations:
			var has := false
			for u in stations[bid].units:
				if String(u.role) == service:
					has = true
					vehicules += 1
			if has:
				garde += mini(staff_of(int(bid)), 999)
		message.emit("%d appel%s en attente : %s en sous-effectif (%s de garde, %d véhicule%s). Embauche ou construis un 2e bâtiment." % [
			n, "s" if n > 1 else "", String(SERVICE_NAMES[service]).get_slice(" ", 0).to_lower(),
			"personne" if garde == 0 else "%d personne%s" % [garde, "s" if garde > 1 else ""], vehicules, "s" if vehicules > 1 else ""])
	else:
		message.emit("%s : aucun bâtiment pour répondre à l'appel." % String(SERVICE_NAMES[service]))


func _send(inc: Dictionary, bid: int, u: Dictionary) -> bool:
	var st: Dictionary = stations[bid]
	var model := model_for(String(u.base))
	var unit := u
	var v := transport.traffic.add_emergency(model, st.road, inc.road, true, func(veh: Dictionary) -> void: _on_arrival(unit, veh))
	if v.is_empty():
		return false
	if sorties != null:
		sorties.sortie(bid, v)
	u.out = true
	u.uid = _next_uid
	_next_uid += 1
	u.model = model
	u.v = v
	u.inc = int(inc.id)
	u.bid = bid
	u.phase = "aller"
	u.t_go = _t
	(inc.units as Array).append(u)
	inc.state = "en_route"
	var service := String(u.role)
	if not inc.taken.get(service, false):
		inc.taken[service] = true
		if not inc.local and _evenements != null and _evenements.has_method("prendre_en_charge"):
			_evenements.call("prendre_en_charge", int(inc.id), service)
	return true


func _on_arrival(u: Dictionary, v: Dictionary) -> void:
	match String(u.get("phase", "")):
		"aller":
			_on_scene(u)
		"hopital":
			u.phase = "pause"
			u.wait = HOSPITAL_STOP
		"retour":
			_home(u)


func _on_scene(u: Dictionary) -> void:
	var id := int(u.inc)
	if not incidents.has(id):
		_go_home(u)
		return
	var inc: Dictionary = incidents[id]
	var service := String(u.role)
	u.phase = "sur_place"
	u.wait = float(WORK.get(service, 30.0)) * (1.0 + 0.5 * (int(inc.gravite) - 1))
	if service == "ambulance" and not inc.meta.has("by"):
		inc.meta["by"] = "les pompiers" if String(u.base) == "vsav" else "le SAMU"
	if not inc.arrived.has(service):
		var dt := _t - float(inc.t0)
		inc.arrived[service] = dt
		var s: Dictionary = stats[service]
		s.n = int(s.n) + 1
		s.total = float(s.total) + dt
		s.best = minf(float(s.best), dt)
		s.worst = maxf(float(s.worst), dt)
		message.emit("%s sur place (%s) en %s." % [String(SERVICE_NAMES[service]), String(inc.name), format_time(dt)])
	inc.state = "sur_place"
	changed.emit()


## Travail fini sur place : le service est fait, le véhicule repart.
func _work_done(u: Dictionary) -> void:
	var id := int(u.inc)
	var service := String(u.role)
	if incidents.has(id):
		var inc: Dictionary = incidents[id]
		var all_done := true
		for o in inc.units:
			if String(o.role) == service and o.get("phase", "") in ["aller", "sur_place"] and not is_same(o, u):
				all_done = false
		if all_done:
			inc.done[service] = true
			_effects_on_done(inc, service)
		if service == "ambulance" and _hospital_road(u) != {}:
			_to_hospital(u, int(inc.gravite) >= 2 or String(inc.type) == "malaise")
		else:
			_go_home(u)
		var finished := true
		for s in inc.besoin:
			if not inc.done.get(s, false):
				finished = false
		if finished:
			_close(id, "termine", true)
	else:
		_go_home(u)
	changed.emit()


func _hospital_road(u: Dictionary) -> Dictionary:
	var best := {}
	var best_d := INF
	var here := transport.traffic.vehicle_position(u.v)
	for bid in stations:
		var st: Dictionary = stations[bid]
		if String(st.t) == "hopital" and not (st.road as Dictionary).is_empty():
			var d := (st.road.pos as Vector3).distance_to(here)
			if d < best_d:
				best_d = d
				best = st.road
	return best


func _to_hospital(u: Dictionary, siren: bool) -> void:
	var road := _hospital_road(u)
	var unit := u
	u.phase = "hopital"
	if not transport.traffic.reroute_emergency(u.v, road, siren, func(veh: Dictionary) -> void: _on_arrival(unit, veh)):
		_go_home(u)


func _go_home(u: Dictionary) -> void:
	var bid := int(u.get("bid", -1))
	if not stations.has(bid) or (u.v as Dictionary).is_empty():
		_home(u)
		return
	var unit := u
	u.phase = "retour"
	if not transport.traffic.reroute_emergency(u.v, stations[bid].road, false, func(veh: Dictionary) -> void: _on_arrival(unit, veh)):
		_home(u)


## Rentré au garage : le véhicule disparaît, il est de nouveau disponible.
func _home(u: Dictionary) -> void:
	if not (u.v as Dictionary).is_empty():
		if sorties != null and String(u.get("phase", "")) == "retour" and transport.traffic.vehicles.has(u.v):
			sorties.rentree(int(u.get("bid", -1)), String(u.get("model", u.base)), transport.traffic.vehicle_position(u.v))
		transport.traffic.remove_emergency(u.v)
	u.v = {}
	u.out = false
	u.phase = ""
	u.inc = 0
	changed.emit()


func _close(id: int, how: String, notify: bool) -> void:
	if not incidents.has(id):
		return
	var inc: Dictionary = incidents[id]
	inc.closing = true
	for u in inc.units:
		if String(u.get("phase", "")) in ["aller", "sur_place"]:
			_go_home(u)
	if notify and not inc.local and _evenements != null and _evenements.has_method("resoudre"):
		_evenements.call("resoudre", id)
	if how == "termine":
		stats.terminees = int(stats.terminees) + 1
	inc.state = how
	inc.t_end = _t
	history.push_front(inc)
	if history.size() > 30:
		history.resize(30)
	incidents.erase(id)
	if scenes != null:
		scenes.fermer(id)
	changed.emit()


# --- Conséquences ----------------------------------------------------------------------

func _effects_on_done(inc: Dictionary, service: String) -> void:
	if population == null:
		return
	var pid := int(inc.meta.get("pid", -1))
	var late := float(CALLS.get(String(inc.type), {}).get("late", INF))
	var dt := float(inc.arrived.get(service, 0.0))
	if service == "ambulance" and pid >= 0 and population.persons.has(pid):
		var p: Dictionary = population.persons[pid]
		if dt > late and String(inc.type) == "malaise" and rng.randf() < 0.3:
			population.vie.die(pid, "d'un malaise, les secours sont arrivés trop tard")
			stats.deces = int(stats.deces) + 1
			message.emit("%s %s n'a pas survécu : les secours sont arrivés trop tard." % [String(p.get("p", "")), String(p.get("n", ""))])
		else:
			stats.sauves = int(stats.sauves) + 1
			population.vie.log_event(p, "urgence", "%s : secouru·e par %s" % [String(inc.name),
				"le SAMU" if String(inc.meta.get("by", "")) == "" else String(inc.meta.by)])
	if service == "police" and String(inc.type) == "cambriolage" and dt > late:
		stats.non_elucides = int(stats.non_elucides) + 1
		var hid := int(inc.meta.get("hid", -1))
		if population.households.has(hid):
			var loss := float(rng.randi_range(3, 15) * 100)
			var h: Dictionary = population.households[hid]
			h.ep = maxf(0.0, float(h.ep) - loss)
			message.emit("Cambriolage non élucidé : le foyer perd %d €." % int(loss))


## Incident sans secours à temps : il s'aggrave ou se termine mal.
func _check_late(inc: Dictionary) -> void:
	if not CALLS.has(String(inc.type)):
		return
	if not inc.local:
		_check_abandon(inc)
		return
	if inc.get("late_done", false):
		return
	var late := float(CALLS.get(String(inc.type), {}).get("late", INF))
	if _t - float(inc.t0) < late:
		return
	for s in inc.besoin:
		if inc.arrived.has(s):
			return
	inc.late_done = true
	stats.trop_tard = int(stats.trop_tard) + 1
	if String(inc.type) == "feu_poubelle":
		var bid := _pick_home(inc.pos)
		if bid >= 0 and _building_pos(bid).distance_to(inc.pos) < 60.0 and _evenements != null:
			message.emit("Le feu de poubelle a gagné un bâtiment !")
			declare("incendie", "Incendie", _building_pos(bid), ["pompiers"], 1, {"bid": bid})
	# Personne n'est jamais parti : l'appel est abandonné.
	if (inc.units as Array).is_empty():
		_effects_on_done(inc, String(inc.besoin[0]))
		_close(int(inc.id), "trop_tard", false)


## Appel d'une ville sans service pour y répondre (ou sans route) : après un
## long moment, les gens se débrouillent seuls et l'incident se ferme, avec
## ses conséquences (dépanneuse privée, cambriolage non élucidé…).
func _check_abandon(inc: Dictionary) -> void:
	# Seulement si ce qui reste à faire n'a aucun bâtiment pour l'envoyer (sinon
	# l'appel attend son tour, même long) et que personne n'y travaille.
	var reste := false
	for s in inc.besoin:
		if bool(inc.done.get(s, false)):
			continue
		reste = true
		if has_service(String(s)) and not (inc.road as Dictionary).is_empty():
			return
		for u in inc.units:
			if String(u.role) == String(s) and String(u.get("phase", "")) in ["aller", "sur_place"]:
				return
	if not reste:
		return
	var late := float(CALLS[String(inc.type)].late)
	if _t - float(inc.t0) < late * ABANDON:
		return
	stats.trop_tard = int(stats.trop_tard) + 1
	var manque := services_manquants(inc)
	match String(inc.type):
		"accident":
			message.emit("Accident : sans %s, les automobilistes ont appelé une dépanneuse privée. Route dégagée." % ", ".join(manque.map(func(s): return String(SERVICE_NAMES[s]).get_slice(" ", 0).to_lower())) if not manque.is_empty() else "Accident : route dégagée sans les secours.")
		"feu_poubelle":
			message.emit("Le feu de poubelle s'est éteint tout seul. Cette fois.")
	_effects_on_done(inc, String(inc.besoin[0]))
	_close(int(inc.id), "trop_tard", true)


# --- Boucle ------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if transport == null or transport.traffic == null or not transport.traffic.enabled:
		return
	step(EchelleTemps.dt(delta))


## Fait avancer les urgences de delta secondes de simulation.
func step(delta: float) -> void:
	_t += delta
	if sorties != null:
		sorties.step(delta)
	_connect_events()
	# Véhicules sur place ou à l'hôpital : minuterie.
	for bid in stations:
		for u in stations[bid].units:
			if not u.out:
				continue
			if (u.v as Dictionary).is_empty() or not transport.traffic.vehicles.has(u.v):
				# Véhicule perdu (route coupée…) : il rentre directement.
				_home(u)
				continue
			match String(u.get("phase", "")):
				"sur_place":
					u.wait = float(u.wait) - delta
					if float(u.wait) <= 0.0:
						_work_done(u)
				"pause":
					u.wait = float(u.wait) - delta
					if float(u.wait) <= 0.0:
						_go_home(u)
	_retry -= delta
	if _retry <= 0.0:
		_retry = 3.0
		_dispatch_all()
		for id in incidents.keys():
			if incidents.has(id):
				_check_late(incidents[id])
	if random_calls:
		_call_timer -= delta
		if _call_timer <= 0.0:
			var rate := call_rate()
			_call_timer = rng.randf_range(0.5, 1.5) * 3600.0 / maxf(rate, 0.05)
			if rate > 0.0 and not stations.is_empty() and _random_open() < MAX_ACTIVE:
				random_call()
	if coverage != "" and _cover_dirty:
		_build_coverage()


# --- Détail d'un incident (icônes, panneau) ---------------------------------------------

func _random_open() -> int:
	var n := 0
	for id in incidents:
		if CALLS.has(String(incidents[id].type)) and String(incidents[id].meta.get("role", "")) == "":
			n += 1
	return n


## Services demandés par l'incident qu'aucun bâtiment de la ville n'envoie.
func services_manquants(inc: Dictionary) -> Array:
	var out := []
	for s in inc.besoin:
		if not inc.done.get(s, false) and not has_service(String(s)):
			out.append(String(s))
	return out


## Pourquoi personne n'est (encore) parti pour un service : "" si quelqu'un vient.
func raison_attente(inc: Dictionary, service: String) -> String:
	if _sent(inc, service) > 0 or bool(inc.done.get(service, false)):
		return ""
	if (inc.road as Dictionary).is_empty():
		return "aucune route n'arrive jusqu'ici"
	if not has_service(service):
		return "il faut %s" % String(NOM_BATIMENT.get(service, "un bâtiment de secours"))
	return "aucun véhicule libre avec son équipage de garde"


## Type de bâtiment (de l'époque) qui envoie ce service, "" s'il n'y en a pas.
func batiment_pour(service: String) -> String:
	var base := String(BATIMENT_DE.get(service, ""))
	if base == "":
		return ""
	if Epoques.batiment_disponible(base):
		return base
	for id in BuildingCatalog.all_types():
		if BuildingCatalog.base_of(String(id)) == base and Epoques.batiment_disponible(String(id)):
			return String(id)
	return base


## Titre et texte de la carte d'un incident (survol de l'icône).
func detail(inc: Dictionary) -> Dictionary:
	var titre := String(inc.name) + _place_name(inc)
	var lignes: Array[String] = []
	var depuis := format_time(_t - float(inc.t0))
	match String(inc.state):
		"attente", "inaccessible":
			lignes.append("Appel il y a %s : personne n'est encore parti." % depuis)
		"en_route":
			lignes.append("Appel il y a %s : secours en route." % depuis)
		"sur_place":
			lignes.append("Secours sur place (appel il y a %s)." % depuis)
	for s in inc.besoin:
		var nom := String(SERVICE_NAMES.get(s, s))
		var etat := ""
		if bool(inc.done.get(s, false)):
			etat = "terminé"
		elif inc.arrived.has(s):
			var la := 0
			for u in inc.units:
				if String(u.role) == s and String(u.get("phase", "")) == "sur_place":
					la += 1
			etat = "sur place (%d véhicule%s), arrivés en %s" % [la, "s" if la > 1 else "", format_time(float(inc.arrived[s]))] if la > 0 else "repartis"
		elif _sent(inc, s) > 0:
			etat = "en route"
		elif not bool(inc.get("demande", true)):
			etat = "à envoyer : clique sur l'icône"
		else:
			etat = "personne : " + raison_attente(inc, String(s))
			var place := place_dans_file(inc, String(s))
			if place > 0 and has_service(String(s)):
				etat += " (%s dans la file sur %d)" % [_rang(place), file(String(s)).size()]
		lignes.append("• %s : %s" % [nom, etat])
	var manque := services_manquants(inc)
	if not manque.is_empty():
		var noms := []
		for s in manque:
			noms.append(String(NOM_BATIMENT[s]))
		lignes.append("Construis %s (B → Services). Sans secours, l'affaire se règle seule, mais mal et lentement." % " et ".join(noms))
	return {"titre": titre, "texte": "\n".join(lignes)}


## Avis pour la Mairie (M) et le fil « À faire » : appels sans aucun service pour y répondre.
func alertes() -> Array:
	var par_service := {}
	for id in incidents:
		for s in services_manquants(incidents[id]):
			par_service[s] = int(par_service.get(s, 0)) + 1
	var out := []
	for s in ["police", "ambulance", "pompiers"]:
		if not par_service.has(s):
			continue
		var n := int(par_service[s])
		var id := batiment_pour(s)
		out.append({"id": "sans_" + s, "gravite": 2 if n >= 3 else 1, "prio": 1, "theme": "securite",
			"titre": "%d appel%s sans %s" % [n, "s" if n > 1 else "", {"police": "police", "ambulance": "ambulance", "pompiers": "pompiers"}[s]],
			"texte": {"police": "Les accidents et les cambriolages attendent un agent qui ne viendra pas.",
				"ambulance": "Les malades attendent une ambulance que personne n'envoie.",
				"pompiers": "Les feux attendent des pompiers qui n'existent pas."}[s],
			"conseil": "Construis %s : il enverra ses véhicules (icônes rouges au-dessus des incidents)." % String(NOM_BATIMENT[s]),
			"panneau": "batiment:" + id if id != "" else "construire"})
	return out


func state_label(inc: Dictionary) -> String:
	match String(inc.state):
		"attente":
			if not bool(inc.get("demande", true)):
				return "à envoyer (clic) · %s" % format_time(_t - float(inc.t0))
			return "en attente (%s)" % format_time(_t - float(inc.t0))
		"en_route": return "secours en route (%s)" % format_time(_t - float(inc.t0))
		"sur_place": return "secours sur place"
		"inaccessible": return "aucune route"
		"termine": return "terminé"
		"trop_tard": return "trop tard"
	return String(inc.state)


static func format_time(sec: float) -> String:
	if sec == INF or is_nan(sec):
		return "—"
	var s := int(round(sec))
	if s < 60:
		return "%d s" % s
	return "%d min %02d" % [s / 60, s % 60]


# --- Couverture ----------------------------------------------------------------------------

## Affiche la zone couverte par un service ("" : rien).
func set_coverage(service: String) -> void:
	coverage = service
	_cover_dirty = true
	if service == "":
		_cover_mesh.visible = false
	else:
		_build_coverage()


## Temps (s) pour atteindre chaque nœud routier depuis les bâtiments du service.
func coverage_times(service: String) -> Dictionary:
	var net := transport.network
	var best := {}
	var open: Array = []
	for bid in stations:
		var st: Dictionary = stations[bid]
		var has := false
		for u in st.units:
			if String(u.role) == service:
				has = true
		if not has or (st.road as Dictionary).is_empty():
			continue
		var eid := int(st.road.edge)
		if not net.edges.has(eid):
			continue
		var e: Dictionary = net.edges[eid]
		var sp := _speed(e)
		for pair in [[int(e.a), float(st.road.s)], [int(e.b), float(e.len) - float(st.road.s)]]:
			var t := float(pair[1]) / sp
			if t < float(best.get(pair[0], INF)):
				best[pair[0]] = t
				open.append([t, pair[0]])
	# Dijkstra simple (le réseau d'une région reste modeste).
	while not open.is_empty():
		var bi := 0
		for i in open.size():
			if float(open[i][0]) < float(open[bi][0]):
				bi = i
		var cur: Array = open[bi]
		open.remove_at(bi)
		var n := int(cur[1])
		if float(cur[0]) > float(best.get(n, INF)):
			continue
		for eid in net.adjacency.get(n, []):
			var e: Dictionary = net.edges[eid]
			if TransportTypes.mode_of(e.t) != TransportTypes.Mode.ROAD:
				continue
			var o := net.other_end(eid, n)
			var t := float(cur[0]) + float(e.len) / _speed(e)
			if t < float(best.get(o, INF)):
				best[o] = t
				open.append([t, o])
	return best


func _speed(e: Dictionary) -> float:
	return minf(TransportTypes.speed_of(e.t) * Traffic.SIREN_SPEED, 36.0)


static func cover_color(t: float) -> Color:
	for i in COVER_STEPS.size():
		if t <= float(COVER_STEPS[i]):
			return COVER_COLORS[i]
	return COVER_COLORS[COVER_COLORS.size() - 1]


func _build_coverage() -> void:
	_cover_dirty = false
	if coverage == "" or transport == null:
		_cover_mesh.visible = false
		return
	var times := coverage_times(coverage)
	var net := transport.network
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any := false
	for eid in net.edges:
		var e: Dictionary = net.edges[eid]
		if TransportTypes.mode_of(e.t) != TransportTypes.Mode.ROAD:
			continue
		var pts: PackedVector3Array = e.pts
		var d: PackedFloat32Array = e.d
		var ta := float(times.get(int(e.a), INF))
		var tb := float(times.get(int(e.b), INF))
		var sp := _speed(e)
		var hw := 1.4
		for i in pts.size() - 1:
			var p0 := pts[i]
			var p1 := pts[i + 1]
			var dir := p1 - p0
			dir.y = 0.0
			if dir.length_squared() < 1e-6:
				continue
			var side := Vector3(-dir.z, 0, dir.x).normalized() * hw
			var sm := (d[i] + d[i + 1]) * 0.5
			var t := minf(ta + sm / sp, tb + (float(e.len) - sm) / sp)
			st.set_color(cover_color(t))
			var up := Vector3(0, 0.45, 0)
			for q in [p0 - side, p0 + side, p1 + side, p0 - side, p1 + side, p1 - side]:
				st.add_vertex((q as Vector3) + up)
			any = true
	_cover_mesh.mesh = st.commit() if any else null
	_cover_mesh.visible = any


# --- Bilan et sauvegarde --------------------------------------------------------------------

func average(service: String) -> float:
	var s: Dictionary = stats[service]
	return float(s.total) / float(s.n) if int(s.n) > 0 else INF


func summary() -> String:
	var bits: Array[String] = []
	for s in SERVICES:
		if int(stats[s].n) > 0:
			bits.append("%s %s" % [String(SERVICE_NAMES[s]).get_slice(" ", 0), format_time(average(s))])
	return "Urgences : %d en cours%s" % [incidents.size(), "" if bits.is_empty() else " · moy. " + ", ".join(bits)]


func to_dict() -> Dictionary:
	var st := {}
	for k in stats:
		if stats[k] is Dictionary:
			var s: Dictionary = stats[k]
			st[k] = {"n": s.n, "total": s.total, "best": -1.0 if float(s.best) == INF else s.best, "worst": s.worst}
		else:
			st[k] = stats[k]
	return {"version": 1, "appels_auto": random_calls, "stats": st}


func from_dict(d: Dictionary) -> void:
	clear()
	random_calls = bool(d.get("appels_auto", true))
	var st: Dictionary = d.get("stats", {})
	for k in st:
		if stats.has(k) and stats[k] is Dictionary and st[k] is Dictionary:
			var s: Dictionary = st[k]
			stats[k] = {"n": int(s.get("n", 0)), "total": float(s.get("total", 0.0)),
				"best": INF if float(s.get("best", -1.0)) < 0.0 else float(s.best), "worst": float(s.get("worst", 0.0))}
		elif stats.has(k):
			stats[k] = int(st[k])
	_sync_stations()
