class_name EpoquesBatiments
extends RefCounted
## Bâtiments du XIXe siècle (1800-1900) pour les parties historiques : fermes,
## moulins, forge, relais de poste, gares et dépôts du chemin de fer, halles,
## lavoirs, kiosques, manufactures, et maisons d'époque de plusieurs régions du
## monde (longère, maison de canuts, échoppe bordelaise, maisons victoriennes,
## tulou hakka, compartiments chinois, bungalow, cases obus…).
##
## Chaque modèle est fabriqué en code (BlocMesh, aucun fichier 3D). Chaque fiche
## a une année d'apparition réaliste ("annee", lue par Epoques) et, si elle joue
## le rôle d'un bâtiment existant, sa "base" : la ferme à cour carrée produit
## comme une ferme céréalière, le moulin à vent comme le moulin à farine, le
## relais de poste loge les voyageurs comme un hôtel… Les réglages de jeu de la
## base (production, réseau, tourisme, métiers) sont recopiés.
##
## Champ "zone" (R, C ou I) : le bâtiment pousse aussi dans le zonage des
## parties historiques, dans sa région (ZoneSystem.types_d_epoque).

const RP := ["route", "chemin"]
const ROAD := ["route"]

const GLASS := BuildingCatalog.GLASS
const PORTE := Color("5a3a22")
const BOIS := Color("8b5a2b")
const BOIS_SOMBRE := Color("5c3d24")
const ARDOISE := Color("4f5560")
const TUILE := Color("b5523b")
const TUILE_CANAL := Color("c46a3b")
const CHAUME := Color("b39a5e")
const PIERRE := Color("c9c1ae")
const GRANIT := Color("a7a299")
const CALCAIRE := Color("e6dcc4")
const BRIQUE := Color("a64b35")
const ENDUIT := Color("efe4cc")
const FONTE := Color("2f3e46")
const VERT_FONTE := Color("2d4a3e")
const HERBE := Color("6aa84f")
const TERRE := Color("b08a5a")
const PAVES := Color("8e8a82")
const EAU := Color("4f86a8")
const BLANC := Color("f4f0e6")

## id -> fiche. Champs du catalogue (name, cat, w, d, access, logements, emplois,
## visiteurs, cost, desc) plus "annee", "region", "base" et "zone".
const TYPES := {
	# --- Campagne d'Europe ---------------------------------------------------------------------
	"longere": {"name": "Longère bretonne", "cat": "logement", "region": "europe", "annee": 1800, "w": 20, "d": 12,
		"access": RP, "logements": 1, "cost": 220_000, "zone": "R",
		"desc": "Une seule rangée de pièces sous un long toit d'ardoise, granite et cheminées aux deux pignons. Les vaches dorment au bout."},
	"ferme_picarde": {"name": "Ferme picarde à cour carrée", "cat": "production", "region": "europe", "annee": 1800, "w": 44, "d": 40,
		"access": RP, "base": "ferme_cereales", "cost": 1_100_000,
		"desc": "Logis, granges, étables et porche charretier fermés autour de la cour, pigeonnier au coin : la grande ferme à blé de Beauce et de Picardie."},
	"ferme_comtoise": {"name": "Ferme comtoise", "cat": "production", "region": "europe", "annee": 1800, "w": 26, "d": 24,
		"access": RP, "base": "ferme_laitiere", "cost": 950_000,
		"desc": "Un immense toit qui descend presque au sol, le tuyé où sèchent les jambons, et l'étable sous le même toit pour le comté."},
	"moulin_tour": {"name": "Moulin-tour en pierre", "cat": "production", "region": "europe", "annee": 1800, "w": 16, "d": 16,
		"access": RP, "base": "moulin", "cost": 700_000,
		"desc": "Tour de pierre, calotte tournante et quatre ailes entoilées. Le meunier oriente le moulin face au vent."},
	"moulin_aubes": {"name": "Moulin à roue à aubes", "cat": "production", "region": "europe", "annee": 1800, "w": 22, "d": 18,
		"access": RP, "base": "moulin", "cost": 800_000,
		"desc": "La roue à aubes tourne dans le bief et fait tourner les meules : farine, huile ou foulon selon la saison."},
	"forge_marechal": {"name": "Forge du maréchal-ferrant", "cat": "industrie", "region": "europe", "annee": 1800, "w": 14, "d": 12,
		"access": RP, "base": "atelier", "emplois": 3, "cost": 180_000, "fumee": true, "zone": "I",
		"desc": "Le foyer, le soufflet, l'enclume et le travail à ferrer : on y ferre les chevaux, on y cercle les roues."},
	"relais_poste": {"name": "Relais de poste et auberge", "cat": "tourisme", "region": "europe", "annee": 1800, "w": 32, "d": 26,
		"access": ROAD, "base": "hotel_2", "emplois": 8, "cost": 900_000,
		"desc": "Tous les quatre lieues, des chevaux frais pour la diligence, une table et des lits pour les voyageurs. Le postillon boit un coup en attendant."},
	"lavoir": {"name": "Lavoir couvert", "cat": "espaces", "region": "europe", "annee": 1851, "w": 14, "d": 10,
		"access": RP, "visiteurs": 30, "cost": 60_000,
		"desc": "Bassin d'eau courante sous un toit sur poteaux : les lavandières battent le linge et toutes les nouvelles du village."},
	"maison_maitre": {"name": "Maison de maître", "cat": "logement", "region": "europe", "annee": 1820, "w": 18, "d": 16,
		"access": RP, "logements": 1, "cost": 520_000, "zone": "R",
		"desc": "Façade symétrique en pierre de taille, toit à quatre pans d'ardoise, grille et allée de tilleuls : la maison du notaire ou du maître de forges."},
	"maison_canuts": {"name": "Immeuble de canuts", "cat": "logement", "region": "europe", "annee": 1825, "w": 16, "d": 14,
		"access": RP, "logements": 8, "emplois": 8, "cost": 1_200_000, "zone": "R",
		"desc": "Plafonds de quatre mètres et hautes fenêtres pour les métiers à tisser Jacquard : on vit et on tisse la soie au même étage."},
	"echoppe_bordelaise": {"name": "Échoppe bordelaise", "cat": "logement", "region": "europe", "annee": 1850, "w": 8, "d": 18,
		"access": RP, "logements": 1, "cost": 240_000, "zone": "R",
		"desc": "Maison basse en pierre blonde, corniche sculptée et couloir central jusqu'au jardin de derrière."},
	"rangee_victorienne": {"name": "Maisons victoriennes en bande", "cat": "logement", "region": "europe", "annee": 1840, "w": 26, "d": 12,
		"access": ROAD, "logements": 4, "cost": 1_000_000, "zone": "R",
		"desc": "Briques, bow-windows et marches blanches : quatre maisons étroites et identiques, comme dans les faubourgs de Londres."},
	"halle_fonte": {"name": "Halle en fonte et verre", "cat": "commerce", "region": "europe", "annee": 1853, "w": 42, "d": 30,
		"access": ROAD, "emplois": 40, "visiteurs": 1500, "cost": 3_200_000, "zone": "C",
		"desc": "Colonnes de fonte, verrières et persiennes : le marché couvert à la manière de Baltard. Les maraîchers arrivent avant l'aube."},
	"kiosque_fonte": {"name": "Kiosque à musique", "cat": "loisirs", "region": "europe", "annee": 1860, "w": 12, "d": 12,
		"access": RP, "base": "kiosque_musique", "visiteurs": 150, "cost": 90_000,
		"desc": "Fonte ajourée et toit en pagode : la fanfare municipale joue le dimanche après la messe."},
	"bureau_poste": {"name": "Bureau de poste et télégraphe", "cat": "services", "region": "europe", "annee": 1850, "w": 16, "d": 12,
		"access": ROAD, "emplois": 6, "visiteurs": 120, "cost": 350_000,
		"desc": "Les lettres, les mandats et le télégraphe électrique : une dépêche arrive à Paris en quelques minutes."},
	"manufacture_vapeur": {"name": "Manufacture à vapeur", "cat": "production", "region": "europe", "annee": 1820, "w": 46, "d": 32,
		"access": ROAD, "base": "usine_textile", "cost": 3_800_000, "fumee": true,
		"desc": "Ateliers en briques à toits en dents de scie, salle des machines et haute cheminée : la machine à vapeur entraîne cent métiers par des courroies."},
	"puits_mine": {"name": "Puits de mine et chevalement", "cat": "production", "region": "europe", "annee": 1840, "w": 28, "d": 24,
		"access": ROAD, "base": "mine", "cost": 3_000_000, "fumee": true,
		"desc": "Le chevalement et ses molettes au-dessus du puits, la machine d'extraction et le terril : la cage descend les mineurs à 300 mètres."},
	"usine_gaz": {"name": "Usine à gaz et gazomètre", "cat": "reseaux", "region": "europe", "annee": 1820, "w": 40, "d": 30,
		"access": ROAD, "base": "poste_gaz", "cost": 2_800_000, "fumee": true,
		"desc": "On distille la houille dans les fours, le gaz attend sous la cloche du gazomètre et part éclairer les réverbères."},
	"phare_granit": {"name": "Phare de granit", "cat": "espaces", "region": "monde", "annee": 1800, "w": 12, "d": 12,
		"access": RP, "emplois": 2, "visiteurs": 20, "cost": 900_000,
		"desc": "La tour, la lanterne et la maison du gardien : la lentille de Fresnel (1823) porte la lumière à trente kilomètres."},
	# --- Chemin de fer ---------------------------------------------------------------------------
	"embarcadere": {"name": "Embarcadère (première gare)", "cat": "services", "region": "europe", "annee": 1840, "w": 30, "d": 14,
		"access": ROAD, "emplois": 4, "visiteurs": 150, "cost": 600_000,
		"desc": "Bâtiment des voyageurs en pierre, horloge, lampisterie et petite halle : à poser au bord d'une gare (menu L)."},
	"halle_marchandises": {"name": "Halle à marchandises", "cat": "industrie", "region": "europe", "annee": 1840, "w": 32, "d": 16,
		"access": ROAD, "base": "entrepot", "emplois": 10, "cost": 700_000, "zone": "I",
		"desc": "Quai haut, portes coulissantes et grue à bras : les colis et les tonneaux passent du wagon à la charrette."},
	"rotonde_locos": {"name": "Rotonde à locomotives", "cat": "industrie", "region": "europe", "annee": 1850, "w": 56, "d": 52,
		"access": ROAD, "base": "atelier", "emplois": 40, "cost": 2_400_000, "fumee": true,
		"desc": "Le pont tournant au centre, une stalle par locomotive : on les graisse, on vide les cendres, on rallume les feux à quatre heures du matin."},
	"chateau_eau_gare": {"name": "Château d'eau de gare", "cat": "reseaux", "region": "europe", "annee": 1850, "w": 12, "d": 12,
		"access": RP, "base": "chateau_eau", "cost": 400_000,
		"desc": "Réservoir sur une tour de briques et grue hydraulique : les locomotives à vapeur boivent des milliers de litres à chaque arrêt."},
	"maison_garde_barriere": {"name": "Maison de garde-barrière", "cat": "logement", "region": "europe", "annee": 1850, "w": 10, "d": 10,
		"access": RP, "logements": 1, "emplois": 1, "cost": 150_000,
		"desc": "La garde-barrière ferme le passage à niveau à la main quand la cloche annonce le train."},
	# --- Reste du monde ----------------------------------------------------------------------------
	"tulou_hakka": {"name": "Tulou hakka", "cat": "logement", "region": "asie_est", "annee": 1800, "w": 42, "d": 42,
		"access": RP, "logements": 60, "cost": 3_000_000, "zone": "R",
		"desc": "Une forteresse ronde de terre damée où vit tout un clan : quatre étages de galeries de bois autour du temple des ancêtres (Fujian)."},
	"kura": {"name": "Kura, entrepôt de marchand", "cat": "industrie", "region": "asie_est", "annee": 1800, "w": 10, "d": 8,
		"access": RP, "base": "entrepot", "emplois": 2, "cost": 160_000, "zone": "I",
		"desc": "Murs épais de terre enduite à la chaux, soubassement noir en namako : le riz et les trésors à l'abri du feu (Japon)."},
	"compartiments_chinois": {"name": "Compartiments chinois", "cat": "commerce", "region": "asie_sud", "annee": 1840, "w": 24, "d": 16,
		"access": ROAD, "logements": 4, "emplois": 12, "visiteurs": 300, "cost": 900_000, "zone": "C",
		"desc": "Boutique en bas, logement en haut, galerie couverte de cinq pieds devant : les shophouses colorées de Singapour et Penang."},
	"bungalow_colonial": {"name": "Bungalow à véranda", "cat": "logement", "region": "asie_sud", "annee": 1830, "w": 22, "d": 20,
		"access": RP, "logements": 1, "cost": 420_000, "zone": "R",
		"desc": "Plain-pied surélevé, véranda tout autour et grand toit pour la mousson (Inde)."},
	"maison_victorienne_us": {"name": "Maison victorienne à tourelle", "cat": "logement", "region": "ameriques", "annee": 1870, "w": 12, "d": 16,
		"access": RP, "logements": 1, "cost": 380_000, "zone": "R",
		"desc": "Bardeaux peints de trois couleurs, tourelle, porche et dentelle de bois : une « painted lady » de San Francisco."},
	"cabane_rondins": {"name": "Cabane en rondins", "cat": "logement", "region": "ameriques", "annee": 1800, "w": 10, "d": 9,
		"access": RP, "logements": 1, "cost": 40_000, "zone": "R",
		"desc": "Troncs entaillés aux angles, cheminée de pierre et un banc sous l'auvent : la première maison des pionniers."},
	"grange_ronde": {"name": "Grange ronde", "cat": "production", "region": "ameriques", "annee": 1826, "w": 26, "d": 26,
		"access": RP, "base": "elevage", "cost": 850_000,
		"desc": "Les vaches en cercle autour du fenil central, un seul homme les nourrit toutes : l'idée des Shakers du Massachusetts."},
	"maison_coloniale_afrique": {"name": "Maison de traite à balcons", "cat": "logement", "region": "afrique", "annee": 1850, "w": 16, "d": 12,
		"access": RP, "logements": 2, "emplois": 2, "cost": 450_000, "zone": "R",
		"desc": "Comptoir au rez-de-chaussée, balcons de bois et persiennes à l'étage : les maisons des négociants de Saint-Louis du Sénégal."},
	"cases_obus": {"name": "Cases obus", "cat": "logement", "region": "afrique", "annee": 1800, "w": 16, "d": 16,
		"access": RP, "logements": 2, "cost": 60_000, "zone": "R",
		"desc": "Coupoles de terre en forme d'obus, nervures en relief pour grimper et entretenir : l'habitat mousgoum du Cameroun."},
	"hammam": {"name": "Hammam", "cat": "loisirs", "region": "moyen_orient", "annee": 1800, "w": 20, "d": 16,
		"access": RP, "emplois": 6, "visiteurs": 200, "cost": 600_000,
		"desc": "Salle froide, tiède et chaude sous des coupoles percées d'étoiles de verre : on s'y lave, on s'y parle, on y passe l'après-midi."},
}

