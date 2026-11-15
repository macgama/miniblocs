class_name ClubSports
extends RefCounted
## Les sports du club : chaque sport a sa section (son équipe, son
## championnat, sa caisse), gérée par un nœud ClubSport. Ce fichier décrit ce
## qui change d'un sport à l'autre : postes, compositions, façon de marquer,
## points au classement, calendrier, salle, économie, durée des matchs.
##
## Champs d'un sport :
## - postes {lettre: nom}, ordre (affichage), formations {nom: {poste: n}}
##   (une clé « _fat » multiplie la fatigue), formation (par défaut).
## - poids {poste: part dans la force}, marqueur {poste: chance de marquer}.
## - effectif (postes de départ), marche (postes proposés), jeunes (postes
##   des jeunes du centre), min / max joueurs.
## - modele : façon de tirer le score (poisson, basket, handball, hockey,
##   rugby, tennis) ; points : {V, N, D, VP (victoire après prolongation),
##   DP (défaite après prolongation)} au classement.
## - jour (0 = dimanche … 6 = samedi), jour2 (quand il faut resserrer),
##   heures (par division), debut / fin [mois, jour], treve [[mois, jour], [mois, jour]].
## - nb_clubs, aller_retour.
## - eco (sponsors, télé, primes), prix_f (billet), sal_f (salaires).
## - hobby (loisir des habitants), lieu (texte), batir (bâtiment proposé).
## - per [périodes, minutes de jeu par période, minutes réelles par période,
##   pause], terrain (demi-longueur, demi-largeur), sur_terrain (par équipe),
##   gardien (bool), unite [singulier, pluriel].

const ORDRE := ["football", "basket", "handball", "hockey", "rugby", "tennis"]

const LIEUX := ["Rive-Lac", "Crêtes", "Val-Rhône", "Montbrun", "Haute-Ville", "Saint-Lorin", "Bergval", "Tilleuls",
	"Combe-Noire", "Port-Avel", "Pré-Vert", "Moraz", "Valmont", "Bellerive", "Clairefontaine", "Roche-Grise",
	"Val-d'Orbe", "Mer-Bleue", "Hautmont", "Pontaven", "Deux-Rives", "Granit", "Forges", "Clos-Fleuri",
	"Montjoie", "Brise-Lames", "Haut-Plateau", "Saint-Aubrac", "Val-Noir", "Côte-Sauvage", "Lacustre",
	"Pierre-Haute", "Marais-Doux", "Combeval", "Monterrain", "Trois-Chênes"]

