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

## Pilote automatique

Panneau Pays (Maj+P) → **Activer** sous une ville. Une fois par semaine de jeu, si tu en es
le maire :

1. budget tenu à l'équilibre (`GestionAuto`, programme « équilibre ») ;
2. **une** construction, la plus urgente, payée par la ville en gardant une réserve de
   3 mois de dépenses (200 k€ au moins) :
   - pas de rue : une rue de 300 m devant la mairie ;
   - logements presque pleins : zone résidentielle de 40 × 30 m le long d'une rue ;
   - services selon la population : école (60 hab., ou enfants sans école), aire de jeux (40),
     boulangerie (80), parc (150), pompiers et police (250), supérette (300), gymnase (600),
     hôpital (2 000) ;
   - chômage au-dessus de 12 % : zone commerciale ou industrielle ;
   - plus de place : une impasse est prolongée de 120 m, ou une rue est ouverte en travers.

Les dernières décisions s'affichent sous la ville. Code : `scripts/pays/pilote_auto.gd`.

## Objectifs (Maj+J)

Code : `scripts/pays/objectifs.gd` (nœud `Objectifs`, section de sauvegarde « objectifs »)
et `scripts/pays/objectifs_panel.gd`. Vérifié une fois par jour de jeu.

- **Rangs des villes** : Hameau, Village (100 hab., satisfaction 50), Bourg (500, 55, école,
  caisse saine), Ville (2 000, 55, + pompiers et police), Grande ville (10 000, 60, + hôpital
  et une ligne), Métropole (50 000). Chaque rang verse une prime au pays et ne se perd pas.
- **Missions** : 3 à la fois, tirées selon l'état des villes, avec un délai et une prime
  (× coût des constructions). Ratée : réputation −3 ; abandonnée : −1.
- **Succès** : 15, débloqués une fois pour toutes.
- **Réputation** (0 à 100, départ 20) : au-dessus de 20, le taux des emprunts baisse
  (jusqu'à −1 point, `Objectifs.bonus_taux()` dans `BudgetCommunal.taux_propose`).

Test : `godot --headless --path . --script res://tests/objectifs_test.gd`
