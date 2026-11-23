"""Parcs et jardins, arbres d'ornement (lot « idées de Gaël », 2026-11-23).

Inspiré des planches low-poly envoyées par Gaël (parc carré avec fontaine et
bac à sable, parc à labyrinthe de haies, étangs à rochers, pont en arc,
cerisiers et arbres d'automne) : tout est redessiné ici par code, rien n'est
copié. Les arbres d'ornement sont des décors fixes (posés avec G) : les arbres
sauvages et plantés au pinceau restent ceux de plantes_lowpoly.py.
"""

import math


# --- Arbres d'ornement ---------------------------------------------------------

def _tronc(d, h, r=0.16, couleur="bois_sombre", penche=0.0):
    d.tube((0, 0, 0), (penche, 0, h), r, couleur, n=6, r2=r * 0.6)


def _houppier(d, c, r, couleurs, n=5, etale=1.0, haut=0.8):
    """Houppier en plusieurs boules (feuillage ou fleurs)."""
    cx, cy, cz = c
    d.boule((cx, cy, cz), r, r, r * haut, couleurs[0], subdiv=1, alea=0.18)
    for i in range(n):
        a = math.tau * i / n + 0.4
        k = r * 0.62 * etale
        col = couleurs[(i + 1) % len(couleurs)]
        d.boule((cx + math.cos(a) * k, cy + math.sin(a) * k, cz - r * 0.15 + (i % 2) * r * 0.3),
                r * 0.6, r * 0.6, r * 0.5 * haut / 0.8, col, subdiv=1, alea=0.2)


def cerisier_fleurs(d):
    """Cerisier en fleurs.

    Cerisier du Japon en fleurs (sakura)."""
    _tronc(d, 1.6, 0.17)
    for a, l in ((0.3, 1.3), (2.4, 1.2), (4.3, 1.1)):
        d.tube((0, 0, 1.4), (math.cos(a) * l, math.sin(a) * l, 2.6), 0.08, "bois_sombre", n=5)
    _houppier(d, (0, 0, 3.1), 1.5, ["rose", "rose", "tissu_blanc", "rose"], n=6, etale=1.2, haut=0.65)


def erable_rouge(d):
    """Érable du Japon rouge.

    Érable du Japon rouge d'automne."""
    _tronc(d, 1.3, 0.13)
    for a in (0.0, 2.1, 4.2):
        d.tube((0, 0, 1.1), (math.cos(a) * 0.9, math.sin(a) * 0.9, 2.0), 0.06, "bois_sombre", n=5)
    _houppier(d, (0, 0, 2.5), 1.3, ["rouge", "rouge_sombre", "orange", "rouge"], n=5, etale=1.2, haut=0.6)


def arbre_automne(d):
    """Arbre d'automne.

    Arbre d'automne orangé (érable, hêtre roux)."""
    _tronc(d, 2.4, 0.2)
    _houppier(d, (0, 0, 4.0), 1.9, ["orange", "jaune", "rouge", "orange"], n=5, haut=0.85)


def ginkgo_dore(d):
    """Ginkgo doré.

    Ginkgo doré : port élancé, feuilles jaunes en automne."""
    _tronc(d, 4.5, 0.18)
    for z, r in ((2.8, 1.3), (4.2, 1.1), (5.5, 0.8)):
        d.boule((0, 0, z), r, r, r * 0.9, "jaune", subdiv=1, alea=0.2)


def jacaranda(d):
    """Jacaranda en fleurs.

    Jacaranda en fleurs violettes."""
    _tronc(d, 2.0, 0.2)
    for a in (0.5, 2.6, 4.6):
        d.tube((0, 0, 1.8), (math.cos(a) * 1.6, math.sin(a) * 1.6, 3.3), 0.09, "bois_sombre", n=5)
    _houppier(d, (0, 0, 3.8), 2.0, ["violet", "violet", "bleu_ciel", "violet"], n=6, etale=1.3, haut=0.5)


def magnolia(d):
    """Magnolia en fleurs.

    Magnolia en fleurs, blanc rosé."""
    _tronc(d, 1.5, 0.15)
    _houppier(d, (0, 0, 2.9), 1.5, ["tissu_blanc", "rose", "tissu_blanc", "feuillage"], n=5, haut=0.8)


