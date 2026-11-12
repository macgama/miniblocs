"""Marché, aires de jeux, sport de plein air et plage."""

import math

from .base import V


# --- Marché -----------------------------------------------------------------------

def _caisse(d, x, y, z, contenu, rz=0.0):
    d.boite((x, y, z), (0.5, 0.35, 0.22), "bois_clair", rz=rz)
    for i in range(3):
        for j in range(2):
            u = -0.15 + i * 0.15
            v = -0.08 + j * 0.16
            c, s = math.cos(math.radians(rz)), math.sin(math.radians(rz))
            d.boule((x + c * u - s * v, y + s * u + c * v, z + 0.24), 0.08, 0.08, 0.07, contenu, subdiv=1, alea=0.05)


def etal_fruits(d):
    """Étal de fruits et légumes sous un auvent rayé (3 m)."""
    for x in (-1.4, 1.4):
        for y in (-0.6, 0.6):
            d.cyl((x, y, 0), 0.04, 2.3 if y > 0 else 2.0, "metal", n=6)
    d.boite((0, -0.1, 0.75), (3.0, 1.0, 0.06), "bois")
    d.boite((0, -0.1, 0.0), (2.9, 0.9, 0.75), "tissu_blanc")
    for i in range(6):
        x = -1.25 + i * 0.5
        _caisse(d, x, -0.25, 0.81, ("fruit_rouge", "orange", "jaune", "chou", "citrouille", "violet")[i])
    # Auvent rayé rouge et blanc
    for i in range(6):
        x = -1.25 + i * 0.5
        c = "rouge" if i % 2 == 0 else "tissu_blanc"
        d.face([(x - 0.25, 0.65, 2.3), (x + 0.25, 0.65, 2.3), (x + 0.25, -0.75, 1.95), (x - 0.25, -0.75, 1.95)], c)
        d.face([(x - 0.25, -0.75, 1.95), (x + 0.25, -0.75, 1.95), (x + 0.25, -0.8, 1.75), (x - 0.25, -0.8, 1.75)], c)


def tente_marche(d):
    """Tente blanche de marché (3 × 3 m)."""
    for x in (-1.5, 1.5):
        for y in (-1.5, 1.5):
            d.cyl((x, y, 0), 0.03, 2.2, "galva", n=4)
    d.face([(-1.55, -1.55, 2.2), (1.55, -1.55, 2.2), (0, 0, 3.1)], "tissu_blanc")
    d.face([(1.55, -1.55, 2.2), (1.55, 1.55, 2.2), (0, 0, 3.1)], "tissu_blanc")
    d.face([(1.55, 1.55, 2.2), (-1.55, 1.55, 2.2), (0, 0, 3.1)], "tissu_blanc")
    d.face([(-1.55, 1.55, 2.2), (-1.55, -1.55, 2.2), (0, 0, 3.1)], "tissu_blanc")
    for (a, b) in [((-1.55, -1.55), (1.55, -1.55)), ((1.55, -1.55), (1.55, 1.55)),
                   ((1.55, 1.55), (-1.55, 1.55)), ((-1.55, 1.55), (-1.55, -1.55))]:
        d.face([(a[0], a[1], 2.2), (b[0], b[1], 2.2), (b[0], b[1], 2.0), (a[0], a[1], 2.0)], "tissu_blanc")
    d.boite((0, 0, 0.75), (2.4, 0.9, 0.05), "bois_clair")
    for x in (-1.0, 1.0):
        d.boite((x, 0, 0), (0.06, 0.8, 0.75), "metal")
    for i in range(4):
        d.boite((-0.9 + i * 0.6, 0, 0.8), (0.4, 0.5, 0.12), ("pierre", "jaune", "bois_clair", "tissu_blanc")[i])


def parasol(d):
    """Grand parasol de marché ou de terrasse."""
    d.cyl((0, 0, 0), 0.3, 0.1, "beton", n=8)
    d.cyl((0, 0, 0.1), 0.03, 2.4, "bois", n=6)
    d.cyl((0, 0, 2.2), 1.5, 0.45, "vert", n=8, r2=0.04)
    d.cyl((0, 0, 2.17), 1.5, 0.05, "vert_fonte", n=8)


