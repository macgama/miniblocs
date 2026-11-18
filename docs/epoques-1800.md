# Le XIXe siècle (1800-1900)

Une partie historique qui commence entre 1800 et 1900 a maintenant son propre contenu : bâtiments, véhicules, gares, musique et ambiances d'époque. Tout apparaît à sa date réelle (inventions datées) et disparaît peu à peu quand la ville se modernise.

## Tester dans Godot (4.7 ou plus)

1. Ouvrir le projet dans Godot, lancer avec **F5**.
2. **Nouvelle partie** → choisir une **année de départ** entre 1800 et 1900 (par exemple 1840).
3. **B** (catalogue) : les bâtiments du XIXe siècle portent « (dès 1840) » dans leur description. Zoner un quartier (R, C, I) : les maisons d'époque de la région poussent (longères en Bretagne, tulou hakka au Fujian, maisons victoriennes en Amérique…).
4. **L** (lignes) : poser une gare ou un port. Avant 1900 : quais bas en pierre, becs de gaz, marquise en fonte, quai en bois et grue à bras. Avant 1880, le bâtiment voyageurs est un petit **embarcadère**.
5. Rues et voies : la circulation n'a que des attelages, vélocipèdes, tramways à chevaux (dès 1853) ou à vapeur (dès 1876), locomotives Crampton, voiliers et vapeurs à roues.
6. **F2** (son) : la playlist ne joue que les 7 morceaux d'époque avant 1920 ; on les mélange aux morceaux modernes entre 1920 et 1950. En ville on entend les sabots, les roues cerclées, la forge, les crieurs ; dès 1830 un sifflet de locomotive au loin.
7. **F10 → Admin** (rythme de l'histoire, jusqu'à 25 ans par an de jeu) : accélérer l'histoire pour voir la ville changer de sons et de véhicules après 1900.

Tests automatiques :

```
godot --headless --path . --script res://tests/epoques_contenu_test.gd
godot --headless --path . --script res://tests/epoques_test.gd
godot --headless --path . --script res://tests/son_test.gd
```

Planches de captures : `godot --path . --script res://tests/epoques_contenu_vitrine.gd -- --dossier /chemin` (options `--groupe batiments|vehicules`, `--ids id1,id2`).

## Bâtiments (34, `scripts/epoques/epoques_batiments.gd`)

Chaque bâtiment reprend le rôle d'un bâtiment existant (`base`) : production, emplois, logements, tourisme, réseaux.

| Usage | Bâtiments |
|---|---|
| Logement | longère bretonne, maison de maître, maison des canuts (Lyon), échoppe bordelaise, rangée victorienne, maison de garde-barrière, tulou hakka (Chine), bungalow colonial (Inde), maison victorienne (États-Unis), cabane en rondins, maison coloniale (Afrique), cases obus (Cameroun) |
| Commerce, industrie | halle en fonte, compartiments chinois (Asie du Sud-Est), forge du maréchal-ferrant, halle aux marchandises, rotonde à locomotives, kura (entrepôt japonais) |
| Production, réseaux | ferme picarde à cour carrée, ferme comtoise, grange ronde (Shakers), moulin-tour en pierre, moulin à roue à aubes, manufacture à vapeur, puits de mine et chevalement, usine à gaz, château d'eau de gare |
| Services, loisirs | embarcadère (première gare), bureau de poste, relais de poste, lavoir, kiosque à musique en fonte, hammam, phare de granit |

## Véhicules (36 avec `"siecle": true`, `scripts/transport/vehicle_catalog.gd`)

- **Attelages** : fiacre, coupé de ville, cabriolet, char à bancs, malle-poste, haquet de brasseur, voiture du laitier, fardier, charrette à bœufs.
- **Deux-roues** : draisienne (1817), vélocipède (1867), bicyclette (1890).
- **Tramways** : à chevaux (1853), à vapeur (1876).
- **Trains** : locomotive Crampton (1849), 030 à marchandises (1855), locomotive-tender de banlieue (1880) ; voitures à compartiments, à impériale, wagon-lit (1876), fourgon, tombereau, wagon couvert, wagon à bestiaux, wagon plat.
- **Eau, air** : trois-mâts, clipper, vapeur à roues, steamer à hélice, remorqueur à vapeur, bateau-mouche, gabare, péniche de halage, bac à traille ; dirigeable Giffard (1852).

Dans une partie historique, une voiture moderne devient une voiture à cheval et un utilitaire un attelage de transport (`Epoques.ATTELAGES`). Dans une partie moderne, ces véhicules ne circulent pas.

## Son (`tools/sons/musique_epoque.py`, `tools/sons/ambiances_epoque.py`)

Tout est synthétisé (CC0), rien n'est enregistré : `python3 tools/build_sons.py musique` / `ambiance` / `effets`.

- Musiques : Menuet de la place du marché, Quadrille des diligences, L'orgue de barbarie du dimanche, Fanfare pour l'inauguration de la gare, Ragtime du saloon, Complainte du canal, Nocturne à la bougie.
- Ambiances : `ville_jour_ancien`, `ville_nuit_ancien`, `trafic_attelages` remplacent la ville et le trafic modernes avant 1900 (`AmbiancesSonores.NAPPES_ANCIENNES`) ; effet `sifflet_vapeur`.
