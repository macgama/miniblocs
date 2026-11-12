"""Résidences de la bible : maisons traditionnelles du monde, maisons et villas
modernes, immeubles et tours. Formes simplifiées d'après des types réels ou
des bâtiments connus (champ `source`)."""

from registre import batiment

F = "residences"


def fen(**kw):
    d = {"l": 1.0, "h": 1.3}
    d.update(kw)
    return d


# --- Maisons traditionnelles d'Europe -----------------------------------------------

@batiment(F, "chalet_bernois", "Chalet de l'Oberland", "logement", 780_000,
          "Grand chalet de bois sur socle de pierre, toit à faible pente et balcons.",
          "Chalets de l'Oberland bernois (Gstaad, Grindelwald)", era="traditionnel", logements=2, role="maison",
          zone="R")
def chalet_bernois(k):
    L, P = 12.0, 10.0
    k.corps(0, 0, 0, L, P, 1, 2.6, "pierre_grise", fen=fen(avant=3, gauche=2, droite=2, l=0.9, h=1.0),
            porte={"l": 1.0, "h": 2.1, "couleur": "bois_sombre"})
    k.corps(0, 0, 2.6, L, P, 2, 2.7, "bois", fen=fen(avant=4, arriere=3, gauche=3, droite=3, l=1.0, h=1.2,
                                                       volets="vert", cadre="blanc"))
    k.balcons(0, 0, 2.6, L, P, 3, 2.7, "avant", nb=1, prof=1.4, dalle="bois_sombre", garde="bois_clair")
    k.toit_2pans(0, 0, 8.0, P, L, 2.6, "bois_gris", axe="y", pignon="bois", debord=1.4, rangs=6)
    k.cheminee(3.0, 2.0, 8.0, 3.2, "pierre_grise")


@batiment(F, "chalet_valaisan", "Chalet valaisan", "logement", 520_000,
          "Chalet de mélèze bruni sur rez de pierre blanchie, toit de lauzes.",
          "Maisons d'Evolène et du val d'Hérens (Valais)", era="traditionnel", logements=1, role="maison",
          zone="R")
def chalet_valaisan(k):
    L, P = 8.0, 8.0
    k.corps(0, 0, 0, L, P, 1, 2.6, "enduit_blanc", fen=fen(avant=2, gauche=1, l=0.7, h=0.8),
            porte={"l": 1.0, "h": 2.0, "couleur": "bois_sombre", "u": 1.8})
    k.corps(0, 0, 2.6, L, P, 2, 2.5, "bois_sombre", fen=fen(avant=3, arriere=2, gauche=2, droite=2, l=0.7, h=0.9,
                                                             cadre="blanc"))
    k.toit_2pans(0, 0, 7.6, P, L, 2.4, "pierre_grise", axe="y", pignon="bois_sombre", debord=0.8, rangs=5)


@batiment(F, "maison_normande", "Maison normande", "logement", 420_000,
          "Maison à colombages, torchis blanc et toit de chaume à forte pente.",
          "Chaumières du pays d'Auge (Normandie)", era="traditionnel", logements=1, role="maison", zone="R")
def maison_normande(k):
    L, P = 12.0, 7.0
    k.corps(0, 0, 0, L, P, 2, 2.6, "enduit_blanc", fen=fen(avant=4, arriere=3, l=0.9, h=1.0, cadre="bois_sombre"),
            porte={"l": 1.0, "h": 2.0, "couleur": "bois_sombre"}, socle="brique")
    k.colombages(0, 0, L, P, 0.4, 2, 2.4, "bois_sombre")
    k.toit_2pans(0, 0, 5.2, L, P, 4.4, "chaume", axe="x", pignon="enduit_blanc", debord=0.7, rangs=5)
    k.cheminee(-L / 2 + 1.0, 0.8, 5.2, 4.6, "brique")


@batiment(F, "maison_alsacienne", "Maison alsacienne", "logement", 560_000,
          "Maison à colombages ocre, pignon sur rue et toit pentu à tuiles plates.",
          "Maisons de Riquewihr et de Colmar (Alsace)", era="traditionnel", logements=1, role="maison", zone="R")
def maison_alsacienne(k):
    L, P = 9.0, 11.0
    k.corps(0, 0, 0, L, P, 1, 2.8, "pierre_claire", fen=fen(avant=2, gauche=3, droite=3, l=0.9, h=1.1),
            porte={"l": 1.1, "h": 2.2, "couleur": "bois_rouge", "forme": "arc"})
    k.corps(0, 0, 2.8, L + 0.4, P, 2, 2.6, "ocre", fen=fen(avant=3, arriere=3, gauche=3, droite=3, l=0.9, h=1.1,
                                                             volets="vert", cadre="blanc"))
    k.colombages(0, 0, L + 0.4, P, 2.8, 2, 2.6, "bois_rouge", pas=1.2)
    k.toit_2pans(0, 0, 8.0, P, L + 0.4, 6.0, "tuile", axe="y", pignon="ocre", debord=0.4, rangs=8)


@batiment(F, "mas_provencal", "Mas provençal", "logement", 690_000,
          "Mas en pierre enduite ocre, tuiles canal, volets bleu lavande.",
          "Mas du Luberon et des Alpilles (Provence)", region="mediterranee", era="traditionnel", logements=1,
          role="maison", zone="R")
def mas(k):
    k.corps(0, 0, 0, 14, 8, 2, 2.9, "ocre", fen=fen(avant=4, arriere=3, gauche=2, l=0.9, h=1.2, volets="bleu",
                                                     cadre="pierre_claire"),
            porte={"l": 1.2, "h": 2.3, "couleur": "bleu"})
    k.toit_2pans(0, 0, 5.8, 14, 8, 1.6, "tuile", axe="x", pignon="ocre", debord=0.4, rangs=6)
    k.corps(9.5, 1.0, 0, 5, 6, 1, 3.2, "enduit_chaud", fen=fen(avant=1, l=1.6, h=1.6, cadre="pierre_claire"))
    k.toit_2pans(9.5, 1.0, 3.2, 6, 5, 1.0, "tuile", axe="y", pignon="enduit_chaud", debord=0.3, rangs=4)
    k.cheminee(-4.0, 1.5, 5.8, 2.6, "pierre_claire")


