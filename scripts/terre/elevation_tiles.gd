class_name ElevationTiles
extends Node
## Source d'altitude réelle : tuiles « Terrarium » (Mapzen / AWS Open Data).
##
## Chaque tuile PNG de 256 × 256 pixels encode l'altitude dans ses couleurs :
##   altitude (m) = R × 256 + G + B / 256 − 32768
## Au zoom 15, un pixel couvre environ 4,8 m × cos(latitude) : le jeu
## interpole ensuite pour obtenir une valeur par case de 1 m.
## Les tuiles téléchargées sont gardées dans user://terrain_cache/ pour
## ne jamais les retélécharger (et jouer hors ligne ensuite).

signal tile_ready(tile: Vector2i)

const ZOOM := 15
const URL := "https://s3.amazonaws.com/elevation-tiles-prod/terrarium/%d/%d/%d.png"
const CACHE_DIR := "user://terrain_cache"
const MAX_PARALLEL := 4
const TILE_PIXELS := 256

## Niveau de zoom des tuiles (15 pour le terrain, 2 ou 3 pour le globe).
var zoom := ZOOM
## Garder aussi les images PNG brutes (utilisé par le globe pour sa texture).
var keep_images := false

## Si défini, aucune requête réseau : ce Callable(tile: Vector2i) -> PackedFloat32Array
## fabrique les tuiles (utilisé par les tests).
var offline_generator: Callable

## Vector2i -> PackedFloat32Array (256 × 256 altitudes, ligne par ligne)
var _tiles: Dictionary = {}
## Vector2i -> Image (seulement si keep_images)
var _images: Dictionary = {}
var _queued: Dictionary = {}
var _queue: Array[Vector2i] = []
var _free_requests: Array[HTTPRequest] = []
## HTTPRequest -> Vector2i (tuile en cours de téléchargement)
var _request_tile: Dictionary = {}
var _failed_count := 0
var _last_key := Vector2i(-1, -1)
var _last_tile: PackedFloat32Array


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(CACHE_DIR)
	for i in MAX_PARALLEL:
		var req := HTTPRequest.new()
		req.timeout = 25.0
		req.use_threads = true
		add_child(req)
		req.request_completed.connect(_on_completed.bind(req))
		_free_requests.append(req)


func has_tile(t: Vector2i) -> bool:
	return _tiles.has(t)


func loaded_count() -> int:
	return _tiles.size()


func pending_count() -> int:
	return _queued.size()


func failed_count() -> int:
	return _failed_count


## Demande une tuile : depuis le cache disque si possible, sinon téléchargement.
func request_tile(t: Vector2i) -> void:
	if _tiles.has(t) or _queued.has(t):
		return
	if offline_generator.is_valid():
		_store(t, offline_generator.call(t))
		return
	var path := _cache_path(t)
	if FileAccess.file_exists(path):
		var bytes := FileAccess.get_file_as_bytes(path)
		var heights := _decode(bytes)
		if heights.size() == TILE_PIXELS * TILE_PIXELS:
			_keep_image(t, bytes)
			_store(t, heights)
			return
	_queued[t] = true
	_queue.append(t)


func _process(_delta: float) -> void:
	while not _queue.is_empty() and not _free_requests.is_empty():
		var t: Vector2i = _queue.pop_front()
		var req: HTTPRequest = _free_requests.pop_back()
		_request_tile[req] = t
		if req.request(URL % [zoom, t.x, t.y]) != OK:
			_request_tile.erase(req)
			_free_requests.append(req)
			_fail(t)


func _on_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, req: HTTPRequest) -> void:
	var t: Vector2i = _request_tile.get(req, Vector2i(-1, -1))
	_request_tile.erase(req)
	_free_requests.append(req)
	_queued.erase(t)
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		push_warning("Tuile d'altitude %s non téléchargée (résultat %d, code HTTP %d)" % [t, result, code])
		_fail(t)
		return
	var heights := _decode(body)
	if heights.size() != TILE_PIXELS * TILE_PIXELS:
		_fail(t)
		return
	var f := FileAccess.open(_cache_path(t), FileAccess.WRITE)
	if f:
		f.store_buffer(body)
	_keep_image(t, body)
	_store(t, heights)


## Une tuile introuvable devient une tuile au niveau de la mer pour ne pas bloquer le jeu.
func _fail(t: Vector2i) -> void:
	_queued.erase(t)
	_failed_count += 1
	var flat := PackedFloat32Array()
	flat.resize(TILE_PIXELS * TILE_PIXELS)
	flat.fill(-1.0)
	_store(t, flat)


func _store(t: Vector2i, heights: PackedFloat32Array) -> void:
	_tiles[t] = heights
	tile_ready.emit(t)


func _keep_image(t: Vector2i, png: PackedByteArray) -> void:
	if not keep_images:
		return
	var img := Image.new()
	if img.load_png_from_buffer(png) == OK:
		img.convert(Image.FORMAT_RGB8)
		_images[t] = img


## Image PNG brute d'une tuile (couleurs encodant l'altitude), ou null.
func get_image(t: Vector2i) -> Image:
	return _images.get(t)


func _cache_path(t: Vector2i) -> String:
	return "%s/%d_%d_%d.png" % [CACHE_DIR, zoom, t.x, t.y]


static func _decode(png: PackedByteArray) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var img := Image.new()
	if png.is_empty() or img.load_png_from_buffer(png) != OK:
		return out
	if img.get_width() != TILE_PIXELS or img.get_height() != TILE_PIXELS:
		return out
	img.convert(Image.FORMAT_RGB8)
	var data := img.get_data()
	out.resize(TILE_PIXELS * TILE_PIXELS)
	for i in out.size():
		out[i] = data[i * 3] * 256.0 + data[i * 3 + 1] + data[i * 3 + 2] / 256.0 - 32768.0
	return out


## Tuile contenant le pixel global (px, py).
static func tile_of_pixel(px: float, py: float) -> Vector2i:
	return Vector2i(floori(px / TILE_PIXELS), floori(py / TILE_PIXELS))


## Altitude d'un pixel global (entiers). NAN si la tuile n'est pas encore chargée.
func height_at_pixel(ix: int, iy: int) -> float:
	var n := TILE_PIXELS << zoom
	ix = posmod(ix, n)
	iy = clampi(iy, 0, n - 1)
	var key := Vector2i(ix >> 8, iy >> 8)
	if key != _last_key:
		if not _tiles.has(key):
			return NAN
		_last_key = key
		_last_tile = _tiles[key]
	return _last_tile[(iy & 255) * TILE_PIXELS + (ix & 255)]


## Altitude interpolée (bilinéaire) en un point en pixels globaux (flottants).
func height_at(px: float, py: float) -> float:
	var fx := px - 0.5
	var fy := py - 0.5
	var ix := floori(fx)
	var iy := floori(fy)
	var tx := fx - ix
	var ty := fy - iy
	var h00 := height_at_pixel(ix, iy)
	var h10 := height_at_pixel(ix + 1, iy)
	var h01 := height_at_pixel(ix, iy + 1)
	var h11 := height_at_pixel(ix + 1, iy + 1)
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), ty)
