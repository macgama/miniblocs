class_name SystemesScolaires
extends RefCounted
## Les systèmes scolaires des pays : degrés, âges, classes, filières, diplômes
## et métiers qui les exigent, selon l'année de la partie (dès 1800).
##
## Trois systèmes :
## - "ch" Suisse (HarmoS dès 2009 : école obligatoire de 4 à 15 ans, 1H-11H ;
##   gymnase et maturité, apprentissage dual CFC chez un vrai employeur,
##   maturité professionnelle, HES, HEP, université et EPF bachelor-master-doctorat) ;
## - "fr" France (maternelle → collège et brevet, lycée et bac, lycée
##   professionnel ou CFA : CAP et bac pro, BTS, BUT, licence, master, doctorat) ;
## - "gen" générique (degrés de la CITE de l'UNESCO) pour les autres pays.
##
## Tout dépend de l'année (Epoques.annee()) : obligation scolaire (1874 en
## Suisse, 1882 en France), part des enfants scolarisés, filières et diplômes
## qui existent (CFC en 1933, maturité professionnelle en 1994, HES en 1997,
## Bologne en 2001…), exigences des métiers.
##
## Diplôme d'un habitant : chaîne "id:domaine:métier" (domaine et métier
## facultatifs), par exemple "cfc:bouche:boulanger" ou "master_uni:technique".
## Les anciens diplômes ("bac", "licence"…) restent valables, sans domaine
## (ils comptent pour tous les domaines).

const NOMS := {"ch": "Suisse", "fr": "France", "gen": "Générique (international)"}
## Pays réels (code ISO) → système. Les autres pays : "gen".
const PAR_PAYS := {"ch": "ch", "li": "ch", "fr": "fr", "mc": "fr", "ad": "fr", "re": "fr", "gp": "fr", "mq": "fr",
	"gf": "fr", "yt": "fr", "nc": "fr", "pf": "fr", "pm": "fr"}

## Niveaux de qualification : échelle commune aux trois systèmes.
const NIVEAUX := ["Aucun diplôme", "Scolarité obligatoire", "Formation professionnelle initiale",
	"Maturité, baccalauréat", "Bac+2, brevet fédéral, ES", "Bachelor, licence", "Master", "Doctorat"]

const DOMAINES := {
	"general": "culture générale", "commerce": "commerce et gestion", "technique": "technique et industrie",
	"artisanat": "artisanat et bâtiment", "bouche": "métiers de bouche", "hotellerie": "hôtellerie et restauration",
	"sante": "santé et soins", "medecine": "médecine et pharmacie", "social": "social et petite enfance",
	"enseignement": "enseignement", "agricole": "agriculture et nature", "arts": "arts et spectacle", "securite": "sécurité",
}

## Degrés (cycles) : identifiants communs ; les bâtiments disent lesquels ils accueillent.
const CYCLES := ["enfantine", "primaire", "sec1", "gym", "ecg", "pro", "hes", "hep", "uni"]
## Noms des degrés : [année de début, nom], le dernier dont l'année est passée l'emporte.
const NOMS_CYCLES := {
	"ch": {
		"enfantine": [[0, "École enfantine"], [2009, "École enfantine (1H-2H)"]],
		"primaire": [[0, "École primaire"], [2009, "École primaire (3H-8H)"]],
		"sec1": [[0, "École secondaire"], [2009, "Secondaire I (9H-11H)"]],
		"gym": [[0, "Collège classique (maturité)"], [1906, "Gymnase (maturité)"]],
		"ecg": [[0, "École de culture générale"]],
		"pro": [[0, "École d'arts et métiers"], [1933, "École professionnelle (CFC)"]],
		"hes": [[0, "Technicum"], [1997, "Haute école spécialisée (HES)"]],
		"hep": [[0, "École normale"], [2001, "Haute école pédagogique (HEP)"]],
		"uni": [[0, "Université"], [1855, "Université ou EPF"]],
	},
	"fr": {
		"enfantine": [[0, "Salle d'asile"], [1881, "École maternelle"]],
		"primaire": [[0, "École primaire"], [1969, "École élémentaire"]],
		"sec1": [[0, "École primaire supérieure"], [1941, "Cours complémentaire"], [1963, "Collège"]],
		"gym": [[0, "Lycée"], [1965, "Lycée général et technologique"]],
		"ecg": [[0, "Lycée"]],
		"pro": [[0, "École pratique d'industrie"], [1919, "Centre d'apprentissage"], [1985, "Lycée professionnel et CFA"]],
		"hes": [[0, "École d'arts et métiers"], [1966, "IUT, BTS et écoles d'ingénieurs"]],
		"hep": [[0, "École normale"], [1991, "IUFM"], [2013, "ESPE"], [2019, "INSPÉ"]],
		"uni": [[0, "Faculté"], [1896, "Université"]],
	},
	"gen": {
		"enfantine": [[0, "Préscolaire"]], "primaire": [[0, "École primaire"]], "sec1": [[0, "Secondaire inférieur"]],
		"gym": [[0, "Secondaire supérieur"]], "ecg": [[0, "Secondaire supérieur"]], "pro": [[0, "Formation professionnelle"]],
		"hes": [[0, "Institut supérieur"]], "hep": [[0, "École normale"]], "uni": [[0, "Université"]],
	},
}

