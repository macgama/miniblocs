"""Génère les personnages low-poly arrondis du jeu dans Blender et les exporte en .glb.

Des bébés aux personnes âgées, de toutes corpulences (mince, moyenne, ronde,
forte), femmes et hommes, plus les coiffures (courtes, longues, afro, tresses,
locks, chignon, foulard, turban…) et les vêtements longs (jupes, robes).
Tout est construit par code : aucune ressource extérieure.

Un personnage reste léger (environ 700 à 1 000 triangles) mais n'est plus fait
de boîtes : chaque partie est un « tube » à 8 ou 10 côtés dont le rayon varie
(épaules, ventre, poitrine, mollets, joues), avec faces plates (style du jeu).

Les couleurs ne sont pas figées : chaque face pointe dans une petite texture
« palette des rôles » (8 colonnes × 4 lignes utiles) :

    colonne : 0 peau, 1 cheveux, 2 haut, 3 bas, 4 chaussures, 5 accessoire
              (foulard, turban), 6 manche (haut ou peau), 7 mollet (bas ou peau)
    ligne   : 0 normal, 1 ombre, 2 clair, 3 couleur fixe de la texture
              (yeux, blanc des yeux)

Dans Godot, le shader scripts/habitants/silhouette.gdshader remplace chaque
rôle par la couleur de l'habitant (peau, cheveux, tenue du métier…).

Squelette (noms des nœuds, origine exactement à l'articulation, regard vers +Z
dans Godot, pieds en y = 0) :

    racine
    └ bassin (hanches)          ├ jambe_g / jambe_d (hanche) └ tibia_g / tibia_d (genou)
                                ├ habit (vide : jupes et robes, échelle = hanches)
                                └ torse (taille) ├ tete (base du cou) └ cheveux (vide, centre de la tête, échelle = tête)
                                                 └ bras_g / bras_d (épaule) └ avant_bras_g / avant_bras_d (coude) └ main_g / main_d (vide)

Usage (Blender 4.2 ou plus, testé avec 5.3) :

    blender --background --factory-startup --python tools/blender/personnages_lowpoly.py -- \
        --dossier assets/modeles/personnages [--seul adulte_f_moyen] [--apercu docs/apercu.png]

ou, avec le module Python « bpy » (pip install bpy) :

    python tools/blender/personnages_lowpoly.py -- --dossier assets/modeles/personnages
"""

import math
import os
import random
import sys

import bpy  # avant bmesh (nécessaire avec le module « bpy » de pip)
import bmesh
from mathutils import Vector

# --- Palette des rôles -------------------------------------------------------------

PEAU, CHEVEUX, HAUT, BAS, CHAUSSURES, ACCESSOIRE, MANCHE, MOLLET = range(8)
NORMAL, OMBRE, CLAIR, FIXE = range(4)
COLONNES = 8
PX = 8  # pixels par case
# Couleurs de démonstration (celles qu'on voit dans Blender ou une visionneuse).
DEMO = ["#d9a37e", "#3a2a20", "#3a86c8", "#3b3f4a", "#2a2a2a", "#c8a040", "#3a86c8", "#3b3f4a"]
# Ligne 3 : couleurs fixes (colonne 0 = yeux, 1 = blanc).
FIXES = ["#1c1a1a", "#f2efe8", "#7a3a36", "#000000", "#000000", "#000000", "#000000", "#000000"]
TEINTES = [1.0, 0.78, 1.14]


def hex_rgb(h):
    h = h.lstrip("#")
    return [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]


def uv_case(role, ligne=NORMAL):
    # V vers le haut dans Blender ; le glTF le retourne, Godot lit donc
    # UV.y = (ligne + 0.5) / 8 : ligne 0 en haut de l'image.
    return ((role + 0.5) / COLONNES, 1.0 - (ligne + 0.5) / COLONNES)


_IMG = {}


def palette_image():
    if "img" in _IMG:
        return _IMG["img"]
    cote = COLONNES * PX
    img = bpy.data.images.new("personnages_roles", cote, cote, alpha=False)
    px = [0.0] * (cote * cote * 4)
    for lig in range(COLONNES):
        for col in range(COLONNES):
            if lig < 3:
                c = [min(1.0, v * TEINTES[lig]) for v in hex_rgb(DEMO[col])]
            elif lig == 3:
                c = hex_rgb(FIXES[col])
            else:
                c = [0.5, 0.5, 0.5]
            for dy in range(PX):
                y = cote - 1 - (lig * PX + dy)  # pixels Blender : depuis le bas
                for dx in range(PX):
                    o = (y * cote + col * PX + dx) * 4
                    px[o:o + 4] = [c[0], c[1], c[2], 1.0]
    img.pixels = px
    img.pack()
    _IMG["img"] = img
    return img


def materiau():
    if "mat" in _IMG:
        return _IMG["mat"]
    mat = bpy.data.materials.new("personnage")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = 0.85
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = palette_image()
    tex.interpolation = "Closest"
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    _IMG["mat"] = mat
    return mat


# --- Géométrie ----------------------------------------------------------------------
# On raisonne en repère Godot (Y en haut, +Z devant, +X à gauche du personnage)
# et on convertit en repère Blender (Z en haut, −Y devant) au dernier moment.


def G(x, y, z):
    return Vector((x, -z, y))


