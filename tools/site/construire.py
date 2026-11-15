"""Site vitrine ManiGames (www.manigames.online), français + anglais.

    python3 tools/site/construire.py            # écrit site/public/
    python3 tools/site/construire.py --medias   # refait aussi images, vidéo, kit presse

site/public/ est le dossier à téléverser tel quel chez Infomaniak (voir
site/README.md). Pas de cookies, pas de traceurs, polices hébergées sur le site.

Pour changer une info (e-mail, lien Steam, réseaux…) : modifier CONFIG
ci-dessous puis relancer le script. Les textes sont dans TEXTES (fr / en).
"""
from __future__ import annotations

import html
import io
import os
import shutil
import subprocess
import sys
import zipfile
from datetime import date

RACINE = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
PUBLIC = os.path.join(RACINE, "site", "public")
MARQUE = os.path.join(RACINE, "marque")
POLICES = os.path.join(RACINE, "tools", "marque", "polices")

# ------------------------------------------------------------------ réglages
CONFIG = {
    "domaine": "https://www.manigames.online",
    "email": "contact@manigames.online",
    # Lien de la page Steam de MiniBlocs, une fois la page « Prochainement » ouverte
    # (ex. https://store.steampowered.com/app/1234560/MiniBlocs/). Vide : « Bientôt sur Steam ».
    "steam_miniblocs": "",
    # Réseaux : coller l'adresse de chaque compte une fois créé ; vide = lien caché.
    "reseaux": {"YouTube": "", "Discord": "", "TikTok": ""},
    # Mentions légales
    "editeur": "Gaël M. (ManiGames)",
    "pays": "Suisse",
    "annee": 2026,
}
# Dossier des captures de la démo (tests/demo_vitrine.gd) pour --medias
CAPTURES = os.environ.get("CAPTURES", "/mnt/project-files/captures/demo")
GRANDES = os.environ.get("GRANDES", os.path.join(CAPTURES, "grandes"))

PAGES = {  # id : (fr, en)
    "accueil": ("index.html", "en/index.html"),
    "miniblocs": ("miniblocs.html", "en/miniblocs.html"),
    "presse": ("presse.html", "en/press.html"),
    "contact": ("contact.html", "en/contact.html"),
    "legal": ("mentions-legales.html", "en/legal.html"),
    "404": ("404.html", "en/404.html"),
}

GALERIE = [  # (fichier de captures/demo, légende fr, légende en)
    ("01-village-vu-du-ciel", "Un village bâti sur le vrai relief, vu du ciel", "A village built on real terrain, seen from above"),
    ("03-centre-du-village", "Le centre du village et sa place", "The village centre and its square"),
    ("05-vue-au-sol", "Dans la grand-rue, en vue à la 3e personne", "Down the high street, in third-person view"),
    ("06-soir-au-village", "Le soir, les lumières s'allument", "In the evening, the lights come on"),
    ("07-foot-et-quartiers", "Le terrain de foot et les quartiers", "The football pitch and the neighbourhoods"),
    ("02-campagne-a-l-horizon", "La campagne jusqu'à l'horizon", "Countryside all the way to the horizon"),
    ("04-demo-guidee-marche", "La démo guidée, un jour de marché", "The guided demo, on market day"),
    ("08-bilan-de-la-demo", "Le bilan de la démo", "The end-of-demo summary"),
]

