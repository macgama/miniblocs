"""Mobilier urbain : bancs, lampadaires, poubelles, abribus, fontaines, statues…"""

import math

from .base import V


# --- Bancs --------------------------------------------------------------------

def _pieds_banc(d, x, couleur="fonte"):
    # Pied en fonte : montant avant, montant arrière incliné, accoudoir.
    d.boite((x, -0.18, 0), (0.06, 0.06, 0.45), couleur)
    d.tube((x, 0.2, 0), (x, 0.26, 0.85), 0.03, couleur, n=4)
    d.boite((x, 0.0, 0.42), (0.06, 0.46, 0.05), couleur)
    d.boite((x, -0.08, 0.62), (0.05, 0.36, 0.04), couleur)
    d.boite((x, -0.24, 0.45), (0.05, 0.05, 0.2), couleur)


def banc_bois(d):
    """Banc public : lattes de bois sur pieds de fonte (1,8 m)."""
    for x in (-0.8, 0.8):
        _pieds_banc(d, x)
    for i in range(4):
        d.boite((0, -0.18 + i * 0.11, 0.45), (1.8, 0.08, 0.035), "bois")
    for i in range(3):
        z = 0.58 + i * 0.1
        d.boite((0, 0.2 + i * 0.022, z), (1.8, 0.035, 0.07), "bois", rx=-12)


def banc_vert(d):
    """Banc de parc à lattes peintes en vert (style parisien)."""
    for x in (-0.85, 0.85):
        _pieds_banc(d, x)
    for i in range(5):
        d.boite((0, -0.2 + i * 0.09, 0.45), (1.9, 0.07, 0.03), "vert_fonte")
    for i in range(4):
        d.boite((0, 0.19 + i * 0.02, 0.56 + i * 0.08), (1.9, 0.03, 0.06), "vert_fonte", rx=-14)


def banc_pierre(d):
    """Banc de pierre massif."""
    for x in (-0.65, 0.65):
        d.boite((x, 0, 0), (0.3, 0.42, 0.4), "pierre_sombre")
    d.boite((0, 0, 0.4), (1.8, 0.5, 0.08), "pierre")


def banc_moderne(d):
    """Banc contemporain : bloc de béton et assise en bois."""
    d.boite((0, 0, 0), (2.0, 0.55, 0.38), "beton")
    d.boite((0, 0, 0.38), (2.0, 0.55, 0.06), "bois_clair")


def table_pique_nique(d):
    """Table de pique-nique en bois et ses deux bancs."""
    for x in (-0.7, 0.7):
        d.poutre((x, -0.7, 0), (x, 0.0, 0.75), 0.08, 0.05, "bois", haut=V(1, 0, 0))
        d.poutre((x, 0.7, 0), (x, 0.0, 0.75), 0.08, 0.05, "bois", haut=V(1, 0, 0))
        d.boite((x, 0, 0.42), (0.08, 1.6, 0.06), "bois_sombre")
    for i in range(4):
        d.boite((0, -0.3 + i * 0.2, 0.75), (1.9, 0.18, 0.04), "bois_clair")
    for s in (-1, 1):
        for i in range(2):
            d.boite((0, s * (0.62 + i * 0.13), 0.45), (1.9, 0.12, 0.04), "bois_clair")


# --- Éclairage ----------------------------------------------------------------

def lampadaire(d):
    """Lampadaire routier : mât de 8 m, crosse, lanterne vers -Y."""
    d.cyl((0, 0, 0), 0.14, 0.4, "metal_sombre", n=8)
    d.cyl((0, 0, 0.4), 0.09, 7.4, "galva", n=8, r2=0.06)
    d.tube((0, 0, 7.6), (0, -0.9, 7.95), 0.045, "galva", n=6)
    d.tube((0, -0.9, 7.95), (0, -1.6, 7.9), 0.045, "galva", n=6)
    d.boite((0, -1.75, 7.72), (0.3, 0.6, 0.16), "metal_sombre")
    d.boite((0, -1.75, 7.68), (0.24, 0.5, 0.04), "lumiere")


