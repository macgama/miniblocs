shader_type spatial;
// Végétation low-poly au vent (herbes hautes, blé, roseaux, fleurs).
// - Les sommets se balancent selon leur hauteur (le pied reste fixe).
// - Des rafales passent en vagues sur le champ (on les voit traverser le blé).
// - Chaque touffe a sa propre nuance (calculée depuis sa position).
// - Lumière traversante (backlight) : contre le soleil, les herbes s'illuminent.
// Les couleurs viennent des sommets (dégradé sombre au pied, clair en haut).
render_mode cull_disabled;

uniform float force = 0.18;
uniform float speed = 1.4;
uniform vec2 wind_dir = vec2(0.8, 0.6);
uniform float gust_scale = 0.045;
uniform float hue_variation = 0.12;
uniform vec3 backlight_color : source_color = vec3(0.55, 0.5, 0.2);
uniform float roughness_value = 0.85;

varying float v_tint;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = max(VERTEX.y, 0.0);
	vec2 dir = normalize(wind_dir);
	float phase = dot(wp.xz, dir) * gust_scale;
	float gust = 0.5 + 0.5 * sin(TIME * speed * 0.6 - phase * 6.2831);
	float sway = sin(TIME * speed * 2.1 + origin.x * 0.7 + origin.z * 0.9) * 0.35;
	float bend = force * h * h * (0.35 + gust + sway);
	vec3 offset = vec3(dir.x, 0.0, dir.y) * bend;
	offset.y = -bend * bend * 0.6;
	VERTEX += inverse(mat3(MODEL_MATRIX)) * offset;
	// Normales adoucies vers le haut : la touffe se lit comme un volume.
	NORMAL = normalize(mix(NORMAL, inverse(mat3(MODEL_MATRIX)) * vec3(0.0, 1.0, 0.0), 0.6));
	v_tint = hash(floor(origin.xz * 3.0)) - 0.5;
}

void fragment() {
	vec3 c = to_linear(COLOR.rgb);
	c *= 1.0 + v_tint * hue_variation * 2.0;
	c.r *= 1.0 + v_tint * hue_variation;
	ALBEDO = c;
	ROUGHNESS = roughness_value;
	SPECULAR = 0.25;
	BACKLIGHT = backlight_color;
}
