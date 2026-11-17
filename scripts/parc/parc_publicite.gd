class_name ParcPublicite
extends RefCounted
## Publicité du parc de loisirs : campagnes ciblées (onglet Publicité, Maj+G).
##
## - Une campagne = un support (affiches, journal, radio, télévision, Internet,
##   réseaux sociaux…), une cible (tout le monde, les habitants, les touristes,
##   les familles, les amateurs de sensations) et une durée (1 à 8 semaines).
##   Elle coûte chaque jour son prix par semaine ÷ 7, payé par la caisse de la
##   ville du parc.
## - Elle fait monter la notoriété du parc, en ville (habitants) et dans la
##   région (touristes). La notoriété retombe doucement quand on arrête (−4 %
##   par jour) : il faut entretenir. Effet sur les visiteurs : jusqu'à +60 %
##   d'habitants et +100 % de touristes à notoriété maximale.
## - Une pub pour un parc mal noté marche moitié moins (le bouche-à-oreille
##   dément les affiches) ; cibler les sensations sans attraction à sensations,
##   c'est jeter l'argent par la fenêtre.
## - Familles : plus de visiteurs qui aiment les manèges doux et dépensent aux
##   stands. Sensations : plus de visiteurs qui cherchent les grands frissons.
## - Époques : chaque support a son année (la radio en 1922, la télévision en
##   1950, Internet en 1996, les réseaux sociaux en 2006, les influenceurs en 2012).

const SUPPORTS := {
	"affiches": {"nom": "Affiches en ville", "annee": 1800, "semaine": 1_200.0, "ville": 0.030, "region": 0.004,
		"desc": "Colleurs d'affiches et colonnes Morris. Toute la ville est au courant, la région un peu moins."},
	"journal": {"nom": "Annonce dans le journal", "annee": 1800, "semaine": 3_000.0, "ville": 0.025, "region": 0.015,
		"desc": "Un encart dans la gazette régionale, entre la météo et les petites annonces."},
	"depliants": {"nom": "Dépliants dans les gares et hôtels", "annee": 1850, "semaine": 2_000.0, "ville": 0.006, "region": 0.026,
		"desc": "Les voyageurs les lisent dans le train. Puis s'en servent comme éventail."},
	"radio": {"nom": "Spots à la radio", "annee": 1922, "semaine": 9_000.0, "ville": 0.040, "region": 0.045,
		"desc": "Trente secondes et un jingle qu'on n'arrive plus à se sortir de la tête."},
	"television": {"nom": "Publicité à la télévision", "annee": 1950, "semaine": 45_000.0, "ville": 0.060, "region": 0.110,
		"desc": "Juste avant le journal du soir. Cher, mais tout le pays la voit."},
	"panneaux_route": {"nom": "Panneaux au bord des routes", "annee": 1960, "semaine": 4_000.0, "ville": 0.010, "region": 0.032,
		"desc": "« Parc à 12 km ! » Les enfants sur la banquette arrière font le reste."},
	"internet": {"nom": "Site et bannières sur Internet", "annee": 1996, "semaine": 6_000.0, "ville": 0.020, "region": 0.045,
		"desc": "Un site avec les horaires, les prix et une bannière qui clignote."},
	"reseaux_sociaux": {"nom": "Réseaux sociaux", "annee": 2006, "semaine": 12_000.0, "ville": 0.045, "region": 0.060, "jeunes": true,
		"desc": "Vidéos des montagnes russes, concours et mèmes. Surtout les jeunes."},
	"influenceurs": {"nom": "Influenceurs", "annee": 2012, "semaine": 20_000.0, "ville": 0.030, "region": 0.085, "jeunes": true,
		"desc": "Une vedette du web filme sa journée au parc. Ses abonnés veulent la même."},
}
const SUPPORTS_ORDRE := ["affiches", "journal", "depliants", "radio", "television", "panneaux_route", "internet", "reseaux_sociaux", "influenceurs"]

## Cibles : [poids ville, poids région], et le public qu'elles amènent.
const CIBLES := {
	"tous": {"nom": "Tout le monde", "ville": 1.0, "region": 1.0},
	"habitants": {"nom": "Les habitants de la ville", "ville": 1.6, "region": 0.35},
	"touristes": {"nom": "Les touristes de la région", "ville": 0.35, "region": 1.6},
	"familles": {"nom": "Les familles", "ville": 1.2, "region": 0.9, "public": "familles"},
	"sensations": {"nom": "Les amateurs de sensations", "ville": 0.9, "region": 1.2, "public": "sensations"},
}
const CIBLES_ORDRE := ["tous", "habitants", "touristes", "familles", "sensations"]
const DUREES := [1, 2, 4, 8]
## Campagnes en même temps, au plus, par parc.
const MAX_CAMPAGNES := 4
## Notoriété perdue chaque jour.
const OUBLI := 0.04
## Effet maximal sur les visiteurs (×(1 + …) à notoriété 1).
const EFFET_VILLE := 0.6
const EFFET_REGION := 1.0


