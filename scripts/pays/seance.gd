class_name Seance
extends Node
## Objectif de séance : un but clair pour environ 20 minutes de jeu, en trois
## paliers (bronze, argent, or) qui rapportent chacun une récompense visible.
##
## - Le but est choisi d'après ce dont la ville gérée a besoin maintenant (avis du
##   Conseiller, conditions du prochain rang des Objectifs) : remettre la caisse à
##   flot, créer des emplois, loger les habitants, remonter la satisfaction,
##   construire le service qui manque pour le rang suivant, ou accueillir des
##   habitants. Deux séances de suite évitent le même but.
## - Le temps compte en minutes réelles de jeu (pas pendant un menu en pause) ;
##   la séance dure DUREE secondes. Les trois paliers sont trois cibles de plus en
##   plus hautes sur la même mesure.
## - Chaque palier atteint : prime à la caisse de la ville (25 %, 25 %, 50 % de la
##   récompense), bannière au centre de l'écran, son « palier ». L'or rapporte en
##   plus un point de progrès (Maj+F10) et compte comme séance réussie.
## - Fin des 20 minutes : bilan (« 2 paliers sur 3 »), puis une nouvelle séance.
##   Or atteint avant la fin : le joueur peut en lancer une autre tout de suite.
## Signal palier_atteint(n, seance) : 1 à 3 (bannière, vol de caméra…).
##
## Sauvegarde : section « seance » (terre_main.save_sections).

signal changed
signal palier_atteint(n: int, s: Dictionary)
signal terminee(s: Dictionary)
signal message(text: String)

## Durée d'une séance (secondes de jeu réelles).
const DUREE := 20.0 * 60.0
const NOMS_PALIERS := ["Bronze", "Argent", "Or"]
## Clés de traduction propres aux médailles (« Argent » seul se traduit déjà par « Money »).
const CLES_PALIERS := ["médaille de bronze", "médaille d'argent", "médaille d'or"]
const COULEURS_PALIERS := [Color("d39a62"), Color("cfd8dc"), Color("ffd166")]
## Part de la récompense versée à chaque palier.
const PARTS := [0.25, 0.25, 0.5]
## Récompense de base d'une séance (€, × coût des constructions), plus par rang de la ville.
const PRIME_BASE := 60_000
const PRIME_RANG := 40_000
## Services du prochain rang qu'une séance peut demander de construire.
const SERVICES := ["ecole", "pompiers", "police", "hopital"]

static var instance: Seance


## Nom d'un palier (0 à 2) dans la langue du jeu : Bronze, Argent, Or / Silver…
## Les textes qui l'utilisent ne doivent plus être retraduits (auto_translate coupé).
static func nom_palier(i: int) -> String:
	if Langue.actuelle == "fr":
		return String(NOMS_PALIERS[i])
	return Langue.t(String(CLES_PALIERS[i]))

var objectifs: Objectifs
## Ville gérée : fonction qui renvoie son id (-1 : la ville principale).
var ville_courante: Callable
## Séance en cours : {type, ref, vid, titre, pourquoi, depart, cibles[3], atteints,
## prime, debut, fin_or} ; vide tant qu'aucune ville n'existe.
var courante := {}
## Secondes de jeu réelles écoulées depuis le lancement de la partie.
var ecoule := 0.0
var reussies := 0
var medailles := [0, 0, 0]
## Types des dernières séances (pour varier).
var derniers: Array = []
var actif := true
## Séance suspendue (tutoriel en cours, démo guidée) : le temps ne compte pas.
var bloque: Callable
var _tick := 0.0


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func setup(o: Objectifs) -> void:
	objectifs = o


func clear() -> void:
	courante = {}
	ecoule = 0.0
	reussies = 0
	medailles = [0, 0, 0]
	derniers = []
	changed.emit()


func _process(delta: float) -> void:
	if not actif or objectifs == null or objectifs.communes == null:
		return
	if get_tree() != null and get_tree().paused:
		return
	if suspendue():
		return
	ecoule += delta
	_tick += delta
	if _tick < 1.0:
		return
	_tick = 0.0
	suivre()


func suspendue() -> bool:
	return bloque.is_valid() and bool(bloque.call())


## Secondes restantes de la séance en cours.
func restant() -> float:
	if courante.is_empty():
		return DUREE
	return maxf(0.0, float(courante.debut) + DUREE - ecoule)