class Maille:
    """Un maillage bmesh, une couleur de rôle par face."""

    def __init__(self):
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")

    def face(self, pts, role, ligne=NORMAL):
        vs = [self.bm.verts.new(p) for p in pts]
        try:
            f = self.bm.faces.new(vs)
        except ValueError:
            return None
        u = uv_case(role, ligne)
        for loop in f.loops:
            loop[self.uv].uv = u
        f.smooth = False
        return f

    def anneaux(self, anneaux, n, axe="y", ferme_bas=True, ferme_haut=True, phase=0.0):
        """Tube passant par une suite d'anneaux.

        Chaque anneau : dict(c=(x, y, z) centre, rx, rav (rayon avant/haut),
        rar (rayon arrière/bas), role, ligne). axe "y" : anneaux horizontaux
        (tronc, membres, tête) ; axe "z" : anneaux verticaux le long de l'avant
        (pieds), rav = haut, rar = bas. La bande entre l'anneau i et i+1 prend
        le rôle de l'anneau i ; les bouchons, celui de l'anneau du bout.
        """
        cercles = []
        for a in anneaux:
            cx, cy, cz = a["c"]
            pts = []
            for k in range(n):
                t = 2.0 * math.pi * (k + phase) / n
                c, s = math.cos(t), math.sin(t)
                r2 = a.get("rav", a["rx"]) if s > 0 else a.get("rar", a["rx"])
                if axe == "y":
                    pts.append(G(cx + a["rx"] * c, cy, cz + r2 * s))
                else:
                    pts.append(G(cx + a["rx"] * c, cy + r2 * s, cz))
            cercles.append(pts)
        for i in range(len(cercles) - 1):
            a, b = cercles[i], cercles[i + 1]
            r = anneaux[i]
            for k in range(n):
                k2 = (k + 1) % n
                if axe == "y" and anneaux[i + 1]["c"][1] > r["c"][1]:
                    self.face([a[k], a[k2], b[k2], b[k]], r["role"], r.get("ligne", NORMAL))
                else:
                    self.face([a[k], b[k], b[k2], a[k2]], r["role"], r.get("ligne", NORMAL))
        montant = axe == "z" or anneaux[-1]["c"][1] > anneaux[0]["c"][1]
        if ferme_bas:
            r = anneaux[0]
            pts = list(cercles[0])
            if montant:
                pts.reverse()
            self.face(pts, r["role"], r.get("ligne", NORMAL))
        if ferme_haut:
            r = anneaux[-1]
            pts = list(cercles[-1])
            if not montant:
                pts.reverse()
            self.face(pts, r["role"], r.get("ligne", NORMAL))

    def boule(self, c, rx, ry, rz, role, ligne=NORMAL, n=8, m=5, garde=None, bosses=0.0, rng=None):
        """Ellipsoïde low-poly (n côtés, m tranches). garde(x, y, z) en repère
        unité : ne garde que les faces dont le centre y répond vrai (coiffures)."""
        cx, cy, cz = c
        grille = []
        for j in range(m + 1):
            phi = math.pi * j / m  # 0 = haut
            ligne_pts = []
            for k in range(n):
                t = 2.0 * math.pi * k / n
                ux = math.sin(phi) * math.cos(t)
                uy = math.cos(phi)
                uz = math.sin(phi) * math.sin(t)
                f = 1.0
                if bosses and rng and 0 < j < m:
                    f += rng.uniform(-bosses, bosses)
                ligne_pts.append((ux * f, uy * f, uz * f))
            grille.append(ligne_pts)

        def P(u):
            return G(cx + u[0] * rx, cy + u[1] * ry, cz + u[2] * rz)

        for j in range(m):
            for k in range(n):
                k2 = (k + 1) % n
                quad = [grille[j][k], grille[j][k2], grille[j + 1][k2], grille[j + 1][k]]
                if garde:
                    mx = sum(q[0] for q in quad) / 4
                    my = sum(q[1] for q in quad) / 4
                    mz = sum(q[2] for q in quad) / 4
                    if not garde(mx, my, mz):
                        continue
                if j == 0:
                    pts = [P(quad[0]), P(quad[3]), P(quad[2])]
                elif j == m - 1:
                    pts = [P(quad[0]), P(quad[3]), P(quad[1])]
                else:
                    pts = [P(quad[0]), P(quad[3]), P(quad[2]), P(quad[1])]
                self.face(pts, role, ligne)

    def boite(self, c, t, role, ligne=NORMAL):
        cx, cy, cz = c
        hx, hy, hz = t[0] / 2, t[1] / 2, t[2] / 2
        p = [G(cx + sx * hx, cy + sy * hy, cz + sz * hz) for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)]
        # index = (sx, sy, sz) en bits 4, 2, 1
        for q in ([0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]):
            self.face([p[i] for i in q], role, ligne)

    def incline(self, angle):
        """Tourne tout le maillage autour de l'axe avant (Z Godot), en radians :
        positif = vers +X (la gauche du personnage)."""
        from mathutils import Matrix
        bmesh.ops.rotate(self.bm, verts=self.bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(-angle, 3, "Y"))

    def objet(self, nom, parent=None, position=(0, 0, 0)):
        bm = self.bm
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        me = bpy.data.meshes.new(nom)
        bm.to_mesh(me)
        bm.free()
        me.materials.append(materiau())
        ob = bpy.data.objects.new(nom, me)
        bpy.context.scene.collection.objects.link(ob)
        if parent is not None:
            ob.parent = parent
        ob.location = G(*position)
        return ob


