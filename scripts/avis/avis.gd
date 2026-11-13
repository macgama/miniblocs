class_name Avis
extends Node
## Avis des habitants : satisfaction par thème, sondages, quartiers, paroles
## d'habitants, élections municipales et manifestations (panneau Avis, touche Y).
##
## Le nœud vit sous la racine (/root/Avis) pendant une partie ; Avis.instance y
## donne accès. Population.satisfaction(p) garde ses propres motifs (emploi,
## école, loisirs, trajet, logement, commerces) et y ajoute ceux d'Avis.
##
## Brancher un autre système (pollution, déchets, réseaux, budget, trafic…),
## sans dépendre de l'ordre de chargement :
##
##   add_to_group("avis_sources")
##   func avis_facteurs() -> Array:
##       return [{"id": "dechets", "theme": "environnement", "f": _avis_dechets},
##               {"id": "impots", "theme": "impots", "f": _avis_impots, "ville": true}]
##
## ou bien : if Avis.instance: Avis.instance.facteur("id", "theme", f, ville).
##
## f(p) -> [delta, raisons] pour un habitant (raisons : « + … » ou « − … ») ;
## avec "ville": true, f() sans argument, le même pour tous (relu toutes les
## quelques secondes). Delta conseillé : −15 à +10 par facteur.
## Thèmes : voir THEMES (un thème inconnu est accepté et affiché tel quel).
##
## Plusieurs villes (Pays) : chaque ville a ses élections, son maire et son
## historique. `ville_vid` est la ville examinée (−1 : toute la population) :
## par défaut la ville gérée (Pays.selection) ; chaque jour, chaque heure, Avis
## passe par toutes les villes. echantillon(), sondage(), compter(),
## logements(), chomage(), pression_fiscale(), dette(), mairie() et ville()
## suivent cette ville.

signal changed
## Une nouvelle de la vie politique (aussi envoyée au fil d'actualité).
signal nouvelle(texte: String)
## Le joueur a perdu la mairie et les réglages disent « fin de partie ».
signal defaite_finale(texte: String)

static var instance: Avis

const THEMES := {
	"emploi": {"nom": "Emploi et revenus", "icone": "emploi"},
	"logement": {"nom": "Logement", "icone": "logement"},
	"services": {"nom": "Écoles et santé", "icone": "ecole"},
	"securite": {"nom": "Sécurité", "icone": "services"},
	"environnement": {"nom": "Environnement", "icone": "paysage"},
	"transports": {"nom": "Transports", "icone": "circulation"},
	"impots": {"nom": "Impôts et budget", "icone": "budget"},
	"reseaux": {"nom": "Eau, énergie, internet", "icone": "eau"},
	"loisirs": {"nom": "Loisirs", "icone": "loisirs"},
	"commerces": {"nom": "Commerces", "icone": "commerce"},
	"politique": {"nom": "Vie politique", "icone": "urne"},
}
## Habitants interrogés par sondage (le calcul complet est coûteux).
const ECHANTILLON := 400
## Taille d'un quartier (m).
const QUARTIER := 250.0
const HISTORIQUE_MAX := 120
## Délai minimal entre deux relectures des facteurs « ville » (ms).
const VILLE_CACHE_MS := 3000

var population: Population
var buildings: BuildingSystem
var transport: TransportSystem
var ambiance: DayNight
var world: TerrainWorld
var evenements: Evenements

## Élections de la ville examinée (voir elections_villes).
var elections: Elections
var manifs: Manifestations
## Ville examinée : −1 = toute la population (partie sans villages).
var ville_vid := -1
## Élections de chaque ville : vid -> Elections (−1 : partie sans villages).
var elections_villes := {}
## Historique des sondages de chaque ville : vid -> Array.
var historiques := {}
## Derniers sondages par ville : vid -> [ms, sondage].
var _sondages := {}

## Effets passagers (promesses, manifestations, police…) :
## [{theme, delta, fin (unix de jeu), raison}].
var effets: Array = []
## Sondage quotidien : {jour, valeur, themes {id: note}} (le plus ancien d'abord).
var historique: Array = []
## Dernier sondage complet (voir sondage()).
var dernier: Dictionary = {}

