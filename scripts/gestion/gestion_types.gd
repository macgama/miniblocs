class_name GestionTypes
extends RefCounted
## Mode gestion « tycoon » : ce qu'on gère dans chaque genre de bâtiment.
##
## Un genre (hôtel, puis prison, hôpital, usine…) décrit :
## - ses pièces : "rect" [x, z, largeur, profondeur] en mètres sur le plan
##   du rez-de-chaussée (x vers la droite, z vers la rue ; la caméra regarde
##   depuis l'angle x+ z+), "max" niveaux, "base" niveau de départ (0 : pas
##   construite, 1 : là dès le début), "flag" (ce que la pièce ajoute au
##   bâtiment du jeu : restaurant, piscine, spa…), "decor" (ce que le
##   diorama y dessine : GestionDiorama), "sol" (couleur du sol), "prix"
##   (part du prix du bâtiment pour passer au niveau 2 ; ×1,7 à chaque niveau),
##   "effets" par niveau au-dessus du départ (voir Gestion.effet), "metiers"
##   (employés du jeu qui y travaillent) et "postes" (où ils se tiennent) ;
## - "dehors" : pièces hors les murs (piscine, parking) ;
## - "demandes" : petites demandes des clients, à régler d'un clic ;
## - "activites" : où vont les clients (pièce, part, assis ou debout).
##
## Ajouter un genre = ajouter une entrée à GENRES et dire dans genre_de()
## quels bâtiments s'y rattachent : le diorama, les améliorations, les
## demandes et la sauvegarde suivent sans rien écrire d'autre. Seuls les
## effets sur la simulation sont propres à chaque système (Tourisme pour
## l'hôtel).

## Effets reconnus (par niveau gagné) :
## - "lits" : +x lits (part des lits du bâtiment) ;
## - "confort" : +x points de note (0 à 5) ;
## - "attrait" : +x part de clients en plus ;
## - "satisf" : +x satisfaction des clients chaque jour ;
## - "repas" : +x part des repas pris sur place ;
## - "entretien" : € par jour et par niveau (charges en plus).
const EFFETS := {
	"lits": "lits", "confort": "confort", "attrait": "clients attirés", "satisf": "satisfaction", "repas": "repas sur place",
}

