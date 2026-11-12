"""Fermes et agriculture de la bible : corps de ferme régionaux, granges,
étables, élevages, serres, silos, moulins et caves. Formes simplifiées
d'après des types réels (champ `source`)."""

import math

from registre import batiment

F = "fermes"
FERMIER = [["agriculteur", 1]]
ELEVEUR = [["eleveur", 2], ["agriculteur", 1]]


def fen(**kw):
    d = {"l": 1.0, "h": 1.2}
    d.update(kw)
    return d


def grande_porte(k, cx, cy, L, P, cote, u, l, h, c="bois_sombre", cadre="bois_clair", forme="rect"):
    (fx, fy), n, _ = k._facades(cx, cy, L, P)[cote]
    k.ouverture(fx, fy, n, u, h / 2, l, h, c, cadre, forme)


def gambrel(k, cx, cy, z, L, P, c, axe="y", bouts=None):
    """Toit de grange à la Mansart américaine (gambrel)."""
    hp = P / 2
    prof = [(-hp - 0.4, -0.3), (-hp * 0.62, 2.8), (0, 4.6), (hp * 0.62, 2.8), (hp + 0.4, -0.3)]
    k.toit_profil(cx, cy, z, L + 0.6, prof, c, axe=axe, bouts=bouts)


@batiment(F, "ferme_cour_carree", "Ferme à cour carrée", "industrie", 1_600_000,
          "Logis, granges et étables de briques fermant une cour, porche d'entrée.",
          "Fermes picardes et flamandes à cour fermée", era="traditionnel", emplois=4, logements=1,
          metiers=FERMIER, role="ferme", zone="I", access=["route", "chemin"])
def cour_carree(k):
    S = 34.0
    k.sol(0, 0, S - 10, S - 10, "terre", h=0.03)
    k.corps(0, S / 2 - 4, 0, S, 8, 2, 3.0, "brique", fen=fen(avant=6, arriere=4, l=1.0, h=1.3, cadre="pierre_claire",
                                                              volets="bois_rouge"),
            porte={"l": 1.0, "h": 2.2, "couleur": "bois_rouge", "cote": "avant"})
    k.toit_2pans(0, S / 2 - 4, 6.0, S, 8, 3.0, "tuile", axe="x", pignon="brique", debord=0.4)
    for s in (-1, 1):
        x = s * (S / 2 - 4)
        k.boite(x, -2, 0, 8, S - 12, 5.0, "brique")
        grande_porte(k, x, -2, 8, S - 12, "droite" if s < 0 else "gauche", 0, 3.6, 4.0)
        k.toit_2pans(x, -2, 5.0, S - 12, 8, 3.4, "tuile", axe="y", pignon="brique", debord=0.4)
    for s in (-1, 1):
        k.boite(s * 10.5, -S / 2 + 4, 0, 13, 8, 4.5, "brique")
        k.toit_2pans(s * 10.5, -S / 2 + 4, 4.5, 13, 8, 3.0, "tuile", axe="x", pignon="brique", debord=0.4)
    k.boite(0, -S / 2 + 4, 0, 8, 8, 6.0, "brique")
    grande_porte(k, 0, -S / 2 + 4, 8, 8, "avant", 0, 3.6, 4.2, "bois_sombre", "pierre_claire", "arc")
    k.toit_2pans(0, -S / 2 + 4, 6.0, 8, 8, 2.6, "tuile", axe="y", pignon="brique", debord=0.3)


@batiment(F, "ferme_jurassienne", "Ferme jurassienne", "industrie", 1_100_000,
          "Grande ferme sous un seul toit très large, logis, étable et grange réunis.",
          "Fermes du Jura suisse et du Haut-Doubs (tuyé)", era="traditionnel", emplois=3, logements=1,
          metiers=ELEVEUR, role="ferme", zone="I", access=["route", "chemin"])
def jurassienne(k):
    L, P = 24.0, 20.0
    k.corps(0, 0, 0, L, P, 2, 3.0, "enduit", fen=fen(avant=3, gauche=4, l=0.9, h=1.1, cadre="pierre_claire",
                                                      volets="vert"),
            porte={"l": 1.0, "h": 2.1, "couleur": "bois_sombre", "u": -6.0}, socle="pierre_grise")
    grande_porte(k, 0, 0, L, P, "avant", 5.0, 3.6, 3.6, "bois", "pierre_claire", "arc")
    k.toit_2pans(0, 0, 6.0, P, L, 4.6, "zinc", axe="y", pignon="bois_gris", debord=0.8)
    k.cheminee(-6, 2, 10.0, 1.8, "enduit", l=1.4)


