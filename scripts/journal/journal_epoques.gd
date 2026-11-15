class_name JournalEpoques
extends RefCounted
## Le journal change avec l'époque de la partie : nom, devise, prix, mise en page
## et vocabulaire. De la gazette de 1800 vendue à la criée au site d'information
## « gratuit » d'aujourd'hui. L'année vient de la date de la partie (voir Journal.annee()).

## Époques, de la plus ancienne à la plus récente. « de » : première année.
## titre : nom du journal (%s = ville) ; devise : sous le titre ; prix ; support ;
## papier et encre : couleurs de la page ; envoye : qui signe les articles.
const EPOQUES := [
	{"id": "gazette", "de": 0, "titre": "La Gazette de %s", "devise": "Feuille d'annonces, affiches et avis divers",
		"prix": "2 sous", "support": "feuille", "envoye": "notre correspondant", "image": "gravure",
		"papier": Color("efe2c2"), "encre": Color("3a2c1a"), "filet": Color("7a5c34"), "colonnes": false},
	{"id": "courrier", "de": 1830, "titre": "Le Courrier de %s", "devise": "Journal politique, littéraire et d'annonces",
		"prix": "10 centimes", "support": "journal", "envoye": "notre correspondant", "image": "gravure",
		"papier": Color("f1e6c9"), "encre": Color("33281a"), "filet": Color("6e5533"), "colonnes": true},
	{"id": "petit", "de": 1870, "titre": "Le Petit Journal de %s", "devise": "Le plus fort tirage du canton",
		"prix": "5 centimes", "support": "journal", "envoye": "notre reporter", "image": "dessin",
		"papier": Color("f2e9d0"), "encre": Color("2b241a"), "filet": Color("8c2f1e"), "colonnes": true},
	{"id": "echo", "de": 1914, "titre": "L'Écho de %s", "devise": "Quotidien régional d'information",
		"prix": "20 centimes", "support": "journal", "envoye": "notre envoyé spécial", "image": "photo",
		"papier": Color("eeeadf"), "encre": Color("22201c"), "filet": Color("333333"), "colonnes": true},
	{"id": "matin", "de": 1945, "titre": "%s-Matin", "devise": "Le quotidien de toute la région",
		"prix": "0,50 F", "support": "journal", "envoye": "notre envoyé spécial", "image": "photo",
		"papier": Color("f4f2ea"), "encre": Color("1d1d1d"), "filet": Color("b3261e"), "colonnes": true},
	{"id": "infos", "de": 1980, "titre": "%s Infos", "devise": "Toute l'actualité de votre ville",
		"prix": "5 F", "support": "journal", "envoye": "notre journaliste", "image": "photo couleur",
		"papier": Color("f7f6f1"), "encre": Color("1a1a1a"), "filet": Color("1f5fa8"), "colonnes": true},
	{"id": "actu", "de": 2002, "titre": "%s Actu", "devise": "Votre journal, aussi sur Internet",
		"prix": "1,20 €", "support": "journal", "envoye": "notre journaliste", "image": "photo couleur",
		"papier": Color("f8f8f6"), "encre": Color("161616"), "filet": Color("d0451b"), "colonnes": true},
	{"id": "web", "de": 2015, "titre": "%s.info", "devise": "L'info locale, en continu",
		"prix": "Gratuit (avec 47 cookies)", "support": "site", "envoye": "la rédaction", "image": "photo",
		"papier": Color("fbfbfb"), "encre": Color("141414"), "filet": Color("0a84c1"), "colonnes": true},
]


static func de_annee(annee: int) -> Dictionary:
	var e: Dictionary = EPOQUES[0]
	for d in EPOQUES:
		if annee >= int(d.de):
			e = d
	return e


static func par_id(id: String) -> Dictionary:
	for d in EPOQUES:
		if d.id == id:
			return d
	return EPOQUES[0]


## Un modèle de texte vaut-il pour cette année ? (String : toujours ; {"t", "de", "a"} : entre ces années.)
static func convient(modele, annee: int) -> bool:
	if modele is String:
		return true
	var m: Dictionary = modele
	return annee >= int(m.get("de", -100000)) and annee <= int(m.get("a", 100000))


static func texte_de(modele) -> String:
	return modele if modele is String else String((modele as Dictionary).t)


## Modèles de la liste qui valent pour l'année (jamais vide si la liste ne l'est pas).
static func filtrer(liste: Array, annee: int) -> Array:
	var out := []
	for m in liste:
		if convient(m, annee):
			out.append(texte_de(m))
	if out.is_empty() and not liste.is_empty():
		out.append(texte_de(liste[0]))
	return out