@batiment(F, "longere_bretonne", "Longère bretonne", "logement", 380_000,
          "Longue maison de granit, ardoises et cheminées aux pignons.",
          "Longères du Finistère (Bretagne)", era="traditionnel", logements=1, role="maison", zone="R")
def longere(k):
    L, P = 16.0, 6.5
    k.corps(0, 0, 0, L, P, 1, 3.0, "granit", fen=fen(avant=4, arriere=2, l=0.9, h=1.1, cadre="pierre_claire",
                                                      volets="bleu"),
            porte={"l": 1.0, "h": 2.1, "couleur": "bleu"})
    k.toit_2pans(0, 0, 3.0, L, P, 3.4, "ardoise", axe="x", pignon="granit", debord=0.15, rangs=6)
    for s in (-1, 1):
        k.cheminee(s * (L / 2 - 0.4), 0, 5.6, 1.6, "granit", l=0.9)
    for x in (-3.5, 3.5):
        k.boite(x, -P / 2 + 0.6, 2.6, 1.4, 1.2, 1.6, "granit")
        k.toit_2pans(x, -P / 2 + 0.6, 4.2, 1.2, 1.4, 0.7, "ardoise", axe="y", debord=0.1, pignon="granit")


@batiment(F, "maison_basque", "Maison basque", "logement", 640_000,
          "Etxe blanche aux colombages rouges, toit dissymétrique.",
          "Fermes labourdines (Ainhoa, Espelette)", era="traditionnel", logements=2, role="maison", zone="R")
def basque(k):
    L, P = 12.0, 12.0
    k.corps(0, 0, 0, L, P, 2, 3.0, "enduit_blanc", fen=fen(avant=4, arriere=3, gauche=3, droite=3, l=1.0, h=1.2,
                                                            volets="bois_rouge", cadre="pierre_claire"),
            porte={"l": 2.0, "h": 2.6, "couleur": "bois_rouge", "forme": "arc"})
    k.colombages(0, 0, L, P, 3.0, 1, 3.0, "bois_rouge", cotes=("avant",), croix=False, pas=2.0)
    k.toit_2pans(0, 0, 6.0, P, L, 3.0, "tuile", axe="y", pignon="enduit_blanc", debord=0.9, rangs=6)


@batiment(F, "cottage_anglais", "Cottage anglais", "logement", 610_000,
          "Cottage de pierre dorée, toit de chaume épais et souches de cheminée.",
          "Cottages des Cotswolds (Angleterre)", era="traditionnel", logements=1, role="maison", zone="R")
def cottage(k):
    k.corps(0, 0, 0, 11, 6.5, 2, 2.5, "ocre", fen=fen(avant=3, arriere=2, l=0.9, h=1.0, cadre="blanc"),
            porte={"l": 1.0, "h": 2.0, "couleur": "vert"})
    k.toit_2pans(0, 0, 4.4, 11, 6.5, 3.6, "chaume", axe="x", pignon="ocre", debord=0.6, rangs=5)
    for s in (-1, 1):
        k.cheminee(s * 5.2, 0, 4.4, 4.4, "brique", l=0.8)
    k.porche(0, -3.25, 2.4, 1.2, 2.4, 2, toit="chaume", poteau="bois_sombre", sol="pierre")


@batiment(F, "maison_canal", "Maison de canal", "logement", 1_400_000,
          "Haute maison de brique étroite à pignon à redents et poulie de levage.",
          "Grachtenhuizen d'Amsterdam (XVIIe s.)", era="traditionnel", logements=3, role="maison", zone="R")
def maison_canal(k):
    L, P = 7.0, 14.0
    k.corps(0, 0, 0, L, P, 4, 3.0, "brique_sombre", fen=fen(avant=2, arriere=2, l=1.2, h=1.8, cadre="blanc"),
            porte={"l": 1.1, "h": 2.4, "couleur": "vert", "u": -1.6}, socle="pierre_grise")
    k.toit_2pans(0, 0, 12.0, P, L, 4.6, "tuile", axe="y", pignon="brique_sombre", debord=0.05)
    k.redents(0, -P / 2, L, 12.0, 5.0, 3, "brique_sombre", cote="avant")
    k.boite(0, -P / 2 - 0.5, 16.2, 0.2, 1.0, 0.2, "bois_sombre")


@batiment(F, "maison_scandinave", "Maison scandinave", "logement", 450_000,
          "Maison de bois peinte au rouge de Falun, encadrements blancs.",
          "Maisons rurales suédoises (Dalécarlie)", era="traditionnel", logements=1, role="maison", zone="R")
def scandinave(k):
    k.corps(0, 0, 0, 10, 7, 2, 2.6, "bardage_rouge", fen=fen(avant=3, arriere=3, gauche=2, droite=2, l=0.9, h=1.2,
                                                              cadre="blanc"),
            porte={"l": 1.0, "h": 2.1, "couleur": "blanc"}, socle="pierre_grise")
    k.toit_2pans(0, 0, 5.6, 10, 7, 2.6, "noir", axe="x", pignon="bardage_rouge", debord=0.4, rangs=5)
    k.cheminee(0, 0.5, 5.6, 3.0, "blanc")
    k.porche(0, -3.5, 2.6, 1.6, 2.6, 2, toit="noir", poteau="blanc", sol="bois_gris")


@batiment(F, "isba", "Isba", "logement", 300_000,
          "Maison de rondins, fenêtres à encadrements sculptés peints.",
          "Isbas du nord de la Russie (Kiji, Souzdal)", era="traditionnel", logements=1, role="maison", zone="R")
def isba(k):
    k.corps(0, 0, 0, 8, 9, 1, 3.4, "bois", fen=fen(avant=3, gauche=2, droite=2, l=0.8, h=1.1, cadre="bleu",
                                                    volets="blanc"),
            porte={"l": 1.0, "h": 2.0, "couleur": "bois_sombre", "cote": "gauche"}, socle="pierre_grise")
    for i in range(6):
        k.boite(0, 0, 0.4 + i * 0.5, 8.4, 9.4, 0.12, "bois_sombre")
    k.toit_2pans(0, 0, 3.4, 9, 8, 3.6, "bois_gris", axe="y", pignon="bois", debord=0.5, rangs=5)
    k.ouverture(0, -4.5, (0, -1), 0, 5.0, 0.8, 0.8, "vitre", "bleu")


