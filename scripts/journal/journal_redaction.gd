class_name JournalRedaction
extends RefCounted
## La rédaction du journal : transforme les faits du jour en articles, avec un
## ton réaliste et une touche d'humour. Chaque texte est un « T » : un tableau
## [modèle, arg1, arg2…] où le modèle est un texte français avec des %s. Il se
## traduit au moment de l'affichage (Journal.texte), donc une édition parue en
## français se relit en anglais si le joueur change de langue.
##
## Un modèle peut être réservé à une époque : {"t": "…", "de": 1800, "a": 1899}.

# --- Titres selon le genre des nouvelles (scripts/evenements) ---------------------------

const TITRES_GENRE := {
	"incendie": [
		"Le feu frappe %s",
		"Incendie à %s : la ville retient son souffle",
		"Flammes à %s : les badauds en restent bouche bée",
		{"t": "Incendie à %s : la chaîne des seaux s'organise", "a": 1899},
		{"t": "Incendie à %s : les pompes à bras entrent en action", "a": 1913},
		{"t": "Incendie à %s : les pompiers sur tous les fronts", "de": 1900},
		{"t": "Incendie à %s : les vidéos inondent les réseaux sociaux", "de": 2008},
	],
	"tempete": [
		"Coup de vent sur %s : les parapluies n'ont rien pu faire",
		"Tempête : %s ramasse les branches",
		"La tempête secoue %s, les tuiles volent bas",
		{"t": "Tempête : les ardoisiers de %s se frottent les mains", "a": 1950},
		{"t": "Tempête : le courant saute à %s, les bougies ressortent", "de": 1900},
	],
	"epidemie": [
		"%s se mouche : l'épidémie gagne du terrain",
		"Épidémie à %s : les médecins débordés",
		"Épidémie : à %s, on ne se serre plus la main",
		{"t": "Épidémie : à %s, on brûle des herbes contre les miasmes", "a": 1880},
		{"t": "Épidémie : les pharmacies de %s en rupture de mouchoirs", "de": 1950},
	],
	"fete": [
		"Fête à %s : on a dansé jusqu'au bout de la nuit",
		"%s en fête : les voisins dorment mal, mais sourient",
		{"t": "Bal populaire à %s : les violoneux ont tenu jusqu'à l'aube", "a": 1913},
		{"t": "Fête à %s : la sono s'entend jusqu'à la commune voisine", "de": 1960},
	],
	"marche": [
		"Jour de marché à %s : les tomates à prix d'or",
		"Marché de %s : on vient de loin pour le fromage",
		{"t": "Foire de %s : les maquignons font affaire", "a": 1930},
		{"t": "Marché de %s : le bio fait le plein", "de": 1995},
	],
	"match": [
		"Soirée de sport à %s",
		"Le stade de %s vibre",
	],
	"politique": [
		"Ça bouge à la mairie de %s",
		"Vie politique : %s s'agite",
		"Conseil municipal de %s : les débats s'enflamment",
	],
	"manifestation": [
		"Pancartes et slogans dans les rues de %s",
		"%s : la colère gronde devant la mairie",
		{"t": "Émeute à %s : les fourches sont de sortie", "a": 1870},
	],
	"crue": [
		"%s les pieds dans l'eau",
		"Crue : la rivière s'invite chez les habitants de %s",
		"La crue surprend %s, les canards ravis",
	],
	"neige": [
		"%s sous la neige : la ville au ralenti",
		"Neige sur %s : les enfants ravis, les automobilistes moins",
		{"t": "Neige sur %s : les traîneaux de sortie", "a": 1920},
	],
	"secheresse": [
		"Sécheresse : %s rationne l'eau",
		"%s a soif : les pelouses jaunissent",
	],
	"canicule": [
		"Canicule : %s cuit à petit feu",
		"Chaleur écrasante sur %s",
		{"t": "Canicule : les climatiseurs de %s tournent à plein", "de": 1990},
	],
	"gel": [
		"Gel tardif : les jardiniers de %s maudissent les saints de glace",
		"%s grelotte : le gel frappe les cultures",
	],
	"saison": [
		"Une nouvelle saison commence à %s",
	],
	"ruine": [
		"%s : il ne reste que des ruines",
	],
	"reparation": [
		"%s : les travaux de réparation avancent",
	],
}

