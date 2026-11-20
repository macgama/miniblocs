# Modifier la façade et aménager l'intérieur

Sur la fiche d'un bâtiment (clic avec l'outil Observer, ou H), deux grandes
tuiles illustrées :

- **Modifier la façade** (pinceau) : style, couleurs (murs, toit, boiseries,
  volets, porte, vitres), forme du toit, étages, pente, variante. La maison
  change tout de suite ; un **devis** s'affiche en haut du panneau.
  « Valider les travaux » paie avec la caisse de la ville, « Annuler » (ou
  fermer le panneau) remet le bâtiment comme avant.
- **Aménager l'intérieur** (fauteuil) : un bâtiment du catalogue est refait en
  murs fins (vraies portes, escaliers, toit) avec ses couleurs, découpé en
  pièces et meublé, puis l'onglet Intérieur (mode Créer) s'ouvre dessus. Le prix
  du bâtiment est repris, on paie les murs et les meubles. Un bâtiment déjà en
  murs fins ouvre directement l'onglet Intérieur.

## Modèles classiques

Les modèles classiques MiniBlocs (maison, villa, petit immeuble, tour
d'habitation, boulangerie, supérette, bureaux, atelier, café, école :
`Personnalisation.CLASSIQUES`) sont dessinés en code sans style. Ils se refont
dans n'importe quel style du monde qui connaît leur archétype (clé `style` de la
personnalisation, `Personnalisation.type_of`). Changer une couleur sans choisir
de style pose le style par défaut (`STYLES_DEFAUT`) avec les couleurs d'origine,
pour rester proche du modèle.

## Prix des travaux (`Personnalisation.cout_travaux`)

Part du prix du bâtiment, 1 500 € au moins par poste :
peinture 3 % par couleur, toit 10 %, pente 4 %, étage 20 % par étage en plus ou
en moins, nouveau style 25 % (peinture et toit compris), variante 5 %.
« Appliquer aux autres » paie le devis de chacun.

Test : `tests/facade_test.gd`. Captures : `tests/facade_vitrine.gd --vue rue|fiche|panneau`.
