"""Styles du monde et monuments de la bible : architecture de terre d'Afrique
et du Moyen-Orient, temples et maisons d'Asie, missions et villages des
Amériques, Océanie, et grands monuments anciens d'Europe. Formes simplifiées
d'après des bâtiments réels ou des types courants (champ `source`)."""

import math

from registre import batiment

F = "monde"


def fen(**kw):
    d = {"l": 1.0, "h": 1.3}
    d.update(kw)
    return d


def creneaux(k, cx, cy, L, P, z, c, pas=2.0, h=0.8, ep=0.6):
    """Merlons sur le pourtour d'un toit (forteresse, kasbah)."""
    for s in (-1, 1):
        n = max(int(L / pas), 1)
        for i in range(n):
            if i % 2 == 0:
                x = cx - L / 2 + (i + 0.5) * L / n
                k.boite(x, cy + s * (P / 2 - ep / 2), z, L / n, ep, h, c)
        n = max(int(P / pas), 1)
        for i in range(n):
            if i % 2 == 0:
                y = cy - P / 2 + (i + 0.5) * P / n
                k.boite(cx + s * (L / 2 - ep / 2), y, z, ep, P / n, h, c)


def tour_ronde(k, x, y, r, h, c, toit=None, c_toit=None, n=10):
    k.cyl(x, y, 0, h, r, c, n=n)
    if toit == "cone":
        k.tronc_cone(x, y, h, r * 1.6, r * 1.15, 0, c_toit or "ardoise", n=n)
    elif toit == "creneaux":
        k.cyl(x, y, h, 0.9, r * 1.12, c, n=n)


# --- Afrique ----------------------------------------------------------------------------

@batiment(F, "mosquee_banco", "Grande mosquée de terre", "services", 4_800_000,
          "Mosquée de banco aux contreforts pointus et poutres de rônier saillantes.",
          "Grande mosquée de Djenné (Mali)", region="afrique", era="traditionnel", emplois=4, visiteurs=3000,
          metiers=[["agent_public", 2]], role="culte", sans_vitres=True, variantes=1)
def mosquee_terre(k):
    L, P = 40, 30
    k.boite(0, 0, 0, L + 4, P + 4, 2.0, "terre")
    k.boite(0, 0, 2.0, L, P, 8.0, "terre", dessus="ocre")
    creneaux(k, 0, 0, L, P, 10.0, "terre", pas=2.4, h=1.0)
    for i in range(3):
        x = -12 + i * 12
        k.boite(x, -P / 2 + 1.5, 2.0, 5, 3.0, 14.0 + (4 if i == 1 else 0), "terre")
        k.tronc_cone(x, -P / 2 + 1.5, 16.0 + (4 if i == 1 else 0), 3.0, 1.6, 0.3, "terre", n=6)
    for i in range(11):
        x = -L / 2 + 2 + i * (L - 4) / 10
        k.boite(x, -P / 2 - 0.5, 2.0, 1.0, 1.0, 9.0, "terre")
        k.tronc_cone(x, -P / 2 - 0.5, 11.0, 1.2, 0.5, 0.1, "terre", n=4)
        for z in (5.0, 8.0):
            k.boite(x, -P / 2 - 1.2, z, 0.18, 1.2, 0.18, "bois_sombre")
    k.porte(0, -P / 2 - 1, (0, -1), 0, 2.0, 2.4, 3.4, "bois_sombre", "ocre", "arc", marche=False)


@batiment(F, "kasbah", "Kasbah", "logement", 1_800_000,
          "Forteresse familiale de pisé à quatre tours d'angle crénelées.",
          "Ksar d'Aït-Ben-Haddou (Maroc)", region="moyen_orient", era="traditionnel", logements=4, role="maison",
          zone="R", sans_vitres=True)
def kasbah(k):
    L, P = 20, 20
    k.boite(0, 0, 0, L, P, 11.0, "terre", dessus="ocre")
    for s in (-1, 1):
        for t in (-1, 1):
            x, y = s * (L / 2 - 2), t * (P / 2 - 2)
            k.tronc(x, y, 0, 5.0, 5.0, 15.0, 4.0, 4.0, "terre", c_dessus="ocre")
            creneaux(k, x, y, 4.0, 4.0, 15.0, "terre", pas=1.0, h=0.7, ep=0.4)
    creneaux(k, 0, 0, L - 8, P, 11.0, "terre", pas=1.4, h=0.7)
    for z in (4.0, 7.5):
        for u in (-3, 0, 3):
            k.ouverture(0, -P / 2, (0, -1), u, z, 0.7, 1.0, "bois_sombre", "ocre")
    k.porte(0, -P / 2, (0, -1), 0, 0, 1.8, 2.8, "bois_sombre", "ocre", "arc")


@batiment(F, "case_obus", "Case obus", "logement", 120_000,
          "Case de terre en forme d'ogive, striée de reliefs pour grimper au sommet.",
          "Cases obus des Musgum (Cameroun)", region="afrique", era="traditionnel", logements=1, role="maison",
          zone="R", access=["route", "chemin"], sans_vitres=True)
def case_obus(k):
    for (x, y, r, h) in ((0, 0, 3.6, 8.0), (6.5, 2.5, 2.6, 6.0), (-5.5, 3.0, 2.4, 5.4)):
        prof = [r, r * 0.97, r * 0.88, r * 0.72, r * 0.5, r * 0.26, 0.05]
        z = 0.0
        dz = h / (len(prof) - 1)
        for a, b in zip(prof, prof[1:]):
            k.tronc_cone(x, y, z, dz, a, b, "terre", n=10, dessus=False)
            z += dz
        k.porte(x, y - r, (0, -1), 0, 0, 0.9, 1.8, "bois_sombre", "ocre", "arc", marche=False)
    k.cloture([(-9, -5), (10, -5), (10, 7), (-9, 7)], h=1.6, c="terre")


@batiment(F, "maison_swahilie", "Maison swahilie", "logement", 520_000,
          "Maison de corail blanchi à terrasse, porte sculptée et barza en façade.",
          "Vieille ville de Lamu (Kenya) et Stone Town (Zanzibar)", region="afrique", era="traditionnel",
          logements=2, role="maison", zone="R")
def maison_swahilie(k):
    L, P = 12, 12
    k.corps(0, 0, 0, L, P, 2, 3.4, "enduit_blanc", fen=fen(avant=3, arriere=3, gauche=2, droite=2, l=1.0, h=1.4,
                                                           cadre="bois_sombre", volets="bois_sombre"),
            porte={"l": 1.6, "h": 2.6, "couleur": "bois_sombre", "forme": "arc"})
    k.toit_plat(0, 0, 6.8, L, P, "pierre_claire", acrotere=0.9, c_acrotere="enduit_blanc")
    k.boite(-2.5, 2.5, 6.8, 5, 5, 2.4, "enduit_blanc")
    k.toit_2pans(-2.5, 2.5, 9.2, 5, 5, 1.8, "chaume", axe="x", pignon="enduit_blanc", debord=0.4)
    k.boite(3.5, -P / 2 - 0.6, 0, 3.5, 1.2, 0.6, "enduit_blanc")


