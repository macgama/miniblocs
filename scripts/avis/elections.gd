class_name Elections
extends RefCounted
## Élections municipales.
##
## - Dès 30 habitants, le joueur est maire. Un mandat dure 6 ans de la vie des
##   habitants (au moins 4 semaines de jeu) ; le vote a lieu un dimanche,
##   dépouillement à 20 h. Pas de majorité au 1er tour : 2e tour le dimanche
##   suivant entre les listes à 10 % ou plus (au moins les deux premières).
## - Une semaine avant (moins si le mandat est court), la campagne s'ouvre :
##   2 ou 3 listes adverses aux noms inventés, menées par des habitants, avec
##   leurs thèmes (écologie, sécurité, impôts bas, solidarité). Le joueur fait
##   jusqu'à 3 promesses (panneau Avis, onglet Élections).
## - Chaque habitant majeur vote selon sa satisfaction (pour la liste sortante),
##   ce qui le mécontente (pour les listes dont c'est le thème) et les
##   promesses qui le touchent. Le bilan des promesses du mandat compte aussi.
## - Défaite (réglage Admin « Élections ») : sans effet, objectifs imposés (les
##   promesses de la liste gagnante deviennent tes objectifs du mandat) ou fin
##   de partie (on peut continuer en bac à sable).

const MIN_HABITANTS := 30
const MANDAT_ANS := 6.0
const MANDAT_MIN_JOURS := 28
const CAMPAGNE_JOURS := 7
const HEURE_RESULTATS := 20
const MAX_PROMESSES := 3
const SEUIL_2E_TOUR := 10.0
## Plus elle est grande, plus les votes se dispersent.
const TEMPERATURE := 5.0

const MODES := ["aucune", "sans_effet", "objectifs", "mairie", "fin"]
const MODE_NOMS := ["Pas d'élections", "Défaite sans conséquence", "Défaite : objectifs imposés", "Défaite : mairie perdue",
	"Défaite : fin de partie"]
## Mairie perdue : satisfaction sous laquelle les habitants signent une pétition
## pour des élections anticipées (le joueur peut alors les lancer).
const SEUIL_PETITION := 40

## Promesses de campagne (et objectifs imposés) : thème, mesure, test.
const PROMESSES := {
	"impots_stables": {"nom": "Ne pas augmenter les impôts", "theme": "impots", "mesure": "impots", "test": "pas_plus"},
	"impots_baisse": {"nom": "Baisser les impôts de 10 %", "theme": "impots", "mesure": "impots", "test": "baisse10"},
	"dette": {"nom": "Ne pas endetter la ville davantage", "theme": "impots", "mesure": "dette", "test": "pas_plus"},
	"ecole": {"nom": "Ouvrir une nouvelle école", "theme": "services", "mesure": "ecoles", "test": "plus1"},
	"sante": {"nom": "Ouvrir un hôpital ou un cabinet médical", "theme": "services", "mesure": "sante", "test": "plus1"},
	"police": {"nom": "Ouvrir un commissariat", "theme": "securite", "mesure": "police", "test": "plus1"},
	"transports": {"nom": "Créer une ligne de transport en commun", "theme": "transports", "mesure": "lignes", "test": "plus1"},
	"logements": {"nom": "Construire 20 % de logements en plus", "theme": "logement", "mesure": "logements", "test": "plus20"},
	"emploi": {"nom": "Faire baisser le chômage", "theme": "emploi", "mesure": "chomage", "test": "baisse"},
	"loisirs": {"nom": "Deux lieux de loisirs de plus", "theme": "loisirs", "mesure": "loisirs", "test": "plus2"},
	"commerces": {"nom": "Deux commerces de plus", "theme": "commerces", "mesure": "commerces", "test": "plus2"},
	"environnement": {"nom": "Une ville plus propre et plus calme", "theme": "environnement", "mesure": "note_environnement", "test": "note"},
	"reseaux": {"nom": "Eau, courant et internet pour tous", "theme": "reseaux", "mesure": "note_reseaux", "test": "note"},
}

