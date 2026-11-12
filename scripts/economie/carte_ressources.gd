class_name CarteRessources
extends RefCounted
## Richesse de chaque ressource naturelle (0 à 1) en tout point de la région.
##
## - Ce qui se voit sur le terrain vient des données réelles déjà chargées :
##   forêts, champs et prairies (ESA WorldCover), relief et pente (tuiles
##   d'altitude), rivières, lacs et mer (WaterMap, bathymétrie).
## - Le sous-sol (fer, charbon, cuivre, or, bauxite, pétrole, gaz) vient des
##   vraies provinces minières (GisementsMonde) : dans une province, les
##   gisements sont des taches tirées d'un bruit calculé sur les coordonnées
##   réelles, donc identiques pour tous les joueurs et toutes les parties.
## Valeur -1 : pas encore connue (relief en cours de chargement).

## Rayon (km) autour de l'origine où l'on cherche les provinces.
const SEARCH_KM := 40.0
## Taille des taches de gisement (km) : minerais et hydrocarbures.
const PATCH_KM := 3.0
const PATCH_KM_HC := 9.0

var world: TerrainWorld
## Provinces réelles qui touchent la région (voir GisementsMonde.near).
var provinces: Array = []
var _for_origin := Vector2(INF, INF)
var _noises := {}


func _init(w: TerrainWorld = null) -> void:
	world = w


## Provinces de la région (recalculées quand l'origine change).
func region_provinces() -> Array:
	if world == null:
		return provinces
	var o := Vector2(world.origin_lat, world.origin_lon)
	if o != _for_origin:
		_for_origin = o
		provinces = GisementsMonde.near(o.x, o.y, SEARCH_KM)
	return provinces


# --- Sous-sol ----------------------------------------------------------------------

func _noise(key: String, freq: float) -> FastNoiseLite:
	if not _noises.has(key):
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.seed = hash(key) & 0x7fffffff
		n.frequency = freq
		n.fractal_type = FastNoiseLite.FRACTAL_FBM
		n.fractal_octaves = 3
		_noises[key] = n
	return _noises[key]


## Valeur du bruit (≈ 0 à 1) aux vraies coordonnées : km vers l'est et vers le nord.
func _field(key: String, lat: float, lon: float, size_km: float) -> float:
	var x := lon * 111.32 * cos(deg_to_rad(lat))
	var y := lat * 110.57
	return clampf(_noise(key, 1.0 / size_km).get_noise_2d(x, y) * 0.9 + 0.5, 0.0, 1.0)


## Tache de gisement : 0 hors tache, jusqu'à 1 au cœur. rarete : 0 = taches
## larges et nombreuses, 1 = rares et petites.
func _patch(key: String, lat: float, lon: float, size_km: float, rarete: float) -> float:
	var v := _field(key, lat, lon, size_km)
	var cut := 0.52 + rarete * 0.22
	return clampf((v - cut) / 0.16, 0.0, 1.0)


## Richesse d'un gisement du sous-sol au point (lat, lon).
func deposit(res: String, lat: float, lon: float) -> float:
	var size := PATCH_KM_HC if res in Ressources.HYDROCARBURES else PATCH_KM
	var best := 0.0
	for p in region_provinces():
		if p.res != res:
			continue
		var w := GisementsMonde.weight(p, lat, lon)
		if w > best:
			best = maxf(best, w * _patch(res, lat, lon, size, 0.0))
	if GisementsMonde.FOND.has(res) and not (res == "bauxite" and absf(lat) > 30.0):
		var f: Array = GisementsMonde.FOND[res]
		best = maxf(best, float(f[0]) * _patch(res + "/fond", lat, lon, size * 0.6, float(f[1])))
	return best


# --- Échantillonnage -----------------------------------------------------------------

