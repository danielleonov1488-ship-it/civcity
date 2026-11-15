// Трава-ковёр (scripts/grass_carpet.gd): густые кустики травы и полевые цветы набора Synty Meadow Forest кусками
// MultiMesh. Цвет травы — от тёмного у корня к светлому жёлто-зелёному на кончиках (как на картинке набора), узор —
// яркость картинки травы. Цветы — картинки из массива (у каждого кустика своя). Качание по ветру — в вершинах (цвет
// вершин набора: G — насколько качается, у кончиков 1). Вдали каждый кустик уменьшается до нуля сам (fade) —
// куски не обрываются прямоугольниками. Без теней.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_lambert_wrap, specular_disabled;

uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2DArray tex_arr : source_color, filter_linear_mipmap, repeat_enable;
uniform bool flowers = false;
uniform vec3 root_col : source_color = vec3(0.16, 0.3, 0.05);
uniform vec3 tip_col : source_color = vec3(0.62, 0.78, 0.22);
uniform float tex_avg = 0.16;          // средняя яркость картинки травы (линейная) — узор вокруг 1
uniform vec2 fade = vec2(60.0, 90.0);
uniform float sway = 0.07;
uniform float fmode = -1.0;              // цвет цветов (flower_recolor): -1 — свой набор «больше белых и розовых»
uniform vec4 season = vec4(0.0);

varying float vh;
varying vec4 ic;

void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;
	ic = INSTANCE_CUSTOM;
	vh = clamp(COLOR.g, 0.0, 1.0);
	float d = distance(o, CAMERA_POSITION_WORLD);
	float f = 1.0 - smoothstep(fade.x, fade.y, d);
	if (f < 0.001) {
		VERTEX = vec3(0.0);
	} else {
		float ph = ic.g * 6.2832 + dot(o.xz, vec2(0.21, 0.13));
		float gust = 0.6 + 0.4 * sin(TIME * 0.37 + o.x * 0.023 + o.z * 0.017);
		VERTEX.x += sin(TIME * 1.6 + ph) * sway * vh * gust;
		VERTEX.z += sin(TIME * 1.2 + ph * 1.3) * sway * 0.6 * vh * gust;
		VERTEX *= f;
	}
	NORMAL = normalize(mix(NORMAL, vec3(0.0, 1.0, 0.0), 0.8));
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

float lum(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }

void fragment() {
	vec4 t;
	vec3 c;
	if (flowers) {
		t = texture(tex_arr, vec3(UV, floor(ic.b * 2.999)));
		c = flower_recolor(t.rgb, fmode, ic.r);
		// стебли и листья цветов — в тон траве
		float leaf = smoothstep(-0.02, 0.06, t.g - max(t.r, t.b));
		vec3 g = mix(root_col, tip_col, vh * 0.8) * (lum(t.rgb) / 0.16);
		c = mix(c * vec3(1.06, 1.04, 1.0), g, leaf * 0.7);
	} else {
		t = texture(tex, UV);
		c = mix(root_col, tip_col, smoothstep(0.0, 1.0, vh)) * mix(1.0, lum(t.rgb) / tex_avg, 0.45);
		c *= 0.88 + 0.24 * ic.r;             // у каждого кустика свой тон
	}
	if (season != vec4(0.0) && !flowers) {
		float l = lum(c);
		c = mix(c, vec3(l * 1.45, l * 1.08, l * 0.36), season.x * 0.5);
		c = mix(c, mix(vec3(l * 1.05), c, 0.4) * vec3(0.97, 1.0, 1.02), season.y * 0.65);
		c = mix(c, c * vec3(0.94, 1.08, 0.9), season.z);
	}
	ALBEDO = c;
	BACKLIGHT = c * 0.35;
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = 0.45;
	ROUGHNESS = 0.9;
}
