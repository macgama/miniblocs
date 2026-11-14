class_name SpectaclesObjets
extends RefCounted
## L'intérieur des salles de spectacle et des studios : scènes, rideaux, grands
## écrans, fauteuils, sono, instruments, régie, loges, plateaux de tournage
## (caméras, grue, travelling, fond vert, projecteurs), salle de montage,
## ateliers de costumes et de décors, foyer, bar et confiserie.
##
## Ce sont des meubles comme les autres (bible Meubles, style « spectacle »,
## ids « spectacle/<type> »), qui complètent les objets du musée déjà là
## (fauteuils rouges, piano, batterie, harpe, caméra ancienne, affiches,
## billetterie, lustre : ids « musee/… »). Champs en plus :
## - fam : famille (onglet Aménager du menu Spectacles) ;
## - estrade : hauteur (m) d'un plancher de scène (couche sol) ; les meubles
##   posés dessus sont montés à cette hauteur ;
## - sp : ce que l'objet apporte à la salle (ecran, scene, son, projection,
##   camera, lumiere, fond_vert, montage, costumes, decor, loge, orchestre…) ;
## - son : points d'acoustique ; decor : décor de tournage (western, ville,
##   chateau, espace, mer) ; service : billetterie, bar, confiserie.
##
## Les salles (fonctions de pièce) dont le mobilier se range face à la scène ou
## à l'écran (SCENES) sont aménagées par layout() : la scène (ou l'écran) contre
## le mur sans porte le plus éloigné de l'entrée, les rangées de fauteuils
## face à elle avec des allées, la régie au fond.

const STYLE := "spectacle"
const SCENE_H := 0.6

## Familles du menu (onglet Aménager), dans l'ordre.
const FAMILLES := {
	"scene": {"name": "Scène et décors", "icon": "masques", "desc": "Planchers de scène, rideaux, décors peints, projecteurs."},
	"salle": {"name": "Fauteuils et gradins", "icon": "habitants", "desc": "Chaque siège est une place vendue. Le confort compte dans la note."},
	"cinema": {"name": "Cinéma", "icon": "clap", "desc": "Grands écrans, projecteur numérique, enceintes, confiserie."},
	"musique": {"name": "Musique et sono", "icon": "micro", "desc": "Instruments, amplis, micros, colonnes de son, console de mixage."},
	"studio": {"name": "Tournage", "icon": "vue", "desc": "Caméras, grue, travelling, fond vert, projecteurs, décors de film."},
	"coulisses": {"name": "Coulisses et ateliers", "icon": "creations", "desc": "Loges, costumes, salle de montage, atelier de décors."},
	"accueil": {"name": "Foyer et accueil", "icon": "billet", "desc": "Billetterie (indispensable), bar, vestiaire, affiches, lustre."},
}
const FAMILLE_ORDER := ["scene", "salle", "cinema", "musique", "studio", "coulisses", "accueil"]

## Objets du musée et meubles ordinaires proposés aussi dans chaque famille.
const AUSSI := {
	"salle": ["musee/fauteuils_cine", "musee/cordon"],
	"cinema": ["musee/projecteur_film", "musee/affiche_film", "musee/clap"],
	"musique": ["musee/piano", "musee/batterie", "musee/harpe", "musee/guitares", "musee/juke_box"],
	"studio": ["musee/camera_cinema", "musee/decor_film", "musee/costume_film", "musee/clap", "musee/projecteur"],
	"coulisses": ["musee/machine_coudre", "contemporain/canape", "contemporain/miroir", "contemporain/wc", "contemporain/lavabo"],
	"accueil": ["musee/billetterie", "musee/vestiaire", "musee/affiche_film", "musee/lustre", "musee/banc_musee", "musee/table_cafe", "musee/file_attente",
		"contemporain/grande_plante"],
}

