class_name BlocMateriaux
extends RefCounted
## Matériaux de l'éditeur libre et leurs textures, dessinées par le jeu au
## démarrage (aucun fichier image à fournir) : briques, pierre taillée,
## planches, tuiles, ardoise, crépi, parquet, carrelage, tôle, verre…
##
## Chaque matériau a une couche dans un Texture2DArray (64 px par mètre).
## L'ordre de la liste ne doit jamais changer : les sauvegardes gardent l'indice.
## On peut ajouter des matériaux à la fin.

const PX := 64

## fam : famille affichée dans le panneau.
const LIST := [
	{"name": "Brique", "pat": "brique", "c1": "b8573f", "c2": "d9cfc0", "price": 120, "fam": "murs"},
	{"name": "Pierre", "pat": "pierre_taillee", "c1": "9a9a94", "c2": "7d7d78", "price": 150, "fam": "murs"},
	{"name": "Bois", "pat": "grain", "c1": "8a5a36", "c2": "6b4329", "price": 80, "fam": "bois"},
	{"name": "Planches", "pat": "planches_h", "c1": "c9a27e", "c2": "8a6a4a", "price": 70, "fam": "bois"},
	{"name": "Béton", "pat": "beton", "c1": "b9b6ae", "c2": "9a978f", "price": 100, "fam": "murs"},
	{"name": "Enduit blanc", "pat": "enduit", "c1": "f1ece2", "c2": "dcd5c6", "price": 90, "fam": "murs"},
	{"name": "Enduit jaune", "pat": "enduit", "c1": "f2d491", "c2": "dcbc78", "price": 90, "fam": "murs"},
	{"name": "Tuile", "pat": "tuile", "c1": "b5523b", "c2": "8c3b2a", "price": 110, "fam": "toits"},
	{"name": "Ardoise", "pat": "ardoise", "c1": "4f5560", "c2": "3a3f48", "price": 130, "fam": "toits"},
	{"name": "Métal", "pat": "metal", "c1": "7d8590", "c2": "6a717b", "price": 180, "fam": "metal_verre"},
	{"name": "Verre", "pat": "verre", "c1": "9fd3eb", "c2": "e8f6ff", "price": 200, "fam": "metal_verre", "glass": true},
	{"name": "Herbe", "pat": "herbe", "c1": "6aa84f", "c2": "4f8a3a", "price": 20, "fam": "nature"},
	{"name": "Sable", "pat": "sable", "c1": "e6d59c", "c2": "cdbb82", "price": 20, "fam": "nature"},
	{"name": "Feuillage", "pat": "feuillage", "c1": "3f7d3a", "c2": "2c5e2a", "price": 30, "fam": "nature"},
	# --- Ajouts (deuxième version de l'éditeur) ----------------------------------------
	{"name": "Brique claire", "pat": "brique", "c1": "d9b48f", "c2": "efe6d6", "price": 130, "fam": "murs"},
	{"name": "Brique sombre", "pat": "brique", "c1": "6e3b2e", "c2": "a39d92", "price": 130, "fam": "murs"},
	{"name": "Pierre de taille", "pat": "pierre_taillee", "c1": "e3d9c2", "c2": "c9bea5", "price": 220, "fam": "murs"},
	{"name": "Moellons", "pat": "moellons", "c1": "a59d8c", "c2": "d6cfbf", "price": 140, "fam": "murs"},
	{"name": "Granit", "pat": "granit", "c1": "8f8f8f", "c2": "4f4f4f", "price": 240, "fam": "murs"},
	{"name": "Grès rose", "pat": "pierre_taillee", "c1": "c98a73", "c2": "a8705c", "price": 200, "fam": "murs"},
	{"name": "Marbre", "pat": "marbre", "c1": "f2f0eb", "c2": "a9a9b2", "price": 400, "fam": "murs"},
	{"name": "Pavés", "pat": "paves", "c1": "8e8a82", "c2": "5f5c57", "price": 90, "fam": "sols"},
	{"name": "Parpaing", "pat": "parpaing", "c1": "a9a7a0", "c2": "8e8c86", "price": 60, "fam": "murs"},
	{"name": "Béton brut", "pat": "beton_banche", "c1": "9a978f", "c2": "85827b", "price": 110, "fam": "murs"},
	{"name": "Crépi rose", "pat": "enduit", "c1": "e8b8a8", "c2": "d4a090", "price": 90, "fam": "murs"},
	{"name": "Crépi bleu", "pat": "enduit", "c1": "a9c4d9", "c2": "8eaac0", "price": 90, "fam": "murs"},
	{"name": "Crépi vert", "pat": "enduit", "c1": "b7cfa5", "c2": "9cb68a", "price": 90, "fam": "murs"},
	{"name": "Crépi ocre", "pat": "enduit", "c1": "d9a066", "c2": "c08850", "price": 90, "fam": "murs"},
	{"name": "Colombage", "pat": "colombage", "c1": "f3ead8", "c2": "4a3222", "price": 160, "fam": "murs"},
	{"name": "Torchis", "pat": "torchis", "c1": "cdb48a", "c2": "a88f62", "price": 50, "fam": "murs"},
	{"name": "Terre crue", "pat": "terre", "c1": "b07d4a", "c2": "8f6238", "price": 40, "fam": "murs"},
	{"name": "Rondins", "pat": "rondins", "c1": "8a5a36", "c2": "5a3a22", "price": 100, "fam": "bois"},
	{"name": "Bardage bois", "pat": "planches_v", "c1": "9a744f", "c2": "6b4a33", "price": 90, "fam": "bois"},
	{"name": "Bardage gris", "pat": "planches_h", "c1": "8e9196", "c2": "6a6d72", "price": 90, "fam": "bois"},
	{"name": "Bardage rouge", "pat": "planches_v", "c1": "9b2c2c", "c2": "6e1f1f", "price": 90, "fam": "bois"},
	{"name": "Parquet chêne", "pat": "parquet", "c1": "c79a63", "c2": "a67c4a", "price": 110, "fam": "sols"},
	{"name": "Parquet foncé", "pat": "parquet", "c1": "6b4a33", "c2": "4f3424", "price": 120, "fam": "sols"},
	{"name": "Carrelage blanc", "pat": "carrelage", "c1": "f2f2ee", "c2": "c8c8c2", "price": 100, "fam": "sols"},
	{"name": "Damier", "pat": "damier", "c1": "f2f2ee", "c2": "2a2a2a", "price": 110, "fam": "sols"},
	{"name": "Tomettes", "pat": "tomettes", "c1": "b5523b", "c2": "d9cbb3", "price": 100, "fam": "sols"},
	{"name": "Moquette", "pat": "moquette", "c1": "8e3b46", "c2": "742f39", "price": 60, "fam": "sols"},
	{"name": "Tuile plate", "pat": "tuile_plate", "c1": "9b4a32", "c2": "7a3826", "price": 120, "fam": "toits"},
	{"name": "Tuile vernissée", "pat": "tuile", "c1": "3f7d4f", "c2": "2c5e3a", "price": 160, "fam": "toits"},
	{"name": "Bardeaux", "pat": "tuile_plate", "c1": "7a5a3e", "c2": "5a3f2a", "price": 90, "fam": "toits"},
	{"name": "Chaume", "pat": "chaume", "c1": "b39a5e", "c2": "8a7444", "price": 60, "fam": "toits"},
	{"name": "Tôle ondulée", "pat": "tole", "c1": "9aa3ad", "c2": "7d8590", "price": 70, "fam": "toits"},
	{"name": "Zinc", "pat": "zinc", "c1": "7f8a94", "c2": "5f6a74", "price": 150, "fam": "toits"},
	{"name": "Cuivre", "pat": "cuivre", "c1": "b87333", "c2": "5fae9a", "price": 300, "fam": "metal_verre"},
	{"name": "Or", "pat": "metal", "c1": "d9a520", "c2": "b8891a", "price": 900, "fam": "metal_verre"},
	{"name": "Bambou", "pat": "bambou", "c1": "c8b06a", "c2": "8f7a3e", "price": 50, "fam": "bois"},
	{"name": "Verre fumé", "pat": "verre", "c1": "4a5a66", "c2": "8a9aa6", "price": 220, "fam": "metal_verre", "glass": true},
	{"name": "Vitrail", "pat": "vitrail", "c1": "2a2a2a", "c2": "ffffff", "price": 350, "fam": "metal_verre", "glass": true},
	{"name": "Gravier", "pat": "gravier", "c1": "a8a297", "c2": "77726a", "price": 15, "fam": "nature"},
	{"name": "Terre", "pat": "terre", "c1": "6b4f35", "c2": "57402b", "price": 10, "fam": "nature"},
	{"name": "Neige", "pat": "neige", "c1": "f4f8fb", "c2": "dde7ee", "price": 10, "fam": "nature"},
	{"name": "Plâtre", "pat": "uni", "c1": "f7f5f0", "c2": "ebe7df", "price": 70, "fam": "murs"},
	{"name": "Fer forgé", "pat": "metal", "c1": "2f3236", "c2": "1e2023", "price": 160, "fam": "metal_verre"},
	{"name": "Bois peint blanc", "pat": "planches_h", "c1": "f2f0ea", "c2": "cfccc4", "price": 90, "fam": "bois"},
	# --- Ajouts (troisième version de l'atelier) -----------------------------------------
	{"name": "Brique flamande", "pat": "flamand", "c1": "a9472f", "c2": "d6ccbb", "price": 140, "fam": "murs"},
	{"name": "Brique anglaise", "pat": "anglais", "c1": "9c4632", "c2": "cfc6b6", "price": 140, "fam": "murs"},
	{"name": "Brique joints alignés", "pat": "joints_alignes", "c1": "7a4a3a", "c2": "3a3532", "price": 130, "fam": "murs"},
	{"name": "Brique jaune", "pat": "brique", "c1": "dcc07e", "c2": "efe8d8", "price": 130, "fam": "murs"},
	{"name": "Brique vernissée", "pat": "brique_vernie", "c1": "2f5d8a", "c2": "e8e4da", "price": 220, "fam": "murs"},
	{"name": "Calcaire", "pat": "pierre_taillee", "c1": "ddd3bc", "c2": "c4b99f", "price": 200, "fam": "murs"},
	{"name": "Pierre bleue", "pat": "pierre_taillee", "c1": "5f6872", "c2": "4a525b", "price": 230, "fam": "murs"},
	{"name": "Meulière", "pat": "meuliere", "c1": "c79a5e", "c2": "e9dfc8", "price": 170, "fam": "murs"},
	{"name": "Opus incertum", "pat": "opus", "c1": "b3a68f", "c2": "e0d8c6", "price": 150, "fam": "murs"},
	{"name": "Travertin", "pat": "travertin", "c1": "e6d8bb", "c2": "c8b48e", "price": 260, "fam": "murs"},
	{"name": "Basalte", "pat": "granit", "c1": "3d3f42", "c2": "1f2022", "price": 240, "fam": "murs"},
	{"name": "Pisé", "pat": "pise", "c1": "b98d5e", "c2": "9c7348", "price": 60, "fam": "murs"},
	{"name": "Béton blanc", "pat": "beton", "c1": "e8e6e0", "c2": "cfccc4", "price": 120, "fam": "murs"},
	{"name": "Crépi terracotta", "pat": "enduit", "c1": "c3653f", "c2": "a8522f", "price": 90, "fam": "murs"},
	{"name": "Crépi gris", "pat": "enduit", "c1": "aaa9a3", "c2": "93928c", "price": 90, "fam": "murs"},
	{"name": "Crépi lavande", "pat": "enduit", "c1": "b9a9cf", "c2": "a090b8", "price": 90, "fam": "murs"},
	{"name": "Enduit à la chaux", "pat": "chaux", "c1": "f3ecdc", "c2": "ddd2bb", "price": 100, "fam": "murs"},
	{"name": "Stuc vénitien", "pat": "marbre", "c1": "e9d3b8", "c2": "c9a888", "price": 300, "fam": "murs"},
	{"name": "Zellige", "pat": "zellige", "c1": "2c7a6a", "c2": "e8e4da", "price": 260, "fam": "murs"},
	{"name": "Bois brûlé", "pat": "bois_brule", "c1": "2a2624", "c2": "15120f", "price": 120, "fam": "bois"},
	{"name": "Mélèze", "pat": "planches_v", "c1": "d3a46d", "c2": "a97c4c", "price": 100, "fam": "bois"},
	{"name": "Bardage vert", "pat": "planches_v", "c1": "4c6e51", "c2": "36513b", "price": 90, "fam": "bois"},
	{"name": "Bardage bleu", "pat": "planches_h", "c1": "44627f", "c2": "30485f", "price": 90, "fam": "bois"},
	{"name": "Bois exotique", "pat": "planches_h", "c1": "7c3b24", "c2": "5a2a18", "price": 140, "fam": "bois"},
	{"name": "Contreplaqué", "pat": "contreplaque", "c1": "d4b07a", "c2": "b38e58", "price": 60, "fam": "bois"},
	{"name": "Rotin", "pat": "vannerie", "c1": "c9a66b", "c2": "8f6e3c", "price": 80, "fam": "bois"},
	{"name": "Bardeaux de cèdre", "pat": "bardeaux", "c1": "a8683e", "c2": "7a4a2a", "price": 120, "fam": "toits"},
	{"name": "Lauzes", "pat": "lauze", "c1": "8a8780", "c2": "5e5b55", "price": 180, "fam": "toits"},
	{"name": "Tuile canal", "pat": "tuile_canal", "c1": "c46a45", "c2": "93452c", "price": 120, "fam": "toits"},
	{"name": "Ardoise en écailles", "pat": "ecailles", "c1": "535a66", "c2": "353a42", "price": 160, "fam": "toits"},
	{"name": "Zinc joints debout", "pat": "joints_debout", "c1": "8a949c", "c2": "6c767e", "price": 170, "fam": "toits"},
	{"name": "Tuile noire", "pat": "tuile", "c1": "34363b", "c2": "1f2024", "price": 150, "fam": "toits"},
	{"name": "Tuile bleue", "pat": "tuile", "c1": "3b5c8c", "c2": "2a4268", "price": 160, "fam": "toits"},
	{"name": "Fibrociment", "pat": "fibrociment", "c1": "a5a7a2", "c2": "8b8d88", "price": 60, "fam": "toits"},
	{"name": "Bac acier", "pat": "bac_acier", "c1": "4a4f55", "c2": "363a3f", "price": 90, "fam": "toits"},
	{"name": "Toit végétal", "pat": "vegetal", "c1": "7d9a4a", "c2": "b3574a", "price": 150, "fam": "toits"},
	{"name": "Terrazzo", "pat": "terrazzo", "c1": "e7e2d8", "c2": "8a7f72", "price": 180, "fam": "sols"},
	{"name": "Carreaux de ciment", "pat": "carreaux_ciment", "c1": "e9e3d6", "c2": "2f5d6e", "price": 170, "fam": "sols"},
	{"name": "Mosaïque", "pat": "mosaique", "c1": "3a8fc2", "c2": "e8f2f7", "price": 200, "fam": "sols"},
	{"name": "Parquet en chevrons", "pat": "chevrons", "c1": "b98a55", "c2": "8f6436", "price": 160, "fam": "sols"},
	{"name": "Dalles de pierre", "pat": "dalles", "c1": "b9b2a4", "c2": "8d877b", "price": 140, "fam": "sols"},
	{"name": "Pavés autobloquants", "pat": "autobloquant", "c1": "9a8f86", "c2": "6c645e", "price": 70, "fam": "sols"},
	{"name": "Enrobé", "pat": "enrobe", "c1": "3c3d40", "c2": "55565a", "price": 40, "fam": "sols"},
	{"name": "Tatami", "pat": "tatami", "c1": "c9c28a", "c2": "5a6a3a", "price": 120, "fam": "sols"},
	{"name": "Sol souple", "pat": "uni", "c1": "6b8fa8", "c2": "5f839c", "price": 60, "fam": "sols"},
	{"name": "Moquette grise", "pat": "moquette", "c1": "7b8088", "c2": "6a6f77", "price": 60, "fam": "sols"},
	{"name": "Acier Corten", "pat": "corten", "c1": "8f4a26", "c2": "5e2e16", "price": 260, "fam": "metal_verre"},
	{"name": "Aluminium", "pat": "panneaux", "c1": "c2c7cc", "c2": "9aa0a6", "price": 200, "fam": "metal_verre"},
	{"name": "Laiton", "pat": "metal", "c1": "c9a24a", "c2": "a8862f", "price": 400, "fam": "metal_verre"},
	{"name": "Pavés de verre", "pat": "pave_verre", "c1": "b8dbe8", "c2": "eef8fc", "price": 250, "fam": "metal_verre", "glass": true},
	{"name": "Verre dépoli", "pat": "verre_depoli", "c1": "e6eef2", "c2": "f8fbfc", "price": 230, "fam": "metal_verre", "glass": true},
	{"name": "Eau", "pat": "eau", "c1": "2f7fb0", "c2": "8fd0ea", "price": 30, "fam": "nature", "glass": true},
	{"name": "Glace", "pat": "verre", "c1": "cfe9f5", "c2": "f4fbff", "price": 30, "fam": "nature", "glass": true},
	{"name": "Roche", "pat": "moellons", "c1": "7d746a", "c2": "5a534b", "price": 60, "fam": "nature"},
	{"name": "Toile blanche", "pat": "toile", "c1": "f1eee6", "c2": "d8d3c6", "price": 40, "fam": "decor"},
	{"name": "Toile rayée", "pat": "rayures", "c1": "c8463d", "c2": "f1eee6", "price": 50, "fam": "decor"},
	{"name": "Feutre", "pat": "moquette", "c1": "4a5d3f", "c2": "3e4f35", "price": 50, "fam": "decor"},
	{"name": "Cuir", "pat": "cuir", "c1": "7a4a2c", "c2": "5e3820", "price": 120, "fam": "decor"},
	{"name": "Crépi blanc cassé", "pat": "enduit", "c1": "ede6d6", "c2": "d8cfbc", "price": 90, "fam": "murs"},
	{"name": "Crépi saumon", "pat": "enduit", "c1": "e9a58a", "c2": "d38f74", "price": 90, "fam": "murs"},
	{"name": "Crépi pêche", "pat": "enduit", "c1": "f2c6a0", "c2": "dcae88", "price": 90, "fam": "murs"},
	{"name": "Crépi abricot", "pat": "enduit", "c1": "e8a35a", "c2": "d08b44", "price": 90, "fam": "murs"},
	{"name": "Crépi menthe", "pat": "enduit", "c1": "bfe0c8", "c2": "a6c9b0", "price": 90, "fam": "murs"},
	{"name": "Crépi sauge", "pat": "enduit", "c1": "a9b79a", "c2": "939f84", "price": 90, "fam": "murs"},
	{"name": "Crépi azur", "pat": "enduit", "c1": "8fb8de", "c2": "789fc4", "price": 90, "fam": "murs"},
	{"name": "Crépi lilas", "pat": "enduit", "c1": "c8b0d8", "c2": "b098c0", "price": 90, "fam": "murs"},
	{"name": "Crépi vieux rose", "pat": "enduit", "c1": "c99098", "c2": "b07880", "price": 90, "fam": "murs"},
	{"name": "Crépi sable", "pat": "enduit", "c1": "dccaa4", "c2": "c4b08a", "price": 90, "fam": "murs"},
	{"name": "Crépi ivoire", "pat": "enduit", "c1": "f4ecd2", "c2": "ddd3b8", "price": 90, "fam": "murs"},
	{"name": "Crépi anthracite", "pat": "enduit", "c1": "4c4f54", "c2": "3c3f44", "price": 90, "fam": "murs"},
	{"name": "Crépi jaune de Naples", "pat": "enduit", "c1": "f0d27a", "c2": "d8b862", "price": 90, "fam": "murs"},
	{"name": "Crépi bleu nuit", "pat": "enduit", "c1": "2f3f66", "c2": "263353", "price": 90, "fam": "murs"},
	{"name": "Crépi vert olive", "pat": "enduit", "c1": "8a8a4a", "c2": "747438", "price": 90, "fam": "murs"},
	{"name": "Crépi rouge pompéien", "pat": "enduit", "c1": "a8473a", "c2": "8e3a2f", "price": 90, "fam": "murs"},
	{"name": "Brique rouge vif", "pat": "brique", "c1": "c0392b", "c2": "ddd2c2", "price": 130, "fam": "murs"},
	{"name": "Brique orangée", "pat": "brique", "c1": "d27a45", "c2": "e8dccb", "price": 130, "fam": "murs"},
	{"name": "Brique brune", "pat": "brique", "c1": "6a4232", "c2": "a69e92", "price": 130, "fam": "murs"},
	{"name": "Brique noire", "pat": "brique", "c1": "2f2c2c", "c2": "8a8580", "price": 150, "fam": "murs"},
	{"name": "Brique peinte blanche", "pat": "brique", "c1": "efede6", "c2": "d3d0c8", "price": 140, "fam": "murs"},
	{"name": "Brique vernissée verte", "pat": "brique_vernie", "c1": "2f7a52", "c2": "e8e4da", "price": 220, "fam": "murs"},
	{"name": "Brique de Chine grise", "pat": "brique", "c1": "7d8085", "c2": "b8b6b0", "price": 130, "fam": "murs"},
	{"name": "Brique flamande sombre", "pat": "flamand", "c1": "5e3226", "c2": "bdb3a3", "price": 150, "fam": "murs"},
	{"name": "Grès des Vosges", "pat": "pierre_taillee", "c1": "b1584a", "c2": "974639", "price": 220, "fam": "murs"},
	{"name": "Granit rose", "pat": "granit", "c1": "c99a8f", "c2": "6e4d48", "price": 260, "fam": "murs"},
	{"name": "Pierre de Bourgogne", "pat": "pierre_taillee", "c1": "e2d6b5", "c2": "c9bb96", "price": 220, "fam": "murs"},
	{"name": "Tuffeau", "pat": "pierre_taillee", "c1": "f0e8d2", "c2": "d9cfb4", "price": 210, "fam": "murs"},
	{"name": "Pierre volcanique", "pat": "meuliere", "c1": "4a4644", "c2": "6a6460", "price": 200, "fam": "murs"},
	{"name": "Quartzite", "pat": "pierre_taillee", "c1": "d9d4cc", "c2": "b9b3aa", "price": 230, "fam": "murs"},
	{"name": "Schiste", "pat": "lauze", "c1": "5c5a55", "c2": "3e3c38", "price": 170, "fam": "murs"},
	{"name": "Silex", "pat": "opus", "c1": "3c3a3a", "c2": "d9d3c4", "price": 160, "fam": "murs"},
	{"name": "Galets", "pat": "moellons", "c1": "bdb4a6", "c2": "8c8378", "price": 120, "fam": "murs"},
	{"name": "Pierre sèche", "pat": "opus", "c1": "9a8f7c", "c2": "5d564a", "price": 110, "fam": "murs"},
	{"name": "Béton rouge", "pat": "beton", "c1": "a2513f", "c2": "8a4232", "price": 120, "fam": "murs"},
	{"name": "Béton matricé", "pat": "beton_banche", "c1": "b0aca2", "c2": "8f8b82", "price": 130, "fam": "murs"},
	{"name": "Béton ciré gris", "pat": "chaux", "c1": "9c9a96", "c2": "8a8884", "price": 140, "fam": "murs"},
	{"name": "Béton sablé", "pat": "terrazzo", "c1": "c4bfb4", "c2": "8a8478", "price": 130, "fam": "murs"},
	{"name": "Enduit rose de chaux", "pat": "chaux", "c1": "eac6bb", "c2": "d6aea2", "price": 100, "fam": "murs"},
	{"name": "Enduit ocre jaune", "pat": "chaux", "c1": "e2b25e", "c2": "c99a48", "price": 100, "fam": "murs"},
	{"name": "Pierre meulière claire", "pat": "meuliere", "c1": "dcc39a", "c2": "f2e9d6", "price": 170, "fam": "murs"},
	{"name": "Pierre de taille grise", "pat": "pierre_taillee", "c1": "b8b8b2", "c2": "9e9e98", "price": 210, "fam": "murs"},
	{"name": "Moellons ocre", "pat": "moellons", "c1": "c49a62", "c2": "e2d4bc", "price": 140, "fam": "murs"},
	{"name": "Colombage rouge", "pat": "colombage", "c1": "f1e4cc", "c2": "8a2f22", "price": 170, "fam": "murs"},
	{"name": "Colombage bleu", "pat": "colombage", "c1": "eef0f2", "c2": "2f4a6e", "price": 170, "fam": "murs"},
	{"name": "Tuile romane", "pat": "tuile_canal", "c1": "b85a3a", "c2": "8e4228", "price": 120, "fam": "toits"},
	{"name": "Tuile mécanique", "pat": "tuile_plate", "c1": "a84f35", "c2": "7e3a26", "price": 110, "fam": "toits"},
	{"name": "Tuile provençale", "pat": "tuile_canal", "c1": "d08a5a", "c2": "a5653a", "price": 125, "fam": "toits"},
	{"name": "Tuile vernissée jaune", "pat": "tuile", "c1": "e2b42c", "c2": "b88a18", "price": 170, "fam": "toits"},
	{"name": "Tuile vernissée turquoise", "pat": "tuile", "c1": "2a9a9a", "c2": "1f7676", "price": 170, "fam": "toits"},
	{"name": "Tuile verte japonaise", "pat": "tuile", "c1": "4f6e4a", "c2": "354d32", "price": 170, "fam": "toits"},
	{"name": "Ardoise verte", "pat": "ardoise", "c1": "4c5c50", "c2": "374238", "price": 140, "fam": "toits"},
	{"name": "Cuivre neuf", "pat": "cuivre", "c1": "c4783a", "c2": "b06a30", "price": 320, "fam": "toits"},
	{"name": "Zinc noir", "pat": "joints_debout", "c1": "3a3d42", "c2": "2a2c30", "price": 170, "fam": "toits"},
	{"name": "Chaume de palme", "pat": "chaume", "c1": "9a8a4a", "c2": "6e6232", "price": 60, "fam": "toits"},
	{"name": "Chaume de roseau", "pat": "chaume", "c1": "c0a86a", "c2": "8f7a44", "price": 70, "fam": "toits"},
	{"name": "Membrane EPDM", "pat": "enrobe", "c1": "2d2e30", "c2": "3a3b3e", "price": 60, "fam": "toits"},
	{"name": "Gravillons de toiture", "pat": "gravier", "c1": "a9a59c", "c2": "7a766e", "price": 40, "fam": "toits"},
	{"name": "Bardeaux bitumés rouges", "pat": "bardeaux", "c1": "8a3a32", "c2": "5e2620", "price": 70, "fam": "toits"},
	{"name": "Bardeaux bitumés verts", "pat": "bardeaux", "c1": "4a5e44", "c2": "34442f", "price": 70, "fam": "toits"},
	{"name": "Lauzes calcaires", "pat": "lauze", "c1": "c9c0ad", "c2": "9d9583", "price": 190, "fam": "toits"},
	{"name": "Tôle rouge", "pat": "tole", "c1": "a8392f", "c2": "8a2c24", "price": 80, "fam": "toits"},
	{"name": "Tôle verte", "pat": "tole", "c1": "3f6b48", "c2": "2f5236", "price": 80, "fam": "toits"},
	{"name": "Tôle bleue", "pat": "tole", "c1": "3a5e8c", "c2": "2c4a70", "price": 80, "fam": "toits"},
	{"name": "Tôle rouillée", "pat": "corten", "c1": "8a4a2a", "c2": "5a2e18", "price": 60, "fam": "toits"},
	{"name": "Marbre de Carrare", "pat": "marbre", "c1": "f4f3ef", "c2": "9fa3ab", "price": 420, "fam": "sols"},
	{"name": "Marbre noir", "pat": "marbre", "c1": "222326", "c2": "c9c9c9", "price": 450, "fam": "sols"},
	{"name": "Marbre vert", "pat": "marbre", "c1": "3f6e56", "c2": "d6e2da", "price": 450, "fam": "sols"},
	{"name": "Marbre rose", "pat": "marbre", "c1": "e2b8ae", "c2": "b88a80", "price": 440, "fam": "sols"},
	{"name": "Granito", "pat": "terrazzo", "c1": "d9d4ca", "c2": "5f5850", "price": 180, "fam": "sols"},
	{"name": "Parquet d'érable", "pat": "parquet", "c1": "e2c69a", "c2": "c4a678", "price": 120, "fam": "sols"},
	{"name": "Parquet de noyer", "pat": "parquet", "c1": "6a4630", "c2": "50331f", "price": 140, "fam": "sols"},
	{"name": "Parquet de teck", "pat": "parquet", "c1": "a6703f", "c2": "82542c", "price": 150, "fam": "sols"},
	{"name": "Parquet de pin", "pat": "parquet", "c1": "e0b77c", "c2": "c0975c", "price": 90, "fam": "sols"},
	{"name": "Point de Hongrie", "pat": "chevrons", "c1": "9c6c3e", "c2": "6e4a28", "price": 170, "fam": "sols"},
	{"name": "Carrelage noir", "pat": "carrelage", "c1": "2c2c2e", "c2": "5a5a5c", "price": 100, "fam": "sols"},
	{"name": "Carrelage bleu", "pat": "carrelage", "c1": "3c6e9e", "c2": "e8eef2", "price": 100, "fam": "sols"},
	{"name": "Carrelage vert", "pat": "carrelage", "c1": "4f8a64", "c2": "e8eee8", "price": 100, "fam": "sols"},
	{"name": "Carrelage rose", "pat": "carrelage", "c1": "e2a9b4", "c2": "f2e6e8", "price": 100, "fam": "sols"},
	{"name": "Carrelage gris", "pat": "carrelage", "c1": "9a9c9e", "c2": "c8cacc", "price": 100, "fam": "sols"},
	{"name": "Tomettes hexagonales", "pat": "hexagones", "c1": "b5523b", "c2": "d9cbb3", "price": 110, "fam": "sols"},
	{"name": "Carreaux hexagonaux blancs", "pat": "hexagones", "c1": "f0eee8", "c2": "9a9a96", "price": 110, "fam": "sols"},
	{"name": "Moquette bleue", "pat": "moquette", "c1": "3a527e", "c2": "2e4268", "price": 60, "fam": "sols"},
	{"name": "Moquette verte", "pat": "moquette", "c1": "4f6e4a", "c2": "3f5a3a", "price": 60, "fam": "sols"},
	{"name": "Moquette beige", "pat": "moquette", "c1": "c9b896", "c2": "b5a482", "price": 60, "fam": "sols"},
	{"name": "Lino damier rouge", "pat": "damier", "c1": "b8352c", "c2": "f0ebe0", "price": 70, "fam": "sols"},
	{"name": "Caillebotis", "pat": "caillebotis", "c1": "9a7450", "c2": "1e1a16", "price": 80, "fam": "sols"},
	{"name": "Pavés de porphyre", "pat": "paves", "c1": "7a4a44", "c2": "4e2e2a", "price": 120, "fam": "sols"},
	{"name": "Pavés de granit", "pat": "paves", "c1": "9a9894", "c2": "6a6864", "price": 110, "fam": "sols"},
	{"name": "Calade", "pat": "moellons", "c1": "b0a690", "c2": "7a7262", "price": 100, "fam": "sols"},
	{"name": "Dalles de béton", "pat": "dalles", "c1": "b4b2ac", "c2": "8c8a84", "price": 70, "fam": "sols"},
	{"name": "Dalles de grès", "pat": "dalles", "c1": "c99a7a", "c2": "9e7458", "price": 120, "fam": "sols"},
	{"name": "Tapis persan", "pat": "tapis", "c1": "8a2a2a", "c2": "e2c48a", "price": 200, "fam": "sols"},
	{"name": "Tapis bleu", "pat": "tapis", "c1": "2e4a7e", "c2": "e2d6b0", "price": 200, "fam": "sols"},
	{"name": "Plancher brut", "pat": "planches_h", "c1": "b08a62", "c2": "7a5a3c", "price": 60, "fam": "sols"},
	{"name": "Planches bleues", "pat": "planches_h", "c1": "4f7fae", "c2": "3a6390", "price": 90, "fam": "bois"},
	{"name": "Planches vertes", "pat": "planches_h", "c1": "5e8a5a", "c2": "48704a", "price": 90, "fam": "bois"},
	{"name": "Planches jaunes", "pat": "planches_h", "c1": "e6c25a", "c2": "c4a040", "price": 90, "fam": "bois"},
	{"name": "Planches rouges", "pat": "planches_h", "c1": "b8443a", "c2": "94352c", "price": 90, "fam": "bois"},
	{"name": "Planches noires", "pat": "planches_h", "c1": "2e2c2a", "c2": "1c1a18", "price": 90, "fam": "bois"},
	{"name": "Bois flotté", "pat": "planches_h", "c1": "b9b2a6", "c2": "8e877c", "price": 80, "fam": "bois"},
	{"name": "Palissade", "pat": "planches_v", "c1": "8a6440", "c2": "5e4228", "price": 70, "fam": "bois"},
	{"name": "Lambris de pin", "pat": "planches_v", "c1": "e2bc84", "c2": "c09a62", "price": 80, "fam": "bois"},
	{"name": "Teck", "pat": "grain", "c1": "a6703f", "c2": "82542c", "price": 150, "fam": "bois"},
	{"name": "Bambou noir", "pat": "bambou", "c1": "3a3630", "c2": "1e1c18", "price": 70, "fam": "bois"},
	{"name": "Osier", "pat": "vannerie", "c1": "c8a670", "c2": "8f7040", "price": 80, "fam": "bois"},
	{"name": "Liège", "pat": "liege", "c1": "b98e5e", "c2": "8a6440", "price": 90, "fam": "bois"},
	{"name": "Écorce", "pat": "ecorce", "c1": "5e4430", "c2": "3a2a1c", "price": 50, "fam": "bois"},
	{"name": "Rondins écorcés", "pat": "rondins", "c1": "c09a6a", "c2": "7a5a3a", "price": 110, "fam": "bois"},
	{"name": "Bois laqué vert", "pat": "laque", "c1": "2f5e46", "c2": "1f4232", "price": 180, "fam": "bois"},
	{"name": "Acier galvanisé", "pat": "metal", "c1": "a9b0b6", "c2": "8e959c", "price": 160, "fam": "metal_verre"},
	{"name": "Inox", "pat": "metal", "c1": "d2d6da", "c2": "b6bbc0", "price": 260, "fam": "metal_verre"},
	{"name": "Acier noir", "pat": "metal", "c1": "34373b", "c2": "222427", "price": 180, "fam": "metal_verre"},
	{"name": "Tôle perforée", "pat": "pois", "c1": "8e959c", "c2": "2a2c30", "price": 170, "fam": "metal_verre"},
	{"name": "Grillage", "pat": "grillage", "c1": "5a5e62", "c2": "9a9ea2", "price": 60, "fam": "metal_verre", "glass": true},
	{"name": "Métal déployé", "pat": "losanges", "c1": "7c8288", "c2": "3e4246", "price": 150, "fam": "metal_verre"},
	{"name": "Bronze patiné", "pat": "cuivre", "c1": "7a5a32", "c2": "4f8a74", "price": 320, "fam": "metal_verre"},
	{"name": "Chrome", "pat": "metal", "c1": "e6e9ec", "c2": "c4c8cc", "price": 300, "fam": "metal_verre"},
	{"name": "Verre bleu", "pat": "verre", "c1": "4a7fb8", "c2": "b8d8f0", "price": 230, "fam": "metal_verre", "glass": true},
	{"name": "Verre vert", "pat": "verre", "c1": "4a9a6e", "c2": "c0eed4", "price": 230, "fam": "metal_verre", "glass": true},
	{"name": "Verre ambré", "pat": "verre", "c1": "c88a2a", "c2": "f0d090", "price": 230, "fam": "metal_verre", "glass": true},
	{"name": "Verre miroir", "pat": "verre", "c1": "b8c2cc", "c2": "f2f6fa", "price": 260, "fam": "metal_verre", "glass": true},
	{"name": "Vitrail bleu", "pat": "vitrail", "c1": "1a1a2a", "c2": "88aaff", "price": 360, "fam": "metal_verre", "glass": true},
	{"name": "Polycarbonate", "pat": "planches_v", "c1": "d8e8f0", "c2": "b8ccd8", "price": 120, "fam": "metal_verre", "glass": true},
	{"name": "Laiton brossé", "pat": "metal", "c1": "c9a65a", "c2": "a8883c", "price": 380, "fam": "metal_verre"},
	{"name": "Herbe sèche", "pat": "herbe", "c1": "b5a85a", "c2": "8f8442", "price": 15, "fam": "nature"},
	{"name": "Prairie fleurie", "pat": "vegetal", "c1": "6e9a48", "c2": "d86a8a", "price": 25, "fam": "nature"},
	{"name": "Mousse", "pat": "feuillage", "c1": "5e7a3a", "c2": "455e2a", "price": 20, "fam": "nature"},
	{"name": "Boue", "pat": "boue", "c1": "5a4632", "c2": "3a2c20", "price": 10, "fam": "nature"},
	{"name": "Terre rouge", "pat": "terre", "c1": "a4532f", "c2": "8a4426", "price": 10, "fam": "nature"},
	{"name": "Sable blanc", "pat": "sable", "c1": "f2ecd8", "c2": "dcd4bc", "price": 20, "fam": "nature"},
	{"name": "Sable noir", "pat": "sable", "c1": "3a3836", "c2": "2a2826", "price": 20, "fam": "nature"},
	{"name": "Galets de rivière", "pat": "moellons", "c1": "a8a49c", "c2": "6e6a64", "price": 30, "fam": "nature"},
	{"name": "Rocher en strates", "pat": "strates", "c1": "b8a688", "c2": "8a7a62", "price": 50, "fam": "nature"},
	{"name": "Rocher rouge", "pat": "strates", "c1": "b0583a", "c2": "7e3c26", "price": 50, "fam": "nature"},
	{"name": "Falaise calcaire", "pat": "strates", "c1": "e4dcc8", "c2": "b8ae98", "price": 50, "fam": "nature"},
	{"name": "Lave refroidie", "pat": "granit", "c1": "2a2624", "c2": "8a2a1a", "price": 40, "fam": "nature"},
	{"name": "Paille", "pat": "chaume", "c1": "e2c878", "c2": "b89e50", "price": 15, "fam": "nature"},
	{"name": "Feuilles mortes", "pat": "feuillage", "c1": "a8682a", "c2": "7a4a1c", "price": 15, "fam": "nature"},
	{"name": "Glace bleue", "pat": "verre", "c1": "8ec8e8", "c2": "d8f0fc", "price": 30, "fam": "nature", "glass": true},
	{"name": "Adobe", "pat": "terre", "c1": "c4946a", "c2": "a87a52", "price": 40, "fam": "monde"},
	{"name": "Banco", "pat": "torchis", "c1": "a8784a", "c2": "806040", "price": 40, "fam": "monde"},
	{"name": "Tadelakt", "pat": "chaux", "c1": "d9a37a", "c2": "c08a62", "price": 160, "fam": "monde"},
	{"name": "Zellige bleu", "pat": "zellige", "c1": "2a5e9a", "c2": "e8e4da", "price": 260, "fam": "monde"},
	{"name": "Zellige blanc", "pat": "zellige", "c1": "eae6dc", "c2": "a8b0b8", "price": 260, "fam": "monde"},
	{"name": "Zellige jaune", "pat": "zellige", "c1": "e2b02a", "c2": "e8e4da", "price": 260, "fam": "monde"},
	{"name": "Azulejos bleus", "pat": "azulejos", "c1": "f2f2ee", "c2": "2a4e9a", "price": 240, "fam": "monde"},
	{"name": "Azulejos jaunes", "pat": "azulejos", "c1": "f2eee0", "c2": "d0901a", "price": 240, "fam": "monde"},
	{"name": "Laque rouge", "pat": "laque", "c1": "b0281e", "c2": "8a1c14", "price": 200, "fam": "monde"},
	{"name": "Laque noire", "pat": "laque", "c1": "1e1c1c", "c2": "3a3434", "price": 200, "fam": "monde"},
	{"name": "Papier shoji", "pat": "shoji", "c1": "f4efe2", "c2": "6a5236", "price": 80, "fam": "monde", "glass": true},
	{"name": "Bambou tressé", "pat": "vannerie", "c1": "d6c088", "c2": "a08a52", "price": 60, "fam": "monde"},
	{"name": "Natte de palme", "pat": "vannerie", "c1": "b8a060", "c2": "7e6a38", "price": 50, "fam": "monde"},
	{"name": "Corail", "pat": "meuliere", "c1": "e8dcc4", "c2": "c4b494", "price": 120, "fam": "monde"},
	{"name": "Pierre de Jérusalem", "pat": "pierre_taillee", "c1": "e9d9b4", "c2": "d0bf98", "price": 230, "fam": "monde"},
	{"name": "Latérite", "pat": "moellons", "c1": "b0603a", "c2": "7e4228", "price": 80, "fam": "monde"},
	{"name": "Céramique persane", "pat": "mosaique", "c1": "1f8aa8", "c2": "f2f0e8", "price": 280, "fam": "monde"},
	{"name": "Mosaïque d'or", "pat": "mosaique", "c1": "d8a832", "c2": "f6e6a8", "price": 500, "fam": "monde"},
	{"name": "Marbre incrusté", "pat": "marbre", "c1": "f6f4ee", "c2": "3a6e8a", "price": 500, "fam": "monde"},
	{"name": "Enduit indigo", "pat": "enduit", "c1": "3a5aa8", "c2": "2e4a8e", "price": 100, "fam": "monde"},
	{"name": "Enduit rose de Jaipur", "pat": "enduit", "c1": "e08a6a", "c2": "c87458", "price": 100, "fam": "monde"},
	{"name": "Enduit bleu de Chefchaouen", "pat": "enduit", "c1": "7aaee2", "c2": "6296ca", "price": 100, "fam": "monde"},
	{"name": "Pisé rouge", "pat": "pise", "c1": "b06a48", "c2": "8e5034", "price": 60, "fam": "monde"},
	{"name": "Torchis blanc", "pat": "torchis", "c1": "ece4d0", "c2": "c8bea6", "price": 60, "fam": "monde"},
	{"name": "Tissu kente", "pat": "kente", "c1": "d8a020", "c2": "1f6a3a", "price": 90, "fam": "monde"},
	{"name": "Tissu wax", "pat": "pois", "c1": "d85a2a", "c2": "2a5e9a", "price": 90, "fam": "monde"},
	{"name": "Bois sculpté", "pat": "grain", "c1": "5e3a22", "c2": "3e2414", "price": 220, "fam": "monde"},
	{"name": "Brique de terre", "pat": "brique", "c1": "a86a48", "c2": "c8b49a", "price": 80, "fam": "monde"},
	{"name": "Granit de Bretagne", "pat": "granit", "c1": "b8a8a0", "c2": "5e5250", "price": 250, "fam": "monde"},
	{"name": "Pierre rose de Petra", "pat": "strates", "c1": "d49a84", "c2": "a86e5c", "price": 200, "fam": "monde"},
	{"name": "Plastique rouge", "pat": "plastique", "c1": "d6322a", "c2": "b02820", "price": 50, "fam": "attractions"},
	{"name": "Plastique jaune", "pat": "plastique", "c1": "f2c62a", "c2": "d6a818", "price": 50, "fam": "attractions"},
	{"name": "Plastique bleu", "pat": "plastique", "c1": "2a6ad6", "c2": "1e52b0", "price": 50, "fam": "attractions"},
	{"name": "Plastique vert", "pat": "plastique", "c1": "3ab04a", "c2": "2a8e3a", "price": 50, "fam": "attractions"},
	{"name": "Plastique orange", "pat": "plastique", "c1": "f28a2a", "c2": "d26e18", "price": 50, "fam": "attractions"},
	{"name": "Plastique violet", "pat": "plastique", "c1": "8a4ac8", "c2": "6e38a6", "price": 50, "fam": "attractions"},
	{"name": "Plastique rose", "pat": "plastique", "c1": "f27ab0", "c2": "d66296", "price": 50, "fam": "attractions"},
	{"name": "Fibre de verre", "pat": "plastique", "c1": "f4f2ee", "c2": "d8d6d2", "price": 70, "fam": "attractions"},
	{"name": "Dorure de manège", "pat": "laque", "c1": "d8a832", "c2": "f2d870", "price": 400, "fam": "attractions"},
	{"name": "Pois rouges", "pat": "pois", "c1": "f4f0e8", "c2": "d6322a", "price": 80, "fam": "attractions"},
	{"name": "Rayures bonbon", "pat": "rayures", "c1": "f27ab0", "c2": "f8f2f4", "price": 80, "fam": "attractions"},
	{"name": "Losanges arlequin", "pat": "losanges", "c1": "d6322a", "c2": "f2c62a", "price": 90, "fam": "attractions"},
	{"name": "Damier noir et blanc", "pat": "damier_fin", "c1": "f2f2ee", "c2": "1e1e1e", "price": 80, "fam": "attractions"},
	{"name": "Vagues", "pat": "vagues", "c1": "2a8ad6", "c2": "bfe6f8", "price": 70, "fam": "attractions"},
	{"name": "Faux rocher beige", "pat": "strates", "c1": "d4bc96", "c2": "a8926e", "price": 90, "fam": "attractions"},
	{"name": "Faux rocher gris", "pat": "strates", "c1": "9a968e", "c2": "6e6a64", "price": 90, "fam": "attractions"},
	{"name": "Néon rose", "pat": "plastique", "c1": "ff4fb8", "c2": "ff2a9a", "price": 120, "fam": "attractions"},
	{"name": "Néon bleu", "pat": "plastique", "c1": "2ad4ff", "c2": "18b0e0", "price": 120, "fam": "attractions"},
	{"name": "Néon vert", "pat": "plastique", "c1": "6aff4a", "c2": "48e02a", "price": 120, "fam": "attractions"},
	{"name": "Écran LED", "pat": "pixels", "c1": "1a1a1e", "c2": "2a8ad6", "price": 400, "fam": "attractions"},
	{"name": "Caoutchouc noir", "pat": "tartan", "c1": "2a2a2c", "c2": "3e3e40", "price": 60, "fam": "attractions"},
	{"name": "Sol amortissant vert", "pat": "tartan", "c1": "3a8a4a", "c2": "2e7a3e", "price": 70, "fam": "attractions"},
	{"name": "Sol amortissant bleu", "pat": "tartan", "c1": "2a5e9a", "c2": "1f4e86", "price": 70, "fam": "attractions"},
	{"name": "Étoiles", "pat": "etoiles", "c1": "1e2a5e", "c2": "f2d04a", "price": 90, "fam": "attractions"},
	{"name": "Rayures de cirque", "pat": "rayures_h", "c1": "d6322a", "c2": "f4f0e8", "price": 80, "fam": "attractions"},
	{"name": "Pelage de zèbre", "pat": "zebre", "c1": "f2f0ea", "c2": "1e1e1e", "price": 80, "fam": "zoo"},
	{"name": "Pelage de tigre", "pat": "zebre", "c1": "e88a2a", "c2": "1e1a16", "price": 80, "fam": "zoo"},
	{"name": "Pelage de léopard", "pat": "leopard", "c1": "d8a858", "c2": "2a2018", "price": 80, "fam": "zoo"},
	{"name": "Pelage de girafe", "pat": "girafe", "c1": "e6c890", "c2": "9a5a2a", "price": 80, "fam": "zoo"},
	{"name": "Camouflage", "pat": "camouflage", "c1": "5a6a3a", "c2": "3a3a26", "price": 60, "fam": "zoo"},
	{"name": "Foin", "pat": "chaume", "c1": "c8b86a", "c2": "9e8e48", "price": 15, "fam": "zoo"},
	{"name": "Copeaux de bois", "pat": "gravier", "c1": "b88a5a", "c2": "8a6038", "price": 20, "fam": "zoo"},
	{"name": "Terre battue de zoo", "pat": "sable", "c1": "c49a62", "c2": "a87e4a", "price": 15, "fam": "zoo"},
	{"name": "Eau de bassin", "pat": "eau", "c1": "2f7a5a", "c2": "8ad0a8", "price": 30, "fam": "zoo", "glass": true},
	{"name": "Faux rocher ocre", "pat": "strates", "c1": "c8904a", "c2": "9a6a34", "price": 90, "fam": "zoo"},
	{"name": "Bambou vert", "pat": "bambou", "c1": "6e9a3a", "c2": "4a6e24", "price": 50, "fam": "zoo"},
	{"name": "Grillage de volière", "pat": "grillage", "c1": "3e4246", "c2": "7a7e82", "price": 70, "fam": "zoo", "glass": true},
	{"name": "Roche grise", "pat": "strates", "c1": "8e8a84", "c2": "5e5a56", "price": 60, "fam": "zoo"},
	{"name": "Sable du désert", "pat": "sable", "c1": "e8c88a", "c2": "d0ae70", "price": 20, "fam": "zoo"},
	{"name": "Boue séchée", "pat": "boue", "c1": "9a8060", "c2": "6e5a40", "price": 10, "fam": "zoo"},
	{"name": "Écailles de reptile", "pat": "ecailles", "c1": "4a7a3a", "c2": "2e4e24", "price": 90, "fam": "zoo"},
	{"name": "Plumes", "pat": "ecailles", "c1": "e8e4dc", "c2": "b8b0a4", "price": 90, "fam": "zoo"},
	{"name": "Glace de banquise", "pat": "neige", "c1": "eaf6fc", "c2": "c8e6f4", "price": 20, "fam": "zoo"},
	{"name": "Paillis", "pat": "gravier", "c1": "6a4a2e", "c2": "3e2a18", "price": 15, "fam": "zoo"},
	{"name": "Gazon de savane", "pat": "herbe", "c1": "b8a85a", "c2": "8a7e3e", "price": 15, "fam": "zoo"},
	{"name": "Pelouse rayée", "pat": "pelouse_rayee", "c1": "4f9a3a", "c2": "3f862e", "price": 30, "fam": "sport"},
	{"name": "Gazon synthétique", "pat": "gazon_synth", "c1": "3aa04a", "c2": "2a8a3a", "price": 50, "fam": "sport"},
	{"name": "Terre battue", "pat": "sable", "c1": "c8643a", "c2": "b0542e", "price": 30, "fam": "sport"},
	{"name": "Piste en tartan rouge", "pat": "tartan", "c1": "b83a2a", "c2": "a03024", "price": 80, "fam": "sport"},
	{"name": "Piste en tartan bleu", "pat": "tartan", "c1": "2a5ea8", "c2": "1f4e90", "price": 80, "fam": "sport"},
	{"name": "Parquet de gymnase", "pat": "parquet_sport", "c1": "e2c08a", "c2": "c4a06a", "price": 140, "fam": "sport"},
	{"name": "Sol sportif bleu", "pat": "plastique", "c1": "2a6ab0", "c2": "1f5a9a", "price": 70, "fam": "sport"},
	{"name": "Sol sportif vert", "pat": "plastique", "c1": "3a8a5a", "c2": "2e7a4a", "price": 70, "fam": "sport"},
	{"name": "Glace de patinoire", "pat": "neige", "c1": "f2f8fc", "c2": "dceef8", "price": 40, "fam": "sport"},
	{"name": "Sable de beach-volley", "pat": "sable", "c1": "f0deaa", "c2": "dcc890", "price": 20, "fam": "sport"},
	{"name": "Sièges de stade rouges", "pat": "sieges", "c1": "c8322a", "c2": "2a2a2c", "price": 120, "fam": "sport"},
	{"name": "Sièges de stade bleus", "pat": "sieges", "c1": "2a5ab0", "c2": "2a2a2c", "price": 120, "fam": "sport"},
	{"name": "Sièges de stade verts", "pat": "sieges", "c1": "2a8a4a", "c2": "2a2a2c", "price": 120, "fam": "sport"},
	{"name": "Sièges de stade jaunes", "pat": "sieges", "c1": "f2c62a", "c2": "2a2a2c", "price": 120, "fam": "sport"},
	{"name": "Piste cendrée", "pat": "gravier", "c1": "8a4a3a", "c2": "5a3028", "price": 30, "fam": "sport"},
	{"name": "Résine de court", "pat": "plastique", "c1": "3a6aa8", "c2": "2e5a92", "price": 70, "fam": "sport"},
	{"name": "Tapis de lutte", "pat": "plastique", "c1": "2e4e9a", "c2": "c83a2a", "price": 60, "fam": "sport"},
	{"name": "Béton de skatepark", "pat": "beton", "c1": "c4c2bc", "c2": "a8a6a0", "price": 90, "fam": "sport"},
	{"name": "Green de golf", "pat": "gazon_synth", "c1": "4fae4a", "c2": "3e9a3a", "price": 50, "fam": "sport"},
	{"name": "Bandes de piste", "pat": "rayures", "c1": "f2f2ee", "c2": "b83a2a", "price": 60, "fam": "sport"},
	{"name": "Marbre vert de musée", "pat": "marbre", "c1": "2a5e48", "c2": "c8d8cc", "price": 480, "fam": "musee"},
	{"name": "Granit poli noir", "pat": "granit", "c1": "1e1e20", "c2": "4a4a4e", "price": 400, "fam": "musee"},
	{"name": "Parquet Versailles", "pat": "versailles", "c1": "b8884e", "c2": "8a6034", "price": 260, "fam": "musee"},
	{"name": "Velours rouge", "pat": "moquette", "c1": "8e1e24", "c2": "701820", "price": 120, "fam": "musee"},
	{"name": "Moquette bordeaux", "pat": "moquette", "c1": "6e2230", "c2": "58182a", "price": 80, "fam": "musee"},
	{"name": "Cimaise blanche", "pat": "uni", "c1": "f6f6f4", "c2": "ecece8", "price": 70, "fam": "musee"},
	{"name": "Mur de galerie gris", "pat": "uni", "c1": "8e9094", "c2": "84868a", "price": 70, "fam": "musee"},
	{"name": "Feuille d'or", "pat": "cuivre", "c1": "e2b440", "c2": "c8961e", "price": 900, "fam": "musee"},
	{"name": "Boiserie de chêne", "pat": "planches_v", "c1": "a87a48", "c2": "7e5830", "price": 160, "fam": "musee"},
	{"name": "Stuc blanc", "pat": "marbre", "c1": "f6f2ea", "c2": "e2dccc", "price": 280, "fam": "musee"},
	{"name": "Pierre de taille claire", "pat": "pierre_taillee", "c1": "efe8d8", "c2": "d8d0bc", "price": 230, "fam": "musee"},
	{"name": "Bois d'ébène", "pat": "grain", "c1": "2a1e18", "c2": "1a120e", "price": 300, "fam": "musee"},
	{"name": "Marbre jaune de Sienne", "pat": "marbre", "c1": "e2c470", "c2": "a8883a", "price": 460, "fam": "musee"},
	{"name": "Mosaïque romaine", "pat": "mosaique", "c1": "c8a882", "c2": "6a3a2a", "price": 300, "fam": "musee"},
	{"name": "Damier de marbre", "pat": "damier", "c1": "f4f2ec", "c2": "2a2a2c", "price": 360, "fam": "musee"},
	{"name": "Tapis rouge", "pat": "moquette", "c1": "b81e24", "c2": "9a161c", "price": 80, "fam": "evenements"},
	{"name": "Moquette d'exposition", "pat": "moquette", "c1": "3a4a6e", "c2": "2e3c5a", "price": 50, "fam": "evenements"},
	{"name": "Chapiteau rouge et blanc", "pat": "rayures", "c1": "c8322a", "c2": "f4f0e8", "price": 60, "fam": "evenements"},
	{"name": "Chapiteau bleu et jaune", "pat": "rayures", "c1": "2a5ab0", "c2": "f2c62a", "price": 60, "fam": "evenements"},
	{"name": "Bâche blanche", "pat": "toile", "c1": "f2f0ea", "c2": "dad6cc", "price": 30, "fam": "evenements"},
	{"name": "Bâche verte", "pat": "toile", "c1": "3a6e4a", "c2": "2e5a3c", "price": 30, "fam": "evenements"},
	{"name": "Confettis", "pat": "confettis", "c1": "f4f0e8", "c2": "d6322a", "price": 50, "fam": "evenements"},
	{"name": "Podium noir", "pat": "laque", "c1": "1e1e20", "c2": "3a3a3e", "price": 120, "fam": "evenements"},
	{"name": "Damier de course", "pat": "damier_fin", "c1": "f2f2ee", "c2": "1a1a1a", "price": 60, "fam": "evenements"},
	{"name": "Scène noire", "pat": "planches_h", "c1": "2a2a2c", "c2": "161618", "price": 90, "fam": "evenements"},
	{"name": "Velours bleu", "pat": "moquette", "c1": "22306e", "c2": "1a2458", "price": 120, "fam": "evenements"},
	{"name": "Banderoles", "pat": "rayures_h", "c1": "f2c62a", "c2": "2a5ab0", "price": 40, "fam": "evenements"},
	{"name": "Plancher de bal", "pat": "parquet", "c1": "c49862", "c2": "9e7444", "price": 110, "fam": "evenements"},
	{"name": "Toile de tente kaki", "pat": "toile", "c1": "7a7a4e", "c2": "5e5e3a", "price": 30, "fam": "evenements"},
	{"name": "Fanions", "pat": "losanges", "c1": "d6322a", "c2": "2a5ab0", "price": 40, "fam": "evenements"},
	{"name": "Paillettes or", "pat": "confettis", "c1": "c89a2a", "c2": "f6e08a", "price": 150, "fam": "evenements"},
	{"name": "Paillettes argent", "pat": "confettis", "c1": "9aa0a8", "c2": "eef0f2", "price": 150, "fam": "evenements"},
	{"name": "Gazon de fête", "pat": "herbe", "c1": "6aa84f", "c2": "4f8a3a", "price": 20, "fam": "evenements"},
	{"name": "Pierre agglomérée", "pat": "pierre_taillee", "c1": "c8bfae", "c2": "a39a88", "price": 90, "fam": "murs"},
	{"name": "Ciment moulé", "pat": "beton", "c1": "bdb6a6", "c2": "9e9788", "price": 80, "fam": "murs"},
	{"name": "Grès flammé Art nouveau", "pat": "brique_vernie", "c1": "6a8a5a", "c2": "c9a24a", "price": 260, "fam": "murs"},
	{"name": "Carreaux de métro", "pat": "carrelage", "c1": "f4f2ea", "c2": "d6d2c6", "price": 130, "fam": "murs"},
	{"name": "Faïence Art déco", "pat": "carrelage", "c1": "1f5f6a", "c2": "d4b25a", "price": 220, "fam": "murs"},
	{"name": "Mosaïque Art déco", "pat": "mosaique", "c1": "1f2a44", "c2": "c9a24a", "price": 240, "fam": "sols"},
	{"name": "Ferronnerie Art nouveau", "pat": "grillage", "c1": "2f4a3a", "c2": "1f2a24", "price": 180, "fam": "metal_verre"},
	{"name": "Bakélite", "pat": "plastique", "c1": "5a2a1a", "c2": "3a1a10", "price": 90, "fam": "decor"},
	{"name": "Formica jaune", "pat": "plastique", "c1": "f2d04a", "c2": "e0be38", "price": 70, "fam": "decor"},
	{"name": "Formica turquoise", "pat": "plastique", "c1": "5ac0c0", "c2": "48a8a8", "price": 70, "fam": "decor"},
	{"name": "Gabions", "pat": "moellons", "c1": "9a958a", "c2": "6e6a62", "price": 60, "fam": "nature"},
	{"name": "Tôle émaillée", "pat": "tole", "c1": "e8e4d8", "c2": "b0aca0", "price": 120, "fam": "toits"},
	{"name": "Façade aluminium composite", "pat": "panneaux", "c1": "d0d4d8", "c2": "8a9096", "price": 210, "fam": "metal_verre"},
	{"name": "Panneaux de béton préfabriqués", "pat": "panneaux", "c1": "c4bfb2", "c2": "9a958a", "price": 100, "fam": "murs"},
	{"name": "Mur-rideau bronze", "pat": "panneaux", "c1": "6a5a3a", "c2": "3a3428", "price": 260, "fam": "metal_verre"},
	{"name": "Vinyle de sol", "pat": "carrelage", "c1": "d8d0c0", "c2": "b8ae9a", "price": 50, "fam": "sols"},
	{"name": "Parquet stratifié", "pat": "parquet", "c1": "c49a6a", "c2": "a07a4a", "price": 60, "fam": "sols"},
	{"name": "Polymère blanc", "pat": "uni", "c1": "f6f4ee", "c2": "e6e2da", "price": 180, "fam": "decor"},
	{"name": "Béton imprimé", "pat": "dalles", "c1": "b8a08a", "c2": "8a7460", "price": 70, "fam": "sols"},
	{"name": "Panneaux solaires", "pat": "solaire", "c1": "1f2f5a", "c2": "9aa6b8", "price": 300, "fam": "toits"},
	{"name": "Tuiles solaires", "pat": "solaire", "c1": "2a2a30", "c2": "4a4a52", "price": 340, "fam": "toits"},
	{"name": "Bois lamellé-croisé", "pat": "planches_v", "c1": "dcbf94", "c2": "bf9f72", "price": 160, "fam": "bois"},
	{"name": "Bardage composite gris", "pat": "planches_h", "c1": "8a8a86", "c2": "6e6e6a", "price": 120, "fam": "bois"},
	{"name": "Bardage fibre-ciment", "pat": "fibrociment", "c1": "b8b4ac", "c2": "9a968e", "price": 110, "fam": "murs"},
	{"name": "Baguettes de terre cuite", "pat": "planches_v", "c1": "c46a44", "c2": "9a4e30", "price": 230, "fam": "murs"},
	{"name": "Coussins ETFE", "pat": "pave_verre", "c1": "d8ecf2", "c2": "a8cad6", "price": 350, "fam": "metal_verre"},
	{"name": "Béton fibré blanc", "pat": "beton", "c1": "eeece6", "c2": "d6d2c8", "price": 200, "fam": "murs"},
	{"name": "Carrelage grand format", "pat": "dalles", "c1": "d6d2ca", "c2": "bab6ae", "price": 120, "fam": "sols"},
	{"name": "Pavés drainants", "pat": "autobloquant", "c1": "9a9a8e", "c2": "6e7a5a", "price": 70, "fam": "sols"},
	{"name": "Mur végétal", "pat": "vegetal", "c1": "4f8a3a", "c2": "2f6a2a", "price": 260, "fam": "nature"},
	{"name": "Métal perforé doré", "pat": "grillage", "c1": "c8a24a", "c2": "8a6a2a", "price": 280, "fam": "metal_verre"},
	{"name": "Verre intelligent", "pat": "verre", "c1": "8ac0d8", "c2": "5a90b0", "price": 420, "fam": "metal_verre"},
	{"name": "Façade OLED", "pat": "pixels", "c1": "20304a", "c2": "101828", "price": 500, "fam": "metal_verre"},
	{"name": "Mycélium", "pat": "enduit", "c1": "e8dcc4", "c2": "c8b89a", "price": 150, "fam": "murs"},
	{"name": "Biobéton", "pat": "beton", "c1": "a8b49a", "c2": "8a967c", "price": 180, "fam": "murs"},
]

