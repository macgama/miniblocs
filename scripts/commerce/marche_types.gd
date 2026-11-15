class_name MarcheTypes
extends RefCounted
## Données du commerce mondial : familles de marchandises (elles montent et
## descendent ensemble), crises économiques, durées des accords.
## Voir CommerceMondial et docs/commerce.md.

## Familles : nom, volatilité par jour (écart type du cours) et marchandises.
const FAMILLES := {
	"energie": {"nom": "Énergie", "vol": 0.030, "biens": ["petrole", "gaz", "charbon", "carburant"]},
	"metaux": {"nom": "Métaux et minerais", "vol": 0.022, "biens": ["minerai_fer", "minerai_cuivre", "minerai_or", "bauxite", "acier", "aluminium", "cuivre"]},
	"agricole": {"nom": "Produits agricoles", "vol": 0.018, "biens": ["cereales", "betteraves", "fibres", "betail", "lait", "oleagineux", "foin", "paille", "fumier", "laine", "farine", "sucre", "huile", "oeufs", "fruits_legumes"]},
	"alimentaire": {"nom": "Alimentation", "vol": 0.008, "biens": ["pain", "viande", "poisson", "laitages", "epicerie", "boissons"]},
	"construction": {"nom": "Matériaux de construction", "vol": 0.012, "biens": ["bois", "planches", "pierre", "calcaire", "granite", "sable", "argile", "briques", "ciment", "verre", "sel"]},
	"chimie": {"nom": "Chimie et papier", "vol": 0.012, "biens": ["chimie", "plastique", "papier", "hygiene", "medicaments", "balles_tri"]},
	"manufacture": {"nom": "Produits manufacturés", "vol": 0.010, "biens": ["vetements", "electronique", "meubles", "biens", "voitures"]},
}
## Bornes du cours par rapport au prix de référence.
const COURS_MIN := 0.35
const COURS_MAX := 3.5
## Rappel vers le prix de référence chaque jour (0 : aucun, 1 : immédiat).
const RAPPEL_FAMILLE := 0.03
const RAPPEL_BIEN := 0.05
## Jours de cours gardés pour les courbes.
const HISTORIQUE := 120

