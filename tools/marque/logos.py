"""Logos ManiGames (4 pistes) et logo du jeu MiniBlocs, en SVG vectorisé.

    python3 tools/marque/logos.py            # écrit marque/*.svg
    python3 tools/marque/logos.py --png      # + rendus PNG (Chromium, voir rendu.js)

Les lettres sont converties en contours (texte.py) : les SVG s'ouvrent partout
(Illustrator, Inkscape, navigateur) sans installer les polices.
"""
from __future__ import annotations

import math
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from texte import glyphe, texte  # noqa: E402

RACINE = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SORTIE = os.path.join(RACINE, "marque")

# Couleurs de MiniBlocs (icône du jeu, menu titre)
JAUNE, JAUNE_F = "#F2C14E", "#C9962A"
ROUGE, ROUGE_F = "#E4572E", "#B03A1A"
BLEU, BLEU_F = "#5DA9E9", "#3478B5"
VERT, VERT_F = "#7FB069", "#55834A"
ENCRE = "#22303C"
CREME = "#FFF8EC"


def svg(l: float, h: float, corps: str, fond: str | None = None) -> str:
    f = f'<rect width="{l:.0f}" height="{h:.0f}" fill="{fond}"/>' if fond else ""
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{l:.0f}" height="{h:.0f}" '
            f'viewBox="0 0 {l:.0f} {h:.0f}">{f}{corps}</svg>\n')


def _pts(pts) -> str:
    return " ".join(f"{x:.2f},{y:.2f}" for x, y in pts)


def faces_cube(cx: float, cy: float, s: float):
    """Les trois faces d'un cube isométrique ; (cx, cy) = coin avant du dessus."""
    c = s * math.cos(math.radians(30))
    dessus = [(cx, cy - s), (cx + c, cy - s / 2), (cx, cy), (cx - c, cy - s / 2)]
    gauche = [(cx - c, cy - s / 2), (cx, cy), (cx, cy + s), (cx - c, cy + s / 2)]
    droite = [(cx, cy), (cx + c, cy - s / 2), (cx + c, cy + s / 2), (cx, cy + s)]
    return dessus, gauche, droite


def cube(cx, cy, s, haut=JAUNE, g=ROUGE, d=ROUGE_F, trait: str | None = None, ep=0.0) -> str:
    dessus, gauche, droite = faces_cube(cx, cy, s)
    t = f' stroke="{trait}" stroke-width="{ep:.2f}" stroke-linejoin="round"' if trait else ""
    return (f'<polygon points="{_pts(gauche)}" fill="{g}"{t}/>'
            f'<polygon points="{_pts(droite)}" fill="{d}"{t}/>'
            f'<polygon points="{_pts(dessus)}" fill="{haut}"{t}/>')


def lettre_sur_face(police, car, graisse, o, u, v, marge=0.2, couleur=CREME) -> str:
    """Pose une lettre sur une face (origine o, axes u et v) d'un cube."""
    t = texte(police, car, 100, graisse)
    x0, x1, y0, y1 = t.gauche, t.droite, -t.haut, t.bas
    su = (1 - 2 * marge) / (x1 - x0)
    sv = (1 - 2 * marge) / (y1 - y0)
    # garder les proportions de la lettre
    k = min(su, sv)
    mu = (1 - (x1 - x0) * k) / 2
    mv = (1 - (y1 - y0) * k) / 2
    a, b = k * u[0], k * u[1]
    c, d = k * v[0], k * v[1]
    e = o[0] + (mu - x0 * k) * u[0] + (mv - y0 * k) * v[0]
    f = o[1] + (mu - x0 * k) * u[1] + (mv - y0 * k) * v[1]
    return (f'<path d="{t.d}" fill="{couleur}" '
            f'transform="matrix({a:.4f} {b:.4f} {c:.4f} {d:.4f} {e:.2f} {f:.2f})"/>')


def mot(police, chaine, taille, graisse, x, y, couleur, approche=0.0, **kw):
    t = texte(police, chaine, taille, graisse, approche=approche, **kw)
    return f'<path transform="translate({x:.2f} {y:.2f})" d="{t.d}" fill="{couleur}"/>', t