const FAMILIES := [
	{"id": "", "name": "Tous les matériaux"},
	{"id": "murs", "name": "Murs"},
	{"id": "toits", "name": "Toits"},
	{"id": "sols", "name": "Sols"},
	{"id": "bois", "name": "Bois"},
	{"id": "metal_verre", "name": "Métal et verre"},
	{"id": "nature", "name": "Nature"},
	{"id": "decor", "name": "Tissus et divers"},
	{"id": "monde", "name": "Styles du monde"},
	{"id": "attractions", "name": "Parcs d'attractions"},
	{"id": "zoo", "name": "Zoo et animaux"},
	{"id": "sport", "name": "Sport et stades"},
	{"id": "musee", "name": "Musées et prestige"},
	{"id": "evenements", "name": "Événements et fêtes"},
]

## Teintes : 0 = couleur naturelle du matériau.
const TINTS := [
	Color(1, 1, 1), Color("f2f2f2"), Color("b0b0b0"), Color("5a5a5a"),
	Color("d94a3d"), Color("e88a3a"), Color("f2d04a"), Color("7cbf5a"),
	Color("3f8f6a"), Color("4aa3d9"), Color("3a5fbf"), Color("8a5ab8"),
	Color("e88ab0"), Color("8a5a36"), Color("2a2a2a"), Color("f5e6c8"),
]
const TINT_NAMES := ["Naturelle", "Blanc", "Gris", "Anthracite", "Rouge", "Orange", "Jaune", "Vert clair",
	"Vert sapin", "Bleu ciel", "Bleu roi", "Violet", "Rose", "Brun", "Noir", "Crème"]