# ------------------------------------------------------------------ textes
TEXTES = {
    "fr": {
        "lang": "fr", "autre": "en", "autre_nom": "English", "autre_court": "EN",
        "nav_jeux": "Jeux", "nav_miniblocs": "MiniBlocs", "nav_presse": "Presse", "nav_contact": "Contact",
        "menu": "Menu",
        "titre_site": "ManiGames, studio de jeux indépendant",
        "desc_site": "ManiGames, studio de jeux vidéo indépendant. Premier jeu : MiniBlocs, un city builder sur la Terre entière, en accès anticipé sur Steam en 2027.",
        "hero_titre": "Des petits blocs,<br>des grands mondes.",
        "hero_texte": "ManiGames est un studio de jeux vidéo indépendant. On y fabrique des mondes à bâtir, à explorer et à vivre, avec des outils libres et beaucoup de patience.",
        "hero_bouton": "Découvrir MiniBlocs",
        "hero_bouton2": "Nos jeux",
        "jeu_phare": "Premier jeu",
        "mb_accroche": "Le city builder où la Terre entière est ton chantier.",
        "mb_resume": "Choisis n'importe quel lieu sur Terre, pose ta Maison de commune et bâtis une ville vivante sur le vrai relief, au mètre près. Routes, réseaux, habitants qui naissent, travaillent et votent, parcs, zoo et club de foot : tu es le maire… tant que les électeurs le veulent bien.",
        "mb_sortie": "Accès anticipé sur Steam en 2027",
        "steam_liste": "Ajouter à ma liste de souhaits",
        "steam_bientot": "Bientôt sur Steam",
        "en_savoir_plus": "En savoir plus",
        "jeux_titre": "Nos jeux",
        "jeux_intro": "Quatre jeux sont en préparation. MiniBlocs sort le premier ; les autres montreront leurs premières images au fil des mois.",
        "en_creation": "En création",
        "jeux": [
            ("Try To Escape All Time", "Évasion · 3D · solo ou coop à 4",
             "Bastion-Gris, une prison sur une île battue par les vents. Six quartiers, trois cents détenus, une seule sortie : la mer. Pour s'évader, il faudra se faire des amis, vivre la vie de la prison sans se faire remarquer… et creuser.",
             "#3B4A5A", "#8FA3B5"),
            ("Sick World", "MMORPG · 3D · voyage dans le temps",
             "Des voyageurs temporels partent d'une ville moderne pour réparer l'histoire de l'humanité, île après île, de la Préhistoire à l'Égypte, en combattant les fractures qui la déforment.",
             "#6B3F2A", "#E0A55E"),
            ("Fan Around The World", "Fan club de foot · 2D · PC puis mobile",
             "Fonde ton fan club, suis les vrais matchs de la saison, collectionne les stades et affronte les tribunes adverses en duels d'ambiance : chants en rythme, tifos et olas.",
             "#1E4FA8", "#57C26B"),
        ],
        "studio_titre": "Le studio",
        "studio_texte": [
            "ManiGames, c'est un développeur seul, qui fait les jeux auxquels il a envie de jouer : des jeux de gestion où l'on bâtit, des aventures où l'on explore, et du sport, parce qu'on ne se refait pas.",
            "Les jeux sont faits avec Godot, Blender et d'autres outils libres. Ils sont réalistes avec une touche d'humour, et pensés pour les joueurs qui aiment prendre leur temps.",
        ],
        "chiffres": [("4", "jeux en création"), ("1", "développeur"), ("2027", "premier jeu sur Steam")],
        # page MiniBlocs
        "mb_titre_page": "MiniBlocs, city builder sur la Terre entière",
        "mb_desc_page": "MiniBlocs : choisis n'importe quel lieu sur Terre et bâtis une ville vivante sur le vrai relief, au mètre près. Accès anticipé sur Steam en 2027.",
        "bande_annonce": "Bande-annonce",
        "video_non": "Ton navigateur ne lit pas cette vidéo.",
        "atouts_titre": "Ce qui t'attend",
        "atouts": [
            ("Ta ville, n'importe où sur Terre", "Fais tourner le globe, cherche ton village natal ou une vallée au bout du monde. Le relief, les forêts, les champs et les rivières sont les vrais. Seule différence : personne n'a encore rien construit.", "globe"),
            ("À l'échelle réelle", "Tout se joue en cases d'un mètre carré. Une maison a la taille d'une maison, une départementale la largeur d'une départementale, et les chantiers avancent ouvrier par ouvrier.", "regle"),
            ("Construire à ta façon", "Plus de 700 bâtiments de 29 styles du monde, le zonage qui laisse la ville pousser seule, ou l'Atelier pour dessiner tes propres bâtiments mur par mur, meubles compris.", "bloc"),
            ("Des habitants, pas des statistiques", "Chaque habitant a un âge, une famille, un métier et un budget. Suis-en un toute la journée, descends dans la rue à la 3e personne ou prends le volant du bus.", "habitant"),
            ("Maire… jusqu'aux élections", "Fixe les impôts, emprunte, prends des arrêtés par quartier et remplis les objectifs de ton pays. Si ta liste perd, c'est le nouveau conseil qui décide.", "urne"),
            ("De quoi occuper le week-end", "Parcs de loisirs avec éditeur de grands huit, zoo de 34 espèces, musées, cinémas et théâtres, et ton club de foot, de la Régionale à la Première Ligue.", "ballon"),
        ],
        "galerie_titre": "Images",
        "infos_titre": "En bref",
        "infos": [
            ("Genre", "City builder, gestion, bac à sable"),
            ("Plateforme", "PC Windows (Steam)"),
            ("Sortie", "2027, en accès anticipé"),
            ("Prix prévu", "19,99 € (19,99 $)"),
            ("Langues", "Français ; anglais prévu"),
            ("Démo", "Démo guidée de 30 minutes, gratuite"),
        ],
        "fermer": "Fermer",
        # presse
        "presse_titre_page": "Kit presse",
        "presse_desc_page": "Kit presse de ManiGames et de MiniBlocs : fiche, textes, logos, captures et bande-annonce à télécharger.",
        "presse_intro": "Tout ce qu'il faut pour parler de MiniBlocs et de ManiGames. Les images et les logos peuvent être utilisés librement pour un article, une vidéo ou un stream sur le jeu.",
        "telecharger_kit": "Télécharger le kit complet (ZIP)",
        "fiche_studio": "Le studio",
        "fiche_jeu": "MiniBlocs",
        "studio_fiche": [
            ("Nom", "ManiGames"),
            ("Équipe", "1 développeur"),
            ("Création", "2026"),
            ("Site", "www.manigames.online"),
            ("Contact presse", "{email}"),
        ],
        "desc_courte": "Description courte",
        "desc_longue": "Description",
        "mb_longue": [
            "MiniBlocs est un city builder qui se joue sur la Terre entière. Le joueur choisit n'importe quel lieu de la planète, avec son vrai relief, ses vraies forêts et ses vraies rivières, mais sans rien de construit : c'est à lui de bâtir.",
            "Tout est à l'échelle réelle, en cases d'un mètre carré. Les chantiers avancent ouvrier par ouvrier, chaque habitant a une famille, un métier et un budget, et la ville a ses réseaux d'électricité, d'eau, d'égouts, de fibre et de déchets.",
            "Le joueur est le maire : il fixe les impôts, prend des arrêtés, remplit les objectifs de son pays… jusqu'aux élections. Parcs de loisirs, zoo, musées, spectacles et club de football occupent le week-end des habitants.",
        ],
        "points_cles": "Points clés",
        "points": [
            "Toute la planète jouable : vrai relief, vrais biomes, vraies rivières, terre vierge.",
            "Échelle réelle, cases de 1 m², temps cohérent (1 jour de jeu = 1 minute par défaut).",
            "Plus de 700 bâtiments, 29 styles, 131 véhicules, 160 décors, éditeur libre de bâtiments et de meubles.",
            "Habitants simulés un par un : familles, métiers, école, vieillissement.",
            "Élections, pays, plusieurs villes avec leur propre caisse.",
            "Vue au sol à la 3e et à la 1re personne, conduite des véhicules.",
            "Parcs de loisirs, zoo, musées, spectacles, club de football.",
            "Démo guidée de 30 minutes.",
        ],
        "logos_titre": "Logos",
        "logos_texte": "SVG (vectoriel) et PNG transparents. Merci de ne pas déformer ni recolorer les logos.",
        "captures_titre": "Captures (1920 × 1080)",
        "video_titre": "Bande-annonce",
        "video_texte": "40 secondes, 720p, MP4.",
        "contact_presse": "Une question, une clé pour tester le jeu ? Écris à {email_lien}.",
        # contact
        "contact_titre_page": "Contact",
        "contact_desc_page": "Écrire à ManiGames : questions, presse, créateurs de contenu.",
        "contact_texte": "Une question sur un jeu, une idée, un bug, une demande de presse ou de créateur de contenu ? Le plus simple est d'écrire un e-mail. Je réponds moi-même, en général sous quelques jours.",
        "contact_reseaux": "Suivre ManiGames",
        "contact_steam": "Le moyen le plus utile de soutenir MiniBlocs : l'ajouter à ta liste de souhaits Steam. Ça aide le jeu à être vu le jour de sa sortie.",
        # légal
        "legal_titre_page": "Mentions légales",
        "legal_desc_page": "Mentions légales et protection des données du site ManiGames.",
        "legal_editeur": "Éditeur du site",
        "legal_hebergeur": "Hébergement",
        "legal_hebergeur_texte": "Infomaniak Network SA, Rue Eugène-Marziano 25, 1227 Les Acacias (GE), Suisse. www.infomaniak.com",
        "legal_donnees": "Données personnelles",
        "legal_donnees_texte": [
            "Ce site ne dépose aucun cookie, n'utilise aucun outil de mesure d'audience ni aucun traceur, et ne charge rien depuis un autre site : les polices et les images sont hébergées ici.",
            "Comme tout serveur web, l'hébergeur garde des journaux techniques (adresse IP, page demandée, date) pour la sécurité du service, pendant une durée limitée.",
            "Si tu écris à ManiGames, ton e-mail sert seulement à te répondre. Il n'est ni revendu, ni utilisé pour de la publicité. Tu peux demander à tout moment qu'il soit effacé.",
        ],
        "legal_droits": "Propriété intellectuelle",
        "legal_droits_texte": "Les jeux, logos, images et textes de ce site appartiennent à ManiGames. Les captures et logos du kit presse peuvent être utilisés pour parler des jeux. Polices : Outfit et Nunito (SIL Open Font License).",
        "legal_donnees_jeu": "Données du jeu MiniBlocs",
        "legal_donnees_jeu_texte": "Relief : Mapzen Terrain Tiles (AWS Open Data : SRTM, GMTED, ETOPO1, EU-DEM). Biomes : ESA WorldCover 2021 (CC BY 4.0). Cours d'eau : © les contributeurs d'OpenStreetMap (ODbL). Villes : GeoNames (CC BY 4.0). Fait avec Godot Engine (MIT).",
        "contact": "Contact",
        # 404
        "p404_titre": "Page introuvable",
        "p404_texte": "Cette page n'existe pas, ou plus. Comme un pont qui mène dans un champ.",
        "p404_bouton": "Retour à l'accueil",
        # pied
        "pied_droits": "Tous droits réservés.",
        "pied_legal": "Mentions légales",
        "pied_presse": "Kit presse",
        "pied_sans_cookies": "Sans cookies ni traceurs.",
    },
    "en": {
        "lang": "en", "autre": "fr", "autre_nom": "Français", "autre_court": "FR",
        "nav_jeux": "Games", "nav_miniblocs": "MiniBlocs", "nav_presse": "Press", "nav_contact": "Contact",
        "menu": "Menu",
        "titre_site": "ManiGames, independent game studio",
        "desc_site": "ManiGames, independent video game studio. First game: MiniBlocs, a city builder set on the whole Earth, coming to Steam Early Access in 2027.",
        "hero_titre": "Small blocks,<br>big worlds.",
        "hero_texte": "ManiGames is an independent video game studio, making worlds to build, explore and live in, with free tools and a lot of patience.",
        "hero_bouton": "Discover MiniBlocs",
        "hero_bouton2": "Our games",
        "jeu_phare": "First game",
        "mb_accroche": "The city builder where the whole Earth is your building site.",
        "mb_resume": "Pick any spot on Earth, lay down your town hall and build a living town on real terrain, one square metre at a time. Roads, utilities, residents who are born, work and vote, theme parks, a zoo and a football club: you are the mayor... for as long as the voters let you.",
        "mb_sortie": "Coming to Steam Early Access in 2027",
        "steam_liste": "Add to my Steam wishlist",
        "steam_bientot": "Coming soon to Steam",
        "en_savoir_plus": "Learn more",
        "jeux_titre": "Our games",
        "jeux_intro": "Four games are in the works. MiniBlocs comes first; the others will show their first images over the coming months.",
        "en_creation": "In development",
        "jeux": [
            ("Try To Escape All Time", "Escape · 3D · solo or 4-player co-op",
             "Bastion-Gris, a prison on a windswept island. Six blocks, three hundred inmates, only one way out: the sea. To escape, you'll have to make friends, live prison life without being noticed... and dig.",
             "#3B4A5A", "#8FA3B5"),
            ("Sick World", "MMORPG · 3D · time travel",
             "Time travellers set out from a modern city to repair human history, island after island, from the Stone Age to Ancient Egypt, fighting the rifts that twist it.",
             "#6B3F2A", "#E0A55E"),
            ("Fan Around The World", "Football fan club · 2D · PC, then mobile",
             "Start your fan club, follow the season's real matches, collect stadiums and take on rival stands in atmosphere duels: rhythm chants, tifos and Mexican waves.",
             "#1E4FA8", "#57C26B"),
        ],
        "studio_titre": "The studio",
        "studio_texte": [
            "ManiGames is a single developer making the games he wants to play: management games where you build, adventures where you explore, and sport, because some habits never change.",
            "The games are made with Godot, Blender and other free tools. They are realistic with a touch of humour, and made for players who like to take their time.",
        ],
        "chiffres": [("4", "games in development"), ("1", "developer"), ("2027", "first game on Steam")],
        "mb_titre_page": "MiniBlocs, a city builder on the whole Earth",
        "mb_desc_page": "MiniBlocs: pick any spot on Earth and build a living town on real terrain, one square metre at a time. Coming to Steam Early Access in 2027.",
        "bande_annonce": "Trailer",
        "video_non": "Your browser cannot play this video.",
        "atouts_titre": "What awaits you",
        "atouts": [
            ("Your town, anywhere on Earth", "Spin the globe, look up your home town or a valley at the end of the world. Terrain, forests, fields and rivers are all real. The only difference: nobody has built anything yet.", "globe"),
            ("At real scale", "Everything is played on one-square-metre tiles. A house is the size of a house, a country road as wide as a country road, and building sites progress one worker at a time.", "regle"),
            ("Build your way", "Over 700 buildings in 29 styles from around the world, zoning that lets the town grow on its own, or the Workshop to design your own buildings wall by wall, furniture included.", "bloc"),
            ("Residents, not statistics", "Every resident has an age, a family, a job and a budget. Follow one all day long, walk down the street in third person or drive the bus.", "habitant"),
            ("Mayor... until the next election", "Set taxes, borrow, pass by-laws for each neighbourhood and meet your country's goals. If your list loses, the new council makes the calls.", "urne"),
            ("Something for the weekend", "Theme parks with a roller coaster editor, a zoo with 34 species, museums, cinemas and theatres, and your own football club, from the regional league to the top flight.", "ballon"),
        ],
        "galerie_titre": "Screenshots",
        "infos_titre": "At a glance",
        "infos": [
            ("Genre", "City builder, management, sandbox"),
            ("Platform", "Windows PC (Steam)"),
            ("Release", "2027, in Early Access"),
            ("Planned price", "$19.99 (€19.99)"),
            ("Languages", "French; English planned"),
            ("Demo", "Free 30-minute guided demo"),
        ],
        "fermer": "Close",
        "presse_titre_page": "Press kit",
        "presse_desc_page": "ManiGames and MiniBlocs press kit: fact sheet, texts, logos, screenshots and trailer to download.",
        "presse_intro": "Everything you need to write about MiniBlocs and ManiGames. Screenshots and logos may be freely used for an article, a video or a stream about the game.",
        "telecharger_kit": "Download the full kit (ZIP)",
        "fiche_studio": "The studio",
        "fiche_jeu": "MiniBlocs",
        "studio_fiche": [
            ("Name", "ManiGames"),
            ("Team", "1 developer"),
            ("Founded", "2026"),
            ("Website", "www.manigames.online"),
            ("Press contact", "{email}"),
        ],
        "desc_courte": "Short description",
        "desc_longue": "Description",
        "mb_longue": [
            "MiniBlocs is a city builder played on the whole Earth. Players pick any spot on the planet, with its real terrain, forests and rivers, but with nothing built yet: building it is their job.",
            "Everything is at real scale, on one-square-metre tiles. Building sites progress one worker at a time, every resident has a family, a job and a budget, and the town runs its own power, water, sewer, fibre and waste networks.",
            "The player is the mayor: setting taxes, passing by-laws, meeting the country's goals... until election day. Theme parks, a zoo, museums, shows and a football club keep residents busy at the weekend.",
        ],
        "points_cles": "Key features",
        "points": [
            "The whole planet is playable: real terrain, real biomes, real rivers, untouched land.",
            "Real scale, 1 m² tiles, consistent time (1 game day = 1 minute by default).",
            "Over 700 buildings, 29 styles, 131 vehicles, 160 decorations, free-form building and furniture editor.",
            "Residents simulated one by one: families, jobs, school, ageing.",
            "Elections, countries, several towns each with its own budget.",
            "Ground view in third and first person, drivable vehicles.",
            "Theme parks, zoo, museums, shows, football club.",
            "30-minute guided demo.",
        ],
        "logos_titre": "Logos",
        "logos_texte": "SVG (vector) and transparent PNG. Please do not stretch or recolour the logos.",
        "captures_titre": "Screenshots (1920 × 1080)",
        "video_titre": "Trailer",
        "video_texte": "40 seconds, 720p, MP4.",
        "contact_presse": "A question, or a key to try the game? Write to {email_lien}.",
        "contact_titre_page": "Contact",
        "contact_desc_page": "Get in touch with ManiGames: questions, press, content creators.",
        "contact_texte": "A question about a game, an idea, a bug, a press or content creator request? The easiest way is to send an e-mail. I answer myself, usually within a few days. French or English, both are fine.",
        "contact_reseaux": "Follow ManiGames",
        "contact_steam": "The most useful way to support MiniBlocs: add it to your Steam wishlist. It helps the game get seen on launch day.",
        "legal_titre_page": "Legal notice",
        "legal_desc_page": "Legal notice and privacy for the ManiGames website.",
        "legal_editeur": "Publisher",
        "legal_hebergeur": "Hosting",
        "legal_hebergeur_texte": "Infomaniak Network SA, Rue Eugène-Marziano 25, 1227 Les Acacias (GE), Switzerland. www.infomaniak.com",
        "legal_donnees": "Privacy",
        "legal_donnees_texte": [
            "This website sets no cookies, uses no analytics or trackers, and loads nothing from other websites: fonts and images are hosted here.",
            "Like any web server, the host keeps technical logs (IP address, requested page, date) for security, for a limited time.",
            "If you write to ManiGames, your e-mail address is only used to reply to you. It is never sold or used for advertising. You can ask for it to be deleted at any time.",
        ],
        "legal_droits": "Intellectual property",
        "legal_droits_texte": "The games, logos, images and texts on this website belong to ManiGames. Press kit screenshots and logos may be used to write about the games. Fonts: Outfit and Nunito (SIL Open Font License).",
        "legal_donnees_jeu": "MiniBlocs game data",
        "legal_donnees_jeu_texte": "Terrain: Mapzen Terrain Tiles (AWS Open Data: SRTM, GMTED, ETOPO1, EU-DEM). Biomes: ESA WorldCover 2021 (CC BY 4.0). Waterways: © OpenStreetMap contributors (ODbL). Towns: GeoNames (CC BY 4.0). Made with Godot Engine (MIT).",
        "contact": "Contact",
        "p404_titre": "Page not found",
        "p404_texte": "This page does not exist, or no longer does. Like a bridge that leads into a field.",
        "p404_bouton": "Back to the home page",
        "pied_droits": "All rights reserved.",
        "pied_legal": "Legal notice",
        "pied_presse": "Press kit",
        "pied_sans_cookies": "No cookies, no trackers.",
    },
}

