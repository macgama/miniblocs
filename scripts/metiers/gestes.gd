class_name Gestes
extends RefCounted
## Bibliothèque des gestes de métier : ce que fait un employé à son poste.
##
## Un geste = un texte (« pétrit la pâte »), une animation du corps (voir
## Figurine.animer), un outil tenu en main et le poste de travail posé devant
## lui dans la vue en coupe (pétrin, four, tableau, lit, caisse…).
##
## Chaque métier de Metiers.METIERS peut donner sa liste dans la clé "geste"
## (un nom ou un tableau de noms). Sans clé, le geste est deviné d'après les
## mots du métier, puis d'après la catégorie du bâtiment : un métier ajouté
## plus tard (chaînes de production, nouvelles entreprises) a donc toujours
## un geste, sans rien écrire de plus. L'employé change de geste toutes les
## 10 minutes de jeu.

## Geste : t = texte, a = animation, o = outil en main, p = poste devant lui,
## s = assis.
const GESTES := {
	# Boulangerie, cuisine, alimentation.
	"petrir": {"t": "pétrit la pâte", "a": "petrir", "o": "", "p": "petrin"},
	"faconner": {"t": "façonne les baguettes", "a": "faconner", "o": "", "p": "plan_travail"},
	"enfourner": {"t": "enfourne le pain", "a": "enfourner", "o": "pelle_four", "p": "four"},
	"cuisiner": {"t": "cuisine au fourneau", "a": "remuer", "o": "louche", "p": "fourneau"},
	"couper": {"t": "découpe la viande", "a": "trancher", "o": "couteau", "p": "billot"},
	"servir": {"t": "sert les clients", "a": "servir", "o": "plateau", "p": "table"},
	"cafe": {"t": "prépare les cafés", "a": "remuer", "o": "tasse", "p": "comptoir"},
	"moudre": {"t": "surveille la meule", "a": "surveiller", "o": "", "p": "meule"},
	# Commerce.
	"caisse": {"t": "tient la caisse", "a": "scanner", "o": "", "p": "caisse"},
	"conseiller": {"t": "conseille un client", "a": "parler", "o": "", "p": "comptoir"},
	"ranger": {"t": "remplit les rayons", "a": "ranger", "o": "carton", "p": "etagere"},
	"vendre": {"t": "vend au comptoir", "a": "tendre", "o": "sachet", "p": "comptoir"},
	"porter": {"t": "porte des cartons", "a": "porter", "o": "carton", "p": "palette"},
	# École.
	"tableau": {"t": "écrit au tableau", "a": "ecrire_tableau", "o": "craie", "p": "tableau"},
	"expliquer": {"t": "fait la leçon", "a": "parler", "o": "livre", "p": "tableau"},
	"corriger": {"t": "corrige les cahiers", "a": "ecrire_assis", "o": "stylo", "p": "bureau_prof", "s": true},
	"aider_enfant": {"t": "aide un enfant", "a": "pencher", "o": "", "p": "petite_table"},
	# Santé.
	"ausculter": {"t": "ausculte un patient", "a": "pencher", "o": "stethoscope", "p": "lit"},
	"soigner": {"t": "fait un pansement", "a": "soigner", "o": "", "p": "lit"},
	"perfuser": {"t": "pose une perfusion", "a": "lever_bras", "o": "", "p": "perfusion"},
	"dossier": {"t": "remplit un dossier", "a": "ecrire_assis", "o": "stylo", "p": "bureau", "s": true},
	"brancard": {"t": "pousse un brancard", "a": "pousser", "o": "", "p": "brancard"},
	# Bureaux, administration.
	"taper": {"t": "travaille sur l'ordinateur", "a": "taper", "o": "", "p": "bureau", "s": true},
	"telephoner": {"t": "est au téléphone", "a": "telephoner", "o": "telephone", "p": "bureau", "s": true},
	"reunion": {"t": "anime une réunion", "a": "parler", "o": "", "p": "ecran"},
	"plans": {"t": "étudie des plans", "a": "pencher", "o": "stylo", "p": "table_plans"},
	"guichet": {"t": "reçoit au guichet", "a": "parler", "o": "", "p": "guichet"},
	"balayer": {"t": "balaie", "a": "balayer", "o": "balai", "p": ""},
	# Artisanat, industrie.
	"marteler": {"t": "travaille à l'établi", "a": "marteler", "o": "marteau", "p": "etabli"},
	"raboter": {"t": "rabote une planche", "a": "raboter", "o": "rabot", "p": "etabli"},
	"machine": {"t": "conduit une machine", "a": "machine", "o": "", "p": "machine"},
	"controle": {"t": "contrôle la production", "a": "surveiller", "o": "tablette", "p": "pupitre_commande"},
	"souder": {"t": "soude une pièce", "a": "souder", "o": "chalumeau", "p": "etabli"},
	"couler": {"t": "coule le métal", "a": "pousser", "o": "", "p": "creuset"},
	"chariot": {"t": "range le stock", "a": "ranger", "o": "carton", "p": "rack"},
	# Dehors : champs, forêt, carrière, mer.
	"becher": {"t": "travaille la terre", "a": "becher", "o": "beche", "p": "sillons"},
	"recolter": {"t": "récolte", "a": "cueillir", "o": "panier", "p": "sillons"},
	"nourrir": {"t": "nourrit les bêtes", "a": "jeter", "o": "seau", "p": "mangeoire"},
	"traire": {"t": "trait les vaches", "a": "accroupi", "o": "seau", "p": "vache"},
	"tronconner": {"t": "abat un arbre", "a": "scier", "o": "tronconneuse", "p": "tronc"},
	"empiler": {"t": "empile les grumes", "a": "porter", "o": "buche", "p": "grumes"},
	"piocher": {"t": "casse la roche", "a": "piocher", "o": "pioche", "p": "rochers"},
	"forer": {"t": "surveille le forage", "a": "surveiller", "o": "cle", "p": "derrick"},
	"filet": {"t": "remonte les filets", "a": "tirer", "o": "", "p": "filet"},
	"trier_poisson": {"t": "trie le poisson", "a": "trier", "o": "", "p": "caisses"},
	"conduire": {"t": "conduit un engin", "a": "conduire", "o": "", "p": "volant", "s": true},
	"charger": {"t": "charge le camion", "a": "porter", "o": "carton", "p": "palette"},
	# Services publics, loisirs, sport.
	"surveiller": {"t": "monte la garde", "a": "surveiller", "o": "", "p": ""},
	"radio": {"t": "parle à la radio", "a": "telephoner", "o": "radio", "p": "bureau", "s": true},
	"lance": {"t": "s'entraîne à la lance", "a": "lance", "o": "lance", "p": "tuyau"},
	"entretien_camion": {"t": "vérifie le camion", "a": "pencher", "o": "cle", "p": "camion"},
	"entrainer": {"t": "entraîne un groupe", "a": "sauter", "o": "sifflet", "p": "tapis"},
	"jouer": {"t": "répète une scène", "a": "declamer", "o": "", "p": "scene"},
	"projeter": {"t": "lance la projection", "a": "machine", "o": "", "p": "projecteur"},
	"billets": {"t": "vend les billets", "a": "tendre", "o": "billet", "p": "guichet"},
	"annoncer": {"t": "renseigne les voyageurs", "a": "parler", "o": "", "p": "guichet"},
}

