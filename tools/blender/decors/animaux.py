"""Animaux de ferme et des grands espaces, à taille réelle, tête vers -Y."""

import math


def _pattes(d, xs, ys, h, ep, couleur, sabot="sabot", leve=None):
    """Quatre pattes (boîtes) ; leve : indice d'une patte avant pliée vers l'avant."""
    i = 0
    for y in ys:
        for x in xs:
            if leve is not None and i == leve:
                d.poutre((x, y, h), (x, y - h * 0.45, h * 0.62), ep, ep, couleur)
                d.poutre((x, y - h * 0.45, h * 0.62), (x, y - h * 0.32, h * 0.3), ep * 0.9, ep * 0.9, couleur)
            else:
                d.boite((x, y, 0.1), (ep, ep, h - 0.1), couleur)
                d.boite((x, y, 0), (ep * 1.05, ep * 1.05, 0.1), sabot)
            i += 1


def bovin(d, robe="pelage_blanc", taches=None, tete_basse=False, echelle=1.0, cornes=True, bosse=False, pis=True):
    """Vache générique : corps en boîte, pattes, tête, cornes, pis, queue."""
    k = echelle
    _pattes(d, (-0.24 * k, 0.24 * k), (-0.62 * k, 0.62 * k), 0.72 * k, 0.16 * k,
            robe if not taches else taches[0])
    d.boite((0, 0, 0.66 * k), (0.72 * k, 1.75 * k, 0.72 * k), robe)
    d.boite((0, 0.05 * k, 0.6 * k), (0.6 * k, 1.4 * k, 0.1 * k), robe)
    if taches:
        tc = taches[0]
        for (y, z, sy, sz, cote) in ((-0.3, 0.95, 0.5, 0.35, 1), (0.45, 0.85, 0.45, 0.45, 1),
                                     (0.1, 1.05, 0.55, 0.3, -1), (-0.55, 0.8, 0.3, 0.3, -1)):
            d.boite((cote * 0.362 * k, y * k, z * k), (0.01, sy * k, sz * k), tc)
        d.boite((0, 0.2 * k, 1.381 * k), (0.4 * k, 0.6 * k, 0.01), tc)
    if bosse:
        d.boule((0, -0.6 * k, 1.42 * k), 0.22 * k, 0.25 * k, 0.22 * k, robe, subdiv=1, alea=0.05)
    # Cou et tête
    if tete_basse:
        d.poutre((0, -0.8 * k, 1.15 * k), (0, -1.15 * k, 0.55 * k), 0.36 * k, 0.4 * k, robe)
        hz, hy = 0.32 * k, -1.25 * k
    else:
        d.poutre((0, -0.8 * k, 1.15 * k), (0, -1.05 * k, 1.25 * k), 0.38 * k, 0.45 * k, robe)
        hz, hy = 1.05 * k, -1.2 * k
    tete = taches[1] if taches and len(taches) > 1 else robe
    d.boite((0, hy, hz), (0.36 * k, 0.42 * k, 0.4 * k), tete)
    d.boite((0, hy - 0.24 * k, hz), (0.3 * k, 0.12 * k, 0.22 * k), "museau")
    for s in (-1, 1):
        d.boite((s * 0.24 * k, hy + 0.1 * k, hz + 0.3 * k), (0.14 * k, 0.06 * k, 0.07 * k), robe)
        if cornes:
            d.tube((s * 0.14 * k, hy + 0.08 * k, hz + 0.4 * k), (s * 0.3 * k, hy + 0.0, hz + 0.52 * k), 0.025 * k,
                   "corne", n=4, r2=0.01 * k)
        d.boite((s * 0.15 * k, hy - 0.08 * k, hz + 0.24 * k), (0.06 * k, 0.03 * k, 0.05 * k), "noir")
    if pis:
        d.boite((0, 0.55 * k, 0.52 * k), (0.28 * k, 0.3 * k, 0.15 * k), "museau")
    d.tube((0, 0.875 * k, 1.3 * k), (0, 0.95 * k, 0.55 * k), 0.03 * k, robe, n=4)
    d.boite((0, 0.95 * k, 0.45 * k), (0.07 * k, 0.07 * k, 0.15 * k), taches[0] if taches else "pelage_noir")


def vache_pie_noire(d):
    """Vache prim'holstein, pie noire."""
    bovin(d, "pelage_blanc", taches=("pelage_noir", "pelage_noir"))


def vache_broute(d):
    """Vache pie noire qui broute, tête dans l'herbe."""
    bovin(d, "pelage_blanc", taches=("pelage_noir", "pelage_blanc"), tete_basse=True)


