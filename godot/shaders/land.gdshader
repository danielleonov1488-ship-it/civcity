// Земля игры: трава пятнами разных оттенков (у каждого кубика 12,5 см — свой тон), утоптанные тропы,
// дороги и площади из плитки Synty (как в промо Ancient Empire), песок, скалы со слоями.
shader_type spatial;
#ifdef CIVCITY_NO_SHADOWS
render_mode cull_back, diffuse_burley, specular_schlick_ggx, shadows_disabled;
#else
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
#endif

uniform sampler2D tile_cobble : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tile_footpath : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tile_road : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tile_plaza_a : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tile_plaza_b : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tile_plaza_c : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tile_plaza_d : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D surf : filter_linear_mipmap, repeat_disable;   // R мостовая, G площадь, B тропа
uniform float map_size = 256.0;
uniform vec4 season = vec4(0.0);                          // времена года (Seasons): x осень, y зима, z весна — трава
uniform float wet = 0.0;                                   // мокрая земля после дождя (Weather): темнее и с бликом
// этап 5.7–5.8: узор кисти «Земля» и улучшенные дороги (Land.deco). deco_on = false — узора в городе нет: картинка как была
uniform bool deco_on = false;
uniform sampler2D surf2 : filter_linear_mipmap, repeat_disable;  // R сочная трава, G луг в цветах, B песок, A утоптанная земля
uniform sampler2D surf3 : filter_linear_mipmap, repeat_disable;  // R гравий, G улучшение, B булыжник, A плиточная дорожка
uniform sampler2D tile_slab : source_color, filter_linear_mipmap, repeat_enable;     // большие плиты (мостовая из камня, травертин)
uniform sampler2D tile_mosaic : source_color, filter_linear_mipmap, repeat_enable;   // мозаика на улучшенной площади
// показ мазка до отпускания кнопки (game.gd): R — где ляжет дорога (или что уберёт ластик), G — куда денег не хватит.
// prev_mode 0 — выключен (картинка как была), 1 — дорога вида prev_kind (4 мостовая, 5 площадь, 1 тропа), 2 — ластик
uniform sampler2D surf_prev : filter_linear, repeat_disable;
uniform int prev_mode = 0;
uniform int prev_kind = 4;
// пейзаж за краем карты (вид 8): те же 4 оттенка травы чужой земли (линейные), большая дорога на север
uniform vec3 far_g0 = vec3(0.081, 0.120, 0.025);
uniform vec3 far_g1 = vec3(0.100, 0.144, 0.030);
uniform vec3 far_g2 = vec3(0.128, 0.176, 0.040);
uniform vec3 far_g3 = vec3(0.155, 0.191, 0.047);
uniform float far_road_x = 192.0;
uniform float far_road_half = 2.25;
// 13.11 (Synty Meadow Forest): трава — плавными пятнами в тонах палитры с узором травы, клевера, цветов и мха из набора
// (вместо резких клеток 25 см), тропа — утоптанная земля с камешками, кромка у дорог и окантовка у домов — гравий,
// берег — земля, стенки уступов в 12,5 см — травяные (не тёмные полосы). meadow_on = false (набора нет) — как было.
// rich = false («Низкая», «Очень низкая») — одна картинка травы вместо пяти, тропы, кромки, дворики, берега и уступы —
// прежние (без картинок набора): земля на низких не дороже, чем была
uniform bool meadow_on = false;
uniform bool rich = true;
uniform float road_scale = 2.5;
uniform sampler2D g_tex_a : source_color, filter_linear_mipmap, repeat_enable;     // трава
uniform sampler2D g_tex_b : source_color, filter_linear_mipmap, repeat_enable;     // трава темнее
uniform sampler2D g_clover : source_color, filter_linear_mipmap, repeat_enable;    // клевер
uniform sampler2D g_flower : source_color, filter_linear_mipmap, repeat_enable;    // трава в жёлтых цветах
uniform sampler2D g_moss : source_color, filter_linear_mipmap, repeat_enable;      // мох (низины у воды)
uniform sampler2D path_tex : source_color, filter_linear_mipmap, repeat_enable;    // утоптанная земля с камешками
uniform sampler2D gravel_tex : source_color, filter_linear_mipmap, repeat_enable;  // гравий
uniform sampler2D earth_tex : source_color, filter_linear_mipmap, repeat_enable;   // земля (берег, стенки уступов)
uniform vec3 pal0 = vec3(0.087, 0.127, 0.022);   // Land.C_GRASS (линейные)
uniform vec3 pal1 = vec3(0.111, 0.157, 0.025);
uniform vec3 pal2 = vec3(0.141, 0.188, 0.032);
uniform vec3 pal3 = vec3(0.181, 0.212, 0.038);
uniform vec3 lock_c = vec3(0.552, 0.497, 0.314);   // Land.LOCK (линейный)
// своя / чужая земля плавно (MeadowNature.plots_tex: точка на участок 64 м, белое — чужая): оттенок чужой земли
// слабый и меняется плавно от середины участка к середине соседнего — без прямоугольников (границу участка и так
// видно по золотому пунктиру); own_on = false — по цвету вершин, как было
uniform sampler2D own_tex : filter_linear, repeat_disable;
uniform bool own_on = false;
uniform vec3 road_tint = vec3(1.0);   // мостовая из набора — теплее (травертин), в тон терракотовому городу

#ifdef PERF14_BAKE_CAPTURE
uniform vec2 bake_center;
uniform float bake_span;
instance uniform float bake_shift = 0.0;
#endif
#ifdef PERF14_BAKE
uniform sampler2DArray baked_land : filter_linear_mipmap, repeat_disable;
uniform sampler2D baked_ready : filter_nearest, repeat_disable;
uniform bool bake_enabled = false;
#endif

varying vec3 wpos;
varying vec3 wnrm;
varying float kind;
varying float top_y;
varying vec2 sm2;                       // плавная земля (Land.smooth_mesh): x — доля пашни у узла, y = 1 — плавная сетка, 2 — русло под мостом

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
#ifdef PERF14_BAKE_CAPTURE
	wpos.x -= bake_shift;
#endif
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	kind = UV.x;
	top_y = UV.y;
	sm2 = UV2;
}

