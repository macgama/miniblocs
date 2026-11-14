class_name ParcTypes
extends RefCounted
## Parc de loisirs : bâtiments de la catégorie « Parc de loisirs » du panneau
## Construire (entrée, attractions, stands, toilettes, aire de repos, atelier).
##
## Même format que BuildingCatalog, plus un champ "parc" qui dit le rôle de
## l'objet pour le système ParcLoisirs :
## - "entree" : entrée du parc, reliée à la route. Elle fonde le parc : tout ce
##   qui est posé à moins de ParcLoisirs.RAYON mètres en fait partie ;
## - "attraction" : "cap" places par tour, "cycle" minutes par tour (chargement
##   compris), "exc" excitation (0 à 10), "int" intensité (le cœur au bord des
##   lèvres au-delà de ce que le visiteur supporte), "attrait" (ce qui fait
##   venir les touristes), "usure" (fiabilité perdue à chaque tour) ;
## - "stand" : "vend" ("manger", "boire" ou "souvenir"), "prix" (€), "service" (clients par heure) ;
## - "toilettes", "repos" (bancs et poubelles), "atelier" (techniciens et agents de propreté).
## Les attractions n'ont pas besoin de route : elles sont dans l'enceinte du parc.
## Chiffres : ordres de grandeur des parcs régionaux français.
##
## Les parties qui bougent (plateau du carrousel, roue, nacelles, bateau,
## voitures, train des montagnes russes…) sont des maillages séparés :
## build_anim() les fabrique, animate() les fait tourner.

const CATEGORY := "parc"
const ROAD := ["route"]

const TYPES := {
	"entree_parc": {"name": "Entrée du parc", "w": 32, "d": 14, "access": ROAD, "emplois": 6, "cost": 900_000,
		"parc": {"role": "entree"},
		"metiers": [["agent_accueil_parc", 5], ["cadre", 1]],
		"desc": "Portique, guichets et tourniquets. Elle fonde le parc : attractions et stands se posent autour, à moins de 250 m."},
	"carrousel_parc": {"name": "Carrousel à chevaux", "w": 18, "d": 18, "access": [], "emplois": 2, "cost": 450_000,
		"parc": {"role": "attraction", "cap": 36, "cycle": 4.0, "exc": 2.0, "int": 1.0, "attrait": 2.0, "usure": 0.05, "anim": "carrousel"},
		"metiers": [["operateur_attraction", 2]],
		"desc": "Chevaux de bois et orgue de Barbarie. Les parents montent aussi, « pour surveiller »."},
	"tasses_parc": {"name": "Tasses tournantes", "w": 18, "d": 18, "access": [], "emplois": 2, "cost": 420_000,
		"parc": {"role": "attraction", "cap": 36, "cycle": 3.0, "exc": 3.0, "int": 6.0, "attrait": 2.0, "usure": 0.08, "anim": "tasses"},
		"metiers": [["operateur_attraction", 2]],
		"desc": "Neuf tasses qui tournent sur trois plateaux qui tournent sur un plateau qui tourne. Déconseillé après les frites."},
	"autos_tamponneuses": {"name": "Autos tamponneuses", "w": 28, "d": 20, "access": [], "emplois": 2, "cost": 600_000,
		"parc": {"role": "attraction", "cap": 24, "cycle": 4.0, "exc": 5.0, "int": 3.0, "attrait": 3.0, "usure": 0.1, "anim": "autos"},
		"metiers": [["operateur_attraction", 2]],
		"desc": "Douze voitures, une piste et aucun code de la route."},
	"grande_roue_parc": {"name": "Grande roue", "w": 34, "d": 16, "access": [], "emplois": 3, "cost": 2_400_000,
		"parc": {"role": "attraction", "cap": 64, "cycle": 12.0, "exc": 3.0, "int": 1.0, "attrait": 5.0, "usure": 0.06, "anim": "roue"},
		"metiers": [["operateur_attraction", 2], ["technicien_attraction", 1]],
		"desc": "34 m de haut, 16 nacelles. On voit toute la ville, et la file d'attente d'en face."},
	"chaises_volantes": {"name": "Chaises volantes", "w": 24, "d": 24, "access": [], "emplois": 2, "cost": 900_000,
		"parc": {"role": "attraction", "cap": 32, "cycle": 4.0, "exc": 5.0, "int": 4.0, "attrait": 3.0, "usure": 0.08, "anim": "chaises"},
		"metiers": [["operateur_attraction", 2]],
		"desc": "La couronne monte, tourne, et les chaises s'envolent. Les tongs aussi."},
	"bateau_pirate": {"name": "Bateau pirate", "w": 26, "d": 16, "access": [], "emplois": 2, "cost": 1_600_000,
		"parc": {"role": "attraction", "cap": 48, "cycle": 5.0, "exc": 6.0, "int": 6.0, "attrait": 4.0, "usure": 0.1, "anim": "bateau"},
		"metiers": [["operateur_attraction", 2]],
		"desc": "Un galion qui se balance jusqu'à la verticale. Le rang du fond crie le plus fort."},
	"train_fantome": {"name": "Train fantôme", "w": 24, "d": 18, "access": [], "emplois": 2, "cost": 800_000,
		"parc": {"role": "attraction", "cap": 24, "cycle": 5.0, "exc": 5.0, "int": 2.0, "attrait": 3.0, "usure": 0.07, "anim": "fantome"},
		"metiers": [["operateur_attraction", 2]],
		"desc": "Wagonnets dans le noir, squelettes et toiles d'araignée. Le fantôme du toit est un ancien comptable."},
	"tour_chute": {"name": "Tour de chute libre", "w": 14, "d": 14, "access": [], "emplois": 2, "cost": 3_500_000,
		"parc": {"role": "attraction", "cap": 16, "cycle": 3.0, "exc": 8.0, "int": 7.0, "attrait": 5.0, "usure": 0.12, "anim": "tour"},
		"metiers": [["operateur_attraction", 1], ["technicien_attraction", 1]],
		"desc": "50 m de montée tranquille, puis 3 secondes de chute libre. Les lunettes restent en bas."},
	"montagnes_russes": {"name": "Montagnes russes familiales", "w": 60, "d": 34, "access": [], "emplois": 4, "cost": 6_000_000,
		"parc": {"role": "attraction", "cap": 20, "cycle": 2.5, "exc": 7.0, "int": 5.0, "attrait": 7.0, "usure": 0.06, "anim": "coaster"},
		"metiers": [["operateur_attraction", 3], ["technicien_attraction", 1]],
		"desc": "Une bosse de 14 m, des virages relevés, un train de cinq wagons. La reine du parc."},
	"friterie_parc": {"name": "Friterie", "w": 8, "d": 7, "access": [], "emplois": 2, "cost": 120_000,
		"parc": {"role": "stand", "vend": "manger", "prix": 8.0, "service": 70.0, "anim": "enseigne"},
		"metiers": [["vendeur_parc", 2]],
		"desc": "Frites, hot-dogs et croque-monsieur. Le cornet géant sur le toit est en résine (ne pas le manger)."},
	"glacier_parc": {"name": "Glacier", "w": 6, "d": 6, "access": [], "emplois": 1, "cost": 80_000,
		"parc": {"role": "stand", "vend": "manger", "prix": 4.5, "service": 60.0, "anim": "enseigne"},
		"metiers": [["vendeur_parc", 1]],
		"desc": "Glaces à l'italienne et barbe à papa. Ventes doublées en été."},
	"buvette_parc": {"name": "Buvette", "w": 8, "d": 7, "access": [], "emplois": 2, "cost": 100_000,
		"parc": {"role": "stand", "vend": "boire", "prix": 3.5, "service": 90.0, "anim": "enseigne"},
		"metiers": [["vendeur_parc", 2]],
		"desc": "Sodas, eau, café et limonade. Indispensable après la file des montagnes russes."},
	"boutique_souvenirs": {"name": "Boutique de souvenirs", "w": 12, "d": 10, "access": [], "emplois": 2, "cost": 250_000,
		"parc": {"role": "stand", "vend": "souvenir", "prix": 14.0, "service": 40.0},
		"metiers": [["vendeur_parc", 2]],
		"desc": "Peluches, casquettes et photos du looping (sur lesquelles personne n'est à son avantage)."},
	"toilettes_parc": {"name": "Toilettes", "w": 8, "d": 6, "access": [], "emplois": 0, "cost": 90_000,
		"parc": {"role": "toilettes", "service": 120.0},
		"desc": "Sans elles, les visiteurs partent plus tôt, et de mauvaise humeur."},
	"aire_repos_parc": {"name": "Aire de repos", "w": 12, "d": 12, "access": [], "emplois": 0, "cost": 40_000,
		"parc": {"role": "repos", "places": 40},
		"desc": "Bancs, parasols, poubelles et un arbre. Les visiteurs fatigués y reprennent des forces."},
	"atelier_parc": {"name": "Atelier d'entretien", "w": 20, "d": 14, "access": [], "emplois": 10, "cost": 500_000,
		"parc": {"role": "atelier"},
		"metiers": [["technicien_attraction", 4], ["agent_proprete", 6]],
		"desc": "Techniciens (révisions et pannes) et agents de propreté. Sans atelier, un dépanneur vient de l'extérieur, lentement et cher."},
}
const ORDER := ["entree_parc", "carrousel_parc", "tasses_parc", "autos_tamponneuses", "train_fantome", "grande_roue_parc",
	"chaises_volantes", "bateau_pirate", "tour_chute", "montagnes_russes", "friterie_parc", "glacier_parc", "buvette_parc",
	"boutique_souvenirs", "toilettes_parc", "aire_repos_parc", "atelier_parc"]


