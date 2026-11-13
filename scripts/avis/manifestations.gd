class_name Manifestations
extends RefCounted
## Manifestations des habitants mécontents.
##
## - Chaque matin, si un thème de l'avis tombe sous 35 / 100 (assez d'habitants
##   concernés, 5 jours au moins depuis la dernière sur ce thème), une
##   manifestation est annoncée l'après-midi devant la mairie (sinon la place
##   du marché, un bâtiment public).
## - On la voit : un cortège avec pancartes et banderole remonte la rue la plus
##   proche jusqu'à la mairie (la rue est fermée à la circulation), et les
##   manifestants quittent leur journée pour y aller.
## - Le joueur répond (panneau Avis, Y) :
##   * Négocier : coûte de l'argent, le thème remonte un mois, la colère retombe.
##   * Ignorer : le thème baisse ; à la 2e fois sur le même thème, grève des
##     agents de la ville pendant une journée (écoles, mairie, services fermés).
##   * Police (s'il y a un commissariat) : une patrouille disperse le cortège ;
##     calme tout de suite, mais la vie politique baisse et les manifestants
##     s'en souviennent.
##   Sans réponse, la manifestation compte comme ignorée.

const SEUIL := 35
const DELAI_JOURS := 5
const HEURES := Vector2(14.0, 17.0)
const MIN_HABITANTS := 50
const PARTICIPANTS_MAX := 2000
## Manifestants dessinés au plus, et qui quittent leur journée pour y aller.
const DESSINES_MAX := 60
const MARCHEURS_MAX := 120
const COUT_PAR_MANIFESTANT := 300
const LONGUEUR_CORTEGE := 220.0

const SLOGANS := {
	"emploi": ["Du travail pour tous !", "Des emplois, pas des promesses !"],
	"logement": ["Des logements dignes !", "Stop aux loyers trop chers !"],
	"services": ["Des écoles pour nos enfants !", "Un hôpital pour tous !"],
	"securite": ["Plus de sécurité !", "La police dans nos quartiers !"],
	"environnement": ["On veut respirer !", "Stop à la pollution !", "Une ville propre !"],
	"transports": ["Stop aux bouchons !", "Des bus, des trams !"],
	"impots": ["Trop d'impôts !", "Rendez-nous notre argent !"],
	"reseaux": ["Eau et courant pour tous !", "Internet partout !"],
	"loisirs": ["Des parcs et des stades !", "On veut s'amuser !"],
	"commerces": ["Des commerces près de chez nous !"],
	"politique": ["Tenez vos promesses !", "Écoutez-nous !"],
}

var avis: Avis
## id -> {id, theme, nb, jour, debut, fin, bid, pos, etat ("prevue", "en_cours", "finie"),
##        reponse, incident, part (pids), edge, chemin, slogan}
var liste: Dictionary = {}
var next_id := 1
## Thème -> dernier jour de manifestation.
var dernier: Dictionary = {}
## Thème -> nombre de manifestations ignorées d'affilée.
var colere: Dictionary = {}
## Manifestants dispersés par la police : pid -> fin (unix).
var rancune: Dictionary = {}
## Pour les tests : -1 = réglage de la partie, 0 = non, 1 = oui.
var forcer := -1
var rng := RandomNumberGenerator.new()
var _part_set: Dictionary = {}
var _nodes: Dictionary = {}


func _init(a: Avis) -> void:
	avis = a
	rng.randomize()


func clear() -> void:
	for id in liste.keys():
		_retirer_visuels(liste[id])
		_rouvrir(liste[id])
	liste.clear()
	next_id = 1
	dernier.clear()
	colere.clear()
	rancune.clear()
	_part_set.clear()
	if avis.population != null and avis.population.effectif != null:
		avis.population.effectif.greve.clear()


func actives() -> bool:
	return forcer == 1 if forcer >= 0 else ReglagesPartie.actuel.manifestations


func en_cours() -> Array:
	var out := []
	for id in liste:
		if String(liste[id].etat) != "finie":
			out.append(liste[id])
	return out


func recentes(n := 10) -> Array:
	var out := liste.values()
	out.sort_custom(func(a, b) -> bool: return int(a.id) > int(b.id))
	return out.slice(0, n)


# --- Déclenchement ------------------------------------------------------------------

