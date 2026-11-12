"""Industrie et énergie de la bible : ateliers, usines, entrepôts, industrie
lourde, énergie, eau et déchets, logistique. Formes simplifiées d'après des
sites réels ou des types courants (champ `source`)."""

import math

from registre import batiment

F = "industrie"


def fen(**kw):
    d = {"l": 1.2, "h": 1.4}
    d.update(kw)
    return d


def porte_quai(k, cx, cy, L, P, cote, u, l=4.0, h=4.5, c="tole"):
    (fx, fy), n, _ = k._facades(cx, cy, L, P)[cote]
    k.ouverture(fx, fy, n, u, h / 2, l, h, c, "jaune")


@batiment(F, "atelier_artisan", "Atelier d'artisan", "industrie", 450_000,
          "Petit atelier en briques avec grande porte, logement à l'étage.",
          "Ateliers de faubourg (Paris XIe, Lyon Croix-Rousse)", era="classique", emplois=6,
          metiers=[["artisan", 4], ["vendeur", 1]], role="atelier", zone="I")
def atelier_artisan(k):
    k.corps(0, 0, 0, 12, 10, 2, 3.4, "brique", fen=fen(avant=3, arriere=3, gauche=2, droite=2, l=1.2, h=1.8,
                                                         cadre="pierre_claire", forme="arc", rdc=False),
            socle="pierre_grise")
    porte_quai(k, 0, 0, 12, 10, "avant", -2.0, 3.2, 3.0, "bois_sombre")
    k.porte(0, -5, (0, -1), 3.6, 0.4, 1.0, 2.2, "vert")
    k.toit_2pans(0, 0, 6.8, 12, 10, 2.8, "tuile", axe="x", pignon="brique", debord=0.4)


@batiment(F, "menuiserie_village", "Menuiserie de village", "industrie", 900_000,
          "Hangar de bois, scie, tas de planches et cheminée d'aspiration.",
          "Menuiseries et charpenteries de village", era="moderne", emplois=8,
          metiers=[["menuisier", 3], ["ouvrier", 1]], role="menuiserie", zone="I")
def menuiserie(k):
    k.sol(0, -2, 26, 22, "beton_clair")
    k.corps(0, 3, 0, 22, 14, 1, 6.5, "bois", fen=fen(gauche=3, droite=3, arriere=5, l=2.4, h=1.2,
                                                     vitre="verre_ciel", cadre="bois_sombre"))
    porte_quai(k, 0, 3, 22, 14, "avant", -4, 5.0, 5.0, "bois_sombre")
    k.toit_2pans(0, 3, 6.5, 22, 14, 2.4, "tole", axe="x", pignon="bois", debord=0.6)
    k.cyl(8, -1, 0, 11.0, 0.5, "zinc", n=8)
    for i in range(3):
        k.boite(-6 + i * 3.2, -7.5, 0, 2.6, 5.0, 0.8 + i * 0.3, "bois_clair")


@batiment(F, "scierie_jura", "Scierie du Jura", "industrie", 2_600_000,
          "Grand hangar ouvert, grumes empilées, séchoir et silo à copeaux.",
          "Scieries des Vosges et du Jura", era="moderne", emplois=18,
          metiers=[["ouvrier", 3], ["conducteur_engins", 1], ["bucheron", 1]], role="scierie", zone="I",
          access=["route", "chemin"])
def scierie(k):
    k.sol(0, 0, 50, 34, "terre")
    k.boite(-6, 4, 0, 30, 18, 0.3, "beton_clair")
    for i in range(6):
        for s in (-1, 1):
            k.boite(-20 + i * 5.6, 4 + s * 8.6, 0.3, 0.4, 0.4, 7.0, "metal")
    k.toit_2pans(-6, 4, 7.3, 30, 18, 2.5, "tole", axe="x", debord=0.5, pignon=None)
    k.corps(14, 6, 0, 10, 12, 1, 6.0, "bardage_vert", fen=fen(avant=2, l=1.6, h=1.0, vitre="verre_ciel"))
    k.toit_plat(14, 6, 6.0, 10, 12, "tole", acrotere=0.3)
    k.silo(20, -8, 2.6, 12.0, "tole", toit="cone")
    for r in range(3):
        k.boite(-12, -10 + r * 1.6, 0, 18, 1.4, 1.4 - r * 0.3, "bois")


