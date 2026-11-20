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

## Tailles de ville (noms par population), lues par les villages et le pays.
## Le déblocage des bâtiments passe par l'arbre de progression (ArbreProgression).
const PALIERS := [
	{"nom": "Hameau", "habitants": 0},
	{"nom": "Village", "habitants": 100},
	{"nom": "Bourg", "habitants": 500},
	{"nom": "Ville", "habitants": 2000},
	{"nom": "Grande ville", "habitants": 10000},
]

## Préréglages : un clic remplit tout le panneau.
const PRESETS := {
	"facile": {"nom": "Facile", "argent_depart": 100_000_000, "argent_illimite": false, "cout_construction": 0.5,
		"acces_route": true, "impots": 1.5, "salaires": 1.0, "epuisement": false, "deblocage": "tout", "reseaux_obligatoires": true, "fondation": true, "territoire": true, "main_oeuvre": true, "recherche_parc": true},
	"normal": {"nom": "Normal", "argent_depart": 30_000_000, "argent_illimite": false, "cout_construction": 1.0,
		"acces_route": true, "impots": 1.0, "salaires": 1.0, "epuisement": true, "deblocage": "arbre", "reseaux_obligatoires": true, "fondation": true, "territoire": true, "main_oeuvre": true, "recherche_parc": true},
	"difficile": {"nom": "Difficile", "argent_depart": 5_000_000, "argent_illimite": false, "cout_construction": 2.0,
		"acces_route": true, "impots": 0.75, "salaires": 1.25, "epuisement": true, "deblocage": "arbre", "reseaux_obligatoires": true, "fondation": true, "territoire": true, "main_oeuvre": true, "recherche_parc": true},
	"libre": {"nom": "Bac à sable libre", "argent_depart": 20_000_000, "argent_illimite": true, "cout_construction": 1.0,
		"acces_route": false, "impots": 1.0, "salaires": 1.0, "epuisement": false, "deblocage": "tout", "reseaux_obligatoires": false, "fondation": false, "territoire": false, "main_oeuvre": false, "recherche_parc": false},
}

## Réglages de la partie en cours (lus par tous les systèmes).
static var actuel := ReglagesPartie.new()
## Réglages choisis sur le globe pour la prochaine nouvelle partie (null = par défaut).
static var prochaine: ReglagesPartie = null

