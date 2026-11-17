class_name Epoques
extends RefCounted
## Les époques : une partie peut commencer à n'importe quelle année depuis 1800
## (réglage « Année de départ », sur le globe ou dans l'Admin F10). Tout suit
## alors l'année du calendrier :
##
## - Bâtiments, services publics, véhicules, voies, stations, réseaux et
##   matériaux de l'Atelier ont une année d'apparition réaliste (le tramway en
##   1880, l'électricité en 1882, l'autoroute en 1930, la 4G en 2010…). Avant,
##   ils sont verrouillés (« Arrive en 1882 ») ; les véhicules et les services
##   prennent un modèle de l'époque (pompe à bras, corbillard à chevaux…).
## - Les habitants n'attendent un réseau qu'une fois qu'il s'est répandu
##   (courant dès 1925, eau courante et tout-à-l'égout dès 1900, téléphone dès
##   1975…) : en 1800, personne ne se plaint de s'éclairer à la bougie.
## - Le temps de l'histoire avance avec l'horloge du jeu, à un rythme réglable
##   (1 à 25 années d'histoire par année de jeu), et l'admin peut sauter des
##   années. Les grandes inventions sont annoncées le jour où elles arrivent.
##
## Année de départ 0 : la partie se joue à l'époque actuelle, rien n'est
## verrouillé (comportement d'avant les époques).

const ANNEE_MIN := 1800
## Secondes dans une année moyenne (365,2425 jours).
const SECONDES_AN := 31556952.0
## Rythmes de l'histoire : années d'histoire par année de jeu.
const RYTHMES := [1.0, 2.0, 5.0, 10.0, 25.0]
const RYTHME_NOMS := ["Réel (1 an = 1 an)", "×2", "×5", "×10", "×25"]

## Horloge de la partie (DayNight s'y inscrit au démarrage).
static var horloge: Node = null

# --- Les grandes inventions (annonces, panneau Admin) ------------------------------------

const INVENTIONS := [
	{"annee": 1800, "nom": "L'aube du XIXe siècle", "desc": "Charrettes, diligences, puits, lampes à huile et pompes à bras."},
	{"annee": 1811, "nom": "Les sapeurs-pompiers", "desc": "Les premiers corps de pompiers organisés."},
	{"annee": 1812, "nom": "Le sucre de betterave", "desc": "Les premières sucreries."},
	{"annee": 1820, "nom": "Le gaz d'éclairage", "desc": "Usines à gaz et conduites sous les rues."},
	{"annee": 1828, "nom": "L'omnibus", "desc": "Les premières lignes de voitures publiques à chevaux."},
	{"annee": 1830, "nom": "Le chemin de fer", "desc": "Locomotives à vapeur, gares et briques industrielles."},
	{"annee": 1849, "nom": "Les express", "desc": "La locomotive Crampton file à 120 km/h ; voitures à compartiments et fourgons à bagages."},
	{"annee": 1850, "nom": "L'eau et les égouts modernes", "desc": "Captages, usines d'eau et grands collecteurs ; les zoos et les grands hôtels."},
	{"annee": 1853, "nom": "Les grands travaux", "desc": "Immeubles haussmanniens, gares monumentales, halles en fonte, tramways à chevaux."},
	{"annee": 1860, "nom": "Le pétrole et l'acier", "desc": "Puits de pétrole, raffineries, aciéries ; pompes à vapeur des pompiers."},
	{"annee": 1863, "nom": "Le métro", "desc": "Le premier chemin de fer souterrain."},
	{"annee": 1867, "nom": "Le vélocipède", "desc": "Pédales sur la roue avant ; les bateaux-mouches promènent les visiteurs de l'Exposition."},
	{"annee": 1876, "nom": "Le tramway à vapeur et le wagon-lit", "desc": "Petites motrices à vapeur dans les rues, premiers trains de nuit."},
	{"annee": 1880, "nom": "Le téléphone", "desc": "Centraux téléphoniques et lignes de cuivre ; locomotives-tenders de banlieue."},
	{"annee": 1882, "nom": "L'électricité", "desc": "Premières centrales au charbon et lignes électriques."},
	{"annee": 1884, "nom": "La poubelle", "desc": "Le préfet Poubelle impose les boîtes à ordures : collecte des déchets, crématoriums."},
	{"annee": 1893, "nom": "La grande roue", "desc": "Les fêtes foraines deviennent des parcs d'attractions."},
	{"annee": 1900, "nom": "L'automobile et le cinéma", "desc": "Voitures sans chevaux, salles de cinéma, centrales électriques."},
	{"annee": 1910, "nom": "L'aviation", "desc": "Aérodromes, garages, usines automobiles, autopompes."},
	{"annee": 1920, "nom": "Les années folles", "desc": "Art déco, stations-service, autobus, jazz et réseau électrique national."},
	{"annee": 1930, "nom": "L'autoroute", "desc": "Autoroutes, aéroports, piscines, camping et premiers immeubles modernes."},
	{"annee": 1950, "nom": "Les Trente Glorieuses", "desc": "Maisons et immeubles modernes, supermarchés, hélicoptères, épuration."},
	{"annee": 1960, "nom": "L'ère nucléaire", "desc": "Centrales nucléaires, tours, hypermarchés et grands ensembles."},
	{"annee": 1964, "nom": "La grande vitesse", "desc": "Lignes à grande vitesse et trains rapides."},
	{"annee": 1975, "nom": "Le téléphone pour tous", "desc": "Chaque foyer veut sa ligne : le téléphone devient indispensable."},
	{"annee": 1990, "nom": "L'écologie", "desc": "Éoliennes, tri sélectif, déchèteries, recyclage, voies vertes."},
	{"annee": 1992, "nom": "Le téléphone portable", "desc": "Les premiers pylônes GSM."},
	{"annee": 2000, "nom": "Internet et le solaire", "desc": "Fibre optique, centres de données, centrales solaires."},
	{"annee": 2010, "nom": "La 4G", "desc": "L'internet mobile partout ; batteries de stockage."},
	{"annee": 2019, "nom": "La 5G", "desc": "Antennes 5G et réseaux très haut débit."},
	{"annee": 2040, "nom": "Le futur", "desc": "Architecture futuriste et véhicules de demain."},
]

