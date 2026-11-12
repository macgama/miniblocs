class_name Silhouettes
extends RefCounted
## Les personnages arrondis, modelés dans Blender
## (tools/blender/personnages_lowpoly.py → assets/modeles/personnages/).
##
## - 28 corps : bébé, petit (3-6 ans), enfant (7-11), ado, adulte, senior ;
##   femmes et hommes ; minces, moyens, ronds, forts.
## - 16 coiffures (courte, raie, boucles, afro, longue, queue, chignon, tresses,
##   locks, calvitie, foulard, turban, casquette…) et 4 jupes / robes.
## - Couleurs libres (shader silhouette.gdshader) : peau, cheveux, haut, bas,
##   chaussures, accessoire ; manches et jambes longues ou nues.
##
## Squelette (nœuds séparés, origine exactement à l'articulation, regard +Z) :
##   bassin ─ jambe_g/d ─ tibia_g/d
##          ├ habit (jupes et robes)
##          └ torse ─ tete ─ cheveux
##                  └ bras_g/d ─ avant_bras_g/d ─ main_g/d (vide : outil tenu)
## rotation.x négative = vers l'avant ; rotation.z = écarte le bras.
##
## Usage :
##   var n := Silhouettes.pour_habitant(pop, pid)   # apparence stable de l'habitant
##   Silhouettes.habiller(n, {"haut": Color.WHITE, "bas": Color("2b3a55")})  # tenue de métier
##   Silhouettes.poser(n, "assis") ; Silhouettes.marcher(n, phase, 1.0)
##   Silhouettes.os(n).avant_bras_d.rotation.x = -1.2

const DOSSIER := "res://assets/modeles/personnages/"
const NOEUDS := ["bassin", "torse", "tete", "cheveux", "habit", "jambe_g", "jambe_d", "tibia_g", "tibia_d",
	"bras_g", "bras_d", "avant_bras_g", "avant_bras_d", "main_g", "main_d"]

## Teintes de peau, de la plus claire à la plus foncée.
const PEAUX := ["f6dccb", "efc9a9", "e5b48f", "d8a27c", "c98f67", "b67b54", "a06743", "8b5636", "75472d", "613a25",
	"4d2e1e", "3c2417"]
## Région (Prenoms) → [teinte la plus fréquente, dispersion].
const PEAU_REGION := {"europe": [1.5, 1.4], "mediterranee": [3.0, 1.5], "moyen_orient": [4.0, 1.6], "afrique": [8.8, 1.6],
	"asie_sud": [6.0, 1.8], "asie_est": [2.6, 1.2], "ameriques": [4.5, 3.0], "oceanie": [4.0, 3.0]}
const CHEVEUX_COULEURS := {"noir": "1c1714", "brun_fonce": "33241b", "brun": "553823", "chatain": "7a4c2c",
	"roux": "93401f", "blond_fonce": "a07848", "blond": "cfae6c", "platine": "e4d6ac", "gris": "9b9791", "blanc": "dddad3"}
const HAUTS := ["3a86c8", "e76f51", "2a9d8f", "e9c46a", "8d5a97", "6b8f3a", "d64545", "4a4e69", "f4f1e8", "1d3557",
	"f2a7b8", "7fb7be", "c8553d", "2f2f2f", "9c6644", "ffd166", "06aed5", "8ab17d"]
const BAS := ["2b2d42", "3b3f4a", "1d3557", "5c4a3a", "6b705c", "22223b", "8d99ae", "a68a64", "3a5a40", "111111"]
const ACCESSOIRES := ["2b2d42", "1d3557", "6d597a", "e9c46a", "c8553d", "f4f1e8", "2a9d8f", "9c2c3a", "8a5a44"]

static var _scenes: Dictionary = {}
static var _materiau: ShaderMaterial


# --- Apparence ---------------------------------------------------------------------

## Tranche d'âge du modèle : bebe, petit, enfant, ado, adulte, senior.
static func tranche(age: float) -> String:
	if age < 2.5:
		return "bebe"
	if age < 6.5:
		return "petit"
	if age < 11.5:
		return "enfant"
	if age < 17.5:
		return "ado"
	if age < 68.0:
		return "adulte"
	return "senior"


