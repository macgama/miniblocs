"""Bâtiments publics de la bible : culte, administration, culture, éducation,
santé, sécurité, sport couvert et gares. Formes simplifiées d'après des
bâtiments réels ou des types courants (champ `source`)."""

import math

from registre import batiment

F = "publics"


def facade(k, cx, cy, L, P, cote):
    return k._facades(cx, cy, L, P)[cote]


def baie(k, cx, cy, L, P, cote, u, z, l, h, vitre="vitre", cadre="cadre", forme="rect"):
    (fx, fy), n, _ = facade(k, cx, cy, L, P, cote)
    k.ouverture(fx, fy, n, u, z, l, h, vitre, cadre, forme)


def contreforts(k, cx, cy, L, P, h, nb, c, cotes=("gauche", "droite")):
    for cote in cotes:
        (fx, fy), n, lg = facade(k, cx, cy, L, P, cote)
        for i in range(nb + 1):
            u = -lg / 2 + i * lg / nb
            k.b.boite_mur(fx, fy, n, u - 0.35, u + 0.35, 0, h, 0.8, c, dessous=False)


# --- Culte ---------------------------------------------------------------------

@batiment(F, "eglise_romane", "Église romane", "services", 3_200_000,
          "Église de village en pierre, nef, abside et clocher carré.",
          "Églises romanes de Bourgogne et du Brionnais (XIe-XIIe s.)", era="traditionnel",
          emplois=2, visiteurs=150, metiers=[["agent_public", 1]], role="culte", variantes=2)
def eglise_romane(k):
    L, P, H = 9.0, 22.0, 8.0
    k.corps(0, 0, 0, L, P, 1, H, "pierre", fen={"gauche": 5, "droite": 5, "l": 0.8, "h": 2.0, "forme": "arc",
                                                "cadre": "pierre_claire", "vitre": "verre_nuit"},
            porte={"l": 1.8, "h": 3.2, "forme": "arc", "couleur": "bois_sombre", "cadre": "pierre_claire"})
    contreforts(k, 0, 0, L, P, 5.0, 5, "pierre_grise")
    k.toit_2pans(0, 0, H, P, L, 4.2, "tuile", axe="y", pignon="pierre", rangs=6, debord=0.3)
    baie(k, 0, 0, L, P, "avant", 0, 9.6, 1.6, 1.6, "verre_nuit", "pierre_claire", "rond")
    k.b.cylindre(0, P / 2, 0, 6.0, 3.6, "pierre", n=12, a0=0, a1=180)
    k.tronc_cone(0, P / 2, 6.0, 2.8, 3.9, 0, "tuile", n=12)
    k.clocher(L / 2 + 2.4, -P / 2 + 4.0, 0, 4.4, 15.0, "pierre", fleche="tuile", forme="pyramide", h_fleche=10)


@batiment(F, "cathedrale_gothique", "Cathédrale gothique", "services", 60_000_000,
          "Nef haute, bas-côtés, transept, deux tours à flèche et rosace.",
          "D'après la cathédrale Notre-Dame de Chartres et celle de Reims, très simplifiées", era="traditionnel",
          emplois=12, visiteurs=2500, metiers=[["agent_public", 3]], role="culte", variantes=1)
def cathedrale(k):
    L, P, H = 14.0, 56.0, 22.0
    k.corps(0, 0, 0, L, P, 1, H, "pierre_claire",
            fen={"gauche": 8, "droite": 8, "l": 2.2, "h": 6.0, "forme": "ogive", "cadre": "pierre",
                 "vitre": "verre_nuit", "rdc": True})
    for s in (-1, 1):
        x = s * (L / 2 + 3.5)
        k.corps(x, 2.0, 0, 7.0, P - 10, 1, 10.0, "pierre_claire",
                fen={"gauche" if s < 0 else "droite": 7, "l": 1.8, "h": 4.5, "forme": "ogive", "cadre": "pierre",
                     "vitre": "verre_nuit"})
        k.toit_mono(x - s * 0.0, 2.0, 10.0, 7.0, P - 10, 0.01, "ardoise", debord=0.2)
        contreforts(k, x, 2.0, 7.0, P - 10, 9.0, 7, "pierre", cotes=("gauche" if s < 0 else "droite",))
    k.toit_2pans(0, 0, H, P, L, 9.0, "ardoise", axe="y", pignon="pierre_claire", debord=0.3)
    # Transept.
    k.corps(0, 12.0, 0, 38.0, 12.0, 1, H, "pierre_claire",
            fen={"gauche": 1, "droite": 1, "l": 2.4, "h": 6.0, "forme": "ogive", "cadre": "pierre",
                 "vitre": "verre_nuit"})
    k.toit_2pans(0, 12.0, H, 38.0, 12.0, 8.0, "ardoise", axe="x", pignon="pierre_claire", debord=0.3)
    for s in (-1, 1):
        (fx, fy), n, _ = facade(k, 0, 12.0, 38.0, 12.0, "gauche" if s < 0 else "droite")
        k.ouverture(fx, fy, n, 0, 17.0, 5.0, 5.0, "verre_nuit", "pierre", "rond")
    # Chevet.
    k.b.cylindre(0, P / 2, 0, H, L / 2, "pierre_claire", n=14, a0=0, a1=180)
    k.tronc_cone(0, P / 2, H, 6.0, L / 2 + 0.3, 0, "ardoise", n=14)
    # Façade : deux tours, rosace, portails.
    for s in (-1, 1):
        x = s * 8.0
        k.boite(x, -P / 2 - 1.0, 0, 9.0, 9.0, 40.0, "pierre_claire")
        (fx, fy), n, _ = facade(k, x, -P / 2 - 1.0, 9.0, 9.0, "avant")
        for z in (14.0, 26.0):
            k.ouverture(fx, fy, n, 0, z, 2.6, 7.0, "verre_nuit", "pierre", "ogive")
        k.ouverture(fx, fy, n, 0, 35.5, 2.6, 5.5, "bois_sombre", "pierre", "ogive")
        k.porte(fx, fy, n, 0, 0, 3.4, 6.0, "bois_sombre", "pierre", "arc", marche=False)
        k.boite(x, -P / 2 - 1.0, 40.0, 9.6, 9.6, 0.6, "pierre")
        k.tronc(x, -P / 2 - 1.0, 40.6, 8.0, 8.0, 62.0, 0.01, 0.01, "pierre", dessus=False)
    k.boite(0, -P / 2 - 1.0, 0, 7.0, 7.0, 28.0, "pierre_claire")
    (fx, fy), n, _ = facade(k, 0, -P / 2 - 1.0, 7.0, 7.0, "avant")
    k.ouverture(fx, fy, n, 0, 19.0, 6.0, 6.0, "verre_nuit", "pierre", "rond")
    k.porte(fx, fy, n, 0, 0, 4.4, 8.0, "bois_sombre", "pierre", "arc", marche=False)
    k.boite(0, -P / 2 - 1.0, 28.0, 7.4, 7.4, 0.6, "pierre")


@batiment(F, "chapelle_alpine", "Chapelle alpine", "services", 650_000,
          "Petite chapelle blanche à clocheton, toit de bardeaux.",
          "Chapelles du Valais et des Grisons", era="traditionnel",
          emplois=1, visiteurs=40, metiers=[["agent_public", 1]], role="culte", variantes=2,
          access=["route", "chemin"])
