"""Animaux sauvages du zoo et objets des enclos, à taille réelle, tête vers -Y.

Même palette que les autres décors (pas de nouvelle couleur) : les pelages
sont faits avec les teintes existantes (sable, foin, gris d'âne, roux, noir…).
"""

import math

from .animaux import _pattes


def quadrupede(d, robe, L, larg, haut_dos, patte, ep_patte, cou=None, tete=(0.3, 0.4, 0.3), tete_col=None,
               queue=0.5, queue_col=None, sabot="sabot", ventre=None):
    """Corps en boîte arrondie sur quatre pattes. cou : (dy, dz) du sommet du cou par rapport à l'avant du corps."""
    tete_col = tete_col or robe
    queue_col = queue_col or robe
    ep_corps = haut_dos - patte
    _pattes(d, (-larg * 0.32, larg * 0.32), (-L * 0.36, L * 0.36), patte + ep_corps * 0.25, ep_patte, robe,
            sabot=sabot)
    d.boule((0, 0, patte + ep_corps * 0.55), larg * 0.5, L * 0.5, ep_corps * 0.55, robe, subdiv=1, alea=0.04)
    if ventre:
        d.boule((0, 0, patte + ep_corps * 0.3), larg * 0.42, L * 0.38, ep_corps * 0.3, ventre, subdiv=1, alea=0.03)
    ay, az = -L * 0.45, patte + ep_corps * 0.75
    if cou:
        hy, hz = ay + cou[0], az + cou[1]
        d.poutre((0, ay, az), (0, hy, hz), tete[0] * 0.7, tete[0] * 0.8, robe)
    else:
        hy, hz = ay - tete[1] * 0.3, az
    d.boule((0, hy - tete[1] * 0.3, hz), tete[0] / 2, tete[1] / 2, tete[2] / 2, tete_col, subdiv=1, alea=0.03)
    if queue > 0:
        d.tube((0, L * 0.48, az), (0, L * 0.48 + queue * 0.4, az - queue * 0.9), 0.03 + larg * 0.02, queue_col,
               n=4, r2=0.015)
    return hy - tete[1] * 0.3, hz


# --- Savane ----------------------------------------------------------------------

def lion(d):
    """Lion à crinière."""
    hy, hz = quadrupede(d, "sable", 1.9, 0.55, 1.05, 0.55, 0.14, tete=(0.36, 0.42, 0.34), queue=0.9)
    d.boule((0, hy + 0.12, hz + 0.02), 0.34, 0.3, 0.36, "cheval_bai", subdiv=1, alea=0.12)
    d.boule((0, hy - 0.05, hz), 0.19, 0.22, 0.18, "sable", subdiv=1, alea=0.03)
    d.boite((0, hy - 0.24, hz - 0.06), (0.12, 0.06, 0.08), "pelage_noir")
    d.boule((0, 1.37, 0.65), 0.07, 0.07, 0.09, "cheval_bai", subdiv=1, alea=0.1)


def lionne(d):
    """Lionne couchée au soleil."""
    d.boule((0, 0, 0.32), 0.32, 0.85, 0.3, "sable", subdiv=1, alea=0.04)
    for s in (-1, 1):
        d.boite((s * 0.16, -0.85, 0.0), (0.12, 0.45, 0.1), "sable")
    d.boule((0, -0.95, 0.55), 0.17, 0.22, 0.17, "sable", subdiv=1, alea=0.03)
    d.boite((0, -1.15, 0.5), (0.1, 0.06, 0.07), "pelage_noir")
    for s in (-1, 1):
        d.boite((s * 0.12, -0.92, 0.7), (0.06, 0.04, 0.06), "sable")
    d.tube((0, 0.8, 0.25), (0.4, 1.4, 0.05), 0.03, "sable", n=4)