def caisses(d):
    """Pile de cagettes."""
    for i, (x, y, z, r) in enumerate([(0, 0, 0, 0), (0.55, 0.05, 0, 8), (0.25, 0, 0.23, -5), (-0.5, 0.1, 0, 15)]):
        d.boite((x, y, z), (0.5, 0.35, 0.22), "bois_clair", rz=r)


def tonneaux(d):
    """Trois tonneaux de bois cerclés."""
    for (x, y, z, couche) in [(-0.35, 0, 0, False), (0.35, 0, 0, False), (0, 0.6, 0, False)]:
        d.cyl((x, y, z), 0.3, 0.85, "bois", n=10, dessus="bois_sombre")
        for zz in (0.12, 0.7):
            d.cyl((x, y, z + zz), 0.31, 0.04, "metal_sombre", n=10)


def charrette(d):
    """Charrette à bras en bois."""
    d.boite((0, 0, 0.6), (1.2, 1.8, 0.08), "bois")
    for s in (-1, 1):
        d.boite((s * 0.6, 0, 0.68), (0.05, 1.8, 0.35), "bois_clair")
        d.roue((s * 0.7, 0.2, 0.55), 0.55, 0.08, couleur="bois_sombre", moyeu="metal_sombre", n=12)
    d.boite((0, 0.9, 0.68), (1.2, 0.05, 0.35), "bois_clair")
    for s in (-1, 1):
        d.poutre((s * 0.4, -0.9, 0.62), (s * 0.35, -2.1, 0.45), 0.06, 0.06, "bois")
    d.boite((0, 0.6, 0.0), (0.06, 0.06, 0.62), "bois_sombre")


def stand_glaces(d):
    """Triporteur à glaces."""
    d.boite((0, -0.3, 0.45), (1.0, 0.8, 0.75), "tissu_blanc")
    d.boite((0, -0.3, 1.2), (1.02, 0.82, 0.05), "rose")
    d.boite((0, -0.71, 0.6), (0.6, 0.01, 0.3), "rose")
    for x in (-0.45, 0.45):
        d.roue((x, -0.3, 0.3), 0.3, 0.05, axe="x")
    d.roue((0, 0.65, 0.3), 0.3, 0.05, axe="x")
    d.tube((0, 0.1, 0.45), (0, 0.6, 0.3), 0.03, "metal", n=4)
    d.boite((0, 0.45, 0.85), (0.25, 0.1, 0.06), "noir")
    d.cyl((0.3, -0.3, 1.25), 0.025, 1.0, "metal", n=4)
    d.cyl((0.3, -0.3, 2.0), 0.7, 0.3, "rose", n=8, r2=0.03)


# --- Aire de jeux et sport ---------------------------------------------------------

def balancoire(d):
    """Portique à deux balançoires."""
    for x in (-1.5, 1.5):
        d.tube((x, -0.8, 0), (x, 0, 2.3), 0.06, "bois", n=6)
        d.tube((x, 0.8, 0), (x, 0, 2.3), 0.06, "bois", n=6)
    d.tube((-1.6, 0, 2.32), (1.6, 0, 2.32), 0.07, "bois", n=6)
    for x in (-0.6, 0.6):
        for dx in (-0.2, 0.2):
            d.tube((x + dx, 0, 2.3), (x + dx, 0, 0.45), 0.012, "metal", n=3)
        d.boite((x, 0, 0.42), (0.45, 0.18, 0.04), "rouge")


def toboggan(d):
    """Toboggan à plate-forme et échelle."""
    for x in (-0.4, 0.4):
        for y in (-0.4, 0.4):
            d.boite((x, y, 0), (0.08, 0.08, 2.1), "bois")
    d.boite((0, 0, 1.4), (0.9, 0.9, 0.06), "bois_clair")
    d.profil([(-0.45, 0), (0.45, 0), (0, 0.5)], -0.45, 0.45, "rouge", origine=(0, 0, 2.1))
    for i in range(5):
        d.boite((0, 0.75, i * 0.28 + 0.2), (0.5, 0.05, 0.04), "bois")
    for x in (-0.25, 0.25):
        d.poutre((x, 0.45, 1.4), (x, 0.95, 0), 0.05, 0.05, "bois")
    d.poutre((0, -0.45, 1.42), (0, -2.4, 0.15), 0.5, 0.04, "jaune", haut=V(0, 0, 1))
    for s in (-1, 1):
        d.poutre((s * 0.26, -0.45, 1.52), (s * 0.26, -2.4, 0.25), 0.04, 0.16, "jaune")