@batiment(F, "ferme_bavaroise", "Ferme bavaroise", "industrie", 1_300_000,
          "Einhof alpin : logis blanc à balcons fleuris, grange de bois dans le prolongement.",
          "Fermes de Haute-Bavière et du Tyrol", era="traditionnel", emplois=3, logements=1,
          metiers=ELEVEUR, role="ferme", zone="I", access=["route", "chemin"])
def bavaroise(k):
    k.corps(0, -6, 0, 13, 12, 2, 2.8, "enduit_blanc", fen=fen(avant=4, gauche=3, droite=3, l=0.9, h=1.1,
                                                                volets="vert", cadre="bois_sombre"),
            porte={"l": 1.1, "h": 2.1, "couleur": "bois_sombre"})
    k.balcons(0, -6, 0, 13, 12, 2, 2.8, "avant", nb=1, prof=1.2, dalle="bois_sombre", garde="bois")
    k.corps(0, 8, 0, 13, 16, 1, 6.0, "bois", fen=fen(gauche=2, droite=2, l=0.8, h=0.8, vitre="vitre",
                                                     cadre="bois_sombre"))
    grande_porte(k, 0, 8, 13, 16, "droite", 0, 3.6, 3.8)
    k.toit_2pans(0, 1, 5.8, 28, 13, 2.6, "tuile", axe="y", pignon="bois", debord=1.2)


@batiment(F, "cortijo", "Cortijo andalou", "industrie", 1_400_000,
          "Ferme blanchie autour d'un patio, tour de guet et tuiles canal.",
          "Cortijos de la campagne de Séville et de Cordoue", region="mediterranee", era="traditionnel",
          emplois=4, logements=1, metiers=FERMIER, role="ferme", zone="I", access=["route", "chemin"])
def cortijo(k):
    S = 28.0
    for (x, y, l, p) in ((0, S / 2 - 3, S, 6), (0, -S / 2 + 3, S, 6), (-S / 2 + 3, 0, 6, S - 12),
                         (S / 2 - 3, 0, 6, S - 12)):
        k.boite(x, y, 0, l, p, 4.0, "enduit_blanc")
        k.toit_2pans(x, y, 4.0, l if l > p else p, p if l > p else l, 1.4, "tuile", axe="x" if l > p else "y",
                     pignon="enduit_blanc", debord=0.3)
    (fx, fy), n, lg = k._facades(0, 0, S, S)["avant"]
    k.porte(fx, fy, n, 0, 0, 3.0, 3.4, "bois_sombre", "ocre", "arc")
    for u in (-9, -5, 5, 9):
        k.ouverture(fx, fy, n, u, 2.2, 0.8, 1.1, "vitre", "ocre", volets="vert")
    k.boite(S / 2 - 3, S / 2 - 3, 4.0, 5, 5, 5.0, "enduit_blanc")
    k.toit_4pans(S / 2 - 3, S / 2 - 3, 9.0, 5, 5, 1.6, "tuile", debord=0.2)


@batiment(F, "hacienda", "Hacienda", "industrie", 2_000_000,
          "Maison de maître à arcades, chapelle et dépendances autour d'une grande cour.",
          "Haciendas du Yucatán et du centre du Mexique", region="ameriques", era="classique",
          emplois=10, logements=2, metiers=[["agriculteur", 3], ["eleveur", 1], ["cadre", 1]], role="ferme",
          zone="I", access=["route", "chemin"])
def hacienda(k):
    k.corps(0, 8, 0, 30, 10, 1, 5.0, "ocre", fen=fen(avant=6, arriere=6, l=1.4, h=2.4, forme="arc", cadre="blanc",
                                                      vitre="vitre"),
            porte={"l": 2.4, "h": 3.4, "couleur": "bois_sombre", "forme": "arc"})
    k.arcade(0, 8, 0, 30, 8, 4.0, 3.5, "enduit_blanc", cote_y=3.0 + 3.5 - 3.5)
    k.toit_plat(0, 8, 5.0, 30, 10, "terre", acrotere=0.6, c_acrotere="ocre")
    k.boite(-18, 4, 0, 6, 12, 7.0, "enduit_blanc")
    k.toit_2pans(-18, 4, 7.0, 12, 6, 2.0, "tuile", axe="y", pignon="enduit_blanc")
    k.clocher(-18, -2.5, 0, 3.0, 10.0, "enduit_blanc", fleche="tuile", forme="pyramide", h_fleche=6)
    for s in (-1, 1):
        k.boite(s * 12, -10, 0, 8, 12, 3.6, "terre")
        k.toit_mono(s * 12, -10, 3.6, 8, 12, 0.8, "tuile", mur="terre")


