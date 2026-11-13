extends Node3D
## Scène « Terre » : relie l'interface, la caméra et le terrain réel.

@onready var world: TerrainWorld = $Terrain
@onready var hud: CanvasLayer = $HUD
@onready var rig: Node3D = $CameraRig
@onready var transport: TransportSystem = $Transport
@onready var buildings: BuildingSystem = $Batiments
@onready var build_panel: BuildingPanel = $PanneauConstruction
@onready var zones: ZoneSystem = $Zones
@onready var blocks: BlockEditor = $Blocs
@onready var ambiance: DayNight = $Ambiance
## Murs fins, étages, sous-sols et intérieurs (mode « Murs et étages » de l'éditeur libre).
var plans: PlanEditor

const TRANSPORT_TOOLS := ["departementale", "train", "voie_verte", "canal"]
## Dernière classe choisie pour chaque outil de transport.
var _tool_class := {}

var _status_timer := 0.0
var transit_panel: StationPanel
## Habitants : vie, foyers, travail, école, loisirs et budget (touche H).
var population: Population
var habitants_panel: HabitantsPanel
## Ressources naturelles et chaînes de production (touche P).
var production: Production
var production_panel: ProductionPanel
var resource_overlay: RessourcesOverlay
## Services d'urgence : pompiers, ambulances, police sur les routes (touche U).
var urgences: Urgences
var urgences_panel: UrgencesPanel
## Budget de la commune : impôts, emprunts, entretien et usure des voies (touche M).
var budget: BudgetCommunal
var budget_panel: BudgetPanel
## Déchets : collecte, décharges, tri et recyclage (touche X).
var dechets: Dechets
var dechets_panel: DechetsPanel
## Chantiers, usure des bâtiments, abords et fumée des maisons habitées.
var vie_batiments: BatimentsVie
## Chantiers des voies et des réseaux (SuiviChantiers) et des voies (ChantiersVoies).
var chantiers: SuiviChantiers
var chantiers_voies: ChantiersVoies
var _hover := Vector2i.ZERO
var _hover_valid := false
## Intérieurs : meubles, pièces, usage des bâtiments en murs fins (onglet Intérieur).
var mobilier: Mobilier
var occupants: Occupants
## Habitants au travail visibles (scripts/metiers, touche K).
var metiers_vivants: MetiersVivants
var interieur_panel: InterieurPanel
## Décors : mobilier urbain, clôtures, animaux, bateaux, rochers (touche G).
var decors: DecorSystem
var decors_panel: DecorPanel
## Événements : fêtes, marchés, matchs, incendies, tempêtes, épidémies (touche I).
var evenements: Evenements
var evenements_panel: EvenementsPanel
var actualites: Actualites
## Internet et téléphone : antennes, centraux, cuivre et fibre (Maj + O, scripts/reseaux).
var telecom: Telecom
var telecom_panel: TelecomPanel
## Pollution de l'air et de l'eau, bruit, valeur des terrains et loyers.
var nuisances: Nuisances
## Panneau « Cartes » (touche N) : cartes de couleur de tous les systèmes.
var cartes_panel: CartesPanel


func _ready() -> void:
	# Nouvelle partie : réglages choisis sur le globe (ou ceux par défaut du joueur).
	if GameStart.load_slot == "":
		var r := ReglagesPartie.prochaine if ReglagesPartie.prochaine != null else ReglagesPartie.load_defaults()
		ReglagesPartie.actuel = r.duplicate_settings()
		ReglagesPartie.actuel.createur = SaveGame.player_id()
		ReglagesPartie.prochaine = null
	_setup_plans()
	# Région jouable : REGION_SIZE de côté autour du point de départ.
	var half := GameStart.REGION_SIZE * 0.5
	rig.bounds = Rect2(-half, -half, GameStart.REGION_SIZE, GameStart.REGION_SIZE)
	# Caméra rasante : elle reste au-dessus du relief (détaillé, sinon lointain).
	rig.ground_height = func(x: float, z: float) -> float:
		var g := world.raw_height(x, z)
		if is_nan(g):
			g = world.horizon.height_at(x, z)
		return NAN if is_nan(g) else maxf(g, 0.0)
	world.origin_changed.connect(_on_origin_changed)
	world.hovered_cell_changed.connect(func(c: Vector2i, valid: bool) -> void:
		_hover = c
		_hover_valid = valid
		_refresh_cell_info())
	world.terrain_edited.connect(func(n: int) -> void:
		if n > 0:
			hud.show_message("%d case%s modifiée%s." % [n, "s" if n > 1 else "", "s" if n > 1 else ""])
		_refresh_cell_info())
	hud.go_requested.connect(func(lat: float, lon: float) -> void:
		GameStart.place_name = ""
		world.set_origin(lat, lon))
	hud.tool_selected.connect(_on_tool_selected)
	_setup_landscape()
	_setup_transit()
	_setup_population()
	_setup_mobilier()
	_setup_production()
	_setup_budget()
	_setup_urgences()
	_setup_telecom()
	_setup_dechets()
	_setup_vie()
	_setup_decors()
	_setup_evenements()
	_setup_nuisances()
	_setup_create_mode()
	hud.traffic_toggled.connect(func(on: bool) -> void: transport.traffic.set_enabled(on))
	hud.traffic_filter_changed.connect(func(era: String, region: String) -> void:
		transport.traffic.set_filters(era, region)
		hud.show_message("Véhicules : %s, %s." % [
			"toutes les époques" if era == "" else Styles.era_name(era).to_lower(),
			"toutes les régions" if region == "" else Styles.region_name(region)]))
	transport.info_changed.connect(func(t: String) -> void: hud.set_tool_info(t))
	transport.message.connect(func(t: String) -> void: hud.show_message(t))
	transport.spec_changed.connect(func(id: String, s: Dictionary) -> void: hud.show_spec(id, s, transport.curve_mode, transport.level))
	hud.spec_edited.connect(func(id: String, s: Dictionary) -> void:
		_tool_class[TransportTypes.mode_of(id)] = id
		transport.set_spec(id, s)
		hud.show_spec(id, transport.spec, transport.curve_mode, transport.level))
	hud.curve_toggled.connect(func(on: bool) -> void: transport.set_curve(on))
	hud.level_changed.connect(func(l: String) -> void:
		transport.set_level(l)
		hud.show_message(String(TransportSystem.LEVEL_NAMES[l]) + "."))
	hud.junction_action_changed.connect(func(act: String) -> void: transport.set_junction_tool(act))
	buildings.info_changed.connect(func(t: String) -> void: hud.set_tool_info(t))
	buildings.message.connect(func(t: String) -> void: hud.show_message(t))
	build_panel.building_chosen.connect(func(id: String) -> void:
		_select_building_tool()
		buildings.set_place(id))
	build_panel.demolish_chosen.connect(func() -> void:
		_select_building_tool()
		buildings.set_demolish())
	zones.info_changed.connect(func(t: String) -> void: hud.set_tool_info(t))
	zones.message.connect(func(t: String) -> void: hud.show_message(t))
	build_panel.zone_chosen.connect(func(k: String) -> void:
		_select_building_tool()
		zones.set_paint(k))
	build_panel.zone_remove_chosen.connect(func() -> void:
		_select_building_tool()
		zones.set_remove())
	blocks.info_changed.connect(func(t: String) -> void: hud.set_tool_info(t))
	blocks.message.connect(func(t: String) -> void: hud.show_message(t))
	build_panel.block_tool_chosen.connect(func(t: int) -> void:
		_select_building_tool()
		blocks.set_tool(t))
	build_panel.block_material_chosen.connect(func(m: int) -> void:
		blocks.set_material(m)
		plans.set_material(m)
		if blocks.tool == BlockEditor.Tool.NONE and plans.tool == PlanEditor.Tool.NONE and build_panel.block_mode() == "blocs":
			_select_building_tool()
			blocks.set_tool(BlockEditor.Tool.BLOCK))
	build_panel.block_shape_chosen.connect(func(sh: int) -> void:
		blocks.set_shape(sh)
		if blocks.tool == BlockEditor.Tool.NONE or blocks.tool == BlockEditor.Tool.ERASE or blocks.tool == BlockEditor.Tool.CAPTURE:
			_select_building_tool()
			blocks.set_tool(BlockEditor.Tool.BLOCK))
	($VueSol as VueSol).interaction.connect(func(o: Vector3, d: Vector3) -> void:
		if not blocks.interact_ray(o, d, 4.0):
			if not plans.interact_ray(o, d, 3.0):
				mobilier.interact_ray(o, d, 3.0))
	build_panel.block_tint_chosen.connect(func(t: int) -> void:
		blocks.set_tint(t)
		plans.set_tint(t))
	build_panel.capture_name_changed.connect(func(n: String) -> void: blocks.capture_name = n)
	build_panel.creation_deleted.connect(func(id: String) -> void: Creations.remove(id))
	blocks.captured.connect(func(res: Dictionary) -> void:
		if res.ok:
			blocks.set_tool(BlockEditor.Tool.NONE)
			build_panel.clear_selection())
	build_panel.wall_height_changed.connect(func(h: int) -> void:
		blocks.wall_height = h
		blocks._emit_help())
	build_panel.growth_toggled.connect(func(on: bool) -> void: zones.growth = on)
	build_panel.zone_style_chosen.connect(func(st: String) -> void: zones.current_style = st)
	build_panel.admin_requested.connect(toggle_admin)
	hud.admin_requested.connect(toggle_admin)
	hud.save_requested.connect(func() -> void:
		if save_game():
			hud.show_message("Partie sauvegardée : %s." % _game_title())
		else:
			hud.show_message("Échec de la sauvegarde : " + last_error))
	hud.load_requested.connect(open_saves_panel)
	hud.help_requested.connect(toggle_help)
	hud.quick_load_requested.connect(func() -> void:
		var slot := GameStart.slot_id
		if slot == "" or not SaveGame.exists(slot):
			var all := SaveGame.list_saves()
			slot = String(all[0].id) if not all.is_empty() else ""
		if slot == "":
			hud.show_message("Aucune partie sauvegardée.")
		elif load_game(slot):
			hud.show_message("Partie chargée : %s." % _game_title())
		else:
			hud.show_message("Chargement impossible : " + last_error))
	for sig in [world.terrain_edited, transport.network_changed, buildings.changed, zones.changed, blocks.changed, plans.changed, transport.stations.lines_changed, transport.junctions.changed, population.changed, production.changed, mobilier.changed, evenements.changed, decors.changed]:
		(sig as Signal).connect(func(_a = null) -> void: _unsaved = true)
	hud.build_requested.connect(func() -> void: build_panel.toggle())
	var vue := get_node_or_null("VueSol")
	if vue:
		hud.view_requested.connect(func() -> void: vue.vue_suivante())
		vue.vue_changee.connect(func(v: int) -> void: hud.set_view(v))
	hud.city_requested.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/main.tscn"))
	hud.globe_requested.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/globe.tscn"))
	if GameStart.atelier:
		_prepare_atelier()
	if GameStart.chosen:
		world.set_origin(GameStart.lat, GameStart.lon)
	_on_origin_changed(world.origin_lat, world.origin_lon)
	_apply_settings(true)
	if GameStart.load_slot != "":
		var slot := GameStart.load_slot
		GameStart.load_slot = ""
		if load_game(slot):
			hud.show_message("Partie chargée : %s." % _game_title())
		else:
			hud.show_message("Chargement impossible : " + last_error)
	if GameStart.atelier:
		_start_atelier.call_deferred()


