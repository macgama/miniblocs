class_name TourismeTypes
extends RefCounted
## Tourisme : bâtiments de la catégorie « Hôtels et tourisme » du panneau
## Construire (hébergements, office de tourisme, boutique de souvenirs, parking
## d'autocars).
##
## Même format que BuildingCatalog, plus un champ "touris" qui dit le rôle :
## - "hebergement" : on y dort. "genre" (camping, hotel, gite, auberge,
##   residence, village) ; "etoiles" (1 à 5) ; "chambres" (ou emplacements,
##   appartements) ; "lits" par chambre ; "prix" (€ par personne et par nuit,
##   réglable dans le menu Tourisme) ; "restaurant", "piscine", "spa",
##   "animation" (les clients y passent du temps et y dépensent) ; "cuisine"
##   (les clients font leurs courses en ville) ; "saison" [premier mois,
##   dernier mois] pour ce qui ferme l'hiver.
## - "office" : office de tourisme (plus de touristes, ils restent plus longtemps).
## - "souvenirs" : boutique de souvenirs (les touristes y dépensent).
## - "autocars" : parking d'autocars (les voyages organisés viennent).
## AUTRES : hôtels de la bible Blender (rôle « hotel ») reconnus comme hébergements.

const CATEGORY := "tourisme"
const ROAD := ["route"]
const RP := ["route", "chemin"]

const GENRES := {
	"camping": "Camping", "hotel": "Hôtel", "gite": "Gîte et chambres d'hôtes", "auberge": "Auberge de jeunesse",
	"residence": "Résidence de tourisme", "village": "Village vacances",
}

