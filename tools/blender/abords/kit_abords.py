"""Kit d'abords low-poly : piscines, parkings, garages, carport, allée, terrasse.

Chaque pièce est un .glb séparé (assets/modeles/abords/) à poser autour des
bâtiments. Mêmes règles que les bâtiments : 1 unité = 1 m, origine au sol au
centre, avant vers -Y dans Blender (+Z dans Godot), palette de couleurs
recolorable dans le jeu (CouleursModele). Rien ne descend sous le sol : l'eau
des piscines est posée un peu au-dessus, entre des margelles.

Le kit ne contient ni plantes, haies ou arbres, ni clôtures, boîtes aux lettres
ou pots de fleurs (faits par d'autres parties du projet).

Usage (toutes les pièces) :
    blender --background --factory-startup --python tools/blender/abords/kit_abords.py -- \
        --dossier assets/modeles/abords [--piece piscine_rect] [--apercus dossier_png]
"""

import math
import os
import sys

import bpy

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import batiment_lowpoly as lp  # noqa: E402

COULEURS = {
    "eau": "#3fa7d6",
    "eau_bord": "#7cc8e6",       # bande claire le long des parois
    "margelle": "#e4ddd0",
    "dalle": "#cfc8b9",
    "asphalte": "#4a4d52",
    "bordure": "#b7b3aa",
    "marquage": "#f2f2ee",
    "mur_garage": "#e8e2d6",
    "porte_garage": "#dcd8cf",
    "porte_garage_rainure": "#b9b5ac",
    "toit_plat": "#6b6e73",
    "bois_terrasse": "#a0704a",
    "bois_terrasse_b": "#8f6340",
    "poteau": "#5a3e2b",
    "lampadaire": "#3a3d42",
    "lampe": "#fff3c4",
    "transat": "#f4f1ea",
    "coussin": "#2f6f8f",
    "gravier": "#bdb6a6",
}


def nouveau():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    pal = lp.Palette()
    for nom, hexa in COULEURS.items():
        pal.ajoute(nom, hexa)
    return lp.Batisseur(pal)


def plat(b, pts, z, couleur):
    """Polygone horizontal (face vers le haut)."""
    b.face_orientee([(x, y, z) for x, y in pts], couleur, (0, 0, 1))


def bord_vertical(b, pts, z0, z1, couleur, dehors=True):
    """Bande verticale le long d'un contour fermé ; normales vers l'extérieur
    (dehors=True) ou vers l'intérieur du contour."""
    cx = sum(p[0] for p in pts) / len(pts)
    cy = sum(p[1] for p in pts) / len(pts)
    s = 1 if dehors else -1
    for i in range(len(pts)):
        (xa, ya), (xb, yb) = pts[i], pts[(i + 1) % len(pts)]
        mx, my = (xa + xb) / 2, (ya + yb) / 2
        b.face_orientee([(xa, ya, z0), (xb, yb, z0), (xb, yb, z1), (xa, ya, z1)], couleur,
                        (s * (mx - cx), s * (my - cy), 0))


def anneau_plat(b, ext, inte, z, couleur):
    """Couronne horizontale entre deux contours de même nombre de points."""
    n = len(ext)
    for i in range(n):
        j = (i + 1) % n
        b.face_orientee([(*ext[i], z), (*ext[j], z), (*inte[j], z), (*inte[i], z)], couleur, (0, 0, 1))


def decale_contour(pts, d):
    """Contour décalé de d vers l'extérieur (normales moyennes aux sommets)."""
    n = len(pts)
    cx = sum(p[0] for p in pts) / n
    cy = sum(p[1] for p in pts) / n
    out = []
    for i in range(n):
        (xa, ya), (xb, yb), (xc, yc) = pts[i - 1], pts[i], pts[(i + 1) % n]
        n1 = (yb - ya, -(xb - xa))
        n2 = (yc - yb, -(xc - xb))
        nx, ny = n1[0] + n2[0], n1[1] + n2[1]
        if nx * (xb - cx) + ny * (yb - cy) < 0:
            nx, ny = -nx, -ny
        lg = math.hypot(nx, ny) or 1.0
        # Corrige l'angle pour garder une largeur constante.
        l1 = math.hypot(*n1) or 1.0
        cosa = max(0.35, (nx * n1[0] + ny * n1[1]) / (lg * l1) * (1 if nx * n1[0] + ny * n1[1] >= 0 else -1))
        k = d / cosa
        out.append((xb + nx / lg * k, yb + ny / lg * k))
    return out