const TYPES := {
	# --- Scène et décors -----------------------------------------------------------------------------
	"plancher_scene": {"n": "Plancher de scène (2 × 2 m)", "k": "plancher_scene", "fam": "scene", "w": 2, "d": 2, "h": SCENE_H, "prix": 1800, "attr": 2,
		"couche": "sol", "estrade": SCENE_H, "sp": "scene"},
	"praticable": {"n": "Praticable de scène (1 × 1 m)", "k": "plancher_scene", "fam": "scene", "w": 1, "d": 1, "h": SCENE_H, "prix": 500, "attr": 1,
		"couche": "sol", "estrade": SCENE_H, "sp": "scene"},
	"rideau_fond": {"n": "Rideau de fond de scène et perche de projecteurs", "k": "rideau_fond", "fam": "scene", "w": 3, "d": 1, "h": 2.95, "prix": 2600, "attr": 3,
		"mur": true, "couche": "mur", "sp": "rideau", "son": 2, "lumiere": 2, "tags": ["lumiere"]},
	"rideau_scene": {"n": "Grand rideau rouge (côté cour, côté jardin)", "k": "rideau_scene", "fam": "scene", "w": 2, "d": 1, "h": 2.3, "prix": 3200, "attr": 5,
		"sp": "rideau", "son": 2},
	"decor_salon": {"n": "Décor de théâtre : salon bourgeois", "k": "decor_theatre", "c": "salon", "fam": "scene", "w": 3, "d": 1, "h": 2.2, "prix": 4500, "attr": 5,
		"mur": true, "sp": "decor_scene"},
	"decor_foret": {"n": "Décor de théâtre : forêt peinte", "k": "decor_theatre", "c": "foret", "fam": "scene", "w": 3, "d": 1, "h": 2.2, "prix": 3800, "attr": 5,
		"mur": true, "sp": "decor_scene"},
	"projecteurs_scene": {"n": "Projecteurs latéraux", "k": "projecteurs_scene", "fam": "scene", "w": 2, "d": 1, "h": 0.5, "prix": 1500, "attr": 2,
		"mur": true, "couche": "mur", "sp": "lumiere", "lumiere": 3, "tags": ["lumiere"]},
	"poursuite": {"n": "Projecteur de poursuite", "k": "poursuite", "fam": "scene", "w": 1, "d": 1, "h": 1.7, "prix": 2200, "attr": 2, "sp": "lumiere", "lumiere": 2,
		"tags": ["lumiere"]},
	"pupitres_orchestre": {"n": "Pupitres et chaises d'orchestre", "k": "pupitres", "fam": "scene", "w": 2, "d": 1, "h": 1.2, "prix": 900, "attr": 1, "sp": "orchestre",
		"tags": ["assise"], "places": [["musicien", -0.5, 0.45, 0.15, 0.0], ["musicien", 0.5, 0.45, 0.15, 0.0]]},
	"podium_chef": {"n": "Podium du chef d'orchestre", "k": "podium_chef", "fam": "scene", "w": 1, "d": 1, "h": 1.3, "prix": 700, "attr": 2, "sp": "orchestre"},
	# --- Fauteuils et gradins ------------------------------------------------------------------------
	"fauteuils_theatre": {"n": "Rangée de fauteuils de théâtre (velours rouge)", "k": "fauteuils", "c": "theatre", "fam": "salle", "w": 3, "d": 1, "h": 1.05, "prix": 4200,
		"attr": 4, "confort": 4, "conf": 4, "sp": "siege", "tags": ["assise"],
		"places": [["assis", -1.0, 0.45, 0.0, 0.0], ["assis", 0.0, 0.45, 0.0, 0.0], ["assis", 1.0, 0.45, 0.0, 0.0]]},
	"fauteuils_inclinables": {"n": "Fauteuils inclinables en cuir (salle premium)", "k": "fauteuils", "c": "premium", "fam": "salle", "w": 3, "d": 1, "h": 1.1, "prix": 9000,
		"attr": 6, "confort": 8, "conf": 8, "sp": "siege", "tags": ["assise"],
		"places": [["assis", -0.75, 0.45, 0.0, 0.0], ["assis", 0.75, 0.45, 0.0, 0.0]]},
	"gradins_bois": {"n": "Rangée de gradins en bois", "k": "gradins", "fam": "salle", "w": 3, "d": 1, "h": 0.45, "prix": 900, "attr": 1, "confort": 1, "conf": 1, "sp": "siege",
		"tags": ["assise"], "places": [["assis", -1.1, 0.45, 0.0, 0.0], ["assis", -0.37, 0.45, 0.0, 0.0], ["assis", 0.37, 0.45, 0.0, 0.0], ["assis", 1.1, 0.45, 0.0, 0.0]]},
	"table_cabaret": {"n": "Table de cabaret et ses chaises", "k": "table_cabaret", "fam": "salle", "w": 2, "d": 2, "h": 0.9, "prix": 1100, "attr": 3, "confort": 3, "conf": 3,
		"sp": "siege", "tags": ["table", "assise"],
		"places": [["assis", -0.55, 0.45, 0.35, 0.0], ["assis", 0.55, 0.45, 0.35, 0.0], ["assis", 0.0, 0.45, -0.6, PI]]},
	"barriere_scene": {"n": "Barrière de sécurité devant la scène", "k": "barriere", "fam": "salle", "w": 2, "d": 1, "h": 1.15, "prix": 600, "attr": 0, "sp": "barriere"},
	# --- Cinéma ---------------------------------------------------------------------------------------
	"grand_ecran": {"n": "Grand écran de cinéma (4 m)", "k": "ecran", "fam": "cinema", "w": 4, "d": 1, "h": 2.9, "prix": 9000, "attr": 6, "mur": true, "couche": "mur",
		"sp": "ecran", "tags": ["ecran"]},
	"ecran_geant": {"n": "Écran géant panoramique (6 m)", "k": "ecran", "fam": "cinema", "w": 6, "d": 1, "h": 2.9, "prix": 16000, "attr": 9, "mur": true, "couche": "mur",
		"sp": "ecran", "tags": ["ecran"]},
	"projecteur_numerique": {"n": "Projecteur numérique 4K (cabine)", "k": "projecteur_numerique", "fam": "cinema", "w": 1, "d": 1, "h": 1.6, "prix": 45000, "attr": 2,
		"sp": "projection"},
	"enceinte_cine": {"n": "Enceinte de son surround", "k": "enceinte_murale", "fam": "cinema", "w": 1, "d": 1, "h": 0.7, "prix": 1400, "attr": 1, "mur": true, "couche": "mur",
		"sp": "son", "son": 3},
	"comptoir_confiserie": {"n": "Comptoir confiserie et pop-corn", "k": "comptoir_confiserie", "fam": "cinema", "w": 3, "d": 1, "h": 1.2, "prix": 6500, "attr": 5,
		"service": "confiserie", "sp": "confiserie", "tags": ["comptoir"], "places": [["comptoir", 0.0, 0.0, -0.3, 0.0]]},
	"machine_popcorn": {"n": "Machine à pop-corn", "k": "machine_popcorn", "fam": "cinema", "w": 1, "d": 1, "h": 1.7, "prix": 2400, "attr": 4, "service": "confiserie"},
	"borne_billets": {"n": "Borne de billets", "k": "borne_billets", "fam": "cinema", "w": 1, "d": 1, "h": 1.6, "prix": 3500, "attr": 1, "service": "billetterie"},
	"affiche_lumineuse": {"n": "Caisson d'affiche lumineux", "k": "affiche_lumineuse", "fam": "cinema", "w": 1, "d": 1, "h": 1.8, "prix": 900, "attr": 4, "mur": true,
		"couche": "mur", "lumiere": 1},
	# --- Musique et sono ------------------------------------------------------------------------------
	"console_son": {"n": "Console de mixage (régie son et lumière)", "k": "console_son", "fam": "musique", "w": 2, "d": 1, "h": 1.15, "prix": 18000, "attr": 2, "sp": "regie",
		"son": 4, "tags": ["poste"], "places": [["poste", 0.0, 0.0, 0.6, PI]]},
	"colonne_son": {"n": "Colonne de sonorisation", "k": "colonne_son", "fam": "musique", "w": 1, "d": 1, "h": 2.2, "prix": 7000, "attr": 2, "sp": "son", "son": 4},
	"amplis": {"n": "Amplis de guitare et de basse", "k": "amplis", "fam": "musique", "w": 2, "d": 1, "h": 1.3, "prix": 4500, "attr": 2, "mur": true, "sp": "instrument", "son": 1},
	"micro_pied": {"n": "Micro sur pied", "k": "micro_pied", "fam": "musique", "w": 1, "d": 1, "h": 1.6, "prix": 400, "attr": 1, "sp": "micro"},
	"retours_scene": {"n": "Retours de scène", "k": "retours", "fam": "musique", "w": 2, "d": 1, "h": 0.4, "prix": 1600, "attr": 1, "sp": "son", "son": 1},
	"platines_dj": {"n": "Platines de DJ", "k": "platines", "fam": "musique", "w": 2, "d": 1, "h": 1.2, "prix": 6000, "attr": 4, "sp": "dj"},
	"contrebasse": {"n": "Contrebasse", "k": "contrebasse", "fam": "musique", "w": 1, "d": 1, "h": 1.9, "prix": 9000, "attr": 4, "sp": "instrument"},
	"panneaux_acoustiques": {"n": "Panneaux acoustiques", "k": "panneaux_acoustiques", "fam": "musique", "w": 2, "d": 1, "h": 1.6, "prix": 1200, "attr": 1, "mur": true,
		"couche": "mur", "sp": "son", "son": 3},
	"boule_facettes": {"n": "Boule à facettes", "k": "boule_facettes", "fam": "musique", "w": 1, "d": 1, "h": 0.02, "prix": 450, "attr": 4, "couche": "sol", "suspendu": true,
		"lumiere": 1, "tags": ["lumiere"]},
	# --- Tournage -------------------------------------------------------------------------------------
	"camera_studio": {"n": "Caméra de cinéma numérique sur pied", "k": "camera_studio", "fam": "studio", "w": 1, "d": 1, "h": 1.7, "prix": 60000, "attr": 3, "sp": "camera"},
	"travelling": {"n": "Rails de travelling et chariot", "k": "travelling", "fam": "studio", "w": 3, "d": 1, "h": 1.6, "prix": 15000, "attr": 3, "sp": "camera"},
	"grue_camera": {"n": "Grue de caméra", "k": "grue", "fam": "studio", "w": 2, "d": 2, "h": 2.8, "prix": 40000, "attr": 5, "sp": "camera"},
	"projecteur_studio": {"n": "Projecteur de studio (Fresnel)", "k": "fresnel", "fam": "studio", "w": 1, "d": 1, "h": 2.1, "prix": 2500, "attr": 1, "sp": "lumiere", "lumiere": 3,
		"tags": ["lumiere"]},
	"boite_lumiere": {"n": "Boîte à lumière (softbox)", "k": "softbox", "fam": "studio", "w": 1, "d": 1, "h": 1.9, "prix": 1200, "attr": 1, "sp": "lumiere", "lumiere": 2,
		"tags": ["lumiere"]},
	"grill_projecteurs": {"n": "Grill de projecteurs (au plafond)", "k": "grill", "fam": "studio", "w": 2, "d": 2, "h": 0.02, "prix": 6000, "attr": 2, "couche": "sol",
		"suspendu": true, "sp": "lumiere", "lumiere": 6, "tags": ["lumiere"]},
	"perche_son": {"n": "Perche et micro du perchiste", "k": "perche", "fam": "studio", "w": 1, "d": 1, "h": 2.2, "prix": 2000, "attr": 1, "sp": "son_tournage"},
	"chaise_realisateur": {"n": "Chaise du réalisateur", "k": "chaise_realisateur", "fam": "studio", "w": 1, "d": 1, "h": 1.2, "prix": 400, "attr": 3, "conf": 2,
		"tags": ["assise"], "places": [["assis", 0.0, 0.6, 0.0, 0.0]]},
	"moniteur_retour": {"n": "Moniteurs de retour vidéo", "k": "moniteurs", "fam": "studio", "w": 1, "d": 1, "h": 1.6, "prix": 4000, "attr": 1, "sp": "video"},
	"fond_vert": {"n": "Fond vert d'incrustation", "k": "fond_vert", "fam": "studio", "w": 3, "d": 1, "h": 2.95, "prix": 5000, "attr": 2, "mur": true, "sp": "fond_vert"},
	"decor_chambre": {"n": "Décor de série : chambre et salon (trois murs)", "k": "decor_chambre", "fam": "studio", "w": 3, "d": 3, "h": 2.6, "prix": 12000, "attr": 6,
		"sp": "decor", "decor": "ville"},
	"decor_rue": {"n": "Décor de film : façade de rue", "k": "decor_rue", "fam": "studio", "w": 3, "d": 1, "h": 2.8, "prix": 14000, "attr": 6, "mur": true, "sp": "decor",
		"decor": "ville"},
	"decor_vaisseau": {"n": "Décor de film : poste de pilotage spatial", "k": "decor_vaisseau", "fam": "studio", "w": 3, "d": 2, "h": 2.4, "prix": 22000, "attr": 8,
		"sp": "decor", "decor": "espace"},
	"decor_remparts": {"n": "Décor de film : remparts de château", "k": "decor_remparts", "fam": "studio", "w": 3, "d": 1, "h": 2.8, "prix": 16000, "attr": 7, "mur": true,
		"sp": "decor", "decor": "chateau"},
	"decor_saloon": {"n": "Décor de film : comptoir de saloon", "k": "decor_saloon", "fam": "studio", "w": 3, "d": 2, "h": 2.4, "prix": 12000, "attr": 6, "sp": "decor",
		"decor": "western"},
	"cuve_tournage": {"n": "Cuve d'eau pour scènes en mer", "k": "cuve", "fam": "studio", "w": 3, "d": 3, "h": 1.1, "prix": 18000, "attr": 5, "sp": "decor", "decor": "mer"},
	# --- Coulisses et ateliers ------------------------------------------------------------------------
	"table_maquillage": {"n": "Table de maquillage à miroir lumineux", "k": "maquillage", "fam": "coulisses", "w": 2, "d": 1, "h": 1.9, "prix": 1500, "attr": 3, "mur": true,
		"sp": "loge", "conf": 3, "lumiere": 1, "tags": ["assise", "lumiere"], "places": [["assis", -0.45, 0.45, 0.45, PI], ["assis", 0.45, 0.45, 0.45, PI]]},
	"portant_costumes": {"n": "Portant de costumes", "k": "portant_costumes", "fam": "coulisses", "w": 2, "d": 1, "h": 1.8, "prix": 2500, "attr": 4, "sp": "costumes"},
	"mannequin_couture": {"n": "Mannequin de couturière", "k": "mannequin", "fam": "coulisses", "w": 1, "d": 1, "h": 1.7, "prix": 300, "attr": 2, "sp": "costumes"},
	"table_coupe": {"n": "Grande table de coupe", "k": "table_coupe", "fam": "coulisses", "w": 3, "d": 2, "h": 0.95, "prix": 1200, "attr": 1, "sp": "costumes", "tags": ["poste"],
		"places": [["poste", 0.0, 0.0, 1.2, PI]]},
	"banc_montage": {"n": "Banc de montage (écrans et table de mixage)", "k": "banc_montage", "fam": "coulisses", "w": 2, "d": 1, "h": 1.4, "prix": 14000, "attr": 2, "mur": true,
		"sp": "montage", "tags": ["poste"], "places": [["poste", 0.0, 0.0, 0.6, PI]]},
	"etabli_decors": {"n": "Établi du décorateur", "k": "etabli", "fam": "coulisses", "w": 2, "d": 1, "h": 1.5, "prix": 1800, "attr": 1, "mur": true, "sp": "atelier",
		"tags": ["poste"], "places": [["poste", 0.0, 0.0, 0.6, PI]]},
	"flight_cases": {"n": "Caisses de matériel (flight-cases)", "k": "flight_cases", "fam": "coulisses", "w": 1, "d": 1, "h": 1.2, "prix": 600, "attr": 0},
	# --- Foyer et accueil -----------------------------------------------------------------------------
	"bar_foyer": {"n": "Bar du foyer", "k": "bar_foyer", "fam": "accueil", "w": 3, "d": 1, "h": 1.15, "prix": 7000, "attr": 6, "service": "bar", "sp": "bar",
		"tags": ["comptoir"], "places": [["comptoir", 0.0, 0.0, -0.3, 0.0]]},
	"guichet_theatre": {"n": "Guichet de location", "k": "guichet", "fam": "accueil", "w": 2, "d": 1, "h": 2.2, "prix": 5000, "attr": 4, "service": "billetterie",
		"tags": ["comptoir"], "places": [["comptoir", 0.0, 0.0, -0.3, 0.0]]},
	"affiche_spectacle": {"n": "Affiche du spectacle", "k": "affiche_spectacle", "fam": "accueil", "w": 1, "d": 1, "h": 1.6, "prix": 200, "attr": 3, "mur": true, "couche": "mur"},
}

