class_name Meubles
extends RefCounted
## « Bible » des meubles et des objets : anciens et modernes, du monde entier.
##
## Comme pour les bâtiments (Styles), le catalogue est généré : chaque STYLE de
## mobilier (une région du monde et une époque, une palette de bois, de tissus
## et de métal) décline les TYPES de meubles qui existent à son époque, avec ses
## noms et ses pièces à lui (futon et kotatsu au Japon, lit clos en Bretagne,
## sedari au Maroc, charpai en Inde, hamac au Mexique…).
##
## Un meuble occupe des cases de 1 m (w le long de x, d le long de z, avant
## tourné vers +Z), sur une couche : "sol" (tapis, sous les meubles), "meuble"
## ou "mur" (accroché au mur, au-dessus des meubles). Il a un prix, un confort
## et une attractivité, des étiquettes (lit, cuisson, eau…) qui disent à quoi il
## sert, et des « places » où les habitants dorment, s'assoient ou travaillent.

const ERA_ORDER := ["antique", "traditionnel", "classique", "moderne", "contemporain", "futuriste"]

## Fonctions des pièces (la fonction choisit le mobilier généré).
const PIECES := {
	"sejour": {"name": "Séjour", "desc": "Salon et salle à manger"},
	"cuisine": {"name": "Cuisine", "desc": "Cuisson, évier, table"},
	"chambre": {"name": "Chambre", "desc": "Lit double, rangements"},
	"enfant": {"name": "Chambre d'enfant", "desc": "Lits simples, bureau, jouets"},
	"sdb": {"name": "Salle de bains", "desc": "Toilettes, lavabo, bain ou douche"},
	"entree": {"name": "Entrée, couloir", "desc": "Porte-manteau, banc"},
	"bureau": {"name": "Bureau", "desc": "Postes de travail"},
	"classe": {"name": "Salle de classe", "desc": "Tableau, pupitres, bureau du maître"},
	"boutique": {"name": "Boutique", "desc": "Comptoir, rayonnages, présentoirs"},
	"salle": {"name": "Salle de café-restaurant", "desc": "Tables, bar, banquettes"},
	"reserve": {"name": "Réserve", "desc": "Étagères et caisses"},
}
const PIECE_ORDER := ["sejour", "cuisine", "chambre", "enfant", "sdb", "entree", "bureau", "classe", "boutique", "salle", "reserve"]

## Onglets du catalogue : les pièces, plus la décoration.
const CATEGORIES := ["sejour", "cuisine", "chambre", "enfant", "sdb", "entree", "bureau", "classe", "boutique", "salle", "reserve", "deco"]
const CATEGORY_NAMES := {"deco": "Décoration, plantes, lumières"}

