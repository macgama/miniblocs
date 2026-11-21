class_name Gestion
extends Node
## Mode gestion « tycoon » d'un bâtiment : niveaux des pièces, objets achetés,
## personnel (salaires, formation), pannes, événements, gestion automatique,
## historique, et ce que tout cela change dans la ville.
##
## Le joueur clique sur un hôtel → fiche → « Gérer l'hôtel » : la vue
## isométrique (GestionVue) montre les pièces, le personnel et les clients.
## Chaque pièce a un niveau et des objets à acheter ; ils coûtent de l'argent
## (d'abord le compte de l'hôtel, le reste avancé par la caisse de la ville)
## et apportent des effets (GestionTypes : lits, confort, attrait,
## satisfaction, repas sur place, vitesse, ventes) que les systèmes du jeu
## lisent avec Gestion.effet_de(bid, clé) : l'hôtel gagne des lits, des
## clients, une meilleure note, des étoiles, donc plus de nuitées, de taxe de
## séjour et d'impôts pour la ville.
##
## Gestion automatique (par défaut) : chaque jour, un hôtel que le joueur ne
## gère pas lui-même répare ses pannes, investit ses bénéfices (jamais
## l'argent de la ville) dans ce qui rapporte le plus, ajuste son prix selon
## le remplissage et forme son personnel. Le joueur reprend la main d'un
## clic (« Je gère ») et peut la rendre (« Auto »).
##
## Le rythme est celui du jeu (1 jour = 1 minute par défaut, pause = arrêt) :
## rien ne se gagne pendant que le jeu est fermé.

signal changed(bid: int)
signal message(text: String)

static var instance: Gestion

## Points de confort gagnés par étoile en plus (classement de l'hôtel).
const SEUIL_ETOILE := 0.6
## Le prix d'un niveau est multiplié par ça à chaque niveau.
const PROGRESSION := 1.7
## Construire une pièce absente coûte plus cher que l'améliorer.
const CONSTRUIRE := 1.5
## Satisfaction gagnée (ou perdue) par demande réglée (ou oubliée).
const SATISF_REGLEE := 0.03
const SATISF_RATEE := 0.015
## Satisfaction perdue chaque jour par panne pas réparée.
const SATISF_PANNE := 0.06
const MAX_PANNES := 4
## Chance qu'une pièce construite tombe en panne un jour donné.
const CHANCE_PANNE := 0.025
const FORMATION_MAX := 5
const SALAIRE_MIN := 0.8
const SALAIRE_MAX := 1.5
## Entretien d'un objet par jour : part de son prix.
const ENTRETIEN_OBJET := 0.0015
## Jours gardés dans l'historique et dans le journal.
const HISTORIQUE := 60
const JOURNAL := 40
## Gestion automatique : garder de quoi payer N jours de charges.
const RESERVE_JOURS := 15.0

var buildings: BuildingSystem
var tourisme: Tourisme
var production: Production
## bid → état (voir etat()).
var etats: Dictionary = {}
var rng := RandomNumberGenerator.new()
var jour := 0


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func setup(b: BuildingSystem, t: Tourisme, p: Production = null) -> void:
	buildings = b
	tourisme = t
	production = p
	rng.seed = 1789


func clear() -> void:
	etats.clear()


# --- Bâtiments ---------------------------------------------------------------------------------

func type_of(bid: int) -> String:
	if buildings == null or not buildings.buildings.has(bid):
		return ""
	return String(buildings.buildings[bid].t)


func genre_of(bid: int) -> String:
	return GestionTypes.genre_de(type_of(bid))


func gerable(bid: int) -> bool:
	return genre_of(bid) != "" and not buildings.en_chantier(bid)


## Spécification du bâtiment dans le jeu, sans les effets de la gestion.
func spec_base(bid: int) -> Dictionary:
	if source(bid) == "production":
		var t := BuildingCatalog.get_type(type_of(bid))
		return {"etoiles": 2 if float(t.get("cost", 0.0)) >= 480_000.0 else 1}
	return TourismeTypes.spec_of(type_of(bid))


## D'où viennent les chiffres du bâtiment : "tourisme" (hôtel) ou
## "production" (entreprise : restaurant…).
func source(bid: int) -> String:
	return String(GestionTypes.genre(genre_of(bid)).get("source", "tourisme"))


## Le bâtiment existe-t-il dans le système qui le fait vivre ?
func valide(bid: int) -> bool:
	if not gerable(bid):
		return false
	match source(bid):
		"production":
			return production != null and production.sites.has(bid)
	return tourisme != null and tourisme.heb.has(bid)


## « l'hôtel », « le restaurant »…
func le_(bid: int) -> String:
	return String(GestionTypes.genre(genre_of(bid)).get("le", "l'établissement"))


## État de gestion du bâtiment (créé au premier passage).
func etat(bid: int) -> Dictionary:
	if etats.has(bid):
		return etats[bid]
	var g := genre_of(bid)
	if g == "":
		return {}
	var st := _etat_vide(g)
	for pid in GestionTypes.ordre(g):
		st.niv[String(pid)] = niveau_depart(bid, String(pid))
	etats[bid] = st
	return st


static func _etat_vide(g: String) -> Dictionary:
	return {"genre": g, "niv": {}, "obj": {}, "auto": true, "salaire": 1.0, "formation": 0, "pannes": [], "journal": [], "hist": [],
		"pourboires": 0.0, "reglees": 0, "ratees": 0, "reparees": 0, "invest": 0.0, "aide_ville": 0.0, "label_fin": -1,
		"inspection": -1, "seminaires": 0, "vip": 0,
		# Établissements sans système de clients à eux (restaurant) :
		"prix": 1.0, "satisf": 3.0, "note": 3.0, "j": {}, "hier": {}}


## Niveau de départ d'une pièce : 1 si le bâtiment l'a déjà (restaurant d'un
## hôtel-restaurant…), sinon celui du genre.
func niveau_depart(bid: int, pid: String) -> int:
	var p := GestionTypes.piece(genre_of(bid), pid)
	var f := String(p.get("flag", ""))
	if f != "" and bool(spec_base(bid).get(f, false)):
		return maxi(1, int(p.get("base", 0)))
	return int(p.get("base", 0))


