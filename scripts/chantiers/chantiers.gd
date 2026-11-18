class_name Chantiers
extends RefCounted
## Règles communes des chantiers (bâtiments et voies) : durées réalistes,
## horaires des équipes, étapes, avancement.
##
## Principe : chaque chantier a une quantité de travail en « heures réelles »
## (une maison ≈ 5 mois d'une équipe, une départementale ≈ 0,1 h par m²). Le
## travail n'avance que pendant les horaires de l'équipe (réglage Admin :
## jours ouvrés, tous les jours ou jour et nuit), à l'heure locale du lieu.
## Comme les habitants et les arbres, le chantier suit la vitesse de la vie
## (Population.life_speed) divisée par 3 (1 an de vie = 1 mois de jeu → ×4),
## puis le réglage Admin « rythme des chantiers » (×3) : ×12 en tout, une
## maison de 5 mois demande ≈ 2 semaines de jeu (≈ 6 semaines à ×1).
##
## Avancement gardé dans la donnée du chantier : "av" (0 à 1) et "hr" (heures
## réelles de travail au total). Changer la vitesse de la vie en cours de route
## accélère ou ralentit les chantiers sans rien casser.

## Heures de travail réelles dans un mois (40 h × 52 semaines / 12).
const HEURES_PAR_MOIS := 173.0
## Horaires d'une équipe en journée (heures locales) : 7 h 30 – 12 h et 13 h – 16 h 30.
const PLAGES_JOUR := [[7.5, 12.0], [13.0, 16.5]]
## Réglage Admin « horaires des chantiers ».
const HORAIRES := ["semaine", "tous_les_jours", "continu"]
const HORAIRES_NOMS := ["Jours ouvrés (lun.–ven., 7 h 30–16 h 30)", "Tous les jours, en journée", "Jour et nuit (équipes en 3 × 8)"]

## Étapes d'un bâtiment : [fin de l'étape (avancement), clé, nom].
const ETAPES_BATIMENT := [
	[0.08, "terrassement", "Terrassement"],
	[0.18, "fondations", "Fondations"],
	[0.78, "murs", "Gros œuvre (murs et planchers)"],
	[0.90, "toit", "Charpente et toiture"],
	[1.0, "finitions", "Finitions et abords"],
]
## Étapes d'une voie.
const ETAPES_VOIE := [
	[0.10, "piquetage", "Piquetage du tracé"],
	[0.35, "decapage", "Décapage et terrassement"],
	[0.62, "fond", "Couche de fondation (grave)"],
	[0.90, "revetement", "Revêtement"],
	[1.0, "marquage", "Marquage et finitions"],
]

## Tunnel ou métro creusé depuis la vue sous terre (tunnelier ou méthode
## traditionnelle selon la profondeur).
const ETAPES_TUNNEL := [
	[0.08, "sondages", "Sondages et puits d'accès"],
	[0.60, "creusement", "Creusement (tunnelier) et voussoirs"],
	[0.80, "radier", "Radier, étanchéité et ventilation"],
	[0.95, "equipements", "Voies, chaussée et éclairage"],
	[1.0, "essais", "Essais de sécurité"],
]
## Pièce souterraine (cave, parking, entrepôt, bunker).
const ETAPES_PIECE := [
	[0.10, "sondages", "Sondages et piquetage"],
	[0.45, "terrassement", "Creusement et évacuation des déblais"],
	[0.65, "soutenement", "Soutènement (béton projeté, ancrages)"],
	[0.90, "gros_oeuvre", "Dalles et voiles en béton armé"],
	[1.0, "etancheite", "Étanchéité et finitions"],
]
## Conduite posée en profondeur (microtunnelier, fonçage).
const ETAPES_FONCAGE := [
	[0.15, "puits", "Puits d'entrée et de sortie"],
	[0.70, "foncage", "Fonçage au microtunnelier"],
	[0.90, "pose", "Pose et raccords des tuyaux"],
	[1.0, "essais", "Essais de pression"],
]


## Les chantiers sont-ils instantanés (réglage Admin, bac à sable) ?
static func instantanes() -> bool:
	return ReglagesPartie.actuel.construction_instantanee


static func horaires() -> String:
	return ReglagesPartie.actuel.horaires_chantiers


## L'équipe travaille-t-elle à cette heure locale (heures depuis minuit) et ce jour (0 = lundi) ?
static func au_travail(heure: float, jour_semaine: int, h := "") -> bool:
	if h == "":
		h = horaires()
	if h == "continu":
		return true
	if h == "semaine" and jour_semaine >= 5:
		return false
	for p in PLAGES_JOUR:
		if heure >= float(p[0]) and heure < float(p[1]):
			return true
	return false


