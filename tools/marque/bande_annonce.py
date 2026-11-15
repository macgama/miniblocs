"""Bande-annonce v2 : les plans de la v1 avec le nouveau logo.

    python3 tools/marque/bande_annonce.py [--source v1.mp4] [--sortie v2.mp4]

v1 = captures/demo/miniblocs-demo-bande-annonce.mp4 (tests/demo_vitrine.gd --film),
dont le titre (0 à 4,4 s) et le carton final (après 36,9 s) étaient en police provisoire.
v2 : carton ManiGames (2,5 s) → plans de 4,4 s à 36,9 s, logo MiniBlocs en surimpression
au début → carton final (logo, « Steam · 2027 », manigames.online).
"""
from __future__ import annotations

import argparse
import os
import subprocess
import tempfile

ICI = os.path.dirname(os.path.abspath(__file__))
RACINE = os.path.abspath(os.path.join(ICI, "..", ".."))
MARQUE = os.path.join(RACINE, "marque")
DEBUT, FIN = 4.4, 36.9
CARTON1, CARTON2 = 2.5, 4.0


def rendre(html: str, sortie: str, transparent=False):
    with tempfile.NamedTemporaryFile("w", suffix=".html", delete=False, encoding="utf-8", dir=MARQUE) as f:
        f.write(html)
    try:
        subprocess.run(["node", os.path.join(ICI, "rendu.js"), f.name, sortie, "1920", "1080"]
                       + (["transparent"] if transparent else []), check=True)
    finally:
        os.remove(f.name)


STYLE = """<style>@font-face{font-family:O;src:url(file://%s/polices/Outfit.ttf)}
html,body{margin:0;width:1920px;height:1080px;font-family:O}</style>""" % ICI


def cartons(d: str):
    rendre(f"""<!doctype html><html><head>{STYLE}</head><body style="background:#FFF8EC;display:grid;place-items:center">
<img src="file://{MARQUE}/manigames-piste1-cube-empile.svg" style="width:640px"></body></html>""",
           os.path.join(d, "c1.png"))
    rendre(f"""<!doctype html><html><head>{STYLE}</head><body style="background:transparent">
<img src="file://{MARQUE}/miniblocs-logo.svg" style="position:absolute;left:50%;top:46%;width:1100px;
transform:translate(-50%,-50%);filter:drop-shadow(0 12px 30px rgba(0,0,0,.45))"></body></html>""",
           os.path.join(d, "logo.png"), transparent=True)
    rendre(f"""<!doctype html><html><head>{STYLE}</head><body style="background:#22303C;color:#FFF8EC;text-align:center">
<img src="file://{MARQUE}/miniblocs-logo.svg" style="width:1000px;margin-top:250px">
<div style="font-weight:800;font-size:64px;margin-top:30px;color:#F2C14E;font-variation-settings:'wght' 800">Steam · 2027</div>
<div style="position:absolute;left:0;right:0;bottom:90px;display:flex;justify-content:center;align-items:center;gap:40px">
<img src="file://{MARQUE}/manigames-piste1-cube-court-sombre.svg" style="height:64px">
<span style="font-size:40px;opacity:.85">manigames.online</span></div></body></html>""",
           os.path.join(d, "c3.png"))


def run(*a):
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", *a], check=True)


def construire(source: str, sortie: str):
    with tempfile.TemporaryDirectory() as d:
        cartons(d)
        enc = ["-c:v", "libx264", "-preset", "slow", "-crf", "18", "-pix_fmt", "yuv420p", "-r", "30"]
        run("-loop", "1", "-t", str(CARTON1), "-i", f"{d}/c1.png",
            "-vf", f"fade=in:0:15,fade=out:st={CARTON1 - .5}:d=0.5", *enc, f"{d}/a.mp4")
        duree = FIN - DEBUT
        run("-ss", str(DEBUT), "-t", str(duree), "-i", source, "-loop", "1", "-t", "4", "-i", f"{d}/logo.png",
            "-filter_complex",
            "[1:v]format=rgba,fade=in:st=0.3:d=0.6:alpha=1,fade=out:st=3.2:d=0.7:alpha=1[l];"
            "[0:v][l]overlay=0:0:eof_action=pass,fade=in:0:10",
            "-an", *enc, f"{d}/b.mp4")
        run("-loop", "1", "-t", str(CARTON2), "-i", f"{d}/c3.png", "-vf", "fade=in:0:15", *enc, f"{d}/c.mp4")
        with open(f"{d}/liste.txt", "w") as f:
            f.write("file 'a.mp4'\nfile 'b.mp4'\nfile 'c.mp4'\n")
        run("-f", "concat", "-safe", "0", "-i", f"{d}/liste.txt", "-c", "copy", f"{d}/video.mp4")
        total = CARTON1 + duree + CARTON2
        run("-i", f"{d}/video.mp4", "-i", source, "-map", "0:v", "-map", "1:a", "-t", str(total),
            "-af", f"afade=out:st={total - 2}:d=2", "-c:v", "copy", "-c:a", "aac", "-b:a", "192k",
            "-movflags", "+faststart", sortie)
    print(sortie)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--source", default="/mnt/project-files/captures/demo/miniblocs-demo-bande-annonce.mp4")
    ap.add_argument("--sortie", default="/mnt/project-files/captures/demo/miniblocs-bande-annonce-v2.mp4")
    a = ap.parse_args()
    construire(a.source, a.sortie)
