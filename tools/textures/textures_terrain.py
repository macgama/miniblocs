"""Fabrique les textures du terrain de MiniBlocs (sols, champs, routes, eau).

Tout est calculé par ce script (bruits et cellules de Voronoï, avec numpy) :
aucune image extérieure, donc aucune licence à respecter, et on peut tout
refaire ou retoucher (dans Krita par exemple) quand on veut.

Chaque texture fait 256 × 256 px et se répète sans raccord visible.

- assets/textures/sol/*.png : textures du sol, une par type de terrain.
  * « détail » (sol naturel) : gris moyen (128) avec des variations. Le jeu
    MULTIPLIE la couleur du biome par (texture × 2) : la couleur reste celle
    du biome (et de l'altitude), la texture ajoute le grain, les touffes,
    les fissures. Une tuile couvre 4 m × 4 m.
  * « couleur » (champs) : la vraie couleur du champ (labour, blé, colza…),
    rangs dans l'axe X. Une tuile couvre 4 m × 4 m.
- assets/textures/routes/*.png : asphalte, pavés, chemin de terre, gravier,
  ballast, dalles de trottoir (vraies couleurs, tuile de 4 m).
- assets/textures/eau/eau_normale.png : carte de normales des vaguelettes.

Usage : python3 tools/textures/textures_terrain.py [--dossier assets/textures] [--planche docs/apercu-textures.png]
"""

import argparse
import os

import numpy as np
from PIL import Image, ImageDraw

N = 256


# --- Bruits qui se répètent (tuiles sans raccord) ---------------------------------

def bruit_valeur(f, rng, n=N):
    """Bruit de valeur périodique : grille f × f interpolée (lissage cubique)."""
    g = rng.random((f, f))
    x = np.arange(n) * f / n
    i0 = np.floor(x).astype(int)
    t = x - i0
    t = t * t * (3 - 2 * t)
    i1 = (i0 + 1) % f
    i0 = i0 % f
    a = g[np.ix_(i0, i0)] * (1 - t)[None, :] + g[np.ix_(i0, i1)] * t[None, :]
    b = g[np.ix_(i1, i0)] * (1 - t)[None, :] + g[np.ix_(i1, i1)] * t[None, :]
    return a * (1 - t)[:, None] + b * t[:, None]


def fbm(rng, f0=4, octaves=5, gain=0.5, n=N):
    out = np.zeros((n, n))
    amp, tot, f = 1.0, 0.0, f0
    for _ in range(octaves):
        out += bruit_valeur(min(f, n), rng, n) * amp
        tot += amp
        amp *= gain
        f *= 2
    return out / tot


def voronoi(nb, rng, n=N, jitter=1.0, grille=None):
    """Distances F1, F2 et numéro de la cellule la plus proche (périodique).
    grille=(cx, cy) : points sur une grille décalée (pavés, dalles)."""
    if grille:
        cx, cy = grille
        pts = []
        for j in range(cy):
            for i in range(cx):
                dx = 0.5 * (j % 2)
                pts.append(((i + dx + 0.5 + (rng.random() - 0.5) * jitter) / cx,
                            (j + 0.5 + (rng.random() - 0.5) * jitter) / cy))
        pts = np.array(pts)
    else:
        pts = rng.random((nb, 2))
    yy, xx = np.mgrid[0:n, 0:n] / n
    f1 = np.full((n, n), 9.0)
    f2 = np.full((n, n), 9.0)
    ident = np.zeros((n, n), dtype=int)
    for k, (px, py) in enumerate(pts):
        dx = np.abs(xx - px)
        dx = np.minimum(dx, 1 - dx)
        dy = np.abs(yy - py)
        dy = np.minimum(dy, 1 - dy)
        d = np.sqrt(dx * dx + dy * dy)
        plus_proche = d < f1
        f2 = np.where(plus_proche, f1, np.minimum(f2, d))
        ident = np.where(plus_proche, k, ident)
        f1 = np.where(plus_proche, d, f1)
    return f1, f2, ident, len(pts)


def coord():
    yy, xx = np.mgrid[0:N, 0:N] / N
    return xx, yy


def hexa(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], dtype=float) / 255.0