def vide(nom, parent, position, echelle=(1, 1, 1)):
    ob = bpy.data.objects.new(nom, None)
    bpy.context.scene.collection.objects.link(ob)
    ob.parent = parent
    ob.location = G(*position)
    # Échelle en repère Godot (x, y, z) -> Blender (x, z, y).
    ob.scale = (echelle[0], echelle[2], echelle[1])
    ob.empty_display_size = 0.05
    return ob


def A(c, rx, rav=None, rar=None, role=PEAU, ligne=NORMAL):
    return {"c": c, "rx": rx, "rav": rx if rav is None else rav, "rar": rx if rar is None else rar,
            "role": role, "ligne": ligne}


# --- Corps --------------------------------------------------------------------------
# h : taille (m) ; tete : rayon de la tête ; jambe : hauteur de la hanche (part
# de h) ; epaules, hanches : demi-largeurs ; ventre, poitrine : avancée (m) ;
# membre : épaisseur relative ; dos : voûte (personnes âgées).

AGES = {
    "bebe":   dict(h=0.80, tete=0.085, jambe=0.36, epaules=0.115, hanches=0.095, membre=1.25, cou=0.0),
    "petit":  dict(h=1.08, tete=0.092, jambe=0.42, epaules=0.14, hanches=0.11, membre=1.0, cou=0.03),
    "enfant": dict(h=1.36, tete=0.097, jambe=0.46, epaules=0.165, hanches=0.125, membre=0.95, cou=0.045),
    "ado":    dict(h=1.64, tete=0.103, jambe=0.50, epaules=0.20, hanches=0.15, membre=0.95, cou=0.05),
    "adulte": dict(h=1.74, tete=0.106, jambe=0.50, epaules=0.215, hanches=0.16, membre=1.0, cou=0.05),
    "senior": dict(h=1.69, tete=0.106, jambe=0.49, epaules=0.205, hanches=0.165, membre=1.0, cou=0.04),
}
CORPULENCES = {
    "mince": dict(ventre=-0.01, gras=0.82, hanches=0.92, epaules=0.95),
    "moyen": dict(ventre=0.01, gras=1.0, hanches=1.0, epaules=1.0),
    "rond":  dict(ventre=0.06, gras=1.22, hanches=1.12, epaules=1.04),
    "fort":  dict(ventre=0.12, gras=1.45, hanches=1.25, epaules=1.1),
}
VARIANTES = (
    [("bebe", "x", c) for c in ("moyen", "rond")]
    + [(a, "x", c) for a in ("petit", "enfant") for c in ("mince", "moyen", "rond")]
    + [("ado", s, c) for s in ("f", "h") for c in ("mince", "moyen", "rond")]
    + [("adulte", s, c) for s in ("f", "h") for c in ("mince", "moyen", "rond", "fort")]
    + [("senior", s, c) for s in ("f", "h") for c in ("mince", "moyen", "rond")]
)


def parametres(age, sexe, corp):
    p = dict(AGES[age])
    c = CORPULENCES[corp]
    if sexe == "f":
        p["h"] *= {"ado": 0.97, "adulte": 0.94, "senior": 0.94}.get(age, 1.0)
        p["epaules"] *= 0.88
        p["hanches"] *= 1.08
        p["poitrine"] = {"ado": 0.03, "adulte": 0.045, "senior": 0.04}.get(age, 0.0)
        p["tete"] *= 0.97
    else:
        p["poitrine"] = 0.0
    p["ventre"] = c["ventre"] * p["h"] / 1.74
    if age in ("bebe", "petit"):
        p["ventre"] += 0.02 * p["h"]
    p["gras"] = c["gras"]
    p["epaules"] *= c["epaules"]
    p["hanches"] *= c["hanches"]
    p["dos"] = 0.06 if age == "senior" else 0.0
    p["age"], p["sexe"], p["corp"] = age, sexe, corp
    return p


