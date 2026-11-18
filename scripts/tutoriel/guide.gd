class_name Guide
extends Node
## Guide en bulles : un chapitre par grande fonction du jeu (fondateurs,
## Construire, Mairie, Atelier, vue au sol, zoo, musée, parc, club…).
##
## - Chaque chapitre est une suite de bulles (BullesAide) au centre de l'écran,
##   qui encadrent ce dont elles parlent.
## - La première fois qu'on ouvre la fonction (son panneau, le mode Créer, la vue
##   au sol), une bulle propose « Découvrir ». « Plus tard » : reproposé à la
##   prochaine session ; « Ne plus proposer » coupe toutes les propositions.
## - Tous les chapitres se relancent depuis le panneau Guide (Ctrl+F1, ou F1).
## - Les chapitres vus et le réglage des propositions sont gardés pour le joueur
##   (user://guide.cfg), pas dans la sauvegarde : on ne revoit pas le zoo à
##   chaque nouvelle partie.
##
## Ajouter un chapitre : une entrée dans CHAPITRES (id, titre, icone, resume,
## declencheur, bulles). Voir BullesAide pour les champs d'une bulle.

signal changed

const FICHIER := "user://guide.cfg"

## declencheur : {"panneau": propriété de la scène} (proposé quand il s'ouvre),
## {"mode": "creer"}, {"vue_sol": true}, ou {} (seulement depuis le panneau Guide).
const CHAPITRES := [
	{"id": "bases", "titre": "Les bases", "icone": "aide", "theme": "Prise en main",
		"resume": "La barre du bas, Gérer et Créer, la recherche, le temps.",
		"declencheur": {},
		"bulles": [
			{"titre": "La barre du bas", "cible": "BarreCategories",
				"texte": "Tout part d'ici : le terrain, les voies, Construire, la Mairie, les loisirs… Un clic ouvre les outils ou le panneau."},
			{"titre": "Gérer ou Créer", "cible": ["Gérer"],
				"texte": "Gérer, c'est ta ville. Créer, c'est l'Atelier : tu dessines ton propre bâtiment, la ville se met en pause.",
				"touches": "Tab : passer de l'un à l'autre"},
			{"titre": "Chercher n'importe quoi", "cible": ["Chercher dans tout le jeu"],
				"texte": "Tu ne sais plus où est le zoo, le budget ou la route ? Tape son nom, Entrée, c'est ouvert.",
				"touches": "Espace : recherche"},
			{"titre": "Le temps", "texte": "Les chantiers et la vie avancent en temps réel : 1 jour de jeu dure environ 1 minute. Mets en pause pour réfléchir, accélère quand tout roule.",
				"touches": "T : pause · Maj + T : vitesse"},
			{"titre": "Besoin d'aide ?", "texte": "F1 donne toutes les touches. Ctrl + F1 ouvre ce guide : un chapitre par fonction du jeu, à revoir quand tu veux.",
				"touches": "F1 : commandes · Ctrl + F1 : guide"},
		]},
	{"id": "fondateurs", "titre": "Les fondateurs", "icone": "emploi", "theme": "Prise en main",
		"resume": "Tes premiers ouvriers, leurs chantiers et leurs vivres.",
		"declencheur": {"panneau": "fondateurs_panel"},
		"bulles": [
			{"titre": "Les fondateurs", "panneau": "fondateurs_panel", "cible": ["Les fondateurs", "Pas encore de fondateurs"],
				"texte": "Une centaine de pionniers campent près de la mairie. Ce sont tes ouvriers : sans eux, pas de chantier."},
			{"titre": "Les vivres", "panneau": "fondateurs_panel", "cible": ["Vivres", "Ravitaillement", "Les fondateurs"], "section": false,
				"texte": "Ils ont 90 jours de vivres. Ensuite, la caisse paie le ravitaillement : loge-les vite dans de vraies maisons."},
			{"titre": "Chantiers en cours", "panneau": "fondateurs_panel", "cible": ["Chantiers en cours"],
				"texte": "Les ouvriers vont aux chantiers dans l'ordre de la liste. « En premier » fait passer un chantier devant, « Pause » le met de côté."},
			{"titre": "Affecter les fondateurs", "panneau": "fondateurs_panel", "cible": ["Affecter les fondateurs"],
				"texte": "Quand un bâtiment est fini (ferme, école, commerce), envoie-y des fondateurs : ils prennent n'importe quel métier."},
		]},
	{"id": "construire", "titre": "Construire", "icone": "construire", "theme": "Construire la ville",
		"resume": "Le catalogue, la recherche, les favoris et le zonage.",
		"declencheur": {"panneau": "build_panel"},
		"bulles": [
			{"titre": "Le catalogue", "panneau": "build_panel", "cible": ["Logement", "Thèmes"], "section": false,
				"texte": "Les bâtiments sont rangés par thèmes : logement, commerces, services, loisirs, sport… Clique un thème, puis une vignette, puis le terrain.",
				"touches": "B : Construire · R : tourner · clic droit : lâcher"},
			{"titre": "Chercher un bâtiment", "panneau": "build_panel", "cible": ["Chercher dans tout le catalogue"],
				"texte": "Piscine, gare, boulangerie : tape quelques lettres, le catalogue entier est fouillé."},
			{"titre": "Favoris et récents", "panneau": "build_panel", "cible": ["Favoris"], "section": false,
				"texte": "L'étoile d'une vignette range le bâtiment dans les Favoris. Les Récents se remplissent tout seuls."},
			{"titre": "Le zonage", "panneau": "build_panel", "cible": ["Zonage"], "section": false,
				"texte": "Plutôt que tout poser toi-même, peins des zones (logements, commerces, industrie) le long des routes : les bâtiments poussent selon la demande."},
			{"titre": "Mes modèles", "panneau": "build_panel", "cible": ["Mes modèles"], "section": false,
				"texte": "Les bâtiments que tu crées dans l'Atelier arrivent ici, dans toutes tes parties."},
		]},
	{"id": "mairie", "titre": "La Mairie", "icone": "mairie", "theme": "Gérer la ville",
		"resume": "Le tableau de bord, les alertes et tous les menus de la ville.",
		"declencheur": {"panneau": "mairie_panel"},
		"bulles": [
			{"titre": "Ton tableau de bord", "panneau": "mairie_panel", "cible": ["Mairie"], "section": false, "panneau_entier": true,
				"texte": "Satisfaction, emploi, école, réseaux, transports, déchets : un coup d'œil suffit. Un clic sur une tuile ouvre le détail.",
				"touches": "M : Mairie"},
			{"titre": "La liste « À faire »", "racine": "fil_alertes", "cible": ["À faire"],
				"texte": "Les problèmes urgents arrivent ici : un quartier sans eau, une école pleine… « Y aller » t'emmène sur place."},
			{"titre": "Tous les menus", "panneau": "mairie_panel", "cible": ["La ville", "Services"], "section": false,
				"texte": "Budget, habitants, avis, services, économie, transports, loisirs : tous les panneaux de gestion sont rangés ici."},
		]},
	{"id": "budget", "titre": "Le budget", "icone": "budget", "theme": "Gérer la ville",
		"resume": "Recettes, dépenses, impôts et emprunts.",
		"declencheur": {"panneau": "budget_panel"},
		"bulles": [
			{"titre": "La caisse de la ville", "panneau": "budget_panel", "cible": ["Prévision par mois", "Budget"], "section": true,
				"texte": "En vert ce qui rentre (impôts, billets, loyers), en rouge ce qui sort (salaires, entretien). Si la prévision est rouge, agis avant la faillite."},
			{"titre": "Les impôts", "panneau": "budget_panel", "cible": ["Impôts", "impôts"], "section": false,
				"texte": "Plus d'impôts remplissent la caisse… et vident les urnes. Les habitants te le diront dans leurs avis."},
			{"titre": "Les emprunts", "panneau": "budget_panel", "cible": ["Emprunts", "emprunts"], "section": false,
				"texte": "Un emprunt dépanne pour un gros chantier. Il se rembourse chaque mois, intérêts compris."},
		]},
	{"id": "habitants", "titre": "Les habitants", "icone": "habitants", "theme": "Gérer la ville",
		"resume": "Qui vit dans ta ville, et suivre un habitant façon Sims.",
		"declencheur": {"panneau": "habitants_panel"},
		"bulles": [
			{"titre": "Ta population", "panneau": "habitants_panel", "cible": ["Population", "Habitants"],
				"texte": "Bébés, élèves, actifs, sans emploi, retraités : chaque habitant a un âge, un foyer, un métier et un budget."},
			{"titre": "La vie en ville", "panneau": "habitants_panel", "cible": ["La vie en ville"],
				"texte": "Ils vont à l'école, au travail, font leurs courses, vieillissent, se marient et déménagent. Tout se voit dans les rues."},
			{"titre": "Suivre un habitant", "panneau": "habitants_panel", "cible": ["Ouvre la fiche d'un habitant", "☆ Suivre"], "section": false,
				"texte": "Ouvre la fiche d'un habitant et clique « Suivre » : la caméra l'accompagne et tu reçois les nouvelles de sa vie."},
		]},
	{"id": "avis", "titre": "Avis et élections", "icone": "urne", "theme": "Gérer la ville",
		"resume": "Ce que pensent les habitants, et rester maire.",
		"declencheur": {"panneau": "avis_panel"},
		"bulles": [
			{"titre": "Ce qu'ils pensent", "panneau": "avis_panel", "cible": ["Par thème", "Personne n'habite encore ici"],
				"texte": "Logement, travail, bruit, propreté, impôts : la satisfaction par thème te dit ce qui coince."},
			{"titre": "Ce qu'ils disent", "panneau": "avis_panel", "cible": ["Ce que disent les habitants"],
				"texte": "Leurs phrases sont souvent plus parlantes que les chiffres (et parfois plus drôles)."},
			{"titre": "Les élections", "panneau": "avis_panel", "cible": ["Élections", "Bientôt maire", "Mairie de"],
				"texte": "Tous les quelques années, on vote. Si ta liste perd, la gagnante impose ses objectifs : tu construis encore, mais tu ne décides plus des réglages."},
		]},
	{"id": "reseaux", "titre": "Les réseaux", "icone": "reseaux", "theme": "Gérer la ville",
		"resume": "Électricité, eau, égouts : produire, transporter, réparer.",
		"declencheur": {"panneau": "reseaux_panel"},
		"bulles": [
			{"titre": "Trois réseaux", "panneau": "reseaux_panel", "panneau_entier": true,
				"texte": "Une centrale ou un raccordement pour le courant, un forage pour l'eau, une station pour les égouts. Les petits câbles et tuyaux suivent déjà les routes.",
				"touches": "O : réseaux · B → Réseaux et déchets"},
			{"titre": "Bâtiments non raccordés", "panneau": "reseaux_panel", "cible": ["Icônes des bâtiments non raccordés"], "section": false,
				"texte": "Une icône au-dessus d'un bâtiment ? Il lui manque le courant ou l'eau. Il doit être à moins de 30 m d'une route desservie."},
			{"titre": "Pannes et usure", "panneau": "reseaux_panel", "cible": ["Rénover", "Vite"], "section": false,
				"texte": "Les conduites vieillissent et cassent. Répare vite ce qui fuit, rénove ce qui est usé."},
		]},
	{"id": "lignes", "titre": "Les lignes", "icone": "lignes", "theme": "Gérer la ville",
		"resume": "Bus, trams, trains : arrêts, lignes, horaires et bilan.",
		"declencheur": {"panneau": "transit_panel"},
		"bulles": [
			{"titre": "Transports publics", "panneau": "transit_panel", "panneau_entier": true,
				"texte": "Pose des arrêts ou des gares le long des voies, puis relie-les par une ligne : un clic par arrêt, clic droit pour finir.",
				"touches": "L : lignes"},
			{"titre": "Les véhicules", "panneau": "transit_panel", "cible": ["Nombre de véhicules"], "section": false,
				"texte": "Plus de bus, moins d'attente, mais plus de frais. Les véhicules vieillissent : renouvelle les usés."},
			{"titre": "Horaire et bilan", "panneau": "transit_panel", "cible": ["Bilan ▾", "Horaire ▾"], "section": false,
				"texte": "L'horaire règle la cadence et les heures de service. Le bilan dit si la ligne gagne ou perd de l'argent."},
		]},
	{"id": "atelier", "titre": "L'Atelier", "icone": "editeur", "theme": "Créer",
		"resume": "Dessiner ton propre bâtiment et le poser dans tes parties.",
		"declencheur": {"mode": "creer"},
		"bulles": [
			{"titre": "Bienvenue dans l'Atelier", "creer": true, "cible": ["Créer"], "section": false,
				"texte": "Ici, tu construis toi-même : maison, église, stade, tout ce que tu veux. La ville se met en pause.",
				"touches": "Tab : revenir à la ville"},
			{"titre": "Trois étapes", "creer": true, "racine": "parcours", "cible": ["ParcoursAtelier"],
				"texte": "1. Construis. 2. Donne un nom et un usage (maison, école, stade…). 3. Enregistre. Le bandeau te dit où tu en es."},
			{"titre": "Murs et étages", "creer": true, "cible": ["Murs et étages"], "section": false,
				"texte": "Trace des murs sur la grille, ajoute des pièces, des portes, des fenêtres, des escaliers et un toit. Étage par étage.",
				"touches": "Page haut / Page bas : changer d'étage"},
			{"titre": "Blocs de 1 m", "creer": true, "cible": ["Blocs"], "section": false,
				"texte": "Pour les formes libres : cubes, pentes, arrondis, 384 matériaux. Comme des briques, mais sans marcher dessus pieds nus.",
				"touches": "R : tourner · F : renverser · C : coucher"},
			{"titre": "Enregistrer mon bâtiment", "creer": true, "racine": "parcours", "cible": ["EnregistrerBatiment", "Enregistrer mon bâtiment"], "section": false,
				"texte": "Quand il te plaît, enregistre-le. Il rejoint Construire › Mes modèles, dans toutes tes parties."},
		]},
	{"id": "vue_sol", "titre": "Ton personnage", "icone": "habitants", "theme": "Créer",
		"resume": "Descendre dans la rue, marcher, entrer, monter à bord.",
		"declencheur": {"vue_sol": true},
		"bulles": [
			{"titre": "À hauteur d'habitant", "texte": "Te voilà dans la rue, avec ton personnage. Visite ta ville comme ses habitants la voient.",
				"touches": "ZQSD : marcher · Maj : courir · Espace : sauter · souris : regarder"},
			{"titre": "Entrer et regarder", "texte": "Approche-toi d'un bâtiment ouvert ou d'un chantier et regarde de près. Les intérieurs meublés se visitent.",
				"touches": "E : interagir"},
			{"titre": "Monter à bord", "texte": "Près d'un bus, d'un train ou d'une voiture, E te fait monter. Tu peux conduire ou te laisser porter.",
				"touches": "E : monter / descendre · Maj + E : changer de véhicule"},
			{"titre": "Remonter", "texte": "V passe en 1re personne, puis te ramène dans ton fauteuil de maire, vue de dessus.",
				"touches": "V : changer de vue"},
		]},
	{"id": "decors", "titre": "Les décors", "icone": "decors", "theme": "Créer",
		"resume": "Bancs, fontaines, arbres, clôtures : embellir la ville.",
		"declencheur": {"panneau": "decors_panel"},
		"bulles": [
			{"titre": "Embellir", "panneau": "decors_panel", "panneau_entier": true,
				"texte": "Bancs, lampadaires, fontaines, statues, clôtures, rochers : plus de 160 objets pour donner une âme à ta ville.",
				"touches": "G : décors"},
			{"titre": "Le pinceau", "panneau": "decors_panel", "cible": ["Pinceau", "Densité"], "section": false,
				"texte": "Pour les fleurs, les arbres ou les cailloux, peins-les d'un coup avec le pinceau. Règle sa taille et sa densité."},
			{"titre": "Décors automatiques", "panneau": "decors_panel", "cible": ["Décors automatiques"], "section": false,
				"texte": "Pas le temps ? Les décors automatiques garnissent les rues et les places tout seuls."},
		]},
	{"id": "zoo", "titre": "Le zoo", "icone": "zoo", "theme": "Loisirs",
		"resume": "Enclos, animaux, visiteurs et échanges.",
		"declencheur": {"panneau": "zoo_panel"},
		"bulles": [
			{"titre": "Fonder un zoo", "panneau": "zoo_panel", "cible": ["Fonder un zoo", "Zoo"],
				"texte": "Tout commence par l'entrée, au bord d'une route. Les enclos et bâtiments à moins de 400 m en font partie.",
				"touches": "Maj + Z : zoo"},
			{"titre": "Les enclos", "panneau": "zoo_panel", "cible": ["Enclos"], "section": false,
				"texte": "Trace un enclos (un clic par coin) et choisis sa barrière. Un lion derrière une clôture de jardin, c'est non."},
			{"titre": "Le terrain", "panneau": "zoo_panel", "cible": ["Terrain"], "section": false,
				"texte": "Chaque espèce aime son sol, son eau et son climat : herbe, sable, rocher, bassin, arbres."},
			{"titre": "Les animaux", "panneau": "zoo_panel", "cible": ["Animaux"], "section": false,
				"texte": "34 espèces à acheter au marché, à nourrir et à soigner. Les petits naissent mieux si les parents ne sont pas cousins."},
			{"titre": "Les visiteurs", "panneau": "zoo_panel", "cible": ["Visiteurs"], "section": false,
				"texte": "Variété, bien-être, vue sur les enclos, restaurants et prix du billet font la note du zoo… et ses recettes."},
		]},
	{"id": "musee", "titre": "Le musée", "icone": "musee", "theme": "Loisirs",
		"resume": "Salles, objets, expositions et visiteurs.",
		"declencheur": {"panneau": "musee_panel"},
		"bulles": [
			{"titre": "Ton musée", "panneau": "musee_panel", "cible": ["Mon musée"], "section": false,
				"texte": "Pose un musée prêt à visiter, ou bâtis le tien salle par salle.",
				"touches": "Maj + C : musée"},
			{"titre": "Bâtir et aménager", "panneau": "musee_panel", "cible": ["Bâtir", "Salles"], "section": false,
				"texte": "Choisis les sols et les murs, puis la fonction de chaque salle : exposition, boutique, café…"},
			{"titre": "Les objets", "panneau": "musee_panel", "cible": ["Objets"], "section": false,
				"texte": "208 objets dans 24 thèmes : dinosaures, peinture, trains, Égypte… Une collection complète attire plus de monde."},
			{"titre": "Les expositions", "panneau": "musee_panel", "cible": ["Expositions"], "section": false,
				"texte": "Fais venir une exposition temporaire : les visiteurs reviennent, la gazette en parle."},
		]},
	{"id": "parc", "titre": "Le parc d'attractions", "icone": "parc", "theme": "Loisirs",
		"resume": "Créer un parc, poser des attractions, régler les billets.",
		"declencheur": {"panneau": "parc_panel"},
		"bulles": [
			{"titre": "Un parc de loisirs", "panneau": "parc_panel", "panneau_entier": true,
				"texte": "L'entrée du parc se pose au bord d'une route. Tout ce qui est à moins de 250 m en fait partie, la clôture se dessine toute seule.",
				"touches": "Maj + G : parc · Maj + A : créer un parc"},
			{"titre": "Les billets", "panneau": "parc_panel", "cible": ["Billets"],
				"texte": "Entrée, prix des tours : trop cher, les visiteurs boudent ; trop bon marché, la caisse pleure."},
			{"titre": "La note du parc", "panneau": "parc_panel", "cible": ["Note du parc"],
				"texte": "Variété, propreté, files d'attente, fiabilité : les visiteurs notent tout. Les conseils disent quoi améliorer."},
			{"titre": "Créer ses attractions", "texte": "Dans « Créer un parc », pose des manèges, des allées, des files d'attente… et dessine ton propre grand huit, pièce par pièce.",
				"touches": "Maj + A : créer un parc"},
		]},
	{"id": "club", "titre": "Le club de sport", "icone": "sport", "theme": "Loisirs",
		"resume": "Foot, basket, hand, hockey, rugby, tennis : gérer ton club.",
		"declencheur": {"panneau": "club_panel"},
		"bulles": [
			{"titre": "Ton club", "panneau": "club_panel", "cible": ["Club"], "section": false,
				"texte": "Fonde un club dans le sport de ton choix. Il lui faut un stade ou une salle, et des joueurs.",
				"touches": "Maj + B : club"},
			{"titre": "L'effectif", "panneau": "club_panel", "cible": ["Effectif"], "section": false,
				"texte": "Choisis tes titulaires, surveille la forme. Les espoirs viennent de la formation, les vedettes des transferts."},
			{"titre": "Les matchs", "panneau": "club_panel", "cible": ["Calendrier", "Classement"], "section": false,
				"texte": "Le calendrier donne les prochains matchs, le classement dit si tu montes ou descends. Va voir le match au stade !"},
			{"titre": "Supporters et finances", "panneau": "club_panel", "cible": ["Supporters", "Finances"], "section": false,
				"texte": "Des victoires remplissent les tribunes, les abonnements et la caisse. Des défaites… remplissent la gazette."},
		]},
	{"id": "production", "titre": "Production et économie", "icone": "ressources", "theme": "Gérer la ville",
		"resume": "Ressources, marchandises, entreprises et livraisons.",
		"declencheur": {"panneau": "production_panel"},
		"bulles": [
			{"titre": "D'où viennent les choses", "panneau": "production_panel", "panneau_entier": true,
				"texte": "Fermes, mines, usines, commerces : chaque entreprise achète, produit et vend. Les camions livrent sur les routes.",
				"touches": "P : production · Maj + F : agriculture · Maj + S : commerce mondial"},
			{"titre": "Ressources du sol", "panneau": "production_panel", "cible": ["Ressources", "Production · ressources"], "section": false,
				"texte": "Bois, pierre, minerai, pétrole : la carte montre ce que cache ton terrain. Ouvre une carrière ou une mine là où c'est riche."},
		]},
	{"id": "pays", "titre": "Ton pays", "icone": "globe", "theme": "Gérer la ville",
		"resume": "Plusieurs villes, chacune sa caisse, et le kit de l'État.",
		"declencheur": {"panneau": "pays_panel"},
		"bulles": [
			{"titre": "Un pays, des villes", "panneau": "pays_panel", "panneau_entier": true,
				"texte": "Ton pays chapeaute tes villes. Chacune a sa propre caisse et se gère à part. Tu peux confier une ville au pilote automatique.",
				"touches": "Maj + P : pays · Maj + M : villages"},
			{"titre": "Décisions du pays", "panneau": "pays_panel", "cible": ["Décisions du pays"],
				"texte": "Virements entre villes, kit d'installation de l'État pour la première ville : des bons pour l'électricité, l'eau, les égouts et les déchets."},
		]},
	{"id": "objectifs", "titre": "Objectifs et rangs", "icone": "trophee", "theme": "Gérer la ville",
		"resume": "Missions du pays, défi du jour, rangs des villes, succès.",
		"declencheur": {"panneau": "objectifs_panel"},
		"bulles": [
			{"titre": "Missions du pays", "panneau": "objectifs_panel", "cible": ["Missions du pays", "Missions en cours"],
				"texte": "Le pays te confie des missions avec une prime et un délai. Elles sont aussi résumées en haut à gauche de l'écran.",
				"touches": "Maj + J : objectifs"},
			{"titre": "Rangs des villes", "panneau": "objectifs_panel", "cible": ["Rangs des villes"],
				"texte": "Hameau, Village, Bourg, Ville… Chaque rang demande des habitants, des services et des gens contents."},
			{"titre": "Succès", "panneau": "objectifs_panel", "cible": ["Succès"],
				"texte": "62 médailles à décrocher, des plus simples aux plus farfelues.",
				"touches": "F6 : succès"},
		]},
]

