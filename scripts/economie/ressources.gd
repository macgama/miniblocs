class_name Ressources
extends RefCounted
## Ressources naturelles et marchandises de MiniBlocs.
##
## Une ressource NATURELLE est une richesse du sol ou de l'eau, de 0 à 1 sur
## chaque case (voir CarteRessources) : forêt, pierre, gisement de fer… Un
## bâtiment d'extraction posé dessus en tire une MARCHANDISE (en tonnes), que
## d'autres bâtiments transforment (voir Production). Les prix sont des ordres
## de grandeur réels, en euros par tonne.

## Ressources naturelles. renouvelable : la ressource repousse (bois, poisson,
## sols) ; sinon le gisement s'épuise. good : marchandise extraite.
const NATURELLES := {
	"bois": {"name": "Forêt (bois)", "color": Color("2d6a4f"), "good": "bois", "renouvelable": true, "repousse": true,
		"desc": "Forêts réelles (ESA WorldCover)."},
	"fertilite": {"name": "Terres cultivables", "color": Color("e9c46a"), "good": "cereales", "renouvelable": true,
		"desc": "Champs et prairies réels, pente, altitude et climat (latitude)."},
	"paturage": {"name": "Pâturages", "color": Color("95d5b2"), "good": "betail", "renouvelable": true,
		"desc": "Prairies, alpages et landes."},
	"poisson": {"name": "Poisson", "color": Color("48cae4"), "good": "poisson", "renouvelable": true, "repousse": true,
		"desc": "Mer (plateau continental plus riche), lacs et rivières."},
	"pierre": {"name": "Pierre et calcaire", "color": Color("adb5bd"), "good": "pierre", "renouvelable": false, "infini": true,
		"desc": "Roche nue, versants pentus et montagne."},
	"sable": {"name": "Sable et graviers", "color": Color("f4d58d"), "good": "sable", "renouvelable": false, "infini": true,
		"desc": "Bords de rivière, plages et déserts."},
	"argile": {"name": "Argile", "color": Color("bc6c25"), "good": "argile", "renouvelable": false, "infini": true,
		"desc": "Plaines basses et zones humides."},
	"calcaire": {"name": "Calcaire", "color": Color("e9e4c9"), "good": "calcaire", "renouvelable": false, "infini": true,
		"desc": "Régions calcaires réelles (Bassin parisien, Jura, Causses, Provence…), là où la roche affleure."},
	"granite": {"name": "Granite", "color": Color("b5838d"), "good": "granite", "renouvelable": false, "infini": true,
		"desc": "Massifs granitiques réels (Bretagne, Massif central, Vosges, Corse…), là où la roche affleure."},
	"sel": {"name": "Sel gemme", "color": Color("f8f9fa"), "good": "sel", "renouvelable": false,
		"desc": "Bassins salifères réels (Lorraine, Jura, Cheshire, Wieliczka, Salzkammergut…)."},
	"fer": {"name": "Minerai de fer", "color": Color("9d0208"), "good": "minerai_fer", "renouvelable": false,
		"desc": "Bassins ferrifères réels (Lorraine, Pilbara, Kiruna…)."},
	"charbon": {"name": "Charbon", "color": Color("343a40"), "good": "charbon", "renouvelable": false,
		"desc": "Bassins houillers réels (Ruhr, Nord-Pas-de-Calais, Kouzbass…)."},
	"cuivre": {"name": "Cuivre", "color": Color("e76f51"), "good": "minerai_cuivre", "renouvelable": false,
		"desc": "Ceintures cuprifères réelles (Atacama, Copperbelt…)."},
	"or": {"name": "Or", "color": Color("ffd60a"), "good": "minerai_or", "renouvelable": false,
		"desc": "Districts aurifères réels (Witwatersrand, Kalgoorlie, Guyane…)."},
	"bauxite": {"name": "Bauxite", "color": Color("d62828"), "good": "bauxite", "renouvelable": false,
		"desc": "Bauxite tropicale (Guinée, Australie, Jamaïque, Provence…)."},
	"petrole": {"name": "Pétrole", "color": Color("6a4c93"), "good": "petrole", "renouvelable": false,
		"desc": "Bassins pétroliers réels (golfe Persique, mer du Nord, Aquitaine…)."},
	"gaz": {"name": "Gaz naturel", "color": Color("4895ef"), "good": "gaz", "renouvelable": false,
		"desc": "Champs gaziers réels (Lacq, Groningue, Ourengoï…)."},
}
## Ordre d'affichage.
const ORDRE := ["bois", "fertilite", "paturage", "poisson", "pierre", "sable", "argile", "calcaire", "granite", "sel",
	"fer", "charbon", "cuivre", "or", "bauxite", "petrole", "gaz"]