## Couche 0 du tableau de textures : blanc uni (portes, cadres peints…).
const PLAIN := 0

static var _array: Texture2DArray
static var _images: Array[Image] = []
static var _solid: ShaderMaterial
static var _glass: ShaderMaterial
static var _ghost: ShaderMaterial

const SHADER := """
shader_type spatial;
render_mode depth_draw_opaque, cull_back;
uniform sampler2DArray tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
void fragment() {
	vec4 c = texture(tex, vec3(UV, UV2.x));
	ALBEDO = c.rgb * COLOR.rgb;
	ROUGHNESS = 0.88;
}
"""

const SHADER_GLASS := """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;
uniform sampler2DArray tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float alpha_mul = 1.0;
void fragment() {
	vec4 c = texture(tex, vec3(UV, UV2.x));
	ALBEDO = c.rgb * COLOR.rgb;
	ALPHA = c.a * alpha_mul;
	ROUGHNESS = 0.08;
	SPECULAR = 0.9;
}
"""


static func count() -> int:
	return LIST.size()


## Indice d'un matériau d'après son nom (−1 s'il n'existe pas).
static func index_of(name: String) -> int:
	for i in LIST.size():
		if String(LIST[i].name) == name:
			return i
	return -1


static func is_glass(m: int) -> bool:
	return bool(LIST[clampi(m, 0, LIST.size() - 1)].get("glass", false))


