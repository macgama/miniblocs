class_name EpoquesObjets
extends RefCounted
## Dates d'apparition de tout ce qui se construit et n'avait pas encore d'année
## à soi (catalogue daté du 2026-11-16) :
##
## - bâtiments faits à la main (bible Blender, espaces publics, stades) qui
##   prenaient jusqu'ici l'année de leur époque ou d'un mot de leur nom ;
## - décors (touche G), meubles et objets de spectacle (Intérieur), ouvertures
##   et toits de l'Atelier, aménagements (bassins, rails, gradins, terrains),
##   grands-huit et leurs figures.
##
## 0 = de tout temps (déjà là en 1800). Les dates sont celles de l'invention ou
## de la diffusion en Europe (le premier looping moderne en 1976, le stop en
## 1927, la botte ronde en 1972…). Avant leur date, ces objets sont verrouillés
## dans les panneaux, et les décors posés tout seuls (rues, berges, fermes)
## prennent un équivalent de l'époque (réverbère à gaz au lieu du lampadaire,
## barque au lieu du hors-bord, meule au lieu des bottes rondes) ou disparaissent.

# --- Bâtiments sans année à eux (bible Blender, espaces publics, stades) ----------------

const BATIMENTS := {
	# Espaces publics
	"place_pavee": 0, "piazza": 0, "square": 0, "kiosque_musique": 1850, "jardin_francais": 0, "obelisque": 0,
	"statue_equestre": 0, "arc_triomphe": 0, "torii": 0, "stupa": 0, "totem": 0, "lampadaire_ancien": 1820,
	"lanterne_pierre": 0, "cerisier": 0, "fontaine_wallace": 1872, "cabine": 1920, "colonne_morris": 1855,
	"kiosque_journaux": 1857,
	# Stades de Super League : année de leur inauguration
	"stade_bale": 2001, "stade_berne": 2005, "stade_geneve": 2003, "stade_letzigrund": 2007,
	"stade_saint_gall": 2008, "stade_lucerne": 2011, "stade_sion": 1968, "stade_tuiliere": 2020,
	"stade_thoune": 2011, "stade_lugano": 1951, "stade_vaduz": 1998,
	# Commerce
	"boulangerie_village": 0, "boucherie_charcuterie": 0, "librairie": 0, "kiosque_presse": 1857,
	"halle_marche": 1853, "souk_couvert": 0, "grand_magasin": 1852, "bistrot_parisien": 1870, "pizzeria": 1830,
	"izakaya": 0, "boutiques_rue": 0, "shophouse": 1820, "auberge_montagne": 0, "palace_belle_epoque": 1880,
	"ryokan": 0, "banque_classique": 0,
	# Loisirs
	"casino": 0, "grande_roue": 1893, "carrousel": 1850, "kiosque_fanfare": 1850,
	# Fermes, ateliers, industrie
	"ferme_cour_carree": 0, "ferme_jurassienne": 0, "ferme_bavaroise": 0, "cortijo": 0, "hacienda": 0,
	"grange_americaine": 0, "bergerie": 0, "haras": 0, "moulin_vent": 0, "moulin_eau": 0, "chai": 0,
	"cave_cooperative": 1901, "ferme_alpage": 0, "rizerie_bali": 0, "atelier_artisan": 0, "filature_briques": 1820,
	"brasserie_biere": 1840, "briqueterie_hoffmann": 1858, "barrage_usine": 1890, "hangar_avions": 1910,
	# Bâtiments du monde (traditionnels : déjà là en 1800)
	"mosquee_banco": 0, "kasbah": 0, "case_obus": 0, "maison_swahilie": 0, "grenier_dogon": 0,
	"eglise_monolithe": 0, "caravanserail": 0, "maison_badgir": 0, "maison_tour_yemen": 0, "tulou": 0,
	"hanok": 0, "chateau_himeji": 0, "temple_hindou": 0, "stupa_boudha": 0, "haveli": 0, "wat_thai": 0,
	"longhouse_borneo": 0, "tongkonan": 0, "mission_espagnole": 0, "pyramide_maya": 0, "saloon_western": 1850,
	"eglise_chiloe": 0, "wharenui": 0,
	# Monuments et lieux de culte
	"chateau_fort_enceinte": 0, "abbaye_cistercienne": 0, "temple_dorique": 0, "amphitheatre_romain": 0,
	"aqueduc_romain": 0, "eglise_romane": 0, "cathedrale_gothique": 0, "chapelle_alpine": 0, "eglise_baroque": 0,
	"temple_protestant": 0, "eglise_orthodoxe": 0, "mosquee": 0, "synagogue": 0, "pagode": 0,
	# Services et culture
	"mairie_village": 0, "hotel_de_ville": 0, "palais_justice": 0, "palais_federal": 1850, "poste": 0,
	"musee_classique": 0, "opera": 0, "theatre": 0, "ecole_ferry": 1882, "lycee": 1802, "universite": 0,
	"gare_village": 1840, "gare_ville": 1850, "phare": 0,
	# Maisons régionales et logements
	"chalet_bernois": 0, "chalet_valaisan": 0, "maison_normande": 0, "maison_alsacienne": 0, "mas_provencal": 0,
	"longere_bretonne": 0, "maison_basque": 0, "cottage_anglais": 0, "maison_canal": 0, "maison_scandinave": 0,
	"isba": 0, "trullo": 0, "maison_cycladique": 0, "riad": 0, "minka": 0, "machiya": 0, "siheyuan": 0,
	"maison_pilotis": 0, "cases_rondes": 0, "pueblo_adobe": 0, "victorienne": 1840, "maison_coloniale": 0,
	"queenslander": 1850, "villa_moderniste": 1925, "maisons_en_bande": 0, "immeuble_haussmannien": 1853,
	"immeuble_annees30": 1925, "brownstone": 1840,
}

