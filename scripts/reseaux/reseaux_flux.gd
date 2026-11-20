class_name ReseauxFlux
extends Node3D
## Flux des réseaux sur les routes : quand on clique sur un bâtiment (fiche),
## ou, dans la vue Réseaux (O), sur une route, une ligne ou une conduite, on voit
## le courant, l'eau, les eaux usées et le gaz circuler, en couleur, le long des
## routes et des tronçons qui les portent :
## - flèches qui avancent depuis les centrales, captages, postes de gaz vers les
##   bâtiments (et des bâtiments vers la station d'épuration pour les égouts) ;
## - bord vert : tout est servi ; bord orange et flèches lentes : réseau saturé
##   (rationné) ; bord rouge, flèches arrêtées qui clignotent : coupé ;
## - petits branchements de la route jusqu'à chaque bâtiment, de la couleur de
##   ce qu'il reçoit ;
## - un bâtiment ordinaire montre tous ses réseaux côte à côte sur la route
##   (électricité, eau, égouts, gaz) ; une centrale, son réseau ; la vue O,
##   le réseau de l'onglet. Le réseau du bâtiment choisi est en plein, les
##   autres parties du même réseau (pas reliées) en plus pâle.
## Rien n'est simulé ici : on lit le dernier calcul de ReseauBase (lignes,
## composantes, taux) et on en tire, pour le sens, la distance à la source le
## long des tracés (Dijkstra).

const RES := ["elec", "eau", "egout", "gaz"]
## Voies côte à côte quand on montre plusieurs réseaux (m, depuis l'axe de la route).
const DECALAGES := {"elec": -2.4, "eau": -0.8, "egout": 0.8, "gaz": 2.4}
const LARGEUR_VOIE := 1.5
const LARGEUR_SEULE := 3.2
## Au-delà, les tracés ne sont pas dessinés (m autour du bâtiment choisi).
const RAYON := 6000.0
const MAX_BRANCHEMENTS := 700
## Longueur maximale d'un morceau de ruban (m) : la distance est exacte à chaque bout.
const PAS := 10.0
const HAUT := 0.8
## Vitesse des flèches (m par seconde à la vitesse ×1).
const VITESSE := 16.0
const ETAT_OK := 0
const ETAT_SATURE := 1
const ETAT_COUPE := 2
const COULEUR_ETAT := [Color("52b788"), Color("f4a261"), Color("e63946")]

const SHADER := """
shader_type spatial;
render_mode unshaded, depth_test_disabled, cull_disabled, blend_mix, shadows_disabled;
uniform vec4 couleur : source_color = vec4(1.0, 0.82, 0.4, 1.0);
uniform float temps = 0.0;
uniform float sens = 1.0;
uniform float periode = 10.0;
uniform float largeur = 3.0;
void fragment() {
	float mode = UV2.x;
	float focus = UV2.y;
	float v = abs(UV.y - 0.5) * 2.0;
	float bord = smoothstep(0.6, 0.72, v);
	float vit = mode < 0.5 ? 1.0 : (mode < 1.5 ? 0.3 : 0.0);
	// Chevrons : la pointe (au centre) est en avant dans le sens du flux (vérifié en capture).
	float ph = fract((UV.x - sens * v * largeur * 0.45 - sens * temps * vit * 16.0) / periode);
	float fleche = smoothstep(0.0, 0.06, ph) * (1.0 - smoothstep(0.26, 0.34, ph));
	vec3 c = mix(couleur.rgb * 0.32, min(couleur.rgb * 1.35, vec3(1.0)), fleche);
	float a = 0.5 + 0.45 * fleche;
	if (mode > 1.5) {
		float clign = 0.5 + 0.5 * sin(TIME * 5.0);
		c = mix(c * 0.6, vec3(0.95, 0.22, 0.27), 0.35 * clign);
	}
	c = mix(c, COLOR.rgb, bord);
	a = max(a, bord * 0.95);
	ALBEDO = c;
	ALPHA = a * mix(0.4, 1.0, focus);
}
"""

var reseaux: Reseaux
## Ce qui est montré : bâtiment choisi (ou -1), réseaux, composante en avant par réseau.
var bid := -1
var reseaux_montres: Array = []
var focus := {}
var centre := Vector3.ZERO
## "batiment" ou "ligne" (clic sur une route ou un tronçon dans la vue O).
var origine := ""
## Résumé du dernier dessin, par réseau (lu par les tests et la fiche) :
## {"morceaux", "ok", "sature", "coupe", "atteints", "noeuds", "branchements"}.
var stats := {}
## Distance à la source par nœud du dernier dessin (res -> {cle: m}), pour les tests.
var distances := {}