func nouveau_jour(n: Dictionary) -> void:
	# Les manifestations finies depuis plus de 3 jours sont oubliées.
	for id in liste.keys():
		var m: Dictionary = liste[id]
		if String(m.etat) == "finie" and int(n.day) - int(m.jour) > 3:
			liste.erase(id)
	var t := avis.now()
	for pid in rancune.keys():
		if float(rancune[pid]) <= t:
			rancune.erase(pid)
	if not actives() or not en_cours().is_empty():
		return
	if avis.population == null or avis.population.persons.size() < MIN_HABITANTS:
		return
	var th := pire_theme()
	if th == "":
		return
	if rng.randf() < 0.6:
		annoncer(th)


## Thème le plus mal noté sous le seuil, hors délai, ou "".
func pire_theme() -> String:
	var s := avis.sondage()
	var best := ""
	var best_note := SEUIL
	for th in s.themes:
		var e: Dictionary = s.themes[th]
		if int(e.note) >= best_note or int(e.n) < int(s.n) / 5:
			continue
		if dernier.has(th) and avis.jour() - int(dernier[th]) < DELAI_JOURS:
			continue
		best = th
		best_note = int(e.note)
	return best


## Annonce une manifestation sur ce thème (aujourd'hui l'après-midi, sinon demain).
func annoncer(theme: String, tout_de_suite := false) -> int:
	var n := avis.local_now()
	var day := int(n.day)
	var h0 := HEURES.x
	if tout_de_suite:
		h0 = float(n.h) + 0.05
	elif float(n.h) >= HEURES.x - 0.5:
		day += 1
	var bid := _lieu()
	var pos := _devant(bid)
	var nb := _participants(theme)
	var debut := _unix_at(day, h0)
	var duree := HEURES.y - HEURES.x
	var id := next_id
	next_id += 1
	var sl: Array = SLOGANS.get(theme, SLOGANS.politique)
	var m := {"id": id, "theme": theme, "nb": nb.n, "jour": day, "debut": debut, "fin": debut + duree * 3600.0, "bid": bid, "pos": pos,
		"etat": "prevue", "reponse": "", "incident": -1, "part": nb.part, "edge": -1, "chemin": [], "slogan": String(sl[id % sl.size()])}
	liste[id] = m
	dernier[theme] = day
	_index()
	var lieu := avis.population.building_name(bid) if bid >= 0 else "en ville"
	avis.dire("Colère sur « %s » : environ %d habitants manifesteront %s à %s (%s)." % [Avis.theme_nom(theme).to_lower(), int(m.nb),
		"tout de suite" if tout_de_suite else ("cet après-midi" if day == int(n.day) else "demain après-midi"), _heure(h0), lieu], pos)
	avis.changed.emit()
	return id


func _heure(h: float) -> String:
	return "%d h %02d" % [int(h), int(fposmod(h, 1.0) * 60.0)]


func _unix_at(day: int, hour: float) -> float:
	var off := avis.ambiance.utc_offset() * 3600.0 if avis.ambiance != null else 0.0
	return day * 86400.0 + hour * 3600.0 - off


## Combien de mécontents sur ce thème, et lesquels iront (pour les voir marcher).
func _participants(theme: String) -> Dictionary:
	var ids := avis.echantillon(true, 400)
	var tres := []
	for pid in ids:
		var s := avis.population.satisfaction(avis.population.persons[pid])
		if float(s.themes.get(theme, 0.0)) <= -6.0 or (theme == "politique" and int(s.value) < 35):
			tres.append(pid)
	var scale := float(_adultes()) / maxi(1, ids.size())
	var n := clampi(roundi(tres.size() * scale * 0.35), 12, PARTICIPANTS_MAX)
	tres.shuffle()
	return {"n": n, "part": tres.slice(0, mini(MARCHEURS_MAX, n))}


func _adultes() -> int:
	var n := 0
	for pid in avis.population.persons:
		if avis.population.age_of(avis.population.persons[pid]) >= Population.ADULT_AGE:
			n += 1
	return n


func _lieu() -> int:
	var m := avis.mairie()
	if m >= 0:
		return m
	if avis.evenements != null and avis.evenements.fetes != null:
		var b := avis.evenements.fetes.lieu_marche()
		if b >= 0:
			return b
	for bid in avis.population.known:
		if bool(avis.population.known[bid].get("public", false)):
			return bid
	for bid in avis.population.known:
		return bid
	return -1


