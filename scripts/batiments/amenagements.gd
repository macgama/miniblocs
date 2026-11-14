class_name Amenagements
extends RefCounted
## Aménagements de l'atelier (mode Murs et étages) : bassins et piscines, voies
## ferrées et quais, gradins et tribunes, terrains de sport.
##
## Un aménagement se pose comme un sol : clic glissé en rectangle (ou un clic :
## taille réglementaire, R pour tourner). Il appartient au bâtiment en murs fins
## (plan) et à un étage : on peut donc faire une piscine sur un toit-terrasse,
## un stade avec ses tribunes, une gare avec ses quais, un zoo avec ses bassins.
##
## Données d'un plan : p.am = {Vector3i(x, étage, z) (coin bas) : {k, w, d, r, m}}
## - k : type (KINDS), w × d : taille en cases (x × z) ;
## - r : orientation (comme les escaliers, 0 : +z, 1 : −x, 2 : −z, 3 : +x) :
##   les gradins montent dans cette direction ;
## - m : matériau principal choisi (−1 : celui du modèle).
## Le maillage est fait ici (emit), dans le même BlocMesher que les murs : il
## suit donc la vue en coupe, la banque de modèles et les bâtiments posés.

const FAMILLES := [["bassins", "Bassins"], ["rails", "Rails et quais"], ["gradins", "Gradins"], ["terrains", "Terrains de sport"]]

## Épaisseur des dalles (comme les planchers).
const SLAB := 0.2
const LINE_Y := 0.035
const SURF_Y := 0.025
const STAIR_DIRS := [Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 0)]

## size : taille d'un clic (x × z, côté long en z) ; min / max : côtés (petit, grand).
## price : € le m² ; fn : fonction de bâtiment proposée (BuildingCatalog) ;
## Bassins : depth (m), raise (margelle surélevée), wall / floor / rim / water.
## Rails : gauge (écartement), entraxe, sleeper (longueur des traverses), ballast.
## Gradins : step (profondeur d'un rang), rise (hauteur), seat (matériau des sièges).
const KINDS := {
	# --- Bassins ---------------------------------------------------------------------
	"piscine": {"name": "Piscine", "fam": "bassins", "size": Vector2i(4, 8), "min": Vector2i(2, 3), "max": Vector2i(30, 60), "price": 700,
		"fn": "piscine", "depth": 1.5, "wall": "Carrelage bleu", "floor": "Carrelage bleu", "rim": "Dalles de pierre", "water": "Eau",
		"desc": "Bassin carrelé de 1,50 m, margelle en pierre. Le terrain est creusé dessous."},
	"bassin_nage": {"name": "Bassin de nage", "fam": "bassins", "size": Vector2i(13, 25), "min": Vector2i(5, 10), "max": Vector2i(30, 60), "price": 950,
		"fn": "piscine", "depth": 2.0, "wall": "Carrelage blanc", "floor": "Carrelage bleu", "rim": "Carrelage blanc", "water": "Eau", "lanes": 2.5,
		"desc": "Bassin sportif de 25 m (ou 50 m) : couloirs de 2,50 m, lignes d'eau, plots de départ."},
	"plongeon": {"name": "Fosse à plongeon", "fam": "bassins", "size": Vector2i(12, 14), "min": Vector2i(8, 8), "max": Vector2i(25, 30), "price": 1300,
		"fn": "piscine", "depth": 4.5, "wall": "Carrelage bleu", "floor": "Carrelage bleu", "rim": "Carrelage blanc", "water": "Eau", "boards": true,
		"desc": "4,50 m de fond, tremplins de 1 m et 3 m et plateforme de 5 m."},
	"pataugeoire": {"name": "Pataugeoire", "fam": "bassins", "size": Vector2i(6, 6), "min": Vector2i(2, 2), "max": Vector2i(20, 20), "price": 400,
		"fn": "piscine", "depth": 0.4, "wall": "Mosaïque", "floor": "Mosaïque", "rim": "Sol amortissant bleu", "water": "Eau",
		"desc": "40 cm d'eau pour les petits, mosaïque et bord amortissant."},
	"spa": {"name": "Spa", "fam": "bassins", "size": Vector2i(3, 3), "min": Vector2i(2, 2), "max": Vector2i(6, 8), "price": 2500,
		"fn": "piscine", "depth": 0.9, "raise": 0.5, "wall": "Mosaïque", "floor": "Mosaïque", "rim": "Teck", "water": "Eau", "bench": true,
		"desc": "Bain bouillonnant surélevé, banquette tout autour, bord en teck."},
	"bassin_ornement": {"name": "Bassin d'ornement", "fam": "bassins", "size": Vector2i(4, 6), "min": Vector2i(2, 2), "max": Vector2i(40, 60), "price": 300,
		"fn": "parc", "depth": 0.6, "raise": 0.4, "wall": "Pierre de taille", "floor": "Galets", "rim": "Pierre de taille", "water": "Eau de bassin", "jet": true,
		"desc": "Bassin de jardin à rebord de pierre et jet d'eau au milieu."},
	"bassin_animaux": {"name": "Bassin pour animaux", "fam": "bassins", "size": Vector2i(10, 12), "min": Vector2i(4, 4), "max": Vector2i(40, 60), "price": 900,
		"fn": "", "depth": 3.0, "raise": 0.8, "wall": "Roche grise", "floor": "Sable blanc", "rim": "Faux rocher gris", "water": "Eau de bassin",
		"window": true, "island": true,
		"desc": "Pour otaries, manchots ou ours : 3 m de fond, bords en rochers, îlot et vitre de vision sous l'eau."},
	"aquarium": {"name": "Aquarium", "fam": "bassins", "size": Vector2i(2, 6), "min": Vector2i(1, 2), "max": Vector2i(20, 40), "price": 3000,
		"fn": "", "depth": 2.4, "tank": true, "wall": "Verre", "floor": "Sable blanc", "rim": "Inox", "water": "Eau",
		"desc": "Grand bac vitré posé sur le sol de l'étage : 2,40 m d'eau, sable et rochers."},
	# --- Rails et quais --------------------------------------------------------------
	"voie_normale": {"name": "Voie ferrée", "fam": "rails", "size": Vector2i(4, 30), "min": Vector2i(3, 4), "max": Vector2i(60, 400), "price": 350,
		"fn": "", "gauge": 1.435, "entraxe": 4.5, "sleeper": 2.6, "ballast": 3.4, "spacing": 0.6, "ties": "Bois", "rail": "Acier noir",
		"desc": "Voie normale de 1,435 m sur ballast et traverses en bois. Plus large : plusieurs voies côte à côte (4,50 m d'entraxe)."},
	"voie_lgv": {"name": "Voie à grande vitesse", "fam": "rails", "size": Vector2i(5, 40), "min": Vector2i(4, 4), "max": Vector2i(60, 400), "price": 500,
		"fn": "", "gauge": 1.435, "entraxe": 4.8, "sleeper": 2.6, "ballast": 3.8, "spacing": 0.6, "ties": "Béton", "rail": "Inox",
		"desc": "Voie normale sur traverses en béton, entraxe de 4,80 m."},
	"voie_metrique": {"name": "Voie métrique", "fam": "rails", "size": Vector2i(3, 24), "min": Vector2i(3, 4), "max": Vector2i(60, 400), "price": 250,
		"fn": "", "gauge": 1.0, "entraxe": 3.5, "sleeper": 2.0, "ballast": 2.6, "spacing": 0.65, "ties": "Bois", "rail": "Acier noir",
		"desc": "Voie de montagne ou de tramway ancien, 1 m d'écartement."},
	"voie_etroite": {"name": "Petit train", "fam": "rails", "size": Vector2i(2, 16), "min": Vector2i(2, 3), "max": Vector2i(40, 300), "price": 120,
		"fn": "parc", "gauge": 0.6, "entraxe": 2.4, "sleeper": 1.2, "ballast": 1.6, "spacing": 0.5, "ties": "Bois", "rail": "Acier noir",
		"desc": "Voie de 60 cm : petit train de parc, de mine ou de jardin."},
	"voie_tram": {"name": "Voie de tram", "fam": "rails", "size": Vector2i(3, 24), "min": Vector2i(3, 4), "max": Vector2i(40, 400), "price": 400,
		"fn": "", "gauge": 1.435, "entraxe": 3.0, "flush": true, "paving": "Pavés de granit", "rail": "Inox",
		"desc": "Rails encastrés dans un pavage : on y marche et on y roule."},
	"quai": {"name": "Quai de gare", "fam": "rails", "size": Vector2i(4, 30), "min": Vector2i(2, 4), "max": Vector2i(20, 400), "price": 300,
		"fn": "", "height": 0.55, "top": "Dalles de béton", "side": "Béton",
		"desc": "Quai de 55 cm de haut, bandes d'éveil jaunes sur les bords."},
	"quai_couvert": {"name": "Quai couvert", "fam": "rails", "size": Vector2i(6, 30), "min": Vector2i(3, 6), "max": Vector2i(20, 400), "price": 700,
		"fn": "", "height": 0.55, "top": "Dalles de béton", "side": "Béton", "canopy": "Bac acier",
		"desc": "Quai avec marquise sur poteaux tous les 8 m."},
	"butoir": {"name": "Heurtoir", "fam": "rails", "size": Vector2i(3, 2), "min": Vector2i(2, 2), "max": Vector2i(6, 4), "price": 3000,
		"fn": "", "desc": "Butoir de fin de voie, à poser au bout des rails."},
	# --- Gradins ---------------------------------------------------------------------
	"gradins_beton": {"name": "Gradins en béton", "fam": "gradins", "size": Vector2i(20, 8), "min": Vector2i(2, 2), "max": Vector2i(60, 200), "price": 250,
		"fn": "", "step": 0.8, "rise": 0.4, "tread": "Béton", "riser": "Béton brut", "seat": "Sièges de stade bleus",
		"desc": "Rangs de 80 cm, 40 cm plus haut à chaque rang, sièges coques. Ils montent vers l'arrière (R : tourner)."},
	"tribune_couverte": {"name": "Tribune couverte", "fam": "gradins", "size": Vector2i(30, 12), "min": Vector2i(4, 3), "max": Vector2i(60, 200), "price": 600,
		"fn": "", "step": 0.8, "rise": 0.45, "tread": "Béton", "riser": "Béton brut", "seat": "Sièges de stade rouges", "roof": "Bac acier",
		"desc": "Gradins à sièges rouges, mur du fond et toit en porte-à-faux."},
	"gradins_bois": {"name": "Gradins en bois", "fam": "gradins", "size": Vector2i(10, 4), "min": Vector2i(2, 2), "max": Vector2i(20, 80), "price": 150,
		"fn": "", "step": 0.7, "rise": 0.35, "tread": "Planches", "riser": "", "seat": "", "frame": "Acier galvanisé",
		"desc": "Bancs en planches sur structure métallique, comme au stade du village."},
	"gradins_pierre": {"name": "Gradins antiques", "fam": "gradins", "size": Vector2i(20, 10), "min": Vector2i(2, 2), "max": Vector2i(60, 200), "price": 400,
		"fn": "", "step": 0.8, "rise": 0.4, "tread": "Pierre de taille", "riser": "Calcaire", "seat": "",
		"desc": "Rangs de pierre façon théâtre antique."},
	"gradins_gazon": {"name": "Talus en gazon", "fam": "gradins", "size": Vector2i(20, 8), "min": Vector2i(2, 2), "max": Vector2i(60, 200), "price": 60,
		"fn": "", "step": 1.0, "rise": 0.3, "tread": "Herbe", "riser": "Terre", "seat": "",
		"desc": "Talus en terrasses où l'on s'assoit dans l'herbe."},
	# --- Terrains de sport -----------------------------------------------------------
	"foot": {"name": "Football", "fam": "terrains", "size": Vector2i(74, 111), "min": Vector2i(20, 30), "max": Vector2i(100, 140), "price": 15,
		"fn": "foot", "reg": Vector2(105, 68), "margin": 2.6, "surf": "Pelouse rayée", "around": "Herbe",
		"desc": "Terrain de 105 × 68 m : surfaces de réparation, buts et filets."},
	"foot5": {"name": "City-stade", "fam": "terrains", "size": Vector2i(14, 24), "min": Vector2i(8, 12), "max": Vector2i(30, 50), "price": 60,
		"fn": "foot", "reg": Vector2(22, 12), "margin": 1.6, "surf": "Gazon synthétique", "around": "Enrobé", "fence": true,
		"desc": "Terrain multisport en gazon synthétique, petits buts et palissade."},
	"rugby": {"name": "Rugby", "fam": "terrains", "size": Vector2i(76, 126), "min": Vector2i(30, 50), "max": Vector2i(100, 150), "price": 15,
		"fn": "foot", "reg": Vector2(120, 70), "surf": "Pelouse rayée", "around": "Herbe",
		"desc": "100 m entre les lignes d'essai, en-buts, lignes des 22 m et poteaux en H."},
	"basket": {"name": "Basket", "fam": "terrains", "size": Vector2i(19, 32), "min": Vector2i(8, 14), "max": Vector2i(40, 60), "price": 45,
		"fn": "basket", "reg": Vector2(28, 15), "surf": "Résine de court", "around": "Enrobé",
		"desc": "28 × 15 m : raquettes, ligne à 3 points, panneaux et paniers à 3,05 m."},
	"handball": {"name": "Handball", "fam": "terrains", "size": Vector2i(24, 44), "min": Vector2i(10, 20), "max": Vector2i(40, 60), "price": 60,
		"fn": "gymnase", "reg": Vector2(40, 20), "margin": 1.6, "surf": "Parquet de gymnase", "around": "Sol sportif vert",
		"desc": "40 × 20 m : zones des 6 et 9 m, petits buts."},
	"volley": {"name": "Volley-ball", "fam": "terrains", "size": Vector2i(15, 24), "min": Vector2i(8, 12), "max": Vector2i(30, 40), "price": 50,
		"fn": "gymnase", "reg": Vector2(18, 9), "surf": "Sol sportif bleu", "around": "Sol sportif vert",
		"desc": "18 × 9 m, filet à 2,43 m."},
	"beach_volley": {"name": "Beach-volley", "fam": "terrains", "size": Vector2i(14, 22), "min": Vector2i(8, 12), "max": Vector2i(30, 40), "price": 30,
		"fn": "parc", "reg": Vector2(16, 8), "surf": "Sable de beach-volley", "around": "Sable de beach-volley",
		"desc": "16 × 8 m dans le sable, sangles et filet."},
	"tennis": {"name": "Tennis (dur)", "fam": "terrains", "size": Vector2i(18, 36), "min": Vector2i(10, 20), "max": Vector2i(40, 60), "price": 55,
		"fn": "tennis", "reg": Vector2(23.77, 10.97), "surf": "Sol sportif bleu", "around": "Sol sportif vert", "fence": true,
		"desc": "Court en résine : couloirs, carrés de service, filet de 91 cm, grillage."},
	"tennis_terre": {"name": "Tennis (terre battue)", "fam": "terrains", "size": Vector2i(18, 36), "min": Vector2i(10, 20), "max": Vector2i(40, 60), "price": 45,
		"fn": "tennis", "reg": Vector2(23.77, 10.97), "surf": "Terre battue", "around": "Terre battue", "fence": true,
		"desc": "Court en terre battue façon Roland-Garros."},
	"athletisme": {"name": "Piste d'athlétisme", "fam": "terrains", "size": Vector2i(94, 178), "min": Vector2i(30, 50), "max": Vector2i(110, 200), "price": 40,
		"fn": "foot", "reg": Vector2(176, 92), "surf": "Piste en tartan rouge", "around": "Herbe", "track": true,
		"desc": "Piste de 400 m à 8 couloirs autour d'un terrain de football (s'il a la place)."},
	"patinoire": {"name": "Patinoire", "fam": "terrains", "size": Vector2i(32, 62), "min": Vector2i(10, 20), "max": Vector2i(40, 70), "price": 140,
		"fn": "gymnase", "reg": Vector2(60, 30), "surf": "Glace de patinoire", "around": "Caoutchouc noir", "rink": true,
		"desc": "Glace de 60 × 30 m aux angles arrondis, bandes et vitres, lignes de hockey."},
	"petanque": {"name": "Pétanque", "fam": "terrains", "size": Vector2i(4, 15), "min": Vector2i(3, 6), "max": Vector2i(30, 40), "price": 20,
		"fn": "parc", "reg": Vector2(15, 4), "surf": "Gravier", "around": "Gravier", "border": true,
		"desc": "Piste de 15 × 4 m en gravier, bordure en bois."},
	"golf_green": {"name": "Green de golf", "fam": "terrains", "size": Vector2i(14, 18), "min": Vector2i(6, 6), "max": Vector2i(60, 80), "price": 35,
		"fn": "parc", "reg": Vector2(18, 14), "surf": "Green de golf", "around": "Herbe", "green": true,
		"desc": "Green ras, trou et drapeau, bunker de sable."},
}