# ---------------------------------------------------------------- piste 1
def icone_cube_mg(s=100.0, ox=0.0, oy=0.0) -> tuple[str, float, float]:
    """Cube M/G : le M sur la face rouge, le G sur la face bleue."""
    c = s * math.cos(math.radians(30))
    cx, cy = ox + c, oy + s
    corps = cube(cx, cy, s, JAUNE, ROUGE, BLEU_F)
    # petit liseré clair sur l'arête du dessus (effet low-poly)
    corps += (f'<polyline points="{_pts([(cx - c, cy - s / 2), (cx, cy), (cx + c, cy - s / 2)])}" '
              f'fill="none" stroke="{CREME}" stroke-opacity=".55" stroke-width="{s * .035:.2f}" '
              f'stroke-linejoin="round"/>')
    corps += lettre_sur_face("Outfit", "M", 800, (cx - c, cy - s / 2), (c, s / 2), (0, s), .2)
    corps += lettre_sur_face("Outfit", "G", 800, (cx, cy), (c, -s / 2), (0, s), .22)
    return corps, 2 * c, 2 * s


def piste1(sombre=False, empile=False, tag=True):
    encre = CREME if sombre else ENCRE
    ic, il, ih = icone_cube_mg(100)
    tm = texte("Outfit", "Mani", 120, 800)
    tg = texte("Outfit", "Games", 120, 800)
    ttag = texte("Outfit", "STUDIO DE JEUX INDÉPENDANT", 25.5, 500, approche=.22)
    if empile:
        larg = max(il, tm.largeur + tg.largeur)
        x = (larg - (tm.largeur + tg.largeur)) / 2
        corps = f'<g transform="translate({(larg - il) / 2:.2f} 0)">{ic}</g>'
        y = ih + 30 + tm.haut
        corps += f'<path transform="translate({x:.2f} {y:.2f})" d="{tm.d}" fill="{encre}"/>'
        corps += f'<path transform="translate({x + tm.largeur:.2f} {y:.2f})" d="{tg.d}" fill="{ROUGE}"/>'
        h = y + tg.bas + 4
        if tag:
            y2 = h + 26 + ttag.haut
            corps += f'<path transform="translate({(larg - ttag.largeur) / 2:.2f} {y2:.2f})" d="{ttag.d}" fill="{encre}" fill-opacity=".7"/>'
            h = y2 + 6
        return svg(larg + 8, h + 4, f'<g transform="translate(4 0)">{corps}</g>')
    x = il + 36
    y = ih / 2 + tm.haut / 2 - (12 if tag else 0)
    corps = ic
    corps += f'<path transform="translate({x:.2f} {y:.2f})" d="{tm.d}" fill="{encre}"/>'
    corps += f'<path transform="translate({x + tm.largeur:.2f} {y:.2f})" d="{tg.d}" fill="{ROUGE}"/>'
    larg = x + tm.largeur + tg.largeur
    if tag:
        corps += f'<path transform="translate({x + 4:.2f} {y + 46:.2f})" d="{ttag.d}" fill="{encre}" fill-opacity=".7"/>'
        larg = max(larg, x + 4 + ttag.largeur)
    return svg(larg + 6, ih + 2, corps)


# ---------------------------------------------------------------- piste 2
def icone_ville(t=200.0) -> str:
    """Badge : cinq immeubles qui dessinent un M au-dessus d'une bande de pré."""
    k = t / 200
    corps = f'<rect width="{t:.1f}" height="{t:.1f}" rx="{44 * k:.1f}" fill="{ENCRE}"/>'
    hauteurs = [118, 88, 58, 88, 118]
    couleurs = [JAUNE, BLEU, ROUGE, BLEU, JAUNE]
    lb, ec = 26 * k, 6 * k
    x0 = (t - (5 * lb + 4 * ec)) / 2
    sol = 156 * k
    for i, (hh, col) in enumerate(zip(hauteurs, couleurs)):
        x = x0 + i * (lb + ec)
        y = sol - hh * k
        corps += f'<rect x="{x:.1f}" y="{y:.1f}" width="{lb:.1f}" height="{hh * k:.1f}" rx="{3 * k:.1f}" fill="{col}"/>'
        # fenêtres
        yy = y + 10 * k
        while yy < sol - 16 * k:
            for dx in (6 * k, 15 * k):
                corps += f'<rect x="{x + dx:.1f}" y="{yy:.1f}" width="{5 * k:.1f}" height="{6 * k:.1f}" rx="{1 * k:.1f}" fill="{ENCRE}" fill-opacity=".28"/>'
            yy += 14 * k
    corps += f'<rect x="{22 * k:.1f}" y="{sol:.1f}" width="{t - 44 * k:.1f}" height="{12 * k:.1f}" rx="{6 * k:.1f}" fill="{VERT}"/>'
    return corps


