class_name Pictos
extends RefCounted
## Petites illustrations en couleur (SVG 96 × 64) pour les menus en images,
## quand le choix n'a pas de modèle 3D : façon de croiser une voie, actions de
## l'outil Carrefour, bords d'une route, météo, format d'image…
## Même principe que Icones (rendu par Image.load_svg_from_string, net à toute
## taille, aussi en --headless), mais en couleurs et au format paysage.
## Voir docs/menus-en-images.md.

const W := 96
const H := 64

const _HERBE := "#6f8f4e"
const _HERBE2 := "#5d7c40"
const _ENROBE := "#3a3d43"
const _MARQUE := "#f2f0e6"
const _TROTTOIR := "#c9c5bd"
const _CIEL := "#9cc9e6"
const _EAU := "#3f7fa8"
const _TERRE := "#8c7a5b"

## Route horizontale vue de dessus (y de 24 à 40) avec tirets au milieu.
const _ROUTE_H := "<rect y=\"24\" width=\"96\" height=\"16\" fill=\"" + _ENROBE + "\"/><path d=\"M2 32h8M18 32h8M34 32h8M54 32h8M70 32h8M86 32h8\" stroke=\"" + _MARQUE + "\" stroke-width=\"1.6\"/>"
const _ROUTE_V := "<rect x=\"40\" width=\"16\" height=\"64\" fill=\"" + _ENROBE + "\"/><path d=\"M48 2v7M48 55v7\" stroke=\"" + _MARQUE + "\" stroke-width=\"1.6\"/>"

