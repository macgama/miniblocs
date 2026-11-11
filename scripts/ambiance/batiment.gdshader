shader_type spatial;
// Matériau des bâtiments : couleurs par sommet (comme avant) et fenêtres qui
// s'allument la nuit. Une face dont la couleur est celle des vitres
// (BuildingCatalog.GLASS, ou une couleur proche) devient une fenêtre.
// Les bandeaux vitrés longs sont découpés en fenêtres de `cell_width` mètres,
// allumées ou éteintes au hasard (toujours les mêmes pour un même bâtiment).

uniform float night = 0.0;
uniform float lit_ratio = 0.6;
uniform vec3 window_color = vec3(0.2, 0.286, 0.369);
uniform vec3 window_color_2 = vec3(0.114, 0.176, 0.235);
// Façades entièrement vitrées (immeuble de bureaux).
uniform vec3 window_color_3 = vec3(0.561, 0.722, 0.847);
uniform float tolerance = 0.06;
uniform vec3 glow_warm : source_color = vec3(1.0, 0.78, 0.45);
uniform vec3 glow_cool : source_color = vec3(0.8, 0.88, 1.0);
uniform float glow_energy = 2.4;
uniform float cell_width = 2.6;
uniform float roughness_value = 0.95;

varying flat vec3 face_corner;
varying vec3 world_pos;
varying vec3 world_normal;

float hash(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	face_corner = world_pos;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 c = COLOR.rgb;
	ALBEDO = to_linear(c);
	ROUGHNESS = roughness_value;
	float is_window = 0.0;
	float d1 = max(max(abs(c.r - window_color.r), abs(c.g - window_color.g)), abs(c.b - window_color.b));
	float d2 = max(max(abs(c.r - window_color_2.r), abs(c.g - window_color_2.g)), abs(c.b - window_color_2.b));
	float d3 = max(max(abs(c.r - window_color_3.r), abs(c.g - window_color_3.g)), abs(c.b - window_color_3.b));
	if (min(min(d1, d2), d3) < tolerance) {
		is_window = 1.0;
	}
	if (is_window > 0.5) {
		ROUGHNESS = 0.25;
		SPECULAR = 0.7;
		if (night > 0.001) {
			float floor_id = floor(world_pos.y / 3.0);
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
			// OpenGL prend le dernier sommet du triangle pour les valeurs « flat » :
			// les deux triangles d'une face ne s'accordent pas. On allume alors
			// par étage et par façade.
			float along = 0.0;
			float frame = 0.5;
			vec3 key = floor(NODE_POSITION_WORLD) + floor(world_normal * 3.0 + 0.5) * 17.0 + vec3(0.0, floor_id * 13.0, 0.0);
#else
			// Découpe en fenêtres le long de la face (depuis son coin).
			vec3 off = world_pos - face_corner;
			float along = length(off.xz);
			float frame = fract(along / cell_width);
			float cell = floor(along / cell_width);
			vec3 key = floor(face_corner * 2.0) + vec3(cell * 7.0, floor_id * 13.0, 0.0);
#endif
			float h = hash(key);
			float on = step(h, lit_ratio);
			// Petits montants sombres entre deux fenêtres d'un bandeau.
			float mullion = (along > cell_width * 0.9) ? smoothstep(0.0, 0.06, frame) * smoothstep(1.0, 0.94, frame) : 1.0;
			vec3 glow = mix(glow_warm, glow_cool, step(0.82, hash(key + 5.0)));
			float flicker = 0.75 + 0.25 * hash(key + 9.0);
			EMISSION = glow * glow_energy * night * on * mullion * flicker;
			ALBEDO *= mix(1.0, 0.35, night);
		}
	}
}
