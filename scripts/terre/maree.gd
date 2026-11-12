class_name Maree
extends RefCounted
## Marées : le niveau de la mer monte et descend avec la Lune.
##
## Modèle simple mais vrai dans ses grandes lignes :
## - marée « semi-diurne » : deux pleines mers par jour lunaire (24 h 50), quand
##   la Lune passe au méridien du lieu ou à l'opposé ;
## - vives-eaux à la nouvelle et à la pleine lune (marées plus fortes), mortes-eaux
##   aux quartiers (plus faibles) ;
## - le marnage dépend de la mer : presque rien en Méditerranée ou en Baltique,
##   fort en Manche.
## Le niveau 0 m reste le niveau moyen (celui des tuiles d'altitude).

## Retard de la pleine mer sur le passage de la Lune au méridien (degrés de
## rotation de la Terre, ~2 h). Il varie selon les côtes ; on garde une valeur.
const LAG_DEG := 30.0
## Écart entre vives-eaux et mortes-eaux (± 30 %).
const SPRING_NEAP := 0.3

## Niveau actuel de la mer (m, autour de 0), mis à jour par TerrainWorld.
static var level := 0.0
## Plus haute mer possible au lieu de la partie (m) : les ponts passent au-dessus.
static var high_water := 0.0


## Demi-marnage moyen (m) au lieu (lat, lon) : la mer monte de cette hauteur
## au-dessus du niveau moyen et descend d'autant.
static func amplitude(lat: float, lon: float) -> float:
	# Mer Caspienne et mers presque fermées : pas ou peu de marée.
	if lat > 36.0 and lat < 47.5 and lon > 46.5 and lon < 55.0:
		return 0.0
	if lat > 40.5 and lat < 47.0 and lon > 27.5 and lon < 42.0:
		return 0.05 # mer Noire
	if lat > 53.5 and lat < 66.0 and lon > 10.0 and lon < 30.5:
		return 0.1 # mer Baltique
	if lat > 30.0 and lat < 46.0 and lon > -5.5 and lon < 36.5:
		return 0.15 # Méditerranée
	# Manche et Bretagne nord : parmi les plus grandes marées du monde.
	if lat > 48.4 and lat < 51.2 and lon > -5.2 and lon < 2.0:
		return 2.5
	# Côte atlantique de l'Europe, mer du Nord, Amérique du Nord-Est.
	if lat > 43.0 and lat < 60.0 and lon > -11.0 and lon < 9.0:
		return 1.8
	return 1.0


## Facteur vives-eaux / mortes-eaux selon l'âge de la Lune (0 = nouvelle lune).
static func spring_factor(unix: float) -> float:
	return 1.0 + SPRING_NEAP * cos(Astro.moon_age(unix) * TAU * 2.0)


## Niveau de la mer (m) à l'instant unix au lieu (lat, lon).
static func level_at(unix: float, lat: float, lon: float) -> float:
	var a := amplitude(lat, lon)
	if a <= 0.0:
		return 0.0
	var n := Astro.days_j2000(unix)
	var eq := Astro.to_equatorial(Astro.moon_ecliptic(n))
	var ha := deg_to_rad(Astro.local_sidereal(n, lon) - eq.x - LAG_DEG)
	return a * spring_factor(unix) * cos(2.0 * ha)


## La mer monte-t-elle à cet instant ?
static func rising(unix: float, lat: float, lon: float) -> bool:
	return level_at(unix + 600.0, lat, lon) > level_at(unix, lat, lon)


## Plus haute mer possible au lieu (grandes vives-eaux).
static func max_level(lat: float, lon: float) -> float:
	return amplitude(lat, lon) * (1.0 + SPRING_NEAP)


## Texte court pour l'interface : « Marée : +1,2 m, montante ».
static func describe(unix: float, lat: float, lon: float) -> String:
	if amplitude(lat, lon) <= 0.0:
		return "Pas de marée"
	var l := level_at(unix, lat, lon)
	var s := ("%+.1f m" % l).replace(".", ",")
	return "Marée : %s, %s" % [s, "montante" if rising(unix, lat, lon) else "descendante"]
