class_name Calques
extends RefCounted
## Registre commun des calques de carte (pollution, bruit, valeur, services…).
## Chaque système ajoute ses calques ; le panneau Cartes (touche N) les liste par
## groupe et n'en montre qu'un à la fois.
##
## Contrat partagé entre les systèmes :
##   Calques.ajouter(id, nom, groupe, afficher)   afficher(on: bool) montre ou cache
##   Calques.liste()                              [{id, nom, groupe, legende}] dans l'ordre d'ajout
##   Calques.afficher(id, on)                     montre id (et éteint les autres) ou le cache
##   Calques.actif()                              id du calque montré ("" = aucun)

static var _calques: Array = []
static var _actif := ""


## Ajoute (ou remplace) un calque. legende : texte court affiché sous la carte.
static func ajouter(id: String, nom: String, groupe: String, afficher_fn: Callable, legende := "") -> void:
	retirer(id)
	_calques.append({"id": id, "nom": nom, "groupe": groupe, "afficher": afficher_fn, "legende": legende})


static func retirer(id: String) -> void:
	for i in range(_calques.size() - 1, -1, -1):
		if String(_calques[i].id) == id:
			if _actif == id:
				_appeler(_calques[i], false)
				_actif = ""
			_calques.remove_at(i)


## Liste des calques (sans les fonctions), dans l'ordre d'ajout.
static func liste() -> Array:
	var out := []
	for c in _calques:
		out.append({"id": c.id, "nom": c.nom, "groupe": c.groupe, "legende": c.legende})
	return out


## Groupes dans l'ordre de leur premier calque.
static func groupes() -> Array:
	var out := []
	for c in _calques:
		if not out.has(c.groupe):
			out.append(c.groupe)
	return out


static func actif() -> String:
	return _actif


## Montre un calque (les autres s'éteignent) ou le cache.
static func afficher(id: String, on := true) -> void:
	if on:
		if _actif != "" and _actif != id:
			var old := _trouver(_actif)
			if not old.is_empty():
				_appeler(old, false)
		var c := _trouver(id)
		if c.is_empty():
			_actif = ""
			return
		_actif = id
		_appeler(c, true)
	elif _actif == id:
		var c := _trouver(id)
		if not c.is_empty():
			_appeler(c, false)
		_actif = ""


## Éteint le calque montré.
static func eteindre() -> void:
	if _actif != "":
		afficher(_actif, false)


## Oublie tout (changement de scène, tests).
static func vider() -> void:
	eteindre()
	_calques.clear()


static func _trouver(id: String) -> Dictionary:
	for c in _calques:
		if String(c.id) == id:
			return c
	return {}


static func _appeler(c: Dictionary, on: bool) -> void:
	var f: Callable = c.afficher
	if f.is_valid():
		f.call(on)