var _mi := {}
var _mats := {}
var _shader: Shader
var _temps := 0.0
var _acc := 0.0
var _signature := ""
var _frame_ligne := -1
## Onglet de la vue O au moment du clic, et largeur des rubans selon la distance de la caméra.
var _calque_vu := ""
var _zoom := 1.0
var _acc_sig := 0


func _ready() -> void:
	_shader = Shader.new()
	_shader.code = SHADER
	for res in RES:
		var m := ShaderMaterial.new()
		m.shader = _shader
		m.render_priority = 3
		m.set_shader_parameter("couleur", ReseauxTypes.COULEURS[res])
		# Les eaux usées vont des bâtiments vers la station : flèches à l'envers.
		m.set_shader_parameter("sens", -1.0 if res == "egout" else 1.0)
		_mats[res] = m
		var mi := MeshInstance3D.new()
		mi.name = "Flux_" + res
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.material_override = m
		add_child(mi)
		_mi[res] = mi


func actif() -> bool:
	return not reseaux_montres.is_empty()


func _process(delta: float) -> void:
	if not actif():
		return
	_temps += EchelleTemps.dt(delta)
	for res in reseaux_montres:
		(_mats[res] as ShaderMaterial).set_shader_parameter("temps", _temps)
	# Montré depuis la vue O : on l'enlève quand on la quitte.
	if origine == "ligne" and reseaux != null and reseaux.vue != null and reseaux.vue.calque_actif() == "":
		effacer()
		return
	# Fiche ouverte depuis la vue O (qui se ferme) : on remontre tous les réseaux du bâtiment.
	if origine == "batiment" and reseaux.vue != null and reseaux.vue.calque_actif() != _calque_vu:
		montrer_batiment(bid)
		return
	_acc += delta
	if _acc < 0.5:
		return
	_acc = 0.0
	# Vu de loin, rubans plus larges (par paliers, pour ne pas tout refaire sans cesse).
	var z := _zoom_camera()
	if absf(z - _zoom) > 0.24:
		_zoom = z
		refaire()
		return
	if _acc_sig < 2:
		_acc_sig += 1
		return
	_acc_sig = 0
	# Nouvelle route, centrale arrêtée, réseau saturé : on redessine.
	if _sig() != _signature:
		refaire()


# --- Ce qu'on montre ---------------------------------------------------------------------

## Clic sur un bâtiment (Population.building_selected) ; -1 = plus rien de choisi.
func sur_selection(b: int) -> void:
	if b < 0:
		# Le même clic vient de montrer une route dans la vue O : on la garde.
		if origine == "ligne" and Engine.get_process_frames() == _frame_ligne:
			return
		effacer()
		return
	montrer_batiment(b)


## Réseaux d'un bâtiment : ceux qu'il alimente puis ceux qu'il consomme.
func reseaux_de(b: int) -> Array:
	var out := []
	if reseaux == null:
		return out
	for res in RES:
		if reseaux.reseau(res).sources.has(b):
			out.append(res)
	for res in RES:
		if reseaux.reseau(res).consos.has(b) and not out.has(res):
			out.append(res)
	return out


func montrer_batiment(b: int) -> bool:
	var lst := reseaux_de(b)
	if lst.is_empty():
		effacer()
		return false
	var cal := reseaux.vue.calque_actif() if reseaux.vue != null else ""
	_calque_vu = cal
	if cal != "" and lst.has(cal):
		lst = [cal]
	elif reseaux.reseau(lst[0]).sources.has(b):
		# Centrale, captage, station : son réseau seulement (le courant qu'elle
		# consomme se voit avec l'onglet Électricité de la vue O).
		lst = [lst[0]]
	bid = b
	origine = "batiment"
	reseaux_montres = lst
	focus.clear()
	for res in lst:
		focus[res] = reseaux.reseau(res).composante_de(b)
	var r0 := reseaux.reseau(lst[0])
	var e: Dictionary = r0.sources.get(b, r0.consos.get(b, {}))
	centre = e.get("p", Vector3.ZERO)
	refaire()
	return true


