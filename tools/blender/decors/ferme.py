"""Ferme : bottes de foin, machines agricoles, petits équipements et cultures."""

import math

from .base import V


# --- Foin et paille -----------------------------------------------------------------

def botte_ronde(d):
    """Botte ronde de foin (Ø 1,5 m), couchée."""
    d.tube((-0.6, 0, 0.75), (0.6, 0, 0.75), 0.75, "foin", n=12)
    d.tube((-0.61, 0, 0.75), (0.61, 0, 0.75), 0.45, "foin_sombre", n=10)


def botte_enrubannee(d):
    """Botte ronde enrubannée de film blanc."""
    d.tube((-0.6, 0, 0.75), (0.6, 0, 0.75), 0.76, "film", n=12)
    d.tube((-0.61, 0, 0.75), (0.61, 0, 0.75), 0.3, "galva", n=8)


def botte_debout(d):
    """Botte ronde posée debout."""
    d.cyl((0, 0, 0), 0.75, 1.2, "foin", n=12, dessus="foin_sombre")


def botte_carree(d):
    """Petite botte de paille rectangulaire."""
    d.boite((0, 0, 0), (0.9, 0.45, 0.38), "paille", dessus="foin")
    for x in (-0.2, 0.2):
        d.boite((x, 0, 0), (0.02, 0.46, 0.39), "foin_sombre")


def pile_bottes(d):
    """Pile de grosses bottes carrées (meule moderne)."""
    for z in range(3):
        for y in range(2 if z < 2 else 1):
            for x in range(3):
                d.boite((-1.25 + x * 1.25, -0.6 + y * 1.2 + (0.6 if z == 2 else 0), z * 0.9),
                        (1.2, 1.15, 0.88), "paille", dessus="foin")


def meule(d):
    """Meule de foin traditionnelle (cône arrondi)."""
    d.cyl((0, 0, 0), 1.6, 1.6, "foin", n=10, r2=1.7)
    d.cyl((0, 0, 1.6), 1.7, 1.8, "foin", n=10, r2=0.25)
    d.cone((0, 0, 3.4), 0.25, 0.4, "foin_sombre", n=8)
    d.cyl((0, 0, 3.4), 0.03, 0.8, "bois", n=4)


# --- Machines --------------------------------------------------------------------

def _tracteur(d, carrosserie, jantes, cabine=True, echelle=1.0):
    k = echelle
    # Châssis et moteur à l'avant (-Y)
    d.boite((0, -0.9 * k, 0.6 * k), (0.8 * k, 1.6 * k, 0.75 * k), carrosserie)
    d.boite((0, -1.72 * k, 0.6 * k), (0.75 * k, 0.06 * k, 0.6 * k), "metal_sombre")
    d.boite((0, 0.45 * k, 0.55 * k), (1.0 * k, 1.1 * k, 0.4 * k), carrosserie)
    d.cyl((0.25 * k, -1.2 * k, 1.35 * k), 0.05 * k, 0.6 * k, "noir", n=6)
    # Roues arrière (grandes) et avant
    for s in (-1, 1):
        d.roue((s * 0.85 * k, 0.45 * k, 0.8 * k), 0.8 * k, 0.45 * k, moyeu=jantes, n=12)
        d.roue((s * 0.7 * k, -1.25 * k, 0.48 * k), 0.48 * k, 0.3 * k, moyeu=jantes, n=10)
        d.boite((s * 0.85 * k, 0.45 * k, 1.55 * k), (0.5 * k, 1.5 * k, 0.05 * k), carrosserie)
    if cabine:
        for x in (-0.5, 0.5):
            for y in (0.0, 0.95):
                d.boite((x * k, y * k, 0.95 * k), (0.06 * k, 0.06 * k, 1.4 * k), "noir")
        d.boite((0, 0.47 * k, 1.2 * k), (0.96 * k, 0.9 * k, 1.1 * k), "vitre")
        d.boite((0, 0.47 * k, 2.35 * k), (1.15 * k, 1.15 * k, 0.1 * k), carrosserie)
    else:
        d.boite((0, 0.4 * k, 0.95 * k), (0.45 * k, 0.4 * k, 0.08 * k), "noir")
        d.boite((0, 0.62 * k, 1.0 * k), (0.45 * k, 0.06 * k, 0.4 * k), "noir")
        d.tube((0, -0.05 * k, 0.9 * k), (0, 0.15 * k, 1.35 * k), 0.025 * k, "noir", n=4)
        d.cyl((0, 0.15 * k, 1.35 * k), 0.18 * k, 0.04 * k, "noir", n=8, rx=-30)