func niveau(bid: int, pid: String) -> int:
	if etats.has(bid):
		return int((etats[bid].niv as Dictionary).get(pid, niveau_depart(bid, pid)))
	return niveau_depart(bid, pid)


func niveau_max(bid: int, pid: String) -> int:
	return int(GestionTypes.piece(genre_of(bid), pid).get("max", 5))


## Niveaux gagnés au-dessus du départ.
func gagnes(bid: int, pid: String) -> int:
	return maxi(0, niveau(bid, pid) - niveau_depart(bid, pid))


func a_objet(bid: int, pid: String, oid: String) -> bool:
	return etats.has(bid) and oid in ((etats[bid].obj as Dictionary).get(pid, []) as Array)


## Objets achetés dans une pièce (ceux d'une pièce démolie ne comptent pas).
func objets_de(bid: int, pid: String) -> Array:
	if not etats.has(bid) or niveau(bid, pid) <= 0:
		return []
	return (etats[bid].obj as Dictionary).get(pid, [])


func nb_objets(bid: int) -> int:
	if not etats.has(bid):
		return 0
	var n := 0
	for pid in (etats[bid].obj as Dictionary):
		n += objets_de(bid, String(pid)).size()
	return n


## Effet total d'une clé (GestionTypes.EFFETS) pour un bâtiment : niveaux,
## objets, personnel, pannes et label du guide.
func effet(bid: int, cle: String) -> float:
	if not etats.has(bid):
		return 0.0
	var st: Dictionary = etats[bid]
	var g := String(st.genre)
	var s := 0.0
	for pid in GestionTypes.ordre(g):
		var e: Dictionary = GestionTypes.piece(g, String(pid)).get("effets", {})
		if e.has(cle):
			s += float(e[cle]) * gagnes(bid, String(pid))
		for oid in objets_de(bid, String(pid)):
			var eo: Dictionary = GestionTypes.objet(g, String(pid), String(oid)).get("effets", {})
			s += float(eo.get(cle, 0.0))
	match cle:
		"satisf":
			s += (float(st.salaire) - 1.0) * 0.35 + 0.03 * float(st.formation) - SATISF_PANNE * (st.pannes as Array).size()
		"vitesse":
			s += 0.08 * float(st.formation)
		"attrait":
			if int(st.label_fin) >= jour:
				s += 0.06
	return s


static func effet_de(bid: int, cle: String) -> float:
	if instance == null or not is_instance_valid(instance):
		return 0.0
	return instance.effet(bid, cle)


## Charges en plus, par jour (€) : entretien des pièces et des objets,
## supplément de salaire, formation.
func entretien_jour(bid: int) -> float:
	if not etats.has(bid):
		return 0.0
	var st: Dictionary = etats[bid]
	var g := String(st.genre)
	var s := 0.0
	for pid in GestionTypes.ordre(g):
		var e: Dictionary = GestionTypes.piece(g, String(pid)).get("effets", {})
		s += float(e.get("entretien", 0.0)) * gagnes(bid, String(pid))
		for oid in objets_de(bid, String(pid)):
			s += prix_objet(bid, String(pid), String(oid)) * ENTRETIEN_OBJET
	var emplois := emplois_de(bid)
	var sal := Tourisme.SALAIRE_MOYEN * ReglagesPartie.actuel.salaires / 30.44
	s += float(emplois) * sal * (float(st.salaire) - 1.0)
	s += float(emplois) * 3.0 * float(st.formation)
	return maxf(0.0, s)


static func entretien_de(bid: int) -> float:
	if instance == null or not is_instance_valid(instance):
		return 0.0
	return instance.entretien_jour(bid)


func emplois_de(bid: int) -> int:
	if buildings == null or not buildings.buildings.has(bid):
		return 0
	return Ameliorations.cap(buildings.buildings[bid], "emplois")


## Étoiles du bâtiment : celles de son type, plus celles gagnées par le confort.
func etoiles(bid: int) -> int:
	var base := int(spec_base(bid).get("etoiles", 2))
	return mini(5, base + int(floorf(maxf(0.0, effet(bid, "confort")) / SEUIL_ETOILE + 0.001)))


## Confort à gagner encore avant la prochaine étoile (0 : déjà 5 étoiles).
func avant_etoile(bid: int) -> float:
	if etoiles(bid) >= 5:
		return 0.0
	var c := maxf(0.0, effet(bid, "confort"))
	return SEUIL_ETOILE * (floorf(c / SEUIL_ETOILE + 0.001) + 1.0) - c


## Spécification vue par le jeu : pièces construites (restaurant, piscine,
## spa…) et étoiles gagnées. Sans état de gestion : celle du type, inchangée.
static func spec_de(bid: int, base: Dictionary) -> Dictionary:
	if instance == null or not is_instance_valid(instance) or not instance.etats.has(bid):
		return base
	var s := base.duplicate()
	var g := String(instance.etats[bid].genre)
	for pid in GestionTypes.ordre(g):
		var f := String(GestionTypes.piece(g, String(pid)).get("flag", ""))
		if f != "" and instance.niveau(bid, String(pid)) > 0:
			s[f] = true
	if s.has("etoiles"):
		var e0 := int(s.etoiles)
		var e1 := instance.etoiles(bid)
		s["etoiles"] = e1
		# Une étoile de plus : les clients acceptent de payer plus cher.
		if e1 > e0 and s.has("prix"):
			s["prix"] = float(s.prix) * TourismeTypes.prix_ref(e1) / maxf(1.0, TourismeTypes.prix_ref(e0))
	return s


# --- Argent ------------------------------------------------------------------------------------

## Prix du bâtiment (base du prix des travaux).
func cout_batiment(bid: int) -> float:
	var t := BuildingCatalog.get_type(type_of(bid))
	var c := float(t.get("cost", 0.0))
	if c <= 0.0:
		c = 400_000.0 if source(bid) == "production" else float(spec_base(bid).get("chambres", 30)) * 60_000.0
	return c * float(GestionTypes.genre(genre_of(bid)).get("cout_mult", 1.0))


