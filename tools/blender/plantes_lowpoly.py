"""Génère toutes les plantes low-poly du jeu dans Blender et les exporte en .glb.

Arbres, arbustes, herbes, fleurs, cultures et rochers, pour chaque biome
ESA WorldCover du jeu (forêt tempérée, boréale, méditerranéenne, tropicale,
savane, désert, toundra, marais, mangrove, montagne, champs…). Tout est
construit par code : aucune ressource extérieure, donc aucune licence à
respecter (le résultat nous appartient, comme tout ce qu'on crée avec Blender).

Toutes les plantes partagent la même petite texture « palette » (64 × 64 px,
8 × 8 couleurs) : dans Godot, un seul matériau (avec le vent) sert à toutes.
Faces plates, une couleur par face : le style low-poly du jeu.

Usage (Blender 4.2 ou plus, testé avec 5.3) :

    blender --background --factory-startup --python tools/blender/plantes_lowpoly.py -- \
        --dossier assets/modeles/plantes [--seul chene] [--apercu docs/apercu-plantes.png]

ou, avec le module Python « bpy » (pip install bpy) :

    python tools/blender/plantes_lowpoly.py -- --dossier assets/modeles/plantes

Repères : 1 unité = 1 m, Z vers le haut dans Blender (Y dans Godot), origine
au pied de la plante. Les arbres ont aussi une version « _loin » de quelques
triangles, affichée au-delà de ~110 m.
"""

import math
import os
import random
import sys

import bpy  # avant bmesh (nécessaire avec le module « bpy » de pip)
import bmesh
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import batiment_lowpoly as bl  # noqa: E402  (lire_options, _materiau_texture, apercu)

# --- Palette commune à toutes les plantes ----------------------------------------
# L'ordre compte : il fixe la case de chaque couleur, la même dans tous les .glb.
PALETTE = [
    ("tronc", "#6b4a32"), ("tronc_clair", "#8d6b49"), ("tronc_sombre", "#4a3424"),
    ("bouleau", "#e6e2d6"), ("bouleau_tache", "#3b3631"), ("palmier_tronc", "#9a7a54"),
    ("ecorce_grise", "#8c8476"), ("baobab", "#a08c74"),
    ("chene", "#3f7a34"), ("hetre", "#4f8f3a"), ("bouleau_f", "#78a844"), ("peuplier", "#3e6f2f"),
    ("sapin", "#2a5a36"), ("pin", "#3b6638"), ("pin_parasol", "#4b6f35"), ("palmier", "#4d8a35"),
    ("acacia", "#7e9a3f"), ("olivier", "#7f9466"), ("tropical", "#2f7a2c"), ("tropical_clair", "#4a9a36"),
    ("paletuvier", "#3c6e3a"), ("buisson", "#557f34"), ("buisson_sec", "#8e8a5a"), ("saule_nain", "#7c9a5a"),
    ("cactus", "#4f8250"), ("cactus_raquette", "#6a9a4c"), ("agave", "#78a08a"), ("herbe", "#6aa040"),
    ("herbe_seche", "#b7a95e"), ("roseau", "#7f9a4e"), ("roseau_epi", "#6b4a2e"), ("fougere", "#4a8a36"),
    ("lichen", "#a8b07a"), ("mousse", "#6a8a4a"), ("rouge", "#d0302a"), ("blanc", "#f4f2e8"),
    ("jaune", "#f0c830"), ("coeur", "#e0a020"), ("lavande", "#8a6ac0"), ("bleu", "#3a5ad0"),
    ("rose", "#e07aa0"), ("orange", "#e88a30"), ("ble", "#d6b65a"), ("ble_epi", "#e4c86c"),
    ("mais", "#6a9a38"), ("mais_epi", "#e8cc5a"), ("colza", "#e8d23a"), ("tige", "#5a8a34"),
    ("tournesol", "#f2c02a"), ("tournesol_coeur", "#5a3a1e"), ("vigne", "#5a8a3a"), ("raisin", "#4e2a52"),
    ("piquet", "#8a7a62"), ("chou", "#7aa86a"), ("riz", "#8ab84a"), ("terre", "#6a5038"),
    ("roche", "#8e8a82"), ("roche_claire", "#a8a49a"), ("roche_sombre", "#6e6a64"), ("sable_roche", "#b8a07a"),
    ("oyat", "#a8b06a"), ("bois_mort", "#a39a8c"), ("bois_mort_sombre", "#6e675e"), ("feuille_morte", "#a8743a"),
]
assert len(PALETTE) <= 64

# Rôle de chaque couleur pour les saisons (lu par le shader des plantes dans
# palette_roles.png) : 0 bois, roche et le reste, 1 feuillage caduc (roussit à
# l'automne, tombe l'hiver), 2 feuillage persistant, 3 herbe (jaunit l'hiver ou
# l'été sec), 4 fleur (seulement à la floraison).
ROLES = {
    "chene": 1, "hetre": 1, "bouleau_f": 1, "peuplier": 1, "buisson": 1, "saule_nain": 1, "vigne": 1, "chou": 0,
    "sapin": 2, "pin": 2, "pin_parasol": 2, "palmier": 2, "acacia": 2, "olivier": 2, "tropical": 2,
    "tropical_clair": 2, "paletuvier": 2, "cactus": 2, "cactus_raquette": 2, "agave": 2, "lichen": 2, "mousse": 2,
    "herbe": 3, "herbe_seche": 3, "roseau": 3, "fougere": 3, "oyat": 3, "tige": 3, "buisson_sec": 3,
    "rouge": 4, "blanc": 4, "jaune": 4, "lavande": 4, "bleu": 4, "rose": 4,
}


class Palette(bl.Palette):
    def __init__(self):
        self.cases = {}
        self.couleurs = []
        for nom, hexa in PALETTE:
            self.ajoute(nom, hexa)


# --- Construction -----------------------------------------------------------------

