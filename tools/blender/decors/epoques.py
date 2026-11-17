"""Décors datés : la rue de 1800 à demain, et quelques objets du monde entier.

Avant 1900 : bec de gaz, vespasienne, kiosques, pompe à bras, lavoir,
poteau télégraphique, orgue de Barbarie… Entre-deux-guerres : pompe à essence,
borne routière, cabine de police, entrée de métro Art nouveau. Après 1990 :
bornes de recharge, vélos et trottinettes en libre-service, panneaux solaires,
boîte à livres, conteneurs enterrés, agrès de fitness… Et demain : borne à
drones, mât 5G. Plus des objets du monde : torii, lanterne de papier, chadouf,
drapeaux de prière, yatai, tandoor, totem.
"""

import math

from .base import V
from .urbain import velo, _personnage


# --- XIXe siècle -----------------------------------------------------------------

def bec_gaz(d):
    """Bec de gaz sur colonnette de fonte (1830)."""
    d.cyl((0, 0, 0), 0.16, 0.35, "fonte", n=8)
    d.cyl((0, 0, 0.35), 0.07, 2.6, "fonte", n=8, r2=0.05)
    d.boite((0, 0, 2.95), (0.5, 0.05, 0.05), "fonte")
    d.cyl((0, 0, 3.0), 0.14, 0.42, "lumiere_chaude", n=6, r2=0.2)
    d.cone((0, 0, 3.42), 0.24, 0.22, "fonte", n=6)


def vespasienne(d):
    """Vespasienne : urinoir public en fonte et tôle (Paris, 1834)."""
    d.anneau((0, 0, 0), 0.75, 0.85, 1.8, "vert_fonte", n=10)
    d.cyl((0, 0, 0), 0.25, 2.3, "vert_fonte", n=8)
    d.cyl((0, 0, 2.3), 1.1, 0.12, "vert_fonte", n=10, r2=0.9)
    d.cone((0, 0, 2.42), 0.9, 0.4, "vert_fonte", n=10)
    d.cyl((0, 0, 2.82), 0.08, 0.3, "fonte", n=6)
    d.boule((0, 0, 3.15), 0.12, 0.12, 0.12, "fonte", alea=0)


def kiosque_journaux(d):
    """Kiosque à journaux octogonal, dôme et lanterneau (1857)."""
    d.cyl((0, 0, 0), 0.95, 0.25, "vert_fonte", n=8)
    d.cyl((0, 0, 0.25), 0.9, 1.8, "vert_fonte", n=8)
    for i in range(8):
        a = math.tau * (i + 0.5) / 8
        d.boite((math.cos(a) * 0.9, math.sin(a) * 0.9, 0.9), (0.5, 0.04, 0.9), "jaune" if i % 2 else "blanc", rz=math.degrees(a) + 90)
    d.cyl((0, 0, 2.05), 1.25, 0.12, "vert_fonte", n=8)
    d.cyl((0, 0, 2.17), 1.15, 0.6, "vert_fonte", n=8, r2=0.35)
    d.cyl((0, 0, 2.77), 0.3, 0.3, "fonte", n=8)
    d.cone((0, 0, 3.07), 0.32, 0.35, "vert_fonte", n=8)


def kiosque_musique(d):
    """Kiosque à musique : plateforme, colonnettes et toit en pavillon (1850)."""
    d.cyl((0, 0, 0), 4.0, 1.0, "pierre", n=8)
    for i in range(8):
        a = math.tau * i / 8
        d.cyl((math.cos(a) * 3.6, math.sin(a) * 3.6, 1.0), 0.1, 3.0, "vert_fonte", n=6)
        d.poutre((math.cos(a) * 3.6, math.sin(a) * 3.6, 1.9), (math.cos(a + math.tau / 8) * 3.6, math.sin(a + math.tau / 8) * 3.6, 1.9),
                 0.05, 0.05, "vert_fonte")
    d.cyl((0, 0, 4.0), 4.3, 0.2, "blanc", n=8)
    d.cyl((0, 0, 4.2), 4.1, 1.4, "tuile", n=8, r2=0.3)
    d.cyl((0, 0, 5.6), 0.35, 0.5, "vert_fonte", n=8)
    d.cone((0, 0, 6.1), 0.4, 0.6, "vert_fonte", n=8)
    d.boite((0, -4.0, 0), (1.4, 0.9, 0.5), "pierre_sombre")


def pompe_a_bras(d):
    """Pompe à bras de village, en fonte, avec son auge (1800)."""
    d.boite((0, 0, 0), (0.3, 0.3, 1.3), "fonte")
    d.cone((0, 0, 1.3), 0.22, 0.25, "fonte", n=4)
    d.tube((0, -0.15, 0.9), (0, -0.4, 0.85), 0.04, "fonte", n=6)
    d.tube((0.15, 0, 1.15), (0.75, 0, 1.45), 0.025, "fonte", n=6)
    d.boite((0, -0.55, 0), (0.9, 0.5, 0.45), "pierre_sombre", dessus="eau")


