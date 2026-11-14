class_name MuseeModeles
extends RefCounted
## Modèles low-poly des objets du musée (MuseeObjets), en code, avec le même
## kit que les meubles (LpKit : faces plates, teintes qui varient un peu).
##
## Repère : centre de l'emprise au sol, largeur w le long de x, profondeur d le
## long de z, dos vers −Z (contre le mur), avant vers +Z. Couches « base »,
## « verre » (vitrines) et « lumiere » (spots, écrans, sans ombre).
## Les objets « suspendus » (lustre, spots, baleine, avion) sont dessinés sous
## le plafond d'un étage de 3 m.

const GOLD := Color("c9a227")
const MARBLE := Color("ece6da")
const BRONZE := Color("6e4f2a")
const BONE := Color("e3d8bc")
const DARK := Color("2b2f33")
const WOOD := Color("6b4a2f")
const WOOD2 := Color("b08a5a")
const RED := Color("8e1e24")
const WHITE := Color("f3f1ec")
const GLASS := Color(0.78, 0.9, 1.0)
const STONE := Color("b8ad98")
const LIGHT := Color("fff1c8")
## Hauteur des objets suspendus (sous un plafond à 3 m).
const CEIL := 2.85


static func build(kit: LpKit, e: Dictionary) -> void:
	var w := float(e.w)
	var d := float(e.d)
	var h := float(e.h)
	var k := String(e.k)
	var c := String(e.get("c", ""))
	match k:
		# --- Vitrines ------------------------------------------------------------------------------
		"vitrine_murale":
			kit.box(Vector3(0, 0.45, -0.2), Vector3(w - 0.1, 0.9, 0.5), WOOD)
			kit.box(Vector3(0, 2.02, -0.2), Vector3(w - 0.1, 0.12, 0.52), WOOD)
			kit.box(Vector3(0, 1.45, -0.44), Vector3(w - 0.14, 1.0, 0.03), Color("d9d2c2"))
			_contenu(kit, c, Vector3(0, 0.92, -0.25), w - 0.3, 0.4, 1.0)
			kit.layer = "lumiere"
			kit.box(Vector3(0, 1.94, -0.2), Vector3(w - 0.3, 0.02, 0.3), LIGHT)
			kit.layer = "verre"
			kit.box(Vector3(0, 1.43, -0.2), Vector3(w - 0.12, 1.06, 0.48), GLASS)
			kit.layer = "base"
		"vitrine_table":
			for sx in [-1, 1]:
				for sz in [-1, 1]:
					kit.box(Vector3(sx * (w * 0.5 - 0.12), 0.35, sz * 0.32), Vector3(0.06, 0.7, 0.06), WOOD)
			kit.box(Vector3(0, 0.72, 0), Vector3(w - 0.1, 0.06, 0.8), WOOD)
			kit.box(Vector3(0, 0.76, 0), Vector3(w - 0.2, 0.02, 0.7), RED if c != "monnaies" else Color("1f3b5a"))
			_contenu(kit, c, Vector3(0, 0.77, 0), w - 0.3, 0.6, 0.2)
			kit.layer = "verre"
			kit.box(Vector3(0, 0.88, 0), Vector3(w - 0.1, 0.24, 0.8), GLASS)
			kit.layer = "base"
		"vitrine_cloche":
			kit.box(Vector3(0, 0.5, 0), Vector3(0.6, 1.0, 0.6), WHITE)
			kit.box(Vector3(0, 1.02, 0), Vector3(0.66, 0.04, 0.66), DARK)
			if c == "dodo":
				_dodo(kit, Vector3(0, 1.04, 0))
			elif MuseeModelesThemes.cloche(kit, c, Vector3(0, 1.04, 0)):
				pass
			else:
				kit.lathe(Vector3(0, 1.04, 0), [Vector2(0.1, 0.0), Vector2(0.14, 0.15), Vector2(0.06, 0.32)], 8, GOLD)
			kit.layer = "verre"
			kit.box(Vector3(0, 1.36, 0), Vector3(0.6, 0.64, 0.6), GLASS)
			kit.layer = "base"
		"vitrine_centrale":
			kit.box(Vector3(0, 0.4, 0), Vector3(w - 0.2, 0.8, d - 0.2), WOOD)
			kit.box(Vector3(0, 2.15, 0), Vector3(w - 0.15, 0.1, d - 0.15), WOOD)
			for sx in [-1, 1]:
				for sz in [-1, 1]:
					kit.box(Vector3(sx * (w * 0.5 - 0.12), 1.45, sz * (d * 0.5 - 0.12)), Vector3(0.05, 1.3, 0.05), GOLD)
			kit.layer = "verre"
			kit.box(Vector3(0, 1.45, 0), Vector3(w - 0.22, 1.3, d - 0.22), GLASS)
			kit.layer = "base"
		# --- Socles ---------------------------------------------------------------------------------
		"socle_cube":
			kit.box(Vector3(0, 0.5, 0), Vector3(0.6, 1.0, 0.6), WHITE)
		"colonne_socle":
			_colonne(kit, Vector3.ZERO, 1.1, 0.22, MARBLE)
		"estrade":
			kit.box(Vector3(0, 0.12, 0), Vector3(w - 0.1, 0.24, d - 0.1), Color("3a3d42"))
			kit.box(Vector3(0, 0.245, 0), Vector3(w - 0.2, 0.01, d - 0.2), Color("54585e"))
		"piedestal_dore":
			kit.box(Vector3(0, 0.08, 0), Vector3(0.7, 0.16, 0.7), DARK)
			kit.lathe(Vector3(0, 0.16, 0), [Vector2(0.28, 0.0), Vector2(0.18, 0.15), Vector2(0.15, 0.75), Vector2(0.3, 0.94)], 8, GOLD)
		"cimaise":
			kit.box(Vector3(0, 1.3, 0), Vector3(w - 0.1, 2.6, 0.16), WHITE)
			kit.box(Vector3(0, 0.03, 0), Vector3(w, 0.06, 0.5), DARK)
			_frame(kit, Vector3(-0.45, 1.5, 0.09), 0.6, 0.8, DARK, "abstrait", 1.0)
			_frame(kit, Vector3(0.45, 1.5, 0.09), 0.6, 0.8, DARK, "portrait", 1.0)
		"tapis_musee":
			kit.box(Vector3(0, 0.01, 0), Vector3(w - 0.2, 0.02, d - 0.2), RED, 0.0)
			kit.box(Vector3(0, 0.012, 0), Vector3(w - 0.5, 0.02, d - 0.5), RED.lightened(0.08), 0.0)
		# --- Peinture -------------------------------------------------------------------------------
		"tableau":
			var fw := w - 0.25 if w > 1.0 else 0.75
			var fh := h * 0.85
			var gold := GOLD if c in ["classique", "portrait", "nature_morte", "paysage", "histoire"] else (DARK if c in ["abstrait", "affiche", "photos", "planche", "couverture", "maillot", "plaques"] else WOOD)
			_frame(kit, Vector3(0, 1.55 if fh < 1.3 else 1.4, -0.46), fw, fh, gold, c, 1.0)
		"triptyque":
			kit.box(Vector3(0, 1.45, -0.46), Vector3(1.0, 1.4, 0.05), GOLD)
			kit.box(Vector3(0, 1.45, -0.43), Vector3(0.86, 1.26, 0.01), Color("b8862b"))
			kit.blob(Vector3(0, 1.5, -0.42), Vector3(0.18, 0.35, 0.02), Color("2a4a8a"), Color("3a5aa0"), 0.05, 0)
			kit.box(Vector3(0, 1.85, -0.42), Vector3(0.18, 0.18, 0.01), Color("f0d080"))
			for sx in [-1, 1]:
				kit.box(Vector3(sx * 0.95, 1.45, -0.42), Vector3(0.85, 1.1, 0.04), GOLD, 0.0)
				kit.box(Vector3(sx * 0.95, 1.45, -0.395), Vector3(0.72, 0.96, 0.01), Color("7a2a2a") if sx < 0 else Color("2f5a3a"))
				kit.blob(Vector3(sx * 0.95, 1.4, -0.39), Vector3(0.12, 0.3, 0.02), Color("d8c3a5"), Color("e6d4b8"), 0.05, 0)
		"fresque":
			kit.box(Vector3(0, 1.4, -0.47), Vector3(w - 0.1, 2.2, 0.02), Color("d9c3a0"), 0.0)
			var cols := [Color("a4513a"), Color("3a6a8a"), Color("c9a227"), Color("4f7a4a"), Color("8a4a6a")]
			for i in 7:
				var x := -w * 0.5 + 0.4 + i * (w - 0.8) / 6.0
				kit.blob(Vector3(x, 1.2 + (i % 2) * 0.15, -0.455), Vector3(0.14, 0.5, 0.01), cols[i % cols.size()], cols[(i + 1) % cols.size()], 0.05, 0)
				kit.box(Vector3(x, 1.85 + (i % 2) * 0.15, -0.455), Vector3(0.16, 0.16, 0.01), Color("e6c8a8"))
			kit.box(Vector3(0, 2.42, -0.45), Vector3(w - 0.1, 0.08, 0.03), Color("8a5a3a"))
		"chef_oeuvre":
			_frame(kit, Vector3(0, 1.5, -0.46), 0.55, 0.75, GOLD, "portrait", 1.0)
			kit.layer = "verre"
			kit.box(Vector3(0, 1.5, -0.32), Vector3(0.9, 1.1, 0.26), GLASS)
			kit.layer = "base"
			kit.box(Vector3(0, 0.95, -0.32), Vector3(0.95, 0.04, 0.3), DARK)
		# --- Sculpture ------------------------------------------------------------------------------
		"statue_antique":
			kit.box(Vector3(0, 0.45, 0), Vector3(0.6, 0.9, 0.6), MARBLE.darkened(0.08))
			_figure(kit, Vector3(0, 0.9, 0), 1.0, MARBLE, true)
		"buste":
			_colonne(kit, Vector3.ZERO, 1.2, 0.18, MARBLE)
			kit.blob(Vector3(0, 1.38, 0), Vector3(0.2, 0.16, 0.13), BRONZE, BRONZE.lightened(0.1), 0.1, 1)
			kit.blob(Vector3(0, 1.62, 0), Vector3(0.1, 0.13, 0.11), BRONZE, BRONZE.lightened(0.12), 0.06, 1)
		"songeur":
			kit.box(Vector3(0, 0.4, 0), Vector3(0.7, 0.8, 0.7), STONE)
			var bz := BRONZE.darkened(0.1)
			kit.box(Vector3(0, 0.95, -0.05), Vector3(0.38, 0.3, 0.36), bz)
			kit.blob(Vector3(0, 1.3, 0.02), Vector3(0.18, 0.28, 0.14), bz, bz.lightened(0.1), 0.1, 1)
			kit.beam(Vector3(0.15, 1.15, 0.05), Vector3(0.15, 1.0, 0.3), 0.09, 0.09, bz)
			kit.beam(Vector3(-0.12, 1.4, 0.05), Vector3(0.05, 1.42, 0.28), 0.08, 0.08, bz)
			kit.blob(Vector3(0.02, 1.62, 0.16), Vector3(0.1, 0.12, 0.1), bz, bz.lightened(0.12), 0.05, 1)
			for sx in [-1, 1]:
				kit.beam(Vector3(sx * 0.1, 0.95, 0.12), Vector3(sx * 0.12, 0.82, 0.32), 0.1, 0.1, bz)
				kit.beam(Vector3(sx * 0.12, 0.82, 0.32), Vector3(sx * 0.12, 0.8, 0.33), 0.1, 0.1, bz)
		"cavalier":
			kit.box(Vector3(0, 0.45, 0), Vector3(1.4, 0.9, 2.4), STONE)
			var bc := Color("3e4a3a")
			kit.blob(Vector3(0, 1.55, 0), Vector3(0.3, 0.32, 0.65), bc, bc.lightened(0.1), 0.06, 1)
			kit.beam(Vector3(0, 1.7, 0.55), Vector3(0, 2.05, 0.85), 0.2, 0.25, bc)
			kit.blob(Vector3(0, 2.05, 0.95), Vector3(0.12, 0.13, 0.22), bc, bc.lightened(0.1), 0.05, 0)
			for sz in [-0.45, 0.45]:
				for sx in [-0.17, 0.17]:
					kit.beam(Vector3(sx, 1.35, sz), Vector3(sx, 0.9, sz + (0.15 if sz > 0 and sx > 0 else 0.0)), 0.1, 0.1, bc)
			kit.beam(Vector3(0, 1.5, -0.6), Vector3(0, 1.0, -0.8), 0.06, 0.12, bc)
			_figure(kit, Vector3(0, 1.75, -0.05), 0.55, bc, false)
		"sculpture_moderne":
			kit.box(Vector3(0, 0.05, 0), Vector3(1.6, 0.1, 1.6), DARK)
			var steel := Color("b5452f")
			kit.beam(Vector3(-0.5, 0.1, -0.4), Vector3(0.2, 2.2, 0.1), 0.18, 0.06, steel)
			kit.beam(Vector3(0.6, 0.1, 0.3), Vector3(-0.1, 1.6, -0.2), 0.22, 0.06, steel.darkened(0.15))
			kit.beam(Vector3(0.2, 2.2, 0.1), Vector3(-0.1, 1.6, -0.2), 0.14, 0.06, steel)
		"mobile":
			var y := CEIL - 0.1
			kit.box(Vector3(0, y, 0), Vector3(0.02, 0.3, 0.02), DARK)
			kit.beam(Vector3(-0.8, y - 0.15, 0), Vector3(0.8, y - 0.15, 0), 0.02, 0.02, DARK)
			kit.beam(Vector3(0.3, y - 0.5, -0.6), Vector3(0.3, y - 0.5, 0.6), 0.02, 0.02, DARK)
			var mc := [Color("d62828"), Color("1d3557"), Color("f4c430"), DARK, Color("d62828")]
			var pts := [Vector3(-0.8, y - 0.35, 0), Vector3(0.8, y - 0.3, 0), Vector3(0.3, y - 0.7, -0.6), Vector3(0.3, y - 0.65, 0.6), Vector3(0.3, y - 0.35, 0)]
			for i in pts.size():
				kit.box(pts[i], Vector3(0.28, 0.02, 0.2), mc[i] as Color)
		# --- Antiquités -----------------------------------------------------------------------------
		"amphore_socle":
			_colonne(kit, Vector3.ZERO, 0.9, 0.2, MARBLE)
			_amphore(kit, Vector3(0, 0.92, 0), 0.9, Color("b5652f"))
		"cratere":
			kit.box(Vector3(0, 0.5, 0), Vector3(0.6, 1.0, 0.6), WHITE)
			kit.lathe(Vector3(0, 1.0, 0), [Vector2(0.1, 0.0), Vector2(0.12, 0.08), Vector2(0.06, 0.12), Vector2(0.24, 0.3), Vector2(0.27, 0.52), Vector2(0.3, 0.58)], 10, Color("1e1612"))
			kit.lathe(Vector3(0, 1.25, 0), [Vector2(0.26, 0.0), Vector2(0.27, 0.2)], 10, Color("c06a2f"), false, false)
		"sarcophage":
			kit.box(Vector3(0, 0.2, 0), Vector3(0.9, 0.4, 2.7), DARK)
			var sg := Color("c9a227")
			kit.blob(Vector3(0, 0.62, 0.05), Vector3(0.36, 0.22, 1.2), Color("2a5a7a"), sg, 0.04, 1)
			kit.blob(Vector3(0, 0.82, 0.95), Vector3(0.2, 0.16, 0.18), sg, sg.lightened(0.2), 0.04, 0)
			kit.box(Vector3(0, 0.8, 0.3), Vector3(0.5, 0.06, 0.3), Color("1f7a8c"))
			kit.box(Vector3(0, 0.75, -0.5), Vector3(0.45, 0.05, 0.6), sg)
		"momie":
			kit.box(Vector3(0, 0.25, 0), Vector3(0.9, 0.5, 2.8), WOOD)
			kit.blob(Vector3(0, 0.62, 0.0), Vector3(0.22, 0.13, 1.05), Color("cdbf9a"), Color("e0d4b4"), 0.12, 1)
			kit.blob(Vector3(0, 0.66, 0.95), Vector3(0.12, 0.1, 0.13), Color("cdbf9a"), Color("e0d4b4"), 0.1, 0)
			kit.layer = "verre"
			kit.box(Vector3(0, 0.78, 0), Vector3(0.86, 0.56, 2.76), GLASS)
			kit.layer = "base"
		"pharaon":
			kit.box(Vector3(0, 0.3, 0), Vector3(1.6, 0.6, 1.6), STONE)
			var gr := Color("3a3632")
			kit.box(Vector3(0, 0.95, -0.25), Vector3(0.9, 0.7, 0.8), gr)
			kit.box(Vector3(0, 1.55, -0.55), Vector3(0.9, 1.6, 0.2), gr)
			kit.box(Vector3(0, 1.6, -0.25), Vector3(0.55, 0.9, 0.45), gr.lightened(0.05))
			for sx in [-1, 1]:
				kit.box(Vector3(sx * 0.2, 0.6, 0.35), Vector3(0.22, 0.6, 0.3), gr.lightened(0.05))
				kit.box(Vector3(sx * 0.2, 1.33, 0.15), Vector3(0.18, 0.12, 0.55), gr.lightened(0.05))
			kit.box(Vector3(0, 2.2, -0.22), Vector3(0.3, 0.35, 0.3), gr.lightened(0.08))
			kit.box(Vector3(0, 2.25, -0.25), Vector3(0.6, 0.45, 0.25), Color("c9a227").darkened(0.3))
			kit.box(Vector3(0, 2.52, -0.25), Vector3(0.22, 0.14, 0.2), Color("c9a227").darkened(0.3))
		"stele":
			kit.box(Vector3(0, 0.15, 0), Vector3(0.75, 0.3, 0.5), DARK)
			kit.box(Vector3(0, 0.85, 0), Vector3(0.6, 1.1, 0.25), Color("2e2c2e"))
			for i in 9:
				kit.box(Vector3(0, 0.45 + i * 0.1, 0.13), Vector3(0.48, 0.015, 0.005), Color("8a8580"))
		"colonne":
			_colonne(kit, Vector3.ZERO, h, 0.28, MARBLE)
		"mosaique":
			kit.box(Vector3(0, 0.012, 0), Vector3(w - 0.2, 0.025, d - 0.2), Color("d9c8a8"), 0.0)
			var mcols := [Color("8e3a2a"), Color("2f4a6a"), Color("c9a227"), Color("3a6a4a"), Color("1e1a18")]
			for i in 5:
				for j in 5:
					if (i + j) % 2 == 0 or (i == 2 and j == 2):
						kit.box(Vector3(-1.0 + i * 0.5, 0.027, -1.0 + j * 0.5), Vector3(0.34, 0.008, 0.34), mcols[(i * 3 + j) % mcols.size()] as Color, 0.0)
			kit.box(Vector3(0, 0.028, 0), Vector3(w - 0.35, 0.006, 0.06), Color("1e1a18"), 0.0)
		"tete_colossale":
			kit.box(Vector3(0, 0.4, 0), Vector3(1.5, 0.8, 1.5), STONE.darkened(0.1))
			kit.blob(Vector3(0, 1.45, 0), Vector3(0.5, 0.62, 0.5), MARBLE.darkened(0.12), MARBLE, 0.08, 1)
			kit.blob(Vector3(0, 1.5, 0.45), Vector3(0.1, 0.18, 0.1), MARBLE.darkened(0.1), MARBLE, 0.05, 0)
			for sx in [-0.18, 0.18]:
				kit.box(Vector3(sx, 1.62, 0.44), Vector3(0.12, 0.04, 0.04), DARK.lightened(0.2))
		# --- Histoire naturelle ---------------------------------------------------------------------
		"dino_herbivore":
			_estrade(kit, w, d)
			_squelette(kit, [Vector3(-3.7, 0.9, 0), Vector3(-2.6, 1.6, 0), Vector3(-1.2, 2.0, 0), Vector3(0.4, 2.15, 0), Vector3(1.3, 2.3, 0),
				Vector3(2.1, 2.7, 0), Vector3(2.8, 2.85, 0), Vector3(3.3, 2.75, 0)], [-0.8, 0.6], 1.95, 0.55, 0.16)
			kit.blob(Vector3(3.5, 2.75, 0), Vector3(0.22, 0.12, 0.12), BONE, BONE.lightened(0.1), 0.05, 0)
		"dino_carnivore":
			_estrade(kit, w, d)
			_squelette(kit, [Vector3(-2.8, 0.9, 0), Vector3(-1.8, 1.4, 0), Vector3(-0.6, 1.8, 0), Vector3(0.4, 1.9, 0), Vector3(1.3, 2.1, 0), Vector3(1.8, 2.35, 0)], [-0.2, 0.6], 1.75, 0.45, 0.14)
			kit.blob(Vector3(2.25, 2.4, 0), Vector3(0.42, 0.26, 0.2), BONE, BONE.lightened(0.1), 0.06, 0)
			kit.box(Vector3(2.35, 2.2, 0), Vector3(0.5, 0.05, 0.2), BONE.darkened(0.15))
			for sz2 in [-0.12, 0.12]:
				kit.beam(Vector3(1.2, 1.85, sz2), Vector3(1.45, 1.55, sz2 * 2.0), 0.05, 0.05, BONE)
		"mammouth":
			_estrade(kit, w, d)
			_squelette(kit, [Vector3(-1.6, 1.5, 0), Vector3(-0.8, 2.0, 0), Vector3(0.3, 2.3, 0), Vector3(1.1, 2.2, 0)], [-0.9, 0.8], 2.0, 0.55, 0.16)
			kit.blob(Vector3(1.45, 2.15, 0), Vector3(0.4, 0.42, 0.35), BONE, BONE.lightened(0.1), 0.06, 0)
			for sz3 in [-0.22, 0.22]:
				kit.beam(Vector3(1.7, 1.85, sz3), Vector3(2.0, 0.9, sz3 * 2.2), 0.08, 0.08, Color("f2ead6"))
				kit.beam(Vector3(2.0, 0.9, sz3 * 2.2), Vector3(1.85, 1.1, sz3 * 3.0), 0.07, 0.07, Color("f2ead6"))
		"baleine":
			var yb := CEIL - 0.55
			for sx in [-2.5, 0.0, 2.5]:
				kit.box(Vector3(sx, CEIL - 0.2, 0), Vector3(0.015, 0.4, 0.015), DARK)
			var spine := []
			for i in 13:
				var t := float(i) / 12.0
				spine.append(Vector3(-3.8 + t * 7.4, yb + sin(t * PI) * 0.15, 0))
			for i in range(1, spine.size()):
				kit.beam(spine[i - 1], spine[i], 0.08, 0.08, BONE)
			for i in range(3, 10):
				var p: Vector3 = spine[i]
				var r := 0.45 * sin(float(i) / 12.0 * PI)
				for s in [-1, 1]:
					kit.beam(p, p + Vector3(0, -r * 0.5, s * r), 0.03, 0.03, BONE)
					kit.beam(p + Vector3(0, -r * 0.5, s * r), p + Vector3(0, -r, s * r * 0.3), 0.03, 0.03, BONE)
			kit.blob(Vector3(3.8, yb - 0.05, 0), Vector3(0.55, 0.2, 0.32), BONE, BONE.lightened(0.1), 0.05, 0)
			kit.beam(Vector3(-3.8, yb, 0), Vector3(-4.0, yb + 0.1, 0.5), 0.03, 0.1, BONE)
			kit.beam(Vector3(-3.8, yb, 0), Vector3(-4.0, yb + 0.1, -0.5), 0.03, 0.1, BONE)
		"ammonite":
			_colonne(kit, Vector3.ZERO, 0.95, 0.18, DARK.lightened(0.2))
			for i in 10:
				var a := float(i) * 0.75
				var rr := 0.06 + float(i) * 0.03
				kit.blob(Vector3(cos(a) * rr * 0.9, 1.22 + sin(a) * rr * 0.9, 0), Vector3(rr * 0.5, rr * 0.5, 0.09), Color("a08a68"), Color("c8b088"), 0.05, 0)
		"meteorite":
			kit.box(Vector3(0, 0.45, 0), Vector3(0.7, 0.9, 0.7), DARK)
			kit.stone(Vector3(0, 1.12, 0), Vector3(0.55, 0.42, 0.48), Color("4a4644"))
		"ours":
			kit.box(Vector3(0, 0.08, 0), Vector3(w - 0.2, 0.16, 0.8), WOOD)
			var br := Color("5a3a22")
			kit.blob(Vector3(0, 1.2, -0.05), Vector3(0.38, 0.6, 0.3), br, br.lightened(0.1), 0.12, 1)
			kit.blob(Vector3(0, 1.9, 0.05), Vector3(0.2, 0.2, 0.2), br, br.lightened(0.12), 0.08, 1)
			kit.blob(Vector3(0, 1.85, 0.23), Vector3(0.09, 0.08, 0.1), br.lightened(0.15), br, 0.05, 0)
			for sx in [-1, 1]:
				kit.beam(Vector3(sx * 0.32, 1.5, 0.0), Vector3(sx * 0.5, 1.75, 0.25), 0.14, 0.14, br)
				kit.beam(Vector3(sx * 0.16, 0.7, 0.0), Vector3(sx * 0.18, 0.16, 0.05), 0.18, 0.18, br)
		"cerf":
			kit.box(Vector3(0, 0.08, 0), Vector3(w - 0.2, 0.16, 0.8), WOOD)
			var cb := Color("8a5a32")
			kit.blob(Vector3(0, 1.05, 0), Vector3(0.6, 0.22, 0.2), cb, cb.lightened(0.1), 0.08, 1)
			for sx in [-0.45, 0.45]:
				for sz in [-0.08, 0.08]:
					kit.beam(Vector3(sx, 0.95, sz), Vector3(sx, 0.16, sz), 0.06, 0.06, cb.darkened(0.1))
			kit.beam(Vector3(0.5, 1.15, 0), Vector3(0.7, 1.55, 0), 0.12, 0.12, cb)
			kit.blob(Vector3(0.78, 1.6, 0), Vector3(0.14, 0.08, 0.08), cb, cb.lightened(0.1), 0.04, 0)
			for sz4 in [-1, 1]:
				kit.beam(Vector3(0.7, 1.68, sz4 * 0.05), Vector3(0.6, 1.95, sz4 * 0.25), 0.03, 0.03, Color("d8c8a8"))
				kit.beam(Vector3(0.6, 1.95, sz4 * 0.25), Vector3(0.75, 2.0, sz4 * 0.35), 0.025, 0.025, Color("d8c8a8"))
		"papillons":
			kit.box(Vector3(0, 1.5, -0.46), Vector3(0.7, 0.55, 0.04), DARK)
			kit.box(Vector3(0, 1.5, -0.44), Vector3(0.62, 0.47, 0.01), WHITE)
			var pc := [Color("2a6fdb"), Color("f4a261"), Color("e63946"), Color("2a9d8f"), Color("f4c430"), Color("8e44ad")]
			for i in 6:
				var px := -0.2 + (i % 3) * 0.2
				var py := 1.6 - (i / 3) * 0.2
				kit.box(Vector3(px, py, -0.43), Vector3(0.12, 0.08, 0.005), pc[i] as Color)
		# --- Sciences -------------------------------------------------------------------------------
		"machine_vapeur":
			kit.box(Vector3(0, 0.1, 0), Vector3(w - 0.2, 0.2, d - 0.2), DARK)
			kit.tube(Vector3(-0.6, 0.6, 0), Vector3(0.5, 0.6, 0), 0.4, 0.4, 10, Color("2f3a2f"))
			kit.tube(Vector3(0.5, 0.2, 0), Vector3(0.5, 2.5, 0), 0.12, 0.1, 8, DARK)
			kit.tube(Vector3(-1.0, 1.15, -0.45), Vector3(-1.0, 1.15, 0.45), 0.55, 0.55, 14, Color("5a3a22"))
			kit.tube(Vector3(-1.0, 1.15, -0.5), Vector3(-1.0, 1.15, 0.5), 0.12, 0.12, 6, Color("b08d57"))
			kit.beam(Vector3(-1.0, 1.15, 0.5), Vector3(0.1, 1.0, 0.5), 0.06, 0.06, Color("b08d57"))
			kit.tube(Vector3(0.2, 0.9, 0.45), Vector3(0.2, 1.4, 0.45), 0.08, 0.08, 6, Color("b08d57"))
		"lunette":
			for a in 3:
				var ang := float(a) * TAU / 3.0
				kit.beam(Vector3(0, 1.1, 0), Vector3(cos(ang) * 0.45, 0, sin(ang) * 0.6), 0.05, 0.05, WOOD)
			kit.tube(Vector3(0, 1.1, -0.85), Vector3(0, 2.3, 0.85), 0.11, 0.09, 10, Color("b08d57"))
			kit.tube(Vector3(0, 1.1, -0.85), Vector3(0, 0.98, -1.0), 0.05, 0.05, 6, DARK)
		"globe_celeste":
			kit.lathe(Vector3.ZERO, [Vector2(0.3, 0.0), Vector2(0.06, 0.1), Vector2(0.05, 0.85)], 8, WOOD)
			kit.blob(Vector3(0, 1.15, 0), Vector3(0.3, 0.3, 0.3), Color("1d3557"), Color("2a4a7a"), 0.0, 2)
			kit.tube(Vector3(0, 0.82, 0), Vector3(0, 1.48, 0), 0.015, 0.015, 4, GOLD)
			for i in 5:
				var a2 := float(i) * 1.3
				kit.box(Vector3(cos(a2) * 0.29, 1.15 + sin(a2 * 1.7) * 0.18, sin(a2) * 0.29), Vector3(0.04, 0.04, 0.04), Color("f4d35e"))
		"planetaire":
			kit.box(Vector3(0, 0.4, 0), Vector3(1.2, 0.8, 1.2), WOOD)
			kit.box(Vector3(0, 0.82, 0), Vector3(1.3, 0.04, 1.3), GOLD)
			kit.tube(Vector3(0, 0.84, 0), Vector3(0, 1.05, 0), 0.02, 0.02, 4, GOLD)
			kit.blob(Vector3(0, 1.1, 0), Vector3(0.12, 0.12, 0.12), Color("f4a020"), Color("ffd060"), 0.0, 1)
			var orb := [[0.25, Color("a09080")], [0.38, Color("e0b070")], [0.52, Color("3a7ad0")], [0.68, Color("c0502a")]]
			for i in orb.size():
				var r2: float = orb[i][0]
				var a3 := float(i) * 1.9
				kit.beam(Vector3(0, 0.98, 0), Vector3(cos(a3) * r2, 0.98, sin(a3) * r2), 0.012, 0.012, GOLD)
				kit.blob(Vector3(cos(a3) * r2, 1.02, sin(a3) * r2), Vector3(0.05, 0.05, 0.05), orb[i][1] as Color, (orb[i][1] as Color).lightened(0.2), 0.0, 0)
		"pendule":
			kit.lathe(Vector3.ZERO, [Vector2(0.9, 0.0), Vector2(0.9, 0.12), Vector2(0.75, 0.14)], 16, Color("8a8f94"))
			kit.lathe(Vector3(0, 0.13, 0), [Vector2(0.72, 0.0), Vector2(0.72, 0.01)], 16, Color("e9e1d3"), false, true)
			kit.tube(Vector3(0, CEIL, 0), Vector3(0.12, 0.45, 0.05), 0.008, 0.008, 4, DARK)
			kit.blob(Vector3(0.12, 0.42, 0.05), Vector3(0.12, 0.14, 0.12), GOLD, GOLD.lightened(0.2), 0.0, 1)
		"avion":
			var ya := CEIL - 0.8
			for sx in [-1.2, 1.2]:
				kit.box(Vector3(sx, CEIL - 0.3, 0), Vector3(0.015, 0.6, 0.015), DARK)
			kit.tube(Vector3(0, ya, -1.6), Vector3(0, ya, 1.4), 0.14, 0.25, 8, Color("c8b48a"))
			kit.box(Vector3(0, ya + 0.1, 0.3), Vector3(3.8, 0.04, 0.6), Color("d8c49a"))
			kit.box(Vector3(0, ya - 0.3, 0.3), Vector3(3.6, 0.04, 0.55), Color("d8c49a"))
			for sx2 in [-1.5, -0.6, 0.6, 1.5]:
				kit.box(Vector3(sx2, ya - 0.1, 0.3), Vector3(0.03, 0.4, 0.03), WOOD)
			kit.box(Vector3(0, ya + 0.05, -1.55), Vector3(1.0, 0.03, 0.3), Color("d8c49a"))
			kit.box(Vector3(0, ya + 0.2, -1.55), Vector3(0.03, 0.35, 0.3), Color("d8c49a"))
			kit.box(Vector3(0, ya, 1.45), Vector3(0.05, 0.9, 0.06), WOOD)
		"automobile":
			kit.box(Vector3(0, 0.08, 0), Vector3(w - 0.1, 0.16, d - 0.1), Color("3a3d42"))
			var ac := Color("7a1f1f")
			kit.box(Vector3(0, 0.75, 0.0), Vector3(1.2, 0.45, 2.6), ac)
			kit.box(Vector3(0, 0.75, 1.45), Vector3(0.8, 0.4, 0.5), Color("2b2b2b"))
			kit.box(Vector3(0, 1.05, -0.4), Vector3(1.1, 0.25, 0.8), Color("2b1e14"))
			kit.box(Vector3(0, 1.6, -0.4), Vector3(1.15, 0.04, 1.2), Color("1e1e1e"))
			for sx in [-0.5, 0.5]:
				kit.box(Vector3(sx, 1.3, 0.1), Vector3(0.03, 0.6, 0.03), DARK)
			for sx3 in [-0.68, 0.68]:
				for sz in [-1.0, 1.0]:
					kit.tube(Vector3(sx3 - 0.06, 0.48, sz), Vector3(sx3 + 0.06, 0.48, sz), 0.32, 0.32, 10, Color("1e1e1e"))
					kit.tube(Vector3(sx3 - 0.07, 0.48, sz), Vector3(sx3 + 0.07, 0.48, sz), 0.08, 0.08, 6, GOLD)
			for sx4 in [-0.3, 0.3]:
				kit.tube(Vector3(sx4, 0.95, 1.7), Vector3(sx4, 0.95, 1.78), 0.09, 0.09, 6, GOLD)
		"fusee":
			kit.box(Vector3(0, 0.05, 0), Vector3(0.9, 0.1, 0.9), DARK)
			kit.lathe(Vector3(0, 0.1, 0), [Vector2(0.18, 0.0), Vector2(0.2, 1.7), Vector2(0.14, 2.2), Vector2(0.0, 2.7)], 10, WHITE)
			kit.lathe(Vector3(0, 0.9, 0), [Vector2(0.205, 0.0), Vector2(0.205, 0.15)], 10, Color("d62828"), false, false)
			for a4 in 4:
				var an := float(a4) * TAU / 4.0
				kit.beam(Vector3(cos(an) * 0.18, 0.5, sin(an) * 0.18), Vector3(cos(an) * 0.4, 0.12, sin(an) * 0.4), 0.03, 0.25, Color("d62828"))
		"robot":
			kit.box(Vector3(0, 0.05, 0), Vector3(0.7, 0.1, 0.7), DARK)
			var rc := Color("c0c8d0")
			for sx in [-0.12, 0.12]:
				kit.box(Vector3(sx, 0.45, 0), Vector3(0.14, 0.7, 0.16), rc.darkened(0.15))
			kit.box(Vector3(0, 1.1, 0), Vector3(0.45, 0.6, 0.28), rc)
			for sx2 in [-0.31, 0.31]:
				kit.box(Vector3(sx2, 1.05, 0), Vector3(0.12, 0.55, 0.12), rc.darkened(0.1))
			kit.box(Vector3(0, 1.58, 0), Vector3(0.3, 0.28, 0.26), rc)
			kit.layer = "lumiere"
			kit.box(Vector3(0, 1.6, 0.135), Vector3(0.22, 0.06, 0.01), Color("2ec4f1"))
			kit.box(Vector3(0, 1.2, 0.145), Vector3(0.12, 0.12, 0.01), Color("2ec4f1"))
			kit.layer = "base"
		"borne":
			kit.box(Vector3(0, 0.55, 0), Vector3(0.5, 1.1, 0.4), Color("1d3557"))
			kit.box(Vector3(0, 1.25, 0.05), Vector3(0.55, 0.45, 0.12), Color("1d3557"))
			kit.layer = "lumiere"
			kit.box(Vector3(0, 1.27, 0.115), Vector3(0.45, 0.33, 0.01), Color("7ad0f0"))
			kit.layer = "base"
		# --- Histoire -------------------------------------------------------------------------------
		"armure":
			kit.box(Vector3(0, 0.06, 0), Vector3(0.65, 0.12, 0.65), WOOD)
			_chevalier(kit, Vector3(0, 0.12, 0), Color("a8adb2"))
		"samourai":
			kit.box(Vector3(0, 0.15, 0), Vector3(0.8, 0.3, 0.8), Color("1e1e1e"))
			var sa := Color("8e1e24")
			kit.box(Vector3(0, 0.6, 0), Vector3(0.5, 0.5, 0.35), sa.darkened(0.2))
			kit.box(Vector3(0, 1.1, 0), Vector3(0.45, 0.55, 0.3), sa)
			for i in 4:
				kit.box(Vector3(0, 0.9 + i * 0.12, 0.155), Vector3(0.44, 0.02, 0.01), GOLD)
			for sx in [-0.32, 0.32]:
				kit.box(Vector3(sx, 1.25, 0), Vector3(0.22, 0.28, 0.32), sa.darkened(0.1))
			kit.blob(Vector3(0, 1.55, 0), Vector3(0.14, 0.14, 0.14), Color("1e1e1e"), Color("2e2e2e"), 0.04, 1)
			kit.box(Vector3(0, 1.72, 0.05), Vector3(0.36, 0.04, 0.3), Color("1e1e1e"))
			kit.beam(Vector3(-0.05, 1.7, 0.12), Vector3(-0.2, 1.88, 0.15), 0.02, 0.05, GOLD)
			kit.beam(Vector3(0.05, 1.7, 0.12), Vector3(0.2, 1.88, 0.15), 0.02, 0.05, GOLD)
			kit.layer = "verre"
			kit.box(Vector3(0, 1.1, 0), Vector3(0.78, 1.6, 0.78), GLASS)
			kit.layer = "base"
		"panoplie":
			kit.box(Vector3(0, 1.5, -0.47), Vector3(1.6, 0.9, 0.03), WOOD)
			kit.blob(Vector3(0, 1.5, -0.43), Vector3(0.25, 0.3, 0.04), RED, GOLD, 0.02, 0)
			for s in [-1, 1]:
				kit.beam(Vector3(s * 0.65, 1.15, -0.43), Vector3(-s * 0.2, 1.9, -0.43), 0.04, 0.01, Color("c8ccd0"))
				kit.box(Vector3(s * 0.55, 1.25, -0.42), Vector3(0.2, 0.03, 0.03), GOLD)
		"canon":
			kit.box(Vector3(0, 0.3, -0.2), Vector3(0.7, 0.3, 1.4), WOOD)
			for sx in [-0.42, 0.42]:
				for sz in [-0.6, 0.4]:
					kit.tube(Vector3(sx - 0.04, 0.3, sz), Vector3(sx + 0.04, 0.3, sz), 0.3, 0.3, 10, WOOD.darkened(0.2))
			kit.tube(Vector3(0, 0.6, -0.9), Vector3(0, 0.75, 1.35), 0.2, 0.14, 10, BRONZE.lightened(0.15))
		"carrosse":
			kit.box(Vector3(0, 0.08, 0), Vector3(w - 0.1, 0.16, d - 0.1), Color("3a3d42"))
			var cg := Color("2a4a2a")
			kit.box(Vector3(0, 1.3, -0.2), Vector3(1.3, 1.1, 1.6), cg)
			kit.box(Vector3(0, 1.9, -0.2), Vector3(1.4, 0.12, 1.7), GOLD)
			kit.box(Vector3(0, 2.05, -0.2), Vector3(0.5, 0.2, 0.5), GOLD)
			for sx in [-0.66, 0.66]:
				kit.box(Vector3(sx, 1.35, -0.2), Vector3(0.02, 0.45, 0.6), Color("c8d8e0"))
			kit.box(Vector3(0, 1.2, 1.05), Vector3(0.9, 0.12, 0.6), cg.darkened(0.2))
			kit.beam(Vector3(0, 0.75, 0.6), Vector3(0, 0.9, 1.9), 0.08, 0.08, WOOD)
			for sx2 in [-0.7, 0.7]:
				for sz2 in [-1.1, 0.9]:
					var rr := 0.55 if sz2 < 0 else 0.42
					kit.tube(Vector3(sx2 - 0.04, rr, sz2), Vector3(sx2 + 0.04, rr, sz2), rr, rr, 12, Color("b5452f"))
		"costume", "uniforme":
			kit.box(Vector3(0, 0.05, 0), Vector3(0.6, 0.1, 0.6), DARK)
			kit.tube(Vector3(0, 0.1, 0), Vector3(0, 0.6, 0), 0.02, 0.02, 4, DARK)
			if k == "costume":
				kit.lathe(Vector3(0, 0.25, 0), [Vector2(0.38, 0.0), Vector2(0.18, 0.75), Vector2(0.13, 1.05), Vector2(0.17, 1.3), Vector2(0.06, 1.42)], 10, Color("6b2a4a"))
				kit.lathe(Vector3(0, 1.0, 0), [Vector2(0.14, 0.0), Vector2(0.16, 0.04)], 10, Color("e6d4b8"), false, false)
				kit.blob(Vector3(0, 1.78, 0), Vector3(0.1, 0.12, 0.1), WHITE, WHITE, 0.0, 1)
			else:
				for sx in [-0.09, 0.09]:
					kit.box(Vector3(sx, 0.45, 0), Vector3(0.12, 0.7, 0.14), WHITE)
				kit.box(Vector3(0, 1.1, 0), Vector3(0.4, 0.6, 0.24), Color("1f3b73"))
				kit.box(Vector3(0, 1.1, 0.125), Vector3(0.18, 0.5, 0.01), WHITE)
				for sx2 in [-0.26, 0.26]:
					kit.box(Vector3(sx2, 1.05, 0), Vector3(0.1, 0.55, 0.12), Color("1f3b73"))
				kit.blob(Vector3(0, 1.55, 0), Vector3(0.1, 0.12, 0.1), WHITE, WHITE, 0.0, 1)
				kit.lathe(Vector3(0, 1.62, 0), [Vector2(0.13, 0.0), Vector2(0.12, 0.4), Vector2(0.0, 0.45)], 8, Color("2a1e14"))
		"plan_relief":
			for sx in [-1, 1]:
				for sz in [-1, 1]:
					kit.box(Vector3(sx * 1.3, 0.4, sz * 0.8), Vector3(0.06, 0.8, 0.06), WOOD)
			kit.box(Vector3(0, 0.82, 0), Vector3(2.8, 0.06, 1.8), WOOD)
			kit.box(Vector3(0, 0.86, 0), Vector3(2.7, 0.02, 1.7), Color("7a9a5a"))
			kit.box(Vector3(0.2, 0.87, 0), Vector3(0.3, 0.01, 1.7), Color("4a7ab0"))
			var rng := RandomNumberGenerator.new()
			rng.seed = 42
			for i in 26:
				var bx := rng.randf_range(-1.25, 1.25)
				if absf(bx - 0.2) < 0.2:
					continue
				var bh := rng.randf_range(0.03, 0.09)
				kit.box(Vector3(bx, 0.87 + bh * 0.5, rng.randf_range(-0.75, 0.75)), Vector3(0.1, bh, 0.08), Color("e8dcc8"))
			kit.box(Vector3(-0.7, 0.95, -0.3), Vector3(0.12, 0.18, 0.12), Color("b8a888"))
			kit.layer = "verre"
			kit.box(Vector3(0, 1.0, 0), Vector3(2.8, 0.3, 1.8), GLASS)
			kit.layer = "base"
		"tapisserie":
			kit.box(Vector3(0, 2.45, -0.44), Vector3(w - 0.1, 0.05, 0.05), WOOD)
			var base := Color("7a3a2a") if c != "persan" else Color("7b1e2b")
			kit.box(Vector3(0, 1.4, -0.46), Vector3(w - 0.3, 2.0, 0.02), base, 0.0)
			kit.box(Vector3(0, 1.4, -0.445), Vector3(w - 0.55, 1.75, 0.01), base.lightened(0.12) if c != "persan" else Color("1d3b6e"), 0.0)
			if c == "persan":
				kit.box(Vector3(0, 1.4, -0.44), Vector3(0.8, 0.8, 0.01), Color("d4a017"), 0.0)
			else:
				for i in 5:
					kit.blob(Vector3(-0.9 + i * 0.45, 1.25, -0.435), Vector3(0.12, 0.35, 0.01), Color("3a5a3a"), Color("d8b070"), 0.05, 0)
				kit.box(Vector3(0, 1.85, -0.435), Vector3(w - 0.8, 0.1, 0.01), Color("d8b070"))
		"presse":
			kit.box(Vector3(0, 0.45, 0), Vector3(1.3, 0.9, 0.9), WOOD)
			for sx in [-0.6, 0.6]:
				kit.box(Vector3(sx, 1.3, 0), Vector3(0.14, 1.8, 0.14), WOOD.darkened(0.1))
			kit.box(Vector3(0, 2.15, 0), Vector3(1.4, 0.15, 0.25), WOOD.darkened(0.1))
			kit.tube(Vector3(0, 2.1, 0), Vector3(0, 1.2, 0), 0.06, 0.06, 6, Color("3a3a3a"))
			kit.box(Vector3(0, 1.15, 0), Vector3(0.9, 0.1, 0.6), WOOD2)
			kit.beam(Vector3(0, 1.7, 0), Vector3(0.6, 1.7, 0.4), 0.04, 0.04, Color("3a3a3a"))
			kit.box(Vector3(0, 0.92, 0), Vector3(0.8, 0.02, 0.55), WHITE)
		"cloche":
			kit.box(Vector3(0, 0.1, 0), Vector3(1.6, 0.2, 1.6), DARK)
			for sx in [-0.7, 0.7]:
				kit.box(Vector3(sx, 1.15, 0), Vector3(0.14, 2.1, 0.14), WOOD)
			kit.box(Vector3(0, 2.2, 0), Vector3(1.6, 0.16, 0.18), WOOD)
			kit.lathe(Vector3(0, 0.8, 0), [Vector2(0.55, 0.0), Vector2(0.5, 0.1), Vector2(0.38, 0.6), Vector2(0.3, 1.1), Vector2(0.12, 1.25)], 12, BRONZE.lightened(0.2))
		# --- Arts du monde --------------------------------------------------------------------------
		"masques":
			kit.box(Vector3(0, 1.5, -0.47), Vector3(1.7, 0.9, 0.02), Color("d9c3a0"))
			var mk := [Color("4a2a17"), Color("8a5a33"), Color("2e1e12")]
			for i in 3:
				var x2 := -0.55 + i * 0.55
				kit.blob(Vector3(x2, 1.5, -0.44), Vector3(0.15, 0.3, 0.05), mk[i] as Color, (mk[i] as Color).lightened(0.15), 0.05, 0)
				for sx in [-0.05, 0.05]:
					kit.box(Vector3(x2 + sx, 1.58, -0.39), Vector3(0.04, 0.02, 0.01), WHITE)
		"totem":
			var tc := [Color("8a3a2a"), Color("2a5a7a"), Color("c9a227"), Color("2e4a3a")]
			kit.box(Vector3(0, 0.05, 0), Vector3(0.7, 0.1, 0.7), DARK)
			for i in 4:
				kit.blob(Vector3(0, 0.45 + i * 0.6, 0), Vector3(0.26, 0.3, 0.24), tc[i] as Color, (tc[i] as Color).lightened(0.15), 0.06, 1)
				kit.box(Vector3(0, 0.55 + i * 0.6, 0.22), Vector3(0.22, 0.06, 0.04), WHITE)
			kit.box(Vector3(0, 2.55, 0), Vector3(0.9, 0.12, 0.2), tc[0] as Color)
		"bouddha":
			kit.box(Vector3(0, 0.25, 0), Vector3(1.5, 0.5, 1.5), STONE.darkened(0.15))
			var bb := Color("8a6a2a")
			kit.lathe(Vector3(0, 0.5, 0), [Vector2(0.65, 0.0), Vector2(0.62, 0.15), Vector2(0.45, 0.3)], 10, bb.lightened(0.1))
			kit.blob(Vector3(0, 0.62, 0.15), Vector3(0.55, 0.18, 0.4), bb, bb.lightened(0.1), 0.05, 1)
			kit.blob(Vector3(0, 1.25, 0), Vector3(0.38, 0.5, 0.3), bb, bb.lightened(0.12), 0.06, 1)
			kit.blob(Vector3(0, 1.95, 0.02), Vector3(0.2, 0.24, 0.2), bb, bb.lightened(0.12), 0.04, 1)
			kit.blob(Vector3(0, 2.2, 0.0), Vector3(0.09, 0.09, 0.09), bb.darkened(0.1), bb, 0.04, 0)
			for sx in [-1, 1]:
				kit.beam(Vector3(sx * 0.35, 1.55, 0.0), Vector3(sx * 0.25, 0.95, 0.3), 0.14, 0.14, bb)
		"vase_ming":
			_colonne(kit, Vector3.ZERO, 0.95, 0.2, DARK.lightened(0.15))
			kit.lathe(Vector3(0, 0.97, 0), [Vector2(0.1, 0.0), Vector2(0.22, 0.2), Vector2(0.24, 0.42), Vector2(0.12, 0.65), Vector2(0.09, 0.72), Vector2(0.13, 0.8)], 10, WHITE,
				true, true, func(_i: int, r: int) -> Color: return Color("1d4e9e") if r % 2 == 1 else WHITE)
		"tete_pierre":
			kit.box(Vector3(0, 0.2, 0), Vector3(1.6, 0.4, 1.6), STONE.darkened(0.3))
			var ts := Color("6a645a")
			kit.box(Vector3(0, 1.1, -0.1), Vector3(0.95, 1.4, 0.9), ts)
			kit.box(Vector3(0, 1.85, -0.1), Vector3(1.05, 0.3, 1.0), ts.darkened(0.05))
			kit.box(Vector3(0, 1.3, 0.42), Vector3(0.26, 0.75, 0.2), ts.lightened(0.05))
			kit.box(Vector3(0, 0.75, 0.38), Vector3(0.6, 0.12, 0.12), ts.darkened(0.15))
			for sx in [-0.52, 0.52]:
				kit.box(Vector3(sx, 1.3, -0.1), Vector3(0.12, 0.8, 0.3), ts.darkened(0.08))
			kit.box(Vector3(0, 2.15, -0.1), Vector3(0.7, 0.3, 0.7), Color("8a3a2a"))
		"pirogue":
			kit.box(Vector3(0, 0.15, 0), Vector3(0.7, 0.3, 3.6), DARK)
			kit.blob(Vector3(0, 0.55, 0), Vector3(0.3, 0.2, 1.8), WOOD, WOOD2, 0.04, 1)
			kit.box(Vector3(0, 0.7, 0), Vector3(0.45, 0.04, 3.2), WOOD.darkened(0.3))
			kit.beam(Vector3(0, 0.6, 1.7), Vector3(0, 1.0, 1.95), 0.08, 0.08, WOOD2)
		"kimono":
			kit.box(Vector3(0, 2.0, -0.42), Vector3(1.8, 0.05, 0.05), WOOD)
			var kc := Color("b22234")
			kit.box(Vector3(0, 1.85, -0.44), Vector3(1.7, 0.25, 0.02), kc)
			kit.box(Vector3(0, 1.35, -0.44), Vector3(0.8, 1.0, 0.02), kc)
			kit.box(Vector3(0, 1.45, -0.43), Vector3(0.82, 0.12, 0.01), GOLD)
			for i in 4:
				kit.box(Vector3(-0.25 + i * 0.17, 1.15 + (i % 2) * 0.25, -0.428), Vector3(0.1, 0.1, 0.005), Color("f0d0e0"))
		# --- Éclairage ------------------------------------------------------------------------------
		"rail_spots":
			kit.box(Vector3(0, CEIL - 0.02, 0), Vector3(w - 0.2, 0.04, 0.06), DARK)
			for i in 3:
				var xs := -0.6 + i * 0.6
				kit.tube(Vector3(xs, CEIL - 0.04, 0), Vector3(xs, CEIL - 0.25, 0.08), 0.05, 0.07, 6, DARK)
				kit.layer = "lumiere"
				kit.box(Vector3(xs, CEIL - 0.27, 0.09), Vector3(0.1, 0.02, 0.1), LIGHT)
				kit.layer = "base"
		"lustre":
			kit.tube(Vector3(0, CEIL, 0), Vector3(0, CEIL - 0.45, 0), 0.015, 0.015, 4, GOLD)
			kit.lathe(Vector3(0, CEIL - 0.95, 0), [Vector2(0.05, 0.0), Vector2(0.45, 0.25), Vector2(0.5, 0.32), Vector2(0.1, 0.5)], 10, GOLD)
			kit.layer = "verre"
			kit.lathe(Vector3(0, CEIL - 1.1, 0), [Vector2(0.0, 0.0), Vector2(0.4, 0.2), Vector2(0.42, 0.4), Vector2(0.0, 0.42)], 10, Color(1.0, 0.98, 0.9))
			kit.layer = "lumiere"
			for i in 8:
				var a5 := float(i) * TAU / 8.0
				kit.box(Vector3(cos(a5) * 0.46, CEIL - 0.6, sin(a5) * 0.46), Vector3(0.04, 0.08, 0.04), LIGHT)
			kit.layer = "base"
		"applique":
			kit.box(Vector3(0, 1.9, -0.47), Vector3(0.12, 0.2, 0.03), GOLD)
			kit.beam(Vector3(0, 1.9, -0.46), Vector3(0, 2.0, -0.3), 0.03, 0.03, GOLD)
			kit.layer = "lumiere"
			kit.lathe(Vector3(0, 1.98, -0.3), [Vector2(0.06, 0.0), Vector2(0.11, 0.14)], 8, LIGHT, false, false)
			kit.layer = "base"
		"projecteur":
			for a in 3:
				var ang := float(a) * TAU / 3.0
				kit.beam(Vector3(0, 0.9, 0), Vector3(cos(ang) * 0.35, 0, sin(ang) * 0.35), 0.03, 0.03, DARK)
			kit.tube(Vector3(0, 0.9, 0), Vector3(0, 1.65, 0), 0.025, 0.025, 4, DARK)
			kit.tube(Vector3(0, 1.75, -0.12), Vector3(0, 1.7, 0.15), 0.12, 0.15, 8, DARK)
			kit.layer = "lumiere"
			kit.box(Vector3(0, 1.7, 0.16), Vector3(0.22, 0.22, 0.01), LIGHT)
			kit.layer = "base"
		"colonne_lumineuse":
			kit.box(Vector3(0, 0.05, 0), Vector3(0.5, 0.1, 0.5), DARK)
			kit.layer = "lumiere"
			kit.tube(Vector3(0, 0.1, 0), Vector3(0, 2.1, 0), 0.16, 0.16, 8, LIGHT)
			kit.layer = "base"
			kit.box(Vector3(0, 2.15, 0), Vector3(0.4, 0.1, 0.4), DARK)
		"verriere":
			# Cadre fin autour d'un panneau lumineux (vu d'en haut en coupe : clair).
			var fc := Color("c9ccd1")
			kit.box(Vector3(0, CEIL + 0.1, -(d - 0.2) * 0.5), Vector3(w - 0.2, 0.06, 0.12), fc)
			kit.box(Vector3(0, CEIL + 0.1, (d - 0.2) * 0.5), Vector3(w - 0.2, 0.06, 0.12), fc)
			kit.box(Vector3(-(w - 0.2) * 0.5, CEIL + 0.1, 0), Vector3(0.12, 0.06, d - 0.2), fc)
			kit.box(Vector3((w - 0.2) * 0.5, CEIL + 0.1, 0), Vector3(0.12, 0.06, d - 0.2), fc)
			kit.layer = "verre"
			kit.box(Vector3(0, CEIL + 0.11, 0), Vector3(w - 0.3, 0.02, d - 0.3), Color("cfe8ff"))
			kit.layer = "lumiere"
			kit.box(Vector3(0, CEIL + 0.06, 0), Vector3(w - 0.4, 0.02, d - 0.4), Color("dff0ff"))
			kit.layer = "base"
			for i in 3:
				kit.box(Vector3(-0.8 + i * 0.8, CEIL + 0.05, 0), Vector3(0.05, 0.05, d - 0.3), fc)
		# --- Parcours ---------------------------------------------------------------------------------
		"cordon":
			for sx in [-0.85, 0.0, 0.85]:
				kit.box(Vector3(sx, 0.03, 0), Vector3(0.28, 0.06, 0.28), GOLD)
				kit.tube(Vector3(sx, 0.06, 0), Vector3(sx, 0.95, 0), 0.035, 0.035, 6, GOLD)
				kit.blob(Vector3(sx, 0.98, 0), Vector3(0.05, 0.05, 0.05), GOLD, GOLD.lightened(0.2), 0.0, 0)
			for sx2 in [-0.425, 0.425]:
				kit.beam(Vector3(sx2 - 0.4, 0.9, 0), Vector3(sx2, 0.78, 0), 0.04, 0.04, RED)
				kit.beam(Vector3(sx2, 0.78, 0), Vector3(sx2 + 0.4, 0.9, 0), 0.04, 0.04, RED)
		"banc_musee":
			kit.box(Vector3(0, 0.4, 0), Vector3(1.8, 0.12, 0.55), Color("2b2b2b"))
			kit.box(Vector3(0, 0.47, 0), Vector3(1.75, 0.04, 0.5), Color("5a1a20"))
			for sx in [-0.75, 0.75]:
				kit.box(Vector3(sx, 0.18, 0), Vector3(0.08, 0.36, 0.45), Color("8a8f94"))
		"cartel":
			kit.box(Vector3(0, 1.2, -0.47), Vector3(0.22, 0.14, 0.015), WHITE)
			kit.box(Vector3(0, 1.22, -0.46), Vector3(0.16, 0.015, 0.003), DARK)
			kit.box(Vector3(0, 1.18, -0.46), Vector3(0.14, 0.01, 0.003), Color("8a8f94"))
		"panneau_info":
			kit.box(Vector3(0, 0.03, 0), Vector3(0.6, 0.06, 0.4), DARK)
			kit.tube(Vector3(0, 0.06, 0), Vector3(0, 1.1, 0), 0.03, 0.03, 4, DARK)
			kit.box(Vector3(0, 1.45, 0), Vector3(0.75, 0.9, 0.05), Color("1d3557"))
			kit.box(Vector3(0, 1.62, 0.03), Vector3(0.6, 0.18, 0.005), Color("e9c46a"))
			for i in 4:
				kit.box(Vector3(0, 1.42 - i * 0.09, 0.03), Vector3(0.6, 0.02, 0.005), WHITE)
		"fleche":
			kit.box(Vector3(0, 0.005, 0.1), Vector3(0.22, 0.01, 0.5), Color("e9c46a"), 0.0)
			kit.tri(Vector3(-0.3, 0.006, -0.15), Vector3(0.3, 0.006, -0.15), Vector3(0, 0.006, -0.45), Color("e9c46a"), Vector3.UP)
		"plan_musee":
			kit.box(Vector3(0, 0.03, 0), Vector3(0.5, 0.06, 0.4), DARK)
			kit.tube(Vector3(0, 0.06, 0), Vector3(0, 1.1, 0), 0.03, 0.03, 4, DARK)
			kit.box(Vector3(0, 1.4, 0), Vector3(0.7, 0.7, 0.04), WHITE)
			var pcs := [Color("e76f51"), Color("2a9d8f"), Color("e9c46a"), Color("8ab17d")]
			for i in 4:
				kit.box(Vector3(-0.15 + (i % 2) * 0.3, 1.25 + (i / 2) * 0.28, 0.025), Vector3(0.26, 0.24, 0.005), pcs[i] as Color)
			kit.box(Vector3(0.2, 1.6, 0.03), Vector3(0.06, 0.06, 0.005), Color("d62828"))
		"audioguide":
			kit.box(Vector3(0, 0.6, -0.1), Vector3(0.6, 1.2, 0.4), Color("1d3557"))
			for i in 2:
				for j in 4:
					kit.box(Vector3(-0.2 + j * 0.13, 0.75 + i * 0.25, 0.11), Vector3(0.07, 0.16, 0.04), DARK)
			kit.layer = "lumiere"
			kit.box(Vector3(0, 1.3, 0.1), Vector3(0.4, 0.12, 0.01), Color("7ad0f0"))
			kit.layer = "base"
		"ecran_video":
			kit.box(Vector3(0, 1.6, -0.46), Vector3(1.7, 1.0, 0.06), DARK)
			kit.layer = "lumiere"
			kit.box(Vector3(0, 1.6, -0.425), Vector3(1.6, 0.9, 0.01), Color("5a8ac0"))
			kit.box(Vector3(-0.3, 1.5, -0.42), Vector3(0.5, 0.35, 0.005), Color("e9c46a"))
			kit.layer = "base"
		"file_attente":
			for sx in [-0.8, 0.8]:
				for sz in [-0.8, 0.0, 0.8]:
					kit.box(Vector3(sx, 0.02, sz), Vector3(0.25, 0.04, 0.25), DARK)
					kit.tube(Vector3(sx, 0.04, sz), Vector3(sx, 0.95, sz), 0.03, 0.03, 4, Color("8a8f94"))
			for sz2 in [-0.4, 0.4]:
				kit.box(Vector3(-0.8, 0.88, sz2), Vector3(0.03, 0.06, 0.8), Color("1d3557"))
				kit.box(Vector3(0.8, 0.88, sz2), Vector3(0.03, 0.06, 0.8), Color("1d3557"))
			kit.box(Vector3(0, 0.88, -0.8), Vector3(1.6, 0.06, 0.03), Color("1d3557"))
		# --- Services ---------------------------------------------------------------------------------
		"billetterie", "comptoir_cafe", "caisse_boutique":
			var top := Color("2b2f33") if k == "billetterie" else (WOOD2 if k == "comptoir_cafe" else WHITE)
			var face := RED if k == "billetterie" else (WOOD if k == "comptoir_cafe" else Color("1d3557"))
			kit.box(Vector3(0, 0.53, 0.0), Vector3(w - 0.1, 1.06, 0.6), face)
			kit.box(Vector3(0, 1.09, 0.0), Vector3(w - 0.05, 0.06, 0.7), top)
			if k == "billetterie":
				for i in 2:
					var bx2 := -0.6 + i * 1.2
					kit.box(Vector3(bx2, 1.3, -0.05), Vector3(0.35, 0.28, 0.04), DARK)
					kit.layer = "lumiere"
					kit.box(Vector3(bx2, 1.3, -0.025), Vector3(0.3, 0.22, 0.01), Color("7ad0f0"))
					kit.layer = "base"
				kit.box(Vector3(0, 0.75, 0.31), Vector3(1.2, 0.3, 0.01), GOLD)
			elif k == "comptoir_cafe":
				kit.box(Vector3(-0.8, 1.35, -0.1), Vector3(0.5, 0.45, 0.4), Color("8a8f94"))
				for i in 4:
					kit.lathe(Vector3(0.2 + i * 0.2, 1.12, 0.1), [Vector2(0.04, 0.0), Vector2(0.045, 0.09)], 6, WHITE)
			else:
				kit.box(Vector3(0.3, 1.25, -0.05), Vector3(0.35, 0.25, 0.3), DARK)
		"vestiaire", "consignes":
			kit.box(Vector3(0, 0.95, -0.2), Vector3(w - 0.1, 1.9, 0.55), WOOD if k == "vestiaire" else Color("8a8f94"))
			if k == "vestiaire":
				kit.box(Vector3(0, 0.95, 0.08), Vector3(w - 0.25, 1.7, 0.02), Color("3a2a1e"))
				kit.box(Vector3(0, 1.7, 0.0), Vector3(w - 0.3, 0.03, 0.03), Color("8a8f94"))
				var cc := [Color("1d3557"), Color("8e1e24"), Color("6b4a2f"), Color("2a9d8f"), Color("e9c46a")]
				for i in 5:
					kit.box(Vector3(-0.6 + i * 0.3, 1.3, 0.02), Vector3(0.22, 0.75, 0.16), cc[i] as Color)
			else:
				for i in 3:
					for j in 4:
						kit.box(Vector3(-0.6 + i * 0.6, 0.3 + j * 0.45, 0.08), Vector3(0.52, 0.38, 0.02), Color("a8adb2"))
						kit.box(Vector3(-0.42 + i * 0.6, 0.3 + j * 0.45, 0.095), Vector3(0.04, 0.06, 0.01), DARK)
		"souvenirs":
			kit.box(Vector3(0, 0.45, 0), Vector3(0.75, 0.9, 0.75), WHITE)
			var sc := [Color("e63946"), Color("2a9d8f"), Color("f4c430"), Color("1d3557")]
			for i in 4:
				kit.box(Vector3(-0.2 + (i % 2) * 0.4, 1.0 + (i / 2) * 0.2, 0.0), Vector3(0.28, 0.14, 0.5), sc[i] as Color)
			kit.blob(Vector3(0, 1.38, 0), Vector3(0.12, 0.12, 0.12), MARBLE, WHITE, 0.0, 1)
		"livres_art":
			kit.box(Vector3(0, 0.42, 0), Vector3(w - 0.2, 0.84, 0.75), WOOD)
			var lc := [Color("1d3557"), Color("8e1e24"), Color("e9c46a"), Color("2a9d8f"), Color("f3f1ec"), Color("6b4a2f")]
			for i in 6:
				kit.box(Vector3(-0.65 + i * 0.26, 0.87 + (i % 3) * 0.02, 0.0), Vector3(0.22, 0.05 + (i % 3) * 0.04, 0.3), lc[i] as Color)
		"cartes_postales":
			kit.tube(Vector3(0, 0, 0), Vector3(0, 1.7, 0), 0.02, 0.02, 4, Color("8a8f94"))
			kit.box(Vector3(0, 0.02, 0), Vector3(0.45, 0.04, 0.45), Color("8a8f94"))
			var pc2 := [Color("f4a261"), Color("2a9d8f"), Color("e9c46a"), Color("e76f51"), Color("8ab17d"), Color("5a8ac0")]
			for i in 6:
				for s in 4:
					var an2 := float(s) * TAU / 4.0
					kit.box(Vector3(cos(an2) * 0.12, 0.5 + i * 0.2, sin(an2) * 0.12), Vector3(0.1 + absf(sin(an2)) * 0.02, 0.14, 0.1), pc2[(i + s) % pc2.size()] as Color)
		"table_cafe":
			kit.tube(Vector3(0, 0.02, 0), Vector3(0, 0.72, 0), 0.04, 0.04, 6, DARK)
			kit.lathe(Vector3(0, 0.72, 0), [Vector2(0.4, 0.0), Vector2(0.4, 0.04)], 12, WHITE)
			kit.lathe(Vector3.ZERO, [Vector2(0.25, 0.0), Vector2(0.25, 0.03)], 8, DARK)
			for sz in [-0.6, 0.6]:
				var cap := 0.0 if sz < 0 else PI
				_chaise(kit, Vector3(0, 0, sz), cap)
		_:
			if not MuseeModelesThemes.build(kit, e):
				kit.box(Vector3(0, h * 0.5, 0), Vector3(w - 0.2, maxf(h, 0.05), d - 0.2), STONE)