@batiment(F, "filature_briques", "Filature en briques", "industrie", 9_000_000,
          "Usine du XIXe s. à quatre étages, toits en sheds et grande cheminée.",
          "Filatures de Roubaix et de Manchester (La Manufacture, Motte-Bossut)", era="classique", emplois=180,
          metiers=[["ouvrier", 7], ["ingenieur", 1], ["magasinier", 1], ["cadre", 1]], role="usine", zone="I")
def filature(k):
    k.corps(0, -8, 0, 60, 16, 4, 4.2, "brique", fen=fen(avant=16, arriere=16, gauche=4, droite=4, l=1.8, h=2.6,
                                                          forme="arc", cadre="pierre_claire"),
            porte={"l": 3.0, "h": 3.6, "couleur": "bois_sombre", "forme": "arc"}, bandeaux="pierre_claire")
    k.toit_2pans(0, -8, 16.8, 60, 16, 3.0, "ardoise", axe="x", pignon="brique", debord=0.3)
    for s in (-1, 1):
        k.boite(s * 30.5, -16.6, 0, 5, 5, 22, "brique")
        k.toit_4pans(s * 30.5, -16.6, 22, 5, 5, 3.0, "ardoise", debord=0.3)
    k.boite(0, 14, 0, 56, 26, 6.0, "brique")
    k.sheds(0, 14, 6.0, 56, 26, 3.0, 6, "ardoise")
    k.tronc_cone(34, 20, 0, 48.0, 2.4, 1.4, "brique_sombre", n=10)


@batiment(F, "usine_automobile", "Usine automobile", "industrie", 120_000_000,
          "Halls d'assemblage, atelier de peinture, parking des voitures neuves.",
          "Usines de Sochaux, de Wolfsburg et de Flins", era="moderne", emplois=2500,
          metiers=[["ouvrier", 7], ["ingenieur", 2], ["magasinier", 1], ["cadre", 1]], role="usine", zone="I")
def usine_auto(k):
    k.sol(0, 0, 150, 110, "beton_clair")
    k.boite(-20, 10, 0, 100, 70, 14, "bardage")
    k.sheds(-20, 10, 14, 100, 70, 3.0, 10, "tole")
    k.boite(50, 25, 0, 30, 40, 22, "bardage_bleu")
    k.toit_plat(50, 25, 22, 30, 40, "tole", acrotere=0.4)
    k.corps(45, -30, 0, 40, 16, 4, 3.6, "verre_bleu", fen=fen(), porte={"l": 4, "h": 3, "couleur": "verre_nuit"})
    k.toit_plat(45, -30, 14.4, 40, 16, "beton_sombre", acrotere=0.5)
    for i in range(4):
        k.cyl(20 + i * 6, 54, 0, 30.0, 1.2, "blanc", n=8)
    k.sol(-30, -42, 60, 22, "asphalte", h=0.08)
    for i in range(12):
        k.boite(-56 + i * 4.6, -42, 0.08, 1.8, 4.2, 1.4, ("rouge", "blanc", "bleu", "noir")[i % 4])


@batiment(F, "entrepot_logistique", "Plateforme logistique", "industrie", 28_000_000,
          "Immense entrepôt de 200 × 80 m, trente quais et parking de semi-remorques.",
          "Plateformes logistiques de la vallée du Rhône et du « Delta » de l'A1", era="contemporain",
          emplois=300, metiers=[["magasinier", 6], ["chauffeur", 4]], role="entrepot", zone="I")
