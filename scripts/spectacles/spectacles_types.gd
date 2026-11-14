class_name SpectaclesTypes
extends RefCounted
## Spectacles : bâtiments de la catégorie « Spectacles » du panneau Construire
## (cinémas, studios de cinéma et leurs annexes, salles de concert, théâtres).
##
## Même format que BuildingCatalog, plus un champ "spect" qui dit le rôle :
## - "salle" : on y vient voir un spectacle. "famille" : "cinema", "concert" ou
##   "theatre" ; "places" ; "salles" (écrans d'un cinéma) ; "genres" (ce que la
##   salle peut accueillir, voir SpectaclesProgrammes.GENRES) ; "confort" et
##   "acoustique" (0–1, font la note de la salle) ; "plein_air" (fermé l'hiver,
##   annulé sous la pluie, sauf "abrite") ; "prix" (billet par défaut, €).
## - "studio" : studios de cinéma. "plateaux" : films tournés en même temps.
## - "annexe" : à moins de Spectacles.RAYON_STUDIO mètres d'un studio. "annexe"
##   dit ce qu'elle apporte : "plateau" (un plateau de plus), "decor" (avec
##   "decor" : western, ville, chateau, espace, mer), "vfx" (effets spéciaux),
##   "postprod" (montage plus court et meilleur), "atelier" (décors et costumes
##   moins chers).
## Le champ "role" (cinema, salle_concert, theatre, studio_cinema) sert aux
## loisirs des habitants (Metiers.LOISIRS) et aux nuisances (bruit des concerts).

const CATEGORY := "spectacles"
const ROAD := ["route"]
const RP := ["route", "chemin"]

## Genres de chaque famille de salles (raccourcis).
const G_FILMS := ["action", "comedie_film", "drame_film", "animation", "horreur", "sf", "policier", "aventure", "romance", "documentaire", "western", "historique"]
const G_ACTUELLES := ["rock", "pop", "rap", "electro", "metal", "chanson", "monde", "jazz"]