## Types de meubles. k : modèle (MeublesModeles), w × d : cases, h : hauteur (m),
## prix (€), conf : confort, attr : attractivité, p : pièces (la première est
## son onglet), mur : se pose dos au mur, couche : "sol" / "meuble" / "mur",
## e : époques [première, dernière] (indices de ERA_ORDER), tags : à quoi il sert,
## places : [genre, x, y, z, cap] (repère du meuble ; cap 0 = regarde vers +Z).
const TYPES := {
	# --- Chambres -------------------------------------------------------------
	"lit_double": {"n": "Lit double", "k": "lit", "w": 2, "d": 2, "h": 0.9, "prix": 900, "conf": 12, "attr": 2, "p": ["chambre"], "mur": true,
		"tags": ["lit"], "places": [["lit", -0.45, 0.55, 0.15, 0.0], ["lit", 0.45, 0.55, 0.15, 0.0]]},
	"lit_simple": {"n": "Lit simple", "k": "lit", "w": 1, "d": 2, "h": 0.8, "prix": 400, "conf": 7, "attr": 1, "p": ["enfant", "chambre"], "mur": true,
		"tags": ["lit"], "places": [["lit", 0.0, 0.5, 0.15, 0.0]]},
	"lit_superpose": {"n": "Lits superposés", "k": "lit_superpose", "w": 1, "d": 2, "h": 1.7, "prix": 550, "conf": 9, "attr": 2, "p": ["enfant"], "mur": true, "e": [2, 5],
		"tags": ["lit"], "places": [["lit", 0.0, 0.45, 0.15, 0.0], ["lit", 0.0, 1.55, 0.15, 0.0]]},
	"berceau": {"n": "Berceau", "k": "berceau", "w": 1, "d": 1, "h": 0.9, "prix": 250, "conf": 4, "attr": 2, "p": ["enfant", "chambre"],
		"tags": ["lit"], "places": [["bebe", 0.0, 0.55, 0.0, 0.0]]},
	"chevet": {"n": "Table de chevet", "k": "chevet", "w": 1, "d": 1, "h": 0.55, "prix": 120, "conf": 2, "attr": 1, "p": ["chambre", "enfant"], "mur": true},
	"armoire": {"n": "Armoire", "k": "armoire", "w": 2, "d": 1, "h": 2.1, "prix": 700, "conf": 4, "attr": 2, "p": ["chambre", "enfant", "entree"], "mur": true, "tags": ["rangement"]},
	"commode": {"n": "Commode", "k": "commode", "w": 1, "d": 1, "h": 0.9, "prix": 350, "conf": 3, "attr": 2, "p": ["chambre", "sejour", "enfant"], "mur": true, "tags": ["rangement"]},
	"coiffeuse": {"n": "Coiffeuse", "k": "coiffeuse", "w": 1, "d": 1, "h": 1.5, "prix": 300, "conf": 2, "attr": 3, "p": ["chambre"], "mur": true},
	"coffre": {"n": "Coffre", "k": "coffre", "w": 1, "d": 1, "h": 0.55, "prix": 200, "conf": 1, "attr": 2, "p": ["chambre", "entree", "sejour"], "tags": ["rangement"]},
	"coffre_jouets": {"n": "Coffre à jouets", "k": "jouets", "w": 1, "d": 1, "h": 0.5, "prix": 90, "conf": 3, "attr": 2, "p": ["enfant"]},
	# --- Séjour ---------------------------------------------------------------
	"canape": {"n": "Canapé", "k": "canape", "w": 2, "d": 1, "h": 0.85, "prix": 800, "conf": 10, "attr": 3, "p": ["sejour"], "mur": true,
		"tags": ["assise"], "places": [["assis", -0.45, 0.45, 0.05, 0.0], ["assis", 0.45, 0.45, 0.05, 0.0]]},
	"fauteuil": {"n": "Fauteuil", "k": "fauteuil", "w": 1, "d": 1, "h": 0.9, "prix": 380, "conf": 6, "attr": 2, "p": ["sejour", "chambre", "bureau"],
		"tags": ["assise"], "places": [["assis", 0.0, 0.45, 0.05, 0.0]]},
	"table_basse": {"n": "Table basse", "k": "table_basse", "w": 1, "d": 1, "h": 0.45, "prix": 180, "conf": 2, "attr": 2, "p": ["sejour"]},
	"table_repas": {"n": "Table et quatre chaises", "k": "table_repas", "w": 2, "d": 2, "h": 0.95, "prix": 750, "conf": 7, "attr": 3, "p": ["sejour", "cuisine", "salle"],
		"tags": ["table", "assise"], "places": [["assis", -0.45, 0.45, -0.75, 0.0], ["assis", 0.45, 0.45, -0.75, 0.0], ["assis", -0.45, 0.45, 0.75, PI], ["assis", 0.45, 0.45, 0.75, PI]]},
	"chaise": {"n": "Chaise", "k": "chaise", "w": 1, "d": 1, "h": 0.95, "prix": 90, "conf": 2, "attr": 1, "p": ["sejour", "cuisine", "salle", "bureau"],
		"tags": ["assise"], "places": [["assis", 0.0, 0.45, 0.0, 0.0]]},
	"buffet": {"n": "Buffet", "k": "buffet", "w": 2, "d": 1, "h": 1.0, "prix": 600, "conf": 3, "attr": 3, "p": ["sejour", "cuisine"], "mur": true, "tags": ["rangement"]},
	"meuble_tv": {"n": "Meuble télé", "k": "meuble_tv", "w": 2, "d": 1, "h": 1.2, "prix": 900, "conf": 6, "attr": 3, "p": ["sejour", "enfant"], "mur": true, "e": [3, 5], "tags": ["ecran"]},
	"bibliotheque": {"n": "Bibliothèque", "k": "bibliotheque", "w": 2, "d": 1, "h": 2.0, "prix": 500, "conf": 4, "attr": 4, "p": ["sejour", "bureau", "classe", "enfant"], "mur": true, "tags": ["livres"]},
	"cheminee": {"n": "Cheminée", "k": "cheminee", "w": 2, "d": 1, "h": 1.3, "prix": 2500, "conf": 9, "attr": 6, "p": ["sejour", "chambre"], "mur": true, "e": [0, 4], "tags": ["chauffage"]},
	"poele": {"n": "Poêle", "k": "poele", "w": 1, "d": 1, "h": 1.2, "prix": 900, "conf": 6, "attr": 2, "p": ["sejour", "cuisine"], "e": [2, 4], "tags": ["chauffage"]},
	"piano": {"n": "Piano", "k": "piano", "w": 2, "d": 1, "h": 1.3, "prix": 4000, "conf": 5, "attr": 7, "p": ["sejour", "classe", "salle"], "mur": true, "e": [2, 5],
		"places": [["assis", 0.0, 0.45, 0.55, PI]]},
	"horloge": {"n": "Horloge", "k": "horloge", "w": 1, "d": 1, "h": 2.1, "prix": 800, "conf": 1, "attr": 3, "p": ["sejour", "entree"], "mur": true, "e": [1, 5]},
	"bureau_maison": {"n": "Bureau et chaise", "k": "bureau", "w": 2, "d": 1, "h": 1.0, "prix": 450, "conf": 4, "attr": 2, "p": ["enfant", "bureau", "chambre"], "mur": true,
		"tags": ["poste"], "places": [["poste", 0.0, 0.45, 0.25, PI]]},
	# --- Cuisine --------------------------------------------------------------
	"plan_travail": {"n": "Plan de travail", "k": "plan_travail", "w": 1, "d": 1, "h": 0.9, "prix": 300, "conf": 2, "attr": 1, "p": ["cuisine"], "mur": true, "tags": ["preparation"]},
	"evier": {"n": "Évier", "k": "evier", "w": 1, "d": 1, "h": 0.9, "prix": 450, "conf": 4, "attr": 1, "p": ["cuisine"], "mur": true, "tags": ["eau"],
		"places": [["cuisine", 0.0, 0.0, 0.6, PI]]},
	"cuisiniere": {"n": "Cuisinière", "k": "cuisiniere", "w": 1, "d": 1, "h": 0.9, "prix": 600, "conf": 5, "attr": 1, "p": ["cuisine"], "mur": true, "e": [3, 5], "tags": ["cuisson"],
		"places": [["cuisine", 0.0, 0.0, 0.6, PI]]},
	"fourneau": {"n": "Fourneau à bois", "k": "fourneau", "w": 1, "d": 1, "h": 1.0, "prix": 500, "conf": 4, "attr": 2, "p": ["cuisine"], "mur": true, "e": [1, 2], "tags": ["cuisson", "chauffage"],
		"places": [["cuisine", 0.0, 0.0, 0.6, PI]]},
	"foyer_feu": {"n": "Foyer de cuisson", "k": "foyer_feu", "w": 1, "d": 1, "h": 0.5, "prix": 120, "conf": 3, "attr": 1, "p": ["cuisine"], "e": [0, 1], "tags": ["cuisson"],
		"places": [["cuisine", 0.0, 0.0, 0.6, PI]]},
	"refrigerateur": {"n": "Réfrigérateur", "k": "frigo", "w": 1, "d": 1, "h": 1.85, "prix": 700, "conf": 5, "attr": 1, "p": ["cuisine"], "mur": true, "e": [3, 5], "tags": ["froid"]},
	"garde_manger": {"n": "Garde-manger", "k": "garde_manger", "w": 1, "d": 1, "h": 1.7, "prix": 250, "conf": 3, "attr": 1, "p": ["cuisine"], "mur": true, "e": [0, 2], "tags": ["froid"]},
	"vaisselier": {"n": "Vaisselier", "k": "vaisselier", "w": 2, "d": 1, "h": 2.0, "prix": 650, "conf": 2, "attr": 4, "p": ["cuisine", "sejour"], "mur": true, "e": [1, 3], "tags": ["rangement"]},
	"jarre": {"n": "Jarre", "k": "jarre", "w": 1, "d": 1, "h": 0.8, "prix": 60, "conf": 1, "attr": 2, "p": ["cuisine", "reserve", "deco"], "e": [0, 2]},
	"lave_vaisselle": {"n": "Lave-vaisselle", "k": "lave_vaisselle", "w": 1, "d": 1, "h": 0.9, "prix": 500, "conf": 4, "attr": 0, "p": ["cuisine"], "mur": true, "e": [3, 5], "tags": ["eau"]},
	# --- Salle de bains -------------------------------------------------------
	"baignoire": {"n": "Baignoire", "k": "baignoire", "w": 2, "d": 1, "h": 0.6, "prix": 900, "conf": 8, "attr": 2, "p": ["sdb"], "mur": true, "e": [2, 5], "tags": ["toilette"]},
	"baquet": {"n": "Baquet de bain", "k": "baquet", "w": 1, "d": 1, "h": 0.6, "prix": 150, "conf": 4, "attr": 2, "p": ["sdb"], "e": [0, 1], "tags": ["toilette"]},
	"douche": {"n": "Douche", "k": "douche", "w": 1, "d": 1, "h": 2.1, "prix": 800, "conf": 6, "attr": 1, "p": ["sdb"], "mur": true, "e": [3, 5], "tags": ["toilette"]},
	"lavabo": {"n": "Lavabo", "k": "lavabo", "w": 1, "d": 1, "h": 1.6, "prix": 350, "conf": 3, "attr": 1, "p": ["sdb"], "mur": true, "e": [2, 5], "tags": ["toilette", "eau"]},
	"table_toilette": {"n": "Table de toilette", "k": "table_toilette", "w": 1, "d": 1, "h": 1.0, "prix": 200, "conf": 2, "attr": 2, "p": ["sdb", "chambre"], "mur": true, "e": [0, 1], "tags": ["toilette", "eau"]},
	"wc": {"n": "Toilettes", "k": "wc", "w": 1, "d": 1, "h": 0.8, "prix": 300, "conf": 5, "attr": 0, "p": ["sdb"], "mur": true, "e": [2, 5], "tags": ["wc"]},
	"chaise_percee": {"n": "Chaise percée", "k": "chaise_percee", "w": 1, "d": 1, "h": 0.9, "prix": 80, "conf": 2, "attr": 0, "p": ["sdb"], "mur": true, "e": [0, 1], "tags": ["wc"]},
	"meuble_vasque": {"n": "Meuble vasque", "k": "vasque", "w": 2, "d": 1, "h": 1.7, "prix": 900, "conf": 5, "attr": 3, "p": ["sdb"], "mur": true, "e": [3, 5], "tags": ["toilette", "eau"]},
	# --- Entrée ---------------------------------------------------------------
	"porte_manteau": {"n": "Porte-manteau", "k": "porte_manteau", "w": 1, "d": 1, "h": 1.8, "prix": 80, "conf": 2, "attr": 1, "p": ["entree"], "mur": true},
	"banc": {"n": "Banc", "k": "banc", "w": 2, "d": 1, "h": 0.5, "prix": 160, "conf": 3, "attr": 1, "p": ["entree", "salle", "classe"], "mur": true,
		"tags": ["assise"], "places": [["assis", -0.45, 0.45, 0.0, 0.0], ["assis", 0.45, 0.45, 0.0, 0.0]]},
	"miroir": {"n": "Miroir", "k": "miroir", "w": 1, "d": 1, "h": 1.0, "prix": 150, "conf": 1, "attr": 2, "p": ["entree", "sdb", "chambre"], "mur": true, "couche": "mur", "e": [1, 5]},
	# --- Bureau ---------------------------------------------------------------
	"poste_travail": {"n": "Poste de travail", "k": "poste", "w": 2, "d": 1, "h": 1.2, "prix": 1400, "conf": 4, "attr": 2, "p": ["bureau"], "mur": false,
		"tags": ["poste"], "places": [["poste", 0.0, 0.45, 0.25, PI]]},
	"armoire_dossiers": {"n": "Armoire à dossiers", "k": "dossiers", "w": 1, "d": 1, "h": 1.9, "prix": 350, "conf": 1, "attr": 0, "p": ["bureau", "classe"], "mur": true, "tags": ["rangement"]},
	"photocopieur": {"n": "Photocopieur", "k": "photocopieur", "w": 1, "d": 1, "h": 1.1, "prix": 2500, "conf": 1, "attr": 1, "p": ["bureau"], "mur": true, "e": [3, 5]},
	"fontaine_eau": {"n": "Fontaine à eau", "k": "fontaine", "w": 1, "d": 1, "h": 1.3, "prix": 300, "conf": 3, "attr": 1, "p": ["bureau", "classe"], "mur": true, "e": [3, 5]},
	"table_reunion": {"n": "Table de réunion", "k": "table_repas", "w": 2, "d": 2, "h": 0.95, "prix": 1200, "conf": 4, "attr": 3, "p": ["bureau"],
		"tags": ["table", "assise"], "places": [["assis", -0.45, 0.45, -0.75, 0.0], ["assis", 0.45, 0.45, -0.75, 0.0], ["assis", -0.45, 0.45, 0.75, PI], ["assis", 0.45, 0.45, 0.75, PI]]},
	# --- École ----------------------------------------------------------------
	"pupitre": {"n": "Pupitre d'élève", "k": "pupitre", "w": 1, "d": 1, "h": 0.8, "prix": 140, "conf": 1, "attr": 1, "p": ["classe"],
		"tags": ["pupitre"], "places": [["pupitre", 0.0, 0.42, 0.2, PI]]},
	"tableau": {"n": "Tableau", "k": "tableau", "w": 2, "d": 1, "h": 2.2, "prix": 400, "conf": 0, "attr": 2, "p": ["classe", "bureau"], "mur": true, "couche": "mur", "e": [2, 5],
		"tags": ["tableau"], "places": [["tableau", 0.0, 0.0, 0.7, 0.0]]},
	"bureau_maitre": {"n": "Bureau du maître", "k": "bureau", "w": 2, "d": 1, "h": 1.0, "prix": 500, "conf": 3, "attr": 2, "p": ["classe"],
		"tags": ["poste"], "places": [["poste", 0.0, 0.45, 0.25, PI]]},
	"casiers": {"n": "Casiers", "k": "casiers", "w": 2, "d": 1, "h": 1.5, "prix": 450, "conf": 1, "attr": 1, "p": ["classe", "entree"], "mur": true, "e": [3, 5], "tags": ["rangement"]},
	"globe": {"n": "Globe terrestre", "k": "globe", "w": 1, "d": 1, "h": 1.0, "prix": 180, "conf": 0, "attr": 3, "p": ["classe", "bureau", "deco"], "e": [2, 5]},
	# --- Boutique -------------------------------------------------------------
	"comptoir": {"n": "Comptoir et caisse", "k": "comptoir", "w": 2, "d": 1, "h": 1.1, "prix": 1500, "conf": 1, "attr": 3, "p": ["boutique"],
		"tags": ["comptoir"], "places": [["comptoir", 0.0, 0.0, -0.3, 0.0]]},
	"rayonnage": {"n": "Rayonnage", "k": "rayonnage", "w": 2, "d": 1, "h": 1.9, "prix": 600, "conf": 0, "attr": 5, "p": ["boutique", "reserve"], "mur": true,
		"tags": ["rayon"], "places": [["client", 0.0, 0.0, 0.8, PI]]},
	"presentoir": {"n": "Présentoir", "k": "presentoir", "w": 1, "d": 1, "h": 1.0, "prix": 350, "conf": 0, "attr": 6, "p": ["boutique"],
		"tags": ["rayon"], "places": [["client", 0.0, 0.0, 0.75, PI]]},
	"vitrine_froide": {"n": "Vitrine réfrigérée", "k": "vitrine_froide", "w": 2, "d": 1, "h": 1.9, "prix": 3500, "conf": 0, "attr": 6, "p": ["boutique", "salle"], "mur": true, "e": [3, 5],
		"tags": ["rayon", "froid"], "places": [["client", 0.0, 0.0, 0.8, PI]]},
	"portant": {"n": "Portant de vêtements", "k": "portant", "w": 2, "d": 1, "h": 1.6, "prix": 250, "conf": 0, "attr": 5, "p": ["boutique"], "e": [2, 5],
		"tags": ["rayon"], "places": [["client", 0.0, 0.0, 0.8, PI]]},
	"etal": {"n": "Étal", "k": "etal", "w": 2, "d": 1, "h": 1.0, "prix": 300, "conf": 0, "attr": 6, "p": ["boutique"], "e": [0, 2],
		"tags": ["rayon"], "places": [["client", 0.0, 0.0, 0.8, PI]]},
	"mannequin": {"n": "Mannequin", "k": "mannequin", "w": 1, "d": 1, "h": 1.8, "prix": 250, "conf": 0, "attr": 6, "p": ["boutique"], "e": [2, 5]},
	"caisses": {"n": "Caisses et sacs", "k": "caisses", "w": 1, "d": 1, "h": 0.9, "prix": 60, "conf": 0, "attr": 1, "p": ["reserve", "boutique"]},
	"etagere_reserve": {"n": "Étagère de réserve", "k": "etagere", "w": 2, "d": 1, "h": 2.0, "prix": 250, "conf": 0, "attr": 0, "p": ["reserve"], "mur": true, "tags": ["rangement"]},
	# --- Café-restaurant ------------------------------------------------------
	"table_bistrot": {"n": "Table de bistrot", "k": "table_bistrot", "w": 2, "d": 1, "h": 0.95, "prix": 350, "conf": 4, "attr": 4, "p": ["salle", "cuisine"],
		"tags": ["table", "assise"], "places": [["assis", -0.68, 0.45, 0.0, PI * 0.5], ["assis", 0.68, 0.45, 0.0, -PI * 0.5]]},
	"comptoir_bar": {"n": "Comptoir de bar", "k": "bar", "w": 2, "d": 1, "h": 1.15, "prix": 2500, "conf": 2, "attr": 6, "p": ["salle"],
		"tags": ["comptoir"], "places": [["comptoir", 0.0, 0.0, -0.3, 0.0]]},
	"tabouret": {"n": "Tabouret", "k": "tabouret", "w": 1, "d": 1, "h": 0.75, "prix": 70, "conf": 1, "attr": 1, "p": ["salle", "cuisine"],
		"tags": ["assise"], "places": [["assis", 0.0, 0.7, 0.0, 0.0]]},
	"banquette": {"n": "Banquette", "k": "banquette", "w": 2, "d": 1, "h": 1.0, "prix": 700, "conf": 6, "attr": 4, "p": ["salle", "sejour"], "mur": true,
		"tags": ["assise"], "places": [["assis", -0.45, 0.45, 0.0, 0.0], ["assis", 0.45, 0.45, 0.0, 0.0]]},
	# --- Décoration -----------------------------------------------------------
	"tapis": {"n": "Tapis", "k": "tapis", "w": 2, "d": 2, "h": 0.02, "prix": 250, "conf": 3, "attr": 3, "p": ["deco", "sejour", "chambre", "enfant"], "couche": "sol"},
	"grand_tapis": {"n": "Grand tapis", "k": "tapis", "w": 3, "d": 2, "h": 0.02, "prix": 450, "conf": 4, "attr": 4, "p": ["deco", "sejour", "salle"], "couche": "sol"},
	"plante": {"n": "Plante verte", "k": "plante", "w": 1, "d": 1, "h": 0.9, "prix": 40, "conf": 2, "attr": 3, "p": ["deco", "sejour", "bureau", "boutique", "salle", "entree", "classe"]},
	"grande_plante": {"n": "Grande plante", "k": "grande_plante", "w": 1, "d": 1, "h": 1.8, "prix": 120, "conf": 3, "attr": 4, "p": ["deco", "sejour", "bureau", "salle"]},
	"lampadaire": {"n": "Lampadaire", "k": "lampadaire", "w": 1, "d": 1, "h": 1.7, "prix": 150, "conf": 3, "attr": 2, "p": ["deco", "sejour", "chambre", "bureau"], "tags": ["lumiere"]},
	"statue": {"n": "Statue", "k": "statue", "w": 1, "d": 1, "h": 1.6, "prix": 1800, "conf": 0, "attr": 8, "p": ["deco", "entree", "salle"]},
	"aquarium": {"n": "Aquarium", "k": "aquarium", "w": 2, "d": 1, "h": 1.4, "prix": 900, "conf": 3, "attr": 7, "p": ["deco", "sejour", "salle"], "mur": true, "e": [3, 5]},
	"cadre": {"n": "Tableau accroché", "k": "cadre", "w": 1, "d": 1, "h": 1.0, "prix": 200, "conf": 1, "attr": 4, "p": ["deco", "sejour", "chambre", "entree", "bureau", "salle"], "mur": true, "couche": "mur"},
	"etagere_murale": {"n": "Étagère murale", "k": "etagere_murale", "w": 1, "d": 1, "h": 0.4, "prix": 60, "conf": 1, "attr": 2, "p": ["deco", "cuisine", "enfant", "sejour"], "mur": true, "couche": "mur"},
	"paravent": {"n": "Paravent", "k": "paravent", "w": 2, "d": 1, "h": 1.7, "prix": 300, "conf": 1, "attr": 4, "p": ["deco", "chambre"]},
	"coussins_sol": {"n": "Coussins de sol", "k": "coussins", "w": 1, "d": 1, "h": 0.25, "prix": 80, "conf": 3, "attr": 2, "p": ["deco", "sejour"],
		"tags": ["assise"], "places": [["assis_sol", 0.0, 0.12, 0.0, 0.0]]},
	"hamac": {"n": "Hamac", "k": "hamac", "w": 1, "d": 2, "h": 1.4, "prix": 150, "conf": 5, "attr": 4, "p": ["deco", "chambre", "sejour"],
		"tags": ["lit"], "places": [["lit", 0.0, 0.55, 0.0, 0.0]]},
}