def logistique(k):
    k.sol(0, -10, 200, 110, "asphalte")
    k.boite(0, 10, 0, 196, 80, 13, "blanc")
    k.toit_plat(0, 10, 13, 196, 80, "beton_clair", acrotere=0.6, c_acrotere="bardage_bleu")
    (fx, fy), n, lg = k._facades(0, 10, 196, 80)["avant"]
    for i in range(30):
        u = -lg / 2 + 6 + i * (lg - 12) / 29
        k.ouverture(fx, fy, n, u, 2.0, 3.0, 3.2, "tole", "noir")
    k.corps(-85, -36, 0, 22, 10, 2, 3.4, "verre_bleu", fen=fen(), porte={"l": 2, "h": 2.6, "couleur": "verre_nuit"})
    k.toit_plat(-85, -36, 6.8, 22, 10, "beton_sombre", acrotere=0.4)
    for i in range(8):
        k.boite(-30 + i * 8, -50, 0.04, 2.5, 16, 3.8, "blanc")


@batiment(F, "brasserie_biere", "Brasserie", "industrie", 8_000_000,
          "Brasserie de briques, salle de brassage aux cuves de cuivre et tour du malt.",
          "Brasseries Carlsberg (Copenhague) et Cardinal (Fribourg)", era="classique", emplois=60,
          visiteurs=80, metiers=[["operateur", 3], ["ouvrier", 3], ["magasinier", 1], ["vendeur", 1]],
          role="usine", zone="I")
def brasserie(k):
    k.corps(0, 0, 0, 32, 18, 3, 4.2, "brique_claire", fen=fen(avant=8, arriere=8, gauche=4, droite=4, l=1.6, h=2.4,
                                                                forme="arc", cadre="pierre_claire"),
            porte={"l": 3, "h": 3.4, "couleur": "bois_sombre", "forme": "arc"}, bandeaux="pierre_claire")
    k.toit_2pans(0, 0, 12.6, 32, 18, 3.5, "ardoise", axe="x", pignon="brique_claire", debord=0.3)
    k.boite(12, 2, 12.6, 7, 7, 12, "brique_claire")
    k.toit_4pans(12, 2, 24.6, 7, 7, 4.0, "cuivre", debord=0.3)
    for i in range(4):
        k.cuve(-12 + i * 5, 16, 2.0, 9.0, "zinc", toit="cone")
    k.tronc_cone(-14, 2, 12.6, 18, 1.4, 0.9, "brique_sombre", n=8)


@batiment(F, "haut_fourneau", "Haut fourneau", "industrie", 400_000_000,
          "Haut fourneau, cowpers, halle de coulée et convoyeurs de minerai.",
          "D'après le site de Belval (Esch-sur-Alzette) et le haut fourneau U4 d'Uckange", era="moderne",
          emplois=1200, metiers=[["siderurgiste", 6], ["ouvrier", 2], ["ingenieur", 1]], role="acierie", zone="I", sans_vitres=1)
def acierie(k):
    k.sol(0, 0, 120, 90, "beton_sombre")
    k.tronc_cone(-20, 10, 0, 20, 7, 5, "rouge", n=12)
    k.cyl(-20, 10, 20, 18, 5, "tole_rouge", n=12)
    k.tronc_cone(-20, 10, 38, 12, 5, 2, "rouge", n=12)
    k.cyl(-20, 10, 50, 14, 1.2, "metal", n=8)
    for i in range(4):
        k.cyl(-42, -10 + i * 8, 0, 36, 3.2, "tole", n=10)
        k.dome(-42, -10 + i * 8, 36, 3.2, "tole", n=10, anneaux=2)
    k.boite(15, 10, 0, 50, 30, 20, "bardage")
    k.toit_2pans(15, 10, 20, 50, 30, 4, "tole", axe="x", pignon="bardage", debord=0.3)
    for s in (-1, 1):
        k.boite(-5, 10 + s * 1.2, 30, 22, 0.6, 1.5, "metal")
    k.f([(-46, -40, 0.1), (-26, -40, 0.1), (-26, 4, 32), (-46, 4, 32)], "tole", vers=(0, -1, 1))
    for i in range(3):
        k.tronc_cone(40, -30 + i * 9, 0, 6, 4, 0, "noir", n=8)


