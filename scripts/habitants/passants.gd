class_name Passants
extends Node3D
## Les habitants visibles : près de la caméra, chaque habitant en trajet est
## dessiné là où sa journée le place (Population.day_plan). Il sort de chez
## lui, suit les voies (sur le trottoir à pied, sur la chaussée en voiture ou
## à vélo), arrive au travail, à l'école, au sport… au rythme de l'horloge.
##
## Allées et venues (près de la caméra, à moins de LOD_PROCHE) :
## - Sortie : la porte s'ouvre (Portes), l'habitant sort du bâtiment et marche
##   jusqu'au trottoir, jusqu'à sa voiture garée le long de la rue (qui démarre
##   ensuite) ou jusqu'à son vélo ; en bus, tram ou train, il marche jusqu'à
##   l'arrêt, attend, puis monte (il disparaît pendant le trajet en ligne) et
##   réapparaît à l'arrêt d'arrivée.
## - Arrivée : la voiture se gare devant le bâtiment et y reste tant qu'il est
##   là (GAREES au plus), il marche jusqu'à la porte, qui s'ouvre, et entre.
## Ces petites scènes suivent EchelleTemps (la pause arrête tout) ; le reste du
## trajet suit l'horloge. Quand l'horloge va plus vite que la scène (vitesses
## rapides), le passant rattrape son retard en RATTRAPAGE secondes au plus.
##
## Niveaux de détail : personnages arrondis animés près de la caméra (au plus
## MAX_PROCHES), simples blocs plus loin, rien au-delà de _radius(). Au plus
## MAX_AGENTS passants, MAX_SCENES scènes de porte et Portes.MAX portes à la fois ;
## les bâtiments les plus proches de la caméra passent en premier.
##
## - Itinéraires : du bâtiment de départ à la voie la plus proche, puis plus
##   court chemin sur le réseau routier (TransportNetwork.find_route), puis
##   jusqu'au bâtiment d'arrivée. Mis en cache par paire de bâtiments.
## - Clic sur un passant : Population.person_clicked.

const MAX_AGENTS := 300
## Temps maximal par image pour faire apparaître de nouveaux passants (µs) : quand
## beaucoup partent en même temps, les suivants apparaissent aux images d'après.
const BUDGET_US := 3000
const SIDEWALK := 1.2
const LANE := 1.7
## Place de stationnement : à cette distance de l'axe de la voie, côté bâtiment.
const PARKING := 2.6
## Distance à la caméra en deçà de laquelle on voit les personnages détaillés,
## les portes et les scènes de sortie et d'arrivée (m).
const LOD_PROCHE := 110.0
const MAX_PROCHES := 90
const MAX_SCENES := 40
const MAX_GAREES := 120
## Vitesse de marche dans les scènes de porte (m par seconde visible).
const MARCHE := 1.5
## Temps (visible) pour finir un trajet que l'horloge a déjà terminé.
const RATTRAPAGE := 0.8
## Au-delà de ce retard sur l'horloge (heures de jeu), on ne joue plus l'arrivée.
const RETARD_MAX := 1.0
## Une sortie n'est jouée que si le trajet a commencé il y a moins de ça (heures).
const SORTIE_MAX := 0.3

var pop: Population
## pid → passant :
##   body : nœud visible (personnage, voiture ou vélo) ; walker / veh : les deux
##   mode : "pied" | "voiture" | "velo" | "tc" ; from, to : bâtiments ; t0, t1, day
##   itin : itinéraire (_itin) ; phase : "sortie" | "route" | "entree"
##   q : avancement du trajet (0 → 1) ; hs : heure de fin de la sortie
##   vp, vd, vs : chemin, distances et avancée de la scène en cours ; vt : attente
##   proche : personnage détaillé ; fini : l'horloge a terminé le trajet
var agents: Dictionary = {}
## pid → {node, bid} : voitures garées devant le bâtiment où se trouve l'habitant.
var garees: Dictionary = {}
var portes: Portes
var _routes: Dictionary = {}
var _itins: Dictionary = {}
## bid → [mesh, Rect2 des murs] ; mesh → Rect2 local des murs (sommets à plus de 0,8 m).
var _murs_cache: Dictionary = {}
var _murs_mesh: Dictionary = {}
## Demi-largeurs des voies le long du dernier tracé de _road_path (un par point).
var _hw := PackedFloat32Array()
var _plans: Dictionary = {}
var _cur: Dictionary = {}
## Revue des candidats : ceux en trajet, heure du prochain changement, état vu.
var _actifs: Array = []
## Minute de la journée → habitants dont le moment change à cette minute.
var _wake: Dictionary = {}
var _retry: Array = []
var _scan_day := -1
var _scan_inc := -2
var _scan_cand: Array = []
var _rescan := true
var _cand: Array = []
var _cand_timer := 0.0
var _net_sig := -1
var _material: StandardMaterial3D
var _meshes: Dictionary = {}
var _h := 0.0
var _day := 0
## Compteurs de l'image (recalculés au début de _update) : scènes, personnages détaillés.
var _n_scenes := 0
var _n_proches := 0
## Affichage actif (désactivé dans certains tests ou si le joueur le coupe).
var enabled := true


func setup(p: Population) -> void:
	pop = p
	_material = StandardMaterial3D.new()
	_material.vertex_color_use_as_albedo = true
	_material.roughness = 0.85
	portes = Portes.new()
	portes.name = "Portes"
	add_child(portes)


func clear() -> void:
	for pid in agents:
		_liberer(agents[pid])
	agents.clear()
	for pid in garees:
		(garees[pid].node as Node).queue_free()
	garees.clear()
	if portes != null:
		portes.vider()
	_plans.clear()
	_cur.clear()
	_actifs.clear()
	_wake.clear()
	_retry.clear()
	_rescan = true
	_routes.clear()
	_itins.clear()
	_murs_cache.clear()
	_cand.clear()
	_n_scenes = 0
	_n_proches = 0


## L'emploi du temps d'un habitant a changé (ordre donné, déménagement…).
func forget(pid: int) -> void:
	_plans.erase(pid)
	_cur.erase(pid)
	_rescan = true


## Passants dessinés dans ce mode ("voiture", "velo" : véhicules qui roulent ;
## "pied" : personnes à pied, y compris celles qui sortent ou entrent).
func count_mode(kind: String) -> int:
	var n := 0
	for pid in agents:
		var a: Dictionary = agents[pid]
		var b: Node3D = a.body
		if b == null or not b.visible:
			continue
		if kind == "pied":
			if b == a.walker:
				n += 1
		elif b == a.veh and String(a.mode) == kind:
			n += 1
	return n


