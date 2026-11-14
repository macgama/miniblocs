class_name SpectaclesProgrammes
extends RefCounted
## Ce qu'on peut voir dans les salles : genres, spectacles en tournée (concerts,
## pièces, opéras, ballets, cirques…), films à l'affiche, et tout ce qu'il faut
## pour produire un film (budgets, réalisateurs, têtes d'affiche, titres).
## Les artistes et les films sont inventés ; les pièces et opéras du domaine
## public gardent leur vrai titre.

## Goût du public par tranche d'âge : enfants (< 12), jeunes (12–29),
## adultes (30–59), seniors (60 +). 1 = goût moyen.
const GENRES := {
	# Films.
	"action": {"name": "Action", "famille": "film", "gout": [0.4, 1.5, 1.1, 0.6]},
	"comedie_film": {"name": "Comédie", "famille": "film", "gout": [0.9, 1.1, 1.2, 1.0]},
	"drame_film": {"name": "Drame", "famille": "film", "gout": [0.1, 0.8, 1.1, 1.3]},
	"animation": {"name": "Animation", "famille": "film", "gout": [2.2, 0.9, 0.9, 0.5]},
	"horreur": {"name": "Horreur", "famille": "film", "gout": [0.0, 1.7, 0.7, 0.2]},
	"sf": {"name": "Science-fiction", "famille": "film", "gout": [0.6, 1.5, 1.0, 0.5]},
	"policier": {"name": "Policier", "famille": "film", "gout": [0.2, 1.0, 1.2, 1.2]},
	"aventure": {"name": "Aventure", "famille": "film", "gout": [1.5, 1.2, 1.0, 0.7]},
	"romance": {"name": "Romance", "famille": "film", "gout": [0.1, 1.2, 1.0, 1.0]},
	"documentaire": {"name": "Documentaire", "famille": "film", "gout": [0.4, 0.6, 1.0, 1.4]},
	"western": {"name": "Western", "famille": "film", "gout": [0.4, 0.6, 1.0, 1.5]},
	"historique": {"name": "Historique", "famille": "film", "gout": [0.3, 0.7, 1.1, 1.5]},
	# Musique.
	"classique": {"name": "Musique classique", "famille": "concert", "gout": [0.4, 0.4, 0.9, 1.8]},
	"jazz": {"name": "Jazz", "famille": "concert", "gout": [0.1, 0.6, 1.1, 1.4]},
	"rock": {"name": "Rock", "famille": "concert", "gout": [0.3, 1.4, 1.2, 0.6]},
	"pop": {"name": "Pop", "famille": "concert", "gout": [1.0, 1.7, 0.9, 0.4]},
	"rap": {"name": "Rap", "famille": "concert", "gout": [0.4, 2.0, 0.6, 0.1]},
	"electro": {"name": "Électro", "famille": "concert", "gout": [0.0, 2.0, 0.6, 0.1]},
	"metal": {"name": "Métal", "famille": "concert", "gout": [0.0, 1.2, 0.8, 0.2]},
	"chanson": {"name": "Chanson française", "famille": "concert", "gout": [0.4, 0.6, 1.1, 1.6]},
	"monde": {"name": "Musiques du monde", "famille": "concert", "gout": [0.5, 0.9, 1.1, 1.0]},
	"fanfare": {"name": "Fanfare et kiosque", "famille": "concert", "gout": [1.2, 0.4, 0.8, 1.4]},
	# Scène.
	"theatre_classique": {"name": "Théâtre classique", "famille": "theatre", "gout": [0.3, 0.7, 1.0, 1.5]},
	"comedie": {"name": "Comédie", "famille": "theatre", "gout": [0.5, 0.9, 1.2, 1.2]},
	"boulevard": {"name": "Théâtre de boulevard", "famille": "theatre", "gout": [0.2, 0.5, 1.1, 1.7]},
	"drame": {"name": "Théâtre contemporain", "famille": "theatre", "gout": [0.1, 0.9, 1.1, 0.9]},
	"comedie_musicale": {"name": "Comédie musicale", "famille": "theatre", "gout": [1.2, 1.3, 1.0, 0.9]},
	"opera": {"name": "Opéra", "famille": "theatre", "gout": [0.2, 0.4, 0.9, 1.8]},
	"ballet": {"name": "Ballet", "famille": "theatre", "gout": [0.9, 0.5, 0.9, 1.5]},
	"danse": {"name": "Danse contemporaine", "famille": "theatre", "gout": [0.3, 1.0, 1.0, 0.8]},
	"humour": {"name": "Humour", "famille": "theatre", "gout": [0.3, 1.4, 1.2, 0.9]},
	"cirque": {"name": "Cirque", "famille": "theatre", "gout": [2.0, 0.8, 1.0, 0.9]},
	"marionnettes": {"name": "Jeune public", "famille": "theatre", "gout": [2.6, 0.2, 0.8, 0.5]},
}