float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float h31(vec3 p) { p = fract(p * 0.1031); p += dot(p, p.zyx + 31.32); return fract((p.x + p.y) * p.z); }
float vn(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}

float lum3(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }

// Два непрерывных смещённых узора: без границ клеток и повторяющихся рядов камней.
// Только новые покрытия. rich=false: одна выборка, без крупной вариации.
vec3 worn_stone(sampler2D tex, vec2 p, bool garden, float cover, vec3 ground) {
	vec2 uv = p / (garden ? 3.1 : 2.7);
	vec3 raw = texture(tex, uv).rgb;
	float macro = 0.5;
	float patch_n = 0.5;
	if (rich) {
		patch_n = vn(p * 0.27 + vec2(12.7, 4.3));
		if (prev_mode != 1 || (prev_kind != 16 && prev_kind != 17)) {
			vec3 alt = texture(tex, vec2(-uv.y, uv.x) + vec2(0.37, 0.61)).rgb;
			// Светлые камни сохраняют читаемые швы при смешивании.
			float blend = smoothstep(0.23, 0.77, patch_n + (lum3(alt) - lum3(raw)) * 0.65);
			raw = mix(raw, alt, blend);
		}
		macro = vn(p / 12.0) * 0.65 + vn(p / 20.0 + vec2(8.1, 19.7)) * 0.35;
	}
	float light = lum3(raw);
	float gap = 1.0 - smoothstep(0.12, 0.29, light);
	float green = smoothstep(0.015, 0.065, raw.g - raw.b) * (1.0 - smoothstep(0.02, 0.08, raw.r - raw.g));
	// Песочный тон и приглушённый контраст; большие пятна теплее и холоднее.
	vec3 stone = mix(vec3(light), raw, 0.68 + macro * 0.12);
	stone = mix(vec3(0.27, 0.225, 0.16), stone * vec3(1.09, 1.0, 0.84), 0.72);
	stone *= (0.92 + macro * 0.16) * vec3(1.0 + (macro - 0.5) * 0.06, 1.0, 1.0 - (macro - 0.5) * 0.05);
	vec3 soil = vec3(0.23, 0.163, 0.095);
	vec3 moss = mix(ground, vec3(0.12, 0.17, 0.05), 0.65);
	float middle = smoothstep(0.55, 0.95, cover);
	float corner = (1.0 - middle) * smoothstep(0.48, 0.8, patch_n);
	float wear = garden ? 0.09 : (0.10 + 0.12 * middle + 0.13 * corner);
	stone = mix(stone, soil, wear * (0.45 + gap * 0.55));
	stone *= 1.0 - gap * 0.10;
	float moss_w = garden ? max(green * 0.65, gap * (0.18 + 0.18 * (1.0 - middle))) : gap * (0.06 * middle + 0.18 * corner);
	return mix(stone, moss, moss_w);
}

// Пятна травы — по картинке плавного шума (MeadowNature.ground: симплекс FastNoiseLite, бесшовная, 4 канала): у шума
// по сетке (vn) края пятен после порога идут прямыми вдоль сетки — на лугу это читалось прямоугольниками
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
const mat2 ROT_A = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));

// Трава набора Meadow Forest: плавные пятна палитры Land.C_GRASS (шум в мире, без клеток) × узор картинок травы;
// lk — чужая земля (1: приглушена к Land.LOCK, как у Land.chunk_mesh)
vec3 meadow_grass(vec3 wp, float lk, float r
#ifdef PERF14_LAND
	, float detail
#endif
) {
	vec4 nz = texture(noise_tex, wp.xz / 230.0);
	vec4 nz2 = texture(noise_tex, ROT_A * wp.xz / 67.0 + vec2(0.37, 0.71));
	float n = clamp(0.5 + ((nz.r * 0.7 + nz2.g * 0.3) - 0.5) * 2.0, 0.0, 1.0);
	vec3 pal = mix(mix(pal0, pal1, smoothstep(0.08, 0.4, n)), mix(pal2, pal3, smoothstep(0.62, 0.92, n)), smoothstep(0.38, 0.62, n));
	vec2 uv = wp.xz / 3.6;
	float la = lum3(texture(g_tex_a, uv).rgb) / 0.165;
	vec3 c = pal * mix(1.0, la, 0.75);
	if (rich) {
#ifdef PERF14_LAND
		// Средние в линейном цвете. Градиенты берём до ветки по дальности.
		float lb = 0.08642836, lc = 0.16722175, lm = 0.08698214;
		vec3 tf = vec3(0.0);
		vec2 dx = dFdx(uv), dy = dFdy(uv);
		if (detail > 0.0) {
			lb = mix(lb, lum3(textureGrad(g_tex_b, uv * 1.13 + 0.37, dx * 1.13, dy * 1.13).rgb), detail);
			lc = mix(lc, lum3(textureGrad(g_clover, uv * 0.9, dx * 0.9, dy * 0.9).rgb), detail);
			lm = mix(lm, lum3(textureGrad(g_moss, uv * 0.7, dx * 0.7, dy * 0.7).rgb), detail);
			tf = textureGrad(g_flower, uv * 0.8, dx * 0.8, dy * 0.8).rgb;
		}
#else
		// картинки — без ветвлений (в ветке у края пятна выборка мипмапа неверна), веса пятен — плавный шум sn
		vec3 tb = texture(g_tex_b, uv * 1.13 + 0.37).rgb;
		vec3 tc = texture(g_clover, uv * 0.9).rgb;
		vec3 tf = texture(g_flower, uv * 0.8).rgb;
		vec3 tm = texture(g_moss, uv * 0.7).rgb;
#endif
		float wb = smoothstep(0.42, 0.72, nz.g * 0.6 + nz2.b * 0.4);
#ifdef PERF14_LAND
		c = mix(c, pal * vec3(0.84, 0.9, 0.95) * mix(1.0, lb / 0.098, 0.75), wb * 0.7);
#else
		c = mix(c, pal * vec3(0.84, 0.9, 0.95) * mix(1.0, lum3(tb) / 0.098, 0.75), wb * 0.7);
#endif
		float wc = smoothstep(0.56, 0.8, nz.b * 0.55 + nz2.a * 0.45) * 0.8;
#ifdef PERF14_LAND
		c = mix(c, pal * mix(1.0, lc / 0.158, 0.55) * vec3(0.95, 1.06, 0.9), wc);
#else
		c = mix(c, pal * mix(1.0, lum3(tc) / 0.158, 0.55) * vec3(0.95, 1.06, 0.9), wc);
#endif
		// 15.11: цветы на земле — меньше, бело-розовые, а не оранжевые (владелец: «меньше оранжевых и красных»)
		float wf = smoothstep(0.66, 0.86, nz.a * 0.65 + nz2.r * 0.35) * 0.8;
		float fm = smoothstep(0.08, 0.25, tf.r - tf.g * 0.75);
		vec3 fcol = mix(vec3(0.95, 0.93, 0.86), vec3(0.95, 0.72, 0.8), step(0.5, fract(floor(wp.x * 0.37) * 0.618 + floor(wp.z * 0.37) * 0.331)));
#ifdef PERF14_LAND
		// Среднее цвета лепестков учитывает связь маски с яркостью.
		vec3 flowers = pal * (0.4 * (1.0 - 0.09101158) + 0.6 * (0.18829164 - 0.04257493) / 0.17)
			+ fcol * (0.45 * 0.09101158 + 1.1 * 0.04257493);
		if (detail > 0.0) {
			vec3 near_flower = mix(pal * mix(1.0, lum3(tf) / 0.17, 0.6), fcol * (0.45 + 1.1 * lum3(tf)), fm);
			flowers = mix(flowers, near_flower, detail);
		}
		c = mix(c, flowers, wf);
#else
		c = mix(c, mix(pal * mix(1.0, lum3(tf) / 0.17, 0.6), fcol * (0.45 + 1.1 * lum3(tf)), fm), wf);
#endif
		// мох — пятнами по шуму (не по высоте: высота у земли ступеньками по 12,5 см — по ней мох ложился бы полосами
		// и прямоугольниками по уступам)
		float wm = smoothstep(0.56, 0.8, (1.0 - nz.g) * 0.55 + nz2.r * 0.45) * 0.55;
#ifdef PERF14_LAND
		c = mix(c, pal * vec3(0.78, 0.95, 0.75) * mix(1.0, lm / 0.085, 0.6), wm);
#else
		c = mix(c, pal * vec3(0.78, 0.95, 0.75) * mix(1.0, lum3(tm) / 0.085, 0.6), wm);
#endif
	}
	c *= 0.95 + 0.1 * r;
	// чужая земля — как у Land.chunk_mesh: 18% к Land.LOCK в sRGB (в линейных цветах та же доля дала бы белёсую траву)
	if (lk > 0.0) c = pow(mix(pow(c, vec3(1.0 / 2.2)), pow(lock_c, vec3(1.0 / 2.2)), 0.08 * lk), vec3(2.2));
	return c;
}