const TYPES := {
	# --- Plein air -----------------------------------------------------------------------------
	"aire_camping_cars": {"name": "Aire de camping-cars", "w": 30, "d": 40, "access": ROAD, "emplois": 1, "cost": 120_000,
		"touris": {"role": "hebergement", "genre": "camping", "etoiles": 1, "chambres": 24, "lits": 2.5, "prix": 7.0},
		"metiers": [["agent_proprete", 1]],
		"desc": "Bornes d'eau et d'électricité, vidange et vue sur rien de spécial. Les camping-caristes adorent quand même."},
	"camping": {"name": "Camping municipal", "w": 60, "d": 50, "access": RP, "emplois": 4, "cost": 600_000,
		"touris": {"role": "hebergement", "genre": "camping", "etoiles": 2, "chambres": 70, "lits": 3.0, "prix": 12.0, "saison": [4, 10]},
		"metiers": [["receptionniste", 2], ["agent_proprete", 2]],
		"desc": "Emplacements ombragés, sanitaires et une barrière qui ne se lève qu'à moitié. D'avril à octobre."},
	"camping_club": {"name": "Camping-club avec piscine", "w": 90, "d": 70, "access": ROAD, "emplois": 18, "cost": 2_800_000,
		"touris": {"role": "hebergement", "genre": "camping", "etoiles": 4, "chambres": 150, "lits": 3.5, "prix": 24.0, "saison": [4, 10],
			"piscine": true, "restaurant": true, "animation": true},
		"metiers": [["receptionniste", 3], ["animateur_vacances", 4], ["maitre_nageur", 2], ["serveur", 3], ["cuisinier", 2], ["agent_proprete", 4]],
		"desc": "Mobil-homes, toboggans aquatiques, mini-club et soirée karaoké. On entend « Les lacs du Connemara » jusqu'au village."},
	# --- Chez l'habitant -----------------------------------------------------------------------
	"gite_rural": {"name": "Gîte rural", "w": 12, "d": 14, "access": RP, "emplois": 1, "cost": 300_000,
		"touris": {"role": "hebergement", "genre": "gite", "etoiles": 3, "chambres": 3, "lits": 2.0, "prix": 38.0, "cuisine": true},
		"metiers": [["agent_etage", 1]],
		"desc": "Vieille maison de pierre retapée, poutres apparentes et cheminée. Les clients font leurs courses au village."},
	"chambres_hotes": {"name": "Chambres d'hôtes", "w": 14, "d": 16, "access": RP, "emplois": 2, "cost": 420_000,
		"touris": {"role": "hebergement", "genre": "gite", "etoiles": 3, "chambres": 5, "lits": 2.0, "prix": 52.0, "restaurant": true},
		"metiers": [["agent_etage", 1], ["cuisinier", 1]],
		"desc": "Cinq chambres, confitures maison et table d'hôtes. Les propriétaires racontent l'histoire du village (deux fois)."},
	"auberge_jeunesse": {"name": "Auberge de jeunesse", "w": 20, "d": 24, "access": RP, "emplois": 6, "cost": 1_600_000,
		"touris": {"role": "hebergement", "genre": "auberge", "etoiles": 1, "chambres": 30, "lits": 4.0, "prix": 26.0},
		"metiers": [["receptionniste", 3], ["agent_etage", 2], ["agent_proprete", 1]],
		"desc": "Dortoirs de quatre, cuisine commune et babyfoot. Des sacs à dos du monde entier dans l'entrée."},
	# --- Hôtels --------------------------------------------------------------------------------
	"hotel_2": {"name": "Hôtel du Commerce (2 étoiles)", "w": 16, "d": 14, "access": RP, "emplois": 8, "cost": 2_200_000,
		"touris": {"role": "hebergement", "genre": "hotel", "etoiles": 2, "chambres": 24, "lits": 2.0, "prix": 45.0},
		"metiers": [["receptionniste", 3], ["agent_etage", 4], ["cadre", 1]],
		"desc": "Hôtel de centre-ville, papier peint à fleurs et petit-déjeuner jusqu'à 9 h 30, pas une minute de plus."},
	"hotel_3": {"name": "Hôtel-restaurant 3 étoiles", "w": 30, "d": 20, "access": ROAD, "emplois": 25, "cost": 7_500_000,
		"touris": {"role": "hebergement", "genre": "hotel", "etoiles": 3, "chambres": 60, "lits": 2.0, "prix": 70.0, "restaurant": true},
		"metiers": [["receptionniste", 4], ["agent_etage", 9], ["serveur", 5], ["cuisinier", 4], ["cadre", 3]],
		"desc": "Soixante chambres, salle de restaurant et bar feutré. Le chef défend sa blanquette depuis vingt ans."},
	"hotel_4": {"name": "Grand hôtel 4 étoiles et spa", "w": 40, "d": 30, "access": ROAD, "emplois": 70, "cost": 22_000_000,
		"touris": {"role": "hebergement", "genre": "hotel", "etoiles": 4, "chambres": 120, "lits": 2.0, "prix": 125.0,
			"restaurant": true, "piscine": true, "spa": true},
		"metiers": [["receptionniste", 8], ["agent_etage", 24], ["serveur", 14], ["cuisinier", 10], ["maitre_nageur", 2], ["cadre", 12]],
		"desc": "Piscine sur le toit, spa, voiturier et peignoirs brodés. Les peignoirs disparaissent parfois dans les valises."},
	"palace": {"name": "Palace 5 étoiles", "w": 56, "d": 36, "access": ROAD, "emplois": 220, "cost": 60_000_000,
		"touris": {"role": "hebergement", "genre": "hotel", "etoiles": 5, "chambres": 160, "lits": 2.0, "prix": 290.0,
			"restaurant": true, "piscine": true, "spa": true},
		"metiers": [["receptionniste", 20], ["agent_etage", 70], ["serveur", 50], ["cuisinier", 40], ["maitre_nageur", 4], ["cadre", 36]],
		"desc": "Marbre, lustres, majordome et restaurant étoilé. Une nuit coûte un mois de loyer ; les clients ne regardent pas les prix."},
	# --- Séjours -------------------------------------------------------------------------------
	"residence_tourisme": {"name": "Résidence de tourisme (appartements)", "w": 30, "d": 18, "access": ROAD, "emplois": 6, "cost": 9_000_000,
		"touris": {"role": "hebergement", "genre": "residence", "etoiles": 3, "chambres": 50, "lits": 4.0, "prix": 36.0, "cuisine": true, "piscine": true},
		"metiers": [["receptionniste", 2], ["agent_etage", 3], ["cadre", 1]],
		"desc": "Appartements avec kitchenette et balcon : les familles restent une semaine et remplissent les caddies du supermarché."},
	"village_vacances": {"name": "Village vacances", "w": 100, "d": 80, "access": ROAD, "emplois": 45, "cost": 14_000_000,
		"touris": {"role": "hebergement", "genre": "village", "etoiles": 3, "chambres": 140, "lits": 4.0, "prix": 62.0, "saison": [4, 10],
			"restaurant": true, "piscine": true, "animation": true},
		"metiers": [["receptionniste", 4], ["animateur_vacances", 10], ["agent_etage", 10], ["serveur", 8], ["cuisinier", 6], ["maitre_nageur", 2], ["cadre", 5]],
		"desc": "Bungalows, pension complète, club enfants et spectacle des animateurs tous les soirs. Les G.O. dansent mieux que les clients."},
	# --- Accueil et services -------------------------------------------------------------------
	"office_tourisme": {"name": "Office de tourisme", "w": 12, "d": 12, "access": RP, "emplois": 3, "cost": 350_000,
		"touris": {"role": "office"},
		"metiers": [["conseiller_sejour", 3]],
		"desc": "Plans de la ville, brochures et conseils : plus de touristes, qui restent plus longtemps et découvrent toutes tes attractions."},
	"boutique_souvenirs_ville": {"name": "Boutique de souvenirs", "w": 8, "d": 10, "access": RP, "emplois": 2, "cost": 180_000,
		"touris": {"role": "souvenirs", "panier": 9.0},
		"metiers": [["vendeur", 2]],
		"desc": "Cartes postales, magnets, tour Eiffel qui clignote et tablier « J'ai survécu à mes vacances »."},
	"parking_autocars": {"name": "Parking d'autocars de tourisme", "w": 40, "d": 30, "access": ROAD, "emplois": 0, "cost": 250_000,
		"touris": {"role": "autocars", "places": 12},
		"desc": "Douze places de car et un abri. Les voyages organisés viennent en ville : 50 touristes d'un coup, appareil photo en main."},
}
const ORDER := ["aire_camping_cars", "camping", "camping_club", "gite_rural", "chambres_hotes", "auberge_jeunesse",
	"hotel_2", "hotel_3", "hotel_4", "palace", "residence_tourisme", "village_vacances", "office_tourisme", "boutique_souvenirs_ville", "parking_autocars"]

