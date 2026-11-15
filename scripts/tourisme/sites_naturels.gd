class_name SitesNaturels
extends RefCounted
## Tourisme v2 : les sites naturels qui attirent les touristes, trouvés dans le
## vrai terrain autour des villages (relief réel, biomes ESA WorldCover, mer,
## lacs et rivières).
##
## Genres : plage (côte basse au bord de la mer), côte (falaises), lac, rivière,
## forêt, sommet (point haut qui domine ses environs), glacier, zone humide.
##
## - scanner(world, centres) : relevé du terrain sur une grille de PAS m dans un
##   rayon RAYON autour de chaque centre (altitudes des tuiles lointaines, déjà
##   téléchargées pour l'horizon, et occupation du sol). Renvoie [] tant que les
##   données ne sont pas toutes là (elles sont demandées ; on réessaie plus tard).
## - analyser(grille) : la même chose sur une grille déjà relevée (tests).
## Chaque site : {genre, key, nom, pos (Vector3), points ([Vector3] : quelques
## points du site, pour la distance aux aménagements, aux sentiers et aux
## routes), taille (ha, ou km de côte), base (points d'attrait de base), note}.
##
## Les aménagements (poste de secours, base nautique, belvédère, parking de
## randonnée, maison de la nature), les sentiers (voies « chemin ») et l'accès
## routier sont comptés par Tourisme, qui connaît les bâtiments et les voies.

const RAYON := 6000.0
const PAS := 200.0
## Sites gardés au plus par genre et en tout, pour un centre.
const MAX_GENRE := 3
const MAX_SITES := 14

const GENRES := {
	"plage": {"name": "Plage", "icone": "soleil"},
	"cote": {"name": "Côte et falaises", "icone": "appareil_photo"},
	"lac": {"name": "Lac", "icone": "eau"},
	"riviere": {"name": "Rivière", "icone": "eau"},
	"foret": {"name": "Forêt", "icone": "feuille"},
	"sommet": {"name": "Sommet", "icone": "paysage"},
	"glacier": {"name": "Glacier", "icone": "neige"},
	"marais": {"name": "Zone humide", "icone": "fleur"},
}
const ORDER := ["plage", "cote", "lac", "riviere", "foret", "sommet", "glacier", "marais"]

## Taille minimale d'un site (mailles de la grille, 4 ha chacune avec PAS = 200 m).
const MIN_MAILLES := {"plage": 2, "cote": 3, "lac": 2, "riviere": 5, "foret": 30, "glacier": 2, "marais": 6}
## Dénivelé minimal (m) d'un sommet au-dessus des points les plus bas autour de lui (2 km).
const PROEMINENCE := 220.0

## Attrait selon le mois (1 à 12) : la plage l'été, la forêt en automne, la montagne
## l'été (et un peu l'hiver), le glacier toute l'année.
const SAISON := {
	"plage": [0.1, 0.1, 0.2, 0.4, 0.7, 1.3, 1.8, 1.9, 0.9, 0.4, 0.15, 0.1],
	"cote": [0.5, 0.5, 0.7, 0.9, 1.0, 1.1, 1.3, 1.3, 1.0, 0.8, 0.5, 0.5],
	"lac": [0.3, 0.3, 0.5, 0.7, 0.9, 1.3, 1.6, 1.6, 1.0, 0.6, 0.3, 0.3],
	"riviere": [0.3, 0.3, 0.5, 0.7, 0.9, 1.2, 1.5, 1.5, 0.9, 0.6, 0.3, 0.3],
	"foret": [0.6, 0.6, 0.8, 1.0, 1.1, 1.0, 1.0, 1.0, 1.1, 1.3, 0.9, 0.6],
	"sommet": [0.6, 0.6, 0.6, 0.7, 0.9, 1.2, 1.5, 1.5, 1.1, 0.8, 0.5, 0.6],
	"glacier": [0.8, 0.8, 0.8, 0.9, 1.0, 1.1, 1.3, 1.3, 1.0, 0.9, 0.8, 0.8],
	"marais": [0.5, 0.5, 0.8, 1.1, 1.2, 1.0, 0.9, 0.9, 1.0, 1.0, 0.7, 0.5],
}

