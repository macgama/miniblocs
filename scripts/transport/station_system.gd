class_name StationSystem
extends Node3D
## Stations et lignes de transport en commun.
##
## Stations posées sur le réseau (un nœud du graphe) : arrêt de bus, arrêt de
## tram, gare, port. Stations posées seules sur le terrain : héliport,
## aérodrome, aéroport (piste, aire de stationnement, aérogare, tour).
##
## Une ligne relie des stations du même genre dans l'ordre choisi par le joueur.
## Ses véhicules (modèle du catalogue, nombre au choix) font la navette d'un
## bout à l'autre et marquent un arrêt à chaque station. Les avions décollent,
## volent d'un aéroport à l'autre et atterrissent.

signal info_changed(text: String)
signal message(text: String)
signal lines_changed

enum Tool { NONE, PLACE, LINE, DEMOLISH }

const ROAD := TransportTypes.Mode.ROAD
const RAIL := TransportTypes.Mode.RAIL
const WATER := TransportTypes.Mode.WATER
const AIR := TransportTypes.Mode.AIR

## kind : genre de ligne (bus, tram, train, bateau, avion).
## classes : classes de voie acceptées ([] = toutes celles du mode).
## len : longueur des quais (stations du réseau) ou de la piste (stations aériennes).
const TYPES := {
	"arret_bus": {"name": "Arrêt de bus", "mode": ROAD, "kind": "bus", "classes": [], "len": 14.0,
		"desc": "Abri et poteau au bord d'une route."},
	"arret_tram": {"name": "Arrêt de tram", "mode": RAIL, "kind": "tram", "classes": ["tram"], "len": 36.0,
		"desc": "Deux quais bas de part et d'autre des voies de tram."},
	"gare": {"name": "Gare", "mode": RAIL, "kind": "train", "classes": ["train", "lgv"], "len": 160.0,
		"desc": "Quais, marquise et bâtiment voyageurs, sur une ligne classique ou une LGV."},
	"port": {"name": "Port", "mode": WATER, "kind": "bateau", "classes": [], "len": 60.0,
		"desc": "Jetée, grue et gare maritime, sur une voie d'eau."},
	"depot": {"name": "Dépôt de marchandises", "mode": ROAD, "kind": "camion", "classes": [], "len": 40.0,
		"desc": "Entrepôt et quai de chargement au bord d'une route : des camions y chargent et déchargent."},
	"parking": {"name": "Parking", "mode": ROAD, "kind": "parking", "classes": ["rue", "avenue", "departementale"], "len": 36.0,
		"desc": "Parking de 28 places au bord d'une route : les voitures de passage viennent s'y garer un moment."},
	"heliport": {"name": "Héliport", "mode": AIR, "kind": "avion", "len": 0.0, "pad": 24.0, "flat": 2.0,
		"desc": "Plateforme pour hélicoptères et taxis volants."},
	"aerodrome": {"name": "Aérodrome", "mode": AIR, "kind": "avion", "len": 600.0, "width": 30.0, "flat": 8.0,
		"desc": "Piste en herbe de 600 m et un hangar."},
	"aeroport": {"name": "Aéroport", "mode": AIR, "kind": "avion", "len": 1000.0, "width": 45.0, "flat": 20.0,
		"desc": "Piste de 1 000 × 45 m, aire de stationnement, aérogare et tour de contrôle."},
}
const ORDER := ["arret_bus", "arret_tram", "gare", "port", "heliport", "aerodrome", "aeroport", "depot", "parking"]
const KIND_NAMES := {"bus": "Bus", "tram": "Tramway", "train": "Train", "bateau": "Bateau", "avion": "Avion", "parking": "Parking", "camion": "Camions"}
## Noms des lignes de marchandises.
const FREIGHT_NAMES := {"train": "Fret ferroviaire", "bateau": "Fret par bateau", "camion": "Camions"}
## Genres de ligne qui peuvent transporter des marchandises.
const FREIGHT_KINDS := ["train", "bateau", "camion"]
## Places de parking : largeur, profondeur, allée (m).
const SPOT_W := 2.5
const SPOT_D := 5.0
const AISLE := 6.0
const LINE_COLORS := [Color("e63946"), Color("2a9d8f"), Color("f4a261"), Color("457b9d"), Color("9d4edd"),
	Color("e9c46a"), Color("06d6a0"), Color("ef476f"), Color("118ab2"), Color("8d6e63")]
## Arrêt en station (s).
const DWELL := 12.0
## Altitude de croisière des avions (m) : basse, pour qu'on les voie.
const CRUISE := 260.0

var transport: TransportSystem
var network: TransportNetwork
var traffic: Traffic
var world: TerrainWorld
var camera: Camera3D

var stations: Dictionary = {}
var lines: Dictionary = {}
var next_id := 1

var tool: Tool = Tool.NONE
var place_type := "arret_bus"
var _rot := 0.0
var _cursor := Vector3.ZERO
var _cursor_valid := false
var _pending: Array[int] = []
var _check := {}

var _views: Dictionary = {}
var _material: StandardMaterial3D
var _ghost: MeshInstance3D
var _ok_mat: StandardMaterial3D
var _bad_mat: StandardMaterial3D
var _marker: MeshInstance3D
var _mesh_cache: Dictionary = {}
var _right_press := Vector2.ZERO


func setup(t: TransportSystem) -> void:
	transport = t
	network = t.network
	traffic = t.traffic
	world = t.world
	camera = t.camera
	network.changed.connect(_on_network_changed)
	traffic.restarted.connect(respawn_all)
	traffic.line_arrived.connect(_on_line_arrived)
	_material = StandardMaterial3D.new()
	_material.vertex_color_use_as_albedo = true
	_material.vertex_color_is_srgb = true
	_material.roughness = 0.75
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ok_mat = TransportSystem._tint(Color(0.35, 0.95, 0.45, 0.55))
	_bad_mat = TransportSystem._tint(Color(1.0, 0.3, 0.25, 0.55))
	_ghost = MeshInstance3D.new()
	_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ghost)
	_marker = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 3.0
	cyl.bottom_radius = 3.0
	cyl.height = 0.4
	_marker.mesh = cyl
	_marker.visible = false
	add_child(_marker)


static func get_type(id: String) -> Dictionary:
	return TYPES.get(id, {})


func clear() -> void:
	for id in stations.keys():
		_drop_view(id)
	stations.clear()
	lines.clear()
	_pending.clear()
	next_id = 1
	traffic.remove_line_vehicles(-1)
	_sync_parkings()
	lines_changed.emit()


# --- Outils ---------------------------------------------------------------------------