## Styles de mobilier. pal : bois, bois2 (clair), tissu, tissu2, metal, accent,
## pierre. alt : noms (et modèles) propres au style ; sans : types absents ;
## plus : pièces propres au style (mêmes champs que TYPES, avec "base" : le type
## dont elles prennent les valeurs) ; prix / conf : multiplicateurs.
const STYLES := {
	# --- Europe ---------------------------------------------------------------
	"rustique": {"name": "Rustique européen", "region": "europe", "era": "traditionnel", "prix": 1.0, "conf": 0.9,
		"pal": {"bois": "6b4a2f", "bois2": "a07850", "tissu": "b5452f", "tissu2": "e8dcc0", "metal": "3a3a3a", "accent": "c9a227", "pierre": "9c9488"},
		"alt": {"lit_double": {"n": "Lit clos breton", "k": "lit_clos"}, "armoire": {"n": "Armoire normande"}, "horloge": {"n": "Horloge comtoise"},
			"coffre": {"n": "Coffre de mariage"}, "table_repas": {"n": "Table de ferme et bancs"}, "fauteuil": {"n": "Fauteuil paillé"}, "chaise": {"n": "Chaise paillée"}},
		"plus": {"maie": {"base": "buffet", "n": "Maie à pétrir", "p": ["cuisine"], "attr": 3}}},
	"louis_xv": {"name": "Louis XV", "region": "europe", "era": "traditionnel", "prix": 2.6, "conf": 1.15,
		"pal": {"bois": "8a5a32", "bois2": "d9b77a", "tissu": "7a2335", "tissu2": "e6c9a8", "metal": "c9a227", "accent": "d4af37", "pierre": "e6e0d4"},
		"alt": {"lit_double": {"n": "Lit à baldaquin", "k": "baldaquin"}, "fauteuil": {"n": "Bergère"}, "canape": {"n": "Canapé à oreilles"}, "commode": {"n": "Commode galbée"},
			"table_basse": {"n": "Guéridon"}, "coiffeuse": {"n": "Coiffeuse à miroir"}, "statue": {"n": "Buste de marbre"}, "cadre": {"n": "Portrait à cadre doré"}},
		"plus": {"secretaire": {"base": "bureau_maison", "n": "Secrétaire en marqueterie", "attr": 5}, "lustre_cristal": {"base": "lampadaire", "n": "Girandole en cristal", "attr": 6}}},
	"victorien": {"name": "Victorien et bourgeois XIXe", "region": "europe", "era": "classique", "prix": 1.8, "conf": 1.1,
		"pal": {"bois": "4a2c1d", "bois2": "8c5a3c", "tissu": "2f4f3f", "tissu2": "c8b48a", "metal": "8c6d3a", "accent": "b08d57", "pierre": "d8d0c0"},
		"alt": {"canape": {"n": "Chesterfield"}, "lit_double": {"n": "Lit en fer forgé"}, "fauteuil": {"n": "Fauteuil Voltaire"}, "piano": {"n": "Piano droit"},
			"bibliotheque": {"n": "Bibliothèque vitrée"}, "poele": {"n": "Poêle en faïence"}, "table_basse": {"n": "Table à thé"}},
		"plus": {"meridienne": {"base": "canape", "n": "Méridienne", "conf": 9}}},
	"art_deco": {"name": "Art déco", "region": "europe", "era": "classique", "prix": 2.0, "conf": 1.1,
		"pal": {"bois": "2b1d16", "bois2": "c08a4a", "tissu": "1f4e5f", "tissu2": "e9dcc0", "metal": "c9a227", "accent": "e0b84f", "pierre": "f0ead8"},
		"alt": {"fauteuil": {"n": "Fauteuil club"}, "canape": {"n": "Canapé club"}, "lampadaire": {"n": "Lampadaire vasque"}, "buffet": {"n": "Enfilade laquée"},
			"comptoir_bar": {"n": "Bar en zinc"}, "statue": {"n": "Statuette en bronze"}}},
	"scandinave": {"name": "Scandinave", "region": "europe", "era": "moderne", "prix": 1.1, "conf": 1.05,
		"pal": {"bois": "c9a777", "bois2": "e7d3b0", "tissu": "8a9aa3", "tissu2": "f2f0ea", "metal": "2f3438", "accent": "e0a458", "pierre": "e8e6e1"},
		"alt": {"fauteuil": {"n": "Fauteuil en bois courbé"}, "lampadaire": {"n": "Suspension en papier"}, "poele": {"n": "Poêle à bois design"}}},
	"industriel": {"name": "Loft industriel", "region": "europe", "era": "contemporain", "prix": 1.3, "conf": 1.0,
		"pal": {"bois": "5b4636", "bois2": "8a6c52", "tissu": "6d4c3d", "tissu2": "3f4448", "metal": "2a2d30", "accent": "c26a3c", "pierre": "7d7a76"},
		"alt": {"canape": {"n": "Canapé en cuir vieilli"}, "bibliotheque": {"n": "Étagère métal et bois"}, "table_repas": {"n": "Table d'atelier"}, "lampadaire": {"n": "Lampe d'architecte"}}},
	# --- Méditerranée -----------------------------------------------------------
	"romain": {"name": "Romain antique", "region": "mediterranee", "era": "antique", "prix": 1.6, "conf": 0.8,
		"pal": {"bois": "6e4a2e", "bois2": "b38b5d", "tissu": "8b1e24", "tissu2": "e8dcc4", "metal": "a87b3a", "accent": "c0392b", "pierre": "e8e2d6"},
		"alt": {"lit_double": {"n": "Lectus (lit romain)"}, "canape": {"n": "Triclinium", "k": "triclinium"}, "chaise": {"n": "Sella curulis"}, "fauteuil": {"n": "Cathedra"},
			"table_basse": {"n": "Table en marbre"}, "jarre": {"n": "Amphore", "k": "amphore"}, "statue": {"n": "Statue de marbre"}, "coffre": {"n": "Arca (coffre-fort)"},
			"table_repas": {"n": "Mensa et bancs"}, "lampadaire": {"n": "Candélabre en bronze"}}},
	"provencal": {"name": "Provençal", "region": "mediterranee", "era": "traditionnel", "prix": 1.1, "conf": 0.95,
		"pal": {"bois": "8b5e34", "bois2": "d9b98c", "tissu": "e0b030", "tissu2": "3a6ea5", "metal": "4a4a4a", "accent": "c2410c", "pierre": "e6d7b9"},
		"alt": {"buffet": {"n": "Buffet provençal"}, "vaisselier": {"n": "Panetière"}, "fauteuil": {"n": "Fauteuil de Beaucaire"}, "jarre": {"n": "Jarre d'Anduze", "k": "amphore"}}},
	# --- Moyen-Orient et Maghreb ------------------------------------------------
	"egyptien": {"name": "Égypte antique", "region": "moyen_orient", "era": "antique", "prix": 1.7, "conf": 0.75,
		"pal": {"bois": "7a4e2a", "bois2": "c89b5d", "tissu": "f0e6cf", "tissu2": "2a6f97", "metal": "d4af37", "accent": "1f7a8c", "pierre": "d9c79e"},
		"alt": {"chaise": {"n": "Chaise à pattes de lion"}, "lit_simple": {"n": "Lit à appui-tête"}, "lit_double": {"n": "Lit à appui-tête"}, "coffre": {"n": "Coffre peint"},
			"statue": {"n": "Statue de Bastet"}, "jarre": {"n": "Jarre à grains", "k": "amphore"}, "fauteuil": {"n": "Trône doré"}}},
	"marocain": {"name": "Marocain", "region": "moyen_orient", "era": "traditionnel", "prix": 1.2, "conf": 1.05,
		"pal": {"bois": "6b3b22", "bois2": "b07a4a", "tissu": "a8322d", "tissu2": "1e5f74", "metal": "b8862b", "accent": "e0a030", "pierre": "e9dcc3"},
		"alt": {"canape": {"n": "Sedari (banquette basse)", "k": "banquette_basse"}, "fauteuil": {"n": "Pouf en cuir", "k": "pouf"}, "table_basse": {"n": "Plateau en cuivre", "k": "plateau"},
			"lampadaire": {"n": "Lanterne ajourée", "k": "lanterne"}, "tapis": {"n": "Tapis berbère"}, "grand_tapis": {"n": "Grand tapis berbère"}, "banquette": {"n": "Banquette de salon marocain", "k": "banquette_basse"}},
		"plus": {"tajine": {"base": "foyer_feu", "n": "Kanoun et tajine", "e": [0, 5]}}},
	"persan": {"name": "Persan et ottoman", "region": "moyen_orient", "era": "classique", "prix": 1.6, "conf": 1.1,
		"pal": {"bois": "5a2e1a", "bois2": "9a6a3a", "tissu": "7b1e2b", "tissu2": "1d3b6e", "metal": "c9a227", "accent": "d4a017", "pierre": "e6dcc6"},
		"alt": {"canape": {"n": "Divan", "k": "banquette_basse"}, "tapis": {"n": "Tapis persan"}, "grand_tapis": {"n": "Grand tapis de Tabriz"}, "lampadaire": {"n": "Lampe en cuivre ciselé", "k": "lanterne"},
			"table_basse": {"n": "Table basse en nacre", "k": "plateau"}, "coffre": {"n": "Coffre ottoman"}},
		"plus": {"samovar": {"base": "jarre", "n": "Samovar", "k": "samovar", "e": [0, 5], "prix": 300, "attr": 4}}},
	"majlis": {"name": "Majlis contemporain", "region": "moyen_orient", "era": "contemporain", "prix": 2.2, "conf": 1.15,
		"pal": {"bois": "3b2a20", "bois2": "c9a777", "tissu": "e8dcc8", "tissu2": "6b2737", "metal": "c9a227", "accent": "d4af37", "pierre": "f2ece0"},
		"alt": {"canape": {"n": "Majlis (banquette de réception)", "k": "banquette_basse"}, "table_basse": {"n": "Plateau à dattes", "k": "plateau"}, "lampadaire": {"n": "Lanterne dorée", "k": "lanterne"}}},
	# --- Afrique ------------------------------------------------------------------
	"afrique_ouest": {"name": "Afrique de l'Ouest traditionnelle", "region": "afrique", "era": "traditionnel", "prix": 0.8, "conf": 0.85,
		"pal": {"bois": "4a2a17", "bois2": "8a5a33", "tissu": "d9822b", "tissu2": "2e7d32", "metal": "a0782c", "accent": "f2b134", "pierre": "b08a62"},
		"alt": {"chaise": {"n": "Tabouret sculpté ashanti", "k": "tabouret_sculpte"}, "fauteuil": {"n": "Chaise à palabres", "k": "chaise_palabre"}, "tapis": {"n": "Natte tressée"},
			"grand_tapis": {"n": "Grande natte"}, "jarre": {"n": "Canari (jarre en terre)", "k": "amphore"}, "lit_double": {"n": "Lit en bois sculpté"}, "statue": {"n": "Statue en bois sculpté"},
			"cadre": {"n": "Pagne kente accroché"}, "table_repas": {"n": "Natte de repas et calebasses", "k": "repas_sol"}},
		"plus": {"djembe": {"base": "jarre", "n": "Djembé", "k": "djembe", "prix": 120, "attr": 4, "conf": 2, "e": [0, 5], "p": ["deco", "sejour"]}}},
	"swahili": {"name": "Côte swahilie", "region": "afrique", "era": "classique", "prix": 1.3, "conf": 1.0,
		"pal": {"bois": "3a2416", "bois2": "8c6239", "tissu": "f0e8d8", "tissu2": "1b6f8a", "metal": "b48a3a", "accent": "c9a227", "pierre": "efe6d2"},
		"alt": {"lit_double": {"n": "Lit swahili à baldaquin", "k": "baldaquin"}, "coffre": {"n": "Coffre de Zanzibar"}, "fauteuil": {"n": "Chaise de Lamu"}, "canape": {"n": "Baraza (banc de pierre)", "k": "banquette_basse"}}},
	"afrique_moderne": {"name": "Afrique urbaine contemporaine", "region": "afrique", "era": "contemporain", "prix": 1.0, "conf": 1.05,
		"pal": {"bois": "4b3020", "bois2": "b58b5a", "tissu": "e8562a", "tissu2": "1f8a70", "metal": "2d2d2d", "accent": "f4c430", "pierre": "e6dfd2"},
		"alt": {"coussins_sol": {"n": "Coussins en wax"}, "canape": {"n": "Canapé en wax"}, "cadre": {"n": "Peinture de Dakar"}}},
	# --- Asie de l'Est ------------------------------------------------------------
	"japonais": {"name": "Japonais traditionnel", "region": "asie_est", "era": "traditionnel", "prix": 1.3, "conf": 1.0,
		"pal": {"bois": "6a4a32", "bois2": "c9b28a", "tissu": "2f3e5c", "tissu2": "efe8d8", "metal": "2a2a2a", "accent": "b22222", "pierre": "cfc6b4"},
		"alt": {"lit_double": {"n": "Futon double", "k": "futon"}, "lit_simple": {"n": "Futon", "k": "futon"}, "chaise": {"n": "Zabuton (coussin)", "k": "coussins"},
			"fauteuil": {"n": "Zaisu (chaise de sol)", "k": "zaisu"}, "table_basse": {"n": "Kotatsu", "k": "kotatsu"}, "commode": {"n": "Tansu"}, "armoire": {"n": "Tansu en escalier", "k": "tansu_escalier"},
			"tapis": {"n": "Tatamis", "k": "tatami"}, "grand_tapis": {"n": "Six tatamis", "k": "tatami"}, "lampadaire": {"n": "Andon (lampe de papier)", "k": "andon"},
			"paravent": {"n": "Paravent byōbu"}, "table_repas": {"n": "Chabudai et zabutons", "k": "repas_sol"}, "baquet": {"n": "Ofuro (bain en bois)"}, "cadre": {"n": "Kakemono (rouleau peint)"}},
		"sans": ["canape"]},
	"chinois": {"name": "Chinois Ming", "region": "asie_est", "era": "traditionnel", "prix": 1.8, "conf": 1.0,
		"pal": {"bois": "4a1f14", "bois2": "8b3a22", "tissu": "b22222", "tissu2": "e8c872", "metal": "c9a227", "accent": "d4af37", "pierre": "d8d0c0"},
		"alt": {"lit_double": {"n": "Lit à baldaquin Ming", "k": "baldaquin"}, "canape": {"n": "Lit luohan"}, "chaise": {"n": "Chaise Ming"}, "fauteuil": {"n": "Fauteuil fer à cheval"},
			"armoire": {"n": "Armoire laquée"}, "lampadaire": {"n": "Lanterne rouge", "k": "lanterne"}, "paravent": {"n": "Paravent laqué"}, "jarre": {"n": "Vase de porcelaine", "k": "amphore"}}},
	"coreen": {"name": "Coréen (hanok)", "region": "asie_est", "era": "classique", "prix": 1.3, "conf": 1.0,
		"pal": {"bois": "5c3a24", "bois2": "b8956a", "tissu": "c8384f", "tissu2": "2f6f6f", "metal": "8a6d3a", "accent": "e0b84f", "pierre": "e8e0cf"},
		"alt": {"lit_double": {"n": "Yo (matelas de sol)", "k": "futon"}, "lit_simple": {"n": "Yo", "k": "futon"}, "coffre": {"n": "Bandaji"}, "table_basse": {"n": "Soban", "k": "plateau"},
			"chaise": {"n": "Bangseok (coussin)", "k": "coussins"}, "table_repas": {"n": "Table basse de repas", "k": "repas_sol"}},
		"sans": ["canape"]},
	"asie_moderne": {"name": "Tokyo contemporain", "region": "asie_est", "era": "contemporain", "prix": 1.2, "conf": 1.05,
		"pal": {"bois": "a58a64", "bois2": "e2d3b8", "tissu": "6c7a80", "tissu2": "f4f1ea", "metal": "1f2326", "accent": "d64545", "pierre": "ece9e2"},
		"alt": {"lit_double": {"n": "Lit plateforme bas"}, "table_basse": {"n": "Kotatsu moderne", "k": "kotatsu"}, "lampadaire": {"n": "Lampe en papier washi", "k": "andon"}}},
	# --- Asie du Sud et du Sud-Est -----------------------------------------------
	"indien": {"name": "Indien traditionnel", "region": "asie_sud", "era": "traditionnel", "prix": 1.0, "conf": 0.95,
		"pal": {"bois": "5a3218", "bois2": "a86a32", "tissu": "d1495b", "tissu2": "f0a830", "metal": "b8862b", "accent": "2e8b57", "pierre": "e0cfa8"},
		"alt": {"lit_simple": {"n": "Charpai (lit de corde)", "k": "charpai"}, "lit_double": {"n": "Charpai double", "k": "charpai"}, "canape": {"n": "Jhula (balançoire)", "k": "balancoire"},
			"table_basse": {"n": "Chowki"}, "tapis": {"n": "Durrie"}, "grand_tapis": {"n": "Grand durrie"}, "coffre": {"n": "Coffre peint du Rajasthan"}, "chaise": {"n": "Gaddi (coussin)", "k": "coussins"},
			"statue": {"n": "Statue de Ganesh"}, "lampadaire": {"n": "Lampe à huile (diya)", "k": "lanterne"}},
		"plus": {"autel": {"base": "commode", "n": "Autel domestique (mandir)", "attr": 5, "p": ["sejour", "deco"]}}},
	"balinais": {"name": "Balinais et thaï", "region": "asie_sud", "era": "traditionnel", "prix": 1.1, "conf": 1.0,
		"pal": {"bois": "6b4423", "bois2": "b88a52", "tissu": "f2ead6", "tissu2": "b85c2e", "metal": "a07a2c", "accent": "2f7d4f", "pierre": "cfc0a0"},
		"alt": {"canape": {"n": "Lit de repos en teck"}, "lit_double": {"n": "Lit à baldaquin en teck", "k": "baldaquin"}, "fauteuil": {"n": "Fauteuil en rotin"}, "statue": {"n": "Bouddha en pierre"},
			"lampadaire": {"n": "Lampe en bambou", "k": "lanterne"}}},
	"colonial": {"name": "Colonial", "region": "asie_sud", "era": "classique", "prix": 1.4, "conf": 1.05,
		"pal": {"bois": "3d2516", "bois2": "8c6a45", "tissu": "efe6d0", "tissu2": "3d5a40", "metal": "8c6d3a", "accent": "b08d57", "pierre": "e8dfcc"},
		"alt": {"fauteuil": {"n": "Fauteuil planteur"}, "lit_double": {"n": "Lit à moustiquaire", "k": "baldaquin"}, "canape": {"n": "Canapé en rotin"}, "coffre": {"n": "Malle de voyage"}}},
	# --- Amériques ----------------------------------------------------------------
	"mexicain": {"name": "Mexicain colonial", "region": "ameriques", "era": "traditionnel", "prix": 1.0, "conf": 0.95,
		"pal": {"bois": "5e3420", "bois2": "a5683a", "tissu": "d62828", "tissu2": "2a9d8f", "metal": "3a3a3a", "accent": "f4a261", "pierre": "e9c46a"},
		"alt": {"fauteuil": {"n": "Equipal (fauteuil en cuir)"}, "armoire": {"n": "Trastero peint"}, "jarre": {"n": "Poterie talavera", "k": "amphore"}, "cadre": {"n": "Retablo"},
			"tapis": {"n": "Tapis zapotèque"}},
		"plus": {"hamac_yucatan": {"base": "hamac", "n": "Hamac du Yucatán", "conf": 6}}},
	"far_west": {"name": "Pionnier américain", "region": "ameriques", "era": "classique", "prix": 0.9, "conf": 0.95,
		"pal": {"bois": "6a4528", "bois2": "a77b4f", "tissu": "8b2e2e", "tissu2": "d9c7a0", "metal": "2f2f2f", "accent": "b5651d", "pierre": "a8998a"},
		"alt": {"fauteuil": {"n": "Rocking-chair", "k": "rocking"}, "poele": {"n": "Poêle en fonte"}, "coffre": {"n": "Coffre de pionnier"}, "lit_double": {"n": "Lit et courtepointe"}, "comptoir_bar": {"n": "Comptoir de saloon"}}},
	"mid_century": {"name": "Mid-century américain", "region": "ameriques", "era": "moderne", "prix": 1.5, "conf": 1.1,
		"pal": {"bois": "7a4a26", "bois2": "c08a52", "tissu": "d98c2b", "tissu2": "2f6f73", "metal": "c0c0c0", "accent": "e9573f", "pierre": "efe8da"},
		"alt": {"fauteuil": {"n": "Fauteuil lounge"}, "buffet": {"n": "Enfilade en teck"}, "table_basse": {"n": "Table basse ovale"}, "comptoir_bar": {"n": "Comptoir de diner"}, "banquette": {"n": "Banquette de diner"}}},
	"andin": {"name": "Andin", "region": "ameriques", "era": "traditionnel", "prix": 0.8, "conf": 0.9,
		"pal": {"bois": "5b3b25", "bois2": "9d7550", "tissu": "c1272d", "tissu2": "f2a900", "metal": "a8a8a8", "accent": "1d6fa3", "pierre": "b3a189"},
		"alt": {"tapis": {"n": "Tapis en laine d'alpaga"}, "grand_tapis": {"n": "Grand tissage andin"}, "coffre": {"n": "Coffre de Cuzco"}, "jarre": {"n": "Jarre inca (aríbalo)", "k": "amphore"}}},
	# --- Océanie ------------------------------------------------------------------
	"polynesien": {"name": "Polynésien", "region": "oceanie", "era": "traditionnel", "prix": 0.8, "conf": 0.9,
		"pal": {"bois": "5a3a22", "bois2": "b08a5a", "tissu": "e9dcb5", "tissu2": "c0392b", "metal": "6b6b6b", "accent": "2a9d8f", "pierre": "9c8f80"},
		"alt": {"tapis": {"n": "Natte en pandanus"}, "grand_tapis": {"n": "Grande natte en pandanus"}, "lit_double": {"n": "Couche de nattes", "k": "futon"}, "lit_simple": {"n": "Natte de couchage", "k": "futon"},
			"cadre": {"n": "Tapa peint"}, "statue": {"n": "Tiki sculpté"}, "coffre": {"n": "Coffre de pirogue"}, "table_repas": {"n": "Repas sur nattes", "k": "repas_sol"}},
		"sans": ["canape"]},
	"bord_de_mer": {"name": "Bord de mer australien", "region": "oceanie", "era": "contemporain", "prix": 1.2, "conf": 1.05,
		"pal": {"bois": "b89b72", "bois2": "e8dcc4", "tissu": "4f8fbf", "tissu2": "f4f1e8", "metal": "8a8f94", "accent": "f2a541", "pierre": "efe9df"},
		"alt": {"fauteuil": {"n": "Fauteuil en osier"}, "canape": {"n": "Canapé en lin"}}},
	# --- Monde --------------------------------------------------------------------
	"annees_70": {"name": "Années 1970", "region": "monde", "era": "moderne", "prix": 1.0, "conf": 1.0,
		"pal": {"bois": "6a4026", "bois2": "b07a45", "tissu": "c06b1f", "tissu2": "6b7d2a", "metal": "d0d0d0", "accent": "e1a03a", "pierre": "e6dcc6"},
		"alt": {"canape": {"n": "Canapé en velours côtelé"}, "lampadaire": {"n": "Lampe boule"}, "meuble_tv": {"n": "Téléviseur à tube"}}},
	"contemporain": {"name": "Contemporain", "region": "monde", "era": "contemporain", "prix": 1.0, "conf": 1.0,
		"pal": {"bois": "9a7b5b", "bois2": "d8c4a6", "tissu": "5e6b73", "tissu2": "efeee9", "metal": "2b2f33", "accent": "3a86c8", "pierre": "eceae6"},
		"alt": {}},
	"luxe": {"name": "Luxe contemporain", "region": "monde", "era": "contemporain", "prix": 3.0, "conf": 1.25,
		"pal": {"bois": "2a1d17", "bois2": "8b6b4a", "tissu": "e9e1d3", "tissu2": "1c2b39", "metal": "c9a227", "accent": "d4af37", "pierre": "f4f1ec"},
		"alt": {"lampadaire": {"n": "Lustre design"}, "statue": {"n": "Sculpture d'artiste"}, "cadre": {"n": "Toile de maître"}}},
	"futuriste": {"name": "Futuriste", "region": "monde", "era": "futuriste", "prix": 2.0, "conf": 1.2,
		"pal": {"bois": "dfe6ec", "bois2": "f6f8fa", "tissu": "4f5d75", "tissu2": "e8eef3", "metal": "8fa3b3", "accent": "2ec4f1", "pierre": "f2f5f7"},
		"alt": {"lit_double": {"n": "Lit capsule", "k": "capsule"}, "lit_simple": {"n": "Capsule de repos", "k": "capsule"}, "fauteuil": {"n": "Fauteuil œuf", "k": "oeuf"},
			"table_basse": {"n": "Table holographique", "k": "holo"}, "meuble_tv": {"n": "Mur d'écrans"}, "lampadaire": {"n": "Colonne lumineuse"}, "plante": {"n": "Jardin hydroponique"},
			"cuisiniere": {"n": "Cuisine automatique"}, "refrigerateur": {"n": "Conservateur cryo"}, "comptoir": {"n": "Caisse sans contact"}, "tableau": {"n": "Tableau interactif"}}},
}

