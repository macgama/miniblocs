class_name Ameliorations
extends Node
## Amélioration des bâtiments posés (nœud « Ameliorations » créé par terre_main) :
##
## - Agrandissement en 3 niveaux : le niveau 2 accueille 50 % de monde en plus
##   (logements, emplois, élèves, lits, visiteurs, puissance d'une centrale,
##   débit d'une station…), le niveau 3 le double. L'agrandissement est un vrai
##   chantier : échafaudages, grue pour les grands, marqueur, payé au fil des
##   travaux par la caisse de la ville (arrêté si elle est vide). Le bâtiment
##   reste ouvert pendant les travaux, avec sa capacité d'avant.
## - Visuel par niveau : un ou plusieurs étages en plus. Les bâtiments faits en
##   code dont la forme se règle (maisons, immeubles, écoles, bureaux…) sont
##   reconstruits avec plus d'étages et leur toit ; les autres (modèles Blender,
##   usines, halles…) reçoivent un étage inséré sous le toit.
## - Rénovation : façade et toit refaits, l'usure repart de zéro.
## - Densification du zonage : un bâtiment poussé par le zonage, plein, dans un
##   quartier qui prend de la valeur et une ville qui demande ce type de zone,
##   est agrandi par ses propriétaires (sans frais pour la ville).
##
## Données gardées dans le bâtiment (sauvegardées avec lui, envoyées aux joueurs
## d'une carte entre amis) : "niv" (niveau, absent = 1), "renov" (date de la
## dernière rénovation, secondes Unix du jeu) et "amel" (chantier en cours :
## {"op": "niv" ou "renov", "cible", "av", "hr", "du", "cout", "prive"}).

signal message(text: String)
signal changed

static var instance: Ameliorations

const NIVEAU_MAX := 3
## Capacité par niveau (indice = niveau).
const FACTEURS := [1.0, 1.0, 1.5, 2.0]
## Prix de l'agrandissement vers ce niveau, en part du prix du bâtiment.
const PRIX := [0.0, 0.0, 0.6, 0.8]
## Durée du chantier vers ce niveau, en part des heures du chantier neuf.
const DUREE := [0.0, 0.0, 0.45, 0.6]
## Rénovation : part du prix et des heures du chantier neuf.
const PRIX_RENOV := 0.15
const DUREE_RENOV := 0.15
## Usure au-dessus de laquelle la rénovation est proposée (0 à 1).
const USURE_RENOV := 0.15
## Densification : jours de jeu au moins entre deux agrandissements d'un même
## bâtiment, valeur du terrain demandée par niveau visé.
const DELAI_DENSIF_J := 45.0
const VALEUR_DENSIF := [0.0, 0.0, 1.05, 1.3]
## Hauteur d'un étage ajouté (m).
const ETAGE := 3.0

## Agrandissements privés des zones (réglable, sauvegardé).
var densification := true

var buildings: BuildingSystem
var vie: BatimentsVie
var population: Population
var zones: ZoneSystem
## Optionnel : Nuisances (valeur du terrain).
var nuisances: Node

## bid -> {"echaf", "grue", "texte", "mi", "bb"} (le marqueur : scripts/chantiers/marqueurs_chantiers.gd)
var _vus := {}
var _t_prev := -1.0
var _acc := 0.0
var _acc_densif := 0.0
var _tour := 0
var _clock := 0.0
var _derniere_alerte := -1.0e12
var _dernier_msg_densif := -1.0e12


func setup(b: BuildingSystem, v: BatimentsVie, p: Population, z: ZoneSystem) -> void:
	instance = self
	buildings = b
	vie = v
	population = p
	zones = z
	_t_prev = now()
	buildings.added.connect(_on_added)
	buildings.removed.connect(_on_removed)
	for bid in buildings.buildings:
		_on_added(bid)


func _exit_tree() -> void:
	if instance == self:
		instance = null


func now() -> float:
	return vie.now() if vie != null else _clock


# --- Niveaux et capacités ----------------------------------------------------------------

static func niveau(b: Dictionary) -> int:
	return clampi(int(b.get("niv", 1)), 1, NIVEAU_MAX)


## Multiplicateur de capacité d'un bâtiment posé (1 ; 1,5 ; 2).
static func facteur(b: Dictionary) -> float:
	return float(FACTEURS[niveau(b)])


