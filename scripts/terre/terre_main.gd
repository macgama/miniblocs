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

## Voie posée par défaut par chaque outil (le joueur change la classe dans le panneau) :
## une rue de village pour la route (moins de bruit et de pollution qu'une départementale).
const TRANSPORT_TOOLS := ["rue", "train", "voie_verte", "canal"]
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
## Agriculture : champs, travaux, machines, élevage et repas (Maj+F).
var agriculture: Agriculture
var agri_panel: AgriPanel
var agri_visuels: AgriVisuels
var resource_overlay: RessourcesOverlay
## Carrières et mines : fosses qui se creusent, verses, sondages (P → Mines).
var carrieres: Carrieres
## Services d'urgence : pompiers, ambulances, police sur les routes (touche U).
var urgences: Urgences
var urgences_panel: UrgencesPanel
## Réseaux : électricité, eau potable, égouts (touche O).
var reseaux: Reseaux
var reseaux_panel: ReseauxPanel
## Trafic : bouchons, stationnement, affluence des lignes (Maj + L).
var trafic: Trafic
var trafic_panel: TraficPanel
var trafic_overlay: TraficOverlay
## Compte d'exploitation des lignes : achats, vieillissement, recettes et coûts (panneau L).
var lignes_eco: ExploitationLignes
var services: ServicesPublics
var services_panel: ServicesPanel
var education_panel: EducationPanel
## Budget de la commune : impôts, emprunts, entretien et usure des voies (touche M).
var budget: BudgetCommunal
var budget_panel: BudgetPanel
## Déchets : collecte, décharges, tri et recyclage (touche X).
var dechets: Dechets
## Saisons, neige et déneigement, crues, sécheresse, canicule (Maj+R).
var saisons: Saisons
var sante: SantePublique
var sante_panel: SantePanel
var saisons_panel: SaisonsPanel
## Climat et pollution : bilan carbone, réchauffement, mer, sols pollués, plan climat (Maj+F7).
var climat: Climat
var climat_panel: ClimatPanel
var dechets_panel: DechetsPanel
## Parc de loisirs : attractions, visiteurs, files, billets, note (Maj+G).
var musee: Musee
var spectacles: Spectacles
var spectacles_panel: SpectaclesPanel
var club: ClubSport
## Toutes les sections du club (sport → ClubSport), football compris.
var clubs: Dictionary = {}
var club_supporters: ClubSupporters
var club_panel: ClubPanel
var musee_panel: MuseePanel
var parc: ParcLoisirs
var parc_panel: ParcPanel
## Zoo : enclos, animaux, soigneurs, visiteurs (Maj+Z, menu Loisirs).
var zoo: ZooSysteme
var zoo_panel: ZooPanel
## Tourisme : hébergements, touristes, dépenses en ville (menu Loisirs, Maj+R).
var tourisme: Tourisme
var tourisme_panel: TourismePanel
## Patrimoine : classement, abords, entretien, grands monuments (touche Fin).
var patrimoine: Patrimoine
var patrimoine_panel: PatrimoinePanel
## Commerce entre villes et pays : cours mondiaux, accords, crises (Économie, Maj+S).
var commerce_mondial: CommerceMondial
var commerce_panel: CommercePanel
var zoo_outils: ZooOutils
## Obsèques, cimetières, crématorium, pompes funèbres (onglet Funéraire du panneau H).
var funeraire: Funeraire
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
## Éditeur du parc (Maj+A) : attractions sur voie, allées et files, décors à thème.
var attractions: AttractionsPerso
var parc_allees: ParcAllees
var parc_editeur_panel: ParcEditeurPanel
## Événements : fêtes, marchés, matchs, incendies, tempêtes, épidémies (touche I).
var evenements: Evenements
var evenements_panel: EvenementsPanel
## Avis des habitants, élections, manifestations (/root/Avis, panneau Y).
var avis: Avis
var avis_panel: AvisPanel
var avis_carte: AvisCarte
var actualites: Actualites
## Internet et téléphone : antennes, centraux, cuivre et fibre (Maj + O, scripts/reseaux).
var telecom: Telecom
## Niveaux de vie des foyers (Maj+N) : besoins, montée, effets sur les impôts et les achats.
var niveaux_vie: NiveauxVie
var niveaux_vie_panel: NiveauxViePanel
var telecom_panel: TelecomPanel
## Pollution de l'air et de l'eau, bruit, valeur des terrains et loyers.
var nuisances: Nuisances
## Agrandissements (3 niveaux), rénovations et densification du zonage.
var ameliorations: Ameliorations
## Immobilier vivant (F11) : prix, promoteurs, gentrification, bidonvilles, logements sociaux.
var immobilier: Immobilier
var immobilier_panel: ImmobilierPanel
## Panneau « Cartes » (touche N) : cartes de couleur de tous les systèmes.
var cartes_panel: CartesPanel
## Villages du joueur et leur territoire (Maj+M, scripts/communes).
var communes: Communes
var villages_panel: VillagesPanel
var fondateurs: Fondateurs
var fondateurs_panel: FondateursPanel
var pays: Pays
var pays_panel: PaysPanel
var pilote: PiloteAuto
var objectifs: Objectifs
var kit: KitInstallation
var rue_fondation: RueFondation
var objectifs_panel: ObjectifsPanel
var statistiques: Statistiques
var stats_panel: StatsPanel
var journal: Journal
var journal_panel: JournalPanel
## Tutoriel guidé et objectifs à l'écran (scripts/tutoriel).
var tutoriel: Tutoriel
var tuto_carte: TutorielCarte
## Scénario en cours (menu principal → Scénarios) et sa carte à l'écran.
var scenario: ScenarioPartie
var scenario_carte: ScenarioCarte
var bilan_scenario: ScenarioBilan
## Ambiances sonores selon la caméra (scripts/son) ; musique et volumes : /root/Son (F2).
var sons: AmbiancesSonores
var quartiers: Quartiers
var quartiers_panel: QuartiersPanel
## Mode photo (F8) et time-lapse de la ville (Maj+F8), scripts/photo.
var mode_photo: ModePhoto
var timelapse: TimeLapse
var mode_streamer: ModeStreamer
var streamer_panel: StreamerPanel
var timelapse_panel: TimeLapsePanel


func _ready() -> void:
	OptionsJeu.appliquer(get_tree())
	var jp := get_node_or_null("/root/Plantages")
	if jp != null:
		jp.etat_partie = etat_pour_rapport
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
	_setup_agriculture()
	_setup_budget()
	_setup_urgences()
	_setup_reseaux()
	_setup_trafic()
	_setup_services()
	_setup_education()
	_setup_telecom()
	_setup_dechets()
	_setup_musee()
	_setup_spectacles()
	_setup_club()
	_setup_parc()
	_setup_funeraire()
	_setup_vie()
	_setup_decors()
	_setup_zoo()
	_setup_tourisme()
	_setup_evenements()
	_setup_saisons()
	_setup_sante()
	_setup_nuisances()
	_setup_climat()
	_setup_avis()
	_setup_parc_editeur()
	_setup_partage()
	_setup_communes()
	_setup_fondateurs()
	_setup_pays()
	_setup_commerce()
	_setup_patrimoine()
	_setup_niveaux_vie()
	_setup_immobilier()
	_setup_statistiques()
	_setup_journal()
	_setup_tutoriel()
	_setup_scenario()
	_setup_edition_demo()
	_setup_quartiers()
	_setup_souterrain()
	_setup_create_mode()
	_setup_son()
	_setup_photo()
	_setup_streamer()
	_setup_succes()
	_setup_visites()
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
	build_panel.block_orient.connect(func(action: String) -> void:
		if action == "tourner":
			blocks.rotate_step()
		elif action == "renverser":
			blocks.flip_step()
		elif action == "coucher":
			blocks.lay_step()
		else:
			blocks.reset_orientation())
	build_panel.block_tint_chosen.connect(func(t: int) -> void:
		blocks.set_tint(t)
		plans.set_tint(t))
	build_panel.capture_name_changed.connect(func(n: String) -> void: blocks.capture_name = n)
	build_panel.creation_deleted.connect(func(id: String) -> void: Creations.remove(id))
	blocks.captured.connect(func(res: Dictionary) -> void:
		if res.ok:
			blocks.set_tool(BlockEditor.Tool.NONE)
			build_panel.clear_selection())
	build_panel.block_piece_changed.connect(func(d: int, n: int) -> void: blocks.set_piece(d, n))
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
	for sig in [world.terrain_edited, transport.network_changed, buildings.changed, zones.changed, blocks.changed, plans.changed, transport.stations.lines_changed, transport.junctions.changed, population.changed, production.changed, agriculture.changed, mobilier.changed, evenements.changed, decors.changed]:
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
			if slot == VisiteVille.SLOT:
				VisiteVille.oublier()
	if GameStart.atelier:
		_start_atelier.call_deferred()
	if VisiteVille.active() and not VisiteVille.en_ligne:
		_debut_visite()
	# Nouvelle partie : on commence par fonder le village (le tutoriel le
	# propose lui-même, après le tour de la caméra).
	if communes.fondation_requise() and not tutoriel.actif and Multijoueur.role != Multijoueur.Role.SERVEUR and not VisiteVille.active():
		get_tree().create_timer(1.5).timeout.connect(func() -> void:
			if communes.fondation_requise() and not villages_panel._dialog.visible and not tutoriel.actif and not VisiteVille.active():
				villages_panel.demander_nom())
	# Carte entre amis : ce jeu est le serveur, ou un joueur connecté (scripts/multijoueur).
	Multijoueur.attacher(self)


# --- Sauvegarde -------------------------------------------------------------------

## Message de la dernière erreur de sauvegarde ou de chargement.
var last_error := ""
## Des changements depuis la dernière sauvegarde (pour la sauvegarde automatique).
var _unsaved := false
var _autosave_timer := 0.0
## Durée de la dernière sauvegarde automatique (ms), pour le rapport de plantage et les bancs.
var derniere_autosave_ms := 0
## Sauvegarde automatique (toutes les 5 minutes par défaut, Options > Jeu), dans une partie à part.
## Première des sauvegardes automatiques tournantes (SaveGame.autosave_slots()).
const AUTOSAVE_SLOT := SaveGame.AUTO_SLOT
const AUTOSAVE_INTERVAL := 300.0
var _saves_panel: PartiesPanel


func _game_title() -> String:
	if GameStart.place_name != "":
		return GameStart.place_name
	return "Région %.3f, %.3f" % [world.origin_lat, world.origin_lon]


## Sections de la sauvegarde : uniquement ce que le joueur a créé ou changé.
func save_sections() -> Dictionary:
	var sec := {"terrain": world.to_dict(), "transport": transport.to_dict(), "batiments": buildings.to_dict(),
		"zones": zones.to_dict(), "blocs": blocks.to_dict(), "plans": plans.to_dict(), "ambiance": ambiance.to_dict(),
		"creations": Creations.to_dict(Creations.used_by(buildings)),
		"modeles_jeu": ModelesJeu.to_dict(buildings),
		"modeles_visites": modeles_visites.to_dict(),
		"personnage": ($VueSol as VueSol).to_dict(), "habitants": population.to_dict(), "mobilier": mobilier.to_dict(),
		"production": production.to_dict(), "agriculture": agriculture.to_dict(), "urgences": urgences.to_dict(), "reseaux": reseaux.to_dict(), "dechets": dechets.to_dict(), "funeraire": funeraire.to_dict(), "trafic": trafic.to_dict(), "lignes_eco": lignes_eco.to_dict(), "reglages": _settings_snapshot().to_dict(), "budget": budget.to_dict(), "evenements": evenements.to_dict(), "saisons": saisons.to_dict(), "decors": decors.to_dict(),
		"nuisances": nuisances.to_dict(), "telecom": telecom.to_dict(), "services": services.to_dict(), "carrieres": carrieres.to_dict(),
		"souterrain": construction_souterraine.to_dict()}
	sec["ameliorations"] = ameliorations.to_dict()
	sec["avis"] = avis.to_dict()
	sec["communes"] = communes.to_dict()
	sec["fondateurs"] = fondateurs.to_dict()
	sec["pays"] = pays.to_dict()
	sec["pilote"] = pilote.to_dict()
	sec["objectifs"] = objectifs.to_dict()
	sec["kit"] = kit.to_dict()
	sec["rue_fondation"] = rue_fondation.to_dict()
	sec["niveaux_vie"] = niveaux_vie.to_dict()
	sec["immobilier"] = immobilier.to_dict()
	sec["statistiques"] = statistiques.to_dict()
	sec["journal"] = journal.to_dict()
	sec["tutoriel"] = tutoriel.to_dict()
	sec["scenario"] = scenario.to_dict()
	sec["musee"] = musee.to_dict()
	sec["spectacles"] = spectacles.to_dict()
	sec["club"] = club.to_dict()
	sec["climat"] = climat.to_dict()
	var autres := {}
	for s in clubs:
		if s != "football" and (clubs[s] as ClubSport).fonde():
			autres[s] = (clubs[s] as ClubSport).to_dict()
	sec["clubs_sports"] = autres
	sec["parc"] = parc.to_dict()
	sec["zoo"] = zoo.to_dict()
	sec["tourisme"] = tourisme.to_dict()
	sec["patrimoine"] = patrimoine.to_dict()
	sec["commerce_mondial"] = commerce_mondial.to_dict()
	sec["quartiers"] = quartiers.to_dict()
	sec["sante"] = sante.to_dict()
	sec["parc_editeur"] = attractions.to_dict()
	sec["parc_allees"] = parc_allees.to_dict()
	sec["timelapse"] = timelapse.to_dict()
	sec["streamer"] = mode_streamer.to_dict()
	sec["edition_demo"] = limite_demo.to_dict()
	sec["courrier"] = courrier.to_dict()
	# Serveur de carte entre amis : membres, code d'invitation, caisses personnelles.
	if Multijoueur.role == Multijoueur.Role.SERVEUR:
		sec["multijoueur"] = Multijoueur.section()
	return sec


