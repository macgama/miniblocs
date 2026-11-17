class_name ExpeditionsDonnees
extends RefCounted
## Données des expéditions (menu Loisirs → Expéditions, Maj+F4) : le bâtiment
## « Société des explorateurs », les destinations, les membres qu'on recrute,
## les provisions, les événements en route (avec leurs choix), les objets rares
## pour les musées, les animaux pour les zoos et les spécialistes pour les villes.
##
## Inspiré des grands récits d'exploration (et des jeux de gestion qui en font
## un mécanisme), sans copier aucun jeu : nos propres destinations, nos propres
## qualités (6), nos propres événements, avec une pointe d'humour.

# --- Qualités de l'équipe -------------------------------------------------------------------

## Les six qualités qui servent à franchir les épreuves.
const QUALITES := ["endurance", "medecine", "orientation", "diplomatie", "savoir", "debrouille"]
const QUALITES_NOMS := {
	"endurance": "Endurance", "medecine": "Médecine", "orientation": "Orientation",
	"diplomatie": "Diplomatie", "savoir": "Savoir", "debrouille": "Débrouillardise",
}

# --- Bâtiment -------------------------------------------------------------------------------

const CATEGORIE := "loisirs"
const TYPES := {
	"societe_explorateurs": {"name": "Société des explorateurs", "w": 22, "d": 16, "access": ["route"], "emplois": 5, "cost": 450_000,
		"annee": 1800, "expedition": true, "visiteurs": 80,
		"metiers": [["conservateur", 2], ["cadre", 3]],
		"desc": "Salle des cartes, bibliothèque et cabinet de curiosités. Elle prépare une expédition à la fois, et expose ce que les explorateurs rapportent."},
}

# --- Moyens de transport selon l'époque -------------------------------------------------------

## [année maximale, nom, facteur sur la durée du voyage, coût par jour et par membre].
const TRANSPORTS := [
	[1839, "en voilier", 1.5, 60.0],
	[1909, "en vapeur et en train", 1.0, 90.0],
	[1949, "en paquebot, en train et en camion", 0.7, 120.0],
	[99999, "en avion, puis en 4×4", 0.35, 180.0],
]

# --- Membres ---------------------------------------------------------------------------------

## Ce qu'apporte chaque membre (qualités), son salaire par jour d'expédition, et l'année où
## le métier apparaît. "max" : combien on peut en emmener.
const MEMBRES := {
	"guide": {"nom": "Guide", "q": {"orientation": 3, "endurance": 1}, "salaire": 180.0, "annee": 0, "max": 2,
		"desc": "Connaît les pistes, les gués et les raccourcis qui n'en sont pas."},
	"medecin": {"nom": "Médecin", "q": {"medecine": 3}, "salaire": 320.0, "annee": 0, "max": 1,
		"desc": "Soigne les fièvres, les ampoules et les chevilles foulées. Ralentit l'usure de l'équipe."},
	"naturaliste": {"nom": "Naturaliste", "q": {"savoir": 2, "medecine": 1}, "salaire": 260.0, "annee": 0, "max": 2,
		"desc": "Indispensable pour ramener des animaux vivants et en bonne santé."},
	"archeologue": {"nom": "Archéologue", "q": {"savoir": 3}, "salaire": 280.0, "annee": 0, "max": 2,
		"desc": "Sans lui, on prend une amphore pour un pot de fleurs. Indispensable pour les pièces de musée."},
	"interprete": {"nom": "Interprète", "q": {"diplomatie": 3}, "salaire": 200.0, "annee": 0, "max": 1,
		"desc": "Parle cinq langues et en comprend sept, surtout quand on parle de lui."},
	"porteur": {"nom": "Porteur", "q": {"endurance": 2, "debrouille": 1}, "salaire": 90.0, "annee": 0, "max": 4,
		"desc": "Porte trente kilos et le moral de l'équipe."},
	"alpiniste": {"nom": "Alpiniste", "q": {"endurance": 3, "orientation": 1}, "salaire": 240.0, "annee": 1850, "max": 2,
		"desc": "Cordes, piolets, et une confiance inquiétante dans les ponts de neige."},
	"cuisinier": {"nom": "Cuisinier", "q": {"endurance": 1, "debrouille": 1}, "salaire": 140.0, "annee": 0, "max": 1, "moral": 1.2,
		"desc": "Un bon repas chaud vaut trois discours du chef. Le moral baisse moins vite."},
	"photographe": {"nom": "Photographe", "q": {"savoir": 1, "diplomatie": 1}, "salaire": 220.0, "annee": 1860, "max": 1, "recit": 1.5,
		"desc": "Ses images font la une de la gazette : l'expédition rapporte plus de renommée."},
	"mecanicien": {"nom": "Mécanicien", "q": {"debrouille": 3}, "salaire": 230.0, "annee": 1900, "max": 1,
		"desc": "Répare un moteur avec un fil de fer et un juron."},
	"pilote": {"nom": "Pilote", "q": {"orientation": 2, "debrouille": 1}, "salaire": 380.0, "annee": 1920, "max": 1, "trajet": 0.8,
		"desc": "Avec lui, le voyage dure 20 % de moins."},
}
const MEMBRES_ORDRE := ["guide", "medecin", "naturaliste", "archeologue", "interprete", "porteur", "alpiniste", "cuisinier",
	"photographe", "mecanicien", "pilote"]
## Taille maximale d'une équipe (chef compris).
const EQUIPE_MAX := 9