## Style de mobilier par défaut selon la région du monde.
const DEFAULT_STYLE := {"europe": "contemporain", "mediterranee": "provencal", "moyen_orient": "marocain", "afrique": "afrique_moderne",
	"asie_est": "asie_moderne", "asie_sud": "indien", "ameriques": "mid_century", "oceanie": "bord_de_mer", "monde": "contemporain"}

static var _all: Dictionary = {}
static var _order: Array = []


static func era_index(era: String) -> int:
	return maxi(0, ERA_ORDER.find(era))


static func piece_name(p: String) -> String:
	if PIECES.has(p):
		return String(PIECES[p].name)
	return String(CATEGORY_NAMES.get(p, p))


static func style_of(id: String) -> Dictionary:
	return STYLES.get(id, STYLES.contemporain)


## Tous les meubles : { id : entrée }. id = "<style>/<type>".
static func all() -> Dictionary:
	if _all.is_empty():
		_build()
	return _all


## Identifiants dans l'ordre du catalogue (style par style).
static func ids() -> Array:
	if _all.is_empty():
		_build()
	return _order


static func get_entry(id: String) -> Dictionary:
	return all().get(id, {})


static func has(id: String) -> bool:
	return all().has(id)


static func _build() -> void:
	_all.clear()
	_order.clear()
	for sid in STYLES:
		var st: Dictionary = STYLES[sid]
		var ei := era_index(String(st.era))
		var sans: Array = st.get("sans", [])
		var alt: Dictionary = st.get("alt", {})
		for tid in TYPES:
			if tid in sans:
				continue
			var t: Dictionary = TYPES[tid]
			var er: Array = t.get("e", [0, 5])
			if ei < int(er[0]) or ei > int(er[1]):
				continue
			_add(sid, st, tid, t, alt.get(tid, {}))
		var plus: Dictionary = st.get("plus", {})
		for pid in plus:
			var over: Dictionary = plus[pid]
			var base: Dictionary = TYPES.get(String(over.get("base", "")), {})
			if base.is_empty():
				continue
			var er2: Array = over.get("e", base.get("e", [0, 5]))
			if ei < int(er2[0]) or ei > int(er2[1]):
				continue
			_add(sid, st, pid, base, over)