const SVG := {
	# --- Croiser une autre voie (outils Route, Rail, Chemin) ---
	"croisement_auto": "<rect width=\"96\" height=\"64\" fill=\"" + _HERBE + "\"/>" + _ROUTE_H + _ROUTE_V
		+ "<path d=\"M40 24h16v16H40Z\" fill=\"" + _ENROBE + "\"/><path d=\"M37 25v14M59 25v14M41 21h14M41 43h14\" stroke=\"" + _MARQUE + "\" stroke-width=\"2\" stroke-dasharray=\"2 1.5\"/>"
		+ "<rect x=\"22\" y=\"34\" width=\"9\" height=\"5\" rx=\"1.2\" fill=\"#e76f51\"/><rect x=\"50\" y=\"8\" width=\"5\" height=\"9\" rx=\"1.2\" fill=\"#e9c46a\"/>",
	"pont": "<rect width=\"96\" height=\"64\" fill=\"" + _CIEL + "\"/><path d=\"M0 50h96v14H0Z\" fill=\"" + _HERBE + "\"/>"
		+ "<path d=\"M0 52h96v6H0Z\" fill=\"" + _ENROBE + "\"/><path d=\"M4 55h8M20 55h8M36 55h8M52 55h8M68 55h8M84 55h8\" stroke=\"" + _MARQUE + "\" stroke-width=\"1\"/>"
		+ "<rect x=\"14\" y=\"30\" width=\"6\" height=\"22\" fill=\"#a7a29a\"/><rect x=\"76\" y=\"30\" width=\"6\" height=\"22\" fill=\"#a7a29a\"/>"
		+ "<path d=\"M0 24h96v7H0Z\" fill=\"#b9b4aa\"/><path d=\"M0 20h96v4H0Z\" fill=\"" + _ENROBE + "\"/><path d=\"M0 18h96\" stroke=\"#e0ddd6\" stroke-width=\"2\"/>"
		+ "<rect x=\"30\" y=\"13\" width=\"12\" height=\"7\" rx=\"1.5\" fill=\"#e76f51\"/><circle cx=\"33\" cy=\"20\" r=\"1.6\" fill=\"#222\"/><circle cx=\"39\" cy=\"20\" r=\"1.6\" fill=\"#222\"/>",
	"tunnel": "<rect width=\"96\" height=\"64\" fill=\"" + _CIEL + "\"/><path d=\"M0 40C14 14 34 6 52 8s36 14 44 32v24H0Z\" fill=\"" + _HERBE + "\"/>"
		+ "<path d=\"M0 40C14 14 34 6 52 8s36 14 44 32\" fill=\"none\" stroke=\"" + _HERBE2 + "\" stroke-width=\"2\"/>"
		+ "<path d=\"M30 64V48a18 18 0 0 1 36 0v16Z\" fill=\"#8a8378\"/><path d=\"M35 64V49a13 13 0 0 1 26 0v15Z\" fill=\"#1d1f22\"/>"
		+ "<path d=\"M18 64l17-6h26l17 6Z\" fill=\"" + _ENROBE + "\"/><path d=\"M48 59v5\" stroke=\"" + _MARQUE + "\" stroke-width=\"1.4\"/>"
		+ "<rect x=\"8\" y=\"21\" width=\"12\" height=\"6\" rx=\"1.5\" fill=\"#e9c46a\"/><path d=\"M0 27h30\" stroke=\"" + _ENROBE + "\" stroke-width=\"3\"/>",
	# --- Outil Carrefour ---
	"regime": "<rect width=\"96\" height=\"64\" fill=\"" + _HERBE + "\"/>" + _ROUTE_H + _ROUTE_V
		+ "<path d=\"M40 24h16v16H40Z\" fill=\"" + _ENROBE + "\"/>"
		+ "<rect x=\"62\" y=\"4\" width=\"8\" height=\"19\" rx=\"2\" fill=\"#222\"/><circle cx=\"66\" cy=\"8\" r=\"2.3\" fill=\"#e63946\"/><circle cx=\"66\" cy=\"13.5\" r=\"2.3\" fill=\"#5c4a14\"/><circle cx=\"66\" cy=\"19\" r=\"2.3\" fill=\"#2d5a3a\"/>"
		+ "<path d=\"M26 44l4-4h6l4 4v6l-4 4h-6l-4-4Z\" fill=\"#d62828\" stroke=\"#fff\" stroke-width=\"1.2\"/><path d=\"M33 54v8\" stroke=\"#999\" stroke-width=\"1.5\"/>",
	"giratoire": "<rect width=\"96\" height=\"64\" fill=\"" + _HERBE + "\"/>" + _ROUTE_H + _ROUTE_V
		+ "<circle cx=\"48\" cy=\"32\" r=\"22\" fill=\"" + _ENROBE + "\"/><circle cx=\"48\" cy=\"32\" r=\"11\" fill=\"" + _HERBE2 + "\" stroke=\"" + _TROTTOIR + "\" stroke-width=\"2\"/>"
		+ "<circle cx=\"48\" cy=\"32\" r=\"16.5\" fill=\"none\" stroke=\"" + _MARQUE + "\" stroke-width=\"1.2\" stroke-dasharray=\"3 3\"/>"
		+ "<path d=\"M62 20l3-6 2 7Z\" fill=\"" + _MARQUE + "\"/><circle cx=\"45\" cy=\"29\" r=\"3\" fill=\"#3d8c5a\"/>",
	"echangeur": "<rect width=\"96\" height=\"64\" fill=\"" + _HERBE + "\"/>"
		+ "<path d=\"M0 22h96v20H0Z\" fill=\"" + _ENROBE + "\"/><path d=\"M0 32h96\" stroke=\"#b9b4aa\" stroke-width=\"2\"/><path d=\"M2 27h8M18 27h8M70 27h8M86 27h8M2 37h8M18 37h8M70 37h8M86 37h8\" stroke=\"" + _MARQUE + "\" stroke-width=\"1\"/>"
		+ "<path d=\"M14 22C28 12 36 8 42 4M82 42C68 52 60 56 54 60M14 42C28 52 36 56 42 60M82 22C68 12 60 8 54 4\" fill=\"none\" stroke=\"" + _ENROBE + "\" stroke-width=\"5\"/>"
		+ "<path d=\"M38 0h20v64H38Z\" fill=\"#55595f\"/><path d=\"M36 18v28M60 18v28\" stroke=\"#e0ddd6\" stroke-width=\"2\"/><path d=\"M48 2v6M48 56v6\" stroke=\"" + _MARQUE + "\" stroke-width=\"1.4\"/>",
	# --- Bords d'une route (coupe) ---
	"bords_trottoir": "<rect width=\"96\" height=\"64\" fill=\"" + _CIEL + "\"/><path d=\"M0 44h96v20H0Z\" fill=\"" + _TERRE + "\"/>"
		+ "<path d=\"M22 40h52v6H22Z\" fill=\"" + _ENROBE + "\"/><path d=\"M4 36h18v10H4ZM74 36h18v10H74Z\" fill=\"" + _TROTTOIR + "\"/><path d=\"M22 36v4M74 36v4\" stroke=\"#9e9a92\" stroke-width=\"1.6\"/>"
		+ "<circle cx=\"11\" cy=\"23\" r=\"2.6\" fill=\"#2b2d42\"/><path d=\"M11 26v6M11 32l-2.5 4M11 32l2.5 4M8 28h6\" stroke=\"#2b2d42\" stroke-width=\"1.8\" stroke-linecap=\"round\"/>"
		+ "<rect x=\"34\" y=\"32\" width=\"14\" height=\"8\" rx=\"2\" fill=\"#e76f51\"/>",
	"bords_accotement": "<rect width=\"96\" height=\"64\" fill=\"" + _CIEL + "\"/><path d=\"M0 44h96v20H0Z\" fill=\"" + _TERRE + "\"/>"
		+ "<path d=\"M0 42h20l4-2h48l4 2h20v4H0Z\" fill=\"" + _HERBE + "\"/><path d=\"M24 40h48v6H24Z\" fill=\"" + _ENROBE + "\"/><path d=\"M18 41h6M72 41h6\" stroke=\"#a39a88\" stroke-width=\"3\"/>"
		+ "<path d=\"M25 41h2M69 41h2\" stroke=\"" + _MARQUE + "\" stroke-width=\"1.4\"/><rect x=\"36\" y=\"32\" width=\"14\" height=\"8\" rx=\"2\" fill=\"#e76f51\"/>",
	"bords_aucun": "<rect width=\"96\" height=\"64\" fill=\"" + _CIEL + "\"/><path d=\"M0 44h96v20H0Z\" fill=\"" + _TERRE + "\"/>"
		+ "<path d=\"M8 40h80v6H8Z\" fill=\"" + _ENROBE + "\"/><path d=\"M6 39h3v7H6ZM87 39h3v7h-3Z\" fill=\"#9e9a92\"/><path d=\"M0 44h6M90 44h6\" stroke=\"" + _HERBE + "\" stroke-width=\"4\"/>"
		+ "<rect x=\"30\" y=\"32\" width=\"14\" height=\"8\" rx=\"2\" fill=\"#e76f51\"/>",
	# --- Météo (Horloge) ---
	"meteo_auto": "<rect width=\"96\" height=\"64\" fill=\"#8fc3e6\"/><path d=\"M96 0v64H40Z\" fill=\"#7d8a99\"/><circle cx=\"28\" cy=\"24\" r=\"11\" fill=\"#ffd166\"/><path d=\"M28 6v5M28 37v5M10 24h5M41 24h5M15 11l3.5 3.5M38 34l3.5 3.5M15 37l3.5-3.5\" stroke=\"#ffd166\" stroke-width=\"2.4\" stroke-linecap=\"round\"/>"
		+ "<path d=\"M54 36h26a8 8 0 0 0 0-16 11 11 0 0 0-21-2 8 8 0 0 0-5 18Z\" fill=\"#eef2f5\"/><path d=\"M60 42l-3 7M70 42l-3 7M80 42l-3 7\" stroke=\"#bfe3ff\" stroke-width=\"2.4\" stroke-linecap=\"round\"/>"
		+ "<path d=\"M0 52h96v12H0Z\" fill=\"" + _HERBE + "\"/><circle cx=\"48\" cy=\"54\" r=\"7\" fill=\"#fff\" stroke=\"#2b2d42\" stroke-width=\"1.6\"/><path d=\"M48 50v4l3 2\" fill=\"none\" stroke=\"#2b2d42\" stroke-width=\"1.6\" stroke-linecap=\"round\"/>",
	"meteo_soleil": "<rect width=\"96\" height=\"64\" fill=\"#7cc0ee\"/><circle cx=\"48\" cy=\"26\" r=\"13\" fill=\"#ffd166\"/><path d=\"M48 4v6M48 42v6M26 26h6M64 26h6M32.5 10.5l4 4M59.5 37.5l4 4M32.5 41.5l4-4M59.5 14.5l4-4\" stroke=\"#ffd166\" stroke-width=\"2.6\" stroke-linecap=\"round\"/><path d=\"M0 52h96v12H0Z\" fill=\"" + _HERBE + "\"/>",
	"meteo_nuageux": "<rect width=\"96\" height=\"64\" fill=\"#8fc3e6\"/><circle cx=\"36\" cy=\"22\" r=\"11\" fill=\"#ffd166\"/><path d=\"M36 5v4M19 22h4M23 10l3 3M49 10l-3 3\" stroke=\"#ffd166\" stroke-width=\"2.4\" stroke-linecap=\"round\"/><path d=\"M38 42h34a10 10 0 0 0 0-20 14 14 0 0 0-27-2 10 10 0 0 0-7 22Z\" fill=\"#f4f6f8\"/><path d=\"M0 52h96v12H0Z\" fill=\"" + _HERBE + "\"/>",
	"meteo_couvert": "<rect width=\"96\" height=\"64\" fill=\"#a9b4bf\"/><path d=\"M10 30h30a9 9 0 0 0 0-18 12 12 0 0 0-23-2 9 9 0 0 0-7 20Z\" fill=\"#dde2e7\"/><path d=\"M40 44h40a10 10 0 0 0 0-20 14 14 0 0 0-27-2 11 11 0 0 0-13 22Z\" fill=\"#c6cdd4\"/><path d=\"M0 52h96v12H0Z\" fill=\"#5f7a48\"/>",
	"meteo_pluie": "<rect width=\"96\" height=\"64\" fill=\"#8b97a3\"/><path d=\"M24 30h44a11 11 0 0 0 0-22 15 15 0 0 0-29-2 12 12 0 0 0-15 24Z\" fill=\"#b9c2cb\"/><path d=\"M30 36l-4 9M42 36l-4 9M54 36l-4 9M66 36l-4 9M36 46l-3 6M48 46l-3 6M60 46l-3 6\" stroke=\"#cfe8ff\" stroke-width=\"2.4\" stroke-linecap=\"round\"/><path d=\"M0 54h96v10H0Z\" fill=\"#55703f\"/>",
	"meteo_orage": "<rect width=\"96\" height=\"64\" fill=\"#4f5866\"/><path d=\"M22 30h46a11 11 0 0 0 0-22 15 15 0 0 0-29-2 12 12 0 0 0-17 24Z\" fill=\"#7d8794\"/><path d=\"M50 30l-8 14h8l-6 16 16-20h-9l6-10Z\" fill=\"#ffd166\"/><path d=\"M28 36l-4 9M72 36l-4 9\" stroke=\"#cfe8ff\" stroke-width=\"2.2\" stroke-linecap=\"round\"/><path d=\"M0 56h96v8H0Z\" fill=\"#3f5530\"/>",
	"meteo_neige": "<rect width=\"96\" height=\"64\" fill=\"#b9c7d6\"/><path d=\"M24 28h44a11 11 0 0 0 0-22 15 15 0 0 0-29-2 12 12 0 0 0-15 24Z\" fill=\"#eef2f6\"/><g fill=\"#fff\"><circle cx=\"30\" cy=\"38\" r=\"2.2\"/><circle cx=\"44\" cy=\"42\" r=\"2.2\"/><circle cx=\"58\" cy=\"37\" r=\"2.2\"/><circle cx=\"70\" cy=\"43\" r=\"2.2\"/><circle cx=\"37\" cy=\"48\" r=\"2.2\"/><circle cx=\"64\" cy=\"49\" r=\"2.2\"/></g><path d=\"M0 52c20-4 40 2 60-2s28 0 36 2v12H0Z\" fill=\"#fbfdff\"/>",
	"meteo_brouillard": "<rect width=\"96\" height=\"64\" fill=\"#c9cfd4\"/><path d=\"M14 40l8-16 8 16Z M66 40l8-18 8 18Z\" fill=\"#9aa6a0\" opacity=\".6\"/><path d=\"M8 20h50M24 30h60M6 40h46M30 50h58\" stroke=\"#eef1f3\" stroke-width=\"4\" stroke-linecap=\"round\"/><path d=\"M0 56h96v8H0Z\" fill=\"#8e9c88\"/>",
	# --- Biomes (Paysage) ---
	"biome_4": "<rect width=\"96\" height=\"64\" fill=\"#9cc9e6\"/><path d=\"M0 44h96v20H0Z\" fill=\"#4f6b3a\"/><g fill=\"#2f5a33\"><path d=\"M12 48l9-28 9 28Z\"/><path d=\"M30 50l10-34 10 34Z\"/><path d=\"M52 48l9-26 9 26Z\"/><path d=\"M70 50l10-32 10 32Z\"/></g><g fill=\"#3d7342\"><path d=\"M22 56l7-20 7 20Z\"/><path d=\"M44 58l8-22 8 22Z\"/><path d=\"M64 58l7-19 7 19Z\"/></g>",
	"biome_6": "<rect width=\"96\" height=\"64\" fill=\"#9cc9e6\"/><path d=\"M0 30c20-6 50-6 96 2v32H0Z\" fill=\"#7fa356\"/><path d=\"M0 44c30-4 60-4 96 0v20H0Z\" fill=\"#8db55f\"/><g fill=\"#f6f1e8\"><circle cx=\"18\" cy=\"50\" r=\"1.8\"/><circle cx=\"40\" cy=\"56\" r=\"1.8\"/><circle cx=\"70\" cy=\"52\" r=\"1.8\"/></g><g fill=\"#ffd166\"><circle cx=\"28\" cy=\"57\" r=\"1.8\"/><circle cx=\"58\" cy=\"48\" r=\"1.8\"/><circle cx=\"84\" cy=\"58\" r=\"1.8\"/></g><path d=\"M10 40v-4M12 40v-5M50 46v-4M52 46v-5M80 40v-4\" stroke=\"#5d7c40\" stroke-width=\"1.2\"/>",
	"biome_7": "<rect width=\"96\" height=\"64\" fill=\"#9cc9e6\"/><path d=\"M0 26h96v38H0Z\" fill=\"#d9b84e\"/><path d=\"M0 26h48v38H0Z\" fill=\"#7fa356\"/><path d=\"M4 30l-4 34M14 30l-8 34M24 30l-12 34M34 30l-16 34M44 30l-20 34\" stroke=\"#6a8e46\" stroke-width=\"2\"/><path d=\"M52 30l2 34M62 30l6 34M72 30l10 34M82 30l14 34M92 30l18 34\" stroke=\"#c39f35\" stroke-width=\"2\"/>",
	"biome_5": "<rect width=\"96\" height=\"64\" fill=\"#a6d0e8\"/><path d=\"M0 40h96v24H0Z\" fill=\"#a39361\"/><g fill=\"#6b7d3e\"><ellipse cx=\"18\" cy=\"44\" rx=\"10\" ry=\"7\"/><ellipse cx=\"46\" cy=\"50\" rx=\"12\" ry=\"8\"/><ellipse cx=\"76\" cy=\"43\" rx=\"9\" ry=\"6\"/><ellipse cx=\"30\" cy=\"58\" rx=\"8\" ry=\"5\"/><ellipse cx=\"68\" cy=\"59\" rx=\"10\" ry=\"6\"/></g>",
	"biome_8": "<rect width=\"96\" height=\"64\" fill=\"#f2d29b\"/><circle cx=\"76\" cy=\"14\" r=\"8\" fill=\"#fff3c4\"/><path d=\"M0 40c18-10 34-10 52 0s30 8 44 0v24H0Z\" fill=\"#e2b066\"/><path d=\"M0 52c22-8 44-4 60 2s26 2 36-2v12H0Z\" fill=\"#d39b4f\"/><path d=\"M24 50V30a3 3 0 0 1 6 0v20M30 40h4v-6a2 2 0 0 1 4 0v8h-8M24 38h-4v-5a2 2 0 0 0-4 0v7h8\" fill=\"#4f7a3a\"/>",
	"biome_12": "<rect width=\"96\" height=\"64\" fill=\"#8fd0f0\"/><path d=\"M0 22h96v14H0Z\" fill=\"#2f86b8\"/><path d=\"M0 34c16-3 30 3 48 0s32-3 48 0v4H0Z\" fill=\"#ffffff\" opacity=\".8\"/><path d=\"M0 37h96v27H0Z\" fill=\"#ecd9a6\"/><path d=\"M60 50l12-8 2 10Z\" fill=\"#e63946\"/><path d=\"M72 42v16\" stroke=\"#8a6d4a\" stroke-width=\"1.5\"/>",
	"biome_3": "<rect width=\"96\" height=\"64\" fill=\"#a9cde6\"/><path d=\"M0 64V40l14-14 10 8 14-22 16 18 10-6 18 20 14-8v28Z\" fill=\"#8d8a84\"/><path d=\"M38 12l16 18-8-2-8 10-6-10Z M74 38l8-4 14 8-12 0Z\" fill=\"#b3afa7\"/><path d=\"M0 64V52h96v12Z\" fill=\"#7a766f\"/>",
	"biome_13": "<rect width=\"96\" height=\"64\" fill=\"#b9d4ea\"/><path d=\"M0 64V38l22-22 16 14 20-20 38 34v20Z\" fill=\"#f7fbff\"/><path d=\"M22 16l16 14-6 2-10-6-8 6Z M58 10l12 12-6-1-6 5-6-6Z\" fill=\"#d6e4f0\"/><path d=\"M0 52c30-4 60-4 96 0v12H0Z\" fill=\"#ffffff\"/>",
	"biome_9": "<rect width=\"96\" height=\"64\" fill=\"#a9c9c4\"/><path d=\"M0 36h96v28H0Z\" fill=\"#5e7a4a\"/><g fill=\"#567f86\"><ellipse cx=\"26\" cy=\"46\" rx=\"16\" ry=\"5\"/><ellipse cx=\"70\" cy=\"54\" rx=\"18\" ry=\"5\"/></g><path d=\"M12 46v-14M16 46v-10M50 52v-16M54 52v-12M86 50v-14M82 50v-10\" stroke=\"#3f5a2e\" stroke-width=\"1.6\"/><g fill=\"#6b4b2a\"><rect x=\"10.8\" y=\"29\" width=\"2.4\" height=\"6\" rx=\"1.2\"/><rect x=\"48.8\" y=\"33\" width=\"2.4\" height=\"6\" rx=\"1.2\"/><rect x=\"84.8\" y=\"33\" width=\"2.4\" height=\"6\" rx=\"1.2\"/></g>",
	"biome_11": "<rect width=\"96\" height=\"64\" fill=\"#c2d6e2\"/><path d=\"M0 38h96v26H0Z\" fill=\"#8f8e6a\"/><g fill=\"#b5a86e\"><ellipse cx=\"18\" cy=\"46\" rx=\"9\" ry=\"3\"/><ellipse cx=\"50\" cy=\"54\" rx=\"12\" ry=\"3.5\"/><ellipse cx=\"80\" cy=\"44\" rx=\"8\" ry=\"3\"/></g><g fill=\"#f7fbff\"><ellipse cx=\"34\" cy=\"58\" rx=\"10\" ry=\"3\"/><ellipse cx=\"72\" cy=\"58\" rx=\"7\" ry=\"2.5\"/></g><path d=\"M0 38l20-8 18 6 22-10 36 12\" fill=\"#a0a6a6\"/>",
	# --- Photo : scène d'exemple pour les filtres ---
	"photo_scene": "<rect width=\"96\" height=\"64\" fill=\"#79b8e6\"/><circle cx=\"76\" cy=\"14\" r=\"7\" fill=\"#ffd166\"/><path d=\"M0 42c20-10 40-12 60-4s28 4 36 0v26H0Z\" fill=\"#6f9a4e\"/><path d=\"M0 54c30-6 60-6 96 0v10H0Z\" fill=\"#5a8040\"/>"
		+ "<path d=\"M22 34l10-8 10 8v14H22Z\" fill=\"#f1e3c6\"/><path d=\"M20 35l12-10 12 10Z\" fill=\"#c0583f\"/><rect x=\"29\" y=\"40\" width=\"5\" height=\"8\" fill=\"#6b4b2a\"/><rect x=\"36\" y=\"37\" width=\"4\" height=\"4\" fill=\"#9cd0ff\"/>"
		+ "<path d=\"M62 48V36\" stroke=\"#6b4b2a\" stroke-width=\"2.4\"/><circle cx=\"62\" cy=\"32\" r=\"7\" fill=\"#3d7342\"/><path d=\"M50 58h14\" stroke=\"#e76f51\" stroke-width=\"4\" stroke-linecap=\"round\"/>",
	"autre_annee": "<rect width=\"96\" height=\"64\" fill=\"#2a3a44\"/><rect x=\"28\" y=\"10\" width=\"40\" height=\"46\" rx=\"4\" fill=\"#f6f1e8\"/><path d=\"M28 14a4 4 0 0 1 4-4h32a4 4 0 0 1 4 4v9H28Z\" fill=\"#e63946\"/><path d=\"M38 6v8M58 6v8\" stroke=\"#ccc\" stroke-width=\"3\" stroke-linecap=\"round\"/>"
		+ "<g fill=\"#b7c4bb\"><rect x=\"33\" y=\"28\" width=\"6\" height=\"5\"/><rect x=\"45\" y=\"28\" width=\"6\" height=\"5\"/><rect x=\"57\" y=\"28\" width=\"6\" height=\"5\"/><rect x=\"33\" y=\"37\" width=\"6\" height=\"5\"/><rect x=\"57\" y=\"37\" width=\"6\" height=\"5\"/><rect x=\"33\" y=\"46\" width=\"6\" height=\"5\"/><rect x=\"45\" y=\"46\" width=\"6\" height=\"5\"/></g><rect x=\"44\" y=\"36\" width=\"8\" height=\"7\" fill=\"#e63946\"/>"
		+ "<path d=\"M70 50l12-16 4 3-12 16-5 2Z\" fill=\"#ffd166\" stroke=\"#2b2d42\" stroke-width=\"1.2\" stroke-linejoin=\"round\"/>",
	# --- Formes de toit (Atelier, personnalisation) ---
	"toit_gable": "<rect width=\"96\" height=\"64\" fill=\"" + _CIEL + "\"/><path d=\"M0 54h96v10H0Z\" fill=\"" + _HERBE + "\"/><rect x=\"26\" y=\"32\" width=\"44\" height=\"24\" fill=\"#efe3cf\"/><rect x=\"44\" y=\"42\" width=\"8\" height=\"14\" fill=\"#7a4e2d\"/><rect x=\"31\" y=\"38\" width=\"8\" height=\"7\" fill=\"#7fb3d5\"/><rect x=\"57\" y=\"38\" width=\"8\" height=\"7\" fill=\"#7fb3d5\"/>" + "<path d=\"M20 33L48 10L76 33Z\" fill=\"#b5523b\"/><path d=\"M20 33L48 10L76 33\" fill=\"none\" stroke=\"#7d3526\" stroke-width=\"2\"/>",
	"toit_hip": "<rect width=\"96\" height=\"64\" fill=\"" + _CIEL + "\"/><path d=\"M0 54h96v10H0Z\" fill=\"" + _HERBE + "\"/><rect x=\"26\" y=\"32\" width=\"44\" height=\"24\" fill=\"#efe3cf\"/><rect x=\"44\" y=\"42\" width=\"8\" height=\"14\" fill=\"#7a4e2d\"/><rect x=\"31\" y=\"38\" width=\"8\" height=\"7\" fill=\"#7fb3d5\"/><rect x=\"57\" y=\"38\" width=\"8\" height=\"7\" fill=\"#7fb3d5\"/>" + "<path d=\"M20 33L36 14H60L76 33Z\" fill=\"#b5523b\"/><path d=\"M36 14L30 33M60 14L66 33\" stroke=\"#7d3526\" stroke-width=\"1.5\"/>",
	"toit_flat": "<rect width=\"96\" height=\"64\" fill=\"" + _CIEL + "\"/><path d=\"M0 54h96v10H0Z\" fill=\"" + _HERBE + "\"/><rect x=\"26\" y=\"32\" width=\"44\" height=\"24\" fill=\"#efe3cf\"/><rect x=\"44\" y=\"42\" width=\"8\" height=\"14\" fill=\"#7a4e2d\"/><rect x=\"31\" y=\"38\" width=\"8\" height=\"7\" fill=\"#7fb3d5\"/><rect x=\"57\" y=\"38\" width=\"8\" height=\"7\" fill=\"#7fb3d5\"/>" + "<rect x=\"24\" y=\"27\" width=\"48\" height=\"6\" fill=\"#8d8f93\"/><rect x=\"30\" y=\"22\" width=\"10\" height=\"5\" fill=\"#b9bcc0\"/><path d=\"M54 20v7M60 20v7\" stroke=\"#5aa05a\" stroke-width=\"3\"/>",
	"toit_mansard": "<rect width=\"96\" height=\"64\" fill=\"" + _CIEL + "\"/><path d=\"M0 54h96v10H0Z\" fill=\"" + _HERBE + "\"/><rect x=\"26\" y=\"32\" width=\"44\" height=\"24\" fill=\"#efe3cf\"/><rect x=\"44\" y=\"42\" width=\"8\" height=\"14\" fill=\"#7a4e2d\"/><rect x=\"31\" y=\"38\" width=\"8\" height=\"7\" fill=\"#7fb3d5\"/><rect x=\"57\" y=\"38\" width=\"8\" height=\"7\" fill=\"#7fb3d5\"/>" + "<path d=\"M22 33L28 18H68L74 33Z\" fill=\"#4d5a6a\"/><path d=\"M28 18L36 10H60L68 18Z\" fill=\"#3a4553\"/><rect x=\"36\" y=\"22\" width=\"7\" height=\"8\" fill=\"#efe3cf\"/><rect x=\"53\" y=\"22\" width=\"7\" height=\"8\" fill=\"#efe3cf\"/>",
	"toit_curved": "<rect width=\"96\" height=\"64\" fill=\"" + _CIEL + "\"/><path d=\"M0 54h96v10H0Z\" fill=\"" + _HERBE + "\"/><rect x=\"26\" y=\"32\" width=\"44\" height=\"24\" fill=\"#efe3cf\"/><rect x=\"44\" y=\"42\" width=\"8\" height=\"14\" fill=\"#7a4e2d\"/><rect x=\"31\" y=\"38\" width=\"8\" height=\"7\" fill=\"#7fb3d5\"/><rect x=\"57\" y=\"38\" width=\"8\" height=\"7\" fill=\"#7fb3d5\"/>" + "<path d=\"M14 28Q22 33 30 26L42 14H54L66 26Q74 33 82 28L76 33H20Z\" fill=\"#3d6b5a\"/><path d=\"M42 14H54L52 10H44Z\" fill=\"#c0392b\"/>",
	"toit_shed": "<rect width=\"96\" height=\"64\" fill=\"" + _CIEL + "\"/><path d=\"M0 54h96v10H0Z\" fill=\"" + _HERBE + "\"/><rect x=\"26\" y=\"32\" width=\"44\" height=\"24\" fill=\"#efe3cf\"/><rect x=\"44\" y=\"42\" width=\"8\" height=\"14\" fill=\"#7a4e2d\"/><rect x=\"31\" y=\"38\" width=\"8\" height=\"7\" fill=\"#7fb3d5\"/><rect x=\"57\" y=\"38\" width=\"8\" height=\"7\" fill=\"#7fb3d5\"/>" + "<path d=\"M22 33L22 22L74 12L74 33Z\" fill=\"#8a6e4b\"/><path d=\"M20 22L76 11\" stroke=\"#5e4a30\" stroke-width=\"2.5\"/>",
	"toit_thatch": "<rect width=\"96\" height=\"64\" fill=\"" + _CIEL + "\"/><path d=\"M0 54h96v10H0Z\" fill=\"" + _HERBE + "\"/><rect x=\"26\" y=\"32\" width=\"44\" height=\"24\" fill=\"#efe3cf\"/><rect x=\"44\" y=\"42\" width=\"8\" height=\"14\" fill=\"#7a4e2d\"/><rect x=\"31\" y=\"38\" width=\"8\" height=\"7\" fill=\"#7fb3d5\"/><rect x=\"57\" y=\"38\" width=\"8\" height=\"7\" fill=\"#7fb3d5\"/>" + "<path d=\"M16 36Q20 18 48 8Q76 18 80 36Z\" fill=\"#d9b35a\"/><path d=\"M24 30q6-8 12-14M40 32q4-10 8-20M58 32q-2-10-6-18M72 30q-6-8-12-14\" fill=\"none\" stroke=\"#b08a3a\" stroke-width=\"1.5\"/>",
	# --- Timbres des cartes postales ---
	"timbre_montagne": "<rect width=\"96\" height=\"64\" fill=\"#f4ecd8\"/><rect x=\"6\" y=\"6\" width=\"84\" height=\"52\" fill=\"" + _CIEL + "\"/>" + "<path d=\"M6 58L32 18L46 36L60 14L90 58Z\" fill=\"#6c7a89\"/><path d=\"M32 18L38 28L28 26ZM60 14L67 25L54 24Z\" fill=\"#fff\"/>" + "<path d=\"M0 0h96v64H0Z\" fill=\"none\" stroke=\"#2a3a44\" stroke-width=\"4\" stroke-dasharray=\"3 3\"/>",
	"timbre_lac": "<rect width=\"96\" height=\"64\" fill=\"#f4ecd8\"/><rect x=\"6\" y=\"6\" width=\"84\" height=\"52\" fill=\"" + _CIEL + "\"/>" + "<path d=\"M6 30L26 14L44 30L62 18L90 32V58H6Z\" fill=\"" + _HERBE + "\"/><path d=\"M6 40h84v18H6Z\" fill=\"" + _EAU + "\"/><path d=\"M40 44l10 0-5 6Z\" fill=\"#fff\"/><path d=\"M45 36v8\" stroke=\"#fff\" stroke-width=\"1.4\"/>" + "<path d=\"M0 0h96v64H0Z\" fill=\"none\" stroke=\"#2a3a44\" stroke-width=\"4\" stroke-dasharray=\"3 3\"/>",
	"timbre_clocher": "<rect width=\"96\" height=\"64\" fill=\"#f4ecd8\"/><rect x=\"6\" y=\"6\" width=\"84\" height=\"52\" fill=\"" + _CIEL + "\"/>" + "<path d=\"M6 50h84v8H6Z\" fill=\"" + _HERBE + "\"/><rect x=\"40\" y=\"22\" width=\"16\" height=\"30\" fill=\"#e7dcc6\"/><path d=\"M38 22L48 6L58 22Z\" fill=\"#7d3526\"/><circle cx=\"48\" cy=\"30\" r=\"4\" fill=\"#fff\" stroke=\"#333\"/><rect x=\"45\" y=\"40\" width=\"6\" height=\"12\" fill=\"#6b4b2a\"/>" + "<path d=\"M0 0h96v64H0Z\" fill=\"none\" stroke=\"#2a3a44\" stroke-width=\"4\" stroke-dasharray=\"3 3\"/>",
	"timbre_tramway": "<rect width=\"96\" height=\"64\" fill=\"#f4ecd8\"/><rect x=\"6\" y=\"6\" width=\"84\" height=\"52\" fill=\"" + _CIEL + "\"/>" + "<path d=\"M6 50h84v8H6Z\" fill=\"#8d8f93\"/><path d=\"M6 18h84\" stroke=\"#333\" stroke-width=\"1\"/><path d=\"M48 18l-4 8\" stroke=\"#333\" stroke-width=\"1.4\"/><rect x=\"20\" y=\"26\" width=\"56\" height=\"22\" rx=\"4\" fill=\"#d62828\"/><g fill=\"#cfe8f7\"><rect x=\"25\" y=\"30\" width=\"9\" height=\"8\"/><rect x=\"38\" y=\"30\" width=\"9\" height=\"8\"/><rect x=\"51\" y=\"30\" width=\"9\" height=\"8\"/><rect x=\"64\" y=\"30\" width=\"8\" height=\"8\"/></g><circle cx=\"30\" cy=\"49\" r=\"3\" fill=\"#222\"/><circle cx=\"66\" cy=\"49\" r=\"3\" fill=\"#222\"/>" + "<path d=\"M0 0h96v64H0Z\" fill=\"none\" stroke=\"#2a3a44\" stroke-width=\"4\" stroke-dasharray=\"3 3\"/>",
	"timbre_soleil": "<rect width=\"96\" height=\"64\" fill=\"#f4ecd8\"/><rect x=\"6\" y=\"6\" width=\"84\" height=\"52\" fill=\"" + _CIEL + "\"/>" + "<circle cx=\"48\" cy=\"32\" r=\"11\" fill=\"#ffd166\"/><path d=\"M48 12v6M48 46v6M28 32h6M62 32h6M34 18l4 4M58 42l4 4M34 46l4-4M58 22l4-4\" stroke=\"#f4a261\" stroke-width=\"3\" stroke-linecap=\"round\"/>" + "<path d=\"M0 0h96v64H0Z\" fill=\"none\" stroke=\"#2a3a44\" stroke-width=\"4\" stroke-dasharray=\"3 3\"/>",
	"timbre_stade": "<rect width=\"96\" height=\"64\" fill=\"#f4ecd8\"/><rect x=\"6\" y=\"6\" width=\"84\" height=\"52\" fill=\"" + _CIEL + "\"/>" + "<path d=\"M6 48h84v10H6Z\" fill=\"" + _HERBE + "\"/><ellipse cx=\"48\" cy=\"40\" rx=\"36\" ry=\"14\" fill=\"#c9c5bd\"/><ellipse cx=\"48\" cy=\"40\" rx=\"26\" ry=\"8\" fill=\"#3d8c5a\"/><path d=\"M48 32v16M22 40h52\" stroke=\"#fff\" stroke-width=\"1\"/><path d=\"M16 18v14M80 18v14\" stroke=\"#555\" stroke-width=\"2\"/><circle cx=\"16\" cy=\"17\" r=\"3\" fill=\"#ffe9a8\"/><circle cx=\"80\" cy=\"17\" r=\"3\" fill=\"#ffe9a8\"/>" + "<path d=\"M0 0h96v64H0Z\" fill=\"none\" stroke=\"#2a3a44\" stroke-width=\"4\" stroke-dasharray=\"3 3\"/>",
	# --- Pièces creusées sous terre ---
	"sous_cave": "<rect width=\"96\" height=\"64\" fill=\"" + _TERRE + "\"/><path d=\"M0 0h96v10H0Z\" fill=\"" + _HERBE + "\"/><rect x=\"10\" y=\"20\" width=\"76\" height=\"38\" fill=\"#d8d2c4\"/><path d=\"M10 20h76v38H10Z\" fill=\"none\" stroke=\"#6e6656\" stroke-width=\"2\"/>" + "<g fill=\"#7a4e2d\"><rect x=\"16\" y=\"40\" width=\"18\" height=\"16\" rx=\"8\"/><rect x=\"38\" y=\"40\" width=\"18\" height=\"16\" rx=\"8\"/></g><path d=\"M60 30h20M60 40h20M60 50h20\" stroke=\"#6b4b2a\" stroke-width=\"2\"/><g fill=\"#5a2a3a\"><rect x=\"62\" y=\"24\" width=\"3\" height=\"6\"/><rect x=\"70\" y=\"24\" width=\"3\" height=\"6\"/><rect x=\"66\" y=\"34\" width=\"3\" height=\"6\"/></g>",
	"sous_parking": "<rect width=\"96\" height=\"64\" fill=\"" + _TERRE + "\"/><path d=\"M0 0h96v10H0Z\" fill=\"" + _HERBE + "\"/><rect x=\"10\" y=\"20\" width=\"76\" height=\"38\" fill=\"#d8d2c4\"/><path d=\"M10 20h76v38H10Z\" fill=\"none\" stroke=\"#6e6656\" stroke-width=\"2\"/>" + "<path d=\"M10 50h76\" stroke=\"#f2f0e6\" stroke-width=\"1\"/><path d=\"M30 30v28M56 30v28\" stroke=\"#f2f0e6\" stroke-width=\"1.5\"/><rect x=\"14\" y=\"40\" width=\"13\" height=\"9\" rx=\"2\" fill=\"#e76f51\"/><rect x=\"60\" y=\"40\" width=\"13\" height=\"9\" rx=\"2\" fill=\"#2a6f97\"/><circle cx=\"43\" cy=\"32\" r=\"8\" fill=\"#2a6f97\"/><path d=\"M40 37v-10h4a3 3 0 0 1 0 6h-4\" fill=\"none\" stroke=\"#fff\" stroke-width=\"2\"/>",
	"sous_entrepot": "<rect width=\"96\" height=\"64\" fill=\"" + _TERRE + "\"/><path d=\"M0 0h96v10H0Z\" fill=\"" + _HERBE + "\"/><rect x=\"10\" y=\"20\" width=\"76\" height=\"38\" fill=\"#d8d2c4\"/><path d=\"M10 20h76v38H10Z\" fill=\"none\" stroke=\"#6e6656\" stroke-width=\"2\"/>" + "<g fill=\"#b08a5a\" stroke=\"#6b4b2a\" stroke-width=\"1\"><rect x=\"16\" y=\"42\" width=\"14\" height=\"14\"/><rect x=\"32\" y=\"42\" width=\"14\" height=\"14\"/><rect x=\"24\" y=\"28\" width=\"14\" height=\"14\"/><rect x=\"58\" y=\"36\" width=\"20\" height=\"20\"/></g>",
	"sous_technique": "<rect width=\"96\" height=\"64\" fill=\"" + _TERRE + "\"/><path d=\"M0 0h96v10H0Z\" fill=\"" + _HERBE + "\"/><rect x=\"10\" y=\"20\" width=\"76\" height=\"38\" fill=\"#d8d2c4\"/><path d=\"M10 20h76v38H10Z\" fill=\"none\" stroke=\"#6e6656\" stroke-width=\"2\"/>" + "<rect x=\"18\" y=\"30\" width=\"22\" height=\"26\" fill=\"#7d8a96\"/><circle cx=\"29\" cy=\"40\" r=\"5\" fill=\"#ffd166\"/><path d=\"M44 34h40M44 44h40\" stroke=\"#2a6f97\" stroke-width=\"4\"/><path d=\"M44 52h40\" stroke=\"#e63946\" stroke-width=\"3\"/>",
	"sous_bunker": "<rect width=\"96\" height=\"64\" fill=\"" + _TERRE + "\"/><path d=\"M0 0h96v10H0Z\" fill=\"" + _HERBE + "\"/><rect x=\"10\" y=\"20\" width=\"76\" height=\"38\" fill=\"#d8d2c4\"/><path d=\"M10 20h76v38H10Z\" fill=\"none\" stroke=\"#6e6656\" stroke-width=\"2\"/>" + "<rect x=\"10\" y=\"20\" width=\"76\" height=\"38\" fill=\"#8b9183\"/><path d=\"M10 20h76v38H10Z\" fill=\"none\" stroke=\"#4b5045\" stroke-width=\"5\"/><circle cx=\"48\" cy=\"39\" r=\"11\" fill=\"#5e6658\" stroke=\"#3d4239\" stroke-width=\"2\"/><path d=\"M48 30v18M39 39h18\" stroke=\"#d8d2c4\" stroke-width=\"2\"/>",
}