static func facteur_bid(bs: BuildingSystem, bid: int) -> float:
	if bs == null or not bs.buildings.has(bid):
		return 1.0
	return facteur(bs.buildings[bid])


## Capacité d'un champ du catalogue (logements, emplois, visiteurs…) pour ce bâtiment.
static func cap(b: Dictionary, key: String, defaut := 0) -> int:
	var v := int(BuildingCatalog.get_type(String(b.get("t", ""))).get(key, defaut))
	return roundi(v * facteur(b))


## Un type de bâtiment peut-il être agrandi ? Ceux qui accueillent du monde ou
## produisent (logements, emplois, places, réseau), sauf les campements, les
## créations en blocs, les stades et les espaces publics.
static func ameliorable(type_id: String) -> bool:
	var t := BuildingCatalog.get_type(type_id)
	if t.is_empty() or t.has("blocks") or t.has("stade") or t.get("espace", false) or t.get("campement", false):
		return false
	if float(ReseauxTypes.info(type_id).get("cap", 0.0)) > 0.0:
		return true
	return int(t.get("logements", 0)) + int(t.get("emplois", 0)) + int(t.get("visiteurs", 0)) > 0


## Étages ajoutés par la personnalisation (bâtiments dont la forme se règle).
static func _etages_perso(type_id: String, niv: int, perso: Dictionary = {}) -> int:
	var base := Personnalisation.base_floors(type_id, perso)
	return (niv - 1) * maxi(1, roundi(base * 0.3))


## Étages à insérer dans le maillage (bâtiments dont la forme ne se règle pas).
static func etages_inseres(b: Dictionary) -> int:
	var niv := niveau(b)
	if niv <= 1 or not ameliorable(String(b.t)) or Personnalisation.can_shape(String(b.t), b.get("perso", {})):
		return 0
	return niv - 1


## Personnalisation à dessiner : celle du joueur, plus les étages des niveaux.
static func perso_effectif(b: Dictionary) -> Dictionary:
	var perso: Dictionary = b.get("perso", {})
	var niv := niveau(b)
	var tid := String(b.t)
	if niv <= 1 or not Personnalisation.can_shape(tid, perso) or not ameliorable(tid):
		return perso
	var out := perso.duplicate()
	var et := int(perso.get("etages", Personnalisation.base_floors(tid, perso)))
	out["etages"] = mini(et + _etages_perso(tid, niv, perso), maxi(et, Personnalisation.max_floors(tid, perso) + 2 * (niv - 1)))
	return out


## Étages ajoutés en tout (pour l'affichage).
static func etages_ajoutes(b: Dictionary) -> int:
	var tid := String(b.t)
	if niveau(b) <= 1:
		return 0
	if Personnalisation.can_shape(tid, b.get("perso", {})):
		return int(perso_effectif(b).get("etages", 0)) - int((b.get("perso", {}) as Dictionary).get("etages", Personnalisation.base_floors(tid, b.get("perso", {}))))
	return 0


# --- Maillage : étages insérés -----------------------------------------------------------