# --- Provisions et matériel --------------------------------------------------------------------

const PROVISIONS := {
	"vivres": {"nom": "Vivres en plus", "q": {"endurance": 2}, "prix": 25_000, "moral": 1.15,
		"desc": "Conserves, biscuits de mer et chocolat : le moral tient mieux."},
	"pharmacie": {"nom": "Pharmacie de voyage", "q": {"medecine": 2}, "prix": 30_000,
		"desc": "Quinine, bandages, sels. Moins de malades."},
	"instruments": {"nom": "Cartes et instruments", "q": {"orientation": 2}, "prix": 20_000,
		"desc": "Boussole, sextant, chronomètre. On se perd moins, et on le sait plus vite."},
	"cadeaux": {"nom": "Cadeaux pour les hôtes", "q": {"diplomatie": 2}, "prix": 15_000,
		"desc": "Tissus, couteaux, livres : on est mieux reçu partout."},
	"fouilles": {"nom": "Matériel de fouille", "q": {"savoir": 1}, "prix": 35_000, "butin": "objet",
		"desc": "Pelles, pinceaux et caisses rembourrées : plus de chances de rapporter des pièces de musée."},
	"cages": {"nom": "Caisses et cages de transport", "prix": 40_000, "butin": "animal",
		"desc": "Sans elles, impossible de ramener un animal vivant."},
	"grand_froid": {"nom": "Équipement grand froid", "prix": 45_000, "climat": "froid",
		"desc": "Fourrures, tentes doubles, lunettes de glacier. Indispensable au froid."},
	"tropiques": {"nom": "Équipement des tropiques", "prix": 30_000, "climat": "chaud",
		"desc": "Moustiquaires, casques, gourdes. Indispensable au chaud et sous les tropiques."},
	"cordes": {"nom": "Cordes et piolets", "prix": 25_000, "climat": "montagne",
		"desc": "Pour la haute montagne : sans eux, chaque col est une épreuve."},
}
const PROVISIONS_ORDRE := ["vivres", "pharmacie", "instruments", "cadeaux", "fouilles", "cages", "grand_froid", "tropiques", "cordes"]
## Climat d'une destination → matériel qui l'évite.
const CLIMAT_MATERIEL := {"froid": "grand_froid", "chaud": "tropiques", "tropical": "tropiques", "desert": "tropiques", "montagne": "cordes"}
const CLIMAT_NOMS := {"froid": "grand froid", "chaud": "chaleur", "tropical": "tropiques", "desert": "désert", "montagne": "haute montagne", "tempere": "tempéré"}

# --- Destinations ------------------------------------------------------------------------------