def vache_rousse(d):
    """Vache montbéliarde, pie rouge à tête blanche."""
    bovin(d, "pelage_roux", taches=("pelage_blanc", "pelage_blanc"))


def vache_blanche(d):
    """Vache charolaise, toute crème."""
    bovin(d, "pelage_creme", echelle=1.05, pis=False)


def vache_broute_rousse(d):
    """Vache rousse qui broute."""
    bovin(d, "pelage_roux", tete_basse=True, cornes=False)


def veau(d):
    """Veau."""
    bovin(d, "pelage_roux", taches=("pelage_blanc",), echelle=0.6, cornes=False, pis=False)


def zebu(d):
    """Zébu à bosse (Afrique, Inde)."""
    bovin(d, "gris_ane", echelle=0.95, bosse=True, pis=False)


def yack(d):
    """Yack à longs poils (Himalaya)."""
    bovin(d, "pelage_noir", echelle=1.0, pis=False)
    d.boite((0, 0, 0.45), (0.8, 1.7, 0.3), "pelage_noir")


# --- Chevaux et ânes ----------------------------------------------------------

def cheval_corps(d, z=0.0, robe="cheval_bai", crin="pelage_noir", sabot="sabot", echelle=1.0, cabre=False,
                 tete_basse=False, oreilles=0.12):
    k = echelle
    if z:
        # Les pattes partent du socle : on décale tout en z.
        pass
    from .base import V
    def P(x, y, zz):
        return (x, y, z + zz)
    i = 0
    for y in (-0.62 * k, 0.62 * k):
        for x in (-0.2 * k, 0.2 * k):
            if cabre and i == 0:
                d.poutre(P(x, y, 0.95 * k), P(x, y - 0.4 * k, 0.62 * k), 0.12 * k, 0.12 * k, robe)
                d.poutre(P(x, y - 0.4 * k, 0.62 * k), P(x, y - 0.25 * k, 0.32 * k), 0.11 * k, 0.11 * k, robe)
            else:
                d.boite(P(x, y, 0.1 * k), (0.12 * k, 0.12 * k, 0.88 * k), robe)
                d.boite(P(x, y, 0), (0.14 * k, 0.14 * k, 0.1 * k), sabot)
            i += 1
    d.boite(P(0, 0, 0.92 * k), (0.52 * k, 1.6 * k, 0.6 * k), robe)
    d.boule(P(0, -0.7 * k, 1.25 * k), 0.27 * k, 0.25 * k, 0.32 * k, robe, subdiv=1, alea=0.03)
    d.boule(P(0, 0.7 * k, 1.25 * k), 0.27 * k, 0.25 * k, 0.3 * k, robe, subdiv=1, alea=0.03)
    if tete_basse:
        d.poutre(P(0, -0.75 * k, 1.35 * k), P(0, -1.15 * k, 0.55 * k), 0.24 * k, 0.32 * k, robe)
        d.poutre(P(0, -1.12 * k, 0.6 * k), P(0, -1.3 * k, 0.12 * k), 0.2 * k, 0.24 * k, robe)
        d.boite(P(0, -0.98 * k, 1.0 * k), (0.06 * k, 0.4 * k, 0.12 * k), crin, rx=60)
        hy, hz = -1.18 * k, 0.55 * k
    else:
        d.poutre(P(0, -0.75 * k, 1.3 * k), P(0, -1.05 * k, 1.95 * k), 0.24 * k, 0.36 * k, robe)
        d.poutre(P(0, -1.0 * k, 2.02 * k), P(0, -1.45 * k, 1.72 * k), 0.2 * k, 0.24 * k, robe)
        d.poutre(P(0, -0.72 * k, 1.5 * k), P(0, -0.95 * k, 2.1 * k), 0.06 * k, 0.12 * k, crin)
        hy, hz = -1.0 * k, 2.08 * k
    for s in (-1, 1):
        d.boite(P(s * 0.06 * k, hy, hz), (0.05 * k, 0.05 * k, oreilles * k), robe)
    d.tube(P(0, 0.8 * k, 1.4 * k), P(0, 1.0 * k, 0.6 * k), 0.06 * k, crin, n=5, r2=0.03 * k)


def cheval(d):
    """Cheval bai à crinière noire."""
    cheval_corps(d)


def cheval_blanc(d):
    """Cheval gris clair qui broute."""
    cheval_corps(d, robe="pelage_blanc", crin="pelage_creme", tete_basse=True)


def cheval_noir(d):
    """Cheval noir."""
    cheval_corps(d, robe="pelage_noir", crin="pelage_noir")