def melange(a, b, t):
    t = np.clip(t, 0, 1)[..., None]
    return a * (1 - t) + b * t


def uni(c):
    return np.broadcast_to(hexa(c), (N, N, 3)).astype(float)


def detail(v, teinte=None):
    """Texture « détail » : v autour de 1.0 (1 = couleur du biome inchangée).
    teinte : variation de couleur (N, N, 3) autour de 1, facultative."""
    rgb = np.repeat(v[..., None], 3, axis=2)
    if teinte is not None:
        rgb = rgb * teinte
    return np.clip(rgb * 0.5, 0, 1)


def recentre(v, force):
    """Ramène la moyenne à 1 et règle l'écart (force = amplitude typique)."""
    v = (v - v.mean()) / (v.std() + 1e-9)
    return 1.0 + v * force


def teinte(rng, chaud, froid, force=0.06, f0=3):
    """Légère variation de couleur : vers chaud (rgb) ou froid selon un bruit."""
    t = fbm(rng, f0, 3)
    t = (t - t.min()) / (np.ptp(t) + 1e-9)
    c = melange(np.broadcast_to(np.array(froid), (N, N, 3)), np.broadcast_to(np.array(chaud), (N, N, 3)), t)
    return 1.0 + (c - 1.0) * force / 0.06


# --- Sols naturels (détail) ----------------------------------------------------------

def herbe(rng):
    v = recentre(fbm(rng, 4, 5), 0.07)
    brins = bruit_valeur(128, rng)
    v += np.where(brins > 0.72, 0.10, 0.0) - np.where(brins < 0.22, 0.08, 0.0)
    return detail(v, teinte(rng, (1.06, 1.03, 0.9), (0.95, 1.02, 1.0)))


def sous_bois(rng):
    f1, f2, ident, nb = voronoi(160, rng)
    feuilles = rng.random(nb)[ident]
    v = recentre(fbm(rng, 4, 5), 0.10) - 0.10 * (f2 - f1 < 0.006)
    v += (feuilles - 0.5) * 0.12
    t = np.ones((N, N, 3))
    brun = feuilles > 0.6
    t[brun] = (1.12, 1.0, 0.82)  # feuilles mortes
    return detail(v, t)


def broussailles(rng):
    taches = fbm(rng, 5, 4)
    terre = np.clip((taches - 0.52) * 8, 0, 1)
    v = recentre(fbm(rng, 8, 4), 0.06) + terre * 0.05
    t = melange(np.ones((N, N, 3)), np.broadcast_to(np.array((1.2, 1.02, 0.8)), (N, N, 3)), terre)
    return detail(v, t)


def sable(rng):
    xx, yy = coord()
    w = fbm(rng, 3, 3)
    rides = np.sin((yy * 9 + w * 1.8) * np.pi * 2)
    v = 1.0 + rides * 0.035 + (bruit_valeur(256, rng) - 0.5) * 0.06
    return detail(v, teinte(rng, (1.03, 1.0, 0.95), (0.98, 1.0, 1.02)))


def roche(rng):
    f1, f2, ident, nb = voronoi(28, rng, jitter=1.0)
    facettes = rng.random(nb)[ident]
    fissure = np.clip(1 - (f2 - f1) / 0.012, 0, 1)
    v = 1.0 + (facettes - 0.5) * 0.18 + (fbm(rng, 8, 4) - 0.5) * 0.15 - fissure * 0.28
    return detail(v)


def neige(rng):
    v = recentre(fbm(rng, 3, 4), 0.025) + (bruit_valeur(256, rng) > 0.97) * 0.03
    return detail(v, teinte(rng, (1.0, 1.0, 1.0), (0.97, 0.99, 1.03)))


def glace(rng):
    f1, f2, _, _ = voronoi(14, rng)
    fissure = np.clip(1 - (f2 - f1) / 0.006, 0, 1)
    v = recentre(fbm(rng, 3, 4), 0.03) - fissure * 0.12
    t = np.ones((N, N, 3))
    t -= fissure[..., None] * np.array((0.10, 0.03, -0.04))
    return detail(v, t)