var argent_depart: int = 30_000_000
var argent_illimite := false
## Multiplicateur de tous les prix de construction (bâtiments, terrassement, zonage, blocs, murs).
var cout_construction := 1.0
var acces_route := true
## Une partie commence par la fondation d'un village (Maison de commune) :
## avant, ni bâtiment, ni zonage, ni voie (scripts/communes).
var fondation := true
## Chaque nouvelle ville reçoit une petite rue de village en T, offerte, devant sa
## Maison de commune, pour poser ses premières maisons tout de suite (RueFondation).
var rue_fondation := true
## Le tout premier village de la carte (en solo, ou le premier joueur) reçoit ses
## services de base prêts à servir, de son époque, un peu à l'écart du centre :
## courant, eau, égouts, déchets (ServicesFondation, avec le kit de l'État).
var services_fondation := true
## Bâtiments et zonage seulement sur le territoire de ses villages.
var territoire := true
## Multiplicateur des impôts touchés par la ville (taxe foncière, impôts des entreprises).
var impots := 1.0
## Multiplicateur des salaires (habitants, agents de la ville, production).
var salaires := 1.0
## Vitesse du temps (indice de DayNight.SPEEDS) et de la vie (Population.LIFE_SPEEDS).
var vitesse_temps: int = DayNight.DEFAULT_SPEED
var vitesse_vie: int = Population.DEFAULT_LIFE_SPEED
## Mines, carrières et puits s'épuisent ; forêts et poissons s'abîment si on exploite trop.
var epuisement := true
## "tout" : tout le catalogue d'office (bac à sable) ; "arbre" : arbre de
## progression à points (ArbreProgression). Les anciennes parties « progression »
## (paliers de population) passent sur l'arbre.
var deblocage := "tout"
## Arbre de progression : branche -> niveau acheté, points gagnés hors
## population (rangs, missions, succès, admin) et derniers gains.
var arbre := {}
var points_bonus: int = 0
var journal_points: Array = []
## Carte entre amis : un arbre par joueur, pid -> {arbre, bonus, journal, record}.
var arbres_joueurs := {}
## Fêtes de quartier, marchés et matchs organisés tout seuls par la ville.
var evenements_auto := true
## Incendies, tempêtes et épidémies au hasard (on peut toujours en déclencher à la main).
var catastrophes := true
## Fréquence des catastrophes (0,25 : rares ; 1 : normales ; 3 : fréquentes).
var frequence_catastrophes := 1.0
## Secours (pompiers, ambulances, police) envoyés seulement au clic du joueur
## sur l'incident ; sinon automatiquement (un clic fait passer l'appel devant).
var envoi_secours_manuel := false
## Crises économiques mondiales (choc pétrolier, krach…) dans le menu Commerce.
var crises_economiques := true
## Marché mondial : 0,5 calme, 1 normal, 2 agité (amplitude des cours chaque jour).
var volatilite_marche := 1.0
## La neige tient sur les routes : il faut des chasse-neige (scripts/saisons).
var neige_routes := true
## Réseaux obligatoires : sans courant, eau ni égouts, les bâtiments en souffrent
## (sinon tout est desservi d'office).
var reseaux_obligatoires := true
## Multiplicateur des factures d'eau et d'électricité payées par les habitants.
var prix_services := 1.0
## Élections municipales (Elections.MODES) et manifestations (scripts/avis).
var elections := "mairie"
var manifestations := true
## Parc de loisirs : les attractions s'inventent au bureau d'études (ParcRecherche).
## Faux d'office (anciennes parties, tests) ; vrai dans les préréglages joués.
var recherche_parc := false
## Faim des habitants quand les commerces d'alimentation sont vides :
## "aucune" (pas d'effet), "normale" (moins satisfaits, santé, départs),
## "mortelle" (en plus, on peut mourir de faim). Voir Repas.
var faim := "normale"
const FAIMS := ["aucune", "normale", "mortelle"]
## Internet et téléphone comptent : satisfaction des habitants et rendement des
## entreprises (sinon les antennes et la fibre ne servent qu'au décor).
var telecom_necessaire := true
## Vitesse d'usure des routes, rails et réseaux (0 : jamais ; 0,5 lente ; 1 normale ; 2 rapide).
var usure := 1.0
## Déchets : production, collecte et conséquences (non : la ville reste propre toute seule).
var dechets := true
## Quantité de déchets produite par habitant (×0,5 à ×3).
var dechets_quantite := 1.0
## Obsèques, cimetières et crématorium (non : les défunts quittent la ville sans obsèques).
var funeraire := true
## Part des crémations (−1 : selon la région d'origine de chaque défunt).
var cremation := -1.0
## Pollution de l'air, de l'eau et bruit : 0 désactivée, 1 faible, 2 normale, 3 forte.
var pollution: int = 2
## La pollution rend malade et raccourcit la vie (sinon : seulement gêne et valeur des terrains).
var pollution_sante := true
## Réchauffement climatique (ClimatTypes.REGLAGES) : 0 désactivé, 1 histoire réelle,
## 2 le monde suit l'exemple des villes du joueur, 3 accéléré.
var climat: int = 2
## Les sols gardent la mémoire des pollutions (usines, mines, pesticides).
var sols_pollues := true
## Immobilier vivant : indice des prix, promoteurs privés, gentrification (Immobilier).
var immobilier_vivant := true
## Des bidonvilles apparaissent quand des familles ne trouvent aucun logement abordable.
var bidonvilles := true
## Joueur qui a créé la partie (SaveGame.player_id()) : l'admin des cartes entre amis.
var createur := ""
## Chantiers : les constructions apparaissent d'un coup (bac à sable) au lieu de
## se construire étape par étape au rythme de la vie (Chantiers).
var construction_instantanee := false
## Horaires des équipes : "semaine", "tous_les_jours" ou "continu" (Chantiers.HORAIRES).
var horaires_chantiers := "semaine"
## Rythme des chantiers : multiplie la vitesse de tous les chantiers (bâtiments,
## voies, réseaux). 1 = durées réalistes au rythme de la vie ; 3 par défaut pour
## que les premières maisons des fondateurs sortent en 2 à 3 semaines de jeu.
var rythme_chantiers := 3.0
const RYTHMES_CHANTIERS := [1.0, 2.0, 3.0, 5.0, 10.0]
## Départ rapide : tant que la carte compte peu d'habitants, les chantiers vont
## encore plus vite (Chantiers.bonus_depart) pour que la première ville décolle.
var depart_rapide := true
## Fondateurs arrivés avec le premier village (réserve de travailleurs,
## scripts/communes/fondateurs.gd) : 0 = aucun.
var fondateurs: int = 100
const FONDATEURS_MAX := 1000
## Jours de vivres apportés par les fondateurs (ensuite, le ravitaillement du
## campement est payé par la caisse).
var vivres_jours: int = 90
const VIVRES_MAX := 365
## Les chantiers ont besoin d'ouvriers (fondateurs au campement, entreprises
## du bâtiment) : sans eux, ils s'arrêtent.
var main_oeuvre := true
## Tutoriel guidé de la première partie (scripts/tutoriel) : coché sur le globe
## ou dans l'Admin, décoché quand le joueur le finit ou l'arrête.
var tutoriel := true
## Objectifs résumés en haut à gauche de l'écran (rang de la ville, missions).
var objectifs_ecran := true
## Plus grande population atteinte (points de progrès de population).
var record_habitants := 0
## Époques (scripts/epoques) : année de départ de la partie (0 = époque
## actuelle, rien de verrouillé), années d'histoire par année de jeu, heure
## de l'horloge au début de l'histoire, années sautées par l'admin.
var annee_depart: int = 0
var rythme_histoire := 1.0
var histoire_debut := 0.0
var histoire_saut: int = 0


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