## Quand un réseau devient indispensable aux yeux des habitants (avant, il ne
## manque à personne : bougies, puits, fosses, poêles à bois).
const ATTENDU := {"elec": 1925, "eau": 1900, "egout": 1900, "gaz": 1960, "telecom": 1975, "dechets": 1884}

# --- Années d'apparition ----------------------------------------------------------------

## Années par époque de la bible (Styles.ERAS) quand rien de plus précis n'est connu.
const ERA_ANNEES := {"antique": 0, "traditionnel": 0, "classique": 1830, "moderne": 1950,
	"contemporain": 1990, "futuriste": 2040}

## Styles de la bible plus précis que leur époque.
const STYLE_ANNEES := {
	"haussmann": 1853, "briques_ind": 1830, "art_deco": 1920, "australien": 1850, "far_west": 1850,
	"hollandais": 0, "latino": 0, "ottoman": 0, "colonial": 0,
	"international": 1930, "brutaliste": 1955, "sovietique": 1955, "banlieue_us": 1950, "afrique_moderne": 1960,
	"golfe": 1990, "asie_dense": 1985, "verre": 1990, "futuriste": 2040,
	# Troisième vague de styles (toutes les régions, toutes les époques).
	"georgien": 0, "balneaire": 1860, "art_nouveau": 1893, "bauhaus": 1925, "reconstruction": 1945,
	"nordique_contemporain": 2000, "palazzina": 1850, "moderniste_catalan": 1888, "rationalisme": 1928,
	"polykatoikia": 1955, "riviera_contemporaine": 1995, "levantin": 1840, "moderne_orient": 1935,
	"maghreb_colonial": 1890, "colonial_tropical": 1870, "independances": 1957, "afrique_contemporaine": 2000,
	"meiji": 1872, "shikumen": 1860, "japon_moderne": 1958, "chine_populaire": 1952, "asie_est_contemporain": 1998,
	"indo_sarrasin": 1870, "compartiments": 1840, "inde_moderne": 1951, "tropical_contemporain": 1995,
	"craftsman": 1905, "neo_hispanique": 1890, "streamline": 1933, "bresil_moderne": 1940, "latino_contemporain": 2000,
	"federation": 1890, "pacifique_contemporain": 1995, "postmoderne": 1978, "high_tech": 1977, "parametrique": 2005,
	"bois_vegetal": 2010, "art_deco_shanghai": 1925, "art_deco_bombay": 1930, "asmara": 1935, "neo_soudanais": 1907,
	"entre_deux_guerres_oceanie": 1915, "art_deco_napier": 1931, "golfe_petrolier": 1968,
	"australie_moderne": 1950,
}