def poney(d):
    """Poney alezan."""
    cheval_corps(d, robe="pelage_roux", crin="pelage_creme", echelle=0.7)


def ane(d):
    """Âne gris aux grandes oreilles."""
    cheval_corps(d, robe="gris_ane", crin="pelage_noir", echelle=0.78, oreilles=0.32)


# --- Petits animaux -------------------------------------------------------------

def mouton(d, laine="laine", tete="pelage_noir", tete_basse=False, echelle=1.0):
    k = echelle
    _pattes(d, (-0.15 * k, 0.15 * k), (-0.32 * k, 0.32 * k), 0.42 * k, 0.07 * k, tete)
    d.boule((0, 0, 0.68 * k), 0.36 * k, 0.55 * k, 0.32 * k, laine, subdiv=1, alea=0.12)
    d.boule((0, -0.15 * k, 0.8 * k), 0.3 * k, 0.35 * k, 0.26 * k, laine, subdiv=1, alea=0.12)
    if tete_basse:
        d.poutre((0, -0.42 * k, 0.72 * k), (0, -0.62 * k, 0.3 * k), 0.2 * k, 0.24 * k, laine)
        d.boite((0, -0.66 * k, 0.12 * k), (0.18 * k, 0.28 * k, 0.2 * k), tete, rx=40)
        hz = 0.3
    else:
        d.boite((0, -0.62 * k, 0.75 * k), (0.18 * k, 0.28 * k, 0.22 * k), tete, rx=-25)
        hz = 0.9
    for s in (-1, 1):
        d.boite((s * 0.14 * k, -0.58 * k, hz * k), (0.12 * k, 0.04 * k, 0.05 * k), tete)


def brebis(d):
    """Brebis blanche à tête noire."""
    mouton(d)


def mouton_broute(d):
    """Mouton qui broute."""
    mouton(d, laine="laine", tete="pelage_creme", tete_basse=True)


def agneau(d):
    """Agneau."""
    mouton(d, laine="pelage_blanc", tete="pelage_blanc", echelle=0.6)


def chevre(d):
    """Chèvre à barbiche et cornes recourbées."""
    _pattes(d, (-0.12, 0.12), (-0.33, 0.33), 0.5, 0.06, "pelage_roux")
    d.boite((0, 0, 0.48), (0.32, 0.85, 0.36), "pelage_roux")
    d.poutre((0, -0.38, 0.75), (0, -0.52, 0.98), 0.14, 0.18, "pelage_roux")
    d.boite((0, -0.62, 0.92), (0.16, 0.28, 0.17), "pelage_roux", rx=-20)
    d.boite((0, -0.7, 0.8), (0.05, 0.06, 0.1), "pelage_creme")
    for s in (-1, 1):
        d.tube((s * 0.05, -0.56, 1.06), (s * 0.08, -0.45, 1.22), 0.02, "corne", n=4, r2=0.008)
        d.boite((s * 0.11, -0.56, 1.0), (0.1, 0.04, 0.04), "pelage_roux")
    d.boite((0, 0.44, 0.75), (0.05, 0.04, 0.12), "pelage_roux")


def cochon(d):
    """Cochon rose."""
    _pattes(d, (-0.16, 0.16), (-0.38, 0.38), 0.3, 0.09, "cochon", sabot="museau")
    d.boule((0, 0, 0.55), 0.34, 0.6, 0.3, "cochon", subdiv=1, alea=0.04)
    d.boule((0, -0.55, 0.58), 0.22, 0.2, 0.2, "cochon", subdiv=1, alea=0.03)
    d.tube((0, -0.68, 0.55), (0, -0.8, 0.55), 0.09, "museau", n=8)
    for s in (-1, 1):
        d.boite((s * 0.12, -0.6, 0.74), (0.1, 0.03, 0.1), "cochon", rx=-30)
    d.tube((0, 0.6, 0.6), (0.05, 0.68, 0.68), 0.015, "cochon", n=4)


def poule(d, plumage="pelage_blanc"):
    d.boule((0, 0, 0.28), 0.14, 0.2, 0.15, plumage, subdiv=1, alea=0.05)
    d.boule((0, -0.15, 0.43), 0.08, 0.08, 0.09, plumage, subdiv=1, alea=0.02)
    d.boite((0, -0.22, 0.42), (0.03, 0.06, 0.03), "bec")
    d.boite((0, -0.15, 0.5), (0.02, 0.08, 0.06), "rouge")
    d.boite((0, 0.2, 0.32), (0.04, 0.12, 0.16), plumage, rx=25)
    for s in (-1, 1):
        d.cyl((s * 0.05, 0, 0), 0.012, 0.16, "bec", n=4)