## "trajet" et "jours" : jours de voyage (à l'époque des vapeurs) et d'exploration ;
## "diff" : 1 à 5 ; "themes" : ce qu'on y trouve ; "faune" : espèces du zoo (ZooEspeces) ;
## "lat"/"lon" : pour la carte du panneau ; "annee" : accessible à partir de.
const DESTINATIONS := {
	"nil": {"nom": "Vallée du Nil", "pays": "Égypte", "climat": "desert", "diff": 2, "trajet": 12, "jours": 16, "cout": 120_000,
		"themes": ["objet", "animal"], "faune": ["crocodile", "dromadaire", "flamant"], "lat": 25.7, "lon": 32.6, "annee": 0,
		"desc": "Temples ensablés, tombes oubliées et crocodiles qui ne le sont pas."},
	"egee": {"nom": "Îles de la mer Égée", "pays": "Grèce", "climat": "tempere", "diff": 1, "trajet": 6, "jours": 12, "cout": 70_000,
		"themes": ["objet"], "faune": [], "lat": 37.4, "lon": 25.3, "annee": 0,
		"desc": "Une expédition idéale pour débuter : du soleil, des ruines, et des chèvres partout."},
	"mesopotamie": {"nom": "Mésopotamie", "pays": "entre le Tigre et l'Euphrate", "climat": "desert", "diff": 3, "trajet": 14, "jours": 18, "cout": 150_000,
		"themes": ["objet", "savoir"], "faune": ["dromadaire"], "lat": 32.5, "lon": 44.4, "annee": 0,
		"desc": "Sous chaque colline, une ville de briques vieille de cinq mille ans."},
	"savane": {"nom": "Savane d'Afrique de l'Est", "pays": "Kenya et Tanzanie", "climat": "chaud", "diff": 2, "trajet": 18, "jours": 18, "cout": 160_000,
		"themes": ["animal", "savoir"], "faune": ["lion", "elephant", "girafe", "zebre", "rhinoceros", "hippopotame", "autruche"],
		"lat": -2.3, "lon": 34.8, "annee": 0, "desc": "Les grandes plaines, leurs troupeaux et leurs fauves."},
	"congo": {"nom": "Forêts du bassin du Congo", "pays": "Afrique centrale", "climat": "tropical", "diff": 4, "trajet": 20, "jours": 22, "cout": 190_000,
		"themes": ["animal", "savoir"], "faune": ["gorille", "chimpanze"], "lat": -0.5, "lon": 23.0, "annee": 0,
		"desc": "La forêt la plus dense d'Afrique, où même la boussole hésite."},
	"madagascar": {"nom": "Madagascar", "pays": "océan Indien", "climat": "tropical", "diff": 3, "trajet": 22, "jours": 16, "cout": 170_000,
		"themes": ["animal", "savoir"], "faune": ["lemurien", "crocodile"], "lat": -19.0, "lon": 46.8, "annee": 0,
		"desc": "Une île où presque tout ce qui vit n'existe nulle part ailleurs."},
	"bengale": {"nom": "Jungles du Bengale", "pays": "Inde", "climat": "tropical", "diff": 3, "trajet": 24, "jours": 16, "cout": 170_000,
		"themes": ["animal", "objet"], "faune": ["tigre"], "lat": 22.0, "lon": 89.0, "annee": 0,
		"desc": "Mangroves, temples dans les racines et un tigre qui vous a vu avant vous."},
	"himalaya": {"nom": "Himalaya", "pays": "Népal et Tibet", "climat": "montagne", "diff": 5, "trajet": 26, "jours": 24, "cout": 240_000,
		"themes": ["savoir", "animal", "objet"], "faune": ["panda_roux", "yack", "panda"], "lat": 28.0, "lon": 86.9, "annee": 0,
		"desc": "Monastères suspendus, cols à 5 000 m et des sages qui ont réponse à presque tout."},
	"route_soie": {"nom": "Route de la soie", "pays": "Asie centrale", "climat": "desert", "diff": 3, "trajet": 22, "jours": 20, "cout": 180_000,
		"themes": ["objet", "savoir"], "faune": ["yack", "dromadaire"], "lat": 39.6, "lon": 66.9, "annee": 0,
		"desc": "Caravansérails, cités de faïence bleue et marchands qui négocient même le prix du thé."},
	"borneo": {"nom": "Bornéo", "pays": "Asie du Sud-Est", "climat": "tropical", "diff": 4, "trajet": 30, "jours": 18, "cout": 200_000,
		"themes": ["animal", "savoir"], "faune": ["orang_outan", "tapir"], "lat": 1.0, "lon": 114.0, "annee": 0,
		"desc": "Des arbres de soixante mètres, et quelqu'un de roux qui vous observe d'en haut."},
	"outback": {"nom": "Cœur de l'Australie", "pays": "Australie", "climat": "desert", "diff": 3, "trajet": 34, "jours": 16, "cout": 210_000,
		"themes": ["animal", "objet"], "faune": ["kangourou", "koala"], "lat": -23.7, "lon": 133.9, "annee": 1830,
		"desc": "Terre rouge, ciel immense et des voisins qui sautent."},
	"galapagos": {"nom": "Galápagos et côte du Pacifique", "pays": "Équateur et Pérou", "climat": "chaud", "diff": 3, "trajet": 32, "jours": 14, "cout": 200_000,
		"themes": ["animal", "savoir"], "faune": ["tortue_geante", "otarie", "manchot"], "lat": -0.7, "lon": -90.3, "annee": 0,
		"desc": "Des tortues plus vieilles que la ville et des pinsons qui font réfléchir."},
	"andes": {"nom": "Cordillère des Andes", "pays": "Pérou et Bolivie", "climat": "montagne", "diff": 4, "trajet": 30, "jours": 20, "cout": 220_000,
		"themes": ["objet", "animal"], "faune": ["lama"], "lat": -13.2, "lon": -72.5, "annee": 0,
		"desc": "Cités de pierre dans les nuages, terrasses à pic et lamas qui crachent sur les retardataires."},
	"yucatan": {"nom": "Yucatán", "pays": "Mexique", "climat": "tropical", "diff": 3, "trajet": 24, "jours": 18, "cout": 180_000,
		"themes": ["objet"], "faune": [], "lat": 20.7, "lon": -88.6, "annee": 0,
		"desc": "Des pyramides sous la jungle et des puits sacrés d'un bleu irréel."},
	"arctique": {"nom": "Grand Nord", "pays": "Groenland et Svalbard", "climat": "froid", "diff": 4, "trajet": 16, "jours": 18, "cout": 210_000,
		"themes": ["animal", "savoir"], "faune": ["ours_polaire", "renne", "loup"], "lat": 78.2, "lon": 15.6, "annee": 0,
		"desc": "Six mois de jour, six mois de nuit et un ours qui ne fait pas la différence."},
	"siberie": {"nom": "Sibérie et Kamtchatka", "pays": "Russie", "climat": "froid", "diff": 4, "trajet": 26, "jours": 20, "cout": 200_000,
		"themes": ["animal", "objet", "savoir"], "faune": ["ours_brun", "renne", "loup"], "lat": 56.0, "lon": 160.0, "annee": 0,
		"desc": "Volcans, toundra et mammouths gelés que le dégel rend au jour."},
	"antarctique": {"nom": "Antarctique", "pays": "continent blanc", "climat": "froid", "diff": 5, "trajet": 40, "jours": 22, "cout": 320_000,
		"themes": ["savoir", "objet"], "faune": [], "lat": -77.8, "lon": 166.7, "annee": 1895,
		"desc": "Le bout du monde. Les scientifiques y vont pour la glace, et en reviennent avec des histoires."},
}
const DESTINATIONS_ORDRE := ["egee", "nil", "mesopotamie", "savane", "madagascar", "congo", "bengale", "route_soie", "himalaya",
	"borneo", "outback", "galapagos", "andes", "yucatan", "arctique", "siberie", "antarctique"]

# --- Objets rares (pour les musées) --------------------------------------------------------------