# --- Décors (touche G) -----------------------------------------------------------------

const DECORS := {
	# Mobilier urbain
	"banc_moderne": 1970, "poubelle": 1884, "poubelles_tri": 1990, "conteneur": 1965, "abribus": 1950,
	"borne_incendie": 1850, "potelet": 1970, "potelets": 1970, "boite_aux_lettres": 1850, "cabine_telephone": 1926,
	"colonne_affichage": 1855, "parcmetre": 1980, "arceaux_velo": 1970, "horloge": 1860, "panneau_publicite": 1950,
	"terrasse_cafe": 1900,
	# Éclairage
	"lampadaire": 1930, "lampadaire_double": 1930, "reverbere": 1820, "lampadaire_boule": 1960,
	# Fontaines et statues
	"fontaine_wallace": 1872, "borne_fontaine": 1850, "monument_morts": 1919,
	# Clôtures
	"cloture_barbelee": 1874, "grillage": 1850, "barriere_metal": 1900, "glissiere": 1950,
	# Signalisation
	"panneau_stop": 1927, "panneau_cedez": 1950, "panneau_vitesse": 1920, "panneau_danger": 1909,
	"panneau_parking": 1940, "panneau_direction": 1900, "panneau_entree": 1920, "balise": 1950,
	"feu_tricolore": 1920, "poteau_electrique": 1882, "pylone": 1910,
	# Marché
	"tente_marche": 1950, "parasol": 1900, "stand_glaces": 1900,
	# Jeux et sport
	"balancoire": 1900, "toboggan": 1920, "tourniquet": 1920, "jeu_ressort": 1960, "bac_a_sable": 1900,
	"cabane_jeux": 1980, "cage_foot": 1870, "panier_basket": 1891, "ping_pong": 1960,
	# Plage
	"parasol_plage": 1900, "transat": 1900, "cabine_plage": 1850, "maitre_nageur": 1900,
	# Ferme
	"botte_ronde": 1972, "botte_enrubannee": 1985, "botte_debout": 1972, "botte_carree": 1940, "pile_bottes": 1980,
	"tracteur": 1960, "tracteur_rouge": 1950, "tracteur_ancien": 1920, "remorque_foin": 1940, "moissonneuse": 1950,
	"abreuvoir": 1900, "citerne": 1920, "silo_grain": 1900, "serre_tunnel": 1960, "bidons_lait": 1850,
	# Bord de l'eau
	"kayak": 1950, "voilier": 1900, "voilier_ancre": 1900, "bateau_peche": 1900, "bateau_moteur": 1910,
	"pedalo": 1950, "bouee": 1850, "balise_verte": 1880, "balise_rouge": 1880, "phare": 1850,
	# Zoo
	"panneau_espece": 1950, "longue_vue": 1850, "balle_enrichissement": 1990, "rocher_chauffant": 1970,
	"plateforme_singes": 1950,
	# Parc de loisirs
	"pt_lampadaire_guirlande": 1900, "pt_poubelle_clown": 1950, "pt_mascotte": 1950, "pt_fusee": 1957,
	"pt_soucoupe": 1950, "pt_radar": 1940, "pt_robot": 1930, "pt_planete": 1950,
	# Décors datés (lot du 2026-11-17) ; torii, lanternes, chadouf, totem, mur mani,
	# four à pain, tandoor, chasse-roue, pompe à bras : de tout temps.
	"bec_gaz": 1830, "vespasienne": 1834, "kiosque_journaux": 1857, "kiosque_musique": 1850, "lavoir": 1830,
	"poteau_telegraphe": 1850, "orgue_barbarie": 1800, "cireur": 1880, "malles_bagages": 1880,
	"pompe_essence_ancienne": 1920, "borne_routiere": 1920, "cabine_police": 1929, "entree_metro": 1900,
	"borne_appel": 1890, "affiche_reclame": 1900, "sirene_alerte": 1938, "yatai": 1900,
	"borne_recharge": 2010, "bornes_recharge_parking": 2015, "velos_libre_service": 2007, "trottinettes": 2018,
	"abribus_moderne": 2000, "panneaux_solaires": 2005, "lampadaire_solaire": 2012, "boite_livres": 2010,
	"conteneurs_enterres": 2000, "poubelle_solaire": 2010, "totem_info": 2012, "camera_surveillance": 1995,
	"radar_vitesse": 2003, "casiers_colis": 2015, "atelier_velo": 2015, "agres_fitness": 2005, "rampe_skate": 1990,
	"sanisette": 1981, "bac_compost": 2015, "jardin_partage": 2000, "hotel_insectes": 2010, "banc_connecte": 2015,
	"mat_5g": 2019, "borne_drones": 2030,
	# Lot 4 (puits couvert et montoir : de tout temps).
	"barriere_octroi": 1800, "poteau_indicateur": 1800, "telegraphe_chappe": 1794, "guerite": 1800,
	"boite_lettres_fonte": 1849, "grue_quai": 1800, "eolienne_urbaine": 2015, "arbre_solaire": 2020, "brumisateur": 2019,
	"capteur_air": 2015, "parklet": 2016, "jardin_pluie": 2015, "frigo_solidaire": 2015, "toilettes_seches": 2015,
	"echange_batteries": 2019, "borne_hydrogene": 2018, "robot_livraison": 2020, "vertiport": 2030,
	# Lot 5 : machines agricoles.
	"semoir": 1960, "semoir_precision": 2010, "planteuse": 1970, "epandeur": 1965, "pulverisateur": 1960, "faucheuse": 1975,
	"presse_balles": 1975, "presse_enrubanneuse": 2005, "dechaumeur": 2005, "arracheuse": 1985, "vendangeuse": 1975,
	"tracteur_gps": 2010, "tracteur_autonome": 2035, "robot_agricole": 2032, "robot_desherbeur": 2026, "drone_agricole": 2016,
	"moissonneuse_autonome": 2030, "robot_cueilleur": 2025, "bac_insectes": 2015,
}

