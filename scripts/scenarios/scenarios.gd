class_name Scenarios
extends RefCounted
## Scénarios et défis (bouton « Scénarios » du menu principal).
##
## Un scénario est une partie comme les autres, lancée à un endroit précis de
## la Terre, avec des réglages imposés, des contraintes (routes limitées,
## bâtiments interdits…), des événements à date fixe (crue, coup de froid,
## subvention…), des objectifs à remplir avant une date limite et un score.
## Le scénario en cours est suivi par ScenarioPartie (dans la scène Terre) et
## les meilleurs scores sont rangés par Classement (local pour l'instant,
## prêt pour un classement en ligne / Steam).
##
## Pour ajouter un scénario : une entrée de plus dans LISTE, rien d'autre.
##
## Champs d'un scénario :
##   nom, accroche (une ligne), histoire (texte d'ouverture), icone,
##   lieu {nom, lat, lon, pays}, difficulte (1 à 3), jours (date limite, en
##   jours de jeu), date "MM-JJ" (date de départ dans l'année, optionnelle),
##   reglages {preset, …champs de ReglagesPartie},
##   contraintes {routes: classes de voies routières permises ([] : aucune),
##   routes_max_m, interdits: [types de bâtiments], sans_emprunt},
##   evenements [{jour, apres_fondation, type, niveau, montant, texte}] :
##     type crue (niveau 2 orange, 3 rouge), message, subvention (montant),
##     facture (montant), vague (des habitants arrivent : niveau = nombre).
##   objectifs [{type, cible, ref, texte}] (tous à remplir pour gagner),
##   bonus [mêmes champs] (des points en plus),
##   medailles {argent, or} (score à atteindre ; le bronze = gagner).
##
## Types d'objectifs (ScenarioPartie.mesure) : habitants, satisfaction,
## batiment (ref = type, cible = nombre), lignes, caisse (€ dans la caisse de
## la ville), sans_dette (cible 0), palier (index d'Objectifs.PALIERS),
## voies (mètres de voies du mode ref : chemin, rail, route), villes,
## emplois, chomage_max (taux de chômage en % à ne pas dépasser).

const TERRE := "res://scenes/terre.tscn"

## Points du score.
const POINTS_OBJECTIF := 1000
const POINTS_BONUS := 500
const POINTS_VICTOIRE := 2000
const POINTS_JOUR_RESTANT := 25
const POINTS_SATISFACTION := 20
## Multiplicateur de la difficulté (1, 2, 3).
const MULT_DIFFICULTE := [1.0, 1.0, 1.25, 1.5]
const NOMS_DIFFICULTE := ["", "Facile", "Moyen", "Difficile"]
const NOMS_MEDAILLES := ["", "Bronze", "Argent", "Or"]
const COULEURS_MEDAILLES := [Color("888888"), Color("cd7f32"), Color("c9d1d9"), Color("ffd166")]