def construit_corps(nom, p):
    h = p["h"]
    g = p["gras"]
    m = p["membre"]
    rt = p["tete"]
    racine = bpy.data.objects.new(nom, None)
    bpy.context.scene.collection.objects.link(racine)

    y_hanche = h * p["jambe"]
    y_genou = y_hanche * 0.52
    y_cheville = h * 0.045
    y_taille = y_hanche + h * 0.09
    y_cou = h - 2.15 * rt - p["cou"]  # base du cou
    y_epaule = y_cou - 0.035 * h / 1.74
    dos = p["dos"]
    hx = p["hanches"]
    ex = p["epaules"]
    ve = p["ventre"]
    po = p["poitrine"]
    ecart_jambe = hx * 0.52
    r_cuisse = (0.075 if p["age"] not in ("bebe", "petit", "enfant") else 0.06 * h / 1.2) * m * (0.6 + 0.4 * g)
    r_cuisse = min(r_cuisse, hx * 0.62)
    r_bras = (0.042 if p["age"] not in ("bebe", "petit") else 0.04 * h / 1.0) * m * (0.65 + 0.35 * g)

    # Bassin : de la taille à l'entrejambe (rôle « bas »).
    b = Maille()
    yt = y_taille - y_hanche
    prof = hx * 0.72 + max(ve, 0) * 0.5
    b.anneaux([
        A((0, -0.06 * h / 1.74, 0), hx * 0.55, prof * 0.6, prof * 0.6, BAS),
        A((0, 0.0, 0), hx * 1.0, prof + max(ve, 0) * 0.2, prof * 0.95, BAS),
        A((0, yt * 0.6, 0), hx * 0.97, prof + max(ve, 0) * 0.5, prof * 0.92, BAS),
        A((0, yt + 0.01, 0), hx * 0.9 + max(ve, 0) * 0.3, prof * 0.95 + max(ve, 0) * 0.7, prof * 0.88, BAS),
    ], 10)
    bassin = b.objet("bassin", racine, (0, y_hanche, 0))

    # Jambes : cuisse (bas) puis tibia (mollet) et pied (chaussures).
    for cote, suffixe in ((1, "g"), (-1, "d")):
        j = Maille()
        lj = y_hanche - y_genou
        j.anneaux([
            A((0, 0.02, 0), r_cuisse * 1.05, role=BAS),
            A((0, -lj * 0.35, 0), r_cuisse, role=BAS),
            A((0, -lj * 0.8, 0.005), r_cuisse * 0.78, role=BAS),
            A((0, -lj - 0.01, 0.005), r_cuisse * 0.72, role=BAS),
        ], 8, ferme_haut=False)
        jambe = j.objet("jambe_" + suffixe, bassin, (cote * ecart_jambe, 0, 0))
        t = Maille()
        lt = y_genou - y_cheville
        rm = r_cuisse * 0.72
        t.anneaux([
            A((0, 0.01, 0), rm, role=MOLLET),
            A((0, -lt * 0.3, -0.005), rm * 0.98, rm * 0.9, rm * 1.1, MOLLET),
            A((0, -lt * 0.9, 0), rm * 0.6, role=MOLLET),
            A((0, -lt - 0.005, 0), rm * 0.6, role=CHAUSSURES),
        ], 8)
        # Pied : un petit tube couché vers l'avant.
        lp = h * 0.15 * (1.0 if p["age"] not in ("bebe", "petit") else 0.85)
        rp = rm * 0.8
        t.anneaux([
            A((0, -lt + 0.0, -rp * 0.9), rp * 0.85, rp * 0.8, rp * 0.2, CHAUSSURES),
            A((0, -lt - y_cheville + rp * 0.9, -rp * 0.1), rp * 1.0, rp * 0.9, rp * 0.9, CHAUSSURES),
            A((0, -lt - y_cheville + rp * 0.75, lp * 0.55), rp * 1.05, rp * 0.7, rp * 0.75, CHAUSSURES),
            A((0, -lt - y_cheville + rp * 0.55, lp * 0.82), rp * 0.85, rp * 0.45, rp * 0.55, CHAUSSURES),
        ], 6, axe="z")
        t.objet("tibia_" + suffixe, jambe, (0, -lj, 0.0))

    # Torse : de la taille aux épaules (rôle « haut »), un peu voûté si âgé.
    tr = Maille()
    yc = y_cou - y_taille
    ye = y_epaule - y_taille
    pr = ex * 0.55
    an = [
        A((0, -0.04 * h / 1.74, 0), hx * 0.92 + max(ve, 0) * 0.3, prof * 0.98 + max(ve, 0) * 0.72, prof * 0.9, HAUT),
        A((0, yc * 0.25, dos * 0.15), max(hx * 0.86, ex * 0.72) + max(ve, 0) * 0.35, pr * 0.95 + max(ve, 0) * 1.1, pr * 0.85, HAUT),
        A((0, yc * 0.52, dos * 0.4), ex * 0.82 + max(ve, 0) * 0.25, pr * 1.0 + max(ve * 0.6, po * 1.3), pr * 0.9 + dos * 0.3, HAUT),
        A((0, ye * 0.82, dos * 0.75), ex * 0.92, pr * 0.95 + po * 0.5, pr * 0.92 + dos * 0.4, HAUT),
        A((0, ye, dos * 0.9), ex * 0.82, pr * 0.8, pr * 0.8 + dos * 0.2, HAUT),
        A((0, yc - 0.005, dos), rt * 0.62 * (0.8 + 0.2 * g), rt * 0.58, rt * 0.55, HAUT),
    ]
    tr.anneaux(an, 10, ferme_haut=False)
    torse = tr.objet("torse", bassin, (0, y_taille - y_hanche, 0))

    # Tête : cou (peau) et tête ovale, yeux, sourcils, nez, oreilles.
    te = Maille()
    rc = rt * (0.45 if p["age"] != "bebe" else 0.5) * (0.85 + 0.15 * g)
    yh = p["cou"] + rt * 1.1  # centre de la tête au-dessus de la base du cou
    zt = rt * 0.08 + dos * 0.5
    te.anneaux([
        A((0, -0.02, 0), rc * 1.1, role=PEAU),
        A((0, yh - rt * 0.75, zt * 0.6), rc, role=PEAU),
    ], 8, ferme_bas=False, ferme_haut=False)
    joues = 1.0 + 0.08 * (g - 1.0)
    if p["age"] in ("bebe", "petit"):
        joues *= 1.06
    # Ovale du visage : anneaux horizontaux (menton → crâne).
    menton = 0.55 if p["age"] not in ("bebe", "petit") else 0.75
    te.anneaux([
        A((0, yh - rt * 1.0, zt + rt * 0.12), rt * 0.32 * menton / 0.55 * 0.8, rt * 0.4, rt * 0.3),
        A((0, yh - rt * 0.82, zt + rt * 0.08), rt * 0.62 * joues, rt * 0.82, rt * 0.62),
        A((0, yh - rt * 0.45, zt + rt * 0.02), rt * 0.88 * joues, rt * 0.98, rt * 0.86),
        A((0, yh + rt * 0.05, zt), rt * 0.97, rt * 1.02, rt * 1.0),
        A((0, yh + rt * 0.55, zt - rt * 0.03), rt * 0.85, rt * 0.86, rt * 0.92),
        A((0, yh + rt * 0.92, zt - rt * 0.05), rt * 0.45, rt * 0.45, rt * 0.5),
        A((0, yh + rt * 1.06, zt - rt * 0.06), rt * 0.08, rt * 0.08, rt * 0.08),
    ], 10, phase=0.25)
    # Yeux (blanc + iris), sourcils (cheveux), nez, oreilles.
    ye_y = yh - rt * 0.02
    for s in (1, -1):
        cx = s * rt * 0.36
        # Blanc de l'œil (colonne 1 de la ligne fixe) puis iris (colonne 0).
        te.boite((cx, ye_y, zt + rt * 0.94), (rt * 0.26, rt * 0.17, rt * 0.08), CHEVEUX, FIXE)
        te.boite((cx, ye_y - rt * 0.005, zt + rt * 0.985), (rt * 0.13, rt * 0.15, rt * 0.04), PEAU, FIXE)
        if p["age"] != "bebe":
            te.boite((cx, ye_y + rt * 0.2, zt + rt * 0.9), (rt * 0.3, rt * 0.06, rt * 0.08), CHEVEUX, OMBRE)
        te.boule((s * rt * 0.98, yh - rt * 0.05, zt - rt * 0.05), rt * 0.12, rt * 0.24, rt * 0.16, PEAU, OMBRE, n=6, m=3)
    te.anneaux([
        A((0, yh - rt * 0.2, zt + rt * 0.92), rt * 0.13, rt * 0.08, rt * 0.08, PEAU, OMBRE),
        A((0, yh - rt * 0.38, zt + rt * 1.0), rt * 0.15, rt * 0.14, rt * 0.08, PEAU),
    ], 6)
    # Bouche : un trait plus sombre.
    te.boite((0, yh - rt * 0.6, zt + rt * 0.82), (rt * 0.32, rt * 0.06, rt * 0.08), PEAU, OMBRE)
    tete = te.objet("tete", torse, (0, y_cou - y_taille, 0))
    vide("cheveux", tete, (0, yh, zt), (rt, rt, rt))

    # Bras : du haut (manche courte = rôle haut) à la main (peau).
    lb = (y_epaule - y_hanche) * 0.62 + h * 0.03
    if p["age"] == "bebe":
        lb *= 0.8  # bras courts et potelés
    lab = lb * 0.85
    for cote, suffixe in ((1, "g"), (-1, "d")):
        br = Maille()
        rb = r_bras
        br.anneaux([
            A((0, rb * 1.0, 0), rb * 0.35, role=HAUT),
            A((0, rb * 0.65, 0), rb * 1.0, role=HAUT),
            A((0, 0.0, 0), rb * 1.18, role=HAUT),
            A((0, -lb * 0.3, 0), rb * 1.08, role=HAUT),
            A((0, -lb * 0.42, 0), rb * 1.02, role=MANCHE),
            A((0, -lb - 0.005, 0), rb * 0.86, role=MANCHE),
        ], 8, ferme_haut=False)
        # L'épaule touche le torse ; chez les corps ronds, le bras s'écarte
        # juste assez pour passer à côté des hanches et du ventre.
        # Pose de repos en léger « A » : juste assez pour que la main passe à
        # côté des hanches et du ventre (les corps ronds écartent un peu plus).
        xb = ex * 0.86
        besoin = hx + max(ve, 0) * 0.35 + rb * 0.8 - xb
        inc = math.atan2(max(besoin, 0.0), lb * 0.95) + math.radians(3)
        br.incline(cote * inc)
        bras = br.objet("bras_" + suffixe, torse, (cote * xb, y_epaule - y_taille - rb * 0.9, dos * 0.8))
        ab = Maille()
        ab.anneaux([
            A((0, 0.01, 0), rb * 0.86, role=MANCHE),
            A((0, -lab * 0.45, 0.004), rb * 0.84, role=MANCHE),
            A((0, -lab * 0.92, 0), rb * 0.62, role=MANCHE),
            A((0, -lab, 0), rb * 0.6, role=PEAU),
        ], 8)
        # Main : moufle aplatie, pouce vers l'avant.
        rmn = rb * (0.85 if p["age"] not in ("bebe", "petit") else 1.0)
        ab.anneaux([
            A((0, -lab + 0.005, 0), rmn * 0.55, rmn * 0.8, rmn * 0.8, PEAU),
            A((0, -lab - rmn * 1.0, 0.0), rmn * 0.55, rmn * 1.0, rmn * 0.95, PEAU),
            A((0, -lab - rmn * 1.9, 0.0), rmn * 0.4, rmn * 0.75, rmn * 0.7, PEAU),
        ], 6, phase=0.5)
        ab.boule((cote * -rmn * 0.1, -lab - rmn * 0.7, rmn * 0.75), rmn * 0.25, rmn * 0.5, rmn * 0.25, PEAU, n=5, m=3)
        ab.incline(cote * inc)
        coude = (cote * lb * math.sin(inc), -lb * math.cos(inc), 0)
        ava = ab.objet("avant_bras_" + suffixe, bras, coude)
        lm = lab + rmn * 1.2
        vide("main_" + suffixe, ava, (cote * lm * math.sin(inc), -lm * math.cos(inc), 0))

    # Jupes et robes : origine aux hanches, échelle = demi-largeur et hauteur des hanches.
    vide("habit", bassin, (0, 0, 0), (hx + max(ve, 0) * 0.3, y_hanche, prof + max(ve, 0) * 0.6))
    racine["taille"] = h
    racine["hanche"] = y_hanche
    return racine