## Taille réelle visée (m) selon l'âge et le sexe ("F" / "H").
static func taille_cible(age: float, sexe: String) -> float:
	var adulte := 1.63 if sexe == "F" else 1.76
	var pts := [[0.0, 0.5], [1.0, 0.75], [2.0, 0.87], [3.0, 0.95], [6.0, 1.15], [9.0, 1.33], [12.0, 1.5],
		[15.0, adulte - (0.01 if sexe == "F" else 0.06)], [18.0, adulte]]
	if age >= 18.0:
		return adulte * (1.0 - clampf((age - 65.0) / 30.0, 0.0, 1.0) * 0.04)
	for i in range(pts.size() - 1):
		if age < float(pts[i + 1][0]):
			var t := (age - float(pts[i][0])) / (float(pts[i + 1][0]) - float(pts[i][0]))
			return lerpf(float(pts[i][1]), float(pts[i + 1][1]), t)
	return adulte


## Taille du modèle Blender (voir AGES dans le script Blender).
static func taille_modele(t: String, sexe: String) -> float:
	var f := sexe == "F"
	match t:
		"bebe":
			return 0.80
		"petit":
			return 1.08
		"enfant":
			return 1.36
		"ado":
			return 1.59 if f else 1.64
		"senior":
			return 1.59 if f else 1.69
	return 1.636 if f else 1.74


## Nom du corps (fichier corps/<nom>.glb).
static func corps_pour(age: float, sexe: String, corpulence: String) -> String:
	var t := tranche(age)
	var s := "f" if sexe == "F" else "h"
	match t:
		"bebe":
			return "bebe_x_" + ("rond" if corpulence in ["rond", "fort"] else "moyen")
		"petit", "enfant":
			return "%s_x_%s" % [t, "rond" if corpulence == "fort" else corpulence]
		"ado", "senior":
			return "%s_%s_%s" % [t, s, "rond" if corpulence == "fort" else corpulence]
	return "adulte_%s_%s" % [s, corpulence]


static func _choix(rng: RandomNumberGenerator, poids: Dictionary) -> String:
	var total := 0.0
	for k in poids:
		total += float(poids[k])
	var r := rng.randf() * total
	for k in poids:
		r -= float(poids[k])
		if r <= 0.0:
			return String(k)
	return String(poids.keys()[0])


