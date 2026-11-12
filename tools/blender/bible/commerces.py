"""Commerces, loisirs et hôtels de la bible : boutiques de quartier, marchés,
grandes surfaces, restaurants, hôtels, bureaux, lieux de sortie et de sport.
Formes simplifiées d'après des bâtiments réels ou des types courants (champ
`source`)."""

import math

from registre import batiment

F = "commerces"


def fen(**kw):
    d = {"l": 1.1, "h": 1.4}
    d.update(kw)
    return d


def store(k, cx, y_facade, L, z, c, prof=1.2):
    """Store banne incliné au-dessus d'une vitrine."""
    k.f([(cx - L / 2, y_facade - prof, z - 0.5), (cx + L / 2, y_facade - prof, z - 0.5),
         (cx + L / 2, y_facade, z), (cx - L / 2, y_facade, z)], c, vers=(0, -1, 2))
    k.f([(cx - L / 2, y_facade - prof, z - 0.8), (cx + L / 2, y_facade - prof, z - 0.8),
         (cx + L / 2, y_facade - prof, z - 0.5), (cx - L / 2, y_facade - prof, z - 0.5)], c, vers=(0, -1, 0))


def enseigne(k, x, y, z, l, h, c="rouge", fond=None):
    """Panneau d'enseigne sur le toit ou en façade (face à -Y)."""
    k.boite(x, y, z, l, 0.25, h, fond or c)
    k.boite(x, y - 0.14, z + h * 0.25, l * 0.8, 0.04, h * 0.5, "blanc")


def parking(k, cx, cy, L, P, places=0):
    k.sol(cx, cy, L, P, "asphalte")
    if places:
        pas = L / places
        for i in range(places + 1):
            k.boite(cx - L / 2 + i * pas, cy, 0.04, 0.12, P * 0.7, 0.01, "marquage")


# --- Boutiques de quartier ------------------------------------------------------------

@batiment(F, "boulangerie_village", "Boulangerie de village", "commerce", 380_000,
          "Boulangerie à devanture de bois peint, logement du boulanger à l'étage.",
          "Devantures de boulangeries parisiennes et de bourgs", era="classique", emplois=4, visiteurs=200,
          logements=1, metiers=[["boulanger", 2], ["vendeur", 1]], role="boulangerie", zone="C")
def boulangerie_village(k):
    k.corps(0, 0, 0, 8, 10, 2, 3.2, "enduit_jaune", fen=fen(avant=2, arriere=2, gauche=2, volets="bleu", rdc=True,
                                                            enseigne="bois_rouge"),
            vitrine="vitre", bandeaux="pierre_claire")
    store(k, 0, -5, 7, 3.0, "rouge")
    k.toit_2pans(0, 0, 6.4, 8, 10, 2.6, "tuile", axe="x", pignon="enduit_jaune", debord=0.4)
    k.cheminee(2.5, 2.0, 6.4, 3.0, "brique")


@batiment(F, "boucherie_charcuterie", "Boucherie-charcuterie", "commerce", 360_000,
          "Boutique à carrelage blanc et rouge, rideau de fer, appartement au-dessus.",
          "Boucheries de quartier (Lyon, Paris)", era="classique", emplois=4, visiteurs=150, logements=1,
          metiers=[["boucher", 3], ["vendeur", 1]], role="boucherie", zone="C")
def boucherie(k):
    k.corps(0, 0, 0, 7, 10, 3, 3.0, "pierre_claire", fen=fen(avant=2, arriere=2, l=1.0, h=1.6, volets="blanc",
                                                             enseigne="bois_rouge"), vitrine="vitre",
            bandeaux="pierre_grise")
    store(k, 0, -5, 6, 2.9, "bois_rouge")
    k.toit_mansarde(0, 0, 9.0, 7, 10, 2.2, 0.8, "ardoise", c_haut="zinc", lucarnes=2, mur="pierre_claire")


@batiment(F, "epicerie_quartier", "Épicerie de quartier", "commerce", 300_000,
          "Petite épicerie d'angle, étals de fruits sous le store vert.",
          "Épiceries et primeurs de quartier", era="moderne", emplois=3, visiteurs=250,
          metiers=[["vendeur", 2], ["caissier", 1]], role="epicerie", zone="C")
def epicerie(k):
    k.corps(0, 0, 0, 9, 9, 2, 3.0, "enduit_rose", fen=fen(avant=3, gauche=2, droite=2, arriere=2, cadre="blanc",
                                                          enseigne="vert"), vitrine="vitre")
    store(k, 0, -4.5, 8.4, 2.9, "vert", prof=1.6)
    for i in range(3):
        k.boite(-2.6 + i * 2.6, -5.4, 0, 2.0, 0.8, 0.8, "bois_clair")
        k.boite(-2.6 + i * 2.6, -5.4, 0.8, 1.8, 0.6, 0.15, ("rouge", "orange", "vert")[i])
    k.toit_plat(0, 0, 6.0, 9, 9, "beton_sombre", acrotere=0.4, c_acrotere="enduit_rose")


@batiment(F, "pharmacie_officine", "Pharmacie", "commerce", 420_000,
          "Officine à grande vitrine et croix verte lumineuse.",
          "Pharmacies d'officine françaises", era="moderne", emplois=5, visiteurs=220,
          metiers=[["vendeur", 2], ["cadre", 1]], role="pharmacie", zone="C")
def pharmacie(k):
    k.corps(0, 0, 0, 10, 12, 2, 3.2, "enduit_blanc", fen=fen(avant=3, gauche=3, droite=3, arriere=2, cadre="metal",
                                                             enseigne="vert"), vitrine="verre_clair")
    for dx, dz, sx, sz in ((0, 0, 0.6, 1.8), (0, 0.6, 1.8, 0.6)):
        k.boite(4.4 + dx, -6.4, 3.2 + dz, sx, 0.25, sz, "vert")
    k.toit_plat(0, 0, 6.4, 10, 12, "beton_sombre", acrotere=0.4)


@batiment(F, "librairie", "Librairie", "commerce", 350_000,
          "Librairie à devanture vert bouteille et ses rayonnages en vitrine.",
          "Librairies indépendantes (Shakespeare and Company)", era="classique", emplois=3, visiteurs=120,
          logements=1, metiers=[["vendeur", 2]], role="librairie", zone="C")
def librairie(k):
    k.corps(0, 0, 0, 8, 10, 3, 3.0, "pierre_claire", fen=fen(avant=2, arriere=2, h=1.7, volets=None, cadre="blanc",
                                                             enseigne="vert"), vitrine="vitre",
            bandeaux="pierre_grise")
    k.boite(0, -5.15, 0, 7.6, 0.3, 3.0, "vert")
    k.ouverture(0, -5.3, (0, -1), -1.8, 1.6, 2.6, 2.2, "vitre", "or")
    k.ouverture(0, -5.3, (0, -1), 1.8, 1.6, 2.6, 2.2, "vitre", "or")
    k.toit_2pans(0, 0, 9.0, 8, 10, 2.8, "ardoise", axe="x", pignon="pierre_claire", debord=0.2)


@batiment(F, "fleuriste", "Fleuriste", "commerce", 260_000,
          "Boutique de fleurs pastel, seaux de bouquets sur le trottoir.",
          "Fleuristes de quartier", era="moderne", emplois=2, visiteurs=90,
          metiers=[["vendeur", 2]], role="fleuriste", zone="C")
def fleuriste(k):
    k.corps(0, 0, 0, 7, 8, 1, 3.4, "enduit_vert", fen=fen(arriere=1, gauche=1, enseigne="blanc"), vitrine="vitre")
    store(k, 0, -4, 6.4, 3.2, "blanc")
    for i in range(5):
        x = -2.6 + i * 1.3
        k.cyl(x, -4.8, 0, 0.45, 0.25, "zinc", n=6)
        k.cyl(x, -4.8, 0.45, 0.4, 0.35, ("rouge", "jaune", "enduit_rose", "blanc", "orange")[i], n=6)
    k.toit_mono(0, 0, 3.4, 7, 8, 1.0, "zinc", mur="enduit_vert")


@batiment(F, "kiosque_presse", "Kiosque Davioud", "commerce", 60_000,
          "Kiosque vert à coupole, colonne Morris et présentoirs de magazines.",
          "Kiosques Davioud des boulevards parisiens", era="classique", emplois=1, visiteurs=80,
          metiers=[["vendeur", 1]], role="kiosque", zone="C", access=["route", "chemin"], variantes=1, sans_vitres=True)
