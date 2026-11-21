class_name EchelleTemps
extends RefCounted
## Vitesse des mouvements visibles selon la vitesse du temps choisie (T, Maj + T).
##
## L'horloge (DayNight) avance de 1 s à 6000 s de jeu par seconde réelle : à
## cette allure, une voiture « vraie » traverserait la ville en un éclair. Les
## mouvements visibles (véhicules, piétons d'ambiance, engins et ouvriers des
## chantiers, bêtes, manèges, figurants…) suivent donc un facteur lisible, réglé
## sur la vitesse par défaut (1 jour/min = ×1) :
##
##   Pause 0 · Réel ×0,25 · 1 min/s ×0,5 · 10 min/s ×0,75 · 1 jour/min ×1 · 100 min/s ×2 · Turbo ×3
##
## Turbo (×10 du défaut) : les mouvements ne vont que 3 fois plus vite, sinon
## voitures et piétons sauteraient d'un bout à l'autre de la rue à chaque image.
##
## En pause, tout s'arrête. Ce qui dépend des heures de jeu (chantiers,
## production, emplois du temps des habitants…) lit déjà DayNight.unix_time et
## suit l'horloge exactement.
##
## Vue au sol (1re / 3e personne, à bord) : le joueur marche en temps réel ;
## pour rester cohérent avec lui, les mouvements visibles passent à ×1 (vitesse
## réelle) tant que le temps n'est pas en pause (`vue_sol_temps_reel`).
##
## Utilisation dans un _process : `var dt := EchelleTemps.dt(delta)`.

## Un facteur par vitesse de DayNight.SPEEDS (même ordre).
const FACTEURS := [0.0, 0.25, 0.5, 0.75, 1.0, 2.0, 3.0]

## Horloge du jeu en cours (réglée par DayNight). Sans horloge (vitrines,
## tests), le facteur vaut 1.
static var horloge: DayNight
## Vue au sol active (réglé par VueSol).
static var vue_sol := false
## En vue au sol, mouvements à vitesse réelle (×1) hors pause.
static var vue_sol_temps_reel := true
## Facteur imposé (tests) ; négatif = aucun.
static var force := -1.0


## Facteur des mouvements visibles (0 en pause).
static func facteur() -> float:
	if force >= 0.0:
		return force
	if horloge == null or not is_instance_valid(horloge):
		return 1.0
	var f := facteur_vitesse(horloge.speed_index)
	if f > 0.0 and vue_sol and vue_sol_temps_reel:
		return 1.0
	return f


## Facteur d'une vitesse de DayNight.SPEEDS (hors vue au sol).
static func facteur_vitesse(i: int) -> float:
	return float(FACTEURS[clampi(i, 0, FACTEURS.size() - 1)])


## Temps « visible » écoulé pendant delta secondes réelles.
static func dt(delta: float) -> float:
	return delta * facteur()


static func en_pause() -> bool:
	return facteur() <= 0.0