const NOMS := {
	"plage": ["Grande Plage", "Plage des Pins", "Plage du Phare", "Plage des Dunes", "Plage de l'Anse", "Plage des Mouettes", "Plage du Moulin"],
	"cote": ["Pointe du Corbeau", "Falaises Blanches", "Cap des Vents", "Pointe des Embruns", "Rochers du Diable"],
	"lac": ["Lac Bleu", "Lac des Cygnes", "Lac Vert", "Lac du Bois", "Étang des Saules"],
	"riviere": ["Gorges de la rivière", "Bords de la rivière", "Rives du Gué", "Méandres du Moulin"],
	"foret": ["Forêt domaniale", "Bois du Loup", "Forêt des Chênes", "Bois Joli", "Forêt des Hêtres", "Bois de la Fée"],
	"sommet": ["Mont Chauve", "Pic de l'Aigle", "Roc Blanc", "Dent du Chamois", "Crêt de la Neige", "Puy de la Vue"],
	"glacier": ["Glacier Blanc", "Mer de Glace du Pic", "Glacier des Séracs"],
	"marais": ["Marais aux Hérons", "Roselière des Grues", "Tourbière du Haut"],
}


## Relevé du terrain autour des centres, puis analyse. [] si les données manquent
## encore (elles sont demandées) ; ok = false dans ce cas.
static func scanner(world: TerrainWorld, centres: Array) -> Dictionary:
	var out: Array = []
	if world == null or world.land == null:
		return {"ok": false, "sites": out}
	var complet := true
	for c in centres:
		var g := releve(world, c as Vector2)
		if g.is_empty():
			complet = false
			continue
		for s in analyser(g):
			# Deux centres proches voient les mêmes sites : on garde le premier.
			var double := false
			for o in out:
				if String(o.genre) == String(s.genre) and (o.pos as Vector3).distance_to(s.pos) < 800.0:
					double = true
					break
			if not double:
				out.append(s)
	return {"ok": complet, "sites": out}


## Grille d'altitudes et de biomes autour d'un centre ({} si les données ne sont pas prêtes).
static func releve(world: TerrainWorld, centre: Vector2, rayon := RAYON, pas := PAS) -> Dictionary:
	var n := int(ceilf(rayon * 2.0 / pas))
	var x0 := centre.x - rayon
	var z0 := centre.y - rayon
	var lats := PackedFloat64Array()
	var lons := PackedFloat64Array()
	lats.resize(n)
	lons.resize(n)
	for i in n:
		lons[i] = Geo.local_to_lon(world.origin_lat, world.origin_lon, x0 + (i + 0.5) * pas)
		lats[i] = Geo.local_to_lat(world.origin_lat, z0 + (i + 0.5) * pas)
	# Occupation du sol : un bloc WorldCover fait ~10 km, on vérifie une grille de points.
	var pret := true
	for j in 4:
		for i in 4:
			var la := lats[mini(n - 1, j * (n - 1) / 3)]
			var lo := lons[mini(n - 1, i * (n - 1) / 3)]
			if not world.land.is_ready_at(la, lo):
				world.land.request_at(la, lo)
				pret = false
	# Altitudes : les tuiles à petit zoom de l'horizon (~38 m par pixel), sinon les tuiles détaillées.
	var tiles: ElevationTiles = world.tiles
	var hz := world.horizon
	# Terrain de test (généré hors ligne) : les tuiles détaillées seulement.
	if world.tiles.offline_generator.is_valid() and (hz == null or hz.tiles == null or not hz.tiles.offline_generator.is_valid()):
		hz = null
	var pxs := PackedFloat64Array()
	var pys := PackedFloat64Array()
	pxs.resize(n)
	pys.resize(n)
	for i in n:
		if hz != null and hz.tiles != null:
			pxs[i] = hz._px(x0 + (i + 0.5) * pas)
			pys[i] = hz._py(z0 + (i + 0.5) * pas)
		else:
			pxs[i] = world._pixel_x(x0 + (i + 0.5) * pas)
			pys[i] = world._pixel_y(z0 + (i + 0.5) * pas)
	if hz != null and hz.tiles != null:
		tiles = hz.tiles
	var t0 := ElevationTiles.tile_of_pixel(pxs[0] - 1.0, pys[0] - 1.0)
	var t1 := ElevationTiles.tile_of_pixel(pxs[n - 1] + 1.0, pys[n - 1] + 1.0)
	for tx in range(mini(t0.x, t1.x), maxi(t0.x, t1.x) + 1):
		for ty in range(mini(t0.y, t1.y), maxi(t0.y, t1.y) + 1):
			if not tiles.has_tile(Vector2i(tx, ty)):
				tiles.request_tile(Vector2i(tx, ty))
				pret = pret and tiles.has_tile(Vector2i(tx, ty))
	if not pret:
		return {}
	var h := tiles.sample_grid(pxs, pys)
	var bio := PackedByteArray()
	bio.resize(n * n)
	for j in n:
		var row := world.land.sample_grid(PackedFloat64Array([lats[j]]), lons)
		for i in n:
			bio[i + j * n] = row[i]
	var wid := PackedFloat32Array()
	wid.resize(n * n)
	if world.water != null and world.water.any_in_rect(x0, z0, x0 + n * pas, z0 + n * pas):
		for j in n:
			for i in n:
				wid[i + j * n] = world.water.width_at(x0 + (i + 0.5) * pas, z0 + (j + 0.5) * pas)
	for k in h.size():
		if is_nan(h[k]):
			return {}
	var noms := {}
	return {"h": h, "bio": bio, "wid": wid, "n": n, "x0": x0, "z0": z0, "pas": pas, "noms": noms, "world": world}