def kiosque_journaux(k):
    k.prisme([(-1.6 + 1.6 * math.cos(a), 1.6 * math.sin(a)) for a in [i * math.pi / 4 for i in range(8)]],
             0, 2.6, "vert")
    k.ouverture(-1.6, -1.6, (0, -1), 0, 1.5, 1.6, 1.0, "vitre", "or")
    k.tronc_cone(-1.6, 0, 2.6, 0.6, 2.0, 1.4, "vert", n=8)
    k.dome(-1.6, 0, 3.2, 1.4, "tole_verte", n=8, anneaux=2, h=0.8, lanterne="or")
    k.cyl(2.2, 0, 0, 3.0, 0.6, "vert", n=8)
    k.cyl(2.2, 0, 0.4, 2.2, 0.62, "jaune", n=8, dessus=False)
    k.dome(2.2, 0, 3.0, 0.65, "tole_verte", n=8, anneaux=2, h=0.4)


# --- Marchés et grandes surfaces ------------------------------------------------------

@batiment(F, "halle_marche", "Halle de marché", "commerce", 2_400_000,
          "Halle métallique à verrière haute, étals sous une grande nef.",
          "Halles Baltard, marché couvert de Saint-Quentin", era="classique", emplois=30, visiteurs=1500,
          metiers=[["vendeur", 4], ["boucher", 1], ["boulanger", 1], ["magasinier", 1]], role="marche", zone="C",
          access=["route", "chemin"])
def halle_marche(k):
    L, P = 36, 24
    k.sol(0, 0, L + 2, P + 2, "pierre_claire")
    k.boite(0, 0, 0, L, P, 0.6, "brique")
    for i in range(7):
        x = -L / 2 + i * L / 6
        for s in (-1, 1):
            k.boite(x, s * P / 2, 0.6, 0.4, 0.4, 7.0, "vert")
    for s in (-1, 1):
        k.ouverture(0, s * P / 2, (0, s), 0, 4.0, L - 2, 5.6, "verre_ciel", "vert")
        k.ouverture(s * L / 2, 0, (s, 0), 0, 4.0, P - 2, 5.6, "verre_ciel", "vert")
    k.boite(0, 0, 0.6, L - 0.2, P - 0.2, 6.9, "verre_ciel", dessus="zinc")
    k.toit_2pans(0, 0, 7.6, L, P, 3.2, "zinc", axe="x", pignon="verre_ciel", debord=1.2)
    k.boite(0, 0, 10.8, L * 0.6, 4.0, 2.2, "verre_clair", dessus="zinc")
    k.toit_2pans(0, 0, 13.0, L * 0.6, 4.0, 1.0, "zinc", axe="x", pignon="vert", debord=0.4)


@batiment(F, "souk_couvert", "Souk couvert", "commerce", 1_800_000,
          "Rue d'échoppes sous voûtes de terre, portes à arcs et tissus tendus.",
          "Souks de Marrakech et bazar de Téhéran", region="moyen_orient", era="traditionnel", emplois=40,
          visiteurs=1800, metiers=[["vendeur", 4], ["artisan", 2]], role="marche", zone="C",
          access=["route", "chemin"])
def souk(k):
    L, P = 30, 14
    k.corps(0, 0, 0, L, P, 1, 4.6, "terre", fen=fen(avant=7, arriere=7, l=2.4, h=2.6, forme="arc",
                                                     vitre="bois_sombre", cadre="ocre"), dessus="ocre")
    for i in range(5):
        k.dome(-L / 2 + 3 + i * 6, 0, 4.6, 2.6, "ocre", n=8, anneaux=2, h=1.6)
    for i in range(7):
        k.boite(-L / 2 + 2.2 + i * 4.27, -P / 2 - 0.7, 2.6, 2.6, 1.4, 0.06, ("rouge", "jaune", "bleu", "orange")[i % 4])
    k.porte(0, -P / 2, (0, -1), 0, 0, 3.2, 3.8, "bois_sombre", "pierre_claire", "arc")
    k.ouverture(-L / 2, 0, (-1, 0), 0, 2.4, 3.0, 2.8, "vitre", "pierre_claire", "arc")


@batiment(F, "supermarche_moderne", "Supermarché", "commerce", 5_500_000,
          "Supermarché de périphérie à auvent, parking et chariots.",
          "Supermarchés de zone commerciale", era="moderne", emplois=55, visiteurs=2200,
          metiers=[["caissier", 4], ["vendeur", 3], ["magasinier", 2], ["boucher", 1], ["boulanger", 1],
                   ["cadre", 1]], role="supermarche", zone="C")
def supermarche(k):
    parking(k, 0, -20, 50, 20, places=16)
    k.corps(0, 10, 0, 50, 34, 1, 7.0, "bardage", fen=fen(arriere=0), dessus="beton_sombre")
    (fx, fy), n, _ = k._facades(0, 10, 50, 34)["avant"]
    k.ouverture(fx, fy, n, -8, 2.0, 20, 3.4, "verre_clair", "metal")
    k.boite(0, -8.5, 4.2, 50, 3.0, 0.5, "rouge")
    for x in (-24, -14, -4, 6):
        k.boite(x, -9.6, 0, 0.3, 0.3, 4.2, "metal")
    enseigne(k, 10, -7.3, 4.8, 14, 2.4, "rouge")
    k.toit_plat(0, 10, 7.0, 50, 34, "beton_sombre", acrotere=0.8, c_acrotere="rouge")
    k.boite(-20, -12, 0, 4, 2.2, 1.6, "metal")


@batiment(F, "hypermarche", "Hypermarché", "commerce", 18_000_000,
          "Immense boîte de tôle, galerie marchande, station de lavage et parking géant.",
          "Hypermarchés des années 1970 (Sainte-Geneviève-des-Bois)", era="moderne", emplois=280, visiteurs=9000,
          metiers=[["caissier", 6], ["vendeur", 5], ["magasinier", 3], ["chauffeur", 1], ["boucher", 1],
                   ["boulanger", 1], ["cadre", 1]], role="supermarche", zone="C", variantes=3)
def hypermarche(k):
    parking(k, 0, -32, 96, 36, places=24)
    k.corps(0, 18, 0, 96, 60, 1, 10.0, "bardage", fen=fen(), dessus="beton_sombre")
    k.toit_plat(0, 18, 10.0, 96, 60, "beton_sombre", acrotere=1.2, c_acrotere="bardage_bleu")
    k.boite(-20, -13.5, 0, 34, 3, 6.5, "verre_bleu")
    k.boite(-20, -15, 6.5, 36, 6, 0.6, "blanc")
    (fx, fy), n, _ = k._facades(0, 18, 96, 60)["avant"]
    k.ouverture(fx, fy, n, 22, 2.4, 26, 4.2, "verre_clair", "metal")
    enseigne(k, 22, -12.4, 7.0, 24, 3.4, "bleu")
    k.boite(40, -26, 0, 10, 6, 4.2, "jaune", dessus="blanc")
    for x in (-44, -30, 30):
        k.boite(x, -48, 0, 0.5, 0.5, 9, "metal")
        k.boite(x, -48, 9, 4, 0.5, 2, "bleu")


@batiment(F, "centre_commercial", "Centre commercial", "commerce", 42_000_000,
          "Galerie couverte à verrière centrale, deux niveaux de boutiques et cinéma.",
          "Malls régionaux (Westfield, Les Quatre Temps)", era="contemporain", emplois=650, visiteurs=20000,
          metiers=[["vendeur", 6], ["caissier", 3], ["serveur", 2], ["cuisinier", 1], ["magasinier", 1],
                   ["agent_cinema", 1], ["cadre", 1]], role="centre_commercial", zone="C", variantes=3)
def centre_commercial(k):
    parking(k, 0, -36, 110, 24, places=20)
    k.corps(0, 10, 0, 110, 68, 2, 7.5, "beton_clair", fen=fen(), dessus="beton_sombre")
    k.toit_plat(0, 10, 15.0, 110, 68, "beton_sombre", acrotere=1.0)
    k.toit_voute(0, 10, 15.0, 14, 60, 5.0, "verre_ciel", n=6, axe="y", bouts="verre_clair")
    k.toit_voute(0, 10, 15.0, 90, 10, 3.5, "verre_ciel", n=5, axe="x", bouts="verre_clair")
    k.boite(0, -25, 0, 26, 2, 13.0, "verre_bleu")
    k.boite(0, -27, 13.0, 30, 6, 0.8, "blanc")
    for s in (-1, 1):
        k.ouverture(s * 34, -24, (0, -1), 0, 4.0, 20, 6.0, "verre_clair", "metal")
        enseigne(k, s * 34, -24.4, 9.0, 14, 3.0, ("orange", "bleu")[s > 0])
    k.boite(42, 34, 15.0, 22, 18, 6.0, "bardage_bleu", dessus="beton_sombre")


