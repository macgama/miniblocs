class_name ModeStreamer
extends Node
## Mode streamer : le chat Twitch influence la ville.
##
## - Votes à intervalle régulier : trois propositions (catastrophes, décisions du
##   maire, météo, fêtes) ; les spectateurs tapent 1, 2 ou 3 dans le chat.
##   Une voix par spectateur (la dernière compte). Le streamer garde un délai
##   pour annuler le résultat avant qu'il s'applique.
## - « !habitant » : le pseudo du spectateur est donné au prochain habitant qui
##   naît ou arrive en ville ; le panneau dit où vivent les habitants du chat.
## - Le streamer et ses modérateurs peuvent taper « !vote » pour lancer un vote.
##
## Désactivé par défaut. Les réglages (chaîne, rythme, catégories) appartiennent
## au joueur, pas à la partie : user://streamer.cfg. La file des pseudos et les
## habitants du chat sont dans la sauvegarde (section « streamer »).
## Lecture du chat : TwitchChat (anonyme, lecture seule, sans clé).
## Voir docs/streamer.md.

signal changed
signal message(texte: String)
## Un vote commence, se termine (résultat en attente) ou s'applique.
signal vote_change

static var instance: ModeStreamer

const FICHIER := "user://streamer.cfg"
const CATEGORIES := {
	"catastrophes": "Catastrophes",
	"maire": "Décisions du maire",
	"meteo": "Météo",
	"fetes": "Fêtes et marchés",
}
## Propositions possibles. cat : catégorie ; icone : Icones.
const ACTIONS := {
	"incendie": {"nom": "Un incendie", "cat": "catastrophes", "icone": "feu"},
	"tempete": {"nom": "Une tempête", "cat": "catastrophes", "icone": "tempete"},
	"epidemie": {"nom": "Une épidémie", "cat": "catastrophes", "icone": "epidemie"},
	"crue": {"nom": "Une crue", "cat": "catastrophes", "icone": "eau"},
	"impots_hausse": {"nom": "Hausser la taxe foncière (+10 %)", "cat": "maire", "icone": "budget"},
	"impots_baisse": {"nom": "Baisser la taxe foncière (−10 %)", "cat": "maire", "icone": "budget"},
	"entretien_plus": {"nom": "Plus d'entretien des routes (+25 %)", "cat": "maire", "icone": "route"},
	"soleil": {"nom": "Grand soleil", "cat": "meteo", "icone": "soleil"},
	"pluie": {"nom": "La pluie", "cat": "meteo", "icone": "eau"},
	"orage": {"nom": "Un gros orage", "cat": "meteo", "icone": "tempete"},
	"neige": {"nom": "La neige", "cat": "meteo", "icone": "neige"},
	"brouillard": {"nom": "Le brouillard", "cat": "meteo", "icone": "oeil"},
	"fete": {"nom": "Une fête de quartier (payée par la ville)", "cat": "fetes", "icone": "fete"},
	"marche": {"nom": "Un marché (payé par la ville)", "cat": "fetes", "icone": "marche"},
	"calme": {"nom": "Rien, laissez-les tranquilles", "cat": "", "icone": "pause"},
}
const METEO := {"soleil": Meteo.Mode.SOLEIL, "pluie": Meteo.Mode.PLUIE, "orage": Meteo.Mode.ORAGE,
	"neige": Meteo.Mode.NEIGE, "brouillard": Meteo.Mode.BROUILLARD}
## Heures de jeu pendant lesquelles la météo votée reste forcée.
const METEO_HEURES := 6.0
const INTERVALLES := [2, 3, 5, 10, 15]
const DUREES := [30, 45, 60, 90, 120]
const DELAIS_VETO := [0, 5, 10, 20]
const PSEUDOS_MAX := 300
## Comptes de robots du chat, ignorés.
const ROBOTS := ["nightbot", "streamelements", "streamlabs", "moobot", "fossabot", "wizebot", "soundalerts", "sery_bot", "botrixoficial"]

# --- Réglages du joueur (user://streamer.cfg) ---------------------------------------------
var actif := false
var chaine := ""
## Minutes réelles entre deux votes (0 : seulement à la main ou par « !vote »).
var intervalle := 3
## Durée d'un vote, secondes réelles.
var duree := 60
## Secondes laissées au streamer pour annuler le résultat.
var delai_veto := 10
var categories := {"catastrophes": true, "maire": true, "meteo": true, "fetes": true}
var noms_habitants := true
var commande_vote_mods := true
## Faux spectateurs pour essayer sans Twitch.
var simulation := false
var fichier := FICHIER

