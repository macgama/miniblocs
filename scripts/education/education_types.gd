class_name EducationTypes
extends RefCounted
## Bâtiments des degrés qui n'en avaient pas : école professionnelle (apprentis,
## CFC, CAP), haute école (HES, IUT ; technicum avant 1997), haute école
## pédagogique (école normale avant 2001) et résidence étudiante.
## L'école, le collège, le lycée (gymnase), la crèche et l'université sont
## déjà au catalogue (Education.niveaux_type dit qui y va).

## id -> [style, archétype, base, année, nom, description, réglages]
const DEFS := {
	"ecole_professionnelle": ["briques_ind", "ecole", "", 1880, "École professionnelle",
		"Cours des apprentis (CFC, CAP) un à deux jours par semaine, ateliers et laboratoires ; école de métiers à plein temps.",
		{"w": 52, "d": 34, "emplois": 60, "visiteurs": 900, "cost": 18_000_000, "niveaux": ["pro"]}],
	"technicum": ["briques_ind", "ecole", "haute_ecole", 1874, "Technicum",
		"École technique supérieure : ingénieurs ETS, architectes, chimistes.",
		{"w": 48, "d": 32, "emplois": 80, "visiteurs": 700, "cost": 12_000_000, "niveaux": ["hes"]}],
	"haute_ecole": ["verre", "ecole", "", 1997, "Haute école (HES, IUT)",
		"Bachelors et masters orientés vers la pratique : ingénierie, gestion, santé, social, arts.",
		{"w": 60, "d": 40, "emplois": 220, "visiteurs": 2000, "cost": 45_000_000, "niveaux": ["hes"]}],
	"ecole_normale": ["haussmann", "ecole", "haute_ecole_pedagogique", 1830, "École normale",
		"On y forme les instituteurs et institutrices, souvent avec un internat.",
		{"w": 36, "d": 26, "emplois": 30, "visiteurs": 300, "cost": 6_000_000, "niveaux": ["hep"]}],
	"haute_ecole_pedagogique": ["international", "ecole", "", 2001, "Haute école pédagogique (HEP)",
		"Bachelors et masters pour enseigner de l'école enfantine au secondaire (INSPÉ en France).",
		{"w": 44, "d": 30, "emplois": 120, "visiteurs": 1200, "cost": 25_000_000, "niveaux": ["hep"]}],
	"residence_etudiante": ["brutaliste", "immeuble", "", 1925, "Résidence étudiante",
		"Studios pour les étudiants de la haute école ou de l'université de la ville (et d'ailleurs).",
		{"w": 22, "d": 16, "logements": 80, "cost": 9_000_000, "etudiants": true, "cat": "logement"}],
}

## Métiers des établissements (prioritaires sur Metiers.PAR_BATIMENT).
const METIERS := {
	"ecole_professionnelle": [["enseignant_pro", 7], ["agent_public", 1], ["employe", 1]],
	"technicum": [["professeur", 6], ["laborantin", 1], ["employe", 1]],
	"haute_ecole": [["professeur", 6], ["chercheur", 1], ["laborantin", 1], ["employe", 1]],
	"ecole_normale": [["professeur", 5], ["agent_public", 1]],
	"haute_ecole_pedagogique": [["professeur", 6], ["chercheur", 1], ["employe", 1]],
	"college": [["professeur", 8], ["agent_public", 2]],
	"lycee": [["professeur", 9], ["agent_public", 2], ["cadre", 1]],
	"universite": [["professeur_universite", 5], ["chercheur", 3], ["employe", 2], ["cadre", 1]],
	"creche": [["educateur_enfance", 4], ["atsem", 1]],
}
## Métiers indispensables (Effectif.REQUIS).
const REQUIS := {
	"ecole_professionnelle": ["enseignant_pro"], "technicum": ["professeur"], "haute_ecole": ["professeur"],
	"ecole_normale": ["professeur"], "haute_ecole_pedagogique": ["professeur"], "college": ["professeur"],
	"lycee": ["professeur"], "universite": ["professeur_universite"], "creche": ["educateur_enfance"],
}


static func entries() -> Dictionary:
	var out := {}
	for id in DEFS:
		var d: Array = DEFS[id]
		if not Styles.STYLES.has(String(d[0])):
			continue
		var e := StyleBuilder.make_entry(String(d[0]), String(d[1]))
		e.name = String(d[4])
		e.desc = "%s (dès %d)" % [String(d[5]), int(d[3])]
		if String(d[2]) != "":
			e.base = String(d[2])
		if String(d[1]) == "ecole":
			e.role = "ecole"
		e.annee = int(d[3])
		e.region = "monde"
		e.access = ["route"]
		e.merge(d[6], true)
		if METIERS.has(id):
			e.metiers = METIERS[id]
		out[id] = e
	return out