## Couche de texture d'un matériau (la couche 0 est le blanc uni).
static func layer(m: int) -> int:
	return clampi(m, 0, LIST.size() - 1) + 1


## Couleur moyenne d'un matériau (aperçus, créations sans texture).
static func color(m: int) -> Color:
	return Color(String(LIST[clampi(m, 0, LIST.size() - 1)].c1))


static func tint_color(t: int) -> Color:
	return TINTS[clampi(t, 0, TINTS.size() - 1)]


static func texture_array() -> Texture2DArray:
	if _array == null:
		_build()
	return _array


## Image d'un matériau (vignette du panneau).
static func image(m: int) -> Image:
	if _array == null:
		_build()
	return _images[layer(m)]


static func solid_material() -> ShaderMaterial:
	if _solid == null:
		var sh := Shader.new()
		sh.code = SHADER
		_solid = ShaderMaterial.new()
		_solid.shader = sh
		_solid.set_shader_parameter("tex", texture_array())
	return _solid


static func glass_material() -> ShaderMaterial:
	if _glass == null:
		var sh := Shader.new()
		sh.code = SHADER_GLASS
		_glass = ShaderMaterial.new()
		_glass.shader = sh
		_glass.set_shader_parameter("tex", texture_array())
	return _glass


## Matériau translucide du fantôme de pose.
static func ghost_material() -> ShaderMaterial:
	if _ghost == null:
		var sh := Shader.new()
		sh.code = SHADER_GLASS
		_ghost = ShaderMaterial.new()
		_ghost.shader = sh
		_ghost.set_shader_parameter("tex", texture_array())
		_ghost.set_shader_parameter("alpha_mul", 0.6)
	return _ghost