var _facteurs: Dictionary = {}
var _sources_ms := -100000
var _sources: Array = []
var _ville_ms := -100000
var _ville: Dictionary = {}
var _last_day := -1
var _last_hour := -1
var _sondage_ms := -100000
var _now_unix := 0.0
## Motif -> thème, appris des sources (pour ranger les motifs par thème).
var _theme_motif: Dictionary = {}


func _init() -> void:
	name = "Avis"
	elections = Elections.new(self)
	elections_villes[-1] = elections
	historiques[-1] = historique
	manifs = Manifestations.new(self)


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func setup(pop: Population, bs: BuildingSystem, tr: TransportSystem, amb: DayNight, w: TerrainWorld, ev: Evenements) -> void:
	population = pop
	buildings = bs
	transport = tr
	ambiance = amb
	world = w
	evenements = ev
	if population != null:
		population.plan_hooks.append(manifs.plan_hook)
	if evenements != null:
		evenements.incident_resolu.connect(manifs.on_incident_resolu)


func clear() -> void:
	effets.clear()
	# L'élection « toute la population » garde son objet (d'autres le tiennent).
	var e0: Elections = elections_villes.get(-1, elections)
	elections_villes.clear()
	historiques.clear()
	_sondages.clear()
	ville_vid = -1
	elections = e0
	elections_villes[-1] = elections
	historique = []
	historiques[-1] = historique
	dernier = {}
	_last_day = -1
	_last_hour = -1
	_sondage_ms = -100000
	_ville_ms = -100000
	elections.clear()
	manifs.clear()
	changed.emit()


# --- Plusieurs villes (Pays) ---------------------------------------------------------

## Plusieurs villes ?
static func multi() -> bool:
	return Pays.instance != null and Pays.instance.a_des_villes()


## Ville examinée par défaut : la ville gérée (−1 sans villages).
func ville_par_defaut() -> int:
	return Pays.instance.selection if multi() else -1


## Villes qui ont des élections : les villages, ou −1 sans villages.
func villes() -> Array:
	if not multi():
		return [-1]
	var ids: Array = Communes.instance.villages.keys()
	ids.sort()
	return ids


## Examine la ville v (élections, historique et sondages suivent).
func examiner(v: int) -> void:
	if v == ville_vid and elections_villes.has(v):
		return
	ville_vid = v
	elections = elections_de(v)
	if not historiques.has(v):
		historiques[v] = []
	historique = historiques[v]
	var c: Array = _sondages.get(v, [-100000, {}])
	_sondage_ms = int(c[0])
	dernier = c[1]


func elections_de(v: int) -> Elections:
	# Le chef-lieu reprend l'élection d'avant les villages (même objet, même mandat).
	if v >= 0 and not elections_villes.has(v) and Communes.instance != null and v == Communes.instance.principal() \
			and elections_villes.has(-1) and (elections_villes[-1] as Elections).vid == -1:
		var e0: Elections = elections_villes[-1]
		e0.vid = v
		elections_villes[v] = e0
		if historiques.has(-1) and not historiques.has(v):
			historiques[v] = historiques[-1]
		return e0
	if not elections_villes.has(v):
		var e := Elections.new(self)
		e.vid = v
		elections_villes[v] = e
	return elections_villes[v]


## Le joueur est-il maire de cette ville ?
func joueur_maire_de(v: int) -> bool:
	return not elections_villes.has(v) or (elections_villes[v] as Elections).joueur_maire()


## Le joueur décide-t-il des réglages de cette ville (impôts, emprunts,
## entretien) ? Non s'il a perdu la mairie avec le réglage « mairie perdue ».
func joueur_decide_de(v: int) -> bool:
	if not elections_villes.has(v):
		return true
	var e: Elections = elections_villes[v]
	return e.mode() != "mairie" or e.joueur_maire()


## Maire d'une ville : {joueur, nom (liste), tete_nom, tendance…}.
func maire_de(v: int) -> Dictionary:
	if not elections_villes.has(v):
		return {"joueur": true}
	var m: Dictionary = (elections_villes[v] as Elections).maire
	return m if not m.is_empty() else {"joueur": true}


## Ce bâtiment est-il dans la ville examinée ?
func dans_ville(bid: int) -> bool:
	if ville_vid < 0 or Communes.instance == null:
		return true
	return Communes.instance.village_de(bid) == ville_vid


## Habitants de la ville examinée.
func habitants() -> int:
	if population == null:
		return 0
	if ville_vid < 0:
		return population.persons.size()
	return echantillon(false, 1 << 30).size()


