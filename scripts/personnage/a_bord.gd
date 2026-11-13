class_name ABord
extends RefCounted
## Monter à bord des véhicules : recherche du véhicule le plus proche, boîte
## englobante, places (conducteur, caméra) et texte du bandeau à bord.
##
## Une « cible » est un dictionnaire :
## - "node" : le Node3D qui porte le véhicule (son avant regarde vers −Z) ;
## - "v" : le véhicule de la circulation (Traffic.vehicles), ou {} ;
## - "nom" : nom affiché ; "box" : boîte englobante dans le repère du nœud.
##
## Deux sources de véhicules :
## - toute la circulation (voitures, bus, tram, trains, bateaux, avions, livraisons,
##   bennes, urgences, corbillards…) : Traffic.vehicles ;
## - tout Node3D du groupe GROUPE (machines agricoles, engins de chantier, engins de
##   mine…). Métas facultatives : "nom_bord" (String), "infos_bord" (String ou
##   Callable sans argument qui rend une String), "siege_bord" (Vector3, place du
##   conducteur dans le repère du nœud) et "avant_plus_z" (vrai si l'avant du
##   modèle regarde vers +Z au lieu de −Z).

const GROUPE := "vehicules_montables"
## Distance (m) entre le personnage et la carrosserie pour monter avec E.
const PORTEE := 3.5
## Distance (m) pour changer de véhicule sans descendre (Maj+E).
const PORTEE_VOISIN := 40.0
## Distance (m) autour du centre de la vue pour Maj+V depuis la vue de dessus.
const PORTEE_DESSUS := 600.0


## Toutes les cibles possibles (véhicules visibles).
static func candidats(trafic: Traffic, arbre: SceneTree) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if trafic != null:
		for v in trafic.vehicles:
			if not montable(v):
				continue
			out.append(cible_trafic(v))
	if arbre != null:
		for n in arbre.get_nodes_in_group(GROUPE):
			var n3 := n as Node3D
			if n3 == null or not n3.is_inside_tree() or not n3.is_visible_in_tree():
				continue
			out.append(cible_noeud(n3))
	return out


## Un véhicule de la circulation où l'on peut monter (pas un piéton).
static func montable(v: Dictionary) -> bool:
	if v.has("sidewalk"):
		return false
	var body := v.get("body") as Node3D
	if body == null or not is_instance_valid(body) or not body.is_inside_tree():
		return false
	if String(v.get("model", "")) == "":
		# Sans modèle : piéton des chemins, ou petit bateau générique.
		return int(v.get("mode", -1)) == TransportTypes.Mode.WATER
	return true


static func cible_trafic(v: Dictionary) -> Dictionary:
	var body: Node3D = v.body
	var model := String(v.get("model", ""))
	var nom := "Bateau"
	if model != "":
		nom = String(VehicleCatalog.get_type(model).get("name", model))
	return {"node": body, "v": v, "nom": nom, "box": boite(body)}


static func cible_noeud(n: Node3D) -> Dictionary:
	var nom := String(n.get_meta("nom_bord", n.name))
	return {"node": n, "v": {}, "nom": nom, "box": boite(n)}


## Boîte englobante des maillages du nœud, dans son propre repère.
static func boite(n: Node3D) -> AABB:
	var res := AABB()
	var vide := true
	var pile: Array[Node] = [n]
	while not pile.is_empty():
		var c: Node = pile.pop_back()
		var mi := c as MeshInstance3D
		if mi != null and mi.mesh != null:
			var rel := n.global_transform.affine_inverse() * mi.global_transform if n.is_inside_tree() else _relatif(n, mi)
			var b := rel * mi.mesh.get_aabb()
			res = b if vide else res.merge(b)
			vide = false
		for e in c.get_children():
			if e is Node3D:
				pile.append(e)
	if vide:
		return AABB(Vector3(-1.0, 0.0, -2.0), Vector3(2.0, 1.6, 4.0))
	return res