# --- Piscines ----------------------------------------------------------------
H_MARGELLE, H_EAU = 0.18, 0.1


def piscine(b, eau_pts, largeur_plage=1.2, echelle=True, transats=2, dx_transats=0.0):
    margelle = decale_contour(eau_pts, 0.35)
    plage = decale_contour(eau_pts, 0.35 + largeur_plage)
    plat(b, eau_pts, H_EAU, "eau")
    bord_vertical(b, eau_pts, H_EAU, H_MARGELLE - 0.02, "eau_bord", dehors=False)
    anneau_plat(b, margelle, eau_pts, H_MARGELLE, "margelle")
    bord_vertical(b, margelle, H_MARGELLE - 0.06, H_MARGELLE, "margelle")
    anneau_plat(b, plage, margelle, H_MARGELLE - 0.06, "dalle")
    bord_vertical(b, plage, 0.0, H_MARGELLE - 0.06, "bordure")
    xs = [p[0] for p in eau_pts]
    ys = [p[1] for p in eau_pts]
    if echelle:
        # Échelle : deux montants arrondis en U au-dessus de la margelle.
        x = max(xs) - 1.0
        y = max(ys)
        for dx in (-0.25, 0.25):
            b.boite((x + dx, y + 0.12, H_MARGELLE + 0.45), (0.05, 0.05, 0.9), "lampadaire")
            b.boite((x + dx, y - 0.05, H_MARGELLE + 0.88), (0.05, 0.4, 0.05), "lampadaire")
    for k in range(transats):
        x = (min(xs) + 1.0 + k * 1.1) + dx_transats
        y = min(ys) - 0.35 - largeur_plage / 2 - 0.1
        b.boite((x, y, H_MARGELLE + 0.12), (0.65, 1.9, 0.12), "transat")
        b.boite((x, y + 0.65, H_MARGELLE + 0.32), (0.6, 0.5, 0.08), "coussin")


def piece_piscine_rect(b):
    L, P = 9.0, 4.5
    eau = [(-L / 2, -P / 2), (L / 2, -P / 2), (L / 2, P / 2), (-L / 2, P / 2)]
    piscine(b, eau, largeur_plage=1.6, transats=3)


def piece_piscine_haricot(b):
    # Ellipse creusée d'un côté (forme de haricot), 24 points.
    pts = []
    for i in range(24):
        t = 2 * math.pi * i / 24
        creux = 0.42 * math.exp(-((math.atan2(math.sin(t - math.pi / 2), math.cos(t - math.pi / 2))) / 0.7) ** 2)
        r = 1.0 - creux
        pts.append((4.2 * r * math.cos(t), 2.3 * r * math.sin(t)))
    piscine(b, pts, largeur_plage=1.3, echelle=False, transats=2, dx_transats=0.6)


