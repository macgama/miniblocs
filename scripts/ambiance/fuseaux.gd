class_name Fuseaux
extends RefCounted
## Vrais fuseaux horaires du monde (heure d'été comprise), sans Internet.
##
## - assets/fuseaux_monde.png : carte du monde à 0,1° par pixel ; la valeur
##   d'un pixel est le numéro du fuseau (0 = mer).
## - assets/fuseaux.json : pour chaque fuseau, ses changements d'heure de 2000
##   à 2055 (calculés depuis la base IANA par tools/build_timezones.py).
## En mer, on cherche le fuseau de la côte la plus proche (≈ 30 km), sinon on
## prend le fuseau « nautique » (longitude / 15).
## Pour exporter le jeu : ajouter *.json aux fichiers non-ressources exportés.

const MAP_PATH := "res://assets/fuseaux_monde.png"
const DATA_PATH := "res://assets/fuseaux.json"
const RES := 0.1
## Les calendriers se répètent tous les 28 ans (de 1901 à 2099).
const CYCLE := 28 * 365.25 * 86400.0

static var _image: Image
static var _zones: Array = []
static var _loaded := false


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var tex := load(MAP_PATH) as Texture2D
	if tex != null:
		_image = tex.get_image()
	var f := FileAccess.open(DATA_PATH, FileAccess.READ)
	if f != null:
		var d = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			_zones = d.get("zones", [])


static func available() -> bool:
	_load()
	return _image != null and not _zones.is_empty()


## Numéro du fuseau au point (0 = aucun : mer ou données absentes).
static func zone_at(lat: float, lon: float) -> int:
	if not available():
		return 0
	var w := _image.get_width()
	var h := _image.get_height()
	var x := clampi(int(floorf((lon + 180.0) / RES)), 0, w - 1)
	var y := clampi(int(floorf((90.0 - lat) / RES)), 0, h - 1)
	var z := _pixel(x, y)
	if z > 0:
		return z
	# Près d'une côte : le fuseau terrestre le plus proche.
	for r in range(1, 4):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				z = _pixel(posmod(x + dx, w), clampi(y + dy, 0, h - 1))
				if z > 0:
					return z
	return 0


static func _pixel(x: int, y: int) -> int:
	var v := roundi(_image.get_pixel(x, y).r * 255.0)
	return v if v <= _zones.size() else 0


## Nom IANA du fuseau qui représente ce groupe (ex. « Europe/Paris »), ou "".
static func zone_name(z: int) -> String:
	if z <= 0 or z > _zones.size():
		return ""
	return String(_zones[z - 1].id)


## Décalage avec UTC (heures) au point et à l'instant donnés.
static func utc_offset(lat: float, lon: float, unix: float) -> float:
	var z := zone_at(lat, lon)
	if z == 0:
		return float(roundi(lon / 15.0))
	return offset_of_zone(z, unix) / 3600.0


## Décalage (secondes) d'un fuseau à un instant donné.
static func offset_of_zone(z: int, unix: float) -> int:
	var t: Array = _zones[z - 1].t
	var first := float(t[0][0])
	var last := float(t[t.size() - 1][0]) + 86400.0 * 366.0
	# Hors de la table : on ramène la date dans la période connue (cycle de 28 ans).
	while unix >= last:
		unix -= CYCLE
	while unix < first:
		unix += CYCLE
	var lo := 0
	var hi := t.size() - 1
	while lo < hi:
		var mid := (lo + hi + 1) / 2
		if float(t[mid][0]) <= unix:
			lo = mid
		else:
			hi = mid - 1
	return int(t[lo][1])