def elephant(d):
    """Éléphant d'Afrique et ses défenses."""
    hy, hz = quadrupede(d, "gris_ane", 4.2, 1.6, 3.2, 1.6, 0.5, tete=(1.1, 1.0, 1.1), queue=0.9,
                        sabot="pierre_sombre")
    for s in (-1, 1):
        d.boite((s * 0.6, hy + 0.35, hz - 0.55), (0.12, 0.8, 1.3), "gris_ane", rz=s * 15)
        d.tube((s * 0.25, hy - 0.35, hz - 0.35), (s * 0.35, hy - 1.05, hz - 0.55), 0.07, "corne", n=5, r2=0.03)
    d.tube((0, hy - 0.45, hz - 0.1), (0, hy - 0.85, hz - 1.2), 0.18, "gris_ane", n=6, r2=0.11)
    d.tube((0, hy - 0.85, hz - 1.2), (0, hy - 0.8, hz - 2.2), 0.11, "gris_ane", n=6, r2=0.08)


def elephanteau(d):
    """Éléphanteau."""
    hy, hz = quadrupede(d, "gris_ane", 2.0, 0.8, 1.5, 0.75, 0.24, tete=(0.55, 0.5, 0.55), queue=0.4,
                        sabot="pierre_sombre")
    for s in (-1, 1):
        d.boite((s * 0.3, hy + 0.18, hz - 0.28), (0.06, 0.4, 0.6), "gris_ane", rz=s * 15)
    d.tube((0, hy - 0.22, hz - 0.05), (0, hy - 0.4, hz - 0.85), 0.08, "gris_ane", n=5, r2=0.05)


def girafe(d):
    """Girafe réticulée."""
    hy, hz = quadrupede(d, "foin", 2.2, 0.7, 2.9, 2.0, 0.13, cou=(-0.55, 2.2), tete=(0.26, 0.6, 0.26), queue=0.8)
    for (x, y, z) in ((0.36, -0.3, 2.6), (-0.36, 0.3, 2.55), (0.36, 0.5, 2.5), (-0.36, -0.55, 2.65),
                      (0.0, 0.2, 2.95), (0.36, 0.1, 2.2), (-0.36, -0.1, 2.3)):
        d.boite((x, y, z), (0.02 if x else 0.3, 0.32, 0.28 if x else 0.02), "cheval_bai")
    for z in (3.4, 3.9, 4.4):
        for s in (-1, 1):
            d.boite((s * 0.17, -0.9 - (z - 3.0) * 0.2, z), (0.02, 0.18, 0.18), "cheval_bai")
    for s in (-1, 1):
        d.tube((s * 0.06, hy + 0.15, hz + 0.1), (s * 0.08, hy + 0.15, hz + 0.32), 0.03, "pelage_noir", n=4)
        d.boite((s * 0.16, hy + 0.2, hz + 0.08), (0.12, 0.04, 0.05), "foin")
    d.boite((0, 0.1, 2.85), (0.06, 0.02, 0.05), "foin_sombre")
    d.poutre((0, -0.95, 3.0), (0, -1.55, 4.9), 0.05, 0.1, "cheval_bai")


def zebre(d):
    """Zèbre des plaines."""
    hy, hz = quadrupede(d, "pelage_blanc", 2.1, 0.5, 1.4, 0.8, 0.11, cou=(-0.35, 0.45), tete=(0.24, 0.6, 0.28),
                        queue=0.6, queue_col="pelage_noir")
    for i in range(7):
        y = -0.75 + i * 0.25
        for s in (-1, 1):
            d.boite((s * 0.255, y, 0.85), (0.01, 0.08, 0.5), "pelage_noir", rx=10)
    d.boite((0, -0.6, 1.4), (0.08, 0.3, 0.12), "pelage_noir", rx=-40)
    d.boite((0, hy - 0.28, hz - 0.08), (0.18, 0.12, 0.14), "pelage_noir")
    for s in (-1, 1):
        d.boite((s * 0.07, hy + 0.25, hz + 0.18), (0.05, 0.05, 0.15), "pelage_blanc")


