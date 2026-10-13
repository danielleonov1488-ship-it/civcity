// Земля поля боя Легиона (legion_field.gd): как земля города — трава пятнами четырёх оттенков, у каждого кубика 12,5 см
// свой тон, редкие сухие травинки; вдоль поля — утоптанная тропа. Цвета — от области похода (лес, холмы, болото, пески…):
// у болота — лужи грязи, у Аида — трещины с жаром, у Лабиринта — каменные плиты.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 g0 : source_color = vec3(0.33, 0.39, 0.16);
uniform vec3 g1 : source_color = vec3(0.37, 0.43, 0.17);
uniform vec3 g2 : source_color = vec3(0.42, 0.47, 0.2);
uniform vec3 g3 : source_color = vec3(0.46, 0.5, 0.22);
uniform vec3 path_col : source_color = vec3(0.6, 0.45, 0.26);
uniform vec3 dirt_col : source_color = vec3(0.36, 0.27, 0.16);  // склоны и кромка тропы
uniform float path_half = 2.6;          // полуширина тропы вдоль поля (м)
uniform float path_soft = 0.9;
uniform float patch_k = 0.34;           // насколько заметны крупные пятна
uniform float stubble = 0.16;           // «щетина» — тон каждого кубика
uniform float mud = 0.0;                // болото: лужи грязи
uniform vec3 mud_col : source_color = vec3(0.27, 0.24, 0.16);
uniform float cracks = 0.0;             // Аид: трещины с жаром
uniform vec3 crack_col : source_color = vec3(1.0, 0.42, 0.12);
uniform float tiles = 0.0;              // Лабиринт: каменные плиты на тропе
uniform vec3 tile_col : source_color = vec3(0.72, 0.66, 0.56);
uniform float dunes = 0.0;              // пески: рябь

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// хеш без sin: на больших координатах sin теряет точность и шум становится «ступеньками»
float h21(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
float h31(vec3 p) { p = fract(p * 0.1031); p += dot(p, p.zyx + 31.32); return fract((p.x + p.y) * p.z); }
float vn(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec3 cube = floor(wpos * 16.0 - wnrm * 0.5);
	float r = h31(cube);
	// трава: четыре оттенка по шуму клеток 25 см (как Land.tint), крупные пятна светлее и темнее
	vec2 q = (floor(wpos.xz * 8.0) + 0.5) * 0.0225;
	float n = (vn(q) * 4.0 + vn(q * 2.0 + vec2(17.3, 5.1)) * 2.0 + vn(q * 4.0 + vec2(3.7, 11.9))) / 7.0;
	vec3 c = n < 0.38 ? g0 : (n < 0.5 ? g1 : (n < 0.62 ? g2 : g3));
	float big = vn(wpos.xz * 0.06) * 0.55 + vn(wpos.xz * 0.21) * 0.45;
	c *= 1.0 - patch_k * 0.5 + patch_k * big;
	c *= 1.0 - stubble * 0.5 + stubble * r;
	float s = h31(cube + 17.0);
	if (s > 0.99) c = mix(c, vec3(0.74, 0.68, 0.42), 0.3);
	if (s < 0.025) c *= 0.75;
	float fl = h31(cube + 41.0);
	if (fl > 0.9982 && mud < 0.5 && cracks < 0.5) c = fl > 0.9994 ? vec3(0.9, 0.86, 0.74) : vec3(0.8, 0.4, 0.46);
	if (dunes > 0.0) {
		float rip = 0.5 + 0.5 * sin(wpos.x * 2.4 + wpos.z * 0.9 + vn(wpos.xz * 0.3) * 4.0);
		c *= 1.0 - dunes * 0.12 * rip;
	}
	// утоптанная тропа вдоль поля: края неровные
	float wob = vn(wpos.xz * 0.45) - 0.5 + (vn(wpos.xz * 2.3) - 0.5) * 0.35;
	float pz = abs(wpos.z + wob * 1.3);
	float w_path = 1.0 - smoothstep(path_half - path_soft, path_half + path_soft * 0.4, pz);
	w_path *= smoothstep(-40.0, -30.0, wpos.x) * (1.0 - smoothstep(34.0, 44.0, wpos.x));
	if (w_path > 0.0) {
		float pn = vn(wpos.xz * 1.3) * 0.6 + vn(wpos.xz * 5.0) * 0.4;
		vec3 p = path_col * (0.86 + 0.22 * pn);
		if (h31(cube + 5.0) > 0.93) p *= 0.82;
		p *= 0.94 + 0.08 * r;
		if (tiles > 0.0) {
			// каменные плиты: неровные квадраты с тёмными швами
			vec2 cell = floor(wpos.xz / vec2(1.2, 1.0) + vec2(floor(wpos.z) * 0.5, 0.0));
			vec2 f = fract(wpos.xz / vec2(1.2, 1.0) + vec2(floor(wpos.z) * 0.5, 0.0));
			float seam = 1.0 - smoothstep(0.0, 0.05, min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y)));
			vec3 t = tile_col * (0.8 + 0.2 * h21(cell * 1.7)) * (0.95 + 0.08 * r);
			t *= 1.0 - 0.35 * seam;
			float broken = step(0.86, h21(cell * 3.1 + 7.0));
			p = mix(t, p, broken * 0.8 * tiles);
		}
		c = mix(c, p, w_path * 0.96);
	}
	// склоны — земля
	float slope = 1.0 - smoothstep(0.72, 0.9, wnrm.y);
	c = mix(c, dirt_col * (0.88 + 0.2 * r), slope);
	if (mud > 0.0) {
		// болото: тёмные лужи грязи пятнами, с блеском
		float m = vn(wpos.xz * 0.35) * 0.65 + vn(wpos.xz * 1.1 + 4.0) * 0.35;
		float wm = smoothstep(0.63, 0.7, m) * mud * (0.35 + 0.65 * smoothstep(2.5, 5.0, abs(wpos.z)));
		c = mix(c, mud_col * (0.95 + 0.15 * r), wm * 0.85);
		ROUGHNESS = mix(0.95, 0.35, wm);
	} else {
		ROUGHNESS = 0.95;
	}
	if (cracks > 0.0) {
		// Аид: сеть трещин, в них светится жар (пульсирует)
		vec2 p2 = wpos.xz * 0.55;
		float a = abs(vn(p2) - 0.5) + abs(vn(p2 * 2.1 + 3.3) - 0.5) * 0.5;
		float line = 1.0 - smoothstep(0.015, 0.05, a);
		line *= smoothstep(1.2, 3.5, abs(wpos.z)) * 0.6 + 0.4;
		float pulse = 0.75 + 0.25 * sin(TIME * 1.7 + wpos.x * 0.4);
		c = mix(c, c * 0.5, line * cracks);
		EMISSION = crack_col * line * cracks * 2.2 * pulse;
	}
	ALBEDO = c;
	SPECULAR = 0.3;
}