// Пятна травы за краем карты — как Land.tint: шум по клеткам 25 см, 4 оттенка (доли как на карте: 4/44/46/5 %)
vec3 far_grass(vec3 wp) {
	vec2 q = (floor(wp.xz * 4.0) + 0.5) * 0.045;
	float n = (vn(q) * 4.0 + vn(q * 2.0 + vec2(17.3, 5.1)) * 2.0 + vn(q * 4.0 + vec2(3.7, 11.9))) / 7.0;
	n = 0.5 + (n - 0.5) * 1.08;
	return n < 0.25 ? far_g0 : (n < 0.5 ? far_g1 : (n < 0.75 ? far_g2 : far_g3));
}

#ifdef PERF14_LAND
float detail_noise(vec2 p, float detail) {
	return detail > 0.0 ? mix(0.5, vn(p), detail) : 0.5;
}
#endif

#ifdef PERF14_BAKE
vec3 bake_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

vec4 read_baked(vec2 p, bool far, float footprint, inout float weight) {
	float tile_m = far ? 384.0 : 64.0;
	float extent = far ? 9.0 : 6.0;
	vec2 grid = (p + (far ? vec2(1536.0) : vec2(0.0))) / tile_m;
	vec2 cell = floor(grid);
	if (any(lessThan(cell, vec2(0.0))) || any(greaterThanEqual(cell, vec2(extent)))) {
		weight = 0.0;
		return vec4(0.0);
	}
	int id = (far ? 36 : 0) + int(cell.y * extent + cell.x);
	if (texelFetch(baked_ready, ivec2(id % 16, id / 16), 0).r < 0.5) {
		weight = 0.0;
		return vec4(0.0);
	}
	// Поля в 8 пикселей скрывают стыки при фильтрации.
	vec2 uv = (fract(grid) * 128.0 + 8.0) / 144.0;
	float mip = clamp(log2(max(footprint * 128.0 / tile_m, 1.0)), 0.0, 3.0);
	vec4 baked = textureLod(baked_land, vec3(uv, float(id)), mip);
	return vec4(bake_linear(baked.rgb), baked.a);
}
#endif

