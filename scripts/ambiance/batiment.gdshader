shader_type spatial;
// Matériau des bâtiments : couleurs par sommet (comme avant) et fenêtres qui
// s'allument la nuit. Une face dont la couleur est celle d'une vitre (liste
// `window_colors`, fournie par NightWindows : BuildingCatalog.GLASS et les
// vitres de chaque style de la bible), même assombrie, devient une fenêtre.
//
// Derrière chaque vitre, une pièce (« interior mapping ») : sol, plafond, murs
// et quelques meubles calculés dans le shader, sans aucune géométrie. Les
// pièces font `room_width` m de large, un étage (3 m) de haut et `room_depth` m
// de profondeur. La nuit, une partie des pièces sont allumées (`lit_ratio`).
//
// Par bâtiment (variantes du matériau, voir NightWindows.variant_material et
// BatimentsVie ; le renderer Compatibilité n'a pas d'uniformes d'instance) :
// - usure : façades délavées, coulures, mousse sur les toits, un peu de lierre ;
// - abandon : lierre qui grimpe, fenêtres éteintes ou condamnées ;
// - chantier_h : le bâtiment n'est dessiné que jusqu'à cette hauteur (chantier).

uniform float night = 0.0;
uniform float lit_ratio = 0.6;
uniform vec3 window_colors[32];
uniform int window_count = 0;
uniform float tolerance = 0.025;
uniform vec3 glow_warm : source_color = vec3(1.0, 0.78, 0.45);
uniform vec3 glow_cool : source_color = vec3(0.8, 0.88, 1.0);
uniform float glow_energy = 2.4;
uniform float cell_width = 2.6;
uniform float roughness_value = 0.95;
// Vrai avec le renderer Compatibilité (OpenGL).
uniform bool compat = false;
// Pièces derrière les vitres.
uniform bool interieurs = true;
uniform float room_width = 3.4;
uniform float room_depth = 4.0;
// Lumière du jour dans les pièces (0 = vitres opaques le jour).
uniform float day_interior = 0.32;

uniform float usure = 0.0;
uniform float abandon = 0.0;
uniform float chantier_h = 10000.0;

varying flat vec3 face_corner;
varying vec3 world_pos;
varying vec3 world_normal;

float hash(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(hash(i), hash(i + vec3(1.0, 0.0, 0.0)), f.x);
	float b = mix(hash(i + vec3(0.0, 1.0, 0.0)), hash(i + vec3(1.0, 1.0, 0.0)), f.x);
	float c = mix(hash(i + vec3(0.0, 0.0, 1.0)), hash(i + vec3(1.0, 0.0, 1.0)), f.x);
	float d = mix(hash(i + vec3(0.0, 1.0, 1.0)), hash(i + vec3(1.0, 1.0, 1.0)), f.x);
	return mix(mix(a, b, f.y), mix(c, d, f.y), f.z);
}

vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	face_corner = world_pos;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// Pièce vue à travers une vitre (couleur sRGB). ly : hauteur au-dessus du pied
// du bâtiment. Renvoie la couleur ; key reçoit l'identifiant de la pièce.
vec3 piece(vec3 V, vec3 N, float ly, vec3 wp, vec3 nodep, out vec3 key, out float hit_ceiling) {
	bool nx = abs(N.x) > abs(N.z);
	float vn = dot(V, N);
	float rw = room_width;
	float fh = 3.0;
	float pu = nx ? wp.z : wp.x;
	float du = nx ? V.z : V.x;
	float tu = du > 0.0 ? (ceil(pu / rw) * rw - pu) / max(du, 1e-4) : (floor(pu / rw) * rw - pu) / min(du, -1e-4);
	float ty = V.y > 0.0 ? (ceil(ly / fh) * fh - ly) / max(V.y, 1e-4) : (floor(ly / fh) * fh - ly) / min(V.y, -1e-4);
	float tb = room_depth / max(-vn, 1e-3);
	float t = min(tb, min(tu, ty));
	float ru = floor(pu / rw);
	float rf = floor(ly / fh);
	key = floor(nodep) + vec3(ru * 7.0, rf * 13.0, (nx ? 29.0 : 0.0) + sign(nx ? N.x : N.z) * 3.0);
	float rh = hash(key + 2.0);
	float hu = pu + du * t;
	float hy = ly + V.y * t - rf * fh;
	float across = fract(hu / rw);
	// Teinte des murs de la pièce : tons chauds, quelques bleus et verts.
	vec3 w1 = vec3(0.93, 0.87, 0.76);
	vec3 w2 = vec3(0.80, 0.86, 0.88);
	vec3 w3 = vec3(0.86, 0.80, 0.70);
	vec3 w4 = vec3(0.78, 0.84, 0.74);
	float pick = fract(rh * 5.3);
	vec3 wallc = pick < 0.4 ? w1 : (pick < 0.6 ? w2 : (pick < 0.85 ? w3 : w4));
	vec3 col;
	hit_ceiling = 0.0;
	if (t == tb) {
		// Mur du fond, avec un meuble bas et un cadre.
		col = wallc * 0.88;
		float fw = 0.18 + 0.22 * fract(rh * 13.0);
		if (hy < 0.85 && abs(across - 0.5) < fw) {
			vec3 m1 = vec3(0.45, 0.30, 0.20);
			vec3 m2 = vec3(0.30, 0.38, 0.52);
			vec3 m3 = vec3(0.62, 0.55, 0.45);
			float mp = fract(rh * 17.0);
			col = mp < 0.4 ? m1 : (mp < 0.7 ? m2 : m3);
			if (hy > 0.75) col *= 1.15;
		} else if (hy > 1.45 && hy < 2.0 && abs(across - 0.5 + 0.1 * (fract(rh * 23.0) - 0.5)) < 0.1) {
			col = mix(vec3(0.75, 0.45, 0.30), vec3(0.30, 0.45, 0.60), fract(rh * 31.0));
		} else if (hy > 0.85 && hy < 2.1 && abs(across - 0.15) < 0.08 && fract(rh * 37.0) > 0.5) {
			// Grande plante ou lampadaire dans un coin.
			col = vec3(0.25, 0.42, 0.20);
		}
	} else if (t == ty) {
		if (V.y < 0.0) {
			// Parquet ou carrelage.
			float plank = hash(vec3(floor(hu * 4.0), rf, ru));
			col = fract(rh * 3.0) < 0.65 ? vec3(0.52, 0.36, 0.22) * (0.9 + 0.2 * plank) : vec3(0.72, 0.70, 0.66) * (0.95 + 0.1 * plank);
		} else {
			col = vec3(0.92, 0.90, 0.86);
			hit_ceiling = 1.0 - smoothstep(0.0, 0.9, abs(across - 0.5) * rw);
		}
	} else {
		col = wallc * 0.74;
		// Porte ou étagère sur le mur de côté.
		float depth_side = (t * -vn);
		if (hy < 2.1 && abs(depth_side - room_depth * 0.6) < 0.45 && fract(rh * 41.0) > 0.4) {
			col = vec3(0.55, 0.40, 0.28);
		}
	}
	// Plus sombre au fond de la pièce.
	float depth = clamp(t * -vn / room_depth, 0.0, 1.0);
	col *= mix(1.0, 0.6, depth);
	return col;
}

