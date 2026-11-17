# Banc « partie jouée comme un joueur »

`tests/joueur_partie.gd` joue une partie complète en passant par les vrais écrans,
pour traquer les bugs avant la démo Steam :

1. **Menu principal** → bouton « Nouvelle partie » → **globe** (Yverdon-les-Bains, relief réel).
2. **Écran de chargement**, tutoriel actif : le joueur passe le tour de la caméra puis
   clique le bouton de l'étape « Fonder » ; il tape le nom du village et **clique sur le
   terrain** pour poser la Maison de commune ; rue en T offerte, fondateurs.
3. **Deux clics de souris** avec l'outil Route tracent une rue ; puis plan de rues, courant,
   eau, entreprises du bâtiment, zones ; la ville grandit (25 jours), puis services
   (pompiers, police, hôpital, déchets, antenne, foot, parc).
4. **51 touches** des panneaux ouvertes puis refermées (F1 à F12, B, M, Maj+…, Page bas…).
5. **Échap → menu Pause → Sauver → Quitter vers le menu → Continuer** : la partie rouverte
   est comparée section par section à celle sauvegardée (date, bâtiments, chantiers,
   habitants, caisse, courant, eau, et tout le contenu des sections).
6. **Sauvegarde automatique** rechargée, même comparaison.
7. **F5 puis F9** (retour à la sauvegarde sans quitter), puis **Charger une autre partie**
   par-dessus la ville : rien ne doit rester de la première.
8. **Partie en 1800** : fondation, bâtiments d'époque, sauvegarde et rechargement.
9. **Démo guidée** depuis le menu : ses 18 étapes s'enchaînent.

Lancer (≈ 20 min) :

    godot --headless --path . --script res://tests/joueur_partie.gd -- --jours 25

Options : `--etapes ville,touches,recharge,f9,epoque,demo` (choisir les étapes ; `ville`
est toujours nécessaire), `--hors-ligne` (relief plat, sans réseau), `--jours N`.
À la fin : la liste des erreurs de script (avec l'étape ou la touche en cours) et des
constats. Les écarts sans conséquence (météo du jour recalculée, record d'habitants
recompté) sont listés dans `ECARTS_PERMIS`.

## Bugs trouvés et corrigés (17 novembre 2026)

- **Le temps courait derrière l'écran de chargement** : 2 h de jeu passaient pendant les
  5 s de chargement à 1 jour/min (chantiers, emménagements, factures), même pour une
  partie sauvegardée en pause. L'heure attend maintenant la fin de l'écran
  (`DayNight._process`).
- **F9 ou Charger pendant une pause** relançait le temps : la partie chargée reste en pause.
- **Chaque chargement ajoutait ~800 cases « modifiées »** sous les carrefours (relief pas
  encore chargé au moment où les plateaux sont recalculés) : la sauvegarde grossissait à
  chaque fois.
- **Tempête rechargée en cours** : l'orage restait pour toujours après la fin de la tempête
  (la « météo d'avant » notée au chargement était déjà l'orage) ; et l'annonce revenait.
- **Marché, fête, match rechargés en cours** : « ça commence » réapparaissait dans les
  nouvelles à chaque chargement.
- **Manifestation interrompue par une sauvegarde** : la rue barrée par le cortège pouvait
  rester fermée pour toujours.
- **F9 en revenant en arrière dans le temps** : une journée de tickets et de stationnement
  en trop au compteur du trafic ; une journée d'habitants à moitié calculée (ou un sondage
  à moitié fait) de l'ancienne partie pouvait continuer sur la partie chargée.