const SPORTS := {
	"football": {
		"nom": "Football", "court": "Foot", "icone": "sport", "hobby": "football",
		"postes": {"G": "Gardien", "D": "Défenseur", "M": "Milieu", "A": "Attaquant"},
		"ordre": ["G", "D", "M", "A"],
		"formations": ClubDonnees.FORMATIONS, "formation": "4-4-2",
		"poids": {"G": 0.12, "D": 0.3, "M": 0.3, "A": 0.28},
		"marqueur": {"G": 0.0, "D": 0.5, "M": 1.6, "A": 4.0},
		"effectif": ["G", "G", "D", "D", "D", "D", "D", "D", "D", "M", "M", "M", "M", "M", "M", "M", "A", "A", "A", "A"],
		"marche": ["G", "D", "D", "D", "M", "M", "M", "A", "A", "A", "D", "M", "A", "G"],
		"jeunes": ["G", "D", "D", "M", "M", "A"],
		"min": 16, "max": 30,
		"modele": "poisson", "moy": 1.35, "points": {"V": 3, "N": 1, "D": 0},
		"jour": 6, "jour2": 3, "heures": [15.0, 18.0, 19.0, 21.0], "debut": [8, 8], "fin": [5, 31], "treve": [[12, 18], [1, 20]],
		"nb_clubs": 12, "aller_retour": true,
		"divisions": ["Régionale", "Nationale", "Deuxième Ligue", "Première Ligue"],
		"eco": 1.0, "prix_f": 1.0, "sal_f": 1.0,
		"motifs": ["FC %s", "%s Sport", "Olympique %s", "AS %s", "Racing %s", "Stade %s", "US %s", "Sporting %s"],
		"lieu": "un stade ou un terrain de foot", "batir": "foot",
		"per": [2, 45, 47, 15], "terrain": Vector2(52.5, 34.0), "sur_terrain": 11, "gardien": true,
		"unite": ["but", "buts"], "annonce": "But de %s !",
	},
	"basket": {
		"nom": "Basket-ball", "court": "Basket", "icone": "basket", "hobby": "basket",
		"postes": {"M": "Meneur", "A": "Ailier", "I": "Intérieur"},
		"ordre": ["M", "A", "I"],
		"formations": {"1-2-2": {"M": 1, "A": 2, "I": 2}, "2-2-1 (petit)": {"M": 2, "A": 2, "I": 1}, "1-1-3 (grand)": {"M": 1, "A": 1, "I": 3}},
		"formation": "1-2-2",
		"poids": {"M": 0.34, "A": 0.33, "I": 0.33},
		"marqueur": {"M": 1.0, "A": 1.2, "I": 1.1},
		"effectif": ["M", "M", "M", "A", "A", "A", "A", "I", "I", "I", "I", "I"],
		"marche": ["M", "M", "A", "A", "A", "I", "I", "I", "M", "I"],
		"jeunes": ["M", "A", "I"],
		"min": 10, "max": 16,
		"modele": "basket", "moy": 78.0, "points": {"V": 2, "D": 1, "VP": 2, "DP": 1},
		"jour": 6, "jour2": 3, "heures": [18.0, 20.0, 20.0, 20.5], "debut": [10, 1], "fin": [5, 15], "treve": [[12, 23], [1, 3]],
		"nb_clubs": 12, "aller_retour": true,
		"divisions": ["Régionale", "Nationale", "Pro B", "Élite"],
		"eco": 0.3, "prix_f": 0.8, "sal_f": 0.35,
		"motifs": ["BC %s", "%s Basket", "Union %s Basket", "ES %s Basket", "Élan %s", "JA %s"],
		"lieu": "un gymnase, un terrain de basket ou une salle omnisports", "batir": "salle_omnisports",
		"per": [4, 10, 24, 4], "terrain": Vector2(14.0, 7.5), "sur_terrain": 5, "gardien": false,
		"unite": ["point", "points"], "annonce": "",
	},
	"handball": {
		"nom": "Handball", "court": "Hand", "icone": "handball", "hobby": "handball",
		"postes": {"G": "Gardien", "R": "Arrière", "L": "Ailier", "P": "Pivot"},
		"ordre": ["G", "R", "L", "P"],
		"formations": {"Classique": {"G": 1, "R": 3, "L": 2, "P": 1}, "Deux pivots": {"G": 1, "R": 2, "L": 2, "P": 2}},
		"formation": "Classique",
		"poids": {"G": 0.25, "R": 0.35, "L": 0.2, "P": 0.2},
		"marqueur": {"G": 0.02, "R": 1.5, "L": 1.2, "P": 1.0},
		"effectif": ["G", "G", "R", "R", "R", "R", "R", "L", "L", "L", "L", "P", "P", "P"],
		"marche": ["G", "R", "R", "R", "L", "L", "P", "P", "R", "L"],
		"jeunes": ["G", "R", "L", "P"],
		"min": 12, "max": 18,
		"modele": "handball", "moy": 27.0, "points": {"V": 2, "N": 1, "D": 0},
		"jour": 5, "jour2": 3, "heures": [20.0, 20.5, 20.5, 20.5], "debut": [9, 5], "fin": [5, 31], "treve": [[12, 20], [1, 31]],
		"nb_clubs": 12, "aller_retour": true,
		"divisions": ["Prénationale", "Nationale", "Proligue", "Élite"],
		"eco": 0.18, "prix_f": 0.7, "sal_f": 0.25,
		"motifs": ["HBC %s", "%s Handball", "US %s Hand", "Entente %s Hand", "Montagnards de %s"],
		"lieu": "un gymnase ou une salle omnisports", "batir": "salle_omnisports",
		"per": [2, 30, 38, 15], "terrain": Vector2(20.0, 10.0), "sur_terrain": 7, "gardien": true,
		"unite": ["but", "buts"], "annonce": "",
	},
	"hockey": {
		"nom": "Hockey sur glace", "court": "Hockey", "icone": "hockey", "hobby": "hockey",
		"postes": {"G": "Gardien", "D": "Défenseur", "A": "Attaquant"},
		"ordre": ["G", "D", "A"],
		"formations": {"Trois lignes": {"G": 1, "D": 6, "A": 9}, "Deux lignes (les meilleurs jouent plus)": {"G": 1, "D": 4, "A": 6, "_fat": 1.5}},
		"formation": "Trois lignes",
		"poids": {"G": 0.3, "D": 0.3, "A": 0.4},
		"marqueur": {"G": 0.0, "D": 0.6, "A": 2.5},
		"effectif": ["G", "G", "D", "D", "D", "D", "D", "D", "D", "D", "A", "A", "A", "A", "A", "A", "A", "A", "A", "A", "A", "A"],
		"marche": ["G", "D", "D", "D", "A", "A", "A", "A", "D", "A", "G", "A"],
		"jeunes": ["G", "D", "A", "A"],
		"min": 18, "max": 28,
		"modele": "hockey", "moy": 2.9, "points": {"V": 3, "VP": 2, "DP": 1, "D": 0},
		"jour": 6, "jour2": 2, "heures": [18.0, 19.5, 20.0, 20.0], "debut": [9, 10], "fin": [3, 31], "treve": [[12, 23], [1, 2]],
		"nb_clubs": 12, "aller_retour": true,
		"divisions": ["Division 3", "Division 2", "Division 1", "Élite"],
		"eco": 0.2, "prix_f": 0.85, "sal_f": 0.3,
		"motifs": ["HC %s", "%s Hockey", "Lions de %s", "Aigles de %s", "Brûleurs de %s", "Ours de %s"],
		"lieu": "une patinoire", "batir": "patinoire_hockey",
		"per": [3, 20, 35, 18], "terrain": Vector2(30.0, 15.0), "sur_terrain": 6, "gardien": true,
		"unite": ["but", "buts"], "annonce": "But de %s !",
	},
	"rugby": {
		"nom": "Rugby à XV", "court": "Rugby", "icone": "rugby", "hobby": "rugby",
		"postes": {"V": "Avant", "T": "Troisième ligne", "N": "Demi", "Q": "Trois-quarts", "R": "Arrière"},
		"ordre": ["V", "T", "N", "Q", "R"],
		"formations": {"Jeu d'avants": {"V": 5, "T": 3, "N": 2, "Q": 4, "R": 1}, "Jeu à la main": {"V": 5, "T": 3, "N": 2, "Q": 4, "R": 1, "_fat": 1.1}},
		"formation": "Jeu d'avants",
		"poids": {"V": 0.32, "T": 0.2, "N": 0.16, "Q": 0.22, "R": 0.1},
		"marqueur": {"V": 0.6, "T": 1.0, "N": 0.8, "Q": 2.2, "R": 1.5},
		"effectif": ["V", "V", "V", "V", "V", "V", "V", "V", "V", "V", "T", "T", "T", "T", "T", "N", "N", "N", "N",
			"Q", "Q", "Q", "Q", "Q", "Q", "Q", "Q", "R", "R", "R"],
		"marche": ["V", "V", "V", "T", "T", "N", "N", "Q", "Q", "Q", "R", "V"],
		"jeunes": ["V", "V", "T", "N", "Q", "R"],
		"min": 23, "max": 36,
		"modele": "rugby", "moy": 2.4, "points": {"V": 4, "N": 2, "D": 0},
		"jour": 0, "jour2": 6, "heures": [15.0, 15.0, 16.0, 16.5], "debut": [8, 25], "fin": [5, 31], "treve": [[12, 22], [1, 5]],
		"nb_clubs": 12, "aller_retour": true,
		"divisions": ["Fédérale", "Nationale", "Deuxième Division", "Top Élite"],
		"eco": 0.4, "prix_f": 0.9, "sal_f": 0.4,
		"motifs": ["RC %s", "Stade %s", "US %s Rugby", "%s XV", "CA %s", "Aviron %s"],
		"lieu": "un stade ou un terrain de foot", "batir": "foot",
		"per": [2, 40, 45, 15], "terrain": Vector2(50.0, 35.0), "sur_terrain": 15, "gardien": false,
		"unite": ["essai", "essais"], "annonce": "Essai de %s !",
	},
	"tennis": {
		"nom": "Tennis (championnat par équipes)", "court": "Tennis", "icone": "tennis", "hobby": "tennis",
		"postes": {"J": "Joueur"},
		"ordre": ["J"],
		"formations": {"4 simples et 2 doubles": {"J": 4}},
		"formation": "4 simples et 2 doubles",
		"poids": {"J": 1.0},
		"marqueur": {"J": 1.0},
		"effectif": ["J", "J", "J", "J", "J", "J", "J", "J"],
		"marche": ["J", "J", "J", "J", "J", "J", "J", "J"],
		"jeunes": ["J", "J"],
		"min": 6, "max": 12,
		"modele": "tennis", "moy": 3.0, "points": {"V": 3, "N": 2, "D": 1},
		"jour": 0, "jour2": 6, "heures": [9.0, 9.0, 9.0, 10.0], "debut": [3, 1], "fin": [6, 28], "treve": [],
		"nb_clubs": 8, "aller_retour": false,
		"divisions": ["Départementale", "Régionale", "Nationale 2", "Nationale 1"],
		"eco": 0.04, "prix_f": 0.2, "sal_f": 0.12,
		"motifs": ["TC %s", "Tennis Club de %s", "ASL %s Tennis", "%s Tennis", "Raquettes de %s"],
		"lieu": "un court de tennis ou un centre de tennis", "batir": "centre_tennis",
		"per": [6, 1, 50, 8], "terrain": Vector2(11.9, 5.5), "sur_terrain": 1, "gardien": false,
		"unite": ["match gagné", "matchs gagnés"], "annonce": "Tennis : %s remporte le %s.",
	},
}

