class_name ReglagesPartie
extends RefCounted
## Réglages d'une partie (panneau Admin, F10) : argent, coûts, règles, économie,
## temps, ressources et déblocage des bâtiments.
##
## - Choisis à la création de la partie (globe, bouton « Réglages de la partie »),
##   puis modifiables en cours de partie par l'admin.
## - Qui est admin : en bac à sable, le joueur ; entre amis, le créateur de la
##   carte ; sur la carte mondiale, le développeur seulement.
## - Gardés dans la sauvegarde (section « reglages »). Les réglages par défaut des
##   nouvelles parties sont dans user://reglages_defaut.json (« Garder par défaut »).
## - Chaque joueur a sa propre caisse : argent_depart est ce que reçoit chaque
##   joueur en arrivant sur la carte (en solo, la caisse de la partie).

const VERSION := 1
const DEFAULTS_FILE := "user://reglages_defaut.json"

## Bornes des réglages.
const ARGENT_MAX := 10_000_000_000
const COUT_MIN := 0.5
const COUT_MAX := 5.0
const IMPOTS_MAX := 3.0
const SALAIRES_MIN := 0.5
const SALAIRES_MAX := 2.0
const PRIX_SERVICES_MIN := 0.0
const PRIX_SERVICES_MAX := 3.0

## Déblocage des bâtiments au fil de la partie : paliers de population (record
## atteint, une démolition ne rebloque rien) et prix maximal débloqué.
const PALIERS := [
	{"nom": "Hameau", "habitants": 0, "prix_max": 1_500_000},
	{"nom": "Village", "habitants": 100, "prix_max": 5_000_000},
	{"nom": "Bourg", "habitants": 500, "prix_max": 15_000_000},
	{"nom": "Ville", "habitants": 2000, "prix_max": 40_000_000},
	{"nom": "Grande ville", "habitants": 10000, "prix_max": -1},
]
## Toujours débloqués : les écoles (il en faut tôt) et les sites de production
## de base, sinon une ville qui démarre ne peut pas vivre.
const TOUJOURS := ["ecole"]

## Préréglages : un clic remplit tout le panneau.
const PRESETS := {
	"facile": {"nom": "Facile", "argent_depart": 100_000_000, "argent_illimite": false, "cout_construction": 0.5,
		"acces_route": true, "impots": 1.5, "salaires": 1.0, "epuisement": false, "deblocage": "tout", "reseaux_obligatoires": true},
	"normal": {"nom": "Normal", "argent_depart": 20_000_000, "argent_illimite": false, "cout_construction": 1.0,
		"acces_route": true, "impots": 1.0, "salaires": 1.0, "epuisement": true, "deblocage": "tout", "reseaux_obligatoires": true},
	"difficile": {"nom": "Difficile", "argent_depart": 5_000_000, "argent_illimite": false, "cout_construction": 2.0,
		"acces_route": true, "impots": 0.75, "salaires": 1.25, "epuisement": true, "deblocage": "progression", "reseaux_obligatoires": true},
	"libre": {"nom": "Bac à sable libre", "argent_depart": 20_000_000, "argent_illimite": true, "cout_construction": 1.0,
		"acces_route": false, "impots": 1.0, "salaires": 1.0, "epuisement": false, "deblocage": "tout", "reseaux_obligatoires": false},
}

## Réglages de la partie en cours (lus par tous les systèmes).
static var actuel := ReglagesPartie.new()
## Réglages choisis sur le globe pour la prochaine nouvelle partie (null = par défaut).
static var prochaine: ReglagesPartie = null

var argent_depart: int = 20_000_000
var argent_illimite := false
## Multiplicateur de tous les prix de construction (bâtiments, terrassement, zonage, blocs, murs).
var cout_construction := 1.0
var acces_route := true
## Multiplicateur des impôts touchés par la ville (taxe foncière, impôts des entreprises).
var impots := 1.0
## Multiplicateur des salaires (habitants, agents de la ville, production).
var salaires := 1.0
## Vitesse du temps (indice de DayNight.SPEEDS) et de la vie (Population.LIFE_SPEEDS).
var vitesse_temps: int = 2
var vitesse_vie: int = Population.DEFAULT_LIFE_SPEED
## Mines, carrières et puits s'épuisent ; forêts et poissons s'abîment si on exploite trop.
var epuisement := true
## "tout" : tout le catalogue d'office ; "progression" : par paliers de population.
var deblocage := "tout"
## Fêtes de quartier, marchés et matchs organisés tout seuls par la ville.
var evenements_auto := true
## Incendies, tempêtes et épidémies au hasard (on peut toujours en déclencher à la main).
var catastrophes := true
## Fréquence des catastrophes (0,25 : rares ; 1 : normales ; 3 : fréquentes).
var frequence_catastrophes := 1.0
## Réseaux obligatoires : sans courant, eau ni égouts, les bâtiments en souffrent
## (sinon tout est desservi d'office).
var reseaux_obligatoires := true
## Multiplicateur des factures d'eau et d'électricité payées par les habitants.
var prix_services := 1.0
## Internet et téléphone comptent : satisfaction des habitants et rendement des
## entreprises (sinon les antennes et la fibre ne servent qu'au décor).
var telecom_necessaire := true
## Vitesse d'usure des routes, rails et réseaux (0 : jamais ; 0,5 lente ; 1 normale ; 2 rapide).
var usure := 1.0
## Déchets : production, collecte et conséquences (non : la ville reste propre toute seule).
var dechets := true
## Quantité de déchets produite par habitant (×0,5 à ×3).
var dechets_quantite := 1.0
## Pollution de l'air, de l'eau et bruit : 0 désactivée, 1 faible, 2 normale, 3 forte.
var pollution: int = 2
## La pollution rend malade et raccourcit la vie (sinon : seulement gêne et valeur des terrains).
var pollution_sante := true
## Joueur qui a créé la partie (SaveGame.player_id()) : l'admin des cartes entre amis.
var createur := ""
## Chantiers : les constructions apparaissent d'un coup (bac à sable) au lieu de
## se construire étape par étape au rythme de la vie (Chantiers).
var construction_instantanee := false
## Horaires des équipes : "semaine", "tous_les_jours" ou "continu" (Chantiers.HORAIRES).
var horaires_chantiers := "semaine"
## Plus grande population atteinte (pour les paliers).
var record_habitants := 0


