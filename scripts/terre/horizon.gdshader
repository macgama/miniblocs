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
// Neige commune avec le terrain détaillé. L'exposition (adret, ubac) ne joue
// qu'au-delà de neige_expo_debut (m) : les blocs détaillés n'ont pas de pente
// lisse, on évite ainsi un raccord visible à leur bord.
#include "res://scripts/terre/neige.gdshaderinc"
uniform float neige_expo_debut = 500.0;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = NORMAL;
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
	vec3 col = COLOR.rgb;
	if (water < 0.5 && (neige > 0.0 || neige_iso0 < 9000.0)) {
		float expo = smoothstep(neige_expo_debut, neige_expo_debut + 800.0, dist);
		float v = neige_locale(world_pos.y, normalize(world_normal), expo);
		if (v > 0.0) {
			col = mix(col, NEIGE_COULEUR, neige_couvre(world_pos.xz, v));
		}
	}
	ALBEDO = col * (1.0 - f);
	EMISSION = horizon_color.rgb * f;
	ROUGHNESS = mix(1.0, 0.3, water);
	SPECULAR = mix(0.2, 0.5, water);
}
