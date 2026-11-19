class_name DevanturesTypes
extends RefCounted
## Ce que chaque bâtiment montre côté rue (voir Devantures) : genre de
## devanture, objets en vitrine, enseigne, store, terrasse, étal dehors.
##
## - Commerces : la vitrine montre ce qu'ils vendent (Ressources.COMMERCES),
##   en quantité réelle (stock du commerce dans Production).
## - Cafés et restaurants : salle, comptoir et terrasse.
## - Services, bureaux, hôtels, loisirs : hall d'accueil éclairé et enseigne.
## - Usines, ateliers, fermes : enseigne de l'entreprise et marchandise empilée
##   devant, selon le stock produit.
## - Logements : plaque au nom de la famille, jardinières, lampe d'entrée.
##
## Tout suit l'époque de la partie (Epoques.annee) : devanture en bois peint et
## lampe à pétrole en 1850, store rayé et lettres dorées en 1900, aluminium et
## néon en 1960, grands vitrages et LED aujourd'hui.

## Genres de devanture.
const BOUTIQUE := "boutique"     ## vitrine de marchandise
const SALLE := "salle"           ## café, restaurant : tables et terrasse
const HALL := "hall"             ## accueil : services, bureaux, hôtels, loisirs
const ENTREPRISE := "entreprise" ## usine, atelier, ferme : stock dehors
const LOGIS := "logis"           ## logement