## Bâtiments d'autres catalogues reconnus (hôtels de la bible Blender, rôle « hotel »).
const AUTRES := {
	"motel": {"role": "hebergement", "genre": "hotel", "etoiles": 1, "chambres": 40, "lits": 2.0, "prix": 38.0, "piscine": true},
	"hotel_chaine": {"role": "hebergement", "genre": "hotel", "etoiles": 2, "chambres": 110, "lits": 2.0, "prix": 42.0},
	"auberge_montagne": {"role": "hebergement", "genre": "hotel", "etoiles": 3, "chambres": 32, "lits": 2.0, "prix": 78.0, "restaurant": true},
	"ryokan": {"role": "hebergement", "genre": "hotel", "etoiles": 4, "chambres": 24, "lits": 2.0, "prix": 140.0, "restaurant": true, "spa": true},
	"palace_belle_epoque": {"role": "hebergement", "genre": "hotel", "etoiles": 5, "chambres": 180, "lits": 2.0, "prix": 260.0, "restaurant": true, "spa": true},
	"tour_hotel": {"role": "hebergement", "genre": "hotel", "etoiles": 5, "chambres": 650, "lits": 2.0, "prix": 210.0, "restaurant": true, "spa": true, "piscine": true},
}

## Taxe de séjour par personne et par nuit, selon les étoiles (barème français arrondi).
const TAXE_SEJOUR := {0: 0.5, 1: 0.8, 2: 0.9, 3: 1.5, 4: 2.3, 5: 4.0}
## Prix de référence par personne et par nuit selon les étoiles.
const PRIX_REF := {1: 20.0, 2: 45.0, 3: 70.0, 4: 125.0, 5: 280.0}


static func entries() -> Dictionary:
	var out := {}
	for id in ORDER:
		var t: Dictionary = TYPES[id].duplicate()
		t["cat"] = CATEGORY
		t["region"] = "monde"
		t["era"] = "moderne"
		t["style"] = ""
		t["role"] = "hotel" if String(t.touris.role) == "hebergement" else "tourisme"
		out[id] = t
	return out


