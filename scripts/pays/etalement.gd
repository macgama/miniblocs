class_name Etalement
extends RefCounted
## Calculs du jour (minuit de jeu) : beaucoup de systèmes font leur bilan à la même
## image. Chacun demande libre() avant le sien : un seul passe par image, les
## autres attendent les images suivantes (quelques images plus tard, rien ne change).

static var _image := -1


## Vrai si aucun gros calcul du jour n'a encore eu lieu à cette image (et le réserve).
static func libre() -> bool:
	var f := Engine.get_process_frames()
	if f == _image:
		return false
	_image = f
	return true
