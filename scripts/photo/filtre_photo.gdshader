shader_type canvas_item;
// Filtres du mode photo, posés par-dessus l'image du jeu (ColorRect plein écran).
// filtre : 0 aucun, 1 noir et blanc, 2 sépia, 3 vintage, 4 chaud, 5 froid,
// 6 vif, 7 délavé, 8 nuit, 9 maquette (tilt-shift), 10 carte postale, 11 néon.

uniform sampler2D ecran : hint_screen_texture, filter_linear_mipmap;
uniform int filtre = 0;
uniform float force : hint_range(0.0, 1.0) = 1.0;
uniform float luminosite : hint_range(-0.5, 0.5) = 0.0;
uniform float contraste : hint_range(0.5, 1.5) = 1.0;
uniform float saturation : hint_range(0.0, 2.0) = 1.0;
uniform float vignette : hint_range(0.0, 1.0) = 0.0;
uniform float grain : hint_range(0.0, 1.0) = 0.0;
uniform float graine = 0.0;

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233)) + graine) * 43758.5453);
}

vec3 sature(vec3 c, float s) {
	return mix(vec3(luma(c)), c, s);
}

vec3 appliquer(vec3 c, vec2 uv) {
	if (filtre == 1) {
		float l = luma(c);
		return vec3(smoothstep(0.02, 0.98, l));
	} else if (filtre == 2) {
		float l = luma(c);
		return vec3(l * 1.07 + 0.05, l * 0.88 + 0.03, l * 0.66);
	} else if (filtre == 3) {
		vec3 v = sature(c, 0.65);
		v = v * vec3(1.06, 0.98, 0.82) + vec3(0.06, 0.04, 0.02);
		return mix(vec3(0.5), v, 0.88);
	} else if (filtre == 4) {
		return c * vec3(1.10, 1.0, 0.84) + vec3(0.03, 0.01, 0.0);
	} else if (filtre == 5) {
		return c * vec3(0.88, 1.0, 1.14);
	} else if (filtre == 6) {
		vec3 v = sature(c, 1.45);
		return (v - 0.5) * 1.15 + 0.5;
	} else if (filtre == 7) {
		vec3 v = sature(c, 0.55);
		return mix(vec3(0.62, 0.62, 0.66), v, 0.75);
	} else if (filtre == 8) {
		float l = luma(c);
		return vec3(l * 0.45, l * 0.7, l * 1.15) * 0.85;
	} else if (filtre == 9) {
		// Maquette : flou en haut et en bas, couleurs plus vives (effet miniature).
		float d = abs(uv.y - 0.55) * 2.0;
		float flou = smoothstep(0.18, 0.75, d) * 5.0;
		vec3 v = textureLod(ecran, uv, flou).rgb;
		v = sature(v, 1.5);
		return (v - 0.5) * 1.12 + 0.5;
	} else if (filtre == 10) {
		vec3 v = sature(c, 1.25) * vec3(1.05, 1.0, 0.95);
		return v + vec3(0.04, 0.03, 0.0);
	} else if (filtre == 11) {
		vec3 v = sature(c, 1.8);
		return v * vec3(1.1, 0.85, 1.25);
	}
	return c;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 base = textureLod(ecran, uv, 0.0).rgb;
	vec3 c = mix(base, appliquer(base, uv), force);
	c = sature(c, saturation);
	c = (c - 0.5) * contraste + 0.5 + luminosite;
	if (vignette > 0.0) {
		vec2 p = uv - 0.5;
		float v = smoothstep(0.85, 0.25, length(p * vec2(1.0, 0.8)) * (1.0 + vignette));
		c *= mix(1.0, v, vignette);
	}
	if (grain > 0.0) {
		c += (hash(uv * 1000.0) - 0.5) * 0.18 * grain;
	}
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
