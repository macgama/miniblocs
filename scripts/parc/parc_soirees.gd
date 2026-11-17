class_name ParcSoirees
extends RefCounted
## Soirées du parc de loisirs : feux d'artifice et spectacles du soir
## (onglet Soirées du panneau Maj+G).
##
## - Programme d'un parc : un spectacle, sa taille (petit, moyen, grand) et
##   quand le donner (jamais, les samedis, les jours de fête, chaque soir d'été,
##   chaque soir), plus « ce soir » à la main.
## - Un soir de spectacle, le parc ferme après le spectacle (le début dépend du
##   mois : 22 h 30 en juin-juillet, 19 h l'hiver). Plus de visiteurs ce jour-là,
##   surtout en fin d'après-midi, et ceux qui sont là restent jusqu'au bout.
##   Ceux qui le voient repartent de bien meilleure humeur.
## - Coût payé au début du spectacle (caisse de la ville du parc). Sous la pluie,
##   le spectacle est annulé (on ne paie que 20 % : les artificiers sont venus).
## - Feux d'artifice et lasers font du bruit (pollution sonore pendant le spectacle).
## - Époques : feux d'artifice de tout temps (dorés avant 1830, en couleurs
##   ensuite avec la recherche), parade lumineuse (1900, éclairage féerique),
##   lasers et jets d'eau (1980), feux pyromélodiques (1990), drones (2016).

const TYPES := {
	"feu_artifice": {"nom": "Feu d'artifice", "annee": 1800, "prix": [5_000.0, 15_000.0, 40_000.0], "duree": [8.0, 12.0, 20.0],
		"bonus": [0.10, 0.25, 0.50], "humeur": [8.0, 12.0, 18.0], "bruit": 0.7, "pluie": true,
		"desc": "Fusées, bombes et bouquet final. Les chiens de la ville n'ont pas été consultés."},
	"pyromelodique": {"nom": "Feu pyromélodique", "annee": 1990, "recherche": "pyromelodie", "prix": [7_000.0, 21_000.0, 56_000.0],
		"duree": [10.0, 15.0, 22.0], "bonus": [0.15, 0.38, 0.75], "humeur": [12.0, 17.0, 24.0], "bruit": 0.7, "pluie": true,
		"desc": "Les fusées partent en rythme avec la musique. On en parle encore à la boulangerie trois jours après."},
	"parade_lumineuse": {"nom": "Parade lumineuse", "annee": 1900, "recherche": "eclairage_feerique", "prix": [4_000.0, 9_000.0, 20_000.0],
		"duree": [20.0, 30.0, 40.0], "bonus": [0.08, 0.18, 0.30], "humeur": [7.0, 10.0, 14.0], "bruit": 0.2, "pluie": true, "familles": true,
		"desc": "Chars illuminés, musique et mascottes dans les allées. Les familles adorent."},
	"laser": {"nom": "Lasers et jets d'eau", "annee": 1980, "recherche": "spectacle_laser", "prix": [6_000.0, 14_000.0, 30_000.0],
		"duree": [15.0, 20.0, 25.0], "bonus": [0.08, 0.20, 0.35], "humeur": [8.0, 12.0, 16.0], "bruit": 0.4, "pluie": false,
		"desc": "Rayons verts dans la brume et écran d'eau. Marche même sous la pluie (c'est déjà mouillé)."},
	"drones": {"nom": "Spectacle de drones", "annee": 2016, "recherche": "drones_lumineux", "prix": [15_000.0, 35_000.0, 80_000.0],
		"duree": [12.0, 15.0, 20.0], "bonus": [0.15, 0.35, 0.60], "humeur": [12.0, 16.0, 22.0], "bruit": 0.0, "pluie": true,
		"desc": "Des centaines de drones dessinent la grande roue, une étoile, le nom du parc. Sans bruit ni fumée."},
}
const TYPES_ORDRE := ["feu_artifice", "pyromelodique", "parade_lumineuse", "laser", "drones"]
const TAILLES := ["Petit", "Moyen", "Grand"]
## Nombre de drones (ou de fusées par minute visible) selon la taille.
const DRONES := [150, 300, 500]
const QUAND := {"jamais": "Jamais", "samedis": "Les samedis", "fetes": "Jours de fête (14 juillet, 1er août, 31 décembre)",
	"ete": "Chaque soir de juin à août", "chaque_soir": "Chaque soir"}