## Copie d'un maillage avec des étages en plus : les murs s'étirent, les fenêtres
## et détails d'un étage courant sont recopiés, le toit monte. Les bâtiments bas
## (halles, entrepôts) sont simplement rehaussés.
static func inserer_etages(mesh: ArrayMesh, n: int) -> ArrayMesh:
	if mesh == null or n <= 0 or mesh.get_surface_count() == 0:
		return mesh
	var bb := BatimentsVie.body_bounds(mesh)
	var H := bb.end.y
	var y_c := 0.0
	var decal := 0.0
	var copie := 0
	if H >= 7.5:
		# Bâtiment à étages : on recopie l'étage juste sous la coupe.
		var nb := maxi(2, floori(H / 3.2))
		var ajout := n * maxi(1, roundi(nb * 0.3))
		y_c = clampf(ETAGE * floorf(minf(H * 0.55, H - 3.5) / ETAGE), ETAGE, H)
		decal = ETAGE * ajout
		copie = ajout
	else:
		y_c = H * 0.45
		decal = 2.0 * n
	var out := ArrayMesh.new()
	const E := 0.02
	for s in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(s)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var ns: PackedVector3Array = arr[Mesh.ARRAY_NORMAL] if arr[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var cs: PackedColorArray = arr[Mesh.ARRAY_COLOR] if arr[Mesh.ARRAY_COLOR] != null else PackedColorArray()
		var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV] if arr[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if idx.is_empty():
			idx.resize(vs.size())
			for i in vs.size():
				idx[i] = i
		var ov := PackedVector3Array()
		var on := PackedVector3Array()
		var oc := PackedColorArray()
		var ou := PackedVector2Array()
		var emit := func(i: int, dy: float) -> void:
			ov.append(vs[i] + Vector3(0, dy, 0))
			if not ns.is_empty():
				on.append(ns[i])
			if not cs.is_empty():
				oc.append(cs[i])
			if not uvs.is_empty():
				ou.append(uvs[i])
		for k in range(0, idx.size() - 2, 3):
			var a := idx[k]
			var b := idx[k + 1]
			var c := idx[k + 2]
			var ya := vs[a].y
			var yb := vs[b].y
			var yc := vs[c].y
			var lo := minf(ya, minf(yb, yc))
			var hi := maxf(ya, maxf(yb, yc))
			if hi <= y_c + E:
				for i in [a, b, c]:
					emit.call(i, 0.0)
				# Étage courant (fenêtres, bandeaux) : recopié plus haut. Les abords plats
				# (pelouse, allée, terrasse au sol) restent au sol.
				if copie > 0 and lo >= y_c - ETAGE - E and hi > 0.6:
					for j in copie:
						for i in [a, b, c]:
							emit.call(i, ETAGE * (j + 1))
			elif lo >= y_c - E:
				for i in [a, b, c]:
					emit.call(i, decal)
			else:
				# Mur qui traverse la coupe : il s'étire.
				for i in [a, b, c]:
					emit.call(i, decal if vs[i].y > y_c + E else 0.0)
		var na := []
		na.resize(Mesh.ARRAY_MAX)
		na[Mesh.ARRAY_VERTEX] = ov
		if not on.is_empty():
			na[Mesh.ARRAY_NORMAL] = on
		if not oc.is_empty():
			na[Mesh.ARRAY_COLOR] = oc
		if not ou.is_empty():
			na[Mesh.ARRAY_TEX_UV] = ou
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, na)
		out.surface_set_material(s, mesh.surface_get_material(s))
	for m in mesh.get_meta_list():
		out.set_meta(m, mesh.get_meta(m))
	if mesh.has_meta("ancres"):
		var anc: Dictionary = (mesh.get_meta("ancres") as Dictionary).duplicate(true)
		for kind in anc:
			var list: Array = anc[kind]
			for j in list.size():
				var p: Vector3 = list[j]
				if p.y > y_c:
					list[j] = p + Vector3(0, decal, 0)
		out.set_meta("ancres", anc)
	return out


# --- Prix, durée, conditions --------------------------------------------------------------

## Prix de la prochaine étape (agrandissement vers cible, ou rénovation si cible = 0).
func cout(bid: int, cible: int) -> int:
	var b: Dictionary = buildings.buildings.get(bid, {})
	if b.is_empty():
		return 0
	var base := float(ReglagesPartie.prix(BuildingCatalog.cost(String(b.t))))
	var part := PRIX_RENOV if cible <= 0 else float(PRIX[clampi(cible, 0, NIVEAU_MAX)])
	return roundi(base * part)


## Heures de travail du chantier.
func heures(bid: int, cible: int) -> float:
	var b: Dictionary = buildings.buildings.get(bid, {})
	if b.is_empty():
		return 0.0
	var part := DUREE_RENOV if cible <= 0 else float(DUREE[clampi(cible, 0, NIVEAU_MAX)])
	return maxf(8.0, Chantiers.heures_batiment(String(b.t)) * part)


## Durée prévue (secondes de jeu) d'un chantier d'amélioration commencé maintenant.
func duree_prevue(bid: int, cible: int) -> float:
	var h := heures(bid, cible) / Chantiers.rythme(population)
	var t := now()
	return Chantiers.date_apres(t, h, vie.offset_h() if vie != null else 0.0) - t


## Usure visible d'un bâtiment (0 à 1).
func usure(bid: int) -> float:
	if vie == null or not vie._etat.has(bid):
		return 0.0
	return clampf(float(vie._etat[bid].get("usure", 0)) / 5.0, 0.0, 1.0)