@batiment(F, "grand_magasin", "Grand magasin", "commerce", 28_000_000,
          "Grand magasin de six niveaux, façade ornée et coupole de verre colorée.",
          "Galeries Lafayette Haussmann, Le Printemps", era="classique", emplois=420, visiteurs=12000,
          metiers=[["vendeur", 6], ["caissier", 2], ["magasinier", 1], ["cadre", 1], ["serveur", 1]],
          role="grand_magasin", zone="C", variantes=2)
def grand_magasin(k):
    L, P = 46, 34
    k.corps(0, 0, 0, L, P, 6, 4.2, "pierre_claire", fen=fen(avant=8, gauche=5, droite=5, arriere=6, l=2.8, h=2.6,
                                                            forme="arc", cadre="or", enseigne="or"),
            vitrine="vitre", bandeaux="pierre", chaines="pierre")
    k.balcons(0, 0, 0, L, P, 6, 4.2, "avant", nb=1, prof=0.7, dalle="pierre", garde="noir", premier=2)
    for s in (-1, 1):
        k.boite(s * (L / 2 - 3), -P / 2 + 3, 25.2, 6, 6, 4.0, "pierre_claire")
        k.dome(s * (L / 2 - 3), -P / 2 + 3, 29.2, 3.0, "cuivre", n=8, anneaux=2, h=2.4, lanterne="or")
    k.toit_mansarde(0, 0, 25.2, L, P, 3.0, 1.0, "ardoise", c_haut="zinc", lucarnes=8, mur="pierre_claire")
    k.dome(0, 2, 29.2, 7.0, "verre_ciel", n=12, anneaux=3, h=5.0, lanterne="or")


@batiment(F, "magasin_bricolage", "Magasin de bricolage", "commerce", 9_000_000,
          "Hangar orange de bricolage, cour des matériaux et jardinerie sous serre.",
          "Grandes surfaces de bricolage (Leroy Merlin, Castorama)", era="contemporain", emplois=120,
          visiteurs=3500, metiers=[["vendeur", 4], ["caissier", 2], ["magasinier", 3], ["chauffeur", 1]],
          role="bricolage", zone="C")
def bricolage(k):
    parking(k, -8, -24, 64, 18, places=14)
    k.corps(-8, 12, 0, 64, 46, 1, 11.0, "bardage", fen=fen(), dessus="beton_sombre")
    k.toit_plat(-8, 12, 11.0, 64, 46, "beton_sombre", acrotere=1.2, c_acrotere="vert")
    k.boite(-8, -11.2, 0, 64, 0.2, 11.0, "vert")
    (fx, fy), n, _ = k._facades(-8, 12, 64, 46)["avant"]
    k.ouverture(fx, fy - 0.3, n, -14, 2.2, 14, 3.8, "verre_clair", "metal")
    enseigne(k, 6, -11.6, 6.0, 20, 3.6, "vert")
    k.serre(30, 2, 12, 26, 5.0)
    k.cloture([(24, 16), (36, 16), (36, 34), (24, 34)], h=2.4, c="metal")
    for i in range(3):
        k.boite(30, 20 + i * 4.5, 0, 9, 3, 1.4 + i * 0.4, ("bois_clair", "beton_clair", "brique")[i])


@batiment(F, "concession_voitures", "Concession automobile", "commerce", 4_200_000,
          "Showroom vitré, atelier et voitures neuves en exposition.",
          "Concessions automobiles de zone commerciale", era="contemporain", emplois=35, visiteurs=200,
          metiers=[["vendeur", 3], ["ouvrier", 2], ["cadre", 1]], role="concession", zone="C")
def concession_auto(k):
    k.sol(0, -10, 40, 14, "asphalte")
    k.boite(-6, 4, 0, 26, 14, 7.5, "verre_bleu", dessus="beton_sombre")
    for x in (-18, -6, 6):
        k.boite(x, -3, 0, 0.4, 0.4, 7.5, "blanc")
    k.toit_plat(-6, 4, 7.5, 27, 15, "blanc", acrotere=0.8, c_acrotere="blanc")
    k.corps(12, 6, 0, 12, 18, 1, 6.0, "bardage", fen=fen(droite=3, arriere=2, l=2.0, h=1.0, vitre="verre_ciel"))
    k.ouverture(12, -3, (0, -1), 0, 2.4, 5.0, 4.4, "tole", "rouge")
    k.toit_plat(12, 6, 6.0, 12, 18, "beton_sombre", acrotere=0.4)
    k.boite(-6, -3.2, 7.6, 14, 0.4, 2.0, "rouge")
    for i, c in enumerate(("rouge", "blanc", "bleu", "noir", "jaune")):
        x = -16 + i * 7
        k.boite(x, -12, 0, 1.9, 4.4, 1.0, c)
        k.boite(x, -12.2, 1.0, 1.7, 2.4, 0.5, "verre_nuit")
    k.cyl(18, -15, 0, 9, 0.25, "metal", n=6)
    k.boite(18, -15, 9, 3, 0.3, 3, "rouge")


@batiment(F, "station_carburant", "Station-service", "commerce", 2_200_000,
          "Auvent sur pompes, boutique et totem de prix.",
          "Stations-service de nationale", era="moderne", emplois=6, visiteurs=900,
          metiers=[["caissier", 2], ["vendeur", 1]], role="station_service", zone="C")
def station_service(k):
    k.sol(0, -4, 34, 24, "asphalte")
    for x in (-8, 0, 8):
        for y in (-8, -2):
            k.boite(x, y, 0, 1.2, 0.8, 1.9, "blanc")
            k.boite(x, y, 1.9, 1.0, 0.82, 0.3, "rouge")
    for x in (-10, 10):
        for y in (-10, 0):
            k.boite(x, y, 0, 0.5, 0.5, 5.2, "blanc")
    k.boite(0, -5, 5.2, 26, 14, 1.0, "blanc", dessus="beton_clair")
    k.boite(0, -12.05, 5.4, 26, 0.1, 0.6, "rouge")
    k.corps(0, 9, 0, 16, 8, 1, 3.8, "beton_clair", fen=fen(gauche=1, droite=1, enseigne="rouge"),
            vitrine="verre_clair")
    k.toit_plat(0, 9, 3.8, 16, 8, "beton_sombre", acrotere=0.4, c_acrotere="rouge")
    k.boite(15, -14, 0, 2.2, 0.5, 7.0, "rouge")
    for i in range(3):
        k.boite(15, -14.3, 3.6 + i * 1.0, 1.8, 0.1, 0.7, "noir")


@batiment(F, "fastfood_drive", "Restauration rapide", "commerce", 1_600_000,
          "Restaurant rapide à toit plat, drive en boucle et totem lumineux.",
          "Restaurants rapides de bord de route", era="contemporain", emplois=24, visiteurs=1200,
          metiers=[["cuisinier", 2], ["serveur", 2], ["caissier", 1]], role="restaurant", zone="C")
def fastfood(k):
    k.sol(0, -4, 30, 26, "asphalte")
    k.corps(0, 2, 0, 18, 12, 1, 4.4, "brique", fen=fen(gauche=2, droite=2, l=2.4, h=2.0, vitre="verre_clair",
                                                        enseigne="rouge"), vitrine="verre_clair")
    k.boite(0, 2, 4.4, 18.6, 12.6, 1.2, "rouge", dessus="beton_sombre")
    k.boite(9.6, 6, 0, 2.4, 3.0, 3.2, "jaune")
    k.boite(13, -10, 0, 0.6, 0.6, 9.0, "rouge")
    k.boite(13, -10, 9.0, 3.4, 0.6, 3.4, "jaune")
    for x in (-12, -9):
        k.boite(x, -10, 0, 2.0, 1.2, 0.8, "bois_clair")


@batiment(F, "bistrot_parisien", "Bistrot", "commerce", 520_000,
          "Café-bistrot d'angle à terrasse, stores rouges et chaises de rotin.",
          "Cafés parisiens (Café de Flore, Les Deux Magots)", era="classique", emplois=8, visiteurs=300,
          logements=2, metiers=[["serveur", 3], ["cuisinier", 1]], role="cafe", zone="C")
