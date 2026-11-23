class_name Tenues
extends RefCounted
## Tenues et accessoires des personnages selon leur situation : métier,
## âge, saison et météo du jour, époque (1800 → aujourd'hui) et région du monde.
##
## - Civils (passants, habitants dans les pièces, piétons d'ambiance) : la mode
##   de l'époque (redingotes, robes longues et hauts-de-forme au XIXe siècle,
##   canotiers et casquettes vers 1900, costumes et robes des Trente Glorieuses,
##   tenues d'aujourd'hui), le temps qu'il fait (manteau, bonnet et écharpe
##   par grand froid, bras nus et shorts en été, parapluie sous la pluie),
##   l'âge (cartable des écoliers, canne des personnes âgées) et la région
##   (tissus wax, chapeaux coniques…).
## - Métiers : uniforme de l'époque et du pays (pompier au casque de laiton en
##   1850, à bandes réfléchissantes aujourd'hui ; gendarme au bicorne, agent au
##   képi, policier à casquette ; médecin en redingote puis en blouse ; bleu de
##   travail puis gilet haute visibilité…).
##
## Rien ne coûte au rendu en plus d'un chapeau et d'un ou deux petits objets
## (maillages partagés, une seule instance chacun, sans ombre) : rayures,
## carreaux, bandes réfléchissantes, gilets et tabliers sont peints par le
## shader des personnages (silhouette.gdshader, uniform « motif »).
##
## Les choix sont stables : ils se tirent à partir du numéro de la personne,
## comme le reste de son apparence (rien à sauvegarder).

## Motifs peints par le shader (instance uniform « motif »).
enum Motif { AUCUN, BANDES, RAYURES, CARREAUX, WAX, GILET, TABLIER, BAVETTE, COSTUME }

## Époques des tenues : 0 XIXe siècle (avant 1870), 1 Belle Époque et
## entre-deux-guerres (1870-1939), 2 Trente Glorieuses (1940-1979), 3 aujourd'hui.
const NOMS_EPOQUES := ["XIXe siècle", "1900", "1950-1970", "Aujourd'hui"]

## Contexte imposé (vitrine, tests) : {annee, saison, temp, pluie, region}.
static var force: Dictionary = {}
static var _ctx: Dictionary = {}
static var _ctx_ms := -1000000
static var _maillages: Dictionary = {}
static var _hauts_tete: Dictionary = {}


static func epoque(annee: int) -> int:
	if annee < 1870:
		return 0
	if annee < 1940:
		return 1
	if annee < 1980:
		return 2
	return 3


## Le contexte du moment (rafraîchi toutes les 2 s) : année, saison (0 hiver,
## 1 printemps, 2 été, 3 automne), température (°C), pluie (0 à 1), neige,
## région du monde de la ville.
static func contexte() -> Dictionary:
	if not force.is_empty():
		var f := {"annee": 2025, "saison": 1, "temp": 16.0, "pluie": 0.0, "neige": 0.0, "region": "europe"}
		f.merge(force, true)
		return f
	var now := Time.get_ticks_msec()
	if not _ctx.is_empty() and now - _ctx_ms < 2000:
		return _ctx
	_ctx_ms = now
	var c := {"annee": Epoques.annee(), "saison": 1, "temp": 16.0, "pluie": 0.0, "neige": 0.0, "region": "europe"}
	var s: Saisons = Saisons.instance
	if s != null and is_instance_valid(s):
		var d := s.date_locale(s.now())
		c.saison = Saisons.saison_de(int(d.doy), s.lat())
		c.region = Prenoms.region_for_place(s.lat(), s.lon())
		var m := s.meteo()
		if m != null:
			c.temp = m.temperature
			c.pluie = m.precip * (1.0 - m.snow)
			c.neige = m.precip * m.snow
	_ctx = c
	return c


## Contexte pour l'intérieur : la mode de l'époque, sans météo ni affaires de sortie.
static func contexte_interieur() -> Dictionary:
	var c := contexte().duplicate()
	c.temp = 20.0
	c.pluie = 0.0
	c.neige = 0.0
	c.dedans = true
	return c


# --- Civils ------------------------------------------------------------------------------

const HAUTS_1800 := ["2b2d42", "3d405b", "5c4033", "6b4e3d", "1f3a2e", "7a2e2e", "e8e0cf", "4a4e69", "3b3b3b", "8c6e4b", "51546e", "6d5a3a"]
const BAS_1800 := ["2b2a28", "3b3631", "5c4a3a", "6b5d4a", "3a3f4a", "8a7a5a", "e8e0cf"]
const ROBES_1800 := ["5b3a4a", "3d4f6b", "6b4e3d", "7a2e2e", "2f4a3a", "8d7b68", "4a3d5c", "a68a64", "2b2d42", "c7b9a0"]
const HAUTS_1900 := ["2b2d42", "3d405b", "5c4033", "4a4e69", "e8e0cf", "1d3557", "6b705c", "7a2e2e", "8d99ae", "f4f1e8", "3a5a40"]
const ROBES_1900 := ["3d4f6b", "7a2e2e", "2f4a3a", "8d7b68", "4a3d5c", "a68a64", "e8e0cf", "1d3557", "6d597a", "b5838d"]
const HAUTS_1950 := ["e9c46a", "8ab17d", "c8553d", "3a86c8", "f4f1e8", "9c6644", "d4a373", "6d597a", "2a9d8f", "e76f51", "4a4e69",
	"f2a7b8", "7fb7be", "a68a64"]
const MANTEAUX := ["2b2d42", "3d3d3d", "5c4033", "1d3557", "6b2e2e", "4a5a3a", "7a6a58", "8d99ae", "3a3f4a", "a0522d"]
const CHAUSSURES_ANCIENNES := ["2a2a2a", "4a3426", "3b2a1e", "1f1f1f"]
const WAX := ["e76f51", "f4a261", "2a9d8f", "e9c46a", "8338ec", "06aed5", "d62828", "ffb703", "3a86c8"]


static func _c(liste: Array, r: RandomNumberGenerator) -> Color:
	return Color(String(liste[r.randi() % liste.size()]))


