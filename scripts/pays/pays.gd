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

static var instance: Pays

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
	journal.clear()
	if budget != null:
		budget.oublier_communes()
	changed.emit()


# --- Questions ------------------------------------------------------------------------

## Le pays a-t-il au moins une ville ?
func a_des_villes() -> bool:
	return communes != null and not communes.villages.is_empty()


## Clés des caisses : les villes puis le pays.
func cles() -> Array:
	var out := []
	if communes != null:
		var ids: Array = communes.villages.keys()
		ids.sort()
		out.append_array(ids)
	out.append(PAYS)
	return out


func nom_de(k: int) -> String:
	if k == PAYS:
		return nom_pays()
	if communes != null and communes.villages.has(k):
		return String(communes.villages[k].nom)
	return "?"


func nom_pays() -> String:
	if nom.strip_edges() != "":
		return nom.strip_edges()
	if communes != null and not communes.villages.is_empty():
		var dr := String(communes.villages[communes.principal()].get("drapeau", ""))
		if dr != "":
			return Drapeaux.nom(dr)
	return "Mon pays"


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
	if communes == null:
		return PAYS
	var v := communes.village_au_point(x, z)
	return v if v >= 0 else PAYS


func payeur_du_batiment(bid: int) -> int:
	if communes == null or buildings == null or not buildings.buildings.has(bid):
		return actif
	var v := int(communes.bat_village.get(bid, -2))
	if v == -2:
		v = communes.village_du_batiment(bid)
	return v if v >= 0 else PAYS


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
	if cle.begins_with("voie:") or cle.begins_with("reparation:"):
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
	if instance == null or not instance.a_des_villes():
		return -1
	return instance.entrer(instance.payeur_au_point(x, z))


static func au_rect(rect: Rect2i) -> int:
	if instance == null or not instance.a_des_villes():
		return -1
	return instance.entrer(instance.payeur_du_rect(rect))


static func au_batiment(bid: int) -> int:
	if instance == null or not instance.a_des_villes():
		return -1
	return instance.entrer(instance.payeur_du_batiment(bid))


static func a_la_caisse(k: int) -> int:
	if instance == null or k < 0:
		return -1
	return instance.entrer(k)


static func retour(p: int) -> void:
	if instance != null and p >= 0:
		instance.sortir(p)


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
	if vid == PAYS:
		return true
	if Avis.instance != null:
		return Avis.instance.joueur_decide_de(vid)
	return true


# --- Ville choisie ---------------------------------------------------------------------

## Choisit la ville gérée (caisse affichée, budget M). epingler : ne suit plus la caméra.
func choisir(k: int, epingler := false) -> void:
	if k != PAYS and (communes == null or not communes.villages.has(k)):
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
	if selection != PAYS and not communes.villages.has(selection):
		choisir(communes.principal() if a_des_villes() else PAYS)
	elif selection == PAYS and a_des_villes():
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
	var why := virer(PAYS, vid, montant, "Subvention")
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
		why = virer(vid, PAYS, montant, "Reversement")
	if why == "":
		message.emit("%s reverse %s au pays." % [nom_de(vid), BuildingSystem.format_money(montant)])
	else:
		message.emit(why)
	return why


## Prime versée au pays (objectifs, missions).
func prime(montant: int, motif: String) -> void:
	if montant <= 0 or illimite():
		return
	_poser(PAYS, solde(PAYS) + montant)
	_noter(PAYS, motif, montant)
	changed.emit()


func set_taux_national(v: float) -> void:
	taux_national = clampf(snappedf(v, 0.01), 0.0, TAUX_NATIONAL_MAX)
	changed.emit()


func set_dotation(v: float) -> void:
	dotation = clampf(snappedf(v, 0.05), 0.0, 2.0)
	changed.emit()


## Multiplicateur de la dotation réellement versée : rien si le pays est à sec.
func facteur_dotation() -> float:
	if not illimite() and solde(PAYS) <= 0:
		return 0.0
	return dotation


# --- Villes fondées et fusionnées ------------------------------------------------------------

## Capital de départ d'une nouvelle ville, payé par le pays.
func capital_pour(premiere: bool) -> int:
	var dispo := maxi(0, solde(PAYS))
	if premiere:
		return roundi(dispo * PART_PREMIERE)
	return mini(dispo, ReglagesPartie.prix(CAPITAL_VILLE))


func _on_fonde(vid: int) -> void:
	if not capital_auto or buildings == null:
		return
	if not comptes.has(vid) and actif != vid:
		comptes[vid] = 0
	var premiere := communes.villages.size() == 1
	# Le bâtiment fondateur est payé par le pays, même s'il se construit peu à peu.
	var bid := int(communes.villages[vid].bid)
	if bid >= 0 and buildings.buildings.has(bid) and not illimite():
		var b: Dictionary = buildings.buildings[bid]
		var du := int(b.get("du", 0))
		if du > 0:
			_poser(PAYS, solde(PAYS) - du)
			_noter(PAYS, "Bâtiment fondateur de " + nom_de(vid), -du)
			b["du"] = 0
	var c := capital_pour(premiere)
	if c > 0 and not illimite():
		virer(PAYS, vid, c, "Capital de départ")
		message.emit("Le pays verse %s à %s pour ses débuts. Chaque ville a sa propre caisse (Maj+P : le pays)." % [
			BuildingSystem.format_money(c), nom_de(vid)])
	if premiere:
		choisir(vid)


func _on_fusion(garde: int, partie: int) -> void:
	var v := solde(partie)
	if actif == partie:
		activer(garde)
	_poser(garde, solde(garde) + v)
	comptes.erase(partie)
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
	return {"version": 1, "nom": nom, "comptes": cs, "selection": selection, "epingle": epingle,
		"taux_national": taux_national, "dotation": dotation, "journal": journal.duplicate(true)}


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
		if a_des_villes():
			adopter_ancienne_partie()
		changed.emit()
		return
	comptes.clear()
	actif = PAYS
	nom = String(d.get("nom", ""))
	var cs: Dictionary = d.get("comptes", {})
	for ks in cs:
		var k := int(ks)
		if k == PAYS or (communes != null and communes.villages.has(k)):
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