func en_cours(bid: int) -> Dictionary:
	if not buildings.buildings.has(bid):
		return {}
	return buildings.buildings[bid].get("amel", {})


## Raison qui empêche d'agrandir ("" : possible).
func refus_agrandir(bid: int) -> String:
	if not buildings.buildings.has(bid):
		return "Bâtiment introuvable."
	var b: Dictionary = buildings.buildings[bid]
	if not ameliorable(String(b.t)):
		return "Ce bâtiment ne s'agrandit pas."
	if Patrimoine.instance != null and Patrimoine.instance.raison_agrandir(bid) != "":
		return Patrimoine.instance.raison_agrandir(bid)
	if niveau(b) >= NIVEAU_MAX:
		return "Déjà agrandi au maximum (niveau %d)." % NIVEAU_MAX
	if buildings.en_chantier(bid):
		return "Attends la fin de son chantier."
	if not en_cours(bid).is_empty():
		return "Des travaux sont déjà en cours."
	return _refus_argent(b, cout(bid, niveau(b) + 1))


func refus_renover(bid: int) -> String:
	if not buildings.buildings.has(bid):
		return "Bâtiment introuvable."
	var b: Dictionary = buildings.buildings[bid]
	if buildings.en_chantier(bid):
		return "Attends la fin de son chantier."
	if not en_cours(bid).is_empty():
		return "Des travaux sont déjà en cours."
	if usure(bid) < USURE_RENOV:
		return "Encore en bon état."
	return _refus_argent(b, cout(bid, 0))


## La caisse peut-elle payer au moins la première semaine de travaux ?
func _refus_argent(b: Dictionary, prix: int) -> String:
	if buildings.unlimited_money or prix <= 0:
		return ""
	var caisse_prev := Pays.du_batiment(b, buildings._rect_of(b))
	var assez := buildings.money >= mini(prix, maxi(1, prix / 10))
	Pays.retour(caisse_prev)
	return "" if assez else "Pas assez d'argent dans la caisse (%s)." % BuildingSystem.format_money(prix)


# --- Lancer les travaux -------------------------------------------------------------------

## Agrandit un bâtiment d'un niveau (chantier payé au fil des travaux).
func agrandir(bid: int) -> bool:
	if _relayer({"t": "ameliorer", "bid": bid, "op": "niv"}):
		return true
	var why := refus_agrandir(bid)
	if why != "":
		message.emit(why)
		return false
	var b: Dictionary = buildings.buildings[bid]
	var cible := niveau(b) + 1
	_lancer(bid, "niv", cible, cout(bid, cible), false)
	message.emit("Agrandissement de %s lancé (niveau %d) : %s, payés au fil des travaux. Fin vers le %s." % [
		_nom(bid), cible, BuildingSystem.format_money(cout(bid, cible)), _date_fin(bid)])
	return true


func renover(bid: int) -> bool:
	if _relayer({"t": "ameliorer", "bid": bid, "op": "renov"}):
		return true
	var why := refus_renover(bid)
	if why != "":
		message.emit(why)
		return false
	_lancer(bid, "renov", 0, cout(bid, 0), false)
	message.emit("Rénovation de %s lancée : %s. Fin vers le %s." % [_nom(bid), BuildingSystem.format_money(cout(bid, 0)), _date_fin(bid)])
	return true


## Carte entre amis (client) : la demande part au serveur, qui renvoie le bâtiment.
func _relayer(action: Dictionary) -> bool:
	if buildings.verrou_reseau and not buildings._par_reseau and buildings.relais.is_valid():
		buildings.relais.call(action)
		return true
	return false


func _lancer(bid: int, op: String, cible: int, prix: int, prive: bool) -> void:
	var b: Dictionary = buildings.buildings[bid]
	b["amel"] = {"op": op, "cible": cible, "av": 0.0, "hr": heures(bid, cible), "du": 0 if prive or buildings.unlimited_money else prix,
		"cout": prix, "prive": prive, "ne": now()}
	# Carte entre amis : payé par la caisse du joueur qui l'a demandé, hors de ses villes.
	if Pays.payeur_force != -1:
		b.amel["caisse"] = Pays.payeur_force
	_montrer(bid)
	buildings.perso_changed.emit(bid)
	changed.emit()


