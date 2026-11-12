class_name DecorSystem
extends Node3D
## Les décors de la Terre : posés par le joueur (un par un, au pinceau, en
## ligne pour les clôtures) et posés tout seuls pour rendre le monde vivant :
##
## - le long des routes : bancs, corbeilles, bornes, boîtes aux lettres en
##   ville ; poteaux électriques, balises, bornes kilométriques à la campagne ;
##   cédez-le-passage aux carrefours ; bancs le long des chemins ;
## - dans les champs : bottes de foin après la moisson (selon le calendrier
##   des cultures du lieu), tracteurs, épouvantails ;
## - dans les prés : troupeaux (vaches, chevaux, moutons, chèvres ; zébus,
##   dromadaires, lamas ou rennes selon le climat) qui broutent et se
##   promènent, avec leur clôture et leur abreuvoir ;
## - au bord de l'eau : pontons, barques, voiliers, bateaux de pêche, bouées ;
##   parasols et transats sur les plages l'été ;
## - rochers, éboulis, souches et troncs morts en montagne, toundra, désert, forêt.
##
## Tout est déterministe : un même lieu a toujours les mêmes décors. Le
## gomme efface aussi les décors automatiques (et c'est sauvegardé).
## Dessin : un MultiMesh par modèle pour tout ce qui est proche de la caméra.

signal message(text: String)
signal info_changed(text: String)
signal changed

enum Outil { AUCUN, POSER, PINCEAU, GOMME }

## Côté d'une tuile de calcul (m).
const TUILE := 64
## Rayon (m) autour de la caméra où les décors sont calculés et dessinés.
const RAYON := 460.0
## Rayon (m) où les animaux bougent.
const RAYON_ANIMAUX := 220.0
## Pas de la grille du gomme (m).
const PAS_EFFACE := 2

## Décors automatiques (routes, champs, prés, berges, rochers).
static var auto_actif := true

var world: TerrainWorld
var transport: TransportSystem
var buildings: BuildingSystem
var ambiance: DayNight

## Décors posés par le joueur : tuile -> [[id, x, y, z, angle, échelle], ...].
var poses: Dictionary = {}
## Cases (de PAS_EFFACE m) où les décors automatiques sont effacés.
var effaces: Dictionary = {}

var outil := Outil.AUCUN
var choix := "banc_bois"
var angle := 0.0
var rayon_pinceau := 6.0
var densite := 0.5

var _auto: Dictionary = {}      # tuile -> décors automatiques
var _routes: Dictionary = {}    # tuile -> décors le long des voies
var _routes_sales := true
var _routes_timer := 0.0
var _mmi: Dictionary = {}       # id -> MultiMeshInstance3D (décors fixes)
var _mmi_anim: Dictionary = {}  # id -> MultiMeshInstance3D (animaux)
var _animaux: Array = []        # états des animaux proches
var _etats: Dictionary = {}     # clé -> état (garde un animal en route d'une reconstruction à l'autre)
var _focus_dessin := Vector3(INF, 0, INF)
var _sale := true
var _climat := 1
var _graine := 0
var _champs_cle := ""
var _champs_timer := 0.0
var _fantome: MeshInstance3D
var _cercle: MeshInstance3D
var _survol := Vector3.ZERO
var _survol_ok := false
var _glisse := false
var _debut_ligne := Vector3.ZERO
var _pinceau_timer := 0.0


func _ready() -> void:
	_fantome = MeshInstance3D.new()
	_fantome.name = "Fantome"
	var mf := StandardMaterial3D.new()
	mf.albedo_color = Color(0.6, 0.9, 1.0, 0.45)
	mf.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mf.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mf.cull_mode = BaseMaterial3D.CULL_DISABLED
	_fantome.material_override = mf
	_fantome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fantome.visible = false
	add_child(_fantome)
	_cercle = MeshInstance3D.new()
	_cercle.name = "Pinceau"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.0
	cyl.height = 0.15
	cyl.radial_segments = 32
	cyl.rings = 1
	_cercle.mesh = cyl
	var mc := StandardMaterial3D.new()
	mc.albedo_color = Color(1.0, 0.85, 0.3, 0.3)
	mc.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mc.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cercle.material_override = mc
	_cercle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cercle.visible = false
	add_child(_cercle)


## Relie le système au terrain, aux voies et aux bâtiments.
func setup(w: TerrainWorld, t: TransportSystem, b: BuildingSystem, a: DayNight = null) -> void:
	world = w
	transport = t
	buildings = b
	ambiance = a
	world.origin_changed.connect(func(_la: float, _lo: float) -> void: reset_lieu())
	world.terrain_edited.connect(func(_n: int) -> void: _terrain_modifie())
	if transport:
		transport.network_changed.connect(func() -> void: _routes_sales = true)
	if buildings:
		buildings.changed.connect(func() -> void:
			_routes_sales = true
			_auto.clear()
			_sale = true)
	reset_lieu()


## Nouveau lieu : on oublie tout ce qui était calculé (les poses du joueur
## sont rechargées par la sauvegarde).
func reset_lieu() -> void:
	if world == null:
		return
	_climat = Plantes.climat(world.origin_lat, world.origin_lon)
	_graine = hash(Vector2i(roundi(world.origin_lat * 1000.0), roundi(world.origin_lon * 1000.0)))
	_auto.clear()
	_routes_sales = true
	_etats.clear()
	_sale = true


func _terrain_modifie() -> void:
	_auto.clear()
	for k in poses:
		for r: Array in poses[k]:
			r[2] = _hauteur(String(r[0]), r[1], r[3])
	_routes_sales = true
	_sale = true


# --- Calcul des décors automatiques ------------------------------------------------

const _EAUX := [TerrainWorld.Kind.MER, TerrainWorld.Kind.LAC, TerrainWorld.Kind.RIVIERE, TerrainWorld.Kind.ETANG, TerrainWorld.Kind.CANAL]