# --- Maisons traditionnelles du monde ---------------------------------------------------

@batiment(F, "trullo", "Trullo", "logement", 350_000,
          "Maisonnettes blanchies à la chaux coiffées de cônes de pierre sèche.",
          "Trulli d'Alberobello (Pouilles, UNESCO)", region="mediterranee", era="traditionnel", logements=1,
          role="maison", zone="R")
def trullo(k):
    k.boite(0, 0, 0, 9, 4.5, 2.4, "enduit_blanc")
    for i, x in enumerate((-2.5, 2.5, 0.0)):
        y = 0 if i < 2 else 3.2
        k.cyl(x, y, 0, 2.4, 2.1, "enduit_blanc", n=10)
        k.tronc_cone(x, y, 2.4, 3.4, 2.2, 0.35, "pierre_grise", n=10)
        k.dome(x, y, 5.8, 0.4, "enduit_blanc", n=8, anneaux=2)
    k.porte(0, -2.25, (0, -1), 0, 0, 1.0, 2.0, "vert", "enduit_blanc", "arc")
    k.ouverture(0, -2.25, (0, -1), 3.2, 1.4, 0.6, 0.7, "vitre", "pierre_claire")


@batiment(F, "maison_cycladique", "Maison des Cyclades", "logement", 520_000,
          "Cubes blanchis à la chaux, terrasse, petite coupole et volets bleus.",
          "Maisons d'Oia (Santorin) et de Mykonos", region="mediterranee", era="traditionnel", logements=1,
          role="maison", zone="R")
def cyclades(k):
    k.corps(0, 0, 0, 8, 7, 1, 3.0, "enduit_blanc", fen=fen(avant=2, gauche=1, droite=1, l=0.8, h=1.0, volets="bleu",
                                                            cadre=None),
            porte={"l": 1.0, "h": 2.1, "couleur": "bleu", "cadre": None})
    k.toit_plat(0, 0, 3.0, 8, 7, "enduit_blanc", acrotere=0.4, c_acrotere="enduit_blanc", ep=0.2)
    k.corps(-1.5, 1.0, 3.6, 5, 4.5, 1, 2.8, "enduit_blanc", fen=fen(avant=1, droite=1, l=0.8, h=1.0, volets="bleu",
                                                                     cadre=None))
    k.dome(-1.5, 1.0, 6.4, 1.6, "bleu", n=10, anneaux=3)
    k.boite(-1.5, 1.0, 6.4, 3.4, 3.4, 0.01, "enduit_blanc")


@batiment(F, "riad", "Riad", "logement", 900_000,
          "Maison à patio aux murs ocre, terrasses et petites ouvertures.",
          "Riads de la médina de Marrakech", region="moyen_orient", era="traditionnel", logements=1,
          role="villa", zone="R")
def riad(k):
    L = 14.0
    for (x, y, sx, sy) in ((0, -L / 2 + 2, L, 4), (0, L / 2 - 2, L, 4), (-L / 2 + 2, 0, 4, L - 8),
                           (L / 2 - 2, 0, 4, L - 8)):
        k.boite(x, y, 0, sx, sy, 7.0, "terre")
        k.boite(x, y, 7.0, sx, sy, 0.6, "ocre")
    (fx, fy), n, lg = k._facades(0, 0, L, L)["avant"]
    k.porte(fx, fy, n, 0, 0, 1.6, 2.8, "bois_sombre", "pierre_claire", "arc")
    for u in (-4.0, 4.0):
        k.ouverture(fx, fy, n, u, 5.2, 0.6, 0.9, "vitre", "bois_sombre")
    k.sol(0, 0, L - 8, L - 8, "pierre_claire", h=0.05)
    k.cyl(0, 0, 0, 0.6, 1.0, "bleu", n=8)
    for x in (-3, 3):
        for y in (-3, 3):
            k.boite(x, y, 0, 0.4, 0.4, 3.2, "pierre_claire")


@batiment(F, "minka", "Minka", "logement", 650_000,
          "Ferme japonaise à grand toit de chaume en croupe et galerie de bois.",
          "Minka de Shirakawa-gō et des maisons rurales japonaises", region="asie_est", era="traditionnel",
          logements=1, role="maison", zone="R", sans_vitres=1)
def minka(k):
    k.boite(0, 0, 0, 15, 10, 0.6, "pierre_grise")
    k.corps(0, 0, 0.6, 14, 9, 1, 4.2, "bois_sombre", fen=fen(avant=5, arriere=4, gauche=2, droite=2, l=1.6, h=1.6,
                                                              vitre="enduit_blanc", cadre="bois_sombre"))
    k.toit_4pans(0, 0, 4.8, 14, 9, 6.0, "chaume", debord=0.8)
    k.toit_2pans(0, 0, 9.4, 5, 3.2, 1.4, "chaume", axe="x", debord=0.3, pignon="bois_sombre")


@batiment(F, "machiya", "Machiya", "logement", 820_000,
          "Maison de ville de Kyoto : façade de lattes de bois, auvent et tuiles grises.",
          "Kyō-machiya du quartier de Gion (Kyoto)", region="asie_est", era="traditionnel", logements=1,
          role="maison", zone="R", sans_vitres=1)
def machiya(k):
    k.corps(0, 0, 0, 7, 14, 2, 2.9, "bois_sombre", fen=fen(avant=2, l=2.2, h=1.4, vitre="bois", cadre="bois_sombre"),
            porte={"l": 1.6, "h": 2.2, "couleur": "bois", "cadre": "bois_sombre"})
    k.f([(-3.7, -8.2, 2.4), (3.7, -8.2, 2.4), (3.7, -7.0, 3.0), (-3.7, -7.0, 3.0)], "ardoise", vers=(0, -1, 2))
    k.toit_2pans(0, 0, 5.8, 7, 14, 2.0, "ardoise", axe="x", pignon="enduit_blanc", debord=0.6, rangs=5)


