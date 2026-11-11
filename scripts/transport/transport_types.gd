class_name TransportTypes
extends RefCounted
## Catalogue des classes de voies et de leurs gabarits réglementaires.
##
## Tous les réseaux (route, rail, chemin, eau, et plus tard air) partagent le
## même graphe : la classe fixe les règles de pose (largeurs, pente maximale,
## rayon de courbure minimal, ponts, tunnels) et l'aspect.
##
## Valeurs de référence (France) :
## - routes interurbaines : guide ARP (Sétra) ; voies de 3,00 à 3,50 m,
##   rayon minimal 240 m à 80 km/h, pente maximale 6 à 7 % ;
## - voies express et autoroutes : ICTAVRU / ICTAAL ; voies de 3,50 m, bande
##   d'arrêt d'urgence de 2,50 à 3,00 m, terre-plein central, rayon minimal
##   400 m (110 km/h) et 665 m (130 km/h), pente maximale 6 % et 5 % ;
## - voirie urbaine : guides CEREMA ; voies de 2,75 à 3,50 m, trottoirs de
##   1,40 m minimum (accessibilité), 2,00 m conseillés ;
## - aménagements cyclables : CEREMA ; piste bidirectionnelle 2,50 à 3,00 m,
##   voie verte 3,00 m minimum, pente conseillée 5 à 6 % ;
## - ferroviaire : écartement 1,435 m ; entraxe 4,20 m (lignes classiques) et
##   4,50 m (LGV) ; rampe maximale 25 ‰ (classique) et 35 ‰ (LGV) ;
##   tramway : entraxe 3,00 m, rayon minimal 25 m, pente jusqu'à 7 %.
## Le tableau ci-dessous est la seule source de ces valeurs : on peut ajouter
## d'autres pays sans toucher au reste du code.

enum Mode { ROAD, RAIL, PATH, WATER, AIR }

## Structure d'un point du tracé.
enum Struct { GROUND, BRIDGE, TUNNEL, WATER }

const NORM_NAME := "France (ARP, ICTAAL, CEREMA, SNCF Réseau)"

const MODE_NAMES := {
	Mode.ROAD: "Route",
	Mode.RAIL: "Rail",
	Mode.PATH: "Chemin",
	Mode.WATER: "Voie d'eau",
	Mode.AIR: "Couloir aérien",
}

const GAUGE := 1.435

