"""Génère les bâtiments de la bible Blender et leur fiche de catalogue.

Chaque famille (publics, residences, industrie, fermes…) est un module de ce
dossier qui déclare ses bâtiments avec le décorateur `batiment`. Pour chaque
bâtiment : un .glb (assets/modeles/bible/<id>.glb), sa carte de palette
(<id>.palette.json, pour CouleursModele.recolore), une vignette, et une ligne
dans la fiche de la famille (assets/modeles/bible/<famille>.json) que le jeu
lit pour remplir le catalogue de construction.

Usage (Blender 4.2 ou plus, ou le module Python bpy) :
    blender --background --factory-startup --python tools/blender/bible/generer.py -- \
        --famille publics [--seul eglise_romane] [--vignettes docs/bible-blender]
"""

import importlib
import json
import math
import os
import sys

ICI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, ICI)
sys.path.insert(0, os.path.join(ICI, ".."))

import bpy  # noqa: E402,F401  (avant bmesh avec le module Python bpy)
import batiment_lowpoly as lp  # noqa: E402
import kit_bible  # noqa: E402
import registre  # noqa: E402

RACINE = os.path.abspath(os.path.join(ICI, "..", "..", ".."))
DOSSIER = os.path.join(RACINE, "assets", "modeles", "bible")
MAX_TRIANGLES = 3000


def genere(fiche, vignettes=None):
    k = kit_bible.Kit(fiche.get("couleurs"))
    fiche["fabrique"](k)
    dx, dy, dz = k.centre_et_bornes()
    out = os.path.join(DOSSIER, fiche["id"] + ".glb")
    obj = lp.exporte(k.b, fiche["id"], {"out": out})
    tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    if tris > MAX_TRIANGLES:
        raise ValueError("%s : %d triangles (max %d)" % (fiche["id"], tris, MAX_TRIANGLES))
    if vignettes:
        os.makedirs(vignettes, exist_ok=True)
        kit_bible.vignette(obj, os.path.join(vignettes, fiche["id"] + ".png"))
    # Emprise en cases : le modèle plus une marge d'un mètre de chaque côté
    # (sauf demande contraire), arrondie au mètre.
    marge = float(fiche.get("marge", 1.0))
    entree = {k2: v for k2, v in fiche.items() if k2 not in ("fabrique", "couleurs", "marge", "emprise")}
    entree.update({
        "glb": "res://assets/modeles/bible/%s.glb" % fiche["id"],
        "w": int(math.ceil(dx + 2 * marge - 0.01)),
        "d": int(math.ceil(dy + 2 * marge - 0.01)),
        "h": round(dz, 1),
        "tris": tris,
        # Emprise imposée (éolienne : les pales survolent les cases voisines).
        **({"w": fiche["emprise"][0], "d": fiche["emprise"][1], "survol": 1} if "emprise" in fiche else {}),
        # Palette dans l'ordre des cases : le jeu colore les sommets avec.
        "palette": [[nom, "#%02x%02x%02x" % tuple(round(c * 255) for c in k.b.palette.couleurs[i])]
                    for nom, i in sorted(k.b.palette.cases.items(), key=lambda e: e[1])],
    })
    print("BIBLE %-28s %5d tris  %5.1f x %5.1f x %5.1f m" % (fiche["id"], tris, dx, dy, dz))
    return entree


def main():
    opts = lp.lire_options()
    famille = opts["famille"]
    importlib.import_module(famille)
    fiches = registre.FICHES[famille]
    seul = opts.get("seul")
    chemin_json = os.path.join(DOSSIER, famille + ".json")
    anciennes = {}
    if seul and os.path.exists(chemin_json):
        with open(chemin_json, encoding="utf-8") as f:
            anciennes = {e["id"]: e for e in json.load(f)["batiments"]}
    os.makedirs(DOSSIER, exist_ok=True)
    entrees = []
    erreurs = []
    for fiche in fiches:
        if seul and fiche["id"] not in seul.split(","):
            if fiche["id"] in anciennes:
                entrees.append(anciennes[fiche["id"]])
            continue
        try:
            entrees.append(genere(dict(fiche), opts.get("vignettes")))
        except ValueError as e:
            erreurs.append(str(e))
    with open(chemin_json, "w", encoding="utf-8", newline="\n") as f:
        json.dump({"famille": famille, "batiments": entrees}, f, ensure_ascii=False, indent=1)
        f.write("\n")
    print("FAMILLE %s : %d bâtiments -> %s" % (famille, len(entrees), chemin_json))
    for e in erreurs:
        print("ERREUR", e)
    if erreurs:
        sys.exit(1)


if __name__ == "__main__":
    main()
