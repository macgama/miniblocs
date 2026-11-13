class_name Quartiers
extends Node3D
## Quartiers nommés de la ville et arrêtés municipaux (panneau Quartiers, Maj+Y).
##
## Le joueur peint ses quartiers au pinceau, en îlots de 50 × 50 m, sur le
## territoire de ses villes, leur donne un nom, puis y prend des arrêtés
## (Arretes.LISTE : zone 30, rues piétonnes, poids lourds interdits, calme la
## nuit, tri obligatoire, détecteurs de fumée, éclairage, stationnement payant,
## fleurissement). Chaque arrêté coûte une mise en place et un montant par mois,
## payés par la caisse de la ville du quartier.
##
## Effets sur les autres systèmes (crochets peu coûteux, rien si aucun arrêté) :
##   - Trafic : coût des tronçons pour les trajets (facteur_cout_voie), poids
##     lourds (facteur_lourds), places payantes le long des rues (tarif_trottoir) ;
##   - Traffic : vitesse des voitures visibles (speed_factors) ;
##   - Nuisances : bruit, air, verdure et attrait des îlots (moduler) ;
##   - Déchets : part triée (bonus_tri) ; Incendies : départs de feu (facteur_feu) ;
##   - Avis : facteurs par thème pour les habitants du quartier (groupe avis_sources) ;
##   - Budget : coûts et économies de chaque ville (groupe budget_ville).
##
## Mairie perdue (réglage « mairie perdue ») : le joueur ne peut plus peindre ni
## changer les arrêtés de cette ville. Le conseil élu les gère selon son
## programme (gerer_conseil, appelé chaque semaine par GestionAuto). Le pilote
## automatique, lui, ajoute les arrêtés utiles et retire les plus chers quand la
## caisse est dans le rouge (piloter, appelé par PiloteAuto).

signal changed
signal message(text: String)

## Côté d'un îlot (m) et sa surface (ha).
const CASE := 50
const HA_CASE := 0.25
const PINCEAUX := [0, 1, 2, 4]
const COULEURS := [Color("f28482"), Color("84a59d"), Color("f6bd60"), Color("7b9acc"), Color("b5838d"),
	Color("80ed99"), Color("e09f3e"), Color("9d8189"), Color("48cae4"), Color("ffafcc")]
const NOMS_AUTO := ["Centre", "Les Tilleuls", "La Gare", "Le Moulin", "Bellevue", "Les Prés", "Le Faubourg",
	"Les Vignes", "Le Port", "La Fontaine", "Les Hauts", "Saint-Roch", "Le Marché", "Les Acacias", "La Croisée"]
## Le conseil élu garde au moins cette réserve après une mise en place.
const RESERVE_CONSEIL := 200_000
## Voies où s'applique la zone 30 (pas les voies rapides).
const ZONE_30_CLASSES := ["rue", "avenue", "departementale", "giratoire"]
## Bruit la nuit (0..1) au-delà duquel le pilote automatique demande le calme.
const SEUIL_NUIT_PILOTE := 0.3

static var instance: Quartiers

var world: TerrainWorld
var buildings: BuildingSystem
var transport: TransportSystem
var population: Population
var communes: Communes
var dechets: Node
var camera: Camera3D

## qid -> {id, nom, couleur, vid, arretes: {aid: jour de l'arrêté}}
var quartiers := {}
## Îlot (Vector2i) -> qid
var cases := {}
var next_id := 1
## Outil en cours : "" ; "peindre" (quartier outil_q) ; "gommer".
var outil := ""
var outil_q := -1
## Rayon du pinceau (en îlots autour de celui visé).
var rayon := 1
var montre := false
var calque := false
## Quartier choisi dans le panneau.
var selection := -1
## Dernières décisions : [{jour, vid, texte}].
var journal: Array = []
## Chiffres par quartier : qid -> {hab, logements, emplois, ha, nuit, satisfaction}
var stats := {}

## Nombre de quartiers ayant chaque arrêté (aid -> n) : crochets rapides.
var _actifs := {}
var _edge_q := {}
var _edge_sale := true
var _sale := true
var _t_stats := 0.0
var _peint := false
var _survol_k := Vector2i(1 << 30, 0)
var _mat: StandardMaterial3D
var _fill: MeshInstance3D
var _bord: MeshInstance3D
var _survol: MeshInstance3D
var _etiquettes := {}
var _nuis_sale := false


func _enter_tree() -> void:
	instance = self
	add_to_group("avis_sources")
	add_to_group("budget_ville")


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _ready() -> void:
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.vertex_color_use_as_albedo = true
	_mat.render_priority = 3
	_mat.disable_fog = true
	for n in ["Remplissage", "Bordure", "Survol"]:
		var mi := MeshInstance3D.new()
		mi.name = n
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.material_override = _mat
		mi.visible = false
		add_child(mi)
	_fill = $Remplissage
	_bord = $Bordure
	_survol = $Survol


func setup(w: TerrainWorld, b: BuildingSystem, t: TransportSystem, p: Population, cm: Communes) -> void:
	world = w
	buildings = b
	transport = t
	population = p
	communes = cm
	camera = b.camera if b != null else null
	if transport != null and transport.network != null:
		transport.network.changed.connect(func() -> void: _edge_sale = true)
		if transport.traffic != null and "speed_factors" in transport.traffic:
			transport.traffic.speed_factors.append(vitesse)
	if communes != null:
		communes.changed.connect(_maj_villes)