## Centre de formation : niveaux (coût mensuel avant l'échelle du sport,
## potentiel en plus, jeunes recrutés par saison, bâtiment demandé).
const ACADEMIE := [
	{"nom": "Aucun", "cout": 0.0, "pot": 0.0, "n": 0, "bati": false, "desc": "Quelques jeunes du coin complètent l'équipe quand il manque du monde."},
	{"nom": "École de sport", "cout": 2_500.0, "pot": 4.0, "n": 3, "bati": false, "desc": "Des éducateurs le mercredi : trois jeunes par saison, surtout des enfants de la ville."},
	{"nom": "Centre de formation", "cout": 12_000.0, "pot": 10.0, "n": 4, "bati": true, "desc": "Internat et terrains d'entraînement : quatre jeunes par saison, qui progressent vite."},
	{"nom": "Académie de haut niveau", "cout": 40_000.0, "pot": 16.0, "n": 5, "bati": true, "desc": "Recruteurs dans tout le pays : cinq jeunes par saison, de futurs internationaux."},
]

const PENSEES := {
	"humeur_haut": "« %s gagne, toute la rue a sorti les drapeaux ! »",
	"humeur_bas": "« %s perd encore… Même le boulanger fait la tête. »",
	"habitant_pro": "« Le petit %s, formé au club, passe pro ! Tout le quartier est fier. »",
	"abonne": "« J'ai pris mon abonnement pour toute la saison. »",
	"abo_cher": "« L'abonnement à %d €, c'est trop pour ma famille. »",
	"fete": "« Quelle fête pour la montée ! On a chanté jusqu'à minuit. »",
}


