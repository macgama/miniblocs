class_name BanqueModeles
extends RefCounted
## Banque de modèles : les bâtiments personnalisés (façade d'un bâtiment du
## catalogue) et les bâtiments en murs fins (murs, pièces, meubles, toit),
## rangés avec des étiquettes (type, style, région, époque, couleurs, étages,
## pièces) pour être retrouvés, reposés, échangés.
##
## Un modèle = un dossier user://modeles/<id>/ avec modele.json et apercu.png :
## c'est la forme d'un objet du Steam Workshop (un dossier de contenu et une
## image d'aperçu), prête pour le partage entre joueurs. En attendant, un
## modèle s'exporte en un seul fichier .json (aperçu compris) dans
## user://partage/, et tout fichier qu'on y dépose s'importe.

const ROOT := "user://modeles"
const SHARE := "user://partage"
const FORMAT := "miniblocs-modele"
const VERSION := 1

## Faux en test : rien n'est écrit sur le disque.
static var persist := true
static var _items: Dictionary = {}
static var _loaded := false


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_items.clear()
	if not persist:
		return
	var dir := DirAccess.open(ROOT)
	if dir == null:
		return
	for sub in dir.get_directories():
		var data := _read_json("%s/%s/modele.json" % [ROOT, sub])
		if _valid(data):
			_items[String(data.id)] = data


static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var v = JSON.parse_string(f.get_as_text())
	return v if v is Dictionary else {}


static func _valid(d: Dictionary) -> bool:
	return String(d.get("format", "")) == FORMAT and String(d.get("id", "")) != "" and String(d.get("genre", "")) in ["facade", "plan"]


static func ids() -> Array:
	ensure_loaded()
	var out := _items.keys()
	out.sort_custom(func(a, b) -> bool: return float(_items[a].get("cree", 0.0)) > float(_items[b].get("cree", 0.0)))
	return out


static func get_model(id: String) -> Dictionary:
	ensure_loaded()
	return _items.get(id, {})


static func count() -> int:
	ensure_loaded()
	return _items.size()


static func _new_id(nom: String) -> String:
	var slug := nom.to_lower().strip_edges().validate_filename().replace(" ", "_").left(24)
	if slug == "":
		slug = "modele"
	return "%s_%d_%d" % [slug, int(Time.get_unix_time_from_system()), randi() % 10000]


