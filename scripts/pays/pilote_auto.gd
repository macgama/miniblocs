class_name PiloteAuto
extends Node
## Pilote automatique d'une ville (panneau Pays, Maj+P → « Pilote auto ») :
## à la demande du joueur, la ville se gère et se construit toute seule.
##
## Chaque jour de jeu, pour chaque ville pilotée dont le joueur est le maire : une construction si besoin ;
## une fois par semaine, aussi le budget et les arrêtés ; une manifestation est
## reçue (négociation) si la caisse le permet :
##   1. le budget est tenu à l'équilibre (GestionAuto, programme « équilibre ») ;
##   2. une seule construction, la plus urgente, si la caisse peut la payer en
##      gardant une réserve (3 mois de dépenses, 200 k€ au moins) :
##      - pas de rue : une rue de 300 m devant la mairie ;
##      - logements presque pleins : une zone résidentielle le long d'une rue
##        (village neuf : 10 logements d'avance, ou ses zones sont pleines ;
##        zones de 120 m, plus nombreuses) ;
##      - services selon la population (BESOINS) : entreprise du bâtiment dès
##        10 habitants (si les chantiers ont besoin d'ouvriers), école dès
##        60 habitants (ou des enfants sans école), aire de jeux, boulangerie,
##        parc, pompiers, police, supérette, antenne 4G, central téléphonique, collecte des
##        déchets (dépôt de camions-bennes et décharge), gymnase,
##        deuxième école, hôpital ;
##      - chômage au-dessus de 12 % : une zone d'activités (commerces ou ateliers) ;
##      - plus de place le long des rues : la rue la plus proche est prolongée.
## Les bâtiments vont le long des rues de la ville, sur son territoire.

signal changed
signal message(text: String)

const JOURS_ENTRE := 7
const RESERVE_MIN := 200_000
const ZONE_LONG := 40
## Village neuf : des zones de 120 m le long des rues (sinon 40 m), pour
## que les maisons poussent sans attendre le zonage du lendemain.
const ZONE_LONG_NEUF := 120
const ZONE_LARGE := 30
const CHOMAGE_MAX := 12.0
## Services : [type, habitants à partir desquels il en faut un, nombre voulu par tranche].
const BESOINS := [
	# Ses propres ouvriers pour les chantiers, dès les premiers foyers (seulement quand
	# les chantiers ont besoin d'ouvriers : Fondateurs.regle_active).
	["entreprise_btp", 10, 3000],
	["ecole", 60, 1500], ["aire_jeux", 40, 0], ["boulangerie", 80, 0], ["parc", 150, 0], ["pompiers", 250, 0],
	["police", 250, 4000], ["superette", 300, 0], ["pylone_4g", 150, 0], ["central_telephonique", 400, 0],
	["depot_collecte", 200, 6000], ["decharge", 200, 0],
	["gymnase", 600, 0], ["hopital", 2000, 0],
	# Degrés de l'école (scripts/education) : collège, lycée ou gymnase, école professionnelle,
	# hautes écoles, université et logements étudiants pour les grandes villes.
	["college", 1200, 6000], ["lycee", 4000, 15000], ["ecole_professionnelle", 5000, 30000],
	["haute_ecole", 20000, 0], ["universite", 40000, 0], ["residence_etudiante", 40000, 20000],
]

## Besoins qu'on attend d'avoir les moyens de payer, sans bloquer les suivants.
const OPTIONNELS := ["college", "lycee", "ecole_professionnelle", "haute_ecole", "universite", "residence_etudiante"]

var buildings: BuildingSystem
var transport: TransportSystem
var zones: ZoneSystem
var communes: Communes
var population: Population
var pays: Pays
var world: TerrainWorld

## Villes pilotées : vid -> true.
var actifs := {}
## Dernières décisions de chaque ville : vid -> [{jour, texte}].
var journal := {}
var _dernier_jour := -1


static var instance: PiloteAuto


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func setup(bs: BuildingSystem, ts: TransportSystem, z: ZoneSystem, cm: Communes, pop: Population, p: Pays, w: TerrainWorld) -> void:
	buildings = bs
	transport = ts
	zones = z
	communes = cm
	population = pop
	pays = p
	world = w