## Les sites d'une grille relevée : {h, bio, wid, n, x0, z0, pas}.
static func analyser(g: Dictionary) -> Array:
	var n := int(g.n)
	if not g.has("noms"):
		g["noms"] = {}
	var h: PackedFloat32Array = g.h
	var bio: PackedByteArray = g.bio
	var wid: PackedFloat32Array = g.get("wid", PackedFloat32Array())
	var pas := float(g.pas)
	var x0 := float(g.x0)
	var z0 := float(g.z0)
	# 1. Classe de chaque maille.
	var cls := PackedStringArray()
	cls.resize(n * n)
	var mer := PackedByteArray()
	mer.resize(n * n)
	_marquer_mer(h, bio, n, mer)
	for j in n:
		for i in n:
			var k := i + j * n
			var code := int(bio[k])
			if mer[k] == 1:
				continue
			if code == 80:
				cls[k] = "lac"
			elif wid.size() == n * n and wid[k] >= 12.0:
				cls[k] = "riviere"
			elif code == 70:
				cls[k] = "glacier"
			elif _touche(mer, n, i, j):
				cls[k] = "cote" if h[k] > 14.0 else "plage"
			elif code == 10:
				cls[k] = "foret"
			elif code == 90 or code == 95:
				cls[k] = "marais"
	# 2. Taches d'une même classe (voisins par les côtés ; la côte aussi en diagonale).
	var vu := PackedByteArray()
	vu.resize(n * n)
	var par_genre := {}
	for k in n * n:
		if cls[k] == "" or vu[k] == 1:
			continue
		var genre := cls[k]
		var tache: Array[int] = []
		var pile: Array[int] = [k]
		vu[k] = 1
		while not pile.is_empty():
			var q: int = pile.pop_back()
			tache.append(q)
			var qi := q % n
			var qj := q / n
			for d in ([Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)] if genre in ["plage", "cote", "riviere"] else [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]):
				var ni: int = qi + d.x
				var nj: int = qj + d.y
				if ni < 0 or nj < 0 or ni >= n or nj >= n:
					continue
				var nk := ni + nj * n
				if vu[nk] == 0 and cls[nk] == genre:
					vu[nk] = 1
					pile.append(nk)
		# Une eau longue et étroite est une rivière (WorldCover ne les distingue pas des lacs).
		if genre == "lac" and _allonge(tache, n):
			genre = "riviere"
		if tache.size() < int(MIN_MAILLES.get(genre, 1)):
			continue
		if not par_genre.has(genre):
			par_genre[genre] = []
		(par_genre[genre] as Array).append(_site(genre, tache, g))
	# 3. Sommets : points les plus hauts de leur voisinage (1 km) qui dominent de PROEMINENCE m.
	var sommets: Array = []
	var r1 := maxi(1, roundi(1000.0 / pas))
	var r2 := maxi(2, roundi(2000.0 / pas))
	for j in range(r1, n - r1):
		for i in range(r1, n - r1):
			var k := i + j * n
			if mer[k] == 1:
				continue
			var hk := h[k]
			var haut := true
			for dj in range(-r1, r1 + 1):
				for di in range(-r1, r1 + 1):
					if (di != 0 or dj != 0) and h[(i + di) + (j + dj) * n] > hk:
						haut = false
						break
				if not haut:
					break
			if not haut:
				continue
			var bas := hk
			for dj in range(-r2, r2 + 1):
				for di in range(-r2, r2 + 1):
					var ii := clampi(i + di, 0, n - 1)
					var jj := clampi(j + dj, 0, n - 1)
					bas = minf(bas, h[ii + jj * n])
			var prom := hk - bas
			if prom < PROEMINENCE:
				continue
			var p := Vector3(x0 + (i + 0.5) * pas, hk, z0 + (j + 0.5) * pas)
			var proche := false
			for s in sommets:
				if (s.pos as Vector3).distance_to(p) < 1500.0:
					proche = true
					if prom > float(s.prom):
						s.pos = p
						s.points = [p]
						s.prom = prom
					break
			if not proche:
				sommets.append({"genre": "sommet", "pos": p, "points": [p], "prom": prom, "alt": hk, "mailles": 1})
	for s in sommets:
		s.taille = roundf(float(s.prom))
		s.base = clampf(float(s.prom) / 400.0, 0.3, 2.5) * (1.25 if float(s.alt) > 1800.0 else 1.0)
		s.note = 3.4 if float(s.alt) > 1500.0 else 3.0
	if not sommets.is_empty():
		par_genre["sommet"] = sommets
	# 4. Les plus grands de chaque genre, nommés.
	var out: Array = []
	for genre in ORDER:
		var l: Array = par_genre.get(genre, [])
		l.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.base) > float(b.base))
		for s in l.slice(0, MAX_GENRE):
			out.append(s)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.base) > float(b.base))
	out = out.slice(0, MAX_SITES)
	for s in out:
		var p: Vector3 = s.pos
		# Clé stable : genre et maille de 500 m.
		s.key = "%s_%d_%d" % [String(s.genre), floori(p.x / 500.0), floori(p.z / 500.0)]
		s.nom = _nom(String(s.genre), String(s.key), g)
		s.erase("prom")
		s.erase("alt")
	return out