func clear() -> void:
	quartiers.clear()
	cases.clear()
	journal.clear()
	stats.clear()
	_actifs.clear()
	next_id = 1
	selection = -1
	set_outil("")
	_edge_sale = true
	_sale = true
	_nuis_sale = true
	changed.emit()


# --- Questions ----------------------------------------------------------------------

static func case_de(x: float, z: float) -> Vector2i:
	return Vector2i(floori(x / CASE), floori(z / CASE))


static func centre_case(k: Vector2i) -> Vector2:
	return Vector2((k.x + 0.5) * CASE, (k.y + 0.5) * CASE)


func quartier_au_point(x: float, z: float) -> int:
	return int(cases.get(case_de(x, z), -1))


func a_arrete(qid: int, aid: String) -> bool:
	return quartiers.has(qid) and (quartiers[qid].arretes as Dictionary).has(aid)


## Un quartier au moins a-t-il cet arrêté ?
func en_vigueur(aid: String) -> bool:
	return int(_actifs.get(aid, 0)) > 0


func arrete_au_point(x: float, z: float, aid: String) -> bool:
	if int(_actifs.get(aid, 0)) <= 0:
		return false
	var q := int(cases.get(case_de(x, z), -1))
	return q >= 0 and a_arrete(q, aid)


## Raccourci sans dépendance : un arrêté au point (x, z) ?
static func au(x: float, z: float, aid: String) -> bool:
	return instance != null and instance.arrete_au_point(x, z, aid)


func ha(qid: int) -> float:
	var n := 0
	for k in cases:
		if int(cases[k]) == qid:
			n += 1
	return n * HA_CASE


func cases_de(qid: int) -> Array:
	var out := []
	for k in cases:
		if int(cases[k]) == qid:
			out.append(k)
	return out


## Ville du quartier (0 : hors des villes, ou partie sans villages).
func ville_de(qid: int) -> int:
	return int(quartiers.get(qid, {}).get("vid", 0))


func nom_ville(vid: int) -> String:
	if communes != null and communes.villages.has(vid):
		return String(communes.villages[vid].nom)
	return Avis.ville()


## Le joueur décide-t-il des arrêtés de cette ville (il en est le maire) ?
func decide(vid: int) -> bool:
	if vid <= 0 or Pays.instance == null:
		return true
	return Pays.instance.joueur_maire(vid)


func maire_txt(vid: int) -> String:
	if Avis.instance == null:
		return "le conseil municipal"
	var m := Avis.instance.maire_de(vid)
	return "la liste « %s »" % String(m.get("nom", "du conseil"))


## Quartiers d'une ville (-1 : tous), triés par nom.
func quartiers_de(vid: int) -> Array:
	var out := []
	for qid in quartiers:
		if vid < 0 or ville_de(qid) == vid:
			out.append(qid)
	out.sort_custom(func(a: int, b: int) -> bool: return String(quartiers[a].nom) < String(quartiers[b].nom))
	return out


func _ville_au(k: Vector2i) -> int:
	if communes == null or communes.villages.is_empty():
		return 0
	var c := centre_case(k)
	var v := communes.village_au_point(c.x, c.y)
	return v if v >= 0 else -1


## Pourquoi on ne peut pas peindre l'îlot k pour le quartier qid ("" : permis).
func raison_peindre(qid: int, k: Vector2i) -> String:
	if not quartiers.has(qid):
		return "Choisis d'abord un quartier."
	var vid := ville_de(qid)
	var v := _ville_au(k)
	if v < 0:
		return "Cet îlot est hors du territoire de tes villes."
	if communes != null and not communes.villages.is_empty() and vid > 0 and v != vid:
		return "Cet îlot appartient à %s : un quartier reste dans sa ville." % nom_ville(v)
	if not decide(vid):
		return "Tu n'es plus maire de %s : c'est %s qui trace ses quartiers." % [nom_ville(vid), maire_txt(vid)]
	var autre := int(cases.get(k, -1))
	if autre >= 0 and autre != qid and not decide(ville_de(autre)):
		return "Cet îlot est dans un quartier d'une ville dont tu n'es plus maire."
	return ""


func raison_gommer(k: Vector2i) -> String:
	var q := int(cases.get(k, -1))
	if q < 0:
		return "Aucun quartier ici."
	if not decide(ville_de(q)):
		return "Tu n'es plus maire de %s." % nom_ville(ville_de(q))
	return ""


# --- Quartiers : créer, peindre, renommer, supprimer --------------------------------

func nom_auto() -> String:
	var pris := {}
	for qid in quartiers:
		pris[String(quartiers[qid].nom)] = true
	for n in NOMS_AUTO:
		if not pris.has(n):
			return n
	return "Quartier %d" % next_id


## Nouveau quartier (sans îlot) dans la ville vid. Renvoie son id (-1 : refusé).
func creer(nom := "", vid := -1) -> int:
	if vid < 0:
		vid = _ville_choisie()
	if not decide(vid):
		message.emit("Tu n'es plus maire de %s : tu ne peux pas y créer de quartier." % nom_ville(vid))
		return -1
	var qid := next_id
	next_id += 1
	nom = nom.strip_edges()
	quartiers[qid] = {"id": qid, "nom": nom if nom != "" else nom_auto(), "couleur": (qid - 1) % COULEURS.size(),
		"vid": vid, "arretes": {}, "cree": _jour()}
	selection = qid
	_sale = true
	changed.emit()
	return qid


