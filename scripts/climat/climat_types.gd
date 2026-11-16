class_name ClimatTypes
extends RefCounted
## Données du climat : courbes historiques et scénarios du réchauffement,
## intensité carbone des filières électriques et des carburants au fil des
## époques, émissions des industries, et mesures du plan climat (datées).
##
## Les ordres de grandeur sont réels (GIEC, Agence internationale de l'énergie,
## ADEME) mais arrondis : le but est que le joueur voie l'effet de ses choix.

# --- Réchauffement ------------------------------------------------------------------------

## Écart de température mondiale (°C) à l'époque préindustrielle (1850-1900), lissé.
const HISTOIRE := [[1800, -0.1], [1815, -0.3], [1830, -0.05], [1850, 0.0], [1880, -0.05], [1900, 0.0], [1910, -0.1],
	[1940, 0.3], [1950, 0.2], [1970, 0.25], [1980, 0.45], [1990, 0.6], [2000, 0.75], [2010, 0.95], [2020, 1.25], [2026, 1.45]]
## Année où l'histoire réelle s'arrête et où les scénarios prennent le relais.
const ANNEE_PRESENT := 2026
## Écart de l'époque où la météo du jeu a été réglée (aujourd'hui) : la météo
## n'est décalée que de ce qui change par rapport à lui.
const ECART_REFERENCE := 1.45
## Scénarios après 2026 (proches des SSP du GIEC) : sobre, médian, fossile.
const SCENARIOS := [
	[[2026, 1.45], [2040, 1.6], [2060, 1.75], [2100, 1.8], [2200, 1.6], [2500, 1.4]],
	[[2026, 1.45], [2040, 1.8], [2060, 2.1], [2100, 2.7], [2200, 3.3], [2500, 3.6]],
	[[2026, 1.45], [2040, 1.9], [2060, 2.5], [2100, 4.4], [2200, 7.0], [2500, 8.0]],
]
const SCENARIO_NOMS := ["sobre", "médian", "fossile"]
## Émissions par habitant (t CO₂ par an) qui mènent à chaque scénario.
const INTENSITE_SCENARIOS := [2.0, 6.0, 12.0]
## Émissions par habitant d'un pays industrialisé typique de chaque époque (t CO₂/an).
const INTENSITE_EPOQUE := [[1800, 0.3], [1850, 1.0], [1900, 3.0], [1950, 5.0], [1970, 10.0], [1990, 9.0], [2010, 8.0], [2026, 6.5]]
## Années d'inertie : la température rejoint sa cible en quelques années.
const INERTIE := 5.0
## Les terres se réchauffent plus que la moyenne du globe (océans compris).
const FACTEUR_TERRES := 1.3

## Réglage Admin « Réchauffement climatique ».
const REGLAGES := ["Désactivé", "Histoire réelle (scénario médian ensuite)", "Le monde suit l'exemple de vos villes", "Accéléré (effets ×2)"]

# --- Filières électriques -------------------------------------------------------------------

## t CO₂ par MWh produit (cycle de vie arrondi).
const FILIERES := {
	"charbon": {"nom": "Charbon", "co2": 0.95, "couleur": Color("5c4d3c")},
	"gaz": {"nom": "Gaz", "co2": 0.40, "couleur": Color("f77f00")},
	"biomasse": {"nom": "Biomasse", "co2": 0.05, "couleur": Color("8a9a5b")},
	"dechets": {"nom": "Déchets", "co2": 0.50, "couleur": Color("a47148")},
	"national": {"nom": "Réseau national", "co2": -1.0, "couleur": Color("adb5bd")},
	"nucleaire": {"nom": "Nucléaire", "co2": 0.012, "couleur": Color("b388ff")},
	"hydro": {"nom": "Hydraulique", "co2": 0.01, "couleur": Color("4cc9f0")},
	"eolien": {"nom": "Éolien", "co2": 0.011, "couleur": Color("90e0ef")},
	"solaire": {"nom": "Solaire", "co2": 0.035, "couleur": Color("ffd166")},
	"autre": {"nom": "Autres", "co2": 0.5, "couleur": Color("6c757d")},
}
const ORDRE_FILIERES := ["charbon", "gaz", "dechets", "national", "biomasse", "nucleaire", "hydro", "eolien", "solaire", "autre"]
## Filières renouvelables ou bas carbone (pour la part « propre » du mix).
const BAS_CARBONE := ["nucleaire", "hydro", "eolien", "solaire", "biomasse"]