## Biome d'une case (comme le terrain), -1 si le relief n'est pas encore là.
func _kind(c: Vector2i) -> int:
	if world.water_cells.has(c):
		return TerrainWorld.Kind.CANAL
	if world.biome_paint.has(c):
		return int(world.biome_paint[c])
	var h := world.cell_height(c)
	if is_nan(h):
		return -1
	var bio := world.cell_biome(c)
	if not world.modifications.has(c) and bio != 80:
		var wk := TerrainWorld.stream_kind_id(world.water.width_at(c.x + 0.5, c.y + 0.5), h)
		if wk >= 0:
			return wk
	return TerrainWorld.cell_kind_id(h, world.cell_slope(c), bio)


## Une voie, une station ou un bâtiment occupe la case ?
func _bloque(c: Vector2i) -> bool:
	if world.tree_blocker.is_valid() and world.tree_blocker.call(c):
		return true
	if buildings and buildings.building_at(c) >= 0:
		return true
	return effaces.has(Vector2i(floori(float(c.x) / PAS_EFFACE), floori(float(c.y) / PAS_EFFACE)))


func _efface_a(x: float, z: float) -> bool:
	return effaces.has(Vector2i(floori(x / PAS_EFFACE), floori(z / PAS_EFFACE)))


## Hauteur où poser un décor (dessus de la case, ou surface de l'eau).
func _hauteur(id: String, x: float, z: float) -> float:
	if Decors.sur_eau(id) or (id == "canard" and _kind(Vector2i(floori(x), floori(z))) in _EAUX):
		var s := world.water_surface_at(x, z)
		if not is_nan(s):
			return s
		return world.sea_level()
	var h := world.cell_height(Vector2i(floori(x), floori(z)))
	if is_nan(h):
		return NAN
	return maxf(h, world.sea_level()) if Decors.info(id).get("berge", 0) == 1 else h


## Le jour de l'année du jeu (0 = 1er janvier).
func _jour() -> float:
	return fposmod(world.temps_jours, 365.2425)


## Décors automatiques d'une tuile (sans les voies). null si le relief manque.
func _calcule_tuile(k: Vector2i) -> Variant:
	var out := []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([k, _graine])
	var x0 := k.x * TUILE
	var z0 := k.y * TUILE
	var cultures := Sols.etat_cultures(_jour(), world.origin_lat)
	var couches: PackedInt32Array = cultures.couche
	var tailles: PackedFloat32Array = cultures.taille
	var manque := 0
	var spot_eau := false
	var mois := int(_jour() / 30.44) % 12
	var ete := (mois >= 5 and mois <= 8) if world.origin_lat >= 0.0 else (mois <= 2 or mois == 11)
	if _climat == Plantes.Climat.TROPICAL:
		ete = true
	for i in 8:
		for j in 8:
			var c := Vector2i(x0 + i * 8 + rng.randi_range(0, 7), z0 + j * 8 + rng.randi_range(0, 7))
			var u := rng.randf()
			var v := rng.randf()
			var kind := _kind(c)
			if kind < 0:
				manque += 1
				continue
			if kind in _EAUX or _bloque(c):
				continue
			var p := Vector2(c.x + 0.5, c.y + 0.5)
			var a := v * TAU
			match kind:
				TerrainWorld.Kind.CHAMPS:
					var cu := Sols.culture(c, _climat)
					var rangs := Sols.rangs_tournes(c)
					var ar := (PI / 2.0 if rangs else 0.0) + (v - 0.5) * 0.3
					var fauche: bool = cu == 8 and ete and tailles[8] < 0.75
					if couches[cu] == Sols.CHAUME or fauche:
						if u < 0.45:
							var id := "botte_enrubannee" if fauche and v < 0.4 else ("botte_debout" if v > 0.85 else "botte_ronde")
							out.append([id, p.x, 0.0, p.y, ar, 1.0])
						elif u < 0.47:
							out.append(["pile_bottes", p.x, 0.0, p.y, ar, 1.0])
					elif u < 0.006 and tailles[cu] < 0.3:
						out.append(["tracteur" if v < 0.5 else "tracteur_rouge", p.x, 0.0, p.y, ar, 1.0])
					elif u < 0.012 and (cu == 6 or cu == 3):
						out.append(["epouvantail", p.x, 0.0, p.y, a, 1.0])
				TerrainWorld.Kind.ROCHE:
					if u < 0.08:
						out.append([["eboulis", "bloc_granit", "falaise_bloc", "eboulis"][int(v * 4)], p.x, 0.0, p.y, a, 0.7 + u * 6.0])
				TerrainWorld.Kind.ALPAGE, TerrainWorld.Kind.TOUNDRA:
					if u < 0.025:
						out.append([["bloc_granit", "rocher_moussu", "rocher_plat", "eboulis"][int(v * 4)], p.x, 0.0, p.y, a, 0.6 + u * 20.0])
					elif u < 0.027:
						out.append(["cairn", p.x, 0.0, p.y, a, 1.0])
				TerrainWorld.Kind.DESERT:
					if u < 0.02:
						var rouge := absf(world.origin_lat) < 40.0
						out.append(["rocher_rouge" if rouge and v < 0.6 else "rocher_plat", p.x, 0.0, p.y, a, 0.6 + u * 25.0])
				TerrainWorld.Kind.FORET:
					if u < 0.012:
						out.append([["souche", "tronc_mort", "rocher_moussu", "souche"][int(v * 4)], p.x, 0.0, p.y, a, 1.0])
				TerrainWorld.Kind.PLAGE:
					if ete and u < 0.05 and _climat != Plantes.Climat.BOREAL:
						out.append(["parasol_plage", p.x, 0.0, p.y, a, 1.0])
						out.append(["transat", p.x + cos(a) * 1.6, 0.0, p.y + sin(a) * 1.6, a + 0.4, 1.0])
						if v < 0.3:
							out.append(["transat", p.x + cos(a + 0.5) * 1.6, 0.0, p.y + sin(a + 0.5) * 1.6, a + 0.9, 1.0])
				TerrainWorld.Kind.PRAIRIE:
					if u < 0.0015:
						out.append(["rocher_moussu", p.x, 0.0, p.y, a, 0.6])
			# Bords de l'eau : un ponton et des bateaux (au plus un coin par tuile).
			if not spot_eau and (i + j) % 2 == 0 and rng.randf() < 0.35:
				var bord := _bord_eau(c)
				if bord.ok:
					spot_eau = true
					_pose_bord_eau(out, p, bord, rng)
	if manque > 40:
		return null
	_ajoute_troupeaux(out, k)
	# Hauteurs, et rien sur les cases effacées.
	var garde := []
	for r: Array in out:
		if _efface_a(r[1], r[3]):
			continue
		var c := Vector2i(floori(r[1]), floori(r[3]))
		if not Decors.sur_eau(r[0]) and Decors.info(r[0]).get("berge", 0) != 1 and _bloque(c):
			continue
		r[2] = _hauteur(String(r[0]), r[1], r[3])
		if not is_nan(r[2]):
			garde.append(r)
	return garde