class Plante:
    """Accumule des faces colorées (palette) dans un bmesh, faces plates."""

    def __init__(self, palette, graine):
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")
        self.palette = palette
        self.rng = random.Random(graine)

    def face(self, pts, couleur):
        verts = [self.bm.verts.new(p) for p in pts]
        f = self.bm.faces.new(verts)
        f.smooth = False
        u, v = self.palette.uv(self.palette.index(couleur))
        for loop in f.loops:
            loop[self.uv].uv = (u, v)
        return f

    # Tronc, branche, tige : cylindre ou cône tronqué entre deux points.
    def cylindre(self, a, b, r0, r1, n, couleur, fond=False, haut=True):
        a, b = Vector(a), Vector(b)
        axe = (b - a).normalized()
        ref = Vector((1, 0, 0)) if abs(axe.x) < 0.9 else Vector((0, 1, 0))
        u = axe.cross(ref).normalized()
        w = axe.cross(u)
        ang0 = self.rng.random() * math.tau
        bas, hau = [], []
        for i in range(n):
            t = ang0 + math.tau * i / n
            d = u * math.cos(t) + w * math.sin(t)
            bas.append(a + d * r0)
            hau.append(b + d * r1)
        for i in range(n):
            j = (i + 1) % n
            if r1 > 1e-4:
                self.face([bas[i], bas[j], hau[j], hau[i]], couleur)
            else:
                self.face([bas[i], bas[j], b], couleur)
        if haut and r1 > 1e-4:
            self.face(hau, couleur)
        if fond:
            self.face(list(reversed(bas)), couleur)

    def cone(self, centre, r, h, n, couleur, fond=True):
        c = Vector(centre)
        self.cylindre(c, c + Vector((0, 0, h)), r, 0.0, n, couleur, fond=fond)

    # Feuillage : icosaèdre (20 faces) ou icosphère (80) déformé au hasard.
    def boule(self, centre, rx, ry, rz, couleur, subdiv=1, alea=0.18, aplatir_bas=0.0):
        tmp = bmesh.new()
        bmesh.ops.create_icosphere(tmp, subdivisions=subdiv, radius=1.0)
        c = Vector(centre)
        for f in tmp.faces:
            pts = []
            for v in f.verts:
                p = v.co.copy()
                # Même déformation pour un sommet partagé : graine sur sa position.
                r = random.Random(hash((round(p.x, 3), round(p.y, 3), round(p.z, 3), self.rng_base)))
                k = 1.0 + (r.random() * 2 - 1) * alea
                z = p.z
                if z < 0 and aplatir_bas > 0:
                    z *= 1.0 - aplatir_bas
                pts.append(c + Vector((p.x * rx * k, p.y * ry * k, z * rz * k)))
            self.face(pts, couleur)
        tmp.free()

    @property
    def rng_base(self):
        if not hasattr(self, "_rb"):
            self._rb = self.rng.random()
        return self._rb

    def nouvelle_forme(self):
        """Change la graine de déformation (chaque boule différente)."""
        self._rb = self.rng.random()

    def lame(self, pied, angle, penche, larg, haut, couleur, segs=2, courbe=0.35):
        """Brin d'herbe, feuille longue : bande qui s'affine et se courbe."""
        p = Vector(pied)
        d = Vector((math.cos(angle), math.sin(angle), 0))
        cote = Vector((-d.y, d.x, 0)) * (larg / 2)
        pts_g, pts_d = [], []
        for s in range(segs + 1):
            t = s / segs
            ofs = d * (penche * t + courbe * haut * t * t)
            z = haut * t * (1.0 - 0.25 * courbe * t)
            k = 1.0 - t
            q = p + ofs + Vector((0, 0, z))
            pts_g.append(q - cote * k)
            pts_d.append(q + cote * k)
        for s in range(segs):
            if s == segs - 1:
                self.face([pts_g[s], pts_d[s], pts_d[s + 1]], couleur)
            else:
                self.face([pts_g[s], pts_d[s], pts_d[s + 1], pts_g[s + 1]], couleur)

    def palme(self, base, angle, longueur, largeur, tombe, couleur, segs=3):
        """Palme de palmier : bande pliée en V qui retombe."""
        b = Vector(base)
        d = Vector((math.cos(angle), math.sin(angle), 0))
        cote = Vector((-d.y, d.x, 0))
        axe = []
        for s in range(segs + 1):
            t = s / segs
            axe.append(b + d * longueur * t + Vector((0, 0, longueur * (0.35 * t - tombe * t * t))))
        for s in range(segs):
            t0, t1 = s / segs, (s + 1) / segs
            w0 = largeur * math.sin(math.pi * (0.15 + 0.85 * t0)) / 2
            w1 = largeur * math.sin(math.pi * (0.15 + 0.85 * t1)) / 2 if s < segs - 1 else 0.0
            pli = Vector((0, 0, -0.12 * largeur))
            for sg in (-1, 1):
                if w1 > 0:
                    self.face([axe[s], axe[s] + cote * w0 * sg + pli, axe[s + 1] + cote * w1 * sg + pli, axe[s + 1]], couleur)
                else:
                    self.face([axe[s], axe[s] + cote * w0 * sg + pli, axe[s + 1]], couleur)

    def disque(self, centre, r, n, couleur, normale_z=True, incline=0.0, angle=0.0):
        """Fleur, coeur, raquette : polygone plat (vertical si incline=90)."""
        c = Vector(centre)
        pts = []
        a = math.radians(incline)
        for i in range(n):
            t = math.tau * i / n
            x, y = math.cos(t) * r, math.sin(t) * r
            # Inclinaison autour de l'axe X puis rotation autour de Z.
            y2, z2 = y * math.cos(a), y * math.sin(a)
            xr = x * math.cos(angle) - y2 * math.sin(angle)
            yr = x * math.sin(angle) + y2 * math.cos(angle)
            pts.append(c + Vector((xr, yr, z2)))
        self.face(pts, couleur)

    def boite(self, x0, y0, z0, x1, y1, z1, couleur):
        v = [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),
             (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)]
        for f in [(0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7), (4, 5, 6, 7)]:
            self.face([v[i] for i in f], couleur)

    def rocher(self, centre, r, couleur, haut=0.6, enfoui=0.3):
        """Pierre : icosaèdre irrégulier, aplati, un peu enfoncé dans le sol."""
        self.nouvelle_forme()
        c = Vector(centre) + Vector((0, 0, r * haut * 0.4 * (1 - enfoui)))
        self.boule(c, r * (0.9 + self.rng.random() * 0.3), r * (0.8 + self.rng.random() * 0.3), r * haut,
                   couleur, alea=0.28, aplatir_bas=0.6)

    def pt(self, rayon):
        a = self.rng.random() * math.tau
        r = rayon * math.sqrt(self.rng.random())
        return math.cos(a) * r, math.sin(a) * r


