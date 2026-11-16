class_name Education
extends RefCounted
## Le parcours scolaire des habitants et les diplômes qu'exigent les métiers
## (données des pays : SystemesScolaires).
##
## - Chaque ville suit le système scolaire de son pays réel (Suisse, France,
##   générique), modifiable par pays dans le panneau Éducation.
## - Degrés : école enfantine, primaire, secondaire I, puis à 15 ans
##   l'orientation : gymnase (maturité, bac), école de culture générale,
##   apprentissage dual chez un vrai employeur de la ville (CFC, CAP), école
##   de métiers à plein temps, ou rien. Puis HES, HEP, université ou EPF :
##   bachelor, master, doctorat.
## - Chaque bâtiment scolaire accueille certains degrés (`niveaux_type`) : la
##   crèche l'école enfantine, l'école la primaire, le collège le secondaire I,
##   le lycée (gymnase) le secondaire II, l'école professionnelle les
##   apprentis, la haute école les HES, la HEP les futurs enseignants,
##   l'université les étudiants. Sans collège, les élèves du secondaire I vont
##   à l'école primaire (classes à plusieurs degrés, moins de réussite). Sans
##   bâtiment du secondaire II ou du supérieur, on étudie dans une autre ville.
## - Métiers : certains exigent un diplôme (médecin, enseignant, ingénieur…).
##   Sans personne de qualifié, le poste reste vide : des frontaliers (si un
##   autre pays a une ville à moins de 60 km) ou des pendulaires viennent le
##   tenir. Les autres métiers embauchent sans diplôme, mais la production baisse.
## - Les logements étudiants (résidence universitaire) n'accueillent que des
##   étudiants, quand la ville a une haute école ou une université.

## Clés des champs ajoutés aux habitants (sauvegarde : CycleVie.pack).
const CHAMPS := ["fil", "fsec", "fdeb", "apm", "apf", "etc", "etdom", "ori", "nq"]
## Réussite des examens (avant la qualité de l'école).
const REUSSITE := {"oblig": 0.9, "gym": 0.95, "ecg": 0.9, "pro": 0.88, "cfc": 0.92, "afp": 0.95, "sup": 0.85}
## Classe à plusieurs degrés (élève du secondaire I dans une école primaire) : réussite en moins.
const MALUS_MULTI := 0.15
## Salaire d'un apprenti : part du salaire du métier.
const SALAIRE_APPRENTI := 0.25
## Apprentis gardés par leur entreprise formatrice à la fin.
const GARDES := 0.65
## Personne non qualifiée dans un métier qui exige un diplôme (non strict) : rendement.
const RENDEMENT_NON_QUALIFIE := 0.6
## Frontaliers : une ville d'un autre pays à moins de cette distance (m).
const RAYON_FRONTALIERS := 60000.0
## Part des postes vacants pourvue chaque jour, et au plus : frontaliers, pendulaires.
const RYTHME_EXTERNES := {"frontaliers": 0.3, "pendulaires": 0.15}
const PLAFOND_EXTERNES := {"frontaliers": 1.0, "pendulaires": 0.6}
## Arrivants en âge de travailler qui viennent pour un poste qualifié vacant.
const ARRIVANTS_ATTIRES := 0.3
## Trajet maximal (minutes, au double plus rien) selon le degré.
const SEUILS := {"enfantine": 15.0, "primaire": 15.0, "sec1": 25.0, "gym": 40.0, "ecg": 40.0, "pro": 45.0,
	"hes": 60.0, "hep": 60.0, "uni": 60.0}
const OBLIGATOIRES := ["enfantine", "primaire", "sec1"]

var pop: Population
## Système choisi par l'admin pour un pays : code -> "ch", "fr" ou "gen".
var choix := {}
## Travailleurs venus d'ailleurs : bid -> {métier: nombre}.
var externes := {}
## Origine des externes d'un bâtiment : bid -> "frontaliers" ou "pendulaires".
var origine := {}
## Nouvelles du jour (diplômes, apprentissages) pour le résumé.
var nouvelles := {"diplomes": 0, "apprentis": 0}

var _sys := {}
var _postes := {}
var _apprentis := {}
var _rend := {}
var _rend_v := -1
var _annee := 0
var _annee_t := -1
var _departs: Array = []
var _vacants := {}


func _init(p: Population) -> void:
	pop = p


# --- Système et année -----------------------------------------------------------------------

func annee() -> int:
	# Epoques.annee() lit l'horloge : gardée une seconde (appelée très souvent).
	var t := Time.get_ticks_msec() / 1000
	if t != _annee_t:
		_annee_t = t
		_annee = Epoques.annee()
	return _annee


func code_au_batiment(bid: int) -> String:
	if Pays.instance != null and pop.known.has(bid):
		var pos: Vector3 = pop.known[bid].pos
		return Pays.instance.code_au_point(pos.x, pos.z)
	return GameStart.pays.to_lower()


func systeme_du_code(code: String) -> String:
	if choix.has(code):
		return String(choix[code])
	return SystemesScolaires.systeme_du_pays(code)


func systeme_batiment(bid: int) -> String:
	if _sys.has(bid):
		return String(_sys[bid])
	var s := systeme_du_code(code_au_batiment(bid))
	_sys[bid] = s
	return s


func systeme(p: Dictionary) -> String:
	return systeme_batiment(pop.home_of(p))


func choisir_systeme(code: String, sys: String) -> void:
	if sys == "" or sys == SystemesScolaires.systeme_du_pays(code):
		choix.erase(code)
	else:
		choix[code] = sys
	_sys.clear()


## Bâtiments ajoutés ou démolis : systèmes et postes à revoir.
func oublier_batiments() -> void:
	_sys.clear()
	_postes.clear()
	_apprentis.clear()
	for bid in externes.keys():
		if not pop.known.has(bid):
			externes.erase(bid)
			origine.erase(bid)


## Tirage stable propre à l'habitant (même résultat à chaque appel).
static func _u(p: Dictionary, cle: String) -> float:
	return float(posmod(hash(str(int(p.id)) + cle), 100000)) / 100000.0


# --- Bâtiments scolaires --------------------------------------------------------------------

## Degrés accueillis par un type de bâtiment ([] : pas une école).
static func niveaux_type(type_id: String) -> Array:
	var t := BuildingCatalog.get_type(type_id)
	if t.has("niveaux"):
		return t.niveaux
	var keys := Metiers.keys_of(type_id)
	if not (keys.has("ecole") or keys.has("college") or keys.has("lycee") or keys.has("maternelle") or keys.has("universite")):
		return []
	for k in [type_id, String(t.get("base", ""))]:
		match k:
			"creche", "maternelle":
				return ["enfantine"]
			"college":
				return ["sec1"]
			"lycee":
				return ["gym", "ecg"]
			"universite":
				return ["uni"]
			"ecole_communale":
				return ["enfantine", "primaire", "sec1"]
	# Bâtiments de la bible des styles et créations : d'après leur nom.
	var nom := String(t.get("name", "")).to_lower()
	if nom.contains("universit") or nom.contains("campus"):
		return ["uni"]
	if nom.contains("lycée") or nom.contains("gymnase") or nom.contains("high school"):
		return ["gym", "ecg"]
	if nom.contains("collège") and not nom.contains("oxford"):
		return ["sec1"]
	if nom.contains("oxford"):
		return ["uni"]
	return ["enfantine", "primaire"]


