shader_type spatial;
// Relief lointain (HorizonTerrain) : couleur par sommet, effacé là où les blocs
// détaillés sont affichés, abaissé selon la courbure de la Terre et fondu dans
// la couleur de l'horizon au bout de la distance d'affichage.
render_mode cull_disabled;

// Un texel par bloc détaillé de 64 m : 1 = bloc affiché, on n'y dessine rien.
uniform sampler2D near_mask : filter_nearest, repeat_disable;
uniform vec2 mask_origin = vec2(0.0);
uniform float mask_cell = 64.0;
uniform float mask_size = 1.0;
uniform vec3 focus = vec3(0.0);
uniform float radius = 10000.0;
uniform vec4 horizon_color : source_color = vec4(0.76, 0.84, 0.92, 1.0);
uniform float earth_radius = 6371000.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 d = world_pos.xz - CAMERA_POSITION_WORLD.xz;
	// Courbure : environ 8 m de moins à 10 km.
	VERTEX.y -= dot(d, d) / (2.0 * earth_radius);
}

void fragment() {
	vec2 t = (world_pos.xz - mask_origin) / mask_cell;
	if (t.x >= 0.0 && t.y >= 0.0 && t.x < mask_size && t.y < mask_size) {
		if (texelFetch(near_mask, ivec2(t), 0).r > 0.5) {
			discard;
		}
	}
	float dist = length(world_pos.xz - focus.xz);
	float f = smoothstep(radius * 0.65, radius, dist);
	// Alpha de sommet 0 = eau (mer, lac) : surface lisse qui reflète le ciel.
	float water = 1.0 - COLOR.a;
	ALBEDO = COLOR.rgb * (1.0 - f);
	EMISSION = horizon_color.rgb * f;
	ROUGHNESS = mix(1.0, 0.3, water);
	SPECULAR = mix(0.2, 0.5, water);
}