## Ressources du sous-sol (gisements placés d'après les vraies régions minières).
const SOUS_SOL := ["fer", "charbon", "cuivre", "or", "bauxite", "sel", "petrole", "gaz"]
## Roches de carrière : la province (calcaire, granite) donne la nature de la
## roche, le relief dit où elle affleure.
const ROCHES := ["calcaire", "granite"]
## Ce que peut extraire une mine, un puits.
const MINERAIS := ["fer", "charbon", "cuivre", "or", "bauxite"]
const HYDROCARBURES := ["petrole", "gaz"]

## Marchandises : prix de gros (€/t). conso : vendue aux habitants dans les
## commerces (prix de détail = prix × DETAIL). liquide / vrac / grumes : le
## camion qui la transporte (citerne, benne, grumier ; sinon camion à caisse).
const MARCHANDISES := {
	"bois": {"name": "Bois", "prix": 60.0, "camion": "grumes"},
	"pierre": {"name": "Granulats (pierre concassée)", "prix": 15.0, "camion": "vrac"},
	"calcaire": {"name": "Calcaire", "prix": 12.0, "camion": "vrac"},
	"granite": {"name": "Granite (pierre de taille)", "prix": 140.0},
	"sel": {"name": "Sel", "prix": 60.0, "camion": "vrac"},
	"sable": {"name": "Sable", "prix": 12.0, "camion": "vrac"},
	"argile": {"name": "Argile", "prix": 10.0, "camion": "vrac"},
	"minerai_fer": {"name": "Minerai de fer", "prix": 100.0, "camion": "vrac"},
	"charbon": {"name": "Charbon", "prix": 120.0, "camion": "vrac"},
	"minerai_cuivre": {"name": "Minerai de cuivre", "prix": 40.0, "camion": "vrac"},
	"minerai_or": {"name": "Minerai d'or", "prix": 150.0, "camion": "vrac"},
	"bauxite": {"name": "Bauxite", "prix": 45.0, "camion": "vrac"},
	"petrole": {"name": "Pétrole brut", "prix": 550.0, "camion": "liquide"},
	"gaz": {"name": "Gaz naturel", "prix": 300.0, "camion": "liquide"},
	"cereales": {"name": "Céréales", "prix": 220.0, "camion": "vrac"},
	"betteraves": {"name": "Betteraves sucrières", "prix": 40.0, "camion": "vrac"},
	"fibres": {"name": "Lin et coton", "prix": 1500.0},
	"betail": {"name": "Bétail", "prix": 2500.0},
	"lait": {"name": "Lait cru", "prix": 500.0, "camion": "liquide"},
	"oleagineux": {"name": "Colza, tournesol et soja", "prix": 450.0, "camion": "vrac"},
	"foin": {"name": "Foin", "prix": 150.0, "camion": "vrac"},
	"paille": {"name": "Paille", "prix": 90.0, "camion": "vrac"},
	"fumier": {"name": "Fumier", "prix": 15.0, "camion": "vrac"},
	"laine": {"name": "Laine", "prix": 2000.0},
	"oeufs": {"name": "Œufs", "prix": 2500.0, "conso": true},
	"huile": {"name": "Huile", "prix": 1600.0, "conso": true, "camion": "liquide"},
	"poisson": {"name": "Poisson", "prix": 3000.0, "conso": true},
	"fruits_legumes": {"name": "Fruits et légumes", "prix": 1500.0, "conso": true},
	"planches": {"name": "Planches", "prix": 300.0},
	"farine": {"name": "Farine", "prix": 600.0},
	"sucre": {"name": "Sucre", "prix": 600.0},
	"pain": {"name": "Pain et viennoiseries", "prix": 3500.0, "conso": true},
	"viande": {"name": "Viande", "prix": 7000.0, "conso": true},
	"laitages": {"name": "Lait, fromages et yaourts", "prix": 3000.0, "conso": true},
	"epicerie": {"name": "Épicerie (pâtes, conserves, biscuits)", "prix": 2500.0, "conso": true},
	"boissons": {"name": "Boissons", "prix": 600.0, "conso": true},
	"verre": {"name": "Verre", "prix": 400.0},
	"papier": {"name": "Papier et carton", "prix": 800.0},
	"chimie": {"name": "Produits chimiques", "prix": 1000.0, "camion": "liquide"},
	"plastique": {"name": "Plastiques", "prix": 1300.0},
	"balles_tri": {"name": "Balles de tri (papier, plastique, métal)", "prix": 120.0},
	"hygiene": {"name": "Hygiène et entretien", "prix": 3500.0, "conso": true},
	"vetements": {"name": "Vêtements et chaussures", "prix": 15000.0, "conso": true},
	"medicaments": {"name": "Médicaments", "prix": 50000.0, "conso": true},
	"acier": {"name": "Acier", "prix": 700.0},
	"aluminium": {"name": "Aluminium", "prix": 2300.0},
	"carburant": {"name": "Carburant", "prix": 900.0, "conso": true, "camion": "liquide"},
	"briques": {"name": "Briques", "prix": 200.0},
	"ciment": {"name": "Ciment", "prix": 120.0, "camion": "vrac"},
	"cuivre": {"name": "Cuivre", "prix": 9000.0},
	"electronique": {"name": "Électronique (téléphones, ordinateurs)", "prix": 30000.0, "conso": true},
	"meubles": {"name": "Meubles", "prix": 3000.0, "conso": true},
	"biens": {"name": "Électroménager et outils", "prix": 6000.0, "conso": true},
	"voitures": {"name": "Voitures neuves", "prix": 15000.0, "conso": true},
}
## Prix de détail (vente aux habitants) par rapport au prix de gros.
const DETAIL := 1.4
## Prix à l'export par rapport au prix de gros (transport, intermédiaires).
const EXPORT := 0.8
## Prix d'une marchandise importée (achetée hors de la carte).
const IMPORT := 1.25