static func _arrondi(v: float, mini_ := 300) -> int:
	return maxi(mini_, int(roundf(v / 100.0)) * 100)


## Prix du prochain niveau (0 : déjà au maximum).
func prix(bid: int, pid: String) -> int:
	var n := niveau(bid, pid)
	if n >= niveau_max(bid, pid):
		return 0
	var p := GestionTypes.piece(genre_of(bid), pid)
	var base := cout_batiment(bid) * float(p.get("prix", 0.005))
	return _arrondi(base * CONSTRUIRE if n == 0 else base * pow(PROGRESSION, float(n - 1)), 500)


func prix_objet(bid: int, pid: String, oid: String) -> int:
	var o := GestionTypes.objet(genre_of(bid), pid, oid)
	if o.is_empty():
		return 0
	return _arrondi(cout_batiment(bid) * float(o.get("prix", 0.001)))


func prix_formation(bid: int) -> int:
	if etats.has(bid) and int(etats[bid].formation) >= FORMATION_MAX:
		return 0
	var f := int(etats[bid].formation) if etats.has(bid) else 0
	return _arrondi(cout_batiment(bid) * 0.0015 * pow(1.6, float(f)))


func prix_reparation(bid: int) -> int:
	return _arrondi(cout_batiment(bid) * 0.0003, 200)


## Argent du compte du bâtiment (hôtel privé : ses bénéfices accumulés).
func compte(bid: int) -> float:
	if source(bid) == "production":
		return float(production.sites[bid].cash) if production != null and production.sites.has(bid) else 0.0
	if tourisme != null and tourisme.heb.has(bid):
		return float(tourisme.heb[bid].compte)
	return 0.0


func _crediter(bid: int, v: float) -> void:
	if source(bid) == "production":
		if production != null and production.sites.has(bid):
			production.pay(bid, "Travaux et achats (gestion)" if v < 0.0 else "Pourboires et extras", v)
		return
	if tourisme != null and tourisme.heb.has(bid):
		tourisme.heb[bid].compte = float(tourisme.heb[bid].compte) + v


func caisse_ville() -> int:
	return buildings.money if buildings != null else 0


## Ce que paieraient le compte du bâtiment et la caisse de la ville.
func repartition(bid: int, montant: int) -> Dictionary:
	var dispo := maxf(0.0, compte(bid))
	var du_bat := minf(dispo, float(montant))
	return {"batiment": int(du_bat), "ville": montant - int(du_bat)}


## Paie un montant : le compte du bâtiment d'abord, la ville avance le reste
## (sauf « sans_ville » : la gestion automatique ne touche pas à la caisse).
func _payer(bid: int, montant: int, sans_ville := false) -> Dictionary:
	var r := repartition(bid, montant)
	var gratuit := buildings.unlimited_money
	if not gratuit and int(r.ville) > 0:
		if sans_ville:
			return {"ok": false, "error": "pas assez d'argent sur le compte de %s" % le_(bid)}
		if caisse_ville() < int(r.ville):
			return {"ok": false, "error": "pas assez d'argent (il manque %s)" % BuildingSystem.format_money(int(r.ville) - caisse_ville())}
	var st := etat(bid)
	if not gratuit:
		_crediter(bid, -float(r.batiment))
		if int(r.ville) > 0:
			_depense_ville("Gestion : avance à %s" % nom(bid), float(r.ville))
			st.aide_ville = float(st.aide_ville) + float(r.ville)
	st.invest = float(st.invest) + float(montant)
	return {"ok": true, "batiment": int(r.batiment), "ville": int(r.ville), "gratuit": gratuit}


## Passe une pièce au niveau suivant (ou la construit). Renvoie {ok, error, batiment, ville}.
func ameliorer(bid: int, pid: String, sans_ville := false) -> Dictionary:
	if not gerable(bid):
		return {"ok": false, "error": "ce bâtiment ne se gère pas"}
	if not GestionTypes.pieces(genre_of(bid)).has(pid):
		return {"ok": false, "error": "pièce inconnue"}
	var p := prix(bid, pid)
	if p <= 0:
		return {"ok": false, "error": "déjà au niveau maximum"}
	var e0 := etoiles(bid)
	var r := _payer(bid, p, sans_ville)
	if not bool(r.ok):
		return r
	var st := etat(bid)
	var avant := niveau(bid, pid)
	st.niv[pid] = avant + 1
	var nom_p := String(GestionTypes.piece(String(st.genre), pid).get("nom", pid))
	_noter(bid, ("%s construit." % nom_p) if avant == 0 else ("%s au niveau %d." % [nom_p, avant + 1]), not sans_ville)
	_etoile_gagnee(bid, e0)
	changed.emit(bid)
	return r


## Raison pour laquelle on ne peut pas acheter un objet, "" sinon.
func refus_objet(bid: int, pid: String, oid: String) -> String:
	var o := GestionTypes.objet(genre_of(bid), pid, oid)
	if o.is_empty():
		return "objet inconnu"
	if a_objet(bid, pid, oid):
		return "déjà installé"
	var n := niveau(bid, pid)
	if n <= 0:
		return "pièce pas encore construite"
	if n < int(o.get("niv", 1)):
		return "pièce au niveau %d requise" % int(o.niv)
	return ""


func acheter(bid: int, pid: String, oid: String, sans_ville := false) -> Dictionary:
	if not gerable(bid):
		return {"ok": false, "error": "ce bâtiment ne se gère pas"}
	var refus := refus_objet(bid, pid, oid)
	if refus != "":
		return {"ok": false, "error": refus}
	var e0 := etoiles(bid)
	var r := _payer(bid, prix_objet(bid, pid, oid), sans_ville)
	if not bool(r.ok):
		return r
	var st := etat(bid)
	if not (st.obj as Dictionary).has(pid):
		st.obj[pid] = []
	(st.obj[pid] as Array).append(oid)
	_noter(bid, "%s installé (%s)." % [String(GestionTypes.objet(String(st.genre), pid, oid).nom), String(GestionTypes.piece(String(st.genre), pid).nom)], not sans_ville)
	_etoile_gagnee(bid, e0)
	changed.emit(bid)
	return r


