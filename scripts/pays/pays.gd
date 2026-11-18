class_name Pays
extends Node
## Le pays qui chapeaute les villes du joueur (panneau Pays, Maj+P).
##
## Chaque ville (village fondé par une Maison de commune) a sa propre caisse,
## ses impôts, ses emprunts et sa tutelle. Le pays a aussi sa caisse :
##   - recettes : impôt national (part des impôts locaux de chaque ville), primes
##     des objectifs ;
##   - dépenses : dotation par habitant versée aux villes, entretien des voies
##     hors des villes, subventions décidées par le joueur, capital de départ
##     des nouvelles villes.
##
## Qui paie quoi :
##   - un bâtiment, un zonage, un chantier : la ville sur le territoire de
##     laquelle il se trouve ; hors de toute ville, le pays ;
##   - le reste (panneaux, éditeurs) : la ville choisie, c'est-à-dire celle que
##     regarde la caméra (ou celle qu'on a épinglée dans le panneau Pays).
##
## Mécanique : BuildingSystem.money contient toujours la caisse « active ». Les
## autres caisses sont rangées dans `comptes`. Pour payer avec une autre caisse :
##   var p := Pays.au_point(x, z)   # ou Pays.entrer_static(cle)
##   ... buildings.money -= prix ...
##   Pays.retour(p)
## Les recettes globales (ventes, billets…) passent par Pays.crediter(bs, v),
## qui les répartit entre les villes selon leur population.
##
## Plusieurs pays (choix de Gaël, 2026-11-14 : « un pays par pays réel ») :
## chaque ville appartient au pays réel de son lieu (France, Suisse,
## Allemagne…). Le joueur dirige chacun de ces pays : une caisse, un impôt
## national, une dotation et une douane par pays. Le premier pays a la clé
## PAYS (0, comme avant) ; les suivants NATION_BASE + n. Un nouveau pays reçoit
## de son gouvernement une aide d'installation (DEPART_NATION). Les livraisons
## entre entreprises de deux pays paient la douane du pays qui importe.

signal changed
signal message(text: String)

## Clé de la caisse du pays (les villes ont la clé de leur village, à partir de 1).
const PAYS := 0
## Impôt national par défaut : part des impôts locaux (foncier, entreprises).
const TAUX_NATIONAL := 0.10
const TAUX_NATIONAL_MAX := 0.30
## Capital versé par le pays à une nouvelle ville (× coût des constructions).
const CAPITAL_VILLE := 1_000_000
## Part de la caisse du pays versée à la toute première ville.
const PART_PREMIERE := 0.6
## Montants proposés pour les subventions.
const SUBVENTIONS := [100_000, 500_000, 1_000_000, 5_000_000]
## Partie d'avant le pays : part de l'argent gardée par le pays.
const PART_PAYS_ANCIENNE := 0.2
## Clés des pays suivants (le premier pays garde la clé PAYS = 0).
const NATION_BASE := 1_000_000
## Aide d'installation du gouvernement d'un nouveau pays (× coût des constructions).
const DEPART_NATION := 5_000_000
## Douane par défaut : part de la valeur des marchandises qui entrent d'un autre de tes pays.
const TAUX_DOUANE := 0.05
const TAUX_DOUANE_MAX := 0.30

static var instance: Pays
## Multijoueur : caisses personnelles des joueurs sans ville (clés JOUEUR_BASE, JOUEUR_BASE - 1…).
const JOUEUR_BASE := -1000
## Multijoueur (serveur) : caisse qui paie ce que fait le joueur dont on applique
## l'action, quel que soit le lieu (-1 : la règle habituelle, la ville du lieu).
static var payeur_force := -1

var buildings: BuildingSystem
var communes: Communes
var population: Population
var budget: BudgetCommunal
var network: TransportNetwork

