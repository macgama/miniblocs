class_name MuseeObjets
extends RefCounted
## Les « ingrédients » du musée : vitrines, socles, œuvres et objets exposés
## (peinture, sculpture, antiquités, histoire naturelle, sciences, histoire,
## arts du monde, transports, automobile, air et espace, marine, cinéma, sport,
## mode, musique, jouets, préhistoire, bande dessinée, gastronomie), éclairage,
## parcours de visite, accueil, boutique et café.
##
## Ce sont des meubles comme les autres (bible Meubles, style « musee », ids
## « musee/<type> ») : ils se posent case par case dans un bâtiment en murs fins
## avec l'outil de pose de l'Intérieur, se tournent avec R, se retirent au clic
## droit. Leurs champs en plus :
## - fam : famille (onglet du menu Musée) ;
## - theme : thème de collection (clé de THEMES) pour les objets exposés, ""
##   pour le reste ;
## - valeur : valeur d'assurance (€) ; prestige : ce qu'il apporte à la
##   réputation du musée ; fragile : à protéger (vitrine, cordon, gardien) ;
## - protege : vitrine ou cordon (protège les objets fragiles de la salle) ;
## - lumiere : points d'éclairage ; confort : bancs, cartels, plans, audioguides ;
## - service : billetterie, vestiaire, boutique, cafe, audioguide, toilettes ;
## - suspendu : pendu au plafond (couche « sol », passe au-dessus des meubles).

const STYLE := "musee"

## Familles du menu Musée (onglets), dans l'ordre.
const FAMILLES := {
	"vitrines": {"name": "Vitrines", "icon": "vitrine", "desc": "Elles protègent les objets fragiles de la salle et en exposent elles-mêmes."},
	"socles": {"name": "Socles et cimaises", "icon": "socle", "desc": "La mise en valeur : socles, estrades, cimaises."},
	"peinture": {"name": "Peinture", "icon": "tableau", "desc": "Tableaux à accrocher sur un mur plein."},
	"sculpture": {"name": "Sculpture", "icon": "statue", "desc": "Statues, bustes, bronzes et sculptures modernes."},
	"antiquites": {"name": "Antiquités", "icon": "amphore", "desc": "Égypte, Grèce, Rome : amphores, momies, colonnes, mosaïques."},
	"nature": {"name": "Histoire naturelle", "icon": "dino", "desc": "Squelettes de dinosaures, fossiles, minéraux, animaux naturalisés."},
	"sciences": {"name": "Sciences et techniques", "icon": "industrie", "desc": "Machines, lunettes astronomiques, avions, automobiles, robots."},
	"histoire": {"name": "Histoire", "icon": "bouclier", "desc": "Armures, canons, carrosses, costumes, cartes et plans-reliefs."},
	"monde": {"name": "Arts du monde", "icon": "globe", "desc": "Afrique, Asie, Amériques, Océanie."},
	"transports": {"name": "Transports et chemins de fer", "icon": "rail", "desc": "Locomotive, vélocipèdes, motos, trains miniatures, signaux, affiches de voyage."},
	"automobile": {"name": "Automobile", "icon": "vehicules", "desc": "Voitures de course, limousines, citadines, moteurs, pompes à essence."},
	"espace": {"name": "Air et espace", "icon": "lune", "desc": "Module lunaire, capsule, combinaison, satellite, planeur, montgolfière."},
	"marine": {"name": "Marine et océans", "icon": "eau", "desc": "Galion, figure de proue, scaphandre, phare, canot, aquarium."},
	"cinema": {"name": "Cinéma et photographie", "icon": "vue", "desc": "Caméras, projecteurs, affiches, décors, costumes de film, fauteuils rouges."},
	"sport": {"name": "Sport", "icon": "sport", "desc": "Maillots, vélos, coupes, médailles, flambeau, skis, statues de champions."},
	"mode": {"name": "Mode et costume", "icon": "creations", "desc": "Haute couture, robes de bal, chapeaux, souliers, podium de défilé."},
	"musique": {"name": "Musique", "icon": "son", "desc": "Piano à queue, harpe, guitares, violon, juke-box, gramophone, cor des Alpes."},
	"jouets": {"name": "Jeux et jouets", "icon": "fete", "desc": "Maison de poupée, cheval à bascule, trains, peluches, bornes d'arcade, consoles."},
	"prehistoire": {"name": "Préhistoire", "icon": "feu", "desc": "Grotte peinte, silex, hutte en os de mammouth, crânes, menhir."},
	"bd": {"name": "Bande dessinée", "icon": "editeur", "desc": "Planches originales, couvertures, héros, table à dessin, coin lecture."},
	"gastronomie": {"name": "Vin et gastronomie", "icon": "commerce", "desc": "Alambic, tonneaux, pressoir, fourneau, grands crus, chaudron à fromage."},
	"eclairage": {"name": "Éclairage", "icon": "lampe", "desc": "Rails de spots, lustres, appliques : une œuvre dans le noir ne vaut rien."},
	"parcours": {"name": "Parcours de visite", "icon": "chemin", "desc": "Cordons, bancs, cartels, panneaux, flèches, audioguides."},
	"services": {"name": "Accueil et services", "icon": "billet", "desc": "Billetterie (indispensable), vestiaire, boutique, café, toilettes."},
}
const FAMILLE_ORDER := ["vitrines", "socles", "peinture", "sculpture", "antiquites", "nature", "sciences", "histoire", "monde",
	"transports", "automobile", "espace", "marine", "cinema", "sport", "mode", "musique", "jouets", "prehistoire", "bd", "gastronomie",
	"eclairage", "parcours", "services"]

## Thèmes des collections.
const THEMES := {
	"art": {"name": "Beaux-arts"},
	"antiquite": {"name": "Antiquités"},
	"nature": {"name": "Histoire naturelle"},
	"sciences": {"name": "Sciences et techniques"},
	"histoire": {"name": "Histoire"},
	"monde": {"name": "Arts du monde"},
	"transports": {"name": "Transports"},
	"automobile": {"name": "Automobile"},
	"espace": {"name": "Air et espace"},
	"marine": {"name": "Marine"},
	"cinema": {"name": "Cinéma et photographie"},
	"sport": {"name": "Sport"},
	"mode": {"name": "Mode"},
	"musique": {"name": "Musique"},
	"jouets": {"name": "Jeux et jouets"},
	"prehistoire": {"name": "Préhistoire"},
	"bd": {"name": "Bande dessinée"},
	"gastronomie": {"name": "Vin et gastronomie"},
}