## Adapte l'apparence de tous les jours (Silhouettes.apparence) à l'époque, à
## la saison, au temps et à l'âge. Ajoute les clés chapeau, objets, motif,
## motif_couleur. look est modifié et renvoyé.
static func civil(look: Dictionary, pid: int, age: float, sexe: String, region: String, ctx: Dictionary) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = hash(pid * 4513 + 29)
	var e := epoque(int(ctx.get("annee", 2025)))
	var t := Silhouettes.tranche(age)
	var f := sexe == "F"
	var adulte := t in ["adulte", "senior"]
	var grand := t in ["ado", "adulte", "senior"]
	var chapeau := ""
	var objets: Array = []
	var motif := 0
	var mcol := Color("f4f1e8")
	var coif := String(look.get("coiffure", ""))
	var voile := coif in ["foulard", "turban"]
	var ailleurs := region in ["afrique", "moyen_orient", "asie_sud", "asie_est"]
	# Époque : silhouettes, couleurs, couvre-chefs.
	match e:
		0:
			look.manches = 1.0
			look.jambes = 1.0
			if f and grand:
				if String(look.habit) in ["", "jupe", "robe"]:
					look.habit = "robe_longue" if r.randf() < 0.55 else "jupe_longue"
				look.haut = _c(ROBES_1800, r)
				look.bas = (look.haut as Color).darkened(0.12) if look.habit == "jupe_longue" else look.haut
				if r.randf() < 0.35 and not ailleurs:
					motif = Motif.TABLIER
					mcol = Color("efe9dc")
				if not voile:
					if coif in ["court", "ras", "raie", "afro", "locks", "casquette", ""]:
						coif = "chignon"
					var p := r.randf()
					if p < 0.45:
						chapeau = "coiffe"
					elif p < 0.6 and age > 25.0:
						chapeau = "capote"
			elif f:
				if String(look.habit) == "":
					look.habit = "robe"
				look.haut = _c(ROBES_1800, r).lightened(0.15)
			else:
				look.haut = _c(HAUTS_1800, r)
				look.bas = _c(BAS_1800, r)
				if adulte and not ailleurs and r.randf() < 0.55:
					motif = Motif.COSTUME
					mcol = Color("f1ece0")
				if adulte and not voile:
					var p2 := r.randf()
					if p2 < 0.35:
						chapeau = "haut_de_forme"
					elif p2 < 0.65:
						chapeau = "chapeau_feutre"
					elif p2 < 0.85:
						chapeau = "casquette_gavroche"
				elif t == "ado" and r.randf() < 0.5:
					chapeau = "casquette_gavroche"
			look.chaussures = _c(CHAUSSURES_ANCIENNES, r)
		1:
			look.manches = 1.0 if r.randf() < 0.9 else 0.0
			look.jambes = 1.0
			if f and grand:
				if String(look.habit) in ["", "jupe"]:
					look.habit = "jupe_longue" if r.randf() < 0.6 else "robe"
				look.haut = _c(ROBES_1900, r)
				if look.habit == "jupe_longue":
					look.bas = _c(["2b2d42", "3d405b", "5c4033", "4a4e69", "6b705c"], r)
				else:
					look.bas = look.haut
				if not voile and r.randf() < 0.45:
					chapeau = "cloche" if int(ctx.get("annee", 1900)) >= 1915 else "capote"
					if coif in ["afro", "locks", "casquette"]:
						coif = "chignon"
			elif f:
				if String(look.habit) == "":
					look.habit = "robe"
			else:
				look.haut = _c(HAUTS_1900, r)
				look.bas = _c(BAS_1800, r)
				if adulte and not ailleurs and r.randf() < 0.5:
					motif = Motif.COSTUME
					mcol = Color("f4f1e8")
				elif r.randf() < 0.12:
					motif = Motif.RAYURES
					mcol = Color("f4f1e8")
				if grand and not voile:
					var p3 := r.randf()
					var ete := int(ctx.get("saison", 1)) == 2
					if p3 < 0.3:
						chapeau = "canotier" if ete else "melon"
					elif p3 < 0.6:
						chapeau = "casquette_gavroche"
					elif p3 < 0.8:
						chapeau = "chapeau_feutre"
				elif t == "enfant" and r.randf() < 0.3:
					chapeau = "beret"
			look.chaussures = _c(CHAUSSURES_ANCIENNES, r)
		2:
			if f and grand and String(look.habit) == "" and r.randf() < 0.55:
				look.habit = "robe" if r.randf() < 0.5 else "jupe"
			look.haut = _c(HAUTS_1950, r)
			if not f and adulte and not ailleurs:
				var p4 := r.randf()
				if p4 < 0.3:
					motif = Motif.COSTUME
					mcol = Color("f4f1e8")
					look.haut = _c(["3a3f4a", "4a4e69", "5c4033", "6b705c", "2b2d42"], r)
					look.bas = look.haut
				elif p4 < 0.42:
					motif = Motif.CARREAUX
					mcol = (look.haut as Color).darkened(0.35)
				if int(ctx.get("annee", 1960)) < 1962 and r.randf() < 0.35:
					chapeau = "chapeau_feutre"
				elif t == "senior" and r.randf() < 0.35:
					chapeau = "beret"
			elif f and grand and r.randf() < 0.1:
				motif = Motif.RAYURES
				mcol = Color("f4f1e8")
		_:
			if grand and not ailleurs:
				var p5 := r.randf()
				if p5 < 0.07:
					motif = Motif.RAYURES
					mcol = Color("f4f1e8") if (look.haut as Color).get_luminance() < 0.5 else Color("1d3557")
				elif p5 < 0.12 and not f:
					motif = Motif.CARREAUX
					mcol = (look.haut as Color).darkened(0.4)
	if e < 2 and coif == "casquette":
		coif = "court"
	if e < 2:
		# Feutres, rubans et lainages de teintes sourdes.
		look.accessoire = _c(["2b2d42", "3d405b", "5c4033", "4a3d5c", "2f4a3a", "6b4e3d", "1b1b1e", "7a2e2e", "8c6e4b", "51546e"], r)
	# Tissus wax d'Afrique de l'Ouest, à toutes les époques.
	if region == "afrique" and grand and motif == 0 and r.randf() < (0.35 if f else 0.15):
		motif = Motif.WAX
		look.haut = _c(WAX, r)
		mcol = _c(WAX, r)
		if String(look.habit) in ["robe", "robe_longue", "jupe_longue"]:
			look.bas = look.haut
	# Chapeau conique des campagnes d'Asie (surtout autrefois).
	if region in ["asie_est", "asie_sud"] and adulte and chapeau == "" and not voile:
		if r.randf() < [0.3, 0.2, 0.1, 0.03][e]:
			chapeau = "chapeau_conique"
	# Saison et temps qu'il fait.
	var temp := float(ctx.get("temp", 16.0))
	var froid := clampf((10.0 - temp) / 14.0, 0.0, 1.0) # 0 à 10 °C, 1 à −4 °C
	var chaud := clampf((temp - 21.0) / 9.0, 0.0, 1.0)  # 0 à 21 °C, 1 à 30 °C
	if t != "bebe":
		if froid > 0.0:
			look.manches = 1.0
			if String(look.habit) == "" or r.randf() < froid:
				look.jambes = 1.0
			if r.randf() < 0.35 + froid * 0.6:
				# Manteau : on couvre le haut d'une couleur d'hiver.
				look.haut = _c(MANTEAUX, r) if e > 0 or not f else (look.haut as Color).darkened(0.2)
				if motif in [Motif.RAYURES, Motif.CARREAUX, Motif.WAX, Motif.TABLIER]:
					motif = 0
			if chapeau in ["", "canotier", "chapeau_conique"] and not voile and r.randf() < froid * (0.75 if e >= 2 else 0.35):
				chapeau = "bonnet_hiver" if e >= 2 or t in ["petit", "enfant"] else "chapeau_feutre"
			if r.randf() < froid * 0.7:
				objets.append(["echarpe", "torse"])
		elif chaud > 0.0:
			if r.randf() < 0.3 + chaud * 0.6 and e >= 2:
				look.manches = 0.0
			if e >= 2 and String(look.habit) == "" and r.randf() < chaud * (0.55 if not f or e == 3 else 0.2):
				look.jambes = 0.0
			if e == 3 and chapeau == "" and not voile and coif != "casquette" and r.randf() < chaud * 0.25:
				chapeau = "chapeau_soleil" if f else "casquette_sport"
			if e >= 2:
				look.haut = (look.haut as Color).lightened(0.12 * chaud)
	# L'âge : cartable des écoliers, canne, sac à main.
	if t in ["enfant", "ado"] and r.randf() < 0.55:
		objets.append(["cartable" if e < 2 else "sac_dos", "torse"])
	elif adulte and e == 3 and r.randf() < 0.1:
		objets.append(["sac_dos", "torse"])
	if motif == 0 and not objets.is_empty() and String(objets[-1][0]) == "sac_dos":
		mcol = _c(["c1121f", "1d3557", "2a9d8f", "e9c46a", "8338ec", "f77f00", "3a86c8", "2b2d42"], r)
	if f and grand and r.randf() < (0.3 if e == 3 else 0.2) and objets.size() < 2:
		objets.append(["sac_main", "torse"])
	var main_gauche := false
	if t == "senior" and age > 72.0 and r.randf() < clampf((age - 72.0) / 20.0, 0.15, 0.6):
		objets.append(["canne", "main_d"])
	var pluie := float(ctx.get("pluie", 0.0))
	if pluie > 0.15 and t != "bebe" and t != "petit" and r.randf() < clampf(pluie * 0.8, 0.15, 0.55):
		objets.append(["parapluie", "torse"])
		main_gauche = true
	if main_gauche and chapeau in ["chapeau_soleil", "casquette_sport", "haut_de_forme", "canotier", "chapeau_paille", "chapeau_conique"]:
		chapeau = ""
	if chapeau != "" and coif in ["afro", "locks", "chignon", "casquette"] and not chapeau in ["coiffe", "capote"]:
		coif = "mi_long" if f else "court"
	if voile:
		chapeau = ""
	if bool(ctx.get("dedans", false)):
		if chapeau != "coiffe":
			chapeau = ""
		objets = []
	look.coiffure = coif
	look.chapeau = chapeau
	look.objets = objets
	look.motif = float(motif)
	look.motif_couleur = mcol
	return look