## Sauvegarde dans la partie en cours (ou une nouvelle). title : nom d'une nouvelle partie.
func save_game(slot := "", title := "") -> bool:
	# En visite : la ville d'un autre ne se sauvegarde pas (la copie est jetée à la fin).
	if VisiteVille.active():
		last_error = "en visite, la ville d'un autre ne se sauvegarde pas"
		return false
	if slot == "":
		slot = GameStart.slot_id if not SaveGame.est_autosave(GameStart.slot_id) else ""
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
	if not SaveGame.est_autosave(slot):
		GameStart.slot_id = slot
	_unsaved = false
	_autosave_timer = 0.0
	capture_preview(slot)
	return true


## Aperçu de la partie pour l'écran Charger : la vue de la caméra, sans l'interface,
## rendue une fois dans une petite fenêtre à part (pas de clignotement à l'écran).
func capture_preview(slot: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var sv := SubViewport.new()
	sv.size = SaveGame.PREVIEW_SIZE * 2
	sv.world_3d = get_viewport().find_world_3d()
	sv.render_target_update_mode = SubViewport.UPDATE_ONCE
	sv.process_mode = Node.PROCESS_MODE_ALWAYS
	var c := Camera3D.new()
	c.fov = cam.fov
	c.near = cam.near
	c.far = cam.far
	c.environment = cam.environment
	c.attributes = cam.attributes
	sv.add_child(c)
	add_child(sv)
	c.global_transform = cam.global_transform
	c.current = true
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	if is_instance_valid(sv):
		SaveGame.save_preview(slot, sv.get_texture().get_image())
		sv.queue_free()


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
	Multijoueur.section_chargee = sec.get("multijoueur", {})
	_chargement = true
	journal.ecoute = false
	var lieu: Dictionary = m.get("lieu", {})
	GameStart.place_name = String(lieu.get("nom", ""))
	world.from_dict(sec.terrain)
	# Les bâtiments rechargés ne fondent pas de village : les villages ont leur section.
	communes.ignorer = true
	pays.capital_auto = false
	transport.from_dict(sec.get("transport", {}))
	Creations.adopt(sec.get("creations", {}))
	ModelesJeu.adopt(sec.get("modeles_jeu", {}))
	AttractionsPerso.adopt(sec.get("parc_editeur", {}))
	buildings.from_dict(sec.get("batiments", {}))
	zones.from_dict(sec.get("zones", {}))
	ameliorations.from_dict(sec.get("ameliorations", {}))
	blocks.from_dict(sec.get("blocs", {}))
	# Murs fins et meubles avant les habitants : ils y vivent et y travaillent.
	plans.from_dict(sec.get("plans", {}))
	mobilier.from_dict(sec.get("mobilier", {}))
	modeles_visites.from_dict(sec.get("modeles_visites", {}))
	population.from_dict(sec.get("habitants", {}))
	production.from_dict(sec.get("production", {}))
	carrieres.from_dict(sec.get("carrieres", {}))
	agriculture.from_dict(sec.get("agriculture", {}))
	budget.from_dict(sec.get("budget", {}))
	decors.from_dict(sec.get("decors", {}))
	parc_allees.from_dict(sec.get("parc_allees", {}))
	attractions.from_dict(sec.get("parc_editeur", {}))
	urgences.from_dict(sec.get("urgences", {}))
	reseaux.from_dict(sec.get("reseaux", {}))
	trafic.from_dict(sec.get("trafic", {}))
	lignes_eco.from_dict(sec.get("lignes_eco", {}))
	services.from_dict(sec.get("services", {}))
	telecom.from_dict(sec.get("telecom", {}))
	construction_souterraine.from_dict(sec.get("souterrain", {}))
	dechets.from_dict(sec.get("dechets", {}))
	musee.from_dict(sec.get("musee", {}))
	spectacles.from_dict(sec.get("spectacles", {}))
	club.from_dict(sec.get("club", {}))
	var autres: Dictionary = sec.get("clubs_sports", {})
	for s in clubs:
		if s != "football":
			(clubs[s] as ClubSport).from_dict(autres.get(s, {}))
	club_supporters.refresh(true)
	parc.from_dict(sec.get("parc", {}))
	zoo.from_dict(sec.get("zoo", {}))
	tourisme.from_dict(sec.get("tourisme", {}))
	patrimoine.from_dict(sec.get("patrimoine", {}))
	commerce_mondial.from_dict(sec.get("commerce_mondial", {}))
	funeraire.from_dict(sec.get("funeraire", {}))
	ambiance.from_dict(sec.get("ambiance", {}))
	# Après les bâtiments et les habitants : dégâts, ruines, malades, matchs.
	evenements.from_dict(sec.get("evenements", {}))
	saisons.from_dict(sec.get("saisons", {}))
	climat.from_dict(sec.get("climat", {}))
	sante.from_dict(sec.get("sante", {}))
	communes.ignorer = false
	if sec.has("communes"):
		communes.from_dict(sec.communes)
	else:
		# Ancienne partie : un village autour de la ville déjà construite.
		communes.clear()
		communes.actif = not GameStart.atelier
		communes.adopter_ancienne_partie()
	# Après les villages et le budget : une caisse par ville (sans section : ancienne partie).
	pays.from_dict(sec.get("pays", {}))
	pays.capital_auto = true
	pilote.from_dict(sec.get("pilote", {}))
	# Après les bâtiments, les habitants et les villages.
	fondateurs.from_dict(sec.get("fondateurs", {}))
	avis.from_dict(sec.get("avis", {}))
	# Après les villages, le pays et les élections (mairies perdues).
	objectifs.from_dict(sec.get("objectifs", {}))
	kit.from_dict(sec.get("kit", {}))
	rue_fondation.from_dict(sec.get("rue_fondation", {}))
	# Après les villages, le pays et les élections (quartiers d'une mairie perdue).
	quartiers.from_dict(sec.get("quartiers", {}))
	nuisances.from_dict(sec.get("nuisances", {}))
	# Après les habitants : niveau de chaque foyer (ancienne partie : évalués au premier jour).
	niveaux_vie.from_dict(sec.get("niveaux_vie", {}))
	# Après les bâtiments et les habitants : bidonvilles, logements de standing, prix.
	immobilier.from_dict(sec.get("immobilier", {}))
	statistiques.from_dict(sec.get("statistiques", {}))
	# Après les villages : une partie d'avant le time-lapse filme ses villages dès maintenant.
	if sec.has("timelapse"):
		timelapse.from_dict(sec.timelapse)
	else:
		timelapse.clear()
		timelapse.adopter_villages()
	if sec.has("streamer"):
		mode_streamer.from_dict(sec.streamer)
	else:
		mode_streamer.clear()
	journal.from_dict(sec.get("journal", {}))
	($VueSol as VueSol).from_dict(sec.get("personnage", {}))
	_load_settings(sec.get("reglages", {}), m)
	# Après les réglages : une partie d'avant le tutoriel n'en a pas.
	limite_demo.from_dict(sec.get("edition_demo", {}))
	courrier.from_dict(sec.get("courrier", {}))
	if sec.has("tutoriel"):
		tutoriel.from_dict(sec.tutoriel)
	else:
		tutoriel.clear()
	ReglagesPartie.actuel.tutoriel = tutoriel.actif
	# Après les réglages : le scénario compare les réglages du départ à ceux-ci.
	scenario.from_dict(sec.get("scenario", {}))
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
	_chargement = false
	journal.ecoute = true
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
		tutoriel.set_actif(ReglagesPartie.actuel.tutoriel)
		if Multijoueur.client_actif() != null and Multijoueur.role == Multijoueur.Role.CLIENT:
			Multijoueur.client.reglages_changes()
		_unsaved = true)
	_admin.caisse_set.connect(func(v: int) -> void:
		if Multijoueur.client_actif() != null and Multijoueur.role == Multijoueur.Role.CLIENT:
			Multijoueur.client.envoyer_admin("caisse", {"v": v})
		buildings.money = v
		_unsaved = true
		hud.show_message("Caisse mise à %s." % BuildingSystem.format_money(v)))
	_windows_layer().add_child(_admin)


## Réseaux : électricité, eau, égouts, leurs tronçons et le panneau (O).
func _setup_reseaux() -> void:
	reseaux = Reseaux.new()
	reseaux.name = "Reseaux"
	add_child(reseaux)
	reseaux.setup(world, buildings, transport, population, production, ambiance)
	reseaux.message.connect(func(t: String) -> void: hud.show_message(t))
	reseaux.info_changed.connect(func(t: String) -> void: hud.set_tool_info(t))
	reseaux_panel = ReseauxPanel.new()
	reseaux_panel.name = "PanneauReseaux"
	add_child(reseaux_panel)
	reseaux_panel.setup(reseaux)
	reseaux.panneau = reseaux_panel
	reseaux_panel.focus_requested.connect(func(pos: Vector3) -> void:
		rig.position.x = pos.x
		rig.position.z = pos.z)


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
	buildings.changed.connect(func() -> void: population.demander_sync())
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


## Climat et pollution (Maj+F7, menu Infos) : bilan carbone, réchauffement qui décale
## la météo, montée de la mer, sols pollués (carte N), mix électrique, plan climat.
func _setup_climat() -> void:
	climat = Climat.new()
	add_child(climat)
	climat.setup(world, buildings, transport, population, ambiance, reseaux, agriculture, evenements)
	climat.message.connect(func(t: String) -> void: hud.show_message(t))
	climat.changed.connect(func() -> void: _unsaved = true)
	climat_panel = ClimatPanel.new()
	climat_panel.name = "PanneauClimat"
	add_child(climat_panel)
	climat_panel.setup(climat)
	climat_panel.focus_requested.connect(func(pos: Vector3) -> void:
		rig.position.x = pos.x
		rig.position.z = pos.z)
	hud.climat_requested.connect(func() -> void: climat_panel.toggle())
	var c := CalqueCouleur.new()
	c.name = "CalqueSols"
	c.world = world
	c.focus = rig
	c.degrade = CalqueCouleur.degrade_nuisance()
	c.seuil = 0.03
	add_child(c)
	var cm := climat
	c.valeur = func(x: float, z: float) -> float:
		var v := cm.sol_at(x, z)
		return v if v >= 0.03 else -1.0
	climat.changed.connect(c.rafraichir)
	Calques.ajouter("climat_sols", "Sols pollués", "Nuisances", c.montrer,
		"pollution qui reste dans la terre pendant des années : usines, mines, décharges, pesticides (du jaune au violet).")
## Santé publique : hygiène, vaccins, mesures sanitaires, grandes épidémies
## de l'histoire (choléra de 1832, grippe de 1918…) ; panneau F7 (menu Infos).
func _setup_sante() -> void:
	sante = SantePublique.new()
	add_child(sante)
	sante.setup(evenements, population, buildings)
	sante.message.connect(func(t: String) -> void:
		if not _chargement:
			hud.show_message(t))
	sante_panel = SantePanel.new()
	sante_panel.name = "PanneauSante"
	add_child(sante_panel)
	sante_panel.setup(sante)
	sante_panel.focus_requested.connect(func(pos: Vector3) -> void:
		rig.position.x = pos.x
		rig.position.z = pos.z)
	hud.sante_requested.connect(func() -> void: sante_panel.toggle())