func set_place(type_id: String) -> void:
	tool = Tool.PLACE
	place_type = type_id
	_pending.clear()
	var t := get_type(type_id)
	var how := "clic sur une voie" if int(t.mode) != AIR else "clic sur un terrain plat, R : tourner"
	info_changed.emit("%s : %s · %s\n%s" % [t.name, how, "Échap : terminer", t.desc])
	_refresh_preview()


func set_line_tool() -> void:
	tool = Tool.LINE
	_pending.clear()
	_ghost.mesh = null
	info_changed.emit("Nouvelle ligne : clique les stations dans l'ordre · Entrée ou clic droit : créer · Échap : annuler")


func set_demolish() -> void:
	tool = Tool.DEMOLISH
	_ghost.mesh = null
	info_changed.emit("Supprimer une station : clic dessus")


func set_inactive() -> void:
	tool = Tool.NONE
	_pending.clear()
	if _ghost:
		_ghost.mesh = null
		_marker.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if tool == Tool.NONE or camera == null or world == null:
		return
	if event is InputEventMouseMotion:
		_update_cursor((event as InputEventMouseMotion).position)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				_right_press = mb.position
			elif mb.position.distance_to(_right_press) < 5.0 and tool == Tool.LINE:
				finish_line()
			return
		if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
			return
		_update_cursor(mb.position)
		if not _cursor_valid:
			return
		match tool:
			Tool.PLACE:
				var res := place(place_type, _cursor, _rot)
				message.emit(res.reason if not res.ok else "%s posé : %s." % [get_type(place_type).name, stations[res.id].name])
			Tool.LINE:
				var sid := station_at(_cursor)
				if sid < 0:
					message.emit("Clique sur une station.")
				elif get_type(stations[sid].type).kind == "parking":
					message.emit("Un parking ne se dessert pas par une ligne.")
				elif not _pending.is_empty() and get_type(stations[sid].type).kind != get_type(stations[_pending[0]].type).kind:
					message.emit("Une ligne relie des stations du même genre (%s)." % KIND_NAMES[get_type(stations[_pending[0]].type).kind].to_lower())
				elif not _pending.is_empty() and _pending[_pending.size() - 1] == sid:
					pass
				else:
					_pending.append(sid)
					info_changed.emit("Nouvelle ligne : %s · Entrée : créer" % " → ".join(_pending.map(func(i: int) -> String: return stations[i].name)))
			Tool.DEMOLISH:
				var sid2 := station_at(_cursor)
				if sid2 >= 0:
					var n: String = stations[sid2].name
					remove_station(sid2)
					message.emit("%s supprimé." % n)
	elif event is InputEventKey:
		var key := event as InputEventKey
		if not key.pressed or key.echo:
			return
		if key.keycode == KEY_R and tool == Tool.PLACE:
			_rot = fmod(_rot + PI / 12.0, TAU)
			_refresh_preview()
			get_viewport().set_input_as_handled()
		elif (key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER) and tool == Tool.LINE:
			finish_line()
			get_viewport().set_input_as_handled()
		elif key.keycode == KEY_ESCAPE:
			if tool == Tool.LINE and not _pending.is_empty():
				_pending.clear()
				set_line_tool()
			else:
				set_inactive()
				info_changed.emit("")
			get_viewport().set_input_as_handled()


func _update_cursor(screen: Vector2) -> void:
	var hit: Variant = world.pick_point(camera.project_ray_origin(screen), camera.project_ray_normal(screen))
	_cursor_valid = hit != null
	if _cursor_valid:
		_cursor = hit
	_refresh_preview()


func _refresh_preview() -> void:
	if _ghost == null:
		return
	_marker.visible = false
	_ghost.mesh = null
	if not _cursor_valid:
		return
	if tool == Tool.LINE or tool == Tool.DEMOLISH:
		var sid := station_at(_cursor)
		if sid >= 0:
			_marker.visible = true
			_marker.position = stations[sid].pos + Vector3(0, 6, 0)
			_marker.material_override = _ok_mat if tool == Tool.LINE else _bad_mat
		return
	if tool != Tool.PLACE:
		return
	var t := get_type(place_type)
	if int(t.mode) == AIR:
		_check = check_air(place_type, _cursor, _rot)
		var pos: Vector3 = _check.pos
		_ghost.mesh = _air_mesh(place_type)
		_ghost.position = pos + Vector3(0, 0.3, 0)
		_ghost.basis = Basis(Vector3.UP, _rot)
		_ghost.material_override = _ok_mat if _check.ok else _bad_mat
		info_changed.emit("%s : %s" % [t.name, "clic pour poser · R : tourner" if _check.ok else _check.reason])
	else:
		_check = check_network(place_type, _cursor)
		_marker.visible = true
		_marker.position = (_check.pos as Vector3) + Vector3(0, 1, 0)
		_marker.material_override = _ok_mat if _check.ok else _bad_mat
		info_changed.emit("%s : %s" % [t.name, "clic pour poser" if _check.ok else _check.reason])


# --- Pose ---------------------------------------------------------------------------------

## Vérifie une station du réseau : {ok, reason, pos, snap}.
func check_network(type_id: String, p: Vector3) -> Dictionary:
	var t := get_type(type_id)
	var res := {"ok": false, "reason": "", "pos": p, "snap": {}}
	var snap := network.find_snap(p, int(t.mode), 3.0)
	if snap.is_empty():
		res.reason = "Pose-le sur une voie : %s." % TransportTypes.MODE_NAMES[int(t.mode)].to_lower()
		return res
	res.pos = snap.pos
	res.snap = snap
	var cls := _class_at(snap)
	var allowed: Array = t.classes
	if not allowed.is_empty() and not allowed.has(cls):
		res.reason = "Il faut une voie de type %s." % " ou ".join(allowed.map(func(c: String) -> String: return String(TransportTypes.get_type(c).name).to_lower()))
		return res
	if int(snap.node) >= 0 and network.adjacency.get(int(snap.node), []).size() > 2:
		res.reason = "Pas sur un carrefour."
		return res
	for sid in stations:
		var s: Dictionary = stations[sid]
		if int(get_type(s.type).mode) == int(t.mode) and (s.pos as Vector3).distance_to(snap.pos) < (float(get_type(s.type).len) + float(t.len)) / 2.0 + 4.0:
			res.reason = "Trop près de %s." % s.name
			return res
	res.ok = true
	return res


func _class_at(snap: Dictionary) -> String:
	if int(snap.get("edge", -1)) >= 0 and network.edges.has(int(snap.edge)):
		return network.edges[int(snap.edge)].t
	for eid in network.adjacency.get(int(snap.get("node", -1)), []):
		return network.edges[eid].t
	return ""


