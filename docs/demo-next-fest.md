# Édition démo pour le Steam Next Fest

Une build à part de MiniBlocs, faite pour être publiée comme **démo Steam** (et jouée
pendant un Steam Next Fest). C'est le même code que le jeu complet : l'exécutable
exporté avec le preset **Windows Demo** porte la fonctionnalité `demo`, et
`EditionDemo.active()` (scripts/edition/edition_demo.gd) devient vrai.

Code : `scripts/edition/edition_demo.gd` (règles et limites), `fin_demo.gd`
(écran de fin), `limite_demo.gd` (limite de la partie). Test :
`tests/edition_demo_test.gd`.

## Ce que contient la démo

| | Démo | Jeu complet |
|---|---|---|
| Démo guidée de 30 min (Échallens) | oui | oui |
| Nouvelle partie n'importe où sur Terre (bac à sable) | oui, jusqu'à la limite | oui |
| Ville : routes, zonage, réseaux, services, budget, habitants, vue au sol, lignes, éditeur libre, décors, mode photo | oui | oui |
| Loisirs simples, sport (terrains), espaces publics | oui | oui |
| Parc de loisirs, zoo, musée, spectacles, club de sport, tourisme | grisés, « dans le jeu complet » | oui |
| Époques (partir de 1800) | non, on démarre aujourd'hui | oui |
| Scénarios, carte entre amis, Atelier, partage Workshop | absents | oui |
| Succès (locaux et Steam) | coupés (Valve le conseille pour une démo) | oui |
| Sauvegardes | dossier à part `MiniBlocs Demo` | `MiniBlocs` |

**Limite d'une partie** : 120 jours de jeu (environ 2 h à la vitesse normale, 1 jour =
1 minute) ou 1 000 habitants (`EditionDemo.JOURS_MAX`, `HABITANTS_MAX`). Alors
l'écran **Fin de la démo** s'ouvre : merci, ce qui attend dans le jeu complet, gros
bouton **Ajouter à ma liste de souhaits**, puis « Regarder ma ville » (le temps reste
en pause, photos possibles, la partie est sauvegardée) ou « Menu principal ».

**Liste de souhaits** partout : bouton dans le menu principal, dans le bilan de la
démo guidée, sur l'écran de fin, et quand on quitte le jeu (écran « Merci d'avoir
joué ! »). Tant qu'il n'y a pas d'App ID, le bouton ouvre www.manigames.online. Dès
que Steamworks donne l'App ID du jeu, le mettre dans `EditionDemo.APP_ID` : le bouton
ouvre alors la page Steam (dans l'overlay Steam si GodotSteam est installé, sinon le
navigateur).

## Tester

**Depuis Godot (sans exporter)** : Projet → Paramètres du projet → (Avancé) Éditeur →
Exécution → *Arguments d'exécution principaux* : `-- --edition-demo`, puis F5. Ou en
ligne de commande :

```
godot --path . -- --edition-demo
```

À vérifier : le menu (badge « DÉMO », bouton Liste de souhaits, pas de Scénarios ni
d'Atelier), la barre Loisirs (boutons grisés, message « dans le jeu complet »),
Maj+Z, le catalogue Construire (pas d'onglet Zoo ni Parc de loisirs), Quitter
(écran de remerciement). Pour voir la fin sans attendre 120 jours : F10 → Admin,
mettre beaucoup d'argent et la vitesse maximale (Maj+T), ou baisser `JOURS_MAX` le
temps du test.

**Build Windows de la démo** :

```
powershell -ExecutionPolicy Bypass -File tools\export\exporter_windows.ps1 -Demo
```

Résultat dans `Documents\MiniBlocs-Demo\MiniBlocsDemo.exe` (+ `.pck`), à côté du jeu
normal, sans toucher à ses sauvegardes. La tâche planifiée « MiniBlocs - export »
continue de ne faire que le jeu complet.

**Test automatique** : `godot --headless --path . --script res://tests/edition_demo_test.gd`.

## Calendrier des Next Fest (vérifié le 16.11.2026 sur Steamworks)

Un jeu ne peut participer qu'**une seule fois** à un Next Fest : il faut choisir.

| | Février 2027 | Juin 2027 |
|---|---|---|
| Inscription jusqu'au | 10 janvier 2027 | 25 avril 2027 |
| Démo + page envoyées en review pour l'aperçu presse | 18 janvier | 10 mai |
| Tout envoyé en review (dernier délai) | 1er février | 24 mai |
| Aperçu presse | dès le 11 février | dès le 3 juin |
| Festival | 22 février → 1er mars | 14 → 21 juin |

Octobre 2027 : Valve annonce une édition, sans dates. Sources :
[Next Fest février 2027](https://partner.steamgames.com/doc/marketing/upcoming_events/nextfest/feb_2027),
[Next Fest juin 2027](https://partner.steamgames.com/doc/marketing/upcoming_events/nextfest/june_2027),
[règles du Next Fest](https://partner.steamgames.com/doc/marketing/upcoming_events/nextfest),
[démos sur Steam](https://partner.steamgames.com/doc/store/application/demos).

**Conseil : juin 2027.** Février demande d'avoir d'ici le 10 janvier une page Steam
publique avec bande-annonce, donc la vérification Steamworks, les 100 $ et la review
de la page en moins de huit semaines, fêtes comprises. Juin laisse le temps de
polir la démo, d'avoir une page anglaise et d'accumuler des listes de souhaits
avant le festival. La sortie en accès anticipé doit venir **après** le festival.

## Check-list Valve

Compte et page du jeu
- [ ] Vérification Steamworks terminée, 100 $ Steam Direct payés, App ID du jeu reçu.
- [ ] Page du jeu complet **publiée et publique** (« Prochainement »), avec au moins
      une bande-annonce visible (obligatoire pour le Next Fest).
- [ ] Tags justes (ils décident où le jeu apparaît pendant le festival).
- [ ] App ID mis dans `EditionDemo.APP_ID` (bouton Liste de souhaits).

Démo (une app à part, de type « Demo », liée au jeu)
- [ ] Créer la démo dans Steamworks (elle a son propre App ID, ses dépôts et builds).
- [ ] Envoyer la build exportée avec `-Demo` (MiniBlocsDemo.exe + .pck) dans le dépôt de la démo.
- [ ] Choisir : bouton « Télécharger la démo » sur la page du jeu (le plus simple) ou
      page de démo séparée (il faut alors une description propre à la démo, une
      bande-annonce et au moins 5 captures de la démo, et ne pas y annoncer ce qui
      n'est que dans le jeu complet ; avantage : les joueurs peuvent laisser des
      évaluations de la démo).
- [ ] Questionnaire de contenu de la démo cohérent avec son contenu.
- [ ] Capsules et images de bibliothèque qui disent clairement « Démo ».
- [ ] Succès Steam désactivés dans la démo (fait dans le code).
- [ ] Remplir les check-lists de la démo, la marquer prête pour la review, puis
      « Release Demo » ; republier la page du jeu pour que le bouton apparaisse.
- [ ] Steam envoie **un seul** e-mail aux listes de souhaits dans les deux semaines
      qui suivent la première sortie de la démo : la sortir quand elle est prête.

Next Fest
- [ ] S'inscrire depuis la page de l'app du **jeu** (pas de la démo), une ou deux catégories.
- [ ] Démo jouable publiquement au plus tard au début du festival (10 h, heure du Pacifique).
- [ ] Ne pas sortir le jeu avant la fin du festival.
- [ ] Facultatif : un direct pendant le festival (le tester avant).