## Objets du musée. Mêmes champs que Meubles.TYPES (n, k, w, d, h, prix, attr,
## mur, couche, tags, places), plus ceux de l'en-tête.
const TYPES := {
	# --- Vitrines ---------------------------------------------------------------------------------------
	"vitrine_murale": {"n": "Vitrine murale", "k": "vitrine_murale", "fam": "vitrines", "w": 2, "d": 1, "h": 2.1, "prix": 4500, "attr": 2, "mur": true, "protege": true},
	"vitrine_table": {"n": "Vitrine de table", "k": "vitrine_table", "fam": "vitrines", "w": 2, "d": 1, "h": 1.0, "prix": 3200, "attr": 2, "protege": true},
	"vitrine_cloche": {"n": "Vitrine-cloche sur socle", "k": "vitrine_cloche", "fam": "vitrines", "w": 1, "d": 1, "h": 1.7, "prix": 2600, "attr": 2, "protege": true},
	"vitrine_centrale": {"n": "Grande vitrine à quatre faces", "k": "vitrine_centrale", "fam": "vitrines", "w": 2, "d": 2, "h": 2.2, "prix": 8000, "attr": 3, "protege": true},
	"vitrine_climat": {"n": "Vitrine climatisée", "k": "vitrine_murale", "fam": "vitrines", "w": 2, "d": 1, "h": 2.1, "prix": 12000, "attr": 2, "mur": true, "protege": true, "tags": ["climat"]},
	"vitrine_bijoux": {"n": "Vitrine de bijoux égyptiens", "k": "vitrine_table", "c": "bijoux", "fam": "vitrines", "theme": "antiquite", "w": 2, "d": 1, "h": 1.0, "prix": 38000, "attr": 6, "protege": true, "valeur": 900000, "prestige": 10},
	"vitrine_monnaies": {"n": "Vitrine de monnaies anciennes", "k": "vitrine_table", "c": "monnaies", "fam": "vitrines", "theme": "histoire", "w": 2, "d": 1, "h": 1.0, "prix": 18000, "attr": 4, "protege": true, "valeur": 250000, "prestige": 5},
	"vitrine_fossiles": {"n": "Vitrine de fossiles", "k": "vitrine_murale", "c": "fossiles", "fam": "vitrines", "theme": "nature", "w": 2, "d": 1, "h": 2.1, "prix": 16000, "attr": 5, "mur": true, "protege": true, "valeur": 120000, "prestige": 6},
	"vitrine_mineraux": {"n": "Vitrine de minéraux et cristaux", "k": "vitrine_murale", "c": "mineraux", "fam": "vitrines", "theme": "nature", "w": 2, "d": 1, "h": 2.1, "prix": 14000, "attr": 5, "mur": true, "protege": true, "valeur": 90000, "prestige": 5},
	"vitrine_instruments": {"n": "Vitrine d'instruments scientifiques", "k": "vitrine_murale", "c": "instruments", "fam": "vitrines", "theme": "sciences", "w": 2, "d": 1, "h": 2.1, "prix": 15000, "attr": 4, "mur": true, "protege": true, "valeur": 150000, "prestige": 5},
	"vitrine_porcelaines": {"n": "Vitrine de porcelaines d'Asie", "k": "vitrine_murale", "c": "porcelaines", "fam": "vitrines", "theme": "monde", "w": 2, "d": 1, "h": 2.1, "prix": 22000, "attr": 5, "mur": true, "protege": true, "valeur": 400000, "prestige": 7},
	"vitrine_dodo": {"n": "Dodo naturalisé sous cloche", "k": "vitrine_cloche", "c": "dodo", "fam": "vitrines", "theme": "nature", "w": 1, "d": 1, "h": 1.7, "prix": 25000, "attr": 6, "protege": true, "valeur": 300000, "prestige": 8},
	# --- Socles et cimaises ----------------------------------------------------------------------------
	"socle_cube": {"n": "Socle blanc", "k": "socle_cube", "fam": "socles", "w": 1, "d": 1, "h": 1.0, "prix": 400, "attr": 1, "tags": ["socle"]},
	"colonne_socle": {"n": "Colonne-socle en marbre", "k": "colonne_socle", "fam": "socles", "w": 1, "d": 1, "h": 1.1, "prix": 1500, "attr": 2, "tags": ["socle"]},
	"estrade": {"n": "Estrade basse", "k": "estrade", "fam": "socles", "w": 2, "d": 2, "h": 0.25, "prix": 900, "attr": 1, "tags": ["socle"]},
	"piedestal_dore": {"n": "Piédestal doré", "k": "piedestal_dore", "fam": "socles", "w": 1, "d": 1, "h": 1.1, "prix": 2800, "attr": 3, "tags": ["socle"]},
	"cimaise": {"n": "Cimaise mobile (panneau d'accrochage)", "k": "cimaise", "fam": "socles", "w": 2, "d": 1, "h": 2.6, "prix": 1200, "attr": 1, "tags": ["cimaise"]},
	"tapis_musee": {"n": "Tapis rouge de galerie", "k": "tapis_musee", "fam": "socles", "w": 3, "d": 2, "h": 0.02, "prix": 600, "attr": 2, "couche": "sol"},
	# --- Peinture (au mur) -----------------------------------------------------------------------------
	"tableau_classique": {"n": "Tableau de maître", "k": "tableau", "c": "classique", "fam": "peinture", "theme": "art", "w": 1, "d": 1, "h": 1.0, "prix": 25000, "attr": 6, "mur": true, "couche": "mur", "valeur": 250000, "prestige": 6, "fragile": true},
	"portrait": {"n": "Portrait de la Renaissance", "k": "tableau", "c": "portrait", "fam": "peinture", "theme": "art", "w": 1, "d": 1, "h": 1.1, "prix": 40000, "attr": 7, "mur": true, "couche": "mur", "valeur": 400000, "prestige": 8, "fragile": true},
	"nature_morte": {"n": "Nature morte flamande", "k": "tableau", "c": "nature_morte", "fam": "peinture", "theme": "art", "w": 1, "d": 1, "h": 0.9, "prix": 18000, "attr": 5, "mur": true, "couche": "mur", "valeur": 180000, "prestige": 5, "fragile": true},
	"paysage": {"n": "Paysage impressionniste", "k": "tableau", "c": "paysage", "fam": "peinture", "theme": "art", "w": 2, "d": 1, "h": 1.2, "prix": 110000, "attr": 10, "mur": true, "couche": "mur", "valeur": 1200000, "prestige": 16, "fragile": true},
	"grand_tableau": {"n": "Grande toile d'histoire", "k": "tableau", "c": "histoire", "fam": "peinture", "theme": "art", "w": 3, "d": 1, "h": 2.0, "prix": 85000, "attr": 11, "mur": true, "couche": "mur", "valeur": 900000, "prestige": 14, "fragile": true},
	"triptyque": {"n": "Triptyque médiéval", "k": "triptyque", "fam": "peinture", "theme": "art", "w": 3, "d": 1, "h": 1.6, "prix": 60000, "attr": 9, "mur": true, "couche": "mur", "valeur": 600000, "prestige": 11, "fragile": true},
	"toile_abstraite": {"n": "Toile abstraite", "k": "tableau", "c": "abstrait", "fam": "peinture", "theme": "art", "w": 2, "d": 1, "h": 1.6, "prix": 30000, "attr": 7, "mur": true, "couche": "mur", "valeur": 300000, "prestige": 7, "fragile": true},
	"estampe": {"n": "Estampe japonaise (la grande vague)", "k": "tableau", "c": "estampe", "fam": "peinture", "theme": "monde", "w": 1, "d": 1, "h": 0.8, "prix": 8000, "attr": 5, "mur": true, "couche": "mur", "valeur": 60000, "prestige": 4, "fragile": true},
	"fresque": {"n": "Fresque murale", "k": "fresque", "fam": "peinture", "theme": "art", "w": 4, "d": 1, "h": 2.2, "prix": 15000, "attr": 7, "mur": true, "couche": "mur", "valeur": 120000, "prestige": 6},
	"chef_oeuvre": {"n": "« La Dame au sourire » (chef-d'œuvre sous verre)", "k": "chef_oeuvre", "fam": "peinture", "theme": "art", "w": 1, "d": 1, "h": 0.9, "prix": 900000, "attr": 25, "mur": true, "couche": "mur", "valeur": 50000000, "prestige": 60, "fragile": true, "tags": ["star"]},
	# --- Sculpture -------------------------------------------------------------------------------------
	"statue_antique": {"n": "Vénus de marbre", "k": "statue_antique", "fam": "sculpture", "theme": "art", "w": 1, "d": 1, "h": 2.4, "prix": 70000, "attr": 9, "valeur": 800000, "prestige": 12, "fragile": true},
	"buste": {"n": "Buste en bronze sur colonne", "k": "buste", "fam": "sculpture", "theme": "art", "w": 1, "d": 1, "h": 1.8, "prix": 22000, "attr": 6, "valeur": 200000, "prestige": 5},
	"songeur": {"n": "« Le Songeur », bronze", "k": "songeur", "fam": "sculpture", "theme": "art", "w": 1, "d": 1, "h": 1.9, "prix": 95000, "attr": 10, "valeur": 1500000, "prestige": 15},
	"cavalier": {"n": "Statue équestre en bronze", "k": "cavalier", "fam": "sculpture", "theme": "art", "w": 2, "d": 3, "h": 2.9, "prix": 120000, "attr": 12, "valeur": 1100000, "prestige": 14},
	"sculpture_moderne": {"n": "Sculpture abstraite en acier", "k": "sculpture_moderne", "fam": "sculpture", "theme": "art", "w": 2, "d": 2, "h": 2.4, "prix": 45000, "attr": 8, "valeur": 450000, "prestige": 8},
	"mobile": {"n": "Mobile suspendu", "k": "mobile", "fam": "sculpture", "theme": "art", "w": 2, "d": 2, "h": 0.02, "prix": 28000, "attr": 6, "couche": "sol", "suspendu": true, "valeur": 350000, "prestige": 6},
	# --- Antiquités ------------------------------------------------------------------------------------
	"amphore": {"n": "Amphore grecque sur socle", "k": "amphore_socle", "fam": "antiquites", "theme": "antiquite", "w": 1, "d": 1, "h": 1.8, "prix": 9000, "attr": 4, "valeur": 80000, "prestige": 3, "fragile": true},
	"cratere": {"n": "Cratère à figures rouges", "k": "cratere", "fam": "antiquites", "theme": "antiquite", "w": 1, "d": 1, "h": 1.6, "prix": 30000, "attr": 6, "valeur": 350000, "prestige": 7, "fragile": true},
	"sarcophage": {"n": "Sarcophage égyptien", "k": "sarcophage", "fam": "antiquites", "theme": "antiquite", "w": 1, "d": 3, "h": 1.0, "prix": 140000, "attr": 13, "valeur": 2000000, "prestige": 18},
	"momie": {"n": "Momie en vitrine", "k": "momie", "fam": "antiquites", "theme": "antiquite", "w": 1, "d": 3, "h": 1.1, "prix": 160000, "attr": 15, "protege": true, "valeur": 2500000, "prestige": 22},
	"pharaon": {"n": "Statue de pharaon assis", "k": "pharaon", "fam": "antiquites", "theme": "antiquite", "w": 2, "d": 2, "h": 2.9, "prix": 220000, "attr": 16, "valeur": 3500000, "prestige": 24},
	"stele": {"n": "Stèle gravée de trois écritures", "k": "stele", "fam": "antiquites", "theme": "antiquite", "w": 1, "d": 1, "h": 1.5, "prix": 180000, "attr": 12, "valeur": 4000000, "prestige": 20},
	"colonne": {"n": "Colonne grecque", "k": "colonne", "fam": "antiquites", "theme": "antiquite", "w": 1, "d": 1, "h": 2.9, "prix": 12000, "attr": 4, "valeur": 60000, "prestige": 3},
	"mosaique": {"n": "Mosaïque romaine au sol", "k": "mosaique", "fam": "antiquites", "theme": "antiquite", "w": 3, "d": 3, "h": 0.03, "prix": 50000, "attr": 8, "couche": "sol", "valeur": 500000, "prestige": 9},
	"tete_colossale": {"n": "Tête colossale d'empereur", "k": "tete_colossale", "fam": "antiquites", "theme": "antiquite", "w": 2, "d": 2, "h": 2.2, "prix": 75000, "attr": 10, "valeur": 900000, "prestige": 12},
	# --- Histoire naturelle ----------------------------------------------------------------------------
	"dino_herbivore": {"n": "Squelette de grand dinosaure à long cou", "k": "dino_herbivore", "fam": "nature", "theme": "nature", "w": 8, "d": 3, "h": 2.9, "prix": 380000, "attr": 30, "valeur": 6000000, "prestige": 45, "tags": ["star"]},
	"dino_carnivore": {"n": "Squelette de tyrannosaure", "k": "dino_carnivore", "fam": "nature", "theme": "nature", "w": 6, "d": 2, "h": 2.9, "prix": 320000, "attr": 28, "valeur": 8000000, "prestige": 42, "tags": ["star"]},
	"mammouth": {"n": "Squelette de mammouth", "k": "mammouth", "fam": "nature", "theme": "nature", "w": 4, "d": 2, "h": 2.9, "prix": 160000, "attr": 18, "valeur": 1800000, "prestige": 22},
	"baleine": {"n": "Squelette de baleine suspendu", "k": "baleine", "fam": "nature", "theme": "nature", "w": 8, "d": 2, "h": 0.02, "prix": 240000, "attr": 22, "couche": "sol", "suspendu": true, "valeur": 1500000, "prestige": 26},
	"ammonite": {"n": "Ammonite géante sur socle", "k": "ammonite", "fam": "nature", "theme": "nature", "w": 1, "d": 1, "h": 1.5, "prix": 12000, "attr": 5, "valeur": 60000, "prestige": 4},
	"meteorite": {"n": "Météorite de fer", "k": "meteorite", "fam": "nature", "theme": "nature", "w": 1, "d": 1, "h": 1.4, "prix": 35000, "attr": 7, "valeur": 400000, "prestige": 8},
	"ours": {"n": "Ours brun naturalisé", "k": "ours", "fam": "nature", "theme": "nature", "w": 2, "d": 1, "h": 2.2, "prix": 18000, "attr": 7, "valeur": 40000, "prestige": 5},
	"cerf": {"n": "Cerf naturalisé", "k": "cerf", "fam": "nature", "theme": "nature", "w": 2, "d": 1, "h": 2.0, "prix": 9000, "attr": 5, "valeur": 20000, "prestige": 3},
	"papillons": {"n": "Cadre de papillons", "k": "papillons", "fam": "nature", "theme": "nature", "w": 1, "d": 1, "h": 0.8, "prix": 3000, "attr": 4, "mur": true, "couche": "mur", "valeur": 15000, "prestige": 2},
	# --- Sciences et techniques ------------------------------------------------------------------------
	"machine_vapeur": {"n": "Machine à vapeur", "k": "machine_vapeur", "fam": "sciences", "theme": "sciences", "w": 3, "d": 2, "h": 2.6, "prix": 90000, "attr": 12, "valeur": 700000, "prestige": 12},
	"lunette": {"n": "Grande lunette astronomique", "k": "lunette", "fam": "sciences", "theme": "sciences", "w": 1, "d": 2, "h": 2.6, "prix": 45000, "attr": 9, "valeur": 400000, "prestige": 9},
	"globe_celeste": {"n": "Globe céleste", "k": "globe_celeste", "fam": "sciences", "theme": "sciences", "w": 1, "d": 1, "h": 1.5, "prix": 20000, "attr": 6, "valeur": 180000, "prestige": 5, "fragile": true},
	"planetaire": {"n": "Planétaire mécanique", "k": "planetaire", "fam": "sciences", "theme": "sciences", "w": 2, "d": 2, "h": 1.4, "prix": 35000, "attr": 8, "valeur": 300000, "prestige": 8, "fragile": true},
	"pendule": {"n": "Pendule de Foucault", "k": "pendule", "fam": "sciences", "theme": "sciences", "w": 2, "d": 2, "h": 2.9, "prix": 30000, "attr": 9, "valeur": 100000, "prestige": 8},
	"avion": {"n": "Avion ancien suspendu", "k": "avion", "fam": "sciences", "theme": "sciences", "w": 4, "d": 4, "h": 0.02, "prix": 150000, "attr": 18, "couche": "sol", "suspendu": true, "valeur": 1200000, "prestige": 20},
	"automobile": {"n": "Automobile de 1900", "k": "automobile", "fam": "sciences", "theme": "sciences", "w": 2, "d": 4, "h": 1.8, "prix": 85000, "attr": 12, "valeur": 600000, "prestige": 12},
	"fusee": {"n": "Maquette de fusée", "k": "fusee", "fam": "sciences", "theme": "sciences", "w": 1, "d": 1, "h": 2.9, "prix": 25000, "attr": 8, "valeur": 80000, "prestige": 6},
	"robot": {"n": "Robot humanoïde", "k": "robot", "fam": "sciences", "theme": "sciences", "w": 1, "d": 1, "h": 1.8, "prix": 40000, "attr": 9, "valeur": 250000, "prestige": 7},
	"borne_interactive": {"n": "Borne interactive", "k": "borne", "fam": "sciences", "theme": "sciences", "w": 1, "d": 1, "h": 1.5, "prix": 9000, "attr": 6, "valeur": 10000, "prestige": 3, "confort": 2, "tags": ["jeu", "ecran"]},
	# --- Histoire --------------------------------------------------------------------------------------
	"armure": {"n": "Armure de chevalier", "k": "armure", "fam": "histoire", "theme": "histoire", "w": 1, "d": 1, "h": 2.0, "prix": 30000, "attr": 7, "valeur": 250000, "prestige": 7},
	"panoplie": {"n": "Panoplie d'épées et de boucliers", "k": "panoplie", "fam": "histoire", "theme": "histoire", "w": 2, "d": 1, "h": 1.2, "prix": 15000, "attr": 6, "mur": true, "couche": "mur", "valeur": 120000, "prestige": 4},
	"canon": {"n": "Canon de bronze", "k": "canon", "fam": "histoire", "theme": "histoire", "w": 1, "d": 3, "h": 1.2, "prix": 22000, "attr": 6, "valeur": 150000, "prestige": 5},
	"carrosse": {"n": "Carrosse de gala", "k": "carrosse", "fam": "histoire", "theme": "histoire", "w": 2, "d": 4, "h": 2.6, "prix": 200000, "attr": 16, "valeur": 2500000, "prestige": 20},
	"costume": {"n": "Costume d'époque sur mannequin", "k": "costume", "fam": "histoire", "theme": "histoire", "w": 1, "d": 1, "h": 1.9, "prix": 12000, "attr": 6, "valeur": 90000, "prestige": 4, "fragile": true},
	"uniforme": {"n": "Uniforme de grenadier", "k": "uniforme", "fam": "histoire", "theme": "histoire", "w": 1, "d": 1, "h": 2.1, "prix": 10000, "attr": 5, "valeur": 60000, "prestige": 3, "fragile": true},
	"plan_relief": {"n": "Plan-relief de la ville", "k": "plan_relief", "fam": "histoire", "theme": "histoire", "w": 3, "d": 2, "h": 1.2, "prix": 70000, "attr": 11, "protege": true, "valeur": 800000, "prestige": 12},
	"carte_ancienne": {"n": "Carte ancienne du monde", "k": "tableau", "c": "carte", "fam": "histoire", "theme": "histoire", "w": 2, "d": 1, "h": 1.2, "prix": 14000, "attr": 6, "mur": true, "couche": "mur", "valeur": 140000, "prestige": 5, "fragile": true},
	"tapisserie": {"n": "Tapisserie médiévale", "k": "tapisserie", "fam": "histoire", "theme": "histoire", "w": 3, "d": 1, "h": 2.2, "prix": 35000, "attr": 8, "mur": true, "couche": "mur", "valeur": 350000, "prestige": 9, "fragile": true},
	"presse": {"n": "Presse à imprimer ancienne", "k": "presse", "fam": "histoire", "theme": "histoire", "w": 2, "d": 2, "h": 2.2, "prix": 40000, "attr": 8, "valeur": 300000, "prestige": 8},
	"cloche": {"n": "Cloche de beffroi", "k": "cloche", "fam": "histoire", "theme": "histoire", "w": 2, "d": 2, "h": 2.4, "prix": 18000, "attr": 6, "valeur": 90000, "prestige": 4},
	# --- Arts du monde ---------------------------------------------------------------------------------
	"masques": {"n": "Masques d'Afrique de l'Ouest", "k": "masques", "fam": "monde", "theme": "monde", "w": 2, "d": 1, "h": 1.0, "prix": 20000, "attr": 7, "mur": true, "couche": "mur", "valeur": 220000, "prestige": 7},
	"totem": {"n": "Mât totémique", "k": "totem", "fam": "monde", "theme": "monde", "w": 1, "d": 1, "h": 2.9, "prix": 45000, "attr": 9, "valeur": 400000, "prestige": 9},
	"bouddha": {"n": "Bouddha assis en bronze", "k": "bouddha", "fam": "monde", "theme": "monde", "w": 2, "d": 2, "h": 2.4, "prix": 90000, "attr": 12, "valeur": 1000000, "prestige": 13},
	"samourai": {"n": "Armure de samouraï", "k": "samourai", "fam": "monde", "theme": "monde", "w": 1, "d": 1, "h": 1.9, "prix": 50000, "attr": 9, "protege": true, "valeur": 500000, "prestige": 9},
	"vase_ming": {"n": "Vase bleu et blanc sur socle", "k": "vase_ming", "fam": "monde", "theme": "monde", "w": 1, "d": 1, "h": 1.8, "prix": 65000, "attr": 8, "valeur": 900000, "prestige": 10, "fragile": true},
	"tete_pierre": {"n": "Tête de pierre polynésienne", "k": "tete_pierre", "fam": "monde", "theme": "monde", "w": 2, "d": 2, "h": 2.9, "prix": 110000, "attr": 14, "valeur": 1200000, "prestige": 16},
	"pirogue": {"n": "Pirogue sculptée", "k": "pirogue", "fam": "monde", "theme": "monde", "w": 1, "d": 4, "h": 1.0, "prix": 30000, "attr": 8, "valeur": 200000, "prestige": 7},
	"kimono": {"n": "Kimono de soie", "k": "kimono", "fam": "monde", "theme": "monde", "w": 2, "d": 1, "h": 1.6, "prix": 16000, "attr": 6, "mur": true, "couche": "mur", "valeur": 120000, "prestige": 5, "fragile": true},
	"tapis_ancien": {"n": "Tapis persan ancien", "k": "tapisserie", "c": "persan", "fam": "monde", "theme": "monde", "w": 3, "d": 1, "h": 2.0, "prix": 28000, "attr": 7, "mur": true, "couche": "mur", "valeur": 260000, "prestige": 7, "fragile": true},
	# --- Horlogerie (sciences) --------------------------------------------------------------------------
	"comtoise": {"n": "Horloge comtoise", "k": "comtoise", "fam": "sciences", "theme": "sciences", "w": 1, "d": 1, "h": 2.3, "prix": 14000, "attr": 5, "mur": true, "valeur": 60000, "prestige": 4},
	"vitrine_montres": {"n": "Vitrine de montres et de mouvements", "k": "vitrine_table", "c": "montres", "fam": "sciences", "theme": "sciences", "w": 2, "d": 1, "h": 1.0, "prix": 30000, "attr": 6, "protege": true, "valeur": 700000, "prestige": 9},
	"coucou": {"n": "Pendule à coucou", "k": "coucou", "fam": "sciences", "theme": "sciences", "w": 1, "d": 1, "h": 0.8, "prix": 4000, "attr": 4, "mur": true, "couche": "mur", "valeur": 15000, "prestige": 2},
	# --- Transports et chemins de fer -------------------------------------------------------------------
	"locomotive": {"n": "Locomotive à vapeur", "k": "locomotive", "fam": "transports", "theme": "transports", "w": 8, "d": 3, "h": 2.9, "prix": 450000, "attr": 32, "valeur": 3000000, "prestige": 44, "tags": ["star"]},
	"grand_bi": {"n": "Grand-bi de 1880", "k": "grand_bi", "fam": "transports", "theme": "transports", "w": 1, "d": 2, "h": 1.7, "prix": 12000, "attr": 6, "valeur": 40000, "prestige": 4},
	"moto_ancienne": {"n": "Motocyclette de 1920", "k": "moto", "fam": "transports", "theme": "transports", "w": 1, "d": 2, "h": 1.2, "prix": 30000, "attr": 7, "valeur": 90000, "prestige": 6},
	"maquette_train": {"n": "Réseau de trains miniatures", "k": "maquette_train", "fam": "transports", "theme": "transports", "w": 3, "d": 2, "h": 1.2, "prix": 25000, "attr": 9, "protege": true, "valeur": 80000, "prestige": 7, "tags": ["jeu"]},
	"horloge_gare": {"n": "Horloge de gare", "k": "horloge_gare", "fam": "transports", "theme": "transports", "w": 1, "d": 1, "h": 0.9, "prix": 5000, "attr": 4, "mur": true, "couche": "mur", "valeur": 12000, "prestige": 2},
	"signal_ferroviaire": {"n": "Signal ferroviaire et lanterne", "k": "signal", "fam": "transports", "theme": "transports", "w": 1, "d": 1, "h": 2.6, "prix": 6000, "attr": 4, "valeur": 10000, "prestige": 2},
	"draisienne": {"n": "Draisienne et vélocipède", "k": "draisienne", "fam": "transports", "theme": "transports", "w": 2, "d": 1, "h": 1.2, "prix": 9000, "attr": 5, "valeur": 30000, "prestige": 3},
	"affiche_train": {"n": "Affiche de voyage en train", "k": "tableau", "c": "affiche_train", "fam": "transports", "theme": "transports", "w": 1, "d": 1, "h": 1.4, "prix": 3000, "attr": 4, "mur": true, "couche": "mur", "valeur": 8000, "prestige": 2},
	# --- Automobile -------------------------------------------------------------------------------------
	"voiture_course": {"n": "Voiture de course des années 1950", "k": "voiture_course", "fam": "automobile", "theme": "automobile", "w": 2, "d": 4, "h": 1.2, "prix": 180000, "attr": 16, "valeur": 4000000, "prestige": 22},
	"limousine": {"n": "Limousine des années 1930", "k": "limousine", "fam": "automobile", "theme": "automobile", "w": 2, "d": 5, "h": 1.8, "prix": 220000, "attr": 16, "valeur": 2500000, "prestige": 20},
	"citadine": {"n": "Petite citadine des années 1960", "k": "citadine", "fam": "automobile", "theme": "automobile", "w": 2, "d": 3, "h": 1.5, "prix": 40000, "attr": 9, "valeur": 60000, "prestige": 6},
	"monoplace": {"n": "Monoplace de course moderne", "k": "monoplace", "fam": "automobile", "theme": "automobile", "w": 2, "d": 5, "h": 1.0, "prix": 300000, "attr": 20, "valeur": 3000000, "prestige": 26, "tags": ["star"]},
	"moteur": {"n": "Moteur en coupe", "k": "moteur", "fam": "automobile", "theme": "automobile", "w": 1, "d": 1, "h": 1.3, "prix": 15000, "attr": 6, "valeur": 20000, "prestige": 3},
	"pompe_essence": {"n": "Pompe à essence ancienne", "k": "pompe", "fam": "automobile", "theme": "automobile", "w": 1, "d": 1, "h": 2.1, "prix": 8000, "attr": 5, "valeur": 15000, "prestige": 2},
	"plaques_emaillees": {"n": "Plaques émaillées publicitaires", "k": "tableau", "c": "plaques", "fam": "automobile", "theme": "automobile", "w": 2, "d": 1, "h": 1.2, "prix": 4000, "attr": 4, "mur": true, "couche": "mur", "valeur": 9000, "prestige": 2},
	"plateau_tournant": {"n": "Plateau tournant d'exposition", "k": "plateau", "fam": "automobile", "w": 4, "d": 5, "h": 0.15, "prix": 9000, "attr": 3, "couche": "sol", "tags": ["socle"]},
	# --- Air et espace ----------------------------------------------------------------------------------
	"module_lunaire": {"n": "Module lunaire (réplique grandeur nature)", "k": "module_lunaire", "fam": "espace", "theme": "espace", "w": 4, "d": 4, "h": 2.9, "prix": 400000, "attr": 30, "valeur": 2000000, "prestige": 40, "tags": ["star"]},
	"capsule": {"n": "Capsule spatiale revenue sur Terre", "k": "capsule", "fam": "espace", "theme": "espace", "w": 2, "d": 2, "h": 2.4, "prix": 260000, "attr": 20, "valeur": 5000000, "prestige": 28},
	"combinaison": {"n": "Combinaison spatiale", "k": "combinaison", "fam": "espace", "theme": "espace", "w": 1, "d": 1, "h": 2.0, "prix": 60000, "attr": 10, "valeur": 800000, "prestige": 10, "fragile": true},
	"satellite": {"n": "Satellite suspendu", "k": "satellite", "fam": "espace", "theme": "espace", "w": 4, "d": 2, "h": 0.02, "prix": 120000, "attr": 14, "couche": "sol", "suspendu": true, "valeur": 400000, "prestige": 14},
	"planeur": {"n": "Planeur suspendu", "k": "planeur", "fam": "espace", "theme": "espace", "w": 6, "d": 3, "h": 0.02, "prix": 90000, "attr": 14, "couche": "sol", "suspendu": true, "valeur": 200000, "prestige": 12},
	"montgolfiere": {"n": "Montgolfière (maquette suspendue)", "k": "montgolfiere", "fam": "espace", "theme": "espace", "w": 2, "d": 2, "h": 0.02, "prix": 20000, "attr": 8, "couche": "sol", "suspendu": true, "valeur": 30000, "prestige": 4},
	"moteur_fusee": {"n": "Moteur de fusée", "k": "moteur_fusee", "fam": "espace", "theme": "espace", "w": 2, "d": 2, "h": 2.6, "prix": 90000, "attr": 12, "valeur": 600000, "prestige": 12},
	"roche_lunaire": {"n": "Roche lunaire sous cloche", "k": "vitrine_cloche", "c": "roche_lunaire", "fam": "espace", "theme": "espace", "w": 1, "d": 1, "h": 1.7, "prix": 80000, "attr": 12, "protege": true, "valeur": 3000000, "prestige": 16},
	# --- Marine et océans -------------------------------------------------------------------------------
	"galion": {"n": "Maquette de galion", "k": "galion", "fam": "marine", "theme": "marine", "w": 2, "d": 1, "h": 1.9, "prix": 35000, "attr": 9, "protege": true, "valeur": 200000, "prestige": 8},
	"figure_proue": {"n": "Figure de proue", "k": "figure_proue", "fam": "marine", "theme": "marine", "w": 1, "d": 2, "h": 2.2, "prix": 40000, "attr": 9, "valeur": 250000, "prestige": 8},
	"scaphandre": {"n": "Scaphandre à casque de cuivre", "k": "scaphandre", "fam": "marine", "theme": "marine", "w": 1, "d": 1, "h": 2.0, "prix": 25000, "attr": 8, "valeur": 80000, "prestige": 6},
	"ancre": {"n": "Ancre de marine", "k": "ancre", "fam": "marine", "theme": "marine", "w": 1, "d": 1, "h": 2.0, "prix": 8000, "attr": 4, "valeur": 15000, "prestige": 2},
	"lentille_phare": {"n": "Lentille de phare", "k": "lentille", "fam": "marine", "theme": "marine", "w": 2, "d": 2, "h": 2.5, "prix": 70000, "attr": 12, "fragile": true, "valeur": 500000, "prestige": 12},
	"barre_roue": {"n": "Barre à roue", "k": "barre", "fam": "marine", "theme": "marine", "w": 1, "d": 1, "h": 1.0, "prix": 4000, "attr": 4, "mur": true, "couche": "mur", "valeur": 10000, "prestige": 2},
	"canot": {"n": "Canot de sauvetage", "k": "canot", "fam": "marine", "theme": "marine", "w": 2, "d": 5, "h": 1.4, "prix": 60000, "attr": 10, "valeur": 120000, "prestige": 8},
	"aquarium": {"n": "Aquarium de récif", "k": "aquarium", "fam": "marine", "theme": "marine", "w": 3, "d": 1, "h": 2.0, "prix": 45000, "attr": 12, "mur": true, "valeur": 60000, "prestige": 7},
	# --- Cinéma et photographie -------------------------------------------------------------------------
	"camera_cinema": {"n": "Caméra de cinéma ancienne sur trépied", "k": "camera", "fam": "cinema", "theme": "cinema", "w": 1, "d": 1, "h": 1.9, "prix": 30000, "attr": 8, "valeur": 120000, "prestige": 7},
	"projecteur_film": {"n": "Projecteur 35 mm", "k": "projecteur_film", "fam": "cinema", "theme": "cinema", "w": 1, "d": 1, "h": 1.7, "prix": 18000, "attr": 6, "valeur": 40000, "prestige": 4},
	"affiche_film": {"n": "Affiche de film encadrée", "k": "tableau", "c": "affiche", "fam": "cinema", "theme": "cinema", "w": 1, "d": 1, "h": 1.5, "prix": 6000, "attr": 5, "mur": true, "couche": "mur", "valeur": 20000, "prestige": 3},
	"clap": {"n": "Clap géant", "k": "clap", "fam": "cinema", "theme": "cinema", "w": 1, "d": 1, "h": 1.5, "prix": 3000, "attr": 4, "valeur": 2000, "prestige": 1},
	"fauteuils_cine": {"n": "Rangée de fauteuils rouges de cinéma", "k": "fauteuils_cine", "fam": "cinema", "w": 3, "d": 1, "h": 1.0, "prix": 3600, "attr": 3, "confort": 3,
		"tags": ["assise"], "places": [["assis", -0.9, 0.45, 0.0, 0.0], ["assis", 0.0, 0.45, 0.0, 0.0], ["assis", 0.9, 0.45, 0.0, 0.0]]},
	"statuette_cinema": {"n": "Statuette dorée de récompense", "k": "vitrine_cloche", "c": "statuette", "fam": "cinema", "theme": "cinema", "w": 1, "d": 1, "h": 1.7, "prix": 50000, "attr": 10, "protege": true, "valeur": 500000, "prestige": 12},
	"appareil_photo": {"n": "Appareil photo à soufflet", "k": "appareil_photo", "fam": "cinema", "theme": "cinema", "w": 1, "d": 1, "h": 1.6, "prix": 12000, "attr": 5, "valeur": 40000, "prestige": 4, "fragile": true},
	"tirages_photo": {"n": "Tirages photographiques en noir et blanc", "k": "tableau", "c": "photos", "fam": "cinema", "theme": "cinema", "w": 2, "d": 1, "h": 1.2, "prix": 8000, "attr": 5, "mur": true, "couche": "mur", "valeur": 60000, "prestige": 5, "fragile": true},
	"costume_film": {"n": "Costume de robot d'un film de science-fiction", "k": "costume_film", "fam": "cinema", "theme": "cinema", "w": 1, "d": 1, "h": 2.1, "prix": 45000, "attr": 11, "valeur": 400000, "prestige": 10},
	"decor_film": {"n": "Décor de tournage (façade de saloon)", "k": "decor_film", "fam": "cinema", "theme": "cinema", "w": 3, "d": 1, "h": 2.8, "prix": 20000, "attr": 9, "mur": true, "valeur": 30000, "prestige": 6},
	# --- Sport ------------------------------------------------------------------------------------------
	"maillot": {"n": "Maillot dédicacé encadré", "k": "tableau", "c": "maillot", "fam": "sport", "theme": "sport", "w": 1, "d": 1, "h": 1.3, "prix": 6000, "attr": 5, "mur": true, "couche": "mur", "valeur": 30000, "prestige": 4},
	"velo_course": {"n": "Vélo de course d'un grand tour", "k": "velo", "fam": "sport", "theme": "sport", "w": 1, "d": 2, "h": 1.6, "prix": 15000, "attr": 6, "valeur": 50000, "prestige": 5},
	"coupe_sport": {"n": "Coupe du championnat sous cloche", "k": "vitrine_cloche", "c": "coupe", "fam": "sport", "theme": "sport", "w": 1, "d": 1, "h": 1.7, "prix": 40000, "attr": 10, "protege": true, "valeur": 300000, "prestige": 10},
	"medailles": {"n": "Vitrine de médailles olympiques", "k": "vitrine_table", "c": "medailles", "fam": "sport", "theme": "sport", "w": 2, "d": 1, "h": 1.0, "prix": 30000, "attr": 8, "protege": true, "valeur": 250000, "prestige": 9},
	"skis": {"n": "Skis, luge et piolets anciens", "k": "skis", "fam": "sport", "theme": "sport", "w": 2, "d": 1, "h": 1.9, "prix": 5000, "attr": 4, "mur": true, "couche": "mur", "valeur": 8000, "prestige": 2},
	"flambeau": {"n": "Flambeau olympique", "k": "flambeau", "fam": "sport", "theme": "sport", "w": 1, "d": 1, "h": 1.6, "prix": 20000, "attr": 7, "protege": true, "valeur": 80000, "prestige": 6},
	"ballons": {"n": "Vitrine de ballons historiques", "k": "vitrine_murale", "c": "ballons", "fam": "sport", "theme": "sport", "w": 2, "d": 1, "h": 2.1, "prix": 15000, "attr": 6, "mur": true, "protege": true, "valeur": 60000, "prestige": 5},
	"champion": {"n": "Statue de champion en bronze", "k": "champion", "fam": "sport", "theme": "sport", "w": 1, "d": 1, "h": 2.4, "prix": 45000, "attr": 9, "valeur": 150000, "prestige": 8},
	"podium_sport": {"n": "Podium des vainqueurs", "k": "podium_sport", "fam": "sport", "theme": "sport", "w": 3, "d": 1, "h": 0.9, "prix": 4000, "attr": 5, "valeur": 3000, "prestige": 2, "tags": ["jeu"]},
	# --- Mode et costume --------------------------------------------------------------------------------
	"robe_couture": {"n": "Robe de haute couture", "k": "robe", "c": "couture", "fam": "mode", "theme": "mode", "w": 1, "d": 1, "h": 2.0, "prix": 60000, "attr": 11, "fragile": true, "valeur": 600000, "prestige": 12},
	"robe_bal": {"n": "Robe de bal du XVIIIe siècle", "k": "robe", "c": "bal", "fam": "mode", "theme": "mode", "w": 2, "d": 2, "h": 2.0, "prix": 80000, "attr": 12, "fragile": true, "valeur": 700000, "prestige": 13},
	"tailleur": {"n": "Tailleur des années 1950", "k": "robe", "c": "tailleur", "fam": "mode", "theme": "mode", "w": 1, "d": 1, "h": 2.0, "prix": 35000, "attr": 8, "fragile": true, "valeur": 250000, "prestige": 7},
	"smoking": {"n": "Costume de soirée sur mannequin", "k": "robe", "c": "smoking", "fam": "mode", "theme": "mode", "w": 1, "d": 1, "h": 2.0, "prix": 25000, "attr": 7, "fragile": true, "valeur": 120000, "prestige": 5},
	"chapeaux": {"n": "Vitrine de chapeaux", "k": "vitrine_murale", "c": "chapeaux", "fam": "mode", "theme": "mode", "w": 2, "d": 1, "h": 2.1, "prix": 18000, "attr": 6, "mur": true, "protege": true, "valeur": 90000, "prestige": 5},
	"chaussures": {"n": "Vitrine de souliers célèbres", "k": "vitrine_table", "c": "chaussures", "fam": "mode", "theme": "mode", "w": 2, "d": 1, "h": 1.0, "prix": 16000, "attr": 6, "protege": true, "valeur": 120000, "prestige": 5},
	"machine_coudre": {"n": "Machine à coudre ancienne", "k": "machine_coudre", "fam": "mode", "theme": "mode", "w": 1, "d": 1, "h": 1.1, "prix": 6000, "attr": 4, "valeur": 9000, "prestige": 2},
	"podium_defile": {"n": "Podium de défilé", "k": "podium_defile", "fam": "mode", "w": 2, "d": 5, "h": 0.4, "prix": 8000, "attr": 5, "tags": ["socle"]},
	# --- Musique ----------------------------------------------------------------------------------------
	"piano": {"n": "Piano à queue", "k": "piano", "fam": "musique", "theme": "musique", "w": 2, "d": 3, "h": 1.4, "prix": 90000, "attr": 12, "valeur": 400000, "prestige": 11},
	"harpe": {"n": "Harpe de concert", "k": "harpe", "fam": "musique", "theme": "musique", "w": 1, "d": 1, "h": 1.9, "prix": 30000, "attr": 8, "fragile": true, "valeur": 90000, "prestige": 6},
	"guitares": {"n": "Guitares électriques de légende", "k": "guitares", "fam": "musique", "theme": "musique", "w": 2, "d": 1, "h": 1.3, "prix": 40000, "attr": 10, "mur": true, "couche": "mur", "fragile": true, "valeur": 500000, "prestige": 10},
	"violon": {"n": "Violon de maître luthier sous cloche", "k": "vitrine_cloche", "c": "violon", "fam": "musique", "theme": "musique", "w": 1, "d": 1, "h": 1.7, "prix": 120000, "attr": 12, "protege": true, "valeur": 4000000, "prestige": 18},
	"juke_box": {"n": "Juke-box", "k": "juke_box", "fam": "musique", "theme": "musique", "w": 1, "d": 1, "h": 1.6, "prix": 12000, "attr": 7, "valeur": 25000, "prestige": 4, "confort": 1},
	"gramophone": {"n": "Gramophone à pavillon", "k": "gramophone", "fam": "musique", "theme": "musique", "w": 1, "d": 1, "h": 1.5, "prix": 9000, "attr": 6, "fragile": true, "valeur": 30000, "prestige": 4},
	"batterie": {"n": "Batterie d'un groupe de rock", "k": "batterie", "fam": "musique", "theme": "musique", "w": 2, "d": 2, "h": 1.4, "prix": 25000, "attr": 8, "valeur": 150000, "prestige": 6},
	"orgue_barbarie": {"n": "Orgue de Barbarie", "k": "orgue_barbarie", "fam": "musique", "theme": "musique", "w": 1, "d": 1, "h": 1.5, "prix": 15000, "attr": 6, "valeur": 40000, "prestige": 4},
	"cor_alpes": {"n": "Cor des Alpes", "k": "cor_alpes", "fam": "musique", "theme": "musique", "w": 1, "d": 4, "h": 1.0, "prix": 4000, "attr": 5, "valeur": 6000, "prestige": 2},
	# --- Jeux et jouets ---------------------------------------------------------------------------------
	"maison_poupee": {"n": "Maison de poupée", "k": "maison_poupee", "fam": "jouets", "theme": "jouets", "w": 2, "d": 1, "h": 1.7, "prix": 20000, "attr": 8, "fragile": true, "valeur": 90000, "prestige": 6},
	"cheval_bascule": {"n": "Cheval à bascule", "k": "cheval_bascule", "fam": "jouets", "theme": "jouets", "w": 1, "d": 2, "h": 1.1, "prix": 6000, "attr": 5, "valeur": 15000, "prestige": 3},
	"train_jouet": {"n": "Train électrique sur table", "k": "maquette_train", "c": "jouet", "fam": "jouets", "theme": "jouets", "w": 3, "d": 2, "h": 1.2, "prix": 15000, "attr": 8, "protege": true, "valeur": 40000, "prestige": 5, "tags": ["jeu"]},
	"peluche": {"n": "Ours en peluche centenaire", "k": "peluche", "fam": "jouets", "theme": "jouets", "w": 1, "d": 1, "h": 1.3, "prix": 8000, "attr": 6, "fragile": true, "valeur": 60000, "prestige": 4},
	"borne_arcade": {"n": "Borne d'arcade", "k": "arcade", "fam": "jouets", "theme": "jouets", "w": 1, "d": 1, "h": 1.8, "prix": 7000, "attr": 7, "valeur": 10000, "prestige": 3, "confort": 2, "tags": ["jeu", "ecran"]},
	"consoles": {"n": "Vitrine de consoles de jeux vidéo", "k": "vitrine_murale", "c": "consoles", "fam": "jouets", "theme": "jouets", "w": 2, "d": 1, "h": 2.1, "prix": 14000, "attr": 7, "mur": true, "protege": true, "valeur": 40000, "prestige": 5},
	"soldats_plomb": {"n": "Soldats de plomb", "k": "vitrine_table", "c": "soldats", "fam": "jouets", "theme": "jouets", "w": 2, "d": 1, "h": 1.0, "prix": 9000, "attr": 5, "protege": true, "valeur": 30000, "prestige": 3},
	"robot_jouet": {"n": "Robot mécanique en fer-blanc", "k": "vitrine_cloche", "c": "robot_jouet", "fam": "jouets", "theme": "jouets", "w": 1, "d": 1, "h": 1.7, "prix": 8000, "attr": 6, "protege": true, "valeur": 25000, "prestige": 3},
	"toupies": {"n": "Toupies, quilles et cubes", "k": "toupies", "fam": "jouets", "theme": "jouets", "w": 1, "d": 1, "h": 0.9, "prix": 3000, "attr": 4, "valeur": 4000, "prestige": 1, "tags": ["jeu"]},
	# --- Préhistoire ------------------------------------------------------------------------------------
	"paroi_grotte": {"n": "Paroi de grotte peinte", "k": "paroi_grotte", "fam": "prehistoire", "theme": "prehistoire", "w": 3, "d": 1, "h": 2.6, "prix": 60000, "attr": 14, "mur": true, "valeur": 100000, "prestige": 14, "fragile": true},
	"silex": {"n": "Outils de silex taillé", "k": "vitrine_table", "c": "silex", "fam": "prehistoire", "theme": "prehistoire", "w": 2, "d": 1, "h": 1.0, "prix": 12000, "attr": 5, "protege": true, "valeur": 80000, "prestige": 5},
	"chasseur": {"n": "Reconstitution d'un chasseur préhistorique", "k": "chasseur", "fam": "prehistoire", "theme": "prehistoire", "w": 1, "d": 1, "h": 1.9, "prix": 30000, "attr": 9, "valeur": 40000, "prestige": 6},
	"hutte_mammouth": {"n": "Hutte en os de mammouth", "k": "hutte", "fam": "prehistoire", "theme": "prehistoire", "w": 3, "d": 3, "h": 2.4, "prix": 90000, "attr": 14, "valeur": 300000, "prestige": 14},
	"cranes": {"n": "Crânes de nos ancêtres sous cloche", "k": "vitrine_cloche", "c": "cranes", "fam": "prehistoire", "theme": "prehistoire", "w": 1, "d": 1, "h": 1.7, "prix": 40000, "attr": 10, "protege": true, "valeur": 600000, "prestige": 12},
	"foyer": {"n": "Foyer reconstitué", "k": "foyer", "fam": "prehistoire", "theme": "prehistoire", "w": 1, "d": 1, "h": 0.6, "prix": 2000, "attr": 4, "lumiere": 1, "valeur": 1000, "prestige": 1},
	"statuette_prehisto": {"n": "Statuette de l'âge de pierre sous cloche", "k": "vitrine_cloche", "c": "venus", "fam": "prehistoire", "theme": "prehistoire", "w": 1, "d": 1, "h": 1.7, "prix": 70000, "attr": 12, "protege": true, "valeur": 2000000, "prestige": 15},
	"menhir": {"n": "Menhir gravé", "k": "menhir", "fam": "prehistoire", "theme": "prehistoire", "w": 1, "d": 1, "h": 2.6, "prix": 30000, "attr": 8, "valeur": 100000, "prestige": 7},
	# --- Bande dessinée et illustration -----------------------------------------------------------------
	"planche_bd": {"n": "Planche originale de bande dessinée", "k": "tableau", "c": "planche", "fam": "bd", "theme": "bd", "w": 1, "d": 1, "h": 1.3, "prix": 15000, "attr": 6, "mur": true, "couche": "mur", "fragile": true, "valeur": 150000, "prestige": 6},
	"grande_planche": {"n": "Couverture originale d'un album", "k": "tableau", "c": "couverture", "fam": "bd", "theme": "bd", "w": 2, "d": 1, "h": 1.5, "prix": 40000, "attr": 9, "mur": true, "couche": "mur", "fragile": true, "valeur": 800000, "prestige": 12},
	"heros_bd": {"n": "Statue d'un héros de bande dessinée", "k": "heros", "fam": "bd", "theme": "bd", "w": 1, "d": 1, "h": 2.0, "prix": 25000, "attr": 10, "valeur": 40000, "prestige": 6},
	"bulle": {"n": "Bulle géante « Bienvenue ! »", "k": "bulle", "fam": "bd", "theme": "bd", "w": 2, "d": 1, "h": 1.2, "prix": 2000, "attr": 4, "mur": true, "couche": "mur", "valeur": 1000, "prestige": 1},
	"table_dessin": {"n": "Table à dessin de l'auteur", "k": "table_dessin", "fam": "bd", "theme": "bd", "w": 2, "d": 1, "h": 1.3, "prix": 12000, "attr": 6, "valeur": 50000, "prestige": 5},
	"coin_lecture": {"n": "Coin lecture (poufs et bacs d'albums)", "k": "coin_lecture", "fam": "bd", "w": 2, "d": 2, "h": 0.9, "prix": 2500, "attr": 4, "confort": 4,
		"tags": ["assise", "jeu"], "places": [["assis", -0.5, 0.35, 0.4, PI], ["assis", 0.5, 0.35, 0.4, PI]]},
	"fusee_bd": {"n": "Fusée de bande dessinée à pois", "k": "fusee_bd", "fam": "bd", "theme": "bd", "w": 2, "d": 2, "h": 2.9, "prix": 50000, "attr": 14, "valeur": 60000, "prestige": 10},
	# --- Vin et gastronomie -----------------------------------------------------------------------------
	"alambic": {"n": "Alambic en cuivre", "k": "alambic", "fam": "gastronomie", "theme": "gastronomie", "w": 2, "d": 2, "h": 2.0, "prix": 25000, "attr": 8, "valeur": 60000, "prestige": 5},
	"tonneaux": {"n": "Tonneaux de chêne", "k": "tonneaux", "fam": "gastronomie", "theme": "gastronomie", "w": 2, "d": 1, "h": 1.3, "prix": 6000, "attr": 5, "valeur": 8000, "prestige": 2},
	"pressoir": {"n": "Pressoir à vin", "k": "pressoir", "fam": "gastronomie", "theme": "gastronomie", "w": 2, "d": 2, "h": 2.2, "prix": 30000, "attr": 9, "valeur": 90000, "prestige": 6},
	"fourneau": {"n": "Fourneau de cuisine d'autrefois", "k": "fourneau", "fam": "gastronomie", "theme": "gastronomie", "w": 2, "d": 1, "h": 1.6, "prix": 15000, "attr": 6, "mur": true, "valeur": 30000, "prestige": 4},
	"grands_crus": {"n": "Vitrine de grands crus", "k": "vitrine_murale", "c": "bouteilles", "fam": "gastronomie", "theme": "gastronomie", "w": 2, "d": 1, "h": 2.1, "prix": 30000, "attr": 7, "mur": true, "protege": true, "valeur": 400000, "prestige": 8},
	"chaudron_fromage": {"n": "Chaudron à fromage et meules", "k": "chaudron", "fam": "gastronomie", "theme": "gastronomie", "w": 2, "d": 2, "h": 1.5, "prix": 12000, "attr": 7, "valeur": 20000, "prestige": 4},
	"affiche_pub": {"n": "Affiche publicitaire ancienne", "k": "tableau", "c": "affiche_pub", "fam": "gastronomie", "theme": "gastronomie", "w": 1, "d": 1, "h": 1.5, "prix": 4000, "attr": 4, "mur": true, "couche": "mur", "valeur": 12000, "prestige": 2},
	# --- Éclairage -------------------------------------------------------------------------------------
	"rail_spots": {"n": "Rail de spots", "k": "rail_spots", "fam": "eclairage", "w": 2, "d": 1, "h": 0.02, "prix": 900, "attr": 1, "couche": "sol", "suspendu": true, "lumiere": 4, "tags": ["lumiere"]},
	"lustre": {"n": "Lustre de cristal", "k": "lustre", "fam": "eclairage", "w": 2, "d": 2, "h": 0.02, "prix": 6500, "attr": 6, "couche": "sol", "suspendu": true, "lumiere": 6, "tags": ["lumiere"]},
	"applique": {"n": "Applique murale", "k": "applique", "fam": "eclairage", "w": 1, "d": 1, "h": 0.4, "prix": 350, "attr": 1, "mur": true, "couche": "mur", "lumiere": 2, "tags": ["lumiere"]},
	"projecteur": {"n": "Projecteur sur pied", "k": "projecteur", "fam": "eclairage", "w": 1, "d": 1, "h": 1.9, "prix": 700, "attr": 1, "lumiere": 3, "tags": ["lumiere"]},
	"colonne_lumineuse": {"n": "Colonne lumineuse", "k": "colonne_lumineuse", "fam": "eclairage", "w": 1, "d": 1, "h": 2.2, "prix": 1600, "attr": 3, "lumiere": 3, "tags": ["lumiere"]},
	"verriere": {"n": "Puits de lumière (verrière)", "k": "verriere", "fam": "eclairage", "w": 3, "d": 3, "h": 0.02, "prix": 9000, "attr": 5, "couche": "sol", "suspendu": true, "lumiere": 9, "tags": ["lumiere"]},
	# --- Parcours de visite ----------------------------------------------------------------------------
	"cordon": {"n": "Poteaux et cordon rouge", "k": "cordon", "fam": "parcours", "w": 2, "d": 1, "h": 1.0, "prix": 300, "attr": 1, "protege": true},
	"banc_musee": {"n": "Banquette de musée", "k": "banc_musee", "fam": "parcours", "w": 2, "d": 1, "h": 0.5, "prix": 1200, "attr": 2, "confort": 3,
		"tags": ["assise"], "places": [["assis", -0.45, 0.45, 0.0, 0.0], ["assis", 0.45, 0.45, 0.0, 0.0]]},
	"cartel": {"n": "Cartel (étiquette de l'œuvre)", "k": "cartel", "fam": "parcours", "w": 1, "d": 1, "h": 0.3, "prix": 60, "attr": 0, "mur": true, "couche": "mur", "confort": 1},
	"panneau_info": {"n": "Panneau explicatif", "k": "panneau_info", "fam": "parcours", "w": 1, "d": 1, "h": 1.9, "prix": 450, "attr": 1, "confort": 2},
	"fleche": {"n": "Flèche « Sens de la visite »", "k": "fleche", "fam": "parcours", "w": 1, "d": 1, "h": 0.01, "prix": 40, "attr": 0, "couche": "sol", "confort": 1},
	"plan_musee": {"n": "Plan du musée", "k": "plan_musee", "fam": "parcours", "w": 1, "d": 1, "h": 1.8, "prix": 600, "attr": 1, "confort": 2},
	"audioguide": {"n": "Borne d'audioguides", "k": "audioguide", "fam": "parcours", "w": 1, "d": 1, "h": 1.4, "prix": 4000, "attr": 2, "confort": 3, "service": "audioguide"},
	"ecran_video": {"n": "Écran de film documentaire", "k": "ecran_video", "fam": "parcours", "w": 2, "d": 1, "h": 1.2, "prix": 3500, "attr": 4, "mur": true, "couche": "mur", "confort": 2, "tags": ["ecran"]},
	"file_attente": {"n": "Barrières de file d'attente", "k": "file_attente", "fam": "parcours", "w": 2, "d": 2, "h": 1.0, "prix": 500, "attr": 0, "confort": 1},
	# --- Accueil et services ---------------------------------------------------------------------------
	"billetterie": {"n": "Billetterie et accueil", "k": "billetterie", "fam": "services", "w": 3, "d": 1, "h": 1.15, "prix": 6000, "attr": 3, "service": "billetterie",
		"tags": ["comptoir"], "places": [["comptoir", 0.0, 0.0, -0.3, 0.0]]},
	"vestiaire": {"n": "Vestiaire", "k": "vestiaire", "fam": "services", "w": 2, "d": 1, "h": 1.9, "prix": 2500, "attr": 1, "mur": true, "service": "vestiaire", "confort": 2},
	"consignes": {"n": "Consignes à bagages", "k": "consignes", "fam": "services", "w": 2, "d": 1, "h": 1.9, "prix": 3000, "attr": 0, "mur": true, "service": "vestiaire", "confort": 1},
	"caisse_boutique": {"n": "Caisse de la boutique", "k": "caisse_boutique", "fam": "services", "w": 2, "d": 1, "h": 1.1, "prix": 2500, "attr": 2, "service": "boutique",
		"tags": ["comptoir"], "places": [["comptoir", 0.0, 0.0, -0.3, 0.0]]},
	"souvenirs": {"n": "Présentoir de souvenirs", "k": "souvenirs", "fam": "services", "w": 1, "d": 1, "h": 1.5, "prix": 800, "attr": 4, "service": "boutique", "tags": ["rayon"]},
	"livres_art": {"n": "Table de livres d'art", "k": "livres_art", "fam": "services", "w": 2, "d": 1, "h": 0.9, "prix": 1200, "attr": 4, "service": "boutique", "tags": ["rayon"]},
	"cartes_postales": {"n": "Tourniquet de cartes postales", "k": "cartes_postales", "fam": "services", "w": 1, "d": 1, "h": 1.7, "prix": 300, "attr": 3, "service": "boutique", "tags": ["rayon"]},
	"comptoir_cafe": {"n": "Comptoir du café", "k": "comptoir_cafe", "fam": "services", "w": 3, "d": 1, "h": 1.15, "prix": 5000, "attr": 4, "service": "cafe",
		"tags": ["comptoir"], "places": [["comptoir", 0.0, 0.0, -0.3, 0.0]]},
	"table_cafe": {"n": "Table de café et chaises", "k": "table_cafe", "fam": "services", "w": 2, "d": 2, "h": 0.9, "prix": 700, "attr": 3, "service": "cafe", "confort": 2,
		"tags": ["table", "assise"], "places": [["assis", -0.45, 0.45, -0.6, 0.0], ["assis", 0.45, 0.45, 0.6, PI]]},
}