@batiment(F, "siheyuan", "Siheyuan", "logement", 1_600_000,
          "Maison à cour carrée de Pékin : quatre ailes de briques grises et toits courbes.",
          "Siheyuan des hutong de Pékin", region="asie_est", era="traditionnel", logements=2,
          role="villa", zone="R")
def siheyuan(k):
    for (x, y, l, p, axe) in ((0, 7, 18, 6, "x"), (-7, -1, 4, 10, "y"), (7, -1, 4, 10, "y"), (0, -8, 18, 4, "x")):
        k.corps(x, y, 0, l, p, 1, 3.4, "pierre_grise",
                fen=fen(avant=3 if axe == "x" and y > 0 else 0, gauche=2 if x > 0 else 0, droite=2 if x < 0 else 0,
                        l=1.4, h=1.6, vitre="vitre", cadre="bois_rouge"))
        k.toit_2pans(x, y, 3.4, l if axe == "x" else p, p if axe == "x" else l, 1.6, "ardoise", axe=axe,
                     debord=0.7, pignon="pierre_grise", rangs=4)
    (fx, fy), n, _ = k._facades(0, -8, 18, 4)["avant"]
    k.porte(fx, fy, n, -6.0, 0, 1.6, 2.6, "bois_rouge", "bois_sombre")


@batiment(F, "maison_pilotis", "Maison thaïe sur pilotis", "logement", 280_000,
          "Maison de teck sur pilotis, toits pentus aux pignons recourbés.",
          "Maisons traditionnelles du centre de la Thaïlande", region="asie_sud", era="traditionnel", logements=1,
          role="maison", zone="R", sans_vitres=1)
def pilotis(k):
    k.pilotis(0, 0, 10, 8, 2.4, 4, 3, "bois_sombre")
    k.boite(0, 0, 2.4, 11, 9, 0.2, "bois")
    k.corps(-1.5, 0.5, 2.6, 6, 6, 1, 3.0, "bois", fen=fen(avant=2, gauche=1, droite=1, l=1.0, h=1.3,
                                                           vitre="bois_sombre", cadre="bois_sombre"),
            porte={"l": 1.0, "h": 2.1, "couleur": "bois_sombre"})
    k.toit_2pans(-1.5, 0.5, 5.6, 6, 6, 3.6, "tuile", axe="y", pignon="bois", debord=0.6)
    k.boite(3.5, -4.6, 0, 1.0, 3.0, 2.4, "bois_sombre")


@batiment(F, "cases_rondes", "Cases rondes", "logement", 120_000,
          "Trois cases de terre aux toits de paille coniques autour d'une cour.",
          "Cases traditionnelles d'Afrique de l'Ouest (pays dogon, Sénégal)", region="afrique", era="traditionnel",
          logements=1, role="maison", zone="R")
def cases(k):
    k.sol(0, 0, 14, 12, "terre", h=0.03)
    for (x, y, r) in ((-3.5, 2.0, 2.4), (3.5, 2.0, 2.0), (0, -3.0, 1.8)):
        k.cyl(x, y, 0, 2.4, r, "terre", n=10)
        k.tronc_cone(x, y, 2.3, 3.0, r + 0.6, 0, "chaume", n=10)
        k.porte(x, y - r, (0, -1), 0, 0, 0.8, 1.6, "bois_sombre", None)
        k.ouverture(x - r, y, (-1, 0), 0, 1.4, 0.5, 0.5, "vitre", None)
    k.cloture([(-7, -6), (7, -6), (7, 6), (-7, 6)], h=1.4, c="chaume")


@batiment(F, "pueblo_adobe", "Maison d'adobe", "logement", 480_000,
          "Volumes d'adobe arrondis en gradins, poutres saillantes (vigas).",
          "Taos Pueblo et maisons de Santa Fe (Nouveau-Mexique)", region="ameriques", era="traditionnel",
          logements=2, role="maison", zone="R")
def adobe(k):
    k.corps(0, 0, 0, 14, 10, 1, 3.2, "terre", fen=fen(avant=3, gauche=2, droite=2, l=0.9, h=1.0, cadre="bleu"),
            porte={"l": 1.0, "h": 2.1, "couleur": "bleu", "cadre": "bois"})
    k.toit_plat(0, 0, 3.2, 14, 10, "terre", acrotere=0.4, c_acrotere="terre", ep=0.2)
    k.corps(-2, 1.5, 3.8, 8, 6, 1, 2.8, "terre", fen=fen(avant=2, l=0.8, h=0.9, cadre="bleu"))
    k.toit_plat(-2, 1.5, 6.6, 8, 6, "terre", acrotere=0.3, c_acrotere="terre", ep=0.2)
    for i in range(6):
        k.boite(-5.5 + i * 1.4, -5.3, 2.9, 0.2, 0.8, 0.2, "bois_sombre")


@batiment(F, "victorienne", "Maison victorienne", "logement", 1_900_000,
          "« Painted lady » à bow-window, tourelle et façade pastel.",
          "Painted Ladies d'Alamo Square (San Francisco)", region="ameriques", era="classique", logements=2,
          role="maison", zone="R")
def victorienne(k):
    L, P = 8.0, 14.0
    k.corps(0, 0, 0, L, P, 3, 3.2, "enduit_bleu", fen=fen(avant=2, arriere=2, gauche=4, droite=4, l=1.0, h=1.8,
                                                           cadre="blanc"),
            porte={"l": 1.1, "h": 2.4, "couleur": "bois_rouge", "u": 2.2}, socle="blanc", bandeaux="blanc")
    k.toit_2pans(0, 0, 9.6, P, L, 3.6, "ardoise", axe="y", pignon="enduit_bleu", debord=0.4)
    k.boite(-1.4, -P / 2 - 0.9, 0.4, 3.6, 1.8, 6.0, "enduit_bleu")
    (fx, fy), n, _ = k._facades(-1.4, -P / 2 - 0.9, 3.6, 1.8)["avant"]
    for z in (2.2, 5.2):
        k.ouverture(fx, fy, n, 0, z, 2.4, 1.8, "vitre", "blanc")
    k.boite(-1.4, -P / 2 - 0.9, 6.4, 4.0, 2.2, 0.3, "blanc")
    k.cyl(L / 2 - 0.4, -P / 2 + 0.4, 0, 11.0, 1.4, "enduit_rose", n=8)
    k.tronc_cone(L / 2 - 0.4, -P / 2 + 0.4, 11.0, 3.0, 1.6, 0, "ardoise", n=8)