## Diplômes : id -> {n: noms [année, nom], niv, dom ("" : celui du parcours), s: système}.
const DIPLOMES := {
	# Anciens diplômes (sauvegardes d'avant les systèmes par pays).
	"brevet": {"n": [[0, "Brevet élémentaire"], [1947, "BEPC"], [1987, "Brevet des collèges"]], "niv": 1, "s": "fr"},
	"bac": {"n": [[0, "Baccalauréat"]], "niv": 3, "s": "fr"},
	"bts": {"n": [[0, "BTS"]], "niv": 4, "s": "fr"},
	"licence": {"n": [[0, "Licence"]], "niv": 5, "s": "fr"},
	"master": {"n": [[0, "Maîtrise"], [2002, "Master"]], "niv": 6, "s": "fr"},
	# Suisse.
	"cert_fin": {"n": [[0, "Certificat d'émancipation scolaire"], [1960, "Certificat de fin de scolarité obligatoire"]], "niv": 1, "s": "ch", "dom": "general"},
	"afp": {"n": [[0, "Formation élémentaire"], [2004, "AFP (attestation fédérale)"]], "niv": 1, "s": "ch"},
	"cfc": {"n": [[0, "Apprentissage chez un maître"], [1880, "Certificat d'apprentissage cantonal"], [1933, "CFC (certificat fédéral de capacité)"]], "niv": 2, "s": "ch"},
	"cert_ecg": {"n": [[0, "Certificat d'école de culture générale"]], "niv": 2, "s": "ch", "dom": "social"},
	"mat_spec": {"n": [[0, "Maturité spécialisée"]], "niv": 3, "s": "ch"},
	"mat_pro": {"n": [[0, "Maturité professionnelle"]], "niv": 3, "s": "ch"},
	"mat_gym": {"n": [[0, "Certificat de maturité cantonal"], [1906, "Maturité fédérale"], [1995, "Maturité gymnasiale"]], "niv": 3, "s": "ch", "dom": "general"},
	"brevet_fed": {"n": [[0, "Maîtrise d'artisan"], [1933, "Brevet fédéral"]], "niv": 4, "s": "ch"},
	"maitrise_fed": {"n": [[0, "Maîtrise fédérale"]], "niv": 4, "s": "ch"},
	"dipl_ets": {"n": [[0, "Diplôme de technicien"], [1874, "Diplôme d'ingénieur ETS"]], "niv": 4, "s": "ch"},
	"brevet_ens": {"n": [[0, "Brevet d'enseignement (école normale)"]], "niv": 3, "s": "ch", "dom": "enseignement"},
	"bachelor_hes": {"n": [[0, "Bachelor HES"]], "niv": 5, "s": "ch"},
	"master_hes": {"n": [[0, "Master HES"]], "niv": 6, "s": "ch"},
	"bachelor_hep": {"n": [[0, "Bachelor HEP (enseignement primaire)"]], "niv": 5, "s": "ch", "dom": "enseignement"},
	"master_hep": {"n": [[0, "Master HEP (enseignement secondaire)"]], "niv": 6, "s": "ch", "dom": "enseignement"},
	"lic_uni": {"n": [[0, "Licence universitaire"]], "niv": 5, "s": "ch"},
	"bachelor_uni": {"n": [[0, "Bachelor universitaire"]], "niv": 5, "s": "ch"},
	"master_uni": {"n": [[0, "Master universitaire"]], "niv": 6, "s": "ch"},
	"dipl_med": {"n": [[0, "Diplôme fédéral de médecin"]], "niv": 6, "s": "ch", "dom": "medecine"},
	"doctorat_ch": {"n": [[0, "Doctorat"]], "niv": 7, "s": "ch"},
	# France.
	"cep": {"n": [[0, "Certificat d'études primaires"]], "niv": 1, "s": "fr", "dom": "general"},
	"dnb": {"n": [[0, "BEPC"], [1987, "Diplôme national du brevet"]], "niv": 1, "s": "fr", "dom": "general"},
	"cap": {"n": [[0, "Certificat d'apprentissage"], [1919, "CAP"]], "niv": 2, "s": "fr"},
	"bac_gen": {"n": [[0, "Baccalauréat"], [1995, "Baccalauréat général"]], "niv": 3, "s": "fr", "dom": "general"},
	"bac_pro": {"n": [[0, "Baccalauréat professionnel"]], "niv": 3, "s": "fr"},
	"bts_fr": {"n": [[0, "BTS"]], "niv": 4, "s": "fr"},
	"dut": {"n": [[0, "DUT"]], "niv": 4, "s": "fr"},
	"but": {"n": [[0, "BUT (bachelor universitaire de technologie)"]], "niv": 5, "s": "fr"},
	"de_inf": {"n": [[0, "Diplôme d'État d'infirmier"]], "niv": 5, "s": "fr", "dom": "sante"},
	"ingenieur": {"n": [[0, "Diplôme d'ingénieur"]], "niv": 6, "s": "fr", "dom": "technique"},
	"brevet_sup": {"n": [[0, "Brevet supérieur (école normale)"]], "niv": 3, "s": "fr", "dom": "enseignement"},
	"dip_pe": {"n": [[0, "Diplôme de professeur des écoles"]], "niv": 5, "s": "fr", "dom": "enseignement"},
	"master_meef": {"n": [[0, "Master MEEF (métiers de l'enseignement)"]], "niv": 6, "s": "fr", "dom": "enseignement"},
	"licence_fr": {"n": [[0, "Licence"]], "niv": 5, "s": "fr"},
	"master_fr": {"n": [[0, "DEA ou DESS"], [2002, "Master"]], "niv": 6, "s": "fr"},
	"doct_med": {"n": [[0, "Doctorat en médecine"]], "niv": 7, "s": "fr", "dom": "medecine"},
	"doctorat_fr": {"n": [[0, "Doctorat"]], "niv": 7, "s": "fr"},
	# Générique.
	"cert_sec": {"n": [[0, "Certificat d'études secondaires"]], "niv": 1, "s": "gen", "dom": "general"},
	"cert_pro": {"n": [[0, "Certificat professionnel"]], "niv": 2, "s": "gen"},
	"dip_sec": {"n": [[0, "Diplôme de fin d'études secondaires"]], "niv": 3, "s": "gen", "dom": "general"},
	"dip_tech": {"n": [[0, "Diplôme technique supérieur"]], "niv": 4, "s": "gen"},
	"dip_ens": {"n": [[0, "Diplôme d'enseignant"]], "niv": 5, "s": "gen", "dom": "enseignement"},
	"licence_gen": {"n": [[0, "Licence"], [1999, "Bachelor"]], "niv": 5, "s": "gen"},
	"master_gen": {"n": [[0, "Master"]], "niv": 6, "s": "gen"},
	"dip_med_gen": {"n": [[0, "Diplôme de médecin"]], "niv": 6, "s": "gen", "dom": "medecine"},
	"doctorat_gen": {"n": [[0, "Doctorat"]], "niv": 7, "s": "gen"},
}

