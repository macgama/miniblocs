class_name Objectifs
extends Node
## Objectifs du joueur (panneau Objectifs, touche J) :
##   - Paliers de chaque ville : Hameau, Village, Bourg, Ville, Ville moyenne,
##     Grande ville, Métropole. Pour monter, il faut la population ET des conditions (habitants
##     satisfaits, école, pompiers et police, hôpital, transports, caisse saine).
##     Chaque palier gagné rapporte une prime au pays et de la réputation. Un
##     palier gagné n'est jamais perdu.
##   - Missions du pays : 3 missions à la fois, tirées selon l'état des villes
##     (faire grandir une ville, ouvrir une école, relier deux villes, fonder une
##     ville, rembourser ses dettes, faire baisser le chômage, créer une ligne…),
##     avec un délai et une prime. Ratée : la réputation baisse.
##   - Succès : des étapes à débloquer une fois pour toutes.
##   - Défi du jour : un petit objectif qui change chaque jour (vrai calendrier),
##     le même pour tous les joueurs ce jour-là. Réussi, il rapporte une prime qui
##     grandit avec la série de jours réussis d'affilée (jusqu'à ×2 à 10 jours).
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
	{"nom": "Ville moyenne", "hab": 5000, "sat": 58, "prime": 5_000_000, "rep": 12, "cond": ["ecole", "pompiers", "police", "hopital", "caisse"]},
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
	"deux_pays": ["Passe-frontière", "Avoir des villes dans deux pays."],
	"sans_frontieres": ["Sans frontières", "Avoir des villes dans trois pays."],
	"libre_echange": ["Libre-échange", "1 M€ de marchandises par mois entre tes pays."],
	"classe_moyenne": ["La classe moyenne", "300 habitants ou plus et la moitié des foyers en Classe moyenne ou mieux (Maj+N)."],
	"beaux_quartiers": ["Les beaux quartiers", "25 foyers Très aisés (Maj+N)."],
	"semaine": ["Fidèle au poste", "Réussir le défi du jour 7 jours d'affilée."],
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
## Défi du jour : {date, type, texte, cible, depart, vu, acc, fait, prime}.
var defi := {}
## Jours de défi réussis d'affilée, et date du dernier réussi.
var serie := 0
var serie_date := ""
## Date du jour (AAAA-MM-JJ, vrai calendrier) ; remplaçable dans les tests.
var date_du_jour: Callable = func() -> String: return Time.get_date_string_from_system()
var _defi_ms := -100000


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
	_frontiere = "?"
	_cache.clear()
	missions.clear()
	historique.clear()
	succes.clear()
	reussies = 0
	reputation = REP_DEPART
	_next = 1
	_dernier_jour = -1
	_perdues.clear()
	defi = {}
	serie = 0
	serie_date = ""
	changed.emit()


func jour() -> int:
	return int(population.now().day) if population != null else 0


func _process(_delta: float) -> void:
	if population == null or communes == null:
		return
	if Time.get_ticks_msec() - _defi_ms > 2000:
		_defi_ms = Time.get_ticks_msec()
		suivre_defi()
	var d := jour()
	if d == _dernier_jour:
		return
	_dernier_jour = d
	_cache.clear()
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


## Chiffres recalculés au plus toutes les CACHE_MS (le résumé à l'écran les lit chaque seconde).
const CACHE_MS := 5000
var _cache := {}


func _en_cache(cle: String) -> Variant:
	var c: Array = _cache.get(cle, [])
	if not c.is_empty() and Time.get_ticks_msec() - int(c[0]) < CACHE_MS:
		return c[1]
	return null


func _garder(cle: String, v: Variant) -> Variant:
	_cache[cle] = [Time.get_ticks_msec(), v]
	return v


func satisfaction(vid: int) -> int:
	var av := Avis.instance
	if av == null:
		return 50
	var c = _en_cache("sat:%d" % vid)
	if c != null:
		return int(c)
	var garde := av.ville_vid
	av.examiner(vid)
	var m := av.moyenne()
	av.examiner(garde)
	return int(_garder("sat:%d" % vid, m))


