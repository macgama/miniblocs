"""Écrit docs/bible-blender.md à partir des fiches de familles (assets/modeles/bible/*.json).

Usage : python3 tools/blender/bible/doc.py
"""

import json
import os

ICI = os.path.dirname(os.path.abspath(__file__))
RACINE = os.path.abspath(os.path.join(ICI, "..", "..", ".."))
DOSSIER = os.path.join(RACINE, "assets", "modeles", "bible")

FAMILLES = [
    ("publics", "Bâtiments publics", "Culte, administration, culture, éducation, santé, sécurité, sport couvert, gares."),
    ("residences", "Résidences", "Maisons traditionnelles du monde, maisons et villas modernes, immeubles et tours."),
    ("industrie", "Industrie et énergie", "Ateliers, usines, entrepôts, énergie, chantiers et infrastructures."),
    ("fermes", "Fermes et agriculture", "Fermes, granges, étables, silos, serres, moulins et bâtiments agricoles."),
    ("commerces", "Commerces, loisirs et hôtels", "Boutiques, marchés, grandes surfaces, restaurants, hôtels, bureaux, loisirs."),
    ("monde", "Styles du monde et monuments", "Terre d'Afrique et du Moyen-Orient, temples et maisons d'Asie, Amériques, Océanie, monuments anciens."),
]

CATS = {"logement": "Logement", "commerce": "Commerce", "industrie": "Industrie",
        "production": "Production", "services": "Services publics", "loisirs": "Loisirs", "sport": "Sport"}

ENTETE = """# Bible de bâtiments Blender

Des centaines de bâtiments **modélisés dans Blender par script**, d'après des bâtiments réels ou des types
courants du monde entier, et branchés dans le catalogue de construction du jeu (touche **B**, puis la
catégorie). Chaque bâtiment a son prix, ses emplois et leurs métiers, ses logements ou ses visiteurs, sa
région et son époque (les filtres du panneau), et plusieurs variantes de couleur.

{total} bâtiments à ce jour : {resume}.

![Un quartier né du zonage avec le style « Bâtiments Blender »](bible-blender/jeu-zonage.jpg)

![Les bâtiments publics posés dans le jeu](bible-blender/jeu-publics.jpg)

![La nuit, les fenêtres des immeubles s'allument](bible-blender/jeu-nuit.jpg)

![Fermes et serres un matin de brume](bible-blender/jeu-fermes.jpg)

## Comment ça marche

1. **Blender, sans interface** : `tools/blender/bible/generer.py` construit chaque bâtiment avec le kit
   `tools/blender/bible/kit_bible.py` (corps de bâtiment et fenêtres sur chaque façade, toits à deux pans,
   à croupes, mansardés, en voûte, en sheds, clochers, coupoles, bulbes, silos, colombages, pignons à
   redents…). Le kit s'appuie sur le générateur commun `tools/blender/batiment_lowpoly.py` (palette, export).
2. Chaque bâtiment donne un `.glb` dans `assets/modeles/bible/` avec sa **texture palette 64 × 64** et sa carte
   `<id>.palette.json` : on peut le recolorer dans une scène avec `CouleursModele.recolore()`, comme les stades.
3. Chaque famille a sa fiche `assets/modeles/bible/<famille>.json` (nom, catégorie, emprise, prix, emplois,
   métiers, logements, source…). **`BibleGlb`** (`scripts/modeles/bible_glb.gd`) la lit et `BuildingCatalog`
   ajoute les bâtiments au catalogue.
4. Dans le jeu, le `.glb` est « cuit » en maillage à couleurs par sommet, comme les bâtiments faits en code :
   même matériau partagé, donc **fenêtres allumées la nuit**, intérieurs derrière les vitres, usure,
   chantiers, ombre au pied des murs, et **variantes de couleur** (murs, toit, volets) selon le bâtiment.

Règles des modèles : 1 unité = 1 mètre, origine au sol au centre, façade principale vers la voie,
3 000 triangles au plus (la plupart en ont moins de 1 000). Les métiers des emplois viennent de
`Metiers.METIERS` ; le champ `role` relie un bâtiment aux mécaniques existantes (une école accueille des
élèves, une église la vie spirituelle, une caserne les pompiers…).

## Tester dans Godot

1. Ouvre le projet dans Godot 4.3 ou plus récent (les `.glb` s'importent tout seuls, ça prend une minute la
   première fois).
2. Lance le jeu (**F5**), choisis un lieu, puis **B** (Construire) : les nouveaux bâtiments sont dans
   chaque catégorie. Le filtre de région (Europe, Asie de l'Est, Amériques…) et d'époque aide à les trouver.
   Un bâtiment se pose comme les autres (clic, **R** pour tourner) ; il lui faut une route à côté.
3. Passe la nuit (**Maj+T** pour accélérer) : les fenêtres s'allument.
4. Zonage : dans l'onglet Zones du panneau, choisis le style **« Bâtiments Blender (bible) »** ; les maisons,
   immeubles, commerces et ateliers de la bible poussent alors dans les zones peintes.

Vitrine de toute une famille le long de deux routes :

```bash
godot --path . --script res://tests/batiments_vitrine.gd -- --famille publics --screenshot vitrine.png
```

Test automatique :

```bash
godot --headless --path . --import
godot --headless --path . --script res://tests/bible_glb_test.gd
```

Il doit afficher `BIBLE GLB TEST OK` (fiches complètes, métiers connus, maillage léger posé au sol et
contenu dans son emprise, vitres reconnues, variantes de couleur).

Refaire une famille avec Blender (sur le PC de Gaël) :

```bash
"C:\\Program Files\\Blender Foundation\\Blender 5.2\\blender.exe" --background --factory-startup --python tools/blender/bible/generer.py -- --famille publics --vignettes vignettes
python tools/blender/bible/planche.py --famille publics --vignettes vignettes --out docs/bible-blender/planche-publics.jpg
python tools/blender/bible/doc.py
```

`--seul id1,id2` ne refait que ces bâtiments. Le dossier `vignettes` (images de chaque bâtiment) n'est pas
gardé dans le dépôt : seules les planches le sont. Pour ajouter un bâtiment : une fonction de plus dans le
module de sa famille, avec le décorateur `@batiment(...)` (voir `tools/blender/bible/registre.py`).
"""