def lavoir(d):
    """Lavoir couvert : bassin de pierre sous un auvent de tuiles (1830)."""
    d.boite((0, 0, 0), (6.0, 3.0, 0.5), "pierre", dessus="eau")
    for x in (-2.7, 2.7):
        for y in (-1.3, 1.3):
            d.boite((x, y, 0.5), (0.3, 0.3, 2.0), "bois_sombre")
    d.boite((0, 1.6, 0), (6.4, 0.4, 2.5), "pierre_sombre")
    d.profil([(-3.4, 2.4), (3.4, 2.4), (3.4, 2.7), (0, 3.6), (-3.4, 2.7)], -1.8, 2.0, "tuile",
             rz=90, cotes="bois_sombre")
    for x in (-1.5, 0, 1.5):
        d.boite((x, -1.6, 0.2), (1.0, 0.4, 0.15), "pierre_sombre", rx=20)


def poteau_telegraphe(d):
    """Poteau télégraphique en bois à isolateurs de verre (1850)."""
    d.cyl((0, 0, 0), 0.12, 7.0, "bois_sombre", n=6, r2=0.09)
    for z in (6.2, 6.7):
        d.boite((0, 0, z), (1.6, 0.1, 0.1), "bois_sombre")
        for x in (-0.65, -0.25, 0.25, 0.65):
            d.cyl((x, 0, z + 0.1), 0.04, 0.12, "vitre", n=5)


def orgue_barbarie(d):
    """Orgue de Barbarie sur sa charrette et son joueur (XIXe siècle)."""
    d.roue((-0.35, 0, 0.3), 0.3, 0.05, "bois_sombre")
    d.roue((0.35, 0, 0.3), 0.3, 0.05, "bois_sombre")
    d.boite((0, 0, 0.35), (0.8, 0.5, 0.06), "bois")
    d.boite((0, 0, 0.41), (0.7, 0.42, 0.55), "rouge_sombre")
    d.boite((0, -0.22, 0.55), (0.55, 0.02, 0.3), "or")
    d.tube((0.36, -0.1, 0.7), (0.5, -0.1, 0.75), 0.02, "metal", n=4)
    _personnage(d, 0.6, 0.35, 0, "bleu", hauteur=1.75)


def chasse_roue(d):
    """Chasse-roue de pierre au coin d'un porche (borne)."""
    d.cyl((0, 0, 0), 0.25, 0.55, "pierre", n=8, r2=0.18)
    d.boule((0, 0, 0.55), 0.18, 0.18, 0.12, "pierre", alea=0)


def cireur(d):
    """Étal de cireur de chaussures, fauteuil haut et parasol (1880)."""
    d.boite((0, 0, 0), (1.2, 0.9, 0.5), "bois_sombre")
    d.boite((0, 0.15, 0.5), (0.6, 0.55, 0.08), "rouge_sombre")
    d.boite((0, 0.4, 0.5), (0.6, 0.08, 0.7), "rouge_sombre")
    for x in (-0.3, 0.3):
        d.boite((x, -0.35, 0.5), (0.12, 0.2, 0.1), "metal")
    d.cyl((0.55, -0.4, 0), 0.03, 2.2, "bois", n=4)
    d.cone((0.55, -0.4, 2.0), 1.0, 0.4, "rouge", n=8)


def malles_bagages(d):
    """Chariot à bagages de gare chargé de malles (1880)."""
    for x in (-0.6, 0.6):
        d.roue((x, -0.3, 0.2), 0.2, 0.06, "fonte", axe="x")
        d.roue((x, 0.3, 0.2), 0.2, 0.06, "fonte", axe="x")
    d.boite((0, 0, 0.35), (1.6, 0.8, 0.06), "bois")
    d.tube((0.8, 0, 0.4), (1.3, 0, 0.9), 0.025, "fonte", n=4)
    d.boite((-0.35, 0, 0.41), (0.8, 0.55, 0.45), "bois_sombre")
    d.boite((-0.35, 0, 0.86), (0.7, 0.5, 0.05), "metal")
    d.boite((0.4, 0, 0.41), (0.6, 0.45, 0.35), "rouge_sombre")
    d.boite((0.4, 0.05, 0.76), (0.45, 0.3, 0.25), "bois_clair")


# --- 1900-1950 ---------------------------------------------------------------------