## Nom du pays ("" : celui du drapeau de la première ville).
var nom := ""
## Caisses rangées : clé -> euros. La caisse active est dans buildings.money.
var comptes := {}
## Clé de la caisse qui est dans buildings.money.
var actif := PAYS
## Ville choisie (caisse affichée, budget M) ; PAYS tant qu'il n'y a pas de ville.
var selection := PAYS
## La ville choisie ne suit plus la caméra.
var epingle := false
## Impôt national (0 à TAUX_NATIONAL_MAX) et multiplicateur de la dotation (0 à 2).
var taux_national := TAUX_NATIONAL
var dotation := 1.0
## Pays dirigés : clé de caisse -> {code, nom, taux_national, dotation, douane}.
## Pour le pays PAYS, taux_national et dotation sont les variables ci-dessus.
var nations := {}
## Pays de chaque ville : vid -> clé du pays.
var ville_nation := {}
## Pour les tests : Callable(Vector2 position) -> code du pays, à la place de la géographie.
var pays_de: Callable
var _codes_cache := {}
## Dernières opérations entre caisses : {jour, de, a, montant, motif}.
var journal: Array = []
## Point regardé par la caméra (x, z), fourni par la scène.
var foyer: Callable
## Les villes reçoivent leur capital à la fondation (faux pendant un chargement).
var capital_auto := true
var _t := 0.0


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func setup(bs: BuildingSystem, cm: Communes, pop: Population, bud: BudgetCommunal, net: TransportNetwork = null) -> void:
	buildings = bs
	communes = cm
	population = pop
	budget = bud
	network = net
	if communes != null:
		communes.fonde.connect(_on_fonde)
		communes.fusion.connect(_on_fusion)


func clear() -> void:
	# Tout l'argent revient dans la caisse active, qui devient celle du pays.
	if buildings != null:
		for k in comptes:
			buildings.money += int(comptes[k])
	comptes.clear()
	actif = PAYS
	selection = PAYS
	epingle = false
	nom = ""
	taux_national = TAUX_NATIONAL
	dotation = 1.0
	nations.clear()
	ville_nation.clear()
	_codes_cache.clear()
	journal.clear()
	if budget != null:
		budget.oublier_communes()
	changed.emit()


# --- Questions ------------------------------------------------------------------------

## Le pays a-t-il au moins une ville ?
func a_des_villes() -> bool:
	return communes != null and not communes.villages.is_empty()


## Clés des caisses : les villes puis les pays (le premier pays en dernier).
func cles() -> Array:
	var out := []
	if communes != null:
		var ids: Array = communes.villages.keys()
		ids.sort()
		out.append_array(ids)
	var ns := cles_nations()
	ns.reverse()
	out.append_array(ns)
	return out


## La clé est-elle celle d'un pays (et pas d'une ville) ?
static func est_nation(k: int) -> bool:
	return k == PAYS or k >= NATION_BASE


static func est_ville(k: int) -> bool:
	return k > 0 and k < NATION_BASE


## Clés des pays dirigés, le premier d'abord (au moins PAYS).
func cles_nations() -> Array:
	var out := [PAYS]
	var ks: Array = nations.keys()
	ks.sort()
	for k in ks:
		if int(k) != PAYS:
			out.append(int(k))
	return out


func plusieurs_nations() -> bool:
	return cles_nations().size() > 1


## Pays d'une ville (ou le pays lui-même).
func nation_de(k: int) -> int:
	if est_nation(k):
		return k
	return int(ville_nation.get(k, PAYS))


func nation_du_batiment(bid: int) -> int:
	return nation_de(payeur_du_batiment(bid))


## Villes d'un pays.
func villes_de(nk: int) -> Array:
	var out := []
	if communes == null:
		return out
	var ids: Array = communes.villages.keys()
	ids.sort()
	for vid in ids:
		if nation_de(int(vid)) == nk:
			out.append(int(vid))
	return out


## Pays de la ville choisie (celui que règle le panneau Pays).
func nation_choisie() -> int:
	return nation_de(selection)


func code_de(nk: int) -> String:
	return String(nations.get(nk, {}).get("code", ""))


func nation_du_code(code: String) -> int:
	for k in nations:
		if String(nations[k].get("code", "")) == code:
			return int(k)
	return -1


func nom_de(k: int) -> String:
	if est_caisse_joueur(k):
		return "ta caisse personnelle"
	if est_nation(k):
		return nom_nation(k)
	if communes != null and communes.villages.has(k):
		return String(communes.villages[k].nom)
	return "?"


func nom_pays() -> String:
	return nom_nation(PAYS)


func nom_nation(nk: int) -> String:
	if nk == PAYS and nom.strip_edges() != "":
		return nom.strip_edges()
	var n := String(nations.get(nk, {}).get("nom", "")).strip_edges()
	if n != "":
		return n
	var code := code_de(nk)
	if code != "":
		var np := Villes.nom_pays(code)
		if np != "" and np.to_lower() != code:
			return np
		return Drapeaux.nom(code)
	if nk == PAYS and communes != null and not communes.villages.is_empty():
		var dr := String(communes.villages[communes.principal()].get("drapeau", ""))
		if dr != "":
			return Drapeaux.nom(dr)
	return "Mon pays" if nk == PAYS else "Pays %d" % (nk - NATION_BASE + 1)


