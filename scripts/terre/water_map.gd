class_name WaterMap
extends Node
## Rivières et ruisseaux de la région, jusqu'aux plus étroits.
##
## Deux sources, la meilleure disponible gagne :
## 1. OpenStreetMap (via l'API Overpass) : les vrais cours d'eau avec leur nom,
##    leur largeur et les étangs. Nécessite Internet ; gardé en cache.
## 2. Calcul hydrologique sur le vrai relief (toujours disponible, hors ligne) :
##    on fait « couler la pluie » sur l'altitude réelle (≈ 30 m par pixel) et
##    on garde les cellules qui drainent assez de surface. Les ruisseaux suivent
##    ainsi les vraies vallées ; leur largeur grandit avec la surface drainée.
## Les lacs et grandes rivières viennent en plus d'ESA WorldCover (land_cover.gd).
##
## Le résultat est une liste de segments (rivières) et de polygones (étangs)
## en mètres locaux, rangés dans une grille de cases de 64 m pour les retrouver vite.

signal water_changed

enum Source { NONE, RELIEF, OSM }

## La région est découpée en zones de 10 × 10 km, chargées autour de la caméra.
const ZONE := 10000.0
## Les rivières d'une zone sont calculées sur ± 9 km autour de son centre
## (la zone + ses bassins versants), puis on ne garde que celles de la zone.
const HYDRO_ZOOM := 12
const HYDRO_MARGIN := 9000.0
## On prépare les zones voisines quand la caméra s'approche à moins de ça de leur bord.
const PRELOAD := 3000.0
## Surface drainée minimale pour qu'un ruisseau apparaisse (km²).
const MIN_AREA_KM2 := 0.6
const BUCKET := 64.0
## Largeur renvoyée par width_at() à l'intérieur d'un étang ou d'un lac.
const POND_WIDTH := 1000.0
## Demi-largeur minimale : un ruisseau de 1 m reste continu même en diagonale.
const MIN_HALF := 0.75
const OVERPASS_URL := "https://overpass-api.de/api/interpreter"
const CACHE_DIR := "user://water_cache"
const OSM_WIDTHS := {"river": 12.0, "canal": 8.0, "stream": 2.0, "brook": 1.5, "ditch": 1.0, "drain": 1.0, "tidal_channel": 4.0}

## Pour les tests : pas de réseau (ni Overpass, ni tuiles).
var offline := false
## Source de la dernière zone terminée (pour l'affichage).
var source: Source = Source.NONE
var status := ""

var origin_lat := 0.0
var origin_lon := 0.0

# Segments : extrémités, largeur, nom.
var seg_a := PackedVector2Array()
var seg_b := PackedVector2Array()
var seg_w := PackedFloat32Array()
var seg_name: Array[String] = []
var polys: Array[PackedVector2Array] = []
var poly_name: Array[String] = []
## Vector2i (case de 64 m) -> PackedInt32Array d'indices de segments
var _seg_buckets: Dictionary = {}
var _poly_buckets: Dictionary = {}

## Vector2i (zone) -> "osm" (en attente d'OpenStreetMap), "tiles", "queued",
## "running", ou une Source quand elle est terminée.
var _zones: Dictionary = {}
var _osm_queue: Array[Vector2i] = []
var _osm_zone := Vector2i(1 << 30, 0)
## OpenStreetMap injoignable une fois : on ne le redemande plus de la session.
var _osm_unreachable := false
var _hydro_queue: Array[Vector2i] = []
var _counts := {Source.OSM: 0, Source.RELIEF: 0}

var _tiles: ElevationTiles
var _http: HTTPRequest
var _generation := 0
var _hydro_running := false
var _hydro_task := -1
## Partagé avec le calcul en arrière-plan : [true] = abandonner.
var _hydro_cancel: Array = [false]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(CACHE_DIR)
	_tiles = ElevationTiles.new()
	_tiles.zoom = HYDRO_ZOOM
	add_child(_tiles)
	_tiles.tile_ready.connect(_on_tile_ready)
	_http = HTTPRequest.new()
	_http.timeout = 30.0
	add_child(_http)
	_http.request_completed.connect(_on_osm)


## Quitter pendant le calcul des rivières : on l'arrête et on l'attend.
func _exit_tree() -> void:
	_hydro_cancel[0] = true
	if _hydro_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_hydro_task)
		_hydro_task = -1


func _on_tile_ready(_t: Vector2i) -> void:
	_try_start_hydro()