static func preset(id: String) -> ReglagesPartie:
	var r := ReglagesPartie.new()
	r.apply_preset(id)
	return r


func apply_preset(id: String) -> void:
	var p: Dictionary = PRESETS.get(id, PRESETS.normal)
	for k in p:
		if k != "nom":
			set(k, p[k])


## Nom du préréglage qui correspond exactement à ces réglages, ou "Personnalisé".
func preset_name() -> String:
	for id in PRESETS:
		var p: Dictionary = PRESETS[id]
		var same := true
		for k in p:
			if k != "nom" and get(k) != p[k]:
				same = false
				break
		if same:
			return String(p.nom)
	return "Personnalisé"


func duplicate_settings() -> ReglagesPartie:
	var r := ReglagesPartie.new()
	r.from_dict(to_dict())
	return r


# --- Qui est admin ------------------------------------------------------------------

## Le joueur de cette machine est-il le développeur ? Pour l'instant : jeu lancé
## depuis l'éditeur Godot, ou avec l'option « -- --dev ». Le serveur de la carte
## mondiale fera la vraie vérification.
static func est_developpeur() -> bool:
	return OS.has_feature("editor") or OS.get_cmdline_user_args().has("--dev")


## Ce joueur peut-il changer les réglages de cette partie ?
static func peut_administrer(mode: int, createur_id: String, joueur: String, developpeur: bool) -> bool:
	match mode:
		GameStart.Mode.BAC_A_SABLE:
			return true
		GameStart.Mode.ENTRE_AMIS:
			return createur_id == "" or createur_id == joueur
		GameStart.Mode.MONDIALE:
			return developpeur
	return false


## Raccourci pour la partie en cours et le joueur de cette machine.
static func admin_ici() -> bool:
	return peut_administrer(int(GameStart.mode), actuel.createur, SaveGame.player_id(), est_developpeur())


static func qui_est_admin(mode: int) -> String:
	match mode:
		GameStart.Mode.ENTRE_AMIS:
			return "Carte entre amis : seul le créateur de la carte peut changer ces réglages."
		GameStart.Mode.MONDIALE:
			return "Carte mondiale : seul le développeur peut changer ces réglages."
	return "Bac à sable : tu es l'admin de ta partie."


# --- Prix et déblocage --------------------------------------------------------------

## Prix après le multiplicateur de coût de la partie en cours.
static func prix(v: int) -> int:
	return roundi(float(v) * actuel.cout_construction)


func palier_atteint() -> int:
	var best := 0
	for i in PALIERS.size():
		if record_habitants >= int(PALIERS[i].habitants):
			best = i
	return best


## Premier palier où ce bâtiment est débloqué.
static func palier_requis(id: String) -> int:
	var t := BuildingCatalog.get_type(id)
	if String(t.get("cat", "")) == "production":
		return 0
	# Il faut du courant et de l'eau dès le hameau (sauf les très grosses centrales).
	if String(t.get("cat", "")) == "reseaux" and BuildingCatalog.cost(id) <= 50_000_000:
		return 0
	for k in Metiers.keys_of(id):
		if TOUJOURS.has(k):
			return 0
	var c := BuildingCatalog.cost(id)
	for i in PALIERS.size():
		var m := int(PALIERS[i].prix_max)
		if m < 0 or c <= m:
			return i
	return PALIERS.size() - 1


func est_debloque(id: String) -> bool:
	return deblocage != "progression" or palier_requis(id) <= palier_atteint()


## Raison du blocage, ou "".
func raison_blocage(id: String) -> String:
	# Ville sous tutelle du préfet : pas de nouveau bâtiment public.
	var tutelle := BudgetCommunal.raison_blocage(id)
	if tutelle != "":
		return tutelle
	if est_debloque(id):
		return ""
	var p: Dictionary = PALIERS[palier_requis(id)]
	return "Débloqué au palier « %s » (%d habitants)." % [p.nom, int(p.habitants)]