# --- Sauvegarde -------------------------------------------------------------------

## Message de la dernière erreur de sauvegarde ou de chargement.
var last_error := ""
## Des changements depuis la dernière sauvegarde (pour la sauvegarde automatique).
var _unsaved := false
var _autosave_timer := 0.0
## Sauvegarde automatique toutes les 5 minutes, dans une partie à part.
const AUTOSAVE_SLOT := "sauvegarde-auto"
const AUTOSAVE_INTERVAL := 300.0
var _saves_panel: PartiesPanel


func _game_title() -> String:
	if GameStart.place_name != "":
		return GameStart.place_name
	return "Région %.3f, %.3f" % [world.origin_lat, world.origin_lon]


## Sections de la sauvegarde : uniquement ce que le joueur a créé ou changé.
func save_sections() -> Dictionary:
	return {"terrain": world.to_dict(), "transport": transport.to_dict(), "batiments": buildings.to_dict(),
		"zones": zones.to_dict(), "blocs": blocks.to_dict(), "plans": plans.to_dict(), "ambiance": ambiance.to_dict(),
		"creations": Creations.to_dict(Creations.used_by(buildings)),
		"personnage": ($VueSol as VueSol).to_dict(), "habitants": population.to_dict(), "mobilier": mobilier.to_dict(),
		"production": production.to_dict(), "urgences": urgences.to_dict(), "dechets": dechets.to_dict(), "reglages": _settings_snapshot().to_dict(), "budget": budget.to_dict(), "evenements": evenements.to_dict(), "decors": decors.to_dict(),
		"nuisances": nuisances.to_dict(), "telecom": telecom.to_dict()}


## Sauvegarde dans la partie en cours (ou une nouvelle). title : nom d'une nouvelle partie.
func save_game(slot := "", title := "") -> bool:
	if slot == "":
		slot = GameStart.slot_id if GameStart.slot_id != AUTOSAVE_SLOT else ""
	if slot == "":
		slot = SaveGame.make_slot_id(title if title != "" else _game_title())
	var old := SaveGame.read_manifest(slot)
	var name: String = title if title != "" else String(old.get("nom", _game_title()))
	var t := buildings.totals()
	var info := {
		"nom": name,
		"lieu": {"lat": world.origin_lat, "lon": world.origin_lon, "nom": GameStart.place_name},
		"mode": ["bac_a_sable", "entre_amis", "mondiale"][int(GameStart.mode)],
		"camera": {"x": snappedf(rig.position.x, 0.01), "z": snappedf(rig.position.z, 0.01),
			"distance": snappedf(rig._target_distance, 0.01), "angle": snappedf(rig.rotation_degrees.y, 0.01),
			"inclinaison": snappedf(rig.get_target_pitch(), 0.1)},
		"resume": {"habitants": population.persons.size(), "batiments": t.count, "logements": t.logements, "emplois": t.emplois,
			"reseau": TransportSystem._km(_network_length()),
			"blocs": blocks.blocks.size(), "cases_modifiees": world.modifications.size()},
	}
	last_error = SaveGame.write(slot, info, save_sections())
	if last_error != "":
		return false
	if slot != AUTOSAVE_SLOT:
		GameStart.slot_id = slot
	_unsaved = false
	_autosave_timer = 0.0
	return true