func set_origin(lat: float, lon: float) -> void:
	origin_lat = lat
	origin_lon = lon
	_generation += 1
	_hydro_cancel[0] = true
	_clear()
	_zones.clear()
	_osm_queue.clear()
	_hydro_queue.clear()
	_osm_zone = Vector2i(1 << 30, 0)
	_counts = {Source.OSM: 0, Source.RELIEF: 0}
	source = Source.NONE
	status = "Calcul des rivières…"
	if offline or not is_inside_tree():
		return
	_http.cancel_request()
	request_zone(Vector2i.ZERO)


## Zone (10 × 10 km) qui contient le point local (x, z).
static func zone_of(x: float, z: float) -> Vector2i:
	return Vector2i(roundi(x / ZONE), roundi(z / ZONE))


## À appeler avec la position de la caméra : charge sa zone et, près d'un bord, la voisine.
func update_focus(x: float, z: float) -> void:
	if offline:
		return
	var k := zone_of(x, z)
	request_zone(k)
	var fx := x / ZONE - k.x
	var fz := z / ZONE - k.y
	var near := 0.5 - PRELOAD / ZONE
	var dx := 1 if fx > near else (-1 if fx < -near else 0)
	var dz := 1 if fz > near else (-1 if fz < -near else 0)
	if dx != 0:
		request_zone(k + Vector2i(dx, 0))
	if dz != 0:
		request_zone(k + Vector2i(0, dz))
	if dx != 0 and dz != 0:
		request_zone(k + Vector2i(dx, dz))


## Lance le chargement des rivières d'une zone (OpenStreetMap, sinon relief).
func request_zone(k: Vector2i) -> void:
	if offline or _zones.has(k) or not is_inside_tree():
		return
	_zones[k] = "osm"
	if _load_osm_cache(k):
		return
	if _osm_unreachable:
		_start_relief(k)
		return
	_osm_queue.append(k)
	_next_osm()


## Vrai quand la zone du point (x, z) a ses rivières (ou qu'on est hors ligne).
func is_ready_at(x: float, z: float) -> bool:
	return offline or typeof(_zones.get(zone_of(x, z), "")) == TYPE_INT


func is_ready() -> bool:
	return is_ready_at(0.0, 0.0)


## Rectangle (mètres locaux) couvert par une zone.
static func zone_rect(k: Vector2i) -> Rect2:
	return Rect2((k.x - 0.5) * ZONE, (k.y - 0.5) * ZONE, ZONE, ZONE)


func _zone_done(k: Vector2i, src: Source, count: int) -> void:
	_zones[k] = src
	source = src
	_counts[src] = int(_counts[src]) + count
	var parts := []
	if int(_counts[Source.OSM]) > 0:
		parts.append("OpenStreetMap (%d)" % _counts[Source.OSM])
	if int(_counts[Source.RELIEF]) > 0:
		parts.append("calculées depuis le relief (%d cours d'eau)" % _counts[Source.RELIEF])
	status = "Rivières : " + (", ".join(parts) if not parts.is_empty() else "aucune")
	water_changed.emit()


func _clear() -> void:
	seg_a = PackedVector2Array()
	seg_b = PackedVector2Array()
	seg_w = PackedFloat32Array()
	seg_name = []
	polys = []
	poly_name = []
	_seg_buckets = {}
	_poly_buckets = {}


# --- Requêtes ----------------------------------------------------------------

## Largeur (m) du cours d'eau qui couvre le point local (x, z), 0 sinon.
func width_at(x: float, z: float) -> float:
	var key := Vector2i(floori(x / BUCKET), floori(z / BUCKET))
	var p := Vector2(x, z)
	var ids: PackedInt32Array = _seg_buckets.get(key, PackedInt32Array())
	var best := 0.0
	for i in ids:
		var w := seg_w[i]
		if _dist_to_segment(p, seg_a[i], seg_b[i]) <= maxf(w * 0.5, MIN_HALF):
			best = maxf(best, w)
	if best > 0.0:
		return best
	var pids: PackedInt32Array = _poly_buckets.get(key, PackedInt32Array())
	for i in pids:
		if Geometry2D.is_point_in_polygon(p, polys[i]):
			return POND_WIDTH
	return 0.0


