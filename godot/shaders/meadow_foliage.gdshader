// Листва и трава набора Synty Meadow Forest (scripts/meadow.gd). В наборе свой шейдер ветра для Unity — здесь свой:
// цвет вершин набора: B — лист (1) или ствол (0), G — насколько качается (у кончиков травинок и веток 1), R — сдвиг фазы.
// Лист — картинка листвы с прозрачностью (alpha scissor), ствол — общая палитра набора. Качание — в вершинах, лёгкое
// (несколько сантиметров), у каждого дерева своя фаза (по месту в мире — у MultiMesh тоже). Нормаль листа наполовину
// смотрит вверх: крона и трава светятся ровно, без чёрных изнанок карточек. Времена года — как у shaders/foliage.gdshader.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_lambert_wrap, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;   // ствол (палитра набора)
uniform sampler2D leaf_tex : source_color, filter_linear_mipmap, repeat_enable;     // лист / травинки / цветы
uniform bool leaf_only = false;       // вся поверхность — лист (трава, цветы, ветки)
uniform bool leaf_cut = true;         // лист с прозрачностью (у палитры — нет)
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 trunk_tint : source_color = vec4(1.0);
uniform float up_normal = 0.45;
uniform float sway = 0.035;
uniform vec4 season = vec4(0.0);
uniform bool evergreen = false;
uniform bool bloom_ok = false;        // фруктовые деревья весной в цвету
uniform vec3 leaf_gain = vec3(1.0);   // картинки листвы набора разной яркости (у луговых деревьев почти чёрная) — к одной
uniform float fmode = 100.0;          // цвет цветов (flower_recolor): 100 — как в картинке набора; 0…5 — один цвет
uniform vec2 fade = vec2(0.0);        // мелочь лугов: от fade.x до fade.y м от камеры каждая травинка уменьшается до нуля

varying float leaf;
varying float th;
varying vec3 wp;

void vertex() {
	leaf = leaf_only ? 1.0 : step(0.5, COLOR.b);
	vec3 o = MODEL_MATRIX[3].xyz;
	if (fade.y > 0.0) {
		// гаснет каждая травинка по своему расстоянию — без прямоугольников кусков на границе дальности
		VERTEX *= 1.0 - smoothstep(fade.x, fade.y, distance(o, CAMERA_POSITION_WORLD));
	}
	th = fract(sin(dot(floor(o.xz * 3.0), vec2(12.9898, 78.233))) * 43758.5453);
	float w = COLOR.g;
	if (w > 0.001 && sway > 0.0) {
		float ph = dot(o.xz, vec2(0.37, 0.23)) + COLOR.r * 6.2832;
		float t = TIME;
		float gust = 0.65 + 0.35 * sin(t * 0.31 + o.x * 0.02 + o.z * 0.013);
		VERTEX.x += sin(t * 1.35 + ph) * sway * w * gust;
		VERTEX.z += sin(t * 1.05 + ph * 1.7) * sway * w * gust * 0.6;
		VERTEX.y += sin(t * 3.7 + ph * 2.3 + VERTEX.x * 3.0) * sway * 0.25 * w * leaf;
	}
	if (leaf > 0.5) {
		NORMAL = normalize(mix(NORMAL, vec3(0.0, 1.0, 0.0), up_normal));
	}
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Цвет цветка (15.11, владелец: больше белых и розовых, меньше оранжевых и красных; свой цвет цветов в «Природе»):
// fmode < 0 — как в наборе, но тёплые цветки (красные, оранжевые) чаще становятся белыми и розовыми, по случаю r;
// 0…5 — один цвет: белый, розовый, красный, жёлтый, сиреневый, синий; ≥ 100 — как в картинке набора (пёстрые)
vec3 f_hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1.0e-10)), d / (q.x + 1.0e-10), q.x);
}