## Charge une partie (par défaut la partie en cours).
func load_game(slot := "") -> bool:
	if slot == "":
		slot = GameStart.slot_id
	var res := SaveGame.read(slot)
	if not res.ok:
		last_error = res.error
		return false
	var sec: Dictionary = res.sections
	var m: Dictionary = res.manifest
	var lieu: Dictionary = m.get("lieu", {})
	GameStart.place_name = String(lieu.get("nom", ""))
	world.from_dict(sec.terrain)
	transport.from_dict(sec.get("transport", {}))
	Creations.adopt(sec.get("creations", {}))
	buildings.from_dict(sec.get("batiments", {}))
	zones.from_dict(sec.get("zones", {}))
	blocks.from_dict(sec.get("blocs", {}))
	# Murs fins et meubles avant les habitants : ils y vivent et y travaillent.
	plans.from_dict(sec.get("plans", {}))
	mobilier.from_dict(sec.get("mobilier", {}))
	population.from_dict(sec.get("habitants", {}))
	production.from_dict(sec.get("production", {}))
	budget.from_dict(sec.get("budget", {}))
	decors.from_dict(sec.get("decors", {}))
	urgences.from_dict(sec.get("urgences", {}))
	telecom.from_dict(sec.get("telecom", {}))
	dechets.from_dict(sec.get("dechets", {}))
	ambiance.from_dict(sec.get("ambiance", {}))
	# Après les bâtiments et les habitants : dégâts, ruines, malades, matchs.
	evenements.from_dict(sec.get("evenements", {}))
	nuisances.from_dict(sec.get("nuisances", {}))
	($VueSol as VueSol).from_dict(sec.get("personnage", {}))
	_load_settings(sec.get("reglages", {}), m)
	# Les chantiers repartent de l'heure de la partie chargée.
	vie_batiments._t_prev = ambiance.unix_time
	chantiers._t_prev = ambiance.unix_time
	build_panel.set_growth(zones.growth)
	var cam: Dictionary = m.get("camera", {})
	if not cam.is_empty():
		rig.position.x = float(cam.get("x", 0.0))
		rig.position.z = float(cam.get("z", 0.0))
		rig._target_distance = float(cam.get("distance", rig._target_distance))
		rig.rotation_degrees.y = float(cam.get("angle", 0.0))
		rig.set_pitch(float(cam.get("inclinaison", rig.get_target_pitch())), true)
		_snap_pending = true
	GameStart.slot_id = slot
	_unsaved = false
	_autosave_timer = 0.0
	last_error = "" if res.warnings.is_empty() else "; ".join(res.warnings)
	if last_error != "":
		hud.show_message("Partie chargée avec des pertes : " + last_error)
	return true


# --- Réglages de la partie (panneau Admin) ---------------------------------------

var _admin: AdminPanel
## Vitesses appliquées en dernier (on ne les réimpose que si l'admin les change).
var _applied_speeds := Vector2i(-1, -1)


## Réglages à jour des valeurs changées ailleurs (touche T, panneau Habitants…).
func _settings_snapshot() -> ReglagesPartie:
	var r := ReglagesPartie.actuel
	r.acces_route = buildings.require_access
	r.argent_illimite = buildings.unlimited_money
	r.vitesse_vie = population.life_speed_index
	if ambiance.speed_index > 0:
		r.vitesse_temps = ambiance.speed_index
	_applied_speeds = Vector2i(r.vitesse_temps, r.vitesse_vie)
	return r


## Applique les réglages aux systèmes. speeds : imposer aussi les vitesses.
func _apply_settings(speeds := false) -> void:
	var r := ReglagesPartie.actuel
	buildings.require_access = r.acces_route
	buildings.unlimited_money = r.argent_illimite
	var sp := Vector2i(r.vitesse_temps, r.vitesse_vie)
	if speeds or sp != _applied_speeds:
		ambiance.set_speed(r.vitesse_temps)
		population.life_speed_index = r.vitesse_vie
		_applied_speeds = sp
	buildings._refresh()
	build_panel.refresh()
	if nuisances != null:
		nuisances._dirty = true
	var admin := ReglagesPartie.admin_ici()
	build_panel.set_admin(admin)
	hud.set_admin_visible(admin)


## Réglages d'une partie chargée. Ancienne sauvegarde sans section : réglages
## par défaut, avec les règles gardées par les bâtiments.
func _load_settings(d: Dictionary, manifest: Dictionary) -> void:
	var r := ReglagesPartie.load_defaults()
	if d.is_empty():
		r.acces_route = buildings.require_access
		r.argent_illimite = buildings.unlimited_money
		r.vitesse_vie = population.life_speed_index
		r.vitesse_temps = maxi(1, ambiance.speed_index)
	else:
		r.from_dict(d)
	if r.createur == "":
		r.createur = String(manifest.get("auteur", ""))
	ReglagesPartie.actuel = r
	_applied_speeds = Vector2i(ambiance.speed_index, population.life_speed_index)
	_apply_settings(false)


## Ouvre ou ferme le panneau Admin (F10), si ce joueur est admin de la partie.
func toggle_admin() -> void:
	if _admin != null:
		_admin.close_panel()
		return
	if not ReglagesPartie.admin_ici():
		hud.show_message(ReglagesPartie.qui_est_admin(int(GameStart.mode)))
		return
	_admin = AdminPanel.new(_settings_snapshot(), false, true, buildings.money)
	_admin.closed.connect(func() -> void: _admin = null)
	_admin.settings_changed.connect(func() -> void:
		_apply_settings(false)
		_unsaved = true)
	_admin.caisse_set.connect(func(v: int) -> void:
		buildings.money = v
		_unsaved = true
		hud.show_message("Caisse mise à %s." % BuildingSystem.format_money(v)))
	_windows_layer().add_child(_admin)


## Habitants (simulation) et leur panneau.
func _setup_population() -> void:
	population = Population.new()
	population.name = "Habitants"
	add_child(population)
	population.world = world
	population.buildings = buildings
	population.transport = transport
	population.ambiance = ambiance
	population.rig = rig
	population.vue_sol = $VueSol as VueSol
	population.message.connect(func(t: String) -> void: hud.show_message(t))
	# Pas de bâtiment, personne dans les rues : la circulation suit les habitants.
	transport.traffic.demand = population.traffic_demand
	buildings.changed.connect(func() -> void: population._sync_buildings.call_deferred())
	habitants_panel = HabitantsPanel.new()
	habitants_panel.name = "PanneauHabitants"
	add_child(habitants_panel)
	habitants_panel.setup(population)
	habitants_panel.focus_requested.connect(func(pos: Vector3) -> void:
		rig.position.x = pos.x
		rig.position.z = pos.z)
	hud.habitants_requested.connect(func() -> void: habitants_panel.toggle())


## Vie des bâtiments : chantiers, usure, abords des maisons habitées, fumée.
## Puis le suivi des chantiers de voies et de réseaux (nœud « Chantiers »).
func _setup_vie() -> void:
	vie_batiments = BatimentsVie.new()
	vie_batiments.name = "VieBatiments"
	add_child(vie_batiments)
	vie_batiments.setup(buildings, ambiance, population)
	chantiers = SuiviChantiers.new()
	chantiers.name = "Chantiers"
	add_child(chantiers)
	chantiers.setup(buildings, ambiance, population)
	chantiers_voies = ChantiersVoies.new()
	chantiers_voies.name = "ChantiersVoies"
	add_child(chantiers_voies)
	chantiers_voies.setup(transport, chantiers)


