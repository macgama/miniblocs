class_name ParcDeco
extends RefCounted
## Habillage « fête foraine » du parc de loisirs : chaque attraction est posée
## sur un socle bordé de couleurs, avec réverbères à lanterne, guirlandes de
## fanions et massifs de fleurs ; ampoules colorées le long des bordures et
## des auvents (maillage à part, toujours vif, qui brille la nuit). Les allées
## reçoivent réverbères, fanions, bancs et massifs (ParcVisuels).
##
## Repère local d'un bâtiment du parc : centré sur (0, 0), entrée vers −Z.

const BLANC := Color("fff8ec")
const VERT_F := Color("2d6a4f")
const NOIR_F := Color("2b2d42")
const TERRE := Color("7f5539")
const FEUILLE := Color("52b788")
const FEUILLE_F := Color("40916c")
const FLEURS := [Color("ff5d8f"), Color("ffd166"), Color("f8f4ea"), Color("c77dff"), Color("ff7b00"), Color("ef476f")]
const AMPOULES := [Color("ffe066"), Color("ff5d8f"), Color("72efdd"), Color("ffb703"), Color("c77dff"), Color("fff3b0")]
## Couleur de bordure de chaque attraction (sinon une couleur vive tirée du nom).
const THEMES := {
	"carrousel_parc": Color("d62828"), "tasses_parc": Color("277da1"), "autos_tamponneuses": Color("ffc93c"),
	"grande_roue_parc": Color("277da1"), "chaises_volantes": Color("7b2cbf"), "bateau_pirate": Color("9c6644"),
	"train_fantome": Color("7b2cbf"), "tour_chute": Color("d62828"), "montagnes_russes": Color("f77f00"),
}

static var _mat: StandardMaterial3D


## Matériau des ampoules et lanternes : sans ombrage (toujours vives), plus
## lumineux la nuit pour que le halo (glow) les fasse briller.
static func materiau() -> StandardMaterial3D:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat.vertex_color_use_as_albedo = true
		_mat.vertex_color_is_srgb = true
	return _mat


## Règle l'éclat des ampoules (0 le jour, 1 la nuit).
static func regler_nuit(nuit: float) -> void:
	var f := 1.0 + 0.15 * clampf(nuit, 0.0, 1.0)
	materiau().albedo_color = Color(f, f, f)


static func theme(id: String) -> Color:
	if THEMES.has(id):
		return THEMES[id]
	return ParcTypes.VIFS[absi(hash(id)) % ParcTypes.VIFS.size()]


static func _role(t: Dictionary) -> String:
	return String((t.get("parc", {}) as Dictionary).get("role", ""))


# --- Petits éléments ----------------------------------------------------------------------------------------

## Réverbère de parc : mât vert foncé, lanterne (verre dans `kl`), chapeau.
static func reverbere(k: BlocMesh, kl: BlocMesh, x: float, y: float, z: float, h := 3.4) -> void:
	k.box(x, y, z, 0.34, 0.3, 0.34, VERT_F)
	k.cylinder(x, y + 0.3, z, 0.08, 0.06, h - 0.3, 6, VERT_F)
	k.box(x, y + h, z, 0.42, 0.06, 0.42, VERT_F)
	if kl != null:
		kl.box(x, y + h + 0.06, z, 0.32, 0.42, 0.32, Color("ffe8a3"))
	k.pyramid(x, y + h + 0.48, z, 0.5, 0.5, 0.3, VERT_F)
	k.box(x, y + h + 0.78, z, 0.08, 0.14, 0.08, Color("d4a373"))


## Guirlande de fanions triangulaires entre deux points (avec un peu de mou).
static func fanions(k: BlocMesh, a: Vector3, b: Vector3, mou := 0.6, graine := 0) -> void:
	var long := a.distance_to(b)
	var n := maxi(2, int(long / 0.75))
	var dir := (b - a).normalized()
	var cote := Vector3(-dir.z, 0, dir.x)
	var prev := a
	for i in range(1, n + 1):
		var u := float(i) / n
		var p := a.lerp(b, u) + Vector3(0, -mou * 4.0 * u * (1.0 - u), 0)
		ParcTypes.beam(k, prev, p, 0.03, Color("eeeeee"))
		if i < n:
			var c: Color = ParcTypes.VIFS[(i + graine) % ParcTypes.VIFS.size()]
			var g := p - dir * 0.22
			var d := p + dir * 0.22
			var bas := p + Vector3(0, -0.5, 0)
			k.tri(g, d, bas, cote, c)
			k.tri(d, g, bas, -cote, c.darkened(0.12))
		prev = p


