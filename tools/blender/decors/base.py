"""Outils communs des décors low-poly : palette, solides, export.

Chaque décor est un seul maillage, faces plates, une couleur de la palette par
face (comme les plantes). Les solides (boîtes, cylindres, boules…) sont
construits avec les opérateurs bmesh puis recopiés : leurs normales sont
recalculées vers l'extérieur, le rendu est juste même vu de près.

Repères : 1 unité = 1 m, Z vers le haut (Y dans Godot), origine au pied de
l'objet, au centre. L'avant d'un objet (l'assise d'un banc, la face d'un
panneau, la tête d'un animal) regarde vers -Y dans Blender, donc vers +Z dans
Godot.
"""

import math
import random

import bpy  # avant bmesh (nécessaire avec le module « bpy » de pip)
import bmesh
from mathutils import Matrix, Vector

# --- Palette commune à tous les décors (64 couleurs au plus) -----------------
# L'ordre compte : il fixe la case de chaque couleur, la même dans tous les .glb.
PALETTE = [
    # Bois, métal, pierre
    ("bois", "#8a5a36"), ("bois_clair", "#b8895a"), ("bois_sombre", "#5a3a24"), ("bois_gris", "#9a9184"),
    ("fonte", "#2f3b33"), ("metal", "#8a9096"), ("metal_sombre", "#4a4f55"), ("galva", "#b8bcc0"),
    ("noir", "#26282b"), ("blanc", "#eeeae0"), ("beton", "#b5b0a5"), ("beton_sombre", "#86827a"),
    ("pierre", "#c9c1ae"), ("pierre_sombre", "#958c7a"), ("brique", "#a8553a"), ("tuile", "#b5583a"),
    # Couleurs vives (peintures, panneaux, tissus)
    ("vert_fonte", "#2f5a3e"), ("vert", "#3f9a4a"), ("rouge", "#c8322a"), ("rouge_sombre", "#8a2a22"),
    ("jaune", "#e8c032"), ("orange", "#e07a2a"), ("bleu", "#2f5fa8"), ("bleu_ciel", "#7ab0d8"),
    ("vitre", "#9cc4d4"), ("eau", "#4a90b8"), ("bronze", "#6b5a3a"), ("bronze_vert", "#5f8a76"),
    ("or", "#d4aa3a"), ("rose", "#e8a0a8"), ("violet", "#7a4a9a"), ("tissu_blanc", "#f2ece0"),
    # Sol, plantes, ferme
    ("sable", "#e0cf9e"), ("terre", "#6a5038"), ("herbe", "#6aa040"), ("feuillage", "#3f7232"),
    ("foin", "#d8b85a"), ("foin_sombre", "#b0903e"), ("paille", "#e8d488"), ("film", "#e9ece8"),
    ("citrouille", "#e0782a"), ("fruit_rouge", "#c8302a"), ("chou", "#7aa86a"), ("caoutchouc", "#2a2a2c"),
    # Animaux
    ("pelage_blanc", "#f2efe6"), ("pelage_noir", "#2a2826"), ("pelage_roux", "#9a4e2a"), ("pelage_creme", "#e6d8b8"),
    ("museau", "#d89a8a"), ("laine", "#ece6d6"), ("cheval_bai", "#7a4626"), ("gris_ane", "#8e8680"),
    ("cochon", "#eab0a4"), ("corne", "#e6dcc4"), ("sabot", "#3a3430"), ("bec", "#e8a030"),
    # Roches et lumières
    ("roche", "#8e8a82"), ("roche_claire", "#aaa69c"), ("roche_sombre", "#6a665f"), ("mousse", "#6a8a4a"),
    ("lumiere", "#fff1c8"), ("lumiere_chaude", "#ffc870"), ("feu_rouge", "#ff3a2a"), ("feu_vert", "#3aff7a"),
]
assert len(PALETTE) <= 64, len(PALETTE)

# Couleurs qui brillent la nuit (palette_decors_lumiere.png, lue par le jeu).
LUMIERES = {"lumiere": 1.0, "lumiere_chaude": 1.0, "feu_rouge": 0.8, "feu_vert": 0.8}