## Saisons et risques naturels : relevés et prévisions, neige sur les routes et
## chasse-neige, crues, sécheresse, canicule, gel ; panneau Maj+R (menu Infos).
func _setup_saisons() -> void:
	saisons = Saisons.new()
	add_child(saisons)
	saisons.setup(world, ambiance, transport, buildings, population, evenements, agriculture)
	saisons.message.connect(func(t: String) -> void: hud.show_message(t))
	saisons.changed.connect(func() -> void: _unsaved = true)
	saisons_panel = SaisonsPanel.new()
	saisons_panel.name = "PanneauSaisons"
	add_child(saisons_panel)
	saisons_panel.setup(saisons)
	saisons_panel.focus_requested.connect(func(pos: Vector3) -> void:
		rig.position.x = pos.x
		rig.position.z = pos.z)
	saisons_panel.build_requested.connect(func(id: String) -> void:
		_select_building_tool()
		buildings.set_place(id))
	hud.saisons_requested.connect(func() -> void: saisons_panel.toggle())


## Avis des habitants (satisfaction par thème, quartiers, paroles), élections
## municipales et manifestations : nœud /root/Avis, panneau Avis (Y), carte.
func _setup_avis() -> void:
	avis = Avis.new()
	avis.setup(population, buildings, transport, ambiance, world, evenements)
	Avis.instance = avis
	get_tree().root.add_child.call_deferred(avis)
	tree_exiting.connect(func() -> void:
		if is_instance_valid(avis):
			avis.queue_free())
	avis.changed.connect(func() -> void: _unsaved = true)
	avis_carte = AvisCarte.new()
	add_child(avis_carte)
	avis_carte.setup(avis)
	avis_panel = AvisPanel.new()
	avis_panel.name = "PanneauAvis"
	add_child(avis_panel)
	avis_panel.setup(avis, avis_carte)
	avis_panel.focus_requested.connect(func(pos: Vector3) -> void:
		rig.position.x = pos.x
		rig.position.z = pos.z)
	avis_panel.person_requested.connect(func(pid: int) -> void:
		habitants_panel.set_open(true)
		habitants_panel.show_view("profil", pid))
	hud.avis_requested.connect(func() -> void: avis_panel.toggle())
	avis.defaite_finale.connect(_on_defaite_finale)


## Villages et territoire (Maj+M) : fondation, frontières, agrandissement, règles
## de construction (bâtiments et zonage sur le territoire, voies avant fondation).
func _setup_communes() -> void:
	communes = Communes.new()
	communes.name = "Communes"
	add_child(communes)
	communes.setup(world, buildings, zones, population)
	# Partie lancée depuis le globe : on commence par fonder un village.
	communes.actif = GameStart.chosen and not GameStart.atelier
	communes.message.connect(func(t: String) -> void: hud.show_message(t))
	communes.changed.connect(func() -> void: _unsaved = true)
	var prev: Callable = buildings.extra_check
	buildings.extra_check = func(id: String, rect: Rect2i) -> Dictionary:
		var why := communes.raison_batiment(id, rect)
		if why != "":
			return {"reason": why}
		var res: Dictionary = prev.call(id, rect) if prev.is_valid() else {}
		var ctr := Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y + rect.size.y * 0.5)
		if String(res.get("reason", "")) == "" and Communes.est_fondateur(id) and communes.village_au_point(ctr.x, ctr.y) < 0:
			var info := "Fonde le village « %s »." % (communes.nom_en_attente if communes.nom_en_attente != "" else communes.nom_auto())
			res["info"] = (String(res.get("info", "")) + "  " + info).strip_edges()
		return res
	zones.area_check = communes.raison_zone
	transport.build_gate = communes.raison_voie
	Calques.ajouter("territoires", "Territoires des villages", "Villages", func(on: bool) -> void: communes.calque = on,
		"une couleur par village · muret : frontière · carrés de 100 m")
	villages_panel = VillagesPanel.new()
	villages_panel.name = "PanneauVillages"
	add_child(villages_panel)
	villages_panel.setup(communes)
	villages_panel.focus_requested.connect(func(pos: Vector3) -> void:
		rig.position.x = pos.x
		rig.position.z = pos.z)
	villages_panel.fonder_requested.connect(func(nom: String) -> void:
		if hud.create_mode:
			set_create_mode(false)
		_select_building_tool()
		buildings.set_place("maison_commune")
		hud.show_message("Clique où poser la Maison de commune de %s (R pour tourner, clic droit pour annuler)." % nom))
	hud.villages_requested.connect(func() -> void: villages_panel.toggle())


## Fondateurs du village (Maj+H) : ils arrivent avec le premier village, campent
## près de la Maison de commune et font les premiers chantiers.
func _setup_fondateurs() -> void:
	fondateurs = Fondateurs.new()
	fondateurs.name = "Fondateurs"
	add_child(fondateurs)
	fondateurs.setup(buildings, population, communes, vie_batiments, chantiers, ambiance)
	zones.peut_pousser = fondateurs.accepte_chantier_prive
	fondateurs.message.connect(func(t: String) -> void: hud.show_message(t))
	fondateurs.changed.connect(func() -> void: _unsaved = true)
	fondateurs_panel = FondateursPanel.new()
	fondateurs_panel.name = "PanneauFondateurs"
	add_child(fondateurs_panel)
	fondateurs_panel.setup(fondateurs)
	fondateurs_panel.focus_requested.connect(func(pos: Vector3) -> void:
		rig.position.x = pos.x
		rig.position.z = pos.z)
	hud.fondateurs_requested.connect(func() -> void: fondateurs_panel.toggle())


## Pays (Maj+P) : une caisse par ville, la caisse du pays, subventions.
func _setup_pays() -> void:
	pays = Pays.new()
	pays.name = "Pays"
	add_child(pays)
	pays.setup(buildings, communes, population, budget, transport.network)
	pays.foyer = func() -> Vector2: return Vector2(rig.position.x, rig.position.z)
	pays.message.connect(func(t: String) -> void: hud.show_message(t))
	pays.changed.connect(func() -> void: _unsaved = true)
	pilote = PiloteAuto.new()
	pilote.name = "PiloteAuto"
	add_child(pilote)
	pilote.setup(buildings, transport, zones, communes, population, pays, world)
	pilote.message.connect(func(t: String) -> void: hud.show_message(t))
	pilote.changed.connect(func() -> void: _unsaved = true)
	pays_panel = PaysPanel.new()
	pays_panel.name = "PanneauPays"
	add_child(pays_panel)
	pays_panel.setup(pays)
	pays_panel.focus_requested.connect(func(pos: Vector3) -> void:
		rig.position.x = pos.x
		rig.position.z = pos.z)
	hud.pays_requested.connect(func() -> void: pays_panel.toggle())
	kit = KitInstallation.new()
	kit.name = "KitInstallation"
	add_child(kit)
	kit.setup(buildings, communes, fondateurs, world)
	# Badge « Offert par l'État » du catalogue B à jour quand un bon sert.
	kit.changed.connect(func() -> void: build_panel.refresh.call_deferred())
	kit.message.connect(func(t: String) -> void: hud.show_message(t))
	kit.changed.connect(func() -> void: _unsaved = true)
	# Rue en T offerte devant chaque nouvelle Maison de commune (réglage Admin).
	rue_fondation = RueFondation.new()
	rue_fondation.name = "RueFondation"
	add_child(rue_fondation)
	rue_fondation.setup(transport, buildings, communes)
	rue_fondation.message.connect(func(t: String) -> void: hud.show_message(t))
	rue_fondation.changed.connect(func() -> void: _unsaved = true)
	objectifs = Objectifs.new()
	objectifs.name = "Objectifs"
	add_child(objectifs)
	objectifs.setup(communes, population, pays, buildings, transport)
	objectifs.message.connect(func(t: String) -> void: hud.show_message(t))
	objectifs.changed.connect(func() -> void: _unsaved = true)
	objectifs_panel = ObjectifsPanel.new()
	objectifs_panel.name = "PanneauObjectifs"
	add_child(objectifs_panel)
	objectifs_panel.setup(objectifs)
	objectifs_panel.focus_requested.connect(func(pos: Vector3) -> void:
		rig.position.x = pos.x
		rig.position.z = pos.z)
	hud.objectifs_requested.connect(func() -> void: objectifs_panel.toggle())


## Niveaux de vie (Maj+N) : les foyers montent de « Précaire » à « Très aisé »
## quand leurs besoins sont couverts ; carte « Niveaux de vie » dans les Cartes (N).
func _setup_niveaux_vie() -> void:
	niveaux_vie = NiveauxVie.new()
	niveaux_vie.name = "NiveauxVie"
	add_child(niveaux_vie)
	niveaux_vie.setup(population, production, buildings, telecom)
	niveaux_vie.message.connect(func(t: String) -> void: hud.show_message(t))
	niveaux_vie.changed.connect(func() -> void: _unsaved = true)
	niveaux_vie_panel = NiveauxViePanel.new()
	niveaux_vie_panel.name = "PanneauNiveauxVie"
	add_child(niveaux_vie_panel)
	niveaux_vie_panel.setup(niveaux_vie)
	niveaux_vie_panel.person_requested.connect(func(pid: int) -> void:
		habitants_panel.set_open(true)
		habitants_panel.show_view("profil", pid))
	var cn := CalqueCouleur.new()
	cn.name = "CalqueNiveauxVie"
	cn.world = world
	cn.focus = rig
	cn.degrade = CalqueCouleur.degrade_valeur()
	cn.alpha = Vector2(0.75, 0.9)
	add_child(cn)
	var nvx := niveaux_vie
	cn.rects = func() -> Array:
		var somme := {}
		for hid in population.households:
			var h: Dictionary = population.households[hid]
			var n := NiveauxVie.niveau(h)
			if n < 0:
				continue
			var hb := int(h.b)
			var e: Vector2 = somme.get(hb, Vector2.ZERO)
			somme[hb] = e + Vector2(n, 1)
		var out := []
		for hb in somme:
			var info: Dictionary = population.known.get(hb, {})
			if not info.has("rect"):
				continue
			var e: Vector2 = somme[hb]
			out.append([(info.rect as Rect2i).grow(8), clampf(e.x / e.y / float(NiveauxVie.NIVEAUX.size() - 1), 0.0, 1.0)])
		return out
	nvx.changed.connect(cn.rafraichir)
	Calques.ajouter("habitants_niveaux", "Niveaux de vie", "Habitants", cn.montrer,
		"niveau moyen des foyers de chaque logement : du rouge (précaire) au bleu (très aisé). Maj+N : ce qui les empêche de monter.")
	niveaux_vie_panel.carte_requested.connect(func() -> void: Calques.afficher("habitants_niveaux", true))
	hud.niveaux_vie_requested.connect(func() -> void: niveaux_vie_panel.toggle())
## Immobilier vivant (F11) : indice des prix par ville, promoteurs et permis,
## gentrification par secteur, bidonvilles, logements sociaux ; carte « Quartiers
## qui changent » dans les Cartes (N → Immobilier).
func _setup_immobilier() -> void:
	immobilier = Immobilier.new()
	immobilier.name = "Immobilier"
	add_child(immobilier)
	immobilier.setup(buildings, population, nuisances, zones, ameliorations)
	immobilier.message.connect(func(t: String) -> void: hud.show_message(t))
	immobilier.changed.connect(func() -> void: _unsaved = true)
	immobilier_panel = ImmobilierPanel.new()
	immobilier_panel.name = "PanneauImmobilier"
	add_child(immobilier_panel)
	immobilier_panel.setup(immobilier)
	immobilier_panel.lieu_requested.connect(func(pos: Vector3) -> void:
		rig.position.x = pos.x
		rig.position.z = pos.z)
	var cg := CalqueCouleur.new()
	cg.name = "CalqueGentrification"
	cg.world = world
	cg.focus = rig
	cg.degrade = CalqueCouleur.degrade_valeur()
	cg.alpha = Vector2(0.55, 0.8)
	add_child(cg)
	var im := immobilier
	cg.valeur = func(x: float, z: float) -> float:
		var k := Immobilier.secteur_de(Vector3(x, 0, z))
		if not im.secteurs.has(k):
			return -1.0
		# Bidonville : rouge vif.
		var bq := buildings.building_at(Vector2i(floori(x), floori(z)))
		if bq >= 0 and Immobilier.precaire(bq):
			return 0.0
		return clampf(0.5 + im.evolution_secteur(k) * 2.0, 0.0, 1.0)
	im.changed.connect(cg.rafraichir)
	Calques.ajouter("immobilier_quartiers", "Quartiers qui changent", "Immobilier", cg.montrer,
		"évolution des prix sur six mois par secteur de 200 m : bleu, il s'embourgeoise ; rouge, il se paupérise (et les bidonvilles). F11 : panneau Immobilier.")
	immobilier_panel.carte_requested.connect(func() -> void: Calques.afficher("immobilier_quartiers", true))
	hud.immobilier_requested.connect(func() -> void: immobilier_panel.toggle())