## Guirlande d'ampoules (dans `kl`) entre deux points.
static func ampoules(kl: BlocMesh, a: Vector3, b: Vector3, pas := 1.1, mou := 0.0, graine := 0) -> void:
	var n := maxi(1, int(a.distance_to(b) / pas))
	for i in n + 1:
		var u := float(i) / n
		var p := a.lerp(b, u) + Vector3(0, -mou * 4.0 * u * (1.0 - u), 0)
		kl.box(p.x, p.y - 0.09, p.z, 0.16, 0.18, 0.16, AMPOULES[(i + graine) % AMPOULES.size()])


## Massif de fleurs rond : bordure, terre, touffes et fleurs de couleur.
static func massif(k: BlocMesh, x: float, y: float, z: float, r := 1.0, graine := 0) -> void:
	k.cylinder(x, y, z, r + 0.12, r + 0.12, 0.28, 10, Color("d9d4c7"))
	k.cylinder(x, y + 0.28, z, r, r, 0.04, 10, TERRE)
	var n := 3 + int(r * 3.0)
	for i in n:
		var a := TAU * float(i) / n + float(graine)
		var rr := r * (0.35 if i % 2 == 0 else 0.68)
		var px := x + cos(a) * rr
		var pz := z + sin(a) * rr
		k.dome(px, y + 0.3, pz, 0.32, 0.32, FEUILLE if i % 2 == 0 else FEUILLE_F, 6)
		k.box(px, y + 0.56, pz, 0.16, 0.12, 0.16, FLEURS[(i + graine) % FLEURS.size()])
	k.dome(x, y + 0.3, z, 0.4, 0.55, FEUILLE_F, 6)
	k.box(x, y + 0.82, z, 0.2, 0.14, 0.2, FLEURS[(graine + 2) % FLEURS.size()])


## Buisson taillé en boule.
static func buisson(k: BlocMesh, x: float, y: float, z: float, s := 1.0) -> void:
	k.dome(x, y, z, 0.6 * s, 0.9 * s, FEUILLE_F, 7)
	k.dome(x + 0.25 * s, y + 0.3 * s, z - 0.1 * s, 0.35 * s, 0.5 * s, FEUILLE, 6)


## Banc de parc (dossier côté +Z si `le_long_x`, sinon côté +X).
static func banc(k: BlocMesh, x: float, y: float, z: float, le_long_x := true) -> void:
	var bois := Color("c68b59")
	if le_long_x:
		k.box(x, y + 0.42, z, 1.6, 0.08, 0.5, bois)
		k.box(x, y + 0.55, z + 0.24, 1.6, 0.4, 0.07, bois)
		for s in [-0.7, 0.7]:
			k.box(x + s, y, z, 0.08, 0.42, 0.45, NOIR_F)
	else:
		k.box(x, y + 0.42, z, 0.5, 0.08, 1.6, bois)
		k.box(x + 0.24, y + 0.55, z, 0.07, 0.4, 1.6, bois)
		for s in [-0.7, 0.7]:
			k.box(x, y, z + s, 0.45, 0.42, 0.08, NOIR_F)


# --- Habillage des modèles -------------------------------------------------------------------------------

## Socle, réverbères, fanions et massifs autour d'un objet du parc. `kl` reçoit
## les lumières (null : on ne dessine que la partie fixe).
static func habiller(k: BlocMesh, kl: BlocMesh, id: String, t: Dictionary) -> void:
	if t.has("voie_famille") or ModelesJeu.is_model(id):
		return
	var role := _role(t)
	var w := float(t.get("w", 10))
	var d := float(t.get("d", 10))
	var hx := w / 2.0
	var hz := d / 2.0
	match role:
		"attraction":
			_socle(k, kl, id, hx, hz)
			var i := 0.65
			var lampes := [Vector2(-hx + i, -hz + i), Vector2(hx - i, -hz + i), Vector2(hx - i, hz - i), Vector2(-hx + i, hz - i)]
			for p in lampes:
				reverbere(k, kl, p.x, 0.0, p.y)
			# Fanions devant et derrière, d'une lanterne à l'autre.
			var hf := 3.25
			fanions(k, Vector3(-hx + i, hf, -hz + i), Vector3(hx - i, hf, -hz + i), 0.7, absi(hash(id)))
			fanions(k, Vector3(-hx + i, hf, hz - i), Vector3(hx - i, hf, hz - i), 0.7, absi(hash(id)) + 3)
			# Massifs dans les coins du fond et buissons sur les côtés.
			massif(k, -hx + 2.0, 0.0, hz - 1.6, 0.8, 1)
			massif(k, hx - 2.0, 0.0, hz - 1.6, 0.8, 4)
			for s in [-1.0, 1.0]:
				buisson(k, s * (hx - 0.7), 0.0, 0.0, 0.8)
		"stand":
			var i := 0.45
			reverbere(k, kl, -hx + i, 0.0, -hz + i, 2.8)
			massif(k, hx - 0.9, 0.0, -hz + 0.9, 0.55, absi(hash(id)))
			buisson(k, -hx + 0.6, 0.0, hz - 0.6, 0.7)
			buisson(k, hx - 0.6, 0.0, hz - 0.6, 0.7)
		"toilettes", "repos", "atelier":
			massif(k, -hx + 1.0, 0.0, -hz + 1.0, 0.6, 2)
			buisson(k, hx - 0.7, 0.0, -hz + 0.7, 0.7)
			reverbere(k, kl, hx - 0.5, 0.0, hz - 0.5, 3.0)
		"entree":
			# Guirlande de fanions et ampoules sur l'arche, massifs devant les tours.
			fanions(k, Vector3(-11.5, 8.9, -2.2), Vector3(11.5, 8.9, -2.2), 0.9, 2)
			if kl != null:
				ampoules(kl, Vector3(-9.5, 8.95, -0.66), Vector3(9.5, 8.95, -0.66), 0.8, 0.0, 1)
				ampoules(kl, Vector3(-9.5, 6.9, -0.66), Vector3(9.5, 6.9, -0.66), 0.8, 0.0, 4)
				for s in [-1.0, 1.0]:
					ampoules(kl, Vector3(11.5 * s - 2.1, 9.55, -2.25), Vector3(11.5 * s + 2.1, 9.55, -2.25), 0.6, 0.0, 2)
			for s in [-1.0, 1.0]:
				massif(k, 11.5 * s, 0.0, -4.4, 1.3, 3 if s < 0 else 0)
				reverbere(k, kl, 14.5 * s, 0.0, -2.0)
	if kl != null and role == "stand":
		_ampoules_stand(kl, id, hx, hz)