## Bâtiments du catalogue (hors bible des styles) : année d'apparition.
## 0 = de tout temps.
const ANNEES := {
	# Logement
	"maison": 1950, "villa": 1960, "immeuble": 1950, "tour_habitation": 1960, "ranch": 1950, "pavillon": 1960,
	"maison_contemporaine": 1995, "villa_mid_century": 1950, "maison_bois": 2000, "plattenbau": 1960,
	"grand_ensemble": 1955, "unite_habitation": 1952, "tour_residence": 1990, "tour_verre": 2000,
	"immeuble_bois": 2010, "tour_hong_kong": 1970, "favela_colline": 1950,
	# Commerce
	"boulangerie": 0, "superette": 1955, "supermarche": 1960, "bureaux": 1960, "station_service": 1920,
	"pharmacie": 1900, "boutique_mode": 1900, "magasin_multimedia": 1970, "magasin_meubles": 1900,
	"concession_auto": 1920, "epicerie_quartier": 0, "pharmacie_officine": 1900, "fleuriste": 1850,
	"supermarche_moderne": 1970, "hypermarche": 1963, "centre_commercial": 1970, "magasin_bricolage": 1980,
	"concession_voitures": 1990, "station_carburant": 1950, "fastfood_drive": 1975, "diner_americain": 1930,
	"hotel_chaine": 1980, "tour_hotel": 1970, "motel": 1930, "immeuble_bureaux": 1960, "tour_bureaux": 1970,
	"siege_social": 1990, "marche_africain": 1960, "fare_polynesien": 1960,
	# Industrie
	"atelier": 0, "entrepot": 1850, "usine": 1850, "ferme": 0, "entreprise_btp": 0, "campement": 0,
	"etable_moderne": 1990, "poulailler": 1960, "porcherie": 1960, "serres_tunnels": 1970, "serre_verre": 1850,
	"silos_grains": 1900, "hangar_agricole": 1950, "menuiserie_village": 0, "scierie_jura": 0,
	"usine_automobile": 1910, "entrepot_logistique": 1990, "haut_fourneau": 0, "raffinerie_petrole": 1860,
	"cimenterie_four": 1850, "incinerateur": 1900, "data_center": 2000, "terminal_conteneurs": 1966,
	"depot_bus": 1910, "garage_auto": 1910,
	# Services publics (les versions d'époque sont dans EpoquesTypes)
	"maison_commune": 0, "mairie": 0, "ecole": 1950, "pompiers": 1950, "police": 1950, "hopital": 1950,
	"chateau_eau": 1880, "pylone_2g": 1992, "pylone_4g": 2010, "pylone_5g": 2019, "antenne_5g": 2020,
	"central_telephonique": 1880, "noeud_fibre": 2000, "centre_technique": 1950, "bassin_retention": 1970,
	"station_meteo": 1850, "bibliotheque": 1980, "college": 1960, "creche": 1970, "universite": 0, "lycee": 1802, "hopital_regional": 1960,
	"clinique": 1970, "caserne_pompiers": 1990, "gendarmerie": 1960, "commissariat": 1990,
	# Loisirs et sport
	"parc": 0, "aire_jeux": 1900, "cafe": 0, "cinema": 1910, "musee": 0, "bowling": 1950, "discotheque": 1965,
	"salle_concert": 1990, "parc_aquatique": 1980, "musee_contemporain": 1980, "cinema_multiplexe": 1990,
	"salle_fetes": 1920, "foot": 1870, "tennis": 1880, "basket": 1900, "gymnase": 1960, "piscine": 1930,
	"salle_omnisports": 1970, "palais_sports": 1970, "patinoire_hockey": 1970, "centre_tennis": 1990,
	"centre_formation": 1980, "skatepark_bowl": 1975, "stade_foot": 1920, "club_house_golf": 1900,
	"patinoire": 1960, "salle_omnisport": 1970, "piscine_couverte": 1990, "halle_tennis": 1980,
	# Espaces publics
	"parc_lac": 0, "pique_nique": 1950, "skatepark": 1990, "jardin_partage": 2000, "place_moderne": 1980,
	"monument_moderne": 1960, "banc": 0, "lampadaire": 0, "arbre": 0, "palmier": 0, "abribus": 1950,
	"poubelle": 1884, "velos": 2007, "terrasse": 0, "jardiniere": 0,
	# Production
	"exploitation_forestiere": 0, "ferme_cereales": 0, "ferme_maraichere": 0, "ferme_betteraves": 1812,
	"ferme_fibres": 0, "elevage": 0, "ferme_laitiere": 0, "silo_cooperative": 1900, "concession_agricole": 1920,
	"port_peche": 0, "carriere": 0, "sabliere": 0, "argiliere": 0, "mine_ciel_ouvert": 1900, "mine": 0,
	"mine_sel": 0, "puits": 1860, "scierie": 0, "moulin": 0, "fournil": 1900, "abattoir": 1820,
	"laiterie": 0, "sucrerie": 1812, "huilerie": 0, "filature": 0, "usine_agro": 1950, "brasserie": 0,
	"briqueterie": 0, "cimenterie": 1850, "verrerie": 0, "papeterie": 0, "acierie": 1860,
	"fonderie_cuivre": 0, "aluminerie": 1890, "raffinerie": 1860, "usine_chimique": 1850, "menuiserie": 0,
	"usine_textile": 1820, "usine_hygiene": 1900, "labo_pharma": 1900, "usine_biens": 1850,
	"usine_electronique": 1960, "usine_auto": 1910, "transporteur": 1920,
	# Réseaux
	"centrale_charbon_locale": 1882, "centrale_gaz": 1990, "centrale_biomasse": 1990, "poste_national": 1920,
	"batteries": 2010, "captage_eau": 1850, "forage_eau": 1870, "station_epuration_locale": 1960,
	"lagunage": 1970, "exutoire_egout": 0, "poste_gaz": 1820, "chaufferie_bois": 1950, "geothermie": 1970,
	"centrale_charbon": 1900, "centrale_nucleaire": 1960, "eolienne": 1990, "centrale_solaire": 2000,
	"station_epuration": 1940, "chateau_eau_champignon": 1960,
	# Déchets
	"depot_collecte": 1884, "decheterie": 1990, "centre_tri": 1990, "usine_recyclage": 1990, "compost": 1990,
	"decharge": 0, "usine_incineration": 1970, "decharge_fermee": 1970,
	# Funéraire
	"pompes_funebres": 0, "cimetiere_village": 0, "cimetiere_communal": 0, "cimetiere_paysager": 1980,
	"columbarium": 1890, "crematorium": 1890, "cimetiere_militaire": 1918, "cimetiere_asie": 0,
	"cimetiere_musulman": 0, "cimetiere_juif": 0,
	# Zoo
	"entree_zoo": 1830, "abri_bois_zoo": 1830, "abri_savane_zoo": 1900, "grotte_zoo": 1900,
	"abri_polaire_zoo": 1950, "vivarium_zoo": 1850, "maison_elephants_zoo": 1830, "poste_soigneurs_zoo": 1830,
	"cuisine_zoo": 1830, "clinique_zoo": 1950, "atelier_zoo": 1830, "belvedere_zoo": 1830,
	"kiosque_pedago_zoo": 1970, "restaurant_zoo": 1900, "glacier_zoo": 1900, "buvette_zoo": 1850,
	"boutique_zoo": 1950, "toilettes_zoo": 1900, "pique_nique_zoo": 1950,
	# Spectacles
	"cinema_art_essai": 1920, "multiplexe": 1990, "cinema_plein_air": 1950, "drive_in": 1933,
	"studio_cinema": 1910, "plateau_tournage": 1930, "decor_western": 1920, "decor_ville": 1920,
	"decor_chateau": 1920, "decor_spatial": 1970, "bassin_tournage": 1950, "studio_effets": 1980,
	"post_production": 1960, "atelier_decors_cinema": 1910, "club_jazz": 1920,
	"salle_musiques_actuelles": 1990, "auditorium": 1960, "arena_concert": 1980, "scene_festival": 1969,
	"cafe_theatre": 1960, "theatre_italienne": 0, "scene_contemporaine": 1970, "opera_coupole": 0,
	"theatre_verdure": 0, "chapiteau_cirque": 0,
	# Tourisme
	"aire_camping_cars": 1980, "camping": 1930, "camping_club": 1970, "gite_rural": 1955,
	"chambres_hotes": 0, "auberge_jeunesse": 1910, "hotel_2": 1850, "hotel_3": 1900, "hotel_4": 1950,
	"palace": 1880, "residence_tourisme": 1970, "village_vacances": 1950, "office_tourisme": 1890,
	"boutique_souvenirs_ville": 1900, "parking_autocars": 1950, "poste_secours_plage": 1950,
	"base_nautique": 1970, "belvedere": 0, "parking_randonnee": 1960, "maison_nature": 1980,
	"refuge_montagne": 1850,
	# Parc de loisirs
	"entree_parc": 1850, "carrousel_parc": 1850, "tasses_parc": 1950, "autos_tamponneuses": 1920,
	"train_fantome": 1930, "grande_roue_parc": 1893, "chaises_volantes": 1900, "bateau_pirate": 1960,
	"tour_chute": 1980, "montagnes_russes": 1885, "friterie_parc": 1900, "glacier_parc": 1900,
	"buvette_parc": 1850, "boutique_souvenirs": 1900, "toilettes_parc": 1900, "aire_repos_parc": 1850,
	"atelier_parc": 1850, "piscine_vagues": 1970, "pataugeoire": 1950, "bateaux_tamponneurs": 1960,
	"pedalos": 1950, "pizzeria_parc": 1950, "creperie_parc": 1950, "barbe_a_papa": 1904,
	"bar_smoothies": 2000, "distributeur_boissons": 1960, "stand_ballons": 1900, "comptoir_photo": 1990,
	"poste_secours": 1950, "kiosque_info": 1950,
}

