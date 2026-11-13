# Le pays et les caisses des villes

Chaque ville (un village fondé par une Maison de commune) est indépendante : elle a sa
propre caisse, ses impôts, ses emprunts, son entretien des voies et sa tutelle. Au-dessus,
le **pays** a sa caisse à lui. Panneau **Pays** : touche **Maj+P** (menu Ville).

## Qui paie quoi

| Dépense | Caisse |
|---|---|
| Bâtiment, zonage, chantier sur le territoire d'une ville | cette ville |
| Voie, bâtiment hors de toute ville | le pays |
| Bâtiment fondateur (Maison de commune) d'une nouvelle ville | le pays |
| Entretien des voies | la ville où se trouve le milieu de la voie, sinon le pays |
| Panneaux et éditeurs (mobilier, blocs, réseaux…) | la ville gérée |
| Ventes des entreprises (impôt sur les bénéfices) | partagées entre les villes selon leur population |

La **ville gérée** est celle que regarde la caméra. Sa caisse s'affiche en haut de l'écran
(« Valfleuri : 4,2 M€ ») et la touche **M** ouvre son budget. Le bouton **Gérer** du panneau
Pays l'épingle (elle ne suit plus la caméra).

## La caisse du pays

- **Recettes** : l'argent de départ de la partie, l'impôt national (10 % des impôts locaux
  des villes, réglable de 0 à 30 %), les primes des objectifs.
- **Dépenses** : la dotation par habitant versée aux villes (réglable de 0 à 200 %),
  l'entretien des voies hors des villes, les subventions, le capital des nouvelles villes.
- Capital de départ : 60 % de la caisse du pays pour la toute première ville, puis 1 M€
  (× coût des constructions) pour chaque nouvelle ville.
- Un pays à sec ne verse plus de dotation. Il n'est jamais mis sous tutelle.

Le panneau Pays permet aussi de verser une **subvention** à une ville ou de faire
**reverser** de l'argent d'une ville au pays (seulement si tu en es le maire).

## Fusion et anciennes parties

- Deux villes qui fusionnent mettent leurs caisses et leurs emprunts en commun.
- Une partie d'avant le pays : 80 % de l'argent est partagé entre les villes selon leur
  population, 20 % reste au pays ; les impôts et les emprunts d'avant vont au chef-lieu.

## Pour les autres systèmes

`BuildingSystem.money` contient toujours la caisse **active**. Pour payer avec la caisse
d'un lieu :

```gdscript
var caisse_prev := Pays.au_rect(rect)   # ou au_point(x, z), au_batiment(bid), a_la_caisse(cle)
buildings.money -= prix
Pays.retour(caisse_prev)
```

Une recette globale : `Pays.crediter(buildings, euros)`. Le budget (`BudgetCommunal`) garde
un état par ville (`cle`, `etats`, `selectionner()`, `bilan_mensuel(cle)`, `bilan_pays()`).

Test : `godot --headless --path . --script res://tests/pays_test.gd`

## Élections dans chaque ville et mairie perdue

Chaque ville a ses municipales, son maire, son historique de satisfaction (panneau
**Avis**, touche **Y**, pour la ville gérée). Réglage Admin (F10 → Événements) **« Défaite :
mairie perdue »** (par défaut pour les nouvelles parties) :

- la liste gagnante prend la mairie : tu construis toujours dans la ville, mais impôts,
  emprunts et entretien sont décidés par son conseil (`GestionAuto`), selon son programme :
  contribuables (impôts 80 %), sécurité (100 %), écologie (110 %), solidarité (120 %) ;
- chaque semaine, le maire élu ajuste ses impôts (plus hauts si la caisse est dans le
  rouge, plus bas si elle déborde), l'entretien, emprunte ou rembourse ;
- ses promesses deviennent des objectifs : les tenir aide sa liste, les rater t'aide ;
- pour reprendre la mairie : gagner les municipales suivantes, ou lancer des élections
  anticipées quand une **pétition** circule (satisfaction sous 40).
