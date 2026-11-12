"""Génère un bâtiment low-poly dans Blender et l'exporte en .glb pour Godot.

Le bâtiment est construit par code (aucun clic dans Blender) à partir d'un
fichier de description JSON : dimensions, toit, ouvertures, couleurs. Toutes
les faces pointent vers une case d'une petite texture « palette » (64 × 64
pixels, 8 × 8 couleurs) : un seul matériau, une seule texture minuscule, des
couleurs franches et des milliers de bâtiments possibles avec la même image.

Usage (ligne de commande, Blender 4.2 ou plus, testé avec 5.2) :

    blender --background --factory-startup --python tools/blender/batiment_lowpoly.py -- \
        --desc tools/blender/exemples/maison_test.json \
        --out assets/modeles/batiments/maison_test.glb \
        [--apercu docs/apercu-glb-maison_test.png] [--blend sortie.blend]

Repères : 1 unité = 1 mètre (une case du jeu). Origine au sol, au centre de
l'emprise. La façade principale (porte) regarde -Y dans Blender, ce qui
donne +Z dans Godot.
"""

import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

# --- Palette ----------------------------------------------------------------
# 8 × 8 cases. Les noms servent dans les fichiers JSON ; une couleur JSON
# « #rrggbb » prend la première case libre.
PALETTE_TAILLE = 8
PIXELS_PAR_CASE = 8
PALETTE_BASE = {
    "enduit": "#f1e6d2",
    "enduit_chaud": "#f2d0a9",
    "pierre": "#b9b0a0",
    "brique": "#a9583f",
    "bois": "#8a6142",
    "bois_sombre": "#5a3e2b",
    "tuile": "#c8553d",
    "ardoise": "#5b5f66",
    "chaume": "#c9a861",
    "vitre": "#33495e",
    "cadre": "#f4f1ea",
    "porte": "#6b4a33",
    "volet": "#4f7a5a",
    "socle": "#8f8a80",
    "beton": "#b9b6ae",
    "metal": "#7d8288",
}


def hex_vers_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


class Palette:
    def __init__(self):
        self.cases = {}  # nom ou "#hex" -> index
        self.couleurs = []
        for nom, hexa in PALETTE_BASE.items():
            self.ajoute(nom, hexa)

    def ajoute(self, cle, hexa):
        if cle in self.cases:
            return self.cases[cle]
        if len(self.couleurs) >= PALETTE_TAILLE * PALETTE_TAILLE:
            raise ValueError("Palette pleine (64 couleurs)")
        self.cases[cle] = len(self.couleurs)
        self.couleurs.append(hex_vers_rgb(hexa))
        return self.cases[cle]

    def index(self, couleur):
        """Nom de la palette ou « #rrggbb »."""
        if couleur in self.cases:
            return self.cases[couleur]
        if couleur.startswith("#"):
            return self.ajoute(couleur, couleur)
        raise KeyError("Couleur inconnue : " + couleur)

    def uv(self, idx):
        """Centre de la case idx (V vers le haut, comme dans Blender)."""
        col = idx % PALETTE_TAILLE
        lig = idx // PALETTE_TAILLE
        return ((col + 0.5) / PALETTE_TAILLE, 1.0 - (lig + 0.5) / PALETTE_TAILLE)

    def image(self, nom):
        cote = PALETTE_TAILLE * PIXELS_PAR_CASE
        img = bpy.data.images.new(nom, cote, cote, alpha=False)
        px = [0.0] * (cote * cote * 4)
        for i, (r, g, b) in enumerate(self.couleurs):
            col = i % PALETTE_TAILLE
            lig = i // PALETTE_TAILLE
            for dy in range(PIXELS_PAR_CASE):
                # Les pixels Blender commencent en bas à gauche.
                y = cote - 1 - (lig * PIXELS_PAR_CASE + dy)
                for dx in range(PIXELS_PAR_CASE):
                    x = col * PIXELS_PAR_CASE + dx
                    o = (y * cote + x) * 4
                    px[o:o + 4] = [r, g, b, 1.0]
        img.pixels = px
        img.pack()
        return img