const QUAND_ORDRE := ["jamais", "samedis", "fetes", "ete", "chaque_soir"]
const FETES := [[7, 14], [8, 1], [12, 31]]
## Heure du début selon le mois (à la nuit tombée).
const HEURE := {1: 19.0, 2: 19.5, 3: 20.0, 4: 21.0, 5: 21.75, 6: 22.5, 7: 22.5, 8: 21.75, 9: 21.0, 10: 20.0, 11: 19.0, 12: 19.0}
## Annulé : part du prix payée quand même.
const FRAIS_ANNULATION := 0.2


static func disponible(type_id: String) -> bool:
	return raison(type_id) == ""


static func raison(type_id: String) -> String:
	if not TYPES.has(type_id):
		return "Spectacle inconnu."
	var t: Dictionary = TYPES[type_id]
	if Epoques.actif() and int(t.annee) > Epoques.annee():
		return "Pas encore inventé : arrive en %d." % int(t.annee)
	var r := String(t.get("recherche", ""))
	if r != "" and not ParcRecherche.est_fait(r):
		return "À inventer d'abord au bureau d'études : « %s »." % String(ParcRecherche.PROJETS[r].nom)
	return ""


static func programme_vide() -> Dictionary:
	return {"type": "feu_artifice", "taille": 1, "quand": "jamais", "ce_soir": -1}


static func heure(month: int) -> float:
	return float(HEURE.get(month, 21.0))


## Y a-t-il un spectacle prévu ce jour-là (now : ParcLoisirs._now) ?
static func prevu(prog: Dictionary, now: Dictionary) -> bool:
	if not disponible(String(prog.get("type", ""))):
		return false
	if int(prog.get("ce_soir", -1)) == int(now.day):
		return true
	match String(prog.get("quand", "jamais")):
		"samedis": return int(now.wd) == 6
		"fetes":
			for f in FETES:
				if int(now.month) == int(f[0]) and int(now.get("dom", 0)) == int(f[1]):
					return true
			return false
		"ete": return int(now.month) in [6, 7, 8]
		"chaque_soir": return true
	return false


static func prix(prog: Dictionary) -> float:
	var t: Dictionary = TYPES.get(String(prog.get("type", "")), TYPES.feu_artifice)
	return float(t.prix[clampi(int(prog.get("taille", 1)), 0, 2)])


static func duree_h(prog: Dictionary) -> float:
	var t: Dictionary = TYPES.get(String(prog.get("type", "")), TYPES.feu_artifice)
	return float(t.duree[clampi(int(prog.get("taille", 1)), 0, 2)]) / 60.0


## Visiteurs en plus ce jour-là (part des visiteurs attendus).
static func bonus(prog: Dictionary) -> float:
	var t: Dictionary = TYPES.get(String(prog.get("type", "")), TYPES.feu_artifice)
	var b := float(t.bonus[clampi(int(prog.get("taille", 1)), 0, 2)])
	if ParcRecherche.a_effet("nuit"):
		b *= 1.1
	if String(prog.get("type", "")) in ["feu_artifice", "pyromelodique"] and couleurs():
		b *= 1.2
	return b


static func humeur(prog: Dictionary) -> float:
	var t: Dictionary = TYPES.get(String(prog.get("type", "")), TYPES.feu_artifice)
	var h := float(t.humeur[clampi(int(prog.get("taille", 1)), 0, 2)])
	if String(prog.get("type", "")) in ["feu_artifice", "pyromelodique"] and couleurs():
		h *= 1.2
	return h


## Feux en couleurs : trouvés à la recherche, et pas avant 1830.
static func couleurs() -> bool:
	return ParcRecherche.est_fait("feux_couleurs") and (not Epoques.actif() or Epoques.annee() >= 1830)


## Couleurs des feux selon l'époque et la recherche (chimie des feux d'artifice).
static func palette() -> Array:
	var or_ := [Color(1.0, 0.78, 0.35), Color(1.0, 0.92, 0.7), Color(1.0, 0.6, 0.2)]
	if not couleurs():
		return or_
	var out := or_ + [Color(1.0, 0.2, 0.25), Color(0.3, 1.0, 0.35)]
	if not Epoques.actif() or Epoques.annee() >= 1880:
		out += [Color(0.35, 0.5, 1.0), Color(0.8, 0.35, 1.0), Color(0.3, 0.95, 1.0)]
	return out
