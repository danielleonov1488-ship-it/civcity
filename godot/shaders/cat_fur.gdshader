// Шерсть кошки (People._cat_mesh_v2): окрас по месту на теле в позе покоя (UV — x,z, UV2.x — y в осях модели),
// а не по экрану — полоски не «плывут», когда кошка идёт. COLOR.r — часть тела: 0 шерсть, 0.25 грудка и лапки,
// 0.5 уши и нос, 0.75 глаз (UV2.y и CUSTOM нет — у глаза свои координаты в UV: −1…1 по ширине и высоте).
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 fur : source_color = vec3(0.88, 0.57, 0.25);
uniform vec3 belly : source_color = vec3(0.96, 0.86, 0.7);
uniform vec3 mark : source_color = vec3(0.6, 0.32, 0.12);     // полоски и пятна
uniform int pattern = 1;       // 0 — гладкая, 1 — тигровая (полоски), 2 — «во фраке» (белые грудь, лапы, мордочка), 3 — пятна
uniform vec3 eye_col : source_color = vec3(0.55, 0.62, 0.18);
uniform float sleep = 0.0;     // 1 — глаза закрыты (спит)
uniform float blink_ph = 0.0;  // сдвиг моргания (кошки моргают не в лад)
uniform vec2 body_x = vec2(-0.0244, 0.0323);   // от кончика хвоста до носа (ед. модели)
uniform vec2 body_z = vec2(0.0, 0.0343);       // от земли до макушки

varying vec3 rp;
varying float part;
varying vec2 euv;

float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	part = COLOR.r;
	rp = vec3(UV.x, UV2.x, UV.y);
	euv = UV;
}

void fragment() {
	float u = clamp((rp.x - body_x.x) / (body_x.y - body_x.x), 0.0, 1.0);   // 0 хвост … 1 нос
	float v = clamp((rp.z - body_z.x) / (body_z.y - body_z.x), 0.0, 1.0);   // 0 лапы … 1 макушка
	float s = rp.y / 0.006;                                                  // бок: −1 … 1
	vec3 c = fur;
	float rough = 0.85;
	if (part > 0.62) {
		// глаз: радужка цвета глаз, зрачок-щёлочка, блик; моргает веком (цвет шерсти), спит — закрыт
		vec2 e = euv;
		float iris = 1.0 - smoothstep(0.82, 0.95, length(e));
		vec3 col = mix(vec3(0.08, 0.07, 0.06), eye_col, iris);
		float pupil = 1.0 - smoothstep(0.85, 1.0, length(vec2(e.x * 3.2, e.y * 1.05)));
		col = mix(col, vec3(0.02), pupil);
		float gl = 1.0 - smoothstep(0.12, 0.2, length(e - vec2(-0.32, 0.36)));
		col = mix(col, vec3(1.0), gl * 0.9);
		float t = fract(TIME * 0.21 + blink_ph);
		float bl = smoothstep(0.0, 0.025, t) * (1.0 - smoothstep(0.03, 0.06, t));   // мигнула раз в ~5 с
		float closed = max(sleep, bl);
		float lid = step(1.0 - 2.1 * closed, e.y);
		col = mix(col, fur * 0.92, lid);
		if (sleep > 0.5) col = mix(fur * 0.92, vec3(0.1, 0.08, 0.07), 1.0 - smoothstep(0.06, 0.16, abs(e.y + 0.1)));
		c = col;
		rough = mix(0.25, 0.85, lid);
	} else if (part > 0.37) {
		c = vec3(0.89, 0.62, 0.62);                                         // розовые уши и нос
	} else {
		bool white = part > 0.12;
		float n = vn(rp.xz * 260.0) * 0.7 + vn(rp.xz * 620.0) * 0.3;
		if (pattern == 1 && !white) {
			// тигровая: полосы поперёк спины и боков, кольца на хвосте и лапах, «М» на лбу, тёмная полоса по хребту
			float t;
			if (v < 0.42 && u > 0.12) t = v * 13.0;                          // лапы — кольца
			else t = u * 14.0 + (n - 0.5) * 0.7 + abs(s) * 0.5;
			float band = smoothstep(0.6, 0.72, 0.5 + 0.5 * sin(t * 6.2832));
			band *= smoothstep(0.25, 0.55, v + 0.15 * (1.0 - abs(s)));       // снизу (живот) полос нет
			band *= 1.0 - smoothstep(0.78, 0.84, u) * (1.0 - smoothstep(0.8, 0.9, v) * step(abs(s), 0.5));   // на морде — нет, на лбу — «М»
			float spine = (1.0 - smoothstep(0.18, 0.45, abs(s))) * smoothstep(0.6, 0.8, v) * step(u, 0.83);
			c = mix(c, mark, max(band, spine * 0.8));
		} else if (pattern == 3 && !white) {
			float sp = smoothstep(0.62, 0.7, vn(rp.xz * 260.0 + vec2(rp.y * 300.0)));
			c = mix(c, mark, sp);
		}
		if (white) {
			c = belly;
		} else {
			// бока к животу светлее, спина темнее (как у настоящих кошек)
			c = mix(c, belly, (1.0 - smoothstep(0.18, 0.42, v)) * 0.45 * step(0.12, u));
			if (pattern == 2) c = mix(c, belly, (1.0 - smoothstep(0.24, 0.3, v)) * step(0.15, u));   // «фрак»: белые живот и лапы
			c *= 0.95 + 0.08 * n;
		}
	}
	ALBEDO = c;
	ROUGHNESS = rough;
	SPECULAR = 0.35;
}
