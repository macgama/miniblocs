class_name ClubDonnees
extends RefCounted
## Données du club de sport : divisions, formations, tactiques, clubs adverses
## inventés, salaires et valeurs des joueurs.

## Du plus bas (0) au plus haut. niveau : note moyenne des équipes ; prix : billet
## de référence ; tv et sponsors : par saison ; primes : du 1er au dernier.
const DIVISIONS := [
	{"nom": "Régionale", "niveau": 46.0, "prix": 7.0, "tv": 0.0, "sponsors": 30_000.0, "titre": 15_000.0, "monte": 2, "descend": 0, "heure": 15.0},
	{"nom": "Nationale", "niveau": 56.0, "prix": 12.0, "tv": 350_000.0, "sponsors": 400_000.0, "titre": 150_000.0, "monte": 2, "descend": 2, "heure": 18.0},
	{"nom": "Deuxième Ligue", "niveau": 65.0, "prix": 18.0, "tv": 6_000_000.0, "sponsors": 2_500_000.0, "titre": 1_500_000.0, "monte": 2, "descend": 2, "heure": 19.0},
	{"nom": "Première Ligue", "niveau": 74.0, "prix": 30.0, "tv": 25_000_000.0, "sponsors": 10_000_000.0, "titre": 12_000_000.0, "monte": 0, "descend": 2, "heure": 21.0},
]
const NB_CLUBS := 12

## Combien de joueurs par ligne (le gardien en plus).
const FORMATIONS := {
	"4-4-2": {"D": 4, "M": 4, "A": 2},
	"4-3-3": {"D": 4, "M": 3, "A": 3},
	"3-5-2": {"D": 3, "M": 5, "A": 2},
	"5-3-2": {"D": 5, "M": 3, "A": 2},
	"4-5-1": {"D": 4, "M": 5, "A": 1},
}
## Tactique : [buts marqués ×, buts encaissés ×, nom].
const TACTIQUES := {
	"defensive": [0.82, 0.8, "Défensive (on ferme le jeu)"],
	"equilibree": [1.0, 1.0, "Équilibrée"],
	"offensive": [1.18, 1.15, "Offensive (tout pour l'attaque)"],
}
## Entraînement : [progression ×, fatigue récupérée par jour, risque de blessure ×, nom].
const ENTRAINEMENTS := {
	"leger": [0.6, 0.16, 0.7, "Léger"],
	"normal": [1.0, 0.12, 1.0, "Normal"],
	"intense": [1.45, 0.08, 1.5, "Intense"],
}
const POSTES := {"G": "Gardien", "D": "Défenseur", "M": "Milieu", "A": "Attaquant"}
const ORDRE_POSTES := ["G", "D", "M", "A"]

const ADVERSES := ["FC Rive-Lac", "Olympique des Crêtes", "Racing Val-Rhône", "AS Montbrun", "FC Haute-Ville",
	"Union Saint-Lorin", "SC Bergval", "FC Les Tilleuls", "Étoile de Combe-Noire", "Sporting Port-Avel",
	"AC Pré-Vert", "FC Moraz", "Lions de Valmont", "Stade Bellerive", "US Clairefontaine", "AS Roche-Grise",
	"FC Val-d'Orbe", "Olympique Mer-Bleue", "Red Star Hautmont", "SC Pontaven", "Entente Deux-Rives",
	"FC Granit", "Union Sportive des Forges", "AS Clos-Fleuri", "Athletic Montjoie", "FC Brise-Lames",
	"Racing Club Haut-Plateau", "Stade Saint-Aubrac", "Dynamo Val-Noir", "FC Côte-Sauvage", "Sporting Lacustre",
	"AS Pierre-Haute", "FC Marais-Doux", "Étoile Sportive Combeval", "Real Monterrain", "US Trois-Chênes"]
const MOTIFS := ["FC %s", "%s Sport", "Olympique %s", "AS %s", "Racing %s", "Stade %s", "US %s", "Sporting %s"]
const COULEURS := [["c8102e", "f2f2f2"], ["1d3c8f", "f2f2f2"], ["f2c200", "1b1b1b"], ["2a9d8f", "f2f2f2"],
	["6a0dad", "f2f2f2"], ["1b1b1b", "f2f2f2"], ["e76f51", "264653"], ["ff7f11", "1d3557"], ["2e7d32", "f2f2f2"],
	["7a1f2b", "e9c46a"], ["4ea8de", "1d3557"], ["d62828", "003049"]]
