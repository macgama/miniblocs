class_name Succes
extends RefCounted
## Succès du joueur (Steam ou non) : ils valent pour toutes les parties, comme sur
## Steam, et sont gardés dans user://succes.cfg avec les compteurs qui servent à les
## débloquer (incendies vus, bâtiments démolis, minutes à la manette…).
##
## - Les 21 succès des Objectifs (Maj+J, Objectifs.SUCCES) gardent leur id et leur nom :
##   débloqués dans une partie, ils le sont aussi ici.
## - Les autres sont débloqués par un compteur (« stat ») qui atteint un seuil.
##   SuccesSuivi (dans la partie) relève les chiffres de la ville ; les événements
##   ajoutent à leur compteur (Succes.ajouter).
## - SteamPont reporte chaque succès sur Steam quand le jeu tourne avec GodotSteam.
##
## Réglage de partie « argent illimité » : aucun succès, et les compteurs n'avancent pas
## (choix de Gaël, 2026-11-15).

## Succès débloqués depuis le lancement du jeu, dans l'ordre (notifications, tests).
static var recents: Array = []

static var fichier := "user://succes.cfg"
## Pas d'écriture sur le disque (tests).
static var persist := true

## Nouveaux succès : id -> {nom, desc, icone, stat, seuil, cache}.
## stat "" : débloqué directement par le code (Succes.debloquer).
## Ton : réaliste, avec une touche d'humour.
const NOUVEAUX := [
	# Premiers pas
	{"id": "premier_coup_de_pelle", "nom": "Premier coup de pelle", "desc": "Poser ton premier bâtiment.", "icone": "construire", "stat": "batiments", "seuil": 1},
	{"id": "route_nulle_part", "nom": "La route de nulle part", "desc": "Tracer 1 km de route. Où elle mène ? On verra plus tard.", "icone": "route", "stat": "route_m", "seuil": 1000},
	{"id": "ponts_et_chaussees", "nom": "Ponts et Chaussées", "desc": "Avoir 25 km de routes.", "icone": "route", "stat": "route_m", "seuil": 25000},
	{"id": "tour_de_france", "nom": "Le tour de France", "desc": "Avoir 200 km de routes. Le Tour peut passer chez toi.", "icone": "route", "stat": "route_m", "seuil": 200000},
	{"id": "cent_toits", "nom": "Cent toits", "desc": "Avoir 100 bâtiments.", "icone": "logement", "stat": "batiments", "seuil": 100},
	{"id": "permis_accorde", "nom": "Permis accordé", "desc": "Avoir 1 000 bâtiments. Le service de l'urbanisme demande des vacances.", "icone": "logement", "stat": "batiments", "seuil": 1000},
	{"id": "eleve_modele", "nom": "Élève modèle", "desc": "Aller au bout du tutoriel. Le prof est fier de toi.", "icone": "ecole", "stat": "tutoriel_fini", "seuil": 1},
	{"id": "visite_guidee", "nom": "Visite guidée", "desc": "Aller au bout de la démo guidée.", "icone": "trophee", "stat": "demo_finie", "seuil": 1},
	# Population
	{"id": "cent_mille", "nom": "Préfecture", "desc": "100 000 habitants dans le pays.", "icone": "habitants", "stat": "habitants", "seuil": 100000},
	{"id": "million", "nom": "Le million !", "desc": "1 000 000 d'habitants. Il va falloir une deuxième boulangerie.", "icone": "habitants", "stat": "habitants", "seuil": 1000000},
	{"id": "plein_emploi", "nom": "Plein emploi", "desc": "Moins de 2 % de chômage avec 500 habitants ou plus. Les économistes n'en reviennent pas.", "icone": "emploi", "stat": "plein_emploi", "seuil": 1},
	{"id": "bebe_boom", "nom": "Baby-boom", "desc": "Voir naître 100 bébés dans une même partie.", "icone": "habitants", "stat": "naissances", "seuil": 100},
	{"id": "memoire_vive", "nom": "Mémoire vive", "desc": "Accompagner 50 habitants jusqu'à leur dernier repos.", "icone": "fleur", "stat": "deces", "seuil": 50},
	# Argent et mairie
	{"id": "dans_le_rouge", "nom": "Dans le rouge", "desc": "Passer la caisse sous zéro. Ça arrive aux meilleurs.", "icone": "budget", "stat": "dans_le_rouge", "seuil": 1, "cache": true},
	{"id": "sous_tutelle", "nom": "Le préfet s'invite", "desc": "Être mis sous tutelle. Il a apporté des croissants, au moins.", "icone": "budget", "stat": "tutelle", "seuil": 1, "cache": true},
	{"id": "banquier_ami", "nom": "Mon banquier est mon ami", "desc": "Avoir 3 emprunts en cours.", "icone": "budget", "stat": "emprunts", "seuil": 3},
	{"id": "oncle_picsou", "nom": "Bas de laine", "desc": "Avoir 500 M€ en caisse.", "icone": "budget", "stat": "caisse", "seuil": 500000000},
	{"id": "battu_aux_urnes", "nom": "Le peuple a parlé", "desc": "Perdre une élection. Tu peux toujours construire, mais plus décider.", "icone": "urne", "stat": "mairie_perdue", "seuil": 1, "cache": true},
	{"id": "fete_au_village", "nom": "Fête au village", "desc": "Organiser 10 marchés ou fêtes.", "icone": "fete", "stat": "fetes", "seuil": 10},
	# Ville vivante
	{"id": "pompier_de_service", "nom": "Pompier de service", "desc": "Voir 25 incendies se déclarer. Il serait peut-être temps de construire une caserne.", "icone": "feu", "stat": "incendies", "seuil": 25},
	{"id": "apres_la_pluie", "nom": "Après la pluie", "desc": "Traverser 5 tempêtes, crues ou inondations.", "icone": "tempete", "stat": "catastrophes", "seuil": 5},
	{"id": "demolisseur", "nom": "Démolition Express", "desc": "Démolir 100 bâtiments. Les riverains apprécient.", "icone": "demolir", "stat": "demolitions", "seuil": 100},
	{"id": "heure_de_pointe", "nom": "Périphérique à 18 h", "desc": "Plus de 40 % du temps perdu dans les bouchons, avec 1 000 habitants ou plus.", "icone": "circulation", "stat": "bouchons", "seuil": 1, "cache": true},
	{"id": "tri_selectif", "nom": "Champion du tri", "desc": "Recycler plus de la moitié des déchets.", "icone": "dechets", "stat": "recyclage", "seuil": 1},
	{"id": "terminus", "nom": "Terminus, tout le monde descend", "desc": "Ouvrir 5 lignes de transport en commun.", "icone": "lignes", "stat": "lignes", "seuil": 5},
	{"id": "un_an", "nom": "Joyeux anniversaire", "desc": "Jouer une année entière dans la même partie.", "icone": "horloge", "stat": "jours", "seuil": 365},
	{"id": "dix_ans", "nom": "Deux mandats", "desc": "Jouer dix ans dans la même partie.", "icone": "horloge", "stat": "jours", "seuil": 3650},
	# Loisirs
	{"id": "arche", "nom": "L'arche du maire", "desc": "Accueillir 10 espèces au zoo.", "icone": "zoo", "stat": "especes_zoo", "seuil": 10},
	{"id": "conservateur", "nom": "Conservateur en chef", "desc": "Exposer 50 objets dans tes musées.", "icone": "musee", "stat": "objets_musee", "seuil": 50},
	{"id": "coup_d_envoi", "nom": "Coup d'envoi", "desc": "Fonder un club de sport.", "icone": "sport", "stat": "clubs", "seuil": 1},
	{"id": "on_est_champions", "nom": "On est les champions !", "desc": "Gagner un titre avec un de tes clubs.", "icone": "trophee", "stat": "titres", "seuil": 1},
	{"id": "carte_postale", "nom": "Carte postale", "desc": "Accueillir 500 touristes en même temps.", "icone": "valise", "stat": "touristes", "seuil": 500},
	# Créer et explorer
	{"id": "architecte", "nom": "Architecte du dimanche", "desc": "Enregistrer une création dans l'Atelier.", "icone": "atelier", "stat": "creations", "seuil": 1},
	{"id": "les_pieds_sur_terre", "nom": "Les pieds sur terre", "desc": "Descendre marcher dans ta ville (V).", "icone": "pieton", "stat": "vue_sol", "seuil": 1},
	{"id": "prochain_arret", "nom": "Prochain arrêt", "desc": "Monter à bord d'un véhicule (E).", "icone": "vehicules", "stat": "a_bord", "seuil": 1},
	{"id": "sous_les_paves", "nom": "Sous les pavés", "desc": "Regarder sous la ville (Page bas).", "icone": "souterrain", "stat": "souterrain", "seuil": 1},
	{"id": "pied_au_plancher", "nom": "Pied au plancher", "desc": "Passer le temps à la vitesse maximale.", "icone": "horloge", "stat": "vitesse_max", "seuil": 1},
	{"id": "pause_cafe", "nom": "Pause café", "desc": "Laisser le temps en pause 10 minutes. Le café était bon ?", "icone": "pause", "stat": "pause_s", "seuil": 600, "cache": true},
	{"id": "maire_insomniaque", "nom": "Maire insomniaque", "desc": "Jouer entre 3 h et 5 h du matin (pour de vrai).", "icone": "lune", "stat": "nuit_blanche", "seuil": 1, "cache": true},
	{"id": "pouces_verts", "nom": "Pouces verts", "desc": "Jouer 30 minutes à la manette.", "icone": "manette", "stat": "manette_min", "seuil": 30},
	{"id": "tour_du_monde", "nom": "Tour du monde", "desc": "Fonder des villes sur 3 continents différents.", "icone": "globe", "stat": "continents", "seuil": 3},
]