## Vrai si un cours d'eau ou un étang peut toucher le rectangle (mètres locaux).
func any_in_rect(x0: float, z0: float, x1: float, z1: float) -> bool:
	for bx in range(floori(x0 / BUCKET), floori(x1 / BUCKET) + 1):
		for bz in range(floori(z0 / BUCKET), floori(z1 / BUCKET) + 1):
			var key := Vector2i(bx, bz)
			if _seg_buckets.has(key) or _poly_buckets.has(key):
				return true
	return false


## Nom du cours d'eau (OpenStreetMap) au point, ou "".
func name_at(x: float, z: float) -> String:
	var key := Vector2i(floori(x / BUCKET), floori(z / BUCKET))
	var p := Vector2(x, z)
	for i in _seg_buckets.get(key, PackedInt32Array()):
		if seg_name[i] != "" and _dist_to_segment(p, seg_a[i], seg_b[i]) <= maxf(seg_w[i] * 0.5, MIN_HALF):
			return seg_name[i]
	for i in _poly_buckets.get(key, PackedInt32Array()):
		if poly_name[i] != "" and Geometry2D.is_point_in_polygon(p, polys[i]):
			return poly_name[i]
	return ""


static func _dist_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 < 1e-6:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_to(a + ab * t)


## Ajoute un cours d'eau (polyligne en mètres locaux).
func add_line(pts: PackedVector2Array, width: float, name := "") -> void:
	for i in pts.size() - 1:
		var id := seg_a.size()
		seg_a.append(pts[i])
		seg_b.append(pts[i + 1])
		seg_w.append(width)
		seg_name.append(name)
		var r := maxf(width * 0.5, MIN_HALF)
		var lo := Vector2(minf(pts[i].x, pts[i + 1].x) - r, minf(pts[i].y, pts[i + 1].y) - r)
		var hi := Vector2(maxf(pts[i].x, pts[i + 1].x) + r, maxf(pts[i].y, pts[i + 1].y) + r)
		_add_to_buckets(_seg_buckets, lo, hi, id)


## Ajoute un étang ou un lac (polygone en mètres locaux).
func add_polygon(pts: PackedVector2Array, name := "") -> void:
	if pts.size() < 3:
		return
	var id := polys.size()
	polys.append(pts)
	poly_name.append(name)
	var lo := pts[0]
	var hi := pts[0]
	for p in pts:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	_add_to_buckets(_poly_buckets, lo, hi, id)


static func _add_to_buckets(buckets: Dictionary, lo: Vector2, hi: Vector2, id: int) -> void:
	for bx in range(floori(lo.x / BUCKET), floori(hi.x / BUCKET) + 1):
		for bz in range(floori(lo.y / BUCKET), floori(hi.y / BUCKET) + 1):
			var key := Vector2i(bx, bz)
			var arr: PackedInt32Array = buckets.get(key, PackedInt32Array())
			arr.append(id)
			buckets[key] = arr


# --- Conversions ---------------------------------------------------------------

func _local_to_pixel12(x: float, z: float) -> Vector2:
	var lon := Geo.local_to_lon(origin_lat, origin_lon, x)
	var lat := Geo.local_to_lat(origin_lat, z)
	return Vector2(Geo.lon_to_pixel_x(lon, HYDRO_ZOOM), Geo.lat_to_pixel_y(lat, HYDRO_ZOOM))


func _lat_lon_to_local(lat: float, lon: float) -> Vector2:
	var x := deg_to_rad(lon - origin_lon) * Geo.EARTH_RADIUS * cos(deg_to_rad(origin_lat))
	var z := deg_to_rad(origin_lat - lat) * Geo.EARTH_RADIUS
	return Vector2(x, z)


static func _pixel_to_lat_lon(px: float, py: float, zoom: int) -> Vector2:
	var n := Geo.world_pixels(zoom)
	var lon := px / n * 360.0 - 180.0
	var lat := rad_to_deg(atan(sinh(PI * (1.0 - 2.0 * py / n))))
	return Vector2(lat, lon)


# --- Source 1 : OpenStreetMap ---------------------------------------------------

func _osm_cache_path(k: Vector2i) -> String:
	return "%s/osm_%.4f_%.4f_%d_%d.json" % [CACHE_DIR, origin_lat, origin_lon, k.x, k.y]


func _load_osm_cache(k: Vector2i) -> bool:
	var path := _osm_cache_path(k)
	if not FileAccess.file_exists(path):
		return false
	return _apply_osm_text(FileAccess.get_file_as_string(path), _generation, k)