## Spectacles en tournée : [nom, genre, notoriété 1–100, cachet par date (€),
## salle minimale (places), description]. La notoriété attire le public (et la
## région pour les stars) ; une star ne joue pas dans une salle trop petite.
const TOURNEES := {
	# Classique.
	"orchestre_regional": ["Orchestre symphonique régional", "classique", 35, 16_000, 400, "Beethoven, Brahms et la toux de l'entracte."],
	"quatuor_cordes": ["Quatuor Les Cordes Sensibles", "classique", 22, 3_200, 60, "Quatre archets, un silence absolu, une chaise qui grince."],
	"recital_piano": ["Récital de piano : Chopin au clair de lune", "classique", 30, 4_000, 80, "Un piano à queue, une pianiste, deux rappels."],
	"philharmonique_international": ["Orchestre philharmonique international", "classique", 82, 95_000, 1500, "Cent musiciens et un chef qui ne regarde jamais la partition."],
	"chorale_ville": ["Grande chorale de la ville", "classique", 12, 600, 0, "Cent vingt choristes, dont votre boulanger (ténor)."],
	"ensemble_baroque": ["Ensemble baroque Les Perruques", "classique", 40, 12_000, 150, "Clavecin, violes de gambe et Vivaldi joué comme en 1725."],
	# Jazz.
	"trio_swing": ["Trio Swing Manouche", "jazz", 25, 2_400, 50, "Guitare, contrebasse, violon, et des doigts qui vont trop vite."],
	"big_band": ["Big Band de la Côte", "jazz", 40, 9_000, 250, "Dix-sept cuivres, un batteur, zéro partition fermée."],
	"nina_velours": ["Nina Velours", "jazz", 62, 26_000, 300, "Une voix grave, un piano, et la salle qui retient son souffle."],
	# Rock et métal.
	"rateaux_rouilles": ["Les Râteaux Rouillés", "rock", 28, 5_000, 150, "Rock de garage. Ils répètent vraiment dans un garage."],
	"electrons_libres": ["Électrons Libres", "rock", 55, 32_000, 700, "Guitares saturées et refrains que toute la fosse connaît."],
	"thunder_pigeons": ["Thunder Pigeons", "rock", 88, 260_000, 6000, "Tournée mondiale, trois semi-remorques de matériel."],
	"mamie_turbo": ["Mamie Turbo", "metal", 42, 14_000, 400, "Métal symphonique. Bouchons d'oreilles offerts à l'entrée."],
	"fracas": ["Fracas", "metal", 70, 85_000, 2000, "Pyrotechnie, double grosse caisse et pogo réglementaire."],
	# Pop.
	"lola_paillettes": ["Lola Paillettes", "pop", 48, 18_000, 500, "Des tubes, des paillettes et des chorégraphies à refaire chez soi."],
	"garcons_du_lundi": ["Les Garçons du Lundi", "pop", 66, 70_000, 1500, "Boys band. Les cris commencent avant le concert."],
	"stella_nova": ["Stella Nova", "pop", 96, 480_000, 8000, "La star planétaire. Les billets partent en quatre minutes."],
	# Rap et électro.
	"mc_bitume": ["MC Bitume", "rap", 44, 14_000, 400, "Rimes affûtées sur la vie de quartier et les nids-de-poule."],
	"lil_croissant": ["Lil Croissant", "rap", 76, 130_000, 3000, "Le rappeur qui a fait danser la boulangerie industrielle."],
	"collectif_beton": ["Collectif Béton Armé", "rap", 58, 40_000, 900, "Six voix, un DJ, et une énergie de chantier."],
	"dj_pixel": ["DJ Pixel", "electro", 38, 7_000, 200, "Platines, lasers et une casquette vissée."],
	"basse_frequence": ["Basse Fréquence", "electro", 72, 95_000, 2500, "Le duo électro qui fait vibrer les vitres à 300 m."],
	"nuit_electro": ["Nuit électro : six DJ jusqu'à l'aube", "electro", 55, 42_000, 1000, "On entre à 22 h, on ressort au lever du soleil."],
	# Chanson et musiques du monde.
	"jean_michel_accordeon": ["Jean-Michel Accordéon", "chanson", 32, 5_500, 120, "Bals, valses et une moustache impeccable."],
	"celeste_moreau": ["Céleste Moreau", "chanson", 72, 58_000, 1200, "Textes ciselés, salle en larmes au troisième titre."],
	"hommage_chanson": ["Hommage à la chanson française", "chanson", 30, 8_000, 250, "Trente ans de refrains, quatre chanteurs, un public qui chante plus fort."],
	"tambours_sahel": ["Les Tambours du Sahel", "monde", 40, 9_000, 250, "Douze percussionnistes. Le plancher danse aussi."],
	"salsa_caliente": ["Orchestre de salsa Caliente", "monde", 34, 6_500, 150, "Cuivres, congas et cours de danse improvisé dans les allées."],
	"gospel_soleil": ["Gospel Soleil Choir", "monde", 46, 9_000, 200, "Trente voix, des claquements de mains et la salle debout au rappel."],
	"racines_sound": ["Racines Sound System", "monde", 38, 7_000, 200, "Reggae, basses rondes et bonne humeur garantie."],
	"fanfare_municipale": ["Fanfare municipale", "fanfare", 10, 300, 0, "L'harmonie de la ville, son tuba et sa grosse caisse."],
	"pompe_a_velo": ["Brass band La Pompe à Vélo", "fanfare", 22, 1_200, 0, "Cuivres déchaînés et reprises de tubes à la trompette."],
	# Théâtre classique (domaine public).
	"malade_imaginaire": ["Le Malade imaginaire (Molière)", "theatre_classique", 55, 9_000, 250, "Argan, ses médecins, ses lavements. Trois siècles de rires."],
	"cyrano": ["Cyrano de Bergerac (Rostand)", "theatre_classique", 72, 17_000, 400, "Un nez, un panache, et le balcon le plus célèbre du théâtre."],
	"le_cid": ["Le Cid (Corneille)", "theatre_classique", 45, 8_000, 250, "« Rodrigue, as-tu du cœur ? » Les alexandrins volent."],
	"romeo_juliette": ["Roméo et Juliette (Shakespeare)", "theatre_classique", 62, 12_000, 300, "Deux familles, un balcon, une fin qu'on espère toujours différente."],
	"hamlet": ["Hamlet (Shakespeare)", "theatre_classique", 58, 12_000, 300, "Être ou ne pas être… à l'heure pour le dernier tram."],
	"avare": ["L'Avare (Molière)", "theatre_classique", 50, 8_500, 250, "Harpagon a perdu sa cassette. Le public, lui, a payé sa place."],
	# Comédie, boulevard, contemporain.
	"diner_voisins": ["Le Dîner des Voisins", "boulevard", 50, 9_000, 200, "Trois portes qui claquent, deux amants dans le placard."],
	"belle_mere_mardi": ["Ma Belle-Mère arrive mardi", "boulevard", 44, 7_000, 150, "Elle arrive lundi."],
	"pieds_dans_le_plat": ["Les Pieds dans le Plat", "comedie", 40, 6_000, 120, "Un repas de famille qui tourne à l'inventaire."],
	"prenom_du_chat": ["Le Prénom du Chat", "comedie", 56, 11_000, 250, "Un couple se dispute pendant deux heures sur le nom du chat."],
	"silence_on_se_dispute": ["Silence, on se dispute", "drame", 34, 5_000, 120, "Huis clos dans une cuisine, une fuite d'eau, des secrets."],
	"gens_d_en_face": ["Les Gens d'en face", "drame", 30, 4_500, 100, "Un immeuble, une cour, cinq fenêtres et autant de vies."],
	# Musical, lyrique, danse.
	"bal_lampadaires": ["Le Bal des Lampadaires", "comedie_musicale", 64, 45_000, 700, "Une comédie musicale sur l'éclairage public. Si. Et c'est un triomphe."],
	"pirates_en_chante": ["Pirates en chanté", "comedie_musicale", 54, 30_000, 500, "Abordages, perroquet et vingt chansons à reprendre en chœur."],
	"carmen": ["Carmen (Bizet)", "opera", 76, 62_000, 700, "L'amour est un oiseau rebelle, et l'orchestre est au complet."],
	"flute_enchantee": ["La Flûte enchantée (Mozart)", "opera", 70, 55_000, 700, "Un prince, un oiseleur, une Reine de la nuit très aiguë."],
	"traviata": ["La Traviata (Verdi)", "opera", 72, 58_000, 700, "Des bals, du champagne, un mouchoir pour le dernier acte."],
	"lac_des_cygnes": ["Le Lac des cygnes (Tchaïkovski)", "ballet", 78, 60_000, 700, "Trente-deux fouettés et des tutus blancs à perte de vue."],
	"casse_noisette": ["Casse-Noisette (Tchaïkovski)", "ballet", 70, 48_000, 600, "La féerie de Noël, en décembre la salle est pleine."],
	"bolero": ["Boléro et autres danses (Ravel)", "danse", 52, 22_000, 400, "Un seul thème, un crescendo de dix-sept minutes."],
	"corps_gravite": ["Compagnie Corps et Gravité", "danse", 36, 8_000, 150, "Danse contemporaine. On ne comprend pas tout, on est ému quand même."],
	# Humour, cirque, jeune public.
	"momo_rigolo": ["Momo Rigolo : seul en scène", "humour", 40, 6_000, 80, "Une heure sur les réunions de copropriété."],
	"gerard_raclette": ["Gérard Raclette fait le bilan", "humour", 68, 48_000, 800, "L'humoriste préféré des Français fait le bilan de sa vie. Et du vôtre."],
	"ligue_impro": ["Ligue d'improvisation", "humour", 26, 2_000, 60, "Le public lance les thèmes, les comédiens tremblent."],
	"cirque_etoiles": ["Cirque des Étoiles", "cirque", 62, 32_000, 600, "Acrobates, jongleurs, clowns. Pas d'animaux sauvages."],
	"cirque_vertige": ["Nouveau cirque Vertige", "cirque", 46, 16_000, 300, "Mât chinois, trapèze et musique live."],
	"guignol": ["Guignol et le Gendarme", "marionnettes", 30, 1_400, 40, "Les enfants préviennent Guignol. Très fort."],
	"pinocchio": ["Pinocchio en marionnettes", "marionnettes", 40, 3_500, 80, "Un nez qui pousse vraiment, à chaque mensonge."],
}

