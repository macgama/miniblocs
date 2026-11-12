"""Registre des bâtiments de la bible : chaque module de famille déclare ses
bâtiments avec @batiment(...). Les champs suivent le catalogue du jeu
(scripts/batiments/building_catalog.gd) :

    id, name, cat (logement, commerce, industrie, production, services, loisirs, sport),
    cost (€), emplois, logements, visiteurs,
    metiers : [[clé de Metiers.METIERS, poids], …] (répartition des emplois),
    role : type de référence pour les mécaniques (ecole, hopital, culte, gymnase,
           piscine, theatre, cinema, cafe, maison, villa, ferme…),
    region, era (filtres du panneau, voir scripts/catalogue/styles.gd),
    desc (phrase courte), source (bâtiment réel ou type dont il s'inspire),
    variantes (nombre de variantes de couleur, 1 = toujours le même),
    access (["route"] ou ["route", "chemin"]), couleurs (couleurs propres), marge.
"""

FICHES = {}

ROUTE = ["route"]
ROUTE_CHEMIN = ["route", "chemin"]


def batiment(famille, id, name, cat, cost, desc, source="", region="europe", era="moderne", emplois=0,
             logements=0, visiteurs=0, metiers=None, role="", variantes=4, access=None, **extra):
    def deco(fn):
        fiche = {
            "id": id, "name": name, "cat": cat, "cost": int(cost), "desc": desc, "source": source,
            "region": region, "era": era, "emplois": int(emplois), "logements": int(logements),
            "visiteurs": int(visiteurs), "variantes": int(variantes),
            "access": access or (ROUTE_CHEMIN if cat in ("logement", "loisirs") else ROUTE),
            "fabrique": fn,
        }
        if metiers:
            fiche["metiers"] = metiers
        if role:
            fiche["role"] = role
        fiche.update(extra)
        FICHES.setdefault(famille, []).append(fiche)
        return fn
    return deco