@batiment(F, "raffinerie_petrole", "Raffinerie de pétrole", "industrie", 900_000_000,
          "Colonnes de distillation, torchère, réservoirs et passerelles de tuyaux.",
          "Raffineries de Donges et de Fos-sur-Mer", era="moderne", emplois=800,
          metiers=[["operateur", 4], ["ingenieur", 1]], role="raffinerie", zone="I")
def raffinerie(k):
    k.sol(0, 0, 160, 120, "beton_clair")
    for i in range(4):
        for j in range(3):
            k.cuve(-60 + i * 22, 30 + j * 22, 9, 14, "blanc", toit="dome")
    for (x, y, r, h) in ((10, -20, 2.4, 50), (18, -20, 1.8, 38), (26, -20, 2.0, 44), (34, -20, 1.4, 30)):
        k.cyl(x, y, 0, h, r, "metal", n=10)
        for z in range(10, int(h), 10):
            k.cyl(x, y, z, 0.4, r + 0.6, "jaune", n=10)
    k.boite(22, -6, 6, 50, 1.2, 1.2, "metal")
    k.boite(22, -10, 8, 50, 1.2, 1.2, "metal")
    for i in range(6):
        k.boite(-2 + i * 10, -8, 0, 0.5, 6, 8, "metal")
    k.cyl(60, -45, 0, 70, 0.9, "rouge", n=8)
    k.tronc_cone(60, -45, 70, 3, 1.6, 0.6, "orange", n=8)
    k.corps(-55, -40, 0, 30, 14, 2, 3.6, "blanc", fen=fen(avant=8, arriere=8, l=2.0, h=1.4, vitre="verre_ciel"),
            porte={"l": 2, "h": 2.6, "couleur": "verre_nuit"})
    k.toit_plat(-55, -40, 7.2, 30, 14, "beton_sombre", acrotere=0.4)


@batiment(F, "cimenterie_four", "Cimenterie", "industrie", 180_000_000,
          "Tour de préchauffage, four rotatif, silos à ciment et carrière de calcaire.",
          "Cimenteries Holcim d'Eclépens et Vicat de Montalieu", era="moderne", emplois=150,
          metiers=[["operateur", 2], ["ouvrier", 2]], role="cimenterie", zone="I", sans_vitres=1)
def cimenterie(k):
    k.sol(0, 0, 110, 70, "beton_clair")
    k.boite(-30, 0, 0, 14, 14, 70, "beton_clair")
    for z in range(10, 70, 12):
        k.boite(-30, 0, z, 15, 15, 1.2, "metal")
    k.toit_plat(-30, 0, 70, 14, 14, "metal", acrotere=1.0)
    k.f([(-23, -3, 8), (30, -3, 3), (30, 3, 3), (-23, 3, 8)], "tole", vers=(0, 0, 1))
    k.f([(-23, -3, 8), (30, -3, 3), (30, -3, 0), (-23, -3, 4)], "tole", vers=(0, -1, 0))
    for i in range(4):
        k.silo(10 + i * 9, 22, 4.0, 40, "beton_clair", toit="dome", c_toit="beton_sombre")
    k.cyl(-40, 18, 0, 90, 2.4, "blanc", n=10)
    for z in (70, 80):
        k.cyl(-40, 18, z, 3.0, 2.5, "rouge", n=10, dessus=False)


@batiment(F, "briqueterie_hoffmann", "Briqueterie", "industrie", 6_500_000,
          "Four Hoffmann allongé, séchoirs à claire-voie et haute cheminée carrée.",
          "Briqueteries du Nord et de Ziegelei Hundisburg", era="classique", emplois=40,
          metiers=[["ouvrier", 3], ["operateur", 1]], role="briqueterie", zone="I", sans_vitres=1)