static func _add(sid: String, st: Dictionary, tid: String, t: Dictionary, over: Dictionary) -> void:
	var e := {}
	for k in t:
		e[k] = t[k]
	for k in over:
		if k != "base":
			e[k] = over[k]
	var id := "%s/%s" % [sid, tid]
	e["id"] = id
	e["type"] = String(over.get("base", tid))
	e["style"] = sid
	e["name"] = String(e.n)
	e["region"] = String(st.region)
	e["era"] = String(st.era)
	e["couche"] = String(e.get("couche", "meuble"))
	e["mur"] = bool(e.get("mur", false))
	e["prix"] = maxi(5, roundi(float(e.prix) * float(st.prix) / 5.0) * 5)
	e["conf"] = roundi(float(e.conf) * float(st.conf))
	e["tags"] = e.get("tags", [])
	e["places"] = e.get("places", [])
	_all[id] = e
	_order.append(id)


## Meubles d'un onglet (pièce ou "deco"), filtrés par style, région, époque et texte.
static func filtered(cat := "", style := "", region := "", era := "", text := "") -> Array:
	var out := []
	var t := text.strip_edges().to_lower()
	for id in ids():
		var e: Dictionary = _all[id]
		if cat != "" and not (e.p as Array).has(cat):
			continue
		if style != "" and String(e.style) != style:
			continue
		if region != "" and String(e.region) != region:
			continue
		if era != "" and String(e.era) != era:
			continue
		if t != "" and not (String(e.name) + " " + String(style_of(String(e.style)).name)).to_lower().contains(t):
			continue
		out.append(id)
	return out