@batiment(F, "grange_americaine", "Grange américaine", "industrie", 600_000,
          "Grande grange rouge à toit gambrel, portes à croix blanches et silo.",
          "Granges du Midwest et du Wisconsin", region="ameriques", era="classique", emplois=2,
          metiers=ELEVEUR, role="elevage", zone="I", access=["route", "chemin"])
def grange_us(k):
    L, P = 14.0, 24.0
    k.boite(0, 0, 0, L, P, 5.0, "bardage_rouge")
    gambrel(k, 0, 0, 5.0, P, L, "noir", axe="y", bouts="bardage_rouge")
    (fx, fy), n, _ = k._facades(0, 0, L, P)["avant"]
    k.ouverture(fx, fy, n, 0, 2.0, 4.0, 4.0, "bardage_rouge", "blanc")
    k.ouverture(fx, fy, n, 0, 7.5, 1.6, 1.6, "bois_sombre", "blanc")
    for s in (-1, 1):
        y = -P / 2 - 0.06
        k.b.face_orientee([(s * 1.9, y, 0.1), (-s * 2.0, y, 3.9), (-s * 1.75, y, 3.9), (s * 2.05, y, 0.1)],
                          "blanc", (0, -1, 0))
    for cote in ("gauche", "droite"):
        (fx, fy), n, lg = k._facades(0, 0, L, P)[cote]
        for i in range(4):
            k.ouverture(fx, fy, n, -lg / 2 + 3 + i * 6, 3.0, 1.0, 1.0, "vitre", "blanc")
    k.silo(L / 2 + 3.5, 4, 3.0, 16, "beton_clair", toit="dome", c_toit="zinc")


@batiment(F, "etable_moderne", "Stabulation laitière", "industrie", 1_800_000,
          "Stabulation libre de 120 vaches, côtés ouverts à filets brise-vent, fosse à lisier.",
          "Exploitations laitières de Normandie et de Bretagne", era="contemporain", emplois=4,
          metiers=ELEVEUR, role="elevage", zone="I", access=["route", "chemin"])
def stabulation(k):
    L, P = 60.0, 30.0
    k.boite(0, 0, 0, L, P, 1.2, "beton_clair")
    k.boite(0, 0, 1.2, L, P, 2.8, "bardage_vert")
    for i in range(11):
        for s in (-1, 1):
            k.boite(-L / 2 + i * L / 10, s * P / 2, 0, 0.3, 0.3, 4.6, "metal")
    k.toit_2pans(0, 0, 4.6, L, P, 3.4, "tole", axe="x", debord=0.8, pignon="bois_gris")
    k.boite(0, 0, 4.6 + 3.4 + 0.1, L, 1.6, 0.4, "verre_clair")
    k.cyl(L / 2 + 10, 0, 0, 3.0, 9.0, "beton_sombre", n=14)
    k.cyl(L / 2 + 10, 0, 2.8, 0.3, 8.6, "terre", n=14)
    k.corps(-L / 2 - 6, 8, 0, 10, 10, 1, 4, "bardage", fen=fen(avant=2, l=1.4, h=1.0, vitre="verre_ciel"),
            porte={"l": 1.2, "h": 2.2, "couleur": "bleu"})
    k.toit_mono(-L / 2 - 6, 8, 4, 10, 10, 1.2, "tole", mur="bardage")
    k.silo(-L / 2 - 6, -6, 2.4, 12, "bardage_bleu", toit="dome", c_toit="blanc")


@batiment(F, "bergerie", "Bergerie", "industrie", 450_000,
          "Bergerie de pierre sèche à toit de lauzes et enclos.",
          "Bergeries des Causses et du Larzac", region="mediterranee", era="traditionnel", emplois=2,
          metiers=ELEVEUR, role="elevage", zone="I", access=["route", "chemin"])