## Relevé du terrain sur une grille de nx × nz points espacés de `step` m, le
## premier au centre de la maille (x0, z0) : altitude, biome, rivières.
func sample_env(x0: float, z0: float, nx: int, nz: int, step: float) -> Dictionary:
	var xs := PackedFloat64Array()
	xs.resize(nx)
	var pxs := PackedFloat64Array()
	pxs.resize(nx)
	var lons := PackedFloat64Array()
	lons.resize(nx)
	for i in nx:
		xs[i] = x0 + (i + 0.5) * step
		pxs[i] = world._pixel_x(xs[i])
		lons[i] = Geo.local_to_lon(world.origin_lat, world.origin_lon, xs[i])
	var zs := PackedFloat64Array()
	zs.resize(nz)
	var pys := PackedFloat64Array()
	pys.resize(nz)
	var lats := PackedFloat64Array()
	lats.resize(nz)
	for j in nz:
		zs[j] = z0 + (j + 0.5) * step
		pys[j] = world._pixel_y(zs[j])
		lats[j] = Geo.local_to_lat(world.origin_lat, zs[j])
	var h := world.tiles.sample_grid(pxs, pys)
	var bio := world.land.sample_grid(lats, lons)
	var wid := PackedFloat32Array()
	wid.resize(nx * nz)
	var any := world.water.any_in_rect(x0, z0, x0 + nx * step, z0 + nz * step)
	for j in nz:
		for i in nx:
			var n := i + j * nx
			if any:
				wid[n] = world.water.width_at(xs[i], zs[j])
			var c := Vector2i(floori(xs[i]), floori(zs[j]))
			if not world.modifications.is_empty() and world.modifications.has(c):
				h[n] = world.modifications[c]
			if not world.water_cells.is_empty() and world.water_cells.has(c):
				wid[n] = maxf(wid[n], 4.0)
			if not world.biome_paint.is_empty() and world.biome_paint.has(c):
				bio[n] = KIND_TO_CODE[int(world.biome_paint[c])]
	return {"h": h, "bio": bio, "wid": wid, "lats": lats, "lons": lons, "nx": nx, "nz": nz, "step": step}


const NEIGH: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

## Richesse de base par code WorldCover (forêt, culture, pâture).
const BOIS := {10: 1.0, 95: 0.8, 20: 0.25, 90: 0.2, 30: 0.04}
const CULTURES := {40: 1.0, 30: 0.7, 10: 0.45, 20: 0.35, 90: 0.3, 100: 0.1, 60: 0.04}
const PATURES := {30: 1.0, 40: 0.6, 20: 0.55, 100: 0.35, 90: 0.3, 10: 0.15}

## Code WorldCover équivalent d'un biome peint (TerrainWorld.Kind).
const KIND_TO_CODE := [80, 80, 70, 60, 10, 20, 30, 40, 60, 90, 95, 100, 60, 70, 30, 80, 80, 80, 80]


## Richesse de `res` sur chaque point d'un relevé (sample_env).
func evaluate(res: String, env: Dictionary) -> PackedFloat32Array:
	var nx: int = env.nx
	var nz: int = env.nz
	var step: float = env.step
	var h: PackedFloat32Array = env.h
	var bio: PackedByteArray = env.bio
	var wid: PackedFloat32Array = env.wid
	var lats: PackedFloat64Array = env.lats
	var lons: PackedFloat64Array = env.lons
	var out := PackedFloat32Array()
	out.resize(nx * nz)
	var deep := res in Ressources.SOUS_SOL
	var any_province := false
	if deep:
		for p in region_provinces():
			any_province = any_province or p.res == res
	for j in nz:
		for i in nx:
			var n := i + j * nx
			var hh := h[n]
			if is_nan(hh):
				# Le sous-sol ne dépend pas du relief : connu même avant son chargement.
				out[n] = deposit(res, lats[j], lons[i]) if deep and any_province or deep and GisementsMonde.FOND.has(res) else -1.0
				if deep:
					out[n] = clampf(out[n], 0.0, 1.0)
				continue
			var code := int(bio[n])
			if code == 0:
				code = 80 if hh < 0.0 else 30
			var water := hh < 0.0 or code == 80 or wid[n] >= 3.0
			# Pente : plus grand écart avec les voisins, rapporté au mètre.
			var s := 0.0
			for d: Vector2i in NEIGH:
				var a: int = i + d.x
				var b: int = j + d.y
				if a >= 0 and a < nx and b >= 0 and b < nz and not is_nan(h[a + b * nx]):
					s = maxf(s, absf(h[a + b * nx] - hh) / step)
			var v := 0.0
			match res:
				"bois":
					if not water:
						v = BOIS.get(code, 0.0)
						if hh > 2200.0:
							v *= 0.4
				"fertilite":
					if not water:
						v = CULTURES.get(code, 0.0)
						v *= clampf(1.0 - s * 4.0, 0.0, 1.0)
						v *= clampf(1.0 - (hh - 1200.0) / 1300.0, 0.0, 1.0)
						v *= _climate(lats[j])
				"paturage":
					if not water:
						v = PATURES.get(code, 0.0)
						v *= clampf(1.0 - s * 1.5, 0.0, 1.0)
						if hh > 2800.0:
							v *= 0.3
				"poisson":
					if hh < 0.0 and code in [0, 80, 90, 95]:
						# Plateau continental (moins de 200 m) plus poissonneux.
						v = 0.45 + 0.55 * clampf(1.0 + hh / 200.0, 0.0, 1.0)
					elif water:
						v = 0.35 if wid[n] < 20.0 else 0.45
					v *= 0.6 + 0.4 * _field("poisson", lats[j], lons[i], 6.0)
				"pierre":
					if not water:
						v = 0.15 + clampf(s * 1.2, 0.0, 0.6)
						if code == 60:
							v += 0.25
						if hh > 800.0:
							v += 0.15
						v *= 0.55 + 0.45 * _field("pierre", lats[j], lons[i], 4.0)
				"sable":
					if not water:
						var shore := _near_water(env, i, j)
						if shore and s < 0.15:
							v = 0.85 if hh < 3.0 else 0.7
						elif code == 60 and hh < 1500.0 and s < 0.2:
							v = 0.6
						else:
							v = 0.04
						v *= 0.6 + 0.4 * _field("sable", lats[j], lons[i], 3.0)
				"argile":
					if not water and s < 0.08:
						v = 0.2
						if hh < 300.0:
							v += 0.25
						if code == 90 or _near_water(env, i, j):
							v += 0.35
						v *= 0.4 + 0.6 * _field("argile", lats[j], lons[i], 5.0)
				_:
					if deep:
						# Les gisements en mer ne servent qu'aux hydrocarbures.
						if not water or res in Ressources.HYDROCARBURES:
							v = deposit(res, lats[j], lons[i]) if any_province or GisementsMonde.FOND.has(res) else 0.0
			out[n] = clampf(v, 0.0, 1.0)
	return out