static var _cache := {}


## Texture de l'illustration `nom`, `largeur` pixels de large (hauteur 2/3).
## Nom inconnu : null.
static func get_picto(nom: String, largeur := 96) -> Texture2D:
	var key := "%s|%d" % [nom, largeur]
	if _cache.has(key):
		return _cache[key]
	if not SVG.has(nom):
		return null
	var svg := "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"%d\" height=\"%d\" viewBox=\"0 0 %d %d\"><clipPath id=\"c\"><rect width=\"%d\" height=\"%d\" rx=\"6\"/></clipPath><g clip-path=\"url(#c)\">%s</g></svg>" % [W, H, W, H, W, H, String(SVG[nom])]
	var img := Image.new()
	if img.load_svg_from_string(svg, float(largeur) / float(W)) != OK:
		return null
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func has_picto(nom: String) -> bool:
	return SVG.has(nom)


## Illustration d'un cadrage : un cadre au rapport largeur / hauteur `r`
## (0 : celui de l'écran, 16:9), avec un petit paysage dedans.
static func cadrage(r: float, largeur := 96) -> Texture2D:
	if r <= 0.0:
		r = 16.0 / 9.0
	var key := "cadrage|%.3f|%d" % [r, largeur]
	if _cache.has(key):
		return _cache[key]
	var mh := 52.0
	var mw := 84.0
	var w := mw
	var h := w / r
	if h > mh:
		h = mh
		w = h * r
	var x := (W - w) * 0.5
	var y := (H - h) * 0.5
	var svg := "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"%d\" height=\"%d\" viewBox=\"0 0 %d %d\"><rect width=\"96\" height=\"64\" rx=\"6\" fill=\"#26302b\"/><clipPath id=\"f\"><rect x=\"%.1f\" y=\"%.1f\" width=\"%.1f\" height=\"%.1f\"/></clipPath><g clip-path=\"url(#f)\">%s</g><rect x=\"%.1f\" y=\"%.1f\" width=\"%.1f\" height=\"%.1f\" fill=\"none\" stroke=\"#ffd166\" stroke-width=\"2\"/></svg>" % [W, H, W, H, x, y, w, h, String(SVG.photo_scene), x, y, w, h]
	var img := Image.new()
	if img.load_svg_from_string(svg, float(largeur) / float(W)) != OK:
		return null
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