def briqueterie(k):
    k.boite(0, 0, 0, 50, 16, 5, "brique")
    k.toit_2pans(0, 0, 5, 50, 16, 3.0, "tuile", axe="x", pignon="brique", debord=0.6)
    (fx, fy), n, lg = k._facades(0, 0, 50, 16)["avant"]
    for i in range(8):
        k.ouverture(fx, fy, n, -lg / 2 + 3 + i * 6.2, 1.4, 1.4, 2.4, "noir", "brique_sombre", "arc")
    for s in (-1, 1):
        k.boite(0, s * 16, 0, 46, 10, 4.5, "bois_gris")
        k.toit_2pans(0, s * 16, 4.5, 46, 10, 2.0, "tuile", axe="x", debord=0.4, pignon="bois_gris")
    k.tronc(0, 0, 8, 4.0, 4.0, 42, 2.4, 2.4, "brique_sombre")


@batiment(F, "centrale_charbon", "Centrale thermique", "industrie", 1_200_000_000,
          "Salle des machines, chaudières, deux tours de refroidissement et cheminée de 200 m.",
          "Centrales de Bouchain, Cordemais et de Neurath", era="moderne", emplois=400,
          metiers=[["operateur", 4], ["ingenieur", 2], ["ouvrier", 1]], role="usine", zone="I")
def centrale(k):
    k.sol(0, 0, 200, 150, "beton_sombre")
    k.boite(0, -20, 0, 70, 30, 30, "bardage")
    k.toit_plat(0, -20, 30, 70, 30, "tole", acrotere=0.5)
    k.boite(10, 10, 0, 40, 30, 70, "bardage_bleu")
    k.toit_plat(10, 10, 70, 40, 30, "tole", acrotere=0.5)
    for s in (-1, 1):
        k.tour_refroidissement(s * 55 - 20, 45, 30, 110)
    k.tronc_cone(70, -20, 0, 200, 8, 4.5, "beton_clair", n=10, dessus=True)
    for z in (170, 185):
        k.cyl(70, -20, z, 5, 5.2, "rouge", n=10, dessus=False)
    k.sol(-60, -50, 60, 40, "noir", h=3.0)


@batiment(F, "centrale_nucleaire", "Centrale nucléaire", "industrie", 9_000_000_000,
          "Deux réacteurs sous dômes, salle des turbines et deux tours aéroréfrigérantes.",
          "D'après la centrale de Gösgen (Soleure) et les centrales françaises de 1 300 MW", era="moderne",
          emplois=1500, metiers=[["ingenieur", 3], ["operateur", 4], ["agent_public", 1]], role="usine", zone="I")
def nucleaire(k):
    k.sol(0, 0, 260, 200, "beton_clair")
    for s in (-1, 1):
        k.cyl(s * 30, -20, 0, 45, 20, "beton_clair", n=16)
        k.dome(s * 30, -20, 45, 20, "beton_clair", n=16, anneaux=3, h=12)
    k.corps(0, 15, 0, 110, 30, 1, 30, "bardage_bleu", fen=fen(avant=1, bande=True, h=3, vitre="verre_ciel"))
    k.toit_plat(0, 15, 30, 110, 30, "tole", acrotere=0.6)
    for s in (-1, 1):
        k.tour_refroidissement(s * 70, 70, 50, 165, n=18)
    k.corps(-95, -60, 0, 40, 18, 3, 3.5, "blanc", fen=fen(avant=10, arriere=10, l=2, h=1.4, vitre="verre_ciel"),
            porte={"l": 3, "h": 2.6, "couleur": "verre_nuit"})
    k.toit_plat(-95, -60, 10.5, 40, 18, "beton_sombre", acrotere=0.5)


@batiment(F, "barrage_usine", "Usine hydroélectrique", "industrie", 60_000_000,
          "Usine au fil de l'eau : quatre turbines sous une halle Art déco, conduites forcées.",
          "D'après l'usine hydroélectrique de Chancy-Pougny et les usines du Rhône", era="classique",
          emplois=40, metiers=[["operateur", 2], ["ingenieur", 1]], role="usine", zone="I")
