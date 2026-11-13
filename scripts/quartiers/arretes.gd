class_name Arretes
extends RefCounted
## Catalogue des arrêtés municipaux qu'un maire peut prendre pour un quartier
## (panneau Quartiers, Maj+Y). Chaque arrêté a :
##   - un coût de mise en place (€ par hectare, une fois : panneaux, ralentisseurs,
##     bacs, aménagements) et un coût par mois (€ par hectare : contrôles, rondes,
##     électricité, entretien ; négatif = une économie pour la ville) ;
##   - des effets sur les autres systèmes (trafic, bruit, déchets, incendies,
##     stationnement, valeur des terrains), appliqués par Quartiers ;
##   - un effet sur l'avis des habitants du quartier, par thème (AVIS) ;
##   - les programmes (tendances des listes, Elections) qui le défendent ou le
##     combattent : un conseil élu qui a pris la mairie au joueur les suit.
## Les deux arrêtés d'éclairage s'excluent l'un l'autre.

const LISTE := [
	{"id": "zone_30", "nom": "Zone 30", "icone": "circulation", "pose": 1500, "mois": 40,
		"desc": "Vitesse limitée à 30 km/h dans les rues et avenues du quartier, ralentisseurs et panneaux.",
		"effets": ["voitures à 30 km/h dans le quartier", "les trajets de transit passent ailleurs", "bruit des voies −15 %"],
		"avis": {"securite": 2.0}, "pour": ["ecologie", "securite", "solidarite"], "contre": []},
	{"id": "rue_pietonne", "nom": "Rues piétonnes", "icone": "pieton", "pose": 8000, "mois": 150,
		"desc": "Les petites rues deviennent piétonnes : seuls riverains, livraisons et secours y roulent, au pas.",
		"effets": ["rues fermées au transit (riverains au pas)", "bruit −40 %, air −30 %", "commerces plus attirants, terrains plus chers"],
		"avis": {"loisirs": 3.0, "commerces": 2.0, "transports": -1.0}, "pour": ["ecologie"], "contre": ["contribuables"]},
	{"id": "poids_lourds", "nom": "Interdit aux poids lourds", "icone": "vehicules", "pose": 500, "mois": 20,
		"desc": "Camions de plus de 3,5 t interdits sauf livraisons ; ils contournent le quartier.",
		"effets": ["presque plus de camions sur les voies du quartier", "moins de bruit le long des grands axes"],
		"avis": {"environnement": 1.0}, "pour": ["ecologie", "securite"], "contre": []},
	{"id": "calme_nuit", "nom": "Tranquillité la nuit", "icone": "lune", "pose": 300, "mois": 60,
		"desc": "De 22 h à 6 h : terrasses rentrées, musique coupée, rondes de la police municipale.",
		"effets": ["bruit la nuit −40 %", "les jeunes adultes regrettent les soirées"],
		"avis": {"environnement": 2.0}, "pour": ["securite", "solidarite"], "contre": []},
	{"id": "tri_obligatoire", "nom": "Tri des déchets obligatoire", "icone": "dechets", "pose": 600, "mois": 30,
		"desc": "Bacs jaunes et verre pour tous, contrôles et amendes pour les mauvais trieurs.",
		"effets": ["+25 points de tri (avec un centre de tri)", "moins d'ordures à brûler ou enterrer"],
		"avis": {"environnement": 1.0}, "pour": ["ecologie", "solidarite"], "contre": ["contribuables"]},
	{"id": "detecteurs_fumee", "nom": "Détecteurs de fumée obligatoires", "icone": "feu", "pose": 900, "mois": 10,
		"desc": "Un détecteur par logement et par commerce, la ville aide à les acheter.",
		"effets": ["deux fois moins de départs de feu", "le feu est repéré plus tôt"],
		"avis": {"securite": 1.0}, "pour": ["securite", "solidarite"], "contre": []},
	{"id": "eclairage_nuit", "nom": "Éclairage renforcé la nuit", "icone": "soleil", "pose": 2500, "mois": 70,
		"desc": "Plus de lampadaires, allumés toute la nuit, rues et passages éclairés.",
		"effets": ["les habitants se sentent en sécurité", "facture d'électricité en plus"],
		"avis": {"securite": 3.0}, "pour": ["securite"], "contre": ["ecologie", "contribuables"], "exclut": "extinction_eclairage"},
	{"id": "extinction_eclairage", "nom": "Extinction de l'éclairage (1 h – 5 h)", "icone": "lune", "pose": 200, "mois": -25,
		"desc": "Lampadaires éteints au cœur de la nuit : économies, et on revoit les étoiles.",
		"effets": ["économie d'électricité pour la ville", "la nuit fait un peu peur à certains"],
		"avis": {"environnement": 1.0, "securite": -2.0}, "pour": ["ecologie", "contribuables"], "contre": ["securite"], "exclut": "eclairage_nuit"},
	{"id": "stationnement_payant", "nom": "Stationnement payant", "icone": "budget", "pose": 1200, "mois": 15,
		"desc": "Horodateurs le long des rues : 1,50 € la journée, gratuit la nuit.",
		"effets": ["recettes de stationnement pour la ville", "moins de voitures : bus, vélo, marche"],
		"avis": {"transports": -1.0}, "pour": ["ecologie", "contribuables"], "contre": ["solidarite"]},
	{"id": "espaces_verts", "nom": "Fleurissement et jardins partagés", "icone": "paysage", "pose": 2000, "mois": 120,
		"desc": "Massifs fleuris, arbres d'alignement, jardins partagés au pied des immeubles.",
		"effets": ["air et bruit un peu filtrés", "terrains plus chers, quartier plus agréable"],
		"avis": {"environnement": 2.0, "loisirs": 1.0}, "pour": ["ecologie", "solidarite"], "contre": ["contribuables"]},
]