# --- Construction -------------------------------------------------------------
# Matériaux : 0 = palette (presque tout), 1 = vitrage à petits carreaux,
# 2 = grille ajourée (garde-corps, treillage), 3 = panneaux solaires ;
# textures de 32 × 32 px répétées.
MAT_PALETTE, MAT_CARREAUX, MAT_GRILLE, MAT_SOLAIRE = 0, 1, 2, 3


def arc(cx, cy, r, a0, a1, n):
    """Points d'un arc (angles en degrés), n segments pour un tour complet."""
    segs = max(1, int(round(n * abs(a1 - a0) / 360.0)))
    return [(cx + r * math.cos(math.radians(a0 + (a1 - a0) * i / segs)),
             cy + r * math.sin(math.radians(a0 + (a1 - a0) * i / segs)))
            for i in range(segs + 1)]


class Batisseur:
    """Accumule des faces colorées dans un seul bmesh."""

    def __init__(self, palette):
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")
        self.palette = palette

    def face(self, pts, couleur, lisse=False):
        verts = [self.bm.verts.new(p) for p in pts]
        f = self.bm.faces.new(verts)
        f.smooth = lisse
        f.material_index = MAT_PALETTE
        u, v = self.palette.uv(self.palette.index(couleur))
        for loop in f.loops:
            loop[self.uv].uv = (u, v)
        return f

    def quad_motif(self, pts, mat, ru, rv):
        """Quadrilatère avec une texture répétée ru × rv fois (carreaux, grille)."""
        verts = [self.bm.verts.new(p) for p in pts]
        f = self.bm.faces.new(verts)
        f.smooth = False
        f.material_index = mat
        for loop, uv in zip(f.loops, [(0, 0), (ru, 0), (ru, rv), (0, rv)]):
            loop[self.uv].uv = uv
        return f

    def face_orientee(self, pts, couleur, vers, mat=None, echelle=None):
        """Face dont la normale est retournée si besoin pour pointer vers
        `vers` (vecteur). Avec mat et echelle : texture projetée en coordonnées
        du monde (u = x / échelle_u, v = y ou z / échelle_v selon la face)."""
        a, b, c = (Vector(p) for p in pts[:3])
        n = (b - a).cross(c - a)
        if n.dot(Vector(vers)) < 0:
            pts = list(reversed(pts))
        if mat is None:
            return self.face(pts, couleur)
        verts = [self.bm.verts.new(p) for p in pts]
        f = self.bm.faces.new(verts)
        f.smooth = False
        f.material_index = mat
        su, sv = echelle
        horizontale = abs(n.normalized().z) > 0.7
        for loop, p in zip(f.loops, pts):
            if horizontale:
                loop[self.uv].uv = (p[0] / su, p[1] / sv)
            else:
                # Mur : u le long du mur (x ou y selon l'orientation), v = hauteur.
                u = p[0] if abs(n.x) < abs(n.y) else p[1]
                loop[self.uv].uv = (u / su, p[2] / sv)
        return f

    def cylindre(self, cx, cy, z0, z1, r, couleur, n=16, a0=0.0, a1=360.0,
                 dessus=True, couleur_dessus=None):
        """Cylindre (ou portion entre les angles a0 et a1, en degrés ; 0 = +X,
        -90 = façade avant). Côtés lisses, dessus plat."""
        pts = arc(cx, cy, r, a0, a1, n)
        plein = abs(a1 - a0) >= 360.0
        if plein:
            pts = pts[:-1]
        m = len(pts) if plein else len(pts) - 1
        for i in range(m):
            (xa, ya), (xb, yb) = pts[i], pts[(i + 1) % len(pts)]
            self.face([(xa, ya, z0), (xb, yb, z0), (xb, yb, z1), (xa, ya, z1)], couleur, lisse=True)
        if dessus:
            poly = pts if plein else [(cx, cy)] + pts
            self.face([(x, y, z1) for x, y in poly], couleur_dessus or couleur)

    def bande_arc(self, cx, cy, r, z0, z1, a0, a1, n, mat, maille_u, maille_v):
        """Bande verticale courbe texturée (vitrage à carreaux, garde-corps)."""
        pts = arc(cx, cy, r, a0, a1, n)
        for (xa, ya), (xb, yb) in zip(pts, pts[1:]):
            lg = math.hypot(xb - xa, yb - ya)
            self.quad_motif([(xa, ya, z0), (xb, yb, z0), (xb, yb, z1), (xa, ya, z1)],
                            mat, lg / maille_u, (z1 - z0) / maille_v)

    def bande_ligne(self, points, z0, z1, mat, maille_u, maille_v):
        """Bande verticale le long d'une ligne brisée [(x, y), …]."""
        for (xa, ya), (xb, yb) in zip(points, points[1:]):
            lg = math.hypot(xb - xa, yb - ya)
            self.quad_motif([(xa, ya, z0), (xb, yb, z0), (xb, yb, z1), (xa, ya, z1)],
                            mat, lg / maille_u, (z1 - z0) / maille_v)

    def vitrage(self, centre, normale, largeur, hauteur, cols, lignes):
        """Fenêtre à petits carreaux posée sur un mur droit (normale ±X ou ±Y)."""
        cx, cy, cz = centre
        nx, ny = normale
        l, h = largeur / 2.0, hauteur / 2.0
        cx, cy = cx + nx * 0.03, cy + ny * 0.03
        if ny != 0:
            s = 1 if ny < 0 else -1
            pts = [(cx - s * l, cy, cz - h), (cx + s * l, cy, cz - h),
                   (cx + s * l, cy, cz + h), (cx - s * l, cy, cz + h)]
        else:
            s = 1 if nx > 0 else -1
            pts = [(cx, cy - s * l, cz - h), (cx, cy + s * l, cz - h),
                   (cx, cy + s * l, cz + h), (cx, cy - s * l, cz + h)]
        self.quad_motif(pts, MAT_CARREAUX, cols, lignes)

    def boite(self, centre, taille, couleur, dessous=False, couleur_dessus=None):
        cx, cy, cz = centre
        sx, sy, sz = (t / 2.0 for t in taille)
        x0, x1, y0, y1 = cx - sx, cx + sx, cy - sy, cy + sy
        z0, z1 = cz - sz, cz + sz
        c = couleur
        self.face([(x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1)], c)  # -Y
        self.face([(x1, y1, z0), (x0, y1, z0), (x0, y1, z1), (x1, y1, z1)], c)  # +Y
        self.face([(x0, y1, z0), (x0, y0, z0), (x0, y0, z1), (x0, y1, z1)], c)  # -X
        self.face([(x1, y0, z0), (x1, y1, z0), (x1, y1, z1), (x1, y0, z1)], c)  # +X
        self.face([(x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)], couleur_dessus or c)
        if dessous:
            self.face([(x0, y1, z0), (x1, y1, z0), (x1, y0, z0), (x0, y0, z0)], c)

    def plaque(self, centre, normale, largeur, hauteur, couleur):
        """Rectangle vertical collé à un mur, normale = ±X ou ±Y."""
        cx, cy, cz = centre
        l, h = largeur / 2.0, hauteur / 2.0
        nx, ny = normale
        if ny != 0:
            s = 1 if ny < 0 else -1
            pts = [(cx - s * l, cy, cz - h), (cx + s * l, cy, cz - h),
                   (cx + s * l, cy, cz + h), (cx - s * l, cy, cz + h)]
        else:
            s = 1 if nx > 0 else -1
            pts = [(cx, cy - s * l, cz - h), (cx, cy + s * l, cz - h),
                   (cx, cy + s * l, cz + h), (cx, cy - s * l, cz + h)]
        self.face(pts, couleur)

    def fenetre(self, centre, normale, largeur, hauteur, d):
        """Cadre clair légèrement saillant puis vitre sombre devant."""
        cx, cy, cz = centre
        nx, ny = normale
        self.plaque((cx + nx * 0.02, cy + ny * 0.02, cz), normale,
                    largeur + 0.16, hauteur + 0.16, d.get("cadre", "cadre"))
        self.plaque((cx + nx * 0.03, cy + ny * 0.03, cz), normale,
                    largeur, hauteur, d.get("vitre", "vitre"))
        if d.get("volets"):
            for cote in (-1, 1):
                off = cote * (largeur / 2 + 0.08 + largeur / 4)
                if ny != 0:
                    p = (cx + off, cy + ny * 0.025, cz)
                else:
                    p = (cx + nx * 0.025, cy + off, cz)
                self.plaque(p, normale, largeur / 2, hauteur + 0.1, d["volets"])