## Vérifie une station aérienne : {ok, reason, pos (centre, hauteur de la plateforme)}.
func check_air(type_id: String, p: Vector3, rot: float) -> Dictionary:
	var t := get_type(type_id)
	var res := {"ok": false, "reason": "", "pos": p}
	var cells := air_cells(type_id, p, rot, 4.0)
	var lo := INF
	var hi := -INF
	var sum := 0.0
	var n := 0
	for c in cells:
		var h := world.cell_height(c)
		if is_nan(h):
			# La piste peut sortir de la zone chargée : on demande les tuiles.
			for c2 in cells:
				var px := world._pixel_x(c2.x + 0.5)
				var py := world._pixel_y(c2.y + 0.5)
				world.tiles.request_tile(Vector2i(floori(px) >> 8, floori(py) >> 8))
			res.reason = "Relief encore en chargement."
			return res
		lo = minf(lo, h)
		hi = maxf(hi, h)
		sum += h
		n += 1
	var top := snappedf(sum / maxf(n, 1), world.height_step if world else 0.5)
	res.pos = Vector3(p.x, top, p.z)
	if lo <= 0.2:
		res.reason = "Pas sur l'eau."
		return res
	if hi - lo > float(t.flat):
		res.reason = "Terrain trop en pente (%d m d'écart, %d m au plus)." % [roundi(hi - lo), roundi(float(t.flat))]
		return res
	for c in cells:
		if transport.is_cell_occupied(c):
			res.reason = "Une voie ou une station passe sur l'emplacement."
			return res
		if transport.blocker.is_valid() and transport.blocker.call(c):
			res.reason = "Un bâtiment se trouve sur l'emplacement."
			return res
	res.ok = true
	return res


## Pose une station. Renvoie {ok, reason, id}.
func place(type_id: String, p: Vector3, rot := 0.0, name_ := "") -> Dictionary:
	var t := get_type(type_id)
	if t.is_empty():
		return {"ok": false, "reason": "Type de station inconnu."}
	var st := {"type": type_id, "node": -1, "name": name_}
	if int(t.mode) == AIR:
		var c := check_air(type_id, p, rot)
		if not c.ok:
			return c
		st.pos = c.pos
		st.dir = Vector3(sin(rot), 0, cos(rot)) * -1.0
		var flat := {}
		for cell in air_cells(type_id, c.pos, rot):
			flat[cell] = float((c.pos as Vector3).y)
		world.set_cells(flat)
	else:
		var c := check_network(type_id, p)
		if not c.ok:
			return c
		var snap: Dictionary = c.snap
		var node := int(snap.node)
		if node < 0:
			node = network.split_edge(int(snap.edge), float(snap.s), 2.0)
		st.node = node
		st.pos = network.node_pos(node)
		st.dir = _node_dir(node)
	var id := next_id
	next_id += 1
	st.id = id
	if String(st.name) == "":
		st.name = _auto_name(type_id)
	stations[id] = st
	if int(t.mode) != AIR:
		network.changed.emit()
	else:
		_update_footprint(id)
		_refresh_station(id)
	return {"ok": true, "reason": "", "id": id}


func _auto_name(type_id: String) -> String:
	var n := 1
	for sid in stations:
		if stations[sid].type == type_id:
			n += 1
	return "%s %d" % [get_type(type_id).name, n]


func _node_dir(node: int) -> Vector3:
	for eid in network.adjacency.get(node, []):
		var d := network.leave_dir(eid, node)
		d.y = 0
		if d.length_squared() > 1e-6:
			return d.normalized()
	return Vector3.FORWARD


## Station la plus proche d'un point (dans son emprise), ou -1.
func station_at(p: Vector3) -> int:
	var best := -1
	var best_d := INF
	for sid in stations:
		var s: Dictionary = stations[sid]
		var t := get_type(s.type)
		var reach := maxf(float(t.len) / 2.0, 14.0) + 6.0
		var d := Vector2(p.x - s.pos.x, p.z - s.pos.z).length()
		if d < reach and d < best_d:
			best_d = d
			best = sid
	return best


func remove_station(id: int) -> void:
	if not stations.has(id):
		return
	var s: Dictionary = stations[id]
	var old := _sample(s.type, s.pos, s.dir, _station_hw(s), 8.0)
	stations.erase(id)
	_drop_view(id)
	if world != null:
		world.mark_cells_dirty(old)
	for lid in lines.keys():
		var l: Dictionary = lines[lid]
		(l.stops as Array).erase(id)
		if (l.stops as Array).size() < 2:
			remove_line(lid)
		else:
			_respawn(lid)
	_sync_parkings()
	lines_changed.emit()


func _on_network_changed() -> void:
	for sid in stations.keys():
		var s: Dictionary = stations[sid]
		if int(get_type(s.type).mode) == AIR:
			continue
		if not network.nodes.has(int(s.node)):
			remove_station(sid)
			continue
		var moved: bool = not s.has("rects") or (s.pos as Vector3).distance_to(network.node_pos(int(s.node))) > 0.01 \
			or float(s.get("hw", -1.0)) != _station_hw(s)
		if not moved:
			continue
		s.pos = network.node_pos(int(s.node))
		s.dir = _node_dir(int(s.node))
		s.hw = _station_hw(s)
		_update_footprint(sid)
		_refresh_station(sid)
	_sync_parkings()


## Places des parkings, en coordonnées du monde, données à la circulation :
## id de nœud -> {"spots": Array[Transform3D], "used": Array[int]} (uid du véhicule garé, 0 si libre).
func _sync_parkings() -> void:
	var out := {}
	for sid in stations:
		var s: Dictionary = stations[sid]
		if s.type != "parking" or not network.nodes.has(int(s.node)):
			continue
		var node := int(s.node)
		var old: Dictionary = traffic.parkings.get(node, {})
		var spots: Array = parking_spots(s.pos, s.dir, _station_hw(s))
		var used: Array = old.get("used", [])
		used.resize(spots.size())
		for i in used.size():
			if used[i] == null:
				used[i] = 0
		out[node] = {"spots": spots, "used": used, "station": sid}
	traffic.set_parkings(out)


## Places d'un parking (repère : route le long de fwd, parking à droite).
static func parking_spots(pos: Vector3, fwd: Vector3, hw: float) -> Array:
	var right := Vector3(-fwd.z, 0, fwd.x)
	var half := float(TYPES.parking.len) / 2.0
	var out: Array = []
	var n := floori((half * 2.0 - 2.0) / SPOT_W)
	for row in 2:
		# Rangée côté route (nez vers la route) puis rangée du fond (nez vers le fond).
		var v := hw + 1.0 + SPOT_D * 0.5 if row == 0 else hw + 1.0 + SPOT_D + AISLE + SPOT_D * 0.5
		var face := -right if row == 0 else right
		for i in n:
			var u := -half + 1.0 + SPOT_W * (i + 0.5)
			var p := pos + fwd * u + right * v + Vector3(0, 0.14, 0)
			out.append(Transform3D(Basis.looking_at(face, Vector3.UP), p))
	return out