func texte_restant() -> String:
	var s := roundi(restant())
	if s >= 60:
		return "%d min" % ceili(s / 60.0)
	return "%d s" % s


func vid() -> int:
	var v := -1
	if ville_courante.is_valid():
		v = int(ville_courante.call())
	if objectifs == null or objectifs.communes == null:
		return -1
	if not objectifs.communes.villages.has(v):
		v = objectifs.communes.principal()
	return v


## Suivi (chaque seconde) : lance la séance, compte les paliers, finit au bout du temps.
func suivre() -> void:
	if objectifs.communes.villages.is_empty():
		return
	if courante.is_empty() or not objectifs.communes.villages.has(int(courante.vid)):
		nouvelle()
		return
	var n := paliers_mesures()
	while int(courante.atteints) < n:
		_gagner(int(courante.atteints) + 1)
	if restant() <= 0.0:
		finir()


## Nombre de paliers que la mesure actuelle atteint (0 à 3).
func paliers_mesures() -> int:
	if courante.is_empty():
		return 0
	var m := mesure(String(courante.type), int(courante.vid), String(courante.get("ref", "")))
	var n := 0
	for c in courante.cibles:
		if m >= float(c) - 0.0001:
			n += 1
		else:
			break
	return n


## Progrès vers le prochain palier (0 à 1), pour la barre.
func progres() -> float:
	if courante.is_empty():
		return 0.0
	var a := int(courante.atteints)
	if a >= 3:
		return 1.0
	var m := mesure(String(courante.type), int(courante.vid), String(courante.get("ref", "")))
	var bas := float(courante.depart) if a == 0 else float(courante.cibles[a - 1])
	var haut := float(courante.cibles[a])
	if haut <= bas:
		return 1.0
	return clampf((m - bas) / (haut - bas), 0.0, 1.0)


## Où en est la mesure, en mots (« 12 / 40 habitants »).
func texte_progres() -> String:
	if courante.is_empty():
		return ""
	var t := String(courante.type)
	var m := mesure(t, int(courante.vid), String(courante.get("ref", "")))
	var a := mini(int(courante.atteints), 2)
	var cible := float(courante.cibles[a])
	match t:
		"habitants", "emplois", "logements":
			var unite: String = {"habitants": "habitants", "emplois": "emplois", "logements": "logements"}[t]
			return "%d / %d %s" % [maxi(0, roundi(m - float(courante.depart))), roundi(cible - float(courante.depart)), unite]
		"satisfaction":
			return "satisfaction %d → %d" % [roundi(m), roundi(cible)]
		"caisse":
			return "caisse %s → %s" % [BuildingSystem.format_short(roundi(m)), BuildingSystem.format_short(roundi(cible))]
		"batiment":
			if m <= 0.0:
				return "pas encore posé"
			if m >= 2.0:
				return "terminé"
			return "chantier à %d %%" % roundi((m - 1.0) * 100.0)
	return ""


## Ce que le palier n demande, en mots.
func texte_palier(n: int) -> String:
	if courante.is_empty() or n < 1 or n > 3:
		return ""
	var t := String(courante.type)
	var c := float(courante.cibles[n - 1])
	var d := float(courante.depart)
	match t:
		"habitants":
			return "+%d habitants" % roundi(c - d)
		"emplois":
			return "+%d emplois" % roundi(c - d)
		"logements":
			return "+%d logements" % roundi(c - d)
		"satisfaction":
			return "satisfaction %d" % roundi(c)
		"caisse":
			return "caisse à %s" % BuildingSystem.format_short(roundi(c))
		"batiment":
			return ["chantier posé", "à moitié construit", "ouvert"][n - 1]
	return ""


# --- Mesures ---------------------------------------------------------------------------

func mesure(t: String, v: int, ref := "") -> float:
	var cm := objectifs.communes
	var st: Dictionary = cm.stats.get(v, {})
	match t:
		"habitants":
			return float(st.get("hab", 0))
		"emplois":
			return float(st.get("emplois", 0))
		"logements":
			return float(st.get("logements", 0))
		"satisfaction":
			return float(objectifs.satisfaction(v))
		"caisse":
			return float(objectifs.pays.solde(v)) if objectifs.pays != null else 0.0
		"batiment":
			return avancement_service(v, ref)
	return 0.0


