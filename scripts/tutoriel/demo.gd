class_name Demo
extends RefCounted
## Démo guidée d'environ 30 minutes (bouton « Démo guidée » du menu principal).
##
## Une nouvelle partie au même endroit pour tout le monde, avec les réglages
## « Normal » : le tutoriel guidé (fonder, route, zonage, réseaux, temps,
## emplois, école, budget, objectifs), puis les chapitres de la démo (vue au
## sol, loisirs, fête, ligne de bus, rang de Village) et le bilan
## (DemoBilan). Les étapes sont dans Tutoriel.ETAPES_DEMO.
##
## La partie est une partie comme les autres : on peut la sauvegarder, la
## reprendre et continuer à jouer après le bilan.

const TERRE := "res://scenes/terre.tscn"
## Lieu de départ de la démo : un plateau agricole presque plat (facile pour
## une première ville), avec des bois et des ruisseaux.
const LIEU := {"nom": "Échallens, Vaud", "lat": 46.6413, "lon": 6.6335, "pays": "ch"}
## Durée annoncée (minutes réelles).
const DUREE_MIN := 30

## La prochaine scène Terre doit lancer la démo (lu une fois par terre_main).
static var demandee := false


## Réglages de la démo : le préréglage Normal, tutoriel et objectifs à l'écran.
static func reglages() -> ReglagesPartie:
	var r := ReglagesPartie.preset("normal")
	r.tutoriel = true
	r.objectifs_ecran = true
	# Démo guidée de 30 min : tout le catalogue ouvert (pas d'arbre de progression).
	r.deblocage = "tout"
	return r


## Prépare GameStart et les réglages ; renvoie le titre de l'écran de chargement.
static func preparer() -> String:
	GameStart.chosen = true
	GameStart.atelier = false
	GameStart.lat = float(LIEU.lat)
	GameStart.lon = float(LIEU.lon)
	GameStart.place_name = String(LIEU.nom)
	GameStart.pays = String(LIEU.pays)
	GameStart.mode = GameStart.Mode.BAC_A_SABLE
	GameStart.load_slot = ""
	GameStart.slot_id = ""
	ReglagesPartie.prochaine = reglages()
	demandee = true
	return "Démo guidée · " + String(LIEU.nom)


static func lancer() -> void:
	EcranChargement.aller(TERRE, preparer())


## Texte de la durée jouée : « 27 min », « 1 h 05 ».
static func duree(minutes: int) -> String:
	if minutes < 60:
		return "%d min" % minutes
	return "%d h %02d" % [minutes / 60, minutes % 60]