class Palette:
    """Même découpage que les plantes et les bâtiments (8 × 8 cases)."""
    TAILLE = 8
    PIXELS = 8

    def __init__(self):
        self.cases = {}
        self.couleurs = []
        for nom, hexa in PALETTE:
            h = hexa.lstrip("#")
            self.cases[nom] = len(self.couleurs)
            self.couleurs.append(tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)))

    def uv(self, nom):
        i = self.cases[nom]
        col, lig = i % self.TAILLE, i // self.TAILLE
        return ((col + 0.5) / self.TAILLE, 1.0 - (lig + 0.5) / self.TAILLE)

    def image(self, nom, valeurs=None):
        """Image de la palette ; avec valeurs (nom -> 0..1), une image en niveaux de gris."""
        cote = self.TAILLE * self.PIXELS
        img = bpy.data.images.new(nom, cote, cote, alpha=False)
        px = [0.0] * (cote * cote * 4)
        noms = [n for n, _h in PALETTE]
        for i, rgb in enumerate(self.couleurs):
            if valeurs is not None:
                v = valeurs.get(noms[i], 0.0)
                rgb = (v * rgb[0], v * rgb[1], v * rgb[2])
            col, lig = i % self.TAILLE, i // self.TAILLE
            for dy in range(self.PIXELS):
                y = cote - 1 - (lig * self.PIXELS + dy)
                for dx in range(self.PIXELS):
                    o = (y * cote + col * self.PIXELS + dx) * 4
                    px[o:o + 4] = [rgb[0], rgb[1], rgb[2], 1.0]
        img.pixels = px
        return img


def V(x, y=0.0, z=0.0):
    return Vector((x, y, z))


