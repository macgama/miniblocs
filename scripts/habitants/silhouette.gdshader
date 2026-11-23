shader_type spatial;
// Personnages low-poly (assets/modeles/personnages, faits dans Blender).
// Chaque face pointe une case de la palette des rôles (palette_roles.png) :
//   colonne : 0 peau, 1 cheveux, 2 haut, 3 bas, 4 chaussures, 5 accessoire,
//             6 manche (haut si manches longues, sinon peau),
//             7 mollet (bas si jambes couvertes, sinon peau)
//   ligne   : 0 normal, 1 ombre, 2 clair, 3 couleur fixe de la texture (yeux)
// Les couleurs sont propres à chaque partie du corps (instance uniform) :
// Silhouettes.colorer() les règle toutes d'un coup.
//
// Chapeaux et objets (Tenues.maillage) : couleurs par sommet ; alpha 0 =
// couleur fixe, 0,4 = couleur « accessoire », 0,6 = couleur du motif.
//
// Motifs peints sur les vêtements (Tenues.Motif), sans géométrie en plus :
// 1 bandes réfléchissantes, 2 rayures, 3 carreaux, 4 wax (pois), 5 gilet,
// 6 tablier (taille), 7 tablier à bavette, 8 costume (plastron et cravate).
// Les bras ne reçoivent pas les motifs 5 à 8 (Silhouettes._applique).

uniform sampler2D palette : source_color, filter_nearest;

instance uniform vec4 peau : source_color = vec4(0.85, 0.64, 0.49, 1.0);
instance uniform vec4 cheveux : source_color = vec4(0.23, 0.16, 0.12, 1.0);
instance uniform vec4 haut : source_color = vec4(0.23, 0.53, 0.78, 1.0);
instance uniform vec4 bas : source_color = vec4(0.23, 0.25, 0.29, 1.0);
instance uniform vec4 chaussures : source_color = vec4(0.16, 0.16, 0.16, 1.0);
instance uniform vec4 accessoire : source_color = vec4(0.78, 0.63, 0.25, 1.0);
instance uniform vec4 motif_couleur : source_color = vec4(0.95, 0.94, 0.91, 1.0);
// 1 = manches longues / jambes couvertes, 0 = bras / mollets nus.
instance uniform float manches = 1.0;
instance uniform float jambes = 1.0;
instance uniform float motif = 0.0;

varying vec3 v_loc;

void vertex() {
	v_loc = VERTEX;
}

// Couleur d'un vêtement (haut = true, bas = false) avec son motif.
vec3 tissu(vec3 base, bool est_haut) {
	int m = int(motif + 0.5);
	vec3 p = v_loc;
	vec3 mc = motif_couleur.rgb;
	if (m == 1) {
		// Une bande tous les 31 cm : poitrine, ceinture, bras, cuisses, tibias.
		float b = fract(p.y * 3.2 + 0.81);
		if (b < 0.13) {
			return b < 0.03 || b > 0.10 ? vec3(0.78, 0.8, 0.82) : mc;
		}
	} else if (m == 2 && est_haut) {
		if (fract(p.y * 16.0) < 0.42) {
			return mc;
		}
	} else if (m == 3 && est_haut) {
		float a = step(0.5, fract(p.x * 9.0 + 0.25));
		float b = step(0.5, fract(p.y * 9.0));
		return mix(base, mc, 0.25 * (a + b) + 0.2 * a * b);
	} else if (m == 4) {
		vec3 q = fract(p * vec3(11.0, 11.0, 11.0) + vec3(0.0, floor(p.y * 11.0) * 0.5, 0.0)) - 0.5;
		if (length(q.xy) < 0.22 || length(q.zy) < 0.16) {
			return mc;
		}
	} else if (m == 5 && est_haut) {
		// Gilet sans manches (haute visibilité si la couleur est vive).
		if (p.y > 0.24 && p.y < 0.265) {
			return vec3(0.8, 0.82, 0.85);
		}
		return mc;
	} else if (m == 6 && !est_haut) {
		if (p.z > -0.01) {
			return mc;
		}
	} else if (m == 7) {
		if (p.z > 0.0 && (!est_haut || abs(p.x) < 0.13)) {
			return mc;
		}
	} else if (m == 8 && est_haut) {
		// Veste ouverte : plastron clair en V, cravate sombre.
		float w = 0.012 + max(p.y - 0.18, 0.0) * 0.16;
		if (p.z > 0.02 && abs(p.x) < w && p.y > 0.12) {
			return abs(p.x) < 0.012 && p.y < 0.47 ? base * 0.45 : mc;
		}
	}
	return base;
}

void fragment() {
	ivec2 cell = ivec2(floor(UV * 8.0));
	vec3 c;
	if (COLOR.a < 0.95) {
		// Chapeau ou objet (Tenues.maillage).
		vec3 v = COLOR.rgb;
		if (COLOR.a < 0.2) {
			// Couleur fixe en sRVB → linéaire.
			c = mix(pow((v + 0.055) / 1.055, vec3(2.4)), v / 12.92, lessThan(v, vec3(0.04045)));
		} else if (COLOR.a < 0.5) {
			c = accessoire.rgb * (v.r / 0.7);
		} else {
			c = motif_couleur.rgb * (v.r / 0.7);
		}
		c = min(c, vec3(1.0));
	} else if (cell.y >= 3) {
		c = texture(palette, UV).rgb;
	} else {
		if (cell.x == 0) {
			c = peau.rgb;
		} else if (cell.x == 1) {
			c = cheveux.rgb;
		} else if (cell.x == 2) {
			c = tissu(haut.rgb, true);
		} else if (cell.x == 3) {
			c = tissu(bas.rgb, false);
		} else if (cell.x == 4) {
			c = chaussures.rgb;
		} else if (cell.x == 5) {
			c = accessoire.rgb;
		} else if (cell.x == 6) {
			c = manches > 0.5 ? tissu(haut.rgb, true) : peau.rgb;
		} else {
			c = jambes > 0.5 ? tissu(bas.rgb, false) : peau.rgb;
		}
		if (cell.y == 1) {
			c *= 0.72;
		} else if (cell.y == 2) {
			c = min(c * 1.22, vec3(1.0));
		}
	}
	ALBEDO = c;
	ROUGHNESS = 0.85;
	SPECULAR = 0.3;
	// Liseré de lumière : les silhouettes se détachent mieux du sol vu de haut.
	RIM = 0.15;
	RIM_TINT = 0.6;
}
