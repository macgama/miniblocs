class_name SanteDonnees
extends RefCounted
## Données de la santé publique : vaccins datés, mesures sanitaires, grandes
## épidémies de l'histoire et repères de la médecine (annoncés le jour venu).
## Les maladies elles-mêmes sont dans Epidemies.MALADIES.

## Vaccins : année d'arrivée (en France), efficacité, cible, prix d'une dose.
## "annuel" : la protection ne dure qu'une année (grippe).
const VACCINS := {
	"variole": {"nom": "Variole", "annee": 1800, "efficacite": 0.95, "cible": "tous", "dose": 3.0, "maladies": ["variole"],
		"desc": "La vaccine de Jenner, tirée du pis des vaches. Les Parisiens trouvent l'idée bizarre, mais elle marche."},
	"typhoide": {"nom": "Typhoïde", "annee": 1896, "efficacite": 0.6, "cible": "tous", "dose": 4.0, "maladies": ["typhoide"],
		"desc": "Protège à moitié. Contre la typhoïde, l'eau propre reste la meilleure arme."},
	"diphterie": {"nom": "Diphtérie", "annee": 1923, "efficacite": 0.9, "cible": "enfants", "dose": 4.0, "maladies": ["diphterie"],
		"desc": "L'anatoxine de Gaston Ramon. Le croup ne fait plus peur aux parents."},
	"grippe": {"nom": "Grippe", "annee": 1945, "efficacite": 0.5, "cible": "tous", "dose": 8.0, "annuel": true,
		"maladies": ["grippe", "grippe_asiatique", "grippe_hk"], "desc": "À refaire chaque année : le virus change de manteau tous les hivers."},
	"polio": {"nom": "Poliomyélite", "annee": 1955, "efficacite": 0.9, "cible": "enfants", "dose": 5.0, "maladies": ["polio"],
		"desc": "Le vaccin de Jonas Salk. Fini les poumons d'acier."},
	"rougeole": {"nom": "Rougeole", "annee": 1963, "efficacite": 0.95, "cible": "enfants", "dose": 6.0, "maladies": ["rougeole"],
		"desc": "Deux doses dans l'enfance et la rougeole devient un souvenir de grand-mère."},
	"covid": {"nom": "Covid-19", "annee": 2021, "efficacite": 0.7, "cible": "tous", "dose": 20.0, "maladies": ["covid"],
		"desc": "Vaccin à ARN messager, mis au point en moins d'un an. Le frigo doit être très, très froid."},
}

## Part des habitants qui refusent le vaccin (sans obligation), selon l'année.
const HESITANTS := [[1800, 0.35], [1870, 0.25], [1920, 0.12], [1960, 0.06], [2000, 0.12], [2020, 0.18]]
## Avec l'obligation vaccinale : il reste quelques irréductibles.
const HESITANTS_OBLIGATION := 0.03

## Mesures sanitaires (arrêtés du maire). "temporaire" : levée seule une semaine
## après la fin de l'épidémie. Coût par jour : fixe + par habitant.
const MESURES := {
	"quarantaine": {"nom": "Quarantaine des malades", "annee": 1800, "fixe": 40.0, "hab": 0.02, "satisfaction": -1.0, "temporaire": true,
		"desc": "Les malades et leur foyer ne sortent plus. Contagion hors de la maison : ÷3.",
		"oui": "Quarantaine : les malades ne quittent plus leur maison. Les voisins apportent la soupe sur le palier."},
	"ecoles": {"nom": "Fermer les écoles", "annee": 1800, "fixe": 0.0, "hab": 0.0, "satisfaction": -4.0, "temporaire": true,
		"desc": "Plus de contagion à l'école. Les parents, eux, gardent les enfants.",
		"oui": "Les écoles ferment. Les enfants hurlent de joie, les parents moins."},
	"lazaret": {"nom": "Ouvrir un lazaret", "annee": 1800, "fixe": 300.0, "hab": 0.05, "satisfaction": 0.0, "temporaire": true,
		"desc": "Hôpital de campagne sous toile : des lits pour les cas graves, même sans hôpital.",
		"oui": "Un lazaret est monté sous des tentes. Le confort est rustique, mais on y est soigné."},
	"hygiene": {"nom": "Campagne d'hygiène", "annee": 1847, "fixe": 60.0, "hab": 0.03, "satisfaction": 0.0, "temporaire": false,
		"desc": "Affiches, savon et lavage des mains : contagion ×0,8, et ×0,7 pour les maladies de l'eau.",
		"oui": "Campagne d'hygiène : « Lavez-vous les mains ! » Le savonnier fait fortune."},
	"eau_bouillie": {"nom": "Faire bouillir l'eau", "annee": 1854, "fixe": 20.0, "hab": 0.01, "satisfaction": -1.0, "temporaire": true,
		"desc": "Depuis le docteur Snow et sa pompe de Broad Street : contagion par l'eau ÷2,5.",
		"oui": "Avis à la population : faites bouillir l'eau ! Les bouilloires chantent dans toute la ville."},
	"chloration": {"nom": "Chlorer l'eau du réseau", "annee": 1902, "fixe": 150.0, "hab": 0.04, "satisfaction": 0.0, "temporaire": false,
		"desc": "Un peu de chlore dans l'eau du réseau : plus aucun microbe au robinet. L'eau a un goût de piscine.",
		"oui": "L'eau du réseau est désormais chlorée. Goût de piscine garanti, microbes en moins."},
	"masques": {"nom": "Masques obligatoires", "annee": 1918, "fixe": 30.0, "hab": 0.05, "satisfaction": -3.0, "temporaire": true,
		"desc": "Contagion par l'air ×0,6. Les lunettes se couvrent de buée.",
		"oui": "Masques obligatoires en ville. On se reconnaît aux sourcils."},
	"confinement": {"nom": "Confinement", "annee": 1918, "fixe": 200.0, "hab": 0.6, "satisfaction": -10.0, "temporaire": true,
		"desc": "Écoles, bureaux et usines au ralenti : contacts au travail ÷4, écoles fermées. Aides aux commerces payées par la ville.",
		"oui": "Confinement ! Les rues se vident, les boulangeries restent ouvertes. Record de ventes de farine."},
}