## Version des motifs : à augmenter quand un dessin de _pixel change.
const PATTERN_VERSION := 3
## Cache disque des textures (le dessin des ~400 matériaux prend quelques secondes).
static var use_cache := true


static func _cache_path() -> String:
	var sig := str(PATTERN_VERSION) + "|" + str(PX) + "|" + JSON.stringify(LIST)
	return "user://cache/materiaux_%s.png" % sig.md5_text().substr(0, 12)


static func _build() -> void:
	_images.clear()
	var plain := Image.create(PX, PX, false, Image.FORMAT_RGBA8)
	plain.fill(Color.WHITE)
	_images.append(plain)
	var path := _cache_path()
	var sheet: Image = null
	if use_cache and FileAccess.file_exists(path):
		sheet = Image.load_from_file(path)
		if sheet != null and (sheet.get_width() != PX or sheet.get_height() != PX * LIST.size()):
			sheet = null
	if sheet != null:
		sheet.convert(Image.FORMAT_RGBA8)
		for i in LIST.size():
			_images.append(sheet.get_region(Rect2i(0, i * PX, PX, PX)))
	else:
		sheet = Image.create(PX, PX * LIST.size(), false, Image.FORMAT_RGBA8)
		for i in LIST.size():
			var img := _draw(LIST[i], i)
			_images.append(img)
			sheet.blit_rect(img, Rect2i(0, 0, PX, PX), Vector2i(0, i * PX))
		if use_cache:
			DirAccess.make_dir_recursive_absolute("user://cache")
			for f in DirAccess.get_files_at("user://cache"):
				if f.begins_with("materiaux_") and "user://cache/" + f != path:
					DirAccess.remove_absolute("user://cache/" + f)
			sheet.save_png(path)
	for img in _images:
		img.generate_mipmaps()
	_array = Texture2DArray.new()
	_array.create_from_images(_images)


