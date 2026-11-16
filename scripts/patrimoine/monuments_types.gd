class_name MonumentsTypes
extends RefCounted
## Grands monuments : des chantiers de plusieurs années (cathédrale, basilique,
## grande mosquée, pagode, palais de verre, opéra, tour de fer, statue colossale,
## barrage, gratte-ciel, tour de télévision, grande arche, tour de 600 m).
##
## Tous sont des modèles originaux, inspirés des grands styles de leur époque,
## pas des copies de monuments réels. Chaque fiche a :
## - "annee" : année d'apparition (lue par Epoques : la tour de fer arrive en 1887) ;
## - "ans" : durée réelle des travaux pour une équipe complète, en années
##   (40 ans pour la cathédrale, 1 an et demi pour le gratte-ciel), divisée comme
##   tous les chantiers par la vitesse de la vie et le rythme des chantiers
##   (Chantiers.rythme) : une cathédrale prend environ un an de jeu ;
## - "equipe" : ouvriers d'une équipe complète ;
## - "etapes" : les étapes du chantier, propres à chaque monument (le chœur, la
##   nef, les voûtes, les tours puis la flèche d'une cathédrale…) ;
## - "prestige" : points d'attrait touristique une fois fini (Patrimoine) ;
## - "matx" : matériaux du chantier en tonnes (MateriauxChantiers), pris dans
##   les stocks de la carte au fil des travaux.
##
## Catégorie Construire « Patrimoine et grands monuments ».

const CAT := "patrimoine"
const ROAD := ["route"]

const CALCAIRE := Color("e6dcc4")
const PIERRE := Color("d2c8b2")
const PIERRE_SOMBRE := Color("b4aa94")
const ARDOISE := Color("4f5560")
const PLOMB := Color("6c7378")
const TOIT_CATH := Color("75818a")
const CUIVRE := Color("6fa595")
const OR := Color("d9b13b")
const VITRAIL := Color("3d4f8a")
const VERRE := Color("8fb8c9")
const VERRE_SOMBRE := Color("4f7185")
const FER := Color("6a4a36")
const FONTE := Color("39444a")
const BETON := Color("c2bfb6")
const BETON_CLAIR := Color("dad7cf")
const MARBRE := Color("f2efe8")
const BLANC := Color("f4f0e6")
const LAQUE := Color("b0302a")
const TUILE_VERTE := Color("3f7d4e")
const BOIS_SOMBRE := Color("5c3d24")
const BLEU_FAIENCE := Color("2f6f9e")
const SABLE := Color("e2cfa5")
const HERBE := Color("6aa84f")
const PARVIS := Color("b9b2a3")
const EAU := Color("4f86a8")
const ACIER := Color("9aa3a8")

## Étapes partagées par plusieurs monuments.
const _DEBUT := [[0.04, "terrassement", "Terrassement et piquetage"], [0.12, "fondations", "Fondations"]]