## Électeurs (majeurs) de la ville examinée.
func electeurs() -> int:
	if population == null:
		return 0
	return echantillon(true, 1 << 30).size()


# --- Facteurs ---------------------------------------------------------------------

## Ajoute (ou remplace) un facteur. f(p) -> [delta, raisons] ; ville : f() pour tous.
func facteur(id: String, theme: String, f: Callable, ville := false) -> void:
	_facteurs[id] = {"id": id, "theme": theme, "f": f, "ville": ville}
	_sources_ms = -100000
	_ville_ms = -100000


func retirer(id: String) -> void:
	_facteurs.erase(id)
	_sources_ms = -100000


## Tous les facteurs : ceux ajoutés ici et ceux des nœuds du groupe « avis_sources ».
func sources() -> Array:
	var ms := Time.get_ticks_msec()
	if ms - _sources_ms < 2000:
		return _sources
	_sources_ms = ms
	var out := []
	var seen := {}
	for id in _facteurs:
		out.append(_facteurs[id])
		seen[id] = true
	if is_inside_tree():
		for n in get_tree().get_nodes_in_group("avis_sources"):
			if not n.has_method("avis_facteurs"):
				continue
			var list = n.call("avis_facteurs")
			if not list is Array:
				continue
			for d in list:
				if not d is Dictionary or not (d as Dictionary).has("f"):
					continue
				var id := String(d.get("id", "%s_%d" % [n.name, out.size()]))
				if seen.has(id) or not (d.f is Callable) or not (d.f as Callable).is_valid():
					continue
				seen[id] = true
				out.append({"id": id, "theme": String(d.get("theme", "politique")), "f": d.f, "ville": bool(d.get("ville", false))})
	_sources = out
	return out


## Facteurs « ville » (les mêmes pour tous), relus toutes les quelques secondes.
func facteurs_ville() -> Dictionary:
	var ms := Time.get_ticks_msec()
	if ms - _ville_ms < VILLE_CACHE_MS:
		return _ville
	_ville_ms = ms
	var out := {}
	for src in sources():
		if not bool(src.ville):
			continue
		var r = (src.f as Callable).call()
		if r is Array and (r as Array).size() >= 2:
			out[src.id] = [String(src.theme), float(r[0]), r[1] if r[1] is Array else []]
	# Effets passagers de la vie politique.
	var t := now()
	for e in effets:
		if float(e.fin) > t:
			var k := "effet_%s_%s" % [e.theme, e.raison]
			if out.has(k):
				out[k][1] = float(out[k][1]) + float(e.delta)
			else:
				out[k] = [String(e.theme), float(e.delta), [("+ " if float(e.delta) >= 0.0 else "− ") + String(e.raison)]]
	_ville = out
	return out


## Appelé par Population.satisfaction : ajoute les motifs des autres systèmes.
## th : {thème: delta} complété ; why : raisons complétées. Rend le total.
func appliquer(p: Dictionary, th: Dictionary, why: Array) -> float:
	var total := 0.0
	for src in sources():
		if bool(src.ville):
			continue
		var r = (src.f as Callable).call(p)
		if not r is Array or (r as Array).size() < 2:
			continue
		var d := float(r[0])
		if d == 0.0 and (r[1] as Array).is_empty():
			continue
		th[src.theme] = float(th.get(src.theme, 0.0)) + d
		total += d
		if r[1] is Array:
			why.append_array(r[1])
			_apprendre(r[1], String(src.theme))
	var v := facteurs_ville()
	for k in v:
		var d := float(v[k][1])
		th[v[k][0]] = float(th.get(v[k][0], 0.0)) + d
		total += d
		why.append_array(v[k][2])
		_apprendre(v[k][2], String(v[k][0]))
	var perso := manifs.effet_perso(p)
	if not perso.is_empty():
		th.politique = float(th.get("politique", 0.0)) + float(perso[0])
		total += float(perso[0])
		why.append(perso[1])
	return total


func _apprendre(raisons: Array, theme: String) -> void:
	if _theme_motif.size() > 2000:
		return
	for r in raisons:
		var m := motif(String(r))
		if not _theme_motif.has(m):
			_theme_motif[m] = theme


