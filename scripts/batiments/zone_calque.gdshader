shader_type spatial;
// Calque coloré des zones (ZoneSystem) : posé sur le dessus et les flancs des
// cases. Chaque sommet est avancé vers la caméra (un peu plus au loin) pour ne
// jamais disparaître dans le sol ni scintiller sur les pentes, tout en restant
// caché derrière une vraie colline. Les bords des cases de 1 m sont soulignés.
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, skip_vertex_transform, shadows_disabled, fog_disabled;

uniform vec4 couleur : source_color = vec4(0.35, 0.85, 0.35, 0.4);
// Avance vers la caméra (m) et part qui grandit avec la distance.
uniform float avance = 0.25;
uniform float avance_loin = 0.004;
// Renforcement des bords de case (0 = aucun).
uniform float bords = 0.22;

varying vec3 monde;

void vertex() {
	monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float d = length(VERTEX);
	VERTEX -= VERTEX / max(d, 0.001) * min(avance + d * avance_loin, d * 0.5);
	NORMAL = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// Distance au bord de case le plus proche, en pixels d'écran.
	vec2 f = abs(fract(monde.xz + 0.5) - 0.5);
	vec2 w = fwidth(monde.xz);
	vec2 g = 1.0 - smoothstep(vec2(0.0), w * 1.5, f);
	float trait = max(g.x, g.y);
	ALBEDO = mix(couleur.rgb, couleur.rgb * 0.55, trait * bords * 2.0);
	ALPHA = clamp(couleur.a + trait * bords, 0.0, 1.0);
}