func _ville_choisie() -> int:
	if Pays.instance != null and Pays.instance.a_des_villes():
		return maxi(0, Pays.instance.selection)
	if communes != null and not communes.villages.is_empty():
		return maxi(0, communes.principal())
	return 0


func renommer(qid: int, nom: String) -> String:
	nom = nom.strip_edges()
	if not quartiers.has(qid) or nom == "":
		return "Nom vide."
	if not decide(ville_de(qid)):
		return "Tu n'es plus maire de %s." % nom_ville(ville_de(qid))
	quartiers[qid].nom = nom
	_sale = true
	changed.emit()
	return ""


func supprimer(qid: int) -> String:
	if not quartiers.has(qid):
		return "Quartier inconnu."
	if not decide(ville_de(qid)):
		return "Tu n'es plus maire de %s : ses quartiers restent." % nom_ville(ville_de(qid))
	for k in cases_de(qid):
		cases.erase(k)
	quartiers.erase(qid)
	if selection == qid:
		selection = -1
	if outil_q == qid:
		set_outil("")
	_apres_changement()
	return ""


## Peint les îlots autour de k (rayon r) pour le quartier qid. Renvoie le nombre peint.
func peindre(qid: int, k: Vector2i, r := 0) -> int:
	var n := 0
	var first_msg := ""
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dz * dz > r * r + r:
				continue
			var kk := k + Vector2i(dx, dz)
			if int(cases.get(kk, -1)) == qid:
				continue
			var why := raison_peindre(qid, kk)
			if why != "":
				if first_msg == "":
					first_msg = why
				continue
			# Un quartier sans ville en prend une au premier îlot.
			if ville_de(qid) == 0 and communes != null and not communes.villages.is_empty():
				quartiers[qid].vid = _ville_au(kk)
			cases[kk] = qid
			n += 1
	if n > 0:
		_apres_changement()
	elif first_msg != "":
		message.emit(first_msg)
	return n


func gommer(k: Vector2i, r := 0) -> int:
	var n := 0
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dz * dz > r * r + r:
				continue
			var kk := k + Vector2i(dx, dz)
			if raison_gommer(kk) == "":
				cases.erase(kk)
				n += 1
	if n > 0:
		_apres_changement()
	return n


## Peint un rectangle de terrain (en mètres) pour qid : pratique pour les tests et le pilote.
func peindre_rect(qid: int, rect: Rect2i) -> int:
	var a := case_de(rect.position.x, rect.position.y)
	var b := case_de(rect.end.x - 1, rect.end.y - 1)
	var n := 0
	for z in range(a.y, b.y + 1):
		for x in range(a.x, b.x + 1):
			n += peindre(qid, Vector2i(x, z), 0)
	return n


func _apres_changement() -> void:
	_edge_sale = true
	_sale = true
	_nuis_sale = true
	_recompter()
	calculer_stats()
	changed.emit()


func _recompter() -> void:
	_actifs.clear()
	for qid in quartiers:
		for aid in quartiers[qid].arretes:
			_actifs[aid] = int(_actifs.get(aid, 0)) + 1


## Les villages ont changé (fusion, territoire) : chaque quartier suit la ville
## de la plupart de ses îlots.
func _maj_villes() -> void:
	if communes == null or communes.villages.is_empty():
		return
	var compte := {}
	for k in cases:
		var q := int(cases[k])
		var v := _ville_au(k)
		if v < 0:
			continue
		if not compte.has(q):
			compte[q] = {}
		compte[q][v] = int(compte[q].get(v, 0)) + 1
	for q in compte:
		var best := -1
		var n := -1
		for v in compte[q]:
			if int(compte[q][v]) > n:
				n = int(compte[q][v])
				best = int(v)
		if best >= 0 and quartiers.has(q) and int(quartiers[q].vid) != best:
			quartiers[q].vid = best


# --- Arrêtés ------------------------------------------------------------------------

## Pourquoi on ne peut pas prendre cet arrêté ("" : permis). ia : décidé par le conseil ou le pilote.
func raison_adopter(qid: int, aid: String, ia := false) -> String:
	if not quartiers.has(qid):
		return "Quartier inconnu."
	var a := Arretes.get_arrete(aid)
	if a.is_empty():
		return "Arrêté inconnu."
	if a_arrete(qid, aid):
		return "Déjà en vigueur."
	var vid := ville_de(qid)
	if not ia and not decide(vid):
		return "Tu n'es plus maire de %s : %s décide de ses arrêtés." % [nom_ville(vid), maire_txt(vid)]
	var h := ha(qid)
	if h <= 0.0:
		return "Peins d'abord le quartier sur la carte."
	var ex := Arretes.exclut(aid)
	if ex != "" and a_arrete(qid, ex):
		return "Incompatible avec « %s » : abroge-le d'abord." % Arretes.nom(ex)
	var cout := Arretes.cout_pose(aid, h)
	if buildings != null and not buildings.unlimited_money and solde_ville(vid) < cout:
		return "Pas assez d'argent dans la caisse de %s (%s)." % [nom_ville(vid), BuildingSystem.format_money(cout)]
	return ""


