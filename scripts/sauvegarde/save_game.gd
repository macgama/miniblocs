class_name SaveGame
extends RefCounted
## Sauvegarde des parties, format 2 (« miniblocs-partie »).
##
## Une partie = un dossier user://parties/<id>/ :
##   partie.json          fiche lisible : format, version, lieu, dates, auteur,
##                        résumé, et la liste des sections avec leur empreinte ;
##   <section>.json.zst   une section par système (terrain, transport, batiments,
##                        zones, blocs, ambiance), en JSON compressé (Zstandard).
##
## Principes (voir docs/sauvegarde.md) :
##  - on ne garde que ce que le joueur a changé : le relief réel, les biomes et la
##    végétation se recalculent à partir des données publiques ; le terrain ne
##    stocke que les cases modifiées, rangées par blocs de 64 × 64 m ;
##  - chaque section a sa propre version : un système peut évoluer seul, et les
##    vieilles sections sont converties au chargement (migrate_section) ;
##  - écriture sûre : fichiers temporaires puis renommage, la fiche en dernier ;
##  - prêt pour le multijoueur : identifiant unique de partie et de joueur,
##    sections indépendantes (échangeables une par une), terrain découpé par blocs
##    (on pourra n'envoyer que les blocs changés), empreinte SHA-256 par section.

const FORMAT := "miniblocs-partie"
const VERSION := 2
const DIR := "user://parties"
const MANIFEST := "partie.json"
## Ancienne sauvegarde unique (format 1), importée automatiquement.
const LEGACY_PATH := "user://terre_save.json"
const PLAYER_FILE := "user://joueur.cfg"
## Version de chaque section écrite par ce jeu.
const SECTION_VERSIONS := {"terrain": 2, "transport": 1, "batiments": 1, "zones": 1, "blocs": 1, "ambiance": 1}


# --- Identifiants ---------------------------------------------------------------

## Identifiant aléatoire de 128 bits en hexadécimal (pour les parties et les joueurs).
static func new_uuid() -> String:
	var b := Crypto.new().generate_random_bytes(16)
	return b.hex_encode()


## Identifiant du joueur sur cette machine (créé une fois, gardé dans user://joueur.cfg).
static func player_id() -> String:
	var cfg := ConfigFile.new()
	cfg.load(PLAYER_FILE)
	var id := String(cfg.get_value("joueur", "id", ""))
	if id == "":
		id = new_uuid()
		cfg.set_value("joueur", "id", id)
		cfg.save(PLAYER_FILE)
	return id


## Nom de dossier lisible et unique : « annecy-20261112-0215 ».
static func make_slot_id(title: String) -> String:
	var base := title.to_lower().strip_edges()
	var out := ""
	for ch in base:
		var c := ch.unicode_at(0)
		if (c >= 97 and c <= 122) or (c >= 48 and c <= 57):
			out += ch
		elif "àâä".contains(ch):
			out += "a"
		elif "éèêë".contains(ch):
			out += "e"
		elif "îï".contains(ch):
			out += "i"
		elif "ôö".contains(ch):
			out += "o"
		elif "ùûü".contains(ch):
			out += "u"
		elif ch == "ç":
			out += "c"
		elif not out.ends_with("-") and out != "":
			out += "-"
	out = out.trim_suffix("-").left(32)
	if out == "":
		out = "partie"
	var t := Time.get_datetime_dict_from_system()
	var id := "%s-%04d%02d%02d-%02d%02d" % [out, t.year, t.month, t.day, t.hour, t.minute]
	var n := 2
	var unique := id
	while DirAccess.dir_exists_absolute(DIR.path_join(unique)):
		unique = "%s-%d" % [id, n]
		n += 1
	return unique


# --- Écriture --------------------------------------------------------------------