def bouleau_blanc(d):
    """Bouleau blanc.

    Bouleau à l'écorce blanche, feuillage léger."""
    d.tube((0, 0, 0), (0.15, 0, 5.5), 0.13, "blanc", n=6, r2=0.07)
    for z in (0.8, 1.9, 3.1, 4.2):
        d.cyl((0.03 * z, 0, z), 0.135, 0.12, "noir", n=6)
    for z, r in ((3.6, 1.1), (4.7, 1.0), (5.7, 0.7)):
        d.boule((0.15, 0, z), r, r, r * 0.9, "vert", subdiv=1, alea=0.25)


def cypres(d):
    """Cyprès d'Italie.

    Cyprès d'Italie, fuseau sombre."""
    d.cyl((0, 0, 0), 0.15, 0.8, "bois_sombre", n=6)
    d.boule((0, 0, 3.6), 0.85, 0.85, 3.4, "feuillage", subdiv=1, alea=0.08)


def saule_pleureur(d):
    """Saule pleureur.

    Saule pleureur au bord de l'eau."""
    _tronc(d, 2.6, 0.28, penche=0.2)
    for a in (0.4, 2.5, 4.4):
        d.tube((0.2, 0, 2.4), (0.2 + math.cos(a) * 1.4, math.sin(a) * 1.4, 3.4), 0.08, "bois_sombre", n=5)
    d.boule((0.2, 0, 3.6), 2.1, 2.1, 0.8, "herbe", subdiv=1, alea=0.12)
    # Rideaux de branches retombantes, fins et effilés vers le bas
    for i in range(14):
        a = math.tau * i / 14 + 0.1
        r = 1.95 + 0.15 * (i % 2)
        x, y = 0.2 + math.cos(a) * r, math.sin(a) * r
        h = 2.4 + 0.5 * (i % 3)
        d.cyl((x, y, 3.5 - h), 0.08, h, "mousse" if i % 3 == 0 else "herbe", n=4, r2=0.38)


def arbre_rond_parc(d):
    """Arbre de parc en boule.

    Arbre de parc taillé en boule, tuteuré."""
    _tronc(d, 2.0, 0.12)
    d.tube((0.3, 0, 0), (0.05, 0, 1.4), 0.03, "bois_clair", n=4)
    d.boule((0, 0, 2.9), 1.2, 1.2, 1.15, "vert", subdiv=1, alea=0.06)


def arbre_pot(d):
    """Arbre en pot.

    Petit arbre en pot de terre cuite (terrasses, devantures)."""
    d.cyl((0, 0, 0), 0.32, 0.55, "tuile", n=8, r2=0.42)
    d.disque((0, 0, 0.5), 0.4, "terre", n=8)
    d.tube((0, 0, 0.5), (0, 0, 1.3), 0.04, "bois", n=5)
    d.boule((0, 0, 1.6), 0.5, 0.5, 0.5, "feuillage", subdiv=1, alea=0.15)


def palmier_bac(d):
    """Palmier en bac.

    Palmier nain en bac de bois."""
    d.boite((0, 0, 0), (0.8, 0.8, 0.6), "bois", dessus="terre")
    d.tube((0, 0, 0.6), (0.1, 0, 1.9), 0.09, "bois_clair", n=6, r2=0.07)
    for i in range(7):
        a = math.tau * i / 7
        x, y = math.cos(a), math.sin(a)
        d.face([(0.1, 0, 1.95), (0.1 + x * 1.0 - y * 0.18, y * 1.0 + x * 0.18, 1.6),
                (0.1 + x * 1.2, y * 1.2, 1.35), (0.1 + x * 1.0 + y * 0.18, y * 1.0 - x * 0.18, 1.6)], "vert")


def bonsai(d):
    """Bonsaï.

    Bonsaï sur sa table basse (jardins japonais, devantures)."""
    d.boite((0, 0, 0), (0.9, 0.5, 0.45), "bois_sombre")
    d.boite((0, 0, 0.45), (0.6, 0.38, 0.12), "bleu")
    d.tube((0, 0, 0.55), (0.12, 0, 0.75), 0.04, "bois_sombre", n=5)
    d.tube((0.12, 0, 0.75), (-0.12, 0, 0.95), 0.03, "bois_sombre", n=5)
    for x, z, r in ((-0.16, 0.98, 0.17), (0.18, 0.82, 0.13), (0.0, 1.08, 0.12)):
        d.boule((x, 0, z), r * 1.3, r, r * 0.55, "feuillage", subdiv=1, alea=0.1)


