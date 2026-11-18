# Zonage

Construire (B) → Outils → **Zonage**. On peint des rectangles de zone ; des
bâtiments y poussent seuls le long des routes, selon la demande.

## Le panneau

- **4 cartes** : Résidentielle (vert), Commerciale (bleu), Industrielle (jaune),
  Retirer (rouge). Le bandeau de chaque carte a la couleur que prendra le sol.
  Chaque carte montre ce qui y pousse, le prix au m² et une **jauge de la
  demande** (`ZoneSystem.jauge_demande` : vide sans demande, ≈ 40 % au seuil
  « forte » de 50, pleine vers 150).
- **Pinceau** : l'encadré dit quel pinceau est en main. Clic droit ou Échap le
  repose (`ZoneSystem.outil_change`), et les cartes se relèvent.
- **Style des bâtiments** : liste des styles et trois vignettes d'exemple
  (logement, commerce, industrie), le bâtiment le plus fréquent du style
  (`BuildingPanel.exemple_de_style`).
- Surfaces déjà zonées en bas.

Les cartes s'appellent `ZoneR`, `ZoneC`, `ZoneI`, `ZoneX` (pour les bulles
d'aide du tutoriel). `BuildingPanel.choisir_zone(k)` choisit un pinceau comme
un clic. Le panneau suit le zonage par `BuildingPanel.suivre_zones(zones)`
(terre_main).

## Le calque coloré sur le relief

Le sol est fait de cases de 1 m en marches. Le calque (`ZoneSystem.calque_relief`)
couvre le **dessus** de chaque case libre et le **flanc** d'une case plus haute
que sa voisine, si bien que la couleur suit les marches au lieu de s'y cacher.
Le shader `scripts/batiments/zone_calque.gdshader` avance chaque sommet vers la
caméra (0,25 m + 0,4 % de la distance) : pas de scintillement, mais une vraie
colline devant la zone la cache toujours. Les bords des cases sont soulignés.

Quand un bloc de sol est redessiné (`TerrainWorld.chunk_rebuilt` : tuile
d'altitude arrivée, terrassement), le calque des zones de ce bloc est refait.

Le cadre du pinceau englobe le relief du rectangle (25 points relevés) et se
voit à travers le terrain.

## Tests

- `tests/zonage_test.gd` : calque sur une colline (aucun dessus sous le sol,
  flancs colorés), mise à jour au redessin du sol, cartes, pinceau, jauges,
  aperçu du style, cadre du pinceau.
- `tests/zonage_vitrine.gd` : capture (xvfb-run + opengl3), options `--glisser`,
  `--defiler`, `--sans-panneau`, `--plat`, `--pitch`, `--distance`, `--yaw`.