## Clic sur une route, une ligne ou une conduite : la partie du réseau `res` qui la porte.
func montrer_ligne(res: String, li: int) -> void:
	var r := reseaux.reseau(res)
	if li < 0 or li >= r.lignes.size():
		return
	bid = -1
	origine = "ligne"
	_frame_ligne = Engine.get_process_frames()
	reseaux_montres = [res]
	focus = {res: r.lignes_comp[li]}
	var pts: PackedVector3Array = r.lignes[li]
	centre = pts[pts.size() / 2]
	refaire()


## Tracé du réseau (route ou tronçon) le plus proche de p, à moins de rayon m ; -1 sinon.
func ligne_pres(res: String, p: Vector3, rayon := 6.0) -> int:
	var r := reseaux.reseau(res)
	if r._grille.is_empty():
		return -1
	return r._closest(r._grille, r.lignes, p, rayon)


func _zoom_camera() -> float:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return 1.0
	var d := cam.global_position.distance_to(centre)
	return snappedf(clampf(d / 180.0, 1.0, 3.0), 0.25)


func effacer() -> void:
	bid = -1
	origine = ""
	reseaux_montres = []
	focus.clear()
	stats.clear()
	distances.clear()
	_signature = ""
	for res in _mi:
		(_mi[res] as MeshInstance3D).mesh = null


func _sig() -> String:
	var s := ""
	for res in reseaux_montres:
		var r := reseaux.reseau(res)
		var q := 0
		for c in r.composantes:
			q += roundi(r.taux_composante(c) * 20.0) * (c % 97 + 1)
		s += "%s:%d,%d,%d,%d,%d,%d;" % [res, r.lignes.size(), r.sources.size(), r.consos.size(), r.composantes.size(), q,
			r.composante_de(bid) if bid >= 0 else -2]
	return s


func refaire() -> void:
	_signature = _sig()
	_zoom = _zoom_camera()
	stats.clear()
	distances.clear()
	for res in RES:
		var mi: MeshInstance3D = _mi[res]
		if not reseaux_montres.has(res):
			mi.mesh = null
			continue
		if bid >= 0:
			focus[res] = reseaux.reseau(res).composante_de(bid)
		var off := (0.0 if reseaux_montres.size() == 1 else float(DECALAGES[res])) * _zoom
		var w := (LARGEUR_SEULE if reseaux_montres.size() == 1 else LARGEUR_VOIE) * _zoom
		(_mats[res] as ShaderMaterial).set_shader_parameter("periode", 10.0 * _zoom)
		(_mats[res] as ShaderMaterial).set_shader_parameter("largeur", w)
		mi.mesh = _construire(res, off, w)


# --- Calcul ------------------------------------------------------------------------------

static func etat_de(t: float) -> int:
	if t >= 0.95:
		return ETAT_OK
	return ETAT_SATURE if t > 0.0 else ETAT_COUPE


static func _cle(p: Vector3) -> Vector2i:
	return Vector2i(roundi(p.x * 2.0), roundi(p.z * 2.0))


## Point le plus proche de p sur [a, b] : [t, point].
static func _projeter(p: Vector3, a: Vector3, b: Vector3) -> Array:
	var ab := Vector2(b.x - a.x, b.z - a.z)
	var l2 := ab.length_squared()
	var t := 0.0 if l2 < 1e-6 else clampf(Vector2(p.x - a.x, p.z - a.z).dot(ab) / l2, 0.0, 1.0)
	return [t, a.lerp(b, t)]