func niveaux(bid: int) -> Array:
	if not pop.known.has(bid):
		return []
	var info: Dictionary = pop.known[bid]
	if not info.has("niv"):
		info.niv = niveaux_type(String(info.t))
	return info.niv


func accepte(bid: int, cyc: String) -> bool:
	return niveaux(bid).has(cyc)


## Degré que l'habitant doit fréquenter maintenant ("" : aucun).
func cycle(p: Dictionary) -> String:
	var st := pop.stage(p)
	match st:
		"eleve":
			if float(p.get("fsec", -1.0)) > pop.life_clock:
				return SystemesScolaires.cycle_filiere(String(p.get("fil", "")))
			var age := pop.age_years(p)
			var sys := systeme(p)
			var an := annee()
			var b := SystemesScolaires.bornes(sys, an)
			for c in OBLIGATOIRES:
				var r: Array = b[c]
				if age >= int(r[0]) and age < int(r[1]):
					return c if _u(p, c) < SystemesScolaires.taux_scolarisation(sys, c, an) else ""
			return ""
		"apprenti":
			return "pro"
		"etudiant":
			return String(p.get("etc", ""))
	return ""


func seuil(p: Dictionary) -> float:
	return float(SEUILS.get(cycle(p), 15.0))


## Élève en âge de scolarité qui n'a pas de place (compte « sans école »).
func sans_ecole(p: Dictionary) -> bool:
	if int(p.sch) >= 0 or pop.stage(p) != "eleve":
		return false
	return cycle(p) in OBLIGATOIRES


## Élève ou étudiant qui étudie dans une autre ville faute de bâtiment ici.
func ailleurs(p: Dictionary) -> bool:
	return bool(p.get("ext", false)) and int(p.sch) < 0


func nom_cycle(cyc: String, sys := "") -> String:
	return SystemesScolaires.nom_cycle(sys if sys != "" else "fr", cyc, annee())


## Classe ou année d'études : "5H", "CM1", "Gymnase, 2e année", "Bachelor HES, 1re année".
func classe(p: Dictionary) -> String:
	var cyc := cycle(p)
	var sys := systeme(p)
	if cyc in OBLIGATOIRES:
		return SystemesScolaires.classe(sys, cyc, pop.age_years(p), annee())
	if cyc in ["gym", "ecg"]:
		return SystemesScolaires.classe(sys, cyc, pop.age_years(p), annee(), int(p.get("fdeb", 15)))
	if pop.stage(p) == "apprenti":
		return "%s, %s" % [nom_apprentissage(p), SystemesScolaires.classe(sys, "pro", pop.age_years(p), annee(), int(p.get("fdeb", 15)))]
	if pop.stage(p) == "etudiant":
		return SystemesScolaires.nom_diplome(String(p.get("etd", "")) + (":" + String(p.etdom) if String(p.get("etdom", "")) != "" else ""))
	return nom_cycle(cyc, sys)


func nom_apprentissage(p: Dictionary) -> String:
	var m := String(p.get("apm", ""))
	var fil := String(p.get("fil", "cfc"))
	var sys := systeme(p)
	var dip := SystemesScolaires.diplome_filiere(sys, fil if fil != "" else "cfc", annee())
	var nom := SystemesScolaires.nom_diplome(dip).get_slice(" (", 0)
	if m == "":
		return "Apprentissage " + nom
	var metier := String(SystemesScolaires.NOMS_APPRENTISSAGE.get(m, String(Metiers.job(m).name).to_lower()))
	return "Apprentissage %s %s%s" % [nom, SystemesScolaires.de(metier), metier]


## Libellé de l'étape scolaire (fiche, liste) : "Élève (5H, École primaire (3H-8H))".
func libelle(p: Dictionary) -> String:
	var st := pop.stage(p)
	match st:
		"eleve":
			var cyc := cycle(p)
			if cyc == "":
				if String(p.get("fil", "")) in ["cfc", "afp"]:
					return "Cherche une place d'apprentissage"
				if pop.age_years(p) >= SystemesScolaires.age_orientation(systeme(p)):
					return "Jeune sans formation"
				return "Enfant (pas d'école à cet âge)"
			if int(p.sch) < 0:
				if ailleurs(p):
					return "Élève (%s, dans une autre ville)" % classe(p)
				return "Enfant sans école"
			return "Élève (%s%s)" % [classe(p), ", classe à plusieurs degrés" if bool(p.get("mult", false)) else ""]
		"apprenti":
			return "Apprenti%s (%s)" % [CycleVie.g(p, "", "e"), classe(p)]
		"etudiant":
			var ou := pop.building_name(int(p.sch)) if int(p.sch) >= 0 else "hors de la ville"
			return "Étudiant%s (%s, %s)" % [CycleVie.g(p, "", "e"), classe(p), ou]
	return ""


# --- Jalons de la vie scolaire (chaque jour de jeu, CycleVie) --------------------------------

## Diplômes de l'habitant (liste), avec les anciens champs remis d'aplomb.
static func diplomes(p: Dictionary) -> Array:
	if not p.has("dips"):
		p.dips = [String(p.dip)] if String(p.get("dip", "")) != "" else []
	return p.dips


func _obtenir(p: Dictionary, dip: String, texte := "") -> void:
	var dips := diplomes(p)
	if not dips.has(dip):
		dips.append(dip)
	p.dip = SystemesScolaires.meilleur(dips)
	nouvelles.diplomes = int(nouvelles.diplomes) + 1
	# Un employé qui obtient son diplôme devient qualifié pour son poste.
	if bool(p.get("nq", false)) and SystemesScolaires.qualifie(dips, String(p.met), annee()):
		p.nq = false
		_rend_v = -1
	pop.vie.log_event(p, "diplome", texte if texte != "" else "Obtient : %s" % SystemesScolaires.nom_diplome(dip))


## Réussite d'un examen selon la filière et l'école.
func _reussit(p: Dictionary, cle: String) -> bool:
	var r := float(REUSSITE.get(cle, 0.9))
	if bool(p.get("mult", false)):
		r -= MALUS_MULTI
	if int(p.sch) >= 0 and pop.effectif != null:
		var e := pop.effectif.etat(int(p.sch))
		if not e.is_empty() and bool(e.get("manque", false)):
			r -= 0.1
	return pop.rng.randf() < r