## Statistiques dans le temps et conseiller (Maj+I, menu Infos).
func _setup_statistiques() -> void:
	statistiques = Statistiques.new()
	statistiques.name = "Statistiques"
	add_child(statistiques)
	statistiques.setup(population, communes, pays, budget, reseaux, trafic, dechets, nuisances, avis)
	Statistiques.instance = statistiques
	statistiques.releve_fait.connect(func() -> void: _unsaved = true)
	statistiques.alerte.connect(func(t: String, _lieu: String) -> void: hud.show_message(t + " (Maj+I)"))
	stats_panel = StatsPanel.new()
	stats_panel.name = "PanneauStatistiques"
	add_child(stats_panel)
	stats_panel.setup(statistiques)
	stats_panel.panneau_requested.connect(ouvrir_panneau)
	hud.stats_requested.connect(func() -> void: stats_panel.toggle())


## Mode photo (F8 : temps figé, caméra libre, filtres, photo sans l'interface)
## et time-lapse (Maj+F8 : une image par jour depuis la fondation, export vidéo).
## Mode streamer (F7) : le chat Twitch vote pour des catastrophes, des décisions
## du maire, la météo ou des fêtes ; « !habitant » donne son pseudo à un habitant.
func _setup_streamer() -> void:
	mode_streamer = ModeStreamer.new()
	mode_streamer.name = "ModeStreamer"
	add_child(mode_streamer)
	mode_streamer.setup(evenements, population, rig)
	mode_streamer.message.connect(func(t: String) -> void: hud.show_message(t))
	mode_streamer.changed.connect(func() -> void: _unsaved = true)
	streamer_panel = StreamerPanel.new()
	streamer_panel.name = "PanneauStreamer"
	add_child(streamer_panel)
	streamer_panel.setup(mode_streamer)
	streamer_panel.focus_requested.connect(func(pos: Vector3) -> void:
		rig.position.x = pos.x
		rig.position.z = pos.z)
	hud.streamer_requested.connect(func() -> void: streamer_panel.toggle())


func _setup_photo() -> void:
	timelapse = TimeLapse.new()
	timelapse.name = "TimeLapse"
	timelapse.ambiance = ambiance
	timelapse.rig = rig
	timelapse.world = world
	timelapse.communes = communes
	timelapse.population = population
	add_child(timelapse)
	timelapse.message.connect(func(t: String) -> void: hud.show_message(t))
	communes.fonde.connect(func(vid: int) -> void:
		if not _chargement and not GameStart.atelier:
			timelapse.on_fonde(vid))
	timelapse_panel = TimeLapsePanel.new()
	timelapse_panel.name = "TimeLapsePanel"
	timelapse_panel.ambiance = ambiance
	timelapse_panel.vue_actuelle = func() -> Array:
		var cam := get_viewport().get_camera_3d()
		return [] if cam == null else [cam.global_transform, cam.fov]
	add_child(timelapse_panel)
	timelapse_panel.setup(timelapse)
	timelapse_panel.message.connect(func(t: String) -> void: hud.show_message(t))
	mode_photo = ModePhoto.new()
	mode_photo.name = "ModePhoto"
	mode_photo.rig = rig
	mode_photo.ambiance = ambiance
	mode_photo.ground_height = rig.ground_height
	mode_photo.avant_entree = func() -> void:
		mode_photo.nom_lieu = _game_title()
		_select_building_tool()
	add_child(mode_photo)
	mode_photo.message.connect(func(t: String) -> void: hud.show_message(t))
	mode_photo.timelapse_requested.connect(func() -> void: timelapse_panel.toggle())
	mode_photo.cadrage_timelapse.connect(func(xf: Transform3D, fov: float, fmt: String) -> void:
		var cid := timelapse.ajouter_camera("Caméra %d" % timelapse.next_cam, xf, fov, fmt)
		if cid >= 0:
			mode_photo._toast("Time-lapse : ce cadrage sera filmé une fois par jour de jeu, vers midi (Maj+F8 pour revoir)."))
	hud.photo_requested.connect(func() -> void: mode_photo.entrer())


## Journal de la ville (F4, menu Infos) : une édition chaque matin sur la veille.
func _setup_journal() -> void:
	journal = Journal.new()
	journal.name = "Journal"
	add_child(journal)
	journal.setup(population, evenements, avis, statistiques, buildings, transport, communes, saisons, ambiance)
	for s in clubs:
		journal.ecouter_club(clubs[s])
	journal.changed.connect(func() -> void: _unsaved = true)
	journal_panel = JournalPanel.new()
	journal_panel.name = "PanneauJournal"
	add_child(journal_panel)
	journal_panel.setup(journal)
	journal_panel.focus_requested.connect(func(pos: Vector3) -> void:
		journal_panel.set_open(false)
		rig.position.x = pos.x
		rig.position.z = pos.z)
	journal_panel.person_requested.connect(func(pid: int) -> void:
		journal_panel.set_open(false)
		habitants_panel.set_open(true)
		habitants_panel.show_view("profil", pid))
	journal.edition_parue.connect(func(ed: Dictionary) -> void:
		if int((ed.une as Dictionary).get("imp", 0)) >= 6 and not _chargement:
			hud.show_message(Langue.t("%s : « %s » (F4)") % [Journal.titre_de(ed), Journal.texte(ed.une.titre)]))
	hud.journal_requested.connect(func() -> void: journal_panel.toggle())


## Ouvre un panneau par son id (boutons du conseiller).
func ouvrir_panneau(id: String) -> void:
	var panels := {"budget": budget_panel, "avis": avis_panel, "construire": build_panel, "trafic": trafic_panel,
		"dechets": dechets_panel, "reseaux": reseaux_panel, "services": services_panel, "education": education_panel, "cartes": cartes_panel,
		"lignes": transit_panel, "pays": pays_panel, "production": production_panel, "objectifs": objectifs_panel,
		"saisons": saisons_panel, "sante": sante_panel, "climat": climat_panel}
	var p = panels.get(id)
	if p != null:
		p.set_open(true)
## Tutoriel guidé (une étape à la fois) et objectifs résumés à l'écran.
func _setup_tutoriel() -> void:
	tutoriel = Tutoriel.new()
	tutoriel.name = "Tutoriel"
	add_child(tutoriel)
	tutoriel.setup(self)
	tutoriel.message.connect(func(t: String) -> void: hud.show_message(t))
	tutoriel.changed.connect(func() -> void: _unsaved = true)
	tutoriel.action_requested.connect(_on_tuto_action)
	tuto_carte = TutorielCarte.new()
	tuto_carte.name = "CarteTutoriel"
	add_child(tuto_carte)
	tuto_carte.ville_courante = func() -> int: return pays.actif
	tuto_carte.setup(tutoriel, objectifs)
	tuto_carte.objectifs_requested.connect(func() -> void: objectifs_panel.set_open(not objectifs_panel.is_open()))
	# Nouvelle partie lancée du globe : le tutoriel commence (s'il est coché).
	tutoriel.bilan_demande.connect(ouvrir_bilan_demo)
	var demo := Demo.demandee
	Demo.demandee = false
	if GameStart.load_slot == "" and GameStart.chosen and not GameStart.atelier and demo:
		tutoriel.demarrer_demo.call_deferred()
	elif GameStart.load_slot == "" and GameStart.chosen and not GameStart.atelier and ReglagesPartie.actuel.tutoriel:
		tutoriel.demarrer.call_deferred()
	else:
		ReglagesPartie.actuel.tutoriel = false


## Bouton d'action de l'étape du tutoriel.
func _on_tuto_action(id: String) -> void:
	if hud.create_mode and id != "temps":
		set_create_mode(false)
	match id:
		"fonder":
			if not villages_panel._dialog.visible:
				villages_panel.demander_nom()
		"fondateurs":
			fondateurs_panel.set_open(true)
		"route":
			hud.choose_tool(TerreHud.FIRST_TRANSPORT_TOOL)
		"zones", "reseaux", "ecole", "dechets":
			build_panel.set_open(true)
			build_panel.show_category({"zones": "zones", "reseaux": "reseaux", "ecole": "services", "dechets": "dechets"}[id])
		"temps":
			ambiance.set_speed(mini(maxi(ambiance.speed_index + 1, DayNight.DEFAULT_SPEED), DayNight.SPEEDS.size() - 1))
			hud.show_message("Vitesse : %s. T met en pause, Maj + T change la vitesse." % String(DayNight.SPEED_NAMES[ambiance.speed_index]).to_lower())
		"budget":
			budget_panel.set_open(true)
		"objectifs":
			objectifs_panel.set_open(true)
		"vue_sol":
			var vs := get_node_or_null("VueSol") as VueSol
			if vs != null and vs.vue == VueSol.Vue.DESSUS:
				vs.vue_suivante()
		"loisirs":
			build_panel.set_open(true)
			build_panel.show_category("espaces")
		"fete":
			evenements_panel.set_open(true)
			evenements_panel.show_view("organiser")
		"ligne":
			transit_panel.set_open(true)


## Scénarios et défis : suivi (ScenarioPartie), carte à l'écran, bilan de fin.
func _setup_scenario() -> void:
	scenario = ScenarioPartie.new()
	scenario.name = "Scenario"
	add_child(scenario)
	scenario.setup(self)
	scenario.message.connect(func(t: String) -> void: hud.show_message(t))
	scenario.changed.connect(func() -> void: _unsaved = true)
	scenario.termine.connect(ouvrir_bilan_scenario)
	scenario_carte = ScenarioCarte.new()
	scenario_carte.name = "CarteScenario"
	add_child(scenario_carte)
	scenario_carte.setup(scenario)
	# Sous la carte du personnage suivi (habitants façon Sims), quand elle est là.
	scenario_carte.decalage = func() -> float:
		var c: Control = habitants_panel._card if habitants_panel != null else null
		return c.size.y + 8.0 if c != null and c.is_visible_in_tree() else 0.0
	var sid := Scenarios.demande
	Scenarios.demande = ""
	if sid != "" and GameStart.load_slot == "" and GameStart.chosen and not GameStart.atelier:
		scenario.demarrer.call_deferred(sid)


func ouvrir_bilan_scenario(r: Dictionary) -> void:
	if bilan_scenario != null:
		return
	bilan_scenario = ScenarioBilan.new(r)
	bilan_scenario.ferme.connect(func() -> void:
		bilan_scenario = null
		hud.show_message("Les règles du scénario sont levées : la ville est à toi."))
	bilan_scenario.menu_demande.connect(func() -> void:
		if not save_game():
			hud.show_message("Sauvegarde impossible : " + last_error)
		GameStart.slot_id = ""
		EcranChargement.aller(MenuPrincipal.SCENE, "Retour au menu principal"))
	bilan_scenario.rejouer_demande.connect(func() -> void:
		if not save_game():
			hud.show_message("Sauvegarde impossible : " + last_error)
		Scenarios.lancer(String(r.get("id", ""))))
	add_child(bilan_scenario)


## Édition démo (Steam Next Fest, EditionDemo) : limite de la partie et écran de fin.
var limite_demo: LimiteDemo
var fin_demo: FinDemo


func _setup_edition_demo() -> void:
	limite_demo = LimiteDemo.new()
	limite_demo.name = "LimiteDemo"
	add_child(limite_demo)
	limite_demo.lire = func() -> Dictionary:
		var vid := int(pays.actif) if pays != null else -1
		return {"jour": objectifs.jour(), "habitants": population.persons.size(),
			"nom": String(pays.nom_de(vid)) if pays != null and vid >= 0 else "Ta ville"}
	limite_demo.vitesse = func() -> int: return ambiance.speed_index
	limite_demo.pause = func() -> void: ambiance.set_speed(0)
	limite_demo.message.connect(func(t: String) -> void: hud.show_message(t))
	limite_demo.fin_atteinte.connect(ouvrir_fin_demo)