# --- Métiers -----------------------------------------------------------------------------

## Uniforme par époque : [XIXe, 1900, 1950-1970, aujourd'hui] ; une case vide
## (null) reprend la précédente. Chaque tenue : haut, bas, chapeau, motif,
## motif_couleur ; options : chaussures, manches (1/0), habit ("robe_longue"…),
## objets ([nom, os]), accessoire (couleur du rôle accessoire des chapeaux).
const UNIFORMES := {
	"pompier": [
		{"haut": "22386b", "bas": "2b2d42", "chapeau": "casque_laiton"},
		{"haut": "1f2a44", "bas": "1f2a44", "chapeau": "casque_laiton"},
		{"haut": "1f2a44", "bas": "1f2a44", "chapeau": "casque_pompier", "motif": Motif.AUCUN},
		{"haut": "1f2a44", "bas": "1f2a44", "chapeau": "casque_f1", "motif": Motif.BANDES, "mc": "e4f04a"},
	],
	"policier": [
		{"haut": "1d3557", "bas": "e8e0cf", "chapeau": "bicorne", "motif": Motif.COSTUME, "mc": "e8e0cf"},
		{"haut": "1d2a4a", "bas": "1d2a4a", "chapeau": "kepi", "motif": Motif.COSTUME, "mc": "f4f1e8"},
		{"haut": "2b3a67", "bas": "2b3a67", "chapeau": "kepi"},
		{"haut": "1d3557", "bas": "1d3557", "chapeau": "casquette_police", "mc": "2b2b2e"},
	],
	"medecin": [
		{"haut": "2b2b2b", "bas": "2b2b2b", "chapeau": "", "motif": Motif.COSTUME, "mc": "f4f1e8"},
		{"haut": "f5f7f8", "bas": "2b2d42", "chapeau": ""},
		{"haut": "f5f7f8", "bas": "3a3f4a", "objets": [["stethoscope", "torse"]]},
		{"haut": "f5f7f8", "bas": "3d5a80", "objets": [["stethoscope", "torse"]]},
	],
	"infirmier": [
		{"haut": "6c7a8a", "bas": "6c7a8a", "chapeau": "coiffe", "motif": Motif.BAVETTE, "mc": "fbfbf8", "habit_f": "robe_longue"},
		{"haut": "5d7590", "bas": "5d7590", "chapeau": "coiffe_infirmiere", "motif": Motif.BAVETTE, "mc": "fbfbf8", "habit_f": "robe_longue"},
		{"haut": "f5f7f8", "bas": "f5f7f8", "chapeau": "coiffe_infirmiere", "habit_f": "robe"},
		{"haut": "8ecae6", "bas": "8ecae6", "chapeau": "", "manches": 0.0},
	],
	"aide_soignant": [null, null, {"haut": "f5f7f8", "bas": "f5f7f8", "habit_f": "robe"}, {"haut": "b7e4c7", "bas": "b7e4c7", "manches": 0.0}],
	"ouvrier": [
		{"haut": "e8e0cf", "bas": "5c4033", "chapeau": "casquette_gavroche", "accessoire": "4a4e69"},
		{"haut": "3b5ba5", "bas": "3b5ba5", "chapeau": "casquette_gavroche", "accessoire": "3a3f4a"},
		{"haut": "3b5ba5", "bas": "3b5ba5", "chapeau": "casque"},
		{"haut": "4a5560", "bas": "3a4a6b", "chapeau": "casque", "motif": Motif.GILET, "mc": "f77f00"},
	],
	"mineur": [
		{"haut": "5c5c5c", "bas": "3a3a3a", "chapeau": "casquette_gavroche", "accessoire": "2b2b2b"},
		{"haut": "4a4a4a", "bas": "3a3a3a", "chapeau": "casque_cuir"},
		{"haut": "5c5c5c", "bas": "3a3a3a", "chapeau": "casque_lampe"},
		{"haut": "2b2d42", "bas": "2b2d42", "chapeau": "casque_lampe", "motif": Motif.BANDES, "mc": "e4f04a"},
	],
	"agriculteur": [
		{"haut": "3b5ba5", "bas": "5c4033", "chapeau": "chapeau_paille"},
		{"haut": "3b5ba5", "bas": "3b3f4a", "chapeau": "chapeau_paille"},
		{"haut": "5a7d3a", "bas": "3b5ba5", "chapeau": "casquette_gavroche", "accessoire": "4a4e69"},
		{"haut": "b23a48", "bas": "3b5ba5", "chapeau": "casquette_sport", "motif": Motif.CARREAUX, "mc": "4a1e24", "accessoire": "2d6a4f"},
	],
	"boulanger": [
		{"haut": "f4f1ea", "bas": "d9d4c7", "chapeau": "calot", "motif": Motif.TABLIER, "mc": "fbfbf8", "manches": 0.0},
		{"haut": "f4f1ea", "bas": "c9c1ae", "chapeau": "calot", "motif": Motif.TABLIER, "mc": "fbfbf8", "manches": 0.0},
		{"haut": "f4f1ea", "bas": "d9d4c7", "chapeau": "toque"},
		{"haut": "f4f1ea", "bas": "2f2f33", "chapeau": "toque", "motif": Motif.TABLIER, "mc": "3a3f4a"},
	],
	"cuisinier": [
		{"haut": "f7f7f2", "bas": "f7f7f2", "chapeau": "toque", "motif": Motif.TABLIER, "mc": "fbfbf8"},
		null,
		{"haut": "f7f7f2", "bas": "3d3d3d", "chapeau": "toque", "motif": Motif.TABLIER, "mc": "fbfbf8"},
		{"haut": "f7f7f2", "bas": "2f2f33", "chapeau": "toque", "motif": Motif.TABLIER, "mc": "2f2f33"},
	],
	"boucher": [
		{"haut": "f4f1ea", "bas": "3a3f4a", "chapeau": "calot", "motif": Motif.BAVETTE, "mc": "e8e4da"},
		null,
		{"haut": "f4f1ea", "bas": "3a3f4a", "chapeau": "", "motif": Motif.BAVETTE, "mc": "9fb8d0"},
		{"haut": "f4f1ea", "bas": "3a3f4a", "chapeau": "", "motif": Motif.BAVETTE, "mc": "7a2e2e"},
	],
	"serveur": [
		{"haut": "f4f1e8", "bas": "202024", "motif": Motif.TABLIER, "mc": "fbfbf8"},
		{"haut": "202024", "bas": "202024", "motif": Motif.TABLIER, "mc": "fbfbf8"},
		{"haut": "f4f1e8", "bas": "202024", "motif": Motif.COSTUME, "mc": "202024"},
		{"haut": "202024", "bas": "202024", "motif": Motif.TABLIER, "mc": "3a3a3e"},
	],
	"cadre": [
		{"haut": "2b2b2b", "bas": "3b3631", "motif": Motif.COSTUME, "mc": "f1ece0"},
		{"haut": "2b2d42", "bas": "2b2d42", "motif": Motif.COSTUME, "mc": "f4f1e8"},
		{"haut": "3a3f4a", "bas": "3a3f4a", "motif": Motif.COSTUME, "mc": "f4f1e8"},
		{"haut": "2b2d42", "bas": "2b2d42", "motif": Motif.COSTUME, "mc": "dde6ef"},
	],
	"chauffeur": [
		{"haut": "3d405b", "bas": "3b3631", "chapeau": "haut_de_forme"},
		{"haut": "2b2d42", "bas": "2b2d42", "chapeau": "kepi"},
		{"haut": "577590", "bas": "3a3f4a", "chapeau": "casquette_police", "accessoire": "577590"},
		{"haut": "577590", "bas": "3a3f4a", "chapeau": ""},
	],
	"agent_gare": [
		{"haut": "264653", "bas": "264653", "chapeau": "kepi", "motif": Motif.COSTUME, "mc": "f4f1e8"},
		null,
		{"haut": "264653", "bas": "264653", "chapeau": "kepi"},
		{"haut": "264653", "bas": "264653", "chapeau": "casquette_police", "motif": Motif.GILET, "mc": "e4f04a"},
	],
	"eboueur": [
		{"haut": "6b5d4a", "bas": "5c4a3a", "chapeau": "casquette_gavroche", "accessoire": "3b3631"},
		{"haut": "3b5ba5", "bas": "3b5ba5", "chapeau": "casquette_gavroche", "accessoire": "3a3f4a"},
		{"haut": "52734a", "bas": "52734a", "chapeau": ""},
		{"haut": "2a6f3a", "bas": "2a6f3a", "chapeau": "", "motif": Motif.BANDES, "mc": "e4f04a"},
	],
	"bucheron": [
		{"haut": "7a2e2e", "bas": "5c4033", "chapeau": "chapeau_feutre", "accessoire": "4a3426"},
		null,
		{"haut": "c1121f", "bas": "3a4a2b", "chapeau": "casquette_gavroche", "motif": Motif.CARREAUX, "mc": "2b1b1b", "accessoire": "3a4a2b"},
		{"haut": "c1121f", "bas": "3a4a2b", "chapeau": "casque", "motif": Motif.CARREAUX, "mc": "2b1b1b"},
	],
	"pecheur": [
		{"haut": "1d3557", "bas": "3b3631", "chapeau": "bonnet_marin", "motif": Motif.RAYURES, "mc": "f4f1e8", "accessoire": "c1121f"},
		null,
		{"haut": "ffb703", "bas": "ffb703", "chapeau": "bonnet_marin", "accessoire": "1d3557"},
		null,
	],
	"meunier": [{"haut": "e9e4d8", "bas": "8a7a5a", "chapeau": "bonnet_hiver", "accessoire": "e9e4d8"}, null, null, null],
	"jardinier": [
		{"haut": "3b5ba5", "bas": "5c4033", "chapeau": "chapeau_paille", "motif": Motif.TABLIER, "mc": "5a7d3a"},
		null,
		{"haut": "2d6a4f", "bas": "3a3f4a", "chapeau": "chapeau_paille"},
		{"haut": "2d6a4f", "bas": "3a3f4a", "chapeau": "chapeau_soleil", "accessoire": "2d6a4f"},
	],
	"artisan": [
		{"haut": "e8e0cf", "bas": "5c4033", "chapeau": "", "motif": Motif.BAVETTE, "mc": "7f5539"},
		null, null,
		{"haut": "7f5539", "bas": "3a3f4a", "chapeau": "", "motif": Motif.BAVETTE, "mc": "5c4033"},
	],
	"enseignant": [
		{"haut": "2b2b2b", "bas": "2b2b2b", "motif": Motif.COSTUME, "mc": "f1ece0"},
		{"haut": "3a3f4a", "bas": "3a3f4a", "motif": Motif.COSTUME, "mc": "f4f1e8"},
		{"haut": "f4f1e8", "bas": "3a3f4a"},
		null,
	],
	"porteur_funeraire": [
		{"haut": "1b1b1e", "bas": "1b1b1e", "chapeau": "haut_de_forme", "motif": Motif.COSTUME, "mc": "f1ece0"},
		{"haut": "1b1b1e", "bas": "1b1b1e", "chapeau": "chapeau_feutre", "motif": Motif.COSTUME, "mc": "f4f1e8", "accessoire": "1b1b1e"},
		{"haut": "1b1b1e", "bas": "1b1b1e", "motif": Motif.COSTUME, "mc": "f4f1e8"},
		null,
	],
}