## id -> fiche (champs du catalogue + annee, ans, equipe, prestige, etapes, matx).
const TYPES := {
	"grande_cathedrale": {"name": "Grande cathédrale gothique", "region": "europe", "annee": 0, "w": 46, "d": 112,
		"cost": 90_000_000, "ans": 40.0, "equipe": 140, "prestige": 6.0, "emplois": 14, "visiteurs": 3000,
		"style_patrimoine": "Gothique",
		"etapes": [[0.04, "terrassement", "Terrassement et piquetage"], [0.12, "fondations", "Fondations et crypte"],
			[0.30, "choeur", "Le chœur et l'abside"], [0.52, "nef", "La nef et les bas-côtés"],
			[0.66, "voutes", "Voûtes et arcs-boutants"], [0.84, "tours", "Façade et tours"],
			[0.93, "fleche", "La flèche"], [1.0, "vitraux", "Vitraux, orgue et cloches"]],
		"matx": {"pierre": 52000.0, "chaux": 4800.0, "sable": 5200.0, "bois": 2600.0, "verre": 120.0, "acier": 300.0},
		"desc": "Quarante ans de chantier, trois générations de tailleurs de pierre et une flèche de 92 m. Les petits-enfants des premiers ouvriers verront la fin."},
	"basilique_coupole": {"name": "Basilique à coupole", "region": "mediterranee", "annee": 0, "w": 64, "d": 82,
		"cost": 70_000_000, "ans": 25.0, "equipe": 110, "prestige": 5.0, "emplois": 10, "visiteurs": 2400,
		"style_patrimoine": "Renaissance",
		"etapes": _DEBUT + [[0.40, "croix", "Plan en croix et piliers"], [0.62, "tambour", "Le tambour de la coupole"],
			[0.82, "coupole", "La coupole (double coque)"], [0.92, "portique", "Portique à colonnes"], [1.0, "decors", "Mosaïques et dorures"]],
		"matx": {"pierre": 38000.0, "chaux": 3600.0, "sable": 4000.0, "briques": 6000.0, "bois": 1500.0, "acier": 200.0},
		"desc": "Une coupole de 26 m de large, posée sans cintre grâce à une double coque de briques en arête de poisson. L'architecte n'en a parlé à personne."},
	"grande_mosquee": {"name": "Grande mosquée à coupoles", "region": "moyen_orient", "annee": 0, "w": 90, "d": 96,
		"cost": 60_000_000, "ans": 12.0, "equipe": 120, "prestige": 5.0, "emplois": 10, "visiteurs": 2000,
		"style_patrimoine": "Ottoman",
		"etapes": _DEBUT + [[0.40, "cour", "La cour et ses galeries"], [0.62, "salle", "Salle de prière"],
			[0.80, "coupoles", "Coupole et demi-coupoles"], [0.93, "minarets", "Les minarets"], [1.0, "faience", "Faïences et calligraphies"]],
		"matx": {"pierre": 30000.0, "chaux": 3000.0, "sable": 3500.0, "briques": 3000.0, "bois": 800.0, "cuivre": 120.0},
		"desc": "Une grande coupole, quatre demi-coupoles, deux minarets de 64 m et 20 000 carreaux de faïence posés un par un."},
	"pagode_neuf_etages": {"name": "Pagode à neuf étages", "region": "asie_est", "annee": 0, "w": 34, "d": 34,
		"cost": 18_000_000, "ans": 8.0, "equipe": 60, "prestige": 3.0, "emplois": 5, "visiteurs": 1200,
		"style_patrimoine": "Asie de l'Est",
		"etapes": _DEBUT + [[0.30, "terrasse", "Terrasse de pierre"], [0.55, "bas", "Les trois premiers étages"],
			[0.78, "milieu", "Les étages du milieu"], [0.92, "haut", "Le dernier étage et la flèche"], [1.0, "laque", "Laque, tuiles vernissées et clochettes"]],
		"matx": {"pierre": 5000.0, "bois": 3200.0, "tuiles": 600.0, "chaux": 300.0},
		"desc": "Neuf toits de tuiles vernissées et 72 clochettes : on entend le vent tourner avant de le sentir."},
	"palais_cristal": {"name": "Palais de verre et de fonte", "region": "europe", "annee": 1851, "w": 150, "d": 56,
		"cost": 40_000_000, "ans": 1.0, "equipe": 220, "prestige": 4.0, "emplois": 20, "visiteurs": 4000,
		"style_patrimoine": "Architecture de fer",
		"etapes": _DEBUT + [[0.45, "colonnes", "Colonnes et poutres de fonte"], [0.70, "nef", "Grande nef en verre"],
			[0.88, "transept", "Transept voûté"], [1.0, "expo", "Jardins d'hiver et exposition"]],
		"matx": {"acier": 5700.0, "verre": 900.0, "bois": 600.0, "pierre": 2000.0},
		"desc": "300 000 vitres et des pièces de fonte toutes identiques : monté en six mois pour l'Exposition universelle, comme un jeu de construction géant."},
	"grand_opera": {"name": "Grand opéra", "region": "europe", "annee": 1861, "w": 72, "d": 112,
		"cost": 75_000_000, "ans": 14.0, "equipe": 120, "prestige": 5.0, "emplois": 60, "visiteurs": 2000,
		"style_patrimoine": "Second Empire",
		"etapes": _DEBUT + [[0.30, "cuvelage", "Cuvelage (une nappe d'eau sous la scène)"], [0.55, "salle", "Salle et grand escalier"],
			[0.72, "cage", "Cage de scène"], [0.88, "coupole", "Coupole de cuivre et statues dorées"], [1.0, "foyer", "Grand foyer, lustre et peintures"]],
		"matx": {"pierre": 34000.0, "chaux": 2500.0, "sable": 3000.0, "acier": 2000.0, "verre": 200.0, "bois": 1400.0},
		"desc": "Marbres de douze couleurs, un lustre de 8 tonnes et un lac sous la scène. Les répétitions ont commencé avant la fin des travaux."},
	"tour_fer": {"name": "Tour de fer de 240 m", "region": "europe", "annee": 1887, "w": 110, "d": 110,
		"cost": 55_000_000, "ans": 2.2, "equipe": 250, "prestige": 8.0, "emplois": 30, "visiteurs": 6000,
		"style_patrimoine": "Architecture de fer",
		"etapes": _DEBUT + [[0.35, "piles", "Les quatre piles"], [0.55, "premier", "Premier étage"],
			[0.80, "second", "Second étage"], [0.95, "sommet", "Le sommet et son phare"], [1.0, "ascenseurs", "Ascenseurs et peinture"]],
		"matx": {"acier": 8300.0, "pierre": 3000.0, "ciment": 600.0},
		"desc": "18 000 pièces de fer et 2,5 millions de rivets posés à chaud. Les artistes ont signé une pétition contre : aujourd'hui, ils la dessinent."},
	"statue_colossale": {"name": "Statue colossale du Génie", "region": "monde", "annee": 1884, "w": 56, "d": 56,
		"cost": 22_000_000, "ans": 9.0, "equipe": 70, "prestige": 4.0, "emplois": 8, "visiteurs": 2500,
		"style_patrimoine": "Néoclassique",
		"etapes": _DEBUT + [[0.40, "socle", "Socle de granit"], [0.65, "charpente", "Charpente de fer intérieure"],
			[0.90, "cuivre", "Plaques de cuivre martelé"], [1.0, "etoile", "L'étoile dorée"]],
		"matx": {"granite": 22000.0, "ciment": 2000.0, "acier": 125.0, "cuivre": 80.0},
		"desc": "Un génie de cuivre de 46 m tend une étoile dorée vers le ciel. Le cuivre vire au vert en vingt ans : personne ne l'avait prévu."},
	"barrage_poids": {"name": "Grand barrage hydroélectrique", "region": "monde", "annee": 1905, "w": 230, "d": 48,
		"cost": 180_000_000, "ans": 7.0, "equipe": 300, "prestige": 1.6, "emplois": 40, "visiteurs": 600,
		"style_patrimoine": "Génie civil",
		"reseau": {"res": "elec", "cap": 350.0, "source": "riviere", "pres_eau": 220.0},
		"etapes": _DEBUT + [[0.30, "derivation", "Galerie de dérivation de la rivière"], [0.70, "mur", "Le mur de béton, plot par plot"],
			[0.85, "usine", "Usine et turbines"], [0.95, "vannes", "Évacuateur de crues et vannes"], [1.0, "mise_en_eau", "Mise en eau"]],
		"matx": {"ciment": 90000.0, "sable": 160000.0, "pierre": 260000.0, "acier": 6000.0},
		"desc": "Un mur de béton de 52 m et quatre turbines : 350 MW au fil de l'eau (rivière à moins de 220 m). Les gens viennent le dimanche regarder les vannes s'ouvrir."},
	"gratte_ciel_art_deco": {"name": "Gratte-ciel Art déco", "region": "ameriques", "annee": 1930, "w": 56, "d": 56,
		"cost": 160_000_000, "ans": 1.6, "equipe": 400, "prestige": 4.0, "emplois": 900, "visiteurs": 3000,
		"style_patrimoine": "Art déco",
		"etapes": _DEBUT + [[0.40, "acier", "Charpente d'acier (4 étages par semaine)"], [0.72, "facades", "Façades de pierre et d'aluminium"],
			[0.90, "gradins", "Les retraits en gradins"], [1.0, "couronne", "Couronne d'acier et flèche"]],
		"matx": {"acier": 57000.0, "pierre": 20000.0, "ciment": 8000.0, "sable": 15000.0, "verre": 800.0},
		"desc": "102 étages en 410 jours : les riveteurs déjeunent assis sur les poutres, à 300 m du trottoir. Un observatoire au sommet."},
	"tour_television": {"name": "Tour de télévision", "region": "monde", "annee": 1965, "w": 44, "d": 44,
		"cost": 38_000_000, "ans": 4.0, "equipe": 90, "prestige": 3.5, "emplois": 40, "visiteurs": 2500,
		"style_patrimoine": "Moderne",
		"etapes": _DEBUT + [[0.60, "fut", "Fût en béton coulé en continu"], [0.80, "sphere", "La sphère panoramique"],
			[0.95, "antenne", "Mât d'antenne"], [1.0, "restaurant", "Restaurant tournant"]],
		"matx": {"ciment": 6000.0, "sable": 12000.0, "pierre": 18000.0, "acier": 2600.0, "verre": 120.0},
		"desc": "Une boule d'acier à 200 m et un restaurant qui fait un tour par heure. Ne commandez pas la soupe."},
	"arche_fraternite": {"name": "Arche de la Fraternité", "region": "europe", "annee": 1985, "w": 116, "d": 100,
		"cost": 120_000_000, "ans": 7.0, "equipe": 200, "prestige": 4.0, "emplois": 500, "visiteurs": 2000,
		"style_patrimoine": "Contemporain",
		"etapes": _DEBUT + [[0.40, "piles", "Les douze piles du socle"], [0.68, "parois", "Les deux parois de bureaux"],
			[0.88, "toit", "Le toit (une poutre de 100 m)"], [1.0, "marbre", "Parement de marbre et le Nuage"]],
		"matx": {"ciment": 30000.0, "sable": 60000.0, "pierre": 70000.0, "acier": 12000.0, "verre": 2000.0},
		"desc": "Un cube creux de 100 m de côté, assez grand pour y glisser une cathédrale. Une toile tendue, le Nuage, flotte dedans."},
	"tour_verre_600": {"name": "Tour-flèche de 600 m", "region": "monde", "annee": 2008, "w": 78, "d": 78,
		"cost": 600_000_000, "ans": 6.0, "equipe": 500, "prestige": 7.0, "emplois": 3000, "visiteurs": 5000,
		"style_patrimoine": "Contemporain",
		"etapes": _DEBUT + [[0.30, "radier", "Pieux et radier de 3 m d'épaisseur"], [0.70, "noyau", "Noyau de béton (coffrage grimpant)"],
			[0.88, "facades", "Murs-rideaux de verre"], [1.0, "fleche", "La flèche d'acier"]],
		"matx": {"ciment": 75000.0, "sable": 150000.0, "pierre": 180000.0, "acier": 40000.0, "verre": 9000.0},
		"desc": "Un noyau de béton qui monte d'un étage tous les trois jours, des ascenseurs à 36 km/h et une flèche qu'on voit à 90 km."},
}