## Chapeaux des articles d'événement.
const CHAPOS_GENRE := {
	"incendie": ["Les flammes ont surpris le quartier. Récit d'une journée chaude.", "Les pompiers ont lutté pied à pied. Voici ce que l'on sait."],
	"tempete": ["Vent violent, arbres à terre et toits malmenés : le point sur les dégâts.", "La ville a passé une nuit agitée."],
	"epidemie": ["Toux, fièvre et salles d'attente pleines : la ville fait le dos rond.", "Les médecins appellent au calme et au lavage des mains."],
	"fete": ["Musique, buvette et piste de danse : la ville a fait la fête.", "Les habitants étaient nombreux au rendez-vous."],
	"marche": ["Les étals ont attiré la foule dès le matin.", "Commerçants et clients ont rempli la place."],
	"politique": ["Les nouvelles de l'hôtel de ville.", "Ce qui se dit dans les couloirs de la mairie."],
	"manifestation": ["Les habitants mécontents se sont fait entendre.", "Le cortège a traversé la ville."],
	"crue": ["La rivière est sortie de son lit. Le point sur les quartiers touchés."],
	"neige": ["Un manteau blanc recouvre la ville."],
	"secheresse": ["Les réserves baissent et la ville surveille le ciel."],
	"canicule": ["Le thermomètre s'affole. Les conseils pour tenir le coup."],
	"gel": ["Le froid est revenu au pire moment pour les cultures."],
}
const CHAPO_DEFAUT := ["Les nouvelles du jour."]

## Paroles de témoins selon le genre (un habitant de la ville, nommé).
const TEMOINS := {
	"incendie": ["J'ai vu la fumée depuis ma fenêtre, j'ai tout de suite appelé.", "On a eu très peur. Heureusement que les secours sont venus vite.",
		"Je l'avais toujours dit, ce bâtiment, c'était une boîte d'allumettes."],
	"tempete": ["Mon parapluie est parti tout seul vers la commune voisine.", "On n'avait pas vu un vent pareil depuis des années.",
		"Ma tondeuse a fini dans le jardin du voisin. Il peut la garder."],
	"epidemie": ["Toute la famille est au lit, même le chien a l'air fatigué.", "Je me lave les mains vingt fois par jour, mes mains n'en peuvent plus."],
	"fete": ["Une super ambiance, on remet ça l'an prochain !", "J'ai dansé jusqu'à minuit, mes genoux s'en souviennent.", "Les merguez étaient parfaites."],
	"marche": ["Je viens tous les samedis, c'est ici qu'on apprend les nouvelles.", "Les prix montent, mais le fromage est bon."],
	"manifestation": ["On veut juste être écoutés.", "Je n'avais jamais porté de pancarte. C'est lourd, en fait."],
	"crue": ["L'eau est arrivée jusqu'aux genoux dans la cuisine.", "Mon potager est devenu un étang."],
	"neige": ["On a sorti la luge du grenier.", "J'ai mis une heure pour faire cent mètres."],
	"canicule": ["Je dors dans la baignoire.", "Même les pigeons cherchent l'ombre."],
	"secheresse": ["Mes tomates font la grimace.", "On garde l'eau des pâtes pour arroser."],
	"politique": ["Les promesses, c'est bien. Les actes, c'est mieux.", "On verra bien aux prochaines élections."],
}

# --- Sport ---------------------------------------------------------------------------------

const TITRES_MATCH := {
	"V": ["Victoire ! %s fait chavirer ses supporters", "%s s'impose et la ville jubile", "Ça sourit pour %s"],
	"N": ["Match nul pour %s : personne n'est vraiment content", "%s partage les points"],
	"D": ["Défaite pour %s : soirée difficile", "%s s'incline, les supporters font la grimace", "Coup dur pour %s"],
}
const CORPS_MATCH := "Score final : %s."
const CORPS_MATCH_DOM := "Devant %s spectateurs, l'ambiance était au rendez-vous."
const CORPS_MATCH_BUTEURS := "Les marqueurs du jour : %s."
const PAROLE_MATCH := {
	"V": ["On a vu un grand match, j'en ai encore des frissons.", "Je l'avais dit à tout le monde au café !"],
	"N": ["On mérite mieux, mais on prend.", "Ni chaud ni froid. Plutôt froid, en fait."],
	"D": ["L'arbitre avait oublié ses lunettes.", "On reviendra plus forts. Il le faut."],
}

# --- Inaugurations et démolitions ----------------------------------------------------------