def chapelle(k):
    L, P, H = 6.0, 10.0, 5.0
    k.corps(0, 0, 0, L, P, 1, H, "enduit_blanc",
            fen={"gauche": 2, "droite": 2, "l": 0.7, "h": 1.5, "forme": "arc", "cadre": "pierre_grise"},
            porte={"l": 1.3, "h": 2.4, "forme": "arc", "couleur": "bois_sombre", "cadre": "pierre_grise"},
            socle="pierre_grise")
    k.toit_2pans(0, 0, H, P, L, 3.6, "bois_gris", axe="y", pignon="enduit_blanc", rangs=6, debord=0.5)
    k.b.cylindre(0, P / 2, 0, 4.2, 2.4, "enduit_blanc", n=10, a0=0, a1=180)
    k.tronc_cone(0, P / 2, 4.2, 2.2, 2.6, 0, "bois_gris", n=10)
    k.boite(0, -P / 2 + 1.2, H + 3.0, 1.6, 1.6, 2.2, "enduit_blanc")
    (fx, fy), n, _ = facade(k, 0, -P / 2 + 1.2, 1.6, 1.6, "avant")
    k.ouverture(fx, fy, n, 0, H + 4.2, 0.6, 1.0, "noir", None, "arc")
    k.tronc(0, -P / 2 + 1.2, H + 5.2, 1.9, 1.9, H + 8.5, 0.01, 0.01, "zinc", dessus=False)


@batiment(F, "eglise_baroque", "Église baroque à bulbe", "services", 7_500_000,
          "Église claire à pilastres et clocher à bulbe de cuivre.",
          "Églises baroques de Bavière et du Tyrol (Wieskirche, Saint-Oswald de Seefeld)", era="classique",
          emplois=3, visiteurs=400, metiers=[["agent_public", 2]], role="culte", variantes=2)
def eglise_baroque(k):
    L, P, H = 13.0, 30.0, 12.0
    k.corps(0, 0, 0, L, P, 1, H, "enduit_jaune",
            fen={"gauche": 5, "droite": 5, "l": 1.6, "h": 4.0, "forme": "arc", "cadre": "enduit_blanc",
                 "vitre": "vitre"},
            porte={"l": 2.2, "h": 3.8, "forme": "arc", "couleur": "bois_rouge", "cadre": "enduit_blanc"})
    contreforts(k, 0, 0, L, P, H, 5, "enduit_blanc", cotes=("gauche", "droite", "avant"))
    k.toit_2pans(0, 0, H, P, L, 6.0, "tuile", axe="y", pignon="enduit_jaune", debord=0.4)
    k.b.cylindre(0, P / 2, 0, H, L / 2 - 0.5, "enduit_jaune", n=12, a0=0, a1=180)
    k.tronc_cone(0, P / 2, H, 4.5, L / 2, 0, "tuile", n=12)
    k.clocher(0, -P / 2 - 2.6, 0, 5.2, 26.0, "enduit_jaune", fleche="cuivre", forme="bulbe", horloge=True)
    k.tronc_cone(0, -P / 2 - 2.6, 26.3 + 1.2 + 5.6, 3.0, 0.5, 0, "cuivre", n=8)


@batiment(F, "temple_protestant", "Temple réformé", "services", 2_400_000,
          "Temple sobre en molasse, grandes fenêtres et clocher à flèche.",
          "Temples vaudois et neuchâtelois (XVIIIe-XIXe s.)", era="classique",
          emplois=1, visiteurs=200, metiers=[["agent_public", 1]], role="culte", variantes=2)
def temple(k):
    L, P, H = 12.0, 18.0, 9.0
    k.corps(0, 0, 0, L, P, 1, H, "pierre_claire",
            fen={"gauche": 4, "droite": 4, "arriere": 2, "l": 1.4, "h": 4.0, "forme": "arc", "cadre": "pierre"},
            porte={"l": 1.6, "h": 3.0, "forme": "arc", "couleur": "vert", "cadre": "pierre"})
    k.toit_4pans(0, 0, H, L, P, 4.0, "tuile", debord=0.5)
    k.clocher(0, -P / 2 - 2.0, 0, 4.0, 18.0, "pierre_claire", fleche="ardoise", horloge=True, h_fleche=12)


@batiment(F, "eglise_orthodoxe", "Église orthodoxe", "services", 9_000_000,
          "Église blanche à cinq bulbes dorés et bleus.",
          "D'après les églises russes à cinq coupoles (cathédrale de la Dormition de Vladimir)",
          region="europe", era="traditionnel", emplois=3, visiteurs=500, metiers=[["agent_public", 2]],
          role="culte", variantes=2)
def orthodoxe(k):
    L, P, H = 18.0, 20.0, 13.0
    k.corps(0, 0, 0, L, P, 1, H, "enduit_blanc",
            fen={"avant": 3, "gauche": 3, "droite": 3, "arriere": 3, "l": 1.1, "h": 3.2, "forme": "arc",
                 "cadre": "pierre_claire", "vitre": "verre_nuit"},
            porte={"l": 2.2, "h": 3.6, "forme": "arc", "couleur": "bois_rouge", "cadre": "or"})
    for cote in ("avant", "arriere", "gauche", "droite"):
        (fx, fy), n, lg = facade(k, 0, 0, L, P, cote)
        k.b.boite_mur(fx, fy, n, -lg / 2, lg / 2, H - 0.6, H, 0.3, "pierre_claire")
    k.toit_plat(0, 0, H, L, P, "zinc", acrotere=0.0)
    for (x, y, r, h, c) in ((0, 0, 3.4, 7.0, "or"), (-5.5, -5.5, 2.0, 4.0, "bleu"), (5.5, -5.5, 2.0, 4.0, "bleu"),
                            (-5.5, 5.5, 2.0, 4.0, "bleu"), (5.5, 5.5, 2.0, 4.0, "bleu")):
        k.cyl(x, y, H + 0.3, h, r * 0.85, "enduit_blanc", n=10)
        k.bulbe(x, y, H + 0.3 + h, r, r * 2.4, c, n=10)
        k.boite(x, y, H + 0.3 + h + r * 2.4 - 0.1, 0.12, 0.12, 1.4, "or")
    k.b.cylindre(0, P / 2, 0, H - 2, 5.0, "enduit_blanc", n=10, a0=0, a1=180)


@batiment(F, "mosquee", "Mosquée", "services", 14_000_000,
          "Salle de prière à grande coupole, demi-coupoles et deux minarets.",
          "D'après les mosquées ottomanes de Sinan (Süleymaniye, Istanbul), simplifiée",
          region="moyen_orient", era="traditionnel", emplois=4, visiteurs=900,
          metiers=[["agent_public", 2]], role="culte", variantes=1)
def mosquee(k):
    L, P, H = 26.0, 26.0, 12.0
    k.corps(0, 0, 0, L, P, 2, H / 2, "pierre_claire",
            fen={"avant": 5, "gauche": 5, "droite": 5, "arriere": 5, "l": 1.2, "h": 2.4, "forme": "arc",
                 "cadre": "pierre", "vitre": "verre_nuit"},
            porte={"l": 2.6, "h": 4.2, "forme": "arc", "couleur": "bois_sombre", "cadre": "pierre"})
    k.toit_plat(0, 0, H, L, P, "zinc", acrotere=0.4, c_acrotere="pierre_claire")
    k.cyl(0, 0, H, 3.0, 9.0, "pierre_claire", n=16)
    k.dome(0, 0, H + 3.0, 9.0, "zinc", n=16, anneaux=4, lanterne="or")
    for (x, y) in ((0, -9), (0, 9), (-9, 0), (9, 0)):
        k.dome(x, y, H, 4.0, "zinc", n=12, anneaux=2)
    # Cour à portique devant.
    k.sol(0, -P / 2 - 9, L, 18, "pierre_claire")
    k.arcade(0, -P / 2 - 9, 0, L, 8, 4.0, 3.0, "pierre_claire", cote_y=-P / 2 - 15.5)
    for s in (-1, 1):
        x, y = s * (L / 2 + 2.5), -P / 2 + 1
        k.cyl(x, y, 0, 36.0, 1.3, "pierre_claire", n=10)
        for z in (20.0, 30.0):
            k.cyl(x, y, z, 0.6, 1.9, "pierre", n=10)
        k.tronc_cone(x, y, 36.0, 7.0, 1.4, 0, "zinc", n=10)


