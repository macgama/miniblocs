class_name PartageSteam
extends PartageBackend
## Steam Workshop, par le module GodotSteam (https://godotsteam.com).
##
## Prêt pour la sortie sur Steam : il ne sert que si le module est installé
## (singleton « Steam »), que Steam tourne et qu'un numéro d'application est
## réglé (Paramètres du projet → steam/initialization/app_id). Sinon, Partage
## garde l'atelier local. Le module est appelé par son nom (call), pour que le
## jeu se lance aussi sans lui.
##
## Un objet du Workshop = le dossier d'un paquet (fiche.json, contenu.json,
## apercu.png) : Steam l'envoie tel quel et le livre tel quel chez les abonnés.
## Les abonnements (bouton « S'abonner » de la page Steam) s'installent seuls
## (Partage.synchroniser).
##
## Appels GodotSteam utilisés : createItem, startItemUpdate, setItemTitle,
## setItemDescription, setItemTags, setItemContent, setItemPreview,
## setItemMetadata, submitItemUpdate, getSubscribedItems, getItemInstallInfo,
## unsubscribeItem, run_callbacks ; signaux item_created, item_updated,
## item_downloaded.

const ENVOI := "user://partage/steam_envoi"
var envoi := ENVOI
## k_EWorkshopFileTypeCommunity
const FILE_TYPE_COMMUNITY := 0
## k_EResultOK
const RESULT_OK := 1

var steam: Object
var app_id := 0
## Paquet en cours d'envoi (un à la fois).
var _envoi: Dictionary = {}
var _handle := 0


static func app_id_projet() -> int:
	return int(ProjectSettings.get_setting("steam/initialization/app_id", 0))


## Le module est-il là, Steam lancé, et le jeu a-t-il un numéro d'application ?
static func disponible() -> bool:
	if not Engine.has_singleton("Steam") or app_id_projet() <= 0:
		return false
	var s := Engine.get_singleton("Steam")
	return s != null and s.has_method("isSteamRunning") and bool(s.call("isSteamRunning"))


func _init() -> void:
	app_id = app_id_projet()
	if Engine.has_singleton("Steam"):
		brancher(Engine.get_singleton("Steam"))


## Branche l'objet Steam (le singleton GodotSteam, ou une doublure pour les tests).
func brancher(s: Object) -> void:
	steam = s
	if steam == null:
		return
	for sig in [["item_created", _on_created], ["item_updated", _on_updated], ["item_downloaded", _on_downloaded]]:
		if steam.has_signal(sig[0]) and not steam.is_connected(sig[0], sig[1]):
			steam.connect(sig[0], sig[1])


func nom() -> String:
	return "Steam Workshop"


func est_steam() -> bool:
	return true


func tick() -> void:
	if steam != null and steam.has_method("run_callbacks"):
		steam.call("run_callbacks")


func publier(p: Dictionary) -> void:
	var c := PaquetPartage.cle(p)
	if steam == null:
		publie.emit(false, c, "Steam n'est pas lancé.")
		return
	if not _envoi.is_empty():
		publie.emit(false, c, "Une autre création part déjà sur le Workshop, patiente un instant.")
		return
	var dir := envoi.path_join(PaquetPartage.nom_dossier(c))
	if not PaquetPartage.ecrire_dossier(p, dir):
		publie.emit(false, c, "Le dossier d'envoi ne s'écrit pas.")
		return
	_envoi = {"paquet": p, "dossier": dir}
	var fid := int(Partage.publication(c).get("steam_id", 0))
	if fid > 0:
		_mettre_a_jour(fid)
	else:
		steam.call("createItem", app_id, FILE_TYPE_COMMUNITY)


func _on_created(result: int, file_id: int, accept_tos: bool) -> void:
	if _envoi.is_empty():
		return
	var p: Dictionary = _envoi.paquet
	if result != RESULT_OK:
		_fin(false, "Steam a refusé la création de l'objet (code %d)." % result)
		return
	Partage.noter_publication(PaquetPartage.cle(p), {"steam_id": file_id})
	if accept_tos:
		# Le joueur doit d'abord accepter l'accord du Workshop sur Steam.
		OS.shell_open("steam://url/CommunityFilePage/%d" % file_id)
	_mettre_a_jour(file_id)


func _mettre_a_jour(file_id: int) -> void:
	var p: Dictionary = _envoi.paquet
	var f: Dictionary = p.fiche
	var dir: String = _envoi.dossier
	_handle = int(steam.call("startItemUpdate", app_id, file_id))
	steam.call("setItemTitle", _handle, String(f.titre).left(128))
	steam.call("setItemDescription", _handle, String(f.get("description", "")).left(7999))
	steam.call("setItemTags", _handle, Array(f.get("etiquettes", [])) + [String(f.genre)], false)
	steam.call("setItemMetadata", _handle, String(f.cle).left(4999))
	steam.call("setItemContent", _handle, ProjectSettings.globalize_path(dir))
	if FileAccess.file_exists(dir.path_join(PaquetPartage.APERCU)):
		steam.call("setItemPreview", _handle, ProjectSettings.globalize_path(dir.path_join(PaquetPartage.APERCU)))
	steam.call("submitItemUpdate", _handle, "Mise à jour depuis MiniBlocs")


func _on_updated(result: int, accept_tos: bool) -> void:
	if _envoi.is_empty():
		return
	if result != RESULT_OK:
		_fin(false, "L'envoi sur le Workshop a échoué (code %d)." % result)
		return
	_fin(true, "Publié sur le Steam Workshop : accepte l'accord du Workshop sur Steam pour qu'il soit visible." if accept_tos else "Publié sur le Steam Workshop.")


func _fin(ok: bool, info: String) -> void:
	var c := PaquetPartage.cle(_envoi.paquet)
	_envoi = {}
	publie.emit(ok, c, info)


func _on_downloaded(_result: int, _file_id: int, _app_id: int) -> void:
	liste_changee.emit()


func objets() -> Array:
	var out := []
	if steam == null:
		return out
	var subs: Variant = steam.call("getSubscribedItems")
	if not (subs is Array):
		return out
	for fid in subs:
		var info: Variant = steam.call("getItemInstallInfo", int(fid))
		if not (info is Dictionary) or not bool((info as Dictionary).get("ret", false)):
			continue
		var dir := String(info.get("folder", ""))
		var p := PaquetPartage.lire_dossier(dir, false)
		if p.is_empty():
			continue
		out.append({"cle": PaquetPartage.cle(p), "fiche": p.fiche, "dossier": dir, "source": "steam", "steam_id": int(fid)})
	return out


func retirer(o: Dictionary) -> bool:
	if steam == null or int(o.get("steam_id", 0)) <= 0:
		return false
	steam.call("unsubscribeItem", int(o.steam_id))
	liste_changee.emit()
	return true