## Décors posés tout seuls (rues, berges, plages, fermes) : équivalents plus
## anciens, essayés dans l'ordre ; "" = rien à cette époque.
const DECORS_ANCIENS := {
	"lampadaire": ["reverbere"], "lampadaire_double": ["reverbere"], "lampadaire_boule": ["reverbere"],
	"banc_moderne": ["banc_bois"], "banc_vert": ["banc_bois"], "poubelles_tri": ["poubelle"], "conteneur": ["poubelle"],
	"bateau_moteur": ["barque"], "pedalo": ["barque"], "kayak": ["barque"], "voilier": ["barque"],
	"voilier_ancre": ["barque"], "bateau_peche": ["barque"],
	"botte_ronde": ["meule"], "botte_enrubannee": ["meule"], "botte_debout": ["meule"], "pile_bottes": ["meule"],
	"botte_carree": ["meule"], "remorque_foin": ["charrette"],
	"tracteur": ["tracteur_rouge", "tracteur_ancien", "cheval"], "tracteur_rouge": ["tracteur_ancien", "cheval"],
	"tracteur_ancien": ["cheval"], "moissonneuse": [], "serre_tunnel": [], "silo_grain": [], "citerne": ["tonneaux"],
	"abreuvoir": [], "tente_marche": ["parasol", "etal_fruits"], "parasol": ["etal_fruits"],
	"cabine_telephone": [], "panneau_publicite": ["colonne_affichage"],
	"abribus_moderne": ["abribus"], "lampadaire_solaire": ["lampadaire", "reverbere"],
	"velos_libre_service": ["arceaux_velo"], "trottinettes": [], "borne_recharge": ["pompe_essence_ancienne"],
	"conteneurs_enterres": ["poubelles_tri", "poubelle"], "poubelle_solaire": ["poubelle"], "totem_info": ["colonne_affichage"],
	"sanisette": ["vespasienne"], "banc_connecte": ["banc_moderne", "banc_bois"], "casiers_colis": [],
	"borne_drones": [], "mat_5g": ["pylone"], "radar_vitesse": [], "camera_surveillance": [],
	"brumisateur": ["borne_fontaine"], "arbre_solaire": ["lampadaire_solaire", "reverbere"], "echange_batteries": ["borne_recharge"],
	"borne_hydrogene": ["borne_recharge", "pompe_essence_ancienne"], "telegraphe_chappe": [],
}