def bistrot(k):
    L, P = 12, 12
    k.corps(0, 0, 0, L, P, 4, 3.1, "pierre_claire", fen=fen(avant=4, gauche=4, arriere=3, l=1.1, h=1.8,
                                                            cadre="blanc", enseigne="bois_rouge"),
            vitrine="vitre", bandeaux="pierre")
    k.balcons(0, 0, 0, L, P, 4, 3.1, "avant", nb=1, prof=0.6, dalle="pierre", garde="noir", premier=2)
    store(k, 0, -6, 11.4, 3.0, "rouge", prof=2.4)
    for i in range(4):
        x = -4.2 + i * 2.8
        k.cyl(x, -7.8, 0, 0.75, 0.35, "bois_sombre", n=6)
        for s in (-1, 1):
            k.boite(x + s * 0.7, -7.8, 0, 0.45, 0.45, 0.9, "bois_clair")
    k.toit_mansarde(0, 0, 12.4, L, P, 2.4, 0.8, "ardoise", c_haut="zinc", lucarnes=3, mur="pierre_claire")


@batiment(F, "pizzeria", "Pizzeria", "commerce", 480_000,
          "Trattoria à façade terracotta, pergola de vigne et four à bois.",
          "Trattorias de Naples et du Trastevere", region="mediterranee", era="traditionnel", emplois=7,
          visiteurs=220, logements=1, metiers=[["cuisinier", 2], ["serveur", 2]], role="restaurant", zone="C")
def pizzeria(k):
    k.corps(0, 2, 0, 10, 10, 2, 3.2, "terre", fen=fen(avant=3, gauche=2, droite=2, arriere=2, volets="vert",
                                                       cadre="pierre_claire"),
            porte={"l": 1.4, "h": 2.4, "couleur": "bois_sombre", "forme": "arc"})
    k.toit_2pans(0, 2, 6.4, 10, 10, 1.6, "tuile", axe="x", pignon="terre", debord=0.4)
    for x in (-4.5, 0, 4.5):
        k.boite(x, -6, 0, 0.3, 0.3, 2.8, "bois_sombre")
    k.boite(0, -4.5, 2.8, 9.6, 3.4, 0.2, "vert")
    k.cheminee(-3.8, 5.0, 6.4, 2.2, "brique", l=0.9)
    k.dome(4.0, 8.5, 0, 1.6, "brique", n=8, anneaux=2, h=1.6)


@batiment(F, "izakaya", "Izakaya", "commerce", 560_000,
          "Bistrot japonais de bois sombre, lanternes rouges et noren à l'entrée.",
          "Ruelles d'izakaya de Shinjuku (Omoide Yokocho)", region="asie_est", era="traditionnel", emplois=6,
          visiteurs=180, logements=1, metiers=[["cuisinier", 2], ["serveur", 2]], role="restaurant", zone="C")
def izakaya(k):
    k.corps(0, 0, 0, 7, 11, 2, 2.9, "bois_sombre", fen=fen(avant=2, arriere=2, l=1.4, h=0.9, cadre="bois_clair",
                                                           rdc=False),
            porte={"l": 2.0, "h": 2.1, "couleur": "bois_clair"})
    k.boite(0, -5.6, 1.6, 2.4, 0.06, 0.8, "bleu")
    for x in (-2.5, 2.5):
        k.cyl(x, -6.0, 1.8, 0.7, 0.3, "rouge", n=8)
    k.boite(0, -5.9, 2.7, 7.2, 1.0, 0.15, "tuile")
    k.toit_2pans(0, 0, 5.8, 11, 7, 1.4, "ardoise", axe="y", pignon="bois_sombre", debord=0.5)
    k.boite(-2.8, -5.7, 3.4, 0.5, 0.3, 2.0, "blanc")


@batiment(F, "diner_americain", "Diner américain", "commerce", 620_000,
          "Wagon-restaurant en inox aux bandeaux colorés et grande enseigne.",
          "Diners de la côte Est (Mickey's Diner, Saint Paul)", region="ameriques", era="moderne",
          emplois=10, visiteurs=350, metiers=[["cuisinier", 2], ["serveur", 3]], role="restaurant", zone="C")
def diner(k):
    k.sol(0, -2, 26, 18, "asphalte")
    L, P = 18, 7
    k.corps(0, 3, 0, L, P, 1, 3.6, "metal", fen=fen(avant=7, gauche=2, droite=2, l=1.6, h=1.2,
                                                     vitre="verre_clair", cadre="blanc"),
            porte={"l": 1.2, "h": 2.2, "couleur": "verre_clair", "u": 6.0})
    k.boite(0, 3, 0.9, L + 0.05, P + 0.05, 0.3, "rouge")
    k.boite(0, 3, 3.0, L + 0.05, P + 0.05, 0.25, "rouge")
    k.toit_voute(0, 3, 3.6, P, L, 1.0, "metal", n=4, axe="x", bouts="metal")
    k.boite(8, -1, 4.6, 7, 0.4, 2.2, "jaune")
    k.boite(8, -1.25, 5.1, 6, 0.1, 1.2, "rouge")


@batiment(F, "boutiques_rue", "Rangée de boutiques", "commerce", 1_900_000,
          "Quatre boutiques sous arcades avec appartements, enseignes variées.",
          "Rues commerçantes de centre-bourg", era="classique", emplois=14, visiteurs=600, logements=6,
          metiers=[["vendeur", 4], ["caissier", 1], ["serveur", 1]], role="boutiques", zone="C")
def boutiques_rue(k):
    L, P = 28, 12
    k.corps(0, 0, 0, L, P, 3, 3.2, "enduit_chaud", fen=fen(avant=8, arriere=6, gauche=2, droite=2, volets="bleu",
                                                           cadre="blanc", rdc=False),
            bandeaux="pierre_claire")
    for i, c in enumerate(("rouge", "vert", "bleu", "jaune")):
        u = -L / 2 + 3.5 + i * 7
        k.ouverture(0, -P / 2, (0, -1), u, 1.5, 5.0, 2.4, "vitre", "metal")
        store(k, u, -P / 2, 5.6, 3.0, c)
    k.toit_2pans(0, 0, 9.6, L, P, 2.6, "tuile", axe="x", pignon="enduit_chaud", debord=0.4)
    for x in (-7, 7):
        k.cheminee(x, 1.5, 9.6, 2.6, "brique")


@batiment(F, "shophouse", "Shophouse", "commerce", 820_000,
          "Compartiment chinois étroit : boutique au rez, galerie couverte, volets à lamelles.",
          "Shophouses de Penang, Singapour et Hội An", region="asie_sud", era="classique", emplois=4,
          visiteurs=180, logements=2, metiers=[["vendeur", 2], ["cuisinier", 1]], role="boutiques", zone="C")
def shophouse(k):
    L, P = 6, 16
    k.corps(0, 0, 0, L, P, 3, 3.4, "enduit_bleu", fen=fen(avant=2, arriere=1, l=1.2, h=1.9, volets="vert",
                                                          cadre="blanc", rdc=False), bandeaux="blanc")
    k.boite(0, -P / 2 - 1.2, 0, L, 2.4, 0.2, "pierre_claire")
    for s in (-1, 1):
        k.boite(s * (L / 2 - 0.25), -P / 2 - 2.2, 0, 0.5, 0.5, 3.4, "blanc")
    k.boite(0, -P / 2 - 1.2, 3.4, L, 2.4, 0.3, "blanc")
    k.ouverture(0, -P / 2, (0, -1), 0, 1.4, 4.0, 2.4, "vitre", "bois_rouge")
    k.boite(0, -P / 2 - 0.2, 10.2, L, 0.4, 1.2, "blanc")
    k.toit_2pans(0, 0, 10.2, P, L, 1.6, "tuile", axe="y", pignon="enduit_bleu", debord=0.3)


# --- Hôtels -----------------------------------------------------------------------------

@batiment(F, "auberge_montagne", "Auberge de montagne", "commerce", 2_800_000,
          "Hôtel-chalet à balcons fleuris et restaurant panoramique.",
          "Hôtels-chalets de Zermatt et de Megève", era="traditionnel", emplois=22, visiteurs=120, logements=0,
          metiers=[["serveur", 3], ["cuisinier", 2], ["employe", 1]], role="hotel", zone="C")