## Apparence stable d'une personne. famille : graine commune du foyer (même
## teinte de base, même couleur de cheveux à peu près) ; region : voir Prenoms.
## Renvoie {corps, coiffure, habit, echelle, peau, cheveux, haut, bas,
## chaussures, accessoire, manches, jambes} (couleurs en Color).
static func apparence(pid: int, age: float, sexe: String, region := "europe", famille := 0) -> Dictionary:
	var rf := RandomNumberGenerator.new()
	rf.seed = hash(famille * 92821 + 17)
	var r := RandomNumberGenerator.new()
	r.seed = hash(pid * 7919 + 3)
	var f := sexe == "F"
	var t := tranche(age)
	# Peau : une teinte par foyer (selon la région, mais toutes les couleurs
	# existent partout), un peu de variation d'une personne à l'autre.
	var reg: Array = PEAU_REGION.get(region, PEAU_REGION.europe)
	var base := float(reg[0]) + rf.randfn(0.0, float(reg[1]))
	if rf.randf() < 0.15:
		base = rf.randf() * float(PEAUX.size() - 1)
	var ip := clampf(base + r.randfn(0.0, 0.5), 0.0, float(PEAUX.size() - 1))
	var i0 := int(floor(ip))
	var peau := Color(PEAUX[i0]).lerp(Color(PEAUX[mini(i0 + 1, PEAUX.size() - 1)]), ip - i0)
	# Cheveux : selon la teinte de peau, le foyer, puis l'âge (gris, blanc).
	var fonce := ip / float(PEAUX.size() - 1)
	var poids_c := {"noir": 1.0 + fonce * 6.0, "brun_fonce": 2.0, "brun": 2.0 - fonce, "chatain": 1.6 - fonce * 1.4,
		"roux": maxf(0.35 - fonce, 0.02), "blond_fonce": maxf(1.2 - fonce * 2.0, 0.05), "blond": maxf(0.9 - fonce * 2.0, 0.02),
		"platine": maxf(0.25 - fonce, 0.0)}
	if region == "asie_est":
		poids_c = {"noir": 6.0, "brun_fonce": 2.0, "brun": 0.4}
	var nom_c := _choix(rf, poids_c)
	if r.randf() < 0.2:
		nom_c = _choix(r, poids_c)
	if t in ["bebe", "petit"] and nom_c in ["brun", "chatain", "blond_fonce"] and r.randf() < 0.4:
		nom_c = "blond_fonce" if nom_c == "chatain" else "chatain" if nom_c == "brun" else "blond"
	var cheveux := Color(CHEVEUX_COULEURS[nom_c])
	var gris := clampf((age - 38.0) / 40.0 + r.randfn(0.0, 0.12), 0.0, 1.0)
	if gris > 0.15:
		cheveux = cheveux.lerp(Color(CHEVEUX_COULEURS.gris), clampf(gris * 1.3, 0.0, 1.0))
		if gris > 0.75:
			cheveux = cheveux.lerp(Color(CHEVEUX_COULEURS.blanc), (gris - 0.75) * 3.0)
	# Corpulence.
	var corp := "moyen"
	if t in ["bebe", "petit", "enfant"]:
		corp = _choix(r, {"mince": 3.0, "moyen": 5.0, "rond": 2.0})
	else:
		corp = _choix(r, {"mince": 25.0, "moyen": 40.0, "rond": 22.0, "fort": 13.0})
	# Coiffure (une courbure de cheveux plus souvent frisée chez les peaux foncées).
	var frise := fonce * 2.2
	var coif := ""
	if t == "bebe":
		coif = _choix(r, {"bebe": 3.0, "": 1.0})
	elif t in ["petit", "enfant"]:
		if f:
			coif = _choix(r, {"queue": 3.0, "long": 2.0, "mi_long": 2.0, "tresses": 0.6 + frise, "boucles": 0.5 + frise, "chignon": 1.0, "afro": frise * 0.6})
		else:
			coif = _choix(r, {"court": 4.0, "ras": 2.0, "raie": 1.5, "boucles": 0.5 + frise, "afro": frise * 0.6, "casquette": 0.4})
	elif f:
		var voile := {"moyen_orient": 0.42, "afrique": 0.18, "asie_sud": 0.14, "mediterranee": 0.06, "europe": 0.04}.get(region, 0.02) as float
		coif = _choix(r, {"long": 3.0, "mi_long": 3.0, "queue": 2.0, "chignon": 1.5 + (2.0 if t == "senior" else 0.0),
			"raie": 1.2, "court": 0.8 + (2.0 if t == "senior" else 0.0), "boucles": 0.6 + frise, "tresses": 0.2 + frise * 1.2,
			"afro": frise * 0.8, "locks": frise * 0.3})
		if t != "ado" or r.randf() < 0.5:
			if r.randf() < voile:
				coif = "foulard"
	else:
		var chauve := clampf((age - 28.0) / 45.0, 0.0, 0.6)
		coif = _choix(r, {"court": 4.0, "ras": 2.5, "raie": 2.0, "boucles": 0.6 + frise, "afro": frise * 0.6,
			"locks": frise * 0.4, "mi_long": 0.4, "queue": 0.15, "casquette": 0.5, "calvitie": chauve * 8.0, "": chauve * 2.0})
		if region == "asie_sud" and t != "ado" and r.randf() < 0.1:
			coif = "turban"
	# Vêtements : jupes et robes, longues plus souvent dans certaines régions.
	var long_r := {"moyen_orient": 2.5, "afrique": 2.0, "asie_sud": 2.5}.get(region, 0.4) as float
	var habit := ""
	if t != "bebe":
		if f:
			habit = _choix(r, {"": 6.0, "jupe": 1.2, "robe": 1.2, "jupe_longue": 0.5 * long_r + (1.0 if t == "senior" else 0.0),
				"robe_longue": 0.5 * long_r})
		elif t in ["adulte", "senior"] and r.randf() < 0.04 * long_r:
			habit = "robe_longue"  # boubou, thobe, kurta…
		if coif == "foulard" and habit == "" and r.randf() < 0.6:
			habit = "robe_longue"
	# Couleurs de vêtements.
	var haut := Color(HAUTS[r.randi() % HAUTS.size()])
	var bas := Color(BAS[r.randi() % BAS.size()])
	if habit in ["jupe", "jupe_longue"] and r.randf() < 0.6:
		bas = Color(HAUTS[r.randi() % HAUTS.size()]).darkened(0.15)
	var acc := Color(ACCESSOIRES[r.randi() % ACCESSOIRES.size()])
	var chaussures := Color(["2a2a2a", "4a3426", "eeeeee", "1d3557", "6b4a32"][r.randi() % 5])
	var manches := 1.0 if r.randf() < 0.6 or t == "bebe" else 0.0
	var jambes := 1.0
	if habit in ["jupe", "robe"]:
		jambes = 1.0 if r.randf() < 0.25 else 0.0  # collants ou jambes nues
	elif habit == "" and r.randf() < (0.3 if t in ["petit", "enfant"] else 0.12):
		jambes = 0.0  # short
	if coif == "foulard":
		manches = 1.0
	var corps := corps_pour(age, sexe, corp)
	var ech := taille_cible(age, sexe) / taille_modele(t, sexe)
	if t in ["ado", "adulte", "senior"]:
		ech *= 1.0 + r.randfn(0.0, 0.035)
	return {"corps": corps, "coiffure": coif, "habit": habit, "echelle": ech, "peau": peau, "cheveux": cheveux,
		"haut": haut, "bas": bas, "chaussures": chaussures, "accessoire": acc, "manches": manches, "jambes": jambes,
		"corpulence": corp}


