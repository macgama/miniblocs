"""Clôtures, murets, haies (tronçons de 2 m le long de X) et panneaux routiers."""

import math

from .base import V


# --- Clôtures : un tronçon fait 2 m, de x = -1 à x = 1 --------------------------

def cloture_bois(d):
    """Palissade de jardin blanche (piquets pointus)."""
    for x in (-1.0, 1.0):
        d.boite((x, 0, 0), (0.09, 0.09, 1.05), "blanc")
    for z in (0.3, 0.75):
        d.boite((0, 0.06, z), (2.0, 0.03, 0.08), "blanc")
    for i in range(10):
        x = -0.9 + i * 0.2
        d.boite((x, -0.0, 0.05), (0.09, 0.025, 0.85), "blanc")
        d.profil([(-0.045, 0.9), (0.045, 0.9), (0, 0.98)], -0.0125, 0.0125, "blanc", origine=(x, 0, 0))


def cloture_ranch(d):
    """Clôture de pâture : poteaux et trois lisses en bois gris."""
    for x in (-1.0, 1.0):
        d.boite((x, 0, 0), (0.12, 0.12, 1.2), "bois_gris")
    for z in (0.35, 0.7, 1.02):
        d.boite((0, 0.07, z), (2.1, 0.04, 0.11), "bois_gris")


def cloture_barbelee(d):
    """Piquets et fils (clôture de champ)."""
    d.cyl((-1.0, 0, 0), 0.05, 1.15, "bois", n=5)
    d.cyl((1.0, 0, 0), 0.05, 1.15, "bois", n=5)
    for z in (0.4, 0.7, 1.0):
        d.tube((-1.0, 0.04, z), (1.0, 0.04, z - 0.02), 0.007, "metal_sombre", n=3)


def grillage(d):
    """Grillage vert sur poteaux."""
    for x in (-1.0, 1.0):
        d.cyl((x, 0, 0), 0.03, 1.55, "vert_fonte", n=6)
    d.boite((0, 0, 0.02), (2.0, 0.01, 1.48), "vert_fonte")
    d.tube((-1.0, 0, 1.5), (1.0, 0, 1.5), 0.015, "vert_fonte", n=4)


def muret_pierre(d):
    """Muret de pierres sèches (2 m)."""
    rng = d.rng
    for rang in range(3):
        z = rang * 0.25
        x = -1.0 + (0.18 if rang % 2 else 0.0)
        while x < 0.98:
            l = rng.uniform(0.28, 0.48)
            l = min(l, 1.0 - x)
            if l < 0.08:
                break
            c = rng.choice(("pierre", "pierre_sombre", "roche_claire"))
            d.boite((x + l / 2, rng.uniform(-0.02, 0.02), z), (l - 0.03, 0.5 - rang * 0.06, 0.24), c,
                    rz=rng.uniform(-3, 3))
            x += l
    d.boite((0, 0, 0.75), (2.0, 0.36, 0.08), "pierre_sombre")


def mur_brique(d):
    """Mur de briques et son chaperon (2 m)."""
    d.boite((0, 0, 0), (2.0, 0.24, 1.6), "brique")
    d.boite((0, 0, 1.6), (2.04, 0.32, 0.08), "pierre")
    for z in (0.4, 0.8, 1.2):
        d.boite((0, 0, z), (2.005, 0.245, 0.015), "pierre_sombre")


def haie(d):
    """Haie taillée de buis ou de troène (2 m)."""
    d.boite((0, 0, 0), (2.0, 0.8, 1.4), "feuillage")
    for i in range(4):
        d.boule((-0.75 + i * 0.5, 0, 1.38), 0.3, 0.42, 0.12, "feuillage", subdiv=1, alea=0.15)


def barriere_metal(d):
    """Barrière de ville en métal (2 m)."""
    for x in (-0.95, 0.95):
        d.tube((x, 0, 0), (x, 0, 1.0), 0.03, "galva", n=6)
        d.boite((x, 0, 0), (0.08, 0.5, 0.03), "galva")
    d.tube((-0.95, 0, 1.0), (0.95, 0, 1.0), 0.03, "galva", n=6)
    d.tube((-0.95, 0, 0.2), (0.95, 0, 0.2), 0.02, "galva", n=4)
    for i in range(12):
        x = -0.8 + i * 0.146
        d.tube((x, 0, 0.2), (x, 0, 1.0), 0.012, "galva", n=4)