## Variantes régionales d'aujourd'hui : région → métier → tenue (remplace l'entrée 3).
const UNIFORMES_REGION := {
	"ameriques": {
		"pompier": {"haut": "b59b5f", "bas": "b59b5f", "chapeau": "casque_us", "motif": Motif.BANDES, "mc": "e4f04a"},
		"policier": {"haut": "22303f", "bas": "22303f", "chapeau": "casquette_police", "accessoire": "22303f"},
	},
	"asie_est": {
		"pompier": {"haut": "2b3a67", "bas": "2b3a67", "chapeau": "casque_f1", "motif": Motif.BANDES, "mc": "f28c28"},
		"policier": {"haut": "a9c6e0", "bas": "1d2a44", "chapeau": "casquette_police"},
	},
	"asie_sud": {"policier": {"haut": "b5a27a", "bas": "b5a27a", "chapeau": "beret", "accessoire": "1d2a44"}},
	"afrique": {"policier": {"haut": "4a5a3a", "bas": "1d2a44", "chapeau": "beret", "accessoire": "1d2a44"}},
}

## Métiers qui portent l'uniforme d'un autre.
const MEME_TENUE := {
	"ouvrier_btp": "ouvrier", "carrier": "ouvrier", "conducteur_engins": "ouvrier", "foreur": "ouvrier",
	"siderurgiste": "ouvrier", "operateur": "ouvrier", "mecanicien": "ouvrier", "boutefeu": "mineur",
	"agent_tri": "eboueur", "gardien_decheterie": "eboueur", "agent_proprete": "eboueur", "maraicher": "agriculteur",
	"eleveur": "agriculteur", "palefrenier": "agriculteur", "fossoyeur": "jardinier", "menuisier": "artisan",
	"couturier": "artisan", "decorateur": "artisan", "professeur": "enseignant", "professeur_universite": "enseignant",
	"enseignant_pro": "enseignant", "conseiller_funeraire": "porteur_funeraire", "thanatopracteur": "medecin",
	"pharmacien": "medecin", "laborantin": "medecin", "veterinaire_zoo": "medecin", "chercheur": "medecin",
	"ambulancier": "infirmier", "ingenieur": "cadre", "comedien": "cadre", "producteur": "cadre", "realisateur": "cadre",
	"receptionniste": "cadre", "conseiller_sejour": "cadre", "guide_conferencier": "cadre", "conservateur": "cadre",
}


