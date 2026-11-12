"""Briques communes aux stades : terrain de football tracé, lignes, buts."""

import math

import batiment_lowpoly as lp

TX, TY = 52.5, 34.0          # demi-terrain réglementaire 105 × 68 m
HERBE_A = "#5aa040"
HERBE_B = "#4d9236"
HERBE_BORD = "#4a8a35"
SYNTH_A = "#4f9a3c"          # gazon synthétique, un peu plus uniforme
SYNTH_B = "#47903a"
LIGNE = "#f4f4f0"


def ligne(b, x0, y0, x1, y1, l=0.15, z=0.05):
    dx, dy = x1 - x0, y1 - y0
    n = math.hypot(dx, dy) or 1.0
    px, py = -dy / n * l / 2, dx / n * l / 2
    b.face_orientee([(x0 + px, y0 + py, z), (x1 + px, y1 + py, z),
                     (x1 - px, y1 - py, z), (x0 - px, y0 - py, z)], LIGNE, (0, 0, 1))


def terrain(b, sol=None, couleur_sol=HERBE_BORD, synthetique=False, bandes=10):
    """Pelouse rayée, lignes et buts. `sol` : contour [(x, y), …] du sol
    autour du terrain (bord de pelouse, ou piste d'athlétisme)."""
    if sol:
        b.face_orientee([(x, y, 0.02) for x, y in sol], couleur_sol, (0, 0, 1))
    ca, cb = (SYNTH_A, SYNTH_B) if synthetique else (HERBE_A, HERBE_B)
    for i in range(bandes):
        x0 = -TX + 2 * TX * i / bandes
        x1 = -TX + 2 * TX * (i + 1) / bandes
        b.face_orientee([(x0, -TY, 0.03), (x1, -TY, 0.03), (x1, TY, 0.03), (x0, TY, 0.03)],
                        ca if i % 2 == 0 else cb, (0, 0, 1))
    coins = [(-TX, -TY), (TX, -TY), (TX, TY), (-TX, TY)]
    for k in range(4):
        ligne(b, *coins[k], *coins[(k + 1) % 4])
    ligne(b, 0, -TY, 0, TY)
    rond = lp.arc(0, 0, 9.15, 0, 360, 20)
    for (xa, ya), (xb, yb) in zip(rond, rond[1:]):
        ligne(b, xa, ya, xb, yb)
    for sx in (-1, 1):
        for prof, demi in ((16.5, 20.15), (5.5, 9.16)):
            x_in = sx * (TX - prof)
            ligne(b, sx * TX, -demi, x_in, -demi)
            ligne(b, x_in, -demi, x_in, demi)
            ligne(b, x_in, demi, sx * TX, demi)
        for y in (-3.72, 3.72):
            b.boite((sx * (TX + 0.06), y, 1.22), (0.12, 0.12, 2.44), LIGNE)
        b.boite((sx * (TX + 0.06), 0, 2.38), (0.12, 7.56, 0.12), LIGNE)
