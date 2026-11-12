class_name Metiers
extends RefCounted
## Métiers, horaires, salaires et loisirs des habitants.
##
## Chaque emploi d'un bâtiment (champ "emplois" du catalogue) reçoit un métier
## tiré dans la liste du bâtiment. Salaires nets mensuels en euros (ordre de
## grandeur français). Jours : "semaine" (lundi-vendredi), "lunsam",
## "marsam" (mardi-samedi), "tous", "garde" (un jour sur deux, de 7 h à 19 h).

const METIERS := {
	"boulanger": {"name": "Boulanger·ère", "salaire": 1750, "h": [5.0, 13.0], "j": "marsam"},
	"vendeur": {"name": "Vendeur·euse", "salaire": 1500, "h": [9.0, 19.0], "j": "lunsam"},
	"caissier": {"name": "Caissier·ère", "salaire": 1450, "h": [8.5, 19.5], "j": "lunsam"},
	"magasinier": {"name": "Magasinier·ère", "salaire": 1700, "h": [6.0, 14.0], "j": "semaine"},
	"chauffeur": {"name": "Chauffeur·euse livreur", "salaire": 1850, "h": [6.0, 15.0], "j": "semaine"},
	"employe": {"name": "Employé·e de bureau", "salaire": 2200, "h": [9.0, 17.5], "j": "semaine"},
	"cadre": {"name": "Cadre", "salaire": 3900, "h": [8.5, 18.5], "j": "semaine"},
	"ingenieur": {"name": "Ingénieur·e", "salaire": 3500, "h": [9.0, 18.0], "j": "semaine"},
	"artisan": {"name": "Artisan·e", "salaire": 2000, "h": [8.0, 17.0], "j": "semaine"},
	"ouvrier": {"name": "Ouvrier·ère", "salaire": 1800, "h": [6.0, 14.0], "j": "semaine"},
	"agriculteur": {"name": "Agriculteur·rice", "salaire": 1600, "h": [6.0, 19.0], "j": "tous"},
	"agent_public": {"name": "Agent·e municipal·e", "salaire": 1900, "h": [8.5, 17.0], "j": "semaine", "public": true},
	"enseignant": {"name": "Enseignant·e", "salaire": 2400, "h": [8.0, 17.0], "j": "ecole", "public": true, "etat": true},
	"atsem": {"name": "ATSEM (aide en maternelle)", "salaire": 1650, "h": [8.0, 17.0], "j": "ecole", "public": true, "etat": true},
	"pompier": {"name": "Sapeur·euse-pompier", "salaire": 2300, "h": [7.0, 19.0], "j": "garde", "public": true},
	"policier": {"name": "Policier·ère", "salaire": 2400, "h": [7.0, 19.0], "j": "garde", "public": true, "etat": true},
	"medecin": {"name": "Médecin", "salaire": 5500, "h": [8.0, 19.0], "j": "semaine", "public": true, "etat": true},
	"infirmier": {"name": "Infirmier·ère", "salaire": 2250, "h": [7.0, 19.0], "j": "garde", "public": true, "etat": true},
	"aide_soignant": {"name": "Aide-soignant·e", "salaire": 1750, "h": [7.0, 19.0], "j": "garde", "public": true, "etat": true},
	"serveur": {"name": "Serveur·euse", "salaire": 1550, "h": [11.0, 23.0], "j": "marsam"},
	"cuisinier": {"name": "Cuisinier·ère", "salaire": 1850, "h": [10.0, 22.0], "j": "marsam"},
	"agent_cinema": {"name": "Agent·e de cinéma", "salaire": 1550, "h": [13.0, 23.5], "j": "tous"},
	"coach": {"name": "Éducateur·rice sportif·ve", "salaire": 1850, "h": [9.0, 20.0], "j": "marsam"},
	"comedien": {"name": "Comédien·ne", "salaire": 2200, "h": [14.0, 23.5], "j": "marsam"},
	"agent_gare": {"name": "Agent·e de gare", "salaire": 2100, "h": [6.0, 18.0], "j": "garde"},
	# Production et ressources.
	"bucheron": {"name": "Bûcheron·ne", "salaire": 1750, "h": [7.0, 16.0], "j": "semaine"},
	"carrier": {"name": "Carrier·ère", "salaire": 1850, "h": [7.0, 15.0], "j": "semaine"},
	"conducteur_engins": {"name": "Conducteur·rice d'engins", "salaire": 2000, "h": [7.0, 15.0], "j": "semaine"},
	"mineur": {"name": "Mineur·e", "salaire": 2300, "h": [6.0, 14.0], "j": "garde"},
	"foreur": {"name": "Foreur·euse", "salaire": 2800, "h": [7.0, 19.0], "j": "garde"},
	"eleveur": {"name": "Éleveur·euse", "salaire": 1550, "h": [6.0, 19.0], "j": "tous"},
	"pecheur": {"name": "Marin·e pêcheur", "salaire": 2100, "h": [4.0, 13.0], "j": "lunsam"},
	"meunier": {"name": "Meunier·ère", "salaire": 1800, "h": [6.0, 14.0], "j": "semaine"},
	"boucher": {"name": "Boucher·ère", "salaire": 1850, "h": [5.0, 13.0], "j": "lunsam"},
	"siderurgiste": {"name": "Sidérurgiste", "salaire": 2200, "h": [6.0, 14.0], "j": "garde"},
	"operateur": {"name": "Opérateur·rice de production", "salaire": 2300, "h": [6.0, 14.0], "j": "garde"},
	"menuisier": {"name": "Menuisier·ère", "salaire": 1900, "h": [8.0, 17.0], "j": "semaine"},
	"pharmacien": {"name": "Pharmacien·ne", "salaire": 3600, "h": [9.0, 19.5], "j": "lunsam"},
	"mecanicien": {"name": "Mécanicien·ne", "salaire": 1900, "h": [8.0, 18.0], "j": "lunsam"},
	"maraicher": {"name": "Maraîcher·ère", "salaire": 1600, "h": [6.0, 17.0], "j": "lunsam"},
	"laborantin": {"name": "Technicien·ne de laboratoire", "salaire": 2300, "h": [8.0, 17.0], "j": "semaine"},
}

