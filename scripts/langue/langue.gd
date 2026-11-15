class_name Langue
extends RefCounted
## Langue du jeu. Le français est la langue d'origine (aucun fichier) ; les autres
## langues sont dans res://assets/langues/<code>.json et passent par TraductionAuto.
## Options > Jeu > Langue change la langue tout de suite (OptionsJeu.langue).

const DOSSIER := "res://assets/langues/"
## [code, nom affiché dans sa propre langue]
const LANGUES := [["fr", "Français"], ["en", "English"]]

static var _chargees := {}
static var actuelle := "fr"


## La traduction branchée sur TranslationServer (null en français).
static var _branchee: Translation = null


## Applique une langue : charge sa traduction (une fois) et change la langue de Godot.
## Tous les textes affichés se traduisent aussitôt.
static func activer(code: String) -> void:
	if not existe(code):
		code = "fr"
	if code != "fr" and not _chargees.has(code):
		var t := TraductionAuto.new()
		if t.charger(DOSSIER + code + ".json", code):
			_chargees[code] = t
		else:
			code = "fr"
	# Une seule traduction branchée à la fois : sinon le moteur se rabat sur la
	# langue de secours (l'anglais) pour les textes français.
	var voulue: Translation = _chargees.get(code)
	if _branchee != voulue:
		if _branchee != null:
			TranslationServer.remove_translation(_branchee)
		if voulue != null:
			TranslationServer.add_translation(voulue)
		_branchee = voulue
	actuelle = code
	if TranslationServer.get_locale() != code:
		TranslationServer.set_locale(code)


static func existe(code: String) -> bool:
	for l in LANGUES:
		if l[0] == code:
			return true
	return false


## Langue proposée au premier lancement : celle du système si le jeu la connaît,
## l'anglais sinon.
static func langue_systeme() -> String:
	var l := OS.get_locale_language()
	if existe(l):
		return l
	return "en"


## Traduit un texte dans la langue actuelle (pour du texte dessiné à la main,
## hors Label et Button qui se traduisent seuls).
static func t(s: String) -> String:
	if actuelle == "fr":
		return s
	var tr_ = _chargees.get(actuelle)
	return (tr_ as TraductionAuto).traduire(s) if tr_ != null else s



## La traduction chargée d'une langue (null pour le français).
static func traduction(code: String) -> TraductionAuto:
	if code != "fr" and not _chargees.has(code):
		var avant := actuelle
		activer(code)
		activer(avant)
	return _chargees.get(code)
