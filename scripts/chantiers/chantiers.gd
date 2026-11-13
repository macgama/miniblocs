class_name Chantiers
extends RefCounted
## Règles communes des chantiers (bâtiments et voies) : durées réalistes,
## horaires des équipes, étapes, avancement.
##
## Principe : chaque chantier a une quantité de travail en « heures réelles »
## (une maison ≈ 6 mois d'une équipe, une départementale ≈ 0,1 h par m²). Le
## travail n'avance que pendant les horaires de l'équipe (réglage Admin :
## jours ouvrés, tous les jours ou jour et nuit), à l'heure locale du lieu.
## Comme les habitants et les arbres, le chantier suit la vitesse de la vie
## (Population.life_speed) : 1 an de vie = 1 mois de jeu par défaut, donc une
## maison de 6 mois demande 6 / 12 mois de travail, soit ≈ 2 semaines de jeu.
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

## Mois de travail réels d'une équipe pour un type de bâtiment.
static func mois_batiment(id: String) -> float:
	var t := BuildingCatalog.get_type(id)
	var w := float(t.get("w", 8))
	var d := float(t.get("d", 8))
	var surface := w * d
	if String(t.get("cat", "")) == "espaces":
		# Places, parcs, bancs : de quelques jours à quelques mois.
		return clampf(sqrt(surface) / 25.0, 0.1, 6.0)
	var etages := maxf(1.0, ceilf(BuildingCatalog.approx_height(id) / 3.0))
	# Maison ≈ 6 à 8 mois, immeuble de 6 étages ≈ 1 an, tour de 20 étages ≈ 2 ans et demi ;
	# les grandes emprises (usines, hôpitaux) ajoutent du temps.
	var mois := 3.0 + 1.6 * pow(etages, 0.9) + sqrt(surface) / 20.0
	if surface < 40.0 and etages <= 1.0:
		mois *= 0.4 # cabanon, kiosque
	return clampf(mois, 0.5, 48.0)


static func heures_batiment(id: String) -> float:
	return mois_batiment(id) * HEURES_PAR_MOIS


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


## Rythme : heures réelles faites pour une heure de travail dans le jeu.
static func rythme(pop: Population) -> float:
	return pop.life_speed() if pop != null else float(Population.LIFE_SPEEDS[Population.DEFAULT_LIFE_SPEED])


# --- Étapes --------------------------------------------------------------------------

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