def rhinoceros(d):
    """Rhinocéros blanc et ses deux cornes."""
    hy, hz = quadrupede(d, "roche", 3.6, 1.3, 1.8, 0.65, 0.34, tete=(0.6, 0.85, 0.55), queue=0.5,
                        sabot="pierre_sombre")
    d.cone((0, hy - 0.3, hz + 0.18), 0.12, 0.55, "corne", n=5)
    d.cone((0, hy - 0.02, hz + 0.24), 0.08, 0.25, "corne", n=5)
    for s in (-1, 1):
        d.boite((s * 0.18, hy + 0.35, hz + 0.25), (0.08, 0.05, 0.16), "roche")
    d.boule((0, -0.9, 1.6), 0.5, 0.55, 0.3, "roche", subdiv=1, alea=0.05)


def hippopotame(d):
    """Hippopotame."""
    hy, hz = quadrupede(d, "gris_ane", 3.5, 1.5, 1.5, 0.45, 0.32, tete=(0.85, 0.9, 0.7), queue=0.25,
                        sabot="pierre_sombre", ventre="cochon")
    d.boite((0, hy - 0.4, hz - 0.35), (0.75, 0.25, 0.3), "cochon")
    for s in (-1, 1):
        d.boite((s * 0.22, hy + 0.3, hz + 0.32), (0.08, 0.05, 0.08), "gris_ane")
        d.boite((s * 0.25, hy - 0.05, hz + 0.3), (0.1, 0.1, 0.08), "pelage_noir")


def autruche(d):
    """Autruche."""
    for s in (-1, 1):
        d.tube((s * 0.12, 0.0, 0.0), (s * 0.12, 0.05, 1.05), 0.04, "museau", n=4)
    d.boule((0, 0.05, 1.25), 0.38, 0.55, 0.32, "pelage_noir", subdiv=1, alea=0.1)
    d.boule((0, 0.55, 1.3), 0.25, 0.2, 0.2, "pelage_blanc", subdiv=1, alea=0.15)
    d.tube((0, -0.35, 1.35), (0, -0.5, 2.25), 0.05, "museau", n=5)
    d.boule((0, -0.55, 2.3), 0.07, 0.1, 0.07, "museau", subdiv=1, alea=0.02)
    d.boite((0, -0.68, 2.27), (0.05, 0.1, 0.03), "bec")


def suricate(d):
    """Suricate debout, en sentinelle."""
    d.boule((0, 0, 0.1), 0.06, 0.09, 0.08, "sable", subdiv=1, alea=0.03)
    d.boule((0, 0, 0.2), 0.06, 0.06, 0.12, "sable", subdiv=1, alea=0.03)
    d.boule((0, -0.02, 0.34), 0.045, 0.06, 0.045, "sable", subdiv=1, alea=0.02)
    for s in (-1, 1):
        d.boite((s * 0.02, -0.06, 0.34), (0.02, 0.015, 0.015), "pelage_noir")
    d.tube((0, 0.06, 0.04), (0, 0.22, 0.01), 0.015, "sable", n=4)


# --- Forêts et montagnes d'Asie --------------------------------------------------

def tigre(d):
    """Tigre du Bengale."""
    hy, hz = quadrupede(d, "orange", 2.1, 0.55, 1.0, 0.5, 0.15, tete=(0.36, 0.4, 0.32), queue=0.95,
                        ventre="pelage_blanc")
    for i in range(8):
        y = -0.75 + i * 0.21
        for s in (-1, 1):
            d.boite((s * 0.27, y, 0.62), (0.01, 0.05, 0.32), "pelage_noir", rx=15)
        d.boite((0, y, 1.04), (0.3, 0.05, 0.01), "pelage_noir")
    d.boite((0, hy - 0.2, hz - 0.06), (0.16, 0.06, 0.1), "pelage_blanc")
    for s in (-1, 1):
        d.boite((s * 0.12, hy + 0.08, hz + 0.16), (0.07, 0.04, 0.07), "orange")