# ------------------------------------------------------------------ icônes (traits simples)
ICONES = {
    "globe": '<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c3 3.2 3 14.8 0 18M12 3c-3 3.2-3 14.8 0 18"/>',
    "regle": '<rect x="3" y="8" width="18" height="8" rx="1.5"/><path d="M7 8v3M11 8v4M15 8v3M19 8v4"/>',
    "bloc": '<path d="M12 3l8 4.5v9L12 21l-8-4.5v-9z"/><path d="M4 7.5l8 4.5 8-4.5M12 12v9"/>',
    "habitant": '<circle cx="12" cy="7" r="3.5"/><path d="M5 21c0-4 3-7 7-7s7 3 7 7"/>',
    "urne": '<rect x="4" y="10" width="16" height="11" rx="1.5"/><path d="M9 6l2 4M8 10h8M10 3h5l-1 7"/>',
    "ballon": '<circle cx="12" cy="12" r="9"/><path d="M12 7l4 3-1.5 4.5h-5L8 10zM12 7V3M16 10l4.5-1.5M14.5 14.5l2.5 4M9.5 14.5L7 18.5M8 10L3.5 8.5"/>',
}


def icone(nom: str) -> str:
    return (f'<svg class="ico" viewBox="0 0 24 24" aria-hidden="true" fill="none" stroke="currentColor" '
            f'stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">{ICONES[nom]}</svg>')