# --- Parkings ----------------------------------------------------------------
def parking(b, places_par_rang, rangs):
    lp_, pp, allee = 2.5, 5.0, 6.0
    L = places_par_rang * lp_ + 1.0
    P = rangs * pp + (allee if rangs > 1 else 3.0) + 1.0
    plat(b, [(-L / 2, -P / 2), (L / 2, -P / 2), (L / 2, P / 2), (-L / 2, P / 2)], 0.04, "asphalte")
    # Bordures autour.
    for (x0, y0, x1, y1) in ((-L / 2, -P / 2, L / 2, -P / 2 + 0.15), (-L / 2, P / 2 - 0.15, L / 2, P / 2),
                             (-L / 2, -P / 2, -L / 2 + 0.15, P / 2), (L / 2 - 0.15, -P / 2, L / 2, P / 2)):
        b.boite(((x0 + x1) / 2, (y0 + y1) / 2, 0.08), (x1 - x0, y1 - y0, 0.16), "bordure")
    # Lignes des places (avant de chaque rang ouvert sur l'allée).
    rangs_y = [P / 2 - 0.5 - pp / 2] + ([-P / 2 + 0.5 + pp / 2] if rangs > 1 else [])
    for yc in rangs_y:
        for i in range(places_par_rang + 1):
            x = -L / 2 + 0.5 + i * lp_
            b.face_orientee([(x - 0.06, yc - pp / 2, 0.05), (x + 0.06, yc - pp / 2, 0.05),
                             (x + 0.06, yc + pp / 2, 0.05), (x - 0.06, yc + pp / 2, 0.05)], "marquage", (0, 0, 1))
        # Butées de roue.
        for i in range(places_par_rang):
            x = -L / 2 + 0.5 + (i + 0.5) * lp_
            yb = yc + (pp / 2 - 0.5) * (1 if yc > 0 else -1)
            b.boite((x, yb, 0.1), (1.4, 0.18, 0.12), "bordure")
    # Lampadaires aux deux bouts de l'allée.
    for sx in (-1, 1):
        x = sx * (L / 2 - 0.4)
        b.boite((x, 0, 2.4), (0.14, 0.14, 4.8), "lampadaire")
        b.boite((x - sx * 0.45, 0, 4.85), (1.0, 0.25, 0.1), "lampadaire")
        b.boite((x - sx * 0.75, 0, 4.77), (0.35, 0.2, 0.06), "lampe")


def piece_parking_4(b):
    parking(b, 4, 1)


def piece_parking_12(b):
    parking(b, 6, 2)


# --- Garages -----------------------------------------------------------------
def porte_basculante(b, x, y, l, h):
    """Porte de garage à rainures horizontales, légèrement en retrait."""
    b.face_orientee([(x - l / 2, y - 0.01, 0.02), (x + l / 2, y - 0.01, 0.02),
                     (x + l / 2, y - 0.01, h), (x - l / 2, y - 0.01, h)], "porte_garage", (0, -1, 0))
    for k in range(1, 5):
        z = h * k / 5
        b.face_orientee([(x - l / 2, y - 0.02, z - 0.03), (x + l / 2, y - 0.02, z - 0.03),
                         (x + l / 2, y - 0.02, z + 0.03), (x - l / 2, y - 0.02, z + 0.03)],
                        "porte_garage_rainure", (0, -1, 0))
    # Encadrement en saillie : la porte paraît en creux.
    b.cadre_creux(x, y, (0, -1), 0, h / 2, l, h, 0.12, 0.08, "mur_garage", sans_bas=True)


def garage(b, nb_portes):
    L = 3.4 * nb_portes + 0.4
    P, H = 6.2, 2.7
    b.boite((0, 0, H / 2), (L, P, H), "mur_garage")
    b.boite((0, 0.1, H + 0.12), (L + 0.3, P + 0.5, 0.24), "toit_plat", dessous=True)
    for i in range(nb_portes):
        x = -L / 2 + 0.2 + 3.4 * (i + 0.5)
        porte_basculante(b, x, -P / 2, 2.6, 2.15)
    b.vitrage_relief((L / 2, 1.0, 1.6), (1, 0), 0.8, 0.6, 2, 1, appui=None)
    # Petite dalle devant les portes.
    plat(b, [(-L / 2, -P / 2 - 1.5), (L / 2, -P / 2 - 1.5), (L / 2, -P / 2), (-L / 2, -P / 2)], 0.03, "dalle")


def piece_garage_simple(b):
    garage(b, 1)


def piece_garage_double(b):
    garage(b, 2)