def auberge_montagne(k):
    L, P = 22, 14
    k.corps(0, 0, 0, L, P, 1, 3.4, "pierre_grise", fen=fen(avant=5, gauche=3, droite=3, arriere=4, l=1.8, h=1.8),
            porte={"l": 1.6, "h": 2.4, "couleur": "bois_sombre"})
    k.corps(0, 0, 3.4, L, P, 3, 2.8, "bois", fen=fen(avant=7, arriere=6, gauche=4, droite=4, l=1.0, h=1.3,
                                                      volets="vert", cadre="blanc"))
    k.balcons(0, 0, 3.4, L, P, 4, 2.8, "avant", nb=1, prof=1.4, dalle="bois_sombre", garde="bois_clair", premier=1)
    k.toit_2pans(0, 0, 11.8, P, L, 3.4, "bois_gris", axe="y", pignon="bois", debord=1.4, rangs=6)
    enseigne(k, 0, -P / 2 - 0.2, 3.5, 6, 0.8, "bois_sombre")


@batiment(F, "palace_belle_epoque", "Palace Belle Époque", "commerce", 24_000_000,
          "Grand hôtel de bord de mer, coupoles d'angle, marquise et terrasses.",
          "Hôtel Negresco (Nice), Carlton (Cannes)", region="mediterranee", era="classique", emplois=240,
          visiteurs=500, metiers=[["serveur", 4], ["cuisinier", 2], ["employe", 2], ["cadre", 1]], role="hotel",
          zone="C", variantes=2)
def palace(k):
    L, P = 56, 22
    k.corps(0, 0, 0, L, P, 7, 3.6, "enduit_blanc", fen=fen(avant=14, arriere=12, gauche=5, droite=5, l=1.4, h=2.0,
                                                           cadre="pierre_claire", volets=None),
            bandeaux="pierre_claire", porte={"l": 4.0, "h": 3.2, "couleur": "verre_clair"})
    k.balcons(0, 0, 0, L, P, 7, 3.6, "avant", nb=7, prof=1.0, dalle="pierre", garde="noir", premier=2)
    for s in (-1, 1):
        x = s * (L / 2 - 4)
        k.boite(x, -P / 2 + 4, 25.2, 8, 8, 3.0, "enduit_blanc")
        k.dome(x, -P / 2 + 4, 28.2, 4.0, "enduit_rose", n=10, anneaux=3, h=4.6, lanterne="or")
    k.toit_mansarde(0, 0, 25.2, L, P, 3.0, 1.0, "ardoise", c_haut="zinc", lucarnes=10, mur="enduit_blanc")
    k.boite(0, -P / 2 - 2, 3.6, 12, 4, 0.3, "verre_ciel")
    k.boite(0, -P / 2 - 2, 3.4, 12.4, 4.4, 0.2, "noir")
    k.sol(0, -P / 2 - 6, L, 8, "pierre_claire")


@batiment(F, "hotel_chaine", "Hôtel de chaîne", "commerce", 6_500_000,
          "Hôtel économique de cinq niveaux, façade rythmée de couleurs et parking.",
          "Hôtels de chaîne de périphérie et de gare", era="contemporain", emplois=30, visiteurs=200,
          metiers=[["employe", 3], ["serveur", 1], ["cuisinier", 1]], role="hotel", zone="C")
def hotel_chaine(k):
    parking(k, 0, -16, 40, 10, places=12)
    L, P = 40, 14
    k.corps(0, 2, 0, L, P, 5, 3.0, "enduit_blanc", fen=fen(avant=10, arriere=10, gauche=2, droite=2, l=1.3, h=1.4,
                                                           cadre="metal"),
            porte={"l": 3.0, "h": 2.6, "couleur": "verre_clair"})
    for i in range(5):
        k.boite(-16 + i * 8, -5.15, 3.0, 2.0, 0.3, 12.0, ("bleu", "orange", "vert", "rouge", "jaune")[i])
    k.toit_plat(0, 2, 15.0, L, P, "beton_sombre", acrotere=0.6)
    enseigne(k, 12, -4.8, 15.6, 12, 2.0, "bleu")


@batiment(F, "tour_hotel", "Tour hôtelière", "commerce", 95_000_000,
          "Gratte-ciel d'hôtel en voile de verre bleu, socle de congrès et spa.",
          "Tours hôtelières de Dubaï et de Shanghai", region="moyen_orient", era="contemporain", emplois=900,
          visiteurs=1500, metiers=[["serveur", 4], ["cuisinier", 2], ["employe", 2], ["cadre", 1]], role="hotel",
          zone="C", variantes=2)
def tour_hotel(k):
    k.corps(0, 0, 0, 50, 34, 2, 5.0, "beton_clair", fen=fen(avant=0, gauche=0, bande=True), dessus="pelouse")
    (fx, fy), n, _ = k._facades(0, 0, 50, 34)["avant"]
    k.ouverture(fx, fy, n, 0, 3.5, 44, 6.0, "verre_bleu", "metal")
    # Fût en voile : niveaux qui se resserrent vers le haut.
    z = 10.0
    for i in range(8):
        L = 26 - i * 1.6
        P = 18 - i * 1.2
        k.boite(0, 4, z, L, P, 14.0, "verre_bleu")
        k.boite(0, 4, z + 13.6, L + 0.4, P + 0.4, 0.4, "blanc")
        z += 14.0
    k.tronc_cone(0, 4, z, 18, 4, 0, "metal", n=6)
    k.cyl(0, 4, z + 18, 10, 0.25, "metal", n=6)


@batiment(F, "motel", "Motel", "commerce", 1_400_000,
          "Motel en L le long de la route : portes sur coursive, piscine et enseigne néon.",
          "Motels de la Route 66", region="ameriques", era="moderne", emplois=8, visiteurs=60,
          metiers=[["employe", 2], ["serveur", 1]], role="hotel", zone="C")
def motel(k):
    k.sol(0, -4, 44, 30, "asphalte")
    k.corps(-4, 6, 0, 34, 9, 2, 3.0, "enduit_rose", fen=fen(avant=8, l=1.2, h=1.1, cadre="blanc"))
    for i in range(8):
        k.porte(-4, 1.5, (0, -1), -15 + i * 4.25 + 1.2, 0, 0.9, 2.1, ("bleu", "vert")[i % 2])
        k.porte(-4, 1.5, (0, -1), -15 + i * 4.25 + 1.2, 3.0, 0.9, 2.1, ("vert", "bleu")[i % 2], marche=False)
    k.boite(-4, 0.4, 2.9, 34, 2.2, 0.2, "beton_clair")
    k.boite(-4, -0.6, 3.1, 34, 0.1, 1.0, "blanc")
    k.toit_plat(-4, 6, 6.0, 34, 9, "beton_sombre", acrotere=0.5, c_acrotere="blanc")
    k.corps(17, -2, 0, 8, 8, 1, 3.4, "enduit_rose", fen=fen(avant=2, droite=2, l=1.6, h=1.4, vitre="verre_clair"),
            porte={"l": 1.2, "h": 2.2, "couleur": "verre_clair", "cote": "gauche"})
    k.toit_mono(17, -2, 3.4, 8, 8, 1.2, "tole", mur="enduit_rose")
    k.boite(-4, -10, 0, 12, 6, 0.2, "beton_clair")
    k.boite(-4, -10, 0.2, 10, 4, 0.05, "eau")
    k.boite(19, -16, 0, 0.6, 0.6, 7.0, "metal")
    k.boite(19, -16, 7.0, 6, 0.6, 2.4, "jaune")
    k.boite(19, -16.35, 7.4, 5, 0.1, 1.4, "rouge")


@batiment(F, "ryokan", "Ryokan", "commerce", 5_200_000,
          "Auberge japonaise de bois, toits de tuiles grises, bains et jardin.",
          "Ryokans de Kyoto et onsen de Hakone", region="asie_est", era="traditionnel", emplois=24,
          visiteurs=80, metiers=[["serveur", 3], ["cuisinier", 2], ["employe", 1]], role="hotel", zone="C",
          access=["route", "chemin"])