## Aperçu d'un filtre photo (mêmes formules que scripts/photo/filtre_photo.gdshader),
## appliqué à une petite scène dessinée.
static func filtre_photo(f: int, largeur := 96) -> Texture2D:
	var key := "filtre|%d|%d" % [f, largeur]
	if _cache.has(key):
		return _cache[key]
	var base := get_picto("photo_scene", largeur)
	if base == null:
		return null
	var img := base.get_image().duplicate() as Image
	img.convert(Image.FORMAT_RGBA8)
	var flou: Image = null
	if f == 9:
		flou = img.duplicate()
		flou.resize(maxi(1, img.get_width() / 6), maxi(1, img.get_height() / 6), Image.INTERPOLATE_BILINEAR)
		flou.resize(img.get_width(), img.get_height(), Image.INTERPOLATE_BILINEAR)
	for py in img.get_height():
		for px in img.get_width():
			var c := img.get_pixel(px, py)
			if c.a <= 0.0:
				continue
			var v := Vector3(c.r, c.g, c.b)
			if flou != null:
				var d := absf(float(py) / img.get_height() - 0.55) * 2.0
				var fc := flou.get_pixel(px, py)
				v = v.lerp(Vector3(fc.r, fc.g, fc.b), clampf((d - 0.18) / 0.57, 0.0, 1.0))
			v = _filtre(f, v)
			img.set_pixel(px, py, Color(clampf(v.x, 0, 1), clampf(v.y, 0, 1), clampf(v.z, 0, 1), c.a))
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func _luma(c: Vector3) -> float:
	return c.dot(Vector3(0.299, 0.587, 0.114))


