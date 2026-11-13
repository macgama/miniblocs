class_name Objectifs
extends Node
## Objectifs du joueur (panneau Objectifs, touche J) :
##   - Paliers de chaque ville : Hameau, Village, Bourg, Ville, Grande ville,
##     Métropole. Pour monter, il faut la population ET des conditions (habitants
##     satisfaits, école, pompiers et police, hôpital, transports, caisse saine).
##     Chaque palier gagné rapporte une prime au pays et de la réputation. Un
##     palier gagné n'est jamais perdu.
##   - Missions du pays : 3 missions à la fois, tirées selon l'état des villes
##     (faire grandir une ville, ouvrir une école, relier deux villes, fonder une
##     ville, rembourser ses dettes, faire baisser le chômage, créer une ligne…),
##     avec un délai et une prime. Ratée : la réputation baisse.
##   - Succès : des étapes à débloquer une fois pour toutes.
##   - Réputation du pays (0 à 100) : missions, paliers et succès la font monter ;
##     missions ratées, villes sous tutelle et mairies perdues la font baisser.
##     Une bonne réputation fait baisser le taux des emprunts (jusqu'à −1 point).

signal changed
signal message(text: String)

static var instance: Objectifs

## Paliers des villes : population et conditions, prime (€, × coût) et réputation.
const PALIERS := [
	{"nom": "Hameau", "hab": 0, "sat": 0, "prime": 0, "rep": 0, "cond": []},
	{"nom": "Village", "hab": 100, "sat": 50, "prime": 250_000, "rep": 4, "cond": []},
	{"nom": "Bourg", "hab": 500, "sat": 55, "prime": 1_000_000, "rep": 6, "cond": ["ecole", "caisse"]},
	{"nom": "Ville", "hab": 2000, "sat": 55, "prime": 3_000_000, "rep": 10, "cond": ["ecole", "pompiers", "police", "caisse"]},
	{"nom": "Grande ville", "hab": 10000, "sat": 60, "prime": 10_000_000, "rep": 15, "cond": ["ecole", "pompiers", "police", "hopital", "ligne", "caisse"]},
	{"nom": "Métropole", "hab": 50000, "sat": 60, "prime": 30_000_000, "rep": 25, "cond": ["ecole", "pompiers", "police", "hopital", "ligne", "caisse"]},
]
const COND_NOMS := {"ecole": "une école", "pompiers": "une caserne de pompiers", "police": "un commissariat",
	"hopital": "un hôpital", "ligne": "une ligne de transport en commun", "caisse": "une caisse positive, sans tutelle"}

const MISSIONS_MAX := 3
const REP_DEPART := 20.0

## Succès : id -> [nom, description].
const SUCCES := {
	"premier_village": ["Première pierre", "Fonder ta première ville."],
	"trois_villes": ["Un vrai pays", "Avoir trois villes."],
	"cent": ["Cent âmes", "100 habitants dans le pays."],
	"mille": ["Mille habitants", "1 000 habitants dans le pays."],
	"dix_mille": ["Dix mille", "10 000 habitants dans le pays."],
	"bourg": ["Jour de marché", "Une ville devient Bourg."],
	"ville": ["Les lumières de la ville", "Une ville devient Ville."],
	"metropole": ["Métropole", "Une ville devient Métropole."],
	"sans_dette": ["Bon gestionnaire", "500 habitants ou plus et aucune dette."],
	"heureux": ["Pays heureux", "Toutes les villes à 70 de satisfaction (200 habitants au moins)."],
	"relies": ["Tout est relié", "Toutes les villes reliées par la route (deux au moins)."],
	"missions5": ["Homme ou femme de parole", "Réussir 5 missions."],
	"missions20": ["Bâtisseur du pays", "Réussir 20 missions."],
	"riche": ["Coffres pleins", "50 M€ dans la caisse du pays."],
	"reconquete": ["Retour gagnant", "Reprendre une mairie perdue."],
}

var communes: Communes
var population: Population
var pays: Pays
var buildings: BuildingSystem
var transport: TransportSystem

