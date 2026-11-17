class_name ParcRecherche
extends RefCounted
## Recherche du parc de loisirs : le bureau d'études met au point de nouvelles
## attractions et des améliorations (onglet Recherche du panneau Maj+G).
##
## - Points de recherche : un budget mensuel (0 à 80 000 €), payé chaque jour par
##   les caisses des villes qui ont un parc (au prorata), plus un peu grâce aux
##   visiteurs (les idées viennent en regardant les files). Sans parc, rien ne
##   bouge.
## - Un projet à la fois, et une file d'attente : quand il est fini, le suivant
##   démarre tout seul.
## - Époques : un projet n'est proposé qu'une fois son année atteinte (pas de
##   looping en 1850). Certains demandent un projet d'abord (« requis »).
## - Attractions : avec le réglage de partie « Recherche des attractions »
##   (Admin F10, oui par défaut dans les nouvelles parties), les attractions des
##   projets restent verrouillées dans Construire tant qu'elles ne sont pas
##   trouvées. Sans le réglage, tout est posable d'office ; la recherche sert
##   alors aux améliorations (et les attractions sont « déjà connues »).
## - Améliorations : effets lus par ParcLoisirs (usure, files, stands, entrées,
##   humeur) et par les soirées (ParcSoirees : couleurs, musique, drones).

## Budgets possibles (€ par mois).
const BUDGETS := [0, 10_000, 30_000, 80_000]
const BUDGET_NOMS := ["Aucun", "Modeste (10 000 €/mois)", "Normal (30 000 €/mois)", "Ambitieux (80 000 €/mois)"]
## Euros par point de recherche.
const EUROS_POINT := 400.0
## Points gagnés par visiteur du jour.
const POINTS_VISITEUR := 1.0 / 4000.0
const FILE_MAX := 6