@batiment(F, "grenier_dogon", "Village de greniers dogon", "production", 160_000,
          "Greniers carrés de terre coiffés de chapeaux de paille, au pied de la falaise.",
          "Greniers des villages dogon (falaise de Bandiagara, Mali)", region="afrique", era="traditionnel",
          emplois=4, metiers=[["agriculteur", 3]], role="grenier", access=["route", "chemin"], sans_vitres=True,
          variantes=1)
def grenier_dogon(k):
    k.sol(0, 0, 18, 14, "terre")
    pos = ((-5, -3), (-1.5, -3.5), (2, -3), (5.5, -2.5), (-4, 2), (0, 2.5), (4, 2.5))
    for i, (x, y) in enumerate(pos):
        h = 2.6 + (i % 3) * 0.5
        k.tronc(x, y, 0.4, 2.2, 2.2, h, 1.8, 1.8, "terre", c_dessus="terre")
        for (dx, dy) in ((-0.8, -0.8), (0.8, -0.8), (-0.8, 0.8), (0.8, 0.8)):
            k.boite(x + dx, y + dy, 0, 0.4, 0.4, 0.4, "pierre_grise")
        k.tronc_cone(x, y, h, 1.6, 1.6, 0.05, "chaume", n=6)
        k.ouverture(x, y - 1.0, (0, -1), 0, 1.6, 0.5, 0.6, "bois_sombre", None)


@batiment(F, "eglise_monolithe", "Église monolithe", "services", 2_600_000,
          "Église en croix grecque taillée dans la roche, au fond d'une fosse.",
          "Bete Giyorgis, Lalibela (Éthiopie)", region="afrique", era="antique", emplois=2, visiteurs=600,
          metiers=[["agent_public", 1]], role="culte", sans_vitres=True, variantes=1)
def eglise_monolithe(k):
    k.boite(0, 0, 0, 30, 30, 0.2, "terre")
    for s in (-1, 1):
        k.boite(0, s * 13.5, 0.2, 30, 3, 2.0, "terre_battue")
        k.boite(s * 13.5, 0, 0.2, 3, 24, 2.0, "terre_battue")
    for (sx, sy) in ((22, 7.5), (7.5, 22)):
        k.boite(0, 0, 0.2, sx, sy, 8.0, "terre_battue", dessus="terre")
    for (sx, sy) in ((20, 6), (6, 20)):
        k.boite(0, 0, 8.2, sx, sy, 0.3, "terre")
    k.boite(0, 0, 8.5, 7, 1.4, 0.3, "terre")
    k.boite(0, 0, 8.5, 1.4, 7, 0.3, "terre")
    for (fx, fy, n) in ((0, -11, (0, -1)), (0, 11, (0, 1)), (-11, 0, (-1, 0)), (11, 0, (1, 0))):
        k.ouverture(fx, fy, n, 0, 4.0, 1.0, 1.6, "bois_sombre", "terre", "arc")
        k.ouverture(fx, fy, n, 0, 6.6, 0.8, 0.9, "bois_sombre", "terre", "rond")
    k.porte(0, -3.75, (0, -1), 7.0, 0.2, 1.2, 2.4, "bois_sombre", "terre", marche=False)


@batiment(F, "marche_africain", "Marché couvert africain", "commerce", 900_000,
          "Étals sous toits de tôle ondulée, parasols et ballots colorés.",
          "Marché de Kejetia (Kumasi, Ghana)", region="afrique", era="moderne", emplois=40, visiteurs=2500,
          metiers=[["vendeur", 5], ["artisan", 1]], role="marche", zone="C", access=["route", "chemin"],
          sans_vitres=True)
def marche_africain(k):
    k.sol(0, 0, 36, 26, "terre_battue")
    for j in range(3):
        y = -8 + j * 8
        for i in range(4):
            x = -12 + i * 8
            for (dx, dy) in ((-3, -2.5), (3, -2.5), (-3, 2.5), (3, 2.5)):
                k.boite(x + dx, y + dy, 0, 0.2, 0.2, 2.8, "bois_gris")
            k.toit_mono(x, y, 2.8, 7.2, 5.6, 0.6, ("tole", "tole_rouge", "tole_verte", "tole")[(i + j) % 4],
                        debord=0.2, ep=0.05)
            k.boite(x, y, 0, 5.0, 1.2, 0.9, "bois_clair")
            k.boite(x - 1.2, y, 0.9, 1.2, 1.0, 0.5, ("rouge", "jaune", "bleu", "orange", "vert")[(i * 3 + j) % 5])


# --- Moyen-Orient -----------------------------------------------------------------------

@batiment(F, "caravanserail", "Caravansérail", "commerce", 3_800_000,
          "Hôtellerie fortifiée de pierre autour d'une cour à arcades.",
          "Caravansérails de la route de la soie (Zein-o-din, Iran)", region="moyen_orient", era="traditionnel",
          emplois=18, visiteurs=200, metiers=[["serveur", 2], ["cuisinier", 1], ["eleveur", 1]], role="hotel",
          zone="C", access=["route", "chemin"], sans_vitres=True)
def caravanserail(k):
    L = 40
    e = 8
    for s in (-1, 1):
        k.boite(0, s * (L / 2 - e / 2), 0, L, e, 7.0, "brique_claire", dessus="terre")
        k.boite(s * (L / 2 - e / 2), 0, 0, e, L - 2 * e, 7.0, "brique_claire", dessus="terre")
    k.sol(0, 0, L - 2 * e, L - 2 * e, "sable")
    k.boite(0, 0, 0, 4, 4, 0.8, "pierre_claire")
    k.boite(0, 0, 0.8, 3.4, 3.4, 0.05, "eau")
    for (fx, fy, n, lg) in ((0, -L / 2 + e, (0, 1), L - 2 * e), (0, L / 2 - e, (0, -1), L - 2 * e),
                            (-L / 2 + e, 0, (1, 0), L - 2 * e), (L / 2 - e, 0, (-1, 0), L - 2 * e)):
        for i in range(5):
            u = -lg / 2 + (i + 0.5) * lg / 5
            k.ouverture(fx, fy, n, u, 2.4, 3.0, 3.6, "ombre", "pierre_claire", "ogive")
    k.boite(0, -L / 2 - 0.5, 0, 12, 1.0, 11.0, "brique_claire")
    k.ouverture(0, -L / 2 - 1.0, (0, -1), 0, 4.0, 6.0, 7.0, "bleu", "pierre_claire", "ogive")
    k.porte(0, -L / 2 - 1.0, (0, -1), 0, 0, 3.0, 4.2, "bois_sombre", "pierre_claire", "arc", marche=False)
    for s in (-1, 1):
        for t in (-1, 1):
            tour_ronde(k, s * L / 2, t * L / 2, 2.2, 8.0, "brique_claire", "creneaux")