def construit(d, palette, b=None):
    b = b or Batisseur(palette)
    L = float(d.get("largeur", 8.0))       # le long de X (façade)
    P = float(d.get("profondeur", 6.0))    # le long de Y
    etages = int(d.get("etages", 2))
    he = float(d.get("hauteur_etage", 2.8))
    socle_h = float(d.get("socle", 0.3))
    H = socle_h + etages * he
    mur = d.get("mur", "enduit")

    # Socle un peu plus large que les murs.
    if socle_h > 0:
        b.boite((0, 0, socle_h / 2), (L + 0.2, P + 0.2, socle_h), d.get("couleur_socle", "socle"))
    # Corps du bâtiment (sans dessus si toit à pans : le toit le couvre).
    toit = d.get("toit", {"forme": "deux_pans"})
    forme = toit.get("forme", "deux_pans")
    b.boite((0, 0, socle_h + (H - socle_h) / 2), (L, P, H - socle_h), mur)

    # Toit.
    deb = float(toit.get("debord", 0.4))
    ep = float(toit.get("epaisseur", 0.15))
    ct = toit.get("couleur", "tuile")
    if forme == "deux_pans":
        pente = math.radians(float(toit.get("pente", 40)))
        demi = P / 2 + deb
        faite = H + (P / 2) * math.tan(pente)
        x0, x1 = -L / 2 - deb, L / 2 + deb
        z_bord = faite - demi * math.tan(pente)
        for s in (-1, 1):
            # Dessus du pan, puis tranche d'épaisseur au bas du pan.
            yb = s * demi
            haut = [(x0, 0, faite + ep), (x1, 0, faite + ep)]
            bas = [(x1, yb, z_bord + ep), (x0, yb, z_bord + ep)]
            pts = [bas[1], bas[0], haut[1], haut[0]] if s < 0 else [bas[0], bas[1], haut[0], haut[1]]
            b.face(pts, ct)
            dessous = [(x0, yb, z_bord), (x1, yb, z_bord), (x1, 0, faite), (x0, 0, faite)]
            b.face(dessous if s > 0 else list(reversed(dessous)), d.get("sous_toit", "bois_sombre"))
            tranche = [(x0, yb, z_bord), (x1, yb, z_bord), (x1, yb, z_bord + ep), (x0, yb, z_bord + ep)]
            b.face(tranche if s < 0 else list(reversed(tranche)), ct)
        # Pignons (triangles de mur) et rives du toit.
        for sx in (-1, 1):
            x = sx * L / 2
            tri = [(x, -P / 2, H), (x, P / 2, H), (x, 0, faite)]
            b.face(tri if sx > 0 else list(reversed(tri)), d.get("pignon", mur))
            xr = sx * (L / 2 + deb)
            rive = [(xr, -demi, z_bord), (xr, 0, faite), (xr, demi, z_bord),
                    (xr, demi, z_bord + ep), (xr, 0, faite + ep), (xr, -demi, z_bord + ep)]
            b.face(rive if sx < 0 else list(reversed(rive)), ct)
    elif forme == "plat":
        b.boite((0, 0, H + ep / 2), (L + 2 * deb, P + 2 * deb, ep), ct)
        faite = H + ep
    else:
        raise ValueError("Forme de toit inconnue : " + forme)

    # Cheminée.
    ch = d.get("cheminee")
    if ch:
        cx = float(ch.get("x", L * 0.3))
        cy = float(ch.get("y", P * 0.2))
        haut = faite + float(ch.get("depasse", 0.8))
        b.boite((cx, cy, (H + haut) / 2), (0.6, 0.6, haut - H), ch.get("couleur", "brique"))

    # Ouvertures : fenêtres régulières par étage sur chaque façade.
    fen = d.get("fenetres", {})
    fl = float(fen.get("largeur", 0.9))
    fh = float(fen.get("hauteur", 1.2))
    par_facade = fen.get("par_facade", {"avant": 3, "arriere": 3, "gauche": 2, "droite": 2})
    porte = d.get("porte", {"largeur": 1.0, "hauteur": 2.1, "couleur": "porte"})
    facades = {
        "avant": ((0, -P / 2), (0, -1), L),
        "arriere": ((0, P / 2), (0, 1), L),
        "gauche": ((-L / 2, 0), (-1, 0), P),
        "droite": ((L / 2, 0), (1, 0), P),
    }
    for nom, ((fx, fy), n, longueur) in facades.items():
        nb = int(par_facade.get(nom, 0))
        if nb <= 0:
            continue
        pas = longueur / nb
        for e in range(etages):
            zc = socle_h + e * he + he * 0.55
            for i in range(nb):
                t = -longueur / 2 + pas * (i + 0.5)
                cx, cy = (fx + t, fy) if n[1] != 0 else (fx, fy + t)
                if nom == "avant" and e == 0 and i == nb // 2 and porte:
                    pl, ph = float(porte["largeur"]), float(porte["hauteur"])
                    b.plaque((cx, cy - 0.02, socle_h + ph / 2), n, pl + 0.16, ph + 0.08, fen.get("cadre", "cadre"))
                    b.plaque((cx, cy - 0.03, socle_h + ph / 2), n, pl, ph, porte.get("couleur", "porte"))
                    continue
                b.fenetre((cx, cy, zc), n, fl, fh, fen)
    return b.bm


