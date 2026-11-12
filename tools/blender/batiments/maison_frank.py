"""Villa moderniste d'après une image d'une maison de Josef Frank (années 1930).

Volumes repérés sur l'image (dimensions estimées, porte = 2,2 m de haut) :
- rez-de-chaussée de 3 m : bloc gauche, porte en retrait sous un porte-à-faux,
  bow-window demi-cylindrique à petits carreaux, bloc droit aveugle ;
- terrasse du 1er étage bordée d'un garde-corps en grille qui suit la courbe
  du bow-window, treillage à droite ;
- 1er étage en retrait : tour cylindrique pleine devant, tour cylindrique
  vitrée derrière à gauche, corps droit avec hublot, auvent au-dessus de la porte ;
- toit-terrasse avec garde-corps à barreaux fins, arrondi à droite.

Usage :
    blender --background --factory-startup --python tools/blender/batiments/maison_frank.py -- \
        --out assets/modeles/batiments/maison_frank.glb [--apercu apercu.png --azimuts -10,35]
"""

import math
import os
import sys

import bpy

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import batiment_lowpoly as lp  # noqa: E402

BLANC = "#eeebe4"
BLANC_OMBRE = "#e2ded5"   # dessous et tranches des dalles
SOL_TERRASSE = "#cfc8bb"
PORTE = "#45413b"

RDC = 3.0          # hauteur du rez-de-chaussée
DALLE = 0.2        # épaisseur des dalles (corniche)
Z1 = RDC + DALLE   # sol du 1er étage
ETAGE = 2.8
Z2 = Z1 + ETAGE    # toit du corps du 1er étage


def dalle(b, x0, x1, y0, y1, z):
    b.boite(((x0 + x1) / 2, (y0 + y1) / 2, z + DALLE / 2), (x1 - x0, y1 - y0, DALLE),
            BLANC_OMBRE, dessous=True, couleur_dessus=SOL_TERRASSE)


def hublot(b, cx, y, cz, r):
    n = 12
    anneau = [(cx + (r + 0.07) * math.cos(2 * math.pi * i / n), y - 0.02,
               cz + (r + 0.07) * math.sin(2 * math.pi * i / n)) for i in range(n)]
    b.face(anneau, "cadre")
    vitre = [(cx + r * math.cos(2 * math.pi * i / n), y - 0.03,
              cz + r * math.sin(2 * math.pi * i / n)) for i in range(n)]
    b.face(vitre, "vitre")


