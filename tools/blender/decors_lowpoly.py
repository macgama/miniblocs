"""Génère tous les décors low-poly du jeu dans Blender et les exporte en .glb.

Mobilier urbain, clôtures, panneaux, marché, jeux, plage, ferme, cultures,
animaux, bateaux et pontons, rochers : de quoi rendre la Terre vivante.
Tout est construit par code (aucune ressource extérieure, aucune licence).

Une seule palette de 64 couleurs (palette_decors.png, 64 × 64 px) pour tous
les décors : dans Godot, un seul matériau. palette_decors_lumiere.png dit
quelles couleurs brillent la nuit (lanternes, feux).
Le catalogue (nom, catégorie, taille, triangles) est écrit dans decors.json,
que le jeu lit : ajouter un décor ici suffit pour qu'il apparaisse en jeu.

Usage (Blender 4.2 ou plus, testé avec 5.3) :

    blender --background --factory-startup --python tools/blender/decors_lowpoly.py -- \
        --dossier assets/modeles/decors [--seul vache_pie_noire] [--apercu vache.png] \
        [--planche docs/apercu-decors.png]

ou, avec le module Python « bpy » (pip install bpy) :

    python tools/blender/decors_lowpoly.py -- --dossier assets/modeles/decors

Repères : 1 unité = 1 m, Z vers le haut dans Blender (Y dans Godot), origine
au pied de l'objet ; l'avant regarde vers -Y (vers +Z dans Godot).
"""

import json
import math
import os
import sys

import bpy  # avant bmesh

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import batiment_lowpoly as bl  # noqa: E402  (lire_options, apercu)
from decors import base, urbain, clotures, loisirs, ferme, animaux, eau, rochers  # noqa: E402

# Catégories, dans l'ordre du panneau du jeu.
CATEGORIES = [
    ("urbain", "Mobilier urbain"), ("eclairage", "Éclairage"), ("monuments", "Fontaines et statues"),
    ("clotures", "Clôtures et murets"), ("panneaux", "Panneaux et réseaux"), ("marche", "Marché"),
    ("jeux", "Jeux et sport"), ("plage", "Plage"), ("ferme", "Ferme"), ("cultures", "Cultures"),
    ("animaux", "Animaux"), ("eau", "Bateaux et pontons"), ("rochers", "Rochers et bois"),
]

