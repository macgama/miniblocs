"""Machines agricoles d'aujourd'hui et de demain (lot 5) : outils attelés,
guidage par satellite, robots, drones et élevages nouveaux.

Repère : origine au pied, avant vers -Y, 1 unité = 1 m.
"""

import math

from .ferme import _tracteur


# --- Outils attelés modernes --------------------------------------------------------

def _attelage(d, y, couleur="metal_sombre"):
    """Timon et chape d'attelage vers l'avant (-Y)."""
    d.poutre((0, y, 0.75), (0, y - 1.2, 0.6), 0.14, 0.14, couleur)


def semoir(d):
    """Semoir combiné : trémie à grains, rampe et disques semeurs (3 m)."""
    d.boite((0, 0, 0.9), (3.0, 1.2, 1.0), "bleu", dessus="bleu")
    d.boite((0, 0, 1.9), (3.1, 1.3, 0.08), "metal_sombre")
    d.boite((0, 0.9, 0.35), (3.0, 0.5, 0.25), "metal_sombre")
    for i in range(12):
        d.roue((-1.4 + i * 0.255, 0.95, 0.25), 0.22, 0.04, "metal", n=8)
    for s in (-1, 1):
        d.roue((s * 1.6, -0.1, 0.4), 0.4, 0.25, n=10)
    _attelage(d, -0.6)


def semoir_precision(d):
    """Semoir monograine : six éléments semeurs et leurs petites trémies."""
    d.boite((0, 0, 0.7), (4.6, 0.25, 0.25), "metal_sombre")
    for i in range(6):
        x = -2.0 + i * 0.8
        d.boite((x, 0.35, 0.3), (0.25, 0.6, 0.45), "rouge")
        d.cyl((x, 0.45, 0.75), 0.2, 0.45, "jaune", n=8, dessus="jaune")
        d.roue((x, 0.75, 0.18), 0.17, 0.08, n=8)
    for s in (-1, 1):
        d.roue((s * 2.5, 0.1, 0.38), 0.38, 0.25, n=10)
    d.boite((0, 0.2, 1.05), (1.8, 0.8, 0.6), "jaune", dessus="jaune")
    _attelage(d, -0.1)


def planteuse(d):
    """Planteuse de pommes de terre quatre rangs : trémie et buttoirs."""
    d.boite((0, 0.3, 1.0), (3.2, 1.8, 1.0), "orange", dessus="orange")
    d.boite((0, 0.3, 2.0), (3.3, 1.9, 0.08), "metal_sombre")
    for i in range(4):
        x = -1.2 + i * 0.8
        d.boite((x, 1.4, 0.15), (0.3, 0.6, 0.35), "metal", rx=20)
    for s in (-1, 1):
        d.roue((s * 1.75, 0.3, 0.45), 0.45, 0.3, n=10)
    _attelage(d, -0.6)


def epandeur(d):
    """Épandeur d'engrais porté : trémie en entonnoir et deux disques."""
    d.boite((0, 0, 0.9), (2.4, 1.4, 0.7), "rouge", dessus="rouge")
    d.cyl((-0.45, 0, 0.45), 0.25, 0.45, "rouge", n=8, r2=0.6)
    d.cyl((0.45, 0, 0.45), 0.25, 0.45, "rouge", n=8, r2=0.6)
    for x in (-0.45, 0.45):
        d.cyl((x, 0.1, 0.32), 0.42, 0.04, "galva", n=10)
    d.boite((0, -0.75, 0.6), (0.9, 0.1, 1.0), "metal_sombre")


def pulverisateur(d):
    """Pulvérisateur traîné : cuve blanche, rampe repliée de 24 m."""
    d.cyl((0, 0.4, 0.9), 0.9, 1.4, "blanc", n=12, rx=90)
    d.boite((0, 0.4, 0.6), (1.6, 2.6, 0.2), "vert")
    for s in (-1, 1):
        d.roue((s * 0.95, 0.6, 0.6), 0.6, 0.25, n=12)
        d.poutre((s * 1.05, 1.9, 0.8), (s * 1.05, -0.9, 1.9), 0.12, 0.12, "metal")
    d.boite((0, 1.9, 0.8), (2.3, 0.15, 0.15), "metal")
    _attelage(d, -0.9, "vert")