## Ordre des vignettes dans chaque onglet.
const ORDER := ["piscine", "bassin_nage", "plongeon", "pataugeoire", "spa", "bassin_ornement", "bassin_animaux", "aquarium",
	"voie_normale", "voie_lgv", "voie_metrique", "voie_etroite", "voie_tram", "quai", "quai_couvert", "butoir",
	"gradins_beton", "tribune_couverte", "gradins_bois", "gradins_pierre", "gradins_gazon",
	"foot", "foot5", "rugby", "basket", "handball", "volley", "beach_volley", "tennis", "tennis_terre", "athletisme",
	"patinoire", "petanque", "golf_green"]

static var _mats: Dictionary = {}


static func has(kind: String) -> bool:
	return KINDS.has(kind)


static func of_family(fam: String) -> Array:
	var out := []
	for k in ORDER:
		if String(KINDS[k].fam) == fam:
			out.append(k)
	return out


## Code d'un matériau d'après son nom (le matériau choisi s'il y en a un).
static func code(name: String, tint := 0) -> int:
	if not _mats.has(name):
		_mats[name] = maxi(0, BlocMateriaux.index_of(name))
	return BlocFormes.encode(int(_mats[name]), 0, 0, tint)


static func _main(a: Dictionary, key: String) -> int:
	var m := int(a.get("m", -1))
	if m >= 0:
		return m
	return code(String(KINDS[a.k].get(key, "Béton")))


static func rect_of(key: Vector3i, a: Dictionary) -> Rect2i:
	return Rect2i(key.x, key.z, int(a.w), int(a.d))


## Taille d'un clic : la taille du modèle, tournée si r est impair.
static func default_size(kind: String, r: int) -> Vector2i:
	var s: Vector2i = KINDS[kind].size
	return Vector2i(s.y, s.x) if r % 2 == 1 else s