## Les tournées de chaque genre, dans l'ordre du catalogue.
static func tournees_de(genre: String) -> Array:
	var out: Array = []
	for id in TOURNEES:
		if String(TOURNEES[id][1]) == genre:
			out.append(id)
	return out


static func nom_tournee(id: String) -> String:
	return String(TOURNEES[id][0]) if TOURNEES.has(id) else id


static func genre_name(g: String) -> String:
	return String(GENRES[g].name) if GENRES.has(g) else g


## Prix de référence d'un billet pour une tournée (au-delà, le public hésite).
static func prix_ref(id: String) -> float:
	if not TOURNEES.has(id):
		return 15.0
	var n := float(TOURNEES[id][2])
	return 8.0 + n * 0.62


# --- Films ------------------------------------------------------------------------------------

## Budgets de film : [nom, budget hors cachets (€), jours de tournage, jours de
## post-production, bonus de qualité, entrées attendues à qualité 60, export].
const BUDGETS := {
	"court": ["Court métrage", 80_000, 5, 4, -6.0, 15_000, 0.0],
	"petit": ["Petit budget", 1_200_000, 12, 8, 0.0, 250_000, 0.3],
	"moyen": ["Budget moyen", 6_000_000, 20, 12, 5.0, 900_000, 0.6],
	"gros": ["Gros budget", 25_000_000, 30, 18, 9.0, 2_500_000, 1.0],
	"super": ["Superproduction", 90_000_000, 45, 25, 13.0, 6_000_000, 1.5],
}
const BUDGET_ORDER := ["court", "petit", "moyen", "gros", "super"]