## Crises : texte d'annonce (avec une touche d'humour), texte de fin, durée
## (jours), effets au plus fort : familles {famille: ×}, biens {bien: ×},
## "tous" (×, toutes les marchandises), export (× du prix payé à l'export),
## import (× du prix des importations), capacite (× de ce qui passe aux
## frontières), conseil pour le joueur.
const CRISES := {
	"choc_petrolier": {"nom": "Choc pétrolier", "icone": "feu", "duree": [45, 100],
		"texte": "Choc pétrolier : les pays producteurs ferment les vannes et le baril s'envole. Les automobilistes redécouvrent leur vélo.",
		"fin": "Le pétrole redescend : fin du choc pétrolier. Les vélos retournent au garage.",
		"biens": {"petrole": 2.2, "gaz": 1.7, "carburant": 1.8, "plastique": 1.3, "chimie": 1.25},
		"conseil": "Tu produis du pétrole, du gaz ou du carburant : exporte tant que ça dure. Sinon, un accord d'achat à prix fixe protège tes entreprises et tes stations-service."},
	"krach": {"nom": "Krach boursier", "icone": "courbe", "duree": [60, 150],
		"texte": "Krach boursier : les marchés plongent. Les traders vendent leur montre et retournent vivre chez leurs parents.",
		"fin": "Les marchés reprennent des couleurs : le krach est oublié (jusqu'au prochain).",
		"familles": {"manufacture": 0.7, "metaux": 0.75, "construction": 0.8}, "export": 0.85, "capacite": 0.7,
		"conseil": "Les acheteurs étrangers se font rares : les accords d'exportation signés avant la crise gardent leur prix. Vends en ville plutôt qu'à l'export."},
	"secheresse": {"nom": "Sécheresse mondiale", "icone": "soleil", "duree": [40, 90],
		"texte": "Sécheresse mondiale : les récoltes grillent sur trois continents. Le prix de la baguette fait la une des journaux.",
		"fin": "La pluie est revenue : les prix agricoles se calment.",
		"familles": {"agricole": 1.6, "alimentaire": 1.25},
		"conseil": "Tes fermes valent de l'or : exporte céréales et oléagineux. Tes boulangeries et supermarchés paieront plus cher s'ils importent."},
	"penurie_puces": {"nom": "Pénurie de puces", "icone": "reseaux", "duree": [60, 120],
		"texte": "Pénurie de puces électroniques : même les grille-pain connectés doivent faire la queue.",
		"fin": "Les usines de puces tournent de nouveau : fin de la pénurie.",
		"biens": {"electronique": 1.9, "voitures": 1.45, "biens": 1.2},
		"conseil": "Électronique et voitures neuves coûtent beaucoup plus cher à l'import. Une usine d'électronique en ville rapporte gros pendant la crise."},
	"boom_construction": {"nom": "Boom de la construction", "icone": "construire", "duree": [50, 110],
		"texte": "Boom mondial de la construction : des grues partout, plus un sac de ciment en vue. Les architectes ne dorment plus.",
		"fin": "Le boom de la construction retombe : les grues rentrent au dépôt.",
		"familles": {"construction": 1.5, "metaux": 1.25},
		"conseil": "Carrières, scieries, cimenteries et briqueteries : c'est leur heure. Exporte tes matériaux."},
	"inflation": {"nom": "Inflation galopante", "icone": "billet", "duree": [90, 180],
		"texte": "Inflation galopante : tout augmente, sauf les salaires (c'est toujours comme ça).",
		"fin": "L'inflation est maîtrisée : les prix arrêtent de grimper.",
		"tous": 1.25,
		"conseil": "Tout coûte plus cher, à l'import comme à l'export. Les accords à prix fixe signés avant la crise sont une bonne affaire pour celui qui achète."},
	"guerre_commerciale": {"nom": "Guerre commerciale", "icone": "bouclier", "duree": [60, 120],
		"texte": "Guerre commerciale : les grandes puissances se disputent à coups de taxes. Les douaniers font des heures supplémentaires.",
		"fin": "Paix commerciale signée : les taxes tombent, les douaniers rentrent chez eux.",
		"import": 1.3, "export": 0.9, "capacite": 0.75,
		"conseil": "Importer coûte 30 % de plus et moins de camions passent la frontière. Produis sur place ce que tu peux, et commerce entre tes villes."},
	"recolte_record": {"nom": "Récolte record", "icone": "agriculture", "duree": [40, 80],
		"texte": "Récolte record : les greniers débordent partout dans le monde. Le blé ne vaut plus rien, les vaches sont ravies.",
		"fin": "Les greniers se vident : les prix agricoles remontent.",
		"familles": {"agricole": 0.65},
		"conseil": "Les céréales et le lait se vendent mal : garde-les pour tes usines et tes commerces, et achète à l'étranger ce qui est bradé."},
	"ruee_metaux": {"nom": "Ruée vers les métaux", "icone": "industrie", "duree": [50, 100],
		"texte": "Ruée vers les métaux : les batteries électriques font flamber le cuivre. On fouille même les vieux greniers à la recherche de casseroles.",
		"fin": "La ruée vers les métaux se termine : les cours du cuivre redescendent.",
		"biens": {"minerai_cuivre": 1.8, "cuivre": 1.7, "aluminium": 1.5, "bauxite": 1.5, "minerai_or": 1.6},
		"conseil": "Une mine de cuivre ou de bauxite rapporte deux fois plus : ouvre une carrière (P → Mines) si ta région en a."},
}
## Jours sans crise après la fin d'une crise, et chance par jour d'en déclencher une ensuite.
const REPIT := 60
const CHANCE_JOUR := 1.0 / 150.0
## Part de la durée où la crise monte, et part où elle redescend.
const MONTEE := 0.15
const DESCENTE := 0.2

## Accords : durées proposées (jours) et pénalités.
const DUREES := [30, 60, 90, 180]
## Pénalité par tonne promise et pas livrée (part du prix de l'accord).
const PENALITE_MANQUE := 0.10
## Rupture d'un accord avant la fin : part de ce qui restait à échanger.
const PENALITE_RUPTURE := 0.10
## Jours de grâce au début d'un accord (les premiers camions sont en route).
const GRACE := 2
## Une offre reste valable tant de jours.
const VALIDITE_OFFRE := 10
## Mission commerciale : coût (× coût des constructions), gain de relation, attente.
const MISSION_COUT := 25_000
const MISSION_RELATION := 8.0
const MISSION_ATTENTE := 7
## Nombre de villes partenaires (vraies villes voisines).
const PARTENAIRES := 6


## Famille d'une marchandise ("" si aucune).
static func famille_de(g: String) -> String:
	for f in FAMILLES:
		if g in (FAMILLES[f].biens as Array):
			return f
	return ""


## Toutes les marchandises échangées sur le marché mondial, famille par famille.
static func biens() -> Array:
	var out: Array = []
	for f in FAMILLES:
		for g in FAMILLES[f].biens:
			if Ressources.MARCHANDISES.has(g):
				out.append(g)
	return out


## Effet d'une crise sur une marchandise au plus fort (× du cours).
static func effet_crise(id: String, g: String) -> float:
	var c: Dictionary = CRISES.get(id, {})
	if c.is_empty():
		return 1.0
	var f := float(c.get("tous", 1.0))
	var fam := famille_de(g)
	f *= float((c.get("familles", {}) as Dictionary).get(fam, 1.0))
	f *= float((c.get("biens", {}) as Dictionary).get(g, 1.0))
	return f


## Intensité d'une crise (0 à 1) au jour j de ses n jours.
static func intensite(j: int, n: int) -> float:
	if n <= 0 or j < 0 or j >= n:
		return 0.0
	var x := float(j) / float(n)
	if x < MONTEE:
		return x / MONTEE
	if x > 1.0 - DESCENTE:
		return (1.0 - x) / DESCENTE
	return 1.0
