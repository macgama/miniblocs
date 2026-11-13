class_name Effectif
extends RefCounted
## Le personnel des bâtiments et ce qu'il change.
##
## Pour chaque bâtiment qui a des emplois : postes prévus, employés embauchés,
## présents en ce moment, et l'état qui en découle :
## - fermé (personne d'embauché, ou il manque le métier indispensable : pas
##   d'enseignant à l'école, pas de médecin ni d'infirmier à l'hôpital, pas de
##   boulanger à la boulangerie…) ;
## - en sous-effectif (moins de la moitié des postes pourvus) ;
## - ouvert maintenant (un employé indispensable est à son poste).
##
## Conséquences (branchées dans Population et CycleVie) : les élèves d'une
## école fermée restent à la maison, les clients vont au commerce ouvert le
## plus proche (sinon pas de courses), les loisirs d'un lieu fermé se font à
## la maison, un hôpital fermé ne soigne personne (santé) et un hôpital en
## sous-effectif soigne moins bien, la satisfaction baisse.
##
## L'état « fermé » suit les embauches (stable dans la journée) ; « ouvert
## maintenant » suit les horaires (enseigne et rideau de fer de la vue métiers).

## Métiers indispensables : il en faut au moins un pour ouvrir. Clé = type,
## archétype ou catégorie du bâtiment (comme Metiers.PAR_BATIMENT).
const REQUIS := {
	"ecole": ["enseignant"],
	"hopital": ["medecin", "infirmier"],
	"clinique": ["medecin", "infirmier"],
	"boulangerie": ["boulanger"],
	"fournil": ["boulanger"],
	"cafe": ["serveur", "cuisinier"],
	"restaurant": ["cuisinier"],
	"pompiers": ["pompier"],
	"police": ["policier"],
	"cinema": ["agent_cinema"],
	"theatre": ["comedien"],
	"gare": ["agent_gare"],
	"gymnase": ["coach"],
	"piscine": ["coach"],
	"supermarche": ["caissier", "vendeur"],
	"superette": ["caissier", "vendeur"],
}

## En dessous de cette part de postes pourvus : « manque de personnel ».
const SOUS_EFFECTIF := 0.5
## Élèves par enseignant au-delà desquels les classes sont surchargées.
const ELEVES_PAR_PROF := 25

var pop: Population
var _etat: Dictionary = {}
var _signature := -1
## Signature de l'ensemble des bâtiments fermés (pour vider les caches des trajets).
var signature_fermes := 0


func _init(p: Population) -> void:
	pop = p


## Bâtiments concernés : ceux qui ont des emplois, sauf les logements.
func concerne(bid: int) -> bool:
	if not pop.known.has(bid):
		return false
	var info: Dictionary = pop.known[bid]
	return int(info.emp) > 0 and String(info.cat) != "logement"


static func requis_de(type_id: String) -> Array:
	for k in Metiers.keys_of(type_id):
		if REQUIS.has(k):
			return REQUIS[k]
	return []


## Recalcule si les embauches ont changé. Rend true si l'ensemble des
## bâtiments fermés a changé.
func actualiser(force := false) -> bool:
	var sig := pop.known.size() * 1000003
	for bid in pop.by_job:
		sig = sig * 31 + int(bid) * 7 + (pop.by_job[bid] as Array).size()
	if sig == _signature and not force:
		return false
	_signature = sig
	_etat.clear()
	var fermes := 0
	for bid in pop.known:
		if not concerne(bid):
			continue
		var e := _calcul(bid)
		_etat[bid] = e
		if bool(e.ferme):
			fermes = fermes * 31 + int(bid) + 1
	var changed := fermes != signature_fermes
	signature_fermes = fermes
	return changed


func _calcul(bid: int) -> Dictionary:
	var info: Dictionary = pop.known[bid]
	var staff: Array = pop.by_job.get(bid, [])
	var prevus := int(info.emp)
	var requis := requis_de(String(info.t))
	var par_metier := {}
	for pid in staff:
		if pop.persons.has(pid):
			var m := String(pop.persons[pid].met)
			par_metier[m] = int(par_metier.get(m, 0)) + 1
	var ferme := staff.is_empty()
	var raison := "aucun employé" if ferme else ""
	if not ferme and not requis.is_empty():
		var ok := false
		for m in requis:
			if par_metier.has(m):
				ok = true
		if not ok:
			ferme = true
			var noms := []
			for m in requis:
				var nom := String(Metiers.job(String(m)).name).to_lower()
				noms.append(("d'" if "aeiouéèêh".contains(nom.left(1)) else "de ") + nom)
			raison = "pas " + " ni ".join(noms)
	var taux := float(staff.size()) / maxf(1.0, float(prevus))
	return {"prevus": prevus, "embauches": staff.size(), "par_metier": par_metier, "requis": requis,
		"ferme": ferme, "raison": raison, "taux": taux, "manque": ferme or taux < SOUS_EFFECTIF}