## Rôle touristique d'un type de bâtiment ({} si aucun).
static func spec_of(type_id: String) -> Dictionary:
	if TYPES.has(type_id):
		return TYPES[type_id].touris
	if AUTRES.has(type_id):
		return AUTRES[type_id]
	var t := BuildingCatalog.get_type(type_id)
	if t.is_empty():
		return {}
	var base := String(t.get("base", ""))
	if base != "" and base != type_id:
		var sb := spec_of(base)
		if not sb.is_empty():
			return sb
	if String(t.get("role", "")) == "hotel" or String(t.get("arch", "")) == "hotel":
		# Hôtel inconnu : deux étoiles, une chambre pour deux emplois.
		return {"role": "hebergement", "genre": "hotel", "etoiles": 2, "chambres": maxi(10, int(t.get("emplois", 10)) * 2), "lits": 2.0, "prix": 50.0}
	return {}


static func est_hebergement(type_id: String) -> bool:
	return String(spec_of(type_id).get("role", "")) == "hebergement"


static func lits_de(spec: Dictionary) -> int:
	return roundi(float(spec.get("chambres", 0)) * float(spec.get("lits", 2.0)))


static func prix_ref(etoiles: int) -> float:
	return float(PRIX_REF.get(clampi(etoiles, 1, 5), 60.0))


static func taxe(etoiles: int) -> float:
	return float(TAXE_SEJOUR.get(clampi(etoiles, 0, 5), 1.0))


# --- Modèles low-poly ------------------------------------------------------------------------

const ENDUIT := Color("efe4cf")
const CREME := Color("f4ecd8")
const TUILE := Color("c8553d")
const ARDOISE := Color("4f5660")
const VITRE := Color("33495e")
const PORTE := Color("6b4a33")
const HERBE := Color("6aa84f")
const BITUME := Color("55585e")
const BOIS := Color("9c6b45")
const EAU := Color("4fb3d9")
const BLANC := Color("f7f7f5")
const ENSEIGNE := Color("2a9d8f")


