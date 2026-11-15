"""Texte -> chemins SVG (lettres vectorisées), pour que les logos ne dépendent
d'aucune police installée.

    from texte import texte
    t = texte("Fredoka", "ManiGames", taille=120, graisse=600)
    t.d        # attribut d du <path>, origine = début de la ligne de base
    t.largeur  # avance totale en px
    t.haut, t.bas  # hauteur au-dessus / en dessous de la ligne de base (px)

Mise en forme par HarfBuzz (crénage, ligatures), contours par fontTools.
Polices libres (OFL) dans tools/marque/polices/.
"""
from __future__ import annotations

import os
from dataclasses import dataclass, field

import uharfbuzz as hb
from fontTools.pens.boundsPen import BoundsPen
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont

ICI = os.path.dirname(os.path.abspath(__file__))
POLICES = os.path.join(ICI, "polices")
_cache: dict[str, tuple[TTFont, bytes]] = {}


def _police(nom: str) -> tuple[TTFont, bytes]:
    if nom not in _cache:
        chemin = os.path.join(POLICES, nom + ".ttf")
        with open(chemin, "rb") as f:
            data = f.read()
        _cache[nom] = (TTFont(chemin), data)
    return _cache[nom]


@dataclass
class Texte:
    d: str
    largeur: float
    haut: float
    bas: float
    gauche: float = 0.0
    droite: float = 0.0
    glyphes: list = field(default_factory=list)  # (nom, x, y, avance) en px


def texte(police: str, chaine: str, taille: float = 100, graisse: float = 400,
          approche: float = 0.0, axes: dict | None = None,
          remplacer: dict | None = None) -> Texte:
    """approche : espacement ajouté entre les lettres, en fraction de la taille.
    remplacer : glyphes dessinés à la place d'autres, ex. {"i": "dotlessi"}
    (i sans point, pour mettre un petit cube à la place)."""
    ft, data = _police(police)
    upem = ft["head"].unitsPerEm
    loc = {"wght": graisse}
    if axes:
        loc.update(axes)
    fvar = ft["fvar"].axes if "fvar" in ft else []
    loc = {k: v for k, v in loc.items() if any(a.axisTag == k for a in fvar)}

    face = hb.Face(data)
    font = hb.Font(face)
    font.set_variations(loc)
    buf = hb.Buffer()
    buf.add_str(chaine)
    buf.guess_segment_properties()
    hb.shape(font, buf, {"kern": True, "liga": True})

    gs = ft.getGlyphSet(location=loc)
    order = ft.getGlyphOrder()
    k = taille / upem
    pen = SVGPathPen(gs)
    bp = BoundsPen(gs)
    x = 0.0
    glyphes = []
    for info, pos in zip(buf.glyph_infos, buf.glyph_positions):
        nom = order[info.codepoint]
        dessin = (remplacer or {}).get(nom, nom)
        gx = x + pos.x_offset
        gy = pos.y_offset
        # y vers le bas en SVG
        t = (k, 0, 0, -k, gx * k, -gy * k)
        gs[dessin].draw(TransformPen(pen, t))
        gs[dessin].draw(TransformPen(bp, t))
        glyphes.append((nom, gx * k, -gy * k, pos.x_advance * k))
        x += pos.x_advance + approche * upem
    x -= approche * upem
    b = bp.bounds or (0, 0, 0, 0)
    return Texte(pen.getCommands(), x * k, -b[1], b[3], b[0], b[2], glyphes)


def glyphe(police: str, nom: str, taille: float, graisse: float, x: float, y: float,
           axes: dict | None = None) -> str:
    """Contour d'un seul glyphe placé en (x, y) (ligne de base)."""
    ft, _ = _police(police)
    upem = ft["head"].unitsPerEm
    loc = {"wght": graisse}
    if axes:
        loc.update(axes)
    gs = ft.getGlyphSet(location=loc)
    k = taille / upem
    pen = SVGPathPen(gs)
    gs[nom].draw(TransformPen(pen, (k, 0, 0, -k, x, y)))
    return pen.getCommands()