## Eau à quelques mètres de la case c ? Renvoie {ok, dir (vers l'eau), mer}.
func _bord_eau(c: Vector2i) -> Dictionary:
	var h := world.cell_height(c)
	if is_nan(h):
		return {"ok": false}
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var k1 := _kind(c + d * 3)
		if k1 in _EAUX:
			var k2 := _kind(c + d * 12)
			if k2 in _EAUX and k2 != TerrainWorld.Kind.RIVIERE or k1 == TerrainWorld.Kind.MER:
				return {"ok": true, "dir": Vector2(d), "mer": k1 == TerrainWorld.Kind.MER, "kind": k1}
	return {"ok": false}


func _pose_bord_eau(out: Array, p: Vector2, bord: Dictionary, rng: RandomNumberGenerator) -> void:
	var d: Vector2 = bord.dir
	var cote := Vector2(-d.y, d.x)
	var ang := atan2(d.x, d.y) # l'avant (+Z local) du ponton vers l'eau
	var mer: bool = bord.mer
	# La rive exacte : première case d'eau en partant de p vers l'eau.
	var rive := p + d * 3.0
	for i in 12:
		var q := p + d * float(i)
		if _kind(Vector2i(floori(q.x), floori(q.y))) in _EAUX:
			rive = q
			break
	var berge := rive - d * 1.5
	if rng.randf() < 0.65:
		var long := mer or rng.randf() < 0.45
		out.append(["ponton" if long else "ponton_court", berge.x, 0.0, berge.y, ang, 1.0])
		var L := 8.0 if long else 3.2
		var bat: String
		if mer:
			bat = ["bateau_peche", "voilier_ancre", "bateau_moteur", "barque"][rng.randi_range(0, 3)]
		else:
			bat = ["barque", "barque", "pedalo", "kayak", "bateau_moteur"][rng.randi_range(0, 4)]
		var w: Array = Decors.info(bat).get("taille", [2, 4, 1])
		# Amarré le long du ponton, la proue vers le large.
		var bp := berge + d * (L * 0.55 + 1.5) + cote * (1.3 + float(w[0]) * 0.5)
		out.append([bat, bp.x, 0.0, bp.y, ang, 1.0])
	else:
		var bp := rive + d * 4.0
		out.append(["barque" if not mer else "kayak", bp.x, 0.0, bp.y, rng.randf() * TAU, 1.0])
	if mer:
		var lp := rive + d * (25.0 + rng.randf() * 25.0) + cote * (rng.randf() - 0.5) * 20.0
		out.append(["voilier" if rng.randf() < 0.5 else "voilier_ancre", lp.x, 0.0, lp.y, rng.randf() * TAU, 1.0])
		var bp2 := rive + d * 16.0 - cote * 8.0
		out.append(["bouee", bp2.x, 0.0, bp2.y, 0.0, 1.0])
		var ca := berge - d * 2.0 + cote * 3.0
		out.append(["casiers", ca.x, 0.0, ca.y, ang, 1.0])
	elif rng.randf() < 0.6:
		var cp := rive + d * 7.0 - cote * 4.0
		for i in 3:
			out.append(["canard", cp.x + i * 0.8, 0.0, cp.y + (i % 2) * 0.6, rng.randf() * TAU, 1.0])
	if not mer and rng.randf() < 0.5:
		var bc := berge - d * 3.0 - cote * 4.0
		out.append(["banc_bois", bc.x, 0.0, bc.y, ang + PI, 1.0])


# --- Troupeaux -------------------------------------------------------------------

const PATURES := [TerrainWorld.Kind.PRAIRIE, TerrainWorld.Kind.ALPAGE, TerrainWorld.Kind.TOUNDRA, TerrainWorld.Kind.BROUSSAILLES, TerrainWorld.Kind.DESERT]
const PARC := 96


## Les espèces d'un troupeau selon le biome et le climat : [[id, poids]...], clôture.
func _especes(kind: int, h: float) -> Array:
	var amer := world.origin_lon < -30.0
	if kind == TerrainWorld.Kind.DESERT:
		return [[["dromadaire", 1]] if not amer else [["chevre", 1]], ""]
	if kind == TerrainWorld.Kind.TOUNDRA or _climat == Plantes.Climat.BOREAL:
		return [[["renne", 1]], ""]
	if kind == TerrainWorld.Kind.ALPAGE or h > 1500.0:
		if amer and world.origin_lat < 0.0:
			return [[["lama", 1]], ""]
		if absf(world.origin_lon - 87.0) < 20.0 and world.origin_lat > 25.0:
			return [[["yack", 1]], ""]
		return [[["brebis", 3], ["mouton_broute", 3], ["agneau", 1]], ""] if h > 1900.0 else [[["vache_rousse", 2], ["vache_broute_rousse", 2], ["veau", 1]], "cloture_barbelee"]
	if kind == TerrainWorld.Kind.BROUSSAILLES:
		return [[["chevre", 2], ["brebis", 1]], ""]
	if _climat == Plantes.Climat.TROPICAL or (_climat == Plantes.Climat.SUBTROPICAL and not amer):
		return [[["zebu", 3], ["chevre", 1]], ""]
	if _climat == Plantes.Climat.MEDITERRANEEN:
		return [[["brebis", 3], ["mouton_broute", 2], ["chevre", 1], ["agneau", 1]], ""]
	return []


