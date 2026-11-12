class_name Sols
extends RefCounted
## Textures du sol (assets/textures/sol/*.png, fabriquées par
## tools/textures/textures_terrain.py) et parcelles de champs.
##
## Le terrain envoie à son shader, pour chaque face, le numéro de sa texture
## (UV.x) et le sens des rangs (UV.y). Les textures « détail » (sol naturel)
## multiplient la couleur du biome ; les textures « couleur » (champs)
## la remplacent.

const DOSSIER := "res://assets/textures/sol/"
## Ordre = numéro de couche dans la texture du terrain (même ordre que SOLS
## dans tools/textures/textures_terrain.py).
const COUCHES: Array[String] = ["herbe", "sous_bois", "broussailles", "sable", "roche", "neige",
	"glace", "vase", "toundra", "galets", "falaise",
	"labour", "ble", "colza", "mais", "vigne", "tournesol", "legumes", "riz", "pre_fauche",
	"chaume", "levee"]
## Les couches à partir de celle-ci sont en vraie couleur (champs).
const PREMIERE_COULEUR := 11
const HERBE := 0
const FALAISE := 10
const LABOUR := 11
const CHAUME := 20
const LEVEE := 21
## Couche « culture n » envoyée au terrain : CHAMP + n. Le shader remplace par la
## couche du moment (labour, levée, culture, chaume : voir etat_cultures()).
const CHAMP := 64

## Texture du dessus par type de case (ordre de TerrainWorld.Kind).
## -1 = champ : la texture dépend de la parcelle (voir culture()).
const DESSUS: Array[int] = [9, 9, 6, 4, 1, 2, 0, -1, 3, 7, 7, 8, 3, 5, 0, 9, 9, 9, 9]
## Texture des flancs (marches de terrain) par type de case.
const FLANC: Array[int] = [3, 9, 6, 4, 10, 10, 10, 10, 3, 7, 7, 10, 3, 5, 4, 9, 9, 9, 9]

## Les champs sont découpés en carrés de PARCELLE m, eux-mêmes coupés en 1 à
## 3 bandes (longues parcelles, comme en vrai). Chaque parcelle a sa culture,
## et ses rangs suivent sa longueur.
const PARCELLE := 96

## [nom, couche, plante (vide = rien), densité par case]
const CULTURES := [
	["labour", 11, "", 0.0], ["blé", 12, "ble", 1.0], ["colza", 13, "colza", 0.7],
	["maïs", 14, "mais", 0.5], ["vigne", 15, "vigne", 1.0], ["tournesol", 16, "tournesol", 0.6],
	["légumes", 17, "legumes", 0.5], ["riz", 18, "riz", 0.8], ["prairie de fauche", 19, "herbe", 0.08],
]
## Poids de chaque culture (même ordre) selon le climat (Plantes.Climat).
const POIDS_CULTURES := [
	[3, 3, 1, 0, 0, 0, 1, 0, 3], # boréal
	[2, 4, 2, 3, 1, 1, 1, 0, 2], # tempéré
	[2, 3, 1, 1, 3, 2, 1, 0, 1], # méditerranéen
	[2, 2, 0, 3, 1, 1, 2, 2, 1], # subtropical
	[1, 0, 0, 3, 0, 0, 2, 4, 1], # tropical
]


## Nombre pseudo-aléatoire (0 .. 2³²-1) d'une parcelle, le même qu'en GLSL.
static func hash_parcelle(px: int, pz: int) -> int:
	var h := ((px * 73856093) ^ (pz * 19349663)) & 0xffffffff
	h ^= h >> 13
	h = (h * 1274126177) & 0xffffffff
	h ^= h >> 16
	return h


## Parcelle de la case c : (carré x, carré z, bande, sens de la découpe).
static func parcelle(c: Vector2i) -> Vector4i:
	var m := Vector2i(floori(float(c.x) / PARCELLE), floori(float(c.y) / PARCELLE))
	var h := hash_parcelle(m.x, m.y)
	var bandes := 1 + h % 3
	var sens := (h >> 4) & 1 # 0 : bandes côte à côte en X, 1 : en Z
	var local := posmod(c.x if sens == 0 else c.y, PARCELLE)
	return Vector4i(m.x, m.y, local * bandes / PARCELLE, sens)


static func _hash(p: Vector4i) -> int:
	return hash_parcelle(p.x * 3 + p.z, p.y * 7 + 1)


## Culture (indice dans CULTURES) de la parcelle qui contient la case c.
static func culture(c: Vector2i, climat: int) -> int:
	var h := _hash(parcelle(c))
	var poids: Array = POIDS_CULTURES[climat]
	var total := 0
	for x in poids:
		total += x
	var r := h % total
	for n in poids.size():
		r -= poids[n]
		if r < 0:
			return n
	return 0


## Couche d'un champ pour le terrain (CHAMP + culture, + 128 si rangs tournés)
## et culture, mémorisées
## par carré de 16 m (les bords de parcelles tombent toujours sur ce pas).
## memo : Dictionary propre à un calcul (pas partagé entre fils).
static func champ(c: Vector2i, climat: int, memo: Dictionary) -> Vector2i:
	var cle := Vector2i(c.x >> 4, c.y >> 4)
	var r: Variant = memo.get(cle)
	if r == null:
		var cu := culture(c, climat)
		r = Vector2i(CHAMP + cu + (128 if rangs_tournes(c) else 0), cu)
		memo[cle] = r
	return r


## Rangs tournés de 90° (dans l'axe Z) dans cette parcelle ? Les rangs suivent
## la longueur des bandes ; un carré entier tire le sens au hasard.
static func rangs_tournes(c: Vector2i) -> bool:
	var p := parcelle(c)
	var m := hash_parcelle(p.x, p.y)
	if 1 + m % 3 == 1:
		return (_hash(p) >> 8) & 1 == 1
	return p.w == 0