func est_debloque(id: String) -> bool:
	return ArbreProgression.batiment_ouvert(self, id)


## Raison du blocage, ou "".
func raison_blocage(id: String) -> String:
	# Ville sous tutelle du préfet : pas de nouveau bâtiment public.
	var tutelle := BudgetCommunal.raison_blocage(id)
	if tutelle != "":
		return tutelle
	# Pas encore inventé à l'époque de la partie.
	var epoque := Epoques.raison_batiment(id, self)
	if epoque != "":
		return epoque
	# Attraction du parc pas encore inventée au bureau d'études.
	var recherche := ParcRecherche.raison_blocage(id, self)
	if recherche != "":
		return recherche
	# Scénario en cours : bâtiments interdits.
	var sc := ScenarioPartie.refus_batiment(id)
	if sc != "":
		return sc
	return ArbreProgression.raison_batiment(self, id)


## Voies et stations : époque d'abord, puis branche Transports de l'arbre.
func raison_voie(cls: String) -> String:
	var ep := Epoques.raison_voie(cls, self)
	return ep if ep != "" else ArbreProgression.raison_voie(self, cls)


func raison_station(type_id: String) -> String:
	var ep := Epoques.raison_station(type_id, self)
	return ep if ep != "" else ArbreProgression.raison_station(self, type_id)


## Note la population ; renvoie le nombre de points de progrès gagnés par ce
## nouveau record (0 si rien de nouveau).
func note_population(n: int) -> int:
	if n <= record_habitants:
		return 0
	var before := ArbreProgression.points_population(record_habitants)
	record_habitants = n
	var gain := ArbreProgression.points_population(n) - before
	if gain > 0:
		ArbreProgression.noter(self, gain, "%d habitants" % ArbreProgression.SEUILS_POPULATION[ArbreProgression.points_population(n) - 1])
	return gain


# --- Fichier --------------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {"version": VERSION, "argent_depart": argent_depart, "argent_illimite": argent_illimite,
		"cout_construction": cout_construction, "acces_route": acces_route, "impots": impots,
		"salaires": salaires, "vitesse_temps": vitesse_temps, "vitesse_vie": vitesse_vie,
		"epuisement": epuisement, "deblocage": deblocage, "createur": createur,
		"arbre": arbre.duplicate(), "points_bonus": points_bonus, "journal_points": journal_points.duplicate(true), "arbres_joueurs": arbres_joueurs.duplicate(true),
		"record_habitants": record_habitants, "evenements_auto": evenements_auto, "catastrophes": catastrophes,
		"frequence_catastrophes": frequence_catastrophes, "envoi_secours_manuel": envoi_secours_manuel, "crises_economiques": crises_economiques, "volatilite_marche": volatilite_marche, "neige_routes": neige_routes, "faim": faim, "telecom_necessaire": telecom_necessaire, "construction_instantanee": construction_instantanee,
		"horaires_chantiers": horaires_chantiers, "rythme_chantiers": rythme_chantiers, "depart_rapide": depart_rapide, "usure": usure, "dechets": dechets, "dechets_quantite": dechets_quantite, "pollution": pollution, "pollution_sante": pollution_sante, "climat": climat, "sols_pollues": sols_pollues,
		"immobilier_vivant": immobilier_vivant, "bidonvilles": bidonvilles,
		"elections": elections, "manifestations": manifestations, "funeraire": funeraire, "recherche_parc": recherche_parc, "cremation": cremation, "reseaux_obligatoires": reseaux_obligatoires, "prix_services": prix_services,
		"fondation": fondation, "rue_fondation": rue_fondation, "services_fondation": services_fondation, "territoire": territoire, "fondateurs": fondateurs, "vivres_jours": vivres_jours, "main_oeuvre": main_oeuvre,
		"tutoriel": tutoriel, "objectifs_ecran": objectifs_ecran,
		"annee_depart": annee_depart, "rythme_histoire": rythme_histoire, "histoire_debut": histoire_debut, "histoire_saut": histoire_saut}