@batiment(F, "maison_badgir", "Maison à tours du vent", "logement", 760_000,
          "Maison de terre à cour, coiffée de deux badgirs qui rafraîchissent les pièces.",
          "Maisons de Yazd (Iran) et d'Al Bastakiya (Dubaï)", region="moyen_orient", era="traditionnel",
          logements=1, role="maison", zone="R", sans_vitres=True)
def maison_badgir(k):
    L, P = 16, 14
    k.boite(0, 0, 0, L, P, 6.0, "ocre", dessus="terre")
    k.boite(0, 0, 6.0, L, P, 0.6, "ocre")
    for (x, y, h) in ((-4, 3, 7.0), (4, 3, 5.0)):
        k.boite(x, y, 6.6, 2.6, 2.6, h, "ocre", dessus="terre")
        for (fx, fy, n) in ((x, y - 1.3, (0, -1)), (x, y + 1.3, (0, 1)), (x - 1.3, y, (-1, 0)),
                            (x + 1.3, y, (1, 0))):
            for u in (-0.6, 0.0, 0.6):
                k.ouverture(fx, fy, n, u, 6.6 + h - 1.6, 0.3, 2.2, "ombre", None)
    k.dome(4, -3, 6.6, 2.4, "ocre", n=8, anneaux=2, h=1.6)
    for u in (-5, 5):
        k.ouverture(0, -P / 2, (0, -1), u, 3.4, 1.0, 1.6, "bois_sombre", "terre", "ogive")
    k.porte(0, -P / 2, (0, -1), 0, 0, 1.6, 2.8, "bois_sombre", "terre", "arc")


@batiment(F, "maison_tour_yemen", "Maison-tour yéménite", "logement", 980_000,
          "Maison-tour de six niveaux en brique crue, frises blanches et vitraux qamariya.",
          "Vieille ville de Sanaa et Shibam (Yémen)", region="moyen_orient", era="traditionnel", logements=3,
          role="maison", zone="R")
def maison_tour_yemen(k):
    L, P = 9, 9
    k.corps(0, 0, 0, L, P, 1, 4.0, "pierre_grise", fen=fen(avant=1, l=0.6, h=0.8, cadre="pierre_claire"),
            porte={"l": 1.2, "h": 2.4, "couleur": "bois_sombre", "u": -2.0})
    k.corps(0, 0, 4.0, L, P, 5, 3.2, "brique_sombre", fen=fen(avant=3, arriere=3, gauche=3, droite=3, l=0.9, h=1.2,
                                                              cadre="enduit_blanc", forme="arc"))
    for e in range(1, 6):
        k.boite(0, 0, 4.0 + e * 3.2 - 0.3, L + 0.1, P + 0.1, 0.3, "enduit_blanc")
    creneaux(k, 0, 0, L, P, 20.0, "enduit_blanc", pas=0.9, h=0.7, ep=0.3)


# --- Asie --------------------------------------------------------------------------------

@batiment(F, "tulou", "Tulou", "logement", 3_500_000,
          "Grande maison ronde de terre où vit tout un clan, cour centrale et temple.",
          "Tulous Hakka du Fujian (Tianluokeng)", region="asie_est", era="traditionnel", logements=24,
          role="maison", zone="R", sans_vitres=True, variantes=2)
def tulou(k):
    n = 16
    R0, R1 = 13.0, 20.0
    for i in range(n):
        a0, a1 = 2 * math.pi * i / n, 2 * math.pi * (i + 1) / n
        c0, s0, c1, s1 = math.cos(a0), math.sin(a0), math.cos(a1), math.sin(a1)
        k.prisme([(R0 * c0, R0 * s0), (R1 * c0, R1 * s0), (R1 * c1, R1 * s1), (R0 * c1, R0 * s1)], 0, 12.0,
                 "terre", dessus="sous_toit")
        k.f([(R1 * c0 * 1.06, R1 * s0 * 1.06, 11.6), (R1 * c1 * 1.06, R1 * s1 * 1.06, 11.6),
             (R0 * c1 * 0.95, R0 * s1 * 0.95, 11.6), (R0 * c0 * 0.95, R0 * s0 * 0.95, 11.6)], "sous_toit",
            vers=(0, 0, -1))
        mx, my = (c0 + c1) / 2, (s0 + s1) / 2
        k.f([(R1 * c0 * 1.06, R1 * s0 * 1.06, 11.6), (R1 * c1 * 1.06, R1 * s1 * 1.06, 11.6),
             ((R0 + R1) / 2 * c1, (R0 + R1) / 2 * s1, 14.0), ((R0 + R1) / 2 * c0, (R0 + R1) / 2 * s0, 14.0)],
            "ardoise", vers=(mx, my, 2))
        k.f([((R0 + R1) / 2 * c0, (R0 + R1) / 2 * s0, 14.0), ((R0 + R1) / 2 * c1, (R0 + R1) / 2 * s1, 14.0),
             (R0 * c1 * 0.95, R0 * s1 * 0.95, 11.6), (R0 * c0 * 0.95, R0 * s0 * 0.95, 11.6)], "ardoise",
            vers=(-mx, -my, 2))
        for z in (8.0, 10.2):
            k.boite(R1 * mx * 1.002, R1 * my * 1.002, z, 0.6, 0.6, 0.8, "bois_sombre")
    k.sol(0, 0, 18, 18, "pierre_grise")
    k.boite(0, 3, 0, 8, 5, 3.6, "bois_rouge")
    k.toit_2pans(0, 3, 3.6, 8, 5, 1.4, "ardoise", axe="x", pignon="bois_rouge", debord=0.6)
    k.porte(0, -R1, (0, -1), 0, 0, 2.0, 3.0, "bois_sombre", "pierre_claire", marche=False)


@batiment(F, "hanok", "Hanok", "logement", 690_000,
          "Maison coréenne de bois sur socle de pierre, toit de tuiles aux bords relevés.",
          "Hanoks de Bukchon (Séoul)", region="asie_est", era="traditionnel", logements=1, role="maison", zone="R")
def hanok(k):
    k.boite(0, 0, 0, 18, 9, 0.8, "pierre_grise")
    k.corps(0, 0, 0.8, 16, 7, 1, 3.0, "enduit_blanc", fen=fen(avant=6, arriere=4, gauche=2, droite=2, l=1.2, h=1.6,
                                                              vitre="verre_clair", cadre="bois_rouge"))
    for i in range(9):
        k.boite(-8 + i * 2, -3.5, 0.8, 0.3, 0.3, 3.0, "bois_rouge")
    k.toit_4pans(0, 0, 3.8, 16, 7, 2.6, "ardoise", debord=1.6)
    for s in (-1, 1):
        k.boite(s * 9.4, -4.6, 3.0, 0.6, 0.6, 0.8, "ardoise")
        k.boite(s * 9.4, 4.6, 3.0, 0.6, 0.6, 0.8, "ardoise")
    k.boite(0, 0, 6.4, 10, 0.6, 0.6, "pierre_grise")