@batiment(F, "maison_coloniale", "Maison coloniale", "logement", 1_200_000,
          "Maison à étage symétrique, colonnes blanches et grand porche.",
          "Maisons néo-coloniales de Nouvelle-Angleterre et du Sud des États-Unis", region="ameriques",
          era="classique", logements=1, role="villa", zone="R")
def coloniale(k):
    L, P = 16.0, 10.0
    k.corps(0, 0, 0, L, P, 2, 3.2, "blanc", fen=fen(avant=5, arriere=5, gauche=2, droite=2, l=1.0, h=1.6,
                                                     volets="noir", cadre="blanc"),
            porte={"l": 1.2, "h": 2.4, "couleur": "noir"}, socle="brique")
    k.toit_2pans(0, 0, 6.4, L, P, 3.0, "ardoise", axe="x", pignon="blanc", debord=0.4)
    k.colonnes(0, -P / 2 - 1.8, 0.4, 10.0, 6, 5.8, 0.25, "blanc", fronton="ardoise", prof=2.0)
    for s in (-1, 1):
        k.cheminee(s * (L / 2 - 0.6), 0, 6.4, 4.0, "brique")


@batiment(F, "ranch", "Maison ranch", "logement", 520_000,
          "Maison de plain-pied tout en longueur, toit bas et garage attenant.",
          "Ranch houses américaines des années 1950", region="ameriques", era="moderne", logements=1,
          role="maison", zone="R")
def ranch(k):
    k.corps(0, 0, 0, 18, 9, 1, 2.8, "bardage", fen=fen(avant=5, arriere=4, gauche=2, droite=2, l=1.6, h=1.2,
                                                        cadre="blanc", volets="bleu"),
            porte={"l": 1.0, "h": 2.1, "couleur": "rouge", "u": -2.0})
    k.toit_4pans(0, 0, 2.8, 18, 9, 1.6, "ardoise", debord=0.7)
    k.corps(12.0, 1.0, 0, 6, 7, 1, 2.6, "bardage")
    k.ouverture(12.0, -2.5, (0, -1), 0, 1.2, 5.0, 2.2, "blanc", "blanc")
    k.toit_4pans(12.0, 1.0, 2.6, 6, 7, 1.2, "ardoise", debord=0.5)


@batiment(F, "queenslander", "Maison du Queensland", "logement", 640_000,
          "Maison de bois sur pilotis, véranda tout autour et toit de tôle.",
          "Queenslanders de Brisbane (Australie)", region="oceanie", era="classique", logements=1,
          role="maison", zone="R")
def queenslander(k):
    k.pilotis(0, 0, 12, 12, 2.0, 4, 4, "bois_gris", r=0.15)
    k.boite(0, 0, 2.0, 13, 13, 0.25, "bois_gris")
    k.corps(0, 0, 2.25, 9, 9, 1, 3.0, "blanc", fen=fen(avant=3, arriere=3, gauche=3, droite=3, l=1.2, h=1.6,
                                                        cadre="vert"),
            porte={"l": 1.0, "h": 2.2, "couleur": "vert"})
    k.toit_4pans(0, 0, 5.25, 9, 9, 3.4, "tole_rouge", debord=2.0)
    for i in range(5):
        for s in (-1, 1):
            k.boite(-6 + i * 3, s * 6.2, 2.25, 0.15, 0.15, 2.4, "blanc")
            k.boite(s * 6.2, -6 + i * 3, 2.25, 0.15, 0.15, 2.4, "blanc")
    k.boite(0, -7.6, 0, 2.0, 2.4, 2.0, "bois_gris")


# --- Maisons modernes ----------------------------------------------------------------------

@batiment(F, "pavillon", "Pavillon", "logement", 310_000,
          "Pavillon de lotissement : crépi clair, tuiles, garage accolé.",
          "Maisons de lotissement françaises des années 1980-2000", era="moderne", logements=1, role="maison",
          zone="R")
def pavillon(k):
    k.corps(0, 0, 0, 10, 8, 2, 2.7, "enduit_chaud", fen=fen(avant=3, arriere=3, gauche=2, droite=1, l=1.0, h=1.2,
                                                             volets="volet", cadre="blanc"),
            porte={"l": 1.0, "h": 2.15, "couleur": "porte", "u": -1.6}, socle="socle")
    k.toit_4pans(0, 0, 5.4, 10, 8, 2.6, "tuile", debord=0.4)
    k.corps(7.6, 0.5, 0, 5.2, 7, 1, 2.6, "enduit_chaud")
    k.ouverture(7.6, -3.0, (0, -1), 0, 1.15, 2.6, 2.1, "blanc", "blanc")
    k.toit_mono(7.6, 0.5, 2.6, 5.2, 7, 0.5, "tuile", debord=0.2)


@batiment(F, "maison_contemporaine", "Maison contemporaine", "logement", 820_000,
          "Deux cubes décalés, toit plat, grandes baies et bardage de bois.",
          "Maisons d'architecte des années 2010", era="contemporain", logements=1, role="villa", zone="R")
def contemporaine(k):
    k.corps(0, 0, 0, 14, 9, 1, 3.2, "blanc", fen=fen(avant=2, arriere=2, gauche=1, droite=1, l=4.0, h=2.4,
                                                      vitre="verre_bleu", cadre="noir"),
            porte={"l": 1.2, "h": 2.4, "couleur": "noir", "cadre": None})
    k.toit_plat(0, 0, 3.2, 14, 9, "beton_sombre", acrotere=0.3, c_acrotere="blanc", ep=0.25)
    k.corps(2.5, 1.5, 3.75, 10, 8, 1, 3.0, "bois_clair", fen=fen(avant=2, arriere=2, droite=1, l=3.0, h=1.6,
                                                                   vitre="verre_bleu", cadre="noir"))
    k.toit_plat(2.5, 1.5, 6.75, 10, 8, "beton_sombre", acrotere=0.3, c_acrotere="noir", ep=0.25)


