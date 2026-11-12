"""Briques de la bible de bâtiments Blender (tools/blender/bible/).

Réutilise le générateur commun (tools/blender/batiment_lowpoly.py : palette
64 × 64, Batisseur, export .glb + carte de palette) et ajoute des pièces de
plus haut niveau : corps de bâtiment avec fenêtres sur chaque façade, toits
(deux pans, quatre pans, mansarde, monopente, plat, voûte, sheds, pyramide,
cône, dôme), tours, clochers, silos, cheminées, balcons, arcades.

Repère Blender : X = largeur de la façade, Y = profondeur, Z = hauteur.
La façade principale regarde -Y (donc +Z dans Godot). 1 unité = 1 mètre.
Toutes les couleurs sont des noms de la palette ci-dessous (ou « #rrggbb »).
"""

import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import batiment_lowpoly as lp  # noqa: E402

# Couleurs de la bible, en plus de celles du générateur commun (enduit, tuile,
# vitre…). Les vitres reprennent les teintes reconnues par le jeu comme
# fenêtres (NightWindows) : elles s'allument la nuit.
COULEURS = {
    "enduit_blanc": "#f4f2ec",
    "enduit_rose": "#e9c2b0",
    "enduit_jaune": "#ecd59a",
    "enduit_bleu": "#c9dbe3",
    "enduit_vert": "#cfdcc0",
    "ocre": "#d39b5a",
    "terre": "#b9825a",
    "brique_claire": "#c87f5d",
    "brique_sombre": "#7e3b2c",
    "pierre_claire": "#d8d0bf",
    "pierre_grise": "#9c988f",
    "granit": "#7f7d78",
    "bois_clair": "#c39a6b",
    "bois_rouge": "#8e3b2e",
    "bois_gris": "#8b8478",
    "beton_clair": "#d4d1ca",
    "beton_sombre": "#8c8a85",
    "bardage": "#a4aab0",
    "bardage_bleu": "#4f6f91",
    "bardage_rouge": "#a2423a",
    "bardage_vert": "#5d7d5a",
    "tole": "#9aa0a6",
    "tole_rouge": "#8f3a33",
    "tole_verte": "#4f6b52",
    "zinc": "#7e8890",
    "cuivre": "#5f9e8a",
    "or": "#d7b04a",
    "verre_bleu": "#4f6d8f",
    "verre_clair": "#8fb8d8",
    "verre_ciel": "#6d97b8",
    "verre_nuit": "#1d2d3c",
    "blanc": "#f7f7f5",
    "noir": "#2a2b2e",
    "rouge": "#c0392b",
    "bleu": "#2a6fdb",
    "vert": "#3f8f5a",
    "jaune": "#f2c14e",
    "orange": "#e4772e",
    "sous_toit": "#6a5040",
    "asphalte": "#55585e",
    "pelouse": "#6aa84f",
    "terre_battue": "#c46a3b",
    "sable": "#e3d3a8",
    "eau": "#3fa7d6",
    "glace": "#e6f2f7",
    "marquage": "#f2f2ee",
}


def _sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def _centre(pts):
    n = float(len(pts))
    return (sum(p[0] for p in pts) / n, sum(p[1] for p in pts) / n, sum(p[2] for p in pts) / n)


class PaletteBible(lp.Palette):
    """Palette qui ne réserve une case qu'aux couleurs vraiment utilisées
    (la bible connaît plus de 64 couleurs nommées)."""

    def __init__(self, extra=None):
        self.cases = {}
        self.couleurs = []
        self.connues = dict(lp.PALETTE_BASE)
        self.connues.update(COULEURS)
        self.connues.update(extra or {})

    def index(self, couleur):
        if couleur in self.cases:
            return self.cases[couleur]
        if couleur in self.connues:
            return self.ajoute(couleur, self.connues[couleur])
        return super().index(couleur)


