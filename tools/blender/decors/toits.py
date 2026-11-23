"""Toits et façades : ce qui habille un toit plat ou un mur (lot du 2026-11-23).

Climatiseurs, château d'eau de toit, chauffe-eau solaire, paraboles, enseignes
néon, lanternes, distributeur automatique, comptoir de rue, et enseignes géantes
à poser sur un toit (cornet, burger, donut, tasse, pizza), à la manière des
« drive-in » d'après-guerre. Posés avec G : sur le sol, ou sur un toit plat en
visant le toit.
"""

import math


def climatiseur(d):
    """Climatiseur.

    Climatiseur (unité extérieure), à poser au mur ou au toit."""
    d.boite((0, 0, 0), (0.9, 0.35, 0.65), "blanc")
    d.cyl((-0.12, -0.18, 0.32), 0.24, 0.02, "metal_sombre", n=10, rx=90)
    d.cyl((-0.12, -0.19, 0.32), 0.06, 0.01, "metal", n=6, rx=90)
    for i in range(4):
        d.boite((0.3, -0.18, 0.15 + i * 0.12), (0.18, 0.01, 0.03), "metal")
    d.tube((0.45, 0.1, 0.4), (0.6, 0.1, 0.4), 0.03, "galva", n=4)


def climatiseurs_toit(d):
    """Climatisation de toit.

    Groupe de climatisation de toit avec ses gaines (4 m)."""
    for x in (-1.2, 0.0):
        d.boite((x, 0.4, 0), (1.0, 1.0, 0.8), "galva")
        d.cyl((x, 0.4, 0.8), 0.38, 0.03, "metal_sombre", n=10)
        d.boite((x, 0.4, 0.83), (0.8, 0.06, 0.02), "metal")
    d.boite((1.4, 0.2, 0), (1.2, 1.2, 1.0), "galva")
    d.boite((1.4, -0.42, 0.2), (0.9, 0.02, 0.6), "metal_sombre")
    # Gaine coudée vers le bas du toit
    d.boite((1.4, 1.2, 0.2), (0.5, 0.8, 0.5), "galva")
    d.boite((0.3, 1.55, 0.2), (2.6, 0.5, 0.5), "galva")
    d.boite((-1.2, 1.55, 0.1), (0.4, 0.4, 0.1), "metal_sombre")
    d.tube((-1.9, -0.4, 0.05), (2.0, -0.4, 0.05), 0.04, "noir", n=4)


def extracteur(d):
    """Extracteur de toit.

    Extracteur de toit à chapeau tournant."""
    d.boite((0, 0, 0), (0.6, 0.6, 0.3), "galva")
    d.cyl((0, 0, 0.3), 0.18, 0.4, "galva", n=8)
    d.cyl((0, 0, 0.7), 0.3, 0.3, "metal", n=10, r2=0.18)
    d.cone((0, 0, 1.0), 0.2, 0.15, "metal", n=8)


def cheminee_metal(d):
    """Conduit de cheminée inox.

    Conduit de cheminée en inox avec son chapeau."""
    d.boite((0, 0, 0), (0.5, 0.5, 0.15), "beton")
    d.cyl((0, 0, 0.15), 0.12, 1.9, "galva", n=8)
    for z in (0.7, 1.4):
        d.cyl((0, 0, z), 0.135, 0.05, "metal", n=8)
    d.cyl((0, 0, 2.15), 0.25, 0.12, "metal", n=8, r2=0.05)


def chateau_eau_toit(d):
    """Château d'eau de toit.

    Château d'eau en bois sur pilotis, perché sur un toit (New York, 1880)."""
    for x in (-1.2, 1.2):
        for y in (-1.2, 1.2):
            d.tube((x, y, 0), (x * 0.85, y * 0.85, 3.0), 0.08, "metal_sombre", n=4)
    d.tube((-1.2, -1.2, 1.5), (1.2, 1.2, 1.5), 0.04, "metal_sombre", n=4)
    d.tube((1.2, -1.2, 1.5), (-1.2, 1.2, 1.5), 0.04, "metal_sombre", n=4)
    d.cyl((0, 0, 3.0), 1.4, 0.15, "metal_sombre", n=10)
    d.cyl((0, 0, 3.15), 1.3, 2.6, "bois", n=12, r2=1.25)
    for z in (3.6, 4.4, 5.2):
        d.cyl((0, 0, z), 1.32, 0.06, "noir", n=12)
    d.cyl((0, 0, 5.75), 1.32, 0.9, "bois_sombre", n=12, r2=0.05)
    d.poutre((1.3, 0, 0), (1.3, 0, 5.6), 0.3, 0.06, "metal")