## Profils par clé (type, base, archétype, rôle ou catégorie, voir Metiers.keys_of).
## objets : ce qui est exposé ; nom : début de l'enseigne ; dehors : étal sur le
## trottoir ; ardoise : phrases de l'ardoise ; store : couleur du store.
const PROFILS := {
	"boulangerie": {"genre": BOUTIQUE, "nom": "Boulangerie", "objets": ["baguette", "miche", "croissant", "gateau"],
		"ardoise": ["Pain chaud", "Croissants du jour", "Tarte maison"], "store": "c0392b", "fond": "f3e3c3"},
	"fournil": {"genre": BOUTIQUE, "nom": "Fournil", "objets": ["miche", "baguette"], "ardoise": ["Pain au levain"], "store": "8e5a2b", "fond": "f0dcb8"},
	"boucherie": {"genre": BOUTIQUE, "nom": "Boucherie", "objets": ["jambon", "viande", "saucisson"],
		"ardoise": ["Rôti du dimanche", "Terrine maison"], "store": "a93226", "fond": "f4f1ec"},
	"epicerie": {"genre": BOUTIQUE, "nom": "Épicerie", "objets": ["cagette", "bocaux", "bouteilles", "conserves"], "dehors": true,
		"ardoise": ["Primeurs", "Ouvert tard"], "store": "27ae60", "fond": "efe4cf"},
	"superette": {"genre": BOUTIQUE, "nom": "Supérette", "objets": ["cagette", "conserves", "bouteilles", "cartons"], "dehors": true,
		"store": "2e86c1", "fond": "eef1f2"},
	"supermarche": {"genre": BOUTIQUE, "nom": "Supermarché", "objets": ["cartons", "bouteilles", "cagette", "conserves"], "fond": "f2f4f4"},
	"marche": {"genre": BOUTIQUE, "nom": "Marché", "objets": ["cagette", "fromage", "poisson", "cagette"], "dehors": true, "store": "e67e22", "fond": "eadcc2"},
	"boutique": {"genre": BOUTIQUE, "nom": "Boutique", "objets": ["mannequin", "portant", "chaussures"], "store": "34495e", "fond": "f5eee6"},
	"boutique_mode": {"genre": BOUTIQUE, "nom": "Mode", "objets": ["mannequin", "portant", "chaussures"], "store": "6c3483", "fond": "f5eee6"},
	"boutiques": {"genre": BOUTIQUE, "nom": "Boutique", "objets": ["mannequin", "livres", "cartons"], "store": "34495e", "fond": "f5eee6"},
	"grand_magasin": {"genre": BOUTIQUE, "nom": "Grands Magasins", "objets": ["mannequin", "portant", "fauteuil", "ecran"], "fond": "f7f1e3"},
	"centre_commercial": {"genre": BOUTIQUE, "nom": "Galerie", "objets": ["mannequin", "ecran", "cartons"], "fond": "f2f2f2"},
	"fleuriste": {"genre": BOUTIQUE, "nom": "Fleurs", "objets": ["fleurs", "plantes"], "dehors": true, "ardoise": ["Bouquets du jour"],
		"store": "1e8449", "fond": "eef5e9"},
	"librairie": {"genre": BOUTIQUE, "nom": "Librairie", "objets": ["livres", "livres", "journaux"], "ardoise": ["Nouveautés"], "store": "1f618d", "fond": "efe6d6"},
	"kiosque": {"genre": BOUTIQUE, "nom": "Presse", "objets": ["journaux", "livres"], "fond": "f5f0e1"},
	"pharmacie": {"genre": BOUTIQUE, "nom": "Pharmacie", "objets": ["boites", "flacons"], "croix": true, "fond": "f4f8f6"},
	"magasin_multimedia": {"genre": BOUTIQUE, "nom": "Électroménager", "objets": ["ecran", "cartons", "ecran"], "fond": "eef0f3"},
	"magasin_meubles": {"genre": BOUTIQUE, "nom": "Meubles", "objets": ["fauteuil", "lampe", "fauteuil"], "fond": "f1e9dd"},
	"bricolage": {"genre": BOUTIQUE, "nom": "Quincaillerie", "objets": ["outils", "pots", "cartons"], "dehors": true, "store": "d35400", "fond": "ece6dc"},
	"concession": {"genre": BOUTIQUE, "nom": "Garage", "objets": ["voiture"], "fond": "eceff1"},
	"concession_auto": {"genre": BOUTIQUE, "nom": "Garage", "objets": ["voiture"], "fond": "eceff1"},
	"station_service": {"genre": BOUTIQUE, "nom": "Station", "objets": ["bouteilles", "bidons"], "fond": "f4f4f4"},
	"cafe": {"genre": SALLE, "nom": "Café", "ardoise": ["Café 2 €", "Formule midi"], "store": "7b241c", "fond": "e9d8bd", "terrasse": true},
	"restaurant": {"genre": SALLE, "nom": "Restaurant", "ardoise": ["Plat du jour", "Menu du marché"], "store": "1b4f72", "fond": "efe0c8", "terrasse": true},
	"banque": {"genre": HALL, "nom": "Banque", "fond": "eceae4", "accueil": "guichet"},
	"hotel": {"genre": HALL, "nom": "Hôtel", "fond": "f1e4cc", "accueil": "reception", "store": "784212"},
	"bureaux": {"genre": HALL, "nom": "", "fond": "eef0f2", "accueil": "accueil"},
	"gratte_ciel": {"genre": HALL, "nom": "", "fond": "edf1f4", "accueil": "accueil"},
	"mairie": {"genre": HALL, "nom": "Mairie", "fond": "f0ebe1", "accueil": "guichet", "drapeau": true},
	"palais": {"genre": HALL, "nom": "Palais", "fond": "f0ebe1", "accueil": "guichet", "drapeau": true},
	"poste": {"genre": HALL, "nom": "La Poste", "fond": "f6f0d8", "accueil": "guichet"},
	"ecole": {"genre": HALL, "nom": "École", "fond": "f3eddc", "accueil": "affiches", "drapeau": true},
	"police": {"genre": HALL, "nom": "Police", "fond": "e8edf3", "accueil": "guichet"},
	"pompiers": {"genre": HALL, "nom": "Pompiers", "fond": "f3e2df", "accueil": "accueil"},
	"hopital": {"genre": HALL, "nom": "Hôpital", "fond": "eef5f3", "accueil": "accueil", "croix": true},
	"cinema": {"genre": HALL, "nom": "Cinéma", "fond": "3b2a3f", "accueil": "affiches"},
	"theatre": {"genre": HALL, "nom": "Théâtre", "fond": "5a2330", "accueil": "affiches"},
	"musee": {"genre": HALL, "nom": "Musée", "fond": "f1ede6", "accueil": "affiches"},
	"gare": {"genre": HALL, "nom": "Gare", "fond": "ece6d8", "accueil": "guichet"},
	"gymnase": {"genre": HALL, "nom": "Gymnase", "fond": "e6eef0", "accueil": "accueil"},
	"piscine": {"genre": HALL, "nom": "Piscine", "fond": "e3f0f5", "accueil": "accueil"},
	"atelier": {"genre": ENTREPRISE, "nom": "Ateliers", "objets": ["caisses", "palette"]},
	"usine": {"genre": ENTREPRISE, "nom": "Usine", "objets": ["palette", "fut", "caisses"]},
	"scierie": {"genre": ENTREPRISE, "nom": "Scierie", "objets": ["planches", "planches"]},
	"entrepot": {"genre": ENTREPRISE, "nom": "Entrepôts", "objets": ["palette", "caisses"]},
	"entreprise_btp": {"genre": ENTREPRISE, "nom": "Bâtiment", "objets": ["planches", "palette"]},
	"huilerie": {"genre": ENTREPRISE, "nom": "Huilerie", "objets": ["fut", "caisses"]},
	"filature": {"genre": ENTREPRISE, "nom": "Filature", "objets": ["balles", "caisses"]},
	"silo_cooperative": {"genre": ENTREPRISE, "nom": "Coopérative", "objets": ["sacs", "palette"]},
	"ferme": {"genre": ENTREPRISE, "nom": "Ferme", "objets": ["sacs", "cagette"]},
}