const LISTE := {
	"crue": {
		"nom": "Reconstruire après l'inondation",
		"accroche": "La rivière a tout emporté. Le village doit renaître, plus solide.",
		"histoire": "Sommières, au bord du Vidourle. Les anciens parlent encore des « vidourlades », ces crues soudaines qui montent de plusieurs mètres en une nuit. La dernière a rasé le vieux village. Tu es le nouveau maire : rebâtis, protège la ville avec des bassins de rétention et prépare-toi, car la rivière reviendra. Elle revient toujours.",
		"icone": "pluie",
		"lieu": {"nom": "Sommières, Gard", "lat": 43.7847, "lon": 4.0894, "pays": "fr"},
		"difficulte": 2,
		"jours": 120,
		"date": "09-15",
		"reglages": {"preset": "normal", "argent_depart": 20_000_000, "catastrophes": true},
		"contraintes": {},
		"evenements": [
			{"jour": 6, "apres_fondation": true, "type": "crue", "niveau": 3,
				"texte": "Vigilance rouge crues : le Vidourle déborde ! Pompiers en alerte, routes coupées."},
			{"jour": 12, "apres_fondation": true, "type": "subvention", "montant": 5_000_000,
				"texte": "L'État déclare la catastrophe naturelle : 5 M€ d'aide à la reconstruction."},
			{"jour": 60, "apres_fondation": true, "type": "crue", "niveau": 2,
				"texte": "Nouvelle crue (vigilance orange). Les bassins de rétention font-ils leur travail ?"},
		],
		"objectifs": [
			{"type": "habitants", "cible": 400, "texte": "Faire revenir 400 habitants"},
			{"type": "batiment", "ref": "bassin_retention", "cible": 2, "texte": "Construire 2 bassins de rétention des crues"},
			{"type": "batiment", "ref": "pompiers", "cible": 1, "texte": "Ouvrir une caserne de pompiers"},
			{"type": "satisfaction", "cible": 55, "texte": "Satisfaction des habitants à 55"},
		],
		"bonus": [
			{"type": "batiment", "ref": "station_meteo", "cible": 1, "texte": "Une station météo pour voir venir la pluie"},
			{"type": "sans_dette", "cible": 0, "texte": "Finir sans dette"},
		],
		"medailles": {"argent": 7500, "or": 10000},
	},
	"sans_voiture": {
		"nom": "Une ville sans voiture",
		"accroche": "Ici, on roule à vélo, on marche et on prend le tram.",
		"histoire": "Houten, aux Pays-Bas. Le conseil a voté : pas une seule avenue, pas une départementale. Seules quelques petites rues de desserte (600 m en tout) sont permises pour les livraisons et les secours. Pour le reste : trottoirs, pistes cyclables, voies vertes, tram et train. Les habitants y croient. Les automobilistes, beaucoup moins.",
		"icone": "pieton",
		"lieu": {"nom": "Houten, Utrecht", "lat": 52.0284, "lon": 5.1683, "pays": "nl"},
		"difficulte": 3,
		"jours": 150,
		"reglages": {"preset": "normal", "acces_route": false},
		"contraintes": {"routes": ["rue"], "routes_max_m": 600.0},
		"evenements": [
			{"jour": 2, "apres_fondation": true, "type": "message",
				"texte": "Rappel du conseil : 600 m de petites rues au total, pas un mètre de plus. Le reste se fait à pied, à vélo ou en tram."},
			{"jour": 30, "apres_fondation": true, "type": "subvention", "montant": 3_000_000,
				"texte": "La région aime ton idée : 3 M€ pour les mobilités douces."},
		],
		"objectifs": [
			{"type": "habitants", "cible": 600, "texte": "Atteindre 600 habitants"},
			{"type": "voies", "ref": "chemin", "cible": 3000, "texte": "3 km de trottoirs, pistes cyclables ou voies vertes"},
			{"type": "lignes", "cible": 1, "texte": "Une ligne de transport en commun (tram ou train)"},
			{"type": "batiment", "ref": "ecole", "cible": 1, "texte": "Une école où l'on vient à pied"},
			{"type": "satisfaction", "cible": 60, "texte": "Satisfaction des habitants à 60"},
		],
		"bonus": [
			{"type": "voies", "ref": "rail", "cible": 2000, "texte": "2 km de rails"},
			{"type": "batiment", "ref": "parc", "cible": 2, "texte": "Deux parcs"},
		],
		"medailles": {"argent": 9000, "or": 12000},
	},
	"grand_hiver": {
		"nom": "Le grand hiver",
		"accroche": "Au-delà du cercle polaire, la neige arrive dans trois semaines.",
		"histoire": "Kiruna, en Laponie suédoise. La mine embauche, les familles arrivent, et l'hiver ne prévient pas deux fois : des mètres de neige, des nuits sans fin, −30 °C. Fonde la ville, ouvre un centre technique pour déneiger les rues et tiens jusqu'au printemps sans que les habitants ne fassent leurs valises.",
		"icone": "neige",
		"lieu": {"nom": "Kiruna, Laponie", "lat": 67.8558, "lon": 20.2253, "pays": "se"},
		"difficulte": 2,
		"jours": 120,
		"date": "10-20",
		"reglages": {"preset": "normal", "argent_depart": 25_000_000, "neige_routes": true},
		"contraintes": {},
		"evenements": [
			{"jour": 20, "type": "message", "texte": "Les premiers flocons tombent sur Kiruna. Tes chasse-neige sont prêts ?"},
			{"jour": 50, "type": "vague", "niveau": 40, "texte": "La mine embauche : 40 nouveaux habitants arrivent par le train de l'aube."},
		],
		"objectifs": [
			{"type": "habitants", "cible": 300, "texte": "300 habitants passent l'hiver"},
			{"type": "batiment", "ref": "centre_technique", "cible": 1, "texte": "Un centre technique municipal (déneigement)"},
			{"type": "batiment", "ref": "ecole", "cible": 1, "texte": "Une école chauffée"},
			{"type": "satisfaction", "cible": 55, "texte": "Satisfaction des habitants à 55"},
		],
		"bonus": [
			{"type": "batiment", "ref": "hopital", "cible": 1, "texte": "Un hôpital"},
			{"type": "batiment", "ref": "station_meteo", "cible": 1, "texte": "Une station météo"},
		],
		"medailles": {"argent": 7500, "or": 10000},
	},
	"caisses_vides": {
		"nom": "Les caisses sont vides",
		"accroche": "3 millions d'euros, pas un centime de crédit. Bonne chance.",
		"histoire": "Un village du Jura. Ton prédécesseur est parti avec la caisse (enfin, presque : il reste 3 M€). La banque ne prête plus un sou à la commune. Fais grandir le village, équilibre le budget et laisse une caisse pleine au suivant.",
		"icone": "budget",
		"lieu": {"nom": "Saint-Claude, Jura", "lat": 46.3872, "lon": 5.8636, "pays": "fr"},
		"difficulte": 3,
		"jours": 150,
		"reglages": {"preset": "normal", "argent_depart": 3_000_000, "cout_construction": 1.0},
		"contraintes": {"sans_emprunt": true},
		"evenements": [
			{"jour": 40, "apres_fondation": true, "type": "facture", "montant": 400_000,
				"texte": "Surprise : une vieille facture de déneigement de ton prédécesseur. 400 000 € à payer."},
		],
		"objectifs": [
			{"type": "habitants", "cible": 500, "texte": "Atteindre 500 habitants"},
			{"type": "sans_dette", "cible": 0, "texte": "Aucune dette"},
			{"type": "caisse", "cible": 5_000_000, "texte": "5 M€ dans la caisse de la ville"},
		],
		"bonus": [
			{"type": "batiment", "ref": "ecole", "cible": 1, "texte": "Une école"},
			{"type": "chomage_max", "cible": 10, "texte": "Moins de 10 % de chômage"},
		],
		"medailles": {"argent": 6000, "or": 8000},
	},
	"course_bourg": {
		"nom": "Course au bourg",
		"accroche": "Du hameau au bourg, le plus vite possible.",
		"histoire": "Échallens, sur le plateau vaudois. Le préfet passe dans 90 jours et il veut voir un vrai bourg : 500 habitants, une école, une caisse saine. Chaque jour gagné rapporte des points. Une course contre la montre, version administrative.",
		"icone": "horloge",
		"lieu": {"nom": "Échallens, Vaud", "lat": 46.6413, "lon": 6.6335, "pays": "ch"},
		"difficulte": 1,
		"jours": 90,
		"reglages": {"preset": "normal"},
		"contraintes": {},
		"evenements": [],
		"objectifs": [
			{"type": "palier", "cible": 2, "texte": "Devenir un Bourg (500 habitants, école, caisse saine)"},
		],
		"bonus": [
			{"type": "lignes", "cible": 1, "texte": "Une ligne de bus"},
			{"type": "satisfaction", "cible": 65, "texte": "Satisfaction des habitants à 65"},
		],
		"medailles": {"argent": 5500, "or": 6500},
	},
	"pays_neuf": {
		"nom": "Trois villes, un pays",
		"accroche": "Fonde trois villes et relie-les avant la fin de l'année.",
		"histoire": "La vallée de l'Ill, en Alsace. Personne n'y a encore posé de pierre. Fonde trois villes, relie-les par la route ou le rail, et fais-en un pays qui compte. Chaque ville a sa caisse : à toi de les faire vivre toutes les trois.",
		"icone": "village",
		"lieu": {"nom": "Sélestat, Alsace", "lat": 48.2594, "lon": 7.4542, "pays": "fr"},
		"difficulte": 2,
		"jours": 200,
		"reglages": {"preset": "normal", "argent_depart": 40_000_000},
		"contraintes": {},
		"evenements": [
			{"jour": 100, "type": "subvention", "montant": 4_000_000,
				"texte": "L'Europe soutient les nouveaux territoires : 4 M€ pour ton pays."},
		],
		"objectifs": [
			{"type": "villes", "cible": 3, "texte": "Fonder trois villes"},
			{"type": "habitants", "cible": 1000, "texte": "1 000 habitants en tout"},
			{"type": "relies", "cible": 1, "texte": "Toutes les villes reliées entre elles"},
		],
		"bonus": [
			{"type": "lignes", "cible": 2, "texte": "Deux lignes de transport"},
			{"type": "sans_dette", "cible": 0, "texte": "Finir sans dette"},
		],
		"medailles": {"argent": 7000, "or": 9500},
	},
}