@batiment(F, "villa_moderniste", "Villa moderniste", "logement", 2_400_000,
          "Boîte blanche sur pilotis, fenêtres en bandeau et solarium sur le toit.",
          "D'après la villa Savoye (Le Corbusier, Poissy, 1931)", era="classique", logements=1, role="villa",
          zone="R")
def savoye(k):
    k.pilotis(0, 0, 19, 19, 3.2, 5, 5, "blanc", r=0.15)
    k.b.cylindre(0, 2.0, 0, 3.2, 5.0, "vert", n=12, a0=0, a1=180)
    k.boite(0, -1.0, 0, 10, 6, 3.2, "vert")
    k.corps(0, 0, 3.2, 19, 19, 1, 3.3, "blanc", fen=fen(avant=1, arriere=1, gauche=1, droite=1, bande=True, h=1.1,
                                                          vitre="vitre", cadre=None))
    k.toit_plat(0, 0, 6.5, 19, 19, "beton_clair", acrotere=0.2, c_acrotere="blanc", ep=0.15)
    k.b.cylindre(-3.0, 4.0, 6.85, 9.6, 3.0, "enduit_rose", n=10, a0=90, a1=270, dessus=True)
    k.boite(1.0, 4.0, 6.85, 8.0, 0.25, 2.75, "enduit_bleu")


@batiment(F, "villa_mid_century", "Villa californienne", "logement", 2_900_000,
          "Pavillon de verre et d'acier à toit plat très débordant.",
          "Case Study Houses (Los Angeles, années 1950)", region="ameriques", era="moderne", logements=1,
          role="villa", zone="R")
def mid_century(k):
    k.boite(0, 0, 0, 22, 14, 0.3, "beton_clair")
    k.boite(0, 0, 0.3, 20, 11, 3.0, "verre_ciel")
    for i in range(7):
        x = -10 + i * 20 / 6
        for y in (-5.6, 5.6):
            k.boite(x, y, 0.3, 0.2, 0.2, 3.0, "noir")
    k.boite(-6, 0, 0.3, 6, 11.1, 3.0, "pierre_grise")
    k.boite(0, 0, 3.3, 24, 15, 0.35, "blanc")


@batiment(F, "maison_bois", "Maison ossature bois", "logement", 450_000,
          "Maison passive en bois clair, toit à deux pans et panneaux solaires.",
          "Maisons passives du Vorarlberg et de Scandinavie", era="contemporain", logements=1, role="maison",
          zone="R")
def maison_bois(k):
    k.corps(0, 0, 0, 11, 8, 2, 2.8, "bois_clair", fen=fen(avant=2, arriere=3, gauche=1, droite=1, l=1.8, h=1.6,
                                                           vitre="verre_bleu", cadre="noir"),
            porte={"l": 1.1, "h": 2.2, "couleur": "noir", "cadre": None})
    k.toit_2pans(0, 0, 5.6, 11, 8, 2.8, "noir", axe="x", pignon="bois_clair", debord=0.15)
    k.f([(-4.5, -4.1, 5.9), (4.5, -4.1, 5.9), (4.5, -1.0, 7.95), (-4.5, -1.0, 7.95)], "verre_nuit", vers=(0, -1, 1.4))


@batiment(F, "maisons_en_bande", "Maisons en bande", "logement", 1_300_000,
          "Quatre maisons de brique mitoyennes avec bow-windows.",
          "Terraced houses de l'époque victorienne (Londres, Manchester)", era="classique", logements=4,
          role="maison", zone="R")
def bande(k):
    for i in range(4):
        x = -9 + i * 6
        k.corps(x, 0, 0, 6, 10, 2, 3.0, "brique", fen=fen(avant=1, arriere=2, l=1.2, h=1.6, cadre="blanc"),
                porte={"l": 1.0, "h": 2.2, "couleur": ("bleu", "rouge", "vert", "noir")[i], "u": 1.8},
                socle="pierre_claire")
        k.boite(x - 0.8, -5.7, 0.4, 2.8, 1.4, 2.6, "pierre_claire")
        (fx, fy), n, _ = k._facades(x - 0.8, -5.7, 2.8, 1.4)["avant"]
        k.ouverture(fx, fy, n, 0, 1.8, 2.0, 1.6, "vitre", "blanc")
        k.cheminee(x + 2.9, 0, 6.0, 2.6, "brique")
    k.toit_2pans(0, 0, 6.0, 24, 10, 2.8, "ardoise", axe="x", pignon="brique", debord=0.3)


# --- Immeubles ----------------------------------------------------------------------------

@batiment(F, "immeuble_haussmannien", "Immeuble haussmannien", "logement", 9_000_000,
          "Pierre de taille, balcons filants aux 2e et 5e étages, toit mansardé en zinc.",
          "Immeubles du baron Haussmann (Paris, 1853-1870)", era="classique", logements=18, role="immeuble",
          zone="R")
def haussmann(k):
    L, P = 20.0, 14.0
    k.corps(0, 0, 0, L, P, 6, 3.2, "pierre_claire", fen=fen(avant=6, arriere=6, gauche=2, droite=2, l=1.2, h=2.0,
                                                             cadre="pierre_claire"),
            porte={"l": 2.2, "h": 3.0, "couleur": "vert", "forme": "arc"}, socle="pierre", bandeaux="pierre")
    for e in (2, 5):
        (fx, fy), n, lg = k._facades(0, 0, L, P)["avant"]
        k.b.boite_mur(fx, fy, n, -lg / 2, lg / 2, e * 3.2 - 0.15, e * 3.2, 0.9, "pierre")
        p, _, (nx, ny) = k.b.repere(fx, fy, n)
        k.b.face_orientee([p(-lg / 2, e * 3.2, 0.9), p(lg / 2, e * 3.2, 0.9), p(lg / 2, e * 3.2 + 1.0, 0.9),
                           p(-lg / 2, e * 3.2 + 1.0, 0.9)], "noir", (nx, ny, 0))
    k.toit_mansarde(0, 0, 19.2, L, P, 3.4, 1.6, "zinc", c_haut="zinc", lucarnes=5, mur="pierre_claire")
    for x in (-7, 0, 7):
        k.cheminee(x, 0, 23.0, 2.0, "brique_claire", l=1.4)