static var instance: Guide
## false dans les tests : rien n'est écrit dans user://.
static var persist := true

## Scène Terre.
var scene: Node
var bulles: BullesAide
## Chapitres vus jusqu'au bout : id -> true.
var vus := {}
## Proposer un chapitre quand on découvre une fonction.
var proposer := true
## Chapitres proposés pendant cette session (« Plus tard ») : id -> true.
var _proposes := {}
## Chapitre en attente de réponse dans la bulle de proposition ("" : aucun).
var propose := ""
var _acc := 0.0
## Renvoie true quand il ne faut rien proposer (tutoriel en cours…).
var bloque: Callable


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func setup(s: Node, b: BullesAide) -> void:
	scene = s
	bulles = b
	charger()
	bulles.termine.connect(_on_termine)
	bulles.action.connect(_on_action)


static func chapitre(id: String) -> Dictionary:
	for c in CHAPITRES:
		if String(c.id) == id:
			return c
	return {}


static func bulles_de(id: String) -> Array:
	return chapitre(id).get("bulles", [])


## Lance un chapitre (depuis le panneau Guide, une proposition ou le tutoriel).
func lancer(id: String) -> void:
	var c := chapitre(id)
	if c.is_empty():
		return
	propose = ""
	bulles.lancer("guide:" + id, String(c.titre), c.bulles, "Terminer")