static func disponible(support: String) -> bool:
	if not SUPPORTS.has(support):
		return false
	return not Epoques.actif() or int(SUPPORTS[support].annee) <= Epoques.annee()


static func raison(support: String) -> String:
	if not SUPPORTS.has(support):
		return "Support inconnu."
	if not disponible(support):
		return "Pas encore inventé : arrive en %d." % int(SUPPORTS[support].annee)
	return ""


## Supports qu'on peut utiliser à l'époque de la partie.
static func supports_possibles() -> Array:
	return SUPPORTS_ORDRE.filter(func(s: String) -> bool: return disponible(s))


## Prix total d'une campagne.
static func cout(support: String, semaines: int) -> float:
	return float(SUPPORTS.get(support, {}).get("semaine", 0.0)) * semaines


static func vide() -> Dictionary:
	return {"ville": 0.0, "region": 0.0, "familles": 0.0, "sensations": 0.0}


## Multiplicateurs des visiteurs [touristes, habitants] selon la notoriété.
static func effet(noto: Dictionary) -> Array:
	return [1.0 + EFFET_REGION * clampf(float(noto.get("region", 0.0)), 0.0, 1.0),
		1.0 + EFFET_VILLE * clampf(float(noto.get("ville", 0.0)), 0.0, 1.0)]


## Efficacité d'une campagne pour ce parc (0,2 à 1,2).
static func efficacite(c: Dictionary, note: float, sensations: bool) -> float:
	var f := 0.5 + 0.5 * clampf(note / 4.0, 0.0, 1.0)
	if String(c.get("cible", "")) == "sensations" and not sensations:
		f *= 0.3
	if bool(SUPPORTS.get(String(c.get("support", "")), {}).get("jeunes", false)) and String(c.get("cible", "")) == "sensations":
		f *= 1.25
	return clampf(f, 0.2, 1.2)


## Un jour de publicité : fait monter la notoriété, renvoie le coût du jour.
static func jour(p: Dictionary, jour_n: int, sensations: bool) -> float:
	var noto: Dictionary = p.get("noto", vide())
	var cout_jour := 0.0
	var gain := vide()
	var restantes: Array = []
	for c in p.get("campagnes", []):
		if int(c.fin) < jour_n:
			continue
		var s: Dictionary = SUPPORTS.get(String(c.support), {})
		var cb: Dictionary = CIBLES.get(String(c.cible), CIBLES.tous)
		if s.is_empty():
			continue
		restantes.append(c)
		cout_jour += float(s.semaine) / 7.0
		var eff := efficacite(c, float(p.get("note", 2.5)), sensations)
		gain.ville = float(gain.ville) + float(s.ville) * float(cb.ville) * eff
		gain.region = float(gain.region) + float(s.region) * float(cb.region) * eff
		if cb.has("public"):
			gain[String(cb.public)] = float(gain[String(cb.public)]) + 0.06 * eff
		c.depense = float(c.get("depense", 0.0)) + float(s.semaine) / 7.0
	p.campagnes = restantes
	for k in noto.keys():
		var v := float(noto[k]) * (1.0 - OUBLI)
		v += float(gain.get(k, 0.0)) * (1.0 - v)
		noto[k] = clampf(v, 0.0, 1.0)
	p.noto = noto
	p.pub_jour = cout_jour
	return cout_jour


## Lance une campagne. Renvoie "" ou la raison du refus.
static func lancer(p: Dictionary, support: String, cible: String, semaines: int, jour_n: int) -> String:
	var why := raison(support)
	if why != "":
		return why
	if not CIBLES.has(cible):
		return "Cible inconnue."
	var camps: Array = p.get("campagnes", [])
	if camps.size() >= MAX_CAMPAGNES:
		return "Déjà %d campagnes en cours : c'est le maximum." % MAX_CAMPAGNES
	for c in camps:
		if String(c.support) == support:
			c.fin = int(c.fin) + semaines * 7
			c.cible = cible
			return ""
	camps.append({"support": support, "cible": cible, "debut": jour_n, "fin": jour_n + semaines * 7, "depense": 0.0})
	p.campagnes = camps
	return ""


static func arreter(p: Dictionary, support: String) -> void:
	p.campagnes = (p.get("campagnes", []) as Array).filter(func(c: Dictionary) -> bool: return String(c.support) != support)


## Public particulier amené par la pub : "familles", "sensations" ou "" (au hasard).
static func public_au_hasard(noto: Dictionary, x: float) -> String:
	var f := clampf(float(noto.get("familles", 0.0)), 0.0, 1.0) * 0.5
	var s := clampf(float(noto.get("sensations", 0.0)), 0.0, 1.0) * 0.5
	if x < f:
		return "familles"
	if x < f + s:
		return "sensations"
	return ""