# --- Arbres -------------------------------------------------------------------------
# Hauteurs réelles (le jeu est à l'échelle 1 case = 1 m), variées ensuite de ±30 %
# par le jeu à la plantation.

def feuillu(p, tronc_h, tronc_r, couronne, h_couronne, couleur, n_boules=4, tronc="tronc", subdiv=1):
    """Arbre à feuilles : tronc, deux ou trois branches, couronne de boules."""
    p.cylindre((0, 0, -0.2), (0, 0, tronc_h), tronc_r, tronc_r * 0.6, 6, tronc)
    z = tronc_h + h_couronne * 0.42
    p.nouvelle_forme()
    p.boule((0, 0, z), couronne * 0.62, couronne * 0.62, h_couronne * 0.42, couleur, subdiv=subdiv)
    for i in range(n_boules - 1):
        a = math.tau * i / (n_boules - 1) + p.rng.random() * 0.8
        d = couronne * 0.42
        bx, by = math.cos(a) * d, math.sin(a) * d
        bz = z - h_couronne * (0.05 + p.rng.random() * 0.15)
        p.cylindre((0, 0, tronc_h * 0.8), (bx * 0.7, by * 0.7, bz), tronc_r * 0.45, tronc_r * 0.2, 4, tronc, haut=False)
        p.nouvelle_forme()
        p.boule((bx, by, bz), couronne * 0.38, couronne * 0.38, h_couronne * 0.3, couleur)


def chene(p):
    feuillu(p, 4.5, 0.45, 11.0, 9.0, "chene", n_boules=5, tronc="tronc_sombre")


def hetre(p):
    feuillu(p, 6.0, 0.35, 8.0, 12.0, "hetre", n_boules=4, tronc="ecorce_grise")


def bouleau(p):
    p.cylindre((0, 0, -0.2), (0, 0, 9.0), 0.17, 0.08, 5, "bouleau")
    for z in (2.0, 4.5, 7.0):  # taches noires de l'écorce
        p.cylindre((0, 0, z), (0, 0, z + 0.25), 0.15, 0.14, 5, "bouleau_tache", haut=False)
    for i, (z, r) in enumerate([(6.0, 1.7), (8.2, 1.5), (10.0, 1.1)]):
        a = i * 2.3
        p.nouvelle_forme()
        p.boule((math.cos(a) * 0.4, math.sin(a) * 0.4, z), r, r, r * 1.1, "bouleau_f")


def peuplier(p):
    p.cylindre((0, 0, -0.2), (0, 0, 4.0), 0.28, 0.2, 5, "ecorce_grise")
    p.nouvelle_forme()
    p.boule((0, 0, 12.0), 1.8, 1.8, 9.0, "peuplier", alea=0.12)


def sapin(p, couleur="sapin", h=18.0, r=3.4, etages=4):
    p.cylindre((0, 0, -0.2), (0, 0, 2.5), 0.32, 0.25, 5, "tronc_sombre")
    for i in range(etages):
        t = i / etages
        base = 2.0 + t * (h - 4.0) * 0.92
        rr = r * (1.0 - t * 0.72)
        hh = (h - base) * 0.55 if i < etages - 1 else h - base
        p.cone((0, 0, base), rr, hh, 7, couleur)


def epicea(p):
    sapin(p, "sapin", h=24.0, r=3.0, etages=5)


def meleze(p):
    sapin(p, "bouleau_f", h=18.0, r=2.8, etages=4)


def pin(p):
    """Pin sylvestre : long tronc nu, couronne haute et plate."""
    p.cylindre((0, 0, -0.2), (0.3, 0.1, 11.0), 0.3, 0.18, 5, "tronc_clair")
    p.cylindre((0.2, 0.05, 8.0), (-1.5, 0.6, 10.5), 0.12, 0.06, 4, "tronc_clair", haut=False)
    for (x, y, z, r) in [(0.3, 0.1, 12.0, 2.6), (-1.6, 0.7, 10.8, 1.7), (1.6, -0.9, 11.2, 1.6)]:
        p.nouvelle_forme()
        p.boule((x, y, z), r, r, r * 0.6, "pin", alea=0.2)


def pin_parasol(p):
    """Pin parasol (Méditerranée) : tronc penché qui se divise, couronne en ombrelle."""
    p.cylindre((0, 0, -0.2), (0.6, 0, 7.0), 0.35, 0.25, 5, "tronc_clair")
    p.cylindre((0.6, 0, 7.0), (-1.8, 0.8, 9.3), 0.18, 0.1, 4, "tronc_clair", haut=False)
    p.cylindre((0.6, 0, 7.0), (2.5, -0.6, 9.5), 0.18, 0.1, 4, "tronc_clair", haut=False)
    p.nouvelle_forme()
    p.boule((0.4, 0, 10.0), 5.5, 5.0, 1.6, "pin_parasol", subdiv=2, alea=0.15, aplatir_bas=0.5)


def olivier(p):
    p.cylindre((0, 0, -0.2), (0.4, 0.2, 1.6), 0.45, 0.35, 6, "ecorce_grise")
    p.cylindre((0.4, 0.2, 1.6), (-0.8, 0.5, 3.0), 0.25, 0.15, 5, "ecorce_grise", haut=False)
    p.cylindre((0.4, 0.2, 1.6), (1.4, -0.4, 3.2), 0.25, 0.15, 5, "ecorce_grise", haut=False)
    for (x, y, z, r) in [(-0.9, 0.5, 3.6, 1.9), (1.4, -0.4, 3.8, 2.0), (0.2, 0.1, 4.5, 2.1)]:
        p.nouvelle_forme()
        p.boule((x, y, z), r, r, r * 0.65, "olivier", alea=0.22)