func est_vu(id: String) -> bool:
	return vus.has(id)


func nb_vus() -> int:
	return vus.size()


func set_proposer(on: bool) -> void:
	proposer = on
	sauver()
	changed.emit()


func _on_termine(suite: String, au_bout: bool) -> void:
	if suite == "proposition":
		propose = ""
		return
	if suite.begins_with("guide:") and au_bout:
		vus[suite.trim_prefix("guide:")] = true
		sauver()
		changed.emit()


func _on_action(a: String) -> void:
	match a:
		"guide_decouvrir":
			var id := propose
			_proposes[id] = true
			lancer(id)
		"guide_plus_tard":
			_proposes[propose] = true
			bulles.fermer()
		"guide_jamais":
			_proposes[propose] = true
			set_proposer(false)
			bulles.fermer()


# --- Propositions ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	_acc += delta
	if _acc < 0.5:
		return
	_acc = 0.0
	verifier()


## Propose le chapitre d'une fonction qu'on vient d'ouvrir pour la première fois.
func verifier() -> void:
	if not proposer or scene == null or bulles == null or bulles.actif:
		return
	if bloque.is_valid() and bool(bloque.call()):
		return
	var id := a_proposer()
	if id != "":
		proposer_chapitre(id)


## Chapitre dont la fonction est ouverte, pas encore vu ni proposé ("" : aucun).
func a_proposer() -> String:
	for c in CHAPITRES:
		var id := String(c.id)
		if vus.has(id) or _proposes.has(id):
			continue
		if _declenche(c.declencheur):
			return id
	return ""