## Événements de la ville et leur panneau (I), fil d'actualité en haut de l'écran.
## Le nœud Evenements vit sous la racine (/root/Evenements) pour les services d'urgence.
func _setup_evenements() -> void:
	evenements = Evenements.new()
	evenements.setup(buildings, population, transport, ambiance, world, rig)
	Evenements.instance = evenements
	get_tree().root.add_child.call_deferred(evenements)
	tree_exiting.connect(func() -> void:
		if is_instance_valid(evenements):
			evenements.queue_free())
	evenements.actualite.connect(func(_n: Dictionary) -> void: _unsaved = true)
	evenements_panel = EvenementsPanel.new()
	evenements_panel.name = "PanneauInfos"
	add_child(evenements_panel)
	evenements_panel.setup(evenements)
	var go := func(pos: Vector3) -> void:
		rig.position.x = pos.x
		rig.position.z = pos.z
	evenements_panel.focus_requested.connect(go)
	evenements_panel.tool_requested.connect(func() -> void: _select_building_tool())
	evenements.outil_change.connect(func(t: String) -> void:
		var names := {"marche": "Marché : clique où poser les étals (clic droit : annuler).",
			"fete": "Fête de quartier : clique où poser les tables et la scène (clic droit : annuler).",
			"incendie": "Incendie : clique sur un bâtiment (clic droit : annuler)."}
		hud.set_tool_info(String(names.get(t, ""))))
	actualites = Actualites.new()
	actualites.name = "FilActualite"
	add_child(actualites)
	actualites.setup(evenements)
	actualites.focus_requested.connect(go)
	actualites.open_requested.connect(func() -> void: evenements_panel.set_open(true))
	hud.infos_requested.connect(func() -> void: evenements_panel.toggle())


## Nuisances (pollution de l'air, de l'eau, bruit) et valeur des terrains, avec
## leurs cartes de couleur dans le panneau Cartes (touche N).
func _setup_nuisances() -> void:
	nuisances = Nuisances.new()
	nuisances.name = "Nuisances"
	add_child(nuisances)
	nuisances.setup(world, buildings, transport, population, ambiance)
	zones.extra_chance = nuisances.chance_pousse
	vie_batiments.extra_usure = nuisances.usure_rythme
	tree_exiting.connect(func() -> void: Calques.vider())
	var make := func(nom: String, deg: Gradient) -> CalqueCouleur:
		var c := CalqueCouleur.new()
		c.name = "Calque" + nom.capitalize()
		c.world = world
		c.focus = rig
		c.degrade = deg
		add_child(c)
		nuisances.recalcule.connect(c.rafraichir)
		return c
	var nz := nuisances
	var specs := [
		["air", "Air", "Nuisances", "pollution de l'air, du jaune (un peu) au violet (très pollué), rien là où l'air est propre : usines, centrales, grandes routes."],
		["eau", "Eau", "Nuisances", "pollution de l'eau et des nappes : usines, fermes, mines, eaux usées."],
		["bruit", "Bruit le jour", "Nuisances", "du jaune (gênant, 40 dB) au violet (80 dB), rien là où c'est calme : routes, rail, aéroports, usines, stades."],
		["nuit", "Bruit la nuit", "Nuisances", "ce qui empêche de dormir : grandes routes, rail, aéroports, bars et discothèques."],
	]
	for sp in specs:
		var c: CalqueCouleur = make.call(String(sp[0]), CalqueCouleur.degrade_nuisance())
		var key := String(sp[0])
		c.seuil = 0.06
		c.valeur = func(x: float, z: float) -> float: return nz.couche(key, x, z)
		Calques.ajouter("nuisances_" + key, String(sp[1]), String(sp[2]), c.montrer, String(sp[3]))
	var cv: CalqueCouleur = make.call("valeur", CalqueCouleur.degrade_valeur())
	cv.alpha = Vector2(0.6, 0.75)
	cv.valeur = func(x: float, z: float) -> float:
		# Seulement là où la ville existe (le reste vaut le prix moyen).
		return nz.couche("valeur", x, z) if nz._tiles.has(Vector2i(floori(x / Nuisances.CELL / Nuisances.TILE), floori(z / Nuisances.CELL / Nuisances.TILE))) else -1.0
	Calques.ajouter("immobilier_valeur", "Valeur du terrain", "Immobilier", cv.montrer,
		"prix du m², du rouge (bon marché) au bleu (très cher). Moyenne : %s €/m²." % BuildingSystem.format_money(roundi(Nuisances.PRIX_M2)).replace(" €", ""))
	var cl: CalqueCouleur = make.call("loyers", CalqueCouleur.degrade_valeur())
	cl.alpha = Vector2(0.75, 0.9)
	cl.rects = func() -> Array:
		var out := []
		for bid in population.known:
			var info: Dictionary = population.known[bid]
			if int(info.log) <= 0 or not info.has("rect"):
				continue
			var c := nz.coef_foncier(bid)
			var v := 0.5 + 0.5 * log(c) / log(3.0) if c >= 1.0 else 0.5 * (c - Nuisances.COEF_MIN) / (1.0 - Nuisances.COEF_MIN)
			# La parcelle autour du bâtiment, pour que la couleur se voie.
			out.append([(info.rect as Rect2i).grow(8), clampf(v, 0.0, 1.0)])
		return out
	population.changed.connect(cl.rafraichir)
	Calques.ajouter("immobilier_loyers", "Loyers", "Immobilier", cl.montrer,
		"loyer de chaque logement, du rouge (bon marché) au bleu (cher). Il suit la valeur du quartier, peu à peu.")
	cartes_panel = CartesPanel.new()
	cartes_panel.name = "PanneauCartes"
	cartes_panel.resume = _resume_nuisances
	cartes_panel.touche_bloquee = func() -> bool: return transport.tool == TransportSystem.Tool.BUILD
	add_child(cartes_panel)
	hud.cartes_requested.connect(func() -> void: cartes_panel.toggle())


## Résumé de la ville sous les cartes : pollution, bruit, valeur et loyers.
func _resume_nuisances() -> Array:
	var out := ["Pollution : %s." % String(Nuisances.NIVEAUX_NOMS[clampi(ReglagesPartie.actuel.pollution, 0, 3)]).to_lower()]
	if population.households.is_empty():
		out.append("Aucun habitant pour l'instant.")
		return out
	var n := 0
	var air := 0.0
	var loud := 0
	var coef := 0.0
	var rent := 0.0
	var cher := 0
	for hid in population.households:
		var b := int(population.households[hid].b)
		var f := nuisances.au_point(nuisances._centre(b))
		n += 1
		air += float(f.air)
		if Nuisances.decibels(float(f.nuit)) >= 55:
			loud += 1
		coef += nuisances.coef_foncier(b)
		rent += nuisances.loyer(b)
		if nuisances.taux_effort(hid) > Nuisances.TAUX_EFFORT_MAX:
			cher += 1
	out.append("Air pollué aux logements : %d %% en moyenne." % roundi(100.0 * air / n))
	out.append("Foyers au bruit la nuit (55 dB ou plus) : %d sur %d." % [loud, n])
	out.append("Terrain des logements : %s €/m² en moyenne." % BuildingSystem.format_money(roundi(Nuisances.PRIX_M2 * coef / n)).replace(" €", ""))
	out.append("Loyer moyen : %s par mois. Foyers au loyer trop cher : %d." % [BuildingSystem.format_money(roundi(rent / n)), cher])
	return out


## Production : sites, stocks, carte des ressources sur le terrain et panneau (P).
func _setup_production() -> void:
	production = Production.new()
	production.name = "Production"
	add_child(production)
	production.setup(world, buildings, population, transport, ambiance)
	production.message.connect(func(t: String) -> void: hud.show_message(t))
	resource_overlay = RessourcesOverlay.new()
	resource_overlay.name = "CarteRessources"
	resource_overlay.world = world
	resource_overlay.carte = production.carte
	resource_overlay.focus = rig
	add_child(resource_overlay)
	production_panel = ProductionPanel.new()
	production_panel.name = "PanneauProduction"
	add_child(production_panel)
	production_panel.setup(production, resource_overlay, rig)
	production_panel.focus_requested.connect(func(pos: Vector3) -> void:
		rig.position.x = pos.x
		rig.position.z = pos.z)
	hud.production_requested.connect(func() -> void: production_panel.toggle())


