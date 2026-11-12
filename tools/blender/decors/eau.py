"""Bateaux et pontons. Origine des bateaux : ligne de flottaison (z = 0)."""

import math

from .base import V


def _coque(d, L, l, h, coul, fond="blanc", pont="bois_clair", proue=0.32, tirant=0.3):
    """Coque pointue à l'avant (-Y) : flancs, tableau arrière, fond et liston."""
    # Profil vu de dessus : demi-largeur selon y (de l'arrière +L/2 à l'avant -L/2).
    pts = []
    n = 6
    for i in range(n + 1):
        t = i / n
        y = L / 2 - t * L
        w = l / 2 * (1.0 if t < 1 - proue else math.cos((t - (1 - proue)) / proue * math.pi / 2))
        pts.append((y, max(w, 0.02)))
    haut = []
    bas = []
    for (y, w) in pts:
        haut.append(((w, y, h), (-w, y, h)))
        bas.append(((w * 0.6, y, -tirant), (-w * 0.6, y, -tirant)))
    for i in range(n):
        for s in (0, 1):
            a, b = haut[i][s], haut[i + 1][s]
            c, e = bas[i + 1][s], bas[i][s]
            d.face([a, b, c, e], coul)
        d.face([bas[i][0], bas[i + 1][0], bas[i + 1][1], bas[i][1]], fond)
        d.face([haut[i][0], haut[i + 1][0], haut[i + 1][1], haut[i][1]], pont)
    d.face([haut[0][0], haut[0][1], bas[0][1], bas[0][0]], coul)
    return pts


def barque(d):
    """Barque à rames (4 m)."""
    _coque(d, 4.0, 1.4, 0.35, "bleu", fond="blanc", pont="bois_clair", tirant=0.25)
    for y in (-0.6, 0.4, 1.4):
        d.boite((0, y, 0.15), (1.3, 0.25, 0.05), "bois")
    for s in (-1, 1):
        d.poutre((s * 0.7, 0.2, 0.4), (s * 1.6, -0.4, 0.0), 0.04, 0.04, "bois_clair")
        d.boite((s * 1.65, -0.45, -0.02), (0.14, 0.4, 0.02), "bois_clair", rz=s * 35)


def kayak(d):
    """Kayak de mer (4,5 m)."""
    _coque(d, 4.5, 0.6, 0.18, "orange", fond="orange", pont="orange", proue=0.45, tirant=0.12)
    d.anneau((0, 0.3, 0.18), 0.22, 0.27, 0.06, "noir", n=10)
    d.tube((-1.1, 0.4, 0.4), (1.1, 0.4, 0.4), 0.02, "noir", n=4)
    for s in (-1, 1):
        d.boite((s * 1.1, 0.4, 0.38), (0.08, 0.2, 0.04), "jaune")


def voilier(d):
    """Petit voilier de plaisance (7 m)."""
    _coque(d, 7.0, 2.4, 0.7, "blanc", fond="rouge_sombre", pont="bois_clair", tirant=0.4)
    d.boite((0, 0.6, 0.7), (1.4, 2.2, 0.5), "blanc")
    d.boite((0, -0.48, 0.85), (1.0, 0.02, 0.2), "vitre")
    d.cyl((0, -0.6, 0.7), 0.06, 9.0, "galva", n=6)
    d.tube((0, -0.6, 1.8), (0, 2.6, 1.9), 0.05, "galva", n=4)
    d.face([(0, -0.55, 9.3), (0, -0.55, 1.95), (0, 2.5, 1.98)], "tissu_blanc")
    d.face([(0, -0.7, 8.4), (0, -3.3, 0.8), (0, -0.75, 1.9)], "tissu_blanc")
    d.tube((0, -0.6, 9.6), (0, -3.5, 0.75), 0.008, "metal", n=3)
    d.tube((0, -0.6, 9.6), (0, 3.4, 0.75), 0.008, "metal", n=3)