static func entries() -> Dictionary:
	var out := {}
	for id in ORDER:
		var t: Dictionary = TYPES[id].duplicate()
		t["cat"] = CATEGORY
		t["region"] = "monde"
		t["era"] = "moderne"
		t["style"] = ""
		t["visiteurs"] = int(t.parc.get("cap", 0)) * 10
		out[id] = t
	return out


static func spec_of(type_id: String) -> Dictionary:
	return TYPES[type_id].parc if TYPES.has(type_id) else {}


static func role_of(type_id: String) -> String:
	return String(spec_of(type_id).get("role", ""))


# --- Couleurs ------------------------------------------------------------------------------

const PAVE := Color("d8cbb3")
const PAVE_F := Color("b9ab92")
const BLANC := Color("f8f4ea")
const ROUGE := Color("d62828")
const JAUNE := Color("ffc93c")
const BLEU := Color("277da1")
const VERT := Color("43aa8b")
const ROSE := Color("f78fb3")
const VIOLET := Color("7b2cbf")
const ORANGE := Color("f77f00")
const METAL := Color("adb5bd")
const METAL_F := Color("6c757d")
const BOIS := Color("9c6644")
const VITRE := Color("33495e")
const VIFS := [Color("d62828"), Color("ffc93c"), Color("277da1"), Color("43aa8b"), Color("f78fb3"), Color("7b2cbf"), Color("f77f00"), Color("4cc9f0")]


# --- Formes utiles --------------------------------------------------------------------------