func jalons(p: Dictionary, a0: float, a: float) -> void:
	var sys := systeme(p)
	var an := annee()
	var clock := pop.life_clock
	# France avant 1989 : certificat d'études primaires vers 12-13 ans.
	if sys == "fr" and an < 1989 and a0 < 12.0 and a >= 12.0 and int(p.sch) >= 0 and pop.rng.randf() < 0.8:
		_obtenir(p, "cep", "Obtient le certificat d'études primaires")
	var ori := float(SystemesScolaires.age_orientation(sys))
	if a0 < ori and a >= ori and not bool(p.get("ori", false)):
		orienter(p, sys, an)
	elif a >= ori and not bool(p.get("ori", false)):
		# Habitant d'une ancienne sauvegarde : un jeune encore élève est orienté, un adulte garde son parcours.
		if a < float(Population.ADULT_AGE) and pop.stage(p) == "eleve":
			orienter(p, sys, an)
		else:
			p.ori = true
	# Fin du secondaire II à plein temps.
	if float(p.get("fsec", -1.0)) > 0.0 and clock >= float(p.fsec):
		_fin_secondaire(p, sys, an)
	# Apprenti sans place depuis plus d'un an : école de métiers à plein temps.
	if String(p.get("fil", "")) in ["cfc", "afp"] and float(p.get("apf", -1.0)) <= 0.0 and a >= ori + 1.0:
		p.fil = "pro" if an >= 1880 else ""
		if String(p.fil) == "pro":
			p.fsec = clock + SystemesScolaires.duree_filiere(sys, "pro") * 365.25
			p.fdeb = int(a)
			pop.vie.log_event(p, "ecole", "Sans place d'apprentissage, entre à plein temps : %s" % nom_cycle("pro", sys))
		else:
			pop.vie.log_event(p, "fin_emploi", "Ne trouve pas de maître d'apprentissage")
	# Fin de l'apprentissage.
	if float(p.get("apf", -1.0)) > 0.0 and clock >= float(p.apf):
		_fin_apprentissage(p, sys, an)
	# Fin des études supérieures.
	if float(p.get("etu", -1.0)) > 0.0 and clock >= float(p.etu):
		_fin_superieur(p, sys, an)
	# Formation continue : brevet ou maîtrise fédérale après un CFC (Suisse).
	if sys == "ch" and a >= 25.0 and a < 45.0 and pop.stage(p) == "actif" and SystemesScolaires.niveau_de(String(p.dip)) == 2 \
			and String(p.dip).begins_with("cfc") and pop.rng.randf() < 0.012 * (a - a0):
		var dom := SystemesScolaires.domaine_de(String(p.dip))
		_obtenir(p, ("maitrise_fed" if dom in ["artisanat", "bouche"] else "brevet_fed") + ":" + dom,
			"Obtient en cours d'emploi : %s" % SystemesScolaires.nom_diplome(("maitrise_fed" if dom in ["artisanat", "bouche"] else "brevet_fed") + ":" + dom))


## Fin du secondaire I : diplôme et filière.
func orienter(p: Dictionary, sys: String, an: int) -> void:
	p.ori = true
	var alle := String(p.get("niv", "")) != "" or int(p.sch) >= 0
	if alle and _reussit(p, "oblig"):
		var dob := SystemesScolaires.diplome_obligatoire(sys, an)
		if not (dob == "cert_fin" and an < 1874):
			_obtenir(p, dob, "Obtient : %s" % SystemesScolaires.nom_diplome(dob, an))
	var fil := SystemesScolaires.tirer_filiere(sys, an, _u(p, "ori"))
	# Sans école obligatoire, ni gymnase ni lycée.
	if not alle and fil in ["gym", "ecg", "pro"]:
		fil = "cfc" if sys != "gen" else "aucun"
	if String(p.get("joueur", "")) != "" and fil == "aucun":
		fil = "gym"
	if sys == "gen" and fil in ["cfc", "afp"]:
		fil = "pro"
	p.fil = fil
	p.fdeb = pop.age_years(p)
	match fil:
		"gym", "ecg", "pro":
			p.fsec = pop.life_clock + SystemesScolaires.duree_filiere(sys, fil) * 365.25
			pop.vie.log_event(p, "ecole", "Entre : %s (%d ans)" % [nom_cycle(fil, sys), int(SystemesScolaires.duree_filiere(sys, fil))])
		"cfc", "afp":
			pop.vie.log_event(p, "ecole", "Cherche une place d'apprentissage")
		_:
			p.fil = ""
			pop.vie.log_event(p, "fin_emploi", "Quitte l'école sans formation")


func _fin_secondaire(p: Dictionary, sys: String, an: int) -> void:
	var fil := String(p.get("fil", ""))
	p.fsec = -1.0
	p.fil = ""
	var dip := SystemesScolaires.diplome_filiere(sys, fil, an)
	if not _reussit(p, fil if REUSSITE.has(fil) else "gym"):
		pop.vie.log_event(p, "fin_emploi", "Échoue à l'examen final (%s)" % SystemesScolaires.nom_diplome(dip, an))
		return
	if fil == "pro":
		var m: String = SystemesScolaires.APPRENTISSAGES[posmod(hash(int(p.id)), SystemesScolaires.APPRENTISSAGES.size())]
		dip = "%s:%s:%s" % [dip, SystemesScolaires.DOMAINE_METIER.get(m, "technique"), m]
	_obtenir(p, dip, "Obtient : %s" % SystemesScolaires.nom_diplome(dip, an))
	var acces := SystemesScolaires.id_de(dip)
	if sys == "ch" and acces == "cert_ecg" and an >= 2004 and pop.rng.randf() < 0.4:
		_obtenir(p, "mat_spec:" + ("sante" if pop.rng.randf() < 0.5 else "social"))
		acces = "mat_spec"
	if SystemesScolaires.niveau_de(acces) < 3:
		return
	if String(p.get("joueur", "")) != "":
		pop.principal.ask_studies(p)
	elif pop.rng.randf() < SystemesScolaires.part_superieur(sys, an, acces):
		commencer_superieur(p, sys, an, acces)


func _fin_apprentissage(p: Dictionary, sys: String, an: int) -> void:
	var m := String(p.get("apm", ""))
	var fil := String(p.get("fil", "cfc"))
	p.apf = -1.0
	p.fil = ""
	var dip := "%s:%s:%s" % [SystemesScolaires.diplome_filiere(sys, fil, an), SystemesScolaires.DOMAINE_METIER.get(m, "technique"), m]
	var ok := _reussit(p, "afp" if fil == "afp" else "cfc")
	if ok:
		_obtenir(p, dip, "Obtient : %s" % SystemesScolaires.nom_diplome(dip, an))
		if sys == "ch" and fil == "cfc" and an >= 1994 and pop.rng.randf() < 0.2:
			_obtenir(p, "mat_pro:" + SystemesScolaires.domaine_de(dip))
			if pop.rng.randf() < SystemesScolaires.part_superieur(sys, an, "mat_pro"):
				pop._leave_job(p, "Termine son apprentissage et part étudier")
				commencer_superieur(p, sys, an, "mat_pro")
				return
	else:
		pop.vie.log_event(p, "fin_emploi", "Échoue à l'examen de fin d'apprentissage")
	p.nq = not ok
	if int(p.job) >= 0:
		oublier_postes(int(p.job))
	# Gardé seulement s'il reste un poste au personnel (les apprentis étaient en plus).
	if int(p.job) >= 0 and (pop.rng.randf() > GARDES or not ok or pop.free_jobs(int(p.job)) < 0):
		pop._leave_job(p, "Fin de l'apprentissage chez %s" % pop.building_name(int(p.job)))
	elif int(p.job) >= 0:
		pop.vie.log_event(p, "emploi", "Gardé%s par son entreprise formatrice (%s)" % [CycleVie.g(p, "", "e"), pop.building_name(int(p.job))], int(p.job))
	_rend_v = -1