func adopter(qid: int, aid: String, ia := false) -> String:
	var why := raison_adopter(qid, aid, ia)
	if why != "":
		return why
	var vid := ville_de(qid)
	var cout := Arretes.cout_pose(aid, ha(qid))
	_payer(vid, cout, "Arrêtés : mise en place")
	quartiers[qid].arretes[aid] = _jour()
	_noter(vid, "« %s » en vigueur à %s (%s)." % [Arretes.nom(aid), String(quartiers[qid].nom), BuildingSystem.format_money(cout)])
	_apres_changement()
	return ""


func raison_abroger(qid: int, aid: String, ia := false) -> String:
	if not a_arrete(qid, aid):
		return "Cet arrêté n'est pas en vigueur ici."
	var vid := ville_de(qid)
	if not ia and not decide(vid):
		return "Tu n'es plus maire de %s : %s décide de ses arrêtés." % [nom_ville(vid), maire_txt(vid)]
	return ""


func abroger(qid: int, aid: String, ia := false) -> String:
	var why := raison_abroger(qid, aid, ia)
	if why != "":
		return why
	(quartiers[qid].arretes as Dictionary).erase(aid)
	_noter(ville_de(qid), "« %s » abrogé à %s." % [Arretes.nom(aid), String(quartiers[qid].nom)])
	_apres_changement()
	return ""


## Coût par mois des arrêtés d'un quartier (négatif : économie).
func cout_mois(qid: int) -> float:
	var h := ha(qid)
	var c := 0.0
	for aid in quartiers.get(qid, {}).get("arretes", {}):
		c += Arretes.cout_mois(aid, h)
	return c


func solde_ville(vid: int) -> int:
	if buildings == null:
		return 0
	if vid > 0 and Pays.instance != null and Pays.instance.a_des_villes():
		return Pays.instance.solde(vid)
	return buildings.money


func _payer(vid: int, montant: int, poste: String) -> void:
	if buildings == null or buildings.unlimited_money or montant == 0:
		return
	var multi := vid > 0 and Pays.instance != null and Pays.instance.a_des_villes()
	var prev := Pays.a_la_caisse(vid) if multi else -1
	buildings.money -= montant
	Pays.retour(prev)
	if BudgetCommunal.instance != null:
		if multi:
			BudgetCommunal.instance.noter_pour(vid, poste, -montant)
		else:
			BudgetCommunal.noter(poste, -montant)


func _jour() -> int:
	return int(population.now().day) if population != null else 0


func _noter(vid: int, t: String) -> void:
	journal.append({"jour": _jour(), "vid": vid, "texte": t})
	while journal.size() > 30:
		journal.pop_front()


## Comptes de la ville k pour le budget (groupe "budget_ville") :
## k = -1 : toutes les villes (partie sans pays) ; 0 : le pays ; sinon une ville.
func budget_ville(k: int) -> Dictionary:
	var dep := {}
	var rec := {}
	for qid in quartiers:
		var vid := ville_de(qid)
		if k >= 0 and vid != k and not (k == 0 and vid < 0):
			continue
		var h := ha(qid)
		for aid in quartiers[qid].arretes:
			var c := Arretes.cout_mois(aid, h)
			if c > 0.0:
				dep["Arrêtés municipaux"] = float(dep.get("Arrêtés municipaux", 0.0)) + c
			elif c < 0.0:
				rec["Économies d'éclairage"] = float(rec.get("Économies d'éclairage", 0.0)) - c
	return {"recettes": rec, "depenses": dep}


# --- Effets sur les autres systèmes --------------------------------------------------

## Quartier de chaque voie (par son milieu), recalculé quand le réseau ou les quartiers changent.
func quartier_de_voie(eid: int) -> int:
	if _edge_sale:
		_edge_sale = false
		_edge_q.clear()
		if transport != null and transport.network != null and not cases.is_empty():
			var net := transport.network
			# Le quartier où passe la plus grande part de la voie (au moins un tiers).
			for e in net.edges:
				var pts: PackedVector3Array = net.edges[e].pts
				if pts.is_empty():
					continue
				var n := {}
				var pas := maxi(1, pts.size() / 24)
				var tot := 0
				for i in range(0, pts.size(), pas):
					tot += 1
					var q := int(cases.get(case_de(pts[i].x, pts[i].z), -1))
					if q >= 0:
						n[q] = int(n.get(q, 0)) + 1
				var best := -1
				for q in n:
					if best < 0 or int(n[q]) > int(n[best]):
						best = q
				if best >= 0 and int(n[best]) * 3 >= tot:
					_edge_q[e] = best
	return int(_edge_q.get(eid, -1))


func _voie_a(eid: int, aid: String) -> bool:
	if int(_actifs.get(aid, 0)) <= 0:
		return false
	var q := quartier_de_voie(eid)
	return q >= 0 and a_arrete(q, aid)


func _classe(eid: int) -> String:
	if transport == null or not transport.network.edges.has(eid):
		return ""
	return String(transport.network.edges[eid].t)