def plantes_pots(d):
    """Plantes en pots.

    Groupe de plantes en pots (seuils, terrasses, escaliers)."""
    for x, y, h, col in ((-0.4, 0, 0.45, "tuile"), (0.1, 0.15, 0.3, "bleu"), (0.45, -0.1, 0.38, "blanc")):
        d.cyl((x, y, 0), h * 0.45, h, col, n=8, r2=h * 0.55)
        d.boule((x, y, h + 0.18), h * 0.6, h * 0.6, h * 0.55, "feuillage" if col != "blanc" else "vert", subdiv=1)
    d.boule((0.1, 0.15, 0.62), 0.12, 0.12, 0.08, "rouge", subdiv=1)


# --- Topiaires -------------------------------------------------------------------

def _bac_topiaire(d):
    d.cyl((0, 0, 0), 0.38, 0.5, "pierre", n=8, r2=0.32)


def topiaire_boule(d):
    """Topiaire en boule.

    Topiaire en boule de buis, en pot."""
    _bac_topiaire(d)
    d.boule((0, 0, 1.0), 0.5, 0.5, 0.5, "feuillage", subdiv=2, alea=0.03)


def topiaire_cone(d):
    """Topiaire en cône.

    Topiaire en cône (if taillé)."""
    _bac_topiaire(d)
    d.cyl((0, 0, 0.5), 0.45, 1.8, "feuillage", n=10, r2=0.02)


def topiaire_spirale(d):
    """Topiaire en spirale.

    Topiaire en spirale."""
    _bac_topiaire(d)
    d.tube((0, 0, 0.5), (0, 0, 2.2), 0.06, "bois", n=4)
    for i in range(14):
        t = i / 13
        a = t * math.tau * 2.5
        r = 0.42 * (1 - t * 0.7)
        d.boule((math.cos(a) * r * 0.5, math.sin(a) * r * 0.5, 0.65 + t * 1.6), r, r, 0.16, "feuillage", subdiv=1, alea=0.05)


def topiaire_etages(d):
    """Topiaire à étages.

    Topiaire à étages : trois boules sur une tige."""
    _bac_topiaire(d)
    d.tube((0, 0, 0.5), (0, 0, 2.4), 0.05, "bois", n=4)
    for z, r in ((1.0, 0.42), (1.65, 0.32), (2.2, 0.22)):
        d.boule((0, 0, z), r, r, r, "feuillage", subdiv=2, alea=0.03)


def topiaire_cube(d):
    """Buis en cube.

    Buis taillé en cube, à même le sol."""
    d.boite((0, 0, 0), (1.0, 1.0, 1.0), "feuillage")


# --- Aménagements de parc -------------------------------------------------------

def _mur_haie(d, x0, y0, x1, y1, h=1.6, e=0.6):
    if abs(x1 - x0) > abs(y1 - y0):
        d.boite(((x0 + x1) / 2, y0, 0), (abs(x1 - x0) + e, e, h), "feuillage", dessus="herbe")
    else:
        d.boite((x0, (y0 + y1) / 2, 0), (e, abs(y1 - y0) + e, h), "feuillage", dessus="herbe")


def labyrinthe_haies(d):
    """Labyrinthe de haies.

    Labyrinthe de haies taillées, vasque au centre (16 × 16 m)."""
    for k, c in enumerate((7.7, 5.2, 2.7)):
        g = 1.0  # demi-largeur de l'ouverture
        s = -1 if k % 2 == 0 else 1  # ouverture au sud, au nord, au sud
        _mur_haie(d, -c, -s * c, c, -s * c)  # côté plein
        _mur_haie(d, -c, s * c, -g, s * c)
        _mur_haie(d, g, s * c, c, s * c)
        _mur_haie(d, -c, -c, -c, c)
        _mur_haie(d, c, -c, c, c)
    # Murs de traverse pour faire tourner le promeneur
    _mur_haie(d, -6.45, 0, -3.95, 0)
    _mur_haie(d, 3.95, 0, 6.45, 0)
    _mur_haie(d, 0, 2.7, 0, 5.2)
    # Vasque et dallage au centre
    d.cyl((0, 0, 0), 1.6, 0.05, "pierre", n=12)
    d.cyl((0, 0, 0.05), 0.2, 0.7, "pierre", n=8)
    d.anneau((0, 0, 0.75), 0.45, 0.55, 0.15, "pierre", n=10)
    d.disque((0, 0, 0.85), 0.47, "eau", n=10)
    for x, y in ((-7.7, -8.2), (7.7, -8.2)):
        d.cyl((x, y, 0), 0.07, 2.0, "fonte", n=6)
        d.boite((x, y, 2.0), (0.25, 0.25, 0.3), "lumiere_chaude")
        d.cone((x, y, 2.3), 0.2, 0.15, "fonte", n=4)