def pompe_essence_ancienne(d):
    """Pompe à essence à globe et cuve de verre (1920)."""
    d.boite((0, 0, 0), (0.6, 0.6, 0.15), "beton")
    d.boite((0, 0, 0.15), (0.42, 0.42, 1.6), "rouge")
    d.cyl((0, 0, 1.75), 0.18, 0.6, "vitre", n=8)
    d.cyl((0, 0, 2.35), 0.22, 0.06, "rouge", n=8)
    d.boule((0, 0, 2.6), 0.2, 0.2, 0.2, "lumiere", alea=0)
    d.tube((0.21, 0, 1.2), (0.45, -0.1, 0.4), 0.025, "caoutchouc", n=4)
    d.boite((0.47, -0.1, 0.3), (0.06, 0.15, 0.15), "metal")


def borne_routiere(d):
    """Borne routière en béton à chapeau peint (1920)."""
    d.boite((0, 0, 0), (0.5, 0.25, 0.65), "blanc")
    d.cyl((0, 0, 0.65), 0.25, 0.25, "rouge", n=8, rx=90)
    d.boite((0, -0.13, 0.3), (0.38, 0.02, 0.18), "jaune")


def cabine_police(d):
    """Cabine d'appel de police en bois peint, lanterne au toit (1929)."""
    d.boite((0, 0, 0), (1.3, 1.3, 0.15), "beton")
    d.boite((0, 0, 0.15), (1.2, 1.2, 2.3), "bleu")
    for r in (0, 90, 180, 270):
        a = math.radians(r)
        d.boite((math.sin(a) * 0.61, -math.cos(a) * 0.61, 1.5), (0.8, 0.03, 0.6), "vitre", rz=r)
    d.boite((0, 0, 2.45), (1.35, 1.35, 0.2), "bleu")
    d.boite((0, 0, 2.65), (1.0, 1.0, 0.15), "bleu")
    d.cyl((0, 0, 2.8), 0.1, 0.25, "lumiere", n=6)


def entree_metro(d):
    """Entrée de métro Art nouveau : rampes de fonte et lanternes (1900)."""
    for x in (-1.2, 1.2):
        for i in range(5):
            d.boite((x, -1.6 + i * 0.8, 0), (0.06, 0.7, 0.9), "vert_fonte")
        d.tube((x, -2.2, 0), (x, -2.2, 3.0), 0.06, "vert_fonte", n=6)
        d.tube((x, -2.2, 3.0), (x * 0.5, -2.2, 3.5), 0.05, "vert_fonte", n=6)
        d.boule((x * 0.95, -2.2, 3.15), 0.12, 0.08, 0.25, "lumiere_chaude", alea=0)
    d.boite((0, -2.2, 3.0), (1.8, 0.06, 0.4), "jaune")
    d.boite((0, 0, 0), (2.3, 4.0, 0.02), "noir")
    for i in range(4):
        d.boite((0, -1.4 + i * 0.5, 0.02), (2.2, 0.08, 0.01), "pierre_sombre")


def borne_appel(d):
    """Avertisseur d'incendie de rue, colonne rouge (1890)."""
    d.cyl((0, 0, 0), 0.14, 0.2, "rouge_sombre", n=8)
    d.cyl((0, 0, 0.2), 0.09, 1.2, "rouge", n=8)
    d.boite((0, 0, 1.3), (0.3, 0.2, 0.35), "rouge", dessus="rouge_sombre")
    d.boite((0, -0.11, 1.4), (0.14, 0.02, 0.14), "vitre")
    d.cone((0, 0, 1.65), 0.16, 0.2, "rouge_sombre", n=4)


def affiche_reclame(d):
    """Mur peint de réclame sur pignon, pied de bois (1900)."""
    for x in (-1.6, 1.6):
        d.boite((x, 0.1, 0), (0.12, 0.12, 2.8), "bois_sombre")
    d.boite((0, 0, 0.8), (3.6, 0.06, 2.0), "jaune")
    d.boite((0, -0.035, 1.3), (3.0, 0.02, 0.6), "rouge")
    d.boite((0, -0.035, 1.0), (2.2, 0.02, 0.15), "noir")


def sirene_alerte(d):
    """Sirène d'alerte sur mât."""
    d.cyl((0, 0, 0), 0.12, 6.0, "galva", n=6)
    d.cyl((0, 0, 6.0), 0.3, 0.4, "metal_sombre", n=8)
    for r in (0, 120, 240):
        a = math.radians(r)
        d.tube((0, 0, 6.2), (math.cos(a) * 0.55, math.sin(a) * 0.55, 6.25), 0.12, "metal", n=6, r2=0.2)


# --- 1990 et après ---------------------------------------------------------------