## Facteur de temps d'un tronçon pour les trajets en voiture (Trafic) : zone 30,
## rues piétonnes (les riverains passent, le transit fait le tour).
func facteur_cout_voie(eid: int) -> float:
	if _actifs.is_empty():
		return 1.0
	var cls := _classe(eid)
	var f := 1.0
	if cls == "rue" and _voie_a(eid, "rue_pietonne"):
		return Arretes.DETOUR_PIETONNE
	if cls in ZONE_30_CLASSES and _voie_a(eid, "zone_30"):
		f = maxf(1.0, TransportTypes.speed_of(cls) * 3.6 / Arretes.KMH_ZONE_30)
	return f


## Vitesse des voitures visibles (Traffic.speed_factors) : 30 km/h, au pas dans
## une rue piétonne. Les secours roulent comme d'habitude.
func vitesse(eid: int, v: Dictionary) -> float:
	if _actifs.is_empty() or v.has("urgence") or bool(v.get("siren", false)):
		return 1.0
	var cls := _classe(eid)
	if cls == "rue" and _voie_a(eid, "rue_pietonne"):
		return clampf(Arretes.KMH_PIETONNE / maxf(1.0, TransportTypes.speed_of(cls) * 3.6), 0.1, 1.0)
	if cls in ZONE_30_CLASSES and _voie_a(eid, "zone_30"):
		return clampf(Arretes.KMH_ZONE_30 / maxf(1.0, TransportTypes.speed_of(cls) * 3.6), 0.1, 1.0)
	return 1.0


## Part des poids lourds qui restent sur le tronçon (Trafic.flux_lourds).
func facteur_lourds(eid: int) -> float:
	if _voie_a(eid, "poids_lourds") or _voie_a(eid, "rue_pietonne"):
		return Arretes.LOURDS_RESTANTS
	return 1.0


## Tarif des places le long de la rue au point p (Trafic) : 0 si gratuites.
func tarif_trottoir(p: Vector3) -> float:
	return Arretes.TARIF_STATIONNEMENT if arrete_au_point(p.x, p.z, "stationnement_payant") else 0.0


## Départs de feu (Incendies) au point p.
func facteur_feu(p: Vector3) -> float:
	return Arretes.FEU_DETECTEURS if arrete_au_point(p.x, p.z, "detecteurs_fumee") else 1.0


## Part triée chez un bâtiment au point p (Déchets), à partir de celle sans arrêté.
func bonus_tri(p: Vector3, r: float) -> float:
	if r <= 0.0 or not arrete_au_point(p.x, p.z, "tri_obligatoire"):
		return r
	return minf(Arretes.TRI_MAX, r + Arretes.TRI_EN_PLUS)


## Couches de nuisances d'une case (Nuisances) : bruit, air, verdure, attrait.
func moduler(f: Dictionary, x: float, z: float) -> Dictionary:
	if _actifs.is_empty():
		return f
	var q := int(cases.get(case_de(x, z), -1))
	if q < 0:
		return f
	var ar: Dictionary = quartiers[q].arretes
	if ar.is_empty():
		return f
	var g := f.duplicate()
	if ar.has("zone_30"):
		g.bruit = float(g.bruit) * 0.85
		g.nuit = float(g.nuit) * 0.85
	if ar.has("rue_pietonne"):
		g.bruit = float(g.bruit) * 0.6
		g.nuit = float(g.nuit) * 0.6
		g.air = float(g.air) * 0.7
		g.commo = minf(1.0, float(g.commo) + 0.12)
		g.prestige = minf(1.0, float(g.prestige) + 0.1)
	if ar.has("calme_nuit"):
		g.nuit = float(g.nuit) * 0.6
	if ar.has("espaces_verts"):
		g.vert = minf(1.0, float(g.vert) + 0.25)
		g.air = float(g.air) * 0.92
		g.bruit = float(g.bruit) * 0.95
		g.prestige = minf(1.0, float(g.prestige) + 0.1)
	return g


# --- Avis des habitants ----------------------------------------------------------------

func avis_facteurs() -> Array:
	var out := []
	for th in ["securite", "environnement", "loisirs", "commerces", "transports"]:
		var t: String = th
		out.append({"id": "arretes_" + t, "theme": t, "f": func(p: Dictionary) -> Array: return avis_theme(p, t)})
	return out


## Effet des arrêtés du quartier d'un habitant sur un thème : [delta, raisons].
func avis_theme(p: Dictionary, theme: String) -> Array:
	if _actifs.is_empty() or population == null:
		return [0.0, []]
	var home := population.home_of(p)
	if home < 0 or not population.known.has(home):
		return [0.0, []]
	var pos: Vector3 = population.known[home].pos
	var q := quartier_au_point(pos.x, pos.z)
	if q < 0:
		return [0.0, []]
	var ar: Dictionary = quartiers[q].arretes
	if ar.is_empty():
		return [0.0, []]
	var d := 0.0
	var why := []
	var voiture := int(population.households.get(int(p.get("f", -1)), {}).get("car", 0)) > 0
	var age := population.age_years(p)
	for aid in ar:
		var a := Arretes.get_arrete(aid)
		var v := float((a.get("avis", {}) as Dictionary).get(theme, 0.0))
		# Les contraintes sur la voiture ne gênent que ceux qui en ont une.
		if theme == "transports" and v < 0.0 and not voiture:
			v = 0.0
		if aid == "calme_nuit" and theme == "loisirs" and age >= 18 and age <= 30:
			v -= 2.0
		if v == 0.0:
			continue
		d += v
		why.append("%s %s (%s)" % ["+" if v > 0.0 else "−", String(a.nom).to_lower() if aid != "zone_30" else "zone 30", String(quartiers[q].nom)])
	return [clampf(d, -8.0, 8.0), why]