def palmier(p):
    """Cocotier : stipe courbé en segments, couronne de 8 palmes."""
    pts = []
    for i in range(6):
        t = i / 5
        pts.append(Vector((2.2 * t * t, 0, 11.5 * t)))
    for i in range(5):
        p.cylindre(pts[i], pts[i + 1], 0.3 - 0.03 * i, 0.27 - 0.03 * i, 5, "palmier_tronc", haut=(i == 4))
    top = pts[-1]
    for i in range(8):
        a = math.tau * i / 8 + p.rng.random() * 0.3
        p.palme(top, a, 5.0 + p.rng.random(), 1.4, 0.9, "palmier")
    for i in range(3):  # noix de coco
        a = math.tau * i / 3
        p.nouvelle_forme()
        p.boule(top + Vector((math.cos(a) * 0.3, math.sin(a) * 0.3, -0.35)), 0.22, 0.22, 0.22, "tronc_sombre")


def acacia(p):
    """Acacia de savane : tronc qui fourche, couronne plate et large."""
    p.cylindre((0, 0, -0.2), (0, 0, 2.5), 0.3, 0.22, 5, "tronc")
    for (x, y) in [(-2.2, 0.8), (2.0, -1.0), (0.3, 2.0)]:
        p.cylindre((0, 0, 2.5), (x, y, 5.6), 0.18, 0.1, 4, "tronc", haut=False)
    p.nouvelle_forme()
    p.boule((0, 0.3, 6.3), 5.2, 4.6, 0.9, "acacia", subdiv=2, alea=0.18, aplatir_bas=0.5)


def baobab(p):
    p.cylindre((0, 0, -0.2), (0, 0, 9.0), 2.0, 1.2, 8, "baobab")
    for i in range(6):
        a = math.tau * i / 6
        x, y = math.cos(a), math.sin(a)
        p.cylindre((x * 0.6, y * 0.6, 8.6), (x * 3.0, y * 3.0, 11.0), 0.35, 0.15, 4, "baobab", haut=False)
        p.nouvelle_forme()
        p.boule((x * 3.1, y * 3.1, 11.3), 1.3, 1.3, 0.8, "acacia")


def tropical(p):
    """Grand arbre de forêt tropicale : très haut, contreforts, couronne étagée."""
    p.cylindre((0, 0, -0.2), (0, 0, 18.0), 0.7, 0.4, 7, "ecorce_grise")
    for i in range(4):  # contreforts
        a = math.tau * i / 4 + 0.4
        x, y = math.cos(a), math.sin(a)
        p.face([(x * 0.5, y * 0.5, 2.5), (x * 0.5, y * 0.5, 0.0), (x * 2.0, y * 2.0, -0.1)], "ecorce_grise")
        p.face([(x * 2.0, y * 2.0, -0.1), (x * 0.5, y * 0.5, 0.0), (x * 0.5, y * 0.5, 2.5)], "ecorce_grise")
    for (x, y, z, r, c) in [(0, 0, 21.0, 6.5, "tropical"), (-4.5, 1.5, 19.0, 3.8, "tropical_clair"),
                            (4.0, -2.0, 19.5, 4.0, "tropical"), (0.5, 4.5, 18.5, 3.5, "tropical_clair")]:
        p.nouvelle_forme()
        p.boule((x, y, z), r, r, r * 0.45, c, alea=0.2, aplatir_bas=0.3)


def paletuvier(p):
    """Palétuvier (mangrove) : racines-échasses arquées, couronne ronde."""
    for i in range(6):
        a = math.tau * i / 6 + p.rng.random() * 0.4
        x, y = math.cos(a), math.sin(a)
        p.cylindre((x * 2.0, y * 2.0, -0.3), (x * 1.0, y * 1.0, 1.4), 0.08, 0.08, 4, "tronc", haut=False)
        p.cylindre((x * 1.0, y * 1.0, 1.4), (0, 0, 2.0), 0.08, 0.1, 4, "tronc", haut=False)
    p.cylindre((0, 0, 2.0), (0, 0, 5.0), 0.22, 0.15, 5, "tronc")
    for (x, y, z, r) in [(0, 0, 6.2, 2.8), (-1.6, 0.8, 5.5, 1.8), (1.6, -0.6, 5.6, 1.8)]:
        p.nouvelle_forme()
        p.boule((x, y, z), r, r, r * 0.7, "paletuvier")


def saule(p):
    """Saule pleureur (bords de l'eau) : dôme et rideau de branches retombantes."""
    p.cylindre((0, 0, -0.2), (0, 0, 4.0), 0.45, 0.35, 6, "tronc")
    p.cylindre((0, 0, 3.8), (-1.2, 0.5, 6.0), 0.2, 0.12, 4, "tronc", haut=False)
    p.cylindre((0, 0, 3.8), (1.3, -0.4, 6.2), 0.2, 0.12, 4, "tronc", haut=False)
    p.nouvelle_forme()
    p.boule((0, 0, 7.0), 3.6, 3.6, 2.2, "bouleau_f", alea=0.12)
    # Rideau : lanières qui retombent en s'écartant, de longueurs inégales.
    n = 16
    for i in range(n):
        a0 = math.tau * i / n
        a1 = a0 + math.tau / n * 0.65
        zb = 2.0 + p.rng.random() * 1.8
        q = [(math.cos(a0) * 3.3, math.sin(a0) * 3.3, 7.4),
             (math.cos(a1) * 3.3, math.sin(a1) * 3.3, 7.4),
             (math.cos(a1) * 4.2, math.sin(a1) * 4.2, zb + 0.4),
             (math.cos((a0 + a1) / 2) * 4.3, math.sin((a0 + a1) / 2) * 4.3, zb),
             (math.cos(a0) * 4.2, math.sin(a0) * 4.2, zb + 0.4)]
        p.face(q, "saule_nain" if i % 3 == 0 else "bouleau_f")


# --- Arbustes, désert, toundra -------------------------------------------------------