func from_dict(d: Dictionary) -> void:
	var n := PRESETS.normal as Dictionary
	argent_depart = clampi(int(d.get("argent_depart", n.argent_depart)), 0, ARGENT_MAX)
	argent_illimite = bool(d.get("argent_illimite", n.argent_illimite))
	cout_construction = clampf(float(d.get("cout_construction", 1.0)), COUT_MIN, COUT_MAX)
	acces_route = bool(d.get("acces_route", true))
	fondation = bool(d.get("fondation", true))
	rue_fondation = bool(d.get("rue_fondation", true))
	services_fondation = bool(d.get("services_fondation", true))
	territoire = bool(d.get("territoire", true))
	fondateurs = clampi(int(d.get("fondateurs", 100)), 0, FONDATEURS_MAX)
	vivres_jours = clampi(int(d.get("vivres_jours", 90)), 0, VIVRES_MAX)
	main_oeuvre = bool(d.get("main_oeuvre", true))
	tutoriel = bool(d.get("tutoriel", true))
	objectifs_ecran = bool(d.get("objectifs_ecran", true))
	impots = clampf(float(d.get("impots", 1.0)), 0.0, IMPOTS_MAX)
	salaires = clampf(float(d.get("salaires", 1.0)), SALAIRES_MIN, SALAIRES_MAX)
	vitesse_temps = clampi(int(d.get("vitesse_temps", DayNight.DEFAULT_SPEED)), 0, DayNight.SPEEDS.size() - 1)
	vitesse_vie = clampi(int(d.get("vitesse_vie", Population.DEFAULT_LIFE_SPEED)), 0, Population.LIFE_SPEEDS.size() - 1)
	epuisement = bool(d.get("epuisement", true))
	deblocage = "arbre" if ["arbre", "progression"].has(String(d.get("deblocage", "tout"))) else "tout"
	arbre = {}
	var a = d.get("arbre", {})
	if a is Dictionary:
		for b in a:
			if not ArbreProgression.branche(String(b)).is_empty():
				arbre[String(b)] = clampi(int(a[b]), 0, ArbreProgression.NIVEAU_MAX)
	points_bonus = maxi(0, int(d.get("points_bonus", 0)))
	arbres_joueurs = lire_arbres_joueurs(d.get("arbres_joueurs", {}))
	journal_points = []
	var jp = d.get("journal_points", [])
	if jp is Array:
		for e in jp:
			if e is Dictionary:
				journal_points.append({"n": int(e.get("n", 0)), "raison": String(e.get("raison", ""))})
	createur = String(d.get("createur", ""))
	record_habitants = maxi(0, int(d.get("record_habitants", 0)))
	evenements_auto = bool(d.get("evenements_auto", true))
	catastrophes = bool(d.get("catastrophes", true))
	envoi_secours_manuel = bool(d.get("envoi_secours_manuel", false))
	frequence_catastrophes = clampf(float(d.get("frequence_catastrophes", 1.0)), 0.25, 3.0)
	crises_economiques = bool(d.get("crises_economiques", true))
	volatilite_marche = clampf(float(d.get("volatilite_marche", 1.0)), 0.0, 3.0)
	neige_routes = bool(d.get("neige_routes", true))
	reseaux_obligatoires = bool(d.get("reseaux_obligatoires", true))
	prix_services = clampf(float(d.get("prix_services", 1.0)), PRIX_SERVICES_MIN, PRIX_SERVICES_MAX)
	elections = String(d.get("elections", "objectifs"))
	if not Elections.MODES.has(elections):
		elections = "objectifs"
	manifestations = bool(d.get("manifestations", true))
	recherche_parc = bool(d.get("recherche_parc", false))
	faim = String(d.get("faim", "normale"))
	if not FAIMS.has(faim):
		faim = "normale"
	telecom_necessaire = bool(d.get("telecom_necessaire", true))
	usure = clampf(float(d.get("usure", 1.0)), 0.0, 3.0)
	construction_instantanee = bool(d.get("construction_instantanee", false))
	horaires_chantiers = String(d.get("horaires_chantiers", "semaine"))
	rythme_chantiers = clampf(float(d.get("rythme_chantiers", 3.0)), 0.25, 20.0)
	depart_rapide = bool(d.get("depart_rapide", true))
	if not Chantiers.HORAIRES.has(horaires_chantiers):
		horaires_chantiers = "semaine"
	dechets = bool(d.get("dechets", true))
	dechets_quantite = clampf(float(d.get("dechets_quantite", 1.0)), 0.5, 3.0)
	pollution = clampi(int(d.get("pollution", 2)), 0, 3)
	pollution_sante = bool(d.get("pollution_sante", true))
	climat = clampi(int(d.get("climat", 2)), 0, 3)
	sols_pollues = bool(d.get("sols_pollues", true))
	immobilier_vivant = bool(d.get("immobilier_vivant", true))
	bidonvilles = bool(d.get("bidonvilles", true))
	funeraire = bool(d.get("funeraire", true))
	cremation = clampf(float(d.get("cremation", -1.0)), -1.0, 1.0)
	annee_depart = int(d.get("annee_depart", 0))
	if annee_depart > 0:
		annee_depart = maxi(Epoques.ANNEE_MIN, annee_depart)
	else:
		annee_depart = 0
	rythme_histoire = clampf(float(d.get("rythme_histoire", 1.0)), 1.0, 25.0)
	histoire_debut = float(d.get("histoire_debut", 0.0))
	histoire_saut = int(d.get("histoire_saut", 0))