## "theme" : thème de musée (MuseeObjets), "prestige" : ajouté au musée qui l'expose,
## "valeur" : prix aux enchères (€), "rare" : 1 (courant) à 3 (exceptionnel).
const OBJETS := {
	"scarabee_or": {"nom": "Scarabée d'or d'un scribe", "dest": "nil", "theme": "antiquite", "prestige": 30.0, "valeur": 280_000, "rare": 1},
	"barque_solaire": {"nom": "Maquette de barque solaire", "dest": "nil", "theme": "antiquite", "prestige": 55.0, "valeur": 650_000, "rare": 2},
	"masque_pharaon": {"nom": "Masque funéraire d'un prince", "dest": "nil", "theme": "antiquite", "prestige": 120.0, "valeur": 3_200_000, "rare": 3},
	"amphore_peinte": {"nom": "Amphore à figures noires", "dest": "egee", "theme": "antiquite", "prestige": 28.0, "valeur": 240_000, "rare": 1},
	"kouros": {"nom": "Statue de jeune homme en marbre", "dest": "egee", "theme": "art", "prestige": 70.0, "valeur": 1_400_000, "rare": 2},
	"mecanisme_bronze": {"nom": "Mécanisme astronomique en bronze", "dest": "egee", "theme": "sciences", "prestige": 110.0, "valeur": 2_600_000, "rare": 3},
	"tablette_cuneiforme": {"nom": "Tablette en écriture cunéiforme", "dest": "mesopotamie", "theme": "histoire", "prestige": 32.0, "valeur": 260_000, "rare": 1},
	"taureau_aile": {"nom": "Bas-relief du taureau ailé", "dest": "mesopotamie", "theme": "antiquite", "prestige": 85.0, "valeur": 1_900_000, "rare": 2},
	"lyre_ur": {"nom": "Lyre royale à tête de taureau", "dest": "mesopotamie", "theme": "musique", "prestige": 95.0, "valeur": 2_100_000, "rare": 3},
	"bouclier_masai": {"nom": "Bouclier de cuir peint", "dest": "savane", "theme": "monde", "prestige": 24.0, "valeur": 120_000, "rare": 1},
	"crane_hominide": {"nom": "Moulage d'un crâne d'hominidé", "dest": "savane", "theme": "prehistoire", "prestige": 75.0, "valeur": 900_000, "rare": 2},
	"masque_kota": {"nom": "Figure de reliquaire en cuivre", "dest": "congo", "theme": "art", "prestige": 60.0, "valeur": 1_100_000, "rare": 2},
	"herbier_congo": {"nom": "Herbier de plantes médicinales", "dest": "congo", "theme": "nature", "prestige": 30.0, "valeur": 150_000, "rare": 1},
	"oeuf_aepyornis": {"nom": "Œuf d'oiseau-éléphant", "dest": "madagascar", "theme": "nature", "prestige": 65.0, "valeur": 700_000, "rare": 2},
	"pirogue_sculptee": {"nom": "Proue de pirogue sculptée", "dest": "madagascar", "theme": "marine", "prestige": 26.0, "valeur": 140_000, "rare": 1},
	"bronze_shiva": {"nom": "Bronze du dieu dansant", "dest": "bengale", "theme": "art", "prestige": 80.0, "valeur": 1_600_000, "rare": 2},
	"manuscrit_palme": {"nom": "Manuscrit sur feuilles de palme", "dest": "bengale", "theme": "histoire", "prestige": 34.0, "valeur": 300_000, "rare": 1},
	"thangka": {"nom": "Peinture sur soie d'un monastère", "dest": "himalaya", "theme": "art", "prestige": 45.0, "valeur": 500_000, "rare": 1},
	"carte_sommets": {"nom": "Carte des sommets de 8 000 m", "dest": "himalaya", "theme": "sciences", "prestige": 40.0, "valeur": 260_000, "rare": 1},
	"bol_chante": {"nom": "Bol chantant en sept métaux", "dest": "himalaya", "theme": "musique", "prestige": 36.0, "valeur": 180_000, "rare": 1},
	"astrolabe_samarcande": {"nom": "Astrolabe de Samarcande", "dest": "route_soie", "theme": "sciences", "prestige": 90.0, "valeur": 2_000_000, "rare": 3},
	"soie_brodee": {"nom": "Rouleau de soie brodée", "dest": "route_soie", "theme": "mode", "prestige": 38.0, "valeur": 420_000, "rare": 1},
	"carreau_faience": {"nom": "Carreaux de faïence bleue", "dest": "route_soie", "theme": "art", "prestige": 30.0, "valeur": 260_000, "rare": 1},
	"sarbacane": {"nom": "Sarbacane et carquois gravés", "dest": "borneo", "theme": "monde", "prestige": 24.0, "valeur": 90_000, "rare": 1},
	"papillon_geant": {"nom": "Collection de papillons géants", "dest": "borneo", "theme": "nature", "prestige": 40.0, "valeur": 220_000, "rare": 1},
	"peinture_ecorce": {"nom": "Peinture sur écorce", "dest": "outback", "theme": "art", "prestige": 44.0, "valeur": 380_000, "rare": 1},
	"boomerang_ancien": {"nom": "Boomerang de chasse ancien", "dest": "outback", "theme": "sport", "prestige": 22.0, "valeur": 80_000, "rare": 1},
	"carnet_pinsons": {"nom": "Carnet de croquis des pinsons", "dest": "galapagos", "theme": "sciences", "prestige": 85.0, "valeur": 1_500_000, "rare": 3},
	"carapace": {"nom": "Carapace de tortue géante", "dest": "galapagos", "theme": "nature", "prestige": 34.0, "valeur": 160_000, "rare": 1},
	"quipu": {"nom": "Cordelettes à nœuds comptables", "dest": "andes", "theme": "histoire", "prestige": 48.0, "valeur": 520_000, "rare": 2},
	"lama_or": {"nom": "Statuette de lama en or", "dest": "andes", "theme": "antiquite", "prestige": 70.0, "valeur": 1_300_000, "rare": 2},
	"textile_paracas": {"nom": "Manteau brodé de deux mille ans", "dest": "andes", "theme": "mode", "prestige": 60.0, "valeur": 900_000, "rare": 2},
	"calendrier_maya": {"nom": "Disque de calendrier sculpté", "dest": "yucatan", "theme": "sciences", "prestige": 75.0, "valeur": 1_400_000, "rare": 2},
	"masque_jade": {"nom": "Masque de jade", "dest": "yucatan", "theme": "antiquite", "prestige": 110.0, "valeur": 2_800_000, "rare": 3},
	"balle_caoutchouc": {"nom": "Balle du jeu de pelote", "dest": "yucatan", "theme": "sport", "prestige": 30.0, "valeur": 150_000, "rare": 1},
	"kayak_peaux": {"nom": "Kayak en peaux cousues", "dest": "arctique", "theme": "marine", "prestige": 36.0, "valeur": 200_000, "rare": 1},
	"meteorite": {"nom": "Météorite de fer", "dest": "arctique", "theme": "espace", "prestige": 80.0, "valeur": 1_200_000, "rare": 2},
	"defense_mammouth": {"nom": "Défense de mammouth", "dest": "siberie", "theme": "prehistoire", "prestige": 65.0, "valeur": 800_000, "rare": 2},
	"tambour_chamane": {"nom": "Tambour de chamane", "dest": "siberie", "theme": "musique", "prestige": 32.0, "valeur": 160_000, "rare": 1},
	"carotte_glace": {"nom": "Carotte de glace de 100 000 ans", "dest": "antarctique", "theme": "sciences", "prestige": 70.0, "valeur": 600_000, "rare": 2},
	"traineau_polaire": {"nom": "Traîneau d'une expédition polaire", "dest": "antarctique", "theme": "transports", "prestige": 55.0, "valeur": 450_000, "rare": 2},
	"meteorite_lune": {"nom": "Météorite venue de la Lune", "dest": "antarctique", "theme": "espace", "prestige": 115.0, "valeur": 2_400_000, "rare": 3},
}