## Commence des études supérieures après une maturité ou un bac.
func commencer_superieur(p: Dictionary, sys: String, an: int, acces: String) -> bool:
	var cursus := SystemesScolaires.cursus_superieurs(sys, an, acces)
	if cursus.is_empty():
		return false
	var tot := 0.0
	for c in cursus:
		tot += float(c[1])
	var x := pop.rng.randf() * tot
	var choisi: Array = cursus[0]
	for c in cursus:
		x -= float(c[1])
		if x < 0.0:
			choisi = c
			break
	var doms: Dictionary = choisi[4]
	var dt := 0.0
	for d in doms:
		dt += float(doms[d])
	var y := pop.rng.randf() * dt
	var dom := String(doms.keys()[0])
	for d in doms:
		y -= float(doms[d])
		if y < 0.0:
			dom = String(d)
			break
	commencer_cursus(p, String(choisi[0]), dom, float(choisi[2]), String(choisi[3]))
	return true


func commencer_cursus(p: Dictionary, id: String, dom: String, duree: float, cyc: String) -> void:
	p.etd = id
	p.etdom = dom if not SystemesScolaires.DIPLOMES.get(id, {}).has("dom") else ""
	p.etc = cyc
	p.etu = pop.life_clock + duree * 365.25
	var ou := "à l'université" if cyc == "uni" else ("en haute école" if cyc == "hes" else "en formation d'enseignant")
	pop.vie.log_event(p, "etudes", "Commence des études %s : %s (%s ans)" % [ou, SystemesScolaires.nom_diplome(id + (":" + dom if String(p.etdom) != "" else "")),
		String.num(duree, 1).trim_suffix(".0")])


## Choix du joueur pour son personnage (PersonnagePrincipal) : "id:dom:durée:cycle".
func choisir_etudes(p: Dictionary, arg: String) -> void:
	var parts := arg.split(":")
	if parts.size() >= 4:
		commencer_cursus(p, parts[0], parts[1], float(parts[2]), parts[3])
		return
	# Anciens choix : bts, licence, master.
	var dur: float = {"bts": 2.0, "licence": 3.0, "master": 5.0}.get(arg, 3.0)
	commencer_cursus(p, arg, "", dur, "hes" if arg == "bts" else "uni")


## Options d'études pour le personnage du joueur : [[texte, "etudes", arg], …].
func options_etudes(p: Dictionary) -> Array:
	var sys := systeme(p)
	var out := []
	var acces := SystemesScolaires.id_de(String(p.dip))
	for c in SystemesScolaires.cursus_superieurs(sys, annee(), acces):
		var doms: Dictionary = c[4]
		var dom := String(doms.keys()[0])
		var best := 0.0
		for d in doms:
			if float(doms[d]) > best:
				best = float(doms[d])
				dom = String(d)
		var id := String(c[0])
		var full := id + (":" + dom if not SystemesScolaires.DIPLOMES.get(id, {}).has("dom") else "")
		out.append(["%s (%s ans)" % [SystemesScolaires.nom_diplome(full), String.num(float(c[2]), 1).trim_suffix(".0")], "etudes",
			"%s:%s:%s:%s" % [id, dom, String.num(float(c[2])), c[3]]])
		if out.size() >= 4:
			break
	return out


func _fin_superieur(p: Dictionary, sys: String, an: int) -> void:
	var id := String(p.get("etd", ""))
	var dom := String(p.get("etdom", ""))
	p.etu = -1.0
	p.etd = ""
	p.etdom = ""
	var cyc := String(p.get("etc", ""))
	p.etc = ""
	if id == "":
		return
	var dip := id + (":" + dom if dom != "" else "")
	if not _reussit(p, "sup"):
		pop.vie.log_event(p, "fin_emploi", "Abandonne ses études (%s)" % SystemesScolaires.nom_diplome(dip, an))
		_apres_etudes(p)
		return
	_obtenir(p, dip, "Obtient : %s" % SystemesScolaires.nom_diplome(dip, an))
	var suite := SystemesScolaires.suite_cursus(id, an)
	if not suite.is_empty() and String(p.get("joueur", "")) == "" and pop.rng.randf() < float(suite[1]):
		var nid := String(suite[0])
		commencer_cursus(p, nid, dom if not SystemesScolaires.DIPLOMES.get(nid, {}).has("dom") else "", float(suite[2]),
			"uni" if nid.begins_with("doctorat") or nid.begins_with("master_uni") or nid == "master_fr" else cyc)
		return
	pop.vie.log_event(p, "emploi", "Termine ses études et cherche un emploi")
	_apres_etudes(p)


## Un étudiant de la résidence universitaire qui a fini s'en va : logement en
## ville s'il y en a un, sinon il quitte la ville.
func _apres_etudes(p: Dictionary) -> void:
	var home := pop.home_of(p)
	if not pop.known.has(home) or not bool(pop.known[home].get("etu", false)):
		return
	# Fait à la fin de la journée (la journée des habitants est en cours).
	if not _departs.has(int(p.id)):
		_departs.append(int(p.id))


## Étudiants diplômés de la résidence : un logement en ville, sinon ils partent.
func _faire_departs() -> void:
	for pid in _departs:
		if not pop.persons.has(pid):
			continue
		var home := pop.home_of(pop.persons[pid])
		if not pop.known.has(home) or not bool(pop.known[home].get("etu", false)) or pop.stage(pop.persons[pid]) == "etudiant":
			continue
		pop._move_out(pid, "Termine ses études et s'installe à %s")
		if pop.persons.has(pid) and pop.home_of(pop.persons[pid]) == home:
			pop._remove_person(pid, true, "Termine ses études et quitte la ville")
	_departs.clear()


# --- Apprentissage chez un employeur -------------------------------------------------------