## Gestes des métiers existants qui n'en donnent pas dans Metiers.METIERS.
## (Le plus simple pour un nouveau métier : ajouter "geste" dans son entrée.)
const PAR_METIER := {
	"boulanger": ["petrir", "faconner", "enfourner"],
	"vendeur": ["vendre", "conseiller", "ranger"],
	"caissier": ["caisse"],
	"magasinier": ["chariot", "porter"],
	"chauffeur": ["charger", "conduire"],
	"employe": ["taper", "telephoner"],
	"cadre": ["reunion", "telephoner", "taper"],
	"ingenieur": ["plans", "taper", "controle"],
	"artisan": ["marteler", "raboter"],
	"ouvrier": ["machine", "porter", "souder"],
	"agriculteur": ["becher", "recolter", "conduire"],
	"agent_public": ["guichet", "taper", "balayer"],
	"enseignant": ["tableau", "expliquer", "corriger"],
	"atsem": ["aider_enfant", "balayer"],
	"pompier": ["lance", "entretien_camion", "radio"],
	"policier": ["surveiller", "radio", "taper"],
	"medecin": ["ausculter", "dossier"],
	"infirmier": ["soigner", "perfuser", "dossier"],
	"aide_soignant": ["soigner", "brancard"],
	"serveur": ["servir", "cafe"],
	"cuisinier": ["cuisiner", "couper"],
	"agent_cinema": ["billets", "projeter"],
	"coach": ["entrainer"],
	"comedien": ["jouer"],
	"agent_gare": ["annoncer", "billets"],
	"bucheron": ["tronconner", "empiler"],
	"carrier": ["piocher", "conduire"],
	"conducteur_engins": ["conduire"],
	"mineur": ["piocher", "porter"],
	"foreur": ["forer", "controle"],
	"eleveur": ["nourrir", "traire"],
	"pecheur": ["filet", "trier_poisson"],
	"meunier": ["moudre", "porter"],
	"boucher": ["couper", "vendre"],
	"siderurgiste": ["couler", "controle"],
	"operateur": ["controle", "machine"],
	"menuisier": ["raboter", "marteler"],
}