## Raison pour laquelle la taille ne va pas ("" si elle va).
static func size_problem(kind: String, w: int, d: int) -> String:
	var k: Dictionary = KINDS[kind]
	var lo: Vector2i = k.min
	var hi: Vector2i = k.max
	var small := mini(w, d)
	var big := maxi(w, d)
	if small < lo.x or big < lo.y:
		return "%s : au moins %d × %d m." % [k.name, lo.x, lo.y]
	if small > hi.x or big > hi.y:
		return "%s : au plus %d × %d m." % [k.name, hi.x, hi.y]
	return ""


static func price(kind: String, w: int, d: int, r := 0) -> int:
	var k: Dictionary = KINDS[kind]
	var p := float(k.price) * w * d
	if String(k.fam) == "gradins":
		p += seats(kind, w, d, r) * 60.0
	return maxi(500, roundi(p))


## Profondeur sous le plancher (bassins) : le terrain est creusé d'autant.
static func depth_below(a: Dictionary) -> float:
	var k: Dictionary = KINDS.get(String(a.k), {})
	if String(k.get("fam", "")) != "bassins" or k.get("tank", false):
		return 0.0
	return float(k.depth) - float(k.get("raise", 0.0)) + 0.25


## Longueur dans le sens de montée des gradins et largeur des rangs.
static func _along(w: int, d: int, r: int) -> Vector2:
	var dir: Vector2i = STAIR_DIRS[r % 4]
	return Vector2(w, d) if dir.x == 0 else Vector2(d, w)


static func rows(kind: String, w: int, d: int, r: int) -> int:
	var k: Dictionary = KINDS[kind]
	if String(k.fam) != "gradins":
		return 0
	var ad := _along(w, d, r)
	return clampi(floori(ad.y / float(k.step)), 1, 80)


## Places assises : un spectateur tous les 50 cm de rang.
static func seats(kind: String, w: int, d: int, r: int) -> int:
	if String(KINDS[kind].fam) != "gradins":
		return 0
	var ad := _along(w, d, r)
	return rows(kind, w, d, r) * floori(ad.x / 0.5)


## Places de toutes les tribunes d'un plan.
static func seats_of(am: Dictionary) -> int:
	var n := 0
	for key in am:
		var a: Dictionary = am[key]
		if has(String(a.k)):
			n += seats(String(a.k), int(a.w), int(a.d), int(a.r))
	return n


## Fonction de bâtiment que suggèrent les aménagements : celle du plus grand.
static func suggest_fonction(am: Dictionary) -> String:
	var best := ""
	var area := 0
	for key in am:
		var a: Dictionary = am[key]
		if not has(String(a.k)):
			continue
		var f := String(KINDS[a.k].get("fn", ""))
		var s := int(a.w) * int(a.d)
		if f != "" and s > area and not BuildingCatalog.get_type(f).is_empty():
			area = s
			best = f
	return best


static func describe(kind: String, w: int, d: int, r: int) -> String:
	var k: Dictionary = KINDS[kind]
	var t := "%s de %d × %d m" % [k.name, w, d]
	match String(k.fam):
		"gradins":
			t += " · %d rangs, %d places" % [rows(kind, w, d, r), seats(kind, w, d, r)]
		"bassins":
			t += " · %s m de fond" % str(float(k.depth)).replace(".", ",")
		"rails":
			if k.has("gauge"):
				var n := tracks(kind, w, d)
				t += " · %d voie%s" % [n, "s" if n > 1 else ""]
	return t


static func tracks(kind: String, w: int, d: int) -> int:
	var k: Dictionary = KINDS[kind]
	return maxi(1, floori(float(mini(w, d)) / float(k.get("entraxe", 4.0)) + 0.2))


# --- Données (plan) -----------------------------------------------------------------

## Aménagement qui couvre la case c à l'étage e : sa clé, ou null.
static func at(am: Dictionary, c: Vector2i, e: int) -> Variant:
	# Le plus petit d'abord (le heurtoir posé sur une voie).
	var best: Variant = null
	var area := 1 << 30
	for key in am:
		var kk: Vector3i = key
		var r := rect_of(kk, am[key])
		if kk.y == e and r.has_point(c) and r.get_area() < area:
			area = r.get_area()
			best = kk
	return best


static func overlaps(am: Dictionary, rect: Rect2i, e: int, skip: Variant = null, kind := "") -> bool:
	for key in am:
		var kk: Vector3i = key
		if kk.y == e and kk != skip and rect_of(kk, am[key]).intersects(rect):
			# Un heurtoir se pose au bout d'une voie (et une voie sous un heurtoir).
			var other := String(am[key].k)
			if (kind == "butoir" and has(other) and String(KINDS[other].fam) == "rails" and KINDS[other].has("gauge")) \
					or (other == "butoir" and has(kind) and KINDS[kind].has("gauge")):
				continue
			return true
	return false


## Cases d'eau (et de fosse) d'un étage : les planchers n'y sont pas dessinés.
static func covers_floor(am: Dictionary, c: Vector2i, e: int) -> bool:
	for key in am:
		var kk: Vector3i = key
		if kk.y != e:
			continue
		var a: Dictionary = am[key]
		if has(String(a.k)) and String(KINDS[a.k].fam) == "bassins" and not KINDS[a.k].get("tank", false) and rect_of(kk, a).has_point(c):
			return true
	return false


static func to_array(am: Dictionary, o := Vector2i.ZERO) -> Array:
	var out := []
	for key in am:
		var kk: Vector3i = key
		var a: Dictionary = am[key]
		out.append_array([kk.x - o.x, kk.y, kk.z - o.y, String(a.k), int(a.w), int(a.d), int(a.r), int(a.get("m", -1))])
	return out


static func from_array(arr: Array, o := Vector2i.ZERO) -> Dictionary:
	var out := {}
	var i := 0
	while i + 7 < arr.size():
		var kind := String(arr[i + 3])
		if has(kind):
			out[Vector3i(int(arr[i]) + o.x, int(arr[i + 1]), int(arr[i + 2]) + o.y)] = {
				"k": kind, "w": maxi(1, int(arr[i + 4])), "d": maxi(1, int(arr[i + 5])), "r": int(arr[i + 6]) % 4, "m": int(arr[i + 7])}
		i += 8
	return out


# --- Maillage -----------------------------------------------------------------------

static func emit(m: BlocMesher, key: Vector3i, a: Dictionary, by: float) -> void:
	var kind := String(a.get("k", ""))
	if not has(kind):
		return
	var r := rect_of(key, a)
	match String(KINDS[kind].fam):
		"bassins":
			_emit_pool(m, r, a, by)
		"rails":
			_emit_rails(m, r, a, by)
		"gradins":
			_emit_stands(m, r, a, by)
		"terrains":
			_emit_field(m, r, a, by)


static func _box(m: BlocMesher, lo: Vector3, hi: Vector3, c: int) -> void:
	PlanEditor.box(m, lo, hi, [c, c, c, c, c, c])


## Face horizontale (vers le haut) de lo à hi (x, z) à la hauteur y.
static func _flat(m: BlocMesher, lo: Vector2, hi: Vector2, y: float, c: int) -> void:
	var mat := BlocFormes.mat_of(c)
	m.face([Vector3(lo.x, y, lo.y), Vector3(hi.x, y, lo.y), Vector3(hi.x, y, hi.y), Vector3(lo.x, y, hi.y)], Vector3.UP,
		BlocMateriaux.layer(mat), BlocMateriaux.tint_color(BlocFormes.tint_of(c)), BlocMateriaux.is_glass(mat))


static func _poly(m: BlocMesher, pts: Array, y: float, c: int) -> void:
	var mat := BlocFormes.mat_of(c)
	var out := []
	for p in pts:
		out.append(Vector3((p as Vector2).x, y, (p as Vector2).y))
	m.face(out, Vector3.UP, BlocMateriaux.layer(mat), BlocMateriaux.tint_color(BlocFormes.tint_of(c)), BlocMateriaux.is_glass(mat))


## Mur mince vertical de a à b (n'importe quelle direction), de y0 à y1.
static func _vwall(m: BlocMesher, a: Vector2, b: Vector2, y0: float, y1: float, thick: float, c: int) -> void:
	var d := b - a
	if d.length() < 0.001:
		return
	var n := Vector2(-d.y, d.x).normalized() * thick / 2.0
	var mat := BlocFormes.mat_of(c)
	var layer := BlocMateriaux.layer(mat)
	var col := BlocMateriaux.tint_color(BlocFormes.tint_of(c))
	var glass := BlocMateriaux.is_glass(mat)
	for s in [1.0, -1.0]:
		var o: Vector2 = n * s
		var nn := Vector3(o.x, 0, o.y).normalized()
		m.face([Vector3(a.x + o.x, y0, a.y + o.y), Vector3(b.x + o.x, y0, b.y + o.y), Vector3(b.x + o.x, y1, b.y + o.y), Vector3(a.x + o.x, y1, a.y + o.y)],
			nn, layer, col, glass)
	m.face([Vector3(a.x + n.x, y1, a.y + n.y), Vector3(b.x + n.x, y1, b.y + n.y), Vector3(b.x - n.x, y1, b.y - n.y), Vector3(a.x - n.x, y1, a.y - n.y)],
		Vector3.UP, layer, col, glass)


# --- Repère d'un rectangle : u le long du grand côté, v en travers ---------------------