## Ajoute les animaux des troupeaux dont le pré touche la tuile k.
func _ajoute_troupeaux(out: Array, k: Vector2i) -> void:
	var rect := Rect2(k.x * TUILE, k.y * TUILE, TUILE, TUILE)
	var p0 := Vector2i(floori(rect.position.x / PARC), floori(rect.position.y / PARC))
	var p1 := Vector2i(floori(rect.end.x / PARC), floori(rect.end.y / PARC))
	for px in range(p0.x, p1.x + 1):
		for pz in range(p0.y, p1.y + 1):
			var rng := RandomNumberGenerator.new()
			rng.seed = hash([px, pz, _graine, 7])
			var centre := Vector2i(px * PARC + PARC / 2, pz * PARC + PARC / 2)
			var kind := _kind(centre)
			if not (kind in PATURES):
				continue
			var proba := {TerrainWorld.Kind.PRAIRIE: 0.22, TerrainWorld.Kind.ALPAGE: 0.18, TerrainWorld.Kind.TOUNDRA: 0.06, TerrainWorld.Kind.BROUSSAILLES: 0.06, TerrainWorld.Kind.DESERT: 0.03}
			if rng.randf() > float(proba[kind]):
				continue
			var h := world.cell_height(centre)
			var esp := _especes(kind, h)
			var cloture := "cloture_ranch"
			if esp.is_empty():
				# Tempéré : vaches, chevaux ou moutons.
				var r := rng.randf()
				if r < 0.5:
					esp = [[["vache_pie_noire", 3], ["vache_broute", 3], ["vache_blanche", 2], ["veau", 1]], "cloture_barbelee"]
				elif r < 0.72:
					esp = [[["cheval", 3], ["cheval_blanc", 2], ["cheval_noir", 1], ["poney", 1], ["ane", 1]], "cloture_ranch"]
				else:
					esp = [[["brebis", 3], ["mouton_broute", 3], ["agneau", 2]], "cloture_barbelee"]
			var especes: Array = esp[0]
			cloture = esp[1]
			var total := 0
			for e: Array in especes:
				total += int(e[1])
			var n := rng.randi_range(5, 14)
			var demi := 26.0
			for i in n:
				var q := Vector2(centre) + Vector2(rng.randf_range(-demi, demi), rng.randf_range(-demi, demi))
				var t := rng.randi_range(0, total - 1)
				var id := ""
				for e: Array in especes:
					t -= int(e[1])
					if t < 0:
						id = e[0]
						break
				var cq := Vector2i(floori(q.x), floori(q.y))
				if rect.has_point(q) and _kind(cq) == kind and not _bloque(cq):
					out.append([id, q.x, 0.0, q.y, rng.randf() * TAU, rng.randf_range(0.92, 1.08)])
			# Abreuvoir près du centre, clôture autour du pré (sauf alpage, désert, toundra).
			var ab := Vector2(centre) + Vector2(6, 3)
			if cloture != "" and rect.has_point(ab):
				out.append(["abreuvoir", ab.x, 0.0, ab.y, 0.3, 1.0])
			if cloture != "":
				var b := demi + 8.0
				for cote in 4:
					for s in range(-int(b), int(b), 2):
						var q: Vector2
						var ang := 0.0
						match cote:
							0: q = Vector2(centre) + Vector2(s + 1, -b)
							1: q = Vector2(centre) + Vector2(s + 1, b)
							2:
								q = Vector2(centre) + Vector2(-b, s + 1)
								ang = PI / 2.0
							3:
								q = Vector2(centre) + Vector2(b, s + 1)
								ang = PI / 2.0
						if cote == 0 and absi(s) < 3:
							continue # l'entrée du pré
						var cq := Vector2i(floori(q.x), floori(q.y))
						if rect.has_point(q) and _kind(cq) == kind and not _bloque(cq):
							out.append([cloture, q.x, 0.0, q.y, ang, 1.0])


# --- Décors des voies ----------------------------------------------------------------

## Un bâtiment à moins de ~18 m ? (on est en ville)
func _en_ville(p: Vector3) -> bool:
	if buildings == null:
		return false
	for d: Vector2 in [Vector2(14, 0), Vector2(-14, 0), Vector2(0, 14), Vector2(0, -14), Vector2(10, 10), Vector2(-10, -10), Vector2(10, -10), Vector2(-10, 10)]:
		if buildings.building_at(Vector2i(floori(p.x + d.x), floori(p.z + d.y))) >= 0:
			return true
	return false


func _ajoute_route(r: Array) -> void:
	var k := Vector2i(floori(r[1] / TUILE), floori(r[3] / TUILE))
	if not _routes.has(k):
		_routes[k] = []
	(_routes[k] as Array).append(r)


