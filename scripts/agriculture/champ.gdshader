shader_type spatial;
// Sol d'un champ du joueur (Agriculture), posé juste au-dessus du terrain.
// Deux couches de Sols : celle d'avant le travail en cours et celle d'après ;
// la part déjà travaillée (bandes successives, comme un vrai tracteur) montre
// la nouvelle. Les couches « détail » (herbe…) multiplient une couleur de base.

uniform sampler2DArray sols : filter_linear_mipmap_anisotropic, repeat_enable;
uniform int couche_avant = 11;
uniform int couche_apres = 11;
uniform int premiere_couleur = 11;
uniform float tuile = 4.0;
// Part travaillée (0 à 1), rectangle du champ (x, z, largeur, profondeur) et
// largeur d'une bande de travail (m).
uniform float avance = 0.0;
uniform vec4 rect = vec4(0.0, 0.0, 100.0, 100.0);
uniform float bande = 12.0;
// Rangs dans l'axe Z (sinon X).
uniform bool rangs_z = false;
// Maturité de la culture (0 vert, 1 mûr) et couleur de base des couches détail.
uniform float maturite = 0.0;
uniform float maturite_apres = 0.0;
uniform vec3 base_detail = vec3(0.32, 0.5, 0.2);
uniform bool cereale_seche = false;

varying vec3 world_pos;

vec3 srgb_vers_lineaire(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

vec3 couleur(int n, vec2 p, float m) {
	vec3 t = texture(sols, vec3(p / tuile, float(n))).rgb;
	if (n >= premiere_couleur) {
		vec3 col = srgb_vers_lineaire(t);
		if (n >= premiere_couleur + 1 && n <= premiere_couleur + 8) {
			float l = dot(col, vec3(0.3, 0.55, 0.15));
			if (cereale_seche) {
				col = mix(col, l * vec3(1.45, 1.15, 0.6), m * 0.8);
			} else {
				col = mix(l * vec3(0.55, 1.15, 0.35), col, m);
			}
		}
		return col;
	}
	return base_detail * t * 2.0;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 loc = world_pos.xz - rect.xy;
	// Bandes parallèles aux rangs : le tracteur va et vient, une bande après l'autre.
	float travers = rangs_z ? loc.x : loc.y;
	float le_long = rangs_z ? loc.y : loc.x;
	float largeur = rangs_z ? rect.z : rect.w;
	float longueur = rangs_z ? rect.w : rect.z;
	float n_bandes = max(ceil(largeur / bande), 1.0);
	float b = floor(travers / bande);
	float fait = avance * n_bandes;
	bool ok = b < floor(fait);
	if (!ok && b == floor(fait)) {
		float f = fract(fait);
		// Une bande sur deux se fait dans l'autre sens.
		float x = mod(b, 2.0) < 1.0 ? le_long / longueur : 1.0 - le_long / longueur;
		ok = x < f;
	}
	vec2 p = rangs_z ? world_pos.zx : world_pos.xz;
	vec3 col = ok ? couleur(couche_apres, p, maturite_apres) : couleur(couche_avant, p, maturite);
	// Bord du champ un peu plus sombre (fourrière).
	float bord = min(min(loc.x, rect.z - loc.x), min(loc.y, rect.w - loc.y));
	col *= mix(0.86, 1.0, smoothstep(0.0, 2.5, bord));
	ALBEDO = col;
	ROUGHNESS = 0.95;
}
