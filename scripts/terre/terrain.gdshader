shader_type spatial;
render_mode cull_disabled;
// Terrain en blocs : couleur par case (couleurs de sommets) + texture du sol
// (Sols.gd) + quadrillage de 1 m sur le dessus des cases, qui s'estompe au loin.
// UV.x = couche de la texture du sol, UV.y = 1 si les rangs du champ sont tournés.

uniform float grid_strength = 0.28;
uniform float grid_fade_start = 35.0;
uniform float grid_fade_end = 140.0;
uniform sampler2DArray sols : filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool avec_textures = false;
uniform int premiere_couleur = 11;
// Taille d'une tuile de texture (m).
uniform float tuile = 4.0;
// Force des textures « détail » (sol naturel), réduite au loin.
uniform float detail_force = 1.0;
uniform float detail_loin = 450.0;

varying vec3 world_pos;
varying vec3 world_normal;
varying vec2 couche;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = NORMAL;
	couche = UV;
}

vec3 srgb_vers_lineaire(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void fragment() {
	vec3 col = COLOR.rgb;
	float dist = length(world_pos - CAMERA_POSITION_WORLD);
	if (avec_textures) {
		int n = int(couche.x + 0.5);
		vec2 p;
		bool dessus = world_normal.y > 0.5;
		if (dessus) {
			p = couche.y > 0.5 ? world_pos.zx : world_pos.xz;
		} else if (abs(world_normal.x) > 0.5) {
			p = vec2(world_pos.z, -world_pos.y);
		} else {
			p = vec2(world_pos.x, -world_pos.y);
		}
		vec3 t = texture(sols, vec3(p / tuile, float(n))).rgb;
		if (n >= premiere_couleur && dessus) {
			col = srgb_vers_lineaire(t);
		} else {
			float f = detail_force * (1.0 - 0.6 * smoothstep(60.0, detail_loin, dist));
			col *= mix(vec3(1.0), t * 2.0, f);
		}
	}
	if (world_normal.y > 0.5) {
		vec2 d = abs(fract(world_pos.xz + 0.5) - 0.5) / max(fwidth(world_pos.xz), vec2(1e-4));
		float line = 1.0 - clamp(min(d.x, d.y) - 0.3, 0.0, 1.0);
		float fade = 1.0 - smoothstep(grid_fade_start, grid_fade_end, dist);
		col *= 1.0 - line * fade * grid_strength;
	}
	ALBEDO = col;
	ROUGHNESS = 0.95;
}