## Repli par catégorie quand aucune clé plus précise n'est connue.
const PAR_CATEGORIE := {
	"commerce": {"genre": BOUTIQUE, "nom": "Boutique", "objets": ["cartons", "bouteilles"], "store": "5d6d7e", "fond": "f1ece3"},
	"services": {"genre": HALL, "nom": "", "fond": "eeeae2", "accueil": "guichet"},
	"loisirs": {"genre": HALL, "nom": "", "fond": "efe6dc", "accueil": "affiches"},
	"sport": {"genre": HALL, "nom": "", "fond": "e6eef0", "accueil": "accueil"},
	"tourisme": {"genre": HALL, "nom": "", "fond": "f1e4cc", "accueil": "reception"},
	"spectacles": {"genre": HALL, "nom": "", "fond": "4a2a38", "accueil": "affiches"},
	"patrimoine": {"genre": HALL, "nom": "", "fond": "efe8dc", "accueil": "affiches"},
	"funeraire": {"genre": HALL, "nom": "", "fond": "e8e4dc", "accueil": "accueil"},
	"industrie": {"genre": ENTREPRISE, "nom": "Ets", "objets": ["caisses", "palette"]},
	"production": {"genre": ENTREPRISE, "nom": "Ets", "objets": ["caisses", "sacs"]},
	"logement": {"genre": LOGIS},
}

## Objets exposés pour une marchandise (Ressources) : sert aux commerces dont
## le profil ne dit rien, et à relier chaque objet au stock de sa marchandise.
const OBJETS_DE_BIEN := {
	"pain": "baguette", "viande": "jambon", "poisson": "poisson", "laitages": "fromage", "fruits_legumes": "cagette",
	"epicerie": "conserves", "boissons": "bouteilles", "hygiene": "flacons", "oeufs": "oeufs", "huile": "bouteilles",
	"miel": "bocaux", "chocolat": "boites", "vetements": "mannequin", "electronique": "ecran", "biens": "cartons",
	"meubles": "fauteuil", "carburant": "bidons", "medicaments": "boites", "voitures": "voiture",
	"farine": "sacs", "bois": "planches", "planches": "planches", "cereales": "sacs", "ble": "sacs",
}