def faucheuse(d):
    """Faucheuse-conditionneuse rotative : carter et assiettes."""
    d.boite((0, 0, 0.3), (3.2, 1.0, 0.5), "rouge", dessus="rouge")
    d.boite((0, 0.1, 0.8), (3.0, 0.8, 0.4), "rouge")
    for i in range(6):
        d.cyl((-1.25 + i * 0.5, -0.45, 0.05), 0.24, 0.1, "metal", n=8)
    d.boite((0, 0.6, 0.7), (3.0, 0.2, 0.5), "noir")
    _attelage(d, -0.4)


def presse_balles(d):
    """Presse à balles rondes : chambre à rouleaux et ramasseur."""
    d.boite((0, 0.2, 0.5), (2.2, 2.0, 1.6), "vert", dessus="vert")
    d.tube((-1.12, 0.6, 1.3), (1.12, 0.6, 1.3), 1.0, "vert", n=12)
    d.boite((0, -1.0, 0.25), (2.0, 0.5, 0.35), "metal_sombre")
    for i in range(6):
        d.boite((-0.8 + i * 0.32, -1.25, 0.15), (0.04, 0.2, 0.25), "galva")
    for s in (-1, 1):
        d.roue((s * 1.2, 0.2, 0.42), 0.42, 0.3, n=10)
    _attelage(d, -1.2)


def presse_enrubanneuse(d):
    """Presse-enrubanneuse : presse à l'avant, table d'enrubannage et botte filmée."""
    presse_balles(d)
    d.boite((0, 2.2, 0.55), (1.6, 1.6, 0.15), "metal_sombre")
    d.tube((-0.6, 2.2, 1.35), (0.6, 2.2, 1.35), 0.7, "film", n=12)
    d.poutre((0.95, 1.5, 0.6), (0.95, 2.9, 2.2), 0.1, 0.1, "jaune")
    d.cyl((0.95, 2.9, 1.5), 0.15, 0.6, "noir", n=6)
    for s in (-1, 1):
        d.roue((s * 0.9, 2.6, 0.3), 0.3, 0.2, n=8)


def dechaumeur(d):
    """Déchaumeur à disques : deux rangées de disques, rouleau arrière."""
    d.boite((0, 0, 0.9), (4.0, 1.6, 0.15), "jaune")
    for r, y in enumerate((-0.4, 0.3)):
        for i in range(12):
            d.cyl((-1.8 + i * 0.33 + r * 0.16, y, 0.32), 0.3, 0.04, "galva", n=10, rx=90, ry=15)
        d.boite((0, y, 0.75), (4.0, 0.12, 0.3), "jaune")
    d.tube((-1.95, 1.0, 0.3), (1.95, 1.0, 0.3), 0.3, "metal_sombre", n=10)
    _attelage(d, -0.8, "jaune")


def arracheuse(d):
    """Arracheuse automotrice de betteraves : effeuilleuse, socs et trémie."""
    d.boite((0, 0.8, 1.2), (3.0, 4.0, 2.2), "jaune", dessus="jaune")
    d.boite((0, 0.6, 3.4), (2.8, 3.0, 0.3), "jaune")
    d.boite((-0.4, -1.4, 2.0), (1.6, 1.4, 1.5), "vitre")
    d.boite((-0.4, -1.4, 3.55), (1.8, 1.6, 0.12), "jaune")
    d.boite((0, -2.6, 0.5), (3.2, 1.0, 0.8), "metal_sombre")
    for i in range(6):
        d.boite((-1.25 + i * 0.5, -3.2, 0.15), (0.18, 0.5, 0.3), "metal", rx=25)
    for s in (-1, 1):
        d.roue((s * 1.55, -0.8, 0.9), 0.9, 0.7, moyeu="jaune", n=12)
        d.roue((s * 1.55, 2.4, 0.9), 0.9, 0.7, moyeu="jaune", n=12)