## Intensité du réseau national (t CO₂/MWh) d'un pays industrialisé typique.
const NATIONAL := [[1882, 1.5], [1920, 1.2], [1950, 1.0], [1970, 0.8], [1990, 0.65], [2010, 0.5], [2026, 0.4]]
## Intensité en 2050 selon le scénario mondial (sobre, médian, fossile).
const NATIONAL_2050 := [0.05, 0.2, 0.45]
## Pays dont le réseau est très différent (t CO₂/MWh vers 2025).
const NATIONAL_PAYS := {"fr": 0.05, "ch": 0.03, "no": 0.02, "se": 0.04, "is": 0.01, "at": 0.12, "ca": 0.12, "br": 0.1,
	"de": 0.38, "gb": 0.2, "es": 0.15, "it": 0.3, "be": 0.15, "nl": 0.35, "pl": 0.7, "us": 0.37, "cn": 0.55, "in": 0.7,
	"jp": 0.45, "au": 0.6, "za": 0.9, "ma": 0.6, "dz": 0.5, "tn": 0.45, "sn": 0.55, "ci": 0.4, "cm": 0.3}

# --- Autres secteurs ----------------------------------------------------------------------

## Secteurs du bilan carbone (t CO₂ équivalent).
const SECTEURS := {
	"electricite": {"nom": "Électricité", "couleur": Color("ffd166"), "icone": "reseaux"},
	"chauffage": {"nom": "Chauffage", "couleur": Color("f77f00"), "icone": "thermometre"},
	"transport": {"nom": "Transports", "couleur": Color("6ea8fe"), "icone": "circulation"},
	"industrie": {"nom": "Industrie", "couleur": Color("adb5bd"), "icone": "industrie"},
	"agriculture": {"nom": "Agriculture", "couleur": Color("90be6d"), "icone": "feuille"},
	"dechets": {"nom": "Déchets", "couleur": Color("a47148"), "icone": "dechets"},
	"absorption": {"nom": "Forêts et parcs (absorbé)", "couleur": Color("2d6a4f"), "icone": "arbre"},
}
const ORDRE_SECTEURS := ["electricite", "chauffage", "transport", "industrie", "agriculture", "dechets", "absorption"]

## Chauffage sans réseau de gaz : t CO₂ par MWh de chaleur (bois, puis charbon,
## fioul, et pompes à chaleur à la fin).
const CHAUFFAGE := [[1800, 0.05], [1850, 0.2], [1880, 0.32], [1950, 0.32], [1970, 0.28], [2000, 0.22], [2026, 0.12], [2050, 0.05]]
## Puissance de chauffage d'un foyer au plus froid (MW).
const CHAUFFAGE_FOYER := 0.004
## Gaz du réseau : t CO₂ par MWh.
const GAZ_CO2 := 0.2
## Voitures : kg CO₂ par véhicule et par km (0 avant le moteur, électriques à la fin).
const VOITURE := [[1890, 0.0], [1900, 0.35], [1950, 0.28], [1980, 0.22], [2000, 0.19], [2020, 0.16], [2035, 0.09], [2050, 0.04]]
## Un poids lourd émet autant que…
const LOURD := 4.0
## Aéroports et ports (t CO₂ par jour), à partir de l'aviation.
const STATIONS := {"aeroport": 90.0, "aerodrome": 3.0, "heliport": 1.0, "port": 10.0}