func ouvrir_fin_demo(chiffres: Dictionary = {}) -> void:
	if fin_demo != null:
		return
	if bilan_demo != null:
		bilan_demo.fermer()
	fin_demo = FinDemo.new(FinDemo.Motif.LIMITE, chiffres)
	fin_demo.ferme.connect(func() -> void:
		fin_demo = null
		if not save_game():
			hud.show_message("Sauvegarde impossible : " + last_error))
	fin_demo.menu_demande.connect(func() -> void:
		if not save_game():
			hud.show_message("Sauvegarde impossible : " + last_error)
		GameStart.slot_id = ""
		EcranChargement.aller(MenuPrincipal.SCENE, "Retour au menu principal"))
	add_child(fin_demo)


## Démo guidée : bilan de fin (DemoBilan), au-dessus du jeu.
var bilan_demo: DemoBilan


func ouvrir_bilan_demo() -> void:
	if bilan_demo != null:
		return
	bilan_demo = DemoBilan.new(tutoriel.bilan())
	bilan_demo.ferme.connect(func() -> void:
		bilan_demo = null
		hud.show_message("La démo est finie, ta ville continue : bonne route, Monsieur le Maire !"))
	bilan_demo.menu_demande.connect(func() -> void:
		if not save_game():
			hud.show_message("Sauvegarde impossible : " + last_error)
		GameStart.slot_id = ""
		EcranChargement.aller(MenuPrincipal.SCENE, "Retour au menu principal"))
	add_child(bilan_demo)


## Visites et cartes postales (F12, VisiteVille, Courrier, docs/visites.md).
var courrier: Courrier
var visites_panel: VisitesPanel
var _bandeau_visite: PanelContainer


func _setup_visites() -> void:
	courrier = Courrier.new()
	courrier.name = "Courrier"
	courrier.world = world
	courrier.ma_partie = func() -> String:
		if GameStart.slot_id == "" or GameStart.slot_id == VisiteVille.SLOT:
			return ""
		return String(SaveGame.read_manifest(GameStart.slot_id).get("partie_id", ""))
	add_child(courrier)
	courrier.arrivee.connect(func(c: Dictionary) -> void:
		if not _chargement and not VisiteVille.active():
			hud.show_message("Carte postale de %s : « %s » (F12 pour la lire)." % [String(c.de), String(c.texte).left(60)]))
	hud.visites_requested.connect(toggle_visites)
	# Courrier arrivé pendant qu'on ne jouait pas : relevé au lancement.
	(func() -> void:
		if not VisiteVille.active() and Multijoueur.role == Multijoueur.Role.SOLO and is_instance_valid(courrier):
			courrier.relever()).call_deferred()


func toggle_visites() -> void:
	if visites_panel != null:
		visites_panel.fermer()
		return
	visites_panel = VisitesPanel.new(self)
	visites_panel.closed.connect(func() -> void:
		visites_panel = null
		hud.set_panel_open("visites", false))
	visites_panel.message.connect(func(t: String) -> void: hud.show_message(t))
	_windows_layer().add_child(visites_panel)
	hud.set_panel_open("visites", true)


## Un champ de texte a-t-il le clavier (carte postale, discussion) ?
func _saisie_en_cours() -> bool:
	var f := get_viewport().gui_get_focus_owner()
	return f is LineEdit or f is TextEdit


## La ville visitée est ouverte : on regarde sans toucher.
func _debut_visite() -> void:
	set_create_mode(false)
	if tutoriel != null:
		tutoriel.set_actif(false)
	ReglagesPartie.actuel.tutoriel = false
	if pilote != null:
		pilote.set_process(false)
	if scenario != null and scenario.en_cours():
		scenario.clear()
	if succes_suivi != null:
		succes_suivi.actif = false
	# La ville vit à son rythme normal pendant la promenade.
	if ambiance.speed_index == 0 and not VisiteVille.en_ligne:
		ambiance.set_speed(1)
	hud.set_admin_visible(false)
	_bandeau_visite = PanelContainer.new()
	UiStyle.style_panel(_bandeau_visite, 0.9, 10, 8)
	_bandeau_visite.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_bandeau_visite.position.y = 112
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	_bandeau_visite.add_child(h)
	var ic := TextureRect.new()
	ic.texture = Icones.get_icon("pieton", 20, UiStyle.ACCENT)
	ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	h.add_child(ic)
	var l := Label.new()
	var de := VisiteVille.auteur()
	l.text = "Visite de « %s »%s" % [VisiteVille.titre(), (" · ville de " + de) if de != "" else ""]
	l.add_theme_color_override("font_color", UiStyle.ACCENT)
	h.add_child(l)
	var cp := Button.new()
	cp.text = "Carte postale (F12)"
	cp.focus_mode = Control.FOCUS_NONE
	cp.pressed.connect(toggle_visites)
	h.add_child(cp)
	var fin := Button.new()
	fin.text = "Terminer la visite"
	fin.focus_mode = Control.FOCUS_NONE
	fin.pressed.connect(func() -> void: VisiteVille.terminer())
	h.add_child(fin)
	hud.add_child(_bandeau_visite)
	(func() -> void:
		if is_instance_valid(_bandeau_visite):
			_bandeau_visite.position.x = (_bandeau_visite.get_parent_area_size().x - _bandeau_visite.size.x) * 0.5).call_deferred()
	var acc := String(VisiteVille.en_cours.get("accueil", ""))
	if acc == "":
		acc = courrier.accueil
	hud.show_message(("« %s » · " % acc if acc != "" else "") + "Bienvenue ! Promène-toi (V pour marcher), et laisse une carte postale avec F12.")


## Son : ambiances selon la caméra, humeur de la musique, sons des événements.
## Succès du joueur (Succes, F6) et commandes de la manette (Manette).
var succes_suivi: SuccesSuivi
var succes_panel: SuccesPanel
## Ordre des outils de la barre du bas pour la croix de la manette (gauche / droite).
const OUTILS_MANETTE := [0, 1, 2, 3, 4, 5, 6, 7, 9, 8, 10]


func _setup_succes() -> void:
	succes_suivi = SuccesSuivi.new()
	succes_suivi.name = "SuccesSuivi"
	add_child(succes_suivi)
	succes_suivi.setup(self)
	hud.succes_requested.connect(toggle_succes)
	if Manette.instance != null:
		Manette.instance.commande.connect(_on_commande_manette)


func toggle_succes() -> void:
	if succes_panel != null:
		succes_panel.close_panel()
		return
	succes_panel = SuccesPanel.new()
	succes_panel.closed.connect(func() -> void: succes_panel = null)
	_windows_layer().add_child(succes_panel)


func _on_commande_manette(nom: String) -> void:
	if pause_menu != null or not is_inside_tree():
		return
	match nom:
		"outil_suivant", "outil_precedent":
			var i := OUTILS_MANETTE.find(hud._current_tool)
			i = (i + (1 if nom == "outil_suivant" else -1) + OUTILS_MANETTE.size()) % OUTILS_MANETTE.size()
			hud.choose_tool(int(OUTILS_MANETTE[maxi(i, 0)]))


func _setup_son() -> void:
	var son := Son.ici()
	if son != null:
		son.humeur_fn = _humeur_musique
		# La scène partie (globe, autre partie) : la musique n'écoute plus cette ville.
		tree_exiting.connect(func() -> void:
			if son.humeur_fn == Callable(self, "_humeur_musique"):
				son.humeur_fn = Callable())
	sons = AmbiancesSonores.new()
	sons.name = "AmbiancesSonores"
	sons.setup(rig, ambiance, world, buildings, transport.traffic, get_node_or_null("VueSol"))
	sons.sources_chantiers.append(vie_batiments.chantiers_bruyants)
	sons.sources_chantiers.append(chantiers_voies.chantiers_bruyants)
	add_child(sons)
	evenements.incident_declare.connect(func(_i: Dictionary) -> void:
		if not _chargement:
			Son.jouer("alerte", -4.0))
	evenements.actualite.connect(func(_n: Dictionary) -> void:
		var t := Time.get_ticks_msec()
		if not _chargement and t - _derniere_nouvelle > 4000:
			_derniere_nouvelle = t
			Son.jouer("ui_notification", -6.0, 0.0, "Interface"))


## Humeur de la musique : nuit, soirée ou journée selon l'heure de la ville.
func _humeur_musique() -> String:
	if ambiance == null:
		return "jour"
	if ambiance.night > 0.6:
		return "nuit"
	var h := ambiance.local_hour()
	return "soir" if h >= 18.0 or h < 7.0 else "jour"


## Pendant un chargement, les événements rechargés ne font pas de bruit.
var _chargement := false
var _derniere_nouvelle := -100000


## Quartiers et arrêtés municipaux (Maj+Y) : quartiers nommés peints sur la
## carte, zone 30, rues piétonnes, calme la nuit, tri obligatoire…
func _setup_quartiers() -> void:
	quartiers = Quartiers.new()
	quartiers.name = "Quartiers"
	add_child(quartiers)
	quartiers.setup(world, buildings, transport, population, communes)
	quartiers.dechets = dechets
	quartiers.message.connect(func(t: String) -> void: hud.show_message(t))
	quartiers.changed.connect(func() -> void: _unsaved = true)
	Calques.ajouter("quartiers", "Quartiers et arrêtés", "Villages", func(on: bool) -> void: quartiers.calque = on,
		"une couleur par quartier · nom et nombre d'arrêtés au milieu · îlots de 50 m")
	quartiers_panel = QuartiersPanel.new()
	quartiers_panel.name = "PanneauQuartiers"
	add_child(quartiers_panel)
	quartiers_panel.setup(quartiers)
	quartiers_panel.focus_requested.connect(func(pos: Vector3) -> void:
		rig.position.x = pos.x
		rig.position.z = pos.z)
	hud.quartiers_requested.connect(func() -> void: quartiers_panel.toggle())


## Élections perdues avec le réglage « fin de partie ».
func _on_defaite_finale(texte: String) -> void:
	var d := AcceptDialog.new()
	d.title = "Fin de partie"
	d.dialog_text = "%s\n\nTu as perdu la mairie. Tu peux continuer en bac à sable, ou revenir au globe pour une nouvelle partie." % texte
	d.ok_button_text = "Continuer quand même"
	d.add_button("Revenir au globe", true, "globe")
	d.custom_action.connect(func(a: StringName) -> void:
		if a == "globe":
			d.hide()
			hud.globe_requested.emit())
	add_child(d)
	d.popup_centered()
## Nuisances (pollution de l'air, de l'eau, bruit) et valeur des terrains, avec
## leurs cartes de couleur dans le panneau Cartes (touche N).
func _setup_nuisances() -> void:
	nuisances = Nuisances.new()
	nuisances.name = "Nuisances"
	add_child(nuisances)
	nuisances.setup(world, buildings, transport, population, ambiance)
	zones.extra_chance = nuisances.chance_pousse
	vie_batiments.extra_usure = nuisances.usure_rythme
	ameliorations = Ameliorations.new()
	ameliorations.name = "Ameliorations"
	add_child(ameliorations)
	ameliorations.setup(buildings, vie_batiments, population, zones)
	ameliorations.nuisances = nuisances
	ameliorations.message.connect(func(t: String) -> void: hud.show_message(t))
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
	carrieres = Carrieres.new()
	carrieres.name = "Carrieres"
	add_child(carrieres)
	carrieres.setup(world, buildings, production, transport, ambiance, rig)
	carrieres.message.connect(func(t: String) -> void: hud.show_message(t))
	carrieres.info_changed.connect(func(t: String) -> void: hud.set_tool_info(t))
	carrieres.changed.connect(func() -> void: _unsaved = true)
	production_panel.carrieres = carrieres
	production_panel.outil_carriere.connect(func(mode: String, bid: int) -> void:
		_select_building_tool()
		carrieres.start_tool(mode, bid))