def pont_arche(d):
    """Pont de bois en arc.

    Pont de bois en arc pour franchir un ruisseau (6 m)."""
    n = 10
    for i in range(n):
        t0, t1 = i / n, (i + 1) / n
        x0, x1 = -3 + 6 * t0, -3 + 6 * t1
        z0, z1 = 1.1 * math.sin(math.pi * t0), 1.1 * math.sin(math.pi * t1)
        d.poutre((x0, 0, z0 + 0.15), (x1, 0, z1 + 0.15), 1.4, 0.1, "bois_clair")
        for y in (-0.72, 0.72):
            d.poutre((x0, y, z0 + 0.95), (x1, y, z1 + 0.95), 0.08, 0.08, "bois")
            if i % 2 == 0:
                d.tube((x0, y, z0 + 0.1), (x0, y, z0 + 0.95), 0.04, "bois", n=4)
    for x in (-3, 3):
        for y in (-0.72, 0.72):
            d.tube((x, y, 0), (x, y, 1.05), 0.06, "bois", n=4)


def pont_japonais(d):
    """Pont japonais.

    Pont japonais en arc, laqué rouge (6 m)."""
    n = 10
    for i in range(n):
        t0, t1 = i / n, (i + 1) / n
        x0, x1 = -3 + 6 * t0, -3 + 6 * t1
        z0, z1 = 1.4 * math.sin(math.pi * t0), 1.4 * math.sin(math.pi * t1)
        d.poutre((x0, 0, z0 + 0.15), (x1, 0, z1 + 0.15), 1.6, 0.12, "bois")
        for y in (-0.8, 0.8):
            d.poutre((x0, y, z0 + 1.0), (x1, y, z1 + 1.0), 0.1, 0.08, "rouge")
            d.poutre((x0, y, z0 + 0.55), (x1, y, z1 + 0.55), 0.05, 0.05, "rouge")
            if i % 3 == 0:
                d.tube((x0, y, z0 + 0.1), (x0, y, z0 + 1.15), 0.06, "rouge", n=6)
    for x in (-3, 3):
        for y in (-0.8, 0.8):
            d.tube((x, y, 0), (x, y, 1.2), 0.07, "rouge", n=6)
            d.boite((x, y, 1.2), (0.16, 0.16, 0.08), "or")


def etang_rochers(d):
    """Étang aux rochers.

    Petit étang bordé de rochers, nénuphars et roseaux (Ø 5 m)."""
    d.disque((0, 0, 0.04), 2.3, "eau", n=14)
    for i in range(14):
        a = math.tau * i / 14
        r = 2.35 + 0.15 * math.sin(i * 1.7)
        d.rocher((math.cos(a) * r, math.sin(a) * r, 0), 0.32 + 0.12 * (i % 3), "roche_claire" if i % 2 else "roche",
                 haut=0.6, dessus="mousse" if i % 4 == 0 else None)
    for x, y in ((-0.8, 0.4), (0.5, -0.6), (0.9, 0.8)):
        d.cyl((x, y, 0.05), 0.28, 0.02, "vert", n=7)
    d.boule((0.5, -0.6, 0.1), 0.07, 0.07, 0.06, "rose", subdiv=1, alea=0)
    for i in range(6):
        d.cyl((-1.6 + i * 0.12, 1.3 + (i % 2) * 0.1, 0), 0.025, 1.1 + (i % 3) * 0.2, "herbe", n=4, r2=0.01)


def bassin_nenuphars(d):
    """Bassin aux nénuphars.

    Bassin rond de pierre aux nénuphars (Ø 4 m)."""
    d.anneau((0, 0, 0), 1.75, 2.0, 0.4, "pierre", n=18, interieur="pierre_sombre")
    d.disque((0, 0, 0.3), 1.77, "eau", n=18)
    for i, (x, y) in enumerate(((-0.6, 0.3), (0.4, -0.5), (0.8, 0.6), (-0.2, -1.0), (0.1, 0.9))):
        d.cyl((x, y, 0.31), 0.24, 0.02, "vert", n=7)
        if i % 2 == 0:
            d.boule((x, y, 0.36), 0.06, 0.06, 0.05, "rose" if i else "tissu_blanc", subdiv=1, alea=0)