## Industries : [mots du type, t CO₂ par emploi et par jour à plein régime].
const INDUSTRIES := [
	[["cimenterie"], 6.0], [["haut_fourneau", "acierie", "aluminerie"], 4.0], [["raffinerie"], 4.0],
	[["usine_chimique"], 2.0], [["verrerie", "briqueterie", "filature_briques"], 1.5], [["puits"], 1.0],
	[["fonderie", "papeterie", "incinerateur"], 1.0], [["sucrerie", "laiterie", "brasserie", "rizerie"], 0.4],
	[["usine_textile", "mine", "carriere", "sabliere", "argiliere"], 0.3], [["labo_pharma", "usine"], 0.15],
	[["scierie", "menuiserie", "atelier"], 0.05],
]
## Élevages (méthane) : t CO₂e par jour et par bâtiment.
const ELEVAGES := ["porcherie", "poulailler", "elevage", "etable", "bergerie", "ferme_laitiere", "haras", "alpage"]
const ELEVAGE_CO2 := 0.4
## Champs engraissés (protoxyde d'azote) : t CO₂e par hectare et par jour.
const CHAMP_CO2 := 0.004
## Décharges (méthane) : t CO₂e par jour.
const DECHARGE_CO2 := 1.5
## Forêts et parcs : t CO₂ absorbées par hectare et par an.
const FORET_T_HA := 6.0
const PARC_T_HA := 3.0

# --- Sols pollués --------------------------------------------------------------------------

## Cases des sols (m).
const SOL_CELL := 40.0
## Dépôt par jour d'une source forte (avant saturation).
const SOL_DEPOT := 0.004
## Ce que le sol perd tout seul chaque jour (≈ demi-vie de 5 ans).
const SOL_OUBLI := 0.0004
## Pesticides et engrais des champs (par jour), après 1945.
const SOL_CHAMPS := 0.0006
## Seuil à partir duquel un sol compte comme pollué.
const SOL_SEUIL := 0.15

# --- Mesures du plan climat ---------------------------------------------------------------

## id → {nom, annee, desc, cout: € par mois (fixe), par_site / par_foyer / par_hab / par_ha, effets}
const MESURES := {
	"filtres_usines": {"nom": "Électrofiltres sur les cheminées", "annee": 1910, "par_site": 1500.0,
		"desc": "Les usines filtrent leurs fumées : −45 % de pollution de l'air autour des industries."},
	"epuration_industrielle": {"nom": "Épuration des rejets industriels", "annee": 1960, "par_site": 2500.0,
		"desc": "Bassins et stations d'épuration dans les usines : −60 % de pollution de l'eau, et les sols se salissent deux fois moins."},
	"desulfuration": {"nom": "Désulfuration des fumées", "annee": 1975, "par_site": 4000.0,
		"desc": "Laveurs de fumées des centrales et des grosses usines : encore −40 % de pollution de l'air (pluies acides)."},
	"isolation": {"nom": "Isolation des logements", "annee": 1974, "par_foyer": 10.0,
		"desc": "Aides à l'isolation après le choc pétrolier : −25 % de chauffage."},
	"transports_doux": {"nom": "Vélo et transports en commun", "annee": 1975, "par_hab": 1.5,
		"desc": "Pistes cyclables, voies de bus, tarifs réduits : −15 % de trafic automobile."},
	"vegetaliser": {"nom": "Arbres et toits végétalisés", "annee": 1970, "par_hab": 0.8,
		"desc": "Plantations dans les rues et sur les toits : l'îlot de chaleur urbain est divisé par deux, et plus de CO₂ absorbé."},
	"depollution": {"nom": "Dépollution des sols", "annee": 1980, "par_ha": 3000.0,
		"desc": "Terres excavées, lavées ou plantées de végétaux dépolluants : les sols pollués guérissent dix fois plus vite."},
	"taxe_carbone": {"nom": "Taxe carbone", "annee": 1991, "recette_t": 45.0,
		"desc": "45 € par tonne de CO₂ des industries, versés à la ville ; elles émettent 15 % de moins. Les patrons grognent."},
	"normes_agricoles": {"nom": "Normes nitrates et pesticides", "annee": 1991,
		"desc": "Moins d'engrais et de pesticides : −50 % de pollution de l'eau autour des fermes, −60 % sur les sols, mais −5 % de récoltes."},
	"pot_catalytique": {"nom": "Pot catalytique obligatoire", "annee": 1993,
		"desc": "Toutes les voitures neuves filtrent leurs gaz : −40 % de pollution de l'air du trafic."},
	"toits_solaires": {"nom": "Panneaux solaires sur les toits", "annee": 2000, "par_foyer": 5.0,
		"desc": "Subvention des panneaux solaires : les maisons produisent une partie de leur courant (−15 % d'électricité achetée)."},
	"zfe": {"nom": "Zone à faibles émissions", "annee": 2015, "cout": 20000.0,
		"desc": "Les vieilles voitures n'entrent plus en ville : −30 % de pollution du trafic et −15 % de CO₂, mais les foyers modestes râlent."},
	"captage_co2": {"nom": "Captage du CO₂ des usines", "annee": 2030, "par_site": 8000.0,
		"desc": "Le CO₂ des cheminées est capté et stocké sous terre : −60 % d'émissions de l'industrie."},
}
const ORDRE_MESURES := ["filtres_usines", "epuration_industrielle", "vegetaliser", "isolation", "desulfuration", "transports_doux",
	"depollution", "taxe_carbone", "normes_agricoles", "pot_catalytique", "toits_solaires", "zfe", "captage_co2"]

