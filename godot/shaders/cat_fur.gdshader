// Шерсть кошки «Kitten» (People._cat_build): окрас по месту на теле в позе покоя (UV — x,z, UV2.x — y в осях скелета),
// а не по экрану — полоски не «плывут», когда кошка идёт. COLOR.r — часть тела: 0 шерсть, 0.25 светлые грудка, живот,
// лапки и мордочка, 0.5 розовые уши изнутри и нос, 0.75 глаз (у глаза свои координаты в UV: −1…1 по ширине и высоте);
// COLOR.g — «маска» сиамской (0.5 мордочка, уши, лапки; 1 — хвост, нос, уши изнутри); COLOR.b — где на теле
// (0 туловище, 0.25 лапа, 0.5 голова, 0.75 хвост).
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 fur : source_color = vec3(0.88, 0.57, 0.25);
uniform vec3 belly : source_color = vec3(0.96, 0.86, 0.7);
uniform vec3 mark : source_color = vec3(0.6, 0.32, 0.12);     // полоски и пятна; у сиамской — «маска»
uniform int pattern = 1;       // 0 — гладкая, 1 — тигровая (полоски), 2 — «во фраке» (белые грудь, лапы, мордочка), 3 — пятна, 4 — сиамская
uniform vec3 eye_col : source_color = vec3(0.55, 0.62, 0.18);
uniform float sleep = 0.0;     // 1 — глаза закрыты (спит)
uniform float blink_ph = 0.0;  // сдвиг моргания (кошки моргают не в лад)
uniform float sheen = 0.0;     // голубоватый отлив по краю (чёрная Мася: видно в тени и на мостовой); 0 — нет
uniform vec3 sheen_col : source_color = vec3(0.62, 0.68, 0.86);
uniform vec2 body_x = vec2(-0.0245, 0.0284);   // от крупа до носа (ед. скелета)
uniform vec2 body_z = vec2(0.0, 0.0473);       // от земли до макушки
uniform float half_w = 0.0074;                 // полуширина туловища

varying vec3 rp;
varying float part;
varying float pts;
varying float reg;
varying vec2 euv;

float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	part = COLOR.r;
	pts = COLOR.g;
	reg = COLOR.b;
	rp = vec3(UV.x, UV2.x, UV.y);
	euv = UV;
}