static func _relatif(racine: Node3D, n: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var c: Node = n
	while c != null and c != racine:
		if c is Node3D:
			t = (c as Node3D).transform * t
		c = c.get_parent()
	return t


## La cible existe-t-elle encore (pas retirée de la circulation ni libérée) ?
static func valide(c: Dictionary, trafic: Traffic) -> bool:
	if c.is_empty():
		return false
	var o: Variant = c.get("node")
	if o == null or not is_instance_valid(o) or not (o is Node3D) or not (o as Node3D).is_inside_tree():
		return false
	var v: Dictionary = c.get("v", {})
	if not v.is_empty() and (trafic == null or not trafic.vehicles.has(v)):
		return false
	return true


## Distance (m) entre un point et la carrosserie de la cible (0 : dedans).
static func distance(c: Dictionary, p: Vector3) -> float:
	var n: Node3D = c.node
	var b: AABB = c.box
	var l := n.global_transform.affine_inverse() * p
	var q := Vector3(clampf(l.x, b.position.x, b.end.x), clampf(l.y, b.position.y, b.end.y), clampf(l.z, b.position.z, b.end.z))
	return (n.global_transform * q).distance_to(p)


## La cible la plus proche du point p, à moins de portee mètres ({} sinon).
## horizontal : distance mesurée à plat (vue de dessus, avion en vol).
static func plus_proche(liste: Array[Dictionary], p: Vector3, portee: float, sauf: Node = null, horizontal := false) -> Dictionary:
	var best := {}
	var best_d := portee
	for c in liste:
		if c.node == sauf:
			continue
		var q := p
		if horizontal:
			q.y = (c.node as Node3D).global_position.y + 1.0
		var d := distance(c, q)
		if d < best_d:
			best_d = d
			best = c
	return best


## Place du conducteur (repère du véhicule) : à gauche, à l'avant, à hauteur des yeux.
static func siege(c: Dictionary) -> Vector3:
	var n: Node3D = c.node
	if n.has_meta("siege_bord"):
		return n.get_meta("siege_bord")
	var b: AABB = c.box
	var s := b.size
	var x := b.get_center().x - s.x * 0.22 if s.x > 1.2 else b.get_center().x
	var y := b.position.y + clampf(s.y * 0.8, 1.0, maxf(s.y - 0.15, 1.0))
	var z := b.position.z + minf(s.z * 0.3, 2.2) if s.z > 3.0 else b.get_center().z
	return Vector3(x, y, z)


## Distance de la caméra à la 3e personne, selon la taille du véhicule (et de ses wagons).
static func recul(c: Dictionary) -> float:
	var b: AABB = c.box
	var l := maxf(b.size.z, b.size.x)
	var v: Dictionary = c.get("v", {})
	if not v.is_empty() and not (v.get("wagons", []) as Array).is_empty():
		l = maxf(l, float(v.get("rear", l)) * 0.7)
	return clampf(l * 1.3 + 3.0, 6.0, 60.0)


## Cap (rotation y, radians) du véhicule : son avant regarde vers −Z.
## Repère « avant vers −Z » du véhicule (retourné si son modèle regarde vers +Z).
static func repere(n: Node3D) -> Basis:
	var b := n.global_transform.basis.orthonormalized()
	if n.get_meta("avant_plus_z", false):
		b = b * Basis(Vector3.UP, PI)
	return b


static func cap(n: Node3D) -> float:
	var f := n.global_transform.basis.z if n.get_meta("avant_plus_z", false) else -n.global_transform.basis.z
	if Vector2(f.x, f.z).length_squared() < 1e-6:
		return n.global_rotation.y
	return atan2(-f.x, -f.z)


## Ce que fait le véhicule (ligne, prochain arrêt, mission…), pour le bandeau.
static func activite(c: Dictionary, stations: StationSystem) -> String:
	var v: Dictionary = c.get("v", {})
	var n: Node3D = c.node
	if v.is_empty():
		var inf: Variant = n.get_meta("infos_bord", "")
		if inf is Callable and (inf as Callable).is_valid():
			return String((inf as Callable).call())
		return String(inf)
	var arret := float(v.get("dwell", 0.0)) > 0.0
	if v.has("line"):
		var txt := "Ligne"
		var prochain := ""
		if stations != null and stations.lines.has(int(v.line)):
			var l: Dictionary = stations.lines[int(v.line)]
			txt = String(l.name)
			if int(v.get("mode", -1)) == TransportTypes.Mode.AIR:
				var ids: Array = l.stops
				var i := int(v.get("target_i", -1))
				if i >= 0 and i < ids.size() and stations.stations.has(int(ids[i])):
					prochain = String(stations.stations[int(ids[i])].name)
			else:
				var noeuds: Array = v.get("stops", [])
				var i := int(v.get("stop_i", -1))
				if i >= 0 and i < noeuds.size():
					prochain = nom_station(stations, int(noeuds[i]))
		if arret:
			return txt + " · à quai, départ imminent" + (" vers " + prochain if prochain != "" else "")
		return txt + (" · prochain arrêt : " + prochain if prochain != "" else "")
	if v.has("urgence"):
		if v.get("on_site", false):
			return "Urgence · sur les lieux"
		return "Urgence · en intervention, sirène hurlante" if v.get("siren", false) else "Urgence · en service"
	if v.has("delivery"):
		var model := String(v.get("model", ""))
		var quoi := "Collecte des déchets" if model.begins_with("benne_") else ("Convoi funéraire" if model.contains("corbillard") else "Livraison")
		return quoi + (" · arrêt, chargement en cours" if arret else " · en tournée")
	if v.get("parked", false):
		return "Garé · repartira bientôt"
	return "Circulation · trajet au hasard dans la ville"


static func nom_station(stations: StationSystem, noeud: int) -> String:
	for sid in stations.stations:
		if int(stations.stations[sid].get("node", -2)) == noeud:
			return String(stations.stations[sid].name)
	return ""


## Peut-on descendre ici ? Renvoie [vrai/faux, point au sol où poser le personnage, raison].
static func sortie(c: Dictionary, world: TerrainWorld) -> Array:
	var n: Node3D = c.node
	var v: Dictionary = c.get("v", {})
	var b: AABB = c.box
	var mode := int(v.get("mode", -1))
	var p := n.global_position
	var sol := _sol(world, p)
	if mode == TransportTypes.Mode.AIR and not is_nan(sol) and p.y - sol > 3.0:
		return [false, Vector3.ZERO, "On ne descend pas en plein vol : attends l'atterrissage."]
	# À droite du véhicule, puis à gauche, puis tout autour : la première case hors de l'eau.
	var droite := n.global_transform.basis.x.normalized()
	droite.y = 0.0
	droite = droite.normalized() if droite.length_squared() > 1e-6 else Vector3.RIGHT
	var ecart := maxf(b.size.x * 0.5, 0.6) + 0.9
	var essais: Array[Vector3] = [p + droite * ecart, p - droite * ecart]
	for r in [6.0, 12.0, 20.0, 30.0]:
		for k in 12:
			essais.append(p + droite.rotated(Vector3.UP, TAU * k / 12.0) * r)
	var bateau := mode == TransportTypes.Mode.WATER
	for i in essais.size():
		if not bateau and i >= 2:
			break
		var q := essais[i]
		var h := _sol(world, q)
		if is_nan(h) or (bateau and h < TerrainWorld.WATER_LEVEL + 0.05):
			continue
		return [true, Vector3(q.x, maxf(h, TerrainWorld.WATER_LEVEL - 1.3) + 0.05, q.z), ""]
	if mode == TransportTypes.Mode.WATER:
		return [false, Vector3.ZERO, "Pas de quai à portée : attends d'arriver au port."]
	var h0 := sol if not is_nan(sol) else p.y
	return [true, Vector3(p.x, h0 + 0.05, p.z) + droite * ecart, ""]


static func _sol(world: TerrainWorld, p: Vector3) -> float:
	if world == null:
		return NAN
	return world.cell_height(Vector2i(floori(p.x), floori(p.z)))