## Bordure du socle : petits blocs de la couleur de l'attraction et blancs,
## ampoules dessus (sauf devant le guichet, à gauche de l'entrée).
static func _socle(k: BlocMesh, kl: BlocMesh, id: String, hx: float, hz: float) -> void:
	var c := theme(id)
	var e := 0.32
	var cotes := [[Vector2(-hx, -hz), Vector2(hx, -hz)], [Vector2(hx, -hz), Vector2(hx, hz)],
			[Vector2(hx, hz), Vector2(-hx, hz)], [Vector2(-hx, hz), Vector2(-hx, -hz)]]
	var j := 0
	for cote in cotes:
		var a: Vector2 = cote[0]
		var b: Vector2 = cote[1]
		var n := maxi(2, int(a.distance_to(b) / 1.2))
		var dir := (b - a).normalized()
		var dedans := Vector2(-dir.y, dir.x) * (e * 0.5)
		for i in n:
			var p := a.lerp(b, (float(i) + 0.5) / n) + dedans
			var l := a.distance_to(b) / n - 0.06
			var sx := absf(dir.x) * l + absf(dir.y) * e
			var sz := absf(dir.y) * l + absf(dir.x) * e
			k.box(p.x, 0.0, p.y, sx, 0.34, sz, c if (i + j) % 2 == 0 else BLANC)
			if kl != null and i % 2 == 0:
				kl.box(p.x, 0.34, p.y, 0.16, 0.16, 0.16, AMPOULES[(i + j) % AMPOULES.size()])
		j += 1


## Ampoules le long de l'auvent des stands.
static func _ampoules_stand(kl: BlocMesh, id: String, hx: float, _hz: float) -> void:
	match id:
		"friterie_parc", "buvette_parc":
			ampoules(kl, Vector3(-3.0, 2.42, -3.12), Vector3(3.0, 2.42, -3.12), 0.6, 0.12, 1)
			ampoules(kl, Vector3(-3.0, 3.12, 2.75), Vector3(3.0, 3.12, 2.75), 0.75, 0.0, 3)
		"glacier_parc":
			ampoules(kl, Vector3(-2.2, 2.42, -2.77), Vector3(2.2, 2.42, -2.77), 0.55, 0.1, 2)
		"boutique_souvenirs":
			ampoules(kl, Vector3(-5.0, 3.62, -3.62), Vector3(5.0, 3.62, -3.62), 0.7, 0.0, 0)
		_:
			ampoules(kl, Vector3(-hx + 0.6, 2.6, -1.0), Vector3(hx - 0.6, 2.6, -1.0), 0.7, 0.15, 0)


## Lumières d'un objet du parc (lanternes, ampoules), en maillage à part.
static func lumieres(id: String) -> MeshInstance3D:
	var t := BuildingCatalog.get_type(id)
	if t.is_empty() or ModelesJeu.is_model(id):
		return null
	var k := BlocMesh.new()
	var kl := BlocMesh.new()
	habiller(k, kl, id, t)
	if kl.verts.is_empty():
		return null
	var mi := MeshInstance3D.new()
	mi.name = "Lumieres"
	mi.mesh = kl.to_mesh(materiau())
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 700.0
	return mi