func _construire(res: String, off: float, w: float) -> Mesh:
	var r := reseaux.reseau(res)
	var fc: int = int(focus.get(res, -1))
	var st := {"morceaux": 0, "ok": 0, "sature": 0, "coupe": 0, "atteints": 0, "noeuds": 0, "branchements": 0}
	stats[res] = st
	# 1) Tracés retenus : près du bâtiment choisi, ou de sa composante.
	var garde := {}
	for li in r.lignes.size():
		var pts: PackedVector3Array = r.lignes[li]
		if pts.size() < 2:
			continue
		if r.lignes_comp[li] == fc or _pres(pts, centre, RAYON):
			garde[li] = true
	if garde.is_empty():
		return null
	# Les routes ont un point tous les 2 m : on garde les virages et un point tous les 60 m.
	var simp := {}  # li -> [points, seg d'origine -> seg simplifié]
	for li in garde:
		simp[li] = _simplifier(r.lignes[li])
	# 2) Points de coupe : bouts des tracés qui touchent un autre tracé, branchements.
	var coupes := {}  # li -> [[seg, t, point]]
	var liens := []  # [point a, point b, cout, kind, bid]
	# Bouts communs à deux tracés (carrefour déjà coupé) : même nœud, rien à chercher.
	var bouts := {}
	for li in garde:
		var pts: PackedVector3Array = r.lignes[li]
		for p in [pts[0], pts[pts.size() - 1]]:
			var k := _cle(p)
			bouts[k] = int(bouts.get(k, 0)) + 1
	for li in garde:
		var pts: PackedVector3Array = r.lignes[li]
		var vus := {}
		for p in [pts[0], pts[pts.size() - 1]]:
			if int(bouts.get(_cle(p), 0)) > 1:
				continue
			for h in r._candidates(r._grille, p, ReseauBase.SNAP):
				if h.x == li or not garde.has(h.x):
					continue
				var q: PackedVector3Array = simp[h.x][0]
				var sg: int = simp[h.x][1][h.y]
				var cle := Vector3i(h.x, sg, 0 if p == pts[0] else 1)
				if vus.has(cle):
					continue
				vus[cle] = true
				var pr := _projeter(p, q[sg], q[sg + 1])
				var d := Vector2(p.x, p.z).distance_to(Vector2(pr[1].x, pr[1].z))
				if d <= ReseauBase.SNAP:
					_ajouter_coupe(coupes, h.x, sg, pr)
					if d > 0.01:
						liens.append([p, pr[1], d, "lien", -1])
	# Bâtiments : sources (toutes) et consommateurs (les plus proches d'abord).
	var bats := []
	for b in r.sources:
		bats.append([b, true])
	var cons := []
	for b in r.consos:
		if r.sources.has(b) or not r.est_raccorde(b):
			continue
		var p: Vector3 = r.consos[b].p
		var d2 := Vector2(p.x - centre.x, p.z - centre.z).length_squared()
		if d2 <= RAYON * RAYON or r.composante_de(b) == fc:
			cons.append([d2, b])
	cons.sort_custom(func(a, c) -> bool: return a[0] < c[0])
	for i in mini(cons.size(), MAX_BRANCHEMENTS):
		bats.append([cons[i][1], false])
	# Le bâtiment choisi a toujours son branchement.
	if bid >= 0 and r.consos.has(bid) and not r.sources.has(bid):
		var deja := false
		for e in bats:
			if int(e[0]) == bid:
				deja = true
		if not deja:
			bats.append([bid, false])
	var depart := []  # clés des bâtiments sources qui produisent
	var depart_tous := []
	for e in bats:
		var b := int(e[0])
		var src: bool = e[1]
		var de: Dictionary = r.sources[b] if src else r.consos[b]
		var p: Vector3 = de.p
		var best := []
		var bd := r.rayon_raccord + float(de.get("x", 0.0))
		for h in r._candidates(r._grille, p, bd):
			if not garde.has(h.x):
				continue
			var q: PackedVector3Array = simp[h.x][0]
			var sg: int = simp[h.x][1][h.y]
			var pr := _projeter(p, q[sg], q[sg + 1])
			var d := Vector2(p.x, p.z).distance_to(Vector2(pr[1].x, pr[1].z))
			if d <= bd:
				bd = d
				best = [h.x, sg, pr]
		if best.is_empty():
			continue
		_ajouter_coupe(coupes, best[0], best[1], best[2])
		var pb := Vector3(p.x, (best[2][1] as Vector3).y, p.z)
		liens.append([pb, best[2][1], maxf(bd, 0.5), "source" if src else "conso", b])
		if src:
			depart_tous.append(_cle(pb))
			if float(r.sources[b].cap) > 0.0:
				depart.append(_cle(pb))
		else:
			st.branchements += 1
	if depart.is_empty():
		depart = depart_tous
	# 3) Graphe : nœuds = points (à 50 cm près), arêtes = morceaux de tracé et liens.
	var pos := {}  # cle -> Vector3
	var adj := {}  # cle -> [[cle, cout]]
	var morceaux := []  # [cle a, cle b, comp ou -1, kind, bid]
	for li in garde:
		var pts: PackedVector3Array = simp[li][0]
		var suite := []
		var cps: Array = coupes.get(li, [])
		cps.sort_custom(func(a, c) -> bool: return a[0] < c[0] or (a[0] == c[0] and a[1] < c[1]))
		var k := 0
		for si in pts.size():
			suite.append(pts[si])
			while k < cps.size() and int(cps[k][0]) == si:
				suite.append(cps[k][2][1])
				k += 1
		var comp := r.lignes_comp[li]
		for i in range(suite.size() - 1):
			var a: Vector3 = suite[i]
			var b: Vector3 = suite[i + 1]
			var ka := _cle(a)
			var kb := _cle(b)
			if ka == kb:
				continue
			pos[ka] = a
			pos[kb] = b
			_arete(adj, ka, kb, Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z)))
			morceaux.append([ka, kb, comp, "trace", -1])
	for l in liens:
		var ka := _cle(l[0])
		var kb := _cle(l[1])
		if not pos.has(ka):
			pos[ka] = l[0]
		if not pos.has(kb):
			pos[kb] = l[1]
		if ka == kb:
			continue
		_arete(adj, ka, kb, float(l[2]))
		if String(l[3]) != "lien":
			morceaux.append([ka, kb, -1, l[3], l[4]])
	st.noeuds = pos.size()
	st["etat_focus"] = etat_de(r.taux_composante(fc)) if fc >= 0 else ETAT_COUPE
	# 4) Distance à la source le long des tracés.
	var dist := _dijkstra(adj, depart)
	distances[res] = dist
	st.atteints = dist.size()
	# 5) Rubans.
	var stool := Tampon.new()
	var cumul := {}
	for m in morceaux:
		var a: Vector3 = pos[m[0]]
		var b: Vector3 = pos[m[1]]
		var kind := String(m[3])
		var comp := int(m[2])
		var etat := ETAT_COUPE
		var en_avant := true
		if kind == "trace":
			etat = etat_de(r.taux_composante(comp))
			en_avant = comp == fc or fc < 0
		else:
			var b_id := int(m[4])
			if kind == "source":
				etat = etat_de(r.taux_composante(r.composante_de(b_id)))
				if float(r.sources[b_id].cap) <= 0.0:
					etat = ETAT_COUPE
			else:
				etat = etat_de(r.taux_servi(b_id))
			en_avant = r.composante_de(b_id) == fc or fc < 0 or b_id == bid
		var da: float = dist.get(m[0], INF)
		var db: float = dist.get(m[1], INF)
		if is_inf(da) and is_inf(db):
			# Pas relié à une source : sens au hasard du tracé, flèches arrêtées.
			da = float(cumul.get(m[0], 0.0))
			db = da + Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))
			cumul[m[1]] = db
			etat = ETAT_COUPE
		var largeur := w if kind == "trace" else w * 0.6
		var decal := off if kind == "trace" else 0.0
		st.morceaux += _ruban(stool, a, b, da, db, largeur, decal, etat, en_avant)
		match etat:
			ETAT_OK:
				st.ok += 1
			ETAT_SATURE:
				st.sature += 1
			_:
				st.coupe += 1
	if st.morceaux == 0:
		return null
	return stool.mesh()