## Réalisateurs : [nom, talent 0–100, cachet (€), genres préférés, mot].
const REALISATEURS := {
	"leo_premier": ["Léo Premier", 42, 30_000, [], "Sort de l'école, plein d'idées, aucune habitude."],
	"bernard_routine": ["Bernard Routine", 52, 140_000, ["comedie_film", "policier"], "Ses films ressemblent à ses films. Le public aime ça."],
	"claire_obscure": ["Claire Obscure", 66, 260_000, ["horreur", "policier", "drame_film"], "Elle tourne la nuit, même les comédies."],
	"aicha_doc": ["Aïcha Benali", 70, 180_000, ["documentaire", "historique", "drame_film"], "Deux ans de repérages, trois prix."],
	"paolo_spaghetti": ["Paolo Sartori", 74, 420_000, ["western", "policier", "aventure"], "Gros plans sur les yeux, longs silences, musique sublime."],
	"max_explosion": ["Max Boum", 70, 950_000, ["action", "sf", "aventure"], "Rien ne lui résiste, surtout pas les voitures."],
	"lin_animee": ["Lin Mei", 82, 600_000, ["animation", "sf", "aventure"], "Ses dessins animés font pleurer les adultes."],
	"jeanne_lumiere": ["Jeanne Lumière", 88, 800_000, ["drame_film", "romance", "historique"], "La palme d'or des festivals imaginaires."],
}
const REAL_ORDER := ["leo_premier", "bernard_routine", "claire_obscure", "aicha_doc", "paolo_spaghetti", "max_explosion", "lin_animee", "jeanne_lumiere"]