func renommer_nation(nk: int, n: String) -> void:
	if nk == PAYS:
		nom = n.strip_edges()
	elif nations.has(nk):
		nations[nk]["nom"] = n.strip_edges()
	changed.emit()


## Code du pays réel au point (x, z) : la ville du monde la plus proche (mis en cache par km²).
func code_au_point(x: float, z: float) -> String:
	if pays_de.is_valid():
		return String(pays_de.call(Vector2(x, z))).to_lower()
	var cell := Vector2i(floori(x / 1000.0), floori(z / 1000.0))
	if _codes_cache.has(cell):
		return String(_codes_cache[cell])
	var code := ""
	var w: TerrainWorld = communes.world if communes != null else null
	var olat := w.origin_lat if w != null else GameStart.lat
	var olon := w.origin_lon if w != null else GameStart.lon
	var lat := Geo.local_to_lat(olat, z)
	var lon := Geo.local_to_lon(olat, olon, x)
	var v := Villes.plus_proche(lat, lon, 60.0)
	if not v.is_empty():
		code = String(v.get("pays", "")).to_lower()
	if code == "":
		code = GameStart.pays.to_lower()
	_codes_cache[cell] = code
	return code


## Code du pays réel d'une ville (d'après son centre).
func code_de_ville(vid: int) -> String:
	if communes == null or not communes.villages.has(vid):
		return ""
	var c: Vector2 = communes.villages[vid].c
	return code_au_point(c.x, c.y)


## Pays qui paie hors des villes au point (x, z) : celui du lieu s'il est à toi,
## sinon celui de la ville la plus proche.
func nation_au_point(x: float, z: float) -> int:
	if nations.size() <= 1:
		return PAYS
	var nk := nation_du_code(code_au_point(x, z))
	if nk >= 0:
		return nk
	var best := PAYS
	var best_d := INF
	if communes != null:
		for vid in communes.villages:
			var d: float = (communes.villages[vid].c as Vector2).distance_squared_to(Vector2(x, z))
			if d < best_d:
				best_d = d
				best = nation_de(int(vid))
	return best


func taux_de(nk: int) -> float:
	if nk == PAYS:
		return taux_national
	return float(nations.get(nk, {}).get("taux_national", TAUX_NATIONAL))


func dotation_de(nk: int) -> float:
	if nk == PAYS:
		return dotation
	return float(nations.get(nk, {}).get("dotation", 1.0))


func douane_de(nk: int) -> float:
	return float(nations.get(nk, {}).get("douane", TAUX_DOUANE))


## Argent d'une caisse.
func solde(k: int) -> int:
	if k == actif:
		return buildings.money if buildings != null else 0
	return int(comptes.get(k, 0))


func _poser(k: int, v: int) -> void:
	if k == actif:
		if buildings != null:
			buildings.money = v
	else:
		comptes[k] = v


func illimite() -> bool:
	return buildings != null and buildings.unlimited_money


## Caisse qui paie ce qui se fait au point (x, z) : la ville du lieu, sinon le pays.
func payeur_au_point(x: float, z: float) -> int:
	if payeur_force != -1:
		return payeur_force
	if communes == null:
		return PAYS
	var v := communes.village_au_point(x, z)
	return v if v >= 0 else nation_au_point(x, z)


func payeur_du_batiment(bid: int) -> int:
	if communes == null or buildings == null or not buildings.buildings.has(bid):
		return actif
	var v := int(communes.bat_village.get(bid, -2))
	if v == -2:
		v = communes.village_du_batiment(bid)
	if v >= 0:
		return v
	var c := communes._centre_bat(bid)
	return nation_au_point(c.x, c.y)


func payeur_du_rect(rect: Rect2i) -> int:
	return payeur_au_point(rect.position.x + rect.size.x * 0.5, rect.position.y + rect.size.y * 0.5)


## Caisse propriétaire d'une voie (son milieu).
func payeur_de_voie(eid: int) -> int:
	if network == null or not network.edges.has(eid):
		return actif
	var p := network.point_at(eid, float(network.edges[eid].len) * 0.5)
	return payeur_au_point(p.x, p.z)


