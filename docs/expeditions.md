# Expéditions et objets rares

Inspiré des expéditions d'Anno 1800, adapté à MiniBlocs : on monte une équipe, on
l'envoie au bout du monde, et ce qu'elle rapporte sert au **musée**, au **zoo** et à
la **ville**.

## Ouvrir

1. Construire → Loisirs → **Société des explorateurs** (450 k€, dès 1800, 22 × 16 m :
   hôtel particulier, coupole d'observatoire, grand globe sur le toit).
2. **Maj+F4** (ou barre Loisirs ▴ → Expéditions). Onglets : **En cours**, **Préparer**,
   **Réserve**, **Récits**.

Une Société prépare une expédition à la fois. On peut en bâtir plusieurs.

## Préparer

- **Destination** : 17 lieux (vallée du Nil, îles de la mer Égée, Mésopotamie,
  savane, bassin du Congo, Madagascar, Bengale, Himalaya, route de la soie, Bornéo,
  cœur de l'Australie dès 1830, Galápagos, Andes, Yucatán, Grand Nord, Sibérie,
  Antarctique dès 1895).
  Chacun a un climat, une difficulté, une durée et ce qu'on peut y trouver (objets,
  animaux, savoir).
- **Chef** : recruté dans la Société ; il gagne un niveau toutes les deux réussites
  (5 au plus) et peut décider seul des imprévus.
- **Équipe** (9 au plus) : guide, médecin, naturaliste, archéologue, interprète,
  porteurs, alpiniste, cuisinier (moral), photographe (récits), pilote (trajet plus
  court)… selon l'époque.
- **Provisions** : vivres en plus, pharmacie de voyage, cartes et instruments,
  cadeaux pour les hôtes, matériel de fouille, caisses et cages de transport,
  équipement grand froid, équipement des tropiques, cordes et piolets…
- **Six qualités** : endurance, médecine, orientation, diplomatie, savoir, débrouille.
  Le menu affiche les avertissements (« pas de matériel contre le froid ») et le prix,
  payé au départ par la ville de la Société.
- **Transport** selon l'année : voilier (jusqu'en 1839), vapeur (1909), paquebot
  (1949), avion ensuite, de plus en plus rapide.

## Le voyage

- Aller, exploration, retour, jour après jour (au rythme du temps du jeu).
- Santé et moral s'usent, bien plus vite sans le matériel adapté au climat. Un
  membre trop faible rentre ; à santé zéro, l'équipe est rapatriée ; à moral zéro,
  elle abandonne.
- **22 imprévus** (rivière en crue, fièvre, blizzard, crevasse, ruines sous la
  végétation, guide perdu, expédition rivale, grotte ornée…) : deux ou trois réponses, avec la chance de réussite selon les
  qualités. Sans réponse en 2 jours, ou en mode auto, le chef choisit.
- **Rappeler** fait rentrer l'équipe avec ce qu'elle a déjà trouvé.

## Ce qu'on rapporte

| Butin | À quoi il sert |
|---|---|
| **42 objets rares** (1 à 3 étoiles) | Donnés à un musée : prestige, valeur, thèmes et étoiles (le musée le montre dans sa note). Exposés au **cabinet de curiosités** de la Société : un site touristique. Ou vendus, ou **rendus** à leur pays (renommée, avis des habitants). |
| **Animaux** (espèces du zoo) | « Enclos ▾ » : installés dans un enclos ; « Au zoo » : ils attendent un enclos dans l'onglet Échanges du zoo. Nés sauvages, ils apportent des **gènes neufs** à l'élevage. « Autre zoo » : 80 % de leur prix. |
| **14 spécialistes** | Installés dans une ville (3 au plus) : chantiers plus rapides (ingénieure des ponts, maître bâtisseur), récoltes (agronome, botaniste), santé (médecin des tropiques), tourisme (conférencier, photographe, cuisinier des épices), musées (conservatrice, déchiffreur), meilleures expéditions (cartographe, vieux loup de mer), humeur des habitants (conteuse). |

À chaque retour : **renommée** de la Société, un **récit** dans l'onglet Récits, et
un article dans la gazette.

## Époque

Avant 1970, les naturalistes **capturent** les animaux ; ensuite ils **recueillent**
des animaux blessés ou orphelins. Certaines destinations et certains membres
n'existent qu'à partir d'une date.

## Pour les développeurs

- `scripts/expeditions/` : `expeditions_donnees.gd` (toutes les données),
  `expeditions.gd` (moteur, `Expeditions.instance`), `expeditions_panel.gd`,
  `expeditions_visuels.gd`.
- Effets : `Expeditions.facteur(effet, ville)`, `rythme_chantier(bid)`,
  `facteur_musee(key)` ; groupes `sante_sources` et `avis_sources` ; sites
  touristiques `sites_tourisme()` (sorte « expeditions »).
- Zoo : `ZooSysteme.accueillir(esp, -1, "sauvage", extra)` (voir docs/zoo.md).
- Sauvegarde : section « expeditions ». Carte entre amis : appels relayés par
  `SystemesGeres`.
- Test : `godot --headless --path . --script res://tests/expeditions_test.gd`.
