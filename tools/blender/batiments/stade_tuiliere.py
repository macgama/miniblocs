"""Stade de la Tuilière, Lausanne (:mlzd et Sollberger Bögli, 2020), en low-poly.

Sources (consultées le 12 novembre 2026) :
- Wikipédia « Stade de la Tuilière » : 12 544 places, terrain de 105 × 68 m ;
- SIA Vaud, visite de chantier 2019 : tribune principale de quatre niveaux,
  trois tribunes latérales ouvertes, entrées aux quatre coins marquées par des
  voiles de béton de 12 m inclinés à 38°, toit en porte-à-faux d'environ 17,7 m
  sur les tribunes (poutres de 1,7 à 1,0 m de haut) ;
- Ville de Lausanne et Sika : environ 4 400 m² de panneaux solaires sur le toit ;
- photos libres de Wikimedia Commons : façade principale en verre à facettes
  bleutées, rez-de-chaussée vitré en retrait, bandeau de toit sombre.

Repères : X le long du terrain, Y en largeur, tribune principale côté -Y
(façade principale vers +Z dans Godot). Origine au centre du terrain, au sol.

Usage :
    blender --background --factory-startup --python tools/blender/batiments/stade_tuiliere.py -- \
        --out assets/modeles/batiments/stade_tuiliere.glb [--apercu apercu.png --azimuts -25,150]
"""

import math
import os
import sys

import bpy

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import batiment_lowpoly as lp  # noqa: E402

# Terrain et bords de pelouse.
TX, TY = 52.5, 34.0          # demi-terrain réglementaire 105 × 68
HX, HY = 56.5, 38.0          # bord de la pelouse (4 m de dégagement)

BETON = "#d6d2c9"
BETON_SOMBRE = "#6e6d69"
SOUBASSEMENT = "#3c4046"
SIEGES = "#2459a8"
SIEGES_OMBRE = "#1d4a8c"
BANDEAU = "#2b2d31"
SOUS_TOIT = "#cfcbc3"
VERRE_A = "#6f93b8"
VERRE_B = "#557aa0"
HERBE_A = "#5aa040"
HERBE_B = "#4d9236"
HERBE_BORD = "#4a8a35"
LIGNE = "#f4f4f0"

TOIT_BAS, TOIT_HAUT = 18.3, 20.0


# --- Repère d'une tribune -------------------------------------------------------
# Chaque tribune a un axe s (le long du côté), une distance d vers l'extérieur
# depuis le bord de pelouse, et la hauteur z.
COTES = {
    "S": (lambda s, d, z: (s, -(HY + d), z), (0, -1, 0), (1, 0, 0)),
    "N": (lambda s, d, z: (s, HY + d, z), (0, 1, 0), (1, 0, 0)),
    "O": (lambda s, d, z: (-(HX + d), s, z), (-1, 0, 0), (0, 1, 0)),
    "E": (lambda s, d, z: (HX + d, s, z), (1, 0, 0), (0, 1, 0)),
}


def tribune(b, cote, s0, s1, section, couleurs):
    """Extrude une section [(d, z), …] (contour fermé) le long de s0..s1.
    couleurs[k] colore l'arête section[k] -> section[k+1] (None = pas de face ;
    ("carreaux", su, sv) = vitrage)."""
    w, dehors, t = COTES[cote]
    n = len(section)
    cd = sum(p[0] for p in section) / n
    cz = sum(p[1] for p in section) / n
    for k in range(n):
        (da, za), (db, zb) = section[k], section[(k + 1) % n]
        c = couleurs[k]
        if c is None:
            continue
        # Normale 2D de l'arête, vers l'extérieur de la section.
        nd, nz = (zb - za), -(db - da)
        if nd * ((da + db) / 2 - cd) + nz * ((za + zb) / 2 - cz) < 0:
            nd, nz = -nd, -nz
        vers = (dehors[0] * nd, dehors[1] * nd, nz)
        pts = [w(s0, da, za), w(s1, da, za), w(s1, db, zb), w(s0, db, zb)]
        if isinstance(c, tuple):
            b.face_orientee(pts, None, vers, mat=lp.MAT_CARREAUX, echelle=(c[1], c[2]))
        else:
            b.face_orientee(pts, c, vers)
    for s, signe in ((s0, -1), (s1, 1)):
        b.face_orientee([w(s, d, z) for d, z in section], BETON_SOMBRE,
                        tuple(signe * v for v in t))