def construit(b):
    # --- Rez-de-chaussée ----------------------------------------------------
    bow_c, bow_r = (0.2, -2.3), 1.2
    b.boite((-4.2, 0.25, RDC / 2), (2.6, 7.5, RDC), BLANC)          # bloc gauche
    b.boite((-0.7, 0.85, RDC / 2), (4.4, 6.3, RDC), BLANC)          # milieu (porte en retrait)
    b.boite((3.5, 0.4, RDC / 2), (4.0, 7.2, RDC), BLANC)            # bloc droit
    b.cylindre(bow_c[0], bow_c[1], 0, RDC, bow_r, BLANC, n=24, a0=180, a1=360)

    # Dalle du 1er étage (porte-à-faux au-dessus de la porte) et terrasse.
    dalle(b, -5.6, 0.2, -3.6, 4.1, RDC)
    dalle(b, 0.2, 1.5, -2.3, 4.1, RDC)
    dalle(b, 1.5, 5.6, -3.3, 4.1, RDC)
    b.cylindre(bow_c[0], bow_c[1], RDC, Z1, bow_r + 0.1, BLANC_OMBRE, n=24, a0=270, a1=360,
               couleur_dessus=SOL_TERRASSE)

    # Ouvertures du rez-de-chaussée.
    b.plaque((-2.3, -2.33, 1.1), (0, -1), 0.9, 2.2, PORTE)
    b.vitrage((-3.45, -3.5, 1.5), (0, -1), 0.35, 1.8, 1, 4)
    b.bande_arc(bow_c[0], bow_c[1], bow_r + 0.03, 0.35, 2.6, 225, 315, 24,
                lp.MAT_CARREAUX, 0.47, 2.25 / 4)
    for y in (-2.4, 0.2):
        b.vitrage((-5.5, y, 1.5), (-1, 0), 0.35, 1.8, 1, 4)
    for x in (-4.0, -1.5, 1.0, 3.6):
        b.vitrage((x, 4.0, 1.6), (0, 1), 1.4, 1.4, 3, 3)
    b.vitrage((5.5, 1.5, 1.6), (1, 0), 1.4, 1.4, 3, 3)

    # Garde-corps en grille de la terrasse (suit la courbe du bow-window).
    trace = [(-5.55, -0.8), (-5.55, -3.55), (0.2, -3.55)]
    trace += lp.arc(bow_c[0], bow_c[1], bow_r + 0.05, 270, 360, 24)[1:]
    trace += [(1.5, -3.25), (5.55, -3.25), (5.55, -0.8)]
    b.bande_ligne(trace, Z1, Z1 + 0.95, lp.MAT_GRILLE, 0.19, 0.19)
    # Treillage à droite.
    b.bande_ligne([(4.2, -2.0), (5.5, -2.0)], Z1, Z1 + 2.3, lp.MAT_GRILLE, 0.19, 0.19)
    b.bande_ligne([(4.2, -2.0), (4.2, -0.9)], Z1, Z1 + 2.3, lp.MAT_GRILLE, 0.19, 0.19)

    # --- 1er étage ------------------------------------------------------------
    b.boite((1.9, 1.3, Z1 + ETAGE / 2), (5.8, 4.4, ETAGE), BLANC)    # corps (x -1..4.8)
    hublot(b, 3.0, -0.9, Z1 + 1.55, 0.28)
    b.plaque((0.55, -0.93, Z1 + 1.05), (0, -1), 0.8, 2.1, PORTE)
    for x in (0.5, 3.2):
        b.vitrage((x, 3.5, Z1 + 1.5), (0, 1), 1.4, 1.3, 3, 3)
    b.vitrage((4.8, 1.8, Z1 + 1.5), (1, 0), 1.2, 1.3, 3, 3)
    # Auvent au-dessus de la porte, arrondi devant.
    b.boite((0.35, -1.45, Z2 + DALLE / 2), (3.1, 1.1, DALLE), BLANC_OMBRE, dessous=True)
    # Toit-terrasse du corps et garde-corps à barreaux fins, arrondi à droite.
    dalle(b, -1.1, 4.9, -1.0, 3.6, Z2)
    fin = [(0.4, -0.95), (3.85, -0.95)]
    fin += lp.arc(3.85, 0.05, 1.0, 270, 360, 24)[1:]
    fin += [(4.85, 3.55), (0.4, 3.55)]
    b.bande_ligne(fin, Z2 + DALLE, Z2 + DALLE + 1.0, lp.MAT_GRILLE, 0.12, 1.0)

    # Tour pleine devant, plus haute que le reste.
    t1 = (-1.05, -0.9, 1.45)
    b.cylindre(t1[0], t1[1], Z1, 8.0, t1[2], BLANC, n=24)
    b.cylindre(t1[0], t1[1], 8.0, 8.12, t1[2] + 0.06, BLANC_OMBRE, n=24)
    # Tour vitrée derrière à gauche : 2e niveau en vitrage continu.
    t2 = (-2.7, 0.3, 1.7)
    b.cylindre(t2[0], t2[1], Z1, 7.7, t2[2], BLANC, n=24)
    b.cylindre(t2[0], t2[1], 7.7, 7.85, t2[2] + 0.1, BLANC_OMBRE, n=24)
    b.bande_arc(t2[0], t2[1], t2[2] + 0.03, Z2 + 0.15, 7.55, 95, 265, 24,
                lp.MAT_CARREAUX, 0.55, 1.4 / 3)


def main():
    opts = lp.lire_options()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    b = lp.Batisseur(lp.Palette())
    construit(b)
    lp.exporte(b, "maison_frank", opts)


main()
