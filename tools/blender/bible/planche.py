"""Assemble les vignettes d'une famille en une planche (JPEG) avec les noms.

Usage : python3 tools/blender/bible/planche.py --famille publics \
            --vignettes dossier_png --out docs/bible-blender/planche-publics.jpg [--colonnes 6]
"""

import argparse
import json
import os

from PIL import Image, ImageDraw, ImageFont

ICI = os.path.dirname(os.path.abspath(__file__))
RACINE = os.path.abspath(os.path.join(ICI, "..", "..", ".."))


def police(taille):
    for chemin in ("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", "C:/Windows/Fonts/segoeui.ttf",
                   "/System/Library/Fonts/Helvetica.ttc"):
        if os.path.exists(chemin):
            return ImageFont.truetype(chemin, taille)
    return ImageFont.load_default()


def main():
    a = argparse.ArgumentParser()
    a.add_argument("--famille", required=True)
    a.add_argument("--vignettes", required=True)
    a.add_argument("--out", required=True)
    a.add_argument("--colonnes", type=int, default=6)
    o = a.parse_args()
    with open(os.path.join(RACINE, "assets", "modeles", "bible", o.famille + ".json"), encoding="utf-8") as f:
        fiches = json.load(f)["batiments"]
    cw, ch, legende = 300, 225, 44
    cols = o.colonnes
    lignes = (len(fiches) + cols - 1) // cols
    img = Image.new("RGB", (cols * cw, lignes * (ch + legende)), (236, 233, 226))
    d = ImageDraw.Draw(img)
    f1, f2 = police(17), police(13)
    for i, e in enumerate(fiches):
        x, y = (i % cols) * cw, (i // cols) * (ch + legende)
        chemin = os.path.join(o.vignettes, e["id"] + ".png")
        if os.path.exists(chemin):
            v = Image.open(chemin).convert("RGBA")
            v.thumbnail((cw, ch))
            fond = Image.new("RGBA", (cw, ch), (214, 222, 228, 255))
            fond.alpha_composite(v, ((cw - v.width) // 2, (ch - v.height) // 2))
            img.paste(fond.convert("RGB"), (x, y))
        d.text((x + 8, y + ch + 4), e["name"], fill=(30, 30, 34), font=f1)
        d.text((x + 8, y + ch + 25), "%d × %d m · %d tri." % (e["w"], e["d"], e["tris"]), fill=(90, 90, 96), font=f2)
    os.makedirs(os.path.dirname(os.path.abspath(o.out)), exist_ok=True)
    img.save(o.out, quality=86)
    print("PLANCHE", o.out, len(fiches))


if __name__ == "__main__":
    main()
