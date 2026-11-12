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
class Batisseur:
    """Accumule des faces colorées dans un seul bmesh."""

    def __init__(self, palette):
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")
        self.palette = palette

    def face(self, pts, couleur):
        verts = [self.bm.verts.new(p) for p in pts]
        f = self.bm.faces.new(verts)
        f.smooth = False
        u, v = self.palette.uv(self.palette.index(couleur))
        for loop in f.loops:
            loop[self.uv].uv = (u, v)
        return f

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


def construit(d, palette):
    b = Batisseur(palette)
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


def materiau(palette, nom):
    mat = bpy.data.materials.new(nom)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = 0.9
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = palette.image(nom + "_palette")
    tex.interpolation = "Closest"
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    return mat


def apercu(obj, chemin):
    """Petite image Workbench (rapide, sans GPU spécial) pour vérifier."""
    scene = bpy.context.scene
    dims = obj.dimensions
    r = max(dims.x, dims.y, dims.z) * 1.9
    cam_data = bpy.data.cameras.new("cam")
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    cible = Vector((0, 0, dims.z * 0.45))
    pos = Vector((r * 0.75, -r, r * 0.55))
    cam.location = pos
    cam.rotation_euler = (cible - pos).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "TEXTURE"
    scene.display.shading.show_shadows = True
    scene.render.resolution_x = 800
    scene.render.resolution_y = 600
    scene.render.film_transparent = False
    scene.render.filepath = os.path.abspath(chemin)
    bpy.ops.render.render(write_still=True)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    opts = {}
    i = 0
    while i < len(argv):
        if argv[i].startswith("--") and i + 1 < len(argv):
            opts[argv[i][2:]] = argv[i + 1]
            i += 2
        else:
            i += 1
    with open(opts["desc"], encoding="utf-8") as f:
        d = json.load(f)
    nom = d.get("nom", os.path.splitext(os.path.basename(opts["out"]))[0])

    bpy.ops.wm.read_factory_settings(use_empty=True)
    palette = Palette()
    bm = construit(d, palette)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    mesh = bpy.data.meshes.new(nom)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(nom, mesh)
    bpy.context.scene.collection.objects.link(obj)
    mesh.materials.append(materiau(palette, nom))

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
        apercu(obj, opts["apercu"])
        print("APERCU OK", opts["apercu"])


main()