# --- Coiffures ----------------------------------------------------------------------
# Modelées autour d'une tête de rayon 1 centrée en 0 (le vide « cheveux » porte
# l'échelle de la tête). Le visage regarde vers +Z (u.z > 0).

def _devant(x, y, z, front=0.32, cote=0.8):
    """Vrai si (x, y, z) est sur le visage (à laisser dégagé)."""
    return z > 0.25 and y < front and abs(x) < cote


def coiffure(nom, rng):
    c = Maille()
    R = CHEVEUX
    if nom == "ras":
        c.boule((0, 0.02, -0.01), 1.04, 1.04, 1.04, R, n=10, m=6,
                garde=lambda x, y, z: y > -0.05 and not _devant(x, y, z, 0.5, 2) and not (abs(x) > 0.85 and y < 0.2))
    elif nom == "court":
        c.boule((0, 0.05, -0.02), 1.08, 1.06, 1.1, R, n=10, m=6,
                garde=lambda x, y, z: y > -0.05 and not _devant(x, y, z, 0.42, 2) and not (abs(x) > 0.8 and y < 0.1 and z > -0.2))
        c.boule((0.1, 0.85, 0.35), 0.55, 0.3, 0.5, R, CLAIR, n=6, m=3)
    elif nom == "raie":
        c.boule((0, 0.06, -0.02), 1.09, 1.08, 1.1, R, n=10, m=6,
                garde=lambda x, y, z: y > -0.15 and not _devant(x, y, z, 0.32, 2) and not (abs(x) > 0.8 and y < 0.0 and z > -0.2))
        c.boule((-0.35, 0.72, 0.62), 0.7, 0.3, 0.42, R, CLAIR, n=6, m=3)
    elif nom == "boucles":
        c.boule((0, 0.1, -0.02), 1.16, 1.12, 1.16, R, n=10, m=6, bosses=0.09, rng=rng,
                garde=lambda x, y, z: y > -0.15 and not _devant(x, y, z, 0.36, 2) and not (abs(x) > 0.8 and y < 0.0 and z > -0.1))
    elif nom == "afro":
        c.boule((0, 0.3, -0.12), 1.48, 1.38, 1.42, R, n=10, m=6, bosses=0.05, rng=rng,
                garde=lambda x, y, z: y > -0.35 and not (z > 0.45 and y < 0.2))
    elif nom == "mi_long":
        c.boule((0, 0.05, -0.04), 1.12, 1.1, 1.14, R, n=10, m=7,
                garde=lambda x, y, z: y > -0.75 and not _devant(x, y, z, 0.3, 0.9))
    elif nom == "long":
        c.boule((0, 0.05, -0.04), 1.12, 1.1, 1.14, R, n=10, m=7,
                garde=lambda x, y, z: y > -0.6 and not _devant(x, y, z, 0.3, 0.9))
        c.anneaux([
            A((0, -0.35, -0.2), 1.0, 0.5, 0.75, R),
            A((0, -1.4, -0.45), 1.05, 0.3, 0.55, R),
            A((0, -2.6, -0.6), 0.9, 0.2, 0.4, R, OMBRE),
        ], 8)
    elif nom == "queue":
        c.boule((0, 0.05, -0.02), 1.07, 1.06, 1.1, R, n=10, m=6,
                garde=lambda x, y, z: y > -0.2 and not _devant(x, y, z, 0.38, 2) and not (abs(x) > 0.8 and y < 0.0 and z > -0.2))
        c.anneaux([
            A((0, 0.35, -1.05), 0.22, role=R, ligne=OMBRE),
            A((0, 0.1, -1.3), 0.3, role=R),
            A((0, -0.8, -1.35), 0.26, role=R),
            A((0, -1.7, -1.2), 0.08, role=R),
        ], 6)
    elif nom == "chignon":
        c.boule((0, 0.05, -0.02), 1.07, 1.06, 1.1, R, n=10, m=6,
                garde=lambda x, y, z: y > -0.2 and not _devant(x, y, z, 0.36, 2) and not (abs(x) > 0.8 and y < 0.0 and z > -0.2))
        c.boule((0, 0.75, -0.75), 0.5, 0.45, 0.5, R, CLAIR, n=8, m=4)
    elif nom == "tresses":
        c.boule((0, 0.03, -0.02), 1.06, 1.05, 1.08, R, n=10, m=6,
                garde=lambda x, y, z: y > -0.3 and not _devant(x, y, z, 0.42, 2))
        for i in range(7):
            a = math.radians(-70 + i * 140 / 6)
            x, z = math.sin(a) * 0.85, -math.cos(a) * 0.85
            longueur = 2.2 + rng.uniform(-0.2, 0.2)
            c.anneaux([
                A((x, -0.1, z), 0.13, role=R),
                A((x * 1.12, -longueur * 0.5, z * 1.15 - 0.1), 0.12, role=R, ligne=OMBRE if i % 2 else NORMAL),
                A((x * 1.15, -longueur, z * 1.2 - 0.15), 0.09, role=R),
            ], 5)
    elif nom == "locks":
        c.boule((0, 0.05, -0.02), 1.1, 1.08, 1.1, R, n=10, m=6, bosses=0.06, rng=rng,
                garde=lambda x, y, z: y > -0.3 and not _devant(x, y, z, 0.38, 2))
        for i in range(11):
            a = math.radians(-115 + i * 230 / 10)
            x, z = math.sin(a) * 0.95, -math.cos(a) * 0.95
            if z > 0.2:
                continue
            longueur = 1.4 + rng.uniform(-0.3, 0.4)
            c.anneaux([
                A((x, 0.1, z), 0.15, role=R),
                A((x * 1.1, -longueur, z * 1.1), 0.12, role=R, ligne=OMBRE if i % 3 == 0 else NORMAL),
            ], 5)
    elif nom == "calvitie":
        c.boule((0, 0.0, -0.02), 1.06, 1.05, 1.08, R, CLAIR, n=10, m=6,
                garde=lambda x, y, z: -0.45 < y < 0.35 and z < 0.3)
    elif nom == "bebe":
        c.boule((0, 0.55, 0.0), 0.7, 0.5, 0.7, R, n=8, m=4, garde=lambda x, y, z: y > 0.1)
        c.boule((0.1, 1.0, 0.2), 0.12, 0.2, 0.12, R, n=5, m=3)
    elif nom == "foulard":
        A_ = ACCESSOIRE
        c.boule((0, 0.03, -0.03), 1.17, 1.15, 1.18, A_, n=10, m=7,
                garde=lambda x, y, z: not (z > 0.2 and -0.85 < y < 0.55 and abs(x) < 0.82))
        c.anneaux([
            A((0, -0.85, -0.1), 1.08, 1.0, 1.05, A_),
            A((0, -1.5, -0.15), 1.45, 1.1, 1.35, A_),
            A((0, -1.95, -0.15), 1.85, 1.3, 1.6, A_, OMBRE),
        ], 10)
    elif nom == "turban":
        A_ = ACCESSOIRE
        c.anneaux([
            A((0, 0.0, -0.08), 1.12, 1.08, 1.2, A_),
            A((0, 0.45, -0.1), 1.25, 1.2, 1.3, A_, OMBRE),
            A((0, 0.8, -0.12), 1.2, 1.12, 1.25, A_),
            A((0, 1.15, -0.1), 0.8, 0.75, 0.85, A_, CLAIR),
            A((0, 1.3, -0.1), 0.3, 0.3, 0.3, A_),
        ], 10)
        c.boule((0, 0.62, 1.1), 0.35, 0.45, 0.2, A_, CLAIR, n=6, m=3)
    elif nom == "casquette":
        A_ = ACCESSOIRE
        c.boule((0, 0.15, -0.02), 1.1, 0.95, 1.12, A_, n=10, m=6, garde=lambda x, y, z: y > 0.0)
        c.anneaux([
            A((0, 0.2, 0.9), 0.75, 0.6, 0.0, A_, OMBRE),
            A((0, 0.22, 0.95), 0.75, 0.6, 0.0, A_, OMBRE),
        ], 8, axe="y")
    else:
        raise ValueError(nom)
    return c