static func _sature(c: Vector3, s: float) -> Vector3:
	var l := _luma(c)
	return Vector3(l, l, l).lerp(c, s)


static func _filtre(f: int, c: Vector3) -> Vector3:
	var l := _luma(c)
	match f:
		1:
			var g := smoothstep(0.02, 0.98, l)
			return Vector3(g, g, g)
		2: return Vector3(l * 1.07 + 0.05, l * 0.88 + 0.03, l * 0.66)
		3:
			var v := _sature(c, 0.65) * Vector3(1.06, 0.98, 0.82) + Vector3(0.06, 0.04, 0.02)
			return Vector3(0.5, 0.5, 0.5).lerp(v, 0.88)
		4: return c * Vector3(1.10, 1.0, 0.84) + Vector3(0.03, 0.01, 0.0)
		5: return c * Vector3(0.88, 1.0, 1.14)
		6: return (_sature(c, 1.45) - Vector3(0.5, 0.5, 0.5)) * 1.15 + Vector3(0.5, 0.5, 0.5)
		7: return Vector3(0.62, 0.62, 0.66).lerp(_sature(c, 0.55), 0.75)
		8: return Vector3(l * 0.45, l * 0.7, l * 1.15) * 0.85
		9: return (_sature(c, 1.5) - Vector3(0.5, 0.5, 0.5)) * 1.12 + Vector3(0.5, 0.5, 0.5)
		10: return _sature(c, 1.25) * Vector3(1.05, 1.0, 0.95) + Vector3(0.04, 0.03, 0.0)
		11: return _sature(c, 1.8) * Vector3(1.1, 0.85, 1.25)
	return c


