"""Rue en fête : chariots de marchands ambulants, guirlandes et fanions
(lot du 2026-11-23). Les vraies attractions et boutiques du parc de loisirs
restent dans scripts/parc : ici, ce sont de simples décors de rue ou de fête
de village, posés avec G.
"""

import math


def _chariot(d, couleur, toit, l=1.6, p=0.8):
    d.boite((0, 0, 0.45), (l, p, 0.6), couleur)
    d.boite((0, 0, 1.05), (l + 0.1, p + 0.1, 0.05), "metal")
    for x in (-l / 2 + 0.25, l / 2 - 0.25):
        d.roue((x, -p / 2 - 0.03, 0.25), 0.25, 0.06, n=8, axe="y")
        d.roue((x, p / 2 + 0.03, 0.25), 0.25, 0.06, n=8, axe="y")
    d.tube((l / 2, 0, 0.8), (l / 2 + 0.6, 0, 0.75), 0.025, "metal", n=4)
    for x in (-l / 2 + 0.05, l / 2 - 0.05):
        d.cyl((x, 0.3, 1.1), 0.02, 1.0, "metal", n=4)
    for i in range(6):
        y0 = -p / 2 - 0.2
        x0 = -l / 2 - 0.1 + i * (l + 0.2) / 6
        d.face([(x0, y0, 2.1), (x0 + (l + 0.2) / 6, y0, 2.1), (x0 + (l + 0.2) / 6, p / 2 + 0.2, 2.25),
                (x0, p / 2 + 0.2, 2.25)], toit if i % 2 == 0 else "tissu_blanc")


def chariot_hot_dog(d):
    """Chariot à hot-dogs.

    Chariot de vendeur de hot-dogs (New York, 1890)."""
    _chariot(d, "galva", "rouge")
    d.boite((-0.4, 0, 1.1), (0.5, 0.5, 0.12), "metal_sombre")
    d.boite((0.3, 0, 1.1), (0.5, 0.4, 0.2), "vitre")
    d.boite((0, -0.41, 0.6), (1.2, 0.01, 0.3), "jaune")


def chariot_popcorn(d):
    """Chariot à pop-corn.

    Chariot à pop-corn vitré (1893)."""
    _chariot(d, "rouge", "jaune", l=1.2, p=0.7)
    d.boite((0, 0, 1.1), (0.8, 0.55, 0.7), "vitre")
    d.boite((0, 0, 1.1), (0.75, 0.5, 0.35), "paille")
    d.cyl((0, 0, 1.8), 0.15, 0.1, "metal", n=8)


def chariot_ballons(d):
    """Marchand de ballons.

    Marchand de ballons de baudruche."""
    d.boite((0, 0, 0), (0.6, 0.4, 0.8), "bleu")
    d.roue((0, -0.23, 0.2), 0.2, 0.05, n=8, axe="y")
    d.roue((0, 0.23, 0.2), 0.2, 0.05, n=8, axe="y")
    cols = ("rouge", "jaune", "bleu_ciel", "vert", "rose", "orange", "violet", "rouge")
    for i, c in enumerate(cols):
        a = math.tau * i / len(cols)
        x, y, z = math.cos(a) * 0.45, math.sin(a) * 0.45, 2.1 + (i % 3) * 0.25
        d.tube((0, 0, 0.8), (x, y, z - 0.25), 0.005, "blanc", n=3)
        d.boule((x, y, z), 0.2, 0.2, 0.25, c, subdiv=1, alea=0)


