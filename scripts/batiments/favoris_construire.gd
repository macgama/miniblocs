class_name FavorisConstruire
extends RefCounted
## Favoris (étoile sur une vignette) et bâtiments récemment posés du panneau
## Construire. Communs à toutes les parties : user://construire_favoris.json.

const PATH := "user://construire_favoris.json"
const MAX_RECENTS := 12

static var persist := true
static var favoris: Array[String] = []
static var recents: Array[String] = []
static var _loaded := false


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if not persist or not FileAccess.file_exists(PATH):
		return
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if d is Dictionary:
		for id in (d as Dictionary).get("favoris", []):
			favoris.append(String(id))
		for id in (d as Dictionary).get("recents", []):
			recents.append(String(id))


static func _write() -> void:
	if not persist:
		return
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"favoris": favoris, "recents": recents}))


static func est_favori(id: String) -> bool:
	ensure_loaded()
	return favoris.has(id)


## Ajoute ou retire l'étoile. Renvoie le nouvel état.
static func basculer(id: String) -> bool:
	ensure_loaded()
	if favoris.has(id):
		favoris.erase(id)
	else:
		favoris.append(id)
	_write()
	return favoris.has(id)


## Un bâtiment vient d'être choisi : en tête des récents.
static func noter(id: String) -> void:
	ensure_loaded()
	if id == "" or BuildingCatalog.get_type(id).is_empty():
		return
	recents.erase(id)
	recents.push_front(id)
	if recents.size() > MAX_RECENTS:
		recents.resize(MAX_RECENTS)
	_write()


## Ids encore connus du catalogue (un modèle supprimé disparaît).
static func liste(quoi: String) -> Array[String]:
	ensure_loaded()
	var out: Array[String] = []
	for id in (favoris if quoi == "favoris" else recents):
		var t := BuildingCatalog.get_type(id)
		if not t.is_empty() and not t.get("cache", false):
			out.append(id)
	return out


static func vider_pour_tests() -> void:
	favoris.clear()
	recents.clear()
	_loaded = true


## Texte comparable : minuscules, sans accents (« ecole » trouve « École »).
static func plier(s: String) -> String:
	var t := s.to_lower()
	const DE := "àâäáãåçéèêëíìîïñóòôöõúùûüýÿœæ"
	const EN := ["a", "a", "a", "a", "a", "a", "c", "e", "e", "e", "e", "i", "i", "i", "i", "n", "o", "o", "o", "o", "o", "u", "u", "u", "u", "y", "y", "oe", "ae"]
	var out := ""
	for ch in t:
		var i := DE.find(ch)
		out += EN[i] if i >= 0 else ch
	return out