# --- Lignes ---------------------------------------------------------------------------------

func finish_line() -> Dictionary:
	var res := create_line(_pending)
	_pending.clear()
	if res.ok:
		message.emit("%s créée : %d stations, %d véhicule(s)." % [lines[res.id].name, lines[res.id].stops.size(), lines[res.id].count])
	else:
		message.emit(res.reason)
	set_line_tool()
	return res


## Crée une ligne passant par les stations données. Renvoie {ok, reason, id}.
## fret : ligne de marchandises (trains et bateaux ; toujours vrai pour les camions).
func create_line(stops: Array, model := "", count := 2, fret := false) -> Dictionary:
	var clean: Array[int] = []
	for s in stops:
		if stations.has(int(s)) and (clean.is_empty() or clean[clean.size() - 1] != int(s)):
			clean.append(int(s))
	if clean.size() < 2:
		return {"ok": false, "reason": "Une ligne relie au moins deux stations."}
	var kind: String = get_type(stations[clean[0]].type).kind
	if kind == "parking":
		return {"ok": false, "reason": "Un parking ne se dessert pas par une ligne."}
	for s in clean:
		if get_type(stations[s].type).kind != kind:
			return {"ok": false, "reason": "Toutes les stations d'une ligne doivent être du même genre."}
	if kind != "avion":
		for i in clean.size() - 1:
			var a: int = stations[clean[i]].node
			var b: int = stations[clean[i + 1]].node
			if network.find_route(a, b).is_empty():
				return {"ok": false, "reason": "Pas de voie entre %s et %s." % [stations[clean[i]].name, stations[clean[i + 1]].name]}
	fret = kind == "camion" or (fret and FREIGHT_KINDS.has(kind))
	var models := models_for(kind, clean, fret)
	if models.is_empty():
		return {"ok": false, "reason": "Aucun véhicule ne peut desservir ces stations."}
	if model == "" or not models.has(model):
		model = _default_model(kind, models)
	var id := next_id
	next_id += 1
	lines[id] = {"id": id, "name": _line_name(kind, fret), "kind": kind, "stops": clean, "fret": fret, "tonnes": 0.0,
		"model": model, "count": clampi(count, 1, 30), "color": LINE_COLORS[(id - 1) % LINE_COLORS.size()]}
	_respawn(id)
	lines_changed.emit()
	return {"ok": true, "reason": "", "id": id}


func _line_name(kind: String, fret: bool) -> String:
	var base: String = FREIGHT_NAMES[kind] if fret else KIND_NAMES[kind]
	var n := 1
	for lid in lines:
		if String(lines[lid].name).begins_with(base + " "):
			n += 1
	return "%s %d" % [base, n]


## Passe une ligne de train ou de bateau en fret (ou en voyageurs).
func set_fret(id: int, on: bool) -> void:
	if not lines.has(id):
		return
	var l: Dictionary = lines[id]
	if not FREIGHT_KINDS.has(String(l.kind)) or l.kind == "camion" or bool(l.get("fret", false)) == on:
		return
	var models := models_for(l.kind, l.stops, on)
	if models.is_empty():
		message.emit("Aucun véhicule de ce genre pour ces stations.")
		lines_changed.emit()
		return
	l.fret = on
	l.name = _line_name(l.kind, on)
	l.model = _default_model(l.kind, models)
	_respawn(id)
	lines_changed.emit()


## Chargement et déchargement : les lignes de fret comptent leurs tonnes.
func _on_line_arrived(line_id: int, model: String) -> void:
	if lines.has(line_id) and bool(lines[line_id].get("fret", false)):
		lines[line_id].tonnes = float(lines[line_id].get("tonnes", 0.0)) + VehicleCatalog.capacity_t(model)


func set_line(id: int, model: String, count: int) -> void:
	if not lines.has(id):
		return
	var l: Dictionary = lines[id]
	if models_for(l.kind, l.stops, bool(l.get("fret", false))).has(model):
		l.model = model
	l.count = clampi(count, 1, 30)
	_respawn(id)
	lines_changed.emit()


func remove_line(id: int) -> void:
	lines.erase(id)
	traffic.remove_line_vehicles(id)
	lines_changed.emit()


## Modèles du catalogue qui peuvent desservir une ligne de ce genre.
func models_for(kind: String, stops: Array = [], fret := false) -> Array[String]:
	var out: Array[String] = []
	var heli_only := false
	var rail_cls := ""
	for s in stops:
		if stations.has(int(s)):
			var st: Dictionary = stations[int(s)]
			if st.type == "heliport":
				heli_only = true
			if st.type == "gare":
				rail_cls = _class_at({"node": int(st.node), "edge": -1})
	for id in VehicleCatalog.TYPES:
		var t := VehicleCatalog.get_type(id)
		if t.get("hidden", false):
			continue
		if FREIGHT_KINDS.has(kind) and VehicleCatalog.is_freight(id) != (fret or kind == "camion"):
			continue
		match kind:
			"camion":
				if not (t.cat in ["utilitaire", "attelage"]):
					continue
			"bus":
				if t.cat != "bus":
					continue
			"tram":
				if String(t.get("rail", "")) != "tram":
					continue
			"train":
				if t.cat != "train":
					continue
			"bateau":
				if t.cat != "bateau":
					continue
			"avion":
				if t.cat != "avion":
					continue
				var vertical := String(t.get("kind", "")) in ["helico", "multirotor", "ballon"]
				if heli_only and not vertical:
					continue
		out.append(id)
	return out


func _default_model(kind: String, models: Array[String]) -> String:
	var prefer := {"bus": "bus_urbain", "tram": "tram_moderne", "train": "regional", "bateau": "bateau_bus", "avion": "court_courrier", "camion": "semi"}
	if not models.is_empty() and VehicleCatalog.is_freight(models[0]) and kind != "camion":
		prefer = {"train": "electrique_fret", "bateau": "peniche"}
	var era := traffic.era_filter
	var region := traffic.region_filter
	for id in models:
		if (era != "" or region != "") and VehicleCatalog.matches(id, era, region):
			return id
	if models.has(prefer.get(kind, "")):
		return prefer[kind]
	if kind == "avion" and models.has("helicoptere"):
		return "helicoptere"
	return models[0]


func respawn_all() -> void:
	for lid in lines:
		_respawn(lid)