## Ordre d'affichage dans le panneau Construire.
const ORDER := ["longere", "maison_maitre", "maison_canuts", "echoppe_bordelaise", "rangee_victorienne", "maison_garde_barriere",
	"tulou_hakka", "bungalow_colonial", "maison_victorienne_us", "cabane_rondins", "maison_coloniale_afrique", "cases_obus",
	"halle_fonte", "compartiments_chinois", "forge_marechal", "halle_marchandises", "rotonde_locos", "kura",
	"ferme_picarde", "ferme_comtoise", "grange_ronde", "moulin_tour", "moulin_aubes", "manufacture_vapeur", "puits_mine",
	"usine_gaz", "chateau_eau_gare", "embarcadere", "bureau_poste", "relais_poste", "lavoir", "kiosque_fonte", "hammam", "phare_granit"]

## Champs propres à la fiche d'époque, jamais repris de la base.
const PROPRES := ["name", "desc", "w", "d", "cost", "annee", "region", "era", "style", "arch", "zone", "base", "cache"]


## Fiches du catalogue. `deja` : types déjà connus (pour recopier ceux des bases).
static func entries(deja: Dictionary = {}) -> Dictionary:
	var out := {}
	for id in ORDER:
		var spec: Dictionary = TYPES[id]
		var e := {}
		var base := String(spec.get("base", ""))
		if base != "" and deja.has(base):
			for key in deja[base]:
				if not PROPRES.has(key):
					e[key] = (deja[base][key] as Variant)
					if e[key] is Dictionary or e[key] is Array:
						e[key] = e[key].duplicate(true)
		e.merge(spec, true)
		e["era"] = "classique" if int(spec.annee) >= 1830 else "traditionnel"
		e["style"] = ""
		e["epoque_bat"] = true
		e["desc"] = "%s (dès %d)" % [String(spec.desc), int(spec.annee)]
		if not e.has("cat"):
			e["cat"] = "logement"
		out[id] = e
	return out


## Types d'époque qui poussent dans une zone (R, C, I) : id -> poids, de la
## région donnée (sinon de toutes les régions), déjà inventés à l'année y.
static func pour_zone(k: String, region: String, y: int) -> Dictionary:
	var out := {}
	for pass_i in 2:
		for id in ORDER:
			var t: Dictionary = TYPES[id]
			if String(t.get("zone", "")) != k or int(t.annee) > y:
				continue
			if pass_i == 0 and String(t.region) != region and String(t.region) != "monde":
				continue
			var lg := int(t.get("logements", 0))
			out[id] = 4 if lg <= 2 else 2
		if not out.is_empty():
			return out
	return out


# --- Petits outils -----------------------------------------------------------------------------

## Poutre ou poteau entre deux points (section carrée th).
static func _poutre(k: BlocMesh, a: Vector3, b: Vector3, th: float, col: Color) -> void:
	var dir := b - a
	if dir.length() < 0.001:
		return
	var f := dir.normalized()
	var up := Vector3.UP if absf(f.y) < 0.95 else Vector3.RIGHT
	var r := f.cross(up).normalized() * th * 0.5
	var u := r.cross(f).normalized() * th * 0.5
	var c := [a - r - u, a + r - u, a + r + u, a - r + u]
	var e := [b - r - u, b + r - u, b + r + u, b - r + u]
	for i in 4:
		var j := (i + 1) % 4
		var mid: Vector3 = (c[i] + c[j]) * 0.5 - a
		k.panel(c[i], c[j], e[j], e[i], mid, col)


## Fenêtres d'une façade −Z (front) ou +Z (dos) avec volets.
static func _fenetres(k: BlocMesh, cx: float, z: float, width: float, y: float, n: int, fw: float, fh: float,
		volets := Color(0, 0, 0, 0)) -> void:
	k.windows_row(cx, z, width, y, n, fw, fh, GLASS)
	if volets.a > 0.0 and n > 0:
		var step := width / n
		for i in n:
			var x := cx - width / 2.0 + step * (i + 0.5)
			for s in [-1.0, 1.0]:
				k.box(x + s * (fw * 0.5 + fw * 0.25), y, z, fw * 0.45, fh, 0.14, volets)


## Fenêtres d'une façade ±X.
static func _fenetres_cote(k: BlocMesh, x: float, cz: float, depth: float, y: float, n: int, fw: float, fh: float) -> void:
	k.windows_col(x, cz, depth, y, n, fw, fh, GLASS)