def buisson(p, couleur="buisson", r=0.9, fleurs=None):
    for i, (x, y, z, k) in enumerate([(0, 0, 0.55, 1.0), (0.45, 0.25, 0.45, 0.7), (-0.4, -0.3, 0.4, 0.75)]):
        p.nouvelle_forme()
        p.boule((x * r, y * r, z * r), r * k * 0.75, r * k * 0.75, r * k * 0.6, couleur, alea=0.2, aplatir_bas=0.4)
    if fleurs:
        for i in range(7):
            a = p.rng.random() * math.tau
            z = 0.3 + p.rng.random() * 0.7
            rr = math.sqrt(max(0.0, 1.0 - ((z - 0.5) / 0.6) ** 2)) * r * 0.78
            p.disque((math.cos(a) * rr, math.sin(a) * rr, z * r + 0.05), 0.12, 5, fleurs, incline=60, angle=a + math.pi / 2)


def buisson_fleuri(p):
    buisson(p, "buisson", 1.0, fleurs="rose")


def genet(p):
    """Genêt : buisson de broussailles aux fleurs jaunes."""
    buisson(p, "tige", 0.9, fleurs="jaune")


def buisson_sec(p):
    """Broussaille sèche (désert, savane) : brindilles en éventail."""
    for i in range(9):
        a = math.tau * i / 9 + p.rng.random() * 0.5
        p.lame((0, 0, 0), a, 0.5, 0.12, 0.9 + p.rng.random() * 0.4, "buisson_sec", segs=2, courbe=0.25)
    p.nouvelle_forme()
    p.boule((0, 0, 0.35), 0.5, 0.5, 0.3, "buisson_sec", alea=0.3)


def saule_nain(p):
    """Toundra : petit coussin de saule arctique."""
    for (x, y, r) in [(0, 0, 0.55), (0.45, 0.2, 0.35), (-0.35, 0.3, 0.3)]:
        p.nouvelle_forme()
        p.boule((x, y, 0.08), r, r, r * 0.45, "saule_nain", alea=0.25, aplatir_bas=0.8)


def lichen(p):
    for (x, y, r, c) in [(0, 0, 0.35, "lichen"), (0.4, 0.15, 0.22, "mousse"), (-0.25, -0.3, 0.25, "lichen")]:
        p.nouvelle_forme()
        p.boule((x, y, 0.0), r, r, 0.1, c, alea=0.25, aplatir_bas=0.9)


def cactus_saguaro(p):
    p.cylindre((0, 0, -0.2), (0, 0, 7.0), 0.35, 0.3, 7, "cactus")
    p.cone((0, 0, 7.0), 0.3, 0.35, 7, "cactus", fond=False)
    for (sens, z0, z1, d) in [(1, 2.6, 5.4, 1.2), (-1, 3.4, 5.8, 1.0)]:
        p.cylindre((0, 0, z0), (sens * d, 0, z0), 0.22, 0.22, 6, "cactus", haut=False)
        p.cylindre((sens * d, 0, z0 - 0.15), (sens * d, 0, z1), 0.22, 0.2, 6, "cactus", haut=False)
        p.cone((sens * d, 0, z1), 0.2, 0.25, 6, "cactus", fond=False)


def cactus_raquette(p):
    """Figuier de Barbarie (Opuntia) : raquettes ovales empilées."""
    for (x, z, ang, r) in [(0, 0.45, 0.0, 0.45), (0.35, 1.1, 0.6, 0.35), (-0.3, 1.05, -0.5, 0.33), (0.1, 1.6, 0.2, 0.28)]:
        p.nouvelle_forme()
        a = p.rng.random() * math.pi
        p.boule((x, 0, z), r * 0.85, 0.09, r, "cactus_raquette", alea=0.08)
    for i in range(4):
        a = p.rng.random() * math.tau
        p.disque((math.cos(a) * 0.2, math.sin(a) * 0.12, 0.9 + p.rng.random() * 0.8), 0.07, 5, "jaune")


def agave(p):
    for i in range(11):
        a = math.tau * i / 11
        p.lame((0, 0, 0), a, 0.25, 0.28, 0.6 + (i % 3) * 0.15, "agave", segs=2, courbe=0.9)


# --- Herbes, fleurs, sous-bois -------------------------------------------------------

def touffe(p, couleur, n, rayon, haut, larg=0.06, courbe=0.4, epis=None):
    for i in range(n):
        x, y = p.pt(rayon)
        a = math.atan2(y, x) if (x or y) else p.rng.random() * math.tau
        h = haut * (0.6 + p.rng.random() * 0.5)
        p.lame((x, y, 0), a + (p.rng.random() - 0.5), 0.05, larg, h, couleur, segs=2, courbe=courbe)
        if epis and i % 2 == 0:
            p.cylindre((x + math.cos(a) * 0.05, y + math.sin(a) * 0.05, h * 0.9),
                       (x + math.cos(a) * 0.08, y + math.sin(a) * 0.08, h * 1.1), 0.03, 0.02, 3, epis)


def herbe(p):
    touffe(p, "herbe", 9, 0.25, 0.35)


def hautes_herbes(p):
    touffe(p, "herbe_seche", 12, 0.35, 0.9, larg=0.05, epis="ble_epi")


def roseaux(p):
    touffe(p, "roseau", 12, 0.35, 2.2, larg=0.05, courbe=0.15, epis="roseau_epi")


def oyat(p):
    """Herbe des dunes."""
    touffe(p, "oyat", 12, 0.3, 0.7, larg=0.04, courbe=0.6)


def fougere(p):
    for i in range(7):
        a = math.tau * i / 7 + p.rng.random() * 0.4
        p.palme((0, 0, 0.05), a, 0.9 + p.rng.random() * 0.3, 0.32, 0.5, "fougere", segs=3)


def _fleurs(p, couleur, coeur, n=7, haut=0.45, r=0.07, petales=5):
    touffe(p, "tige", 6, 0.25, haut * 0.6, larg=0.05)
    for i in range(n):
        x, y = p.pt(0.3)
        h = haut * (0.7 + p.rng.random() * 0.5)
        p.cylindre((x, y, 0), (x, y, h), 0.012, 0.012, 3, "tige", haut=False)
        p.disque((x, y, h), r, petales, couleur)
        if coeur:
            p.disque((x, y, h + 0.01), r * 0.35, 4, coeur)


def coquelicots(p):
    _fleurs(p, "rouge", "tournesol_coeur")


def marguerites(p):
    _fleurs(p, "blanc", "jaune", n=8, haut=0.4, r=0.06, petales=8)