# ------------------------------------------------------------------ gabarit
def e(s: str) -> str:
    return html.escape(s, quote=True)


def chemin(page: str, lang: str) -> str:
    return PAGES[page][0 if lang == "fr" else 1]


def lien(page: str, lang: str, depuis_lang: str, ancre: str = "") -> str:
    """Lien relatif depuis une page de la langue depuis_lang."""
    cible = chemin(page, lang)
    if depuis_lang == "en":
        cible = cible[3:] if cible.startswith("en/") else "../" + cible
    if cible.endswith("index.html"):
        cible = cible[: -len("index.html")] or "./"
    return cible + ancre


def racine(lang: str) -> str:
    return "../" if lang == "en" else ""


def logo_inline(sombre=False) -> str:
    nom = "manigames-piste1-cube-court-sombre.svg" if sombre else "manigames-piste1-cube-court.svg"
    with open(os.path.join(MARQUE, nom), encoding="utf-8") as f:
        s = f.read().strip()
    return s.replace("<svg ", '<svg role="img" aria-label="ManiGames" ', 1)


def steam_bouton(t: dict, classe="btn btn-steam") -> str:
    url = CONFIG["steam_miniblocs"]
    steam = ('<svg class="ico" viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M12 2a10 10 0 0 0-9.96 9.1l5.36 2.22a2.8 2.8 0 0 1 1.6-.5h.16l2.39-3.46v-.05a3.79 3.79 0 1 1 3.79 3.79h-.09l-3.4 2.43v.13a2.84 2.84 0 0 1-5.63.56L2.4 14.7A10 10 0 1 0 12 2zm-4.3 15.17l-1.23-.5a2.13 2.13 0 1 0 1.16-2.9l1.27.52a1.57 1.57 0 1 1-1.2 2.9zm9.6-7.8a2.53 2.53 0 1 0-2.52 2.52 2.53 2.53 0 0 0 2.53-2.52zm-4.42 0a1.9 1.9 0 1 1 1.9 1.9 1.9 1.9 0 0 1-1.9-1.9z"/></svg>')
    if url:
        return f'<a class="{classe}" href="{e(url)}" rel="noopener">{steam}{e(t["steam_liste"])}</a>'
    return f'<span class="{classe} btn-inactif" aria-disabled="true">{steam}{e(t["steam_bientot"])}</span>'