func former(bid: int, sans_ville := false) -> Dictionary:
	var p := prix_formation(bid)
	if p <= 0:
		return {"ok": false, "error": "personnel déjà formé au maximum"}
	var r := _payer(bid, p, sans_ville)
	if not bool(r.ok):
		return r
	var st := etat(bid)
	st.formation = int(st.formation) + 1
	_noter(bid, "Formation du personnel : niveau %d." % int(st.formation), not sans_ville)
	changed.emit(bid)
	return r


func set_salaire(bid: int, f: float) -> void:
	var st := etat(bid)
	if st.is_empty():
		return
	st.salaire = clampf(snappedf(f, 0.05), SALAIRE_MIN, SALAIRE_MAX)
	changed.emit(bid)


func set_auto(bid: int, on: bool) -> void:
	var st := etat(bid)
	if st.is_empty():
		return
	st.auto = on
	_noter(bid, "Gestion automatique." if on else "Tu gères %s toi-même." % le_(bid), false)
	changed.emit(bid)


func auto(bid: int) -> bool:
	return not etats.has(bid) or bool(etats[bid].auto)


func _etoile_gagnee(bid: int, e0: int) -> void:
	if etoiles(bid) > e0:
		var cl := String(GestionTypes.genre(genre_of(bid)).get("classe", "étoiles"))
		_noter(bid, "%s gagne une %s : %d %s !" % [nom(bid), cl.trim_suffix("s"), etoiles(bid), cl], true)


func _depense_ville(poste: String, v: float) -> void:
	var bc := BudgetCommunal.instance
	if bc != null and is_instance_valid(bc) and bc.is_inside_tree():
		bc.depense(poste, v)
	elif buildings != null:
		buildings.money -= int(v)


## Rend à la ville ce qu'elle a avancé, quand le compte du bâtiment le permet.
func rembourser(bid: int) -> int:
	if not etats.has(bid):
		return 0
	var st: Dictionary = etats[bid]
	var v := int(minf(float(st.aide_ville), maxf(0.0, compte(bid))))
	if v <= 0:
		return 0
	_crediter(bid, -float(v))
	st.aide_ville = float(st.aide_ville) - float(v)
	var bc := BudgetCommunal.instance
	if bc != null and is_instance_valid(bc) and bc.is_inside_tree():
		bc.recette("Gestion : remboursement de %s" % nom(bid), float(v))
	elif buildings != null and not buildings.unlimited_money:
		buildings.money += v
	_noter(bid, "%s rendus à la ville." % BuildingSystem.format_money(v), false)
	changed.emit(bid)
	return v


func nom(bid: int) -> String:
	if source(bid) == "tourisme" and tourisme != null and tourisme.heb.has(bid):
		return tourisme.nom(bid)
	return String(BuildingCatalog.get_type(type_of(bid)).get("name", "Bâtiment"))


## Note dans le journal de l'établissement (et message à l'écran si fort).
func _noter(bid: int, texte: String, annoncer := false) -> void:
	var st := etat(bid)
	if st.is_empty():
		return
	(st.journal as Array).push_front([jour, texte])
	while (st.journal as Array).size() > JOURNAL:
		(st.journal as Array).pop_back()
	if annoncer:
		message.emit("%s : %s" % [nom(bid), texte])


# --- Pannes ------------------------------------------------------------------------------------

func nouvelle_panne(bid: int) -> Dictionary:
	var st := etat(bid)
	if st.is_empty() or (st.pannes as Array).size() >= MAX_PANNES:
		return {}
	var g := String(st.genre)
	var possibles: Array = []
	var tables: Dictionary = GestionTypes.genre(g).get("pannes", {})
	for pid in tables:
		if niveau(bid, String(pid)) > 0:
			var deja := false
			for p in st.pannes:
				deja = deja or String(p.piece) == String(pid)
			if not deja:
				possibles.append(String(pid))
	if possibles.is_empty():
		return {}
	var pid: String = possibles[rng.randi() % possibles.size()]
	var textes: Array = tables[pid]
	var p := {"piece": pid, "texte": String(textes[rng.randi() % textes.size()]), "jour": jour}
	(st.pannes as Array).append(p)
	_noter(bid, "Panne : %s (%s)." % [String(p.texte), String(GestionTypes.piece(g, pid).nom)], false)
	changed.emit(bid)
	return p


func reparer(bid: int, i: int, sans_ville := false) -> Dictionary:
	var st := etat(bid)
	if st.is_empty() or i < 0 or i >= (st.pannes as Array).size():
		return {"ok": false, "error": "rien à réparer"}
	var r := _payer(bid, prix_reparation(bid), sans_ville)
	if not bool(r.ok):
		return r
	var p: Dictionary = (st.pannes as Array)[i]
	(st.pannes as Array).remove_at(i)
	st.reparees = int(st.reparees) + 1
	_noter(bid, "Réparé : %s." % String(p.texte), false)
	changed.emit(bid)
	return r


# --- Demandes des clients ------------------------------------------------------------------------

## Demandes possibles maintenant (pièces construites seulement).
func demandes_possibles(bid: int) -> Array:
	var g := genre_of(bid)
	var out: Array = []
	for d in GestionTypes.genre(g).get("demandes", []):
		if niveau(bid, String(d.piece)) > 0:
			out.append(d)
	return out


## Demande réglée : pourboire sur le compte, clients plus contents.
func regler(bid: int, d: Dictionary) -> float:
	var st := etat(bid)
	if st.is_empty():
		return 0.0
	var tip := float(d.get("pourboire", 5)) * (0.6 + 0.2 * float(etoiles(bid)))
	_crediter(bid, tip)
	st.pourboires = float(st.pourboires) + tip
	st.reglees = int(st.reglees) + 1
	_ajouter_satisf(bid, SATISF_REGLEE)
	changed.emit(bid)
	return tip