func compter(vid: int, type_id: String) -> int:
	var c = _en_cache("compte")
	if c == null or int(c.n) != buildings.buildings.size():
		# Un seul passage sur les bâtiments pour toutes les villes et tous les types.
		var par := {}
		for bid in buildings.buildings:
			var b: Dictionary = buildings.buildings[bid]
			if b.get("chantier", false):
				continue
			var k := "%d:%s" % [communes.village_de(bid), String(b.t)]
			par[k] = int(par.get(k, 0)) + 1
		c = _garder("compte", {"n": buildings.buildings.size(), "par": par})
	return int(c.par.get("%d:%s" % [vid, type_id], 0))


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
		pays.prime(prime, "Prime : %s devient %s" % [pays.nom_de(vid), String(p.nom)], vid)
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
	var c = _en_cache("chomage")
	if c == null:
		# Un seul passage sur les habitants pour toutes les villes.
		var par := {}
		for pid in population.persons:
			var p: Dictionary = population.persons[pid]
			var s := population.stage(p)
			if s != "actif" and s != "chomeur":
				continue
			var v := communes.village_de(population.home_of(p))
			var e: Array = par.get(v, [0, 0])
			e[0 if s == "actif" else 1] += 1
			par[v] = e
		c = _garder("chomage", par)
	var e: Array = c.get(vid, [0, 0])
	return 100.0 * e[1] / (e[0] + e[1]) if e[0] + e[1] > 0 else 0.0


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
	# Plusieurs pays : s'installer de l'autre côté de la frontière, puis commercer.
	if pays.cles_nations().size() == 1 and population.persons.size() >= 400 and frontiere_proche() != "" \
			and not en_cours.has("pays:-1"):
		out.append({"type": "pays", "vid": -1, "cible": 2, "duree": 150, "prime": 2_000_000, "rep": 6,
			"texte": "Fonder une ville de l'autre côté de la frontière (%s)" % Villes.nom_pays(frontiere_proche())})
	if pays.cles_nations().size() >= 2 and Production.instance != null and not en_cours.has("commerce:-1"):
		var c := commerce_pays()
		var cible := maxi(50_000, snappedi(roundi(c * 1.5) + 20_000, 10_000))
		out.append({"type": "commerce", "vid": -1, "cible": cible, "duree": 90, "prime": 1_500_000, "rep": 5,
			"texte": "Commerce entre tes pays : %s par mois" % BuildingSystem.format_money(cible)})
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
		"pays":
			return pays.cles_nations().size() >= int(m.cible)
		"commerce":
			return commerce_pays() >= float(m.cible)
	return false


## Commerce du mois entre tes pays (€) : le mois en cours ou, s'il vient de
## commencer, le précédent.
func commerce_pays() -> float:
	if Production.instance == null:
		return 0.0
	return maxf(float(Production.instance.commerce_total(false).pays), float(Production.instance.commerce_total(true).pays))


var _frontiere := "?"