## Meubles ordinaires de la bible proposés aussi dans « Accueil et services ».
const SERVICES_BIBLE := ["contemporain/wc", "contemporain/lavabo", "contemporain/plante", "contemporain/grande_plante", "contemporain/banc", "contemporain/etagere_reserve"]

## Fonctions des salles du musée (outil Fonction et « Aménager la salle »).
const SALLES := {
	"hall_musee": {"name": "Hall d'accueil", "theme": "", "desc": "Billetterie, vestiaire, plan, bancs : là où commence la visite."},
	"galerie_peinture": {"name": "Galerie de peinture", "theme": "art", "desc": "Tableaux aux murs, banquettes au centre, spots."},
	"salle_sculpture": {"name": "Salle des sculptures", "theme": "art", "desc": "Statues et bustes sur socles, à tourner autour."},
	"salle_art_moderne": {"name": "Salle d'art moderne", "theme": "art", "desc": "Toiles abstraites, sculptures d'acier, mobile."},
	"salle_antiquites": {"name": "Salle des antiquités", "theme": "antiquite", "desc": "Amphores, cratères, colonnes, mosaïque."},
	"salle_egypte": {"name": "Salle égyptienne", "theme": "antiquite", "desc": "Sarcophage, momie, pharaon, stèle, bijoux."},
	"salle_dinosaures": {"name": "Galerie des dinosaures", "theme": "nature", "desc": "Les grands squelettes au centre (il faut de la place)."},
	"salle_nature": {"name": "Salle d'histoire naturelle", "theme": "nature", "desc": "Fossiles, minéraux, animaux naturalisés, météorite."},
	"salle_sciences": {"name": "Salle des sciences et techniques", "theme": "sciences", "desc": "Machines, instruments, bornes interactives."},
	"salle_histoire": {"name": "Salle d'histoire", "theme": "histoire", "desc": "Armures, canon, costumes, plan-relief, cartes."},
	"salle_monde": {"name": "Salle des arts du monde", "theme": "monde", "desc": "Masques, totem, bouddha, samouraï, porcelaines."},
	"salle_transports": {"name": "Halle des transports", "theme": "transports", "desc": "La locomotive au centre, vélocipèdes, motos et trains miniatures autour."},
	"salle_automobile": {"name": "Salle de l'automobile", "theme": "automobile", "desc": "Voitures sur plateaux tournants, moteurs, pompes et plaques émaillées."},
	"salle_espace": {"name": "Salle de l'air et de l'espace", "theme": "espace", "desc": "Module lunaire, capsule, et satellite ou planeur au plafond."},
	"salle_marine": {"name": "Salle de la marine", "theme": "marine", "desc": "Galion, figure de proue, scaphandre, lentille de phare, aquarium."},
	"salle_cinema": {"name": "Salle du cinéma", "theme": "cinema", "desc": "Caméras, affiches, décor de tournage, fauteuils rouges devant l'écran."},
	"salle_sport": {"name": "Salle du sport", "theme": "sport", "desc": "Maillots, coupes, médailles, vélos et podium des vainqueurs."},
	"salle_mode": {"name": "Galerie de la mode", "theme": "mode", "desc": "Robes sur mannequins, chapeaux, souliers, podium de défilé."},
	"salle_musique": {"name": "Salle de la musique", "theme": "musique", "desc": "Piano à queue, harpe, guitares, violon et juke-box."},
	"salle_jouets": {"name": "Salle des jouets", "theme": "jouets", "desc": "Maison de poupée, trains, peluches et bornes d'arcade."},
	"salle_prehistoire": {"name": "Salle de la préhistoire", "theme": "prehistoire", "desc": "Grotte peinte, silex, hutte, chasseur, crânes."},
	"salle_bd": {"name": "Salle de la bande dessinée", "theme": "bd", "desc": "Planches originales, héros grandeur nature, coin lecture."},
	"salle_gastronomie": {"name": "Salle du vin et de la gastronomie", "theme": "gastronomie", "desc": "Alambic, tonneaux, pressoir, fourneau, grands crus."},
	"salle_expo": {"name": "Salle d'exposition temporaire", "theme": "", "desc": "Cimaises et vitrines vides : l'exposition du moment s'y installe."},
	"boutique_musee": {"name": "Boutique du musée", "theme": "", "desc": "Caisse, souvenirs, livres d'art, cartes postales."},
	"cafe_musee": {"name": "Café du musée", "theme": "", "desc": "Comptoir et tables : on y discute des œuvres (ou du prix du café)."},
}
const SALLE_ORDER := ["hall_musee", "galerie_peinture", "salle_sculpture", "salle_art_moderne", "salle_antiquites", "salle_egypte", "salle_dinosaures",
	"salle_nature", "salle_sciences", "salle_histoire", "salle_monde", "salle_transports", "salle_automobile", "salle_espace", "salle_marine",
	"salle_cinema", "salle_sport", "salle_mode", "salle_musique", "salle_jouets", "salle_prehistoire", "salle_bd", "salle_gastronomie",
	"salle_expo", "boutique_musee", "cafe_musee"]