## Demande oubliée : les clients sont un peu déçus.
func rater(bid: int) -> void:
	var st := etat(bid)
	if st.is_empty():
		return
	st.ratees = int(st.ratees) + 1
	_ajouter_satisf(bid, -SATISF_RATEE)
	changed.emit(bid)


# --- La journée ----------------------------------------------------------------------------------

## Fin de journée (appelée par le tourisme) : historique, pannes, événements
## et gestion automatique de chaque établissement.
func nouveau_jour(now: Dictionary = {}) -> void:
	if buildings == null:
		return
	jour = int(now.get("day", jour + 1))
	var month := int(now.get("month", 6))
	nettoyer()
	for b in buildings.buildings:
		var bid := int(b)
		if not valide(bid):
			continue
		var st := etat(bid)
		if source(bid) == "tourisme":
			_historique(bid, st)
		if rng.randf() < CHANCE_PANNE * _nb_pieces(bid) * (1.0 - 0.12 * float(st.formation)) * (0.6 if niveau(bid, "direction") >= 3 or niveau(bid, "bureau") >= 3 else 1.0):
			nouvelle_panne(bid)
		_evenements(bid, st, month)
		if bool(st.auto):
			gerer_auto(bid)


func _nb_pieces(bid: int) -> int:
	var n := 0
	for pid in GestionTypes.ordre(genre_of(bid)):
		if niveau(bid, String(pid)) > 0:
			n += 1
	return n


func _historique(bid: int, st: Dictionary) -> void:
	var h: Dictionary = tourisme.heb[bid]
	var j: Dictionary = h.get("jour", {})
	(st.hist as Array).append([jour, float(j.get("ca", 0.0)), float(j.get("charges", 0.0)), int(j.get("nuitees", 0)),
		snappedf(tourisme.occupation(bid), 0.01), snappedf(tourisme.note(bid), 0.01), snappedf(float(h.get("satisf", 3.0)), 0.01)])
	while (st.hist as Array).size() > HISTORIQUE:
		(st.hist as Array).pop_front()


## Événements du jour, selon le genre.
func _evenements(bid: int, st: Dictionary, month: int) -> void:
	match genre_of(bid):
		"restaurant":
			_evenements_restaurant(bid, st)
		_:
			_evenements_hotel(bid, st, month)


## Inspecteur du guide, client célèbre, séminaire, groupe en autocar.
func _evenements_hotel(bid: int, st: Dictionary, month: int) -> void:
	# Inspecteur du guide : environ une fois par mois.
	if int(st.inspection) < 0:
		st.inspection = jour + rng.randi_range(10, 40)
	elif jour >= int(st.inspection):
		st.inspection = jour + rng.randi_range(25, 50)
		var n := tourisme.note(bid)
		var vise := 2.6 + 0.4 * float(etoiles(bid))
		if n >= vise:
			st.label_fin = jour + 60
			_noter(bid, "L'inspecteur du guide est passé incognito : « Recommandé » pendant 60 jours (+6 % de clients) !", true)
		else:
			_noter(bid, "L'inspecteur du guide est passé incognito : pas de recommandation (note %.1f, il fallait %.1f)." % [n, vise], true)
	# Séminaires : la salle de conférences se loue.
	var conf := niveau(bid, "conference")
	if conf > 0 and rng.randf() < 0.08 * conf:
		var v := 900.0 * conf * (1.0 + 0.5 * objets_de(bid, "conference").size())
		_crediter(bid, v)
		st.seminaires = int(st.seminaires) + 1
		_noter(bid, "Séminaire d'entreprise dans la salle de conférences : %s encaissés." % BuildingSystem.format_money(int(v)), false)
	# Client célèbre (plus souvent dans les beaux hôtels).
	if rng.randf() < 0.012 * float(etoiles(bid)):
		var tip := 150.0 * float(etoiles(bid))
		_crediter(bid, tip)
		st.vip = int(st.vip) + 1
		var qui := ["Une chanteuse célèbre", "Un footballeur international", "Une ministre en visite", "Un acteur de cinéma", "Une famille royale (en toute discrétion)"]
		_noter(bid, "%s a dormi ici et laissé %s de pourboire." % [String(qui[rng.randi() % qui.size()]), BuildingSystem.format_money(int(tip))], false)
	# Groupe en autocar quand il reste de la place.
	if rng.randf() < 0.05 + 0.02 * float(niveau(bid, "parking")):
		var libres := tourisme.capacite(bid, month) - tourisme.clients(bid)
		var n := mini(libres, rng.randi_range(18, 45))
		if n >= 10:
			tourisme._loger(bid, n, month)
			_noter(bid, "Un autocar de %d touristes arrive sans prévenir : l'hôtel les loge." % n, false)


## Gestion automatique : réparer, investir, ajuster le prix, former.
func gerer_auto(bid: int) -> void:
	var st := etat(bid)
	if st.is_empty():
		return
	# Réparer d'abord.
	for i in range((st.pannes as Array).size() - 1, -1, -1):
		reparer(bid, i, true)
	# Prix : suivre le remplissage, une fois par semaine.
	if jour % 7 == 0:
		ajuster_prix_auto(bid)
	# Investir ce qui dépasse la réserve, dans le meilleur rapport effet / prix.
	var charges := maxf(float(hier(bid).get("charges", 0.0)), 500.0 if source(bid) == "tourisme" else 150.0)
	var dispo := compte(bid) - charges * RESERVE_JOURS
	if dispo <= 0.0:
		return
	var best := {}
	var best_score := 0.0
	for c in candidats(bid):
		if float(c.prix) > dispo:
			continue
		var score := float(c.valeur) / float(c.prix)
		if score > best_score:
			best_score = score
			best = c
	if best.is_empty():
		return
	match String(best.type):
		"niveau":
			ameliorer(bid, String(best.piece), true)
		"objet":
			acheter(bid, String(best.piece), String(best.objet), true)
		"formation":
			former(bid, true)