## Nombre de scènes de porte en cours (sorties et arrivées).
func scenes() -> int:
	var n := 0
	for pid in agents:
		if String(agents[pid].phase) != "route":
			n += 1
	return n


func proches() -> int:
	var n := 0
	for pid in agents:
		if bool(agents[pid].proche):
			n += 1
	return n


func _process(delta: float) -> void:
	if pop == null:
		return
	if not enabled:
		if not agents.is_empty() or not garees.is_empty():
			clear()
		return
	_cand_timer -= delta
	if _cand_timer <= 0.0:
		_cand_timer = 0.5
		_collect()
	_update()
	var dt := EchelleTemps.dt(delta)
	_animer(dt)
	portes.avancer(dt)


func _focus() -> Vector3:
	if pop.rig != null:
		return pop.rig.global_position
	var cam := get_viewport().get_camera_3d()
	return cam.global_position if cam != null else Vector3.ZERO


func _cam_pos() -> Vector3:
	var cam := get_viewport().get_camera_3d()
	return cam.global_position if cam != null else _focus()


func _radius() -> float:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return 400.0
	return clampf((cam.global_position - _focus()).length() * 2.5, 150.0, 700.0)


## Habitants qui vivent, travaillent ou étudient près de la caméra : les bâtiments
## les plus proches d'abord (trois anneaux), pour que le plafond MAX_AGENTS garde
## ceux qu'on voit le mieux.
func _collect() -> void:
	var tr := pop.transport
	if tr != null:
		var sig := tr.network.next_id * 100003 + tr.network.edges.size()
		if sig != _net_sig:
			_net_sig = sig
			_routes.clear()
			_itins.clear()
	if pop.known.size() != _murs_cache.get(-1, -1):
		# Bâtiments ajoutés ou démolis : murs et itinéraires à revoir.
		_murs_cache.clear()
		_itins.clear()
		_murs_cache[-1] = pop.known.size()
	var o := _focus()
	var r := _radius()
	var cam := _cam_pos()
	var rings := [[], [], []]
	for bid in pop.known:
		var p: Vector3 = pop.known[bid].pos
		var d := Vector2(p.x - o.x, p.z - o.z).length()
		if d > r:
			continue
		var dc := p.distance_to(cam)
		rings[0 if dc < LOD_PROCHE else (1 if d < r * 0.5 else 2)].append(bid)
	var seen := {}
	var out := []
	for ring in rings:
		for bid in ring:
			for hid in pop.by_home.get(bid, []):
				for m in pop.households[hid].m:
					if not seen.has(m):
						seen[m] = true
						out.append(m)
			for m in pop.by_job.get(bid, []):
				if not seen.has(m):
					seen[m] = true
					out.append(m)
			for m in pop.by_school.get(bid, []):
				if not seen.has(m):
					seen[m] = true
					out.append(m)
			if out.size() > 2000:
				break
		if out.size() > 2000:
			break
	var f := pop.followed()
	if f >= 0 and not seen.has(f):
		out.append(f)
	_cand = out
	_trier_garees(o, r)
	_niveaux(cam)


## Voitures garées trop loin de la caméra, ou dont le conducteur est reparti : rangées.
func _trier_garees(o: Vector3, r: float) -> void:
	for pid in garees.keys():
		var g: Dictionary = garees[pid]
		var p: Vector3 = (g.node as Node3D).global_position
		if Vector2(p.x - o.x, p.z - o.z).length() > r * 1.2 or not pop.persons.has(pid):
			(g.node as Node).queue_free()
			garees.erase(pid)


## Change le niveau de détail des passants qui s'approchent ou s'éloignent (en route).
func _niveaux(cam: Vector3) -> void:
	var n := proches()
	var faits := 0
	for pid in agents:
		var a: Dictionary = agents[pid]
		if String(a.phase) != "route" or a.walker == null or faits >= 12:
			continue
		var p := (a.body as Node3D).global_position
		var veut := p.distance_to(cam) < LOD_PROCHE * 1.1
		if veut == bool(a.proche) or (veut and n >= MAX_PROCHES):
			continue
		var vis := (a.walker as Node3D).visible
		var tr := (a.walker as Node3D).transform
		var est_body: bool = a.body == a.walker
		(a.walker as Node).queue_free()
		a.proche = veut
		a.walker = _creer_marcheur(pid, veut)
		(a.walker as Node3D).transform = tr
		(a.walker as Node3D).visible = vis
		if est_body:
			a.body = a.walker
		n += 1 if veut else -1
		faits += 1


func _plan_of(pid: int, n: Dictionary) -> Array:
	var c: Array = _plans.get(pid, [])
	if not c.is_empty() and int(c[0]) == int(n.day):
		return c[1]
	var plan := _avec_trajets(pop.persons[pid], pop.day_plan(pop.persons[pid], n))
	_plans[pid] = [int(n.day), plan]
	return plan


## Les courses, le sport, les loisirs… s'enchaînent dans l'emploi du temps sans
## trajet écrit (on passe de « À la maison » à « Fait les courses ») : pour qu'on
## voie l'habitant y aller et en revenir, le début du moment suivant devient un
## trajet visible (durée de Population.commute, au plus la moitié du moment).
## Seul l'affichage change : l'emploi du temps de la simulation reste le même.
func _avec_trajets(p: Dictionary, plan: Array) -> Array:
	var out := []
	var prev := -1
	var prev_kind := ""
	for seg in plan:
		var bid := int(seg[3])
		var kind := String(seg[2])
		if out.size() > 0 and kind != "trajet" and prev_kind != "trajet" and bid >= 0 and prev >= 0 and bid != prev \
				and pop.known.has(bid) and pop.known.has(prev):
			var c := pop.commute(p, prev, bid)
			var t0 := float(seg[0])
			var t1 := float(seg[1])
			var dur := minf(maxf(float(c.min), 2.0) / 60.0, (t1 - t0) * 0.5)
			if dur > 0.01:
				out.append([t0, t0 + dur, "trajet", bid, "En route %s" % String(c.mode)])
				var rest: Array = (seg as Array).duplicate()
				rest[0] = t0 + dur
				out.append(rest)
				prev = bid
				prev_kind = kind
				continue
		out.append(seg)
		if bid >= 0:
			prev = bid
		prev_kind = kind
	return out