func _devant(bid: int) -> Vector3:
	if bid < 0:
		return avis._centre()
	var pos := avis.population.building_pos(bid)
	if avis.evenements != null and avis.evenements.fetes != null:
		return avis.evenements.fetes._devant(bid, pos)
	return pos


# --- Déroulement -------------------------------------------------------------------

func nouvelle_heure(_n: Dictionary) -> void:
	pass


func step() -> void:
	if liste.is_empty():
		return
	var t := avis.now()
	for id in liste.keys():
		var m: Dictionary = liste[id]
		match String(m.etat):
			"prevue":
				if t >= float(m.debut):
					_commencer(m)
			"en_cours":
				if t >= float(m.fin):
					finir(int(m.id), "")
				else:
					_avancer(m, t)


func _commencer(m: Dictionary) -> void:
	m.etat = "en_cours"
	_preparer_chemin(m)
	_fermer(m)
	_creer_visuels(m)
	avis.dire("Manifestation : %d habitants défilent (« %s »). Réponds-leur dans le panneau Avis (Y)." % [int(m.nb), String(m.slogan)], m.pos)
	if avis.population != null and avis.population.passants != null:
		avis.population.passants._plans.clear()
	avis.changed.emit()


## Rue la plus proche du lieu : le cortège en remonte ~220 m jusqu'au lieu.
func _preparer_chemin(m: Dictionary) -> void:
	m.chemin = []
	m.edge = -1
	if avis.transport == null:
		return
	var net := avis.transport.network
	var pos: Vector3 = m.pos
	var best := -1
	var best_d := 90.0
	var best_s := 0.0
	for eid in avis.transport.edges_near(pos, 90.0):
		if not net.edges.has(eid) or net.node_mode(int(net.edges[eid].a)) != TransportTypes.Mode.ROAD:
			continue
		var near := net.nearest_on_edge(eid, pos)
		if float(near.dist) < best_d:
			best_d = float(near.dist)
			best = eid
			best_s = float(near.s)
	if best < 0:
		return
	m.edge = best
	var e: Dictionary = net.edges[best]
	var length := float(e.len)
	var s0 := best_s - LONGUEUR_CORTEGE
	if s0 < 0.0:
		s0 = minf(length, best_s + LONGUEUR_CORTEGE)
	var pts := []
	var steps := 12
	for i in steps + 1:
		var s := lerpf(s0, best_s, float(i) / steps)
		pts.append(Evenements.v3(net.point_at(best, s)))
	pts.append(Evenements.v3(pos))
	m.chemin = pts


func _fermer(m: Dictionary) -> void:
	if int(m.edge) < 0 or avis.transport == null:
		return
	var net := avis.transport.network
	if net.closed_edges.has(int(m.edge)):
		return
	var trafic := _trafic()
	if trafic != null and trafic.has_method("fermer"):
		trafic.call("fermer", int(m.edge), "manifestation")
	else:
		net.closed_edges[int(m.edge)] = "manifestation"
	m.ferme = true
	if avis.evenements != null:
		avis.evenements.reroute()


func _rouvrir(m: Dictionary) -> void:
	if not bool(m.get("ferme", false)) or avis.transport == null:
		return
	m.ferme = false
	var net := avis.transport.network
	var trafic := _trafic()
	if trafic != null and trafic.has_method("rouvrir"):
		trafic.call("rouvrir", int(m.edge))
	elif String(net.closed_edges.get(int(m.edge), "")) == "manifestation":
		net.closed_edges.erase(int(m.edge))
	if avis.evenements != null:
		avis.evenements.reroute()


## Nœud du trafic (fil trafic : Trafic.fermer / rouvrir), s'il existe.
func _trafic() -> Node:
	if not avis.is_inside_tree():
		return null
	for n in avis.get_tree().get_nodes_in_group("avis_sources"):
		if n.has_method("fermer") and n.has_method("rouvrir"):
			return n
	return null


## Le cortège avance pendant la première heure, puis reste devant le lieu.
func _avancer(m: Dictionary, t: float) -> void:
	var node: Node3D = _nodes.get(int(m.id), null)
	if node == null or not is_instance_valid(node):
		return
	var ch: Array = m.chemin
	if ch.size() < 2:
		return
	var u := clampf((t - float(m.debut)) / 3600.0, 0.0, 1.0)
	var f := u * (ch.size() - 1)
	var i := mini(int(f), ch.size() - 2)
	var a := Evenements.to_v3(ch[i])
	var b := Evenements.to_v3(ch[i + 1])
	var p := a.lerp(b, f - i)
	node.position = p
	var dir := b - a
	if dir.length_squared() > 0.01 and u < 1.0:
		node.rotation.y = atan2(-dir.x, -dir.z)