void fragment() {
#ifdef PERF14_BAKE_CAPTURE
	if (any(greaterThan(abs(wpos.xz - bake_center), vec2(bake_span * 0.5)))) discard;
#endif
#ifdef PERF14_LAND
	float detail = 1.0 - smoothstep(60.0, 90.0, distance(wpos, INV_VIEW_MATRIX[3].xyz));
#endif
	vec3 base = COLOR.rgb;               // вершинный цвет: оттенок клетки (у чужой земли приглушён)
	float k = sm2.y > 1.5 ? 3.0 : floor(kind + 0.5);
	bool far = k > 7.5;
#ifdef PERF14_BAKE
	float footprint = max(length(dFdx(wpos.xz)), length(dFdy(wpos.xz)));
	float bw = 0.0;
	vec4 baked = vec4(0.0);
	if (bake_enabled && map_size == 384.0 && prev_mode == 0 && wnrm.y > 0.65) {
		float d = distance(wpos, INV_VIEW_MATRIX[3].xyz);
		vec2 p = wpos.xz;
		float edge = min(min(p.x, p.y), min(map_size - p.x, map_size - p.y));
		float edge_blend = smoothstep(4.0, 12.0, edge);
		if (far) {
			edge_blend = smoothstep(12.0, 32.0, length(max(max(-p, p - vec2(map_size)), vec2(0.0))));
			if (p.y < 0.0) edge_blend *= smoothstep(far_road_half + 1.0, far_road_half + 6.0, abs(p.x - far_road_x));
		}
		bw = (rich ? smoothstep(110.0, 155.0, d) : smoothstep(76.0, 112.0, d))
			* edge_blend * smoothstep(0.65, 0.83, wnrm.y);
		if (bw > 0.0 && !far) {
			// Рисунок мостовых, площадей и троп сохраняем на исходных текстурах.
			vec3 cover = textureLod(surf, p / map_size, 0.7).rgb;
			bw *= 1.0 - smoothstep(0.06, 0.28, max(cover.r, max(cover.g, cover.b)));
		}
		if (bw > 0.0) baked = read_baked(p, far, footprint, bw);
	}
#endif
	float fv = wpos.y / 0.125 + 0.5;          // для горизонталей за краем карты (производная — вне ветвлений)
	float fw = max(fwidth(fv), 1e-4);
	float rough = 0.95;
	vec3 c;
#ifdef PERF14_BAKE
	if (bw < 1.0) {
#endif
	float dmap = 0.0;
	if (far) {
		// за краем карты: вблизи — пятна клетками, как на карте; вдали — крупные пятна из вершинного цвета
		vec2 dd = max(max(-wpos.xz, wpos.xz - vec2(map_size)), vec2(0.0));
		dmap = length(dd);
#ifndef PERF14_E4_CONTROL
		if (dmap < 420.0) base = mix(far_grass(wpos), base, smoothstep(90.0, 420.0, dmap));
#else
		base = mix(far_grass(wpos), base, smoothstep(90.0, 420.0, dmap));
#endif
		k = 0.0;
	}
	vec3 an = abs(wnrm);
	bool smooth_g = sm2.y > 0.5;
	bool top = an.y > 0.5 || smooth_g;      // у плавной земли стенок нет: крутой склон — камень (ниже)
	vec3 cube = smooth_g ? floor(vec3(wpos.x * 8.0, 0.0, wpos.z * 8.0)) : floor(wpos * 8.0 - wnrm * 0.5);
#ifdef PERF14_LAND
	float r = detail > 0.0 ? mix(0.5, h31(cube), detail) : 0.5;
#else
	float r = h31(cube);
#endif
	bool mg = meadow_on && (k == 0.0 || k == 1.0 || k == 4.0 || k == 5.0);
	if (mg) {
		// чужая земля: вершинный цвет приглушён к Land.LOCK — синего к зелёному у него больше (≥ 0,26 против ≤ 0,18 у травы)
		float lk = far ? 1.0 : step(0.22, COLOR.b / max(COLOR.g, 1e-3));
		if (own_on && !far) {
			lk = texture(own_tex, wpos.xz / map_size).r;
		}
		vec3 mgc = meadow_grass(wpos, lk, r
#ifdef PERF14_LAND
			, detail
#endif
		);
		base = far ? mix(mgc, base, smoothstep(90.0, 420.0, dmap)) : mgc;
	}
	c = base;
	if (top) {
		if (k == 6.0) {
			// утоптанная земля под домами и во дворах
#ifdef PERF14_LAND
			c = base * (0.85 + 0.2 * detail_noise(wpos.xz * 2.0, detail)) * (0.94 + 0.08 * r);
#else
			c = base * (0.85 + 0.2 * vn(wpos.xz * 2.0)) * (0.94 + 0.08 * r);
#endif
		} else if (k == 7.0) {
			// пашня: борозды
			float rows = 0.5 + 0.5 * sin(wpos.x * 6.2832 / 0.75);
			c = base * (0.8 + 0.3 * rows) * (0.94 + 0.08 * r);
		} else if (mg) {
			// трава набора — уже в base (meadow_grass); редкие сухие травинки и тёмные кочки по кубикам, как в Town to City
#ifdef PERF14_LAND
			vec3 mean = c * (1.0 - 0.01 * 0.15 - 0.0015 * 0.2) + vec3(0.74, 0.68, 0.42) * 0.0003;
			if (detail > 0.0) {
				float s = h31(cube + 17.0);
				if (s > 0.9985) c = mix(c, vec3(0.74, 0.68, 0.42), 0.2);
				if (s < 0.01) c *= 0.85;
				c = mix(mean, c, detail);
			} else {
				c = mean;
			}
#else
			float s = h31(cube + 17.0);
			if (s > 0.9985) c = mix(c, vec3(0.74, 0.68, 0.42), 0.2);
			if (s < 0.01) c *= 0.85;
#endif
		} else if (k == 0.0 || k == 1.0 || k == 4.0 || k == 5.0) {
			// трава под всем: крупные пятна светлее и темнее, у каждого кубика свой тон, редкие светлые травинки
			float big = vn(wpos.xz * 0.06) * 0.55 + vn(wpos.xz * 0.21) * 0.45;
			c = base * (0.8 + 0.34 * big);
			// «щетина» как в Town to City: у каждого кубика свой тон, кое-где сухие травинки и тёмные кочки
			c *= 0.86 + 0.24 * r;
#ifdef PERF14_LAND
			vec3 mean = (c * (1.0 - 0.025 * 0.28 - 0.01 * 0.3) + vec3(0.74, 0.68, 0.42) * 0.003) * 0.9985
				+ vec3(0.9, 0.86, 0.74) * 0.0005 + vec3(0.8, 0.4, 0.46) * 0.001;
			if (detail > 0.0) {
				float s = h31(cube + 17.0);
				if (s > 0.99) c = mix(c, vec3(0.74, 0.68, 0.42), 0.3);
				if (s < 0.025) c *= 0.72;
				// редкие крошечные цветочки
				float fl = h31(cube + 41.0);
				if (fl > 0.9985) c = fl > 0.9995 ? vec3(0.9, 0.86, 0.74) : vec3(0.8, 0.4, 0.46);
				c = mix(mean, c, detail);
			} else {
				c = mean;
			}
#else
			float s = h31(cube + 17.0);
			if (s > 0.99) c = mix(c, vec3(0.74, 0.68, 0.42), 0.3);
			if (s < 0.025) c *= 0.72;
			// редкие крошечные цветочки
			float fl = h31(cube + 41.0);
			if (fl > 0.9985) c = fl > 0.9995 ? vec3(0.9, 0.86, 0.74) : vec3(0.8, 0.4, 0.46);
#endif
		} else {
			c *= 0.92 + 0.12 * r;
		}
		if (smooth_g) {
			// крутой склон плавной земли (обрыв, край выровненной площадки): камень слоями и земля
			float steep = 1.0 - smoothstep(0.62, 0.84, wnrm.y);
			if (steep > 0.01) {
				float band = 0.5 + 0.5 * sin(wpos.y * 3.1 + sin(wpos.y * 1.3 + wpos.x * 0.05) * 1.5);
#ifdef PERF14_LAND
				vec3 rk = vec3(0.42, 0.36, 0.3) * mix(1.0, 0.78, band) * (0.9 + 0.2 * detail_noise(wpos.xz * 1.7, detail));
#else
				vec3 rk = vec3(0.42, 0.36, 0.3) * mix(1.0, 0.78, band) * (0.9 + 0.2 * vn(wpos.xz * 1.7));
#endif
				if (rich && meadow_on) {
					rk = mix(texture(earth_tex, wpos.xz / 2.0).rgb * vec3(1.02, 0.92, 0.8), rk, 0.45);
				}
				c = mix(c, rk, steep);
			}
			// пашня под фермами (Kind.FIELD — доля у узлов): борозды
			if (sm2.x > 0.01) {
				float rows = 0.5 + 0.5 * sin(wpos.x * 6.2832 / 0.75);
				vec3 fc = vec3(0.325, 0.195, 0.076) * (0.8 + 0.3 * rows) * (0.94 + 0.08 * r);
				c = mix(c, fc, smoothstep(0.15, 0.6, sm2.x));
			}
		}
		if (k == 0.0 || k == 1.0 || k == 4.0 || k == 5.0 || k == 6.0) {
			// покрытия по маске с плавной выборкой — края скруглены, а не ступеньками по клеткам
#ifdef PERF14_E4_CONTROL
			vec4 m = textureLod(surf, wpos.xz / map_size, 0.7);   // размытая маска: плавные края без ступенек
			if (far) {
				// за краем карты маски нет: большая дорога уходит на север прямо за горизонт (края — как у маски)
				float rd = abs(wpos.x - far_road_x);
				m = vec4(wpos.z < 0.0 ? clamp(0.5 + (far_road_half - rd) / 1.6, 0.0, 1.0) : 0.0, 0.0, 0.0, 1.0);
			}
#else
			vec4 m;
			if (far) {
				// за краем карты маски нет: большая дорога уходит на север прямо за горизонт (края — как у маски)
				float rd = abs(wpos.x - far_road_x);
				m = vec4(wpos.z < 0.0 ? clamp(0.5 + (far_road_half - rd) / 1.6, 0.0, 1.0) : 0.0, 0.0, 0.0, 1.0);
			} else {
				m = textureLod(surf, wpos.xz / map_size, 0.7);   // размытая маска: плавные края без ступенек
			}
#endif
			float wob = vn(wpos.xz * 2.3) - 0.5;
			vec4 g2 = vec4(0.0);
			vec4 g3 = vec4(0.0);
			if (deco_on && !far) {
				g2 = textureLod(surf2, wpos.xz / map_size, 0.7);
				g3 = textureLod(surf3, wpos.xz / map_size, 0.7);
				float gs = g2.r + g2.g + g2.b + g2.a + g3.r;
				if (gs > 0.02) {
					// кисть «Земля» (этап 5.8): узор на траве, край неровный, как у троп
					float gw = smoothstep(0.22, 0.55, gs + wob * 0.3);
#ifdef PERF14_LAND
					float gn = vn(wpos.xz * 1.5) * 0.6 + detail_noise(wpos.xz * 5.5, detail) * 0.4;
#else
					float gn = vn(wpos.xz * 1.5) * 0.6 + vn(wpos.xz * 5.5) * 0.4;
#endif
#ifdef PERF14_LAND
					vec3 lush = base * vec3(0.6, 0.86, 0.48) * (0.8 + 0.32 * vn(wpos.xz * 0.9)) * (0.84 + 0.26 * r);
					vec3 mead = c * vec3(1.02, 1.07, 0.9);
					vec3 sand = vec3(0.72, 0.59, 0.36) * (0.9 + 0.16 * gn) * (0.95 + 0.07 * r);
					vec3 earth = vec3(0.29, 0.17, 0.085) * (0.84 + 0.3 * gn) * (0.92 + 0.12 * r);
					vec3 grav_base = vec3(0.4, 0.38, 0.34) * (0.94 + 0.1 * gn);
					vec3 grav = grav_base * 0.8509158 + vec3(0.6, 0.57, 0.5) * 0.07;
					vec3 lush_mean = lush * (vec3(0.81 + 0.14 * 0.68) + vec3(1.25, 1.3, 1.1) * 0.05);
					vec3 flowers = vec3(0.9, 0.88, 0.8) * 0.3 + vec3(0.95, 0.74, 0.14) * 0.25
						+ vec3(0.82, 0.3, 0.45) * 0.25 + vec3(0.46, 0.36, 0.82) * 0.2;
					vec3 mead_mean = mix(mead, flowers, 0.12);
					if (detail > 0.0) {
						float tf = h31(cube + 61.0);
						if (tf < 0.14) lush *= 0.68;
						else if (tf > 0.95) lush *= vec3(1.25, 1.3, 1.1);
						float fl = h31(cube + 71.0);
						if (fl > 0.88) {
							float pc = h31(cube + 3.0);
							mead = pc < 0.3 ? vec3(0.9, 0.88, 0.8) : (pc < 0.55 ? vec3(0.95, 0.74, 0.14) : (pc < 0.8 ? vec3(0.82, 0.3, 0.45) : vec3(0.46, 0.36, 0.82)));
						}
						float pb = h31(cube + 81.0);
						vec3 grav_near = grav_base * (0.72 + 0.46 * pb);
						if (pb > 0.93) grav_near = vec3(0.6, 0.57, 0.5);
						else if (pb < 0.06) grav_near *= 0.6;
						grav = mix(grav, grav_near, detail);
					}
					lush = mix(lush_mean, lush, detail);
					mead = mix(mead_mean, mead, detail);
#else
					vec3 lush = base * vec3(0.6, 0.86, 0.48) * (0.8 + 0.32 * vn(wpos.xz * 0.9)) * (0.84 + 0.26 * r);
					float tf = h31(cube + 61.0);
					if (tf < 0.14) lush *= 0.68;                  // тёмные кочки
					else if (tf > 0.95) lush = lush * vec3(1.25, 1.3, 1.1);   // светлые травинки
					vec3 mead = c * vec3(1.02, 1.07, 0.9);
					float fl = h31(cube + 71.0);
					if (fl > 0.88) {
						float pc = h31(cube + 3.0);
						mead = pc < 0.3 ? vec3(0.9, 0.88, 0.8) : (pc < 0.55 ? vec3(0.95, 0.74, 0.14) : (pc < 0.8 ? vec3(0.82, 0.3, 0.45) : vec3(0.46, 0.36, 0.82)));
					}
					vec3 sand = vec3(0.72, 0.59, 0.36) * (0.9 + 0.16 * gn) * (0.95 + 0.07 * r);
					vec3 earth = vec3(0.29, 0.17, 0.085) * (0.84 + 0.3 * gn) * (0.92 + 0.12 * r);
					float pb = h31(cube + 81.0);
					vec3 grav = vec3(0.4, 0.38, 0.34) * (0.72 + 0.46 * pb) * (0.94 + 0.1 * gn);
					if (pb > 0.93) grav = vec3(0.6, 0.57, 0.5);
					else if (pb < 0.06) grav *= 0.6;
#endif
					vec3 gc = (lush * g2.r + mead * g2.g + sand * g2.b + earth * g2.a + grav * g3.r) / gs;
					c = mix(c, gc, gw);
					rough = mix(rough, 1.0, gw * (g2.b + g2.a + g3.r) / gs);
				}
			}
			float new_cover = g3.b + g3.a;
			if (new_cover > 0.0) {
				// Класс ходьбы прежний, его плитку заменяет новый материал.
				m.r = max(0.0, m.r - g3.b);
				m.b = max(0.0, m.b - g3.a);
			}
			float w_path = smoothstep(0.28, 0.6, m.b + wob * 0.35);
			float w_road = smoothstep(0.44, 0.54, m.r + wob * 0.06);
			float w_plaza = smoothstep(0.44, 0.54, m.g + wob * 0.04);
			float edge = smoothstep(0.18, 0.42, max(m.r, m.g)) * (1.0 - max(w_road, w_plaza));
			if (meadow_on && rich) {
				// кромка у мостовой — гравий с травой (набор Meadow), а не тёмная полоса
				vec3 gv = texture(gravel_tex, wpos.xz / 2.2).rgb * vec3(0.92, 0.88, 0.8);
				c = mix(c, mix(gv, c, step(0.7, h31(cube + 29.0)) * 0.6), edge * 0.55);
			} else {
				c *= 1.0 - 0.18 * edge;                   // притоптанная кромка у мостовой
			}
			// окантовка у домов и лавок (Land.wear → surf.a: 1 — трава): утоптанная глина с камешками,
			// край неровный, кое-где уцелели кустики травы
			float ap = (1.0 - m.a) * (1.0 - max(w_road, w_plaza));
			if (ap > 0.02) {
				float n2 = vn(wpos.xz * 1.7) * 0.6 + vn(wpos.xz * 6.0) * 0.4;
				float w_ap = smoothstep(0.18, 0.58, ap + (n2 - 0.5) * 0.45 + wob * 0.25);
				vec3 soil = vec3(0.27, 0.155, 0.075) * (0.82 + 0.3 * n2);                 // глина: тёплая, темнее троп
				soil = mix(soil, vec3(0.33, 0.21, 0.11), smoothstep(0.6, 0.98, ap) * 0.4);   // у стены — суше
				if (meadow_on && rich) {
					// у домов — светлая утоптанная земля с гравием (набор Meadow): дом стоит на дворике, а не на голой глине
					vec3 gv2 = texture(gravel_tex, wpos.xz / 2.0).rgb * vec3(0.95, 0.9, 0.82);
					vec3 pt = texture(path_tex, wpos.xz / 3.0).rgb * vec3(1.1, 0.98, 0.82);
					soil = mix(pt, gv2, smoothstep(0.45, 0.9, ap) * 0.7) * (0.9 + 0.2 * n2);
				}
				soil *= 0.92 + 0.12 * r;
				float pb = h31(cube + 13.0);
				if (pb > 0.975) soil = mix(soil, vec3(0.5, 0.46, 0.4), 0.7);                // камешки
				else if (pb < 0.05) soil *= 0.78;
				float tuft = step(0.82, h31(cube + 23.0)) * (1.0 - smoothstep(0.35, 0.8, ap));
				c = mix(c, mix(soil, c, tuft), w_ap * 0.92);
				rough = mix(rough, 1.0, w_ap);
			}
			if (w_path > 0.0) {
				// тропа: утоптанный песок с камешками
				float n = vn(wpos.xz * 1.3) * 0.6 + vn(wpos.xz * 5.0) * 0.4;
				vec3 p = vec3(0.56, 0.39, 0.19) * (0.86 + 0.22 * n);
				if (h31(cube + 5.0) > 0.93) p *= 0.8;
				p *= 0.94 + 0.08 * r;
				if (meadow_on && rich) {
					// тропа — утоптанная земля с камешками и трещинами (набор Meadow), тёплая, по краю — мелкий гравий
					p = texture(path_tex, wpos.xz / 3.2).rgb * vec3(1.3, 1.08, 0.78) * (0.92 + 0.14 * n);
					vec3 gp = texture(gravel_tex, wpos.xz / 2.0).rgb * vec3(1.0, 0.93, 0.82);
					p = mix(gp, p, smoothstep(0.35, 0.75, m.b + wob * 0.3));
				}
				c = mix(c, p, w_path);
			}
			if (w_road > 0.0) {
				// дорога: каменная плитка Synty, у края темнее — бордюр
				vec3 t = texture(tile_road, wpos.xz / road_scale).rgb * road_tint;
				t *= (0.92 + 0.12 * vn(wpos.xz * 0.6)) * (0.9 + 0.12 * r);
				if (deco_on) {
					// улучшенная мостовая (этап 5.7): большие серые плиты, у каждой — свой тон
					float wu = smoothstep(0.3, 0.62, g3.g + wob * 0.08);
					if (wu > 0.0) {
						vec3 sl = texture(tile_slab, wpos.xz / 1.8).rgb * vec3(0.5, 0.52, 0.57);
						sl *= (0.86 + 0.24 * h21(floor(wpos.xz / 0.9) * 1.31 + 7.7)) * (0.93 + 0.1 * r);
						t = mix(t, sl, wu);
					}
				}
				t *= mix(0.8, 1.0, smoothstep(0.5, 0.64, m.r + wob * 0.06));
				c = mix(c, t, w_road);
				rough = mix(rough, 0.85, w_road);
			}
			if (w_plaza > 0.0) {
				// площадь: узорная плитка, у каждого квадрата 2,5 м — свой рисунок
				vec2 cell = floor(wpos.xz / 2.5);
				float pick = h21(cell * 1.37 + 3.1);
				vec2 uv = wpos.xz / 2.5;
				vec3 t;
				if (pick < 0.4) t = texture(tile_plaza_a, uv).rgb;
				else if (pick < 0.75) t = texture(tile_plaza_b, uv).rgb;
				else if (pick < 0.9) t = texture(tile_plaza_c, uv).rgb;
				else t = texture(tile_plaza_d, uv).rgb;
				t *= 0.94 + 0.1 * vn(wpos.xz * 0.4);
				if (deco_on) {
					// улучшенная площадь (этап 5.7): тёплый травертин большими плитами, кое-где — круг мозаики (квадрат 5 м)
					float wu = smoothstep(0.3, 0.62, g3.g + wob * 0.08);
					if (wu > 0.0) {
						vec3 tv = texture(tile_slab, wpos.xz / 2.5).rgb * vec3(1.06, 1.0, 0.9);
						tv *= 0.9 + 0.14 * h21(floor(wpos.xz / 1.25) * 0.73 + 2.9);
						if (h21(floor(wpos.xz / 5.0) * 1.91 + 5.3) < 0.2) tv = texture(tile_mosaic, wpos.xz / 5.0).rgb;
						t = mix(t, tv, wu);
					}
				}
				t *= mix(0.82, 1.0, smoothstep(0.5, 0.64, m.g));
				c = mix(c, t, w_plaza);
				rough = mix(rough, 0.8, w_plaza);
			}
			if (new_cover > 0.0) {
				// Маска 0,5 м с mip 0,7: мягкая кромка около 1–1,5 м.
				float edge_noise = rich ? vn(wpos.xz * 0.83 + vec2(4.9, 7.3)) - 0.5 : 0.0;
				float cover = clamp(new_cover, 0.0, 1.0);
				float worn = cover + edge_noise * 0.30 * (1.0 - cover);
				float weight = smoothstep(0.04, 0.96, worn);
				bool garden = g3.a > g3.b;
				vec3 stone;
				if (garden) {
					stone = worn_stone(tile_footpath, wpos.xz, true, cover, base);
				} else {
					stone = worn_stone(tile_cobble, wpos.xz, false, cover, base);
					// Редкие камни снаружи кромки, без мелкой ряби.
					float loose = smoothstep(0.64, 0.82, vn(wpos.xz * 3.0));
					weight = max(weight, loose * smoothstep(0.02, 0.22, cover) * (1.0 - smoothstep(0.22, 0.5, cover)) * 0.38);
				}
				vec3 bed = mix(c, vec3(0.23, 0.163, 0.095), garden ? 0.12 : 0.28);
				c = mix(c, bed, smoothstep(0.01, 0.45, cover) * (1.0 - weight));
				c = mix(c, stone, weight);
				rough = mix(rough, 0.94, weight);
			}
		}
		if (prev_mode > 0 && !far && k != 2.0 && k != 7.0) {
			float wob = vn(wpos.xz * 2.3) - 0.5;
			vec2 pv = texture(surf_prev, wpos.xz / map_size).rg;
			float wp = smoothstep(0.3, 0.6, pv.r + wob * 0.12);
			float wr = smoothstep(0.3, 0.6, pv.g + wob * 0.12);
			if (prev_mode == 1) {
				// задуманная дорога: плитка её вида чуть светлее, по краю — светлая кайма
				vec3 t;
				if (prev_kind == 5) {
					t = texture(tile_plaza_a, wpos.xz / 2.5).rgb;
				} else if (prev_kind == 9) {
					t = texture(tile_slab, wpos.xz / 1.8).rgb * vec3(0.5, 0.52, 0.57);   // «Улучшить»
				} else if (prev_kind == 16) {
					t = base;
					if (wp + wr > 0.0) t = worn_stone(tile_cobble, wpos.xz, false, 1.0, base);
				} else if (prev_kind == 17) {
					t = base;
					if (wp + wr > 0.0) t = worn_stone(tile_footpath, wpos.xz, true, 1.0, base);
				} else if (prev_kind >= 10) {
					// «Земля»: цвет выбранного узора (10 — обычная трава)
					int g = prev_kind - 10;
					t = g == 1 ? base * vec3(0.6, 0.86, 0.48) : (g == 2 ? mix(c, vec3(0.95, 0.74, 0.14), 0.25) : (g == 3 ? vec3(0.72, 0.59, 0.36) :
						(g == 4 ? vec3(0.29, 0.17, 0.085) : (g == 5 ? vec3(0.4, 0.38, 0.34) : base))));
				} else if (prev_kind == 1) {
					t = vec3(0.56, 0.39, 0.19) * (0.86 + 0.22 * vn(wpos.xz * 1.3));
				} else {
					t = texture(tile_road, wpos.xz / 2.5).rgb;
				}
				t *= 1.08;
				float rim = smoothstep(0.08, 0.3, pv.r + pv.g) * (1.0 - smoothstep(0.35, 0.6, pv.r + pv.g));
				c = mix(c, t, wp * 0.8);
				c = mix(c, vec3(1.0, 0.96, 0.84), rim * 0.45);
				// куда денег не хватит — красным
				c = mix(c, mix(t, vec3(0.85, 0.22, 0.16), 0.6), wr * 0.8);
			} else {
				// ластик: дорога, которую он уберёт, — красным
				c = mix(c, vec3(0.85, 0.22, 0.16), wp * 0.55);
			}
		}
		if (far && !meadow_on) {
			// горизонтали там, где на карте уступы по 12,5 см (высота (n + ½)·0,125): тонкие тёмные линии,
			// вдали, где они сливаются, — гаснут
			float line = (1.0 - smoothstep(0.0, fw * 1.4, fract(fv))) * (1.0 - smoothstep(0.3, 0.8, fw));
			c *= 1.0 - 0.45 * line;
		}
	} else if (k == 2.0) {
		// обрыв: слои камня по высоте
		float band = 0.5 + 0.5 * sin(wpos.y * 3.1 + sin(wpos.y * 1.3 + wpos.x * 0.05) * 1.5);
#ifdef PERF14_LAND
		float fine = detail_noise(vec2(wpos.x * 0.7 + wpos.z * 0.7, wpos.y * 6.0), detail);
#else
		float fine = vn(vec2(wpos.x * 0.7 + wpos.z * 0.7, wpos.y * 6.0));
#endif
		c = mix(c * vec3(1.03, 1.0, 0.97), c * vec3(0.8, 0.76, 0.72), band * 0.75);
		c *= 0.88 + 0.2 * fine;
		c *= 0.93 + 0.1 * r;
	} else if (k == 1.0) {
		// стенка уступа: сверху кромка травы, ниже земля
		vec3 dirt = vec3(0.34, 0.25, 0.14) * (0.9 + 0.2 * r);
		if (meadow_on) {
			// уступ в одну ступеньку (12,5 см) — весь травяной, чуть темнее верха: склон читается ровными горизонталями,
			// а не тёмными лесенками; выше — земля из набора (по стенке, а не сверху; на низких — прежняя земля без картинки)
			vec3 et = dirt * vec3(1.25, 1.2, 1.15);
			if (rich) {
				vec2 wuv = (an.x > an.z ? wpos.zy : wpos.xy) / 2.0;
				et = texture(earth_tex, wuv).rgb * vec3(1.05, 0.92, 0.78);
			}
			c = top_y < 1.31 ? et * 0.85 : (top_y - wpos.y < 0.14 ? c * 0.93 : mix(et, c * 0.7, 0.25));   // у воды — берег, не трава
			if (top_y - wpos.y < 0.14) {
				NORMAL = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;   // ступенька светится как луг: без тёмной штриховки склонов
			}
		} else {
			c = wpos.y > top_y - 0.05 ? c * 0.85 : dirt;
		}
	} else {
		c *= 0.92 + 0.12 * r;
	}
	bool bank = k == 3.0;
	if (smooth_g && !bank && wpos.y < 1.32) {
		vec4 mb = textureLod(surf, wpos.xz / map_size, 0.7);
		bank = max(mb.r, mb.g) < 0.3;          // у воды — берег (дороги и площади у воды — как есть)
	}
	if (meadow_on && top && bank) {
		// берег прудов и ручьёв: земля и мелкий гравий набора, у воды мокрее; кверху — в траву (без резкой границы);
		// на низких — те же тона без картинок
		vec3 sd = vec3(0.36, 0.27, 0.17) * (0.88 + 0.24 * vn(wpos.xz * 0.6));
		vec3 gr2 = pal1 * 0.92;
		if (rich) {
			sd = texture(earth_tex, wpos.xz / 2.4).rgb * vec3(1.18, 1.06, 0.86);
			vec3 gw = texture(gravel_tex, wpos.xz / 1.8).rgb * vec3(0.95, 0.92, 0.86);
			sd = mix(sd, gw, smoothstep(0.55, 0.8, vn(wpos.xz * 0.6)) * 0.6);
			gr2 = meadow_grass(wpos, 0.0, r
#ifdef PERF14_LAND
			, detail
#endif
		) * 0.92;
		}
		sd *= mix(0.72, 1.0, smoothstep(1.02, 1.14, wpos.y));
		c = mix(sd, gr2, smoothstep(1.04, 1.12, wpos.y + (vn(wpos.xz * 0.9) - 0.5) * 0.04)) * (0.95 + 0.1 * r);   // земля — узкой каймой у воды
		// дно под водой — темнее, с зеленцой (ил): у мелких заводей сквозь воду не светит песок
		c = mix(c, vec3(0.11, 0.12, 0.065), (1.0 - smoothstep(0.96, 1.03, wpos.y)) * 0.75);
		rough = 0.9;
	}
#ifdef PERF14_BAKE
		if (bw > 0.0) {
			c = mix(c, baked.rgb, bw);
			rough = mix(rough, baked.a, bw);
		}
	} else {
		c = baked.rgb;
		rough = baked.a;
	}
#endif
#ifdef PERF14_BAKE_CAPTURE
	ALBEDO = bake_shift > 0.0 ? vec3(rough) : c;
#else
	if (season != vec4(0.0)) {
		// трава по временам года: осенью золотится, зимой бледнеет, весной сочнее; мостовые и камни — как были
		float gr = smoothstep(0.004, 0.03, c.g - max(c.r, c.b));
		float lg = dot(c, vec3(0.2126, 0.7152, 0.0722));
		vec3 t = mix(c, vec3(lg * 1.45, lg * 1.08, lg * 0.36), season.x * 0.5);
		t = mix(t, mix(vec3(lg * 1.05), c, 0.4) * vec3(0.97, 1.0, 1.02), season.y * 0.65);
		t = mix(t, c * vec3(0.94, 1.08, 0.9), season.z);
		c = mix(c, t, gr);
	}
	ALBEDO = c * (1.0 - 0.28 * wet);
#endif
	ROUGHNESS = mix(rough, 0.32, wet);
	SPECULAR = mix(0.3, 0.55, wet);
}