def bassin_mogol(d):
    """Bassin moghol à jets d'eau.

    Bassin-canal à jets d'eau des jardins moghols (char bagh, 10 m)."""
    d.boite((0, 0, 0), (2.2, 10.0, 0.35), "pierre", dessus="pierre")
    d.boite((0, 0, 0.35), (1.6, 9.4, 0.01), "eau")
    for i in range(5):
        y = -3.6 + i * 1.8
        d.cyl((0, y, 0.35), 0.06, 0.6, "bleu_ciel", n=5, r2=0.0)
    for y in (-5.2, 5.2):
        d.boite((0, y, 0), (2.8, 0.6, 0.5), "pierre", dessus="blanc")
    for x in (-1.6, 1.6):
        for y in (-3.6, 0, 3.6):
            d.cyl((x, y, 0), 0.25, 3.0, "feuillage", n=6, r2=0.05)


def tsukubai(d):
    """Tsukubai.

    Tsukubai : bassin de pierre et bambou verseur (jardin japonais)."""
    d.rocher((0, 0, 0), 0.45, "pierre", haut=0.9)
    d.cyl((0, 0, 0.32), 0.2, 0.06, "eau", n=8)
    d.tube((0.9, 0, 0.6), (0.1, 0, 0.5), 0.035, "vert", n=5)
    d.tube((0.9, 0, 0), (0.9, 0, 0.7), 0.05, "vert", n=5)
    d.boite((-0.2, 0.15, 0.45), (0.05, 0.05, 0.05), "bois")
    for i in range(6):
        a = math.tau * i / 6
        d.boule((math.cos(a) * 0.9, math.sin(a) * 0.9, 0), 0.12, 0.12, 0.06, "roche_sombre", subdiv=1)


def jardin_zen(d):
    """Jardin zen.

    Jardin sec zen : sable ratissé et trois pierres (4 × 3 m)."""
    d.boite((0, 0, 0), (4.0, 3.0, 0.12), "bois_sombre", dessus="sable")
    for i in range(7):
        d.boite((0, -1.2 + i * 0.4, 0.12), (3.7, 0.04, 0.012), "pierre")
    for x, y, r in ((-1.1, 0.4, 0.45), (0.9, -0.5, 0.35), (1.3, 0.7, 0.25)):
        d.anneau((x, y, 0.12), r + 0.12, r + 0.17, 0.01, "pierre", n=10)
        d.rocher((x, y, 0.12), r, "roche_sombre", haut=0.9, dessus="mousse")


def porte_lune(d):
    """Porte de lune.

    Porte de lune : mur blanc percé d'un cercle (jardins chinois)."""
    n = 16
    R, L, H, e = 1.2, 4.0, 3.0, 0.3
    zc = 1.45
    # Mur en deux moitiés, ouvertes d'un cercle approché par des bandes
    for i in range(n):
        a0, a1 = math.tau * i / n, math.tau * (i + 1) / n
        x0, z0 = math.cos(a0) * R, zc + math.sin(a0) * R
        x1, z1 = math.cos(a1) * R, zc + math.sin(a1) * R
        haut = H if (z0 + z1) / 2 > zc else 0.0
        d.profil([(x0, z0), (x1, z1), (x1, haut), (x0, haut)], -e / 2, e / 2, "blanc", cotes="blanc")
    for sx in (-1, 1):
        d.boite((sx * (R + (L / 2 - R) / 2), 0, 0), (L / 2 - R, e, H), "blanc")
    d.boite((0, 0, H), (L + 0.4, e + 0.3, 0.12), "tuile")
    d.profil([(-L / 2 - 0.2, H + 0.12), (L / 2 + 0.2, H + 0.12), (L / 2 + 0.3, H + 0.3), (0, H + 0.45),
              (-L / 2 - 0.3, H + 0.3)], -0.3, 0.3, "noir")


def pergola_vigne(d):
    """Pergola à vigne.

    Pergola de bois couverte de vigne grimpante (4 × 3 m)."""
    for x in (-1.9, 1.9):
        for y in (-1.4, 1.4):
            d.boite((x, y, 0), (0.15, 0.15, 2.5), "bois")
    for y in (-1.4, 1.4):
        d.boite((0, y, 2.5), (4.4, 0.14, 0.2), "bois")
    for i in range(8):
        d.boite((-1.75 + i * 0.5, 0, 2.7), (0.08, 3.3, 0.12), "bois_clair")
    for i in range(7):
        x = -1.6 + i * 0.53
        d.boule((x, 0.4 * math.sin(i * 1.3), 2.9), 0.55, 0.9, 0.22, "feuillage" if i % 2 else "vert", subdiv=1, alea=0.25)
    for x in (-1.9, 1.9):
        d.boule((x, 1.4, 1.2), 0.25, 0.2, 1.1, "feuillage", subdiv=1, alea=0.2)
    d.boite((0, 0, 0), (1.4, 0.8, 0.75), "bois_sombre")


