# Site ManiGames (www.manigames.online)

Site vitrine statique, en français et en anglais : accueil du studio, page MiniBlocs
(bande-annonce, images, infos), kit presse, contact, mentions légales, page 404.
Pas de base de données, pas de PHP, pas de cookies ni de traceurs : de simples fichiers
HTML, CSS et images, que n'importe quel hébergement sait servir.

| Dossier | Contenu |
|---|---|
| `public/` | **le site prêt à téléverser** (c'est ce dossier qu'on envoie chez Infomaniak) |
| `src/` | feuille de style, petit script de la visionneuse, `.htaccess` |
| `../tools/site/construire.py` | fabrique `public/` : pages FR et EN, images, polices, kit presse |
| `../marque/` | logos (SVG, PNG) et capsules Steam, voir [../marque/README.md](../marque/README.md) |

La vidéo, les captures du kit presse et le ZIP du kit ne sont pas dans Git (trop lourds) :
`construire.py --medias` les refait à partir des captures de la démo (fichiers du projet,
`captures/demo/`). Le dossier complet, prêt à téléverser, est aussi dans les fichiers du
projet : `site-manigames/manigames-site.zip`.

## Mettre le site en ligne chez Infomaniak

Il faut un **hébergement Web** lié au domaine (le nom de domaine seul ne suffit pas).
Le site pèse environ 16 Mo.

### 1. Préparer l'hébergement (une seule fois)

1. Se connecter au **Manager Infomaniak** (manager.infomaniak.com).
2. Ouvrir **Hébergement Web** et choisir l'hébergement. S'il n'y en a pas encore, en
   commander un (Infomaniak propose une petite offre avec le domaine : vérifier qu'elle a
   au moins 50 Mo d'espace, sinon prendre l'hébergement Web payant).
3. Dans l'hébergement, **Ajouter un site** (ou ouvrir celui qui existe) pour
   `manigames.online`, avec **www** comme adresse principale. Noter le **dossier du site**
   affiché dans ses paramètres (souvent `/sites/manigames.online` ou `/web`).
4. Dans le site, partie **Sécurité / Certificat SSL** : activer le certificat gratuit
   **Let's Encrypt** pour `manigames.online` et `www.manigames.online`. Sans lui,
   la redirection vers https du fichier `.htaccess` mènerait à une erreur.

### 2. Envoyer les fichiers

**Méthode simple : le gestionnaire de fichiers du Manager**

1. Hébergement Web → **FTP / SSH** → **Gestionnaire de fichiers** (ou « FTP Manager »).
2. Ouvrir le **dossier du site** noté plus haut. S'il contient une page d'attente
   d'Infomaniak (`index.html` ou `index.php`), la supprimer.
3. Téléverser **le contenu** du dossier `public` (pas le dossier lui-même) : les fichiers
   `index.html`, `.htaccess`, `style.css`… et les dossiers `en`, `img`, `media`, `polices`,
   `presse` doivent se trouver directement dans le dossier du site. Le plus rapide : envoyer
   `manigames-site.zip`, puis clic droit → **Décompresser** dans le dossier du site.

**Autre méthode : FileZilla (gratuit)**

1. Hébergement Web → FTP / SSH → **Créer un compte FTP** (nom et mot de passe à choisir).
   Le Manager affiche l'**adresse du serveur FTP**.
2. Dans FileZilla : Hôte = cette adresse, identifiant et mot de passe du compte, port 21
   (FileZilla choisit le FTP chiffré tout seul).
3. À droite, ouvrir le dossier du site ; à gauche, ouvrir `public` ; tout sélectionner à
   gauche et glisser à droite.

> Le fichier `.htaccess` commence par un point : sur certains ordinateurs il est caché.
> Vérifier qu'il est bien arrivé sur le serveur (il force https et www, et affiche la
> page 404 maison).

### 3. Vérifier

- https://www.manigames.online s'affiche, et http://manigames.online y redirige.
- Le bouton **EN** mène à la version anglaise, **FR** revient au français.
- La bande-annonce se lance sur la page MiniBlocs.
- https://www.manigames.online/nimportequoi affiche la page « Page introuvable ».

Si une ancienne version reste affichée : recharger avec **Ctrl + F5**.

### 4. L'adresse contact@manigames.online

Le site l'affiche partout (contact, presse, mentions légales). La créer dans le Manager :
**Service Mail** → ajouter l'adresse `contact` sur `manigames.online`.

## Changer quelque chose

Tout se règle en haut de `tools/site/construire.py`, dans `CONFIG` :

- `steam_miniblocs` : coller le lien de la page Steam dès qu'elle est ouverte. Les boutons
  « Bientôt sur Steam » deviennent « Ajouter à ma liste de souhaits ».
- `reseaux` : coller les adresses YouTube, Discord, TikTok une fois les comptes créés
  (vides = liens cachés).
- `email`, `editeur`, `pays` : contact et mentions légales.

Les textes sont dans `TEXTES` (`fr` et `en`, mêmes clés). Puis :

```
python3 tools/site/construire.py            # pages seulement
python3 tools/site/construire.py --medias   # + images, vidéo, polices, kit presse
```

et renvoyer les fichiers changés chez Infomaniak (souvent seulement les `.html`).
Il suffit de demander à Claude : il modifie, reconstruit et redonne le ZIP.

Outils utilisés : Python 3 avec `fonttools` et `brotli` (polices), ImageMagick, ffmpeg,
Node avec Playwright (rendu des logos et des capsules).