def borne_recharge(d):
    """Borne de recharge pour voitures électriques, deux prises (2010)."""
    d.boite((0, 0, 0), (0.6, 0.4, 0.1), "beton")
    d.boite((0, 0, 0.1), (0.42, 0.28, 1.5), "blanc")
    d.boite((0, -0.145, 1.1), (0.3, 0.02, 0.22), "noir")
    d.boite((0, -0.15, 1.15), (0.22, 0.01, 0.12), "feu_vert")
    d.boite((0, 0, 1.6), (0.44, 0.3, 0.04), "vert")
    for x in (-0.25, 0.25):
        d.tube((x, -0.05, 0.9), (x * 1.6, -0.25, 0.2), 0.025, "noir", n=4)


def bornes_recharge_parking(d):
    """Quatre places de recharge sous une ombrière solaire (2015)."""
    for x in (-3.75, -1.25, 1.25, 3.75):
        d.boite((x, 2.2, 0), (0.35, 0.3, 1.4), "blanc")
        d.boite((x, 2.05, 1.0), (0.25, 0.02, 0.15), "feu_vert")
        d.boite((x - 1.25, 0, 0), (0.1, 5.0, 0.02), "blanc")
    for x in (-4, 0, 4):
        d.cyl((x, 2.4, 0), 0.1, 3.2, "galva", n=6)
    d.boite((0, 1.0, 3.2), (10.0, 5.0, 0.12), "galva", rx=-6)
    for x in range(-4, 5, 2):
        d.boite((x, 1.0, 3.33), (1.9, 4.8, 0.04), "bleu", rx=-6)


def velos_libre_service(d):
    """Station de vélos en libre-service : borne et six vélos (2007)."""
    d.boite((-2.4, 0, 0), (0.4, 0.3, 1.8), "metal_sombre")
    d.boite((-2.4, -0.16, 1.2), (0.3, 0.02, 0.4), "vitre")
    d.boite((-2.4, 0, 1.8), (0.5, 0.35, 0.08), "vert")
    for i in range(6):
        x = -1.6 + i * 0.7
        d.boite((x, 0.5, 0), (0.12, 0.12, 0.6), "metal_sombre")
        velo(d, x, 0, rz=90, couleur="vert")


def trottinettes(d):
    """Trottinettes électriques en libre-service garées (2018)."""
    for i, c in enumerate(("vert", "orange", "vert", "noir")):
        x = i * 0.5 - 0.75
        d.boite((x, 0, 0.08), (0.14, 0.9, 0.05), c)
        d.roue((x, -0.45, 0.1), 0.1, 0.05, axe="x")
        d.roue((x, 0.45, 0.1), 0.1, 0.05, axe="x")
        d.tube((x, -0.45, 0.1), (x, -0.5, 1.1), 0.02, "metal_sombre", n=4)
        d.boite((x, -0.5, 1.1), (0.45, 0.04, 0.04), "noir")
    d.boite((0, 0, 0), (2.4, 1.4, 0.01), "blanc")


def abribus_moderne(d):
    """Abribus contemporain en verre, écran d'information (2000)."""
    for x in (-1.8, 1.8):
        d.boite((x, 0.6, 0), (0.08, 0.08, 2.5), "metal")
    d.boite((0, 0.65, 0.1), (3.6, 0.03, 2.3), "vitre")
    d.boite((1.85, 0.1, 0.1), (0.03, 1.1, 2.3), "vitre")
    d.boite((0, 0.1, 2.5), (4.0, 1.5, 0.1), "metal_sombre")
    d.boite((-0.6, 0.45, 0.45), (2.0, 0.35, 0.05), "bois_clair")
    d.boite((-1.65, 0.6, 1.5), (0.4, 0.06, 0.25), "noir")
    d.boite((-1.65, 0.56, 1.55), (0.34, 0.02, 0.16), "orange")


def panneaux_solaires(d):
    """Champ de panneaux solaires au sol, trois rangées (2005)."""
    for j in range(3):
        y = j * 2.5 - 2.5
        for x in (-2.5, 0, 2.5):
            d.boite((x, y + 0.6, 0), (0.08, 0.08, 1.3), "galva")
        d.boite((0, y, 0.6), (7.0, 1.7, 0.06), "galva", rx=-28)
        for i in range(6):
            d.boite((-2.9 + i * 1.16, y, 0.67), (1.1, 1.6, 0.03), "bleu", rx=-28)


def lampadaire_solaire(d):
    """Lampadaire LED autonome à panneau solaire (2012)."""
    d.cyl((0, 0, 0), 0.12, 0.3, "beton", n=8)
    d.cyl((0, 0, 0.3), 0.07, 5.5, "galva", n=8, r2=0.05)
    d.boite((0, 0.1, 5.8), (0.9, 0.6, 0.04), "bleu", rx=25)
    d.tube((0, 0, 5.4), (0, -0.7, 5.5), 0.035, "galva", n=6)
    d.boite((0, -0.85, 5.42), (0.18, 0.45, 0.06), "metal_sombre")
    d.boite((0, -0.85, 5.4), (0.14, 0.38, 0.02), "lumiere")