## Marchandise que représente un objet (pour lire le stock).
const BIEN_D_OBJET := {
	"baguette": "pain", "miche": "pain", "croissant": "pain", "gateau": "pain",
	"jambon": "viande", "viande": "viande", "saucisson": "viande", "poisson": "poisson", "fromage": "laitages",
	"cagette": "fruits_legumes", "conserves": "epicerie", "bocaux": "epicerie", "bouteilles": "boissons",
	"flacons": "hygiene", "boites": "medicaments", "oeufs": "oeufs", "mannequin": "vetements", "portant": "vetements",
	"chaussures": "vetements", "ecran": "electronique", "cartons": "biens", "fauteuil": "meubles", "lampe": "meubles",
	"bidons": "carburant", "voiture": "voitures",
}

## Objets d'époque : ce qui n'existe pas encore ne s'expose pas (remplacé).
const ANNEE_OBJET := {"ecran": 1950, "voiture": 1900, "bidons": 1905, "conserves": 1830, "cartons": 1880, "palette": 1930}
const REMPLACE_OBJET := {"ecran": "lampe", "voiture": "outils", "bidons": "fut", "conserves": "bocaux", "cartons": "caisses", "palette": "caisses"}

## Noms d'entreprises de bureaux, d'hôtels et de lieux, quand le type n'en donne pas.
const NOMS_BUREAUX := ["Assurances", "Conseil", "Études", "Groupe", "Holding", "Société", "Cabinet", "Agence"]
const NOMS_HOTEL := ["du Commerce", "de la Gare", "des Voyageurs", "du Lac", "de la Poste", "Bellevue", "des Alpes", "Central"]
const NOMS_CAFE := ["du Centre", "de la Place", "des Sports", "du Marché", "de la Mairie", "du Port", "des Amis", "de la Gare"]
const NOMS_RESIDENCE := ["Les Tilleuls", "Les Érables", "Le Belvédère", "Les Glycines", "Beau-Site", "Les Cèdres", "Le Parc", "Les Peupliers"]

static var _cache := {}


## Profil de devanture d'un type de bâtiment ({} : rien côté rue).
static func profil(type_id: String) -> Dictionary:
	if _cache.has(type_id):
		return _cache[type_id]
	var t := BuildingCatalog.get_type(type_id)
	var out := {}
	if t.is_empty():
		_cache[type_id] = out
		return out
	var cle := ""
	for k in Metiers.keys_of(type_id):
		if PROFILS.has(k):
			out = (PROFILS[k] as Dictionary).duplicate(true)
			cle = String(k)
			break
	var cat := String(t.get("cat", ""))
	if out.is_empty() and PAR_CATEGORIE.has(cat):
		out = (PAR_CATEGORIE[cat] as Dictionary).duplicate(true)
		cle = cat
	if out.is_empty():
		_cache[type_id] = out
		return out
	out["cle"] = cle
	out["type"] = type_id
	out["cat"] = cat
	# Un commerce de détail connu de l'économie : ce qu'il vend vraiment.
	var shop := Ressources.commerce_of(type_id)
	out["vend"] = (shop.get("vend", []) as Array).duplicate()
	if shop.has("consomme"):
		out["genre"] = SALLE
		out["terrasse"] = true
	if String(out.genre) == BOUTIQUE and not out.has("objets"):
		var objs := []
		for g in out.vend:
			var o := String(OBJETS_DE_BIEN.get(g, ""))
			if o != "" and not objs.has(o):
				objs.append(o)
		out["objets"] = objs if not objs.is_empty() else ["cartons"]
	if String(out.genre) == BOUTIQUE and (out.objets as Array).is_empty():
		out["objets"] = ["cartons"]
	if not out.has("fond"):
		out["fond"] = "efe7da"
	_cache[type_id] = out
	return out