## Une requête Overpass à la fois.
func _next_osm() -> void:
	if _osm_zone.x != 1 << 30 or _osm_queue.is_empty():
		return
	var k: Vector2i = _osm_queue.pop_front()
	if _osm_unreachable:
		_start_relief(k)
		_next_osm()
		return
	var r := zone_rect(k).grow(300.0)
	var sw := Vector2(Geo.local_to_lat(origin_lat, r.end.y), Geo.local_to_lon(origin_lat, origin_lon, r.position.x))
	var ne := Vector2(Geo.local_to_lat(origin_lat, r.position.y), Geo.local_to_lon(origin_lat, origin_lon, r.end.x))
	var bbox := "%.5f,%.5f,%.5f,%.5f" % [sw.x, sw.y, ne.x, ne.y]
	var q := "[out:json][timeout:25];(way[\"waterway\"~\"^(river|stream|canal|brook|ditch|drain|tidal_channel)$\"](%s);way[\"natural\"=\"water\"](%s););out geom;" % [bbox, bbox]
	var headers := PackedStringArray(["Content-Type: application/x-www-form-urlencoded", "User-Agent: MiniBlocs/0.1 (jeu Godot)"])
	_osm_zone = k
	_http.set_meta("gen", _generation)
	if _http.request(OVERPASS_URL, headers, HTTPClient.METHOD_POST, "data=" + q.uri_encode()) != OK:
		_osm_zone = Vector2i(1 << 30, 0)
		_osm_unreachable = true
		_start_relief(k)
		_next_osm()