def glissiere(d):
    """Glissière de sécurité routière (2 m)."""
    for x in (-1.0, 1.0):
        d.boite((x, 0.08, 0), (0.08, 0.1, 0.75), "galva")
    d.profil([(-0.0, 0.45), (0.06, 0.5), (0.0, 0.58), (0.06, 0.66), (0.0, 0.7), (-0.04, 0.68), (-0.04, 0.47)],
             -1.0, 1.0, "galva", rz=90, origine=(0, 0, 0))


def portail_ferme(d):
    """Barrière de ferme en bois à cinq lisses (3,6 m)."""
    for x in (-1.9, 1.9):
        d.boite((x, 0, 0), (0.18, 0.18, 1.4), "bois_sombre")
    for z in (0.25, 0.5, 0.75, 1.0, 1.2):
        d.boite((0, 0, z), (3.6, 0.05, 0.1), "bois_gris")
    d.poutre((-1.75, 0, 0.25), (1.75, 0, 1.2), 0.05, 0.1, "bois_gris", haut=V(0, 1, 0))
    d.poutre((1.75, 0, 0.25), (1.75, 0, 1.25), 0.05, 0.1, "bois_gris", haut=V(0, 1, 0))


def palissade_bambou(d):
    """Palissade de bambous (Asie, 2 m)."""
    for i in range(16):
        x = -0.94 + i * 0.125
        h = 1.7 + 0.05 * math.sin(i * 1.7)
        d.cyl((x, 0, 0), 0.055, h, "paille", n=6)
    for z in (0.4, 1.3):
        d.tube((-1.0, -0.07, z), (1.0, -0.07, z), 0.03, "bois_clair", n=5)


# --- Panneaux et réseaux ---------------------------------------------------------

def _mat(d, h=2.3):
    d.cyl((0, 0.04, 0), 0.035, h, "galva", n=6)


def panneau_stop(d):
    """Stop."""
    _mat(d)
    d.cyl((0, 0, 1.95), 0.4, 0.03, "rouge", n=8, rx=90, rz=22.5)
    d.boite((0, -0.025, 2.03), (0.42, 0.01, 0.12), "blanc")


def panneau_cedez(d):
    """Cédez le passage."""
    _mat(d)
    d.profil([(-0.45, 2.45), (0.45, 2.45), (0, 1.7)], -0.015, 0.015, "rouge", origine=(0, 0, 0))
    d.profil([(-0.3, 2.37), (0.3, 2.37), (0, 1.85)], -0.03, -0.016, "blanc", origine=(0, 0, 0))


def panneau_vitesse(d):
    """Limitation à 50."""
    _mat(d)
    d.cyl((0, 0, 1.95), 0.32, 0.03, "rouge", n=12, rx=90)
    d.cyl((0, -0.005, 1.95), 0.25, 0.03, "blanc", n=12, rx=90)
    d.boite((-0.07, -0.025, 1.85), (0.08, 0.01, 0.2), "noir")
    d.boite((0.07, -0.025, 1.85), (0.08, 0.01, 0.2), "noir")


def panneau_danger(d):
    """Danger (triangle rouge)."""
    _mat(d)
    d.profil([(-0.42, 1.7), (0.42, 1.7), (0, 2.42)], -0.015, 0.015, "rouge")
    d.profil([(-0.28, 1.79), (0.28, 1.79), (0, 2.27)], -0.03, -0.016, "blanc")
    d.boite((0, -0.032, 1.9), (0.04, 0.01, 0.2), "noir")


def panneau_parking(d):
    """Parking (P blanc sur fond bleu)."""
    _mat(d)
    d.boite((0, 0, 1.7), (0.6, 0.03, 0.6), "bleu")
    d.boite((-0.08, -0.02, 1.82), (0.06, 0.01, 0.36), "blanc")
    d.boite((0.0, -0.02, 2.12), (0.18, 0.01, 0.06), "blanc")
    d.boite((0.0, -0.02, 1.98), (0.18, 0.01, 0.06), "blanc")
    d.boite((0.08, -0.02, 2.0), (0.06, 0.01, 0.16), "blanc")