static func _frame(r: Rect2i) -> Dictionary:
	var c := Vector2(r.position) + Vector2(r.size) / 2.0
	var along_z := r.size.y >= r.size.x
	return {"c": c, "lu": Vector2(0, 1) if along_z else Vector2(1, 0), "lv": Vector2(1, 0) if along_z else Vector2(0, 1),
		"L": float(r.size.y if along_z else r.size.x), "W": float(r.size.x if along_z else r.size.y), "sx": 1.0, "sy": 1.0}


static func _p(f: Dictionary, u: float, v: float) -> Vector2:
	return (f.c as Vector2) + (f.lu as Vector2) * u * float(f.sx) + (f.lv as Vector2) * v * float(f.sy)


## Pavé aligné du repère, centre (u, v) en mètres réglementaires, demi-tailles en vrais mètres.
static func _ubox(m: BlocMesher, f: Dictionary, u: float, v: float, hu: float, hv: float, y0: float, y1: float, c: int) -> void:
	var p := _p(f, u, v)
	var e := (f.lu as Vector2).abs() * hu + (f.lv as Vector2).abs() * hv
	_box(m, Vector3(p.x - e.x, y0, p.y - e.y), Vector3(p.x + e.x, y1, p.y + e.y), c)


## Pavé du repère entre deux bornes u et v (mètres réglementaires).
static func _urange(m: BlocMesher, f: Dictionary, u0: float, u1: float, v0: float, v1: float, y0: float, y1: float, c: int) -> void:
	var a := _p(f, u0, v0)
	var b := _p(f, u1, v1)
	_box(m, Vector3(minf(a.x, b.x), y0, minf(a.y, b.y)), Vector3(maxf(a.x, b.x), y1, maxf(a.y, b.y)), c)


static func _seg(m: BlocMesher, f: Dictionary, u0: float, v0: float, u1: float, v1: float, wid: float, y: float, c: int) -> void:
	var a := _p(f, u0, v0)
	var b := _p(f, u1, v1)
	var d := b - a
	if d.length() < 0.001:
		return
	var n := Vector2(-d.y, d.x).normalized() * wid / 2.0
	var t := d.normalized() * wid / 2.0
	a -= t
	b += t
	_poly(m, [a + n, b + n, b - n, a - n], y, c)


static func _arc(m: BlocMesher, f: Dictionary, cu: float, cv: float, rad: float, a0: float, a1: float, wid: float, y: float, c: int) -> void:
	var segs := clampi(ceili(absf(a1 - a0) * rad / 1.5), 4, 48)
	var prev := Vector2(cu + rad * cos(a0), cv + rad * sin(a0))
	for i in range(1, segs + 1):
		var t := a0 + (a1 - a0) * float(i) / segs
		var q := Vector2(cu + rad * cos(t), cv + rad * sin(t))
		_seg(m, f, prev.x, prev.y, q.x, q.y, wid, y, c)
		prev = q


static func _outline(m: BlocMesher, f: Dictionary, hu: float, hv: float, wid: float, y: float, c: int) -> void:
	_seg(m, f, -hu, -hv, hu, -hv, wid, y, c)
	_seg(m, f, -hu, hv, hu, hv, wid, y, c)
	_seg(m, f, -hu, -hv, -hu, hv, wid, y, c)
	_seg(m, f, hu, -hv, hu, hv, wid, y, c)


# --- Bassins -------------------------------------------------------------------------

static func _emit_pool(m: BlocMesher, r: Rect2i, a: Dictionary, by: float) -> void:
	var k: Dictionary = KINDS[a.k]
	var wall := _main(a, "wall")
	var bottom := code(String(k.floor))
	var rim := code(String(k.rim))
	var water := code(String(k.water))
	var shell := code("Béton")
	var lo := Vector2(r.position)
	var hi := Vector2(r.end)
	if k.get("tank", false):
		_emit_tank(m, lo, hi, a, by)
		return
	var depth := float(k.depth)
	var raise := float(k.get("raise", 0.0))
	var top := by + raise + 0.05
	var b0 := by + raise - depth
	var rw := 0.3 if raise <= 0.0 else 0.35
	if mini(r.size.x, r.size.y) <= 2:
		rw = 0.2
	# Quatre bords : dessus en margelle, face intérieure carrelée, dehors en béton.
	var glass := code("Verre bleu")
	var sides := [
		[Vector3(lo.x, b0 - 0.25, lo.y), Vector3(hi.x, top, lo.y + rw), 5],
		[Vector3(lo.x, b0 - 0.25, hi.y - rw), Vector3(hi.x, top, hi.y), 4],
		[Vector3(lo.x, b0 - 0.25, lo.y + rw), Vector3(lo.x + rw, top, hi.y - rw), 1],
		[Vector3(hi.x - rw, b0 - 0.25, lo.y + rw), Vector3(hi.x, top, hi.y - rw), 0],
	]
	for i in sides.size():
		var s: Array = sides[i]
		var mats := [shell, shell, shell, rim, shell, shell]
		var inner: int = s[2]
		mats[inner] = wall
		# Vitre de vision : le long côté de devant (zoo).
		if k.get("window", false) and i == 0:
			mats[inner] = glass
		PlanEditor.box(m, s[0], s[1], mats)
	# Fond.
	PlanEditor.box(m, Vector3(lo.x + rw, b0 - 0.25, lo.y + rw), Vector3(hi.x - rw, b0, hi.y - rw), [shell, shell, shell, bottom, shell, shell])
	var ilo := lo + Vector2(rw, rw)
	var ihi := hi - Vector2(rw, rw)
	var wy := top - 0.17
	var f := _frame(Rect2i(r.position, r.size))
	# Lignes de nage au fond et lignes d'eau, plots de départ.
	if k.has("lanes"):
		var lane := float(k.lanes)
		var n := maxi(1, floori((f.W - 2 * rw) / lane))
		var w0 := -float(n) * lane / 2.0
		var dark := code("Carrelage noir")
		var hl: float = f.L / 2.0 - rw
		for i in n:
			var v := w0 + (i + 0.5) * lane
			_seg(m, f, -hl + 2.0, v, hl - 2.0, v, 0.25, b0 + 0.01, dark)
			_ubox(m, f, -f.L / 2.0 + rw + 0.35, v, 0.3, 0.25, top, top + 0.7, code("Inox"))
		for i in range(1, n):
			var v2 := w0 + i * lane
			var nb := floori(hl * 2.0 / 2.5)
			for j in nb:
				var uu := -hl + (j + 0.5) * hl * 2.0 / nb
				_ubox(m, f, uu, v2, hl / nb * 0.9, 0.05, wy - 0.03, wy + 0.05, code("Plastique rouge" if j % 2 == 0 else "Plastique bleu"))
	# Banquette tout autour (spa).
	if k.get("bench", false):
		var bw := 0.4
		PlanEditor.box(m, Vector3(ilo.x, b0, ilo.y), Vector3(ihi.x, b0 + 0.45, ilo.y + bw), [wall, wall, wall, wall, wall, wall])
		PlanEditor.box(m, Vector3(ilo.x, b0, ihi.y - bw), Vector3(ihi.x, b0 + 0.45, ihi.y), [wall, wall, wall, wall, wall, wall])
	# Îlot de rochers (bassin pour animaux).
	if k.get("island", false) and f.W >= 6.0:
		var rock := code(String(k.rim))
		_ubox(m, f, f.L * 0.15, 0.0, f.L * 0.12, f.W * 0.14, b0, top + 0.4, rock)
		_ubox(m, f, f.L * 0.18, f.W * 0.05, f.L * 0.06, f.W * 0.07, top + 0.4, top + 1.1, rock)
	# Jet d'eau (bassin d'ornement) : vasque sur une colonne.
	if k.get("jet", false):
		var stone := code(String(k.rim))
		_ubox(m, f, 0, 0, 0.25, 0.25, b0, top + 0.6, stone)
		_ubox(m, f, 0, 0, 0.6, 0.6, top + 0.6, top + 0.75, stone)
		_ubox(m, f, 0, 0, 0.06, 0.06, top + 0.75, top + 1.6, water)
	# Tremplins et plateforme (plongeon), au bout « bas » du grand côté.
	if k.get("boards", false):
		var u0: float = -f.L / 2.0
		var concrete := code("Béton blanc")
		var board := code("Fibre de verre")
		for b in [[1.0, -f.W * 0.3], [3.0, 0.0]]:
			var h: float = b[0]
			var v: float = b[1]
			_ubox(m, f, u0 + 0.6, v, 0.5, 0.35, top, top + h - 0.1, concrete)
			_urange(m, f, u0 + 0.2, u0 + 4.8, v - 0.25, v + 0.25, top + h - 0.08, top + h, board)
		var tv: float = f.W * 0.3
		_ubox(m, f, u0 + 1.0, tv, 0.8, 0.8, top, top + 5.0, concrete)
		_urange(m, f, u0 + 0.2, u0 + 5.0, tv - 1.0, tv + 1.0, top + 4.8, top + 5.0, concrete)
		_urange(m, f, u0 + 0.2, u0 + 0.3, tv - 1.0, tv + 1.0, top + 5.0, top + 6.0, code("Inox"))
	# L'eau (surface vitrée, vue d'en haut et d'en dessous).
	_flat(m, ilo, ihi, wy, water)
	var wm := BlocFormes.mat_of(water)
	m.face([Vector3(ilo.x, wy - 0.001, ilo.y), Vector3(ihi.x, wy - 0.001, ilo.y), Vector3(ihi.x, wy - 0.001, ihi.y), Vector3(ilo.x, wy - 0.001, ihi.y)],
		Vector3.DOWN, BlocMateriaux.layer(wm), Color.WHITE, true)