## Vignette dessinée d'office pour un choix sans image : l'icône du thème
## (`icone`, voir Icones) sur une couleur propre au choix, ou, pour une liste
## graduée (nombres, niveaux), une jauge qui monte avec le rang `i` sur `n`.
static func auto(texte: String, i: int, n: int, icone := "details", gradue := false, largeur := 120) -> Texture2D:
	var key := "auto|%s|%d|%d|%s|%s|%d" % [texte, i, n, icone, gradue, largeur]
	if _cache.has(key):
		return _cache[key]
	var h := float(hash(texte) & 0xffff) / 65535.0
	var fond := Color.from_hsv(h, 0.38, 0.62)
	var clair := Color.from_hsv(h, 0.28, 0.78)
	var corps := "<defs><linearGradient id=\"g\" x1=\"0\" y1=\"0\" x2=\"0\" y2=\"1\"><stop offset=\"0\" stop-color=\"#%s\"/><stop offset=\"1\" stop-color=\"#%s\"/></linearGradient></defs><rect width=\"96\" height=\"64\" fill=\"url(#g)\"/>" % [clair.to_html(false), fond.to_html(false)]
	var ic: String = Icones.SVG.get(icone, Icones.SVG.get("details", ""))
	ic = ic.replace("currentColor", "#ffffff")
	if gradue and n > 1:
		var barres := mini(n, 6)
		var rang := roundi(float(i) / float(n - 1) * float(barres - 1))
		corps += "<g transform=\"translate(6 9) scale(1.15)\" opacity=\"0.9\">%s</g>" % ic
		var bw := 7.0
		var x0 := 40.0
		for b in barres:
			var bh := 10.0 + 38.0 * float(b + 1) / float(barres)
			var on := b <= rang
			corps += "<rect x=\"%.1f\" y=\"%.1f\" width=\"%.1f\" height=\"%.1f\" rx=\"1.5\" fill=\"%s\" opacity=\"%s\"/>" % [
				x0 + b * (bw + 2.0), 56.0 - bh, bw, bh, "#ffd166" if on else "#ffffff", "1" if on else "0.25"]
	else:
		corps += "<circle cx=\"48\" cy=\"32\" r=\"24\" fill=\"#000\" opacity=\"0.12\"/>"
		corps += "<g transform=\"translate(30 14) scale(1.5)\">%s</g>" % ic
	var svg := "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"%d\" height=\"%d\" viewBox=\"0 0 %d %d\"><clipPath id=\"c\"><rect width=\"%d\" height=\"%d\" rx=\"6\"/></clipPath><g clip-path=\"url(#c)\">%s</g></svg>" % [W, H, W, H, W, H, corps]
	var img := Image.new()
	if img.load_svg_from_string(svg, float(largeur) / float(W)) != OK:
		return null
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


