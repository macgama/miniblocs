class_name GisementsMonde
extends RefCounted
## Grandes régions minières et pétrolières réelles de la Terre.
##
## Chaque entrée est une province (bassin, ceinture, district) : centre
## approximatif, rayon et richesse relative. Ce sont des faits géographiques
## connus (manuels de géologie, atlas) ; aucune base de données n'est recopiée.
## Dans une province, CarteRessources place les gisements avec un bruit
## déterministe calculé sur les vraies coordonnées : tout le monde trouve les
## mêmes gisements au même endroit. Hors des provinces, de petits gisements
## locaux restent possibles (FOND), plus rares et plus pauvres.
##
## Plus tard (voir docs/ressources.md) : remplacer ou compléter ce tableau par
## un fichier précalculé à partir de USGS MRDS (domaine public) et de Global
## Energy Monitor (CC BY 4.0).

## [ressource, nom, latitude, longitude, rayon (km), richesse 0-1]
const PROVINCES := [
	# --- Fer ---------------------------------------------------------------------
	["fer", "Bassin ferrifère lorrain", 49.30, 5.95, 45.0, 0.7],
	["fer", "Kiruna-Malmberget (Laponie)", 67.85, 20.20, 40.0, 1.0],
	["fer", "Pilbara", -22.50, 118.50, 260.0, 1.0],
	["fer", "Carajás", -6.05, -50.25, 80.0, 1.0],
	["fer", "Quadrilatère ferrifère (Minas Gerais)", -20.20, -43.80, 70.0, 0.9],
	["fer", "Kryvyï Rih", 47.90, 33.40, 40.0, 0.9],
	["fer", "Anomalie magnétique de Koursk", 51.30, 37.00, 120.0, 0.9],
	["fer", "Mesabi Range (Minnesota)", 47.50, -92.60, 80.0, 0.8],
	["fer", "Fosse du Labrador", 53.00, -66.90, 150.0, 0.8],
	["fer", "Simandou", 8.60, -8.90, 60.0, 0.9],
	["fer", "Bailadila", 18.70, 81.20, 50.0, 0.8],
	["fer", "Keonjhar-Joda (Odisha)", 21.85, 85.45, 70.0, 0.8],
	["fer", "Anshan", 41.10, 123.00, 50.0, 0.7],
	["fer", "Kedia d'Idjil (Zouérate)", 22.70, -12.50, 60.0, 0.8],
	["fer", "Sishen-Kathu", -27.80, 23.00, 60.0, 0.8],
	["fer", "Bassin de Normandie (fer de May)", 48.95, -0.45, 30.0, 0.4],
	# --- Charbon -------------------------------------------------------------------
	["charbon", "Bassin de la Ruhr", 51.50, 7.20, 50.0, 0.9],
	["charbon", "Bassin minier du Nord-Pas-de-Calais", 50.45, 2.80, 45.0, 0.7],
	["charbon", "Bassin houiller lorrain", 49.15, 6.75, 25.0, 0.7],
	["charbon", "Bassin houiller de la Loire (Saint-Étienne)", 45.45, 4.40, 20.0, 0.5],
	["charbon", "Bassin des Cévennes (Alès)", 44.15, 4.10, 20.0, 0.4],
	["charbon", "Bassin de Blanzy-Montceau", 46.67, 4.37, 20.0, 0.5],
	["charbon", "Haute-Silésie", 50.20, 18.90, 50.0, 0.9],
	["charbon", "Donbass", 48.00, 38.00, 120.0, 0.9],
	["charbon", "Kouzbass", 54.00, 86.70, 150.0, 1.0],
	["charbon", "Powder River Basin", 44.00, -105.50, 120.0, 1.0],
	["charbon", "Appalaches centrales", 38.00, -81.50, 200.0, 0.8],
	["charbon", "Bassin de l'Illinois", 38.50, -88.50, 150.0, 0.7],
	["charbon", "Shanxi", 37.80, 112.50, 200.0, 1.0],
	["charbon", "Ordos (Mongolie-Intérieure)", 39.50, 110.00, 150.0, 1.0],
	["charbon", "Jharia (Dhanbad)", 23.75, 86.40, 50.0, 0.9],
	["charbon", "Korba", 22.35, 82.70, 60.0, 0.8],
	["charbon", "Bassin de Bowen", -22.50, 148.50, 200.0, 1.0],
	["charbon", "Hunter Valley", -32.50, 151.00, 60.0, 0.8],
	["charbon", "Mpumalanga (Witbank)", -26.00, 29.20, 80.0, 0.9],
	["charbon", "Kalimantan-Est", -0.50, 117.00, 150.0, 0.8],
	["charbon", "El Cerrejón", 11.10, -72.60, 40.0, 0.8],
	["charbon", "Lignite de Lusace", 51.60, 14.30, 40.0, 0.6],
	["charbon", "Lignite rhénan", 50.90, 6.50, 30.0, 0.7],
	["charbon", "Galles du Sud", 51.70, -3.40, 40.0, 0.6],
	# --- Cuivre --------------------------------------------------------------------
	["cuivre", "Désert d'Atacama (Escondida, Chuquicamata)", -23.50, -69.00, 200.0, 1.0],
	["cuivre", "El Teniente", -34.10, -70.40, 60.0, 0.9],
	["cuivre", "Sud du Pérou (Cerro Verde, Toquepala)", -16.80, -71.00, 150.0, 0.9],
	["cuivre", "Copperbelt (Zambie, Katanga)", -12.50, 27.50, 220.0, 1.0],
	["cuivre", "Arizona (Morenci)", 33.00, -110.50, 150.0, 0.8],
	["cuivre", "Bingham Canyon", 40.52, -112.15, 25.0, 0.9],
	["cuivre", "Oyu Tolgoï", 43.00, 106.85, 40.0, 0.9],
	["cuivre", "Olympic Dam", -30.45, 136.90, 40.0, 0.9],
	["cuivre", "Grasberg", -4.05, 137.10, 30.0, 1.0],
	["cuivre", "Norilsk", 69.35, 88.20, 60.0, 0.8],
	["cuivre", "Lubin (Basse-Silésie)", 51.40, 16.20, 40.0, 0.8],
	["cuivre", "Jezkazgan", 47.80, 67.70, 50.0, 0.7],
	["cuivre", "Ceinture pyriteuse ibérique (Rio Tinto)", 37.70, -6.60, 60.0, 0.7],
	# --- Or ------------------------------------------------------------------------
	["or", "Witwatersrand", -26.20, 27.50, 120.0, 1.0],
	["or", "Kalgoorlie (Golden Mile)", -30.75, 121.50, 100.0, 0.9],
	["or", "Carlin Trend (Nevada)", 40.90, -116.30, 80.0, 0.9],
	["or", "Klondike", 63.90, -139.00, 60.0, 0.7],
	["or", "Ceinture d'Ashanti (Obuasi)", 6.20, -1.70, 80.0, 0.9],
	["or", "Muruntau", 41.50, 64.60, 40.0, 0.9],
	["or", "Yanacocha", -6.98, -78.50, 40.0, 0.8],
	["or", "Guyane (placers)", 4.50, -53.50, 120.0, 0.6],
	["or", "Salsigne (Montagne Noire)", 43.33, 2.37, 15.0, 0.5],
	["or", "Limousin (Le Châtelet, Bourneix)", 45.90, 1.50, 50.0, 0.4],
	["or", "Grasberg", -4.05, 137.10, 30.0, 0.8],
	# --- Bauxite -------------------------------------------------------------------
	["bauxite", "Boké (Guinée)", 11.00, -14.00, 120.0, 1.0],
	["bauxite", "Weipa", -12.60, 141.90, 80.0, 1.0],
	["bauxite", "Jamaïque", 18.10, -77.30, 60.0, 0.8],
	["bauxite", "Bauxite de Provence (Brignoles, les Baux)", 43.45, 6.05, 40.0, 0.5],
	["bauxite", "Trombetas", -1.50, -56.40, 60.0, 0.9],
	["bauxite", "Darling Range", -32.80, 116.20, 80.0, 0.9],
	# --- Pétrole -------------------------------------------------------------------
	["petrole", "Ghawar (Arabie saoudite)", 25.40, 49.60, 250.0, 1.0],
	["petrole", "Koweït et sud de l'Irak (Rumaila)", 30.20, 47.50, 150.0, 1.0],
	["petrole", "Kirkouk", 35.50, 44.40, 60.0, 0.9],
	["petrole", "Khouzistan", 31.00, 49.50, 150.0, 1.0],
	["petrole", "Abou Dhabi", 23.50, 53.80, 150.0, 1.0],
	["petrole", "Mer du Nord (Brent)", 61.00, 1.70, 150.0, 0.9],
	["petrole", "Mer du Nord (Ekofisk)", 56.50, 3.20, 100.0, 0.9],
	["petrole", "Sibérie occidentale (Samotlor)", 61.10, 76.70, 300.0, 1.0],
	["petrole", "Bassin permien (Texas)", 31.80, -102.50, 200.0, 1.0],
	["petrole", "Prudhoe Bay", 70.30, -148.70, 80.0, 0.9],
	["petrole", "Golfe du Mexique", 27.50, -90.50, 250.0, 0.9],
	["petrole", "Sables bitumineux de l'Athabasca", 57.00, -111.50, 150.0, 0.9],
	["petrole", "Lac de Maracaibo", 10.00, -71.50, 80.0, 0.9],
	["petrole", "Ceinture de l'Orénoque", 8.50, -64.00, 200.0, 0.9],
	["petrole", "Delta du Niger", 5.00, 6.50, 150.0, 0.9],
	["petrole", "Bassin de Syrte", 29.00, 19.50, 250.0, 0.9],
	["petrole", "Hassi Messaoud", 31.70, 6.10, 100.0, 0.9],
	["petrole", "Cantarell", 19.40, -92.20, 80.0, 0.8],
	["petrole", "Pré-sel du bassin de Santos", -25.00, -43.00, 200.0, 0.9],
	["petrole", "Tengiz", 46.10, 53.40, 80.0, 0.9],
	["petrole", "Bakou", 40.40, 50.00, 60.0, 0.8],
	["petrole", "Daqing", 46.60, 125.00, 80.0, 0.8],
	["petrole", "Large de l'Angola", -7.00, 12.00, 150.0, 0.8],
	["petrole", "Bakken (Dakota du Nord)", 47.80, -103.30, 150.0, 0.8],
	["petrole", "Parentis (Landes)", 44.35, -1.10, 25.0, 0.5],
	["petrole", "Bassin parisien", 48.60, 3.00, 60.0, 0.25],
	# --- Gaz -----------------------------------------------------------------------
	["gaz", "North Field / South Pars", 26.20, 51.80, 120.0, 1.0],
	["gaz", "Ourengoï", 66.10, 76.70, 200.0, 1.0],
	["gaz", "Yamal", 70.50, 70.00, 150.0, 0.9],
	["gaz", "Galkynysh", 37.40, 62.40, 80.0, 0.9],
	["gaz", "Hassi R'Mel", 32.90, 3.30, 80.0, 0.9],
	["gaz", "Groningue", 53.30, 6.80, 40.0, 0.9],
	["gaz", "Lacq", 43.42, -0.62, 20.0, 0.7],
	["gaz", "Marcellus (Appalaches)", 41.50, -77.50, 200.0, 0.8],
	["gaz", "Troll (mer du Nord)", 60.65, 3.70, 60.0, 0.9],
	["gaz", "Mer du Nord sud (Leman)", 53.10, 2.00, 80.0, 0.7],
]