## Aquarium : bac vitré posé sur le plancher, plein d'eau.
static func _emit_tank(m: BlocMesher, lo: Vector2, hi: Vector2, a: Dictionary, by: float) -> void:
	var k: Dictionary = KINDS[a.k]
	var h := float(k.depth)
	var frame := code(String(k.rim))
	var glass := _main(a, "wall")
	var water := code(String(k.water))
	var sand := code(String(k.floor))
	_box(m, Vector3(lo.x, by, lo.y), Vector3(hi.x, by + 0.4, hi.y), frame)
	_flat(m, lo + Vector2(0.05, 0.05), hi - Vector2(0.05, 0.05), by + 0.55, sand)
	# Vitres.
	var t := 0.05
	PlanEditor.box(m, Vector3(lo.x, by + 0.4, lo.y), Vector3(hi.x, by + h + 0.4, lo.y + t), [glass, glass, -1, frame, glass, glass])
	PlanEditor.box(m, Vector3(lo.x, by + 0.4, hi.y - t), Vector3(hi.x, by + h + 0.4, hi.y), [glass, glass, -1, frame, glass, glass])
	PlanEditor.box(m, Vector3(lo.x, by + 0.4, lo.y + t), Vector3(lo.x + t, by + h + 0.4, hi.y - t), [glass, glass, -1, frame, glass, glass])
	PlanEditor.box(m, Vector3(hi.x - t, by + 0.4, lo.y + t), Vector3(hi.x, by + h + 0.4, hi.y - t), [glass, glass, -1, frame, glass, glass])
	# Cadre du haut.
	_box(m, Vector3(lo.x, by + h + 0.4, lo.y), Vector3(hi.x, by + h + 0.5, lo.y + 0.1), frame)
	_box(m, Vector3(lo.x, by + h + 0.4, hi.y - 0.1), Vector3(hi.x, by + h + 0.5, hi.y), frame)
	# Rochers et eau.
	var c := (lo + hi) / 2.0
	var s := (hi - lo)
	var rock := code("Roche grise")
	_box(m, Vector3(c.x - s.x * 0.2, by + 0.55, c.y - s.y * 0.15), Vector3(c.x + s.x * 0.1, by + 1.3, c.y + s.y * 0.1), rock)
	_box(m, Vector3(c.x + s.x * 0.15, by + 0.55, c.y + s.y * 0.2), Vector3(c.x + s.x * 0.35, by + 0.9, c.y + s.y * 0.35), rock)
	var wy := by + h + 0.25
	_flat(m, lo + Vector2(t, t), hi - Vector2(t, t), wy, water)


# --- Rails ---------------------------------------------------------------------------

static func _emit_rails(m: BlocMesher, r: Rect2i, a: Dictionary, by: float) -> void:
	var k: Dictionary = KINDS[a.k]
	var f := _frame(r)
	var L: float = f.L
	var W: float = f.W
	var kind := String(a.k)
	if kind == "butoir":
		_emit_buffer(m, r, a, by)
		return
	if k.has("height"):
		_emit_platform(m, f, a, by)
		return
	var steel := code(String(k.rail))
	var n := tracks(kind, r.size.x, r.size.y)
	var ent := float(k.entraxe)
	var g := float(k.gauge)
	var hl := L / 2.0
	if k.get("flush", false):
		# Pavage et rails encastrés (gorge du rail : bande sombre).
		var pav := _main(a, "paving")
		_urange(m, f, -hl, hl, -W / 2.0, W / 2.0, by - SLAB, by + 0.05, pav)
		for i in n:
			var v := (i - (n - 1) / 2.0) * ent
			for s in [-1.0, 1.0]:
				var rv: float = v + s * g / 2.0
				_urange(m, f, -hl, hl, rv - 0.04, rv + 0.04, by + 0.05, by + 0.062, steel)
				_seg(m, f, -hl, rv - s * 0.07, hl, rv - s * 0.07, 0.05, by + 0.052, code("Caoutchouc noir"))
		return
	var ballast := int(a.m) if int(a.get("m", -1)) >= 0 else code("Gravier")
	var ties := code(String(k.ties))
	var sl := float(k.sleeper)
	var bw := float(k.ballast)
	var sp := float(k.spacing)
	var bh := 0.3
	for i in n:
		var v := (i - (n - 1) / 2.0) * ent
		# Ballast (un peu plus large en bas : deux couches).
		_urange(m, f, -hl, hl, v - bw / 2.0 - 0.3, v + bw / 2.0 + 0.3, by, by + 0.12, ballast)
		_urange(m, f, -hl, hl, v - bw / 2.0, v + bw / 2.0, by + 0.12, by + bh, ballast)
		# Traverses.
		var count := maxi(1, floori(L / sp))
		for j in count:
			var u := -hl + (j + 0.5) * L / count
			_ubox(m, f, u, v, 0.12, sl / 2.0, by + bh, by + bh + 0.14, ties)
		# Rails.
		for s in [-1.0, 1.0]:
			var rv: float = v + s * g / 2.0
			_urange(m, f, -hl, hl, rv - 0.035, rv + 0.035, by + bh + 0.14, by + bh + 0.3, steel)


static func _emit_platform(m: BlocMesher, f: Dictionary, a: Dictionary, by: float) -> void:
	var k: Dictionary = KINDS[a.k]
	var h := float(k.height)
	var top := _main(a, "top")
	var side := code(String(k.side))
	var hl: float = f.L / 2.0
	var hw: float = f.W / 2.0
	var lo := _p(f, -hl, -hw)
	var hi := _p(f, hl, hw)
	PlanEditor.box(m, Vector3(minf(lo.x, hi.x), by, minf(lo.y, hi.y)), Vector3(maxf(lo.x, hi.x), by + h, maxf(lo.y, hi.y)), [side, side, side, top, side, side])
	# Bandes d'éveil et bordure blanche.
	var yellow := code("Plastique jaune")
	var white := code("Toile blanche")
	for s in [-1.0, 1.0]:
		_seg(m, f, -hl + 0.3, s * (hw - 0.15), hl - 0.3, s * (hw - 0.15), 0.25, by + h + 0.005, white)
		_seg(m, f, -hl + 0.3, s * (hw - 0.75), hl - 0.3, s * (hw - 0.75), 0.4, by + h + 0.005, yellow)
	if k.has("canopy"):
		var roof := code(String(k.canopy))
		var post := code("Acier noir")
		var n := maxi(1, floori(f.L / 8.0))
		for i in n:
			var u: float = -hl + (i + 0.5) * f.L / n
			_ubox(m, f, u, 0, 0.12, 0.12, by + h, by + h + 3.6, post)
		_urange(m, f, -hl, hl, -hw + 0.1, hw - 0.1, by + h + 3.6, by + h + 3.75, roof)
		# Bancs entre les poteaux.
		for i in range(0, n, 2):
			var u2: float = -hl + (i + 1.0) * f.L / n
			if u2 < hl - 1.0:
				_ubox(m, f, u2, 0, 0.9, 0.22, by + h + 0.4, by + h + 0.47, code("Bois"))


static func _emit_buffer(m: BlocMesher, r: Rect2i, a: Dictionary, by: float) -> void:
	# Butoir : socle en béton (il se pose aussi au bout d'une voie, sur le
	# ballast), poteaux, butée rayée rouge et blanc et deux tampons, tourné par r.
	var dir: Vector2i = STAIR_DIRS[int(a.r) % 4]
	var c := Vector2(r.position) + Vector2(r.size) / 2.0
	var along := Vector2(dir).abs()
	var across := Vector2(absf(dir.y), absf(dir.x))
	var stripe := int(a.m) if int(a.get("m", -1)) >= 0 else code("Bandes de piste")
	var steel := code("Acier noir")
	var y0 := by + 0.45
	var e0 := across * 1.6 + along * 0.6
	_box(m, Vector3(c.x - e0.x, by, c.y - e0.y), Vector3(c.x + e0.x, y0, c.y + e0.y), code("Béton"))
	var back := c + Vector2(dir) * 0.4
	for s in [-1.0, 1.0]:
		var p: Vector2 = back + across * s * 0.75
		_box(m, Vector3(p.x - 0.12, y0, p.y - 0.12), Vector3(p.x + 0.12, y0 + 1.45, p.y + 0.12), steel)
		var q: Vector2 = c - Vector2(dir) * 0.25 + across * s * 0.75
		var eq := across * 0.18 + along * 0.25
		_box(m, Vector3(q.x - eq.x, y0 + 0.95, q.y - eq.y), Vector3(q.x + eq.x, y0 + 1.3, q.y + eq.y), code("Acier galvanisé"))
	var e := across * 1.2 + along * 0.15
	var bc := c + Vector2(dir) * 0.1
	_box(m, Vector3(bc.x - e.x, y0 + 0.9, bc.y - e.y), Vector3(bc.x + e.x, y0 + 1.4, bc.y + e.y), stripe)


# --- Gradins -------------------------------------------------------------------------

