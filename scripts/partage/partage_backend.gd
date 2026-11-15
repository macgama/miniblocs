class_name PartageBackend
extends RefCounted
## Où vont les créations publiées et d'où viennent celles des autres.
## Deux réalisations :
## - PartageLocal : un « atelier local » (user://partage/atelier_local), un
##   dossier par création, comme un objet du Workshop ; les fichiers .mbloc
##   reçus d'amis y entrent. C'est ce qui sert tant que le jeu n'est pas sur Steam.
## - PartageSteam : le Steam Workshop par GodotSteam (si le module est là et
##   que Steam tourne), mêmes dossiers, mêmes fiches.
## Le reste du jeu ne parle qu'à Partage, qui choisit.

## Publication finie (ok, clé de la création, texte pour le joueur).
signal publie(ok: bool, cle: String, info: String)
## La liste des créations disponibles a changé (téléchargement fini…).
signal liste_changee


func nom() -> String:
	return "?"


func est_steam() -> bool:
	return false


## Publie un paquet (PaquetPartage) : asynchrone, répond par le signal publie.
func publier(_p: Dictionary) -> void:
	publie.emit(false, "", "Partage indisponible.")


## Créations disponibles : [{cle, fiche, dossier, source}].
func objets() -> Array:
	return []


## Paquet complet d'un objet de objets() ({} si illisible).
func lire(o: Dictionary) -> Dictionary:
	return PaquetPartage.lire_dossier(String(o.get("dossier", "")))


func retirer(_o: Dictionary) -> bool:
	return false


## À appeler à chaque image (rappels de Steam).
func tick() -> void:
	pass