## Termine tout de suite les travaux en cours (tests, chantiers instantanés).
func finir_tout() -> void:
	for bid in buildings.buildings.keys():
		if buildings.buildings.has(bid) and buildings.buildings[bid].has("amel"):
			_finir(bid)


## Change le niveau d'un bâtiment sans chantier (tests, Admin, chargement d'un modèle).
func regler_niveau(bid: int, niv: int) -> void:
	if not buildings.buildings.has(bid):
		return
	var b: Dictionary = buildings.buildings[bid]
	if niv <= 1:
		b.erase("niv")
	else:
		b["niv"] = clampi(niv, 1, NIVEAU_MAX)
	_appliquer_niveau(bid)


# --- Avancement des chantiers -------------------------------------------------------------

func _process(delta: float) -> void:
	_clock += EchelleTemps.dt(delta)
	if buildings == null:
		return
	_acc += delta
	_acc_densif += delta
	if _acc >= 0.25:
		_acc = 0.0
		_avancer()
	if _acc_densif >= 2.0:
		_acc_densif = 0.0
		if densification and not buildings.verrou_reseau:
			densifier()


func _avancer() -> void:
	var t := now()
	if _t_prev < 0.0:
		_t_prev = t
	# Carte entre amis (client) : le serveur fait avancer les travaux.
	if buildings.verrou_reseau:
		_t_prev = t
		return
	if not BatimentsVie.chantiers or Chantiers.instantanes():
		_t_prev = t
		if not _vus.is_empty() or _a_des_travaux():
			finir_tout()
		return
	var off := vie.offset_h() if vie != null else 0.0
	var h := Chantiers.heures_ouvrees(_t_prev, t, off)
	_t_prev = t
	if h <= 0.0 and _vus.is_empty():
		return
	var k := Chantiers.rythme(population)
	var finis := []
	for bid in _vus.keys():
		if not buildings.buildings.has(bid):
			_oublier(bid)
			continue
		var b: Dictionary = buildings.buildings[bid]
		var a: Dictionary = b.get("amel", {})
		if a.is_empty():
			_oublier(bid)
			continue
		if h > 0.0:
			var dp := minf(h * k / maxf(float(a.hr), 1.0), 1.0 - float(a.av))
			var du := int(a.get("du", 0))
			if du > 0:
				var part := mini(du, ceili(float(a.cout) * dp))
				var caisse_prev := _caisse(b)
				if not buildings.unlimited_money and buildings.money < part:
					if not a.get("attente", false):
						_alerte_argent(bid)
					a["attente"] = true
					dp = 0.0
				else:
					a.erase("attente")
					if not buildings.unlimited_money:
						buildings.money -= part
					a["du"] = du - part
				Pays.retour(caisse_prev)
			a["av"] = float(a.av) + dp
		if float(a.av) >= 0.9999:
			finis.append(bid)
		else:
			_maj_panneau(bid)
	for bid in finis:
		_finir(bid)
	if not _vus.is_empty():
		_animer()


## Entre dans la caisse qui paie les travaux (à refermer avec Pays.retour).
func _caisse(b: Dictionary, a: Dictionary = {}) -> int:
	if a.is_empty():
		a = b.get("amel", {})
	if a.has("caisse"):
		return Pays.a_la_caisse(int(a.caisse))
	return Pays.du_batiment(b, buildings._rect_of(b))


## Carte entre amis (client) : le serveur a envoyé le bâtiment ; on montre son niveau et ses travaux.
func depuis_reseau(bid: int, niv_avant: int) -> void:
	if not buildings.buildings.has(bid):
		return
	var b: Dictionary = buildings.buildings[bid]
	if niveau(b) != niv_avant:
		_appliquer_niveau(bid)
	if b.has("amel"):
		if _vus.has(bid):
			_maj_panneau(bid)
		else:
			_montrer(bid)
	elif _vus.has(bid):
		_oublier(bid)
	changed.emit()


func _a_des_travaux() -> bool:
	for b in buildings.buildings.values():
		if b.has("amel"):
			return true
	return false


func _alerte_argent(bid: int) -> void:
	var t := now()
	if t - _derniere_alerte < 86400.0:
		return
	_derniere_alerte = t
	message.emit("Travaux de %s arrêtés : la caisse est vide. Emprunte dans le Budget (M), ou attends les impôts du mois." % _nom(bid))


