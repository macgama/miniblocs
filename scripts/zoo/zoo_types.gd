class_name ZooTypes
extends RefCounted
## Zoo : bâtiments de la catégorie « Zoo » du panneau Construire (entrée, abris,
## soigneurs, cuisine, clinique, atelier, belvédère, kiosque, boutiques…).
##
## Même format que BuildingCatalog, plus un champ "zoo" qui dit le rôle :
## - "entree" : entrée du zoo, au bord d'une route. Elle fonde le zoo : enclos et
##   bâtiments à moins de ZooSysteme.RAYON mètres en font partie ;
## - "abri" : "places" (en tailles d'animaux, voir ZooEspeces), "chaud" (chauffé),
##   "froid" (réfrigéré). Un abri compte pour l'enclos qui le contient ;
## - "soigneurs" (nourrissent et nettoient), "cuisine" (nourriture moins chère),
##   "clinique" (vétérinaires), "atelier" (barrières réparées) ;
## - "vue" (belvédère : meilleure vue sur les enclos proches), "pedago" (dons) ;
## - "stand" : "vend" ("manger", "boire", "souvenir"), "prix" (€), "service" ;
## - "toilettes", "repos".
## Seule l'entrée a besoin d'une route : le reste est dans l'enceinte du zoo.

const CATEGORY := "zoo"
const ROAD := ["route"]