vec3 f_swatch(int k) {
	if (k == 0) return vec3(0.96, 0.95, 0.9);
	if (k == 1) return vec3(0.93, 0.48, 0.68);
	if (k == 2) return vec3(0.78, 0.09, 0.09);
	if (k == 3) return vec3(1.0, 0.82, 0.16);
	if (k == 4) return vec3(0.52, 0.27, 0.78);
	return vec3(0.2, 0.38, 0.9);
}

vec3 flower_recolor(vec3 c, float fm, float r) {
	if (fm >= 99.0) return c;
	vec3 h = f_hsv(c);
	float green = step(0.17, h.x) * step(h.x, 0.47);
	float bloom = smoothstep(0.08, 0.22, h.y) * (1.0 - green) * smoothstep(0.1, 0.3, h.z);   // лепесток: цветной, не зелёный (стебли и листья — нет)
	bool blue = h.x > 0.5 && h.x < 0.75;
	bool pink = h.x > 0.88 && h.x < 0.97;
	int k = int(fm + 0.5);
	if (fm < 0.0) {
		if (blue) return c;
		if (pink) {
			k = r < 0.45 ? 0 : 1;                        // розовые — наполовину белыми
		} else {
			k = r < 0.4 ? 0 : (r < 0.78 ? 1 : (r < 0.9 ? 3 : 5));       // красные и оранжевые: белые, розовые, чуть жёлтых и синих
		}
	}
	vec3 t = f_swatch(k) * clamp(0.5 + 0.7 * h.z, 0.62, 1.1);
	return mix(c, t, bloom);
}

float lum(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

void fragment() {
	vec3 c;
	float a = 1.0;
	if (leaf > 0.5) {
		vec4 t = texture(leaf_tex, UV);
		vec3 tc = fmode < 99.0 ? flower_recolor(t.rgb, fmode, th) : t.rgb;
		c = tc * leaf_gain * tint.rgb * (0.92 + 0.16 * th);
		if (leaf_cut) a = t.a;
	} else {
		c = texture(albedo_tex, UV).rgb * trunk_tint.rgb;
	}
	if (season != vec4(0.0) && leaf > 0.5) {
		float l = lum(c);
		vec3 t = c;
		vec3 au = (th < 0.12 || evergreen) ? c : (th < 0.5 ? vec3(1.0, 0.66, 0.12) : (th < 0.8 ? vec3(1.0, 0.38, 0.07) : vec3(0.8, 0.15, 0.05)));
		au *= l / max(lum(au), 1e-3) * (evergreen ? 1.0 : 1.15);
		if (evergreen) au = mix(c, vec3(l * 1.45, l * 1.08, l * 0.36), 0.5);     // трава осенью золотится
		t = mix(t, au, season.x);
		vec3 dry = vec3(0.62, 0.47, 0.26);
		vec3 wi = (th < 0.35 || evergreen) ? c * vec3(0.8, 0.86, 0.84) : dry * (l * 0.85 / lum(dry));
		t = mix(t, wi, season.y);
		float spot = fract(sin(dot(floor(wp * 14.0), vec3(12.99, 78.23, 37.71))) * 43758.55);
		float bloom = bloom_ok ? step(0.3, th) : 0.0;
		vec3 bl = mix(vec3(0.95, 0.42, 0.6), vec3(1.0, 0.82, 0.88), fract(th * 7.0)) * max(l * 2.4, 0.2) * (0.88 + 0.24 * spot);
		t = mix(t, mix(t * vec3(0.95, 1.07, 0.9), bl, bloom * 0.85), season.z);
		c = t;
	}
	ALBEDO = c;
	if (leaf > 0.5) {
		BACKLIGHT = c * 0.45;                 // свет сквозь листву: теневая сторона кроны не чернеет
	}
	ALPHA = a;
	ALPHA_SCISSOR_THRESHOLD = 0.4;
	ROUGHNESS = 0.9;
	SPECULAR = 0.25;
}