## Palier gagné par ville : vid -> index de PALIERS.
var paliers := {}
## Missions en cours : [{id, type, vid, vid2, cible, ref, debut, fin, prime, rep, texte}].
var missions: Array = []
## Dernières missions terminées : [{texte, reussie, jour}].
var historique: Array = []
var reussies := 0
var succes := {}
var reputation := REP_DEPART
var _next := 1
var _dernier_jour := -1
## Mairies perdues vues la veille : vid -> true.
var _perdues := {}


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func setup(cm: Communes, pop: Population, p: Pays, bs: BuildingSystem, ts: TransportSystem) -> void:
	communes = cm
	population = pop
	pays = p
	buildings = bs
	transport = ts


func clear() -> void:
	paliers.clear()
	missions.clear()
	historique.clear()
	succes.clear()
	reussies = 0
	reputation = REP_DEPART
	_next = 1
	_dernier_jour = -1
	_perdues.clear()
	changed.emit()


func jour() -> int:
	return int(population.now().day) if population != null else 0


func _process(_delta: float) -> void:
	if population == null or communes == null:
		return
	var d := jour()
	if d == _dernier_jour:
		return
	_dernier_jour = d
	nouveau_jour()


## Un jour passe : paliers, missions, succès, réputation.
func nouveau_jour() -> void:
	if communes.villages.is_empty():
		return
	communes.calculer_stats()
	for vid in communes.villages:
		verifier_palier(int(vid))
	_verifier_missions()
	_completer_missions()
	_verifier_succes()
	_reputation_du_jour()
	changed.emit()


# --- Réputation -----------------------------------------------------------------------

func ajouter_reputation(v: float, pourquoi := "") -> void:
	var avant := roundi(reputation)
	reputation = clampf(reputation + v, 0.0, 100.0)
	if pourquoi != "" and roundi(reputation) != avant:
		message.emit("Réputation du pays %s%d (%s) : %d / 100." % ["+" if v >= 0.0 else "", roundi(v), pourquoi, roundi(reputation)])


## Étoiles (0 à 5) pour l'affichage.
func etoiles() -> int:
	return clampi(roundi(reputation / 20.0), 0, 5)


## Baisse du taux des emprunts due à la réputation (0 à 0,01).
static func bonus_taux() -> float:
	if instance == null:
		return 0.0
	return 0.01 * clampf((instance.reputation - 20.0) / 80.0, 0.0, 1.0)


func _reputation_du_jour() -> void:
	var b := BudgetCommunal.instance
	for vid in communes.villages:
		if b != null and bool(b.etat_de(int(vid)).get("tutelle", false)):
			ajouter_reputation(-0.1)
		var perdue := Avis.instance != null and not Avis.instance.joueur_maire_de(int(vid))
		if perdue and not _perdues.has(vid):
			ajouter_reputation(-5.0, "mairie de %s perdue" % pays.nom_de(int(vid)))
		elif not perdue and _perdues.has(vid):
			succes_debloque("reconquete")
			ajouter_reputation(4.0, "mairie de %s reprise" % pays.nom_de(int(vid)))
		if perdue:
			_perdues[vid] = true
		else:
			_perdues.erase(vid)


# --- Paliers des villes -----------------------------------------------------------------

func palier_de(vid: int) -> int:
	return int(paliers.get(vid, 0))


func satisfaction(vid: int) -> int:
	var av := Avis.instance
	if av == null:
		return 50
	var garde := av.ville_vid
	av.examiner(vid)
	var m := av.moyenne()
	av.examiner(garde)
	return m


func compter(vid: int, type_id: String) -> int:
	var n := 0
	for bid in buildings.buildings:
		var b: Dictionary = buildings.buildings[bid]
		if String(b.t) == type_id and not b.get("chantier", false) and communes.village_de(bid) == vid:
			n += 1
	return n


func lignes() -> int:
	if transport == null or transport.stations == null:
		return 0
	return transport.stations.lines.size()


## Une condition remplie ?
func condition(vid: int, c: String) -> bool:
	match c:
		"ecole", "pompiers", "police", "hopital":
			return compter(vid, c) > 0
		"ligne":
			return lignes() > 0
		"caisse":
			var b := BudgetCommunal.instance
			return pays.solde(vid) >= 0 and (b == null or not bool(b.etat_de(vid).get("tutelle", false)))
	return true