func _update() -> void:
	var t0 := Time.get_ticks_usec()
	var n := pop.now()
	var h: float = n.h
	var day := int(n.day)
	_h = h
	_day = day
	_n_scenes = 0
	_n_proches = 0
	for pid in agents:
		if String(agents[pid].phase) != "route":
			_n_scenes += 1
		if bool(agents[pid].proche):
			_n_proches += 1
	var live := {}
	var inc := pop.incarnated()
	var minute := floori(h * 60.0)
	# Revue complète des candidats quand ils changent (toutes les 0,5 s), au changement
	# de jour, ou après un ordre ; sinon, seuls ceux qui sont en trajet et ceux dont le
	# moment de la journée se termine maintenant sont regardés.
	var full := _rescan or day != _scan_day or inc != _scan_inc or not is_same(_scan_cand, _cand)
	var liste: Array
	if full:
		liste = _cand
		_wake.clear()
		_rescan = false
		_scan_day = day
		_scan_inc = inc
		_scan_cand = _cand
	else:
		liste = _actifs.duplicate()
		liste.append_array(_retry)
		for m in _wake.keys():
			if int(m) <= minute:
				liste.append_array(_wake[m])
				_wake.erase(m)
	_retry = []
	var actifs: Array = []
	var vus := {}
	for pid in liste:
		if vus.has(pid):
			continue
		vus[pid] = true
		if live.size() >= MAX_AGENTS:
			# Beaucoup de monde : les suivants seront vus lors d'une revue complète.
			_rescan = true
			break
		if not pop.persons.has(pid) or inc == pid:
			continue
		var over := Time.get_ticks_usec() - t0 > BUDGET_US
		var c: Array = _plans.get(pid, [])
		if over and (c.is_empty() or int(c[0]) != day):
			# Plan du jour pas encore calculé : à une prochaine image.
			if agents.has(pid):
				live[pid] = true
				actifs.append(pid)
			else:
				_retry.append(pid)
			continue
		# Moment de la journée en cours : [jour, plan, début, fin, de, vers, mode] (gardé
		# tant que l'heure reste dans ce moment, sinon recherché dans le plan du jour).
		var cur: Array = _cur.get(pid, [])
		var plan := _plan_of(pid, n)
		if cur.is_empty() or int(cur[0]) != day or not is_same(cur[1], plan) or h < float(cur[2]) or h >= float(cur[3]):
			cur = []
			var debut := INF
			for i in plan.size():
				var seg: Array = plan[i]
				if h < float(seg[0]) or h >= float(seg[1]):
					if float(seg[0]) > h:
						debut = minf(debut, float(seg[0]))
					continue
				if String(seg[2]) == "trajet" and i > 0:
					cur = [day, plan, float(seg[0]), float(seg[1]), int(plan[i - 1][3]), int(seg[3]), _mode_of(String(seg[4]))]
				else:
					cur = [day, plan, float(seg[0]), float(seg[1]), -1, -1, ""]
				break
			if cur.is_empty():
				# Rien à cette heure : on regardera de nouveau au début du prochain moment.
				_cur.erase(pid)
				if debut < INF:
					_reveil(pid, debut)
				continue
			_cur[pid] = cur
		if int(cur[4]) < 0:
			_reveil(pid, float(cur[3]))
			continue
		actifs.append(pid)
		var from := int(cur[4])
		var to := int(cur[5])
		if pop.known.has(from) and pop.known.has(to) and from != to:
			var mode: String = cur[6]
			var a: Dictionary = agents.get(pid, {})
			var nouveau := a.is_empty() or int(a.from) != from or int(a.to) != to or int(a.day) != day or absf(float(a.t0) - float(cur[2])) > 0.001
			if nouveau and Time.get_ticks_usec() - t0 > BUDGET_US:
				# Trop de départs à la fois : il apparaîtra à une prochaine image.
				if not a.is_empty():
					live[pid] = true
			else:
				if nouveau:
					_nouveau(pid, from, to, mode, float(cur[2]), float(cur[3]), day, h)
				else:
					a.fini = false
				live[pid] = true
	_actifs = actifs
	for pid in agents.keys():
		if live.has(pid):
			continue
		var a: Dictionary = agents[pid]
		# Trajet terminé à l'horloge : on laisse le passant finir son arrivée s'il est
		# près de la caméra et pas trop en retard ; sinon il disparaît.
		var retard := h - float(a.t1) if int(a.day) == day else INF
		var garder := String(a.phase) != "route" or (bool(a.proche) and retard < RETARD_MAX)
		if garder and pop.persons.has(pid) and pid != inc:
			a.fini = true
		else:
			_liberer(a)
			agents.erase(pid)


## À regarder de nouveau quand l'horloge atteint l'heure h (au plus tard à la minute).
func _reveil(pid: int, h: float) -> void:
	var m := floori(h * 60.0)
	if not _wake.has(m):
		_wake[m] = []
	(_wake[m] as Array).append(pid)


static func _mode_of(text: String) -> String:
	if text.contains("voiture"):
		return "voiture"
	if text.contains("vélo"):
		return "velo"
	if text.contains(" en ") and not text.contains("pied"):
		# « En route en bus (Ligne 1) », « Rentre en tram (…) »…
		return "tc"
	return "pied"


# --- Création ----------------------------------------------------------------------