## Facteur de climat pour les cultures : nul vers les pôles.
static func _climate(lat: float) -> float:
	var a := absf(lat)
	if a <= 50.0:
		return 1.0
	return clampf(1.0 - (a - 50.0) / 22.0, 0.08, 1.0)


func _near_water(env: Dictionary, i: int, j: int) -> bool:
	var nx: int = env.nx
	var nz: int = env.nz
	var h: PackedFloat32Array = env.h
	var wid: PackedFloat32Array = env.wid
	var bio: PackedByteArray = env.bio
	for dj in range(-1, 2):
		for di in range(-1, 2):
			var a := i + di
			var b := j + dj
			if a < 0 or b < 0 or a >= nx or b >= nz:
				continue
			var n := a + b * nx
			if wid[n] > 0.0 or h[n] < 0.0 or int(bio[n]) == 80:
				return true
	return false


## Richesse sur une grille (voir sample_env).
func sample(res: String, x0: float, z0: float, nx: int, nz: int, step: float) -> PackedFloat32Array:
	return evaluate(res, sample_env(x0, z0, nx, nz, step))


## Toutes les ressources sous une case : {res: richesse}, -1 si inconnue.
func all_at(c: Vector2i) -> Dictionary:
	var env := sample_env(c.x - 7.0, c.y - 7.0, 3, 3, 5.0)
	var out := {}
	for res in Ressources.ORDRE:
		out[res] = evaluate(res, env)[4]
	return out


## Richesse moyenne d'une ressource sur un rectangle agrandi de `radius` m.
## Pour le poisson, seule l'eau compte : un port au bord de l'eau vaut l'eau
## qui l'entoure. -1 si le relief n'est pas encore chargé.
func mean_in(res: String, rect: Rect2i, radius := 0.0) -> float:
	var r := Rect2(rect.position, rect.size).grow(radius)
	var step := clampf(maxf(r.size.x, r.size.y) / 14.0, 3.0, 40.0)
	var nx := maxi(1, ceili(r.size.x / step))
	var nz := maxi(1, ceili(r.size.y / step))
	var v := sample(res, r.position.x, r.position.y, nx, nz, step)
	var sum := 0.0
	var n := 0
	for x in v:
		if x < 0.0:
			return -1.0
		sum += x
		n += 1
	if n == 0:
		return 0.0
	var m := sum / n
	if res == "poisson":
		m = clampf(m * 2.5, 0.0, 1.0)
	return m


## La ressource la plus riche parmi `list` sur un rectangle : {res, rich}.
func best_of(list: Array, rect: Rect2i, radius := 0.0) -> Dictionary:
	var best := {"res": "", "rich": 0.0}
	for res in list:
		var m := mean_in(res, rect, radius)
		if m < 0.0:
			return {"res": "", "rich": -1.0}
		if m > float(best.rich):
			best = {"res": res, "rich": m}
	return best