def chauffe_eau_solaire(d):
    """Chauffe-eau solaire.

    Chauffe-eau solaire de toit : capteurs et ballon (Méditerranée)."""
    d.boite((0, 0, 0), (2.0, 0.08, 1.2), "noir", rx=-55)
    d.boite((0, 0, 0), (1.9, 0.09, 1.1), "vitre", rx=-55)
    d.tube((-1.0, 0.75, 0), (-1.0, 0.75, 0.95), 0.03, "galva", n=4)
    d.tube((1.0, 0.75, 0), (1.0, 0.75, 0.95), 0.03, "galva", n=4)
    d.tube((-1.1, 0.75, 1.15), (1.1, 0.75, 1.15), 0.28, "blanc", n=10)


def parabole(d):
    """Antenne parabolique.

    Antenne parabolique sur son support."""
    d.tube((0, 0, 0), (0, 0, 0.9), 0.03, "galva", n=6)
    d.cyl((0, -0.05, 0.9), 0.4, 0.12, "blanc", n=12, r2=0.1, rx=60)
    d.tube((0, -0.1, 1.0), (0, -0.55, 1.3), 0.015, "galva", n=4)
    d.boite((0, -0.57, 1.28), (0.06, 0.08, 0.06), "noir")


def antenne_rateau(d):
    """Antenne râteau.

    Antenne râteau de télévision (années 1950-2000)."""
    d.tube((0, 0, 0), (0, 0, 2.6), 0.025, "galva", n=6)
    d.tube((0, -0.8, 2.4), (0, 0.8, 2.4), 0.015, "galva", n=4)
    for i in range(7):
        y = -0.7 + i * 0.23
        w = 0.55 - i * 0.04
        d.tube((-w, y, 2.4), (w, y, 2.4), 0.008, "galva", n=3)
    for a in (0, 120, 240):
        r = math.radians(a)
        d.tube((0, 0, 1.6), (math.cos(r) * 0.8, math.sin(r) * 0.8, 0), 0.006, "metal", n=3)


def enseigne_neon(d):
    """Enseigne néon verticale.

    Enseigne verticale à néons, à accrocher à une façade."""
    d.tube((0, 0.35, 0.3), (0, 0, 0.3), 0.03, "metal_sombre", n=4)
    d.tube((0, 0.35, 2.7), (0, 0, 2.7), 0.03, "metal_sombre", n=4)
    d.boite((0, 0, 0), (0.12, 0.55, 3.0), "noir")
    for i in range(5):
        d.boite((0, 0, 0.25 + i * 0.55), (0.14, 0.4, 0.38), "feu_rouge" if i % 2 == 0 else "lumiere")
    d.boite((0, 0, 3.0), (0.16, 0.6, 0.06), "feu_rouge")


def enseigne_lumineuse(d):
    """Enseigne lumineuse sur pied.

    Enseigne lumineuse sur pied (rues commerçantes d'Asie)."""
    d.boite((0, 0, 0), (0.5, 0.3, 0.12), "metal_sombre")
    d.boite((0, 0, 0.12), (0.36, 0.26, 1.2), "lumiere")
    for i in range(3):
        d.boite((0, -0.135, 0.3 + i * 0.35), (0.22, 0.01, 0.22), "rouge")


def lanternes_rouges(d):
    """Lanternes rouges.

    Guirlande de lanternes rouges en papier (chōchin), 4 m."""
    for x in (-2.0, 2.0):
        d.cyl((x, 0, 0), 0.05, 2.8, "bois_sombre", n=5)
    for i in range(5):
        x = -1.6 + i * 0.8
        z = 2.55 - 0.18 * math.sin(math.pi * (i + 0.5) / 5)
        d.tube((x, 0, z + 0.25), (x, 0, z + 0.1), 0.01, "noir", n=3)
        d.boule((x, 0, z - 0.12), 0.16, 0.16, 0.22, "feu_rouge", subdiv=1, alea=0)
        d.cyl((x, 0, z + 0.06), 0.1, 0.04, "noir", n=6)
    d.tube((-2.0, 0, 2.75), (2.0, 0, 2.75), 0.008, "noir", n=3)