@batiment(F, "synagogue", "Synagogue", "services", 6_000_000,
          "Façade néo-mauresque à arcs, deux tourelles à petites coupoles.",
          "D'après la synagogue Beth Yaacov de Genève et les synagogues néo-mauresques du XIXe s.",
          era="classique", emplois=2, visiteurs=300, metiers=[["agent_public", 1]], role="culte", variantes=2)
def synagogue(k):
    L, P, H = 16.0, 22.0, 11.0
    k.corps(0, 0, 0, L, P, 2, H / 2, "brique_claire",
            fen={"gauche": 4, "droite": 4, "avant": 3, "l": 1.2, "h": 2.6, "forme": "arc", "cadre": "pierre_claire"},
            porte={"l": 2.4, "h": 3.6, "forme": "arc", "couleur": "bois_sombre", "cadre": "pierre_claire"},
            bandeaux="pierre_claire")
    k.toit_plat(0, 0, H, L, P, "zinc", acrotere=0.5, c_acrotere="pierre_claire")
    k.cyl(0, 2, H + 0.8, 1.5, 4.5, "brique_claire", n=12)
    k.dome(0, 2, H + 2.3, 4.5, "cuivre", n=12, anneaux=3)
    for s in (-1, 1):
        x = s * (L / 2 - 1.2)
        k.boite(x, -P / 2 + 1.2, 0, 2.6, 2.6, H + 4.0, "brique_claire")
        k.dome(x, -P / 2 + 1.2, H + 4.0, 1.4, "cuivre", n=8, anneaux=2)


@batiment(F, "pagode", "Pagode à cinq toits", "services", 5_500_000,
          "Pagode de bois à cinq étages de toits débordants.",
          "D'après la pagode du Hōryū-ji (Nara, Japon)", region="asie_est", era="traditionnel",
          emplois=2, visiteurs=350, metiers=[["agent_public", 1]], role="culte", variantes=1, sans_vitres=1)
def pagode(k):
    k.boite(0, 0, 0, 14.0, 14.0, 1.2, "pierre_claire")
    z = 1.2
    for i in range(5):
        c = 9.0 - i * 1.1
        h = 3.6 if i == 0 else 2.6
        k.boite(0, 0, z, c, c, h, "bois_rouge")
        for cote in ("avant", "arriere", "gauche", "droite"):
            (fx, fy), n, _ = facade(k, 0, 0, c, c, cote)
            k.ouverture(fx, fy, n, 0, z + h * 0.5, c * 0.3, h * 0.55, "bois_sombre", "blanc")
        z += h
        d = 2.6 - i * 0.2
        k.tronc(0, 0, z, c + 2 * d, c + 2 * d, z + 1.4, c - 0.6, c - 0.6, "ardoise",
                dessus=True)
        k.boite(0, 0, z - 0.25, c + 2 * d, c + 2 * d, 0.25, "bois_sombre")
        z += 1.4
    k.cyl(0, 0, z, 8.0, 0.25, "or", n=6)
    for j in range(5):
        k.cyl(0, 0, z + 1.5 + j * 1.2, 0.2, 0.7, "or", n=8)


# --- Administration et culture ------------------------------------------------------

@batiment(F, "mairie_village", "Mairie de village", "services", 1_800_000,
          "Mairie-école à fronton, horloge et drapeau.",
          "Mairies-écoles françaises de la IIIe République", era="classique",
          emplois=6, metiers=[["agent_public", 4], ["cadre", 1]], role="mairie", variantes=3)
def mairie_village(k):
    L, P = 16.0, 10.0
    k.corps(0, 0, 0, L, P, 2, 3.6, "enduit",
            fen={"avant": 5, "arriere": 5, "gauche": 2, "droite": 2, "l": 1.1, "h": 1.9, "volets": "volet",
                 "appui": "pierre_claire"},
            porte={"l": 1.6, "h": 2.7, "couleur": "porte"}, socle="pierre_grise", bandeaux="pierre_claire",
            chaines="pierre_claire")
    k.toit_4pans(0, 0, 7.2, L, P, 3.6, "ardoise", debord=0.4)
    (fx, fy), n, _ = facade(k, 0, 0, L, P, "avant")
    k.b.boite_mur(fx, fy, n, -2.6, 2.6, 7.2, 9.2, 0.2, "enduit")
    k.f([(-2.8, -P / 2 - 0.2, 9.2), (2.8, -P / 2 - 0.2, 9.2), (0, -P / 2 - 0.2, 10.6)], "pierre_claire", vers=(0, -1, 0))
    k.ouverture(fx, fy, n, 0, 8.3, 1.2, 1.2, "blanc", "noir", "rond", w=0.2)
    k.boite(-L / 2 - 0.6, -P / 2 - 0.8, 0, 0.12, 0.12, 9.0, "blanc")
    k.boite(-L / 2 + 0.2, -P / 2 - 0.8, 7.6, 1.6, 0.05, 1.1, "bleu")


@batiment(F, "hotel_de_ville", "Hôtel de ville à beffroi", "services", 18_000_000,
          "Grand hôtel de ville à arcades et beffroi de 55 m.",
          "D'après l'hôtel de ville et le beffroi d'Arras (Pas-de-Calais)", era="traditionnel",
          emplois=60, metiers=[["agent_public", 6], ["cadre", 2], ["employe", 2]], role="mairie", variantes=1)
def hotel_de_ville(k):
    L, P = 34.0, 16.0
    k.arcade(0, 0, 0, L, 9, 4.5, 3.0, "pierre_claire", cote_y=-P / 2)
    k.corps(0, 0, 0, L, P, 3, 4.5, "pierre_claire",
            fen={"avant": 9, "arriere": 9, "gauche": 3, "droite": 3, "l": 1.4, "h": 2.6, "forme": "ogive",
                 "cadre": "pierre", "rdc": False},
            porte={"l": 2.4, "h": 3.4, "couleur": "bois_sombre", "forme": "arc"})
    k.toit_2pans(0, 0, 13.5, L, P, 8.0, "ardoise", axe="x", pignon="pierre_claire", debord=0.3)
    for i in range(6):
        x = -L / 2 + 3 + i * (L - 6) / 5
        k.boite(x, -P / 2 + 1.0, 14.0, 1.6, 1.2, 2.2, "pierre_claire")
        k.toit_2pans(x, -P / 2 + 1.0, 16.2, 1.2, 1.6, 1.0, "ardoise", axe="y", debord=0.1, pignon="pierre_claire")
    k.boite(L / 2 + 4.0, 2.0, 0, 8.0, 8.0, 34.0, "pierre_claire")
    for cote in ("avant", "droite", "gauche", "arriere"):
        (fx, fy), n, _ = facade(k, L / 2 + 4.0, 2.0, 8.0, 8.0, cote)
        k.ouverture(fx, fy, n, 0, 30.0, 2.2, 2.2, "blanc", "noir", "rond", w=0.0)
        k.ouverture(fx, fy, n, 0, 24.0, 1.6, 5.0, "verre_nuit", "pierre", "ogive")
    k.boite(L / 2 + 4.0, 2.0, 34.0, 9.0, 9.0, 0.8, "pierre")
    k.cyl(L / 2 + 4.0, 2.0, 34.8, 8.0, 3.0, "pierre_claire", n=8)
    k.dome(L / 2 + 4.0, 2.0, 42.8, 3.2, "zinc", n=8, anneaux=2, h=4.0)
    k.tronc_cone(L / 2 + 4.0, 2.0, 46.8, 7.0, 1.0, 0, "zinc", n=8)