@batiment(F, "chateau_himeji", "Château japonais", "loisirs", 22_000_000,
          "Donjon blanc à cinq toits recourbés sur une base de pierre talutée.",
          "Château de Himeji (Japon)", region="asie_est", era="traditionnel", emplois=20, visiteurs=2500,
          metiers=[["agent_public", 3], ["vendeur", 1]], role="monument", variantes=1)
def chateau_japonais(k):
    k.tronc(0, 0, 0, 34, 28, 10.0, 28, 22, "pierre_grise", c_dessus="pierre_claire")
    z = 10.0
    for i, (L, P, h) in enumerate(((24, 18, 5.0), (20, 15, 4.6), (16, 12, 4.2), (12, 9, 4.0), (9, 7, 3.6))):
        k.corps(0, 0, z, L, P, 1, h, "enduit_blanc", fen=fen(avant=max(2, int(L / 4)), arriere=max(2, int(L / 4)),
                                                            gauche=2, droite=2, l=0.8, h=0.8, vitre="vitre",
                                                            cadre="noir"))
        z += h
        k.tronc(0, 0, z, L + 3.0, P + 3.0, z + 1.6, L * 0.75, P * 0.75, "ardoise", c_dessus="ardoise")
        if i in (1, 3):
            k.toit_2pans(0, -P / 2 - 0.5, z - 0.4, 6, 3, 2.2, "ardoise", axe="y", pignon="enduit_blanc", debord=0.3)
        z += 0.6
    k.toit_2pans(0, 0, z, 9, 7, 3.4, "ardoise", axe="x", pignon="enduit_blanc", debord=0.8)
    for s in (-1, 1):
        k.boite(s * 4.4, 0, z + 3.0, 0.6, 0.6, 1.0, "or")


@batiment(F, "temple_hindou", "Temple hindou", "services", 3_400_000,
          "Temple de grès à tour-sanctuaire shikhara et mandapa à colonnes.",
          "Temples de Khajuraho (Inde)", region="asie_sud", era="antique", emplois=3, visiteurs=900,
          metiers=[["agent_public", 2]], role="culte", sans_vitres=True, variantes=1)
def temple_hindou(k):
    k.boite(0, 0, 0, 26, 36, 3.0, "pierre_claire")
    k.boite(0, -9, 3.0, 14, 12, 5.0, "ocre", dessus="ocre")
    for x in (-6, -2, 2, 6):
        k.cyl(x, -15.4, 3.0, 5.0, 0.5, "ocre", n=6)
    z = 8.0
    for i in range(3):
        L = 13 - i * 3
        k.tronc(0, -9, z, L, L, z + 2.6, L - 3, L - 3, "ocre", c_dessus="ocre")
        z += 2.6
    k.boite(0, 7, 3.0, 12, 12, 6.0, "ocre")
    z = 9.0
    for i in range(6):
        L = 12 - i * 1.6
        k.tronc(0, 7, z, L, L, z + 3.4, L - 1.6, L - 1.6, "ocre", c_dessus="ocre")
        z += 3.4
    k.dome(0, 7, z, 1.6, "ocre", n=8, anneaux=2, h=1.0)
    k.tronc_cone(0, 7, z + 1.0, 2.0, 0.5, 0, "or", n=6)
    k.porte(0, -15, (0, -1), 0, 3.0, 2.0, 3.2, "ombre", "ocre", marche=False)
    for s in (-1, 1):
        k.boite(s * 4, -17, 0, 6, 2, 0.5, "pierre_claire")


@batiment(F, "stupa_boudha", "Stupa", "services", 2_000_000,
          "Dôme blanc sur terrasses, flèche dorée et yeux de Bouddha.",
          "Stupa de Boudhanath (Katmandou, Népal)", region="asie_sud", era="antique", emplois=2, visiteurs=1500,
          metiers=[["agent_public", 1]], role="culte", sans_vitres=True, variantes=1)
def stupa(k):
    for i, L in enumerate((40, 34, 28)):
        k.boite(0, 0, i * 1.6, L, L, 1.6, "enduit_blanc")
    k.dome(0, 0, 4.8, 12.0, "enduit_blanc", n=14, anneaux=4, h=9.0)
    k.boite(0, 0, 13.8, 6, 6, 3.0, "or")
    for (fx, fy, n) in ((0, -3.02, (0, -1)), (0, 3.02, (0, 1)), (-3.02, 0, (-1, 0)), (3.02, 0, (1, 0))):
        for u in (-1.2, 1.2):
            k.ouverture(fx, fy, n, u, 15.6, 1.0, 0.4, "noir", None)
    z = 16.8
    for i in range(6):
        r = 2.6 - i * 0.38
        k.tronc_cone(0, 0, z, 1.0, r, r * 0.92, "or", n=8)
        z += 1.0
    k.tronc_cone(0, 0, z, 3.0, 0.5, 0, "or", n=6)
    for a in range(12):
        ang = 2 * math.pi * a / 12
        k.f([(0, 0, z), (16 * math.cos(ang), 16 * math.sin(ang), 3.2),
             (16 * math.cos(ang + 0.05), 16 * math.sin(ang + 0.05), 3.4)],
            ("rouge", "jaune", "vert", "bleu", "blanc")[a % 5], vers=(0, 0, 1))


@batiment(F, "haveli", "Haveli", "logement", 1_400_000,
          "Demeure de grès à balcons-jharokhas en encorbellement et cour intérieure.",
          "Havelis de Jaisalmer (Rajasthan)", region="asie_sud", era="traditionnel", logements=3, role="villa",
          zone="R")
def haveli(k):
    L, P = 16, 14
    k.corps(0, 0, 0, L, P, 4, 3.4, "ocre", fen=fen(avant=4, arriere=3, gauche=3, droite=3, l=0.9, h=1.4,
                                                    forme="arc", cadre="pierre_claire"),
            porte={"l": 2.0, "h": 3.0, "couleur": "bois_sombre", "forme": "arc"}, bandeaux="pierre_claire")
    for e in (1, 2, 3):
        for u in (-5.5, 0, 5.5):
            z = e * 3.4 + 0.4
            k.boite(u, -P / 2 - 0.7, z, 2.4, 1.4, 2.4, "ocre")
            k.ouverture(u, -P / 2 - 1.4, (0, -1), 0, z + 1.3, 1.6, 1.4, "vitre", "pierre_claire", "arc")
            k.dome(u, -P / 2 - 0.7, z + 2.4, 1.0, "ocre", n=6, anneaux=2, h=0.6)
    k.toit_plat(0, 0, 13.6, L, P, "pierre_claire", acrotere=0.8, c_acrotere="ocre")
    for s in (-1, 1):
        for x in (-0.7, 0.7):
            k.cyl(s * 6 + x, 4 + x, 13.6, 2.0, 0.12, "ocre", n=4)
        k.dome(s * 6, 4, 15.6, 1.4, "ocre", n=8, anneaux=2, h=1.0)