## Écrit une partie. info : champs de la fiche (nom, lieu, mode, resume…).
## sections : nom -> Dictionary. Renvoie "" si tout va bien, sinon le message d'erreur.
static func write(slot_id: String, info: Dictionary, sections: Dictionary) -> String:
	var dir := DIR.path_join(slot_id)
	var err := DirAccess.make_dir_recursive_absolute(dir)
	if err != OK:
		return "Impossible de créer le dossier de sauvegarde (%s)." % error_string(err)
	var old := read_manifest(slot_id)
	var now := int(Time.get_unix_time_from_system())
	var manifest := {
		"format": FORMAT,
		"version": VERSION,
		"jeu": String(ProjectSettings.get_setting("application/config/version", "")),
		"partie_id": String(old.get("partie_id", info.get("partie_id", new_uuid()))),
		"auteur": player_id(),
		"cree": int(old.get("cree", now)),
		"modifie": now,
		"sauvegardes": int(old.get("sauvegardes", 0)) + 1,
		"sections": {},
	}
	for k in info:
		if not manifest.has(k):
			manifest[k] = info[k]
	var written: Array[String] = []
	for name in sections:
		var text := JSON.stringify(sections[name], "", true)
		var file := "%s.json.zst" % name
		var tmp := dir.path_join(file + ".tmp")
		var f := FileAccess.open_compressed(tmp, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
		if f == null:
			return "Écriture impossible : %s (%s)." % [file, error_string(FileAccess.get_open_error())]
		f.store_string(text)
		f.close()
		written.append(file)
		manifest.sections[name] = {
			"fichier": file,
			"version": int(SECTION_VERSIONS.get(name, 1)),
			"octets": text.to_utf8_buffer().size(),
			"sha256": text.sha256_text(),
		}
	# Tout est écrit : on remplace les anciens fichiers, puis la fiche.
	for file in written:
		var final := dir.path_join(file)
		if FileAccess.file_exists(final):
			DirAccess.remove_absolute(final)
		err = DirAccess.rename_absolute(final + ".tmp", final)
		if err != OK:
			return "Renommage impossible : %s (%s)." % [file, error_string(err)]
	var mf := FileAccess.open(dir.path_join(MANIFEST + ".tmp"), FileAccess.WRITE)
	if mf == null:
		return "Écriture impossible : fiche de la partie."
	mf.store_string(JSON.stringify(manifest, "\t", true))
	mf.close()
	if FileAccess.file_exists(dir.path_join(MANIFEST)):
		DirAccess.remove_absolute(dir.path_join(MANIFEST))
	err = DirAccess.rename_absolute(dir.path_join(MANIFEST + ".tmp"), dir.path_join(MANIFEST))
	if err != OK:
		return "Renommage impossible : fiche de la partie (%s)." % error_string(err)
	return ""


# --- Lecture ---------------------------------------------------------------------

static func exists(slot_id: String) -> bool:
	return FileAccess.file_exists(DIR.path_join(slot_id).path_join(MANIFEST))


static func read_manifest(slot_id: String) -> Dictionary:
	var path := DIR.path_join(slot_id).path_join(MANIFEST)
	if not FileAccess.file_exists(path):
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY or data.get("format", "") != FORMAT:
		return {}
	data["id"] = slot_id
	return data


## Lit une partie : {ok, error, manifest, sections, warnings}. Les sections sont
## converties à la version actuelle ; une section abîmée est signalée et ignorée.
static func read(slot_id: String) -> Dictionary:
	var out := {"ok": false, "error": "", "manifest": {}, "sections": {}, "warnings": []}
	var manifest := read_manifest(slot_id)
	if manifest.is_empty():
		out.error = "Partie introuvable ou illisible."
		return out
	if int(manifest.get("version", 0)) > VERSION:
		out.error = "Cette partie vient d'une version plus récente du jeu."
		return out
	out.manifest = manifest
	var dir := DIR.path_join(slot_id)
	var secs: Dictionary = manifest.get("sections", {})
	for name in secs:
		var meta: Dictionary = secs[name]
		var path := dir.path_join(String(meta.get("fichier", "")))
		var f := FileAccess.open_compressed(path, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
		if f == null:
			out.warnings.append("Section « %s » manquante." % name)
			continue
		var text := f.get_as_text()
		f.close()
		if meta.has("sha256") and text.sha256_text() != String(meta.sha256):
			out.warnings.append("Section « %s » abîmée (empreinte différente)." % name)
			continue
		var data: Variant = JSON.parse_string(text)
		if typeof(data) != TYPE_DICTIONARY:
			out.warnings.append("Section « %s » illisible." % name)
			continue
		out.sections[name] = migrate_section(name, int(meta.get("version", 1)), data)
	out.ok = out.sections.has("terrain")
	if not out.ok:
		out.error = "Le terrain de la partie est illisible."
	return out


## Convertit une section d'une ancienne version vers la version actuelle.
static func migrate_section(name: String, version: int, data: Dictionary) -> Dictionary:
	if name == "terrain" and version < 2 and data.has("modifications"):
		# Format 1 : liste [x, z, h] -> blocs de 64 × 64.
		var mods := {}
		for m in data.modifications:
			mods[Vector2i(int(m[0]), int(m[1]))] = float(m[2])
		return {"version": 2, "lat": float(data.get("lat", 0.0)), "lon": float(data.get("lon", 0.0)),
			"modifs": encode_cells(mods)}
	return data


## Toutes les parties, la plus récente d'abord (fiches avec leur "id").
static func list_saves() -> Array[Dictionary]:
	import_legacy()
	var out: Array[Dictionary] = []
	var d := DirAccess.open(DIR)
	if d == null:
		return out
	for name in d.get_directories():
		var m := read_manifest(name)
		if not m.is_empty():
			out.append(m)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("modifie", 0)) > int(b.get("modifie", 0)))
	return out