func clear() -> void:
	_prol_curseur.clear()
	actifs.clear()
	journal.clear()
	_dernier_jour = -1
	changed.emit()


func actif(vid: int) -> bool:
	return bool(actifs.get(vid, false))


func activer(vid: int, on: bool) -> void:
	if on:
		actifs[vid] = true
		_noter(vid, "Pilote automatique activé : la ville se gère et se construit toute seule.")
		message.emit("%s passe en pilote automatique : budget à l'équilibre, logements, services et emplois selon ses besoins." % pays.nom_de(vid))
	else:
		actifs.erase(vid)
		_noter(vid, "Pilote automatique arrêté.")
		message.emit("%s : tu reprends la main." % pays.nom_de(vid))
	changed.emit()


func _noter(vid: int, t: String) -> void:
	if not journal.has(vid):
		journal[vid] = []
	var j: Array = journal[vid]
	j.append({"jour": _jour(), "texte": t})
	while j.size() > 12:
		j.pop_front()


func _jour() -> int:
	return int(population.now().day) if population != null else 0


func _process(_delta: float) -> void:
	if population == null or actifs.is_empty():
		return
	if Time.get_ticks_msec() - _manifs_ms > 2000:
		_manifs_ms = Time.get_ticks_msec()
		repondre_manifestations()
	var d := _jour()
	if d != _dernier_jour:
		# Jour suivant alors que des villes attendent encore : on les finit d'abord.
		while not _file.is_empty():
			_journee(int(_file.pop_front()), _file_jour)
		_dernier_jour = d
		_file = actifs.keys()
		_file_jour = d
	# Une ville par image au plus (minuit : Etalement).
	if not _file.is_empty() and Etalement.libre():
		_journee(int(_file.pop_front()), _file_jour)


## Villes pilotées qui n'ont pas encore eu leur journée, et le jour en question.
var _file: Array = []
var _file_jour := -1


func _journee(vid: int, d: int) -> void:
	if communes == null or not communes.villages.has(vid) or not actifs.has(vid):
		actifs.erase(vid)
		return
	_en_journee = true
	if posmod(d + vid, JOURS_ENTRE) == 0:
		semaine(vid)
	elif pays.joueur_maire(vid):
		# Entre deux semaines : une construction par jour si la ville en a besoin.
		var fait := construire(vid)
		if fait != "":
			_noter(vid, fait)
			changed.emit()
	_en_journee = false


var _manifs_ms := -100000


## Manifestation dans une ville pilotée : le pilote reçoit les manifestants
## (négociation payée par la ville) s'il en a les moyens, sinon il laisse faire.
func repondre_manifestations() -> void:
	var av := Avis.instance
	if av == null or av.manifs == null:
		return
	for id in av.manifs.liste.keys():
		var m: Dictionary = av.manifs.liste[id]
		var vid := int(m.get("vid", -1))
		if String(m.etat) == "finie" or String(m.reponse) != "" or not actif(vid) or not pays.joueur_maire(vid):
			continue
		if dispo(vid) >= av.manifs.cout_negociation(m):
			if av.manifs.repondre(int(id), "negocier") == "":
				_noter(vid, "Manifestation : la mairie a reçu les manifestants (%s)." % BuildingSystem.format_money(av.manifs.cout_negociation(m)))
				changed.emit()


## La semaine d'une ville pilotée : budget puis une construction.
func semaine(vid: int) -> String:
	if not pays.joueur_maire(vid):
		return ""
	GestionAuto.gerer_budget(vid, "equilibre")
	var fait := construire(vid)
	if fait != "":
		_noter(vid, fait)
		changed.emit()
	# Arrêtés utiles dans les quartiers (ou le plus cher retiré si la caisse est dans le rouge).
	if Quartiers.instance != null:
		var ar := Quartiers.instance.piloter(vid)
		if ar != "":
			_noter(vid, "Arrêté : " + ar)
			changed.emit()
	return fait


# --- Besoins -----------------------------------------------------------------------------

