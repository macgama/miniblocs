class_name AgriEpoques
extends RefCounted
## L'agriculture au fil des époques (voir Epoques) : chaque machine agricole
## change de forme avec les années, les cultures et les élevages arrivent à
## leur date réelle.
##
## Une machine du jeu (AgriDonnees.MACHINES) est un RÔLE : « moissonneuse »
## veut dire « ce qui récolte les céréales ». En 1800, c'est la faux, la
## faucille et le fléau ; en 1850, la moissonneuse attelée et la batteuse à
## vapeur ; en 1940, la première moissonneuse-batteuse ; aujourd'hui, la
## grosse automotrice. AgriDonnees.machine(id) rend la version de l'année en
## cours. Les champs de chaque version remplacent ceux de la machine moderne :
## - name, prix, loc, ha_h, litres, automoteur, modele (décor affiché) ;
## - manuel : travail à la main (pas de tracteur ni d'attelage) ;
## - foin_h : fourrage mangé par heure de travail par les bêtes de trait (t).
## Une version "absent" (pulvérisateur avant la bouillie bordelaise) veut dire
## que la tâche ne se fait pas encore : le rendement s'en ressent.

## Versions de chaque rôle, de la plus ancienne à la plus récente. La dernière
## version déjà inventée est prise ; la machine moderne d'AgriDonnees vient
## après la dernière ligne.
const VERSIONS := {
	"tracteur": [
		{"annee": 0, "name": "Paire de chevaux de trait", "prix": 2_400, "loc": 18, "litres": 0.0, "foin_h": 0.012,
			"modele": "cheval", "automoteur": true},
		{"annee": 1920, "name": "Tracteur à pétrole (Fordson)", "prix": 9_000, "loc": 60, "litres": 9.0, "modele": "tracteur_ancien",
			"automoteur": true},
		{"annee": 1950, "name": "Tracteur diesel", "prix": 35_000, "loc": 120, "litres": 11.0, "modele": "tracteur_rouge",
			"automoteur": true},
		{"annee": 1990},
	],
	"charrue": [
		{"annee": 0, "name": "Charrue à versoir attelée", "prix": 300, "loc": 4, "ha_h": 0.06, "modele": "charrue"},
		{"annee": 1880, "name": "Brabant double", "prix": 900, "loc": 8, "ha_h": 0.12, "modele": "charrue"},
		{"annee": 1950, "name": "Charrue portée trois socs", "prix": 6_000, "loc": 30, "ha_h": 0.6, "modele": "charrue"},
		{"annee": 1980},
	],
	"semoir": [
		{"annee": 0, "name": "Semis à la volée (à la main)", "prix": 20, "loc": 0, "ha_h": 0.25, "manuel": true,
			"automoteur": true, "modele": "brouette"},
		{"annee": 1850, "name": "Semoir en ligne attelé", "prix": 700, "loc": 6, "ha_h": 0.5, "modele": ""},
		{"annee": 1950, "name": "Semoir mécanique", "prix": 9_000, "loc": 40, "ha_h": 1.5, "modele": ""},
		{"annee": 1985},
	],
	"planteuse": [
		{"annee": 0, "name": "Plantation à la main", "prix": 20, "loc": 0, "ha_h": 0.03, "manuel": true, "automoteur": true,
			"modele": "brouette"},
		{"annee": 1930, "name": "Planteuse attelée", "prix": 1_500, "loc": 12, "ha_h": 0.2, "modele": ""},
		{"annee": 1960, "name": "Planteuse deux rangs", "prix": 12_000, "loc": 60, "ha_h": 0.6, "modele": ""},
		{"annee": 1990},
	],
	"epandeur": [
		{"annee": 0, "name": "Épandage à la fourche (tombereau)", "prix": 400, "loc": 4, "ha_h": 0.2, "modele": "charrette"},
		{"annee": 1910, "name": "Épandeur à fumier attelé", "prix": 1_200, "loc": 10, "ha_h": 0.8, "modele": "charrette"},
		{"annee": 1960, "name": "Épandeur à hérissons", "prix": 8_000, "loc": 35, "ha_h": 3.0, "modele": ""},
		{"annee": 1990},
	],
	"pulverisateur": [
		{"annee": 0, "absent": true, "name": "Pas de traitement des cultures"},
		{"annee": 1885, "name": "Pulvérisateur à dos (bouillie bordelaise)", "prix": 60, "loc": 1, "ha_h": 0.15, "manuel": true,
			"automoteur": true, "modele": "brouette"},
		{"annee": 1950, "name": "Pulvérisateur porté", "prix": 6_000, "loc": 30, "ha_h": 4.0, "modele": ""},
		{"annee": 1990},
	],
	"moissonneuse": [
		{"annee": 0, "name": "Faux, faucille et fléau (à la main)", "prix": 40, "loc": 0, "ha_h": 0.03, "manuel": true,
			"automoteur": true, "modele": "brouette"},
		{"annee": 1850, "name": "Moissonneuse attelée et batteuse à vapeur", "prix": 4_000, "loc": 35, "ha_h": 0.25,
			"litres": 0.0, "automoteur": false, "modele": "charrette"},
		{"annee": 1900, "name": "Moissonneuse-lieuse et batteuse", "prix": 6_000, "loc": 45, "ha_h": 0.45, "litres": 0.0,
			"automoteur": false, "modele": "charrette"},
		{"annee": 1940, "name": "Moissonneuse-batteuse tractée", "prix": 30_000, "loc": 180, "ha_h": 0.9, "litres": 8.0,
			"automoteur": false, "modele": "moissonneuse"},
		{"annee": 1960, "name": "Moissonneuse-batteuse automotrice", "prix": 90_000, "loc": 400, "ha_h": 1.6, "litres": 18.0,
			"automoteur": true, "modele": "moissonneuse"},
		{"annee": 1995},
	],
	"arracheuse": [
		{"annee": 0, "name": "Arrachage à la main (houe et panier)", "prix": 30, "loc": 0, "ha_h": 0.02, "manuel": true,
			"automoteur": true, "modele": "brouette"},
		{"annee": 1900, "name": "Arracheuse attelée", "prix": 1_800, "loc": 15, "ha_h": 0.12, "modele": "charrette",
			"automoteur": false, "litres": 0.0},
		{"annee": 1960, "name": "Arracheuse tractée", "prix": 40_000, "loc": 200, "ha_h": 0.4, "modele": "remorque_foin",
			"automoteur": false, "litres": 0.0},
		{"annee": 1985},
	],
	"faucheuse": [
		{"annee": 0, "name": "Faux (à la main)", "prix": 15, "loc": 0, "ha_h": 0.08, "manuel": true, "automoteur": true, "modele": "brouette"},
		{"annee": 1850, "name": "Faucheuse à cheval", "prix": 800, "loc": 8, "ha_h": 0.6, "modele": ""},
		{"annee": 1950, "name": "Barre de coupe portée", "prix": 4_000, "loc": 25, "ha_h": 1.5, "modele": ""},
		{"annee": 1985},
	],
	"presse": [
		{"annee": 0, "name": "Fourche, râteau et meules (à la main)", "prix": 10, "loc": 0, "ha_h": 0.15, "manuel": true,
			"automoteur": true, "modele": "meule"},
		{"annee": 1880, "name": "Presse à foin fixe", "prix": 1_500, "loc": 12, "ha_h": 0.5, "modele": "pile_bottes"},
		{"annee": 1945, "name": "Ramasseuse-presse (balles carrées)", "prix": 12_000, "loc": 60, "ha_h": 2.0, "modele": "botte_carree"},
		{"annee": 1975},
	],
	"remorque": [
		{"annee": 0, "name": "Charrette (récolte à la main)", "prix": 250, "loc": 3, "ha_h": 0.06, "modele": "charrette"},
		{"annee": 1950},
	],
	"cueillette": [
		{"annee": 0, "name": "Cueillette à la main (paniers, échelles)", "prix": 50, "loc": 0, "ha_h": 0.04, "litres": 0.0,
			"modele": "brouette"},
		{"annee": 1960},
	],
	"vendangeuse": [
		{"annee": 0, "name": "Vendange à la main (hottes et paniers)", "prix": 50, "loc": 0, "ha_h": 0.04, "litres": 0.0,
			"manuel": true, "modele": "tonneaux"},
		{"annee": 1975},
	],
	"coupe_canne": [
		{"annee": 0, "name": "Coupe à la machette", "prix": 20, "loc": 0, "ha_h": 0.02, "litres": 0.0, "manuel": true,
			"modele": "brouette"},
		{"annee": 1975},
	],
}