def bergerie(k):
    k.corps(0, 0, 0, 22, 9, 1, 3.4, "pierre", fen=fen(avant=3, l=0.5, h=0.7, cadre=None, vitre="vitre"))
    grande_porte(k, 0, 0, 22, 9, "avant", 0, 2.4, 2.6, "noir", "pierre_claire", "arc")
    k.toit_2pans(0, 0, 3.4, 22, 9, 3.0, "pierre_grise", axe="x", pignon="pierre", debord=0.3, rangs=5)
    k.cloture([(-12, -6), (12, -6), (12, -16), (-12, -16)], h=1.2, c="pierre_grise")


@batiment(F, "poulailler", "Poulailler industriel", "industrie", 900_000,
          "Long bâtiment avicole de 100 m, ventilateurs en pignon et silos d'aliment.",
          "Poulaillers label de Bretagne et des Landes", era="contemporain", emplois=2,
          metiers=ELEVEUR, role="elevage", zone="I", access=["route", "chemin"])
def poulailler(k):
    L, P = 100.0, 14.0
    k.corps(0, 0, 0, L, P, 1, 2.8, "bardage_vert", fen=fen(avant=1, arriere=1, bande=True, h=0.5, vitre="vitre"))
    k.toit_2pans(0, 0, 2.8, L, P, 1.8, "tole", axe="x", debord=0.4, pignon="bardage_vert")
    (fx, fy), n, _ = k._facades(0, 0, L, P)["droite"]
    for u in (-4, 0, 4):
        k.ouverture(fx, fy, n, u, 1.4, 1.4, 1.4, "noir", "metal", "rond")
    for i in range(2):
        k.silo(-L / 2 - 4, -3 + i * 6, 1.6, 7, "tole", toit="cone")


@batiment(F, "porcherie", "Porcherie", "industrie", 1_100_000,
          "Deux bâtiments d'engraissement, cheminées d'aération et fosse couverte.",
          "Élevages porcins de Bretagne et du Danemark", era="contemporain", emplois=3,
          metiers=ELEVEUR, role="elevage", zone="I", access=["route", "chemin"])
def porcherie(k):
    for s in (-1, 1):
        y = s * 9
        k.corps(0, y, 0, 56, 12, 1, 3.0, "beton_clair", fen=fen(avant=10, arriere=10, l=1.4, h=0.6, vitre="vitre"))
        k.toit_2pans(0, y, 3.0, 56, 12, 1.6, "tole", axe="x", debord=0.3, pignon="beton_clair")
        for i in range(5):
            k.cyl(-22 + i * 11, y, 4.2, 1.6, 0.6, "metal", n=6)
    k.tronc_cone(36, 0, 0, 3.0, 8.0, 8.4, "beton_sombre", n=14)


@batiment(F, "haras", "Haras", "industrie", 3_200_000,
          "Écuries de pierre en U, horloge, manège couvert et carrière de sable.",
          "Haras national du Pin (Orne) et de Haras de Cluny", era="classique", emplois=12,
          visiteurs=60, metiers=[["eleveur", 3], ["coach", 1]], role="elevage", zone="I",
          access=["route", "chemin"], sans_vitres=1)
def haras(k):
    k.corps(0, 6, 0, 36, 8, 1, 4.0, "pierre_claire", fen=fen(avant=10, l=1.2, h=1.2, forme="arc",
                                                              vitre="bois_sombre", cadre="brique"))
    k.toit_2pans(0, 6, 4.0, 36, 8, 2.6, "ardoise", axe="x", pignon="pierre_claire", debord=0.3)
    k.boite(0, 2.0, 4.0, 4, 1.2, 4.5, "pierre_claire")
    k.ouverture(0, 1.4, (0, -1), 0, 6.6, 1.4, 1.4, "blanc", "noir", "rond")
    k.tronc_cone(0, 2.6, 8.5, 2.2, 1.0, 0, "ardoise", n=8)
    for s in (-1, 1):
        k.corps(s * 15, -6, 0, 8, 16, 1, 4.0, "pierre_claire", fen=fen(gauche=5 if s > 0 else 0,
                                                                           droite=5 if s < 0 else 0, l=1.2, h=1.2,
                                                                           forme="arc", vitre="bois_sombre",
                                                                           cadre="brique"))
        k.toit_2pans(s * 15, -6, 4.0, 16, 8, 2.6, "ardoise", axe="y", pignon="pierre_claire", debord=0.3)
    k.boite(-34, 0, 0, 22, 40, 4.5, "bois")
    k.toit_2pans(-34, 0, 4.5, 40, 22, 4.0, "ardoise", axe="y", pignon="bois", debord=0.3)
    k.sol(30, -2, 20, 34, "sable")
    k.cloture([(20, -19), (40, -19), (40, 15), (20, 15)], h=1.3, c="blanc")