## Métiers proposés par bâtiment : clé = type, archétype de style ou catégorie.
const PAR_BATIMENT := {
	"boulangerie": [["boulanger", 3], ["vendeur", 1]],
	"superette": [["vendeur", 1], ["caissier", 1]],
	"boutique": [["vendeur", 3], ["artisan", 1]],
	"supermarche": [["caissier", 4], ["vendeur", 3], ["magasinier", 2], ["cadre", 1]],
	"marche": [["vendeur", 4], ["caissier", 1], ["magasinier", 1]],
	"grand_magasin": [["vendeur", 4], ["caissier", 3], ["magasinier", 2], ["cadre", 1]],
	"bureaux": [["employe", 6], ["cadre", 3], ["ingenieur", 2]],
	"gratte_ciel": [["employe", 5], ["cadre", 4], ["ingenieur", 3]],
	"atelier": [["artisan", 7], ["ouvrier", 3]],
	"usine": [["ouvrier", 7], ["ingenieur", 1], ["magasinier", 1], ["cadre", 1]],
	"entrepot": [["magasinier", 6], ["chauffeur", 4]],
	"ferme": [["agriculteur", 1]],
	"mairie": [["agent_public", 4], ["cadre", 1]],
	"palais": [["agent_public", 4], ["cadre", 1]],
	"ecole": [["enseignant", 7], ["atsem", 2], ["agent_public", 1]],
	"pompiers": [["pompier", 1]],
	"police": [["policier", 1]],
	"hopital": [["medecin", 2], ["infirmier", 5], ["aide_soignant", 3]],
	"cafe": [["serveur", 3], ["cuisinier", 2]],
	"restaurant": [["serveur", 3], ["cuisinier", 2]],
	"cinema": [["agent_cinema", 1]],
	"theatre": [["comedien", 1], ["agent_public", 1]],
	"gymnase": [["coach", 1]],
	"piscine": [["coach", 1]],
	"gare": [["agent_gare", 1]],
	"exploitation_forestiere": [["bucheron", 3], ["conducteur_engins", 1], ["chauffeur", 1]],
	"carriere": [["carrier", 2], ["conducteur_engins", 2], ["chauffeur", 2]],
	"sabliere": [["carrier", 1], ["conducteur_engins", 1], ["chauffeur", 1]],
	"argiliere": [["carrier", 1], ["conducteur_engins", 1], ["chauffeur", 1]],
	"mine": [["mineur", 6], ["conducteur_engins", 2], ["ingenieur", 1], ["chauffeur", 2]],
	"puits": [["foreur", 2], ["ingenieur", 1], ["chauffeur", 1]],
	"ferme_cereales": [["agriculteur", 1], ["chauffeur", 1]],
	"ferme_maraichere": [["maraicher", 4], ["chauffeur", 1]],
	"ferme_betteraves": [["agriculteur", 1], ["chauffeur", 1]],
	"ferme_fibres": [["agriculteur", 1], ["chauffeur", 1]],
	"elevage": [["eleveur", 3], ["chauffeur", 1]],
	"ferme_laitiere": [["eleveur", 3], ["chauffeur", 1]],
	"port_peche": [["pecheur", 4], ["magasinier", 1], ["chauffeur", 1]],
	"scierie": [["ouvrier", 3], ["conducteur_engins", 1], ["chauffeur", 1]],
	"moulin": [["meunier", 2], ["chauffeur", 1]],
	"fournil": [["boulanger", 3], ["chauffeur", 1]],
	"abattoir": [["boucher", 3], ["ouvrier", 1], ["chauffeur", 1]],
	"laiterie": [["ouvrier", 3], ["operateur", 1], ["chauffeur", 1]],
	"sucrerie": [["operateur", 2], ["ouvrier", 2], ["chauffeur", 1]],
	"usine_agro": [["ouvrier", 5], ["operateur", 1], ["magasinier", 1], ["chauffeur", 1]],
	"brasserie": [["operateur", 2], ["ouvrier", 2], ["chauffeur", 1]],
	"acierie": [["siderurgiste", 6], ["ouvrier", 2], ["ingenieur", 1], ["chauffeur", 1]],
	"raffinerie": [["operateur", 4], ["ingenieur", 1], ["chauffeur", 1]],
	"briqueterie": [["ouvrier", 3], ["operateur", 1], ["chauffeur", 1]],
	"cimenterie": [["operateur", 2], ["ouvrier", 2], ["chauffeur", 1]],
	"verrerie": [["operateur", 2], ["ouvrier", 2], ["chauffeur", 1]],
	"papeterie": [["operateur", 2], ["ouvrier", 2], ["chauffeur", 1]],
	"usine_chimique": [["operateur", 3], ["ingenieur", 1], ["chauffeur", 1]],
	"fonderie_cuivre": [["siderurgiste", 3], ["ingenieur", 1], ["chauffeur", 1]],
	"aluminerie": [["operateur", 4], ["ingenieur", 1], ["chauffeur", 1]],
	"menuiserie": [["menuisier", 3], ["chauffeur", 1]],
	"usine_textile": [["ouvrier", 6], ["magasinier", 1], ["chauffeur", 1]],
	"usine_hygiene": [["ouvrier", 4], ["operateur", 1], ["chauffeur", 1]],
	"labo_pharma": [["laborantin", 4], ["ingenieur", 2], ["chauffeur", 1]],
	"usine_biens": [["ouvrier", 7], ["ingenieur", 1], ["magasinier", 1], ["cadre", 1], ["chauffeur", 1]],
	"usine_electronique": [["ouvrier", 6], ["ingenieur", 2], ["magasinier", 1], ["chauffeur", 1]],
	"usine_auto": [["ouvrier", 8], ["ingenieur", 1], ["magasinier", 1], ["chauffeur", 1]],
	"transporteur": [["chauffeur", 8], ["magasinier", 1], ["cadre", 1]],
	"station_service": [["caissier", 2], ["mecanicien", 1]],
	"pharmacie": [["pharmacien", 1], ["vendeur", 2]],
	"concession_auto": [["vendeur", 2], ["mecanicien", 2]],
	"boutique_mode": [["vendeur", 3], ["caissier", 1]],
	"magasin_multimedia": [["vendeur", 3], ["caissier", 1], ["magasinier", 1]],
	"magasin_meubles": [["vendeur", 2], ["magasinier", 1], ["chauffeur", 1]],
	# Repli par catégorie.
	"production": [["ouvrier", 3], ["conducteur_engins", 1]],
	"commerce": [["vendeur", 2], ["caissier", 1]],
	"industrie": [["ouvrier", 3], ["magasinier", 1]],
	"services": [["agent_public", 1]],
	"loisirs": [["serveur", 1]],
	"sport": [["coach", 1]],
	"espaces": [["agent_public", 1]],
	"logement": [["agent_public", 1]],
}

