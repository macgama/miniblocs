shader_type spatial;
// Globe coloré à partir des vraies altitudes.
// La texture « merc » contient les tuiles Terrarium assemblées (projection
// Web Mercator) : l'altitude est encodée dans les couleurs R, G, B.

uniform sampler2D merc : filter_nearest, repeat_disable;
uniform bool has_data = false;
// Carte des biomes (ESA WorldCover), projection équirectangulaire, codes 0-100.
uniform sampler2D biomes : filter_nearest, repeat_enable;
uniform bool has_biomes = false;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

vec3 land_color(float h) {
	vec3 low = vec3(0.36, 0.60, 0.30);
	vec3 mid = vec3(0.70, 0.66, 0.42);
	vec3 high = vec3(0.55, 0.50, 0.46);
	vec3 snow = vec3(0.95, 0.96, 0.98);
	vec3 c = mix(low, mid, smoothstep(150.0, 1200.0, h));
	c = mix(c, high, smoothstep(1200.0, 2800.0, h));
	return mix(c, snow, smoothstep(3200.0, 4500.0, h));
}

vec3 biome_color(float code, float h, float lat) {
	if (code < 5.0) {
		// Pas de donnée sur la terre ferme (ex. Antarctique) : glace près des pôles.
		return abs(lat) > radians(60.0) ? vec3(0.93, 0.95, 0.98) : land_color(h);
	}
	if (code < 15.0) return vec3(0.17, 0.42, 0.17);   // forêt
	if (code < 25.0) return vec3(0.55, 0.60, 0.34);   // broussailles
	if (code < 35.0) return vec3(0.55, 0.74, 0.36);   // prairie
	if (code < 45.0) return vec3(0.84, 0.77, 0.40);   // champs
	if (code < 55.0) return vec3(0.55, 0.74, 0.36);   // bâti -> terre vierge (prairie)
	if (code < 65.0) return h > 1500.0 ? vec3(0.58, 0.53, 0.48) : vec3(0.90, 0.81, 0.58); // roche / désert
	if (code < 75.0) return vec3(0.95, 0.97, 1.0);    // glacier
	if (code < 85.0) return vec3(0.30, 0.60, 0.86);   // lacs et rivières
	if (code < 92.0) return vec3(0.36, 0.60, 0.50);   // marais
	if (code < 97.0) return vec3(0.18, 0.47, 0.35);   // mangrove
	return vec3(0.64, 0.64, 0.52);                    // toundra
}

float merc_height(vec2 uv) {
	vec3 c = texture(merc, uv).rgb * 255.0;
	return c.r * 256.0 + c.g + c.b / 256.0 - 32768.0;
}

void fragment() {
	vec3 n = normalize(local_pos);
	float lat = asin(clamp(n.y, -1.0, 1.0));
	float lon = atan(n.x, n.z);
	vec3 col;
	float h = 0.0;
	if (abs(lat) > radians(85.0)) {
		h = 1000.0;
		col = vec3(0.93, 0.95, 0.98);
	} else if (!has_data) {
		col = vec3(0.25, 0.45, 0.70);
	} else {
		float u = (lon + PI) / (2.0 * PI);
		float v = (1.0 - log(tan(lat) + 1.0 / cos(lat)) / PI) / 2.0;
		h = merc_height(vec2(u, v));
		float code = has_biomes ? texture(biomes, vec2(u, 0.5 - lat / PI)).r * 255.0 : 0.0;
		bool water = (h < 0.0 && (code < 5.0 || (code > 75.0 && code < 85.0)));
		if (water) {
			col = mix(vec3(0.06, 0.20, 0.42), vec3(0.22, 0.50, 0.75), smoothstep(-5000.0, -50.0, h));
		} else {
			h = max(h, 0.0);
			if (has_biomes) {
				col = biome_color(code, h, lat);
				// Les hauts sommets restent enneigés, les montagnes tirent vers la roche.
				col = mix(col, vec3(0.58, 0.54, 0.50), smoothstep(2200.0, 3600.0, h) * 0.6);
				col = mix(col, vec3(0.95, 0.96, 0.98), smoothstep(4200.0, 5200.0, h));
			} else {
				col = land_color(h);
				col = mix(col, vec3(0.93, 0.95, 0.98), smoothstep(radians(66.0), radians(72.0), abs(lat)) * step(1.0, h));
			}
			// Ombrage du relief : fait ressortir les chaînes de montagnes.
			vec2 px = vec2(1.0 / 2048.0, 0.0);
			float hx = merc_height(vec2(u, v) + px.xy) - merc_height(vec2(u, v) - px.xy);
			float hy = merc_height(vec2(u, v) + px.yx) - merc_height(vec2(u, v) - px.yx);
			col *= clamp(1.0 + (hy - hx) / 2500.0, 0.75, 1.2);
		}
	}
	ALBEDO = col;
	ROUGHNESS = h < 0.0 ? 0.6 : 0.9;
	SPECULAR = h < 0.0 ? 0.3 : 0.15;
}