def lampadaire_double(d):
    """Lampadaire à deux crosses (terre-plein, grandes avenues)."""
    d.cyl((0, 0, 0), 0.16, 0.4, "metal_sombre", n=8)
    d.cyl((0, 0, 0.4), 0.1, 8.6, "galva", n=8, r2=0.07)
    for s in (-1, 1):
        d.tube((0, 0, 8.7), (0, s * 1.5, 9.0), 0.05, "galva", n=6)
        d.boite((0, s * 1.75, 8.82), (0.3, 0.6, 0.16), "metal_sombre")
        d.boite((0, s * 1.75, 8.78), (0.24, 0.5, 0.04), "lumiere")


def reverbere(d):
    """Réverbère ancien en fonte et sa lanterne (4 m)."""
    d.cyl((0, 0, 0), 0.22, 0.3, "fonte", n=8, r2=0.16)
    d.cyl((0, 0, 0.3), 0.12, 0.7, "fonte", n=8, r2=0.08)
    d.cyl((0, 0, 1.0), 0.07, 2.6, "fonte", n=8, r2=0.05)
    d.cyl((0, 0, 3.55), 0.12, 0.1, "fonte", n=8)
    d.cyl((0, 0, 3.65), 0.16, 0.5, "lumiere_chaude", n=6, r2=0.22)
    d.cyl((0, 0, 4.15), 0.26, 0.18, "fonte", n=6, r2=0.04)
    d.cone((0, 0, 4.33), 0.05, 0.15, "fonte", n=6)
    d.tube((-0.35, 0, 3.0), (0.35, 0, 3.0), 0.02, "fonte", n=4)


def lampadaire_boule(d):
    """Lampadaire de parc à boule (3,5 m)."""
    d.cyl((0, 0, 0), 0.12, 0.3, "metal_sombre", n=8)
    d.cyl((0, 0, 0.3), 0.06, 3.0, "metal_sombre", n=8)
    d.boule((0, 0, 3.55), 0.28, 0.28, 0.28, "lumiere", subdiv=1, alea=0.0)


def lanterne_pierre(d):
    """Tōrō : lanterne de pierre de jardin japonais."""
    d.cyl((0, 0, 0), 0.4, 0.15, "pierre_sombre", n=6)
    d.cyl((0, 0, 0.15), 0.14, 0.7, "pierre", n=6)
    d.cyl((0, 0, 0.85), 0.35, 0.12, "pierre", n=6)
    d.boite((0, 0, 0.97), (0.42, 0.42, 0.34), "pierre")
    d.boite((0, -0.01, 1.05), (0.24, 0.44, 0.18), "lumiere_chaude")
    d.cyl((0, 0, 1.31), 0.55, 0.22, "pierre_sombre", n=6, r2=0.12)
    d.cone((0, 0, 1.53), 0.12, 0.2, "pierre_sombre", n=6)


# --- Propreté, réseaux ---------------------------------------------------------

def poubelle(d):
    """Corbeille de rue sur son poteau."""
    d.cyl((0, 0.1, 0), 0.04, 1.0, "vert_fonte", n=6)
    d.cyl((0, -0.12, 0.35), 0.22, 0.6, "vert_fonte", n=10, dessus="noir")
    d.cyl((0, -0.12, 0.93), 0.235, 0.04, "galva", n=10)


def poubelles_tri(d):
    """Trois bacs de tri (verre, papier, ordures)."""
    for i, c in enumerate(("vert", "jaune", "bleu")):
        x = -0.62 + i * 0.62
        d.boite((x, 0, 0), (0.56, 0.6, 1.0), c)
        d.boite((x, 0, 1.0), (0.58, 0.62, 0.05), "metal_sombre")
        d.boite((x, -0.31, 0.85), (0.3, 0.02, 0.06), "noir")