## Effet passager sur un thème pour tous les habitants.
func ajouter_effet(theme: String, delta: float, jours: float, raison: String) -> void:
	effets.append({"theme": theme, "delta": delta, "fin": now() + jours * 86400.0, "raison": raison})
	_ville_ms = -100000
	_sondage_ms = -100000
	changed.emit()


func effets_actifs() -> Array:
	var out := []
	var t := now()
	for e in effets:
		if float(e.fin) > t:
			out.append(e)
	return out


# --- Temps --------------------------------------------------------------------------

func now() -> float:
	return ambiance.unix_time if ambiance != null else _now_unix


func local_now() -> Dictionary:
	if population != null:
		return population.now()
	return {"h": 10.0, "wd": 2, "month": 3, "day": 0, "mday": 10}


## Jour de jeu (Population.now().day).
func jour() -> int:
	return int(local_now().day)


func _process(_delta: float) -> void:
	if population == null:
		return
	var n := local_now()
	var d := int(n.day)
	if ville_vid != ville_par_defaut():
		examiner(ville_par_defaut())
	if _last_day < 0 or d < _last_day:
		_last_day = d
		_last_hour = int(float(n.h))
		for v in villes():
			examiner(v)
			elections.demarrer_si_besoin(d)
		examiner(ville_par_defaut())
		return
	if d > _last_day:
		_last_day = d
		_nouveau_jour(n)
	var h := int(float(n.h))
	if h != _last_hour:
		_last_hour = h
		_nouvelle_heure(n)
	manifs.step()


func _nouveau_jour(n: Dictionary) -> void:
	# Effets passés oubliés.
	var t := now()
	for i in range(effets.size() - 1, -1, -1):
		if float(effets[i].fin) <= t:
			effets.remove_at(i)
	# Chaque ville : son sondage du jour, ses élections, son maire.
	for v in villes():
		examiner(v)
		var s := sondage(true)
		if int(s.n) > 0:
			var notes := {}
			for th in s.themes:
				notes[th] = int(s.themes[th].note)
			historique.append({"jour": int(n.day), "valeur": int(s.valeur), "themes": notes})
			while historique.size() > HISTORIQUE_MAX:
				historique.remove_at(0)
		elections.nouveau_jour(n)
		# Ville perdue : le maire élu gère son budget (GestionAuto).
		if v >= 0 and not joueur_decide_de(v):
			GestionAuto.gerer_maire(v, maire_de(v), int(n.day))
	examiner(ville_par_defaut())
	manifs.nouveau_jour(n)
	changed.emit()


func _nouvelle_heure(n: Dictionary) -> void:
	for v in villes():
		examiner(v)
		elections.nouvelle_heure(n)
	examiner(ville_par_defaut())
	manifs.nouvelle_heure(n)


# --- Sondage --------------------------------------------------------------------------

## Habitants majeurs (électeurs) et échantillon régulier de la population.
func echantillon(adultes := false, n_max := ECHANTILLON) -> Array:
	var ids := []
	var cm := Communes.instance
	var filtre := ville_vid >= 0 and cm != null
	for pid in population.persons:
		if adultes and population.age_of(population.persons[pid]) < Population.ADULT_AGE:
			continue
		if filtre and cm.village_de(population.home_of(population.persons[pid])) != ville_vid:
			continue
		ids.append(pid)
	if ids.size() <= n_max:
		return ids
	var out := []
	var step := float(ids.size()) / n_max
	for k in n_max:
		out.append(ids[int(k * step)])
	return out


## Note d'un thème (0-100) d'après le delta moyen.
static func note_de(delta_moyen: float) -> int:
	return clampi(roundi(50.0 + delta_moyen * 3.0), 0, 100)


static func theme_nom(id: String) -> String:
	return String(THEMES.get(id, {}).get("nom", id.capitalize()))


static func theme_icone(id: String) -> String:
	return String(THEMES.get(id, {}).get("icone", "sourire"))


## Raison sans les chiffres entre parenthèses (pour regrouper « long trajet (52 min) »).
static func motif(r: String) -> String:
	var re := RegEx.create_from_string("\\s*\\([^)]*\\)")
	var s := re.sub(r, "", true).strip_edges()
	# « loisirs : 2 sur 3 possibles en ville » → « loisirs en ville ».
	re = RegEx.create_from_string(" ?: \\d+ sur \\d+ possibles")
	return re.sub(s, "", true)