## L'uniforme d'un métier à une époque, dans une région ({} = pas d'uniforme connu).
static func uniforme(met: String, annee: int, region := "europe") -> Dictionary:
	var cle := met
	var m: Dictionary = Metiers.METIERS.get(met, {})
	if not UNIFORMES.has(cle):
		if m.has("tenue") and UNIFORMES.has(String(m.tenue)):
			cle = String(m.tenue)
		else:
			cle = String(MEME_TENUE.get(met, ""))
	if cle == "" or not UNIFORMES.has(cle):
		return {}
	var e := epoque(annee)
	if e == 3 and UNIFORMES_REGION.has(region) and (UNIFORMES_REGION[region] as Dictionary).has(cle):
		return UNIFORMES_REGION[region][cle]
	var liste: Array = UNIFORMES[cle]
	for i in range(e, -1, -1):
		if liste[i] != null:
			return liste[i]
	for i in range(e + 1, liste.size()):
		if liste[i] != null:
			return liste[i]
	return {}


## Habille un look (Silhouettes.apparence) pour le travail : uniforme de
## l'époque si le métier en a un ; sinon les couleurs de Figurine.TENUES
## (ancien système), et les vêtements de ville sans bonnet ni parapluie.
static func metier(look: Dictionary, met: String, sexe: String, ctx: Dictionary, region := "") -> Dictionary:
	var reg := region if region != "" else String(ctx.get("region", "europe"))
	var annee := int(ctx.get("annee", 2025))
	var u := uniforme(met, annee, reg)
	var objets: Array = []
	for o in look.get("objets", []):
		if String(o[0]) in ["sac_main", "sac_dos", "cartable", "parapluie", "echarpe", "canne"]:
			continue
		objets.append(o)
	look.objets = objets
	if String(look.get("chapeau", "")) in ["bonnet_hiver", "chapeau_soleil", "casquette_sport", "canotier", "capote"]:
		look.chapeau = ""
	if u.is_empty():
		var t: Array = Figurine.TENUES.get(met, ["", "", ""]) if met != "" else ["", "", ""]
		var m: Dictionary = Metiers.METIERS.get(met, {})
		if m.has("tenue") and Figurine.TENUES.has(String(m.tenue)):
			t = Figurine.TENUES[String(m.tenue)]
		if String(t[0]) != "":
			look.haut = Color(String(t[0]))
			look.manches = 1.0
			look.motif = 0.0
		if String(t[1]) != "":
			look.bas = Color(String(t[1]))
			look.jambes = 1.0
		var ch := String(t[2])
		if ch in ["toque", "casque", "casque_lampe", "casque_pompier", "casquette", "chapeau", "bonnet"]:
			look.chapeau = {"casquette": "casquette_police", "chapeau": "chapeau_paille", "bonnet": "bonnet_hiver"}.get(ch, ch)
		elif ch == "tablier" or ch == "tablier_rouge":
			look.motif = float(Motif.TABLIER)
			look.motif_couleur = Color("fbfbf8") if ch == "tablier" else Color("9c2c3a")
		elif ch == "blouse":
			look.objets.append(["stethoscope", "torse"])
		return look
	look.haut = Color(String(u.get("haut", "3a3f4a")))
	look.bas = Color(String(u.get("bas", "3a3f4a")))
	look.manches = float(u.get("manches", 1.0))
	look.jambes = 1.0
	look.motif = float(u.get("motif", 0))
	look.motif_couleur = Color(String(u.get("mc", "f4f1e8")))
	look.chapeau = String(u.get("chapeau", ""))
	if u.has("accessoire"):
		look.accessoire = Color(String(u.accessoire))
	if u.has("chaussures"):
		look.chaussures = Color(String(u.chaussures))
	else:
		look.chaussures = Color("1f1f1f") if annee >= 1870 else Color("3b2a1e")
	if sexe == "F" and u.has("habit_f"):
		look.habit = String(u.habit_f)
	elif String(look.get("habit", "")) == "robe_longue" and not met in ["infirmier", "aide_soignant"]:
		look.habit = ""  # la tenue de travail remplace le boubou ou la robe
	elif String(look.get("habit", "")) != "" and met in ["pompier", "policier", "ouvrier", "mineur"]:
		look.habit = ""
	for o in u.get("objets", []):
		look.objets.append(o)
	var coif := String(look.get("coiffure", ""))
	if look.chapeau != "" and coif in ["afro", "locks", "chignon", "casquette", "turban"]:
		look.coiffure = "court" if sexe != "F" else "mi_long"
	if look.chapeau != "" and coif == "foulard":
		look.chapeau = "" if not met in ["pompier", "ouvrier", "mineur"] else look.chapeau
		if look.chapeau != "":
			look.coiffure = "mi_long"
	return look