## Décors le long de tout le réseau (recalculé quand il change).
func _calcule_routes() -> void:
	_routes.clear()
	_routes_sales = false
	if transport == null:
		_sale = true
		return
	var net := transport.network
	var trims := TransportView.compute_trims(net)
	for id in net.edges:
		var e: Dictionary = net.edges[id]
		var mode := TransportTypes.mode_of(e.t)
		if mode != TransportTypes.Mode.ROAD and mode != TransportTypes.Mode.PATH:
			continue
		var route := mode == TransportTypes.Mode.ROAD
		var width := float(e.width)
		var length := float(e.len)
		var tr: Vector2 = trims.get(id, Vector2.ZERO)
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([int(id), _graine])
		var pas := 36.0 if route else 70.0
		var s := 11.0 + rng.randf() * 10.0
		var n := 0
		while s < length - 6.0:
			n += 1
			var s_ici := s
			s += pas
			if s_ici < tr.x + 6.0 or s_ici > length - tr.y - 6.0:
				continue
			if net.struct_at(id, s_ici) != TransportTypes.Struct.GROUND:
				continue
			var p := net.point_at(id, s_ici)
			var t := net.tangent_at(id, s_ici)
			t.y = 0.0
			if t.length_squared() < 0.0001:
				continue
			t = t.normalized()
			var droite := Vector3(-t.z, 0.0, t.x)
			var ville := _en_ville(p)
			var cote := 1.0 if n % 2 == 0 else -1.0
			var nrm := droite * cote
			var q := p + nrm * (width / 2.0 + 0.9)
			var face := atan2(-nrm.x, -nrm.z) # l'avant regarde la voie
			var u := rng.randf()
			var id_d := ""
			if ville:
				if route:
					id_d = "banc_vert" if u < 0.3 else ("poubelle" if u < 0.5 else ("borne_incendie" if u < 0.58 else
						("boite_aux_lettres" if u < 0.63 else ("jardiniere" if u < 0.7 else ("arceaux_velo" if u < 0.75 else
						("potelets" if u < 0.82 else ""))))))
				else:
					id_d = "banc_bois" if u < 0.5 else ("poubelle" if u < 0.7 else "")
			else:
				if route:
					# Poteaux électriques d'un seul côté, balises de part et d'autre.
					var pe := p + droite * (width / 2.0 + 3.0)
					_ajoute_route(["poteau_electrique", pe.x, p.y, pe.z, atan2(t.x, t.z) + PI / 2.0, 1.0])
					if n % 2 == 0:
						for sg: float in [-1.0, 1.0]:
							var pb := p + droite * sg * (width / 2.0 + 0.6)
							_ajoute_route(["balise", pb.x, p.y, pb.z, atan2(-droite.x * sg, -droite.z * sg), 1.0])
					if n % 28 == 0:
						var pk := p - droite * (width / 2.0 + 1.0)
						_ajoute_route(["borne_km", pk.x, p.y, pk.z, atan2(droite.x, droite.z), 1.0])
				else:
					id_d = "banc_bois" if u < 0.3 else ("poubelle" if u < 0.4 else ("table_pique_nique" if u < 0.45 else ""))
					q = p + nrm * (width / 2.0 + 1.6)
			if id_d != "":
				_ajoute_route([id_d, q.x, p.y, q.z, face, 1.0])
	# Cédez-le-passage aux carrefours (une route sur deux).
	for nid in net.nodes:
		if net.degree(nid) < 3 or net.node_mode(nid) != TransportTypes.Mode.ROAD:
			continue
		var i := 0
		for eid in net.adjacency[nid]:
			i += 1
			var e: Dictionary = net.edges[eid]
			if TransportTypes.mode_of(e.t) != TransportTypes.Mode.ROAD or (i + int(nid)) % 2 == 0:
				continue
			var d := net.leave_dir(eid, nid)
			d.y = 0.0
			if d.length_squared() < 0.001:
				continue
			d = d.normalized()
			var droite := Vector3(-d.z, 0.0, d.x)
			var tr: Vector2 = trims.get(eid, Vector2.ZERO)
			var recul := maxf(tr.x if int(e.a) == int(nid) else tr.y, 4.0) + 2.0
			var pp := net.node_pos(nid) + d * recul - droite * (float(e.width) / 2.0 + 0.6)
			_ajoute_route(["panneau_cedez", pp.x, pp.y, pp.z, atan2(d.x, d.z), 1.0])
	# Hauteur du sol à côté de la voie (la voie peut être sur un remblai).
	for k in _routes:
		var garde := []
		for r: Array in _routes[k]:
			if _efface_a(r[1], r[3]):
				continue
			var c := Vector2i(floori(r[1]), floori(r[3]))
			if buildings and buildings.building_at(c) >= 0:
				continue
			var h := world.cell_height(c)
			if not is_nan(h) and absf(h - r[2]) < 3.0:
				r[2] = h
			garde.append(r)
		_routes[k] = garde
	_sale = true


# --- Dessin --------------------------------------------------------------------------

func _focus() -> Vector3:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return Vector3.ZERO
	var p := cam.global_position
	var f := cam.get_parent()
	while f and not (f is Node3D and f.name == "CameraRig"):
		f = f.get_parent()
	if f is Node3D:
		p = (f as Node3D).global_position
	return p