## La mer : les grandes eaux au niveau 0 qui touchent le bord de la grille (les
## tuiles d'altitude mettent l'océan à 0 m, WorldCover le note « eau » ou rien),
## ou tout ce qui est sous −1 m. Un étang côtier de quelques hectares reste un lac.
static func _marquer_mer(h: PackedFloat32Array, bio: PackedByteArray, n: int, mer: PackedByteArray) -> void:
	var cand := PackedByteArray()
	cand.resize(n * n)
	for k in n * n:
		var code := int(bio[k])
		if h[k] < -1.0 or (h[k] <= 1.0 and (code == 0 or code == 80)):
			cand[k] = 1
	var vu := PackedByteArray()
	vu.resize(n * n)
	for k in n * n:
		if cand[k] == 0 or vu[k] == 1:
			continue
		var tache: Array[int] = []
		var pile: Array[int] = [k]
		vu[k] = 1
		var bord := false
		var profond := false
		while not pile.is_empty():
			var q: int = pile.pop_back()
			tache.append(q)
			var qi := q % n
			var qj := q / n
			if qi == 0 or qj == 0 or qi == n - 1 or qj == n - 1:
				bord = true
			if h[q] < -1.0:
				profond = true
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var ni: int = qi + d.x
				var nj: int = qj + d.y
				if ni < 0 or nj < 0 or ni >= n or nj >= n:
					continue
				var nk := ni + nj * n
				if vu[nk] == 0 and cand[nk] == 1:
					vu[nk] = 1
					pile.append(nk)
		if profond or (bord and tache.size() >= 150):
			for q in tache:
				mer[q] = 1


static func _allonge(tache: Array[int], n: int) -> bool:
	var lo := Vector2i(1 << 30, 1 << 30)
	var hi := Vector2i(-(1 << 30), -(1 << 30))
	for q in tache:
		lo = Vector2i(mini(lo.x, q % n), mini(lo.y, q / n))
		hi = Vector2i(maxi(hi.x, q % n), maxi(hi.y, q / n))
	# Largeur moyenne (mailles) = surface / longueur ; une rivière fait moins de 500 m de large.
	var long := float(maxi(hi.x - lo.x, hi.y - lo.y) + 1)
	return long >= 6.0 and float(tache.size()) / long <= 2.5


static func _touche(mer: PackedByteArray, n: int, i: int, j: int) -> bool:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var ni: int = i + d.x
		var nj: int = j + d.y
		if ni >= 0 and nj >= 0 and ni < n and nj < n and mer[ni + nj * n] == 1:
			return true
	return false