def _texture_motif(nom, fonction, alpha=False, taille=32):
    """Petite image procédurale : fonction(x, y) -> (r, g, b, a), y vers le haut."""
    img = bpy.data.images.new(nom, taille, taille, alpha=alpha)
    px = [0.0] * (taille * taille * 4)
    for y in range(taille):
        for x in range(taille):
            o = (y * taille + x) * 4
            px[o:o + 4] = fonction(x, y, taille)
    img.pixels = px
    img.pack()
    return img


def _carreaux(x, y, t):
    """Vitrage : petit bois clair sur le bord de chaque carreau, vitre sombre."""
    bord = 2
    if x < bord or x >= t - bord or y < bord or y >= t - bord:
        return [0.93, 0.92, 0.89, 1.0]
    k = 0.10 + 0.06 * (y / t)  # léger reflet du ciel vers le haut
    return [k, k * 1.25, k * 1.5, 1.0]


def _grille(x, y, t):
    """Grille ajourée : barreaux blancs sur les bords, presque transparent au
    centre (un léger voile garde la grille lisible de loin, une fois réduite)."""
    bord = 3
    if x < bord or x >= t - bord or y < bord or y >= t - bord:
        return [0.95, 0.95, 0.93, 1.0]
    return [0.95, 0.95, 0.93, 0.12]