## Année d'arrivée des cultures (ailleurs que dans leur pays d'origine, où le
## joueur peut toujours s'installer : on prend la diffusion en Europe et dans
## le monde agricole).
const ANNEES_CULTURES := {
	"soja": 1920, "tournesol": 1830, "betterave": 1812, "colza": 0, "ble": 0, "orge": 0, "mais": 0,
	"pomme_de_terre": 0, "legumes": 0, "riz": 0, "lin": 0, "coton": 0, "prairie": 0, "paturage": 0,
	"houblon": 0, "tabac": 0, "vigne": 0, "verger": 0, "agrumes": 0, "olivier": 0, "cafe": 0, "cacao": 0,
	"canne": 0, "the": 0,
}

## Élevages : année où l'élevage se répand.
const ANNEES_ESPECES := {
	"pisciculture": 1850, "dinde": 0, "lapin": 0, "abeille": 0, "canard": 0, "buffle": 0, "lama": 0, "renne": 0,
	"poule": 0, "porc": 0, "vache": 0, "bovin": 0, "mouton": 0, "chevre": 0, "cheval": 0,
}

static func _annee() -> int:
	return Epoques.annee() if Epoques.actif() else 99999


## Version d'une machine pour une année donnée ({} : la machine moderne).
static func version(id: String, annee := -1) -> Dictionary:
	if annee < 0:
		annee = _annee()
	var vs: Array = VERSIONS.get(id, [])
	var best := {}
	for v: Dictionary in vs:
		if int(v.annee) <= annee:
			best = v
	return best


## La machine (rôle) a-t-elle une forme à cette époque ? (pulvérisateur avant 1885 : non)
static func machine_existe(id: String, annee := -1) -> bool:
	return not bool(version(id, annee).get("absent", false))


static func annee_culture(id: String) -> int:
	return int(ANNEES_CULTURES.get(id, AgriDonnees.CULTURES.get(id, {}).get("annee", 0)))


static func culture_disponible(id: String) -> bool:
	return annee_culture(id) <= _annee()


static func raison_culture(id: String) -> String:
	if culture_disponible(id):
		return ""
	return "Pas encore cultivé ici : arrive en %d." % annee_culture(id)


static func annee_espece(id: String) -> int:
	return int(ANNEES_ESPECES.get(id, 0))


static func espece_disponible(id: String) -> bool:
	return annee_espece(id) <= _annee()

