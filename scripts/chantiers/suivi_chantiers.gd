class_name SuiviChantiers
extends Node
## Fait avancer tous les chantiers « génériques » (voies, réseaux…) au rythme
## des équipes (Chantiers) : le travail ne compte que pendant les horaires de
## l'équipe, à la vitesse de la vie, et le prix se paie au fil des travaux.
##
## Les bâtiments ont leur propre suivi (BatimentsVie), plus riche en étapes.
##
## Utilisation (le propriétaire garde l'avancement dans sa donnée et le sauvegarde) :
##   SuiviChantiers.instance.commencer("voie:12", heures, maj, fini, av, cout)
##   maj(av: float, etape: Array) est appelé à chaque progrès ;
##   fini() une fois le chantier terminé (ou tout de suite en construction instantanée).
## Au chargement d'une partie, le propriétaire rappelle commencer(...) avec son av.

signal avance(cle: String, av: float)
signal termine(cle: String)

static var instance: SuiviChantiers

var buildings: BuildingSystem
var ambiance: DayNight
var population: Population

## cle -> {"hr", "av", "maj", "fini", "du", "cout", "etapes", "attente"}
var chantiers := {}
var au_travail := false
var _t_prev := -1.0
var _acc := 0.0
var _clock := 0.0


func setup(b: BuildingSystem, a: DayNight, p: Population) -> void:
	buildings = b
	ambiance = a
	population = p
	_t_prev = now()
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func now() -> float:
	return ambiance.unix_time if ambiance != null else _clock


func offset_h() -> float:
	return ambiance.utc_offset() if ambiance != null else 0.0


## Lance (ou reprend, avec av > 0) un chantier. cout : prix total, payé au fil
## des travaux ; du : ce qui reste à payer (par défaut cout × (1 − av)).
func commencer(cle: String, heures_reelles: float, maj := Callable(), fini := Callable(), av := 0.0,
		cout := 0, etapes: Array = Chantiers.ETAPES_VOIE, du := -1) -> void:
	if du < 0:
		du = roundi(float(cout) * (1.0 - av))
	chantiers[cle] = {"hr": maxf(heures_reelles, 0.1), "av": clampf(av, 0.0, 1.0), "maj": maj, "fini": fini,
		"du": du, "cout": cout, "etapes": etapes, "attente": false}
	if Chantiers.instantanes() or av >= 1.0:
		terminer(cle)
		return
	if maj.is_valid():
		maj.call(float(chantiers[cle].av), Chantiers.etape(etapes, float(chantiers[cle].av)))


func en_cours(cle: String) -> bool:
	return chantiers.has(cle)


func avancement(cle: String) -> float:
	return float(chantiers[cle].av) if chantiers.has(cle) else 1.0


func reste_a_payer(cle: String) -> int:
	return int(chantiers[cle].du) if chantiers.has(cle) else 0


func en_attente(cle: String) -> bool:
	return chantiers.has(cle) and bool(chantiers[cle].attente)


func etape(cle: String) -> Array:
	if not chantiers.has(cle):
		return []
	return Chantiers.etape(chantiers[cle].etapes, float(chantiers[cle].av))


## Termine tout de suite (le reste dû est payé).
func terminer(cle: String) -> void:
	if not chantiers.has(cle):
		return
	var c: Dictionary = chantiers[cle]
	chantiers.erase(cle)
	_payer(int(c.du))
	c.av = 1.0
	if (c.maj as Callable).is_valid():
		(c.maj as Callable).call(1.0, Chantiers.etape(c.etapes, 1.0))
	if (c.fini as Callable).is_valid():
		(c.fini as Callable).call()
	termine.emit(cle)


## Abandonne un chantier (voie démolie…) sans rien payer de plus.
func annuler(cle: String) -> void:
	chantiers.erase(cle)


func terminer_tout() -> void:
	for cle in chantiers.keys():
		terminer(cle)


## Date prévue de fin d'un chantier, au rythme actuel.
func fin_prevue(cle: String) -> float:
	if not chantiers.has(cle):
		return now()
	var c: Dictionary = chantiers[cle]
	var reste := (1.0 - float(c.av)) * float(c.hr) / Chantiers.rythme(population)
	return Chantiers.date_apres(now(), reste, offset_h())


func _payer(v: int) -> void:
	if v > 0 and buildings != null and not buildings.unlimited_money:
		buildings.money -= v


func _process(delta: float) -> void:
	_clock += delta
	_acc += delta
	if _acc < 0.2:
		return
	_acc = 0.0
	mettre_a_jour()


## Avance tous les chantiers selon les heures de travail écoulées.
func mettre_a_jour() -> void:
	var t := now()
	if _t_prev < 0.0:
		_t_prev = t
	if Chantiers.instantanes():
		_t_prev = t
		terminer_tout()
		return
	var off := offset_h()
	var heures := Chantiers.heures_ouvrees(_t_prev, t, off)
	_t_prev = t
	var local := t + off * 3600.0
	au_travail = Chantiers.au_travail(fposmod(local, 86400.0) / 3600.0, Chantiers.jour_semaine(local))
	if heures <= 0.0 or chantiers.is_empty():
		return
	var k := Chantiers.rythme(population)
	var finis := []
	for cle in chantiers.keys():
		var c: Dictionary = chantiers[cle]
		var dp := minf(heures * k / float(c.hr), 1.0 - float(c.av))
		var du := int(c.du)
		if du > 0:
			var part := mini(du, ceili(float(c.cout) * dp))
			var libre := buildings == null or buildings.unlimited_money
			if not libre and buildings.money < part:
				c.attente = true
				continue
			c.attente = false
			_payer(part)
			c.du = du - part
		c.av = float(c.av) + dp
		if float(c.av) >= 0.9999:
			finis.append(cle)
			continue
		if (c.maj as Callable).is_valid():
			(c.maj as Callable).call(float(c.av), Chantiers.etape(c.etapes, float(c.av)))
		avance.emit(cle, float(c.av))
	for cle in finis:
		terminer(cle)
