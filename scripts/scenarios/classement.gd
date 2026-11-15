class_name Classement
extends RefCounted
## Classement des scénarios : les 10 meilleurs scores de chaque scénario,
## rangés sur cet ordinateur (user://scenarios_classement.json).
##
## Seules les victoires sans triche (réglages de l'Admin changés en cours de
## scénario) entrent au classement. Une entrée : {nom, score, medaille,
## jours, habitants, date, version}.
##
## Classement en ligne : le jeu appellera `envoi_en_ligne` (s'il est branché)
## avec l'id du scénario et l'entrée, et lira `lecture_en_ligne` pour
## l'afficher. Sur Steam, chaque scénario aura son classement nommé
## nom_steam(id) (« scenario_crue »…), en score décroissant ; rien d'autre à
## changer dans les scénarios.

const TAILLE := 10
const VERSION := 1

## Fichier du classement (remplaçable dans les tests).
static var chemin := "user://scenarios_classement.json"
## Envoi au classement en ligne : func(id: String, entree: Dictionary) -> void. Non branché pour l'instant.
static var envoi_en_ligne: Callable
## Lecture du classement en ligne : func(id: String) -> Array. Non branché pour l'instant.
static var lecture_en_ligne: Callable

static var _cache := {}
static var _charge := false


static func nom_steam(id: String) -> String:
	return "scenario_" + id


static func en_ligne() -> bool:
	return lecture_en_ligne.is_valid()


static func _lire() -> void:
	if _charge:
		return
	_charge = true
	_cache = {}
	if not FileAccess.file_exists(chemin):
		return
	var f := FileAccess.open(chemin, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		_cache = (d as Dictionary).get("scenarios", {})


static func _ecrire() -> void:
	var f := FileAccess.open(chemin, FileAccess.WRITE)
	if f == null:
		push_warning("Classement : impossible d'écrire " + chemin)
		return
	f.store_string(JSON.stringify({"version": VERSION, "scenarios": _cache}, "\t"))


## Oublie ce qui a été lu (après un changement de fichier, dans les tests).
static func recharger() -> void:
	_charge = false


## Les meilleurs scores d'un scénario, du premier au dernier.
static func liste(id: String) -> Array:
	_lire()
	return (_cache.get(id, []) as Array).duplicate(true)


static func meilleur(id: String) -> Dictionary:
	var l := liste(id)
	return l[0] if not l.is_empty() else {}


## Meilleure médaille obtenue sur ce scénario (0 : aucune).
static func meilleure_medaille(id: String) -> int:
	var m := 0
	for e in liste(id):
		m = maxi(m, int(e.get("medaille", 0)))
	return m


## Ajoute un score ; renvoie son rang (1 = premier) ou 0 s'il n'entre pas dans les 10.
static func ajouter(id: String, entree: Dictionary) -> int:
	_lire()
	var l: Array = _cache.get(id, [])
	var e := entree.duplicate(true)
	if not e.has("date"):
		e["date"] = Time.get_datetime_string_from_system().substr(0, 10)
	if not e.has("nom") or String(e.nom).strip_edges() == "":
		e["nom"] = nom_joueur()
	e["version"] = VERSION
	l.append(e)
	l.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.score) != int(b.score):
			return int(a.score) > int(b.score)
		return int(a.get("jours", 0)) < int(b.get("jours", 0)))
	var rang := l.find(e) + 1
	if l.size() > TAILLE:
		l.resize(TAILLE)
	if rang > TAILLE:
		rang = 0
	_cache[id] = l
	_ecrire()
	if envoi_en_ligne.is_valid():
		envoi_en_ligne.call(id, e)
	return rang


## Change le nom d'une entrée (écran de fin : « Ton nom au classement »).
static func renommer(id: String, rang: int, nom: String) -> void:
	_lire()
	var l: Array = _cache.get(id, [])
	nom = nom.strip_edges().substr(0, 24)
	if rang < 1 or rang > l.size() or nom == "":
		return
	l[rang - 1]["nom"] = nom
	_ecrire()


static func effacer(id := "") -> void:
	_lire()
	if id == "":
		_cache.clear()
	else:
		_cache.erase(id)
	_ecrire()


## Nom du joueur : son pseudo d'« Entre amis », sinon le nom de sa session.
static func nom_joueur() -> String:
	var p := Multijoueur.pseudo()
	if p.strip_edges() != "":
		return p
	for v in ["USERNAME", "USER"]:
		var n := OS.get_environment(v)
		if n != "":
			return n
	return "Maire anonyme"