def conteneur(d):
    """Conteneur à ordures sur roues (1 100 l)."""
    d.boite((0, 0, 0.15), (1.3, 1.0, 1.0), "vert_fonte")
    d.profil([(-0.68, 1.15), (0.68, 1.15), (0.68, 1.3), (-0.68, 1.22)], -0.55, 0.55, "vert_fonte")
    for x in (-0.5, 0.5):
        for y in (-0.38, 0.38):
            d.roue((x, y, 0.1), 0.1, 0.06, axe="x")


def borne_incendie(d):
    """Poteau d'incendie rouge."""
    d.cyl((0, 0, 0), 0.14, 0.12, "rouge_sombre", n=8)
    d.cyl((0, 0, 0.12), 0.1, 0.62, "rouge", n=8)
    d.cyl((0, 0, 0.74), 0.12, 0.1, "rouge", n=8, r2=0.05)
    for a in (0, 180):
        x = math.cos(math.radians(a)) * 0.12
        d.tube((0, 0, 0.5), (x, 0, 0.5), 0.045, "rouge", n=6)
    d.tube((0, 0, 0.5), (0, -0.14, 0.5), 0.06, "galva", n=6)


def potelet(d):
    """Potelet de trottoir (anti-stationnement)."""
    d.cyl((0, 0, 0), 0.06, 1.0, "fonte", n=8)
    d.cyl((0, 0, 1.0), 0.07, 0.05, "fonte", n=8, r2=0.03)
    d.cyl((0, 0, 0.8), 0.065, 0.06, "blanc", n=8)


def potelets(d):
    """Rangée de cinq potelets (4 m)."""
    for i in range(5):
        x = -2.0 + i * 1.0
        d.cyl((x, 0, 0), 0.06, 1.0, "fonte", n=6)
        d.cyl((x, 0, 0.8), 0.065, 0.06, "blanc", n=6)
        d.cyl((x, 0, 1.0), 0.07, 0.05, "fonte", n=6, r2=0.03)


def boite_aux_lettres(d):
    """Boîte aux lettres jaune sur pied."""
    d.cyl((0, 0, 0), 0.05, 0.9, "metal_sombre", n=6)
    d.boite((0, 0, 0.85), (0.5, 0.4, 0.55), "jaune")
    d.profil([(-0.25, 1.4), (0.25, 1.4), (0.25, 1.46), (0, 1.52), (-0.25, 1.46)], -0.2, 0.2, "jaune")
    d.boite((0, -0.205, 1.25), (0.3, 0.02, 0.04), "noir")
    d.boite((0, -0.205, 1.0), (0.2, 0.02, 0.12), "bleu")


def cabine_telephone(d):
    """Cabine téléphonique rouge à petits carreaux."""
    d.boite((0, 0, 0), (1.0, 1.0, 0.12), "rouge_sombre")
    for x in (-0.45, 0.45):
        for y in (-0.45, 0.45):
            d.boite((x, y, 0.12), (0.1, 0.1, 2.2), "rouge")
    for (cx, cy, sx, sy) in [(0, -0.47, 0.8, 0.04), (0, 0.47, 0.8, 0.04), (-0.47, 0, 0.04, 0.8), (0.47, 0, 0.04, 0.8)]:
        d.boite((cx, cy, 0.4), (sx, sy, 1.6), "vitre")
        for k in range(4):
            d.boite((cx, cy, 0.6 + k * 0.4), (sx + 0.02, sy + 0.02, 0.04), "rouge")
        d.boite((cx, cy, 0.12), (sx + 0.02, sy + 0.02, 0.28), "rouge")
        d.boite((cx, cy, 2.0), (sx + 0.02, sy + 0.02, 0.2), "rouge")
    d.boite((0, 0, 2.32), (1.06, 1.06, 0.08), "rouge")
    d.profil([(-0.5, 0), (0.5, 0), (0.35, 0.2), (-0.35, 0.2)], -0.5, 0.5, "rouge", origine=(0, 0, 2.4))
    d.boite((0, -0.5, 2.1), (0.6, 0.04, 0.14), "blanc")