# --- Dessin des motifs -----------------------------------------------------------------

static var _noise: FastNoiseLite


static func _n(x: float, y: float, freq: float, seed_off: int) -> float:
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.seed = seed_off
	_noise.frequency = freq
	# Bruit répété tous les 64 px : on mélange quatre lectures décalées.
	var u := x / PX
	var v := y / PX
	var a := _noise.get_noise_2d(x, y)
	var b := _noise.get_noise_2d(x - PX, y)
	var c := _noise.get_noise_2d(x, y - PX)
	var d := _noise.get_noise_2d(x - PX, y - PX)
	return lerpf(lerpf(a, b, u), lerpf(c, d, u), v)


static func _h(x: int, y: int, s: int) -> float:
	var v := (x * 374761393 + y * 668265263 + s * 2147483647) & 0x7fffffff
	v = ((v ^ (v >> 13)) * 1274126177) & 0x7fffffff
	return float(v % 10000) / 10000.0


static func _draw(m: Dictionary, idx: int) -> Image:
	var img := Image.create(PX, PX, false, Image.FORMAT_RGBA8)
	var c1 := Color(String(m.c1))
	var c2 := Color(String(m.c2))
	var pat: String = m.pat
	var s := idx * 17 + 3
	for y in PX:
		for x in PX:
			img.set_pixel(x, y, _pixel(pat, x, y, c1, c2, s))
	return img


static func _shade(c: Color, f: float) -> Color:
	return Color(clampf(c.r * f, 0, 1), clampf(c.g * f, 0, 1), clampf(c.b * f, 0, 1), c.a)


## Rangées décalées (briques, pierres) : renvoie [ligne, colonne, joint?].
static func _bond(x: int, y: int, bw: int, bh: int, joint: int) -> Array:
	var row := y / bh
	var xx := x + (bw / 2 if row % 2 == 1 else 0)
	var col := xx / bw
	var j := (y % bh) < joint or (xx % bw) < joint
	return [row, col, j]


