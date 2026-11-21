extends SceneTree
## Chevauchements de l'interface en partie : barre du haut (horloge au milieu,
## Annuler/Rétablir/mode plan, chiffres de la ville), mention des sources en bas à
## droite et barre des catégories, panneaux ouverts depuis la Mairie.
## Fenêtres 1280×720, 1600×900 (base), 1920×1080, 2560×1080 (ultra-large) et
## 1600×1200 (4:3), avec la mise à l'échelle du projet (canvas_items, expand), en
## mode Gérer et en mode Créer, avec des chiffres longs (nom de ville, habitants).
## Usage : godot --headless --path . --script res://tests/chevauchements_test.gd

const TAILLES := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1080), Vector2i(1600, 1200)]

var ok := true
var scene: Node
var hud: TerreHud


func _initialize() -> void:
	_run.call_deferred()


func _check(cond: bool, what: String) -> void:
	if not cond:
		push_error("ÉCHEC : " + what)
		ok = false
	else:
		print("  ok  ", what)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _flat_tile(_t: Vector2i) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(256 * 256)
	a.fill(40.0)
	return a


## Deux rectangles se recouvrent (au-delà d'un pixel d'arrondi).
static func _recouvre(a: Rect2, b: Rect2) -> bool:
	return a.grow(-1.0).intersects(b.grow(-1.0))


## Attend `n` images en gardant des chiffres longs dans la barre (la partie les
## remet à jour de temps en temps).
func _attendre(n: int) -> void:
	for i in n:
		hud.set_stats("Vulliens (Vaud) : Illimitée", 1234567, 76, "100 %")
		await process_frame


func _horloge() -> HBoxContainer:
	return root.find_children("Horloge", "HBoxContainer", true, false)[0]


## Barre du haut : dans l'écran, rien ne se recouvre, l'horloge reste dans sa place.
func _verifier_barre(nom: String) -> void:
	var vue := root.get_visible_rect()
	var barre: Control = hud.find_child("BarreHaut", true, false)
	var rb := barre.get_global_rect()
	_check(vue.grow(1.0).encloses(rb), "%s : la barre du haut tient dans l'écran (%s dans %s)" % [nom, rb, vue.size])
	var row := barre.get_child(0) as HBoxContainer
	var elems: Array[Control] = []
	var place: Control = null
	for c in row.get_children():
		var cc := c as Control
		if cc == null or not cc.visible or cc is ColorRect:
			continue
		if cc.name == "PlaceHorloge":
			place = cc
			continue
		elems.append(cc)
	var chevauche := []
	for i in elems.size():
		for j in range(i + 1, elems.size()):
			if _recouvre(elems[i].get_global_rect(), elems[j].get_global_rect()):
				chevauche.append("%s/%s" % [elems[i].name, elems[j].name])
	_check(chevauche.is_empty(), "%s : aucun bouton de la barre n'en recouvre un autre %s" % [nom, chevauche])
	_check(place != null, "%s : place réservée à l'horloge" % nom)
	var h := _horloge()
	var rh := h.get_global_rect()
	_check(place != null and place.get_global_rect().grow(1.0).encloses(rh),
		"%s : l'horloge tient dans sa place (%s dans %s)" % [nom, rh, place.get_global_rect() if place else Rect2()])
	var sous := []
	for e in elems:
		if _recouvre(rh, e.get_global_rect()):
			sous.append(String(e.name))
	_check(sous.is_empty(), "%s : l'horloge ne recouvre aucun bouton (Annuler, Rétablir…) %s" % [nom, sous])
	var hors := []
	for b in h.find_children("*", "Button", true, false):
		if (b as Control).is_visible_in_tree() and not rb.grow(1.0).encloses((b as Control).get_global_rect()):
			hors.append(String(b.name))
	_check(hors.is_empty(), "%s : les boutons de l'horloge restent dans la barre %s" % [nom, hors])
	# Bas de l'écran : la mention des sources ne passe pas sous la barre des catégories.
	if hud._dock.is_visible_in_tree():
		_check(not _recouvre(hud._credit.get_global_rect(), hud._dock.get_global_rect()),
			"%s : la mention des sources ne passe pas sous la barre du bas" % nom)
	# Mini-carte en bas à droite : dans l'écran, sous rien d'autre que les panneaux de droite.
	var mc: MiniCarte = scene.mini_carte
	if mc != null and mc.est_montree():
		mc._placer()
		var rm := mc._cadre.get_global_rect()
		var pb := []
		if not vue.grow(1.0).encloses(rm):
			pb.append("sort de l'écran")
		for autre in [["barre du haut", rb], ["barre des catégories", hud._dock.get_global_rect()],
				["carte de la case", hud._cell_card.get_global_rect()], ["sources", hud._credit.get_global_rect()]]:
			if (autre[1] as Rect2).has_area() and _recouvre(rm, autre[1]):
				pb.append("recouvre " + String(autre[0]))
		_check(pb.is_empty(), "%s : la mini-carte %s tient en bas à droite %s" % [nom, rm, ", ".join(pb)])


