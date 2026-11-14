class_name ModelesVisites
extends Node
## Les modèles de l'atelier posés comme bâtiments restent visitables : une fois
## le chantier fini, les vrais murs, planchers, escaliers, toit en blocs, pièces
## et meubles du modèle sont posés à la place de son volume, tournés comme le
## bâtiment. Le bâtiment du catalogue garde le rôle de jeu (fonction, habitants,
## emplois, réseau) ; les murs fins ne comptent pas une deuxième fois.
## Démoli, le bâtiment emporte ses murs, ses meubles et son toit.

var bs: BuildingSystem
var mob: Mobilier
## bid -> {"plan": id des murs fins, "bk": [x, y, z, …] blocs du toit posés}
var links: Dictionary = {}
var _timer := 0.0


func _process(delta: float) -> void:
	_timer += delta
	if _timer < 0.5:
		return
	_timer = 0.0
	sync()


func sync() -> void:
	if bs == null or mob == null or mob.pe == null:
		return
	for bid in links.keys():
		if not bs.buildings.has(bid) or not ModelesJeu.is_model(String(bs.buildings[bid].t)):
			_remove(int(bid))
	for bid in bs.buildings:
		var b: Dictionary = bs.buildings[bid]
		if not ModelesJeu.is_model(String(b.t)) or bs.en_chantier(int(bid)):
			continue
		if not links.has(bid):
			_build(int(bid))
		var link: Dictionary = links.get(bid, {})
		var n := bs.node_of(int(bid))
		if n != null:
			# Le volume cuit ne se voit que si les murs fins n'ont pas pu être posés.
			var show := link.is_empty() or not mob.pe.plans.has(String(link.plan))
			if n.visible != show:
				n.visible = show


## Murs fins posés pour ce bâtiment ("" : aucun).
func plan_of(bid: int) -> String:
	return String(links.get(bid, {}).get("plan", ""))


func _build(bid: int) -> void:
	var b: Dictionary = bs.buildings[bid]
	if absf(float(b.get("a", 0.0))) > 0.001:
		links[bid] = {"plan": "", "bk": []}
		return
	var mid := String(b.t).substr(ModelesJeu.PREFIX.length())
	var d := ModelesJeu.model_data(mid)
	if d.is_empty():
		links[bid] = {"plan": "", "bk": []}
		return
	var rect: Rect2i = bs._rect_of(b)
	var res := ModelesJeu.place_rotated(d, rect, int(b.r) % 4, float(b.h), mob, bid)
	links[bid] = {"plan": String(res.get("plan", "")), "bk": res.get("bk", [])}


func _remove(bid: int) -> void:
	var link: Dictionary = links.get(bid, {})
	links.erase(bid)
	var id := String(link.get("plan", ""))
	var pe := mob.pe
	if id != "":
		mob.linked.erase(id)
		mob._drop_plan(id)
		mob.room_fns.erase(id)
		mob.usages.erase(id)
		mob.styles.erase(id)
		mob.names.erase(id)
		if pe.plans.has(id):
			var p: Dictionary = pe.plans[id]
			p.walls.clear()
			p.floors.clear()
			p.stairs.clear()
			pe._drop_if_empty(id)
			pe._rebuild_cells()
			pe.changed.emit()
	var bk: Array = link.get("bk", [])
	if pe.blocks != null and not bk.is_empty():
		var i := 0
		while i + 2 < bk.size():
			var k := Vector3i(int(bk[i]), int(bk[i + 1]), int(bk[i + 2]))
			if pe.blocks.blocks.has(k):
				pe.blocks._drop_block(k)
			i += 3
		pe.blocks.changed.emit()
	if bs.buildings.has(bid) and bs.node_of(bid) != null:
		bs.node_of(bid).visible = true


# --- Sauvegarde ---------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var out := {}
	for bid in links:
		out[str(bid)] = links[bid]
	return {"version": 1, "links": out}


## Après les bâtiments, les murs fins, les blocs et les meubles, avant les habitants.
func from_dict(data: Dictionary) -> void:
	links.clear()
	mob.linked.clear()
	var src: Dictionary = data.get("links", {})
	for k in src:
		var l: Dictionary = src[k]
		var bid := int(k)
		links[bid] = {"plan": String(l.get("plan", "")), "bk": (l.get("bk", []) as Array).map(func(v: Variant) -> int: return int(v))}
		if String(links[bid].plan) != "":
			mob.linked[String(links[bid].plan)] = bid
