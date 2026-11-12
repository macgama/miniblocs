shader_type spatial;
// Fumée de cheminée low-poly : quelques bouffées (petits volumes à facettes)
// qui montent, grossissent, dérivent avec le vent et s'effacent. Tout est
// calculé ici : un seul petit maillage partagé, aucune particule.
// UV.x = numéro de la bouffée / nombre de bouffées.
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform float speed = 0.12;
uniform float rise = 5.0;
uniform vec2 wind = vec2(1.6, 0.7);
uniform vec3 smoke_color : source_color = vec3(0.86, 0.86, 0.84);
uniform float opacity = 0.55;

varying float v_life;

float hash1(float n) {
	return fract(sin(n) * 43758.5453);
}

void vertex() {
	vec3 origin = NODE_POSITION_WORLD;
	float seed = hash1(dot(floor(origin.xz), vec2(12.9898, 78.233)));
	float t = fract(TIME * speed + UV.x + seed);
	v_life = t;
	float s = 0.35 + t * 1.3;
	vec3 drift = vec3(wind.x, 0.0, wind.y) * t * t * 1.4 + vec3(0.0, rise * t, 0.0);
	drift.x += sin(TIME * 0.7 + UV.x * 6.0) * 0.15;
	VERTEX = VERTEX * s + inverse(mat3(MODEL_MATRIX)) * drift;
}

void fragment() {
	ALBEDO = smoke_color;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	float fade_in = smoothstep(0.0, 0.08, v_life);
	ALPHA = opacity * fade_in * (1.0 - v_life);
}