def facade_facettes(b, s0, s1, d, z0, z1, pas=3.75, saillie=0.8):
    """Façade principale : panneaux de verre inclinés en dents de scie."""
    w, dehors, _ = COTES["S"]
    nb = int(round((s1 - s0) / pas))
    for i in range(nb):
        a, c = s0 + i * pas, s0 + (i + 1) * pas
        pts = [w(a, d, z0), w(c, d + saillie, z0), w(c, d + saillie, z1), w(a, d, z1)]
        b.face_orientee(pts, VERRE_A if i % 2 == 0 else VERRE_B, dehors)


def poteau(b, x, y, z0, z1, cote=0.8):
    b.boite((x, y, (z0 + z1) / 2), (cote, cote, z1 - z0), BETON)


def toit(b):
    """Anneau de toit : contour extérieur à angles biseautés, trou au-dessus
    du terrain ; dessus en panneaux solaires, bandeau sombre tout autour."""
    xe, ys, yn, bis = 78.0, -69.0, 59.5, 2.5
    ext = [(-xe + bis, ys), (xe - bis, ys), (xe, ys + bis), (xe, yn - bis),
           (xe - bis, yn), (-xe + bis, yn), (-xe, yn - bis), (-xe, ys + bis)]
    xi, yis, yin = 60.0, -43.0, 42.0
    inte = [(-xi, yis), (xi, yis), (xi, yin), (-xi, yin)]
    # Côtés (quadrilatères) et biseaux (triangles) de l'anneau.
    morceaux = []
    for k in range(4):
        e0, e1 = ext[2 * k], ext[2 * k + 1]
        i0, i1 = inte[k], inte[(k + 1) % 4]
        morceaux.append([e0, e1, i1, i0])
        morceaux.append([e1, ext[(2 * k + 2) % 8], i1])
    for m in morceaux:
        b.face_orientee([(x, y, TOIT_HAUT) for x, y in m], None, (0, 0, 1),
                        mat=lp.MAT_SOLAIRE, echelle=(4.0, 2.0))
        b.face_orientee([(x, y, TOIT_BAS) for x, y in m], SOUS_TOIT, (0, 0, -1))
    # Bandeaux : extérieur (vers le dehors) et intérieur (vers le terrain).
    for contour, vers_dehors in ((ext, True), (inte, False)):
        for k in range(len(contour)):
            (xa, ya), (xb, yb) = contour[k], contour[(k + 1) % len(contour)]
            mx, my = (xa + xb) / 2, (ya + yb) / 2
            sens = 1 if vers_dehors else -1
            b.face_orientee([(xa, ya, TOIT_BAS), (xb, yb, TOIT_BAS),
                             (xb, yb, TOIT_HAUT), (xa, ya, TOIT_HAUT)],
                            BANDEAU, (sens * mx, sens * (my + 5), 0))


def voile_angle(b, sx, y_facade, y_dehors, epaisseur=0.6):
    """Voile triangulaire en béton à un angle (entrée des spectateurs) : base
    au sol, sommet sous l'angle du toit, diagonale vers le début de la façade."""
    x_debut, x_coin = sx * (HX + 1.5), sx * 75.0
    sortie = 1 if y_dehors > y_facade else -1      # sens du dehors en Y
    pente = y_dehors - y_facade                    # le haut penche vers l'extérieur
    y_ext, y_int = y_facade, y_facade - sortie * epaisseur
    for yy, sens in ((y_ext, sortie), (y_int, -sortie)):
        tri = [(x_debut, yy, 0), (x_coin, yy, 0), (x_coin, yy + pente, TOIT_BAS)]
        b.face_orientee(tri, BETON_SOMBRE, (0, sens, 0))
    # Tranche diagonale (le seul côté bien visible de l'épaisseur).
    b.face_orientee([(x_debut, y_ext, 0), (x_debut, y_int, 0),
                     (x_coin, y_int + pente, TOIT_BAS), (x_coin, y_ext + pente, TOIT_BAS)],
                    BETON, (-sx, 0, 0.6))