def colonne_affichage(d):
    """Colonne d'affichage verte et ses affiches."""
    d.cyl((0, 0, 0), 0.7, 0.3, "vert_fonte", n=12)
    d.cyl((0, 0, 0.3), 0.6, 2.4, "tissu_blanc", n=12)
    for i, c in enumerate(("rouge", "jaune", "bleu", "orange")):
        a = i * 90
        d.boite((math.cos(math.radians(a)) * 0.58, math.sin(math.radians(a)) * 0.58, 0.9), (0.5, 0.5, 1.2), c, rz=a)
    d.cyl((0, 0, 2.7), 0.68, 0.2, "vert_fonte", n=12)
    d.cyl((0, 0, 2.9), 0.62, 0.5, "vert_fonte", n=12, r2=0.15)
    d.cone((0, 0, 3.4), 0.15, 0.3, "vert_fonte", n=8)


def parcmetre(d):
    """Horodateur de stationnement."""
    d.boite((0, 0, 0), (0.25, 0.2, 1.0), "metal_sombre")
    d.boite((0, 0, 1.0), (0.38, 0.3, 0.55), "galva")
    d.boite((0, -0.155, 1.2), (0.22, 0.02, 0.22), "bleu")
    d.boite((0, 0, 1.55), (0.4, 0.32, 0.04), "metal_sombre")


def velo(d, x, y, rz=0.0, couleur="bleu"):
    c, s = math.cos(math.radians(rz)), math.sin(math.radians(rz))
    def p(u, z):
        return (x + c * u, y + s * u, z)
    for u in (-0.55, 0.55):
        cx, cy, cz = p(u, 0.34)
        d.tube((cx - s * 0.02, cy + c * 0.02, cz), (cx + s * 0.02, cy - c * 0.02, cz), 0.34, "caoutchouc", n=10)
    d.tube(p(-0.55, 0.34), p(-0.05, 0.4), 0.025, couleur, n=4)
    d.tube(p(-0.05, 0.4), p(0.45, 0.85), 0.025, couleur, n=4)
    d.tube(p(-0.15, 0.82), p(0.45, 0.85), 0.025, couleur, n=4)
    d.tube(p(-0.05, 0.4), p(-0.15, 0.82), 0.025, couleur, n=4)
    d.tube(p(0.45, 0.85), p(0.55, 0.34), 0.025, couleur, n=4)
    d.boite(p(-0.17, 0.86), (0.22, 0.1, 0.05), "noir", rz=rz)
    d.tube(p(0.42, 1.0), p(0.45, 0.85), 0.02, "metal", n=4)
    cx, cy, cz = p(0.42, 1.0)
    d.tube((cx - s * 0.25, cy + c * 0.25, cz), (cx + s * 0.25, cy - c * 0.25, cz), 0.02, "noir", n=4)


def arceaux_velo(d):
    """Arceaux à vélos et deux vélos garés."""
    for i in range(3):
        x = -1.0 + i * 1.0
        d.tube((x, -0.35, 0), (x, -0.35, 0.75), 0.03, "galva", n=6)
        d.tube((x, 0.35, 0), (x, 0.35, 0.75), 0.03, "galva", n=6)
        d.tube((x, -0.35, 0.75), (x, 0.35, 0.75), 0.03, "galva", n=6)
    velo(d, -0.5, 0.0, 90, "bleu")
    velo(d, 0.5, 0.05, 90, "rouge")


def jardiniere(d):
    """Bac à fleurs en bois (2 m)."""
    d.boite((0, 0, 0), (2.0, 0.6, 0.55), "bois")
    d.boite((0, 0, 0.55), (1.9, 0.5, 0.04), "terre")
    for i in range(7):
        x = -0.85 + i * 0.28
        d.boule((x, (i % 2) * 0.12 - 0.06, 0.66), 0.17, 0.17, 0.15, "feuillage", subdiv=1)
        d.boule((x + 0.06, (i % 2) * 0.12 - 0.06, 0.8), 0.07, 0.07, 0.05,
                ("rouge", "jaune", "rose", "violet")[i % 4], subdiv=1)