def panda(d):
    """Panda géant qui grignote du bambou."""
    d.boule((0, 0.1, 0.4), 0.42, 0.45, 0.42, "pelage_blanc", subdiv=1, alea=0.04)
    d.boule((0, 0.05, 0.55), 0.45, 0.2, 0.22, "pelage_noir", subdiv=1, alea=0.04)
    for s in (-1, 1):
        d.boite((s * 0.3, -0.2, 0.0), (0.2, 0.5, 0.2), "pelage_noir")
        d.tube((s * 0.3, -0.2, 0.55), (s * 0.15, -0.45, 0.9), 0.09, "pelage_noir", n=5)
    d.boule((0, -0.15, 1.05), 0.27, 0.24, 0.24, "pelage_blanc", subdiv=1, alea=0.03)
    for s in (-1, 1):
        d.boule((s * 0.2, -0.12, 1.25), 0.08, 0.05, 0.08, "pelage_noir", subdiv=1, alea=0.02)
        d.boite((s * 0.09, -0.37, 1.06), (0.08, 0.02, 0.09), "pelage_noir")
    d.boite((0, -0.4, 0.98), (0.06, 0.03, 0.04), "pelage_noir")
    d.tube((-0.25, -0.5, 0.75), (0.2, -0.45, 1.25), 0.025, "vert", n=4)


def panda_roux(d):
    """Panda roux à queue annelée."""
    hy, hz = quadrupede(d, "pelage_roux", 0.6, 0.25, 0.4, 0.15, 0.06, tete=(0.2, 0.18, 0.17), queue=0)
    d.boite((0, hy - 0.08, hz - 0.03), (0.1, 0.05, 0.06), "pelage_blanc")
    for s in (-1, 1):
        d.boite((s * 0.08, hy + 0.02, hz + 0.08), (0.05, 0.03, 0.06), "pelage_blanc")
    for i in range(4):
        d.tube((0, 0.3 + i * 0.1, 0.3 - i * 0.04), (0, 0.4 + i * 0.1, 0.26 - i * 0.04), 0.06,
               "pelage_roux" if i % 2 == 0 else "cheval_bai", n=6)


def ours_brun(d):
    """Ours brun."""
    hy, hz = quadrupede(d, "cheval_bai", 2.0, 0.85, 1.2, 0.5, 0.22, tete=(0.4, 0.45, 0.38), queue=0.1)
    d.boule((0, -0.55, 1.15), 0.45, 0.4, 0.3, "cheval_bai", subdiv=1, alea=0.06)
    d.boite((0, hy - 0.22, hz - 0.08), (0.16, 0.12, 0.14), "pelage_roux")
    d.boite((0, hy - 0.29, hz - 0.0), (0.06, 0.03, 0.04), "pelage_noir")
    for s in (-1, 1):
        d.boule((s * 0.15, hy + 0.08, hz + 0.18), 0.06, 0.04, 0.06, "cheval_bai", subdiv=1, alea=0.02)


def ours_polaire(d):
    """Ours polaire."""
    hy, hz = quadrupede(d, "pelage_creme", 2.4, 0.9, 1.3, 0.55, 0.24, cou=(-0.4, -0.05), tete=(0.36, 0.5, 0.34),
                        queue=0.1)
    d.boite((0, hy - 0.26, hz - 0.08), (0.06, 0.03, 0.05), "pelage_noir")
    for s in (-1, 1):
        d.boule((s * 0.13, hy + 0.12, hz + 0.16), 0.05, 0.04, 0.05, "pelage_creme", subdiv=1, alea=0.02)


# --- Grands singes -----------------------------------------------------------------

def gorille(d):
    """Gorille dos argenté, appuyé sur ses poings."""
    d.boule((0, 0.1, 0.85), 0.5, 0.45, 0.5, "pelage_noir", subdiv=1, alea=0.06)
    d.boule((0, 0.25, 1.05), 0.42, 0.35, 0.3, "roche_claire", subdiv=1, alea=0.06)
    for s in (-1, 1):
        d.tube((s * 0.45, -0.25, 1.15), (s * 0.5, -0.45, 0.1), 0.13, "pelage_noir", n=5)
        d.boule((s * 0.5, -0.45, 0.08), 0.12, 0.12, 0.08, "pelage_noir", subdiv=1, alea=0.03)
        d.tube((s * 0.25, 0.35, 0.6), (s * 0.3, 0.3, 0.0), 0.12, "pelage_noir", n=5)
    d.boule((0, -0.35, 1.35), 0.22, 0.22, 0.25, "pelage_noir", subdiv=1, alea=0.03)
    d.boite((0, -0.55, 1.25), (0.22, 0.08, 0.16), "pierre_sombre")