## Tendances des listes adverses.
const TENDANCES := {
	"ecologie": {"noms": ["%s en commun", "Respirer à %s", "%s Écologie", "Vivre mieux à %s"], "couleur": "57cc99",
		"themes": ["environnement", "transports", "loisirs"], "promesses": ["environnement", "transports", "loisirs"]},
	"securite": {"noms": ["%s Sûre et Fière", "Ordre et proximité pour %s", "Tranquillité à %s"], "couleur": "4361ee",
		"themes": ["securite", "impots", "commerces"], "promesses": ["police", "impots_stables", "commerces"]},
	"contribuables": {"noms": ["%s Libre", "Moins d'impôts pour %s", "Bien gérer %s"], "couleur": "f8961e",
		"themes": ["impots", "emploi", "commerces"], "promesses": ["impots_baisse", "dette", "emploi"]},
	"solidarite": {"noms": ["%s Solidaire", "Le cœur de %s", "%s pour tous"], "couleur": "e63946",
		"themes": ["logement", "services", "emploi", "reseaux"], "promesses": ["logements", "ecole", "sante"]},
}
const COULEUR_JOUEUR := "ffd166"

var avis: Avis
## Ville de ces élections (−1 : toute la population, partie sans villages).
var vid := -1
## "attente" (moins de 30 habitants), "mandat", "campagne", "entre_tours".
var etat := "attente"
var mandat_debut := -1
## Jour de jeu du prochain scrutin (1er ou 2e tour).
var vote_jour := -1
var tour := 1
var maire: Dictionary = {}
var listes: Array = []
var nom_liste := ""
## Promesses du mandat en cours (si le joueur est maire) : [{id, ref, jour}].
var promesses: Array = []
## Promesses choisies pendant la campagne : [id].
var promesses_campagne: Array = []
## Objectifs imposés par la liste gagnante (défaite, mode « objectifs »).
var objectifs: Array = []
## Bilan du mandat calculé à l'ouverture de la campagne : [{id, nom, tenu, objectif}].
var bilan: Array = []
var historique: Array = []
var perdu_final := false
## Pour les tests : mode forcé (sinon ReglagesPartie.actuel.elections).
var forcer_mode := ""
var _fait_jour := -1


func _init(a: Avis) -> void:
	avis = a


func clear() -> void:
	etat = "attente"
	mandat_debut = -1
	vote_jour = -1
	tour = 1
	maire = {}
	listes.clear()
	nom_liste = ""
	promesses.clear()
	promesses_campagne.clear()
	objectifs.clear()
	bilan.clear()
	historique.clear()
	perdu_final = false
	_fait_jour = -1


func mode() -> String:
	if forcer_mode != "":
		return forcer_mode
	return ReglagesPartie.actuel.elections


func actives() -> bool:
	return mode() != "aucune"


func joueur_maire() -> bool:
	return maire.is_empty() or bool(maire.get("joueur", true))


func ma_liste() -> String:
	if nom_liste.strip_edges() != "":
		return nom_liste.strip_edges()
	return "Ensemble pour %s" % Avis.ville()


## Durée d'un mandat en jours de jeu (6 ans de la vie des habitants).
func duree_mandat() -> int:
	var speed := avis.population.life_speed() if avis.population != null else 12.0
	return maxi(MANDAT_MIN_JOURS, roundi(MANDAT_ANS * 365.25 / speed))


func duree_campagne() -> int:
	return clampi(duree_mandat() / 4, 2, CAMPAGNE_JOURS)


## Jour de la semaine d'un jour de jeu (0 = dimanche).
func jour_semaine(d: int) -> int:
	var n := avis.local_now()
	return posmod(int(n.wd) + d - int(n.day), 7)


## Premier dimanche à partir du jour d.
func dimanche(d: int) -> int:
	var x := d
	while jour_semaine(x) != 0:
		x += 1
	return x


func jours_avant_vote() -> int:
	return vote_jour - avis.jour() if vote_jour >= 0 else -1


# --- Calendrier ---------------------------------------------------------------------

func demarrer_si_besoin(d: int) -> void:
	if etat != "attente" or not actives() or avis.population == null:
		return
	var hab := avis.habitants()
	if hab < MIN_HABITANTS:
		return
	etat = "mandat"
	mandat_debut = d
	vote_jour = dimanche(d + duree_mandat())
	maire = {"joueur": true, "liste": "joueur", "nom": ma_liste(), "couleur": COULEUR_JOUEUR}
	avis.dire("%s compte %d habitants : te voilà maire ! Prochaines municipales dans %d jours." % [Avis.ville(), hab, vote_jour - d])