func _nouveau(pid: int, from: int, to: int, mode: String, t0: float, t1: float, day: int, h: float) -> void:
	var old: Dictionary = agents.get(pid, {})
	if not old.is_empty():
		_liberer(old)
		agents.erase(pid)
	var itin := _itin(from, to, mode)
	var cam := _cam_pos()
	var depart: Vector3 = pop.known[from].pos
	var proche := depart.distance_to(cam) < LOD_PROCHE and _n_proches < MAX_PROCHES
	if pid == pop.followed() and depart.distance_to(cam) < LOD_PROCHE * 2.0:
		proche = true
	var a := {"mode": String(itin.mode), "from": from, "to": to, "t0": t0, "t1": t1, "day": day,
		"itin": itin, "phase": "route", "q": 0.0, "hs": t0, "vp": PackedVector3Array(), "vd": PackedFloat32Array(),
		"vs": 0.0, "vt": 0.0, "proche": proche, "fini": false, "walker": null, "veh": null, "body": null, "age": 0.0}
	if String(itin.mode) in ["voiture", "velo"]:
		var g: Dictionary = garees.get(pid, {})
		if not g.is_empty() and String(itin.mode) == "voiture":
			# Sa voiture était garée devant : c'est elle qui repart.
			a.veh = g.node
			garees.erase(pid)
		else:
			var m3 := MeshInstance3D.new()
			m3.material_override = _material
			m3.mesh = _mesh_for(pid, String(itin.mode))
			m3.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(m3)
			a.veh = m3
	elif garees.has(pid):
		(garees[pid].node as Node).queue_free()
		garees.erase(pid)
	if proche:
		_n_proches += 1
	if String(itin.mode) != "voiture" or proche:
		a.walker = _creer_marcheur(pid, proche)
	# Sortie jouée si on le voit de près et que le trajet vient de commencer.
	if proche and h - t0 < SORTIE_MAX and _n_scenes < MAX_SCENES and not (itin.sortie as PackedVector3Array).is_empty():
		a.phase = "sortie"
		_n_scenes += 1
		_scene(a, itin.sortie)
		var cadre: Dictionary = itin.cadre_a
		portes.ouvrir(from, cadre, 1.0)
		a.body = a.walker
		if a.veh != null:
			_poser_vehicule(a, 0.0)
	else:
		a.body = a.veh if a.veh != null else a.walker
	if a.walker != null:
		(a.walker as Node3D).visible = a.body == a.walker
	agents[pid] = a
	_placer(pid, a, 0.0)


func _creer_marcheur(pid: int, proche: bool) -> Node3D:
	var mi: Node3D
	if proche and Silhouettes.disponible():
		# Personnage arrondi, avec l'apparence de l'habitant.
		mi = Silhouettes.pour_habitant(pop, pid)
	else:
		var m3 := MeshInstance3D.new()
		m3.material_override = _material
		m3.mesh = _mesh_for(pid, "pied")
		m3.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi = m3
	add_child(mi)
	return mi


func _scene(a: Dictionary, chemin: PackedVector3Array) -> void:
	a.vp = chemin
	a.vd = _cumul(chemin)
	a.vs = 0.0
	a.vt = 0.0


func _liberer(a: Dictionary) -> void:
	if a.walker != null and is_instance_valid(a.walker):
		(a.walker as Node).queue_free()
	if a.veh != null and is_instance_valid(a.veh):
		(a.veh as Node).queue_free()
	a.walker = null
	a.veh = null


# --- Animation ---------------------------------------------------------------------

func _animer(dt: float) -> void:
	for pid in agents.keys():
		var a: Dictionary = agents[pid]
		if a.body == null or not is_instance_valid(a.body):
			_liberer(a)
			agents.erase(pid)
			continue
		if not _placer(pid, a, dt):
			_finir(pid, a)


## Avance et place un passant. Renvoie false quand il a fini (entré dans le bâtiment).
func _placer(pid: int, a: Dictionary, dt: float) -> bool:
	match String(a.phase):
		"sortie":
			if _marcher_scene(a, dt, int(a.from), a.itin.cadre_a):
				# Arrivé au trottoir, à sa voiture, à son vélo : en route.
				if a.veh != null:
					a.vt = float(a.vt) + dt
					if float(a.vt) < 0.45:
						# Le temps d'ouvrir la portière, de monter, d'enfourcher le vélo.
						return true
					(a.walker as Node3D).visible = false
					a.body = a.veh
				a.phase = "route"
				a.hs = clampf(_h if int(a.day) == _day else float(a.t1), float(a.t0), float(a.t1))
				a.q = 0.0
			return true
		"entree":
			if a.vt > 0.0 and a.veh != null:
				# Il coupe le moteur et descend.
				a.vt = float(a.vt) - dt
				return true
			if a.walker != null and not (a.walker as Node3D).visible:
				(a.walker as Node3D).visible = true
				a.body = a.walker
				if a.veh != null:
					_garer(pid, a)
			a.age = float(a.age) + dt
			return not _marcher_scene(a, dt, int(a.to), a.itin.cadre_b) and float(a.age) < 12.0
	# En route : l'horloge mène ; une fois le trajet fini à l'horloge, il rattrape.
	var q_horloge := 1.0
	if int(a.day) == _day and not bool(a.fini):
		var hs := float(a.hs)
		var reste := float(a.t1) - hs
		q_horloge = clampf((_h - hs) / reste, 0.0, 1.0) if reste > 0.0001 else 1.0
	var q := float(a.q)
	if q_horloge < 1.0:
		q = maxf(q, q_horloge)
	elif dt > 0.0:
		q = minf(1.0, q + dt / RATTRAPAGE)
	a.q = q
	_poser_route(pid, a, q)
	if q >= 1.0 and (bool(a.fini) or q_horloge >= 1.0):
		return _arriver(pid, a)
	return true


## Fin du trajet : la scène d'arrivée, si on la voit de près ; sinon il disparaît.
func _arriver(pid: int, a: Dictionary) -> bool:
	var entree: PackedVector3Array = a.itin.entree
	var retard := _h - float(a.t1) if int(a.day) == _day else INF
	if not bool(a.proche) or entree.is_empty() or a.walker == null or retard > RETARD_MAX or _n_scenes >= MAX_SCENES:
		return false
	a.phase = "entree"
	_n_scenes += 1
	a.age = 0.0
	_scene(a, entree)
	if a.veh != null:
		a.vt = 0.45
		_poser_vehicule(a, 1.0)
	else:
		a.vt = 0.0
		(a.walker as Node3D).visible = true
		a.body = a.walker
	return true


func _finir(pid: int, a: Dictionary) -> void:
	if String(a.phase) == "entree" and a.veh != null and garees.has(pid) and garees[pid].node == a.veh:
		a.veh = null
	_liberer(a)
	agents.erase(pid)


## La voiture reste garée devant le bâtiment d'arrivée.
func _garer(pid: int, a: Dictionary) -> void:
	if String(a.mode) != "voiture":
		(a.veh as Node3D).visible = String(a.mode) == "velo"
		return
	if garees.has(pid):
		(garees[pid].node as Node).queue_free()
		garees.erase(pid)
	if garees.size() >= MAX_GAREES:
		return
	garees[pid] = {"node": a.veh, "bid": int(a.to)}