## Apprenti qui cherche une place : signe chez l'employeur le plus proche qui
## forme à un de ses métiers. Rend true si un contrat est signé.
func chercher_apprentissage(p: Dictionary, jobs: Array) -> bool:
	if String(p.get("fil", "")) not in ["cfc", "afp"] or float(p.get("apf", -1.0)) > 0.0:
		return false
	var possibles := []
	for b in jobs:
		if apprentis_de(b) < places_apprentissage(b) and _metier_apprentissage(b, p) != "":
			possibles.append(b)
	if possibles.is_empty():
		return false
	var best := pop._nearest(pop.home_of(p), possibles)
	if best < 0:
		return false
	var m := _metier_apprentissage(best, p)
	var sys := systeme(p)
	var dur := SystemesScolaires.duree_filiere(sys, String(p.fil), m)
	if not pop._join_job(p, best, m):
		return false
	p.apm = m
	p.apf = pop.life_clock + dur * 365.25
	p.fdeb = pop.age_years(p)
	p.nq = true
	nouvelles.apprentis = int(nouvelles.apprentis) + 1
	pop.vie.log_event(p, "emploi", "Signe un contrat d'apprentissage (%s, %d ans) chez %s" % [nom_apprentissage(p).trim_prefix("Apprentissage "),
		int(dur), pop.building_name(best)], best)
	return true


func _metier_apprentissage(bid: int, p: Dictionary) -> String:
	var best := ""
	var best_u := INF
	for e in Metiers.jobs_for(String(pop.known[bid].t)) if pop.known.has(bid) else []:
		var m := String(e[0])
		if not SystemesScolaires.APPRENTISSAGES.has(m):
			continue
		var u := _u(p, "app" + String(m))
		if u < best_u:
			best_u = u
			best = String(m)
	return best


# --- Postes et qualifications ---------------------------------------------------------------

func qualifie(p: Dictionary, metier: String) -> bool:
	return SystemesScolaires.qualifie(diplomes(p), metier, annee())


## Postes d'un bâtiment par métier : {métier: {q: prévus, n: habitants, e: externes, libre}}.
func postes(bid: int) -> Dictionary:
	if _postes.has(bid):
		return _postes[bid]
	var out := {}
	if not pop.known.has(bid):
		return out
	var info: Dictionary = pop.known[bid]
	var emp := int(info.emp)
	var liste := Metiers.jobs_for(String(info.t))
	var tot := 0.0
	for e in liste:
		tot += float(e[1])
	var restes := []
	var pris := 0
	for e in liste:
		var m := String(e[0])
		var x := emp * float(e[1]) / maxf(tot, 1.0)
		var q := floori(x)
		out[m] = {"q": q, "n": 0, "e": 0, "libre": 0}
		pris += q
		restes.append([x - q, m])
	restes.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	var i := 0
	while pris < emp and i < restes.size():
		out[restes[i][1]].q = int(out[restes[i][1]].q) + 1
		pris += 1
		i += 1
	# Les métiers indispensables ont au moins une place.
	for m in Effectif.requis_de(String(info.t)):
		if out.has(m) and int(out[m].q) < 1 and emp > 0:
			out[m].q = 1
	var napp := 0
	for pid in pop.by_job.get(bid, []):
		if pop.persons.has(pid):
			# Les apprentis sont en plus du personnel (places d'apprentissage).
			if float(pop.persons[pid].get("apf", -1.0)) > pop.life_clock:
				napp += 1
				continue
			var m := String(pop.persons[pid].met)
			if not out.has(m):
				out[m] = {"q": 0, "n": 0, "e": 0, "libre": 0}
			out[m].n = int(out[m].n) + 1
	var ext: Dictionary = externes.get(bid, {})
	for m in ext:
		if not out.has(m):
			out[m] = {"q": 0, "n": 0, "e": 0, "libre": 0}
		out[m].e = int(ext[m])
	for m in out:
		out[m].libre = maxi(0, int(out[m].q) - int(out[m].n) - int(out[m].e))
	_postes[bid] = out
	_apprentis[bid] = napp
	return out


func oublier_postes(bid: int) -> void:
	_postes.erase(bid)
	_apprentis.erase(bid)


## Apprentis formés dans ce bâtiment (en plus de son personnel).
func apprentis_de(bid: int) -> int:
	if not _apprentis.has(bid):
		postes(bid)
	return int(_apprentis.get(bid, 0))


## Places d'apprentissage d'une entreprise formatrice : une pour huit postes (au moins une),
## seulement si l'un de ses métiers s'apprend.
func places_apprentissage(bid: int) -> int:
	if not pop.known.has(bid):
		return 0
	var info: Dictionary = pop.known[bid]
	if int(info.emp) <= 0 or bool(info.get("etu", false)):
		return 0
	for e in Metiers.jobs_for(String(info.t)):
		if SystemesScolaires.APPRENTISSAGES.has(String(e[0])):
			return maxi(1, int(info.emp) / 8)
	return 0


## Métier que l'habitant prendrait dans ce bâtiment ("" : aucun poste pour lui).
## [métier, qualifié].
func choisir_metier(p: Dictionary, bid: int) -> Array:
	var ps := postes(bid)
	var an := annee()
	var dips := diplomes(p)
	var ok := []
	var sans := []
	for m in ps:
		if int(ps[m].libre) <= 0:
			continue
		if SystemesScolaires.qualifie(dips, m, an):
			ok.append(m)
		elif not bool(SystemesScolaires.exigence(m, an).strict):
			sans.append(m)
	if not ok.is_empty():
		# Les plus diplômés prennent les postes les mieux payés.
		ok.sort_custom(func(a: String, b: String) -> bool:
			return int(Metiers.job(a).salaire) > int(Metiers.job(b).salaire))
		var niv := SystemesScolaires.niveau_de(String(p.get("dip", "")))
		if niv >= 5 or ok.size() == 1:
			return [ok[0], true]
		return [ok[pop.rng.randi() % ok.size()], true]
	if not sans.is_empty():
		return [sans[pop.rng.randi() % sans.size()], false]
	return ["", false]


func peut_travailler(p: Dictionary, bid: int) -> bool:
	return String(choisir_metier(p, bid)[0]) != ""


## Bâtiment qui a encore des postes sans diplôme obligatoire.
func a_postes_ouverts(bid: int) -> bool:
	var ps := postes(bid)
	var an := annee()
	for m in ps:
		if int(ps[m].libre) > 0 and not bool(SystemesScolaires.exigence(m, an).strict):
			return true
	return false


## Métier indispensable de ce bâtiment fermé que l'habitant peut tenir ("" : aucun).
func metier_requis_pour(p: Dictionary, bid: int) -> String:
	if not pop.known.has(bid):
		return ""
	for m in Effectif.requis_de(String(pop.known[bid].t)):
		if qualifie(p, String(m)):
			return String(m)
	return ""


func externes_de(bid: int) -> int:
	var n := 0
	var e: Dictionary = externes.get(bid, {})
	for m in e:
		n += int(e[m])
	return n