func nouveau_jour(n: Dictionary) -> void:
	var d := int(n.day)
	if not actives():
		if etat != "attente":
			etat = "attente"
			listes.clear()
		return
	demarrer_si_besoin(d)
	if etat == "mandat" and d >= vote_jour - duree_campagne():
		ouvrir_campagne()
	elif etat == "campagne" and d < vote_jour:
		_journee_campagne(d)


func nouvelle_heure(n: Dictionary) -> void:
	if etat != "campagne" and etat != "entre_tours":
		return
	var d := int(n.day)
	if (d == vote_jour and int(float(n.h)) >= HEURE_RESULTATS) or d > vote_jour:
		if _fait_jour != d:
			_fait_jour = d
			scrutin()


## Élections anticipées (bouton du panneau) : la campagne s'ouvre tout de suite,
## vote le prochain dimanche à au moins 2 jours.
func anticiper() -> bool:
	if etat == "campagne" or etat == "entre_tours" or not actives():
		return false
	if avis.population == null or avis.habitants() < MIN_HABITANTS:
		return false
	if not joueur_maire() and not petition():
		return false
	if etat == "attente":
		demarrer_si_besoin(avis.jour())
	vote_jour = dimanche(avis.jour() + 2)
	ouvrir_campagne()
	return true


## Mairie perdue et habitants mécontents : une pétition réclame des élections
## anticipées, que le joueur peut lancer (bouton du panneau Avis).
func petition() -> bool:
	if mode() != "mairie" or joueur_maire() or etat != "mandat":
		return false
	var m := avis.moyenne()
	return m >= 0 and m < SEUIL_PETITION


# --- Campagne -----------------------------------------------------------------------

func ouvrir_campagne() -> void:
	if etat == "campagne":
		return
	etat = "campagne"
	tour = 1
	promesses_campagne.clear()
	_faire_bilan()
	var s := avis.sondage(true)
	# Les tendances qui parlent des pires thèmes d'abord.
	var scores := []
	for tid in TENDANCES:
		var sc := 0.0
		for th in TENDANCES[tid].themes:
			if (s.themes as Dictionary).has(th):
				sc += maxf(0.0, 60.0 - float(s.themes[th].note))
		scores.append([tid, sc + float(hash(tid + str(vote_jour)) % 10)])
	scores.sort_custom(func(a, b) -> bool: return float(a[1]) > float(b[1]))
	var n_adv := 3 if avis.habitants() >= 300 else 2
	listes.clear()
	var moi := {"id": "joueur", "nom": ma_liste(), "couleur": COULEUR_JOUEUR, "tendance": "", "themes": [], "promesses": [],
		"joueur": true, "sortant": joueur_maire(), "tete": _tete_joueur(), "tete_nom": _tete_joueur_nom()}
	listes.append(moi)
	var deja := {}
	if not joueur_maire():
		# La liste sortante se représente.
		var sortante := _liste_ia(String(maire.get("tendance", "solidarite")), String(maire.get("nom", "")), int(maire.get("tete", -1)))
		sortante.sortant = true
		listes.append(sortante)
		deja[sortante.tendance] = true
	for sc in scores:
		if listes.size() >= n_adv + 1:
			break
		if deja.has(sc[0]):
			continue
		deja[sc[0]] = true
		listes.append(_liste_ia(String(sc[0])))
	var noms := []
	for l in listes:
		if not bool(l.joueur):
			noms.append("« %s » (%s)" % [l.nom, l.tete_nom])
	avis.dire("Municipales : la campagne est ouverte, vote dimanche dans %d jours. En face : %s." % [jours_avant_vote(), ", ".join(noms)])
	var bad := 0
	for b in bilan:
		if not bool(b.tenu):
			bad += 1
	if not bilan.is_empty():
		var ok := bilan.size() - bad
		avis.ajouter_effet("politique", 2.0 * ok - 3.0 * bad, duree_campagne() + 1.0,
			"promesses tenues (%d sur %d)" % [ok, bilan.size()] if bad == 0 else "promesses non tenues (%d sur %d)" % [bad, bilan.size()])
	avis.changed.emit()


## Le personnage principal du joueur mène sa liste s'il est majeur.
func _tete_joueur() -> int:
	if avis.population != null and avis.population.principal != null:
		var pid := avis.population.principal.mine()
		if pid >= 0 and avis.population.persons.has(pid) and avis.population.age_of(avis.population.persons[pid]) >= Population.ADULT_AGE:
			return pid
	return -1


func _tete_joueur_nom() -> String:
	var pid := _tete_joueur()
	if pid >= 0 and avis.population.persons.has(pid):
		return CycleVie.full_name(avis.population.persons[pid])
	return "toi"