const TYPES := {
	"entree_zoo": {"name": "Entrée du zoo", "w": 30, "d": 14, "access": ROAD, "emplois": 6, "cost": 800_000,
		"zoo": {"role": "entree"},
		"metiers": [["agent_accueil_zoo", 5], ["cadre", 1]],
		"desc": "Portique en rondins, guichets et plan du zoo. Elle fonde le zoo : enclos et bâtiments à moins de 400 m en font partie."},
	"abri_bois_zoo": {"name": "Abri en bois", "w": 8, "d": 6, "access": [], "emplois": 0, "cost": 30_000,
		"zoo": {"role": "abri", "places": 8},
		"desc": "Petit abri chauffé l'hiver : lémuriens, suricates, chèvres, manchots, kangourous (8 places)."},
	"abri_savane_zoo": {"name": "Grand abri de savane", "w": 18, "d": 12, "access": [], "emplois": 0, "cost": 200_000,
		"zoo": {"role": "abri", "places": 30},
		"desc": "Charpente et toit de chaume, pour zèbres, girafes, lions et rhinocéros (30 places)."},
	"maison_elephants_zoo": {"name": "Maison des éléphants", "w": 32, "d": 22, "access": [], "emplois": 0, "cost": 900_000,
		"zoo": {"role": "abri", "places": 70, "chaud": true},
		"desc": "Grande halle chauffée au sol de sable, portes de 5 m (70 places)."},
	"grotte_zoo": {"name": "Grotte en rochers", "w": 12, "d": 10, "access": [], "emplois": 0, "cost": 140_000,
		"zoo": {"role": "abri", "places": 16},
		"desc": "Faux rochers et tanière fraîche : ours, loups, tigres (16 places)."},
	"abri_polaire_zoo": {"name": "Abri réfrigéré", "w": 14, "d": 10, "access": [], "emplois": 0, "cost": 320_000,
		"zoo": {"role": "abri", "places": 20, "froid": true},
		"desc": "Glace pilée et air à 0 °C : manchots et ours polaires y passent l'été (20 places)."},
	"vivarium_zoo": {"name": "Serre tropicale", "w": 24, "d": 16, "access": [], "emplois": 0, "cost": 650_000,
		"zoo": {"role": "abri", "places": 30, "chaud": true},
		"desc": "Verrière à 28 °C et 80 % d'humidité : crocodiles, tortues, orangs-outans y passent l'hiver (30 places)."},
	"poste_soigneurs_zoo": {"name": "Poste des soigneurs", "w": 14, "d": 10, "access": [], "emplois": 6, "cost": 220_000,
		"zoo": {"role": "soigneurs"},
		"metiers": [["soigneur_animalier", 6]],
		"desc": "Six soigneurs : ils nourrissent, nettoient les enclos et donnent des jouets. Un soigneur suit environ 20 places d'animaux."},
	"cuisine_zoo": {"name": "Cuisine et réserve de nourriture", "w": 16, "d": 10, "access": [], "emplois": 3, "cost": 260_000,
		"zoo": {"role": "cuisine"},
		"metiers": [["soigneur_animalier", 3]],
		"desc": "Chambres froides, foin et légumes en gros : la nourriture coûte 40 % de moins qu'avec un livreur."},
	"clinique_zoo": {"name": "Clinique vétérinaire", "w": 18, "d": 12, "access": [], "emplois": 4, "cost": 750_000,
		"zoo": {"role": "clinique"},
		"metiers": [["veterinaire_zoo", 2], ["soigneur_animalier", 2]],
		"desc": "Bloc opératoire et quarantaine. Sans elle, un vétérinaire de campagne passe deux fois par semaine."},
	"atelier_zoo": {"name": "Atelier d'entretien du zoo", "w": 16, "d": 12, "access": [], "emplois": 4, "cost": 300_000,
		"zoo": {"role": "atelier"},
		"metiers": [["technicien_zoo", 3], ["agent_proprete", 1]],
		"desc": "Techniciens qui réparent les barrières usées. Une barrière usée, c'est une évasion qui se prépare."},
	"belvedere_zoo": {"name": "Belvédère", "w": 8, "d": 8, "access": [], "emplois": 0, "cost": 90_000,
		"zoo": {"role": "vue", "portee": 60.0},
		"desc": "Tour en bois de 6 m avec longues-vues : les enclos à moins de 60 m sont mieux vus, même derrière un mur."},
	"kiosque_pedago_zoo": {"name": "Kiosque pédagogique", "w": 10, "d": 8, "access": [], "emplois": 1, "cost": 120_000,
		"zoo": {"role": "pedago"},
		"metiers": [["animateur_zoo", 1]],
		"desc": "Panneaux, crânes et plumes à toucher : les visiteurs apprennent, et donnent pour la conservation."},
	"restaurant_zoo": {"name": "Restaurant du zoo", "w": 18, "d": 14, "access": [], "emplois": 5, "cost": 420_000,
		"zoo": {"role": "stand", "vend": "manger", "prix": 14.0, "service": 80.0},
		"metiers": [["vendeur_parc", 5]],
		"desc": "Terrasse au bord de la savane. Le steak est très bien vu par les lions d'en face."},
	"glacier_zoo": {"name": "Kiosque à glaces", "w": 6, "d": 6, "access": [], "emplois": 1, "cost": 70_000,
		"zoo": {"role": "stand", "vend": "manger", "prix": 4.0, "service": 60.0},
		"metiers": [["vendeur_parc", 1]],
		"desc": "Glaces, gaufres et barbe à papa. Ne pas en donner aux chèvres (elles insistent)."},
	"buvette_zoo": {"name": "Buvette", "w": 7, "d": 6, "access": [], "emplois": 1, "cost": 80_000,
		"zoo": {"role": "stand", "vend": "boire", "prix": 3.0, "service": 90.0},
		"metiers": [["vendeur_parc", 1]],
		"desc": "Eau, sirops et cafés. Indispensable devant l'enclos des suricates en plein soleil."},
	"boutique_zoo": {"name": "Boutique du zoo", "w": 12, "d": 10, "access": [], "emplois": 2, "cost": 230_000,
		"zoo": {"role": "stand", "vend": "souvenir", "prix": 16.0, "service": 40.0},
		"metiers": [["vendeur_parc", 2]],
		"desc": "Peluches de panda, casquettes à oreilles et livres. Une partie des ventes va à la conservation."},
	"toilettes_zoo": {"name": "Toilettes", "w": 8, "d": 6, "access": [], "emplois": 0, "cost": 90_000,
		"zoo": {"role": "toilettes", "service": 120.0},
		"desc": "Sans elles, les visiteurs écourtent la visite (et les parents s'agacent)."},
	"pique_nique_zoo": {"name": "Aire de pique-nique", "w": 14, "d": 12, "access": [], "emplois": 0, "cost": 40_000,
		"zoo": {"role": "repos", "places": 48},
		"desc": "Tables, bancs, poubelles et ombre. Les familles y restent une heure de plus."},
}
const ORDER := ["entree_zoo", "abri_bois_zoo", "abri_savane_zoo", "grotte_zoo", "abri_polaire_zoo", "vivarium_zoo",
	"maison_elephants_zoo", "poste_soigneurs_zoo", "cuisine_zoo", "clinique_zoo", "atelier_zoo", "belvedere_zoo",
	"kiosque_pedago_zoo", "restaurant_zoo", "glacier_zoo", "buvette_zoo", "boutique_zoo", "toilettes_zoo", "pique_nique_zoo"]