func _respawn(id: int) -> void:
	traffic.remove_line_vehicles(id)
	if not lines.has(id) or not traffic.enabled:
		return
	var l: Dictionary = lines[id]
	var stops: Array = l.stops
	if l.kind == "avion":
		for k in int(l.count):
			var i := (k * stops.size()) / maxi(int(l.count), 1)
			traffic.add_air_vehicle(id, String(l.model), stops.size(), i, flight_path, -k * 9.0)
		return
	var nodes: Array[int] = []
	for s in stops:
		nodes.append(int(stations[int(s)].node))
	for k in int(l.count):
		var i := (k * nodes.size()) / maxi(int(l.count), 1)
		traffic.add_line_vehicle(id, String(l.model), nodes, i, -k * 4.0)


## Trajet d'un aéronef de la k-ième à la j-ième station de la ligne (points 3D).
func flight_path(line_id: int, from_i: int, to_i: int) -> PackedVector3Array:
	var l: Dictionary = lines.get(line_id, {})
	if l.is_empty():
		return PackedVector3Array()
	var a: Dictionary = stations.get(int(l.stops[from_i]), {})
	var b: Dictionary = stations.get(int(l.stops[to_i]), {})
	if a.is_empty() or b.is_empty():
		return PackedVector3Array()
	var la := float(get_type(a.type).len)
	var lb := float(get_type(b.type).len)
	var vt := VehicleCatalog.get_type(l.model)
	var vertical := String(vt.get("kind", "")) in ["helico", "multirotor", "ballon"] or la == 0.0
	var cruise := CRUISE if not vertical else 120.0
	var pa: Vector3 = a.pos
	var pb: Vector3 = b.pos
	var da: Vector3 = a.dir
	var db: Vector3 = b.dir
	var way: Array[Vector3] = []
	var lift_at := 0.0
	var touch_from_end := 0.0
	if vertical or la == 0.0:
		way.append(pa)
	else:
		way.append(pa - da * la * 0.45)
		way.append(pa + da * la * 0.45)
		lift_at = la * 0.5
	if vertical or lb == 0.0:
		way.append(pb)
	else:
		way.append(pb - db * (lb * 0.45 + 2500.0))
		way.append(pb - db * lb * 0.4)
		way.append(pb + db * lb * 0.3)
		touch_from_end = lb * 0.7
	# Rééchantillonnage tous les 15 m et profil en long.
	var flat := PackedVector3Array()
	for i in way.size() - 1:
		var p0: Vector3 = way[i]
		var p1: Vector3 = way[i + 1]
		var n := maxi(1, ceili(Vector2(p1.x - p0.x, p1.z - p0.z).length() / 15.0))
		for k in n:
			flat.append(p0.lerp(p1, float(k) / n))
	flat.append(way[way.size() - 1])
	var total := 0.0
	var dist := PackedFloat32Array([0.0])
	for i in range(1, flat.size()):
		total += Vector2(flat[i].x - flat[i - 1].x, flat[i].z - flat[i - 1].z).length()
		dist.append(total)
	var climb := 0.2 if not vertical else 4.0
	var out := PackedVector3Array()
	for i in flat.size():
		var s := dist[i]
		var ground := pa.y if s < total * 0.5 else pb.y
		var alt := minf(cruise, minf(maxf(0.0, s - lift_at) * climb, maxf(0.0, total - touch_from_end - s) * climb * 0.8))
		if vertical:
			alt = minf(cruise, minf(s * climb + (8.0 if s > 0.0 else 0.0), (total - s) * climb + (8.0 if s < total else 0.0)))
		out.append(Vector3(flat[i].x, ground + 0.25 + alt, flat[i].z))
	if vertical:
		# Montée et descente verticales.
		out.insert(1, Vector3(pa.x, pa.y + 0.25 + cruise * 0.5, pa.z))
		out.insert(out.size() - 1, Vector3(pb.x, pb.y + 0.25 + cruise * 0.5, pb.z))
	return out


func line_summary(id: int) -> String:
	var l: Dictionary = lines[id]
	var names: Array = (l.stops as Array).map(func(s: int) -> String: return stations[s].name if stations.has(s) else "?")
	var txt := "%s : %s" % [l.name, " ↔ ".join(names)]
	if bool(l.get("fret", false)):
		txt += "  ·  %s transportées" % format_tonnes(float(l.get("tonnes", 0.0)))
	return txt


static func format_tonnes(t: float) -> String:
	if t < 1000.0:
		return ("%.1f t" % t).replace(".", ",").replace(",0 t", " t")
	if t < 1.0e6:
		return ("%.1f kt" % (t / 1000.0)).replace(".", ",")
	return ("%.2f Mt" % (t / 1.0e6)).replace(".", ",")


# --- Emprises -------------------------------------------------------------------------------

## Rectangles d'emprise dans le repère de la station : [u0, u1, v0, v1]
## (u le long de la voie ou de la piste, v vers la droite).
func _rects(type_id: String, hw := 0.0) -> Array:
	var t := get_type(type_id)
	var half := float(t.len) / 2.0
	match type_id:
		"heliport":
			return [[-15.0, 15.0, -15.0, 15.0]]
		"aerodrome":
			return [[-half, half, -20.0, 20.0], [-30.0, 30.0, 20.0, 60.0]]
		"aeroport":
			return [[-half, half, -32.0, 32.0], [-15.0, 15.0, 32.0, 110.0], [-130.0, 130.0, 110.0, 260.0]]
		"arret_bus":
			return [[-half, half, hw + 0.2, hw + 3.4]]
		"arret_tram":
			return [[-half, half, hw + 0.2, hw + 3.4], [-half, half, -hw - 3.4, -hw - 0.2]]
		"parking":
			return [[-half, half, hw + 0.2, hw + 1.0 + SPOT_D * 2.0 + AISLE + 0.5]]
		"depot":
			return [[-half, half, hw + 0.2, hw + 26.0]]
		"gare":
			return [[-half, half, hw + 0.2, hw + 32.0], [-half, half, -hw - 6.4, -hw - 0.2]]
	return []


static func _fwd_of(rot: float) -> Vector3:
	return Vector3(sin(rot), 0, cos(rot)) * -1.0


## Cases d'une emprise, échantillonnées tous les step mètres.
func _sample(type_id: String, p: Vector3, fwd: Vector3, hw: float, step: float) -> Array[Vector2i]:
	var right := Vector3(-fwd.z, 0, fwd.x)
	var out: Array[Vector2i] = []
	var seen := {}
	for r in _rects(type_id, hw):
		var u := float(r[0])
		while u <= float(r[1]) + 0.001:
			var v := float(r[2])
			while v <= float(r[3]) + 0.001:
				var w := p + fwd * u + right * v
				var c := Vector2i(floori(w.x), floori(w.z))
				if not seen.has(c):
					seen[c] = true
					out.append(c)
				v += step
			u += step
	return out


