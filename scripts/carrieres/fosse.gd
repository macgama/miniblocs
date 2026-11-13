class_name Fosse
extends RefCounted
## Géométrie d'une fosse d'extraction en gradins (ou, à l'envers, d'une verse
## à stériles, d'un terril) sur un rectangle de cases de 1 m².
##
## Le creusement avance comme dans une vraie carrière : gradin par gradin, en
## partant du côté des installations. Le gradin k descend la roche jusqu'au
## niveau `haut - (k + 1) × gradin`, et il est en retrait de `k × risberme`
## cases du bord : les parois forment des marches. Chaque case taillée est une
## « passe » ; une passe n'est faite que lorsque le volume extrait la paie
## entièrement, donc le relief change par paliers visibles.
##
## Tout l'état tient dans `vol` (m³ déjà déplacés) et les hauteurs d'origine
## `h0` : en rejouant les passes depuis zéro, on retrouve le même relief.
## Une verse (signe +1) fait l'inverse : elle monte par couches de plus en
## plus petites, en tronc de pyramide.

## -1 : on creuse (fosse) ; +1 : on remblaie (verse, terril).
var signe := -1
var rect := Rect2i()
## Hauteurs d'origine des cases, ligne par ligne (NaN : case inconnue).
var h0 := PackedFloat32Array()
## Hauteur d'un gradin (m) et largeur d'une risberme (cases).
var gradin := 6.0
var risberme := 4
## Profondeur maximale sous le point le plus bas du bord (ou hauteur maximale
## au-dessus du point le plus haut, pour une verse).
var profondeur := 40.0
## Côté de départ du front : 0 nord (z min), 1 est (x max), 2 sud, 3 ouest.
var depart := 0
## Volume déjà déplacé (m³), et volume pas encore « payé » en passe complète.
var vol := 0.0

var cur := PackedFloat32Array()
var _ordre := PackedInt32Array()
var _retrait := PackedInt32Array()
var _k := 0
var _i := 0
var _reste := 0.0
var _haut := 0.0
var _limite := 0.0
var _niveaux := 0
var _capacite := -1.0
## Dernière case taillée (pour poser la pelle) et nombre de passes faites.
var front := Vector2i(-1, -1)
var passes := 0


## Prépare une fosse sur rect à partir des hauteurs actuelles (heights[i] :
## case rect.position + (i % w, i / w)).
func preparer(r: Rect2i, heights: PackedFloat32Array, sgn := -1) -> void:
	rect = r
	h0 = heights.duplicate()
	signe = sgn
	_init_geometrie()


func _init_geometrie() -> void:
	var w := rect.size.x
	var d := rect.size.y
	var n := w * d
	_retrait.resize(n)
	var keys := []
	keys.resize(n)
	var lo := INF
	var hi := -INF
	for j in d:
		for i in w:
			var idx := i + j * w
			_retrait[idx] = mini(mini(i, w - 1 - i), mini(j, d - 1 - j))
			var h := h0[idx]
			if is_nan(h):
				continue
			hi = maxf(hi, h)
			# Fosse : la profondeur se compte sous le point le plus bas du bord.
			if signe > 0 or _retrait[idx] == 0:
				lo = minf(lo, h)
	if lo == INF:
		lo = 0.0
		hi = 0.0
	if signe < 0:
		_haut = ceilf(hi)
		_limite = floorf(lo - profondeur)
		_niveaux = maxi(1, ceili((_haut - _limite) / gradin))
	else:
		_haut = floorf(lo)
		_limite = ceilf(hi + profondeur)
		_niveaux = maxi(1, ceili((_limite - _haut) / gradin))
	# Ordre de passage : en balayant depuis le côté de départ, rang par rang,
	# en serpentant (comme une pelle qui avance sur son front).
	var ordre := []
	for j in d:
		for i in w:
			var a := 0
			var b := 0
			match depart:
				0:
					a = j
					b = i
				1:
					a = w - 1 - i
					b = j
				2:
					a = d - 1 - j
					b = i
				_:
					a = i
					b = j
			if signe > 0:
				# Une verse monte depuis son centre.
				a = -_retrait[i + j * w]
				b = i + j * w
			var serp := b if posmod(a, 2) == 0 else -b
			ordre.append([a, serp, i + j * w])
	ordre.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0] or (x[0] == y[0] and x[1] < y[1]))
	_ordre.resize(n)
	for k in n:
		_ordre[k] = int(ordre[k][2])
	_rejouer()


## Niveau visé par le gradin k.
func niveau(k: int) -> float:
	if signe < 0:
		return maxf(_haut - (k + 1) * gradin, _limite)
	return minf(_haut + (k + 1) * gradin, _limite)