## Chiffres de la ville : habitants, foyers, logements, enfants sans école, chômage.
func chiffres(vid: int) -> Dictionary:
	communes.calculer_stats()
	var st: Dictionary = communes.stats.get(vid, {})
	var out := {"hab": int(st.get("hab", 0)), "foyers": int(st.get("foyers", 0)), "logements": int(st.get("logements", 0)),
		"sans_ecole": 0, "actifs": 0, "chomeurs": 0}
	for pid in population.persons:
		var p: Dictionary = population.persons[pid]
		if communes.village_de(population.home_of(p)) != vid:
			continue
		var s := population.stage(p)
		if population.edu.sans_ecole(p):
			out.sans_ecole += 1
		elif s == "actif":
			out.actifs += 1
		elif s == "chomeur":
			out.chomeurs += 1
	var adultes := int(out.actifs) + int(out.chomeurs)
	out["chomage"] = 100.0 * int(out.chomeurs) / adultes if adultes > 0 else 0.0
	return out


## Bâtiments de ce type dans la ville. Un bâtiment qui en joue le rôle compte
## aussi (maison d'école d'une partie historique, modèle de l'Atelier : base_of).
func compter(vid: int, type_id: String) -> int:
	var n := 0
	for bid in buildings.buildings:
		var t := String(buildings.buildings[bid].t)
		if (t == type_id or BuildingCatalog.base_of(t) == type_id) and communes.village_de(bid) == vid:
			n += 1
	return n


## Le bâtiment à construire pour un besoin : le type lui-même, ou dans une partie
## historique le plus récent des bâtiments d'époque qui jouent son rôle (maison
## d'école en 1800, école de la République en 1890…). "" : rien n'existe encore.
static func type_d_epoque(id: String) -> String:
	if Epoques.batiment_disponible(id):
		return id
	var types := BuildingCatalog.all_types()
	var best := ""
	var best_a := -1
	for t in types:
		# Seulement les bâtiments d'époque (année d'apparition), pas les modèles du joueur.
		if t == id or types[t].get("cache", false) or not types[t].has("annee") or BuildingCatalog.base_of(t) != id:
			continue
		var a := Epoques.annee_batiment(t)
		if Epoques.batiment_disponible(t) and a > best_a:
			best = t
			best_a = a
	return best


## Un bâtiment de ce rôle (base_of) est-il en chantier dans la ville ?
func _en_chantier(vid: int, base: String) -> bool:
	for bid in buildings.buildings:
		if buildings.en_chantier(bid) and BuildingCatalog.base_of(String(buildings.buildings[bid].t)) == base \
				and communes.village_de(bid) == vid:
			return true
	return false


## Bâtiments à logements en chantier dans la ville.
func logements_en_chantier(vid: int) -> int:
	var n := 0
	for bid in buildings.buildings:
		if buildings.en_chantier(bid) and int(BuildingCatalog.get_type(String(buildings.buildings[bid].t)).get("logements", 0)) > 0 \
				and communes.village_de(bid) == vid:
			n += 1
	return n


func zones_de(vid: int, k: String) -> int:
	var n := 0
	for zid in zones.zones:
		var z: Dictionary = zones.zones[zid]
		if String(z.k) != k:
			continue
		var r := ZoneSystem.zone_rect(z)
		if pays.payeur_du_rect(r) == vid:
			n += 1
	return n


## Argent disponible au-delà de la réserve.
func dispo(vid: int) -> int:
	if buildings.unlimited_money:
		return 1 << 40
	var b := BudgetCommunal.instance
	var dep := 0.0
	if b != null:
		var e: Dictionary = b.etat_de(vid).get("dernier", {})
		dep = float(e.get("total_depenses", 0.0))
	return pays.solde(vid) - maxi(RESERVE_MIN, roundi(dep * 3.0))


