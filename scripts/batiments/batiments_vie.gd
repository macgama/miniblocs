class_name BatimentsVie
extends Node
## Vie des bâtiments posés :
## - Chantier : un bâtiment neuf monte étage par étage derrière ses
##   échafaudages (grue pour les grands), dans une palissade, puis le toit, puis
##   on démonte tout. Personne ne s'y installe avant la fin (Population).
## - Usure : les façades se délavent, la mousse gagne les toits ; un bâtiment
##   vide depuis longtemps se couvre de lierre, ses fenêtres restent éteintes
##   ou sont condamnées (uniformes d'instance de batiment.gdshader).
## - Maisons habitées : clôture, boîte aux lettres, potager, linge (Abords) et
##   fumée aux cheminées.
##
## Données gardées dans chaque bâtiment (et dans la sauvegarde) : "ne" (début
## du chantier, secondes Unix du jeu), "fin" (fin prévue ou réelle), "av"
## (avancement du chantier, 0 à 1), "hr" (heures réelles de travail du
## chantier, voir Chantiers) et "du" (reste à payer : le prix est payé au fil
## des travaux ; caisse vide = chantier arrêté).

## Chantiers visibles (false : les bâtiments apparaissent d'un coup).
static var chantiers := true
## Usure, abords et fumée.
static var vie := true

const AN := 365.0 * 86400.0
## Au-delà, les détails de vie (abords, fumée) ne sont pas dessinés.
const VUE_ABORDS := 260.0
const VUE_FUMEE := 380.0
## Ouvriers et engins animés seulement près de la caméra.
const VUE_OUVRIERS := 240.0
## Marqueur de chantier (icône et anneau d'avancement) visible jusqu'à cette distance
## (scripts/chantiers/marqueurs_chantiers.gd) ; le détail est dans l'info-bulle et la fiche.
const VUE_PANNEAU := 650.0

## Vitesse d'usure d'un bâtiment (bid) -> multiplicateur (Nuisances : quartiers dévalués).
var extra_usure: Callable
var buildings: BuildingSystem
var ambiance: DayNight
var population: Population

## Route à moins de CAMION_ROUTE_MAX m du bord de la palissade : les camions
## du chantier s'y garent (sinon devant l'entrée, sur le terrain).
const CAMION_ROUTE_MAX := 12.0
const CAMION_DEMI_LARGEUR := 1.2
## bid -> {"mi", "echaf", "grue", "fleche", "palissade", "terre", "dalle", "engins", "ouvriers", "texte", "H", "bb", "mat", "mat_echaf", "etape"}
var _chantiers := {}
## bid -> {"abords": nœud, "fumee": [nœuds], "usure": float, "abandon": float, "vide": float}
var _etat := {}
var _acc_chantier := 0.0
var _acc_vie := 0.0
var _clock := 0.0
## Dernière heure du jeu vue par les chantiers (pour compter les heures de travail).
var _t_prev := -1.0
## L'équipe est-elle au travail en ce moment (heure locale) ?
var au_travail := false
## Petits marqueurs au-dessus des chantiers (icône, anneau d'avancement, état).
var marqueurs: MarqueursChantiers

## Dernière vie des bâtiments installée (fiche du bâtiment).
static var instance: BatimentsVie
static var _bounds_cache := {}
static var _fumee_mesh: ArrayMesh
static var _fumee_mat: ShaderMaterial


func setup(b: BuildingSystem, a: DayNight, p: Population) -> void:
	instance = self
	buildings = b
	ambiance = a
	population = p
	_t_prev = now()
	buildings.added.connect(_on_added)
	buildings.removed.connect(_on_removed)
	for bid in buildings.buildings:
		_on_added(bid)
	if marqueurs == null:
		marqueurs = MarqueursChantiers.new()
		marqueurs.vie = self
		add_child(marqueurs)


func now() -> float:
	return ambiance.unix_time if ambiance != null else _clock


func offset_h() -> float:
	return ambiance.utc_offset() if ambiance != null else 0.0


## Années de « vie » écoulées pour une durée de jeu (suit la vitesse de la vie des habitants).
## Années du calendrier de la partie. Les murs vieillissent avec la date affichée,
## pas au rythme de la vie des habitants (« 1 an = 1 mois » par défaut) : sinon
## une maison posée il y a quelques mois paraissait vieille de plusieurs années.
func _years(seconds: float) -> float:
	return seconds / AN


## Un bâtiment de ce type posé maintenant aura-t-il un chantier ?
static func aura_chantier(id: String) -> bool:
	if not chantiers or Chantiers.instantanes():
		return false
	var t := BuildingCatalog.get_type(id)
	return not t.is_empty() and not t.has("blocks") and not t.has("stade") and not t.get("sans_chantier", false)


func _on_added(bid: int) -> void:
	var b: Dictionary = buildings.buildings[bid]
	var t := now()
	var mi := buildings.node_of(bid)
	if mi == null:
		return
	if _t_prev < 0.0:
		_t_prev = t
	if not b.has("ne") or float(b.ne) <= 0.0:
		var fresh := not b.has("ne")
		b["ne"] = t
		if fresh and aura_chantier(String(b.t)):
			b["av"] = 0.0
			b["hr"] = Chantiers.heures_batiment(String(b.t))
			b["fin"] = fin_prevue(bid)
		else:
			b["fin"] = t
	elif not b.has("av") and float(b.get("fin", 0.0)) > t and _chantier_possible(b):
		# Ancienne partie (chantier daté) : on reprend où il en était.
		var ne := float(b.ne)
		b["av"] = clampf((t - ne) / maxf(float(b.fin) - ne, 1.0), 0.0, 0.99)
		b["hr"] = Chantiers.heures_batiment(String(b.t))
	_etat[bid] = {"abords": null, "fumee": [], "usure": -1, "abandon": -1, "vide": -1.0,
		"base": posmod(hash(Vector2i(int(b.x), int(b.z))), 1000) / 1000.0 * 0.22}
	if b.has("av") and float(b.av) < 1.0:
		_start_chantier(bid)
	else:
		b.erase("chantier")
		b.erase("av")
		_payer_reste(b)


func _on_removed(bid: int) -> void:
	var c: Dictionary = _chantiers.get(bid, {})
	if not c.is_empty():
		for f in c.ouvriers:
			if is_instance_valid(f):
				(f as Node).queue_free()
	_chantiers.erase(bid)
	_etat.erase(bid)


