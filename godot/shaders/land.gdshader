// Земля игры: трава пятнами разных оттенков (у каждого кубика 12,5 см — свой тон), утоптанные тропы,
// дороги и площади из плитки Synty (как в промо Ancient Empire), песок, скалы со слоями.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

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
uniform sampler2D surf3 : filter_linear_mipmap, repeat_disable;  // R гравий, G улучшенная дорога (плиты, травертин)
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
// rich = false («Низкая», «Очень низкая») — одна картинка травы вместо пяти
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

float lum3(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }

// Трава набора Meadow Forest: плавные пятна палитры Land.C_GRASS (шум в мире, без клеток) × узор картинок травы;
// lk — чужая земля (1: приглушена к Land.LOCK, как у Land.chunk_mesh)
vec3 meadow_grass(vec3 wp, float lk, float r) {
	float n = vn(wp.xz * 0.035) * 0.55 + vn(wp.xz * 0.11 + vec2(7.1, 3.3)) * 0.3 + vn(wp.xz * 0.43 + vec2(3.7, 9.2)) * 0.15;
	n = clamp(0.5 + (n - 0.5) * 1.5, 0.0, 1.0);
	vec3 pal = mix(mix(pal0, pal1, smoothstep(0.08, 0.4, n)), mix(pal2, pal3, smoothstep(0.62, 0.92, n)), smoothstep(0.38, 0.62, n));
	vec2 uv = wp.xz / 3.6;
	float la = lum3(texture(g_tex_a, uv).rgb) / 0.165;
	vec3 c = pal * mix(1.0, la, 0.75);
	if (rich) {
		float nb = vn(wp.xz * 0.07 + vec2(13.0, 2.0));
		float wb = smoothstep(0.5, 0.75, nb);
		vec3 tb = texture(g_tex_b, uv * 1.13 + 0.37).rgb;
		c = mix(c, pal * vec3(0.84, 0.9, 0.95) * mix(1.0, lum3(tb) / 0.098, 0.75), wb * 0.7);
		float wc = smoothstep(0.72, 0.86, vn(wp.xz * 0.09 + vec2(41.0, 5.0))) * 0.8;
		if (wc > 0.0) {
			vec3 tc = texture(g_clover, uv * 0.9).rgb;
			c = mix(c, pal * mix(1.0, lum3(tc) / 0.158, 0.55) * vec3(0.95, 1.06, 0.9), wc);
		}
		float wf = smoothstep(0.74, 0.86, vn(wp.xz * 0.055 + vec2(77.0, 19.0)));
		if (wf > 0.0) {
			vec3 tf = texture(g_flower, uv * 0.8).rgb;
			float fm = smoothstep(0.08, 0.25, tf.r - tf.g * 0.75);
			c = mix(c, mix(pal * mix(1.0, lum3(tf) / 0.17, 0.6), tf * vec3(1.0, 0.86, 0.6), fm), wf);
		}
		float wm = (1.0 - smoothstep(1.32, 1.9, wp.y)) * 0.75;
		if (wm > 0.0) {
			vec3 tm = texture(g_moss, uv * 0.7).rgb;
			c = mix(c, pal * vec3(0.78, 0.95, 0.75) * mix(1.0, lum3(tm) / 0.085, 0.6), wm);
		}
	}
	c *= 0.95 + 0.1 * r;
	// чужая земля — как у Land.chunk_mesh: 18% к Land.LOCK в sRGB (в линейных цветах та же доля дала бы белёсую траву)
	if (lk > 0.0) c = pow(mix(pow(c, vec3(1.0 / 2.2)), pow(lock_c, vec3(1.0 / 2.2)), 0.18 * lk), vec3(2.2));
	return c;
}

// Пятна травы за краем карты — как Land.tint: шум по клеткам 25 см, 4 оттенка (доли как на карте: 4/44/46/5 %)
vec3 far_grass(vec3 wp) {
	vec2 q = (floor(wp.xz * 4.0) + 0.5) * 0.045;
	float n = (vn(q) * 4.0 + vn(q * 2.0 + vec2(17.3, 5.1)) * 2.0 + vn(q * 4.0 + vec2(3.7, 11.9))) / 7.0;
	n = 0.5 + (n - 0.5) * 1.08;
	return n < 0.25 ? far_g0 : (n < 0.5 ? far_g1 : (n < 0.75 ? far_g2 : far_g3));
}