## Projets : "type" attraction (débloque "ids") ou amelioration (effet "effet").
const PROJETS := {
	# --- Attractions --------------------------------------------------------------------
	"palais_glaces": {"nom": "Palais des glaces", "type": "attraction", "ids": ["palais_glaces"], "points": 15, "annee": 1850,
		"desc": "Des miroirs, beaucoup de miroirs. Le plus simple des labyrinthes."},
	"montagnes_russes": {"nom": "Montagnes russes familiales", "type": "attraction", "ids": ["montagnes_russes"], "points": 110, "annee": 1885,
		"desc": "Le « scenic railway » : une bosse, des virages, et des cris."},
	"grande_roue_parc": {"nom": "Grande roue", "type": "attraction", "ids": ["grande_roue_parc"], "points": 60, "annee": 1893,
		"desc": "Inventée pour l'exposition de Chicago. Nos ingénieurs promettent qu'elle tourne dans les deux sens."},
	"chaises_volantes": {"nom": "Chaises volantes", "type": "attraction", "ids": ["chaises_volantes"], "points": 35, "annee": 1900},
	"autos_tamponneuses": {"nom": "Autos tamponneuses", "type": "attraction", "ids": ["autos_tamponneuses"], "points": 35, "annee": 1920,
		"desc": "Une piste électrifiée et douze voitures. Le code de la route reste à inventer."},
	"train_fantome": {"nom": "Train fantôme", "type": "attraction", "ids": ["train_fantome"], "points": 40, "annee": 1930},
	"tasses_parc": {"nom": "Tasses tournantes", "type": "attraction", "ids": ["tasses_parc"], "points": 30, "annee": 1950},
	"bateau_pirate": {"nom": "Bateau pirate", "type": "attraction", "ids": ["bateau_pirate"], "points": 70, "annee": 1960, "requis": ["chaises_volantes"]},
	"bateaux_tamponneurs": {"nom": "Bateaux tamponneurs", "type": "attraction", "ids": ["bateaux_tamponneurs"], "points": 40, "annee": 1960,
		"requis": ["autos_tamponneuses"]},
	"piscine_vagues": {"nom": "Piscine à vagues", "type": "attraction", "ids": ["piscine_vagues"], "points": 90, "annee": 1970},
	"tour_panoramique": {"nom": "Tour panoramique", "type": "attraction", "ids": ["tour_panoramique"], "points": 80, "annee": 1970,
		"requis": ["grande_roue_parc"], "desc": "Une cabine vitrée qui monte en tournant à 60 m."},
	"looping_express": {"nom": "Montagnes russes à looping", "type": "attraction", "ids": ["looping_express"], "points": 170, "annee": 1976,
		"requis": ["montagnes_russes"], "desc": "Le premier looping vertical moderne date de 1976. Les nôtres tiendront la tête en bas aussi."},
	"tour_chute": {"nom": "Tour de chute libre", "type": "attraction", "ids": ["tour_chute"], "points": 130, "annee": 1980, "requis": ["tour_panoramique"]},
	"riviere_rapide": {"nom": "Rivière rapide en bouées", "type": "attraction", "ids": ["riviere_rapide"], "points": 120, "annee": 1980,
		"requis": ["bateaux_tamponneurs"]},
	"cinema_dynamique": {"nom": "Cinéma dynamique 4D", "type": "attraction", "ids": ["cinema_dynamique"], "points": 100, "annee": 1993,
		"desc": "Sièges qui bougent, vent, embruns et odeurs. Le mal de mer est offert."},
	# --- Améliorations ------------------------------------------------------------------
	"revision_preventive": {"nom": "Révisions préventives", "type": "amelioration", "effet": "usure", "points": 40, "annee": 1880,
		"desc": "Les attractions s'usent 25 % moins vite : on change les boulons avant qu'ils tombent."},
	"eclairage_feerique": {"nom": "Éclairage féerique", "type": "amelioration", "effet": "nuit", "points": 45, "annee": 1900,
		"desc": "Des milliers d'ampoules : le parc attire 10 % de monde en plus les soirs de spectacle et permet la parade lumineuse."},
	"feux_couleurs": {"nom": "Feux d'artifice en couleurs", "type": "amelioration", "effet": "couleurs", "points": 30, "annee": 1830,
		"desc": "Rouge du strontium, vert du baryum, puis bleu du cuivre : fini les feux tout dorés. +20 % d'effet sur le public."},
	"mascottes": {"nom": "Mascottes du parc", "type": "amelioration", "effet": "humeur", "points": 35, "annee": 1955,
		"desc": "Un grand lapin qui serre des mains. Les visiteurs arrivent de meilleure humeur (+4)."},
	"restauration_rapide": {"nom": "Restauration rapide", "type": "amelioration", "effet": "stands", "points": 40, "annee": 1955,
		"desc": "Les stands servent 30 % plus vite. Les frites, elles, cuisent toujours le même temps."},
	"spectacle_laser": {"nom": "Lasers et jets d'eau", "type": "amelioration", "effet": "laser", "points": 50, "annee": 1980,
		"requis": ["eclairage_feerique"], "desc": "Permet le spectacle laser du soir (onglet Soirées)."},
	"pyromelodie": {"nom": "Feux pyromélodiques", "type": "amelioration", "effet": "musique", "points": 60, "annee": 1990,
		"requis": ["feux_couleurs"], "desc": "Les fusées partent en rythme avec la musique : un feu inoubliable (onglet Soirées)."},
	"billetterie_ligne": {"nom": "Billetterie en ligne", "type": "amelioration", "effet": "billets", "points": 45, "annee": 1998,
		"desc": "Billets achetés à l'avance : 8 % de visiteurs en plus et moins de demi-tours au guichet."},
	"coupe_file": {"nom": "Coupe-file", "type": "amelioration", "effet": "files", "points": 55, "annee": 1999,
		"desc": "Réservation d'un créneau : l'attente paraît 20 % plus courte, l'humeur en souffre moins."},
	"drones_lumineux": {"nom": "Drones lumineux", "type": "amelioration", "effet": "drones", "points": 90, "annee": 2016,
		"requis": ["spectacle_laser"], "desc": "Des centaines de drones dessinent dans le ciel, sans bruit ni fumée (onglet Soirées)."},
}
const ORDRE := ["feux_couleurs", "palais_glaces", "revision_preventive", "montagnes_russes", "grande_roue_parc", "chaises_volantes",
	"eclairage_feerique", "autos_tamponneuses", "train_fantome", "tasses_parc", "mascottes", "restauration_rapide", "bateau_pirate",
	"bateaux_tamponneurs", "piscine_vagues", "tour_panoramique", "looping_express", "tour_chute", "riviere_rapide", "spectacle_laser",
	"pyromelodie", "cinema_dynamique", "billetterie_ligne", "coupe_file", "drones_lumineux"]