## Poutre de section carrée entre deux points quelconques.
static func beam(k: BlocMesh, a: Vector3, b: Vector3, t: float, col: Color) -> void:
	var d := b - a
	if d.length() < 0.01:
		return
	var f := d.normalized()
	var up := Vector3.UP if absf(f.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var u := f.cross(up).normalized() * (t / 2.0)
	var v := f.cross(u).normalized() * (t / 2.0)
	var c := [a + u + v, a - u + v, a - u - v, a + u - v]
	var e := [b + u + v, b - u + v, b - u - v, b + u - v]
	for i in 4:
		var j := (i + 1) % 4
		var n: Vector3 = ((c[i] + c[j]) / 2.0 - a).normalized()
		k.quad(c[i], c[j], e[j], e[i], n, col if i % 2 == 0 else col.darkened(0.08))
	k.quad(c[0], c[1], c[2], c[3], -f, col.darkened(0.1))
	k.quad(e[0], e[1], e[2], e[3], f, col.darkened(0.1))


## Cône (ou toit de chapiteau) à pans de couleurs alternées.
static func chapiteau(k: BlocMesh, cx: float, y0: float, cz: float, r: float, h: float, sides: int, c1: Color, c2: Color) -> void:
	var top := Vector3(cx, y0 + h, cz)
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var am := (a0 + a1) / 2.0
		var p0 := Vector3(cx + cos(a0) * r, y0, cz + sin(a0) * r)
		var p1 := Vector3(cx + cos(a1) * r, y0, cz + sin(a1) * r)
		var n := Vector3(cos(am) * h, r, sin(am) * h).normalized()
		k.tri(p0, p1, top, n, c1 if i % 2 == 0 else c2)
		# Lambrequin festonné sous le bord.
		var q0 := p0 + Vector3(0, -0.7, 0)
		var q1 := p1 + Vector3(0, -0.7, 0)
		k.quad(p0, p1, q1, q0, Vector3(cos(am), 0, sin(am)), c2 if i % 2 == 0 else c1)


## Anneau de poutres (jante d'une roue dans le plan XY, centré en c).
static func ring_xy(k: BlocMesh, c: Vector3, r: float, n: int, t: float, col: Color) -> void:
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		beam(k, c + Vector3(cos(a0) * r, sin(a0) * r, 0), c + Vector3(cos(a1) * r, sin(a1) * r, 0), t, col)


## Petite clôture basse en cercle (barrières des manèges).
static func barriere_ronde(k: BlocMesh, r: float, n: int, col: Color, gap := -1) -> void:
	for i in n:
		if i == gap:
			continue
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var p := Vector3(cos(a0) * r, 0, sin(a0) * r)
		var q := Vector3(cos(a1) * r, 0, sin(a1) * r)
		k.box(p.x, 0, p.z, 0.12, 1.0, 0.12, col)
		beam(k, p + Vector3(0, 0.95, 0), q + Vector3(0, 0.95, 0), 0.08, col)
		beam(k, p + Vector3(0, 0.5, 0), q + Vector3(0, 0.5, 0), 0.06, col)


## Guichet de l'attraction (devant, côté −Z) avec son panneau de file.
static func guichet(k: BlocMesh, x: float, z: float, col: Color) -> void:
	k.box(x, 0, z, 2.0, 2.4, 1.6, BLANC)
	k.box(x, 2.4, z, 2.4, 0.25, 2.0, col)
	k.box(x, 1.1, z - 0.81, 1.2, 0.8, 0.05, VITRE)
	# Barrières de la file d'attente.
	for i in 3:
		k.box(x + 2.2 + i * 1.6, 0, z - 0.6, 0.08, 1.0, 0.08, METAL_F)
	beam(k, Vector3(x + 2.2, 0.95, z - 0.6), Vector3(x + 5.4, 0.95, z - 0.6), 0.06, METAL)


static func cheval(k: BlocMesh, col: Color) -> void:
	k.box(0, 0, 0, 0.5, 0.55, 1.4, col)
	k.box(0, 0.4, -0.75, 0.35, 0.7, 0.35, col)
	k.box(0, 0.95, -0.95, 0.3, 0.3, 0.55, col)
	k.box(0, 0.55, 0.25, 0.52, 0.12, 0.5, ROUGE)
	for s in [-1.0, 1.0]:
		k.box(0.15 * s, -0.55, -0.5, 0.12, 0.6, 0.12, col.darkened(0.1))
		k.box(0.15 * s, -0.55, 0.5, 0.12, 0.6, 0.12, col.darkened(0.1))
	k.box(0, 0.25, 0.85, 0.12, 0.45, 0.25, Color("3d2b1f"))


# --- Modèles fixes ------------------------------------------------------------------------------

static func build(k: BlocMesh, id: String, t: Dictionary) -> void:
	var w := float(t.w)
	var d := float(t.d)
	match id:
		"entree_parc":
			k.plate(0, 0, w, d, PAVE)
			# Deux tours et un arc avec l'enseigne.
			for s in [-1.0, 1.0]:
				k.box(11.5 * s, 0, 0, 4.0, 9.0, 4.0, BLANC)
				k.box(11.5 * s, 9.0, 0, 4.4, 0.4, 4.4, ROUGE)
				k.pyramid(11.5 * s, 9.4, 0, 4.4, 4.4, 4.5, BLEU)
				k.cylinder(11.5 * s, 13.9, 0, 0.06, 0.06, 2.4, 4, METAL_F)
				k.box(11.5 * s + 0.7, 15.4, 0, 1.3, 0.8, 0.05, JAUNE)
				k.windows_row(11.5 * s, -2.02, 2.4, 5.0, 2, 0.7, 1.2, VITRE)
			k.box(0, 7.2, 0, 19.0, 1.6, 1.2, ROUGE)
			k.box(0, 7.5, -0.62, 15.0, 1.0, 0.05, JAUNE)
			for i in 9:
				k.box(-7.0 + i * 1.75, 7.65, -0.66, 0.9, 0.7, 0.05, VIFS[i % VIFS.size()])
			# Guichets et tourniquets.
			for i in 3:
				var x := -6.0 + i * 6.0
				k.box(x, 0, 2.0, 3.2, 2.8, 2.6, BLANC)
				k.box(x, 2.8, 2.0, 3.6, 0.3, 3.0, [ROUGE, JAUNE, BLEU][i])
				k.box(x, 1.2, 0.68, 2.0, 1.0, 0.05, VITRE)
			for i in 8:
				var x := -8.0 + i * 2.3
				k.box(x, 0, -2.0, 0.25, 1.0, 0.25, METAL)
				k.box(x + 0.4, 0.85, -2.0, 0.6, 0.06, 0.06, METAL_F)
			# Bacs de fleurs.
			for s in [-1.0, 1.0]:
				k.box(15.0 * s, 0, -5.0, 1.6, 0.6, 1.6, BOIS)
				k.box(15.0 * s, 0.6, -5.0, 1.4, 0.4, 1.4, Color("6a994e"))
		"carrousel_parc":
			k.plate(0, 0, w, d, PAVE)
			k.cylinder(0, 0, 0, 7.8, 7.8, 0.12, 20, PAVE_F)
			barriere_ronde(k, 8.6, 20, ROUGE, 15)
			guichet(k, -6.0, -8.2, ROUGE)
		"tasses_parc":
			k.plate(0, 0, w, d, PAVE)
			k.cylinder(0, 0, 0, 7.8, 7.8, 0.1, 18, Color("e9d8a6"))
			barriere_ronde(k, 8.5, 18, BLEU, 13)
			guichet(k, -6.0, -8.2, BLEU)
		"autos_tamponneuses":
			k.plate(0, 0, w, d, PAVE)
			k.box(0, 0, 1.0, 26.0, 0.3, 17.0, Color("3d405b"))
			# Bordure en caoutchouc.
			for s in [-1.0, 1.0]:
				k.box(0, 0.3, 1.0 + 8.4 * s, 26.0, 0.45, 0.3, JAUNE)
				k.box(12.9 * s, 0.3, 1.0, 0.3, 0.45, 17.0, JAUNE)
			# Toit sur poteaux, grille électrique.
			for x in [-12.5, -4.2, 4.2, 12.5]:
				for z in [-7.2, 9.2]:
					k.box(x, 0.3, z, 0.4, 5.2, 0.4, METAL_F)
			k.box(0, 5.5, 1.0, 26.6, 0.4, 17.6, Color("2b2d42"))
			k.box(0, 5.9, 1.0, 27.0, 1.0, 18.0, ROUGE)
			k.box(0, 6.0, -8.02, 20.0, 0.8, 0.05, JAUNE)
			for i in 8:
				k.box(-10.5 + i * 3.0, 6.05, -8.06, 1.8, 0.6, 0.05, VIFS[(i + 3) % VIFS.size()])
			guichet(k, -10.0, -9.0, ROUGE)
		"grande_roue_parc":
			k.plate(0, 0, w, d, PAVE)
			var axe := Vector3(0, 18.0, 0)
			for z in [-2.6, 2.6]:
				for x in [-9.0, 9.0]:
					beam(k, Vector3(x, 0.45, z * 1.4), axe + Vector3(0, 0, z), 0.9, BLANC)
				beam(k, Vector3(-5.0, 9.0, z * 1.2), Vector3(5.0, 9.0, z * 1.2), 0.5, BLANC)
			beam(k, axe + Vector3(0, 0, -3.0), axe + Vector3(0, 0, 3.0), 1.2, METAL_F)
			# Quai d'embarquement et escalier.
			k.box(0, 0, -1.0, 8.0, 0.8, 4.0, PAVE_F)
			k.box(0, 0.8, -1.0, 8.0, 0.1, 4.0, ROUGE)
			k.box(0, 0, 4.5, 6.0, 3.0, 3.0, BLANC)
			k.box(0, 3.0, 4.5, 6.4, 0.3, 3.4, BLEU)
			guichet(k, -10.0, -6.0, BLEU)
		"chaises_volantes":
			k.plate(0, 0, w, d, PAVE)
			k.cylinder(0, 0, 0, 10.5, 10.5, 0.1, 20, PAVE_F)
			k.cylinder(0, 0, 0, 1.6, 1.2, 1.0, 10, BLEU)
			k.cylinder(0, 0, 0, 1.0, 0.9, 12.0, 10, BLANC)
			barriere_ronde(k, 11.4, 22, VIOLET, 16)
			guichet(k, -7.0, -11.0, VIOLET)
		"bateau_pirate":
			k.plate(0, 0, w, d, PAVE)
			k.box(0, 0, 0, 22.0, 0.3, 7.0, PAVE_F)
			var piv := Vector3(0, 14.0, 0)
			for z in [-4.2, 4.2]:
				beam(k, Vector3(-7.5, 0.4, z), piv + Vector3(0, 0, z), 0.8, METAL_F)
				beam(k, Vector3(7.5, 0.4, z), piv + Vector3(0, 0, z), 0.8, METAL_F)
			beam(k, piv + Vector3(0, 0, -4.4), piv + Vector3(0, 0, 4.4), 0.9, METAL)
			# Quai et barrières.
			k.box(0, 0, -5.0, 12.0, 0.6, 1.6, BOIS)
			for i in 8:
				k.box(-10.5 + i * 3.0, 0, -7.2, 0.1, 1.1, 0.1, METAL_F)
			beam(k, Vector3(-10.5, 1.05, -7.2), Vector3(10.5, 1.05, -7.2), 0.07, METAL)
			guichet(k, -10.0, -7.4, Color("3d2b1f"))
		"train_fantome":
			k.plate(0, 0, w, d, Color("5c5346"))
			var mur := Color("4a3b5c")
			k.box(0, 0, 2.0, 18.0, 7.0, 12.0, mur)
			k.gable(0, 7.0, 2.0, 18.6, 12.6, 4.0, Color("2b2d42"))
			# Tour de travers.
			k.box(7.0, 0, 5.0, 4.0, 13.0, 4.0, mur.darkened(0.1))
			k.pyramid(7.0, 13.0, 5.0, 4.8, 4.8, 4.0, Color("2b2d42"))
			var lueur := Color("b5e48c")
			k.windows_row(0, -4.05, 14.0, 4.2, 5, 1.0, 1.4, lueur)
			k.windows_row(7.0, 2.95, 3.0, 9.0, 1, 1.0, 1.4, lueur)
			# Porte d'entrée et de sortie des wagonnets, rails.
			for x in [-4.5, 3.0]:
				k.box(x, 0, -4.05, 2.6, 3.0, 0.1, Color("111111"))
				k.box(x, 3.0, -4.06, 3.2, 0.5, 0.1, ROUGE)
			k.box(-0.75, 0.0, -5.5, 9.0, 0.12, 0.8, METAL_F)
			# Pierres tombales.
			for i in 5:
				k.box(-9.0 + i * 1.4, 0, -6.5, 0.8, 1.0 + 0.2 * (i % 2), 0.25, Color("8d99ae"))
			guichet(k, 9.0, -7.5, VIOLET)
		"tour_chute":
			k.plate(0, 0, w, d, PAVE)
			k.box(0, 0, 0, 7.0, 0.5, 7.0, PAVE_F)
			k.box(0, 0, 0, 2.0, 52.0, 2.0, BLANC)
			for i in 10:
				k.box(0, 4.0 + i * 5.0, 0, 2.06, 0.8, 2.06, ROUGE if i % 2 == 0 else JAUNE)
			k.box(0, 52.0, 0, 3.4, 2.0, 3.4, ROUGE)
			k.cylinder(0, 54.0, 0, 0.1, 0.1, 3.0, 4, METAL_F)
			k.box(0, 56.5, 0, 0.3, 0.3, 0.3, Color("ff595e"))
			barriere_ronde(k, 6.2, 16, ROUGE, 12)
			guichet(k, -4.0, -6.0, ROUGE)
		"montagnes_russes":
			k.plate(0, 0, w, d, Color("8ab17d"))
			var pts := coaster_points()
			var n := pts.size()
			for i in n:
				var a: Vector3 = pts[i]
				var b: Vector3 = pts[(i + 1) % n]
				var side := (b - a).cross(Vector3.UP).normalized() * 0.55
				beam(k, a + side, b + side, 0.22, ROUGE)
				beam(k, a - side, b - side, 0.22, ROUGE)
				beam(k, a + Vector3(0, -0.35, 0), b + Vector3(0, -0.35, 0), 0.3, METAL_F)
				if i % 2 == 0:
					beam(k, a + side, a - side, 0.12, METAL)
				if i % 4 == 0 and a.y > 1.2:
					beam(k, Vector3(a.x, 0, a.z), a + Vector3(0, -0.4, 0), 0.35, JAUNE)
			# Gare (côté −Z, devant) et sa marquise.
			k.box(0, 0, -15.2, 14.0, 1.0, 3.0, PAVE_F)
			for x in [-6.5, 0.0, 6.5]:
				k.box(x, 1.0, -16.4, 0.3, 3.0, 0.3, BLANC)
			k.box(0, 4.0, -14.6, 14.6, 0.4, 4.2, BLEU)
			k.box(0, 4.4, -16.5, 8.0, 0.9, 0.1, JAUNE)
			guichet(k, -11.0, -15.5, ROUGE)
			for i in 8:
				k.tree(-20.0 + i * 6.0, 3.0 + (i % 3) * 2.0, 0.9 + 0.1 * (i % 2), Color("40916c"))
		"friterie_parc":
			k.plate(0, 0, w, d, PAVE)
			k.box(0, 0, 0.5, 6.0, 3.0, 4.5, BLANC)
			k.box(0, 1.0, -1.77, 4.6, 1.2, 0.05, VITRE)
			_store(k, -1.8, 6.6, JAUNE, ROUGE)
			k.box(0, 0, -2.4, 5.0, 1.0, 0.6, Color("e9e2c8"))
		"glacier_parc":
			k.plate(0, 0, w, d, PAVE)
			k.box(0, 0, 0.4, 4.4, 2.8, 3.6, Color("caf0f8"))
			k.box(0, 1.0, -1.42, 3.2, 1.1, 0.05, VITRE)
			_store(k, -1.45, 5.0, ROSE, BLANC)
		"buvette_parc":
			k.plate(0, 0, w, d, PAVE)
			k.box(0, 0, 0.5, 6.0, 3.0, 4.5, Color("d8f3dc"))
			k.box(0, 1.0, -1.77, 4.6, 1.2, 0.05, VITRE)
			_store(k, -1.8, 6.6, VERT, BLANC)
			k.box(0, 0, -2.4, 5.0, 1.0, 0.6, BOIS)
		"boutique_souvenirs":
			k.plate(0, 0, w, d, PAVE)
			k.box(0, 0, 0.5, 10.0, 3.6, 8.0, Color("ffe8d6"))
			k.gable(0, 3.6, 0.5, 10.6, 8.6, 2.4, VIOLET)
			k.windows_row(0, -3.55, 8.0, 0.8, 2, 2.4, 2.0, VITRE)
			k.box(0, 0, -3.55, 1.6, 2.6, 0.1, BOIS)
			k.box(0, 3.0, -3.6, 6.0, 0.6, 0.05, JAUNE)
			# Grappe de ballons devant la porte.
			for i in 7:
				var a := float(i) * 0.9
				k.cylinder(3.5 + cos(a) * 0.6, 2.2, -4.2 + sin(a) * 0.4, 0.0, 0.0, 0.0, 4, METAL)
				k.box(3.5 + cos(a) * 0.6, 2.4 + float(i % 3) * 0.4, -4.2 + sin(a) * 0.4, 0.5, 0.6, 0.5, VIFS[i % VIFS.size()])
		"toilettes_parc":
			k.plate(0, 0, w, d, PAVE)
			k.box(0, 0, 0.3, 7.0, 3.0, 4.6, Color("e9ecef"))
			k.box(0, 3.0, 0.3, 7.4, 0.3, 5.0, BLEU)
			k.box(-1.8, 0, -1.96, 1.0, 2.1, 0.06, Color("4895ef"))
			k.box(1.8, 0, -1.96, 1.0, 2.1, 0.06, ROSE)
			k.box(0, 2.3, -1.99, 1.0, 0.5, 0.04, BLANC)
		"aire_repos_parc":
			k.plate(0, 0, w, d, Color("8ab17d"))
			k.plate(0, 0, 8.0, 8.0, PAVE, 0.0, 0.1)
			k.tree(3.5, 3.5, 1.3, Color("52b788"))
			for i in 4:
				var a := TAU * i / 4.0 + 0.4
				var x := cos(a) * 2.6
				var z := sin(a) * 2.6
				k.box(x, 0.4, z, 1.6, 0.1, 0.5, BOIS)
				k.box(x, 0, z, 1.4, 0.4, 0.3, METAL_F)
				k.cylinder(x * 1.6, 0, z * 1.6, 0.05, 0.05, 2.4, 4, METAL)
				chapiteau(k, x * 1.6, 2.4, z * 1.6, 1.4, 0.6, 8, VIFS[i], BLANC)
			for s in [-1.0, 1.0]:
				k.cylinder(4.6 * s, 0, -4.6, 0.3, 0.3, 0.9, 8, VERT)
		"atelier_parc":
			k.plate(0, 0, w, d, Color("b9b6ae"))
			k.box(0, 0, 1.0, 16.0, 6.0, 10.0, Color("dee2e6"))
			k.gable(0, 6.0, 1.0, 16.6, 10.6, 1.8, METAL_F)
			k.box(-3.0, 0, -4.05, 5.0, 4.5, 0.1, Color("6c757d"))
			k.box(4.5, 1.2, -4.05, 3.0, 1.2, 0.08, VITRE)
			k.box(4.5, 0, -4.06, 1.0, 2.2, 0.08, BOIS)
			k.box(0, 5.2, -4.1, 6.0, 0.6, 0.05, JAUNE)
			# Chariot de nettoyage et nacelle élévatrice.
			k.box(-8.0, 0, -5.5, 1.0, 1.0, 1.4, VERT)
			k.box(7.5, 0, -5.5, 1.8, 1.2, 3.0, ORANGE)
			beam(k, Vector3(7.5, 1.2, -5.0), Vector3(7.5, 5.0, -4.0), 0.3, ORANGE)
		_:
			k.plate(0, 0, w, d, PAVE)
			k.box(0, 0, 0, w * 0.5, 4, d * 0.5, BLANC)


## Auvent rayé du stand (devant, côté −Z) et support de l'enseigne au-dessus.
static func _store(k: BlocMesh, z: float, larg: float, c1: Color, c2: Color) -> void:
	var n := 6
	for i in n:
		var x := -larg / 2.0 + larg * (i + 0.5) / n
		k.panel(Vector3(x - larg / n / 2.0, 3.0, z), Vector3(x + larg / n / 2.0, 3.0, z),
			Vector3(x + larg / n / 2.0, 2.4, z - 1.3), Vector3(x - larg / n / 2.0, 2.4, z - 1.3), Vector3(0, 1, -1), c1 if i % 2 == 0 else c2)
	k.box(0, 3.0, z + 2.0, 0.3, 0.6, 0.3, METAL_F)


# --- Montagnes russes : tracé ------------------------------------------------------------------

const COASTER_N := 72

static var _coaster: PackedVector3Array


## Points du tracé (boucle fermée) dans le repère du bâtiment. La gare est au
## point 0, devant (z ≈ −14), le haut de la bosse à l'arrière.
static func coaster_points() -> PackedVector3Array:
	if not _coaster.is_empty():
		return _coaster
	var out := PackedVector3Array()
	for i in COASTER_N:
		var u := TAU * float(i) / COASTER_N
		# Ovale déformé : grand virage relevé à droite, lacet à gauche.
		var x := 25.0 * sin(u) + 2.0 * sin(2.0 * u)
		var z := -13.0 * cos(u) + 3.0 * sin(3.0 * u) * 0.5
		var y := 1.6
		var s := fposmod(u / TAU, 1.0)
		if s < 0.3:
			y = 1.6 + 12.5 * smoothstep(0.03, 0.28, s)
		elif s < 0.45:
			y = 14.1 - 11.0 * smoothstep(0.3, 0.42, s)
		else:
			y = 3.1 + 3.0 * sin((s - 0.45) / 0.5 * TAU * 1.5) * (1.0 - smoothstep(0.85, 0.97, s)) - 1.5 * smoothstep(0.85, 0.97, s)
		out.append(Vector3(x, maxf(y, 1.2), z))
	_coaster = out
	return out


# --- Parties mobiles ------------------------------------------------------------------------------

## Même matériau que les bâtiments (couleurs, vitres éclairées la nuit).
static func material() -> Material:
	return NightWindows.building_material()


static func _mi(k: BlocMesh, nom: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nom
	mi.mesh = k.to_mesh(material())
	mi.visibility_range_end = 900.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return mi


static func _nacelle(col: Color) -> BlocMesh:
	var k := BlocMesh.new()
	k.box(0, -0.4, 0, 0.12, 0.4, 0.12, METAL_F)
	k.box(0, -0.65, 0, 1.6, 0.25, 1.4, col)
	k.box(0, -2.5, 0, 1.4, 1.85, 1.2, col.lightened(0.2))
	k.box(0, -2.0, 0, 1.46, 0.8, 1.26, VITRE)
	k.box(0, -2.7, 0, 1.5, 0.2, 1.3, col)
	return k


## Parties mobiles d'un objet du parc (vide si rien ne bouge).
static func build_anim(id: String) -> Node3D:
	var spec := spec_of(id)
	var root := Node3D.new()
	root.name = "Anim"
	match String(spec.get("anim", "")):
		"carrousel":
			var rot := Node3D.new()
			rot.name = "rot"
			root.add_child(rot)
			var k := BlocMesh.new()
			k.cylinder(0, 0.12, 0, 7.2, 7.2, 0.5, 20, BOIS)
			k.cylinder(0, 0.62, 0, 7.0, 7.0, 0.05, 20, Color("e9c46a"))
			k.cylinder(0, 0.6, 0, 1.6, 1.4, 5.0, 12, ROUGE)
			k.cylinder(0, 2.0, 0, 1.7, 1.7, 1.6, 12, Color("ffd6a5"))
			for i in 12:
				var a := TAU * i / 12.0
				k.cylinder(cos(a) * 5.8, 0.6, sin(a) * 5.8, 0.05, 0.05, 4.6, 4, Color("ffd166"))
			chapiteau(k, 0, 5.6, 0, 7.6, 3.2, 16, ROUGE, BLANC)
			k.cylinder(0, 8.8, 0, 0.06, 0.06, 1.2, 4, METAL_F)
			k.box(0.4, 9.6, 0, 0.8, 0.5, 0.05, JAUNE)
			rot.add_child(_mi(k, "plateau"))
			for i in 12:
				var a := TAU * i / 12.0
				var hk := BlocMesh.new()
				cheval(hk, [BLANC, Color("3d2b1f"), Color("ffd6a5"), Color("cdb4db")][i % 4])
				var h := _mi(hk, "cheval_%d" % i)
				h.position = Vector3(cos(a) * 5.8, 2.0, sin(a) * 5.8)
				h.rotation.y = -a
				rot.add_child(h)
		"tasses":
			var rot := Node3D.new()
			rot.name = "rot"
			root.add_child(rot)
			var k := BlocMesh.new()
			k.cylinder(0, 0.1, 0, 7.2, 7.2, 0.3, 18, BLEU)
			k.cylinder(0, 0.4, 0, 1.2, 0.4, 3.0, 8, JAUNE)
			k.cylinder(0, 3.4, 0, 0.8, 0.8, 0.5, 8, ROUGE)
			rot.add_child(_mi(k, "plateau"))
			for j in 3:
				var a := TAU * j / 3.0
				var sub := Node3D.new()
				sub.name = "sous_%d" % j
				sub.position = Vector3(cos(a) * 4.2, 0.4, sin(a) * 4.2)
				rot.add_child(sub)
				var sk := BlocMesh.new()
				sk.cylinder(0, 0, 0, 2.6, 2.6, 0.15, 12, BLANC)
				sub.add_child(_mi(sk, "disque"))
				for c in 3:
					var b := TAU * c / 3.0
					var ck := BlocMesh.new()
					ck.lathe(0, 0, 0, [Vector2(0.0, 0.0), Vector2(0.75, 0.05), Vector2(1.0, 0.6), Vector2(1.05, 1.2), Vector2(0.95, 1.2)], 10, VIFS[(j * 3 + c) % VIFS.size()])
					ck.cylinder(0, 0.15, 0, 0.18, 0.18, 0.7, 6, METAL)
					ck.box(1.15, 0.5, 0, 0.3, 0.5, 0.12, VIFS[(j * 3 + c) % VIFS.size()])
					var cup := _mi(ck, "tasse_%d" % c)
					cup.position = Vector3(cos(b) * 1.5, 0.15, sin(b) * 1.5)
					sub.add_child(cup)
		"autos":
			for i in 12:
				var k := BlocMesh.new()
				var col: Color = VIFS[i % VIFS.size()]
				k.box(0, 0.05, 0, 1.4, 0.55, 2.1, col)
				k.box(0, 0.05, 0, 1.6, 0.3, 2.3, Color("222222"))
				k.box(0, 0.6, 0.35, 1.0, 0.5, 0.6, col.darkened(0.2))
				k.box(0, 0.6, -0.55, 0.5, 0.4, 0.3, Color("444444"))
				k.cylinder(0, 0.6, 0.6, 0.04, 0.04, 4.3, 4, METAL)
				var car := _mi(k, "auto_%d" % i)
				car.position = Vector3(0, 0.3, 1.0)
				root.add_child(car)
		"roue":
			var axe := Node3D.new()
			axe.name = "axe"
			axe.position = Vector3(0, 18.0, 0)
			root.add_child(axe)
			var wheel := Node3D.new()
			wheel.name = "roue"
			axe.add_child(wheel)
			var k := BlocMesh.new()
			for z in [-1.4, 1.4]:
				ring_xy(k, Vector3(0, 0, z), 15.0, 32, 0.35, BLANC)
				ring_xy(k, Vector3(0, 0, z), 9.0, 16, 0.25, ROUGE)
				for i in 16:
					var a := TAU * i / 16.0
					beam(k, Vector3(0, 0, z * 0.4), Vector3(cos(a) * 15.0, sin(a) * 15.0, z), 0.18, BLANC)
			for i in 16:
				var a := TAU * i / 16.0
				beam(k, Vector3(cos(a) * 15.0, sin(a) * 15.0, -1.4), Vector3(cos(a) * 15.0, sin(a) * 15.0, 1.4), 0.2, METAL_F)
			k.cylinder(0, -0.2, 0, 1.4, 1.4, 0.4, 10, JAUNE)
			var mi := _mi(k, "jante")
			wheel.add_child(mi)
			for i in 16:
				var g := _mi(_nacelle(VIFS[i % VIFS.size()]), "nacelle_%d" % i)
				axe.add_child(g)
		"chaises":
			var tete := Node3D.new()
			tete.name = "tete"
			tete.position = Vector3(0, 8.0, 0)
			root.add_child(tete)
			var k := BlocMesh.new()
			k.cylinder(0, 0, 0, 1.3, 1.3, 1.2, 10, BLANC)
			chapiteau(k, 0, 1.6, 0, 7.5, 2.4, 16, VIOLET, JAUNE)
			k.cylinder(0, 0.9, 0, 7.4, 7.4, 0.7, 16, VIOLET.darkened(0.2))
			tete.add_child(_mi(k, "couronne"))
			for i in 16:
				var a := TAU * i / 16.0
				var piv := Node3D.new()
				piv.name = "piv_%d" % i
				piv.position = Vector3(cos(a) * 6.8, 0.9, sin(a) * 6.8)
				piv.rotation.y = -a
				tete.add_child(piv)
				var ck := BlocMesh.new()
				beam(ck, Vector3(0, 0, -0.25), Vector3(0, -4.6, -0.25), 0.05, METAL)
				beam(ck, Vector3(0, 0, 0.25), Vector3(0, -4.6, 0.25), 0.05, METAL)
				ck.box(0, -5.0, 0, 0.6, 0.12, 0.6, VIFS[i % VIFS.size()])
				ck.box(-0.25, -5.0, 0, 0.1, 0.6, 0.6, VIFS[i % VIFS.size()])
				piv.add_child(_mi(ck, "chaise"))
		"bateau":
			var piv := Node3D.new()
			piv.name = "pivot"
			piv.position = Vector3(0, 14.0, 0)
			root.add_child(piv)
			var k := BlocMesh.new()
			var hy := -11.2
			# Coque : flancs et pont, proue et poupe relevées.
			var hull := Color("6f4518")
			var L := 9.5
			for s in [-1.0, 1.0]:
				k.panel(Vector3(-L, hy - 1.6, 1.6 * s), Vector3(L, hy - 1.6, 1.6 * s), Vector3(L + 1.6, hy + 1.2, 2.4 * s), Vector3(-L - 1.6, hy + 1.2, 2.4 * s), Vector3(0, 0, s), hull)
				k.box(0, hy + 1.2, 2.4 * s, (L + 1.6) * 2.0, 0.4, 0.2, Color("ffc93c"))
			k.panel(Vector3(-L, hy - 1.6, -1.6), Vector3(L, hy - 1.6, -1.6), Vector3(L, hy - 1.6, 1.6), Vector3(-L, hy - 1.6, 1.6), Vector3.DOWN, hull.darkened(0.2))
			k.box(0, hy + 0.2, 0, L * 2.0, 0.2, 4.4, BOIS)
			for s in [-1.0, 1.0]:
				k.panel(Vector3(L * s, hy - 1.6, -1.6), Vector3(L * s, hy - 1.6, 1.6), Vector3((L + 1.6) * s, hy + 1.2, 2.4), Vector3((L + 1.6) * s, hy + 1.2, -2.4), Vector3(s, 0, 0), hull.darkened(0.1))
				k.box((L + 0.6) * s, hy + 1.2, 0, 2.0, 1.6, 4.6, hull.lightened(0.1))
			# Bancs, mât, voile à tête de mort.
			for i in 6:
				k.box(-7.0 + i * 2.8, hy + 0.4, 0, 0.6, 0.5, 4.0, ROUGE)
			k.cylinder(0, hy + 0.4, 0, 0.18, 0.15, 7.0, 6, BOIS)
			k.box(0, hy + 3.0, 0, 5.0, 3.4, 0.08, BLANC)
			k.box(0, hy + 4.3, -0.06, 1.0, 1.0, 0.04, Color("222222"))
			k.box(0.0, hy + 7.4, 0, 1.4, 0.8, 0.05, Color("111111"))
			# Bras vers le pivot.
			for z in [-2.0, 2.0]:
				beam(k, Vector3(0, 0, z * 1.8), Vector3(-6.0, hy + 1.0, z), 0.5, METAL_F)
				beam(k, Vector3(0, 0, z * 1.8), Vector3(6.0, hy + 1.0, z), 0.5, METAL_F)
			piv.add_child(_mi(k, "bateau"))
		"tour":
			var k := BlocMesh.new()
			k.cylinder(0, 0, 0, 3.0, 3.0, 1.2, 12, JAUNE)
			k.cylinder(0, 1.2, 0, 3.1, 3.1, 0.25, 12, ROUGE)
			for i in 12:
				var a := TAU * i / 12.0
				k.box(cos(a) * 2.6, -0.6, sin(a) * 2.6, 0.5, 0.6, 0.5, Color("222222"))
				k.box(cos(a) * 2.6, 0.2, sin(a) * 2.6, 0.55, 1.4, 0.2, Color("444444"))
			var g := _mi(k, "nacelle")
			g.position = Vector3(0, 1.5, 0)
			root.add_child(g)
		"coaster":
			for i in 5:
				var k := BlocMesh.new()
				var col: Color = [ROUGE, JAUNE, BLEU, VERT, ORANGE][i]
				k.box(0, 0.0, 0, 1.6, 0.8, 2.0, col)
				k.box(0, 0.8, 0.5, 1.6, 0.5, 0.25, col.darkened(0.25))
				k.box(0, 0.8, -0.5, 1.6, 0.5, 0.25, col.darkened(0.25))
				if i == 0:
					k.box(0, 0.8, -0.95, 1.6, 0.6, 0.3, col)
				var w := _mi(k, "wagon_%d" % i)
				root.add_child(w)
		"fantome":
			var k := BlocMesh.new()
			k.dome(0, 1.0, 0, 1.0, 1.2, BLANC, 10)
			k.cylinder(0, -0.6, 0, 1.2, 1.0, 1.6, 10, BLANC)
			k.box(-0.35, 1.3, -0.95, 0.22, 0.35, 0.05, Color("111111"))
			k.box(0.35, 1.3, -0.95, 0.22, 0.35, 0.05, Color("111111"))
			k.box(0, 0.8, -0.97, 0.4, 0.3, 0.05, Color("111111"))
			var g := _mi(k, "fantome")
			g.position = Vector3(7.0, 20.0, 5.0)
			root.add_child(g)
		"enseigne":
			var k := BlocMesh.new()
			match id:
				"friterie_parc":
					k.cylinder(0, 0, 0, 0.2, 1.1, 2.2, 8, ROUGE)
					for i in 9:
						k.box(-0.7 + (i % 3) * 0.7, 2.0 + (i / 3) * 0.25, -0.4 + (i % 2) * 0.6, 0.18, 1.0, 0.18, JAUNE)
				"glacier_parc":
					k.cylinder(0, 0, 0, 0.1, 0.9, 2.0, 8, Color("d4a373"))
					k.dome(0, 2.0, 0, 0.95, 0.9, ROSE, 10)
					k.dome(0, 2.6, 0, 0.6, 0.7, BLANC, 10)
					k.box(0, 3.25, 0, 0.25, 0.25, 0.25, ROUGE)
				_:
					k.cylinder(0, 0, 0, 0.7, 0.9, 2.2, 10, ROUGE)
					k.cylinder(0, 2.2, 0, 0.95, 0.95, 0.25, 10, BLANC)
					k.cylinder(0.3, 2.4, 0, 0.08, 0.08, 1.2, 4, Color("ffc93c"))
			var s := _mi(k, "enseigne")
			var z := -1.45 if id == "glacier_parc" else -1.8
			s.position = Vector3(0, 3.3 if id != "glacier_parc" else 2.8, z + 2.0)
			root.add_child(s)
	if root.get_child_count() == 0:
		root.free()
		return null
	return root


## Fait bouger les parties mobiles. t : secondes (temps réel), dt : durée de
## l'image, marche : 0 (arrêt) à 1, phase : décalage propre à chaque attraction.
static func animate(root: Node3D, id: String, t: float, dt: float, marche: float, phase := 0.0) -> void:
	var spec := spec_of(id)
	var tt := t + phase
	match String(spec.get("anim", "")):
		"carrousel":
			var rot: Node3D = root.get_node("rot")
			var a := fposmod(float(root.get_meta("a", 0.0)) + dt * 0.9 * marche, TAU)
			root.set_meta("a", a)
			rot.rotation.y = a
			for i in 12:
				var h: Node3D = rot.get_node("cheval_%d" % i)
				h.position.y = 2.0 + 0.45 * sin(tt * 2.2 + i * 1.3) * marche
		"tasses":
			var rot: Node3D = root.get_node("rot")
			var a := float(root.get_meta("a", 0.0)) + dt * 0.6 * marche
			root.set_meta("a", a)
			rot.rotation.y = a
			for j in 3:
				var sub: Node3D = rot.get_node("sous_%d" % j)
				sub.rotation.y = -a * 2.2
				for c in 3:
					(sub.get_node("tasse_%d" % c) as Node3D).rotation.y = a * (3.0 + c)
		"autos":
			for i in 12:
				var car: Node3D = root.get_node("auto_%d" % i)
				var u := float(root.get_meta("u%d" % i, float(i) * 0.9))
				u += dt * (0.5 + 0.08 * (i % 5)) * marche
				root.set_meta("u%d" % i, u)
				var x := 10.5 * sin(u * 1.0 + i) * cos(u * 0.37 + i * 0.5)
				var z := 1.0 + 6.5 * sin(u * 1.3 + i * 2.1)
				var dx := x - car.position.x
				var dz := z - car.position.z
				if dx * dx + dz * dz > 0.0001:
					car.rotation.y = atan2(-dx, -dz)
				car.position = Vector3(x, 0.3, z)
		"roue":
			var axe: Node3D = root.get_node("axe")
			var wheel: Node3D = axe.get_node("roue")
			var a := float(root.get_meta("a", 0.0)) + dt * 0.12 * marche
			root.set_meta("a", a)
			wheel.rotation.z = a
			for i in 16:
				var b := a + TAU * i / 16.0
				var g: Node3D = axe.get_node("nacelle_%d" % i)
				g.position = Vector3(cos(b) * 15.0, sin(b) * 15.0, 0)
		"chaises":
			var tete: Node3D = root.get_node("tete")
			var m := float(root.get_meta("m", 0.0))
			m = move_toward(m, marche, dt * 0.25)
			root.set_meta("m", m)
			var a := float(root.get_meta("a", 0.0)) + dt * 1.4 * m
			root.set_meta("a", a)
			tete.rotation.y = a
			tete.position.y = 8.0 + 3.5 * m
			tete.rotation.x = 0.06 * m * sin(tt * 0.7)
			for i in 16:
				var piv: Node3D = tete.get_node("piv_%d" % i)
				piv.rotation.z = 0.0
				piv.rotation.x = 0.0
				(piv.get_node("chaise") as Node3D).rotation.z = -0.75 * m
		"bateau":
			var piv: Node3D = root.get_node("pivot")
			var m := float(root.get_meta("m", 0.0))
			m = move_toward(m, marche, dt * 0.12)
			root.set_meta("m", m)
			piv.rotation.z = 1.15 * m * sin(tt * 0.9)
		"tour":
			var g: Node3D = root.get_node("nacelle")
			var period := 22.0
			var s := fposmod(tt, period)
			var y := 1.5
			if marche > 0.0:
				if s < 13.0:
					y = 1.5 + 44.0 * smoothstep(0.0, 13.0, s)
				elif s < 15.0:
					y = 45.5
				elif s < 16.5:
					var f := (s - 15.0) / 1.5
					y = 45.5 - 38.0 * f * f
				elif s < 20.0:
					y = 7.5 - 6.0 * smoothstep(16.5, 20.0, s)
			g.position.y = lerpf(g.position.y, y, minf(1.0, dt * 20.0))
			g.rotation.y += dt * 0.12 * marche
		"coaster":
			var pts := coaster_points()
			var L := float(root.get_meta("L", 0.0))
			if L <= 0.0:
				for i in pts.size():
					L += pts[i].distance_to(pts[(i + 1) % pts.size()])
				root.set_meta("L", L)
			var s := float(root.get_meta("s", 0.0))
			var p := _coaster_at(pts, s, L)
			var v := 4.0
			var ymax := 14.5
			if s / L < 0.3:
				v = 3.0
			else:
				v = sqrt(maxf(2.0 * 9.81 * (ymax - p.y), 9.0))
			s = fposmod(s + v * dt * marche, L)
			root.set_meta("s", s)
			for i in 5:
				var w: Node3D = root.get_node("wagon_%d" % i)
				var si := fposmod(s - i * 2.3, L)
				var a := _coaster_at(pts, si, L)
				var b := _coaster_at(pts, fposmod(si + 0.5, L), L)
				w.position = a + Vector3(0, 0.05, 0)
				if b.distance_to(a) > 0.01:
					w.look_at_from_position(w.position, b + Vector3(0, 0.05, 0), Vector3.UP)
		"fantome":
			var g: Node3D = root.get_node("fantome")
			g.position = Vector3(7.0 + 2.2 * cos(tt * 0.6), 18.5 + 0.8 * sin(tt * 1.7), 5.0 + 2.2 * sin(tt * 0.6))
			g.rotation.y = -tt * 0.6
		"enseigne":
			var s: Node3D = root.get_node("enseigne")
			s.rotation.y = tt * 0.5


static func _coaster_at(pts: PackedVector3Array, s: float, total: float) -> Vector3:
	var n := pts.size()
	var acc := 0.0
	s = fposmod(s, total)
	for i in n:
		var a := pts[i]
		var b := pts[(i + 1) % n]
		var l := a.distance_to(b)
		if acc + l >= s:
			return a.lerp(b, (s - acc) / maxf(l, 0.001))
		acc += l
	return pts[0]