def voilier_ancre(d):
    """Voilier au mouillage, voiles roulées."""
    _coque(d, 8.0, 2.6, 0.75, "bleu", fond="blanc", pont="bois_clair", tirant=0.4)
    d.boite((0, 0.6, 0.75), (1.5, 2.4, 0.5), "blanc")
    d.cyl((0, -0.8, 0.75), 0.07, 10.5, "galva", n=6)
    d.tube((0, -0.8, 1.9), (0, 2.9, 2.0), 0.12, "tissu_bleu" if False else "bleu", n=6)
    d.tube((0, -0.8, 11.2), (0, -3.9, 0.8), 0.04, "tissu_blanc", n=4)
    d.tube((0, -0.8, 11.2), (0, 3.9, 0.8), 0.008, "metal", n=3)


def bateau_peche(d):
    """Chalutier côtier (11 m) avec sa timonerie."""
    _coque(d, 11.0, 3.6, 1.4, "rouge", fond="noir", pont="bois_gris", tirant=0.9, proue=0.4)
    d.boite((0, -5.5 + 4.4, 1.4), (3.4, 0.02, 0.18), "blanc")
    d.boite((0, 0.5, 1.4), (2.4, 2.6, 1.9), "blanc", dessus="metal")
    d.boite((0, -0.81, 2.6), (2.0, 0.02, 0.6), "vitre")
    d.boite((0, 0.5, 3.3), (2.6, 2.8, 0.1), "bleu")
    d.cyl((0, 0.5, 3.4), 0.08, 3.5, "galva", n=6)
    d.cyl((0.8, 1.6, 3.4), 0.12, 1.4, "noir", n=6)
    d.tube((0, 3.5, 1.4), (0, 4.8, 5.2), 0.1, "jaune", n=6)
    d.tube((0, 4.8, 5.2), (0, 5.4, 1.6), 0.03, "metal", n=3)
    d.boite((0, 4.2, 1.4), (2.6, 1.0, 0.7), "vert_fonte")
    for y in (-3.0, -2.0):
        d.boite((0, y, 1.4), (1.0, 0.6, 0.4), "bleu")


def bateau_moteur(d):
    """Vedette à moteur (6 m)."""
    _coque(d, 6.0, 2.2, 0.8, "blanc", fond="bleu", pont="tissu_blanc", tirant=0.35, proue=0.45)
    d.boite((0, -0.2, 0.8), (1.6, 1.2, 0.5), "blanc")
    d.profil([(-0.8, 0), (0.8, 0), (0.7, 0.5), (-0.7, 0.5)], -0.85, -0.1, "vitre", origine=(0, 0, 1.3))
    d.boite((0, 3.05, 0.0), (0.5, 0.4, 0.9), "noir")


def pedalo(d):
    """Pédalo à deux places."""
    for x in (-0.65, 0.65):
        d.tube((x, -1.2, 0.05), (x, 1.2, 0.05), 0.3, "blanc", n=8)
        d.cone((x, -1.2, 0.05), 0.3, 0.01, "blanc", n=8)
    d.boite((0, 0.2, 0.3), (1.6, 1.6, 0.1), "jaune")
    for x in (-0.35, 0.35):
        d.boite((x, 0.4, 0.4), (0.5, 0.5, 0.06), "bleu")
        d.boite((x, 0.68, 0.4), (0.5, 0.06, 0.5), "bleu")
    d.boite((0, -0.7, 0.3), (1.2, 0.5, 0.3), "jaune")


def ponton(d):
    """Ponton de bois sur pilotis (8 × 1,8 m), qui s'avance vers -Y.
    Origine : sur la berge ; le plancher est à 0,6 m au-dessus de l'eau."""
    for i in range(5):
        y = -i * 2.0
        for x in (-0.85, 0.85):
            d.cyl((x, y, -1.5), 0.12, 2.3, "bois_sombre", n=6)
    for i in range(32):
        y = 0.1 - i * 0.25
        d.boite((0, y - 0.12, 0.6), (1.9, 0.22, 0.06), "bois_gris" if i % 5 else "bois")
    for x in (-0.85, 0.85):
        d.boite((x, -4.0, 0.45), (0.12, 8.2, 0.15), "bois_sombre")
    d.cyl((0.85, -7.9, 0.66), 0.1, 0.4, "bois_sombre", n=6)
    d.cyl((-0.85, -7.9, 0.66), 0.1, 0.4, "bois_sombre", n=6)
    d.boule((1.0, -6.0, 0.25), 0.18, 0.18, 0.18, "blanc", subdiv=1, alea=0.0)