## Jour de la semaine (0 = lundi) d'une date locale en secondes (le 1er janvier 1970 était un jeudi).
static func jour_semaine(local_s: float) -> int:
	return posmod(int(floor(local_s / 86400.0)) + 3, 7)


## Heures de travail de l'équipe entre t0 et t1 (secondes Unix du jeu), à l'heure
## locale décalée de offset_h heures par rapport à UTC.
static func heures_ouvrees(t0: float, t1: float, offset_h: float, h := "") -> float:
	if t1 <= t0:
		return 0.0
	if h == "":
		h = horaires()
	if h == "continu":
		return (t1 - t0) / 3600.0
	var a := t0 + offset_h * 3600.0
	var b := t1 + offset_h * 3600.0
	var total := 0.0
	var day := floorf(a / 86400.0)
	var guard := 0
	while day * 86400.0 < b and guard < 4000:
		guard += 1
		var wd := posmod(int(day) + 3, 7)
		if h != "semaine" or wd < 5:
			for p in PLAGES_JOUR:
				var s := day * 86400.0 + float(p[0]) * 3600.0
				var e := day * 86400.0 + float(p[1]) * 3600.0
				total += maxf(0.0, minf(b, e) - maxf(a, s))
		day += 1.0
	return total / 3600.0


## Date (secondes Unix) où l'équipe aura fait `heures` heures de travail en partant de t.
static func date_apres(t: float, heures: float, offset_h: float, h := "") -> float:
	if h == "":
		h = horaires()
	if heures <= 0.0:
		return t
	if h == "continu":
		return t + heures * 3600.0
	var reste := heures * 3600.0
	var a := t + offset_h * 3600.0
	var day := floorf(a / 86400.0)
	for _i in 4000:
		var wd := posmod(int(day) + 3, 7)
		if h != "semaine" or wd < 5:
			for p in PLAGES_JOUR:
				var s := maxf(day * 86400.0 + float(p[0]) * 3600.0, a)
				var e := day * 86400.0 + float(p[1]) * 3600.0
				if e <= s:
					continue
				if e - s >= reste:
					return s + reste - offset_h * 3600.0
				reste -= e - s
		day += 1.0
	return t + heures * 3600.0


# --- Durées réalistes ----------------------------------------------------------------

## Ouvrages élancés dont la hauteur n'est pas faite d'étages (mât, pylône, réservoir
## perché, phare) : [mois de travail réels, équipe complète]. Sans cette table, une
## éolienne de 160 m comptait comme une tour de 50 étages (4 ans, 60 ouvriers).
const OUVRAGES := {
	"eolienne": [2.0, 12],
	"pylone_2g": [1.0, 6], "pylone_4g": [1.0, 6], "pylone_5g": [1.0, 6],
	"chateau_eau": [8.0, 14], "chateau_eau_champignon": [9.0, 16],
	"phare": [8.0, 12],
	# Panneaux posés sur des pieux battus : 2 ha en quelques mois.
	"centrale_solaire": [3.0, 20],
}


## Règle des durées (bâtiments ordinaires) : la durée suit la surface de plancher
## (emprise bâtie × niveaux), avec des rendements décroissants (une équipe plus
## grande travaille en parallèle) : mois = 0,42 × plancher^0,46. Repères réels
## d'aujourd'hui avec une équipe complète :
##   maison ≈ 190 m² → 4 à 6 mois ; immeuble de 8 niveaux ≈ 2 000 m² → 12 à 18 mois ;
##   école ≈ 2 000 m² → 1 an et demi à 2 ans ; hôpital ≈ 10 000 m² → 3 à 4 ans ;
##   stade (emprise, sans niveaux) → 2 à 3 ans ; tour de 40 étages → 4 à 5 ans.
## Puis : × type (technique, simple), × matériaux (bois plus rapide, pierre de
## taille plus lente) et × époque (à la main en 1800, machines aujourd'hui).
const PLANCHER_A := 0.42
const PLANCHER_EXPOSANT := 0.46
## Hauteur d'un niveau pour compter les étages (toit compris dans la hauteur).
const HAUTEUR_NIVEAU := 3.5
## Plafond des bâtiments ordinaires (les grands monuments ont leurs propres durées).
const MOIS_MAX := 120.0
## Catégories à grande emprise ouverte (tribunes, enclos, attractions) : on compte
## l'emprise, pas les niveaux.
const CAT_EMPRISE := ["sport", "parc", "zoo"]
## Complexité par catégorie.
const COEF_CATEGORIE := {
	"logement": 1.0, "commerce": 0.9, "tourisme": 1.0, "industrie": 0.75, "production": 0.75,
	"services": 1.1, "reseaux": 1.2, "dechets": 1.0, "funeraire": 1.0, "loisirs": 0.9,
	"sport": 1.0, "parc": 0.8, "zoo": 0.7, "spectacles": 1.1, "patrimoine": 1.3,
}
## Bâtiments très techniques (mots du nom ou de l'id).
const COEF_MOTS := [
	["nucleaire", 2.5], ["hopital", 1.35], ["clinique", 1.2], ["centrale", 1.4], ["aeroport", 1.3],
	["laboratoire", 1.25], ["gare", 1.15], ["prison", 1.2], ["universite", 1.1], ["hangar", 0.6],
	["entrepot", 0.6], ["serre", 0.5], ["abri", 0.5], ["cabane", 0.6], ["garage", 0.6],
]
## Pierre de taille, maçonnerie lourde : plus lent.
const MOTS_PIERRE := ["pierre", "chateau", "fort", "gothique", "roman", "cathedrale", "abbaye", "monastere", "citadelle"]
## Époques : [jusqu'à l'année (exclue), facteur]. Avant 1850 tout se fait à la main.
const COEF_EPOQUES := [[1850, 1.6], [1900, 1.4], [1945, 1.2], [1980, 1.05]]