## Un champ vu de dessus aux couleurs de la culture `id` (AgriDonnees), en rangs.
static func champ(id: String, largeur := 120) -> Texture2D:
	var c := AgriDonnees.culture(id)
	if c.is_empty():
		return null
	var key := "champ|%s|%d" % [id, largeur]
	if _cache.has(key):
		return _cache[key]
	var col: Color = c.get("couleur", Color(0.6, 0.7, 0.3))
	var fonce := col.darkened(0.3)
	var corps := "<rect width=\"96\" height=\"64\" fill=\"#%s\"/><rect width=\"96\" height=\"14\" fill=\"%s\"/>" % [_TERRE.substr(1), _CIEL]
	corps += "<path d=\"M0 14h96v50H0Z\" fill=\"#%s\"/>" % col.to_html(false)
	var rangs := ""
	for k in 7:
		var x := -20.0 + k * 20.0
		rangs += "M%.1f 64L%.1f 14" % [x, 38.0 + k * 4.0]
	corps += "<path d=\"%s\" stroke=\"#%s\" stroke-width=\"3\"/>" % [rangs, fonce.to_html(false)]
	corps += "<path d=\"M0 14h96\" stroke=\"#%s\" stroke-width=\"2\"/>" % _HERBE2.substr(1)
	var svg := "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"%d\" height=\"%d\" viewBox=\"0 0 %d %d\"><clipPath id=\"c\"><rect width=\"%d\" height=\"%d\" rx=\"6\"/></clipPath><g clip-path=\"url(#c)\">%s</g></svg>" % [W, H, W, H, W, H, corps]
	var img := Image.new()
	if img.load_svg_from_string(svg, float(largeur) / float(W)) != OK:
		return null
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