## Caisse d'un chantier suivi (SuiviChantiers), d'après sa clé.
func payeur_de_cle(cle: String) -> int:
	if payeur_force != -1:
		return payeur_force
	if cle.begins_with("voie:") or cle.begins_with("reparation:") or cle.begins_with("evolution:"):
		var eid := int(cle.get_slice(":", 1))
		if network != null and network.edges.has(eid):
			return payeur_de_voie(eid)
	return actif


# --- Changer de caisse active ------------------------------------------------------------

## Met la caisse k dans buildings.money (l'ancienne est rangée).
func activer(k: int) -> void:
	if k == actif or buildings == null:
		return
	comptes[actif] = buildings.money
	actif = k
	buildings.money = int(comptes.get(k, 0))
	comptes.erase(k)


## Entre dans la caisse k et renvoie l'ancienne (à rendre avec sortir()).
func entrer(k: int) -> int:
	var p := actif
	activer(k)
	return p


func sortir(p: int) -> void:
	activer(p)


## Raccourcis sans dépendance : -1 si pas de pays.
static func au_point(x: float, z: float) -> int:
	if payeur_force != -1 and instance != null:
		return instance.entrer(payeur_force)
	if instance == null or not instance.a_des_villes():
		return -1
	return instance.entrer(instance.payeur_au_point(x, z))


static func au_rect(rect: Rect2i) -> int:
	if payeur_force != -1 and instance != null:
		return instance.entrer(payeur_force)
	if instance == null or not instance.a_des_villes():
		return -1
	return instance.entrer(instance.payeur_du_rect(rect))


static func au_batiment(bid: int) -> int:
	if instance == null or not instance.a_des_villes():
		return -1
	return instance.entrer(instance.payeur_du_batiment(bid))


static func a_la_caisse(k: int) -> int:
	if instance == null or (k < 0 and not est_caisse_joueur(k)):
		return -1
	return instance.entrer(k)


static func retour(p: int) -> void:
	if instance != null and (p >= 0 or est_caisse_joueur(p)):
		instance.sortir(p)


## Caisse d'un bâtiment posé (chantier, remboursement) : celle qui l'a payé en
## multijoueur (clé « caisse », hors de ses villes), sinon la ville du lieu.
static func du_batiment(b: Dictionary, rect: Rect2i) -> int:
	if b.has("caisse"):
		return a_la_caisse(int(b.caisse))
	return au_rect(rect)


## Caisse personnelle d'un joueur sans ville (multijoueur).
static func est_caisse_joueur(k: int) -> bool:
	return k <= JOUEUR_BASE


## Caisse active du moment (pour la retenir, par exemple à la création d'un chantier).
static func caisse_active() -> int:
	return instance.actif if instance != null else -1


## Recette d'un système global (ventes, billets, collectes) : répartie entre les
## villes selon leur population (le pays s'il n'y a pas de ville).
static func crediter(bs: BuildingSystem, v: int) -> void:
	if bs == null or bs.unlimited_money or v == 0:
		return
	if instance == null or not instance.a_des_villes():
		bs.money += v
		return
	instance._repartir(v)


func _repartir(v: int) -> void:
	var parts := parts_population()
	var reste := v
	var ks: Array = parts.keys()
	for i in ks.size():
		var k: int = ks[i]
		var x := reste if i == ks.size() - 1 else roundi(float(v) * float(parts[k]))
		reste -= x
		_poser(k, solde(k) + x)


## Part de chaque ville dans la population (à parts égales s'il n'y a personne).
func parts_population() -> Dictionary:
	var out := {}
	if communes == null or communes.villages.is_empty():
		out[PAYS] = 1.0
		return out
	var tot := 0.0
	for vid in communes.villages:
		var h := float(communes.stats.get(vid, {}).get("hab", 0))
		out[vid] = h
		tot += h
	for vid in out:
		out[vid] = (float(out[vid]) / tot) if tot > 0.0 else 1.0 / out.size()
	return out


## Le joueur décide-t-il dans cette ville (il en est le maire) ?
func joueur_maire(vid: int) -> bool:
	if est_nation(vid):
		return true
	if Avis.instance != null:
		return Avis.instance.joueur_decide_de(vid)
	return true


# --- Ville choisie ---------------------------------------------------------------------

