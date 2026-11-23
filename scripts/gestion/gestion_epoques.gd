class_name GestionEpoques
extends RefCounted
## Mode gestion : ce qui dépend de l'époque et du pays, pour tous les genres.
##
## - Un objet n'est achetable qu'une fois inventé : année de son modèle
##   (MODELES) ou "annee" de l'objet ; "jusqu" : plus vendu après cette année
##   (la pompe à bras, la lampe à pétrole…).
## - Une pièce peut aussi attendre son année ("annee" de la pièce, ou
##   PIECES pour les genres faits à la main : l'imagerie de l'hôpital, la
##   salle informatique…).
## - Les noms changent selon le pays de la partie (NOMS_PAYS pour les genres
##   faits à la main, "noms_pays" des fiches GenresAuto :
##   {"ch": {"titre": …, "pieces": {pid: nom}}}) et selon l'époque
##   ("noms_epoque" : [[année jusqu'à laquelle, {"pieces": {pid: nom}}], …]).
## Hors époques (partie moderne sans année), tout est permis.

## Année d'invention des modèles d'objets (les autres : toujours possibles).
const MODELES := {
	"tele_meuble": 1950, "tele_pied": 1955, "ecran": 1985, "ecran_pied": 1990, "mur_ecrans": 1995, "ordinateur": 1980,
	"imprimante": 1985, "imprimante_3d": 2012, "clim": 1955, "minibar": 1960, "borne": 1995, "borne_recharge": 2010,
	"tablette_resa": 2010, "camera_surv": 1975, "radar": 1960, "scanner": 1975, "echographe": 1970, "moniteur_medical": 1965,
	"respirateur": 1955, "robot_chir": 2000, "robot": 1985, "robot_bras": 1980, "agv": 1995, "defibrillateur": 1965,
	"frigo_sang": 1940, "spectrometre": 1960, "negatoscope": 1910, "table_radio": 1900, "jacuzzi": 1970, "sauna": 1900,
	"tapis_course": 1975, "velo": 1960, "rameur": 1970, "juke_box": 1930, "expresso": 1905, "machine_cafe": 1950,
	"lave_vaisselle": 1955, "lave_linge": 1950, "lave_linge_xxl": 1955, "seche_linge": 1960, "seche_mains": 1950,
	"chambre_froide": 1920, "armoire_froide": 1930, "friteuse": 1950, "four_mixte": 1980, "panneaux_solaires": 1990,
	"eolienne": 1995, "helico": 1955, "moto_police": 1910, "voiture": 1905, "camionnette": 1920, "camion_semi": 1950,
	"chariot_elevateur": 1930, "depanneuse": 1920, "estafette": 1959, "navette": 1960, "scooter": 1950, "feu_tricolore": 1925,
	"chargeur_radios": 1950, "baie_radio": 1930, "enceinte": 1930, "pk_ecran_attente": 1995, "pk_borne_billets": 1990,
	"pk_borne_photo": 2000, "pk_projecteurs": 1950, "valise_empreintes": 1905, "labo_police": 1910, "simulateur_feu": 1995,
	"desincarceration": 1970, "motopompe": 1920, "compresseur": 1900, "machine_outil": 1850, "presse": 1850, "convoyeur": 1915,
	"emballeuse": 1950, "filmeuse": 1975, "etiqueteuse": 1950, "filtre_manches": 1950, "pont_roulant": 1880, "pompe_carburant": 1905,
	"distributeur": 1950, "fontaine_eau": 1910, "pointeuse": 1890, "horloges": 1800, "microscope": 1800,
}

## Modèles qui ne se vendent plus après une année.
const JUSQU := {"pompe_bras": 1920, "camion_ancien": 1970, "estafette": 1980}

## Pièces des genres faits à la main qui attendent leur année : "genre/pièce" → année.
const PIECES := {
	"hopital/imagerie": 1896, "hopital/helistation": 1960, "hopital/regulation": 1968, "hopital/garage": 1900,
	"caserne/alerte": 1880, "caserne/sport": 1900, "commissariat/commandement": 1920, "commissariat/tir": 1900,
	"hotel/spa": 1850, "hotel/sport": 1960, "hotel/conference": 1900, "hotel/piscine": 1900, "hotel/parking": 1910,
	"restaurant/livraison": 1900, "usine/energie": 1880, "usine/epuration": 1960, "usine/labo": 1880,
}

## Noms selon le pays pour les genres faits à la main : genre → {pays: {"titre", "pieces"}}.
const NOMS_PAYS := {
	"commissariat": {"ch": {"titre": "Gérer le poste de police", "pieces": {"commandement": "Centrale d'engagement (117)"}},
		"be": {"titre": "Gérer le commissariat", "pieces": {"commandement": "Dispatching (101)"}}},
	"hopital": {"ch": {"pieces": {"regulation": "Centrale sanitaire (144)"}}, "be": {"pieces": {"regulation": "Centrale 112"}}},
	"caserne": {"ch": {"pieces": {"alerte": "Centrale d'alarme (118)"}}, "be": {"pieces": {"alerte": "Centrale 112"}}},
}


static var _adaptes := {}


## Genre fait à la main aux noms du pays de la partie (copie gardée en cache).
static func adapter(g: String, gd: Dictionary) -> Dictionary:
	var np: Dictionary = (NOMS_PAYS.get(g, {}) as Dictionary).get(pays(), {})
	if np.is_empty():
		return gd
	var c: Dictionary = _adaptes.get(g + "|" + pays(), {})
	if not c.is_empty():
		return c
	var out := gd.duplicate(true)
	if np.has("titre"):
		out["titre"] = String(np.titre)
	for pid in (np.get("pieces", {}) as Dictionary):
		for cle in ["pieces", "dehors"]:
			var ps: Dictionary = out.get(cle, {})
			if ps.has(pid):
				ps[pid]["nom"] = String(np.pieces[pid])
				ps[pid]["court"] = String(np.pieces[pid]).split(" (")[0]
	_adaptes[g + "|" + pays()] = out
	return out


static func annee() -> int:
	return EpoquesObjets.annee_partie()


## Code du pays de la partie (« fr », « ch »…).
static func pays() -> String:
	return String(GameStart.pays).to_lower()


static func annee_objet(o: Dictionary) -> int:
	if o.has("annee"):
		return int(o.annee)
	return int(MODELES.get(String(o.get("modele", "")), 0))


static func jusqu_objet(o: Dictionary) -> int:
	if o.has("jusqu"):
		return int(o.jusqu)
	return int(JUSQU.get(String(o.get("modele", "")), 99999))


static func annee_piece(g: String, pid: String) -> int:
	var p := GestionTypes.piece(g, pid)
	if p.has("annee"):
		return int(p.annee)
	return int(PIECES.get(g + "/" + pid, 0))


## Pourquoi un objet n'existe pas à l'époque de la partie ("" : il existe).
static func refus_objet(g: String, pid: String, oid: String) -> String:
	var o := GestionTypes.objet(g, pid, oid)
	var an := annee()
	var a := annee_objet(o)
	if a > an:
		return "pas encore inventé (vers %d)" % a
	var j := jusqu_objet(o)
	if j < an:
		return "ne se fait plus depuis %d" % j
	return ""


static func refus_piece(g: String, pid: String) -> String:
	var a := annee_piece(g, pid)
	if a > annee():
		return "pas encore à cette époque (vers %d)" % a
	return ""