def panneau_direction(d):
    """Panneau de direction à deux flèches."""
    d.cyl((0, 0, 0), 0.05, 2.9, "galva", n=6)
    for i, (z, s) in enumerate(((2.6, 1), (2.2, -1))):
        d.profil([(0, -0.15), (1.1, -0.15), (1.3, 0), (1.1, 0.15), (0, 0.15)], -0.015, 0.015,
                 "blanc", origine=(0, 0, z), rz=0 if s > 0 else 180)
        d.boite((s * 0.6, -0.02, z - 0.05), (0.7, 0.01, 0.08), "noir")


def panneau_entree(d):
    """Panneau d'entrée d'agglomération (blanc bordé de rouge)."""
    for x in (-0.6, 0.6):
        d.cyl((x, 0.04, 0), 0.04, 2.1, "galva", n=6)
    d.boite((0, 0, 1.3), (1.6, 0.03, 0.75), "rouge")
    d.boite((0, -0.02, 1.36), (1.48, 0.01, 0.63), "blanc")
    d.boite((0, -0.03, 1.62), (1.1, 0.01, 0.13), "noir")


def borne_km(d):
    """Borne kilométrique de route (tête rouge)."""
    d.boite((0, 0, 0), (0.42, 0.22, 0.6), "blanc")
    d.profil([(-0.21, 0), (0.21, 0), (0.21, 0.12), (0, 0.24), (-0.21, 0.12)], -0.11, 0.11, "rouge",
             origine=(0, 0, 0.6))
    d.boite((0, -0.115, 0.3), (0.2, 0.01, 0.15), "noir")


def balise(d):
    """Balise de bord de route (blanche à bande noire)."""
    d.boite((0, 0, 0), (0.1, 0.1, 1.0), "blanc")
    d.boite((0, 0, 0.75), (0.105, 0.105, 0.16), "noir")
    d.boite((0, -0.053, 0.8), (0.05, 0.01, 0.08), "orange")


def feu_tricolore(d):
    """Feu tricolore sur son mât."""
    d.cyl((0, 0.05, 0), 0.06, 2.4, "metal_sombre", n=6)
    d.boite((0, 0, 2.4), (0.32, 0.25, 0.95), "noir")
    for i, c in enumerate(("feu_vert", "orange", "rouge")):
        d.cyl((0, -0.13, 2.55 + i * 0.3), 0.1, 0.03, c, n=8, rx=90)


def poteau_electrique(d):
    """Poteau électrique en bois avec traverse et isolateurs (9 m)."""
    d.cyl((0, 0, 0), 0.14, 9.0, "bois", n=7, r2=0.1)
    d.boite((0, 0, 8.3), (1.8, 0.12, 0.12), "bois_sombre")
    for x in (-0.8, 0.0, 0.8):
        z = 8.42 if x else 9.0
        d.cyl((x, 0, z), 0.04, 0.18, "blanc", n=6)
    d.tube((0, 0, 7.6), (-0.6, 0, 8.3), 0.03, "metal_sombre", n=4)
    d.tube((0, 0, 7.6), (0.6, 0, 8.3), 0.03, "metal_sombre", n=4)


def pylone(d):
    """Pylône à haute tension (32 m), en treillis simplifié."""
    pieds = [(-3.0, -3.0), (3.0, -3.0), (3.0, 3.0), (-3.0, 3.0)]
    haut = [(-0.8, -0.8), (0.8, -0.8), (0.8, 0.8), (-0.8, 0.8)]
    for (a, b) in zip(pieds, haut):
        d.tube((a[0], a[1], 0), (b[0], b[1], 26.0), 0.12, "galva", n=4)
    for z0, z1, f0, f1 in ((0.0, 8.0, 1.0, 0.68), (8.0, 16.0, 0.68, 0.42), (16.0, 26.0, 0.42, 0.27)):
        for i in range(4):
            a, b = pieds[i], pieds[(i + 1) % 4]
            d.tube((a[0] * f0, a[1] * f0, z0), (b[0] * f1, b[1] * f1, z1), 0.05, "galva", n=4)
            d.tube((b[0] * f0, b[1] * f0, z0), (a[0] * f1, a[1] * f1, z1), 0.05, "galva", n=4)
    for z, l in ((20.0, 7.5), (24.0, 6.0)):
        d.boite((0, 0, z), (l * 2, 0.6, 0.5), "galva")
        for x in (-l + 0.4, l - 0.4):
            d.cyl((x, 0, z - 2.0), 0.12, 2.0, "vitre", n=6)
    d.cone((0, 0, 26.0), 1.0, 6.0, "galva", n=4)
