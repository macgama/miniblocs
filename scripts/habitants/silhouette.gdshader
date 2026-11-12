shader_type spatial;
// Personnages low-poly (assets/modeles/personnages, faits dans Blender).
// Chaque face pointe une case de la palette des rôles (palette_roles.png) :
//   colonne : 0 peau, 1 cheveux, 2 haut, 3 bas, 4 chaussures, 5 accessoire,
//             6 manche (haut si manches longues, sinon peau),
//             7 mollet (bas si jambes couvertes, sinon peau)
//   ligne   : 0 normal, 1 ombre, 2 clair, 3 couleur fixe de la texture (yeux)
// Les couleurs sont propres à chaque partie du corps (instance uniform) :
// Silhouettes.colorer() les règle toutes d'un coup.

uniform sampler2D palette : source_color, filter_nearest;

instance uniform vec4 peau : source_color = vec4(0.85, 0.64, 0.49, 1.0);
instance uniform vec4 cheveux : source_color = vec4(0.23, 0.16, 0.12, 1.0);
instance uniform vec4 haut : source_color = vec4(0.23, 0.53, 0.78, 1.0);
instance uniform vec4 bas : source_color = vec4(0.23, 0.25, 0.29, 1.0);
instance uniform vec4 chaussures : source_color = vec4(0.16, 0.16, 0.16, 1.0);
instance uniform vec4 accessoire : source_color = vec4(0.78, 0.63, 0.25, 1.0);
// 1 = manches longues / jambes couvertes, 0 = bras / mollets nus.
instance uniform float manches = 1.0;
instance uniform float jambes = 1.0;

void fragment() {
	ivec2 cell = ivec2(floor(UV * 8.0));
	vec3 c;
	if (cell.y >= 3) {
		c = texture(palette, UV).rgb;
	} else {
		if (cell.x == 0) {
			c = peau.rgb;
		} else if (cell.x == 1) {
			c = cheveux.rgb;
		} else if (cell.x == 2) {
			c = haut.rgb;
		} else if (cell.x == 3) {
			c = bas.rgb;
		} else if (cell.x == 4) {
			c = chaussures.rgb;
		} else if (cell.x == 5) {
			c = accessoire.rgb;
		} else if (cell.x == 6) {
			c = mix(peau.rgb, haut.rgb, manches);
		} else {
			c = mix(peau.rgb, bas.rgb, jambes);
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
}