## Mots du nom ou de l'id d'un bâtiment inconnu des tables : première règle qui correspond.
const MOTS_BATIMENTS := [
	["5g", 2019], ["4g", 2010], ["fibre", 2000], ["data", 2000], ["solaire", 2000], ["photovolt", 2000],
	["eolien", 1990], ["éolien", 1990], ["recyclage", 1990], ["multiplexe", 1990], ["nucleaire", 1960],
	["nucléaire", 1960], ["hypermarch", 1963], ["supermarch", 1960], ["centre commercial", 1970],
	["parking", 1920], ["aeroport", 1930], ["aéroport", 1930], ["heliport", 1950], ["héliport", 1950],
	["station-service", 1920], ["cinema", 1910], ["cinéma", 1910], ["garage", 1910], ["electri", 1882],
	["électri", 1882], ["telephon", 1880], ["téléphon", 1880], ["gare", 1830],
]

## Voies (TransportTypes.CLASSES).
const VOIES := {"rue": 0, "avenue": 0, "giratoire": 1906, "departementale": 0, "voie_express": 1950,
	"autoroute": 1930, "bretelle": 1930, "tram": 1853, "train": 1830, "cremaillere": 1870, "metro": 1863,
	"lgv": 1964, "trottoir": 0, "piste_cyclable": 1930, "voie_verte": 1990, "canal": 0, "chenal": 0}