def boite_livres(d):
    """Boîte à livres en bois sur pied, porte vitrée (2010)."""
    d.boite((0, 0, 0), (0.12, 0.12, 1.0), "bois_sombre")
    d.boite((0, 0, 1.0), (0.7, 0.4, 0.8), "bois")
    d.boite((0, -0.205, 1.08), (0.6, 0.02, 0.64), "vitre")
    for z in (1.12, 1.42):
        for i in range(6):
            d.boite((-0.25 + i * 0.1, 0, z), (0.06, 0.25, 0.24), ("rouge", "bleu", "jaune", "vert", "blanc", "orange")[i])
    d.profil([(-0.42, 1.8), (0.42, 1.8), (0, 2.1)], -0.25, 0.25, "tuile", rz=0)


def conteneurs_enterres(d):
    """Conteneurs enterrés de tri sélectif (bornes d'apport, 2000)."""
    d.boite((0, 0, 0), (4.6, 1.8, 0.05), "beton_sombre")
    for i, c in enumerate(("vert", "jaune", "bleu", "galva")):
        x = -1.65 + i * 1.1
        d.cyl((x, 0, 0.05), 0.4, 1.1, c, n=8, r2=0.35)
        d.cyl((x, 0, 1.15), 0.36, 0.08, "metal_sombre", n=8)
        d.boite((x, -0.38, 0.85), (0.3, 0.04, 0.12), "noir")


def poubelle_solaire(d):
    """Poubelle compacteuse à panneau solaire (2010)."""
    d.boite((0, 0, 0), (0.65, 0.6, 1.2), "vert_fonte")
    d.boite((0, -0.31, 0.75), (0.45, 0.02, 0.25), "noir")
    d.boite((0, 0, 1.2), (0.62, 0.56, 0.03), "bleu", rx=-12)


def totem_info(d):
    """Totem d'information numérique et plan de quartier (2012)."""
    d.boite((0, 0, 0), (0.9, 0.35, 0.1), "beton")
    d.boite((0, 0, 0.1), (0.8, 0.25, 2.2), "metal_sombre")
    d.boite((0, -0.13, 0.7), (0.65, 0.02, 1.3), "bleu_ciel")
    d.boite((0, -0.14, 0.8), (0.5, 0.01, 0.9), "vitre")
    d.boite((0, 0, 2.3), (0.84, 0.28, 0.12), "orange")


def camera_surveillance(d):
    """Mât de vidéosurveillance à deux caméras (1995)."""
    d.cyl((0, 0, 0), 0.1, 5.0, "galva", n=6)
    for s in (-1, 1):
        d.tube((0, 0, 4.8), (s * 0.45, -0.2, 4.8), 0.03, "galva", n=4)
        d.boite((s * 0.5, -0.3, 4.6), (0.14, 0.35, 0.15), "blanc", rx=-15)
    d.boite((0, 0.1, 2.5), (0.3, 0.12, 0.45), "metal_sombre")


def radar_vitesse(d):
    """Radar de contrôle de vitesse sur poteau (2003)."""
    d.cyl((0, 0, 0), 0.08, 2.4, "galva", n=6)
    d.boite((0, 0, 2.4), (0.7, 0.55, 0.75), "metal")
    d.boite((0, -0.28, 2.55), (0.45, 0.02, 0.35), "noir")
    d.cyl((-0.15, -0.3, 2.85), 0.06, 0.03, "vitre", n=8, rx=90)
    d.boite((0, 0, 3.15), (0.75, 0.6, 0.05), "metal_sombre")


def casiers_colis(d):
    """Consigne automatique de colis."""
    d.boite((0, 0, 0), (2.4, 0.7, 2.0), "galva")
    for i in range(6):
        for j in range(4):
            if i in (2, 3) and j in (1, 2):
                continue
            d.boite((-1.0 + i * 0.4, -0.355, 0.15 + j * 0.45), (0.36, 0.02, 0.4), "metal")
    d.boite((0, -0.36, 0.75), (0.6, 0.02, 0.6), "noir")
    d.boite((0, -0.37, 0.95), (0.4, 0.01, 0.3), "bleu_ciel")
    d.boite((0, 0, 2.0), (2.5, 0.75, 0.15), "jaune")