## Cases d'une station aérienne (toutes, pour l'aplanissement).
func air_cells(type_id: String, p: Vector3, rot: float, step := 0.7) -> Array[Vector2i]:
	return _sample(type_id, p, _fwd_of(rot), 0.0, step)


func _station_hw(s: Dictionary) -> float:
	if int(get_type(s.type).mode) == AIR or not network.nodes.has(int(s.node)):
		return 0.0
	return network.node_half_width(int(s.node))


## Vrai si la case est dans l'emprise d'une station (quais, piste, aérogare…).
func occupies(c: Vector2i) -> bool:
	var q := Vector3(c.x + 0.5, 0, c.y + 0.5)
	for sid in stations:
		var s: Dictionary = stations[sid]
		var d: Vector3 = q - s.pos
		d.y = 0
		if d.length() > float(s.get("reach", 1e9)):
			continue
		var fwd: Vector3 = s.dir
		var u := d.dot(fwd)
		var v := d.dot(Vector3(-fwd.z, 0, fwd.x))
		for r in s.get("rects", []):
			if u >= float(r[0]) - 0.5 and u <= float(r[1]) + 0.5 and v >= float(r[2]) - 0.5 and v <= float(r[3]) + 0.5:
				return true
	return false


## Met à jour l'emprise d'une station et redessine le terrain autour (arbres).
func _update_footprint(sid: int, old_cells: Array = []) -> void:
	var s: Dictionary = stations[sid]
	var hw := _station_hw(s)
	s.rects = _rects(s.type, hw)
	var reach := 0.0
	for r in s.rects:
		reach = maxf(reach, Vector2(maxf(absf(r[0]), absf(r[1])), maxf(absf(r[2]), absf(r[3]))).length())
	s.reach = reach + 2.0
	if world != null:
		var cells: Array = _sample(s.type, s.pos, s.dir, hw, 8.0)
		cells.append_array(old_cells)
		world.mark_cells_dirty(cells)


# --- Modèles ---------------------------------------------------------------------------------

func _drop_view(id: int) -> void:
	if _views.has(id):
		(_views[id] as Node).queue_free()
		_views.erase(id)


func _refresh_station(id: int) -> void:
	_drop_view(id)
	var s: Dictionary = stations[id]
	var root := Node3D.new()
	root.position = s.pos
	var fwd: Vector3 = s.dir
	if fwd.length_squared() < 1e-6:
		fwd = Vector3.FORWARD
	root.basis = Basis.looking_at(fwd, Vector3.UP)
	add_child(root)
	_views[id] = root
	var mi := MeshInstance3D.new()
	mi.material_override = _material
	root.add_child(mi)
	var t := get_type(s.type)
	if int(t.mode) == AIR:
		mi.mesh = _air_mesh(s.type)
		# Au-dessus des cases du terrain (évite le scintillement).
		mi.position.y = 0.12
	else:
		var hw := network.node_half_width(int(s.node))
		mi.mesh = _network_mesh(s.type, hw)
		if s.type == "gare":
			var gid := _gare_building()
			if gid != "":
				var b := MeshInstance3D.new()
				b.mesh = _cached("bat:" + gid, func() -> ArrayMesh: return BuildingCatalog.build_mesh(gid))
				b.material_override = _material
				var bt := BuildingCatalog.get_type(gid)
				b.rotation.y = PI / 2.0
				b.position = Vector3(hw + 7.0 + float(bt.get("d", 20)) / 2.0, 0.0, 0.0)
				root.add_child(b)
	var label := Label3D.new()
	label.text = s.name
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 64
	label.pixel_size = 0.04 if int(t.mode) != AIR else 0.12
	label.outline_size = 12
	label.position = Vector3(0, 9.0 if int(t.mode) != AIR else 40.0, 0)
	label.no_depth_test = false
	root.add_child(label)


static func _gare_building() -> String:
	for id in ["haussmann__gare", "briques_ind__gare"]:
		if not BuildingCatalog.get_type(id).is_empty():
			return id
	for id in BuildingCatalog.all_types():
		if String(id).ends_with("__gare"):
			return id
	return ""


func _cached(key: String, make: Callable) -> ArrayMesh:
	if not _mesh_cache.has(key):
		_mesh_cache[key] = make.call()
	return _mesh_cache[key]


func _air_mesh(type_id: String) -> ArrayMesh:
	return _cached("air:" + type_id, func() -> ArrayMesh: return StationSystem.build_air_mesh(type_id))


func _network_mesh(type_id: String, hw: float) -> ArrayMesh:
	var key := "net:%s:%.1f" % [type_id, hw]
	return _cached(key, func() -> ArrayMesh: return StationSystem.build_network_mesh(type_id, hw))


const CONCRETE := Color("bdb8ad")
const ASPHALT := Color("4b4e54")
const WHITE := Color("f2f2f2")
const ROOF := Color("6c757d")


static func _shelter(k: VehicleMesh, x: float, z: float, len: float, side: float, col: Color) -> void:
	var back := x + side * 1.1
	for dz in [-len / 2.0 + 0.2, len / 2.0 - 0.2]:
		k.box(back, 0.15, z + dz, 0.1, 2.4, 0.1, ROOF)
	k.box(back, 0.35, z, 0.06, 2.0, len, Color(0.6, 0.75, 0.85))
	k.box(x + side * 0.4, 2.55, z, 1.9, 0.12, len + 0.3, col)
	k.box(back - side * 0.35, 0.15, z, 0.45, 0.5, len * 0.7, Color("8d6e63"))