## Profil : succès débloqués (id -> date unix) et compteurs (stat -> valeur).
static var debloques: Dictionary = {}
static var stats: Dictionary = {}
static var _charge := false
static var _sale := false


## Tous les succès, dans l'ordre d'affichage : ceux des Objectifs, puis les nouveaux.
static func catalogue() -> Array:
	var out: Array = []
	for id in Objectifs.SUCCES:
		var s: Array = Objectifs.SUCCES[id]
		out.append({"id": String(id), "nom": String(s[0]), "desc": String(s[1]), "icone": "trophee", "stat": "", "seuil": 1, "objectifs": true})
	for s in NOUVEAUX:
		out.append(s)
	return out


static func info(id: String) -> Dictionary:
	for s in catalogue():
		if String(s.id) == id:
			return s
	return {}


static func existe(id: String) -> bool:
	return not info(id).is_empty()


## Nom de l'API Steam (lettres majuscules, chiffres, _) : MB_ + id.
static func api_steam(id: String) -> String:
	return "MB_" + id.to_upper()


static func charger() -> void:
	if _charge:
		return
	_charge = true
	debloques = {}
	stats = {}
	if not persist:
		return
	var cf := ConfigFile.new()
	if cf.load(fichier) != OK:
		return
	for k in cf.get_section_keys("debloques") if cf.has_section("debloques") else []:
		debloques[String(k)] = int(cf.get_value("debloques", k, 0))
	for k in cf.get_section_keys("stats") if cf.has_section("stats") else []:
		stats[String(k)] = float(cf.get_value("stats", k, 0.0))