def page(lang: str, page_id: str, titre: str, desc: str, corps: str, image_og="img/og.jpg") -> str:
    t = TEXTES[lang]
    r = racine(lang)
    autre = t["autre"]
    url = CONFIG["domaine"] + "/" + chemin(page_id, lang).replace("index.html", "")
    url_autre = CONFIG["domaine"] + "/" + chemin(page_id, autre).replace("index.html", "")
    url_fr = url if lang == "fr" else url_autre
    url_en = url if lang == "en" else url_autre

    def nav(pid, cle, ancre=""):
        cour = ' aria-current="page"' if pid == page_id and not ancre else ""
        return f'<a href="{lien(pid, lang, lang, ancre)}"{cour}>{e(t[cle])}</a>'

    navs = (nav("accueil", "nav_jeux", "#jeux") + nav("miniblocs", "nav_miniblocs")
            + nav("presse", "nav_presse") + nav("contact", "nav_contact"))
    langue = (f'<a class="langue" href="{lien(page_id, autre, lang)}" hreflang="{autre}" lang="{autre}" '
              f'title="{e(t["autre_nom"])}">{t["autre_court"]}</a>')
    reseaux = "".join(f'<a href="{e(u)}" rel="noopener">{e(n)}</a>' for n, u in CONFIG["reseaux"].items() if u)
    titre_complet = titre if page_id == "accueil" else f"{titre} · ManiGames"
    return f"""<!doctype html>
<html lang="{lang}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{e(titre_complet)}</title>
<meta name="description" content="{e(desc)}">
<link rel="canonical" href="{url}">
<link rel="alternate" hreflang="fr" href="{url_fr}">
<link rel="alternate" hreflang="en" href="{url_en}">
<link rel="alternate" hreflang="x-default" href="{url_fr}">
<meta property="og:type" content="website">
<meta property="og:site_name" content="ManiGames">
<meta property="og:title" content="{e(titre)}">
<meta property="og:description" content="{e(desc)}">
<meta property="og:url" content="{url}">
<meta property="og:image" content="{CONFIG['domaine']}/{image_og}">
<meta property="og:locale" content="{'fr_FR' if lang == 'fr' else 'en_GB'}">
<meta name="twitter:card" content="summary_large_image">
<meta name="theme-color" content="#22303C">
<link rel="icon" href="{r}favicon.svg" type="image/svg+xml">
<link rel="icon" href="{r}favicon-32.png" sizes="32x32" type="image/png">
<link rel="apple-touch-icon" href="{r}apple-touch-icon.png">
<link rel="preload" href="{r}polices/outfit.woff2" as="font" type="font/woff2" crossorigin>
<link rel="stylesheet" href="{r}style.css">
</head>
<body class="page-{page_id}">
<a class="saut" href="#contenu">{'Aller au contenu' if lang == 'fr' else 'Skip to content'}</a>
<header class="entete">
  <div class="cadre entete-in">
    <a class="logo" href="{lien('accueil', lang, lang)}">{logo_inline()}</a>
    <nav class="nav" aria-label="{'Navigation principale' if lang == 'fr' else 'Main navigation'}">
      <input type="checkbox" id="menu-bascule" class="menu-bascule">
      <label for="menu-bascule" class="menu-bouton"><span></span>{e(t['menu'])}</label>
      <div class="nav-liens">{navs}{langue}</div>
    </nav>
  </div>
</header>
<main id="contenu">
{corps}
</main>
<footer class="pied">
  <div class="cadre pied-in">
    <div class="pied-logo">{logo_inline(True)}</div>
    <div class="pied-liens">
      <a href="{lien('miniblocs', lang, lang)}">MiniBlocs</a>
      <a href="{lien('presse', lang, lang)}">{e(t['pied_presse'])}</a>
      <a href="{lien('contact', lang, lang)}">{e(t['nav_contact'])}</a>
      <a href="{lien('legal', lang, lang)}">{e(t['pied_legal'])}</a>
      {reseaux}
    </div>
    <p class="pied-mention">© {CONFIG['annee']}{'–' + str(date.today().year) if date.today().year > CONFIG['annee'] else ''} ManiGames. {e(t['pied_droits'])} {e(t['pied_sans_cookies'])}</p>
  </div>
</footer>
<script src="{r}site.js" defer></script>
</body>
</html>
"""


def img(r: str, nom: str, alt: str, classe="", tailles="(min-width: 1100px) 1100px, 100vw", charge="lazy") -> str:
    return (f'<img class="{classe}" src="{r}img/{nom}-1600.webp" '
            f'srcset="{r}img/{nom}-800.webp 800w, {r}img/{nom}-1600.webp 1600w" sizes="{tailles}" '
            f'width="1600" height="900" alt="{e(alt)}" loading="{charge}" decoding="async">')


def email_lien() -> str:
    m = CONFIG["email"]
    return f'<a href="mailto:{e(m)}">{e(m)}</a>'


