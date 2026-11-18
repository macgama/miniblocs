"""Capsules Steam de MiniBlocs (et image de partage du site), avec le logo final.

    python3 tools/marque/capsules.py [--grandes DOSSIER] [--captures DOSSIER]

Images de fond : les grandes captures 3840 × 2160 de tests/demo_vitrine.gd --grand
(grand-village.png, grand-horizon.png, grand-centre.png, grand-foot.png, grand-soir.png),
sinon les captures 1920 × 1080 de la démo. Sortie : marque/steam/.
Chaque capsule est une petite page HTML rendue par Chromium à la taille exacte.
"""
from __future__ import annotations

import argparse
import os
import subprocess
import tempfile

ICI = os.path.dirname(os.path.abspath(__file__))
RACINE = os.path.abspath(os.path.join(ICI, "..", ".."))
MARQUE = os.path.join(RACINE, "marque")
SORTIE = os.path.join(MARQUE, "steam")

# nom, largeur, hauteur, fond, position du fond, zoom, logo (largeur en %, x, y), voile, logo du studio
CAPSULES = [
    ("capsule-entete-920x430", 920, 430, "village", "50% 45%", 1.0, (62, "50%", "50%"), "bas", False),
    ("capsule-petite-462x174", 462, 174, "village", "50% 40%", 1.0, (86, "50%", "50%"), "plein", False),
    ("capsule-principale-1232x706", 1232, 706, "village", "50% 45%", 1.0, (56, "50%", "44%"), "bas", False),
    ("capsule-verticale-748x896", 748, 896, "centre", "50% 50%", 1.0, (86, "50%", "20%"), "haut", False),
    ("capsule-bibliotheque-600x900", 600, 900, "centre", "45% 50%", 1.0, (88, "50%", "19%"), "haut", False),
    ("heros-bibliotheque-3840x1240", 3840, 1240, "horizon", "50% 62%", 1.0, None, "aucun", False),
    ("fond-page-1438x810", 1438, 810, "horizon", "50% 55%", 1.0, None, "fond", False),
    ("annonce-couverture-800x450", 800, 450, "soir", "50% 50%", 1.0, (64, "50%", "48%"), "bas", False),
    ("annonce-entete-1920x622", 1920, 622, "horizon", "50% 60%", 1.0, (38, "50%", "50%"), "bas", False),
    ("og-manigames", 1200, 630, "village", "50% 45%", 1.0, None, "gauche", True),
]
FONDS = {
    "village": ("grand-village.png", "01-village-vu-du-ciel.png"),
    "horizon": ("grand-horizon.png", "02-campagne-a-l-horizon.png"),
    "centre": ("grand-centre.png", "03-centre-du-village.png"),
    "soir": ("grand-soir.png", "06-soir-au-village.png"),
    "foot": ("grand-foot.png", "07-foot-et-quartiers.png"),
}
VOILES = {
    "aucun": "none",
    "bas": "radial-gradient(ellipse at 50% 50%, rgba(20,30,40,.45) 0%, rgba(20,30,40,.15) 55%, rgba(20,30,40,0) 80%)",
    "plein": "linear-gradient(rgba(20,30,40,.35), rgba(20,30,40,.35))",
    "haut": "linear-gradient(180deg, rgba(20,30,40,.55) 0%, rgba(20,30,40,.15) 38%, rgba(20,30,40,0) 60%)",
    "fond": "linear-gradient(180deg, rgba(27,38,48,.35), rgba(27,38,48,.85))",
    "gauche": "linear-gradient(90deg, rgba(255,248,236,.96) 0%, rgba(255,248,236,.9) 42%, rgba(255,248,236,0) 72%)",
}


def fond(cle: str, grandes: str, captures: str) -> str:
    g, c = FONDS[cle]
    p = os.path.join(grandes, g)
    return p if os.path.exists(p) else os.path.join(captures, c)


def rendre(html: str, sortie: str, l: int, h: int, transparent=False) -> None:
    with tempfile.NamedTemporaryFile("w", suffix=".html", delete=False, encoding="utf-8", dir=SORTIE) as f:
        f.write(html)
        nom = f.name
    try:
        subprocess.run(["node", os.path.join(ICI, "rendu.js"), nom, sortie, str(l), str(h)]
                       + (["transparent"] if transparent else []), check=True)
    finally:
        os.remove(nom)


def capsule(spec, grandes, captures) -> str:
    nom, l, h, cle, pos, zoom, logo, voile, studio = spec
    image = "file://" + fond(cle, grandes, captures)
    logo_html = ""
    if logo:
        lw, lx, ly = logo
        logo_html = (f'<img class="logo" src="file://{MARQUE}/miniblocs-logo.svg" '
                     f'style="width:{lw}%;left:{lx};top:{ly}">')
    if studio:
        logo_html = (f'<img class="studio" src="file://{MARQUE}/manigames-piste1-cube-empile.svg">')
    filtre = "saturate(.85) brightness(.9) blur(1px)" if voile == "fond" else "saturate(1.05)"
    html = f"""<!doctype html><html><head><meta charset="utf-8"><style>
html,body{{margin:0;width:{l}px;height:{h}px;overflow:hidden;background:#22303C}}
.fond{{position:absolute;inset:0;width:100%;height:100%;object-fit:cover;object-position:{pos};
  transform:scale({zoom});filter:{filtre}}}
.voile{{position:absolute;inset:0;background:{VOILES[voile]}}}
.logo{{position:absolute;transform:translate(-50%,-50%);filter:drop-shadow(0 {h * .012:.0f}px {h * .03:.0f}px rgba(0,0,0,.45))}}
.studio{{position:absolute;left:7%;top:50%;transform:translateY(-50%);width:36%}}
</style></head><body><img class="fond" src="{image}"><div class="voile"></div>{logo_html}</body></html>"""
    sortie = os.path.join(SORTIE, nom + ".png")
    rendre(html, sortie, l, h)
    return sortie


def logo_bibliotheque() -> str:
    """Logo de bibliothèque 1280 × 720, fond transparent (Steam le pose sur le héros)."""
    html = f"""<!doctype html><html><head><meta charset="utf-8"><style>
html,body{{margin:0;width:1280px;height:720px;background:transparent}}
img{{position:absolute;left:50%;top:50%;width:92%;transform:translate(-50%,-50%)}}
</style></head><body><img src="file://{MARQUE}/miniblocs-logo.svg"></body></html>"""
    sortie = os.path.join(SORTIE, "logo-bibliotheque-1280x720.png")
    rendre(html, sortie, 1280, 720, transparent=True)
    return sortie


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--grandes", default="/mnt/project-files/captures/demo/grandes")
    ap.add_argument("--captures", default="/mnt/project-files/captures/demo")
    a = ap.parse_args()
    os.makedirs(SORTIE, exist_ok=True)
    for s in CAPSULES:
        print(os.path.relpath(capsule(s, a.grandes, a.captures), RACINE))
    print(os.path.relpath(logo_bibliotheque(), RACINE))