def fleurs_jaunes(p):
    _fleurs(p, "jaune", None, n=9, haut=0.3, r=0.05)


def gentianes(p):
    """Fleurs de montagne (alpages)."""
    _fleurs(p, "bleu", "blanc", n=6, haut=0.18, r=0.05)


def lavande(p):
    for i in range(14):
        a = math.tau * i / 14 + p.rng.random() * 0.3
        h = 0.45 + p.rng.random() * 0.15
        top = Vector((math.cos(a) * 0.3, math.sin(a) * 0.3, h))
        p.cylindre((0, 0, 0), top, 0.015, 0.012, 3, "olivier", haut=False)
        p.cylindre(top, top + Vector((math.cos(a) * 0.03, math.sin(a) * 0.03, 0.14)), 0.03, 0.015, 4, "lavande")


# --- Cultures (une case de 1 m × 1 m, rangs dans l'axe X) ------------------------

def ble(p, couleur="ble", epi="ble_epi", haut=0.85):
    for rang in (-0.33, 0.0, 0.33):
        for k in range(4):
            x = -0.375 + k * 0.25 + (p.rng.random() - 0.5) * 0.08
            y = rang + (p.rng.random() - 0.5) * 0.06
            h = haut * (0.85 + p.rng.random() * 0.2)
            a = p.rng.random() * math.tau
            p.lame((x, y, 0), a, 0.03, 0.08, h * 0.8, couleur, segs=1, courbe=0.1)
            # L'épi : un losange vertical (2 triangles), vu des deux côtés.
            e = Vector((math.cos(a + 1.6) * 0.03, math.sin(a + 1.6) * 0.03, 0))
            c = Vector((x + 0.03, y, h * 0.86))
            p.face([c + Vector((0, 0, -0.1)), c + e, c + Vector((0, 0, 0.12)), c - e], epi)


def riz(p):
    for rang in (-0.33, 0.0, 0.33):
        for k in range(3):
            touffe_x = -0.33 + k * 0.33
            for i in range(3):
                a = p.rng.random() * math.tau
                p.lame((touffe_x, rang, 0), a, 0.04, 0.05, 0.6, "riz", segs=2, courbe=0.5)


def mais(p):
    for rang in (-0.25, 0.25):
        for x in (-0.25, 0.25):
            p.cylindre((x, rang, 0), (x, rang, 2.2), 0.03, 0.02, 3, "mais", haut=False)
            for z, a in [(0.7, 0.3), (1.1, 2.4), (1.5, 4.2), (1.9, 1.3)]:
                p.lame((x, rang, z), a, 0.1, 0.12, 0.65, "mais", segs=2, courbe=-0.6)
            p.cylindre((x + 0.04, rang, 1.2), (x + 0.1, rang, 1.45), 0.04, 0.03, 3, "mais_epi", haut=False)


def colza(p):
    for rang in (-0.25, 0.25):
        for x in (-0.25, 0.25):
            p.cylindre((x, rang, 0), (x, rang, 1.0), 0.02, 0.015, 3, "tige", haut=False)
            p.nouvelle_forme()
            p.boule((x, rang, 1.15), 0.22, 0.22, 0.14, "colza", alea=0.3)
    for i in range(4):
        x, y = p.pt(0.45)
        p.lame((x, y, 0), p.rng.random() * math.tau, 0.1, 0.12, 0.5, "tige", segs=1, courbe=0.3)


def tournesol(p):
    for x, y in [(-0.25, -0.25), (0.25, 0.25)]:
        p.cylindre((x, y, 0), (x, y, 1.7), 0.035, 0.03, 4, "tige", haut=False)
        for z, a in [(0.6, 0.2), (1.0, 2.5)]:
            p.lame((x, y, z), a, 0.15, 0.25, 0.35, "tige", segs=1, courbe=-0.5)
        # La fleur regarde vers le sud-est (-Y dans Blender, donc +Z dans Godot)
        p.disque((x, y - 0.03, 1.75), 0.24, 10, "tournesol", incline=70)
        p.disque((x, y - 0.05, 1.75), 0.12, 6, "tournesol_coeur", incline=70)


def vigne(p):
    """Un cep palissé sur un fil, rang dans l'axe X."""
    p.boite(-0.5, -0.03, 0, -0.44, 0.03, 1.5, "piquet")
    p.cylindre((-0.47, 0, 1.0), (0.5, 0, 1.0), 0.008, 0.008, 3, "piquet", haut=False)
    p.cylindre((0, 0, 0), (0.05, 0, 0.75), 0.06, 0.045, 5, "tronc_sombre")
    for (x, z, r) in [(-0.25, 1.0, 0.33), (0.25, 1.05, 0.33), (0.0, 1.35, 0.3)]:
        p.nouvelle_forme()
        p.boule((x, 0, z), r, 0.22, r * 0.85, "vigne", alea=0.25)
    for x in (-0.2, 0.15):
        p.nouvelle_forme()
        p.boule((x, -0.18, 0.78), 0.07, 0.05, 0.1, "raisin", alea=0.2)


def legumes(p):
    """Potager / maraîchage : rangs de choux."""
    for x in (-0.25, 0.25):
        for y in (-0.25, 0.25):
            p.nouvelle_forme()
            p.boule((x, y, 0.12), 0.17, 0.17, 0.14, "chou", alea=0.2, aplatir_bas=0.8)
            for i in range(4):
                a = math.tau * i / 4 + 0.4
                p.lame((x, y, 0.02), a, 0.12, 0.18, 0.12, "chou", segs=1, courbe=1.0)


# --- Rochers et cailloux --------------------------------------------------------------

def rocher(p):
    p.rocher((0, 0, 0), 1.4, "roche", haut=0.75)
    p.rocher((1.2, 0.6, 0), 0.6, "roche_claire", haut=0.6)


def gros_rocher(p):
    p.rocher((0, 0, 0), 3.0, "roche_sombre", haut=0.65)
    p.rocher((2.4, -1.0, 0), 1.2, "roche", haut=0.7)
    p.rocher((-2.0, 1.5, 0), 0.8, "roche_claire", haut=0.6)


def cailloux(p):
    for i in range(6):
        x, y = p.pt(0.5)
        c = p.rng.choice(["roche", "roche_claire", "roche_sombre", "sable_roche"])
        p.rocher((x, y, 0), 0.08 + p.rng.random() * 0.12, c, haut=0.6)