class Decor:
    """Accumule des solides colorés dans un bmesh."""

    def __init__(self, palette, graine):
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")
        self.palette = palette
        self.rng = random.Random(graine)

    # -- Bas niveau --------------------------------------------------------------
    def _colle(self, tmp, couleur, recalc=True):
        """Recopie le bmesh tmp (déjà placé) ; couleur : nom ou fonction(normale, centre)."""
        if recalc:
            bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces[:])
        tmp.normal_update()
        vmap = {v: self.bm.verts.new(v.co) for v in tmp.verts}
        for f in tmp.faces:
            nf = self.bm.faces.new([vmap[v] for v in f.verts])
            nf.smooth = False
            c = couleur if isinstance(couleur, str) else couleur(f.normal, f.calc_center_median())
            u, v = self.palette.uv(c)
            for loop in nf.loops:
                loop[self.uv].uv = (u, v)
        tmp.free()

    def face(self, pts, couleur):
        """Polygone plat (voiles, toiles, feuilles) : vu des deux côtés dans le jeu."""
        verts = [self.bm.verts.new(Vector(p)) for p in pts]
        f = self.bm.faces.new(verts)
        f.smooth = False
        u, v = self.palette.uv(couleur)
        for loop in f.loops:
            loop[self.uv].uv = (u, v)
        return f

    # -- Solides -----------------------------------------------------------------
    def boite(self, c, taille, couleur, rz=0.0, dessus=None, rx=0.0, ry=0.0):
        """Boîte posée : c = centre de sa face du bas, taille = (x, y, z), rz en degrés.
        dessus : couleur de la face du haut."""
        tmp = bmesh.new()
        bmesh.ops.create_cube(tmp, size=1.0)
        sx, sy, sz = taille
        m = (Matrix.Translation(Vector(c)) @ Matrix.Rotation(math.radians(rz), 4, "Z")
             @ Matrix.Rotation(math.radians(ry), 4, "Y") @ Matrix.Rotation(math.radians(rx), 4, "X")
             @ Matrix.Translation((0, 0, sz / 2)) @ Matrix.Diagonal((sx, sy, sz, 1)))
        bmesh.ops.transform(tmp, matrix=m, verts=tmp.verts)
        if dessus:
            self._colle(tmp, lambda n, _c: dessus if n.z > 0.7 else couleur)
        else:
            self._colle(tmp, couleur)

    def cyl(self, c, r, h, couleur, n=8, r2=None, rz=0.0, dessus=None, rx=0.0, ry=0.0):
        """Cylindre (ou tronc de cône si r2) posé sur c, axe Z. rx/ry l'inclinent."""
        tmp = bmesh.new()
        r2 = r if r2 is None else r2
        bmesh.ops.create_cone(tmp, cap_ends=True, cap_tris=False, segments=n,
                              radius1=r, radius2=max(r2, 1e-4), depth=h)
        m = (Matrix.Translation(Vector(c)) @ Matrix.Rotation(math.radians(rz), 4, "Z")
             @ Matrix.Rotation(math.radians(ry), 4, "Y") @ Matrix.Rotation(math.radians(rx), 4, "X")
             @ Matrix.Translation((0, 0, h / 2)))
        bmesh.ops.transform(tmp, matrix=m, verts=tmp.verts)
        if r2 < 1e-3:
            bmesh.ops.remove_doubles(tmp, verts=tmp.verts[:], dist=1e-3)
        if dessus:
            self._colle(tmp, lambda nn, _c: dessus if nn.z > 0.7 else couleur)
        else:
            self._colle(tmp, couleur)

    def cone(self, c, r, h, couleur, n=8):
        self.cyl(c, r, h, couleur, n=n, r2=0.0)

    def tube(self, a, b, r, couleur, n=6, r2=None):
        """Cylindre entre deux points (barreaux, pieds inclinés, mâts)."""
        a, b = Vector(a), Vector(b)
        d = b - a
        L = d.length
        if L < 1e-5:
            return
        tmp = bmesh.new()
        r2 = r if r2 is None else r2
        bmesh.ops.create_cone(tmp, cap_ends=True, cap_tris=False, segments=n,
                              radius1=r, radius2=max(r2, 1e-4), depth=L)
        q = Vector((0, 0, 1)).rotation_difference(d.normalized())
        m = Matrix.Translation(a) @ q.to_matrix().to_4x4() @ Matrix.Translation((0, 0, L / 2))
        bmesh.ops.transform(tmp, matrix=m, verts=tmp.verts)
        self._colle(tmp, couleur)

    def poutre(self, a, b, larg, ep, couleur, haut=Vector((0, 0, 1))):
        """Planche ou poutre de section larg × ep entre a et b (larg à l'horizontale)."""
        a, b = Vector(a), Vector(b)
        d = b - a
        L = d.length
        if L < 1e-5:
            return
        x = d.normalized()
        y = Vector(haut).cross(x)
        if y.length < 1e-4:
            y = Vector((0, 1, 0)).cross(x)
        y.normalize()
        z = x.cross(y)
        tmp = bmesh.new()
        bmesh.ops.create_cube(tmp, size=1.0)
        rot = Matrix((x, y, z)).transposed().to_4x4()
        m = Matrix.Translation((a + b) / 2) @ rot @ Matrix.Diagonal((L, larg, ep, 1))
        bmesh.ops.transform(tmp, matrix=m, verts=tmp.verts)
        self._colle(tmp, couleur)

    def boule(self, c, rx, ry, rz, couleur, subdiv=1, alea=0.15, aplatir_bas=0.0, graine=None):
        """Icosphère déformée (feuillage, laine, rochers, foin)."""
        tmp = bmesh.new()
        bmesh.ops.create_icosphere(tmp, subdivisions=subdiv, radius=1.0)
        r = random.Random(self.rng.random() if graine is None else graine)
        for v in tmp.verts:
            k = 1.0 + (r.random() * 2 - 1) * alea
            p = v.co
            z = p.z * (1.0 - aplatir_bas) if p.z < 0 else p.z
            v.co = Vector(c) + Vector((p.x * rx * k, p.y * ry * k, z * rz * k))
        self._colle(tmp, couleur)

    def profil(self, pts, y0, y1, couleur, rz=0.0, origine=(0, 0, 0), cotes=None):
        """Prisme : profil (x, z) dans le plan XZ, extrudé de y0 à y1, puis tourné
        de rz autour de Z et déplacé à origine. cotes : couleur des deux bouts."""
        tmp = bmesh.new()
        av = [tmp.verts.new((x, y0, z)) for x, z in pts]
        ar = [tmp.verts.new((x, y1, z)) for x, z in pts]
        n = len(pts)
        for i in range(n):
            j = (i + 1) % n
            tmp.faces.new([av[i], av[j], ar[j], ar[i]])
        f1 = tmp.faces.new(av)
        f2 = tmp.faces.new(list(reversed(ar)))
        m = Matrix.Translation(Vector(origine)) @ Matrix.Rotation(math.radians(rz), 4, "Z")
        bmesh.ops.transform(tmp, matrix=m, verts=tmp.verts)
        if cotes:
            bouts = {f1, f2}
            bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces[:])
            tmp.normal_update()
            cols = {f: (cotes if f in bouts else couleur) for f in tmp.faces}
            self._colle_par_face(tmp, cols)
        else:
            self._colle(tmp, couleur)

    def _colle_par_face(self, tmp, cols):
        vmap = {v: self.bm.verts.new(v.co) for v in tmp.verts}
        for f in tmp.faces:
            nf = self.bm.faces.new([vmap[v] for v in f.verts])
            nf.smooth = False
            u, v = self.palette.uv(cols[f])
            for loop in nf.loops:
                loop[self.uv].uv = (u, v)
        tmp.free()

    def anneau(self, c, r_in, r_out, h, couleur, n=16, interieur=None):
        """Margelle de bassin ou de puits : couronne épaisse posée sur c."""
        tmp = bmesh.new()
        cx, cy, cz = c
        bas_o, bas_i, hau_o, hau_i = [], [], [], []
        for i in range(n):
            a = math.tau * i / n
            ca, sa = math.cos(a), math.sin(a)
            bas_o.append(tmp.verts.new((cx + ca * r_out, cy + sa * r_out, cz)))
            hau_o.append(tmp.verts.new((cx + ca * r_out, cy + sa * r_out, cz + h)))
            bas_i.append(tmp.verts.new((cx + ca * r_in, cy + sa * r_in, cz)))
            hau_i.append(tmp.verts.new((cx + ca * r_in, cy + sa * r_in, cz + h)))
        cols = {}
        for i in range(n):
            j = (i + 1) % n
            cols[tmp.faces.new([bas_o[i], bas_o[j], hau_o[j], hau_o[i]])] = couleur
            cols[tmp.faces.new([hau_i[i], hau_i[j], bas_i[j], bas_i[i]])] = interieur or couleur
            cols[tmp.faces.new([hau_o[i], hau_o[j], hau_i[j], hau_i[i]])] = couleur
            cols[tmp.faces.new([bas_i[i], bas_i[j], bas_o[j], bas_o[i]])] = couleur
        bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces[:])
        self._colle_par_face(tmp, cols)

    def disque(self, c, r, couleur, n=12):
        """Disque horizontal (surface d'eau, plateau)."""
        cx, cy, cz = c
        self.face([(cx + math.cos(math.tau * i / n) * r, cy + math.sin(math.tau * i / n) * r, cz)
                   for i in range(n)], couleur)

    def roue(self, c, r, larg, couleur="caoutchouc", n=10, moyeu="metal", axe="x"):
        """Roue verticale : axe X (roue vue de côté depuis Y) ou Y."""
        cx, cy, cz = c
        if axe == "x":
            self.tube((cx - larg / 2, cy, cz), (cx + larg / 2, cy, cz), r, couleur, n=n)
            self.tube((cx - larg / 2 - 0.01, cy, cz), (cx + larg / 2 + 0.01, cy, cz), r * 0.5, moyeu, n=6)
        else:
            self.tube((cx, cy - larg / 2, cz), (cx, cy + larg / 2, cz), r, couleur, n=n)
            self.tube((cx, cy - larg / 2 - 0.01, cz), (cx, cy + larg / 2 + 0.01, cz), r * 0.5, moyeu, n=6)

    def rocher(self, c, r, couleur="roche", haut=0.7, alea=0.28, subdiv=1, dessus=None):
        """Rocher irrégulier, à moitié enterré, éventuellement moussu dessus."""
        tmp = bmesh.new()
        bmesh.ops.create_icosphere(tmp, subdivisions=subdiv, radius=1.0)
        g = random.Random(self.rng.random())
        sx, sy = 1.0 + g.uniform(-0.2, 0.25), 1.0 + g.uniform(-0.25, 0.2)
        for v in tmp.verts:
            k = 1.0 + (g.random() * 2 - 1) * alea
            p = v.co
            z = p.z * haut if p.z > 0 else p.z * 0.35
            v.co = Vector(c) + Vector((p.x * r * sx * k, p.y * r * sy * k, z * r * k))
        if dessus:
            self._colle(tmp, lambda n, _c: dessus if n.z > 0.75 else couleur)
        else:
            self._colle(tmp, couleur)

    def triangles(self):
        return sum(len(f.verts) - 2 for f in self.bm.faces)