## La construction la plus urgente, ou "" si rien à faire (ou pas d'argent).
func construire(vid: int) -> String:
	if _voies(vid).is_empty():
		return _rue_mairie(vid)
	var c := chiffres(vid)
	var libres := int(c.logements) - int(c.foyers)
	var hab := int(c.hab)
	# Village neuf : des logements d'avance pour les familles qui arrivent, et une zone de plus.
	var neuf := communes.est_jeune(vid)
	var marge := maxi(10 if neuf else 3, int(c.foyers) / 10)
	# Village neuf : aussi quand ses zones ne font plus pousser de logements (pleines).
	var a_zoner := libres < marge or (neuf and logements_en_chantier(vid) < 2)
	if a_zoner and zones_de(vid, "R") <= (hab / 25 + 4 if neuf else hab / 40 + 2):
		var t := _zoner(vid, "R", ZONE_LONG_NEUF if neuf else ZONE_LONG)
		if t != "":
			return t
	for b in BESOINS:
		var besoin := String(b[0])
		var id := type_d_epoque(besoin)
		if id == "":
			continue
		if id == Fondateurs.ENTREPRISE and (Fondateurs.instance == null or not Fondateurs.instance.regle_active()):
			continue
		var voulu := 1 if hab >= int(b[1]) else 0
		# Un de plus par tranche, mais seulement passé le seuil : avant, ceili(1 / 1500) = 1
		# faisait bâtir école, police et dépôt de collecte dès le premier habitant.
		if int(b[2]) > 0 and voulu > 0:
			voulu = maxi(voulu, ceili(float(hab) / float(b[2])))
		# Une école de plus pour les enfants sans école, mais pas tant qu'une autre est
		# en chantier : ses élèves l'attendent (sinon, avec une maison d'école à
		# 600 k€, une nouvelle chaque jour tant que la première n'est pas finie).
		if besoin == "ecole" and int(c.sans_ecole) > 0 and not _en_chantier(vid, "ecole"):
			voulu = maxi(voulu, compter(vid, "ecole") + (1 if int(c.sans_ecole) > 15 or compter(vid, "ecole") == 0 else 0))
		if compter(vid, besoin) >= voulu:
			continue
		var prix := BuildingCatalog.prix_ville(id)
		# Établissements chers (lycée, hautes écoles…) : attendus sans bloquer le reste.
		if besoin in OPTIONNELS and dispo(vid) < prix:
			continue
		if besoin == "ecole" and dispo(vid) < prix:
			_financer_ecole(vid, prix)
		if dispo(vid) < prix:
			return ""
		if ReglagesPartie.actuel.raison_blocage(id) != "":
			continue
		var bid := _poser(vid, id)
		if bid >= 0:
			return "%s construit (%s)." % [String(BuildingCatalog.get_type(id).name), BuildingSystem.format_money(prix) if prix > 0 else "promoteur privé"]
		return _prolonger(vid)
	if hab >= 50 and float(c.chomage) > CHOMAGE_MAX:
		var k := "C" if zones_de(vid, "C") <= zones_de(vid, "I") else "I"
		var t := _zoner(vid, k)
		if t != "":
			return t
	return ""


## Une école coûte bien plus que ce qu'une commune met de côté (6 M€ pour 300 élèves) :
## comme en vrai, l'État en paie une part et la ville emprunte le reste sur 20 ans.
const ECOLE_PART_ETAT := 0.4
const ECOLE_EMPRUNT_ANS := 20
## Le pays garde au moins cette somme dans sa caisse.
const RESERVE_PAYS := 1_000_000


## Plan de financement d'une école qui manque : subvention du pays (jusqu'à 40 %
## du prix), puis emprunt de la ville. Rien n'est versé si l'emprunt est refusé.
func _financer_ecole(vid: int, prix: int) -> bool:
	if buildings.unlimited_money or pays == null:
		return true
	var manque := prix - dispo(vid)
	if manque <= 0:
		return true
	var nk := pays.nation_de(vid)
	var sub := 0
	if nk != vid:
		sub = clampi(mini(manque, roundi(prix * ECOLE_PART_ETAT)), 0, maxi(0, pays.solde(nk) - RESERVE_PAYS))
	var pret := manque - sub
	var refus := [""]
	if pret > 0:
		GestionAuto.dans_ville(vid, func(b: BudgetCommunal) -> void: refus[0] = b.refus_emprunt(pret, ECOLE_EMPRUNT_ANS))
		if String(refus[0]) != "" or BudgetCommunal.instance == null:
			return false
	if sub > 0 and pays.virer(nk, vid, sub, "Subvention pour une école") != "":
		return false
	if pret > 0:
		var fait := [false]
		GestionAuto.dans_ville(vid, func(b: BudgetCommunal) -> void: fait[0] = not b.emprunter(pret, ECOLE_EMPRUNT_ANS).is_empty())
		if not bool(fait[0]):
			return false
	_noter(vid, "École financée : %s de subvention du pays, %s empruntés sur %d ans." % [
		BuildingSystem.format_money(sub), BuildingSystem.format_money(pret), ECOLE_EMPRUNT_ANS])
	return true