void fragment() {
	float u = clamp((rp.x - body_x.x) / (body_x.y - body_x.x), 0.0, 1.0);   // 0 круп … 1 нос
	float v = clamp((rp.z - body_z.x) / (body_z.y - body_z.x), 0.0, 1.0);   // 0 лапы … 1 макушка
	float s = clamp(rp.y / half_w, -1.0, 1.0);                              // бок: −1 … 1
	bool leg = reg > 0.12 && reg < 0.37;
	bool head = reg > 0.37 && reg < 0.62;
	bool tail = reg > 0.62;
	vec3 c = fur;
	float rough = 0.85;
	float n = vn(rp.xz * 260.0 + vec2(rp.y * 90.0)) * 0.7 + vn(rp.xz * 620.0) * 0.3;
	if (part > 0.62) {
		// глаз: радужка цвета глаз, зрачок-щёлочка, блик; моргает веком (цвет шерсти), спит — закрыт
		vec2 e = euv;
		float iris = 1.0 - smoothstep(0.86, 1.0, length(e));
		vec3 col = mix(vec3(0.08, 0.07, 0.06), eye_col, iris);
		float pupil = 1.0 - smoothstep(0.8, 1.0, length(vec2(e.x * 3.4, e.y * 1.05)));
		col = mix(col, vec3(0.02), pupil);
		float gl = 1.0 - smoothstep(0.14, 0.24, length(e - vec2(-0.3, 0.34)));
		col = mix(col, vec3(1.0), gl * 0.9);
		float t = fract(TIME * 0.21 + blink_ph);
		float bl = smoothstep(0.0, 0.025, t) * (1.0 - smoothstep(0.03, 0.06, t));   // мигнула раз в ~5 с
		float closed = max(sleep, bl);
		vec3 lidc = (pattern == 4) ? mark : fur * 0.92;
		float lid = step(1.0 - 2.1 * closed, e.y);
		col = mix(col, lidc, lid);
		if (sleep > 0.5) col = mix(lidc, vec3(0.1, 0.08, 0.07), 1.0 - smoothstep(0.08, 0.2, abs(e.y + 0.1)));
		c = col;
		rough = mix(0.25, 0.85, lid);
	} else if (pattern == 4 && pts > 0.25) {
		// сиамская: «маска» — мордочка, уши, лапки; хвост, нос и уши изнутри темнее
		c = (pts > 0.75 ? mark * 0.57 : mark) * (0.96 + 0.06 * n);
	} else if (part > 0.37) {
		c = vec3(0.89, 0.62, 0.62);                                         // розовые уши изнутри и нос
	} else {
		bool white = part > 0.12;
		if (pattern == 1 && !white) {
			// тигровая: полосы поперёк спины и боков, кольца на лапах и хвосте, «М» на лбу, тёмная полоса по хребту
			float t;
			float band;
			if (leg) {
				t = v * 15.0;
				band = smoothstep(0.62, 0.74, 0.5 + 0.5 * sin(t * 6.2832)) * smoothstep(0.06, 0.12, v);
			} else if (tail) {
				t = rp.z / 0.0052;
				band = smoothstep(0.55, 0.7, 0.5 + 0.5 * sin(t * 6.2832));
			} else if (head) {
				// лоб — «М» (полоски вдоль головы), щёки и затылок — полосы назад, мордочка ниже глаз — без полос
				float fore = smoothstep(0.8, 0.86, v) * smoothstep(0.82, 0.87, u);
				float mm = smoothstep(0.6, 0.78, 0.5 + 0.5 * cos(rp.y / half_w * 15.0)) * fore * (1.0 - step(0.5, abs(s)));
				t = u * 15.0 + (n - 0.5) * 0.5 + v * 3.0;
				float cheek = smoothstep(0.62, 0.74, 0.5 + 0.5 * sin(t * 6.2832)) * (1.0 - fore) * smoothstep(0.62, 0.7, v)
					* (1.0 - smoothstep(0.9, 0.95, u) * (1.0 - step(0.35, abs(s))));
				band = max(mm, cheek);
			} else {
				t = u * 14.0 + (n - 0.5) * 0.7 + abs(s) * 0.5;
				band = smoothstep(0.6, 0.72, 0.5 + 0.5 * sin(t * 6.2832));
				band *= smoothstep(0.45, 0.62, v + 0.12 * (1.0 - abs(s)));   // снизу (живот) полос нет
			}
			float spine = (head || leg) ? 0.0 : (1.0 - smoothstep(0.18, 0.45, abs(s))) * smoothstep(0.72, 0.84, v);
			c = mix(c, mark, max(band, spine * 0.8));
		} else if (pattern == 3 && !white) {
			float sp = smoothstep(0.62, 0.7, vn(rp.xz * 260.0 + vec2(rp.y * 300.0)));
			c = mix(c, mark, sp);
		}
		if (white) {
			c = belly;
		} else {
			// бока к животу светлее, спина темнее (как у настоящих кошек)
			if (!leg && !tail) c = mix(c, belly, (1.0 - smoothstep(0.42, 0.56, v)) * 0.45);
			// «фрак»: белые грудка, лапы «в носочках»
			if (pattern == 2) {
				float bib = (!head && !tail) ? step(0.7, u) * (1.0 - smoothstep(0.55, 0.6, v)) * (1.0 - step(0.75, abs(s))) : 0.0;
				float sock = leg ? 1.0 - smoothstep(0.2, 0.24, v) : 0.0;
				c = mix(c, belly, max(bib, sock));
			}
			c *= 0.95 + 0.08 * n;
		}
	}
	ALBEDO = c;
	if (sheen > 0.0 && part < 0.37) {
		// отлив: светится только край силуэта (как блеск чёрной шерсти), середина, уши и нос — как были. Грани «Kitten»
		// крупные: степень 4, чтобы светились края, а не целые грани вполоборота
		float fr = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
		EMISSION = sheen_col * fr * sheen;
	}
	ROUGHNESS = rough;
	SPECULAR = 0.35;
}