## Stations (StationSystem.TYPES).
const STATIONS := {"arret_bus": 1828, "arret_tram": 1853, "station_metro": 1863, "gare": 1830, "port": 0,
	"heliport": 1950, "aerodrome": 1910, "aeroport": 1930, "depot": 0, "parking": 1920}
## Tronçons des réseaux (ReseauxTypes.TRONCONS) et câbles (Telecom.CABLES).
const TRONCONS := {"ligne_ht": 1910, "ligne_mt": 1882, "conduite_eau": 0, "collecteur": 0, "conduite_gaz": 1820,
	"cuivre_aerien": 1880, "fibre": 2000, "fibre_aerienne": 2000}

## Matériaux de l'Atelier (BlocMateriaux.LIST) : mots du nom, première règle qui correspond.
const MOTS_MATERIAUX := [
	# Lot du 2026-11-17 (avant les règles générales : « béton fibré » avant « béton »).
	["pierre agglomérée", 1850], ["ciment moulé", 1860], ["grès flammé", 1890], ["carreaux de métro", 1904],
	["art déco", 1925], ["ferronnerie art nouveau", 1893], ["bakélite", 1910], ["formica", 1950], ["gabions", 1900],
	["tôle émaillée", 1900], ["aluminium composite", 1969], ["béton préfabriqués", 1950], ["mur-rideau bronze", 1958],
	["vinyle", 1950], ["stratifié", 1977], ["polymère", 1971], ["béton imprimé", 1970], ["panneaux solaires", 1995],
	["tuiles solaires", 2016], ["lamellé-croisé", 1995], ["bardage composite", 2000], ["fibre-ciment", 1990],
	["baguettes de terre cuite", 2000], ["etfe", 2001], ["béton fibré", 2000], ["grand format", 2005],
	["pavés drainants", 2005], ["mur végétal", 1994], ["métal perforé", 2005], ["verre intelligent", 2025],
	["oled", 2030], ["mycélium", 2030], ["biobéton", 2028],
	["bâche", 1950], ["camouflage", 1915], ["confettis", 1890], ["écran led", 2000], ["néon", 1925], ["fibre de verre", 1950], ["polycarbonate", 1970], ["plastique", 1950],
	["epdm", 1965], ["gazon synthétique", 1966], ["tartan", 1968], ["sol amortissant", 1980],
	["sol sportif", 1970], ["résine", 1970], ["sol souple", 1960], ["caoutchouc", 1900], ["corten", 1965],
	["aluminium", 1950], ["inox", 1920], ["chrome", 1925], ["galvanisé", 1850], ["bac acier", 1960],
	["fibrociment", 1910], ["dalles de béton", 1930], ["béton", 1890], ["parpaing", 1920],
	["autobloquant", 1960], ["enrobé", 1920], ["bardeaux bitumés", 1900], ["contreplaqué", 1900],
	["moquette", 1950], ["lino", 1870], ["sièges de stade", 1950], ["tôle", 1830], ["tuile mécanique", 1850],
	["pavés de verre", 1930], ["verre fumé", 1950], ["verre miroir", 1850], ["toit végétal", 1970],
	["carreaux de ciment", 1860], ["zinc", 1820], ["acier", 1860], ["métal déployé", 1900],
	["tôle perforée", 1900], ["grillage", 1850], ["piste cendrée", 1880], ["parquet de gymnase", 1900],
	["green de golf", 1900], ["glace de patinoire", 1900], ["sable de beach-volley", 1990],
]