## Consommation par habitant et par jour (tonnes), ordre de grandeur français ;
## carburant et voitures neuves : par voiture du foyer.
const CONSO_HABITANT := {"pain": 0.0002, "viande": 0.00016, "poisson": 0.00005, "laitages": 0.0003,
	"fruits_legumes": 0.0004, "epicerie": 0.0003, "oeufs": 0.00004, "huile": 0.00004, "boissons": 0.0005, "hygiene": 0.00006,
	"vetements": 0.00001, "medicaments": 0.000005, "electronique": 0.000005, "meubles": 0.00002, "biens": 0.0001}
const CONSO_VOITURE := {"carburant": 0.003, "voitures": 0.0003}
## Besoins de première nécessité : un rayon vide fâche davantage.
## Nourriture : ce qui compte pour les repas des habitants (voir Repas).
const NOURRITURE := ["pain", "viande", "poisson", "laitages", "fruits_legumes", "epicerie", "oeufs", "huile"]
const ESSENTIELS := ["pain", "laitages", "fruits_legumes", "epicerie", "boissons", "hygiene", "viande", "medicaments", "carburant"]

## Commerces : ce qu'ils vendent aux habitants. Clé = type, archétype ou
## catégorie (comme Metiers.PAR_BATIMENT). fait : le commerce fabrique lui-même
## une partie de ce qu'il vend (le boulanger pétrit sa farine). Les cafés et
## restaurants ne vendent rien à emporter : ils consomment (t par visiteur et
## par jour) pour servir leurs clients.
const COMMERCES := {
	"boulangerie": {"vend": ["pain"], "fait": {"in": {"farine": 0.75}, "out": {"pain": 1.0}}},
	"superette": {"vend": ["pain", "laitages", "fruits_legumes", "epicerie", "boissons", "hygiene", "viande", "oeufs", "huile"]},
	"supermarche": {"vend": ["pain", "viande", "poisson", "laitages", "fruits_legumes", "epicerie", "oeufs", "huile",
		"boissons", "hygiene",
		"vetements", "electronique", "biens", "carburant"]},
	"marche": {"vend": ["fruits_legumes", "viande", "poisson", "laitages", "pain", "oeufs"]},
	"boutique": {"vend": ["vetements"]},
	"boutique_mode": {"vend": ["vetements"]},
	"grand_magasin": {"vend": ["vetements", "meubles", "electronique", "biens", "hygiene"]},
	"magasin_multimedia": {"vend": ["electronique", "biens"]},
	"magasin_meubles": {"vend": ["meubles"]},
	"station_service": {"vend": ["carburant", "boissons", "epicerie"]},
	"pharmacie": {"vend": ["medicaments", "hygiene"]},
	"concession_auto": {"vend": ["voitures"]},
	"cafe": {"consomme": {"boissons": 0.00025, "pain": 0.00004, "laitages": 0.00003, "fruits_legumes": 0.00006, "viande": 0.00004}},
	"restaurant": {"consomme": {"boissons": 0.0003, "pain": 0.00005, "viande": 0.00012, "poisson": 0.00004,
		"fruits_legumes": 0.00015, "laitages": 0.00005, "epicerie": 0.00005}},
}
## Prix moyen d'un repas ou d'une consommation au café (€ par visiteur servi).
const REPAS := 14.0