static func sport(s: String) -> Dictionary:
	return SPORTS.get(s, SPORTS.football)


static func nom(s: String) -> String:
	return String(sport(s).nom)


## Division d'un sport, avec son économie (même format que ClubDonnees.DIVISIONS).
static func division(s: String, i: int) -> Dictionary:
	var base := ClubDonnees.division(i)
	if s == "football":
		return base
	var sp := sport(s)
	var d := base.duplicate()
	var noms: Array = sp.divisions
	d.nom = String(noms[clampi(i, 0, noms.size() - 1)])
	d.prix = roundf(float(base.prix) * float(sp.prix_f))
	d.tv = roundf(float(base.tv) * float(sp.eco) / 1000.0) * 1000.0
	d.sponsors = roundf(float(base.sponsors) * float(sp.eco) / 1000.0) * 1000.0
	d.titre = roundf(float(base.titre) * float(sp.eco) / 1000.0) * 1000.0
	d.heure = float((sp.heures as Array)[clampi(i, 0, (sp.heures as Array).size() - 1)])
	return d


static func nb_divisions(_s: String) -> int:
	return ClubDonnees.DIVISIONS.size()


static func salaire(s: String, note: float) -> float:
	return roundf(ClubDonnees.salaire(note) * float(sport(s).sal_f) / 10.0) * 10.0


static func valeur(s: String, note: float, age: float, potentiel: float) -> float:
	return roundf(ClubDonnees.valeur(note, age, potentiel) * float(sport(s).sal_f) / 1000.0) * 1000.0


## Clubs adverses inventés du sport (le football garde sa liste).
static func adverses(s: String) -> Array:
	if s == "football":
		return ClubDonnees.ADVERSES
	var sp := sport(s)
	var motifs: Array = sp.motifs
	var out := []
	for i in LIEUX.size():
		var m: String = motifs[(i * 7 + hash(s)) % motifs.size()]
		out.append(m % LIEUX[i])
	return out


static func nom_propose(s: String, lieu: String) -> String:
	if s == "football":
		return "FC %s" % lieu
	return String((sport(s).motifs as Array)[0]) % lieu