## Icône du thème devinée d'après le nom d'un choix (vignettes d'office).
const _MOTS := [
	["€", "billet"], ["prix", "billet"], ["budget", "billet"], ["subvention", "billet"], ["emprunt", "banque"],
	["minute", "horloge"], ["heure", "horloge"], ["jour", "horloge"], ["semaine", "horloge"], ["mois", "horloge"], [" an", "horloge"],
	["rapide", "fast"], ["lent", "play"], ["vitesse", "fast"], ["×", "fast"], ["réaliste", "horloge"],
	["ville", "village"], ["village", "village"], ["commune", "mairie"], ["pays", "globe"], ["carte", "globe"], ["monde", "globe"],
	["école", "ecole"], ["élève", "ecole"], ["étudiant", "ecole"], ["apprenti", "ecole"], ["université", "ecole"],
	["bébé", "habitants"], ["retraité", "habitants"], ["actif", "emploi"], ["chômeur", "emploi"], ["métier", "emploi"], ["chef", "emploi"],
	["tout le monde", "habitants"], ["habitant", "habitants"], ["défunt", "funeraire"], ["crémation", "funeraire"],
	["parc", "parc"], ["zoo", "zoo"], ["enclos", "enclos"], ["musée", "musee"], ["stade", "sport"], ["club", "sport"],
	["pollution", "climat"], ["climat", "climat"], ["faim", "agriculture"], ["ferme", "agriculture"], ["culture", "agriculture"],
	["élection", "urne"], ["mairie", "mairie"], ["chantier", "grue"], ["usure", "grue"], ["événement", "fete"], ["catastrophe", "tempete"],
	["fenêtre", "vue"], ["plein écran", "vue"], ["ombre", "soleil"], ["msaa", "vue"], ["images par", "vue"], ["px", "appareil_photo"],
	["caméra", "appareil_photo"], ["qualité", "etoile"], ["timbre", "carte_postale"], ["photo", "appareil_photo"],
	["bâtiment", "construire"], ["maison", "logement"], ["logement", "logement"], ["commerce", "commerce"], ["industrie", "industrie"],
	["désactiv", "fermer"], ["aucun", "fermer"], ["sans", "fermer"], ["arbre", "feuille"], ["débloqu", "cadenas"],
	["marchandise", "ressources"], ["stock", "ressources"], ["partie", "sauver"], ["sauvegarde", "sauver"], ["langue", "globe"],
]


static func icone_pour(texte: String) -> String:
	var t := texte.to_lower()
	for m in _MOTS:
		if t.contains(String(m[0])):
			return String(m[1])
	return "details"


## Maillot aux deux couleurs `c1` et `c2` (codes hexadécimaux), pour les couleurs d'un club.
static func maillot(c1: String, c2: String, largeur := 120) -> Texture2D:
	var key := "maillot|%s|%s|%d" % [c1, c2, largeur]
	if _cache.has(key):
		return _cache[key]
	var corps := "<rect width=\"96\" height=\"64\" fill=\"%s\"/><path d=\"M34 8l-16 10 6 12 8-4v32h32V26l8 4 6-12-16-10c-2 6-8 8-14 8s-12-2-14-8Z\" fill=\"#%s\" stroke=\"#222\" stroke-width=\"1.2\"/>" % [_HERBE, c1]
	corps += "<path d=\"M44 16h8v42h-8Z\" fill=\"#%s\"/><path d=\"M34 8c2 6 8 8 14 8s12-2 14-8\" fill=\"none\" stroke=\"#%s\" stroke-width=\"3\"/>" % [c2, c2]
	var svg := "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"%d\" height=\"%d\" viewBox=\"0 0 %d %d\"><clipPath id=\"c\"><rect width=\"%d\" height=\"%d\" rx=\"6\"/></clipPath><g clip-path=\"url(#c)\">%s</g></svg>" % [W, H, W, H, W, H, corps]
	var img := Image.new()
	if img.load_svg_from_string(svg, float(largeur) / float(W)) != OK:
		return null
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex
