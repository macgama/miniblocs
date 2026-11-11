shader_type sky;
// Ciel du cycle jour/nuit : dégradé piloté par la hauteur du Soleil, halo du
// Soleil, disque du Soleil, Lune avec sa vraie phase, étoiles qui tournent
// autour du pôle céleste. Les couleurs sont fournies par DayNight.

uniform vec3 zenith_color : source_color = vec3(0.42, 0.64, 0.92);
uniform vec3 horizon_color : source_color = vec3(0.78, 0.86, 0.93);
uniform vec3 ground_color : source_color = vec3(0.35, 0.38, 0.42);
uniform vec3 glow_color : source_color = vec3(1.0, 0.6, 0.35);
uniform float glow_strength = 0.0;
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 sun_color : source_color = vec3(1.0, 0.95, 0.85);
uniform float sun_visible = 1.0;
uniform vec3 moon_dir = vec3(0.0, -1.0, 0.0);
uniform float moon_visible = 0.0;
uniform float stars = 0.0;
// Rotation du ciel étoilé (repère local -> repère des étoiles).
uniform mat3 star_basis = mat3(1.0);

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

vec3 star_field(vec3 d) {
	vec3 s = star_basis * d;
	vec3 p = s * 220.0;
	vec3 cell = floor(p);
	float h = hash3(cell);
	if (h < 0.985) {
		return vec3(0.0);
	}
	vec3 center = cell + vec3(hash3(cell + 7.1), hash3(cell + 3.7), hash3(cell + 1.3));
	float dist = length(p - center);
	float b = smoothstep(0.32, 0.0, dist) * (h - 0.985) / 0.015;
	float tint = hash3(cell + 11.0);
	vec3 col = mix(vec3(0.75, 0.82, 1.0), vec3(1.0, 0.9, 0.75), tint);
	return col * b * 1.6;
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float h = d.y;
	vec3 col;
	if (h >= 0.0) {
		col = mix(horizon_color, zenith_color, pow(clamp(h, 0.0, 1.0), 0.55));
	} else {
		col = mix(horizon_color, ground_color, clamp(-h * 6.0, 0.0, 1.0));
	}

	// Halo du lever / coucher : plus fort vers le Soleil et près de l'horizon.
	vec3 sd = normalize(sun_dir);
	float toward = max(dot(normalize(vec3(d.x, 0.0, d.z) + vec3(0.0001)), normalize(vec3(sd.x, 0.0, sd.z) + vec3(0.0001))), 0.0);
	float band = exp(-abs(h) * 7.0);
	col += glow_color * glow_strength * band * pow(toward, 3.0);
	float mie = max(dot(d, sd), 0.0);
	col += sun_color * sun_visible * (pow(mie, 60.0) * 0.6 + pow(mie, 8.0) * 0.12);

	// Disque du Soleil.
	float disk = smoothstep(0.99985, 0.99993, dot(d, sd));
	col += sun_color * disk * 18.0 * sun_visible * step(-0.02, h);

	if (AT_CUBEMAP_PASS == false) {
		// Étoiles (pas dans la lumière ambiante, seulement à l'écran).
		col += star_field(d) * stars * smoothstep(-0.02, 0.15, h);
	}

	// Lune : disque éclairé du côté du Soleil (phase réelle).
	vec3 md = normalize(moon_dir);
	float r = 0.0095; // rayon apparent un peu exagéré (≈ 0,55°)
	float cm = dot(d, md);
	if (moon_visible > 0.0 && cm > cos(r * 1.6)) {
		vec3 q = (d - md * cm) / r;
		float q2 = dot(q, q);
		if (q2 < 1.0) {
			vec3 n = q - md * sqrt(1.0 - q2);
			float lit = smoothstep(-0.05, 0.12, dot(n, sd));
			float spots = 0.85 + 0.15 * hash3(floor((q + 2.0) * 4.0));
			vec3 moon = vec3(0.95, 0.95, 0.88) * spots * (0.04 + lit * 1.6);
			float edge = smoothstep(1.0, 0.9, q2);
			col = mix(col, moon, edge * moon_visible);
		}
		// Halo léger.
		col += vec3(0.5, 0.55, 0.65) * pow(max(cm, 0.0), 900.0) * 0.25 * moon_visible;
	}
	COLOR = col;
}