## Points utiles d'un tracé (bouts, virages, relief, un point tous les 60 m) et,
## pour chaque segment d'origine, le segment simplifié qui le contient.
static func _simplifier(pts: PackedVector3Array) -> Array:
	var out := PackedVector3Array([pts[0]])
	var carte := PackedInt32Array()
	carte.resize(maxi(pts.size() - 1, 0))
	var dir0 := Vector3.ZERO
	var depuis := 0.0
	for i in range(1, pts.size()):
		carte[i - 1] = out.size() - 1
		if i == pts.size() - 1:
			out.append(pts[i])
			break
		var d := pts[i + 1] - pts[i]
		var dp := pts[i] - out[out.size() - 1]
		depuis = dp.length()
		if dir0 == Vector3.ZERO and dp.length() > 0.01:
			dir0 = dp.normalized()
		var garder := depuis >= 60.0
		if d.length() > 0.01 and dir0 != Vector3.ZERO and dir0.dot(d.normalized()) < 0.9986:
			garder = true
		if garder:
			out.append(pts[i])
			dir0 = d.normalized() if d.length() > 0.01 else Vector3.ZERO
	return [out, carte]


static func _pres(pts: PackedVector3Array, c: Vector3, r: float) -> bool:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in pts:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.z))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.z))
	return c.x >= lo.x - r and c.x <= hi.x + r and c.z >= lo.y - r and c.z <= hi.y + r


static func _ajouter_coupe(coupes: Dictionary, li: int, seg: int, pr: Array) -> void:
	if not coupes.has(li):
		coupes[li] = []
	coupes[li].append([seg, float(pr[0]), pr])