## Code d'un autre pays réel à moins de 15 km du chef-lieu ("" : aucun).
func frontiere_proche() -> String:
	if _frontiere != "?":
		return _frontiere
	_frontiere = ""
	if communes.villages.is_empty():
		_frontiere = "?"
		return ""
	var c: Vector2 = communes.villages[communes.principal()].c
	var ici := pays.code_au_point(c.x, c.y)
	for r in [5000.0, 10000.0, 15000.0]:
		for i in 16:
			var a := TAU * i / 16.0
			var code := pays.code_au_point(c.x + cos(a) * r, c.y + sin(a) * r)
			if code != "" and code != ici:
				_frontiere = code
				return code
	return ""


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
		"commerce":
			return "%s / %s par mois" % [BuildingSystem.format_money(roundi(commerce_pays())), BuildingSystem.format_money(int(m.cible))]
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
			pays.prime(int(m.prime), "Mission réussie : " + String(m.texte), vid if vid >= 0 else -1)
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
	var nvx := NiveauxVie.instance
	if nvx != null and nvx.population == population:
		if hab >= 300 and nvx.part_au_moins(2) >= 0.5:
			succes_debloque("classe_moyenne")
		if int(nvx.bilan().foyers[4]) >= 25:
			succes_debloque("beaux_quartiers")
	var best := 0
	for vid in communes.villages:
		best = maxi(best, palier_de(vid))
	if best >= 2:
		succes_debloque("bourg")
	if best >= 3:
		succes_debloque("ville")
	if best >= PALIERS.size() - 1:
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
	var nn := pays.cles_nations().size()
	if nn >= 2 and pays.a_des_villes():
		succes_debloque("deux_pays")
	if nn >= 3 and pays.a_des_villes():
		succes_debloque("sans_frontieres")
	if nn >= 2 and commerce_pays() >= 1_000_000:
		succes_debloque("libre_echange")
	var tresor := 0
	for nk in pays.cles_nations():
		tresor += pays.solde(int(nk))
	if tresor >= 50_000_000 and not pays.illimite():
		succes_debloque("riche")


# --- Sauvegarde --------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var pl := {}
	for vid in paliers:
		pl[str(vid)] = int(paliers[vid])
	return {"version": 1, "paliers": pl, "missions": missions.duplicate(true), "historique": historique.duplicate(true),
		"reussies": reussies, "succes": succes.duplicate(), "reputation": reputation, "next": _next,
		"defi": defi.duplicate(true), "serie": serie, "serie_date": serie_date, "rangs": 2}


func from_dict(d: Dictionary) -> void:
	clear()
	for k in (d.get("paliers", {}) as Dictionary):
		var i := int(d.paliers[k])
		# Avant le rang « Ville moyenne » (inséré en 5e position) : décalage.
		if int(d.get("rangs", 1)) < 2 and i >= 4:
			i += 1
		paliers[int(k)] = i
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
	defi = (d.get("defi", {}) as Dictionary).duplicate(true)
	serie = int(d.get("serie", 0))
	serie_date = String(d.get("serie_date", ""))
	# Les mairies déjà perdues au chargement ne coûtent pas une 2e fois.
	if Avis.instance != null and communes != null:
		for vid in communes.villages:
			if not Avis.instance.joueur_maire_de(int(vid)):
				_perdues[vid] = true
	changed.emit()


# --- Défi du jour --------------------------------------------------------------------------

const DEFI_PRIME := 100_000
const DEFI_TYPES := ["habitants", "commerce", "construire", "voies", "satisfaction"]
## Bâtiments que le défi « construire » peut demander.
const DEFI_BATIMENTS := ["parc", "aire_jeux", "ecole", "boulangerie", "superette", "gymnase", "pompiers", "police"]


## Habitants de toutes les villes.
func habitants_total() -> int:
	var n := 0
	for vid in communes.villages:
		n += _hab(int(vid))
	return n


func _voies_m() -> float:
	if transport == null or transport.network == null:
		return 0.0
	var m := 0.0
	for e in transport.network.edges:
		m += float(transport.network.edges[e].len)
	return m


func _compter_partout(t: String) -> int:
	var n := 0
	for vid in communes.villages:
		n += compter(int(vid), t)
	return n


func _meilleure_ville() -> int:
	var best := -1
	for vid in communes.villages:
		if best < 0 or _hab(int(vid)) > _hab(best):
			best = int(vid)
	return best


## Valeur suivie par le défi en cours.
func _mesure(t: String) -> float:
	match t:
		"habitants":
			return float(habitants_total())
		"commerce":
			var pr := Production.instance
			return float(pr.commerce_total(false).villes) if pr != null else 0.0
		"construire":
			return float(_compter_partout(String(defi.get("ref", ""))))
		"voies":
			return _voies_m()
		"satisfaction":
			var v := int(defi.get("vid", -1))
			return float(satisfaction(v)) if communes.villages.has(v) else 0.0
	return 0.0