## Ce qu'exige chaque métier : [niveau, domaine ("" : tous), strict, année].
## Strict : sans le diplôme, pas d'embauche (le poste reste vide, des
## frontaliers ou des pendulaires le prennent). Sinon on embauche quand même,
## mais la personne non qualifiée travaille moins bien (production réduite).
## Avant l'année donnée, le métier n'exige rien.
const EXIGENCES := {
	"boulanger": [2, "bouche", false, 1880], "meunier": [2, "bouche", false, 1900], "boucher": [2, "bouche", false, 1880],
	"cuisinier": [2, "hotellerie", false, 1900], "receptionniste": [2, "hotellerie", false, 1950],
	"employe": [2, "commerce", false, 1900], "conseiller_funeraire": [2, "commerce", false, 1960], "conseiller_sejour": [2, "commerce", false, 1960],
	"cadre": [5, "", false, 1900], "producteur": [5, "", false, 1950], "conservateur": [6, "general", false, 1900],
	"ingenieur": [5, "technique", true, 1880], "artisan": [2, "artisanat", false, 1880], "menuisier": [2, "artisanat", false, 1880],
	"couturier": [2, "artisanat", false, 1900], "decorateur": [2, "artisanat", false, 1950],
	"agriculteur": [2, "agricole", false, 1950], "eleveur": [2, "agricole", false, 1950], "maraicher": [2, "agricole", false, 1950],
	"jardinier": [2, "agricole", false, 1950], "soigneur_animalier": [2, "agricole", false, 1950],
	"agent_public": [1, "", false, 1900], "pompier": [1, "", false, 1900], "agent_gare": [1, "", false, 1900],
	"enseignant": [5, "enseignement", true, 1834], "atsem": [2, "social", false, 1960], "educateur_enfance": [2, "social", false, 1960],
	"professeur": [6, "", true, 1808], "enseignant_pro": [4, "", true, 1930], "professeur_universite": [7, "", true, 1800],
	"chercheur": [7, "", true, 1800],
	"policier": [2, "", true, 1900],
	"medecin": [6, "medecine", true, 1803], "pharmacien": [6, "medecine", true, 1803], "veterinaire_zoo": [6, "medecine", true, 1850],
	"infirmier": [5, "sante", true, 1922], "aide_soignant": [2, "sante", false, 1950], "thanatopracteur": [3, "sante", false, 1976],
	"laborantin": [2, "technique", false, 1950], "operateur": [2, "technique", false, 1950], "mecanicien": [2, "technique", false, 1920],
	"conducteur_engins": [2, "technique", false, 1950], "foreur": [2, "technique", false, 1950], "boutefeu": [2, "technique", true, 1950],
	"operateur_crematorium": [2, "technique", false, 1960], "technicien_attraction": [2, "technique", false, 1960],
	"technicien_zoo": [2, "technique", false, 1960], "technicien_spectacle": [2, "technique", false, 1960],
	"technicien_plateau": [2, "technique", false, 1960], "regisseur": [2, "arts", false, 1960], "monteur": [2, "arts", false, 1960],
	"realisateur": [3, "arts", false, 1960], "guide_conferencier": [3, "", false, 1950], "animateur_zoo": [3, "", false, 1970],
	"maitre_nageur": [2, "", false, 1951],
}
## Exigences plus faibles avant une réforme : métier -> [[année, niveau], …] (avant l'année : ce niveau).
const AVANT := {
	"enseignant": [[2001, 3]], "professeur": [[2001, 5]], "infirmier": [[2002, 4]], "ingenieur": [[1930, 4]],
}
## Domaine appris en apprentissage, selon le métier de l'employeur.
const DOMAINE_METIER := {
	"boulanger": "bouche", "boucher": "bouche", "meunier": "bouche", "cuisinier": "hotellerie", "serveur": "hotellerie",
	"receptionniste": "hotellerie", "agent_etage": "hotellerie",
	"vendeur": "commerce", "caissier": "commerce", "employe": "commerce", "magasinier": "commerce", "chauffeur": "commerce",
	"conseiller_funeraire": "commerce", "conseiller_sejour": "commerce", "agent_accueil_parc": "commerce",
	"artisan": "artisanat", "menuisier": "artisanat", "ouvrier_btp": "artisanat", "couturier": "artisanat", "decorateur": "artisanat",
	"ouvrier": "technique", "mecanicien": "technique", "operateur": "technique", "laborantin": "technique", "siderurgiste": "technique",
	"conducteur_engins": "technique", "foreur": "technique", "carrier": "technique", "mineur": "technique",
	"technicien_attraction": "technique", "technicien_zoo": "technique", "technicien_spectacle": "technique", "technicien_plateau": "technique",
	"agriculteur": "agricole", "eleveur": "agricole", "maraicher": "agricole", "jardinier": "agricole", "bucheron": "agricole",
	"soigneur_animalier": "agricole", "palefrenier": "agricole", "pecheur": "agricole",
	"aide_soignant": "sante", "atsem": "social", "educateur_enfance": "social", "monteur": "arts", "regisseur": "arts",
}
## Métiers qu'on apprend en apprentissage (CFC, CAP) chez un employeur.
const APPRENTISSAGES := ["boulanger", "boucher", "meunier", "cuisinier", "serveur", "receptionniste", "vendeur", "employe",
	"magasinier", "artisan", "menuisier", "ouvrier_btp", "couturier", "mecanicien", "operateur", "laborantin", "agriculteur",
	"eleveur", "maraicher", "jardinier", "aide_soignant", "atsem", "educateur_enfance", "conducteur_engins", "technicien_spectacle",
	"bucheron", "decorateur"]
