shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never;
// Halo bleuté au bord du globe.

uniform vec3 glow_color = vec3(0.35, 0.6, 1.0);

void fragment() {
	float f = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 4.0);
	ALBEDO = glow_color * f;
}