@batiment(F, "wat_thai", "Temple thaï", "services", 3_000_000,
          "Wat à toits superposés rouge et vert, pignons dorés et chedi blanc.",
          "Wat Phra Singh (Chiang Mai, Thaïlande)", region="asie_sud", era="traditionnel", emplois=3,
          visiteurs=1000, metiers=[["agent_public", 2]], role="culte", variantes=1)
def wat_thai(k):
    k.boite(0, 2, 0, 18, 30, 1.2, "enduit_blanc")
    k.corps(0, 2, 1.2, 14, 26, 1, 6.0, "enduit_blanc", fen=fen(gauche=5, droite=5, l=1.0, h=2.2, vitre="vitre",
                                                               cadre="or"),
            porte={"l": 2.4, "h": 3.8, "couleur": "bois_rouge"})
    for i, (h, d) in enumerate(((3.4, 1.8), (3.0, 0.9), (2.6, 0.0))):
        k.toit_2pans(0, 2 + i * 1.5, 7.2 + i * 1.6, 26 - i * 3, 14 - i * 2.6, h, ("bois_rouge", "vert")[i % 2],
                     axe="y", pignon="or", debord=d + 0.4)
    k.cyl(0, 22, 0, 4, 4.0, "enduit_blanc", n=12)
    k.bulbe(0, 22, 4.0, 3.4, 6.0, "enduit_blanc", n=10)
    k.tronc_cone(0, 22, 9.6, 7.0, 0.8, 0, "or", n=8)


@batiment(F, "longhouse_borneo", "Maison longue", "logement", 980_000,
          "Maison longue sur pilotis de bois de fer, véranda commune et toit de feuilles.",
          "Rumah panjang des Iban (Sarawak, Bornéo)", region="asie_sud", era="traditionnel", logements=10,
          role="maison", zone="R", access=["route", "chemin"], sans_vitres=True)
def longhouse(k):
    L, P = 44, 12
    k.pilotis(0, 0, L, P, 3.0, 9, 3, "bois_sombre", r=0.2)
    k.boite(0, 0, 3.0, L, P, 0.3, "bois")
    k.boite(0, 2, 3.3, L, 7, 3.0, "bois_clair")
    for i in range(10):
        k.porte(0, -1.5, (0, -1), -L / 2 + 2.2 + i * 4.4, 3.3, 0.9, 2.0, "bois_sombre", "bois")
    k.toit_2pans(0, 0.5, 6.3, L, 10, 3.4, "chaume", axe="x", pignon="bois_clair", debord=0.8)
    for s in (-1, 1):
        k.f([(s * 10 - 0.9, -P / 2, 0), (s * 10 + 0.9, -P / 2, 0), (s * 10 + 0.9, -P / 2 + 1.5, 3.0),
             (s * 10 - 0.9, -P / 2 + 1.5, 3.0)], "bois_sombre", vers=(0, -1, 1))


@batiment(F, "tongkonan", "Tongkonan", "logement", 640_000,
          "Maison toraja sur pilotis au toit en forme de proue, façade sculptée rouge et noire.",
          "Tongkonan du pays toraja (Sulawesi, Indonésie)", region="asie_sud", era="traditionnel", logements=1,
          role="maison", zone="R", access=["route", "chemin"], sans_vitres=True)
def tongkonan(k):
    k.pilotis(0, 0, 6, 10, 2.4, 3, 3, "bois_sombre", r=0.22)
    k.boite(0, 0, 2.4, 6, 10, 3.0, "bois_rouge", dessus="bois_sombre")
    k.ouverture(0, -5, (0, -1), 0, 3.9, 4.0, 2.0, "noir", "jaune")
    k.toit_profil(0, 0, 5.4, 6.4, [(-4.2, 0), (-3.0, 2.2), (0, 3.0), (3.0, 2.2), (4.2, 0)], "bois_gris", axe="y",
                  bouts="bois_gris")
    for s in (-1, 1):
        k.f([(-3.0, s * 5, 5.4), (3.0, s * 5, 5.4), (4.2, s * 9.5, 9.6), (-4.2, s * 9.5, 9.6)], "chaume",
            vers=(0, -s * 0.4, 1))
        k.f([(-4.2, s * 9.5, 9.6), (4.2, s * 9.5, 9.6), (3.0, s * 5, 8.4), (-3.0, s * 5, 8.4)], "chaume",
            vers=(0, 0, 1))
        k.boite(0, s * 8.6, 0, 0.5, 0.5, 9.0, "bois_sombre")


# --- Amériques ----------------------------------------------------------------------------

@batiment(F, "mission_espagnole", "Mission espagnole", "services", 2_800_000,
          "Église de mission en adobe blanc, clocher-mur à arcades et cloître.",
          "Missions de Californie (San Carlos Borromeo, Carmel)", region="ameriques", era="traditionnel",
          emplois=2, visiteurs=300, metiers=[["agent_public", 1]], role="culte", variantes=2)
def mission(k):
    L, P = 12, 30
    k.corps(0, 0, 0, L, P, 1, 9.0, "enduit_blanc", fen=fen(gauche=4, droite=4, l=0.9, h=1.8, forme="arc",
                                                           cadre="pierre_claire", rdc=True),
            porte={"l": 2.4, "h": 4.0, "couleur": "bois_sombre", "forme": "arc"})
    k.toit_2pans(0, 0, 9.0, P, L, 2.6, "tuile", axe="y", pignon="enduit_blanc", debord=0.4)
    k.boite(0, -P / 2 - 0.3, 9.0, L, 0.6, 4.2, "enduit_blanc")
    k.f([(-L / 2, -P / 2 - 0.62, 13.2), (L / 2, -P / 2 - 0.62, 13.2), (0, -P / 2 - 0.62, 16.0)], "enduit_blanc",
        vers=(0, -1, 0))
    k.ouverture(0, -P / 2 - 0.6, (0, -1), 0, 10.6, 1.4, 1.4, "vitre", "pierre_claire", "rond")
    k.boite(L / 2 + 3, -P / 2 + 3, 0, 6, 6, 16.0, "enduit_blanc")
    for u in (-1.4, 1.4):
        k.ouverture(L / 2 + 3, -P / 2, (0, -1), u, 13.5, 1.2, 2.4, "ombre", "pierre_claire", "arc")
    k.dome(L / 2 + 3, -P / 2 + 3, 16.0, 2.6, "enduit_blanc", n=8, anneaux=2, h=2.2, lanterne="pierre_claire")
    k.boite(-L / 2 - 8, 4, 0, 14, 16, 4.0, "enduit_blanc", dessus="tuile")
    k.arcade(-L / 2 - 8, 4, 0, 14, 5, 3.2, 2.4, "enduit_blanc", cote_y=-4.0)