## Internet et téléphone (scripts/reseaux/telecom.gd) et son panneau (Maj + O),
## aussi en onglet du panneau Réseaux (O) quand il existe.
func _setup_telecom() -> void:
	telecom = Telecom.new()
	telecom.name = "Telecom"
	add_child(telecom)
	telecom.setup(world, buildings, transport, population)
	telecom.message.connect(func(t: String) -> void: hud.show_message(t))
	telecom.info_changed.connect(func(t: String) -> void: hud.set_tool_info(t))
	telecom.outil_active.connect(func() -> void: _select_building_tool())
	telecom_panel = TelecomPanel.new()
	telecom_panel.name = "PanneauTelecom"
	add_child(telecom_panel)
	telecom_panel.setup(telecom)
	world.hovered_cell_changed.connect(func(c: Vector2i, valid: bool) -> void:
		telecom_panel.vue.survol_bid = buildings.building_at(c) if valid else -1)
	_telecom_onglet.call_deferred()


func _telecom_onglet() -> void:
	var r := get_node_or_null("Reseaux")
	if r != null and r.has_method("ajouter_onglet"):
		var v := TelecomVue.new()
		v.setup(telecom)
		world.hovered_cell_changed.connect(func(c: Vector2i, valid: bool) -> void:
			v.survol_bid = buildings.building_at(c) if valid else -1)
		r.ajouter_onglet("Télécom", v)
## Budget communal : impôts votés, emprunts, entretien et usure des voies (M).
func _setup_budget() -> void:
	budget = BudgetCommunal.new()
	budget.name = "Budget"
	add_child(budget)
	budget.setup(buildings, transport, population, production)
	budget.message.connect(func(t: String) -> void: hud.show_message(t))
	budget_panel = BudgetPanel.new()
	budget_panel.name = "PanneauBudget"
	add_child(budget_panel)
	budget_panel.setup(budget)
	budget_panel.focus_requested.connect(func(pos: Vector3) -> void:
		rig.position.x = pos.x
		rig.position.z = pos.z)
	hud.budget_requested.connect(func() -> void: budget_panel.toggle())


## Urgences : casernes, appels, véhicules prioritaires et panneau (U).
func _setup_urgences() -> void:
	urgences = Urgences.new()
	urgences.name = "Urgences"
	add_child(urgences)
	urgences.setup(buildings, transport, population)
	urgences.message.connect(func(t: String) -> void: hud.show_message(t))
	urgences_panel = UrgencesPanel.new()
	urgences_panel.name = "PanneauUrgences"
	add_child(urgences_panel)
	urgences_panel.setup(urgences, rig)
	urgences_panel.focus_requested.connect(func(pos: Vector3) -> void:
		rig.position.x = pos.x
		rig.position.z = pos.z)
	hud.urgences_requested.connect(func() -> void: urgences_panel.toggle())


## Déchets : bacs, bennes sur les routes, décharges, tri et panneau (X).
func _setup_dechets() -> void:
	dechets = Dechets.new()
	dechets.name = "Dechets"
	add_child(dechets)
	dechets.setup(buildings, population, transport, production, ambiance)
	dechets.message.connect(func(t: String) -> void: hud.show_message(t))
	dechets_panel = DechetsPanel.new()
	dechets_panel.name = "PanneauDechets"
	add_child(dechets_panel)
	dechets_panel.setup(dechets)
	dechets_panel.focus_requested.connect(func(pos: Vector3) -> void:
		rig.position.x = pos.x
		rig.position.z = pos.z)
	hud.dechets_requested.connect(func() -> void: dechets_panel.toggle())


## Panneau des transports publics : stations et lignes.
func _setup_transit() -> void:
	transit_panel = StationPanel.new()
	transit_panel.name = "PanneauLignes"
	add_child(transit_panel)
	var st := transport.stations
	transit_panel.setup(st)
	st.info_changed.connect(func(t: String) -> void: hud.set_tool_info(t))
	st.message.connect(func(t: String) -> void: hud.show_message(t))
	hud.transit_requested.connect(func() -> void: transit_panel.toggle())
	transit_panel.station_chosen.connect(func(id: String) -> void:
		_select_building_tool(true)
		build_panel.clear_selection()
		st.set_place(id))
	transit_panel.demolish_chosen.connect(func() -> void:
		_select_building_tool(true)
		build_panel.clear_selection()
		st.set_demolish())
	transit_panel.line_tool_chosen.connect(func() -> void:
		_select_building_tool(true)
		build_panel.clear_selection()
		st.set_line_tool())


func _network_length() -> float:
	var t := 0.0
	for id in transport.network.edges:
		t += float(transport.network.edges[id].len)
	return t


func open_saves_panel() -> void:
	if _saves_panel != null:
		return
	_saves_panel = PartiesPanel.new(true)
	_windows_layer().add_child(_saves_panel)
	_saves_panel.closed.connect(func() -> void: _saves_panel = null)
	_saves_panel.load_chosen.connect(func(slot: String) -> void:
		_saves_panel.close_panel()
		if load_game(slot):
			hud.show_message("Partie chargée : %s." % _game_title())
		else:
			hud.show_message("Chargement impossible : " + last_error))
	_saves_panel.save_as_requested.connect(func(title: String) -> void:
		if save_game(SaveGame.make_slot_id(title), title):
			hud.show_message("Partie sauvegardée : %s." % title)
			_saves_panel.refresh()
		else:
			hud.show_message("Échec de la sauvegarde : " + last_error))


var _help: AidePanel
var _windows: CanvasLayer


## Calque des fenêtres (aide, parties) : au-dessus de tous les panneaux.
func _windows_layer() -> CanvasLayer:
	if _windows == null:
		_windows = CanvasLayer.new()
		_windows.name = "Fenetres"
		_windows.layer = 20
		add_child(_windows)
	return _windows


func toggle_help() -> void:
	if _help != null:
		_help.close_panel()
		return
	_help = AidePanel.new()
	_help.closed.connect(func() -> void: _help = null)
	_windows_layer().add_child(_help)


func _autosave(delta: float) -> void:
	if GameStart.atelier:
		return
	_autosave_timer += delta
	if _autosave_timer < AUTOSAVE_INTERVAL:
		return
	_autosave_timer = 0.0
	if not _unsaved:
		return
	var keep := GameStart.slot_id
	var t := _game_title()
	if save_game(AUTOSAVE_SLOT, "Sauvegarde automatique · " + t):
		hud.show_message("Sauvegarde automatique.")
	GameStart.slot_id = keep
	# La partie du joueur n'est pas à jour : on garde la marque « non sauvegardé ».
	_unsaved = keep != ""