func _process(delta: float) -> void:
	if world == null:
		return
	Decors.set_nuit(ambiance.street.night if ambiance and ambiance.street else 0.0)
	if _routes_sales:
		_routes_timer += delta
		if _routes_timer > 0.4:
			_routes_timer = 0.0
			_calcule_routes()
	_champs_timer -= delta
	if _champs_timer <= 0.0:
		_champs_timer = 2.0
		var cu := Sols.etat_cultures(_jour(), world.origin_lat)
		var cle := str(cu.couche) + str(int(_jour() / 30.44))
		if cle != _champs_cle:
			if _champs_cle != "":
				_auto.clear()
				_sale = true
			_champs_cle = cle
	var f := _focus()
	# Les tuiles manquantes, les plus proches d'abord, avec un budget de temps.
	if auto_actif:
		var t0 := Time.get_ticks_usec()
		var kc := Vector2i(floori(f.x / TUILE), floori(f.z / TUILE))
		var n := ceili(RAYON / TUILE)
		var faites := 0
		for anneau in n + 1:
			for dx in range(-anneau, anneau + 1):
				for dz in range(-anneau, anneau + 1):
					if maxi(absi(dx), absi(dz)) != anneau:
						continue
					var k := kc + Vector2i(dx, dz)
					if _auto.has(k):
						continue
					var centre := Vector3((k.x + 0.5) * TUILE, f.y, (k.y + 0.5) * TUILE)
					if Vector2(centre.x - f.x, centre.z - f.z).length() > RAYON + TUILE * 0.7:
						continue
					if Time.get_ticks_usec() - t0 > 3500:
						break
					var r: Variant = _calcule_tuile(k)
					if r != null:
						_auto[k] = r
						faites += 1
		if faites > 0:
			_sale = true
		# On oublie les tuiles lointaines.
		if _auto.size() > 400:
			for k: Vector2i in _auto.keys():
				if Vector2((k.x + 0.5) * TUILE - f.x, (k.y + 0.5) * TUILE - f.z).length() > RAYON + TUILE * 3:
					_auto.erase(k)
	if _sale or Vector2(f.x - _focus_dessin.x, f.z - _focus_dessin.z).length() > 24.0:
		_dessine(f)
	_anime(delta)
	_maj_outil(delta)


## Remplit les MultiMesh avec tout ce qui est assez proche de la caméra.
func _dessine(f: Vector3) -> void:
	_sale = false
	_focus_dessin = f
	var listes := {}
	var anim := {}
	var kc := Vector2i(floori(f.x / TUILE), floori(f.z / TUILE))
	var n := ceili(RAYON / TUILE)
	var sources: Array = [poses, _routes]
	if auto_actif:
		sources.append(_auto)
	else:
		sources = [poses]
	for dx in range(-n, n + 1):
		for dz in range(-n, n + 1):
			var k := kc + Vector2i(dx, dz)
			for src: Dictionary in sources:
				if not src.has(k):
					continue
				for r: Array in src[k]:
					var id: String = r[0]
					if is_nan(float(r[2])):
						r[2] = _hauteur(id, r[1], r[3])
						if is_nan(float(r[2])):
							continue
					var d := Vector2(r[1] - f.x, r[3] - f.z).length()
					if d > Decors.distance_vue(id):
						continue
					if Decors.est_anime(id) and d < RAYON_ANIMAUX:
						if not anim.has(id):
							anim[id] = []
						(anim[id] as Array).append(r)
						continue
					if not listes.has(id):
						listes[id] = []
					(listes[id] as Array).append(r)
	for id in _mmi.keys():
		if not listes.has(id) and _mmi[id]:
			(_mmi[id] as MultiMeshInstance3D).multimesh.instance_count = 0
	for id: String in listes:
		var mmi := _mmi_de(_mmi, id)
		if mmi == null:
			continue
		var l: Array = listes[id]
		var mm := mmi.multimesh
		mm.instance_count = l.size()
		for i in l.size():
			var r: Array = l[i]
			mm.set_instance_transform(i, _xform(r[1], r[2], r[3], r[4], r[5]))
	# Animaux : on garde l'état de ceux qui restent.
	var etats := {}
	_animaux.clear()
	for id: String in anim:
		for r: Array in anim[id]:
			var cle := "%s@%d,%d" % [id, roundi(r[1] * 10.0), roundi(r[3] * 10.0)]
			var e: Dictionary = _etats.get(cle, {})
			if e.is_empty():
				var g := hash(cle)
				e = {"id": id, "home": Vector2(r[1], r[3]), "pos": Vector2(r[1], r[3]), "cible": Vector2(r[1], r[3]),
					"ang": float(r[4]), "y": float(r[2]), "sc": float(r[5]), "pause": float(g % 1000) / 100.0,
					"vit": 0.6 if id.begins_with("cheval") or id == "poney" or id == "chien" else (0.25 if id.begins_with("vache") or id == "zebu" or id == "yack" else 0.35),
					"g": g, "case": Vector2i(floori(r[1]), floori(r[3]))}
			etats[cle] = e
			_animaux.append(e)
	_etats = etats
	for id in _mmi_anim.keys():
		if _mmi_anim[id]:
			(_mmi_anim[id] as MultiMeshInstance3D).multimesh.instance_count = 0
	var compte := {}
	for e: Dictionary in _animaux:
		compte[e.id] = int(compte.get(e.id, 0)) + 1
	for id: String in compte:
		var mmi := _mmi_de(_mmi_anim, id)
		if mmi:
			mmi.multimesh.instance_count = compte[id]
	_anime(0.0, true)


func _mmi_de(d: Dictionary, id: String) -> MultiMeshInstance3D:
	if d.has(id):
		return d[id]
	var m := Decors.mesh(id)
	if m == null:
		d[id] = null
		return null
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = m
	var mmi := MultiMeshInstance3D.new()
	mmi.name = id
	mmi.multimesh = mm
	mmi.material_override = Decors.materiau()
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if Decors.hauteur(id) > 0.6 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	d[id] = mmi
	return mmi


static func _xform(x: float, y: float, z: float, ang: float, sc: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, ang).scaled(Vector3.ONE * sc), Vector3(x, y, z))