COIFFURES = ["ras", "court", "raie", "boucles", "afro", "mi_long", "long", "queue", "chignon",
             "tresses", "locks", "calvitie", "bebe", "foulard", "turban", "casquette"]


# --- Jupes et robes ------------------------------------------------------------------
# Repère du vide « habit » : origine aux hanches, x et z en demi-largeurs des
# hanches, y en hauteur de hanche (y = −1 : le sol).

def habit(nom):
    c = Maille()
    if nom in ("jupe", "robe"):
        role = BAS if nom == "jupe" else HAUT
        c.anneaux([
            A((0, 0.17, 0), 1.0, 1.0, 1.0, role),
            A((0, -0.1, 0), 1.25, 1.2, 1.15, role),
            A((0, -0.48, 0), 1.6, 1.5, 1.45, role, OMBRE),
            A((0, -0.5, 0), 1.6, 1.5, 1.45, role, OMBRE),
        ], 10, ferme_bas=False, ferme_haut=False)
    elif nom in ("jupe_longue", "robe_longue"):
        role = BAS if nom == "jupe_longue" else HAUT
        c.anneaux([
            A((0, 0.17, 0), 1.0, 1.0, 1.0, role),
            A((0, -0.15, 0), 1.3, 1.25, 1.2, role),
            A((0, -0.6, 0), 1.6, 1.5, 1.45, role),
            A((0, -0.9, 0), 1.8, 1.65, 1.6, role, OMBRE),
            A((0, -0.92, 0), 1.8, 1.65, 1.6, role, OMBRE),
        ], 10, ferme_bas=False, ferme_haut=False)
    else:
        raise ValueError(nom)
    return c