## Rectangle (x, z) d'une tranche [a0, a1] dans le sens de montée, sur toute la largeur.
static func _slice(r: Rect2i, dir: Vector2i, a0: float, a1: float) -> Array:
	var lo := Vector2(r.position)
	var hi := Vector2(r.end)
	match dir:
		Vector2i(0, 1):
			return [Vector2(lo.x, lo.y + a0), Vector2(hi.x, lo.y + a1)]
		Vector2i(0, -1):
			return [Vector2(lo.x, hi.y - a1), Vector2(hi.x, hi.y - a0)]
		Vector2i(1, 0):
			return [Vector2(lo.x + a0, lo.y), Vector2(lo.x + a1, hi.y)]
	return [Vector2(hi.x - a1, lo.y), Vector2(hi.x - a0, hi.y)]


## Indices des faces (−x, +x, −y, +y, −z, +z) de l'avant et de l'arrière d'un rang.
static func _front_back(dir: Vector2i) -> Vector2i:
	match dir:
		Vector2i(0, 1):
			return Vector2i(4, 5)
		Vector2i(0, -1):
			return Vector2i(5, 4)
		Vector2i(1, 0):
			return Vector2i(0, 1)
	return Vector2i(1, 0)


static func _emit_stands(m: BlocMesher, r: Rect2i, a: Dictionary, by: float) -> void:
	var k: Dictionary = KINDS[a.k]
	var dir: Vector2i = STAIR_DIRS[int(a.r) % 4]
	var n := rows(String(a.k), r.size.x, r.size.y, int(a.r))
	var step := float(k.step)
	var rise := float(k.rise)
	var tread := _main(a, "tread")
	var riser := code(String(k.riser)) if String(k.riser) != "" else tread
	var fb := _front_back(dir)
	var total := float(n) * step
	var ad := _along(r.size.x, r.size.y, int(a.r))
	if k.has("frame"):
		# Gradins en bois : planches sur une structure métallique.
		var steel := code(String(k.frame))
		for i in n:
			var s: Array = _slice(r, dir, i * step, (i + 1) * step)
			var y := by + (i + 1) * rise
			var s0: Vector2 = s[0]
			var s1: Vector2 = s[1]
			_box(m, Vector3(s0.x, y - 0.05, s0.y), Vector3(s1.x, y, s1.y), tread)
			# Contremarche ajourée : une planche.
			var sf: Array = _slice(r, dir, i * step, i * step + 0.04)
			_box(m, Vector3((sf[0] as Vector2).x, y - rise * 0.6, (sf[0] as Vector2).y), Vector3((sf[1] as Vector2).x, y - 0.05, (sf[1] as Vector2).y), tread)
		var posts := maxi(2, floori(ad.x / 3.0) + 1)
		var across_x := dir.x == 0
		for j in posts:
			var t := float(j) / (posts - 1)
			for i in [0, n - 1]:
				var s2: Array = _slice(r, dir, (i + 0.5) * step - 0.05, (i + 0.5) * step + 0.05)
				var p0: Vector2 = s2[0]
				var p1: Vector2 = s2[1]
				var pos := Vector2(lerpf(p0.x + 0.1, p1.x - 0.1, t), (p0.y + p1.y) / 2.0) if across_x else Vector2((p0.x + p1.x) / 2.0, lerpf(p0.y + 0.1, p1.y - 0.1, t))
				_box(m, Vector3(pos.x - 0.05, by, pos.y - 0.05), Vector3(pos.x + 0.05, by + (int(i) + 1) * rise - 0.05, pos.y + 0.05), steel)
		return
	for i in n:
		var s: Array = _slice(r, dir, i * step, (i + 1) * step)
		var mats := [riser, riser, riser, tread, riser, riser]
		mats[fb.x] = riser
		if i < n - 1:
			mats[fb.y] = -1
		var s0: Vector2 = s[0]
		var s1: Vector2 = s[1]
		PlanEditor.box(m, Vector3(s0.x, by, s0.y), Vector3(s1.x, by + (i + 1) * rise, s1.y), mats)
		# Sièges : une rangée de coques (motif) sur le rang.
		if String(k.seat) != "":
			var ss: Array = _slice(r, dir, i * step + step * 0.45, i * step + step * 0.9)
			var q0: Vector2 = ss[0]
			var q1: Vector2 = ss[1]
			var y := by + (i + 1) * rise
			_box(m, Vector3(q0.x, y, q0.y), Vector3(q1.x, y + 0.42, q1.y), code(String(k.seat)))
	if k.has("roof"):
		var concrete := code("Béton")
		var roof := code(String(k.roof))
		var ytop := by + n * rise
		# Mur du fond.
		var sw: Array = _slice(r, dir, total - 0.01, total + 0.3)
		var w0: Vector2 = sw[0]
		var w1: Vector2 = sw[1]
		_box(m, Vector3(w0.x, by, w0.y), Vector3(w1.x, ytop + 3.4, w1.y), concrete)
		# Toit en porte-à-faux, de l'arrière jusqu'au premier rang.
		var sr: Array = _slice(r, dir, -0.5, total + 0.3)
		var r0: Vector2 = sr[0]
		var r1: Vector2 = sr[1]
		var yr := ytop + 3.4
		_box(m, Vector3(r0.x, yr, r0.y), Vector3(r1.x, yr + 0.25, r1.y), roof)


# --- Terrains de sport ---------------------------------------------------------------

static func _emit_field(m: BlocMesher, r: Rect2i, a: Dictionary, by: float) -> void:
	var k: Dictionary = KINDS[a.k]
	var kind := String(a.k)
	var surf := _main(a, "surf")
	var around := code(String(k.around))
	var white := code("Toile blanche")
	var concrete := code("Béton")
	var lo := Vector2(r.position)
	var hi := Vector2(r.end)
	# Dalle : abords en surface, côtés en béton.
	PlanEditor.box(m, Vector3(lo.x, by - SLAB, lo.y), Vector3(hi.x, by + 0.02, hi.y), [concrete, concrete, concrete, around, concrete, concrete])
	var f := _frame(r)
	var reg: Vector2 = k.reg
	# Aire de jeu : réglementaire si elle tient, sinon réduite (marge de 1 m au moins).
	var margin := float(k.get("margin", 1.0))
	var pl := minf(reg.x, f.L - 2.0 * margin)
	var pw := minf(reg.y, f.W - 2.0 * margin)
	f.sx = pl / reg.x
	f.sy = pw / reg.y
	var hu := reg.x / 2.0
	var hv := reg.y / 2.0
	var y := by + LINE_Y
	if k.get("track", false):
		_emit_track(m, f, by, surf, white)
		return
	if k.get("rink", false):
		_emit_rink(m, f, hu, hv, by, surf)
		return
	if k.get("green", false):
		_emit_green(m, f, hu, hv, by, surf)
		return
	# Surface de jeu.
	var plo := _p(f, -hu, -hv)
	var phi := _p(f, hu, hv)
	var sm := 0.0 if surf == around else 1.0
	var g0 := Vector2(minf(plo.x, phi.x), minf(plo.y, phi.y)) - Vector2.ONE * sm
	var g1 := Vector2(maxf(plo.x, phi.x), maxf(plo.y, phi.y)) + Vector2.ONE * sm
	g0 = Vector2(maxf(g0.x, lo.x), maxf(g0.y, lo.y))
	g1 = Vector2(minf(g1.x, hi.x), minf(g1.y, hi.y))
	_flat(m, g0, g1, by + SURF_Y, surf)
	match kind:
		"foot":
			_foot_lines(m, f, y, white)
		"foot5":
			_outline(m, f, hu, hv, 0.08, y, white)
			_seg(m, f, 0, -hv, 0, hv, 0.08, y, white)
			_arc(m, f, 0, 0, 3.0, 0, TAU, 0.08, y, white)
			for s in [-1.0, 1.0]:
				_arc(m, f, s * hu, 0, 6.0, PI / 2.0 if s > 0 else -PI / 2.0, PI * 1.5 if s > 0 else PI / 2.0, 0.08, y, white)
				_goal(m, f, s * hu, 1.5, 2.0, 1.0, by, s)
		"rugby":
			_outline(m, f, hu, hv, 0.1, y, white)
			for u in [-50.0, -28.0, 0.0, 28.0, 50.0]:
				_seg(m, f, u, -hv, u, hv, 0.1, y, white)
			for u2 in [-40.0, -10.0, 10.0, 40.0]:
				var nd := 14
				for j in nd:
					var v0 := -hv + (j + 0.25) * reg.y / nd
					_seg(m, f, u2, v0, u2, v0 + reg.y / nd * 0.5, 0.1, y, white)
			for s in [-1.0, 1.0]:
				_hposts(m, f, s * 50.0, by)
		"basket":
			_basket_lines(m, f, hu, hv, y, white, by)
		"handball":
			_outline(m, f, hu, hv, 0.05, y, white)
			_seg(m, f, 0, -hv, 0, hv, 0.05, y, white)
			for s in [-1.0, 1.0]:
				for rad in [6.0, 9.0]:
					var uu: float = s * (hu - rad)
					_seg(m, f, uu, -1.5, uu, 1.5, 0.05, y, white)
					_arc(m, f, s * hu, -1.5, rad, PI if s > 0 else 0.0, PI * 1.5 if s > 0 else -PI / 2.0, 0.05, y, white)
					_arc(m, f, s * hu, 1.5, rad, PI / 2.0 if s > 0 else 0.0, PI if s > 0 else PI / 2.0, 0.05, y, white)
				_seg(m, f, s * (hu - 7.0), -0.5, s * (hu - 7.0), 0.5, 0.05, y, white)
				_goal(m, f, s * hu, 1.5, 2.0, 1.0, by, s, code("Bandes de piste"))
		"volley", "beach_volley":
			var wid := 0.05 if kind == "volley" else 0.05
			var tape := white if kind == "volley" else code("Plastique bleu")
			_outline(m, f, hu, hv, wid, y + (0.01 if kind == "beach_volley" else 0.0), tape)
			if kind == "volley":
				_seg(m, f, 0, -hv, 0, hv, wid, y, white)
				for s in [-1.0, 1.0]:
					_seg(m, f, s * 3.0, -hv, s * 3.0, hv, wid, y, white)
			_net(m, f, 0.0, hv + 1.0, 2.43, 1.0, by)
		"tennis", "tennis_terre":
			_tennis_lines(m, f, hu, hv, y, white)
			_net(m, f, 0.0, hv + 0.914, 1.07, 0.95, by, true)
		"petanque":
			var wood := code("Rondins")
			var b0 := _p(f, -hu, -hv)
			var b1 := _p(f, hu, hv)
			var e0 := Vector2(minf(b0.x, b1.x), minf(b0.y, b1.y))
			var e1 := Vector2(maxf(b0.x, b1.x), maxf(b0.y, b1.y))
			_box(m, Vector3(e0.x - 0.1, by, e0.y - 0.1), Vector3(e1.x + 0.1, by + 0.2, e0.y), wood)
			_box(m, Vector3(e0.x - 0.1, by, e1.y), Vector3(e1.x + 0.1, by + 0.2, e1.y + 0.1), wood)
			_box(m, Vector3(e0.x - 0.1, by, e0.y), Vector3(e0.x, by + 0.2, e1.y), wood)
			_box(m, Vector3(e1.x, by, e0.y), Vector3(e1.x + 0.1, by + 0.2, e1.y), wood)
	if k.get("fence", false):
		_fence(m, lo, hi, by, 3.0 if kind.begins_with("tennis") else 1.0)