## Avance le personnage sur le chemin de la scène ; renvoie true quand c'est fini.
func _marcher_scene(a: Dictionary, dt: float, bid: int, cadre: Dictionary) -> bool:
	var vp: PackedVector3Array = a.vp
	var vd: PackedFloat32Array = a.vd
	if vp.size() < 2 or a.walker == null:
		return true
	var total := vd[vd.size() - 1]
	a.vs = minf(total, float(a.vs) + dt * MARCHE)
	var w: Node3D = a.walker
	_suivre(w, vp, vd, float(a.vs))
	if w.has_meta("rig"):
		Silhouettes.marcher(w, float(a.vs) * 2.6, 1.0 if float(a.vs) < total else 0.0)
	if Portes.proche(cadre, w.position):
		portes.ouvrir(bid, cadre, 0.6)
	return float(a.vs) >= total


## Place un passant sur son itinéraire à l'avancement q (0 → 1).
func _poser_route(pid: int, a: Dictionary, q: float) -> void:
	var legs: Array = a.itin.legs
	var leg: Dictionary = legs[legs.size() - 1]
	for l in legs:
		if q < float(l.f1):
			leg = l
			break
	var u := clampf((q - float(leg.f0)) / maxf(float(leg.f1) - float(leg.f0), 0.0001), 0.0, 1.0)
	var kind := String(leg.kind)
	var node: Node3D = a.veh if kind == "vehicule" else a.walker
	if node == null:
		node = a.body
	if a.walker != null:
		(a.walker as Node3D).visible = node == a.walker and kind != "cache"
	if a.veh != null:
		(a.veh as Node3D).visible = node == a.veh and kind != "cache"
	a.body = node
	var path: PackedVector3Array = leg.path
	var d: PackedFloat32Array = leg.d
	if path.size() < 2:
		if path.size() == 1:
			node.position = path[0]
		return
	var s := u * d[d.size() - 1]
	if kind == "attente":
		s = 0.0
	_suivre(node, path, d, s)
	if node.has_meta("rig"):
		if kind == "attente":
			Silhouettes.repos(node)
		else:
			Silhouettes.marcher(node, s * 2.6, 1.0)
	# Le marcheur suivi est un peu plus grand, pour le repérer.
	node.scale = Vector3.ONE * (1.4 if pid == pop.followed() else 1.0)


## Voiture ou vélo à l'arrêt au début (0) ou à la fin (1) de son trajet.
func _poser_vehicule(a: Dictionary, u: float) -> void:
	for l in a.itin.legs:
		if String(l.kind) == "vehicule":
			var path: PackedVector3Array = l.path
			var d: PackedFloat32Array = l.d
			if path.size() >= 2:
				_suivre(a.veh, path, d, u * d[d.size() - 1])
			(a.veh as Node3D).visible = true
			return


static func _suivre(node: Node3D, path: PackedVector3Array, d: PackedFloat32Array, s: float) -> void:
	var i := 0
	while i < d.size() - 2 and d[i + 1] < s:
		i += 1
	var seg_len := maxf(d[i + 1] - d[i], 0.0001)
	node.position = path[i].lerp(path[i + 1], clampf((s - d[i]) / seg_len, 0.0, 1.0))
	var dir := path[i + 1] - path[i]
	dir.y = 0.0
	if dir.length_squared() > 0.0001:
		node.basis = Basis.looking_at(dir.normalized(), Vector3.UP)


func _mesh_for(pid: int, mode: String) -> Mesh:
	var key := "walker_%d" % (pid % 5)
	if mode == "voiture":
		key = "car_%d" % (pid % 6)
	elif mode == "velo":
		key = "bike_%d" % (pid % 4)
	if _meshes.has(key):
		return _meshes[key]
	var m: Mesh = null
	if pop.transport != null and pop.transport.traffic != null:
		m = pop.transport.traffic._mesh(key)
	if m == null:
		var b := BoxMesh.new()
		b.size = Vector3(0.5, 1.7, 0.4)
		m = b
	_meshes[key] = m
	return m


# --- Itinéraires --------------------------------------------------------------------

## Itinéraire complet d'un trajet, en cache :
##   mode, legs : [{f0, f1, kind: "marche" | "vehicule" | "attente" | "cache", path, d}]
##   (fractions du trajet), sortie / entree : chemins des scènes de porte,
##   cadre_a / cadre_b : portes de départ et d'arrivée (_cadre).
func _itin(from: int, to: int, mode: String) -> Dictionary:
	var key := "%d>%d>%s" % [from, to, mode]
	if _itins.has(key):
		return _itins[key]
	var a: Vector3 = pop.known[from].pos
	var b: Vector3 = pop.known[to].pos
	var res := {}
	if mode == "tc":
		res = _itin_tc(from, to, a, b)
	if res.is_empty():
		if mode == "tc":
			mode = "pied"
		var raw := _road_raw(a, b)
		var hw := _hw
		if raw.size() < 2:
			# Pas de voie : en ligne droite d'une porte à l'autre.
			var ca := _cadre(from, b)
			var cb := _cadre(to, a)
			var p := PackedVector3Array([ca.dehors, cb.dehors])
			res = {"mode": "pied" if mode == "voiture" else mode, "cadre_a": ca, "cadre_b": cb,
				"legs": [_leg(0.0, 1.0, "vehicule" if mode == "velo" else "marche", p)],
				"sortie": _seuil(ca, ca.dehors, false), "entree": _seuil(cb, cb.dehors, true)}
		elif mode == "pied":
			var road := _offset_var(raw, hw, SIDEWALK, 0.8)
			var ca := _cadre(from, road[0])
			var cb := _cadre(to, road[road.size() - 1])
			res = {"mode": "pied", "cadre_a": ca, "cadre_b": cb, "legs": [_leg(0.0, 1.0, "marche", road)],
				"sortie": _seuil(ca, road[0], false), "entree": _seuil(cb, road[road.size() - 1], true)}
		else:
			# Voiture ou vélo garé au bord de la voie, côté bâtiment.
			var lane := _offset(raw, LANE)
			var ca := _cadre(from, raw[0])
			var cb := _cadre(to, raw[raw.size() - 1])
			var pa := _place(raw, 0, ca.dehors, hw[0])
			var pb := _place(raw, raw.size() - 1, cb.dehors, hw[hw.size() - 1])
			var path := PackedVector3Array([pa])
			path.append_array(lane)
			path.append(pb)
			var cote_a: Vector3 = pa + _vers(pa, ca.dehors) * 1.3
			var cote_b: Vector3 = pb + _vers(pb, cb.dehors) * 1.3
			res = {"mode": mode, "cadre_a": ca, "cadre_b": cb, "legs": [_leg(0.0, 1.0, "vehicule", path)],
				"sortie": _seuil(ca, cote_a, false), "entree": _seuil(cb, cote_b, true)}
	_itins[key] = res
	return res