## Les animaux broutent, puis marchent un peu autour de leur place.
func _anime(delta: float, force := false) -> void:
	if _animaux.is_empty():
		return
	var idx := {}
	for e: Dictionary in _animaux:
		if delta > 0.0:
			if e.pause > 0.0:
				e.pause -= delta
			else:
				var pos: Vector2 = e.pos
				var cible: Vector2 = e.cible
				var to := cible - pos
				if to.length() < 0.2:
					e.g = (int(e.g) * 1103515245 + 12345) & 0x7fffffff
					var gg := int(e.g)
					e.pause = 4.0 + float(gg % 1300) / 100.0
					var home: Vector2 = e.home
					var nc := home + Vector2(float(gg % 1600) / 100.0 - 8.0, float((gg >> 11) % 1600) / 100.0 - 8.0)
					var cc := Vector2i(floori(nc.x), floori(nc.y))
					if not _bloque(cc) and not (_kind(cc) in _EAUX):
						e.cible = nc
				else:
					var dir := to.normalized()
					var voulu := atan2(dir.x, dir.y)
					e.ang = lerp_angle(float(e.ang), voulu, minf(1.0, delta * 2.5))
					pos += Vector2(sin(float(e.ang)), cos(float(e.ang))) * float(e.vit) * delta
					e.pos = pos
					var c := Vector2i(floori(pos.x), floori(pos.y))
					if c != e.case:
						e.case = c
						var h := world.cell_height(c)
						if not is_nan(h):
							e.y = h
		var mmi: MultiMeshInstance3D = _mmi_anim.get(e.id)
		var i := int(idx.get(e.id, 0))
		idx[e.id] = i + 1
		if mmi and i < mmi.multimesh.instance_count:
			var p: Vector2 = e.pos
			mmi.multimesh.set_instance_transform(i, _xform(p.x, e.y, p.y, e.ang, e.sc))


## Nombre de décors dessinés (fixes + animaux).
func nombre_dessines() -> int:
	var n := _animaux.size()
	for id in _mmi:
		if _mmi[id]:
			n += (_mmi[id] as MultiMeshInstance3D).multimesh.instance_count
	return n


## Nombre de décors dessinés d'un modèle.
func nombre_de(id: String) -> int:
	var n := 0
	if _mmi.get(id):
		n += (_mmi[id] as MultiMeshInstance3D).multimesh.instance_count
	for e: Dictionary in _animaux:
		if e.id == id:
			n += 1
	return n


## Force le calcul de tout ce qui entoure p (tests, captures).
func calcule_autour(p: Vector3) -> void:
	if _routes_sales:
		_calcule_routes()
	var kc := Vector2i(floori(p.x / TUILE), floori(p.z / TUILE))
	var n := ceili(RAYON / TUILE)
	for dx in range(-n, n + 1):
		for dz in range(-n, n + 1):
			var k := kc + Vector2i(dx, dz)
			if not _auto.has(k):
				var r: Variant = _calcule_tuile(k)
				if r != null:
					_auto[k] = r
	_dessine(p)


# --- Pose par le joueur --------------------------------------------------------------

## Pose un décor (x, z au sol). Renvoie false si impossible.
## force : garde le décor même si le relief n'est pas encore chargé (sauvegarde).
func pose(id: String, x: float, z: float, ang := 0.0, sc := 1.0, force := false) -> bool:
	if not Decors.existe(id):
		return false
	var y := _hauteur(id, x, z)
	if is_nan(y) and not force:
		return false
	var k := Vector2i(floori(x / TUILE), floori(z / TUILE))
	if not poses.has(k):
		poses[k] = []
	(poses[k] as Array).append([id, snappedf(x, 0.01), y, snappedf(z, 0.01), snappedf(fposmod(ang, TAU), 0.001), snappedf(sc, 0.01)])
	_sale = true
	changed.emit()
	return true


## Pose une clôture (ou tout décor) en ligne de a à b. Renvoie le nombre posé.
func pose_ligne(id: String, a: Vector3, b: Vector3) -> int:
	var L := Decors.ligne(id)
	var pas := L if L > 0.0 else maxf(Decors.emprise(id) * 1.2, 1.0)
	var d := Vector2(b.x - a.x, b.z - a.z)
	var long := d.length()
	if long < 0.5:
		return 1 if pose(id, a.x, a.z, angle) else 0
	var dir := d / long
	var ang := atan2(dir.y, dir.x) * -1.0 # le tronçon court le long de X local
	var n := maxi(1, roundi(long / pas))
	var posees := 0
	for i in n:
		var t := (i + 0.5) * pas
		var p := Vector2(a.x, a.z) + dir * t
		if pose(id, p.x, p.y, ang):
			posees += 1
	return posees


## Efface les décors posés et automatiques dans un rayon. Renvoie le nombre de décors posés retirés.
func efface(centre: Vector3, r: float) -> int:
	var n := 0
	var k0 := Vector2i(floori((centre.x - r) / TUILE), floori((centre.z - r) / TUILE))
	var k1 := Vector2i(floori((centre.x + r) / TUILE), floori((centre.z + r) / TUILE))
	for kx in range(k0.x, k1.x + 1):
		for kz in range(k0.y, k1.y + 1):
			var k := Vector2i(kx, kz)
			if not poses.has(k):
				continue
			var garde := []
			for rr: Array in poses[k]:
				if Vector2(rr[1] - centre.x, rr[3] - centre.z).length() <= r + 0.5:
					n += 1
				else:
					garde.append(rr)
			poses[k] = garde
	var e := ceili(r / PAS_EFFACE)
	var ce := Vector2i(floori(centre.x / PAS_EFFACE), floori(centre.z / PAS_EFFACE))
	for dx in range(-e, e + 1):
		for dz in range(-e, e + 1):
			if Vector2(dx, dz).length() * PAS_EFFACE <= r + 1.0:
				effaces[ce + Vector2i(dx, dz)] = true
	# Les tuiles touchées sont recalculées sans ces cases.
	for kx in range(k0.x, k1.x + 1):
		for kz in range(k0.y, k1.y + 1):
			_auto.erase(Vector2i(kx, kz))
	_routes_sales = true
	_sale = true
	changed.emit()
	return n


## Remet les décors automatiques effacés dans un rayon.
func restaure(centre: Vector3, r: float) -> void:
	for c: Vector2i in effaces.keys():
		if Vector2((c.x + 0.5) * PAS_EFFACE - centre.x, (c.y + 0.5) * PAS_EFFACE - centre.z).length() <= r:
			effaces.erase(c)
	_auto.clear()
	_routes_sales = true
	_sale = true


func nombre_poses() -> int:
	var n := 0
	for k in poses:
		n += (poses[k] as Array).size()
	return n