## Postes et nombre de titulaires d'une composition (sans les clés « _ »).
static func besoins(s: String, formation: String) -> Dictionary:
	var sp := sport(s)
	var f: Dictionary = (sp.formations as Dictionary).get(formation, (sp.formations as Dictionary)[sp.formation])
	var out := {}
	for p in sp.ordre:
		out[p] = int(f.get(p, 0))
	if bool(sp.gardien) and int(out.get("G", 0)) == 0 and (sp.ordre as Array).has("G"):
		out.G = 1
	return out


static func titulaires(s: String, formation: String) -> int:
	var n := 0
	var b := besoins(s, formation)
	for k in b:
		n += int(b[k])
	return n


static func fatigue_f(s: String, formation: String) -> float:
	var sp := sport(s)
	var f: Dictionary = (sp.formations as Dictionary).get(formation, {})
	return float(f.get("_fat", 1.0))


static func hobby(s: String) -> String:
	return String(sport(s).hobby)


## Le bâtiment accueille-t-il les matchs de ce sport ?
static func accueille(s: String, type_id: String) -> bool:
	var t := BuildingCatalog.get_type(type_id)
	if t.is_empty():
		return false
	var cs: Dictionary = t.get("club_sport", {})
	if (cs.get("sports", []) as Array).has(s):
		return true
	var base := BuildingCatalog.base_of(type_id)
	var role := String(t.get("role", ""))
	match s:
		"football", "rugby":
			return Stades.est_stade(type_id)
		"basket":
			return base in ["basket", "gymnase"] or role == "gymnase"
		"handball":
			return base == "gymnase" or role == "gymnase"
		"hockey":
			return base == "patinoire" or role == "patinoire"
		"tennis":
			return base == "tennis" or role == "tennis"
	return false


## Places assises (ou debout) d'un lieu de match.
static func places_lieu(type_id: String) -> int:
	if Stades.est_stade(type_id):
		return Stades.places(type_id)
	var t := BuildingCatalog.get_type(type_id)
	if t.has("club_sport"):
		return int(t.club_sport.get("places", 100))
	if t.has("modele") and int(t.get("places", 0)) > 0:
		return int(t.places)
	return maxi(int(t.get("visiteurs", 50)), 20)


# --- Chronomètre des matchs -----------------------------------------------------------------

## Durée réelle d'un match, du coup d'envoi à la fin (s).
static func duree(s: String) -> float:
	var p: Array = sport(s).per
	return (float(p[0]) * float(p[2]) + float(p[0] - 1) * float(p[3])) * 60.0


## Où en est le match, s secondes après le coup d'envoi : {m (minute de jeu,
## −1 avant, total + 1 après), per (nom de la période), jeu (bool)}.
static func chrono(sport_id: String, s: float) -> Dictionary:
	var p: Array = sport(sport_id).per
	var n := int(p[0])
	var jeu_min := float(p[1])
	var reel := float(p[2])
	var pause := float(p[3])
	var total := n * jeu_min
	var mn := s / 60.0
	if mn < 0.0:
		return {"m": -1.0, "per": "avant", "jeu": false}
	for i in n:
		if mn < reel:
			return {"m": i * jeu_min + jeu_min * mn / reel, "per": nom_periode(sport_id, i), "jeu": true}
		mn -= reel
		if i < n - 1:
			if mn < pause:
				return {"m": (i + 1) * jeu_min, "per": "pause", "jeu": false}
			mn -= pause
	return {"m": total + 1.0, "per": "fin", "jeu": false}


static func nom_periode(s: String, i: int) -> String:
	match s:
		"basket":
			return "%s quart-temps" % ["1er", "2e", "3e", "4e"][clampi(i, 0, 3)]
		"hockey":
			return "%s tiers-temps" % ["1er", "2e", "3e"][clampi(i, 0, 2)]
		"tennis":
			return ["simple 4", "simple 3", "simple 2", "simple 1", "double 1", "double 2"][clampi(i, 0, 5)]
	return "%s mi-temps" % ["1re", "2e"][clampi(i, 0, 1)]


## Texte du chrono (tableau d'affichage, panneau des événements).
static func chrono_texte(s: String, c: Dictionary) -> String:
	match String(c.per):
		"avant":
			return "avant"
		"fin":
			return "terminé"
		"pause":
			return "mi-temps" if int((sport(s).per as Array)[0]) == 2 else "pause"
	if s == "tennis":
		return String(c.per)
	return "%d' (%s)" % [int(c.m), String(c.per)] if s != "football" else "%d'" % int(c.m)