def arche_roses(d):
    """Arche de roses.

    Arche de jardin en fer couverte de roses."""
    n = 8
    for y in (-0.35, 0.35):
        for x in (-0.8, 0.8):
            d.tube((x, y, 0), (x, y, 1.6), 0.025, "fonte", n=4)
        for i in range(n):
            a0, a1 = math.pi * i / n, math.pi * (i + 1) / n
            d.tube((math.cos(a0) * 0.8, y, 1.6 + math.sin(a0) * 0.8), (math.cos(a1) * 0.8, y, 1.6 + math.sin(a1) * 0.8),
                   0.025, "fonte", n=4)
    for i in range(12):
        a = math.pi * i / 11
        x, z = math.cos(a) * 0.82, 1.6 + math.sin(a) * 0.82
        d.boule((x, 0, z), 0.22, 0.42, 0.2, "feuillage", subdiv=1, alea=0.2)
        d.boule((x * 1.06, -0.25 + (i % 3) * 0.25, z + 0.12), 0.07, 0.07, 0.07, ("rouge", "rose", "tissu_blanc")[i % 3],
                subdiv=1, alea=0)
    for x in (-0.8, 0.8):
        d.boule((x, 0, 0.7), 0.25, 0.35, 0.7, "feuillage", subdiv=1, alea=0.2)


def arche_coeur(d):
    """Arche en cœur.

    Arche fleurie en forme de cœur (mariages, photos souvenir)."""
    pts = []
    for i in range(25):
        t = math.tau * i / 24
        x = 16 * math.sin(t) ** 3
        z = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        pts.append((x * 0.09, z * 0.09 + 1.6))
    for (x0, z0), (x1, z1) in zip(pts, pts[1:]):
        d.tube((x0, 0, z0), (x1, 0, z1), 0.1, "rouge", n=5)
    for i in range(0, 24, 2):
        x, z = pts[i]
        d.boule((x, -0.05, z), 0.15, 0.12, 0.15, "rose" if i % 4 else "tissu_blanc", subdiv=1, alea=0)
    d.boite((0, 0, 0), (1.2, 0.6, 0.12), "blanc")


def banc_arbre(d):
    """Banc autour d'un arbre.

    Banc circulaire autour d'un grand arbre."""
    d.anneau((0, 0, 0), 0.9, 1.4, 0.45, "bois_clair", n=10, interieur="bois")
    for i in range(10):
        a = math.tau * i / 10
        d.poutre((math.cos(a) * 1.35, math.sin(a) * 1.35, 0.5), (math.cos(a) * 1.4, math.sin(a) * 1.4, 0.95), 0.4, 0.06,
                 "bois", haut=(math.cos(a), math.sin(a), 0))
    d.tube((0, 0, 0), (0, 0, 3.2), 0.3, "bois_sombre", n=7, r2=0.2)
    _houppier(d, (0, 0, 4.6), 2.3, ["feuillage", "vert", "feuillage"], n=5, haut=0.75)


def nappe_pique_nique(d):
    """Nappe de pique-nique.

    Nappe de pique-nique à carreaux, panier et coussins."""
    for i in range(4):
        for j in range(4):
            d.boite((-0.75 + i * 0.5, -0.75 + j * 0.5, 0), (0.5, 0.5, 0.02), "rouge" if (i + j) % 2 else "tissu_blanc")
    d.boite((0.4, 0.3, 0.02), (0.45, 0.3, 0.25), "paille")
    d.tube((0.25, 0.3, 0.27), (0.55, 0.3, 0.27), 0.02, "bois", n=4)
    d.cyl((-0.4, -0.3, 0.02), 0.12, 0.02, "blanc", n=8)
    d.boule((-0.4, -0.3, 0.06), 0.05, 0.05, 0.04, "fruit_rouge", subdiv=1, alea=0)
    d.cyl((-0.1, 0.4, 0.02), 0.04, 0.28, "vert", n=6, r2=0.02)