func _liste_ia(tid: String, nom := "", tete := -1) -> Dictionary:
	var t: Dictionary = TENDANCES.get(tid, TENDANCES.solidarite)
	if nom == "":
		var noms: Array = t.noms
		nom = String(noms[absi(hash(tid + str(mandat_debut))) % noms.size()]) % Avis.ville()
	if tete < 0 or not avis.population.persons.has(tete):
		tete = _choisir_tete()
	var tete_nom := "un·e habitant·e"
	if tete >= 0:
		var p: Dictionary = avis.population.persons[tete]
		tete_nom = CycleVie.full_name(p)
		avis.population.vie.log_event(p, "politique", "Conduit la liste « %s » aux municipales" % nom)
	return {"id": tid, "nom": nom, "couleur": String(t.couleur), "tendance": tid, "themes": (t.themes as Array).duplicate(),
		"promesses": (t.promesses as Array).duplicate(), "joueur": false, "sortant": false, "tete": tete, "tete_nom": tete_nom}


## Un habitant de 30 à 70 ans qui ne mène pas déjà une liste (ni le personnage du joueur).
func _choisir_tete() -> int:
	var pris := {}
	for l in listes:
		pris[int(l.get("tete", -1))] = true
	var mine := _tete_joueur()
	var best := -1
	var best_s := -1.0
	for pid in avis.echantillon(true, 200):
		if pris.has(pid) or pid == mine:
			continue
		var p: Dictionary = avis.population.persons[pid]
		var a := avis.population.age_of(p)
		if a < 30.0 or a > 70.0 or bool(p.get("joueur", false)):
			continue
		var s := float(absi(hash(str(pid) + str(vote_jour))) % 1000)
		if s > best_s:
			best_s = s
			best = pid
	return best


func _journee_campagne(d: int) -> void:
	# Un meeting par jour, une liste après l'autre.
	var adv := []
	for l in listes:
		if not bool(l.joueur):
			adv.append(l)
	if adv.is_empty():
		return
	var l: Dictionary = adv[posmod(d, adv.size())]
	var th := String(l.themes[posmod(d, (l.themes as Array).size())])
	avis.dire("Meeting de « %s » : %s promet d'agir pour %s." % [l.nom, l.tete_nom, Avis.theme_nom(th).to_lower()])


## Ajoute ou retire une promesse du joueur (campagne, avant le 1er tour).
func promettre(id: String) -> bool:
	if etat != "campagne" or not PROMESSES.has(id):
		return false
	if promesses_campagne.has(id):
		promesses_campagne.erase(id)
	elif promesses_campagne.size() < MAX_PROMESSES:
		promesses_campagne.append(id)
	else:
		return false
	for l in listes:
		if bool(l.joueur):
			l.promesses = promesses_campagne.duplicate()
			var th := []
			for pid in promesses_campagne:
				th.append(String(PROMESSES[pid].theme))
			l.themes = th
	avis.changed.emit()
	return true


# --- Promesses : mesures et bilan ---------------------------------------------------------

func mesure(m: String) -> float:
	match m:
		"impots":
			return avis.pression_fiscale()
		"dette":
			return avis.dette()
		"ecoles":
			return float(avis.compter(["ecole", "college", "lycee", "universite"]))
		"sante":
			return float(avis.compter(["hopital", "medecin", "clinique", "cabinet_medical"]))
		"police":
			return float(avis.compter(["police", "commissariat", "gendarmerie"]))
		"lignes":
			return float(avis.lignes())
		"logements":
			return float(avis.logements())
		"chomage":
			return avis.chomage()
		"loisirs":
			return float(avis.compter(["loisirs", "sport"]))
		"commerces":
			return float(avis.compter(["commerce"]))
		"note_environnement":
			return float(maxi(avis.note("environnement"), 50) if avis.note("environnement") >= 0 else 50)
		"note_reseaux":
			return float(maxi(avis.note("reseaux"), 50) if avis.note("reseaux") >= 0 else 50)
	return 0.0


func nouvelle_promesse(id: String) -> Dictionary:
	return {"id": id, "ref": mesure(String(PROMESSES[id].mesure)), "jour": avis.jour()}