def piste2(sombre=False):
    encre = CREME if sombre else ENCRE
    corps = icone_ville(200)
    a = texte("Lexend", "MANI", 92, 700, approche=.04)
    b = texte("Lexend", "GAMES", 92, 300, approche=.04)
    y = 100 + a.haut / 2
    corps += f'<path transform="translate(236 {y:.2f})" d="{a.d}" fill="{encre}"/>'
    corps += f'<path transform="translate({236 + a.largeur + 6:.2f} {y:.2f})" d="{b.d}" fill="{encre}"/>'
    return svg(236 + a.largeur + 6 + b.largeur + 6, 200, corps)


# ---------------------------------------------------------------- piste 3
def piste3(sombre=False):
    encre = CREME if sombre else ENCRE
    t = texte("Baloo2", "manigames", 160, 800, remplacer={"i": "dotlessi"})
    corps = f'<path transform="translate(0 {170:.2f})" d="{t.d}" fill="{encre}"/>'
    for nom, gx, gy, av in t.glyphes:
        if nom == "i":
            cx = gx + av / 2
            corps += cube(cx, 170 - 110, 23, JAUNE, ROUGE, ROUGE_F)
    return svg(t.largeur + 4, 215, f'<g transform="translate(2 0)">{corps}</g>')


# ---------------------------------------------------------------- piste 4
def piste4(sombre=False):
    r = 160.0
    cx = cy = r
    fond_ext = ENCRE
    corps = f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{fond_ext}"/>'
    corps += f'<circle cx="{cx}" cy="{cy}" r="{r - 52}" fill="{CREME}"/>'
    corps += f'<circle cx="{cx}" cy="{cy}" r="{r - 8}" fill="none" stroke="{JAUNE}" stroke-width="2.5"/>'
    # texte autour
    phrase = "MANIGAMES · INDIE GAMES · MADE WITH CARE · "
    taille, graisse = 25, 700
    t = texte("Outfit", phrase, taille, graisse, approche=.12)
    rt = r - 34
    total = 2 * math.pi * rt
    echelle = total / t.largeur
    # le mot MANIGAMES centré en haut
    milieu = texte("Outfit", "MANIGAMES", taille, graisse, approche=.12).largeur / 2 * echelle
    for nom, gx, gy, av in t.glyphes:
        if nom == "space":
            continue
        ang = (gx * echelle + av / 2 - milieu) / rt - math.pi / 2
        px, py = cx + rt * math.cos(ang), cy + rt * math.sin(ang)
        rot = math.degrees(ang) + 90
        d = glyphe("Outfit", nom, taille, graisse, -av / 2, taille * .36)
        coul = JAUNE if nom == "periodcentered" else CREME
        corps += f'<path d="{d}" fill="{coul}" transform="translate({px:.2f} {py:.2f}) rotate({rot:.2f})"/>'
    # trois blocs empilés au centre
    s = 34
    corps += cube(cx - 30, cy + 22, s, JAUNE, ROUGE, ROUGE_F)
    corps += cube(cx + 30, cy + 22, s, JAUNE, BLEU, BLEU_F)
    corps += cube(cx, cy - 12, s, JAUNE, VERT, VERT_F)
    return svg(2 * r, 2 * r, corps)


# ---------------------------------------------------------------- MiniBlocs
def logo_miniblocs(taille=220, ombre=14, contour=13):
    """Logo du jeu : lettres jaunes en relief, points des i en petits cubes."""
    t = texte("Fredoka", "MiniBlocs", taille, 600, remplacer={"i": "dotlessi"})
    m = contour + ombre + 30
    y = m + t.haut + taille * .1
    x = m - t.gauche
    corps = ""
    # relief : copies décalées vers le bas
    for k in range(ombre, 0, -1):
        corps += f'<path transform="translate({x + k * .35:.2f} {y + k:.2f})" d="{t.d}" fill="{ENCRE}" stroke="{ENCRE}" stroke-width="{contour * 2}" stroke-linejoin="round"/>'
    corps += f'<path transform="translate({x:.2f} {y:.2f})" d="{t.d}" fill="{ENCRE}" stroke="{ENCRE}" stroke-width="{contour * 2}" stroke-linejoin="round"/>'
    corps += f'<path transform="translate({x:.2f} {y:.2f})" d="{t.d}" fill="{JAUNE_F}"/>'
    corps += f'<path transform="translate({x:.2f} {y - taille * .025:.2f})" d="{t.d}" fill="{JAUNE}"/>'
    s = taille * .105
    xh = taille * .5
    couleurs = [(ROUGE, ROUGE_F), (BLEU, BLEU_F)]
    n = 0
    for nom, gx, gy, av in t.glyphes:
        if nom == "i":
            g, d = couleurs[n % 2]
            n += 1
            ccx, ccy = x + gx + av / 2, y - xh - s * 1.15
            corps += cube(ccx, ccy, s + contour * .55, ENCRE, ENCRE, ENCRE, ENCRE, contour * .9)
            corps += cube(ccx, ccy + ombre * .5, s + contour * .55, ENCRE, ENCRE, ENCRE)
            corps += cube(ccx, ccy, s, JAUNE, g, d)
    larg = x + t.droite + m
    haut = y + t.bas + m
    return svg(larg, haut, corps)