# --- Où construire ------------------------------------------------------------------------

func _net() -> TransportNetwork:
	return transport.network


## Rues de la ville (routes dont le milieu est sur son territoire).
func _voies(vid: int) -> Array:
	var out := []
	var net := _net()
	for eid in net.edges:
		if TransportTypes.mode_of(String(net.edges[eid].t)) != TransportTypes.Mode.ROAD:
			continue
		if pays.payeur_de_voie(eid) == vid:
			out.append(eid)
	out.sort()
	return out


## Points le long des rues, de part et d'autre, à `recul` m du bord : [Vector3, tangente].
func _bords(vid: int, recul: float, max_n := 240) -> Array:
	var out := []
	var net := _net()
	for eid in _voies(vid):
		var e: Dictionary = net.edges[eid]
		var l := float(e.len)
		var s := 12.0
		while s < l - 12.0 and out.size() < max_n:
			var p := net.point_at(eid, s)
			var tg := net.tangent_at(eid, s)
			tg.y = 0.0
			tg = tg.normalized()
			var n := Vector3(-tg.z, 0.0, tg.x)
			for side in [1.0, -1.0]:
				var q: Vector3 = p + n * (net.half_width(eid) + recul) * side
				if pays.payeur_au_point(q.x, q.z) == vid:
					out.append([q, tg])
			s += 18.0
	return out


func _poser(vid: int, id: String) -> int:
	var t := BuildingCatalog.get_type(id)
	var prof := maxf(float(t.get("w", 20)), float(t.get("d", 20)))
	for b in _bords(vid, prof * 0.5 + 3.0):
		var q: Vector3 = b[0]
		var c := Vector2i(roundi(q.x), roundi(q.z))
		var r := buildings.best_rotation(id, c)
		if buildings.check_place(id, c, r).ok:
			var caisse_prev := Pays.a_la_caisse(vid)
			var bid := buildings.place(id, c, r)
			Pays.retour(caisse_prev)
			if bid >= 0:
				return bid
	return -1


## Une zone de 40 × 30 m (ou `longueur` × 30 m) le long d'une rue, sur un terrain libre.
func _zoner(vid: int, k: String, longueur := ZONE_LONG) -> String:
	var bords := _bords(vid, ZONE_LARGE * 0.5 + 2.0)
	for l in ([longueur, ZONE_LONG] if longueur > ZONE_LONG else [ZONE_LONG]):
		for b in bords:
			var q: Vector3 = b[0]
			var tg: Vector3 = b[1]
			var le_long_x := absf(tg.x) >= absf(tg.z)
			var w: int = l if le_long_x else ZONE_LARGE
			var h: int = ZONE_LARGE if le_long_x else l
			var rect := Rect2i(roundi(q.x) - w / 2, roundi(q.z) - h / 2, w, h)
			if not _libre(vid, rect):
				continue
			if zones.add_zone(k, rect) >= 0:
				return "Zone %s de %d × %d m." % [String(ZoneSystem.KINDS[k].name).to_lower(), w, h]
	return _prolonger(vid)


## Rectangle sur le territoire, sans bâtiment, sans zone, sans voie.
func _libre(vid: int, rect: Rect2i) -> bool:
	if communes != null and not communes.rect_dans_territoire(rect):
		return false
	for x in range(rect.position.x, rect.end.x, 5):
		for z in range(rect.position.y, rect.end.y, 5):
			if buildings.occupancy.has(Vector2i(x, z)):
				return false
			if pays.payeur_au_point(x, z) != vid:
				return false
	for zid in zones.zones:
		if ZoneSystem.zone_rect(zones.zones[zid]).intersects(rect):
			return false
	var net := _net()
	var c := Vector3(rect.get_center().x, 0.0, rect.get_center().y)
	var rayon := Vector2(rect.size).length() * 0.5
	for eid in net.edges:
		var near := net.nearest_on_edge(eid, c)
		var hw := net.half_width(eid)
		if float(near.dist) > rayon + hw:
			continue
		var pos: Vector3 = near.pos
		if Rect2(rect).grow(hw).has_point(Vector2(pos.x, pos.z)):
			return false
	return true