def horloge(d):
    """Horloge de rue à double cadran."""
    d.cyl((0, 0, 0), 0.2, 0.3, "fonte", n=8)
    d.cyl((0, 0, 0.3), 0.08, 2.6, "fonte", n=8)
    d.tube((0, -0.08, 3.2), (0, 0.08, 3.2), 0.36, "fonte", n=12)
    d.tube((0, -0.1, 3.2), (0, 0.1, 3.2), 0.3, "blanc", n=12)
    d.boite((0, -0.11, 3.2), (0.03, 0.01, 0.22), "noir")
    d.boite((0.07, -0.11, 3.18), (0.16, 0.01, 0.03), "noir")
    d.cone((0, 0, 3.56), 0.08, 0.2, "fonte", n=6)


def abribus(d):
    """Abribus vitré : banc, toit et plan du réseau (4 m)."""
    for x in (-1.95, 1.95):
        for y in (-0.6, 0.6):
            d.boite((x, y, 0), (0.08, 0.08, 2.5), "metal_sombre")
    d.boite((0, 0.6, 0.1), (3.8, 0.04, 2.3), "vitre")
    d.boite((1.95, 0, 0.1), (0.04, 1.1, 2.3), "vitre")
    d.boite((-1.95, 0.05, 0.1), (0.06, 1.0, 2.3), "blanc")
    d.boite((-1.92, 0.05, 0.6), (0.02, 0.85, 1.4), "bleu_ciel")
    d.boite((0, 0, 2.5), (4.1, 1.5, 0.12), "metal_sombre", dessus="galva")
    d.boite((0, 0.38, 0.45), (2.4, 0.38, 0.05), "bois_clair")
    for x in (-1.0, 1.0):
        d.boite((x, 0.4, 0), (0.06, 0.3, 0.45), "metal_sombre")
    # Mât du panneau d'arrêt
    d.cyl((2.4, -0.4, 0), 0.04, 2.8, "galva", n=6)
    d.boite((2.4, -0.4, 2.5), (0.5, 0.04, 0.4), "bleu")
    d.boite((2.4, -0.425, 2.6), (0.3, 0.01, 0.2), "blanc")


def fontaine(d):
    """Fontaine ronde : bassin de pierre, colonne et vasque (Ø 4,4 m)."""
    d.anneau((0, 0, 0), 1.9, 2.2, 0.55, "pierre", n=20, interieur="pierre_sombre")
    d.disque((0, 0, 0.42), 1.92, "eau", n=20)
    d.cyl((0, 0, 0), 0.3, 1.6, "pierre", n=8)
    d.cyl((0, 0, 1.6), 0.25, 0.1, "pierre_sombre", n=10, r2=0.9)
    d.anneau((0, 0, 1.7), 0.8, 0.92, 0.18, "pierre", n=14)
    d.disque((0, 0, 1.82), 0.82, "eau", n=14)
    d.cyl((0, 0, 1.7), 0.12, 0.7, "pierre", n=8)
    d.boule((0, 0, 2.5), 0.14, 0.14, 0.14, "pierre", subdiv=1, alea=0.0)
    d.cyl((0, 0, 2.6), 0.05, 0.35, "bleu_ciel", n=6, r2=0.0)


