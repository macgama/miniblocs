class_name EpoquesTypes
extends RefCounted
## Services publics d'époque : ce qui tenait lieu d'école, d'hôpital, de
## caserne de pompiers et de commissariat avant les modèles modernes (1950).
## Chacun joue le rôle de son service ("base") : couverture des services
## publics (Maj+U), flotte des urgences (U), métiers des habitants.
## Les modèles sont ceux de la bible des styles (StyleBuilder), à leur taille.

## id -> [style, archétype, base, année, nom, description, réglages]
const DEFS := {
	"ecole_communale": ["colombages", "ecole", "ecole", 1800, "Maison d'école",
		"École communale à classe unique : l'instituteur loge à l'étage.",
		{"w": 20, "d": 14, "emplois": 2, "visiteurs": 60, "cost": 600_000}],
	"ecole_republicaine": ["briques_ind", "ecole", "ecole", 1882, "École de la République",
		"Gratuite, laïque et obligatoire : préau, cour et deux entrées filles et garçons.",
		{"emplois": 12, "visiteurs": 200, "cost": 2_500_000}],
	"hotel_dieu": ["gothique", "grande_maison", "hopital", 1800, "Hôtel-Dieu",
		"L'hôpital de charité tenu par les sœurs : grandes salles communes.",
		{"w": 34, "d": 24, "emplois": 30, "lits": 60, "logements": 0, "cost": 4_000_000}],
	"hopital_pavillons": ["briques_ind", "hopital", "hopital", 1880, "Hôpital à pavillons",
		"Pavillons séparés et aérés contre la contagion, à la manière de Pasteur.",
		{"emplois": 160, "lits": 220, "cost": 12_000_000}],
	"remise_pompes": ["colombages", "atelier", "pompiers", 1800, "Remise des pompes à incendie",
		"La pompe à bras, les seaux de cuir et la cloche d'alarme des pompiers volontaires.",
		{"w": 14, "d": 12, "emplois": 10, "cost": 400_000}],
	"caserne_briques": ["briques_ind", "atelier", "pompiers", 1880, "Caserne de pompiers en briques",
		"Écuries, tour de séchage des tuyaux et pompe à vapeur, puis les premières autopompes.",
		{"w": 22, "d": 18, "emplois": 18, "cost": 1_500_000}],
	"brigade_gendarmerie": ["colombages", "grande_maison", "police", 1800, "Brigade de gendarmerie",
		"Cinq gendarmes à cheval, leurs familles et une cellule.",
		{"w": 16, "d": 12, "emplois": 6, "cost": 500_000}],
	"commissariat_quartier": ["haussmann", "bureaux", "police", 1860, "Commissariat de quartier",
		"Le commissaire, ses agents en pèlerine et le panier à salade dans la cour.",
		{"w": 18, "d": 16, "emplois": 20, "cost": 1_800_000}],
}


static func entries() -> Dictionary:
	var out := {}
	for id in DEFS:
		var d: Array = DEFS[id]
		if not Styles.STYLES.has(String(d[0])):
			continue
		var e := StyleBuilder.make_entry(String(d[0]), String(d[1]))
		e.name = String(d[4])
		e.desc = "%s · %s (dès %d)" % [String(d[5]), Styles.era_name(String(e.era)), int(d[3])]
		e.base = String(d[2])
		e.annee = int(d[3])
		e.region = "monde"
		e.access = ["route", "chemin"]
		e.merge(d[6], true)
		out[id] = e
	return out