def icone_miniblocs(t=512):
    """Icône carrée du jeu (fond vert, cube MiniBlocs)."""
    k = t / 512
    corps = f'<rect width="{t}" height="{t}" rx="{96 * k:.1f}" fill="{VERT}"/>'
    corps += f'<rect y="{t * .72:.1f}" width="{t}" height="{t * .28:.1f}" fill="{VERT_F}" clip-path="url(#c)"/>'
    corps = f'<defs><clipPath id="c"><rect width="{t}" height="{t}" rx="{96 * k:.1f}"/></clipPath></defs>' + corps
    corps += cube(t * .5, t * .5, t * .26, JAUNE, ROUGE, ROUGE_F)
    return svg(t, t, corps)


FICHIERS = {
    "manigames-piste1-cube.svg": lambda: piste1(),
    "manigames-piste1-cube-sombre.svg": lambda: piste1(True),
    "manigames-piste1-cube-court.svg": lambda: piste1(tag=False),
    "manigames-piste1-cube-court-sombre.svg": lambda: piste1(True, tag=False),
    "manigames-piste1-cube-empile.svg": lambda: piste1(empile=True),
    "manigames-piste1-icone.svg": lambda: svg(*icone_cube_mg(100, 6, 4)[1:] and (185.3, 208), icone_cube_mg(100, 6, 4)[0]),
    "manigames-piste2-ville.svg": lambda: piste2(),
    "manigames-piste2-ville-sombre.svg": lambda: piste2(True),
    "manigames-piste2-icone.svg": lambda: svg(200, 200, icone_ville(200)),
    "manigames-piste3-point.svg": lambda: piste3(),
    "manigames-piste3-point-sombre.svg": lambda: piste3(True),
    "manigames-piste4-tampon.svg": lambda: piste4(),
    "miniblocs-logo.svg": lambda: logo_miniblocs(),
}


def ecrire() -> list[str]:
    os.makedirs(SORTIE, exist_ok=True)
    faits = []
    for nom, f in FICHIERS.items():
        chemin = os.path.join(SORTIE, nom)
        with open(chemin, "w", encoding="utf-8") as fh:
            fh.write(f())
        faits.append(chemin)
    return faits


def taille_svg(chemin: str) -> tuple[int, int]:
    import re
    with open(chemin, encoding="utf-8") as f:
        tete = f.read(400)
    m = re.search(r'width="(\d+)" height="(\d+)"', tete)
    return int(m.group(1)), int(m.group(2))


def png(chemin: str, sortie: str, largeur: int | None = None) -> None:
    """Rend un SVG en PNG transparent (Chromium), à la largeur voulue."""
    l, h = taille_svg(chemin)
    if largeur and largeur != l:
        import tempfile
        with open(chemin, encoding="utf-8") as f:
            s = f.read()
        hh = round(h * largeur / l)
        s = s.replace(f'width="{l}" height="{h}"', f'width="{largeur}" height="{hh}"', 1)
        tmp = tempfile.NamedTemporaryFile("w", suffix=".svg", delete=False, encoding="utf-8")
        tmp.write(s)
        tmp.close()
        chemin, l, h = tmp.name, largeur, hh
    subprocess.run(["node", os.path.join(os.path.dirname(__file__), "rendu.js"),
                    chemin, sortie, str(l), str(h), "transparent"], check=True)


if __name__ == "__main__":
    faits = ecrire()
    if "--png" in sys.argv:
        for c in faits:
            l, _ = taille_svg(c)
            png(c, c[:-4] + ".png", max(l * 2, 1024) if "icone" not in c else 512)
    print("\n".join(os.path.relpath(c, RACINE) for c in faits))