# --- Partie ------------------------------------------------------------------------------
var evenements: Evenements
var population: Population
var rig: Node3D
var chat: TwitchChat
var rng := RandomNumberGenerator.new()

## Vote en cours : {options: [ids], voix: {pseudo: index}, fin: s, etat: "ouvert"|"resultat"} ou vide.
var vote: Dictionary = {}
## Dernier résultat appliqué : {action, voix, total}.
var dernier: Dictionary = {}
var historique: Array = []
## Pseudos en attente d'un habitant (affichage du chat).
var file_noms: Array = []
## pid -> pseudo des habitants nommés par le chat.
var habitants_chat: Dictionary = {}
var votes_faits := 0
var _avant_vote := 0.0
var _meteo_fin := -1.0
var _sim_t := 0.0
var _horloge := 0.0
var _deja_vus: Dictionary = {}


func _init() -> void:
	rng.randomize()


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null
	if population != null and population.prenom_impose.is_valid() and population.prenom_impose.get_object() == self:
		population.prenom_impose = Callable()


func setup(ev: Evenements, pop: Population, r: Node3D) -> void:
	evenements = ev
	population = pop
	rig = r
	chat = TwitchChat.new()
	chat.name = "TwitchChat"
	add_child(chat)
	chat.message_recu.connect(recevoir)
	chat.etat_change.connect(func(_e: String) -> void: changed.emit())
	if population != null:
		population.prenom_impose = _prenom_pour
	charger_reglages()
	_avant_vote = intervalle * 60.0
	if actif and not chaine.is_empty():
		chat.connecter(chaine)


# --- Réglages -----------------------------------------------------------------------------

func charger_reglages() -> void:
	var cf := ConfigFile.new()
	if cf.load(fichier) != OK:
		return
	actif = bool(cf.get_value("streamer", "actif", false))
	chaine = String(cf.get_value("streamer", "chaine", ""))
	intervalle = int(cf.get_value("streamer", "intervalle", 3))
	duree = int(cf.get_value("streamer", "duree", 60))
	delai_veto = int(cf.get_value("streamer", "delai_veto", 10))
	noms_habitants = bool(cf.get_value("streamer", "noms_habitants", true))
	commande_vote_mods = bool(cf.get_value("streamer", "commande_vote_mods", true))
	for c in CATEGORIES:
		categories[c] = bool(cf.get_value("categories", c, true))


func enregistrer_reglages() -> void:
	var cf := ConfigFile.new()
	cf.set_value("streamer", "actif", actif)
	cf.set_value("streamer", "chaine", chaine)
	cf.set_value("streamer", "intervalle", intervalle)
	cf.set_value("streamer", "duree", duree)
	cf.set_value("streamer", "delai_veto", delai_veto)
	cf.set_value("streamer", "noms_habitants", noms_habitants)
	cf.set_value("streamer", "commande_vote_mods", commande_vote_mods)
	for c in CATEGORIES:
		cf.set_value("categories", c, bool(categories.get(c, true)))
	cf.save(fichier)


## Allume ou éteint le mode streamer (et la connexion au chat).
func activer(on: bool, nom_chaine := "") -> void:
	if nom_chaine != "":
		chaine = TwitchChat.nettoyer_chaine(nom_chaine)
	actif = on
	if on:
		_avant_vote = intervalle * 60.0
		if not chaine.is_empty():
			chat.connecter(chaine)
		message.emit("Mode streamer allumé%s." % ("" if chaine.is_empty() else " : chat de twitch.tv/" + chaine))
	else:
		chat.deconnecter()
		vote = {}
		simulation = false
		message.emit("Mode streamer éteint.")
	enregistrer_reglages()
	changed.emit()
	vote_change.emit()


func set_intervalle(m: int) -> void:
	intervalle = maxi(m, 0)
	_avant_vote = intervalle * 60.0
	enregistrer_reglages()
	changed.emit()


func etat_texte() -> String:
	if not actif:
		return "Mode éteint"
	if simulation and not chat.est_connecte():
		return "Chat simulé"
	if chaine.is_empty():
		return "Aucune chaîne"
	var t: String = TwitchChat.ETATS.get(chat.etat, chat.etat)
	if chat.etat == "erreur" and chat.derniere_erreur != "":
		t += " : " + chat.derniere_erreur
	return t


## Les votes ne s'appliquent qu'en solo : sur une carte partagée, les autres
## joueurs n'ont pas à subir le chat d'un seul streamer.
func partage() -> bool:
	return Multijoueur.role != Multijoueur.Role.SOLO


