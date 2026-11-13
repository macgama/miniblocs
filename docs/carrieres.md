# Carrières et mines

Livré le 2026-11-13. Le code est dans `scripts/carrieres/`, le test dans `tests/carrieres_test.gd`, les captures dans `tests/carrieres_vitrine.gd`.

## Ce que ça fait

- **La roche sort vraiment du sol.** Une carrière, une sablière, une argilière ou une mine à ciel ouvert a un **périmètre d'extraction** à côté de ses installations. Chaque tonne extraite creuse la fosse : le relief descend pour de bon, gradin par gradin, en partant du côté des installations. Les cases taillées prennent un sol de roche (ou de sable).
- **Gradins réels** : 6 m de haut pour une carrière de roche, 4 m pour une sablière, 3 m pour une argilière, 10 m pour une mine à ciel ouvert, avec des risbermes (marches) de 3 à 6 m. Profondeur maximale : 42 m, 8 m, 9 m et 80 m sous le point le plus bas du bord.
- **Réserve = roche du périmètre** : volume que la fosse peut encore creuser, multiplié par la densité (2,6 t/m³ pour la roche, 1,7 pour le sable…) et par la richesse du gisement **sous le périmètre**. Un grand périmètre sur un bon gisement dure des années. Fosse pleine : « Gisement épuisé » (si l'épuisement est activé dans le panneau Admin ; sinon on continue d'extraire).
- **Stériles** : la découverte et la roche trop pauvre montent en **verse** à côté (15 % du volume pour une carrière, 2 m³ de stériles par m³ de minerai pour une mine à ciel ouvert). Les stériles d'une mine souterraine forment un **terril** en cône, jusqu'à 40 m.
- **Pose automatique** : à la construction, le jeu cherche le côté libre (ni bâtiment, ni voie, ni eau) le plus riche et y pose la fosse (110 m de côté pour une carrière, 90 m pour une sablière, 70 m pour une argilière, 200 m pour une mine à ciel ouvert ; plus petit si la place manque), puis la verse sur un autre côté.
- **Nouveau périmètre** : panneau **P → Mines → Nouveau périmètre**, puis glisser un rectangle (20 à 400 m de côté, à moins de 400 m des installations, 2 € le m² pour le bornage, le défrichement et l'autorisation). Ce qui a été creusé reste creusé.
- **Sondages** : sans sondage, l'aide de pose donne une **richesse estimée** (une fourchette) et pas de tonnage. **P → Mines → Faire un sondage** (15 000 €), puis clic sur le terrain : une foreuse travaille deux jours, puis donne la richesse exacte de toutes les roches et de tous les minerais. Les sites posés à moins de 250 m d'un sondage affichent leurs vrais chiffres.
- **Fin de vie** (à tout moment, le site ferme) : **plan d'eau** (le fond se remplit jusqu'à 1 m sous le bord, 60 000 €), **remblai** (la fosse est comblée et redevient prairie, 3 € par m³ creusé) ou **laisser** la fosse telle quelle (gratuit). Un nouveau périmètre rouvre le site.
- **Vie du site** : près de la caméra, une pelle hydraulique travaille sur le front et un ou deux tombereaux font la navette jusqu'aux installations, de 7 h à 17 h en semaine. Un **tir de mine** a lieu chaque jour de travail à midi dans les carrières de roche et les mines à ciel ouvert (nuage de poussière, message).
- **Nuisances** : `Carrieres.nuisances()` donne pour chaque site sa position, son bruit, son rayon, sa poussière et s'il travaille (pour la pollution, le bruit et la valeur foncière).
- **Métier nouveau** : boutefeu (tirs de mine) dans les carrières et les mines à ciel ouvert.

## Géologie réelle

| Ressource | D'où elle vient | Exemples de régions |
|---|---|---|
| Calcaire (et marbre) | 27 grandes régions calcaires réelles, plus un fond faible partout ; affleure sur les versants, la roche nue et en montagne | Bassin parisien, Jura, Causses, Provence, Vercors, Bourgogne, Carrare, Dolomites, Karst dinarique, Yucatán, Guilin, Ha Long |
| Granite | 21 massifs cristallins et boucliers réels, plus un fond faible | Bretagne, Massif central, Vosges, Corse, Mont-Blanc, Cornouailles, bouclier scandinave et canadien, Sierra Nevada |
| Sel gemme | 24 bassins salifères réels (gisements en taches, comme les minerais) | Lorraine (Varangéville), Jura (Salins), Cheshire, Wieliczka, Salzkammergut, Zechstein, Uyuni, Mer Morte |

Ce sont des faits géographiques (atlas, manuels de géologie). Plus tard, GLiM (carte lithologique mondiale, CC BY) pourra remplacer ces régions par une grille précise.

## Bâtiments

| Bâtiment | Extrait | Remarques |
|---|---|---|
| Carrière | granulats, calcaire ou granite (le plus riche) | fosse de roche, tirs de mine |
| Sablière et gravière | sable et graviers | fosse peu profonde, souvent en eau ensuite |
| Carrière d'argile | argile | fosse peu profonde |
| Mine à ciel ouvert (nouveau) | fer, charbon, cuivre, or, bauxite | 120 emplois, 25 M€, grande fosse, pelles et tombereaux géants |
| Mine souterraine | fer, charbon, cuivre, or, bauxite | réserve fixe, terril |
| Mine de sel (nouveau) | sel | réserve 1,5 Mt × richesse |

Chaînes nouvelles : **calcaire + argile → ciment** (cimenterie) ; **sel** dans l'usine agroalimentaire ; le **granite** (pierre de taille, 140 €/t) part à l'export en attendant que les chantiers consomment des matériaux.

## Code

- `fosse.gd` (`Fosse`) : géométrie d'une fosse en gradins ou d'une verse (signe −1 ou +1). Tout l'état tient dans le volume déplacé `vol` et les hauteurs d'origine `h0` : rejouer les passes redonne le même relief.
- `carrieres.gd` (`Carrieres`, nœud « Carrieres » de la scène Terre) : sites, pose automatique, périmètre dessiné, sondages, réaménagement, engins et tirs, sauvegarde (section `carrieres`).
- `engins.gd` (`EnginsCarriere`) : pelle hydraulique, tombereau, foreuse, poussière.
- Branchements dans `Production` : `extraction_gate` (raison qui bloque l'extraction) et le signal `extrait(bid, res, t)` à chaque tonne produite.
- Les cases creusées vont dans `TerrainWorld.modifications` (déjà sauvées avec le terrain) sans le message « cases modifiées ».

## Suite possible

- Rampe d'accès en spirale dans la fosse (les tombereaux montent aujourd'hui en ligne droite).
- Remontée de la nappe : une gravière près d'une rivière se remplit d'eau toute seule.
- Matériaux consommés par les chantiers (granulats, ciment, sable, granite).
- Marais salants sur les côtes chaudes (Guérande, Camargue).
- Bruit et poussière pris en compte par la pollution et la valeur foncière.