static func build(k: BlocMesh, id: String, t: Dictionary) -> void:
	var w := float(t.w)
	var d := float(t.d)
	match id:
		"aire_camping_cars":
			k.plate(0, 0, w, d, BITUME)
			for i in 4:
				var x := -10.5 + i * 7.0
				k.box(x, 0.08, -8.0, 0.12, 0.02, 14.0, BLANC)
				_camping_car(k, x + 3.5, -8.0, Color("f1faee") if i % 2 == 0 else Color("e9c46a"))
			k.box(0, 0.08, 9.0, 3.0, 1.2, 1.0, Color("8d99ae"))
			k.box(0, 1.2, 9.0, 0.6, 0.8, 0.6, ENSEIGNE)
			k.box(-12, 0, 15, 0.2, 3.2, 0.2, Color("adb5bd"))
			k.box(-12, 3.2, 15, 2.4, 1.4, 0.2, Color("1d3557"))
			for x in [-13.0, 13.0]:
				for z in [-17.0, 0.0, 16.0]:
					k.tree(x, z, 0.9)
		"camping", "camping_club":
			k.plate(0, 0, w, d, HERBE)
			k.box(0, 0.08, 0, 3.0, 0.03, d - 4.0, Color("c2a878"))
			k.box(0, 0.08, 0, w - 6.0, 0.03, 3.0, Color("c2a878"))
			var club := id == "camping_club"
			# Accueil à l'entrée (devant, -z).
			k.box(-w * 0.5 + 7.0, 0, -d * 0.5 + 5.0, 9.0, 3.4, 6.0, CREME)
			k.gable(-w * 0.5 + 7.0, 3.4, -d * 0.5 + 5.0, 9.6, 6.6, 1.8, TUILE)
			k.box(-w * 0.5 + 7.0, 0, -d * 0.5 + 1.95, 1.2, 2.2, 0.1, PORTE)
			k.box(-w * 0.5 + 14.0, 0, -d * 0.5 + 2.0, 0.2, 1.1, 0.2, Color("e63946"))
			k.box(-w * 0.5 + 16.5, 1.0, -d * 0.5 + 2.0, 5.0, 0.15, 0.15, Color("e63946"))
			# Tentes et mobil-homes en rangées.
			var colors := [Color("e76f51"), Color("2a9d8f"), Color("e9c46a"), Color("457b9d"), Color("f4a261")]
			var n := 0
			for gx in range(-int(w * 0.5) + 6, int(w * 0.5) - 4, 8):
				for gz in range(-int(d * 0.5) + 12, int(d * 0.5) - 3, 8):
					if absf(gx) < 4.0 or absf(gz) < 4.0:
						continue
					# Piscine et restaurant du camping-club : place libre.
					if club and absf(gx) < 22.0 and gz < -4.0:
						continue
					n += 1
					if club and n % 2 == 0:
						k.box(gx, 0.3, gz, 3.0, 2.6, 7.0, BLANC)
						k.box(gx, 2.9, gz, 3.2, 0.2, 7.2, Color("adb5bd"))
						k.box(gx - 1.55, 1.0, gz, 0.05, 0.9, 1.4, VITRE)
					else:
						k.gable(gx, 0.0, gz, 2.6, 3.0, 1.5, colors[n % colors.size()])
					if n % 3 == 0:
						k.tree(gx + 3.4, gz + 2.5, 0.85)
			# Sanitaires.
			k.box(w * 0.5 - 8.0, 0, -d * 0.5 + 6.0, 8.0, 2.8, 5.0, Color("dee2e6"))
			k.box(w * 0.5 - 8.0, 2.8, -d * 0.5 + 6.0, 8.4, 0.25, 5.4, Color("8d99ae"))
			if club:
				# Piscine et toboggan, restaurant.
				k.box(10.0, 0.05, -14.0, 18.0, 0.1, 10.0, Color("e9ecef"))
				k.box(10.0, 0.06, -14.0, 15.0, 0.12, 7.5, EAU)
				k.cylinder(19.5, 0, -18.0, 0.6, 0.6, 5.0, 6, Color("adb5bd"))
				k.box(16.0, 2.0, -16.5, 7.0, 0.5, 1.0, Color("f4a261"))
				k.box(-10.0, 0, -14.0, 12.0, 3.6, 8.0, CREME)
				k.box(-10.0, 3.6, -14.0, 13.0, 0.3, 9.0, Color("e76f51"))
				k.windows_row(-10.0, -18.05, 10.0, 1.0, 4, 1.8, 1.6, VITRE)
		"gite_rural":
			k.plate(0, 0, w, d, HERBE)
			k.box(0, 0, -1.0, 9.0, 5.6, 7.5, Color("b8ab95"))
			k.gable(0, 5.6, -1.0, 9.8, 8.3, 3.0, TUILE)
			k.box(0, 0, -4.8, 1.1, 2.2, 0.1, PORTE)
			k.windows_row(0, -4.8, 7.0, 3.4, 3, 0.9, 1.1, VITRE)
			for x in [-3.0, 3.0]:
				k.box(x, 0.8, -4.85, 1.1, 1.2, 0.05, Color("4c8c3f"))
				k.box(x, 0.8, -4.82, 0.9, 1.1, 0.05, VITRE)
			k.box(3.0, 5.6, 1.0, 0.8, 2.8, 0.8, Color("8c7b6a"))
			k.box(-3.5, 0, 4.5, 2.0, 0.9, 0.9, BOIS)
			k.tree(4.0, 5.0, 0.9)
			k.box(0, 0, 6.8, w, 0.9, 0.2, Color("a39e93"))
		"chambres_hotes":
			k.plate(0, 0, w, d, HERBE)
			k.box(0, 0, -1.5, 11.0, 6.2, 8.0, ENDUIT)
			k.hip(0, 6.2, -1.5, 11.8, 8.8, 3.0, TUILE)
			k.box(0, 0, -5.55, 1.2, 2.3, 0.1, PORTE)
			k.windows_row(0, -5.55, 9.0, 0.9, 4, 0.9, 1.3, VITRE)
			k.windows_row(0, -5.55, 9.0, 3.8, 4, 0.9, 1.2, VITRE)
			k.box(0, 0, 4.5, 8.0, 0.1, 4.0, Color("c2a878"))
			for x in [-2.5, 0.5, 3.5]:
				k.cylinder(x, 0.1, 4.5, 0.6, 0.6, 0.8, 8, BLANC)
			k.box(-4.5, 0, -6.3, 0.2, 1.8, 0.2, BOIS)
			k.box(-4.5, 1.8, -6.3, 1.6, 0.6, 0.1, Color("e9c46a"))
			k.tree(5.0, 6.0, 0.9)
		"auberge_jeunesse":
			k.plate(0, 0, w, d, Color("a39e93"))
			k.box(0, 0, 0, 16.0, 9.0, 18.0, Color("e9c46a"))
			k.box(0, 9.0, 0, 16.4, 0.4, 18.4, Color("6c757d"))
			k.box(0, 0, -9.05, 2.4, 2.6, 0.1, VITRE)
			for y in [1.0, 4.0, 7.0]:
				k.windows_row(0, -9.05, 14.0, y, 5, 1.2, 1.4, VITRE)
			k.box(0, 3.0, -9.15, 8.0, 1.0, 0.1, Color("e76f51"))
			for x in [-6.0, -4.5, 6.0]:
				k.box(x, 0, -10.5, 0.15, 0.9, 1.6, Color("2a9d8f"))
		"hotel_2":
			k.plate(0, 0, w, d, Color("a39e93"))
			k.box(0, 0, 0, 14.0, 11.5, 12.0, Color("f2d0a9"))
			k.gable(0, 11.5, 0, 14.6, 12.6, 3.6, ARDOISE)
			k.box(0, 0, -6.05, 2.0, 2.6, 0.1, PORTE)
			k.box(0, 2.6, -6.6, 3.2, 0.15, 1.2, Color("8b2c2c"))
			for y in [3.6, 6.4, 9.2]:
				k.windows_row(0, -6.05, 12.0, y, 5, 1.0, 1.5, VITRE)
			k.windows_row(0, -6.05, 12.0, 0.6, 2, 2.2, 1.8, VITRE)
			k.box(6.3, 4.0, -6.4, 0.2, 5.0, 0.8, Color("1d3557"))
			_etoiles(k, 6.3, 9.2, -6.85, 2)
		"hotel_3":
			k.plate(0, 0, w, d, Color("a39e93"))
			k.box(0, 0, 1.0, 26.0, 15.0, 15.0, CREME)
			k.box(0, 15.0, 1.0, 26.4, 0.5, 15.4, Color("6c757d"))
			k.box(0, 0, -7.0, 10.0, 4.0, 2.0, Color("e9ecef"))
			k.box(0, 4.0, -7.0, 10.4, 0.3, 2.4, Color("1d3557"))
			k.box(0, 0, -8.05, 3.0, 2.8, 0.1, VITRE)
			k.windows_row(-8.5, -8.0, 4.0, 0.6, 2, 1.6, 2.4, VITRE)
			for y in [4.6, 7.8, 11.0]:
				k.windows_row(0, -6.55, 24.0, y, 10, 1.1, 1.6, VITRE)
			k.box(0, 15.5, 1.0, 9.0, 1.4, 0.3, Color("1d3557"))
			_etoiles(k, 0.0, 17.2, 0.8, 3)
			for x in [-11.0, 11.0]:
				k.tree(x, -8.5, 0.8)
		"hotel_4":
			k.plate(0, 0, w, d, Color("a39e93"))
			k.box(0, 0, 2.0, 36.0, 24.0, 22.0, Color("e9e2d4"))
			k.window_bands(0, 2.0, 36.0, 22.0, 3.6, 6, 3.4, VITRE)
			k.box(0, 24.0, 2.0, 36.4, 0.4, 22.4, Color("6c757d"))
			# Piscine sur le toit.
			k.box(4.0, 24.4, 2.0, 18.0, 0.6, 9.0, Color("dee2e6"))
			k.box(4.0, 24.5, 2.0, 16.0, 0.6, 7.0, EAU)
			k.box(-11.0, 24.4, 2.0, 7.0, 3.0, 8.0, VITRE)
			# Marquise et voiturier.
			k.box(0, 3.4, -11.5, 14.0, 0.4, 6.0, Color("343a40"))
			for x in [-6.5, 6.5]:
				k.box(x, 0, -14.0, 0.3, 3.4, 0.3, Color("adb5bd"))
			k.box(0, 0, -9.05, 4.0, 3.0, 0.1, Color("e9c46a"))
			_etoiles(k, 0.0, 4.1, -14.4, 4)
			for x in [-16.0, 16.0]:
				k.tree(x, -12.5, 0.9)
		"palace":
			k.plate(0, 0, w, d, Color("c2a878"))
			k.box(0, 0, 2.0, 50.0, 22.0, 26.0, Color("f8f1e1"))
			for y in [3.0, 7.2, 11.4, 15.6]:
				k.windows_row(0, -11.05, 46.0, y, 18, 1.2, 2.4, VITRE)
				k.box(0, y - 0.3, -11.3, 48.0, 0.25, 0.6, BLANC)
			k.hip(0, 22.0, 2.0, 50.4, 26.4, 5.0, ARDOISE)
			for x in [-23.0, 23.0]:
				k.box(x, 0, -9.0, 8.0, 26.0, 8.0, Color("f8f1e1"))
				k.dome(x, 26.0, -9.0, 4.5, 5.0, Color("5b6d7a"))
			k.box(0, 0, -11.5, 8.0, 3.2, 1.0, Color("e9c46a"))
			k.box(0, 3.2, -14.0, 16.0, 0.4, 6.0, Color("343a40"))
			k.box(0, 0.08, -15.5, 22.0, 0.04, 3.0, Color("8b2c2c"))
			_etoiles(k, 0.0, 3.8, -17.1, 5)
			for x in [-14.0, -8.0, 8.0, 14.0]:
				k.cylinder(x, 0, -16.0, 0.5, 0.5, 1.2, 8, Color("adb5bd"))
				k.tree(x, -16.0, 0.5)
		"residence_tourisme":
			k.plate(0, 0, w, d, HERBE)
			k.box(0, 0, 0, 26.0, 12.0, 12.0, Color("f1e6d2"))
			k.box(0, 12.0, 0, 26.4, 0.4, 12.4, TUILE)
			for y in [0.6, 3.6, 6.6, 9.6]:
				k.windows_row(0, -6.05, 24.0, y, 8, 1.6, 2.0, VITRE)
				k.box(0, y + 2.4, -6.7, 25.0, 0.15, 1.2, Color("dee2e6"))
			k.box(-6.0, 0.05, 7.5, 12.0, 0.1, 2.5, Color("e9ecef"))
			k.box(-6.0, 0.06, 7.5, 10.0, 0.12, 1.8, EAU)
		"village_vacances":
			k.plate(0, 0, w, d, HERBE)
			# Bâtiment central : accueil, restaurant, scène.
			k.box(0, 0, -d * 0.5 + 10.0, 30.0, 6.0, 14.0, CREME)
			k.gable(0, 6.0, -d * 0.5 + 10.0, 31.0, 15.0, 3.6, TUILE)
			k.box(0, 0, -d * 0.5 + 2.95, 4.0, 2.8, 0.1, VITRE)
			k.windows_row(0, -d * 0.5 + 2.95, 26.0, 1.0, 8, 1.8, 2.2, VITRE)
			# Piscine et toboggans.
			k.box(0, 0.05, -6.0, 28.0, 0.1, 14.0, Color("e9ecef"))
			k.box(0, 0.06, -6.0, 24.0, 0.12, 10.0, EAU)
			k.cylinder(13.0, 0, -12.0, 0.7, 0.7, 6.0, 6, Color("adb5bd"))
			k.box(9.5, 3.0, -10.0, 7.0, 0.6, 1.2, Color("e76f51"))
			# Bungalows.
			var cols := [Color("f4a261"), Color("e9c46a"), Color("ffffff"), Color("a8dadc")]
			var i := 0
			for gx in range(-44, 45, 11):
				for gz in [8, 20, 32]:
					i += 1
					k.box(gx, 0, gz, 7.0, 3.0, 6.0, cols[i % cols.size()])
					k.gable(gx, 3.0, gz, 7.6, 6.6, 1.6, TUILE if i % 2 == 0 else Color("b5651d"))
					k.box(gx, 0, gz - 3.05, 1.0, 2.0, 0.1, PORTE)
					if i % 3 == 0:
						k.tree(gx + 5.0, gz + 3.0, 0.9)
			# Terrain de jeux et scène en plein air.
			k.box(-32.0, 0.06, -14.0, 18.0, 0.05, 10.0, Color("c97b4a"))
			k.box(32.0, 0, -14.0, 12.0, 1.0, 8.0, BOIS)
			k.box(32.0, 1.0, -17.5, 12.0, 4.0, 0.3, Color("343a40"))
		"office_tourisme":
			k.plate(0, 0, w, d, Color("c2a878"))
			k.box(0, 0, 0, 9.0, 4.2, 8.0, CREME)
			k.box(0, 4.2, 0, 9.6, 0.4, 8.6, Color("2a9d8f"))
			k.box(0, 0, -4.05, 6.0, 3.0, 0.1, VITRE)
			# Grand « i » d'information.
			k.box(3.8, 0, -5.2, 0.25, 3.6, 0.25, Color("adb5bd"))
			k.box(3.8, 3.6, -5.2, 1.8, 1.8, 0.2, Color("2a9d8f"))
			k.box(3.8, 3.95, -5.32, 0.3, 0.8, 0.05, BLANC)
			k.box(3.8, 4.95, -5.32, 0.3, 0.25, 0.05, BLANC)
			k.box(-3.0, 0, -5.4, 2.0, 1.4, 0.15, Color("1d3557"))
		"boutique_souvenirs_ville":
			k.plate(0, 0, w, d, Color("a39e93"))
			k.box(0, 0, 0.5, 7.0, 4.0, 8.0, Color("f2d0a9"))
			k.gable(0, 4.0, 0.5, 7.6, 8.6, 2.2, TUILE)
			k.box(0, 0.3, -3.55, 5.0, 2.4, 0.1, VITRE)
			k.box(0, 2.6, -4.0, 6.6, 0.12, 1.0, Color("e63946"))
			for x in [-2.2, 0.0, 2.2]:
				k.box(x, 0, -4.4, 0.7, 1.4, 0.4, Color("e9c46a"))
			k.box(2.6, 0, -4.8, 0.5, 1.6, 0.5, Color("457b9d"))
		"parking_autocars":
			k.plate(0, 0, w, d, BITUME)
			for i in 6:
				var x := -15.0 + i * 6.0
				k.box(x - 3.0, 0.08, -2.0, 0.15, 0.02, 14.0, BLANC)
				if i % 2 == 0:
					_autocar(k, x, -2.0)
			k.box(0, 0, 11.5, 12.0, 2.8, 3.0, Color("adb5bd"))
			k.box(0, 2.8, 11.5, 12.6, 0.2, 3.6, ENSEIGNE)
			k.box(-17.0, 0, 12.0, 0.25, 3.5, 0.25, Color("adb5bd"))
			k.box(-17.0, 3.5, 12.0, 2.0, 1.6, 0.2, Color("1d3557"))
		_:
			k.box(0, 0, 0, w * 0.8, 6.0, d * 0.8, CREME)