## Grandes épidémies de l'histoire : elles arrivent l'année venue (époques).
## "rumeur" : nouvelle quelques mois avant, pour se préparer.
const PANDEMIES := [
	{"annee": 1832, "maladie": "cholera", "nom": "Choléra de 1832",
		"rumeur": "Le choléra, parti des bords du Gange, traverse l'Europe. On dit qu'il sera là avant l'été."},
	{"annee": 1849, "maladie": "cholera", "nom": "Choléra de 1849",
		"rumeur": "Le choléra est de retour en Europe. Les médecins se disputent : miasmes ou eau sale ?"},
	{"annee": 1854, "maladie": "cholera", "nom": "Choléra de 1854",
		"rumeur": "Un médecin de Londres, John Snow, accuse une pompe à eau d'avoir tué tout un quartier."},
	{"annee": 1866, "maladie": "cholera", "nom": "Choléra de 1866", "rumeur": "Le choléra revient par les ports. Les égouts neufs seront-ils prêts ?"},
	{"annee": 1870, "maladie": "variole", "nom": "Variole de 1870", "rumeur": "La guerre et la variole avancent ensemble. Les vaccinés dorment tranquilles."},
	{"annee": 1884, "maladie": "cholera", "nom": "Choléra de 1884", "rumeur": "Le choléra frappe Toulon et Marseille. Robert Koch vient d'identifier son bacille."},
	{"annee": 1892, "maladie": "cholera", "nom": "Choléra de 1892", "rumeur": "Hambourg boit l'eau de l'Elbe sans la filtrer, et le choléra y fait des ravages."},
	{"annee": 1918, "maladie": "grippe_espagnole", "nom": "Grippe espagnole",
		"rumeur": "Une grippe étrange circule dans les tranchées. La censure l'appelle « espagnole », l'Espagne proteste."},
	{"annee": 1957, "maladie": "grippe_asiatique", "nom": "Grippe asiatique", "rumeur": "Une nouvelle grippe venue d'Asie fait le tour du monde en quelques mois."},
	{"annee": 1968, "maladie": "grippe_hk", "nom": "Grippe de Hong Kong", "rumeur": "Une grippe partie de Hong Kong arrive par avion. Les hôpitaux se préparent."},
	{"annee": 2020, "maladie": "covid", "nom": "Covid-19",
		"rumeur": "Un nouveau coronavirus circule en Chine. Les rayons de papier toilette commencent à frémir."},
]
## Jours de jeu entre la rumeur et le risque d'arrivée.
const RUMEUR_AVANCE := 45

## Repères de la médecine (annoncés le jour où ils arrivent, panneau Histoire).
const REPERES := [
	{"annee": 1800, "texte": "La vaccine contre la variole arrive en France."},
	{"annee": 1847, "texte": "Semmelweis prouve qu'il suffit de se laver les mains pour sauver les accouchées."},
	{"annee": 1854, "texte": "John Snow montre que le choléra vient de l'eau souillée."},
	{"annee": 1864, "texte": "Pasteur et la pasteurisation : les microbes existent, et on peut les tuer."},
	{"annee": 1882, "texte": "Koch découvre le bacille de la tuberculose, puis celui du choléra (1884)."},
	{"annee": 1894, "texte": "Le sérum antidiphtérique de Roux : on guérit enfin le croup."},
	{"annee": 1902, "texte": "Loi sur la santé publique : vaccin antivariolique obligatoire, chlore dans l'eau."},
	{"annee": 1928, "texte": "Fleming découvre la pénicilline… en oubliant de laver ses boîtes de culture."},
	{"annee": 1945, "texte": "Les antibiotiques pour tous : typhoïde et choléra se soignent."},
	{"annee": 1955, "texte": "Le vaccin contre la polio de Jonas Salk."},
	{"annee": 1980, "texte": "L'OMS déclare la variole éradiquée de la planète."},
]

## Mesures dont le joueur peut parler à la gazette (nouvelles du jour).
const LEVEES := {
	"quarantaine": "Fin de la quarantaine : les familles ressortent, un peu pâles.",
	"ecoles": "Les écoles rouvrent. Les cartables avaient pris la poussière.",
	"lazaret": "Le lazaret est démonté. Les tentes partiront au prochain cirque.",
	"eau_bouillie": "On peut de nouveau boire l'eau sans la faire bouillir. Les bouilloires se reposent.",
	"masques": "Fin des masques obligatoires. Les sourires sont de retour.",
	"confinement": "Fin du confinement ! Les coiffeurs sont pris d'assaut.",
}


static func hesitants(annee: int) -> float:
	var v := float(HESITANTS[0][1])
	for row in HESITANTS:
		if annee >= int(row[0]):
			v = float(row[1])
	return v


static func vaccins_de(maladie: String) -> Array:
	var out := []
	for k in VACCINS:
		if (VACCINS[k].maladies as Array).has(maladie):
			out.append(k)
	return out