def vase(rng):
    flaques = fbm(rng, 4, 4)
    eau = np.clip((flaques - 0.58) * 10, 0, 1)
    v = recentre(fbm(rng, 8, 4), 0.07) - eau * 0.12
    t = melange(np.ones((N, N, 3)), np.broadcast_to(np.array((0.85, 0.95, 1.12)), (N, N, 3)), eau)
    return detail(v, t)


def toundra(rng):
    lich = np.clip((fbm(rng, 6, 4) - 0.55) * 7, 0, 1)
    mousse = np.clip((0.42 - fbm(rng, 7, 4)) * 7, 0, 1)
    v = recentre(fbm(rng, 10, 3), 0.05) + lich * 0.12 - mousse * 0.1
    t = melange(np.ones((N, N, 3)), np.broadcast_to(np.array((1.1, 1.08, 0.92)), (N, N, 3)), lich)
    t = melange(t, np.broadcast_to(np.array((0.92, 1.05, 0.9)), (N, N, 3)), mousse)
    return detail(v, t)


def galets(rng):
    f1, f2, ident, nb = voronoi(90, rng)
    clair = rng.random(nb)[ident]
    bord = np.clip(1 - (f2 - f1) / 0.02, 0, 1)
    bombe = np.clip(1 - f1 / 0.05, 0, 1)
    v = 1.0 + (clair - 0.5) * 0.25 + bombe * 0.06 - bord * 0.25
    return detail(v)


def falaise(rng):
    """Flanc des marches de terrain : strates horizontales (v = hauteur)."""
    xx, yy = coord()
    w = fbm(rng, 4, 3)
    strates = np.sin((yy * 6 + w * 0.6) * np.pi * 2)
    v = 1.0 + strates * 0.06 + (fbm(rng, 16, 3) - 0.5) * 0.2
    return detail(v, teinte(rng, (1.05, 1.0, 0.92), (0.96, 0.98, 1.0)))


# --- Champs (vraie couleur, rangs dans l'axe X : lignes horizontales) ---------------

def rangs(nb, epaisseur=0.5, w=None):
    """1 au milieu d'un rang, 0 entre deux rangs (nb rangs par tuile de 4 m)."""
    _, yy = coord()
    if w is not None:
        yy = yy + w
    s = 0.5 + 0.5 * np.cos(yy * nb * np.pi * 2)
    return np.clip((s - (1 - epaisseur)) / max(epaisseur, 1e-3), 0, 1)


def labour(rng):
    sillon = rangs(6, 0.55, fbm(rng, 4, 2) * 0.01)
    mottes = fbm(rng, 32, 3)
    c = melange(uni("#6a4e3a"), uni("#9a7a5a"), sillon * 0.8 + (mottes - 0.5) * 0.6)
    return c


def ble(rng):
    r = rangs(12, 0.7)
    c = melange(uni("#b89640"), uni("#dcc06a"), r * 0.7 + (fbm(rng, 6, 5) - 0.5) * 0.8)
    epis = bruit_valeur(128, rng) > 0.75
    c[epis] = c[epis] * 0.6 + hexa("#ecd488") * 0.4
    return c


def colza(rng):
    fleurs = fbm(rng, 16, 3)
    c = melange(uni("#7a9a30"), uni("#ecd43a"), 0.55 + (fleurs - 0.5) * 2.2)
    return melange(c, uni("#f6e45a"), (bruit_valeur(128, rng) > 0.8) * 0.6)


def mais(rng):
    r = rangs(5, 0.5)
    feuilles = fbm(rng, 24, 3)
    sol = melange(uni("#6e5440"), uni("#8a6c50"), fbm(rng, 16, 3))
    vert = melange(uni("#4a7a2a"), uni("#7aa840"), feuilles)
    return melange(sol, vert, r * 1.2 + (feuilles - 0.5) * 0.8)


def vigne(rng):
    r = rangs(2, 0.3)
    sol = melange(uni("#9a8466"), uni("#b8a07a"), fbm(rng, 16, 3))
    herbe_ = melange(sol, uni("#8aa060"), np.clip((fbm(rng, 6, 3) - 0.45) * 3, 0, 1) * 0.6)
    vert = melange(uni("#3e6a2a"), uni("#6a9a3e"), fbm(rng, 24, 3))
    return melange(herbe_, vert, r * 1.3)