## lanes : voies par sens [min, max, défaut] · lane_w : largeur d'une voie [min, max, défaut]
## median : terre-plein central (m) · median_from : nombre de voies par sens à partir duquel il existe
## side : trottoir ou accotement de chaque côté (m) · side_kind : "trottoir", "accotement", "bau"
## tracks : nombre de voies ferrées [min, max, défaut] · spacing : entraxe (m)
## width : largeur totale [min, max, défaut] (chemins, eau)
## kmh : vitesse de référence · r_min : rayon de courbure minimal (m)
## max_grade : pente maximale · smooth : rayon de lissage du profil (m)
## bridge_gap / tunnel_depth : écart avec le sol au-delà duquel on fait un pont / un tunnel (m)
const CLASSES := {
	"rue": {
		"name": "Rue de desserte", "mode": Mode.ROAD, "kmh": 30.0,
		"lanes": [1, 1, 1], "lane_w": [2.75, 3.25, 3.0], "median": 0.0, "median_from": 9,
		"side": 1.5, "side_kind": "trottoir", "center": "dashed",
		"r_min": 15.0, "max_grade": 0.12, "smooth": 6.0, "bridge_gap": 4.0, "tunnel_depth": 6.0,
	},
	"avenue": {
		"name": "Avenue urbaine", "mode": Mode.ROAD, "kmh": 50.0,
		"lanes": [1, 3, 2], "lane_w": [3.0, 3.5, 3.25], "median": 2.0, "median_from": 2,
		"side": 2.0, "side_kind": "trottoir", "center": "solid",
		"r_min": 40.0, "max_grade": 0.08, "smooth": 10.0, "bridge_gap": 4.0, "tunnel_depth": 6.0,
	},
	"departementale": {
		"name": "Route départementale", "mode": Mode.ROAD, "kmh": 80.0,
		"lanes": [1, 1, 1], "lane_w": [3.0, 3.5, 3.0], "median": 0.0, "median_from": 9,
		"side": 1.75, "side_kind": "accotement", "center": "dashed",
		"r_min": 240.0, "max_grade": 0.07, "smooth": 16.0, "bridge_gap": 4.0, "tunnel_depth": 6.0,
	},
	"voie_express": {
		"name": "Voie express", "mode": Mode.ROAD, "kmh": 110.0,
		"lanes": [2, 3, 2], "lane_w": [3.5, 3.5, 3.5], "median": 2.6, "median_from": 1,
		"side": 2.5, "side_kind": "bau", "center": "barrier",
		"r_min": 400.0, "max_grade": 0.06, "smooth": 30.0, "bridge_gap": 5.0, "tunnel_depth": 8.0,
	},
	"autoroute": {
		"name": "Autoroute", "mode": Mode.ROAD, "kmh": 130.0,
		"lanes": [2, 4, 2], "lane_w": [3.5, 3.5, 3.5], "median": 3.0, "median_from": 1,
		"side": 3.0, "side_kind": "bau", "center": "barrier",
		"r_min": 665.0, "max_grade": 0.05, "smooth": 40.0, "bridge_gap": 5.0, "tunnel_depth": 8.0,
	},
	"tram": {
		"name": "Tramway", "mode": Mode.RAIL, "kmh": 50.0,
		"tracks": [1, 2, 2], "spacing": 3.0, "side": 0.5,
		"r_min": 25.0, "max_grade": 0.07, "smooth": 8.0, "bridge_gap": 4.0, "tunnel_depth": 6.0,
	},
	"train": {
		"name": "Ligne ferroviaire classique", "mode": Mode.RAIL, "kmh": 120.0,
		"tracks": [1, 2, 1], "spacing": 4.2, "side": 1.5,
		"r_min": 600.0, "max_grade": 0.025, "smooth": 40.0, "bridge_gap": 4.0, "tunnel_depth": 6.0,
	},
	"lgv": {
		"name": "Ligne à grande vitesse", "mode": Mode.RAIL, "kmh": 300.0,
		"tracks": [2, 2, 2], "spacing": 4.5, "side": 1.5,
		"r_min": 4000.0, "max_grade": 0.035, "smooth": 80.0, "bridge_gap": 4.0, "tunnel_depth": 8.0,
	},
	"trottoir": {
		"name": "Chemin piéton", "mode": Mode.PATH, "kmh": 5.0, "width": [1.4, 4.0, 2.0],
		"r_min": 2.0, "max_grade": 0.12, "smooth": 3.0, "bridge_gap": 3.0, "tunnel_depth": 5.0,
		"color": Color("c9c5bd"),
	},
	"piste_cyclable": {
		"name": "Piste cyclable bidirectionnelle", "mode": Mode.PATH, "kmh": 18.0, "width": [2.5, 3.0, 3.0],
		"r_min": 10.0, "max_grade": 0.06, "smooth": 6.0, "bridge_gap": 3.0, "tunnel_depth": 5.0,
		"color": Color("a8554a"),
	},
	"voie_verte": {
		"name": "Voie verte (piétons et vélos)", "mode": Mode.PATH, "kmh": 12.0, "width": [3.0, 5.0, 3.0],
		"r_min": 10.0, "max_grade": 0.06, "smooth": 6.0, "bridge_gap": 3.0, "tunnel_depth": 5.0,
		"color": Color("d9c49a"),
	},
	"canal": {
		"name": "Voie navigable", "mode": Mode.WATER, "kmh": 12.0, "width": [12.0, 60.0, 20.0],
		"r_min": 50.0, "max_grade": 0.0, "smooth": 0.0, "bridge_gap": 0.0, "tunnel_depth": 0.0,
	},
	"chenal": {
		"name": "Chenal maritime", "mode": Mode.WATER, "kmh": 40.0, "width": [60.0, 400.0, 150.0],
		"r_min": 400.0, "max_grade": 0.0, "smooth": 0.0, "bridge_gap": 0.0, "tunnel_depth": 0.0,
	},
}

## Anciens identifiants (sauvegardes de la première version).
const ALIASES := {"route": "departementale", "rail": "train", "chemin": "voie_verte", "voie_eau": "canal"}

## Classes proposées par chaque outil, dans l'ordre d'affichage.
const BY_MODE := {
	Mode.ROAD: ["rue", "avenue", "departementale", "voie_express", "autoroute"],
	Mode.RAIL: ["tram", "train", "lgv"],
	Mode.PATH: ["trottoir", "piste_cyclable", "voie_verte"],
	Mode.WATER: ["canal", "chenal"],
}

## Pas d'échantillonnage du tracé (m).
const STEP := 2.0


static func resolve(id: String) -> String:
	return ALIASES.get(id, id)


static func get_type(id: String) -> Dictionary:
	return CLASSES.get(resolve(id), {})