def atelier_velo(d):
    """Station de réparation de vélos en libre accès, pompe et outils (2015)."""
    d.boite((0, 0, 0), (0.2, 0.2, 1.6), "rouge")
    d.tube((0, 0, 1.55), (0.6, 0, 1.65), 0.04, "rouge", n=6)
    d.boite((0.6, 0, 1.45), (0.1, 0.1, 0.25), "metal_sombre")
    for i in range(4):
        d.tube((-0.06 + i * 0.04, -0.11, 1.3), (-0.06 + i * 0.04, -0.11, 1.05), 0.008, "galva", n=3)
    d.cyl((-0.45, 0, 0), 0.06, 0.8, "rouge", n=6)
    d.tube((-0.45, 0, 0.6), (-0.3, -0.1, 0.2), 0.012, "noir", n=3)


def agres_fitness(d):
    """Agrès de fitness en plein air : barres et vélo elliptique (2005)."""
    d.boite((0, 0, 0), (5.0, 3.0, 0.03), "vert")
    for x in (-2.0, -1.0, 0.0):
        d.tube((x, 0.8, 0), (x, 0.8, 2.2), 0.05, "galva", n=6)
    d.tube((-2.0, 0.8, 2.2), (0.0, 0.8, 2.2), 0.03, "galva", n=6)
    d.tube((-2.0, 0.8, 1.6), (-1.0, 0.8, 1.6), 0.03, "galva", n=6)
    d.boite((1.6, 0, 0.03), (0.5, 1.2, 0.15), "galva")
    d.tube((1.6, -0.5, 0.15), (1.6, -0.5, 1.4), 0.05, "vert_fonte", n=6)
    d.tube((1.3, -0.5, 1.4), (1.9, -0.5, 1.4), 0.03, "vert_fonte", n=6)
    for x in (1.4, 1.8):
        d.boite((x, 0.2, 0.25), (0.15, 0.35, 0.04), "noir")
    d.boite((0.7, -0.9, 0.03), (1.2, 0.4, 0.45), "vert_fonte")


def rampe_skate(d):
    """Module de skatepark en béton : rampe, plan incliné et rail (1990)."""
    d.profil([(-3.0, 0), (3.0, 0), (3.0, 1.4), (2.6, 1.4), (1.0, 0.25), (-1.0, 0.25), (-2.6, 1.4), (-3.0, 1.4)],
             -2.0, 2.0, "beton", rz=0, cotes="beton_sombre")
    d.tube((-0.8, -1.2, 0.6), (0.8, -1.2, 0.6), 0.04, "galva", n=6)
    for x in (-0.8, 0.8):
        d.tube((x, -1.2, 0.25), (x, -1.2, 0.6), 0.03, "galva", n=4)


def sanisette(d):
    """Toilette publique automatique."""
    d.boite((0, 0, 0), (1.6, 2.0, 0.1), "beton")
    d.boite((0, 0, 0.1), (1.5, 1.9, 2.4), "beton_sombre")
    d.boite((0, -0.96, 0.1), (0.9, 0.02, 2.0), "metal")
    d.boite((0.55, -0.97, 1.4), (0.2, 0.02, 0.2), "feu_vert")
    d.cyl((0, 0, 2.5), 1.05, 0.3, "vert_fonte", n=10, r2=0.75)


def bac_compost(d):
    """Composteur de quartier en bois, trois bacs (2015)."""
    for i in range(3):
        x = -0.9 + i * 0.9
        for z in range(5):
            d.boite((x, 0, z * 0.18), (0.82, 0.82, 0.14), "bois_clair" if z % 2 else "bois")
        d.boite((x, 0, 0.9), (0.85, 0.85, 0.04), "bois_sombre", rx=-8)
    d.boite((1.4, -0.1, 0), (0.05, 0.05, 1.2), "bois_sombre")
    d.boite((1.4, -0.1, 0.9), (0.4, 0.03, 0.3), "vert")


def jardin_partage(d):
    """Jardin partagé : bacs potagers surélevés et cabane à outils (2000)."""
    for i in range(3):
        for j in range(2):
            x, y = -2.2 + i * 2.0, -1.0 + j * 2.2
            d.boite((x, y, 0), (1.6, 1.2, 0.45), "bois", dessus="terre")
            for k in range(3):
                d.boule((x - 0.5 + k * 0.5, y, 0.55), 0.2, 0.2, 0.14, ("chou", "feuillage", "fruit_rouge")[(i + k) % 3], alea=0.2)
    d.boite((3.3, 0, 0), (1.4, 1.2, 1.9), "bois_gris")
    d.profil([(-0.8, 1.9), (0.8, 1.9), (0, 2.4)], -0.7, 0.7, "metal_sombre", origine=(3.3, 0, 0))


def hotel_insectes(d):
    """Hôtel à insectes : cases de bûches, paille et briques (2010)."""
    for x in (-0.55, 0.55):
        d.boite((x, 0, 0), (0.08, 0.35, 1.5), "bois_sombre")
    for j, c in enumerate(("bois", "paille", "brique", "bois_clair")):
        d.boite((0, 0, 0.1 + j * 0.33), (1.05, 0.3, 0.3), c)
    d.profil([(-0.7, 1.5), (0.7, 1.5), (0, 1.9)], -0.22, 0.22, "tuile")