def tournesol(rng):
    f1, f2, ident, nb = voronoi(0, rng, grille=(14, 14), jitter=0.4)
    fleur = np.clip(1 - f1 / 0.028, 0, 1)
    coeur = np.clip(1 - f1 / 0.01, 0, 1)
    c = melange(uni("#4e7a2a"), uni("#f0c02a"), fleur * 1.5)
    return melange(c, uni("#5a3a1e"), coeur * 1.5)


def legumes(rng):
    r = rangs(6, 0.45)
    f1, _, _, _ = voronoi(0, rng, grille=(16, 24), jitter=0.3)
    choux = np.clip(1 - f1 / 0.03, 0, 1) * r
    sol = melange(uni("#5e4632"), uni("#7a5c42"), fbm(rng, 16, 3))
    return melange(sol, melange(uni("#5a8a4a"), uni("#9ac080"), choux), np.clip(choux * 2, 0, 1))


def riz(rng):
    r = rangs(10, 0.5)
    eau = melange(uni("#5a7a7a"), uni("#7a9a96"), fbm(rng, 4, 3))
    vert = melange(uni("#6aa040"), uni("#9ac850"), fbm(rng, 16, 3))
    return melange(eau, vert, 0.55 + r * 0.45)


def pre_fauche(rng):
    """Prairie de fauche : bandes de tonte claires et foncées (2 m)."""
    xx, yy = coord()
    bandes = (np.floor(yy * 2) % 2)
    c = melange(uni("#6a9a44"), uni("#86b056"), bandes * 0.6 + (fbm(rng, 8, 4) - 0.5) * 0.7)
    return c


# --- Routes (vraie couleur) ------------------------------------------------------------

def asphalte(rng):
    v = fbm(rng, 8, 5)
    c = melange(uni("#3c3d40"), uni("#55575b"), v)
    grains = bruit_valeur(256, rng)
    c = melange(c, uni("#6e7074"), (grains > 0.8) * 0.6)
    return melange(c, uni("#2a2b2d"), (grains < 0.12) * 0.6)


def paves(rng):
    """Pavés de granit, rangs décalés (10 × 14 cm environ)."""
    f1, f2, ident, nb = voronoi(0, rng, grille=(28, 36), jitter=0.15)
    teintes = rng.random(nb)[ident]
    joint = np.clip(1 - (f2 - f1) / 0.012, 0, 1)
    c = melange(uni("#7a7670"), uni("#a29d94"), teintes + (fbm(rng, 32, 2) - 0.5) * 0.5)
    return melange(c, uni("#4a4744"), joint)


def chemin(rng):
    """Chemin de terre : deux ornières et une bande d'herbe au milieu (rangs X)."""
    _, yy = coord()
    w = fbm(rng, 4, 3) * 0.04
    terre = melange(uni("#8a6e4e"), uni("#a88a66"), fbm(rng, 16, 4))
    ornieres = np.exp(-(((yy + w) % 1.0 - 0.3) / 0.06) ** 2) + np.exp(-(((yy + w) % 1.0 - 0.7) / 0.06) ** 2)
    c = melange(terre, uni("#6e553c"), ornieres * 0.7)
    milieu = np.exp(-(((yy + w) % 1.0 - 0.5) / 0.07) ** 2) * np.clip((fbm(rng, 12, 3) - 0.35) * 3, 0, 1)
    return melange(c, uni("#6e8a44"), milieu * 0.8)


def gravier(rng):
    f1, f2, ident, nb = voronoi(500, rng)
    teintes = rng.random(nb)[ident]
    joint = np.clip(1 - (f2 - f1) / 0.008, 0, 1)
    c = melange(uni("#9a958c"), uni("#c8c2b6"), teintes)
    return melange(c, uni("#6a665e"), joint * 0.8)


def ballast(rng):
    f1, f2, ident, nb = voronoi(380, rng)
    teintes = rng.random(nb)[ident]
    joint = np.clip(1 - (f2 - f1) / 0.01, 0, 1)
    c = melange(uni("#5e5c58"), uni("#8a8680"), teintes)
    c = melange(c, uni("#7a5a40"), (teintes > 0.9) * 0.4)  # pierres rouillées
    return melange(c, uni("#2e2c2a"), joint)