void fragment() {
	vec3 base = COLOR.rgb;               // вершинный цвет: оттенок клетки (у чужой земли приглушён)
	float k = floor(kind + 0.5);
	bool far = k > 7.5;
	float fv = wpos.y / 0.125 + 0.5;          // для горизонталей за краем карты (производная — вне ветвлений)
	float fw = max(fwidth(fv), 1e-4);
	float dmap = 0.0;
	if (far) {
		// за краем карты: вблизи — пятна клетками, как на карте; вдали — крупные пятна из вершинного цвета
		vec2 dd = max(max(-wpos.xz, wpos.xz - vec2(map_size)), vec2(0.0));
		dmap = length(dd);
		base = mix(far_grass(wpos), base, smoothstep(90.0, 420.0, dmap));
		k = 0.0;
	}
	vec3 an = abs(wnrm);
	bool top = an.y > 0.5;
	vec3 cube = floor(wpos * 8.0 - wnrm * 0.5);
	float r = h31(cube);
	float rough = 0.95;
	bool mg = meadow_on && (k == 0.0 || k == 1.0 || k == 4.0 || k == 5.0);
	if (mg) {
		// чужая земля: вершинный цвет приглушён к Land.LOCK — синего к зелёному у него больше (≥ 0,26 против ≤ 0,18 у травы)
		float lk = far ? 1.0 : step(0.22, COLOR.b / max(COLOR.g, 1e-3));
		vec3 mgc = meadow_grass(wpos, lk, r);
		base = far ? mix(mgc, base, smoothstep(90.0, 420.0, dmap)) : mgc;
	}
	vec3 c = base;
	if (top) {
		if (k == 6.0) {
			// утоптанная земля под домами и во дворах
			c = base * (0.85 + 0.2 * vn(wpos.xz * 2.0)) * (0.94 + 0.08 * r);
		} else if (k == 7.0) {
			// пашня: борозды
			float rows = 0.5 + 0.5 * sin(wpos.x * 6.2832 / 0.75);
			c = base * (0.8 + 0.3 * rows) * (0.94 + 0.08 * r);
		} else if (mg) {
			// трава набора — уже в base (meadow_grass); редкие сухие травинки и тёмные кочки по кубикам, как в Town to City
			float s = h31(cube + 17.0);
			if (s > 0.9985) c = mix(c, vec3(0.74, 0.68, 0.42), 0.2);
			if (s < 0.01) c *= 0.85;
		} else if (k == 0.0 || k == 1.0 || k == 4.0 || k == 5.0) {
			// трава под всем: крупные пятна светлее и темнее, у каждого кубика свой тон, редкие светлые травинки
			float big = vn(wpos.xz * 0.06) * 0.55 + vn(wpos.xz * 0.21) * 0.45;
			c = base * (0.8 + 0.34 * big);
			// «щетина» как в Town to City: у каждого кубика свой тон, кое-где сухие травинки и тёмные кочки
			c *= 0.86 + 0.24 * r;
			float s = h31(cube + 17.0);
			if (s > 0.99) c = mix(c, vec3(0.74, 0.68, 0.42), 0.3);
			if (s < 0.025) c *= 0.72;
			// редкие крошечные цветочки
			float fl = h31(cube + 41.0);
			if (fl > 0.9985) c = fl > 0.9995 ? vec3(0.9, 0.86, 0.74) : vec3(0.8, 0.4, 0.46);
		} else {
			c *= 0.92 + 0.12 * r;
		}
		if (k == 0.0 || k == 1.0 || k == 4.0 || k == 5.0 || k == 6.0) {
			// покрытия по маске с плавной выборкой — края скруглены, а не ступеньками по клеткам
			vec4 m = textureLod(surf, wpos.xz / map_size, 0.7);   // размытая маска: плавные края без ступенек
			if (far) {
				// за краем карты маски нет: большая дорога уходит на север прямо за горизонт (края — как у маски)
				float rd = abs(wpos.x - far_road_x);
				m = vec4(wpos.z < 0.0 ? clamp(0.5 + (far_road_half - rd) / 1.6, 0.0, 1.0) : 0.0, 0.0, 0.0, 1.0);
			}
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
					float gn = vn(wpos.xz * 1.5) * 0.6 + vn(wpos.xz * 5.5) * 0.4;
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
					vec3 gc = (lush * g2.r + mead * g2.g + sand * g2.b + earth * g2.a + grav * g3.r) / gs;
					c = mix(c, gc, gw);
					rough = mix(rough, 1.0, gw * (g2.b + g2.a + g3.r) / gs);
				}
			}
			float w_path = smoothstep(0.28, 0.6, m.b + wob * 0.35);
			float w_road = smoothstep(0.44, 0.54, m.r + wob * 0.06);
			float w_plaza = smoothstep(0.44, 0.54, m.g + wob * 0.04);
			float edge = smoothstep(0.18, 0.42, max(m.r, m.g)) * (1.0 - max(w_road, w_plaza));
			if (meadow_on) {
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
				if (meadow_on) {
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
				if (meadow_on) {
					// тропа — утоптанная земля с камешками и трещинами (набор Meadow), тёплая, по краю — мелкий гравий
					p = texture(path_tex, wpos.xz / 3.2).rgb * vec3(1.3, 1.08, 0.78) * (0.92 + 0.14 * n);
					vec3 gp = texture(gravel_tex, wpos.xz / 2.0).rgb * vec3(1.0, 0.93, 0.82);
					p = mix(gp, p, smoothstep(0.35, 0.75, m.b + wob * 0.3));
				}
				c = mix(c, p, w_path);
			}
			if (w_road > 0.0) {
				// дорога: каменная плитка Synty, у края темнее — бордюр
				vec3 t = texture(tile_road, wpos.xz / road_scale).rgb;
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
		if (far) {
			// горизонтали там, где на карте уступы по 12,5 см (высота (n + ½)·0,125): тонкие тёмные линии,
			// вдали, где они сливаются, — гаснут
			float line = (1.0 - smoothstep(0.0, fw * 1.4, fract(fv))) * (1.0 - smoothstep(0.3, 0.8, fw));
			c *= 1.0 - 0.45 * line;
		}
	} else if (k == 2.0) {
		// обрыв: слои камня по высоте
		float band = 0.5 + 0.5 * sin(wpos.y * 3.1 + sin(wpos.y * 1.3 + wpos.x * 0.05) * 1.5);
		float fine = vn(vec2(wpos.x * 0.7 + wpos.z * 0.7, wpos.y * 6.0));
		c = mix(c * vec3(1.03, 1.0, 0.97), c * vec3(0.8, 0.76, 0.72), band * 0.75);
		c *= 0.88 + 0.2 * fine;
		c *= 0.93 + 0.1 * r;
	} else if (k == 1.0) {
		// стенка уступа: сверху кромка травы, ниже земля
		vec3 dirt = vec3(0.34, 0.25, 0.14) * (0.9 + 0.2 * r);
		if (meadow_on) {
			// уступ в одну ступеньку (12,5 см) — весь травяной, чуть темнее верха: склон читается ровными горизонталями,
			// а не тёмными лесенками; выше — земля из набора (по стенке, а не сверху)
			vec2 wuv = (an.x > an.z ? wpos.zy : wpos.xy) / 2.0;
			vec3 et = texture(earth_tex, wuv).rgb * vec3(1.05, 0.92, 0.78);
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
	if (meadow_on && top && k == 3.0) {
		// берег прудов и ручьёв: земля и мелкий гравий набора, у воды мокрее; кверху — в траву (без резкой границы)
		vec3 sd = texture(earth_tex, wpos.xz / 2.4).rgb * vec3(1.18, 1.06, 0.86);
		vec3 gw = texture(gravel_tex, wpos.xz / 1.8).rgb * vec3(0.95, 0.92, 0.86);
		sd = mix(sd, gw, smoothstep(0.55, 0.8, vn(wpos.xz * 0.6)) * 0.6);
		sd *= mix(0.72, 1.0, smoothstep(1.02, 1.14, wpos.y));
		vec3 gr2 = meadow_grass(wpos, 0.0, r) * 0.92;
		c = mix(sd, gr2, smoothstep(1.16, 1.3, wpos.y) * 0.7) * (0.95 + 0.1 * r);
		rough = 0.9;
	}
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
	ROUGHNESS = mix(rough, 0.32, wet);
	SPECULAR = mix(0.3, 0.55, wet);
}
