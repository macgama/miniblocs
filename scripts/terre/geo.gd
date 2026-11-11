class_name Geo
extends RefCounted
## Conversions géographiques.
##
## - Tuiles « Web Mercator » (celles de presque toutes les cartes web) :
##   la Terre est découpée en 2^zoom × 2^zoom tuiles de 256 × 256 pixels.
## - Repère local du jeu : une région plate centrée sur un point d'origine
##   (lat, lon). x = mètres vers l'Est, z = mètres vers le Sud.
##   1 unité Godot = 1 mètre = 1 case. Assez précis sur ± 10 km autour de l'origine.

const EARTH_RADIUS := 6378137.0


## Nombre total de pixels sur un côté du monde au niveau de zoom donné.
static func world_pixels(zoom: int) -> float:
	return 256.0 * pow(2.0, zoom)


static func lon_to_pixel_x(lon: float, zoom: int) -> float:
	return (lon + 180.0) / 360.0 * world_pixels(zoom)


static func lat_to_pixel_y(lat: float, zoom: int) -> float:
	var lat_rad := deg_to_rad(clampf(lat, -85.05, 85.05))
	return (1.0 - log(tan(lat_rad) + 1.0 / cos(lat_rad)) / PI) / 2.0 * world_pixels(zoom)


static func local_to_lat(origin_lat: float, z: float) -> float:
	return origin_lat - rad_to_deg(z / EARTH_RADIUS)


static func local_to_lon(origin_lat: float, origin_lon: float, x: float) -> float:
	return origin_lon + rad_to_deg(x / (EARTH_RADIUS * cos(deg_to_rad(origin_lat))))


## Convertit "48.8584, 2.2945" (ou "48,8584 2,2945") en Vector2(lat, lon).
## Renvoie null si le texte n'est pas compris.
static func parse_lat_lon(text: String) -> Variant:
	var t := text.strip_edges().replace(";", " ")
	var parts: PackedStringArray
	if t.count(",") == 1 and t.count(".") >= 1:
		parts = t.split(",", false)
	else:
		# Virgules décimales à la française : "48,85 2,29".
		parts = t.replace(",", ".").split(" ", false)
	if parts.size() != 2:
		return null
	var a := parts[0].strip_edges()
	var b := parts[1].strip_edges()
	if not a.is_valid_float() or not b.is_valid_float():
		return null
	var lat := a.to_float()
	var lon := b.to_float()
	if absf(lat) > 85.0 or absf(lon) > 180.0:
		return null
	return Vector2(lat, lon)
