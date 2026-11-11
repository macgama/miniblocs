class_name LandCover
extends Node
## Occupation du sol réelle : ESA WorldCover 2021 (10 m, CC BY 4.0, AWS Open Data).
##
## La planète est découpée en fichiers GeoTIFF « optimisés pour le cloud » de
## 3° × 3° (36 000 × 36 000 pixels de ~10 m). On ne télécharge jamais un
## fichier entier : seulement son en-tête, puis les blocs de 1024 × 1024 pixels
## (~10 km de côté, 50 à 150 Ko) qui couvrent la région jouée. Tout est gardé
## dans user://landcover_cache/.
##
## Codes WorldCover : 10 forêt, 20 broussailles, 30 prairie, 40 champs, 50 bâti,
## 60 sol nu, 70 neige et glace, 80 eau, 90 marais, 95 mangrove, 100 mousses.
## 0 = pas de donnée (pleine mer, ou pas encore chargé).

signal data_ready

const BASE_URL := "https://esa-worldcover.s3.eu-central-1.amazonaws.com/v200/2021/map/"
const CACHE_DIR := "user://landcover_cache"
const PX_PER_DEG := 12000.0
const TILE := 1024
const TILES_ACROSS := 36 # 36 000 / 1024, arrondi au-dessus
const HEADER_BYTES := 32768
const MAX_PARALLEL := 4

enum State { LOADING, READY, MISSING }

## Pour les tests : Callable(lat: float, lon: float) -> int, aucun réseau.
var offline_generator: Callable

## nom de fichier -> {state, offs: PackedInt64Array, cnts: PackedInt64Array}
var _files: Dictionary = {}
## "nom|indice" -> PackedByteArray (1024 × 1024 codes) ; vide = échec
var _tiles: Dictionary = {}
var _loading_tiles: Dictionary = {}
var _queue: Array = []
var _free: Array[HTTPRequest] = []
var _jobs: Dictionary = {}
var _last_key := ""
var _last_tile: PackedByteArray
var _failed := 0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(CACHE_DIR)
	for i in MAX_PARALLEL:
		var req := HTTPRequest.new()
		req.timeout = 30.0
		req.use_threads = true
		add_child(req)
		req.request_completed.connect(_on_completed.bind(req))
		_free.append(req)


static func file_name(lat: float, lon: float) -> String:
	var la := int(floorf(lat / 3.0) * 3.0)
	var lo := int(floorf(lon / 3.0) * 3.0)
	return "ESA_WorldCover_10m_2021_v200_%s%02d%s%03d_Map.tif" % [
		"N" if la >= 0 else "S", absi(la), "E" if lo >= 0 else "W", absi(lo)]


## Fichier et indice du bloc 1024 × 1024 contenant (lat, lon), et position dans le bloc.
static func locate(lat: float, lon: float) -> Dictionary:
	var la0 := floorf(lat / 3.0) * 3.0
	var lo0 := floorf(lon / 3.0) * 3.0
	var col := clampi(int((lon - lo0) * PX_PER_DEG), 0, 35999)
	var row := clampi(int((la0 + 3.0 - lat) * PX_PER_DEG), 0, 35999)
	return {
		"file": file_name(lat, lon),
		"index": (row >> 10) * TILES_ACROSS + (col >> 10),
		"pixel": (row & 1023) * TILE + (col & 1023),
	}


func failed_count() -> int:
	return _failed


func pending_count() -> int:
	return _jobs.size() + _queue.size()


## Vrai si la donnée de ce point est disponible (ou définitivement absente).
func is_ready_at(lat: float, lon: float) -> bool:
	if offline_generator.is_valid():
		return true
	var loc := locate(lat, lon)
	var f: Dictionary = _files.get(loc.file, {})
	if f.is_empty():
		return false
	if f.state == State.MISSING:
		return true
	if f.state == State.LOADING:
		return false
	return _tiles.has("%s|%d" % [loc.file, loc.index])


## Demande la donnée autour de ce point (en-tête du fichier puis bloc).
func request_at(lat: float, lon: float) -> void:
	if offline_generator.is_valid():
		return
	var loc := locate(lat, lon)
	var f: Dictionary = _files.get(loc.file, {})
	if f.is_empty():
		_files[loc.file] = {"state": State.LOADING, "wanted": [loc.index]}
		var head_path := "%s/%s.head" % [CACHE_DIR, loc.file]
		if FileAccess.file_exists(head_path):
			_on_header(loc.file, FileAccess.get_file_as_bytes(head_path))
		elif FileAccess.file_exists(head_path + ".absent"):
			_files[loc.file] = {"state": State.MISSING}
		else:
			_enqueue({"kind": "head", "file": loc.file, "from": 0, "to": HEADER_BYTES - 1})
		return
	if f.state == State.LOADING:
		if not (f.wanted as Array).has(loc.index):
			f.wanted.append(loc.index)
		return
	if f.state == State.READY:
		_request_tile(loc.file, loc.index)


## Code WorldCover du point, ou 0 si inconnu.
func class_at(lat: float, lon: float) -> int:
	if offline_generator.is_valid():
		return offline_generator.call(lat, lon)
	var loc := locate(lat, lon)
	var key := "%s|%d" % [loc.file, loc.index]
	if key != _last_key:
		if not _tiles.has(key):
			return 0
		_last_key = key
		_last_tile = _tiles[key]
	if _last_tile.is_empty():
		return 0
	return _last_tile[loc.pixel]