@batiment(F, "pyramide_maya", "Pyramide maya", "loisirs", 15_000_000,
          "Pyramide à neuf degrés, escalier central et temple au sommet.",
          "El Castillo, Chichén Itzá (Mexique)", region="ameriques", era="antique", emplois=10, visiteurs=4000,
          metiers=[["agent_public", 2], ["vendeur", 1]], role="monument", sans_vitres=True, variantes=1)
def pyramide_maya(k):
    z = 0.0
    for i in range(9):
        L = 55 - i * 5
        k.tronc(0, 0, z, L, L, z + 2.6, L - 1.2, L - 1.2, "pierre_claire", c_dessus="pierre_grise")
        z += 2.6
    for dx, dy in ((0, -1), (0, 1), (-1, 0), (1, 0)):
        if dx == 0:
            y0, y1 = dy * 28.5, dy * 10.5
            k.f([(-4, y0, 0), (4, y0, 0), (4, y1, z), (-4, y1, z)], "pierre_grise", vers=(0, dy, 1))
        else:
            x0, x1 = dx * 28.5, dx * 10.5
            k.f([(x0, 4, 0), (x0, -4, 0), (x1, -4, z), (x1, 4, z)], "pierre_grise", vers=(dx, 0, 1))
    k.boite(0, 0, z, 12, 12, 5.0, "pierre_claire")
    k.porte(0, -6, (0, -1), 0, z, 2.6, 3.0, "ombre", "pierre_grise", marche=False)
    k.boite(0, 0, z + 5.0, 13, 13, 1.0, "pierre_grise")


@batiment(F, "saloon_western", "Saloon", "commerce", 420_000,
          "Saloon de bois à fausse façade, galerie couverte et balcon.",
          "Rues des villes minières de l'Ouest (Virginia City, Nevada)", region="ameriques", era="classique",
          emplois=6, visiteurs=250, logements=1, metiers=[["serveur", 3], ["cuisinier", 1]], role="cafe", zone="C")
def saloon(k):
    L, P = 12, 16
    k.corps(0, 0, 0, L, P, 2, 3.4, "bois", fen=fen(avant=3, gauche=3, droite=3, arriere=2, l=1.0, h=1.6,
                                                    cadre="blanc"),
            porte={"l": 1.6, "h": 2.4, "couleur": "bois_sombre"})
    k.toit_2pans(0, 0, 6.8, P, L, 2.0, "tole", axe="y", pignon="bois", debord=0.3)
    k.boite(0, -P / 2 - 0.1, 6.8, L, 0.2, 3.2, "bois_rouge")
    k.boite(0, -P / 2 - 0.3, 8.4, L * 0.7, 0.1, 1.0, "jaune")
    k.porche(0, -P / 2, L, 2.4, 3.4, 5, toit="tole", poteau="bois_sombre", sol="bois_gris")
    k.boite(0, -P / 2 - 1.2, 4.1, L, 2.4, 0.15, "bois_gris")
    for x in (-3, 3):
        k.boite(x, -P / 2 - 3.4, 0, 2.6, 0.1, 0.9, "bois_sombre")


@batiment(F, "eglise_chiloe", "Église en bois de Chiloé", "services", 1_600_000,
          "Église de bois peinte aux tavaillons, portique et tour-clocher à trois étages.",
          "Églises de Chiloé (Chili), patrimoine mondial", region="ameriques", era="classique", emplois=1,
          visiteurs=250, metiers=[["agent_public", 1]], role="culte", variantes=3)
def eglise_chiloe(k):
    L, P = 12, 28
    k.corps(0, 0, 0, L, P, 1, 7.0, "jaune", fen=fen(gauche=5, droite=5, l=1.0, h=2.0, forme="arc", cadre="blanc"))
    k.toit_2pans(0, 0, 7.0, P, L, 3.6, "bois_gris", axe="y", pignon="jaune", debord=0.4)
    k.boite(0, -P / 2 - 2.0, 0, L, 4.0, 0.3, "bois_gris")
    for i in range(5):
        k.boite(-L / 2 + 0.3 + i * (L - 0.6) / 4, -P / 2 - 3.8, 0.3, 0.4, 0.4, 5.6, "blanc")
    k.boite(0, -P / 2 - 2.0, 5.9, L, 4.0, 0.4, "blanc")
    z = 7.0
    for i, (c, h) in enumerate((("jaune", 4.0), ("blanc", 3.2), ("jaune", 2.6))):
        w = 5.0 - i * 1.0
        k.boite(0, -P / 2 + 2.5, z, w, w, h, c)
        k.ouverture(0, -P / 2 + 2.5 - w / 2, (0, -1), 0, z + h * 0.55, w * 0.4, h * 0.5, "vitre", "blanc", "arc")
        z += h
    k.tronc_cone(0, -P / 2 + 2.5, z, 5.0, 2.2, 0, "bois_gris", n=8)
    k.porte(0, -P / 2, (0, -1), 0, 0.3, 2.0, 3.6, "bleu", "blanc", "arc", marche=False)


@batiment(F, "favela_colline", "Maisons de favela", "logement", 600_000,
          "Empilement de petites maisons de brique et d'enduit coloré à toits plats.",
          "Favelas de Rio de Janeiro (Santa Marta)", region="ameriques", era="contemporain", logements=8,
          role="maison", zone="R", access=["route", "chemin"], variantes=3)
def favela(k):
    blocs = ((-7, -4, 5, 5, 2, "enduit_jaune"), (-2, -4, 4.4, 5, 3, "brique_claire"), (3, -4, 5, 5, 2, "enduit_bleu"),
             (7.6, -3.4, 4, 6, 1, "enduit_rose"), (-6, 2, 6, 6, 3, "brique_claire"), (0, 2.4, 5, 5.6, 4, "enduit_vert"),
             (5.6, 2, 5.4, 6, 2, "brique_claire"), (-1.5, 7.2, 8, 4, 2, "ocre"))
    for (x, y, L, P, et, c) in blocs:
        k.corps(x, y, 0, L, P, et, 2.7, c, fen=fen(avant=1, gauche=1, droite=1, l=0.9, h=0.9, cadre="blanc"),
                dessus="beton_sombre")
        k.boite(x + L / 4, y + P / 4, et * 2.7, 1.0, 1.0, 1.0, "bleu")
    k.boite(-2, -6.6, 2.7, 3.4, 0.3, 1.0, "beton_clair")


# --- Océanie -------------------------------------------------------------------------------

@batiment(F, "wharenui", "Wharenui", "services", 900_000,
          "Maison de réunion maorie à pignon sculpté et bargeboards rouges.",
          "Wharenui des marae (Te Papa, Waitangi, Nouvelle-Zélande)", region="oceanie", era="traditionnel",
          emplois=1, visiteurs=300, metiers=[["agent_public", 1]], role="salle_fetes", variantes=1)