## Tout ce qui peut s'acheter, avec une « valeur » (effets pondérés).
func candidats(bid: int) -> Array:
	var out: Array = []
	var g := genre_of(bid)
	for pid in GestionTypes.ordre(g):
		var p := GestionTypes.piece(g, String(pid))
		var px := prix(bid, String(pid))
		if px > 0:
			out.append({"type": "niveau", "piece": String(pid), "prix": px, "valeur": _valeur(p.get("effets", {})) * (1.3 if niveau(bid, String(pid)) == 0 else 1.0)})
		for oid in GestionTypes.objets(g, String(pid)):
			if refus_objet(bid, String(pid), String(oid)) == "":
				out.append({"type": "objet", "piece": String(pid), "objet": String(oid), "prix": prix_objet(bid, String(pid), String(oid)),
					"valeur": _valeur(GestionTypes.objet(g, String(pid), String(oid)).get("effets", {}))})
	var pf := prix_formation(bid)
	if pf > 0:
		out.append({"type": "formation", "prix": pf, "valeur": 0.08})
	return out


static func _valeur(e: Dictionary) -> float:
	return float(e.get("confort", 0.0)) * 1.0 + float(e.get("attrait", 0.0)) * 1.6 + float(e.get("satisf", 0.0)) * 1.0 \
		+ float(e.get("lits", 0.0)) * 2.5 + float(e.get("couverts", 0.0)) * 2.0 + float(e.get("repas", 0.0)) * 0.8 + float(e.get("vitesse", 0.0)) * 0.15 + float(e.get("ventes", 0.0)) * 0.02


# --- Chiffres de l'établissement (selon sa source) ------------------------------------------------

## Clients du moment : ce soir (hôtel) ou servis hier (restaurant).
func clients(bid: int) -> int:
	if source(bid) == "production":
		var st: Dictionary = etats.get(bid, {})
		var h: Dictionary = st.get("hier", {})
		if h.has("clients"):
			return roundi(float(h.clients))
		return roundi(float((st.get("j", {}) as Dictionary).get("clients", 0.0)))
	return tourisme.clients(bid) if tourisme != null and tourisme.heb.has(bid) else 0


## Capacité : lits (hôtel) ou couverts par jour (restaurant).
func capacite(bid: int) -> int:
	if source(bid) == "production":
		var h: Dictionary = (etats.get(bid, {}) as Dictionary).get("hier", {})
		if float(h.get("cap", 0.0)) > 0.0:
			return roundi(float(h.cap))
		var vis := float(BuildingCatalog.get_type(type_of(bid)).get("visiteurs", 100)) * Ameliorations.facteur_bid(buildings, bid)
		return roundi(vis * couverts(bid))
	return tourisme.lits(bid) if tourisme != null and tourisme.heb.has(bid) else 0


func occupation(bid: int) -> float:
	if source(bid) == "production":
		var c := capacite(bid)
		return clampf(float(clients(bid)) / float(c), 0.0, 1.0) if c > 0 else 0.0
	return tourisme.occupation(bid) if tourisme != null and tourisme.heb.has(bid) else 0.0


func note(bid: int) -> float:
	if source(bid) == "production":
		return float((etats.get(bid, {}) as Dictionary).get("note", 3.0))
	return tourisme.note(bid) if tourisme != null and tourisme.heb.has(bid) else 0.0


func satisf(bid: int) -> float:
	if source(bid) == "production":
		return float((etats.get(bid, {}) as Dictionary).get("satisf", 3.0))
	return float(tourisme.heb[bid].get("satisf", 3.0)) if tourisme != null and tourisme.heb.has(bid) else 3.0


func _ajouter_satisf(bid: int, dv: float) -> void:
	if source(bid) == "production":
		if etats.has(bid):
			etats[bid].satisf = clampf(float(etats[bid].satisf) + dv, 0.5, 5.0)
	elif tourisme != null and tourisme.heb.has(bid):
		tourisme.heb[bid].satisf = clampf(float(tourisme.heb[bid].satisf) + dv, 0.5, 5.0)


## Recettes et charges de la veille : {ca, charges}.
func hier(bid: int) -> Dictionary:
	if source(bid) == "production":
		return (etats.get(bid, {}) as Dictionary).get("hier", {})
	return tourisme.heb[bid].get("hier", {}) if tourisme != null and tourisme.heb.has(bid) else {}


## Prix payé par un client : la nuit (hôtel) ou le menu (restaurant), en €.
func prix_unitaire(bid: int) -> float:
	if source(bid) == "production":
		return Ressources.REPAS * prix_repas(bid)
	return float(tourisme.heb[bid].prix) if tourisme != null and tourisme.heb.has(bid) else 0.0


func prix_txt(bid: int) -> String:
	var v := BuildingSystem.format_money(roundi(prix_unitaire(bid)))
	if source(bid) == "production":
		return "Prix moyen du repas : %s (%d %% du prix habituel)" % [v, roundi(float(etat(bid).prix) * 100.0)]
	return "Prix de la nuit : %s par personne" % v


## Monte (sens 1) ou baisse (-1) le prix de 5 %.
func changer_prix(bid: int, sens: int) -> void:
	if source(bid) == "production":
		var st := etat(bid)
		if not st.is_empty():
			st.prix = clampf(snappedf(float(st.prix) * (1.0 + 0.05 * sens), 0.01), PRIX_MIN, PRIX_MAX)
			changed.emit(bid)
	elif tourisme != null and tourisme.heb.has(bid):
		tourisme.set_prix(bid, roundf(float(tourisme.heb[bid].prix) * (1.0 + 0.05 * sens)))
		changed.emit(bid)


## Gestion automatique du prix : suivre le remplissage.
func ajuster_prix_auto(bid: int) -> void:
	var occ := occupation(bid)
	if source(bid) == "production":
		var st := etat(bid)
		var p := float(st.prix)
		if occ > 0.9:
			p *= 1.04
		elif occ < 0.5:
			p *= 0.97
		st.prix = clampf(snappedf(p, 0.01), 0.85, 1.6)
		return
	if tourisme == null or not tourisme.heb.has(bid):
		return
	var ref := float(tourisme.spec(bid).get("prix", 60.0))
	var p := float(tourisme.heb[bid].prix)
	if occ > 0.9:
		p *= 1.04
	elif occ < 0.45:
		p *= 0.96
	tourisme.set_prix(bid, clampf(roundf(p), ref * 0.75, ref * 1.35))


