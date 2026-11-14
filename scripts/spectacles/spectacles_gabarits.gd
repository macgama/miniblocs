class_name SpectaclesGabarits
extends RefCounted
## Salles de spectacle et studios prêts à poser (onglet Bâtir du menu
## Spectacles, ou outil « Poser un bâtiment meublé » de l'Intérieur) : de vrais
## murs, la scène ou l'écran au fond, les fauteuils en rangées face à elle, le
## foyer avec sa billetterie et son bar, les loges, la régie ; pour les
## studios, deux plateaux, la salle de montage et les ateliers.
##
## Même description que MuseeGabarits : w × d (m), par étage des salles
## [x, z, w, d, fonction] (entrée sur z = 0), des portes [x0, z0, x1, z1, genre]
## (un mètre de mur chacune) et des escaliers. « sans_fenetres » : seules les
## fenêtres listées dans les portes (les salles restent noires).
## Ces bâtiments sont des salles du menu Spectacles comme les autres : leurs
## places sont leurs fauteuils, leur note vient de leur confort et de leur son.

const KINDS := {
	"cinema_village": {"name": "Cinéma de village (une salle)", "w": 12, "d": 20, "usage": "cinema", "roof": "plat", "budget": 1_200_000, "sans_fenetres": true,
		"mur": "Enduit blanc", "toit": "Béton",
		"desc": "Un hall avec billetterie, confiserie et pop-corn, une salle de cent fauteuils rouges devant un écran panoramique.",
		"salles": [[[0, 0, 8, 5, "hall_cinema"], [8, 0, 4, 5, "sdb"], [0, 5, 12, 15, "salle_projection"]]],
		"portes": [[[3, 0, 4, 0, "porte_double"], [4, 0, 5, 0, "porte_double"], [1, 0, 2, 0, "vitrine"], [6, 0, 7, 0, "vitrine"], [8, 2, 8, 3, "porte"], [6, 5, 7, 5, "passage"]]],
		"stairs": [[]], "floors": {"salle_projection": "Moquette", "hall_cinema": "Marbre de Carrare"}},
	"cinema_quartier": {"name": "Cinéma de quartier (trois salles)", "w": 30, "d": 22, "usage": "cinema", "roof": "plat", "budget": 3_200_000, "sans_fenetres": true,
		"mur": "Brique", "toit": "Béton",
		"desc": "Un grand hall (billetterie, bornes, confiserie), trois salles de projection de 70 à 110 places.",
		"salles": [[[0, 0, 24, 6, "hall_cinema"], [24, 0, 6, 6, "sdb"], [0, 6, 12, 16, "salle_projection"], [12, 6, 10, 16, "salle_projection"], [22, 6, 8, 16, "salle_projection"]]],
		"portes": [[[11, 0, 12, 0, "porte_double"], [12, 0, 13, 0, "porte_double"], [13, 0, 14, 0, "porte_double"], [2, 0, 3, 0, "vitrine"], [5, 0, 6, 0, "vitrine"],
			[18, 0, 19, 0, "vitrine"], [21, 0, 22, 0, "vitrine"], [24, 2, 24, 3, "porte"], [10, 6, 11, 6, "passage"], [13, 6, 14, 6, "passage"], [23, 6, 24, 6, "passage"]]],
		"stairs": [[]], "floors": {"salle_projection": "Moquette", "hall_cinema": "Marbre de Carrare"}},
	"theatre_poche": {"name": "Petit théâtre de poche", "w": 16, "d": 20, "usage": "theatre", "roof": "deux_pans", "budget": 1_400_000, "sans_fenetres": true,
		"mur": "Pierre de taille", "toit": "Ardoise",
		"desc": "Un foyer, une salle de 70 fauteuils de velours devant une scène à rideau rouge, une régie et une loge.",
		"salles": [[[0, 0, 12, 5, "foyer_spectacle"], [12, 0, 4, 5, "sdb"], [0, 5, 12, 15, "scene_theatre"], [12, 5, 4, 8, "regie"], [12, 13, 4, 7, "loges"]]],
		"portes": [[[5, 0, 6, 0, "porte_double"], [6, 0, 7, 0, "porte_double"], [1, 0, 2, 0, "fenetre"], [10, 0, 11, 0, "fenetre"], [12, 2, 12, 3, "porte"],
			[2, 5, 3, 5, "passage"], [9, 5, 10, 5, "passage"], [12, 6, 12, 7, "porte"], [12, 17, 12, 18, "porte"], [16, 18, 16, 19, "porte"]]],
		"stairs": [[]], "floors": {"scene_theatre": "Parquet chêne", "foyer_spectacle": "Marbre de Carrare"}},
	"theatre_ville": {"name": "Théâtre municipal", "w": 34, "d": 35, "usage": "theatre", "roof": "mansarde", "budget": 7_500_000, "sans_fenetres": true,
		"mur": "Pierre de taille", "toit": "Ardoise",
		"desc": "Un grand foyer avec son bar et son lustre, une salle de 400 fauteuils, une scène de 6 m, les loges, l'atelier des costumes et celui des décors.",
		"salles": [[[0, 0, 26, 7, "foyer_spectacle"], [26, 0, 4, 7, "sdb"], [30, 0, 4, 7, "bureau"], [0, 7, 26, 28, "scene_theatre"],
			[26, 7, 8, 11, "atelier_costumes"], [26, 18, 8, 8, "atelier_decors"], [26, 26, 8, 9, "loges"]]],
		"portes": [[[11, 0, 12, 0, "porte_double"], [12, 0, 13, 0, "porte_double"], [13, 0, 14, 0, "porte_double"], [14, 0, 15, 0, "porte_double"],
			[2, 0, 3, 0, "fenetre_cintree"], [6, 0, 7, 0, "fenetre_cintree"], [19, 0, 20, 0, "fenetre_cintree"], [23, 0, 24, 0, "fenetre_cintree"],
			[26, 3, 26, 4, "porte"], [32, 0, 33, 0, "porte"], [3, 7, 4, 7, "passage"], [4, 7, 5, 7, "passage"], [21, 7, 22, 7, "passage"], [22, 7, 23, 7, "passage"],
			[26, 31, 26, 32, "porte"], [26, 29, 26, 30, "porte"], [30, 18, 31, 18, "porte"], [34, 21, 34, 22, "porte_garage"], [34, 22, 34, 23, "porte_garage"],
			[34, 31, 34, 32, "porte"]]],
		"stairs": [[]], "floors": {"scene_theatre": "Parquet chêne", "foyer_spectacle": "Marbre de Carrare"}},
	"opera_lyrique": {"name": "Maison d'opéra (fosse d'orchestre)", "w": 30, "d": 36, "usage": "theatre", "roof": "voute", "budget": 9_000_000, "sans_fenetres": true,
		"mur": "Pierre de taille", "toit": "Ardoise",
		"desc": "Un foyer de marbre, une salle de plus de 300 fauteuils, la fosse d'orchestre devant une scène de 7 m : opéra, ballet et comédie musicale.",
		"salles": [[[0, 0, 24, 7, "foyer_spectacle"], [24, 0, 6, 7, "sdb"], [0, 7, 24, 29, "salle_lyrique"], [24, 7, 6, 10, "atelier_costumes"],
			[24, 17, 6, 10, "atelier_decors"], [24, 27, 6, 9, "loges"]]],
		"portes": [[[10, 0, 11, 0, "porte_double"], [11, 0, 12, 0, "porte_double"], [12, 0, 13, 0, "porte_double"], [13, 0, 14, 0, "porte_double"],
			[2, 0, 3, 0, "fenetre_cintree"], [6, 0, 7, 0, "fenetre_cintree"], [17, 0, 18, 0, "fenetre_cintree"], [21, 0, 22, 0, "fenetre_cintree"],
			[24, 3, 24, 4, "porte"], [3, 7, 4, 7, "arcade"], [4, 7, 5, 7, "arcade"], [19, 7, 20, 7, "arcade"], [20, 7, 21, 7, "arcade"],
			[24, 31, 24, 32, "porte"], [24, 29, 24, 30, "porte"], [27, 17, 28, 17, "porte"], [30, 21, 30, 22, "porte_garage"], [30, 22, 30, 23, "porte_garage"],
			[30, 32, 30, 33, "porte"], [27, 27, 28, 27, "porte"]]],
		"stairs": [[]], "floors": {"salle_lyrique": "Parquet chêne", "foyer_spectacle": "Marbre de Carrare"}},
	"salle_musiques_actuelles_plan": {"name": "Salle de concert (musiques actuelles)", "w": 28, "d": 28, "usage": "concert", "roof": "plat", "budget": 4_500_000,
		"sans_fenetres": true, "mur": "Béton brut", "toit": "Béton",
		"desc": "Un foyer et son bar, une grande fosse debout de 700 places devant une scène de rock (batterie, amplis, colonnes de son), la régie au fond, les loges.",
		"salles": [[[0, 0, 20, 6, "foyer_spectacle"], [20, 0, 4, 6, "sdb"], [24, 0, 4, 6, "reserve"], [0, 6, 22, 22, "salle_concert"], [22, 6, 6, 12, "bureau"],
			[22, 18, 6, 10, "loges"]]],
		"portes": [[[8, 0, 9, 0, "porte_double"], [9, 0, 10, 0, "porte_double"], [10, 0, 11, 0, "porte_double"], [2, 0, 3, 0, "vitrine"], [15, 0, 16, 0, "vitrine"],
			[20, 2, 20, 3, "porte"], [25, 0, 26, 0, "porte"], [5, 6, 6, 6, "passage"], [6, 6, 7, 6, "passage"], [14, 6, 15, 6, "passage"], [15, 6, 16, 6, "passage"],
			[22, 8, 22, 9, "porte"], [22, 24, 22, 25, "porte"], [28, 22, 28, 23, "porte"], [28, 25, 28, 26, "porte_garage"], [28, 26, 28, 27, "porte_garage"]]],
		"stairs": [[]], "floors": {"salle_concert": "Béton ciré gris"}},
	"club_jazz_plan": {"name": "Club de jazz", "w": 14, "d": 14, "usage": "concert", "roof": "plat", "budget": 700_000, "sans_fenetres": true,
		"mur": "Brique sombre", "toit": "Béton",
		"desc": "Une petite scène (batterie, piano, contrebasse), des tables de cabaret, le bar.",
		"salles": [[[0, 0, 9, 4, "foyer_spectacle"], [9, 0, 5, 4, "sdb"], [0, 4, 14, 10, "club_jazz"]]],
		"portes": [[[4, 0, 5, 0, "porte"], [1, 0, 2, 0, "vitrine"], [6, 0, 7, 0, "vitrine"], [9, 1, 9, 2, "porte"], [7, 4, 8, 4, "passage"]]],
		"stairs": [[]], "floors": {"club_jazz": "Parquet foncé"}},
	"auditorium_plan": {"name": "Auditorium (musique classique)", "w": 26, "d": 30, "usage": "concert", "roof": "voute", "budget": 5_000_000, "sans_fenetres": true,
		"mur": "Béton blanc", "toit": "Béton",
		"desc": "Un foyer, plus de 200 fauteuils face à une grande scène où l'orchestre s'installe devant son chef, piano et harpe compris.",
		"salles": [[[0, 0, 20, 6, "foyer_spectacle"], [20, 0, 6, 6, "sdb"], [0, 6, 20, 24, "salle_classique"], [20, 6, 6, 12, "reserve"], [20, 18, 6, 12, "loges"]]],
		"portes": [[[8, 0, 9, 0, "porte_double"], [9, 0, 10, 0, "porte_double"], [10, 0, 11, 0, "porte_double"], [2, 0, 3, 0, "baie"], [3, 0, 4, 0, "baie"],
			[15, 0, 16, 0, "baie"], [16, 0, 17, 0, "baie"], [20, 2, 20, 3, "porte"], [3, 6, 4, 6, "passage"], [16, 6, 17, 6, "passage"], [26, 10, 26, 11, "porte"],
			[20, 25, 20, 26, "porte"], [26, 26, 26, 27, "porte"]]],
		"stairs": [[]], "floors": {"salle_classique": "Parquet chêne", "foyer_spectacle": "Marbre de Carrare"}},
	"studios_tournage": {"name": "Studios de tournage", "w": 36, "d": 30, "usage": "studio_cine", "roof": "dents_de_scie", "budget": 8_000_000, "sans_fenetres": true,
		"mur": "Béton", "toit": "Béton",
		"desc": "Bureaux de production, un grand plateau avec son décor, un plateau fond vert, la salle de montage, les loges, l'atelier des costumes et celui des décors.",
		"salles": [[[0, 0, 12, 6, "bureau"], [12, 0, 4, 6, "sdb"], [16, 0, 10, 6, "salle_montage"], [26, 0, 10, 6, "loges"], [0, 6, 18, 24, "plateau_studio"],
			[18, 6, 18, 14, "plateau_fond_vert"], [18, 20, 9, 10, "atelier_costumes"], [27, 20, 9, 10, "atelier_decors"]]],
		"portes": [[[5, 0, 6, 0, "porte_vitree"], [1, 0, 2, 0, "fenetre"], [9, 0, 10, 0, "fenetre"], [20, 0, 21, 0, "fenetre"], [30, 0, 31, 0, "porte"],
			[12, 2, 12, 3, "porte"], [6, 6, 7, 6, "porte"], [22, 6, 23, 6, "porte"], [30, 6, 31, 6, "porte"], [18, 12, 18, 13, "porte_double"], [18, 13, 18, 14, "porte_double"],
			[22, 20, 23, 20, "porte"], [31, 20, 32, 20, "porte_double"], [32, 20, 33, 20, "porte_double"], [27, 24, 27, 25, "porte"],
			[0, 14, 0, 15, "porte_garage"], [0, 15, 0, 16, "porte_garage"], [0, 16, 0, 17, "porte_garage"], [0, 17, 0, 18, "porte_garage"],
			[36, 24, 36, 25, "porte_garage"], [36, 25, 36, 26, "porte_garage"], [36, 26, 36, 27, "porte_garage"]]],
		"stairs": [[]], "floors": {"plateau_studio": "Béton ciré gris", "plateau_fond_vert": "Béton ciré gris", "bureau": "Parquet chêne"}},
}
const ORDER := ["cinema_village", "cinema_quartier", "theatre_poche", "theatre_ville", "opera_lyrique", "club_jazz_plan", "salle_musiques_actuelles_plan",
	"auditorium_plan", "studios_tournage"]


## Spécification complète (pour Gabarits.build_spec) : étages, murs, toit et sols résolus.
static func spec(kind: String) -> Dictionary:
	var g: Dictionary = (KINDS[kind] as Dictionary).duplicate()
	g["levels"] = MuseeGabarits.levels_from(g)
	g["wall_mat"] = MuseeGabarits._mat(String(g.get("mur", MuseeGabarits.MUR)), 5)
	g["roof_mat"] = MuseeGabarits._mat(String(g.get("toit", MuseeGabarits.TOIT)), 8)
	var sols := {}
	var f: Dictionary = g.get("floors", {})
	for fn in f:
		sols[fn] = MuseeGabarits._mat(String(f[fn]), -1)
	g["floors"] = sols
	return g


static func of_usage(u: String) -> Array:
	var out: Array = []
	for k in ORDER:
		if String(KINDS[k].usage) == u:
			out.append(k)
	return out