## Tire le défi d'une date : le même pour tous les joueurs ce jour-là.
func _nouveau_defi(date: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("defi:" + date)
	var types := DEFI_TYPES.duplicate()
	if communes.villages.size() < 2:
		types.erase("commerce")
	var hab := habitants_total()
	if hab < 50:
		types.erase("satisfaction")
	var t := String(types[rng.randi() % types.size()])
	defi = {"date": date, "type": t, "fait": false, "acc": 0.0}
	var cible := 0.0
	var texte := ""
	match t:
		"habitants":
			cible = maxf(20.0, roundf(hab * 0.03))
			texte = "Accueillir %d nouveaux habitants" % int(cible)
		"commerce":
			cible = maxf(5000.0, roundf(float(Production.instance.commerce_total(true).villes) * 0.05 / 1000.0) * 1000.0) if Production.instance != null else 5000.0
			texte = "Vendre %s de marchandises entre tes villes" % BuildingSystem.format_money(int(cible))
		"construire":
			var b := String(DEFI_BATIMENTS[rng.randi() % DEFI_BATIMENTS.size()])
			defi.ref = b
			cible = 1.0
			texte = "Construire : %s" % String(BuildingCatalog.get_type(b).get("name", b)).to_lower()
		"voies":
			cible = 500.0
			texte = "Poser 500 m de routes, de rails ou de chemins"
		"satisfaction":
			var v := _meilleure_ville()
			defi.vid = v
			cible = 3.0
			texte = "Gagner 3 points de satisfaction à %s" % pays.nom_de(v)
	defi.cible = cible
	defi.texte = texte
	defi.prime = ReglagesPartie.prix(roundi(DEFI_PRIME * (1.0 + 0.1 * mini(serie, 10))))
	defi.depart = _mesure(t)
	defi.vu = defi.depart
	changed.emit()


## Progrès du défi (0 à 1).
func progres_defi() -> float:
	if defi.is_empty():
		return 0.0
	if bool(defi.fait):
		return 1.0
	return clampf(float(defi.acc) / maxf(float(defi.cible), 0.001), 0.0, 1.0)


## Suivi du défi (toutes les 2 secondes) : nouveau jour, progrès, réussite.
func suivre_defi() -> void:
	if communes == null or communes.villages.is_empty():
		return
	var date := String(date_du_jour.call())
	if String(defi.get("date", "")) != date:
		# Série cassée si hier n'a pas été réussi.
		if serie_date != "" and serie_date != date and serie_date != _veille(date):
			serie = 0
		_nouveau_defi(date)
	if bool(defi.fait):
		return
	var t := String(defi.type)
	var cur := _mesure(t)
	if t == "commerce" and cur < float(defi.vu):
		# Nouveau mois de comptes : on repart de zéro.
		defi.vu = 0.0
	if t == "satisfaction":
		defi.acc = cur - float(defi.depart)
	elif t == "construire" or t == "habitants" or t == "voies":
		defi.acc = maxf(float(defi.acc), cur - float(defi.depart))
	else:
		defi.acc = float(defi.acc) + maxf(0.0, cur - float(defi.vu))
	defi.vu = cur
	if float(defi.acc) >= float(defi.cible):
		defi.fait = true
		serie += 1
		serie_date = date
		var nk := pays.nation_choisie() if pays != null else -1
		pays.prime(int(defi.prime), "Défi du jour réussi : %s" % String(defi.texte), nk)
		ajouter_reputation(1.0, "défi du jour")
		message.emit("Défi du jour réussi : %s ! Prime de %s, série de %d jour%s." % [String(defi.texte),
			BuildingSystem.format_money(int(defi.prime)), serie, "s" if serie > 1 else ""])
		if serie >= 7:
			succes_debloque("semaine")
	changed.emit()


static func _veille(date: String) -> String:
	var u := Time.get_unix_time_from_datetime_string(date + "T12:00:00")
	return Time.get_date_string_from_unix_time(u - 86400)