## Budget choisi (indice de BUDGETS).
var budget := 1
var points := 0.0
## Projet en cours ("" : aucun) et file d'attente.
var en_cours := ""
var file: Array = []
## Projets finis : id → jour (unix / 86400) de la découverte.
var faits: Dictionary = {}
## Points gagnés hier (affichage).
var hier := 0.0


static func instance() -> ParcRecherche:
	var p := ParcLoisirs.instance
	if p == null or not is_instance_valid(p):
		return null
	return p.recherche


## Ce projet est-il fini (ou la recherche n'existe-t-elle pas dans cette partie) ?
static func est_fait(id: String) -> bool:
	var r := instance()
	return r != null and r.faits.has(id)


## Une amélioration (par son effet) est-elle trouvée ?
static func a_effet(effet: String) -> bool:
	var r := instance()
	if r == null:
		return false
	for id in r.faits:
		if String(PROJETS.get(id, {}).get("effet", "")) == effet:
			return true
	return false


## Projet qui débloque ce bâtiment, ou "".
static func projet_de(type_id: String) -> String:
	var base := BuildingCatalog.base_of(type_id)
	for id in PROJETS:
		if (PROJETS[id].get("ids", []) as Array).has(base):
			return String(id)
	return ""


## Bâtiment verrouillé par la recherche ? (réglage de partie « recherche_parc »)
static func verrouille(type_id: String, r: ReglagesPartie = null) -> bool:
	if r == null:
		r = ReglagesPartie.actuel
	if r == null or not r.recherche_parc:
		return false
	var pid := projet_de(type_id)
	return pid != "" and not est_fait(pid)


## Raison du verrou de recherche, ou "".
static func raison_blocage(type_id: String, r: ReglagesPartie = null) -> String:
	if not verrouille(type_id, r):
		return ""
	return "À inventer d'abord : projet « %s » au bureau d'études du parc (Maj+G → Recherche)." % String(PROJETS[projet_de(type_id)].nom)


## Peut-on lancer ce projet (époque atteinte, projets requis finis) ?
func possible(id: String) -> bool:
	if not PROJETS.has(id) or faits.has(id):
		return false
	var p: Dictionary = PROJETS[id]
	if String(p.type) == "attraction" and not attractions_a_chercher():
		return false
	if Epoques.actif() and int(p.get("annee", 0)) > Epoques.annee():
		return false
	for q in p.get("requis", []):
		if not _requis_ok(String(q)):
			return false
	return true


func _requis_ok(q: String) -> bool:
	return faits.has(q) or (String(PROJETS.get(q, {}).get("type", "")) == "attraction" and not attractions_a_chercher())


## Pourquoi on ne peut pas (ou "").
func raison(id: String) -> String:
	if not PROJETS.has(id):
		return "Projet inconnu."
	if faits.has(id):
		return "Déjà trouvé."
	var p: Dictionary = PROJETS[id]
	if String(p.type) == "attraction" and not attractions_a_chercher():
		return "Posable d'office (réglage « Recherche des attractions » désactivé)."
	if Epoques.actif() and int(p.get("annee", 0)) > Epoques.annee():
		return "Trop tôt : pas avant %d." % int(p.annee)
	var manque: Array = []
	for q in p.get("requis", []):
		if not _requis_ok(String(q)):
			manque.append(String(PROJETS[String(q)].nom))
	if not manque.is_empty():
		return "Il faut d'abord : %s." % ", ".join(manque)
	return ""