## En bus, tram, train : à pied jusqu'à l'arrêt, attente, trajet en ligne (caché),
## à pied depuis l'arrêt d'arrivée. Durées d'après TransitPlanner.
func _itin_tc(from: int, to: int, a: Vector3, b: Vector3) -> Dictionary:
	var tc := pop._transit_between(a, b)
	if tc.is_empty() or not tc.has("trip"):
		return {}
	var legs_tp: Array = (tc.trip as Dictionary).get("legs", [])
	if legs_tp.size() < 3:
		return {}
	var secs := []
	var total := 0.0
	for l in legs_tp:
		var s := float(l.get("s", 0.0)) if String(l.type) == "marche" else float(l.get("wait_s", 0.0)) + float(l.get("ride_s", 0.0))
		secs.append(maxf(s, 1.0))
		total += maxf(s, 1.0)
	var first: Dictionary = legs_tp[0]
	var last: Dictionary = legs_tp[legs_tp.size() - 1]
	var arret_a: Vector3 = first.to
	var arret_b: Vector3 = last.from
	var w1 := _road_raw(a, arret_a)
	w1 = _offset_var(w1, _hw, SIDEWALK, 0.8) if w1.size() >= 2 else PackedVector3Array([a, arret_a])
	var w2 := _road_raw(arret_b, b)
	w2 = _offset_var(w2, _hw, SIDEWALK, 0.8) if w2.size() >= 2 else PackedVector3Array([arret_b, b])
	w1.append(arret_a)
	w2.insert(0, arret_b)
	var ca := _cadre(from, w1[0])
	var cb := _cadre(to, w2[w2.size() - 1])
	var legs := []
	var f := 0.0
	var f1 := float(secs[0]) / total
	legs.append(_leg(0.0, f1, "marche", w1))
	f = f1
	var ligne: Dictionary = legs_tp[1]
	if String(ligne.type) == "ligne":
		var attente := clampf(float(ligne.get("wait_s", 0.0)) / total, 0.0, 1.0 - f)
		legs.append(_leg(f, f + attente, "attente", PackedVector3Array([arret_a + _vers(arret_a, w1[maxi(0, w1.size() - 2)]) * 1.5])))
		f += attente
	var f_fin := 1.0 - float(secs[secs.size() - 1]) / total
	legs.append(_leg(f, maxf(f, f_fin), "cache", PackedVector3Array()))
	legs.append(_leg(maxf(f, f_fin), 1.0, "marche", w2))
	return {"mode": "tc", "cadre_a": ca, "cadre_b": cb, "legs": legs,
		"sortie": _seuil(ca, w1[0], false), "entree": _seuil(cb, w2[w2.size() - 1], true)}


static func _leg(f0: float, f1: float, kind: String, path: PackedVector3Array) -> Dictionary:
	return {"f0": f0, "f1": f1, "kind": kind, "path": path, "d": _cumul(path)}


static func _cumul(pts: PackedVector3Array) -> PackedFloat32Array:
	var d := PackedFloat32Array()
	d.resize(pts.size())
	var acc := 0.0
	for i in pts.size():
		if i > 0:
			acc += pts[i].distance_to(pts[i - 1])
		d[i] = acc
	return d


static func _vers(de: Vector3, vers: Vector3) -> Vector3:
	var v := vers - de
	v.y = 0.0
	return v.normalized() if v.length_squared() > 1e-6 else Vector3.ZERO


## Place de stationnement au bord de la voie (point i du tracé), côté bâtiment.
static func _place(raw: PackedVector3Array, i: int, cote: Vector3, demi := 0.0) -> Vector3:
	var j := i + 1 if i + 1 < raw.size() else i - 1
	var t := raw[j] - raw[i]
	t.y = 0.0
	if t.length_squared() < 1e-6:
		return raw[i]
	t = t.normalized()
	var nrm := Vector3(-t.z, 0.0, t.x)
	var c := cote - raw[i]
	if nrm.dot(c) < 0.0:
		nrm = -nrm
	return raw[i] + nrm * maxf(PARKING, demi - 1.1)


## Chemin de la scène de porte : de l'intérieur au seuil, devant la porte, au bord
## de la parcelle (jardin, parking) puis jusqu'à rue (sortie), ou l'inverse (entree).
static func _seuil(cadre: Dictionary, rue: Vector3, entree: bool) -> PackedVector3Array:
	var pts := PackedVector3Array([cadre.dedans, cadre.face, cadre.dehors])
	var bord: Vector3 = cadre.get("bord", cadre.dehors)
	if bord.distance_to(cadre.dehors) > 0.5:
		pts.append(bord)
	if rue.distance_to(pts[pts.size() - 1]) > 0.05:
		pts.append(rue)
	if entree:
		pts.reverse()
	return pts


## Chemin entre deux bâtiments : {path: PackedVector3Array, d: distances cumulées}.
func route_between(from: int, to: int, mode := "pied") -> Dictionary:
	var key := "%d>%d>%s" % [from, to, mode]
	if _routes.has(key):
		return _routes[key]
	var a: Vector3 = pop.known[from].pos
	var b: Vector3 = pop.known[to].pos
	var pts := PackedVector3Array()
	var side := SIDEWALK if mode == "pied" else LANE
	var road := _road_raw(a, b)
	if road.size() >= 2:
		road = _offset(road, side)
		# On sort par la façade qui donne sur la voie, pas du milieu du bâtiment.
		pts.append(_door(from, road[0]))
		pts.append_array(road)
		pts.append(_door(to, road[road.size() - 1]))
	else:
		pts.append(_door(from, b))
		pts.append(_door(to, a))
	var res := {"path": pts, "d": _cumul(pts)}
	_routes[key] = res
	return res


## Tracé brut (axe des voies) entre deux points, vide sans voie proche.
func _road_raw(a: Vector3, b: Vector3) -> PackedVector3Array:
	_hw = PackedFloat32Array()
	var net: TransportNetwork = pop.transport.network if pop.transport != null else null
	if net == null:
		return PackedVector3Array()
	var sa := net.find_snap(a, TransportTypes.Mode.ROAD, 80.0)
	var sb := net.find_snap(b, TransportTypes.Mode.ROAD, 80.0)
	if sa.is_empty() or sb.is_empty():
		return PackedVector3Array()
	var out := _road_path(net, sa, sb, a, b)
	if _hw.size() != out.size():
		_hw.resize(out.size())
		_hw.fill(LANE + 1.0)
	return out