def dalles(rng):
    """Trottoir : dalles de 50 cm (8 × 8 par tuile de 4 m)."""
    xx, yy = coord()
    jx = np.abs(((xx * 8) % 1.0) - 0.5)
    jy = np.abs(((yy * 8) % 1.0) - 0.5)
    joint = np.clip((np.maximum(jx, jy) - 0.47) * 40, 0, 1)
    cellule = (np.floor(xx * 8) * 7 + np.floor(yy * 8) * 13) % 5 / 5.0
    c = melange(uni("#a8a49c"), uni("#bcb8ae"), cellule + (fbm(rng, 16, 3) - 0.5) * 0.6)
    return melange(c, uni("#6e6a64"), joint)


# --- Eau ----------------------------------------------------------------------------------

def eau_normale(rng):
    """Carte de normales (format OpenGL, vert = haut) de vaguelettes."""
    h = fbm(rng, 4, 5, 0.55)
    dx = (np.roll(h, -1, axis=1) - np.roll(h, 1, axis=1)) * N / 16
    dy = (np.roll(h, -1, axis=0) - np.roll(h, 1, axis=0)) * N / 16
    n = np.stack([-dx, dy, np.ones_like(h)], axis=2)
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return n * 0.5 + 0.5


SOLS = [  # ordre = couche de la texture du terrain (voir Sols.gd)
    ("herbe", herbe), ("sous_bois", sous_bois), ("broussailles", broussailles), ("sable", sable),
    ("roche", roche), ("neige", neige), ("glace", glace), ("vase", vase), ("toundra", toundra),
    ("galets", galets), ("falaise", falaise),
    ("labour", labour), ("ble", ble), ("colza", colza), ("mais", mais), ("vigne", vigne),
    ("tournesol", tournesol), ("legumes", legumes), ("riz", riz), ("pre_fauche", pre_fauche),
]
ROUTES = [("asphalte", asphalte), ("paves", paves), ("chemin", chemin), ("gravier", gravier),
          ("ballast", ballast), ("dalles", dalles)]
EAU = [("eau_normale", eau_normale)]


def enregistre(img, chemin):
    os.makedirs(os.path.dirname(chemin), exist_ok=True)
    Image.fromarray((np.clip(img, 0, 1) * 255 + 0.5).astype(np.uint8), "RGB").save(chemin, optimize=True)


def planche(images, chemin):
    """Planche-contact : chaque texture répétée 2 × 2, avec son nom."""
    col = 6
    t = 160
    lig = (len(images) + col - 1) // col
    out = Image.new("RGB", (col * (t + 10) + 10, lig * (t + 30) + 10), (30, 32, 36))
    d = ImageDraw.Draw(out)
    for k, (nom, img, mod) in enumerate(images):
        a = np.clip(img, 0, 1)
        if mod:  # texture détail : montrée sur un vert moyen pour la lire
            a = np.clip(a * 2 * hexa("#6a9a50"), 0, 1)
        a = np.tile(a, (2, 2, 1))
        im = Image.fromarray((a * 255).astype(np.uint8)).resize((t, t), Image.LANCZOS)
        x, y = 10 + (k % col) * (t + 10), 10 + (k // col) * (t + 30)
        out.paste(im, (x, y))
        d.text((x, y + t + 4), nom, fill=(230, 230, 230))
    os.makedirs(os.path.dirname(chemin) or ".", exist_ok=True)
    out.save(chemin)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dossier", default="assets/textures")
    ap.add_argument("--planche", default=None)
    a = ap.parse_args()
    toutes = []
    for groupe, liste in (("sol", SOLS), ("routes", ROUTES), ("eau", EAU)):
        for nom, f in liste:
            rng = np.random.default_rng(sum(map(ord, nom)) * 7919)
            img = f(rng)
            enregistre(img, os.path.join(a.dossier, groupe, nom + ".png"))
            mod = groupe == "sol" and nom in [s[0] for s in SOLS[:11]]
            toutes.append((nom, img, mod))
            print("TEXTURE", groupe, nom, "moyenne %.2f" % float(np.mean(img)))
    if a.planche:
        planche(toutes, a.planche)
    print("TEXTURES OK :", len(toutes))


if __name__ == "__main__":
    main()