# --- Morceaux réutilisés ------------------------------------------------------------------------

## Cadre de tableau (centre at, face vers +Z) et sa peinture.
static func _frame(kit: LpKit, at: Vector3, fw: float, fh: float, col: Color, c: String, _s: float) -> void:
	kit.box(at, Vector3(fw, fh, 0.05), col)
	var inner := at + Vector3(0, 0, 0.03)
	var iw := fw - 0.12
	var ih := fh - 0.12
	match c:
		"portrait":
			kit.box(inner, Vector3(iw, ih, 0.01), Color("2a2418"))
			kit.blob(inner + Vector3(0, -ih * 0.25, 0.005), Vector3(iw * 0.32, ih * 0.22, 0.01), Color("3a2a1e"), Color("4a3424"), 0.04, 0)
			kit.blob(inner + Vector3(0, ih * 0.08, 0.008), Vector3(iw * 0.16, ih * 0.15, 0.01), Color("d8b894"), Color("e6c8a4"), 0.04, 0)
			kit.box(inner + Vector3(0, ih * 0.24, 0.006), Vector3(iw * 0.36, ih * 0.1, 0.005), Color("1e1610"))
		"nature_morte":
			kit.box(inner, Vector3(iw, ih, 0.01), Color("1e1a14"))
			kit.box(inner + Vector3(0, -ih * 0.3, 0.005), Vector3(iw * 0.9, ih * 0.08, 0.005), Color("5a3a22"))
			for i in 4:
				var colf := [Color("b22222"), Color("e0a030"), Color("6a8a3a"), Color("8e44ad")][i] as Color
				kit.blob(inner + Vector3(-iw * 0.25 + i * iw * 0.16, -ih * 0.18, 0.01), Vector3(0.06, 0.06, 0.01), colf, colf.lightened(0.2), 0.0, 0)
		"paysage":
			kit.box(inner + Vector3(0, ih * 0.2, 0), Vector3(iw, ih * 0.6, 0.01), Color("8ab4d8"))
			kit.box(inner + Vector3(0, -ih * 0.3, 0), Vector3(iw, ih * 0.4, 0.01), Color("6a9a4a"))
			kit.box(inner + Vector3(iw * 0.15, -ih * 0.32, 0.004), Vector3(iw * 0.5, ih * 0.12, 0.005), Color("5a8ac0"))
			for i in 6:
				var cc := [Color("e9c46a"), Color("f4a261"), Color("f2f0ea"), Color("d8a0c0")][i % 4] as Color
				kit.box(inner + Vector3(-iw * 0.4 + i * iw * 0.15, -ih * 0.12 + (i % 2) * 0.04, 0.006), Vector3(0.05, 0.04, 0.003), cc)
			kit.blob(inner + Vector3(iw * 0.32, ih * 0.3, 0.004), Vector3(0.06, 0.06, 0.005), Color("ffe08a"), Color("fff0b0"), 0.0, 0)
		"histoire":
			kit.box(inner, Vector3(iw, ih, 0.01), Color("5a4a3a"))
			kit.box(inner + Vector3(0, ih * 0.3, 0.004), Vector3(iw, ih * 0.35, 0.005), Color("a8b8c0"))
			for i in 7:
				var cc2 := [Color("8e1e24"), Color("1d3557"), Color("e6d4b8"), Color("2a2a2a")][i % 4] as Color
				kit.blob(inner + Vector3(-iw * 0.4 + i * iw * 0.13, -ih * 0.1, 0.008), Vector3(0.05, 0.18, 0.01), cc2, cc2.lightened(0.15), 0.04, 0)
			kit.box(inner + Vector3(iw * 0.1, ih * 0.25, 0.008), Vector3(0.03, ih * 0.4, 0.005), Color("3a2a1e"))
			kit.box(inner + Vector3(iw * 0.18, ih * 0.38, 0.008), Vector3(0.16, 0.1, 0.005), Color("1d3557"))
		"abstrait":
			kit.box(inner, Vector3(iw, ih, 0.01), WHITE)
			kit.box(inner + Vector3(-iw * 0.2, ih * 0.15, 0.005), Vector3(iw * 0.5, ih * 0.5, 0.005), Color("d62828"))
			kit.box(inner + Vector3(iw * 0.3, -ih * 0.3, 0.005), Vector3(iw * 0.3, ih * 0.3, 0.005), Color("1d3557"))
			kit.box(inner + Vector3(iw * 0.32, ih * 0.3, 0.005), Vector3(iw * 0.25, ih * 0.25, 0.005), Color("f4c430"))
			kit.box(inner + Vector3(0.05, 0, 0.007), Vector3(0.025, ih, 0.004), DARK)
			kit.box(inner + Vector3(0, -ih * 0.08, 0.007), Vector3(iw, 0.025, 0.004), DARK)
		"estampe":
			kit.box(inner, Vector3(iw, ih, 0.01), Color("ece2c8"))
			for i in 5:
				kit.blob(inner + Vector3(-iw * 0.3 + i * iw * 0.13, -ih * 0.15 + sin(float(i)) * 0.05, 0.006), Vector3(0.08, 0.1, 0.005), Color("1d4e7e"), Color("f2f0ea"), 0.03, 0)
			kit.tri(inner + Vector3(iw * 0.15, -ih * 0.25, 0.006), inner + Vector3(iw * 0.35, -ih * 0.25, 0.006), inner + Vector3(iw * 0.25, -ih * 0.05, 0.006), Color("f2f0ea"), Vector3.BACK)
		"carte":
			kit.box(inner, Vector3(iw, ih, 0.01), Color("e0cfa0"))
			for p in [Vector2(-0.3, 0.05), Vector2(-0.18, -0.15), Vector2(0.05, 0.1), Vector2(0.12, -0.1), Vector2(0.32, 0.08)]:
				kit.blob(inner + Vector3(iw * p.x, ih * p.y, 0.006), Vector3(iw * 0.08, ih * 0.13, 0.005), Color("a8865a"), Color("8a6a3a"), 0.08, 0)
			kit.box(inner + Vector3(0, 0, 0.004), Vector3(iw, 0.008, 0.003), Color("8a5a3a"))
		_:
			if MuseeModelesThemes.peinture(kit, c, inner, iw, ih):
				return
			kit.box(inner, Vector3(iw, ih, 0.01), Color("3a3020"))
			kit.box(inner + Vector3(0, -ih * 0.2, 0.004), Vector3(iw, ih * 0.5, 0.005), Color("5a5a30"))
			kit.blob(inner + Vector3(-iw * 0.15, -ih * 0.05, 0.008), Vector3(0.06, 0.18, 0.01), Color("8e1e24"), Color("a83a3a"), 0.04, 0)
			kit.box(inner + Vector3(iw * 0.2, ih * 0.15, 0.006), Vector3(iw * 0.3, ih * 0.4, 0.004), Color("6a5a3a"))