def wharenui(k):
    L, P = 10, 22
    k.corps(0, 0, 0, L, P, 1, 3.0, "bois_rouge", fen=fen(gauche=3, droite=3, l=0.9, h=1.0, cadre="noir"))
    k.toit_2pans(0, 0, 3.0, P, L, 3.6, "bois_gris", axe="y", pignon="bois_rouge", debord=0.2)
    k.boite(0, -P / 2 - 1.6, 0, L, 3.2, 0.3, "bois_sombre")
    for s in (-1, 1):
        k.boite(s * (L / 2 - 0.2), -P / 2 - 3.2, 0.3, 0.5, 0.5, 2.7, "bois_rouge")
        k.f([(s * (L / 2 + 0.6), -P / 2 - 3.4, 2.4), (s * (L / 2 + 0.6) - s * 0.6, -P / 2 - 3.4, 2.4),
             (0, -P / 2 - 3.4, 6.8), (0, -P / 2 - 3.4, 7.4)], "bois_rouge", vers=(0, -1, 0))
    k.toit_2pans(0, -P / 2 - 1.6, 3.0, 3.2, L, 3.6, "bois_gris", axe="y", debord=0.2, pignons=False)
    k.boite(0, -P / 2 - 3.42, 6.8, 0.7, 0.2, 1.8, "bois_rouge")
    k.porte(0, -P / 2, (0, -1), -2.0, 0.3, 1.0, 2.0, "bois_sombre", "bois_rouge", marche=False)
    k.ouverture(0, -P / 2, (0, -1), 2.0, 1.6, 1.2, 1.0, "vitre", "bois_rouge")


@batiment(F, "fare_polynesien", "Faré sur pilotis", "commerce", 1_200_000,
          "Bungalows de luxe sur l'eau, toits de pandanus et pontons de bois.",
          "Bungalows sur pilotis de Bora Bora", region="oceanie", era="contemporain", emplois=12, visiteurs=40,
          metiers=[["serveur", 2], ["cuisinier", 1], ["employe", 1]], role="hotel", zone="C",
          access=["route", "chemin"])
def fare(k):
    k.boite(0, 0, 0, 34, 24, 0.05, "eau")
    k.boite(0, -10, 0, 2.2, 6, 1.6, "bois_gris")
    k.boite(0, -1, 1.5, 2.2, 14, 0.15, "bois_gris")
    k.boite(0, 6, 1.5, 28, 2.2, 0.15, "bois_gris")
    for x in (-11, 0, 11):
        y = 1 if x else -6
        if x == 0:
            y = 11
        k.pilotis(x, y, 6, 6, 1.6, 2, 2, "bois_sombre", r=0.15)
        k.boite(x, y, 1.6, 7, 7, 0.2, "bois_clair")
        k.corps(x, y + 0.6, 1.8, 5, 5, 1, 2.6, "bois_clair", fen=fen(avant=2, gauche=1, droite=1, l=1.4, h=1.4,
                                                                    vitre="verre_clair", cadre="bois_sombre"))
        k.toit_4pans(x, y + 0.6, 4.4, 5, 5, 3.2, "chaume", debord=0.9)
        k.boite(x, y - 3.0, 1.75, 4, 1.4, 0.05, "eau")


# --- Monuments d'Europe et de l'Antiquité -------------------------------------------------

@batiment(F, "chateau_fort_enceinte", "Château fort", "loisirs", 18_000_000,
          "Enceinte crénelée à tours rondes, donjon carré et pont-levis.",
          "Châteaux forts de Carcassonne et de Pierrefonds", era="traditionnel", emplois=14, visiteurs=2000,
          metiers=[["agent_public", 3], ["vendeur", 1]], role="monument", sans_vitres=True, variantes=1)
def chateau_fort(k):
    L, P = 40, 34
    k.sol(0, 0, L + 10, P + 10, "eau")
    k.sol(0, 0, L + 3, P + 3, "pelouse")
    for s in (-1, 1):
        k.boite(0, s * (P / 2 - 1), 0, L, 2.0, 10.0, "pierre_grise")
        k.boite(s * (L / 2 - 1), 0, 0, 2.0, P, 10.0, "pierre_grise")
    creneaux(k, 0, 0, L, P, 10.0, "pierre_grise", pas=1.6, h=1.0, ep=0.8)
    for s in (-1, 1):
        for t in (-1, 1):
            tour_ronde(k, s * L / 2, t * P / 2, 3.4, 15.0, "pierre_grise", "cone", "ardoise")
    for s in (-1, 1):
        tour_ronde(k, s * 4, -P / 2, 2.6, 13.0, "pierre_grise", "cone", "ardoise")
    k.porte(0, -P / 2 - 1, (0, -1), 0, 0, 3.2, 4.4, "bois_sombre", "pierre", "arc", marche=False)
    k.f([(-1.6, -P / 2 - 1.2, 0.2), (1.6, -P / 2 - 1.2, 0.2), (1.6, -P / 2 - 5.2, 0.2), (-1.6, -P / 2 - 5.2, 0.2)],
        "bois_sombre", vers=(0, 0, 1))
    k.boite(4, 4, 0, 12, 12, 22.0, "pierre_grise")
    creneaux(k, 4, 4, 12, 12, 22.0, "pierre_grise", pas=1.4, h=1.0, ep=0.7)
    for (fx, fy, n) in ((4, -2, (0, -1)), (-2, 4, (-1, 0))):
        for z in (12.0, 17.0):
            k.ouverture(fx, fy, n, 0, z, 0.6, 1.6, "ombre", "pierre", "arc")
    k.boite(-10, 6, 0, 10, 14, 7.0, "pierre_claire")
    k.toit_2pans(-10, 6, 7.0, 14, 10, 4.0, "ardoise", axe="y", pignon="pierre_claire", debord=0.3)


@batiment(F, "abbaye_cistercienne", "Abbaye cistercienne", "services", 9_000_000,
          "Église dépouillée, cloître et bâtiments conventuels de pierre blonde.",
          "Abbaye de Sénanque (Provence) et de Fontenay (Bourgogne)", region="mediterranee", era="traditionnel",
          emplois=8, visiteurs=800, metiers=[["agent_public", 2], ["agriculteur", 1], ["vendeur", 1]],
          role="culte", variantes=1)