def vendangeuse(d):
    """Machine à vendanger enjambeuse : haute, étroite, bacs sur les côtés."""
    for s in (-1, 1):
        d.boite((s * 1.0, 0, 1.6), (0.5, 3.2, 2.0), "rouge")
        d.boite((s * 1.0, 0.4, 2.9), (0.7, 1.6, 0.9), "rouge_sombre")
        d.roue((s * 1.0, -1.2, 0.55), 0.55, 0.35, n=10)
        d.roue((s * 1.0, 1.3, 0.55), 0.55, 0.35, n=10)
    d.boite((0, 0, 3.0), (2.5, 3.4, 0.6), "rouge")
    d.boite((0, -1.2, 3.6), (1.2, 1.1, 1.2), "vitre")
    d.boite((0, -1.2, 4.85), (1.4, 1.3, 0.1), "rouge")


# --- Guidage, autonomie, robots, drones -------------------------------------------

def tracteur_gps(d):
    """Tracteur bleu à guidage satellite : dôme d'antenne sur la cabine."""
    _tracteur(d, "bleu", "blanc")
    d.cyl((0, 0.47, 2.45), 0.22, 0.12, "blanc", n=10, dessus="noir")
    d.boite((0.35, 0.95, 1.6), (0.25, 0.04, 0.2), "noir")


def tracteur_autonome(d):
    """Tracteur autonome électrique : sans cabine, capteurs et batteries."""
    d.boite((0, -0.2, 0.75), (1.5, 2.8, 0.9), "blanc", dessus="blanc")
    d.boite((0, -0.2, 1.25), (1.3, 2.4, 0.1), "metal_sombre")
    d.boite((0, -1.62, 0.95), (1.1, 0.06, 0.25), "noir")
    for x in (-0.55, 0.55):
        d.boite((x, -1.65, 0.95), (0.18, 0.04, 0.12), "lumiere")
    d.cyl((0, -1.3, 1.3), 0.12, 0.35, "noir", n=8)
    d.cyl((0, -1.3, 1.65), 0.16, 0.12, "metal", n=8)
    d.cyl((0, 1.0, 1.3), 0.1, 0.6, "blanc", n=6)
    d.cyl((0, 1.0, 1.9), 0.2, 0.1, "blanc", n=10)
    for s in (-1, 1):
        d.roue((s * 0.95, 0.75, 0.7), 0.7, 0.45, moyeu="vert", n=12)
        d.roue((s * 0.95, -1.05, 0.7), 0.7, 0.45, moyeu="vert", n=12)
    d.boite((0, 0.2, 1.31), (1.0, 1.0, 0.03), "vert")


def robot_agricole(d):
    """Petit robot de champ à quatre roues (semis, binage)."""
    for s in (-1, 1):
        d.boite((s * 0.75, 0, 0.75), (0.12, 1.4, 0.12), "metal")
        for y in (-0.55, 0.55):
            d.boite((s * 0.75, y, 0.45), (0.1, 0.1, 0.6), "metal")
            d.roue((s * 0.75, y, 0.22), 0.22, 0.12, n=8)
    d.boite((0, 0, 0.85), (1.7, 1.3, 0.2), "orange", dessus="orange")
    d.boite((0, 0, 0.96), (1.4, 1.0, 0.03), "bleu")
    d.cyl((0, -0.55, 1.0), 0.06, 0.4, "noir", n=6)
    d.boite((0, -0.55, 1.4), (0.25, 0.12, 0.12), "noir")
    for i in range(3):
        d.boite((-0.45 + i * 0.45, 0, 0.35), (0.08, 0.08, 0.5), "galva")


def robot_desherbeur(d):
    """Robot désherbeur : châssis haut, caméras et outils de binage."""
    robot_agricole(d)
    for i in range(4):
        d.boite((-0.55 + i * 0.37, 0.45, 0.08), (0.25, 0.08, 0.05), "metal_sombre")
    d.boite((0, 0.65, 0.65), (1.2, 0.08, 0.08), "noir")
    d.boite((0, 0.62, 0.62), (0.15, 0.1, 0.1), "feu_vert")