func tenue(pr: Dictionary) -> bool:
	var spec: Dictionary = PROMESSES.get(String(pr.id), {})
	if spec.is_empty():
		return true
	var now := mesure(String(spec.mesure))
	var ref := float(pr.ref)
	match String(spec.test):
		"pas_plus":
			return now <= ref + maxf(0.01, absf(ref) * 0.001)
		"baisse10":
			return now <= ref * 0.9 + 0.001
		"plus1":
			return now >= ref + 1.0
		"plus2":
			return now >= ref + 2.0
		"plus20":
			return now >= maxf(ref * 1.2, ref + 5.0)
		"baisse":
			return now < ref - 0.5 or now < 4.0
		"note":
			return now >= maxf(60.0, ref + 5.0)
	return false


## Où en est une promesse : « 2 écoles (au départ 1, il en faut 2) ».
func progres(pr: Dictionary) -> String:
	var spec: Dictionary = PROMESSES.get(String(pr.id), {})
	if spec.is_empty():
		return ""
	var now := mesure(String(spec.mesure))
	var ref := float(pr.ref)
	match String(spec.mesure):
		"impots":
			return "impôts à %d %% (au départ %d %%)" % [roundi(now * 100.0), roundi(ref * 100.0)]
		"dette":
			return "dette %s (au départ %s)" % [BuildingSystem.format_short(roundi(now)), BuildingSystem.format_short(roundi(ref))]
		"chomage":
			return "chômage %.1f %% (au départ %.1f %%)" % [now, ref]
		"note_environnement", "note_reseaux":
			return "note %d / 100 (il faut %d)" % [roundi(now), roundi(maxf(60.0, ref + 5.0))]
		"logements":
			return "%d logements (au départ %d, il en faut %d)" % [roundi(now), roundi(ref), ceili(maxf(ref * 1.2, ref + 5.0))]
	var need := 2.0 if String(spec.test) == "plus2" else 1.0
	return "%d (au départ %d, il en faut %d)" % [roundi(now), roundi(ref), roundi(ref + need)]


func _faire_bilan() -> void:
	bilan.clear()
	for pr in promesses:
		bilan.append({"id": pr.id, "nom": PROMESSES[pr.id].nom, "tenu": tenue(pr), "objectif": false})
	for pr in objectifs:
		bilan.append({"id": pr.id, "nom": PROMESSES[pr.id].nom, "tenu": tenue(pr), "objectif": true})


## Bonus de la liste sortante d'après le bilan (promesses tenues ou non).
func _bonus_bilan() -> float:
	var b := 0.0
	for e in bilan:
		b += 4.0 if bool(e.tenu) else -6.0
	return b


# --- Vote ---------------------------------------------------------------------------

static func _h01(a: int, b: int, c: int) -> float:
	return float(absi(hash(Vector3i(a, b, c))) % 10000) / 10000.0


## Intentions de vote (sondage ou vrai scrutin) entre ces listes.
## {pct {id: %}, voix {id: n}, participation (%), inscrits, votants, exprimes}
func intentions(ls: Array = listes, graine := -1) -> Dictionary:
	var out := {"pct": {}, "voix": {}, "participation": 0.0, "inscrits": 0, "votants": 0, "exprimes": 0}
	if ls.is_empty() or avis.population == null:
		return out
	var ids := avis.echantillon(true, 500)
	if ids.is_empty():
		return out
	var adults := avis.electeurs()
	var g := graine if graine >= 0 else vote_jour * 10 + tour
	var bonus := _bonus_bilan()
	var counts := {}
	for l in ls:
		counts[l.id] = 0
	var votants := 0
	for pid in ids:
		var p: Dictionary = avis.population.persons[pid]
		var s := avis.population.satisfaction(p)
		var sat := float(s.value)
		var th: Dictionary = s.themes
		var age := avis.population.age_of(p)
		var prob := 0.5 + 0.35 * absf(sat - 50.0) / 50.0
		if age > 60.0:
			prob += 0.15
		elif age < 30.0:
			prob -= 0.15
		if _h01(int(pid), g, 7) > prob:
			continue
		votants += 1
		# Utilité de chaque liste, puis choix au hasard (graine fixe) selon
		# leurs poids : un vote n'est jamais unanime.
		var us := []
		var umax := -INF
		for l in ls:
			var u := 0.0
			if bool(l.sortant):
				u = (sat - 50.0) * 0.35 + bonus
			else:
				for t in l.themes:
					u += clampf(-float(th.get(t, 0.0)), 0.0, 20.0) * 0.45
			var n_pr := 0
			for prid in l.promesses:
				var t := String(PROMESSES.get(prid, {}).get("theme", ""))
				if float(th.get(t, 0.0)) < -3.0 and n_pr < MAX_PROMESSES:
					u += 3.0
					n_pr += 1
			# Affinités de chacun (famille politique, habitudes).
			u += (_h01(int(pid), hash(String(l.id)), 3) - 0.5) * 14.0
			us.append(u)
			umax = maxf(umax, u)
		var w := []
		var wsum := 0.0
		for u in us:
			var x := exp((float(u) - umax) / TEMPERATURE)
			w.append(x)
			wsum += x
		var pick := _h01(int(pid), g, 11) * wsum
		var best := String(ls[ls.size() - 1].id)
		for i in ls.size():
			pick -= float(w[i])
			if pick <= 0.0:
				best = String(ls[i].id)
				break
		counts[best] = int(counts[best]) + 1
	var scale := float(adults) / ids.size()
	out.inscrits = adults
	out.votants = roundi(votants * scale)
	out.exprimes = out.votants
	out.participation = 100.0 * votants / ids.size()
	for id in counts:
		out.voix[id] = roundi(int(counts[id]) * scale)
		out.pct[id] = 100.0 * int(counts[id]) / votants if votants > 0 else 0.0
	return out