## Sondage : satisfaction moyenne, notes par thème avec leurs motifs principaux,
## quartiers, satisfaction par logement. Gardé quelques secondes.
func sondage(force := false) -> Dictionary:
	var ms := Time.get_ticks_msec()
	if not force and ms - _sondage_ms < 4000 and not dernier.is_empty():
		return dernier
	_sondage_ms = ms
	var out := {"jour": jour(), "n": 0, "valeur": 0, "themes": {}, "quartiers": [], "logements": {}, "mecontents": 0,
		"contents": 0, "habitants": habitants()}
	var ids := echantillon() if population != null else []
	if ids.is_empty():
		dernier = out
		_sondages[ville_vid] = [ms, out]
		return out
	var tot := 0.0
	var th_sum := {}
	var th_n := {}
	var motifs := {}
	var homes := {}
	var q := {}
	var centre := _centre()
	for pid in ids:
		var p: Dictionary = population.persons[pid]
		var s := population.satisfaction(p)
		var v := float(s.value)
		tot += v
		if v < 35.0:
			out.mecontents += 1
		elif v >= 65.0:
			out.contents += 1
		for th in s.themes:
			th_sum[th] = float(th_sum.get(th, 0.0)) + float(s.themes[th])
			th_n[th] = int(th_n.get(th, 0)) + 1
		for r in s.why:
			var txt := String(r)
			var key := motif(txt)
			motifs[key] = int(motifs.get(key, 0)) + 1
		var home := population.home_of(p)
		if home >= 0:
			if not homes.has(home):
				homes[home] = [0.0, 0]
			homes[home][0] += v
			homes[home][1] += 1
	var n := ids.size()
	out.n = n
	out.valeur = roundi(tot / n)
	var scale := float(out.habitants) / n
	out.mecontents = roundi(out.mecontents * scale)
	out.contents = roundi(out.contents * scale)
	# Motifs rangés par thème (le thème d'un motif = celui où il pèse le plus).
	var raisons_par_theme := _raisons_par_theme(ids, motifs)
	for th in th_sum:
		var moy := float(th_sum[th]) / n
		out.themes[th] = {"note": note_de(moy), "delta": moy, "n": int(th_n[th]), "raisons": raisons_par_theme.get(th, [])}
	for bid in homes:
		out.logements[bid] = roundi(float(homes[bid][0]) / int(homes[bid][1]))
		var pos := population.building_pos(bid)
		var k := Vector2i(floori((pos.x - centre.x) / QUARTIER + 0.5), floori((pos.z - centre.z) / QUARTIER + 0.5))
		if not q.has(k):
			q[k] = {"somme": 0.0, "n": 0, "pos": Vector3.ZERO, "pires": {}}
		q[k].somme += float(homes[bid][0])
		q[k].n += int(homes[bid][1])
		q[k].pos += pos * int(homes[bid][1])
	for k in q:
		var e: Dictionary = q[k]
		out.quartiers.append({"nom": nom_quartier(k), "cle": k, "valeur": roundi(float(e.somme) / int(e.n)), "n": roundi(int(e.n) * scale),
			"pos": e.pos / int(e.n)})
	out.quartiers.sort_custom(func(a, b) -> bool: return int(a.valeur) < int(b.valeur))
	dernier = out
	_sondages[ville_vid] = [ms, out]
	return out


## Motifs regroupés par thème : [[motif, nombre d'habitants]], 4 au plus.
func _raisons_par_theme(ids: Array, motifs: Dictionary) -> Dictionary:
	var out := {}
	for key in motifs:
		var th := theme_du_motif(key)
		if not out.has(th):
			out[th] = []
		(out[th] as Array).append([key, roundi(int(motifs[key]) * float(habitants()) / ids.size())])
	for th in out:
		(out[th] as Array).sort_custom(func(a, b) -> bool: return int(a[1]) > int(b[1]))
		out[th] = (out[th] as Array).slice(0, 4)
	return out


## Thème d'un motif : celui de la source qui l'a donné, sinon d'après ses mots.
func theme_du_motif(m: String) -> String:
	if _theme_motif.has(m):
		return String(_theme_motif[m])
	return _theme_du_motif(m)