## Agriculture : champs, machines, bêtes, repas des habitants et panneau (Maj+F).
func _setup_agriculture() -> void:
	agriculture = Agriculture.new()
	agriculture.name = "Agriculture"
	add_child(agriculture)
	agriculture.setup(world, buildings, population, production, ambiance)
	agriculture.message.connect(func(t: String) -> void: hud.show_message(t))
	agriculture.info_changed.connect(func(t: String) -> void: hud.set_tool_info(t))
	agri_visuels = AgriVisuels.new()
	agri_visuels.name = "ChampsVisibles"
	add_child(agri_visuels)
	agri_visuels.setup(agriculture, world)
	agri_panel = AgriPanel.new()
	agri_panel.name = "PanneauAgriculture"
	add_child(agri_panel)
	agri_panel.setup(agriculture)
	agri_panel.focus_requested.connect(func(pos: Vector3) -> void:
		rig.position.x = pos.x
		rig.position.z = pos.z)
	agri_panel.outil_demande.connect(func() -> void:
		var o := agriculture.outil
		_select_building_tool()
		agriculture.outil = o)
	hud.agriculture_requested.connect(func() -> void: agri_panel.toggle())


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
func _setup_trafic() -> void:
	trafic = Trafic.new()
	trafic.name = "Trafic"
	add_child(trafic)
	trafic.setup(transport, population)
	population.trafic = trafic
	trafic.message.connect(func(t: String) -> void: hud.show_message(t))
	lignes_eco = ExploitationLignes.new()
	lignes_eco.name = "ExploitationLignes"
	add_child(lignes_eco)
	lignes_eco.setup(transport, trafic, population, buildings, production)
	lignes_eco.message.connect(func(t: String) -> void: hud.show_message(t))
	transit_panel.set_eco(lignes_eco)
	trafic_overlay = TraficOverlay.new()
	trafic_overlay.name = "CarteTrafic"
	add_child(trafic_overlay)
	trafic_overlay.setup(trafic)
	trafic_panel = TraficPanel.new()
	trafic_panel.name = "PanneauTrafic"
	add_child(trafic_panel)
	trafic_panel.setup(trafic, trafic_overlay, transport.camera)
	trafic_panel.focus_requested.connect(func(pos: Vector3) -> void:
		rig.position.x = pos.x
		rig.position.z = pos.z)
	hud.trafic_requested.connect(func() -> void: trafic_panel.toggle())
	_register_trafic_map.call_deferred()


## Carte « Trafic » dans le panneau commun des cartes (touche N).
func _register_trafic_map() -> void:
	Calques.ajouter("trafic", "Trafic (bouchons)", "Transports", func(on: bool) -> void: trafic_overlay.set_shown(on),
		"vert : fluide · jaune : chargé · rouge : bouché · bleu : voie de bus · violet : fermée")


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


## Éducation : système scolaire du pays, degrés, apprentis, diplômes et pénuries (Maj+K).
func _setup_education() -> void:
	education_panel = EducationPanel.new()
	education_panel.name = "PanneauEducation"
	add_child(education_panel)
	education_panel.setup(population)
	education_panel.focus_requested.connect(func(pos: Vector3) -> void:
		rig.position.x = pos.x
		rig.position.z = pos.z)


## Services publics : couverture des écoles, hôpitaux et police (Maj+U, calques).
func _setup_services() -> void:
	services = ServicesPublics.new()
	services.name = "ServicesPublics"
	add_child(services)
	services.setup(population, buildings, transport, urgences)
	services_panel = ServicesPanel.new()
	services_panel.name = "PanneauServices"
	add_child(services_panel)
	services_panel.setup(services)
	services_panel.focus_requested.connect(func(pos: Vector3) -> void:
		rig.position.x = pos.x
		rig.position.z = pos.z)
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


## Musées : salles à thème, œuvres, visiteurs, billetterie et panneau (Maj+C).
func _setup_musee() -> void:
	musee = Musee.new()
	musee.name = "Musee"
	add_child(musee)
	musee.setup(mobilier, buildings, population, ambiance)
	musee.message.connect(func(t: String) -> void: hud.show_message(t))
	musee_panel = MuseePanel.new()
	musee_panel.name = "PanneauMusee"
	add_child(musee_panel)
	musee_panel.setup(musee, func() -> void: _select_building_tool())
	musee_panel.focus_requested.connect(func(pos: Vector3) -> void:
		rig.position.x = pos.x
		rig.position.z = pos.z)
	musee_panel.draw_requested.connect(func() -> void:
		musee_panel.set_open(false)
		set_create_mode(true))
	hud.musee_requested.connect(func() -> void: musee_panel.toggle())


## Spectacles : cinémas, salles de concert, théâtres, studios de cinéma et leur menu (Maj+X).
func _setup_spectacles() -> void:
	spectacles = Spectacles.new()
	spectacles.name = "Spectacles"
	add_child(spectacles)
	spectacles.setup(buildings, population, ambiance, transport, mobilier)
	spectacles.message.connect(func(t: String) -> void: hud.show_message(t))
	spectacles_panel = SpectaclesPanel.new()
	spectacles_panel.name = "PanneauSpectacles"
	add_child(spectacles_panel)
	spectacles_panel.setup(spectacles, func() -> void: _select_building_tool())
	spectacles_panel.building_chosen.connect(func(id: String) -> void:
		_select_building_tool()
		buildings.set_place(id))
	spectacles_panel.focus_requested.connect(func(pos: Vector3) -> void:
		rig.position.x = pos.x
		rig.position.z = pos.z)
	hud.spectacles_requested.connect(func() -> void:
		if not spectacles_panel.is_open():
			_select_building_tool()
		spectacles_panel.toggle())


## Club de sport : une section par sport (football, basket, handball, hockey,
## rugby, tennis), centre de formation, supporters en ville (Maj+B).
func _setup_club() -> void:
	for s in ClubSports.ORDRE:
		var c := ClubSport.new()
		c.sport = s
		c.name = "ClubSport" if s == "football" else "ClubSport_%s" % s
		add_child(c)
		c.setup(buildings, population, ambiance)
		c.message.connect(func(t: String) -> void: hud.show_message(t))
		clubs[s] = c
	club = clubs.football
	club_supporters = ClubSupporters.new()
	add_child(club_supporters)
	club_supporters.setup(buildings, population)
	club_panel = ClubPanel.new()
	club_panel.name = "PanneauClub"
	add_child(club_panel)
	club_panel.setup(club, clubs)
	club_panel.building_chosen.connect(func(id: String) -> void:
		club_panel.set_open(false)
		_select_building_tool()
		build_panel.set_open(true)
		build_panel.show_category("sport")
		if id != "" and BuildingCatalog.all_types().has(id):
			buildings.set_place(id))
	club_panel.focus_requested.connect(func(pos: Vector3) -> void:
		rig.position.x = pos.x
		rig.position.z = pos.z)
	hud.club_requested.connect(func() -> void: club_panel.toggle())


## Parc de loisirs : manèges, visiteurs, files d'attente, billets et panneau (Maj+G).
func _setup_parc() -> void:
	parc = ParcLoisirs.new()
	parc.name = "ParcLoisirs"
	add_child(parc)
	parc.setup(buildings, population, transport, ambiance)
	parc.message.connect(func(t: String) -> void: hud.show_message(t))
	parc_panel = ParcPanel.new()
	parc_panel.name = "PanneauParc"
	add_child(parc_panel)
	parc_panel.setup(parc)
	parc_panel.focus_requested.connect(func(pos: Vector3) -> void:
		rig.position.x = pos.x
		rig.position.z = pos.z)
	hud.parc_requested.connect(func() -> void: parc_panel.toggle())


## Obsèques : cimetières qui se remplissent, corbillards sur les routes, crématorium.
func _setup_funeraire() -> void:
	funeraire = Funeraire.new()
	funeraire.name = "Funeraire"
	add_child(funeraire)
	funeraire.setup(buildings, population, transport, production, ambiance)
	funeraire.message.connect(func(t: String) -> void: hud.show_message(t))


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
		_windows.layer = 70
		# Les fenêtres (aide, parties) marchent aussi depuis le menu pause.
		_windows.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(_windows)
	return _windows


func toggle_help() -> void:
	if _help != null:
		_help.close_panel()
		return
	_help = AidePanel.new()
	_help.closed.connect(func() -> void: _help = null)
	_windows_layer().add_child(_help)


func _exit_tree() -> void:
	var jp := get_node_or_null("/root/Plantages")
	if jp != null and jp.etat_partie == Callable(self, "etat_pour_rapport"):
		jp.etat_partie = Callable()


## Ce que dit le rapport de plantage de la partie en cours (JournalPlantage).
func etat_pour_rapport() -> Dictionary:
	var d := {"nom": _game_title(), "partie": GameStart.slot_id, "mode": ["bac à sable", "entre amis", "mondiale"][int(GameStart.mode)]}
	if ambiance != null:
		var dt: Dictionary = ambiance.local_datetime()
		d["date_jeu"] = "%02d/%02d/%04d %02dh%02d" % [int(dt.get("day", 0)), int(dt.get("month", 0)), int(dt.get("year", 0)), int(dt.get("hour", 0)), int(dt.get("minute", 0))]
		d["vitesse"] = ambiance.speed_index
	if population != null:
		d["habitants"] = population.persons.size()
	if buildings != null:
		d["batiments"] = buildings.buildings.size()
	if transport != null and transport.traffic != null:
		d["vehicules"] = transport.traffic.vehicles.size()
	if rig != null:
		d["camera"] = "%.0f, %.0f" % [rig.position.x, rig.position.z]
	d["vue_au_sol"] = ($VueSol as VueSol).active if has_node("VueSol") and "active" in $VueSol else false
	d["sauvegarde_auto_ms"] = derniere_autosave_ms
	d["non_sauvegarde"] = _unsaved
	return d


func _autosave(delta: float) -> void:
	# En ligne : c'est le serveur qui sauvegarde la carte.
	if GameStart.atelier or Multijoueur.en_ligne() or VisiteVille.active():
		return
	var interval := OptionsJeu.autosave_min * 60.0
	if interval <= 0.0:
		return
	_autosave_timer += delta
	if _autosave_timer < interval:
		return
	_autosave_timer = 0.0
	if not _unsaved:
		return
	var keep := GameStart.slot_id
	var t := _game_title()
	var t0 := Time.get_ticks_msec()
	if save_game(SaveGame.prochain_autosave(), "Sauvegarde automatique · " + t):
		hud.show_message("Sauvegarde automatique.")
	else:
		push_warning("Sauvegarde automatique impossible : " + last_error)
		hud.show_message("Sauvegarde automatique impossible : " + last_error)
	derniere_autosave_ms = Time.get_ticks_msec() - t0
	GameStart.slot_id = keep
	# La partie du joueur n'est pas à jour : on garde la marque « non sauvegardé ».
	_unsaved = keep != ""


# --- Menu pause (Échap) -------------------------------------------------------------

var pause_menu: MenuPause
## Échap pressé alors qu'un outil était actif : il annule l'outil, pas de pause.
var _esc_busy := false


## Un outil est-il en cours (Échap doit d'abord l'arrêter) ?
func _tool_busy() -> bool:
	if hud._current_tool != 0:
		return true
	if attractions != null and (attractions.outil == "gare" or parc_allees.outil != ""):
		return true
	if buildings.mode != BuildingSystem.Mode.NONE or zones.mode != ZoneSystem.Mode.NONE:
		return true
	if blocks.tool != BlockEditor.Tool.NONE or transport.tool != TransportSystem.Tool.NONE:
		return true
	if (plans != null and plans.tool != PlanEditor.Tool.NONE) or (mobilier != null and mobilier.tool != Mobilier.Tool.NONE):
		return true
	if quartiers != null and quartiers.outil != "":
		return true
	if zoo_outils != null and zoo_outils.actif():
		return true
	if outil_site != null and outil_site.actif():
		return true
	return decors != null and decors.outil != DecorSystem.Outil.AUCUN


func _input(event: InputEvent) -> void:
	var k := event as InputEventKey
	# Édition démo : raccourcis des panneaux du jeu complet (avant que les panneaux les voient).
	var verrou := EditionDemo.touche_verrouillee(k)
	if verrou != "":
		get_viewport().set_input_as_handled()
		hud.show_message(EditionDemo.texte_verrou(verrou))
		return
	# En visite : rien ne se construit ni ne se règle (sauf ce qu'on tape dans un champ).
	if VisiteVille.touche_verrouillee(k) and not _saisie_en_cours():
		get_viewport().set_input_as_handled()
		hud.show_message(VisiteVille.TEXTE_VERROU)
		return
	if k != null and k.pressed and not k.echo and k.keycode == KEY_ESCAPE and pause_menu == null:
		_esc_busy = _tool_busy()