# id -> (fonction, catégorie, options). Options : ligne (longueur d'un tronçon
# qui se répète, en m), eau (posé sur l'eau, origine à la flottaison), berge
# (ponton : origine sur la berge), anime (animal qui se déplace).
U, C, L, F, A, E, R = urbain, clotures, loisirs, ferme, animaux, eau, rochers
DECORS = {
    # Mobilier urbain
    "banc_bois": (U.banc_bois, "urbain", {}), "banc_vert": (U.banc_vert, "urbain", {}),
    "banc_pierre": (U.banc_pierre, "urbain", {}), "banc_moderne": (U.banc_moderne, "urbain", {}),
    "table_pique_nique": (U.table_pique_nique, "urbain", {}), "poubelle": (U.poubelle, "urbain", {}),
    "poubelles_tri": (U.poubelles_tri, "urbain", {}), "conteneur": (U.conteneur, "urbain", {}),
    "abribus": (U.abribus, "urbain", {}), "borne_incendie": (U.borne_incendie, "urbain", {}),
    "potelet": (U.potelet, "urbain", {}), "potelets": (U.potelets, "urbain", {}),
    "boite_aux_lettres": (U.boite_aux_lettres, "urbain", {}), "cabine_telephone": (U.cabine_telephone, "urbain", {}),
    "colonne_affichage": (U.colonne_affichage, "urbain", {}), "parcmetre": (U.parcmetre, "urbain", {}),
    "arceaux_velo": (U.arceaux_velo, "urbain", {}), "jardiniere": (U.jardiniere, "urbain", {}),
    "horloge": (U.horloge, "urbain", {}), "panneau_publicite": (U.panneau_publicite, "urbain", {}),
    "terrasse_cafe": (U.terrasse_cafe, "urbain", {}),
    # Éclairage
    "lampadaire": (U.lampadaire, "eclairage", {}), "lampadaire_double": (U.lampadaire_double, "eclairage", {}),
    "reverbere": (U.reverbere, "eclairage", {}), "lampadaire_boule": (U.lampadaire_boule, "eclairage", {}),
    "lanterne_pierre": (U.lanterne_pierre, "eclairage", {}),
    # Fontaines et statues
    "fontaine": (U.fontaine, "monuments", {}), "fontaine_wallace": (U.fontaine_wallace, "monuments", {}),
    "borne_fontaine": (U.borne_fontaine, "monuments", {}), "statue": (U.statue, "monuments", {}),
    "statue_equestre": (U.statue_equestre, "monuments", {}), "buste": (U.buste, "monuments", {}),
    "monument_morts": (U.monument_morts, "monuments", {}), "obelisque": (U.obelisque, "monuments", {}),
    # Clôtures et murets (tronçons)
    "cloture_bois": (C.cloture_bois, "clotures", {"ligne": 2.0}),
    "cloture_ranch": (C.cloture_ranch, "clotures", {"ligne": 2.0}),
    "cloture_barbelee": (C.cloture_barbelee, "clotures", {"ligne": 2.0}),
    "grillage": (C.grillage, "clotures", {"ligne": 2.0}),
    "muret_pierre": (C.muret_pierre, "clotures", {"ligne": 2.0}),
    "mur_brique": (C.mur_brique, "clotures", {"ligne": 2.0}),
    "haie": (C.haie, "clotures", {"ligne": 2.0}),
    "barriere_metal": (C.barriere_metal, "clotures", {"ligne": 2.0}),
    "glissiere": (C.glissiere, "clotures", {"ligne": 2.0}),
    "palissade_bambou": (C.palissade_bambou, "clotures", {"ligne": 2.0}),
    "portail_ferme": (C.portail_ferme, "clotures", {}),
    # Panneaux et réseaux
    "panneau_stop": (C.panneau_stop, "panneaux", {}), "panneau_cedez": (C.panneau_cedez, "panneaux", {}),
    "panneau_vitesse": (C.panneau_vitesse, "panneaux", {}), "panneau_danger": (C.panneau_danger, "panneaux", {}),
    "panneau_parking": (C.panneau_parking, "panneaux", {}), "panneau_direction": (C.panneau_direction, "panneaux", {}),
    "panneau_entree": (C.panneau_entree, "panneaux", {}), "borne_km": (C.borne_km, "panneaux", {}),
    "balise": (C.balise, "panneaux", {}), "feu_tricolore": (C.feu_tricolore, "panneaux", {}),
    "poteau_electrique": (C.poteau_electrique, "panneaux", {}), "pylone": (C.pylone, "panneaux", {}),
    # Marché
    "etal_fruits": (L.etal_fruits, "marche", {}), "tente_marche": (L.tente_marche, "marche", {}),
    "parasol": (L.parasol, "marche", {}), "caisses": (L.caisses, "marche", {}),
    "tonneaux": (L.tonneaux, "marche", {}), "charrette": (L.charrette, "marche", {}),
    "stand_glaces": (L.stand_glaces, "marche", {}),
    # Jeux et sport
    "balancoire": (L.balancoire, "jeux", {}), "toboggan": (L.toboggan, "jeux", {}),
    "tourniquet": (L.tourniquet, "jeux", {}), "jeu_ressort": (L.jeu_ressort, "jeux", {}),
    "bac_a_sable": (L.bac_a_sable, "jeux", {}), "cabane_jeux": (L.cabane_jeux, "jeux", {}),
    "cage_foot": (L.cage_foot, "jeux", {}), "panier_basket": (L.panier_basket, "jeux", {}),
    "ping_pong": (L.ping_pong, "jeux", {}),
    # Plage
    "parasol_plage": (L.parasol_plage, "plage", {}), "transat": (L.transat, "plage", {}),
    "cabine_plage": (L.cabine_plage, "plage", {}), "maitre_nageur": (L.maitre_nageur, "plage", {}),
    # Ferme
    "botte_ronde": (F.botte_ronde, "ferme", {}), "botte_enrubannee": (F.botte_enrubannee, "ferme", {}),
    "botte_debout": (F.botte_debout, "ferme", {}), "botte_carree": (F.botte_carree, "ferme", {}),
    "pile_bottes": (F.pile_bottes, "ferme", {}), "meule": (F.meule, "ferme", {}),
    "tracteur": (F.tracteur, "ferme", {}), "tracteur_rouge": (F.tracteur_rouge, "ferme", {}),
    "tracteur_ancien": (F.tracteur_ancien, "ferme", {}), "remorque_foin": (F.remorque_foin, "ferme", {}),
    "moissonneuse": (F.moissonneuse, "ferme", {}), "charrue": (F.charrue, "ferme", {}),
    "abreuvoir": (F.abreuvoir, "ferme", {}), "ratelier": (F.ratelier, "ferme", {}),
    "epouvantail": (F.epouvantail, "ferme", {}), "ruches": (F.ruches, "ferme", {}),
    "tas_bois": (F.tas_bois, "ferme", {}), "grumes": (F.grumes, "ferme", {}),
    "brouette": (F.brouette, "ferme", {}), "puits": (F.puits, "ferme", {}),
    "bidons_lait": (F.bidons_lait, "ferme", {}), "poulailler": (F.poulailler, "ferme", {}),
    "citerne": (F.citerne, "ferme", {}), "silo_grain": (F.silo_grain, "ferme", {}),
    # Cultures
    "citrouilles": (F.citrouilles, "cultures", {}), "choux": (F.choux, "cultures", {}),
    "tomates": (F.tomates, "cultures", {}), "serre_tunnel": (F.serre_tunnel, "cultures", {}),
    "pommier": (F.pommier, "cultures", {}), "vigne_piquets": (F.vigne_piquets, "cultures", {}),
    # Animaux
    "vache_pie_noire": (A.vache_pie_noire, "animaux", {"anime": 1}),
    "vache_broute": (A.vache_broute, "animaux", {"anime": 1}),
    "vache_rousse": (A.vache_rousse, "animaux", {"anime": 1}),
    "vache_broute_rousse": (A.vache_broute_rousse, "animaux", {"anime": 1}),
    "vache_blanche": (A.vache_blanche, "animaux", {"anime": 1}),
    "veau": (A.veau, "animaux", {"anime": 1}), "zebu": (A.zebu, "animaux", {"anime": 1}),
    "yack": (A.yack, "animaux", {"anime": 1}),
    "cheval": (A.cheval, "animaux", {"anime": 1}), "cheval_blanc": (A.cheval_blanc, "animaux", {"anime": 1}),
    "cheval_noir": (A.cheval_noir, "animaux", {"anime": 1}), "poney": (A.poney, "animaux", {"anime": 1}),
    "ane": (A.ane, "animaux", {"anime": 1}),
    "brebis": (A.brebis, "animaux", {"anime": 1}), "mouton_broute": (A.mouton_broute, "animaux", {"anime": 1}),
    "agneau": (A.agneau, "animaux", {"anime": 1}), "chevre": (A.chevre, "animaux", {"anime": 1}),
    "cochon": (A.cochon, "animaux", {"anime": 1}), "poule_blanche": (A.poule_blanche, "animaux", {"anime": 1}),
    "poule_rousse": (A.poule_rousse, "animaux", {"anime": 1}), "canard": (A.canard, "animaux", {"anime": 1}),
    "chien": (A.chien, "animaux", {"anime": 1}), "dromadaire": (A.dromadaire, "animaux", {"anime": 1}),
    "lama": (A.lama, "animaux", {"anime": 1}), "renne": (A.renne, "animaux", {"anime": 1}),
    # Bateaux et pontons
    "barque": (E.barque, "eau", {"eau": 1}), "kayak": (E.kayak, "eau", {"eau": 1}),
    "voilier": (E.voilier, "eau", {"eau": 1}), "voilier_ancre": (E.voilier_ancre, "eau", {"eau": 1}),
    "bateau_peche": (E.bateau_peche, "eau", {"eau": 1}), "bateau_moteur": (E.bateau_moteur, "eau", {"eau": 1}),
    "pedalo": (E.pedalo, "eau", {"eau": 1}), "bouee": (E.bouee, "eau", {"eau": 1}),
    "balise_verte": (E.balise_verte, "eau", {"eau": 1}), "balise_rouge": (E.balise_rouge, "eau", {"eau": 1}),
    "ponton": (E.ponton, "eau", {"berge": 1}), "ponton_court": (E.ponton_court, "eau", {"berge": 1}),
    "bitte": (E.bitte, "eau", {}), "casiers": (E.casiers, "eau", {}), "phare": (E.phare, "eau", {}),
    # Rochers et bois
    "rocher_plat": (R.rocher_plat, "rochers", {}), "rocher_moussu": (R.rocher_moussu, "rochers", {}),
    "bloc_granit": (R.bloc_granit, "rochers", {}), "eboulis": (R.eboulis, "rochers", {}),
    "rochers_cote": (R.rochers_cote, "rochers", {}), "rocher_rouge": (R.rocher_rouge, "rochers", {}),
    "falaise_bloc": (R.falaise_bloc, "rochers", {}), "menhir": (R.menhir, "rochers", {}),
    "dolmen": (R.dolmen, "rochers", {}), "cairn": (R.cairn, "rochers", {}),
    "galets": (R.galets, "rochers", {}), "souche": (R.souche, "rochers", {}),
    "tronc_mort": (R.tronc_mort, "rochers", {}),
}