## Apparence d'un habitant de la Population.
static func apparence_habitant(pop: Population, pid: int) -> Dictionary:
	var p: Dictionary = pop.persons.get(pid, {})
	if p.is_empty():
		return apparence(pid, 35.0, "F" if pid % 2 == 0 else "H")
	var h: Dictionary = pop.households.get(int(p.f), {})
	return apparence(pid, pop.age_of(p), String(p.s), String(h.get("reg", "europe")), int(p.f))


# --- Construction -------------------------------------------------------------------

static func _scene(chemin: String) -> PackedScene:
	if _scenes.has(chemin):
		return _scenes[chemin]
	var sc: PackedScene = null
	var full := DOSSIER + chemin + ".glb"
	if ResourceLoader.exists(full):
		sc = load(full) as PackedScene
	_scenes[chemin] = sc
	return sc


static func materiau() -> ShaderMaterial:
	if _materiau == null:
		_materiau = ShaderMaterial.new()
		_materiau.shader = preload("res://scripts/habitants/silhouette.gdshader")
		var pal := DOSSIER + "palette_roles.png"
		if ResourceLoader.exists(pal):
			_materiau.set_shader_parameter("palette", load(pal))
	return _materiau


## Vrai si les modèles Blender sont importés (sinon creer() fait des blocs).
static func disponible() -> bool:
	return _scene("corps/adulte_h_moyen") != null


## Construit un personnage d'après une apparence (voir apparence()).
## ombre : projette une ombre (coûteux pour des centaines de passants).
static func creer(look: Dictionary, ombre := false) -> Node3D:
	var racine := Node3D.new()
	racine.name = "Silhouette"
	var pose := Node3D.new()
	pose.name = "Pose"
	racine.add_child(pose)
	var ech := float(look.get("echelle", 1.0))
	pose.scale = Vector3.ONE * ech
	var sc := _scene("corps/" + String(look.get("corps", "adulte_h_moyen")))
	var rig := {}
	if sc != null:
		var corps := sc.instantiate() as Node3D
		pose.add_child(corps)
		for nom in NOEUDS:
			rig[nom] = corps.find_child(nom, true, false)
	else:
		_rig_blocs(pose, rig)
	racine.set_meta("rig", rig)
	racine.set_meta("hanche", (rig.bassin as Node3D).position.y)
	racine.set_meta("echelle", ech)
	var coif := String(look.get("coiffure", ""))
	if coif != "" and rig.get("cheveux") != null:
		var c := _scene("cheveux/" + coif)
		if c != null:
			(rig.cheveux as Node3D).add_child(c.instantiate())
	var hab := String(look.get("habit", ""))
	if hab != "" and rig.get("habit") != null:
		var h := _scene("habits/" + hab)
		if h != null:
			(rig.habit as Node3D).add_child(h.instantiate())
	racine.set_meta("couleurs", {})
	_materiaux(racine, ombre)
	colorer(racine, look)
	return racine


## Personnage d'un habitant, avec son apparence stable.
static func pour_habitant(pop: Population, pid: int, ombre := false) -> Node3D:
	var n := creer(apparence_habitant(pop, pid), ombre)
	n.set_meta("pid", pid)
	return n