@batiment(F, "palais_justice", "Palais de justice", "services", 22_000_000,
          "Palais néo-classique à colonnade, fronton et grand perron.",
          "D'après le palais de justice de Lyon (« les 24 colonnes ») et celui de Paris", era="classique",
          emplois=80, metiers=[["cadre", 4], ["employe", 4], ["agent_public", 2], ["policier", 1]],
          role="palais", variantes=1)
def palais_justice(k):
    L, P, H = 40.0, 24.0, 14.0
    k.boite(0, 0, 0, L + 2, P + 2, 1.6, "pierre_grise")
    k.corps(0, 0, 1.6, L, P, 2, 6.2, "pierre_claire",
            fen={"gauche": 5, "droite": 5, "arriere": 9, "avant": 9, "l": 1.6, "h": 3.0, "forme": "arc",
                 "cadre": "pierre"}, bandeaux="pierre")
    k.toit_plat(0, 0, 14.0, L, P, "zinc", acrotere=1.2, c_acrotere="pierre_claire")
    k.colonnes(0, -P / 2 - 2.0, 1.6, 30.0, 10, 11.0, 0.7, "pierre_claire", fronton="zinc", prof=4.0)
    for i in range(6):
        k.boite(0, -P / 2 - 4.2 - i * 0.45, 0, 32.0, 0.45, 1.6 - i * 0.26, "pierre_grise")


@batiment(F, "palais_federal", "Parlement à coupole", "services", 90_000_000,
          "Grand palais de grès vert avec coupole centrale et deux ailes.",
          "D'après le Palais fédéral de Berne (1902)", era="classique",
          emplois=300, metiers=[["cadre", 5], ["employe", 4], ["agent_public", 3]], role="palais", variantes=1)
def palais_federal(k):
    for x, L in ((0, 30.0), (-31.0, 32.0), (31.0, 32.0)):
        P = 26.0 if x == 0 else 18.0
        k.corps(x, 0 if x == 0 else 4, 0, L, P, 4, 4.4, "pierre_grise" if x else "pierre_claire",
                fen={"avant": 8, "arriere": 8, "gauche": 4, "droite": 4, "l": 1.4, "h": 2.4, "forme": "arc" if x == 0
                     else "rect", "cadre": "pierre_claire"}, socle="granit", bandeaux="pierre_claire")
        k.toit_4pans(x, 0 if x == 0 else 4, 17.6, L, P, 4.0, "cuivre", debord=0.3)
    k.colonnes(0, -15.0, 0.4, 20.0, 6, 12.0, 0.8, "pierre_claire", fronton="cuivre", prof=4.0)
    k.cyl(0, 2.0, 21.0, 8.0, 7.5, "pierre_claire", n=14)
    k.dome(0, 2.0, 29.0, 7.8, "cuivre", n=14, anneaux=4, h=10.0, lanterne="cuivre")


@batiment(F, "poste", "Bureau de poste", "services", 1_500_000,
          "Bureau de poste en pierre, guichets au rez-de-chaussée.",
          "Bureaux de poste suisses et français des années 1920-1930", era="classique",
          emplois=10, visiteurs=200, metiers=[["agent_public", 3], ["chauffeur", 2]], variantes=3)
def poste(k):
    L, P = 18.0, 12.0
    k.corps(0, 0, 0, L, P, 2, 4.0, "pierre_claire",
            fen={"avant": 5, "arriere": 5, "gauche": 3, "droite": 3, "l": 1.3, "h": 2.3, "forme": "arc",
                 "cadre": "pierre"},
            porte={"l": 2.0, "h": 3.0, "couleur": "jaune", "auvent": "noir"}, socle="granit", bandeaux="pierre")
    k.toit_4pans(0, 0, 8.0, L, P, 3.0, "tuile", debord=0.5)
    (fx, fy), n, _ = facade(k, 0, 0, L, P, "avant")
    k.b.boite_mur(fx, fy, n, -3.0, 3.0, 4.4, 5.0, 0.15, "jaune")


@batiment(F, "bibliotheque", "Médiathèque", "services", 12_000_000,
          "Médiathèque contemporaine, grand volume de verre et lames de bois.",
          "D'après les médiathèques françaises des années 2000 (Bordeaux, Lyon)", era="contemporain",
          emplois=20, visiteurs=600, metiers=[["agent_public", 3], ["employe", 1]], variantes=2)
def bibliotheque(k):
    L, P = 32.0, 22.0
    k.corps(0, 0, 0, L, P, 3, 4.5, "bois_clair",
            fen={"avant": 1, "arriere": 1, "gauche": 1, "droite": 1, "bande": True, "h": 3.2, "vitre": "verre_ciel"},
            porte={"l": 4.0, "h": 3.0, "couleur": "verre_nuit", "cadre": "noir"})
    (fx, fy), n, lg = facade(k, 0, 0, L, P, "avant")
    for i in range(18):
        u = -lg / 2 + 0.8 + i * (lg - 1.6) / 17
        k.b.boite_mur(fx, fy, n, u - 0.1, u + 0.1, 4.5, 13.5, 0.4, "bois_rouge", dessous=True)
    k.toit_plat(0, 0, 13.5, L, P, "beton_sombre", acrotere=0.3, c_acrotere="blanc")
    k.boite(-L / 2 + 6, 0, 13.8, 10.0, 10.0, 3.0, "blanc")


@batiment(F, "musee_classique", "Musée des beaux-arts", "loisirs", 30_000_000,
          "Musée néo-classique à portique ionique et salles éclairées par le toit.",
          "D'après le British Museum (Londres) et le musée des Beaux-Arts de Lille", era="classique",
          emplois=40, visiteurs=1500, metiers=[["agent_public", 3], ["vendeur", 1], ["cadre", 1]],
          role="musee", variantes=1)
def musee_classique(k):
    L, P, H = 44.0, 28.0, 13.0
    k.boite(0, 0, 0, L + 2, P + 2, 1.4, "pierre_grise")
    k.corps(0, 0, 1.4, L, P, 1, H - 1.4, "pierre_claire",
            fen={"gauche": 6, "droite": 6, "arriere": 8, "l": 1.4, "h": 4.0, "forme": "rect", "cadre": "pierre",
                 "vitre": "verre_nuit"})
    k.toit_plat(0, 0, H, L, P, "zinc", acrotere=1.0, c_acrotere="pierre_claire")
    k.toit_2pans(0, 0, H + 1.3, L - 12, 8.0, 2.0, "verre_ciel", axe="x", debord=0.0, pignon="pierre_claire",
                 sous="verre_ciel", ep=0.05)
    k.colonnes(0, -P / 2 - 2.0, 1.4, 26.0, 8, 10.0, 0.65, "pierre_claire", fronton="zinc", prof=4.0)
    for i in range(5):
        k.boite(0, -P / 2 - 4.2 - i * 0.45, 0, 28.0, 0.45, 1.4 - i * 0.28, "pierre_grise")


@batiment(F, "musee_contemporain", "Musée d'art contemporain", "loisirs", 40_000_000,
          "Boîtes blanches empilées et décalées, bandeaux de verre.",
          "D'après le New Museum de New York (SANAA, 2007)", region="ameriques", era="contemporain",
          emplois=35, visiteurs=1200, metiers=[["agent_public", 3], ["vendeur", 1], ["cadre", 1]],
          role="musee", variantes=1)
def musee_contemporain(k):
    z = 0.0
    for (dx, dy, L, P, h) in ((0, 0, 22, 20, 7), (1.5, -1.0, 20, 18, 6), (-1.0, 1.0, 22, 17, 5.5),
                              (2.0, 0.0, 18, 18, 6.5), (-1.5, 1.5, 16, 15, 5), (0.5, 0.0, 14, 13, 4.5)):
        k.boite(dx, dy, z, L, P, h, "blanc")
        k.boite(dx, dy, z + h - 0.01, L - 0.3, P - 0.3, 0.6, "verre_ciel")
        z += h + 0.6
    (fx, fy), n, _ = facade(k, 0, 0, 22, 20, "avant")
    k.ouverture(fx, fy, n, 0, 1.8, 14.0, 3.0, "verre_clair", "noir")