func _chantier_possible(b: Dictionary) -> bool:
	var t := BuildingCatalog.get_type(String(b.t))
	return not t.has("blocks") and not t.has("stade") and not t.get("sans_chantier", false)


## Durée prévue du chantier d'un type (secondes de jeu, horaires et vitesse de la vie actuels),
## pour un chantier qui commence un lundi à 7 h 30.
func duree_prevue(id: String) -> float:
	var h := Chantiers.heures_batiment(id) / Chantiers.rythme(population)
	var lundi := 4.0 * 86400.0 + 7.5 * 3600.0 # lundi 5 janvier 1970, 7 h 30
	return Chantiers.date_apres(lundi, h, 0.0) - lundi


## Date (secondes Unix du jeu) où le chantier devrait finir, au rythme actuel.
func fin_prevue(bid: int) -> float:
	var b: Dictionary = buildings.buildings[bid]
	var reste := (1.0 - float(b.get("av", 1.0))) * float(b.get("hr", 0.0)) / Chantiers.rythme(population)
	# Équipe incomplète (ouvriers comptés, Fondateurs) : plus long. Sans ouvriers, au rythme normal.
	var f := Fondateurs.facteur_de(Fondateurs.cle_batiment(bid)) if b.has("av") else 1.0
	if f > 0.0:
		reste /= f
	reste /= Expeditions.rythme_chantier(bid)
	return Chantiers.date_apres(now(), reste, offset_h())


## Paie d'un coup ce qui reste dû (chantier terminé ou annulé par les réglages).
func _payer_reste(b: Dictionary) -> void:
	var du := int(b.get("du", 0))
	if du > 0 and not buildings.unlimited_money:
		var caisse_prev := Pays.du_batiment(b, buildings._rect_of(b))
		buildings.money -= du
		Pays.retour(caisse_prev)
	b.erase("du")


func _process(delta: float) -> void:
	_clock += EchelleTemps.dt(delta)
	if buildings == null:
		return
	_acc_chantier += delta
	_acc_vie += delta
	if _acc_chantier >= 0.2:
		_acc_chantier = 0.0
		_update_chantiers()
	if not _chantiers.is_empty():
		_animer_chantiers()
	if _acc_vie >= 1.5:
		_acc_vie = 0.0
		_update_vie()


# --- Chantiers ---------------------------------------------------------------------------

## Volume construit d'un maillage (sans les abords plats) : AABB des sommets au-dessus de 0,6 m.
static func body_bounds(mesh: ArrayMesh) -> AABB:
	var key := mesh.get_rid()
	if _bounds_cache.has(key):
		return _bounds_cache[key]
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	if mesh.get_surface_count() > 0:
		var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for v in verts:
			if v.y > 0.6:
				lo = lo.min(v)
				hi = hi.max(v)
	var box := AABB(Vector3.ZERO, Vector3(1, 1, 1))
	if lo.x < INF:
		lo.y = 0.0
		box = AABB(lo, hi - lo)
	_bounds_cache[key] = box
	return box


func _start_chantier(bid: int) -> void:
	var b: Dictionary = buildings.buildings[bid]
	var mi := buildings.node_of(bid)
	b["chantier"] = true
	var bb := body_bounds(mi.mesh as ArrayMesh)
	# Matériaux propres au chantier : bâtiment (et sa version lointaine) d'un côté,
	# échafaudages de l'autre (ils dépassent un peu la partie construite).
	var mat := NightWindows.chantier_copy()
	var mat_echaf := NightWindows.chantier_copy()
	mi.set_meta("chantier", true)
	mi.material_override = mat
	var far := mi.get_node_or_null("Loin") as MeshInstance3D
	if far != null:
		far.material_override = mat
	var echaf := MeshInstance3D.new()
	echaf.name = "Echafaudage"
	echaf.mesh = _scaffold_mesh(bb)
	echaf.material_override = mat_echaf
	echaf.visibility_range_end = 1400.0
	mi.add_child(echaf)
	var t := BuildingCatalog.get_type(String(b.t))
	var w := float(t.get("w", 8))
	var d := float(t.get("d", 8))
	var pal := MeshInstance3D.new()
	pal.name = "Palissade"
	pal.mesh = _palissade_mesh(w, d)
	pal.material_override = NightWindows.chantier_material()
	pal.visibility_range_end = 900.0
	mi.add_child(pal)
	var terre := MeshInstance3D.new()
	terre.name = "Fouille"
	terre.mesh = _fouille_mesh(bb, w, d)
	terre.material_override = NightWindows.chantier_material()
	terre.visibility_range_end = 1400.0
	mi.add_child(terre)
	var dalle := MeshInstance3D.new()
	dalle.name = "Dalle"
	var kd := BlocMesh.new()
	kd.box(bb.get_center().x, 0.0, bb.get_center().z, bb.size.x + 0.4, 1.0, bb.size.z + 0.4, Color("a9a59c"))
	dalle.mesh = kd.to_mesh(NightWindows.chantier_material())
	mi.add_child(dalle)
	var engins := Node3D.new()
	engins.name = "Engins"
	mi.add_child(engins)
	var pel := EnginsChantier.pelleteuse()
	pel.position = Vector3(bb.get_center().x + minf(bb.size.x * 0.2, 2.0), 0.15, bb.get_center().z)
	pel.rotation.y = 0.6
	engins.add_child(pel)
	# Camion-benne, toupie et camionnette ne sortent jamais ensemble (une étape
	# chacun) : ils partagent la même place, garée par _garer_camions().
	for cam in [EnginsChantier.benne(), EnginsChantier.toupie(), EnginsChantier.camionnette()]:
		engins.add_child(cam)
	var c := {"mi": mi, "echaf": echaf, "palissade": pal, "grue": null, "fleche": null, "H": bb.end.y, "bb": bb,
		"mat": mat, "mat_echaf": mat_echaf, "terre": terre, "dalle": dalle, "engins": engins,
		"ouvriers": [], "etape": "", "texte": "", "w": w, "d": d}
	if bb.end.y > 12.0:
		var g := _grue(bb)
		mi.add_child(g)
		c.grue = g
		c.fleche = g.get_node("Fleche")
	_chantiers[bid] = c
	_garer_camions(c)
	_show_etape(bid)