## Point du bord d'un bâtiment le plus proche de p (sa porte, à peu près).
func _door(bid: int, p: Vector3) -> Vector3:
	var info: Dictionary = pop.known[bid]
	var c: Vector3 = info.pos
	if not info.has("rect"):
		return c
	var r: Rect2i = info.rect
	var x := clampf(p.x, float(r.position.x) - 0.6, float(r.end.x) + 0.6)
	var z := clampf(p.z, float(r.position.y) - 0.6, float(r.end.y) + 0.6)
	# Un point dans le rectangle (bâtiment collé à la voie) : on prend le bord le plus proche.
	if Rect2(r).grow(0.5).has_point(Vector2(x, z)):
		var dl := x - r.position.x
		var dr := r.end.x - x
		var dt := z - r.position.y
		var db := r.end.y - z
		var m := minf(minf(dl, dr), minf(dt, db))
		if m == dl:
			x = r.position.x - 0.6
		elif m == dr:
			x = r.end.x + 0.6
		elif m == dt:
			z = r.position.y - 0.6
		else:
			z = r.end.y + 0.6
	return Vector3(x, p.y, z)


## Porte d'un bâtiment, sur la façade qui regarde p :
##   face : milieu du seuil (sur le mur), n : normale vers l'extérieur,
##   dehors : 0,6 m devant, dedans : 0,9 m derrière (caché par le bâtiment),
##   bord : sortie de la parcelle (jardin, parking) dans l'axe de la porte,
##   porte : false pour un bâtiment tourné en biais (pas de vantail dessiné).
func _cadre(bid: int, p: Vector3) -> Dictionary:
	var info: Dictionary = pop.known[bid]
	var c: Vector3 = info.pos
	var y := c.y
	if not info.has("rect"):
		return {"face": c, "n": Vector3.FORWARD, "dehors": c, "dedans": c, "bord": c, "porte": false}
	var lot := Rect2(info.rect)
	var murs := _murs(bid, lot)
	var x0 := murs.position.x
	var x1 := murs.end.x
	var z0 := murs.position.y
	var z1 := murs.end.y
	var x := clampf(p.x, x0, x1)
	var z := clampf(p.z, z0, z1)
	var dehors_x := p.x < x0 or p.x > x1
	var dehors_z := p.z < z0 or p.z > z1
	var n := Vector3.ZERO
	if dehors_x and not dehors_z:
		n = Vector3.LEFT if p.x < x0 else Vector3.RIGHT
	elif dehors_z and not dehors_x:
		n = Vector3.FORWARD if p.z < z0 else Vector3.BACK
	elif dehors_x and dehors_z:
		# En diagonale : la façade face à p.
		if absf(p.x - x) > absf(p.z - z):
			n = Vector3.LEFT if p.x < x0 else Vector3.RIGHT
		else:
			n = Vector3.FORWARD if p.z < z0 else Vector3.BACK
	else:
		# p dans le bâtiment : le mur le plus proche.
		var dl := p.x - x0
		var dr := x1 - p.x
		var dt := p.z - z0
		var db := z1 - p.z
		var m := minf(minf(dl, dr), minf(dt, db))
		n = Vector3.LEFT if m == dl else (Vector3.RIGHT if m == dr else (Vector3.FORWARD if m == dt else Vector3.BACK))
	# Seuil : sur le mur, à au moins 0,8 m des angles.
	if n.x != 0.0:
		x = x0 if n.x < 0.0 else x1
		z = clampf(z, z0 + 0.8, z1 - 0.8) if z1 - z0 > 1.6 else (z0 + z1) * 0.5
	else:
		z = z0 if n.z < 0.0 else z1
		x = clampf(x, x0 + 0.8, x1 - 0.8) if x1 - x0 > 1.6 else (x0 + x1) * 0.5
	var face := Vector3(x, y, z)
	var dehors := face + n * 0.6
	# Bord de la parcelle dans l'axe de la porte (jardin, parking devant le bâtiment).
	var bord := dehors
	if n.x < 0.0:
		bord.x = minf(dehors.x, lot.position.x - 0.4)
	elif n.x > 0.0:
		bord.x = maxf(dehors.x, lot.end.x + 0.4)
	elif n.z < 0.0:
		bord.z = minf(dehors.z, lot.position.y - 0.4)
	else:
		bord.z = maxf(dehors.z, lot.end.y + 0.4)
	var biais := false
	if pop.buildings != null and pop.buildings.buildings.has(bid):
		var ang := fmod(absf(float(pop.buildings.buildings[bid].get("a", 0.0))), 90.0)
		biais = ang > 1.0 and ang < 89.0
	return {"face": face, "n": n, "dehors": dehors, "dedans": face - n * 0.9, "bord": bord, "porte": not biais and not info.has("plan")}


## Emprise des murs d'un bâtiment (sans le jardin ni le parking de sa parcelle) :
## les sommets de son modèle à plus de 0,8 m du sol. À défaut, la parcelle.
func _murs(bid: int, lot: Rect2) -> Rect2:
	var bs := pop.buildings
	if bs == null or not bs._nodes.has(bid):
		return lot
	var mi := bs._nodes[bid] as MeshInstance3D
	if mi == null or not is_instance_valid(mi) or mi.mesh == null:
		return lot
	var c: Array = _murs_cache.get(bid, [])
	if not c.is_empty() and c[0] == mi.mesh and c[2] == mi.global_transform:
		return c[1]
	var loc: Variant = _murs_mesh.get(mi.mesh, null)
	if loc == null:
		loc = _murs_locaux(mi.mesh)
		_murs_mesh[mi.mesh] = loc
	var res := lot
	if loc is AABB:
		var box: AABB = mi.global_transform * (loc as AABB)
		var r := Rect2(box.position.x, box.position.z, box.size.x, box.size.z)
		# Le modèle doit tenir dans sa parcelle (à 1 m près) et y faire au moins 1,5 m.
		if lot.grow(1.0).encloses(r) and r.size.x >= 1.5 and r.size.y >= 1.5:
			res = r
	_murs_cache[bid] = [mi.mesh, res, mi.global_transform]
	return res