def ryokan(k):
    k.sol(0, 0, 34, 30, "pelouse")
    k.boite(0, 6, 0, 26, 14, 0.6, "pierre_grise")
    k.corps(0, 6, 0.6, 24, 12, 2, 3.0, "bois_clair", fen=fen(avant=6, arriere=6, gauche=3, droite=3, l=2.0, h=1.4,
                                                             vitre="verre_clair", cadre="bois_sombre"),
            porte={"l": 2.4, "h": 2.2, "couleur": "bois_sombre"})
    k.boite(0, 6, 3.6, 26, 14, 0.2, "ardoise")
    k.toit_4pans(0, 6, 6.6, 24, 12, 2.6, "ardoise", debord=1.2)
    k.boite(-8, -8, 0, 10, 7, 0.4, "pierre_grise")
    k.boite(-8, -8, 0.4, 8.6, 5.6, 0.04, "eau")
    for x, y in ((6, -6), (10, -9), (13, -4)):
        k.boite(x, y, 0, 1.2, 1.2, 0.8, "pierre_grise")
    k.boite(-8, -12.4, 0, 12, 0.8, 1.8, "bois_sombre")


# --- Bureaux --------------------------------------------------------------------------------

@batiment(F, "immeuble_bureaux", "Immeuble de bureaux", "commerce", 14_000_000,
          "Bureaux de six étages en bandes vitrées, rez commercial.",
          "Immeubles tertiaires de quartier d'affaires", era="moderne", emplois=320, visiteurs=0,
          metiers=[["employe", 5], ["cadre", 3], ["ingenieur", 1]], role="bureaux", zone="C")
def immeuble_bureaux(k):
    L, P = 32, 18
    k.corps(0, 0, 0, L, P, 6, 3.5, "beton_clair", fen=fen(avant=1, arriere=1, gauche=1, droite=1, h=1.8, bande=True,
                                                          vitre="verre_bleu"),
            porte={"l": 3.0, "h": 2.8, "couleur": "verre_clair"})
    k.toit_plat(0, 0, 21.0, L, P, "beton_sombre", acrotere=0.6)
    k.boite(6, 2, 21.0, 8, 6, 2.6, "bardage")


@batiment(F, "tour_bureaux", "Tour de bureaux", "commerce", 120_000_000,
          "Tour de verre de quarante étages, couronne lumineuse et socle en retrait.",
          "Tours de La Défense (Tour First, Tour Saint-Gobain)", era="contemporain", emplois=3500, visiteurs=0,
          metiers=[["employe", 5], ["cadre", 4], ["ingenieur", 2]], role="bureaux", zone="C", variantes=2)
def tour_bureaux(k):
    k.sol(0, 0, 50, 50, "pierre_claire")
    k.boite(0, 0, 0, 34, 34, 8.0, "verre_bleu")
    for i in range(4):
        x = -15 + i * 10
        k.boite(x, -17.2, 0, 0.6, 0.6, 8.0, "metal")
    z = 8.0
    for L, h in ((30, 64), (27, 52), (23, 40)):
        k.boite(0, 0, z, L, L, h, "verre_bleu")
        for j in range(1, int(h / 8)):
            k.boite(0, 0, z + j * 8 - 0.2, L + 0.1, L + 0.1, 0.4, "metal")
        z += h
        k.boite(0, 0, z, L + 0.6, L + 0.6, 0.6, "blanc")
    k.boite(0, 0, z, 18, 18, 6.0, "verre_clair")
    k.cyl(0, 0, z + 6, 14, 0.3, "metal", n=6)


@batiment(F, "banque_classique", "Banque", "commerce", 9_000_000,
          "Siège de banque en pierre à portique de colonnes et hall vitré.",
          "Sièges bancaires de la fin du XIXe (Crédit Lyonnais, Banque de France)", era="classique", emplois=140,
          visiteurs=300, metiers=[["employe", 4], ["cadre", 2]], role="banque", zone="C", variantes=2)
def banque(k):
    L, P = 30, 22
    k.corps(0, 2, 0, L, P, 4, 4.2, "pierre_claire", fen=fen(avant=7, arriere=6, gauche=5, droite=5, l=1.4, h=2.2,
                                                            cadre="pierre", forme="arc"),
            socle="pierre_grise", bandeaux="pierre", chaines="pierre")
    k.colonnes(0, -10.5, 0, 16, 6, 9.0, 0.6, "pierre_claire", fronton="pierre_claire", prof=3.0)
    k.porte(0, -9, (0, -1), 0, 0, 3.0, 4.6, "bois_sombre", "or")
    k.toit_plat(0, 2, 16.8, L, P, "zinc", acrotere=1.0, c_acrotere="pierre_claire")


@batiment(F, "siege_social", "Siège social", "commerce", 60_000_000,
          "Campus de bureaux à anneau vitré autour d'un jardin intérieur.",
          "Sièges en anneau (Apple Park, Cupertino)", region="ameriques", era="contemporain", emplois=1800,
          visiteurs=0, metiers=[["ingenieur", 4], ["cadre", 3], ["employe", 3], ["cuisinier", 1]], role="bureaux",
          zone="C", variantes=1)
def siege_social(k):
    k.sol(0, 0, 90, 90, "pelouse")
    n = 16
    R0, R1 = 34, 42
    for i in range(n):
        a0, a1 = 2 * math.pi * i / n, 2 * math.pi * (i + 1) / n
        pts = [(R0 * math.cos(a0), R0 * math.sin(a0)), (R1 * math.cos(a0), R1 * math.sin(a0)),
               (R1 * math.cos(a1), R1 * math.sin(a1)), (R0 * math.cos(a1), R0 * math.sin(a1))]
        k.prisme(pts, 0, 12.0, "verre_ciel", dessus="blanc")
        k.prisme([(x * 1.0, y * 1.0) for x, y in pts], 12.0, 12.6, "blanc")
    for x, y in ((-12, 8), (10, -6), (0, 14), (-6, -14), (14, 10)):
        k.cyl(x, y, 0, 2.6, 0.35, "bois_sombre", n=6)
        k.dome(x, y, 2.6, 2.6, "vert", n=6, anneaux=2, h=3.2)


# --- Loisirs et sorties -------------------------------------------------------------------

@batiment(F, "bowling", "Bowling", "loisirs", 4_800_000,
          "Salle de bowling à grande quille sur le toit, bar et billards.",
          "Bowlings américains des années 1960", region="ameriques", era="moderne", emplois=18,
          visiteurs=600, metiers=[["serveur", 3], ["vendeur", 1], ["cuisinier", 1]], role="bowling", zone="C")
def bowling(k):
    parking(k, 0, -18, 44, 12, places=12)
    L, P = 40, 26
    k.corps(0, 4, 0, L, P, 1, 7.0, "enduit_bleu", fen=fen(gauche=3, droite=3, l=2.0, h=1.2, vitre="verre_clair",
                                                          enseigne="rouge"), vitrine="verre_clair")
    k.toit_plat(0, 4, 7.0, L, P, "beton_sombre", acrotere=0.8, c_acrotere="rouge")
    k.cyl(12, -7, 7.0, 2.4, 1.0, "blanc", n=8)
    k.dome(12, -7, 9.4, 1.0, "blanc", n=8, anneaux=2, h=1.6)
    k.cyl(12, -7, 9.8, 0.4, 1.02, "rouge", n=8, dessus=False)
    k.boite(-6, -9.3, 7.0, 18, 0.4, 2.4, "rouge")
    k.boite(-6, -9.55, 7.5, 15, 0.1, 1.4, "jaune")


@batiment(F, "casino", "Casino", "loisirs", 30_000_000,
          "Casino de station balnéaire, façade à colonnes, verrière et jardins.",
          "Casino de Monte-Carlo", region="mediterranee", era="classique", emplois=420, visiteurs=3000,
          metiers=[["serveur", 4], ["employe", 3], ["cuisinier", 1], ["cadre", 1], ["policier", 1]],
          role="casino", zone="C", variantes=2)
def casino(k):
    k.sol(0, -8, 64, 24, "pelouse")
    L, P = 50, 30
    k.corps(0, 6, 0, L, P, 3, 5.0, "pierre_claire", fen=fen(avant=11, arriere=9, gauche=6, droite=6, l=1.8, h=3.0,
                                                            forme="arc", cadre="or"),
            bandeaux="pierre", chaines="pierre")
    k.colonnes(0, -10.5, 0, 18, 6, 10.0, 0.6, "pierre_claire", prof=2.6)
    k.porte(0, -9, (0, -1), 0, 0, 3.6, 5.0, "verre_clair", "or", "arc")
    for s in (-1, 1):
        k.boite(s * 21, -5, 15.0, 8, 8, 6.0, "pierre_claire")
        k.toit_4pans(s * 21, -5, 21.0, 8, 8, 5.0, "cuivre", debord=0.2)
    k.toit_mansarde(0, 6, 15.0, L, P, 2.6, 1.2, "cuivre", c_haut="zinc", lucarnes=8, mur="pierre_claire")
    k.dome(0, 6, 18.8, 8.0, "verre_ciel", n=12, anneaux=3, h=4.0, lanterne="or")
    k.cyl(0, -16, 0, 0.6, 4.0, "pierre_claire", n=12)
    k.cyl(0, -16, 0.6, 0.04, 3.6, "eau", n=12)