static func _colonne(kit: LpKit, at: Vector3, h: float, r: float, col: Color) -> void:
	kit.box(at + Vector3(0, 0.06, 0), Vector3(r * 2.6, 0.12, r * 2.6), col.darkened(0.06))
	kit.tube(at + Vector3(0, 0.12, 0), at + Vector3(0, h - 0.12, 0), r, r * 0.92, 10, col)
	kit.box(at + Vector3(0, h - 0.06, 0), Vector3(r * 2.6, 0.12, r * 2.6), col.darkened(0.06))


static func _amphore(kit: LpKit, at: Vector3, s: float, col: Color) -> void:
	kit.lathe(at, [Vector2(0.03 * s, 0.0), Vector2(0.14 * s, 0.15 * s), Vector2(0.2 * s, 0.4 * s), Vector2(0.15 * s, 0.62 * s), Vector2(0.06 * s, 0.75 * s), Vector2(0.08 * s, 0.82 * s)], 10, col)
	for sx in [-1, 1]:
		kit.beam(at + Vector3(sx * 0.07 * s, 0.75 * s, 0), at + Vector3(sx * 0.17 * s, 0.6 * s, 0), 0.025, 0.025, col.darkened(0.1))


static func _estrade(kit: LpKit, w: float, d: float) -> void:
	kit.box(Vector3(0, 0.08, 0), Vector3(w - 0.2, 0.16, d - 0.2), Color("54585e"))
	kit.box(Vector3(0, 0.165, 0), Vector3(w - 0.4, 0.01, d - 0.4), Color("c8b48a"))