def fontaine_wallace(d):
    """Fontaine à boire en fonte verte (cariatides et dôme)."""
    d.cyl((0, 0, 0), 0.45, 0.4, "vert_fonte", n=8, r2=0.36)
    d.cyl((0, 0, 0.4), 0.3, 0.3, "vert_fonte", n=8)
    for i in range(4):
        a = math.radians(45 + 90 * i)
        x, y = math.cos(a) * 0.2, math.sin(a) * 0.2
        d.cyl((x, y, 0.7), 0.06, 1.1, "vert_fonte", n=6, r2=0.05)
        d.boule((x, y, 1.85), 0.07, 0.07, 0.09, "vert_fonte", subdiv=1, alea=0.0)
    d.cyl((0, 0, 1.95), 0.32, 0.12, "vert_fonte", n=8)
    d.boule((0, 0, 2.07), 0.3, 0.3, 0.3, "vert_fonte", subdiv=1, alea=0.0, aplatir_bas=1.0)
    d.cone((0, 0, 2.32), 0.06, 0.25, "vert_fonte", n=6)
    d.cyl((0, 0, 1.0), 0.015, 0.7, "bleu_ciel", n=4)


def borne_fontaine(d):
    """Borne-fontaine pour boire."""
    d.cyl((0, 0, 0), 0.18, 1.0, "fonte", n=8, r2=0.14)
    d.cyl((0, 0, 1.0), 0.17, 0.08, "fonte", n=8)
    d.tube((0, 0, 0.85), (0, -0.25, 0.85), 0.03, "galva", n=6)
    d.boite((0, -0.25, 0), (0.5, 0.4, 0.05), "fonte")


# --- Statues et monuments ------------------------------------------------------

def _personnage(d, x, y, z, couleur, bras_leve=False, hauteur=1.9):
    k = hauteur / 1.8
    d.cyl((x - 0.1 * k, y, z), 0.08 * k, 0.85 * k, couleur, n=6, r2=0.07 * k)
    d.cyl((x + 0.1 * k, y, z), 0.08 * k, 0.85 * k, couleur, n=6, r2=0.07 * k)
    d.cyl((x, y, z + 0.8 * k), 0.2 * k, 0.65 * k, couleur, n=8, r2=0.24 * k)
    d.boule((x, y, z + 1.6 * k), 0.12 * k, 0.12 * k, 0.14 * k, couleur, subdiv=1, alea=0.03)
    d.tube((x - 0.24 * k, y, z + 1.4 * k), (x - 0.3 * k, y - 0.1 * k, z + 0.9 * k), 0.06 * k, couleur, n=5)
    if bras_leve:
        d.tube((x + 0.24 * k, y, z + 1.4 * k), (x + 0.45 * k, y - 0.2 * k, z + 2.0 * k), 0.06 * k, couleur, n=5)
    else:
        d.tube((x + 0.24 * k, y, z + 1.4 * k), (x + 0.3 * k, y - 0.15 * k, z + 0.92 * k), 0.06 * k, couleur, n=5)


def statue(d):
    """Statue en bronze sur son piédestal."""
    d.boite((0, 0, 0), (1.6, 1.6, 0.3), "pierre_sombre")
    d.boite((0, 0, 0.3), (1.1, 1.1, 1.6), "pierre")
    d.boite((0, 0, 1.9), (1.3, 1.3, 0.2), "pierre_sombre")
    d.boite((0, -0.56, 0.9), (0.6, 0.03, 0.3), "bronze")
    _personnage(d, 0, 0, 2.1, "bronze_vert", bras_leve=True, hauteur=2.2)


def statue_equestre(d):
    """Cavalier en bronze sur un grand piédestal."""
    d.boite((0, 0, 0), (2.4, 4.0, 0.4), "pierre_sombre")
    d.boite((0, 0, 0.4), (1.8, 3.4, 2.0), "pierre")
    d.boite((0, 0, 2.4), (2.0, 3.6, 0.2), "pierre_sombre")
    from .animaux import cheval_corps
    cheval_corps(d, z=2.6, robe="bronze_vert", crin="bronze_vert", sabot="bronze_vert", echelle=1.25, cabre=True)
    _personnage(d, 0, 0.15, 4.25, "bronze_vert", bras_leve=True, hauteur=1.5)