## Noms des formations par apprentissage (Suisse : CFC officiels).
const NOMS_APPRENTISSAGE := {
	"aide_soignant": "assistant·e en soins et santé communautaire (ASSC)", "atsem": "assistant·e socio-éducatif·ve (ASE)",
	"educateur_enfance": "assistant·e socio-éducatif·ve (ASE)", "employe": "employé·e de commerce",
	"vendeur": "gestionnaire du commerce de détail", "magasinier": "logisticien·ne", "operateur": "polymécanicien·ne",
	"ouvrier_btp": "maçon·ne", "artisan": "artisan·e du bois",
}

## Âge de fin de la scolarité obligatoire et bornes des degrés selon l'année.
## Rend {enfantine: [de, à[, primaire, sec1, oblig: [de, à[ (vide : pas d'obligation)}.
static func bornes(sys: String, annee: int) -> Dictionary:
	match sys:
		"ch":
			if annee >= 2009:
				return {"enfantine": [4, 6], "primaire": [6, 12], "sec1": [12, 15], "oblig": [4, 15]}
			if annee >= 1874:
				return {"enfantine": [5, 6], "primaire": [6, 12], "sec1": [12, 15], "oblig": [6, 15]}
			return {"enfantine": [5, 7], "primaire": [7, 12], "sec1": [12, 15], "oblig": [7, 13]}
		"fr":
			var o: Array = []
			if annee >= 2019:
				o = [3, 16]
			elif annee >= 1959:
				o = [6, 16]
			elif annee >= 1936:
				o = [6, 14]
			elif annee >= 1882:
				o = [6, 13]
			return {"enfantine": [3, 6], "primaire": [6, 11], "sec1": [11, 15], "oblig": o}
	var g: Array = []
	if annee >= 1950:
		g = [6, 15]
	elif annee >= 1900:
		g = [6, 12]
	return {"enfantine": [4, 6], "primaire": [6, 12], "sec1": [12, 15], "oblig": g}