HABITS = ["jupe", "robe", "jupe_longue", "robe_longue"]


# --- Export -------------------------------------------------------------------------

def triangles(objs):
    return sum(sum(len(f.vertices) - 2 for f in o.data.polygons) for o in objs if o.type == "MESH")


def exporte(racine, chemin):
    bpy.ops.object.select_all(action="DESELECT")
    objs = [racine] + list(racine.children_recursive)
    for o in objs:
        o.select_set(True)
    os.makedirs(os.path.dirname(chemin), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=chemin, export_format="GLB", use_selection=True,
        export_apply=True, export_yup=True, export_materials="EXPORT",
        export_image_format="AUTO", export_extras=True,
    )
    return triangles(objs)


def efface(racine):
    for o in [racine] + list(racine.children_recursive):
        bpy.data.objects.remove(o, do_unlink=True)


def seul_objet(nom, maille):
    ob = maille.objet(nom)
    return ob


def apercu(chemin):
    """Aligne quelques corps habillés et coiffés, rendu Workbench (couleurs démo)."""
    scene = bpy.context.scene
    choix = [("bebe", "x", "rond", "bebe", None), ("petit", "x", "moyen", "boucles", None),
             ("enfant", "x", "mince", "queue", "jupe"), ("ado", "h", "mince", "afro", None),
             ("ado", "f", "moyen", "long", None), ("adulte", "h", "mince", "court", None),
             ("adulte", "f", "rond", "foulard", "robe_longue"), ("adulte", "h", "fort", "calvitie", None),
             ("adulte", "f", "mince", "tresses", "robe"), ("adulte", "h", "moyen", "turban", None),
             ("adulte", "f", "fort", "chignon", "jupe"), ("senior", "h", "rond", "ras", None),
             ("senior", "f", "mince", "mi_long", "jupe_longue")]
    rng = random.Random(3)
    x = 0.0
    for age, s, c, coif, hab in choix:
        p = parametres(age, s, c)
        r = construit_corps("apercu_%s_%s_%s" % (age, s, c), p)
        r.location = (x, 0, 0)
        cv = [o for o in r.children_recursive if o.name.startswith("cheveux")][0]
        hv = [o for o in r.children_recursive if o.name.startswith("habit")][0]
        ch = coiffure(coif, rng).objet("c_" + coif, cv)
        if hab:
            habit(hab).objet("h_" + hab, hv)
        x += 0.75
    bpy.context.view_layer.update()
    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = x + 0.4
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    cam.location = (x / 2 - 0.37, -12, 0.95)
    cam.rotation_euler = (math.radians(90), 0, 0)
    if os.environ.get("APERCU_ZOOM"):
        # Gros plan de trois quarts sur les premiers personnages.
        cam_data.type = "PERSP"
        cam_data.lens = 50
        z = float(os.environ["APERCU_ZOOM"])
        cam.location = (z + 0.9, -2.6, 2.1)
        cam.rotation_euler = (math.radians(76), 0, math.radians(18))
    scene.camera = cam
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "TEXTURE"
    scene.display.shading.show_shadows = False
    scene.render.resolution_x = 2000
    scene.render.resolution_y = 560
    scene.render.filepath = os.path.abspath(chemin)
    bpy.ops.render.render(write_still=True)


