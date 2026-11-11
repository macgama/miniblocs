shader_type spatial;
// Eau animée : vagues procédurales, reflets (Fresnel), transparence et écume
// sur les berges. Sert aux rivières, lacs et à la mer.
// Couleur de sommet (donnée, pas une couleur) : r = bord / cascade, g = profondeur.
render_mode blend_mix, depth_draw_opaque, cull_disabled, specular_schlick_ggx;

uniform vec3 deep_color : source_color = vec3(0.07, 0.30, 0.48);
uniform vec3 shallow_color : source_color = vec3(0.26, 0.58, 0.66);
uniform vec3 foam_color : source_color = vec3(0.93, 0.97, 1.0);
// 0 = pas d'écume (la mer, dessinée par un grand plan).
uniform float foam_amount = 1.0;
// >= 0 : profondeur imposée (ignore la couleur des sommets).
uniform float fixed_depth = -1.0;
uniform float wave_scale = 1.0;
uniform float wave_strength = 0.18;
uniform float alpha_shallow = 0.5;
uniform float alpha_deep = 0.86;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Somme de vagues sinusoïdales : renvoie la pente (dérivées en x et z).
vec2 wave_slope(vec2 p, float t) {
	vec2 g = vec2(0.0);
	vec2 dirs[4] = vec2[](vec2(1.0, 0.3), vec2(-0.4, 1.0), vec2(0.7, -0.8), vec2(-1.0, -0.2));
	float freqs[4] = float[](1.3, 2.1, 3.7, 5.9);
	float speeds[4] = float[](1.1, 1.6, 2.3, 3.1);
	for (int i = 0; i < 4; i++) {
		vec2 d = normalize(dirs[i]);
		float f = freqs[i];
		float a = 1.0 / f;
		g += d * f * a * cos(dot(p, d) * f + t * speeds[i]);
	}
	return g;
}

void fragment() {
	vec2 p = world_pos.xz * wave_scale;
	vec2 g = wave_slope(p, TIME) * wave_strength;
	vec3 n = normalize(vec3(-g.x, 1.0, -g.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);

	float depth = fixed_depth >= 0.0 ? fixed_depth : COLOR.g;
	float shore = fixed_depth >= 0.0 ? 0.0 : COLOR.r;
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);

	// Écume qui bouge le long des berges et dans les cascades.
	float ripple = 0.5 + 0.5 * sin(world_pos.x * 3.1 + TIME * 1.7) * sin(world_pos.z * 2.7 - TIME * 1.3);
	float foam = smoothstep(0.45, 0.95, shore * (0.55 + 0.45 * ripple)) * foam_amount;

	vec3 col = mix(shallow_color, deep_color, depth);
	col = mix(col, vec3(0.75, 0.86, 0.95), fresnel * 0.5);
	ALBEDO = mix(col, foam_color, foam);
	ROUGHNESS = mix(0.06, 0.6, foam);
	SPECULAR = 0.7;
	ALPHA = clamp(mix(alpha_shallow, alpha_deep, depth) + fresnel * 0.25 + foam * 0.5, 0.0, 0.97);
}