const TITRES_INAUGURATION := {
	"services": ["Le maire coupe le ruban : %s ouvre ses portes", "%s ouvre ses portes, enfin", "Nouveau service public : %s"],
	"sport": ["%s inauguré : les sportifs s'échauffent déjà", "Les baskets sont lacées : %s ouvre"],
	"loisirs": ["%s ouvre : la ville se divertit", "Nouveau lieu de sortie : %s"],
	"spectacles": ["Lever de rideau : %s ouvre", "%s accueille son premier public"],
	"tourisme": ["%s attend ses premiers touristes", "La ville soigne son accueil : %s ouvre"],
	"parc": ["Cris de joie au %s", "%s : premiers frissons pour les visiteurs"],
	"zoo": ["Les animaux s'installent : %s ouvre", "%s : rugissements garantis"],
	"funeraire": ["%s ouvre, dans le calme et la dignité"],
	"logement": ["La ville prend de la hauteur : %s sort de terre"],
	"autre": ["%s ouvre ses portes"],
}
const CHAPO_INAUGURATION := [
	{"t": "La fanfare municipale a joué trois airs, dont deux justes.", "a": 1960},
	{"t": "Le maire a prononcé un discours de quarante minutes. Les plus jeunes ont tenu dix.", "a": 1990},
	{"t": "Ruban coupé, petits fours et photos de groupe : tout était là.", "de": 1930},
	{"t": "Le maire a coupé le ruban sous les flashs et les téléphones levés.", "de": 2005},
	"Une foule de curieux était venue voir à quoi ressemblait l'intérieur.",
]
const CORPS_INAUGURATION := "%s a ouvert à %s."
const CORPS_INAUGURATION_COUT := "Coût de l'opération : %s."
const TITRES_DEMOLITION := [
	"Adieu %s : il n'en reste rien",
	{"t": "Les pioches ont eu raison de %s", "a": 1930},
	{"t": "Les bulldozers rasent %s", "de": 1931},
]
const CHAPO_DEMOLITION := ["Certains regrettent déjà, d'autres demandent ce qui viendra à la place."]

# --- Ponts et routes -----------------------------------------------------------------------

const TITRES_PONT_NULLE_PART := [
	"Le maire inaugure un pont vers nulle part",
	"Un pont tout neuf qui ne mène à rien : la ville s'interroge",
	"%s : le pont qui ne va nulle part attire les curieux",
]
const CHAPO_PONT_NULLE_PART := [
	"De l'autre côté, il n'y a rien. Pour l'instant, assure la mairie.",
	"Les promeneurs vont jusqu'au bout, regardent le vide, et reviennent.",
]
const PAROLE_PONT_NULLE_PART := ["C'est beau, mais ça va où ?", "Je l'ai traversé deux fois pour être sûr. Il n'y a rien.", "C'est de l'art moderne, non ?"]
const TITRES_PONT := ["Un nouveau pont relie les deux rives", "%s gagne un pont", "Le pont est ouvert : les détours, c'est fini"]
const CHAPO_PONT := ["Les habitants ont traversé, puis retraversé, pour le plaisir.", "Une belle réalisation, saluée par les automobilistes et les piétons."]
const TITRES_ROUTES := [
	{"t": "%s de chemins nouveaux tracés à %s", "a": 1899},
	{"t": "%s de nouvelles routes à %s : la ville s'étend", "de": 1900},
	"La ville trace sa route : %s de voies nouvelles à %s",
]
const CHAPO_ROUTES := [
	{"t": "Les cantonniers ont manié la pelle et la brouette.", "a": 1920},
	{"t": "Le bitume est encore chaud.", "de": 1921},
	"Les riverains découvrent leurs nouveaux trottoirs.",
]

# --- Communes ------------------------------------------------------------------------------

const TITRES_FONDATION := ["Naissance d'une commune : bienvenue à %s", "%s est fondée", "Un nouveau village sur la carte : %s"]
const CHAPO_FONDATION := ["Une maison de commune, quelques pionniers et beaucoup d'espoir.", "Tout reste à construire. Les premiers habitants ont déjà des idées."]

# --- Chiffres de la ville (relevés des statistiques) ---------------------------------------

const TITRES_PALIER := ["%s habitants : %s grandit", "Le cap des %s habitants est franchi", "%s compte désormais %s habitants"]
const CHAPO_PALIER := ["Les nouveaux arrivants s'installent, la boulangerie fait des heureux.", "La ville change de dimension. Les embouteillages aussi."]
const TITRES_CHOMAGE := ["Le chômage grimpe à %s", "Emploi : l'inquiétude monte à %s"]
const CHAPO_CHOMAGE := ["Les files s'allongent devant les offres d'emploi. Il faudrait des usines, des bureaux, des commerces."]
const TITRES_CAISSE_ROUGE := ["Les caisses de la ville sont vides", "La mairie dans le rouge : %s", "Budget : la ville vit à crédit"]
const CHAPO_CAISSE_ROUGE := ["Le trésorier ne répond plus au téléphone.", "Il va falloir faire des choix : impôts, économies ou emprunt."]
const TITRES_CAISSE_VERTE := ["La caisse de la ville repasse dans le vert", "Les comptes de la ville respirent à nouveau"]
const CHAPO_CAISSE_VERTE := ["Le trésorier a été vu en train de sourire."]
const TITRES_SATISFACTION_BASSE := ["Les habitants font la tête", "Moral en berne à %s"]
const CHAPO_SATISFACTION_BASSE := ["Les plaintes s'accumulent à la mairie. La prochaine élection pourrait être agitée."]
const TITRES_SATISFACTION_HAUTE := ["Il fait bon vivre à %s", "Les habitants de %s n'ont jamais été aussi contents"]
const CHAPO_SATISFACTION_HAUTE := ["Même les râleurs professionnels peinent à trouver à redire."]
const TITRES_BOUCHONS := ["Bouchons : %s klaxonne", {"t": "Embouteillage de charrettes dans les rues de %s", "a": 1910}, "Circulation : la ville à l'arrêt"]
const CHAPO_BOUCHONS := ["Un trajet sur trois se passe à l'arrêt. Il faudrait des transports en commun, ou des routes plus larges."]
const TITRES_POUBELLES := ["Les poubelles débordent à %s", "%s croule sous les ordures"]
const CHAPO_POUBELLES := ["Les rats tiennent leur congrès annuel. Il manque des bennes ou une décharge."]
const TITRES_POLLUTION := ["L'air de %s devient irrespirable", "Pollution : %s tousse"]
const CHAPO_POLLUTION := ["Les cheminées d'usine fument plus que jamais. Les médecins s'inquiètent."]