func points_requis(id: String) -> float:
	return float(PROJETS.get(id, {}).get("points", 0))


## Lance un projet tout de suite (le projet en cours retourne en tête de file).
func lancer(id: String) -> bool:
	if not possible(id):
		return false
	if en_cours == id:
		return true
	file.erase(id)
	if en_cours != "":
		file.push_front(en_cours)
	en_cours = id
	return true


## Ajoute un projet à la file (ou le lance si rien n'est en cours).
func ajouter(id: String) -> bool:
	if not PROJETS.has(id) or faits.has(id) or file.has(id) or en_cours == id:
		return false
	if en_cours == "" and possible(id):
		en_cours = id
		return true
	if file.size() >= FILE_MAX:
		return false
	file.append(id)
	return true


func retirer(id: String) -> void:
	file.erase(id)
	if en_cours == id:
		en_cours = ""
		_suivant()


func set_budget(i: int) -> void:
	budget = clampi(i, 0, BUDGETS.size() - 1)


func cout_mois() -> float:
	return float(BUDGETS[budget])


## Points par jour au budget actuel (sans les visiteurs).
func points_jour() -> float:
	return cout_mois() / 30.44 / EUROS_POINT


## Jours restants pour le projet en cours (INF sans budget ni visiteurs).
func jours_restants(visiteurs_jour := 0.0) -> float:
	if en_cours == "":
		return 0.0
	var v := points_jour() + visiteurs_jour * POINTS_VISITEUR
	if v <= 0.0:
		return INF
	return maxf(0.0, points_requis(en_cours) - points) / v


## Un jour de recherche. Renvoie les projets finis ce jour-là.
func jour(visiteurs: float, jour_n: int) -> Array:
	var fini: Array = []
	var gain := points_jour() + visiteurs * POINTS_VISITEUR
	hier = gain
	if en_cours == "" or not possible(en_cours):
		if en_cours != "" and not possible(en_cours):
			file.push_front(en_cours)
			en_cours = ""
		_suivant()
	if en_cours == "":
		# Rien à chercher : les points attendent (au plus un gros projet d'avance).
		points = minf(points + gain, 200.0)
		return fini
	points += gain
	var garde := 0
	while en_cours != "" and points >= points_requis(en_cours) and garde < 10:
		garde += 1
		points -= points_requis(en_cours)
		faits[en_cours] = jour_n
		fini.append(en_cours)
		en_cours = ""
		_suivant()
	return fini


func _suivant() -> void:
	for i in file.size():
		var id := String(file[i])
		if possible(id):
			file.remove_at(i)
			en_cours = id
			return


## Les attractions sont-elles à inventer dans cette partie (réglage Admin) ?
static func attractions_a_chercher() -> bool:
	return ReglagesPartie.actuel != null and ReglagesPartie.actuel.recherche_parc


## Projets à proposer (pas finis), dans l'ordre historique. Sans le réglage,
## les attractions sont posables d'office : seules les améliorations restent.
func proposables() -> Array:
	var out: Array = []
	for id in ORDRE:
		if faits.has(id):
			continue
		if String(PROJETS[id].type) == "attraction" and not attractions_a_chercher():
			continue
		out.append(id)
	return out


func to_dict() -> Dictionary:
	return {"budget": budget, "points": snappedf(points, 0.01), "en_cours": en_cours, "file": file.duplicate(), "faits": faits.duplicate(),
		"hier": snappedf(hier, 0.01)}


func from_dict(d: Dictionary) -> void:
	budget = clampi(int(d.get("budget", 1)), 0, BUDGETS.size() - 1)
	points = float(d.get("points", 0.0))
	en_cours = String(d.get("en_cours", ""))
	if not PROJETS.has(en_cours):
		en_cours = ""
	file = (d.get("file", []) as Array).filter(func(x) -> bool: return PROJETS.has(String(x))).map(func(x) -> String: return String(x))
	faits = {}
	var f: Dictionary = d.get("faits", {})
	for k in f:
		if PROJETS.has(String(k)):
			faits[String(k)] = int(f[k])
	hier = float(d.get("hier", 0.0))