def chimpanze(d):
    """Chimpanzé assis."""
    d.boule((0, 0, 0.35), 0.25, 0.22, 0.32, "pelage_noir", subdiv=1, alea=0.06)
    for s in (-1, 1):
        d.tube((s * 0.25, -0.05, 0.55), (s * 0.3, -0.25, 0.05), 0.06, "pelage_noir", n=4)
        d.tube((s * 0.15, -0.1, 0.12), (s * 0.18, -0.35, 0.05), 0.07, "pelage_noir", n=4)
    d.boule((0, -0.08, 0.8), 0.15, 0.15, 0.16, "pelage_noir", subdiv=1, alea=0.03)
    d.boite((0, -0.22, 0.72), (0.15, 0.07, 0.14), "museau")
    for s in (-1, 1):
        d.boite((s * 0.16, -0.08, 0.82), (0.05, 0.03, 0.07), "museau")


def orang_outan(d):
    """Orang-outan aux longs bras."""
    d.boule((0, 0, 0.45), 0.32, 0.28, 0.38, "pelage_roux", subdiv=1, alea=0.1)
    for s in (-1, 1):
        d.tube((s * 0.3, -0.05, 0.75), (s * 0.55, -0.2, 0.05), 0.07, "pelage_roux", n=4)
        d.tube((s * 0.15, 0.05, 0.12), (s * 0.25, -0.3, 0.05), 0.08, "pelage_roux", n=4)
    d.boule((0, -0.1, 0.95), 0.17, 0.15, 0.17, "pelage_roux", subdiv=1, alea=0.04)
    d.boite((0, -0.24, 0.9), (0.24, 0.05, 0.18), "cheval_bai")


# --- Régions froides et rivages ------------------------------------------------------

def manchot(d):
    """Manchot."""
    d.boule((0, 0, 0.35), 0.17, 0.15, 0.33, "pelage_noir", subdiv=1, alea=0.03)
    d.boule((0, -0.06, 0.32), 0.13, 0.1, 0.27, "pelage_blanc", subdiv=1, alea=0.02)
    d.boule((0, 0, 0.7), 0.1, 0.1, 0.1, "pelage_noir", subdiv=1, alea=0.02)
    d.boite((0, -0.13, 0.68), (0.04, 0.08, 0.03), "bec")
    for s in (-1, 1):
        d.boite((s * 0.16, 0.0, 0.25), (0.03, 0.1, 0.28), "pelage_noir", ry=s * 15)
        d.boite((s * 0.06, -0.05, 0.0), (0.06, 0.1, 0.03), "bec")
        d.boite((s * 0.07, -0.07, 0.72), (0.02, 0.04, 0.03), "jaune")


def otarie(d):
    """Otarie dressée sur ses nageoires."""
    d.boule((0, 0.3, 0.2), 0.25, 0.6, 0.2, "metal_sombre", subdiv=1, alea=0.03)
    d.tube((0, -0.1, 0.25), (0, -0.3, 0.85), 0.2, "metal_sombre", n=6, r2=0.12)
    d.boule((0, -0.35, 0.92), 0.11, 0.15, 0.1, "metal_sombre", subdiv=1, alea=0.02)
    d.boite((0, -0.5, 0.9), (0.06, 0.04, 0.04), "pelage_noir")
    for s in (-1, 1):
        d.boite((s * 0.22, -0.15, 0.0), (0.2, 0.3, 0.04), "metal_sombre", rz=s * 25)
        d.boite((s * 0.12, 0.9, 0.0), (0.14, 0.25, 0.04), "metal_sombre", rz=s * 20)