void fragment() {
	float ly = world_pos.y - NODE_POSITION_WORLD.y;
	if (ly > chantier_h) {
		discard;
	}
	vec3 c = COLOR.rgb;
	ALBEDO = to_linear(c);
	ROUGHNESS = roughness_value;
	if (!FRONT_FACING) {
		// Intérieur d'un bâtiment en chantier (vu par-dessus) : béton brut.
		ALBEDO = vec3(0.16, 0.155, 0.15);
	} else {
		float is_window = 0.0;
		for (int i = 0; i < window_count; i++) {
			vec3 g = window_colors[i];
			// Même teinte, éventuellement assombrie (côtés des boîtes, variantes).
			float k = dot(c, g) / max(dot(g, g), 0.0001);
			vec3 diff = abs(c - g * k);
			if (k > 0.68 && k < 1.06 && max(max(diff.r, diff.g), diff.b) < tolerance) {
				is_window = 1.0;
				break;
			}
		}
		if (is_window > 0.5) {
			ROUGHNESS = 0.18;
			SPECULAR = 0.65;
			vec3 V = normalize(world_pos - CAMERA_POSITION_WORLD);
			vec3 N = world_normal;
			float vn = dot(V, N);
			float floor_id = floor(ly / 3.0);
			vec3 key = floor(NODE_POSITION_WORLD) + floor(N * 3.0 + 0.5) * 17.0 + vec3(0.0, floor_id * 13.0, 0.0);
			vec3 room = vec3(0.0);
			float ceiling_lamp = 0.0;
			bool inside = interieurs && vn < -0.02 && abs(N.y) < 0.5;
			if (inside) {
				room = to_linear(piece(V, N, ly, world_pos, NODE_POSITION_WORLD, key, ceiling_lamp));
			}
			// Fenêtres condamnées des bâtiments abandonnés.
			float boarded = step(hash(key + 3.0), abandon * 0.7 - 0.15);
			float h = hash(key);
			float on = step(h, lit_ratio) * (1.0 - step(0.3, abandon));
			// Petits montants sombres entre deux fenêtres d'un bandeau.
			float mullion = 1.0;
			if (!compat) {
				vec3 off = world_pos - face_corner;
				float along = length(off.xz);
				float frame = fract(along / cell_width);
				mullion = (along > cell_width * 0.9) ? smoothstep(0.0, 0.06, frame) * smoothstep(1.0, 0.94, frame) : 1.0;
			}
			vec3 glow = mix(glow_warm, glow_cool, step(0.82, hash(key + 5.0)));
			float flicker = 0.75 + 0.25 * hash(key + 9.0);
			// Moins de pièce visible quand on regarde la vitre en biais (reflets).
			float fresnel = pow(1.0 - clamp(-vn, 0.0, 1.0), 4.0);
			if (inside) {
				ALBEDO *= 0.45;
				vec3 lit = room * (0.55 + ceiling_lamp * 0.5) * glow;
				vec3 day = room * day_interior * (1.0 - night) * (1.0 - abandon * 0.7);
				vec3 dark = room * 0.025;
				EMISSION = mix(day + dark * night, lit * glow_energy * flicker, night * on) * mullion * (1.0 - fresnel * 0.85);
			} else if (night > 0.001) {
				EMISSION = glow * glow_energy * night * on * mullion * flicker;
				ALBEDO *= mix(1.0, 0.35, night);
			}
			if (boarded > 0.5) {
				float plank = step(0.5, fract(ly * 3.2));
				ALBEDO = to_linear(mix(vec3(0.42, 0.32, 0.22), vec3(0.36, 0.27, 0.18), plank));
				ROUGHNESS = 0.95;
				SPECULAR = 0.2;
				EMISSION = vec3(0.0);
			}
		} else if (usure > 0.001 || abandon > 0.001) {
			// Vieillissement : façades délavées, coulures, mousse, lierre.
			vec3 alb = ALBEDO;
			vec3 wp = world_pos;
			float up = world_normal.y;
			float n1 = vnoise(wp * vec3(0.8, 0.25, 0.8));
			float n2 = vnoise(wp * 1.7 + 7.0);
			float wear = clamp(usure + abandon * 0.6, 0.0, 1.0);
			float lum = dot(alb, vec3(0.3, 0.59, 0.11));
			vec3 washed = mix(alb, vec3(lum) * vec3(1.03, 1.0, 0.94) * 1.1, 0.7);
			alb = mix(alb, washed, wear * (0.3 + 0.5 * n1));
			float foot = 1.0 - smoothstep(0.0, 2.0, ly);
			alb *= 1.0 - wear * (0.3 * foot + 0.18 * smoothstep(0.55, 0.85, n1));
			if (up > 0.25) {
				// Mousse : petites taches, surtout vers le bas des pans.
				float nm = vnoise(wp * 3.1) * 0.6 + n2 * 0.5;
				float m = smoothstep(0.98 - wear * 0.3, 1.06 - wear * 0.28, nm);
				alb = mix(alb, vec3(0.07, 0.10, 0.03), m * 0.7 * smoothstep(0.12, 0.45, wear));
			}
			if (abs(up) < 0.3) {
				// Lierre : monte du sol en traînées verticales, plus haut et plus dense quand le bâtiment est abandonné.
				float cover = abandon * 0.7 + usure * 0.08;
				float reach = 0.8 + abandon * 7.0 * (0.4 + 0.6 * vnoise(vec3(wp.x * 0.25, 0.0, wp.z * 0.25)));
				float tendril = vnoise(vec3(wp.x * 1.3, wp.y * 0.2, wp.z * 1.3));
				float leaf = vnoise(wp * 8.0);
				float ivy = step(1.0 - cover, tendril) * (1.0 - smoothstep(reach - 1.2, reach, ly)) * step(0.22, leaf);
				alb = mix(alb, mix(vec3(0.02, 0.055, 0.014), vec3(0.06, 0.13, 0.035), leaf), ivy);
			}
			alb = mix(alb, alb * vec3(0.82, 0.8, 0.77), abandon * 0.6);
			ALBEDO = alb;
		}
	}
}