def tracteur(d):
    """Tracteur moderne vert à cabine."""
    _tracteur(d, "vert", "jaune")


def tracteur_rouge(d):
    """Tracteur rouge."""
    _tracteur(d, "rouge", "blanc")


def tracteur_ancien(d):
    """Vieux tracteur sans cabine."""
    _tracteur(d, "orange", "rouge_sombre", cabine=False, echelle=0.85)


def remorque_foin(d):
    """Plateau chargé de bottes de paille."""
    d.boite((0, 0, 0.75), (2.4, 5.0, 0.12), "rouge_sombre")
    for y in (-1.5, 1.5):
        for s in (-1, 1):
            d.roue((s * 1.05, y, 0.42), 0.42, 0.3, n=10)
    d.poutre((0, -2.5, 0.8), (0, -3.6, 0.6), 0.12, 0.12, "metal_sombre")
    for z in range(2):
        for y in range(4):
            for x in range(2):
                d.boite((-0.55 + x * 1.1, -1.8 + y * 1.2, 0.87 + z * 0.88), (1.08, 1.15, 0.86), "paille",
                        dessus="foin")


def moissonneuse(d):
    """Moissonneuse-batteuse et sa barre de coupe."""
    d.boite((0, 0.6, 0.9), (2.8, 5.0, 2.2), "vert", dessus="vert")
    d.boite((0, 2.2, 3.1), (2.4, 1.6, 0.6), "vert")
    for s in (-1, 1):
        d.roue((s * 1.55, -0.9, 0.85), 0.85, 0.6, moyeu="jaune", n=12)
        d.roue((s * 1.35, 2.6, 0.55), 0.55, 0.4, moyeu="jaune", n=10)
    d.boite((-0.3, -1.6, 2.2), (1.4, 1.4, 1.4), "vitre")
    d.boite((-0.3, -1.6, 3.6), (1.6, 1.6, 0.1), "vert")
    d.boite((0, -2.4, 0.6), (1.2, 1.2, 1.0), "vert")
    # Barre de coupe (6 m)
    d.boite((0, -3.4, 0.3), (6.2, 1.2, 0.4), "jaune")
    d.tube((-3.0, -3.7, 1.0), (3.0, -3.7, 1.0), 0.45, "jaune", n=8)
    # Vis de déchargement
    d.tube((1.5, 1.5, 3.2), (4.5, 0.5, 3.5), 0.18, "vert", n=6)


def charrue(d):
    """Charrue à socs."""
    d.poutre((0, -1.4, 0.7), (0, 1.4, 0.55), 0.18, 0.18, "rouge")
    for i in range(4):
        y = -0.9 + i * 0.6
        x = -0.4 + i * 0.25
        d.poutre((x, y, 0.62), (x + 0.1, y + 0.3, 0.1), 0.08, 0.08, "rouge")
        d.boite((x + 0.15, y + 0.35, 0.0), (0.4, 0.25, 0.25), "metal", rz=30)
    d.roue((0.6, 1.3, 0.35), 0.35, 0.2, n=10)


def abreuvoir(d):
    """Abreuvoir galvanisé (2 m)."""
    d.boite((0, 0, 0), (2.0, 0.7, 0.6), "galva")
    d.boite((0, 0, 0.6), (2.0, 0.7, 0.05), "galva")
    d.boite((0, 0, 0.5), (1.9, 0.6, 0.12), "eau")


def ratelier(d):
    """Râtelier à foin."""
    d.boite((0, 0, 0), (2.4, 1.4, 0.4), "galva")
    for x in (-1.15, 1.15):
        for y in (-0.65, 0.65):
            d.boite((x, y, 0), (0.08, 0.08, 1.3), "galva")
    for i in range(10):
        x = -1.1 + i * 0.245
        for y in (-0.68, 0.68):
            d.cyl((x, y, 0.4), 0.02, 0.9, "galva", n=4)
    d.boule((0, 0, 0.9), 1.0, 0.55, 0.45, "foin", subdiv=1, alea=0.12)


def epouvantail(d):
    """Épouvantail au chapeau de paille."""
    d.cyl((0, 0, 0), 0.04, 1.9, "bois", n=4)
    d.tube((-0.7, 0, 1.4), (0.7, 0, 1.4), 0.035, "bois", n=4)
    d.boite((0, 0, 0.85), (0.5, 0.25, 0.65), "rouge_sombre")
    d.tube((-0.25, 0, 1.4), (-0.7, 0, 1.38), 0.08, "bleu", n=5)
    d.tube((0.25, 0, 1.4), (0.7, 0, 1.38), 0.08, "bleu", n=5)
    d.boule((0, 0, 1.68), 0.15, 0.15, 0.17, "tissu_blanc", subdiv=1, alea=0.05)
    d.cyl((0, 0, 1.8), 0.3, 0.03, "paille", n=8)
    d.cyl((0, 0, 1.83), 0.14, 0.15, "paille", n=8)
    for s in (-1, 1):
        d.boite((s * 0.72, 0, 1.25), (0.05, 0.05, 0.15), "paille")


def ruches(d):
    """Trois ruches en bois."""
    for i, c in enumerate(("jaune", "bleu_ciel", "blanc")):
        x = -1.0 + i * 1.0
        d.boite((x, 0, 0), (0.5, 0.5, 0.3), "bois_sombre")
        d.boite((x, 0, 0.3), (0.5, 0.45, 0.55), c)
        d.boite((x, -0.24, 0.32), (0.25, 0.04, 0.03), "noir")
        d.profil([(-0.3, 0), (0.3, 0), (0.3, 0.06), (0, 0.15), (-0.3, 0.06)], -0.28, 0.28, "metal",
                 origine=(x, 0, 0.85))


def tas_bois(d):
    """Tas de bûches."""
    for z in range(3):
        for i in range(6 - z):
            x = -1.0 + i * 0.36 + z * 0.18
            d.tube((x, -0.4, 0.17 + z * 0.3), (x, 0.4, 0.17 + z * 0.3), 0.16, "bois", n=6)
            d.tube((x, -0.41, 0.17 + z * 0.3), (x, -0.4, 0.17 + z * 0.3), 0.12, "bois_clair", n=6)


def grumes(d):
    """Grumes (troncs abattus) en bord de chemin."""
    for i, (x, z, r) in enumerate([(-0.5, 0.3, 0.3), (0.1, 0.28, 0.28), (0.65, 0.32, 0.32), (-0.2, 0.8, 0.28),
                                   (0.4, 0.82, 0.3)]):
        d.tube((x, -3.0, z), (x, 3.0, z), r, "bois_gris", n=7)
        d.tube((x, -3.01, z), (x, -3.0, z), r * 0.85, "bois_clair", n=7)


def brouette(d):
    """Brouette."""
    d.profil([(-0.35, 0.3), (0.35, 0.3), (0.45, 0.62), (-0.5, 0.62)], -0.32, 0.32, "vert", rz=90)
    d.roue((0, -0.65, 0.2), 0.2, 0.08, axe="x", n=8)
    for s in (-1, 1):
        d.poutre((s * 0.22, -0.6, 0.25), (s * 0.28, 0.9, 0.55), 0.04, 0.04, "bois")
        d.boite((s * 0.22, 0.3, 0.0), (0.04, 0.04, 0.32), "metal_sombre")


def puits(d):
    """Puits en pierre avec son toit."""
    d.anneau((0, 0, 0), 0.6, 0.9, 0.85, "pierre", n=12, interieur="pierre_sombre")
    d.disque((0, 0, 0.3), 0.62, "noir", n=12)
    for x in (-0.75, 0.75):
        d.boite((x, 0, 0.85), (0.1, 0.1, 1.2), "bois")
    d.tube((-0.75, 0, 1.75), (0.75, 0, 1.75), 0.08, "bois_sombre", n=6)
    d.tube((0, 0, 1.7), (0, 0, 1.2), 0.008, "metal", n=3)
    d.cyl((0, 0, 1.0), 0.14, 0.22, "bois", n=8)
    d.profil([(-0.65, 0), (0.65, 0), (0, 0.6)], -0.95, 0.95, "tuile", rz=90, origine=(0, 0, 2.0))


def bidons_lait(d):
    """Bidons de lait sur un quai en bois."""
    d.boite((0, 0, 0), (1.4, 0.8, 0.5), "bois_gris")
    for i in range(3):
        x = -0.45 + i * 0.45
        d.cyl((x, 0, 0.5), 0.17, 0.5, "galva", n=8, r2=0.17)
        d.cyl((x, 0, 1.0), 0.17, 0.12, "galva", n=8, r2=0.09)
        d.cyl((x, 0, 1.12), 0.1, 0.06, "galva", n=8)


def poulailler(d):
    """Petit poulailler sur pilotis."""
    for x in (-0.6, 0.6):
        for y in (-0.5, 0.5):
            d.boite((x, y, 0), (0.08, 0.08, 0.5), "bois_sombre")
    d.boite((0, 0, 0.5), (1.4, 1.2, 0.9), "bois")
    d.profil([(-0.85, 0), (0.85, 0), (0, 0.6)], -0.7, 0.7, "tuile", rz=90, origine=(0, 0, 1.4))
    d.boite((0, -0.61, 0.6), (0.3, 0.02, 0.35), "noir")
    d.poutre((0, -0.62, 0.6), (0, -1.3, 0.0), 0.3, 0.03, "bois_clair")


def citerne(d):
    """Cuve à eau ou à fioul sur berceau."""
    for y in (-1.0, 1.0):
        d.boite((0, y, 0), (1.2, 0.2, 0.5), "beton")
    d.tube((0, -1.6, 1.1), (0, 1.6, 1.1), 0.75, "galva", n=12)
    d.cyl((0, 0, 1.8), 0.25, 0.15, "galva", n=8)


def silo_grain(d):
    """Silo à grain en tôle ondulée (Ø 5 m, 8 m)."""
    d.cyl((0, 0, 0), 2.6, 0.3, "beton", n=16)
    d.cyl((0, 0, 0.3), 2.5, 6.5, "galva", n=16)
    for z in (1.5, 3.0, 4.5, 6.0):
        d.cyl((0, 0, z), 2.53, 0.08, "metal", n=16)
    d.cyl((0, 0, 6.8), 2.55, 1.6, "galva", n=16, r2=0.4)
    d.cyl((0, 0, 8.4), 0.45, 0.4, "metal", n=8)
    for i in range(10):
        d.boite((2.55, 0, 0.3 + i * 0.7), (0.06, 0.5, 0.04), "metal_sombre")


# --- Cultures (1 m² ou en rangs) --------------------------------------------------