def loup(d):
    """Loup gris."""
    hy, hz = quadrupede(d, "gris_ane", 1.2, 0.35, 0.85, 0.48, 0.08, cou=(-0.15, 0.12), tete=(0.2, 0.32, 0.2),
                        queue=0.45, ventre="pelage_creme")
    d.boite((0, hy - 0.2, hz - 0.08), (0.1, 0.15, 0.1), "gris_ane")
    for s in (-1, 1):
        d.boite((s * 0.06, hy + 0.08, hz + 0.1), (0.05, 0.03, 0.1), "gris_ane")


def bison(d):
    """Bison d'Europe."""
    hy, hz = quadrupede(d, "cheval_bai", 2.9, 0.95, 1.8, 0.7, 0.2, cou=(-0.2, -0.35), tete=(0.55, 0.55, 0.55),
                        queue=0.5, tete_col="bois_sombre")
    d.boule((0, -0.75, 1.55), 0.55, 0.6, 0.5, "bois_sombre", subdiv=1, alea=0.1)
    for s in (-1, 1):
        d.tube((s * 0.2, hy + 0.1, hz + 0.18), (s * 0.35, hy, hz + 0.4), 0.04, "corne", n=4, r2=0.015)
    d.boule((0, hy - 0.05, hz - 0.3), 0.18, 0.12, 0.15, "bois_sombre", subdiv=1, alea=0.1)


def kangourou(d):
    """Kangourou roux."""
    d.boule((0, 0.05, 0.75), 0.25, 0.3, 0.45, "pelage_roux", subdiv=1, alea=0.04)
    for s in (-1, 1):
        d.boite((s * 0.16, -0.05, 0.0), (0.1, 0.45, 0.08), "pelage_roux")
        d.boule((s * 0.17, 0.15, 0.3), 0.1, 0.22, 0.2, "pelage_roux", subdiv=1, alea=0.03)
        d.tube((s * 0.12, -0.2, 0.95), (s * 0.1, -0.35, 0.75), 0.03, "pelage_roux", n=4)
    d.tube((0, 0.3, 0.45), (0, 1.15, 0.05), 0.08, "pelage_roux", n=5, r2=0.03)
    d.boule((0, -0.12, 1.32), 0.11, 0.18, 0.12, "pelage_roux", subdiv=1, alea=0.03)
    for s in (-1, 1):
        d.boite((s * 0.06, -0.04, 1.42), (0.04, 0.04, 0.16), "pelage_roux")


def flamant(d):
    """Flamant rose sur une patte."""
    d.tube((0, 0.0, 0.0), (0, 0.0, 0.85), 0.015, "rose", n=4)
    d.tube((0.0, 0.0, 0.6), (0.06, 0.12, 0.72), 0.015, "rose", n=4)
    d.boule((0, 0.05, 0.95), 0.12, 0.25, 0.13, "rose", subdiv=1, alea=0.05)
    d.tube((0, -0.15, 1.0), (0, -0.22, 1.35), 0.025, "rose", n=4)
    d.tube((0, -0.22, 1.35), (0, -0.3, 1.45), 0.03, "rose", n=4)
    d.boite((0, -0.36, 1.38), (0.03, 0.08, 0.05), "pelage_noir", rx=-35)


def crocodile(d):
    """Crocodile du Nil."""
    d.boule((0, 0, 0.22), 0.4, 1.0, 0.18, "vert_fonte", subdiv=1, alea=0.03, aplatir_bas=0.6)
    d.boule((0, -1.1, 0.18), 0.22, 0.45, 0.12, "vert_fonte", subdiv=1, alea=0.03, aplatir_bas=0.6)
    d.boite((0, -1.65, 0.05), (0.2, 0.55, 0.14), "vert_fonte")
    d.tube((0, 0.9, 0.18), (0, 2.6, 0.08), 0.18, "vert_fonte", n=5, r2=0.03)
    for i in range(10):
        d.boite((0, -0.6 + i * 0.3, 0.38 - i * 0.02), (0.16, 0.08, 0.06), "mousse")
    for s in (-1, 1):
        d.boite((s * 0.45, -0.5, 0.0), (0.12, 0.25, 0.12), "vert_fonte", rz=s * 30)
        d.boite((s * 0.45, 0.55, 0.0), (0.14, 0.28, 0.12), "vert_fonte", rz=-s * 30)
        d.boite((s * 0.1, -1.12, 0.28), (0.06, 0.06, 0.05), "jaune")