const TYPES := {
	# --- Cinémas --------------------------------------------------------------------------------
	"cinema_art_essai": {"name": "Cinéma d'art et d'essai", "w": 18, "d": 28, "access": RP, "emplois": 6, "cost": 2_200_000, "role": "cinema",
		"spect": {"role": "salle", "famille": "cinema", "places": 320, "salles": 2, "confort": 0.6, "acoustique": 0.6, "prix": 8.0, "genres": G_FILMS, "art_essai": true},
		"metiers": [["agent_cinema", 3], ["projectionniste", 2], ["cadre", 1]],
		"desc": "Deux salles, une affiche peinte et un public qui reste pour le générique. Les films de qualité y marchent mieux."},
	"multiplexe": {"name": "Multiplexe (12 salles)", "w": 64, "d": 52, "access": ROAD, "emplois": 40, "cost": 22_000_000, "role": "cinema",
		"spect": {"role": "salle", "famille": "cinema", "places": 2600, "salles": 12, "confort": 0.85, "acoustique": 0.8, "prix": 11.5, "genres": G_FILMS, "regional": true},
		"metiers": [["agent_cinema", 28], ["projectionniste", 6], ["serveur", 4], ["cadre", 2]],
		"desc": "Douze écrans, fauteuils inclinables, seaux de pop-corn géants. Attire aussi les villes voisines."},
	"cinema_plein_air": {"name": "Cinéma en plein air", "w": 40, "d": 46, "access": RP, "emplois": 4, "cost": 350_000, "role": "cinema",
		"spect": {"role": "salle", "famille": "cinema", "places": 500, "salles": 1, "confort": 0.45, "acoustique": 0.4, "prix": 6.0, "genres": G_FILMS, "plein_air": true},
		"metiers": [["agent_cinema", 2], ["projectionniste", 2]],
		"desc": "Écran gonflable de 16 m, transats et couvertures. De mai à septembre, à la nuit tombée, s'il ne pleut pas."},
	"drive_in": {"name": "Drive-in", "w": 70, "d": 80, "access": ROAD, "emplois": 6, "cost": 900_000, "role": "cinema",
		"spect": {"role": "salle", "famille": "cinema", "places": 420, "salles": 1, "confort": 0.55, "acoustique": 0.5, "prix": 9.0, "genres": G_FILMS, "plein_air": true, "abrite": true},
		"metiers": [["agent_cinema", 3], ["projectionniste", 1], ["serveur", 2]],
		"desc": "160 places de voiture face à un écran géant, le son par l'autoradio. Il peut pleuvoir : on reste au sec."},
	# --- Studios de cinéma ----------------------------------------------------------------------
	"studio_cinema": {"name": "Studios de cinéma", "w": 90, "d": 70, "access": ROAD, "emplois": 60, "cost": 28_000_000, "role": "studio_cinema",
		"spect": {"role": "studio", "plateaux": 2},
		"metiers": [["technicien_plateau", 26], ["decorateur", 10], ["monteur", 6], ["producteur", 6], ["realisateur", 2], ["agent_accueil_parc", 4], ["cadre", 6]],
		"desc": "Bureaux de production, deux grands plateaux et un château d'eau à l'ancienne. On y tourne des films (menu Spectacles → Studios)."},
	"plateau_tournage": {"name": "Plateau de tournage insonorisé", "w": 40, "d": 30, "access": [], "emplois": 10, "cost": 4_500_000, "role": "studio_cinema",
		"spect": {"role": "annexe", "annexe": "plateau"},
		"metiers": [["technicien_plateau", 8], ["decorateur", 2]],
		"desc": "Un hangar de 14 m sous plafond, noir et silencieux : un film de plus en tournage à la fois."},
	"decor_western": {"name": "Décor de ville western", "w": 60, "d": 40, "access": [], "emplois": 2, "cost": 1_800_000, "role": "studio_cinema",
		"spect": {"role": "annexe", "annexe": "decor", "decor": "western"},
		"desc": "Saloon, banque, prison et rue poussiéreuse. Les façades n'ont pas d'arrière : ne pas s'y adosser."},
	"decor_ville": {"name": "Décor de rue de grande ville", "w": 60, "d": 36, "access": [], "emplois": 2, "cost": 2_600_000, "role": "studio_cinema",
		"spect": {"role": "annexe", "annexe": "decor", "decor": "ville"},
		"desc": "Immeubles de briques, escaliers de secours, taxi jaune et bouche d'égout qui fume (à la demande)."},
	"decor_chateau": {"name": "Décor de château fort", "w": 50, "d": 50, "access": [], "emplois": 2, "cost": 3_200_000, "role": "studio_cinema",
		"spect": {"role": "annexe", "annexe": "decor", "decor": "chateau"},
		"desc": "Remparts en polystyrène peint, donjon et pont-levis. Bon pour les films historiques et d'aventure."},
	"decor_spatial": {"name": "Décor de base spatiale", "w": 44, "d": 40, "access": [], "emplois": 2, "cost": 2_900_000, "role": "studio_cinema",
		"spect": {"role": "annexe", "annexe": "decor", "decor": "espace"},
		"desc": "Dôme, sas, antenne et sol de planète rouge. Pour la science-fiction (le vide spatial n'est pas fourni)."},
	"bassin_tournage": {"name": "Bassin de tournage", "w": 44, "d": 44, "access": [], "emplois": 3, "cost": 3_000_000, "role": "studio_cinema",
		"spect": {"role": "annexe", "annexe": "decor", "decor": "mer"},
		"desc": "Bassin de 2 m de fond, machine à vagues et fond peint en horizon. Naufrages, pirates et tempêtes."},
	"studio_effets": {"name": "Studio d'effets spéciaux (fond vert)", "w": 34, "d": 26, "access": [], "emplois": 12, "cost": 6_000_000, "role": "studio_cinema",
		"spect": {"role": "annexe", "annexe": "vfx"},
		"metiers": [["monteur", 8], ["technicien_plateau", 4]],
		"desc": "Fond vert de 30 m, capture de mouvement et serveurs de calcul. Indispensable pour la science-fiction et l'animation."},
	"post_production": {"name": "Post-production (montage, mixage)", "w": 22, "d": 18, "access": [], "emplois": 10, "cost": 2_400_000, "role": "studio_cinema",
		"spect": {"role": "annexe", "annexe": "postprod"},
		"metiers": [["monteur", 8], ["producteur", 2]],
		"desc": "Salles de montage, auditorium de mixage et étalonnage : un montage plus court et un meilleur film."},
	"atelier_decors_cinema": {"name": "Atelier de décors et costumes", "w": 30, "d": 22, "access": [], "emplois": 12, "cost": 1_400_000, "role": "studio_cinema",
		"spect": {"role": "annexe", "annexe": "atelier"},
		"metiers": [["decorateur", 9], ["couturier", 3]],
		"desc": "Menuiserie, peinture et couture sur place : les films coûtent 12 % de moins."},
	# --- Salles de concert ----------------------------------------------------------------------
	"club_jazz": {"name": "Club de jazz", "w": 14, "d": 20, "access": RP, "emplois": 5, "cost": 900_000, "role": "salle_concert",
		"spect": {"role": "salle", "famille": "concert", "places": 150, "confort": 0.6, "acoustique": 0.75, "prix": 18.0,
			"genres": ["jazz", "chanson", "monde", "classique", "humour"]},
		"metiers": [["serveur", 3], ["technicien_spectacle", 1], ["cadre", 1]],
		"desc": "Cave voûtée, lumière tamisée, piano droit. Le saxophoniste joue parfois jusqu'à 2 h du matin."},
	"salle_musiques_actuelles": {"name": "Salle de musiques actuelles", "w": 32, "d": 40, "access": ROAD, "emplois": 14, "cost": 7_000_000, "role": "salle_concert",
		"spect": {"role": "salle", "famille": "concert", "places": 1100, "confort": 0.5, "acoustique": 0.75, "prix": 25.0, "genres": G_ACTUELLES + ["humour"]},
		"metiers": [["technicien_spectacle", 5], ["regisseur", 2], ["ouvreur", 4], ["serveur", 2], ["cadre", 1]],
		"desc": "Fosse debout de 1 100 places, bar et studios de répétition. Rock, rap, électro : ça fait du bruit le soir."},
	"auditorium": {"name": "Auditorium philharmonique", "w": 50, "d": 60, "access": ROAD, "emplois": 30, "cost": 38_000_000, "role": "salle_concert",
		"spect": {"role": "salle", "famille": "concert", "places": 2400, "confort": 0.95, "acoustique": 1.0, "prix": 38.0,
			"genres": ["classique", "jazz", "chanson", "monde", "opera"]},
		"metiers": [["musicien", 14], ["technicien_spectacle", 5], ["regisseur", 2], ["ouvreur", 7], ["cadre", 2]],
		"desc": "Salle en vignoble autour de l'orchestre, acoustique réglée au millimètre. Son orchestre résident en fait partie."},
	"arena_concert": {"name": "Aréna de concerts", "w": 110, "d": 90, "access": ROAD, "emplois": 60, "cost": 90_000_000, "role": "salle_concert",
		"spect": {"role": "salle", "famille": "concert", "places": 9000, "confort": 0.6, "acoustique": 0.6, "prix": 55.0, "regional": true,
			"genres": ["pop", "rock", "rap", "electro", "metal", "chanson", "humour", "comedie_musicale", "cirque"]},
		"metiers": [["technicien_spectacle", 18], ["regisseur", 4], ["ouvreur", 26], ["serveur", 8], ["cadre", 4]],
		"desc": "9 000 places pour les tournées des grandes stars. Toute la région vient, en voiture : prévois des routes."},
	"scene_festival": {"name": "Scène de festival en plein air", "w": 120, "d": 110, "access": ROAD, "emplois": 20, "cost": 2_500_000, "role": "salle_concert",
		"spect": {"role": "salle", "famille": "concert", "places": 25000, "confort": 0.3, "acoustique": 0.5, "prix": 49.0, "plein_air": true, "festival": true, "regional": true,
			"genres": G_ACTUELLES},
		"metiers": [["technicien_spectacle", 10], ["regisseur", 2], ["ouvreur", 6], ["serveur", 2]],
		"desc": "Grande scène, écrans géants et prairie. Festival les vendredis et samedis de mai à septembre : 4 groupes par soir."},
	# --- Théâtres -------------------------------------------------------------------------------
	"cafe_theatre": {"name": "Café-théâtre", "w": 14, "d": 18, "access": RP, "emplois": 4, "cost": 700_000, "role": "theatre",
		"spect": {"role": "salle", "famille": "theatre", "places": 90, "confort": 0.5, "acoustique": 0.5, "prix": 16.0,
			"genres": ["humour", "boulevard", "comedie", "chanson", "marionnettes"]},
		"metiers": [["serveur", 2], ["comedien", 1], ["technicien_spectacle", 1]],
		"desc": "Une petite scène, un bar et des humoristes qui débutent. Le premier rang est en danger."},
	"theatre_italienne": {"name": "Théâtre à l'italienne", "w": 36, "d": 48, "access": ROAD, "emplois": 22, "cost": 18_000_000, "role": "theatre",
		"spect": {"role": "salle", "famille": "theatre", "places": 750, "confort": 0.8, "acoustique": 0.85, "prix": 30.0,
			"genres": ["theatre_classique", "comedie", "boulevard", "drame", "comedie_musicale", "opera", "ballet", "humour", "danse", "chanson"]},
		"metiers": [["comedien", 6], ["technicien_spectacle", 5], ["regisseur", 2], ["ouvreur", 6], ["couturier", 1], ["cadre", 2]],
		"desc": "Salle en fer à cheval, balcons dorés et lustre de cristal. Pièces, comédies musicales, opéras de poche."},
	"scene_contemporaine": {"name": "Scène contemporaine (centre dramatique)", "w": 40, "d": 44, "access": ROAD, "emplois": 18, "cost": 16_000_000, "role": "theatre",
		"spect": {"role": "salle", "famille": "theatre", "places": 900, "confort": 0.75, "acoustique": 0.8, "prix": 22.0,
			"genres": ["drame", "theatre_classique", "danse", "comedie", "marionnettes", "cirque", "monde", "electro"]},
		"metiers": [["comedien", 5], ["technicien_spectacle", 5], ["regisseur", 2], ["ouvreur", 4], ["cadre", 2]],
		"desc": "Boîte noire modulable en béton et verre. Créations, danse et pièces qui font débat au café d'en face."},
	"opera_coupole": {"name": "Grand opéra à coupole", "w": 60, "d": 80, "access": ROAD, "emplois": 70, "cost": 75_000_000, "role": "theatre",
		"spect": {"role": "salle", "famille": "theatre", "places": 1900, "confort": 1.0, "acoustique": 1.0, "prix": 65.0,
			"genres": ["opera", "ballet", "classique", "comedie_musicale", "danse"]},
		"metiers": [["musicien", 22], ["danseur", 16], ["comedien", 8], ["technicien_spectacle", 10], ["regisseur", 3], ["ouvreur", 8], ["couturier", 2], ["cadre", 3]],
		"desc": "Grand escalier, coupole verte et cage de scène de 40 m. Opéras, ballets et galas : le prestige de la ville."},
	"theatre_verdure": {"name": "Théâtre de verdure", "w": 50, "d": 46, "access": RP, "emplois": 3, "cost": 600_000, "role": "theatre",
		"spect": {"role": "salle", "famille": "theatre", "places": 700, "confort": 0.4, "acoustique": 0.6, "prix": 14.0, "plein_air": true,
			"genres": ["theatre_classique", "comedie", "chanson", "jazz", "classique", "danse", "cirque", "marionnettes", "fanfare", "monde"]},
		"metiers": [["technicien_spectacle", 2], ["ouvreur", 1]],
		"desc": "Gradins de pierre et d'herbe en demi-cercle sous les arbres. Shakespeare au coucher du soleil, l'été."},
	"chapiteau_cirque": {"name": "Chapiteau de cirque", "w": 46, "d": 46, "access": RP, "emplois": 6, "cost": 1_200_000, "role": "theatre",
		"spect": {"role": "salle", "famille": "theatre", "places": 1400, "confort": 0.45, "acoustique": 0.45, "prix": 24.0,
			"genres": ["cirque", "humour", "marionnettes", "comedie_musicale", "fanfare"]},
		"metiers": [["technicien_spectacle", 3], ["ouvreur", 3]],
		"desc": "Toile rayée, piste de 13 m et gradins. Acrobates, clowns et jongleurs, matinée le mercredi et le week-end."},
}
const ORDER := ["cinema_art_essai", "multiplexe", "cinema_plein_air", "drive_in",
	"studio_cinema", "plateau_tournage", "decor_western", "decor_ville", "decor_chateau", "decor_spatial", "bassin_tournage",
	"studio_effets", "post_production", "atelier_decors_cinema",
	"club_jazz", "salle_musiques_actuelles", "auditorium", "arena_concert", "scene_festival",
	"cafe_theatre", "theatre_italienne", "scene_contemporaine", "opera_coupole", "theatre_verdure", "chapiteau_cirque"]