static func _materiaux(n: Node, ombre: bool) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		mi.material_override = materiau()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if ombre else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_materiaux(c, ombre)


## Change les couleurs : clés peau, cheveux, haut, bas, chaussures, accessoire
## (Color ou "rrggbb"), manches, jambes (1 couvert, 0 nu). Les autres gardent
## leur valeur.
static func colorer(n: Node3D, couleurs: Dictionary) -> void:
	var cur: Dictionary = n.get_meta("couleurs", {})
	for k in ["peau", "cheveux", "haut", "bas", "chaussures", "accessoire", "manches", "jambes"]:
		if couleurs.has(k):
			var v: Variant = couleurs[k]
			if v is String:
				v = Color(v as String)
			elif v is bool:
				v = 1.0 if v else 0.0
			cur[k] = v
	n.set_meta("couleurs", cur)
	_applique(n, cur)


static func _applique(n: Node, cur: Dictionary) -> void:
	if n is GeometryInstance3D:
		for k in cur:
			(n as GeometryInstance3D).set_instance_shader_parameter(k, cur[k])
	for c in n.get_children():
		_applique(c, cur)


## Tenue de métier (haut, bas, chaussures, accessoire, manches, jambes).
## Les clés absentes gardent les vêtements de tous les jours.
static func habiller(n: Node3D, tenue: Dictionary) -> void:
	var t := {}
	for k in ["haut", "bas", "chaussures", "accessoire", "manches", "jambes"]:
		if tenue.has(k):
			t[k] = tenue[k]
	colorer(n, t)


## Les articulations : {bassin, torse, tete, cheveux, habit, jambe_g, …, main_d}.
static func os(n: Node3D) -> Dictionary:
	return n.get_meta("rig", {})


# --- Poses et marche ----------------------------------------------------------------

## Remet toutes les articulations au repos (debout, bras le long du corps).
static func repos(n: Node3D) -> void:
	var rig := os(n)
	for k in rig:
		if rig[k] != null and k != "cheveux" and k != "habit" and not String(k).begins_with("main"):
			(rig[k] as Node3D).rotation = Vector3.ZERO
	if rig.get("bassin") != null:
		(rig.bassin as Node3D).position.y = float(n.get_meta("hanche", 0.9))
	if rig.get("habit") != null:
		var hab := rig.habit as Node3D
		if not hab.has_meta("echelle"):
			hab.set_meta("echelle", hab.scale)
		hab.scale = hab.get_meta("echelle")
		hab.rotation = Vector3.ZERO
	var pose := n.get_node_or_null("Pose") as Node3D
	if pose:
		pose.position = Vector3.ZERO
		pose.rotation = Vector3.ZERO


## Pose : "debout" (pieds en 0), "assis" (bassin sur l'assise en 0, jambes
## pliées vers +Z), "couche" (sur le dos, tête vers −Z, centré en 0).
static func poser(n: Node3D, pose_nom: String) -> void:
	repos(n)
	var rig := os(n)
	if rig.is_empty():
		return
	var pose := n.get_node("Pose") as Node3D
	var ech := float(n.get_meta("echelle", 1.0))
	var hanche := float(n.get_meta("hanche", 0.9))
	match pose_nom:
		"assis":
			for s in ["g", "d"]:
				(rig["jambe_" + s] as Node3D).rotation.x = -PI * 0.5
				(rig["tibia_" + s] as Node3D).rotation.x = PI * 0.5
				(rig["bras_" + s] as Node3D).rotation.x = -0.35
				(rig["avant_bras_" + s] as Node3D).rotation.x = -0.9
			(rig.bassin as Node3D).position.y = hanche * 0.09
			pose.position.z = -0.04 * ech
			# La jupe suit les cuisses au lieu de pendre au travers.
			(rig.habit as Node3D).rotation.x = -PI * 0.42
		"couche":
			pose.rotation.x = -PI * 0.5
			# Après la rotation, le corps va de z = 0 (pieds) à z = −taille.
			var taille := hanche / 0.5
			pose.position = Vector3(0, 0.13 * ech, taille * 0.52 * ech)
			for s in ["g", "d"]:
				(rig["bras_" + s] as Node3D).rotation.z = 0.12 if s == "g" else -0.12
			# La jupe retombe à plat au lieu de traverser le lit.
			var hab2 := rig.habit as Node3D
			hab2.scale = (hab2.get_meta("echelle") as Vector3) * Vector3(1.0, 1.0, 0.4)