## Devinette d'après les mots du métier (id ou nom), dans l'ordre.
const MOTS := [
	["boulang", ["petrir", "enfourner"]], ["patiss", ["faconner", "enfourner"]], ["cuisin", ["cuisiner", "couper"]],
	["boucher", ["couper"]], ["charcut", ["couper"]], ["poisson", ["trier_poisson", "vendre"]], ["serveu", ["servir"]],
	["barman", ["cafe"]], ["caiss", ["caisse"]], ["vend", ["vendre", "conseiller"]], ["magasin", ["chariot"]],
	["livr", ["charger", "conduire"]], ["chauffeur", ["conduire", "charger"]], ["conduct", ["conduire"]],
	["enseign", ["tableau", "expliquer"]], ["profes", ["tableau", "expliquer"]], ["educat", ["aider_enfant"]],
	["medec", ["ausculter", "dossier"]], ["infirm", ["soigner", "perfuser"]], ["soign", ["soigner"]], ["pharma", ["vendre", "conseiller"]],
	["ingen", ["plans", "taper"]], ["cadre", ["reunion", "taper"]], ["comptab", ["taper"]], ["secret", ["telephoner", "taper"]],
	["employ", ["taper", "telephoner"]], ["agent", ["guichet", "taper"]], ["menuis", ["raboter", "marteler"]],
	["charpent", ["raboter", "marteler"]], ["soud", ["souder"]], ["forgeron", ["marteler"]], ["mecan", ["entretien_camion", "marteler"]],
	["electric", ["marteler", "controle"]], ["plomb", ["marteler"]], ["macon", ["porter", "marteler"]], ["textile", ["machine"]],
	["couturi", ["machine"]], ["tisser", ["machine"]], ["operat", ["controle", "machine"]], ["ouvri", ["machine", "porter"]],
	["agricult", ["becher", "recolter"]], ["vigner", ["recolter"]], ["maraich", ["recolter", "becher"]], ["eleveu", ["nourrir", "traire"]],
	["berger", ["nourrir"]], ["bucher", ["tronconner", "empiler"]], ["carri", ["piocher"]], ["mine", ["piocher"]],
	["fore", ["forer"]], ["pech", ["filet", "trier_poisson"]], ["meuni", ["moudre"]], ["siderur", ["couler", "controle"]],
	["fond", ["couler"]], ["pompier", ["lance", "radio"]], ["polic", ["surveiller", "radio"]], ["gendarm", ["surveiller", "radio"]],
	["coach", ["entrainer"]], ["sport", ["entrainer"]], ["comedi", ["jouer"]], ["musici", ["jouer"]], ["cinema", ["billets", "projeter"]],
	["gare", ["annoncer", "billets"]], ["nettoy", ["balayer"]], ["menage", ["balayer"]],
]