## Bâtiments d'autres catalogues reconnus comme salles.
const AUTRES := {
	"cinema": {"role": "salle", "famille": "cinema", "places": 600, "salles": 4, "confort": 0.65, "acoustique": 0.65, "prix": 9.5, "genres": G_FILMS},
	"kiosque_musique": {"role": "salle", "famille": "concert", "places": 250, "confort": 0.3, "acoustique": 0.4, "prix": 0.0, "plein_air": true,
		"genres": ["fanfare", "jazz", "chanson", "classique", "monde"]},
	"theatre": {"role": "salle", "famille": "theatre", "places": 650, "confort": 0.75, "acoustique": 0.8, "prix": 26.0,
		"genres": ["theatre_classique", "comedie", "boulevard", "drame", "comedie_musicale", "opera", "ballet", "humour", "danse", "chanson", "classique"]},
	# Bible Blender (assets/modeles/bible).
	"opera": {"role": "salle", "famille": "theatre", "places": 1900, "confort": 0.95, "acoustique": 1.0, "prix": 60.0,
		"genres": ["opera", "ballet", "classique", "comedie_musicale", "danse"]},
	"cinema_multiplexe": {"role": "salle", "famille": "cinema", "places": 1800, "salles": 8, "confort": 0.8, "acoustique": 0.75, "prix": 11.0,
		"genres": G_FILMS, "regional": true},
	"salle_concert": {"role": "salle", "famille": "concert", "places": 4000, "confort": 0.6, "acoustique": 0.7, "prix": 40.0, "regional": true,
		"genres": ["pop", "rock", "rap", "electro", "metal", "chanson", "jazz", "monde", "humour", "comedie_musicale", "classique"]},
	"amphitheatre_romain": {"role": "salle", "famille": "theatre", "places": 5000, "confort": 0.3, "acoustique": 0.7, "prix": 25.0, "plein_air": true,
		"genres": ["theatre_classique", "opera", "classique", "rock", "pop", "chanson", "cirque", "monde", "danse"]},
}

const FAMILLES := {
	"cinema": {"name": "Cinéma", "icon": "clap"},
	"concert": {"name": "Concert", "icon": "micro"},
	"theatre": {"name": "Théâtre", "icon": "masques"},
}


static func entries() -> Dictionary:
	var out := {}
	for id in ORDER:
		var t: Dictionary = TYPES[id].duplicate()
		t["cat"] = CATEGORY
		t["region"] = "monde"
		t["era"] = "moderne"
		t["style"] = ""
		t["visiteurs"] = int(t.spect.get("places", 0))
		out[id] = t
	return out