# --- Conseil élu et pilote automatique ---------------------------------------------------

## La semaine du conseil élu d'une ville (mairie perdue) : il abroge un arrêté que
## son programme combat, sinon en prend un qu'il défend, dans le quartier le plus
## peuplé qui ne l'a pas. Un changement par semaine au plus.
func gerer_conseil(vid: int, tendance: String) -> String:
	var qs := quartiers_de(vid)
	if qs.is_empty() or tendance == "":
		return ""
	for qid in qs:
		for aid in (quartiers[qid].arretes as Dictionary).keys():
			if Arretes.avis_programme(aid, tendance) < 0 and abroger(qid, aid, true) == "":
				return _annonce(vid, "Le conseil de %s (%s) abroge « %s » à %s." % [nom_ville(vid), maire_txt(vid), Arretes.nom(aid), String(quartiers[qid].nom)])
	calculer_stats()
	qs.sort_custom(func(a: int, b: int) -> bool: return int(stats.get(a, {}).get("hab", 0)) > int(stats.get(b, {}).get("hab", 0)))
	for aid in Arretes.ids():
		if Arretes.avis_programme(aid, tendance) <= 0:
			continue
		for qid in qs:
			if a_arrete(qid, aid) or raison_adopter(qid, aid, true) != "":
				continue
			var reste := solde_ville(vid) - Arretes.cout_pose(aid, ha(qid)) - roundi(maxf(0.0, Arretes.cout_mois(aid, ha(qid))) * 12.0)
			if buildings != null and not buildings.unlimited_money and reste < RESERVE_CONSEIL:
				continue
			if adopter(qid, aid, true) == "":
				return _annonce(vid, "Le conseil de %s (%s) instaure « %s » à %s." % [nom_ville(vid), maire_txt(vid), Arretes.nom(aid), String(quartiers[qid].nom)])
	return ""


## Pilote automatique (le joueur est maire) : caisse dans le rouge, il abroge
## l'arrêté le plus cher ; sinon il ajoute ce qui sert : détecteurs de fumée
## là où l'on habite, calme la nuit là où c'est bruyant, tri obligatoire s'il y
## a un centre de tri.
func piloter(vid: int) -> String:
	var qs := quartiers_de(vid)
	if qs.is_empty() or not decide(vid):
		return ""
	if buildings != null and not buildings.unlimited_money and solde_ville(vid) < 0:
		var best_q := -1
		var best_a := ""
		var best_c := 0.0
		for qid in qs:
			for aid in quartiers[qid].arretes:
				var c := Arretes.cout_mois(aid, ha(qid))
				if c > best_c:
					best_c = c
					best_q = qid
					best_a = aid
		if best_q >= 0 and abroger(best_q, best_a, true) == "":
			return "Caisse dans le rouge : « %s » abrogé à %s (%s par mois en moins)." % [Arretes.nom(best_a), String(quartiers[best_q].nom), BuildingSystem.format_money(roundi(best_c))]
		return ""
	calculer_stats()
	var tri := dechets != null and dechets.has_method("sites_of") and not (dechets.sites_of("tri") as Array).is_empty()
	for qid in qs:
		var s: Dictionary = stats.get(qid, {})
		if int(s.get("hab", 0)) <= 0:
			continue
		var voulus := ["detecteurs_fumee"]
		if float(s.get("nuit", 0.0)) > SEUIL_NUIT_PILOTE:
			voulus.append("calme_nuit")
		if tri:
			voulus.append("tri_obligatoire")
		for aid in voulus:
			if a_arrete(qid, aid):
				continue
			var reste := solde_ville(vid) - Arretes.cout_pose(aid, ha(qid))
			if buildings != null and not buildings.unlimited_money and reste < RESERVE_CONSEIL:
				continue
			if adopter(qid, aid, true) == "":
				return "« %s » à %s." % [Arretes.nom(aid), String(quartiers[qid].nom)]
	return ""


func _annonce(vid: int, t: String) -> String:
	message.emit(t)
	if Avis.instance != null:
		Avis.instance.dire(t)
	return t


# --- Chiffres ------------------------------------------------------------------------------