## Rendement d'une entreprise selon la qualification de son personnel (Production).
func rendement(bid: int) -> float:
	if _rend_v != pop.emplois_version:
		_rend.clear()
		_rend_v = pop.emplois_version
	if _rend.has(bid):
		return _rend[bid]
	var staff: Array = pop.by_job.get(bid, [])
	var r := 1.0
	if not staff.is_empty():
		var nq := 0
		for pid in staff:
			if pop.persons.has(pid) and bool(pop.persons[pid].get("nq", false)) and pop.stage(pop.persons[pid]) != "apprenti":
				nq += 1
		r = 1.0 - (1.0 - RENDEMENT_NON_QUALIFIE) * float(nq) / float(staff.size() + externes_de(bid))
	_rend[bid] = r
	return r


# --- Chaque jour : frontaliers et pendulaires -------------------------------------------

## Origine des travailleurs venus d'ailleurs pour ce bâtiment.
func bassin(bid: int) -> String:
	if Pays.instance == null or Communes.instance == null or not pop.known.has(bid):
		return "pendulaires"
	var pays := Pays.instance
	var cm := Communes.instance
	var vid := cm.village_de(bid)
	var nk := pays.nation_de(vid) if vid >= 0 else -1
	var pos: Vector3 = pop.known[bid].pos
	var p2 := Vector2(pos.x, pos.z)
	var r2 := RAYON_FRONTALIERS * RAYON_FRONTALIERS
	for v in cm.villages:
		if int(v) == vid or pays.nation_de(int(v)) == nk:
			continue
		if (cm.villages[v].c as Vector2).distance_squared_to(p2) <= r2:
			return "frontaliers"
	return "pendulaires"


func quotidien() -> void:
	_faire_departs()
	_vacants.clear()
	var an := annee()
	# Chômeurs diplômés (ils remplacent les externes), puis par métier à la demande.
	var dispo := []
	for pid in pop.persons:
		var p: Dictionary = pop.persons[pid]
		if pop.stage(p) != "chomeur":
			continue
		for d in diplomes(p):
			if SystemesScolaires.niveau_de(String(d)) >= 2:
				dispo.append(pid)
				break
	var pris := {}
	var par_metier := {}
	var change := false
	for bid in pop.known:
		var info: Dictionary = pop.known[bid]
		if int(info.emp) <= 0 or String(info.cat) == "logement" or Fondateurs.est_campement(bid):
			continue
		var ps := postes(bid)
		var b := ""
		var ext: Dictionary = externes.get(bid, {})
		for m in ps:
			var ex := SystemesScolaires.exigence(String(m), an)
			if not bool(ex.strict):
				continue
			# Des chômeurs qualifiés en ville : un externe s'en va, la place leur revient.
			if int(ext.get(m, 0)) > 0 and not dispo.is_empty():
				if not par_metier.has(m):
					par_metier[m] = dispo.filter(func(q: int) -> bool: return qualifie(pop.persons[q], String(m)))
				var l: Array = par_metier[m]
				while not l.is_empty() and pris.has(l[-1]):
					l.pop_back()
				if not l.is_empty():
					pris[l.pop_back()] = true
					ext[m] = int(ext[m]) - 1
					change = true
			var vacants := int(ps[m].q) - int(ps[m].n) - int(ext.get(m, 0))
			if vacants <= 0:
				continue
			if b == "":
				b = bassin(bid)
			var plafond := float(PLAFOND_EXTERNES[b]) * (0.3 if an < 1850 else 1.0)
			var deja := int(ext.get(m, 0))
			var max_ext := maxi(1, floori(float(ps[m].q) * plafond))
			var n := mini(vacants, maxi(1, ceili(vacants * float(RYTHME_EXTERNES[b]))))
			n = mini(n, max_ext - deja)
			if n > 0:
				ext[m] = deja + n
				change = true
		for m in ext.keys():
			if int(ext[m]) <= 0:
				ext.erase(m)
		if ext.is_empty():
			externes.erase(bid)
			origine.erase(bid)
		else:
			externes[bid] = ext
			if b != "":
				origine[bid] = b
	if change:
		_postes.clear()
		_apprentis.clear()
		pop.emplois_version += 1


# --- Nouveaux arrivants ------------------------------------------------------------------

## Passé scolaire d'un habitant qui emménage : diplômes de sa génération,
## filière en cours pour les jeunes. Certains viennent pour un poste qualifié vacant.
func arrivee(p: Dictionary, attires: Array = []) -> void:
	var sys := systeme(p)
	var an := annee()
	var a := pop.age_of(p)
	var ori := float(SystemesScolaires.age_orientation(sys))
	var nj := float(p.nj)
	if a < ori:
		return
	# Année où il avait 15 ans.
	var a15 := an - int(a - ori)
	var scol := _u(p, "sec1") < SystemesScolaires.taux_scolarisation(sys, "sec1", maxi(1800, a15)) \
		or _u(p, "primaire") < SystemesScolaires.taux_scolarisation(sys, "primaire", maxi(1800, a15 - 5))
	p.ori = true
	if scol and pop.rng.randf() < REUSSITE.oblig:
		var dob := SystemesScolaires.diplome_obligatoire(sys, a15)
		if not (dob == "cert_fin" and a15 < 1874):
			_passe(p, dob, nj + ori * 365.25, a15)
	var fil := SystemesScolaires.tirer_filiere(sys, maxi(1800, a15), _u(p, "ori"))
	if not scol and fil in ["gym", "ecg", "pro"]:
		fil = "cfc" if sys != "gen" else "aucun"
	if sys == "gen" and fil in ["cfc", "afp"]:
		fil = "pro"
	var dur := SystemesScolaires.duree_filiere(sys, fil)
	# Encore en formation : la filière continue ici.
	if fil != "aucun" and a < ori + dur:
		p.fil = fil
		p.fdeb = int(ori)
		if fil in ["gym", "ecg", "pro"]:
			p.fsec = pop.life_clock + (ori + dur - a) * 365.25
		return
	var acces := ""
	if fil != "aucun" and pop.rng.randf() < 0.9:
		var dip := SystemesScolaires.diplome_filiere(sys, fil, a15 + int(dur))
		if fil in ["cfc", "afp", "pro"]:
			var m: String = SystemesScolaires.APPRENTISSAGES[posmod(hash(int(p.id) * 7), SystemesScolaires.APPRENTISSAGES.size())]
			dip = "%s:%s:%s" % [dip, SystemesScolaires.DOMAINE_METIER.get(m, "technique"), m]
		_passe(p, dip, nj + (ori + dur) * 365.25, a15 + int(dur))
		acces = SystemesScolaires.id_de(dip)
		if sys == "ch" and fil == "cfc" and a15 + dur >= 1994 and pop.rng.randf() < 0.2:
			acces = "mat_pro"
			_passe(p, "mat_pro:" + SystemesScolaires.domaine_de(dip), nj + (ori + dur) * 365.25, a15 + int(dur))
	var t := ori + dur
	if SystemesScolaires.niveau_de(acces) >= 3 and pop.rng.randf() < SystemesScolaires.part_superieur(sys, a15 + int(dur), acces):
		var cursus := SystemesScolaires.cursus_superieurs(sys, a15 + int(dur), acces)
		if not cursus.is_empty():
			var tot := 0.0
			for c in cursus:
				tot += float(c[1])
			var x := pop.rng.randf() * tot
			var ch: Array = cursus[0]
			for c in cursus:
				x -= float(c[1])
				if x < 0.0:
					ch = c
					break
			var doms: Dictionary = ch[4]
			var dom := String(doms.keys()[pop.rng.randi() % doms.size()])
			var id := String(ch[0])
			var suffixe := ":" + dom if not SystemesScolaires.DIPLOMES.get(id, {}).has("dom") else ""
			var d := float(ch[2])
			if a < t + d:
				# Encore étudiant.
				p.etd = id
				p.etdom = suffixe.trim_prefix(":")
				p.etc = String(ch[3])
				p.etu = pop.life_clock + (t + d - a) * 365.25
				return
			_passe(p, id + suffixe, nj + (t + d) * 365.25, a15 + int(dur + d))
			t += d
			var suite := SystemesScolaires.suite_cursus(id, a15 + int(dur + d))
			while not suite.is_empty() and pop.rng.randf() < float(suite[1]) and a >= t + float(suite[2]):
				var nid := String(suite[0])
				var suf := suffixe if not SystemesScolaires.DIPLOMES.get(nid, {}).has("dom") else ""
				t += float(suite[2])
				_passe(p, nid + suf, nj + t * 365.25, a15 + int(t - ori))
				suite = SystemesScolaires.suite_cursus(nid, a15 + int(t - ori))
	# Venu pour un poste qualifié vacant.
	if not attires.is_empty() and a >= 24.0 and a < 60.0 and pop.rng.randf() < ARRIVANTS_ATTIRES:
		var m := String(attires[pop.rng.randi() % attires.size()])
		var ex := SystemesScolaires.exigence(m, an)
		if not qualifie(p, m):
			var dip := diplome_pour(sys, ex, m)
			if dip != "":
				_passe(p, dip, nj + minf(a - 1.0, 26.0) * 365.25, an - int(a - 26.0))


