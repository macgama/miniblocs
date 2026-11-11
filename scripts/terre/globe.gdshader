shader_type spatial;
// Globe coloré à partir des vraies altitudes.
// La texture « merc » contient les tuiles Terrarium assemblées (projection
// Web Mercator) : l'altitude est encodée dans les couleurs R, G, B.

uniform sampler2D merc : filter_nearest, repeat_disable;
uniform bool has_data = false;

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
		vec3 c = texture(merc, vec2(u, v)).rgb * 255.0;
		h = c.r * 256.0 + c.g + c.b / 256.0 - 32768.0;
		if (h < 0.0) {
			col = mix(vec3(0.06, 0.20, 0.42), vec3(0.22, 0.50, 0.75), smoothstep(-5000.0, -50.0, h));
		} else {
			col = land_color(h);
			// Glaces polaires.
			col = mix(col, vec3(0.93, 0.95, 0.98), smoothstep(radians(66.0), radians(72.0), abs(lat)) * step(1.0, h));
		}
	}
	ALBEDO = col;
	ROUGHNESS = h < 0.0 ? 0.6 : 0.9;
	SPECULAR = h < 0.0 ? 0.3 : 0.15;
}