static func _cheminee(k: BlocMesh, x: float, y: float, z: float, sx: float, sz: float, h: float, col: Color, fumee := false) -> void:
	k.box(x, y, z, sx, h, sz, col)
	k.box(x, y + h, z, sx + 0.15, 0.2, sz + 0.15, col.darkened(0.15))
	if fumee:
		k.anchor("fumee", Vector3(x, y + h + 0.3, z))


## Anneau de murs (tulou, rotonde) : n panneaux entre les rayons r0 et r1.
static func _anneau(k: BlocMesh, cx: float, cz: float, r0: float, r1: float, y0: float, h: float, n: int, col: Color,
		a0 := 0.0, a1 := TAU) -> void:
	for i in n:
		var t0 := a0 + (a1 - a0) * i / n
		var t1 := a0 + (a1 - a0) * (i + 1) / n
		var o0 := Vector3(cx + cos(t0) * r1, 0, cz + sin(t0) * r1)
		var o1 := Vector3(cx + cos(t1) * r1, 0, cz + sin(t1) * r1)
		var i0 := Vector3(cx + cos(t0) * r0, 0, cz + sin(t0) * r0)
		var i1 := Vector3(cx + cos(t1) * r0, 0, cz + sin(t1) * r0)
		var up := Vector3(0, h, 0)
		var by := Vector3(0, y0, 0)
		var om := (o0 + o1) * 0.5 - Vector3(cx, 0, cz)
		k.panel(o0 + by, o1 + by, o1 + by + up, o0 + by + up, om, col)
		k.panel(i0 + by, i1 + by, i1 + by + up, i0 + by + up, -om, col.darkened(0.1))
		k.panel(o0 + by + up, o1 + by + up, i1 + by + up, i0 + by + up, Vector3.UP, col.lightened(0.05))


## Toit en anneau incliné vers l'extérieur et l'intérieur (tulou, rotonde).
static func _toit_anneau(k: BlocMesh, cx: float, cz: float, r0: float, r1: float, y0: float, h: float, n: int, col: Color,
		a0 := 0.0, a1 := TAU) -> void:
	var rm := (r0 + r1) * 0.5
	for i in n:
		var t0 := a0 + (a1 - a0) * i / n
		var t1 := a0 + (a1 - a0) * (i + 1) / n
		var p := func(t: float, r: float, y: float) -> Vector3: return Vector3(cx + cos(t) * r, y, cz + sin(t) * r)
		var om := Vector3(cos((t0 + t1) * 0.5), 0, sin((t0 + t1) * 0.5))
		k.panel(p.call(t0, r1, y0), p.call(t1, r1, y0), p.call(t1, rm, y0 + h), p.call(t0, rm, y0 + h), om + Vector3.UP, col)
		k.panel(p.call(t0, r0, y0), p.call(t1, r0, y0), p.call(t1, rm, y0 + h), p.call(t0, rm, y0 + h), -om + Vector3.UP, col.darkened(0.08))


## Roue verticale dans le plan YZ (molettes du chevalement).
static func _roue(k: BlocMesh, c: Vector3, r: float, col: Color) -> void:
	var n := 10
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		_poutre(k, c + Vector3(0, sin(a0), cos(a0)) * r, c + Vector3(0, sin(a1), cos(a1)) * r, 0.18, col)
		if i % 2 == 0:
			_poutre(k, c, c + Vector3(0, sin(a0), cos(a0)) * r, 0.1, col)


## Couleur selon la variante (deux bâtiments voisins ne sont pas identiques).
static func _v(k: BlocMesh, couleurs: Array) -> Color:
	return couleurs[k.variant % couleurs.size()]


# --- Modèles -------------------------------------------------------------------------------------