## Mobilier de chaque salle (même forme que Mobilier.LAYOUTS ; ids complets).
const LAYOUTS := {
	"hall_musee": [[["musee/billetterie"], "mur", 1, true], [["musee/vestiaire"], "mur", 1, false], [["musee/audioguide"], "mur", 1, false],
		[["musee/plan_musee"], "coin", 1, false], [["musee/banc_musee"], "mur", 1, false], [["musee/file_attente"], "centre", 1, false],
		[["contemporain/grande_plante"], "coin", 2, false], [["musee/lustre"], "sol", 1, false], [["musee/applique"], "accroche", 2, false]],
	"galerie_peinture": [[["musee/paysage"], "accroche", 3, true], [["musee/portrait"], "accroche", 4, false], [["musee/tableau_classique"], "accroche", 4, false],
		[["musee/nature_morte"], "accroche", 3, false], [["musee/grand_tableau"], "accroche", 2, false], [["musee/triptyque"], "accroche", 1, false],
		[["musee/cimaise"], "centre", 2, false], [["musee/banc_musee"], "centre", 2, false],
		[["musee/rail_spots"], "sol", 4, false], [["musee/cordon"], "centre", 1, false]],
	"salle_sculpture": [[["musee/statue_antique"], "remplir", 2, true], [["musee/buste"], "remplir", 3, false], [["musee/songeur"], "remplir", 1, false],
		[["musee/colonne_socle"], "mur", 2, false], [["musee/banc_musee"], "mur", 1, false], [["musee/rail_spots"], "sol", 3, false], [["musee/cartel"], "accroche", 3, false]],
	"salle_art_moderne": [[["musee/toile_abstraite"], "accroche", 3, true], [["musee/sculpture_moderne"], "centre", 1, false], [["musee/mobile"], "sol", 1, false],
		[["musee/cimaise"], "centre", 1, false], [["musee/banc_musee"], "centre", 1, false], [["musee/rail_spots"], "sol", 3, false]],
	"salle_antiquites": [[["musee/cratere"], "remplir", 2, true], [["musee/amphore"], "remplir", 3, false], [["musee/colonne"], "coin", 2, false],
		[["musee/mosaique"], "sol", 1, false], [["musee/tete_colossale"], "centre", 1, false], [["musee/vitrine_murale"], "mur", 1, false],
		[["musee/rail_spots"], "sol", 2, false], [["musee/cartel"], "accroche", 3, false]],
	"salle_egypte": [[["musee/sarcophage"], "centre", 1, true], [["musee/momie"], "centre", 1, false], [["musee/pharaon"], "mur", 1, false],
		[["musee/stele"], "mur", 1, false], [["musee/vitrine_bijoux"], "centre", 1, false], [["musee/amphore"], "coin", 2, false],
		[["musee/projecteur"], "coin", 2, false], [["musee/cartel"], "accroche", 3, false]],
	"salle_dinosaures": [[["musee/dino_herbivore", "musee/dino_carnivore", "musee/mammouth"], "centre", 1, true], [["musee/dino_carnivore"], "centre", 1, false],
		[["musee/vitrine_fossiles"], "mur", 2, false], [["musee/ammonite"], "coin", 2, false], [["musee/panneau_info"], "mur", 2, false],
		[["musee/banc_musee"], "mur", 1, false], [["musee/verriere"], "sol", 1, false], [["musee/rail_spots"], "sol", 2, false]],
	"salle_nature": [[["musee/vitrine_fossiles"], "mur", 1, true], [["musee/vitrine_mineraux"], "mur", 1, false], [["musee/ours"], "mur", 1, false],
		[["musee/cerf"], "mur", 1, false], [["musee/meteorite"], "centre", 1, false], [["musee/vitrine_dodo"], "centre", 1, false],
		[["musee/papillons"], "accroche", 3, false], [["musee/rail_spots"], "sol", 2, false]],
	"salle_sciences": [[["musee/machine_vapeur"], "centre", 1, true], [["musee/lunette"], "coin", 1, false], [["musee/vitrine_instruments"], "mur", 1, false],
		[["musee/globe_celeste"], "coin", 1, false], [["musee/planetaire"], "centre", 1, false], [["musee/borne_interactive"], "mur", 2, false],
		[["musee/robot"], "coin", 1, false], [["musee/avion"], "sol", 1, false], [["musee/ecran_video"], "accroche", 1, false], [["musee/rail_spots"], "sol", 2, false]],
	"salle_histoire": [[["musee/armure"], "mur", 2, true], [["musee/panoplie"], "accroche", 1, false], [["musee/canon"], "centre", 1, false],
		[["musee/plan_relief"], "centre", 1, false], [["musee/costume"], "mur", 2, false], [["musee/uniforme"], "mur", 1, false],
		[["musee/carte_ancienne"], "accroche", 1, false], [["musee/tapisserie"], "accroche", 1, false], [["musee/vitrine_monnaies"], "centre", 1, false],
		[["musee/rail_spots"], "sol", 2, false]],
	"salle_monde": [[["musee/bouddha"], "mur", 1, true], [["musee/masques"], "accroche", 1, false], [["musee/totem"], "coin", 1, false],
		[["musee/samourai"], "mur", 1, false], [["musee/vase_ming"], "remplir", 2, false], [["musee/vitrine_porcelaines"], "mur", 1, false],
		[["musee/kimono"], "accroche", 1, false], [["musee/estampe"], "accroche", 2, false], [["musee/pirogue"], "centre", 1, false], [["musee/rail_spots"], "sol", 2, false]],
	"salle_transports": [[["musee/locomotive"], "centre", 1, true], [["musee/grand_bi"], "mur", 1, false], [["musee/draisienne"], "mur", 1, false],
		[["musee/moto_ancienne"], "mur", 1, false], [["musee/maquette_train"], "centre", 1, false], [["musee/signal_ferroviaire"], "coin", 2, false],
		[["musee/horloge_gare"], "accroche", 1, false], [["musee/affiche_train"], "accroche", 3, false], [["musee/banc_musee"], "mur", 1, false], [["musee/rail_spots"], "sol", 3, false]],
	"salle_automobile": [[["musee/plateau_tournant"], "sol", 1, false], [["musee/monoplace", "musee/voiture_course"], "centre", 1, true], [["musee/limousine"], "centre", 1, false],
		[["musee/voiture_course", "musee/citadine"], "centre", 1, false], [["musee/citadine"], "mur", 1, false], [["musee/moteur"], "coin", 1, false],
		[["musee/pompe_essence"], "coin", 2, false], [["musee/plaques_emaillees"], "accroche", 2, false], [["musee/rail_spots"], "sol", 3, false]],
	"salle_espace": [[["musee/module_lunaire", "musee/capsule"], "centre", 1, true], [["musee/capsule"], "centre", 1, false], [["musee/combinaison"], "mur", 2, false],
		[["musee/moteur_fusee"], "coin", 1, false], [["musee/roche_lunaire"], "centre", 1, false], [["musee/satellite"], "sol", 1, false],
		[["musee/montgolfiere"], "sol", 1, false], [["musee/panneau_info"], "mur", 1, false], [["musee/projecteur"], "coin", 2, false]],
	"salle_marine": [[["musee/galion"], "mur", 1, true], [["musee/figure_proue"], "mur", 1, false], [["musee/scaphandre"], "coin", 1, false],
		[["musee/ancre"], "coin", 1, false], [["musee/lentille_phare"], "centre", 1, false], [["musee/canot"], "centre", 1, false],
		[["musee/aquarium"], "mur", 1, false], [["musee/barre_roue"], "accroche", 2, false], [["musee/rail_spots"], "sol", 2, false]],
	"salle_cinema": [[["musee/ecran_video"], "accroche", 1, true], [["musee/fauteuils_cine"], "remplir", 3, true], [["musee/camera_cinema"], "coin", 1, false],
		[["musee/projecteur_film"], "coin", 1, false], [["musee/decor_film"], "mur", 1, false], [["musee/costume_film"], "mur", 1, false],
		[["musee/statuette_cinema"], "coin", 1, false], [["musee/appareil_photo"], "mur", 1, false], [["musee/affiche_film"], "accroche", 3, false],
		[["musee/tirages_photo"], "accroche", 1, false], [["musee/clap"], "coin", 1, false]],
	"salle_sport": [[["musee/podium_sport"], "mur", 1, true], [["musee/champion"], "centre", 1, false], [["musee/velo_course"], "mur", 1, false],
		[["musee/coupe_sport"], "centre", 1, false], [["musee/medailles"], "centre", 1, false], [["musee/flambeau"], "coin", 1, false],
		[["musee/ballons"], "mur", 1, false], [["musee/maillot"], "accroche", 3, false], [["musee/skis"], "accroche", 1, false], [["musee/rail_spots"], "sol", 2, false]],
	"salle_mode": [[["musee/podium_defile"], "centre", 1, true], [["musee/robe_couture"], "mur", 2, false], [["musee/robe_bal"], "coin", 1, false],
		[["musee/tailleur"], "mur", 1, false], [["musee/smoking"], "mur", 1, false], [["musee/chapeaux"], "mur", 1, false],
		[["musee/chaussures"], "centre", 1, false], [["musee/machine_coudre"], "coin", 1, false], [["musee/rail_spots"], "sol", 3, false]],
	"salle_musique": [[["musee/piano"], "centre", 1, true], [["musee/harpe"], "coin", 1, false], [["musee/guitares"], "accroche", 1, false],
		[["musee/violon"], "centre", 1, false], [["musee/juke_box"], "mur", 1, false], [["musee/gramophone"], "coin", 1, false],
		[["musee/batterie"], "mur", 1, false], [["musee/orgue_barbarie"], "coin", 1, false], [["musee/cor_alpes"], "mur", 1, false], [["musee/rail_spots"], "sol", 2, false]],
	"salle_jouets": [[["musee/maison_poupee"], "mur", 1, true], [["musee/train_jouet"], "centre", 1, false], [["musee/cheval_bascule"], "coin", 1, false],
		[["musee/peluche"], "coin", 1, false], [["musee/borne_arcade"], "mur", 2, false], [["musee/consoles"], "mur", 1, false],
		[["musee/soldats_plomb"], "centre", 1, false], [["musee/robot_jouet"], "coin", 1, false], [["musee/toupies"], "coin", 1, false]],
	"salle_prehistoire": [[["musee/paroi_grotte"], "mur", 1, true], [["musee/hutte_mammouth"], "centre", 1, false], [["musee/chasseur"], "coin", 1, false],
		[["musee/foyer"], "centre", 1, false], [["musee/silex"], "centre", 1, false], [["musee/cranes"], "mur", 1, false],
		[["musee/statuette_prehisto"], "coin", 1, false], [["musee/menhir"], "coin", 1, false], [["musee/projecteur"], "coin", 1, false]],
	"salle_bd": [[["musee/planche_bd"], "accroche", 4, true], [["musee/grande_planche"], "accroche", 1, false], [["musee/heros_bd"], "coin", 2, false],
		[["musee/fusee_bd"], "centre", 1, false], [["musee/table_dessin"], "mur", 1, false], [["musee/coin_lecture"], "coin", 1, false],
		[["musee/bulle"], "accroche", 1, false], [["musee/rail_spots"], "sol", 2, false]],
	"salle_gastronomie": [[["musee/pressoir"], "centre", 1, true], [["musee/alambic"], "coin", 1, false], [["musee/tonneaux"], "mur", 2, false],
		[["musee/fourneau"], "mur", 1, false], [["musee/grands_crus"], "mur", 1, false], [["musee/chaudron_fromage"], "coin", 1, false],
		[["musee/affiche_pub"], "accroche", 2, false], [["musee/rail_spots"], "sol", 2, false]],
	"salle_expo": [[["musee/cimaise"], "centre", 2, true], [["musee/vitrine_centrale"], "centre", 1, false], [["musee/vitrine_murale"], "mur", 2, false],
		[["musee/panneau_info"], "mur", 1, false], [["musee/projecteur"], "coin", 2, false], [["musee/rail_spots"], "sol", 3, false]],
	"boutique_musee": [[["musee/caisse_boutique"], "centre", 1, true], [["musee/livres_art"], "remplir_mur", 2, true], [["musee/souvenirs"], "remplir", 3, false],
		[["musee/cartes_postales"], "coin", 1, false], [["contemporain/rayonnage"], "remplir_mur", 2, false]],
	"cafe_musee": [[["musee/comptoir_cafe"], "mur", 1, true], [["musee/table_cafe"], "remplir", 6, true], [["contemporain/grande_plante"], "coin", 2, false]],
}