class Kit:
    """Un bâtiment en cours de construction (un seul maillage, une palette)."""

    def __init__(self, couleurs_extra=None):
        bpy.ops.wm.read_factory_settings(use_empty=True)
        pal = PaletteBible(couleurs_extra)
        self.b = lp.Batisseur(pal)

    # --- Faces de base ------------------------------------------------------
    def f(self, pts, c, ref=None, vers=None):
        """Face orientée vers l'extérieur : soit selon `vers`, soit à l'opposé
        du point `ref` (centre du volume)."""
        if vers is None:
            m = _centre(pts)
            vers = _sub(m, ref)
        return self.b.face_orientee(pts, c, vers)

    def boite(self, x, y, z0, sx, sy, h, c, dessus=None, dessous=False):
        self.b.boite((x, y, z0 + h / 2.0), (sx, sy, h), c, dessous=dessous, couleur_dessus=dessus)

    def sol(self, x, y, sx, sy, c, h=0.04):
        """Dalle posée au sol (cour, parking, pelouse) : dessus seulement + bords."""
        x0, x1, y0, y1 = x - sx / 2, x + sx / 2, y - sy / 2, y + sy / 2
        self.f([(x0, y0, h), (x1, y0, h), (x1, y1, h), (x0, y1, h)], c, vers=(0, 0, 1))
        ref = (x, y, 0)
        for a, b in (((x0, y0), (x1, y0)), ((x1, y0), (x1, y1)), ((x1, y1), (x0, y1)), ((x0, y1), (x0, y0))):
            self.f([(a[0], a[1], 0), (b[0], b[1], 0), (b[0], b[1], h), (a[0], a[1], h)], c, ref)

    def prisme(self, pts, z0, z1, c, dessus=None):
        """Polygone (x, y) extrudé de z0 à z1 (murs + dessus)."""
        cx = sum(p[0] for p in pts) / len(pts)
        cy = sum(p[1] for p in pts) / len(pts)
        ref = (cx, cy, (z0 + z1) / 2)
        n = len(pts)
        for i in range(n):
            a, b = pts[i], pts[(i + 1) % n]
            self.f([(a[0], a[1], z0), (b[0], b[1], z0), (b[0], b[1], z1), (a[0], a[1], z1)], c, ref)
        self.f([(p[0], p[1], z1) for p in pts], dessus or c, vers=(0, 0, 1))

    def cyl(self, x, y, z0, h, r, c, n=12, dessus=True, c_dessus=None):
        self.b.cylindre(x, y, z0, z0 + h, r, c, n=n, dessus=dessus, couleur_dessus=c_dessus)

    def tronc_cone(self, x, y, z0, h, r0, r1, c, n=12, dessus=True):
        """Cône (r1 = 0) ou tronc de cône."""
        pts0 = lp.arc(x, y, r0, 0, 360, n)[:-1]
        ref = (x, y, z0 + h * 0.3)
        if r1 <= 0.001:
            for i in range(n):
                a, b = pts0[i], pts0[(i + 1) % n]
                self.f([(a[0], a[1], z0), (b[0], b[1], z0), (x, y, z0 + h)], c, ref)
            return
        pts1 = lp.arc(x, y, r1, 0, 360, n)[:-1]
        for i in range(n):
            a, b = pts0[i], pts0[(i + 1) % n]
            c1, d1 = pts1[(i + 1) % n], pts1[i]
            self.f([(a[0], a[1], z0), (b[0], b[1], z0), (c1[0], c1[1], z0 + h), (d1[0], d1[1], z0 + h)], c, ref)
        if dessus:
            self.f([(p[0], p[1], z0 + h) for p in pts1], c, vers=(0, 0, 1))

    def dome(self, x, y, z0, r, c, n=12, anneaux=3, h=None, lanterne=None):
        """Coupole : demi-sphère (h = r) ou coupole surbaissée / allongée."""
        h = r if h is None else h
        prof = [(r * math.cos(math.pi / 2 * i / anneaux), z0 + h * math.sin(math.pi / 2 * i / anneaux))
                for i in range(anneaux + 1)]
        ref = (x, y, z0)
        for (ra, za), (rb, zb) in zip(prof, prof[1:]):
            pa = lp.arc(x, y, ra, 0, 360, n)[:-1]
            if rb < 0.01:
                for i in range(n):
                    a, b = pa[i], pa[(i + 1) % n]
                    self.f([(a[0], a[1], za), (b[0], b[1], za), (x, y, zb)], c, ref)
            else:
                pb = lp.arc(x, y, rb, 0, 360, n)[:-1]
                for i in range(n):
                    a, b = pa[i], pa[(i + 1) % n]
                    self.f([(a[0], a[1], za), (b[0], b[1], za), (pb[(i + 1) % n][0], pb[(i + 1) % n][1], zb),
                            (pb[i][0], pb[i][1], zb)], c, ref)
        if lanterne:
            self.cyl(x, y, z0 + h - 0.1, r * 0.35, r * 0.18, lanterne, n=8)
            self.tronc_cone(x, y, z0 + h + r * 0.25, r * 0.3, r * 0.2, 0, lanterne, n=8)

    def bulbe(self, x, y, z0, r, h, c, n=10):
        """Bulbe (oignon) des églises orthodoxes."""
        prof = [(r * 0.7, 0.0), (r, 0.25), (r * 0.95, 0.5), (r * 0.55, 0.75), (r * 0.15, 0.9), (0.0, 1.0)]
        ref = (x, y, z0 + h * 0.4)
        for (ra, ta), (rb, tb) in zip(prof, prof[1:]):
            za, zb = z0 + ta * h, z0 + tb * h
            pa = lp.arc(x, y, ra, 0, 360, n)[:-1]
            if rb < 0.01:
                for i in range(n):
                    a, b = pa[i], pa[(i + 1) % n]
                    self.f([(a[0], a[1], za), (b[0], b[1], za), (x, y, zb)], c, ref)
                continue
            pb = lp.arc(x, y, rb, 0, 360, n)[:-1]
            for i in range(n):
                a, b = pa[i], pa[(i + 1) % n]
                self.f([(a[0], a[1], za), (b[0], b[1], za), (pb[(i + 1) % n][0], pb[(i + 1) % n][1], zb),
                        (pb[i][0], pb[i][1], zb)], c, ref)

    # --- Toits ----------------------------------------------------------------
    def _map(self, cx, cy, axe):
        if axe == "x":
            return lambda a, b, z: (cx + a, cy + b, z)
        return lambda a, b, z: (cx + b, cy + a, z)

    def toit_2pans(self, cx, cy, z, L, P, h, c, axe="x", debord=0.35, pignon=None, ep=0.14,
                   rangs=0, sous="sous_toit", pignons=True):
        """Toit à deux pans. axe = direction du faîtage ("x" : parallèle à la
        façade). L = longueur le long du faîtage, P = largeur, h = hauteur du
        faîtage au-dessus de z (bas des murs du pignon)."""
        m = self._map(cx, cy, axe)
        hl, hp = L / 2.0, P / 2.0
        pente = h / hp
        a0, a1 = -hl - debord, hl + debord
        bb = hp + debord
        zb = z - debord * pente
        zr = z + h
        ref = m(0, 0, z)
        for s in (-1, 1):
            if rangs > 0:
                saut = 0.07
                for i in range(rangs):
                    t0, t1 = i / rangs, (i + 1) / rangs
                    b0, z0 = s * bb * (1 - t0), zb + ep + (zr - zb) * t0
                    b1, z1 = s * bb * (1 - t1), zb + ep + (zr - zb) * t1
                    self.f([m(a0, b0, z0 + saut), m(a1, b0, z0 + saut), m(a1, b1, z1), m(a0, b1, z1)], c,
                           vers=_sub(m(0, s * pente, 1), m(0, 0, 0)))
                    self.f([m(a0, b0, z0), m(a1, b0, z0), m(a1, b0, z0 + saut), m(a0, b0, z0 + saut)],
                           "tuile_ombre", vers=_sub(m(0, s, 0), m(0, 0, 0)))
            else:
                self.f([m(a0, s * bb, zb + ep), m(a1, s * bb, zb + ep), m(a1, 0, zr + ep), m(a0, 0, zr + ep)], c,
                       vers=_sub(m(0, s * pente, 1), m(0, 0, 0)))
            # Dessous du débord et tranche.
            self.f([m(a0, s * bb, zb), m(a1, s * bb, zb), m(a1, 0, zr), m(a0, 0, zr)], sous,
                   vers=_sub(m(0, 0, -1), m(0, 0, 0)))
            self.f([m(a0, s * bb, zb), m(a1, s * bb, zb), m(a1, s * bb, zb + ep), m(a0, s * bb, zb + ep)], c,
                   vers=_sub(m(0, s, 0), m(0, 0, 0)))
        for sa in (-1, 1):
            aa = sa * (hl + debord)
            self.f([m(aa, -bb, zb), m(aa, 0, zr), m(aa, bb, zb), m(aa, bb, zb + ep), m(aa, 0, zr + ep),
                    m(aa, -bb, zb + ep)], c, vers=_sub(m(sa, 0, 0), m(0, 0, 0)))
            if pignons and pignon:
                ap = sa * hl
                self.f([m(ap, -hp, z), m(ap, hp, z), m(ap, 0, zr)], pignon, vers=_sub(m(sa, 0, 0), m(0, 0, 0)))
        return zr + ep

    def tronc(self, cx, cy, z0, L0, P0, z1, L1, P1, c, dessus=True, c_dessus=None):
        """Tronc de pyramide rectangulaire (L1 ou P1 = 0 : toit à croupes)."""
        ref = (cx, cy, z0)
        b = [(cx - L0 / 2, cy - P0 / 2, z0), (cx + L0 / 2, cy - P0 / 2, z0),
             (cx + L0 / 2, cy + P0 / 2, z0), (cx - L0 / 2, cy + P0 / 2, z0)]
        t = [(cx - L1 / 2, cy - P1 / 2, z1), (cx + L1 / 2, cy - P1 / 2, z1),
             (cx + L1 / 2, cy + P1 / 2, z1), (cx - L1 / 2, cy + P1 / 2, z1)]
        for i in range(4):
            j = (i + 1) % 4
            pts = [b[i], b[j], t[j], t[i]]
            if (t[i][0] - t[j][0]) ** 2 + (t[i][1] - t[j][1]) ** 2 < 1e-6:
                pts = [b[i], b[j], t[i]]
            self.f(pts, c, ref)
        if dessus and L1 > 0.01 and P1 > 0.01:
            self.f(t, c_dessus or c, vers=(0, 0, 1))

    def toit_4pans(self, cx, cy, z, L, P, h, c, debord=0.35, sous="sous_toit", ep=0.14):
        """Toit à quatre pans (croupes) ; L = P donne une pyramide."""
        L0, P0 = L + 2 * debord, P + 2 * debord
        k = h / (min(L, P) / 2.0)
        zb = z - debord * k
        if L >= P:
            L1, P1 = L - P, 0.0
        else:
            L1, P1 = 0.0, P - L
        self.boite(cx, cy, zb, L0, P0, ep, c, dessus=None)
        self.tronc(cx, cy, zb + ep, L0, P0, z + h + ep, L1, P1, c)
        self.f([(cx - L0 / 2, cy + P0 / 2, zb - 0.001), (cx + L0 / 2, cy + P0 / 2, zb - 0.001),
                (cx + L0 / 2, cy - P0 / 2, zb - 0.001), (cx - L0 / 2, cy - P0 / 2, zb - 0.001)], sous,
               vers=(0, 0, -1))
        return z + h + ep

    def toit_plat(self, cx, cy, z, L, P, c="beton_sombre", acrotere=0.5, c_acrotere=None, ep=0.3):
        """Toit-terrasse avec acrotère (petit muret de rive)."""
        ca = c_acrotere or "beton_clair"
        self.boite(cx, cy, z, L + 0.1, P + 0.1, ep, ca, dessus=c)
        if acrotere > 0:
            e = 0.25
            for (x, y, sx, sy) in ((cx, cy - P / 2 + e / 2, L + 0.1, e), (cx, cy + P / 2 - e / 2, L + 0.1, e),
                                   (cx - L / 2 + e / 2, cy, e, P - 2 * e), (cx + L / 2 - e / 2, cy, e, P - 2 * e)):
                self.boite(x, y, z + ep, sx, sy, acrotere, ca)
        return z + ep + acrotere

    def toit_mono(self, cx, cy, z, L, P, h, c, debord=0.4, ep=0.15, mur=None):
        """Toit monopente, haut à l'arrière (+Y) ; mur = couleur des côtés."""
        x0, x1 = cx - L / 2 - debord, cx + L / 2 + debord
        y0, y1 = cy - P / 2 - debord, cy + P / 2 + debord
        k = h / P
        za, zb = z - debord * k, z + h + debord * k
        self.f([(x0, y0, za + ep), (x1, y0, za + ep), (x1, y1, zb + ep), (x0, y1, zb + ep)], c, vers=(0, -k, 1))
        self.f([(x0, y0, za), (x1, y0, za), (x1, y1, zb), (x0, y1, zb)], "sous_toit", vers=(0, 0, -1))
        for (pa, pb, v) in (((x0, y0, za), (x1, y0, za), (0, -1, 0)), ((x0, y1, zb), (x1, y1, zb), (0, 1, 0))):
            self.f([pa, pb, (pb[0], pb[1], pb[2] + ep), (pa[0], pa[1], pa[2] + ep)], c, vers=v)
        for sx in (-1, 1):
            xx = x0 if sx < 0 else x1
            self.f([(xx, y0, za), (xx, y1, zb), (xx, y1, zb + ep), (xx, y0, za + ep)], c, vers=(sx, 0, 0))
            if mur:
                xm = cx + sx * L / 2
                self.f([(xm, cy - P / 2, z), (xm, cy + P / 2, z), (xm, cy + P / 2, z + h)], mur, vers=(sx, 0, 0))
        return z + h + ep

    def toit_mansarde(self, cx, cy, z, L, P, h1, h2, c, c_haut=None, lucarnes=0, mur="enduit"):
        """Toit à la Mansart : brisis raide (h1) puis terrasson à croupes (h2)."""
        r = h1 * 0.28
        self.boite(cx, cy, z, L + 0.3, P + 0.3, 0.25, "pierre_claire")
        self.tronc(cx, cy, z + 0.25, L + 0.2, P + 0.2, z + 0.25 + h1, L - 2 * r, P - 2 * r, c, dessus=False)
        zt = z + 0.25 + h1
        L1, P1 = L - 2 * r, P - 2 * r
        k = h2 / (min(L1, P1) / 2)
        self.tronc(cx, cy, zt, L1, P1, zt + h2, max(L1 - P1, 0), max(P1 - L1, 0), c_haut or "zinc")
        if lucarnes:
            pas = L / lucarnes
            for i in range(lucarnes):
                x = cx - L / 2 + pas * (i + 0.5)
                for s in (-1, 1):
                    y = cy + s * (P / 2 - r * 0.5)
                    self.boite(x, y, z + 0.4, 1.1, 0.9, 1.5, mur)
                    self.b.face_orientee(
                        [(x - 0.35, y + s * 0.46, z + 0.6), (x + 0.35, y + s * 0.46, z + 0.6),
                         (x + 0.35, y + s * 0.46, z + 1.65), (x - 0.35, y + s * 0.46, z + 1.65)], "vitre", (0, s, 0))
                    self.toit_2pans(x, y, z + 1.9, 1.1, 1.2, 0.5, c, axe="y", debord=0.08, ep=0.08,
                                    pignon=mur)
        return zt + h2

    def toit_voute(self, cx, cy, z, L, P, h, c, n=6, axe="y", bouts=None):
        """Toit en berceau (voûte) : arc de largeur L (le long de X si axe = "y")."""
        m = self._map(cx, cy, axe)
        larg, long_ = (L, P) if axe == "y" else (P, L)
        prof = [(-larg / 2 * math.cos(math.pi * i / n), h * math.sin(math.pi * i / n)) for i in range(n + 1)]
        ref = m(0, 0, z)
        hl = long_ / 2
        for (ua, za), (ub, zb) in zip(prof, prof[1:]):
            self.f([m(-hl, ua, z + za), m(hl, ua, z + za), m(hl, ub, z + zb), m(-hl, ub, z + zb)], c, ref)
        for s in (-1, 1):
            self.f([m(s * hl, u, z + zz) for u, zz in prof], bouts or c, vers=_sub(m(s, 0, 0), m(0, 0, 0)))
        return z + h

    def sheds(self, cx, cy, z, L, P, h, n, c, vitre="verre_ciel"):
        """Toit en dents de scie (usines) : n dents le long de Y, vitrages au nord (+Y)."""
        pas = P / n
        for i in range(n):
            y0 = cy - P / 2 + i * pas
            y1 = y0 + pas
            x0, x1 = cx - L / 2, cx + L / 2
            self.f([(x0, y0, z), (x1, y0, z), (x1, y1, z + h), (x0, y1, z + h)], c, vers=(0, -1, 2))
            self.f([(x0, y1, z), (x1, y1, z), (x1, y1, z + h), (x0, y1, z + h)], vitre, vers=(0, 1, 0))
            for xx, s in ((x0, -1), (x1, 1)):
                self.f([(xx, y0, z), (xx, y1, z), (xx, y1, z + h)], c, vers=(s, 0, 0))

    # --- Façades ---------------------------------------------------------------
    @staticmethod
    def _facades(cx, cy, L, P):
        return {
            "avant": ((cx, cy - P / 2), (0, -1), L),
            "arriere": ((cx, cy + P / 2), (0, 1), L),
            "gauche": ((cx - L / 2, cy), (-1, 0), P),
            "droite": ((cx + L / 2, cy), (1, 0), P),
        }

    def ouverture(self, fx, fy, n, u, z, l, hh, vitre="vitre", cadre="cadre", forme="rect", w=0.0, appui=None,
                  volets=None):
        """Fenêtre plate (cadre + vitre) sur un mur. forme : rect, arc (plein
        cintre), ogive (arc brisé), rond (oculus)."""
        p, _, (nx, ny) = self.b.repere(fx, fy, n)
        vers = (nx, ny, 0)

        def contour(dl, dh, ww):
            l2, h2 = l / 2 + dl, hh / 2 + dh
            if forme == "rect":
                return [p(u - l2, z - h2, ww), p(u + l2, z - h2, ww), p(u + l2, z + h2, ww), p(u - l2, z + h2, ww)]
            if forme == "rond":
                return [p(u + l2 * math.cos(a), z + l2 * math.sin(a), ww)
                        for a in [2 * math.pi * i / 10 for i in range(10)]]
            # Arc en haut : rectangle jusqu'à z + h2 - l2 puis demi-cercle / ogive.
            zs = z + h2 - l2
            pts = [p(u - l2, z - h2, ww), p(u + l2, z - h2, ww)]
            if forme == "arc":
                for i in range(6):
                    a = math.pi * i / 5
                    pts.append(p(u + l2 * math.cos(a), zs + l2 * math.sin(a), ww))
            else:  # ogive : arc brisé
                a = l2 * 1.4
                for du, dz in ((1.0, 0.0), (0.8, 0.5), (0.45, 0.85), (0.0, 1.0), (-0.45, 0.85), (-0.8, 0.5), (-1.0, 0.0)):
                    pts.append(p(u + du * l2, zs + dz * a, ww))
            return pts

        if cadre:
            self.b.face_orientee(contour(0.1, 0.1, w + 0.03), cadre, vers)
        self.b.face_orientee(contour(0, 0, w + 0.05), vitre, vers)
        if appui:
            self.b.boite_mur(fx, fy, n, u - l / 2 - 0.12, u + l / 2 + 0.12, z - hh / 2 - 0.2, z - hh / 2 - 0.08,
                             0.16, appui)
        if volets:
            for s in (-1, 1):
                uu = u + s * (l / 2 + 0.1 + l / 4)
                self.b.face_orientee([p(uu - l / 4, z - hh / 2, w + 0.04), p(uu + l / 4, z - hh / 2, w + 0.04),
                                      p(uu + l / 4, z + hh / 2, w + 0.04), p(uu - l / 4, z + hh / 2, w + 0.04)],
                                     volets, vers)

    def porte(self, fx, fy, n, u, z0, l, hh, couleur="porte", cadre="cadre", forme="rect", marche=True, auvent=None):
        p, _, (nx, ny) = self.b.repere(fx, fy, n)
        vers = (nx, ny, 0)
        if forme == "arc":
            pts = [p(u - l / 2, z0, 0.05), p(u + l / 2, z0, 0.05)]
            zs = z0 + hh - l / 2
            for i in range(6):
                a = math.pi * i / 5
                pts.append(p(u + l / 2 * math.cos(a), zs + l / 2 * math.sin(a), 0.05))
            cad = [p(u - l / 2 - 0.15, z0, 0.03), p(u + l / 2 + 0.15, z0, 0.03)]
            for i in range(6):
                a = math.pi * i / 5
                cad.append(p(u + (l / 2 + 0.15) * math.cos(a), zs + (l / 2 + 0.15) * math.sin(a), 0.03))
        else:
            pts = [p(u - l / 2, z0, 0.05), p(u + l / 2, z0, 0.05), p(u + l / 2, z0 + hh, 0.05), p(u - l / 2, z0 + hh, 0.05)]
            cad = [p(u - l / 2 - 0.12, z0, 0.03), p(u + l / 2 + 0.12, z0, 0.03), p(u + l / 2 + 0.12, z0 + hh + 0.12, 0.03),
                   p(u - l / 2 - 0.12, z0 + hh + 0.12, 0.03)]
        if cadre:
            self.b.face_orientee(cad, cadre, vers)
        self.b.face_orientee(pts, couleur, vers)
        if marche and z0 > 0.1:
            self.b.boite_mur(fx, fy, n, u - l / 2 - 0.4, u + l / 2 + 0.4, 0.0, z0, 0.6, "pierre", dessous=False)
        if auvent:
            self.b.boite_mur(fx, fy, n, u - l / 2 - 0.5, u + l / 2 + 0.5, z0 + hh + 0.2, z0 + hh + 0.35, 1.2,
                             auvent)

    def corps(self, cx, cy, z0, L, P, etages, he, mur, fen=None, dessus=None, socle=None, porte=None,
              bandeaux=None, chaines=None, vitrine=None):
        """Volume d'un bâtiment avec ses fenêtres.
        fen : {"avant": n, "arriere": n, "gauche": n, "droite": n, "l": 1.0, "h": 1.3,
               "forme": "rect", "vitre": "vitre", "cadre": "cadre", "volets": None,
               "appui": None, "rdc": True (fenêtres au rez-de-chaussée), "bande": False}
        porte : {"l": 1.2, "h": 2.3, "couleur": "porte", "u": 0, "forme": "rect",
                 "cote": "avant", "auvent": None}
        vitrine : couleur de vitre du rez-de-chaussée commercial (côté avant)."""
        H = etages * he
        zs = z0
        if socle:
            self.boite(cx, cy, z0, L + 0.2, P + 0.2, 0.4, socle)
            zs = z0 + 0.4
        self.boite(cx, cy, zs, L, P, H - (zs - z0), mur, dessus=dessus)
        fen = fen or {}
        faces = self._facades(cx, cy, L, P)
        fl, fh = fen.get("l", 1.0), fen.get("h", 1.3)
        porte_cote = (porte or {}).get("cote", "avant")
        pu = (porte or {}).get("u", 0.0)
        pl = (porte or {}).get("l", 1.2)
        for nom, ((fx, fy), n, lg) in faces.items():
            nb = int(fen.get(nom, 0))
            if fen.get("bande"):
                if nb:
                    for e in range(0 if fen.get("rdc", True) else 1, etages):
                        zc = z0 + e * he + he * 0.55
                        self.ouverture(fx, fy, n, 0, zc, lg - 1.0, fh, fen.get("vitre", "vitre"),
                                       fen.get("cadre", None))
                continue
            if nb <= 0:
                continue
            pas = lg / nb
            for e in range(etages):
                if e == 0 and not fen.get("rdc", True):
                    continue
                if e == 0 and vitrine and nom == "avant":
                    continue
                zc = z0 + e * he + he * 0.52
                for i in range(nb):
                    u = -lg / 2 + pas * (i + 0.5)
                    if porte and e == 0 and nom == porte_cote and abs(u - pu) < (pl + fl) / 2 + 0.2:
                        continue
                    self.ouverture(fx, fy, n, u, zc, fl, fh, fen.get("vitre", "vitre"), fen.get("cadre", "cadre"),
                                   fen.get("forme", "rect"), appui=fen.get("appui"), volets=fen.get("volets"))
        if vitrine:
            (fx, fy), n, lg = faces["avant"]
            self.ouverture(fx, fy, n, 0, z0 + 1.6, lg - 1.4, 2.4, vitrine, "metal")
            self.b.boite_mur(fx, fy, n, -lg / 2, lg / 2, z0 + 3.0, z0 + 3.5, 0.6, fen.get("enseigne", "rouge"))
        if porte:
            (fx, fy), n, lg = faces[porte_cote]
            self.porte(fx, fy, n, pu, zs if socle else z0, pl, porte.get("h", 2.3), porte.get("couleur", "porte"),
                       porte.get("cadre", "cadre"), porte.get("forme", "rect"), auvent=porte.get("auvent"))
        if bandeaux:
            for e in range(1, etages):
                self.boite(cx, cy, z0 + e * he - 0.08, L + 0.16, P + 0.16, 0.16, bandeaux, dessous=True)
        if chaines:
            for sx in (-1, 1):
                for sy in (-1, 1):
                    self.boite(cx + sx * (L / 2 - 0.2), cy + sy * (P / 2 - 0.2), zs, 0.5, 0.5, H - (zs - z0), chaines)
        return z0 + H

    def balcons(self, cx, cy, z0, L, P, etages, he, cote="avant", nb=1, larg=None, prof=1.3, dalle="beton_clair",
                garde="verre_clair", premier=1):
        """Balcons filants (nb = 1) ou individuels sur une façade."""
        (fx, fy), n, lg = self._facades(cx, cy, L, P)[cote]
        larg = larg or (lg - 1.0) / nb * 0.8
        pas = lg / nb
        for e in range(premier, etages):
            z = z0 + e * he
            for i in range(nb):
                u = -lg / 2 + pas * (i + 0.5)
                self.b.boite_mur(fx, fy, n, u - larg / 2, u + larg / 2, z - 0.15, z, prof, dalle)
                p, _, (nx, ny) = self.b.repere(fx, fy, n)
                self.b.face_orientee([p(u - larg / 2, z, prof), p(u + larg / 2, z, prof), p(u + larg / 2, z + 1.0, prof),
                                      p(u - larg / 2, z + 1.0, prof)], garde, (nx, ny, 0))

    def cheminee(self, x, y, z0, h, c="brique", l=0.6):
        self.boite(x, y, z0, l, l, h, c)
        self.boite(x, y, z0 + h, l + 0.15, l + 0.15, 0.15, "pierre_grise")

    def clocher(self, x, y, z0, cote, h, mur, fleche="ardoise", h_fleche=None, abat_son="bois_sombre",
                forme="fleche", horloge=False):
        """Tour carrée avec baies en haut, puis flèche, pyramide, bulbe ou toit plat."""
        self.boite(x, y, z0, cote, cote, h, mur)
        zt = z0 + h
        for nom, ((fx, fy), n, lg) in self._facades(x, y, cote, cote).items():
            self.ouverture(fx, fy, n, 0, zt - 1.8, cote * 0.35, 2.2, abat_son, "pierre_claire", "arc")
            if horloge and nom in ("avant", "droite", "gauche", "arriere"):
                self.ouverture(fx, fy, n, 0, zt - 4.2, cote * 0.45, cote * 0.45, "blanc", "noir", "rond")
        self.boite(x, y, zt, cote + 0.3, cote + 0.3, 0.3, "pierre_claire")
        zt += 0.3
        hf = h_fleche or cote * 2.4
        if forme == "fleche":
            self.tronc(x, y, zt, cote, cote, zt + hf, 0.01, 0.01, fleche, dessus=False)
            self.boite(x, y, zt + hf - 0.1, 0.08, 0.08, 1.2, "or")
        elif forme == "pyramide":
            self.tronc(x, y, zt, cote + 0.2, cote + 0.2, zt + hf * 0.4, 0.01, 0.01, fleche, dessus=False)
        elif forme == "bulbe":
            self.boite(x, y, zt, cote * 0.6, cote * 0.6, 1.2, mur)
            self.bulbe(x, y, zt + 1.2, cote * 0.45, cote * 1.1, fleche)
        elif forme == "carre":
            for sx in (-1, 1):
                for sy in (-1, 1):
                    self.boite(x + sx * (cote / 2 - 0.3), y + sy * (cote / 2 - 0.3), zt, 0.6, 0.6, 1.0, mur)
        return zt

    def arcade(self, cx, cy, z0, L, nb, h, prof, mur, cote_y=None):
        """Galerie à arcades en avant d'une façade (piliers + linteau)."""
        y = cy if cote_y is None else cote_y
        pas = L / nb
        for i in range(nb + 1):
            x = cx - L / 2 + i * pas
            self.boite(x, y - prof, z0, 0.6, 0.6, h, mur)
        self.boite(cx, y - prof / 2, z0 + h, L + 0.6, prof + 0.6, 0.7, mur)

    def colonnes(self, cx, cy, z0, L, nb, h, r, c, fronton=None, prof=3.0):
        """Portique à colonnes (temple, musée, palais de justice)."""
        pas = L / (nb - 1)
        for i in range(nb):
            x = cx - L / 2 + i * pas
            self.cyl(x, cy, z0, h, r, c, n=8)
            self.boite(x, cy, z0 + h, r * 2.6, r * 2.6, 0.3, c)
        self.boite(cx, cy + prof / 2 - r, z0 + h + 0.3, L + 2 * r + 0.6, prof, 0.9, c)
        if fronton:
            ztop = z0 + h + 1.2
            self.toit_2pans(cx, cy + prof / 2 - r, ztop, L + 2 * r + 0.6, prof, L * 0.14, fronton, axe="y",
                            debord=0.05, pignon=c)
            self.f([(cx - L / 2 - r - 0.3, cy - r - 0.02, ztop), (cx + L / 2 + r + 0.3, cy - r - 0.02, ztop),
                    (cx, cy - r - 0.02, ztop + L * 0.14)], c, vers=(0, -1, 0))
        self.boite(cx, cy, z0 - 0.0, L + 2.0, prof + 1.0, 0.01, c)

    def silo(self, x, y, r, h, c="tole", toit="dome", c_toit=None, n=12):
        self.cyl(x, y, 0, h, r, c, n=n, dessus=False)
        for k in range(1, int(h / 3)):
            self.cyl(x, y, k * 3.0, 0.15, r + 0.05, c_toit or "zinc", n=n, dessus=False)
        if toit == "dome":
            self.dome(x, y, h, r, c_toit or c, n=n, anneaux=2, h=r * 0.4)
        else:
            self.tronc_cone(x, y, h, r * 0.5, r, 0, c_toit or c, n=n)

    def serre(self, cx, cy, L, P, h, vitre="verre_clair", armature="blanc"):
        """Serre en verre : murets, verrière à deux pans, faîtage blanc."""
        self.boite(cx, cy, 0, L, P, 0.5, "beton_clair")
        self.boite(cx, cy, 0.5, L, P, h - 0.5, vitre)
        self.toit_2pans(cx, cy, h, L, P, P * 0.3, vitre, axe="y" if P > L else "x", debord=0.05, pignon=vitre,
                        sous=vitre, ep=0.05)
        for i in range(int(L / 3) + 1):
            x = cx - L / 2 + i * L / max(int(L / 3), 1)
            self.boite(x, cy - P / 2 - 0.02, 0.5, 0.1, 0.06, h - 0.5, armature)
            self.boite(x, cy + P / 2 + 0.02, 0.5, 0.1, 0.06, h - 0.5, armature)

    def cloture(self, pts, h=1.1, c="bois_gris"):
        """Clôture basse (une lisse par côté) le long d'une ligne fermée."""
        n = len(pts)
        for i in range(n):
            (xa, ya), (xb, yb) = pts[i], pts[(i + 1) % n]
            lg = math.hypot(xb - xa, yb - ya)
            ang = math.atan2(yb - ya, xb - xa)
            mx, my = (xa + xb) / 2, (ya + yb) / 2
            dx, dy = math.cos(ang) * lg / 2, math.sin(ang) * lg / 2
            ox, oy = -math.sin(ang) * 0.04, math.cos(ang) * 0.04
            self.f([(mx - dx - ox, my - dy - oy, h - 0.25), (mx + dx - ox, my + dy - oy, h - 0.25),
                    (mx + dx - ox, my + dy - oy, h), (mx - dx - ox, my - dy - oy, h)], c, (mx + ox * 5, my + oy * 5, h))
            self.f([(mx - dx + ox, my - dy + oy, h - 0.25), (mx + dx + ox, my + dy + oy, h - 0.25),
                    (mx + dx + ox, my + dy + oy, h), (mx - dx + ox, my - dy + oy, h)], c, (mx - ox * 5, my - oy * 5, h))
            self.boite(xa, ya, 0, 0.12, 0.12, h, c)

    def colombages(self, cx, cy, L, P, z0, etages, he, c="bois_sombre", cotes=("avant", "arriere", "gauche", "droite"),
                   pas=1.4, croix=True):
        """Pans de bois apparents : poteaux, sablières à chaque étage et
        écharpes en biais aux extrémités."""
        for cote in cotes:
            (fx, fy), n, lg = self._facades(cx, cy, L, P)[cote]
            nb = max(2, int(lg / pas))
            p, _, (nx, ny) = self.b.repere(fx, fy, n)
            for i in range(nb + 1):
                u = -lg / 2 + 0.1 + i * (lg - 0.2) / nb
                self.b.boite_mur(fx, fy, n, u - 0.09, u + 0.09, z0, z0 + etages * he, 0.06, c, dessous=False)
            for e in range(etages + 1):
                z = z0 + e * he
                self.b.boite_mur(fx, fy, n, -lg / 2, lg / 2, max(z - 0.1, z0), z + 0.1, 0.07, c)
            if croix:
                for e in range(etages):
                    for s in (-1, 1):
                        ua, ub = s * (lg / 2 - 0.1), s * (lg / 2 - 0.1 - (lg - 0.2) / nb)
                        za, zb = z0 + e * he + 0.1, z0 + (e + 1) * he - 0.1
                        d = 0.08
                        self.b.face_orientee([p(ua - d, za, 0.065), p(ua + d, za, 0.065), p(ub + d, zb, 0.065),
                                              p(ub - d, zb, 0.065)], c, (nx, ny, 0))

    def redents(self, cx, cy, L, z, h, marches, c, cote="avant", ep=0.4):
        """Pignon à redents (maisons flamandes et hollandaises) dressé au-dessus
        de la façade avant (y = cy - ep / 2 … ou arrière), de largeur L."""
        s_y = -1 if cote == "avant" else 1
        y0 = cy
        pas_u = (L / 2) / (marches + 0.5)
        pas_z = h / (marches + 0.5)
        droite = [(L / 2, z)]
        for i in range(marches):
            u0, u1 = L / 2 - i * pas_u, L / 2 - (i + 1) * pas_u
            zz = z + (i + 1) * pas_z
            droite += [(u0, zz), (u1, zz)]
        droite.append((droite[-1][0], z + h))
        poly = droite + [(-u, zz) for (u, zz) in reversed(droite)]
        ya, yb = y0 + s_y * 0.0, y0 - s_y * ep
        self.f([(cx + u, ya, zz) for u, zz in poly], c, vers=(0, s_y, 0))
        self.f([(cx + u, yb, zz) for u, zz in poly], c, vers=(0, -s_y, 0))
        centre = (cx, (ya + yb) / 2, z)
        for (ua, za), (ub, zb) in zip(poly, poly[1:]):
            self.f([(cx + ua, ya, za), (cx + ub, ya, zb), (cx + ub, yb, zb), (cx + ua, yb, za)], c, centre)

    def porche(self, cx, y_facade, L, prof, h, poteaux, toit="tuile", poteau="blanc", sol="bois_clair"):
        """Véranda / porche couvert devant la façade avant (y_facade = y du mur)."""
        y = y_facade - prof / 2
        self.boite(cx, y, 0, L, prof, 0.4, sol)
        for i in range(poteaux):
            x = cx - L / 2 + 0.2 + i * (L - 0.4) / max(poteaux - 1, 1)
            self.boite(x, y_facade - prof + 0.2, 0.4, 0.2, 0.2, h - 0.4, poteau)
        self.f([(cx - L / 2 - 0.2, y_facade - prof - 0.3, h), (cx + L / 2 + 0.2, y_facade - prof - 0.3, h),
                    (cx + L / 2 + 0.2, y_facade, h + 0.7), (cx - L / 2 - 0.2, y_facade, h + 0.7)], toit, vers=(0, -1, 2))
        self.f([(cx - L / 2 - 0.2, y_facade - prof - 0.3, h - 0.12), (cx + L / 2 + 0.2, y_facade - prof - 0.3, h - 0.12),
                (cx + L / 2 + 0.2, y_facade, h + 0.58), (cx - L / 2 - 0.2, y_facade, h + 0.58)], "sous_toit",
               vers=(0, 0, -1))
        self.f([(cx - L / 2 - 0.2, y_facade - prof - 0.3, h - 0.12), (cx + L / 2 + 0.2, y_facade - prof - 0.3, h - 0.12),
                (cx + L / 2 + 0.2, y_facade - prof - 0.3, h), (cx - L / 2 - 0.2, y_facade - prof - 0.3, h)], toit,
               vers=(0, -1, 0))

    def pilotis(self, cx, cy, L, P, h, nx_=3, ny_=3, c="bois_sombre", r=0.18):
        for i in range(nx_):
            for j in range(ny_):
                x = cx - L / 2 + 0.3 + i * (L - 0.6) / max(nx_ - 1, 1)
                y = cy - P / 2 + 0.3 + j * (P - 0.6) / max(ny_ - 1, 1)
                self.boite(x, y, 0, r * 2, r * 2, h, c)

    # --- Fin ---------------------------------------------------------------------
    def centre_et_bornes(self):
        """Recentre le modèle sur son emprise (X, Y) et renvoie (dx, dy, dz)."""
        bm = self.b.bm
        xs = [v.co.x for v in bm.verts]
        ys = [v.co.y for v in bm.verts]
        zs = [v.co.z for v in bm.verts]
        mx, my = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
        z0 = min(zs)
        for v in bm.verts:
            v.co.x -= mx
            v.co.y -= my
            v.co.z -= z0
        return max(xs) - min(xs), max(ys) - min(ys), max(zs) - z0