## 0 : aucun ; 1 à 2 : chantier posé, selon son avancement ; 2 : ouvert.
func avancement_service(v: int, type_id: String) -> float:
	if objectifs.compter(v, type_id) > 0:
		return 2.0
	var bs := objectifs.buildings
	var vie := BatimentsVie.instance
	var best := 0.0
	if bs == null:
		return 0.0
	for bid in bs.buildings:
		var b: Dictionary = bs.buildings[bid]
		if not b.get("chantier", false) or BuildingCatalog.base_of(String(b.t)) != type_id:
			continue
		if objectifs.communes.village_de(bid) != v:
			continue
		var av := vie.progress(bid) if vie != null else float(b.get("av", 0.0))
		best = maxf(best, 1.0 + clampf(av, 0.0, 0.999))
	return best


# --- Choix du but ----------------------------------------------------------------------

## Lance une nouvelle séance pour la ville gérée.
func nouvelle() -> void:
	var v := vid()
	if v < 0:
		return
	objectifs.communes.calculer_stats()
	var c := choisir(v)
	c.vid = v
	c.debut = ecoule
	c.atteints = 0
	c.depart = mesure(String(c.type), v, String(c.get("ref", "")))
	c.cibles = cibles(String(c.type), float(c.depart), v)
	var rang := objectifs.palier_de(v)
	c.prime = ReglagesPartie.prix(PRIME_BASE + PRIME_RANG * rang)
	courante = c
	derniers.push_front(String(c.type))
	derniers = derniers.slice(0, 3)
	message.emit("Nouvel objectif de séance : %s (20 min, 3 paliers)." % String(c.titre))
	changed.emit()


## Le but de la séance : {type, ref, titre, pourquoi}.
func choisir(v: int) -> Dictionary:
	var ids := {}
	var st := Statistiques.instance
	if st != null:
		for a in Conseiller.analyser(st, str(v)):
			if int(a.gravite) >= 1:
				ids[String(a.id)] = int(a.gravite)
	var hab := int(objectifs.communes.stats.get(v, {}).get("hab", 0))
	var dernier := String(derniers[0]) if not derniers.is_empty() else ""
	var propositions: Array = []
	if objectifs.pays != null and objectifs.pays.solde(v) < 0:
		propositions.append({"type": "caisse", "titre": "Remettre la caisse à flot",
			"pourquoi": "La caisse de la ville est dans le rouge : sans argent, les chantiers s'arrêtent."})
	if ids.has("chomage"):
		propositions.append({"type": "emplois", "titre": "Créer des emplois",
			"pourquoi": "Trop d'habitants cherchent du travail."})
	if ids.has("logements"):
		propositions.append({"type": "logements", "titre": "Loger les nouveaux venus",
			"pourquoi": "Plus un logement libre alors que des emplois attendent."})
	if (ids.has("colere") or ids.has("grogne")) and hab >= 50:
		propositions.append({"type": "satisfaction", "titre": "Rendre le sourire aux habitants",
			"pourquoi": "La satisfaction baisse : l'avis des habitants (Y) dit pourquoi."})
	# Service qui manque pour le rang suivant (ou une école réclamée par le Conseiller).
	var manque := ""
	if ids.has("ecole") and objectifs.compter(v, "ecole") == 0:
		manque = "ecole"
	else:
		var i := objectifs.palier_de(v) + 1
		if i < Objectifs.PALIERS.size():
			for cnd in Objectifs.PALIERS[i].cond:
				if SERVICES.has(String(cnd)) and not objectifs.condition(v, String(cnd)):
					manque = String(cnd)
					break
	if manque != "":
		var rang_suivant := String(Objectifs.PALIERS[mini(objectifs.palier_de(v) + 1, Objectifs.PALIERS.size() - 1)].nom)
		propositions.append({"type": "batiment", "ref": manque,
			"titre": "Ouvrir %s" % String(Objectifs.COND_NOMS.get(manque, manque)),
			"pourquoi": "Il en faut pour devenir %s." % rang_suivant})
	propositions.append({"type": "habitants", "titre": "Faire grandir la ville",
		"pourquoi": "Plus d'habitants, plus d'impôts, et le prochain rang se rapproche."})
	if hab >= 30:
		propositions.append({"type": "emplois", "titre": "Créer des emplois",
			"pourquoi": "De nouveaux emplois attirent de nouveaux habitants."})
	else:
		propositions.append({"type": "logements", "titre": "Bâtir les premières maisons",
			"pourquoi": "Chaque maison finie loge une famille et fait vivre le village."})
	# Le plus pressant d'abord, mais pas deux fois de suite le même but.
	for p in propositions:
		if String(p.type) != dernier:
			return p
	return propositions[0]