# --- Export ------------------------------------------------------------------

_MAT = {}


def materiau(palette):
    if "mat" not in _MAT:
        img = palette.image("decors_palette")
        img.pack()
        mat = bpy.data.materials.new("decors")
        mat.use_nodes = True
        nt = mat.node_tree
        bsdf = nt.nodes.get("Principled BSDF")
        bsdf.inputs["Roughness"].default_value = 0.85
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = img
        tex.interpolation = "Closest"
        nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        mat.use_backface_culling = False
        _MAT["mat"] = mat
        _MAT["img"] = img
    return _MAT["mat"]


def exporte(d, nom, chemin, poser=True):
    """Écrit d (Decor) en .glb ; renvoie (triangles, dimensions x, y, z en m)."""
    bm = d.bm
    if poser and bm.verts:
        bas = min(v.co.z for v in bm.verts)
        if bas > -0.03:
            for v in bm.verts:
                v.co.z -= bas + 0.03
    mesh = bpy.data.meshes.new(nom)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(nom, mesh)
    bpy.context.scene.collection.objects.link(obj)
    mesh.materials.append(materiau(d.palette))
    tris = sum(len(f.vertices) - 2 for f in mesh.polygons)
    dims = tuple(obj.dimensions)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=chemin, export_format="GLB", use_selection=True,
        export_apply=True, export_yup=True,
        # Pas de matériau dans les .glb : le jeu pose le sien (palette commune,
        # lanternes qui s'allument) ; sinon Godot extrait une image par modèle.
        export_materials="NONE",
    )
    return obj, tris, dims