## Thème d'un motif d'après ses mots (motifs de Population et des autres systèmes).
const MOTS := {
	"emploi": ["emploi", "chômage", "salaire", "endetté", "travail", "retraite", "revenu"],
	"services": ["école", "études", "hôpital", "médecin", "soins", "santé", "enseignant", "collège", "lycée"],
	"securite": ["police", "délinquance", "cambriol", "sécurité", "délit", "vol"],
	"environnement": ["pollution", "bruit", "déchet", "poubelle", "odeur", "ordure", "air", "fumée", "décharge", "recycl", "parc", "vert", "arbre"],
	"transports": ["trajet", "bouchon", "embouteillage", "bus", "tram", "métro", "garer", "parking", "route", "train", "transport"],
	"impots": ["impôt", "taxe", "dette", "budget", "emprunt", "tutelle", "fiscal"],
	"reseaux": ["eau", "électricité", "courant", "égout", "internet", "réseau", "fibre", "antenne", "téléphone", "coupure"],
	"logement": ["logement", "loyer", "confort", "maison", "appartement"],
	"loisirs": ["loisir", "sport", "fête", "culture"],
	"commerces": ["commerce", "magasin", "rayon", "courses", "boutique", "pain"],
	"politique": ["promesse", "manifestation", "maire", "élection", "grève", "police a dispersé", "dialogue"],
}


static func _theme_du_motif(m: String) -> String:
	var low := m.to_lower()
	# La vie politique d'abord (« manifestation dispersée par la police »).
	for w in MOTS.politique:
		if low.contains(w):
			return "politique"
	for th in MOTS:
		for w in MOTS[th]:
			if low.contains(String(w)):
				return th
	return "politique"


## Centre de la ville (moyenne des logements), pour nommer les quartiers.
func _centre() -> Vector3:
	var c := Vector3.ZERO
	var n := 0
	if population == null:
		return c
	for bid in population.known:
		if int(population.known[bid].log) > 0 and dans_ville(bid):
			c += population.building_pos(bid)
			n += 1
	return c / n if n > 0 else c


const DIRECTIONS := ["Est", "Nord-Est", "Nord", "Nord-Ouest", "Ouest", "Sud-Ouest", "Sud", "Sud-Est"]


static func nom_quartier(k: Vector2i) -> String:
	if k == Vector2i.ZERO:
		return "Centre-ville"
	# Nord = −z dans le monde (caméra vers −z).
	var a := atan2(-float(k.y), float(k.x))
	var i := posmod(roundi(a / (PI / 4.0)), 8)
	var d := maxi(absi(k.x), absi(k.y))
	return "Quartier %s%s" % [DIRECTIONS[i], "" if d <= 1 else " (%d)" % d]


## Satisfaction moyenne (dernier sondage), −1 sans habitant.
func moyenne() -> int:
	var s := sondage()
	return int(s.valeur) if int(s.n) > 0 else -1


## Note d'un thème (dernier sondage), −1 si aucun habitant n'en parle.
func note(theme: String) -> int:
	var s := sondage()
	if not (s.themes as Dictionary).has(theme):
		return -1
	return int(s.themes[theme].note)


## Tendance : satisfaction d'aujourd'hui moins celle d'il y a `jours` jours.
func tendance(jours := 7) -> int:
	if historique.size() < 2:
		return 0
	var last: Dictionary = historique[historique.size() - 1]
	var old: Dictionary = historique[maxi(0, historique.size() - 1 - jours)]
	return int(last.valeur) - int(old.valeur)


# --- Paroles d'habitants ---------------------------------------------------------------