## Choisit la ville gérée (caisse affichée, budget M). epingler : ne suit plus la caméra.
func choisir(k: int, epingler := false) -> void:
	if not est_nation(k) and (communes == null or not communes.villages.has(k)):
		return
	epingle = epingler
	selection = k
	activer(k)
	if budget != null:
		budget.selectionner(k, true)
	changed.emit()


func liberer() -> void:
	epingle = false
	changed.emit()


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.4
	if communes == null:
		return
	# Ville disparue (fusion) ou aucune ville encore : on revient à une caisse valable.
	if not est_nation(selection) and not communes.villages.has(selection):
		choisir(communes.principal() if a_des_villes() else PAYS)
	elif est_nation(selection) and a_des_villes():
		choisir(communes.principal())
	if epingle or not foyer.is_valid() or not a_des_villes():
		return
	var p: Vector2 = foyer.call()
	var v := communes.village_au_point(p.x, p.y)
	if v >= 0 and v != selection:
		choisir(v)


# --- Argent entre les caisses ----------------------------------------------------------------

## Vire de l'argent d'une caisse à une autre. Renvoie "" ou la raison du refus.
func virer(de: int, a: int, montant: int, motif := "Subvention") -> String:
	if montant <= 0 or de == a:
		return "Montant invalide."
	if not illimite() and solde(de) < montant:
		return "Pas assez d'argent dans la caisse de %s (%s)." % [nom_de(de), BuildingSystem.format_money(solde(de))]
	if not illimite():
		_poser(de, solde(de) - montant)
		_poser(a, solde(a) + montant)
	_noter(de, motif + " versée à " + nom_de(a), -montant)
	_noter(a, motif + " reçue de " + nom_de(de), montant)
	journal.append({"jour": budget.jour_total if budget != null else 0, "de": de, "a": a, "montant": montant, "motif": motif})
	while journal.size() > 40:
		journal.pop_front()
	changed.emit()
	return ""


## Inscrit un mouvement au mois de la caisse k (budget de la commune).
func _noter(k: int, poste: String, v: float) -> void:
	if budget != null:
		budget.noter_pour(k, poste, v)


## Le pays verse une subvention à une ville.
func subventionner(vid: int, montant: int) -> String:
	var why := virer(nation_de(vid), vid, montant, "Subvention")
	if why == "":
		message.emit("Le pays verse %s de subvention à %s." % [BuildingSystem.format_money(montant), nom_de(vid)])
	else:
		message.emit(why)
	return why


## Une ville reverse de l'argent au pays.
func reverser(vid: int, montant: int) -> String:
	var why := ""
	if not joueur_maire(vid):
		why = "Tu n'es plus maire de %s : son conseil refuse de reverser de l'argent au pays." % nom_de(vid)
	else:
		why = virer(vid, nation_de(vid), montant, "Reversement")
	if why == "":
		message.emit("%s reverse %s au pays." % [nom_de(vid), BuildingSystem.format_money(montant)])
	else:
		message.emit(why)
	return why


## Prime versée au pays (objectifs, missions).
## nk : le pays qui la reçoit, ou une ville (son pays) ; -1 : le pays de la ville choisie.
func prime(montant: int, motif: String, nk := -1) -> void:
	if montant <= 0 or illimite():
		return
	nk = nation_choisie() if nk < 0 else nation_de(nk)
	_poser(nk, solde(nk) + montant)
	_noter(nk, motif, montant)
	changed.emit()


## Recette d'un pays (douane…), sans message.
func encaisser(nk: int, montant: float, motif: String) -> void:
	if illimite() or absf(montant) < 0.5:
		return
	_poser(nk, solde(nk) + roundi(montant))
	_noter(nk, motif, roundi(montant))


## Réglages d'un pays (nk = -1 : le pays de la ville choisie).
func set_taux_national(v: float, nk := -1) -> void:
	nk = nation_choisie() if nk < 0 else nk
	v = clampf(snappedf(v, 0.01), 0.0, TAUX_NATIONAL_MAX)
	if nk == PAYS:
		taux_national = v
	elif nations.has(nk):
		nations[nk]["taux_national"] = v
	changed.emit()


func set_dotation(v: float, nk := -1) -> void:
	nk = nation_choisie() if nk < 0 else nk
	v = clampf(snappedf(v, 0.05), 0.0, 2.0)
	if nk == PAYS:
		dotation = v
	elif nations.has(nk):
		nations[nk]["dotation"] = v
	changed.emit()