def buste(d):
    """Buste sur une colonne."""
    d.cyl((0, 0, 0), 0.35, 0.2, "pierre_sombre", n=8)
    d.cyl((0, 0, 0.2), 0.22, 1.2, "pierre", n=8)
    d.cyl((0, 0, 1.4), 0.3, 0.1, "pierre_sombre", n=8)
    d.boule((0, 0, 1.6), 0.28, 0.18, 0.15, "bronze", subdiv=1, alea=0.02)
    d.boule((0, 0, 1.9), 0.13, 0.14, 0.17, "bronze", subdiv=1, alea=0.02)


def monument_morts(d):
    """Monument aux morts : stèle, obélisque et grille."""
    d.boite((0, 0, 0), (3.0, 3.0, 0.3), "pierre_sombre")
    d.boite((0, 0, 0.3), (1.4, 1.4, 1.2), "pierre")
    d.boite((0, -0.71, 0.5), (0.9, 0.02, 0.7), "noir")
    d.cyl((0, 0, 1.5), 0.55, 4.0, "pierre", n=4, r2=0.3, rz=45)
    d.cone((0, 0, 5.5), 0.32, 0.6, "pierre", n=4)
    for i in range(12):
        a = i / 12 * math.tau
        x, y = math.cos(a) * 1.45, math.sin(a) * 1.45
        if abs(y + 1.45) < 0.3:
            continue
        d.cyl((x, y, 0.3), 0.025, 0.7, "fonte", n=4)
    d.boule((-0.5, -0.9, 0.3), 0.2, 0.15, 0.12, "rouge", subdiv=1)


def obelisque(d):
    """Petit obélisque de granit."""
    d.boite((0, 0, 0), (1.4, 1.4, 0.4), "pierre_sombre")
    d.cyl((0, 0, 0.4), 0.45, 5.2, "roche_claire", n=4, r2=0.28, rz=45)
    d.cone((0, 0, 5.6), 0.28, 0.5, "or", n=4)


def panneau_publicite(d):
    """Panneau publicitaire 4 × 3 sur pied."""
    d.cyl((0, 0.1, 0), 0.18, 3.0, "metal_sombre", n=8)
    d.boite((0, 0.1, 3.0), (4.2, 0.3, 3.1), "metal_sombre")
    d.boite((0, -0.06, 3.05), (4.0, 0.02, 3.0), "bleu_ciel")
    d.boite((-0.8, -0.075, 3.6), (1.6, 0.01, 1.8), "jaune")
    d.boite((1.0, -0.075, 4.4), (1.6, 0.01, 0.6), "rouge")
    for x in (-1.5, 0, 1.5):
        d.tube((x, -0.06, 6.1), (x, -0.5, 6.2), 0.025, "metal_sombre", n=4)


def terrasse_cafe(d):
    """Table de café, deux chaises et un parasol."""
    d.cyl((0, 0, 0), 0.25, 0.04, "fonte", n=8)
    d.cyl((0, 0, 0), 0.03, 0.72, "fonte", n=6)
    d.cyl((0, 0, 0.72), 0.33, 0.03, "galva", n=10)
    for a in (0, 180):
        x = math.cos(math.radians(a)) * 0.6
        d.boite((x, 0, 0.42), (0.4, 0.4, 0.04), "bois_clair")
        for (dx, dy) in [(-0.17, -0.17), (0.17, -0.17), (-0.17, 0.17), (0.17, 0.17)]:
            d.cyl((x + dx, dy, 0), 0.015, 0.42, "fonte", n=4)
        sx = 1 if a == 0 else -1
        d.boite((x + sx * 0.2, 0, 0.46), (0.03, 0.4, 0.42), "bois_clair")
    d.cyl((0, 0, 0.75), 0.025, 1.6, "bois", n=6)
    d.cyl((0, 0, 2.05), 1.3, 0.35, "rouge", n=8, r2=0.03)
    d.cyl((0, 0, 2.0), 1.3, 0.05, "tissu_blanc", n=8)