## Modèles qui remplacent un véhicule trop moderne : rôle (« urgence » ou
## « role » du catalogue) -> modèles du plus ancien au plus récent. Le plus
## récent déjà inventé est pris.
const ROLES_VEHICULES := {
	"benne_om": "ordures", "benne": "ordures", "corbillard": "corbillard", "chasse_neige": "chasse_neige",
	"autocar": "car",
}

## Attelages qui remplacent les voitures et les utilitaires avant le moteur.
const ATTELAGES := {
	"voiture": ["fiacre", "cabriolet", "coupe_ville", "caleche"],
	"utilitaire": ["fardier", "haquet_brasseur", "voiture_laitier", "malle_poste"],
}

static var _cache_bat := {}
static var _cache_mat := {}


# --- Année en cours -------------------------------------------------------------------------

## La partie se joue-t-elle à une époque historique ?
static func actif(r: ReglagesPartie = null) -> bool:
	if r == null:
		r = ReglagesPartie.actuel
	# Édition démo : on démarre toujours aujourd'hui (les époques sont dans le jeu complet).
	return r != null and r.annee_depart > 0 and not EditionDemo.active()


static func _unix() -> float:
	if horloge != null and is_instance_valid(horloge):
		return float(horloge.get("unix_time"))
	return NAN