def tourniquet(d):
    """Tourniquet d'aire de jeux."""
    d.cyl((0, 0, 0), 0.12, 0.3, "metal_sombre", n=8)
    d.cyl((0, 0, 0.3), 1.0, 0.06, "bleu", n=12)
    for i in range(4):
        a = math.radians(i * 90 + 45)
        d.tube((0, 0, 0.36), (math.cos(a) * 0.9, math.sin(a) * 0.9, 1.0), 0.025, "jaune", n=4)
        d.tube((0, 0, 1.05), (math.cos(a) * 0.9, math.sin(a) * 0.9, 1.0), 0.025, "jaune", n=4)


def jeu_ressort(d):
    """Jeu à ressort en forme de cheval."""
    d.boite((0, 0, 0), (0.4, 0.4, 0.04), "metal_sombre")
    d.cyl((0, 0, 0.04), 0.1, 0.4, "metal", n=8)
    d.boite((0, 0, 0.44), (0.2, 0.7, 0.25), "rouge")
    d.boite((0, -0.4, 0.6), (0.18, 0.25, 0.28), "rouge", rx=-25)
    d.tube((-0.18, -0.25, 0.75), (0.18, -0.25, 0.75), 0.02, "jaune", n=4)


def bac_a_sable(d):
    """Bac à sable bordé de rondins (3 × 3 m)."""
    for (x, y, sx, sy) in [(0, -1.5, 3.2, 0.2), (0, 1.5, 3.2, 0.2), (-1.5, 0, 0.2, 2.8), (1.5, 0, 0.2, 2.8)]:
        d.boite((x, y, 0), (sx, sy, 0.3), "bois")
    d.boite((0, 0, 0), (2.8, 2.8, 0.18), "sable")
    d.boule((0.5, 0.3, 0.18), 0.4, 0.35, 0.18, "sable", subdiv=1, alea=0.1)
    d.cyl((-0.6, -0.5, 0.18), 0.1, 0.14, "rouge", n=6, r2=0.07)
    d.boite((-0.3, -0.7, 0.18), (0.08, 0.3, 0.03), "bleu")


def cabane_jeux(d):
    """Cabane perchée avec filet d'escalade."""
    for x in (-0.8, 0.8):
        for y in (-0.8, 0.8):
            d.boite((x, y, 0), (0.12, 0.12, 1.4), "bois")
    d.boite((0, 0, 1.4), (1.8, 1.8, 0.08), "bois_clair")
    for (x, y, sx, sy) in [(0, 0.85, 1.8, 0.05), (-0.85, 0, 0.05, 1.7), (0.85, 0, 0.05, 1.7)]:
        d.boite((x, y, 1.48), (sx, sy, 0.9), "bois")
    d.profil([(-1.05, 0), (1.05, 0), (0, 0.9)], -1.05, 1.05, "vert", origine=(0, 0, 2.38))
    for i in range(5):
        x = -0.6 + i * 0.3
        d.tube((x, -0.9, 1.4), (x, -1.8, 0.0), 0.015, "galva", n=3)
    for i in range(4):
        t = (i + 1) / 5
        d.tube((-0.65, -0.9 - 0.9 * t, 1.4 * (1 - t)), (0.65, -0.9 - 0.9 * t, 1.4 * (1 - t)), 0.015, "galva", n=3)


def cage_foot(d):
    """But de football à 7 (5 × 2 m)."""
    for x in (-2.5, 2.5):
        d.cyl((x, 0, 0), 0.06, 2.0, "blanc", n=6)
        d.tube((x, 0, 2.0), (x, 1.2, 0), 0.03, "galva", n=4)
    d.tube((-2.5, 0, 2.0), (2.5, 0, 2.0), 0.06, "blanc", n=6)
    d.face([(-2.5, 0, 2.0), (2.5, 0, 2.0), (2.5, 1.2, 0.0), (-2.5, 1.2, 0.0)], "tissu_blanc")