## Grandes dates du climat, annoncées dans les nouvelles quand l'histoire y arrive.
const HISTOIRE_CLIMAT := [
	[1824, "Joseph Fourier décrit l'effet de serre : l'atmosphère garde la chaleur du Soleil comme une vitre."],
	[1856, "Eunice Foote montre que le gaz carbonique réchauffe l'air au soleil. Peu de monde l'écoute."],
	[1896, "Svante Arrhenius calcule que doubler le CO₂ réchaufferait la Terre de plusieurs degrés. Il trouve l'idée plutôt agréable."],
	[1938, "Guy Callendar relie la hausse des températures au charbon brûlé. Les météorologues haussent les épaules."],
	[1958, "Charles Keeling mesure le CO₂ au sommet du Mauna Loa : la courbe monte chaque année."],
	[1972, "Sommet de la Terre à Stockholm : l'environnement entre dans la politique."],
	[1979, "Rapport Charney : doubler le CO₂, c'est environ 3 °C de plus. Les chiffres tiendront."],
	[1988, "Création du GIEC, le groupe d'experts de l'ONU sur le climat."],
	[1992, "Sommet de Rio : les pays signent la convention sur le climat."],
	[1997, "Protocole de Kyoto : les pays riches promettent de réduire leurs émissions."],
	[2015, "Accord de Paris : rester bien en dessous de 2 °C, viser 1,5 °C."],
	[2050, "Année de la neutralité carbone promise par beaucoup de pays. Bilan dans le panneau Climat (F7)."],
]


# --- Fonctions ---------------------------------------------------------------------------

## Interpolation linéaire dans une table [[année, valeur], …] (bornée aux extrémités).
static func courbe(table: Array, x: float) -> float:
	if table.is_empty():
		return 0.0
	if x <= float(table[0][0]):
		return float(table[0][1])
	for i in range(1, table.size()):
		var b: Array = table[i]
		if x <= float(b[0]):
			var a: Array = table[i - 1]
			var t := (x - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.001)
			return lerpf(float(a[1]), float(b[1]), t)
	return float(table[table.size() - 1][1])


## Écart mondial de l'histoire réelle (°C) pour une année (avant 2026).
static func histoire(annee: float) -> float:
	return courbe(HISTOIRE, annee)


## Écart visé par un mélange de scénarios (s : 0 sobre, 1 médian, 2 fossile).
static func scenario(annee: float, s: float) -> float:
	s = clampf(s, 0.0, 2.0)
	var i := mini(floori(s), 1)
	return lerpf(courbe(SCENARIOS[i], annee), courbe(SCENARIOS[i + 1], annee), s - i)


## Scénario (0..2) qui correspond à des émissions par habitant (t/an).
static func scenario_de(intensite: float) -> float:
	var t: Array = INTENSITE_SCENARIOS
	if intensite <= float(t[0]):
		return 0.0
	if intensite <= float(t[1]):
		return (intensite - float(t[0])) / (float(t[1]) - float(t[0]))
	return clampf(1.0 + (intensite - float(t[1])) / (float(t[2]) - float(t[1])), 1.0, 2.0)


static func nom_scenario(s: float) -> String:
	if s < 0.5:
		return "sobre"
	if s < 1.5:
		return "médian"
	return "fossile"