static func _foot_lines(m: BlocMesher, f: Dictionary, y: float, white: int) -> void:
	var w := 0.12
	_outline(m, f, 52.5, 34.0, w, y, white)
	_seg(m, f, 0, -34, 0, 34, w, y, white)
	_arc(m, f, 0, 0, 9.15, 0, TAU, w, y, white)
	_ubox(m, f, 0, 0, 0.15, 0.15, y - 0.009, y + 0.002, white)
	var bys := y - LINE_Y
	for s in [-1.0, 1.0]:
		var gl: float = s * 52.5
		# Surface de réparation, surface de but, point et arc.
		_seg(m, f, gl, -20.16, gl - s * 16.5, -20.16, w, y, white)
		_seg(m, f, gl, 20.16, gl - s * 16.5, 20.16, w, y, white)
		_seg(m, f, gl - s * 16.5, -20.16, gl - s * 16.5, 20.16, w, y, white)
		_seg(m, f, gl, -9.16, gl - s * 5.5, -9.16, w, y, white)
		_seg(m, f, gl, 9.16, gl - s * 5.5, 9.16, w, y, white)
		_seg(m, f, gl - s * 5.5, -9.16, gl - s * 5.5, 9.16, w, y, white)
		var spot: float = gl - s * 11.0
		_ubox(m, f, spot, 0, 0.12, 0.12, y - 0.009, y + 0.002, white)
		var ang := acos(5.5 / 9.15)
		var base := PI if s > 0 else 0.0
		_arc(m, f, spot, 0, 9.15, base - ang, base + ang, w, y, white)
		# Arcs de coin.
		for t in [-1.0, 1.0]:
			var a0 := atan2(-t, -s)
			_arc(m, f, gl, t * 34.0, 1.0, a0 - PI / 4.0, a0 + PI / 4.0, w, y, white)
		_goal(m, f, gl, 3.66, 2.44, 2.0, bys, s)


## But : deux poteaux, la barre et le filet derrière la ligne (côté s).
static func _goal(m: BlocMesher, f: Dictionary, u: float, half: float, h: float, deep: float, by: float, s: float, c := -1) -> void:
	var post := code("Toile blanche") if c < 0 else c
	var net := code("Grillage")
	var p := 0.06
	var hw := half * float(f.sy)
	for t in [-1.0, 1.0]:
		var v: float = t * half
		_ubox(m, f, u, v, p, p, by, by + h, post)
	var pc := _p(f, u, 0)
	var e := (f.lu as Vector2).abs() * p + (f.lv as Vector2).abs() * (hw + p)
	_box(m, Vector3(pc.x - e.x, by + h - 2 * p, pc.y - e.y), Vector3(pc.x + e.x, by + h, pc.y + e.y), post)
	# Filet : fond, toit et côtés (grillage transparent).
	var back := pc + (f.lu as Vector2) * s * deep
	var lv: Vector2 = f.lv
	_vwall(m, back - lv * hw, back + lv * hw, by, by + h * 0.8, 0.02, net)
	for t2 in [-1.0, 1.0]:
		_vwall(m, pc + lv * hw * t2, back + lv * hw * t2, by, by + h * 0.8, 0.02, net)
	_poly(m, [pc - lv * hw, pc + lv * hw, back + lv * hw, back - lv * hw], by + h * 0.8, net)


static func _hposts(m: BlocMesher, f: Dictionary, u: float, by: float) -> void:
	var white := code("Toile blanche")
	var pad := code("Plastique bleu")
	for t in [-1.0, 1.0]:
		var v: float = t * 2.8
		_ubox(m, f, u, v, 0.1, 0.1, by, by + 12.0, white)
		_ubox(m, f, u, v, 0.25, 0.25, by, by + 2.0, pad)
	var pc := _p(f, u, 0)
	var e := (f.lu as Vector2).abs() * 0.08 + (f.lv as Vector2).abs() * 2.8 * float(f.sy)
	_box(m, Vector3(pc.x - e.x, by + 2.92, pc.y - e.y), Vector3(pc.x + e.x, by + 3.08, pc.y + e.y), white)


static func _basket_lines(m: BlocMesher, f: Dictionary, hu: float, hv: float, y: float, white: int, by: float) -> void:
	var w := 0.05
	_outline(m, f, hu, hv, w, y, white)
	_seg(m, f, 0, -hv, 0, hv, w, y, white)
	_arc(m, f, 0, 0, 1.8, 0, TAU, w, y, white)
	var paint := code("Plastique rouge")
	for s in [-1.0, 1.0]:
		var bl: float = s * hu
		var ft: float = bl - s * 5.8
		# Raquette peinte et cercle des lancers francs.
		var a := _p(f, bl, -2.45)
		var b := _p(f, ft, 2.45)
		_flat(m, Vector2(minf(a.x, b.x), minf(a.y, b.y)), Vector2(maxf(a.x, b.x), maxf(a.y, b.y)), y - 0.005, paint)
		_seg(m, f, bl, -2.45, ft, -2.45, w, y, white)
		_seg(m, f, bl, 2.45, ft, 2.45, w, y, white)
		_seg(m, f, ft, -2.45, ft, 2.45, w, y, white)
		_arc(m, f, ft, 0, 1.8, 0, TAU, w, y, white)
		# Ligne à 3 points : deux droites et l'arc de 6,75 m.
		var hc: float = bl - s * 1.575
		var ang := asin(6.6 / 6.75)
		var cut: float = hc - s * 6.75 * cos(ang)
		_seg(m, f, bl, -6.6, cut, -6.6, w, y, white)
		_seg(m, f, bl, 6.6, cut, 6.6, w, y, white)
		var base := PI if s > 0 else 0.0
		_arc(m, f, hc, 0, 6.75, base - ang, base + ang, w, y, white)
		# Poteau, panneau et cercle à 3,05 m.
		var steel := code("Acier noir")
		_ubox(m, f, bl + s * 1.0, 0, 0.1, 0.1, by, by + 3.4, steel)
		_urange(m, f, bl + s * 1.0, bl - s * 1.2, -0.05, 0.05, by + 3.3, by + 3.4, steel)
		_urange(m, f, bl - s * 1.2, bl - s * 1.25, -0.9, 0.9, by + 2.9, by + 3.95, code("Polycarbonate"))
		var ring := code("Plastique orange")
		_urange(m, f, hc - 0.23, hc + 0.23, -0.25, -0.21, by + 3.03, by + 3.06, ring)
		_urange(m, f, hc - 0.23, hc + 0.23, 0.21, 0.25, by + 3.03, by + 3.06, ring)
		_urange(m, f, hc - 0.25, hc - 0.21, -0.25, 0.25, by + 3.03, by + 3.06, ring)
		_urange(m, f, hc + 0.21, hc + 0.25, -0.25, 0.25, by + 3.03, by + 3.06, ring)


static func _tennis_lines(m: BlocMesher, f: Dictionary, hu: float, hv: float, y: float, white: int) -> void:
	var w := 0.05
	_outline(m, f, hu, hv, w, y, white)
	for t in [-1.0, 1.0]:
		_seg(m, f, -hu, t * 4.115, hu, t * 4.115, w, y, white)
		_seg(m, f, t * 6.4, -4.115, t * 6.4, 4.115, w, y, white)
		_seg(m, f, t * hu, -0.0, t * (hu - 0.1), 0.0, w, y, white)
	_seg(m, f, -6.4, 0, 6.4, 0, w, y, white)