def tortue_geante(d):
    """Tortue géante des Galápagos."""
    d.boule((0, 0, 0.35), 0.55, 0.7, 0.45, "bois_sombre", subdiv=1, alea=0.05, aplatir_bas=0.8)
    d.boule((0, 0, 0.2), 0.58, 0.73, 0.1, "pierre_sombre", subdiv=1, alea=0.02)
    for s in (-1, 1):
        for y in (-0.45, 0.45):
            d.boite((s * 0.45, y, 0.0), (0.18, 0.18, 0.2), "gris_ane")
    d.tube((0, -0.6, 0.35), (0, -0.95, 0.5), 0.09, "gris_ane", n=5)
    d.boule((0, -1.0, 0.52), 0.1, 0.13, 0.09, "gris_ane", subdiv=1, alea=0.02)


def koala(d):
    """Koala accroché à son tronc d'eucalyptus."""
    d.cyl((0, 0.18, 0), 0.12, 2.2, "bois_gris", n=7)
    d.boule((0, 0.0, 1.3), 0.18, 0.16, 0.24, "roche_claire", subdiv=1, alea=0.05)
    d.boule((0, -0.06, 1.6), 0.15, 0.13, 0.13, "roche_claire", subdiv=1, alea=0.03)
    for s in (-1, 1):
        d.boule((s * 0.15, -0.03, 1.7), 0.08, 0.05, 0.08, "pelage_blanc", subdiv=1, alea=0.03)
        d.tube((s * 0.14, -0.02, 1.4), (s * 0.08, 0.14, 1.55), 0.05, "roche_claire", n=4)
    d.boite((0, -0.18, 1.55), (0.07, 0.04, 0.08), "pelage_noir")


def lemurien(d):
    """Lémurien catta à queue rayée."""
    hy, hz = quadrupede(d, "roche_claire", 0.45, 0.18, 0.42, 0.2, 0.04, tete=(0.12, 0.14, 0.11),
                        tete_col="pelage_blanc", queue=0)
    d.boite((0, hy - 0.08, hz - 0.03), (0.05, 0.04, 0.04), "pelage_noir")
    for i in range(8):
        d.tube((0, 0.22, 0.38 + i * 0.09), (0, 0.24, 0.47 + i * 0.09), 0.03,
               "pelage_blanc" if i % 2 == 0 else "pelage_noir", n=5)


def tapir(d):
    """Tapir de Malaisie, noir et blanc."""
    hy, hz = quadrupede(d, "pelage_noir", 2.0, 0.6, 1.05, 0.5, 0.14, tete=(0.35, 0.5, 0.35), queue=0.1)
    d.boule((0, 0.25, 0.85), 0.33, 0.45, 0.28, "pelage_blanc", subdiv=1, alea=0.03)
    d.tube((0, hy - 0.25, hz - 0.05), (0, hy - 0.45, hz - 0.25), 0.07, "pelage_noir", n=5, r2=0.04)


# --- Objets des enclos -----------------------------------------------------------------

def tronc_escalade(d):
    """Tronc d'escalade et ses branches (fauves, ours, singes)."""
    d.tube((0, 0, 0), (0.3, 0.1, 3.2), 0.18, "bois_gris", n=6, r2=0.1)
    d.tube((0.15, 0.05, 1.6), (1.1, -0.2, 2.2), 0.09, "bois_gris", n=5, r2=0.05)
    d.tube((0.25, 0.08, 2.5), (-0.8, 0.5, 3.0), 0.08, "bois_gris", n=5, r2=0.04)
    d.rocher((0.4, 0.4, 0), 0.4, "roche", haut=0.5)