def distributeur_boissons(d):
    """Distributeur de boissons.

    Distributeur automatique de boissons, éclairé la nuit."""
    d.boite((0, 0, 0), (1.0, 0.75, 1.85), "rouge")
    d.boite((-0.12, -0.38, 0.75), (0.62, 0.02, 0.95), "lumiere")
    for i in range(3):
        for j in range(5):
            d.boite((-0.36 + j * 0.12, -0.395, 0.95 + i * 0.28), (0.07, 0.01, 0.16),
                    ("bleu", "jaune", "vert", "orange", "blanc")[(i + j) % 5])
    d.boite((0.33, -0.38, 0.8), (0.2, 0.02, 0.5), "metal_sombre")
    d.boite((-0.12, -0.38, 0.2), (0.62, 0.03, 0.22), "noir")


def comptoir_tabourets(d):
    """Comptoir et tabourets.

    Comptoir de rue et ses tabourets (bar à nouilles, buvette), 3 m."""
    d.boite((0, 0.2, 0), (3.0, 0.5, 1.0), "bois")
    d.boite((0, 0.1, 1.0), (3.2, 0.75, 0.06), "orange")
    for i in range(5):
        x = -1.2 + i * 0.6
        d.cyl((x, -0.45, 0), 0.03, 0.7, "metal", n=5)
        d.cyl((x, -0.45, 0.7), 0.16, 0.08, "rouge", n=8)
        d.anneau((x, -0.45, 0.25), 0.1, 0.12, 0.02, "metal", n=6)
        d.cyl((x, -0.05, 1.06), 0.1, 0.08, "blanc", n=8, r2=0.07)


def store_terrasse(d):
    """Auvent de tuiles.

    Auvent de tuiles sur consoles, au-dessus d'un comptoir (Japon), 4 m."""
    for x in (-1.9, 0, 1.9):
        d.poutre((x, 0.5, 2.3), (x, -0.6, 2.0), 0.08, 0.08, "noir")
    d.boite((0, -0.05, 2.15), (4.2, 1.3, 0.06), "rouge_sombre", rx=-14)
    for i in range(14):
        d.boite((-2.0 + i * 0.31, -0.67, 1.97), (0.06, 0.1, 0.08), "rouge")
    for i in range(4):
        d.face([(-1.6 + i, -0.6, 2.0), (-1.1 + i, -0.6, 2.0), (-1.1 + i, -0.62, 1.45), (-1.6 + i, -0.62, 1.45)],
               "tissu_blanc" if i % 2 else "bleu")


def escalier_exterieur(d):
    """Escalier extérieur.

    Escalier de façade en béton avec rampe (pour monter à un toit-terrasse), 3 m de haut."""
    for i in range(12):
        d.boite((0, -2.4 + i * 0.4, 0), (1.1, 0.4, 0.25 * (i + 1)), "beton", dessus="pierre")
    d.boite((0, 2.6, 0), (1.1, 1.2, 3.0), "beton", dessus="pierre")
    for i in range(0, 12, 3):
        d.tube((-0.5, -2.4 + i * 0.4, 0.25 * (i + 1)), (-0.5, -2.4 + i * 0.4, 0.25 * (i + 1) + 0.9), 0.025, "noir", n=4)
    d.tube((-0.5, -2.4, 1.15), (-0.5, 2.0, 3.9), 0.03, "noir", n=4)


# --- Enseignes géantes (architecture « drive-in ») --------------------------------

def _mat(d, h):
    d.boite((0, 0, 0), (0.7, 0.7, 0.2), "metal_sombre")
    d.cyl((0, 0, 0.2), 0.1, h, "metal", n=6)


def cornet_geant(d):
    """Cornet de glace géant.

    Cornet de glace géant, enseigne de toit (glacier)."""
    _mat(d, 0.6)
    d.cyl((0, 0, 0.8), 0.06, 2.2, "bois_clair", n=10, r2=0.75)
    for z in (1.4, 2.0, 2.6):
        d.cyl((0, 0, z), 0.06 + (z - 0.8) / 2.2 * 0.69, 0.04, "bois", n=10)
    d.boule((0, 0, 3.3), 0.85, 0.85, 0.6, "rose", subdiv=2, alea=0.05)
    d.boule((0, 0, 3.95), 0.6, 0.6, 0.45, "tissu_blanc", subdiv=2, alea=0.05)
    d.boule((0, 0, 4.5), 0.18, 0.18, 0.18, "fruit_rouge", subdiv=1, alea=0)