@batiment(F, "serres_tunnels", "Serres tunnels", "industrie", 300_000,
          "Six tunnels maraîchers en plastique sur arceaux.",
          "Maraîchage sous abri (Bretagne, Provence)", era="contemporain", emplois=4,
          metiers=FERMIER, role="ferme_cereales", zone="I", access=["route", "chemin"], sans_vitres=1)
def tunnels(k):
    for i in range(6):
        k.toit_voute(-20 + i * 8, 0, 0, 7, 40, 3.2, "blanc", n=6, axe="y", bouts="verre_clair")
    k.boite(26, -14, 0, 5, 5, 3, "bois_gris")
    k.toit_mono(26, -14, 3, 5, 5, 0.6, "tole", mur="bois_gris")


@batiment(F, "serre_verre", "Serre de verre", "industrie", 4_500_000,
          "Serre Venlo de 1 ha pour tomates : toits de verre en dents de scie.",
          "Serres horticoles du Westland (Pays-Bas)", era="contemporain", emplois=20,
          metiers=[["agriculteur", 4], ["magasinier", 1]], role="ferme_cereales", zone="I")
def venlo(k):
    L, P = 100.0, 64.0
    k.boite(0, 0, 0, L, P, 0.5, "beton_clair")
    k.boite(0, 0, 0.5, L, P, 5.5, "verre_clair")
    for i in range(16):
        x = -L / 2 + 3.2 + i * 6.25
        k.toit_2pans(x, 0, 6.0, P, 6.25, 1.0, "verre_ciel", axe="y", debord=0.0, pignon="verre_clair",
                     sous="verre_clair", ep=0.05)
    k.corps(0, -P / 2 - 6, 0, 30, 12, 1, 6, "bardage", fen=fen(avant=3, l=4, h=4, vitre="tole", cadre="blanc"))
    k.toit_plat(0, -P / 2 - 6, 6, 30, 12, "tole", acrotere=0.4)
    k.cuve(L / 2 + 6, 10, 4, 12, "bardage_vert", toit="plat")


@batiment(F, "silos_grains", "Silos à grains", "industrie", 3_800_000,
          "Batterie de silos de béton, tour d'élévation et hangar de réception.",
          "Silos de coopératives agricoles de Beauce et de la Brie", era="moderne", emplois=8,
          metiers=[["magasinier", 3], ["chauffeur", 2], ["agriculteur", 1]], role="entrepot", zone="I",
          sans_vitres=1)
def silos(k):
    for i in range(4):
        for j in range(2):
            k.cyl(-12 + i * 8, -4 + j * 8, 0, 30, 4.0, "beton_clair", n=12)
    k.boite(-2, 0, 30, 32, 16, 3.0, "beton_clair")
    k.boite(18, 0, 0, 7, 7, 40, "beton_clair")
    k.toit_plat(18, 0, 40, 7, 7, "tole", acrotere=0.3)
    k.boite(18, -14, 0, 14, 12, 7, "tole")
    k.toit_2pans(18, -14, 7, 14, 12, 1.5, "tole", axe="x", pignon="tole")


@batiment(F, "moulin_vent", "Moulin à vent", "industrie", 900_000,
          "Moulin hollandais octogonal à calotte tournante et quatre ailes de toile.",
          "D'après les moulins de Kinderdijk (Pays-Bas)", era="traditionnel", emplois=2,
          metiers=[["meunier", 1]], role="moulin", access=["route", "chemin"], variantes=2,
          emprise=[16, 16])