@batiment(F, "immeuble_annees30", "Immeuble Art déco", "logement", 6_500_000,
          "Immeuble de briques et béton, bow-windows d'angle et attique en retrait.",
          "Immeubles des années 1930 (Boulogne-Billancourt, Genève, Tel-Aviv)", era="classique", logements=14,
          role="immeuble", zone="R")
def art_deco(k):
    L, P = 18.0, 14.0
    k.corps(0, 0, 0, L, P, 5, 3.0, "brique_claire", fen=fen(avant=5, arriere=5, gauche=3, droite=3, l=1.4, h=1.6,
                                                             cadre="blanc"),
            porte={"l": 2.0, "h": 2.6, "couleur": "noir"}, socle="granit", bandeaux="beton_clair")
    for s in (-1, 1):
        k.boite(s * 5.5, -P / 2 - 0.6, 3.0, 3.0, 1.2, 12.0, "beton_clair")
        (fx, fy), n, _ = k._facades(s * 5.5, -P / 2 - 0.6, 3.0, 1.2)["avant"]
        for e in range(4):
            k.ouverture(fx, fy, n, 0, 4.6 + e * 3.0, 2.2, 1.6, "vitre", "blanc")
    k.corps(0, 1.0, 15.0, L - 4, P - 4, 1, 3.0, "beton_clair", fen=fen(avant=4, arriere=4, l=1.6, h=1.8))
    k.toit_plat(0, 1.0, 18.0, L - 4, P - 4, "beton_sombre", acrotere=0.4)
    k.boite(0, 0, 15.0, L, P, 0.01, "beton_sombre")


@batiment(F, "brownstone", "Brownstone", "logement", 3_600_000,
          "Maison de ville new-yorkaise en grès brun, perron et corniche saillante.",
          "Brownstones de Brooklyn et Harlem (New York)", region="ameriques", era="classique", logements=4,
          role="immeuble", zone="R")
def brownstone(k):
    L, P = 7.0, 16.0
    k.corps(0, 0, 0, L, P, 4, 3.2, "brique_sombre", fen=fen(avant=3, arriere=3, l=1.0, h=1.9, cadre="pierre_claire"),
            socle="brique_sombre")
    k.porte(0, -P / 2, (0, -1), -2.0, 1.8, 1.2, 2.4, "bois_sombre", "pierre_claire")
    for i in range(7):
        k.boite(-2.0, -P / 2 - 3.2 + i * 0.4, 0, 1.8, 0.4 + 0.01, 0.26 * (i + 1), "brique_sombre")
    k.toit_plat(0, 0, 12.8, L, P, "beton_sombre", acrotere=0.0)
    k.boite(0, -P / 2 - 0.4, 12.8, L + 0.4, 0.8, 0.9, "noir")


@batiment(F, "plattenbau", "Barre préfabriquée", "logement", 16_000_000,
          "Bloc de panneaux de béton préfabriqués, onze étages, loggias.",
          "Plattenbau WBS 70 (Berlin-Marzahn, Halle-Neustadt)", era="moderne", logements=88, role="immeuble",
          zone="R")
def plattenbau(k):
    L, P = 60.0, 12.0
    k.corps(0, 0, 0, L, P, 11, 2.8, "beton_clair", fen=fen(avant=14, arriere=14, gauche=2, droite=2, l=2.0, h=1.4,
                                                            vitre="vitre", cadre="beton_sombre"),
            porte={"l": 2.0, "h": 2.4, "couleur": "bois_sombre"}, bandeaux="beton_sombre")
    k.balcons(0, 0, 0, L, P, 11, 2.8, "avant", nb=10, prof=1.2, dalle="beton_clair", garde="enduit_jaune")
    k.toit_plat(0, 0, 30.8, L, P, "beton_sombre", acrotere=0.6)


@batiment(F, "grand_ensemble", "Barre de grand ensemble", "logement", 22_000_000,
          "Longue barre HLM de quatorze étages, façades rythmées et halls traversants.",
          "Grands ensembles des années 1960 (Sarcelles, La Courneuve)", era="moderne", logements=120,
          role="immeuble", zone="R")
def grand_ensemble(k):
    L, P = 90.0, 11.0
    k.corps(0, 0, 0, L, P, 14, 2.7, "enduit_blanc", fen=fen(avant=1, arriere=1, gauche=0, droite=0, bande=True,
                                                             h=1.3, vitre="vitre", rdc=False),
            porte={"l": 3.0, "h": 2.4, "couleur": "verre_nuit"}, bandeaux="beton_sombre")
    for i in range(6):
        x = -L / 2 + 7.5 + i * 15
        k.boite(x, -P / 2 - 0.2, 0, 1.2, 0.4, 37.8, "enduit_rose")
    k.toit_plat(0, 0, 37.8, L, P, "beton_sombre", acrotere=0.5)


@batiment(F, "unite_habitation", "Unité d'habitation", "logement", 40_000_000,
          "Grand paquebot de béton brut sur pilotis, loggias colorées, toit-terrasse.",
          "D'après la Cité radieuse (Le Corbusier, Marseille, 1952)", era="moderne", logements=160,
          visiteurs=100, role="immeuble", zone="R")