## Ordre d'affichage (par année).
const ORDER := ["grande_cathedrale", "basilique_coupole", "grande_mosquee", "pagode_neuf_etages", "palais_cristal",
	"grand_opera", "statue_colossale", "tour_fer", "barrage_poids", "gratte_ciel_art_deco", "tour_television",
	"arche_fraternite", "tour_verre_600"]


static func est_monument(id: String) -> bool:
	return TYPES.has(id)


static func spec(id: String) -> Dictionary:
	return TYPES.get(id, {})


static func entries() -> Dictionary:
	var out := {}
	for id in ORDER:
		var s: Dictionary = TYPES[id]
		var e := {}
		for key in ["name", "region", "annee", "w", "d", "cost", "emplois", "visiteurs", "reseau"]:
			if s.has(key):
				e[key] = s[key]
		e["cat"] = CAT
		e["access"] = ROAD
		e["era"] = "traditionnel" if int(s.annee) < 1830 else ("classique" if int(s.annee) < 1950 else "contemporain")
		e["style"] = ""
		e["role"] = "monument"
		e["monument"] = true
		e["metiers"] = [["gardien_musee", 4], ["guide_conferencier", 3], ["agent_accueil_parc", 2], ["conservateur", 1]]
		var quand := "de tout temps" if int(s.annee) <= 0 else "dès %d" % int(s.annee)
		e["desc"] = "%s (%s ; %s de travaux, %d ouvriers)" % [String(s.desc), quand, ans_texte(float(s.ans)), int(s.equipe)]
		out[id] = e
	return out