def hydro(k):
    k.corps(0, 0, 0, 60, 20, 1, 16, "beton_clair", fen=fen(avant=8, arriere=8, l=3.0, h=9.0, forme="arc",
                                                            cadre="pierre_claire", vitre="verre_ciel"),
            porte={"l": 4, "h": 5, "couleur": "bois_sombre", "forme": "arc"})
    k.toit_2pans(0, 0, 16, 60, 20, 3.0, "cuivre", axe="x", pignon="beton_clair", debord=0.3)
    for i in range(4):
        x = -21 + i * 14
        k.f([(x - 1.4, 10, 0.5), (x + 1.4, 10, 0.5), (x + 1.4, 40, 30), (x - 1.4, 40, 30)], "metal", vers=(0, -1, 1))
    k.boite(0, 41, 0, 70, 4, 31, "beton_sombre")


@batiment(F, "eolienne", "Éolienne", "industrie", 3_200_000,
          "Mât de 100 m, nacelle et trois pales de 60 m.",
          "Éoliennes terrestres de 3 MW (Vestas V117, Enercon E-115)", era="contemporain", emplois=1,
          metiers=[["ingenieur", 1]], role="usine", sans_vitres=1, access=["route", "chemin"], variantes=1, emprise=[12, 12])
def eolienne(k):
    k.tronc_cone(0, 0, 0, 100, 2.4, 1.3, "blanc", n=12)
    k.boite(0, 1.5, 99, 3.2, 10, 4, "blanc")
    k.cyl(0, -3.5, 99.5, 3.0, 1.2, "blanc", n=8)
    k.pales(0, -4.0, 101, 58, 3, "blanc", angle0=math.pi / 2, largeur=2.6)


@batiment(F, "centrale_solaire", "Centrale solaire", "industrie", 25_000_000,
          "Champ de panneaux photovoltaïques sur 2 ha, onduleurs et clôture.",
          "Parcs solaires au sol de la vallée du Rhône", era="contemporain", emplois=3,
          metiers=[["ingenieur", 1], ["ouvrier", 1]], role="usine", access=["route", "chemin"], variantes=1)
def solaire(k):
    k.sol(0, 0, 150, 130, "pelouse", h=0.02)
    for r in range(12):
        y = -58 + r * 10.5
        k.f([(-68, y - 2, 0.8), (68, y - 2, 0.8), (68, y + 2, 3.0), (-68, y + 2, 3.0)], "verre_nuit", vers=(0, -1, 1.7))
        k.boite(0, y + 1.5, 0, 136, 0.15, 2.4, "metal")
    for i in range(3):
        k.boite(-40 + i * 40, -64, 0, 4, 2.5, 2.6, "blanc")
    k.cloture([(-74, -67), (74, -67), (74, 64), (-74, 64)], h=2.0, c="metal")


@batiment(F, "station_epuration", "Station d'épuration", "industrie", 35_000_000,
          "Bassins ronds de décantation, aération et bâtiment des boues.",
          "Stations d'épuration municipales (Vidy à Lausanne, Achères)", era="moderne", emplois=25,
          metiers=[["operateur", 2], ["agent_public", 1]], role="usine", zone="I")
def epuration(k):
    k.sol(0, 0, 110, 80, "beton_clair")
    for i, (x, y) in enumerate(((-30, -15), (0, -15), (30, -15), (-30, 18), (0, 18))):
        k.cyl(x, y, 0, 2.5, 12, "beton_clair", n=16, dessus=False)
        k.cyl(x, y, 0, 2.2, 11.4, "eau" if i % 2 else "terre", n=16)
        k.boite(x, y, 2.5, 24, 1.0, 0.4, "metal")
    k.boite(38, 22, 0, 22, 8, 1.8, "beton_sombre")
    k.boite(38, 22, 1.8, 21, 7, 0.01, "eau")
    k.corps(40, -10, 0, 20, 16, 2, 4.0, "bardage_vert", fen=fen(avant=5, gauche=3, l=1.6, h=1.6, vitre="verre_ciel"),
            porte={"l": 4, "h": 4, "couleur": "tole"})
    k.toit_plat(40, -10, 8.0, 20, 16, "tole", acrotere=0.4)
    k.silo(40, -30, 4, 10, "tole_verte", toit="dome")