@batiment(F, "opera", "Opéra", "loisirs", 120_000_000,
          "Façade à loggia et colonnes, coupole et grande cage de scène.",
          "D'après l'Opéra Garnier (Paris, 1875), très simplifié", era="classique",
          emplois=150, visiteurs=2000, metiers=[["comedien", 4], ["agent_public", 1], ["serveur", 1]],
          role="theatre", variantes=1)
def opera(k):
    k.boite(0, -6, 0, 52, 30, 2.0, "pierre_grise")
    k.corps(0, -8, 2.0, 46, 22, 2, 7.0, "pierre_claire",
            fen={"avant": 7, "gauche": 3, "droite": 3, "l": 2.0, "h": 4.0, "forme": "arc", "cadre": "pierre",
                 "vitre": "verre_nuit"}, bandeaux="or")
    k.colonnes(0, -20.5, 9.0, 40.0, 16, 7.0, 0.55, "pierre_claire", prof=2.5)
    k.toit_plat(0, -8, 16.0, 46, 22, "cuivre", acrotere=1.5, c_acrotere="pierre_claire")
    for s in (-1, 1):
        k.boite(s * 21.0, -18.0, 17.5, 4.0, 2.0, 3.0, "or")
    k.cyl(0, 10, 0, 20.0, 18.0, "pierre_claire", n=16)
    k.dome(0, 10, 20.0, 18.0, "cuivre", n=16, anneaux=3, h=8.0, lanterne="or")
    k.boite(0, 34, 0, 40, 26, 36.0, "pierre_claire")
    k.toit_2pans(0, 34, 36.0, 40, 26, 6.0, "cuivre", axe="x", pignon="pierre_claire", debord=0.3)
    k.boite(0, 34 - 13.4, 36.0, 4.0, 0.6, 7.0, "or")


@batiment(F, "theatre", "Théâtre municipal", "loisirs", 15_000_000,
          "Théâtre à l'italienne de ville moyenne, fronton et cage de scène.",
          "Théâtres municipaux du XIXe s. (Lausanne, Besançon)", era="classique",
          emplois=25, visiteurs=700, metiers=[["comedien", 3], ["agent_public", 1], ["serveur", 1]],
          role="theatre", variantes=2)
def theatre(k):
    k.corps(0, 0, 0, 24, 18, 3, 4.2, "enduit_jaune",
            fen={"avant": 5, "gauche": 4, "droite": 4, "l": 1.4, "h": 2.6, "forme": "arc", "cadre": "pierre_claire"},
            porte={"l": 3.0, "h": 3.2, "couleur": "bois_rouge", "auvent": "noir"}, socle="pierre_grise",
            bandeaux="pierre_claire")
    k.toit_2pans(0, 0, 12.6, 24, 18, 4.0, "zinc", axe="y", pignon="enduit_jaune", debord=0.3)
    k.boite(0, 16.0, 0, 22.0, 14.0, 20.0, "enduit_jaune")
    k.toit_2pans(0, 16.0, 20.0, 22.0, 14.0, 3.0, "zinc", axe="x", pignon="enduit_jaune", debord=0.2)


@batiment(F, "cinema_multiplexe", "Cinéma multiplexe", "loisirs", 18_000_000,
          "Douze salles, hall vitré et enseigne lumineuse.",
          "Multiplexes de périphérie (Pathé, UGC, Kinepolis)", era="contemporain",
          emplois=30, visiteurs=2500, metiers=[["agent_cinema", 4], ["vendeur", 1], ["cadre", 1]], role="cinema",
          variantes=2)
def multiplexe(k):
    k.boite(0, 6, 0, 56, 40, 16, "bardage")
    k.toit_plat(0, 6, 16, 56, 40, "beton_sombre", acrotere=0.6, c_acrotere="noir")
    k.boite(0, -16, 0, 30, 8, 12, "verre_bleu")
    k.toit_plat(0, -16, 12, 30, 8, "noir", acrotere=0.4, c_acrotere="noir")
    (fx, fy), n, _ = facade(k, 0, 6, 56, 40, "avant")
    k.b.boite_mur(fx, fy, n, -12, 12, 12.8, 15.4, 0.4, "rouge")
    k.b.boite_mur(fx, fy, n, -10, 10, 13.2, 15.0, 0.5, "jaune")


@batiment(F, "salle_fetes", "Salle des fêtes", "loisirs", 2_200_000,
          "Salle polyvalente de village avec scène et buvette.",
          "Salles polyvalentes de communes rurales", era="moderne",
          emplois=3, visiteurs=400, metiers=[["agent_public", 1], ["serveur", 1]], variantes=3)
def salle_fetes(k):
    k.corps(0, 0, 0, 24, 16, 1, 6.0, "enduit_rose",
            fen={"avant": 5, "gauche": 4, "droite": 4, "l": 1.6, "h": 2.2},
            porte={"l": 2.4, "h": 2.6, "couleur": "verre_nuit", "auvent": "tole"})
    k.toit_2pans(0, 0, 6.0, 24, 16, 3.0, "tuile", axe="x", pignon="enduit_rose", debord=0.5)
    k.boite(13.5, 0, 0, 3, 8, 3.5, "enduit_rose")
    k.toit_plat(13.5, 0, 3.5, 3, 8, "tole", acrotere=0.2)


# --- Éducation -----------------------------------------------------------------------

@batiment(F, "ecole_ferry", "École de village", "services", 3_000_000,
          "École Jules Ferry : corps central, deux ailes (filles et garçons) et préau.",
          "Écoles de la IIIe République (lois Jules Ferry, 1881-1882)", era="classique",
          emplois=8, visiteurs=120, metiers=[["enseignant", 4], ["atsem", 1], ["agent_public", 1]], role="ecole",
          variantes=3)
def ecole_ferry(k):
    k.sol(0, -6, 40, 14, "asphalte")
    k.corps(0, 4, 0, 12, 10, 2, 3.8, "pierre_claire",
            fen={"avant": 3, "arriere": 3, "gauche": 2, "droite": 2, "l": 1.2, "h": 2.2, "appui": "pierre"},
            porte={"l": 1.6, "h": 2.6, "couleur": "bleu"}, socle="pierre_grise", bandeaux="brique_claire",
            chaines="brique_claire")
    k.toit_4pans(0, 4, 7.6, 12, 10, 3.0, "ardoise")
    for s in (-1, 1):
        x = s * 13.0
        k.corps(x, 4, 0, 14, 9, 1, 4.6, "pierre_claire",
                fen={"avant": 4, "arriere": 4, "l": 1.5, "h": 2.6, "appui": "pierre"},
                socle="pierre_grise", chaines="brique_claire")
        k.toit_2pans(x, 4, 4.6, 14, 9, 2.8, "ardoise", axe="x", pignon="pierre_claire", debord=0.4)
    k.boite(-12, -9, 0, 10, 0.3, 0.01, "asphalte")
    for i in range(4):
        k.boite(-16 + i * 3.0, -10, 0, 0.3, 0.3, 3.0, "bois_sombre")
    k.toit_mono(-11.5, -11, 3.0, 10, 3.6, 0.6, "tuile", debord=0.2)


@batiment(F, "college", "Collège", "services", 14_000_000,
          "Collège des années 1970 : barres de béton et bandes vitrées.",
          "Collèges « Pailleron » et constructions scolaires industrialisées", era="moderne",
          emplois=50, visiteurs=600, metiers=[["enseignant", 8], ["agent_public", 2]], role="ecole", variantes=3)