def piece_carport(b):
    L, P, H = 3.4, 5.6, 2.4
    plat(b, [(-L / 2, -P / 2), (L / 2, -P / 2), (L / 2, P / 2), (-L / 2, P / 2)], 0.03, "gravier")
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.boite((sx * (L / 2 - 0.1), sy * (P / 2 - 0.15), H / 2), (0.14, 0.14, H), "poteau")
        b.boite((sx * (L / 2 - 0.1), 0, H - 0.1), (0.12, P, 0.2), "poteau")
    # Toit légèrement incliné vers l'arrière, avec bandeau bois.
    for k, (z0, z1) in enumerate(((H + 0.1, H - 0.05),)):
        y0, y1 = -P / 2 - 0.3, P / 2 + 0.3
        pts = [(-L / 2 - 0.25, y0, z0), (L / 2 + 0.25, y0, z0), (L / 2 + 0.25, y1, z1), (-L / 2 - 0.25, y1, z1)]
        b.face_orientee(pts, "toit_plat", (0, 0.05, 1))
        b.face_orientee([(x, y, z - 0.12) for x, y, z in pts], "poteau", (0, 0, -1))
        for (xa, ya, za), (xc, yc, zc) in zip(pts, pts[1:] + pts[:1]):
            mx, my = (xa + xc) / 2, (ya + yc) / 2
            b.face_orientee([(xa, ya, za - 0.12), (xc, yc, zc - 0.12), (xc, yc, zc), (xa, ya, za)], "poteau",
                            (mx, my, 0))


# --- Allée et terrasse -------------------------------------------------------
def piece_allee(b):
    L, P = 3.0, 9.0
    plat(b, [(-L / 2, -P / 2), (L / 2, -P / 2), (L / 2, P / 2), (-L / 2, P / 2)], 0.04, "dalle")
    # Joints : bandes plus claires tous les 0,6 m (pavés à l'échelle du jeu).
    n = int(P / 0.6)
    for i in range(1, n):
        y = -P / 2 + i * 0.6
        b.face_orientee([(-L / 2, y - 0.02, 0.045), (L / 2, y - 0.02, 0.045),
                         (L / 2, y + 0.02, 0.045), (-L / 2, y + 0.02, 0.045)], "bordure", (0, 0, 1))
    for sx in (-1, 1):
        b.boite((sx * (L / 2 + 0.06), 0, 0.07), (0.12, P, 0.14), "bordure")


def piece_terrasse(b):
    L, P, H = 6.0, 4.0, 0.35
    lames = 14
    for i in range(lames):
        y0 = -P / 2 + P * i / lames
        y1 = -P / 2 + P * (i + 1) / lames - 0.015
        plat(b, [(-L / 2, y0), (L / 2, y0), (L / 2, y1), (-L / 2, y1)], H, "bois_terrasse" if i % 2 == 0 else "bois_terrasse_b")
    bord_vertical(b, [(-L / 2, -P / 2), (L / 2, -P / 2), (L / 2, P / 2), (-L / 2, P / 2)], 0.0, H, "bois_terrasse_b")
    # Marche devant.
    b.boite((0, -P / 2 - 0.2, H / 4), (1.6, 0.4, H / 2), "bois_terrasse")


PIECES = {
    "piscine_rect": piece_piscine_rect,
    "piscine_haricot": piece_piscine_haricot,
    "parking_4": piece_parking_4,
    "parking_12": piece_parking_12,
    "garage_simple": piece_garage_simple,
    "garage_double": piece_garage_double,
    "carport": piece_carport,
    "allee": piece_allee,
    "terrasse": piece_terrasse,
}


def main():
    opts = lp.lire_options()
    dossier = opts.get("dossier", "assets/modeles/abords")
    noms = [opts["piece"]] if "piece" in opts else list(PIECES)
    for nom in noms:
        b = nouveau()
        PIECES[nom](b)
        o = {"out": os.path.join(dossier, nom + ".glb")}
        if "apercus" in opts:
            o["apercu"] = os.path.join(opts["apercus"], nom + ".png")
        lp.exporte(b, nom, o)


main()
