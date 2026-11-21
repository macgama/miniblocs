class_name Gestion
extends Node
## Mode gestion « tycoon » d'un bâtiment : niveaux des pièces, investissements,
## petites demandes des clients, et ce que tout cela change dans la ville.
##
## Le joueur clique sur un hôtel → fiche → « Gérer l'hôtel » : la vue
## isométrique (GestionVue) montre les pièces, le personnel et les clients.
## Chaque pièce a un niveau ; l'améliorer coûte de l'argent (d'abord le compte
## de l'hôtel, le reste avancé par la caisse de la ville) et apporte des
## effets (GestionTypes : lits, confort, attrait, satisfaction, repas sur
## place) que les systèmes du jeu lisent avec Gestion.effet_de(bid, clé) :
## l'hôtel gagne des lits, des clients, une meilleure note, puis des étoiles,
## donc plus de nuitées, de taxe de séjour et d'impôts pour la ville.
##
## Le rythme est celui du jeu (1 jour = 1 minute par défaut, pause = arrêt) :
## rien ne se gagne pendant que le jeu est fermé. Un bâtiment jamais ouvert
## en mode gestion n'a aucun état ici et fonctionne exactement comme avant.

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

var buildings: BuildingSystem
var tourisme: Tourisme
## bid → {"genre", "niv": {pièce: niveau}, "pourboires", "reglees", "ratees", "invest", "aide_ville"}
var etats: Dictionary = {}


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func setup(b: BuildingSystem, t: Tourisme) -> void:
	buildings = b
	tourisme = t


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
	return TourismeTypes.spec_of(type_of(bid))


## État de gestion du bâtiment (créé au premier passage).
func etat(bid: int) -> Dictionary:
	if etats.has(bid):
		return etats[bid]
	var g := genre_of(bid)
	if g == "":
		return {}
	var st := {"genre": g, "niv": {}, "pourboires": 0.0, "reglees": 0, "ratees": 0, "invest": 0.0, "aide_ville": 0.0}
	for pid in GestionTypes.ordre(g):
		st.niv[String(pid)] = niveau_depart(bid, String(pid))
	etats[bid] = st
	return st


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


## Effet total d'une clé (GestionTypes.EFFETS) pour un bâtiment.
func effet(bid: int, cle: String) -> float:
	if not etats.has(bid):
		return 0.0
	var g := String(etats[bid].genre)
	var s := 0.0
	for pid in GestionTypes.ordre(g):
		var e: Dictionary = GestionTypes.piece(g, String(pid)).get("effets", {})
		if e.has(cle):
			s += float(e[cle]) * gagnes(bid, String(pid))
	return s


static func effet_de(bid: int, cle: String) -> float:
	if instance == null or not is_instance_valid(instance):
		return 0.0
	return instance.effet(bid, cle)


## Charges d'entretien en plus, par jour (€).
func entretien_jour(bid: int) -> float:
	if not etats.has(bid):
		return 0.0
	var g := String(etats[bid].genre)
	var s := 0.0
	for pid in GestionTypes.ordre(g):
		var e: Dictionary = GestionTypes.piece(g, String(pid)).get("effets", {})
		s += float(e.get("entretien", 0.0)) * gagnes(bid, String(pid))
	return s


static func entretien_de(bid: int) -> float:
	if instance == null or not is_instance_valid(instance):
		return 0.0
	return instance.entretien_jour(bid)


## Étoiles du bâtiment : celles de son type, plus celles gagnées par le confort.
func etoiles(bid: int) -> int:
	var base := int(spec_base(bid).get("etoiles", 2))
	return mini(5, base + int(floorf(effet(bid, "confort") / SEUIL_ETOILE + 0.001)))


## Confort à gagner encore avant la prochaine étoile (0 : déjà 5 étoiles).
func avant_etoile(bid: int) -> float:
	if etoiles(bid) >= 5:
		return 0.0
	var c := effet(bid, "confort")
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
		c = float(spec_base(bid).get("chambres", 30)) * 60_000.0
	return c


## Prix du prochain niveau (0 : déjà au maximum).
func prix(bid: int, pid: String) -> int:
	var n := niveau(bid, pid)
	if n >= niveau_max(bid, pid):
		return 0
	var p := GestionTypes.piece(genre_of(bid), pid)
	var base := cout_batiment(bid) * float(p.get("prix", 0.005))
	var v := base * CONSTRUIRE if n == 0 else base * pow(PROGRESSION, float(n - 1))
	return maxi(500, int(roundf(v / 100.0)) * 100)


## Argent du compte du bâtiment (hôtel privé : ses bénéfices accumulés).
func compte(bid: int) -> float:
	if tourisme != null and tourisme.heb.has(bid):
		return float(tourisme.heb[bid].compte)
	return 0.0


func _crediter(bid: int, v: float) -> void:
	if tourisme != null and tourisme.heb.has(bid):
		tourisme.heb[bid].compte = float(tourisme.heb[bid].compte) + v


func caisse_ville() -> int:
	return buildings.money if buildings != null else 0


## Ce que paieraient le compte du bâtiment et la caisse de la ville.
func repartition(bid: int, montant: int) -> Dictionary:
	var dispo := maxf(0.0, compte(bid))
	var du_bat := minf(dispo, float(montant))
	return {"batiment": int(du_bat), "ville": montant - int(du_bat)}