## Squelette : colonne (points), pattes à deux abscisses, hauteur de la hanche,
## demi-largeur, épaisseur des os.
static func _squelette(kit: LpKit, spine: Array, legs: Array, hip: float, half: float, bone: float) -> void:
	for i in range(1, spine.size()):
		kit.beam(spine[i - 1], spine[i], bone, bone, BONE)
	for i in spine.size():
		var p: Vector3 = spine[i]
		kit.blob(p, Vector3(bone * 0.9, bone * 1.2, bone * 0.9), BONE.darkened(0.05), BONE, 0.05, 0)
	# Côtes au-dessus des pattes avant et arrière.
	var x0 := float(legs[0])
	var x1 := float(legs[1])
	for i in 6:
		var x := lerpf(x0, x1, float(i) / 5.0)
		var y := hip + 0.05
		for s in [-1, 1]:
			kit.beam(Vector3(x, y, 0), Vector3(x + 0.05, y - 0.35, s * half), bone * 0.4, bone * 0.4, BONE)
			kit.beam(Vector3(x + 0.05, y - 0.35, s * half), Vector3(x + 0.1, y - 0.7, s * half * 0.35), bone * 0.4, bone * 0.4, BONE)
	for lx in legs:
		for s in [-1, 1]:
			var top := Vector3(float(lx), hip, s * half * 0.6)
			var knee := Vector3(float(lx) + 0.15, hip * 0.5, s * half * 0.7)
			var foot := Vector3(float(lx) + 0.05, 0.2, s * half * 0.75)
			kit.beam(top, knee, bone * 1.1, bone * 1.1, BONE)
			kit.beam(knee, foot, bone, bone, BONE)
			kit.box(foot + Vector3(0.1, 0.03, 0), Vector3(0.32, 0.06, 0.18), BONE.darkened(0.08))
	# Le support d'acier.
	kit.tube(Vector3(lerpf(x0, x1, 0.5), 0.16, 0), Vector3(lerpf(x0, x1, 0.5), hip, 0), 0.03, 0.03, 4, DARK)