## Ce qui manque pour le palier suivant : [texte…] (vide : il peut monter).
func manques(vid: int) -> Array:
	var i := palier_de(vid) + 1
	if i >= PALIERS.size():
		return []
	var p: Dictionary = PALIERS[i]
	var out := []
	var hab := int(communes.stats.get(vid, {}).get("hab", 0))
	if hab < int(p.hab):
		out.append("%d habitants (aujourd'hui %d)" % [int(p.hab), hab])
	var s := satisfaction(vid) if hab > 0 else -1
	if int(p.sat) > 0 and s < int(p.sat):
		out.append("satisfaction %d (aujourd'hui %s)" % [int(p.sat), "—" if s < 0 else str(s)])
	for c in p.cond:
		if not condition(vid, String(c)):
			out.append(String(COND_NOMS[c]))
	return out


func verifier_palier(vid: int) -> void:
	while palier_de(vid) + 1 < PALIERS.size() and manques(vid).is_empty():
		var i := palier_de(vid) + 1
		paliers[vid] = i
		var p: Dictionary = PALIERS[i]
		var prime := ReglagesPartie.prix(int(p.prime))
		pays.prime(prime, "Prime : %s devient %s" % [pays.nom_de(vid), String(p.nom)])
		message.emit("%s devient « %s » ! Le pays reçoit une prime de %s." % [pays.nom_de(vid), String(p.nom), BuildingSystem.format_money(prime)])
		ajouter_reputation(float(p.rep), "%s devient %s" % [pays.nom_de(vid), String(p.nom).to_lower()])


# --- Missions ------------------------------------------------------------------------------

func _hab(vid: int) -> int:
	return int(communes.stats.get(vid, {}).get("hab", 0))


## Villes reliées par la route (même morceau de réseau près des deux mairies) ?
func relies(a: int, b: int) -> bool:
	if transport == null or not communes.villages.has(a) or not communes.villages.has(b):
		return false
	var net := transport.network
	var na := _noeud_pres(net, communes.villages[a].c)
	var nb := _noeud_pres(net, communes.villages[b].c)
	if na < 0 or nb < 0:
		return false
	return net.component(na).has(nb)


static func _noeud_pres(net: TransportNetwork, c: Vector2) -> int:
	var best := -1
	var bd := 400.0
	for id in net.nodes:
		if net.node_mode(id) != TransportTypes.Mode.ROAD:
			continue
		var p := net.node_pos(id)
		var d := Vector2(p.x, p.z).distance_to(c)
		if d < bd:
			bd = d
			best = id
	return best


func chomage(vid: int) -> float:
	var actifs := 0
	var sans := 0
	for pid in population.persons:
		var p: Dictionary = population.persons[pid]
		if communes.village_de(population.home_of(p)) != vid:
			continue
		var s := population.stage(p)
		if s == "actif":
			actifs += 1
		elif s == "chomeur":
			sans += 1
	return 100.0 * sans / (actifs + sans) if actifs + sans > 0 else 0.0


## Missions possibles aujourd'hui (pas déjà en cours).
func candidates() -> Array:
	var out := []
	var d := jour()
	var en_cours := {}
	for m in missions:
		en_cours["%s:%d" % [m.type, int(m.vid)]] = true
	var ids: Array = communes.villages.keys()
	ids.sort()
	var b := BudgetCommunal.instance
	for vid in ids:
		var h := _hab(vid)
		var nom := pays.nom_de(vid)
		if not en_cours.has("habitants:%d" % vid):
			var cible := maxi(30, snappedi(roundi(h * 1.25) + 20, 10))
			out.append({"type": "habitants", "vid": vid, "cible": cible, "duree": 60, "prime": 150_000 + cible * 500, "rep": 3,
				"texte": "Faire grandir %s jusqu'à %d habitants" % [nom, cible]})
		if h >= 40 and compter(vid, "ecole") == 0 and not en_cours.has("ecole:%d" % vid):
			out.append({"type": "ecole", "vid": vid, "cible": 1, "duree": 45, "prime": 2_000_000, "rep": 4,
				"texte": "Ouvrir une école à %s" % nom})
		if h >= 60 and not en_cours.has("satisfaction:%d" % vid):
			var s := satisfaction(vid)
			if s >= 0 and s < 80:
				var cible := mini(85, maxi(60, s + 8))
				out.append({"type": "satisfaction", "vid": vid, "cible": cible, "duree": 30, "prime": 600_000, "rep": 4,
					"texte": "Rendre %s heureuse : satisfaction %d" % [nom, cible]})
		if h >= 50 and chomage(vid) > 10.0 and not en_cours.has("chomage:%d" % vid):
			out.append({"type": "chomage", "vid": vid, "cible": 6, "duree": 60, "prime": 800_000, "rep": 4,
				"texte": "Faire tomber le chômage de %s sous 6 %%" % nom})
		if b != null and not (b.etat_de(vid).get("emprunts", []) as Array).is_empty() and not en_cours.has("dette:%d" % vid):
			out.append({"type": "dette", "vid": vid, "cible": 0, "duree": 120, "prime": 500_000, "rep": 5,
				"texte": "Rembourser tous les emprunts de %s" % nom})
	if ids.size() < 3 and not en_cours.has("fonder:-1"):
		out.append({"type": "fonder", "vid": -1, "cible": ids.size() + 1, "duree": 120, "prime": 1_000_000, "rep": 6,
			"texte": "Fonder une nouvelle ville (%d en tout)" % (ids.size() + 1)})
	if ids.size() >= 2 and not en_cours.has("relier:-1"):
		for i in ids.size():
			for j in range(i + 1, ids.size()):
				if not relies(ids[i], ids[j]):
					out.append({"type": "relier", "vid": -1, "vid2": [ids[i], ids[j]], "cible": 1, "duree": 90, "prime": 1_500_000,
						"rep": 5, "texte": "Relier %s et %s par la route" % [pays.nom_de(ids[i]), pays.nom_de(ids[j])]})
					break
			if out.size() > 0 and String(out[out.size() - 1].type) == "relier":
				break
	if lignes() == 0 and population.persons.size() >= 150 and not en_cours.has("ligne:-1"):
		out.append({"type": "ligne", "vid": -1, "cible": 1, "duree": 60, "prime": 1_000_000, "rep": 4,
			"texte": "Créer une ligne de transport en commun (touche L)"})
	return out