func _request_tile(file: String, index: int) -> void:
	var key := "%s|%d" % [file, index]
	if _tiles.has(key) or _loading_tiles.has(key):
		return
	var path := "%s/%s_%d.bin" % [CACHE_DIR, file, index]
	if FileAccess.file_exists(path):
		_store_tile(key, FileAccess.get_file_as_bytes(path))
		return
	var f: Dictionary = _files[file]
	var offs: PackedInt64Array = f.offs
	var cnts: PackedInt64Array = f.cnts
	if index >= offs.size() or cnts[index] == 0:
		_store_tile(key, PackedByteArray())
		return
	_loading_tiles[key] = true
	_enqueue({"kind": "tile", "file": file, "index": index, "key": key,
		"from": offs[index], "to": offs[index] + cnts[index] - 1})


func _store_tile(key: String, compressed: PackedByteArray) -> void:
	_loading_tiles.erase(key)
	var data := PackedByteArray()
	if not compressed.is_empty():
		data = compressed.decompress(TILE * TILE, FileAccess.COMPRESSION_DEFLATE)
		if data.size() != TILE * TILE:
			data = PackedByteArray()
	if data.is_empty():
		_failed += 1
	_tiles[key] = data
	if key == _last_key:
		_last_key = ""
	data_ready.emit()


func _enqueue(job: Dictionary) -> void:
	_queue.append(job)


func _process(_delta: float) -> void:
	while not _queue.is_empty() and not _free.is_empty():
		var job: Dictionary = _queue.pop_front()
		var req: HTTPRequest = _free.pop_back()
		_jobs[req] = job
		var headers := PackedStringArray(["Range: bytes=%d-%d" % [job.from, job.to]])
		if req.request(BASE_URL + job.file, headers) != OK:
			_jobs.erase(req)
			_free.append(req)
			_fail_job(job, false)


func _on_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, req: HTTPRequest) -> void:
	var job: Dictionary = _jobs.get(req, {})
	_jobs.erase(req)
	_free.append(req)
	if job.is_empty():
		return
	var ok := result == HTTPRequest.RESULT_SUCCESS and (code == 206 or code == 200)
	if not ok:
		# 403/404 : pas de fichier ici (pleine mer). Sinon : problème de réseau.
		_fail_job(job, result == HTTPRequest.RESULT_SUCCESS and code >= 400 and code < 500)
		return
	if job.kind == "head":
		var f := FileAccess.open("%s/%s.head" % [CACHE_DIR, job.file], FileAccess.WRITE)
		if f:
			f.store_buffer(body)
		_on_header(job.file, body)
	else:
		var f := FileAccess.open("%s/%s_%d.bin" % [CACHE_DIR, job.file, job.index], FileAccess.WRITE)
		if f:
			f.store_buffer(body)
		_store_tile(job.key, body)


func _fail_job(job: Dictionary, absent: bool) -> void:
	if job.kind == "head":
		if absent:
			var f := FileAccess.open("%s/%s.head.absent" % [CACHE_DIR, job.file], FileAccess.WRITE)
			if f:
				f.store_8(0)
		else:
			_failed += 1
		_files[job.file] = {"state": State.MISSING}
		data_ready.emit()
	else:
		_store_tile(job.key, PackedByteArray())


## Lit le premier répertoire TIFF : positions et tailles des blocs.
func _on_header(file: String, data: PackedByteArray) -> void:
	var wanted: Array = _files.get(file, {}).get("wanted", [])
	var parsed := parse_tiff_header(data)
	if parsed.is_empty():
		_failed += 1
		_files[file] = {"state": State.MISSING}
		data_ready.emit()
		return
	_files[file] = {"state": State.READY, "offs": parsed.offs, "cnts": parsed.cnts}
	for index in wanted:
		_request_tile(file, index)
	data_ready.emit()


static func parse_tiff_header(d: PackedByteArray) -> Dictionary:
	if d.size() < 16 or d[0] != 0x49 or d[1] != 0x49 or d.decode_u16(2) != 42:
		return {}
	var off := d.decode_u32(4)
	if off + 2 > d.size():
		return {}
	var n := d.decode_u16(off)
	var tags := {}
	for i in n:
		var e := off + 2 + 12 * i
		if e + 12 > d.size():
			return {}
		tags[d.decode_u16(e)] = [d.decode_u16(e + 2), d.decode_u32(e + 4), e + 8]
	for needed in [259, 322, 323, 324, 325]:
		if not tags.has(needed):
			return {}
	if _tag_value(d, tags[259]) != 8 or _tag_value(d, tags[322]) != TILE or _tag_value(d, tags[323]) != TILE:
		return {}
	var offs := _tag_array(d, tags[324])
	var cnts := _tag_array(d, tags[325])
	if offs.is_empty() or offs.size() != cnts.size():
		return {}
	return {"offs": offs, "cnts": cnts}


static func _tag_value(d: PackedByteArray, t: Array) -> int:
	return d.decode_u16(t[2]) if t[0] == 3 else d.decode_u32(t[2])


static func _tag_array(d: PackedByteArray, t: Array) -> PackedInt64Array:
	var typ: int = t[0]
	var count: int = t[1]
	var size := 2 if typ == 3 else (8 if typ == 16 else 4)
	var at: int = t[2] if size * count <= 4 else d.decode_u32(t[2])
	var out := PackedInt64Array()
	if at + size * count > d.size():
		return out
	out.resize(count)
	for i in count:
		match size:
			2: out[i] = d.decode_u16(at + i * 2)
			4: out[i] = d.decode_u32(at + i * 4)
			8: out[i] = d.decode_s64(at + i * 8)
	return out