## Modèle d'une station du réseau (repère : voie le long de Z, côté droit en +X).
static func build_network_mesh(type_id: String, hw: float) -> ArrayMesh:
	var k := VehicleMesh.new()
	var len := float(get_type(type_id).len)
	match type_id:
		"depot":
			# Cour, entrepôt, quai de chargement et piles de conteneurs.
			k.box(hw + 13.0, 0.0, 0, 25.6, 0.15, len, CONCRETE)
			k.box(hw + 19.0, 0.15, -4.0, 12.0, 8.0, 26.0, Color("a8a29e"))
			k.box(hw + 19.0, 8.15, -4.0, 12.6, 0.4, 26.6, Color("57534e"))
			k.box(hw + 12.6, 0.15, -4.0, 1.2, 1.2, 26.0, Color("78716c"))
			for i in 4:
				k.box(hw + 13.15, 1.4, -14.0 + i * 6.6, 0.1, 4.2, 4.0, Color("d6d3d1"))
			var cols := [Color("c1121f"), Color("1d4ed8"), Color("f77f00"), Color("2d6a4f"), Color("6b7280")]
			for i in 6:
				var z := 12.0 + (i % 3) * 2.7
				var lvl := i / 3
				k.box(hw + 6.0, 0.15 + lvl * 2.6, z, 6.1, 2.55, 2.45, cols[i % cols.size()])
			# Barrière d'entrée.
			k.box(hw + 0.6, 0.0, len / 2.0 - 1.0, 0.25, 1.1, 0.25, Color("dcdcdc"))
			k.box(hw + 0.6, 1.0, len / 2.0 - 4.0, 0.12, 0.12, 6.0, Color("e63946"))
		"parking":
			var depth := SPOT_D * 2.0 + AISLE + 1.0
			k.box(hw + 0.6 + depth / 2.0, 0.0, 0, depth, 0.12, len, ASPHALT)
			# Bordure, avec l'entrée au milieu.
			for zz in [-len / 4.0 - 2.0, len / 4.0 + 2.0]:
				k.box(hw + 0.4, 0.0, zz, 0.3, 0.25, len / 2.0 - 4.0, Color("dcdcdc"))
			k.box(hw + 1.0 + depth, 0.0, 0, 0.3, 0.3, len, Color("dcdcdc"))
			# Marquage des places.
			var n := floori((len - 2.0) / SPOT_W)
			for row in 2:
				var x0 := hw + 1.0 if row == 0 else hw + 1.0 + SPOT_D + AISLE
				for i in n + 1:
					var z := -len / 2.0 + 1.0 + SPOT_W * i
					k.box(x0 + SPOT_D / 2.0, 0.12, z, SPOT_D, 0.02, 0.12, WHITE)
			# Panneau P.
			k.box(hw + 0.6, 0.0, -len / 2.0 + 0.5, 0.12, 2.6, 0.12, ROOF)
			k.box(hw + 0.6, 2.6, -len / 2.0 + 0.5, 0.08, 0.8, 0.8, Color("1d4ed8"))
			k.box(hw + 0.55, 2.75, -len / 2.0 + 0.5, 0.02, 0.5, 0.1, WHITE)
			k.box(hw + 0.55, 2.9, -len / 2.0 + 0.6, 0.02, 0.2, 0.25, WHITE)
			# Quelques arbres en bout de rangée.
			for zz in [-len / 2.0 - 1.5, len / 2.0 + 1.5]:
				k.box(hw + 0.6 + depth / 2.0, 0.0, zz, 0.3, 2.2, 0.3, Color("6d4c41"))
				k.box(hw + 0.6 + depth / 2.0, 2.2, zz, 2.2, 2.0, 2.2, Color("4f8a3c"))
		"arret_bus":
			k.box(hw + 1.8, 0.0, 0, 3.2, 0.18, len, CONCRETE)
			k.box(hw + 0.25, 0.0, 0, 0.3, 0.2, len, Color("dcdcdc"))
			_shelter(k, hw + 2.0, 1.5, 5.0, 1.0, Color("2a9d8f"))
			k.box(hw + 0.9, 0.18, -len / 2.0 + 1.0, 0.1, 2.6, 0.1, ROOF)
			k.box(hw + 0.9, 2.4, -len / 2.0 + 1.0, 0.08, 0.6, 0.6, Color("ffb703"))
			for i in 5:
				k.box(hw - 1.6, 0.02, -len / 2.0 + 1.5 + i * 2.6, 3.0, 0.03, 0.3, Color("f6c90e"))
		"arret_tram":
			for side in [-1.0, 1.0]:
				k.box(side * (hw + 1.8), 0.0, 0, 3.2, 0.32, len, CONCRETE)
				k.box(side * (hw + 0.35), 0.32, 0, 0.3, 0.01, len, WHITE)
				_shelter(k, side * (hw + 2.0), 0.0, 8.0, side, Color("264653"))
				k.box(side * (hw + 2.6), 0.32, len / 2.0 - 3.0, 0.5, 1.6, 0.4, Color("e76f51"))
		"gare":
			for side in [-1.0, 1.0]:
				k.box(side * (hw + 3.3), 0.0, 0, 6.2, 0.55, len, CONCRETE)
				k.box(side * (hw + 0.45), 0.55, 0, 0.4, 0.01, len, WHITE)
				for i in 8:
					var z := -len * 0.3 + i * len * 0.6 / 7.0
					k.box(side * (hw + 3.6), 0.55, z, 0.2, 4.2, 0.2, Color("3d405b"))
				k.taper(side * (hw + 3.4), 4.7, 5.3, -len * 0.32, len * 0.32, 7.4, 6.6, 0.0, 0.0, Color("5c677d"))
				k.box(side * (hw + 4.6), 0.55, -len * 0.36, 0.6, 2.6, 0.6, Color("ffb703"))
			k.box(hw + 6.6, 0.0, 0, 0.4, 0.4, len, CONCRETE)
		"port":
			var x := hw + 8.0
			k.box(x, -3.0, 0, 14.0, 4.5, len, Color("9a958a"))
			k.box(x - 7.0, 1.4, 0, 0.3, 0.2, len, Color("ffd166"))
			for i in 6:
				k.cylinder(x - 6.4, 1.5, -len / 2.0 + 5.0 + i * (len - 10.0) / 5.0, 0.25, 0.2, 0.6, 6, Color("2b2d42"))
			k.box(x + 2.0, 1.5, len * 0.2, 9.0, 6.0, 16.0, Color("e9ecef"))
			k.box(x + 2.0, 3.6, len * 0.2, 9.1, 1.6, 15.0, Color("2b3d4f"))
			k.box(x + 2.0, 7.5, len * 0.2, 9.6, 0.4, 16.6, Color("e76f51"))
			# Grue.
			var gz := -len * 0.25
			for dx in [-2.0, 2.0]:
				for dz in [-2.0, 2.0]:
					k.box(x + dx, 1.5, gz + dz, 0.4, 14.0, 0.4, Color("f4a261"))
			k.box(x, 15.5, gz, 5.0, 2.5, 5.0, Color("f4a261"))
			k.box(x - 8.0, 17.0, gz, 26.0, 1.0, 1.2, Color("f4a261"))
			k.box(x - 14.0, 8.0, gz, 0.1, 9.0, 0.1, Color("2b2d42"))
	return k.to_mesh()