## _unhandled_input (pas _unhandled_key_input, qui passe avant) : les outils, qui
## écoutent Échap dans leur _unhandled_input, l'ont déjà reçu ; la scène est la
## racine, elle passe donc en dernier.
func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo and k.keycode == KEY_F3 and Multijoueur.client_actif() != null \
			and Multijoueur.role == Multijoueur.Role.CLIENT:
		get_viewport().set_input_as_handled()
		toggle_joueurs()
		return
	if k != null and k.pressed and not k.echo and k.keycode == KEY_F6 and pause_menu == null:
		get_viewport().set_input_as_handled()
		toggle_succes()
		return
	if k != null and k.pressed and not k.echo and k.keycode == KEY_F12 and not k.shift_pressed and pause_menu == null:
		get_viewport().set_input_as_handled()
		toggle_visites()
		return
	if k == null or not k.pressed or k.echo or k.keycode != KEY_ESCAPE or pause_menu != null:
		return
	if _esc_busy:
		_esc_busy = false
		# Un outil de terrain ou de voie sans tracé en cours : retour à Observer.
		if hud._current_tool != 0:
			get_viewport().set_input_as_handled()
			hud.select_tool_silently(0)
			_on_tool_selected(0)
		return
	get_viewport().set_input_as_handled()
	open_pause()


## Carte entre amis (F3) : joueurs, code d'invitation, discussion.
var joueurs_panel: JoueursPanel


func toggle_joueurs() -> void:
	if joueurs_panel != null:
		joueurs_panel.queue_free()
		joueurs_panel = null
		return
	joueurs_panel = JoueursPanel.new(Multijoueur.client)
	joueurs_panel.closed.connect(func() -> void: joueurs_panel = null)
	_windows_layer().add_child(joueurs_panel)


func open_pause() -> void:
	if pause_menu != null:
		return
	pause_menu = MenuPause.new()
	pause_menu.unsaved = _unsaved and not GameStart.atelier and not VisiteVille.active()
	pause_menu.place = ("Visite : " + VisiteVille.titre()) if VisiteVille.active() else (_game_title() if not GameStart.atelier else "Atelier")
	pause_menu.resume_requested.connect(close_pause)
	pause_menu.save_requested.connect(func() -> void:
		if save_game():
			pause_menu.set_status("Partie sauvegardée : %s." % _game_title())
			pause_menu.unsaved = false
		else:
			pause_menu.set_status("Échec de la sauvegarde : " + last_error))
	pause_menu.load_requested.connect(func() -> void:
		open_saves_panel()
		if _saves_panel != null:
			_saves_panel.closed.connect(func() -> void:
				if pause_menu != null:
					pause_menu.unsaved = _unsaved))
	pause_menu.help_requested.connect(toggle_help)
	pause_menu.quit_requested.connect(_quit_from_pause)
	add_child(pause_menu)
	get_tree().paused = true


func close_pause() -> void:
	if pause_menu == null:
		return
	pause_menu.queue_free()
	pause_menu = null
	get_tree().paused = false


func _quit_from_pause(to_desktop: bool, save_first: bool) -> void:
	if save_first:
		if not save_game():
			pause_menu.set_status("Échec de la sauvegarde : " + last_error)
			return
		# Laisse le temps à l'aperçu d'être capturé.
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
	get_tree().paused = false
	if to_desktop:
		get_tree().quit()
		return
	if GameStart.atelier:
		GameStart.atelier = false
	if VisiteVille.active():
		VisiteVille.oublier()
	GameStart.slot_id = ""
	EcranChargement.aller(MenuPrincipal.SCENE, "Retour au menu principal")


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
	build_panel.plan_amenagement_chosen.connect(func(k: String) -> void:
		plans.set_amenagement(k)
		plans.set_material(blocks.material)
		plans.set_tint(blocks.tint)
		if plans.tool != PlanEditor.Tool.AMENAG:
			_select_building_tool()
			plans.set_tool(PlanEditor.Tool.AMENAG))
	build_panel.plan_amenagement_material.connect(func(on: bool) -> void: plans.amenag_own_mat = on)
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
	mobilier.changed.connect(func() -> void: population.demander_sync())
	plans.changed.connect(func() -> void: population.demander_sync())
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
	# Modèles de l'atelier posés comme bâtiments : leurs vrais murs et meubles.
	modeles_visites = ModelesVisites.new()
	modeles_visites.name = "ModelesVisites"
	modeles_visites.bs = buildings
	modeles_visites.mob = mobilier
	add_child(modeles_visites)
	interieur_panel = InterieurPanel.new()
	interieur_panel.setup(mobilier, func() -> void: _select_building_tool())
	build_panel.interieur_builder = interieur_panel.build
	_setup_atelier_tools()


# --- Personnaliser, banque de modèles, atelier ---------------------------------------

var perso_panel: PersoPanel
var modeles_visites: ModelesVisites
var banque_pose: BanquePose
var vue_etages: VueEtages
var banque_panel: BanquePanel


## Vue sous terre (scripts/souterrain) : Page bas sous le rez-de-chaussée, ou
## menu Infos. Réseaux de rue, tronçons enterrés, tunnels, métro, sous-sols.
var souterrain: VueSouterraine
var construction_souterraine: ConstructionSouterraine


func _setup_souterrain() -> void:
	souterrain = VueSouterraine.new()
	souterrain.name = "VueSouterraine"
	souterrain.world = world
	souterrain.transport = transport
	souterrain.buildings = buildings
	souterrain.reseaux = reseaux
	souterrain.telecom = telecom
	souterrain.plans = plans
	souterrain.rig = rig
	souterrain.camera = $CameraRig/Camera3D
	add_child(souterrain)
	souterrain.message.connect(func(t: String) -> void: hud.show_message(t))
	vue_etages.souterrain = souterrain
	transport.network.changed.connect(souterrain.marquer_sale)
	buildings.changed.connect(souterrain.marquer_sale)
	reseaux.elec.changed.connect(souterrain.marquer_sale)
	# Construire sous terre : conduites, tunnels, pièces (scripts/souterrain).
	construction_souterraine = ConstructionSouterraine.new()
	construction_souterraine.name = "ConstructionSouterraine"
	construction_souterraine.reseaux = reseaux
	construction_souterraine.telecom = telecom
	construction_souterraine.transport = transport
	construction_souterraine.plans = plans
	construction_souterraine.buildings = buildings
	construction_souterraine.world = world
	construction_souterraine.ranger = func() -> void: _select_building_tool()
	souterrain.brancher_construction(construction_souterraine)
	construction_souterraine.setup()
	construction_souterraine.message.connect(func(t: String) -> void: hud.show_message(t))
	construction_souterraine.changed.connect(souterrain.marquer_sale)
	if telecom != null:
		telecom.fibre.changed.connect(souterrain.marquer_sale)
	hud.souterrain_requested.connect(func() -> void:
		if souterrain.actif:
			souterrain.sortir()
		else:
			vue_etages.show_all()
			souterrain.entrer())


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
			EcranChargement.aller("res://scenes/terre.tscn", GameStart.retour_nom)
		else:
			GameStart.slot_id = ""
			EcranChargement.aller(MenuPrincipal.SCENE, "Retour au menu principal")
		return
	if not save_game():
		hud.show_message("Sauvegarde impossible, l'atelier attendra : " + last_error)
		return
	GameStart.retour_slot = GameStart.slot_id
	GameStart.retour_lat = world.origin_lat
	GameStart.retour_lon = world.origin_lon
	GameStart.retour_nom = GameStart.place_name
	GameStart.atelier = true
	EcranChargement.aller("res://scenes/terre.tscn", "Atelier")


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
	if partage_panel != null and partage_panel.is_open() and id != "partage":
		partage_panel.set_open(false)
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
		"partage":
			build_panel.set_open(false)
			partage_panel.set_open(true)
			return
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
	_ranger_parc_editeur()
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
	if carrieres:
		carrieres.set_inactive()
	if agriculture and agriculture.outil != "":
		agriculture.set_outil("")
	if banque_pose:
		banque_pose.stop()
	if outil_site:
		outil_site.stop()
	if zoo_outils:
		zoo_outils.set_inactive()
	hud.select_tool_silently(0)


## Zoo : enclos tracés à la main, animaux, soigneurs, visiteurs, et son menu (Maj+Z).
## Tourisme : hébergements, touristes qui visitent et dépensent (Maj+R).
## Partage des créations (Maj+W, Créer → 8) : publier, installer, plans de site.
var partage_panel: PartagePanel
var outil_site: OutilSite


func _setup_partage() -> void:
	outil_site = OutilSite.new()
	outil_site.name = "OutilPlanSite"
	add_child(outil_site)
	outil_site.world = world
	outil_site.camera = $CameraRig/Camera3D
	outil_site.contexte = contexte_partage
	outil_site.message.connect(func(t: String) -> void:
		if t != "":
			hud.show_message(t))
	partage_panel = PartagePanel.new()
	partage_panel.name = "PanneauPartage"
	add_child(partage_panel)
	partage_panel.setup(outil_site, func() -> void: _select_building_tool())
	partage_panel.message.connect(func(t: String) -> void: hud.show_message(t))
	# Steam : les abonnements du Workshop s'installent seuls.
	var n := Partage.synchroniser()
	if n > 0:
		hud.show_message("Créations du Workshop installées : %d." % n)


## Ce que les plans de site lisent et reposent (PlansSites).
func contexte_partage() -> Dictionary:
	return {"bs": buildings, "world": world, "allees": parc_allees, "zoo": zoo, "decors": decors, "mob": mobilier, "blocks": blocks}


func _setup_tourisme() -> void:
	tourisme = Tourisme.new()
	tourisme.name = "Tourisme"
	add_child(tourisme)
	tourisme.setup(buildings, population, ambiance, transport)
	tourisme.message.connect(func(t: String) -> void: hud.show_message(t))
	tourisme_panel = TourismePanel.new()
	tourisme_panel.name = "PanneauTourisme"
	add_child(tourisme_panel)
	tourisme_panel.setup(tourisme, func() -> void: _select_building_tool())
	tourisme_panel.building_chosen.connect(func(id: String) -> void:
		_select_building_tool()
		buildings.set_place(id))
	tourisme_panel.focus_requested.connect(func(pos: Vector3) -> void:
		rig.position.x = pos.x
		rig.position.z = pos.z)
	hud.tourisme_requested.connect(func() -> void: tourisme_panel.toggle())


## Patrimoine : bâtiments inscrits et classés (protection, abords, entretien,
## restauration) et grands monuments sur plusieurs années (touche Fin).
func _setup_patrimoine() -> void:
	patrimoine = Patrimoine.new()
	patrimoine.name = "Patrimoine"
	add_child(patrimoine)
	patrimoine.setup(buildings, population, ambiance, vie_batiments)
	patrimoine.message.connect(func(t: String) -> void: hud.show_message(t))
	patrimoine.changed.connect(func() -> void: _unsaved = true)
	patrimoine.actualite.connect(func(t: String, pos: Vector3) -> void:
		if evenements != null:
			evenements.news(t, pos, "patrimoine"))
	# Un monument protégé ne se démolit pas ; ses abords ont des règles.
	var prev_demol: Callable = buildings.demolish_check
	buildings.demolish_check = func(bid: int) -> String:
		var why := patrimoine.raison_demolir(bid)
		if why != "":
			return why
		return String(prev_demol.call(bid)) if prev_demol.is_valid() else ""
	var prev_check: Callable = buildings.extra_check
	buildings.extra_check = func(id: String, rect: Rect2i) -> Dictionary:
		var mine := patrimoine.check_place(id, rect)
		if String(mine.get("reason", "")) != "":
			return mine
		var res: Dictionary = prev_check.call(id, rect) if prev_check.is_valid() else {}
		if String(mine.get("info", "")) != "" and String(res.get("reason", "")) == "":
			res = res.duplicate()
			res["info"] = (String(res.get("info", "")) + "  " + String(mine.info)).strip_edges()
		return res
	# Entretenu, un monument protégé s'use moins vite.
	var prev_usure: Callable = vie_batiments.extra_usure
	vie_batiments.extra_usure = func(bid: int) -> float:
		var k := float(prev_usure.call(bid)) if prev_usure.is_valid() else 1.0
		return k * patrimoine.usure_rythme(bid)
	patrimoine_panel = PatrimoinePanel.new()
	patrimoine_panel.name = "PanneauPatrimoine"
	add_child(patrimoine_panel)
	patrimoine_panel.setup(patrimoine)
	patrimoine_panel.building_chosen.connect(func(id: String) -> void:
		_select_building_tool()
		buildings.set_place(id))
	patrimoine_panel.focus_requested.connect(func(pos: Vector3) -> void:
		rig.position.x = pos.x
		rig.position.z = pos.z)
	hud.patrimoine_requested.connect(func() -> void: patrimoine_panel.toggle())


