"""Générateur de stades de football low-poly à partir d'une fiche JSON.

Deux familles :
- "anneau" : tribunes continues autour du terrain (angles fermés ou arrondis,
  éventuellement autour d'une piste d'athlétisme), un toit en anneau, une
  façade continue (lamelles, verre à facettes, panneaux, ou ouverte) ;
- "separees" : quatre tribunes indépendantes, angles ouverts, un toit par
  tribune (stades plus anciens).

Les fiches sont dans tools/blender/stades/*.json (dimensions, couleurs,
sources). Repères : X le long du terrain, Y en largeur, tribune principale
côté -Y (vers +Z dans Godot), origine au centre du terrain.

Usage :
    blender --background --factory-startup --python tools/blender/batiments/stade_generique.py -- \
        --desc tools/blender/stades/stade_bale.json --out assets/modeles/batiments/stade_bale.glb \
        [--apercu apercu.png --azimuts -30]
"""

import json
import math
import os
import sys

import bmesh
import bpy

ICI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(ICI, ".."))
sys.path.insert(0, ICI)
import batiment_lowpoly as lp  # noqa: E402
import stade_commun as sc  # noqa: E402

BETON = "#d6d2c9"
BETON_SOMBRE = "#6e6d69"
SOUBASSEMENT = "#3c4046"
SOUS_TOIT = "#cfcbc3"
BANDEAU = "#2b2d31"
PISTE = "#b5523b"


# --- Contour arrondi ------------------------------------------------------------
def contour(ax, ay, r, pas=20.0, n_coin=4):
    """Rectangle arrondi (demi-côtés ax, ay, rayon r), sens trigonométrique,
    en partant de l'angle +X -Y. Chaque point : (x, y, nx, ny), la normale
    vers l'extérieur ; un décalage d vers l'extérieur reste un rectangle
    arrondi (rayon r + d)."""
    r = max(0.5, min(r, ax, ay))
    pts = []
    coins = [((ax - r, -ay + r), -90), ((ax - r, ay - r), 0),
             ((-ax + r, ay - r), 90), ((-ax + r, -ay + r), 180)]
    for (cx, cy), a0 in coins:
        # Droite qui mène à ce coin (depuis la fin du coin précédent).
        for i in range(n_coin + 1):
            a = math.radians(a0 + 90.0 * i / n_coin)
            nx, ny = math.cos(a), math.sin(a)
            pts.append((cx + r * nx, cy + r * ny, nx, ny))
        # Subdivise la droite qui suit ce coin.
        a_fin = math.radians(a0 + 90.0)
        nx, ny = math.cos(a_fin), math.sin(a_fin)
        x0, y0 = cx + r * nx, cy + r * ny
        suivant = coins[(coins.index(((cx, cy), a0)) + 1) % 4]
        (sx_, sy_), a1 = suivant
        a_deb = math.radians(a1)
        x1, y1 = sx_ + r * math.cos(a_deb), sy_ + r * math.sin(a_deb)
        lg = math.hypot(x1 - x0, y1 - y0)
        m = max(1, int(round(lg / pas)))
        for j in range(1, m):
            t = j / m
            pts.append((x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, nx, ny))
    return pts


def decale(p, d, z):
    return (p[0] + p[2] * d, p[1] + p[3] * d, z)


def cote_de(nx, ny):
    if abs(ny) >= abs(nx):
        return "S" if ny < 0 else "N"
    return "O" if nx < 0 else "E"