## Fonctions des pièces (outil Fonction et « Aménager la salle »).
const SALLES := {
	"salle_projection": {"name": "Salle de projection", "famille": "cinema", "desc": "L'écran contre le mur du fond, les fauteuils en rangées face à lui, le projecteur au fond."},
	"scene_theatre": {"name": "Salle de théâtre (scène et fauteuils)", "famille": "theatre", "desc": "La scène au fond avec ses rideaux et son décor, les fauteuils face à elle."},
	"salle_lyrique": {"name": "Salle d'opéra (fosse d'orchestre)", "famille": "theatre", "desc": "Une grande scène, la fosse d'orchestre devant, puis les fauteuils."},
	"salle_concert": {"name": "Salle de concert (fosse debout)", "famille": "concert", "desc": "La scène avec batterie, amplis et sono ; devant, une fosse où l'on danse debout."},
	"salle_classique": {"name": "Auditorium (musique classique)", "famille": "concert", "desc": "L'orchestre sur scène face au chef, les fauteuils devant."},
	"club_jazz": {"name": "Salle de club (jazz, cabaret)", "famille": "concert", "desc": "Une petite scène, des tables de cabaret et le bar."},
	"foyer_spectacle": {"name": "Foyer et billetterie", "famille": "", "desc": "Billetterie (indispensable), bar, vestiaire, affiches, lustre."},
	"hall_cinema": {"name": "Hall du cinéma", "famille": "", "desc": "Billetterie, bornes, confiserie et pop-corn, affiches lumineuses."},
	"loges": {"name": "Loges des artistes", "famille": "", "desc": "Tables de maquillage, portants de costumes, un canapé pour le trac."},
	"regie": {"name": "Régie", "famille": "", "desc": "Console son et lumière, moniteurs."},
	"plateau_studio": {"name": "Plateau de tournage", "famille": "studio", "desc": "Un décor au centre, caméras, grue, travelling, projecteurs, perche et chaise du réalisateur."},
	"plateau_fond_vert": {"name": "Plateau fond vert (effets spéciaux)", "famille": "studio", "desc": "Fond vert d'incrustation, caméras et projecteurs."},
	"salle_montage": {"name": "Salle de montage et mixage", "famille": "studio", "desc": "Bancs de montage : la post-production du film se fait ici."},
	"atelier_costumes": {"name": "Atelier des costumes", "famille": "studio", "desc": "Portants, mannequins, machines à coudre, table de coupe."},
	"atelier_decors": {"name": "Atelier des décors", "famille": "studio", "desc": "Établis, décors en cours, caisses de matériel."},
}
const SALLE_ORDER := ["salle_projection", "hall_cinema", "scene_theatre", "salle_lyrique", "salle_concert", "salle_classique", "club_jazz", "foyer_spectacle", "loges", "regie",
	"plateau_studio", "plateau_fond_vert", "salle_montage", "atelier_costumes", "atelier_decors"]