# --- Maillages des chapeaux et objets -------------------------------------------------------
# Couleurs : alpha 0 = couleur fixe ; alpha 0,4 = couleur « accessoire » de la
# personne (la luminosité du RVB sert d'ombrage) ; alpha 0,6 = couleur du motif.
# Les chapeaux sont dessinés dans le repère de la tête, haut du crâne en y = 0,25
# (comme Figurine._chapeau) ; les objets du torse dans celui du torse, les
# objets tenus dans celui de la main (avant-bras à l'horizontale : +Z = vers le haut).

const ACC := 0.4
const MOT := 0.6


static func _fixe(hex: String) -> Color:
	var c := Color(hex)
	c.a = 0.0
	return c


static func _acc(ombre := 1.0) -> Color:
	return Color(0.7 * ombre, 0.7 * ombre, 0.7 * ombre, ACC)


static func _mot(ombre := 1.0) -> Color:
	return Color(0.7 * ombre, 0.7 * ombre, 0.7 * ombre, MOT)


## Le maillage d'un chapeau ou d'un objet (partagé, null si inconnu).
static func maillage(nom: String) -> ArrayMesh:
	if _maillages.has(nom):
		return _maillages[nom]
	var k := LpKit.new(hash(nom))
	k.jitter = 0.0
	var ok := true
	match nom:
		# Chapeaux.
		"haut_de_forme":
			k.tube(Vector3(0, 0.205, -0.01), Vector3(0, 0.222, -0.01), 0.19, 0.19, 10, _fixe("1e1c1c"))
			k.tube(Vector3(0, 0.215, -0.01), Vector3(0, 0.45, -0.01), 0.118, 0.128, 10, _fixe("252222"))
			k.tube(Vector3(0, 0.222, -0.01), Vector3(0, 0.26, -0.01), 0.124, 0.122, 10, _fixe("5a1e1e"))
		"melon":
			k.tube(Vector3(0, 0.2, -0.01), Vector3(0, 0.215, -0.01), 0.17, 0.17, 10, _fixe("2a2522"))
			k.blob(Vector3(0, 0.25, -0.01), Vector3(0.13, 0.11, 0.14), _fixe("221e1b"), _fixe("3a3330"), 0.0, 1)
		"canotier":
			k.tube(Vector3(0, 0.205, -0.01), Vector3(0, 0.218, -0.01), 0.2, 0.2, 10, _fixe("e6cf8f"))
			k.tube(Vector3(0, 0.21, -0.01), Vector3(0, 0.3, -0.01), 0.125, 0.125, 10, _fixe("ddc27e"))
			k.tube(Vector3(0, 0.22, -0.01), Vector3(0, 0.25, -0.01), 0.128, 0.128, 10, _fixe("1d3557"))
		"chapeau_feutre":
			k.tube(Vector3(0, 0.2, -0.01), Vector3(0, 0.215, -0.01), 0.19, 0.19, 10, _acc(0.8))
			k.tube(Vector3(0, 0.21, -0.01), Vector3(0, 0.34, -0.01), 0.125, 0.11, 10, _acc(1.0))
			k.tube(Vector3(0, 0.215, -0.01), Vector3(0, 0.245, -0.01), 0.128, 0.126, 10, _fixe("1b1b1e"))
		"casquette_gavroche":
			k.blob(Vector3(0, 0.235, 0.0), Vector3(0.15, 0.06, 0.165), _acc(0.8), _acc(1.05), 0.03, 1)
			k.box(Vector3(0, 0.2, 0.15), Vector3(0.2, 0.02, 0.09), _acc(0.7))
		"casquette_sport":
			k.blob(Vector3(0, 0.22, -0.01), Vector3(0.14, 0.09, 0.15), _acc(0.85), _acc(1.05), 0.0, 1)
			k.box(Vector3(0, 0.19, 0.17), Vector3(0.18, 0.02, 0.13), _acc(0.75))
		"bonnet_hiver", "bonnet_marin":
			k.blob(Vector3(0, 0.215, -0.015), Vector3(0.145, 0.12, 0.15), _acc(0.85), _acc(1.05), 0.04, 1)
			k.tube(Vector3(0, 0.15, -0.015), Vector3(0, 0.2, -0.015), 0.148, 0.146, 10, _acc(0.75))
			if nom == "bonnet_hiver":
				k.blob(Vector3(0, 0.345, -0.02), Vector3(0.045, 0.045, 0.045), _fixe("f4f1e8"), _fixe("ffffff"), 0.1, 0)
		"beret":
			k.blob(Vector3(0.02, 0.255, -0.01), Vector3(0.16, 0.045, 0.16), _acc(0.8), _acc(1.0), 0.02, 1)
		"cloche":
			k.blob(Vector3(0, 0.215, -0.01), Vector3(0.15, 0.13, 0.155), _acc(0.85), _acc(1.05), 0.0, 1)
			k.tube(Vector3(0, 0.12, -0.01), Vector3(0, 0.14, -0.01), 0.17, 0.165, 10, _acc(0.75))
			k.tube(Vector3(0, 0.15, -0.01), Vector3(0, 0.18, -0.01), 0.153, 0.152, 10, _fixe("7a2e2e"))
		"capote":
			k.blob(Vector3(0, 0.21, -0.05), Vector3(0.14, 0.13, 0.13), _acc(0.85), _acc(1.0), 0.0, 1)
			k.beam(Vector3(0, 0.33, 0.08), Vector3(0, 0.33, -0.1), 0.27, 0.02, _acc(0.95))
			k.beam(Vector3(0.12, 0.16, 0.02), Vector3(0.03, 0.0, 0.1), 0.03, 0.01, _fixe("efe9dc"))
		"coiffe":
			k.blob(Vector3(0, 0.2, -0.05), Vector3(0.135, 0.125, 0.13), _fixe("efebe2"), _fixe("fbfaf5"), 0.05, 1)
			k.beam(Vector3(0, 0.3, 0.07), Vector3(0, 0.3, -0.12), 0.25, 0.02, _fixe("f4f1e8"))
		"coiffe_infirmiere":
			k.box(Vector3(0, 0.27, -0.01), Vector3(0.2, 0.06, 0.16), _fixe("fbfbf8"))
			k.box(Vector3(0, 0.29, 0.06), Vector3(0.05, 0.035, 0.012), _fixe("d62828"))
		"chapeau_paille":
			k.tube(Vector3(0, 0.2, -0.01), Vector3(0, 0.215, -0.01), 0.26, 0.26, 12, _fixe("d9bf73"))
			k.tube(Vector3(0, 0.21, -0.01), Vector3(0, 0.33, -0.01), 0.125, 0.105, 10, _fixe("e2ca85"))
			k.tube(Vector3(0, 0.215, -0.01), Vector3(0, 0.24, -0.01), 0.128, 0.126, 10, _fixe("7a2e2e"))
		"chapeau_soleil":
			k.tube(Vector3(0, 0.2, -0.01), Vector3(0, 0.212, -0.01), 0.23, 0.23, 12, _acc(0.95))
			k.blob(Vector3(0, 0.24, -0.01), Vector3(0.125, 0.09, 0.13), _acc(0.85), _acc(1.05), 0.0, 1)
		"chapeau_conique":
			k.tube(Vector3(0, 0.19, -0.01), Vector3(0, 0.4, -0.01), 0.3, 0.012, 12, _fixe("d8c38a"))
		"bicorne":
			k.blob(Vector3(0, 0.25, -0.01), Vector3(0.13, 0.06, 0.14), _fixe("1b1b1e"), _fixe("2b2b2e"), 0.0, 1)
			k.tri(Vector3(-0.24, 0.24, -0.01), Vector3(0.24, 0.24, -0.01), Vector3(0, 0.42, -0.01), _fixe("1e1e22"), Vector3.BACK)
			k.tri(Vector3(-0.24, 0.24, -0.02), Vector3(0.24, 0.24, -0.02), Vector3(0, 0.42, -0.02), _fixe("1e1e22"), Vector3.FORWARD)
			k.box(Vector3(0.06, 0.31, -0.005), Vector3(0.05, 0.05, 0.02), _fixe("d62828"))
		"kepi":
			k.tube(Vector3(0, 0.17, -0.01), Vector3(0, 0.3, -0.03), 0.138, 0.125, 10, _fixe("1d2a4a"))
			k.tube(Vector3(0, 0.17, -0.01), Vector3(0, 0.21, -0.012), 0.144, 0.142, 10, _fixe("b08d2c"))
			k.box(Vector3(0, 0.175, 0.15), Vector3(0.2, 0.015, 0.08), _fixe("111111"))
		"casquette_police":
			k.tube(Vector3(0, 0.16, -0.01), Vector3(0, 0.25, -0.01), 0.14, 0.14, 10, _fixe("1b2233"))
			k.blob(Vector3(0, 0.27, -0.015), Vector3(0.17, 0.05, 0.18), _acc(0.8), _acc(1.0), 0.0, 1)
			k.tube(Vector3(0, 0.18, -0.01), Vector3(0, 0.215, -0.01), 0.143, 0.143, 10, _mot(1.0))
			k.box(Vector3(0, 0.165, 0.15), Vector3(0.21, 0.015, 0.09), _fixe("111111"))
			k.box(Vector3(0, 0.235, 0.14), Vector3(0.04, 0.04, 0.01), _fixe("d4af37"))
		"casque_laiton":
			k.blob(Vector3(0, 0.235, -0.01), Vector3(0.155, 0.13, 0.17), _fixe("a27e2a"), _fixe("e0bd5a"), 0.0, 1)
			k.beam(Vector3(0, 0.36, -0.14), Vector3(0, 0.37, 0.12), 0.035, 0.06, _fixe("c9a23a"))
			k.tube(Vector3(0, 0.15, -0.01), Vector3(0, 0.17, -0.01), 0.18, 0.175, 10, _fixe("b08d2c"))
		"casque_f1":
			k.blob(Vector3(0, 0.235, -0.01), Vector3(0.16, 0.13, 0.17), _fixe("b8bec6"), _fixe("e8ecf0"), 0.0, 1)
			k.box(Vector3(0, 0.23, 0.165), Vector3(0.2, 0.06, 0.02), _fixe("d4a017"))
			k.tube(Vector3(0, 0.14, -0.04), Vector3(0, 0.16, -0.04), 0.17, 0.17, 10, _fixe("2b2b2e"))
		"casque_pompier":
			k.blob(Vector3(0, 0.24, -0.01), Vector3(0.15, 0.1, 0.16), _fixe("e8e8e8"), _fixe("ffffff"), 0.0, 1)
			k.box(Vector3(0, 0.29, 0.0), Vector3(0.03, 0.05, 0.3), _fixe("d62828"))
		"casque_us":
			k.blob(Vector3(0, 0.24, -0.01), Vector3(0.15, 0.11, 0.16), _fixe("d9a404"), _fixe("f2c230"), 0.0, 1)
			k.tube(Vector3(0, 0.16, -0.06), Vector3(0, 0.175, -0.07), 0.22, 0.2, 10, _fixe("c99a06"))
			k.box(Vector3(0, 0.27, 0.15), Vector3(0.08, 0.07, 0.02), _fixe("f4f1e8"))
		"casque", "casque_lampe", "casque_cuir":
			var cc := _fixe("f9c74f") if nom != "casque_cuir" else _fixe("5c4033")
			k.blob(Vector3(0, 0.24, -0.01), Vector3(0.155, 0.1, 0.165), cc, Color(cc).lightened(0.15), 0.0, 1)
			k.tube(Vector3(0, 0.17, -0.01), Vector3(0, 0.185, -0.01), 0.18, 0.18, 10, Color(cc).darkened(0.1))
			if nom == "casque_lampe":
				k.box(Vector3(0, 0.25, 0.16), Vector3(0.06, 0.05, 0.03), _fixe("fff3b0"))
		"toque":
			k.tube(Vector3(0, 0.17, -0.01), Vector3(0, 0.25, -0.01), 0.14, 0.14, 10, _fixe("f4f4f0"))
			k.blob(Vector3(0, 0.33, -0.01), Vector3(0.17, 0.1, 0.17), _fixe("eeeeea"), _fixe("fbfbf8"), 0.12, 1)
		"calot":
			k.tube(Vector3(0, 0.18, -0.01), Vector3(0, 0.27, -0.01), 0.14, 0.138, 10, _fixe("f4f4f0"))
		# Objets du torse (taille en y = 0, cou vers y = 0,43, devant en +Z).
		"echarpe":
			k.tube(Vector3(0, 0.35, 0.0), Vector3(0, 0.44, 0.0), 0.115, 0.085, 8, _acc(0.95))
			k.beam(Vector3(0.05, 0.38, 0.1), Vector3(0.075, 0.16, 0.135), 0.07, 0.025, _acc(0.85))
		"stethoscope":
			k.beam(Vector3(-0.075, 0.42, 0.06), Vector3(-0.06, 0.24, 0.125), 0.014, 0.014, _fixe("2b2b2e"))
			k.beam(Vector3(0.075, 0.42, 0.06), Vector3(0.06, 0.24, 0.125), 0.014, 0.014, _fixe("2b2b2e"))
			k.box(Vector3(0.06, 0.225, 0.13), Vector3(0.04, 0.04, 0.02), _fixe("b8bec6"))
		"sac_dos", "cartable":
			var sc := _mot(1.0) if nom == "sac_dos" else _fixe("6b4a32")
			k.box(Vector3(0, 0.22, -0.155), Vector3(0.26, 0.3, 0.1), sc)
			k.box(Vector3(0, 0.14, -0.21), Vector3(0.2, 0.12, 0.02), Color(sc).darkened(0.2))
		"sac_main":
			k.box(Vector3(0.225, -0.02, 0.0), Vector3(0.06, 0.16, 0.22), _fixe("6b4a32"))
			k.beam(Vector3(0.22, 0.06, 0.0), Vector3(0.13, 0.42, 0.0), 0.015, 0.015, _fixe("4a3426"))
		"parapluie":
			# Tenu dans la main gauche devant la poitrine, la toile au-dessus de la tête.
			k.beam(Vector3(0.24, 0.16, 0.32), Vector3(0.07, 1.09, 0.11), 0.018, 0.018, _fixe("2b2b2e"))
			k.tube(Vector3(0.07, 0.87, 0.11), Vector3(0.07, 1.09, 0.11), 0.56, 0.02, 8, _acc(0.9))
		# Objets tenus (repère de la main).
		"canne":
			k.beam(Vector3(0, 0.03, 0.0), Vector3(0, -0.8, -0.36), 0.022, 0.022, _fixe("5c4033"))
			k.beam(Vector3(0, 0.03, 0.0), Vector3(0, 0.03, 0.09), 0.025, 0.025, _fixe("5c4033"))
		_:
			ok = false
	var m: ArrayMesh = k.commit({"base": Silhouettes.materiau()}) if ok else null
	_maillages[nom] = m
	return m


