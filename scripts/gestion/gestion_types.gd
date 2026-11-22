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
##   diorama y dessine : GestionDiorama), "sol" (couleur du sol) et "motif"
##   (parquet, damier, carrelage, moquette, gazon, dalles), "prix" (part du
##   prix du bâtiment pour passer au niveau 2 ; ×1,7 à chaque niveau),
##   "effets" par niveau au-dessus du départ (voir Gestion.effet),
##   "metiers" (employés du jeu qui y travaillent), "postes" (où ils se
##   tiennent, [x, z, angle] en coordonnées du plan), "porte" et "via"
##   (par où passent les clients), "chemin" (points de passage après la
##   porte, pour les pièces du dehors) ;
## - "objets" de chaque pièce : ce qu'on achète en plus (télé, minibar,
##   piano, sauna, toboggan…) : "nom", "modele" (GestionDiorama._modele),
##   "poses" [[x, z, angle], …] relatives au coin de la pièce (ou de chaque
##   chambre si "cellules"), "prix" (part du prix du bâtiment), "niv"
##   (niveau de pièce requis), "effets" (mêmes clés que les pièces) ;
## - "dehors" : pièces hors les murs (piscine, jardin, parking) ;
## - "demandes" : petites demandes des clients, à régler d'un clic ;
## - "pannes" : ce qui peut casser dans chaque pièce ;
## - "activites" : où vont les clients (pièce, part).
##
## Ajouter un genre = ajouter une entrée à GENRES et dire dans genre_de()
## quels bâtiments s'y rattachent : le diorama, les améliorations, les
## objets, les demandes, les pannes, la gestion automatique et la
## sauvegarde suivent sans rien écrire d'autre. Seuls les effets sur la
## simulation sont propres à chaque système ("source" : Tourisme pour
## l'hôtel, Production pour le restaurant). Les grands genres ont leur
## fichier dans scripts/gestion/genres (GenreRestaurant…).

## Effets reconnus (par niveau gagné, ou par objet acheté) :
## - "lits" : +x lits (part des lits du bâtiment) ;
## - "confort" : +x points de note (0 à 5) ;
## - "attrait" : +x part de clients en plus ;
## - "satisf" : +x satisfaction des clients chaque jour ;
## - "repas" : +x part des repas pris sur place ;
## - "vitesse" : +x vitesse du service (réception, file d'attente) ;
## - "ventes" : +x € dépensés par client (et par nuit) dans l'établissement ;
## - "couverts" : +x part de couverts (restaurant : tables en plus) ;
## - "equipage" / "engins" : personnes de garde / véhicules en plus (services d'urgence) ;
## - "enquete" : part des cambriolages élucidés malgré une patrouille en retard (police) ;
## - "soins" : part des malaises en retard qu'on sauve quand même (hôpital) ;
## - "lits_sup" : lits d'hôpital en plus (un nombre, pas une part) ;
## - "entretien" : € par jour (charges en plus).
const EFFETS := {
	"lits": "lits", "confort": "confort", "attrait": "clients attirés", "satisf": "satisfaction", "repas": "repas sur place",
	"vitesse": "vitesse du service", "ventes": "dépenses des clients", "couverts": "couverts",
	"equipage": "personnes de garde", "engins": "véhicules", "enquete": "affaires élucidées", "soins": "qualité des soins", "lits_sup": "lits d'hôpital",
}