static func _store(data: Dictionary, preview: Image) -> void:
	_items[String(data.id)] = data
	if not persist:
		return
	var dir := "%s/%s" % [ROOT, data.id]
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(dir + "/modele.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data, "\t", true))
	if preview != null and not preview.is_empty():
		preview.save_png(dir + "/apercu.png")


## Aperçu : le centre de l'écran, réduit (ce que le joueur regarde).
static func screenshot(vp: Viewport) -> Image:
	if vp == null or DisplayServer.get_name() == "headless":
		return null
	var img := vp.get_texture().get_image()
	if img == null or img.is_empty():
		return null
	var s := mini(img.get_width(), img.get_height())
	var crop := img.get_region(Rect2i((img.get_width() - s) / 2, (img.get_height() - s) / 2, s, s))
	crop.resize(256, 256, Image.INTERPOLATE_LANCZOS)
	return crop


static func preview_of(id: String) -> Texture2D:
	var path := "%s/%s/apercu.png" % [ROOT, id]
	if not persist or not FileAccess.file_exists(path):
		return null
	var img := Image.load_from_file(path)
	return ImageTexture.create_from_image(img) if img != null else null


# --- Enregistrer ----------------------------------------------------------------------------

## Bâtiment du catalogue posé, avec sa personnalisation.
static func save_building(bs: BuildingSystem, bid: int, nom: String, vp: Viewport = null) -> Dictionary:
	ensure_loaded()
	if not bs.buildings.has(bid):
		return {"ok": false, "error": "Bâtiment introuvable."}
	var b: Dictionary = bs.buildings[bid]
	var tid := String(b.t)
	var t := BuildingCatalog.get_type(tid)
	var perso: Dictionary = b.get("perso", {})
	var v := int(b.get("v", 0))
	var nm := nom.strip_edges() if nom.strip_edges() != "" else String(t.get("name", tid))
	var cols := []
	for key in ["mur", "toit_c"]:
		if not key in Personnalisation.color_keys(tid):
			continue
		var c := Personnalisation.color_name(Personnalisation.color_of(tid, v, perso, key))
		if not c in cols:
			cols.append(c)
	var etages := int(perso.get("etages", Personnalisation.base_floors(tid)))
	var data := {
		"format": FORMAT, "version": VERSION, "id": _new_id(nm), "nom": nm, "auteur": _author(),
		"cree": Time.get_unix_time_from_system(), "genre": "facade",
		"type": tid, "perso": Personnalisation.clean(perso), "v": v,
		"etiquettes": {"type": String(t.get("arch", t.get("role", t.get("cat", "")))), "categorie": String(t.get("cat", "")),
			"style": String(t.get("style", "")), "region": String(t.get("region", "")), "epoque": String(t.get("era", "")),
			"couleurs": cols, "etages": etages, "pieces": 0, "taille": "%d × %d m" % [int(t.get("w", 0)), int(t.get("d", 0))]},
	}
	_store(data, screenshot(vp))
	return {"ok": true, "id": data.id, "nom": nm}


## Bâtiment en murs fins (murs, sols, escaliers, meubles, pièces, toit en blocs).
static func save_plan(mob: Mobilier, plan_id: String, nom: String, vp: Viewport = null) -> Dictionary:
	ensure_loaded()
	var pe := mob.pe
	if pe == null or not pe.plans.has(plan_id):
		return {"ok": false, "error": "Bâtiment en murs fins introuvable."}
	var p: Dictionary = pe.plans[plan_id]
	var bbox: Rect2i = pe._bbox.get(plan_id, Rect2i())
	var o := bbox.position
	var y0 := float(p.y0)
	var walls := []
	for k in p.walls:
		var kw: Vector4i = k
		var w: Dictionary = p.walls[k]
		walls.append_array([kw.x - o.x, kw.y, kw.z - o.y, kw.w, int(w.a), int(w.b), String(w.o), int(w.om), 1 if w.op else 0])
	var floors := []
	for k in p.floors:
		var kf: Vector3i = k
		floors.append_array([kf.x - o.x, kf.y, kf.z - o.y, int(p.floors[k].t), int(p.floors[k].u)])
	var stairs := []
	for k in p.stairs:
		var ks: Vector3i = k
		stairs.append_array([ks.x - o.x, ks.y, ks.z - o.y, int(p.stairs[k].r), int(p.stairs[k].m)])
	var meubles := []
	for key in mob.items.get(plan_id, {}):
		var km: Vector4i = key
		var it: Dictionary = mob.items[plan_id][km]
		meubles.append_array([km.x - o.x, km.y, km.z - o.y, km.w, String(it.m), int(it.r)])
	var pieces := []
	for key in mob.room_fns.get(plan_id, {}):
		var kp: Vector3i = key
		pieces.append_array([kp.x - o.x, kp.y, kp.z - o.y, String(mob.room_fns[plan_id][kp])])
	# Toit et ajouts en blocs au-dessus de l'emprise (débords compris).
	var blocs := []
	var area := bbox.grow(2)
	var by := floori(y0)
	if pe.blocks != null:
		for k in pe.blocks.blocks:
			var kb: Vector3i = k
			if area.has_point(Vector2i(kb.x, kb.z)) and kb.y >= by:
				blocs.append_array([kb.x - o.x, kb.y - by, kb.z - o.y, int(pe.blocks.blocks[k])])
	var st := mob.stats(plan_id)
	var levels := pe.levels_of(plan_id)
	var style := String(mob.styles.get(plan_id, mob.style))
	var sty := Meubles.style_of(style)
	var nm := nom.strip_edges() if nom.strip_edges() != "" else mob.plan_name(plan_id)
	var data := {
		"format": FORMAT, "version": VERSION, "id": _new_id(nm), "nom": nm, "auteur": _author(),
		"cree": Time.get_unix_time_from_system(), "genre": "plan",
		"w": bbox.size.x, "d": bbox.size.y, "dy": y0 - by,
		"walls": walls, "floors": floors, "stairs": stairs, "blocs": blocs,
		"usage": mob.usage_of(plan_id), "style_meubles": style, "meubles": meubles, "pieces": pieces,
		"etiquettes": {"type": mob.usage_of(plan_id), "categorie": "murs_fins", "style": style,
			"region": String(sty.get("region", "")), "epoque": String(sty.get("era", "")),
			"couleurs": _plan_colors(p), "etages": levels.size(), "pieces": (mob.rooms_count(plan_id)),
			"taille": "%d × %d m" % [bbox.size.x, bbox.size.y], "meubles": meubles.size() / 6,
			"confort": int(st.get("conf", 0))},
	}
	_store(data, screenshot(vp))
	return {"ok": true, "id": data.id, "nom": nm}


static func _plan_colors(p: Dictionary) -> Array:
	var count := {}
	for k in p.walls:
		var w: Dictionary = p.walls[k]
		for side in ["a", "b"]:
			var m := BlocFormes.mat_of(int(w[side]))
			if m >= 0 and m < BlocMateriaux.LIST.size():
				var n := Personnalisation.color_name(Color(String(BlocMateriaux.LIST[m].c1)))
				count[n] = int(count.get(n, 0)) + 1
	var names := count.keys()
	names.sort_custom(func(a, b) -> bool: return int(count[a]) > int(count[b]))
	return names.slice(0, 2)


static func _author() -> String:
	var n := OS.get_environment("USERNAME")
	if n == "":
		n = OS.get_environment("USER")
	return n if n != "" else "moi"


static func remove(id: String) -> void:
	ensure_loaded()
	_items.erase(id)
	if not persist:
		return
	var dir := "%s/%s" % [ROOT, id]
	for f in ["modele.json", "apercu.png"]:
		if FileAccess.file_exists(dir + "/" + f):
			DirAccess.remove_absolute(dir + "/" + f)
	DirAccess.remove_absolute(dir)


static func rename(id: String, nom: String) -> void:
	ensure_loaded()
	if _items.has(id) and nom.strip_edges() != "":
		var d: Dictionary = _items[id]
		d["nom"] = nom.strip_edges()
		_store(d, null)


# --- Chercher ---------------------------------------------------------------------------------

## Modèles qui passent les filtres (texte libre, type, style, époque, couleur).
static func filtered(text := "", type := "", style := "", era := "", color := "") -> Array:
	var out := []
	var needle := text.to_lower().strip_edges()
	for id in ids():
		var d: Dictionary = _items[id]
		var e: Dictionary = d.get("etiquettes", {})
		if type != "" and String(e.get("type", "")) != type:
			continue
		if style != "" and String(e.get("style", "")) != style:
			continue
		if era != "" and String(e.get("epoque", "")) != era:
			continue
		if color != "" and not color in (e.get("couleurs", []) as Array):
			continue
		if needle != "" and not describe(d).to_lower().contains(needle) and not String(d.nom).to_lower().contains(needle):
			continue
		out.append(id)
	return out


## Valeurs présentes d'une étiquette (pour remplir les filtres).
static func tag_values(tag: String) -> Array:
	var seen := {}
	for id in ids():
		var e: Dictionary = _items[id].get("etiquettes", {})
		var v = e.get(tag, "")
		if v is Array:
			for x in v:
				seen[String(x)] = true
		elif String(v) != "":
			seen[String(v)] = true
	var out := seen.keys()
	out.sort()
	return out


static func type_name(t: String) -> String:
	if Styles.ARCHETYPES.has(t):
		return String(Styles.ARCHETYPES[t].name)
	if Mobilier.USAGES.has(t):
		return String(Mobilier.USAGES[t].name)
	return t.capitalize()


static func style_name(s: String) -> String:
	if Styles.STYLES.has(s):
		return String(Styles.STYLES[s].name)
	if Meubles.STYLES.has(s):
		return String(Meubles.STYLES[s].name)
	return s


## Ligne d'étiquettes lisible.
static func describe(d: Dictionary) -> String:
	var e: Dictionary = d.get("etiquettes", {})
	var parts := [type_name(String(e.get("type", ""))), style_name(String(e.get("style", "")))]
	if String(e.get("epoque", "")) != "":
		parts.append(Styles.era_name(String(e.epoque)).to_lower())
	parts.append("%d étage%s" % [int(e.get("etages", 1)), "s" if int(e.get("etages", 1)) > 1 else ""])
	if int(e.get("pieces", 0)) > 0:
		parts.append("%d pièces" % int(e.pieces))
	if (e.get("couleurs", []) as Array).size() > 0:
		parts.append(", ".join(e.couleurs))
	parts.append(String(e.get("taille", "")))
	return " · ".join(parts.filter(func(x) -> bool: return String(x) != ""))


# --- Poser ----------------------------------------------------------------------------------

## Pose un modèle. Façade : centré sur c, tourné de r. Murs fins : coin −x −z
## en c (sans rotation). Rend {ok, error, bid | plan}.
static func place(id: String, c: Vector2i, r: int, bs: BuildingSystem, mob: Mobilier) -> Dictionary:
	var d := get_model(id)
	if d.is_empty():
		return {"ok": false, "error": "modèle introuvable"}
	if String(d.genre) == "facade":
		var tid := String(d.type)
		if BuildingCatalog.get_type(tid).is_empty():
			return {"ok": false, "error": "ce modèle vient d'une version du jeu qui n'a pas ce bâtiment"}
		var bid := bs.place(tid, c, r)
		if bid < 0:
			return {"ok": false, "error": "pas de place ici"}
		bs.set_perso(bid, Personnalisation.clean(d.get("perso", {})), int(d.get("v", 0)))
		return {"ok": true, "bid": bid}
	return _place_plan(d, c, mob)


static func _place_plan(d: Dictionary, o: Vector2i, mob: Mobilier) -> Dictionary:
	var pe := mob.pe
	var w := int(d.get("w", 1))
	var dd := int(d.get("d", 1))
	var y0 := -INF
	for x in w:
		for z in dd:
			var c := o + Vector2i(x, z)
			var why := pe.check_cell(c, "")
			if why != "":
				return {"ok": false, "error": why.trim_suffix(".").to_lower()}
			y0 = maxf(y0, pe.ground_level(c))
	var id := pe.new_plan(y0)
	var p: Dictionary = pe.plans[id]
	var wa: Array = d.get("walls", [])
	var i := 0
	while i + 8 < wa.size():
		var kind := String(wa[i + 6])
		p.walls[Vector4i(int(wa[i]) + o.x, int(wa[i + 1]), int(wa[i + 2]) + o.y, int(wa[i + 3]))] = {
			"a": int(wa[i + 4]), "b": int(wa[i + 5]), "o": kind if PlanEditor.OPENINGS.has(kind) else "", "om": int(wa[i + 7]), "op": int(wa[i + 8]) == 1}
		i += 9
	var fa: Array = d.get("floors", [])
	i = 0
	while i + 4 < fa.size():
		p.floors[Vector3i(int(fa[i]) + o.x, int(fa[i + 1]), int(fa[i + 2]) + o.y)] = {"t": int(fa[i + 3]), "u": int(fa[i + 4])}
		i += 5
	var sa: Array = d.get("stairs", [])
	i = 0
	while i + 4 < sa.size():
		p.stairs[Vector3i(int(sa[i]) + o.x, int(sa[i + 1]), int(sa[i + 2]) + o.y)] = {"r": int(sa[i + 3]), "m": int(sa[i + 4])}
		i += 5
	pe._after_change(id)
	# Toit et ajouts en blocs.
	if pe.blocks != null:
		var ba: Array = d.get("blocs", [])
		var by := floori(y0)
		i = 0
		while i + 3 < ba.size():
			var k := Vector3i(int(ba[i]) + o.x, int(ba[i + 1]) + by, int(ba[i + 2]) + o.y)
			if not pe.blocks.blocks.has(k):
				pe.blocks._put_block(k, int(ba[i + 3]))
			i += 4
		pe.blocks.changed.emit()
	pe.flush()
	# Meubles, fonctions des pièces, usage, style.
	mob.set_usage(id, String(d.get("usage", "logement")))
	if Meubles.STYLES.has(String(d.get("style_meubles", ""))):
		mob.styles[id] = String(d.style_meubles)
	var ma: Array = d.get("meubles", [])
	i = 0
	while i + 5 < ma.size():
		var m := String(ma[i + 4])
		if Meubles.has(m):
			mob._put(id, int(ma[i + 1]), Vector2i(int(ma[i]) + o.x, int(ma[i + 2]) + o.y), int(ma[i + 5]), m)
			mob._mark(id, int(ma[i + 1]))
		i += 6
	var pa: Array = d.get("pieces", [])
	var fns := {}
	i = 0
	while i + 3 < pa.size():
		fns[Vector3i(int(pa[i]) + o.x, int(pa[i + 1]), int(pa[i + 2]) + o.y)] = String(pa[i + 3])
		i += 4
	mob.room_fns[id] = fns
	mob.set_name_of(id, String(d.get("nom", "")))
	mob.flush()
	return {"ok": true, "plan": id}


# --- Échanger ------------------------------------------------------------------------------

## Exporte un modèle en un fichier (aperçu compris) dans user://partage.
static func export_model(id: String) -> String:
	var d := get_model(id).duplicate(true)
	if d.is_empty():
		return ""
	var png := "%s/%s/apercu.png" % [ROOT, id]
	if persist and FileAccess.file_exists(png):
		d["apercu_png"] = Marshalls.raw_to_base64(FileAccess.get_file_as_bytes(png))
	DirAccess.make_dir_recursive_absolute(SHARE)
	var path := "%s/%s.json" % [SHARE, id]
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(JSON.stringify(d, "\t", true))
	return path


## Importe un modèle depuis un fichier exporté. Rend son id, ou "".
static func import_file(path: String) -> String:
	ensure_loaded()
	var d := _read_json(path)
	return import_data(d)


static func import_data(d: Dictionary) -> String:
	ensure_loaded()
	if not _valid(d) or int(d.get("version", 0)) > VERSION:
		return ""
	var img: Image = null
	if d.has("apercu_png"):
		img = Image.new()
		if img.load_png_from_buffer(Marshalls.base64_to_raw(String(d.apercu_png))) != OK:
			img = null
		d.erase("apercu_png")
	if _items.has(String(d.id)):
		return String(d.id)
	_store(d, img)
	return String(d.id)


## Importe tous les fichiers .json de user://partage pas encore connus.
static func import_shared() -> int:
	ensure_loaded()
	var dir := DirAccess.open(SHARE)
	if dir == null:
		return 0
	var n := 0
	for f in dir.get_files():
		if f.ends_with(".json"):
			var d := _read_json("%s/%s" % [SHARE, f])
			if _valid(d) and not _items.has(String(d.id)):
				if import_data(d) != "":
					n += 1
	return n


static func share_folder() -> String:
	DirAccess.make_dir_recursive_absolute(SHARE)
	return ProjectSettings.globalize_path(SHARE)