# --- Spécialistes (pour les villes) --------------------------------------------------------------

## "effets" : effet → valeur, lus par les autres systèmes (Expeditions.facteur) :
## - "chantiers" (+x : chantiers des bâtiments plus rapides), "agriculture" (+x : rendement),
##   "tourisme" (+x : attrait), "musee" (+x : prestige des musées de la ville),
##   "sante" (−x : risques pour la santé), "avis" (+ satisfaction, thème loisirs),
##   "expeditions" (+x à toutes les qualités des prochaines expéditions).
## "dest" : où on a le plus de chances de le rencontrer ("" : partout).
const SPECIALISTES := {
	"ingenieure_ponts": {"nom": "Ingénieure des ponts", "effets": {"chantiers": 0.15}, "dest": "",
		"desc": "Revenue d'un chantier de chemin de fer au bout du monde : les chantiers de la ville vont 15 % plus vite."},
	"maitre_batisseur": {"nom": "Maître bâtisseur", "effets": {"chantiers": 0.10}, "dest": "andes",
		"desc": "Sait assembler des pierres sans mortier : chantiers 10 % plus rapides."},
	"agronome": {"nom": "Agronome", "effets": {"agriculture": 0.12}, "dest": "mesopotamie",
		"desc": "A étudié les canaux d'irrigation les plus anciens du monde : récoltes +12 %."},
	"botaniste": {"nom": "Botaniste", "effets": {"agriculture": 0.08, "sante": 0.02}, "dest": "congo",
		"desc": "Rapporte des semences robustes et des plantes qui soignent : récoltes +8 %, un peu moins de malades."},
	"medecin_tropiques": {"nom": "Médecin des tropiques", "effets": {"sante": 0.06}, "dest": "borneo",
		"desc": "A soigné toutes les fièvres connues, et quelques inconnues : beaucoup moins de malades en ville."},
	"herboriste": {"nom": "Herboriste des montagnes", "effets": {"sante": 0.04}, "dest": "himalaya",
		"desc": "Ses tisanes ne guérissent pas tout, mais presque : moins de malades."},
	"guide_conferencier": {"nom": "Explorateur conférencier", "effets": {"tourisme": 0.12}, "dest": "",
		"desc": "Ses conférences font salle comble et donnent envie de venir : attrait touristique +12 %."},
	"photographe_renom": {"nom": "Photographe de renom", "effets": {"tourisme": 0.08, "avis": 1.0}, "dest": "savane",
		"desc": "Ses images de la ville font le tour du monde : attrait +8 %, et les habitants en sont fiers."},
	"cuisinier_epices": {"nom": "Cuisinier des épices", "effets": {"tourisme": 0.06, "avis": 1.0}, "dest": "route_soie",
		"desc": "Ouvre une table où l'on vient de loin : attrait +6 %, et les habitants se régalent."},
	"conservatrice": {"nom": "Conservatrice de musée", "effets": {"musee": 0.20}, "dest": "nil",
		"desc": "Sait mettre en scène une collection : prestige des musées de la ville +20 %."},
	"epigraphiste": {"nom": "Déchiffreur d'écritures", "effets": {"musee": 0.12}, "dest": "yucatan",
		"desc": "Lit les écritures oubliées et écrit des cartels passionnants : prestige des musées +12 %."},
	"cartographe": {"nom": "Cartographe", "effets": {"expeditions": 1.0}, "dest": "arctique",
		"desc": "Conseille les prochaines expéditions : +1 à toutes leurs qualités."},
	"vieux_marin": {"nom": "Vieux loup de mer", "effets": {"expeditions": 1.0}, "dest": "galapagos",
		"desc": "A fait trois fois le tour du monde et le raconte à qui veut : +1 aux qualités des expéditions."},
	"conteuse": {"nom": "Conteuse", "effets": {"avis": 1.5}, "dest": "siberie",
		"desc": "Ses veillées au coin du feu sont le meilleur moment de la semaine : les habitants sont plus heureux."},
}
## Spécialistes par ville au plus.
const SPECIALISTES_PAR_VILLE := 3

