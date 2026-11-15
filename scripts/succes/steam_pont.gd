class_name SteamPont
extends RefCounted
## Pont vers Steam, prêt pour GodotSteam (https://godotsteam.com, extension GDExtension
## gratuite). Sans GodotSteam (aujourd'hui, et dans l'éditeur), tout marche quand même :
## les succès sont gardés en local (Succes) et chaque appel ici ne fait rien.
##
## Pour brancher Steam le jour venu :
## 1. Installer l'extension GodotSteam (AssetLib « GodotSteam GDExtension ») dans addons/.
## 2. Mettre l'App ID du jeu dans steam_appid.txt (à côté de l'exe) pendant les essais.
## 3. Créer les succès sur Steamworks avec docs/steam/succes-steam.csv (noms MB_…).
## Rien d'autre à changer dans le code : SteamPont trouve le singleton « Steam ».

## Appels faits (tests : on vérifie ce qui serait parti vers Steam).
static var journal: Array = []
## Remplace le vrai singleton (tests).
static var faux: Object = null
static var _init_fait := false
static var _actif := false
static var _a_envoyer := false


static func _steam() -> Object:
	if faux != null:
		return faux
	if Engine.has_singleton("Steam"):
		return Engine.get_singleton("Steam")
	return null


## Démarre Steam une fois (au lancement du jeu). Renvoie true si Steam répond.
static func demarrer() -> bool:
	if _init_fait:
		return _actif
	_init_fait = true
	var s := _steam()
	if s == null:
		return false
	var res: Variant = null
	if s.has_method("steamInitEx"):
		res = s.call("steamInitEx")
	elif s.has_method("steamInit"):
		res = s.call("steamInit")
	# steamInitEx renvoie {status: 0 = OK, verbal}, steamInit un booléen.
	if res is Dictionary:
		_actif = int((res as Dictionary).get("status", 1)) == 0
	else:
		_actif = bool(res)
	journal.append(["demarrer", _actif])
	if _actif:
		Succes.synchroniser_steam()
	return _actif


static func actif() -> bool:
	return _actif and _steam() != null


## À appeler à chaque image (callbacks de Steam).
static func tick() -> void:
	if not actif():
		return
	var s := _steam()
	if s.has_method("run_callbacks"):
		s.call("run_callbacks")
	if _a_envoyer:
		envoyer()


static func debloquer(api: String, envoyer_tout_de_suite := true) -> void:
	journal.append(["succes", api])
	if not actif():
		return
	var s := _steam()
	if s.has_method("setAchievement"):
		s.call("setAchievement", api)
	_a_envoyer = true
	if envoyer_tout_de_suite:
		envoyer()


## Barre d'avancement de Steam (« 12 / 25 incendies »), aux paliers de 10 % seulement
## (Steam affiche une notification à chaque appel).
static var _dernier_palier := {}


static func progres(api: String, v: float, seuil: float) -> void:
	if not actif() or seuil <= 1.0:
		return
	var palier := floori(v / seuil * 10.0)
	if palier <= int(_dernier_palier.get(api, 0)) or palier >= 10:
		return
	_dernier_palier[api] = palier
	var s := _steam()
	if s.has_method("indicateAchievementProgress"):
		s.call("indicateAchievementProgress", api, int(v), int(seuil))


static func est_debloque(api: String) -> bool:
	if not actif():
		return false
	var s := _steam()
	if not s.has_method("getAchievement"):
		return false
	var r: Variant = s.call("getAchievement", api)
	if r is Dictionary:
		return bool((r as Dictionary).get("achieved", false))
	return bool(r)


static func envoyer() -> void:
	_a_envoyer = false
	if not actif():
		return
	var s := _steam()
	if s.has_method("storeStats"):
		s.call("storeStats")


## Le jeu tourne-t-il sur un Steam Deck ? (Steam le dit ; sinon la variable
## d'environnement SteamDeck=1 que Steam pose sur la console.)
static func steam_deck() -> bool:
	var s := _steam()
	if actif() and s.has_method("isSteamRunningOnSteamDeck") and bool(s.call("isSteamRunningOnSteamDeck")):
		return true
	return OS.get_environment("SteamDeck") == "1"


## Clavier à l'écran de Steam (Steam Deck, mode Big Picture) pour un champ de texte.
## Renvoie true si Steam l'a ouvert.
static func clavier(rect: Rect2, multiligne := false) -> bool:
	if not actif():
		return false
	var s := _steam()
	if s.has_method("showFloatingGamepadTextInput"):
		return bool(s.call("showFloatingGamepadTextInput", 1 if multiligne else 0,
			int(rect.position.x), int(rect.position.y), int(rect.size.x), int(rect.size.y)))
	return false


## Remise à zéro (tests).
static func reinitialiser() -> void:
	journal = []
	faux = null
	_init_fait = false
	_actif = false
	_a_envoyer = false
	_dernier_palier = {}