# --- Visuels ---------------------------------------------------------------------------

func _creer_visuels(m: Dictionary) -> void:
	if avis.evenements == null or avis.evenements.visuels == null:
		return
	_retirer_visuels(m)
	var root := Node3D.new()
	root.name = "Manifestation_%d" % int(m.id)
	var ch: Array = m.chemin
	root.position = Evenements.to_v3(ch[0]) if ch.size() >= 2 else (m.pos as Vector3)
	var n := clampi(int(m.nb), 16, DESSINES_MAX)
	var seed := int(m.id) * 7907
	# Le cortège : la foule s'étire derrière la banderole (vers +Z local).
	var foule := EvVisuels.foule(n, Vector2(6.0, 4.0 + n * 0.22), seed, Vector3(0, 0, -40))
	foule.position = Vector3(0, 0, 3.0 + n * 0.11)
	root.add_child(foule)
	root.add_child(pancartes(mini(n / 3, 14), Vector2(7.0, 6.0 + n * 0.35), seed, Color(String(Avis.THEMES.get(m.theme, {}).get("couleur", "f77f00")))))
	(root.get_child(1) as Node3D).position = foule.position
	root.get_child(1).scale = Vector3(0.75, 1.0, 0.6)
	root.add_child(banderole(String(m.slogan)))
	avis.evenements.visuels.add_child(root)
	_nodes[int(m.id)] = root
	_avancer(m, avis.now())


func _retirer_visuels(m: Dictionary) -> void:
	var node = _nodes.get(int(m.id), null)
	if node != null and is_instance_valid(node):
		(node as Node).queue_free()
	_nodes.erase(int(m.id))


