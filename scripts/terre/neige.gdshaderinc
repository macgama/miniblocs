// Manteau neigeux commun au terrain détaillé (terrain.gdshader), au relief
// lointain (horizon.gdshader) et aux plantes (plante.gdshader) : les trois
// calculent la même neige au même endroit, donc pas de bord net entre eux.
// Réglé par TerrainWorld.neige_params() (Plantes.applique_neige, HorizonTerrain).

// Neige tombée au point de référence (0 à 1, d'après la météo du lieu).
uniform float neige = 0.0;
// Altitude (m) du point de référence (là où la météo est calculée).
uniform float neige_alt_ref = 0.0;
// Altitude (m) de l'isotherme 0 °C moyen du jour : au-dessus, la neige de
// saison tient (hiver : bas ; été : seulement les hauts sommets).
uniform float neige_iso0 = 100000.0;
// Direction (x, z) vers l'équateur : les pentes tournées vers elle sont au soleil.
uniform vec2 neige_equateur = vec2(0.0, 1.0);

// Couverture de neige (0 à 1) à l'altitude alt, pour une surface de normale n
// (repère du monde). expo (0 à 1) : poids de l'exposition et de la pente.
float neige_locale(float alt, vec3 n, float expo) {
	float dh = alt - neige_alt_ref;
	// Neige tombée : plus épaisse en montant, plus mince en descendant.
	float v = neige * (1.0 + max(dh, 0.0) / 400.0) - max(-dh, 0.0) / 1200.0;
	// Neige de saison au-dessus de l'isotherme 0 °C (à partir de 300 m au-dessus
	// du lieu : en bas, c'est la météo du jour qui décide).
	float s = smoothstep(neige_iso0 - 150.0, neige_iso0 + 450.0, alt) * clamp(dh / 300.0, 0.0, 1.0);
	v = max(v, s);
	// Exposition : l'adret (face au soleil) fond, l'ubac garde sa neige ;
	// les pentes très raides (falaises) ne la retiennent pas.
	float face = dot(n.xz, neige_equateur);
	v += expo * (face > 0.0 ? -0.55 * face : -0.3 * face);
	v *= mix(1.0, smoothstep(0.45, 0.75, n.y), expo);
	return clamp(v, 0.0, 1.0);
}

float neige_hache(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float neige_bruit(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(neige_hache(i), neige_hache(i + vec2(1.0, 0.0)), f.x),
		mix(neige_hache(i + vec2(0.0, 1.0)), neige_hache(i + vec2(1.0, 1.0)), f.x), f.y);
}

// Part du sol couverte (0 à 1) pour une couverture v : d'abord par taches,
// puis partout. Les taches fines s'effacent au loin (sinon moiré) : on garde
// alors leur moyenne.
float neige_couvre(vec2 xz, float v) {
	float px = max(length(fwidth(xz)), 1e-4);
	float fin = 1.0 - smoothstep(0.15, 0.6, px * 1.7);
	float moyen = 1.0 - smoothstep(0.15, 0.6, px * 0.35);
	float large = 1.0 - smoothstep(0.15, 0.6, px * 0.02);
	float b = mix(0.5, neige_bruit(xz * 0.35), moyen) * 0.45
		+ mix(0.5, neige_bruit(xz * 1.7), fin) * 0.3
		+ mix(0.5, neige_bruit(xz * 0.02), large) * 0.25;
	// Au loin, la bordure des taches s'élargit (fondu plutôt qu'escalier).
	float w = 0.1 + 0.3 * (1.0 - fin);
	return smoothstep(b - w - 0.05, b + w, v * 1.25 - 0.1);
}

const vec3 NEIGE_COULEUR = vec3(0.86, 0.89, 0.93);