## Têtes d'affiche : [nom, notoriété 0–100, cachet (€), genres où elle brille, mot].
const STARS := {
	"inconnus": ["Des inconnus (casting local)", 0, 0, [], "Des habitants de la ville. Charme garanti, talent variable."],
	"kevin_du_coin": ["Kévin du Coin", 22, 40_000, ["comedie_film"], "Le comique de la ville. Il joue juste… parfois."],
	"chien_biscotte": ["Biscotte, le chien acteur", 35, 60_000, ["comedie_film", "aventure", "animation"], "Il ne lit pas les scénarios, il les mange."],
	"margot_etincelle": ["Margot Étincelle", 58, 600_000, ["romance", "comedie_film", "drame_film"], "La révélation de l'année dernière."],
	"bastien_machoire": ["Bastien Mâchoire", 70, 1_500_000, ["action", "policier", "sf"], "Il fait ses cascades lui-même, l'assureur pleure."],
	"reginald_pompous": ["Sir Reginald Pompous", 76, 2_000_000, ["historique", "drame_film", "aventure"], "Accent impeccable, perruque en option."],
	"victoire_grand": ["Victoire Grand", 88, 3_000_000, ["drame_film", "romance", "policier", "sf"], "La plus grande actrice de sa génération (elle le dit)."],
}
const STAR_ORDER := ["inconnus", "kevin_du_coin", "chien_biscotte", "margot_etincelle", "bastien_machoire", "reginald_pompous", "victoire_grand"]