# --- Meubles et objets de spectacle (Intérieur) ------------------------------------------

## Types de Meubles.TYPES : année d'apparition (absent = de tout temps).
const MEUBLES := {
	"meuble_tv": 1950, "refrigerateur": 1930, "lave_vaisselle": 1960, "cuisiniere": 1920, "douche": 1900,
	"baignoire": 1850, "lavabo": 1880, "wc": 1880, "meuble_vasque": 1960, "photocopieur": 1960,
	"fontaine_eau": 1950, "poste_travail": 1985, "armoire_dossiers": 1900, "vitrine_froide": 1950,
	"aquarium": 1850, "lampadaire": 1900, "casiers": 1950, "portant": 1900, "mannequin": 1850,
	# Catalogue étoffé (17 novembre 2026).
	"machine_coudre": 1851, "lampe_petrole": 1860, "glaciere": 1850, "lessiveuse": 1850, "telephone_mural": 1880,
	"phonographe": 1895, "fauteuil_club": 1920, "radio_tsf": 1922, "lit_escamotable": 1916, "juke_box": 1940,
	"flipper": 1947, "baby_foot": 1950, "lave_linge": 1950, "seche_linge": 1960, "television_tube": 1950,
	"micro_ondes": 1975, "chaine_hifi": 1970, "velo_appartement": 1970, "fauteuil_oeuf": 1958, "lampe_lave": 1963,
	"borne_arcade": 1978, "ordinateur_perso": 1981, "minitel": 1982, "canape_angle": 1990, "ecran_plat": 2005,
	"home_cinema": 1995, "bureau_assis_debout": 2012, "fauteuil_gamer": 2015, "robot_aspirateur": 2002,
	"enceinte_connectee": 2014, "tapis_course": 1990, "imprimante_3d": 2012, "ilot_induction": 2000, "cave_vin": 1990,
	"poele_granules": 2005, "hologramme": 2040, "robot_domestique": 2035,
	# Lot 4.
	"harpe": 1800, "lit_bateau": 1800, "psyche": 1810, "baignoire_zinc": 1830, "cuisiniere_fonte": 1830,
	"lanterne_magique": 1800, "chambre_photo": 1840, "frigo_connecte": 2018, "realite_virtuelle": 2016, "mur_vegetal": 2015,
	"potager_interieur": 2019, "batterie_domestique": 2020, "capsule_sommeil": 2030, "mur_ecran": 2032, "robot_cuisinier": 2033,
	"imprimante_repas": 2040,
}