# ------------------------------------------------------------------ pages
def p_accueil(lang: str) -> str:
    t = TEXTES[lang]
    r = racine(lang)
    jeux = ""
    for nom, genre, texte, c1, c2 in t["jeux"]:
        jeux += f"""
      <article class="carte-jeu" style="--c1:{c1};--c2:{c2}">
        <div class="carte-jeu-visuel" aria-hidden="true"><span>{e(nom)}</span></div>
        <div class="carte-jeu-corps">
          <p class="etiquette">{e(t['en_creation'])}</p>
          <h3>{e(nom)}</h3>
          <p class="genre">{e(genre)}</p>
          <p>{e(texte)}</p>
        </div>
      </article>"""
    chiffres = "".join(f'<div><strong>{e(a)}</strong><span>{e(b)}</span></div>' for a, b in t["chiffres"])
    studio = "".join(f"<p>{e(p)}</p>" for p in t["studio_texte"])
    corps = f"""
<section class="hero">
  {img(r, 'hero-village', '', 'hero-fond', '100vw', 'eager')}
  <div class="cadre hero-in">
    <h1>{t['hero_titre']}</h1>
    <p class="hero-texte">{e(t['hero_texte'])}</p>
    <p class="boutons"><a class="btn btn-jaune" href="{lien('miniblocs', lang, lang)}">{e(t['hero_bouton'])}</a>
    <a class="btn btn-clair" href="#jeux">{e(t['hero_bouton2'])}</a></p>
  </div>
</section>

<section class="phare cadre" aria-labelledby="t-mb">
  <div class="phare-image">
    <a href="{lien('miniblocs', lang, lang)}">{img(r, 'capsule-miniblocs', 'MiniBlocs', '', '(min-width: 900px) 560px, 100vw')}</a>
  </div>
  <div class="phare-texte">
    <p class="etiquette etiquette-jaune">{e(t['jeu_phare'])}</p>
    <h2 id="t-mb"><img class="logo-mb" src="{r}img/miniblocs-logo.svg" alt="MiniBlocs" width="640" height="160"></h2>
    <p class="accroche">{e(t['mb_accroche'])}</p>
    <p>{e(t['mb_resume'])}</p>
    <p class="sortie">{e(t['mb_sortie'])}</p>
    <p class="boutons">{steam_bouton(t)} <a class="btn btn-contour" href="{lien('miniblocs', lang, lang)}">{e(t['en_savoir_plus'])}</a></p>
  </div>
</section>

<section class="jeux" id="jeux" aria-labelledby="t-jeux">
  <div class="cadre">
    <h2 id="t-jeux">{e(t['jeux_titre'])}</h2>
    <p class="intro">{e(t['jeux_intro'])}</p>
    <div class="grille-jeux">{jeux}
    </div>
  </div>
</section>

<section class="studio cadre" aria-labelledby="t-studio">
  <div>
    <h2 id="t-studio">{e(t['studio_titre'])}</h2>
    {studio}
  </div>
  <div class="chiffres">{chiffres}</div>
</section>
"""
    return page(lang, "accueil", t["titre_site"], t["desc_site"], corps)


def p_miniblocs(lang: str) -> str:
    t = TEXTES[lang]
    r = racine(lang)
    atouts = "".join(
        f'<article class="atout">{icone(ic)}<h3>{e(a)}</h3><p>{e(b)}</p></article>' for a, b, ic in t["atouts"])
    gal = ""
    for i, (nom, fr, en) in enumerate(GALERIE):
        leg = fr if lang == "fr" else en
        gal += (f'<figure><a href="{r}img/{nom}-1600.webp" data-galerie="{i}">'
                f'{img(r, nom, leg, "", "(min-width: 900px) 360px, 50vw")}</a>'
                f'<figcaption>{e(leg)}</figcaption></figure>')
    infos = "".join(f"<div><dt>{e(a)}</dt><dd>{e(b)}</dd></div>" for a, b in t["infos"])
    corps = f"""
<section class="mb-hero">
  {img(r, 'hero-horizon', '', 'hero-fond', '100vw', 'eager')}
  <div class="cadre mb-hero-in">
    <h1><img class="logo-mb-grand" src="{r}img/miniblocs-logo.svg" alt="MiniBlocs" width="760" height="190"></h1>
    <p class="accroche">{e(t['mb_accroche'])}</p>
    <p class="boutons">{steam_bouton(t)}</p>
    <p class="sortie">{e(t['mb_sortie'])}</p>
  </div>
</section>

<section class="cadre video-bloc" aria-labelledby="t-video">
  <h2 id="t-video" class="visuel-cache">{e(t['bande_annonce'])}</h2>
  <video controls preload="none" playsinline poster="{r}img/bande-annonce.webp" width="1280" height="720">
    <source src="{r}media/miniblocs-bande-annonce.mp4" type="video/mp4">
    {e(t['video_non'])}
  </video>
  <p class="resume">{e(t['mb_resume'])}</p>
</section>

<section class="cadre" aria-labelledby="t-atouts">
  <h2 id="t-atouts">{e(t['atouts_titre'])}</h2>
  <div class="grille-atouts">{atouts}</div>
</section>

<section class="cadre" aria-labelledby="t-gal">
  <h2 id="t-gal">{e(t['galerie_titre'])}</h2>
  <div class="galerie">{gal}</div>
</section>

<section class="cadre infos-bloc" aria-labelledby="t-infos">
  <div>
    <h2 id="t-infos">{e(t['infos_titre'])}</h2>
    <dl class="infos">{infos}</dl>
  </div>
  <div class="cta-steam">
    <img src="{r}img/miniblocs-logo.svg" alt="" width="320" height="80">
    <p>{e(t['contact_steam'])}</p>
    <p>{steam_bouton(t)}</p>
    <p><a href="{lien('presse', lang, lang)}">{e(t['pied_presse'])} →</a></p>
  </div>
</section>

<dialog class="visionneuse" aria-label="{e(t['galerie_titre'])}">
  <form method="dialog"><button class="fermer" aria-label="{e(t['fermer'])}">×</button></form>
  <button class="prec" type="button" aria-label="←">‹</button>
  <img src="" alt="">
  <button class="suiv" type="button" aria-label="→">›</button>
  <p class="legende"></p>
</dialog>
"""
    return page(lang, "miniblocs", t["mb_titre_page"], t["mb_desc_page"], corps, "img/og-miniblocs.jpg")


def p_presse(lang: str) -> str:
    t = TEXTES[lang]
    r = racine(lang)
    fiche_s = "".join(
        f"<div><dt>{e(a)}</dt><dd>{email_lien() if '{email}' in b else e(b)}</dd></div>" for a, b in t["studio_fiche"])
    fiche_j = "".join(f"<div><dt>{e(a)}</dt><dd>{e(b)}</dd></div>" for a, b in t["infos"])
    longue = "".join(f"<p>{e(p)}</p>" for p in t["mb_longue"])
    points = "".join(f"<li>{e(p)}</li>" for p in t["points"])
    logos = ""
    for nom, fond in [("manigames-piste1-cube", "clair"), ("manigames-piste1-cube-sombre", "sombre"),
                      ("manigames-piste1-cube-empile", "clair"), ("manigames-piste1-icone", "clair"),
                      ("miniblocs-logo", "clair")]:
        logos += (f'<figure class="logo-kit fond-{fond}"><img src="{r}presse/logos/{nom}.svg" alt="{nom}" loading="lazy">'
                  f'<figcaption>{nom} · <a href="{r}presse/logos/{nom}.svg" download>SVG</a> · '
                  f'<a href="{r}presse/logos/{nom}.png" download>PNG</a></figcaption></figure>')
    caps = ""
    for nom, fr, en in GALERIE:
        leg = fr if lang == "fr" else en
        caps += (f'<figure><a href="{r}presse/captures/{nom}.jpg" download>{img(r, nom, leg, "", "300px")}</a>'
                 f'<figcaption><a href="{r}presse/captures/{nom}.jpg" download>{e(nom)}.jpg</a></figcaption></figure>')
    corps = f"""
<section class="cadre entete-page">
  <h1>{e(t['presse_titre_page'])}</h1>
  <p class="intro">{e(t['presse_intro'])}</p>
  <p><a class="btn btn-jaune" href="{r}presse/manigames-kit-presse.zip" download>{e(t['telecharger_kit'])}</a></p>
</section>

<section class="cadre presse-fiches">
  <div><h2>{e(t['fiche_studio'])}</h2><dl class="infos">{fiche_s}</dl></div>
  <div><h2>{e(t['fiche_jeu'])}</h2><dl class="infos">{fiche_j}</dl></div>
</section>

<section class="cadre texte-long">
  <h2>{e(t['desc_courte'])}</h2>
  <blockquote>{e(t['mb_resume'])}</blockquote>
  <h2>{e(t['desc_longue'])}</h2>
  {longue}
  <h2>{e(t['points_cles'])}</h2>
  <ul class="puces">{points}</ul>
</section>

<section class="cadre">
  <h2>{e(t['logos_titre'])}</h2>
  <p>{e(t['logos_texte'])}</p>
  <div class="grille-logos">{logos}</div>
</section>

<section class="cadre">
  <h2>{e(t['captures_titre'])}</h2>
  <div class="galerie galerie-presse">{caps}</div>
</section>

<section class="cadre">
  <h2>{e(t['video_titre'])}</h2>
  <p>{e(t['video_texte'])} <a href="{r}media/miniblocs-bande-annonce.mp4" download>miniblocs-bande-annonce.mp4</a></p>
  <p>{t['contact_presse'].replace('{email_lien}', email_lien())}</p>
</section>
"""
    return page(lang, "presse", t["presse_titre_page"], t["presse_desc_page"], corps)