## Âge de fin du secondaire I (orientation : gymnase, apprentissage…).
static func age_orientation(sys: String) -> int:
	return 15


## Parts d'une génération : [année, valeur] interpolées.
static func _interp(table: Array, annee: int) -> float:
	if table.is_empty():
		return 0.0
	if annee <= int(table[0][0]):
		return float(table[0][1])
	for i in range(1, table.size()):
		if annee <= int(table[i][0]):
			var a: Array = table[i - 1]
			var b: Array = table[i]
			var t := float(annee - int(a[0])) / maxf(1.0, float(int(b[0]) - int(a[0])))
			return lerpf(float(a[1]), float(b[1]), t)
	return float(table[-1][1])


## Part des enfants qui vont à l'école de ce degré (avant l'obligation : moins).
const SCOLARISATION := {
	"ch": {"enfantine": [[1800, 0.0], [1900, 0.3], [1960, 0.75], [2008, 0.95], [2009, 1.0]],
		"primaire": [[1800, 0.55], [1874, 0.95], [1900, 1.0]], "sec1": [[1800, 0.1], [1900, 0.45], [1950, 0.85], [1970, 1.0]]},
	"fr": {"enfantine": [[1800, 0.0], [1881, 0.2], [1950, 0.5], [1980, 0.95], [2019, 1.0]],
		"primaire": [[1800, 0.35], [1850, 0.6], [1881, 0.85], [1882, 1.0]], "sec1": [[1800, 0.03], [1900, 0.08], [1936, 0.3], [1960, 0.6], [1975, 1.0]]},
	"gen": {"enfantine": [[1900, 0.0], [1950, 0.2], [2000, 0.6], [2020, 0.8]],
		"primaire": [[1800, 0.2], [1900, 0.6], [1950, 0.9], [2000, 1.0]], "sec1": [[1800, 0.02], [1950, 0.5], [2000, 0.9], [2020, 0.95]]},
}

static func taux_scolarisation(sys: String, cyc: String, annee: int) -> float:
	var t: Dictionary = SCOLARISATION.get(sys, SCOLARISATION.gen)
	var b := bornes(sys, annee)
	var r := _interp(t.get(cyc, []), annee)
	# Âge obligatoire : tout le monde.
	var o: Array = b.oblig
	if not o.is_empty():
		var c: Array = b[cyc]
		if int(c[0]) >= int(o[0]) and int(c[1]) <= int(o[1]):
			r = 1.0
	return clampf(r, 0.0, 1.0)


## Orientation à la fin du secondaire I : parts de chaque filière selon l'année.
## gym (maturité, bac général), ecg, cfc (apprentissage chez un employeur),
## pro (école de métiers ou lycée professionnel à plein temps), afp, aucun.
const ORIENTATION := {
	"ch": [
		[1800, {"gym": 0.02, "cfc": 0.15, "aucun": 0.83}],
		[1900, {"gym": 0.04, "cfc": 0.35, "aucun": 0.61}],
		[1950, {"gym": 0.07, "cfc": 0.6, "pro": 0.03, "aucun": 0.3}],
		[1980, {"gym": 0.13, "ecg": 0.04, "cfc": 0.68, "pro": 0.05, "aucun": 0.1}],
		[2010, {"gym": 0.21, "ecg": 0.06, "cfc": 0.58, "pro": 0.06, "afp": 0.04, "aucun": 0.05}],
	],
	"fr": [
		[1800, {"gym": 0.01, "cfc": 0.15, "aucun": 0.84}],
		[1900, {"gym": 0.02, "cfc": 0.2, "pro": 0.03, "aucun": 0.75}],
		[1950, {"gym": 0.08, "cfc": 0.2, "pro": 0.15, "aucun": 0.57}],
		[1980, {"gym": 0.35, "cfc": 0.12, "pro": 0.35, "aucun": 0.18}],
		[2010, {"gym": 0.6, "cfc": 0.1, "pro": 0.25, "aucun": 0.05}],
	],
	"gen": [
		[1800, {"gym": 0.01, "pro": 0.05, "aucun": 0.94}],
		[1900, {"gym": 0.03, "pro": 0.1, "aucun": 0.87}],
		[1950, {"gym": 0.15, "pro": 0.25, "aucun": 0.6}],
		[2000, {"gym": 0.5, "pro": 0.3, "aucun": 0.2}],
		[2020, {"gym": 0.6, "pro": 0.3, "aucun": 0.1}],
	],
}