func _passe(p: Dictionary, dip: String, jour: float, an: int) -> void:
	var dips := diplomes(p)
	if not dips.has(dip):
		dips.append(dip)
	p.dip = SystemesScolaires.meilleur(dips)
	pop.vie.log_event(p, "diplome", "Obtient : %s" % SystemesScolaires.nom_diplome(dip, an), -1, jour)


## Un diplôme du système qui suffit à l'exigence ("" : aucun).
static func diplome_pour(sys: String, ex: Dictionary, metier := "") -> String:
	var niv := int(ex.niv)
	var dom := String(ex.dom)
	var d := dom if dom != "" else "general"
	var t := {
		"ch": {7: "doctorat_ch:" + d, 6: "master_uni:" + d, 5: "bachelor_hes:" + d, 4: "brevet_fed:" + d, 3: "mat_gym", 2: "cfc:%s:%s" % [d, metier], 1: "cert_fin"},
		"fr": {7: "doctorat_fr:" + d, 6: "master_fr:" + d, 5: "licence_fr:" + d, 4: "bts_fr:" + d, 3: "bac_gen", 2: "cap:%s:%s" % [d, metier], 1: "dnb"},
		"gen": {7: "doctorat_gen:" + d, 6: "master_gen:" + d, 5: "licence_gen:" + d, 4: "dip_tech:" + d, 3: "dip_sec", 2: "cert_pro:%s:%s" % [d, metier], 1: "cert_sec"},
	}
	if dom == "medecine":
		return {"ch": "dipl_med", "fr": "doct_med", "gen": "dip_med_gen"}.get(sys, "dip_med_gen")
	if dom == "enseignement":
		if niv >= 6:
			return {"ch": "master_hep", "fr": "master_meef", "gen": "master_gen:enseignement"}.get(sys, "")
		return {"ch": "bachelor_hep", "fr": "dip_pe", "gen": "dip_ens"}.get(sys, "")
	if dom == "sante" and niv == 5:
		return {"ch": "bachelor_hes:sante", "fr": "de_inf", "gen": "licence_gen:sante"}.get(sys, "")
	if niv <= 0:
		return ""
	return String(t.get(sys, t.gen).get(niv, ""))


## Métiers stricts dont des postes restent vacants dans la ville du bâtiment (arrivants attirés).
func postes_vacants_stricts(bid: int) -> Array:
	var cm := Communes.instance
	var vid := cm.village_de(bid) if cm != null else -1
	if _vacants.has(vid):
		return _vacants[vid]
	var out := []
	_vacants[vid] = out
	var an := annee()
	for b in externes:
		if cm != null and cm.village_de(b) != vid:
			continue
		for m in externes[b]:
			if not out.has(m):
				out.append(m)
	for b in pop.known:
		if int(pop.known[b].emp) <= 0 or (cm != null and cm.village_de(b) != vid):
			continue
		if pop.effectif != null and not pop.effectif.ferme(b):
			continue
		for m in Effectif.requis_de(String(pop.known[b].t)):
			if bool(SystemesScolaires.exigence(String(m), an).strict) and not out.has(m):
				out.append(m)
	return out


# --- Étudiants et résidences -----------------------------------------------------------

## Places libres pour des étudiants venus d'ailleurs dans la ville du bâtiment.
func places_etudiants(bid: int) -> int:
	var cm := Communes.instance
	var vid := cm.village_de(bid) if cm != null else -1
	var n := 0
	for b in pop.known:
		var nv := niveaux(b)
		if not (nv.has("uni") or nv.has("hes") or nv.has("hep")):
			continue
		if cm != null and cm.village_de(b) != vid:
			continue
		n += pop.free_seats(b)
	return n


## Nouvel étudiant de la résidence : maturité ou bac, études en cours dans la ville.
func nouvel_etudiant(p: Dictionary, bid: int) -> void:
	var sys := systeme(p)
	var an := annee()
	p.ori = true
	var acces := SystemesScolaires.diplome_filiere(sys, "gym", an)
	_passe(p, SystemesScolaires.diplome_obligatoire(sys, an), float(p.nj) + 15.0 * 365.25, an)
	_passe(p, acces, float(p.nj) + 18.5 * 365.25, an)
	# Cursus offert par les écoles de la ville.
	var cm := Communes.instance
	var vid := cm.village_de(bid) if cm != null else -1
	var offerts := []
	for b in pop.known:
		if (cm == null or cm.village_de(b) == vid) and pop.free_seats(b) > 0:
			for c in niveaux(b):
				if c in ["uni", "hes", "hep"] and not offerts.has(c):
					offerts.append(c)
	var cursus := SystemesScolaires.cursus_superieurs(sys, an, acces).filter(func(c: Array) -> bool: return offerts.has(String(c[3])))
	if cursus.is_empty():
		commencer_superieur(p, sys, an, acces)
		return
	var c: Array = cursus[pop.rng.randi() % cursus.size()]
	var doms: Dictionary = c[4]
	commencer_cursus(p, String(c[0]), String(doms.keys()[pop.rng.randi() % doms.size()]), float(c[2]), String(c[3]))
	# Déjà en cours d'études depuis un peu de temps.
	p.etu = float(p.etu) - pop.rng.randf_range(0.0, float(c[2]) - 0.5) * 365.25