## Balancement de marche : phase en radians (augmente avec la distance),
## ampleur 0 (arrêt) à 1 (pas normal), plus pour courir.
static func marcher(n: Node3D, phase: float, ampleur := 1.0) -> void:
	var rig := os(n)
	if rig.is_empty() or rig.get("jambe_g") == null:
		return
	var a := sin(phase) * 0.5 * ampleur
	var b := cos(phase)
	(rig.jambe_g as Node3D).rotation.x = a
	(rig.jambe_d as Node3D).rotation.x = -a
	(rig.tibia_g as Node3D).rotation.x = maxf(0.0, -b) * 0.6 * ampleur
	(rig.tibia_d as Node3D).rotation.x = maxf(0.0, b) * 0.6 * ampleur
	(rig.bras_g as Node3D).rotation.x = -a * 0.8
	(rig.bras_d as Node3D).rotation.x = a * 0.8
	(rig.avant_bras_g as Node3D).rotation.x = -0.15 * ampleur
	(rig.avant_bras_d as Node3D).rotation.x = -0.15 * ampleur
	(rig.bassin as Node3D).position.y = float(n.get_meta("hanche", 0.9)) + absf(sin(phase)) * 0.015 * ampleur


# --- Secours sans modèles importés --------------------------------------------------

## Même squelette en simples blocs (si les .glb ne sont pas encore importés).
static func _rig_blocs(parent: Node3D, rig: Dictionary) -> void:
	var bassin := _bloc_noeud(parent, "bassin", Vector3(0, 0.88, 0), Vector3(0.34, 0.2, 0.22), 3)
	rig.bassin = bassin
	rig.habit = _bloc_noeud(bassin, "habit", Vector3.ZERO, Vector3.ZERO, -1)
	var torse := _bloc_noeud(bassin, "torse", Vector3(0, 0.15, 0), Vector3(0.4, 0.5, 0.24), 2, 0.25)
	rig.torse = torse
	var tete := _bloc_noeud(torse, "tete", Vector3(0, 0.55, 0), Vector3(0.22, 0.26, 0.24), 0, 0.15)
	rig.tete = tete
	rig.cheveux = _bloc_noeud(tete, "cheveux", Vector3(0, 0.15, 0), Vector3.ZERO, -1)
	for s in ["g", "d"]:
		var x := 0.1 if s == "g" else -0.1
		var j := _bloc_noeud(bassin, "jambe_" + s, Vector3(x, 0, 0), Vector3(0.14, 0.42, 0.15), 3, -0.21)
		rig["jambe_" + s] = j
		rig["tibia_" + s] = _bloc_noeud(j, "tibia_" + s, Vector3(0, -0.42, 0), Vector3(0.12, 0.44, 0.13), 7, -0.22)
		var b := _bloc_noeud(torse, "bras_" + s, Vector3(x * 2.6, 0.45, 0), Vector3(0.1, 0.3, 0.1), 2, -0.15)
		rig["bras_" + s] = b
		var ab := _bloc_noeud(b, "avant_bras_" + s, Vector3(0, -0.3, 0), Vector3(0.09, 0.28, 0.09), 6, -0.14)
		rig["avant_bras_" + s] = ab
		rig["main_" + s] = _bloc_noeud(ab, "main_" + s, Vector3(0, -0.32, 0), Vector3.ZERO, -1)


static func _bloc_noeud(parent: Node3D, nom: String, pos: Vector3, taille: Vector3, role: int, decal := 0.0) -> Node3D:
	var n: Node3D
	if role < 0:
		n = Node3D.new()
	else:
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = taille
		mi.mesh = box
		n = mi
	n.name = nom
	n.position = pos
	parent.add_child(n)
	if role >= 0:
		# Le bloc pend sous l'articulation (decal) : on décale le maillage.
		var mi2 := n as MeshInstance3D
		var am := ArrayMesh.new()
		var arr := (mi2.mesh as BoxMesh).get_mesh_arrays()
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var uv := PackedVector2Array()
		for i in v.size():
			v[i].y += decal
			uv.append(Vector2((role + 0.5) / 8.0, 0.5 / 8.0))
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_TEX_UV] = uv
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		mi2.mesh = am
	return n