def college(k):
    k.sol(0, -4, 60, 20, "asphalte")
    k.corps(0, 10, 0, 60, 12, 3, 3.4, "beton_clair",
            fen={"avant": 1, "arriere": 1, "bande": True, "h": 1.8, "vitre": "verre_ciel"},
            porte={"l": 3.0, "h": 2.6, "couleur": "verre_nuit", "auvent": "orange"})
    k.toit_plat(0, 10, 10.2, 60, 12, "beton_sombre", acrotere=0.5, c_acrotere="orange")
    k.corps(24, -6, 0, 12, 20, 2, 3.4, "beton_clair",
            fen={"gauche": 1, "droite": 1, "bande": True, "h": 1.8, "vitre": "verre_ciel"})
    k.toit_plat(24, -6, 6.8, 12, 20, "beton_sombre", acrotere=0.5, c_acrotere="orange")
    k.boite(-22, -8, 0, 16, 10, 7.0, "bardage_bleu")
    k.toit_voute(-22, -8, 7.0, 16, 10, 1.6, "tole", axe="y")


@batiment(F, "lycee", "Lycée", "services", 28_000_000,
          "Lycée en U autour d'une cour, briques et grandes fenêtres.",
          "Lycées urbains de l'entre-deux-guerres (lycée Claude-Bernard, Paris)", era="classique",
          emplois=110, visiteurs=1200, metiers=[["enseignant", 9], ["agent_public", 2], ["cadre", 1]],
          role="ecole", variantes=2)
def lycee(k):
    k.sol(0, 0, 40, 30, "asphalte")
    k.corps(0, 18, 0, 64, 12, 4, 3.8, "brique_claire",
            fen={"avant": 14, "arriere": 14, "gauche": 2, "droite": 2, "l": 1.6, "h": 2.4, "cadre": "pierre_claire"},
            socle="pierre_grise", bandeaux="pierre_claire")
    k.toit_2pans(0, 18, 15.2, 64, 12, 4.0, "ardoise", axe="x", pignon="brique_claire", debord=0.3)
    for s in (-1, 1):
        x = s * 26.0
        k.corps(x, -4, 0, 12, 32, 3, 3.8, "brique_claire",
                fen={"gauche": 7, "droite": 7, "avant": 2, "l": 1.6, "h": 2.4, "cadre": "pierre_claire"},
                socle="pierre_grise", bandeaux="pierre_claire")
        k.toit_2pans(x, -4, 11.4, 32, 12, 4.0, "ardoise", axe="y", pignon="brique_claire", debord=0.3)
    k.boite(0, 18, 15.2, 6.0, 6.0, 8.0, "brique_claire")
    (fx, fy), n, _ = facade(k, 0, 18, 6, 6, "avant")
    k.ouverture(fx, fy, n, 0, 20.5, 2.0, 2.0, "blanc", "noir", "rond")
    k.toit_4pans(0, 18, 23.2, 6, 6, 3.0, "ardoise", debord=0.3)


@batiment(F, "universite", "Université", "services", 80_000_000,
          "Bâtiment principal néo-Renaissance à coupole et deux cours.",
          "D'après le bâtiment principal de l'EPF de Zurich (Semper, 1864)", era="classique",
          emplois=400, visiteurs=3000, metiers=[["enseignant", 6], ["ingenieur", 2], ["employe", 2], ["cadre", 1]],
          role="ecole", variantes=1)
def universite(k):
    L, P = 90.0, 50.0
    for (x, y, l, p) in ((0, -P / 2 + 7, L, 14), (0, P / 2 - 7, L, 14), (-L / 2 + 7, 0, 14, P - 28),
                         (L / 2 - 7, 0, 14, P - 28), (0, 0, 14, P - 28)):
        fen = {"avant": int(l / 6), "arriere": int(l / 6), "gauche": int(p / 6), "droite": int(p / 6),
               "l": 1.5, "h": 2.4, "cadre": "pierre_claire"}
        k.corps(x, y, 0, l, p, 4, 4.2, "pierre_claire", fen=fen, socle="granit", bandeaux="pierre")
        k.toit_plat(x, y, 16.8, l, p, "zinc", acrotere=0.8, c_acrotere="pierre_claire")
    k.colonnes(0, -P / 2 - 1.5, 0.4, 24, 8, 12.0, 0.7, "pierre_claire", prof=3.0)
    k.cyl(0, 0, 17.6, 6.0, 9.0, "pierre_claire", n=14)
    k.dome(0, 0, 23.6, 9.0, "cuivre", n=14, anneaux=4, lanterne="cuivre")


@batiment(F, "creche", "Crèche", "services", 1_900_000,
          "Crèche et école maternelle colorée, toits à un pan et jardin.",
          "Crèches contemporaines en bois (Suisse romande, Vorarlberg)", era="contemporain",
          emplois=10, visiteurs=60, metiers=[["atsem", 4], ["enseignant", 1]], role="ecole", variantes=3)
def creche(k):
    k.sol(0, 6, 26, 10, "pelouse")
    for i, c in enumerate(("jaune", "bois_clair", "vert", "bois_clair")):
        x = -9 + i * 6
        k.corps(x, -2, 0, 6, 10, 1, 3.6, c,
                fen={"avant": 1, "arriere": 2, "l": 2.4, "h": 1.8, "vitre": "verre_ciel", "cadre": "blanc"},
                porte={"l": 1.4, "h": 2.3, "couleur": "orange"} if i == 1 else None)
        k.toit_mono(x, -2, 3.6, 6, 10, 1.4 + 0.4 * (i % 2), "zinc", debord=0.3, mur=c)
    k.cloture([(-13, 1), (13, 1), (13, 11), (-13, 11)], h=1.0, c="bois_clair")


# --- Santé et sécurité ----------------------------------------------------------------

@batiment(F, "hopital_regional", "Hôpital régional", "services", 120_000_000,
          "Socle de soins, tour d'hospitalisation de 9 étages et urgences.",
          "Hôpitaux régionaux des années 1970-1990 (CHUV Lausanne, CHU de province)", era="moderne",
          emplois=900, visiteurs=1500, metiers=[["medecin", 2], ["infirmier", 5], ["aide_soignant", 3]],
          role="hopital", variantes=1)
def hopital(k):
    k.sol(0, -26, 70, 12, "asphalte")
    k.corps(0, 0, 0, 70, 40, 3, 4.2, "blanc",
            fen={"avant": 1, "arriere": 1, "gauche": 1, "droite": 1, "bande": True, "h": 1.8, "vitre": "verre_ciel"},
            porte={"l": 6.0, "h": 3.0, "couleur": "verre_nuit", "auvent": "blanc"})
    k.toit_plat(0, 0, 12.6, 70, 40, "beton_sombre", acrotere=0.5)
    k.corps(0, 4, 12.6, 56, 16, 9, 3.4, "beton_clair",
            fen={"avant": 1, "arriere": 1, "gauche": 1, "droite": 1, "bande": True, "h": 1.6, "vitre": "verre_ciel"})
    k.toit_plat(0, 4, 43.2, 56, 16, "beton_sombre", acrotere=0.6)
    k.cyl(18, 4, 43.8, 0.2, 7.0, "vert", n=12)
    k.boite(18, 4, 44.0, 1.0, 5.0, 0.02, "blanc")
    k.boite(-26, -21.5, 0, 14, 6, 4.0, "rouge")
    k.boite(-26, -21.5, 4.0, 15, 7, 0.4, "blanc")
    (fx, fy), n, _ = facade(k, 0, 0, 70, 40, "avant")
    k.b.boite_mur(fx, fy, n, -4, 4, 9.0, 11.6, 0.3, "rouge")


@batiment(F, "clinique", "Clinique", "services", 18_000_000,
          "Clinique privée de trois étages, façade claire et loggias.",
          "Cliniques de quartier contemporaines", era="contemporain",
          emplois=120, visiteurs=200, metiers=[["medecin", 2], ["infirmier", 4], ["aide_soignant", 2]],
          role="hopital", variantes=2)