## Filet en travers (u = cu) : poteaux à ±half, bande de grillage, ruban blanc.
static func _net(m: BlocMesher, f: Dictionary, cu: float, half: float, h: float, band: float, by: float, low := false) -> void:
	var steel := code("Acier noir")
	var net := code("Grillage")
	var white := code("Toile blanche")
	for t in [-1.0, 1.0]:
		_ubox(m, f, cu, t * half, 0.05, 0.05, by, by + h, steel)
	var a := _p(f, cu, -half)
	var b := _p(f, cu, half)
	var top := by + h - (0.15 if low else 0.0)
	_vwall(m, a, b, top - band, top, 0.02, net)
	_vwall(m, a, b, top - 0.06, top, 0.04, white)


static func _fence(m: BlocMesher, lo: Vector2, hi: Vector2, by: float, h: float) -> void:
	var net := code("Grillage")
	var steel := code("Acier galvanisé")
	var corners := [lo, Vector2(hi.x, lo.y), hi, Vector2(lo.x, hi.y)]
	for i in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		var inset := (Vector2((lo.x + hi.x) / 2.0, (lo.y + hi.y) / 2.0) - (a + b) / 2.0).normalized() * 0.05
		_vwall(m, a + inset, b + inset, by + 0.02, by + h, 0.03, net)
		var n := maxi(1, ceili(a.distance_to(b) / 3.0))
		for j in n + 1:
			var p: Vector2 = a.lerp(b, float(j) / n) + inset
			_box(m, Vector3(p.x - 0.04, by, p.y - 0.04), Vector3(p.x + 0.04, by + h, p.y + 0.04), steel)


static func _emit_track(m: BlocMesher, f: Dictionary, by: float, surf: int, white: int) -> void:
	f.sx = 1.0
	f.sy = 1.0
	var ro: float = f.W / 2.0 - 1.0
	var lanes := clampi(floori((ro - 4.0) / 1.22), 1, 8)
	var ri := ro - lanes * 1.22
	var st := maxf(0.0, f.L - 2.0 - 2.0 * ro)
	var hs := st / 2.0
	var y := by + SURF_Y
	# Lignes droites.
	for t in [-1.0, 1.0]:
		var a := _p(f, -hs, t * ri)
		var b := _p(f, hs, t * ro)
		if st > 0.0:
			_flat(m, Vector2(minf(a.x, b.x), minf(a.y, b.y)), Vector2(maxf(a.x, b.x), maxf(a.y, b.y)), y, surf)
	# Virages : anneaux en quadrilatères.
	var segs := 32
	var infield := code("Pelouse rayée")
	for s in [-1.0, 1.0]:
		var cu: float = s * hs
		for i in segs:
			var a0 := -PI / 2.0 + PI * float(i) / segs
			var a1 := -PI / 2.0 + PI * float(i + 1) / segs
			var c0 := Vector2(cos(a0) * s, sin(a0))
			var c1 := Vector2(cos(a1) * s, sin(a1))
			_poly(m, [_p(f, cu + c0.x * ri, c0.y * ri), _p(f, cu + c0.x * ro, c0.y * ro), _p(f, cu + c1.x * ro, c1.y * ro), _p(f, cu + c1.x * ri, c1.y * ri)], y, surf)
			_poly(m, [_p(f, cu, 0), _p(f, cu + c0.x * ri, c0.y * ri), _p(f, cu + c1.x * ri, c1.y * ri)], y, infield)
	if st > 0.0:
		var a2 := _p(f, -hs, -ri)
		var b2 := _p(f, hs, ri)
		_flat(m, Vector2(minf(a2.x, b2.x), minf(a2.y, b2.y)), Vector2(maxf(a2.x, b2.x), maxf(a2.y, b2.y)), y, infield)
	# Couloirs.
	var ly := by + LINE_Y
	for i in lanes + 1:
		var rad := ri + i * 1.22
		for t2 in [-1.0, 1.0]:
			if st > 0.0:
				_seg(m, f, -hs, t2 * rad, hs, t2 * rad, 0.05, ly, white)
		_arc(m, f, hs, 0, rad, -PI / 2.0, PI / 2.0, 0.05, ly, white)
		_arc(m, f, -hs, 0, rad, PI / 2.0, PI * 1.5, 0.05, ly, white)
	# Ligne d'arrivée.
	_seg(m, f, hs, ri, hs, ro, 0.3, ly, white)
	# Un terrain de football au milieu s'il a la place.
	if st >= 60.0 and ri * 2.0 >= 40.0:
		var g := f.duplicate()
		g.sx = minf(1.0, (st + ri * 0.6) / 105.0)
		g.sy = minf(1.0, (ri * 2.0 - 4.0) / 68.0)
		_foot_lines(m, g, ly, white)


static func _emit_rink(m: BlocMesher, f: Dictionary, hu: float, hv: float, by: float, ice: int) -> void:
	var rad := 8.5 * minf(float(f.sx), float(f.sy))
	var su: float = hu * float(f.sx)
	var sv: float = hv * float(f.sy)
	var g := f.duplicate()
	g.sx = 1.0
	g.sy = 1.0
	var y := by + SURF_Y
	# Glace : croix centrale et quatre quarts de disque.
	_poly(m, [_p(g, -su + rad, -sv), _p(g, su - rad, -sv), _p(g, su - rad, sv), _p(g, -su + rad, sv)], y, ice)
	_poly(m, [_p(g, -su, -sv + rad), _p(g, -su + rad, -sv + rad), _p(g, -su + rad, sv - rad), _p(g, -su, sv - rad)], y, ice)
	_poly(m, [_p(g, su - rad, -sv + rad), _p(g, su, -sv + rad), _p(g, su, sv - rad), _p(g, su - rad, sv - rad)], y, ice)
	var board := code("Bois peint blanc")
	var glass := code("Polycarbonate")
	var segs := 8
	var pts := []
	for q in 4:
		var cu: float = (su - rad) * (1.0 if q == 0 or q == 3 else -1.0)
		var cv: float = (sv - rad) * (1.0 if q < 2 else -1.0)
		var start: float = [0.0, PI / 2.0, PI, PI * 1.5][q]
		for i in segs + 1:
			var t: float = start + PI / 2.0 * float(i) / segs
			pts.append(Vector2(cu + cos(t) * rad, cv + sin(t) * rad))
		for i in segs:
			var t0: float = start + PI / 2.0 * float(i) / segs
			var t1: float = start + PI / 2.0 * float(i + 1) / segs
			_poly(m, [_p(g, cu, cv), _p(g, cu + cos(t0) * rad, cv + sin(t0) * rad), _p(g, cu + cos(t1) * rad, cv + sin(t1) * rad)], y, ice)
	for i in pts.size():
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % pts.size()]
		_vwall(m, _p(g, a.x, a.y), _p(g, b.x, b.y), by, by + 1.07, 0.12, board)
		_vwall(m, _p(g, a.x, a.y), _p(g, b.x, b.y), by + 1.07, by + 2.6, 0.03, glass)
	var ly := by + LINE_Y
	var red := code("Plastique rouge")
	var blue := code("Plastique bleu")
	_seg(m, g, 0, -sv, 0, sv, 0.3, ly, red)
	for s in [-1.0, 1.0]:
		_seg(m, g, s * (su - 22.86 * float(f.sx) - 4.0 * float(f.sx)), -sv, s * (su - 22.86 * float(f.sx) - 4.0 * float(f.sx)), sv, 0.3, ly, blue)
		_seg(m, g, s * (su - 4.0 * float(f.sx)), -sv + 1.5, s * (su - 4.0 * float(f.sx)), sv - 1.5, 0.05, ly, red)
		_goal(m, g, s * (su - 4.0 * float(f.sx)), 0.92, 1.22, 1.0, by, s, red)
	_arc(m, g, 0, 0, 4.5, 0, TAU, 0.05, ly, blue)


static func _emit_green(m: BlocMesher, f: Dictionary, hu: float, hv: float, by: float, green: int) -> void:
	# Green ovale, bunker de sable, trou et drapeau.
	var y := by + SURF_Y
	var segs := 28
	var c0 := _p(f, 0, 0)
	for i in segs:
		var a0 := TAU * float(i) / segs
		var a1 := TAU * float(i + 1) / segs
		_poly(m, [c0, _p(f, cos(a0) * hu * 0.95, sin(a0) * hv * 0.95), _p(f, cos(a1) * hu * 0.95, sin(a1) * hv * 0.95)], y, green)
	var sand := code("Sable")
	var bc := Vector2(-hu * 0.55, hv * 0.75)
	for i in 16:
		var a0b := TAU * float(i) / 16
		var a1b := TAU * float(i + 1) / 16
		_poly(m, [_p(f, bc.x, bc.y), _p(f, bc.x + cos(a0b) * hu * 0.25, bc.y + sin(a0b) * hv * 0.18),
			_p(f, bc.x + cos(a1b) * hu * 0.25, bc.y + sin(a1b) * hv * 0.18)], y + 0.004, sand)
	var hole := _p(f, hu * 0.2, -hv * 0.1)
	_box(m, Vector3(hole.x - 0.06, y, hole.y - 0.06), Vector3(hole.x + 0.06, y + 0.003, hole.y + 0.06), code("Caoutchouc noir"))
	_box(m, Vector3(hole.x - 0.02, by, hole.y - 0.02), Vector3(hole.x + 0.02, by + 2.3, hole.y + 0.02), code("Toile blanche"))
	_box(m, Vector3(hole.x + 0.02, by + 1.85, hole.y - 0.01), Vector3(hole.x + 0.55, by + 2.25, hole.y + 0.01), code("Plastique rouge"))