# --- Événements en route ------------------------------------------------------------------------

## Chaque événement propose 2 ou 3 choix. Un choix a une qualité ("q", "" = sans épreuve),
## un seuil (ajouté à la difficulté de la destination), et deux issues : "ok" et "ko".
## Effets : "m" (moral), "s" (santé), "j" (jours en plus), "e" (euros, négatif = dépense),
## "b" (trouvaille en plus : "objet", "animal", "specialiste" ou "*"), "r" (renommée),
## "perte" (un membre rentre au pays). "climats" : où il peut arriver ([] = partout).
const EVENEMENTS := {
	"riviere_crue": {"titre": "Rivière en crue", "climats": ["tropical", "chaud", "tempere"],
		"texte": "La rivière a doublé de largeur dans la nuit. Le gué d'hier est devenu un fleuve.",
		"choix": [
			{"t": "Chercher un passage plus haut", "q": "orientation", "seuil": 4, "ok": {"j": 1, "m": 2}, "ko": {"j": 3, "m": -8}},
			{"t": "Construire un radeau", "q": "debrouille", "seuil": 5, "ok": {"m": 6}, "ko": {"s": -12, "m": -6}},
			{"t": "Attendre la décrue", "q": "", "ok": {"j": 4, "m": -4}},
		]},
	"fievre": {"titre": "Une fièvre dans le camp", "climats": ["tropical", "chaud", "desert"],
		"texte": "Trois porteurs grelottent sous trente degrés. Le médecin fronce les sourcils, ce qui n'est jamais bon signe.",
		"choix": [
			{"t": "Soigner sur place", "q": "medecine", "seuil": 4, "ok": {"s": 6, "j": 1}, "ko": {"s": -15, "perte": true}},
			{"t": "Continuer en portant les malades", "q": "endurance", "seuil": 6, "ok": {"m": -2}, "ko": {"s": -18, "m": -10}},
		]},
	"village_accueil": {"titre": "Un village accueillant", "climats": [],
		"texte": "Les habitants d'un village vous invitent à partager leur repas. Leur chef semble connaître la région mieux que vos cartes.",
		"choix": [
			{"t": "Accepter et échanger des cadeaux", "q": "diplomatie", "seuil": 3, "ok": {"m": 12, "s": 8, "b": "*"}, "ko": {"m": 4, "e": -8_000}},
			{"t": "Demander un guide", "q": "diplomatie", "seuil": 5, "ok": {"j": -2, "m": 6}, "ko": {"e": -15_000}},
			{"t": "Remercier poliment et repartir", "q": "", "ok": {"m": -2}},
		]},
	"tempete_sable": {"titre": "Tempête de sable", "climats": ["desert"],
		"texte": "Un mur ocre avance à l'horizon. Dans dix minutes, on ne verra plus ses pieds.",
		"choix": [
			{"t": "S'abriter derrière les dunes", "q": "debrouille", "seuil": 4, "ok": {"j": 1}, "ko": {"s": -10, "j": 2}},
			{"t": "Marcher à la boussole", "q": "orientation", "seuil": 6, "ok": {"m": 6}, "ko": {"j": 4, "m": -12}},
		]},
	"tempete_neige": {"titre": "Blizzard", "climats": ["froid", "montagne"],
		"texte": "Le vent hurle à cent kilomètres à l'heure. La tente du cuisinier est partie faire sa propre expédition.",
		"choix": [
			{"t": "Creuser un abri dans la neige", "q": "endurance", "seuil": 5, "ok": {"j": 2, "m": 4}, "ko": {"s": -16, "j": 2}},
			{"t": "Rebrousser chemin jusqu'au dernier camp", "q": "orientation", "seuil": 4, "ok": {"j": 3}, "ko": {"j": 4, "s": -8, "m": -8}},
		]},
	"crevasse": {"titre": "Une crevasse", "climats": ["froid", "montagne"],
		"texte": "Un porteur a disparu jusqu'à la taille dans un pont de neige. Il dit que tout va bien. Sa voix dit le contraire.",
		"choix": [
			{"t": "Le hisser à la corde", "q": "endurance", "seuil": 5, "ok": {"m": 8}, "ko": {"perte": true, "m": -10}},
			{"t": "Faire le tour par la moraine", "q": "orientation", "seuil": 3, "ok": {"j": 2}, "ko": {"j": 3, "s": -6}},
		]},
	"ruines": {"titre": "Des ruines sous la végétation", "climats": [], "theme": "objet",
		"texte": "Le guide écarte des lianes : un escalier de pierre descend sous la colline.",
		"choix": [
			{"t": "Fouiller avec soin", "q": "savoir", "seuil": 5, "ok": {"b": "objet", "j": 2, "r": 10}, "ko": {"j": 2, "m": -4}},
			{"t": "Faire un relevé et repartir", "q": "savoir", "seuil": 2, "ok": {"r": 6}, "ko": {"m": -2}},
			{"t": "Ne pas déranger les esprits du lieu", "q": "", "ok": {"m": 2}},
		]},
	"marchand": {"titre": "Un marchand ambulant", "climats": [],
		"texte": "Un marchand propose « le plus bel objet de toute la région, à un prix d'ami ». Il a beaucoup d'amis, apparemment.",
		"choix": [
			{"t": "Examiner l'objet de près", "q": "savoir", "seuil": 5, "ok": {"b": "objet", "e": -40_000}, "ko": {"e": -40_000, "m": -6}},
			{"t": "Marchander longuement", "q": "diplomatie", "seuil": 6, "ok": {"b": "objet", "e": -15_000}, "ko": {"m": -2}},
			{"t": "Passer son chemin", "q": "", "ok": {}},
		]},
	"animal_blesse": {"titre": "Un animal blessé", "climats": [], "theme": "animal",
		"texte": "Un jeune animal s'est pris la patte dans des racines. Sa mère n'est pas en vue. Pour l'instant.",
		"choix": [
			{"t": "Le soigner et l'emmener", "q": "medecine", "seuil": 4, "ok": {"b": "animal", "m": 8}, "ko": {"s": -8, "m": -4}},
			{"t": "Le libérer et s'éloigner vite", "q": "debrouille", "seuil": 3, "ok": {"m": 6, "r": 4}, "ko": {"s": -10}},
		]},
	"troupeau": {"titre": "Un grand troupeau", "climats": ["chaud", "froid", "tempere"], "theme": "animal",
		"texte": "Des milliers de bêtes traversent la plaine. Le naturaliste en pleure de joie, les porteurs aussi, mais pas pour la même raison.",
		"choix": [
			{"t": "Observer et approcher prudemment", "q": "savoir", "seuil": 5, "ok": {"b": "animal", "r": 8}, "ko": {"s": -10, "j": 1}},
			{"t": "Attendre que le troupeau passe", "q": "", "ok": {"j": 2, "r": 3}},
		]},
	"guide_perdu": {"titre": "Le guide est perdu", "climats": [],
		"texte": "Le guide jure que la carte est fausse. La carte, elle, ne dit rien.",
		"choix": [
			{"t": "Faire le point aux étoiles", "q": "orientation", "seuil": 5, "ok": {"m": 4}, "ko": {"j": 3, "m": -8}},
			{"t": "Demander son chemin", "q": "diplomatie", "seuil": 4, "ok": {"j": -1}, "ko": {"j": 2, "e": -5_000}},
		]},
	"vol_nuit": {"titre": "Des vivres disparus", "climats": [],
		"texte": "Au matin, la moitié des vivres a disparu. Des traces de pattes, ou de pieds ? Le débat fait rage.",
		"choix": [
			{"t": "Chasser et cueillir", "q": "debrouille", "seuil": 4, "ok": {"m": 2}, "ko": {"s": -10, "m": -8}},
			{"t": "Racheter au prochain comptoir", "q": "diplomatie", "seuil": 3, "ok": {"e": -12_000}, "ko": {"e": -25_000, "m": -4}},
		]},
	"savant_local": {"titre": "Un savant du pays", "climats": [], "theme": "savoir",
		"texte": "Un vieil érudit vous reçoit au milieu de ses livres. Il parle de tout, et surtout de ce que vous ignorez.",
		"choix": [
			{"t": "L'écouter des jours entiers", "q": "savoir", "seuil": 4, "ok": {"b": "specialiste", "j": 3}, "ko": {"j": 3, "r": 4}},
			{"t": "Lui proposer de rejoindre la ville", "q": "diplomatie", "seuil": 7, "ok": {"b": "specialiste"}, "ko": {"m": -4}},
		]},
	"col_ferme": {"titre": "Un col fermé", "climats": ["montagne"],
		"texte": "Le col est barré par une coulée de pierres fraîches. On entend encore rouler les dernières.",
		"choix": [
			{"t": "Escalader la coulée", "q": "endurance", "seuil": 6, "ok": {"m": 6}, "ko": {"perte": true, "s": -12}},
			{"t": "Prendre la vallée voisine", "q": "orientation", "seuil": 4, "ok": {"j": 2}, "ko": {"j": 5, "m": -6}},
		]},
	"moteur_panne": {"titre": "Panne en pleine piste", "climats": [], "annee": 1900,
		"texte": "Le moteur tousse, crache et s'arrête. Le silence qui suit est très instructif.",
		"choix": [
			{"t": "Réparer avec les moyens du bord", "q": "debrouille", "seuil": 5, "ok": {"m": 4}, "ko": {"j": 4, "e": -20_000}},
			{"t": "Télégraphier pour une pièce", "q": "", "ok": {"j": 5, "e": -12_000}},
		]},
	"fete_locale": {"titre": "Une grande fête", "climats": [],
		"texte": "Vous arrivez en pleine fête. Il y a de la musique, des danses et un plat dont personne n'ose demander la recette.",
		"choix": [
			{"t": "Participer", "q": "diplomatie", "seuil": 3, "ok": {"m": 14, "r": 6}, "ko": {"m": 4, "s": -4}},
			{"t": "Profiter du calme pour se reposer", "q": "", "ok": {"s": 8, "j": 1}},
		]},
	"grotte_ornee": {"titre": "Une grotte ornée", "climats": [], "theme": "objet",
		"texte": "Au fond d'une grotte, des mains peintes sur la paroi. Tout le monde se tait.",
		"choix": [
			{"t": "Relever et photographier", "q": "savoir", "seuil": 4, "ok": {"r": 16}, "ko": {"r": 6}},
			{"t": "Chercher des objets dans les éboulis", "q": "savoir", "seuil": 6, "ok": {"b": "objet"}, "ko": {"s": -6, "m": -4}},
		]},
	"serpent": {"titre": "Un serpent dans la tente", "climats": ["tropical", "chaud", "desert"],
		"texte": "Le cuisinier a trouvé un serpent dans sa marmite. Le serpent a l'air aussi surpris que lui.",
		"choix": [
			{"t": "Le faire sortir doucement", "q": "debrouille", "seuil": 3, "ok": {"m": 4}, "ko": {"s": -12}},
			{"t": "Appeler le naturaliste", "q": "savoir", "seuil": 4, "ok": {"r": 4, "m": 2}, "ko": {"s": -8, "m": -4}},
		]},
	"douane": {"titre": "Un poste de frontière", "climats": [],
		"texte": "Un douanier très consciencieux veut compter chaque caisse. Il y en a quatre-vingts.",
		"choix": [
			{"t": "Lui présenter tous les papiers en règle", "q": "diplomatie", "seuil": 4, "ok": {"j": 1}, "ko": {"j": 4, "m": -6}},
			{"t": "Payer « les frais de dossier »", "q": "", "ok": {"e": -10_000}},
		]},
	"source_chaude": {"titre": "Une source chaude", "climats": ["froid", "montagne", "tempere"],
		"texte": "Une source fumante au milieu des rochers. Personne n'avait pris de bain depuis trois semaines. Ça se sentait.",
		"choix": [
			{"t": "Faire une halte", "q": "", "ok": {"s": 10, "m": 10, "j": 1}},
			{"t": "Noter l'endroit et continuer", "q": "", "ok": {"r": 2}},
		]},
	"rival": {"titre": "Une expédition rivale", "climats": [],
		"texte": "Une autre expédition campe sur votre site. Leur chef vous salue d'un air beaucoup trop aimable.",
		"choix": [
			{"t": "Proposer de travailler ensemble", "q": "diplomatie", "seuil": 5, "ok": {"b": "*", "r": 6}, "ko": {"m": -6}},
			{"t": "Partir plus tôt et plus loin", "q": "endurance", "seuil": 5, "ok": {"b": "*"}, "ko": {"s": -10, "m": -4}},
			{"t": "Laisser la place", "q": "", "ok": {"m": -6, "j": -1}},
		]},
	"nuit_etoilee": {"titre": "Une nuit claire", "climats": [],
		"texte": "Pas un nuage. Les étoiles sont si nombreuses que le cartographe en oublie de les compter.",
		"choix": [
			{"t": "Faire le point et dormir", "q": "", "ok": {"m": 6, "s": 4}},
		]},
}