## Arbres des joueurs d'une carte entre amis, nettoyés (pid -> {arbre, bonus, journal, record}).
static func lire_arbres_joueurs(aj: Variant) -> Dictionary:
	var out := {}
	if not aj is Dictionary:
		return out
	for pid in aj:
		var e = aj[pid]
		if not e is Dictionary:
			continue
		var ar := {}
		if e.get("arbre") is Dictionary:
			for b in e.arbre:
				if not ArbreProgression.branche(String(b)).is_empty():
					ar[String(b)] = clampi(int(e.arbre[b]), 0, ArbreProgression.NIVEAU_MAX)
		var jr: Array = []
		if e.get("journal") is Array:
			for x in e.journal:
				if x is Dictionary:
					jr.append({"n": int(x.get("n", 0)), "raison": String(x.get("raison", ""))})
		out[String(pid)] = {"arbre": ar, "bonus": maxi(0, int(e.get("bonus", 0))), "journal": jr, "record": maxi(0, int(e.get("record", 0)))}
	return out


## Réglages par défaut des nouvelles parties (fichier du joueur, sinon « Normal »).
static func load_defaults() -> ReglagesPartie:
	var r := preset("normal")
	if FileAccess.file_exists(DEFAULTS_FILE):
		var data = JSON.parse_string(FileAccess.get_file_as_string(DEFAULTS_FILE))
		if data is Dictionary:
			r.from_dict(data)
			# Réglages par défaut enregistrés avant la recherche du parc : on la garde.
			if not (data as Dictionary).has("recherche_parc"):
				r.recherche_parc = true
	# « -- --tout-debloque » (suite de tests, essais) : nouvelles parties sans arbre.
	if OS.get_cmdline_user_args().has("--tout-debloque"):
		r.deblocage = "tout"
	r.createur = ""
	r.record_habitants = 0
	r.arbre = {}
	r.points_bonus = 0
	r.journal_points = []
	r.arbres_joueurs = {}
	r.histoire_debut = 0.0
	r.histoire_saut = 0
	return r


func save_as_defaults() -> bool:
	var d := to_dict()
	d.erase("createur")
	d.erase("record_habitants")
	d.erase("arbre")
	d.erase("points_bonus")
	d.erase("journal_points")
	d.erase("arbres_joueurs")
	d.erase("histoire_debut")
	d.erase("histoire_saut")
	var f := FileAccess.open(DEFAULTS_FILE, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(d, "\t"))
	return true


## Résumé en une ligne (globe, infobulles).
func summary() -> String:
	var money := "argent illimité" if argent_illimite else BuildingSystem.format_short(argent_depart) + " au départ"
	return "%s · %s · coûts ×%s · %s · %s" % [preset_name(), money, _fmt(cout_construction),
		"arbre de progression" if deblocage == "arbre" else "tout débloqué", Epoques.resume(self)]


static func _fmt(x: float) -> String:
	return String.num(x, 2).replace(".", ",")