# --- Restaurant : ce que la gestion change dans l'économie (Production) --------------------------

## Prix du menu : facteur du prix habituel des repas.
const PRIX_MIN := 0.6
const PRIX_MAX := 2.0


## Couverts : facteur de la capacité de service (tables en plus).
func couverts(bid: int) -> float:
	return 1.0 + maxf(0.0, effet(bid, "couverts"))


## Clients qui viennent, en facteur des clients habituels : la note, l'attrait
## et le prix du menu jouent, les couverts plafonnent.
func affluence(bid: int) -> float:
	if not etats.has(bid) or source(bid) != "production":
		return 1.0
	var st: Dictionary = etats[bid]
	var envie := clampf(1.0 + 0.15 * (float(st.note) - 3.0) + effet(bid, "attrait"), 0.3, 2.2) / pow(maxf(0.3, float(st.prix)), 1.3)
	return clampf(envie * (1.0 + 0.6 * maxf(0.0, effet(bid, "couverts"))), 0.1, couverts(bid))


## Prix d'un repas, en facteur de Ressources.REPAS : prix choisi, toques,
## et ce que les clients prennent en plus (vin, dessert, café).
func prix_repas(bid: int) -> float:
	if not etats.has(bid) or source(bid) != "production":
		return 1.0
	var st: Dictionary = etats[bid]
	return float(st.prix) * (1.0 + 0.08 * float(etoiles(bid) - int(spec_base(bid).get("etoiles", 1)))) + effet(bid, "ventes") * float(GestionTypes.genre(genre_of(bid)).get("ventes_mult", 1.0)) / Ressources.REPAS


## Compte les repas du jour (appelé par Production quand elle sert).
func compter(bid: int, euros: float, servis: float, cap: float) -> void:
	if not etats.has(bid):
		return
	var j: Dictionary = etats[bid].j
	j["ca"] = float(j.get("ca", 0.0)) + euros
	j["clients"] = float(j.get("clients", 0.0)) + servis
	j["cap"] = float(j.get("cap", 0.0)) + cap


## Fin de la journée d'une entreprise gérée (appelée par Production après les
## salaires) : historique, satisfaction et note du lendemain.
func cloture(bid: int, charges: float) -> void:
	if not etats.has(bid) or source(bid) != "production":
		return
	var st: Dictionary = etats[bid]
	var j: Dictionary = st.j
	var manque := production != null and production.sites.has(bid) and not (production.sites[bid].get("manque", {}) as Dictionary).is_empty()
	st.hier = {"ca": float(j.get("ca", 0.0)), "charges": charges, "clients": float(j.get("clients", 0.0)), "cap": float(j.get("cap", 0.0)), "manque": manque}
	st.j = {}
	var cible := 3.0 + 3.0 * effet(bid, "satisf") + 0.5 * effet(bid, "confort") - 1.4 * (float(st.prix) - 1.0) - (0.7 if manque else 0.0)
	st.satisf = clampf(lerpf(float(st.satisf), clampf(cible, 0.5, 5.0), 0.2), 0.5, 5.0)
	st.note = clampf(2.7 + 0.3 * float(etoiles(bid)) + 0.6 * (float(st.satisf) - 3.0), 0.5, 5.0)
	(st.hist as Array).append([jour, float(st.hier.ca), charges, roundi(float(st.hier.clients)),
		snappedf(occupation(bid), 0.01), snappedf(float(st.note), 0.01), snappedf(float(st.satisf), 0.01)])
	while (st.hist as Array).size() > HISTORIQUE:
		(st.hist as Array).pop_front()


static func _inst() -> Gestion:
	if instance == null or not is_instance_valid(instance):
		return null
	return instance


static func affluence_de(bid: int) -> float:
	return _inst().affluence(bid) if _inst() != null else 1.0


static func couverts_de(bid: int) -> float:
	return _inst().couverts(bid) if _inst() != null and _inst().etats.has(bid) else 1.0


static func prix_repas_de(bid: int) -> float:
	return _inst().prix_repas(bid) if _inst() != null else 1.0


static func compter_de(bid: int, euros: float, servis: float, cap: float) -> void:
	if _inst() != null:
		_inst().compter(bid, euros, servis, cap)


## Entretien à payer par une entreprise gérée (0 pour les autres).
static func entretien_site(bid: int) -> float:
	var g := _inst()
	if g == null or not g.etats.has(bid) or g.source(bid) != "production":
		return 0.0
	return g.entretien_jour(bid)


static func cloture_de(bid: int, charges: float) -> void:
	if _inst() != null:
		_inst().cloture(bid, charges)