def rocher_desert(p):
    p.rocher((0, 0, 0), 1.6, "sable_roche", haut=0.9)
    p.rocher((1.0, -0.8, 0), 0.7, "sable_roche", haut=0.6)


# --- Versions « loin » des arbres (quelques triangles) -------------------------------

def loin_feuillu(h_tronc, r, h, couleur, tronc="tronc"):
    def f(p):
        p.cylindre((0, 0, -0.2), (0, 0, h_tronc + 0.5), r * 0.06, r * 0.04, 3, tronc, haut=False)
        z = h_tronc + h * 0.5
        # Double pyramide à 6 pans : 12 triangles, ronde de partout.
        pts = [(r * math.cos(math.tau * i / 6), r * math.sin(math.tau * i / 6), z) for i in range(6)]
        hautp, basp = (0, 0, z + h * 0.5), (0, 0, z - h * 0.5)
        for i in range(6):
            a, b = pts[i], pts[(i + 1) % 6]
            p.face([a, b, hautp], couleur)
            p.face([b, a, basp], couleur)
    return f


def loin_conifere(h, r, couleur="sapin"):
    def f(p):
        p.cylindre((0, 0, -0.2), (0, 0, 2.2), r * 0.08, r * 0.08, 3, "tronc_sombre", haut=False)
        p.cone((0, 0, 1.8), r, h - 1.8, 5, couleur)
    return f


def loin_palmier(p):
    p.cylindre((0, 0, -0.2), (2.2, 0, 11.5), 0.3, 0.25, 3, "palmier_tronc", haut=False)
    for i in range(5):
        a = math.tau * i / 5
        p.palme((2.2, 0, 11.5), a, 5.0, 1.4, 0.9, "palmier", segs=1)


# --- Étapes de vie : jeunes pousses et arbres morts ---------------------------------
# Les arbres jeunes et adultes sont le modèle de l'espèce, mis à l'échelle par
# le jeu. Les pousses et les arbres morts ont leurs propres modèles, par famille.

def pousse_feuillu(p):
    """Jeune pousse d'arbre à feuilles (≈ 1,2 m) : tige fine et quelques bouquets."""
    p.cylindre((0, 0, -0.05), (0.05, 0, 1.0), 0.025, 0.012, 4, "tronc_clair", haut=False)
    for (x, y, z, r) in [(0.05, 0, 1.05, 0.22), (-0.12, 0.08, 0.75, 0.16), (0.14, -0.06, 0.6, 0.14)]:
        p.nouvelle_forme()
        p.boule((x, y, z), r, r, r * 0.8, "hetre", alea=0.25)


def pousse_conifere(p):
    """Jeune sapin (≈ 1 m)."""
    p.cylindre((0, 0, -0.05), (0, 0, 0.2), 0.03, 0.03, 4, "tronc_sombre", haut=False)
    p.cone((0, 0, 0.15), 0.38, 0.55, 6, "sapin")
    p.cone((0, 0, 0.5), 0.26, 0.5, 6, "sapin")


def pousse_palmier(p):
    """Jeune palmier (≈ 1 m) : une touffe de palmes."""
    for i in range(5):
        a = math.tau * i / 5
        p.palme((0, 0, 0.05), a, 0.9, 0.3, -0.6, "palmier", segs=2)


def mort_feuillu(p):
    """Arbre mort : tronc gris, branches nues et cassées."""
    p.cylindre((0, 0, -0.2), (0, 0, 5.5), 0.42, 0.25, 6, "bois_mort")
    p.cylindre((0, 0, 5.4), (0.2, 0.1, 7.0), 0.22, 0.12, 5, "bois_mort", haut=True)
    for (x, y, z0, z1) in [(2.4, 0.5, 3.8, 6.6), (-2.0, 1.2, 4.2, 7.2), (0.4, -2.3, 4.6, 6.9), (-1.0, -1.4, 3.0, 4.6)]:
        p.cylindre((0, 0, z0), (x, y, z1), 0.13, 0.05, 4, "bois_mort", haut=False)
        p.cylindre((x * 0.7, y * 0.7, z0 + (z1 - z0) * 0.7), (x * 0.9 + 0.5, y * 0.9 - 0.3, z1 + 0.6), 0.05, 0.02, 3, "bois_mort_sombre", haut=False)


def mort_conifere(p):
    """Conifère mort : grand fût gris et moignons de branches."""
    p.cylindre((0, 0, -0.2), (0, 0, 13.0), 0.32, 0.08, 6, "bois_mort")
    for i in range(7):
        z = 3.0 + i * 1.4
        a = i * 2.4
        l = 1.6 - i * 0.15
        p.cylindre((0, 0, z), (math.cos(a) * l, math.sin(a) * l, z - 0.3), 0.05, 0.02, 3, "bois_mort_sombre", haut=False)


def mort_palmier(p):
    """Palmier mort : stipe cassé, quelques palmes sèches pendantes."""
    p.cylindre((0, 0, -0.2), (0.6, 0, 7.5), 0.3, 0.26, 5, "palmier_tronc")
    for i in range(3):
        a = math.tau * i / 3 + 0.5
        p.palme((0.6, 0, 7.4), a, 2.2, 0.8, 1.6, "herbe_seche", segs=2)