## Petits gisements locaux possibles partout : [richesse maxi, rareté 0-1].
## Plus la rareté est haute, plus les taches sont petites et espacées.
## La bauxite est tropicale (latitude < 30°).
const FOND := {
	"fer": [0.30, 0.55], "charbon": [0.25, 0.6], "cuivre": [0.20, 0.7], "or": [0.15, 0.8],
	"bauxite": [0.30, 0.6], "petrole": [0.15, 0.7], "gaz": [0.15, 0.7],
}


## Distance (km) entre deux points du globe.
static func distance_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
	var p1 := deg_to_rad(lat1)
	var p2 := deg_to_rad(lat2)
	var dp := p2 - p1
	var dl := deg_to_rad(lon2 - lon1)
	var a := sin(dp / 2.0) ** 2 + cos(p1) * cos(p2) * sin(dl / 2.0) ** 2
	return 6371.0 * 2.0 * atan2(sqrt(a), sqrt(maxf(1.0 - a, 0.0)))


## Provinces à moins de `margin` km de leur bord : [{res, name, lat, lon, r, rich, d}],
## triées par distance.
static func near(lat: float, lon: float, margin := 30.0) -> Array:
	var out := []
	for p in PROVINCES:
		var d := distance_km(lat, lon, p[2], p[3])
		if d <= float(p[4]) + margin:
			out.append({"res": p[0], "name": p[1], "lat": p[2], "lon": p[3], "r": p[4], "rich": p[5], "d": d})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.d < b.d)
	return out


## Poids d'une province en un point (0 au bord, sa richesse au centre).
static func weight(p: Dictionary, lat: float, lon: float) -> float:
	var d := distance_km(lat, lon, p.lat, p.lon)
	var k := clampf(1.0 - d / float(p.r), 0.0, 1.0)
	return float(p.rich) * sqrt(k)