## Tarif des places le long des rues d'un quartier en stationnement payant (€ par jour).
const TARIF_STATIONNEMENT := 1.5
## Vitesse en zone 30 (km/h) et allure dans une rue piétonne (km/h).
const KMH_ZONE_30 := 30.0
const KMH_PIETONNE := 10.0
## Coût d'un tronçon pour les trajets (×) : on évite les zones 30 et les rues piétonnes.
const DETOUR_PIETONNE := 4.0
## Part des poids lourds qui restent (livraisons du quartier).
const LOURDS_RESTANTS := 0.15
## Départs de feu (×) avec les détecteurs.
const FEU_DETECTEURS := 0.5
## Points de tri en plus (avec un centre de tri), plafond.
const TRI_EN_PLUS := 0.25
const TRI_MAX := 0.92


static func get_arrete(id: String) -> Dictionary:
	for a in LISTE:
		if String(a.id) == id:
			return a
	return {}


static func ids() -> Array:
	return LISTE.map(func(a: Dictionary) -> String: return String(a.id))


static func nom(id: String) -> String:
	return String(get_arrete(id).get("nom", id))


## Coût de mise en place pour une surface (ha), × réglage Admin « coût des constructions ».
static func cout_pose(id: String, ha: float) -> int:
	return ReglagesPartie.prix(roundi(float(get_arrete(id).get("pose", 0)) * maxf(ha, 0.25)))


## Coût par mois (négatif : économie) pour une surface (ha).
static func cout_mois(id: String, ha: float) -> float:
	return float(get_arrete(id).get("mois", 0)) * maxf(ha, 0.25) * ReglagesPartie.actuel.cout_construction


## Arrêté incompatible avec id ("" : aucun).
static func exclut(id: String) -> String:
	return String(get_arrete(id).get("exclut", ""))


## Avis d'un programme (tendance d'une liste) sur un arrêté : 1 pour, −1 contre, 0 neutre.
static func avis_programme(id: String, tendance: String) -> int:
	var a := get_arrete(id)
	if (a.get("pour", []) as Array).has(tendance):
		return 1
	if (a.get("contre", []) as Array).has(tendance):
		return -1
	return 0