def panier_basket(d):
    """Panier de basket sur poteau."""
    d.cyl((0, 1.0, 0), 0.08, 3.2, "metal_sombre", n=8)
    d.tube((0, 1.0, 3.1), (0, 0.15, 3.15), 0.05, "metal_sombre", n=6)
    d.boite((0, 0.1, 2.9), (1.8, 0.05, 1.05), "blanc")
    d.boite((0, 0.07, 3.05), (0.6, 0.01, 0.45), "rouge")
    d.anneau((0, -0.15, 3.05), 0.21, 0.24, 0.02, "orange", n=12)


def ping_pong(d):
    """Table de ping-pong en béton."""
    d.boite((-0.6, 0, 0), (0.25, 1.2, 0.7), "beton_sombre")
    d.boite((0.6, 0, 0), (0.25, 1.2, 0.7), "beton_sombre")
    d.boite((0, 0, 0.7), (2.74, 1.52, 0.06), "vert_fonte")
    d.boite((0, 0, 0.761), (2.74, 0.02, 0.005), "blanc")
    d.boite((0, 0, 0.76), (0.04, 1.6, 0.15), "metal_sombre")


# --- Plage ---------------------------------------------------------------------

def parasol_plage(d):
    """Parasol de plage rayé, planté dans le sable."""
    d.cyl((0, 0, -0.2), 0.025, 2.3, "blanc", n=6, ry=6)
    for i in range(8):
        a0 = math.tau * i / 8
        a1 = math.tau * (i + 1) / 8
        c = "bleu" if i % 2 else "tissu_blanc"
        d.face([(0.22, 0, 2.15), (0.22 + math.cos(a0) * 1.1, math.sin(a0) * 1.1, 1.8),
                (0.22 + math.cos(a1) * 1.1, math.sin(a1) * 1.1, 1.8)], c)


def transat(d):
    """Chaise longue en toile."""
    d.poutre((0, -0.8, 0.0), (0, 0.4, 0.35), 0.6, 0.04, "bois_clair")
    d.poutre((0, 0.4, 0.35), (0, 0.85, 0.9), 0.6, 0.04, "bois_clair")
    d.poutre((0, -0.75, 0.05), (0, 0.4, 0.38), 0.52, 0.01, "rouge")
    d.poutre((0, 0.4, 0.38), (0, 0.83, 0.92), 0.52, 0.01, "rouge")
    d.poutre((0, 0.0, 0.0), (0, 0.7, 0.62), 0.55, 0.03, "bois_clair")


def cabine_plage(d):
    """Cabine de plage rayée."""
    d.boite((0, 0, 0), (1.6, 1.6, 0.15), "bois")
    for i in range(8):
        x = -0.7 + i * 0.2
        d.boite((x, 0, 0.15), (0.2, 1.5, 2.0), "bleu" if i % 2 else "tissu_blanc")
    d.boite((0, -0.76, 0.2), (0.7, 0.02, 1.7), "bois_clair")
    d.profil([(-0.85, 0), (0.85, 0), (0, 0.6)], -0.85, 0.85, "bleu", origine=(0, 0, 2.15))


def maitre_nageur(d):
    """Chaise haute de surveillant de baignade."""
    for x in (-0.5, 0.5):
        d.tube((x, -0.4, 0), (x * 0.7, -0.1, 1.9), 0.05, "blanc", n=6)
        d.tube((x, 0.6, 0), (x * 0.7, 0.2, 1.9), 0.05, "blanc", n=6)
    for i in range(5):
        d.tube((-0.45, 0.55 - i * 0.08, 0.3 + i * 0.35), (0.45, 0.55 - i * 0.08, 0.3 + i * 0.35), 0.03, "blanc", n=4)
    d.boite((0, 0.05, 1.9), (0.8, 0.6, 0.06), "bois_clair")
    d.boite((0, 0.33, 1.96), (0.8, 0.05, 0.6), "rouge")
    d.cyl((0.35, 0, 1.96), 0.025, 1.2, "metal", n=4)
    d.boite((0.35, -0.02, 2.85), (0.03, 0.4, 0.28), "rouge")