# --- Sections de tribune --------------------------------------------------------
def section(t, haut_mur, ferme=True):
    """Profil (d, z) d'une tribune et la « nature » de chaque arête.
    d = distance depuis le bord intérieur (devant la tribune)."""
    f, h0 = 1.5, 1.0
    do = t["profondeur"]
    hb = t.get("soubassement", 4.0)
    if t.get("niveaux", 1) >= 2:
        d1, h1 = t["profondeur"] * 0.45, t["hauteur"] * 0.38
        pts = [(f, 0), (f, h0), (d1, h1), (d1, h1 + 3.2), (d1 + 1.5, h1 + 3.2),
               (do - 3, t["hauteur"]), (do - 3, haut_mur), (do, haut_mur)]
        nat = ["front", "sieges", "loges", "dalle", "sieges", "mur_haut", "dessus", "facade"]
    else:
        pts = [(f, 0), (f, h0), (do - 3, t["hauteur"]), (do - 3, haut_mur), (do, haut_mur)]
        nat = ["front", "sieges", "mur_haut", "dessus", "facade"]
    pts += [(do, hb), (do - 1.5, hb), (do - 1.5, 0)]
    nat += ["sous_porte_a_faux", "rez", None]
    return pts, nat


def couleur_arete(nature, t, d, i_seg, cote):
    if nature == "sieges":
        motif = t.get("sieges", ["#2459a8"])
        if isinstance(motif, str):
            motif = [motif]
        return motif[(i_seg // max(1, t.get("groupe", 1))) % len(motif)]
    return {
        "front": BETON, "dalle": BETON, "dessus": BETON,
        "mur_haut": d.get("mur_haut", BETON_SOMBRE),
        "facade": d.get("facade", {}).get("couleurs", [BETON])[0],
        "sous_porte_a_faux": BETON_SOMBRE,
        "loges": ("carreaux", 3.0, 1.6),
        "rez": ("carreaux", 3.0, 2.0),
    }.get(nature, BETON)


def pose(b, pts, couleur, vers):
    if isinstance(couleur, tuple):
        b.face_orientee(pts, None, vers, mat=lp.MAT_CARREAUX, echelle=(couleur[1], couleur[2]))
    else:
        b.face_orientee(pts, couleur, vers)


# --- Famille « anneau » --------------------------------------------------------
def anneau(b, d):
    a = d["anneau"]
    t = d["tribunes"]
    ax, ay, r = a["demi_longueur"], a["demi_largeur"], a.get("rayon_angle", 2.0)
    toit = d.get("toit", {})
    zt = toit.get("hauteur", t["hauteur"] + 4)
    fac = d.get("facade", {"type": "plein"})
    ouverte = fac.get("type") == "ouverte"
    haut_mur = t["hauteur"] + 2.5 if ouverte else zt
    cont = contour(ax, ay, r, pas=a.get("pas", 20.0))
    n = len(cont)
    prof, nat = section(t, haut_mur)
    cd = sum(p[0] for p in prof) / len(prof)
    cz = sum(p[1] for p in prof) / len(prof)

    # Sol intérieur (piste ou bord de pelouse) jusqu'au pied des tribunes.
    sol = [(p[0], p[1]) for p in cont]
    sc.terrain(b, sol=sol, couleur_sol=PISTE if d.get("piste") else sc.HERBE_BORD,
               synthetique=d.get("synthetique", False))
    if d.get("piste"):
        # Lignes de couloir : deux anneaux blancs autour du terrain.
        for dd in (-9.0, -1.5):
            for i in range(n):
                p, q = cont[i], cont[(i + 1) % n]
                sc.ligne(b, *decale(p, dd, 0)[:2], *decale(q, dd, 0)[:2], l=0.12, z=0.035)

    for i in range(n):
        p, q = cont[i], cont[(i + 1) % n]
        mnx, mny = (p[2] + q[2]) / 2, (p[3] + q[3]) / 2
        for k in range(len(prof)):
            if nat[k] is None:
                continue
            (da, za), (db, zb) = prof[k], prof[(k + 1) % len(prof)]
            nd, nz = (zb - za), -(db - da)
            if nd * ((da + db) / 2 - cd) + nz * ((za + zb) / 2 - cz) < 0:
                nd, nz = -nd, -nz
            vers = (mnx * nd, mny * nd, nz)
            pts = [decale(p, da, za), decale(q, da, za), decale(q, db, zb), decale(p, db, zb)]
            pose(b, pts, couleur_arete(nat[k], t, d, i, cote_de(mnx, mny)), vers)

    do = t["profondeur"]
    hb = t.get("soubassement", 4.0)
    # Façade à lamelles ou à facettes de verre.
    if fac.get("type") in ("lamelles", "verre"):
        couleurs = fac.get("couleurs", ["#c9a96e", "#b8955a"])
        pas, saillie = fac.get("pas", 4.0), fac.get("saillie", 0.6)
        j = 0
        for i in range(n):
            p, q = cont[i], cont[(i + 1) % n]
            a0, a1 = decale(p, do + 0.05, 0), decale(q, do + 0.05, 0)
            lg = math.hypot(a1[0] - a0[0], a1[1] - a0[1])
            m = max(1, int(round(lg / pas)))
            nx, ny = (p[2] + q[2]) / 2, (p[3] + q[3]) / 2
            for k in range(m):
                u0, u1 = k / m, (k + 1) / m
                x0, y0 = a0[0] + (a1[0] - a0[0]) * u0, a0[1] + (a1[1] - a0[1]) * u0
                x1, y1 = a0[0] + (a1[0] - a0[0]) * u1, a0[1] + (a1[1] - a0[1]) * u1
                pts = [(x0, y0, hb), (x1 + nx * saillie, y1 + ny * saillie, hb),
                       (x1 + nx * saillie, y1 + ny * saillie, haut_mur), (x0, y0, haut_mur)]
                b.face_orientee(pts, couleurs[j % len(couleurs)], (nx, ny, 0))
                j += 1
    elif fac.get("type") == "bandes":
        # Façade en bandes horizontales (deux teintes) posée sur le mur.
        couleurs = fac.get("couleurs", [BETON, "#c8202f"])
        nb = fac.get("nb_bandes", 3)
        for i in range(n):
            p, q = cont[i], cont[(i + 1) % n]
            nx, ny = (p[2] + q[2]) / 2, (p[3] + q[3]) / 2
            for k in range(nb):
                z0 = hb + (haut_mur - hb) * k / nb
                z1 = hb + (haut_mur - hb) * (k + 1) / nb
                b.face_orientee([decale(p, do + 0.05, z0), decale(q, do + 0.05, z0),
                                 decale(q, do + 0.05, z1), decale(p, do + 0.05, z1)],
                                couleurs[k % len(couleurs)], (nx, ny, 0))
    if ouverte:
        # Poteaux qui portent le toit au-dessus de la tribune ouverte.
        cumul = 0.0
        for i in range(n):
            p, q = cont[i], cont[(i + 1) % n]
            cumul += math.hypot(q[0] - p[0], q[1] - p[1])
            if cumul >= fac.get("pas_poteaux", 16.0):
                cumul = 0.0
                x, y, _ = decale(q, do - 1.0, 0)
                b.boite((x, y, (haut_mur + zt) / 2), (0.6, 0.6, zt - haut_mur), BANDEAU)

    # Toit en anneau, éventuellement ondulé.
    if toit:
        d_in = toit.get("debut", 3.0)
        d_out = do + toit.get("debord", 1.0)
        ep = toit.get("epaisseur", 1.8)
        amp, periode = toit.get("ondulation", 0.0), toit.get("periode", 60.0)
        haut = toit.get("dessus", "metal")
        coul = toit.get("couleur", "#5a5f66")
        s = 0.0
        zs = []
        for i in range(n):
            zs.append(zt + amp * math.sin(2 * math.pi * s / periode))
            p, q = cont[i], cont[(i + 1) % n]
            s += math.hypot(q[0] - p[0], q[1] - p[1])
        for i in range(n):
            p, q = cont[i], cont[(i + 1) % n]
            za, zb = zs[i], zs[(i + 1) % n]
            dessus = [decale(p, d_in, za + ep), decale(q, d_in, zb + ep),
                      decale(q, d_out, zb + ep), decale(p, d_out, za + ep)]
            if haut == "solaire":
                b.face_orientee(dessus, None, (0, 0, 1), mat=lp.MAT_SOLAIRE, echelle=(4.0, 2.0))
            else:
                b.face_orientee(dessus, coul, (0, 0, 1))
            b.face_orientee([decale(p, d_in, za), decale(q, d_in, zb),
                             decale(q, d_out, zb), decale(p, d_out, za)],
                            toit.get("sous_toit", SOUS_TOIT), (0, 0, -1))
            nx, ny = (p[2] + q[2]) / 2, (p[3] + q[3]) / 2
            for dd, sens in ((d_out, 1), (d_in, -1)):
                b.face_orientee([decale(p, dd, za), decale(q, dd, zb),
                                 decale(q, dd, zb + ep), decale(p, dd, za + ep)],
                                toit.get("bandeau", BANDEAU), (sens * nx, sens * ny, 0))


# --- Famille « séparées » ------------------------------------------------------
REPERES = {
    "S": (lambda s, dd, z, hx, hy: (s, -(hy + dd), z), (0, -1, 0), (1, 0, 0)),
    "N": (lambda s, dd, z, hx, hy: (s, hy + dd, z), (0, 1, 0), (1, 0, 0)),
    "O": (lambda s, dd, z, hx, hy: (-(hx + dd), s, z), (-1, 0, 0), (0, 1, 0)),
    "E": (lambda s, dd, z, hx, hy: (hx + dd, s, z), (1, 0, 0), (0, 1, 0)),
}


def extrude(b, cote, s0, s1, prof, couleurs, hx, hy):
    w, dehors, tg = REPERES[cote]
    n = len(prof)
    cd = sum(p[0] for p in prof) / n
    cz = sum(p[1] for p in prof) / n
    for k in range(n):
        c = couleurs[k]
        if c is None:
            continue
        (da, za), (db, zb) = prof[k], prof[(k + 1) % n]
        nd, nz = (zb - za), -(db - da)
        if nd * ((da + db) / 2 - cd) + nz * ((za + zb) / 2 - cz) < 0:
            nd, nz = -nd, -nz
        vers = (dehors[0] * nd, dehors[1] * nd, nz)
        pts = [w(s0, da, za, hx, hy), w(s1, da, za, hx, hy), w(s1, db, zb, hx, hy), w(s0, db, zb, hx, hy)]
        pose(b, pts, c, vers)
    for s, signe in ((s0, -1), (s1, 1)):
        b.face_orientee([w(s, dd, z, hx, hy) for dd, z in prof], BETON_SOMBRE,
                        tuple(signe * v for v in tg))


def separees(b, d):
    hx, hy = sc.TX + d.get("degagement", 5.0), sc.TY + d.get("degagement", 5.0)
    sc.terrain(b, sol=[(-hx - 6, -hy - 6), (hx + 6, -hy - 6), (hx + 6, hy + 6), (-hx - 6, hy + 6)],
               synthetique=d.get("synthetique", False))
    for cote, t in d["tribunes"].items():
        lg = t.get("longueur", 2 * sc.TX if cote in "SN" else 2 * sc.TY)
        s0, s1 = -lg / 2, lg / 2
        do, h = t["profondeur"], t["hauteur"]
        motif = t.get("sieges", ["#c8202f"])
        motif = [motif] if isinstance(motif, str) else motif
        zt = t.get("toit")  # hauteur du toit (None = gradins à ciel ouvert)
        haut_mur = zt if zt else h + 1.2
        prof = [(1.5, 0), (1.5, 1.0), (do - 1.5, h), (do - 1.5, haut_mur), (do, haut_mur), (do, 0)]
        couls = [BETON, motif[0], t.get("mur", BETON_SOMBRE), BETON, t.get("facade", BETON), None]
        # Gradins en plusieurs blocs pour alterner les couleurs des sièges.
        nb = max(1, len(motif))
        for k in range(nb):
            a, c = s0 + (s1 - s0) * k / nb, s0 + (s1 - s0) * (k + 1) / nb
            couls[1] = motif[k]
            extrude(b, cote, a, c, prof, couls, hx, hy)
        if zt:
            ep = t.get("epaisseur_toit", 0.8)
            d_in = t.get("toit_debut", 2.0)
            toit = [(d_in, zt), (do + 0.6, zt), (do + 0.6, zt + ep), (d_in, zt + ep)]
            extrude(b, cote, s0 - 1, s1 + 1, toit,
                    [t.get("sous_toit", SOUS_TOIT), BANDEAU, t.get("couleur_toit", "#8d9096"), BANDEAU],
                    hx, hy)
            # Poteaux sur le devant si le toit porte loin.
            if t.get("poteaux"):
                w, _, _ = REPERES[cote]
                for i in range(t["poteaux"] + 1):
                    s = s0 + (s1 - s0) * i / t["poteaux"]
                    x, y, _ = w(s, d_in + 1.0, 0, hx, hy)
                    b.boite((x, y, (h * 0.15 + zt) / 2), (0.4, 0.4, zt - h * 0.15), BANDEAU)


# --- Bâtiments voisins (tours, centres commerciaux) ---------------------------
def blocs(b, d):
    for t in d.get("batiments", []):
        x, y, l, p, h = t["x"], t["y"], t["l"], t["p"], t["h"]
        b.boite((x, y, h / 2), (l, p, h), t.get("couleur", BETON), couleur_dessus=t.get("toit", "#7d8288"))
        if t.get("vitre"):
            e = 0.03
            x0, x1, y0, y1 = x - l / 2 - e, x + l / 2 + e, y - p / 2 - e, y + p / 2 + e
            z0 = t.get("vitre_depuis", 0.5)
            for pts, vers in (([(x0, y0, z0), (x1, y0, z0), (x1, y0, h - 0.5), (x0, y0, h - 0.5)], (0, -1, 0)),
                              ([(x0, y1, z0), (x1, y1, z0), (x1, y1, h - 0.5), (x0, y1, h - 0.5)], (0, 1, 0)),
                              ([(x0, y0, z0), (x0, y1, z0), (x0, y1, h - 0.5), (x0, y0, h - 0.5)], (-1, 0, 0)),
                              ([(x1, y0, z0), (x1, y1, z0), (x1, y1, h - 0.5), (x1, y0, h - 0.5)], (1, 0, 0))):
                b.face_orientee(pts, None, vers, mat=lp.MAT_CARREAUX, echelle=(3.0, 3.3))


def main():
    opts = lp.lire_options()
    with open(opts["desc"], encoding="utf-8") as f:
        d = json.load(f)
    nom = d.get("nom", os.path.splitext(os.path.basename(opts["out"]))[0])
    bpy.ops.wm.read_factory_settings(use_empty=True)
    b = lp.Batisseur(lp.Palette())
    if d.get("famille", "anneau") == "anneau":
        anneau(b, d)
    else:
        separees(b, d)
    # Socle (centre commercial sous le stade) : tout monte de sa hauteur.
    socle = d.get("socle")
    if socle:
        bmesh.ops.translate(b.bm, verts=b.bm.verts[:], vec=(0, 0, socle["hauteur"]))
        l, p = socle["longueur"], socle["largeur"]
        b.boite((socle.get("x", 0), socle.get("y", 0), socle["hauteur"] / 2),
                (l, p, socle["hauteur"]), socle.get("couleur", "#b8b4ac"))
    blocs(b, d)
    lp.exporte(b, nom, opts)


main()