func set_douane(v: float, nk := -1) -> void:
	nk = nation_choisie() if nk < 0 else nk
	_assurer_nation(nk)
	nations[nk]["douane"] = clampf(snappedf(v, 0.01), 0.0, TAUX_DOUANE_MAX)
	changed.emit()


## Multiplicateur de la dotation réellement versée par le pays nk : rien s'il est à sec.
func facteur_dotation(nk := PAYS) -> float:
	if not illimite() and solde(nk) <= 0:
		return 0.0
	return dotation_de(nk)


## Douane entre deux villes (ou pays) : taux payé à l'arrivée, 0 dans un même pays.
func douane_entre(de: int, a: int) -> float:
	var nd := nation_de(de)
	var na := nation_de(a)
	if nd == na:
		return 0.0
	# Accord de libre-échange entre les deux pays (menu Commerce).
	if CommerceMondial.instance != null and CommerceMondial.instance.libre_echange_entre(nd, na):
		return 0.0
	return douane_de(na)


func _assurer_nation(nk: int) -> void:
	if not nations.has(nk):
		nations[nk] = {"code": "", "nom": "", "taux_national": TAUX_NATIONAL, "dotation": 1.0, "douane": TAUX_DOUANE}


## Pays d'une ville qui vient d'être fondée : celui du lieu, créé s'il le faut.
## Renvoie [clé, nouveau pays ?].
func _nation_pour(vid: int) -> Array:
	var code := code_de_ville(vid)
	if nations.is_empty():
		_assurer_nation(PAYS)
		nations[PAYS]["code"] = code
		return [PAYS, false]
	var nk := nation_du_code(code)
	if nk >= 0:
		return [nk, false]
	nk = NATION_BASE + 1
	while nations.has(nk):
		nk += 1
	_assurer_nation(nk)
	nations[nk]["code"] = code
	if not illimite() and capital_auto:
		var aide := ReglagesPartie.prix(DEPART_NATION)
		_poser(nk, solde(nk) + aide)
		_noter(nk, "Aide d'installation du gouvernement", aide)
	return [nk, true]


# --- Villes fondées et fusionnées ------------------------------------------------------------

## Capital de départ d'une nouvelle ville, payé par le pays.
func capital_pour(premiere: bool, nk := PAYS) -> int:
	var dispo := maxi(0, solde(nk))
	if premiere:
		return roundi(dispo * PART_PREMIERE)
	return mini(dispo, ReglagesPartie.prix(CAPITAL_VILLE))


func _on_fonde(vid: int) -> void:
	if not capital_auto or buildings == null:
		return
	if not comptes.has(vid) and actif != vid:
		comptes[vid] = 0
	var premiere := communes.villages.size() == 1
	var c0: Vector2 = communes.villages[vid].c
	var payeur_avant := nation_au_point(c0.x, c0.y)
	var np := _nation_pour(vid)
	var nk := int(np[0])
	ville_nation[vid] = nk
	var premiere_du_pays := villes_de(nk).size() == 1
	if bool(np[1]):
		# Le bâtiment fondateur payé à la pose par un autre de tes pays : le nouveau le rembourse.
		var bf := int(communes.villages[vid].bid)
		if bf >= 0 and buildings.buildings.has(bf) and not illimite() and payeur_avant != nk:
			var bb: Dictionary = buildings.buildings[bf]
			var paye := int(bb.get("cost", 0)) - int(bb.get("du", 0))
			if paye > 0:
				_poser(payeur_avant, solde(payeur_avant) + paye)
				_poser(nk, solde(nk) - paye)
		message.emit("Nouveau pays : %s. Son gouvernement t'accueille avec %s ; tu le diriges aussi (Maj+P), avec sa caisse, son impôt et sa douane." % [
			nom_nation(nk), BuildingSystem.format_money(solde(nk))])
	# Le bâtiment fondateur est payé par le pays, même s'il se construit peu à peu.
	var bid := int(communes.villages[vid].bid)
	if bid >= 0 and buildings.buildings.has(bid) and not illimite():
		var b: Dictionary = buildings.buildings[bid]
		var du := int(b.get("du", 0))
		if du > 0:
			_poser(nk, solde(nk) - du)
			_noter(nk, "Bâtiment fondateur de " + nom_de(vid), -du)
			b["du"] = 0
	var c := capital_pour(premiere_du_pays, nk)
	if c > 0 and not illimite():
		virer(nk, vid, c, "Capital de départ")
		message.emit("%s verse %s à %s pour ses débuts. Chaque ville a sa propre caisse (Maj+P : le pays)." % [
			nom_nation(nk), BuildingSystem.format_money(c), nom_de(vid)])
	if premiere:
		choisir(vid)
	changed.emit()