def moulin_vent(k):
    k.boite(0, 0, 0, 9, 9, 3.0, "brique")
    k.tronc_cone(0, 0, 3.0, 14, 4.4, 2.6, "bois_sombre", n=8)
    k.dome(0, 0, 17, 2.9, "chaume", n=8, anneaux=2, h=2.6)
    (fx, fy), n, _ = k._facades(0, 0, 9, 9)["avant"]
    k.porte(fx, fy, n, 0, 0, 1.2, 2.2, "vert")
    k.ouverture(0, -3.9, (0, -1), 0, 9.0, 0.6, 0.8, "vitre", "blanc")
    k.boite(0, -3.4, 0.5 + 16.5, 0.6, 1.0, 0.6, "bois_sombre")
    k.pales(0, -3.9, 17.6, 12.5, 4, "blanc", angle0=math.pi / 4, largeur=2.2)
    k.boite(0, 5.4, 3.0, 0.3, 0.3, 14, "bois_sombre")


@batiment(F, "moulin_eau", "Moulin à eau", "industrie", 1_000_000,
          "Moulin de pierre au bord du bief, grande roue à aubes.",
          "Moulins du Périgord et de Bourgogne", era="traditionnel", emplois=2, logements=1,
          metiers=[["meunier", 1]], role="moulin", access=["route", "chemin"])
def moulin_eau(k):
    k.corps(0, 0, 0, 14, 9, 3, 3.0, "pierre", fen=fen(avant=3, arriere=3, gauche=2, droite=2, l=0.9, h=1.1,
                                                      cadre="pierre_claire", volets="bois_rouge"),
            porte={"l": 1.2, "h": 2.2, "couleur": "bois_sombre"})
    k.toit_2pans(0, 0, 9.0, 14, 9, 3.6, "tuile", axe="x", pignon="pierre", debord=0.4)
    k.sol(10.5, 0, 4.0, 18, "eau", h=0.02)
    for i in range(8):
        a = 2 * math.pi * i / 8
        k.boite(8.3, 3.0 * math.cos(a), 3.2 + 3.0 * math.sin(a), 1.2, 0.3, 0.3, "bois_sombre")
    k.boite(8.3, 0, 0.2, 0.6, 0.6, 3.0, "bois_sombre")
    k.f([(7.7, -3.2, 3.2), (7.7, 0, 0.2), (7.7, 3.2, 3.2), (7.7, 0, 6.2)], "bois", vers=(-1, 0, 0))
    k.f([(8.9, -3.2, 3.2), (8.9, 0, 0.2), (8.9, 3.2, 3.2), (8.9, 0, 6.2)], "bois", vers=(1, 0, 0))


@batiment(F, "chai", "Château viticole", "industrie", 6_000_000,
          "Demeure bordelaise à tourelles, chai à barriques et cuverie.",
          "Châteaux du Médoc (Pichon-Baron, Cos d'Estournel)", era="classique", emplois=15, logements=1,
          visiteurs=80, metiers=[["agriculteur", 4], ["operateur", 1], ["vendeur", 1]], role="ferme",
          zone="I", access=["route", "chemin"])
def chai(k):
    k.corps(0, 0, 0, 20, 12, 2, 4.0, "pierre_claire", fen=fen(avant=5, arriere=5, gauche=2, droite=2, l=1.3, h=2.2,
                                                               cadre="pierre", volets="blanc"),
            porte={"l": 1.6, "h": 2.8, "couleur": "bois_sombre"}, socle="pierre", bandeaux="pierre")
    k.toit_4pans(0, 0, 8.0, 20, 12, 4.5, "ardoise", debord=0.3)
    for s in (-1, 1):
        k.cyl(s * 10, -6, 0, 11, 2.2, "pierre_claire", n=10)
        k.tronc_cone(s * 10, -6, 11, 5.0, 2.5, 0, "ardoise", n=10)
    k.boite(0, 18, 0, 40, 14, 6.0, "pierre_claire")
    k.toit_2pans(0, 18, 6.0, 40, 14, 2.4, "tuile", axe="x", pignon="pierre_claire", debord=0.4)
    for i in range(4):
        k.cuve(26, 10 + i * 5, 2.0, 7.0, "zinc", toit="cone")


@batiment(F, "cave_cooperative", "Cave coopérative", "industrie", 3_500_000,
          "Cave Art déco des années 1930 : grand fronton, cuves de béton et quai de réception.",
          "Caves coopératives du Languedoc (Vignerons de Tavel, Lézignan)", region="mediterranee",
          era="classique", emplois=15, visiteurs=60, metiers=[["operateur", 2], ["agriculteur", 2], ["vendeur", 1]],
          role="usine", zone="I")