## Commerce : marché mondial, villes partenaires, accords, crises (Maj+S).
func _setup_commerce() -> void:
	commerce_mondial = CommerceMondial.new()
	commerce_mondial.name = "CommerceMondial"
	add_child(commerce_mondial)
	commerce_mondial.setup(production, buildings, pays)
	commerce_mondial.message.connect(func(t: String) -> void: hud.show_message(t))
	commerce_mondial.actualite.connect(func(t: String) -> void:
		if evenements != null:
			evenements.news(t, Vector3.INF, "commerce"))
	commerce_panel = CommercePanel.new()
	commerce_panel.name = "PanneauCommerce"
	add_child(commerce_panel)
	commerce_panel.setup(commerce_mondial, pays)
	hud.commerce_requested.connect(func() -> void: commerce_panel.toggle())


func _setup_zoo() -> void:
	zoo = ZooSysteme.new()
	zoo.name = "Zoo"
	add_child(zoo)
	zoo.setup(buildings, population, transport, ambiance, world, decors)
	zoo.message.connect(func(t: String) -> void: hud.show_message(t))
	zoo_outils = ZooOutils.new()
	zoo_outils.name = "OutilsZoo"
	add_child(zoo_outils)
	zoo_outils.setup(zoo, world, decors)
	zoo_outils.message.connect(func(t: String) -> void: hud.show_message(t))
	zoo_outils.info_changed.connect(func(t: String) -> void: hud.set_tool_info(t))
	zoo_panel = ZooPanel.new()
	zoo_panel.name = "PanneauZoo"
	add_child(zoo_panel)
	zoo_panel.setup(zoo, zoo_outils)
	zoo_panel.building_chosen.connect(func(id: String) -> void:
		_select_building_tool()
		buildings.set_place(id))
	zoo_panel.hud_tool_requested.connect(func(t: int) -> void:
		zoo_outils.set_inactive()
		hud.select_tool_silently(t)
		_on_tool_selected(t))
	zoo_panel.decors_requested.connect(func() -> void:
		zoo_panel.set_open(false)
		toggle_decors())
	zoo_panel.focus_requested.connect(func(pos: Vector3) -> void:
		rig.position.x = pos.x
		rig.position.z = pos.z)
	hud.zoo_requested.connect(toggle_zoo)


## Ouvre ou ferme le menu du zoo (les autres outils sont rangés).
func toggle_zoo() -> void:
	if zoo_panel.is_open():
		zoo_panel.set_open(false)
		return
	_select_building_tool()
	zoo_panel.set_open(true)


## Décors (DecorSystem) et leur panneau (touche G).
func _setup_decors() -> void:
	decors = DecorSystem.new()
	decors.name = "Decors"
	add_child(decors)
	decors.setup(world, transport, buildings, ambiance)
	carrieres.relief_change.connect(decors._terrain_modifie)
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


## Éditeur du parc (Maj+A) : attractions sur voie (AttractionsPerso), allées
## et files d'attente (ParcAllees), décors à thème (dans DecorSystem).
func _setup_parc_editeur() -> void:
	attractions = AttractionsPerso.new()
	attractions.name = "AttractionsPerso"
	add_child(attractions)
	attractions.setup(buildings, world, parc)
	attractions.message.connect(func(t: String) -> void: hud.show_message(t))
	attractions.info_changed.connect(func(t: String) -> void: hud.set_tool_info(t))
	parc_allees = ParcAllees.new()
	parc_allees.name = "ParcAllees"
	add_child(parc_allees)
	parc_allees.setup(parc, world)
	parc_allees.message.connect(func(t: String) -> void: hud.show_message(t))
	parc_allees.info_changed.connect(func(t: String) -> void: hud.set_tool_info(t))
	parc_editeur_panel = ParcEditeurPanel.new()
	parc_editeur_panel.name = "PanneauParcEditeur"
	add_child(parc_editeur_panel)
	parc_editeur_panel.setup(attractions, parc_allees, parc)
	var aller := func(pos: Vector3) -> void:
		rig.position.x = pos.x
		rig.position.z = pos.z
	parc_editeur_panel.focus_requested.connect(aller)
	attractions.focus_requested.connect(aller)
	parc_editeur_panel.poser_batiment.connect(func(id: String) -> void:
		_select_building_tool()
		buildings.set_place(id))
	parc_editeur_panel.poser_decor.connect(func(id: String, o: int) -> void:
		_select_building_tool()
		if id != "":
			decors.set_choix(id)
		decors.set_outil(o as DecorSystem.Outil))
	hud.parc_editeur_requested.connect(func() -> void:
		if not parc_editeur_panel.is_open():
			_select_building_tool()
		parc_editeur_panel.toggle())


## Un autre outil prend la main : on arrête la pose de gare et le tracé d'allées
## (un tracé d'attraction en cours reste ouvert dans le panneau).
func _ranger_parc_editeur() -> void:
	if attractions == null:
		return
	if attractions.outil == "gare":
		attractions.annuler()
	parc_allees.set_inactive()


## Un panneau de loisirs (à gauche) est ouvert : la carte des objectifs s'efface.
func _loisirs_ouvert() -> bool:
	for p in _panneaux_parc().values():
		if p != null and p.is_open():
			return true
	return false


func _panneaux_parc() -> Dictionary:
	return {"parc": parc_panel, "parc_editeur": parc_editeur_panel, "zoo": zoo_panel, "musee": musee_panel, "spectacles": spectacles_panel, "club": club_panel, "tourisme": tourisme_panel, "patrimoine": patrimoine_panel}


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
	if agriculture and agriculture.outil != "":
		agriculture.set_outil("")
	if telecom:
		telecom.set_inactive()
	if decors_panel:
		decors_panel.set_shown(false)
	if zoo_outils:
		zoo_outils.set_inactive()
	_ranger_parc_editeur()
	if banque_pose:
		banque_pose.stop()
	if outil_site:
		outil_site.stop()
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
	if saisons != null:
		saisons.clear()
	if climat != null:
		climat.clear()
	if sante != null:
		sante.clear()
	if avis != null:
		avis.clear()
	if pays != null:
		pays.clear()
	if pilote != null:
		pilote.clear()
	if objectifs != null:
		objectifs.clear()
	if quartiers != null:
		quartiers.clear()
	if kit != null:
		kit.clear()
	if rue_fondation != null:
		rue_fondation.clear()
	if niveaux_vie != null:
		niveaux_vie.clear()
	if immobilier != null:
		immobilier.clear()
	if journal != null:
		journal.clear()
	if communes != null:
		communes.clear()
	if fondateurs != null:
		fondateurs.clear()
	population.clear()
	production.clear()
	if carrieres != null:
		carrieres.clear()
	agriculture.clear()
	budget.clear()
	urgences.clear()
	reseaux.clear()
	trafic.clear()
	lignes_eco.clear()
	services.clear()
	telecom.clear()
	if construction_souterraine != null:
		construction_souterraine.clear()
	dechets.clear()
	funeraire.clear()
	spectacles.clear()
	for s in clubs:
		(clubs[s] as ClubSport).clear()
	if tourisme != null:
		tourisme.clear()
	if patrimoine != null:
		patrimoine.clear()
	if commerce_mondial != null:
		commerce_mondial.clear()
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
		build_panel.set_money("Caisse : illimitée" if buildings.unlimited_money else "Caisse%s : %s" % [_caisse_de(), BuildingSystem.format_money(buildings.money)])
		build_panel.set_summary(buildings.summary())
		build_panel.set_zone_info(zones.summary())
		build_panel.set_block_info(plans.summary() if build_panel.block_mode() == "plans" else blocks.summary())
		_stats_timer -= 0.3
		if _stats_timer <= 0.0:
			_stats_timer = 1.0
			_stats_en_cours = true
	# Chiffres de la barre du haut : calculés par petits morceaux (grandes villes).
	if _stats_en_cours:
		var st := population.stats_par_morceaux()
		if not st.is_empty():
			_stats_en_cours = false
			_refresh_stats(st)
	_exclusive_panels()
	if tuto_carte != null:
		tuto_carte.cachee = hud.create_mode or GameStart.atelier or hud.coords_open() or _loisirs_ouvert()
	if scenario_carte != null:
		scenario_carte.cachee = hud.create_mode or GameStart.atelier or hud.coords_open() or _loisirs_ouvert()


var _stats_timer := 0.0
var _stats_en_cours := false
## Panneaux de droite ouverts à l'image précédente (pour n'en garder qu'un).
var _open_before := {}


## Construire, Lignes et Habitants partagent la même place à droite : quand
## l'un s'ouvre, les autres se ferment. Leur bouton de la barre du bas s'allume.
func _exclusive_panels() -> void:
	var panels := {"pays": pays_panel, "objectifs": objectifs_panel, "quartiers": quartiers_panel, "construire": build_panel, "lignes": transit_panel, "habitants": habitants_panel, "production": production_panel, "agriculture": agri_panel, "urgences": urgences_panel, "reseaux": reseaux_panel, "dechets": dechets_panel, "trafic": trafic_panel, "budget": budget_panel, "telecom": telecom_panel, "perso": perso_panel, "streamer": streamer_panel, "infos": evenements_panel, "cartes": cartes_panel, "avis": avis_panel, "villages": villages_panel, "fondateurs": fondateurs_panel, "stats": stats_panel, "saisons": saisons_panel, "sante": sante_panel, "climat": climat_panel}
	var opened := ""
	panels.merge(_panneaux_parc())
	panels["musee"] = musee_panel
	panels["partage"] = partage_panel
	for id in panels:
		var p = panels[id]
		var on: bool = p != null and p.is_open()
		if on and not _open_before.get(id, false):
			opened = id
		_open_before[id] = on
	if opened != "":
		Son.jouer("ui_ouvrir", -3.0, 0.0, "Interface")
		for id in panels:
			if id != opened and _open_before[id]:
				panels[id].set_open(false)
				_open_before[id] = false
	for id in panels:
		hud.set_panel_open(id, _open_before[id])
	# Mode Créer : panneau fermé (B, croix) = plus de catégorie allumée.
	if hud.create_mode and not build_panel.is_open() and not (partage_panel != null and partage_panel.is_open()) and hud.create_category() != "":
		hud.set_create_category("")


## Chiffres de la ville dans la barre du haut : caisse, habitants, satisfaction, chômage.
func _refresh_stats(st := {}) -> void:
	var money := "Illimitée" if buildings.unlimited_money else BuildingSystem.format_money(buildings.money)
	var s := st if not st.is_empty() else population.stats()
	# Les fondateurs encore sous la tente ne font pas monter les paliers.
	var palier := ReglagesPartie.actuel.note_population(int(s.habitants) - (fondateurs.au_campement() if fondateurs != null else 0))
	if palier != "" and ReglagesPartie.actuel.deblocage == "progression":
		hud.show_message("Palier « %s » atteint : de nouveaux bâtiments sont débloqués !" % palier)
		Son.jouer("palier")
		build_panel.refresh()
	suivre_epoque()
	var adults: int = int(s.actif) + int(s.chomeur)
	var unemployment := "—" if adults == 0 else "%d %%" % roundi(100.0 * int(s.chomeur) / adults)
	var tip := ""
	if pays != null and pays.a_des_villes():
		money = "%s : %s" % [pays.nom_de(pays.actif), money]
		tip = "Caisse de %s, la ville que tu gères (elle suit la caméra ; Maj+P pour le pays et les autres villes). Clic : budget." % pays.nom_de(pays.actif)
	hud.set_stats(money, int(s.habitants), int(s.satisfaction), unemployment, tip)


## Partie historique : à chaque nouvelle année, les véhicules en circulation
## changent et les grandes inventions sont annoncées (Epoques).
var _annee_vue := 0


func suivre_epoque() -> void:
	if not Epoques.actif():
		_annee_vue = 0
		return
	var y := Epoques.annee()
	if y == _annee_vue:
		return
	var avant := _annee_vue
	_annee_vue = y
	if transport != null and transport.traffic != null:
		transport.traffic.epoque_changee()
	if avant == 0:
		return
	var nouv := Epoques.inventions_entre(avant, y)
	if build_panel != null:
		build_panel.refresh()
	if nouv.is_empty():
		return
	var inv: Dictionary = nouv[nouv.size() - 1]
	hud.show_message("%d : %s ! %s" % [int(inv.annee), String(inv.nom), String(inv.desc)])
	Son.jouer("palier")


## « de Beauvallon » quand il y a plusieurs caisses.
func _caisse_de() -> String:
	if pays == null or not pays.a_des_villes():
		return ""
	return " de " + pays.nom_de(pays.actif)


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