def abbaye(k):
    k.corps(0, -6, 0, 34, 12, 1, 12.0, "pierre_claire", fen=fen(avant=6, arriere=0, gauche=2, droite=1, l=1.0,
                                                                h=2.4, forme="arc", cadre="pierre"),
            porte={"l": 2.2, "h": 3.6, "couleur": "bois_sombre", "forme": "arc", "cote": "gauche"})
    k.toit_2pans(0, -6, 12.0, 34, 12, 3.6, "pierre_grise", axe="x", pignon="pierre_claire", debord=0.3)
    k.boite(6, -6, 12.0, 6, 6, 6.0, "pierre_claire")
    k.toit_4pans(6, -6, 18.0, 6, 6, 3.0, "pierre_grise", debord=0.2)
    k.boite(0, 9, 0, 18, 18, 0.1, "pelouse")
    for s in (-1, 1):
        k.boite(s * 12, 9, 0, 6, 18, 8.0, "pierre_claire")
        k.toit_2pans(s * 12, 9, 8.0, 18, 6, 2.4, "tuile", axe="y", pignon="pierre_claire", debord=0.3)
    k.boite(0, 21, 0, 30, 6, 8.0, "pierre_claire")
    k.toit_2pans(0, 21, 8.0, 30, 6, 2.4, "tuile", axe="x", pignon="pierre_claire", debord=0.3)
    for s in (-1, 1):
        k.arcade(s * 7.5, 9, 0, 0.1, 1, 3.0, 0.1, "pierre_claire")
    for (fx, fy, n, lg) in ((-9, 9, (1, 0), 18), (9, 9, (-1, 0), 18), (0, 18, (0, -1), 12)):
        for i in range(4):
            u = -lg / 2 + 2 + i * (lg - 4) / 3
            k.ouverture(fx, fy, n, u, 1.8, 1.6, 2.6, "ombre", "pierre", "arc")
        for i in range(4):
            u = -lg / 2 + 2 + i * (lg - 4) / 3
            k.ouverture(fx, fy, n, u, 5.4, 0.8, 1.2, "vitre", "pierre", "arc")


@batiment(F, "temple_dorique", "Temple grec", "loisirs", 12_000_000,
          "Temple dorique de marbre, péristyle de colonnes et fronton.",
          "Parthénon (Athènes) et temples de Paestum", region="mediterranee", era="antique", emplois=6,
          visiteurs=3000, metiers=[["agent_public", 2], ["vendeur", 1]], role="monument", sans_vitres=True,
          variantes=1)
def temple_grec(k):
    L, P = 18, 36
    for i in range(3):
        k.boite(0, 0, i * 0.5, L + 3 - i, P + 3 - i, 0.5, "pierre_claire")
    k.boite(0, 0, 1.5, L - 5, P - 7, 9.0, "pierre_claire")
    nx, ny = 6, 13
    for i in range(nx):
        x = -L / 2 + 1 + i * (L - 2) / (nx - 1)
        for y in (-P / 2 + 1, P / 2 - 1):
            k.cyl(x, y, 1.5, 9.0, 0.75, "enduit_blanc", n=8)
    for j in range(1, ny - 1):
        y = -P / 2 + 1 + j * (P - 2) / (ny - 1)
        for x in (-L / 2 + 1, L / 2 - 1):
            k.cyl(x, y, 1.5, 9.0, 0.75, "enduit_blanc", n=8)
    k.boite(0, 0, 10.5, L, P, 1.8, "pierre_claire")
    k.toit_2pans(0, 0, 12.3, P, L, 3.0, "tuile", axe="y", pignon="pierre_claire", debord=0.3)


@batiment(F, "amphitheatre_romain", "Amphithéâtre romain", "loisirs", 40_000_000,
          "Arène ovale à trois niveaux d'arcades de pierre, gradins et piste de sable.",
          "Arènes de Nîmes et Colisée de Rome", region="mediterranee", era="antique", emplois=40,
          visiteurs=20000, metiers=[["agent_public", 3], ["comedien", 1], ["vendeur", 1]], role="theatre",
          sans_vitres=True, variantes=1)
def amphitheatre(k):
    n = 20
    A, B = 66.0, 54.0
    ea, eb = 24.0, 20.0
    for i in range(n):
        a0, a1 = 2 * math.pi * i / n, 2 * math.pi * (i + 1) / n
        o0 = (A / 2 * math.cos(a0), B / 2 * math.sin(a0))
        o1 = (A / 2 * math.cos(a1), B / 2 * math.sin(a1))
        i0 = ((A / 2 - ea) * math.cos(a0), (B / 2 - eb) * math.sin(a0))
        i1 = ((A / 2 - ea) * math.cos(a1), (B / 2 - eb) * math.sin(a1))
        k.f([(o0[0], o0[1], 0), (o1[0], o1[1], 0), (o1[0], o1[1], 20), (o0[0], o0[1], 20)], "pierre_claire",
            vers=((o0[0] + o1[0]) / 2, (o0[1] + o1[1]) / 2, 0))
        k.f([(o0[0], o0[1], 20), (o1[0], o1[1], 20), (i1[0], i1[1], 3), (i0[0], i0[1], 3)], "pierre",
            vers=(-(o0[0] + o1[0]) / 2, -(o0[1] + o1[1]) / 2, 30))
        k.f([(i0[0], i0[1], 0), (i1[0], i1[1], 0), (i1[0], i1[1], 3), (i0[0], i0[1], 3)], "pierre_grise",
            vers=(-(i0[0] + i1[0]) / 2, -(i0[1] + i1[1]) / 2, 0))
        mx, my = (o0[0] + o1[0]) / 2, (o0[1] + o1[1]) / 2
        lg = math.hypot(o1[0] - o0[0], o1[1] - o0[1])
        nn = (math.cos((a0 + a1) / 2) / A, math.sin((a0 + a1) / 2) / B)
        nl = math.hypot(*nn)
        nn = (nn[0] / nl, nn[1] / nl)
        for z in (3.2, 9.4, 15.6):
            k.ouverture(mx + nn[0] * 0.02, my + nn[1] * 0.02, nn, 0, z, lg * 0.55, 4.0, "ombre", "pierre", "arc")
    k.sol(0, 0, A - 2 * ea + 1, B - 2 * eb + 1, "sable")


@batiment(F, "aqueduc_romain", "Aqueduc romain", "loisirs", 8_000_000,
          "Pont-aqueduc à trois rangs d'arches de pierre blonde.",
          "Pont du Gard (Gard)", region="mediterranee", era="antique", emplois=3, visiteurs=1500,
          metiers=[["agent_public", 1], ["vendeur", 1]], role="monument", sans_vitres=True, variantes=1)
def aqueduc(k):
    L = 60
    k.boite(0, 0, 0, L, 6, 0.04, "eau")
    for (z, h, nb, ep) in ((0, 18, 6, 6.0), (18, 16, 10, 4.6), (34, 6, 30, 3.0)):
        k.boite(0, 0, z, L, ep, h, "pierre_claire")
        pas = L / nb
        for i in range(nb):
            u = -L / 2 + pas * (i + 0.5)
            for s in (-1, 1):
                k.ouverture(0, s * ep / 2, (0, s), u * s, z + h * 0.45, pas * 0.7, h * 0.8, "ombre", "pierre",
                            "arc")
