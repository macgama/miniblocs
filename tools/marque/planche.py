"""Planche de comparaison des pistes de logo ManiGames (PNG pour choisir).

    python3 tools/marque/planche.py sortie.png
"""
import os
import subprocess
import sys
import tempfile

ICI = os.path.dirname(os.path.abspath(__file__))
M = os.path.abspath(os.path.join(ICI, "..", "..", "marque"))
POL = os.path.join(ICI, "polices")

PISTES = [
    ("1. Cube MG", "Un bloc de MiniBlocs, M et G sur les faces. Actuellement sur le site.", "manigames-piste1-cube.svg", "manigames-piste1-icone.svg"),
    ("2. Ville en M", "Cinq immeubles dont les toits dessinent un M.", "manigames-piste2-ville.svg", "manigames-piste2-icone.svg"),
    ("3. Point-cube", "Minuscules rondes, le point du i est un petit cube.", "manigames-piste3-point.svg", None),
    ("4. Tampon", "Médaillon rond, trois blocs empilés.", "manigames-piste4-tampon.svg", None),
    ("5. Planète (nouveau)", "Petite Terre low-poly et son anneau : le monde entier, comme tes jeux.", "manigames-piste5-planete.svg", "manigames-piste5-icone.svg"),
    ("6. M play (nouveau)", "Tuile rouge, grand M et bouton play. Simple, se lit en tout petit.", "manigames-piste6-play.svg", "manigames-piste6-icone.svg"),
    ("7. Pixel M (nouveau)", "M en gros pixels de couleur, clin d'œil aux jeux rétro.", "manigames-piste7-pixel.svg", "manigames-piste7-icone.svg"),
    ("8. Cartouche (nouveau)", "Une cartouche de jeu, le nom sur l'étiquette.", "manigames-piste8-cartouche.svg", None),
]


def html() -> str:
    cartes = ""
    for titre, txt, logo, icone in PISTES:
        ic = (f'<div class="ic"><img src="file://{M}/{icone}"><span>icône / réseaux</span></div>' if icone else "")
        cartes += (f'<div class="c"><h2>{titre}</h2><p>{txt}</p>'
                   f'<div class="z"><img class="l" src="file://{M}/{logo}">{ic}</div></div>')
    return f"""<html><head><style>
@font-face{{font-family:O;src:url(file://{POL}/Outfit.ttf)}}
@font-face{{font-family:N;src:url(file://{POL}/Nunito.ttf)}}
body{{margin:0;background:#EFE7D8;font-family:N;color:#22303C;width:1600px;padding:32px;box-sizing:border-box}}
h1{{font-family:O;font-weight:800;font-size:40px;margin:0 0 24px}}
.g{{display:grid;grid-template-columns:1fr 1fr;gap:24px}}
.c{{background:#FFF8EC;border-radius:18px;padding:24px 28px;height:330px;box-sizing:border-box;display:flex;flex-direction:column}}
h2{{font-family:O;font-weight:800;font-size:25px;margin:0}} p{{margin:6px 0 0;font-size:16px;opacity:.75}}
.z{{flex:1;display:flex;align-items:center;justify-content:center;gap:34px}}
.l{{max-width:470px;max-height:170px}}
.ic{{display:flex;flex-direction:column;align-items:center;gap:6px;font-size:12px;opacity:.9}}
.ic img{{width:84px;height:84px;object-fit:contain}}
</style></head><body><h1>ManiGames : 8 pistes de logo</h1><div class="g">{cartes}</div></body></html>"""


if __name__ == "__main__":
    sortie = sys.argv[1]
    f = tempfile.NamedTemporaryFile("w", suffix=".html", delete=False, encoding="utf-8")
    f.write(html())
    f.close()
    subprocess.run(["node", os.path.join(ICI, "rendu.js"), f.name, sortie, "1600", "1520"], check=True)