def cave_coop(k):
    k.corps(0, 0, 0, 30, 20, 1, 8.0, "enduit_rose", fen=fen(avant=4, gauche=4, droite=4, l=1.4, h=2.8, forme="arc",
                                                             cadre="enduit_blanc"),
            porte={"l": 3.0, "h": 3.6, "couleur": "bois_rouge"})
    k.toit_2pans(0, 0, 8.0, 30, 20, 2.6, "tuile", axe="y", pignon="enduit_rose", debord=0.3)
    k.boite(0, -10.2, 7.0, 16, 0.5, 5.0, "enduit_blanc")
    k.boite(0, -10.5, 10.2, 10, 0.2, 1.0, "bois_rouge")
    k.boite(0, -13, 0, 30, 4, 1.2, "beton_clair")


@batiment(F, "hangar_agricole", "Hangar agricole", "industrie", 250_000,
          "Hangar ouvert sur charpente métallique, tracteur et bottes de foin.",
          "Hangars de stockage des exploitations céréalières", era="contemporain", emplois=1,
          metiers=FERMIER, role="ferme_cereales", zone="I", access=["route", "chemin"], sans_vitres=1)
def hangar_agricole(k):
    L, P = 30.0, 16.0
    k.sol(0, 0, L, P, "beton_clair")
    for i in range(6):
        for s in (-1, 1):
            k.boite(-L / 2 + i * L / 5, s * P / 2, 0, 0.3, 0.3, 6.0, "metal")
    k.boite(0, P / 2, 0, L, 0.2, 6.0, "bardage")
    k.toit_2pans(0, 0, 6.0, L, P, 2.0, "tole", axe="x", debord=0.6, pignon=None)
    for i in range(3):
        for j in range(2):
            k.boite(-10 + i * 2.6, 4 + j * 1.3, 0, 2.4, 1.2, 1.2 * (2 - j), "chaume")
    k.boite(6, -2, 0, 3.2, 2.2, 2.0, "vert")
    k.boite(6.6, -2, 2.0, 1.8, 2.0, 1.2, "verre_nuit")
    for s in (-1, 1):
        k.b.cylindre(4.8, -2 + s * 1.15, 0, 0.5, 0.8, "noir", n=8)


@batiment(F, "ferme_alpage", "Ferme d'alpage", "industrie", 700_000,
          "Chalet d'alpage bas et large, fromagerie et étable sous un toit de tavillons.",
          "Alpages de la Gruyère (Fribourg)", era="traditionnel", emplois=3, logements=1,
          metiers=[["eleveur", 2], ["artisan", 1]], role="elevage", zone="I", access=["route", "chemin"])
def alpage(k):
    L, P = 24.0, 14.0
    k.corps(0, 0, 0, L, P, 1, 3.4, "pierre_grise", fen=fen(avant=4, gauche=2, l=0.7, h=0.8, cadre="bois_sombre"),
            porte={"l": 1.1, "h": 2.1, "couleur": "bois_sombre", "u": -6})
    grande_porte(k, 0, 0, L, P, "avant", 5, 2.6, 2.6)
    k.toit_4pans(0, 0, 3.4, L, P, 4.0, "bois_gris", debord=1.0)
    k.cheminee(-6, 0, 7.0, 1.4, "pierre_grise")


@batiment(F, "rizerie_bali", "Grenier à riz", "industrie", 180_000,
          "Lumbung de bambou sur pilotis, toit de chaume en forme de selle.",
          "Greniers à riz (lumbung) de Bali et de Lombok", region="asie_sud", era="traditionnel", emplois=2,
          metiers=FERMIER, role="ferme_cereales", zone="I", access=["route", "chemin"], sans_vitres=1)
def lumbung(k):
    k.boite(0, 0, 0, 6, 6, 0.4, "pierre_grise")
    k.pilotis(0, 0, 4, 4, 2.4, 2, 2, "bois_sombre", r=0.2)
    k.boite(0, 0, 2.4, 4.6, 4.6, 0.2, "bois")
    prof = [(-2.8, 0.0), (-2.2, 2.2), (-1.0, 4.4), (0, 5.0), (1.0, 4.4), (2.2, 2.2), (2.8, 0.0)]
    k.toit_profil(0, 0, 2.6, 5.4, prof, "chaume", axe="x", bouts="bois_sombre")