def vignette(obj, chemin, taille=(360, 270), azimut=-35.0, elevation=30.0):
    """Petite image d'aperçu (Workbench, couleurs de la palette, vue
    axonométrique cadrée sur le modèle)."""
    scene = bpy.context.scene
    dims = obj.dimensions
    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    a, e = math.radians(azimut), math.radians(elevation)
    direction = Vector((-math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e)))
    # Taille apparente : projection des huit coins de la boîte sur le plan de vue.
    droite = Vector((0, 0, 1)).cross(direction).normalized()
    haut = direction.cross(droite).normalized()
    coins = [Vector((sx * dims.x / 2, sy * dims.y / 2, z)) for sx in (-1, 1) for sy in (-1, 1) for z in (0, dims.z)]
    us = [c.dot(droite) for c in coins]
    vs = [c.dot(haut) for c in coins]
    largeur, hauteur = max(us) - min(us), max(vs) - min(vs)
    ratio = taille[0] / taille[1]
    cam_data.ortho_scale = max(largeur, hauteur * ratio) * 1.08
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    centre = droite * ((max(us) + min(us)) / 2) + haut * ((max(vs) + min(vs)) / 2)
    cam.location = centre + direction * (max(dims) * 3 + 10)
    cam.rotation_euler = (-direction).to_track_quat("-Z", "Y").to_euler()
    cam_data.clip_end = max(dims) * 8 + 50
    scene.camera = cam
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.view_settings.view_transform = "Standard"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "TEXTURE"
    scene.display.shading.show_shadows = False
    scene.display.shading.show_cavity = True
    scene.render.resolution_x, scene.render.resolution_y = taille
    scene.render.film_transparent = True
    scene.render.filepath = os.path.abspath(chemin)
    bpy.ops.render.render(write_still=True)