def bain_oiseaux(d):
    """Bain d'oiseaux.

    Bain d'oiseaux de pierre, sur son pied."""
    d.cyl((0, 0, 0), 0.25, 0.1, "pierre", n=8)
    d.cyl((0, 0, 0.1), 0.1, 0.7, "pierre", n=8, r2=0.14)
    d.cyl((0, 0, 0.8), 0.15, 0.12, "pierre", n=10, r2=0.45)
    d.disque((0, 0, 0.9), 0.38, "eau", n=10)
    d.boule((0.3, 0.1, 0.96), 0.06, 0.04, 0.05, "pelage_roux", subdiv=1, alea=0)


def cadran_solaire(d):
    """Cadran solaire.

    Cadran solaire de jardin sur colonne."""
    d.boite((0, 0, 0), (0.6, 0.6, 0.12), "pierre")
    d.cyl((0, 0, 0.12), 0.14, 0.85, "pierre", n=8)
    d.cyl((0, 0, 0.97), 0.3, 0.05, "bronze", n=12)
    d.profil([(0, 0), (0.24, 0), (0, 0.2)], -0.01, 0.01, "bronze", origine=(0, 0, 1.02))


def nichoir(d):
    """Nichoir.

    Nichoir à oiseaux sur poteau."""
    d.boite((0, 0, 0), (0.08, 0.08, 1.8), "bois")
    d.boite((0, 0, 1.8), (0.25, 0.25, 0.3), "bois_clair")
    d.profil([(-0.2, 0), (0.2, 0), (0, 0.16)], -0.17, 0.17, "tuile", origine=(0, 0, 2.1), rz=90)
    d.cyl((0, -0.13, 1.98), 0.04, 0.01, "noir", n=6, rx=90)


def parterre_rond(d):
    """Parterre de fleurs.

    Parterre de fleurs rond bordé de buis (Ø 3 m)."""
    d.anneau((0, 0, 0), 1.3, 1.5, 0.3, "feuillage", n=14)
    d.cyl((0, 0, 0), 1.32, 0.15, "terre", n=14)
    for i in range(18):
        a = math.tau * i / 18
        r = 0.4 + (i % 3) * 0.35
        d.boule((math.cos(a) * r, math.sin(a) * r, 0.25), 0.14, 0.14, 0.12,
                ("rouge", "jaune", "violet", "rose", "orange", "tissu_blanc")[i % 6], subdiv=1, alea=0.1)
    d.boule((0, 0, 0.45), 0.3, 0.3, 0.35, "feuillage", subdiv=1, alea=0.05)


def parterre_francais(d):
    """Parterre à la française.

    Parterre à la française : buis taillés en compartiments (6 × 6 m)."""
    d.boite((0, 0, 0), (6.0, 6.0, 0.03), "sable")
    for sx in (-1, 1):
        for sy in (-1, 1):
            cx, cy = sx * 1.6, sy * 1.6
            d.boite((cx, cy, 0.03), (2.4, 2.4, 0.05), "terre")
            for k in (-1.15, 1.15):
                d.boite((cx + k, cy, 0.03), (0.2, 2.5, 0.35), "feuillage")
                d.boite((cx, cy + k, 0.03), (2.5, 0.2, 0.35), "feuillage")
            d.boule((cx, cy, 0.2), 0.45, 0.45, 0.25, "rouge" if sx == sy else "violet", subdiv=1, alea=0.1)
    d.cyl((0, 0, 0.03), 0.35, 1.2, "feuillage", n=8, r2=0.02)


def rocaille(d):
    """Rocaille fleurie.

    Rocaille fleurie : rochers, plantes grasses et fleurs (3 m)."""
    for i, (x, y, r) in enumerate(((-0.8, 0, 0.5), (0.4, 0.3, 0.6), (0.9, -0.5, 0.35), (-0.2, -0.6, 0.3))):
        d.rocher((x, y, 0), r, "roche_claire" if i % 2 else "roche", haut=0.7, dessus="mousse" if i == 1 else None)
    for i in range(9):
        a = i * 2.4
        x, y = math.cos(a) * (0.4 + i * 0.12), math.sin(a) * (0.4 + i * 0.1)
        d.boule((x, y, 0.15), 0.13, 0.13, 0.1, ("jaune", "violet", "tissu_blanc", "rose")[i % 4], subdiv=1, alea=0.1)