func liste(id: String) -> Dictionary:
	for l in listes:
		if String(l.id) == id:
			return l
	return {}


## Dépouillement (le dimanche à 20 h).
func scrutin() -> void:
	if listes.is_empty():
		etat = "mandat"
		return
	var r := intentions()
	var res := []
	for l in listes:
		res.append({"id": l.id, "nom": l.nom, "couleur": l.couleur, "pct": float(r.pct.get(l.id, 0.0)), "voix": int(r.voix.get(l.id, 0)),
			"joueur": bool(l.joueur), "tete_nom": l.tete_nom})
	res.sort_custom(func(a, b) -> bool: return float(a.pct) > float(b.pct))
	var entree := {"jour": avis.jour(), "tour": tour, "resultats": res, "participation": float(r.participation),
		"inscrits": int(r.inscrits), "votants": int(r.votants), "elu": ""}
	var txt := ", ".join(res.map(func(e) -> String: return "« %s » %.1f %%" % [e.nom, e.pct]))
	if tour == 1 and float(res[0].pct) <= 50.0 and res.size() > 2:
		# Second tour : listes à 10 % ou plus (au moins les deux premières).
		var garde := []
		for i in res.size():
			if i < 2 or float(res[i].pct) >= SEUIL_2E_TOUR:
				garde.append(String(res[i].id))
		var nl := []
		for l in listes:
			if garde.has(String(l.id)):
				nl.append(l)
		listes = nl
		historique.append(entree)
		tour = 2
		etat = "entre_tours"
		vote_jour = avis.jour() + 7
		avis.dire("Municipales, 1er tour (participation %d %%) : %s. Second tour dimanche prochain." % [roundi(r.participation), txt])
		avis.changed.emit()
		return
	entree.elu = String(res[0].id)
	historique.append(entree)
	_elire(liste(String(res[0].id)), float(res[0].pct), txt, float(r.participation))