## Profil de commerce d'un type de bâtiment ({} si ce n'est pas un commerce de détail).
static func commerce_of(type_id: String) -> Dictionary:
	for k in Metiers.keys_of(type_id):
		if COMMERCES.has(k):
			return COMMERCES[k]
	return {}


## Camion qui transporte une marchandise : "caisse", "liquide", "vrac" ou "grumes".
static func truck_kind(good: String) -> String:
	return String(MARCHANDISES.get(good, {}).get("camion", "caisse"))


static func naturelle(id: String) -> Dictionary:
	return NATURELLES.get(id, {})


static func good_name(id: String) -> String:
	return String(MARCHANDISES.get(id, {}).get("name", id))


static func price(id: String) -> float:
	return float(MARCHANDISES.get(id, {}).get("prix", 0.0))


## Ressource naturelle d'où vient une marchandise ("" si fabriquée).
static func source_of(good: String) -> String:
	for id in NATURELLES:
		if String(NATURELLES[id].good) == good:
			return id
	return ""


## « 12,5 t », « 850 kg », « 3 g ».
static func format_t(t: float) -> String:
	var a := absf(t)
	if a >= 1000.0:
		return "%s t" % _thousands(roundi(t))
	if a >= 10.0:
		return "%d t" % roundi(t)
	if a >= 1.0:
		return ("%.1f t" % t).replace(".", ",")
	if a >= 0.001:
		return "%d kg" % roundi(t * 1000.0)
	if a > 0.0:
		return "%d g" % maxi(roundi(t * 1_000_000.0), 1)
	return "0 t"


static func _thousands(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = " " + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if v < 0 else "") + s + out