## Salles où le public regarde une scène ou un écran (rangées face à elle) :
## profondeur de la scène (part de la profondeur, min, max), sièges, rangée de départ.
const SCENES := {
	"salle_projection": {"scene": [0.0, 0, 0], "siege": "musee/fauteuils_cine"},
	"scene_theatre": {"scene": [0.3, 3, 6], "siege": "spectacle/fauteuils_theatre"},
	"salle_lyrique": {"scene": [0.3, 4, 7], "siege": "spectacle/fauteuils_theatre", "fosse": 2},
	"salle_concert": {"scene": [0.25, 3, 5], "siege": ""},
	"salle_classique": {"scene": [0.35, 4, 7], "siege": "spectacle/fauteuils_theatre"},
	"club_jazz": {"scene": [0.25, 2, 3], "siege": "spectacle/table_cabaret"},
}

## Mobilier des autres salles (même forme que Mobilier.LAYOUTS ; ids complets).
const LAYOUTS := {
	"foyer_spectacle": [[["spectacle/guichet_theatre", "musee/billetterie"], "mur", 1, true], [["spectacle/bar_foyer"], "mur", 1, false],
		[["musee/vestiaire"], "mur", 1, false], [["spectacle/affiche_spectacle"], "accroche", 4, false], [["musee/banc_musee"], "mur", 2, false],
		[["musee/table_cafe"], "remplir", 3, false], [["musee/lustre"], "sol", 2, false], [["contemporain/grande_plante"], "coin", 2, false]],
	"hall_cinema": [[["musee/billetterie"], "mur", 1, true], [["spectacle/comptoir_confiserie"], "mur", 1, true], [["spectacle/machine_popcorn"], "coin", 1, false],
		[["spectacle/borne_billets"], "mur", 2, false], [["spectacle/affiche_lumineuse"], "accroche", 5, false], [["musee/file_attente"], "centre", 1, false],
		[["musee/banc_musee"], "mur", 1, false], [["contemporain/grande_plante"], "coin", 2, false]],
	"loges": [[["spectacle/table_maquillage"], "remplir_mur", 3, true], [["spectacle/portant_costumes"], "mur", 2, false], [["canape"], "mur", 1, false],
		[["spectacle/flight_cases"], "coin", 1, false], [["plante"], "coin", 1, false]],
	"regie": [[["spectacle/console_son"], "mur", 1, true], [["spectacle/moniteur_retour"], "mur", 1, false], [["spectacle/flight_cases"], "coin", 2, false]],
	"plateau_studio": [[["spectacle/decor_chambre", "spectacle/decor_saloon", "spectacle/decor_vaisseau"], "centre", 1, true],
		[["spectacle/decor_rue", "spectacle/decor_remparts"], "mur", 1, false], [["spectacle/camera_studio"], "centre", 2, true], [["spectacle/travelling"], "centre", 1, false],
		[["spectacle/grue_camera"], "coin", 1, false], [["spectacle/projecteur_studio"], "coin", 3, false], [["spectacle/boite_lumiere"], "centre", 2, false],
		[["spectacle/perche_son"], "centre", 1, false], [["spectacle/chaise_realisateur"], "centre", 1, false], [["spectacle/moniteur_retour"], "centre", 1, false],
		[["spectacle/grill_projecteurs"], "sol", 2, false], [["spectacle/flight_cases"], "mur", 2, false]],
	"plateau_fond_vert": [[["spectacle/fond_vert"], "mur", 3, true], [["spectacle/camera_studio"], "centre", 2, true], [["spectacle/grue_camera"], "coin", 1, false],
		[["spectacle/projecteur_studio"], "coin", 3, false], [["spectacle/boite_lumiere"], "centre", 2, false], [["spectacle/moniteur_retour"], "centre", 1, false],
		[["spectacle/grill_projecteurs"], "sol", 2, false], [["spectacle/cuve_tournage"], "centre", 1, false]],
	"salle_montage": [[["spectacle/banc_montage"], "remplir_mur", 4, true], [["spectacle/console_son"], "centre", 1, false], [["canape"], "mur", 1, false],
		[["musee/affiche_film"], "accroche", 2, false], [["plante"], "coin", 1, false]],
	"atelier_costumes": [[["spectacle/portant_costumes"], "remplir_mur", 4, true], [["spectacle/table_coupe"], "centre", 1, false], [["musee/machine_coudre"], "mur", 2, false],
		[["spectacle/mannequin_couture"], "coin", 3, false], [["miroir"], "accroche", 1, false]],
	"atelier_decors": [[["spectacle/etabli_decors"], "remplir_mur", 3, true], [["spectacle/decor_foret", "spectacle/decor_salon"], "mur", 2, false],
		[["spectacle/flight_cases"], "remplir", 4, false], [["spectacle/projecteur_studio"], "coin", 1, false]],
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
			e["id"] = "%s/%s" % [STYLE, tid]
			e["type"] = tid
			e["style"] = STYLE
			e["name"] = String(t.n)
			e["region"] = "monde"
			e["era"] = "contemporain"
			e["conf"] = int(t.get("conf", 0))
			e["attr"] = int(t.get("attr", 0))
			e["couche"] = String(t.get("couche", "meuble"))
			e["mur"] = bool(t.get("mur", false))
			e["p"] = ["spectacle", String(t.fam)]
			var tags: Array = (t.get("tags", []) as Array).duplicate()
			tags.append("spectacle")
			e["tags"] = tags
			e["places"] = t.get("places", [])
			_entries.append(e)
	return _entries


static func is_spectacle(id: String) -> bool:
	return id.begins_with(STYLE + "/")


## Ids d'une famille (onglet Aménager), dans l'ordre, avec les objets du musée utiles.
static func of_famille(fam: String) -> Array:
	var out := []
	for tid in TYPES:
		if String(TYPES[tid].fam) == fam:
			out.append("%s/%s" % [STYLE, tid])
	for id in AUSSI.get(fam, []):
		if Meubles.has(String(id)):
			out.append(String(id))
	return out


static func salle_name(fn: String) -> String:
	return String(SALLES[fn].name) if SALLES.has(fn) else ""


static func count() -> int:
	return TYPES.size()


# --- Fonctions devinées des pièces --------------------------------------------------------------

## La pièce où l'on entre (une porte vers l'extérieur), au rez-de-chaussée.
static func _hall(mob: Mobilier, id: String, rooms: Array) -> Dictionary:
	var p: Dictionary = mob.pe.plans[id]
	for r in rooms:
		if int(r.e) != 0:
			continue
		for c in r.cells:
			for d in Mobilier.DIRS:
				var w: Dictionary = mob.wall_at(id, 0, c, d)
				if Mobilier.is_door(w) and not p.floors.has(Vector3i((c + d).x, 0, (c + d).y)):
					return r
	return {}


const GUESS_SALLE := {"cinema": "salle_projection", "theatre": "scene_theatre", "concert": "salle_concert", "studio_cine": "plateau_studio"}
const GUESS_ACCUEIL := {"cinema": "hall_cinema", "studio_cine": "bureau"}


## Fonctions devinées (Mobilier._guess_group) pour les usages cinema, theatre,
## concert et studio_cine.
static func guess(mob: Mobilier, id: String, u: String, big: Array, small: Array, assign: Callable) -> void:
	var hall := _hall(mob, id, big + small)
	var salle := String(GUESS_SALLE.get(u, "scene_theatre"))
	var accueil := String(GUESS_ACCUEIL.get(u, "foyer_spectacle"))
	if hall.is_empty() and big.size() >= 2:
		hall = big[big.size() - 1]
	var i := 0
	for r in big:
		if r == hall:
			assign.call(r, accueil)
			continue
		var fn: String = salle
		match u:
			"cinema":
				fn = "salle_projection" if int(r.area) >= 30 or i == 0 else "regie"
			"theatre":
				fn = "scene_theatre" if i == 0 or int(r.area) >= 80 else ("loges" if i == 1 else "atelier_costumes")
			"concert":
				if i == 0:
					fn = "salle_concert" if int(r.area) >= 70 else "club_jazz"
				else:
					fn = "loges" if i == 1 else "regie"
			"studio_cine":
				if i == 0 or int(r.area) >= 120:
					fn = "plateau_studio"
				elif int(r.area) >= 70:
					fn = "plateau_fond_vert"
				else:
					fn = ["salle_montage", "atelier_costumes", "atelier_decors", "loges"][(i - 1) % 4]
		assign.call(r, fn)
		i += 1
	var sdb := false
	for r in small:
		if r == hall:
			assign.call(r, accueil)
		elif not sdb:
			assign.call(r, "sdb")
			sdb = true
		else:
			assign.call(r, "loges" if u != "cinema" else "reserve")


# --- Salles face à la scène ---------------------------------------------------------------------

## Pose un meuble à une place précise (si elle est libre) ; sur_scene : un
## plancher de scène peut couvrir l'entrée d'une porte (on y monte de plain-pied).
static func _try(mob: Mobilier, st: Dictionary, m: String, c: Vector2i, r: int, sur_scene := false, zone := {}) -> bool:
	var ent := Meubles.get_entry(m)
	if ent.is_empty():
		return false
	var layer := Mobilier.layer_index(ent)
	for cc in Meubles.cells_of(ent, c, r):
		if not zone.is_empty() and not zone.has(cc):
			return false
		if not st.inroom.has(cc) or st.taken.has(Vector3i(cc.x, layer, cc.y)) or st.bl.has(cc):
			return false
		if layer != 2 and st.keep.has(cc) and not sur_scene:
			return false
	if mob.check(String(st.id), int(st.e), c, r, m, st.bl) != "":
		return false
	for cc in Meubles.cells_of(ent, c, r):
		st.taken[Vector3i(cc.x, layer, cc.y)] = true
	(st.res as Array).append([c, r, layer, m])
	return true


## Aménage une salle de SCENES dans st (Mobilier._layout).
static func layout(mob: Mobilier, st: Dictionary, cells: Array, fn: String) -> void:
	var cfg: Dictionary = SCENES[fn]
	var id: String = st.id
	var e: int = st.e
	var p: Dictionary = mob.pe.plans[id]
	# Mur de la scène : plein, sans porte, en face des portes d'entrée.
	var solid := {}
	var doors := {}
	for d in Mobilier.DIRS:
		solid[d] = 0
		doors[d] = 0
		for c in cells:
			if st.inroom.has(c + d):
				continue
			var w: Dictionary = p.walls.get(Mobilier.edge_key(c, e, d), {})
			if w.is_empty():
				continue
			if Mobilier.is_door(w):
				# Les entrées du public comptent double (passages, portes doubles, arcades).
				doors[d] = int(doors[d]) + (2 if String(w.get("o", "")) in ["passage", "arcade", "porte_double", "porte_vitree"] else 1)
			elif Mobilier.sill(w) >= 2.2:
				solid[d] = int(solid[d]) + 1
	# L'entrée du public : le côté qui a le plus de portes ; la scène lui fait face.
	var entree := Vector2i.ZERO
	for d in Mobilier.DIRS:
		if int(doors[d]) > 0 and (entree == Vector2i.ZERO or int(doors[d]) > int(doors[entree])):
			entree = d
	var best_d := Vector2i(0, 1)
	var best_s := -INF
	for d in Mobilier.DIRS:
		var s := float(solid[d]) - 50.0 * float(doors[d]) + (40.0 if entree != Vector2i.ZERO and d == -entree else 0.0)
		if s > best_s:
			best_s = s
			best_d = d
	var r_face := 0
	for i in 4:
		if Meubles.back_dir(i) == best_d:
			r_face = i
	var r_seat := (r_face + 2) % 4
	var lateral := Vector2i(absi(best_d.y), absi(best_d.x))
	# Distance de chaque case au mur de la scène, et position le long de ce mur.
	var at := {} # Vector2i(dist, lat) -> case
	var dist := {}
	var dmax := 0
	var lo := 1 << 30
	var hi := -(1 << 30)
	for c in cells:
		var k := 0
		var cc: Vector2i = c
		while st.inroom.has(cc + best_d):
			cc += best_d
			k += 1
		dist[c] = k
		dmax = maxi(dmax, k)
		var lat: int = c.x * lateral.x + c.y * lateral.y
		lo = mini(lo, lat)
		hi = maxi(hi, lat)
		at[Vector2i(k, lat)] = c
	var width := hi - lo + 1
	var depth := dmax + 1
	var mid := (lo + hi) / 2
	# Ancre (coin −x −z) du meuble m posé de face, sa première rangée à la distance
	# k de la scène, son bord gauche à lat (ses w cases le long de la scène, ses d
	# cases en profondeur) ; null s'il sort de la salle.
	var anchor := func(k: int, lat: int, m: String) -> Variant:
		var en := Meubles.get_entry(m)
		var fw := int(en.get("w", 1))
		var fd := int(en.get("d", 1))
		var mn := Vector2i(1 << 30, 1 << 30)
		for i in fd:
			for j in fw:
				var cc: Variant = at.get(Vector2i(k + i, lat + j))
				if cc == null:
					return null
				mn = Vector2i(mini(mn.x, (cc as Vector2i).x), mini(mn.y, (cc as Vector2i).y))
		return mn
	var sc: Array = cfg.scene
	var D := 0
	if float(sc[0]) > 0.0:
		D = clampi(roundi(depth * float(sc[0])), int(sc[1]), int(sc[2]))
		D = mini(D, maxi(1, depth - 3))
	var stage: Array = []
	var audience: Array = []
	for c in cells:
		(stage if int(dist[c]) < D else audience).append(c)
	# --- La scène ------------------------------------------------------------------------------
	if D > 0:
		var zone := {}
		for c in stage:
			zone[c] = true
		for c in stage:
			_try(mob, st, "spectacle/plancher_scene", c, 0, true, zone)
		for c in stage:
			_try(mob, st, "spectacle/praticable", c, 0, true, zone)
		# Le rideau de fond, d'un bout à l'autre du mur de scène.
		var lat0 := lo + (width % 3) / 2
		while lat0 + 2 <= hi:
			var af: Variant = anchor.call(0, lat0, "spectacle/rideau_fond")
			if af != null:
				_try(mob, st, "spectacle/rideau_fond", af, r_face)
			lat0 += 3
		# Grand rideau aux deux bouts du bord de scène.
		if width >= 6:
			for lat in [lo, hi - 1]:
				var a: Variant = anchor.call(D - 1, lat, "spectacle/rideau_scene")
				if a != null:
					_try(mob, st, "spectacle/rideau_scene", a, r_face)
	match fn:
		"scene_theatre", "salle_lyrique":
			var dec := "spectacle/decor_salon" if fn == "scene_theatre" else "spectacle/decor_foret"
			var ad: Variant = anchor.call(0, mid - 1, dec)
			if ad == null or not _try(mob, st, dec, ad, r_face):
				mob._place_one(st, dec, "mur", stage, false)
			if fn == "salle_lyrique" and width >= 12:
				for off in [-4, 2]:
					var ad2: Variant = anchor.call(0, mid + int(off), "spectacle/decor_foret")
					if ad2 != null:
						_try(mob, st, "spectacle/decor_foret", ad2, r_face)
		"salle_concert":
			var a2: Variant = anchor.call(0, mid - 1, "musee/batterie")
			if a2 != null:
				_try(mob, st, "musee/batterie", a2, r_face)
			for i in 2:
				mob._place_one(st, "spectacle/amplis", "mur", stage, false)
			for lat in [mid - 3, mid, mid + 3]:
				var a3: Variant = anchor.call(D - 1, lat, "spectacle/micro_pied")
				if a3 != null:
					_try(mob, st, "spectacle/micro_pied", a3, r_face)
			for lat in [lo, hi]:
				var a4: Variant = anchor.call(D - 1, lat, "spectacle/colonne_son")
				if a4 != null and not _try(mob, st, "spectacle/colonne_son", a4, r_face):
					var a5: Variant = anchor.call(D - 2, lat, "spectacle/colonne_son")
					if a5 != null:
						_try(mob, st, "spectacle/colonne_son", a5, r_face)
			var a6: Variant = anchor.call(D - 1, mid - 5, "spectacle/retours_scene")
			if a6 != null:
				_try(mob, st, "spectacle/retours_scene", a6, r_face)
		"salle_classique":
			# L'orchestre face au public, le chef devant, le piano côté jardin.
			for k in range(0, D - 1):
				var lat2 := lo + 1
				while lat2 + 1 <= hi - 1:
					var a7: Variant = anchor.call(k, lat2, "spectacle/pupitres_orchestre")
					if a7 != null:
						_try(mob, st, "spectacle/pupitres_orchestre", a7, r_face)
					lat2 += 3
			var a8: Variant = anchor.call(D - 1, mid, "spectacle/podium_chef")
			if a8 != null:
				_try(mob, st, "spectacle/podium_chef", a8, r_seat)
			var a9: Variant = anchor.call(D - 3, lo + 1, "musee/piano")
			if a9 != null:
				_try(mob, st, "musee/piano", a9, r_face)
			mob._place_one(st, "musee/harpe", "coin", stage, false)
		"club_jazz":
			var b1: Variant = anchor.call(0, mid - 1, "musee/batterie")
			if b1 != null:
				_try(mob, st, "musee/batterie", b1, r_face)
			if D >= 3:
				var b2: Variant = anchor.call(0, mid - 4, "musee/piano")
				if b2 != null:
					_try(mob, st, "musee/piano", b2, r_face)
			var b3: Variant = anchor.call(0, mid + 2, "spectacle/contrebasse")
			if b3 != null:
				_try(mob, st, "spectacle/contrebasse", b3, r_face)
			var b4: Variant = anchor.call(D - 1, mid + 1, "spectacle/micro_pied")
			if b4 != null:
				_try(mob, st, "spectacle/micro_pied", b4, r_face)
	# --- L'écran -------------------------------------------------------------------------------
	if fn == "salle_projection":
		var ecran := "spectacle/ecran_geant" if width >= 10 else ("spectacle/grand_ecran" if width >= 6 else "musee/ecran_video")
		var ew := int(Meubles.get_entry(ecran).w)
		var a10: Variant = anchor.call(0, mid - ew / 2 + (1 if ew % 2 == 0 and width % 2 == 1 else 0), ecran)
		if a10 == null or not _try(mob, st, ecran, a10, r_face):
			mob._place_one(st, ecran, "accroche", cells, true)
		for i in 4:
			mob._place_one(st, "spectacle/enceinte_cine", "accroche", audience, false)
	# --- Fosse d'orchestre ---------------------------------------------------------------------
	var start := D + 1
	if fn == "salle_projection":
		start = maxi(2, depth / 5)
	var fosse := int(cfg.get("fosse", 0))
	if fosse > 0:
		for k in range(D, D + fosse):
			var lat3 := lo + 1
			while lat3 + 1 <= hi - 1:
				var a11: Variant = anchor.call(k, lat3, "spectacle/pupitres_orchestre")
				if a11 != null:
					_try(mob, st, "spectacle/pupitres_orchestre", a11, r_face)
				lat3 += 2
		start = D + fosse + 1
	# --- Le public -----------------------------------------------------------------------------
	var siege := String(cfg.siege)
	var last := dmax - 1 if depth >= 6 else dmax
	if fn == "salle_concert":
		# Barrière devant la scène, puis la fosse debout.
		var lat4 := lo + 1
		while lat4 + 1 <= hi - 1:
			var a12: Variant = anchor.call(D, lat4, "spectacle/barriere_scene")
			if a12 != null:
				_try(mob, st, "spectacle/barriere_scene", a12, r_face)
			lat4 += 2
		mob._place_one(st, "spectacle/boule_facettes", "sol", audience, false)
	elif fn == "club_jazz":
		var aud2: Array = []
		for c in audience:
			if int(dist[c]) >= D + 1:
				aud2.append(c)
		mob._place_one(st, "spectacle/bar_foyer", "mur", aud2, false)
		for i in maxi(2, aud2.size() / 7):
			if not mob._place_one(st, siege, "remplir", aud2, false):
				break
	elif siege != "":
		var sw := int(Meubles.get_entry(siege).w)
		var aisles := {}
		if width >= 7:
			aisles[lo] = true
			aisles[hi] = true
		if width >= 14:
			aisles[mid] = true
		for k in range(start, last + 1):
			var run: Array = []
			for lat5 in range(lo, hi + 1):
				var c5: Variant = at.get(Vector2i(k, lat5))
				var free := false
				if c5 != null and not aisles.has(lat5):
					var cv5: Vector2i = c5
					free = not st.keep.has(cv5) and not st.taken.has(Vector3i(cv5.x, 1, cv5.y)) and not st.bl.has(cv5)
				if not free:
					run.clear()
					continue
				run.append(lat5)
				if run.size() == sw:
					var a13: Variant = anchor.call(k, int(run[0]), siege)
					if a13 != null:
						_try(mob, st, siege, a13, r_seat)
					run.clear()
		if fn != "salle_projection":
			var a14: Variant = anchor.call(int(start + last) / 2, mid - 1, "musee/lustre")
			if a14 != null:
				_try(mob, st, "musee/lustre", a14, 0)
	# --- Le fond de salle : projection, régie, poursuite ----------------------------------------
	var fond := "spectacle/projecteur_numerique" if fn == "salle_projection" else ("" if fn == "club_jazz" else "spectacle/console_son")
	if fond != "":
		var r_fond := r_seat if fn == "salle_projection" else r_face
		var k_fond := dmax if fn == "salle_projection" else maxi(start, dmax - 1)
		var placed := false
		for off in [0, 1, -1, 2, -2, 3, -3]:
			var a15: Variant = at.get(Vector2i(k_fond, mid + int(off)))
			if a15 != null and _try(mob, st, fond, a15, r_fond):
				placed = true
				break
		if not placed:
			mob._place_one(st, fond, "centre", audience, false)
	if fn in ["scene_theatre", "salle_lyrique", "salle_concert"]:
		var a16: Variant = at.get(Vector2i(dmax, lo + 1))
		if a16 != null:
			_try(mob, st, "spectacle/poursuite", a16, r_seat)
		for i in 2:
			mob._place_one(st, "spectacle/projecteurs_scene", "accroche", audience, false)
	if fn == "salle_classique" or fn == "scene_theatre":
		for i in maxi(1, width / 6):
			mob._place_one(st, "spectacle/panneaux_acoustiques", "accroche", audience, false)


# --- Analyse d'un bâtiment en murs fins ---------------------------------------------------------

const USAGE_FAMILLE := {"cinema": "cinema", "theatre": "theatre", "concert": "concert"}
const PRIX := {"cinema": 9.0, "theatre": 22.0, "concert": 24.0}


static func is_usage(u: String) -> bool:
	return u in ["cinema", "theatre", "concert", "studio_cine"]


## Ce qu'il y a dans un bâtiment en murs fins de spectacle : fiche au format
## de SpectaclesTypes.spec_of (role, famille, places, salles, confort,
## acoustique, prix, genres ; plateaux et annexes pour un studio), plus les
## manques et le détail (scene, ecran, billetterie, debout, assis).
static func analyse(mob: Mobilier, id: String) -> Dictionary:
	var u := mob.usage_of(id)
	var out := {"role": "studio" if u == "studio_cine" else "salle", "famille": String(USAGE_FAMILLE.get(u, "")), "places": 0, "salles": 0, "confort": 0.3,
		"acoustique": 0.3, "prix": float(PRIX.get(u, 15.0)), "genres": [], "plan": true, "manques": [], "assis": 0, "debout": 0, "scene": 0, "ecrans": 0,
		"billetterie": false, "plateaux": 0, "annexes": {"plateau": 0, "decors": {}, "vfx": false, "postprod": false, "atelier": false}, "fonctions": {}}
	if mob.pe == null or not mob.pe.plans.has(id):
		return out
	var guesses := mob.guess_functions(id)
	var sp := {} # sp -> nombre
	var seat_conf := 0.0
	var seats := 0
	var son := 0.0
	var aud_area := 0
	var services := {}
	var occ: Dictionary = mob._occ_of(id)
	for e in mob.pe.levels_of(id):
		for r in mob.rooms(id, int(e)):
			var fn := mob.function_of(id, r, guesses)
			out.fonctions[fn] = int(out.fonctions.get(fn, 0)) + 1
			var public := SCENES.has(fn)
			var cells := {}
			for c in r.cells:
				cells[c] = true
			var room_sp := {}
			for k in mob.items.get(id, {}):
				var kk: Vector4i = k
				if kk.y != int(e) or not cells.has(Vector2i(kk.x, kk.z)):
					continue
				var ent := Meubles.get_entry(String(mob.items[id][k].m))
				if ent.is_empty():
					continue
				var s := String(ent.get("sp", ""))
				if String(ent.type) == "fauteuils_cine":
					s = "siege"
				elif String(ent.type) in ["piano", "harpe", "batterie"]:
					s = "instrument_" + String(ent.type)
				elif String(ent.type) == "camera_cinema":
					s = "camera"
				elif String(ent.type) == "decor_film":
					s = "decor"
				elif String(ent.type) == "ecran_video" and fn == "salle_projection":
					s = "ecran"
				if s != "":
					sp[s] = int(sp.get(s, 0)) + 1
					room_sp[s] = int(room_sp.get(s, 0)) + 1
				var sv := String(ent.get("service", ""))
				if sv != "":
					services[sv] = int(services.get(sv, 0)) + 1
				son += float(ent.get("son", 0))
				if s == "decor" and String(ent.get("decor", "western" if String(ent.type) == "decor_film" else "")) != "":
					out.annexes.decors[String(ent.get("decor", "western"))] = true
				if public:
					for pl in ent.places:
						if String(pl[0]) == "assis":
							seats += 1
							seat_conf += float(ent.get("confort", ent.get("conf", 2)))
			if public:
				aud_area += int(r.area)
			if fn == "salle_projection" and int(room_sp.get("ecran", 0)) > 0:
				out.salles = int(out.salles) + 1
			if fn == "salle_concert":
				# Fosse debout : deux personnes par m² libre hors de la scène.
				for c in r.cells:
					var cv: Vector2i = c
					if occ.has(Vector4i(cv.x, int(e), cv.y, 0)) or occ.has(Vector4i(cv.x, int(e), cv.y, 1)):
						continue
					out.debout = int(out.debout) + 2
			if fn in ["plateau_studio", "plateau_fond_vert"] and int(room_sp.get("camera", 0)) > 0:
				out.plateaux = int(out.plateaux) + 1
			if fn == "plateau_fond_vert" and int(room_sp.get("fond_vert", 0)) > 0:
				out.annexes.vfx = true
			if int(room_sp.get("montage", 0)) > 0:
				out.annexes.postprod = true
			if int(room_sp.get("costumes", 0)) + int(room_sp.get("atelier", 0)) > 0:
				out.annexes.atelier = true
	if int(sp.get("fond_vert", 0)) > 0:
		out.annexes.vfx = true
	out.assis = seats
	out.scene = int(sp.get("scene", 0))
	out.ecrans = int(sp.get("ecran", 0))
	out.billetterie = int(services.get("billetterie", 0)) > 0
	out.places = seats + int(out.debout)
	var manques: Array = out.manques
	if u == "studio_cine":
		if int(out.plateaux) == 0:
			manques.append("pas de plateau de tournage avec une caméra")
		out.confort = 0.5
		return out
	if not bool(out.billetterie):
		manques.append("pas de billetterie : personne ne peut acheter sa place")
	if int(out.places) == 0:
		manques.append("pas une seule place pour le public (fauteuils, tables ou fosse)")
	match u:
		"cinema":
			if int(out.salles) == 0:
				manques.append("pas d'écran dans une salle de projection")
			if int(sp.get("projection", 0)) == 0:
				manques.append("pas de projecteur : l'écran reste noir")
			out.salles = maxi(1, int(out.salles))
			out.genres = SpectaclesTypes.G_FILMS.duplicate()
			out["art_essai"] = int(out.places) < 220
		"theatre":
			if int(out.scene) == 0:
				manques.append("pas de scène (planchers de scène)")
			var g := ["theatre_classique", "comedie", "boulevard", "drame", "humour", "marionnettes"]
			if int(sp.get("orchestre", 0)) >= 4:
				g.append_array(["opera", "ballet", "comedie_musicale"])
			if int(out.scene) >= 8:
				g.append_array(["danse", "chanson"])
				if not g.has("comedie_musicale"):
					g.append("comedie_musicale")
			out.genres = g
		"concert":
			if int(out.scene) == 0:
				manques.append("pas de scène (planchers de scène)")
			var g2 := []
			if int(sp.get("instrument_batterie", 0)) > 0 or int(sp.get("instrument", 0)) > 0:
				g2.append_array(["rock", "pop", "chanson", "monde", "metal"])
			if int(sp.get("dj", 0)) > 0 or int(sp.get("son", 0)) >= 2:
				g2.append_array(["electro", "rap"])
			if int(sp.get("instrument_piano", 0)) > 0 or int(sp.get("orchestre", 0)) >= 4 or int(sp.get("instrument_harpe", 0)) > 0:
				g2.append_array(["classique", "jazz"])
			if (out.fonctions as Dictionary).has("club_jazz"):
				g2.append_array(["jazz", "chanson", "monde", "humour"])
			if g2.is_empty():
				g2 = ["chanson", "jazz", "monde"]
			var uniq := []
			for x in g2:
				if not uniq.has(x):
					uniq.append(x)
			out.genres = uniq
	if not bool(services.has("bar")) and u != "cinema":
		out["sans_bar"] = true
	# Confort : les sièges, les services ; acoustique : rideaux, enceintes, régie, panneaux.
	var avg := seat_conf / float(seats) if seats > 0 else 2.0
	if int(out.debout) > 0 and seats == 0:
		avg = 2.5
	var bonus := 0.05 * float(mini(3, services.size()))
	if (out.fonctions as Dictionary).has("sdb"):
		bonus += 0.05
	out.confort = clampf(0.2 + avg * 0.08 + bonus, 0.1, 1.0)
	var besoin := maxf(2.0, float(aud_area) / 30.0)
	out.acoustique = clampf(0.3 + 0.55 * minf(1.0, son / besoin) + (0.1 if int(sp.get("regie", 0)) > 0 or int(sp.get("projection", 0)) > 0 else 0.0), 0.2, 1.0)
	return out


## Emplois d'un bâtiment de spectacle en murs fins (Mobilier.stats).
static func emplois(a: Dictionary) -> int:
	if String(a.role) == "studio":
		return 0 if int(a.plateaux) == 0 else 6 + int(a.plateaux) * 8 + (4 if bool(a.annexes.postprod) else 0) + (3 if bool(a.annexes.atelier) else 0)
	if not bool(a.billetterie) or int(a.places) == 0:
		return 0
	var n := 2 + int(a.places) / 150
	match String(a.famille):
		"cinema":
			n += maxi(1, int(a.salles) / 3)
		_:
			n += 3
	if not a.has("sans_bar"):
		n += 1
	return n