def clinique(k):
    k.corps(0, 0, 0, 34, 16, 4, 3.4, "enduit_blanc",
            fen={"avant": 10, "arriere": 10, "gauche": 4, "droite": 4, "l": 1.8, "h": 1.8, "vitre": "verre_ciel",
                 "cadre": "bois_clair"},
            porte={"l": 3.0, "h": 2.6, "couleur": "verre_nuit", "auvent": "blanc"})
    k.balcons(0, 0, 0, 34, 16, 4, 3.4, "arriere", nb=1)
    k.toit_plat(0, 0, 13.6, 34, 16, "beton_sombre", acrotere=0.5)
    (fx, fy), n, _ = facade(k, 0, 0, 34, 16, "avant")
    k.b.boite_mur(fx, fy, n, -1.2, 1.2, 10.4, 12.8, 0.2, "vert")


@batiment(F, "caserne_pompiers", "Centre de secours", "services", 9_000_000,
          "Caserne moderne : six portes, bureaux, tour de manœuvre.",
          "Centres d'incendie et de secours (SDIS) des années 2000", era="contemporain",
          emplois=40, metiers=[["pompier", 1]], role="pompiers", variantes=1)
def pompiers(k):
    k.sol(0, -12, 44, 12, "asphalte")
    k.boite(0, 4, 0, 40, 18, 7.0, "beton_clair")
    (fx, fy), n, lg = facade(k, 0, 4, 40, 18, "avant")
    for i in range(6):
        u = -lg / 2 + 3.6 + i * 6.4
        k.ouverture(fx, fy, n, u, 2.4, 4.4, 4.6, "rouge", "blanc")
    k.toit_plat(0, 4, 7.0, 40, 18, "beton_sombre", acrotere=0.5, c_acrotere="rouge")
    k.corps(0, 18, 0, 24, 10, 3, 3.3, "blanc",
            fen={"avant": 6, "arriere": 6, "gauche": 2, "droite": 2, "l": 1.6, "h": 1.4, "vitre": "verre_ciel"})
    k.toit_plat(0, 18, 9.9, 24, 10, "beton_sombre", acrotere=0.4)
    k.boite(23, 16, 0, 4, 4, 20, "rouge")
    for z in (4, 8, 12, 16):
        (fx, fy), n, _ = facade(k, 23, 16, 4, 4, "avant")
        k.ouverture(fx, fy, n, 0, z, 1.4, 2.0, "noir", "blanc")
    k.toit_plat(23, 16, 20, 4, 4, "noir", acrotere=0.3)


@batiment(F, "gendarmerie", "Gendarmerie", "services", 6_500_000,
          "Brigade de gendarmerie : bureaux et logements de fonction.",
          "Casernes de gendarmerie françaises", era="moderne",
          emplois=25, logements=8, metiers=[["policier", 1]], role="police", variantes=2)
def gendarmerie(k):
    k.corps(0, 0, 0, 22, 12, 2, 3.2, "enduit",
            fen={"avant": 6, "arriere": 6, "gauche": 2, "droite": 2, "l": 1.4, "h": 1.5, "vitre": "verre_ciel"},
            porte={"l": 2.0, "h": 2.4, "couleur": "bleu"})
    k.toit_4pans(0, 0, 6.4, 22, 12, 2.6, "tuile")
    (fx, fy), n, _ = facade(k, 0, 0, 22, 12, "avant")
    k.b.boite_mur(fx, fy, n, -4, 4, 3.4, 4.4, 0.15, "bleu")
    for s in (-1, 1):
        k.corps(s * 6, 16, 0, 10, 10, 3, 2.9, "enduit_jaune",
                fen={"avant": 3, "arriere": 3, "gauche": 2, "droite": 2, "l": 1.2, "h": 1.4, "volets": "volet"},
                porte={"l": 1.2, "h": 2.2})
        k.toit_2pans(s * 6, 16, 8.7, 10, 10, 2.6, "tuile", axe="x", pignon="enduit_jaune")


@batiment(F, "commissariat", "Hôtel de police", "services", 16_000_000,
          "Commissariat central : quatre étages, accueil vitré, garage.",
          "Hôtels de police contemporains", era="contemporain",
          emplois=120, metiers=[["policier", 1]], role="police", variantes=1)
def commissariat(k):
    k.corps(0, 0, 0, 36, 18, 4, 3.5, "beton_clair",
            fen={"avant": 12, "arriere": 12, "gauche": 6, "droite": 6, "l": 1.2, "h": 2.2, "vitre": "verre_ciel",
                 "cadre": "noir", "rdc": False},
            porte={"l": 6.0, "h": 3.0, "couleur": "verre_bleu", "cadre": "noir"})
    k.toit_plat(0, 0, 14.0, 36, 18, "beton_sombre", acrotere=0.6, c_acrotere="bleu")
    (fx, fy), n, _ = facade(k, 0, 0, 36, 18, "avant")
    k.ouverture(fx, fy, n, 0, 1.6, 16.0, 2.6, "verre_bleu", "noir")
    k.b.boite_mur(fx, fy, n, -6, 6, 11.0, 13.0, 0.3, "bleu")


# --- Sport couvert ----------------------------------------------------------------------

@batiment(F, "patinoire", "Patinoire couverte", "sport", 24_000_000,
          "Halle voûtée avec piste de 60 × 30 m et gradins.",
          "D'après la patinoire de Malley (Lausanne) et les patinoires municipales", era="moderne",
          emplois=15, visiteurs=1500, metiers=[["coach", 3], ["agent_public", 1]], role="patinoire", variantes=2)
def patinoire(k):
    L, P = 50.0, 76.0
    k.boite(0, 0, 0, L, P, 9.0, "bardage_bleu")
    for cote in ("gauche", "droite"):
        (fx, fy), n, lg = facade(k, 0, 0, L, P, cote)
        k.ouverture(fx, fy, n, 0, 6.6, lg - 4, 2.4, "verre_ciel", "blanc")
    k.toit_voute(0, 0, 9.0, L, P, 9.0, "zinc", n=8, axe="y", bouts="verre_ciel")
    (fx, fy), n, _ = facade(k, 0, 0, L, P, "avant")
    k.porte(fx, fy, n, 0, 0, 8.0, 3.0, "verre_nuit", "blanc", auvent="blanc")
    k.b.boite_mur(fx, fy, n, -8, 8, 5.0, 7.6, 0.3, "blanc")


@batiment(F, "salle_omnisport", "Salle omnisport", "sport", 7_000_000,
          "Gymnase triple : terrain de handball, gradins, toit à sheds.",
          "Salles omnisports municipales", era="moderne",
          emplois=6, visiteurs=500, metiers=[["coach", 1]], role="gymnase", variantes=3)
def omnisport(k):
    k.boite(0, 0, 0, 48, 30, 10.0, "bardage")
    k.boite(0, 0, 9.99, 48, 30, 0.3, "tole")
    k.sheds(0, 0, 10.3, 46, 28, 2.4, 5, "tole")
    (fx, fy), n, lg = facade(k, 0, 0, 48, 30, "avant")
    k.ouverture(fx, fy, n, 0, 7.8, lg - 2, 2.4, "verre_ciel", "blanc")
    k.corps(0, -19, 0, 30, 8, 1, 3.6, "beton_clair",
            fen={"avant": 6, "l": 2.4, "h": 1.6, "vitre": "verre_ciel"},
            porte={"l": 3.0, "h": 2.6, "couleur": "verre_nuit", "auvent": "orange"})
    k.toit_plat(0, -19, 3.6, 30, 8, "beton_sombre", acrotere=0.4, c_acrotere="orange")