## Repli selon la catégorie du bâtiment.
const PAR_CATEGORIE := {
	"commerce": ["vendre", "ranger", "caisse"],
	"industrie": ["machine", "porter", "controle"],
	"production": ["porter", "machine", "conduire"],
	"services": ["guichet", "taper"],
	"loisirs": ["servir", "billets"],
	"sport": ["entrainer"],
	"espaces": ["balayer"],
	"logement": ["balayer"],
}

## Métiers d'extérieur : on les voit dehors, autour du bâtiment, sans vue en coupe.
const DEHORS := ["becher", "recolter", "nourrir", "traire", "tronconner", "empiler", "piocher", "forer", "filet",
	"trier_poisson", "conduire", "charger", "balayer", "lance", "entretien_camion", "surveiller"]

## Bâtiments dont les employés travaillent dehors.
const BATIMENTS_DEHORS := ["ferme", "ferme_cereales", "elevage", "exploitation_forestiere", "carriere", "sabliere",
	"argiliere", "port_peche", "puits", "mine", "marche"]

## Durée d'un geste avant de passer au suivant (secondes de jeu).
const DUREE := 600.0


## Liste des gestes d'un métier.
static func du_metier(met: String, type_id := "") -> Array:
	var m: Dictionary = Metiers.METIERS.get(met, {})
	if m.has("geste"):
		var g: Variant = m.geste
		if g is Array:
			return _valides(g)
		return _valides([g])
	if PAR_METIER.has(met):
		return PAR_METIER[met]
	var txt := (met + " " + String(m.get("name", ""))).to_lower()
	txt = txt.replace("é", "e").replace("è", "e").replace("ç", "c").replace("ê", "e").replace("â", "a")
	for e in MOTS:
		if txt.contains(String(e[0])):
			return e[1]
	if type_id != "":
		var cat := String(BuildingCatalog.get_type(type_id).get("cat", ""))
		if PAR_CATEGORIE.has(cat):
			return PAR_CATEGORIE[cat]
	return ["taper", "telephoner"]


static func _valides(list: Array) -> Array:
	var out := []
	for g in list:
		if GESTES.has(String(g)):
			out.append(String(g))
	return out if not out.is_empty() else ["taper"]


## Geste en cours d'un employé (change toutes les 10 minutes de jeu).
static func courant(pid: int, met: String, unix_time: float, type_id := "") -> String:
	var list := du_metier(met, type_id)
	var i := (int(unix_time / DUREE) + pid * 7) % list.size()
	return String(list[i])


static func info(geste: String) -> Dictionary:
	return GESTES.get(geste, GESTES.taper)


static func texte(geste: String) -> String:
	return String(info(geste).t)


static func assis(geste: String) -> bool:
	return bool(info(geste).get("s", false))


static func dehors(geste: String) -> bool:
	return DEHORS.has(geste)


## Tous les métiers connus ont-ils un geste valide ? (tests)
static func metiers_sans_geste() -> Array:
	var out := []
	for met in Metiers.METIERS:
		for g in du_metier(String(met)):
			if not GESTES.has(String(g)):
				out.append(met)
	return out


## Phrase pour la fiche d'un habitant à son poste (« pétrit la pâte »), ou "".
static func de_personne(pop: Population, pid: int) -> String:
	if not pop.persons.has(pid):
		return ""
	var p: Dictionary = pop.persons[pid]
	if int(p.job) < 0:
		return ""
	var a := pop.activity(p)
	if String(a.kind) != "travail" or int(a.bid) != int(p.job):
		return ""
	var t := String((pop.known.get(int(p.job), {}) as Dictionary).get("t", ""))
	var unix := pop.ambiance.unix_time if pop.ambiance != null else 0.0
	return texte(courant(pid, String(p.met), unix, t))