const PHRASES := {
	"emploi": [["Je cherche du travail depuis des mois.", "Il faudrait des entreprises ici."], ["J'ai un bon travail pas loin.", "On vit correctement."]],
	"logement": [["Mon logement est trop petit et mal fichu.", "Le loyer me prend tout."], ["On est bien chez nous.", "Notre maison est confortable."]],
	"services": [["Il n'y a pas de place à l'école pour mon fils.", "L'hôpital est bien trop loin."], ["L'école est super, les enfants l'adorent.", "On est bien soignés ici."]],
	"securite": [["Je n'ose plus sortir le soir.", "On ne voit jamais la police."], ["On se sent en sécurité dans le quartier."]],
	"environnement": [["On respire mal, avec toute cette pollution.", "Le bruit m'empêche de dormir.", "Les poubelles débordent dans la rue."], ["L'air est pur, c'est agréable.", "Le quartier est propre et calme."]],
	"transports": [["Je passe ma vie dans les bouchons.", "Le bus est toujours bondé.", "Impossible de se garer !"], ["Je vais au travail en dix minutes.", "Les transports marchent bien."]],
	"impots": [["Les impôts sont beaucoup trop lourds.", "La mairie dépense n'importe comment."], ["Les impôts restent raisonnables."]],
	"reseaux": [["Encore une coupure de courant !", "Internet ne marche pas chez nous.", "Pas d'eau au robinet ce matin."], ["Tout fonctionne, eau, courant, internet."]],
	"loisirs": [["On s'ennuie, il n'y a rien à faire ici.", "Il faudrait un stade, un parc, quelque chose !"], ["Il y a plein de choses à faire le week-end."]],
	"commerces": [["Les rayons sont vides au magasin.", "Il faut prendre la voiture pour acheter du pain."], ["Les commerces sont tout près, c'est pratique."]],
	"politique": [["Le maire n'a pas tenu ses promesses.", "Personne ne nous écoute à la mairie."], ["Le maire fait ce qu'il a dit.", "La mairie nous écoute."]],
}


## Quelques habitants qui donnent leur avis : les plus mécontents et quelques
## autres au hasard. [{pid, nom, age, etape, valeur, theme, phrase, motif}]
func paroles(n := 8) -> Array:
	var out := []
	if population == null or population.persons.is_empty():
		return out
	var ids := echantillon(true, 160)
	var notes := []
	for pid in ids:
		var p: Dictionary = population.persons[pid]
		var s := population.satisfaction(p)
		notes.append([pid, s])
	notes.sort_custom(func(a, b) -> bool: return int(a[1].value) < int(b[1].value))
	var pick := []
	for i in mini(n / 2, notes.size()):
		pick.append(notes[i])
	var rng := RandomNumberGenerator.new()
	rng.seed = jour() * 7919 + population.persons.size()
	var tries := 0
	while pick.size() < mini(n, notes.size()) and tries < 50:
		tries += 1
		var c = notes[rng.randi() % notes.size()]
		if not pick.has(c):
			pick.append(c)
	for c in pick:
		var p: Dictionary = population.persons[c[0]]
		var s: Dictionary = c[1]
		var negatif := int(s.value) < 55
		# Le thème qui pèse le plus dans le sens de son humeur.
		var best := ""
		var best_d := 0.0
		for th in s.themes:
			var d := float(s.themes[th])
			if (negatif and d < best_d) or (not negatif and d > best_d):
				best = th
				best_d = d
		if best == "" or not PHRASES.has(best):
			continue
		var lst: Array = PHRASES[best][0 if negatif else 1]
		var phrase := String(lst[int(p.id) % lst.size()])
		var motif_txt := ""
		for r in s.why:
			if theme_du_motif(motif(String(r))) == best and String(r).begins_with("−" if negatif else "+"):
				motif_txt = String(r)
				break
		out.append({"pid": int(p.id), "nom": CycleVie.full_name(p), "age": population.age_years(p), "etape": population.stage_label(p),
			"valeur": int(s.value), "theme": best, "phrase": phrase, "motif": motif_txt})
	return out


# --- Mesures (promesses, objectifs) ----------------------------------------------------

## Nœud du budget communal s'il existe (fil budget : groupe « budget_communal »).
func budget_node() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group("budget_communal")


func pression_fiscale() -> float:
	var b := budget_node()
	if ville_vid >= 0 and b is BudgetCommunal:
		return (b as BudgetCommunal).pression_fiscale_de(ville_vid)
	if b != null and b.has_method("pression_fiscale"):
		return float(b.call("pression_fiscale"))
	return ReglagesPartie.actuel.impots


func dette() -> float:
	var b := budget_node()
	if ville_vid >= 0 and b is BudgetCommunal:
		return (b as BudgetCommunal).dette_de(ville_vid)
	if b != null and b.has_method("dette"):
		return float(b.call("dette"))
	return 0.0


## Nombre de bâtiments terminés qui ont une de ces clés (type, archétype, rôle, catégorie).
func compter(cles: Array) -> int:
	var n := 0
	if buildings == null:
		return 0
	for bid in buildings.buildings:
		var b: Dictionary = buildings.buildings[bid]
		if b.get("chantier", false) or not dans_ville(bid):
			continue
		for k in Metiers.keys_of(String(b.t)):
			if cles.has(k):
				n += 1
				break
	return n


