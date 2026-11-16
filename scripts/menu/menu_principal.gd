class_name MenuPrincipal
extends Node3D
## Écran titre et menu principal : une île low-poly qui tourne doucement, et à
## gauche le menu en groupes (Continuer, Nouvelle partie, Charger · Démo guidée, Scénarios et défis,
## Entre amis, Visiter une ville · Atelier) et une rangée Succès, Options, Crédits, Quitter.
## C'est la scène de départ du jeu. Tout tient dans 1600×900 (voir tests/menu_accueil_vitrine.gd).

const SCENE := "res://scenes/menu_principal.tscn"
const TERRE := "res://scenes/terre.tscn"
const GLOBE := "res://scenes/globe.tscn"
## Mise en page de la colonne de gauche (UI de base 1600×900, toujours au moins 900 de haut).
const LARGEUR := 420.0
const MARGE_HAUT := 52.0
## Place gardée en bas pour la ligne de version.
const MARGE_BAS := 52.0

const DEVISES := [
	"Le city builder où la Terre entière est ton chantier.",
	"Construire une ville, c'est facile. Trouver une place de parking, moins.",
	"Relief réel, habitants exigeants, budget limité. Bonne chance, Monsieur le Maire.",
	"Aucun nid-de-poule n'a été maltraité pendant le développement.",
	"Ici, les travaux finissent à l'heure. Enfin, presque.",
	"Bâtis, gère, et explique au conseil municipal pourquoi le pont mène dans un champ.",
	"1 m² par case, 510 millions de km² à aménager. On commence quand ?",
]

const CREDITS := "MiniBlocs, un jeu de Gaël, fait avec Godot Engine (MIT).\n\n" \
	+ "Relief : Mapzen Terrain Tiles (AWS Open Data) : SRTM, GMTED, ETOPO1, EU-DEM.\n" \
	+ "Biomes : © ESA WorldCover 2021 (CC BY 4.0).\n" \
	+ "Villes : GeoNames (CC BY 4.0). Drapeaux : flag-icons (MIT).\n" \
	+ "Recherche en ligne : © contributeurs OpenStreetMap (Nominatim).\n\n" \
	+ "Modèles, sons et musique : faits maison, en code.\n" \
	+ "Merci aux habitants virtuels, qui n'ont jamais demandé à naître dans un embouteillage."

var diorama: TitreDiorama
var camera: Camera3D
var _angle := 0.6
var _ui: CanvasLayer
var _menu: VBoxContainer
var _carte: PanelContainer
var _carte_img: TextureRect
var _carte_txt: Label
var _sub: Control
var _derniere := {}
var _boutons := {}
var _aide: Label
var _rangee: HBoxContainer
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	# « -- --serveur » : ce jeu devient le serveur d'une carte entre amis, sans menu.
	if Multijoueur.demarrage_serveur(get_tree()):
		return
	OptionsJeu.appliquer(get_tree())
	OptionsJeu.musique("menu")
	_rng.randomize()
	GameStart.atelier = false
	_scene_3d()
	_build_ui()
	_maj_camera(0.0)


func _process(delta: float) -> void:
	_maj_camera(delta)


func _maj_camera(delta: float) -> void:
	if not OptionsJeu.titre_fixe:
		_angle += delta * 0.035
	var r := 112.0
	camera.position = Vector3(sin(_angle) * r, 34.0 + sin(_angle * 0.7) * 4.0, cos(_angle) * r)
	camera.look_at(Vector3(0, -7.0, 0), Vector3.UP)


func _scene_3d() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("4f7fb8")
	sm.sky_horizon_color = Color("f0c89a")
	sm.ground_horizon_color = Color("e8c9a2")
	sm.ground_bottom_color = Color("6d86a8")
	sm.sun_angle_max = 20.0
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.05
	env.fog_enabled = true
	env.fog_light_color = Color("e8cfb0")
	env.fog_density = 0.0005
	env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("ffd8a6")
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 220.0
	sun.rotation_degrees = Vector3(-32.0, -50.0, 0.0)
	add_child(sun)
	diorama = TitreDiorama.new()
	diorama.name = "Diorama"
	add_child(diorama)
	camera = Camera3D.new()
	camera.fov = 42.0
	camera.far = 900.0
	# L'île à droite de l'écran : le menu occupe la gauche.
	camera.h_offset = -26.0
	add_child(camera)
	camera.current = true