static func _arete(adj: Dictionary, a: Vector2i, b: Vector2i, cout: float) -> void:
	if not adj.has(a):
		adj[a] = []
	if not adj.has(b):
		adj[b] = []
	adj[a].append([b, cout])
	adj[b].append([a, cout])


## Distances depuis les départs (tas binaire) : cle -> m.
static func _dijkstra(adj: Dictionary, departs: Array) -> Dictionary:
	var dist := {}
	var tas_d := PackedFloat64Array()
	var tas_k := []
	for k in departs:
		dist[k] = 0.0
		_pousser(tas_d, tas_k, 0.0, k)
	while tas_k.size() > 0:
		var d := tas_d[0]
		var k: Vector2i = tas_k[0]
		_retirer_haut(tas_d, tas_k)
		if d > float(dist.get(k, INF)):
			continue
		for e in adj.get(k, []):
			var nd := d + float(e[1])
			if nd < float(dist.get(e[0], INF)):
				dist[e[0]] = nd
				_pousser(tas_d, tas_k, nd, e[0])
	return dist


static func _pousser(td: PackedFloat64Array, tk: Array, d: float, k: Vector2i) -> void:
	td.append(d)
	tk.append(k)
	var i := td.size() - 1
	while i > 0:
		var p := (i - 1) / 2
		if td[p] <= td[i]:
			break
		var x := td[p]
		td[p] = td[i]
		td[i] = x
		var y = tk[p]
		tk[p] = tk[i]
		tk[i] = y
		i = p


static func _retirer_haut(td: PackedFloat64Array, tk: Array) -> void:
	var n := td.size() - 1
	td[0] = td[n]
	tk[0] = tk[n]
	td.resize(n)
	tk.resize(n)
	var i := 0
	while true:
		var l := i * 2 + 1
		var m := i
		if l < n and td[l] < td[m]:
			m = l
		if l + 1 < n and td[l + 1] < td[m]:
			m = l + 1
		if m == i:
			break
		var x := td[m]
		td[m] = td[i]
		td[i] = x
		var y = tk[m]
		tk[m] = tk[i]
		tk[i] = y
		i = m


## Sommets des rubans, rangés directement dans des tableaux (plus rapide que SurfaceTool).
class Tampon:
	var v := PackedVector3Array()
	var c := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()

	func ajouter(p: Vector3, u: Vector2, col: Color, u2: Vector2) -> void:
		v.append(p)
		uv.append(u)
		c.append(col)
		uv2.append(u2)

	func mesh() -> ArrayMesh:
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_COLOR] = c
		arr[Mesh.ARRAY_TEX_UV] = uv
		arr[Mesh.ARRAY_TEX_UV2] = uv2
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		return m


## Ruban de a à b, découpé en morceaux de PAS m ; la distance à la source est
## exacte à chaque bout de morceau (min des deux sens). Rend le nombre de morceaux.
func _ruban(t: Tampon, a: Vector3, b: Vector3, da: float, db: float, w: float, off: float,
		etat: int, en_avant: bool) -> int:
	var d := Vector3(b.x - a.x, 0, b.z - a.z)
	var l := d.length()
	if l < 0.05:
		return 0
	var side := Vector3(-d.z, 0, d.x) / l
	var n := maxi(1, ceili(l / PAS))
	var col: Color = COULEUR_ETAT[etat]
	var uv2 := Vector2(float(etat), 1.0 if en_avant else 0.0)
	var o := side * off + Vector3(0, HAUT, 0)
	var hw := side * w * 0.5
	var p0 := a + o
	var u0 := minf(da, db + l)
	if is_inf(u0):
		u0 = 0.0
	for i in n:
		var f := float(i + 1) / n
		var s1 := l * f
		var p1 := a.lerp(b, f) + o
		var u1 := minf(da + s1, db + l - s1)
		if is_inf(u1):
			u1 = s1
		t.ajouter(p0 - hw, Vector2(u0, 0), col, uv2)
		t.ajouter(p0 + hw, Vector2(u0, 1), col, uv2)
		t.ajouter(p1 + hw, Vector2(u1, 1), col, uv2)
		t.ajouter(p0 - hw, Vector2(u0, 0), col, uv2)
		t.ajouter(p1 + hw, Vector2(u1, 1), col, uv2)
		t.ajouter(p1 - hw, Vector2(u1, 0), col, uv2)
		p0 = p1
		u0 = u1
	return n