static func parts_orientation(sys: String, annee: int) -> Dictionary:
	var t: Array = ORIENTATION.get(sys, ORIENTATION.gen)
	var out := {}
	for k in ["gym", "ecg", "cfc", "pro", "afp", "aucun"]:
		var col := []
		for e in t:
			col.append([int(e[0]), float((e[1] as Dictionary).get(k, 0.0))])
		out[k] = _interp(col, annee)
	if sys == "ch" and annee < 2004:
		out.aucun = float(out.aucun) + float(out.afp)
		out.afp = 0.0
	if sys == "ch" and annee < 1965:
		out.gym = float(out.gym) + float(out.ecg)
		out.ecg = 0.0
	return out


## Tire une filière (u dans [0, 1[).
static func tirer_filiere(sys: String, annee: int, u: float) -> String:
	var parts := parts_orientation(sys, annee)
	var tot := 0.0
	for k in parts:
		tot += float(parts[k])
	var x := u * tot
	for k in ["gym", "ecg", "cfc", "pro", "afp", "aucun"]:
		x -= float(parts[k])
		if x < 0.0:
			return k
	return "aucun"


## Durée (années) d'une filière du secondaire II.
static func duree_filiere(sys: String, fil: String, metier := "") -> float:
	match fil:
		"gym":
			return 4.0 if sys == "ch" else 3.0
		"ecg":
			return 3.0
		"afp":
			return 2.0
		"cfc", "pro":
			if sys == "ch":
				return 4.0 if DOMAINE_METIER.get(metier, "") == "technique" else 3.0
			return 2.0 if sys == "fr" and fil == "cfc" else 3.0
	return 3.0


## Degré d'une filière du secondaire II (bâtiment fréquenté).
static func cycle_filiere(fil: String) -> String:
	match fil:
		"gym":
			return "gym"
		"ecg":
			return "ecg"
		"cfc", "pro", "afp":
			return "pro"
	return ""


## Diplôme de fin de filière : id (le domaine est donné à part).
static func diplome_filiere(sys: String, fil: String, annee: int) -> String:
	match sys:
		"ch":
			match fil:
				"gym":
					return "mat_gym"
				"ecg":
					return "cert_ecg"
				"afp":
					return "afp"
				"cfc", "pro":
					return "cfc"
		"fr":
			match fil:
				"gym":
					return "bac_gen"
				"cfc", "pro", "afp":
					return "bac_pro" if annee >= 1985 and fil == "pro" else "cap"
	match fil:
		"gym":
			return "dip_sec"
	return "cert_pro"


## Diplôme de fin de scolarité obligatoire.
static func diplome_obligatoire(sys: String, annee: int) -> String:
	match sys:
		"ch":
			return "cert_fin"
		"fr":
			return "dnb" if annee >= 1947 else "cep"
	return "cert_sec"