## Silhouette debout (statue) : at = pied, s = échelle.
static func _figure(kit: LpKit, at: Vector3, s: float, col: Color, drape: bool) -> void:
	if drape:
		kit.lathe(at, [Vector2(0.2 * s, 0.0), Vector2(0.16 * s, 0.5 * s), Vector2(0.14 * s, 0.85 * s)], 8, col.darkened(0.04))
	else:
		for sx in [-0.07, 0.07]:
			kit.beam(at + Vector3(sx * s, 0, 0), at + Vector3(sx * s, 0.8 * s, 0), 0.09 * s, 0.09 * s, col)
	kit.blob(at + Vector3(0, 1.05 * s, 0), Vector3(0.16 * s, 0.26 * s, 0.11 * s), col, col.lightened(0.1), 0.06, 1)
	kit.blob(at + Vector3(0, 1.42 * s, 0), Vector3(0.09 * s, 0.11 * s, 0.09 * s), col, col.lightened(0.12), 0.04, 1)
	kit.beam(at + Vector3(0.17 * s, 1.25 * s, 0), at + Vector3(0.22 * s, 0.85 * s, 0.05 * s), 0.06 * s, 0.06 * s, col)
	kit.beam(at + Vector3(-0.17 * s, 1.25 * s, 0), at + Vector3(-0.12 * s, 1.0 * s, 0.12 * s), 0.06 * s, 0.06 * s, col)