@batiment(F, "incinerateur", "Usine d'incinération", "industrie", 150_000_000,
          "Valorisation des déchets : fosse, chaudières, cheminée et façade de lames colorées.",
          "D'après l'usine Tridel (Lausanne) et Amager Bakke (Copenhague)", era="contemporain", emplois=90,
          metiers=[["operateur", 4], ["chauffeur", 2], ["ingenieur", 1]], role="usine", zone="I")
def incinerateur(k):
    k.boite(0, 0, 0, 70, 40, 30, "bardage")
    k.f([(-35, -20, 30), (35, -20, 30), (35, 20, 42), (-35, 20, 42)], "tole", vers=(0, -1, 3))
    for s in (-1, 1):
        k.f([(s * 35, -20, 30), (s * 35, 20, 30), (s * 35, 20, 42)], "bardage", vers=(s, 0, 0))
    k.boite(0, 20, 0, 70, 0.2, 42, "bardage")
    (fx, fy), n, lg = k._facades(0, 0, 70, 40)["avant"]
    for i in range(14):
        u = -lg / 2 + 2.5 + i * 5
        k.b.boite_mur(fx, fy, n, u - 1.6, u + 1.6, 4, 28, 0.4, ("bardage_bleu", "bardage_vert", "orange")[i % 3])
    for i in range(4):
        k.ouverture(fx, fy, n, -22 + i * 6, 2.5, 4.2, 5, "tole", "jaune")
    k.cyl(28, 12, 0, 80, 2.2, "metal", n=10)


@batiment(F, "data_center", "Centre de données", "industrie", 220_000_000,
          "Hangar sans fenêtres, toit couvert de groupes froids, générateurs de secours.",
          "Centres de données de Marcoussis et de la région de Francfort", era="contemporain", emplois=60,
          metiers=[["ingenieur", 3], ["employe", 1], ["magasinier", 1]], role="usine", zone="I")
def data_center(k):
    k.sol(0, 0, 90, 70, "beton_clair")
    k.corps(0, 5, 0, 80, 50, 1, 12, "bardage", fen=fen(avant=1, bande=True, h=0.6, vitre="verre_bleu"))
    k.toit_plat(0, 5, 12, 80, 50, "beton_clair", acrotere=1.0, c_acrotere="noir")
    for i in range(6):
        for j in range(3):
            k.boite(-30 + i * 12, -8 + j * 13, 13, 8, 4, 2.2, "metal")
    for i in range(5):
        k.boite(-30 + i * 14, -28, 0, 10, 3, 3.5, "blanc")
    k.corps(-30, -25, 0, 18, 8, 1, 4, "verre_bleu", fen=fen(), porte={"l": 2, "h": 2.6, "couleur": "verre_nuit"})


@batiment(F, "terminal_conteneurs", "Terminal à conteneurs", "industrie", 350_000_000,
          "Quai, portiques géants, piles de conteneurs colorés et bâtiment des douanes.",
          "Ports du Havre, d'Anvers et de Rotterdam", era="contemporain", emplois=600,
          metiers=[["magasinier", 4], ["conducteur_engins", 4], ["chauffeur", 2], ["cadre", 1]], role="entrepot",
          zone="I")
def conteneurs(k):
    k.sol(0, 0, 180, 120, "asphalte", h=0.2)
    cols = ("rouge", "bleu", "vert", "orange", "blanc", "bardage_rouge", "jaune")
    for i in range(10):
        for j in range(4):
            h = 2.6 * (1 + (i * 3 + j * 5) % 4)
            k.boite(-70 + i * 12.5, -30 + j * 9, 0.2, 12.2, 2.5, h, cols[(i + j * 3) % len(cols)])
    for g in range(3):
        x = -50 + g * 50
        for s in (-1, 1):
            k.boite(x + s * 8, 45, 0.2, 1.4, 1.4, 36, "orange")
            k.boite(x + s * 8, 35, 0.2, 1.4, 1.4, 36, "orange")
        k.boite(x, 30, 36, 18, 50, 2.5, "orange")
        k.boite(x, 30, 38.5, 5, 6, 4, "blanc")
    k.corps(60, -45, 0, 30, 14, 3, 3.6, "blanc", fen=fen(avant=8, arriere=8, l=2.2, h=1.6, vitre="verre_ciel"),
            porte={"l": 2.4, "h": 2.6, "couleur": "verre_nuit"})
    k.toit_plat(60, -45, 10.8, 30, 14, "beton_sombre", acrotere=0.5)