func _on_osm(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var gen: int = _http.get_meta("gen", -1)
	var k := _osm_zone
	_osm_zone = Vector2i(1 << 30, 0)
	if gen != _generation:
		_next_osm()
		return
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		if result != HTTPRequest.RESULT_SUCCESS or code == 403:
			_osm_unreachable = true
		push_warning("OpenStreetMap injoignable (résultat %d, code %d) : rivières calculées depuis le relief." % [result, code])
		_start_relief(k)
	else:
		var text := body.get_string_from_utf8()
		if _apply_osm_text(text, gen, k):
			var f := FileAccess.open(_osm_cache_path(k), FileAccess.WRITE)
			if f:
				f.store_string(text)
		else:
			_start_relief(k) # réponse vide : pas de rivière connue, on calcule
	_next_osm()


## Lit une réponse Overpass (JSON, « out geom ») pour la zone k. Vrai si elle contient de l'eau.
func _apply_osm_text(text: String, gen: int, k := Vector2i.ZERO) -> bool:
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY or not data.has("elements"):
		return false
	var lines := []
	var areas := []
	for e in data.elements:
		if typeof(e) != TYPE_DICTIONARY or e.get("type") != "way" or not e.has("geometry"):
			continue
		var tags: Dictionary = e.get("tags", {})
		var pts := PackedVector2Array()
		for g in e.geometry:
			pts.append(_lat_lon_to_local(float(g.lat), float(g.lon)))
		var name := String(tags.get("name", ""))
		if tags.has("waterway"):
			var w: float = OSM_WIDTHS.get(String(tags.waterway), 2.0)
			var tw := String(tags.get("width", "")).replace(",", ".").split(" ")[0]
			if tw.is_valid_float():
				w = clampf(tw.to_float(), 0.5, 200.0)
			lines.append([pts, w, name])
		elif tags.get("natural") == "water" and pts.size() >= 4:
			areas.append([pts, name])
	if lines.is_empty() and areas.is_empty():
		return false
	if gen != _generation:
		return false
	for l in lines:
		add_line(l[0], l[1], l[2])
	for a in areas:
		add_polygon(a[0], a[1])
	_zone_done(k, Source.OSM, lines.size())
	return true


# --- Source 2 : calcul sur le relief -------------------------------------------

## Tuiles d'altitude (zoom 12) d'une zone et de ses bassins versants.
func _zone_tiles(k: Vector2i) -> Array[Vector2i]:
	var c := Vector2(k) * ZONE
	var p0 := _local_to_pixel12(c.x - HYDRO_MARGIN, c.y - HYDRO_MARGIN)
	var p1 := _local_to_pixel12(c.x + HYDRO_MARGIN, c.y + HYDRO_MARGIN)
	var out: Array[Vector2i] = []
	for tx in range(floori(p0.x / 256.0), floori(p1.x / 256.0) + 1):
		for ty in range(floori(p0.y / 256.0), floori(p1.y / 256.0) + 1):
			out.append(Vector2i(tx, ty))
	return out


func _start_relief(k: Vector2i) -> void:
	if typeof(_zones.get(k, "")) == TYPE_INT:
		return
	_zones[k] = "queued"
	for t in _zone_tiles(k):
		_tiles.request_tile(t)
	_hydro_queue.append(k)
	_try_start_hydro()


func _try_start_hydro() -> void:
	if _hydro_running or offline or _hydro_queue.is_empty():
		return
	# La première zone dont toutes les tuiles sont là.
	var k := Vector2i(1 << 30, 0)
	for z in _hydro_queue:
		var ok := true
		for t in _zone_tiles(z):
			if not _tiles.has_tile(t):
				ok = false
				break
		if ok:
			k = z
			break
	if k.x == 1 << 30:
		return
	_hydro_queue.erase(k)
	_zones[k] = "running"
	var c := Vector2(k) * ZONE
	var p0 := _local_to_pixel12(c.x - HYDRO_MARGIN, c.y - HYDRO_MARGIN)
	var p1 := _local_to_pixel12(c.x + HYDRO_MARGIN, c.y + HYDRO_MARGIN)
	var x0 := floori(p0.x)
	var y0 := floori(p0.y)
	var w := floori(p1.x) - x0 + 1
	var h := floori(p1.y) - y0 + 1
	var elev := PackedFloat32Array()
	elev.resize(w * h)
	for j in h:
		for i in w:
			elev[i + j * w] = _tiles.height_at_pixel(x0 + i, y0 + j)
	# Taille d'un pixel au sol (m) à cette latitude.
	var px_m := 2.0 * PI * Geo.EARTH_RADIUS * cos(deg_to_rad(origin_lat)) / Geo.world_pixels(HYDRO_ZOOM)
	_hydro_running = true
	var gen := _generation
	var cancel := [false]
	_hydro_cancel = cancel
	_hydro_task = WorkerThreadPool.add_task(func() -> void:
		var res := compute_streams(elev, w, h, px_m, cancel)
		_finish_hydro.call_deferred(res, x0, y0, gen, k))


func _finish_hydro(res: Dictionary, x0: int, y0: int, gen: int, k := Vector2i.ZERO) -> void:
	_hydro_running = false
	if _hydro_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_hydro_task)
		_hydro_task = -1
	if gen != _generation:
		_try_start_hydro()
		return
	# On ne garde que les tronçons de la zone (les voisines ont leur propre calcul).
	var rect := zone_rect(k)
	var count := 0
	for line in res.lines:
		var pts := PackedVector2Array()
		for p in (line[0] as PackedVector2Array):
			var ll := _pixel_to_lat_lon(x0 + p.x + 0.5, y0 + p.y + 0.5, HYDRO_ZOOM)
			pts.append(_lat_lon_to_local(ll.x, ll.y))
		var mid := (pts[0] + pts[pts.size() - 1]) * 0.5
		if not rect.has_point(mid):
			continue
		add_line(_chaikin(pts, 2), line[1])
		count += 1
	_zone_done(k, Source.RELIEF, count)
	_try_start_hydro()


