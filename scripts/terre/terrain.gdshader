shader_type spatial;
render_mode cull_disabled;
// Terrain en blocs : couleur par case (couleurs de sommets) + quadrillage de 1 m
// sur le dessus des cases, qui s'estompe au loin.

uniform float grid_strength = 0.28;
uniform float grid_fade_start = 35.0;
uniform float grid_fade_end = 140.0;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = NORMAL;
}

void fragment() {
	vec3 col = COLOR.rgb;
	if (world_normal.y > 0.5) {
		vec2 d = abs(fract(world_pos.xz + 0.5) - 0.5) / max(fwidth(world_pos.xz), vec2(1e-4));
		float line = 1.0 - clamp(min(d.x, d.y) - 0.3, 0.0, 1.0);
		float dist = length(world_pos - CAMERA_POSITION_WORLD);
		float fade = 1.0 - smoothstep(grid_fade_start, grid_fade_end, dist);
		col *= 1.0 - line * fade * grid_strength;
	}
	ALBEDO = col;
	ROUGHNESS = 0.95;
}