## Surface de plancher (m²) servant à la durée d'un type de bâtiment.
static func plancher_batiment(id: String) -> float:
	var t := BuildingCatalog.get_type(id)
	var w := float(t.get("w", 8))
	var d := float(t.get("d", 8))
	var surface := w * d
	# Les grands terrains (usines, fermes) ne sont pas bâtis partout.
	var emprise := surface * (0.6 if surface > 400.0 else 0.8)
	if String(t.get("cat", "")) in CAT_EMPRISE:
		return emprise
	return emprise * niveaux_batiment(id)


static var _niveaux := {}


## Niveaux d'un type de bâtiment, d'après sa hauteur (toit compris).
static func niveaux_batiment(id: String) -> float:
	if not _niveaux.has(id):
		_niveaux[id] = maxf(1.0, floorf(BuildingCatalog.approx_height(id) / HAUTEUR_NIVEAU))
	return float(_niveaux[id])


## Facteur de l'époque (année de jeu) : 1 aujourd'hui, 1,6 en 1800.
static func coef_epoque(annee := -1) -> float:
	if annee < 0:
		annee = MateriauxChantiers._annee()
	for e in COEF_EPOQUES:
		if annee < int(e[0]):
			return float(e[1])
	return 1.0


## Facteur du type (catégorie, bâtiment technique) et des matériaux.
static func coef_type(id: String) -> float:
	var t := BuildingCatalog.get_type(id)
	var k := float(COEF_CATEGORIE.get(String(t.get("cat", "")), 1.0))
	var hay := (id + " " + String(t.get("name", "")) + " " + String(t.get("style", ""))).to_lower()
	hay = hay.replace("ô", "o").replace("é", "e").replace("è", "e").replace("â", "a").replace("ï", "i")
	for m in COEF_MOTS:
		if hay.contains(String(m[0])):
			k *= float(m[1])
			break
	for m in MateriauxChantiers.MOTS_BOIS:
		if hay.contains(m):
			return k * 0.8
	for m in MOTS_PIERRE:
		if hay.contains(m):
			return k * 1.25
	return k


static var _mois_base := {}


## Mois de travail réels d'une équipe complète pour un type de bâtiment, à
## l'époque donnée (année de jeu par défaut).
static func mois_batiment(id: String, annee := -1) -> float:
	if MonumentsTypes.est_monument(id):
		return MonumentsTypes.mois(id)
	if OUVRAGES.has(id):
		return float(OUVRAGES[id][0])
	var t := BuildingCatalog.get_type(id)
	if String(t.get("cat", "")) == "espaces":
		# Places, parcs, bancs : de quelques jours à quelques mois.
		return clampf(sqrt(float(t.get("w", 8)) * float(t.get("d", 8))) / 25.0, 0.1, 6.0)
	if not _mois_base.has(id):
		_mois_base[id] = PLANCHER_A * pow(plancher_batiment(id), PLANCHER_EXPOSANT) * coef_type(id)
	return clampf(float(_mois_base[id]) * coef_epoque(annee), 0.3, MOIS_MAX)


static func heures_batiment(id: String, annee := -1) -> float:
	return mois_batiment(id, annee) * HEURES_PAR_MOIS


## Heures de travail réelles pour un tronçon de voie (longueur en m) : selon
## la surface, plus cher sur les ponts et en tunnel.
static func heures_voie(type_id: String, longueur: float, largeur: float, st: PackedByteArray = PackedByteArray()) -> float:
	var mode := TransportTypes.mode_of(type_id)
	var par_m2 := 0.1
	match mode:
		TransportTypes.Mode.RAIL:
			par_m2 = 0.14
		TransportTypes.Mode.PATH:
			par_m2 = 0.04
		TransportTypes.Mode.WATER:
			par_m2 = 0.005 # balisage d'un chenal
	var ouvrage := 0.0
	if st.size() > 0:
		var n := 0
		for v in st:
			if v == TransportTypes.Struct.BRIDGE or v == TransportTypes.Struct.TUNNEL:
				n += 1
		ouvrage = float(n) / float(st.size())
	var h := longueur * maxf(largeur, 1.5) * par_m2 * (1.0 + ouvrage * 5.0)
	return maxf(h, 8.0)