# --- Jour calme ----------------------------------------------------------------------------

const TITRES_CALME := [
	"Rien à signaler : la rédaction s'ennuie",
	"Journée calme à %s : un chat coincé dans un arbre fait la une",
	"%s : le facteur a fait sa tournée, et c'est tout",
	"Un pigeon élu personnalité du jour à %s, faute de concurrence",
	{"t": "La pluie a cessé à midi : la ville en parle encore", "a": 1950},
	{"t": "Panne de wifi au café de %s : trois clients ont dû se parler", "de": 2008},
]
const CHAPO_CALME := ["Il ne s'est rien passé, et nous l'avons vérifié deux fois.", "Une journée tranquille, comme on les aime (sauf à la rédaction)."]

# --- Carnet, annonces, divers --------------------------------------------------------------

const ANNONCES_DROLES := [
	"Perdu parapluie noir, très attaché. Récompense.",
	"Cherche voisin qui ne tond pas sa pelouse le dimanche matin.",
	"Vends vélo, roule bien, freine un peu.",
	"Donne chatons, affectueux, griffes incluses.",
	{"t": "Vends cheval docile, ne mord que le mardi.", "a": 1930},
	{"t": "Recherche personne sachant lire pour me lire ce journal.", "a": 1880},
	{"t": "Vends lampe à huile, éclaire encore très bien.", "a": 1910},
	{"t": "Vends télévision noir et blanc, idéale pour les vieux films.", "de": 1970, "a": 2000},
	{"t": "Cherche le mot de passe du wifi de la mairie.", "de": 2005},
	{"t": "Vends trottinette électrique, batterie fatiguée comme son propriétaire.", "de": 2016},
]
const ANNONCE_LOGEMENTS := "À louer : %s logements libres en ville. Visites sur rendez-vous."
const ANNONCE_EMPLOIS := "On recrute : %s postes à pourvoir. Se présenter avec le sourire."
const ANNONCE_HABITANTS := "On cherche des bras : %s logements attendent des familles."

const CHIFFRES := {
	"habitants": "habitants en ville",
	"chomage": "de chômage",
	"satisfaction": "de satisfaction moyenne sur 100",
	"touristes": "touristes en ville",
	"dechets": "poubelles qui débordent",
	"congestion": "du temps perdu dans les bouchons",
}

## Mots d'introduction d'un témoin : %s = nom, %s = âge, %s = situation.
const TEMOIN_INTRO := "%s, %s ans, %s :"
const SIGNATURE := "Par %s"


# --- Outils --------------------------------------------------------------------------------

static func choisir(rng: RandomNumberGenerator, liste: Array, annee: int) -> String:
	var l := JournalEpoques.filtrer(liste, annee)
	if l.is_empty():
		return ""
	return String(l[rng.randi() % l.size()])


## Un T simple (modèle et arguments).
static func t(modele: String, args := []) -> Array:
	var out := [modele]
	for a in args:
		out.append(str(a))
	return out


## Le modèle a-t-il exactement autant de %s que d'arguments ? Sinon on garde ce qui rentre.
static func t_libre(modele: String, args: Array) -> Array:
	var n := modele.count("%s")
	var a := args.slice(0, n)
	while a.size() < n:
		a.append("")
	return t(modele, a)


static func nombre(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = " " + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


static func km(m: float) -> String:
	if m >= 1000.0:
		return "%s km" % str(snappedf(m / 1000.0, 0.1)).replace(".", ",")
	return "%d m" % roundi(m)