@batiment(F, "depot_bus", "Dépôt de bus", "industrie", 30_000_000,
          "Grande halle de remisage, atelier d'entretien et station de lavage.",
          "Dépôts de bus de la RATP et des transports lausannois", era="contemporain", emplois=200,
          metiers=[["chauffeur", 6], ["artisan", 2], ["cadre", 1]], role="entrepot", zone="I")
def depot_bus(k):
    k.sol(0, -20, 100, 30, "asphalte")
    k.boite(0, 15, 0, 96, 40, 8.5, "bardage_bleu")
    k.toit_voute(0, 15, 8.5, 96, 40, 3.0, "tole", n=6, axe="x")
    (fx, fy), n, lg = k._facades(0, 15, 96, 40)["avant"]
    for i in range(10):
        k.ouverture(fx, fy, n, -lg / 2 + 6 + i * 9.4, 2.8, 4.4, 5.0, "tole", "jaune")
    k.corps(40, -26, 0, 16, 10, 2, 3.4, "blanc", fen=fen(avant=4, gauche=2, l=2, h=1.4, vitre="verre_ciel"),
            porte={"l": 1.6, "h": 2.4, "couleur": "verre_nuit"})
    k.toit_plat(40, -26, 6.8, 16, 10, "beton_sombre", acrotere=0.4)
    for i in range(6):
        k.boite(-38 + i * 4, -22, 0.04, 2.5, 12, 3.2, "vert")


@batiment(F, "garage_auto", "Garage automobile", "industrie", 1_200_000,
          "Atelier de réparation avec trois portes, station de lavage et enseigne.",
          "Garages de quartier", era="moderne", emplois=8, visiteurs=40,
          metiers=[["artisan", 4], ["vendeur", 1]], role="atelier", zone="I")
def garage_auto(k):
    k.sol(0, -6, 26, 10, "asphalte")
    k.boite(0, 6, 0, 24, 14, 5.0, "blanc")
    k.toit_plat(0, 6, 5.0, 24, 14, "tole", acrotere=0.6, c_acrotere="rouge")
    (fx, fy), n, lg = k._facades(0, 6, 24, 14)["avant"]
    for i in range(3):
        k.ouverture(fx, fy, n, -7 + i * 5, 1.9, 4.0, 3.6, "tole", "rouge")
    k.ouverture(fx, fy, n, 8.5, 1.6, 3.6, 2.4, "verre_bleu", "rouge")
    k.boite(0, -1.2, 5.6, 8, 0.3, 1.4, "rouge")
    k.cyl(-10, -9, 0, 6.0, 0.15, "metal", n=6)
    k.boite(-10, -9, 6, 1.6, 0.2, 1.6, "bleu")


@batiment(F, "hangar_avions", "Hangar d'aviation", "industrie", 40_000_000,
          "Hangar voûté de 80 m d'ouverture pour la maintenance des avions.",
          "Hangars d'Orly (Freyssinet, 1923) et de l'aéroport de Zurich", era="classique", emplois=150,
          metiers=[["ingenieur", 3], ["artisan", 4], ["magasinier", 1]], role="atelier", zone="I")
def hangar(k):
    k.toit_voute(0, 0, 0, 80, 60, 30, "beton_clair", n=10, axe="y", bouts="beton_clair")
    (fx, fy), n, lg = k._facades(0, 0, 80, 60)["avant"]
    k.ouverture(fx, fy, n, 0, 10, 60, 20, "verre_ciel", "metal")
    k.corps(48, 10, 0, 12, 30, 2, 4, "blanc", fen=fen(avant=2, droite=6, l=2, h=1.6, vitre="verre_ciel"),
            porte={"l": 2, "h": 2.6, "couleur": "verre_nuit"})
    k.toit_plat(48, 10, 8, 12, 30, "beton_sombre", acrotere=0.4)
