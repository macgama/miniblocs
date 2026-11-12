shader_type spatial;
render_mode cull_disabled;
// Plantes low-poly (arbres, herbes, cultures) posées en MultiMesh.
// Couleur : case de la palette commune (UV) × teinte de l'instance.
// INSTANCE_CUSTOM : rgb = teinte (autour de 1), a = coefficient du vent
// (balancement = a × hauteur², 0 pour les rochers).
//
// Saisons (Plantes.applique_saison) : la carte des rôles (palette_roles.png,
// même découpage que la palette) dit ce qu'est chaque couleur :
// 0 bois, roche… ; 1 feuillage caduc ; 2 feuillage persistant ; 3 herbe ; 4 fleur.

uniform sampler2D palette : source_color, filter_nearest;
uniform sampler2D roles : filter_nearest;
uniform float vent = 1.0;

// Part des feuilles caduques encore là, feuilles rousses, vert tendre.
uniform float feuilles = 1.0;
uniform float automne = 0.0;
uniform float printemps = 0.0;
uniform float herbe_seche = 0.0;
uniform float fleurs = 1.0;
// Neige au sol (0 à 1) : blanchit le dessus des branches, couvre l'herbe.
uniform float neige = 0.0;
// Cultures : taille (0 = moissonné) et maturité (0 vert, 1 mûr) par culture
// (ordre de Sols.CULTURES). -1 = pas une culture.
instance uniform int culture = -1;
uniform float taille_culture[9];
uniform float maturite_culture[9];

varying vec3 teinte;
varying float hasard;
varying float hasard2;

float hache(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void vertex() {
	teinte = INSTANCE_CUSTOM.rgb;
	vec2 o = MODEL_MATRIX[3].xz;
	hasard = hache(o);
	hasard2 = hache(o * 1.37 + 5.1);
	if (culture >= 0) {
		VERTEX *= taille_culture[culture];
	}
	float h = max(VERTEX.y, 0.0);
	float phase = dot(o, vec2(0.071, 0.113));
	float s = sin(TIME * 1.3 + phase) * 0.7 + sin(TIME * 2.9 + phase * 1.7) * 0.3;
	float d = INSTANCE_CUSTOM.a * h * h * vent;
	// Rafales venant de l'ouest, un peu de travers.
	VERTEX.x += d * (0.6 + s);
	VERTEX.z += d * 0.4 * sin(TIME * 1.7 + phase * 0.6);
}

void fragment() {
	vec3 c = texture(palette, UV).rgb * teinte;
	int role = int(texture(roles, UV).r * 4.0 + 0.5);
	float l = dot(c, vec3(0.3, 0.55, 0.15));
	if (role == 1) {
		// Feuillage caduc : chute des feuilles (chaque arbre à son rythme),
		// couleurs d'automne, vert tendre au printemps.
		if (hasard * 0.85 + 0.1 > feuilles) {
			discard;
		}
		float a = clamp(automne * 1.5 - hasard * 0.5, 0.0, 1.0);
		vec3 roux = hasard2 < 0.4 ? vec3(0.62, 0.30, 0.06) : (hasard2 < 0.75 ? vec3(0.70, 0.52, 0.08) : vec3(0.50, 0.12, 0.05));
		c = mix(c, roux * (0.7 + l * 1.5), a);
		c = mix(c, c * vec3(1.15, 1.25, 0.8) + vec3(0.02, 0.04, 0.0), printemps);
	} else if (role == 3) {
		c = mix(c, l * vec3(1.4, 1.15, 0.6), herbe_seche);
		if (neige > 0.4 && hasard2 < (neige - 0.4) * 1.8) {
			discard;
		}
	} else if (role == 4) {
		if (hasard2 > fleurs || neige > 0.3) {
			discard;
		}
	}
	if (culture >= 0) {
		float m = maturite_culture[culture];
		float lc = dot(c, vec3(0.3, 0.55, 0.15));
		if (culture == 3 || culture == 7) {
			// Maïs et riz : ils sèchent en paille.
			c = mix(c, lc * vec3(1.45, 1.15, 0.6), m * 0.8);
		} else {
			c = mix(lc * vec3(0.55, 1.15, 0.35), c, m);
		}
	}
	if (neige > 0.0) {
		// Neige sur ce qui regarde le ciel (branches des sapins, rochers).
		vec3 n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
		// Les flancs raides des sapins en prennent aussi.
		float haut = smoothstep(role == 2 ? 0.0 : 0.15, role == 2 ? 0.45 : 0.55, n.y);
		c = mix(c, vec3(0.86, 0.88, 0.92), haut * clamp(neige * 1.1, 0.0, role == 2 ? 0.75 : 0.9));
	}
	ALBEDO = c;
	ROUGHNESS = 0.9;
	// Un peu de lumière qui traverse les feuilles fines.
	BACKLIGHT = c * 0.25;
}