def nom_affiche(fn):
    doc = (fn.__doc__ or fn.__name__).strip().split("\n")[0]
    return doc.rstrip(".").split(" (")[0] if len(doc) > 40 else doc.rstrip(".")


def planche(objets, chemin, colonnes=8, pas=7.0, noms=None):
    """Décors rangés en grille, chacun agrandi à la même taille, vus de trois quarts."""
    scene = bpy.context.scene
    for o in scene.collection.objects:
        o.hide_render = True
    for i, obj in enumerate(objets):
        obj.hide_render = False
        k = max(obj.dimensions.x, obj.dimensions.y, obj.dimensions.z)
        s = 4.6 / max(k, 0.01)
        obj.scale = (s, s, s)
        obj.rotation_euler = (0, 0, math.radians(-30))
        obj.location = ((i % colonnes) * pas, -(i // colonnes) * pas * 1.45, 0)
    lignes = (len(objets) + colonnes - 1) // colonnes
    cam_data = bpy.data.cameras.new("cam_planche")
    cam_data.type = "ORTHO"
    larg = colonnes * pas
    haut = lignes * pas * 1.45 * 0.574 + 4.5
    cam_data.ortho_scale = max(larg, haut * 4 / 3) * 1.0
    cam = bpy.data.objects.new("cam_planche", cam_data)
    scene.collection.objects.link(cam)
    cx = (colonnes - 1) * pas / 2
    cy = -(lignes - 1) * pas * 1.45 / 2
    a = math.radians(55)
    cam.location = (cx, cy - 100 * math.sin(a), 100 * math.cos(a) + 2.0)
    cam.rotation_euler = (a, 0, 0)
    scene.camera = cam
    monde = bpy.data.worlds.new("fond")
    monde.color = (0.78, 0.82, 0.86)
    scene.world = monde
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "TEXTURE"
    scene.display.shading.show_shadows = False
    scene.display.shading.show_cavity = True
    scene.view_settings.view_transform = "Standard"
    scene.render.resolution_x = 1600
    scene.render.resolution_y = int(1600 * haut / max(larg, haut * 4 / 3)) + 20
    scene.render.filepath = os.path.abspath(chemin)
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(cam)


def main():
    opts = bl.lire_options()
    dossier = os.path.abspath(opts.get("dossier", "assets/modeles/decors"))
    seul = opts.get("seul")
    os.makedirs(dossier, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    palette = base.Palette()
    catalogue = []
    objets = []
    total = 0
    for nom, (fn, cat, o) in DECORS.items():
        if seul and nom != seul:
            continue
        d = base.Decor(palette, nom)
        fn(d)
        obj, tris, dims = base.exporte(d, nom, os.path.join(dossier, nom + ".glb"),
                                       poser=not (o.get("eau") or o.get("berge")))
        total += tris
        print("DECOR %-20s %5d triangles  %.1f x %.1f x %.1f m" % (nom, tris, dims[0], dims[1], dims[2]))
        e = {"id": nom, "nom": nom_affiche(fn), "cat": cat, "triangles": tris,
             "taille": [round(dims[0], 2), round(dims[1], 2), round(dims[2], 2)]}
        e.update(o)
        catalogue.append(e)
        objets.append(obj)
        if seul and opts.get("apercu"):
            bl.apercu(obj, opts["apercu"])
    if not seul:
        with open(os.path.join(dossier, "decors.json"), "w", encoding="utf-8") as f:
            json.dump({"categories": [{"id": i, "nom": n} for i, n in CATEGORIES], "decors": catalogue}, f,
                      ensure_ascii=False, indent=1)
        img = palette.image("palette_decors")
        img.filepath_raw = os.path.join(dossier, "palette_decors.png")
        img.file_format = "PNG"
        img.save()
        lum = palette.image("palette_decors_lumiere", valeurs=base.LUMIERES)
        lum.filepath_raw = os.path.join(dossier, "palette_decors_lumiere.png")
        lum.file_format = "PNG"
        lum.save()
    if opts.get("planche"):
        planche(objets, opts["planche"])
    if opts.get("planches"):
        # Une planche par catégorie : <dossier>/decors-<categorie>.png
        os.makedirs(opts["planches"], exist_ok=True)
        for cid, _n in CATEGORIES:
            objs = [o for o, e in zip(objets, catalogue) if e["cat"] == cid]
            if objs:
                planche(objs, os.path.join(opts["planches"], "decors-%s.png" % cid))
    print("DECORS OK : %d modèles, %d triangles en tout" % (len(catalogue), total))


if __name__ == "__main__":
    main()