## Objets de spectacle (SpectaclesObjets.TYPES).
const SPECTACLES := {
	"rampe_gaz": 1817, "panorama_peint": 1800,
	"mur_led": 2010, "laser_scene": 1980, "hologramme_scene": 2015, "drones_lumineux": 2016, "camera_robot": 2015,
	"plateau_virtuel": 2019, "casques_vr": 2016,
	"projecteurs_scene": 1880, "poursuite": 1900, "fauteuils_inclinables": 1990, "barriere_scene": 1970,
	"grand_ecran": 1900, "ecran_geant": 1953, "projecteur_numerique": 2005, "enceinte_cine": 1975,
	"comptoir_confiserie": 1930, "machine_popcorn": 1893, "borne_billets": 2000, "affiche_lumineuse": 1930,
	"console_son": 1960, "colonne_son": 1950, "amplis": 1950, "micro_pied": 1925, "retours_scene": 1970,
	"platines_dj": 1970, "panneaux_acoustiques": 1950, "boule_facettes": 1920, "camera_studio": 2005,
	"travelling": 1900, "grue_camera": 1920, "projecteur_studio": 1925, "boite_lumiere": 1960,
	"grill_projecteurs": 1900, "perche_son": 1928, "chaise_realisateur": 1910, "moniteur_retour": 1960,
	"fond_vert": 1970, "decor_chambre": 1950, "decor_rue": 1910, "decor_vaisseau": 1960, "decor_remparts": 1910,
	"decor_saloon": 1910, "cuve_tournage": 1920, "table_maquillage": 1900, "banc_montage": 1980,
	"flight_cases": 1960,
}

# --- Atelier : ouvertures, toits, aménagements -------------------------------------------

const OUVERTURES := {
	"baie": 1930, "baie_coulissante": 1950, "mur_rideau": 1950, "porte_garage": 1910, "bandeau": 1925,
	"vitrine": 1850, "vitrine_store": 1850, "fenetre_atelier": 1850,
	"fenetre_balconnet": 1850, "fenetre_store": 1880, "hublot": 1930, "baie_balconnet": 1930,
	"fenetre_balconnet_volets": 1850, "fenetre_balconnet_store": 1880, "baie_store": 1960, "baie_volets": 1970,
	"baie_balconnet_store": 1960,
}

const TOITS := {"terrasse": 1920, "dents_de_scie": 1830, "verriere": 1830, "plat_debord": 1905, "toit_vegetal": 1970,
	"toit_solaire": 1995, "verriere_pavillon": 1830, "coupole_verre": 1820, "papillon": 1950, "sheds_solaires": 2010,
	"tuiles_solaires": 2016, "toit_radiatif": 2022}

const AMENAGEMENTS := {
	"piscine": 1920, "bassin_nage": 1900, "plongeon": 1900, "pataugeoire": 1920, "spa": 1970, "bassin_animaux": 1830,
	"aquarium": 1853, "voie_normale": 1830, "voie_lgv": 1964, "voie_metrique": 1870, "voie_etroite": 1860,
	"voie_tram": 1853, "quai": 1830, "quai_couvert": 1840, "butoir": 1840, "gradins_beton": 1900,
	"tribune_couverte": 1890, "foot": 1863, "foot5": 1990, "rugby": 1871, "basket": 1891, "handball": 1920,
	"volley": 1895, "beach_volley": 1990, "tennis": 1950, "tennis_terre": 1880, "athletisme": 1880,
	"patinoire": 1876, "petanque": 1907,
	"bassin_naturel": 2000, "bassin_urbain": 2017, "voie_large": 1851, "voie_cap": 1873, "tribune_bois": 1830,
	"gradins_retractables": 1990, "cricket": 1800, "croquet": 1856, "badminton": 1873, "padel": 1990,
}