func _finir(bid: int) -> void:
	if not buildings.buildings.has(bid):
		_oublier(bid)
		return
	var b: Dictionary = buildings.buildings[bid]
	var a: Dictionary = b.get("amel", {})
	b.erase("amel")
	_oublier(bid)
	if a.is_empty():
		return
	var du := int(a.get("du", 0))
	if du > 0 and not buildings.unlimited_money:
		var caisse_prev := _caisse(b, a)
		buildings.money -= du
		Pays.retour(caisse_prev)
	# Travaux finis : façade neuve dans les deux cas.
	b["renov"] = now()
	if vie != null and vie._etat.has(bid):
		vie._etat[bid].usure = -1
	if String(a.op) == "niv":
		b["niv"] = clampi(int(a.cible), 2, NIVEAU_MAX)
		_appliquer_niveau(bid)
		if not bool(a.get("prive", false)):
			message.emit("%s agrandi : niveau %d, %s." % [_nom(bid), int(b.niv), texte_capacites(bid)])
	else:
		var mi := buildings.node_of(bid)
		if mi != null:
			BatimentsVie.apply_wear(mi, 0, 0)
		message.emit("%s rénové : façade et toit refaits à neuf." % _nom(bid))
		buildings.perso_changed.emit(bid)
	var fini_mi := buildings.node_of(bid)
	if fini_mi != null and fini_mi.is_inside_tree():
		Son.jouer_a("chantier_fini", fini_mi.global_position, -4.0, 300.0)
	changed.emit()


## Nouveau niveau : modèle redessiné, capacités prises en compte par les habitants.
func _appliquer_niveau(bid: int) -> void:
	buildings.rafraichir_modele(bid)
	if vie != null and vie._etat.has(bid):
		# Fumée et abords repris à la nouvelle hauteur.
		var e: Dictionary = vie._etat[bid]
		for f in e.get("fumee", []):
			if is_instance_valid(f):
				(f as Node).queue_free()
		e.fumee = []
		e.usure = -1
		if e.get("abords") != null and is_instance_valid(e.abords):
			(e.abords as Node).queue_free()
		e.abords = null
	if population != null and population.known.has(bid):
		var info: Dictionary = population.known[bid]
		var neuf := population._info_of(buildings.buildings[bid])
		for k in ["log", "emp", "seats"]:
			info[k] = neuf[k]
		population.emplois_version += 1
	if zones != null:
		zones._demand_cache = {}
	buildings.perso_changed.emit(bid)
	buildings.changed.emit()


# --- Échafaudages, grue et panneau -------------------------------------------------------

func _on_added(bid: int) -> void:
	if buildings.buildings.has(bid) and buildings.buildings[bid].has("amel"):
		_vus.erase(bid)
		_montrer.call_deferred(bid)


func _on_removed(bid: int) -> void:
	_vus.erase(bid)


func _oublier(bid: int) -> void:
	var v: Dictionary = _vus.get(bid, {})
	for key in ["echaf", "grue"]:
		if v.get(key) != null and is_instance_valid(v[key]):
			(v[key] as Node).queue_free()
	_vus.erase(bid)


func _montrer(bid: int) -> void:
	if not buildings.buildings.has(bid) or _vus.has(bid):
		return
	var b: Dictionary = buildings.buildings[bid]
	var a: Dictionary = b.get("amel", {})
	var mi := buildings.node_of(bid)
	if a.is_empty() or mi == null:
		return
	var bb := BatimentsVie.body_bounds(mi.mesh as ArrayMesh)
	# Agrandissement : les échafaudages montent jusqu'aux futurs étages.
	if String(a.op) == "niv":
		var futur := b.duplicate()
		futur["niv"] = int(a.cible)
		var m := buildings.mesh_du_niveau(futur)
		if m != null:
			bb = bb.merge(BatimentsVie.body_bounds(m))
	var echaf := MeshInstance3D.new()
	echaf.name = "EchafaudageTravaux"
	echaf.mesh = BatimentsVie._scaffold_mesh(bb)
	echaf.material_override = NightWindows.chantier_material()
	echaf.visibility_range_end = 1400.0
	mi.add_child(echaf)
	var grue: Node3D = null
	if bb.end.y > 12.0 and String(a.op) == "niv":
		grue = BatimentsVie._grue(bb)
		grue.name = "GrueTravaux"
		mi.add_child(grue)
	_vus[bid] = {"echaf": echaf, "grue": grue, "texte": "", "mi": mi, "bb": bb}
	_maj_panneau(bid)