def _solaire(x, y, t):
    """Panneau solaire : cellules bleu nuit, joints gris fins."""
    if x == 0 or y == 0:
        return [0.42, 0.44, 0.47, 1.0]
    if x % 8 == 0 or y % 16 == 0:
        return [0.12, 0.16, 0.24, 1.0]
    k = 0.07 + 0.03 * (y / t)
    return [k, k * 1.3, k * 2.0, 1.0]


def _materiau_texture(nom, image, closest, transparent=False, rugosite=0.9):
    mat = bpy.data.materials.new(nom)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = rugosite
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = image
    tex.interpolation = "Closest" if closest else "Linear"
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    if transparent:
        # Alpha progressif (alphaMode BLEND) : les barreaux fins restent
        # visibles de loin au lieu de disparaître comme avec un seuil.
        nt.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
        mat.use_backface_culling = False
    return mat


def materiaux(palette, nom):
    """Les matériaux, dans l'ordre MAT_PALETTE, MAT_CARREAUX, MAT_GRILLE, MAT_SOLAIRE.
    Seuls ceux réellement utilisés par des faces sont exportés."""
    return [
        _materiau_texture(nom, palette.image(nom + "_palette"), closest=True),
        _materiau_texture(nom + "_carreaux", _texture_motif(nom + "_carreaux_tex", _carreaux),
                          closest=False, rugosite=0.25),
        _materiau_texture(nom + "_grille", _texture_motif(nom + "_grille_tex", _grille, alpha=True),
                          closest=False, transparent=True),
        _materiau_texture(nom + "_solaire", _texture_motif(nom + "_solaire_tex", _solaire),
                          closest=False, rugosite=0.3),
    ]