static func _chevalier(kit: LpKit, at: Vector3, col: Color) -> void:
	for sx in [-0.09, 0.09]:
		kit.box(at + Vector3(sx, 0.42, 0), Vector3(0.13, 0.84, 0.15), col.darkened(0.1))
	kit.box(at + Vector3(0, 0.95, 0), Vector3(0.36, 0.25, 0.24), col.darkened(0.05))
	kit.box(at + Vector3(0, 1.25, 0), Vector3(0.42, 0.4, 0.26), col)
	for sx2 in [-0.28, 0.28]:
		kit.blob(at + Vector3(sx2, 1.4, 0), Vector3(0.11, 0.08, 0.12), col.lightened(0.1), col, 0.03, 0)
		kit.box(at + Vector3(sx2, 1.08, 0.02), Vector3(0.1, 0.5, 0.11), col.darkened(0.05))
	kit.blob(at + Vector3(0, 1.66, 0), Vector3(0.13, 0.16, 0.14), col.lightened(0.05), col, 0.02, 1)
	kit.box(at + Vector3(0, 1.66, 0.13), Vector3(0.14, 0.02, 0.01), DARK)
	kit.beam(at + Vector3(0.3, 0.1, 0.18), at + Vector3(0.3, 1.25, 0.18), 0.03, 0.01, Color("d8dce0"))
	kit.box(at + Vector3(0.3, 0.95, 0.18), Vector3(0.18, 0.03, 0.04), GOLD)


