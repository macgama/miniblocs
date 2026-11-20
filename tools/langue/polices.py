#!/usr/bin/env python3
"""Régénère les polices de secours (assets/polices) d'après les textes du jeu.

Ce que la police par défaut de Godot ne sait pas dessiner (flèches, ♥, chinois…)
est pris dans DejaVu Sans, Noto Sans SC et Noto Color Emoji, réduits aux seuls
caractères utilisés. Il faut fonttools (pip install fonttools) et les polices :
  python3 tools/langue/polices.py DejaVuSans.ttf NotoSansSC-Regular.otf NotoColorEmoji.ttf
"""
import glob, json, os, re, subprocess, sys

RACINE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SORTIE = os.path.join(RACINE, "assets", "polices")


def caracteres():
	cs = set()
	for f in glob.glob(os.path.join(RACINE, "scripts", "**", "*.gd"), recursive=True):
		for m in re.finditer(r'"((?:[^"\\\n]|\\.)*)"', open(f, encoding="utf-8").read()):
			cs.update(m.group(1))
	for f in glob.glob(os.path.join(RACINE, "assets", "langues", "*.json")):
		for v in json.load(open(f, encoding="utf-8"))["textes"].values():
			cs.update(v)
	return {c for c in cs if ord(c) > 0x7E}


def cjk(c):
	o = ord(c)
	return 0x2E80 <= o <= 0x9FFF or 0xFF00 <= o <= 0xFFEF or 0x3000 <= o <= 0x303F


def main():
	dejavu, sc, emoji = sys.argv[1:4]
	cs = caracteres()
	chinois = "".join(sorted(c for c in cs if cjk(c))) + "，。：；！？（）、“”‘’《》【】…—·０１２３４５６７８９"
	symboles = "".join(sorted(c for c in cs if not cjk(c) and 0x2000 <= ord(c) < 0x1F000))
	emojis = "".join(sorted(c for c in cs if ord(c) >= 0x1F000)) + "⏳"
	os.makedirs(SORTIE, exist_ok=True)
	# Noto Sans SC prend aussi les symboles absents de DejaVu (Ⓐ Ⓑ Ⓧ Ⓨ ⤵).
	for src, txt, out in [(dejavu, symboles, "symboles.ttf"), (sc, chinois + symboles, "chinois.otf"), (emoji, emojis, "emoji.ttf")]:
		subprocess.run(["pyftsubset", src, "--text=" + txt, "--output-file=" + os.path.join(SORTIE, out), "--no-hinting"], check=True)
		print(out, len(txt), "caractères")


if __name__ == "__main__":
	main()
