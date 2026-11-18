class_name PileGauche
extends Node
## Cartes flottantes de la colonne de gauche, empilées pour ne jamais se recouvrir.
## En haut (sous la barre du haut) : carte du tutoriel et des objectifs, puis la
## carte de l'habitant suivi. En bas (au-dessus du bord de l'écran) : carte de la
## case survolée, puis le fil « À faire ». Si la colonne manque de place (petite
## fenêtre, carte de la case très longue), le fil « À faire » se replie sur son titre.
## Chaque carte est un Control posé librement (pas dans un conteneur) ; on ne
## déplace que les cartes du bas-gauche et la carte de l'habitant, la carte du
## tutoriel reste où elle est et sert de repère.

const ECART := 8.0

## Callables -> Control (ou null) : les cartes, dans l'ordre d'empilement.
var haut: Array[Callable] = []
var bas: Array[Callable] = []


static func _visible(c: Control) -> bool:
	return c != null and is_instance_valid(c) and c.is_visible_in_tree() and c.size.y > 1.0


func _process(_delta: float) -> void:
	placer()


## Pose les cartes ; rend la place libre entre les deux piles (pour les tests).
func placer() -> float:
	var y := UiStyle.SIDE_TOP
	for i in haut.size():
		var c := haut[i].call() as Control
		if not _visible(c):
			continue
		# La première carte (tutoriel) reste où elle est : elle sert de repère.
		if i > 0:
			_poser_haut(c, y)
		y = c.get_global_rect().end.y + ECART
	var vue := 0.0
	var fond := INF
	for f in bas:
		var c := f.call() as Control
		if c == null or not is_instance_valid(c) or not c.is_inside_tree():
			continue
		vue = c.get_viewport_rect().size.y
		if fond == INF:
			fond = vue
		# Place qui reste sous la pile du haut : le fil « À faire » s'y adapte (même
		# caché faute de place, pour réapparaître quand elle revient).
		if fond < vue and c.has_meta("place"):
			var place: Callable = c.get_meta("place")
			place.call(fond - y)
		if not c.is_visible_in_tree():
			continue
		if fond < vue:
			_poser_bas(c, fond, vue)
		fond = c.get_global_rect().position.y - ECART
	return (fond - y) if fond != INF else 0.0


## Carte posée par son coin haut-gauche (offset_top, sans ancre en bas).
static func _poser_haut(c: Control, y: float) -> void:
	if c.anchor_top == 0.0 and c.anchor_bottom == 0.0:
		if absf(c.offset_top - y) > 0.5:
			var h := c.offset_bottom - c.offset_top
			c.offset_top = y
			c.offset_bottom = y + maxf(h, 0.0)
	else:
		c.global_position.y = y


## Carte ancrée en bas de l'écran qui grandit vers le haut : son bas va à `fond`.
static func _poser_bas(c: Control, fond: float, vue: float) -> void:
	var off := roundf(fond - vue)
	if c.anchor_bottom == 1.0 and absf(c.offset_bottom - off) > 0.5:
		c.offset_top = off
		c.offset_bottom = off