func _completer_missions() -> void:
	var c := candidates()
	var d := jour()
	var i := 0
	while missions.size() < MISSIONS_MAX and not c.is_empty() and i < 10:
		i += 1
		var k := absi(hash(str(d) + str(_next))) % c.size()
		var m: Dictionary = c[k]
		c.remove_at(k)
		m["id"] = _next
		_next += 1
		m["debut"] = d
		m["fin"] = d + int(m.duree)
		m["prime"] = ReglagesPartie.prix(int(m.prime))
		if not m.has("vid2"):
			m["vid2"] = []
		missions.append(m)
		message.emit("Nouvelle mission du pays : %s (avant %d jours, prime %s). Touche J." % [String(m.texte), int(m.duree),
			BuildingSystem.format_money(int(m.prime))])


## Mission réussie ?
func reussie(m: Dictionary) -> bool:
	var vid := int(m.vid)
	match String(m.type):
		"habitants":
			return _hab(vid) >= int(m.cible)
		"ecole":
			return compter(vid, "ecole") >= 1
		"satisfaction":
			return satisfaction(vid) >= int(m.cible)
		"chomage":
			return chomage(vid) < float(m.cible)
		"dette":
			var b := BudgetCommunal.instance
			return b == null or (b.etat_de(vid).get("emprunts", []) as Array).is_empty()
		"fonder":
			return communes.villages.size() >= int(m.cible)
		"relier":
			var v2: Array = m.vid2
			return v2.size() == 2 and relies(int(v2[0]), int(v2[1]))
		"ligne":
			return lignes() >= 1
	return false


## Où en est une mission (texte court).
func progres(m: Dictionary) -> String:
	var vid := int(m.vid)
	match String(m.type):
		"habitants":
			return "%d / %d habitants" % [_hab(vid), int(m.cible)]
		"satisfaction":
			return "satisfaction %d / %d" % [satisfaction(vid), int(m.cible)]
		"chomage":
			return "chômage %.1f %%" % chomage(vid)
		"fonder":
			return "%d / %d villes" % [communes.villages.size(), int(m.cible)]
	return "en cours"


func _verifier_missions() -> void:
	var d := jour()
	for m in missions.duplicate():
		var vid := int(m.vid)
		if vid >= 0 and not communes.villages.has(vid):
			missions.erase(m)
			continue
		if reussie(m):
			missions.erase(m)
			reussies += 1
			pays.prime(int(m.prime), "Mission réussie : " + String(m.texte))
			message.emit("Mission réussie : %s ! Le pays reçoit %s." % [String(m.texte), BuildingSystem.format_money(int(m.prime))])
			ajouter_reputation(float(m.rep), "mission réussie")
			_historiser(m, true)
		elif d > int(m.fin):
			missions.erase(m)
			message.emit("Mission ratée : %s." % String(m.texte))
			ajouter_reputation(-3.0, "mission ratée")
			_historiser(m, false)