# Nom -> (fonction, catégorie). Les noms sont ceux des fichiers .glb.
PLANTES = {
    # Arbres
    "chene": chene, "hetre": hetre, "bouleau": bouleau, "peuplier": peuplier,
    "sapin": sapin, "epicea": epicea, "meleze": meleze, "pin": pin, "pin_parasol": pin_parasol,
    "olivier": olivier, "palmier": palmier, "acacia": acacia, "baobab": baobab,
    "tropical": tropical, "paletuvier": paletuvier, "saule": saule,
    # Arbustes, désert, toundra
    "buisson": buisson, "buisson_fleuri": buisson_fleuri, "genet": genet, "buisson_sec": buisson_sec,
    "saule_nain": saule_nain, "lichen": lichen, "cactus_saguaro": cactus_saguaro,
    "cactus_raquette": cactus_raquette, "agave": agave,
    # Herbes et fleurs
    "herbe": herbe, "hautes_herbes": hautes_herbes, "roseaux": roseaux, "oyat": oyat, "fougere": fougere,
    "coquelicots": coquelicots, "marguerites": marguerites, "fleurs_jaunes": fleurs_jaunes,
    "gentianes": gentianes, "lavande": lavande,
    # Cultures
    "ble": ble, "riz": riz, "mais": mais, "colza": colza, "tournesol": tournesol, "vigne": vigne,
    "legumes": legumes,
    # Rochers
    "rocher": rocher, "gros_rocher": gros_rocher, "cailloux": cailloux, "rocher_desert": rocher_desert,
    # Versions lointaines
    "chene_loin": loin_feuillu(4.5, 5.5, 9.0, "chene", "tronc_sombre"),
    "hetre_loin": loin_feuillu(6.0, 4.0, 12.0, "hetre", "ecorce_grise"),
    "bouleau_loin": loin_feuillu(5.0, 1.8, 6.5, "bouleau_f", "bouleau"),
    "peuplier_loin": loin_feuillu(3.0, 1.8, 18.0, "peuplier", "ecorce_grise"),
    "sapin_loin": loin_conifere(18.0, 3.4), "epicea_loin": loin_conifere(24.0, 3.0),
    "meleze_loin": loin_conifere(18.0, 2.8, "bouleau_f"),
    "pin_loin": loin_feuillu(9.0, 2.8, 3.0, "pin", "tronc_clair"),
    "pin_parasol_loin": loin_feuillu(8.0, 5.5, 3.0, "pin_parasol", "tronc_clair"),
    "olivier_loin": loin_feuillu(2.0, 2.6, 3.5, "olivier", "ecorce_grise"),
    "palmier_loin": loin_palmier,
    "acacia_loin": loin_feuillu(5.0, 5.0, 1.8, "acacia"),
    "baobab_loin": loin_feuillu(9.0, 4.0, 2.5, "acacia", "baobab"),
    "tropical_loin": loin_feuillu(17.0, 6.5, 6.0, "tropical", "ecorce_grise"),
    "paletuvier_loin": loin_feuillu(3.0, 2.8, 4.0, "paletuvier"),
    "saule_loin": loin_feuillu(3.0, 4.0, 6.0, "bouleau_f"),
    # Étapes de vie
    "pousse_feuillu": pousse_feuillu, "pousse_conifere": pousse_conifere, "pousse_palmier": pousse_palmier,
    "mort_feuillu": mort_feuillu, "mort_conifere": mort_conifere, "mort_palmier": mort_palmier,
}


def construit(nom, palette):
    p = Plante(palette, nom)
    PLANTES[nom](p)
    return p


def exporte(p, nom, dossier, apercu=None):
    bm = p.bm
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    # Rien ne flotte : une plante dont le bas est au-dessus du sol y est posée
    # (5 cm enfoncée pour ne pas laisser de jour sur un sol en pente douce).
    bas = min(v.co.z for v in bm.verts)
    if bas > -0.05:
        for v in bm.verts:
            v.co.z -= bas + 0.05
    mesh = bpy.data.meshes.new(nom)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(nom, mesh)
    bpy.context.scene.collection.objects.link(obj)
    mat = bl._materiau_texture("plantes", palette_image(p.palette), closest=True)
    mat.use_backface_culling = False  # herbes et palmes vues des deux côtés
    mesh.materials.append(mat)
    tris = sum(len(f.vertices) - 2 for f in mesh.polygons)
    print("PLANTE %s : %d triangles, %.1f x %.1f x %.1f m" % (
        nom, tris, obj.dimensions.x, obj.dimensions.y, obj.dimensions.z))
    out = os.path.abspath(os.path.join(dossier, nom + ".glb"))
    os.makedirs(os.path.dirname(out), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=out, export_format="GLB", use_selection=True,
        export_apply=True, export_yup=True, export_materials="EXPORT",
        export_image_format="AUTO",
    )
    if apercu:
        bl.apercu(obj, apercu)
    bpy.data.objects.remove(obj)
    return tris


_PALETTE_IMG = {}


def palette_image(palette):
    if "img" not in _PALETTE_IMG:
        _PALETTE_IMG["img"] = palette.image("plantes_palette")
    return _PALETTE_IMG["img"]


def main():
    opts = bl.lire_options()
    dossier = opts.get("dossier", "assets/modeles/plantes")
    seul = opts.get("seul")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    palette = Palette()
    total = 0
    for nom in PLANTES:
        if seul and nom != seul:
            continue
        p = construit(nom, palette)
        total += exporte(p, nom, dossier, opts.get("apercu") if seul else None)
    # Les rôles des couleurs pour les saisons, même découpage que la palette.
    cote = bl.PALETTE_TAILLE * bl.PIXELS_PAR_CASE
    roles = bpy.data.images.new("palette_roles", cote, cote, alpha=False)
    roles.colorspace_settings.name = "Non-Color"
    px = [0.0] * (cote * cote * 4)
    for i, (nom_c, _h) in enumerate(PALETTE):
        v = ROLES.get(nom_c, 0) / 4.0
        col, lig = i % bl.PALETTE_TAILLE, i // bl.PALETTE_TAILLE
        for dy in range(bl.PIXELS_PAR_CASE):
            y = cote - 1 - (lig * bl.PIXELS_PAR_CASE + dy)
            for dx in range(bl.PIXELS_PAR_CASE):
                o = (y * cote + col * bl.PIXELS_PAR_CASE + dx) * 4
                px[o:o + 4] = [v, v, v, 1.0]
    roles.pixels = px
    roles.filepath_raw = os.path.abspath(os.path.join(dossier, "palette_roles.png"))
    roles.file_format = "PNG"
    roles.save()
    # La palette, aussi en image à part (pour la retoucher dans Krita).
    img = palette_image(palette)
    img.filepath_raw = os.path.abspath(os.path.join(dossier, "palette_plantes.png"))
    img.file_format = "PNG"
    img.save()
    print("PLANTES OK : %d modèles, %d triangles en tout" % (len(PLANTES) if not seul else 1, total))


if __name__ == "__main__":
    main()
