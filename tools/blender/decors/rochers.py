"""Rochers, blocs, pierres dressées : de quoi casser l'uniformité des pentes."""

import math


def rocher_plat(d):
    """Dalle rocheuse affleurante (4 m)."""
    d.rocher((0, 0, 0), 2.0, "roche_claire", haut=0.25, alea=0.22)
    d.rocher((1.4, 0.6, 0), 0.6, "roche", haut=0.5)


def rocher_moussu(d):
    """Rocher couvert de mousse sur le dessus (2,5 m)."""
    d.rocher((0, 0, 0), 1.25, "roche", haut=0.75, dessus="mousse")


def bloc_granit(d):
    """Gros bloc de granit erratique (4 m)."""
    d.rocher((0, 0, 0), 2.1, "roche_claire", haut=0.85, alea=0.2, subdiv=1)
    d.rocher((-1.6, 1.1, 0), 0.7, "roche_claire", haut=0.6)


def eboulis(d):
    """Éboulis : pierres de toutes tailles (5 m)."""
    for i in range(14):
        a = i * 2.39996
        r = math.sqrt(i / 14) * 2.3
        t = 0.65 - i * 0.035
        d.rocher((math.cos(a) * r, math.sin(a) * r, 0), max(t, 0.15),
                 ("roche", "roche_sombre", "roche_claire")[i % 3], haut=0.6, subdiv=0)


def rochers_cote(d):
    """Rochers de bord de mer, noircis en bas."""
    d.rocher((0, 0, 0), 1.6, "roche_sombre", haut=0.8, dessus="roche")
    d.rocher((1.6, -0.8, 0), 0.9, "roche_sombre", haut=0.6, dessus="roche")
    d.rocher((-1.3, 0.9, 0), 0.7, "roche_sombre", haut=0.5)


def rocher_rouge(d):
    """Rocher de grès rouge (déserts, canyons)."""
    d.rocher((0, 0, 0), 1.8, "brique", haut=1.0, alea=0.18, dessus="sable")
    d.rocher((1.5, 0.5, 0), 0.6, "brique", haut=0.6)


def falaise_bloc(d):
    """Pan de roche dressé (5 m de haut) pour les flancs de montagne."""
    d.boite((0, 0, -0.3), (3.4, 2.2, 3.0), "roche", rz=8)
    d.boite((0.5, 0.3, 2.6), (2.4, 1.6, 2.4), "roche_sombre", rz=-6)
    d.rocher((-1.4, -1.2, 0), 0.9, "roche_claire", haut=0.6)
    d.rocher((0.9, 1.3, 4.8), 0.8, "roche", haut=0.5, dessus="mousse")


def menhir(d):
    """Menhir (pierre dressée de 4 m)."""
    d.cyl((0, 0, -0.3), 0.6, 4.2, "roche_claire", n=6, r2=0.32, rz=12)
    d.rocher((0, 0, 3.8), 0.35, "roche_claire", haut=0.8, alea=0.15, subdiv=0)
    d.rocher((0.7, 0.4, 0), 0.25, "roche", haut=0.5, subdiv=0)


def dolmen(d):
    """Dolmen : table de pierre sur trois montants."""
    for (x, y, r) in ((-1.1, -0.5, 4), (1.1, -0.4, -6), (0.0, 0.8, 85)):
        d.boite((x, y, -0.2), (0.45, 1.2, 2.0), "roche", rz=r)
    d.boite((0, 0, 1.75), (3.4, 2.4, 0.45), "roche_claire", rz=5, rx=3)


def cairn(d):
    """Cairn de randonneurs."""
    z = 0.0
    for i, r in enumerate((0.45, 0.38, 0.3, 0.24, 0.17, 0.12)):
        d.rocher((0.03 * (i % 2), 0, z), r, ("roche", "roche_claire", "roche_sombre")[i % 3], haut=0.5, subdiv=0)
        z += r * 0.7


def galets(d):
    """Galets ronds de rivière (2 m)."""
    for i in range(9):
        a = i * 2.39996
        r = math.sqrt(i / 9) * 0.9
        d.boule((math.cos(a) * r, math.sin(a) * r, 0.05), 0.2 - i * 0.01, 0.16, 0.08,
                ("roche_claire", "pierre", "roche")[i % 3], subdiv=1, alea=0.05)


def souche(d):
    """Souche d'arbre coupé et ses racines."""
    d.cyl((0, 0, 0), 0.45, 0.5, "bois", n=8, r2=0.4, dessus="bois_clair")
    for i in range(5):
        a = i * math.tau / 5 + 0.3
        d.tube((0, 0, 0.25), (math.cos(a) * 0.9, math.sin(a) * 0.9, -0.05), 0.12, "bois", n=4, r2=0.04)


def tronc_mort(d):
    """Tronc couché, gagné par la mousse (6 m)."""
    d.tube((-3.0, 0, 0.35), (3.0, 0.2, 0.3), 0.38, "bois_gris", n=7, r2=0.3)
    d.tube((-3.01, 0, 0.35), (-3.0, 0, 0.35), 0.32, "bois_clair", n=7)
    d.boule((0.5, 0.05, 0.62), 0.9, 0.3, 0.12, "mousse", subdiv=1, alea=0.2)
    d.tube((1.0, 0.1, 0.5), (1.6, -0.8, 1.2), 0.08, "bois_gris", n=4, r2=0.03)