func _run() -> void:
	print("Chevauchements de l'interface")
	Creations.persist = false
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.content_scale_size = Vector2i(1600, 900)
	root.size = Vector2i(1600, 900)
	scene = load("res://scenes/terre.tscn").instantiate()
	var world: TerrainWorld = scene.get_node("Terrain")
	root.add_child(scene)
	world.tiles.offline_generator = _flat_tile
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 30
	world.set_origin(48.8584, 2.2945)
	await _frames(30)
	hud = scene.hud
	hud._place_label.text = "Vulliens (Vaud), Suisse"

	# 1) Barre du haut et bas de l'écran, à plusieurs tailles de fenêtre.
	for t in TAILLES:
		root.size = t
		await _attendre(8)
		await _verifier_barre("%d×%d" % [t.x, t.y])
	root.size = Vector2i(1600, 900)
	scene.set_create_mode(true)
	await _attendre(8)
	await _verifier_barre("Mode Créer 1600×900")
	scene.set_create_mode(false)
	await _attendre(8)
	# La caisse d'une ville au long nom est raccourcie, le nom complet reste en infobulle.
	var caisse := hud._chips.caisse as Button
	_check(caisse.size.x <= TerreHud.CAISSE_MAX + 1.0 and caisse.tooltip_text.begins_with("Vulliens (Vaud) : Illimitée"),
		"la caisse d'une ville au long nom est raccourcie (%d px), nom complet en infobulle" % caisse.size.x)

	# 2) Panneaux de gestion (Mairie et tous ses menus) en 1600×900 : dans l'écran,
	# sous la barre du haut, au-dessus de la barre des catégories, à côté de la case.
	var vue := root.get_visible_rect()
	var barre: Rect2 = (hud.find_child("BarreHaut", true, false) as Control).get_global_rect()
	var dock: Rect2 = hud._dock.get_global_rect()
	var carte: Rect2 = hud._cell_card.get_global_rect()
	var deja := []
	for c in scene.find_children("*", "PanelContainer", true, false):
		if (c as Control).is_visible_in_tree():
			deja.append(c)
	var ids := ["mairie"]
	for m in MairiePanel.MENUS:
		for pair in m.ids:
			ids.append(String(pair[0]))
	for id in ids:
		scene.aller_au_panneau(id)
		await _frames(8)
		var vus := 0
		for c in scene.find_children("*", "PanelContainer", true, false):
			var p := c as PanelContainer
			if deja.has(p) or not p.is_visible_in_tree():
				continue
			var n: Node = p
			while n != null and not (n.has_method("set_open") or n.has_method("close_panel") or n.has_method("fermer")):
				n = n.get_parent()
			# Fenêtre sur fond assombri qui couvre tout l'écran (Succès, Visites, Admin…) :
			# elle passe devant le reste, il suffit qu'elle tienne dans l'écran.
			var modale := n is Control and (n as Control).get_global_rect().size.x >= vue.size.x - 1.0
			if p.get_parent() is Container and not (p.get_parent() is CenterContainer):
				continue
			vus += 1
			var r := p.get_global_rect()
			var pb := []
			if not vue.grow(1.0).encloses(r):
				pb.append("sort de l'écran")
			if not modale and _recouvre(r, barre):
				pb.append("recouvre la barre du haut")
			if not modale and _recouvre(r, dock):
				pb.append("recouvre la barre des catégories")
			if not modale and _recouvre(r, carte):
				pb.append("recouvre la carte de la case")
			_check(pb.is_empty(), "panneau %s %s %s" % [id, r, ", ".join(pb)])
			if n != null and n.has_method("set_open"):
				n.set_open(false)
			elif n != null and n.has_method("close_panel"):
				n.close_panel()
			elif n != null:
				n.fermer()
			else:
				p.visible = false
		_check(vus > 0, "le menu %s ouvre un panneau" % id)
		await _frames(3)

	# 3) Colonne de gauche : tutoriel/objectifs, habitant suivi, carte de la case et
	# « À faire » ne se recouvrent pas, même avec une carte de la case très longue.
	scene.tutoriel.demarrer()
	var hab: HabitantsPanel = scene.habitants_panel
	hab.set_process(false) # pas d'habitant réel à suivre ici : la carte reste ouverte
	hab._card.visible = true
	hab._card_text.text = "★ Jeanne Fournier, 0 ans · Bébé\nChez l'assistante maternelle"
	var fil: FilAlertes = scene.fil_alertes
	for i in 4:
		var b := Button.new()
		b.text = "Alerte de test %d" % i
		b.custom_minimum_size = Vector2(0, 44)
		fil._list.add_child(b)
	fil._n = 4
	fil._panel.visible = true
	for lignes in [3, 14]:
		var t := PackedStringArray()
		for i in lignes:
			t.append("Ligne d'information du terrain n° %d" % i)
		hud._cell_label.text = "\n".join(t)
		for t2 in [Vector2i(1600, 900), Vector2i(1280, 720)]:
			root.size = t2
			await _frames(8)
			var cartes := {"tutoriel": scene.tuto_carte.find_child("CarteTutoriel", true, false),
				"habitant suivi": hab._card, "case": hud._cell_card, "À faire": fil._panel}
			var noms := cartes.keys()
			var pb := []
			for i in noms.size():
				var a := cartes[noms[i]] as Control
				if a == null or not a.is_visible_in_tree():
					# Sans place pour son titre, « À faire » se cache (alertes dans la Mairie).
					if not (noms[i] == "À faire" and lignes > 3):
						pb.append("%s invisible" % noms[i])
					continue
				for j in range(i + 1, noms.size()):
					var b2 := cartes[noms[j]] as Control
					if b2 != null and b2.is_visible_in_tree() and _recouvre(a.get_global_rect(), b2.get_global_rect()):
						pb.append("%s/%s" % [noms[i], noms[j]])
			_check(pb.is_empty(), "colonne de gauche (%d lignes, %s) : aucune carte n'en recouvre une autre %s" % [lignes, t2, pb])
	root.size = Vector2i(1600, 900)

	print("TEST OK" if ok else "TEST ÉCHEC")
	quit(0 if ok else 1)