## Meilleur meuble d'un type dans un style (ou un style proche de la même époque).
static func pick(type_id: String, style: String) -> String:
	var a := all()
	var id := "%s/%s" % [style, type_id]
	if a.has(id):
		return id
	# Sinon : un équivalent de la même époque, puis de n'importe quelle époque.
	var era := String(style_of(style).era)
	var region := String(style_of(style).region)
	var best := ""
	var best_score := -1
	for sid in STYLES:
		var cand := "%s/%s" % [sid, type_id]
		if not a.has(cand):
			continue
		var st: Dictionary = STYLES[sid]
		var score := 0
		if String(st.region) == region:
			score += 2
		score += 4 - mini(4, absi(era_index(String(st.era)) - era_index(era)))
		if score > best_score:
			best_score = score
			best = cand
	return best


## Premier type présent dans le style parmi plusieurs équivalents (cuisinière,
## fourneau, foyer…) : rend l'identifiant du meuble ou "".
static func pick_any(types: Array, style: String) -> String:
	for t in types:
		var id := "%s/%s" % [style, t]
		if all().has(id):
			return id
	for t in types:
		var id2 := pick(String(t), style)
		if id2 != "":
			var st := String(style_of(style).era)
			var er: Array = TYPES.get(String(t), {}).get("e", [0, 5])
			if era_index(st) >= int(er[0]) and era_index(st) <= int(er[1]):
				return id2
	for t in types:
		var id3 := pick(String(t), style)
		if id3 != "":
			return id3
	return ""