## Hausse du niveau de la mer (cm par an) pour un écart de température.
static func montee_mer(ecart: float) -> float:
	return maxf(0.0, 0.1 + 0.28 * maxf(ecart, 0.0))


## Niveau de la mer de l'histoire réelle (cm au-dessus de celui de 1900).
static func mer_histoire(annee: float) -> float:
	var h := 0.0
	var y := 1900.0
	if annee >= 1900.0:
		while y < annee:
			var dy := minf(1.0, annee - y)
			h += montee_mer(histoire(y)) * dy
			y += dy
	else:
		while y > annee:
			var dy := minf(1.0, y - annee)
			h -= montee_mer(histoire(y)) * dy
			y -= dy
	return h


## Filière d'une centrale d'après son type.
static func filiere(type_id: String) -> String:
	var id := type_id.to_lower()
	if id.contains("batterie"):
		return ""
	for pair in [["charbon", "charbon"], ["gaz", "gaz"], ["biomasse", "biomasse"], ["nucleaire", "nucleaire"],
			["barrage", "hydro"], ["hydro", "hydro"], ["eolien", "eolien"], ["solaire", "solaire"],
			["poste_national", "national"], ["incinerateur", "dechets"]]:
		if id.contains(String(pair[0])):
			return String(pair[1])
	return "autre"


## Intensité du réseau national (t CO₂/MWh) une année donnée, dans un pays (code ISO).
static func intensite_nationale(annee: float, pays := "", s := 1.0) -> float:
	var v := courbe(NATIONAL, annee)
	if NATIONAL_PAYS.has(pays):
		# Le pays prend son propre chemin (nucléaire, barrages…) à partir des années 1970.
		var k := smoothstep(1970.0, 2000.0, annee)
		v = lerpf(v, float(NATIONAL_PAYS[pays]), k)
	if annee > ANNEE_PRESENT:
		var futur := lerpf(float(NATIONAL_2050[mini(floori(s), 1)]), float(NATIONAL_2050[mini(floori(s), 1) + 1]), clampf(s - mini(floori(s), 1), 0.0, 1.0))
		if NATIONAL_PAYS.has(pays):
			futur = minf(futur, float(NATIONAL_PAYS[pays]))
		v = lerpf(v, futur, clampf((annee - ANNEE_PRESENT) / (2050.0 - ANNEE_PRESENT), 0.0, 1.0))
	return v


## Intensité d'une filière (t CO₂/MWh).
static func intensite_filiere(f: String, annee: float, pays := "", s := 1.0) -> float:
	if f == "national":
		return intensite_nationale(annee, pays, s)
	return float(FILIERES.get(f, FILIERES.autre).co2)


## Industrie : t CO₂ par emploi et par jour (0 si ce n'est pas une industrie).
static func intensite_industrie(type_id: String) -> float:
	var id := type_id.to_lower()
	if filiere_centrale(id):
		return 0.0
	for row in INDUSTRIES:
		for kw in row[0]:
			if id.contains(String(kw)):
				return float(row[1])
	return 0.0


## Les centrales électriques sont comptées par le mix, pas par l'industrie.
static func filiere_centrale(id: String) -> bool:
	return id.begins_with("centrale") or id == "poste_national" or id.contains("barrage")


static func est_elevage(type_id: String) -> bool:
	var id := type_id.to_lower()
	for kw in ELEVAGES:
		if id.contains(kw):
			return true
	return false


## Famille d'un émetteur pour les mesures : "industrie", "ferme" ou "".
static func famille(type_id: String) -> String:
	var id := type_id.to_lower()
	if est_elevage(id):
		return "ferme"
	for kw in ["ferme", "cereales", "maraichere", "betteraves", "fibres", "serre", "cortijo", "hacienda", "grange", "silos", "hangar_agricole"]:
		if id.contains(kw):
			return "ferme"
	var e := Nuisances.emission_of(type_id)
	if not e.is_empty() and (float(e.air) >= 0.3 or float(e.eau) >= 0.3):
		return "industrie"
	return ""


## Une mesure peut-elle être adoptée cette année ?
static func mesure_disponible(id: String, annee: int) -> bool:
	if not MESURES.has(id):
		return false
	return annee >= int(MESURES[id].annee)
