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
8. **Nouveautés de la semaine** (étape `semaine`) : marqueurs des chantiers (un par
   chantier, aucun texte flottant), devantures dessinées de près et effacées de loin,
   allées et venues d'un matin de semaine (plafonds de scènes et de personnages), manteau
   neigeux recopié sur le relief lointain, et chaque menu en images des panneaux ouvert
   puis rechoisi (aucune liste de texte, aucune erreur).
9. **Partie à la montagne** (étape `montagne`, relief réel) : Zermatt, neige au-dessus de
   l'isotherme 0 °C, route droite trop raide refusée avec le conseil « Lacets », tracé en
   lacets posé et tronçons d'épingles ralentis.
10. **Partie en 1800** : fondation, bâtiments d'époque, sauvegarde et rechargement.
11. **Démo guidée** depuis le menu : ses 18 étapes s'enchaînent.

Lancer (≈ 35 min) :

    godot --headless --path . --script res://tests/joueur_partie.gd

Options : `--etapes ville,touches,recharge,f9,semaine,montagne,epoque,demo` (choisir les étapes ; `ville`
est toujours nécessaire), `--hors-ligne` (relief plat, sans réseau), `--jours N` (40 par défaut : depuis les chantiers au tiers de la vie, les immeubles sortent après 20 à 30 jours).
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

## Bugs trouvés et corrigés (20 novembre 2026)

- **Au chargement, le campement emménageait dans les immeubles pas finis** : les
  bâtiments en chantier n'étaient pas encore marqués « en chantier » quand les habitants
  sont relus, si bien que 100 fondateurs s'installaient d'un coup dans des immeubles et
  des tours en travaux (34 → 143 habitants à chaque rechargement).
- **Relief qui bougeait de 0,5 m au bout des rues** à chaque chargement : les plateaux
  de carrefour étaient reterrassés par-dessus les cases sauvegardées.
- **Incident sans secours pour toujours** : un incident déclaré avant qu'une caserne
  (ou un poste) existe n'était jamais pris en charge ensuite ; et les secours en route
  étaient refaits au rechargement (F9 changeait l'état d'un incident).
- **Missions jugées au chargement** : le bilan du jour se refaisait en rouvrant la
  partie (mission « 60 habitants » réussie seulement après un rechargement).
- **Reste à payer d'un chantier** effacé au rechargement quand il valait 0.