## Taille au sol une fois tourné de r quarts de tour.
static func footprint(e: Dictionary, r: int) -> Vector2i:
	if r % 2 == 1:
		return Vector2i(int(e.d), int(e.w))
	return Vector2i(int(e.w), int(e.d))


## Cases occupées par un meuble posé en c (coin −x −z), tourné de r.
static func cells_of(e: Dictionary, c: Vector2i, r: int) -> Array:
	var f := footprint(e, r)
	var out := []
	for dx in f.x:
		for dz in f.y:
			out.append(c + Vector2i(dx, dz))
	return out


## Transformation du repère du meuble (centre au sol, avant vers +Z) vers le monde.
static func transform_of(e: Dictionary, c: Vector2i, r: int, floor_y: float) -> Transform3D:
	var f := footprint(e, r)
	var center := Vector3(c.x + f.x * 0.5, floor_y, c.y + f.y * 0.5)
	return Transform3D(Basis(Vector3.UP, r * PI * 0.5), center)


## Direction (case voisine) vers laquelle se trouve le dos d'un meuble tourné de r.
static func back_dir(r: int) -> Vector2i:
	return [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 0)][r % 4]


## Nombre de meubles et de styles (pour l'aide et les tests).
static func count() -> int:
	return all().size()


static func describe(id: String) -> String:
	var e := get_entry(id)
	if e.is_empty():
		return ""
	var parts: Array[String] = [BuildingSystem.format_money(int(e.prix))]
	if int(e.conf) > 0:
		parts.append("confort +%d" % int(e.conf))
	if int(e.attr) > 0:
		parts.append("attrait +%d" % int(e.attr))
	return " · ".join(parts)