func calculer_stats() -> void:
	var out := {}
	for qid in quartiers:
		out[qid] = {"hab": 0, "foyers": 0, "logements": 0, "emplois": 0, "ha": 0.0, "nuit": 0.0, "bruit": 0.0, "satisfaction": -1.0, "_n": 0, "_s": 0.0}
	for k in cases:
		var q := int(cases[k])
		if out.has(q):
			out[q].ha = float(out[q].ha) + HA_CASE
	if buildings != null:
		for bid in buildings.buildings:
			var c := BuildingSystem.rect_center(buildings._rect_of(buildings.buildings[bid]))
			var q := quartier_au_point(c.x, c.z)
			if q < 0 or not out.has(q):
				continue
			var t := BuildingCatalog.get_type(String(buildings.buildings[bid].t))
			out[q].logements += int(t.get("logements", 0))
			out[q].emplois += int(t.get("emplois", 0))
	if population != null:
		var nz: Nuisances = Nuisances.instance
		for hid in population.households:
			var h: Dictionary = population.households[hid]
			var b := int(h.b)
			if not population.known.has(b):
				continue
			var pos: Vector3 = population.known[b].pos
			var q := quartier_au_point(pos.x, pos.z)
			if q < 0 or not out.has(q):
				continue
			var n := (h.m as Array).size()
			out[q].foyers += 1
			out[q].hab += n
			if nz != null:
				out[q].nuit = float(out[q].nuit) + nz.bruit(pos, 1) * n
				out[q].bruit = float(out[q].bruit) + nz.bruit(pos, 0) * n
	for q in out:
		var s: Dictionary = out[q]
		if int(s.hab) > 0:
			s.nuit = float(s.nuit) / int(s.hab)
			s.bruit = float(s.bruit) / int(s.hab)
		s.erase("_n")
		s.erase("_s")
	stats = out


## Satisfaction moyenne des habitants d'un quartier (-1 : personne), échantillon de 60.
func satisfaction(qid: int) -> float:
	if population == null:
		return -1.0
	var tot := 0.0
	var n := 0
	for hid in population.households:
		var h: Dictionary = population.households[hid]
		var b := int(h.b)
		if not population.known.has(b):
			continue
		var pos: Vector3 = population.known[b].pos
		if quartier_au_point(pos.x, pos.z) != qid:
			continue
		for pid in h.m:
			var p: Dictionary = population.persons.get(pid, {})
			if p.is_empty():
				continue
			tot += float(population.satisfaction(p).get("value", 50))
			n += 1
			if n >= 60:
				return tot / n
	return tot / n if n > 0 else -1.0


# --- Mise à jour, pinceau et dessin ------------------------------------------------------

func _process(delta: float) -> void:
	if _nuis_sale:
		_nuis_sale = false
		if Nuisances.instance != null:
			Nuisances.instance._dirty = true
			Nuisances.instance._cache.clear()
	_t_stats -= delta
	if _t_stats <= 0.0:
		_t_stats = 3.0
		if montre or outil != "":
			calculer_stats()
	var show := montre or calque or outil != ""
	if show and _sale:
		_reconstruire()
	if _fill != null:
		_fill.visible = show
		_bord.visible = show
		_survol.visible = outil != ""
	for q in _etiquettes:
		(_etiquettes[q] as Label3D).visible = show


func set_outil(o: String, qid := -1) -> void:
	outil = o
	outil_q = qid if o == "peindre" else -1
	_survol_k = Vector2i(1 << 30, 0)
	_peint = false
	if o == "peindre" and quartiers.has(qid):
		message.emit("Peindre « %s » : clic ou glisser sur la carte (îlots de 50 m). Clic droit ou Échap pour arrêter." % String(quartiers[qid].nom))
	elif o == "gommer":
		message.emit("Gomme : clic ou glisser pour retirer des îlots de leur quartier. Clic droit ou Échap pour arrêter.")