def unite(k):
    L, P = 110.0, 22.0
    for i in range(9):
        x = -L / 2 + 6 + i * (L - 12) / 8
        k.tronc(x, 0, 0, 1.4, 4.0, 8.0, 2.4, 6.0, "beton_sombre", dessus=False)
    k.boite(0, 0, 8.0, L, P, 0.8, "beton_sombre")
    k.corps(0, 0, 8.8, L, P, 12, 3.0, "beton_clair", fen=fen(avant=22, arriere=22, l=3.0, h=2.0, vitre="vitre",
                                                              cadre="beton_sombre"))
    (fx, fy), n, lg = k._facades(0, 0, L, P)["avant"]
    for i, c in enumerate(("rouge", "jaune", "vert", "bleu")):
        for e in (1, 4, 7, 10):
            u = -lg / 2 + 4 + ((i * 7 + e * 3) % 26) * 4
            k.b.boite_mur(fx, fy, n, u - 1.5, u + 1.5, 8.8 + e * 3.0 + 0.2, 8.8 + e * 3.0 + 2.6, 0.1, c,
                          dessous=False)
    k.toit_plat(0, 0, 44.8, L, P, "beton_clair", acrotere=1.2, c_acrotere="beton_clair")
    k.boite(-30, 0, 46.0, 12, 8, 4.0, "beton_clair")
    k.tronc_cone(25, 0, 46.0, 6.0, 2.2, 1.4, "beton_clair", n=10)


@batiment(F, "tour_residence", "Tour résidentielle", "logement", 45_000_000,
          "Tour de vingt-quatre étages, balcons filants vitrés et socle commercial.",
          "Tours de logements contemporaines (Paris rive gauche, Lyon Confluence)", era="contemporain",
          logements=150, role="tour", zone="R")
def tour_residence(k):
    k.corps(0, 0, 0, 30, 26, 1, 5.0, "pierre_grise", fen=fen(avant=1, gauche=1, droite=1, bande=True, h=3.4,
                                                              vitre="verre_bleu"),
            porte={"l": 3.0, "h": 3.0, "couleur": "verre_nuit"})
    k.toit_plat(0, 0, 5.0, 30, 26, "pelouse", acrotere=0.6, c_acrotere="blanc")
    k.corps(0, 0, 5.6, 22, 20, 24, 3.0, "blanc", fen=fen(avant=1, arriere=1, gauche=1, droite=1, bande=True, h=1.8,
                                                          vitre="verre_ciel"))
    for e in range(1, 24, 2):
        z = 5.6 + e * 3.0
        k.boite(0, 0, z - 0.15, 24.4, 22.4, 0.15, "blanc")
    k.toit_plat(0, 0, 77.6, 22, 20, "beton_sombre", acrotere=1.2, c_acrotere="blanc")


@batiment(F, "tour_verre", "Gratte-ciel résidentiel", "logement", 160_000_000,
          "Tour de verre de 45 étages, couronnement lumineux.",
          "Tours résidentielles new-yorkaises et de Dubaï (années 2010)", region="ameriques", era="contemporain",
          logements=320, role="tour", zone="R")
def tour_verre(k):
    k.boite(0, 0, 0, 30, 30, 8.0, "verre_nuit")
    k.toit_plat(0, 0, 8.0, 30, 30, "beton_sombre", acrotere=0.4)
    z = 8.4
    for (c, n_et) in ((26, 15), (23, 15), (19, 15)):
        k.boite(0, 0, z, c, c, n_et * 3.2, "verre_bleu")
        for e in range(0, n_et, 3):
            k.boite(0, 0, z + e * 3.2, c + 0.3, c + 0.3, 0.4, "zinc")
        z += n_et * 3.2
    k.boite(0, 0, z, 17, 17, 6.0, "verre_clair")
    k.boite(0, 0, z + 6.0, 17.4, 17.4, 0.6, "zinc")
    k.cyl(0, 0, z + 6.6, 14.0, 0.5, "zinc", n=6)


@batiment(F, "immeuble_bois", "Immeuble en bois", "logement", 12_000_000,
          "Immeuble de sept étages en bois, loggias et toiture végétalisée.",
          "Immeubles bois-béton contemporains (Mjøstårnet, Bordeaux Hypérion)", era="contemporain",
          logements=42, role="immeuble", zone="R")
def immeuble_bois(k):
    L, P = 28.0, 14.0
    k.corps(0, 0, 0, L, P, 7, 3.0, "bois_clair", fen=fen(avant=8, arriere=8, gauche=3, droite=3, l=1.4, h=2.0,
                                                          vitre="verre_bleu", cadre="noir"),
            porte={"l": 2.4, "h": 2.6, "couleur": "verre_nuit", "cadre": "noir"})
    k.balcons(0, 0, 0, L, P, 7, 3.0, "avant", nb=4, prof=1.6, dalle="bois_sombre", garde="verre_clair")
    k.toit_plat(0, 0, 21.0, L, P, "pelouse", acrotere=0.4, c_acrotere="bois_sombre")


@batiment(F, "tour_hong_kong", "Tour de Hong Kong", "logement", 70_000_000,
          "Tour fine de quarante étages en croix, fenêtres serrées et climatiseurs.",
          "Tours de logements publics de Hong Kong (Harmony, Concord)", region="asie_est", era="moderne",
          logements=400, role="tour", zone="R")
def hong_kong(k):
    for (sx, sy) in ((30, 12), (12, 30)):
        k.corps(0, 0, 0, sx, sy, 40, 2.8, "enduit_blanc",
                fen=fen(avant=1, arriere=1, gauche=1, droite=1, bande=True, h=1.4, vitre="vitre"),
                bandeaux="beton_clair")
        for cote in ("avant", "arriere", "gauche", "droite"):
            (fx, fy), n, lg = k._facades(0, 0, sx, sy)[cote]
            for i in range(int(lg / 3) + 1):
                u = -lg / 2 + 0.6 + i * (lg - 1.2) / int(lg / 3)
                k.b.boite_mur(fx, fy, n, u - 0.25, u + 0.25, 2.8, 112.0, 0.3, "enduit_bleu" if i % 2 else "beton_clair",
                              dessous=False)
    k.toit_plat(0, 0, 112.0, 30, 12, "beton_sombre", acrotere=0.6)
    k.toit_plat(0, 0, 112.0, 12, 30, "beton_sombre", acrotere=0.6)
    k.boite(0, 0, 112.6, 6, 6, 4.0, "enduit_bleu")