static func _dodo(kit: LpKit, at: Vector3) -> void:
	var g := Color("8a8a7a")
	kit.blob(at + Vector3(0, 0.15, 0), Vector3(0.13, 0.12, 0.16), g, g.lightened(0.15), 0.08, 1)
	kit.blob(at + Vector3(0, 0.3, 0.12), Vector3(0.06, 0.07, 0.06), g, g.lightened(0.15), 0.05, 0)
	kit.beam(at + Vector3(0, 0.3, 0.16), at + Vector3(0, 0.26, 0.25), 0.04, 0.05, Color("e0c060"))
	for sx in [-0.05, 0.05]:
		kit.beam(at + Vector3(sx, 0.05, 0), at + Vector3(sx, 0.0, 0.02), 0.025, 0.025, Color("e0c060"))


static func _chaise(kit: LpKit, at: Vector3, cap: float) -> void:
	var saved := kit.xf
	kit.xf = saved * Transform3D(Basis(Vector3.UP, cap), at)
	kit.box(Vector3(0, 0.45, 0), Vector3(0.4, 0.04, 0.4), WOOD2)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			kit.box(Vector3(sx * 0.17, 0.22, sz * 0.17), Vector3(0.03, 0.45, 0.03), DARK)
	kit.box(Vector3(0, 0.7, -0.18), Vector3(0.4, 0.4, 0.03), WOOD2)
	kit.xf = saved