def poule_blanche(d):
    """Poule blanche."""
    poule(d)


def poule_rousse(d):
    """Poule rousse."""
    poule(d, "pelage_roux")


def canard(d):
    """Canard colvert (posé sur l'eau ou au sol)."""
    d.boule((0, 0, 0.12), 0.13, 0.22, 0.1, "pierre_sombre", subdiv=1, alea=0.03)
    d.boule((0, -0.16, 0.26), 0.07, 0.08, 0.07, "vert_fonte", subdiv=1, alea=0.02)
    d.boite((0, -0.25, 0.24), (0.06, 0.09, 0.025), "jaune")
    d.boite((0, 0.2, 0.15), (0.06, 0.08, 0.05), "noir", rx=30)


def chien(d):
    """Chien de ferme."""
    _pattes(d, (-0.1, 0.1), (-0.25, 0.25), 0.38, 0.06, "pelage_roux", sabot="pelage_blanc")
    d.boite((0, 0, 0.36), (0.24, 0.65, 0.24), "pelage_roux")
    d.boite((0, -0.35, 0.52), (0.2, 0.22, 0.2), "pelage_roux")
    d.boite((0, -0.5, 0.52), (0.12, 0.12, 0.1), "pelage_blanc")
    d.boite((0, -0.565, 0.56), (0.05, 0.02, 0.04), "noir")
    for s in (-1, 1):
        d.boite((s * 0.08, -0.32, 0.72), (0.05, 0.04, 0.09), "pelage_noir")
    d.tube((0, 0.32, 0.52), (0, 0.5, 0.72), 0.03, "pelage_roux", n=4, r2=0.015)


def dromadaire(d):
    """Dromadaire à une bosse (désert)."""
    _pattes(d, (-0.22, 0.22), (-0.55, 0.55), 1.3, 0.12, "sable", sabot="pierre_sombre")
    d.boule((0, 0, 1.55), 0.38, 0.9, 0.35, "sable", subdiv=1, alea=0.04)
    d.boule((0, 0.05, 1.9), 0.3, 0.42, 0.38, "sable", subdiv=1, alea=0.06)
    d.poutre((0, -0.75, 1.5), (0, -1.25, 1.95), 0.18, 0.22, "sable")
    d.poutre((0, -1.25, 1.9), (0, -1.3, 2.35), 0.16, 0.18, "sable")
    d.boite((0, -1.45, 2.3), (0.2, 0.42, 0.18), "sable")
    d.tube((0, 0.85, 1.6), (0, 0.95, 1.0), 0.03, "sable", n=4)


def lama(d):
    """Lama des Andes."""
    _pattes(d, (-0.13, 0.13), (-0.38, 0.38), 0.8, 0.08, "pelage_creme", sabot="pierre_sombre")
    d.boule((0, 0, 0.95), 0.25, 0.55, 0.25, "pelage_creme", subdiv=1, alea=0.06)
    d.poutre((0, -0.45, 1.0), (0, -0.55, 1.75), 0.14, 0.17, "pelage_creme")
    d.boite((0, -0.65, 1.66), (0.15, 0.3, 0.15), "pelage_creme")
    for s in (-1, 1):
        d.boite((s * 0.05, -0.52, 1.82), (0.04, 0.04, 0.14), "pelage_creme")
    d.boite((0, 0.55, 1.0), (0.1, 0.08, 0.12), "pelage_creme")


def renne(d):
    """Renne de Laponie et ses bois."""
    _pattes(d, (-0.15, 0.15), (-0.5, 0.5), 0.75, 0.09, "pelage_roux", sabot="pelage_noir")
    d.boite((0, 0, 0.72), (0.45, 1.3, 0.48), "pelage_roux")
    d.boite((0, -0.55, 0.82), (0.44, 0.3, 0.4), "pelage_creme")
    d.poutre((0, -0.55, 1.05), (0, -0.85, 1.42), 0.2, 0.26, "pelage_creme")
    d.boite((0, -1.0, 1.32), (0.18, 0.35, 0.18), "pelage_roux")
    for s in (-1, 1):
        a = (s * 0.06, -0.9, 1.5)
        b = (s * 0.35, -0.75, 2.05)
        d.tube(a, b, 0.025, "corne", n=4)
        d.tube((s * 0.2, -0.82, 1.75), (s * 0.15, -1.05, 1.95), 0.018, "corne", n=4)
        d.tube((s * 0.3, -0.77, 1.95), (s * 0.5, -0.9, 2.15), 0.018, "corne", n=4)