## Haut du crâne (cheveux compris) dans le repère de la tête, mis en cache par
## corps et coiffure (le calcul parcourt les maillages de la tête).
static func haut_de_tete(tete: Node3D, cle: String) -> float:
	if _hauts_tete.has(cle):
		return _hauts_tete[cle]
	var h := Figurine._haut_de_tete(tete)
	_hauts_tete[cle] = h
	return h


## Pose le chapeau et les objets d'un look sur le squelette (Silhouettes.creer).
static func equiper(racine: Node3D, rig: Dictionary, look: Dictionary) -> void:
	var tient := {}
	var ch := String(look.get("chapeau", ""))
	if ch != "" and rig.get("tete") != null:
		var m := maillage(ch)
		if m != null:
			var tete := rig.tete as Node3D
			var cle := String(look.get("corps", "")) + "/" + String(look.get("coiffure", ""))
			var hat := MeshInstance3D.new()
			hat.name = "Chapeau"
			hat.mesh = m
			# Les chapeaux enveloppent le crâne : on ne tient compte que du haut
			# de la tête, pas d'une coiffure volumineuse.
			var top := haut_de_tete(tete, cle)
			var crane := haut_de_tete(tete, String(look.get("corps", "")) + "/")
			hat.position = Vector3(0, minf(top, crane + 0.03) - Figurine.CHAPEAU_Y, 0)
			tete.add_child(hat)
			if ch in ["haut_de_forme", "casque_laiton", "casque_f1", "casque_us", "casque", "casque_lampe", "casque_pompier",
					"toque", "kepi", "casquette_police", "bicorne", "chapeau_paille", "chapeau_conique", "melon", "canotier", "chapeau_feutre"]:
				# Sous un chapeau rigide, les cheveux du dessus sont cachés.
				var chev := rig.get("cheveux") as Node3D
				if chev != null and chev.get_child_count() > 0 and String(look.get("coiffure", "")) in ["court", "ras", "raie", "boucles", "mi_long"]:
					(chev.get_child(0) as Node3D).scale = Vector3(1.0, 0.85, 1.0)
	for o in look.get("objets", []):
		var nom := String(o[0])
		var os_nom := String(o[1])
		var parent := rig.get(os_nom) as Node3D
		var m2 := maillage(nom)
		if parent == null or m2 == null:
			continue
		var mi := MeshInstance3D.new()
		mi.name = nom
		mi.mesh = m2
		if os_nom == "torse" and parent is MeshInstance3D and (parent as MeshInstance3D).mesh != null:
			# Objets dessinés pour un torse d'adulte moyen : à la mesure de celui-ci.
			var t := (parent as MeshInstance3D).mesh.get_aabb().size
			mi.scale = Vector3(t.x / 0.3956, t.y / 0.4705, t.z / 0.2223)
		parent.add_child(mi)
		if os_nom.begins_with("main"):
			tient[os_nom.substr(5)] = nom
		elif nom == "parapluie":
			tient["g"] = nom
	if not tient.is_empty():
		racine.set_meta("tient", tient)
		rig["_tient"] = tient  # lu à chaque pas (Silhouettes.marcher), sans get_meta


## Pose du bras qui tient un objet (parapluie levé, canne en avant).
static func bras_tenant(rig: Dictionary, cote: String, objet: String) -> void:
	var b := rig.get("bras_" + cote) as Node3D
	var ab := rig.get("avant_bras_" + cote) as Node3D
	if b == null or ab == null:
		return
	if objet == "parapluie":
		b.rotation = Vector3(-0.2, 0, -0.5 if cote == "g" else 0.5)
		ab.rotation = Vector3(-2.3, 0, 0)
	else:
		b.rotation = Vector3(-0.2, 0, 0)
		ab.rotation = Vector3(-0.25, 0, 0)