def banc_connecte(d):
    """Banc solaire connecté : recharge des téléphones (2015)."""
    d.boite((0, 0, 0), (1.9, 0.55, 0.4), "beton")
    d.boite((0, 0, 0.4), (1.9, 0.55, 0.05), "bois_clair")
    d.boite((-0.9, 0.2, 0.45), (0.1, 0.12, 1.1), "metal_sombre")
    d.boite((-0.6, 0.25, 1.55), (0.8, 0.5, 0.04), "bleu", rx=-15)


def mat_5g(d):
    """Mât d'antennes de téléphonie 4G/5G (2019)."""
    d.boite((0, 0, 0), (1.5, 1.5, 0.3), "beton")
    d.cyl((0, 0, 0.3), 0.35, 24.0, "galva", n=8, r2=0.2)
    for z in (22.0, 19.5):
        for r in (0, 120, 240):
            a = math.radians(r)
            d.boite((math.cos(a) * 0.5, math.sin(a) * 0.5, z), (0.3, 0.12, 1.8), "blanc", rz=r + 90)
    d.cyl((0, 0, 24.3), 0.05, 1.5, "galva", n=4)
    d.boite((1.4, 0, 0), (1.0, 0.8, 1.6), "beton_sombre")


def borne_drones(d):
    """Borne de livraison par drones, aire de pose sur le toit (2030)."""
    d.cyl((0, 0, 0), 0.9, 2.6, "blanc", n=8)
    d.boite((0, -0.88, 0.8), (0.8, 0.05, 1.0), "metal_sombre")
    d.cyl((0, 0, 2.6), 1.3, 0.12, "metal_sombre", n=8)
    d.anneau((0, 0, 2.72), 1.0, 1.15, 0.03, "lumiere", n=12)
    d.boite((0, 0, 2.95), (0.5, 0.5, 0.12), "noir")
    for r in (45, 135, 225, 315):
        a = math.radians(r)
        d.tube((0, 0, 3.0), (math.cos(a) * 0.5, math.sin(a) * 0.5, 3.02), 0.02, "noir", n=4)
        d.cyl((math.cos(a) * 0.5, math.sin(a) * 0.5, 3.05), 0.18, 0.01, "metal", n=8)


# --- Objets du monde ----------------------------------------------------------------

def torii(d):
    """Torii : portique shinto en bois laqué vermillon (Japon)."""
    for x in (-1.8, 1.8):
        d.cyl((x, 0, 0), 0.18, 4.2, "rouge", n=8, r2=0.15)
        d.cyl((x, 0, 0), 0.24, 0.4, "noir", n=8)
    d.boite((0, 0, 3.3), (4.4, 0.25, 0.25), "rouge")
    d.boite((0, 0, 3.3), (0.25, 0.22, 0.75), "rouge")
    d.profil([(-2.8, 4.0), (2.8, 4.0), (2.6, 4.3), (-2.6, 4.3)], -0.2, 0.2, "noir")


def lanternes_papier(d):
    """Guirlande de lanternes de papier rouges entre deux mâts (Chine)."""
    for x in (-3, 3):
        d.cyl((x, 0, 0), 0.07, 3.6, "bois_sombre", n=6)
    d.tube((-3, 0, 3.5), (3, 0, 3.3), 0.012, "noir", n=3)
    for i in range(7):
        x = -2.4 + i * 0.8
        d.boule((x, 0, 2.95), 0.22, 0.22, 0.26, "rouge", alea=0)
        d.cyl((x, 0, 2.62), 0.05, 0.1, "or", n=6)


def chadouf(d):
    """Chadouf : puits à balancier, perche et contrepoids (Égypte, Inde)."""
    d.anneau((0, -1.2, 0), 0.45, 0.65, 0.6, "pierre", n=10, interieur="eau")
    d.tube((0.8, 0, 0), (0.8, 0, 2.4), 0.09, "bois_sombre", n=6)
    d.tube((-0.8, 0, 0), (-0.8, 0, 2.4), 0.09, "bois_sombre", n=6)
    d.tube((-0.9, 0, 2.35), (0.9, 0, 2.35), 0.06, "bois_sombre", n=6)
    d.tube((0, 2.0, 1.2), (0, -1.6, 3.2), 0.05, "bois", n=6)
    d.boule((0, 2.0, 1.1), 0.3, 0.3, 0.25, "terre", alea=0.2)
    d.tube((0, -1.6, 3.2), (0, -1.2, 0.9), 0.01, "bois_sombre", n=3)
    d.cyl((0, -1.2, 0.7), 0.15, 0.25, "bois", n=6)