def euros(v):
    if v >= 1_000_000:
        return ("%.1f M€" % (v / 1e6)).replace(".0 M", " M").replace(".", ",")
    return "%d k€" % round(v / 1000)


def main():
    familles = []
    for fid, titre, sous in FAMILLES:
        chemin = os.path.join(DOSSIER, fid + ".json")
        if os.path.exists(chemin):
            with open(chemin, encoding="utf-8") as f:
                familles.append((fid, titre, sous, json.load(f)["batiments"]))
    total = sum(len(b) for *_, b in familles)
    resume = ", ".join("%d %s" % (len(b), t.lower()) for _, t, _, b in familles)
    lignes = [ENTETE.format(total=total, resume=resume)]
    for fid, titre, sous, bats in familles:
        lignes.append("## %s (%d)\n\n%s\n\n![%s](bible-blender/planche-%s.jpg)\n" % (titre, len(bats), sous, titre, fid))
        lignes.append("| Bâtiment | Catégorie | Emprise | Prix | Emplois / logements | D'après |")
        lignes.append("| --- | --- | --- | --- | --- | --- |")
        for e in bats:
            occ = []
            if e.get("emplois"):
                occ.append("%d emplois" % e["emplois"])
            if e.get("logements"):
                occ.append("%d logement%s" % (e["logements"], "s" if e["logements"] > 1 else ""))
            if e.get("visiteurs") and not occ:
                occ.append("%d visiteurs" % e["visiteurs"])
            lignes.append("| **%s** — %s | %s | %d × %d m, %s m de haut | %s | %s | %s |" % (
                e["name"], e["desc"], CATS.get(e["cat"], e["cat"]), e["w"], e["d"], ("%g" % e["h"]).replace(".", ","), euros(e["cost"]),
                ", ".join(occ) or "—", e.get("source", "")))
        lignes.append("")
    with open(os.path.join(RACINE, "docs", "bible-blender.md"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lignes))
    print("DOC", total, "bâtiments")


if __name__ == "__main__":
    main()