# --- Migration des anciennes parties --------------------------------------------------------

## Après un chargement : les enseignants des collèges, lycées et universités
## prennent le métier de leur établissement (professeur…), sans perdre leur poste.
func migrer() -> void:
	for bid in pop.by_job:
		if not pop.known.has(bid):
			continue
		var req := Effectif.requis_de(String(pop.known[bid].t))
		if req.is_empty():
			continue
		var liste := []
		for e in Metiers.jobs_for(String(pop.known[bid].t)):
			liste.append(String(e[0]))
		for pid in pop.by_job[bid]:
			var p: Dictionary = pop.persons.get(pid, {})
			if not p.is_empty() and not liste.has(String(p.met)) and String(p.met) in ["enseignant", "atsem"]:
				p.met = String(req[0])
	_postes.clear()
	_apprentis.clear()


# --- Chiffres (panneau) -----------------------------------------------------------------

## Bilan d'une ville (vid, -1 : toute la carte).
func bilan(vid := -1) -> Dictionary:
	var cm := Communes.instance
	var out := {"cycles": {}, "niveaux": [0, 0, 0, 0, 0, 0, 0, 0], "apprentis": 0, "etudiants_ici": 0, "etudiants_ailleurs": 0,
		"eleves_ailleurs": 0, "sans_ecole": 0, "multi": 0, "adultes": 0, "non_qualifies": 0, "par_employeur": {}}
	for c in SystemesScolaires.CYCLES:
		out.cycles[c] = {"eleves": 0, "places": 0, "batiments": 0, "ailleurs": 0}
	for bid in pop.known:
		if vid >= 0 and cm != null and cm.village_de(bid) != vid:
			continue
		var nv := niveaux(bid)
		for c in nv:
			out.cycles[c].batiments = int(out.cycles[c].batiments) + 1
			out.cycles[c].places = int(out.cycles[c].places) + int(pop.known[bid].seats) / maxi(1, nv.size())
	for pid in pop.persons:
		var p: Dictionary = pop.persons[pid]
		if vid >= 0 and cm != null and cm.village_de(pop.home_of(p)) != vid:
			continue
		var st := pop.stage(p)
		var cyc := cycle(p)
		if cyc != "" and out.cycles.has(cyc):
			if int(p.sch) >= 0:
				out.cycles[cyc].eleves = int(out.cycles[cyc].eleves) + 1
			elif ailleurs(p):
				out.cycles[cyc].ailleurs = int(out.cycles[cyc].ailleurs) + 1
		if sans_ecole(p):
			out.sans_ecole += 1
		if bool(p.get("mult", false)) and int(p.sch) >= 0:
			out.multi += 1
		match st:
			"apprenti":
				out.apprentis += 1
				var j := int(p.job)
				if j >= 0:
					out.par_employeur[j] = int(out.par_employeur.get(j, 0)) + 1
			"etudiant":
				if int(p.sch) >= 0:
					out.etudiants_ici += 1
				else:
					out.etudiants_ailleurs += 1
			"eleve":
				if ailleurs(p):
					out.eleves_ailleurs += 1
			"actif", "chomeur", "retraite":
				out.adultes += 1
				out.niveaux[SystemesScolaires.niveau_de(String(p.dip))] += 1
				if st == "actif" and bool(p.get("nq", false)):
					out.non_qualifies += 1
	return out


## Pénuries : métiers stricts tenus par des externes ou vacants. [{metier, externes, vacants, origine}].
func penuries(vid := -1) -> Array:
	var cm := Communes.instance
	var an := annee()
	var par := {}
	for bid in pop.known:
		if vid >= 0 and cm != null and cm.village_de(bid) != vid:
			continue
		if int(pop.known[bid].emp) <= 0:
			continue
		var ps := postes(bid)
		for m in ps:
			if not bool(SystemesScolaires.exigence(String(m), an).strict):
				continue
			var vac := maxi(0, int(ps[m].q) - int(ps[m].n) - int(ps[m].e))
			if vac <= 0 and int(ps[m].e) <= 0:
				continue
			if not par.has(m):
				par[m] = {"metier": m, "externes": 0, "vacants": 0, "origine": String(origine.get(bid, "pendulaires"))}
			par[m].externes = int(par[m].externes) + int(ps[m].e)
			par[m].vacants = int(par[m].vacants) + vac
	var out := par.values()
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.externes) + int(a.vacants) > int(b.externes) + int(b.vacants))
	return out


# --- Sauvegarde -------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var ext := {}
	for bid in externes:
		ext[str(bid)] = externes[bid]
	var ori := {}
	for bid in origine:
		ori[str(bid)] = origine[bid]
	return {"choix": choix, "externes": ext, "origine": ori}


func from_dict(d: Dictionary) -> void:
	choix = {}
	var c: Dictionary = d.get("choix", {})
	for k in c:
		choix[String(k)] = String(c[k])
	externes = {}
	var ext: Dictionary = d.get("externes", {})
	for k in ext:
		var e := {}
		for m in ext[k]:
			e[String(m)] = int(ext[k][m])
		externes[int(k)] = e
	origine = {}
	var o: Dictionary = d.get("origine", {})
	for k in o:
		origine[int(k)] = String(o[k])
	_sys.clear()
	_postes.clear()
	_apprentis.clear()
	_rend_v = -1


## Champs d'un habitant pour la sauvegarde (CycleVie.pack).
static func pack(p: Dictionary, d: Dictionary) -> void:
	if (p.get("dips", []) as Array).size() > 0:
		d.dips = ",".join(p.dips)
	for k in ["fil", "apm", "etc", "etdom"]:
		if String(p.get(k, "")) != "":
			d[k] = p[k]
	for k in ["fsec", "apf"]:
		if float(p.get(k, -1.0)) > 0.0:
			d[k] = snappedf(float(p[k]), 0.01)
	if int(p.get("fdeb", 0)) > 0:
		d.fdeb = int(p.fdeb)
	if bool(p.get("ori", false)):
		d.ori = true
	if bool(p.get("nq", false)):
		d.nq = true


static func unpack(p: Dictionary, d: Dictionary) -> void:
	if d.has("dips"):
		p.dips = Array(String(d.dips).split(",", false))
	for k in ["fil", "apm", "etc", "etdom"]:
		p[k] = String(d.get(k, ""))
	for k in ["fsec", "apf"]:
		p[k] = float(d.get(k, -1.0))
	p.fdeb = int(d.get("fdeb", 0))
	p.ori = bool(d.get("ori", false))
	p.nq = bool(d.get("nq", false))