## Décors qui aident un genre (annexes « decor » des studios), et effets spéciaux.
const DECOR_GENRES := {
	"western": ["western"],
	"ville": ["policier", "action", "comedie_film", "romance", "drame_film"],
	"chateau": ["historique", "aventure"],
	"espace": ["sf"],
	"mer": ["aventure", "action"],
}
const VFX_GENRES := ["sf", "action", "animation", "aventure", "horreur"]

## Mots pour inventer des titres de films.
const TITRES := {
	"action": ["Opération %s", "%s : riposte", "Zone rouge à %s", "Le Dernier Convoi", "Impact %s", "Course contre la montre"],
	"comedie_film": ["Les %s en vacances", "Mon voisin le %s", "Bienvenue chez les %s", "Tout le monde déménage", "Le Mariage de %s", "Rien ne va plus à %s"],
	"drame_film": ["L'Hiver de %s", "Ceux qui restent", "La Lettre", "Un été à %s", "Les Silences", "Après la pluie"],
	"animation": ["Le Petit %s", "Pipo et la forêt magique", "Les Aventures de %s", "La Fourmi géante", "Nuages", "Le Dragon timide"],
	"horreur": ["Ne réponds pas", "La Cave de %s", "Il est derrière toi", "Les Murmures", "Nuit noire à %s", "Le Grenier"],
	"sf": ["Odyssée %s", "Planète %s", "Les Androïdes rêvent-ils", "Orbite basse", "Horizon %s", "2147"],
	"policier": ["L'Affaire %s", "Quai des %s", "Le Commissaire et le Chat", "Brigade de nuit", "Témoin gênant", "Le Silence de %s"],
	"aventure": ["Le Trésor de %s", "L'Île aux %s", "Jusqu'au bout du monde", "La Carte perdue", "Les Naufragés", "Le Temple oublié"],
	"romance": ["Un amour à %s", "Coup de foudre au %s", "Toi et moi", "Les Lettres d'été", "Rendez-vous à %s", "Le Bal"],
	"documentaire": ["La Vie secrète des %s", "Au cœur de %s", "Ceux qui bâtissent", "L'Eau", "Mémoires de %s", "Le Grand Voyage des oies"],
	"western": ["Le Shérif de %s", "Poussière", "Pour quelques dollars de %s", "La Piste de %s", "Le Train de midi", "Les Sept Collines"],
	"historique": ["La Reine de %s", "Le Siège de %s", "1789", "L'Empereur", "Les Bâtisseurs de cathédrales", "La Révolte de %s"],
}
const MOTS_TITRES := ["Minuit", "Pigeons", "Castors", "Saturne", "Bretagne", "Tonnerre", "Lumière", "Sardines", "Cobalt", "Montmartre",
	"Bambous", "Océans", "Marmottes", "Velours", "Granit", "Hirondelles", "Mistral", "Nébuleuse", "Sablier", "Tournesols", "Bourgogne", "Phare"]


static func titre_au_hasard(genre: String, rng: RandomNumberGenerator) -> String:
	var l: Array = TITRES.get(genre, ["Sans titre"])
	var t := String(l[rng.randi() % l.size()])
	if t.contains("%s"):
		t = t % String(MOTS_TITRES[rng.randi() % MOTS_TITRES.size()])
	return t


static func genres_films() -> Array:
	var out: Array = []
	for g in GENRES:
		if String(GENRES[g].famille) == "film":
			out.append(g)
	return out


static func genres_scene() -> Array:
	var out: Array = []
	for g in GENRES:
		if String(GENRES[g].famille) != "film":
			out.append(g)
	return out