def vasque_fleurie(d):
    """Vasque fleurie.

    Vasque Médicis fleurie sur piédestal."""
    d.boite((0, 0, 0), (0.6, 0.6, 0.8), "pierre")
    d.cyl((0, 0, 0.8), 0.12, 0.2, "pierre", n=8)
    d.cyl((0, 0, 1.0), 0.18, 0.4, "pierre", n=10, r2=0.4)
    d.boule((0, 0, 1.45), 0.45, 0.45, 0.25, "feuillage", subdiv=1, alea=0.2)
    for i in range(6):
        a = math.tau * i / 6
        d.boule((math.cos(a) * 0.3, math.sin(a) * 0.3, 1.55), 0.09, 0.09, 0.08, "rouge" if i % 2 else "rose", subdiv=1, alea=0)


def gloriette(d):
    """Gloriette.

    Gloriette : petit pavillon de jardin ouvert, toit en dôme."""
    d.cyl((0, 0, 0), 2.0, 0.3, "pierre", n=6)
    for i in range(6):
        a = math.tau * i / 6
        d.cyl((math.cos(a) * 1.7, math.sin(a) * 1.7, 0.3), 0.09, 2.4, "blanc", n=6)
    d.cyl((0, 0, 2.7), 2.0, 0.2, "blanc", n=6)
    d.cyl((0, 0, 2.9), 1.95, 1.1, "vert_fonte", n=6, r2=0.2)
    d.cone((0, 0, 4.0), 0.25, 0.5, "or", n=6)
    d.cyl((0, 0, 0.3), 0.9, 0.06, "bois_clair", n=6)


def serre_jardin(d):
    """Serre de jardin.

    Serre de jardin en fer et verre (style victorien, 4 × 3 m)."""
    d.boite((0, 0, 0), (4.0, 3.0, 0.5), "brique")
    for x in (-2.0, -1.0, 0.0, 1.0, 2.0):
        for y in (-1.5, 1.5):
            d.boite((x, y, 0.5), (0.06, 0.06, 1.6), "blanc")
    d.boite((0, -1.52, 0.5), (4.0, 0.02, 1.6), "vitre")
    d.boite((0, 1.52, 0.5), (4.0, 0.02, 1.6), "vitre")
    for sx in (-1, 1):
        d.boite((sx * 2.02, 0, 0.5), (0.02, 3.0, 1.6), "vitre")
    d.profil([(-1.55, 0), (1.55, 0), (0, 1.1)], -2.05, 2.05, "vitre", rz=90, origine=(0, 0, 2.1), cotes="vitre")
    d.boite((0, 0, 3.2), (4.2, 0.08, 0.12), "blanc")
    for x in (-1.2, 0, 1.2):
        d.boule((x, 0.8, 0.9), 0.35, 0.35, 0.35, "vert", subdiv=1)


def borne_jardin(d):
    """Borne lumineuse d'allée.

    Borne lumineuse basse d'allée de parc."""
    d.cyl((0, 0, 0), 0.1, 0.7, "fonte", n=8)
    d.cyl((0, 0, 0.7), 0.09, 0.15, "lumiere_chaude", n=8)
    d.cyl((0, 0, 0.85), 0.14, 0.06, "fonte", n=8)


def lampadaire_parc(d):
    """Lampadaire de parc.

    Lampadaire de parc à lanterne, fût noir."""
    d.cyl((0, 0, 0), 0.15, 0.4, "noir", n=8)
    d.cyl((0, 0, 0.4), 0.06, 2.8, "noir", n=6)
    d.cyl((0, 0, 3.2), 0.14, 0.4, "lumiere_chaude", n=4, r2=0.2)
    d.cyl((0, 0, 3.6), 0.25, 0.15, "noir", n=4, r2=0.05)


def bac_a_sable_hexa(d):
    """Bac à sable hexagonal.

    Bac à sable hexagonal bordé de bois, seau et pelle."""
    d.anneau((0, 0, 0), 1.75, 2.0, 0.3, "bois", n=6, interieur="bois_clair")
    d.cyl((0, 0, 0), 1.76, 0.22, "sable", n=6)
    d.cyl((0.6, 0.3, 0.22), 0.1, 0.15, "rouge", n=6, r2=0.13)
    d.boite((-0.5, -0.4, 0.22), (0.3, 0.1, 0.03), "jaune", rz=30)
    d.boule((-0.3, 0.6, 0.22), 0.3, 0.25, 0.15, "sable", subdiv=1, alea=0.1)