@batiment(F, "discotheque", "Discothèque", "loisirs", 2_600_000,
          "Boîte de nuit cubique noire, enseigne néon et entrée surveillée.",
          "Clubs de zone industrielle reconvertis", era="contemporain", emplois=20, visiteurs=900,
          metiers=[["serveur", 4], ["employe", 1], ["policier", 1]], role="discotheque", zone="C")
def discotheque(k):
    k.sol(0, -12, 30, 10, "asphalte")
    L, P = 26, 22
    k.corps(0, 4, 0, L, P, 1, 8.0, "noir", fen=fen(), dessus="beton_sombre")
    k.toit_plat(0, 4, 8.0, L, P, "beton_sombre", acrotere=0.5, c_acrotere="noir")
    k.porte(0, -7, (0, -1), 0, 0, 2.4, 2.8, "verre_nuit", "bleu", auvent="bleu")
    for i, c in enumerate(("enduit_rose", "bleu", "jaune")):
        k.boite(-6 + i * 6, -7.15, 4.0 + (i % 2) * 1.6, 4.4, 0.1, 0.5, c)
    k.ouverture(0, -7, (0, -1), 8, 5.6, 6.0, 1.4, "verre_bleu", "enduit_rose")
    for x in (-4, -2, 2, 4):
        k.cyl(x, -10, 0, 0.9, 0.1, "metal", n=4)


@batiment(F, "salle_concert", "Salle de concert", "loisirs", 34_000_000,
          "Grande salle de concerts à toile tendue rouge et parvis.",
          "Zéniths de France (Paris, Strasbourg)", era="contemporain", emplois=90, visiteurs=6000,
          metiers=[["agent_cinema", 3], ["serveur", 2], ["comedien", 2], ["employe", 1]], role="theatre", zone="C",
          variantes=2)
def salle_concert(k):
    k.sol(0, -26, 70, 14, "pierre_claire")
    R = 32
    n = 14
    pts = [(R * math.cos(2 * math.pi * i / n), 4 + R * 0.75 * math.sin(2 * math.pi * i / n)) for i in range(n)]
    k.prisme(pts, 0, 6.0, "bardage", dessus="bardage")
    k.tronc_cone(0, 4, 6.0, 12.0, R, R * 0.3, "rouge", n=n)
    k.tronc_cone(0, 4, 18.0, 3.0, R * 0.3, 0, "rouge", n=n)
    k.boite(0, -19, 0, 24, 2.0, 5.6, "verre_clair", dessus="metal")
    for x in (-10, 0, 10):
        k.boite(x, -21, 0, 0.5, 0.5, 9.0, "metal")
    enseigne(k, 0, -20.4, 6.2, 18, 2.6, "noir")


@batiment(F, "parc_aquatique", "Parc aquatique", "loisirs", 22_000_000,
          "Bassins à vagues sous dôme vitré, toboggans géants et plages.",
          "Aqualands et centres aquatiques (Aquaboulevard)", era="contemporain", emplois=120, visiteurs=4000,
          metiers=[["coach", 4], ["vendeur", 1], ["serveur", 1], ["aide_soignant", 1]], role="piscine", zone="C")