static var _entries: Array = []


## Entrées de la bible des meubles (appelée par Meubles._build).
static func entries() -> Array:
	if _entries.is_empty():
		for tid in TYPES:
			var t: Dictionary = TYPES[tid]
			var e := {}
			for k in t:
				e[k] = t[k]
			var id := "%s/%s" % [STYLE, tid]
			e["id"] = id
			e["type"] = tid
			e["style"] = STYLE
			e["name"] = String(t.n)
			e["region"] = "monde"
			e["era"] = "contemporain"
			e["conf"] = int(t.get("conf", 0))
			e["couche"] = String(t.get("couche", "meuble"))
			e["mur"] = bool(t.get("mur", false))
			e["p"] = ["musee", String(t.fam)]
			var tags: Array = (t.get("tags", []) as Array).duplicate()
			tags.append("musee")
			if String(t.get("theme", "")) != "":
				tags.append("oeuvre")
			e["tags"] = tags
			e["places"] = t.get("places", [])
			e["theme"] = String(t.get("theme", ""))
			e["valeur"] = int(t.get("valeur", 0))
			e["prestige"] = int(t.get("prestige", 0))
			_entries.append(e)
	return _entries


static func is_musee(id: String) -> bool:
	return id.begins_with(STYLE + "/")


## Ids d'une famille (onglet du menu), dans l'ordre du catalogue.
static func of_famille(fam: String) -> Array:
	var out := []
	for tid in TYPES:
		if String(TYPES[tid].fam) == fam:
			out.append("%s/%s" % [STYLE, tid])
	if fam == "services":
		for id in SERVICES_BIBLE:
			if Meubles.has(id):
				out.append(id)
	return out


