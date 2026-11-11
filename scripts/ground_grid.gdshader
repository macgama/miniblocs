shader_type spatial;
// Sol herbeux avec un quadrillage discret (1 case = 1 unité).

uniform vec4 grass_color : source_color = vec4(0.36, 0.58, 0.28, 1.0);
uniform vec4 grass_color_2 : source_color = vec4(0.33, 0.54, 0.26, 1.0);
uniform vec4 line_color : source_color = vec4(0.24, 0.40, 0.20, 1.0);
uniform float line_width = 0.03;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 cell = floor(world_pos.xz);
	// Damier très léger pour donner du relief visuel au sol.
	float checker = mod(cell.x + cell.y, 2.0);
	vec3 base = mix(grass_color.rgb, grass_color_2.rgb, checker);
	vec2 f = fract(world_pos.xz);
	vec2 d = min(f, 1.0 - f);
	float line = 1.0 - smoothstep(0.0, line_width, min(d.x, d.y));
	ALBEDO = mix(base, line_color.rgb, line * 0.6);
	ROUGHNESS = 1.0;
}
