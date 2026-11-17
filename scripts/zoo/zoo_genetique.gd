class_name ZooGenetique
extends RefCounted
## Zoo : génétique des animaux (gènes hérités, consanguinité, diversité).
##
## - Chaque animal porte quatre gènes, de -1 (faible) à +1 (fort), 0 = moyenne de
##   l'espèce : taille, santé (résistance aux maladies), fertilité, longévité.
## - Un petit hérite de la moyenne de ses parents, plus un peu de hasard.
## - La généalogie (ZooSysteme.genealogie) garde les parents de chaque animal, même
##   vendu, mort ou relâché : on calcule la parenté (coefficient de parenté de
##   Malécot) et la consanguinité d'un petit (= parenté de ses parents).
## - La consanguinité affaiblit (dépression de consanguinité) : santé, fertilité et
##   longévité baissent, et au-delà de 12,5 % (demi-frère × demi-sœur) une tare
##   héréditaire peut apparaître.
## - La diversité génétique d'un groupe = 1 - parenté moyenne (paires et soi-même) :
##   2 fondateurs sans lien = 75 %, 10 = 95 %. Des animaux venus d'ailleurs
##   (échanges, expéditions) l'améliorent.

const GENES := ["taille", "sante", "fertilite", "longevite"]
const NOMS := {"taille": "Taille", "sante": "Santé", "fertilite": "Fertilité", "longevite": "Longévité"}
## Écart des gènes d'un fondateur (élevage) et d'un animal sauvage.
const ECART_ELEVAGE := 0.35
const ECART_SAUVAGE := 0.45
## Hasard à la naissance (mélange des deux parents).
const MUTATION := 0.25
## Effet de la consanguinité sur chaque gène (F = 0,25 : -0,4 en santé).
const DEPRESSION := {"taille": 0.5, "sante": 1.6, "fertilite": 2.0, "longevite": 1.2}
## Seuil d'alerte (demi-frère × demi-sœur, grand-parent × petit-enfant).
const SEUIL_TARE := 0.125
const TARES := ["cœur fragile", "hanches faibles", "vue basse", "système immunitaire faible", "dents mal plantées"]
const PROFONDEUR := 8


static func fondateur(rng: RandomNumberGenerator, sauvage := false) -> Dictionary:
	var g := {}
	var ecart := ECART_SAUVAGE if sauvage else ECART_ELEVAGE
	for k in GENES:
		g[k] = snappedf(clampf(rng.randfn(0.0, ecart), -1.0, 1.0), 0.01)
	return g


static func heritage(rng: RandomNumberGenerator, pere: Dictionary, mere: Dictionary) -> Dictionary:
	var g := {}
	for k in GENES:
		var m := (float(pere.get(k, 0.0)) + float(mere.get(k, 0.0))) * 0.5
		g[k] = snappedf(clampf(m + rng.randfn(0.0, MUTATION), -1.0, 1.0), 0.01)
	return g


## Gène effectif d'un animal : le gène, moins la consanguinité, moins sa tare éventuelle.
static func effectif(a: Dictionary, gene: String) -> float:
	var g: Dictionary = a.get("genes", {})
	var v := float(g.get(gene, 0.0)) - float(a.get("consang", 0.0)) * float(DEPRESSION.get(gene, 1.0))
	if String(a.get("tare", "")) != "" and gene == "sante":
		v -= 0.4
	return clampf(v, -1.5, 1.0)


## Parenté de deux animaux (probabilité qu'un gène pris au hasard chez l'un et chez
## l'autre soit le même par descendance) ; gen : la généalogie {id: {pere, mere, F, naiss}}.
static func parente(gen: Dictionary, a: int, b: int, memo: Dictionary = {}, prof := 0) -> float:
	if a < 0 or b < 0 or prof > PROFONDEUR or not gen.has(a) or not gen.has(b):
		return 0.0
	if a == b:
		return 0.5 * (1.0 + float(gen[a].get("F", 0.0)))
	# a = le plus jeune (il ne peut pas être l'ancêtre de b).
	var na := float(gen[a].get("naiss", 0.0))
	var nb := float(gen[b].get("naiss", 0.0))
	if na < nb or (na == nb and a < b):
		var t := a
		a = b
		b = t
	var cle := Vector2i(a, b)
	if memo.has(cle):
		return float(memo[cle])
	var r := 0.5 * (parente(gen, int(gen[a].get("pere", -1)), b, memo, prof + 1) + parente(gen, int(gen[a].get("mere", -1)), b, memo, prof + 1))
	memo[cle] = r
	return r


## Diversité génétique d'un groupe d'animaux (ids de la généalogie), de 0 à 1.
static func diversite(gen: Dictionary, ids: Array) -> float:
	if ids.is_empty():
		return 0.0
	var memo := {}
	var s := 0.0
	for i in ids.size():
		for j in ids.size():
			if j < i:
				continue
			var k := parente(gen, int(ids[i]), int(ids[j]), memo)
			s += k if i == j else 2.0 * k
	return clampf(1.0 - s / float(ids.size() * ids.size()), 0.0, 1.0)


## Parenté moyenne d'un animal avec un groupe (sans lui) : basse = précieux pour l'élevage.
static func parente_moyenne(gen: Dictionary, aid: int, ids: Array) -> float:
	var memo := {}
	var s := 0.0
	var n := 0
	for b in ids:
		if int(b) == aid:
			continue
		s += parente(gen, aid, int(b), memo)
		n += 1
	return s / float(n) if n > 0 else 0.0


## Ancêtres d'un animal (jusqu'à PROFONDEUR générations), pour élaguer la généalogie.
static func ancetres(gen: Dictionary, aid: int, out: Dictionary, prof := 0) -> void:
	if aid < 0 or out.has(aid) or not gen.has(aid) or prof > PROFONDEUR:
		return
	out[aid] = true
	ancetres(gen, int(gen[aid].get("pere", -1)), out, prof + 1)
	ancetres(gen, int(gen[aid].get("mere", -1)), out, prof + 1)


## « +0,3 » → texte court pour la fiche (Excellent, Bon, Moyen, Faible, Très faible).
static func qualite(v: float) -> String:
	if v >= 0.5:
		return "excellente"
	if v >= 0.15:
		return "bonne"
	if v > -0.15:
		return "moyenne"
	if v > -0.5:
		return "faible"
	return "très faible"


static func pourcent(v: float) -> String:
	return "%d %%" % roundi(v * 100.0) if v >= 0.01 or v == 0.0 else "%.1f %%" % (v * 100.0)