def lire_options():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    opts = {}
    i = 0
    while i < len(argv):
        if argv[i].startswith("--") and i + 1 < len(argv):
            opts[argv[i][2:]] = argv[i + 1]
            i += 2
        else:
            i += 1
    return opts


def main():
    opts = lire_options()
    dossier = opts.get("dossier", "assets/modeles/personnages")
    seul = opts.get("seul")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if opts.get("apercu"):
        apercu(opts["apercu"])
        return
    rng = random.Random(7)
    total = []
    for age, sexe, corp in VARIANTES:
        nom = "%s_%s_%s" % (age, sexe, corp)
        if seul and nom != seul:
            continue
        r = construit_corps(nom, parametres(age, sexe, corp))
        t = exporte(r, os.path.abspath(os.path.join(dossier, "corps", nom + ".glb")))
        print("CORPS %s : %d triangles, %.2f m" % (nom, t, r["taille"]))
        total.append(t)
        efface(r)
    for nom in COIFFURES:
        if seul and nom != seul:
            continue
        ob = coiffure(nom, rng).objet(nom)
        t = exporte(ob, os.path.abspath(os.path.join(dossier, "cheveux", nom + ".glb")))
        print("COIFFURE %s : %d triangles" % (nom, t))
        efface(ob)
    for nom in HABITS:
        if seul and nom != seul:
            continue
        ob = habit(nom).objet(nom)
        t = exporte(ob, os.path.abspath(os.path.join(dossier, "habits", nom + ".glb")))
        print("HABIT %s : %d triangles" % (nom, t))
        efface(ob)
    img = palette_image()
    img.filepath_raw = os.path.abspath(os.path.join(dossier, "palette_roles.png"))
    img.file_format = "PNG"
    img.save()
    if total:
        print("PERSONNAGES OK : %d corps, de %d à %d triangles" % (len(total), min(total), max(total)))


if __name__ == "__main__":
    main()