static func ans_texte(a: float) -> String:
	if a < 1.0:
		return "%d mois" % roundi(a * 12.0)
	if absf(a - roundf(a)) < 0.05:
		return "%d an%s" % [roundi(a), "s" if roundi(a) > 1 else ""]
	return "%s ans" % String.num(a, 1).replace(".", ",")


## Mois de travail réels d'une équipe complète (Chantiers.mois_batiment).
static func mois(id: String) -> float:
	return float(TYPES[id].ans) * 12.0


static func equipe(id: String) -> int:
	return int(TYPES[id].equipe)


static func etapes(id: String) -> Array:
	return TYPES[id].etapes if TYPES.has(id) else Chantiers.ETAPES_BATIMENT


## Matériaux du chantier (t), un peu moins de bois et de pierre et plus de béton après 1950.
static func materiaux(id: String) -> Dictionary:
	var out := {}
	var m: Dictionary = TYPES[id].get("matx", {})
	for g in m:
		out[String(g)] = float(m[g])
	return out


## Étape « visuelle » d'un chantier de monument pour BatimentsVie : les deux
## premières étapes (terrassement, fondations) et la dernière (finitions) sont
## les mêmes que pour un bâtiment ; entre les deux, le monument monte d'un bout
## à l'autre derrière ses échafaudages ("murs" avec l'avancement u de 0 à 1 sur
## toutes les étapes du milieu).
static func visuel(id: String, av: float) -> Array:
	var et := etapes(id)
	var e := Chantiers.etape(et, av)
	var i := int(e[0])
	if i <= 1:
		return [String(et[i][1]) if i == 0 else "fondations", float(e[3])]
	if i == et.size() - 1:
		return ["finitions", float(e[3])]
	var debut := float(et[1][0])
	var fin := float(et[et.size() - 2][0])
	return ["murs", clampf((av - debut) / maxf(fin - debut, 0.001), 0.0, 1.0)]


# --- Modèles (BlocMesh, façade vers −Z) ---------------------------------------------------

## Tronc de pyramide à base carrée (côtés alignés sur les axes), de s0 à s1 de large.
static func _tronc(k: BlocMesh, cx: float, y0: float, cz: float, s0x: float, s0z: float, s1x: float, s1z: float, h: float, col: Color) -> void:
	var a := [Vector3(cx - s0x / 2.0, y0, cz - s0z / 2.0), Vector3(cx + s0x / 2.0, y0, cz - s0z / 2.0),
		Vector3(cx + s0x / 2.0, y0, cz + s0z / 2.0), Vector3(cx - s0x / 2.0, y0, cz + s0z / 2.0)]
	var b := [Vector3(cx - s1x / 2.0, y0 + h, cz - s1z / 2.0), Vector3(cx + s1x / 2.0, y0 + h, cz - s1z / 2.0),
		Vector3(cx + s1x / 2.0, y0 + h, cz + s1z / 2.0), Vector3(cx - s1x / 2.0, y0 + h, cz + s1z / 2.0)]
	var outs := [Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0)]
	for i in 4:
		var j := (i + 1) % 4
		k.panel(a[i], a[j], b[j], b[i], outs[i] + Vector3(0, 0.2, 0), col.darkened(0.04 * i))
	if s1x > 0.01:
		k.panel(b[0], b[1], b[2], b[3], Vector3.UP, col)


## Flèche gothique : pyramide élancée avec quatre clochetons.
static func _fleche(k: BlocMesh, cx: float, y0: float, cz: float, s: float, h: float, col: Color, pierre: Color) -> void:
	k.box(cx, y0, cz, s, s * 0.5, s, pierre)
	_tronc(k, cx, y0 + s * 0.5, cz, s * 0.9, s * 0.9, 0.0, 0.0, h, col)
	for dx: float in [-1.0, 1.0]:
		for dz: float in [-1.0, 1.0]:
			k.cylinder(cx + dx * s * 0.45, y0 + s * 0.5, cz + dz * s * 0.45, s * 0.1, 0.0, s * 1.2, 4, pierre)