const GENRES := {
	"hotel": {
		"nom": "Hôtel",
		"titre": "Gérer l'hôtel",
		"icone": "lit",
		"plan": Vector2(30, 22),
		"porte": Vector2(15, 22),
		"murs": "e9dcc6",
		"pieces": {
			"reception": {"nom": "Hall et réception", "rect": [10, 14, 10, 8], "max": 5, "base": 1, "prix": 0.004,
				"decor": "reception", "sol": "d9c3a0",
				"effets": {"attrait": 0.05, "confort": 0.05, "entretien": 60.0},
				"metiers": ["receptionniste"], "postes": [[15, 16.0, 0.0]],
				"desc": "Le comptoir, les clés et le sourire. Plus grand et plus beau, il accueille plus de monde sans file d'attente."},
			"chambres": {"nom": "Chambres", "rect": [0, 0, 10, 22], "max": 5, "base": 1, "prix": 0.010,
				"decor": "chambres", "sol": "c9a27e",
				"effets": {"lits": 0.1, "confort": 0.1, "entretien": 220.0},
				"porte": [10, 18],
				"metiers": ["agent_etage"], "postes": [[9.2, 6.0, 0.0], [9.2, 13.0, PI]],
				"desc": "Le cœur de l'hôtel. Chaque niveau ouvre des chambres en plus et les rend plus confortables (literie, salle de bains, vue)."},
			"menage": {"nom": "Lingerie et ménage", "rect": [10, 0, 6, 6], "max": 5, "base": 1, "prix": 0.003,
				"decor": "lingerie", "sol": "b9c7cf",
				"effets": {"satisf": 0.06, "entretien": 50.0},
				"porte": [13, 6], "via": "bar",
				"metiers": ["agent_proprete"], "postes": [[13.0, 2.2, PI]],
				"desc": "Draps propres, serviettes pliées en cygne. Les clients le remarquent tout de suite (surtout quand ça manque)."},
			"direction": {"nom": "Bureau de la direction", "rect": [16, 0, 4, 6], "max": 5, "base": 1, "prix": 0.003,
				"decor": "bureau", "sol": "8fa3b8",
				"effets": {"attrait": 0.03, "satisf": 0.03, "entretien": 40.0},
				"porte": [18, 6], "via": "bar",
				"metiers": ["cadre"], "postes": [[18.0, 0.9, 0.0]],
				"desc": "Réservations, publicité en ligne et tableau des plannings. Un bon directeur remplit l'hôtel."},
			"bar": {"nom": "Bar et salon", "rect": [10, 6, 10, 8], "max": 5, "base": 0, "prix": 0.004,
				"decor": "bar", "sol": "a8735a",
				"effets": {"confort": 0.12, "attrait": 0.02, "entretien": 90.0},
				"porte": [15, 14],
				"metiers": ["serveur"], "postes": [[13.5, 7.1, 0.0]],
				"desc": "Fauteuils club, cocktails et piano. Les clients y passent la soirée (et y laissent un peu d'argent)."},
			"restaurant": {"nom": "Restaurant", "rect": [20, 12, 10, 10], "max": 5, "base": 0, "prix": 0.006, "flag": "restaurant",
				"decor": "restaurant", "sol": "e6d2b5",
				"effets": {"repas": 0.08, "confort": 0.1, "entretien": 160.0},
				"porte": [20, 18],
				"metiers": ["cuisinier", "serveur"], "postes": [[28.6, 14.2, PI * 0.5], [23.7, 15.8, 0.0]],
				"desc": "Petit-déjeuner, déjeuner, dîner : les clients mangent sur place au lieu d'aller en ville, et l'hôtel encaisse."},
			"spa": {"nom": "Spa et bien-être", "rect": [20, 0, 10, 12], "max": 5, "base": 0, "prix": 0.007, "flag": "spa",
				"decor": "spa", "sol": "cfe3e0",
				"effets": {"confort": 0.16, "attrait": 0.03, "entretien": 180.0},
				"porte": [25, 12], "via": "restaurant",
				"metiers": ["maitre_nageur"], "postes": [[22.9, 2.2, -PI * 0.5]],
				"desc": "Hammam, massages et tisanes. Les clients repartent détendus et laissent de meilleures notes."},
		},
		"dehors": {
			"piscine": {"nom": "Piscine", "rect": [32, 6, 10, 14], "max": 5, "base": 0, "prix": 0.008, "flag": "piscine",
				"decor": "piscine", "sol": "e8e2d4",
				"effets": {"confort": 0.15, "attrait": 0.05, "entretien": 200.0},
				"porte": [30, 17], "via": "restaurant",
				"metiers": ["maitre_nageur"], "postes": [[33.2, 18.2, PI * 0.5]],
				"desc": "Bassin, transats et parasols. En été, c'est la première chose que les clients regardent sur les photos."},
			"parking": {"nom": "Parking et voiturier", "rect": [0, 25, 30, 8], "max": 5, "base": 0, "prix": 0.003,
				"decor": "parking", "sol": "6b6f75",
				"effets": {"attrait": 0.06, "entretien": 30.0},
				"metiers": [], "postes": [],
				"desc": "Des places devant la porte, puis un voiturier. Les clients venus en voiture choisissent l'hôtel où l'on se gare."},
		},
		"ordre": ["reception", "chambres", "menage", "direction", "bar", "restaurant", "spa", "piscine", "parking"],
		"activites": [["chambres", 0.5, false], ["restaurant", 0.2, true], ["bar", 0.12, true], ["spa", 0.08, true], ["piscine", 0.1, true]],
		"demandes": [
			{"id": "serviettes", "piece": "chambres", "texte": "Des serviettes propres, s'il vous plaît !", "pourboire": 8},
			{"id": "valises", "piece": "reception", "texte": "Quelqu'un peut monter nos valises ?", "pourboire": 15},
			{"id": "reveil", "piece": "chambres", "texte": "Réveil à 6 h demain, j'ai un train.", "pourboire": 5},
			{"id": "bruit", "piece": "chambres", "texte": "Les voisins chantent du karaoké…", "pourboire": 4},
			{"id": "plat", "piece": "restaurant", "texte": "Mon plat est froid !", "pourboire": 6},
			{"id": "vin", "piece": "restaurant", "texte": "La carte des vins, je vous prie.", "pourboire": 12},
			{"id": "cocktail", "piece": "bar", "texte": "Un cocktail maison, avec une ombrelle.", "pourboire": 10},
			{"id": "massage", "piece": "spa", "texte": "Il reste un créneau de massage ?", "pourboire": 20},
			{"id": "transat", "piece": "piscine", "texte": "Plus un seul transat de libre !", "pourboire": 6},
			{"id": "wifi", "piece": "reception", "texte": "Le code du wifi ne marche pas.", "pourboire": 3},
		],
		"pensees": {
			"regle": ["Service impeccable, merci !", "Rapide et souriant, bravo.", "Voilà ce que j'appelle un hôtel."],
			"rate": ["Personne n'est venu…", "J'attends toujours.", "Je le dirai dans mon avis."],
		},
	},
}


## Genre de gestion d'un type de bâtiment ("" : pas de mode gestion).
static func genre_de(type_id: String) -> String:
	if type_id == "":
		return ""
	var sp := TourismeTypes.spec_of(type_id)
	if String(sp.get("role", "")) == "hebergement" and String(sp.get("genre", "")) == "hotel":
		return "hotel"
	return ""


static func genre(g: String) -> Dictionary:
	return GENRES.get(g, {})


## Toutes les pièces d'un genre (dedans et dehors).
static func pieces(g: String) -> Dictionary:
	var gd := genre(g)
	var out: Dictionary = (gd.get("pieces", {}) as Dictionary).duplicate()
	out.merge(gd.get("dehors", {}))
	return out


static func piece(g: String, pid: String) -> Dictionary:
	return pieces(g).get(pid, {})


static func ordre(g: String) -> Array:
	return genre(g).get("ordre", pieces(g).keys())


static func est_dehors(g: String, pid: String) -> bool:
	return (genre(g).get("dehors", {}) as Dictionary).has(pid)


## Pièce qui accueille un métier du jeu (première trouvée), "" sinon.
static func piece_du_metier(g: String, met: String) -> String:
	for pid in ordre(g):
		if met in (piece(g, String(pid)).get("metiers", []) as Array):
			return String(pid)
	return ""