def ligne(b, x0, y0, x1, y1, l=0.15, z=0.05):
    dx, dy = x1 - x0, y1 - y0
    n = math.hypot(dx, dy) or 1.0
    px, py = -dy / n * l / 2, dx / n * l / 2
    b.face_orientee([(x0 + px, y0 + py, z), (x1 + px, y1 + py, z),
                     (x1 - px, y1 - py, z), (x0 - px, y0 - py, z)], LIGNE, (0, 0, 1))


def terrain(b):
    b.face_orientee([(-HX - 4, -HY - 5, 0.02), (HX + 4, -HY - 5, 0.02),
                     (HX + 4, HY + 4, 0.02), (-HX - 4, HY + 4, 0.02)], HERBE_BORD, (0, 0, 1))
    bandes = 10
    for i in range(bandes):
        x0 = -TX + 2 * TX * i / bandes
        x1 = -TX + 2 * TX * (i + 1) / bandes
        b.face_orientee([(x0, -TY, 0.03), (x1, -TY, 0.03), (x1, TY, 0.03), (x0, TY, 0.03)],
                        HERBE_A if i % 2 == 0 else HERBE_B, (0, 0, 1))
    # Lignes : contour, médiane, rond central, surfaces de réparation et de but.
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
        # But : deux poteaux et la barre transversale.
        for y in (-3.72, 3.72):
            b.boite((sx * (TX + 0.06), y, 1.22), (0.12, 0.12, 2.44), LIGNE)
        b.boite((sx * (TX + 0.06), 0, 2.38), (0.12, 7.56, 0.12), LIGNE)


def construit(b):
    terrain(b)
    vip = ("carreaux", 3.0, 1.45)
    # Tribune principale (-Y) : gradins, loges vitrées, façade, rez vitré en retrait.
    principale = [(5, 0), (5, 1.5), (24, 14), (24, TOIT_BAS), (30, TOIT_BAS),
                  (30, 4.5), (28, 4.5), (28, 0)]
    tribune(b, "S", -HX, HX, principale,
            [BETON, SIEGES, vip, None, BETON_SOMBRE, SOUBASSEMENT,
             ("carreaux", 3.0, 2.25), None])
    facade_facettes(b, -HX, HX, 30.05, 4.5, TOIT_BAS)
    # Trois tribunes latérales ouvertes, plus basses.
    laterale = [(4, 0), (4, 1.2), (18, 10), (20, 10), (20, 3), (19, 3), (19, 0)]
    coul = [BETON, SIEGES_OMBRE, BETON, BETON, SOUBASSEMENT, SOUBASSEMENT, None]
    tribune(b, "N", -HX, HX, laterale, coul)
    tribune(b, "O", -HY, HY, laterale, coul)
    tribune(b, "E", -HY, HY, laterale, coul)
    # Poteaux du toit derrière les tribunes ouvertes.
    for s in (-45, -15, 15, 45):
        poteau(b, s, HY + 19.5, 10, TOIT_BAS)
    for s in (-25, 0, 25):
        poteau(b, -(HX + 19.5), s, 10, TOIT_BAS)
        poteau(b, HX + 19.5, s, 10, TOIT_BAS)
    toit(b)
    # Voiles de béton aux quatre coins.
    for sx in (-1, 1):
        voile_angle(b, sx, -(HY + 30), -(HY + 31))
        voile_angle(b, sx, HY + 20, HY + 21.5)


def main():
    opts = lp.lire_options()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    b = lp.Batisseur(lp.Palette())
    construit(b)
    lp.exporte(b, "stade_tuiliere", opts)


main()