func _unhandled_input(event: InputEvent) -> void:
	if outil == "" or camera == null or world == null:
		return
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		_survoler(mm.position)
		if _peint and (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_appliquer()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			set_outil("")
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			_peint = mb.pressed
			if mb.pressed:
				_survoler(mb.position)
				_appliquer()
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		set_outil("")
		get_viewport().set_input_as_handled()


func _appliquer() -> void:
	if _survol_k.x == 1 << 30:
		return
	if outil == "peindre":
		peindre(outil_q, _survol_k, int(PINCEAUX[clampi(rayon, 0, PINCEAUX.size() - 1)]))
	elif outil == "gommer":
		gommer(_survol_k, int(PINCEAUX[clampi(rayon, 0, PINCEAUX.size() - 1)]))


func _survoler(screen: Vector2) -> void:
	var hit: Variant = world.pick_cell(camera.project_ray_origin(screen), camera.project_ray_normal(screen))
	if hit == null:
		return
	var k := case_de(float(hit.x) + 0.5, float(hit.y) + 0.5)
	if k == _survol_k:
		return
	_survol_k = k
	var r := int(PINCEAUX[clampi(rayon, 0, PINCEAUX.size() - 1)])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dz * dz > r * r + r:
				continue
			var kk := k + Vector2i(dx, dz)
			var ok := (raison_peindre(outil_q, kk) if outil == "peindre" else raison_gommer(kk)) == ""
			_carre(st, kk, Color(0.3, 0.95, 0.4, 0.4) if ok else Color(1.0, 0.3, 0.25, 0.4), 1.6)
	_survol.mesh = st.commit()


func _h(x: float, z: float) -> float:
	var h := NAN
	if world != null:
		h = world.cell_height(Vector2i(floori(x), floori(z)))
		if is_nan(h) and world.horizon != null:
			h = world.horizon.height_at(x, z)
	return maxf(h, 0.0) if not is_nan(h) else 0.0


func _carre(st: SurfaceTool, k: Vector2i, col: Color, dy: float) -> void:
	const N := 5
	var step := float(CASE) / N
	var x0 := float(k.x * CASE)
	var z0 := float(k.y * CASE)
	var hs := []
	for i in N + 1:
		var row := []
		for j in N + 1:
			var x := x0 + i * step
			var z := z0 + j * step
			row.append(Vector3(x, _h(x, z) + dy, z))
		hs.append(row)
	for i in N:
		for j in N:
			var a: Vector3 = hs[i][j]
			var b: Vector3 = hs[i + 1][j]
			var c: Vector3 = hs[i + 1][j + 1]
			var d: Vector3 = hs[i][j + 1]
			for p in [a, b, c, a, c, d]:
				st.set_color(col)
				st.add_vertex(p)


func couleur(qid: int) -> Color:
	return COULEURS[int(quartiers.get(qid, {}).get("couleur", 0)) % COULEURS.size()]


func _reconstruire() -> void:
	_sale = false
	var fill := SurfaceTool.new()
	fill.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bord := SurfaceTool.new()
	bord.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nf := 0
	var nb := 0
	var centres := {}
	for k in cases:
		var q := int(cases[k])
		if not quartiers.has(q):
			continue
		var col := couleur(q)
		_carre(fill, k, Color(col, 0.28 if q == selection else 0.18), 1.1)
		nf += 1
		var c := centre_case(k)
		if not centres.has(q):
			centres[q] = [Vector2.ZERO, 0]
		centres[q][0] += c
		centres[q][1] += 1
		var x0 := float(k.x * CASE)
		var z0 := float(k.y * CASE)
		for e in [[Vector2i(0, -1), Vector2(x0, z0), Vector2(x0 + CASE, z0)], [Vector2i(0, 1), Vector2(x0, z0 + CASE), Vector2(x0 + CASE, z0 + CASE)],
				[Vector2i(-1, 0), Vector2(x0, z0), Vector2(x0, z0 + CASE)], [Vector2i(1, 0), Vector2(x0 + CASE, z0), Vector2(x0 + CASE, z0 + CASE)]]:
			if int(cases.get(k + (e[0] as Vector2i), -1)) == q:
				continue
			_trait(bord, e[1], e[2], col)
			nb += 1
	_fill.mesh = fill.commit() if nf > 0 else null
	_bord.mesh = bord.commit() if nb > 0 else null
	# Étiquettes : le nom au milieu du quartier, avec ses arrêtés.
	for q in _etiquettes.keys():
		if not centres.has(q):
			(_etiquettes[q] as Node).queue_free()
			_etiquettes.erase(q)
	for q in centres:
		var l: Label3D = _etiquettes.get(q)
		if l == null:
			l = Label3D.new()
			l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			l.fixed_size = true
			l.pixel_size = 0.001
			l.font_size = 34
			l.outline_size = 10
			l.no_depth_test = true
			add_child(l)
			_etiquettes[q] = l
		var n := (quartiers[q].arretes as Dictionary).size()
		l.text = String(quartiers[q].nom) + ("\n%d arrêté%s" % [n, "s" if n > 1 else ""] if n > 0 else "")
		l.outline_modulate = Color(couleur(q).darkened(0.6), 0.9)
		var c: Vector2 = centres[q][0] / float(centres[q][1])
		l.position = Vector3(c.x, _h(c.x, c.y) + 25.0, c.y)


## Un côté de quartier : une bande colorée au sol, du bord vers l'intérieur.
func _trait(st: SurfaceTool, a: Vector2, b: Vector2, col: Color) -> void:
	var d := (b - a).normalized()
	var n := Vector2(-d.y, d.x) * 1.5
	var pts := [a - n, b - n, b + n, a + n]
	var v := []
	for p in pts:
		v.append(Vector3(p.x, _h(p.x, p.y) + 1.4, p.y))
	for i in [0, 1, 2, 0, 2, 3]:
		st.set_color(Color(col, 0.9))
		st.add_vertex(v[i])


# --- Sauvegarde ----------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var qs := []
	for qid in quartiers:
		var q: Dictionary = quartiers[qid]
		var cs := []
		for k in cases_de(qid):
			cs.append([k.x, k.y])
		qs.append({"id": qid, "nom": q.nom, "couleur": q.couleur, "vid": q.vid, "cree": q.get("cree", 0),
			"arretes": (q.arretes as Dictionary).duplicate(), "cases": cs})
	return {"version": 1, "next_id": next_id, "quartiers": qs, "journal": journal.duplicate(true)}


func from_dict(d: Dictionary) -> void:
	clear()
	next_id = maxi(1, int(d.get("next_id", 1)))
	for e in d.get("quartiers", []):
		var qid := int(e.id)
		var ar := {}
		var src: Dictionary = e.get("arretes", {})
		for aid in src:
			if not Arretes.get_arrete(String(aid)).is_empty():
				ar[String(aid)] = int(src[aid])
		quartiers[qid] = {"id": qid, "nom": String(e.get("nom", "Quartier")), "couleur": int(e.get("couleur", qid - 1)),
			"vid": int(e.get("vid", 0)), "cree": int(e.get("cree", 0)), "arretes": ar}
		for k in e.get("cases", []):
			cases[Vector2i(int(k[0]), int(k[1]))] = qid
		next_id = maxi(next_id, qid + 1)
	for j in d.get("journal", []):
		if j is Dictionary:
			journal.append({"jour": int(j.get("jour", 0)), "vid": int(j.get("vid", 0)), "texte": String(j.get("texte", ""))})
	_maj_villes()
	_apres_changement()