func _declenche(d: Dictionary) -> bool:
	if d.has("panneau"):
		var n = scene.get(String(d.panneau))
		return n is Node and is_instance_valid(n) and BullesAide.est_ouvert(n)
	if d.has("mode"):
		var hud = scene.get("hud")
		return hud != null and bool(hud.get("create_mode"))
	if d.has("vue_sol"):
		var vs := scene.get_node_or_null("VueSol")
		return vs != null and int(vs.get("vue")) != 0
	return false


func proposer_chapitre(id: String) -> void:
	var c := chapitre(id)
	if c.is_empty():
		return
	propose = id
	bulles.lancer("proposition", "Guide", [{
		"titre": "Nouveau : %s" % String(c.titre),
		"texte": "%s\nVeux-tu une petite visite en %d bulles ?" % [String(c.resume), (c.bulles as Array).size()],
		"touches": "Ctrl + F1 : tous les chapitres du guide",
		"action": ["Découvrir", "guide_decouvrir"],
	}, ], "Plus tard")
	_proposes[id] = true


# --- Préférences du joueur -----------------------------------------------------------------------

func charger() -> void:
	vus.clear()
	proposer = true
	if not persist:
		return
	var cf := ConfigFile.new()
	if cf.load(FICHIER) != OK:
		return
	proposer = bool(cf.get_value("guide", "proposer", true))
	for k in cf.get_value("guide", "vus", []):
		vus[String(k)] = true


func sauver() -> void:
	if not persist:
		return
	var cf := ConfigFile.new()
	cf.set_value("guide", "proposer", proposer)
	cf.set_value("guide", "vus", vus.keys())
	cf.save(FICHIER)


## Remet le guide à zéro (tous les chapitres redeviennent nouveaux).
func oublier() -> void:
	vus.clear()
	_proposes.clear()
	proposer = true
	sauver()
	changed.emit()