## Année du calendrier de la partie en cours.
static func annee(r: ReglagesPartie = null) -> int:
	if r == null:
		r = ReglagesPartie.actuel
	if not actif(r):
		var u := _unix()
		if is_nan(u):
			return int(Time.get_date_dict_from_system().year)
		return int(Time.get_date_dict_from_unix_time(int(u)).year)
	var t := _unix()
	if not is_nan(t) and r.histoire_debut == 0.0:
		r.histoire_debut = t
	var ecoule := 0.0
	if not is_nan(t) and r.histoire_debut != 0.0:
		ecoule = maxf(0.0, t - r.histoire_debut) / SECONDES_AN * r.rythme_histoire
	return r.annee_depart + r.histoire_saut + floori(ecoule)


## Règle l'année en cours (admin) : ajuste le saut, sans toucher à l'horloge.
static func aller_a(annee_voulue: int, r: ReglagesPartie = null) -> void:
	if r == null:
		r = ReglagesPartie.actuel
	if not actif(r):
		return
	annee_voulue = maxi(ANNEE_MIN, annee_voulue)
	r.histoire_saut += annee_voulue - annee(r)


static func nom_rythme(v: float) -> String:
	for i in RYTHMES.size():
		if absf(float(RYTHMES[i]) - v) < 0.01:
			return RYTHME_NOMS[i]
	return "×" + String.num(v, 1)


# --- Bâtiments ------------------------------------------------------------------------

static func annee_batiment(id: String) -> int:
	if _cache_bat.has(id):
		return int(_cache_bat[id])
	var t := BuildingCatalog.get_type(id)
	var y := 0
	if t.is_empty() or t.has("blocks") or t.has("modele"):
		y = 0 # Créations du joueur et modèles de l'Atelier : de toutes les époques.
	elif t.has("annee"):
		y = int(t.annee)
	elif ANNEES.has(id):
		y = int(ANNEES[id])
	elif EpoquesObjets.BATIMENTS.has(id):
		y = int(EpoquesObjets.BATIMENTS[id])
	elif String(t.get("style", "")) != "" and STYLE_ANNEES.has(String(t.style)):
		y = int(STYLE_ANNEES[String(t.style)])
	elif String(t.get("style", "")) != "":
		y = int(ERA_ANNEES.get(String(t.get("era", "")), 0))
	else:
		y = -1
		var hay := (id + " " + String(t.get("name", ""))).to_lower()
		for regle in MOTS_BATIMENTS:
			if hay.contains(String(regle[0])):
				y = int(regle[1])
				break
		if y < 0:
			y = int(ERA_ANNEES.get(String(t.get("era", "moderne")), 1950))
	_cache_bat[id] = y
	return y


static func batiment_disponible(id: String, r: ReglagesPartie = null) -> bool:
	return not actif(r) or annee_batiment(id) <= annee(r)


## Raison du verrou d'époque, ou "".
static func raison_batiment(id: String, r: ReglagesPartie = null) -> String:
	if batiment_disponible(id, r):
		return ""
	return "Pas encore inventé : arrive en %d (nous sommes en %d)." % [annee_batiment(id), annee(r)]


# --- Véhicules --------------------------------------------------------------------------

static func annee_vehicule(id: String) -> int:
	return int(VehicleCatalog.get_type(id).get("year", 0))


static func vehicule_disponible(id: String, r: ReglagesPartie = null) -> bool:
	return not actif(r) or annee_vehicule(id) <= annee(r)


static func role_vehicule(id: String) -> String:
	var t := VehicleCatalog.get_type(id)
	if String(t.get("urgence", "")) != "":
		return String(t.urgence)
	if String(t.get("role", "")) != "":
		return String(t.role)
	return String(ROLES_VEHICULES.get(id, ""))


## Modèle à utiliser à la place de id à l'époque de la partie : lui-même s'il est
## déjà inventé, sinon le plus récent modèle du même rôle (pompe à bras avant
## l'autopompe), sinon de la même catégorie, sinon une charrette.
static func vehicule(id: String, r: ReglagesPartie = null) -> String:
	if vehicule_disponible(id, r):
		return id
	return vehicule_pour_annee(id, annee(r))