func _maj_panneau(bid: int) -> void:
	var v: Dictionary = _vus.get(bid, {})
	if v.is_empty():
		return
	v.texte = texte_travaux(bid)


## Le détail des travaux en quelques lignes (info-bulle du marqueur).
func texte_travaux(bid: int) -> String:
	if not buildings.buildings.has(bid):
		return ""
	var a: Dictionary = buildings.buildings[bid].get("amel", {})
	if a.is_empty():
		return ""
	var quoi := "Agrandissement · niveau %d" % int(a.get("cible", 2)) if String(a.get("op", "")) == "niv" else "Rénovation"
	var txt := "%s\n%s · %d %%\n" % [_nom(bid), quoi, floori(float(a.get("av", 0.0)) * 100.0)]
	if a.get("attente", false):
		txt += "Arrêté : plus d'argent dans la caisse"
	else:
		txt += ("Équipe au repos · " if vie != null and not vie.au_travail else "") + "Fin vers le %s" % _date_fin(bid)
	return txt


## Travaux montrés en ce moment (bid), pour les marqueurs.
func travaux_en_cours() -> Array:
	return _vus.keys()


## Pour le marqueur : [genre ("niv" ou "renov"), avancement, statut ("argent", "repos" ou "")].
func etat_travaux(bid: int) -> Array:
	var a: Dictionary = buildings.buildings.get(bid, {}).get("amel", {})
	if a.is_empty():
		return []
	var st := "argent" if a.get("attente", false) else ("repos" if vie != null and not vie.au_travail else "")
	return ["niv" if String(a.get("op", "")) == "niv" else "renov", clampf(float(a.get("av", 0.0)), 0.0, 1.0), st]


## Point au-dessus des travaux où poser le marqueur (coordonnées du monde).
func haut_des_travaux(bid: int) -> Vector3:
	var v: Dictionary = _vus.get(bid, {})
	if v.is_empty() or not is_instance_valid(v.get("mi")) or not (v.mi as Node3D).is_inside_tree():
		return Vector3.INF
	var bb: AABB = v.bb
	return (v.mi as Node3D).global_transform * Vector3(bb.get_center().x, 0.0, bb.get_center().z) + Vector3(0, bb.end.y + 3.0, 0)


func _animer() -> void:
	var au_travail := vie != null and vie.au_travail
	for bid in _vus:
		var v: Dictionary = _vus[bid]
		if v.grue != null and is_instance_valid(v.grue) and au_travail:
			var f := (v.grue as Node3D).get_node_or_null("Fleche") as Node3D
			if f != null:
				f.rotation.y = sin(_clock * 0.15 + float(bid)) * 1.3


## Date de fin prévue des travaux en cours.
func fin_prevue(bid: int) -> float:
	var a := en_cours(bid)
	if a.is_empty():
		return now()
	var reste := (1.0 - float(a.av)) * float(a.hr) / Chantiers.rythme(population)
	return Chantiers.date_apres(now(), reste, vie.offset_h() if vie != null else 0.0)


func _date_fin(bid: int) -> String:
	return Chantiers.date_texte(fin_prevue(bid), vie.offset_h() if vie != null else 0.0)


func _nom(bid: int) -> String:
	if population != null and population.known.has(bid):
		return population.building_name(bid)
	var b: Dictionary = buildings.buildings.get(bid, {})
	return String(BuildingCatalog.get_type(String(b.get("t", ""))).get("name", "Bâtiment"))


# --- Textes pour la fiche du bâtiment ----------------------------------------------------

## Capacités actuelles d'un bâtiment, en clair (« 450 élèves, 30 emplois »).
func texte_capacites(bid: int, niv := -1) -> String:
	var b: Dictionary = buildings.buildings.get(bid, {})
	if b.is_empty():
		return ""
	var e := b.duplicate()
	if niv > 0:
		e["niv"] = niv
	var t := BuildingCatalog.get_type(String(b.t))
	var parts := []
	if int(t.get("logements", 0)) > 0:
		parts.append("%d logements" % cap(e, "logements"))
	if Metiers.keys_of(String(b.t)).has("ecole"):
		parts.append("%d élèves" % roundi(int(t.get("visiteurs", Population.DEFAULT_SCHOOL_SEATS)) * facteur(e)))
	elif int(t.get("visiteurs", 0)) > 0:
		parts.append("%d visiteurs" % cap(e, "visiteurs"))
	if int(t.get("emplois", 0)) > 0:
		parts.append("%d emplois" % cap(e, "emplois"))
	var r := ReseauxTypes.info(String(b.t))
	if float(r.get("cap", 0.0)) > 0.0:
		var unite := String(ReseauxTypes.UNITES.get(String(r.get("res", "")), ""))
		parts.append("%s %s" % [_fmt(float(r.cap) * facteur(e)), unite])
	return ", ".join(parts)