def charrette_fleurs(d):
    """Charrette de fleuriste.

    Charrette de fleuriste à bras, chargée de bouquets."""
    d.boite((0, 0, 0.5), (1.6, 0.9, 0.35), "bois")
    d.roue((0.2, -0.5, 0.5), 0.5, 0.06, couleur="bois_sombre", n=10, moyeu="bois", axe="y")
    d.roue((0.2, 0.5, 0.5), 0.5, 0.06, couleur="bois_sombre", n=10, moyeu="bois", axe="y")
    d.tube((-0.8, -0.3, 0.7), (-1.6, -0.3, 0.6), 0.03, "bois", n=4)
    d.tube((-0.8, 0.3, 0.7), (-1.6, 0.3, 0.6), 0.03, "bois", n=4)
    d.tube((0.75, 0, 0.5), (0.75, 0, 0), 0.03, "bois", n=4)
    for i in range(10):
        x, y = -0.6 + (i % 5) * 0.3, -0.2 + (i // 5) * 0.4
        d.cyl((x, y, 0.85), 0.1, 0.18, "metal", n=6)
        d.boule((x, y, 1.12), 0.16, 0.16, 0.13, ("rouge", "jaune", "rose", "violet", "tissu_blanc", "orange")[i % 6],
                subdiv=1, alea=0.1)


def stand_limonade(d):
    """Stand de limonade.

    Stand de limonade en bois, comme ceux des enfants."""
    d.boite((0, 0, 0), (1.4, 0.6, 0.9), "bois_clair")
    d.boite((0, -0.31, 0.3), (1.2, 0.01, 0.4), "jaune")
    for x in (-0.65, 0.65):
        d.boite((x, 0.2, 0.9), (0.06, 0.06, 1.0), "bois")
    d.boite((0, 0.2, 1.85), (1.5, 0.3, 0.3), "tissu_blanc")
    d.cyl((-0.3, 0, 0.9), 0.12, 0.35, "vitre", n=8)
    d.cyl((-0.3, 0, 0.92), 0.11, 0.25, "jaune", n=8)
    for x in (0.1, 0.3, 0.5):
        d.cyl((x, 0, 0.9), 0.04, 0.12, "vitre", n=6)


def stand_tir(d):
    """Stand de tir forain.

    Stand de tir forain : comptoir, cibles et lots en peluche."""
    d.boite((0, 0.6, 0), (3.0, 0.2, 2.4), "bois")
    for i in range(3):
        x = -0.9 + i * 0.9
        d.cyl((x, 0.49, 1.5), 0.3, 0.02, "blanc", n=12, rx=90)
        d.cyl((x, 0.47, 1.5), 0.2, 0.02, "rouge", n=12, rx=90)
        d.cyl((x, 0.45, 1.5), 0.08, 0.02, "blanc", n=8, rx=90)
    d.boite((0, -0.5, 0), (3.0, 0.5, 1.0), "rouge")
    d.boite((0, -0.5, 1.0), (3.1, 0.6, 0.06), "bois_clair")
    for x in (-1.5, 1.5):
        d.boite((x, 0, 0), (0.1, 1.4, 2.8), "bois_sombre")
    for i in range(6):
        d.face([(-1.55 + i * 0.52, -0.8, 2.8), (-1.03 + i * 0.52, -0.8, 2.8), (-1.03 + i * 0.52, 0.7, 2.9),
                (-1.55 + i * 0.52, 0.7, 2.9)], "rouge" if i % 2 else "jaune")
    for x, c in ((-1.2, "rose"), (1.2, "bleu_ciel")):
        d.boule((x, 0.35, 2.15), 0.18, 0.15, 0.2, c, subdiv=1, alea=0.05)
    d.tube((0.5, -0.45, 1.08), (1.1, -0.45, 1.12), 0.025, "noir", n=4)


def guirlande_ampoules(d):
    """Guirlande d'ampoules.

    Guirlande d'ampoules entre deux mâts (guinguette, terrasse), 8 m."""
    for x in (-4.0, 4.0):
        d.cyl((x, 0, 0), 0.06, 3.4, "bois", n=6)
    n = 12
    pts = [(-4.0 + 8.0 * i / n, 0, 3.3 - 0.6 * math.sin(math.pi * i / n)) for i in range(n + 1)]
    for a, b in zip(pts, pts[1:]):
        d.tube(a, b, 0.008, "noir", n=3)
    for x, y, z in pts[1:-1]:
        d.boule((x, y, z - 0.1), 0.06, 0.06, 0.08, "lumiere_chaude", subdiv=1, alea=0)


def fanions(d):
    """Fanions de fête.

    Fanions de fête en triangle entre deux mâts, 8 m."""
    for x in (-4.0, 4.0):
        d.cyl((x, 0, 0), 0.05, 3.2, "bois", n=6)
    n = 16
    cols = ("rouge", "jaune", "bleu", "vert", "orange", "tissu_blanc", "rose")
    pts = [(-4.0 + 8.0 * i / n, 3.1 - 0.5 * math.sin(math.pi * i / n)) for i in range(n + 1)]
    for i, ((x0, z0), (x1, z1)) in enumerate(zip(pts, pts[1:])):
        d.tube((x0, 0, z0), (x1, 0, z1), 0.006, "blanc", n=3)
        d.face([(x0 + 0.03, 0, z0), (x1 - 0.03, 0, z1), ((x0 + x1) / 2, 0, (z0 + z1) / 2 - 0.32)], cols[i % len(cols)])


def arche_ballons(d):
    """Arche de ballons.

    Arche de ballons pour une inauguration ou une fête (4 m)."""
    n = 20
    for i in range(n + 1):
        a = math.pi * i / n
        x, z = math.cos(a) * 2.0, math.sin(a) * 2.6
        for j, dy in enumerate((-0.15, 0.15)):
            d.boule((x, dy, z + 0.2), 0.22, 0.22, 0.24, ("rouge", "tissu_blanc", "bleu", "jaune")[(i + j) % 4],
                    subdiv=1, alea=0)
    for x in (-2.0, 2.0):
        d.boite((x, 0, 0), (0.4, 0.4, 0.15), "metal_sombre")


def montgolfiere_captive(d):
    """Montgolfière captive.

    Petite montgolfière captive décorative, amarrée au sol."""
    d.boite((0, 0, 0), (1.0, 1.0, 0.8), "paille")
    for x in (-0.45, 0.45):
        for y in (-0.45, 0.45):
            d.tube((x, y, 0.8), (x * 1.6, y * 1.6, 2.3), 0.015, "noir", n=3)
    d.cyl((0, 0, 2.2), 0.4, 0.4, "metal_sombre", n=8, r2=0.9)
    d.boule((0, 0, 4.3), 2.0, 2.0, 2.2, "rouge", subdiv=2, alea=0)
    for i in range(6):
        a = math.tau * i / 6
        d.boite((math.cos(a) * 2.02, math.sin(a) * 2.02, 3.9), (0.3, 0.02, 1.0), "jaune", rz=math.degrees(a) + 90)
    for a in (0.8, 2.4, 3.9, 5.5):
        d.tube((math.cos(a) * 1.5, math.sin(a) * 1.5, 3.0), (math.cos(a) * 4.0, math.sin(a) * 4.0, 0), 0.01, "blanc", n=3)
        d.cyl((math.cos(a) * 4.0, math.sin(a) * 4.0, 0), 0.08, 0.3, "bois", n=4)