## Note la population ; renvoie le nom du nouveau palier atteint, ou "".
func note_population(n: int) -> String:
	if n <= record_habitants:
		return ""
	var before := palier_atteint()
	record_habitants = n
	var after := palier_atteint()
	return String(PALIERS[after].nom) if after > before else ""


# --- Fichier --------------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {"version": VERSION, "argent_depart": argent_depart, "argent_illimite": argent_illimite,
		"cout_construction": cout_construction, "acces_route": acces_route, "impots": impots,
		"salaires": salaires, "vitesse_temps": vitesse_temps, "vitesse_vie": vitesse_vie,
		"epuisement": epuisement, "deblocage": deblocage, "createur": createur,
		"record_habitants": record_habitants, "evenements_auto": evenements_auto, "catastrophes": catastrophes,
		"frequence_catastrophes": frequence_catastrophes, "telecom_necessaire": telecom_necessaire, "construction_instantanee": construction_instantanee,
		"horaires_chantiers": horaires_chantiers, "usure": usure, "dechets": dechets, "dechets_quantite": dechets_quantite, "pollution": pollution, "pollution_sante": pollution_sante,
		"reseaux_obligatoires": reseaux_obligatoires, "prix_services": prix_services}


func from_dict(d: Dictionary) -> void:
	var n := PRESETS.normal as Dictionary
	argent_depart = clampi(int(d.get("argent_depart", n.argent_depart)), 0, ARGENT_MAX)
	argent_illimite = bool(d.get("argent_illimite", n.argent_illimite))
	cout_construction = clampf(float(d.get("cout_construction", 1.0)), COUT_MIN, COUT_MAX)
	acces_route = bool(d.get("acces_route", true))
	impots = clampf(float(d.get("impots", 1.0)), 0.0, IMPOTS_MAX)
	salaires = clampf(float(d.get("salaires", 1.0)), SALAIRES_MIN, SALAIRES_MAX)
	vitesse_temps = clampi(int(d.get("vitesse_temps", DayNight.DEFAULT_SPEED)), 0, DayNight.SPEEDS.size() - 1)
	vitesse_vie = clampi(int(d.get("vitesse_vie", Population.DEFAULT_LIFE_SPEED)), 0, Population.LIFE_SPEEDS.size() - 1)
	epuisement = bool(d.get("epuisement", true))
	deblocage = "progression" if String(d.get("deblocage", "tout")) == "progression" else "tout"
	createur = String(d.get("createur", ""))
	record_habitants = maxi(0, int(d.get("record_habitants", 0)))
	evenements_auto = bool(d.get("evenements_auto", true))
	catastrophes = bool(d.get("catastrophes", true))
	frequence_catastrophes = clampf(float(d.get("frequence_catastrophes", 1.0)), 0.25, 3.0)
	reseaux_obligatoires = bool(d.get("reseaux_obligatoires", true))
	prix_services = clampf(float(d.get("prix_services", 1.0)), PRIX_SERVICES_MIN, PRIX_SERVICES_MAX)
	telecom_necessaire = bool(d.get("telecom_necessaire", true))
	usure = clampf(float(d.get("usure", 1.0)), 0.0, 3.0)
	construction_instantanee = bool(d.get("construction_instantanee", false))
	horaires_chantiers = String(d.get("horaires_chantiers", "semaine"))
	if not Chantiers.HORAIRES.has(horaires_chantiers):
		horaires_chantiers = "semaine"
	dechets = bool(d.get("dechets", true))
	dechets_quantite = clampf(float(d.get("dechets_quantite", 1.0)), 0.5, 3.0)
	pollution = clampi(int(d.get("pollution", 2)), 0, 3)
	pollution_sante = bool(d.get("pollution_sante", true))


## Réglages par défaut des nouvelles parties (fichier du joueur, sinon « Normal »).
static func load_defaults() -> ReglagesPartie:
	var r := preset("normal")
	if FileAccess.file_exists(DEFAULTS_FILE):
		var data = JSON.parse_string(FileAccess.get_file_as_string(DEFAULTS_FILE))
		if data is Dictionary:
			r.from_dict(data)
	r.createur = ""
	r.record_habitants = 0
	return r


func save_as_defaults() -> bool:
	var d := to_dict()
	d.erase("createur")
	d.erase("record_habitants")
	var f := FileAccess.open(DEFAULTS_FILE, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(d, "\t"))
	return true


## Résumé en une ligne (globe, infobulles).
func summary() -> String:
	var money := "argent illimité" if argent_illimite else BuildingSystem.format_short(argent_depart) + " au départ"
	return "%s · %s · coûts ×%s · %s" % [preset_name(), money, _fmt(cout_construction),
		"déblocage par paliers" if deblocage == "progression" else "tout débloqué"]


static func _fmt(x: float) -> String:
	return String.num(x, 2).replace(".", ",")