def ponton_court(d):
    """Petit embarcadère (3 m), une échelle."""
    for y in (0.0, -1.5, -3.0):
        for x in (-0.7, 0.7):
            d.cyl((x, y, -1.5), 0.1, 2.25, "bois_sombre", n=6)
    for i in range(12):
        d.boite((0, -i * 0.26, 0.6), (1.6, 0.23, 0.06), "bois_gris")
    for z in (0.0, 0.3):
        d.boite((0, -3.1, z), (0.5, 0.06, 0.04), "galva")
    for x in (-0.25, 0.25):
        d.boite((x, -3.1, -0.4), (0.04, 0.04, 1.06), "galva")


def bouee(d):
    """Bouée de mouillage rouge."""
    d.boule((0, 0, 0.05), 0.45, 0.45, 0.4, "rouge", subdiv=1, alea=0.0)
    d.cyl((0, 0, 0.4), 0.05, 0.3, "galva", n=6)
    d.anneau((0, 0, 0.7), 0.06, 0.1, 0.05, "galva", n=6)


def balise_verte(d):
    """Balise de chenal verte (tribord)."""
    d.cyl((0, 0, -0.5), 0.5, 1.2, "vert", n=8, r2=0.4)
    d.cone((0, 0, 0.7), 0.4, 1.0, "vert", n=8)
    d.cyl((0, 0, 1.7), 0.06, 0.3, "galva", n=4)
    d.boule((0, 0, 2.05), 0.08, 0.08, 0.1, "feu_vert", subdiv=1, alea=0.0)


def balise_rouge(d):
    """Balise de chenal rouge (bâbord)."""
    d.cyl((0, 0, -0.5), 0.5, 1.2, "rouge", n=8, r2=0.45)
    d.cyl((0, 0, 0.7), 0.4, 1.0, "rouge", n=8)
    d.cyl((0, 0, 1.7), 0.06, 0.3, "galva", n=4)
    d.boule((0, 0, 2.05), 0.08, 0.08, 0.1, "feu_rouge", subdiv=1, alea=0.0)


def bitte(d):
    """Bitte d'amarrage de quai."""
    d.cyl((0, 0, 0), 0.22, 0.5, "noir", n=8, r2=0.18)
    d.cyl((0, 0, 0.5), 0.3, 0.1, "noir", n=8)


def casiers(d):
    """Casiers et filets de pêcheur sur le quai."""
    for (x, y, z) in [(0, 0, 0), (0.7, 0.1, 0), (0.35, 0.05, 0.5)]:
        d.boite((x, y, z), (0.6, 0.45, 0.48), "bleu")
        d.boite((x, y, z + 0.1), (0.62, 0.47, 0.03), "noir")
    d.boule((-0.9, 0, 0.15), 0.5, 0.4, 0.2, "vert_fonte", subdiv=1, alea=0.2)
    for i in range(3):
        d.boule((-0.9 + i * 0.25, 0.3, 0.32), 0.08, 0.08, 0.08, "orange", subdiv=0, alea=0.0)


def phare(d):
    """Petit phare de jetée blanc et rouge (9 m)."""
    d.cyl((0, 0, 0), 1.4, 0.5, "pierre", n=10)
    for i in range(4):
        d.cyl((0, 0, 0.5 + i * 1.8), 0.95 - i * 0.08, 1.8, "blanc" if i % 2 == 0 else "rouge", n=10,
              r2=0.87 - i * 0.08)
    d.cyl((0, 0, 7.7), 0.95, 0.1, "metal_sombre", n=10)
    d.cyl((0, 0, 7.8), 0.55, 0.8, "lumiere", n=8)
    d.cyl((0, 0, 8.6), 0.7, 0.5, "rouge", n=8, r2=0.1)
    for i in range(10):
        a = math.tau * i / 10
        d.cyl((math.cos(a) * 0.9, math.sin(a) * 0.9, 7.8), 0.015, 0.45, "metal_sombre", n=3)
