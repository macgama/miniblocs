class_name TransportTypes
extends RefCounted
## Catalogue des types de voies. Tous les réseaux (route, rail, chemin, eau, et
## plus tard air) partagent le même graphe : seul le type change les règles de
## pose (pente, ponts, tunnels) et l'aspect.

enum Mode { ROAD, RAIL, PATH, WATER, AIR }

## Structure d'un point du tracé.
enum Struct { GROUND, BRIDGE, TUNNEL, WATER }

const MODE_NAMES := {
	Mode.ROAD: "Route",
	Mode.RAIL: "Rail",
	Mode.PATH: "Chemin",
	Mode.WATER: "Voie d'eau",
	Mode.AIR: "Couloir aérien",
}

## width : largeur (m) · max_grade : pente maxi (0,10 = 10 %)
## smooth : rayon de lissage du profil (m), plus grand = tracé plus tendu
## bridge_gap : au-dessus de cet écart avec le sol, on fait un pont (m)
## tunnel_depth : au-dessous de cet écart, on creuse un tunnel (m)
## speed : vitesse des véhicules (m/s) · lane : décalage de la file depuis l'axe (m)
const TYPES := {
	"route": {
		"name": "Route", "mode": Mode.ROAD, "width": 7.0, "max_grade": 0.10,
		"smooth": 14.0, "bridge_gap": 4.0, "tunnel_depth": 6.0,
		"speed": 13.9, "lane": 1.75, "color": Color("4a4e55"),
	},
	"rail": {
		"name": "Voie ferrée", "mode": Mode.RAIL, "width": 3.6, "max_grade": 0.04,
		"smooth": 40.0, "bridge_gap": 4.0, "tunnel_depth": 6.0,
		"speed": 22.0, "lane": 0.0, "color": Color("8a7f72"),
	},
	"chemin": {
		"name": "Chemin piéton et vélo", "mode": Mode.PATH, "width": 2.4, "max_grade": 0.15,
		"smooth": 4.0, "bridge_gap": 3.0, "tunnel_depth": 5.0,
		"speed": 1.4, "lane": 0.5, "color": Color("d9c49a"),
	},
	"voie_eau": {
		"name": "Voie navigable", "mode": Mode.WATER, "width": 12.0, "max_grade": 0.0,
		"smooth": 0.0, "bridge_gap": 0.0, "tunnel_depth": 0.0,
		"speed": 6.0, "lane": 3.0, "color": Color("2f6fa8"),
	},
}

## Pas d'échantillonnage du tracé (m).
const STEP := 2.0


static func get_type(id: String) -> Dictionary:
	return TYPES.get(id, {})


static func mode_of(id: String) -> int:
	return int(TYPES.get(id, {}).get("mode", -1))