## Écoulement de l'eau sur une grille d'altitude (algorithme « priority-flood ») :
## chaque cellule reçoit la direction vers laquelle elle se vide, même dans les
## cuvettes et les zones plates, puis on cumule la surface drainée.
## Renvoie {lines: [[PackedVector2Array (pixels), largeur m], ...]}.
## cancel : [true] pour abandonner en cours de route.
static func compute_streams(elev: PackedFloat32Array, w: int, h: int, px_m: float, cancel: Array = [false]) -> Dictionary:
	var n := w * h
	var parent := PackedInt32Array()
	parent.resize(n)
	parent.fill(-1)
	var seen := PackedByteArray()
	seen.resize(n)
	var order := PackedInt32Array()
	order.resize(n)
	var count := 0
	# File de priorité par paliers de 10 cm (« bucket queue »).
	var lo := INF
	var hi := -INF
	for v in elev:
		if not is_nan(v):
			lo = minf(lo, v)
			hi = maxf(hi, v)
	if lo == INF:
		return {"lines": []}
	var nb := int((hi - lo) * 10.0) + 2
	var buckets: Array[PackedInt32Array] = []
	buckets.resize(nb)
	for b in nb:
		buckets[b] = PackedInt32Array()
	var level := PackedFloat32Array()
	level.resize(n)
	var cur_b := nb
	# Graines : les bords et la mer.
	for idx in n:
		var x := idx % w
		var y := idx / w
		var e := elev[idx]
		if is_nan(e):
			e = lo
		if x == 0 or y == 0 or x == w - 1 or y == h - 1 or e <= 0.0:
			var b := clampi(int((e - lo) * 10.0), 0, nb - 1)
			buckets[b].append(idx)
			level[idx] = e
			seen[idx] = 1
			cur_b = mini(cur_b, b)
	var dx := [1, -1, 0, 0, 1, 1, -1, -1]
	var dy := [0, 0, 1, -1, 1, -1, 1, -1]
	var heads := PackedInt32Array()
	heads.resize(nb)
	var b := cur_b
	while b < nb:
		var bucket := buckets[b]
		if heads[b] >= bucket.size():
			b += 1
			continue
		var c := bucket[heads[b]]
		heads[b] += 1
		if (count & 0xffff) == 0 and cancel[0]:
			return {"lines": []}
		order[count] = c
		count += 1
		var cx := c % w
		var cy := c / w
		var lc := level[c]
		for k in 8:
			var nx: int = cx + dx[k]
			var ny: int = cy + dy[k]
			if nx < 0 or ny < 0 or nx >= w or ny >= h:
				continue
			var ni := nx + ny * w
			if seen[ni]:
				continue
			seen[ni] = 1
			parent[ni] = c
			var e := elev[ni]
			if is_nan(e):
				e = lc
			var l := maxf(e, lc)
			level[ni] = l
			var nbk := clampi(int((l - lo) * 10.0), 0, nb - 1)
			buckets[nbk].append(ni)
			if nbk < b:
				b = nbk
	# Surface drainée : des crêtes vers l'aval (ordre de visite inversé).
	var acc := PackedFloat32Array()
	acc.resize(n)
	acc.fill(1.0)
	for i in range(count - 1, -1, -1):
		var c := order[i]
		var p := parent[c]
		if p >= 0:
			acc[p] += acc[c]
	var cell_km2 := px_m * px_m / 1.0e6
	var min_cells := MIN_AREA_KM2 / cell_km2
	# Nombre d'affluents « cours d'eau » de chaque cellule.
	var kids := PackedByteArray()
	kids.resize(n)
	for c in n:
		var p := parent[c]
		if p >= 0 and acc[c] >= min_cells and elev[c] > 0.0:
			kids[p] = mini(kids[p] + 1, 255)
	# Polylignes : on part de chaque source ou confluence et on descend.
	var lines := []
	for c in n:
		if acc[c] < min_cells or elev[c] <= 0.0:
			continue
		if kids[c] == 1:
			continue # milieu d'un tronçon : traité depuis son amont
		# Découpé en tronçons de quelques pixels : la largeur grandit vers l'aval.
		var pts := PackedVector2Array([Vector2(c % w, c / w)])
		var cur := c
		while true:
			var p := parent[cur]
			if p < 0:
				if pts.size() >= 2:
					lines.append([pts, stream_width(acc[cur] * cell_km2)])
				break
			pts.append(Vector2(p % w, p / w))
			var last := kids[p] != 1 or elev[p] <= 0.0
			if last or pts.size() >= 6:
				lines.append([pts, stream_width(acc[p] * cell_km2)])
				pts = PackedVector2Array([Vector2(p % w, p / w)])
			if last:
				break
			cur = p
	return {"lines": lines}


## Largeur (m) d'un cours d'eau qui draine km2 km² : ~1 m pour un ruisseau
## naissant, ~8 m pour 100 km², 40 m au plus (les grands fleuves viennent de WorldCover).
static func stream_width(km2: float) -> float:
	return clampf(0.6 + 0.9 * pow(km2, 0.42), 1.0, 40.0)


## Adoucit une polyligne (algorithme de Chaikin), extrémités conservées.
static func _chaikin(pts: PackedVector2Array, iterations: int) -> PackedVector2Array:
	var cur := pts
	for it in iterations:
		if cur.size() < 3:
			return cur
		var out := PackedVector2Array([cur[0]])
		for i in cur.size() - 1:
			var a := cur[i]
			var b := cur[i + 1]
			out.append(a.lerp(b, 0.25))
			out.append(a.lerp(b, 0.75))
		out.append(cur[cur.size() - 1])
		cur = out
	return cur