## Objets d'un profil adaptés à l'année (un écran avant 1950 devient une lampe).
static func objets_a(p: Dictionary, annee: int) -> Array:
	var out := []
	for o in p.get("objets", []):
		var s := String(o)
		while ANNEE_OBJET.has(s) and annee < int(ANNEE_OBJET[s]):
			s = String(REMPLACE_OBJET[s])
		out.append(s)
	return out


## Style d'époque de la devanture : cadre, enseigne, lumière, store.
static func style(annee: int) -> Dictionary:
	if annee < 1880:
		return {"id": "ancien", "cadre": Color("4a3326"), "bandeau": Color("2f3d2e"), "lettres": Color("e8d9a8"),
			"lumiere": Color(1.0, 0.72, 0.4), "carreaux": true, "store": annee >= 1840, "neon": false, "enseigne_potence": true}
	if annee < 1940:
		return {"id": "belle_epoque", "cadre": Color("1f3a2e"), "bandeau": Color("1b2a38"), "lettres": Color("e6c35c"),
			"lumiere": Color(1.0, 0.78, 0.5), "carreaux": false, "store": true, "neon": annee >= 1925, "enseigne_potence": true}
	if annee < 1980:
		return {"id": "trente_glorieuses", "cadre": Color("b9bec4"), "bandeau": Color("f2f2ee"), "lettres": Color("c0392b"),
			"lumiere": Color(0.95, 0.95, 1.0), "carreaux": false, "store": true, "neon": true, "enseigne_potence": false}
	return {"id": "moderne", "cadre": Color("3d4247"), "bandeau": Color("2b2f33"), "lettres": Color("f5f5f5"),
		"lumiere": Color(1.0, 0.92, 0.82), "carreaux": false, "store": true, "neon": false, "enseigne_potence": false}


## Remplissage d'une vitrine en paliers (0, 1/4… 1) : un maillage par palier.
static func palier(fill: float) -> int:
	if fill <= 0.02:
		return 0
	return clampi(ceili(fill * 4.0 - 0.01), 1, 4)


## Nom affiché sur l'enseigne. `famille` : nom du patron ou d'une famille
## (Population), "" pour en tirer un au hasard, stable pour ce bâtiment.
static func enseigne(p: Dictionary, type_id: String, bid: int, famille: String) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("enseigne%d" % bid)
	var t := BuildingCatalog.get_type(type_id)
	var genre := String(p.get("genre", ""))
	var base := String(p.get("nom", ""))
	match genre:
		LOGIS:
			if int(t.get("logements", 1)) > 3:
				return "Résidence " + NOMS_RESIDENCE[rng.randi() % NOMS_RESIDENCE.size()]
			return famille
		SALLE:
			if famille != "" and rng.randf() < 0.4:
				return "%s %s" % [base, famille]
			return "%s %s" % [base, NOMS_CAFE[rng.randi() % NOMS_CAFE.size()]]
		HALL:
			if String(p.cle) == "hotel":
				return "Hôtel " + NOMS_HOTEL[rng.randi() % NOMS_HOTEL.size()]
			if base == "":
				if String(p.cle) in ["bureaux", "gratte_ciel"]:
					var who := famille if famille != "" else "Martin"
					return "%s %s" % [NOMS_BUREAUX[rng.randi() % NOMS_BUREAUX.size()], who]
				return String(t.get("name", ""))
			return base
		ENTREPRISE:
			return "%s %s" % [base, famille] if famille != "" else String(t.get("name", base))
	if famille == "":
		return base
	if base in ["Supermarché", "Grands Magasins", "Galerie", "Station", "Marché"]:
		return base
	return "%s %s" % [base, famille]


## Phrase de l'ardoise du jour ("" : pas d'ardoise).
static func ardoise(p: Dictionary, jour: int, bid: int) -> String:
	var l: Array = p.get("ardoise", [])
	if l.is_empty():
		return ""
	return String(l[(jour + bid) % l.size()])