## Passe une pièce au niveau suivant (ou la construit). Renvoie {ok, error, batiment, ville}.
func ameliorer(bid: int, pid: String) -> Dictionary:
	if not gerable(bid):
		return {"ok": false, "error": "ce bâtiment ne se gère pas"}
	if not GestionTypes.pieces(genre_of(bid)).has(pid):
		return {"ok": false, "error": "pièce inconnue"}
	var p := prix(bid, pid)
	if p <= 0:
		return {"ok": false, "error": "déjà au niveau maximum"}
	var r := repartition(bid, p)
	var gratuit := buildings.unlimited_money
	if not gratuit and int(r.ville) > 0 and caisse_ville() < int(r.ville):
		return {"ok": false, "error": "pas assez d'argent (il manque %s)" % BuildingSystem.format_money(int(r.ville) - caisse_ville())}
	var st := etat(bid)
	if not gratuit:
		_crediter(bid, -float(r.batiment))
		if int(r.ville) > 0:
			_depense_ville("Gestion : avance à %s" % _nom(bid), float(r.ville))
			st.aide_ville = float(st.aide_ville) + float(r.ville)
	st.invest = float(st.invest) + float(p)
	var avant := niveau(bid, pid)
	var e0 := etoiles(bid)
	st.niv[pid] = avant + 1
	var nom_p := String(GestionTypes.piece(String(st.genre), pid).get("nom", pid))
	if avant == 0:
		message.emit("%s : %s construit." % [_nom(bid), nom_p])
	else:
		message.emit("%s : %s au niveau %d." % [_nom(bid), nom_p, avant + 1])
	if etoiles(bid) > e0:
		message.emit("%s gagne une étoile : %d étoiles !" % [_nom(bid), etoiles(bid)])
	changed.emit(bid)
	return {"ok": true, "batiment": int(r.batiment), "ville": int(r.ville), "gratuit": gratuit}


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
		bc.recette("Gestion : remboursement de %s" % _nom(bid), float(v))
	elif buildings != null and not buildings.unlimited_money:
		buildings.money += v
	changed.emit(bid)
	return v


func _nom(bid: int) -> String:
	if tourisme != null and tourisme.heb.has(bid):
		return tourisme.nom(bid)
	return String(BuildingCatalog.get_type(type_of(bid)).get("name", "Bâtiment"))


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
	if tourisme != null and tourisme.heb.has(bid):
		tourisme.heb[bid].satisf = clampf(float(tourisme.heb[bid].satisf) + SATISF_REGLEE, 0.5, 5.0)
	changed.emit(bid)
	return tip


## Demande oubliée : les clients sont un peu déçus.
func rater(bid: int) -> void:
	var st := etat(bid)
	if st.is_empty():
		return
	st.ratees = int(st.ratees) + 1
	if tourisme != null and tourisme.heb.has(bid):
		tourisme.heb[bid].satisf = clampf(float(tourisme.heb[bid].satisf) - SATISF_RATEE, 0.5, 5.0)
	changed.emit(bid)


# --- Objectifs ---------------------------------------------------------------------------------

## Petits objectifs de l'établissement : [{texte, fait}].
func objectifs(bid: int) -> Array:
	var out: Array = []
	var g := genre_of(bid)
	var tot := 0
	for pid in GestionTypes.ordre(g):
		tot += gagnes(bid, String(pid))
	var reglees := int(etats.get(bid, {}).get("reglees", 0))
	var occ := tourisme.occupation(bid) if tourisme != null and tourisme.heb.has(bid) else 0.0
	var note := tourisme.note(bid) if tourisme != null and tourisme.heb.has(bid) else 0.0
	out.append({"texte": "Faire 3 améliorations", "fait": tot >= 3, "avance": "%d / 3" % mini(tot, 3)})
	out.append({"texte": "Régler 10 demandes de clients", "fait": reglees >= 10, "avance": "%d / 10" % mini(reglees, 10)})
	out.append({"texte": "Remplir l'hôtel à 75 %", "fait": occ >= 0.75, "avance": "%d %%" % roundi(occ * 100.0)})
	out.append({"texte": "Note de 4 sur 5", "fait": note >= 4.0, "avance": "%.1f / 5" % note})
	out.append({"texte": "Atteindre 5 étoiles", "fait": etoiles(bid) >= 5, "avance": "%d / 5" % etoiles(bid)})
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
	return {"etats": out}


func from_dict(d: Dictionary) -> void:
	clear()
	var src: Dictionary = d.get("etats", {})
	for k in src:
		var s: Dictionary = src[k]
		var niv := {}
		for pid in (s.get("niv", {}) as Dictionary):
			niv[String(pid)] = int(s.niv[pid])
		etats[int(k)] = {"genre": String(s.get("genre", "hotel")), "niv": niv, "pourboires": float(s.get("pourboires", 0.0)),
			"reglees": int(s.get("reglees", 0)), "ratees": int(s.get("ratees", 0)), "invest": float(s.get("invest", 0.0)),
			"aide_ville": float(s.get("aide_ville", 0.0))}
	nettoyer()