def parc_aquatique(k):
    k.sol(0, 0, 80, 64, "sable")
    k.boite(-16, 6, 0, 40, 34, 0.5, "beton_clair")
    k.toit_voute(-16, 6, 0.5, 40, 34, 16, "verre_ciel", n=7, axe="y", bouts="verre_clair")
    for (x, y, w, d) in ((14, -12, 24, 14), (24, 14, 16, 18)):
        k.boite(x, y, 0, w, d, 0.4, "beton_clair")
        k.boite(x, y, 0.4, w - 1.2, d - 1.2, 0.04, "eau")
    k.boite(30, -20, 0, 4, 4, 14, "jaune")
    for i, c in enumerate(("rouge", "bleu", "vert")):
        z0 = 14 - i * 1.2
        pts = [(30, -18), (24 - i * 3, -10), (18 - i * 4, -4)]
        for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
            z1 = z0 - 6
            k.f([(x0 - 0.7, y0, z0), (x0 + 0.7, y0, z0), (x1 + 0.7, y1, z1), (x1 - 0.7, y1, z1)], c, vers=(0, 0, 1))
            k.f([(x0 - 0.7, y0, z0 - 0.3), (x1 - 0.7, y1, z1 - 0.3), (x1 + 0.7, y1, z1 - 0.3), (x0 + 0.7, y0, z0 - 0.3)],
                c, vers=(0, 0, -1))
            k.boite(x1, y1, 0, 0.4, 0.4, max(z1, 0.5), "metal")
            z0 = z1
    for x in (-34, -28, -22):
        k.cyl(x, -24, 0, 2.6, 0.08, "metal", n=4)
        k.tronc_cone(x, -24, 2.4, 0.6, 1.6, 0, ("rouge", "jaune", "bleu")[(x // 6) % 3], n=6)


@batiment(F, "grande_roue", "Grande roue", "loisirs", 3_800_000,
          "Roue de fête foraine de 40 m, nacelles colorées et guichet.",
          "Grande roue de la Concorde, Prater de Vienne", era="classique", emplois=8, visiteurs=1200,
          metiers=[["agent_cinema", 2], ["vendeur", 1]], role="manege", zone="C", access=["route", "chemin"],
          sans_vitres=True, variantes=2)
def grande_roue(k):
    k.sol(0, 0, 30, 14, "pierre_claire")
    R, zc = 18.0, 21.0
    for s in (-1, 1):
        for dx in (-7, 7):
            k.f([(dx, s * 1.2 - 0.3, 0), (dx + 0.6, s * 1.2 - 0.3, 0), (0.3, s * 1.2, zc), (-0.3, s * 1.2, zc)],
                "blanc", vers=(0, s, 0))
            k.f([(dx, s * 1.2 + 0.3, 0), (dx + 0.6, s * 1.2 + 0.3, 0), (0.3, s * 1.2, zc), (-0.3, s * 1.2, zc)],
                "blanc", vers=(0, -s, 0))
    n = 16
    for i in range(n):
        a0, a1 = 2 * math.pi * i / n, 2 * math.pi * (i + 1) / n
        for y in (-1.0, 1.0):
            p0 = (R * math.cos(a0), y, zc + R * math.sin(a0))
            p1 = (R * math.cos(a1), y, zc + R * math.sin(a1))
            k.f([(p0[0], y, p0[2] - 0.2), (p1[0], y, p1[2] - 0.2), (p1[0], y, p1[2] + 0.2), (p0[0], y, p0[2] + 0.2)],
                "blanc", vers=(0, y, 0))
        x, z = R * math.cos(a0), zc + R * math.sin(a0)
        k.boite(x, 0, z - 2.4, 1.6, 1.6, 1.8, ("rouge", "jaune", "bleu", "vert")[i % 4])
    k.pales(0, -1.1, zc, R, 8, "metal", largeur=0.25)
    k.cyl(0, 0, zc - 0.8, 1.6, 1.0, "metal", n=8)
    k.boite(10, -4, 0, 4, 3, 2.6, "rouge", dessus="blanc")


@batiment(F, "carrousel", "Carrousel", "loisirs", 450_000,
          "Manège de chevaux de bois sous chapiteau rayé.",
          "Carrousels forains (jardin des Tuileries)", era="classique", emplois=2, visiteurs=300,
          metiers=[["vendeur", 1]], role="manege", zone="C", access=["route", "chemin"], sans_vitres=True,
          variantes=2)
def carrousel(k):
    k.cyl(0, 0, 0, 0.6, 6.0, "bois_rouge", n=12)
    k.cyl(0, 0, 0.6, 4.0, 0.6, "or", n=8)
    for i in range(10):
        a = 2 * math.pi * i / 10
        x, y = 4.6 * math.cos(a), 4.6 * math.sin(a)
        k.cyl(x, y, 0.6, 3.4, 0.08, "or", n=4, dessus=False)
        k.boite(x, y, 1.4 + (i % 2) * 0.4, 0.4, 1.2, 0.8, ("blanc", "bois_clair")[i % 2])
    k.cyl(0, 0, 4.0, 0.6, 6.2, "rouge", n=12, dessus=False)
    k.tronc_cone(0, 0, 4.6, 2.4, 6.2, 0.3, "blanc", n=12)
    k.tronc_cone(0, 0, 4.62, 2.38, 6.18, 0.35, "rouge", n=6, dessus=False)
    k.cyl(0, 0, 7.0, 1.0, 0.1, "or", n=4)


@batiment(F, "kiosque_fanfare", "Kiosque à musique en fonte", "loisirs", 180_000,
          "Kiosque octogonal à colonnettes de fonte et toit en pavillon.",
          "Kiosques des jardins publics (Vichy, Nancy)", era="classique", emplois=0, visiteurs=150,
          role="kiosque_musique", zone="C", access=["route", "chemin"], sans_vitres=True, variantes=2)
def kiosque_musique(k):
    n = 8
    r = 5.0
    pts = [(r * math.cos(2 * math.pi * i / n), r * math.sin(2 * math.pi * i / n)) for i in range(n)]
    k.prisme(pts, 0, 1.2, "pierre_claire", dessus="bois_clair")
    for x, y in pts:
        k.cyl(x * 0.92, y * 0.92, 1.2, 3.6, 0.12, "vert", n=4)
    k.prisme([(x * 0.94, y * 0.94) for x, y in pts], 1.2, 2.0, "vert", dessus="bois_clair")
    k.tronc_cone(0, 0, 4.8, 0.4, r * 1.08, r * 1.04, "vert", n=8)
    k.tronc_cone(0, 0, 5.2, 2.6, r * 1.04, 0, "zinc", n=8)
    k.cyl(0, 0, 7.8, 0.8, 0.1, "or", n=4)


@batiment(F, "skatepark_bowl", "Skatepark à bowl", "sport", 600_000,
          "Bowl de béton, rampes, rails et gradins graffés.",
          "Skateparks municipaux (Bercy, Marseille Prado)", era="contemporain", emplois=0, visiteurs=200,
          role="skatepark", zone="C", access=["route", "chemin"], sans_vitres=True, variantes=2)
def skatepark(k):
    k.sol(0, 0, 36, 26, "beton_clair")
    for s in (-1, 1):
        k.toit_profil(s * 12, 0, 0, 16, [(-3.0 * s, 0), (-1.2 * s, 0.4), (0, 1.4), (0.6 * s, 2.6), (0.6 * s, 0)],
                      "beton_sombre", axe="y", bouts="enduit_bleu")
    k.boite(0, 6, 0, 8, 6, 0.04, "beton_sombre")
    k.toit_profil(0, -6, 0, 8, [(-2, 0), (0, 0.8), (2, 0)], "beton_sombre", axe="x", bouts="enduit_rose")
    k.boite(0, 9, 0.4, 6, 0.1, 0.1, "metal")
    for x in (-3, 3):
        k.boite(x, 9, 0, 0.1, 0.1, 0.4, "metal")
    k.boite(0, 12.2, 0, 20, 1.6, 0.4, "beton_clair")
    k.boite(0, 12.6, 0.4, 20, 0.8, 0.4, "beton_clair")
    k.boite(-16, 0, 0, 0.3, 20, 2.4, "jaune", dessus="beton_clair")


@batiment(F, "stade_foot", "Stade de football", "sport", 85_000_000,
          "Stade de 30 000 places, tribunes couvertes et pylônes d'éclairage.",
          "Stades à l'anglaise (Anfield, Geoffroy-Guichard)", era="moderne", emplois=160, visiteurs=30000,
          metiers=[["coach", 3], ["agent_public", 2], ["vendeur", 2], ["serveur", 1], ["policier", 1]],
          role="foot", zone="C", variantes=2)
def stade_foot(k):
    LT, PT = 105, 68
    k.sol(0, 0, LT + 8, PT + 8, "pelouse")
    for i in range(1, 10, 2):
        k.boite(-LT / 2 + i * LT / 10, 0, 0.04, LT / 10, PT, 0.01, "vert")
    k.boite(0, 0, 0.06, 0.15, PT, 0.01, "marquage")
    for s in (-1, 1):
        k.boite(s * LT / 2, 0, 0.06, 0.15, PT, 0.01, "marquage")
        k.boite(0, s * PT / 2, 0.06, LT, 0.15, 0.01, "marquage")
        k.boite(s * (LT / 2 + 0.6), 0, 0, 0.12, 7.3, 2.44, "blanc")
    # Tribunes : pentes et toitures.
    cotes = (("x", 0, -PT / 2 - 4, LT), ("x", 0, PT / 2 + 4, LT), ("y", -LT / 2 - 4, 0, PT), ("y", LT / 2 + 4, 0, PT))
    for axe, x, y, lg in cotes:
        if axe == "x":
            s = -1 if y < 0 else 1
            k.f([(-lg / 2, y - s * 4, 0.5), (lg / 2, y - s * 4, 0.5), (lg / 2, y + s * 12, 18), (-lg / 2, y + s * 12, 18)],
                ("rouge" if s < 0 else "bleu"), vers=(0, -s, 1))
            k.boite(0, y + s * 12.5, 0, lg, 1.0, 22, "beton_clair")
            k.f([(-lg / 2, y + s * 13, 24), (lg / 2, y + s * 13, 24), (lg / 2, y - s * 4, 22), (-lg / 2, y - s * 4, 22)],
                "tole", vers=(0, 0, 1))
            k.f([(-lg / 2, y + s * 13, 23.6), (lg / 2, y + s * 13, 23.6), (lg / 2, y - s * 4, 21.6),
                 (-lg / 2, y - s * 4, 21.6)], "sous_toit", vers=(0, 0, -1))
            k.ouverture(0, y + s * 13, (0, s), 0, 5.0, lg * 0.6, 2.0, "verre_bleu", None)
        else:
            s = -1 if x < 0 else 1
            k.f([(x - s * 4, -lg / 2, 0.5), (x + s * 10, -lg / 2, 12), (x + s * 10, lg / 2, 12), (x - s * 4, lg / 2, 0.5)],
                "rouge", vers=(-s, 0, 1))
            k.boite(x + s * 10.5, 0, 0, 1.0, lg, 14, "beton_clair")
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = sx * (LT / 2 + 10), sy * (PT / 2 + 14)
            k.boite(x, y, 0, 1.0, 1.0, 40, "metal")
            k.boite(x, y, 40, 5.0, 1.0, 3.0, "blanc")


@batiment(F, "club_house_golf", "Club-house de golf", "sport", 4_500_000,
          "Club-house de bois et pierre à véranda, green d'entraînement et voiturettes.",
          "Club-houses de golf écossais et américains", era="moderne", emplois=26, visiteurs=200,
          metiers=[["coach", 2], ["serveur", 2], ["cuisinier", 1], ["agriculteur", 1]], role="golf", zone="C",
          access=["route", "chemin"])
def club_house_golf(k):
    k.sol(0, 0, 52, 40, "pelouse")
    k.corps(-6, 6, 0, 28, 14, 2, 3.4, "pierre_claire", fen=fen(avant=7, arriere=6, gauche=3, droite=3, l=1.6, h=1.8,
                                                               cadre="blanc"),
            porte={"l": 2.0, "h": 2.6, "couleur": "bois_sombre"})
    k.porche(-6, -1, 24, 3.4, 3.2, 7, toit="ardoise", poteau="blanc", sol="bois_clair")
    k.toit_2pans(-6, 6, 6.8, 28, 14, 3.6, "ardoise", axe="x", pignon="bois", debord=0.6)
    k.cheminee(-16, 8, 6.8, 4.0, "pierre_grise", l=1.0)
    k.cyl(16, -10, 0, 0.04, 7, "vert", n=12)
    k.cyl(16, -10, 0, 2.2, 0.04, "blanc", n=4)
    k.boite(16.4, -10, 2.0, 0.8, 0.04, 0.5, "rouge")
    for i in range(4):
        k.boite(10 + i * 2.2, 10, 0, 1.3, 2.4, 1.0, "blanc")
        k.boite(10 + i * 2.2, 10, 1.9, 1.4, 2.0, 0.08, "vert")
