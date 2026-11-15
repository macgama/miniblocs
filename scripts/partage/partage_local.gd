class_name PartageLocal
extends PartageBackend
## Atelier local : en attendant Steam, les créations publiées et reçues sont
## rangées dans user://partage/atelier_local/<clé>/ (fiche.json, contenu.json,
## apercu.png), exactement comme le Workshop les livrerait. Publier crée aussi
## un fichier .mbloc dans le dossier d'échange, à envoyer à un ami ; un .mbloc
## déposé dans ce dossier entre dans l'atelier local (recevoir_echange).

const ROOT := "user://partage/atelier_local"

## Dossier de l'atelier local (autre dossier pour les tests).
var root := ROOT

var _cache: Array = []
var _cache_ok := false


func nom() -> String:
	return "Atelier local"


func dossier_de(cle: String) -> String:
	return root.path_join(PaquetPartage.nom_dossier(cle))


func publier(p: Dictionary) -> void:
	var c := PaquetPartage.cle(p)
	var why := PaquetPartage.verifier(p)
	if why != "":
		publie.emit(false, c, "Publication impossible : %s." % why)
		return
	if not PaquetPartage.ecrire_dossier(p, dossier_de(c)):
		publie.emit(false, c, "Publication impossible : le dossier de l'atelier local ne s'écrit pas.")
		return
	var path := Partage.fichier_de(p)
	var ok := PaquetPartage.ecrire_fichier(p, path)
	_cache_ok = false
	liste_changee.emit()
	if ok:
		publie.emit(true, c, "« %s » est dans l'atelier local et dans le fichier %s, à envoyer à tes amis." % [String(p.fiche.titre), ProjectSettings.globalize_path(path)])
	else:
		publie.emit(true, c, "« %s » est dans l'atelier local." % String(p.fiche.titre))


## Ajoute un paquet reçu (fichier .mbloc lu) à l'atelier local. Rend sa clé.
func recevoir(p: Dictionary) -> String:
	if PaquetPartage.verifier(p) != "":
		return ""
	var c := PaquetPartage.cle(p)
	var dir := dossier_de(c)
	var deja := PaquetPartage.lire_dossier(dir, false)
	# Une version plus ancienne ne remplace pas celle qu'on a.
	if not deja.is_empty() and float(deja.fiche.get("maj", 0.0)) > float(p.fiche.get("maj", 0.0)):
		return c
	if not PaquetPartage.ecrire_dossier(p, dir):
		return ""
	_cache_ok = false
	liste_changee.emit()
	return c


func objets() -> Array:
	if _cache_ok:
		return _cache
	_cache.clear()
	_cache_ok = true
	var d := DirAccess.open(root)
	if d == null:
		return _cache
	for sub in d.get_directories():
		var dir := root.path_join(sub)
		var p := PaquetPartage.lire_dossier(dir, false)
		if p.is_empty():
			continue
		_cache.append({"cle": PaquetPartage.cle(p), "fiche": p.fiche, "dossier": dir, "source": "local"})
	_cache.sort_custom(func(a, b) -> bool: return float(a.fiche.get("maj", 0.0)) > float(b.fiche.get("maj", 0.0)))
	return _cache


func retirer(o: Dictionary) -> bool:
	var dir := String(o.get("dossier", ""))
	if not dir.begins_with(root):
		return false
	PaquetPartage.supprimer_dossier(dir)
	_cache_ok = false
	liste_changee.emit()
	return true


func oublier_cache() -> void:
	_cache_ok = false
