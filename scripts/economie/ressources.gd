class_name Ressources
extends RefCounted
## Ressources naturelles et marchandises de MiniBlocs.
##
## Une ressource NATURELLE est une richesse du sol ou de l'eau, de 0 à 1 sur
## chaque case (voir CarteRessources) : forêt, pierre, gisement de fer… Un
## bâtiment d'extraction posé dessus en tire une MARCHANDISE (en tonnes), que
## d'autres bâtiments transforment (voir Production). Les prix sont des ordres
## de grandeur réels, en euros par tonne.

## Ressources naturelles. renouvelable : la ressource repousse (bois, poisson,
## sols) ; sinon le gisement s'épuise. good : marchandise extraite.
const NATURELLES := {
	"bois": {"name": "Forêt (bois)", "color": Color("2d6a4f"), "good": "bois", "renouvelable": true, "repousse": true,
		"desc": "Forêts réelles (ESA WorldCover)."},
	"fertilite": {"name": "Terres cultivables", "color": Color("e9c46a"), "good": "cereales", "renouvelable": true,
		"desc": "Champs et prairies réels, pente, altitude et climat (latitude)."},
	"paturage": {"name": "Pâturages", "color": Color("95d5b2"), "good": "betail", "renouvelable": true,
		"desc": "Prairies, alpages et landes."},
	"poisson": {"name": "Poisson", "color": Color("48cae4"), "good": "poisson", "renouvelable": true, "repousse": true,
		"desc": "Mer (plateau continental plus riche), lacs et rivières."},
	"pierre": {"name": "Pierre et calcaire", "color": Color("adb5bd"), "good": "pierre", "renouvelable": false, "infini": true,
		"desc": "Roche nue, versants pentus et montagne."},
	"sable": {"name": "Sable et graviers", "color": Color("f4d58d"), "good": "sable", "renouvelable": false, "infini": true,
		"desc": "Bords de rivière, plages et déserts."},
	"argile": {"name": "Argile", "color": Color("bc6c25"), "good": "argile", "renouvelable": false, "infini": true,
		"desc": "Plaines basses et zones humides."},
	"fer": {"name": "Minerai de fer", "color": Color("9d0208"), "good": "minerai_fer", "renouvelable": false,
		"desc": "Bassins ferrifères réels (Lorraine, Pilbara, Kiruna…)."},
	"charbon": {"name": "Charbon", "color": Color("343a40"), "good": "charbon", "renouvelable": false,
		"desc": "Bassins houillers réels (Ruhr, Nord-Pas-de-Calais, Kouzbass…)."},
	"cuivre": {"name": "Cuivre", "color": Color("e76f51"), "good": "minerai_cuivre", "renouvelable": false,
		"desc": "Ceintures cuprifères réelles (Atacama, Copperbelt…)."},
	"or": {"name": "Or", "color": Color("ffd60a"), "good": "minerai_or", "renouvelable": false,
		"desc": "Districts aurifères réels (Witwatersrand, Kalgoorlie, Guyane…)."},
	"bauxite": {"name": "Bauxite", "color": Color("d62828"), "good": "bauxite", "renouvelable": false,
		"desc": "Bauxite tropicale (Guinée, Australie, Jamaïque, Provence…)."},
	"petrole": {"name": "Pétrole", "color": Color("6a4c93"), "good": "petrole", "renouvelable": false,
		"desc": "Bassins pétroliers réels (golfe Persique, mer du Nord, Aquitaine…)."},
	"gaz": {"name": "Gaz naturel", "color": Color("4895ef"), "good": "gaz", "renouvelable": false,
		"desc": "Champs gaziers réels (Lacq, Groningue, Ourengoï…)."},
}
## Ordre d'affichage.
const ORDRE := ["bois", "fertilite", "paturage", "poisson", "pierre", "sable", "argile",
	"fer", "charbon", "cuivre", "or", "bauxite", "petrole", "gaz"]