def apercu(obj, chemin, azimut=-37.0, hauteur=0.55):
    """Petite image Workbench (rapide) pour vérifier. azimut en degrés depuis -Y."""
    scene = bpy.context.scene
    dims = obj.dimensions
    r = max(dims.x, dims.y, dims.z) * 1.9
    cam_data = bpy.data.cameras.new("cam")
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    cible = Vector((0, 0, dims.z * 0.45))
    a = math.radians(azimut)
    pos = Vector((-r * math.sin(a), -r * math.cos(a), r * hauteur))
    cam.location = pos
    cam.rotation_euler = (cible - pos).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "TEXTURE"
    scene.display.shading.show_shadows = True
    scene.render.resolution_x = 1000
    scene.render.resolution_y = 750
    scene.render.film_transparent = False
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


def exporte(batisseur, nom, opts):
    """Transforme le bmesh en objet, exporte le .glb (opts["out"]) et, si
    demandé, un .blend (opts["blend"]) et des aperçus (opts["apercu"], un
    chemin ; opts["azimuts"], ex. "-37,20" pour plusieurs vues)."""
    bm = batisseur.bm
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    mesh = bpy.data.meshes.new(nom)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(nom, mesh)
    bpy.context.scene.collection.objects.link(obj)
    for m in materiaux(batisseur.palette, nom):
        mesh.materials.append(m)

    tris = sum(len(p.vertices) - 2 for p in mesh.polygons)
    print("BATIMENT %s : %d faces, %d triangles, %.1f x %.1f x %.1f m" % (
        nom, len(mesh.polygons), tris, obj.dimensions.x, obj.dimensions.y, obj.dimensions.z))

    out = os.path.abspath(opts["out"])
    os.makedirs(os.path.dirname(out), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=out, export_format="GLB", use_selection=True,
        export_apply=True, export_yup=True, export_materials="EXPORT",
        export_image_format="AUTO",
    )
    print("EXPORT OK", out)
    if "blend" in opts:
        bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(opts["blend"]))
    if "apercu" in opts:
        azimuts = [float(a) for a in opts.get("azimuts", "-37").split(",")]
        base, ext = os.path.splitext(opts["apercu"])
        for k, az in enumerate(azimuts):
            chemin = opts["apercu"] if k == 0 else "%s_%d%s" % (base, k, ext)
            apercu(obj, chemin, az)
            print("APERCU OK", chemin)
    return obj


def main():
    opts = lire_options()
    with open(opts["desc"], encoding="utf-8") as f:
        d = json.load(f)
    nom = d.get("nom", os.path.splitext(os.path.basename(opts["out"]))[0])
    bpy.ops.wm.read_factory_settings(use_empty=True)
    b = Batisseur(Palette())
    b.bm = construit(d, b.palette, b)
    exporte(b, nom, opts)


if __name__ == "__main__":
    main()
