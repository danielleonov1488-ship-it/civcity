// Земля игры: трава пятнами разных оттенков (у каждого кубика 12,5 см — свой тон), утоптанные тропы,
// дороги и площади из плитки Synty (как в промо Ancient Empire), песок, скалы со слоями.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D tile_road : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tile_plaza_a : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tile_plaza_b : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tile_plaza_c : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tile_plaza_d : source_color, filter_linear_mipmap, repeat_enable;

varying vec3 wpos;
varying vec3 wnrm;
varying float kind;
varying float top_y;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	kind = UV.x;
	top_y = UV.y;
}

float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float h31(vec3 p) { p = fract(p * 0.1031); p += dot(p, p.zyx + 31.32); return fract((p.x + p.y) * p.z); }
float vn(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec3 base = COLOR.rgb;               // вершинный цвет: оттенок клетки (у чужой земли приглушён)
	vec3 c = base;
	vec3 an = abs(wnrm);
	float k = floor(kind + 0.5);
	bool top = an.y > 0.5;
	vec3 cube = floor(wpos * 8.0 - wnrm * 0.5);
	float r = h31(cube);
	float rough = 0.95;
	// насколько клетка «чужая» (вершинный цвет потускнел) — переносим на текстуры тоже
	if (top && k == 4.0) {
		// дорога: светлая каменная плитка
		vec3 t = texture(tile_road, wpos.xz / 2.5).rgb;
		c = t * (base / vec3(0.788, 0.733, 0.627)) * (0.92 + 0.12 * vn(wpos.xz * 0.6));
		c *= 0.9 + 0.12 * r;
		rough = 0.85;
	} else if (top && k == 5.0) {
		// площадь: узорная плитка, у каждого квадрата 2,5 м — свой рисунок
		vec2 cell = floor(wpos.xz / 2.5);
		float pick = h21(cell * 1.37 + 3.1);
		vec2 uv = wpos.xz / 2.5;
		vec3 t;
		if (pick < 0.4) t = texture(tile_plaza_a, uv).rgb;
		else if (pick < 0.75) t = texture(tile_plaza_b, uv).rgb;
		else if (pick < 0.9) t = texture(tile_plaza_c, uv).rgb;
		else t = texture(tile_plaza_d, uv).rgb;
		c = t * (base / vec3(0.847, 0.788, 0.69)) * (0.94 + 0.1 * vn(wpos.xz * 0.4));
		rough = 0.8;
	} else if (top && k == 1.0) {
		// тропа: утоптанный песок с камешками и колеями
		float n = vn(wpos.xz * 1.3) * 0.6 + vn(wpos.xz * 5.0) * 0.4;
		c = base * (0.86 + 0.22 * n);
		if (h31(cube + 5.0) > 0.93) c *= 0.8;
		c *= 0.94 + 0.08 * r;
	} else if (top && k == 6.0) {
		// утоптанная земля под домами и во дворах
		c = base * (0.85 + 0.2 * vn(wpos.xz * 2.0)) * (0.94 + 0.08 * r);
	} else if (top && k == 7.0) {
		// пашня: борозды
		float rows = 0.5 + 0.5 * sin(wpos.x * 6.2832 / 0.75);
		c = base * (0.8 + 0.3 * rows) * (0.94 + 0.08 * r);
	} else if (!top && k == 2.0) {
		// обрыв: слои камня по высоте
		float band = 0.5 + 0.5 * sin(wpos.y * 4.2 + sin(wpos.y * 1.3) * 1.5);
		c = mix(c, c * vec3(0.86, 0.84, 0.82), band * 0.8);
		c *= 0.93 + 0.12 * r;
	} else if (!top && k == 1.0) {
		// стенка уступа: сверху кромка травы, ниже земля
		vec3 dirt = vec3(0.24, 0.16, 0.09) * (0.9 + 0.2 * r);
		c = wpos.y > top_y - 0.05 ? c * 0.85 : dirt;
	} else if (top && k == 0.0) {
		// трава: крупные пятна светлее и темнее, у каждого кубика свой тон, редкие светлые травинки
		float big = vn(wpos.xz * 0.08) * 0.6 + vn(wpos.xz * 0.25) * 0.4;
		c = base * (0.86 + 0.26 * big);
		c *= 1.0 - 0.08 + 0.16 * r;
		float s = h31(cube + 17.0);
		if (s > 0.95) c *= 1.18;
		if (s < 0.03) c *= 0.85;
	} else {
		c *= 0.92 + 0.12 * r;
	}
	ALBEDO = c;
	ROUGHNESS = rough;
	SPECULAR = 0.3;
}