## Loisirs. lieux : types, archétypes ou "cat:<catégorie>" où ils se pratiquent
## (vide = à la maison). age : [min, max].
const LOISIRS := {
	"football": {"name": "Football", "lieux": ["foot"], "age": [5, 55]},
	"tennis": {"name": "Tennis", "lieux": ["tennis"], "age": [6, 80]},
	"basket": {"name": "Basket", "lieux": ["basket", "gymnase"], "age": [8, 50]},
	"natation": {"name": "Natation", "lieux": ["piscine"], "age": [4, 90]},
	"musculation": {"name": "Sport en salle", "lieux": ["gymnase"], "age": [15, 75]},
	"cinema": {"name": "Cinéma", "lieux": ["cinema"], "age": [6, 95]},
	"theatre": {"name": "Théâtre", "lieux": ["theatre", "kiosque_musique"], "age": [10, 95]},
	"cafe": {"name": "Café entre amis", "lieux": ["cafe", "restaurant"], "age": [16, 95]},
	"promenade": {"name": "Promenade", "lieux": ["parc", "jardin", "cat:espaces"], "age": [0, 100]},
	"aire_jeux": {"name": "Aire de jeux", "lieux": ["aire_jeux", "parc"], "age": [2, 10]},
	"skate": {"name": "Skate", "lieux": ["skatepark"], "age": [9, 35]},
	"jardinage": {"name": "Jardinage", "lieux": ["jardin_partage"], "age": [10, 100], "maison": true},
	"lecture": {"name": "Lecture", "lieux": [], "age": [6, 100]},
	"jeux_video": {"name": "Jeux vidéo", "lieux": [], "age": [7, 60]},
	"musique": {"name": "Musique", "lieux": [], "age": [6, 90]},
	"cuisine": {"name": "Cuisine", "lieux": [], "age": [14, 100]},
	"dessin": {"name": "Dessin", "lieux": [], "age": [3, 90]},
	"shopping": {"name": "Shopping", "lieux": ["cat:commerce"], "age": [13, 90]},
	"priere": {"name": "Vie spirituelle", "lieux": ["culte"], "age": [6, 100]},
}