# --- Interface ---------------------------------------------------------------------------

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	add_child(_ui)
	# Dégradé sombre à gauche pour que le menu se lise sur le ciel.
	var grad := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.03, 0.05, 0.05, 0.82))
	g.set_color(1, Color(0.03, 0.05, 0.05, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_to = Vector2(1, 0)
	gt.width = 256
	gt.height = 4
	grad.texture = gt
	grad.anchor_bottom = 1.0
	grad.offset_right = 720
	grad.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	grad.stretch_mode = TextureRect.STRETCH_SCALE
	grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(grad)

	# Colonne de gauche, de haut en bas : logo, devise, menu (défilant si l'écran est
	# trop bas), ligne d'aide du bouton survolé, puis Succès · Options · Crédits · Quitter.
	# Elle s'arrête au-dessus de la ligne de version : rien ne se chevauche.
	var col := VBoxContainer.new()
	col.name = "Colonne"
	col.position = Vector2(80, MARGE_HAUT)
	col.custom_minimum_size = Vector2(LARGEUR, 0)
	col.add_theme_constant_override("separation", 6)
	_ui.add_child(col)
	var logo := Label.new()
	logo.text = "MiniBlocs"
	logo.add_theme_font_size_override("font_size", 68)
	logo.add_theme_color_override("font_color", UiStyle.ACCENT)
	logo.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	logo.add_theme_constant_override("shadow_offset_x", 3)
	logo.add_theme_constant_override("shadow_offset_y", 4)
	col.add_child(logo)
	if EditionDemo.active():
		var badge := Label.new()
		badge.name = "BadgeDemo"
		badge.text = "DÉMO · Steam Next Fest"
		badge.add_theme_font_size_override("font_size", 20)
		badge.add_theme_color_override("font_color", UiStyle.TEXT)
		col.add_child(badge)
	var devise := Label.new()
	devise.name = "Devise"
	devise.text = String(DEVISES[_rng.randi() % DEVISES.size()])
	devise.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	devise.custom_minimum_size = Vector2(LARGEUR, 0)
	devise.add_theme_font_size_override("font_size", 16)
	devise.add_theme_color_override("font_color", UiStyle.TEXT)
	col.add_child(devise)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 14)
	col.add_child(sp)

	# Menu en trois groupes : jouer (la démo en tête pour qui découvre), d'autres façons
	# de jouer, puis l'Atelier.
	_menu = VBoxContainer.new()
	_menu.name = "Menu"
	_menu.add_theme_constant_override("separation", 6)
	col.add_child(UiStyle.scroll_fit(_menu, col, MARGE_BAS))
	_derniere = SaveGame.latest()
	if not _derniere.is_empty():
		var b := _bouton("continuer", "Continuer", "Reprendre « %s »" % String(_derniere.get("nom", _derniere.id)), continuer)
		b.mouse_entered.connect(func() -> void: _carte.visible = true)
	_bouton("demo", "Démo guidée", "Environ %d minutes, pas à pas : fonder un village près de %s et le faire grandir" % [Demo.DUREE_MIN, String(Demo.LIEU.nom).get_slice(",", 0)], lancer_demo)
	_bouton("nouvelle", "Nouvelle partie", "Choisir un lieu sur le globe, n'importe où sur Terre", nouvelle_partie)
	_bouton("charger", "Charger une partie", "Toutes les parties sauvegardées, avec leur aperçu", ouvrir_parties)
	_separateur()
	_bouton("scenarios", "Scénarios et défis", "Des parties avec un lieu, des règles et une date limite : crue, ville sans voiture, grand hiver… et un classement", ouvrir_scenarios)
	_bouton("amis", "Entre amis", "Rejoindre la carte d'un ami avec son code, ou héberger une de tes parties", ouvrir_amis)
	_bouton("visites", "Visiter une ville", "Se promener dans la ville d'un ami ou d'un inconnu (fichier .mbloc, Workshop) et lui laisser une carte postale", ouvrir_visites)
	_separateur()
	_bouton("atelier", "Atelier", "Créer des bâtiments sur un terrain plat, sans habitants ni argent", ouvrir_atelier)
	if EditionDemo.active():
		_bouton("souhaits", "Liste de souhaits ♥", "Ouvrir la page Steam de MiniBlocs pour l'ajouter à ta liste de souhaits", func() -> void: EditionDemo.ouvrir_magasin())
	# Retire un séparateur resté en bout de groupe (édition démo : boutons absents).
	_nettoyer_separateurs()

	# Aide du bouton survolé ou sélectionné : une ligne fixe sous le menu, à la place
	# des infobulles qui flottaient par-dessus les boutons et la version.
	_aide = Label.new()
	_aide.name = "Aide"
	_aide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_aide.custom_minimum_size = Vector2(LARGEUR, 42)
	_aide.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_aide.add_theme_font_size_override("font_size", 14)
	_aide.add_theme_color_override("font_color", Color(UiStyle.TEXT, 0.85))
	col.add_child(_aide)

	_rangee = HBoxContainer.new()
	_rangee.name = "Rangee"
	_rangee.add_theme_constant_override("separation", 6)
	col.add_child(_rangee)
	_bouton("succes", "Succès", "%d succès débloqués sur %d, dans toutes tes parties" % [Succes.nombre(), Succes.total()], ouvrir_succes, true)
	_bouton("options", "Options", "Graphismes, son, sauvegarde automatique, touches, manette", ouvrir_options, true)
	_bouton("credits", "Crédits", "Qui a fait quoi, et avec quelles données", ouvrir_credits, true)
	_bouton("quitter", "Quitter", "Fermer le jeu (les habitants ne t'en voudront pas… trop)", quitter, true)
	var first: Button = _boutons.get("continuer", _boutons.get("demo", _boutons.get("nouvelle")))
	first.grab_focus.call_deferred()

	# Carte « dernière partie » à droite, en bas.
	_carte = PanelContainer.new()
	UiStyle.style_panel(_carte, 0.86, 12, 10)
	_carte.anchor_left = 1.0
	_carte.anchor_right = 1.0
	_carte.anchor_top = 1.0
	_carte.anchor_bottom = 1.0
	_carte.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_carte.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_carte.offset_right = -40
	_carte.offset_bottom = -48
	_ui.add_child(_carte)
	var cv := VBoxContainer.new()
	_carte.add_child(cv)
	var ct := Label.new()
	ct.text = "Dernière partie"
	ct.add_theme_color_override("font_color", UiStyle.ACCENT)
	cv.add_child(ct)
	_carte_img = TextureRect.new()
	_carte_img.custom_minimum_size = Vector2(320, 180)
	_carte_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_carte_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	cv.add_child(_carte_img)
	_carte_txt = Label.new()
	_carte_txt.add_theme_font_size_override("font_size", 13)
	_carte_txt.custom_minimum_size = Vector2(320, 0)
	_carte_txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cv.add_child(_carte_txt)
	_maj_carte()

	var version := Label.new()
	version.name = "VersionBuild"
	version.text = ("Démo · " if EditionDemo.active() else "") + VersionBuild.texte()
	version.add_theme_font_size_override("font_size", 12)
	version.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	version.anchor_top = 1.0
	version.anchor_bottom = 1.0
	version.grow_vertical = Control.GROW_DIRECTION_BEGIN
	version.offset_left = 80
	version.offset_bottom = -16
	_ui.add_child(version)
	if JournalPlantage.dernier_rapport != "" and not JournalPlantage.rapport_vu:
		JournalPlantage.rapport_vu = true
		ouvrir_rapport_plantage.call_deferred()


func _bouton(id: String, texte: String, aide: String, cb: Callable, petit := false) -> Button:
	# Édition démo (Steam Next Fest) : scénarios, carte entre amis, Atelier et succès absents.
	if not EditionDemo.menu_visible(id):
		return null
	var b := Button.new()
	b.name = id
	b.text = texte
	# Pas d'infobulle : l'aide s'affiche dans la ligne fixe sous le menu (_aide).
	b.set_meta("aide", aide)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER if petit else HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(0, 38) if petit else Vector2(LARGEUR, 44)
	b.add_theme_font_size_override("font_size", 16 if petit else 19)
	var marge := 8 if petit else 20
	var n := UiStyle.flat_box(Color(0.06, 0.08, 0.07, 0.55), 10, 10)
	n.content_margin_left = marge
	n.content_margin_right = marge
	var h := UiStyle.flat_box(Color(UiStyle.ACCENT, 0.92), 10, 10)
	h.content_margin_left = marge if petit else 26
	h.content_margin_right = marge
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("focus", h)
	b.add_theme_stylebox_override("pressed", h)
	b.add_theme_color_override("font_hover_color", UiStyle.ACCENT_INK)
	b.add_theme_color_override("font_focus_color", UiStyle.ACCENT_INK)
	b.add_theme_color_override("font_pressed_color", UiStyle.ACCENT_INK)
	b.pressed.connect(cb)
	b.mouse_entered.connect(_montrer_aide.bind(b))
	b.focus_entered.connect(_montrer_aide.bind(b))
	if petit:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_rangee.add_child(b)
	else:
		_menu.add_child(b)
	_boutons[id] = b
	return b


func _montrer_aide(b: Button) -> void:
	if _aide != null and is_instance_valid(b):
		_aide.text = String(b.get_meta("aide", ""))


## Petit espace entre deux groupes de boutons.
func _separateur() -> void:
	var s := Control.new()
	s.name = "Separateur%d" % _menu.get_child_count()
	s.custom_minimum_size = Vector2(0, 8)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu.add_child(s)


func _nettoyer_separateurs() -> void:
	var precedent_sep := true
	for c in _menu.get_children():
		var sep := not (c is Button)
		if sep and precedent_sep:
			_menu.remove_child(c)
			c.queue_free()
			continue
		precedent_sep = sep
	var n := _menu.get_child_count()
	if n > 0 and not (_menu.get_child(n - 1) is Button):
		var d := _menu.get_child(n - 1)
		_menu.remove_child(d)
		d.queue_free()


func _maj_carte() -> void:
	_derniere = SaveGame.latest()
	_carte.visible = not _derniere.is_empty()
	if _derniere.is_empty():
		return
	var tex := SaveGame.load_preview(String(_derniere.id))
	_carte_img.texture = tex
	_carte_img.visible = tex != null
	var res: Dictionary = _derniere.get("resume", {})
	var txt := "%s\n%s" % [String(_derniere.get("nom", _derniere.id)), PartiesPanel.format_date(int(_derniere.get("modifie", 0)))]
	if not res.is_empty():
		txt += "\n%d habitants · %d bâtiments" % [int(res.get("habitants", 0)), int(res.get("batiments", 0))]
	_carte_txt.text = txt


# --- Actions ----------------------------------------------------------------------------

## Quitter : dans la démo, un dernier écran avec la liste de souhaits (FinDemo).
func quitter() -> void:
	if not EditionDemo.active():
		get_tree().quit()
		return
	if get_node_or_null("FinDemo") != null:
		return
	var f := FinDemo.new(FinDemo.Motif.QUITTER)
	f.quitter_demande.connect(func() -> void: get_tree().quit())
	add_child(f)


func continuer() -> void:
	if not _derniere.is_empty():
		charger_partie(String(_derniere.id))


## Démo guidée : nouvelle partie au lieu de la démo, tutoriel puis chapitres (Demo).
func lancer_demo() -> void:
	Demo.lancer()


func nouvelle_partie() -> void:
	GameStart.slot_id = ""
	GameStart.load_slot = ""
	get_tree().change_scene_to_file(GLOBE)


## Ouvre une partie sauvegardée derrière l'écran de chargement.
func charger_partie(slot_id: String) -> void:
	var m := SaveGame.read_manifest(slot_id)
	if m.is_empty():
		return
	var lieu: Dictionary = m.get("lieu", {})
	GameStart.chosen = true
	GameStart.atelier = false
	GameStart.lat = float(lieu.get("lat", GameStart.lat))
	GameStart.lon = float(lieu.get("lon", GameStart.lon))
	GameStart.place_name = String(lieu.get("nom", ""))
	GameStart.load_slot = slot_id
	EcranChargement.aller(TERRE, String(m.get("nom", slot_id)))


func ouvrir_parties() -> void:
	if _sub != null:
		return
	var p := PartiesPanel.new(false)
	p.load_chosen.connect(charger_partie)
	p.closed.connect(func() -> void:
		_sub = null
		_maj_carte())
	_sub = p
	_ui.add_child(p)


## Scénarios et défis : liste, histoire, objectifs, classement, « Jouer ».
func ouvrir_scenarios() -> void:
	if _sub != null:
		return
	var p := ScenariosPanel.new()
	p.closed.connect(func() -> void: _sub = null)
	p.jouer.connect(func(id: String) -> void: Scenarios.lancer(id))
	_sub = p
	_ui.add_child(p)


func ouvrir_amis() -> void:
	if _sub != null:
		return
	var p := MultijoueurPanel.new()
	p.closed.connect(func() -> void: _sub = null)
	_sub = p
	_ui.add_child(p)


func ouvrir_visites() -> void:
	if _sub != null:
		return
	var p := VisitesPanel.new(null, "visiter")
	p.closed.connect(func() -> void: _sub = null)
	_sub = p
	_ui.add_child(p)


func ouvrir_atelier() -> void:
	GameStart.atelier = true
	GameStart.retour_slot = ""
	EcranChargement.aller(TERRE, "Atelier")


func ouvrir_options() -> void:
	if _sub != null:
		return
	var o := OptionsPanel.new()
	o.closed.connect(func() -> void: _sub = null)
	_sub = o
	_ui.add_child(o)


func ouvrir_succes() -> void:
	if _sub != null:
		return
	var p := SuccesPanel.new()
	p.closed.connect(func() -> void:
		_sub = null
		(_boutons.succes as Button).grab_focus())
	_sub = p
	_ui.add_child(p)


func ouvrir_credits() -> void:
	if _sub != null:
		return
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.add_child(center)
	var p := PanelContainer.new()
	UiStyle.style_panel(p, 0.96, 12, 18)
	center.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	var t := Label.new()
	t.text = "Crédits"
	t.add_theme_font_size_override("font_size", 24)
	v.add_child(t)
	var l := Label.new()
	l.text = CREDITS
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(560, 0)
	v.add_child(l)
	var close := Button.new()
	close.text = "Fermer"
	close.pressed.connect(func() -> void:
		_sub = null
		c.queue_free())
	v.add_child(close)
	close.grab_focus.call_deferred()
	_sub = c
	_ui.add_child(c)


## La dernière session s'est arrêtée brutalement : on le dit, on montre où est le
## rapport (rien n'est envoyé) et on propose de reprendre la dernière sauvegarde automatique.
func ouvrir_rapport_plantage() -> void:
	if _sub != null:
		return
	var c := Control.new()
	c.name = "RapportPlantage"
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.add_child(center)
	var p := PanelContainer.new()
	UiStyle.style_panel(p, 0.96, 12, 18)
	center.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	var t := Label.new()
	t.text = "MiniBlocs s'est fermé brutalement"
	t.add_theme_font_size_override("font_size", 24)
	v.add_child(t)
	var auto := SaveGame.derniere_autosave()
	var l := Label.new()
	l.text = ("La dernière fois, le jeu s'est arrêté sans se fermer normalement. Désolé : même les maires les mieux organisés ont des coupures de courant.\n\n"
		+ "Un rapport a été écrit sur ton ordinateur (rien n'a été envoyé en ligne) :\n%s\n\n" % ProjectSettings.globalize_path(JournalPlantage.dernier_rapport)
		+ "Tu peux l'envoyer au développeur pour l'aider à corriger le problème.")
	if not auto.is_empty():
		l.text += "\n\nDernière sauvegarde automatique : « %s », %s." % [String(auto.get("nom", auto.id)), PartiesPanel.format_date(int(auto.get("modifie", 0)))]
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(600, 0)
	v.add_child(l)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	var fermer := func() -> void:
		_sub = null
		c.queue_free()
	var first: Button = null
	if not auto.is_empty():
		var rep := Button.new()
		rep.name = "Reprendre"
		rep.text = "Reprendre la sauvegarde automatique"
		rep.pressed.connect(func() -> void:
			fermer.call()
			charger_partie(String(auto.id)))
		row.add_child(rep)
		first = rep
	var dossier := Button.new()
	dossier.name = "Dossier"
	dossier.text = "Ouvrir le dossier des rapports"
	dossier.pressed.connect(func() -> void: JournalPlantage.ouvrir_dossier())
	row.add_child(dossier)
	var close := Button.new()
	close.name = "Fermer"
	close.text = "Fermer"
	close.pressed.connect(fermer)
	row.add_child(close)
	(first if first != null else close).grab_focus.call_deferred()
	_sub = c
	_ui.add_child(c)


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.keycode == KEY_ESCAPE and _sub != null and not (_sub is OptionsPanel or _sub is PartiesPanel or _sub is SuccesPanel or _sub is ScenariosPanel):
		get_viewport().set_input_as_handled()
		_sub.queue_free()
		_sub = null