static func build(k: BlocMesh, id: String, t: Dictionary) -> void:
	var w := float(t.w)
	var d := float(t.d)
	match id:
		"grande_cathedrale":
			k.plate(0, 0, w, d, PARVIS)
			var p := PIERRE
			# Nef et bas-côtés.
			k.box(0, 0, 6, 15, 30, 72, p)
			k.gable(0, 30, 6, 15.6, 72, 11, TOIT_CATH, false)
			for s: float in [-1.0, 1.0]:
				k.box(s * 12.5, 0, 6, 10, 15, 72, p.darkened(0.05))
				k.gable(s * 12.5, 15, 6, 10.4, 72, 4, PLOMB, false)
				k.windows_col(s * 17.55, 6, 66, 4, 9, 2.6, 7.5, VITRAIL)
				k.windows_col(s * 7.55, 6, 66, 19, 9, 2.4, 8.5, VITRAIL)
				# Arcs-boutants : contreforts et culées.
				for i in 9:
					var z := -27.0 + i * 8.0
					k.box(s * 18.5, 0, z, 2.0, 18, 1.4, p.darkened(0.1))
					k.box(s * 15.0, 18, z, 5.0, 1.2, 1.0, p.darkened(0.08))
					k.cylinder(s * 18.5, 18, z, 0.7, 0.0, 4.0, 4, p)
			# Transept.
			k.box(0, 0, 22, 44, 30, 14, p)
			k.gable(0, 30, 22, 44.6, 14.6, 10, TOIT_CATH, true)
			for s: float in [-1.0, 1.0]:
				k.box(s * 22.06, 12, 22, 0.12, 9, 9, VITRAIL)
			# Chœur et abside.
			k.box(0, 0, 38, 15, 30, 18, p)
			k.gable(0, 30, 38, 15.6, 18, 11, TOIT_CATH, false)
			k.cylinder(0, 0, 49, 8.6, 8.6, 30, 8, p)
			k.cylinder(0, 30, 49, 9.0, 0.0, 11, 8, TOIT_CATH)
			# Façade et deux tours.
			k.box(0, 0, -34, 16, 36, 8, p.lightened(0.05))
			k.gable(0, 36, -34, 16, 8, 6, p, true)
			k.cylinder(0, 20, -38.1, 4.2, 4.2, 0.2, 12, VITRAIL)
			for s: float in [-1.0, 1.0]:
				k.box(s * 11.5, 0, -36, 11, 64, 12, p.lightened(0.03))
				k.windows_row(s * 11.5, -42.06, 6, 44, 2, 1.6, 12, Color("2b2f3a"))
				_fleche(k, s * 11.5, 64, -36, 9.5, 22, p.darkened(0.04), p)
			for x: float in [-4.0, 0.0, 4.0]:
				k.box(x, 0, -38.1, 3.2, 8, 0.3, Color("4a3a2a"))
			k.windows_row(0, -38.12, 15, 31, 12, 0.8, 3.0, PIERRE_SOMBRE)
			# Flèche de la croisée.
			k.box(0, 30, 22, 6, 8, 6, PLOMB)
			_tronc(k, 0, 38, 22, 5, 5, 0, 0, 54, PLOMB)
		"basilique_coupole":
			k.plate(0, 0, w, d, PARVIS)
			var p := Color("e8dcc0")
			k.box(0, 0, 4, 24, 28, 66, p)
			k.box(0, 0, 4, 62, 28, 24, p)
			k.gable(0, 28, 4, 24.6, 66, 7, Color("b5523b"), false)
			k.gable(0, 28, 4, 62.6, 24.6, 7, Color("b5523b"), true)
			k.windows_row(0, -29.06, 18, 10, 3, 2.6, 7, GLASS_SOMBRE())
			for s: float in [-1.0, 1.0]:
				k.windows_col(s * 31.06, 4, 18, 10, 3, 2.6, 7, GLASS_SOMBRE())
			# Tambour, coupole, lanterne.
			k.cylinder(0, 28, 4, 13, 13, 14, 16, p.lightened(0.04))
			for i in 16:
				var a := TAU * (i + 0.5) / 16.0
				k.box(cos(a) * 13.1, 32, 4 + sin(a) * 13.1, 1.0, 6.0, 1.0, GLASS_SOMBRE())
			k.dome(0, 42, 4, 13.6, 17, PLOMB, 16)
			k.cylinder(0, 58.5, 4, 2.4, 2.4, 5, 8, p)
			k.dome(0, 63.5, 4, 2.6, 2.4, PLOMB, 8)
			k.cylinder(0, 65.8, 4, 0.3, 0.0, 3.5, 4, OR)
			# Portique.
			k.box(0, 0, -33, 30, 1.6, 8, p.darkened(0.08))
			for i in 6:
				k.cylinder(-12.5 + i * 5.0, 1.6, -36, 0.9, 0.8, 16, 8, MARBRE)
			k.box(0, 17.6, -33, 30, 2.4, 8, p)
			k.gable(0, 20, -33, 30, 8, 5, p.lightened(0.05), true)
			for s: float in [-1.0, 1.0]:
				k.box(s * 26, 0, -24, 6, 40, 6, p)
				k.pyramid(s * 26, 40, -24, 6.4, 6.4, 6, Color("b5523b"))
		"grande_mosquee":
			k.plate(0, 0, w, d, SABLE)
			var p := Color("efe6d4")
			# Cour à galeries.
			k.box(0, 0, -30, 84, 9, 4, p)
			for s: float in [-1.0, 1.0]:
				k.box(s * 40, 0, -14, 4, 9, 36, p)
			for i in 9:
				k.dome(-32 + i * 8.0, 9, -30, 2.2, 2.0, PLOMB, 8)
			k.box(0, 0, -30, 8, 13, 4.4, p.lightened(0.04))
			k.box(0, 4, -32.3, 4.4, 6, 0.2, BLEU_FAIENCE)
			k.cylinder(0, 0, -14, 3.2, 3.2, 3, 8, MARBRE)
			k.dome(0, 3, -14, 3.4, 2.4, PLOMB, 8)
			# Salle de prière et coupoles.
			k.box(0, 0, 20, 70, 18, 46, p)
			k.windows_row(0, -3.06, 60, 5, 12, 1.6, 4, BLEU_FAIENCE)
			k.cylinder(0, 18, 20, 15, 15, 7, 16, p.lightened(0.03))
			k.dome(0, 25, 20, 15.5, 15, PLOMB, 16)
			k.cylinder(0, 40, 20, 0.4, 0.0, 5, 4, OR)
			for c: Vector2 in [Vector2(-22, 20), Vector2(22, 20), Vector2(0, 2), Vector2(0, 38)]:
				k.dome(c.x, 18, c.y, 8, 7, PLOMB, 12)
			for c: Vector2 in [Vector2(-28, 6), Vector2(28, 6), Vector2(-28, 34), Vector2(28, 34)]:
				k.dome(c.x, 18, c.y, 4, 3.5, PLOMB, 8)
			# Minarets.
			for s: float in [-1.0, 1.0]:
				var mx := s * 41.0
				k.box(mx, 0, 0, 5, 6, 5, p)
				k.cylinder(mx, 6, 0, 2.3, 2.0, 46, 12, p.lightened(0.05))
				for y: float in [26.0, 40.0]:
					k.cylinder(mx, y, 0, 3.2, 3.2, 1.0, 12, p)
				k.cylinder(mx, 52, 0, 2.2, 0.0, 10, 12, PLOMB)
				k.cylinder(mx, 62, 0, 0.15, 0.0, 2.5, 4, OR)
		"pagode_neuf_etages":
			k.plate(0, 0, w, d, PARVIS)
			k.box(0, 0, 0, 30, 2.4, 30, PIERRE_SOMBRE)
			k.box(0, 0, -16.5, 8, 1.2, 3, PIERRE_SOMBRE)
			var y := 2.4
			for i in 9:
				var s := 16.0 - i * 1.25
				var hh := 5.2 - i * 0.22
				k.box(0, y, 0, s, hh, s, LAQUE if i % 2 == 0 else LAQUE.darkened(0.08))
				k.windows_row(0, -s / 2.0 - 0.06, s * 0.6, y + hh * 0.3, 3, 0.9, hh * 0.45, BOIS_SOMBRE)
				k.hip(0, y + hh, 0, s + 5.0, s + 5.0, 1.8, TUILE_VERTE)
				y += hh + 1.8
			k.cylinder(0, y, 0, 0.5, 0.3, 9, 8, OR)
			for j in 5:
				k.cylinder(0, y + 1.5 + j * 1.4, 0, 1.0 - j * 0.12, 1.0 - j * 0.12, 0.4, 8, OR)
			for s2: float in [-1.0, 1.0]:
				k.box(s2 * 12, 0, -14, 2.4, 3.0, 2.4, PIERRE)
		"palais_cristal":
			k.plate(0, 0, w, d, HERBE)
			k.box(0, 0, 0, 146, 0.8, 52, PIERRE_SOMBRE)
			# Nef de verre et bas-côtés en gradins.
			k.box(0, 0.8, 0, 140, 20, 24, VERRE)
			k.gable(0, 20.8, 0, 140, 24, 5, VERRE_SOMBRE, true)
			for s: float in [-1.0, 1.0]:
				k.box(0, 0.8, s * 18, 136, 12, 12, VERRE)
				k.gable(0, 12.8, s * 18, 136, 12, 2.5, VERRE_SOMBRE, true)
			# Ossature de fonte.
			for i in 24:
				var x := -69.0 + i * 6.0
				k.box(x, 0.8, -24.05, 0.5, 12.4, 0.3, FONTE)
				k.box(x, 0.8, 24.05, 0.5, 12.4, 0.3, FONTE)
				k.box(x, 12.8, -12.05, 0.5, 8.4, 0.3, FONTE)
			# Transept voûté.
			k.box(0, 0.8, 0, 26, 26, 54, VERRE)
			k.lathe(0, 26.8, 0, [Vector2(13, 0), Vector2(11.3, 6.5), Vector2(6.5, 11.3), Vector2(0, 13)], 12, VERRE_SOMBRE)
			for i in 5:
				k.box(-12.0 + i * 6.0, 0.8, -27.1, 0.6, 26.2, 0.3, FONTE)
			k.box(0, 0.8, -27.1, 6, 7, 0.4, FONTE)
			for x: float in [-50.0, 50.0]:
				k.tree(x, -22, 1.4)
		"grand_opera":
			k.plate(0, 0, w, d, PARVIS)
			var p := Color("e9dfc8")
			k.box(0, 0, -46, 60, 2.2, 10, p.darkened(0.08))
			# Façade : arcades, loggia à colonnes, attique.
			k.box(0, 2.2, -40, 60, 12, 12, p)
			for i in 7:
				k.box(-24.0 + i * 8.0, 2.2, -46.06, 4.2, 8, 0.2, Color("3a2e26"))
			k.box(0, 14.2, -40, 60, 14, 12, p.lightened(0.03))
			for i in 16:
				k.cylinder(-28.0 + i * 3.73, 14.2, -46.3, 0.55, 0.5, 12, 8, MARBRE)
			k.windows_row(0, -46.08, 52, 17, 7, 3.0, 7, VERRE_SOMBRE)
			k.box(0, 28.2, -40, 60, 4, 12, p)
			for s: float in [-1.0, 1.0]:
				k.box(s * 26, 28.2, -40, 8, 6, 12, p)
				k.box(s * 26, 34.2, -45.5, 4, 4, 1.4, OR) # groupes de statues dorées
			# Salle et coupole de cuivre.
			k.box(0, 0, -10, 52, 30, 48, p.darkened(0.03))
			k.cylinder(0, 30, -10, 16, 16, 4, 16, p)
			k.dome(0, 34, -10, 16.4, 9, CUIVRE, 16)
			k.cylinder(0, 43, -10, 1.6, 0.0, 4, 8, OR)
			# Cage de scène et fronton.
			k.box(0, 0, 26, 56, 46, 30, p.darkened(0.05))
			k.gable(0, 46, 26, 56.6, 30, 9, CUIVRE, true)
			k.box(0, 54, 11, 4, 4, 1.4, OR)
			# Administration à l'arrière.
			k.box(0, 0, 48, 60, 20, 14, p)
			k.hip(0, 20, 48, 60.6, 14.6, 4, CUIVRE.darkened(0.1))
			for s: float in [-1.0, 1.0]:
				k.box(s * 32, 0, -6, 8, 18, 22, p)
				k.dome(s * 32, 18, -6, 4.6, 5, CUIVRE, 10)
		"tour_fer":
			k.plate(0, 0, w, d, HERBE)
			var f := FER
			# Quatre piles inclinées (troncs posés en gradins), réunies par de grands arcs.
			for sx: float in [-1.0, 1.0]:
				for sz: float in [-1.0, 1.0]:
					k.box(sx * 40, 0, sz * 40, 16, 2.5, 16, PIERRE_SOMBRE)
					for j in 4:
						var y0 := 2.5 + j * 13.0
						var o := 40.0 - j * 6.0
						_tronc(k, sx * o, y0, sz * o, 11.0 - j * 0.8, 11.0 - j * 0.8, 10.0 - j * 0.8, 10.0 - j * 0.8, 13.0, f)
			for i in 4:
				var arc := [Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0)][i] as Vector3
				var cx := arc.x * 28.0
				var cz := arc.z * 28.0
				if absf(arc.x) > 0.5:
					k.box(cx, 30, cz, 3.0, 8.0, 50.0, f.darkened(0.1))
				else:
					k.box(cx, 30, cz, 50.0, 8.0, 3.0, f.darkened(0.1))
			# Premier étage.
			k.box(0, 54.5, 0, 66, 5, 66, f.darkened(0.12))
			k.box(0, 59.5, 0, 66.6, 1.2, 66.6, f)
			# Fût jusqu'au second étage.
			_tronc(k, 0, 60.7, 0, 40, 40, 20, 20, 52, f)
			k.box(0, 112.7, 0, 26, 4, 26, f.darkened(0.12))
			# Haut de la tour.
			_tronc(k, 0, 116.7, 0, 18, 18, 7, 7, 100, f)
			_tronc(k, 0, 216.7, 0, 7, 7, 5, 5, 8, f.darkened(0.1))
			k.box(0, 224.7, 0, 6.4, 4.5, 6.4, Color("f0d77a"))
			k.cylinder(0, 229.2, 0, 0.6, 0.2, 11, 6, f)
		"statue_colossale":
			k.plate(0, 0, w, d, HERBE)
			# Fort en étoile, puis socle de granit.
			k.box(0, 0, 0, 50, 6, 50, PIERRE_SOMBRE)
			k.box(0, 6, 0, 30, 4, 30, PIERRE)
			_tronc(k, 0, 10, 0, 22, 22, 16, 16, 32, PIERRE.lightened(0.05))
			k.box(0, 42, 0, 18, 3, 18, PIERRE)
			# Le Génie : robe, buste, tête, bras levé et étoile dorée.
			var c := CUIVRE
			k.cylinder(0, 45, 0, 6.4, 4.2, 22, 10, c)
			k.cylinder(0, 67, 0, 4.2, 3.4, 9, 10, c.lightened(0.04))
			k.cylinder(0, 76, 0, 1.6, 1.6, 2, 8, c)
			k.dome(0, 78, 0, 2.8, 3.4, c, 10)
			k.lathe(0, 78, 0, [Vector2(2.8, 0), Vector2(2.6, -1.4), Vector2(0, -1.6)], 10, c)
			k.box(3.6, 70, 0, 1.8, 16, 1.8, c)
			k.box(3.6, 86, 0, 2.4, 2.4, 2.4, c.darkened(0.05))
			for i in 5:
				var a := TAU * i / 5.0
				k.box(3.6 + cos(a) * 1.6, 90.0 + sin(a) * 1.6, 0, 1.2, 1.2, 0.6, OR)
			k.box(3.6, 89.0, 0, 2.0, 2.0, 0.8, OR)
			k.box(-3.8, 58, -1.0, 1.4, 10, 1.4, c.darkened(0.05)) # bras baissé tenant un livre
			k.box(-4.0, 57, -2.0, 2.4, 3, 0.8, c.darkened(0.12))
		"barrage_poids":
			k.plate(0, 0, w, d, Color("8f9a7a"))
			# Mur poids en gradins (parement aval incliné), couronnement et route.
			for j in 6:
				k.box(0, j * 8.0, 6.0 + j * 2.4, 220, 8.0, 34.0 - j * 4.8, BETON.darkened(0.02 * j))
			k.box(0, 48, 18, 222, 4, 8, BETON_CLAIR)
			for i in 23:
				k.box(-99.0 + i * 9.0, 52, 14.2, 0.4, 1.0, 0.3, ACIER)
			# Retenue (côté amont).
			k.box(0, 0, 22.5, 220, 44, 3, EAU)
			# Évacuateur de crues et vannes.
			for i in 4:
				k.box(-18.0 + i * 12.0, 30, -6.0, 8, 18, 4, BETON_CLAIR)
				k.box(-18.0 + i * 12.0, 40, -8.2, 7, 6, 0.4, ACIER)
			k.box(0, 0, -16, 52, 2, 14, EAU.lightened(0.15))
			# Usine au pied du barrage.
			k.box(70, 0, -14, 44, 14, 18, Color("d8c9a8"))
			k.gable(70, 14, -14, 44.4, 18.4, 3, Color("7a4f3a"), true)
			k.windows_row(70, -23.06, 40, 4, 8, 2.2, 6.5, VERRE_SOMBRE)
			for i in 4:
				k.cylinder(52.0 + i * 12.0, 14, -4, 1.6, 1.6, 40, 8, ACIER.darkened(0.15)) # conduites forcées
		"gratte_ciel_art_deco":
			k.plate(0, 0, w, d, PARVIS)
			var p := Color("d9d0bd")
			var y := 0.0
			var etages := [[52.0, 30.0], [44.0, 90.0], [36.0, 110.0], [26.0, 60.0], [18.0, 24.0]]
			for e: Array in etages:
				var s := float(e[0])
				var hh := float(e[1])
				k.box(0, y, 0, s, hh, s, p)
				var n := int(s / 4.0)
				for i in n:
					var x := -s / 2.0 + (i + 0.5) * (s / n)
					k.box(x, y + 2.0, -s / 2.0 - 0.06, 1.1, hh - 3.0, 0.12, VERRE_SOMBRE)
					k.box(x, y + 2.0, s / 2.0 + 0.06, 1.1, hh - 3.0, 0.12, VERRE_SOMBRE)
					k.box(-s / 2.0 - 0.06, y + 2.0, x, 0.12, hh - 3.0, 1.1, VERRE_SOMBRE)
					k.box(s / 2.0 + 0.06, y + 2.0, x, 0.12, hh - 3.0, 1.1, VERRE_SOMBRE)
				y += hh
			# Couronne d'acier en gradins et flèche.
			for j in 4:
				_tronc(k, 0, y + j * 6.0, 0, 16.0 - j * 3.6, 16.0 - j * 3.6, 13.0 - j * 3.4, 13.0 - j * 3.4, 6.0, ACIER.lightened(0.1))
			k.cylinder(0, y + 24.0, 0, 0.8, 0.1, 40, 6, ACIER)
			k.box(0, 0, -26.4, 10, 9, 1.0, Color("3a3226"))
		"tour_television":
			k.plate(0, 0, w, d, HERBE)
			k.cylinder(0, 0, 0, 16, 16, 9, 12, BETON_CLAIR)
			k.cylinder(0, 9, 0, 7.5, 4.6, 190, 12, BETON)
			# Sphère panoramique.
			k.lathe(0, 199, 0, [Vector2(0, -14), Vector2(7, -12), Vector2(12.1, -7), Vector2(14, 0), Vector2(12.1, 7),
				Vector2(7, 12), Vector2(0, 14)], 16, ACIER.lightened(0.1))
			k.cylinder(0, 197, 0, 14.4, 14.4, 2.6, 16, VERRE_SOMBRE)
			k.cylinder(0, 213, 0, 2.6, 2.0, 22, 8, BETON)
			k.cylinder(0, 235, 0, 1.2, 0.3, 32, 6, Color("c0392b"))
		"arche_fraternite":
			k.plate(0, 0, w, d, PARVIS)
			k.box(0, 0, 0, 110, 3, 96, Color("c9c3b8"))
			var m := MARBRE
			var top := 100.0
			for s: float in [-1.0, 1.0]:
				k.box(s * 45.5, 3, 0, 19, top - 3.0, 92, m)
				k.window_bands(s * 45.5, 0, 19, 92, 6, 30, 3.0, Color("6d8796"))
			k.box(0, top - 18.0, 0, 110, 18, 92, m)
			k.box(0, 3, 0, 72, 4, 92, m.darkened(0.04))
			k.box(0, 7, 0, 72, 0.6, 8, VERRE)
			# Le Nuage (toile tendue) et les ascenseurs panoramiques.
			k.box(0, 24, 0, 54, 1.6, 40, Color(0.96, 0.97, 0.98))
			for x: float in [-14.0, 14.0]:
				k.box(x, 7, -10, 2.4, top - 25.0, 2.4, VERRE_SOMBRE)
			# Escalier du parvis.
			for j in 6:
				k.box(0, 0, -48.5 + j * 0.8, 80, 0.5 * (j + 1), 1.0, Color("d4cfc4"))
		"tour_verre_600":
			k.plate(0, 0, w, d, PARVIS)
			k.box(0, 0, 0, 74, 8, 74, BETON_CLAIR)
			var y := 8.0
			var secs := [[60.0, 50.0, 150.0], [50.0, 36.0, 150.0], [36.0, 22.0, 140.0], [22.0, 9.0, 90.0]]
			for s: Array in secs:
				_tronc(k, 0, y, 0, float(s[0]), float(s[0]), float(s[1]), float(s[1]), float(s[2]), VERRE_SOMBRE)
				k.box(0, y + float(s[2]) - 2.0, 0, float(s[1]) + 1.0, 2.0, float(s[1]) + 1.0, ACIER)
				y += float(s[2])
			k.cylinder(0, y, 0, 3.0, 0.4, 62, 8, ACIER.lightened(0.15))
			for s2: float in [-1.0, 1.0]:
				k.box(s2 * 30, 0, -34, 10, 12, 6, VERRE)


static func GLASS_SOMBRE() -> Color:
	return VERRE_SOMBRE