## Clé de recherche d'un type de bâtiment : son id, son archétype, sa catégorie.
static func keys_of(type_id: String) -> Array:
	var t := BuildingCatalog.get_type(type_id)
	var out := [type_id]
	if t.has("arch"):
		out.append(String(t.arch))
	out.append(String(t.get("cat", "")))
	return out


static func jobs_for(type_id: String) -> Array:
	for k in keys_of(type_id):
		if PAR_BATIMENT.has(k):
			return PAR_BATIMENT[k]
	return [["employe", 1]]


static func pick_job(rng: RandomNumberGenerator, type_id: String) -> String:
	var list := jobs_for(type_id)
	var total := 0
	for e in list:
		total += int(e[1])
	var r := rng.randi() % maxi(total, 1)
	for e in list:
		r -= int(e[1])
		if r < 0:
			return String(e[0])
	return String(list[0][0])


static func job(id: String) -> Dictionary:
	return METIERS.get(id, METIERS.employe)


## Le bâtiment convient-il au loisir ?
static func venue_matches(hobby: String, type_id: String) -> bool:
	var lieux: Array = LOISIRS[hobby].lieux
	if lieux.is_empty():
		return false
	var t := BuildingCatalog.get_type(type_id)
	for l in lieux:
		var s := String(l)
		if s.begins_with("cat:"):
			# Les « commerces » sans clients (bureaux) ne comptent pas.
			if String(t.get("cat", "")) == s.substr(4) and (s != "cat:commerce" or int(t.get("visiteurs", 0)) > 0):
				return true
		elif s == type_id or s == String(t.get("arch", "")):
			return true
	return false


## Tire 1 à 3 loisirs adaptés à l'âge.
static func pick_hobbies(rng: RandomNumberGenerator, age: float) -> Array:
	var ok := []
	for k in LOISIRS:
		var a: Array = LOISIRS[k].age
		if age >= float(a[0]) and age <= float(a[1]):
			ok.append(k)
	var out := []
	var n := 1 + rng.randi() % 3
	while out.size() < n and not ok.is_empty():
		var i := rng.randi() % ok.size()
		out.append(ok[i])
		ok.remove_at(i)
	return out


## Classe d'un élève selon son âge (système français).
static func school_class(age: int) -> String:
	const CLASSES := ["Petite section", "Moyenne section", "Grande section", "CP", "CE1", "CE2", "CM1", "CM2",
		"6e", "5e", "4e", "3e", "Seconde", "Première", "Terminale"]
	return CLASSES[clampi(age - 3, 0, CLASSES.size() - 1)]


static func school_level(age: int) -> String:
	if age < 6:
		return "maternelle"
	if age < 11:
		return "élémentaire"
	if age < 15:
		return "collège"
	return "lycée"