## Murs et étages : outils, étage actif, copie d'étage, toit.
func _setup_plans() -> void:
	plans = PlanEditor.new()
	plans.name = "Plans"
	plans.world_path = NodePath("../Terrain")
	plans.camera_path = NodePath("../CameraRig/Camera3D")
	plans.buildings_path = NodePath("../Batiments")
	plans.blocks_path = NodePath("../Blocs")
	add_child(plans)
	# Ni route ni bâtiment dans un bâtiment en murs fins.
	buildings.extra_blocker = func(c: Vector2i) -> bool: return blocks.columns.has(c) or plans.cells.has(c)
	plans.info_changed.connect(func(t: String) -> void: hud.set_tool_info(t))
	plans.message.connect(func(t: String) -> void: hud.show_message(t))
	plans.level_changed.connect(func(t: String) -> void:
		build_panel.set_level_label(t)
		hud.set_level_text(t)
		_refresh_ladder())
	build_panel.plan_tool_chosen.connect(func(t: int) -> void:
		_select_building_tool()
		plans.set_material(blocks.material)
		plans.set_tint(blocks.tint)
		plans.set_tool(t))
	build_panel.plan_opening_chosen.connect(func(k: String) -> void:
		plans.set_opening(k)
		if plans.tool != PlanEditor.Tool.OPENING:
			_select_building_tool()
			plans.set_tool(PlanEditor.Tool.OPENING))
	build_panel.plan_level_step.connect(func(d: int) -> void: plans.step_level(d))
	build_panel.plan_cutaway_toggled.connect(func(on: bool) -> void: plans.set_cutaway(on))
	build_panel.plan_wall_levels.connect(func(n: int) -> void: plans.set_wall_levels(n))
	build_panel.plan_copy_level.connect(func(n: int) -> void:
		if plans.active_id() == "":
			hud.show_message("Vise d'abord un bâtiment avec un outil Murs et étages.")
			return
		if plans.copy_level_up(plans.active_id(), plans.level, n) > 0:
			hud.show_message("%s recopié sur %d étage%s." % [PlanEditor.level_name(plans.level), n, "s" if n > 1 else ""])
			plans.step_level(n))
	build_panel.plan_roof.connect(func(kind: String) -> void:
		if plans.active_id() == "":
			hud.show_message("Vise d'abord un bâtiment avec un outil Murs et étages.")
			return
		plans.add_roof(plans.active_id(), kind))
	build_panel.plan_reseat.connect(func() -> void:
		if plans.active_id() == "":
			hud.show_message("Vise d'abord un bâtiment avec un outil Murs et étages.")
			return
		var d := plans.reseat(plans.active_id())
		hud.show_message("Bâtiment déjà au ras du sol." if d == 0.0 else "Bâtiment %s de %s m : porte de plain-pied." % ["descendu" if d < 0.0 else "monté", str(absf(d)).replace(".", ",")]))


## Intérieurs : meubles posés case par case, mobilier généré, bâtiments meublés,
## habitants dans les pièces à leurs heures.
func _setup_mobilier() -> void:
	mobilier = Mobilier.new()
	mobilier.name = "Mobilier"
	mobilier.plans_path = NodePath("../Plans")
	mobilier.buildings_path = NodePath("../Batiments")
	mobilier.camera_path = NodePath("../CameraRig/Camera3D")
	add_child(mobilier)
	mobilier.info_changed.connect(func(t: String) -> void: hud.set_tool_info(t))
	mobilier.message.connect(func(t: String) -> void: hud.show_message(t))
	population.extra_buildings = mobilier.population_info
	population.extra_pick = mobilier.bid_at
	mobilier.changed.connect(func() -> void: population._sync_buildings.call_deferred())
	plans.changed.connect(func() -> void: population._sync_buildings.call_deferred())
	occupants = Occupants.new()
	occupants.name = "Occupants"
	add_child(occupants)
	occupants.setup(mobilier, population, get_viewport().get_camera_3d() if get_viewport().get_camera_3d() != null else $CameraRig/Camera3D)
	# Habitants au travail : vue en coupe, gestes, enseignes, personnel (K).
	metiers_vivants = MetiersVivants.new()
	metiers_vivants.name = "MetiersVivants"
	add_child(metiers_vivants)
	metiers_vivants.setup(population, buildings, ambiance, rig)
	metiers_vivants.occupants = occupants
	interieur_panel = InterieurPanel.new()
	interieur_panel.setup(mobilier, func() -> void: _select_building_tool())
	build_panel.interieur_builder = interieur_panel.build
	_setup_atelier_tools()


# --- Personnaliser, banque de modèles, atelier ---------------------------------------

var perso_panel: PersoPanel
var banque_pose: BanquePose
var vue_etages: VueEtages
var banque_panel: BanquePanel


func _setup_atelier_tools() -> void:
	perso_panel = PersoPanel.new()
	perso_panel.name = "PanneauPersonnaliser"
	add_child(perso_panel)
	perso_panel.setup(buildings, mobilier)
	perso_panel.opened_interior.connect(func(id: String) -> void:
		mobilier.focus_plan(id))
	banque_pose = BanquePose.new()
	banque_pose.name = "PoseModele"
	add_child(banque_pose)
	banque_pose.world = world
	banque_pose.camera = $CameraRig/Camera3D
	banque_pose.mob = mobilier
	banque_pose.bs = buildings
	banque_pose.message.connect(func(t: String) -> void:
		hud.set_tool_info(t)
		if t != "" and not t.begins_with("Poser"):
			hud.show_message(t))
	vue_etages = VueEtages.new()
	vue_etages.name = "VueEtages"
	vue_etages.pe = plans
	vue_etages.rig = $CameraRig
	add_child(vue_etages)
	vue_etages.message.connect(func(t: String) -> void: hud.show_message(t))
	banque_panel = BanquePanel.new()
	banque_panel.setup(buildings, mobilier, banque_pose, func() -> void: _select_building_tool())
	build_panel.banque_builder = banque_panel.build
	habitants_panel.customize_requested.connect(func(bid: int) -> void:
		habitants_panel.set_open(false)
		perso_panel.edit(bid))
	habitants_panel.furnish_requested.connect(func(bid: int) -> void:
		var info: Dictionary = population.known.get(bid, {})
		habitants_panel.set_open(false)
		if not hud.create_mode:
			set_create_mode(true)
		mobilier.focus_plan(String(info.get("plan", "")))
		hud.set_create_category("interieur")
		_on_create_requested("interieur"))


## Avant le chargement : l'atelier est un terrain plat, hors ligne.
func _prepare_atelier() -> void:
	world.tiles.offline_generator = func(_t: Vector2i) -> PackedFloat32Array:
		var a := PackedFloat32Array()
		a.resize(256 * 256)
		a.fill(40.0)
		return a
	# Sol bâti (WorldCover 50) : ni arbres ni herbes hautes.
	world.land.offline_generator = func(_lat: float, _lon: float) -> int: return 50
	GameStart.chosen = true
	GameStart.lat = GameStart.ATELIER_LAT
	GameStart.lon = GameStart.ATELIER_LON
	GameStart.place_name = "Atelier"
	GameStart.slot_id = GameStart.ATELIER_SLOT
	GameStart.load_slot = GameStart.ATELIER_SLOT if SaveGame.exists(GameStart.ATELIER_SLOT) else ""


## Après le chargement : argent illimité, pas d'accès routier exigé, temps
## arrêté, mode Créer, tuile « Quitter ».
func _start_atelier() -> void:
	buildings.unlimited_money = true
	buildings.require_access = false
	ambiance.set_speed(0)
	ambiance.weather.mode = Meteo.Mode.SOLEIL
	set_create_mode(true)
	hud.set_category_label("atelier", "Quitter", "Quitter l'atelier et revenir à la partie (l'atelier est gardé tel quel) (7)")
	hud.set_create_banner("Atelier : terrain plat, sans habitants ni argent  ·  7 : quitter")
	hud.show_message("Atelier : crée, personnalise, meuble, puis range tes bâtiments dans la banque (6).")


