shader_type spatial;
// Matériau des bâtiments : couleurs par sommet (comme avant) et fenêtres qui
// s'allument la nuit. Une face dont la couleur est celle d'une vitre (liste
// `window_colors`, fournie par NightWindows : BuildingCatalog.GLASS et les
// vitres de chaque style de la bible), même assombrie, devient une fenêtre.
// Les bandeaux vitrés longs sont découpés en fenêtres de `cell_width` mètres,
// allumées ou éteintes au hasard (toujours les mêmes pour un même bâtiment).

uniform float night = 0.0;
uniform float lit_ratio = 0.6;
uniform vec3 window_colors[32];
uniform int window_count = 0;
uniform float tolerance = 0.025;
uniform vec3 glow_warm : source_color = vec3(1.0, 0.78, 0.45);
uniform vec3 glow_cool : source_color = vec3(0.8, 0.88, 1.0);
uniform float glow_energy = 2.4;
uniform float cell_width = 2.6;
uniform float roughness_value = 0.95;
// Vrai avec le renderer Compatibilité (OpenGL).
uniform bool compat = false;

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
	for (int i = 0; i < window_count; i++) {
		vec3 g = window_colors[i];
		// Même teinte, éventuellement assombrie (côtés des boîtes, variantes).
		float k = dot(c, g) / max(dot(g, g), 0.0001);
		vec3 diff = abs(c - g * k);
		if (k > 0.68 && k < 1.06 && max(max(diff.r, diff.g), diff.b) < tolerance) {
			is_window = 1.0;
			break;
		}
	}
	if (is_window > 0.5) {
		ROUGHNESS = 0.25;
		SPECULAR = 0.7;
		if (night > 0.001) {
			float floor_id = floor(world_pos.y / 3.0);
			// Choix du renderer à l'exécution (uniforme `compat`, réglée par
			// NightWindows) plutôt qu'avec le préprocesseur : CURRENT_RENDERER
			// n'existe qu'à partir de Godot 4.4, et en 4.3 le shader ne
			// compilait pas (bâtiments tout blancs).
			float along;
			float frame;
			vec3 key;
			if (compat) {
				// OpenGL prend le dernier sommet du triangle pour les valeurs « flat » :
				// les deux triangles d'une face ne s'accordent pas. On allume alors
				// par étage et par façade.
				along = 0.0;
				frame = 0.5;
				key = floor(NODE_POSITION_WORLD) + floor(world_normal * 3.0 + 0.5) * 17.0 + vec3(0.0, floor_id * 13.0, 0.0);
			} else {
				// Découpe en fenêtres le long de la face (depuis son coin).
				vec3 off = world_pos - face_corner;
				along = length(off.xz);
				frame = fract(along / cell_width);
				float cell = floor(along / cell_width);
				key = floor(face_corner * 2.0) + vec3(cell * 7.0, floor_id * 13.0, 0.0);
			}
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