static func _camping_car(k: BlocMesh, x: float, z: float, col: Color) -> void:
	k.box(x, 0.4, z, 2.3, 2.6, 7.0, col)
	k.box(x, 3.0, z + 0.5, 2.3, 0.6, 5.0, col)
	k.box(x, 1.6, z - 3.55, 2.0, 1.0, 0.1, VITRE)
	for zz in [-2.4, 2.4]:
		k.box(x, 0.0, z + zz, 2.5, 0.6, 0.8, Color("212529"))


static func _autocar(k: BlocMesh, x: float, z: float) -> void:
	k.box(x, 0.4, z, 2.5, 3.2, 12.0, Color("f1faee"))
	k.box(x, 1.4, z, 2.55, 1.2, 11.0, VITRE)
	k.box(x, 0.5, z, 2.56, 0.5, 12.0, Color("e76f51"))
	for zz in [-4.0, 4.0]:
		k.box(x, 0.0, z + zz, 2.6, 0.7, 1.0, Color("212529"))


## Les étoiles de l'enseigne (petits cubes dorés).
static func _etoiles(k: BlocMesh, x: float, y: float, z: float, n: int) -> void:
	var w := 0.5
	for i in n:
		var xx := x + (float(i) - float(n - 1) * 0.5) * (w + 0.2)
		k.box(xx, y, z, w, w, 0.12, Color("ffd166"))