## Scénario demandé pour la prochaine scène Terre (lu une fois par ScenarioPartie).
static var demande := ""


static func ids() -> Array:
	return LISTE.keys()


static func existe(id: String) -> bool:
	return LISTE.has(id)


static func donnees(id: String) -> Dictionary:
	return LISTE.get(id, {})


## Réglages de la partie d'un scénario : le préréglage puis les champs imposés.
static func reglages(id: String) -> ReglagesPartie:
	var s := donnees(id)
	var rg: Dictionary = s.get("reglages", {})
	var r := ReglagesPartie.preset(String(rg.get("preset", "normal")))
	# Les scénarios ont leurs propres limites : pas d'arbre de progression, sauf s'ils le demandent.
	r.deblocage = "tout"
	for k in rg:
		if k != "preset":
			r.set(k, rg[k])
	r.tutoriel = false
	r.objectifs_ecran = false
	return r


## Prépare GameStart et les réglages ; renvoie le titre de l'écran de chargement.
static func preparer(id: String) -> String:
	var s := donnees(id)
	var lieu: Dictionary = s.lieu
	GameStart.chosen = true
	GameStart.atelier = false
	GameStart.lat = float(lieu.lat)
	GameStart.lon = float(lieu.lon)
	GameStart.place_name = String(lieu.nom)
	GameStart.pays = String(lieu.get("pays", ""))
	GameStart.mode = GameStart.Mode.BAC_A_SABLE
	GameStart.load_slot = ""
	GameStart.slot_id = ""
	ReglagesPartie.prochaine = reglages(id)
	demande = id
	return "Scénario · " + String(s.nom)