## Trois cibles croissantes, réglées pour être à portée en 20 minutes.
func cibles(t: String, depart: float, v: int) -> Array:
	var hab := float(objectifs.communes.stats.get(v, {}).get("hab", 0))
	var total := 0.0
	match t:
		"habitants":
			total = _rond(clampf(hab * 0.15, 20.0, 3000.0))
		"emplois":
			total = _rond(clampf(hab * 0.08, 10.0, 1500.0))
		"logements":
			total = _rond(clampf(hab * 0.05, 8.0, 1000.0))
		"satisfaction":
			var but := clampf(depart + 6.0, 50.0, 90.0)
			return [roundf(lerpf(depart, but, 1.0 / 3.0)), roundf(lerpf(depart, but, 2.0 / 3.0)), roundf(but)]
		"caisse":
			# Du rouge vers zéro, par tiers.
			if depart < 0.0:
				return [roundf(depart * 2.0 / 3.0), roundf(depart / 3.0), 0.0]
			return [depart + 50_000.0, depart + 100_000.0, depart + 200_000.0]
		"batiment":
			return [1.0, 1.5, 2.0]
	return [depart + roundf(total / 3.0), depart + roundf(total * 2.0 / 3.0), depart + total]


static func _rond(v: float) -> float:
	var pas := 5.0 if v < 100.0 else (10.0 if v < 500.0 else 50.0)
	return maxf(pas, roundf(v / pas) * pas)


# --- Récompenses -----------------------------------------------------------------------

func prime_du_palier(n: int) -> int:
	if courante.is_empty() or n < 1 or n > 3:
		return 0
	return roundi(float(courante.prime) * float(PARTS[n - 1]))


func _gagner(n: int) -> void:
	courante.atteints = n
	medailles[n - 1] = int(medailles[n - 1]) + 1
	var prime := prime_du_palier(n)
	var v := int(courante.vid)
	var p := objectifs.pays
	if p != null and prime > 0 and not p.illimite():
		# La récompense va dans la caisse de la ville de la séance.
		var garde := Pays.a_la_caisse(v)
		if objectifs.buildings != null:
			objectifs.buildings.money += prime
		Pays.retour(garde)
	var txt := "Palier %s atteint : %s ! +%s" % [String(NOMS_PALIERS[n - 1]).to_lower(), String(courante.titre), BuildingSystem.format_money(prime)]
	if n == 3:
		reussies += 1
		courante.fin_or = ecoule
		ArbreProgression.gagner(ReglagesPartie.actuel, 1, "Séance réussie : %s" % String(courante.titre))
		txt += " et 1 point de progrès (Maj+F10)"
	Son.jouer("palier")
	message.emit(txt + ".")
	palier_atteint.emit(n, courante)
	changed.emit()


## Fin de la séance (temps écoulé, ou le joueur en veut une autre) : bilan puis suivante.
func finir() -> void:
	if courante.is_empty():
		return
	var a := int(courante.atteints)
	var bilan := "Séance terminée : %d palier%s sur 3" % [a, "s" if a > 1 else ""]
	if a == 0:
		bilan += ". Pas de médaille cette fois, la prochaine sera la bonne."
	else:
		bilan += " (%s)." % String(NOMS_PALIERS[a - 1]).to_lower()
	message.emit(bilan)
	terminee.emit(courante)
	courante = {}
	nouvelle()


## Or déjà gagné : le joueur lance la séance suivante sans attendre.
func suivante() -> void:
	if not courante.is_empty() and int(courante.atteints) >= 3:
		courante = {}
		nouvelle()


func to_dict() -> Dictionary:
	return {"courante": courante.duplicate(true), "ecoule": ecoule, "reussies": reussies,
		"medailles": medailles.duplicate(), "derniers": derniers.duplicate()}


func from_dict(d: Dictionary) -> void:
	courante = (d.get("courante", {}) as Dictionary).duplicate(true)
	if courante.has("vid"):
		courante.vid = int(courante.vid)
		courante.atteints = int(courante.get("atteints", 0))
	ecoule = float(d.get("ecoule", 0.0))
	reussies = int(d.get("reussies", 0))
	var m: Array = d.get("medailles", [0, 0, 0])
	medailles = [int(m[0]), int(m[1]), int(m[2])] if m.size() >= 3 else [0, 0, 0]
	derniers = (d.get("derniers", []) as Array).duplicate()
	changed.emit()
