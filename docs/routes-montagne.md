# Routes en montagne

Demande de Gaël (2026-11-19) : « il faut un peu de tolérance, sinon en montagne il
va être difficile de construire », puis « on pourrait créer des virages serrés ? ».

## Ce qui change à la pose d'une voie

1. **Pentes de montagne** (`TransportTypes.CLASSES`, `max_grade`) : valeurs relevées
   d'après les routes alpines suisses (VSS) et l'ARP en relief difficile.

   | Voie | Avant | Norme | Tolérée (orange) |
   |---|---|---|---|
   | Rue de desserte | 12 % | 12 % | 18 % |
   | Route départementale | 7 % | 10 % | 15 % |
   | Route à 2 + 1 voies | 6 % | 8 % | 12 % |
   | Voie express | 6 % | 7 % | 10,5 % |
   | Autoroute | 5 % | 6 % (ICTAAL L1) | 9 % |
   | Chemin de terre | 15 % | 18 % | 27 % |
   | Ligne ferroviaire classique | 25 ‰ | 30 ‰ (Gothard 27 ‰) | 37,5 ‰ |
   | Voie métrique | 40 ‰ | 70 ‰ (Bernina) | 87,5 ‰ |
   | LGV | 35 ‰ | 40 ‰ | 50 ‰ |
   | Tramway | 7 % | 8 % | 10 % |

   Routes et chemins : tolérance × 1,5 ; rails : × 1,25 (`TOLERANCE_PENTE`).

2. **Terrassement automatique** (`RoutePlanner.plan`) : si la pente dépasse la
   norme, une extrémité libre (pas raccordée à une voie) est creusée (en haut) ou
   remblayée (en bas) jusqu'à 3 m (`TERRASSEMENT_BOUT`). Le message affiche
   « bout terrassé de X m » et les volumes de déblai et de remblai.

3. **Zone orange** : au-delà de la norme et jusqu'à la tolérance, le tracé
   s'affiche en orange et se construit quand même. Il coûte plus cher et les
   véhicules y roulent moins vite. Le rouge ne bloque qu'au-delà.

4. **Virages en épingle** : chaque classe a un rayon d'épingle `r_epingle`
   (départementale 12 m au lieu de 240 m, rue 8 m, voie métrique 45 m…). Entre ce
   rayon et le rayon de la norme : zone orange. Pas d'épingle sur les autoroutes
   et voies express (rayon toléré 450 m et 300 m).

5. **Bouton « Lacets »** (à côté de « Courbe ») : la voie monte en épingles quand
   la ligne droite est trop raide. `RoutePlanner.lacets()` calcule des branches en
   travers de la pente (85 % de la pente de la norme) reliées par des arcs au
   rayon d'épingle × 1,15. Si la ligne droite suffit, elle est gardée ; si la place
   manque, le tracé reste droit (et rouge).

## Surcoût

Les voies ne coûtaient rien à poser ; seul le surcoût de montagne est payé, au fil
des travaux (`TransportSystem.appliquer_surcout`, via `ChantiersVoies.fixer_cout`) :

- gros terrassement : 12 €/m³ au-delà de 1 m de déblai ou de remblai ;
- zone orange : 30 €/m² de plate-forme (revêtement antidérapant, glissières,
  drainage renforcé).

Le multiplicateur de coût de la partie (Admin) s'applique.

## Vitesse

`TransportNetwork._measure` calcule pour chaque tronçon `lent` (part de la vitesse
normale) et `raide` (0 à 1) d'après sa géométrie : rien à sauvegarder, c'est
recalculé au chargement. Pente la plus forte tolérée : × 0,65 ; camions et
trains de fret perdent jusqu'à 30 % de plus. Tronçon à épingles : au moins × 0,5.
Pris en compte par la circulation (`Traffic`), l'affectation du trafic (`Trafic`)
et les temps de trajet des lignes (`TransitPlanner`).

## Tests

`godot --headless --path . --script res://tests/montagne_test.gd`