# --- Messages du chat ---------------------------------------------------------------------

## Un message du chat (Twitch ou simulé).
func recevoir(pseudo: String, nom: String, texte: String, tags: Dictionary = {}) -> void:
	if not actif:
		return
	var p := pseudo.to_lower()
	if p in ROBOTS:
		return
	var t := texte.strip_edges()
	if t.length() > 200:
		return
	var bas := t.to_lower()
	if bas == "!vote" and commande_vote_mods and (TwitchChat.est_moderateur(tags) or p == chaine):
		if vote.is_empty():
			lancer_vote()
		return
	if bas == "!habitant" or bas == "!citizen":
		ajouter_pseudo(nom if nom != "" else pseudo)
		return
	if vote.is_empty() or String(vote.etat) != "ouvert":
		return
	var n := _numero(bas)
	if n >= 1 and n <= (vote.options as Array).size():
		vote.voix[p] = n - 1
		vote_change.emit()


static func _numero(t: String) -> int:
	var s := t.trim_prefix("!vote").trim_prefix("!").strip_edges()
	if s.length() == 1 and s >= "1" and s <= "9":
		return int(s)
	return -1


func ajouter_pseudo(pseudo: String) -> bool:
	if not noms_habitants:
		return false
	var nom := nom_habitant(pseudo)
	if nom.is_empty():
		return false
	var cle := nom.to_lower()
	if _deja_vus.has(cle) or file_noms.size() >= PSEUDOS_MAX:
		return false
	_deja_vus[cle] = true
	file_noms.append(nom)
	changed.emit()
	return true


## Pseudo → prénom présentable : « xx_marie_42 » → « Marie_42 » (lettres, chiffres, _ et -).
static func nom_habitant(pseudo: String) -> String:
	var s := ""
	for ch in pseudo.strip_edges():
		if ch.is_valid_identifier() or (ch >= "0" and ch <= "9") or ch == "-" or ch.unicode_at(0) > 127:
			s += ch
	s = s.lstrip("_-").substr(0, 20)
	if s.is_empty():
		return ""
	return s[0].to_upper() + s.substr(1)


## Branché sur Population.prenom_impose : prochain pseudo de la file.
func _prenom_pour(_sexe: String, _age: float, _role: String) -> String:
	if not actif or not noms_habitants or file_noms.is_empty():
		return ""
	return String(file_noms.pop_front())


## Appelé par Population après la création d'un habitant nommé par le chat.
func habitant_nomme(pid: int, prenom: String) -> void:
	var p: Dictionary = population.persons.get(pid, {}) if population != null else {}
	if p.is_empty():
		return
	habitants_chat[pid] = prenom
	if evenements != null:
		var bid := population.home_of(p)
		var ou := population.building_name(bid) if bid >= 0 else ""
		evenements.news("%s, du chat, %s%s." % [prenom, "vient de naître" if population.age_of(p) < 1.0 else "s'installe en ville",
			"" if ou.is_empty() else " (" + ou + ")"], Vector3.INF, "streamer")
	changed.emit()


## Habitants du chat encore en ville : [{pid, nom, age, logement, bid}].
func liste_habitants() -> Array:
	var out := []
	if population == null:
		return out
	for pid in habitants_chat.keys():
		var p: Dictionary = population.persons.get(int(pid), {})
		if p.is_empty():
			continue
		var bid := population.home_of(p)
		out.append({"pid": int(pid), "nom": "%s %s" % [p.p, p.n], "age": population.age_of(p),
			"logement": population.building_name(bid) if bid >= 0 else "", "bid": bid})
	return out


# --- Votes --------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_horloge += delta
	if not actif:
		return
	if simulation:
		_simuler(delta)
	_fin_meteo()
	if vote.is_empty():
		if intervalle > 0:
			_avant_vote -= delta
			if _avant_vote <= 0.0:
				lancer_vote()
		return
	if _horloge >= float(vote.fin):
		if String(vote.etat) == "ouvert":
			_clore()
		else:
			appliquer_resultat()


func secondes_avant_vote() -> float:
	return maxf(_avant_vote, 0.0)


func secondes_restantes() -> float:
	return maxf(float(vote.get("fin", 0.0)) - _horloge, 0.0) if not vote.is_empty() else 0.0


## Propositions disponibles maintenant, selon les catégories cochées.
func propositions() -> Array:
	var out := []
	for id in ACTIONS:
		var cat := String(ACTIONS[id].cat)
		if cat != "" and not bool(categories.get(cat, false)):
			continue
		if id == "crue" and Saisons.instance == null:
			continue
		if (id == "impots_hausse" or id == "impots_baisse" or id == "entretien_plus") and not _budget_ok():
			continue
		if id == String(dernier.get("action", "")) and id != "calme":
			continue
		out.append(id)
	return out