## Rôle d'un type de bâtiment pour les spectacles ({} si aucun). Les modèles de
## l'atelier prennent celui de leur fonction ; les théâtres de la bible des
## styles (opéra, cinéma Art déco, amphithéâtre…) sont reconnus par leur archétype.
static func spec_of(type_id: String) -> Dictionary:
	var base := BuildingCatalog.base_of(type_id)
	if TYPES.has(base):
		return TYPES[base].spect
	if AUTRES.has(base):
		return AUTRES[base]
	var t := BuildingCatalog.get_type(base)
	if String(t.get("role", "")) == "cinema" and t.has("glb"):
		return AUTRES.cinema
	if String(t.get("arch", t.get("role", ""))) == "theatre" and (t.has("arch") or t.has("glb")):
		var nom := String(t.get("name", "")).to_lower()
		if nom.contains("musée"):
			return {}
		if nom.contains("cinéma"):
			return AUTRES.cinema
		return AUTRES.theatre
	return {}


static func role_of(type_id: String) -> String:
	return String(spec_of(type_id).get("role", ""))


static func of_famille(f: String) -> Array:
	var out: Array = []
	for id in ORDER:
		if String(TYPES[id].spect.get("famille", "")) == f:
			out.append(id)
	return out


static func of_role(role: String) -> Array:
	var out: Array = []
	for id in ORDER:
		if String(TYPES[id].spect.role) == role:
			out.append(id)
	return out


# --- Modèles (front = −Z, côté route) -------------------------------------------------------------

const BETON := Color("b9b6ae")
const BETON_F := Color("8e8b84")
const ASPHALTE := Color("55585e")
const NOIR := Color("26252b")
const NUIT := Color("3d3a4b")
const ROUGE := Color("b8222c")
const ROUGE_F := Color("7e1820")
const OR := Color("e2b440")
const CREME := Color("efe6d2")
const PIERRE := Color("e2d8c2")
const VITRE := Color("33495e")
const NEON := Color("fff3b0")
const BLEU := Color("2a5d9a")
const VERT := Color("4f9a3a")
const VERT_F := Color("3c7a2c")
const BOIS := Color("8a5a36")
const BOIS_C := Color("c49a62")
const SABLE := Color("d8b878")
const BLANC := Color("f2f2ee")
const METAL := Color("8a9096")
const BRIQUE := Color("9a4a32")
const CUIVRE := Color("5e9a86")