## Pancartes : un manche et un panneau blanc ou coloré, au-dessus de la foule.
static func pancartes(n: int, size: Vector2, seed: int, couleur: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "Pancartes"
	var rng := RandomNumberGenerator.new()
	rng.seed = seed + 11
	var k := EvVisuels._kit()
	var cols := [Color("f8f9fa"), Color("ffd166"), couleur, Color("f8f9fa")]
	for i in n:
		var x := rng.randf_range(-size.x, size.x) * 0.45
		var z := rng.randf_range(-size.y, size.y) * 0.45
		var c: Color = cols[rng.randi() % cols.size()]
		k.box(x, 0.9, z, 0.05, 1.3, 0.05, Color("8d6e63"))
		k.box(x, 1.95, z, 0.9, 0.6, 0.04, c)
	var mi := EvVisuels._mesh_instance(k)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 600.0
	root.add_child(mi)
	return root


## Banderole tenue par deux porteurs, en tête du cortège, avec le slogan.
static func banderole(texte: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Banderole"
	var k := EvVisuels._kit()
	k.box(-2.6, 0.0, 0.0, 0.06, 2.2, 0.06, Color("6d4c41"))
	k.box(2.6, 0.0, 0.0, 0.06, 2.2, 0.06, Color("6d4c41"))
	k.box(0.0, 1.35, 0.0, 5.2, 0.8, 0.03, Color("f1faee"))
	var mi := EvVisuels._mesh_instance(k)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	# Le slogan des deux côtés de la banderole.
	for side in [-1.0, 1.0]:
		var lbl := Label3D.new()
		lbl.text = texte
		lbl.font_size = 64
		lbl.pixel_size = 0.0042
		lbl.modulate = Color("c1121f")
		lbl.outline_size = 0
		lbl.shaded = false
		lbl.double_sided = false
		lbl.position = Vector3(0, 1.75, 0.04 * side)
		lbl.rotation.y = PI if side < 0.0 else 0.0
		lbl.width = 1150
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		root.add_child(lbl)
	for x in [-2.6, 2.6]:
		var porteur := MeshInstance3D.new()
		porteur.mesh = EvVisuels.random_person(RandomNumberGenerator.new())
		porteur.position = Vector3(x, 0, 0.35)
		root.add_child(porteur)
	return root


# --- Réponses du joueur -------------------------------------------------------------------

func cout_negociation(m: Dictionary) -> int:
	return ReglagesPartie.prix(int(m.nb) * COUT_PAR_MANIFESTANT)


func police_possible() -> bool:
	return avis.compter(["police", "commissariat", "gendarmerie"]) > 0


## reponse : "negocier", "ignorer" ou "police". Rend un message (vide si fait).
func repondre(id: int, reponse: String) -> String:
	if not liste.has(id):
		return "Manifestation introuvable."
	var m: Dictionary = liste[id]
	if String(m.etat) == "finie" or String(m.reponse) != "":
		return "Déjà répondu."
	var th := String(m.theme)
	match reponse:
		"negocier":
			var cout := cout_negociation(m)
			if avis.evenements != null and not avis.evenements._payer(cout, "negocier"):
				return "Pas assez d'argent pour négocier (%s)." % BuildingSystem.format_money(cout)
			m.reponse = "negocier"
			colere[th] = 0
			avis.ajouter_effet(th, 6.0, 30.0, "la mairie a écouté les manifestants")
			avis.dire("La mairie reçoit les manifestants et s'engage sur « %s » (%s). Le cortège se disperse." % [Avis.theme_nom(th).to_lower(),
				BuildingSystem.format_money(cout)], m.pos)
			finir(id, "negocier")
		"ignorer":
			m.reponse = "ignorer"
			_ignorer(m)
		"police":
			if not police_possible():
				return "Il faut un commissariat pour envoyer la police."
			m.reponse = "police"
			if avis.evenements != null:
				m.incident = avis.evenements.declarer({"type": "manifestation", "position": m.pos, "batiment": int(m.bid), "gravite": 1 if int(m.nb) < 200 else 2,
					"besoin": ["police"], "texte": "Manifestation à disperser (%d personnes)" % int(m.nb), "origine": "avis"})
			avis.dire("La police est envoyée pour disperser la manifestation.", m.pos)
		_:
			return "Réponse inconnue."
	avis.changed.emit()
	return ""


func _ignorer(m: Dictionary) -> void:
	var th := String(m.theme)
	colere[th] = int(colere.get(th, 0)) + 1
	avis.ajouter_effet(th, -4.0, 20.0, "la mairie a ignoré la manifestation")
	if int(colere[th]) >= 2:
		colere[th] = 0
		var n := greve(1.0)
		avis.dire("Les manifestants ne sont pas écoutés : grève des agents de la ville demain (%d bâtiments fermés)." % n, m.pos)
	else:
		avis.dire("La mairie ne répond pas aux manifestants. La colère monte.", m.pos)


## Grève d'une journée des agents de la ville (bâtiments publics, sauf
## hôpitaux, pompiers et police). Rend le nombre de bâtiments fermés.
func greve(jours: float) -> int:
	var pop := avis.population
	if pop == null or pop.effectif == null:
		return 0
	var fin := avis.now() + jours * 86400.0
	var n := 0
	for bid in pop.known:
		var info: Dictionary = pop.known[bid]
		if not bool(info.get("public", false)) or int(info.get("emp", 0)) <= 0:
			continue
		var keys := Metiers.keys_of(String(info.t))
		if keys.has("hopital") or keys.has("pompiers") or keys.has("police"):
			continue
		pop.effectif.greve[bid] = fin
		n += 1
	pop.effectif.signature_fermes += 1
	if pop.passants != null:
		pop.passants._plans.clear()
	return n


## La police est arrivée : le cortège est dispersé.
func on_incident_resolu(inc_id: int) -> void:
	for id in liste:
		var m: Dictionary = liste[id]
		if int(m.incident) == inc_id and String(m.etat) != "finie":
			avis.ajouter_effet("politique", -5.0, 20.0, "manifestation dispersée par la police")
			var fin := avis.now() + 30.0 * 86400.0
			for pid in m.part:
				rancune[int(pid)] = fin
			avis.dire("La police a dispersé la manifestation. Le calme revient, mais les habitants s'en souviendront.", m.pos)
			finir(int(id), "police")
			return


## Effet personnel (manifestants dispersés) : [delta, raison] ou [].
func effet_perso(p: Dictionary) -> Array:
	if rancune.is_empty() or not rancune.has(int(p.id)):
		return []
	if float(rancune[int(p.id)]) <= avis.now():
		return []
	return [-8.0, "− dispersé·e par la police pendant une manifestation"]


func finir(id: int, raison: String) -> void:
	if not liste.has(id):
		return
	var m: Dictionary = liste[id]
	if String(m.etat) == "finie":
		return
	var was := String(m.etat) == "en_cours"
	m.etat = "finie"
	m.fin = minf(float(m.fin), avis.now())
	if raison == "" and String(m.reponse) == "" and was:
		m.reponse = "sans_reponse"
		_ignorer(m)
	elif raison == "" and was:
		avis.dire("Fin de la manifestation.", m.pos)
	_retirer_visuels(m)
	_rouvrir(m)
	_index()
	if avis.population != null and avis.population.passants != null:
		avis.population.passants._plans.clear()
	avis.changed.emit()


# --- Habitants : ceux qui manifestent quittent leur journée ---------------------------------

func _index() -> void:
	_part_set.clear()
	for id in liste:
		var m: Dictionary = liste[id]
		if String(m.etat) == "finie":
			continue
		for pid in m.part:
			_part_set[int(pid)] = int(id)


## Accroché à Population.plan_hooks.
func plan_hook(p: Dictionary, n: Dictionary, plan: Array) -> Array:
	if _part_set.is_empty() or not _part_set.has(int(p.id)):
		return plan
	var m: Dictionary = liste.get(int(_part_set[int(p.id)]), {})
	if m.is_empty() or int(m.jour) != int(n.day) or int(m.bid) < 0 or not avis.population.known.has(int(m.bid)):
		return plan
	var off := avis.ambiance.utc_offset() * 3600.0 if avis.ambiance != null else 0.0
	var h0 := (float(m.debut) + off) / 3600.0 - int(m.jour) * 24.0
	var h1 := (float(m.fin) + off) / 3600.0 - int(m.jour) * 24.0
	var free := false
	for seg in plan:
		if h0 >= float(seg[0]) and h0 < float(seg[1]):
			# On manifeste même en sortant du travail (pas de l'école).
			free = String(seg[2]) in ["maison", "loisir", "sport", "courses", "promenade", "travail"]
			break
	if not free:
		return plan
	return avis.population._apply_order(p, plan, {"d": int(m.jour), "t": h0, "b": int(m.bid), "kind": "loisir", "dur": maxf(0.5, h1 - h0),
		"txt": "Manifeste (%s)" % String(m.slogan)})


# --- Sauvegarde --------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var ls := []
	for id in liste:
		var m: Dictionary = (liste[id] as Dictionary).duplicate(true)
		m.pos = Evenements.v3(m.pos)
		ls.append(m)
	var rc := {}
	for pid in rancune:
		rc[str(pid)] = rancune[pid]
	var gr := {}
	if avis.population != null and avis.population.effectif != null:
		for bid in avis.population.effectif.greve:
			gr[str(bid)] = avis.population.effectif.greve[bid]
	return {"next_id": next_id, "liste": ls, "dernier": dernier.duplicate(), "colere": colere.duplicate(), "rancune": rc, "greve": gr}


func from_dict(d: Dictionary) -> void:
	clear()
	if d.is_empty():
		return
	next_id = int(d.get("next_id", 1))
	for k in (d.get("dernier", {}) as Dictionary):
		dernier[String(k)] = int(d.dernier[k])
	for k in (d.get("colere", {}) as Dictionary):
		colere[String(k)] = int(d.colere[k])
	for k in (d.get("rancune", {}) as Dictionary):
		rancune[int(k)] = float(d.rancune[k])
	if avis.population != null and avis.population.effectif != null:
		avis.population.effectif.greve.clear()
		for k in (d.get("greve", {}) as Dictionary):
			avis.population.effectif.greve[int(k)] = float(d.greve[k])
	for o in d.get("liste", []):
		var m: Dictionary = (o as Dictionary).duplicate(true)
		for key in ["id", "nb", "jour", "bid", "incident", "edge"]:
			m[key] = int(m.get(key, -1))
		m.debut = float(m.debut)
		m.fin = float(m.fin)
		m.pos = Evenements.to_v3(m.get("pos", []))
		if not (m.pos as Vector3).is_finite():
			m.pos = Vector3.ZERO
		var part := []
		for pid in m.get("part", []):
			part.append(int(pid))
		m.part = part
		m.ferme = false
		liste[int(m.id)] = m
		if String(m.etat) == "en_cours":
			m.etat = "prevue"
	_index()