static func _pixel(pat: String, x: int, y: int, c1: Color, c2: Color, s: int) -> Color:
	var fx := float(x)
	var fy := float(y)
	match pat:
		"uni":
			return _shade(c1, 1.0 + _n(fx, fy, 0.08, s) * 0.03)
		"enduit":
			return _shade(c1, 1.0 + _n(fx, fy, 0.25, s) * 0.06 + (_h(x, y, s) - 0.5) * 0.06)
		"brique", "parpaing", "pierre_taillee":
			var bw := 21 if pat == "brique" else 32
			var bh := 8 if pat == "brique" else (16 if pat == "parpaing" else 16)
			if pat == "brique":
				bw = 16
			var b := _bond(x, y, bw, bh, 2 if pat != "brique" else 1)
			if b[2]:
				return _shade(c2, 1.0 + _n(fx, fy, 0.3, s) * 0.05)
			var v := 0.88 + _h(b[0], b[1], s) * 0.22
			return _shade(c1, v + _n(fx, fy, 0.2, s + 1) * 0.06)
		"moellons", "paves":
			var cell := 16 if pat == "paves" else 21
			var best := 1e9
			var second := 1e9
			var bid := Vector2i.ZERO
			var cx := x / cell
			var cy := y / cell
			var nper := PX / cell + (0 if PX % cell == 0 else 1)
			for oy in range(-1, 2):
				for ox in range(-1, 2):
					var gx := cx + ox
					var gy := cy + oy
					var wx := posmod(gx, nper)
					var wy := posmod(gy, nper)
					var j := 0.5 if pat == "paves" else 0.85
					var px := (gx + 0.5 + (_h(wx, wy, s) - 0.5) * j) * cell
					var py := (gy + 0.5 + (_h(wx, wy, s + 9) - 0.5) * j) * cell
					var dd := Vector2(px - fx, py - fy).length()
					if dd < best:
						second = best
						best = dd
						bid = Vector2i(wx, wy)
					elif dd < second:
						second = dd
			if second - best < 2.2:
				return _shade(c2, 1.0 + _n(fx, fy, 0.3, s) * 0.05)
			return _shade(c1, 0.82 + _h(bid.x, bid.y, s + 3) * 0.3 + _n(fx, fy, 0.25, s) * 0.05)
		"granit":
			var r := _h(x, y, s)
			var base := _shade(c1, 1.0 + _n(fx, fy, 0.15, s) * 0.08)
			if r > 0.86:
				return c2
			if r < 0.06:
				return _shade(c1, 1.25)
			return base
		"marbre":
			var vein := sin((fx + fy * 0.6) * 0.12 + _n(fx, fy, 0.05, s) * 6.0)
			var t := clampf(pow(absf(vein), 12.0), 0.0, 1.0)
			return c1.lerp(c2, t * 0.8)
		"beton", "beton_banche":
			var c := _shade(c1, 1.0 + _n(fx, fy, 0.2, s) * 0.06 + (_h(x, y, s) - 0.5) * 0.05)
			if pat == "beton_banche":
				if y % 32 == 0 or x % 64 == 0:
					return _shade(c1, 0.85)
				if (x % 32 == 16) and (y % 32 == 16):
					return c2.darkened(0.3)
			elif _h(x, y, s + 5) > 0.985:
				return c2.darkened(0.2)
			return c
		"grain", "planches_h", "planches_v", "parquet", "bois":
			var along := fx if pat != "planches_v" else fy
			var across := fy if pat != "planches_v" else fx
			var bh := 64.0
			if pat == "planches_h" or pat == "planches_v":
				bh = 64.0 / 6.0
			elif pat == "parquet":
				bh = 8.0
			var board := int(across / bh)
			var off := _h(board, 0, s) * PX
			var grain := sin((along + off) * 0.05 + across * 0.9 + _n(along, across * 3.0, 0.05, s + board) * 4.0)
			var c := _shade(c1, 0.92 + grain * 0.06 + _h(board, 1, s) * 0.1)
			var inb := fmod(across, bh)
			if bh < 64.0 and inb < 1.0:
				return _shade(c2, 0.8)
			if pat == "planches_h" and inb > bh - 2.0:
				return _shade(c1, 0.8)
			if pat == "parquet":
				var seg := int((along + off) / 32.0)
				if fmod(along + off, 32.0) < 1.0:
					return _shade(c2, 0.85)
				c = _shade(c, 0.95 + _h(board, seg, s) * 0.1)
			return c
		"rondins":
			var lh := 16.0
			var t := fmod(fy, lh) / lh
			var round := sin(t * PI)
			var c := _shade(c1, 0.55 + round * 0.55 + _n(fx * 0.3, fy * 2.0, 0.1, s) * 0.06)
			if t < 0.06 or t > 0.94:
				return _shade(c2, 0.7)
			return c
		"tuile":
			var rh := 10.7
			var cw := 10.7
			var row := int(fy / rh)
			var t := fmod(fy, rh) / rh
			var xx := fx + (cw / 2.0 if row % 2 == 1 else 0.0)
			var u := fmod(xx, cw) / cw
			var arc := sin(u * PI)
			var c := _shade(c1, 0.72 + arc * 0.38 + _h(row, int(xx / cw), s) * 0.08)
			if t > 0.85:
				return _shade(c2, 0.7)
			return c
		"tuile_plate", "ardoise":
			var rh := 8.0 if pat == "tuile_plate" else 10.7
			var cw := 12.8 if pat == "tuile_plate" else 16.0
			var row := int(fy / rh)
			var xx := fx + (cw / 2.0 if row % 2 == 1 else 0.0)
			var col := int(xx / cw)
			var t := fmod(fy, rh) / rh
			if fmod(xx, cw) < 1.0 or t > 0.88:
				return _shade(c2, 0.75)
			return _shade(c1, 0.85 + _h(row, col % 5, s) * 0.25 + t * 0.06)
		"enduit_lisse":
			return c1
		"metal":
			return _shade(c1, 0.93 + _n(fx * 0.2, fy * 4.0, 0.2, s) * 0.08 + sin(fy * 0.3) * 0.02)
		"tole":
			return _shade(c1, 0.8 + sin(fx / 64.0 * TAU * 8.0) * 0.18)
		"zinc":
			if x % 16 == 0 or x % 16 == 1:
				return _shade(c1, 1.25)
			return _shade(c1, 0.95 + _n(fx, fy, 0.1, s) * 0.05)
		"cuivre":
			var t := clampf(0.5 + _n(fx, fy, 0.08, s) * 1.2, 0.0, 1.0)
			return c1.lerp(c2, t)
		"verre":
			var streak := 0.25 + 0.15 * clampf(sin((fx + fy) * 0.12) * 2.0 - 1.0, 0.0, 1.0)
			var g := c1.lerp(c2, streak)
			g.a = 0.38 + streak * 0.3
			return g
		"vitrail":
			var cell := 16
			var col := Color.from_hsv(_h(x / cell, y / cell, s), 0.7, 0.9)
			if x % cell < 2 or y % cell < 2:
				return Color(0.1, 0.1, 0.1, 0.95)
			col.a = 0.75
			return col
		"herbe":
			var c := _shade(c1, 1.0 + _n(fx, fy, 0.15, s) * 0.12)
			if _h(x, y, s) > 0.82:
				return _shade(c2, 0.95)
			return c
		"sable", "neige", "moquette", "terre":
			var amp := 0.1 if pat != "neige" else 0.04
			return _shade(c1, 1.0 + _n(fx, fy, 0.2, s) * amp + (_h(x, y, s) - 0.5) * amp)
		"gravier":
			var r := _h(x / 3, y / 3, s)
			return _shade(c1.lerp(c2, r), 0.85 + _h(x, y, s + 1) * 0.3)
		"feuillage":
			var v := _n(fx, fy, 0.2, s)
			if v < -0.25:
				return _shade(c2, 0.8)
			return _shade(c1, 1.0 + v * 0.25)
		"chaume":
			return _shade(c1, 0.8 + _n(fx * 4.0, fy * 0.3, 0.2, s) * 0.25 + _h(x, y / 4, s) * 0.12)
		"torchis":
			var c := _shade(c1, 1.0 + _n(fx, fy, 0.18, s) * 0.08)
			if _h(x, y, s) > 0.93:
				return _shade(c2, 1.1)
			return c
		"bambou":
			if x % 10 == 0:
				return _shade(c2, 0.8)
			if (y + (x / 10) * 7) % 21 == 0:
				return c2
			return _shade(c1, 0.85 + sin(float(x % 10) / 10.0 * PI) * 0.25)
		"carrelage", "tomettes":
			var cell := 16 if pat == "carrelage" else 21
			if x % cell == 0 or y % cell == 0:
				return c2
			return _shade(c1, 0.95 + _h(x / cell, y / cell, s) * 0.08)
		"damier":
			var a := ((x / 16) + (y / 16)) % 2 == 0
			return _shade(c1 if a else c2, 1.0 + _n(fx, fy, 0.3, s) * 0.03)
		"flamand", "anglais", "joints_alignes":
			# Appareils : boutisses (8 px) et panneresses (16 px), joints de 1 px.
			var row := y / 8
			var bw := 16
			var off := 0
			if pat == "flamand":
				off = 6 if row % 2 == 1 else 0
				var xx := posmod(x + off, 24)
				var j := (y % 8) < 1 or xx == 0 or xx == 16
				if j:
					return _shade(c2, 1.0 + _n(fx, fy, 0.3, s) * 0.05)
				var hdr := xx >= 16
				return _shade(c1, (0.8 if hdr else 0.95) + _h(row, (x + off) / 24 * 2 + int(hdr), s) * 0.2)
			if pat == "anglais":
				bw = 8 if row % 2 == 1 else 16
				off = 4 if row % 2 == 1 else 0
			var xx2 := x + off
			if (y % 8) < 1 or (xx2 % bw) < 1:
				return _shade(c2, 1.0 + _n(fx, fy, 0.3, s) * 0.05)
			var v2 := 0.86 + _h(row, xx2 / bw, s) * 0.24
			if pat == "anglais" and row % 2 == 1:
				v2 *= 0.88
			return _shade(c1, v2 + _n(fx, fy, 0.2, s + 1) * 0.05)
		"brique_vernie":
			var bv := _bond(x, y, 16, 8, 1)
			if bv[2]:
				return c2
			var g := 0.85 + _h(bv[0], bv[1], s) * 0.3
			var hl := 0.15 if (y % 8) == 2 else 0.0
			return _shade(c1, g + hl)
		"meuliere":
			var mv := _n(fx, fy, 0.12, s)
			if absf(mv) < 0.04:
				return _shade(c2, 0.95)
			var c := _shade(c1, 0.9 + mv * 0.3 + (_h(x, y, s) - 0.5) * 0.12)
			if _h(x / 2, y / 2, s + 4) > 0.9:
				return _shade(c, 0.7)
			return c
		"opus":
			# Pierres irrégulières : cellules de Voronoï plus grandes et joints larges.
			return _pixel("moellons", x, y, c1, c2, s + 7)
		"travertin":
			var band := sin(fy * 0.35 + _n(fx, fy, 0.03, s) * 5.0)
			var c := _shade(c1, 0.95 + band * 0.04 + _n(fx, fy, 0.2, s) * 0.04)
			if _h(x, y / 2, s) > 0.93:
				return _shade(c2, 0.9)
			if y % 32 == 0 or (x + (y / 32) * 21) % 64 == 0:
				return _shade(c1, 0.8)
			return c
		"pise":
			var layer_h := 10.7
			var t := fmod(fy, layer_h) / layer_h
			var c := _shade(c1.lerp(c2, _h(int(fy / layer_h), 0, s) * 0.6), 0.95 + _n(fx, fy, 0.2, s) * 0.08)
			if t < 0.08:
				return _shade(c, 0.85)
			return c
		"chaux":
			var c := _shade(c1, 1.0 + _n(fx * 0.5, fy * 2.0, 0.1, s) * 0.07)
			if _n(fx, fy, 0.05, s + 2) > 0.35:
				return c.lerp(c2, 0.4)
			return c
		"zellige":
			var cell := 8
			if x % cell == 0 or y % cell == 0:
				return c2
			var hv := _h(x / cell, y / cell, s)
			var c := _shade(c1, 0.75 + hv * 0.45)
			if (x % cell) == 2 and (y % cell) == 2:
				return _shade(c, 1.4)
			return c
		"bois_brule":
			var row := int(fy / 10.67)
			var cr := _n(fx * 0.6, fy * 0.6, 0.25, s + row)
			if fmod(fy, 10.67) < 1.0:
				return c2
			if absf(cr) < 0.05:
				return _shade(c1, 1.6)
			return _shade(c1, 0.85 + _h(x / 3, y / 3, s) * 0.3)
		"contreplaque":
			var gr := sin(fx * 0.05 + _n(fx, fy * 0.2, 0.04, s) * 9.0)
			if x % 64 == 0 or y % 64 == 0:
				return _shade(c2, 0.8)
			return _shade(c1, 0.95 + gr * 0.06)
		"vannerie":
			var cx := x / 8
			var cy := y / 8
			var horiz := (cx + cy) % 2 == 0
			var t := float((y if horiz else x) % 8) / 8.0
			var c := _shade(c1, 0.75 + sin(t * PI) * 0.35)
			if (x % 8 == 0 and not horiz) or (y % 8 == 0 and horiz):
				return _shade(c2, 0.8)
			return c
		"bardeaux":
			var rh := 12.8
			var row := int(fy / rh)
			var cw := 9.0 + _h(row, 0, s) * 4.0
			var xx := fx + _h(row, 1, s) * 20.0
			var col := int(xx / cw)
			var t := fmod(fy, rh) / rh
			if fmod(xx, cw) < 1.0 or t > 0.9:
				return _shade(c2, 0.7)
			return _shade(c1, 0.8 + _h(row, col, s) * 0.3 + t * 0.08)
		"lauze":
			var row := int(fy / 12.8)
			var xx := fx + float(row % 3) * 9.0
			var cw := 14.0 + _h(row, int(xx / 18.0), s) * 8.0
			var col := int(xx / cw)
			var t := fmod(fy, 12.8) / 12.8
			if fmod(xx, cw) < 1.5 or t > 0.86:
				return _shade(c2, 0.75)
			return _shade(c1, 0.8 + _h(row, col, s + 2) * 0.3 + _n(fx, fy, 0.3, s) * 0.06)
		"tuile_canal":
			var cw := 12.8
			var row := int(fy / 16.0)
			var u := fmod(fx, cw) / cw
			var arc := sin(u * PI)
			var chan := int(fx / cw) % 2 == 0
			var c := _shade(c1, (0.75 if chan else 0.6) + arc * 0.4 + _h(row, int(fx / cw), s) * 0.12)
			if fmod(fy, 16.0) > 14.0 and chan:
				return _shade(c2, 0.7)
			return c
		"ecailles":
			var rh := 8.0
			var cw := 10.67
			var row := int(fy / rh)
			var xx := fx + (cw / 2.0 if row % 2 == 1 else 0.0)
			var u := fmod(xx, cw) / cw - 0.5
			var t := fmod(fy, rh) / rh
			var edge := 1.0 - sqrt(maxf(0.0, 1.0 - 4.0 * u * u))
			if absf(t - (1.0 - edge * 0.9)) < 0.12:
				return _shade(c2, 0.7)
			return _shade(c1, 0.85 + _h(row, int(xx / cw), s) * 0.25)
		"joints_debout":
			var xm := x % 21
			if xm == 0:
				return _shade(c1, 1.3)
			if xm == 1:
				return _shade(c1, 0.75)
			return _shade(c1, 0.95 + _n(fx, fy, 0.08, s) * 0.04)
		"fibrociment":
			return _shade(c1, 0.82 + sin(fx / 64.0 * TAU * 4.0) * 0.16 + _n(fx, fy, 0.2, s) * 0.04)
		"bac_acier":
			var xm := x % 16
			if xm < 4:
				return _shade(c1, 1.2 if xm < 2 else 0.8)
			return _shade(c1, 0.95)
		"vegetal":
			var v := _n(fx, fy, 0.25, s)
			if _h(x / 2, y / 2, s) > 0.93:
				return c2
			if _h(x / 2, y / 2, s + 1) > 0.95:
				return Color("e9d36a")
			return _shade(c1, 0.85 + v * 0.3)
		"terrazzo":
			var r := _h(x / 2, y / 2, s)
			if r > 0.9:
				return _shade(c2, 0.8 + _h(x, y, s) * 0.4)
			if r > 0.84:
				return Color("c9a27e").lerp(c1, 0.3)
			if r < 0.04:
				return _shade(c2, 0.55)
			return _shade(c1, 1.0 + _n(fx, fy, 0.2, s) * 0.03)
		"carreaux_ciment":
			var cell := 32
			if x % cell == 0 or y % cell == 0:
				return _shade(c1, 0.85)
			var u := float(x % cell) / cell - 0.5
			var v := float(y % cell) / cell - 0.5
			var d := absf(u) + absf(v)
			var ring := sqrt(u * u + v * v)
			if d < 0.18 or (ring > 0.34 and ring < 0.42) or (absf(absf(u) - absf(v)) < 0.03 and d < 0.5):
				return c2
			return c1
		"mosaique":
			var cell := 5
			if x % cell == 0 or y % cell == 0:
				return c2
			var hv := _h(x / cell, y / cell, s)
			return _shade(c1.lerp(c2, hv * 0.3), 0.8 + hv * 0.35)
		"chevrons":
			var bw := 8
			var col := x / bw
			var yy := y + (x % bw) * (1 if col % 2 == 0 else -1) + (col % 2) * 8
			var plank := posmod(yy, 32)
			var id := int(floor(float(yy) / 32.0))
			if plank < 1 or x % bw == 0:
				return _shade(c2, 0.85)
			return _shade(c1, 0.88 + _h(col, id, s) * 0.2 + sin(float(plank) * 0.4) * 0.02)
		"dalles":
			var b := _bond(x, y, 32, 21, 1)
			if b[2]:
				return _shade(c2, 0.9)
			return _shade(c1, 0.88 + _h(b[0], b[1], s) * 0.2 + _n(fx, fy, 0.2, s) * 0.06)
		"autobloquant":
			var b := _bond(x, y, 16, 8, 1)
			var wav := (x % 8) == 4 and (y % 8) < 4
			if b[2] or wav:
				return _shade(c2, 0.9)
			return _shade(c1, 0.88 + _h(b[0], b[1], s) * 0.2)
		"enrobe":
			var r := _h(x, y, s)
			return _shade(c1.lerp(c2, r * r), 0.9 + _n(fx, fy, 0.3, s) * 0.08)
		"tatami":
			if x % 32 < 2 or y % 64 < 1:
				return c2
			return _shade(c1, 0.92 + sin(fy * 1.4) * 0.04 + _n(fx, fy, 0.2, s) * 0.04)
		"corten":
			var t := clampf(0.5 + _n(fx, fy, 0.1, s) * 1.4, 0.0, 1.0)
			var c := c1.lerp(c2, t)
			if _h(x, y, s) > 0.9:
				return _shade(c, 1.2)
			return c
		"solaire":
			# Cellules photovoltaïques : quadrillage fin, cadre clair tous les 32 px.
			if x % 32 == 0 or y % 32 == 0:
				return _shade(c2, 1.0)
			if x % 8 == 0 or y % 8 == 0:
				return _shade(c1, 1.35)
			return _shade(c1, 0.95 + _n(fx * 0.3, fy * 0.3, 0.1, s) * 0.05 + (0.08 if (x + y) % 32 < 3 else 0.0))
		"panneaux":
			if x % 32 == 0 or y % 21 == 0:
				return _shade(c2, 0.7)
			return _shade(c1, 0.95 + _n(fx * 0.3, fy * 0.3, 0.1, s) * 0.05)
		"pave_verre":
			var cell := 16
			if x % cell < 2 or y % cell < 2:
				return Color(0.85, 0.85, 0.82, 0.95)
			var u := float(x % cell) / cell - 0.5
			var v := float(y % cell) / cell - 0.5
			var g := c1.lerp(c2, clampf(1.0 - (u * u + v * v) * 3.0, 0.0, 1.0))
			g.a = 0.6
			return g
		"verre_depoli":
			var g := c1.lerp(c2, _h(x, y, s) * 0.5)
			g.a = 0.78
			return g
		"eau":
			var w := sin(fx * 0.25 + _n(fx, fy, 0.06, s) * 6.0) * 0.5 + 0.5
			var g := c1.lerp(c2, w * 0.35)
			g.a = 0.62
			return g
		"toile":
			var c := _shade(c1, 0.97 + ((x + y) % 2) * 0.03 + _n(fx, fy, 0.1, s) * 0.03)
			return c
		"rayures":
			return _shade(c1 if (x / 8) % 2 == 0 else c2, 0.97 + (y % 2) * 0.03)
		"cuir":
			var c := _shade(c1, 0.92 + _n(fx, fy, 0.35, s) * 0.12)
			if _h(x, y, s) > 0.97:
				return _shade(c2, 0.9)
			return c
		"colombage":
			var beam := 5
			var on := x < beam or x >= PX - beam or y < beam or y >= PX - beam
			on = on or absi(x - y) < 4
			if on:
				return _shade(c2, 0.9 + _n(fx, fy, 0.3, s) * 0.08)
			return _shade(c1, 1.0 + _n(fx, fy, 0.25, s) * 0.05)
		# --- Motifs du monde, des parcs, du zoo, du sport, des musées et des fêtes ---
		"azulejos":
			var u := x % 16
			var v := y % 16
			if u == 0 or v == 0:
				return _shade(c2, 1.3)
			var du := absi(u - 8)
			var dv := absi(v - 8)
			if du + dv < 4 or (du == dv and du < 7) or du + dv == 7:
				return _shade(c2, 0.95 + _h(x / 16, y / 16, s) * 0.08)
			return _shade(c1, 0.97 + _n(fx, fy, 0.3, s) * 0.03)
		"caillebotis":
			if x % 8 < 2:
				return _shade(c2, 0.55)
			return _shade(c1, 0.9 + _n(fx * 0.3, fy, 0.2, s) * 0.08 + (x / 8 % 2) * 0.04)
		"camouflage":
			var a := _n(fx, fy, 0.06, s)
			var b := _n(fx, fy, 0.09, s + 7)
			if a > 0.15:
				return _shade(c2, 0.95)
			if b > 0.2:
				return _shade(c1, 0.7)
			if a < -0.25:
				return _shade(c2, 0.55)
			return c1
		"confettis":
			var cx := x / 8
			var cy := y / 8
			var hv := _h(cx, cy, s)
			var px := x % 8 - int(_h(cx, cy, s + 1) * 4.0) - 2
			var py := y % 8 - int(_h(cx, cy, s + 2) * 4.0) - 2
			if hv > 0.35 and px * px + py * py <= 2:
				return Color.from_hsv(_h(cx, cy, s + 3), 0.8, 0.95)
			return _shade(c1, 0.97 + _n(fx, fy, 0.2, s) * 0.03)
		"damier_fin":
			return _shade(c1 if ((x / 4) + (y / 4)) % 2 == 0 else c2, 0.97 + _h(x, y, s) * 0.04)
		"ecorce":
			var w := sin(fx * 0.4 + _n(fx, fy, 0.05, s) * 8.0)
			if w > 0.75:
				return _shade(c2, 0.7)
			return _shade(c1.lerp(c2, (w + 1.0) * 0.25), 0.9 + _n(fx, fy * 0.2, 0.2, s) * 0.12)
		"etoiles":
			var hv := _h(x / 4, y / 4, s)
			if hv > 0.93 and x % 4 == 1 and y % 4 == 1:
				return _shade(c2, 1.0 + hv * 0.2)
			if hv > 0.985 and (x % 4 == 1 or y % 4 == 1) and absi(x % 4 - 1) + absi(y % 4 - 1) <= 2:
				return _shade(c2, 0.8)
			return _shade(c1, 0.95 + _n(fx, fy, 0.05, s) * 0.1)
		"gazon_synth":
			return _shade(c1.lerp(c2, _h(x, y / 2, s)), 0.92 + (0.04 if x % 3 == 0 else 0.0) + sin(fy * 0.9) * 0.03)
		"girafe":
			var cs := 16
			var bx := x / cs
			var by := y / cs
			var ox := int(_h(bx, by, s) * 4.0) - 2
			var oy := int(_h(bx, by, s + 5) * 4.0) - 2
			var u := x % cs - 8 - ox
			var v := y % cs - 8 - oy
			if absi(u) + absi(v) < 10 and u * u + v * v < 40:
				return _shade(c2, 0.92 + _n(fx, fy, 0.2, s) * 0.08)
			return _shade(c1, 0.98 + _n(fx, fy, 0.2, s) * 0.04)
		"grillage":
			var a := (x + y) % 8
			var b := (x - y + 64) % 8
			if a == 0 or b == 0:
				return _shade(c1, 1.0 + (_h(x, y, s) - 0.5) * 0.1)
			return Color(c2.r, c2.g, c2.b, 0.0)
		"hexagones":
			# Pavage en nid d'abeille (16 × 16 px répété sans couture sur 64).
			var r := y / 8
			var xx := x + (4 if r % 2 == 1 else 0)
			var u := xx % 8
			var v := y % 8
			if v == 0 or u == 0 or (v < 2 and (u == 1 or u == 7)):
				return _shade(c2, 0.9)
			return _shade(c1, 0.9 + _h(xx / 8, r, s) * 0.16)
		"kente":
			var bx := (x / 16) % 2
			var by := (y / 16) % 2
			var band := (x % 16 < 4) if bx == by else (y % 16 < 4)
			var c := c1 if band else c2
			if (x % 16 == 8 or y % 16 == 8) and not band:
				c = Color("2e7d32")
			return _shade(c, 0.95 + ((x + y) % 2) * 0.05)
		"laque":
			var gl := 0.25 * clampf(sin((fx - fy) * 0.05) * 3.0 - 2.0, 0.0, 1.0)
			return c1.lerp(Color.WHITE, gl).lerp(c2, _n(fx, fy, 0.05, s) * 0.1 + 0.05)
		"leopard":
			var cs := 11
			var bx := x / cs
			var by := y / cs
			var u := float(x % cs) - 5.0 - _h(bx, by, s) * 2.0
			var v := float(y % cs) - 5.0 - _h(bx, by, s + 1) * 2.0
			var d := u * u + v * v
			if x >= 55 or y >= 55:
				d = 99.0
			if d < 5.0:
				return _shade(c1, 0.75)
			if d < 11.0:
				return _shade(c2, 1.0)
			return _shade(c1, 0.98 + _n(fx, fy, 0.2, s) * 0.06)
		"liege":
			var hv := _h(x, y, s)
			return _shade(c1.lerp(c2, hv * hv), 0.9 + _n(fx, fy, 0.4, s) * 0.12)
		"losanges":
			var u := absi(x % 16 - 8)
			var v := absi(y % 16 - 8)
			if u + v == 8 or u + v == 7:
				return _shade(c2, 0.8)
			return _shade(c1 if u + v < 8 else c2, 0.97 + _n(fx, fy, 0.2, s) * 0.03)
		"parquet_sport":
			var plank := y / 4
			var off := int(_h(plank, 0, s) * 64.0)
			if (x + off) % 64 == 0 or y % 4 == 0:
				return _shade(c1, 0.82)
			var c := _shade(c1, 0.95 + _h((x + off) / 64, plank, s) * 0.1 + _n(fx * 0.2, fy, 0.2, s) * 0.04)
			if x == 32 or x == 33:
				return c2
			return c
		"pelouse_rayee":
			var c := c1 if (y / 16) % 2 == 0 else c2
			return _shade(c, 0.94 + _h(x, y, s) * 0.08)
		"pixels":
			return Color.from_hsv(_h(x / 8, y / 8, s), 0.75, 0.9).lerp(c1, 0.25)
		"plastique":
			var gl := 0.12 * clampf(sin((fx + fy * 0.5) * 0.08) * 2.0 - 1.0, 0.0, 1.0)
			return _shade(c1, 1.0 + gl + _n(fx, fy, 0.05, s) * 0.02)
		"pois":
			var u := x % 16 - 8
			var v := y % 16 - 8
			if u * u + v * v < 14:
				return c2
			return _shade(c1, 0.98 + _h(x, y, s) * 0.03)
		"rayures_h":
			return _shade(c1 if (y / 8) % 2 == 0 else c2, 0.97 + (x % 2) * 0.03)
		"shoji":
			if x % 16 < 2 or y % 21 < 2 or x == 63 or y == 63:
				var c := _shade(c2, 0.95 + _n(fx, fy, 0.3, s) * 0.06)
				c.a = 1.0
				return c
			var g := _shade(c1, 0.97 + _n(fx, fy, 0.4, s) * 0.04)
			g.a = 0.85
			return g
		"sieges":
			var u := x % 8
			var v := y % 16
			if v < 3:
				return _shade(c2, 0.6)
			if u == 0 or u == 7:
				return _shade(c2, 0.7)
			if v < 8:
				return _shade(c1, 1.08)
			return _shade(c1, 0.92)
		"strates":
			var w := fy + _n(fx, fy, 0.04, s) * 10.0
			var band := int(floorf(w / 6.0))
			var c := c1.lerp(c2, _h(band, 0, s))
			return _shade(c, 0.94 + _h(x, y, s) * 0.08)
		"tapis":
			var u := mini(mini(x, 63 - x), mini(y, 63 - y))
			if u < 4:
				return _shade(c2, 0.9)
			if u < 6:
				return Color("d8b25a")
			var du := absi(x - 32)
			var dv := absi(y - 32)
			if du + dv < 14 and du + dv > 10:
				return Color("d8b25a")
			if du + dv < 8:
				return _shade(c2, 1.0)
			return _shade(c1, 0.95 + ((x + y) % 2) * 0.05)
		"tartan":
			var a := (x % 32) < 8
			var b := (y % 32) < 8
			var c := c1
			if a and b:
				c = c2.lerp(Color.BLACK, 0.3)
			elif a or b:
				c = c1.lerp(c2, 0.6)
			if x % 32 == 20 or y % 32 == 20:
				c = c.lerp(Color("e8c84a"), 0.6)
			return _shade(c, 0.95 + ((x + y) % 2) * 0.05)
		"vagues":
			var w := sin(fx / 64.0 * TAU * 2.0) * 4.0
			var band := int(floorf((fy + w) / 8.0))
			return _shade(c1 if band % 2 == 0 else c2, 0.97 + _h(x, y, s) * 0.04)
		"versailles":
			var u := x % 32
			var v := y % 32
			if u < 2 or v < 2:
				return _shade(c1, 0.7)
			var diag := absi(u - v) < 2 or absi(u + v - 32) < 2
			if diag:
				return _shade(c2, 0.85)
			var c := c1 if ((u < 16) == (v < 16)) else c2
			return _shade(c, 0.9 + _n(fx * 0.4, fy, 0.2, s) * 0.1)
		"zebre":
			var w := sin((fx + sin(fy / 64.0 * TAU * 2.0) * 5.0) / 64.0 * TAU * 6.0 + _n(fx, fy, 0.05, s) * 1.5)
			return _shade(c2 if w > 0.25 else c1, 0.96 + _h(x, y, s) * 0.06)
		"boue":
			var t := clampf(0.5 + _n(fx, fy, 0.08, s) * 1.4, 0.0, 1.0)
			var c := c1.lerp(c2, t)
			if _n(fx, fy, 0.15, s + 9) > 0.35:
				c = c.lerp(Color(0.35, 0.3, 0.25), 0.4)
			return _shade(c, 0.92 + _h(x, y, s) * 0.08)
	return c1