# --- Les champs au fil de l'année ---------------------------------------------------
# Pour chaque culture (ordre de CULTURES), mois par mois (janvier à décembre) :
# taille des plantes (0 = rien), maturité (0 = vert, 1 = mûr : blé doré, colza
# en fleur, maïs sec…) et sol visible (L labour, V levée, C la culture, H chaume).
const _L := -1
const _V := -2
const _C := -3
const _H := -4
const CALENDRIER := [
	# labour
	[[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
		[_L, _L, _L, _L, _L, _L, _L, _L, _L, _L, _L, _L]],
	# blé d'hiver : semé en octobre, vert au printemps, doré en juillet, moissonné.
	[[.2, .2, .3, .5, .8, 1, 1, 0, 0, 0, .1, .15], [0, 0, 0, 0, 0, .3, 1, 1, 0, 0, 0, 0],
		[_V, _V, _C, _C, _C, _C, _C, _H, _L, _L, _V, _V]],
	# colza : en fleur (jaune) en avril, récolté en juillet.
	[[.3, .3, .5, .8, 1, 1, 0, 0, .1, .2, .3, .3], [0, 0, 0, 1, .5, .2, 0, 0, 0, 0, 0, 0],
		[_V, _V, _C, _C, _C, _C, _H, _L, _V, _V, _V, _V]],
	# maïs : semé fin avril, haut l'été, sec en octobre.
	[[0, 0, 0, 0, .1, .4, .8, 1, 1, 1, 0, 0], [0, 0, 0, 0, 0, 0, 0, .2, .6, 1, 0, 0],
		[_L, _L, _L, _L, _V, _C, _C, _C, _C, _C, _H, _L]],
	# vigne
	[[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1], [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
		[_C, _C, _C, _C, _C, _C, _C, _C, _C, _C, _C, _C]],
	# tournesol : en fleur en juillet.
	[[0, 0, 0, 0, .15, .5, 1, 1, 1, 0, 0, 0], [0, 0, 0, 0, 0, 0, 1, .8, .5, 0, 0, 0],
		[_L, _L, _L, _L, _V, _C, _C, _C, _C, _H, _L, _L]],
	# légumes
	[[0, 0, .2, .4, .7, 1, 1, 1, 1, .8, .3, 0], [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
		[_L, _L, _V, _C, _C, _C, _C, _C, _C, _C, _V, _L]],
	# riz : mûr en septembre.
	[[0, 0, 0, .2, .5, .8, 1, 1, 1, 0, 0, 0], [0, 0, 0, 0, 0, 0, 0, .4, 1, 0, 0, 0],
		[_L, _L, _L, _V, _C, _C, _C, _C, _C, _H, _L, _L]],
	# prairie de fauche : fauchée en juin.
	[[.6, .6, .7, .9, 1, .3, .6, .8, .9, .9, .7, .6], [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
		[_C, _C, _C, _C, _C, _C, _C, _C, _C, _C, _C, _C]],
]


## État des champs un jour de l'année (0 = 1er janvier) à cette latitude
## (hémisphère sud : six mois de décalage). Pour chaque culture :
## taille des plantes, maturité (0 vert → 1 mûr) et couche de sol visible.
static func etat_cultures(jour: float, lat: float) -> Dictionary:
	var j := fposmod(jour + (182.6 if lat < 0.0 else 0.0), 365.25)
	# Mois en cours (le 15 = valeur du mois), mélangé avec le suivant.
	var m := j / 30.4375 - 0.5
	var m0 := posmod(floori(m), 12)
	var m1 := (m0 + 1) % 12
	var f := m - floorf(m)
	var taille := PackedFloat32Array()
	var maturite := PackedFloat32Array()
	var couche := PackedInt32Array()
	for n in CALENDRIER.size():
		var cal: Array = CALENDRIER[n]
		var t0: float = cal[0][m0]
		var t1: float = cal[0][m1]
		# Moisson (ou fauche) et semis vers la fin du mois : on coupe net,
		# la pousse repart de zéro.
		var t := lerpf(t0, t1, f)
		if t1 == 0.0 and t0 > 0.0:
			t = t0 * (1.0 - smoothstep(0.45, 0.55, f))
		elif t0 == 0.0 and t1 > 0.0:
			t = t1 * smoothstep(0.5, 1.0, f)
		taille.append(t)
		maturite.append(lerpf(cal[1][m0], cal[1][m1], f))
		var s: int = cal[2][m0 if f < 0.5 else m1]
		var cl: int = CULTURES[n][1]
		match s:
			_L: cl = LABOUR
			_V: cl = LEVEE
			_H: cl = CHAUME
		couche.append(cl)
	return {"taille": taille, "maturite": maturite, "couche": couche}


static var _texture: Texture2DArray


## Toutes les textures du sol dans une seule Texture2DArray (une couche par sol).
static func texture() -> Texture2DArray:
	if _texture:
		return _texture
	var images: Array[Image] = []
	for nom in COUCHES:
		var chemin := DOSSIER + nom + ".png"
		var img: Image = null
		if ResourceLoader.exists(chemin):
			var t := load(chemin) as Texture2D
			if t:
				img = t.get_image()
		if img == null:
			# Texture absente : gris moyen (ne change pas la couleur du biome).
			img = Image.create(4, 4, false, Image.FORMAT_RGBA8)
			img.fill(Color(0.5, 0.5, 0.5))
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		if img.get_width() != 256 or img.get_height() != 256:
			img.resize(256, 256)
		img.generate_mipmaps()
		images.append(img)
	_texture = Texture2DArray.new()
	_texture.create_from_images(images)
	return _texture