const NOMS_COULEURS := ["Rouge et blanc", "Bleu et blanc", "Jaune et noir", "Vert d'eau et blanc", "Violet et blanc",
	"Noir et blanc", "Orange et bleu nuit", "Orange et marine", "Vert et blanc", "Grenat et or", "Ciel et marine", "Rouge et marine"]

## Sponsors principaux inventés (maillot).
const SPONSORS := ["Fromagerie Durand", "Garage du Centre", "Boulangerie Moreau", "Assurances Lambert",
	"Crédit des Vallées", "Brasserie du Lac", "TransAlpes Logistique", "Eaux de Bergval", "Pneus Rapido",
	"Mutuelle Horizon", "Télécom Plus", "Énergies du Rhône", "Supermarché Le Panier", "Chocolats Favre"]

const PENSEES := {
	"victoire": "« On a gagné ! Toute la tribune chantait. »",
	"defaite": "« Encore perdu… Mais je reviendrai samedi prochain. »",
	"nul": "« Un nul, ça ne fait plaisir à personne. »",
	"cher": "« %d € la place pour voir ça ? Le président exagère. »",
	"bon_prix": "« À ce prix-là, j'emmène toute la famille. »",
	"complet": "« Guichets fermés ! Il a fallu se serrer sur les gradins. »",
	"buteur": "« Quel but de %s ! On en parlera longtemps au café. »",
	"montee": "« Montée ! Je n'y croyais plus. »",
	"descente": "« Descendre… quelle tristesse. On reviendra. »",
	"habitant": "« Mon voisin %s joue dans l'équipe, je ne rate aucun match. »",
}


## Salaire mensuel demandé selon la note (bénévoles en Régionale : voir ClubSport).
static func salaire(note: float) -> float:
	return roundf(60.0 * exp((note - 35.0) / 6.5) / 10.0) * 10.0


## Valeur sur le marché des transferts.
static func valeur(note: float, age: float, potentiel: float) -> float:
	var f := 1.0
	if age < 21.0:
		f = 1.5 + maxf(potentiel - note, 0.0) * 0.05
	elif age < 25.0:
		f = 1.3 + maxf(potentiel - note, 0.0) * 0.03
	elif age > 32.0:
		f = 0.35
	elif age > 29.0:
		f = 0.7
	return maxf(roundf(salaire(note) * 48.0 * f / 1000.0) * 1000.0, 0.0)


static func division(i: int) -> Dictionary:
	return DIVISIONS[clampi(i, 0, DIVISIONS.size() - 1)]


static func poisson(rng: RandomNumberGenerator, lam: float) -> int:
	var k := 0
	var p := exp(-lam)
	var cdf := p
	var u := rng.randf()
	while u > cdf and k < 9:
		k += 1
		p *= lam / k
		cdf += p
	return k


## Calendrier aller-retour (méthode du cercle) : liste de journées, chacune une
## liste de paires [domicile, extérieur].
static func round_robin(noms: Array, aller_retour := true) -> Array:
	var l := noms.duplicate()
	if l.size() % 2 == 1:
		l.append("")
	var n := l.size()
	var rounds := []
	for r in n - 1:
		var paires := []
		for i in n / 2:
			var a: String = l[i]
			var b: String = l[n - 1 - i]
			if a == "" or b == "":
				continue
			# Alterner domicile et extérieur d'une journée à l'autre (le pivot
			# selon la journée, les autres selon leur place, qui tourne).
			var dom := (r % 2 == 0) if i == 0 else (i % 2 == 0)
			if dom:
				paires.append([a, b])
			else:
				paires.append([b, a])
		rounds.append(paires)
		# Rotation : le premier reste fixe.
		var last: String = l.pop_back()
		l.insert(1, last)
	if aller_retour:
		var retour := []
		for r in rounds:
			var p2 := []
			for p in r:
				p2.append([p[1], p[0]])
			retour.append(p2)
		rounds.append_array(retour)
	return rounds