static func salle_name(fn: String) -> String:
	return String(SALLES[fn].name) if SALLES.has(fn) else ""


static func theme_name(t: String) -> String:
	return String(THEMES[t].name) if THEMES.has(t) else ""


static func count() -> int:
	return TYPES.size()


## Fonctions devinées des pièces d'un musée (Mobilier._guess_group) : le hall
## là où l'on entre, puis une salle par thème, les petites pièces en toilettes
## et réserve.
static func guess(mob: Mobilier, id: String, big: Array, small: Array, assign: Callable) -> void:
	var hall := {}
	var p: Dictionary = mob.pe.plans[id]
	for r in big + small:
		if int(r.e) != 0 or not hall.is_empty():
			continue
		for c in r.cells:
			for d in Mobilier.DIRS:
				var w: Dictionary = mob.wall_at(id, 0, c, d)
				if Mobilier.is_door(w) and not p.floors.has(Vector3i((c + d).x, 0, (c + d).y)):
					hall = r
					break
			if not hall.is_empty():
				break
	var themes := ["galerie_peinture", "salle_antiquites", "salle_dinosaures", "salle_sciences", "salle_histoire", "salle_sculpture", "salle_monde", "salle_nature", "salle_egypte", "salle_art_moderne",
		"salle_transports", "salle_cinema", "salle_musique", "salle_espace", "salle_sport", "salle_mode", "salle_marine", "salle_jouets", "salle_automobile",
		"salle_prehistoire", "salle_bd", "salle_gastronomie"]
	var i := 0
	var have_shop := false
	var have_cafe := false
	for r in big:
		if r == hall:
			assign.call(r, "hall_musee")
			continue
		if int(r.area) < 40 and not have_shop and i >= 2:
			assign.call(r, "boutique_musee")
			have_shop = true
			continue
		if int(r.area) < 40 and not have_cafe and i >= 3:
			assign.call(r, "cafe_musee")
			have_cafe = true
			continue
		var fn: String = themes[i % themes.size()]
		if fn == "salle_dinosaures" and int(r.area) < 60:
			fn = "salle_nature"
		assign.call(r, fn)
		i += 1
	var sdb := false
	for r in small:
		if r == hall:
			assign.call(r, "hall_musee")
		elif not sdb:
			assign.call(r, "sdb")
			sdb = true
		else:
			assign.call(r, "reserve")
	if hall.is_empty() and not big.is_empty():
		assign.call(big[big.size() - 1], "hall_musee")