func _budget_ok() -> bool:
	var b := BudgetCommunal.instance
	return b != null and b.joueur_decide()


## Tire trois propositions de catégories différentes si possible.
func tirer_options(n := 3) -> Array:
	var dispo := propositions()
	dispo.erase("calme")
	var par_cat := {}
	for id in dispo:
		var c := String(ACTIONS[id].cat)
		if not par_cat.has(c):
			par_cat[c] = []
		(par_cat[c] as Array).append(id)
	var cats := par_cat.keys()
	_melanger(cats)
	var out := []
	for c in cats:
		if out.size() >= n - 1:
			break
		var l: Array = par_cat[c]
		out.append(l[rng.randi() % l.size()])
	var reste := dispo.filter(func(x) -> bool: return not out.has(x))
	_melanger(reste)
	while out.size() < n - 1 and not reste.is_empty():
		out.append(reste.pop_back())
	# Une porte de sortie : le chat peut toujours choisir la paix.
	out.append("calme")
	return out


func _melanger(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var x = a[i]
		a[i] = a[j]
		a[j] = x


func lancer_vote(options: Array = []) -> bool:
	if not actif or not vote.is_empty():
		return false
	if partage():
		message.emit("Les votes du chat sont réservés aux parties en solo.")
		return false
	if options.is_empty():
		options = tirer_options()
	if options.size() < 2:
		message.emit("Pas assez de propositions : coche au moins une catégorie.")
		return false
	vote = {"options": options, "voix": {}, "fin": _horloge + float(duree), "etat": "ouvert", "gagnant": -1}
	_avant_vote = intervalle * 60.0
	if evenements != null:
		var noms := []
		for i in options.size():
			noms.append("%d. %s" % [i + 1, nom_action(String(options[i]))])
		evenements.news("Le chat vote : " + " · ".join(noms), Vector3.INF, "streamer")
	vote_change.emit()
	return true


static func nom_action(id: String) -> String:
	return String(ACTIONS.get(id, {}).get("nom", id))


## Voix par option : [n, n, n].
func decompte() -> Array:
	var c := []
	if vote.is_empty():
		return c
	c.resize((vote.options as Array).size())
	c.fill(0)
	for p in vote.voix:
		c[int(vote.voix[p])] += 1
	return c


func _clore() -> void:
	var c := decompte()
	var total := 0
	var best := -1
	var ex := []
	for i in c.size():
		total += int(c[i])
		if best < 0 or int(c[i]) > int(c[best]):
			best = i
			ex = [i]
		elif int(c[i]) == int(c[best]):
			ex.append(i)
	if total == 0:
		message.emit("Personne n'a voté dans le chat : la ville respire.")
		vote = {}
		vote_change.emit()
		return
	var g: int = ex[rng.randi() % ex.size()]
	vote.gagnant = g
	vote.total = total
	vote.etat = "resultat"
	vote.fin = _horloge + float(delai_veto)
	message.emit("Le chat a choisi : %s (%d voix sur %d)." % [nom_action(String(vote.options[g])), int(c[g]), total])
	vote_change.emit()
	if delai_veto <= 0:
		appliquer_resultat()


## Le streamer annule le résultat (ou le vote en cours).
func annuler() -> void:
	if vote.is_empty():
		return
	if evenements != null:
		evenements.news("Le maire a mis son veto au vote du chat.", Vector3.INF, "streamer")
	vote = {}
	vote_change.emit()


## Termine tout de suite le vote en cours (bouton « Clore »).
func clore_maintenant() -> void:
	if not vote.is_empty() and String(vote.etat) == "ouvert":
		vote.fin = _horloge
		_clore()


func appliquer_resultat() -> void:
	if vote.is_empty() or int(vote.get("gagnant", -1)) < 0:
		vote = {}
		vote_change.emit()
		return
	var id := String(vote.options[int(vote.gagnant)])
	var c := decompte()
	var ok := appliquer(id)
	dernier = {"action": id, "voix": int(c[int(vote.gagnant)]), "total": int(vote.total), "ok": ok}
	historique.push_front(dernier.duplicate())
	if historique.size() > 30:
		historique.resize(30)
	votes_faits += 1
	vote = {}
	vote_change.emit()
	changed.emit()


## Applique une proposition. Renvoie false si rien n'a pu se faire.
func appliquer(id: String) -> bool:
	var ev := evenements
	var ok := false
	match id:
		"incendie":
			ok = ev != null and ev.incendies.start_random() >= 0
		"tempete", "epidemie":
			ok = ev != null and ev.declencher(id) >= 0
		"crue":
			ok = Saisons.instance != null and Saisons.instance.declencher_crue(2) >= 0
		"impots_hausse", "impots_baisse":
			var b := BudgetCommunal.instance
			if b != null and b.joueur_decide():
				var avant := float(b.taux.foncier)
				b.set_taux("foncier", avant + (0.1 if id == "impots_hausse" else -0.1))
				ok = not is_equal_approx(avant, float(b.taux.foncier))
		"entretien_plus":
			var b2 := BudgetCommunal.instance
			if b2 != null and b2.joueur_decide():
				var avant2 := float(b2.entretien.get("route", {}).get("taux", 1.0))
				b2.set_entretien("route", "taux", avant2 * 1.25)
				ok = float(b2.entretien.get("route", {}).get("taux", 1.0)) > avant2
		"soleil", "pluie", "orage", "neige", "brouillard":
			var w := _meteo()
			if w != null:
				w.mode = METEO[id]
				_meteo_fin = ev.now() + METEO_HEURES * 3600.0 if ev != null else -1.0
				ok = true
		"fete", "marche":
			if ev != null and rig != null:
				var p := rig.global_position
				ok = ev.fetes.organiser(id, Vector3(p.x, ev.ground(p.x, p.z), p.z)) >= 0
		"calme":
			ok = true
	var texte := "Le chat a voté : %s." % nom_action(id)
	if not ok:
		texte = "Le chat a voté : %s… mais rien ne s'est passé." % nom_action(id)
	if id == "calme":
		texte = "Le chat a voté pour le calme : rien ne se passe."
	if ev != null:
		ev.news(texte, Vector3.INF, "streamer")
	message.emit(texte)
	return ok


func _meteo() -> Meteo:
	if evenements != null and evenements.ambiance != null:
		return evenements.ambiance.weather
	return null


func _fin_meteo() -> void:
	if _meteo_fin < 0.0 or evenements == null:
		return
	if evenements.now() >= _meteo_fin:
		_meteo_fin = -1.0
		var w := _meteo()
		if w != null:
			w.mode = Meteo.Mode.AUTO


# --- Chat simulé (essais sans Twitch) -----------------------------------------------------

const FAUX := ["Marie_42", "LeoDu74", "pixel_mamie", "Kevin2Lyon", "CaptainTartiflette", "zoe_builds", "Gros_Minet", "NadiaPlays",
	"BaguetteMaster", "lucas_tv", "Mme_Patate", "ArchiTom", "sunny_ch", "Rafa_Geneve", "BlobLeChat", "Maxou"]


func simuler(on: bool) -> void:
	simulation = on
	_sim_t = 0.0
	changed.emit()


func _simuler(delta: float) -> void:
	_sim_t -= delta
	if _sim_t > 0.0:
		return
	_sim_t = rng.randf_range(0.4, 1.6)
	var qui: String = FAUX[rng.randi() % FAUX.size()]
	if not vote.is_empty() and String(vote.etat) == "ouvert":
		# Le chat a ses préférences : la première proposition plaît un peu plus.
		var n := (vote.options as Array).size()
		var choix := 1 if rng.randf() < 0.4 else 1 + rng.randi() % n
		recevoir(qui.to_lower(), qui, str(choix))
	elif rng.randf() < 0.15:
		recevoir(qui.to_lower(), qui, "!habitant")


# --- Sauvegarde ---------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var hc := {}
	for pid in habitants_chat:
		hc[str(pid)] = habitants_chat[pid]
	return {"file": file_noms.duplicate(), "habitants": hc, "votes": votes_faits, "historique": historique.slice(0, 10)}


func from_dict(d: Dictionary) -> void:
	clear()
	file_noms = Array(d.get("file", []))
	for k in file_noms:
		_deja_vus[String(k).to_lower()] = true
	var hc: Dictionary = d.get("habitants", {})
	for k in hc:
		habitants_chat[int(k)] = String(hc[k])
		_deja_vus[String(hc[k]).to_lower()] = true
	votes_faits = int(d.get("votes", 0))
	historique = Array(d.get("historique", []))
	changed.emit()


func clear() -> void:
	vote = {}
	dernier = {}
	historique = []
	file_noms = []
	habitants_chat = {}
	_deja_vus = {}
	votes_faits = 0
	_meteo_fin = -1.0
	_avant_vote = intervalle * 60.0
	vote_change.emit()
