shader_type spatial;
render_mode cull_disabled;
// Plantes low-poly (arbres, herbes, cultures) posées en MultiMesh.
// Couleur : case de la palette commune (UV) × teinte de l'instance.
// INSTANCE_CUSTOM : rgb = teinte (autour de 1), a = coefficient du vent
// (balancement = a × hauteur², 0 pour les rochers).

uniform sampler2D palette : source_color, filter_nearest;
uniform float vent = 1.0;

varying vec3 teinte;

void vertex() {
	teinte = INSTANCE_CUSTOM.rgb;
	float h = max(VERTEX.y, 0.0);
	vec2 o = MODEL_MATRIX[3].xz;
	float phase = dot(o, vec2(0.071, 0.113));
	float s = sin(TIME * 1.3 + phase) * 0.7 + sin(TIME * 2.9 + phase * 1.7) * 0.3;
	float d = INSTANCE_CUSTOM.a * h * h * vent;
	// Rafales venant de l'ouest, un peu de travers.
	VERTEX.x += d * (0.6 + s);
	VERTEX.z += d * 0.4 * sin(TIME * 1.7 + phase * 0.6);
}

void fragment() {
	vec3 c = texture(palette, UV).rgb * teinte;
	ALBEDO = c;
	ROUGHNESS = 0.9;
	// Un peu de lumière qui traverse les feuilles fines.
	BACKLIGHT = c * 0.25;
}