## Les employés d'un bâtiment ont changé : son état sera recalculé.
func oublier(bid: int) -> void:
	_etat.erase(bid)


func etat(bid: int) -> Dictionary:
	if not concerne(bid):
		return {}
	actualiser()
	if not _etat.has(bid):
		_etat[bid] = _calcul(bid)
	return _etat[bid]


## Fermé faute de personnel ou pour grève (les habitants ne peuvent pas y aller).
func ferme(bid: int) -> bool:
	if en_greve(bid):
		return true
	var e := etat(bid)
	return not e.is_empty() and bool(e.ferme)


## Grève des agents (manifestation ignorée, scripts/avis) : bid -> fin (unix de jeu).
var greve: Dictionary = {}


func en_greve(bid: int) -> bool:
	if greve.is_empty() or not greve.has(bid):
		return false
	var t := pop.ambiance.unix_time if pop.ambiance != null else 0.0
	if t >= float(greve[bid]):
		greve.erase(bid)
		signature_fermes += 1
		return false
	return true


func manque(bid: int) -> bool:
	var e := etat(bid)
	return not e.is_empty() and bool(e.manque)


## Part des postes pourvus (1 si le bâtiment n'a pas d'emplois).
func taux(bid: int) -> float:
	var e := etat(bid)
	return 1.0 if e.is_empty() else float(e.taux)


## Employés à leur poste en ce moment.
func presents(bid: int) -> Array:
	var out := []
	for pid in pop.by_job.get(bid, []):
		if not pop.persons.has(pid):
			continue
		var a := pop.activity(pop.persons[pid])
		if int(a.bid) == bid and String(a.kind) == "travail":
			out.append(pid)
	return out


## Ouvert en ce moment : pas fermé, et un employé indispensable (ou n'importe
## lequel s'il n'y a pas de métier indispensable) est à son poste.
func ouvert_maintenant(bid: int) -> bool:
	var e := etat(bid)
	if e.is_empty():
		return false
	if bool(e.ferme):
		return false
	var req: Array = e.requis
	for pid in presents(bid):
		if req.is_empty() or req.has(String(pop.persons[pid].met)):
			return true
	return false


## Phrase pour les fiches : « Ouvert · 3 présents · 4 embauchés sur 6 postes ».
func resume(bid: int) -> String:
	var e := etat(bid)
	if e.is_empty():
		return ""
	var n := presents(bid).size()
	var etat_txt := "Fermé : %s" % String(e.raison) if bool(e.ferme) else ("Ouvert" if ouvert_maintenant(bid) else "Fermé pour l'instant (hors des horaires)")
	var txt := "%s · %d au travail maintenant · %d embauché%s sur %d poste%s" % [etat_txt, n, int(e.embauches),
		"s" if int(e.embauches) > 1 else "", int(e.prevus), "s" if int(e.prevus) > 1 else ""]
	if not bool(e.ferme) and bool(e.manque):
		txt += " · manque de personnel"
	return txt


## Conséquences en clair (fiche du bâtiment).
func consequences(bid: int) -> Array:
	var e := etat(bid)
	var out := []
	if e.is_empty():
		return out
	var keys := Metiers.keys_of(String(pop.known[bid].t))
	var info: Dictionary = pop.known[bid]
	if keys.has("ecole"):
		var eleves := (pop.by_school.get(bid, []) as Array).size()
		var profs := int((e.par_metier as Dictionary).get("enseignant", 0))
		if bool(e.ferme):
			out.append("Les %d élèves restent à la maison." % eleves)
		elif eleves > profs * ELEVES_PAR_PROF:
			out.append("Classes surchargées : %d élèves pour %d enseignant%s (%d au plus)." % [eleves, profs, "s" if profs > 1 else "", profs * ELEVES_PAR_PROF])
	elif keys.has("hopital") or keys.has("clinique"):
		if bool(e.ferme):
			out.append("Personne n'y est soigné : la santé des habitants baisse.")
		elif bool(e.manque):
			out.append("Soins ralentis : les habitants guérissent moins bien.")
	elif (info.serves as Array).has("shopping") or String(info.cat) == "commerce":
		if bool(e.ferme):
			out.append("Les clients vont ailleurs, ou ne font pas leurs courses.")
		elif bool(e.manque):
			out.append("Longues files d'attente : les clients sont moins satisfaits.")
	elif not (info.serves as Array).is_empty():
		if bool(e.ferme):
			out.append("Les habitants font leurs loisirs à la maison.")
	elif String(info.cat) in ["production", "industrie"]:
		out.append("Production à %d %% (selon les postes pourvus)." % roundi(clampf(float(e.taux), 0.0, 1.0) * 100.0))
	if keys.has("pompiers") or keys.has("police"):
		if bool(e.ferme):
			out.append("Aucun véhicule ne peut partir en intervention.")
	return out


## Pour les services d'urgence : la caserne ou le commissariat peut-il envoyer
## quelqu'un maintenant ? (un pompier ou policier présent)
func peut_intervenir(bid: int) -> bool:
	return ouvert_maintenant(bid)