func _historiser(m: Dictionary, ok: bool) -> void:
	historique.append({"texte": String(m.texte), "reussie": ok, "jour": jour()})
	while historique.size() > 20:
		historique.pop_front()


## Abandonner une mission (petite perte de réputation).
func abandonner(id: int) -> void:
	for m in missions:
		if int(m.id) == id:
			missions.erase(m)
			ajouter_reputation(-1.0, "mission abandonnée")
			_historiser(m, false)
			changed.emit()
			return


# --- Succès ----------------------------------------------------------------------------------

func succes_debloque(id: String) -> void:
	if succes.has(id) or not SUCCES.has(id):
		return
	succes[id] = jour()
	message.emit("Succès débloqué : « %s » — %s" % [SUCCES[id][0], SUCCES[id][1]])
	ajouter_reputation(2.0)


func _verifier_succes() -> void:
	var n := communes.villages.size()
	var hab := 0
	for vid in communes.villages:
		hab += _hab(vid)
	if n >= 1:
		succes_debloque("premier_village")
	if n >= 3:
		succes_debloque("trois_villes")
	if hab >= 100:
		succes_debloque("cent")
	if hab >= 1000:
		succes_debloque("mille")
	if hab >= 10000:
		succes_debloque("dix_mille")
	var best := 0
	for vid in communes.villages:
		best = maxi(best, palier_de(vid))
	if best >= 2:
		succes_debloque("bourg")
	if best >= 3:
		succes_debloque("ville")
	if best >= 5:
		succes_debloque("metropole")
	var b := BudgetCommunal.instance
	if hab >= 500 and b != null:
		var dette := 0.0
		for k in pays.cles():
			dette += b.dette_de(int(k))
		if dette <= 0.0:
			succes_debloque("sans_dette")
	if hab >= 200:
		var tous := true
		for vid in communes.villages:
			if _hab(vid) > 0 and satisfaction(vid) < 70:
				tous = false
		if tous:
			succes_debloque("heureux")
	if n >= 2 and not succes.has("relies"):
		var ids: Array = communes.villages.keys()
		var ok := true
		for i in range(1, ids.size()):
			if not relies(ids[0], ids[i]):
				ok = false
				break
		if ok:
			succes_debloque("relies")
	if reussies >= 5:
		succes_debloque("missions5")
	if reussies >= 20:
		succes_debloque("missions20")
	if pays.solde(Pays.PAYS) >= 50_000_000 and not pays.illimite():
		succes_debloque("riche")


# --- Sauvegarde --------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var pl := {}
	for vid in paliers:
		pl[str(vid)] = int(paliers[vid])
	return {"version": 1, "paliers": pl, "missions": missions.duplicate(true), "historique": historique.duplicate(true),
		"reussies": reussies, "succes": succes.duplicate(), "reputation": reputation, "next": _next}


func from_dict(d: Dictionary) -> void:
	clear()
	for k in (d.get("paliers", {}) as Dictionary):
		paliers[int(k)] = int(d.paliers[k])
	for m in d.get("missions", []):
		var x: Dictionary = (m as Dictionary).duplicate(true)
		for key in ["id", "vid", "cible", "debut", "fin", "prime", "duree"]:
			if x.has(key):
				x[key] = int(x[key])
		x["rep"] = float(x.get("rep", 3))
		var v2 := []
		for v in x.get("vid2", []):
			v2.append(int(v))
		x["vid2"] = v2
		missions.append(x)
	historique = (d.get("historique", []) as Array).duplicate(true)
	reussies = int(d.get("reussies", 0))
	for k in (d.get("succes", {}) as Dictionary):
		succes[String(k)] = int(d.succes[k])
	reputation = clampf(float(d.get("reputation", REP_DEPART)), 0.0, 100.0)
	_next = maxi(1, int(d.get("next", missions.size() + 1)))
	# Les mairies déjà perdues au chargement ne coûtent pas une 2e fois.
	if Avis.instance != null and communes != null:
		for vid in communes.villages:
			if not Avis.instance.joueur_maire_de(int(vid)):
				_perdues[vid] = true
	changed.emit()