def plateforme_singes(d):
    """Plateforme en bois sur poteaux, cordes et filet (grands singes)."""
    for x, y in ((-1.2, -1.2), (1.2, -1.2), (-1.2, 1.2), (1.2, 1.2)):
        d.cyl((x, y, 0), 0.12, 3.6, "bois", n=6)
    d.boite((0, 0, 2.6), (2.8, 2.8, 0.15), "bois_clair")
    for s in (-1, 1):
        d.tube((s * 1.2, -1.2, 3.5), (s * 3.0, -2.2, 0.0), 0.03, "paille", n=4)
        d.tube((-1.2, s * 1.2, 3.5), (1.2, s * 1.2, 3.5), 0.03, "paille", n=4)
    for i in range(6):
        d.tube((-1.2 + i * 0.48, 1.2, 2.6), (-1.2 + i * 0.48, 2.6, 0.0), 0.02, "paille", n=4)


def mangeoire_haute(d):
    """Mangeoire perchée pour girafes, pleine de feuillage."""
    d.cyl((0, 0, 0), 0.12, 3.6, "bois_sombre", n=6)
    d.cyl((0, 0, 3.6), 0.55, 0.5, "bois", n=8, r2=0.7)
    d.boule((0, 0, 4.15), 0.6, 0.6, 0.3, "feuillage", subdiv=1, alea=0.2)


def ratelier_foin(d):
    """Râtelier à foin (herbivores)."""
    for s in (-1, 1):
        d.boite((s * 0.9, 0, 0), (0.12, 0.8, 1.3), "bois")
    d.boite((0, 0, 0.6), (1.7, 0.7, 0.6), "foin")
    for i in range(8):
        d.tube((-0.8 + i * 0.23, -0.35, 0.6), (-0.8 + i * 0.23, -0.4, 1.3), 0.015, "metal_sombre", n=4)
    d.boite((0, 0, 1.3), (2.0, 1.0, 0.08), "tuile")


def balle_enrichissement(d):
    """Grosse balle d'enrichissement (à pousser, à mâcher)."""
    d.boule((0, 0, 0.45), 0.45, 0.45, 0.45, "rouge", subdiv=2, alea=0.0)


def rocher_chauffant(d):
    """Rocher plat chauffant (reptiles, fauves)."""
    d.rocher((0, 0, 0), 0.9, "roche_claire", haut=0.35, alea=0.15)


def piscine_ours(d):
    """Bassin rocheux pour ours ou otaries."""
    d.anneau((0, 0, 0), 2.4, 3.0, 0.4, "roche", n=12, interieur="roche_sombre")
    d.disque((0, 0, 0.3), 2.45, "eau", n=12)
    d.rocher((2.6, 1.2, 0), 0.7, "roche", haut=0.8)
    d.rocher((-2.2, -1.8, 0), 0.5, "roche_sombre", haut=0.7)


def abri_paille(d):
    """Petit abri à toit de paille (suricates, lémuriens, kangourous)."""
    for x, y in ((-1.2, -1.0), (1.2, -1.0), (-1.2, 1.0), (1.2, 1.0)):
        d.cyl((x, y, 0), 0.08, 1.6, "bois", n=5)
    d.profil([(-1.6, 1.5), (1.6, 1.5), (0, 2.4)], -1.4, 1.4, "paille")
    d.boite((0, 1.0, 0), (2.4, 0.08, 1.5), "bois_sombre")


def panneau_espece(d):
    """Panneau pédagogique d'enclos (nom, carte, régime)."""
    for s in (-1, 1):
        d.cyl((s * 0.5, 0, 0), 0.04, 1.2, "bois_sombre", n=5)
    d.boite((0, 0, 0.9), (1.2, 0.06, 0.7), "bois_clair", rx=-15)
    d.boite((0, -0.06, 1.0), (1.0, 0.02, 0.45), "tissu_blanc", rx=-15)
    d.boite((-0.25, -0.08, 1.05), (0.4, 0.02, 0.3), "vert", rx=-15)


def longue_vue(d):
    """Longue-vue de belvédère."""
    d.cyl((0, 0, 0), 0.08, 1.1, "metal_sombre", n=6)
    d.tube((0, 0.2, 1.25), (0, -0.4, 1.35), 0.07, "galva", n=6)
    d.boite((0, 0, 1.0), (0.2, 0.3, 0.3), "vert_fonte")
