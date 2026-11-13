"""Fabrique tous les sons et toutes les musiques de MiniBlocs.

Rien n'est enregistré ni téléchargé : chaque son est synthétisé par les scripts
de tools/sons/ (bruits filtrés, oscillateurs, petite réverbération). Les fichiers
produits sont placés sous licence CC0 (voir assets/son/LICENCE.md).

Sorties (OGG Vorbis, 44,1 kHz) :
- assets/son/ambiance/*.ogg : boucles (nature, ville, trafic, pluie, vent, mer, chantier)
- assets/son/effets/*.ogg   : sons ponctuels (interface, construction, fanfares, tonnerre…)
- assets/son/musique/*.ogg  : morceaux

Usage : python3 tools/build_sons.py [ambiance|effets|musique] [nom…]
Dépendances : numpy, scipy, ffmpeg (avec libvorbis).
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "sons"))

import ambiances  # noqa: E402
import effets  # noqa: E402
import musique  # noqa: E402
from synth import write_ogg  # noqa: E402

OUT = os.path.join(HERE, "..", "assets", "son")


def main():
    groups = sys.argv[1:2] or ["ambiance", "effets", "musique"]
    only = set(sys.argv[2:])
    if "ambiance" in groups:
        for name, f in ambiances.ALL.items():
            if only and name not in only:
                continue
            print("ambiance", name)
            write_ogg(os.path.join(OUT, "ambiance", name + ".ogg"), f(), 3, mono=(name == "chantier"))
    if "effets" in groups:
        for name, f in effets.ALL.items():
            if only and name not in only:
                continue
            print("effet", name)
            write_ogg(os.path.join(OUT, "effets", name + ".ogg"), f(), 4)
    if "musique" in groups:
        for name, (f, title, mood) in musique.ALL.items():
            if only and name not in only:
                continue
            print("musique", name, "-", title)
            write_ogg(os.path.join(OUT, "musique", name + ".ogg"), f(), 3)


if __name__ == "__main__":
    main()