func _elire(l: Dictionary, pct: float, txt: String, participation: float) -> void:
	var etait_maire := joueur_maire()
	var tour_txt := "1er tour" if tour == 1 else "2e tour"
	Son.jouer("election_gagnee" if bool(l.joueur) else "election_perdue")
	if bool(l.joueur):
		maire = {"joueur": true, "liste": "joueur", "nom": l.nom, "couleur": COULEUR_JOUEUR}
		promesses.clear()
		for id in promesses_campagne:
			promesses.append(nouvelle_promesse(id))
		objectifs.clear()
		var tete := _tete_joueur()
		if tete >= 0:
			avis.population.vie.log_event(avis.population.persons[tete], "politique", "Élu·e maire de %s (%.0f %%)" % [Avis.ville(), pct])
		avis.dire("Municipales (%s, participation %d %%) : %s. %s maire avec %.1f %% !" % [tour_txt, roundi(participation), txt,
			"Tu es réélu·e" if etait_maire else "Tu redeviens", pct])
		avis.ajouter_effet("politique", 3.0, 30.0, "nouveau mandat")
	else:
		maire = {"joueur": false, "liste": l.id, "nom": l.nom, "couleur": l.couleur, "tendance": l.tendance, "tete": int(l.tete),
			"tete_nom": l.tete_nom}
		if int(l.tete) >= 0 and avis.population.persons.has(int(l.tete)):
			avis.population.vie.log_event(avis.population.persons[int(l.tete)], "politique", "Élu·e maire de %s (%.0f %%)" % [Avis.ville(), pct])
		promesses.clear()
		objectifs.clear()
		var m := mode()
		var suite := ""
		match m:
			"objectifs":
				for id in l.promesses:
					objectifs.append(nouvelle_promesse(String(id)))
				suite = " Tu restes aux commandes, mais le nouveau conseil t'impose ses objectifs (panneau Avis, Y)."
			"mairie":
				for id in l.promesses:
					objectifs.append(nouvelle_promesse(String(id)))
				suite = " Tu perds la mairie : tu peux toujours construire, mais les impôts, les emprunts et l'entretien sont décidés par le nouveau conseil. Reprends-la aux prochaines municipales (dans %d jours) ou par une pétition si les habitants sont mécontents." % duree_mandat()
				GestionAuto.appliquer_politique(vid, String(l.tendance))
			"fin":
				perdu_final = true
				suite = " Tu as perdu la mairie : fin de partie."
			_:
				suite = " Tu restes aux commandes de la ville."
		avis.dire("Municipales (%s, participation %d %%) : %s. %s (%s) devient maire avec %.1f %%.%s" % [tour_txt, roundi(participation),
			txt, l.tete_nom, l.nom, pct, suite])
		avis.ajouter_effet("politique", 3.0, 30.0, "nouveau mandat")
		if m == "fin":
			avis.defaite_finale.emit("%s (%s) a gagné les municipales avec %.1f %%." % [l.tete_nom, l.nom, pct])
	etat = "mandat"
	tour = 1
	mandat_debut = avis.jour()
	vote_jour = dimanche(mandat_debut + duree_mandat())
	promesses_campagne.clear()
	bilan.clear()
	avis.changed.emit()


func dernier_scrutin() -> Dictionary:
	return historique[historique.size() - 1] if not historique.is_empty() else {}


# --- Sauvegarde ---------------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {"etat": etat, "mandat_debut": mandat_debut, "vote_jour": vote_jour, "tour": tour, "maire": maire.duplicate(true),
		"listes": listes.duplicate(true), "nom_liste": nom_liste, "promesses": promesses.duplicate(true),
		"promesses_campagne": promesses_campagne.duplicate(), "objectifs": objectifs.duplicate(true), "bilan": bilan.duplicate(true),
		"historique": historique.slice(maxi(0, historique.size() - 20)), "perdu_final": perdu_final}


func from_dict(d: Dictionary) -> void:
	clear()
	if d.is_empty():
		return
	etat = String(d.get("etat", "attente"))
	if not etat in ["attente", "mandat", "campagne", "entre_tours"]:
		etat = "attente"
	mandat_debut = int(d.get("mandat_debut", -1))
	vote_jour = int(d.get("vote_jour", -1))
	tour = int(d.get("tour", 1))
	maire = (d.get("maire", {}) as Dictionary).duplicate(true)
	if maire.has("tete"):
		maire.tete = int(maire.tete)
	nom_liste = String(d.get("nom_liste", ""))
	for l in d.get("listes", []):
		var x: Dictionary = (l as Dictionary).duplicate(true)
		x.tete = int(x.get("tete", -1))
		x.joueur = bool(x.get("joueur", false))
		x.sortant = bool(x.get("sortant", false))
		listes.append(x)
	for key in ["promesses", "objectifs"]:
		var arr: Array = promesses if key == "promesses" else objectifs
		for pr in d.get(key, []):
			if PROMESSES.has(String(pr.id)):
				arr.append({"id": String(pr.id), "ref": float(pr.ref), "jour": int(pr.get("jour", 0))})
	for id in d.get("promesses_campagne", []):
		if PROMESSES.has(String(id)):
			promesses_campagne.append(String(id))
	for b in d.get("bilan", []):
		bilan.append({"id": String(b.id), "nom": String(b.nom), "tenu": bool(b.tenu), "objectif": bool(b.get("objectif", false))})
	for h in d.get("historique", []):
		var e: Dictionary = (h as Dictionary).duplicate(true)
		e.jour = int(e.jour)
		e.tour = int(e.tour)
		historique.append(e)
	perdu_final = bool(d.get("perdu_final", false))
