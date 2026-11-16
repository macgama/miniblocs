# Santé publique et épidémies

Panneau **F7** (menu Infos → Santé publique). Code : `scripts/sante/`
(`sante_publique.gd` = `SantePublique`, nœud « SantePublique » sous
`terre_main`, `SantePublique.instance` ; `sante_donnees.gd` = vaccins, mesures,
calendrier ; `sante_panel.gd` = panneau). Le moteur des épidémies reste
`scripts/evenements/epidemies.gd` (`Epidemies`). Test : `tests/sante_test.gd`.
Section de sauvegarde « sante ».

## Les maladies et leurs années

| Maladie | Passe par | Circule | Remarque |
|---|---|---|---|
| Grippe | l'air | toujours | surtout l'hiver ; vaccin dès 1945 (à refaire chaque année) |
| Gastro-entérite | les contacts | toujours | |
| Rougeole | l'air | toujours | surtout les enfants ; vaccin 1963 |
| Virus respiratoire | l'air | dès 1950 | |
| Choléra | **l'eau** | 1817 à 1923 | grandes vagues 1832, 1849, 1854, 1866, 1884, 1892 ; réhydratation dès 1945 |
| Typhoïde | **l'eau** | 1800 à 1960 | vaccin 1896 (moitié d'efficacité), antibiotiques 1948 |
| Variole | l'air | 1800 à 1977 | vaccine dès 1800 ; vague de 1870 |
| Diphtérie | les contacts | 1800 à 1990 | enfants ; sérum 1894, vaccin 1923 |
| Polio | les contacts | 1900 à 1990 | enfants ; vaccin 1955 |
| Grippe espagnole | l'air | 1918 à 1920 | tue surtout les jeunes adultes |
| Grippes asiatique, de Hong Kong | l'air | 1957, 1968 | |
| Covid-19 | l'air | 2020 à 2023 | vaccin 2021 |

Les épidémies au hasard (Admin F10 → catastrophes) ne tirent que les maladies
de l'année en cours. Les grandes épidémies (choléra, grippes de 1918, 1957,
1968, Covid-19) n'arrivent que par le **calendrier** : quand la partie commence
dans le passé, une rumeur paraît dans la gazette l'année d'avant, puis
l'épidémie arrive dans l'année (au plus tard l'année suivante). Une partie
commencée après une date ne la voit pas. F7 → Histoire : couper le calendrier,
voir les épidémies passées, provoquer une maladie du moment.

## L'eau, les égouts et l'hygiène

Chaque logement a une hygiène : eau du réseau (et sa qualité, `Reseaux.qualite_de`)
ou eau du puits ; égout raccordé et traité, égout qui finit à la rivière, ou
fosse d'aisance.

- Choléra et typhoïde : un malade sans égout souille les puits de son quartier
  (cases de 150 m, et un peu les cases voisines). Un malade raccordé à un égout
  sans station d'épuration salit la rivière, donc l'eau mal traitée du réseau.
  Un logement avec égouts et eau potable ne risque plus rien par l'eau.
- Avant 1950 (époques), un logement insalubre raccourcit un peu la vie
  (`Population.extra_health`), sauf si le réseau compte déjà son eau et ses
  égouts (`Reseaux.risque_sante`).

## Vaccins

Campagne : la ville paie chaque dose (de 3 € la vaccine à 20 € le Covid-19) ;
les doses par jour augmentent avec les hôpitaux, cliniques et médecins. Une
partie des habitants refuse selon l'époque (35 % en 1800, 6 % en 1960, 18 % en
2020) ; l'obligation vaccinale n'en laisse que 3 %, et vaccine aussi les
nouveaux venus et les enfants qui grandissent. Au-delà de 90 % de vaccinés,
la maladie ne prend plus (immunité collective).

## Mesures sanitaires

| Mesure | Dès | Effet | Satisfaction |
|---|---|---|---|
| Quarantaine | 1800 | contagion hors du foyer ÷3 | −1 |
| Fermer les écoles | 1800 | plus de contagion à l'école | −4 |
| Lazaret | 1800 | lits de campagne pour les cas graves | |
| Campagne d'hygiène | 1847 | contagion ×0,8, eau ×0,7 | |
| Faire bouillir l'eau | 1854 | contagion par l'eau ÷2,5 | −1 |
| Chlorer l'eau du réseau | 1902 | eau du réseau potable | |
| Masques | 1918 | contagion par l'air ×0,6 | −3 |
| Confinement | 1918 | contacts au travail ÷4, écoles fermées | −10 |

Coût par jour : un fixe + un montant par habitant (budget de la commune, poste
« Santé publique »). Les mesures temporaires (⏳) sont levées seules une
semaine après la fin de l'épidémie ; l'hygiène et le chlore restent.
Pendant une épidémie, la peur coûte aussi de 2 à 8 points de satisfaction.

## Hôpitaux et traitements

Les cas graves vont à l'hôpital en ambulance (comme avant). Les épidémies
prennent les lits laissés libres (40 % des lits) : au-delà, l'hôpital est
débordé et la létalité des hospitalisés est multipliée par 1,8. Le lazaret
compte comme un hôpital pour ceux qui n'en ont pas. Les traitements arrivent
avec l'histoire (sérum antidiphtérique 1894, antibiotiques 1945-1948).

## Contrats

- `Epidemies` appelle `protege(pid, maladie)`, `facteur_contagion(maladie, lieu)`,
  `contamines_eau(malades, maladie, rng)`, `facteur_letalite(maladie, hop, sans_hop)`,
  `lazaret()`, `immunite_collective(maladie)`, `noter_deces()`, `noter_fin()`.
  Sans `SantePublique`, les épidémies marchent comme avant.
- Avis : groupe `avis_sources`, facteur `sante_mesures` (thème « sante »,
  pour toute la ville) ; sinon chaîné dans `Population.extra_satisfaction`.
- Budget : groupe `budget_entretien` (mesures), dépenses « Vaccination ».
- Gazette : tout passe par `Evenements.news(…, "epidemie")`.