static func delete(slot_id: String) -> bool:
	var dir := DIR.path_join(slot_id)
	var d := DirAccess.open(dir)
	if d == null:
		return false
	for f in d.get_files():
		d.remove(f)
	return DirAccess.remove_absolute(dir) == OK


## Importe l'ancienne sauvegarde unique (user://terre_save.json) comme une partie,
## puis la renomme en .bak. Renvoie l'id de la partie créée, ou "".
static func import_legacy() -> String:
	if not FileAccess.file_exists(LEGACY_PATH):
		return ""
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(LEGACY_PATH))
	if typeof(data) != TYPE_DICTIONARY or not data.has("lat"):
		return ""
	var terrain := migrate_section("terrain", 1, data)
	var sections := {"terrain": terrain}
	for k in ["transport", "batiments", "zones", "blocs", "ambiance"]:
		if data.has(k) and typeof(data[k]) == TYPE_DICTIONARY:
			sections[k] = data[k]
	var mtime := FileAccess.get_modified_time(LEGACY_PATH)
	var slot := make_slot_id("ancienne sauvegarde")
	var err := write(slot, {"nom": "Ancienne sauvegarde", "lieu": {"lat": float(data.lat), "lon": float(data.lon), "nom": ""},
		"mode": "bac_a_sable", "importee_le": int(Time.get_unix_time_from_system()), "cree": mtime}, sections)
	if err != "":
		push_warning("Import de l'ancienne sauvegarde : " + err)
		return ""
	DirAccess.rename_absolute(LEGACY_PATH, LEGACY_PATH + ".bak")
	return slot


# --- Terrain : cases modifiées, rangées par blocs ----------------------------------

const CELL_BLOCK := 64


## Cases modifiées (Vector2i -> hauteur) -> {"bloc": 64, "blocs": {"bx,bz": base64}}.
## Chaque bloc : suite de (x local u8, z local u8, hauteur f32), triée.
static func encode_cells(mods: Dictionary) -> Dictionary:
	# Bloc -> {indice local (z * 64 + x) -> hauteur}.
	var by_block := {}
	for c: Vector2i in mods:
		var bx := c.x >> 6
		var bz := c.y >> 6
		var bk := Vector2i(bx, bz)
		var d: Dictionary = by_block.get(bk, {})
		if d.is_empty():
			by_block[bk] = d
		d[((c.y - (bz << 6)) << 6) | (c.x - (bx << 6))] = mods[c]
	var blocks := {}
	for bk: Vector2i in by_block:
		var d: Dictionary = by_block[bk]
		var keys := PackedInt32Array(d.keys())
		keys.sort()
		var buf := PackedByteArray()
		buf.resize(keys.size() * 6)
		var o := 0
		for k in keys:
			buf[o] = k & 63
			buf[o + 1] = k >> 6
			buf.encode_float(o + 2, float(d[k]))
			o += 6
		blocks["%d,%d" % [bk.x, bk.y]] = Marshalls.raw_to_base64(buf)
	return {"bloc": CELL_BLOCK, "blocs": blocks}


static func decode_cells(data: Dictionary) -> Dictionary:
	var out := {}
	var size := int(data.get("bloc", CELL_BLOCK))
	var blocks: Dictionary = data.get("blocs", {})
	for key in blocks:
		var p := String(key).split(",")
		if p.size() != 2:
			continue
		var bx := int(p[0]) * size
		var bz := int(p[1]) * size
		var raw := Marshalls.base64_to_raw(String(blocks[key]))
		var o := 0
		while o + 6 <= raw.size():
			out[Vector2i(bx + raw[o], bz + raw[o + 1])] = raw.decode_float(o + 2)
			o += 6
	return out