static func _murs_locaux(mesh: Mesh) -> Variant:
	var lo := INF
	for i in mesh.get_surface_count():
		var v: PackedVector3Array = mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX]
		var pas := maxi(1, v.size() / 4000)
		for k in range(0, v.size(), pas):
			lo = minf(lo, v[k].y)
	if lo == INF:
		return null
	var box := AABB()
	var vide := true
	for i in mesh.get_surface_count():
		var v: PackedVector3Array = mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX]
		# Échantillon (au plus ~4 000 sommets par surface) : calcul fait une fois par modèle.
		var pas := maxi(1, v.size() / 4000)
		for k in range(0, v.size(), pas):
			var q := v[k]
			if q.y > lo + 0.8:
				if vide:
					box = AABB(q, Vector3.ZERO)
					vide = false
				else:
					box = box.expand(q)
	return null if vide else box


## Tracé sur les voies entre deux accroches (nœud ou point d'un tronçon).
## Remplit aussi _hw : la demi-largeur de la voie en chaque point.
func _road_path(net: TransportNetwork, sa: Dictionary, sb: Dictionary, a: Vector3, b: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array()
	_hw = PackedFloat32Array()
	var ea := int(sa.edge)
	var eb := int(sb.edge)
	if ea >= 0 and ea == eb:
		_ajouter(out, _edge_part(net, ea, float(sa.s), float(sb.s)), net.half_width(ea), false)
		return out
	# Nœuds de départ et d'arrivée sur le réseau.
	var na := int(sa.node)
	var nb := int(sb.node)
	var starts := [na] if na >= 0 else [int(net.edges[ea].a), int(net.edges[ea].b)]
	var ends := [nb] if nb >= 0 else [int(net.edges[eb].a), int(net.edges[eb].b)]
	var best: Array[int] = []
	var best_cost := INF
	var best_pair := [-1, -1]
	for s in starts:
		for e in ends:
			var r: Array[int] = []
			if s != e:
				r = net.find_route(s, e)
				if r.is_empty():
					continue
			var cost := 0.0
			for eid in r:
				cost += float(net.edges[eid].len)
			cost += Vector2(net.node_pos(s).x - a.x, net.node_pos(s).z - a.z).length()
			cost += Vector2(net.node_pos(e).x - b.x, net.node_pos(e).z - b.z).length()
			if cost < best_cost:
				best_cost = cost
				best = r
				best_pair = [s, e]
	if best_pair[0] < 0:
		return out
	if na < 0:
		var e: Dictionary = net.edges[ea]
		_ajouter(out, _edge_part(net, ea, float(sa.s), 0.0 if int(e.a) == best_pair[0] else float(e.len)), net.half_width(ea), false)
	else:
		_ajouter(out, PackedVector3Array([net.node_pos(na)]), net.node_half_width(na), false)
	var cur: int = best_pair[0]
	for eid in best:
		var e: Dictionary = net.edges[eid]
		var forward := int(e.a) == cur
		_ajouter(out, _edge_part(net, eid, 0.0 if forward else float(e.len), float(e.len) if forward else 0.0), net.half_width(eid), true)
		cur = int(e.b) if forward else int(e.a)
	if nb < 0:
		var e: Dictionary = net.edges[eb]
		_ajouter(out, _edge_part(net, eb, 0.0 if int(e.a) == best_pair[1] else float(e.len), float(sb.s)), net.half_width(eb), true)
	return out


func _ajouter(out: PackedVector3Array, part: PackedVector3Array, demi: float, sauter_premier: bool) -> void:
	if sauter_premier and not out.is_empty() and not part.is_empty():
		part.remove_at(0)
	out.append_array(part)
	for i in part.size():
		_hw.append(demi)


## Points d'un tronçon entre les abscisses s0 et s1 (dans un sens ou l'autre).
static func _edge_part(net: TransportNetwork, eid: int, s0: float, s1: float) -> PackedVector3Array:
	var e: Dictionary = net.edges[eid]
	var d: PackedFloat32Array = e.d
	var pts: PackedVector3Array = e.pts
	var out := PackedVector3Array()
	out.append(net.point_at(eid, s0))
	if s0 <= s1:
		for i in pts.size():
			if d[i] > s0 and d[i] < s1:
				out.append(pts[i])
	else:
		for i in range(pts.size() - 1, -1, -1):
			if d[i] < s0 and d[i] > s1:
				out.append(pts[i])
	out.append(net.point_at(eid, s1))
	return out


## Décale un tracé sur sa droite (trottoir ou voie de droite).
static func _offset(pts: PackedVector3Array, dist: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	out.resize(pts.size())
	for i in pts.size():
		var a := pts[maxi(i - 1, 0)]
		var b := pts[mini(i + 1, pts.size() - 1)]
		var t := b - a
		t.y = 0.0
		if t.length_squared() < 1e-6:
			out[i] = pts[i]
			continue
		t = t.normalized()
		out[i] = pts[i] + Vector3(-t.z, 0.0, t.x) * dist
	return out


## Décale un tracé sur sa droite, au bord de chaque voie (demi-largeur + marge),
## au moins de dist_min : le trottoir, quelle que soit la largeur de la rue.
static func _offset_var(pts: PackedVector3Array, demi: PackedFloat32Array, dist_min: float, marge: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	out.resize(pts.size())
	for i in pts.size():
		var a := pts[maxi(i - 1, 0)]
		var b := pts[mini(i + 1, pts.size() - 1)]
		var t := b - a
		t.y = 0.0
		if t.length_squared() < 1e-6:
			out[i] = pts[i]
			continue
		t = t.normalized()
		var dist := maxf(dist_min, (demi[i] if i < demi.size() else 0.0) + marge)
		out[i] = pts[i] + Vector3(-t.z, 0.0, t.x) * dist
	return out


# --- Clic ---------------------------------------------------------------------------

## Habitant visible sous le pointeur (à 18 px près), ou -1.
func pick(screen: Vector2, cam: Camera3D) -> int:
	var best := -1
	var best_d := 18.0
	for pid in agents:
		var body: Node3D = agents[pid].body
		if body == null or not body.visible:
			continue
		var p := body.global_position + Vector3(0, 1.0, 0)
		if cam.is_position_behind(p):
			continue
		var d := cam.unproject_position(p).distance_to(screen)
		if d < best_d:
			best_d = d
			best = pid
	return best