func _rejouer() -> void:
	cur = h0.duplicate()
	_k = 0
	_i = 0
	_reste = 0.0
	passes = 0
	front = Vector2i(-1, -1)
	var v := vol
	vol = 0.0
	avancer(v)


## Volume d'une passe sur la case idx au gradin k (0 si rien à faire).
func _passe(idx: int, k: int) -> float:
	var h := cur[idx]
	if is_nan(h):
		return 0.0
	if _retrait[idx] < k * risberme:
		return 0.0
	var lv := niveau(k)
	return h - lv if signe < 0 else lv - h


## Avance de v m³ : renvoie les cases changées {Vector2i: nouvelle hauteur}.
## Ce qui ne paie pas une passe complète attend la suite.
func avancer(v: float) -> Dictionary:
	var changed := {}
	vol += maxf(v, 0.0)
	_reste += maxf(v, 0.0)
	var w := rect.size.x
	var n := _ordre.size()
	while _k < _niveaux:
		if _i >= n:
			_k += 1
			_i = 0
			continue
		var idx := _ordre[_i]
		var need := _passe(idx, _k)
		if need <= 0.0:
			_i += 1
			continue
		if _reste + 1e-6 < need:
			break
		_reste -= need
		cur[idx] = niveau(_k)
		front = rect.position + Vector2i(idx % w, idx / w)
		changed[front] = cur[idx]
		passes += 1
		_i += 1
	if _k >= _niveaux:
		# Pleine : le volume en trop n'est pas déplacé.
		vol -= _reste
		_reste = 0.0
	return changed


func pleine() -> bool:
	return _k >= _niveaux


## Volume total que la fosse peut déplacer (m³).
func capacite() -> float:
	if _capacite >= 0.0:
		return _capacite
	var f := Fosse.new()
	f.signe = signe
	f.gradin = gradin
	f.risberme = risberme
	f.rect = rect
	f.h0 = h0
	f._ordre = _ordre
	f._retrait = _retrait
	f._haut = _haut
	f._limite = _limite
	f._niveaux = _niveaux
	f.cur = h0.duplicate()
	f.avancer(1.0e12)
	_capacite = f.vol
	return _capacite


func restant() -> float:
	return maxf(capacite() - vol, 0.0)


## Profondeur actuelle (m) sous le point le plus haut d'origine, ou hauteur d'une verse.
func profondeur_actuelle() -> float:
	var best := 0.0
	for i in cur.size():
		if not is_nan(cur[i]) and not is_nan(h0[i]):
			best = maxf(best, absf(cur[i] - h0[i]))
	return best


## Niveau du gradin en cours (fond actuel de la fosse ou sommet de la verse).
func niveau_actuel() -> float:
	return niveau(mini(_k, _niveaux - 1))


func gradin_actuel() -> int:
	return mini(_k + 1, _niveaux)


func nb_gradins() -> int:
	return _niveaux


## Hauteur de la case c dans la fosse (NaN hors du rectangle).
func hauteur(c: Vector2i) -> float:
	if not rect.has_point(c):
		return NAN
	var p := c - rect.position
	return cur[p.x + p.y * rect.size.x]


## Cases modifiées (pour remettre le relief) : {Vector2i: hauteur}.
func cases_modifiees() -> Dictionary:
	var out := {}
	var w := rect.size.x
	for i in cur.size():
		if not is_nan(cur[i]) and cur[i] != h0[i]:
			out[rect.position + Vector2i(i % w, i / w)] = cur[i]
	return out


# --- Sauvegarde ------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var hs := []
	for h in h0:
		hs.append(-99999 if is_nan(h) else roundi(h * 2.0))
	return {"x": rect.position.x, "z": rect.position.y, "w": rect.size.x, "d": rect.size.y, "s": signe,
		"g": gradin, "r": risberme, "p": profondeur, "dep": depart, "vol": snappedf(vol, 0.01), "h0": hs}


static func from_dict(d: Dictionary) -> Fosse:
	var f := Fosse.new()
	f.rect = Rect2i(int(d.get("x", 0)), int(d.get("z", 0)), int(d.get("w", 1)), int(d.get("d", 1)))
	f.signe = int(d.get("s", -1))
	f.gradin = float(d.get("g", 6.0))
	f.risberme = int(d.get("r", 4))
	f.profondeur = float(d.get("p", 40.0))
	f.depart = int(d.get("dep", 0))
	var hs: Array = d.get("h0", [])
	f.h0.resize(f.rect.size.x * f.rect.size.y)
	for i in f.h0.size():
		var v := int(hs[i]) if i < hs.size() else -99999
		f.h0[i] = NAN if v == -99999 else v * 0.5
	f.vol = float(d.get("vol", 0.0))
	f._init_geometrie()
	return f