## Modèle d'une station aérienne (repère : piste le long de Z, installations en +X).
static func build_air_mesh(type_id: String) -> ArrayMesh:
	var k := VehicleMesh.new()
	var t := get_type(type_id)
	match type_id:
		"heliport":
			k.box(0, 0.0, 0, 24.0, 0.35, 24.0, Color("6c757d"))
			k.cylinder(0, 0.35, 0, 9.0, 9.0, 0.02, 24, Color("f6c90e"))
			k.cylinder(0, 0.37, 0, 8.4, 8.4, 0.02, 24, Color("6c757d"))
			k.box(-2.0, 0.39, 0, 0.8, 0.02, 7.0, WHITE)
			k.box(2.0, 0.39, 0, 0.8, 0.02, 7.0, WHITE)
			k.box(0, 0.39, 0, 4.0, 0.02, 0.8, WHITE)
			k.box(12.5, 0.0, 10.0, 0.1, 5.0, 0.1, ROOF)
			k.box(12.5, 4.6, 9.0, 0.3, 0.4, 2.0, Color("ff7f11"))
		"aerodrome":
			var l := float(t.len)
			k.box(0, 0.0, 0, float(t.width), 0.06, l, Color("5f8f3e"))
			for i in 10:
				k.box(-float(t.width) / 2.0, 0.06, -l / 2.0 + i * l / 9.0, 0.6, 0.3, 1.0, WHITE)
				k.box(float(t.width) / 2.0, 0.06, -l / 2.0 + i * l / 9.0, 0.6, 0.3, 1.0, WHITE)
			k.box(40.0, 0.0, 0, 22.0, 0.08, 40.0, Color("7f8c5a"))
			k.box(42.0, 0.0, -10.0, 18.0, 7.0, 16.0, Color("a3b18a"))
			k.z_cyl(42.0, 7.0, -18.0, -2.0, 9.0, 9.0, 8, Color("8a9a5b"), 0.4)
			k.box(42.0, 0.0, -18.05, 12.0, 6.0, 0.1, Color("495057"))
			k.box(25.0, 0.0, 20.0, 0.12, 6.0, 0.12, ROOF)
			k.z_cyl(25.0, 5.6, 20.0, 22.5, 0.35, 0.15, 6, Color("ff7f11"))
		_:
			var l2 := float(t.len)
			var w := float(t.width)
			k.box(0, 0.0, 0, w + 14.0, 0.05, l2 + 20.0, Color("8a9a5b"))
			k.box(0, 0.05, 0, w, 0.08, l2, ASPHALT)
			var n := int(l2 / 50.0)
			for i in n:
				k.box(0, 0.13, -l2 / 2.0 + 60.0 + i * (l2 - 120.0) / maxf(n - 1, 1), 0.9, 0.02, 30.0, WHITE)
			for e in [-1.0, 1.0]:
				for j in 8:
					k.box(-w / 2.0 + 4.0 + j * (w - 8.0) / 7.0, 0.13, e * (l2 / 2.0 - 15.0), 1.8, 0.02, 30.0, WHITE)
			for s in [-1.0, 1.0]:
				k.box(s * (w / 2.0 - 1.0), 0.13, 0, 0.9, 0.02, l2, WHITE)
			# Bretelle, aire de stationnement, aérogare, tour, hangar.
			k.box(w / 2.0 + 39.0, 0.05, 0, 78.0, 0.08, 23.0, ASPHALT)
			k.box(w / 2.0 + 39.0, 0.13, 0, 78.0, 0.02, 0.5, Color("f6c90e"))
			k.box(185.0, 0.05, 0, 150.0, 0.08, 260.0, Color("6c6f75"))
			for i in 5:
				k.box(150.0, 0.13, -100.0 + i * 50.0, 60.0, 0.02, 0.5, Color("f6c90e"))
			k.box(238.0, 0.0, 0, 40.0, 14.0, 180.0, Color("dfe7ec"))
			k.box(238.0, 2.5, 0, 40.3, 9.0, 176.0, Color("2b3d4f"))
			k.box(238.0, 14.0, 0, 44.0, 1.0, 184.0, Color("adb5bd"))
			for i in 4:
				k.box(212.0, 4.0, -90.0 + i * 60.0, 12.0, 3.0, 4.0, Color("adb5bd"))
			k.cylinder(205.0, 0.0, -150.0, 4.0, 3.0, 32.0, 10, Color("e9ecef"))
			k.cylinder(205.0, 32.0, -150.0, 7.0, 7.5, 5.0, 10, Color("2b3d4f"))
			k.cylinder(205.0, 37.0, -150.0, 7.8, 2.0, 2.0, 10, Color("6c757d"))
			k.box(190.0, 0.0, 165.0, 60.0, 16.0, 50.0, Color("b0b7c0"))
			k.z_cyl(190.0, 16.0, 140.0, 190.0, 30.0, 30.0, 10, Color("9aa3ad"), 0.25)
	return k.to_mesh()


# --- Sauvegarde ---------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var ss := []
	for sid in stations:
		var s: Dictionary = stations[sid]
		ss.append({"id": sid, "type": s.type, "node": s.node, "name": s.name,
			"p": [snappedf(s.pos.x, 0.01), snappedf(s.pos.y, 0.01), snappedf(s.pos.z, 0.01)], "d": [snappedf(s.dir.x, 0.0001), snappedf(s.dir.z, 0.0001)]})
	var ls := []
	for lid in lines:
		var l: Dictionary = lines[lid]
		ls.append({"id": lid, "name": l.name, "kind": l.kind, "stops": l.stops, "model": l.model, "count": l.count, "color": (l.color as Color).to_html(false),
			"fret": bool(l.get("fret", false)), "tonnes": snappedf(float(l.get("tonnes", 0.0)), 0.1)})
	return {"next_id": next_id, "stations": ss, "lines": ls}


func from_dict(data: Dictionary) -> void:
	clear()
	for s in data.get("stations", []):
		var id := int(s.id)
		var t := get_type(String(s.type))
		if t.is_empty():
			continue
		var node := int(s.get("node", -1))
		if int(t.mode) != AIR and not network.nodes.has(node):
			continue
		var p: Array = s.p
		var d: Array = s.d
		stations[id] = {"id": id, "type": String(s.type), "node": node, "name": String(s.name),
			"pos": Vector3(float(p[0]), float(p[1]), float(p[2])), "dir": Vector3(float(d[0]), 0, float(d[1]))}
		next_id = maxi(next_id, id + 1)
		_update_footprint(id)
		_refresh_station(id)
	_sync_parkings()
	for l in data.get("lines", []):
		var id := int(l.id)
		var stops: Array[int] = []
		for s in l.stops:
			if stations.has(int(s)):
				stops.append(int(s))
		if stops.size() < 2:
			continue
		lines[id] = {"id": id, "name": String(l.name), "kind": String(l.kind), "stops": stops, "model": String(l.model),
			"fret": bool(l.get("fret", String(l.kind) == "camion")), "tonnes": float(l.get("tonnes", 0.0)),
			"count": int(l.count), "color": Color(String(l.get("color", "e63946")))}
		next_id = maxi(next_id, id + 1)
	next_id = maxi(next_id, int(data.get("next_id", 1)))
	respawn_all()
	lines_changed.emit()