## Ouvriers d'une équipe complète sur le chantier d'un bâtiment : une maison
## ≈ 8, la Maison de commune ≈ 10, une usine ≈ 20, un hôpital ≈ 35. Avec moins
## d'ouvriers (réserve des fondateurs, entreprises du bâtiment), le chantier
## avance moins vite (Fondateurs).
static var _equipes := {}


static func equipe_batiment(id: String) -> int:
	if _equipes.has(id):
		return int(_equipes[id])
	var n := _equipe_batiment(id)
	_equipes[id] = n
	return n


static func _equipe_batiment(id: String) -> int:
	if MonumentsTypes.est_monument(id):
		return MonumentsTypes.equipe(id)
	if OUVRAGES.has(id):
		return int(OUVRAGES[id][1])
	var t := BuildingCatalog.get_type(id)
	var surface := float(t.get("w", 8)) * float(t.get("d", 8))
	if String(t.get("cat", "")) == "espaces":
		return clampi(roundi(2.0 + sqrt(surface) / 10.0), 2, 10)
	var etages := maxf(1.0, ceilf(BuildingCatalog.approx_height(id) / 3.0))
	return clampi(roundi(3.0 + sqrt(surface) / 3.0 + etages), 3, 60)


## Ouvriers d'une équipe complète sur un chantier de voie ou de réseau, selon
## sa quantité de travail (heures réelles) : 3 pour un petit tronçon, jusqu'à 16.
static func equipe_travaux(heures_reelles: float) -> int:
	return clampi(roundi(2.0 + sqrt(maxf(heures_reelles, 0.0)) / 4.0), 2, 16)


## Rythme : heures réelles faites pour une heure de travail dans le jeu (vitesse de
## la vie × réglage Admin « rythme des chantiers »).
## Les chantiers ne suivent qu'une partie de la vitesse de la vie : vie / 3
## (1 an de vie = 1 mois de jeu → chantiers ×4), jamais moins que ×1. Choix de
## Gaël (2026-11-18) : maison ≈ 2 semaines de jeu, hôpital ≈ 4 mois à ×3.
const VIE_DIVISEUR := 3.0


static func vie_chantiers(pop: Population) -> float:
	var vie := pop.life_speed() if pop != null else float(Population.LIFE_SPEEDS[Population.DEFAULT_LIFE_SPEED])
	return maxf(1.0, vie / VIE_DIVISEUR)


static func rythme(pop: Population) -> float:
	return vie_chantiers(pop) * ReglagesPartie.actuel.rythme_chantiers


# --- Étapes --------------------------------------------------------------------------

## Étapes du chantier d'un type de bâtiment (les grands monuments ont les leurs).
static func etapes_batiment(id: String) -> Array:
	return MonumentsTypes.etapes(id) if MonumentsTypes.est_monument(id) else ETAPES_BATIMENT


## [indice, clé, nom, avancement dans l'étape (0 à 1)] pour un avancement global.
static func etape(etapes: Array, av: float) -> Array:
	var debut := 0.0
	for i in etapes.size():
		var fin := float(etapes[i][0])
		if av < fin or i == etapes.size() - 1:
			return [i, String(etapes[i][1]), String(etapes[i][2]), clampf((av - debut) / maxf(fin - debut, 0.0001), 0.0, 1.0)]
		debut = fin
	return [0, "", "", 0.0]


## Texte court de la durée : « 3 jours », « 2 semaines », « 5 mois ».
static func duree_texte(secondes: float) -> String:
	var j := secondes / 86400.0
	if j < 1.0:
		var h := maxi(1, roundi(secondes / 3600.0))
		return "%d heure%s" % [h, "s" if h > 1 else ""]
	if j < 14.0:
		var n := roundi(j)
		return "%d jour%s" % [n, "s" if n > 1 else ""]
	if j < 60.0:
		return "%d semaines" % roundi(j / 7.0)
	return "%d mois" % roundi(j / 30.44)


const MOIS_NOMS := ["janv.", "févr.", "mars", "avril", "mai", "juin", "juil.", "août", "sept.", "oct.", "nov.", "déc."]


## Date locale courte : « 12 mars, 14 h ».
static func date_texte(unix: float, offset_h: float) -> String:
	var d := Time.get_datetime_dict_from_unix_time(int(unix + offset_h * 3600.0))
	return "%d %s, %d h" % [int(d.day), MOIS_NOMS[int(d.month) - 1], int(d.hour)]