def drapeaux_priere(d):
    """Cordes de drapeaux de prière tendues depuis un mât (Himalaya)."""
    d.cyl((0, 0, 0), 0.08, 5.0, "bois", n=6)
    cols = ("bleu", "blanc", "rouge", "vert", "jaune")
    for k, a in enumerate((-30, 30, 150, 210)):
        r = math.radians(a)
        bx, by = math.cos(r) * 4.5, math.sin(r) * 4.5
        d.tube((0, 0, 4.8), (bx, by, 0.6), 0.01, "noir", n=3)
        d.cyl((bx, by, 0), 0.25, 0.6, "pierre", n=6, r2=0.1)
        for i in range(1, 8):
            t = i / 8
            d.boite((bx * t, by * t, 4.8 - 4.2 * t - 0.3), (0.28, 0.01, 0.28), cols[(i + k) % 5], rz=a + 90)


def yatai(d):
    """Yatai : échoppe de rue sur roues, auvent et lanterne (Japon, 1900)."""
    d.roue((-0.8, 0.5, 0.4), 0.4, 0.06, "bois_sombre", axe="x")
    d.roue((0.8, 0.5, 0.4), 0.4, 0.06, "bois_sombre", axe="x")
    d.boite((0, 0, 0.35), (2.0, 1.1, 0.75), "bois")
    d.boite((0, -0.15, 1.1), (2.1, 0.8, 0.06), "bois_clair")
    for x in (-0.95, 0.95):
        d.boite((x, 0.4, 1.1), (0.08, 0.08, 1.2), "bois_sombre")
    d.boite((0, 0.1, 2.3), (2.3, 1.4, 0.06), "bois_sombre", rx=-8)
    d.boite((0, -0.55, 1.85), (2.0, 0.02, 0.4), "tissu_blanc")
    d.boule((1.1, -0.6, 1.8), 0.15, 0.15, 0.2, "lumiere_chaude", alea=0)
    for x in (-0.6, 0, 0.6):
        d.cyl((x, -0.9, 0), 0.15, 0.6, "bois_sombre", n=6)


def tandoor(d):
    """Four tandoor en argile et sa table de pâte (Inde, Asie centrale)."""
    d.cyl((0, 0, 0), 0.55, 0.9, "terre", n=10, r2=0.45)
    d.anneau((0, 0, 0.9), 0.28, 0.45, 0.08, "brique", n=10, interieur="lumiere_chaude")
    d.boite((1.0, 0, 0), (0.8, 0.6, 0.75), "bois")
    d.boite((1.0, 0, 0.75), (0.85, 0.65, 0.04), "pierre")


def totem(d):
    """Mât totémique sculpté et peint (côte Pacifique Nord-Ouest)."""
    d.cyl((0, 0, 0), 0.4, 0.3, "pierre_sombre", n=8)
    cols = ("rouge_sombre", "bois", "noir", "bleu", "bois_sombre")
    for i in range(5):
        z = 0.3 + i * 1.3
        d.cyl((0, 0, z), 0.32, 1.3, cols[i], n=8, r2=0.3)
        d.boite((0, -0.3, z + 0.7), (0.4, 0.12, 0.2), "blanc")
        d.boite((0, -0.32, z + 0.35), (0.25, 0.14, 0.25), "rouge")
    d.boite((0, 0, 5.4), (2.2, 0.25, 0.5), "rouge_sombre")
    d.cone((0, -0.2, 5.7), 0.3, 0.6, "noir", n=4)


def mur_mani(d):
    """Mur de pierres gravées de prières (mani), Tibet et Népal."""
    d.boite((0, 0, 0), (6.0, 1.0, 1.1), "pierre_sombre")
    d.boite((0, 0, 1.1), (6.2, 1.1, 0.12), "blanc")
    for i in range(12):
        d.boite((-2.75 + i * 0.5, -0.51, 0.25), (0.42, 0.04, 0.6), "pierre" if i % 3 else "roche_claire")
    for x in (-2.8, 2.8):
        d.cyl((x, 0, 1.22), 0.35, 0.4, "blanc", n=8, r2=0.2)


def four_pain(d):
    """Four à pain communal en briques et pierre (village)."""
    d.boite((0, 0, 0), (2.4, 2.4, 0.9), "pierre")
    d.boule((0, 0.2, 0.9), 1.0, 1.0, 0.85, "brique", alea=0, aplatir_bas=1.0)
    d.boite((0, -0.9, 0.9), (0.6, 0.4, 0.55), "brique")
    d.boite((0, -1.11, 0.95), (0.4, 0.02, 0.35), "noir")
    d.cyl((0.4, 0.6, 1.4), 0.15, 0.8, "brique", n=6)