def p_contact(lang: str) -> str:
    t = TEXTES[lang]
    reseaux = ""
    if any(CONFIG["reseaux"].values()):
        liens = "".join(f'<li><a href="{e(u)}" rel="noopener">{e(n)}</a></li>' for n, u in CONFIG["reseaux"].items() if u)
        reseaux = f"<h2>{e(t['contact_reseaux'])}</h2><ul class='liste-reseaux'>{liens}</ul>"
    corps = f"""
<section class="cadre entete-page contact">
  <h1>{e(t['contact_titre_page'])}</h1>
  <p class="intro">{e(t['contact_texte'])}</p>
  <p class="email-grand"><a class="btn btn-jaune" href="mailto:{e(CONFIG['email'])}">{e(CONFIG['email'])}</a></p>
  {reseaux}
  <div class="encadre">
    <p>{e(t['contact_steam'])}</p>
    <p>{steam_bouton(t)}</p>
  </div>
</section>
"""
    return page(lang, "contact", t["contact_titre_page"], t["contact_desc_page"], corps)


def p_legal(lang: str) -> str:
    t = TEXTES[lang]
    pays = f"<br>{e(CONFIG['pays'])}" if CONFIG["pays"] else ""
    donnees = "".join(f"<p>{e(p)}</p>" for p in t["legal_donnees_texte"])
    corps = f"""
<section class="cadre texte-long entete-page">
  <h1>{e(t['legal_titre_page'])}</h1>
  <h2>{e(t['legal_editeur'])}</h2>
  <p>{e(CONFIG['editeur'])}{pays}<br>{e(t['contact'])} : {email_lien()}</p>
  <h2>{e(t['legal_hebergeur'])}</h2>
  <p>{e(t['legal_hebergeur_texte'])}</p>
  <h2>{e(t['legal_donnees'])}</h2>
  {donnees}
  <h2>{e(t['legal_droits'])}</h2>
  <p>{e(t['legal_droits_texte'])}</p>
  <h2>{e(t['legal_donnees_jeu'])}</h2>
  <p>{e(t['legal_donnees_jeu_texte'])}</p>
</section>
"""
    return page(lang, "legal", t["legal_titre_page"], t["legal_desc_page"], corps)


def p_404(lang: str) -> str:
    t = TEXTES[lang]
    # page servie à n'importe quelle adresse : chemins absolus depuis la racine du site
    corps = f"""
<section class="cadre entete-page page-404">
  <h1>{e(t['p404_titre'])}</h1>
  <p class="intro">{e(t['p404_texte'])}</p>
  <p><a class="btn btn-jaune" href="/{'en/' if lang == 'en' else ''}">{e(t['p404_bouton'])}</a></p>
</section>
"""
    s = page(lang, "404", t["p404_titre"], t["p404_texte"], corps)
    # liens et ressources relatifs -> absolus (la page peut être servie depuis /a/b/c)
    base = "/en/" if lang == "en" else "/"
    return s.replace("<head>\n", f'<head>\n<base href="{base}">\n', 1).replace(
        '<meta name="description"', '<meta name="robots" content="noindex">\n<meta name="description"', 1)


# ------------------------------------------------------------------ médias
def _run(*cmd):
    subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def webp(src: str, nom: str, recadre: str | None = None) -> None:
    """nom-800.webp et nom-1600.webp (16:9) dans public/img/."""
    d = os.path.join(PUBLIC, "img")
    os.makedirs(d, exist_ok=True)
    base = ["convert", src]
    if recadre:
        base += ["-gravity", "center", "-crop", recadre, "+repage"]
    for w in (800, 1600):
        _run(*base, "-resize", f"{w}x{w * 9 // 16}^", "-gravity", "center", "-extent", f"{w}x{w * 9 // 16}",
             "-quality", "80", os.path.join(d, f"{nom}-{w}.webp"))