## Tuile Atelier : y aller depuis la partie (après l'avoir sauvegardée), ou en revenir.
func _toggle_atelier() -> void:
	if GameStart.atelier:
		save_game(GameStart.ATELIER_SLOT, "Atelier")
		GameStart.atelier = false
		if GameStart.retour_slot != "" and SaveGame.exists(GameStart.retour_slot):
			GameStart.chosen = true
			GameStart.lat = GameStart.retour_lat
			GameStart.lon = GameStart.retour_lon
			GameStart.place_name = GameStart.retour_nom
			GameStart.load_slot = GameStart.retour_slot
			GameStart.slot_id = GameStart.retour_slot
			get_tree().change_scene_to_file("res://scenes/terre.tscn")
		else:
			GameStart.slot_id = ""
			get_tree().change_scene_to_file("res://scenes/globe.tscn")
		return
	if not save_game():
		hud.show_message("Sauvegarde impossible, l'atelier attendra : " + last_error)
		return
	GameStart.retour_slot = GameStart.slot_id
	GameStart.retour_lat = world.origin_lat
	GameStart.retour_lon = world.origin_lon
	GameStart.retour_nom = GameStart.place_name
	GameStart.atelier = true
	get_tree().change_scene_to_file("res://scenes/terre.tscn")


# --- Mode Créer : la construction libre à part de la gestion de la ville ---------

## Vitesse du temps avant le mode Créer (la ville s'y met en pause).
var _speed_before_create := -1


func _setup_create_mode() -> void:
	hud.mode_changed.connect(set_create_mode)
	hud.create_requested.connect(_on_create_requested)
	hud.level_step_requested.connect(func(d: int) -> void: plans.step_level(d))
	build_panel.plan_level_set.connect(func(e: int) -> void: plans.set_level(e))
	plans.changed.connect(_refresh_ladder)
	hud.set_level_text(PlanEditor.level_name(plans.level))


## Passe en mode Créer (atelier, ville en pause) ou revient en mode Gérer.
func set_create_mode(on: bool) -> void:
	if GameStart.atelier and not on:
		# L'atelier n'a pas de ville à gérer.
		hud.set_create_mode(true)
		hud.show_message("Tu es dans l'atelier : « Quitter » (7) ramène à la partie.")
		return
	if hud.create_mode != on:
		hud.set_create_mode(on)
	if on:
		_select_building_tool()
		if _speed_before_create < 0:
			_speed_before_create = ambiance.speed_index
		ambiance.set_speed(0)
		_on_create_requested("murs")
		hud.set_create_category("murs")
	else:
		_select_building_tool()
		build_panel.set_workshop(false)
		build_panel.set_open(false)
		if _speed_before_create >= 0:
			ambiance.set_speed(_speed_before_create)
			_speed_before_create = -1


## Barre du bas du mode Créer : Murs et étages, Blocs, Intérieur, Mes créations.
func _on_create_requested(id: String) -> void:
	_select_building_tool()
	if id == "":
		build_panel.set_open(false)
		return
	build_panel.set_workshop(true)
	match id:
		"murs": build_panel.set_block_mode("plans")
		"blocs": build_panel.set_block_mode("blocs")
		"interieur": build_panel.show_category("interieur")
		"creations": build_panel.show_category(Creations.CATEGORY)
		"banque": build_panel.show_category(BanquePanel.CATEGORY)
		"atelier":
			build_panel.set_open(false)
			_toggle_atelier()
			return
	build_panel.set_open(true)
	if id == "murs":
		# On commence avec l'outil Mur en main.
		plans.set_material(blocks.material)
		plans.set_tint(blocks.tint)
		plans.set_tool(PlanEditor.Tool.WALL)
	_refresh_ladder()


## Échelle des étages : niveaux du bâtiment visé (ou vide) et étage actif.
func _refresh_ladder() -> void:
	build_panel.set_ladder(plans.level_counts(plans.active_id()), plans.level)


## Un outil de construction prend la main : on range ceux du terrain et des voies.
func _select_building_tool(from_transit := false) -> void:
	world.set_tool(TerrainWorld.Tool.INSPECT)
	landscape.set_shown(false)
	if decors_panel:
		decors_panel.set_shown(false)
	transport.stations.set_inactive()
	if transit_panel and not from_transit:
		transit_panel.clear_selection()
	transport.set_inactive()
	hud.show_spec("", {}, false)
	buildings.set_inactive()
	zones.set_inactive()
	blocks.set_inactive()
	plans.set_inactive()
	mobilier.set_inactive()
	if banque_pose:
		banque_pose.stop()
	hud.select_tool_silently(0)


## Décors (DecorSystem) et leur panneau (touche G).
func _setup_decors() -> void:
	decors = DecorSystem.new()
	decors.name = "Decors"
	add_child(decors)
	decors.setup(world, transport, buildings, ambiance)
	decors.message.connect(func(t: String) -> void: hud.show_message(t))
	decors.info_changed.connect(func(t: String) -> void: hud.set_tool_info(t))
	decors_panel = DecorPanel.new()
	decors_panel.name = "PanneauDecors"
	decors_panel.decors = decors
	add_child(decors_panel)
	hud.decors_requested.connect(toggle_decors)
	decors_panel.bascule_demandee.connect(toggle_decors)


## Ouvre ou ferme le panneau des décors (les autres outils sont rangés).
func toggle_decors() -> void:
	if decors_panel.visible:
		decors_panel.set_shown(false)
		return
	_select_building_tool()
	decors_panel.set_shown(true)


## Panneau « Paysage » : pinceaux de terrain (outil 0).
var landscape: PaysagePanel


func _setup_landscape() -> void:
	landscape = PaysagePanel.new()
	landscape.name = "PanneauPaysage"
	add_child(landscape)
	landscape.set_shown(false)
	landscape.tool_chosen.connect(func(t: int) -> void:
		if landscape.visible:
			world.set_tool(t))
	landscape.radius_changed.connect(func(r: int) -> void:
		world.brush_radius = r
		world._update_selection())
	landscape.biome_chosen.connect(func(k: int) -> void: world.paint_kind = k)
	world.brush_radius = landscape.radius
	world.paint_kind = landscape.kind


func _on_tool_selected(t: int) -> void:
	landscape.set_shown(t == TerreHud.LANDSCAPE_TOOL)
	if telecom:
		telecom.set_inactive()
	if decors_panel:
		decors_panel.set_shown(false)
	if banque_pose:
		banque_pose.stop()
	transport.stations.set_inactive()
	transit_panel.clear_selection()
	buildings.set_inactive()
	zones.set_inactive()
	blocks.set_inactive()
	plans.set_inactive()
	mobilier.set_inactive()
	build_panel.clear_selection()
	if t == TerreHud.LANDSCAPE_TOOL:
		transport.set_inactive()
		hud.show_spec("", {}, false)
		world.set_tool(landscape.current_tool)
		return
	var k := t - TerreHud.FIRST_TRANSPORT_TOOL
	if k < 0:
		transport.set_inactive()
		hud.show_spec("", {}, false)
		world.set_tool(t)
		return
	world.set_tool(TerrainWorld.Tool.INSPECT)
	if k < TRANSPORT_TOOLS.size():
		var default_id: String = TRANSPORT_TOOLS[k]
		transport.set_build(_tool_class.get(TransportTypes.mode_of(default_id), default_id))
	elif k == TRANSPORT_TOOLS.size():
		hud.show_spec("", {}, false)
		transport.set_demolish()
	else:
		hud.show_spec("", {}, false)
		transport.set_junction_tool()
		hud.show_junction_panel(transport.junction_action)


func _on_origin_changed(lat: float, lon: float) -> void:
	# Nouvelle région : réseau vierge, paliers de déblocage à zéro.
	ReglagesPartie.actuel.record_habitants = 0
	if evenements != null:
		evenements.clear()
	population.clear()
	production.clear()
	budget.clear()
	urgences.clear()
	telecom.clear()
	dechets.clear()
	resource_overlay.show_resource(resource_overlay.res)
	transport.clear()
	buildings.clear()
	zones.clear()
	blocks.clear()
	plans.clear()
	mobilier.clear()
	GameStart.lat = lat
	GameStart.lon = lon
	# Nouvelle région : nouvelle partie (load_game() remet son identifiant après).
	GameStart.slot_id = ""
	hud.set_place(lat, lon)
	rig.position = Vector3.ZERO
	_snap_pending = true
	hud.show_message("Chargement du relief réel autour de %.4f, %.4f…" % [lat, lon])


var _snap_pending := true


## Horloge de la vie (jours) : les arbres vieillissent comme les habitants, selon
## le réglage Admin « vitesse de la vie » (réglage Admin).
func _horloge_vie() -> float:
	return population.life_clock if population != null else NAN


func _process(delta: float) -> void:
	_autosave(delta)
	# Jour permanent automatique pendant la construction.
	ambiance.set_construction(build_panel.is_open() or blocks.tool != BlockEditor.Tool.NONE
		or (plans != null and plans.tool != PlanEditor.Tool.NONE))
	world.update_tide(ambiance.unix_time)
	world.update_saison(ambiance.unix_time, ambiance.weather, _horloge_vie())
	# Le pivot de la caméra suit le relief sous lui.
	var h := world.cell_height(Vector2i(floori(rig.position.x), floori(rig.position.z)))
	if not is_nan(h):
		var target := maxf(h, 0.0)
		if _snap_pending or absf(target - rig.position.y) > 60.0:
			rig.position.y = target
			_snap_pending = false
		else:
			rig.position.y = lerpf(rig.position.y, target, clampf(delta * 4.0, 0.0, 1.0))

	_status_timer -= delta
	if _status_timer <= 0.0:
		_status_timer = 0.3
		var t := world.tiles
		var s := "Blocs de 64 × 64 m affichés : %d   ·   Tuiles d'altitude : %d en mémoire" % [world.chunks.size(), t.loaded_count()]
		if t.pending_count() > 0:
			s += ", %d en téléchargement…" % t.pending_count()
		if t.failed_count() > 0:
			s += "   ·   %d tuile(s) introuvable(s) (pas de réseau ?)" % t.failed_count()
		s += "   ·   Cases modifiées : %d" % world.modifications.size()
		if Maree.amplitude(world.origin_lat, world.origin_lon) > 0.0:
			s += "   ·   " + Maree.describe(ambiance.unix_time, world.origin_lat, world.origin_lon)
		if world.water.status != "":
			s += "   ·   " + world.water.status
		hud.set_status(s)
		hud.set_network_info(transport.summary() + "   ·   " + population.summary() + "   ·   " + production.summary())
		build_panel.set_money("Caisse : illimitée" if buildings.unlimited_money else "Caisse : " + BuildingSystem.format_money(buildings.money))
		build_panel.set_summary(buildings.summary())
		build_panel.set_zone_info(zones.summary())
		build_panel.set_block_info(plans.summary() if build_panel.block_mode() == "plans" else blocks.summary())
		_stats_timer -= 0.3
		if _stats_timer <= 0.0:
			_stats_timer = 1.0
			_refresh_stats()
	_exclusive_panels()


var _stats_timer := 0.0
## Panneaux de droite ouverts à l'image précédente (pour n'en garder qu'un).
var _open_before := {}


## Construire, Lignes et Habitants partagent la même place à droite : quand
## l'un s'ouvre, les autres se ferment. Leur bouton de la barre du bas s'allume.
func _exclusive_panels() -> void:
	var panels := {"construire": build_panel, "lignes": transit_panel, "habitants": habitants_panel, "production": production_panel, "urgences": urgences_panel, "dechets": dechets_panel, "budget": budget_panel, "telecom": telecom_panel, "perso": perso_panel, "infos": evenements_panel, "cartes": cartes_panel}
	var opened := ""
	for id in panels:
		var p = panels[id]
		var on: bool = p != null and p.is_open()
		if on and not _open_before.get(id, false):
			opened = id
		_open_before[id] = on
	if opened != "":
		for id in panels:
			if id != opened and _open_before[id]:
				panels[id].set_open(false)
				_open_before[id] = false
	for id in panels:
		hud.set_panel_open(id, _open_before[id])
	# Mode Créer : panneau fermé (B, croix) = plus de catégorie allumée.
	if hud.create_mode and not build_panel.is_open() and hud.create_category() != "":
		hud.set_create_category("")


## Chiffres de la ville dans la barre du haut : caisse, habitants, satisfaction, chômage.
func _refresh_stats() -> void:
	var money := "Illimitée" if buildings.unlimited_money else BuildingSystem.format_money(buildings.money)
	var s := population.stats()
	var palier := ReglagesPartie.actuel.note_population(int(s.habitants))
	if palier != "" and ReglagesPartie.actuel.deblocage == "progression":
		hud.show_message("Palier « %s » atteint : de nouveaux bâtiments sont débloqués !" % palier)
		build_panel.refresh()
	var adults: int = int(s.actif) + int(s.chomeur)
	var unemployment := "—" if adults == 0 else "%d %%" % roundi(100.0 * int(s.chomeur) / adults)
	hud.set_stats(money, int(s.habitants), int(s.satisfaction), unemployment)


func _refresh_cell_info() -> void:
	if not _hover_valid:
		hud.set_cell_info("Survole le terrain pour voir une case.")
		return
	var h := world.cell_height(_hover)
	if is_nan(h):
		hud.set_cell_info("Case %d, %d : relief en cours de chargement…" % [_hover.x, _hover.y])
		return
	var ll := world.local_to_lat_lon(_hover.x + 0.5, _hover.y + 0.5)
	var kind := world.cell_kind_at(_hover)
	var real := world.raw_height(_hover.x + 0.5, _hover.y + 0.5)
	var txt := "Case %d, %d   ·   %s" % [_hover.x, _hover.y, kind]
	var river := world.water_name_at(_hover)
	if river != "":
		txt += " (%s)" % river
	txt += "\nHauteur %.1f m (réelle %.1f m)   ·   %.5f, %.5f" % [h, real, ll.x, ll.y]
	if world.modifications.has(_hover):
		txt += "   ·   modifiée"
	# Ressources sous la case (les plus riches).
	var rich := production.carte.all_at(_hover)
	var best: Array = []
	for res in rich:
		if float(rich[res]) >= 0.15:
			best.append([res, float(rich[res])])
	best.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1])
	if not best.is_empty():
		var parts: Array[String] = []
		for e in best.slice(0, 3):
			parts.append("%s %d %%" % [String(Ressources.naturelle(e[0]).name).to_lower(), roundi(e[1] * 100.0)])
		txt += "\nRessources : " + ", ".join(parts)
	if nuisances != null:
		var p := Vector3(_hover.x + 0.5, h, _hover.y + 0.5)
		var f := nuisances.au_point(p)
		txt += "\nAir %d %% · Eau %d %% · Bruit %d dB (nuit %d dB) · Terrain %s €/m²" % [roundi(100.0 * float(f.air)),
			roundi(100.0 * float(f.eau)), Nuisances.decibels(float(f.bruit)), Nuisances.decibels(float(f.nuit)),
			BuildingSystem.format_money(roundi(Nuisances.PRIX_M2 * nuisances.valeur_de(f, p))).replace(" €", "")]
	hud.set_cell_info(txt)