## Cursus du supérieur possibles : [id, poids, durée, cycle, domaines {dom: poids}].
## Après une maturité / un bac, selon le système, l'année et le diplôme d'accès.
static func cursus_superieurs(sys: String, annee: int, acces: String) -> Array:
	var out := []
	var dom_uni := {"general": 35, "technique": 20, "commerce": 15, "medecine": 10, "sante": 4, "social": 6, "arts": 4, "enseignement": 6}
	var dom_hes := {"technique": 35, "commerce": 30, "sante": 20, "social": 10, "arts": 5}
	match sys:
		"ch":
			var bologne := annee >= 2001
			if acces in ["mat_gym", "bac", "bac_gen", "dip_sec"]:
				if bologne:
					out.append(["bachelor_uni", 60, 3.0, "uni", dom_uni])
					out.append(["dipl_med", 8, 6.0, "uni", {"medecine": 1}])
				else:
					out.append(["lic_uni", 62, 4.0, "uni", dom_uni])
					out.append(["dipl_med", 8, 6.0, "uni", {"medecine": 1}])
				out.append(["bachelor_hep" if bologne else "brevet_ens", 10, 3.0, "hep", {"enseignement": 1}])
				out.append(["bachelor_hes" if annee >= 1997 else "dipl_ets", 12, 3.0, "hes", dom_hes])
			elif acces in ["mat_pro", "mat_spec"]:
				if annee >= 1997:
					out.append(["bachelor_hes", 70, 3.0, "hes", dom_hes if acces == "mat_pro" else {"sante": 60, "social": 40}])
				out.append(["bachelor_hep" if bologne else "brevet_ens", 10, 3.0, "hep", {"enseignement": 1}])
		"fr":
			if acces in ["bac", "bac_gen", "bac_pro", "mat_gym", "dip_sec"]:
				var pro := acces == "bac_pro"
				if annee >= 1959:
					out.append(["bts_fr", 45 if pro else 14, 2.0, "hes", dom_hes])
				if annee >= 2021:
					out.append(["but", 5 if pro else 10, 3.0, "hes", {"technique": 60, "commerce": 40}])
				elif annee >= 1966:
					out.append(["dut", 5 if pro else 10, 2.0, "hes", {"technique": 60, "commerce": 40}])
				if not pro:
					out.append(["licence_fr", 40, 3.0, "uni", dom_uni])
					out.append(["ingenieur", 7, 5.0, "hes", {"technique": 1}])
					out.append(["doct_med", 7, 9.0, "uni", {"medecine": 1}])
					if annee >= 1922:
						out.append(["de_inf", 6, 3.0, "hes", {"sante": 1}])
					out.append(["master_meef" if annee >= 2010 else ("dip_pe" if annee >= 1991 else "brevet_sup"), 6,
						5.0 if annee >= 2010 else 3.0, "hep", {"enseignement": 1}])
		_:
			if acces in ["dip_sec", "bac", "bac_gen", "mat_gym"]:
				out.append(["licence_gen", 55, 3.0, "uni", dom_uni])
				out.append(["dip_med_gen", 8, 6.0, "uni", {"medecine": 1}])
				out.append(["dip_tech", 25, 2.0, "hes", dom_hes])
				out.append(["dip_ens", 10, 3.0, "hep", {"enseignement": 1}])
	return out


## Part des diplômés (maturité, bac) qui font des études supérieures.
static func part_superieur(sys: String, annee: int, acces: String) -> float:
	var t := [[1800, 0.25], [1900, 0.35], [1950, 0.55], [2000, 0.75], [2020, 0.8]]
	if acces in ["mat_pro", "bac_pro"]:
		t = [[1990, 0.15], [2020, 0.4]]
	elif acces == "mat_spec":
		t = [[2004, 0.7]]
	return _interp(t, annee)


## Cursus suivant (bachelor → master → doctorat) : [id, part, durée] ou [].
static func suite_cursus(dip: String, annee: int) -> Array:
	match dip:
		"bachelor_uni":
			return ["master_uni", 0.75, 2.0]
		"master_uni", "lic_uni", "dipl_med", "master_hes":
			return ["doctorat_ch", 0.12 if dip != "dipl_med" else 0.5, 4.0]
		"bachelor_hes":
			return ["master_hes", 0.15, 1.5]
		"bachelor_hep":
			return ["master_hep", 0.3, 2.0]
		"licence_fr":
			return ["master_fr", 0.6, 2.0]
		"master_fr", "ingenieur":
			return ["doctorat_fr", 0.1 if dip == "master_fr" else 0.05, 3.0]
		"licence_gen":
			return ["master_gen", 0.5, 2.0]
		"master_gen", "dip_med_gen":
			return ["doctorat_gen", 0.1, 4.0]
		"bts_fr", "dut":
			return ["licence_fr", 0.3, 1.0] if annee >= 1999 else []
	return []


# --- Diplômes -------------------------------------------------------------------------

static func _nom_epoque(noms: Array, annee: int) -> String:
	var out := String(noms[0][1])
	for e in noms:
		if annee >= int(e[0]):
			out = String(e[1])
	return out


static func id_de(dip: String) -> String:
	return dip.get_slice(":", 0)


static func domaine_de(dip: String) -> String:
	var d := dip.get_slice(":", 1) if dip.contains(":") else ""
	if d == "":
		d = String(DIPLOMES.get(id_de(dip), {}).get("dom", ""))
	return d


static func niveau_de(dip: String) -> int:
	if dip == "":
		return 0
	return int(DIPLOMES.get(id_de(dip), {}).get("niv", 0))


## Nom lisible : "CFC (certificat fédéral de capacité) de boulanger·ère", "Master universitaire (technique et industrie)".
static func nom_diplome(dip: String, annee := 0) -> String:
	if dip == "":
		return "aucun diplôme"
	var id := id_de(dip)
	if not DIPLOMES.has(id):
		return id
	if annee <= 0:
		annee = Epoques.annee()
	var nom := _nom_epoque(DIPLOMES[id].n, annee)
	var parts := dip.split(":")
	if parts.size() >= 3 and parts[2] != "":
		var m := String(parts[2])
		var metier := String(NOMS_APPRENTISSAGE.get(m, String(Metiers.job(m).name).to_lower()))
		return "%s %s%s" % [nom, de(metier), metier]
	var dom := dip.get_slice(":", 1) if dip.contains(":") else ""
	if dom != "" and not DIPLOMES[id].has("dom") and DOMAINES.has(dom):
		return "%s (%s)" % [nom, DOMAINES[dom]]
	return nom