# --- Outils ---------------------------------------------------------------------------

func set_outil(o: Outil) -> void:
	outil = o
	_glisse = false
	_maj_fantome()
	_aide()


func set_choix(id: String) -> void:
	choix = id
	if outil == Outil.AUCUN or outil == Outil.GOMME:
		outil = Outil.POSER
	_maj_fantome()
	_aide()


func set_inactive() -> void:
	outil = Outil.AUCUN
	_glisse = false
	_fantome.visible = false
	_cercle.visible = false


func _maj_fantome() -> void:
	_fantome.mesh = Decors.mesh(choix) if outil == Outil.POSER else null
	_fantome.visible = outil == Outil.POSER and _survol_ok
	_cercle.visible = (outil == Outil.PINCEAU or outil == Outil.GOMME) and _survol_ok


func _aide() -> void:
	match outil:
		Outil.POSER:
			if Decors.ligne(choix) > 0.0:
				info_changed.emit("%s : clic glissé pour tracer la clôture. R : tourner." % Decors.nom(choix))
			else:
				info_changed.emit("%s : clic pour poser, R / Maj+R pour tourner, glisser pour une rangée." % Decors.nom(choix))
		Outil.PINCEAU:
			info_changed.emit("Pinceau (%s) : glisser pour semer des décors au hasard." % Decors.nom(choix))
		Outil.GOMME:
			info_changed.emit("Gomme : glisser pour effacer les décors, posés ou automatiques.")
		_:
			info_changed.emit("")


func _pick(pos: Vector2) -> Variant:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return null
	return world.pick_point(cam.project_ray_origin(pos), cam.project_ray_normal(pos))


func _unhandled_input(event: InputEvent) -> void:
	if outil == Outil.AUCUN or world == null:
		return
	if event is InputEventMouseMotion:
		var p: Variant = _pick((event as InputEventMouseMotion).position)
		_survol_ok = p != null
		if p != null:
			_survol = p
		_maj_fantome()
	elif event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if k.physical_keycode == KEY_R and outil == Outil.POSER:
			angle += deg_to_rad(-15.0 if k.shift_pressed else 45.0)
			get_viewport().set_input_as_handled()
		elif k.physical_keycode == KEY_ESCAPE:
			set_inactive()
			_aide()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		var p: Variant = _pick(mb.position)
		if mb.pressed and p != null:
			_glisse = true
			_debut_ligne = p
			_pinceau_timer = 0.0
			if outil == Outil.GOMME:
				efface(p, rayon_pinceau)
			elif outil == Outil.PINCEAU:
				_seme(p)
			get_viewport().set_input_as_handled()
		elif not mb.pressed and _glisse:
			_glisse = false
			if outil == Outil.POSER and p != null:
				var a: Vector3 = _debut_ligne
				var b: Vector3 = p
				var n := 0
				if Vector2(b.x - a.x, b.z - a.z).length() > 1.5:
					n = pose_ligne(choix, a, b)
				elif pose(choix, a.x, a.z, angle, 1.0):
					n = 1
				message.emit("%d × %s posé%s." % [n, Decors.nom(choix), "s" if n > 1 else ""] if n > 0 else "Impossible de poser ici.")
			get_viewport().set_input_as_handled()


func _maj_outil(delta: float) -> void:
	if outil == Outil.AUCUN:
		return
	if _fantome.visible:
		var y := _survol.y
		if Decors.sur_eau(choix):
			y = _hauteur(choix, _survol.x, _survol.z)
		_fantome.transform = _xform(_survol.x, y, _survol.z, angle, 1.0)
	if _cercle.visible:
		_cercle.transform = Transform3D(Basis().scaled(Vector3(rayon_pinceau, 1.0, rayon_pinceau)), _survol + Vector3(0, 0.1, 0))
	if _glisse and (outil == Outil.PINCEAU or outil == Outil.GOMME):
		_pinceau_timer += delta
		if _pinceau_timer > 0.12 and _survol_ok:
			_pinceau_timer = 0.0
			if outil == Outil.GOMME:
				efface(_survol, rayon_pinceau)
			else:
				_seme(_survol)


## Pinceau : sème quelques exemplaires du décor choisi, sans trop les serrer.
func _seme(centre: Vector3) -> void:
	var ecart := maxf(Decors.emprise(choix) * 1.1, 1.2)
	var essais := maxi(1, roundi(densite * 4.0))
	var k := Vector2i(floori(centre.x / TUILE), floori(centre.z / TUILE))
	for i in essais:
		var a := randf() * TAU
		var r := sqrt(randf()) * rayon_pinceau
		var x := centre.x + cos(a) * r
		var z := centre.z + sin(a) * r
		var libre := true
		for dk in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			for rr: Array in poses.get(k + dk, []):
				if Vector2(rr[1] - x, rr[3] - z).length() < ecart:
					libre = false
					break
		var c := Vector2i(floori(x), floori(z))
		if libre and not _bloque(c):
			pose(choix, x, z, randf() * TAU, randf_range(0.9, 1.1))


# --- Sauvegarde -------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var l := []
	for k in poses:
		for r: Array in poses[k]:
			l.append([r[0], r[1], r[3], r[4], r[5]])
	var e := []
	for c: Vector2i in effaces:
		e.append([c.x, c.y])
	return {"poses": l, "effaces": e, "auto": auto_actif}


func from_dict(d: Dictionary) -> void:
	poses.clear()
	effaces.clear()
	for c: Array in d.get("effaces", []):
		effaces[Vector2i(int(c[0]), int(c[1]))] = true
	for r: Array in d.get("poses", []):
		if r.size() >= 5:
			pose(String(r[0]), float(r[1]), float(r[2]), float(r[3]), float(r[4]), true)
	auto_actif = bool(d.get("auto", true))
	_auto.clear()
	_routes_sales = true
	_sale = true