def medias() -> None:
    img_d = os.path.join(PUBLIC, "img")
    os.makedirs(img_d, exist_ok=True)
    for nom, _, _ in GALERIE:
        webp(os.path.join(CAPTURES, nom + ".png"), nom)
    gv = os.path.join(GRANDES, "grand-village.png")
    gh = os.path.join(GRANDES, "grand-horizon.png")
    webp(gv if os.path.exists(gv) else os.path.join(CAPTURES, "01-village-vu-du-ciel.png"), "hero-village")
    webp(gh if os.path.exists(gh) else os.path.join(CAPTURES, "02-campagne-a-l-horizon.png"), "hero-horizon")
    capsule = os.path.join(RACINE, "marque", "steam", "capsule-principale-1232x706.png")
    webp(capsule, "capsule-miniblocs")
    shutil.copy(os.path.join(MARQUE, "miniblocs-logo.svg"), os.path.join(img_d, "miniblocs-logo.svg"))
    # images de partage (1200 × 630)
    _run("convert", capsule, "-resize", "1200x630^", "-gravity", "center", "-extent", "1200x630",
         "-quality", "85", os.path.join(img_d, "og-miniblocs.jpg"))
    og = os.path.join(RACINE, "marque", "steam", "og-manigames.png")
    if os.path.exists(og):
        _run("convert", og, "-quality", "85", os.path.join(img_d, "og.jpg"))
    # vidéo : 1080p allégée + image d'attente
    vid = os.path.join(CAPTURES, "miniblocs-bande-annonce-v2.mp4")  # tools/marque/bande_annonce.py
    if not os.path.exists(vid):
        vid = os.path.join(CAPTURES, "miniblocs-demo-bande-annonce.mp4")
    md = os.path.join(PUBLIC, "media")
    os.makedirs(md, exist_ok=True)
    sortie = os.path.join(md, "miniblocs-bande-annonce.mp4")
    if os.path.exists(vid) and not os.path.exists(sortie):
        _run("ffmpeg", "-y", "-i", vid, "-vf", "scale=1280:-2", "-c:v", "libx264", "-preset", "slow", "-crf", "28",
             "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "128k", "-movflags", "+faststart", sortie)
    if os.path.exists(vid):
        tmp = os.path.join(md, "_poster.png")
        _run("ffmpeg", "-y", "-ss", "12", "-i", vid, "-frames:v", "1", tmp)
        _run("convert", tmp, "-resize", "1600x900", "-quality", "80", os.path.join(img_d, "bande-annonce.webp"))
        os.remove(tmp)
    # kit presse
    pd = os.path.join(PUBLIC, "presse")
    for sd in ("logos", "captures"):
        os.makedirs(os.path.join(pd, sd), exist_ok=True)
    for nom in ("manigames-piste1-cube", "manigames-piste1-cube-sombre", "manigames-piste1-cube-empile",
                "manigames-piste1-icone", "miniblocs-logo"):
        for ext in ("svg", "png"):
            shutil.copy(os.path.join(MARQUE, f"{nom}.{ext}"), os.path.join(pd, "logos", f"{nom}.{ext}"))
    for nom, _, _ in GALERIE:
        _run("convert", os.path.join(CAPTURES, nom + ".png"), "-quality", "86",
             os.path.join(pd, "captures", nom + ".jpg"))
    # favicons
    ico = os.path.join(MARQUE, "manigames-piste1-icone.svg")
    shutil.copy(ico, os.path.join(PUBLIC, "favicon.svg"))
    png_ico = os.path.join(MARQUE, "manigames-piste1-icone.png")
    _run("convert", png_ico, "-resize", "32x32", os.path.join(PUBLIC, "favicon-32.png"))
    _run("convert", png_ico, "-resize", "150x150", "-background", "#FFF8EC", "-gravity", "center",
         "-extent", "180x180", os.path.join(PUBLIC, "apple-touch-icon.png"))
    _run("convert", png_ico, "-resize", "48x48", "-define", "icon:auto-resize=48,32,16",
         os.path.join(PUBLIC, "favicon.ico"))


def kit_zip() -> None:
    pd = os.path.join(PUBLIC, "presse")
    z = os.path.join(pd, "manigames-kit-presse.zip")
    with zipfile.ZipFile(z, "w", zipfile.ZIP_STORED) as zf:
        for sd in ("logos", "captures"):
            for f in sorted(os.listdir(os.path.join(pd, sd))):
                zf.write(os.path.join(pd, sd, f), f"manigames-kit-presse/{sd}/{f}")
        for lang in ("fr", "en"):
            t = TEXTES[lang]
            lignes = [f"MiniBlocs · ManiGames ({lang.upper()})", "",
                      t["desc_courte"], t["mb_resume"], "", t["desc_longue"], *t["mb_longue"], "",
                      t["points_cles"], *[f"- {p}" for p in t["points"]], "",
                      *[f"{a} : {b}" for a, b in t["infos"]], "",
                      f"{CONFIG['domaine']}", f"{CONFIG['email']}", ""]
            zf.writestr(f"manigames-kit-presse/miniblocs-{lang}.txt", "\n".join(lignes))


def polices() -> None:
    """Sous-ensembles WOFF2 (latin) d'Outfit et Nunito."""
    from fontTools import subset
    from fontTools.ttLib import TTFont
    from fontTools.varLib import instancer
    d = os.path.join(PUBLIC, "polices")
    os.makedirs(d, exist_ok=True)
    unicodes = "U+0000-00FF,U+0131,U+0152-0153,U+02C6,U+02DA,U+02DC,U+2000-206F,U+20AC,U+2122,U+2190-2193,U+2212"
    for src, dst, plage in (("Outfit.ttf", "outfit.woff2", (400, 800)), ("Nunito.ttf", "nunito.woff2", (400, 800))):
        f = TTFont(os.path.join(POLICES, src))
        f = instancer.instantiateVariableFont(f, {"wght": plage})
        tampon = io.BytesIO()
        f.save(tampon)
        tampon.seek(0)
        f = TTFont(tampon)
        opts = subset.Options()
        opts.flavor = "woff2"
        opts.layout_features = ["kern", "liga", "calt"]
        s = subset.Subsetter(opts)
        s.populate(unicodes=subset.parse_unicodes(unicodes))
        s.subset(f)
        f.flavor = "woff2"
        f.save(os.path.join(d, dst))
    shutil.copy(os.path.join(POLICES, "OFL-outfit.txt"), os.path.join(d, "OFL-outfit.txt"))
    shutil.copy(os.path.join(POLICES, "OFL-nunito.txt"), os.path.join(d, "OFL-nunito.txt"))


def fichiers_fixes() -> None:
    src = os.path.join(RACINE, "site", "src")
    for f in ("style.css", "site.js", ".htaccess"):
        shutil.copy(os.path.join(src, f), os.path.join(PUBLIC, f))
    with open(os.path.join(PUBLIC, "robots.txt"), "w") as f:
        f.write(f"User-agent: *\nAllow: /\nSitemap: {CONFIG['domaine']}/sitemap.xml\n")
    urls = []
    for pid, (fr, en) in PAGES.items():
        if pid == "404":
            continue
        for p in (fr, en):
            urls.append(f"  <url><loc>{CONFIG['domaine']}/{p.replace('index.html', '')}</loc></url>")
    with open(os.path.join(PUBLIC, "sitemap.xml"), "w") as f:
        f.write('<?xml version="1.0" encoding="UTF-8"?>\n'
                '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n' + "\n".join(urls) + "\n</urlset>\n")


def construire(avec_medias: bool) -> None:
    os.makedirs(os.path.join(PUBLIC, "en"), exist_ok=True)
    if avec_medias:
        medias()
        kit_zip()
        polices()
    fichiers_fixes()
    gens = {"accueil": p_accueil, "miniblocs": p_miniblocs, "presse": p_presse,
            "contact": p_contact, "legal": p_legal, "404": p_404}
    for pid, f in gens.items():
        for lang in ("fr", "en"):
            with open(os.path.join(PUBLIC, chemin(pid, lang)), "w", encoding="utf-8") as fh:
                fh.write(f(lang))
    print("Site écrit dans", os.path.relpath(PUBLIC, RACINE))


if __name__ == "__main__":
    construire("--medias" in sys.argv)