static func lancer(id: String) -> void:
	if existe(id):
		EcranChargement.aller(TERRE, preparer(id))


## Score d'une fin de partie. r : {objectifs: n faits, total, bonus: n, jours_restants,
## habitants, satisfaction, dette, victoire}. Renvoie {total, lignes: [[libellé, points]]}.
static func calculer_score(id: String, r: Dictionary) -> Dictionary:
	var s := donnees(id)
	var lignes := []
	var pts := 0
	var o := int(r.get("objectifs", 0)) * POINTS_OBJECTIF
	lignes.append(["Objectifs remplis (%d / %d)" % [int(r.get("objectifs", 0)), int(r.get("total", 0))], o])
	pts += o
	var b := int(r.get("bonus", 0)) * POINTS_BONUS
	if b > 0:
		lignes.append(["Objectifs bonus (%d)" % int(r.get("bonus", 0)), b])
		pts += b
	if bool(r.get("victoire", false)):
		lignes.append(["Scénario réussi", POINTS_VICTOIRE])
		pts += POINTS_VICTOIRE
		var j := maxi(int(r.get("jours_restants", 0)), 0) * POINTS_JOUR_RESTANT
		if j > 0:
			lignes.append(["Avance sur la date limite (%d jours)" % int(r.get("jours_restants", 0)), j])
			pts += j
	var h := maxi(int(r.get("habitants", 0)), 0)
	if h > 0:
		lignes.append(["Habitants (%d)" % h, h])
		pts += h
	var sat := maxi(int(r.get("satisfaction", 0)), 0) * POINTS_SATISFACTION
	if sat > 0:
		lignes.append(["Satisfaction (%d)" % int(r.get("satisfaction", 0)), sat])
		pts += sat
	var d := int(float(r.get("dette", 0.0)) / 10000.0)
	if d > 0:
		lignes.append(["Dette (%s)" % BuildingSystem.format_money(int(r.get("dette", 0.0))), -d])
		pts -= d
	var diff := int(s.get("difficulte", 1))
	var mult: float = MULT_DIFFICULTE[clampi(diff, 0, 3)]
	var total := maxi(roundi(pts * mult), 0)
	if mult != 1.0:
		lignes.append(["Difficulté %s (×%s)" % [String(NOMS_DIFFICULTE[diff]).to_lower(), str(mult).replace(".", ",")], total - pts])
	return {"total": total, "lignes": lignes}


## Médaille d'un score : 0 aucune (échec), 1 bronze, 2 argent, 3 or.
static func medaille(id: String, score: int, victoire: bool) -> int:
	if not victoire:
		return 0
	var m: Dictionary = donnees(id).get("medailles", {})
	if score >= int(m.get("or", 1 << 30)):
		return 3
	if score >= int(m.get("argent", 1 << 30)):
		return 2
	return 1