func _on_fusion(garde: int, partie: int) -> void:
	var v := solde(partie)
	if actif == partie:
		activer(garde)
	_poser(garde, solde(garde) + v)
	comptes.erase(partie)
	ville_nation.erase(partie)
	if budget != null:
		budget.fusionner_etats(garde, partie)
	if selection == partie:
		choisir(garde)
	changed.emit()


## Partie d'avant le pays : l'argent est partagé entre les villes (selon leur
## population) et le pays en garde une part.
func adopter_ancienne_partie() -> void:
	if buildings == null or not a_des_villes():
		return
	activer(PAYS)
	var tout := buildings.money
	var pour_villes := roundi(tout * (1.0 - PART_PAYS_ANCIENNE))
	buildings.money = tout - pour_villes
	var parts := parts_population()
	var reste := pour_villes
	var ks: Array = parts.keys()
	for i in ks.size():
		var k: int = ks[i]
		var x := reste if i == ks.size() - 1 else roundi(pour_villes * float(parts[k]))
		reste -= x
		comptes[k] = int(comptes.get(k, 0)) + x
	# Impôts votés, emprunts et entretien d'avant : ceux du chef-lieu.
	if budget != null:
		budget.transferer_etat(PAYS, communes.principal())
	choisir(communes.principal())


# --- Sauvegarde ----------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var cs := {}
	for k in cles():
		cs[str(k)] = solde(k)
	var ns := {}
	for k in nations:
		ns[str(k)] = (nations[k] as Dictionary).duplicate()
	var vn := {}
	for vid in ville_nation:
		vn[str(vid)] = int(ville_nation[vid])
	return {"version": 2, "nom": nom, "comptes": cs, "selection": selection, "epingle": epingle,
		"taux_national": taux_national, "dotation": dotation, "journal": journal.duplicate(true),
		"nations": ns, "villes_pays": vn}


## Chargement (après les villages et le budget). Sans section : ancienne partie.
func from_dict(d: Dictionary) -> void:
	if buildings == null:
		return
	if d.is_empty():
		# L'argent chargé est dans buildings.money (caisse unique d'avant).
		comptes.clear()
		actif = PAYS
		selection = PAYS
		epingle = false
		nations.clear()
		ville_nation.clear()
		if a_des_villes():
			adopter_ancienne_partie()
			_nations_anciennes()
		changed.emit()
		return
	comptes.clear()
	actif = PAYS
	nom = String(d.get("nom", ""))
	nations.clear()
	ville_nation.clear()
	_codes_cache.clear()
	var ns: Dictionary = d.get("nations", {})
	for ks in ns:
		nations[int(ks)] = (ns[ks] as Dictionary).duplicate()
	var vn: Dictionary = d.get("villes_pays", {})
	for ks in vn:
		if communes != null and communes.villages.has(int(ks)):
			ville_nation[int(ks)] = int(vn[ks])
	_nations_anciennes()
	var cs: Dictionary = d.get("comptes", {})
	for ks in cs:
		var k := int(ks)
		if est_nation(k) or (communes != null and communes.villages.has(k)):
			comptes[k] = int(cs[ks])
	buildings.money = int(comptes.get(PAYS, 0))
	comptes.erase(PAYS)
	taux_national = clampf(float(d.get("taux_national", TAUX_NATIONAL)), 0.0, TAUX_NATIONAL_MAX)
	dotation = clampf(float(d.get("dotation", 1.0)), 0.0, 2.0)
	journal = (d.get("journal", []) as Array).duplicate(true)
	var sel := int(d.get("selection", PAYS))
	selection = PAYS
	choisir(sel if (communes != null and communes.villages.has(sel)) else (communes.principal() if a_des_villes() else PAYS),
		bool(d.get("epingle", false)))
	changed.emit()


## Partie d'avant les pays multiples : un seul pays (celui de la première ville).
func _nations_anciennes() -> void:
	if not a_des_villes():
		return
	if not nations.has(PAYS):
		_assurer_nation(PAYS)
		nations[PAYS]["code"] = code_de_ville(communes.principal())
	for vid in communes.villages:
		if not ville_nation.has(vid):
			ville_nation[vid] = PAYS