func chomage() -> float:
	if population == null:
		return 0.0
	if ville_vid >= 0:
		var actifs := 0
		var sans := 0
		for pid in echantillon(true, 1 << 30):
			var st := population.stage(population.persons[pid])
			if st == "actif":
				actifs += 1
			elif st == "chomeur":
				sans += 1
		return 100.0 * sans / (actifs + sans) if actifs + sans > 0 else 0.0
	var s := population.stats()
	var adults := int(s.actif) + int(s.chomeur)
	return 100.0 * int(s.chomeur) / adults if adults > 0 else 0.0


func logements() -> int:
	var n := 0
	if population == null:
		return 0
	for bid in population.known:
		if dans_ville(bid):
			n += int(population.known[bid].log)
	return n


func lignes() -> int:
	if transport == null or transport.stations == null:
		return 0
	return transport.stations.lines.size()


## Mairie de la ville (bâtiment), sinon −1.
func mairie() -> int:
	if buildings == null:
		return -1
	# Siège du premier village (scripts/communes) s'il est construit.
	var cm := Communes.instance
	if cm != null and not cm.villages.is_empty():
		var siege := int(cm.villages[ville_vid if cm.villages.has(ville_vid) else cm.principal()].bid)
		if buildings.buildings.has(siege) and not buildings.buildings[siege].get("chantier", false):
			return siege
	for bid in buildings.buildings:
		var b: Dictionary = buildings.buildings[bid]
		if not b.get("chantier", false) and Metiers.keys_of(String(b.t)).has("mairie"):
			return bid
	return -1


## Nom de la commune : le premier village fondé (scripts/communes), sinon le
## nom du lieu (« Annecy, Haute-Savoie » → « Annecy »).
static func ville() -> String:
	if instance != null and instance.ville_vid >= 0 and Communes.instance != null and Communes.instance.villages.has(instance.ville_vid):
		return String(Communes.instance.villages[instance.ville_vid].nom)
	var v := Communes.nom_principal()
	if v != "":
		return v
	var n := GameStart.place_name.strip_edges()
	if n == "" or n == "Atelier":
		return "MiniBlocs"
	return n.split(",")[0].strip_edges()


func dire(texte: String, pos := Vector3.INF) -> void:
	nouvelle.emit(texte)
	if evenements != null:
		evenements.news(texte, pos, "politique")


# --- Sauvegarde --------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var ef := []
	for e in effets_actifs():
		ef.append(e.duplicate())
	var vs := {}
	for v in elections_villes:
		if int(v) == -1 and (elections_villes[v] as Elections).vid != -1:
			continue  # déjà sauvée avec le chef-lieu
		vs[str(v)] = {"elections": (elections_villes[v] as Elections).to_dict(), "historique": (historiques.get(v, []) as Array).duplicate(true)}
	return {"version": 2, "effets": ef, "historique": historique.duplicate(true), "elections": elections.to_dict(),
		"manifs": manifs.to_dict(), "villes": vs, "ville_vid": ville_vid}


func from_dict(d: Dictionary) -> void:
	clear()
	if d.is_empty():
		return
	for e in d.get("effets", []):
		effets.append({"theme": String(e.theme), "delta": float(e.delta), "fin": float(e.fin), "raison": String(e.raison)})
	if d.has("villes"):
		for ks in d.villes:
			var v := int(ks)
			var e: Dictionary = d.villes[ks]
			elections_de(v).from_dict(e.get("elections", {}))
			historiques[v] = _lire_historique(e.get("historique", []))
	else:
		# Avant le pays : une seule commune, celle du chef-lieu s'il y a des villages.
		var v := Communes.instance.principal() if multi() else -1
		elections_de(v).from_dict(d.get("elections", {}))
		historiques[v] = _lire_historique(d.get("historique", []))
	ville_vid = -2
	examiner(ville_par_defaut())
	manifs.from_dict(d.get("manifs", {}))
	_last_day = jour()
	_last_hour = int(float(local_now().h))
	changed.emit()


func _lire_historique(src: Array) -> Array:
	var out := []
	for h in src:
		var th := {}
		for k in (h.get("themes", {}) as Dictionary):
			th[String(k)] = int(h.themes[k])
		out.append({"jour": int(h.jour), "valeur": int(h.valeur), "themes": th})
	return out