static func sauver() -> void:
	_sale = false
	if not persist:
		return
	var cf := ConfigFile.new()
	for k in debloques:
		cf.set_value("debloques", k, debloques[k])
	for k in stats:
		cf.set_value("stats", k, stats[k])
	cf.save(fichier)


## Écrit le profil s'il a changé (appelé de temps en temps, pas à chaque compteur).
static func sauver_si_besoin() -> void:
	if _sale:
		sauver()


## Remet tout à zéro (tests, ou Options → « Effacer mes succès »).
static func reinitialiser() -> void:
	_charge = true
	debloques = {}
	stats = {}
	sauver()


static func est_debloque(id: String) -> bool:
	charger()
	return debloques.has(id)


static func nombre() -> int:
	charger()
	var n := 0
	for s in catalogue():
		if debloques.has(String(s.id)):
			n += 1
	return n


static func total() -> int:
	return catalogue().size()


## Débloque un succès (une seule fois). Renvoie true s'il vient d'être débloqué.
static func debloquer(id: String) -> bool:
	charger()
	# Édition démo : pas de succès (Valve conseille de les couper dans une démo).
	if debloques.has(id) or not existe(id) or argent_illimite or EditionDemo.active():
		return false
	debloques[id] = int(Time.get_unix_time_from_system())
	sauver()
	SteamPont.debloquer(api_steam(id))
	recents.append(id)
	# Carte « Succès débloqué » (nœud global SuccesNotif, s'il est là).
	var tree := Engine.get_main_loop() as SceneTree
	var notif := tree.root.get_node_or_null("SuccesNotif") if tree != null else null
	if notif != null and notif.has_method("annoncer"):
		notif.annoncer(id)
	return true


static func stat(nom: String) -> float:
	charger()
	return float(stats.get(nom, 0.0))


## Garde la plus grande valeur vue (habitants, km de route…).
static func noter(nom: String, v: float) -> void:
	charger()
	if argent_illimite:
		return
	if v > float(stats.get(nom, 0.0)):
		stats[nom] = v
		_sale = true
		_verifier(nom)


## Ajoute à un compteur (incendies, démolitions…).
static func ajouter(nom: String, n := 1.0) -> void:
	charger()
	if n == 0.0 or argent_illimite:
		return
	stats[nom] = float(stats.get(nom, 0.0)) + n
	_sale = true
	_verifier(nom)


## Argent illimité dans la partie en cours : tous les succès sont coupés.
static var argent_illimite := false


static func _verifier(nom: String) -> void:
	var v := float(stats.get(nom, 0.0))
	for s in NOUVEAUX:
		if String(s.stat) != nom or debloques.has(String(s.id)):
			continue
		if v >= float(s.seuil):
			debloquer(String(s.id))
		elif s.has("seuil") and float(s.seuil) > 1.0:
			SteamPont.progres(api_steam(String(s.id)), v, float(s.seuil))


## Avancement d'un succès à compteur (0..1), -1 s'il n'en a pas.
static func avancement(id: String) -> float:
	var s := info(id)
	if s.is_empty() or String(s.get("stat", "")) == "" or float(s.seuil) <= 1.0:
		return -1.0
	return clampf(stat(String(s.stat)) / float(s.seuil), 0.0, 1.0)


## Après la connexion à Steam : chaque succès gagné hors ligne est reporté, et ceux
## gagnés sur un autre ordinateur reviennent ici.
static func synchroniser_steam() -> void:
	charger()
	if not SteamPont.actif():
		return
	var change := false
	for s in catalogue():
		var id := String(s.id)
		var sur_steam := SteamPont.est_debloque(api_steam(id))
		if debloques.has(id) and not sur_steam:
			SteamPont.debloquer(api_steam(id), false)
		elif sur_steam and not debloques.has(id):
			debloques[id] = int(Time.get_unix_time_from_system())
			change = true
	SteamPont.envoyer()
	if change:
		sauver()