def drone_agricole(d):
    """Drone de pulvérisation à six rotors et cuve, posé sur ses patins."""
    d.boite((0, 0, 0.75), (0.7, 0.7, 0.35), "blanc", dessus="blanc")
    d.cyl((0, 0, 0.35), 0.28, 0.4, "blanc", n=8)
    for i in range(6):
        a = math.tau * i / 6
        x, y = math.cos(a) * 1.0, math.sin(a) * 1.0
        d.poutre((0, 0, 0.85), (x, y, 0.85), 0.06, 0.06, "noir")
        d.cyl((x, y, 0.85), 0.06, 0.12, "noir", n=6)
        d.cyl((x, y, 0.97), 0.42, 0.015, "metal_sombre", n=10)
        d.boite((x * 0.9, y * 0.9, 0.62), (0.05, 0.05, 0.2), "galva")
    for s in (-1, 1):
        d.boite((s * 0.35, 0, 0.3), (0.05, 0.05, 0.6), "noir")
        d.boite((s * 0.35, 0, 0.02), (0.06, 1.0, 0.04), "noir")
    d.boite((0, 0, 0.2), (1.6, 0.05, 0.05), "galva")


def moissonneuse_autonome(d):
    """Moissonneuse-batteuse autonome : sans cabine, capteurs à l'avant."""
    d.boite((0, 0.6, 0.9), (2.8, 5.0, 2.4), "rouge", dessus="rouge")
    d.boite((0, 2.0, 3.3), (2.4, 2.0, 0.7), "rouge")
    for s in (-1, 1):
        d.roue((s * 1.55, -0.9, 0.85), 0.85, 0.6, moyeu="blanc", n=12)
        d.roue((s * 1.35, 2.6, 0.55), 0.55, 0.4, moyeu="blanc", n=10)
    d.boite((0, -1.95, 2.3), (1.6, 0.1, 0.3), "noir")
    for x in (-0.6, 0, 0.6):
        d.boite((x, -2.0, 2.3), (0.2, 0.05, 0.12), "lumiere")
    d.cyl((0, -1.2, 3.3), 0.15, 0.4, "noir", n=8)
    d.cyl((0, -1.2, 3.7), 0.22, 0.15, "metal", n=8)
    d.boite((0, -2.4, 0.6), (1.2, 1.2, 1.0), "rouge")
    d.boite((0, -3.4, 0.3), (7.0, 1.2, 0.4), "metal_sombre")
    d.tube((-3.4, -3.7, 1.0), (3.4, -3.7, 1.0), 0.45, "rouge", n=8)
    d.tube((1.5, 1.5, 3.4), (4.5, 0.5, 3.7), 0.18, "rouge", n=6)


def robot_cueilleur(d):
    """Robot cueilleur de fruits : base à chenilles, mât, bras et bac."""
    for s in (-1, 1):
        d.boite((s * 0.55, 0, 0.2), (0.3, 1.6, 0.4), "caoutchouc")
    d.boite((0, 0, 0.55), (1.2, 1.4, 0.3), "vert", dessus="vert")
    d.boite((0, 0.4, 0.85), (1.0, 0.6, 0.3), "bois_clair")
    d.boite((0, -0.3, 1.5), (0.2, 0.2, 1.6), "metal")
    for z, x in ((1.6, 0.6), (2.1, -0.6)):
        d.poutre((0, -0.3, z), (x, -0.8, z + 0.2), 0.08, 0.08, "blanc")
        d.cyl((x, -0.8, z + 0.1), 0.09, 0.2, "noir", n=6)
    d.boite((0, -0.4, 2.35), (0.3, 0.15, 0.15), "noir")


def bac_insectes(d):
    """Élevage d'insectes : étagères de bacs sous un petit abri."""
    d.boite((0, 0, 0), (3.0, 2.0, 0.1), "beton")
    for x in (-1.4, 1.4):
        for y in (-0.9, 0.9):
            d.boite((x, y, 0.1), (0.08, 0.08, 2.2), "galva")
    d.boite((0, 0, 2.3), (3.2, 2.2, 0.08), "metal")
    for z in range(4):
        for x in (-0.7, 0.7):
            d.boite((x, 0, 0.25 + z * 0.5), (1.3, 1.6, 0.25), "orange" if z % 2 else "jaune", dessus="terre")