## Même choix pour une année donnée (catalogue : ce qui roule à la place avant l'invention).
static func vehicule_pour_annee(id: String, y: int) -> String:
	if annee_vehicule(id) <= y:
		return id
	var t := VehicleCatalog.get_type(id)
	var role := role_vehicule(id)
	var best := ""
	var best_y := -100000
	for pass_i in 2:
		for vid in VehicleCatalog.TYPES:
			var v: Dictionary = VehicleCatalog.TYPES[vid]
			var vy := int(v.get("year", 0))
			if vy > y or vy <= best_y or bool(v.get("hidden", false)):
				continue
			if int(v.get("mode", 0)) != int(t.get("mode", 0)):
				continue
			if pass_i == 0 and (role == "" or role_vehicule(vid) != role):
				continue
			if pass_i == 1 and (String(v.cat) != String(t.get("cat", "")) or role_vehicule(vid) != ""):
				continue
			best = vid
			best_y = vy
		if best != "":
			return best
	# Voitures et utilitaires à moteur : un attelage du même usage (varié selon le modèle).
	var choix: Array = []
	for vid in ATTELAGES.get(String(t.get("cat", "")), []):
		if int(VehicleCatalog.get_type(vid).get("year", 99999)) <= y:
			choix.append(vid)
	if not choix.is_empty():
		return choix[absi(hash(id)) % choix.size()]
	match int(t.get("mode", 0)):
		TransportTypes.Mode.WATER:
			return "barque"
		TransportTypes.Mode.AIR:
			return "montgolfiere"
	return "charrette"


# --- Voies, stations, réseaux, matériaux ------------------------------------------------------

static func annee_voie(cls: String) -> int:
	return int(VOIES.get(TransportTypes.resolve(cls), 0))


static func raison_voie(cls: String, r: ReglagesPartie = null) -> String:
	if not actif(r) or annee_voie(cls) <= annee(r):
		return ""
	return "%s : pas encore inventé, arrive en %d." % [String(TransportTypes.get_type(cls).get("name", cls)), annee_voie(cls)]


static func raison_station(type_id: String, r: ReglagesPartie = null) -> String:
	var y := int(STATIONS.get(type_id, 0))
	if not actif(r) or y <= annee(r):
		return ""
	return "Pas encore inventé : arrive en %d." % y


static func raison_troncon(type_id: String, r: ReglagesPartie = null) -> String:
	var y := int(TRONCONS.get(type_id, 0))
	if not actif(r) or y <= annee(r):
		return ""
	return "Pas encore inventé : arrive en %d (nous sommes en %d)." % [y, annee(r)]


static func annee_materiau(m: int) -> int:
	if _cache_mat.has(m):
		return int(_cache_mat[m])
	var y := 0
	if m >= 0 and m < BlocMateriaux.LIST.size():
		var nom := String(BlocMateriaux.LIST[m].name).to_lower()
		for regle in MOTS_MATERIAUX:
			if nom.contains(String(regle[0])):
				y = int(regle[1])
				break
	_cache_mat[m] = y
	return y


static func materiau_disponible(m: int, r: ReglagesPartie = null) -> bool:
	return not actif(r) or annee_materiau(m) <= annee(r)


## Le réseau (elec, eau, egout, gaz, telecom, dechets) manque-t-il aux habitants à cette époque ?
static func attendu(res: String, r: ReglagesPartie = null) -> bool:
	return not actif(r) or annee(r) >= int(ATTENDU.get(res, 0))


# --- Annonces ---------------------------------------------------------------------------

## Inventions arrivées après l'année « de » jusqu'à l'année « a » incluse.
static func inventions_entre(de: int, a: int) -> Array:
	var out := []
	for inv in INVENTIONS:
		if int(inv.annee) > de and int(inv.annee) <= a:
			out.append(inv)
	return out


## Les prochaines inventions après l'année donnée.
static func prochaines(apres: int, n := 3) -> Array:
	var out := []
	for inv in INVENTIONS:
		if int(inv.annee) > apres:
			out.append(inv)
			if out.size() >= n:
				break
	return out


## Résumé en une ligne (globe, Admin).
static func resume(r: ReglagesPartie = null) -> String:
	if r == null:
		r = ReglagesPartie.actuel
	if not actif(r):
		return "époque actuelle"
	var txt := "départ en %d" % r.annee_depart
	if r.rythme_histoire > 1.0:
		txt += ", histoire %s" % nom_rythme(r.rythme_histoire)
	return txt