const GENRES := {
	"hotel": {
		"nom": "Hôtel",
		"titre": "Gérer l'hôtel",
		"icone": "lit",
		"le": "l'hôtel",
		"du": "de l'hôtel",
		"source": "tourisme",
		"accueil": "reception",
		"classe": "étoiles",
		"unite": "lits",
		"remplir": "Remplir l'hôtel à 75 %",
		"evenement_nom": "Séminaires",
		"paye_accueil": true,
		"gains": {"restaurant": 21.0, "bar": 9.0, "spa": 45.0, "boutique": 12.0, "conference": 30.0},
		"plan": Vector2(44, 26),
		"porte": Vector2(16, 26),
		"hall": Vector2(16.2, 21.6),
		"file": Vector2(14.0, 20.6),
		"murs": "efe3cc",
		"murs_dehors": "c9876a",
		"pieces": {
			"reception": {"nom": "Hall et réception", "court": "Réception", "rect": [12, 17, 8, 9], "max": 5, "base": 1, "prix": 0.004,
				"decor": "reception", "sol": "e8dcc4", "motif": "damier",
				"effets": {"attrait": 0.05, "confort": 0.04, "vitesse": 0.2, "entretien": 60.0},
				"metiers": ["receptionniste"], "postes": [[13.2, 18.6, 0.0], [14.8, 18.6, 0.0]],
				"desc": "Le comptoir, les clés et le sourire. Plus grand et plus beau, il accueille plus de monde sans file d'attente."},
			"boutique": {"nom": "Boutique", "court": "Boutique", "rect": [20, 17, 4, 9], "max": 5, "base": 0, "prix": 0.002,
				"decor": "boutique", "sol": "f2e2c9", "motif": "parquet",
				"effets": {"ventes": 1.2, "attrait": 0.01, "entretien": 30.0},
				"porte": [20, 23],
				"metiers": ["vendeur", "caissier"], "postes": [[22.0, 24.6, PI]],
				"desc": "Cartes postales, brosses à dents oubliées et peluches à l'effigie de l'hôtel. Les clients y laissent toujours quelque chose."},
			"chambres": {"nom": "Chambres", "court": "Chambres", "rect": [0, 0, 12, 26], "max": 5, "base": 1, "prix": 0.010,
				"decor": "chambres", "sol": "c9a27e", "motif": "moquette",
				"effets": {"lits": 0.1, "confort": 0.08, "entretien": 220.0},
				"porte": [12, 21.5],
				"metiers": ["agent_etage"], "postes": [[11.0, 6.0, 0.0], [11.0, 15.0, PI]],
				"desc": "Le cœur de l'hôtel. Chaque niveau ouvre des chambres en plus et les rend plus confortables. Équipe-les une par une : télé, minibar, baignoire…"},
			"menage": {"nom": "Lingerie et ménage", "court": "Lingerie", "rect": [12, 0, 6, 8], "max": 5, "base": 1, "prix": 0.003,
				"decor": "lingerie", "sol": "c5d3da", "motif": "carrelage",
				"effets": {"satisf": 0.05, "vitesse": 0.05, "entretien": 50.0},
				"porte": [15, 8], "via": "bar",
				"metiers": ["agent_proprete"], "postes": [[15.0, 3.2, PI]],
				"desc": "Draps propres, serviettes pliées en cygne. Les clients le remarquent tout de suite (surtout quand ça manque)."},
			"direction": {"nom": "Bureau de la direction", "court": "Direction", "rect": [18, 0, 6, 8], "max": 5, "base": 1, "prix": 0.003,
				"decor": "bureau", "sol": "9fb1c4", "motif": "moquette",
				"effets": {"attrait": 0.03, "satisf": 0.02, "entretien": 40.0},
				"porte": [21, 8], "via": "bar",
				"metiers": ["cadre"], "postes": [[21.0, 2.8, PI]],
				"desc": "Réservations, publicité en ligne et tableau des plannings. Un bon directeur remplit l'hôtel et évite les pannes."},
			"bar": {"nom": "Bar et salon", "court": "Bar", "rect": [12, 8, 12, 9], "max": 5, "base": 0, "prix": 0.004,
				"decor": "bar", "sol": "a8735a", "motif": "parquet",
				"effets": {"confort": 0.1, "attrait": 0.02, "ventes": 1.5, "entretien": 90.0},
				"porte": [16, 17],
				"metiers": ["serveur"], "postes": [[12.9, 11.0, PI * 0.5]],
				"desc": "Fauteuils club, cocktails et piano. Les clients y passent la soirée (et y laissent un peu d'argent)."},
			"restaurant": {"nom": "Restaurant", "court": "Restaurant", "rect": [24, 14, 12, 12], "max": 5, "base": 0, "prix": 0.006, "flag": "restaurant",
				"decor": "restaurant", "sol": "e6d2b5", "motif": "parquet",
				"effets": {"repas": 0.07, "confort": 0.08, "entretien": 160.0},
				"porte": [24, 15.5], "via": "bar",
				"metiers": ["cuisinier", "serveur"], "postes": [[33.0, 15.2, PI], [35.0, 15.2, PI], [30.2, 17.6, 0.0]],
				"desc": "Petit-déjeuner, déjeuner, dîner : les clients mangent sur place au lieu d'aller en ville, et l'hôtel encaisse."},
			"spa": {"nom": "Spa et bien-être", "court": "Spa", "rect": [24, 0, 12, 14], "max": 5, "base": 0, "prix": 0.007, "flag": "spa",
				"decor": "spa", "sol": "d6ebe7", "motif": "carrelage",
				"effets": {"confort": 0.14, "attrait": 0.03, "ventes": 2.0, "entretien": 180.0},
				"porte": [30, 14], "via": "restaurant",
				"metiers": ["maitre_nageur"], "postes": [[26.9, 2.4, -PI * 0.5]],
				"desc": "Hammam, sauna, massages et tisanes. Les clients repartent détendus et laissent de meilleures notes."},
			"sport": {"nom": "Salle de sport", "court": "Sport", "rect": [36, 14, 8, 12], "max": 5, "base": 0, "prix": 0.003,
				"decor": "sport", "sol": "5d6d7e", "motif": "dalles",
				"effets": {"confort": 0.06, "attrait": 0.03, "entretien": 50.0},
				"porte": [36, 20], "via": "restaurant",
				"metiers": ["coach"], "postes": [[40.0, 19.0, PI]],
				"desc": "Tapis de course, vélos et haltères. Les clients d'affaires ne réservent plus sans."},
			"conference": {"nom": "Salle de conférences", "court": "Conférences", "rect": [36, 0, 8, 14], "max": 5, "base": 0, "prix": 0.004,
				"decor": "conference", "sol": "b8a99a", "motif": "moquette",
				"effets": {"attrait": 0.04, "ventes": 1.0, "entretien": 70.0},
				"porte": [40, 14], "via": "sport",
				"metiers": [], "postes": [],
				"desc": "Séminaires, congrès et mariages : des groupes entiers réservent l'hôtel, et la salle se loue cher."},
		},
		"dehors": {
			"piscine": {"nom": "Piscine", "court": "Piscine", "rect": [46, 10, 12, 16], "max": 5, "base": 0, "prix": 0.008, "flag": "piscine",
				"decor": "piscine", "sol": "efe6d2", "motif": "dalles",
				"effets": {"confort": 0.14, "attrait": 0.05, "entretien": 200.0},
				"porte": [44, 22], "via": "sport", "chemin": [[45.0, 22.0]],
				"metiers": ["maitre_nageur"], "postes": [[47.4, 23.5, PI * 0.5]],
				"desc": "Bassin, transats et parasols. En été, c'est la première chose que les clients regardent sur les photos."},
			"jardin": {"nom": "Jardin et club enfants", "court": "Jardin", "rect": [46, 0, 12, 9], "max": 5, "base": 0, "prix": 0.003,
				"decor": "jardin", "sol": "7fbf62", "motif": "gazon", "via": "piscine", "chemin": [[45.0, 9.5]],
				"effets": {"confort": 0.05, "attrait": 0.04, "satisf": 0.02, "entretien": 40.0},
				"metiers": ["animateur_vacances"], "postes": [[50.0, 4.4, 0.0]],
				"desc": "Balançoires, toboggan et un animateur : les familles choisissent l'hôtel où les enfants s'amusent."},
			"parking": {"nom": "Parking et voiturier", "court": "Parking", "rect": [0, 29, 40, 8], "max": 5, "base": 0, "prix": 0.003,
				"decor": "parking", "sol": "6b6f75", "motif": "",
				"effets": {"attrait": 0.05, "entretien": 30.0},
				"metiers": [], "postes": [],
				"desc": "Des places devant la porte, puis un voiturier. Les clients venus en voiture choisissent l'hôtel où l'on se gare."},
		},
		"ordre": ["reception", "chambres", "menage", "direction", "bar", "restaurant", "spa", "boutique", "sport", "conference", "piscine", "jardin", "parking"],
		"objets": {
			"reception": {
				"plantes_hall": {"nom": "Plantes vertes", "modele": "plante_grande", "poses": [[0.5, 8.5, 0.0], [5.2, 8.5, 0.0], [7.5, 0.5, 0.0]], "prix": 0.0006, "niv": 1, "effets": {"confort": 0.02}},
				"canapes_hall": {"nom": "Canapés d'attente", "modele": "canape", "poses": [[7.3, 2.6, -PI * 0.5], [7.3, 8.1, -PI * 0.5]], "prix": 0.0012, "niv": 1, "effets": {"confort": 0.03, "vitesse": 0.05}},
				"tapis_rouge": {"nom": "Tapis rouge", "modele": "tapis_rouge", "poses": [[4.0, 6.4, 0.0]], "prix": 0.0008, "niv": 1, "effets": {"attrait": 0.02}},
				"presentoir": {"nom": "Présentoir de brochures", "modele": "presentoir", "poses": [[7.5, 4.6, -PI * 0.5]], "prix": 0.0005, "niv": 1, "effets": {"attrait": 0.01, "satisf": 0.01}},
				"chariot_bagages": {"nom": "Chariot à bagages doré", "modele": "chariot_bagages", "poses": [[0.8, 7.6, 0.0]], "prix": 0.0008, "niv": 2, "effets": {"satisf": 0.02}},
				"borne": {"nom": "Borne d'enregistrement", "modele": "borne", "poses": [[5.4, 0.6, 0.0]], "prix": 0.0015, "niv": 2, "effets": {"vitesse": 0.3}},
				"horloges": {"nom": "Horloges du monde", "modele": "horloges", "poses": [[6.6, 0.12, 0.0]], "prix": 0.0004, "niv": 2, "effets": {"attrait": 0.01}},
				"fontaine": {"nom": "Fontaine en marbre", "modele": "fontaine", "poses": [[5.4, 3.4, 0.0]], "prix": 0.0025, "niv": 3, "effets": {"confort": 0.04, "attrait": 0.03}},
				"lustre": {"nom": "Lustre en cristal", "modele": "lustre", "poses": [[4.0, 5.0, 0.0]], "prix": 0.003, "niv": 4, "effets": {"confort": 0.05, "attrait": 0.02}},
			},
			"chambres": {
				"tele": {"nom": "Télévision", "modele": "tele_meuble", "poses": [[3.6, 0.3, 0.0]], "prix": 0.0015, "niv": 1, "cellules": true, "effets": {"confort": 0.04}},
				"clim": {"nom": "Climatisation", "modele": "clim", "poses": [[5.6, 0.16, 0.0]], "prix": 0.0012, "niv": 1, "cellules": true, "effets": {"satisf": 0.03}},
				"minibar": {"nom": "Minibar", "modele": "minibar", "poses": [[2.5, 0.35, 0.0]], "prix": 0.0010, "niv": 1, "cellules": true, "effets": {"confort": 0.01, "ventes": 2.0}},
				"tableaux": {"nom": "Tableaux", "modele": "tableau", "poses": [[1.2, 0.12, 0.0]], "prix": 0.0005, "niv": 1, "cellules": true, "effets": {"confort": 0.02}},
				"machine_cafe": {"nom": "Machine à café", "modele": "machine_cafe", "poses": [[4.7, 0.35, 0.0]], "prix": 0.0006, "niv": 2, "cellules": true, "effets": {"confort": 0.02}},
				"coffre": {"nom": "Coffre-fort", "modele": "coffre", "poses": [[6.2, 3.95, PI]], "prix": 0.0006, "niv": 2, "cellules": true, "effets": {"satisf": 0.02}},
				"plante_chambre": {"nom": "Plante et fauteuil de lecture", "modele": "plante", "poses": [[4.7, 3.85, 0.0]], "prix": 0.0004, "niv": 2, "cellules": true, "effets": {"confort": 0.01}},
				"baignoire": {"nom": "Baignoire balnéo", "modele": "baignoire", "poses": [[8.5, 0.9, 0.0]], "prix": 0.0025, "niv": 3, "cellules": true, "effets": {"confort": 0.05}},
				"literie": {"nom": "Literie de luxe", "modele": "", "poses": [], "prix": 0.002, "niv": 3, "cellules": true, "effets": {"confort": 0.04, "satisf": 0.02}},
			},
			"menage": {
				"seche_linge": {"nom": "Sèche-linge industriel", "modele": "seche_linge", "poses": [[4.9, 0.6, 0.0]], "prix": 0.0008, "niv": 1, "effets": {"satisf": 0.02}},
				"repassage": {"nom": "Table à repasser vapeur", "modele": "repassage", "poses": [[2.4, 4.6, 0.0]], "prix": 0.0004, "niv": 1, "effets": {"satisf": 0.01}},
				"chariots": {"nom": "Chariots de ménage", "modele": "chariot_menage", "poses": [[1.0, 6.8, 0.0], [2.4, 6.8, 0.0]], "prix": 0.0006, "niv": 2, "effets": {"vitesse": 0.05, "satisf": 0.01}},
				"produits": {"nom": "Réserve de produits", "modele": "etagere_produits", "poses": [[5.5, 4.4, -PI * 0.5]], "prix": 0.0004, "niv": 2, "effets": {"satisf": 0.01}},
				"tunnel": {"nom": "Tunnel de lavage", "modele": "lave_linge_xxl", "poses": [[2.6, 0.7, 0.0]], "prix": 0.0018, "niv": 3, "effets": {"satisf": 0.03, "vitesse": 0.05}},
			},
			"direction": {
				"ordinateur": {"nom": "Logiciel de réservation", "modele": "ordinateur", "poses": [[3.0, 2.0, 0.0]], "prix": 0.0010, "niv": 1, "effets": {"attrait": 0.03}},
				"planning": {"nom": "Tableau des plannings", "modele": "tableau_blanc", "poses": [[3.0, 0.12, 0.0]], "prix": 0.0003, "niv": 1, "effets": {"satisf": 0.01}},
				"cafe_bureau": {"nom": "Machine à café du bureau", "modele": "machine_cafe", "poses": [[5.4, 0.5, 0.0]], "prix": 0.0003, "niv": 1, "effets": {"satisf": 0.01}},
				"avis_en_ligne": {"nom": "Gestion des avis en ligne", "modele": "ordinateur", "poses": [[1.2, 5.4, PI * 0.5]], "prix": 0.0015, "niv": 2, "effets": {"attrait": 0.04}},
				"coffre_bureau": {"nom": "Coffre de l'hôtel", "modele": "coffre", "poses": [[5.4, 6.8, -PI * 0.5]], "prix": 0.0006, "niv": 2, "effets": {"satisf": 0.01}},
			},
			"bar": {
				"juke_box": {"nom": "Juke-box", "modele": "juke_box", "poses": [[6.0, 0.4, 0.0]], "prix": 0.0008, "niv": 1, "effets": {"confort": 0.02}},
				"flechettes": {"nom": "Jeu de fléchettes", "modele": "flechettes", "poses": [[11.86, 3.0, -PI * 0.5]], "prix": 0.0003, "niv": 1, "effets": {"attrait": 0.01}},
				"piano": {"nom": "Piano à queue", "modele": "piano", "poses": [[10.2, 1.6, 0.0]], "prix": 0.0025, "niv": 1, "effets": {"confort": 0.04}},
				"cave_bar": {"nom": "Cave à vins", "modele": "cave_vins", "poses": [[7.6, 0.4, 0.0]], "prix": 0.0012, "niv": 2, "effets": {"ventes": 1.5}},
				"billard": {"nom": "Billard", "modele": "billard", "poses": [[9.4, 5.6, 0.0]], "prix": 0.0015, "niv": 2, "effets": {"confort": 0.03, "ventes": 0.5}},
				"cheminee": {"nom": "Cheminée", "modele": "cheminee", "poses": [[0.25, 7.2, PI * 0.5]], "prix": 0.002, "niv": 3, "effets": {"confort": 0.05}},
			},
			"restaurant": {
				"plantes_resto": {"nom": "Plantes et paravents", "modele": "plante_grande", "poses": [[0.6, 11.4, 0.0], [8.8, 11.4, 0.0], [0.6, 4.2, 0.0]], "prix": 0.0005, "niv": 1, "effets": {"confort": 0.01}},
				"buffet": {"nom": "Buffet du petit-déjeuner", "modele": "buffet", "poses": [[2.6, 0.5, 0.0]], "prix": 0.0015, "niv": 1, "effets": {"repas": 0.04, "confort": 0.02}},
				"chariot_desserts": {"nom": "Chariot des desserts", "modele": "chariot_desserts", "poses": [[10.6, 6.6, -PI * 0.5]], "prix": 0.0006, "niv": 2, "effets": {"ventes": 1.0}},
				"four_pizza": {"nom": "Four à pizza", "modele": "four_pizza", "poses": [[10.9, 10.2, -PI * 0.5]], "prix": 0.0012, "niv": 2, "effets": {"repas": 0.03, "ventes": 0.8}},
				"cave_resto": {"nom": "Cave à vins vitrée", "modele": "cave_vins", "poses": [[0.4, 8.0, PI * 0.5]], "prix": 0.0015, "niv": 2, "effets": {"ventes": 1.5}},
				"aquarium": {"nom": "Aquarium", "modele": "aquarium", "poses": [[4.6, 11.5, PI]], "prix": 0.002, "niv": 3, "effets": {"confort": 0.04, "attrait": 0.01}},
				"lustres_resto": {"nom": "Lustres", "modele": "lustre", "poses": [[3.8, 4.5, 0.0], [3.8, 8.5, 0.0]], "prix": 0.002, "niv": 4, "effets": {"confort": 0.04}},
			},
			"spa": {
				"bougies": {"nom": "Bougies et plantes", "modele": "plante", "poses": [[0.6, 5.6, 0.0], [0.6, 9.4, 0.0], [11.4, 13.4, 0.0]], "prix": 0.0003, "niv": 1, "effets": {"confort": 0.01}},
				"sauna": {"nom": "Sauna finlandais", "modele": "sauna", "poses": [[10.2, 2.0, 0.0]], "prix": 0.002, "niv": 1, "effets": {"confort": 0.04, "ventes": 1.0}},
				"tisanerie": {"nom": "Tisanerie", "modele": "tisanerie", "poses": [[8.6, 13.4, PI]], "prix": 0.0005, "niv": 1, "effets": {"satisf": 0.02}},
				"jacuzzi": {"nom": "Jacuzzi", "modele": "jacuzzi", "poses": [[3.2, 9.6, 0.0]], "prix": 0.0025, "niv": 2, "effets": {"confort": 0.05}},
				"hammam": {"nom": "Hammam", "modele": "hammam", "poses": [[10.0, 7.0, 0.0]], "prix": 0.002, "niv": 2, "effets": {"confort": 0.04}},
				"douche_sens": {"nom": "Douche sensorielle", "modele": "douche", "poses": [[11.2, 11.4, 0.0]], "prix": 0.0012, "niv": 3, "effets": {"confort": 0.03}},
			},
			"boutique": {
				"souvenirs": {"nom": "Présentoir de souvenirs", "modele": "presentoir_souvenirs", "poses": [[2.0, 3.2, 0.0]], "prix": 0.0006, "niv": 1, "effets": {"ventes": 1.5}},
				"journaux": {"nom": "Journaux et magazines", "modele": "journaux", "poses": [[3.5, 6.0, -PI * 0.5]], "prix": 0.0003, "niv": 1, "effets": {"ventes": 0.4, "satisf": 0.01}},
				"peluches": {"nom": "Peluches de l'hôtel", "modele": "peluches", "poses": [[3.4, 1.0, -PI * 0.5]], "prix": 0.0005, "niv": 2, "effets": {"ventes": 1.0}},
				"cosmetiques": {"nom": "Cosmétiques", "modele": "etagere_produits", "poses": [[0.5, 1.4, PI * 0.5]], "prix": 0.0006, "niv": 2, "effets": {"ventes": 1.0}},
			},
			"sport": {
				"tapis_course": {"nom": "Tapis de course", "modele": "tapis_course", "poses": [[1.4, 1.2, 0.0], [3.2, 1.2, 0.0]], "prix": 0.0012, "niv": 1, "effets": {"confort": 0.03, "attrait": 0.02}},
				"velos": {"nom": "Vélos d'appartement", "modele": "velo", "poses": [[5.2, 1.2, 0.0], [6.8, 1.2, 0.0]], "prix": 0.0008, "niv": 1, "effets": {"confort": 0.02}},
				"miroir": {"nom": "Grand miroir", "modele": "miroir", "poses": [[7.88, 3.6, -PI * 0.5]], "prix": 0.0002, "niv": 1, "effets": {"satisf": 0.01}},
				"distributeur": {"nom": "Distributeur de boissons", "modele": "distributeur", "poses": [[7.4, 11.0, -PI * 0.5]], "prix": 0.0004, "niv": 1, "effets": {"ventes": 0.6}},
				"banc_muscu": {"nom": "Banc de musculation", "modele": "banc_muscu", "poses": [[2.0, 5.2, 0.0]], "prix": 0.0008, "niv": 2, "effets": {"confort": 0.02}},
				"sac_frappe": {"nom": "Sac de frappe", "modele": "sac_frappe", "poses": [[6.4, 5.0, 0.0]], "prix": 0.0004, "niv": 2, "effets": {"confort": 0.01}},
				"vestiaires": {"nom": "Vestiaires", "modele": "vestiaire", "poses": [[0.4, 10.0, PI * 0.5]], "prix": 0.0008, "niv": 2, "effets": {"satisf": 0.02}},
			},
			"conference": {
				"ecran": {"nom": "Écran et projecteur", "modele": "ecran", "poses": [[4.0, 0.15, 0.0]], "prix": 0.001, "niv": 1, "effets": {"attrait": 0.02, "ventes": 0.8}},
				"pupitre": {"nom": "Pupitre", "modele": "pupitre", "poses": [[1.6, 1.6, 0.0]], "prix": 0.0003, "niv": 1, "effets": {"attrait": 0.01}},
				"sono": {"nom": "Sonorisation", "modele": "enceinte", "poses": [[0.5, 1.0, 0.0], [7.5, 1.0, 0.0]], "prix": 0.0006, "niv": 2, "effets": {"attrait": 0.02}},
				"buffet_pause": {"nom": "Buffet des pauses", "modele": "buffet", "poses": [[6.4, 13.3, PI]], "prix": 0.0008, "niv": 2, "effets": {"ventes": 1.0}},
				"traduction": {"nom": "Cabines de traduction", "modele": "cabine", "poses": [[7.3, 9.0, -PI * 0.5]], "prix": 0.0015, "niv": 3, "effets": {"attrait": 0.03}},
			},
			"piscine": {
				"parasols": {"nom": "Parasols", "modele": "parasol", "poses": [[2.6, 2.4, 0.0], [2.6, 6.4, 0.0], [2.6, 10.4, 0.0]], "prix": 0.0004, "niv": 1, "effets": {"confort": 0.02}},
				"plongeoir": {"nom": "Plongeoir", "modele": "plongeoir", "poses": [[7.6, 0.9, 0.0]], "prix": 0.0006, "niv": 1, "effets": {"confort": 0.02}},
				"douche_piscine": {"nom": "Douche", "modele": "douche", "poses": [[0.6, 15.2, 0.0]], "prix": 0.0002, "niv": 1, "effets": {"satisf": 0.01}},
				"palmiers": {"nom": "Palmiers", "modele": "palmier", "poses": [[11.3, 0.7, 0.0], [11.3, 15.3, 0.0], [0.7, 0.7, 0.0]], "prix": 0.0006, "niv": 1, "effets": {"attrait": 0.02}},
				"bouees": {"nom": "Bouées et ballons", "modele": "bouees", "poses": [[7.6, 8.0, 0.0]], "prix": 0.0002, "niv": 1, "effets": {"confort": 0.01}},
				"bar_piscine": {"nom": "Bar de la piscine", "modele": "bar_piscine", "poses": [[10.6, 14.8, PI]], "prix": 0.0015, "niv": 2, "effets": {"ventes": 1.5, "confort": 0.02}},
				"toboggan": {"nom": "Toboggan aquatique", "modele": "toboggan", "poses": [[10.6, 3.0, 0.0]], "prix": 0.003, "niv": 3, "effets": {"confort": 0.05, "attrait": 0.03}},
			},
			"jardin": {
				"balancoire": {"nom": "Balançoire", "modele": "balancoire", "poses": [[2.0, 2.2, 0.0]], "prix": 0.0004, "niv": 1, "effets": {"confort": 0.02}},
				"toboggan_enfants": {"nom": "Toboggan", "modele": "toboggan_enfants", "poses": [[5.6, 2.2, 0.0]], "prix": 0.0004, "niv": 1, "effets": {"confort": 0.02}},
				"bac_sable": {"nom": "Bac à sable", "modele": "bac_sable", "poses": [[9.2, 2.4, 0.0]], "prix": 0.0002, "niv": 1, "effets": {"satisf": 0.01}},
				"bancs": {"nom": "Bancs", "modele": "banc", "poses": [[1.6, 7.9, 0.0], [10.4, 7.9, 0.0]], "prix": 0.0002, "niv": 1, "effets": {"confort": 0.01}},
				"massifs": {"nom": "Massifs de fleurs", "modele": "massif", "poses": [[11.0, 5.0, 0.0], [0.9, 5.0, 0.0]], "prix": 0.0003, "niv": 1, "effets": {"attrait": 0.01}},
				"kiosque": {"nom": "Kiosque", "modele": "kiosque", "poses": [[6.0, 6.2, 0.0]], "prix": 0.0015, "niv": 2, "effets": {"confort": 0.03}},
				"fontaine_jardin": {"nom": "Fontaine", "modele": "fontaine", "poses": [[3.4, 6.0, 0.0]], "prix": 0.0012, "niv": 3, "effets": {"attrait": 0.03}},
			},
			"parking": {
				"lampadaires": {"nom": "Lampadaires", "modele": "lampadaire", "poses": [[6.0, 0.3, 0.0], [26.0, 0.3, 0.0], [36.0, 0.3, 0.0]], "prix": 0.0003, "niv": 1, "effets": {"satisf": 0.01}},
				"auvent": {"nom": "Auvent d'entrée", "modele": "auvent", "poses": [[16.0, -2.0, 0.0]], "prix": 0.0008, "niv": 1, "effets": {"attrait": 0.02}},
				"bornes_recharge": {"nom": "Bornes de recharge", "modele": "borne_recharge", "poses": [[1.0, 1.6, 0.0], [3.5, 1.6, 0.0]], "prix": 0.0008, "niv": 1, "effets": {"attrait": 0.02}},
				"guerite": {"nom": "Guérite du voiturier", "modele": "guerite", "poses": [[19.2, 1.2, 0.0]], "prix": 0.0008, "niv": 2, "effets": {"attrait": 0.03, "satisf": 0.01}},
				"navette": {"nom": "Navette de l'hôtel", "modele": "navette", "poses": [[33.0, 5.6, 0.0]], "prix": 0.003, "niv": 3, "effets": {"attrait": 0.04}},
			},
		},
		"activites": [["chambres", 0.4], ["restaurant", 0.16], ["bar", 0.1], ["spa", 0.07], ["piscine", 0.08], ["boutique", 0.05],
			["sport", 0.05], ["jardin", 0.04], ["conference", 0.05], ["reception", 0.03]],
		"demandes": [
			{"id": "serviettes", "piece": "chambres", "texte": "Des serviettes propres, s'il vous plaît !", "pourboire": 8},
			{"id": "reveil", "piece": "chambres", "texte": "Réveil à 6 h demain, j'ai un train.", "pourboire": 5},
			{"id": "bruit", "piece": "chambres", "texte": "Les voisins chantent du karaoké…", "pourboire": 4},
			{"id": "oreiller", "piece": "chambres", "texte": "Un oreiller plus ferme, possible ?", "pourboire": 6},
			{"id": "valises", "piece": "reception", "texte": "Quelqu'un peut monter nos valises ?", "pourboire": 15},
			{"id": "wifi", "piece": "reception", "texte": "Le code du wifi ne marche pas.", "pourboire": 3},
			{"id": "taxi", "piece": "reception", "texte": "Vous pouvez m'appeler un taxi ?", "pourboire": 7},
			{"id": "plat", "piece": "restaurant", "texte": "Mon plat est froid !", "pourboire": 6},
			{"id": "vin", "piece": "restaurant", "texte": "La carte des vins, je vous prie.", "pourboire": 12},
			{"id": "allergie", "piece": "restaurant", "texte": "Il y a des noix dans ce gâteau ?", "pourboire": 5},
			{"id": "cocktail", "piece": "bar", "texte": "Un cocktail maison, avec une ombrelle.", "pourboire": 10},
			{"id": "piano", "piece": "bar", "texte": "Le pianiste connaît « La Vie en rose » ?", "pourboire": 9},
			{"id": "massage", "piece": "spa", "texte": "Il reste un créneau de massage ?", "pourboire": 20},
			{"id": "peignoir", "piece": "spa", "texte": "Un peignoir à ma taille, svp…", "pourboire": 6},
			{"id": "transat", "piece": "piscine", "texte": "Plus un seul transat de libre !", "pourboire": 6},
			{"id": "glace", "piece": "piscine", "texte": "On peut avoir des glaces au bord du bassin ?", "pourboire": 8},
			{"id": "cartes", "piece": "boutique", "texte": "Vous avez des cartes postales avec timbre ?", "pourboire": 4},
			{"id": "halteres", "piece": "sport", "texte": "Où sont les haltères de 10 kg ?", "pourboire": 4},
			{"id": "toboggan", "piece": "jardin", "texte": "Mon fils est coincé en haut du toboggan !", "pourboire": 10},
			{"id": "projecteur", "piece": "conference", "texte": "Le projecteur ne s'allume pas !", "pourboire": 25},
		],
		"pannes": {
			"chambres": ["Douche bouchée", "Climatisation en panne", "Télé qui ne s'allume plus"],
			"reception": ["Imprimante des factures bloquée", "Porte automatique coincée"],
			"menage": ["Lave-linge en panne"],
			"direction": ["Ordinateur des réservations planté"],
			"bar": ["Machine à glaçons en panne", "Pompe à bière qui fuit"],
			"restaurant": ["Four en panne", "Lave-vaisselle bloqué"],
			"spa": ["Sauna froid", "Jacuzzi sans bulles"],
			"sport": ["Tapis de course bloqué"],
			"conference": ["Micro qui grésille"],
			"piscine": ["Filtre de la piscine encrassé", "Eau trouble"],
			"boutique": ["Caisse enregistreuse bloquée"],
			"jardin": ["Balançoire cassée"],
			"parking": ["Barrière du parking bloquée"],
		},
		"pensees": {
			"regle": ["Service impeccable, merci !", "Rapide et souriant, bravo.", "Voilà ce que j'appelle un hôtel.", "Je reviendrai, c'est sûr."],
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
	if Ressources.commerce_of(type_id).has("consomme"):
		return "restaurant"
	# Services d'urgence (versions d'époque et modèles de l'Atelier compris).
	var t := type_id if Urgences.BUILDING_SERVICE.has(type_id) else BuildingCatalog.base_of(type_id)
	match t:
		"pompiers":
			return "caserne"
		"police":
			return "commissariat"
		"hopital":
			return "hopital"
	return ""


## Genres décrits dans leur propre fichier (scripts/gestion/genres).
static func genre(g: String) -> Dictionary:
	match g:
		"restaurant":
			return GenreRestaurant.GENRE
		"caserne":
			return GenreCaserne.GENRE
		"commissariat":
			return GenreCommissariat.GENRE
		"hopital":
			return GenreHopital.GENRE
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


## Objets qu'on peut acheter dans une pièce : id → définition.
static func objets(g: String, pid: String) -> Dictionary:
	return (genre(g).get("objets", {}) as Dictionary).get(pid, {})


static func objet(g: String, pid: String, oid: String) -> Dictionary:
	return objets(g, pid).get(oid, {})


## Pièce qui accueille un métier du jeu (première trouvée), "" sinon.
static func piece_du_metier(g: String, met: String) -> String:
	for pid in ordre(g):
		if met in (piece(g, String(pid)).get("metiers", []) as Array):
			return String(pid)
	return ""