def citrouilles(d):
    """Carré de citrouilles (1 m²)."""
    for (x, y, r) in [(-0.25, -0.2, 0.2), (0.25, 0.15, 0.24), (0.2, -0.3, 0.15), (-0.3, 0.3, 0.17)]:
        d.boule((x, y, r * 0.75), r, r, r * 0.75, "citrouille", subdiv=1, alea=0.06)
        d.cyl((x, y, r * 1.45), 0.02, 0.06, "terre", n=4)
    for i in range(6):
        a = i * 1.1
        d.face([(math.cos(a) * 0.1, math.sin(a) * 0.1, 0.05), (math.cos(a) * 0.5, math.sin(a) * 0.45, 0.1),
                (math.cos(a + 0.4) * 0.45, math.sin(a + 0.4) * 0.5, 0.12)], "feuillage")


def choux(d):
    """Rang de choux (1 m)."""
    for i in range(3):
        x = -0.33 + i * 0.33
        d.boule((x, 0, 0.15), 0.17, 0.17, 0.15, "chou", subdiv=1, alea=0.2)
        d.boule((x, 0, 0.22), 0.1, 0.1, 0.09, "herbe", subdiv=1, alea=0.1)


def tomates(d):
    """Rang de tomates sur tuteurs (1 m)."""
    for i in range(3):
        x = -0.33 + i * 0.33
        d.cyl((x, 0, 0), 0.012, 1.4, "bois", n=4)
        for z in (0.35, 0.7, 1.05):
            d.boule((x + 0.04, 0, z), 0.16, 0.14, 0.18, "feuillage", subdiv=1, alea=0.2)
            d.boule((x + 0.1, -0.08, z - 0.08), 0.045, 0.045, 0.045, "fruit_rouge", subdiv=1, alea=0.0)


def serre_tunnel(d):
    """Serre tunnel en plastique (6 × 20 m)."""
    pts = []
    for i in range(9):
        a = math.pi * i / 8
        pts.append((math.cos(a) * 3.0, math.sin(a) * 2.8))
    for i in range(8):
        (x0, z0), (x1, z1) = pts[i], pts[i + 1]
        d.face([(x0, -10, z0), (x1, -10, z1), (x1, 10, z1), (x0, 10, z0)], "film")
    for y in range(-10, 11, 2):
        for i in range(8):
            (x0, z0), (x1, z1) = pts[i], pts[i + 1]
            d.tube((x0, y, z0), (x1, y, z1), 0.025, "galva", n=3)
    for y in (-10.0, 10.0):
        d.face([(x, y, z) for x, z in pts], "film")
    d.boite((0, -10.02, 0), (1.4, 0.03, 2.0), "galva")


def pommier(d):
    """Pommier de verger, chargé de pommes."""
    d.cyl((0, 0, -0.1), 0.13, 1.5, "bois", n=6, r2=0.1)
    d.tube((0, 0, 1.3), (0.6, 0.2, 2.1), 0.08, "bois", n=5)
    d.tube((0, 0, 1.3), (-0.5, -0.3, 2.0), 0.08, "bois", n=5)
    d.boule((0, 0, 2.5), 1.6, 1.5, 1.2, "feuillage", subdiv=1, alea=0.18)
    d.boule((0.6, 0.4, 2.9), 0.9, 0.9, 0.7, "herbe", subdiv=1, alea=0.15)
    for i in range(14):
        a = i * 2.4
        r = 1.35 + (i % 3) * 0.1
        z = 1.9 + (i % 4) * 0.35
        d.boule((math.cos(a) * r, math.sin(a) * r, z), 0.09, 0.09, 0.09, "fruit_rouge", subdiv=0, alea=0.0)


def vigne_piquets(d):
    """Fin de rang de vigne : piquet de tête et fils."""
    d.cyl((0, 0, 0), 0.05, 1.6, "bois_gris", n=5, ry=-12)
    d.tube((0.15, 0, 1.0), (1.0, 0, 1.0), 0.006, "metal", n=3)
    d.tube((0.25, 0, 1.4), (1.0, 0, 1.4), 0.006, "metal", n=3)
    d.tube((0, 0, 1.2), (-0.8, 0, 0.0), 0.006, "metal", n=3)