static func _fmt(v: float) -> String:
	return str(roundi(v)) if absf(v - roundf(v)) < 0.05 or v >= 100.0 else "%.1f" % v


# --- Densification du zonage --------------------------------------------------------------

## Un passage : quelques bâtiments du zonage, chacun à son tour. Renvoie le
## nombre d'agrandissements lancés.
func densifier(n_max := 40) -> int:
	if zones == null or population == null:
		return 0
	var ids := buildings.buildings.keys()
	if ids.is_empty():
		return 0
	var d := zones.demand()
	var lances := 0
	for i in mini(n_max, ids.size()):
		_tour = (_tour + 1) % ids.size()
		var bid := int(ids[_tour])
		if _densifiable(bid, d):
			var b: Dictionary = buildings.buildings[bid]
			var cible := niveau(b) + 1
			_lancer(bid, "niv", cible, cout(bid, cible), true)
			lances += 1
			var t := now()
			if t - _dernier_msg_densif > 86400.0 * 3.0:
				_dernier_msg_densif = t
				message.emit("Le quartier prend de la valeur : %s s'agrandit (niveau %d), aux frais de ses propriétaires." % [_nom(bid), cible])
			break
	return lances


## Raison pour laquelle un bâtiment du zonage ne s'agrandit pas ("" : il le peut).
func raison_densif(bid: int, d: Dictionary = {}) -> String:
	if not buildings.buildings.has(bid):
		return "introuvable"
	var b: Dictionary = buildings.buildings[bid]
	var zid := int(b.get("zone", 0))
	if zid <= 0 or not zones.zones.has(zid):
		return "hors zone"
	if niveau(b) >= NIVEAU_MAX:
		return "au maximum"
	if Patrimoine.instance != null and Patrimoine.instance.niveau(bid) > 0:
		return "protégé"
	if not ameliorable(String(b.t)) or buildings.en_chantier(bid) or b.has("amel"):
		return "en travaux"
	var t := now()
	var depuis := maxf(float(b.get("fin", 0.0)), float(b.get("renov", 0.0)))
	if t - depuis < DELAI_DENSIF_J * 86400.0:
		return "trop récent"
	if d.is_empty():
		d = zones.demand()
	var k := String(zones.zones[zid].k)
	if float(d.get(k, 0.0)) <= 0.0:
		return "pas de demande"
	var info: Dictionary = population.known.get(bid, {})
	if info.is_empty():
		return "inconnu"
	if int(info.log) > 0 and (population.by_home.get(bid, []) as Array).size() < int(info.log):
		return "logements libres"
	if int(info.emp) > 0 and (population.by_job.get(bid, []) as Array).size() < ceili(int(info.emp) * 0.9):
		return "emplois libres"
	var valeur := 1.0
	if nuisances != null and nuisances.has_method("coef_foncier"):
		valeur = float(nuisances.coef_foncier(bid))
	if valeur < float(VALEUR_DENSIF[niveau(b) + 1]):
		return "terrain pas assez cher"
	return ""


func _densifiable(bid: int, d: Dictionary) -> bool:
	return raison_densif(bid, d) == ""


# --- Sauvegarde ----------------------------------------------------------------------------
## Les niveaux et les travaux sont rangés dans les bâtiments (section « batiments ») ;
## cette section garde le réglage de la densification.

func to_dict() -> Dictionary:
	return {"version": 1, "densification": densification}


func from_dict(d: Dictionary) -> void:
	densification = bool(d.get("densification", true))
	_t_prev = now()
	for bid in _vus.keys():
		_oublier(bid)
	for bid in buildings.buildings:
		if buildings.buildings[bid].has("amel"):
			_montrer(bid)