## Première rue : 300 m devant la mairie.
func _rue_mairie(vid: int) -> String:
	var v: Dictionary = communes.villages[vid]
	var c: Vector2 = v.c
	for dz in [24.0, -24.0, 40.0, -40.0]:
		var a := Vector3(c.x - 150.0, 0.0, c.y + dz)
		var b := Vector3(c.x + 150.0, 0.0, c.y + dz)
		if _route(vid, a, b):
			return "Première rue tracée devant la mairie (300 m)."
	return ""


## Prolonge une impasse de la ville de 120 m, sinon ouvre une rue en travers.
## Essais de pose d'une rue par jour du pilote : chaque essai refusé coûte (relief,
## croisements) et une grande ville en a des centaines. On reprend le lendemain là où on
## s'est arrêté. Hors de la journée du pilote (appel direct), on essaie tout, comme avant.
const PROLONGER_BUDGET_US := 25000
var _en_journee := false
var _prol_curseur := {}


func _prolonger(vid: int) -> String:
	var budget_us := PROLONGER_BUDGET_US if _en_journee else -1
	var net := _net()
	var essais := []  # [a, b, message]
	for eid in _voies(vid):
		var e: Dictionary = net.edges[eid]
		for n in [int(e.a), int(e.b)]:
			if net.degree(n) != 1:
				continue
			var dir := -net.leave_dir(eid, n)
			dir.y = 0.0
			if dir.length() < 0.01:
				continue
			var a := net.node_pos(n)
			var b := a + dir.normalized() * 120.0
			if pays.payeur_au_point(b.x, b.z) == vid:
				essais.append([a, b, "Rue prolongée de 120 m pour faire de la place."])
	for eid in _voies(vid):
		var e: Dictionary = net.edges[eid]
		var m := net.point_at(eid, float(e.len) * 0.5)
		var tg := net.tangent_at(eid, float(e.len) * 0.5)
		var n := Vector3(-tg.z, 0.0, tg.x).normalized()
		for side in [1.0, -1.0]:
			var b: Vector3 = m + n * 120.0 * side
			if pays.payeur_au_point(b.x, b.z) == vid:
				essais.append([m, b, "Nouvelle rue de 120 m pour faire de la place."])
	if essais.is_empty():
		return ""
	# Les bouts de rue d'abord, puis les rues neuves ; on reprend au curseur si le dernier
	# appel a manqué de temps.
	var t0 := Time.get_ticks_usec()
	var debut := int(_prol_curseur.get(vid, 0)) % essais.size()
	var ordre := []
	for k in essais.size():
		ordre.append((debut + k) % essais.size())
	for i in ordre:
		var x: Array = essais[i]
		if _route(vid, x[0], x[1]):
			_prol_curseur.erase(vid)
			return x[2]
		if budget_us >= 0 and Time.get_ticks_usec() - t0 > budget_us:
			_prol_curseur[vid] = int(i) + 1
			return ""
	_prol_curseur.erase(vid)
	return ""


func _route(vid: int, a: Vector3, b: Vector3) -> bool:
	if pays.payeur_au_point(a.x, a.z) != vid or pays.payeur_au_point(b.x, b.z) != vid:
		return false
	var caisse_prev := Pays.a_la_caisse(vid)
	var r: Dictionary = transport.build_segment("route", a, b)
	Pays.retour(caisse_prev)
	return bool(r.get("ok", false))


# --- Sauvegarde ------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var a := []
	for vid in actifs:
		a.append(int(vid))
	var j := {}
	for vid in journal:
		j[str(vid)] = (journal[vid] as Array).duplicate(true)
	return {"version": 1, "actifs": a, "journal": j}


func from_dict(d: Dictionary) -> void:
	clear()
	for vid in d.get("actifs", []):
		actifs[int(vid)] = true
	var j: Dictionary = d.get("journal", {})
	for k in j:
		journal[int(k)] = (j[k] as Array).duplicate(true)