static func entries() -> Dictionary:
	var out := {}
	for id in ORDER:
		var t: Dictionary = TYPES[id].duplicate()
		t["cat"] = CATEGORY
		t["region"] = "monde"
		t["era"] = "moderne"
		t["style"] = ""
		out[id] = t
	return out


static func spec_of(type_id: String) -> Dictionary:
	var base := BuildingCatalog.base_of(type_id)
	return TYPES[base].zoo if TYPES.has(base) else {}


static func role_of(type_id: String) -> String:
	return String(spec_of(type_id).get("role", ""))


## Bâtiments d'un rôle, dans l'ordre du catalogue.
static func of_role(role: String) -> Array:
	var out: Array = []
	for id in ORDER:
		if String(TYPES[id].zoo.role) == role:
			out.append(id)
	return out


# --- Modèles -----------------------------------------------------------------------------------

const TERRE := Color("c49a62")
const BOIS := Color("8a5a36")
const BOIS_C := Color("b8895a")
const BOIS_F := Color("5a3a24")
const CHAUME := Color("c8b86a")
const ROCHE := Color("9a8e7e")
const ROCHE_F := Color("6e655a")
const VERT := Color("3f7232")
const VERT_C := Color("6aa040")
const BLANC := Color("f2ece0")
const VITRE := Color("33495e")
const METAL := Color("8a9096")
const ORANGE := Color("e07a2a")
const JAUNE := Color("e8c032")
const ROUGE := Color("c8322a")
const BETON := Color("b5b0a5")