@batiment(F, "piscine_couverte", "Piscine couverte", "sport", 22_000_000,
          "Halle vitrée avec bassin olympique de 50 m et toboggan.",
          "Centres aquatiques et piscines olympiques couvertes", era="contemporain",
          emplois=20, visiteurs=1200, metiers=[["coach", 4], ["caissier", 1]], role="piscine", variantes=2)
def piscine_couverte(k):
    k.boite(0, 0, 0, 64, 36, 3.0, "beton_clair")
    k.boite(0, 0, 3.0, 64, 36, 7.0, "verre_ciel")
    for i in range(9):
        x = -32 + i * 8
        k.boite(x, -18.05, 3.0, 0.4, 0.3, 7.0, "blanc")
    k.toit_voute(0, 0, 10.0, 64, 36, 4.0, "blanc", n=6, axe="x")
    (fx, fy), n, _ = facade(k, 0, 0, 64, 36, "avant")
    k.porte(fx, fy, n, -20, 0, 5.0, 2.6, "verre_nuit", "blanc", auvent="blanc")
    k.cyl(33, 10, 0, 14, 2.4, "blanc", n=10)
    k.b.cylindre(33, 10, 8, 9.0, 3.6, "orange", n=10, a0=-90, a1=180, dessus=False)


@batiment(F, "halle_tennis", "Tennis couvert", "sport", 3_500_000,
          "Halle gonflable sur arceaux, deux courts en résine.",
          "Halles de tennis de clubs", era="contemporain",
          emplois=3, visiteurs=60, metiers=[["coach", 1]], role="gymnase", variantes=2)
def halle_tennis(k):
    k.boite(0, 0, 0, 36, 40, 2.0, "blanc")
    k.toit_voute(0, 0, 2.0, 36, 40, 9.0, "blanc", n=8, axe="y", bouts="bardage_vert")
    k.corps(0, -23, 0, 10, 6, 1, 3.2, "bois_clair", fen={"avant": 2, "l": 2.0, "h": 1.6},
            porte={"l": 1.4, "h": 2.3})
    k.toit_mono(0, -23, 3.2, 10, 6, 0.8, "zinc", mur="bois_clair")


# --- Transports et équipements --------------------------------------------------------------

@batiment(F, "gare_village", "Gare de village", "services", 2_000_000,
          "Bâtiment voyageurs à deux niveaux, marquise et halle à marchandises.",
          "Gares des compagnies PLM et des CFF (fin XIXe s.)", era="classique",
          emplois=6, visiteurs=300, metiers=[["agent_gare", 1]], role="gare", variantes=3)
def gare_village(k):
    k.corps(0, 0, 0, 16, 9, 2, 3.6, "pierre_claire",
            fen={"avant": 5, "arriere": 5, "gauche": 2, "droite": 2, "l": 1.1, "h": 2.2, "forme": "arc",
                 "cadre": "brique_claire", "volets": "vert"},
            porte={"l": 1.6, "h": 2.6, "couleur": "vert", "forme": "arc"}, chaines="brique_claire",
            bandeaux="brique_claire")
    k.toit_4pans(0, 0, 7.2, 16, 9, 2.8, "ardoise", debord=0.6)
    (fx, fy), n, _ = facade(k, 0, 0, 16, 9, "avant")
    k.ouverture(fx, fy, n, 0, 6.4, 0.9, 0.9, "blanc", "noir", "rond", w=0.0)
    k.toit_mono(0, 7.0, 3.6, 18, 4.5, -0.01, "zinc", debord=0.0)
    for i in range(5):
        k.boite(-8 + i * 4, 9.0, 0, 0.2, 0.2, 3.6, "vert")
    k.corps(14, 0, 0, 10, 8, 1, 4.0, "bois_rouge", fen={"avant": 1, "l": 3.0, "h": 3.0, "vitre": "bois_sombre"})
    k.toit_2pans(14, 0, 4.0, 10, 8, 2.0, "tuile", axe="x", pignon="bois_rouge", debord=0.6)


@batiment(F, "gare_ville", "Grande gare", "services", 95_000_000,
          "Bâtiment voyageurs à horloge et grande halle voûtée sur les quais.",
          "D'après la gare de l'Est (Paris) et la gare de Lausanne", era="classique",
          emplois=150, visiteurs=8000, metiers=[["agent_gare", 3], ["vendeur", 1], ["cadre", 1]], role="gare",
          variantes=1)
def gare_ville(k):
    k.corps(0, -10, 0, 80, 14, 3, 5.0, "pierre_claire",
            fen={"avant": 16, "gauche": 2, "droite": 2, "l": 2.0, "h": 3.2, "forme": "arc", "cadre": "pierre"},
            socle="granit", bandeaux="pierre")
    k.toit_mansarde(0, -10, 15.0, 80, 14, 3.0, 1.5, "ardoise", lucarnes=8, mur="pierre_claire")
    k.boite(0, -17.5, 0, 22, 2.0, 22.0, "pierre_claire")
    (fx, fy), n, _ = facade(k, 0, -17.5, 22, 2.0, "avant")
    k.ouverture(fx, fy, n, 0, 10.0, 14.0, 14.0, "verre_ciel", "pierre", "arc")
    k.ouverture(fx, fy, n, 0, 19.5, 3.0, 3.0, "blanc", "noir", "rond", w=0.0)
    k.f([(-11, -18.6, 22.0), (11, -18.6, 22.0), (0, -18.6, 25.0)], "pierre_claire", vers=(0, -1, 0))
    k.boite(0, 22, 0, 70, 50, 8.0, "pierre_claire")
    k.toit_voute(0, 22, 8.0, 70, 50, 14.0, "verre_ciel", n=8, axe="y", bouts="verre_ciel")


@batiment(F, "phare", "Phare", "services", 4_000_000,
          "Tour à bandes rouges et blanches, lanterne et maison du gardien.",
          "D'après les phares de Bretagne (phare du Créac'h, Ouessant)", era="classique",
          emplois=2, logements=1, metiers=[["agent_public", 1]], variantes=2, access=["route", "chemin"])
def phare(k):
    for i in range(6):
        k.tronc_cone(0, 0, i * 5.0, 5.0, 3.6 - i * 0.25, 3.6 - (i + 1) * 0.25, "rouge" if i % 2 else "blanc", n=12,
                     dessus=False)
    k.cyl(0, 0, 30.0, 0.4, 3.0, "noir", n=12)
    k.cyl(0, 0, 30.4, 3.2, 1.8, "verre_clair", n=10)
    k.dome(0, 0, 33.6, 1.9, "rouge", n=10, anneaux=2)
    k.corps(6.5, 0, 0, 7, 6, 1, 3.2, "enduit_blanc", fen={"avant": 2, "gauche": 1, "l": 1.0, "h": 1.2,
                                                           "volets": "bleu"},
            porte={"l": 1.0, "h": 2.1, "couleur": "bleu", "u": 1.5})
    k.toit_2pans(6.5, 0, 3.2, 7, 6, 2.0, "ardoise", axe="x", pignon="enduit_blanc")


@batiment(F, "chateau_eau_champignon", "Château d'eau champignon", "services", 2_500_000,
          "Réservoir de béton en forme de champignon sur un fût de 30 m.",
          "Châteaux d'eau en béton des années 1960-1970 (France, Suède)", era="moderne",
          emplois=1, metiers=[["agent_public", 1]], role="chateau_eau", variantes=1, access=["route", "chemin"], sans_vitres=1)
def chateau_eau(k):
    k.cyl(0, 0, 0, 28.0, 2.4, "beton_clair", n=12)
    k.tronc_cone(0, 0, 28.0, 5.0, 2.4, 9.0, "beton_clair", n=16, dessus=False)
    k.cyl(0, 0, 33.0, 3.0, 9.0, "beton_clair", n=16, dessus=False)
    k.tronc_cone(0, 0, 36.0, 1.6, 9.0, 1.0, "beton_sombre", n=16)