# --- Parc de loisirs : grands-huit et figures ---------------------------------------------

const FAMILLES_VOIES := {
	"bois": 1884, "acier": 1959, "mine": 1966, "familial": 1950, "suspendu": 1981, "lance": 1977,
	"splash": 1884, "buches": 1963, "riviere": 1980, "toboggan": 1960,
	"panoramique": 1887, "moulin": 1902, "tour_glissade": 1905, "bobsleigh": 1929, "train_fantome": 1930,
	"promenades": 1817, "tournant": 1997, "luge_ete": 1996, "aile": 2007, "realite_virtuelle": 2016,
}

const PIECES_VOIES := {
	"looping": 1976, "petit_looping": 1976, "vrille_g": 1975, "vrille_d": 1975, "tire_bouchon_g": 1975,
	"tire_bouchon_d": 1975, "immelmann_g": 1995, "immelmann_d": 1995, "plongeon_g": 2000, "plongeon_d": 2000,
	"vertical_haut": 1998, "quitter_vertical_haut": 1998, "vertical_bas": 1998, "quitter_vertical_bas": 1998,
	"sommet": 2003, "lanceur": 1977, "helice_g": 1959, "helice_d": 1959,
}


# --- Années ------------------------------------------------------------------------------

## Année en cours de la partie, ou très loin dans le futur hors époques (tout est permis).
static func annee_partie() -> int:
	return Epoques.annee() if Epoques.actif() else 99999


static func annee_decor(id: String) -> int:
	return int(DECORS.get(id, 0))


static func decor_disponible(id: String, annee := -1) -> bool:
	return annee_decor(id) <= (annee_partie() if annee < 0 else annee)


static var _remplace_annee := -1
static var _remplace := {}


## Décor posé tout seul : lui-même s'il existe déjà à l'époque de la partie,
## sinon son équivalent d'époque, ou "" s'il n'en a pas.
static func decor_epoque(id: String, annee := -1) -> String:
	var y := annee_partie() if annee < 0 else annee
	if annee_decor(id) <= y:
		return id
	if annee < 0:
		if _remplace_annee != y:
			_remplace_annee = y
			_remplace.clear()
		if _remplace.has(id):
			return String(_remplace[id])
	var out := ""
	for alt in DECORS_ANCIENS.get(id, []):
		var a := decor_epoque(String(alt), y)
		if a != "":
			out = a
			break
	if annee < 0:
		_remplace[id] = out
	return out


## Meuble : identifiant du catalogue (« style/type ») ou type seul.
static func annee_meuble(id: String) -> int:
	var parts := id.split("/")
	var type_id := parts[parts.size() - 1]
	if parts.size() > 1 and parts[0] == SpectaclesObjets.STYLE:
		return int(SPECTACLES.get(type_id, 0))
	if parts.size() > 1 and parts[0] == MuseeObjets.STYLE:
		return 0
	if parts.size() > 1:
		var e := Meubles.get_entry(id)
		if not e.is_empty():
			type_id = String(e.get("type", type_id))
	return int(MEUBLES.get(type_id, SPECTACLES.get(type_id, 0)))


static func meuble_disponible(id: String, annee := -1) -> bool:
	return annee_meuble(id) <= (annee_partie() if annee < 0 else annee)


static func annee_ouverture(id: String) -> int:
	return int(OUVERTURES.get(id, 0))


static func annee_toit(id: String) -> int:
	return int(TOITS.get(id, 0))


static func annee_amenagement(id: String) -> int:
	return int(AMENAGEMENTS.get(id, 0))


static func annee_famille_voie(id: String) -> int:
	return int(FAMILLES_VOIES.get(id, 0))


static func annee_piece_voie(id: String) -> int:
	return int(PIECES_VOIES.get(id, 0))


## "" si l'objet de cette année existe déjà dans la partie, sinon la raison du verrou.
static func raison(annee_objet: int) -> String:
	var y := annee_partie()
	if annee_objet <= y:
		return ""
	return "Pas encore inventé : arrive en %d (nous sommes en %d)." % [annee_objet, y]