static func mode_of(id: String) -> int:
	return int(get_type(id).get("mode", -1))


static func speed_of(id: String) -> float:
	return float(get_type(id).get("kmh", 30.0)) / 3.6


## Réglages par défaut d'une classe.
static func default_spec(id: String) -> Dictionary:
	var c := get_type(id)
	var s := {}
	if c.has("lanes"):
		s.lanes = int(c.lanes[2])
		s.lane_w = float(c.lane_w[2])
	if c.has("tracks"):
		s.tracks = int(c.tracks[2])
	if c.has("width"):
		s.width = float(c.width[2])
	return s


## Ramène les réglages dans les limites réglementaires de la classe.
static func normalize(id: String, spec: Dictionary) -> Dictionary:
	var c := get_type(id)
	var s := default_spec(id)
	if c.has("lanes"):
		s.lanes = clampi(int(spec.get("lanes", s.lanes)), int(c.lanes[0]), int(c.lanes[1]))
		s.lane_w = clampf(snappedf(float(spec.get("lane_w", s.lane_w)), 0.05), float(c.lane_w[0]), float(c.lane_w[1]))
	if c.has("tracks"):
		s.tracks = clampi(int(spec.get("tracks", s.tracks)), int(c.tracks[0]), int(c.tracks[1]))
	if c.has("width"):
		s.width = clampf(snappedf(float(spec.get("width", s.width)), 0.05), float(c.width[0]), float(c.width[1]))
	return s


static func median_of(id: String, spec: Dictionary) -> float:
	var c := get_type(id)
	if not c.has("lanes"):
		return 0.0
	return float(c.median) if int(spec.get("lanes", 1)) >= int(c.median_from) else 0.0


## Largeur totale (m) : chaussées + terre-plein + trottoirs / accotements.
static func width_of(id: String, spec: Dictionary) -> float:
	var c := get_type(id)
	var s := normalize(id, spec)
	match int(c.get("mode", -1)):
		Mode.ROAD:
			return 2.0 * s.lanes * s.lane_w + median_of(id, s) + 2.0 * float(c.side)
		Mode.RAIL:
			return float(s.tracks - 1) * float(c.spacing) + 3.0 + 2.0 * float(c.side)
		Mode.PATH, Mode.WATER:
			return s.width
	return 4.0


## Décalages latéraux (vers la droite du sens de marche) des files d'un sens.
static func lane_offsets(id: String, spec: Dictionary) -> Array[float]:
	var c := get_type(id)
	var s := normalize(id, spec)
	var out: Array[float] = []
	match int(c.get("mode", -1)):
		Mode.ROAD:
			for i in int(s.lanes):
				out.append(median_of(id, s) * 0.5 + float(s.lane_w) * (i + 0.5))
		Mode.RAIL:
			out.append(float(c.spacing) * 0.5 if int(s.tracks) == 2 else 0.0)
		Mode.PATH:
			out.append(float(s.width) * 0.22)
		Mode.WATER:
			out.append(float(s.width) * 0.25)
	return out


## Résumé lisible du gabarit, pour l'interface.
static func describe(id: String, spec: Dictionary) -> String:
	var c := get_type(id)
	if c.is_empty():
		return ""
	var s := normalize(id, spec)
	var parts: Array[String] = []
	parts.append("largeur totale %s m" % _num(width_of(id, s)))
	match int(c.mode):
		Mode.ROAD:
			parts.append("2 × %d voie%s de %s m" % [s.lanes, "s" if s.lanes > 1 else "", _num(s.lane_w)])
			if median_of(id, s) > 0.0:
				parts.append("terre-plein %s m" % _num(median_of(id, s)))
			var side_names := {"trottoir": "trottoirs", "accotement": "accotements", "bau": "bandes d'arrêt d'urgence"}
			parts.append("%s %s m" % [side_names.get(c.side_kind, "bords"), _num(c.side)])
		Mode.RAIL:
			parts.append("%s, écartement %s m" % ["voie unique" if s.tracks == 1 else "double voie (entraxe %s m)" % _num(c.spacing), _num(GAUGE)])
	parts.append("%d km/h" % roundi(c.kmh))
	parts.append("rayon mini %s m" % _num(c.r_min))
	if float(c.max_grade) > 0.0:
		parts.append("pente maxi %s %%" % _num(float(c.max_grade) * 100.0))
	return " · ".join(parts)


static func _num(v: float) -> String:
	var t := ("%.2f" % v).rstrip("0").rstrip(".")
	return t.replace(".", ",")