## Critique gastronomique, inspection d'hygiène, banquet, célébrité, match.
func _evenements_restaurant(bid: int, st: Dictionary) -> void:
	# Critique du guide : environ une fois par mois.
	if int(st.inspection) < 0:
		st.inspection = jour + rng.randi_range(10, 40)
	elif jour >= int(st.inspection):
		st.inspection = jour + rng.randi_range(25, 50)
		var n := note(bid)
		var vise := 2.6 + 0.4 * float(etoiles(bid))
		if n >= vise:
			st.label_fin = jour + 60
			_noter(bid, "Un critique gastronomique a dîné incognito : « Coup de cœur » du guide pendant 60 jours (+6 % de clients) !", true)
		else:
			_noter(bid, "Un critique gastronomique a dîné incognito : pas de coup de cœur (note %.1f, il fallait %.1f)." % [n, vise], true)
	# Inspection d'hygiène : amende si la cuisine, la plonge ou la réserve sont en panne.
	if rng.randf() < 0.02:
		var sales := 0
		for p in st.pannes:
			if String(p.piece) in ["cuisine", "plonge", "reserve", "toilettes"]:
				sales += 1
		if sales > 0:
			var amende := 300.0 * sales * (1.0 + 0.5 * float(etoiles(bid)))
			_crediter(bid, -amende)
			_ajouter_satisf(bid, -0.2)
			_noter(bid, "Inspection d'hygiène : %d problème%s, amende de %s." % [sales, "s" if sales > 1 else "", BuildingSystem.format_money(int(amende))], true)
		else:
			_noter(bid, "Inspection d'hygiène : cuisine impeccable, rien à signaler.", false)
	# Banquets dans le salon privé.
	var salon := niveau(bid, "salle_privee")
	if salon > 0 and rng.randf() < 0.07 * salon:
		var qui := ["Un mariage", "Un repas d'entreprise", "Les 80 ans d'une grand-mère", "Le club de foot après sa victoire", "Une communion"]
		var v := 600.0 * salon * (1.0 + 0.4 * objets_de(bid, "salle_privee").size())
		_crediter(bid, v)
		st.seminaires = int(st.seminaires) + 1
		_noter(bid, "%s dans le salon privé : %s encaissés." % [String(qui[rng.randi() % qui.size()]), BuildingSystem.format_money(int(v))], false)
	# Client célèbre.
	if rng.randf() < 0.012 * float(etoiles(bid)):
		var tip := 60.0 * float(etoiles(bid))
		_crediter(bid, tip)
		st.vip = int(st.vip) + 1
		var qui := ["Un chef étoilé venu en voisin", "Une chanteuse célèbre", "Le maire et son conseil", "Un acteur de cinéma", "Une influenceuse culinaire"]
		_noter(bid, "%s a dîné ici et laissé %s de pourboire." % [String(qui[rng.randi() % qui.size()]), BuildingSystem.format_money(int(tip))], false)
	# Soir de match : le bar se remplit.
	if niveau(bid, "bar") > 0 and rng.randf() < 0.04 * (2.0 if "tele_sport" in objets_de(bid, "bar") else 0.5):
		var v := 150.0 * niveau(bid, "bar")
		_crediter(bid, v)
		_noter(bid, "Soir de match : le bar est plein, %s de boissons en plus." % BuildingSystem.format_money(int(v)), false)


# --- Objectifs ---------------------------------------------------------------------------------

## Petits objectifs de l'établissement : [{texte, fait, avance}].
func objectifs(bid: int) -> Array:
	var out: Array = []
	var g := genre_of(bid)
	var tot := 0
	var construites := 0
	for pid in GestionTypes.ordre(g):
		tot += gagnes(bid, String(pid))
		if niveau(bid, String(pid)) > 0:
			construites += 1
	var st: Dictionary = etats.get(bid, {})
	var reglees := int(st.get("reglees", 0))
	var gd := GestionTypes.genre(g)
	var occ := occupation(bid) if valide(bid) else 0.0
	var nt := note(bid) if valide(bid) else 0.0
	var nobj := nb_objets(bid)
	var cl := String(gd.get("classe", "étoiles"))
	out.append({"texte": "Faire 3 améliorations", "fait": tot >= 3, "avance": "%d / 3" % mini(tot, 3)})
	out.append({"texte": "Installer 15 objets", "fait": nobj >= 15, "avance": "%d / 15" % mini(nobj, 15)})
	out.append({"texte": "Régler 10 demandes de clients", "fait": reglees >= 10, "avance": "%d / 10" % mini(reglees, 10)})
	out.append({"texte": String(gd.get("remplir", "Remplir à 75 %")), "fait": occ >= 0.75, "avance": "%d %%" % roundi(occ * 100.0)})
	out.append({"texte": "Note de 4 sur 5", "fait": nt >= 4.0, "avance": "%.1f / 5" % nt})
	out.append({"texte": "Être recommandé par le guide", "fait": int(st.get("label_fin", -1)) >= jour, "avance": "en cours" if int(st.get("label_fin", -1)) >= jour else "pas encore"})
	out.append({"texte": "Construire toutes les pièces", "fait": construites >= GestionTypes.ordre(g).size(), "avance": "%d / %d" % [construites, GestionTypes.ordre(g).size()]})
	out.append({"texte": "Atteindre 5 %s" % cl, "fait": etoiles(bid) >= 5, "avance": "%d / 5" % etoiles(bid)})
	return out


# --- Sauvegarde --------------------------------------------------------------------------------

## Oublie les bâtiments démolis.
func nettoyer() -> void:
	if buildings == null:
		return
	for bid in etats.keys():
		if not buildings.buildings.has(bid) or genre_of(int(bid)) != String(etats[bid].genre):
			etats.erase(bid)


func to_dict() -> Dictionary:
	nettoyer()
	var out := {}
	for bid in etats:
		out[str(bid)] = etats[bid].duplicate(true)
	return {"etats": out, "jour": jour}


func from_dict(d: Dictionary) -> void:
	clear()
	jour = int(d.get("jour", 0))
	var src: Dictionary = d.get("etats", {})
	for k in src:
		var s: Dictionary = src[k]
		var st := _etat_vide(String(s.get("genre", "hotel")))
		for f in st:
			if s.has(f):
				st[f] = s[f]
		var niv := {}
		for pid in (s.get("niv", {}) as Dictionary):
			niv[String(pid)] = int(s.niv[pid])
		st.niv = niv
		var obj := {}
		for pid in (s.get("obj", {}) as Dictionary):
			var l: Array = []
			for o in s.obj[pid]:
				l.append(String(o))
			obj[String(pid)] = l
		st.obj = obj
		for f in ["reglees", "ratees", "reparees", "formation", "label_fin", "inspection", "seminaires", "vip"]:
			st[f] = int(st[f])
		for f in ["pourboires", "invest", "aide_ville", "salaire", "prix", "satisf", "note"]:
			st[f] = float(st[f])
		st.auto = bool(st.auto)
		for f in ["j", "hier"]:
			st[f] = (st[f] as Dictionary).duplicate() if st[f] is Dictionary else {}
		var jl: Array = []
		for e in st.journal:
			jl.append([int(e[0]), String(e[1])])
		st.journal = jl
		var pn: Array = []
		for p in st.pannes:
			pn.append({"piece": String(p.piece), "texte": String(p.texte), "jour": int(p.get("jour", 0))})
		st.pannes = pn
		etats[int(k)] = st
	nettoyer()