## Le plus haut diplôme d'une liste.
static func meilleur(dips: Array) -> String:
	var best := ""
	for d in dips:
		if niveau_de(String(d)) >= niveau_de(best):
			best = String(d)
	return best


# --- Métiers ------------------------------------------------------------------------------

## Exigence du métier l'année donnée : {niv, dom, strict}.
static func exigence(metier: String, annee: int) -> Dictionary:
	var e: Array = EXIGENCES.get(metier, [0, "", false, 0])
	if annee > 0 and annee < int(e[3]):
		return {"niv": 0, "dom": "", "strict": false}
	var niv := int(e[0])
	for av in AVANT.get(metier, []):
		if annee > 0 and annee < int(av[0]):
			niv = mini(niv, int(av[1]))
			break
	return {"niv": niv, "dom": String(e[1]), "strict": bool(e[2])}


## Un diplôme suffit-il à l'exigence ? Un diplôme d'un autre domaine suffit
## aux métiers non stricts s'il est d'au moins deux niveaux au-dessus.
static func diplome_suffit(dip: String, ex: Dictionary) -> bool:
	var n := niveau_de(dip)
	if n < int(ex.niv):
		return false
	var dom := String(ex.dom)
	if dom == "":
		return true
	var dd := domaine_de(dip)
	if dd == "" or dd == dom:
		return true
	return not bool(ex.strict) and n >= int(ex.niv) + 2


static func qualifie(dips: Array, metier: String, annee: int) -> bool:
	var ex := exigence(metier, annee)
	if int(ex.niv) <= 0:
		return true
	for d in dips:
		if diplome_suffit(String(d), ex):
			return true
	return false


## Texte de l'exigence : "master en médecine et pharmacie (obligatoire)".
static func texte_exigence(metier: String, annee: int) -> String:
	var ex := exigence(metier, annee)
	if int(ex.niv) <= 0:
		return "aucun diplôme exigé"
	var t := String(NIVEAUX[int(ex.niv)]).to_lower()
	if String(ex.dom) != "":
		t += " en " + String(DOMAINES.get(String(ex.dom), ex.dom))
	return t + (" (obligatoire)" if bool(ex.strict) else " (conseillé)")


## Système d'un pays réel (code ISO en minuscules, "" : France par défaut, comme avant).
static func systeme_du_pays(code: String) -> String:
	if code == "":
		return "fr"
	return String(PAR_PAYS.get(code.to_lower(), "gen"))


static func nom_cycle(sys: String, cyc: String, annee: int) -> String:
	var t: Dictionary = NOMS_CYCLES.get(sys, NOMS_CYCLES.gen)
	if not t.has(cyc):
		return cyc
	return _nom_epoque(t[cyc], annee)


## Nom de la classe d'un élève : "5H", "CM1", "Gymnase, 2e année"…
static func classe(sys: String, cyc: String, age: int, annee: int, debut := 0) -> String:
	var b := bornes(sys, annee)
	match cyc:
		"enfantine", "primaire", "sec1":
			match sys:
				"ch":
					if annee >= 2009:
						return "%dH" % clampi(age - 3, 1, 11)
					if cyc == "enfantine":
						return "École enfantine"
					var y := age - int(b.primaire[0]) + 1
					return "%de année" % clampi(y, 1, 9) if y > 1 else "1re année"
				"fr":
					const FR := ["Petite section", "Moyenne section", "Grande section", "CP", "CE1", "CE2", "CM1", "CM2", "6e", "5e", "4e", "3e"]
					return FR[clampi(age - 3, 0, FR.size() - 1)]
			var g := age - 5
			return "Préscolaire" if g < 1 else "Année %d" % clampi(g, 1, 9)
	var an := maxi(1, age - debut + 1) if debut > 0 else 1
	var rang := "1re" if an == 1 else "%de" % an
	match cyc:
		"gym":
			if sys == "fr":
				const LY := ["Seconde", "Première", "Terminale"]
				return LY[clampi(an - 1, 0, 2)]
			return "%s, %s année" % [nom_cycle(sys, cyc, annee), rang]
	return "%s année" % rang


## « de » ou « d' » devant un nom de métier.
static func de(mot: String) -> String:
	return "d'" if mot.left(1).to_lower() in ["a", "e", "é", "è", "ê", "i", "î", "o", "ô", "u", "h"] else "de "