## Contenu d'une vitrine (bas de la vitrine en at, largeur w, profondeur d, hauteur dispo h).
static func _contenu(kit: LpKit, c: String, at: Vector3, w: float, d: float, h: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(c)
	match c:
		"bijoux":
			for i in 7:
				var col := GOLD if i % 3 != 0 else Color("1f7a8c")
				kit.box(at + Vector3(-w * 0.4 + i * w * 0.13, 0.02, rng.randf_range(-0.15, 0.15)), Vector3(0.09, 0.03, 0.09), col)
			kit.blob(at + Vector3(0, 0.06, 0), Vector3(0.12, 0.05, 0.1), GOLD, Color("1f7a8c"), 0.02, 0)
		"monnaies":
			for i in 18:
				kit.lathe(at + Vector3(-w * 0.42 + (i % 9) * w * 0.105, 0.0, -0.12 + (i / 9) * 0.24), [Vector2(0.03, 0.0), Vector2(0.03, 0.008)], 6, GOLD if i % 2 == 0 else Color("b8b8b0"))
		"fossiles":
			for j in 2:
				for i in 3:
					kit.blob(at + Vector3(-w * 0.33 + i * w * 0.33, 0.12 + j * 0.45, -0.05), Vector3(0.13, 0.1, 0.06), Color("a08a68"), Color("c8b088"), 0.1, 0)
			kit.box(at + Vector3(0, 0.42, 0), Vector3(w, 0.02, d), Color("e0e0e0"))
		"mineraux":
			var mc := [Color("8e44ad"), Color("2a9d8f"), Color("e9c46a"), Color("e76f51"), Color("5a8ac0"), Color("d8e0e8")]
			for j in 2:
				for i in 4:
					var col2 := mc[(i + j * 2) % mc.size()] as Color
					kit.tube(at + Vector3(-w * 0.36 + i * w * 0.24, 0.02 + j * 0.45, -0.05), at + Vector3(-w * 0.36 + i * w * 0.24 + 0.03, 0.22 + j * 0.45, -0.03), 0.06, 0.0, 5, col2)
			kit.box(at + Vector3(0, 0.42, 0), Vector3(w, 0.02, d), Color("e0e0e0"))
		"instruments":
			kit.tube(at + Vector3(-w * 0.3, 0.0, 0), at + Vector3(-w * 0.3, 0.35, 0), 0.03, 0.03, 6, Color("b08d57"))
			kit.tube(at + Vector3(-w * 0.3, 0.35, -0.05), at + Vector3(-w * 0.25, 0.45, 0.08), 0.03, 0.02, 6, Color("b08d57"))
			kit.blob(at + Vector3(0, 0.12, 0), Vector3(0.1, 0.1, 0.1), Color("b08d57"), GOLD, 0.0, 1)
			kit.lathe(at + Vector3(w * 0.3, 0.0, 0), [Vector2(0.08, 0.0), Vector2(0.02, 0.05), Vector2(0.02, 0.3)], 6, Color("b08d57"))
			kit.box(at + Vector3(0, 0.55, -0.1), Vector3(0.3, 0.2, 0.15), WOOD)
		"porcelaines":
			for i in 4:
				var vx := -w * 0.36 + i * w * 0.24
				kit.lathe(at + Vector3(vx, 0.0, 0), [Vector2(0.05, 0.0), Vector2(0.11, 0.12), Vector2(0.06, 0.28), Vector2(0.07, 0.32)], 8, WHITE,
					true, true, func(_i: int, r: int) -> Color: return Color("1d4e9e") if r == 1 else WHITE)
		_:
			MuseeModelesThemes.contenu(kit, c, at, w, d, h)
