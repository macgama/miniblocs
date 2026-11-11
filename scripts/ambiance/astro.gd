class_name Astro
extends RefCounted
## Position réelle du Soleil et de la Lune dans le ciel.
##
## Formules astronomiques « basse précision » (Almanach astronomique) : à peu
## près 0,01° pour le Soleil et 0,5° pour la Lune, largement assez pour un jeu.
## Le temps est un horodatage Unix en secondes (UTC).
##
## Repère local du jeu (voir Geo) : x = Est, y = haut, z = Sud.

const JD_UNIX_EPOCH := 2440587.5
const JD_J2000 := 2451545.0
const OBLIQUITY := 23.439


static func julian_day(unix: float) -> float:
	return unix / 86400.0 + JD_UNIX_EPOCH


## Jours depuis le 1er janvier 2000 à midi (UTC).
static func days_j2000(unix: float) -> float:
	return julian_day(unix) - JD_J2000


## Coordonnées écliptiques du Soleil : Vector2(longitude, latitude) en degrés.
static func sun_ecliptic(n: float) -> Vector2:
	var l := fposmod(280.460 + 0.9856474 * n, 360.0)
	var g := deg_to_rad(fposmod(357.528 + 0.9856003 * n, 360.0))
	return Vector2(l + 1.915 * sin(g) + 0.020 * sin(2.0 * g), 0.0)


## Coordonnées écliptiques de la Lune : Vector2(longitude, latitude) en degrés.
static func moon_ecliptic(n: float) -> Vector2:
	var l := 218.316 + 13.176396 * n
	var m := deg_to_rad(134.963 + 13.064993 * n)
	var f := deg_to_rad(93.272 + 13.229350 * n)
	return Vector2(l + 6.289 * sin(m), 5.128 * sin(f))


## Écliptique -> équatorial : Vector2(ascension droite, déclinaison) en degrés.
static func to_equatorial(ecl: Vector2) -> Vector2:
	var lam := deg_to_rad(ecl.x)
	var bet := deg_to_rad(ecl.y)
	var eps := deg_to_rad(OBLIQUITY)
	var ra := atan2(sin(lam) * cos(eps) - tan(bet) * sin(eps), cos(lam))
	var dec := asin(sin(bet) * cos(eps) + cos(bet) * sin(eps) * sin(lam))
	return Vector2(fposmod(rad_to_deg(ra), 360.0), rad_to_deg(dec))


## Temps sidéral local (degrés).
static func local_sidereal(n: float, lon: float) -> float:
	return fposmod(280.46061837 + 360.98564736629 * n + lon, 360.0)


## Équatorial -> horizontal : Vector2(hauteur, azimut) en degrés.
## Azimut compté depuis le Nord, vers l'Est (90° = Est, 180° = Sud).
static func to_horizontal(eq: Vector2, n: float, lat: float, lon: float) -> Vector2:
	var ha := deg_to_rad(local_sidereal(n, lon) - eq.x)
	var dec := deg_to_rad(eq.y)
	var phi := deg_to_rad(lat)
	var el := asin(clampf(sin(phi) * sin(dec) + cos(phi) * cos(dec) * cos(ha), -1.0, 1.0))
	var az := atan2(-sin(ha) * cos(dec), cos(phi) * sin(dec) - sin(phi) * cos(dec) * cos(ha))
	return Vector2(rad_to_deg(el), fposmod(rad_to_deg(az), 360.0))


## Hauteur et azimut du Soleil (degrés) vus depuis (lat, lon).
static func sun_horizontal(unix: float, lat: float, lon: float) -> Vector2:
	var n := days_j2000(unix)
	return to_horizontal(to_equatorial(sun_ecliptic(n)), n, lat, lon)


## Hauteur et azimut de la Lune (degrés) vus depuis (lat, lon).
static func moon_horizontal(unix: float, lat: float, lon: float) -> Vector2:
	var n := days_j2000(unix)
	return to_horizontal(to_equatorial(moon_ecliptic(n)), n, lat, lon)


## Part éclairée du disque lunaire (0 = nouvelle lune, 1 = pleine lune).
static func moon_illumination(unix: float) -> float:
	var n := days_j2000(unix)
	var s := sun_ecliptic(n)
	var m := moon_ecliptic(n)
	var c := cos(deg_to_rad(m.y)) * cos(deg_to_rad(m.x - s.x))
	return (1.0 - c) / 2.0


## Âge de la lune (0 à 1 : nouvelle, premier quartier 0,25, pleine 0,5…).
static func moon_age(unix: float) -> float:
	var n := days_j2000(unix)
	return fposmod(moon_ecliptic(n).x - sun_ecliptic(n).x, 360.0) / 360.0


## Direction vers l'astre dans le repère local (x Est, y haut, z Sud).
static func direction(horiz: Vector2) -> Vector3:
	var el := deg_to_rad(horiz.x)
	var az := deg_to_rad(horiz.y)
	return Vector3(sin(az) * cos(el), sin(el), -cos(az) * cos(el))


## Heures (locales, en heures décimales) du lever et du coucher du Soleil pour le
## jour qui contient `unix`. Renvoie Vector2(-1, -1) pendant la nuit polaire et
## Vector2(-2, -2) pendant le jour polaire.
static func sun_rise_set(unix: float, lat: float, lon: float, offset_h: float) -> Vector2:
	var local := unix + offset_h * 3600.0
	var midnight := floorf(local / 86400.0) * 86400.0 - offset_h * 3600.0
	var rise := -1.0
	var sset := -1.0
	var prev := sun_horizontal(midnight, lat, lon).x + 0.833
	var any_up := prev > 0.0
	var step := 300.0
	var t := midnight + step
	while t <= midnight + 86400.0:
		var e := sun_horizontal(t, lat, lon).x + 0.833
		if e > 0.0:
			any_up = true
		if prev <= 0.0 and e > 0.0 and rise < 0.0:
			rise = (t - step * e / (e - prev) - midnight) / 3600.0
		elif prev > 0.0 and e <= 0.0 and sset < 0.0:
			sset = (t - step * e / (e - prev) - midnight) / 3600.0
		prev = e
		t += step
	if rise < 0.0 and sset < 0.0:
		return Vector2(-2, -2) if any_up else Vector2(-1, -1)
	return Vector2(rise, sset)