## Ressources du sous-sol (gisements placés d'après les vraies régions minières).
const SOUS_SOL := ["fer", "charbon", "cuivre", "or", "bauxite", "petrole", "gaz"]
## Ce que peut extraire une mine, un puits.
const MINERAIS := ["fer", "charbon", "cuivre", "or", "bauxite"]
const HYDROCARBURES := ["petrole", "gaz"]

## Marchandises : prix de gros (€/t). conso : vendue aux habitants dans les
## commerces (prix de détail = prix × DETAIL).
const MARCHANDISES := {
	"bois": {"name": "Bois", "prix": 60.0},
	"pierre": {"name": "Pierre", "prix": 15.0},
	"sable": {"name": "Sable", "prix": 12.0},
	"argile": {"name": "Argile", "prix": 10.0},
	"minerai_fer": {"name": "Minerai de fer", "prix": 100.0},
	"charbon": {"name": "Charbon", "prix": 120.0},
	"minerai_cuivre": {"name": "Minerai de cuivre", "prix": 90.0},
	"minerai_or": {"name": "Minerai d'or", "prix": 150.0},
	"bauxite": {"name": "Bauxite", "prix": 45.0},
	"petrole": {"name": "Pétrole brut", "prix": 550.0},
	"gaz": {"name": "Gaz naturel", "prix": 300.0},
	"cereales": {"name": "Céréales", "prix": 220.0},
	"betail": {"name": "Bétail", "prix": 2500.0},
	"poisson": {"name": "Poisson", "prix": 3000.0, "conso": true},
	"planches": {"name": "Planches", "prix": 300.0},
	"farine": {"name": "Farine", "prix": 450.0},
	"pain": {"name": "Pain", "prix": 2500.0, "conso": true},
	"viande": {"name": "Viande", "prix": 7000.0, "conso": true},
	"acier": {"name": "Acier", "prix": 700.0},
	"carburant": {"name": "Carburant", "prix": 900.0, "conso": true},
	"briques": {"name": "Briques", "prix": 200.0},
	"ciment": {"name": "Ciment", "prix": 120.0},
	"cuivre": {"name": "Cuivre", "prix": 8500.0},
	"meubles": {"name": "Meubles", "prix": 3000.0, "conso": true},
	"biens": {"name": "Biens manufacturés", "prix": 4000.0, "conso": true},
}
## Prix de détail (vente aux habitants) par rapport au prix de gros.
const DETAIL := 1.4
## Prix à l'export par rapport au prix de gros (transport, intermédiaires).
const EXPORT := 0.8

## Consommation par habitant et par jour (tonnes) ; carburant : par voiture.
const CONSO_HABITANT := {"pain": 0.00025, "viande": 0.00016, "poisson": 0.00005, "meubles": 0.00002, "biens": 0.0001}
const CONSO_VOITURE := {"carburant": 0.003}


static func naturelle(id: String) -> Dictionary:
	return NATURELLES.get(id, {})


static func good_name(id: String) -> String:
	return String(MARCHANDISES.get(id, {}).get("name", id))


static func price(id: String) -> float:
	return float(MARCHANDISES.get(id, {}).get("prix", 0.0))


## Ressource naturelle d'où vient une marchandise ("" si fabriquée).
static func source_of(good: String) -> String:
	for id in NATURELLES:
		if String(NATURELLES[id].good) == good:
			return id
	return ""


## « 12,5 t », « 850 kg », « 3 g ».
static func format_t(t: float) -> String:
	var a := absf(t)
	if a >= 1000.0:
		return "%s t" % _thousands(roundi(t))
	if a >= 10.0:
		return "%d t" % roundi(t)
	if a >= 1.0:
		return ("%.1f t" % t).replace(".", ",")
	if a >= 0.001:
		return "%d kg" % roundi(t * 1000.0)
	if a > 0.0:
		return "%d g" % maxi(roundi(t * 1_000_000.0), 1)
	return "0 t"


static func _thousands(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = " " + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if v < 0 else "") + s + out
