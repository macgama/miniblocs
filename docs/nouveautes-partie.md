# Partie depuis 1800 : les nouveautés du 15 novembre jouées ensemble

Banc `tests/nouveautes_partie.gd` : une ville fondée près de Bâle en 1800,
remplie (≈ 400 à 600 habitants), mise en pilote automatique, puis jouée
6 jours à chaque époque (1800, 1850, 1890, 1925, 1960, 2000, l'année est
sautée comme avec le réglage Admin). Le banc fait ce qu'un joueur ferait en
plus du pilote : poser les réseaux (courant, eau, égouts, gaz) quand les
habitants commencent à les attendre.

```bash
godot --headless --path . --script res://tests/nouveautes_partie.gd -- [--jours 6] [--hab 600] [--reel 600] [--periodes 1800,1960] [--rapport f.csv]
```

## Ce qui est vérifié

- **Époques** : calendrier en 1800, aucun bâtiment trop moderne posé (zonage,
  pilote), aucun véhicule trop moderne en circulation, l'année revient après
  chargement.
- **Gazette** : un numéro par jour, titre de l'époque (Gazette 1800, Courrier
  1850, Petit Journal 1890, Écho 1925, -Matin 1960, Infos 2000), numérotation
  gardée à la sauvegarde.
- **Commerce** : les cours bougent, 6 villes partenaires (Mulhouse, Zürich,
  Fribourg, Stuttgart, Rheinfelden, Laufen), une crise (krach) déclenchée,
  une offre signée, l'accord revient après chargement.
- **Succès** : débloqués au fil de la partie (11 sur 62 en fin de banc).
- **Plans de site** : le centre (360 × 360 m) enregistré et empaqueté pour le
  partage, puis reposé en 1800 : les modèles trop modernes sont refusés.
- **Mode photo** : il s'ouvre et rend la main ; **time-lapse** : une caméra
  posée à la fondation.
- **Scénario** « Course au bourg » : il démarre à l'époque actuelle, avance,
  et la gazette paraît.
- Aucune erreur de script de bout en bout.

## Bugs trouvés et corrigés

1. **Pilote automatique avant 1950** : il ne cherchait que les bâtiments
   modernes (`ecole`, `pompiers`, `police`, `hopital`), verrouillés avant
   1950. Une ville pilotée en 1800 n'avait donc ni école, ni pompiers, ni
   gendarmes, et le pilote **empruntait chaque jour pour une école qu'il ne
   pouvait pas bâtir**. Il prend maintenant le bâtiment d'époque qui joue le
   rôle (maison d'école, école de la République, remise des pompes, brigade de
   gendarmerie, Hôtel-Dieu…) et compte un bâtiment par son rôle
   (`PiloteAuto.type_d_epoque`, `compter` par `base_of`).
2. **Une école par jour** : tant que la première maison d'école était en
   chantier, ses élèves comptaient « sans école » et le pilote en lançait une
   nouvelle chaque jour (18 écoles pour 1 000 habitants). Il attend
   maintenant la fin du chantier ; pompiers et gendarmes passent enfin.
3. **Kit de l'État en 1800** : le message offrait l'électricité 125 ans
   avant son arrivée. Avant 1925 il dit que le bon d'électricité attendra son
   invention (le bon reste valable).
4. Un fichier `scripts/succes/succes_signaux.gd.uid` orphelin retiré.

## Résultats (conteneur sans carte graphique, 4 cœurs)

| Époque | Habitants | Écoles | Pompiers | Gendarmes | Pas moyen |
|---|---|---|---|---|---|
| 1800 | 813 | 1 | 1 | 1 | 36 ms |
| 1850 | 979 | 2 | 1 | 1 | 33 ms |
| 1890 | 1 005 | 2 | 1 | 1 | 39 ms |
| 1925 | 1 011 | 3 | 1 | 1 | 41 ms |
| 1960 | 1 071 | 3 | 1 | 1 | 56 ms |
| 2000 | 1 046 | 3 | 1 | 1 | 77 ms |

Un pas = 10 minutes de jeu par image (bien plus dense que le vrai jeu).
En temps réel (1 jour par minute) : image moyenne 12 à 26 ms selon les essais, p95 30 à 61 ms.
Banc `perf_ville` : 5,5 ms par image à 1 000 habitants, 9,5 ms à 5 000,
comme avant les nouveautés.

Reste à voir : il manque encore beaucoup de places d'école (≈ 190 enfants)
car une maison d'école n'a que 60 places et un chantier dure longtemps ;
le pilote ne pose pas les réseaux lui-même (c'était déjà le cas avant).