## Modèle low-poly d'un bâtiment d'époque (repère BlocMesh : façade vers −Z).
static func build(k: BlocMesh, id: String, t: Dictionary) -> void:
	var w := float(t.w)
	var d := float(t.d)
	match id:
		"longere":
			k.plate(0, 0, w, d, HERBE)
			var mur := _v(k, [GRANIT, Color("b3ada3"), Color("9e988f")])
			k.box(0, 0, 0.5, 16.0, 3.0, 6.5, mur)
			k.gable(0, 3.0, 0.5, 17.0, 7.6, 3.6, ARDOISE)
			for s in [-1.0, 1.0]:
				_cheminee(k, s * 7.6, 4.5, 0.5, 1.0, 1.3, 2.8, mur)
			# Appentis de l'étable au bout.
			k.box(-7.0 - 0.0, 0, 4.4, 4.0, 2.2, 1.6, mur.darkened(0.08))
			k.box(0, 0, -2.8, 1.1, 2.1, 0.12, PORTE)
			k.box(5.0, 0, -2.8, 2.2, 2.0, 0.12, BOIS_SOMBRE)
			_fenetres(k, -3.0, -2.8, 6.0, 1.0, 2, 0.9, 1.1, Color("3a6b8c"))
			k.windows_row(0, -2.8, 8.0, 4.4, 2, 0.8, 0.8, GLASS) # lucarnes
			for x in [-2.0, 2.0]:
				k.gable(x, 4.0, -2.6, 1.4, 1.2, 0.9, ARDOISE, false)
			k.box(0, 0, -4.4, w, 0.6, 0.3, GRANIT.darkened(0.2))
			k.tree(8.0, -4.0, 1.1)
			k.box(-8.0, 0, -4.0, 1.6, 1.0, 1.0, Color("c9a46a")) # tas de fagots
		"maison_maitre":
			k.plate(0, 0, w, d, HERBE)
			var pierre := _v(k, [CALCAIRE, Color("ece2cc"), Color("ddd2b8")])
			k.box(0, 0, 1.5, 14.0, 9.0, 10.0, pierre)
			k.box(0, 0, 1.5, 14.3, 0.8, 10.3, pierre.darkened(0.12))
			k.box(0, 3.2, 1.5, 14.2, 0.25, 10.2, pierre.lightened(0.05))
			k.box(0, 6.2, 1.5, 14.2, 0.25, 10.2, pierre.lightened(0.05))
			k.hip(0, 9.0, 1.5, 14.8, 10.8, 4.2, ARDOISE)
			for s in [-1.0, 1.0]:
				_cheminee(k, s * 4.0, 11.0, 1.5, 0.9, 1.6, 3.0, pierre)
			_fenetres(k, 0, -3.5, 12.0, 1.2, 5, 1.0, 1.9, Color("e9e2d4"))
			_fenetres(k, 0, -3.5, 12.0, 4.2, 5, 1.0, 1.7, Color("e9e2d4"))
			_fenetres(k, 0, -3.5, 12.0, 7.0, 5, 1.0, 1.3, Color("e9e2d4"))
			k.box(0, 0, -3.6, 1.6, 2.8, 0.16, PORTE)
			k.box(0, 0, -4.5, 4.0, 0.5, 1.6, pierre.darkened(0.1)) # perron
			k.box(0, 2.9, -3.7, 2.4, 0.3, 0.4, pierre.lightened(0.08))
			# Grille et allée.
			k.box(0, 0.08, -6.5, 2.6, 0.03, 4.0, Color("d8c8a0"))
			for x in range(-8, 9, 1):
				if absi(x) > 1:
					k.box(float(x), 0, -7.7, 0.08, 1.6, 0.08, FONTE)
			k.box(-4.6, 1.4, -7.7, 7.0, 0.08, 0.08, FONTE)
			k.box(4.6, 1.4, -7.7, 7.0, 0.08, 0.08, FONTE)
			for s in [-1.0, 1.0]:
				k.box(s * 1.5, 0, -7.7, 0.5, 2.2, 0.5, pierre)
				k.tree(s * 6.5, -5.0, 1.2, Color("5a8f3e"))
		"maison_canuts":
			var enduit := _v(k, [Color("e9c9a0"), Color("efd8b4"), Color("e3b98a"), Color("f0dcc0")])
			var etages := 5
			var hh := 4.0
			k.box(0, 0, 0, w, etages * hh, d, enduit)
			for e in etages:
				var y := e * hh + 1.0
				_fenetres(k, 0, -d / 2.0, w - 2.0, y, 4, 1.2, 2.6, Color(0, 0, 0, 0))
				_fenetres(k, 0, d / 2.0, w - 2.0, y, 4, 1.2, 2.6, Color(0, 0, 0, 0))
				k.box(0, e * hh, -d / 2.0 - 0.05, w, 0.2, 0.12, enduit.darkened(0.12))
			k.box(0, etages * hh, 0, w + 0.6, 0.4, d + 0.6, enduit.darkened(0.15))
			k.hip(0, etages * hh + 0.4, 0, w + 0.8, d + 0.8, 2.4, TUILE_CANAL)
			k.box(0, 0, -d / 2.0 - 0.05, 2.0, 3.0, 0.14, PORTE)
			for x in [-5.0, 0.0, 5.0]:
				_cheminee(k, x, etages * hh + 1.4, 2.0, 0.7, 0.9, 1.8, enduit.darkened(0.1))
		"echoppe_bordelaise":
			var blond := _v(k, [Color("e8d6a8"), Color("efdfb6"), Color("dccb9c")])
			k.plate(0, 3.0, w, d - 6.0, HERBE)
			k.box(0, 0, -4.0, w, 4.4, 10.0, blond)
			k.box(0, 4.4, -4.0, w + 0.2, 0.7, 10.2, blond.lightened(0.06)) # corniche
			k.box(0, 5.1, -4.0, w - 0.4, 0.5, 9.6, TUILE_CANAL)
			k.box(0, 0, -9.05, 1.3, 2.9, 0.12, PORTE)
			_fenetres(k, -2.5, -9.05, 2.6, 0.9, 1, 1.2, 2.4)
			_fenetres(k, 2.5, -9.05, 2.6, 0.9, 1, 1.2, 2.4)
			for x in [-2.5, 0.0, 2.5]:
				k.box(x, 3.6, -9.1, 1.6, 0.5, 0.15, blond.lightened(0.1)) # mascarons
			k.box(0, 0, 1.2, w - 1.0, 3.2, 1.0, blond.darkened(0.06)) # chai
			k.tree(1.5, 6.0, 0.9)
		"rangee_victorienne":
			var brique := _v(k, [BRIQUE, Color("8c3b2a"), Color("b5583d"), Color("6e2f22")])
			var n := 4
			var lw := w / n
			for i in n:
				var x := -w / 2.0 + lw * (i + 0.5)
				var c := brique if i % 2 == 0 else brique.darkened(0.06)
				k.box(x, 0, 0.8, lw - 0.1, 8.0, 9.0, c)
				# Bow-window sur deux niveaux.
				k.box(x - lw * 0.18, 0.6, -3.9, 2.6, 5.4, 0.8, BLANC)
				_fenetres(k, x - lw * 0.18, -4.35, 2.2, 1.0, 2, 0.8, 1.7)
				_fenetres(k, x - lw * 0.18, -4.35, 2.2, 3.8, 2, 0.8, 1.5)
				k.box(x - lw * 0.18, 6.0, -3.9, 2.8, 0.3, 1.0, BLANC)
				k.box(x + lw * 0.28, 0.5, -3.75, 1.1, 2.4, 0.12, [Color("1d3557"), Color("6b2737"), Color("2d4a3e"), Color("1b1b1b")][i % 4])
				k.box(x + lw * 0.28, 0, -4.3, 1.6, 0.5, 1.2, BLANC) # marches
				_fenetres(k, x + lw * 0.1, -3.75, 3.0, 6.3, 2, 0.8, 1.2)
				_cheminee(k, x + lw * 0.45, 9.8, 0.8, 0.6, 1.4, 1.8, c.darkened(0.1))
			k.gable(0, 8.0, 0.8, w + 0.2, 9.6, 2.0, ARDOISE)
			for x in range(-12, 13, 1):
				k.box(float(x), 0, -5.6, 0.06, 1.0, 0.06, Color("1b1b1b"))
		"maison_garde_barriere":
			k.plate(0, 0, w, d, HERBE)
			var mur := _v(k, [Color("efe4cc"), Color("f2e3c6")])
			k.box(0, 0, 0.5, 6.5, 5.4, 6.0, mur)
			for y in [0.0, 5.3]:
				k.box(0, y, 0.5, 6.7, 0.12, 6.2, BRIQUE)
			for s in [-1.0, 1.0]:
				k.box(s * 3.3, 0, 0.5, 0.25, 5.4, 6.2, BRIQUE)
			k.gable(0, 5.4, 0.5, 7.2, 6.8, 2.2, TUILE)
			k.box(0, 0, -2.55, 1.0, 2.1, 0.12, PORTE)
			_fenetres(k, 0, -2.55, 5.0, 3.2, 2, 0.8, 1.2, Color("8a1c1c"))
			k.box(0, 0.6, -2.6, 1.0, 0.25, 0.25, Color("c9a227")) # numéro du passage
			k.box(4.0, 0, -3.5, 0.15, 2.6, 0.15, FONTE) # cloche
			k.box(4.0, 2.6, -3.5, 0.4, 0.4, 0.4, Color("c9a227"))
			k.box(-3.0, 0.9, -4.2, 4.0, 0.12, 0.12, Color("c1121f")) # barrière
			k.box(-1.0, 0.9, -4.2, 0.8, 0.12, 0.12, BLANC)
		"tulou_hakka":
			k.plate(0, 0, w, d, TERRE)
			var terre := _v(k, [Color("c9a27e"), Color("b9906a"), Color("d2b08a")])
			var r := 20.0
			_anneau(k, 0, 0, r - 7.0, r, 0, 13.0, 28, terre)
			_toit_anneau(k, 0, 0, r - 7.6, r + 1.2, 13.0, 2.4, 28, Color("4a4e55"))
			# Fenêtres étroites en haut seulement (défense).
			for i in 28:
				var a := TAU * (i + 0.5) / 28.0
				for y in [8.0, 10.6]:
					k.box(cos(a) * (r + 0.02), y, sin(a) * (r + 0.02), 0.5, 0.9, 0.5, GLASS)
			# Galeries de bois intérieures.
			for y in [3.2, 6.4, 9.6]:
				_anneau(k, 0, 0, r - 8.2, r - 7.0, y, 0.25, 28, BOIS)
			# Porte et temple des ancêtres au centre.
			k.box(0, 0, -r - 0.1, 3.0, 4.0, 1.2, PIERRE)
			k.box(0, 0, -r - 0.7, 2.0, 3.0, 0.12, PORTE)
			k.box(0, 0, 3.0, 7.0, 4.0, 5.0, Color("b8322a"))
			k.gable(0, 4.0, 3.0, 8.0, 6.0, 1.8, Color("3f4a52"))
			k.plate(0, -2.0, 6.0, 4.0, PAVES, 0.0, 0.1)
		"kura":
			k.plate(0, 0, w, d, PAVES)
			k.box(0, 0, 0, 7.5, 1.6, 5.5, Color("2f3338")) # namako
			for x in range(-3, 4, 1):
				k.box(float(x), 0.2, -2.8, 0.06, 1.2, 0.04, BLANC)
			k.box(0, 1.6, 0, 7.5, 4.4, 5.5, Color("f4f0e6"))
			k.box(0, 6.0, 0, 8.0, 0.5, 6.0, Color("f4f0e6"))
			k.gable(0, 6.5, 0, 9.0, 7.0, 2.4, Color("3a3f45"))
			k.box(0, 0, -2.8, 1.6, 2.4, 0.2, Color("1b1b1b"))
			k.box(2.0, 4.0, -2.8, 0.9, 0.9, 0.2, Color("1b1b1b"))
			k.box(0, 6.5, -3.4, 1.8, 0.8, 0.8, Color("f4f0e6")) # mon du marchand
		"compartiments_chinois":
			var couleurs := [Color("f2c14e"), Color("7fb8a4"), Color("f4a3b4"), Color("9cc5e6"), Color("e9a46a")]
			var n := 4
			var lw := w / n
			for i in n:
				var x := -w / 2.0 + lw * (i + 0.5)
				var c: Color = couleurs[(i + k.variant) % couleurs.size()]
				k.box(x, 0, 1.0, lw - 0.1, 8.0, 12.0, c)
				# Galerie de cinq pieds : arcades au rez-de-chaussée.
				k.box(x, 3.6, -5.8, lw - 0.1, 4.4, 1.6, c)
				for s in [-1.0, 1.0]:
					k.box(x + s * (lw / 2.0 - 0.3), 0, -6.3, 0.5, 3.6, 0.5, BLANC)
				_fenetres(k, x, -6.65, lw - 1.6, 4.6, 2, 0.9, 1.9, Color("2a6f5f"))
				k.box(x, 0.2, -4.95, lw - 1.8, 2.6, 0.12, Color("6b2737")) # devanture
				k.box(x, 3.0, -4.95, lw - 2.0, 0.5, 0.14, Color("1b1b1b")) # enseigne
				k.box(x, 3.05, -5.0, lw - 2.4, 0.35, 0.05, Color("d9a520"))
			k.gable(0, 8.0, -0.4, w + 0.3, 14.8, 2.6, TUILE_CANAL)
		"bungalow_colonial":
			k.plate(0, 0, w, d, HERBE)
			var mur := _v(k, [BLANC, Color("f2e6d0"), Color("e9d8b6")])
			k.box(0, 0, 0, 18.0, 1.0, 16.0, Color("b5583d"))
			k.box(0, 1.0, 0, 12.0, 4.0, 10.0, mur)
			for x in range(-8, 9, 2):
				for z in [-7.5, 7.5]:
					k.box(float(x), 1.0, z, 0.3, 3.6, 0.3, BLANC)
			for z in range(-6, 7, 2):
				for x in [-8.5, 8.5]:
					k.box(x, 1.0, float(z), 0.3, 3.6, 0.3, BLANC)
			k.hip(0, 4.6, 0, 19.0, 17.0, 4.0, Color("8a5a36"))
			k.box(0, 1.0, -5.05, 1.6, 2.6, 0.12, PORTE)
			_fenetres(k, 0, -5.05, 10.0, 1.8, 4, 1.1, 2.0, Color("2d6a4f"))
			k.box(0, 0, -8.6, 4.0, 1.0, 1.6, Color("b5583d"))
			k.tree(-9.0, -8.5, 1.2, Color("3f7d3a"))
			k.tree(9.0, 8.5, 1.4, Color("3f7d3a"))
		"maison_victorienne_us":
			k.plate(0, 0, w, d, HERBE)
			var c1 := _v(k, [Color("c9d6df"), Color("f4a3b4"), Color("e9c46a"), Color("a8c8a0")])
			var c2 := _v(k, [Color("6b2737"), Color("1d3557"), Color("2d4a3e"), Color("8c3b2a")])
			k.box(-0.8, 0, 1.5, 9.0, 7.6, 10.0, c1)
			k.gable(-0.8, 7.6, 1.5, 9.6, 10.6, 4.4, Color("4f5560"), false)
			# Tourelle d'angle.
			k.cylinder(3.6, 0, -2.6, 1.8, 1.8, 9.0, 8, c1.darkened(0.05))
			k.cylinder(3.6, 9.0, -2.6, 2.1, 0.0, 4.2, 8, Color("4f5560"))
			k.windows_row(3.6, -4.45, 2.0, 1.4, 1, 0.9, 1.8, GLASS)
			k.windows_row(3.6, -4.45, 2.0, 5.0, 1, 0.9, 1.6, GLASS)
			# Porche à colonnettes.
			k.box(-1.5, 0, -4.4, 7.6, 0.8, 2.6, c2)
			k.box(-1.5, 3.3, -4.4, 7.8, 0.25, 2.8, c2)
			for x in [-5.0, -3.0, -1.0, 1.0]:
				k.box(x, 0.8, -5.5, 0.22, 2.5, 0.22, BLANC)
			k.box(-1.5, 0.8, -3.45, 1.1, 2.3, 0.12, c2.darkened(0.2))
			_fenetres(k, -3.8, -3.45, 2.5, 1.4, 1, 1.0, 1.9)
			_fenetres(k, -0.8, -3.45, 7.0, 4.6, 2, 0.9, 1.7)
			k.box(-0.8, 6.2, -3.6, 9.2, 0.3, 0.2, c2) # frise
			k.box(-0.8, 8.6, -3.5, 1.0, 1.4, 0.12, GLASS)
			_cheminee(k, -3.5, 8.8, 3.0, 0.8, 0.8, 3.8, BRIQUE)
			k.box(0, 0, -7.5, w, 0.9, 0.12, BLANC)
		"cabane_rondins":
			k.plate(0, 0, w, d, Color("7aa35a"))
			var rondin := _v(k, [Color("8a6a48"), Color("7a5a3a"), Color("9b7653")])
			for i in 8:
				var y := i * 0.32
				var c := rondin if i % 2 == 0 else rondin.darkened(0.12)
				k.box(0, y, -2.4, 7.4, 0.32, 0.36, c)
				k.box(0, y, 2.4, 7.4, 0.32, 0.36, c)
				k.box(-3.5, y + 0.16, 0, 0.36, 0.32, 5.4, c)
				k.box(3.5, y + 0.16, 0, 0.36, 0.32, 5.4, c)
			k.box(0, 0, 0, 6.6, 2.6, 4.4, rondin.darkened(0.25))
			k.gable(0, 2.6, 0, 8.0, 6.0, 1.8, Color("6b4a33"))
			k.box(0, 0, -2.6, 1.0, 2.0, 0.12, BOIS_SOMBRE)
			k.box(2.0, 1.0, -2.6, 0.8, 0.7, 0.12, GLASS)
			_cheminee(k, -3.9, 0, 0, 1.0, 1.4, 5.2, Color("8e8a82"), true)
			k.box(0, 2.0, -3.4, 7.4, 0.12, 1.8, Color("6b4a33")) # auvent
			for x in [-3.4, 3.4]:
				k.box(x, 0, -4.2, 0.2, 2.0, 0.2, rondin)
			k.box(1.8, 0, -3.8, 1.6, 0.45, 0.4, rondin) # banc
			k.box(-4.2, 0, -3.5, 1.2, 0.8, 0.8, Color("a07850")) # bois coupé
		"maison_coloniale_afrique":
			var ocre := _v(k, [Color("e3b98a"), Color("d9a46c"), Color("f0d8b0"), Color("c98d5a")])
			k.box(0, 0, 0.6, 14.0, 7.6, 9.0, ocre)
			k.box(0, 7.6, 0.6, 14.4, 0.4, 9.4, ocre.lightened(0.1))
			k.hip(0, 8.0, 0.6, 14.6, 9.6, 2.4, Color("8e8a82"))
			# Comptoir en bas, balcon de bois à l'étage.
			for x in [-4.5, -1.5, 1.5, 4.5]:
				k.box(x, 0, -3.95, 1.6, 2.8, 0.12, Color("5a3a22"))
			k.box(0, 3.6, -4.7, 14.0, 0.25, 1.6, BOIS)
			for x in range(-7, 8, 1):
				k.box(float(x), 3.85, -5.45, 0.08, 1.0, 0.08, BOIS_SOMBRE)
			k.box(0, 4.8, -5.45, 14.0, 0.1, 0.1, BOIS_SOMBRE)
			for x in [-4.5, -1.5, 1.5, 4.5]:
				k.box(x, 3.85, -3.95, 1.3, 2.4, 0.12, Color("2d6a4f")) # persiennes
			for x in [-6.8, 6.8]:
				k.box(x, 0, -5.4, 0.25, 3.6, 0.25, BOIS)
		"cases_obus":
			k.plate(0, 0, w, d, Color("c9a46a"))
			var terre := _v(k, [Color("b07a4a"), Color("a86e40"), Color("c08a58")])
			var pos := [Vector3(-3.5, 0, -2.5), Vector3(3.5, 0, -2.0), Vector3(0, 0, 3.5), Vector3(-5.0, 0, 4.0)]
			var tailles := [1.0, 0.85, 1.15, 0.6]
			for i in pos.size():
				var p: Vector3 = pos[i]
				var s := float(tailles[i])
				k.lathe(p.x, 0, p.z, [Vector2(2.6 * s, 0), Vector2(2.55 * s, 2.0 * s), Vector2(2.2 * s, 4.2 * s),
					Vector2(1.4 * s, 6.2 * s), Vector2(0.5 * s, 7.4 * s), Vector2(0, 7.8 * s)], 10, terre)
				# Nervures en V.
				for j in 6:
					var a := TAU * j / 6.0
					for e in 4:
						var y := (0.8 + e * 1.5) * s
						var rr := (2.62 - e * 0.32) * s * (1.0 if e < 2 else 0.85)
						k.box(p.x + cos(a) * rr, y, p.z + sin(a) * rr, 0.35, 0.3, 0.35, terre.darkened(0.15))
				k.box(p.x, 0, p.z - 2.6 * s, 0.9 * s, 1.5 * s, 0.3, Color("3d2b1f"))
			# Mur d'enceinte bas, ouvert devant.
			_anneau(k, 0, 0, 7.1, 7.6, 0, 1.2, 18, terre.darkened(0.08), -PI / 2.0 + 0.35, 3.0 * PI / 2.0 - 0.35)
		"hammam":
			k.plate(0, 0, w, d, PAVES)
			var chaux := _v(k, [Color("e6d3b0"), Color("e3cfa8"), Color("dcc8a0")])
			k.box(0, 0, 0, 18.0, 4.5, 14.0, chaux)
			k.box(0, 4.5, 0, 18.3, 0.3, 14.3, chaux.darkened(0.08))
			for p in [Vector2(-5.0, 1.0), Vector2(0.0, 1.0), Vector2(5.0, 1.0)]:
				k.box(p.x, 4.8, p.y, 4.4, 0.8, 4.4, chaux.darkened(0.06))
				k.dome(p.x, 5.6, p.y, 2.2, 2.0, chaux.darkened(0.16))
				for j in 5:
					var a := TAU * j / 5.0
					k.box(p.x + cos(a) * 1.1, 6.9, p.y + sin(a) * 1.1, 0.25, 0.15, 0.25, Color("8fb8d8"))
			k.box(0, 0, -7.05, 2.4, 3.2, 0.2, Color("1f6f5f"))
			k.box(0, 3.2, -7.1, 3.0, 0.6, 0.25, Color("2a9d8f"))
			_cheminee(k, 8.0, 4.8, 5.0, 1.0, 1.0, 2.4, chaux.darkened(0.15), true)
		"ferme_picarde":
			k.plate(0, 0, w, d, Color("c2a878"))
			var mur := _v(k, [Color("d9cdb4"), Color("e2d4b6"), Color("cfc1a4")])
			# Logis au fond.
			k.box(0, 0, 14.0, 22.0, 6.0, 9.0, mur)
			k.gable(0, 6.0, 14.0, 22.8, 9.8, 3.6, TUILE)
			_fenetres(k, 0, 9.45, 18.0, 1.0, 5, 0.9, 1.3, Color("6b4a33"))
			_fenetres(k, 0, 9.45, 18.0, 3.8, 5, 0.9, 1.1, Color("6b4a33"))
			k.box(0, 0, 9.45, 1.1, 2.2, 0.12, PORTE)
			_cheminee(k, -7.0, 8.0, 14.0, 0.8, 1.2, 2.6, mur, true)
			# Granges sur les côtés.
			for s in [-1.0, 1.0]:
				k.box(s * 17.5, 0, 0, 8.0, 7.5, 26.0, mur.darkened(0.04))
				k.gable(s * 17.5, 7.5, 0, 8.8, 26.6, 4.4, TUILE.darkened(0.05), false)
				k.box(s * 13.45, 0, -2.0, 0.12, 4.5, 4.0, BOIS_SOMBRE)
				k.box(s * 13.45, 0, 7.0, 0.12, 2.4, 1.4, BOIS_SOMBRE)
			# Bâtiment d'entrée avec le porche charretier.
			k.box(-8.5, 0, -15.0, 10.0, 5.0, 7.0, mur)
			k.box(8.5, 0, -15.0, 10.0, 5.0, 7.0, mur)
			k.box(0, 4.4, -15.0, 7.0, 1.6, 7.0, mur)
			k.gable(0, 5.0, -15.0, 28.0, 7.8, 3.2, TUILE)
			k.box(0, 0, -18.55, 4.6, 4.3, 0.12, BOIS)
			# Pigeonnier rond au coin.
			k.cylinder(-18.0, 0, -16.5, 2.8, 2.8, 9.0, 10, mur.lightened(0.04))
			k.cylinder(-18.0, 9.0, -16.5, 3.2, 0.0, 3.2, 10, TUILE)
			for j in 6:
				var a := TAU * j / 6.0
				k.box(-18.0 + cos(a) * 2.85, 7.0, -16.5 + sin(a) * 2.85, 0.4, 0.3, 0.4, Color("1b1b1b"))
			# Cour : fumier, mare, charrette.
			k.box(-4.0, 0.05, 2.0, 5.0, 0.8, 4.0, Color("6b4a33"))
			k.plate(5.0, -2.0, 5.0, 3.6, EAU, 0.05, 0.06)
			k.box(2.0, 0.05, -7.0, 1.8, 0.9, 3.4, BOIS)
			for s in [-1.0, 1.0]:
				k.box(2.0 + s * 1.0, 0.0, -7.0, 0.15, 1.4, 1.4, BOIS_SOMBRE)
			k.box(8.0, 0, 6.0, 3.0, 2.4, 3.0, Color("e9c46a")) # meule de paille
			k.pyramid(8.0, 2.4, 6.0, 3.2, 3.2, 1.4, Color("d9b44a"))
		"ferme_comtoise":
			k.plate(0, 0, w, d, HERBE)
			var mur := _v(k, [Color("ece2cc"), Color("e6dcc4"), Color("f2e8d2")])
			k.box(0, 0, 0, 18.0, 4.0, 16.0, mur)
			k.box(0, 0, 0, 18.2, 0.8, 16.2, GRANIT)
			k.hip(0, 4.0, 0, 22.0, 20.0, 8.5, Color("7a3b2a"))
			k.box(0, 0, -8.05, 4.0, 3.6, 0.15, BOIS) # porte de grange
			k.box(0, 2.2, -8.6, 4.4, 0.3, 1.0, BOIS) # pont de grange
			_fenetres(k, 5.5, -8.05, 5.0, 1.2, 2, 0.8, 1.0, Color("2d4a3e"))
			_fenetres(k, -5.5, -8.05, 5.0, 1.2, 2, 0.8, 1.0, Color("2d4a3e"))
			# Le tuyé : grande cheminée pyramidale au milieu du toit.
			k.box(0, 9.5, 2.0, 2.6, 2.4, 2.6, Color("8e8a82"))
			k.pyramid(0, 11.9, 2.0, 3.0, 3.0, 1.4, Color("6b6f75"))
			k.anchor("fumee", Vector3(0, 13.5, 2.0))
			k.plate(-7.0, -10.0, 6.0, 3.0, Color("c2a878"), 0.0, 0.05)
			k.box(-9.0, 0, -10.0, 2.0, 1.2, 1.0, BOIS) # bassin de bois
			k.tree(9.0, -9.0, 1.3, Color("2f5d3a"))
		"grange_ronde":
			k.plate(0, 0, w, d, HERBE)
			var rouge := _v(k, [Color("9b2c2c"), Color("b03a2e"), Color("8c3b2a")])
			k.cylinder(0, 0, 0, 10.5, 10.5, 1.2, 16, PIERRE)
			k.cylinder(0, 1.2, 0, 10.2, 10.2, 7.8, 16, rouge)
			k.cylinder(0, 9.0, 0, 11.0, 3.0, 4.5, 16, Color("4f5560"))
			k.cylinder(0, 13.5, 0, 3.0, 3.0, 2.2, 8, BLANC) # lanterneau
			k.cylinder(0, 15.7, 0, 3.4, 0.0, 1.6, 8, Color("4f5560"))
			k.box(0, 0, -10.3, 3.6, 4.0, 0.4, BLANC)
			k.box(0, 0, -10.45, 3.0, 3.6, 0.2, rouge.darkened(0.2))
			for j in 12:
				var a := TAU * (j + 0.5) / 12.0
				k.box(cos(a) * 10.25, 4.2, sin(a) * 10.25, 0.7, 0.9, 0.7, BLANC)
			k.box(0, 0, -12.0, 3.6, 0.2, 2.8, PIERRE) # rampe
		"moulin_tour":
			k.plate(0, 0, w, d, HERBE)
			var pierre := _v(k, [Color("d4ccb8"), Color("c9c1ae"), Color("e0d6c0")])
			k.cylinder(0, 0, 0, 3.6, 2.8, 10.0, 12, pierre)
			k.cylinder(0, 10.0, 0, 3.2, 0.0, 3.2, 12, Color("5c3d24")) # calotte
			k.box(0, 0, -3.55, 1.0, 2.0, 0.15, PORTE)
			k.box(0, 5.0, -3.15, 0.7, 0.8, 0.15, GLASS)
			# Arbre moteur et quatre ailes face au vent (vers −Z).
			var c := Vector3(0, 10.6, -3.6)
			k.box(0, 10.3, -3.3, 0.5, 0.5, 1.4, BOIS_SOMBRE)
			for i in 4:
				var a := PI / 4.0 + i * PI / 2.0
				var dirv := Vector3(cos(a), sin(a), 0)
				var bout := c + dirv * 8.5
				_poutre(k, c, bout, 0.25, BOIS_SOMBRE)
				# Toile : un panneau le long de l'aile.
				var lat := Vector3(-dirv.y, dirv.x, 0) * 1.4
				k.panel(c + dirv * 1.5, bout, bout + lat, c + dirv * 1.5 + lat, Vector3(0, 0, -1), Color("efe6d0"))
			k.box(0, 0, 5.0, 0.3, 0.3, 4.0, BOIS) # queue pour orienter
		"moulin_aubes":
			k.plate(0, 0, w, d, HERBE)
			k.plate(8.0, 0, 5.0, d, EAU, 0.02, 0.06) # bief
			var pierre := _v(k, [Color("c9c1ae"), Color("b8b09c"), Color("d4ccb8")])
			k.box(-1.5, 0, 0, 12.0, 7.0, 10.0, pierre)
			k.gable(-1.5, 7.0, 0, 12.8, 10.8, 3.6, TUILE)
			k.box(-1.5, 0, -5.05, 1.2, 2.3, 0.12, PORTE)
			_fenetres(k, -1.5, -5.05, 9.0, 3.8, 3, 0.9, 1.1, Color("6b4a33"))
			k.box(-1.5, 4.0, -5.4, 2.0, 1.0, 0.8, BOIS) # palan à sacs
			# Roue à aubes contre le pignon est, dans le bief.
			var cx := 6.4
			var cy := 3.4
			var r := 3.0
			k.box(cx, cy - 0.2, 0, 2.0, 0.4, 0.4, BOIS_SOMBRE) # arbre de la roue
			for side in [-0.55, 0.55]:
				for i in 16:
					var a0 := TAU * i / 16.0
					var a1 := TAU * (i + 1) / 16.0
					_poutre(k, Vector3(cx + side, cy + sin(a0) * r, cos(a0) * r), Vector3(cx + side, cy + sin(a1) * r, cos(a1) * r), 0.22, BOIS_SOMBRE)
					if i % 2 == 0:
						_poutre(k, Vector3(cx + side, cy, 0), Vector3(cx + side, cy + sin(a0) * r, cos(a0) * r), 0.14, BOIS_SOMBRE)
			for i in 16:
				var a := TAU * (i + 0.5) / 16.0
				k.box(cx, cy + sin(a) * r - 0.3, cos(a) * r, 1.3, 0.6, 0.12, BOIS)
			k.box(cx, 0, 0, 1.8, 0.5, 8.0, EAU.darkened(0.2))
			k.box(8.0, 0, -7.0, 5.2, 1.2, 0.4, pierre) # vanne
			k.box(8.0, 0, -7.0, 0.3, 2.2, 0.6, BOIS_SOMBRE)
		"forge_marechal":
			k.plate(0, 0, w, d, PAVES)
			var pierre := _v(k, [Color("b8b09c"), Color("a7a299"), Color("c9c1ae")])
			k.box(0, 0, 2.0, 10.0, 4.0, 6.0, pierre)
			k.gable(0, 4.0, 2.0, 10.8, 6.8, 2.4, TUILE.darkened(0.1))
			# Appentis ouvert devant : le travail à ferrer.
			k.box(0, 3.0, -2.6, 10.0, 0.2, 3.4, TUILE.darkened(0.2))
			for x in [-4.8, 4.8]:
				k.box(x, 0, -4.1, 0.3, 3.0, 0.3, BOIS)
			k.box(0, 0, -0.95, 3.0, 2.6, 0.12, Color("1b1b1b")) # gueule de la forge
			k.box(-1.5, 0, -2.5, 0.8, 0.8, 0.5, Color("3d3d3d")) # enclume sur billot
			k.box(-1.5, 0.8, -2.5, 1.0, 0.3, 0.35, Color("5a5a5a"))
			k.box(1.8, 0, -2.8, 2.0, 2.0, 0.2, BOIS_SOMBRE) # travail
			_cheminee(k, 3.2, 3.0, 3.0, 1.2, 1.2, 4.2, Color("8e8a82"), true)
			k.box(-4.0, 0, -4.8, 0.8, 1.6, 0.8, Color("8e8a82")) # tas de fers
			k.box(4.0, 0, -5.2, 1.6, 0.9, 0.8, Color("5c3d24"))
		"relais_poste":
			k.plate(0, 0, w, d, PAVES)
			var mur := _v(k, [Color("e8dcc2"), Color("efe4cc"), Color("e2d4b6")])
			# Auberge sur la rue.
			k.box(-4.0, 0, -8.0, 22.0, 7.0, 9.0, mur)
			k.gable(-4.0, 7.0, -8.0, 22.8, 9.8, 3.8, ARDOISE)
			_fenetres(k, -4.0, -12.55, 20.0, 1.0, 6, 1.0, 1.6, Color("2d4a3e"))
			_fenetres(k, -4.0, -12.55, 20.0, 4.2, 6, 1.0, 1.4, Color("2d4a3e"))
			k.box(-4.0, 0, -12.6, 1.6, 2.6, 0.14, PORTE)
			k.box(-4.0, 3.0, -12.9, 4.0, 0.7, 0.15, Color("1d3557")) # enseigne « Poste aux chevaux »
			k.box(-4.0, 3.15, -12.95, 3.4, 0.4, 0.05, Color("e9c46a"))
			for x in [-11.0, 3.0]:
				_cheminee(k, x, 9.0, -8.0, 0.8, 1.4, 2.6, mur, true)
			# Porche vers la cour et écuries au fond.
			k.box(11.5, 0, -8.0, 9.0, 6.0, 9.0, mur.darkened(0.04))
			k.box(11.5, 0, -12.55, 4.0, 4.0, 0.12, BOIS)
			k.gable(11.5, 6.0, -8.0, 9.6, 9.6, 3.0, ARDOISE)
			k.box(0, 0, 8.0, 30.0, 4.5, 9.0, mur.darkened(0.08))
			k.gable(0, 4.5, 8.0, 30.6, 9.6, 3.0, TUILE)
			for i in 6:
				k.box(-12.5 + i * 5.0, 0, 3.45, 1.6, 2.4, 0.12, BOIS_SOMBRE)
			k.box(-5.0, 0, 1.0, 2.0, 0.9, 1.2, Color("7a5230")) # abreuvoir
			k.plate(-5.0, 1.0, 1.7, 0.9, EAU, 0.85, 0.05)
			k.box(6.0, 0, 0.0, 1.0, 1.0, 4.0, Color("c9a46a")) # foin
		"embarcadere":
			k.plate(0, 0, w, d, Color("b9b6ae"))
			var pierre := _v(k, [CALCAIRE, Color("efe4cc"), Color("d9cdb4")])
			# Corps central à étage (logement du chef de gare) et deux ailes basses.
			k.box(0, 0, 0, 10.0, 8.0, 9.0, pierre)
			k.hip(0, 8.0, 0, 10.6, 9.6, 2.6, ARDOISE)
			for s in [-1.0, 1.0]:
				k.box(s * 9.0, 0, 0, 8.0, 4.8, 8.0, pierre)
				k.hip(s * 9.0, 4.8, 0, 8.6, 8.6, 2.0, ARDOISE)
				_fenetres(k, s * 9.0, -4.05, 6.0, 1.0, 2, 1.1, 2.2)
				for x in [s * 6.0, s * 12.5]:
					k.box(x, 0, -4.05, 0.4, 4.8, 0.2, BRIQUE)
			k.box(0, 0, -4.55, 1.6, 2.8, 0.14, PORTE)
			_fenetres(k, 0, -4.55, 8.0, 1.0, 2, 1.1, 2.2)
			_fenetres(k, 0, -4.55, 8.0, 4.8, 3, 1.0, 1.6, Color("e9e2d4"))
			# Horloge et nom de la gare.
			k.box(0, 6.6, -4.65, 1.2, 1.2, 0.15, BLANC)
			k.box(0, 6.6, -4.72, 0.12, 0.5, 0.05, Color("1b1b1b"))
			k.box(0, 3.4, -4.62, 5.0, 0.6, 0.1, Color("1d3557"))
			# Marquise sur le quai (côté +Z, vers les voies).
			k.box(0, 0, 6.0, w, 0.5, 3.0, Color("9a958a"))
			for x in range(-12, 13, 4):
				k.box(float(x), 0.5, 6.8, 0.2, 3.4, 0.2, FONTE)
			k.box(0, 3.9, 6.0, w - 4.0, 0.15, 3.2, FONTE)
			k.box(0, 3.6, 7.5, w - 4.0, 0.3, 0.08, Color("e9e2d4")) # lambrequin
			k.box(12.5, 0.5, 5.2, 0.6, 1.0, 0.6, Color("b5583d")) # lampisterie
			k.box(-12.0, 0.5, 6.5, 1.0, 1.2, 0.8, BOIS) # bagages
			k.anchor("fumee", Vector3(3.0, 11.0, 0))
			_cheminee(k, 3.0, 8.6, 0, 0.6, 0.8, 1.8, pierre)
		"halle_marchandises":
			k.plate(0, 0, w, d, Color("b9b6ae"))
			var mur := _v(k, [Color("8a6a48"), Color("7a5a3a"), BRIQUE])
			k.box(0, 0, 0, 28.0, 1.2, 12.0, PIERRE) # quai haut
			k.box(0, 1.2, 0, 26.0, 4.8, 9.0, mur)
			k.gable(0, 6.0, 0, 28.0, 14.0, 2.4, ARDOISE)
			for i in 4:
				var x := -9.0 + i * 6.0
				k.box(x, 1.2, -4.55, 3.2, 3.4, 0.12, mur.darkened(0.25))
				k.box(x, 1.2, 4.55, 3.2, 3.4, 0.12, mur.darkened(0.25))
			k.box(0, 4.8, -4.6, 6.0, 0.6, 0.1, BLANC)
			# Grue à bras sur le quai.
			k.box(12.0, 1.2, -5.0, 0.4, 4.5, 0.4, FONTE)
			_poutre(k, Vector3(12.0, 5.5, -5.0), Vector3(14.5, 5.0, -7.0), 0.2, FONTE)
			k.box(14.5, 2.4, -7.0, 0.04, 2.6, 0.04, Color("1b1b1b"))
			k.box(14.5, 1.8, -7.0, 0.8, 0.6, 0.8, BOIS)
			for i in 3:
				k.cylinder(-12.0 + i * 1.0, 1.2, -5.4, 0.4, 0.4, 0.9, 8, BOIS) # tonneaux
		"rotonde_locos":
			k.plate(0, 0, w, d, Color("6b6660"))
			var brique := _v(k, [BRIQUE, Color("9a4431"), Color("b5583d")])
			# Demi-anneau de stalles ouvert vers −Z, pont tournant au centre.
			var r0 := 10.0
			var r1 := 25.0
			_anneau(k, 0, -6.0, r1 - 0.6, r1, 0, 8.0, 14, brique, 0.0, PI)
			_toit_anneau(k, 0, -6.0, r0, r1 + 0.4, 8.0, 1.6, 14, ARDOISE, 0.0, PI)
			for i in 15:
				var a := PI * i / 14.0
				k.box(cos(a) * r0, 0, -6.0 + sin(a) * r0, 0.6, 8.0, 0.6, brique.darkened(0.1))
			for i in 14:
				var a := PI * (i + 0.5) / 14.0
				for e in 2:
					var rr := r1 + 0.05
					k.box(cos(a) * rr, 3.0 + e * 2.4, -6.0 + sin(a) * rr, 1.0, 1.4, 1.0, GLASS)
				# Rails vers chaque stalle.
				_poutre(k, Vector3(cos(a) * 6.0, 0.12, -6.0 + sin(a) * 6.0), Vector3(cos(a) * r1, 0.12, -6.0 + sin(a) * r1), 0.15, Color("3d3d3d"))
			k.cylinder(0, 0, -6.0, 6.0, 6.0, 0.3, 16, Color("4a4a4a"))
			k.box(0, 0.3, -6.0, 12.0, 0.4, 1.6, FONTE)
			k.box(0, 0, -19.0, 1.6, 0.25, 14.0, Color("4a4a4a")) # voie d'accès au pont tournant
			_cheminee(k, 18.0, 8.0, 10.0, 1.0, 1.0, 5.0, brique, true)
			_cheminee(k, -18.0, 8.0, 10.0, 1.0, 1.0, 5.0, brique, true)
		"chateau_eau_gare":
			k.plate(0, 0, w, d, Color("b9b6ae"))
			var brique := _v(k, [BRIQUE, Color("9a4431")])
			k.box(0, 0, 1.0, 6.0, 9.0, 6.0, brique)
			k.box(0, 9.0, 1.0, 6.6, 0.3, 6.6, PIERRE)
			k.cylinder(0, 9.3, 1.0, 3.4, 3.4, 3.4, 12, FONTE)
			k.cylinder(0, 12.7, 1.0, 3.6, 0.0, 1.2, 12, ARDOISE)
			k.box(0, 0, -2.05, 1.0, 2.2, 0.12, PORTE)
			_fenetres_cote(k, 3.05, 1.0, 4.0, 5.0, 2, 0.6, 1.4)
			# Grue hydraulique au bord du quai.
			k.box(0, 0, -4.8, 0.5, 3.4, 0.5, FONTE)
			_poutre(k, Vector3(0, 3.2, -4.8), Vector3(-3.0, 3.2, -4.8), 0.3, FONTE)
			_poutre(k, Vector3(-3.0, 3.2, -4.8), Vector3(-3.0, 2.2, -4.8), 0.25, Color("1b1b1b"))
		"halle_fonte":
			k.plate(0, 0, w, d, PAVES)
			var fonte := _v(k, [VERT_FONTE, FONTE, Color("3b4a5a")])
			# Colonnes et grand toit à lanterneau vitré.
			for i in 8:
				for j in 5:
					var x := -18.0 + i * (36.0 / 7.0)
					var z := -12.0 + j * 6.0
					k.box(x, 0, z, 0.35, 8.0, 0.35, fonte)
			k.box(0, 0.0, -12.6, 38.0, 1.0, 0.25, fonte) # soubassement des grilles
			k.box(0, 6.0, 0, 39.0, 0.3, 26.0, fonte)
			for i in 9:
				k.box(0, 1.6 + i * 0.5, -12.7, 38.0, 0.12, 0.08, fonte.lightened(0.15)) # persiennes
			k.gable(0, 8.0, 0, 40.0, 28.0, 3.4, Color("8a959e"))
			k.box(0, 11.0, 0, 38.0, 2.2, 6.0, Color("8fb8d8"))
			k.gable(0, 13.2, 0, 38.6, 6.6, 1.4, Color("7a858e"))
			k.box(0, 6.3, -13.6, 6.0, 1.8, 0.3, fonte)
			k.box(0, 6.8, -13.8, 4.4, 0.8, 0.1, Color("e9c46a"))
			for i in 6:
				var x := -14.0 + i * 5.6
				k.box(x, 0, -2.0, 2.4, 0.9, 1.4, BOIS) # étals
				k.box(x, 0.9, -2.0, 2.2, 0.3, 1.2, [Color("e76f51"), Color("76b041"), Color("f2c14e")][i % 3])
		"kiosque_fonte":
			k.plate(0, 0, w, d, Color("c2a878"))
			k.cylinder(0, 0, 0, 5.2, 5.2, 1.4, 8, PIERRE)
			var fonte := _v(k, [VERT_FONTE, Color("2f4a5a"), FONTE])
			for i in 8:
				var a := TAU * (i + 0.5) / 8.0
				k.box(cos(a) * 4.6, 1.4, sin(a) * 4.6, 0.2, 3.4, 0.2, fonte)
			_anneau(k, 0, 0, 4.5, 4.7, 1.4, 0.9, 8, fonte.lightened(0.2), PI / 8.0, PI / 8.0 + TAU * 7.0 / 8.0) # garde-corps
			k.cylinder(0, 4.8, 0, 5.6, 0.6, 2.4, 8, fonte)
			k.cylinder(0, 7.2, 0, 0.6, 0.0, 1.0, 8, Color("c9a227"))
			k.box(0, 0, -5.6, 2.0, 0.7, 1.2, PIERRE)
			for i in 5:
				k.box(-4.0 + i * 2.0, 0, -8.5, 1.6, 0.45, 0.5, BOIS) # bancs
		"bureau_poste":
			var pierre := _v(k, [Color("e8dcc2"), Color("efe4cc")])
			k.box(0, 0, 0, 14.0, 7.6, 10.0, pierre)
			k.box(0, 7.6, 0, 14.4, 0.4, 10.4, pierre.darkened(0.1))
			k.hip(0, 8.0, 0, 14.6, 10.6, 2.6, ARDOISE)
			k.box(0, 0, -5.05, 2.0, 3.0, 0.14, PORTE)
			_fenetres(k, 0, -5.05, 12.0, 1.0, 4, 1.2, 2.4)
			_fenetres(k, 0, -5.05, 12.0, 4.6, 4, 1.0, 1.8)
			k.box(0, 3.5, -5.12, 7.0, 0.7, 0.12, Color("1d3557"))
			k.box(0, 3.6, -5.18, 6.0, 0.45, 0.05, Color("e9c46a"))
			# Poteau du télégraphe et ses fils.
			k.box(6.2, 0, -6.0, 0.25, 9.5, 0.25, BOIS)
			k.box(6.2, 9.0, -6.0, 1.6, 0.12, 0.12, BOIS)
			k.box(-5.5, 0, -5.7, 0.6, 1.2, 0.5, Color("e9c46a")) # boîte aux lettres
		"manufacture_vapeur":
			k.plate(0, 0, w, d, Color("8e8a82"))
			var brique := _v(k, [BRIQUE, Color("9a4431"), Color("8c3b2a")])
			# Ateliers en sheds.
			k.box(-4.0, 0, 2.0, 34.0, 5.0, 24.0, brique)
			for i in 6:
				var z := -8.0 + i * 4.0
				k.panel(Vector3(-21.0, 5.0, z - 2.0), Vector3(13.0, 5.0, z - 2.0), Vector3(13.0, 7.6, z + 2.0), Vector3(-21.0, 7.6, z + 2.0), Vector3(0, 1, -0.8), ARDOISE)
				k.box(-4.0, 5.0, z + 2.0, 34.0, 2.6, 0.12, GLASS)
			_fenetres(k, -4.0, -10.05, 30.0, 1.4, 10, 1.2, 2.4)
			# Salle des machines et haute cheminée.
			k.box(17.0, 0, -4.0, 10.0, 9.0, 12.0, brique.darkened(0.05))
			k.gable(17.0, 9.0, -4.0, 10.6, 12.6, 3.0, ARDOISE, false)
			_fenetres_cote(k, 22.05, -4.0, 10.0, 2.0, 3, 1.4, 4.5)
			k.cylinder(17.0, 0, 9.0, 1.9, 1.3, 32.0, 10, brique.darkened(0.1))
			k.cylinder(17.0, 31.0, 9.0, 1.6, 1.6, 1.2, 10, Color("3d3d3d"))
			k.anchor("fumee", Vector3(17.0, 33.0, 9.0))
			k.box(17.0, 0, 9.0, 4.4, 2.0, 4.4, PIERRE)
			k.box(-4.0, 0, -10.6, 4.0, 3.6, 0.12, BOIS_SOMBRE)
			k.box(10.0, 0, 12.0, 6.0, 2.2, 4.0, Color("2b2b2b")) # tas de charbon
		"puits_mine":
			k.plate(0, 0, w, d, Color("6b6660"))
			var brique := _v(k, [BRIQUE, Color("8c3b2a")])
			# Chevalement en bois et poutrelles.
			var top := Vector3(-4.0, 18.0, -3.0)
			for s in [-1.0, 1.0]:
				_poutre(k, Vector3(-4.0 + s * 3.0, 0.4, -6.0), top + Vector3(s * 0.8, 0, 0), 0.5, Color("3d3d3d"))
				_poutre(k, Vector3(-4.0 + s * 3.0, 0.4, 0.0), top + Vector3(s * 0.8, 0, 0), 0.5, Color("3d3d3d"))
				_poutre(k, Vector3(-4.0 + s * 2.5, 0.4, 7.0), top + Vector3(s * 0.8, 0, 0), 0.4, Color("4a4a4a")) # bigues
			for s2 in [-0.6, 0.6]:
				_roue(k, Vector3(-4.0 + s2, 18.6, -3.0), 1.8, Color("2f2f2f"))
			k.box(-4.0, 0, -3.0, 6.0, 1.2, 6.0, Color("4a4a4a"))
			# Salle de la machine d'extraction et cheminée.
			k.box(6.0, 0, 6.0, 12.0, 8.0, 9.0, brique)
			k.gable(6.0, 8.0, 6.0, 12.6, 9.6, 3.0, ARDOISE)
			_fenetres(k, 6.0, 1.45, 10.0, 2.0, 3, 1.4, 3.6)
			_poutre(k, Vector3(2.0, 6.0, 4.0), top, 0.1, Color("1b1b1b")) # câble
			k.cylinder(10.0, 0, -6.0, 1.4, 1.0, 22.0, 10, brique.darkened(0.1))
			k.anchor("fumee", Vector3(10.0, 22.5, -6.0))
			k.cylinder(-10.0, 0, 7.0, 6.0, 0.6, 7.0, 10, Color("3a3634")) # terril
			for i in 3:
				k.box(4.0 + i * 1.8, 0.1, -8.0, 1.4, 1.0, 1.0, Color("2b2b2b")) # berlines
		"usine_gaz":
			k.plate(0, 0, w, d, Color("8e8a82"))
			var brique := _v(k, [BRIQUE, Color("9a4431")])
			k.box(-10.0, 0, 4.0, 16.0, 7.0, 12.0, brique)
			k.gable(-10.0, 7.0, 4.0, 16.6, 12.6, 3.0, ARDOISE)
			_fenetres(k, -10.0, -2.05, 14.0, 1.5, 5, 1.2, 3.0)
			k.cylinder(-14.0, 0, 8.0, 1.0, 0.8, 18.0, 8, brique.darkened(0.1))
			k.anchor("fumee", Vector3(-14.0, 18.5, 8.0))
			# Gazomètre : cloche dans sa cage de fonte.
			k.cylinder(9.0, 0, 0, 9.0, 9.0, 1.0, 16, PIERRE)
			k.cylinder(9.0, 1.0, 0, 8.4, 8.4, 9.0, 16, Color("6d7a80"))
			k.dome(9.0, 10.0, 0, 8.4, 1.4, Color("5c686e"), 16)
			for i in 10:
				var a := TAU * i / 10.0
				k.box(9.0 + cos(a) * 9.2, 1.0, sin(a) * 9.2, 0.4, 13.0, 0.4, FONTE)
			for y in [6.0, 13.6]:
				for i in 10:
					var a0 := TAU * i / 10.0
					var a1 := TAU * (i + 1) / 10.0
					_poutre(k, Vector3(9.0 + cos(a0) * 9.2, y, sin(a0) * 9.2), Vector3(9.0 + cos(a1) * 9.2, y, sin(a1) * 9.2), 0.25, FONTE)
			k.box(-8.0, 0, -9.0, 8.0, 2.4, 5.0, Color("2b2b2b")) # houille
		"phare_granit":
			k.plate(0, 0, w, d, Color("9a958a"))
			var c := _v(k, [BLANC, Color("e9e2d4")])
			k.cylinder(0, 0, 1.0, 2.8, 1.9, 22.0, 12, c)
			for y in [5.0, 13.0]:
				k.cylinder(0, y, 1.0, 2.55 - y * 0.04, 2.45 - y * 0.04, 3.0, 12, Color("1b1b1b") if k.variant % 2 == 0 else Color("c1121f"))
			k.cylinder(0, 22.0, 1.0, 2.4, 2.4, 0.4, 12, FONTE)
			k.cylinder(0, 22.4, 1.0, 1.3, 1.3, 2.2, 8, Color("ffd166"))
			k.cylinder(0, 24.6, 1.0, 1.6, 0.2, 1.4, 8, FONTE)
			k.box(0, 0, -1.85, 0.9, 2.0, 0.12, PORTE)
			k.box(-3.0, 0, -3.0, 5.0, 3.2, 4.0, c) # maison du gardien
			k.gable(-3.0, 3.2, -3.0, 5.6, 4.6, 1.6, ARDOISE)
			k.box(-3.0, 0, -5.05, 0.9, 2.0, 0.12, PORTE)
		"lavoir":
			k.plate(0, 0, w, d, PAVES)
			k.box(0, 0, 0, 10.0, 0.6, 6.0, PIERRE)
			k.plate(0, 0, 9.0, 5.0, EAU, 0.2, 0.42)
			for x in [-4.6, -1.5, 1.5, 4.6]:
				for z in [-2.8, 2.8]:
					k.box(x, 0.6, z, 0.3, 2.8, 0.3, BOIS)
			k.gable(0, 3.4, 0, 11.4, 7.6, 1.6, TUILE)
			for i in 5:
				k.box(-4.0 + i * 2.0, 0.6, -2.6, 1.2, 0.15, 0.6, BOIS) # planches à laver
			k.box(5.6, 0, -3.5, 0.6, 1.4, 0.6, PIERRE) # pompe
			k.box(5.6, 1.4, -3.8, 0.12, 0.12, 0.6, FONTE)
		_:
			k.box(0, 0, 0, w * 0.8, 4.0, d * 0.8, ENDUIT)
			k.gable(0, 4.0, 0, w * 0.85, d * 0.85, 2.0, TUILE)