# --- Petites fonctions --------------------------------------------------------------------------

static func entries() -> Dictionary:
	var out := {}
	for id in TYPES:
		var t: Dictionary = TYPES[id].duplicate()
		t["cat"] = CATEGORIE
		t["region"] = "monde"
		t["era"] = "moderne"
		t["style"] = ""
		out[id] = t
	return out


static func est_societe(type_id: String) -> bool:
	return TYPES.has(BuildingCatalog.base_of(type_id))


## [nom du trajet, facteur de durée, coût par jour et par membre] pour une année.
static func transport(annee: int) -> Array:
	for t in TRANSPORTS:
		if annee <= int(t[0]):
			return [String(t[1]), float(t[2]), float(t[3])]
	return [String(TRANSPORTS[-1][1]), float(TRANSPORTS[-1][2]), float(TRANSPORTS[-1][3])]


static func destination(id: String) -> Dictionary:
	return DESTINATIONS.get(id, {})


static func membre(id: String) -> Dictionary:
	return MEMBRES.get(id, {})


static func objet(id: String) -> Dictionary:
	return OBJETS.get(id, {})


static func specialiste(id: String) -> Dictionary:
	return SPECIALISTES.get(id, {})


static func objets_de(dest: String) -> Array:
	var out := []
	for id in OBJETS:
		if String(OBJETS[id].dest) == dest:
			out.append(id)
	return out


static func etoiles(rare: int) -> String:
	return "★".repeat(clampi(rare, 1, 3))


## Noms des chefs d'expédition (prénom, nom), tirés dans l'ordre.
const CHEFS := [
	"Adèle Vernier", "Hector Malaurie", "Léonie Castel", "Auguste Ferrand", "Joséphine Lacombe", "Théodore Brunel",
	"Camille Delorme", "Émile Garnier", "Marguerite Roussel", "Victor Lambert", "Hortense Duval", "Gaspard Morel",
	"Clémence Arnaud", "Ferdinand Lebrun", "Eugénie Marchal", "Anatole Rivière",
]