def burger_geant(d):
    """Burger géant.

    Burger géant, enseigne de toit (snack, années 1950)."""
    _mat(d, 0.8)
    d.cyl((0, 0, 1.0), 1.2, 0.4, "bois_clair", n=14, r2=1.25)
    d.cyl((0, 0, 1.4), 1.35, 0.1, "vert", n=12)
    d.cyl((0, 0, 1.5), 1.28, 0.4, "bois_sombre", n=14)
    d.cyl((0, 0, 1.9), 1.32, 0.08, "jaune", n=4, rz=45)
    d.cyl((0, 0, 1.98), 1.3, 0.12, "fruit_rouge", n=12)
    d.boule((0, 0, 2.1), 1.28, 1.28, 0.75, "bois_clair", subdiv=2, alea=0.02, aplatir_bas=1.0)
    for i in range(8):
        a = math.tau * i / 8 + 0.3
        d.boule((math.cos(a) * 0.7, math.sin(a) * 0.7, 2.6), 0.06, 0.04, 0.03, "tissu_blanc", subdiv=1, alea=0)


def donut_geant(d):
    """Donut géant.

    Donut géant dressé, enseigne de toit (boulangerie, café)."""
    _mat(d, 1.2)
    n = 14
    R, r = 1.2, 0.5
    for i in range(n):
        a0, a1 = math.tau * i / n, math.tau * (i + 1) / n
        p0 = (math.cos(a0) * R, 0, 2.9 + math.sin(a0) * R)
        p1 = (math.cos(a1) * R, 0, 2.9 + math.sin(a1) * R)
        d.tube(p0, p1, r, "bois_clair", n=8)
        d.tube((p0[0], -0.15, p0[2]), (p1[0], -0.15, p1[2]), r * 0.9, "rose", n=8)
    for i in range(10):
        a = math.tau * i / 10
        d.boite((math.cos(a) * R, -0.62, 2.9 + math.sin(a) * R), (0.15, 0.04, 0.05),
                ("jaune", "bleu_ciel", "tissu_blanc", "vert")[i % 4], rz=0, ry=i * 37)


def tasse_geante(d):
    """Tasse de café géante.

    Tasse de café géante fumante, enseigne de toit (café)."""
    _mat(d, 0.4)
    d.cyl((0, 0, 0.6), 0.9, 0.08, "blanc", n=14, r2=1.1)
    d.cyl((0, 0, 0.68), 0.7, 1.4, "blanc", n=14, r2=0.95)
    d.disque((0, 0, 1.98), 0.9, "bois_sombre", n=14)
    for i in range(7):
        a0, a1 = math.pi * (i / 6 - 0.5), math.pi * ((i + 1) / 6 - 0.5)
        if i == 6:
            break
        d.tube((0.95 + math.cos(a0) * 0.35, 0, 1.35 + math.sin(a0) * 0.35),
               (0.95 + math.cos(a1) * 0.35, 0, 1.35 + math.sin(a1) * 0.35), 0.08, "blanc", n=6)
    for i, z in enumerate((2.3, 2.75, 3.2)):
        d.boule((0.15 * (-1) ** i, 0, z), 0.25, 0.12, 0.22, "tissu_blanc", subdiv=1, alea=0.1)


def pizza_geante(d):
    """Part de pizza géante.

    Part de pizza géante, enseigne de toit (pizzeria)."""
    _mat(d, 0.8)
    d.profil([(-1.1, 2.9), (1.1, 2.9), (0, 0.9)], -0.12, 0.12, "jaune", cotes="jaune")
    d.profil([(-1.15, 2.85), (1.15, 2.85), (1.1, 3.15), (-1.1, 3.15)], -0.18, 0.18, "bois_clair")
    for x, z in ((-0.4, 2.4), (0.35, 2.3), (0.0, 1.8), (0.1, 1.35)):
        d.cyl((x, -0.13, z), 0.14, 0.03, "fruit_rouge", n=8, rx=90)
    d.cyl((-0.15, -0.13, 2.0), 0.08, 0.03, "vert", n=6, rx=90)