## Camions du chantier (benne, toupie, camionnette) : garés le long du trottoir,
## sur la chaussée côté chantier, dans le sens de la circulation, devant
## l'entrée de la palissade. Sans route tout près, sur le terrain devant
## l'entrée, sans toucher la palissade.
func _garer_camions(c: Dictionary) -> void:
	var mi := c.mi as MeshInstance3D
	var eng := c.engins as Node3D
	if not is_instance_valid(mi) or eng == null:
		return
	var local := place_camion(mi.global_transform, float(c.d),
		buildings.transport if buildings != null else null)
	for n in eng.get_children():
		if n.name != "Pelleteuse":
			(n as Node3D).transform = local


## Place (dans le repère du bâtiment) d'un camion de chantier de profondeur d
## (entrée côté -Z). Les engins regardent vers +Z et reposent sur y = 0.
static func place_camion(g: Transform3D, d: float, tr: TransportSystem) -> Transform3D:
	# Par défaut : sur le terrain devant l'entrée, parallèle à la palissade,
	# 0,8 m devant elle (demi-largeur du camion 1,2 m).
	var defaut := Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(0, 0, -d / 2.0 - 2.1))
	if tr == null or tr.network == null:
		return defaut
	var ent := g * Vector3(0, 0, -d / 2.0)
	var best := {}
	var best_d := INF
	for eid in tr.edges_near(ent, CAMION_ROUTE_MAX + 20.0):
		if not tr.network.edges.has(eid):
			continue
		var e: Dictionary = tr.network.edges[eid]
		if TransportTypes.mode_of(String(e.t)) != TransportTypes.Mode.ROAD or e.has("ch"):
			continue
		var hit: Dictionary = tr.network.nearest_on_edge(eid, ent)
		var bord := TransportTypes.width_of(String(e.t), e.w) / 2.0
		var dist := float(hit.dist) - bord
		if dist < best_d and dist <= CAMION_ROUTE_MAX:
			best_d = dist
			best = {"e": e, "pos": hit.pos}
	if best.is_empty():
		return defaut
	var e: Dictionary = best.e
	var p: Vector3 = best.pos
	var pts: PackedVector3Array = e.pts
	# Direction de la route au point le plus proche.
	var t := Vector3.ZERO
	var dmin := INF
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var ab := Vector3(b.x - a.x, 0, b.z - a.z)
		if ab.length_squared() < 1e-6:
			continue
		var u := clampf(Vector3(p.x - a.x, 0, p.z - a.z).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var q := a + (b - a) * u
		var dd := Vector2(q.x - p.x, q.z - p.z).length()
		if dd < dmin:
			dmin = dd
			t = ab.normalized()
	if t == Vector3.ZERO:
		return defaut
	var n := Vector3(ent.x - p.x, 0, ent.z - p.z)
	if n.length_squared() < 1e-4:
		return defaut
	n = n.normalized()
	# Composante perpendiculaire à la route seulement (entrée en biais, route courbe).
	n = (n - t * n.dot(t))
	if n.length_squared() < 1e-4:
		return defaut
	n = n.normalized()
	var spec: Dictionary = e.w
	var bord_chaussee := TransportTypes.width_of(String(e.t), spec) / 2.0 \
		- TransportTypes.side_of(String(e.t), spec) - TransportTypes.bus_of(String(e.t), spec)
	var off := maxf(bord_chaussee - CAMION_DEMI_LARGEUR - 0.25, 0.0)
	var pos := Vector3(p.x, p.y + 0.05, p.z) + n * off
	# Circulation à droite : le trottoir (n) est à droite du camion.
	if t.cross(Vector3.UP).dot(n) < 0.0:
		t = -t
	var monde := Transform3D(Basis(Vector3.UP.cross(t), Vector3.UP, t), pos)
	# Repère du bâtiment sans son échelle : le camion garde sa taille réelle.
	var gl := Transform3D(g.basis.orthonormalized(), g.origin)
	var out := gl.affine_inverse() * monde
	out.basis = out.basis.scaled(Vector3.ONE / g.basis.get_scale())
	return out


func _set_clip(bid: int, h: float) -> void:
	var c: Dictionary = _chantiers[bid]
	(c.mat as ShaderMaterial).set_shader_parameter("chantier_h", h)
	(c.mat_echaf as ShaderMaterial).set_shader_parameter("chantier_h", h + 1.3 if h < 9000.0 else h)


## Avancement du chantier (0 à 1), 1 si terminé ou inconnu.
func progress(bid: int) -> float:
	if not buildings.buildings.has(bid):
		return 1.0
	var b: Dictionary = buildings.buildings[bid]
	return clampf(float(b.get("av", 1.0)), 0.0, 1.0)


## Étape en cours d'un chantier : [indice, clé, nom, avancement de l'étape], ou [] si fini.
func etape_de(bid: int) -> Array:
	if not _chantiers.has(bid):
		return []
	return Chantiers.etape(Chantiers.etapes_batiment(String(buildings.buildings[bid].t)), progress(bid))


## Fait avancer les chantiers selon les heures de travail écoulées depuis le dernier passage.
func _update_chantiers() -> void:
	var t := now()
	if _t_prev < 0.0:
		_t_prev = t
	if not chantiers or Chantiers.instantanes():
		_t_prev = t
		if not _chantiers.is_empty():
			finish_all()
		return
	var off := offset_h()
	var heures := Chantiers.heures_ouvrees(_t_prev, t, off)
	_t_prev = t
	var local := t + off * 3600.0
	au_travail = Chantiers.au_travail(fposmod(local, 86400.0) / 3600.0, Chantiers.jour_semaine(local))
	var k := Chantiers.rythme(population)
	var done := []
	for bid in _chantiers:
		var c: Dictionary = _chantiers[bid]
		if not is_instance_valid(c.mi) or not buildings.buildings.has(bid):
			done.append(bid)
			continue
		var b: Dictionary = buildings.buildings[bid]
		# Arrêté faute d'argent (ses ouvriers sont partis ailleurs) : il reprend quand
		# la caisse peut payer une semaine de travaux.
		if b.get("attente", false):
			var caisse_a := Pays.du_batiment(b, buildings._rect_of(b))
			if buildings.unlimited_money or buildings.money >= _part_semaine(b, k):
				b.erase("attente")
			Pays.retour(caisse_a)
		# Ouvriers présents (fondateurs, entreprises du bâtiment) : 0 = arrêté, 1 = équipe complète.
		var f := Fondateurs.facteur_de(Fondateurs.cle_batiment(bid))
		if f <= 0.0:
			b["sans_ouvriers"] = true
		else:
			b.erase("sans_ouvriers")
		if heures > 0.0 and f > 0.0:
			# Spécialistes rapportés par les expéditions (ingénieure des ponts…) : plus rapide.
			var dp := heures * k * f * Expeditions.rythme_chantier(bid) / maxf(float(b.get("hr", 1.0)), 1.0)
			dp = minf(dp, 1.0 - float(b.av))
			# Le prix se paie au fil des travaux ; sans argent, le chantier s'arrête.
			var du := int(b.get("du", 0))
			if du > 0:
				var part := mini(du, ceili(float(b.get("cost", 0)) * dp))
				# Chaque chantier est payé par la caisse de sa ville (ou du pays).
				var caisse_prev := Pays.du_batiment(b, buildings._rect_of(b))
				if not buildings.unlimited_money and buildings.money < part:
					if not b.get("attente", false):
						_alerte_argent(String(b.t))
					b["attente"] = true
					dp = 0.0
				else:
					b.erase("attente")
					if not buildings.unlimited_money:
						buildings.money -= part
					b["du"] = du - part
				Pays.retour(caisse_prev)
			if dp > 0.0:
				_materiaux(b, dp)
			b["av"] = float(b.av) + dp
		if float(b.av) >= 0.9999:
			done.append(bid)
			continue
		_show_etape(bid)
		if c.fleche != null and au_travail:
			(c.fleche as Node3D).rotation.y = sin(_clock * 0.15 + float(bid)) * 1.3
	for bid in done:
		_finish_chantier(bid)


var _derniere_alerte := -1.0e12


## Le chantier consomme la part dp de ses matériaux d'époque (MateriauxChantiers) :
## pris dans les stocks de la carte, sinon importés (surcoût payé par sa caisse).
func _materiaux(b: Dictionary, dp: float) -> void:
	if not b.has("matx"):
		b["matx"] = MateriauxChantiers.besoins_batiment(String(b.t))
	var r := buildings._rect_of(b)
	var f := MateriauxChantiers.fournir(b.matx, dp, _pos_chantier(b))
	if not b.has("mat_l"):
		b["mat_l"] = {}
		b["mat_i"] = {}
	MateriauxChantiers.cumule(b.mat_l, f.local)
	MateriauxChantiers.cumule(b.mat_i, f.import)
	# Bâtiment privé : son promoteur paie aussi les matériaux importés, pas la ville.
	if float(f.surcout) > 0.0 and not BuildingCatalog.est_prive(String(b.t)):
		var caisse_prev := Pays.du_batiment(b, r)
		var sc := MateriauxChantiers.regler_surcout(f, buildings)
		Pays.retour(caisse_prev)
		if sc > 0:
			b["mat_sc"] = int(b.get("mat_sc", 0)) + sc


## Point où les camions livrent un chantier de bâtiment (centre du terrain).
func _pos_chantier(b: Dictionary) -> Vector3:
	var r := buildings._rect_of(b)
	var c := Vector2(r.position) + Vector2(r.size) * 0.5
	return Vector3(c.x, 0.0, c.y)


## Matériaux reçus par un chantier : {"local": {g: t}, "import": {g: t}, "total": {g: t}}.
func materiaux_de(bid: int) -> Dictionary:
	var b: Dictionary = buildings.buildings.get(bid, {})
	return {"local": b.get("mat_l", {}), "import": b.get("mat_i", {}), "surcout": int(b.get("mat_sc", 0)),
		"total": b.get("matx", MateriauxChantiers.besoins_batiment(String(b.get("t", ""))))}


## Un chantier s'arrête faute d'argent : on le dit (au plus une fois par jour de jeu),
## avec la solution.
func _alerte_argent(type_id: String) -> void:
	var t := now()
	if t - _derniere_alerte < 86400.0:
		return
	_derniere_alerte = t
	buildings.message.emit("Chantier de %s arrêté : la caisse est vide. Emprunte dans le Budget (M), ou attends les impôts du mois ; ses ouvriers vont aux autres chantiers." % String(BuildingCatalog.get_type(type_id).get("name", type_id)))


## Prix d'une semaine de travaux (37,5 h) d'un chantier, plafonné à ce qui reste dû.
func _part_semaine(b: Dictionary, k: float) -> int:
	var dp := 37.5 * k / maxf(float(b.get("hr", 1.0)), 1.0)
	return mini(int(b.get("du", 0)), ceili(float(b.get("cost", 0)) * dp))


## Montre l'étape du chantier : fouille, dalle, murs étage par étage derrière
## les échafaudages, toit, puis finitions ; engins et panneau selon l'étape.
func _show_etape(bid: int) -> void:
	var c: Dictionary = _chantiers[bid]
	var b: Dictionary = buildings.buildings[bid]
	var e := Chantiers.etape(Chantiers.etapes_batiment(String(b.t)), float(b.get("av", 0.0)))
	var key: String = e[1]
	var u: float = e[3]
	c["u"] = u
	# Grand monument : ses étapes propres, montrées comme celles d'un bâtiment.
	if MonumentsTypes.est_monument(String(b.t)):
		var vu := MonumentsTypes.visuel(String(b.t), float(b.get("av", 0.0)))
		key = String(vu[0])
		u = float(vu[1])
	c["u"] = u
	var H: float = c.H
	var h := -1.0
	match key:
		"murs":
			h = (floorf(u * ceilf(H / 3.0)) + 1.0) * 3.0
		"toit", "finitions":
			h = 10000.0
	_set_clip(bid, h)
	(c.terre as Node3D).visible = key == "terrassement" or key == "fondations"
	(c.dalle as Node3D).visible = key == "fondations"
	if key == "fondations":
		(c.dalle as Node3D).scale.y = maxf(0.05, u * 0.4)
	(c.echaf as Node3D).visible = key == "murs" or key == "toit"
	if c.grue != null:
		(c.grue as Node3D).visible = key == "murs" or key == "toit"
	var eng: Node3D = c.engins
	eng.get_node("Pelleteuse").visible = key == "terrassement"
	eng.get_node("Benne").visible = key == "terrassement"
	eng.get_node("Toupie").visible = key == "fondations" or (key == "murs" and u < 0.3)
	eng.get_node("Camionnette").visible = key == "finitions"
	if key != String(c.etape):
		c.etape = key
		_vider_ouvriers(c)
		# Une route a pu être tracée depuis le début du chantier : on regare le camion.
		_garer_camions(c)
	c.texte = texte_chantier(bid)


## Pourquoi le chantier n'avance pas (ou "" s'il avance) : pause, argent, sans_ouvriers,
## equipe (équipe incomplète), repos (hors des heures de travail).
func statut_de(bid: int) -> String:
	var b: Dictionary = buildings.buildings.get(bid, {})
	if b.is_empty():
		return ""
	if b.get("pause", false):
		return "pause"
	if b.get("attente", false):
		return "argent"
	if b.get("sans_ouvriers", false):
		return "sans_ouvriers"
	var eq := _equipe(bid)
	if not eq.is_empty() and int(eq[0]) < int(eq[1]):
		return "equipe"
	if not au_travail:
		return "repos"
	return ""


func _equipe(bid: int) -> Array:
	return Fondateurs.instance.equipe_de(Fondateurs.cle_batiment(bid)) \
		if Fondateurs.instance != null and Fondateurs.instance.regle_active() else []


## Ce qu'on sait d'un chantier, pour l'info-bulle du marqueur et la fiche du bâtiment :
## {nom, etape, av, statut, etat (phrase), materiaux, fin} ; vide si pas de chantier.
func detail_chantier(bid: int) -> Dictionary:
	if not _chantiers.has(bid) or not buildings.buildings.has(bid):
		return {}
	var b: Dictionary = buildings.buildings[bid]
	var e := Chantiers.etape(Chantiers.etapes_batiment(String(b.t)), float(b.get("av", 0.0)))
	var fin := Chantiers.date_texte(fin_prevue(bid), offset_h())
	var st := statut_de(bid)
	var etat := "Équipe au travail"
	match st:
		"pause": etat = "En pause (Maj+H : fondateurs et chantiers)"
		"argent": etat = "Arrêté : plus d'argent dans la caisse"
		"sans_ouvriers": etat = "En attente d'ouvriers (Maj+H)"
		"equipe":
			var eq := _equipe(bid)
			etat = "%d ouvriers sur %d" % [int(eq[0]), int(eq[1])]
		"repos": etat = "Équipe au repos"
	var mat := ""
	var imp := ""
	if b.has("matx") and not (b.matx as Dictionary).is_empty():
		mat = MateriauxChantiers.texte(b.matx, 3)
		# Ce qui est déjà arrivé : d'ici (carrières, usines) ou importé (avec son surcoût).
		var t_l := 0.0
		var t_i := 0.0
		for g in b.get("mat_l", {}):
			t_l += float(b.mat_l[g])
		for g in b.get("mat_i", {}):
			t_i += float(b.mat_i[g])
		if t_l + t_i >= 0.5:
			imp = "%s livrées, dont %d %% importées" % [Ressources.format_t(t_l + t_i), roundi(100.0 * t_i / (t_l + t_i))]
			if int(b.get("mat_sc", 0)) > 0:
				imp += " (+%s)" % BuildingSystem.format_money(int(b.mat_sc))
	return {"nom": String(BuildingCatalog.get_type(String(b.t)).get("name", "Chantier")), "etape": String(e[2]) if e.size() > 2 else "",
		"av": progress(bid), "statut": st, "etat": etat, "materiaux": mat, "livres": imp,
		"fin": "" if st == "argent" or st == "pause" or st == "sans_ouvriers" else fin}


## Le détail du chantier en quelques lignes (info-bulle du marqueur).
func texte_chantier(bid: int) -> String:
	var d := detail_chantier(bid)
	if d.is_empty():
		return ""
	var txt := "%s\n%s · %d %%\n" % [d.nom, d.etape, floori(float(d.av) * 100.0)]
	if String(d.materiaux) != "":
		txt += "Matériaux : %s\n" % d.materiaux
	if String(d.get("livres", "")) != "":
		txt += "%s\n" % d.livres
	txt += String(d.etat)
	if String(d.fin) != "":
		txt += " · fin vers le %s" % d.fin
	return txt


## Les chantiers de bâtiments en cours (bid).
func chantiers_en_cours() -> Array:
	return _chantiers.keys()


## Point au-dessus du chantier où poser son marqueur (coordonnées du monde).
func haut_du_chantier(bid: int) -> Vector3:
	var c: Dictionary = _chantiers.get(bid, {})
	if c.is_empty() or not is_instance_valid(c.mi) or not (c.mi as Node3D).is_inside_tree():
		return Vector3.INF
	var mi: MeshInstance3D = c.mi
	var bb: AABB = c.bb
	return mi.global_transform * Vector3(bb.get_center().x, 0.0, bb.get_center().z) + Vector3(0, float(c.H) + 3.0, 0)


## Ouvriers (près de la caméra, pendant les heures de travail) et engins qui bougent.
func _animer_chantiers() -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	for bid in _chantiers:
		var c: Dictionary = _chantiers[bid]
		if not is_instance_valid(c.mi):
			continue
		var mi: MeshInstance3D = c.mi
		var pres := cam != null and cam.global_position.distance_to(mi.global_position) < VUE_OUVRIERS
		var bb: Dictionary = buildings.buildings[bid]
		var veut: bool = pres and au_travail and not bool(bb.get("attente", false)) and not bool(bb.get("sans_ouvriers", false)) \
			and not bool(bb.get("pause", false))
		if veut and (c.ouvriers as Array).is_empty():
			_poser_ouvriers(bid, c)
		elif not veut and not (c.ouvriers as Array).is_empty():
			_vider_ouvriers(c)
		if veut:
			for f in c.ouvriers:
				(f as Figurine).animer(_clock)
			for n in (c.engins as Node3D).get_children():
				if (n as Node3D).visible:
					EnginsChantier.animer(n, _clock + float(bid), true)


## Chantiers où l'équipe travaille en ce moment près de la caméra (pour les sons).
func chantiers_bruyants() -> Array:
	var out := []
	for bid in _chantiers:
		var c: Dictionary = _chantiers[bid]
		if not (c.ouvriers as Array).is_empty() and is_instance_valid(c.mi):
			out.append((c.mi as Node3D).global_position)
	return out


func _vider_ouvriers(c: Dictionary) -> void:
	for f in c.ouvriers:
		if is_instance_valid(f):
			(f as Node).queue_free()
	(c.ouvriers as Array).clear()


## Place les ouvriers selon l'étape : à la pioche dans la fouille, au béton sur
## la dalle, sur les échafaudages, sur le toit, puis aux finitions.
func _poser_ouvriers(bid: int, c: Dictionary) -> void:
	var bb: AABB = c.bb
	var key := String(c.etape)
	var mi: MeshInstance3D = c.mi
	var n := clampi(2 + int(bb.size.x * bb.size.z / 60.0), 2, 6)
	var cx := bb.get_center().x
	var cz := bb.get_center().z
	var gestes := ["piocher"]
	var y := 0.15
	var tour := false
	match key:
		"fondations":
			gestes = ["couler", "porter"]
			y = 0.0
		"murs":
			gestes = ["marteler", "porter"]
			var built := (floorf(float(c.get("u", 0.0)) * ceilf(c.H / 3.0)) + 1.0) * 3.0
			y = maxf(0.0, floorf((minf(built, c.H) - 1.5) / 2.0) * 2.0)
			tour = true
		"toit":
			gestes = ["marteler"]
			y = maxf(0.0, floorf(c.H / 2.0) * 2.0 - 2.0)
			tour = true
		"finitions":
			gestes = ["porter", "balayer"]
			y = 0.0
	for i in n:
		var f := Figurine.creer(-1000 - bid * 8 - i, "ouvrier")
		f.regler(String(gestes[i % gestes.size()]))
		var p := Vector3.ZERO
		var u := (float(i) + 0.5) / float(n)
		if tour:
			# Sur le plancher des échafaudages, tout autour.
			var per := 2.0 * (bb.size.x + bb.size.z)
			var s := u * per
			var x0 := bb.position.x - 0.35
			var x1 := bb.end.x + 0.35
			var z0 := bb.position.z - 0.35
			var z1 := bb.end.z + 0.35
			if s < bb.size.x:
				p = Vector3(x0 + s, y, z0)
			elif s < bb.size.x + bb.size.z:
				p = Vector3(x1, y, z0 + s - bb.size.x)
			elif s < 2.0 * bb.size.x + bb.size.z:
				p = Vector3(x1 - (s - bb.size.x - bb.size.z), y, z1)
			else:
				p = Vector3(x0, y, z1 - (s - 2.0 * bb.size.x - bb.size.z))
		elif key == "finitions":
			p = Vector3(lerpf(-c.w * 0.35, c.w * 0.35, u), 0.0, -c.d / 2.0 + 0.9)
		else:
			var a := u * TAU + float(bid)
			p = Vector3(cx + cos(a) * bb.size.x * 0.32, y, cz + sin(a) * bb.size.z * 0.32)
		f.position = p
		var vers := Vector3(cx, 0, cz) - Vector3(p.x, 0, p.z)
		if key == "finitions":
			vers = Vector3(0, 0, -1)
		f.rotation.y = atan2(vers.x, vers.z)
		mi.add_child(f)
		(c.ouvriers as Array).append(f)


func _finish_chantier(bid: int) -> void:
	var fini_mi := buildings.node_of(bid)
	if fini_mi != null and fini_mi.is_inside_tree():
		Son.jouer_a("chantier_fini", fini_mi.global_position, -4.0, 300.0)
	var c: Dictionary = _chantiers.get(bid, {})
	_chantiers.erase(bid)
	if c.is_empty() or not is_instance_valid(c.mi):
		return
	var mi: MeshInstance3D = c.mi
	mi.remove_meta("chantier")
	mi.material_override = null
	var far := mi.get_node_or_null("Loin") as MeshInstance3D
	if far != null:
		far.material_override = null
	refresh_material(mi)
	# L'usure sera réappliquée au prochain passage.
	if _etat.has(bid):
		_etat[bid].usure = -1.0
	for key in ["echaf", "palissade", "grue", "terre", "dalle", "engins"]:
		if c[key] != null:
			(c[key] as Node).queue_free()
	_vider_ouvriers(c)
	if buildings.buildings.has(bid):
		var b: Dictionary = buildings.buildings[bid]
		b.erase("chantier")
		b.erase("attente")
		b.erase("sans_ouvriers")
		b.erase("pause")
		b.erase("ordre")
		b.erase("av")
		b.erase("hr")
		# Dernier chargement en route vers le chantier qui se termine.
		LivraisonsChantiers.solder(_pos_chantier(b))
		for k in ["matx", "mat_l", "mat_i", "mat_sc"]:
			b.erase(k)
		b["fin"] = now()
		_payer_reste(b)
	# Les habitants peuvent s'installer.
	buildings.changed.emit()


## Termine tout de suite les chantiers en cours (tests, captures, construction instantanée).
func finish_all() -> void:
	for bid in _chantiers.keys():
		_finish_chantier(bid)


## Terre retournée de la fouille, avec ses tas de déblais.
static func _fouille_mesh(bb: AABB, w: float, d: float) -> ArrayMesh:
	var k := BlocMesh.new()
	var cx := bb.get_center().x
	var cz := bb.get_center().z
	k.box(cx, 0.0, cz, bb.size.x + 1.2, 0.12, bb.size.z + 1.2, Color("6b4f35"))
	k.box(cx, 0.0, cz, bb.size.x - 0.6, 0.06, bb.size.z - 0.6, Color("5a412b"))
	var rx := clampf(minf(w, d) * 0.12, 0.8, 3.0)
	EnginsChantier.tas(k, -w / 2.0 + rx + 0.4, d / 2.0 - rx - 0.4, rx)
	EnginsChantier.tas(k, w / 2.0 - rx - 0.4, d / 2.0 - rx * 0.8 - 0.4, rx * 0.7, Color("8a7f72"))
	EnginsChantier.palette(k, -w / 2.0 + 1.2, -d / 2.0 + 1.4)
	EnginsChantier.palette(k, -w / 2.0 + 2.6, -d / 2.0 + 1.4, Color("b5432f"))
	return k.to_mesh(NightWindows.chantier_material())


static func _scaffold_mesh(bb: AABB) -> ArrayMesh:
	var k := BlocMesh.new()
	var x0 := bb.position.x - 0.8
	var x1 := bb.end.x + 0.8
	var z0 := bb.position.z - 0.8
	var z1 := bb.end.z + 0.8
	var H := bb.end.y + 1.0
	var pole := Color("b3b8bf")
	var plank := Color("a07a4a")
	var net := Color("2f7f6f")
	var levels := maxi(1, int(H / 2.0))
	var edges := [[Vector2(x0, z0), Vector2(x1, z0)], [Vector2(x1, z0), Vector2(x1, z1)], [Vector2(x1, z1), Vector2(x0, z1)], [Vector2(x0, z1), Vector2(x0, z0)]]
	var ei := 0
	for e in edges:
		var a: Vector2 = e[0]
		var b: Vector2 = e[1]
		var length := a.distance_to(b)
		var n := maxi(1, int(length / 2.6))
		var along_x := absf(b.x - a.x) > 0.01
		var inward := Vector2(0, 0.45) if (along_x and a.y < (z0 + z1) / 2.0) else (Vector2(0, -0.45) if along_x else (Vector2(0.45, 0) if a.x < (x0 + x1) / 2.0 else Vector2(-0.45, 0)))
		for i in n:
			var p := a.lerp(b, float(i) / n)
			k.box(p.x, 0, p.y, 0.09, H, 0.09, pole)
			k.box(p.x + inward.x * 1.6, 0, p.y + inward.y * 1.6, 0.09, H, 0.09, pole)
		var mid := (a + b) / 2.0
		for l in levels:
			var y := (l + 1) * 2.0
			# Plancher et lisse.
			var c := mid + inward
			k.box(c.x, y - 0.06, c.y, (length if along_x else 0.75), 0.06, (0.75 if along_x else length), plank)
			k.box(mid.x, y + 0.9, mid.y, (length if along_x else 0.06), 0.06, (0.06 if along_x else length), pole)
			k.box(mid.x, y + 0.45, mid.y, (length if along_x else 0.05), 0.05, (0.05 if along_x else length), pole)
			# Filets sur quelques travées.
			for i in n:
				if BlocMesh._hash(Vector3(i, l, ei) * 3.1) < 0.16:
					var p0 := a.lerp(b, float(i) / n)
					var p1 := a.lerp(b, float(i + 1) / n)
					var pm := (p0 + p1) / 2.0 - inward * 0.1
					k.box(pm.x, y - 2.0, pm.y, (p0.distance_to(p1) if along_x else 0.03), 2.0, (0.03 if along_x else p0.distance_to(p1)), net)
		ei += 1
	return k.to_mesh()


static func _palissade_mesh(w: float, d: float) -> ArrayMesh:
	var k := BlocMesh.new()
	var col := Color("d6d9dc")
	var x0 := -w / 2.0 + 0.1
	var x1 := w / 2.0 - 0.1
	var z0 := -d / 2.0 + 0.1
	var z1 := d / 2.0 - 0.1
	for e in [[Vector2(x0, z0), Vector2(x1, z0)], [Vector2(x1, z0), Vector2(x1, z1)], [Vector2(x1, z1), Vector2(x0, z1)], [Vector2(x0, z1), Vector2(x0, z0)]]:
		var a: Vector2 = e[0]
		var b: Vector2 = e[1]
		var n := maxi(1, int(a.distance_to(b) / 3.5))
		for i in n:
			if i == n / 2 and a.y == z0 and b.y == z0:
				continue # entrée du chantier
			var p0 := a.lerp(b, float(i) / n)
			var p1 := a.lerp(b, float(i + 1) / n)
			var pm := (p0 + p1) / 2.0
			var along_x := absf(b.x - a.x) > 0.01
			var length := p0.distance_to(p1) - 0.1
			k.box(pm.x, 0.1, pm.y, (length if along_x else 0.04), 1.9, (0.04 if along_x else length), col)
			k.box(p0.x, 0, p0.y, 0.25, 0.15, 0.6 if along_x else 0.25, Color("8a8f96"))
			if i % 2 == 0:
				k.box(pm.x, 1.2, pm.y, (length * 0.5 if along_x else 0.05), 0.35, (0.05 if along_x else length * 0.5), Color("e8b923"))
	return k.to_mesh()


static func _grue(bb: AABB) -> Node3D:
	var root := Node3D.new()
	root.name = "Grue"
	var H := bb.end.y + 8.0
	var x := bb.end.x + 2.2
	var z := bb.end.z + 2.2
	root.position = Vector3(x, 0, z)
	var yellow := Color("e8b923")
	var k := BlocMesh.new()
	k.box(0, 0, 0, 3.0, 0.8, 3.0, Color("8a8f96"))
	for ox in [-0.8, 0.8]:
		for oz in [-0.8, 0.8]:
			k.box(ox, 0.8, oz, 0.16, H - 0.8, 0.16, yellow)
	var y := 0.8
	while y < H:
		k.box(0, y, -0.8, 1.6, 0.1, 0.1, yellow)
		k.box(0, y, 0.8, 1.6, 0.1, 0.1, yellow)
		k.box(-0.8, y, 0, 0.1, 0.1, 1.6, yellow)
		k.box(0.8, y, 0, 0.1, 0.1, 1.6, yellow)
		y += 2.0
	var mast := MeshInstance3D.new()
	mast.mesh = k.to_mesh(NightWindows.chantier_material())
	root.add_child(mast)
	var jib := Node3D.new()
	jib.name = "Fleche"
	jib.position = Vector3(0, H, 0)
	var kj := BlocMesh.new()
	var reach := clampf(maxf(bb.size.x, bb.size.z) + 6.0, 18.0, 45.0)
	kj.box(0, 0, 0, 2.0, 2.2, 2.0, yellow)
	kj.box(0.9, 0.5, -1.05, 0.2, 1.0, 0.8, Color("6d97b8").darkened(0.4))
	kj.box(0, 2.2, 0, 0.3, 4.0, 0.3, yellow)
	kj.box(-reach / 2.0, 0.9, 0, reach, 0.9, 0.9, yellow)
	kj.box(5.0, 0.9, 0, 10.0, 0.9, 1.2, yellow)
	kj.box(8.5, 0.0, 0, 2.6, 1.8, 1.6, Color("8a8f96"))
	var hook := -reach * 0.6
	kj.box(hook, 0.3, 0, 1.0, 0.6, 1.0, Color("55585e"))
	kj.box(hook, -H * 0.55, 0, 0.04, H * 0.55 + 0.3, 0.04, Color("2b2b2b"))
	kj.box(hook, -H * 0.55 - 0.5, 0, 0.5, 0.5, 0.3, Color("b5432f"))
	kj.box(hook, -H * 0.55 - 1.6, 0, 1.6, 1.1, 1.2, Color("a64b35"))
	var jm := MeshInstance3D.new()
	jm.mesh = kj.to_mesh(NightWindows.chantier_material())
	jib.add_child(jm)
	root.add_child(jib)
	return root


# --- Usure, abords et fumée ------------------------------------------------------------

func _occupe(bid: int) -> bool:
	if population == null:
		return true
	return not (population.by_home.get(bid, []) as Array).is_empty() or not (population.by_job.get(bid, []) as Array).is_empty()


func _habite(bid: int) -> bool:
	return population != null and not (population.by_home.get(bid, []) as Array).is_empty()


func _update_vie() -> void:
	if not vie:
		return
	var t := now()
	for bid in _etat:
		if _chantiers.has(bid) or not buildings.buildings.has(bid):
			continue
		var b: Dictionary = buildings.buildings[bid]
		var e: Dictionary = _etat[bid]
		var mi := buildings.node_of(bid)
		if mi == null:
			continue
		var tt := BuildingCatalog.get_type(String(b.t))
		var accueille := int(tt.get("logements", 0)) + int(tt.get("emplois", 0)) > 0
		var occupe := _occupe(bid)
		# Depuis quand le bâtiment est-il vide ?
		if not accueille or occupe:
			e.vide = -1.0
		elif e.vide < 0.0:
			e.vide = maxf(t, float(b.get("fin", t)))
		# Rénové ou agrandi (Ameliorations) : l'usure repart de la fin des travaux.
		var age := _years(maxf(t - maxf(float(b.get("ne", t)), float(b.get("renov", 0.0))), 0.0))
		var rythme := float(extra_usure.call(bid)) if extra_usure.is_valid() else 1.0
		# Un bâtiment neuf est propre : l'écart propre à chaque bâtiment (base) ne
		# s'installe qu'au fil de ses dix premières années.
		var usure: float = e.base * clampf(age / 10.0, 0.0, 1.0) + age * rythme / (60.0 if occupe or not accueille else 18.0)
		var abandon := 0.0
		if e.vide >= 0.0:
			abandon = clampf((_years(t - float(e.vide)) - 0.5) / 2.0, 0.0, 1.0)
		usure = clampf(usure, 0.0, 1.0)
		# Paliers : quelques matériaux partagés suffisent (et le renderer
		# Compatibilité n'a pas de réglage par objet).
		var qu := roundi(usure * 5.0)
		var qa := roundi(abandon * 4.0)
		if qu != int(e.usure) or qa != int(e.abandon):
			e.usure = qu
			e.abandon = qa
			apply_wear(mi, qu, qa)
		var habite := _habite(bid)
		_set_abords(bid, mi, e, habite)
		_set_fumee(bid, mi, e, habite)


## Matériau d'usure d'un bâtiment (et de sa version lointaine). Les dégâts
## laissés par les événements (métadonnées « ev_degats », « ev_bache »,
## « ev_panne » posées par Evenements) s'y ajoutent.
static func apply_wear(mi: MeshInstance3D, usure_q: int, abandon_q: int) -> void:
	mi.set_meta("usure_q", usure_q)
	mi.set_meta("abandon_q", abandon_q)
	refresh_material(mi)


## Recalcule le matériau d'un bâtiment (usure + dégâts des événements).
## Les modèles Blender (.glb) gardent leurs propres matériaux.
static func refresh_material(mi: MeshInstance3D) -> void:
	# Pendant un chantier, le matériau « en construction » (bâtiment coupé à la
	# hauteur déjà montée) ne doit pas être remplacé, sinon le bâtiment paraît fini
	# (par exemple quand le chantier n'a pas encore d'électricité).
	if mi == null or mi.has_meta("glb") or mi.has_meta("chantier"):
		return
	var u := int(mi.get_meta("usure_q", 0))
	var a := int(mi.get_meta("abandon_q", 0))
	var dq := int(mi.get_meta("ev_degats", 0))
	var bq := int(mi.get_meta("ev_bache", 0))
	var pn := bool(mi.get_meta("ev_panne", false)) or bool(mi.get_meta("res_panne", false))
	var m: Material = null
	if u > 0 or a > 0 or dq > 0 or bq > 0 or pn:
		m = NightWindows.variant_material(u, a, dq, bq, pn)
	mi.material_override = m
	var far := mi.get_node_or_null("Loin") as MeshInstance3D
	if far != null:
		far.material_override = m


func _set_abords(bid: int, mi: MeshInstance3D, e: Dictionary, on: bool) -> void:
	var b: Dictionary = buildings.buildings[bid]
	if on and e.abords == null:
		var m := Abords.mesh_for(String(b.t), NightWindows.building_material())
		if m == null:
			return
		var n := MeshInstance3D.new()
		n.name = "Abords"
		n.mesh = m
		n.visibility_range_end = VUE_ABORDS
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.add_child(n)
		e.abords = n
	elif not on and e.abords != null:
		(e.abords as Node).queue_free()
		e.abords = null


func _set_fumee(bid: int, mi: MeshInstance3D, e: Dictionary, on: bool) -> void:
	var list: Array = e.fumee
	if on and list.is_empty():
		var ancres: Dictionary = mi.mesh.get_meta("ancres", {}) if mi.mesh.has_meta("ancres") else {}
		for p: Vector3 in ancres.get("fumee", []):
			var n := MeshInstance3D.new()
			n.name = "Fumee"
			n.mesh = fumee_mesh()
			n.position = p
			n.visibility_range_end = VUE_FUMEE
			n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			n.custom_aabb = AABB(Vector3(-4, -1, -4), Vector3(8, 9, 8))
			mi.add_child(n)
			list.append(n)
	elif not on and not list.is_empty():
		for n in list:
			(n as Node).queue_free()
		list.clear()


## Bouffées de fumée : petits octaèdres, UV.x = rang de la bouffée.
static func fumee_mesh() -> ArrayMesh:
	if _fumee_mesh != null:
		return _fumee_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 6
	var pts := [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, -1, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]
	var faces := [[0, 2, 4], [4, 2, 1], [1, 2, 5], [5, 2, 0], [4, 3, 0], [1, 3, 4], [5, 3, 1], [0, 3, 5]]
	for i in n:
		var r := 0.5 + 0.2 * sin(i * 2.3)
		var rot := Basis(Vector3.UP, i * 0.9)
		for f in faces:
			var a: Vector3 = rot * pts[f[0]] * r
			var b: Vector3 = rot * pts[f[1]] * r
			var c: Vector3 = rot * pts[f[2]] * r
			var nn := (b - a).cross(c - a).normalized()
			if nn.dot(a + b + c) < 0.0:
				nn = -nn
				var tmp := b
				b = c
				c = tmp
			for v in [a, c, b]:
				st.set_normal(nn)
				st.set_uv(Vector2(float(i) / n, 0))
				st.add_vertex(v)
	_fumee_mesh = st.commit()
	if _fumee_mat == null:
		_fumee_mat = ShaderMaterial.new()
		_fumee_mat.shader = load("res://scripts/batiments/fumee.gdshader")
	_fumee_mesh.surface_set_material(0, _fumee_mat)
	return _fumee_mesh