static func build(k: BlocMesh, id: String, t: Dictionary) -> void:
	var w := float(t.w)
	var d := float(t.d)
	match id:
		"entree_zoo":
			k.plate(0, 0, w, d, TERRE)
			for s in [-1.0, 1.0]:
				# Tours en rondins, toit de chaume.
				k.box(10.5 * s, 0, 0, 5.0, 6.0, 5.0, BOIS)
				k.windows_row(10.5 * s, -2.52, 3.0, 2.6, 2, 0.8, 1.2, VITRE)
				k.pyramid(10.5 * s, 6.0, 0, 6.4, 6.4, 3.6, CHAUME)
				k.cylinder(7.6 * s, 0, -2.4, 0.3, 0.3, 8.0, 6, BOIS_F)
			# Arche et enseigne (une girafe stylisée).
			k.box(0, 6.6, -2.4, 16.0, 1.2, 0.6, BOIS_F)
			k.box(0, 6.9, -2.75, 12.0, 0.8, 0.05, JAUNE)
			k.box(-4.5, 7.8, -2.4, 0.3, 2.6, 0.3, ORANGE)
			k.box(-4.0, 9.9, -2.4, 1.0, 0.5, 0.4, ORANGE)
			for i in 3:
				var x := -5.0 + i * 5.0
				k.box(x, 0, 2.5, 3.0, 2.6, 2.6, BOIS_C)
				k.gable(x, 2.6, 2.5, 3.4, 3.0, 1.2, CHAUME)
				k.box(x, 1.1, 1.18, 1.8, 0.9, 0.05, VITRE)
			for i in 6:
				k.box(-6.0 + i * 2.4, 0, -1.8, 0.2, 1.0, 0.2, METAL)
			# Plan du zoo.
			k.box(13.5, 0, -6.0, 0.2, 2.2, 0.2, BOIS_F)
			k.box(13.5, 1.0, -6.1, 2.6, 1.6, 0.1, VERT_C)
			for s in [-1.0, 1.0]:
				k.tree(14.0 * s, 5.0, 1.1)
		"abri_bois_zoo":
			k.plate(0, 0, w, d, TERRE)
			k.box(0, 0, 0.5, 6.4, 2.4, 4.0, BOIS)
			k.gable(0, 2.4, 0.5, 7.0, 4.8, 1.6, BOIS_F)
			k.box(0, 0, -1.52, 1.4, 1.6, 0.05, BOIS_F)
			k.box(-2.4, 0, -2.2, 1.2, 0.6, 0.8, CHAUME)
		"abri_savane_zoo":
			k.plate(0, 0, w, d, TERRE)
			for x in [-7.5, -2.5, 2.5, 7.5]:
				for z in [-5.0, 5.0]:
					k.cylinder(x, 0, z, 0.3, 0.3, 4.2, 6, BOIS_F)
			k.box(0, 0, 3.0, 16.0, 3.4, 4.0, BOIS)
			k.hip(0, 4.2, 0, 18.4, 12.6, 3.8, CHAUME)
			for i in 3:
				k.box(-5.0 + i * 5.0, 0, -3.0, 3.0, 0.8, 1.2, CHAUME)
		"maison_elephants_zoo":
			k.plate(0, 0, w, d, TERRE)
			k.box(0, 0, 0, 30.0, 7.0, 20.0, Color("d8c8a8"))
			k.gable(0, 7.0, 0, 31.0, 21.0, 5.0, BOIS_F)
			for s in [-1.0, 1.0]:
				k.box(8.0 * s, 0, -10.02, 5.0, 5.0, 0.1, BOIS)
			k.windows_row(0, -10.03, 26.0, 5.6, 6, 2.0, 1.0, VITRE)
			k.box(0, 9.6, 0, 6.0, 2.4, 6.0, VITRE)
		"grotte_zoo":
			k.plate(0, 0, w, d, ROCHE_F)
			k.box(0, 0, 1.0, 11.0, 3.2, 8.0, ROCHE)
			k.box(-2.0, 3.2, 1.5, 6.0, 1.6, 5.0, ROCHE_F)
			k.box(2.5, 3.2, 0.5, 4.0, 1.0, 6.0, ROCHE)
			k.box(0, 0, -3.02, 3.0, 2.2, 0.1, Color("2a2622"))
			k.box(3.0, 4.2, 2.0, 2.0, 0.6, 2.0, VERT)
		"abri_polaire_zoo":
			k.plate(0, 0, w, d, Color("dfeef4"))
			k.box(0, 0, 0.5, 12.0, 3.6, 8.0, Color("eaf6fc"))
			k.dome(0, 3.6, 0.5, 4.0, 2.2, Color("c8e6f4"))
			k.box(0, 0, -3.52, 2.2, 2.2, 0.1, Color("6a8aa0"))
			for s in [-1.0, 1.0]:
				k.box(4.0 * s, 3.6, 2.5, 1.2, 1.0, 1.2, METAL)
		"vivarium_zoo":
			k.plate(0, 0, w, d, Color("9a8e6e"))
			k.box(0, 0, 0, 22.0, 1.0, 14.0, BETON)
			k.box(0, 1.0, 0, 22.0, 5.0, 14.0, Color("8ab8b0"))
			k.gable(0, 6.0, 0, 22.4, 14.4, 3.5, Color("9cc4d4"))
			for i in 5:
				k.tree(-8.0 + i * 4.0, 0.0, 1.0)
			k.box(0, 0, -7.02, 3.0, 2.6, 0.1, BOIS_F)
		"poste_soigneurs_zoo":
			k.plate(0, 0, w, d, TERRE)
			k.box(0, 0, 0, 12.0, 3.2, 8.0, Color("d8c8a8"))
			k.gable(0, 3.2, 0, 12.6, 8.6, 2.0, Color("8a4a32"))
			k.windows_row(0, -4.02, 10.0, 1.2, 3, 1.2, 1.1, VITRE)
			k.box(0, 0, -4.02, 1.2, 2.2, 0.05, BOIS_F)
			k.box(4.5, 0, -5.0, 2.0, 1.0, 1.2, Color("3f9a4a"))
			k.box(-4.5, 0, -5.0, 1.4, 1.2, 1.4, CHAUME)
		"cuisine_zoo":
			k.plate(0, 0, w, d, BETON)
			k.box(0, 0, 0, 14.0, 4.0, 8.0, Color("c9c1ae"))
			k.box(0, 4.0, 0, 14.4, 0.4, 8.4, Color("6a6f75"))
			k.box(-3.0, 0, -4.02, 4.0, 3.2, 0.05, METAL)
			for i in 4:
				k.box(2.0 + i * 1.4, 0, -4.6, 1.1, 1.0, 1.1, CHAUME)
		"clinique_zoo":
			k.plate(0, 0, w, d, BETON)
			k.box(0, 0, 0, 16.0, 3.6, 10.0, BLANC)
			k.box(0, 3.6, 0, 16.4, 0.4, 10.4, Color("6a6f75"))
			k.windows_row(0, -5.02, 14.0, 1.2, 4, 1.4, 1.2, VITRE)
			k.box(-6.0, 2.0, -5.06, 1.2, 1.2, 0.05, Color("3f9a4a"))
			k.box(-6.0, 2.4, -5.08, 1.2, 0.4, 0.05, BLANC)
			k.box(-6.0, 2.0, -5.08, 0.4, 1.2, 0.05, BLANC)
		"atelier_zoo":
			k.plate(0, 0, w, d, BETON)
			k.box(0, 0, 0, 14.0, 4.5, 10.0, Color("8a9a8a"))
			k.gable(0, 4.5, 0, 14.4, 10.4, 1.6, Color("5a5f65"))
			k.box(0, 0, -5.02, 6.0, 3.8, 0.05, METAL)
			for i in 5:
				k.box(-6.0 + i * 0.5, 0, -6.0, 0.15, 2.0, 0.15, METAL)
		"belvedere_zoo":
			k.plate(0, 0, w, d, TERRE)
			for x in [-2.5, 2.5]:
				for z in [-2.5, 2.5]:
					k.cylinder(x, 0, z, 0.25, 0.25, 6.0, 6, BOIS_F)
			k.box(0, 5.6, 0, 6.4, 0.3, 6.4, BOIS_C)
			for s in [-1.0, 1.0]:
				k.box(0, 5.9, 3.1 * s, 6.4, 1.0, 0.1, BOIS)
				k.box(3.1 * s, 5.9, 0, 0.1, 1.0, 6.4, BOIS)
			k.pyramid(0, 7.8, 0, 7.0, 7.0, 2.0, CHAUME)
			for i in 6:
				k.box(3.4, 0.4 + i * 0.9, -2.0 + i * 0.7, 1.2, 0.15, 0.7, BOIS_C)
		"kiosque_pedago_zoo":
			k.plate(0, 0, w, d, TERRE)
			k.box(0, 0, 1.0, 8.0, 2.8, 4.0, BOIS_C)
			k.gable(0, 2.8, 0, 9.0, 7.0, 1.6, CHAUME)
			for i in 4:
				k.box(-3.0 + i * 2.0, 0, -2.5, 0.12, 1.2, 0.12, BOIS_F)
				k.box(-3.0 + i * 2.0, 0.9, -2.55, 1.2, 0.8, 0.08, [VERT_C, JAUNE, ORANGE, Color("7ab0d8")][i])
		"restaurant_zoo":
			k.plate(0, 0, w, d, Color("d8cbb3"))
			k.box(0, 0, 3.0, 16.0, 3.6, 7.0, BOIS_C)
			k.hip(0, 3.6, 3.0, 17.0, 8.0, 2.6, CHAUME)
			k.windows_row(0, -0.52, 14.0, 1.0, 5, 1.8, 1.6, VITRE)
			for i in 4:
				var x := -6.0 + i * 4.0
				k.box(x, 0, -4.0, 1.6, 0.75, 1.0, BOIS)
				k.cylinder(x, 0, -4.0, 0.05, 0.05, 2.4, 4, METAL)
				k.pyramid(x, 2.3, -4.0, 2.6, 2.6, 0.7, [ORANGE, JAUNE, VERT_C, ROUGE][i])
		"glacier_zoo":
			k.plate(0, 0, w, d, Color("d8cbb3"))
			k.box(0, 0, 0.5, 4.0, 2.6, 3.0, Color("f7c6d0"))
			k.box(0, 2.6, 0.5, 4.6, 0.3, 3.6, BLANC)
			k.cylinder(0, 2.9, 0.5, 0.6, 0.0, 1.2, 8, Color("d8a050"))
			k.box(0, 1.0, -1.02, 2.6, 0.9, 0.05, VITRE)
		"buvette_zoo":
			k.plate(0, 0, w, d, Color("d8cbb3"))
			k.box(0, 0, 0.5, 5.0, 2.6, 3.4, BOIS)
			k.gable(0, 2.6, 0.5, 5.6, 4.0, 1.0, CHAUME)
			k.box(0, 1.0, -1.22, 3.6, 0.9, 0.05, VITRE)
		"boutique_zoo":
			k.plate(0, 0, w, d, Color("d8cbb3"))
			k.box(0, 0, 0, 10.0, 3.4, 8.0, Color("e6d8b8"))
			k.gable(0, 3.4, 0, 10.6, 8.6, 2.0, Color("8a4a32"))
			k.windows_row(0, -4.02, 8.0, 0.6, 2, 2.4, 2.0, VITRE)
			k.box(0, 2.6, -4.08, 6.0, 0.6, 0.05, ORANGE)
		"toilettes_zoo":
			k.plate(0, 0, w, d, Color("d8cbb3"))
			k.box(0, 0, 0, 7.0, 2.8, 5.0, BOIS_C)
			k.gable(0, 2.8, 0, 7.4, 5.4, 1.0, CHAUME)
			for s in [-1.0, 1.0]:
				k.box(1.8 * s, 0, -2.52, 1.0, 2.0, 0.05, BOIS_F)
		"pique_nique_zoo":
			k.plate(0, 0, w, d, VERT_C)
			for i in 4:
				var x := -4.0 + (i % 2) * 8.0
				var z := -3.0 + (i / 2) * 6.0
				k.box(x, 0, z, 2.4, 0.75, 0.9, BOIS)
				k.box(x, 0, z - 0.8, 2.4, 0.45, 0.35, BOIS_C)
				k.box(x, 0, z + 0.8, 2.4, 0.45, 0.35, BOIS_C)
			k.tree(0, 0, 1.4)
			k.box(6.0, 0, 5.0, 0.6, 0.9, 0.6, Color("2f5a3e"))
		_:
			k.box(0, 0, 0, w * 0.8, 3.0, d * 0.8, BOIS)