## Un site à partir d'une tache de mailles.
static func _site(genre: String, tache: Array[int], g: Dictionary) -> Dictionary:
	var n := int(g.n)
	var pas := float(g.pas)
	var h: PackedFloat32Array = g.h
	var c := Vector2.ZERO
	for q in tache:
		c += Vector2(float(g.x0) + (q % n + 0.5) * pas, float(g.z0) + (q / n + 0.5) * pas)
	c /= float(tache.size())
	# Le point de la tache le plus proche de son centre (une forêt en croissant n'a
	# pas son centre dans la forêt), et quelques points répartis.
	var best := tache[0]
	var best_d := INF
	for q in tache:
		var d := Vector2(float(g.x0) + (q % n + 0.5) * pas, float(g.z0) + (q / n + 0.5) * pas).distance_squared_to(c)
		if d < best_d:
			best_d = d
			best = q
	var pts: Array = []
	# Pour l'eau : les points du bord (les promeneurs sont sur la rive, pas dans l'eau).
	var choix := tache
	if genre in ["lac", "riviere"]:
		var dedans := {}
		for q in tache:
			dedans[q] = true
		var bord: Array[int] = []
		for q in tache:
			var qi := q % n
			var qj := q / n
			if qi == 0 or qj == 0 or qi == n - 1 or qj == n - 1 or not dedans.has(q - 1) or not dedans.has(q + 1) or not dedans.has(q - n) or not dedans.has(q + n):
				bord.append(q)
		if not bord.is_empty():
			choix = bord
	var pas_pts := maxi(1, choix.size() / 16)
	for idx in range(0, choix.size(), pas_pts):
		var q: int = choix[idx]
		pts.append(Vector3(float(g.x0) + (q % n + 0.5) * pas, maxf(h[q], 0.0), float(g.z0) + (q / n + 0.5) * pas))
	var pos := Vector3(float(g.x0) + (best % n + 0.5) * pas, maxf(h[best], 0.0), float(g.z0) + (best / n + 0.5) * pas)
	var m := float(tache.size())
	var ha := m * pas * pas / 10_000.0
	var km := m * pas / 1000.0
	var base := 0.0
	var note := 3.0
	var taille := ha
	match genre:
		"plage":
			base = clampf(0.5 + 0.35 * sqrt(m), 0.6, 3.0)
			taille = km
			note = 3.3
		"cote":
			base = clampf(0.3 + 0.2 * sqrt(m), 0.4, 1.6)
			taille = km
			note = 3.2
		"lac":
			base = clampf(0.3 + 0.22 * sqrt(m), 0.4, 2.4)
			note = 3.2
		"riviere":
			base = clampf(0.2 + 0.1 * sqrt(m), 0.3, 1.1)
			taille = km
		"foret":
			base = clampf(0.1 + 0.06 * sqrt(m), 0.3, 1.3)
		"glacier":
			base = clampf(1.0 + 0.2 * sqrt(m), 1.0, 3.0)
			note = 3.8
		"marais":
			base = clampf(0.15 + 0.07 * sqrt(m), 0.2, 0.8)
			note = 2.8
	return {"genre": genre, "pos": pos, "points": pts, "taille": roundf(taille * 10.0) / 10.0, "base": base, "note": note, "mailles": tache.size()}


static func _nom(genre: String, key: String, g: Dictionary) -> String:
	var l: Array = NOMS.get(genre, ["Site naturel"])
	var noms: Dictionary = g.get("noms", {})
	var i := absi(hash(key)) % l.size()
	# Pas deux fois le même nom dans la région.
	for t in l.size():
		var nom := String(l[(i + t) % l.size()])
		if not noms.has(nom):
			noms[nom] = true
			return nom
	return String(l[i])


static func saison(genre: String, month: int) -> float:
	var s: Array = SAISON.get(genre, [])
	return float(s[clampi(month, 1, 12) - 1]) if s.size() == 12 else 1.0


static func nom_genre(genre: String) -> String:
	return String(GENRES.get(genre, {}).get("name", genre))


## Distance horizontale d'un point au site (au plus proche de ses points).
static func distance(site: Dictionary, p: Vector3) -> float:
	var best := INF
	for q in site.get("points", [site.pos]):
		best = minf(best, Vector2((q as Vector3).x - p.x, (q as Vector3).z - p.z).length())
	return best