static func build(k: BlocMesh, id: String, t: Dictionary) -> void:
	var w := float(t.w)
	var d := float(t.d)
	match id:
		"cinema_art_essai":
			k.plate(0, 0, w, d, BETON)
			k.box(0, 0, 2.0, 16.0, 9.0, 23.0, Color("c8b49a"))
			k.box(0, 9.0, 2.0, 16.4, 0.4, 23.4, Color("8a6a4a"))
			k.box(0, 0, -9.55, 6.0, 3.0, 0.2, VITRE)
			k.box(0, 3.2, -10.3, 15.0, 0.25, 1.8, ROUGE_F)
			k.box(0, 4.2, -9.8, 10.0, 2.2, 0.3, Color("1d3557"))
			k.box(0, 4.6, -9.98, 8.0, 1.4, 0.06, NEON)
			for x in [-5.5, 5.5]:
				k.box(x, 0.6, -9.6, 2.2, 3.0, 0.1, Color("e9c46a"))
			k.windows_row(0, -9.6, 14.0, 7.0, 4, 1.2, 1.2, VITRE)
		"multiplexe":
			k.plate(0, 0, w, d, ASPHALTE)
			k.box(0, 0, 6.0, 60.0, 14.0, 38.0, NUIT)
			k.box(0, 14.0, 6.0, 60.4, 0.6, 38.4, Color("2b2836"))
			# Hall vitré en avancée, auvent et enseigne lumineuse.
			k.box(0, 0, -16.0, 30.0, 10.0, 8.0, VITRE)
			k.box(0, 10.0, -16.0, 31.0, 0.5, 9.0, Color("2b2836"))
			k.box(0, 4.2, -20.6, 34.0, 0.3, 2.4, Color("f2c14e"))
			k.box(0, 11.0, -12.4, 26.0, 5.0, 0.6, ROUGE)
			k.box(0, 12.0, -12.75, 22.0, 3.0, 0.1, NEON)
			for i in 6:
				k.box(-25.0 + i * 10.0, 1.2, -12.95, 3.0, 4.5, 0.1, [Color("e63946"), Color("2a9d8f"), Color("e9c46a"), Color("457b9d"), Color("f4a261"), Color("8e44ad")][i])
			for i in 5:
				k.plate(-24.0 + i * 12.0, -23.5, 0.15, 4.0, BLANC, 0.0, 0.1)
		"cinema_plein_air":
			k.plate(0, 0, w, d, VERT)
			# Écran gonflable sur pieds, au fond (+Z), le public face à lui.
			k.box(0, 1.0, 19.0, 18.0, 9.0, 0.8, BLANC)
			k.box(0, 0, 19.6, 19.0, 1.0, 1.6, Color("1d1d22"))
			for x in [-9.6, 9.6]:
				k.cylinder(x, 0, 19.4, 0.6, 0.5, 10.4, 8, Color("2a5d9a"))
			for r in 6:
				for c in 8:
					k.box(-12.6 + c * 3.6, 0.08, 8.0 - r * 3.6, 1.0, 0.45, 1.6, [Color("e76f51"), Color("2a9d8f"), Color("e9c46a"), BLEU][(r + c) % 4])
			# Cabine de projection et buvette.
			k.box(0, 0, -16.0, 4.0, 3.2, 3.0, BOIS)
			k.box(0, 3.2, -16.0, 4.4, 0.3, 3.4, Color("5a3a24"))
			k.box(12.0, 0, -17.0, 6.0, 2.6, 4.0, Color("e9c46a"))
			for x in [-16.0, 16.0]:
				k.tree(x, -6.0, 1.4)
				k.tree(x, 8.0, 1.2)
		"drive_in":
			k.plate(0, 0, w, d, ASPHALTE)
			k.box(0, 0, 34.0, 4.0, 3.0, 4.0, BETON_F)
			k.box(0, 3.0, 34.0, 36.0, 15.0, 1.0, BLANC)
			k.box(0, 3.0, 34.6, 37.0, 15.4, 0.4, Color("3a3d42"))
			for x in [-14.0, 0.0, 14.0]:
				k.box(x, 0, 34.8, 1.2, 3.0, 1.2, Color("3a3d42"))
			# Allées en arc et voitures garées.
			var cols := [Color("c8322a"), Color("2a5d9a"), Color("e9c46a"), Color("f2f2ee"), Color("2a9d8f"), Color("3a3d42")]
			for r in 5:
				var z := 20.0 - r * 9.0
				k.plate(0, z + 2.6, 60.0, 0.15, Color("e8d89a"), 0.0, 0.1)
				for c in 10:
					if (r * 10 + c) % 3 == 0:
						continue
					var x := -27.0 + c * 6.0
					k.box(x, 0.2, z, 1.8, 0.8, 4.2, cols[(r + c * 2) % cols.size()])
					k.box(x, 1.0, z + 0.4, 1.6, 0.6, 2.0, Color(cols[(r + c * 2) % cols.size()]).darkened(0.25))
					k.cylinder(x + 1.6, 0, z - 2.2, 0.06, 0.06, 1.1, 4, METAL)
			# Snack et guichet à l'entrée.
			k.box(-20.0, 0, -32.0, 12.0, 3.4, 8.0, Color("f4a261"))
			k.box(-20.0, 3.4, -32.0, 12.6, 0.4, 8.6, ROUGE)
			k.box(14.0, 0, -36.0, 3.0, 2.8, 3.0, BLANC)
			k.box(14.0, 3.4, -37.5, 8.0, 2.6, 0.4, ROUGE)
			k.box(14.0, 3.8, -37.75, 6.4, 1.6, 0.08, NEON)
		"studio_cinema":
			k.plate(0, 0, w, d, BETON)
			# Deux grands plateaux (hangars à toit en voûte) au fond.
			for x in [-22.0, 22.0]:
				k.box(x, 0, 14.0, 38.0, 13.0, 36.0, Color("e6dcc6"))
				k.lathe(x, 13.0, 14.0, [Vector2(19.0, 0), Vector2(14.0, 3.0), Vector2(0.0, 4.0)], 4, Color("c8bfae"))
				k.box(x, 0, -4.05, 8.0, 9.0, 0.3, Color("6e6a62"))
				k.box(x, 10.0, -4.1, 10.0, 1.6, 0.1, Color("1d3557"))
			# Bureaux de production Art déco et portail.
			k.box(-20.0, 0, -22.0, 34.0, 8.0, 12.0, CREME)
			k.box(-20.0, 8.0, -22.0, 34.6, 0.5, 12.6, OR)
			k.window_bands(-20.0, -22.0, 34.0, 12.0, 0.0, 2, 4.0, VITRE)
			k.box(18.0, 0, -32.0, 1.2, 7.0, 1.2, CREME)
			k.box(32.0, 0, -32.0, 1.2, 7.0, 1.2, CREME)
			k.box(25.0, 6.0, -32.0, 15.0, 1.6, 1.0, CREME)
			k.box(25.0, 6.3, -32.55, 12.0, 1.0, 0.08, OR)
			# Château d'eau à l'ancienne (logo du studio).
			k.cylinder(36.0, 0, -12.0, 0.3, 0.3, 12.0, 4, METAL)
			k.cylinder(36.0, 12.0, -12.0, 3.0, 3.0, 4.0, 10, Color("6a8ab0"))
			k.pyramid(36.0, 16.0, -12.0, 6.4, 6.4, 1.6, Color("4a6a90"))
		"plateau_tournage":
			k.plate(0, 0, w, d, BETON)
			k.box(0, 0, 0, 36.0, 14.0, 26.0, Color("d8d0c0"))
			k.box(0, 14.0, 0, 36.6, 0.5, 26.6, Color("8e8b84"))
			k.box(0, 0, -13.05, 10.0, 10.0, 0.3, Color("6e6a62"))
			k.box(10.0, 11.0, -13.1, 3.0, 1.2, 0.2, ROUGE)
			k.box(-12.0, 0, -13.05, 1.4, 2.4, 0.2, Color("4a4a4e"))
			k.box(0, 15.0, 4.0, 6.0, 1.6, 3.0, METAL)
		"decor_western":
			k.plate(0, 0, w, d, SABLE)
			var facs := [["SALOON", Color("a8683a")], ["BANQUE", Color("c8b49a")], ["PRISON", Color("8e7a62")], ["HÔTEL", Color("b07848")], ["FORGE", Color("6e4a30")]]
			for i in facs.size():
				var x := -24.0 + i * 12.0
				var col: Color = facs[i][1]
				for side in [-1.0, 1.0]:
					var z: float = side * 11.0
					k.box(x, 0, z, 10.0, 6.5 + (i % 2) * 1.5, 0.4, col)
					k.box(x, 0, z - side * 1.6, 10.0, 0.4, 3.0, BOIS)
					k.box(x, 3.2, z - side * 2.9, 10.0, 0.2, 0.3, BOIS)
					for px in [-4.5, 4.5]:
						k.box(x + px, 0, z - side * 2.9, 0.25, 3.2, 0.25, BOIS)
					k.box(x, 2.0, z - side * 0.25, 2.0, 2.4, 0.1, Color("3a2416"))
			# Abreuvoir, chariot, cactus, rails pour la caméra.
			k.box(0, 0, 0, 3.0, 0.8, 1.0, BOIS)
			k.box(14.0, 0.6, 2.0, 2.6, 1.0, 4.0, BOIS_C)
			for zz in [-0.8, 3.2]:
				k.cylinder(15.4, 0, zz + 1.6, 0.7, 0.7, 0.15, 8, Color("3a2416"))
			for p in [Vector2(-26.0, 0.0), Vector2(26.0, -3.0), Vector2(22.0, 4.0)]:
				k.cylinder(p.x, 0, p.y, 0.45, 0.4, 3.2, 6, VERT_F)
				k.cylinder(p.x + 0.7, 1.4, p.y, 0.22, 0.2, 1.2, 5, VERT_F)
			k.plate(0, -4.0, 40.0, 0.3, METAL, 0.0, 0.12)
		"decor_ville":
			k.plate(0, 0, w, d, ASPHALTE)
			k.plate(0, 0, w, 8.0, Color("4a4d52"), 0.0, 0.1)
			for i in 5:
				var x := -24.0 + i * 12.0
				for side in [-1.0, 1.0]:
					var z: float = side * 11.0
					var h := 14.0 + float((i * 7 + int(side + 1.0) * 3) % 5) * 2.0
					var col := BRIQUE.lightened(0.08 * float((i + int(side)) % 3))
					k.box(x, 0, z, 11.0, h, 0.5, col)
					k.plate(x, z - side * 2.2, 11.0, 4.0, Color("a8a49c"), 0.0, 0.18)
					k.windows_row(x, z - side * 0.3, 10.0, 3.5, 3, 1.4, 1.8, VITRE)
					k.windows_row(x, z - side * 0.3, 10.0, 7.5, 3, 1.4, 1.8, VITRE)
					k.windows_row(x, z - side * 0.3, 10.0, 11.5, 3, 1.4, 1.8, VITRE)
					# Escaliers de secours.
					k.box(x + 2.0, 6.0, z - side * 0.9, 4.0, 0.15, 1.2, NOIR)
					k.box(x + 2.0, 10.0, z - side * 0.9, 4.0, 0.15, 1.2, NOIR)
			# Taxi jaune, bouche d'incendie, réverbère.
			k.box(-6.0, 0.25, 1.5, 1.9, 0.8, 4.6, Color("f2c230"))
			k.box(-6.0, 1.05, 1.7, 1.7, 0.6, 2.4, Color("d8a820"))
			k.cylinder(8.0, 0, -6.0, 0.25, 0.25, 0.8, 6, ROUGE)
			k.cylinder(14.0, 0, -6.2, 0.1, 0.1, 5.0, 4, NOIR)
		"decor_chateau":
			k.plate(0, 0, w, d, VERT)
			var pierre := Color("9e968a")
			for s in [-1.0, 1.0]:
				k.box(0, 0, 18.0 * s, 36.0, 8.0, 2.0, pierre)
				k.box(18.0 * s, 0, 0, 2.0, 8.0, 36.0, pierre)
				for i in 9:
					k.box(-16.0 + i * 4.0, 8.0, 18.0 * s, 1.6, 1.2, 2.0, pierre)
			for c in [Vector2(-18, -18), Vector2(18, -18), Vector2(-18, 18), Vector2(18, 18)]:
				k.cylinder(c.x, 0, c.y, 3.4, 3.2, 12.0, 10, pierre.darkened(0.08))
				k.cylinder(c.x, 12.0, c.y, 3.8, 0.0, 5.0, 10, Color("4a5a8a"))
			k.box(0, 0, 4.0, 12.0, 18.0, 12.0, pierre.darkened(0.04))
			k.pyramid(0, 18.0, 4.0, 13.0, 13.0, 6.0, Color("4a5a8a"))
			k.box(0, 0, -19.1, 5.0, 5.0, 0.3, Color("3a2416"))
			k.box(0, 0.05, -22.0, 5.0, 0.3, 6.0, BOIS)
			k.plate(0, -22.0, 44.0, 3.0, Color("4a7aa0"), 0.0, 0.05)
			k.box(0, 0, 19.2, 36.0, 8.0, 0.2, Color("6e6a62"))
		"decor_spatial":
			k.plate(0, 0, w, d, Color("b85a34"))
			for p in [Vector2(-8, 6), Vector2(10, 8), Vector2(0, -8)]:
				k.dome(p.x, 0, p.y, 7.0 if p.y > 0 else 5.0, 6.0 if p.y > 0 else 4.0, BLANC, 12)
			k.box(1.0, 0, 7.0, 8.0, 2.6, 2.6, Color("d8d8d8"))
			k.box(-4.0, 0, -2.0, 2.6, 2.6, 8.0, Color("d8d8d8"))
			k.cylinder(16.0, 0, -12.0, 0.3, 0.3, 9.0, 4, METAL)
			k.lathe(16.0, 9.0, -12.0, [Vector2(0.4, 0), Vector2(3.0, 1.4), Vector2(3.2, 1.6)], 10, BLANC)
			for r in [Vector2(-16, -10), Vector2(-14, 14), Vector2(18, 12)]:
				k.box(r.x, 0, r.y, 3.0, 1.6, 2.4, Color("8a3a24"))
			k.cylinder(-12.0, 0, -14.0, 1.2, 0.2, 8.0, 6, Color("d8d8d8"))
		"bassin_tournage":
			k.plate(0, 0, w, d, BETON)
			k.box(0, 0, 2.0, 38.0, 0.8, 34.0, BETON_F)
			k.plate(0, 2.0, 36.0, 32.0, Color("3a7aa8"), 0.8, 0.05)
			k.box(0, 0.8, 19.0, 38.0, 12.0, 0.6, Color("9ac4e0"))
			k.box(0, 0.8, 19.4, 38.0, 0.3, 0.3, BLANC)
			# Galion à moitié construit, machine à vagues.
			k.box(-4.0, 0.6, 2.0, 5.0, 2.4, 14.0, BOIS)
			k.box(-4.0, 3.0, 6.0, 5.0, 1.4, 4.0, BOIS.darkened(0.15))
			k.cylinder(-4.0, 3.0, 0.0, 0.2, 0.2, 9.0, 5, Color("5a3a24"))
			k.box(-4.0, 6.0, 0.0, 0.1, 3.6, 4.0, BLANC)
			k.box(16.0, 0.8, 14.0, 4.0, 3.0, 4.0, METAL)
			k.box(-17.0, 0, -18.0, 6.0, 3.0, 4.0, Color("e6dcc6"))
		"studio_effets":
			k.plate(0, 0, w, d, BETON)
			k.box(0, 0, 1.0, 32.0, 12.0, 22.0, Color("3a3d42"))
			k.box(0, 12.0, 1.0, 32.4, 0.4, 22.4, Color("26282c"))
			k.box(0, 0, -10.05, 12.0, 2.8, 0.2, VITRE)
			k.box(0, 4.0, -10.15, 20.0, 5.0, 0.1, Color("2fbf4a"))
			k.box(0, 9.5, -10.2, 14.0, 1.4, 0.1, NEON)
			for i in 4:
				k.box(-12.0 + i * 8.0, 12.4, 6.0, 3.0, 1.2, 3.0, METAL)
		"post_production":
			k.plate(0, 0, w, d, BETON)
			k.box(0, 0, 1.0, 20.0, 7.0, 14.0, Color("e6e1d3"))
			k.box(0, 7.0, 1.0, 20.4, 0.4, 14.4, Color("5e6b73"))
			k.window_bands(0, 1.0, 20.0, 14.0, 0.0, 2, 3.5, VITRE)
			k.box(0, 0, -6.1, 3.0, 2.6, 0.2, Color("1d3557"))
			k.box(6.0, 7.4, 4.0, 3.0, 1.4, 3.0, METAL)
		"atelier_decors_cinema":
			k.plate(0, 0, w, d, BETON)
			k.box(0, 0, 3.0, 28.0, 8.0, 16.0, Color("b8a68a"))
			k.gable(0, 8.0, 3.0, 28.4, 16.4, 3.0, Color("7e6a52"))
			k.box(-6.0, 0, -5.05, 8.0, 6.0, 0.2, Color("6e6a62"))
			# Décors en attente devant l'atelier (façade, colonne, rocher).
			k.box(6.0, 0, -8.0, 6.0, 5.0, 0.3, Color("d8c8a8"))
			k.cylinder(-2.0, 0, -8.0, 0.6, 0.6, 4.0, 8, BLANC)
			k.box(10.0, 0, -7.0, 2.4, 1.8, 2.0, Color("8a7a66"))
		"club_jazz":
			k.plate(0, 0, w, d, Color("7e7468"))
			k.box(0, 0, 1.0, 12.0, 7.0, 18.0, BRIQUE)
			k.box(0, 7.0, 1.0, 12.4, 0.4, 18.4, Color("3a2a22"))
			k.box(0, 0, -8.05, 2.0, 2.6, 0.2, Color("3a2416"))
			k.box(0, 2.9, -8.6, 4.0, 0.2, 1.2, ROUGE_F)
			k.box(3.8, 3.0, -8.2, 0.3, 3.4, 0.6, Color("1d3557"))
			k.box(3.8, 3.3, -8.55, 0.1, 2.8, 0.4, Color("4ab0e0"))
			k.windows_row(0, -8.05, 10.0, 4.6, 3, 1.2, 1.6, Color("e9a84e"))
		"salle_musiques_actuelles":
			k.plate(0, 0, w, d, ASPHALTE)
			k.box(0, 0, 3.0, 30.0, 13.0, 32.0, NOIR)
			k.box(0, 13.0, 3.0, 30.4, 0.5, 32.4, Color("1a191e"))
			k.box(-8.0, 0, -15.0, 14.0, 5.0, 6.0, Color("e63946"))
			k.box(-8.0, 0, -18.05, 8.0, 3.0, 0.2, VITRE)
			k.box(0, 8.0, -13.1, 20.0, 3.0, 0.2, Color("f2f2ee"))
			k.box(0, 8.6, -13.25, 16.0, 1.8, 0.1, Color("ff4fa0"))
			k.box(9.0, 0, -13.05, 4.0, 4.0, 0.2, Color("4a4a4e"))
		"auditorium":
			k.plate(0, 0, w, d, Color("cfc8b6"))
			# Salle en vignoble : coque ovale à gradins de toits.
			k.cylinder(0, 0, 6.0, 22.0, 21.0, 16.0, 16, Color("e8e2d6"))
			k.cylinder(0, 16.0, 6.0, 21.0, 16.0, 4.0, 16, Color("c8c0b0"))
			k.cylinder(0, 20.0, 6.0, 16.0, 9.0, 3.0, 16, Color("b0a898"))
			# Foyer vitré en façade.
			k.box(0, 0, -20.0, 36.0, 10.0, 10.0, VITRE)
			k.box(0, 10.0, -20.0, 37.0, 0.6, 11.0, BLANC)
			k.box(0, 0, -27.0, 30.0, 0.5, 4.0, PIERRE)
			k.box(0, 10.6, -25.2, 20.0, 1.2, 0.2, Color("1d3557"))
		"arena_concert":
			k.plate(0, 0, w, d, ASPHALTE)
			k.cylinder(0, 0, 6.0, 40.0, 38.0, 22.0, 20, Color("c8ccd2"))
			k.lathe(0, 22.0, 6.0, [Vector2(38.0, 0), Vector2(31.0, 5.0), Vector2(17.0, 8.0), Vector2(0.0, 9.0)], 20, Color("8a9096"))
			k.box(0, 0, -40.0, 50.0, 8.0, 6.0, VITRE)
			k.box(0, 8.0, -40.0, 52.0, 0.5, 7.0, Color("3a3d42"))
			k.box(0, 9.0, -43.2, 40.0, 4.0, 0.4, Color("1d1d22"))
			k.box(0, 9.5, -43.45, 36.0, 3.0, 0.1, Color("ff4fa0"))
		"scene_festival":
			k.plate(0, 0, w, d, VERT)
			# Grande scène au fond, toit en arche, écrans géants.
			k.box(0, 0, 44.0, 40.0, 2.2, 16.0, NOIR)
			k.box(0, 2.2, 51.5, 40.0, 14.0, 1.0, Color("1d1d22"))
			for x in [-19.0, 19.0]:
				k.box(x, 2.2, 44.0, 1.2, 14.0, 16.0, Color("1d1d22"))
			k.gable(0, 16.2, 44.0, 42.0, 17.0, 4.0, Color("1d1d22"), true)
			for x in [-30.0, 30.0]:
				k.box(x, 0, 44.0, 0.6, 14.0, 0.6, METAL)
				k.box(x, 6.0, 43.6, 12.0, 7.0, 0.4, Color("1d3557"))
				k.box(x, 6.4, 43.35, 11.0, 6.2, 0.1, Color("4ab0e0"))
			k.box(0, 15.0, 35.9, 38.0, 0.4, 0.2, Color("ff4fa0"))
			# Régie, buvettes, toilettes, entrée.
			k.box(0, 0, 4.0, 8.0, 4.0, 6.0, NOIR)
			k.box(0, 4.0, 4.0, 9.0, 0.3, 7.0, METAL)
			for x in [-46.0, 46.0]:
				k.box(x, 0, 10.0, 10.0, 3.0, 6.0, Color("f4a261"))
				k.box(x, 3.0, 10.0, 10.6, 0.3, 6.6, BLANC)
			k.box(-46.0, 0, -20.0, 6.0, 2.6, 8.0, Color("2a9d8f"))
			k.box(0, 0, -50.0, 1.0, 6.0, 1.0, BOIS)
			k.box(24.0, 0, -50.0, 1.0, 6.0, 1.0, BOIS)
			k.box(12.0, 5.0, -50.0, 25.0, 1.6, 0.6, Color("e63946"))
			for x in range(-54, 56, 12):
				k.box(float(x), 0, -54.0, 0.1, 1.1, 0.1, METAL)
		"cafe_theatre":
			k.plate(0, 0, w, d, Color("8a8478"))
			k.box(0, 0, 1.0, 12.0, 8.0, 16.0, Color("f2d0a9"))
			k.gable(0, 8.0, 1.0, 12.6, 16.6, 3.0, Color("c8553d"))
			k.box(0, 0, -7.05, 8.0, 3.0, 0.2, VITRE)
			k.box(0, 3.2, -7.8, 11.0, 0.2, 1.6, Color("2a9d8f"))
			k.box(0, 4.0, -7.1, 7.0, 1.2, 0.2, Color("1d3557"))
			k.box(0, 4.2, -7.25, 5.0, 0.8, 0.06, NEON)
			k.windows_row(0, -7.05, 10.0, 5.6, 3, 1.0, 1.4, VITRE)
		"theatre_italienne":
			k.plate(0, 0, w, d, Color("cfc8b6"))
			k.box(0, 0, 4.0, 34.0, 16.0, 38.0, PIERRE)
			k.box(0, 16.0, 14.0, 26.0, 8.0, 16.0, Color("d6ccb4"))
			k.box(0, 24.0, 14.0, 26.6, 0.5, 16.6, Color("6a8a7e"))
			k.hip(0, 16.0, -2.0, 34.6, 22.0, 3.5, Color("6a8a7e"))
			# Façade : perron, arcades, colonnes jumelées, fronton et statues.
			for i in 3:
				k.box(0, 0, -15.6 - i * 0.7, 24.0 + i * 1.4, 0.6 - i * 0.18, 0.7, Color("d8d0bc"))
			for i in 5:
				k.box(-10.0 + i * 5.0, 0.6, -15.1, 3.0, 4.6, 0.2, Color("3a2416"))
			for i in 8:
				k.cylinder(-12.25 + i * 3.5, 6.0, -15.3, 0.45, 0.42, 7.0, 8, CREME)
			k.box(0, 13.0, -15.2, 32.0, 1.2, 1.2, PIERRE)
			k.gable(0, 14.2, -15.2, 18.0, 1.4, 3.4, CREME, true)
			k.windows_row(0, -15.1, 28.0, 8.0, 8, 1.4, 3.2, VITRE)
			for x in [-14.0, 14.0]:
				k.box(x, 14.2, -15.2, 1.2, 2.6, 1.2, OR)
		"scene_contemporaine":
			k.plate(0, 0, w, d, BETON)
			k.box(0, 0, 4.0, 36.0, 12.0, 32.0, Color("6e6a62"))
			k.box(0, 12.0, 10.0, 20.0, 10.0, 16.0, Color("5a5650"))
			k.box(-6.0, 0, -15.0, 24.0, 9.0, 6.0, VITRE)
			k.box(-6.0, 9.0, -15.0, 24.6, 0.4, 6.6, BLANC)
			k.box(12.0, 4.0, -12.1, 8.0, 6.0, 0.2, Color("e63946"))
			k.box(12.0, 4.5, -12.25, 6.0, 5.0, 0.06, Color("f2f2ee"))
		"opera_coupole":
			k.plate(0, 0, w, d, Color("cfc8b6"))
			k.box(0, 0, 8.0, 54.0, 20.0, 56.0, PIERRE)
			k.box(0, 20.0, 22.0, 34.0, 18.0, 22.0, Color("d6ccb4"))
			k.gable(0, 38.0, 22.0, 34.6, 22.6, 6.0, CUIVRE, true)
			k.dome(0, 20.0, -2.0, 15.0, 10.0, CUIVRE, 16)
			k.cylinder(0, 30.0, -2.0, 1.4, 0.6, 3.0, 8, OR)
			# Grand escalier et façade à loggia.
			for i in 5:
				k.box(0, i * 0.4, -23.0 - (4 - i) * 0.9, 40.0, 0.4, 0.9 + (4 - i) * 0.0, Color("d8d0bc"))
			k.box(0, 2.0, -20.6, 44.0, 6.0, 1.0, PIERRE)
			for i in 7:
				k.box(-15.0 + i * 5.0, 2.0, -21.15, 3.4, 4.6, 0.2, Color("3a2416"))
			for i in 14:
				k.cylinder(-19.5 + i * 3.0, 8.0, -21.0, 0.5, 0.45, 8.0, 8, CREME)
			k.box(0, 16.0, -20.8, 44.0, 2.0, 1.6, PIERRE)
			k.windows_row(0, -21.0, 40.0, 10.0, 7, 2.0, 4.2, VITRE)
			for x in [-20.0, 20.0]:
				k.box(x, 18.0, -20.8, 2.0, 3.6, 2.0, OR)
				k.box(x, 0, -27.0, 1.2, 4.6, 1.2, Color("2a2a2c"))
				k.cylinder(x, 4.6, -27.0, 0.6, 0.6, 0.8, 6, NEON)
		"theatre_verdure":
			k.plate(0, 0, w, d, VERT)
			# Gradins en demi-cercle tournés vers la scène (au fond, +Z).
			for r in 7:
				var rr := 10.0 + r * 2.4
				for i in 9:
					var a := PI * (0.1 + 0.8 * i / 8.0)
					var x := cos(a) * rr
					var z := 14.0 - sin(a) * rr
					k.box(x, 0, z, 3.0, 0.4 + r * 0.45, 1.8, Color("cfc7b5").darkened(0.02 * r))
			k.box(0, 0, 16.0, 16.0, 1.0, 7.0, Color("d8d0bc"))
			k.box(0, 1.0, 19.2, 16.0, 5.0, 0.4, Color("9e968a"))
			for x in [-20.0, -12.0, 12.0, 20.0]:
				k.tree(x, 19.0, 1.8)
			k.tree(-22.0, -18.0, 1.6)
			k.tree(22.0, -18.0, 1.6)
		"chapiteau_cirque":
			k.plate(0, 0, w, d, Color("7aa84f"))
			k.cylinder(0, 0, 0, 19.0, 19.0, 6.0, 16, Color("f2f2ee"))
			for i in 8:
				var a := TAU * i / 8.0
				k.box(cos(a) * 18.9, 0.4, sin(a) * 18.9, 2.4, 5.4, 2.4, ROUGE)
			k.cylinder(0, 6.0, 0, 19.4, 1.0, 10.0, 16, ROUGE)
			k.cylinder(0, 6.05, 0, 19.0, 9.0, 4.7, 16, Color("f2f2ee"))
			for x in [-6.0, 6.0]:
				k.cylinder(x, 0, 0, 0.3, 0.3, 18.0, 5, METAL)
				k.cylinder(x, 18.0, 0, 0.05, 0.05, 2.0, 4, Color("1d3557"))
				k.box(x + 0.6, 19.2, 0, 1.2, 0.8, 0.05, Color("f2c14e"))
			k.box(0, 0, -19.6, 5.0, 4.0, 2.0, Color("f2c14e"))
			for p in [Vector2(-18, -20), Vector2(18, -20), Vector2(-20, 18)]:
				k.box(p.x, 0.5, p.y, 3.0, 2.6, 7.0, Color("2a5d9a"))
				for wz in [-2.4, 2.4]:
					k.cylinder(p.x, 0, p.y + wz, 0.5, 0.5, 0.2, 8, Color("1d1d22"))
