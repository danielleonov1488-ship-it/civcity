// Толпа зрителей (scripts/crowd.gd): сотни людей одним вызовом отрисовки на модель.
// Позы костей заранее «запечены» в картинку bones (на кадр — строка, на кость — три текселя: строки матрицы 3×4),
// вершина сама себя «натягивает» на кости: номера костей — CUSTOM0, веса — CUSTOM1.
// У каждого человека (экземпляра MultiMesh): INSTANCE_CUSTOM = (клип, время начала, прежний клип + доля его круга,
// время смены клипа) — смена клипа плавная, за BLEND с; COLOR = номера цветов в палитре (одежда: основной, второй,
// кайма; волосы) / 255. Время — общее crowd_now (в съёмке ролика его ведёт AnimClock).
// Одежда красится как у жителей (shaders/citizen_cloth.gdshader): те же полосы атласа Synty.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

global uniform float crowd_now;

uniform sampler2D bones : filter_nearest, repeat_disable;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D palette : filter_nearest, repeat_disable;
uniform vec4 clips[24];          // x — первая строка клипа, y — кадров, z — петля (1) или раз (0), w — кадров в секунду
uniform int mode = 0;            // 0 — тело (атлас и ткани), 1 — атлас как есть, 2 — ровный цвет волос из палитры
uniform int mask_main = 0;
uniform int mask_second = 0;
uniform int mask_trim = 0;
uniform float rough = 0.85;
uniform float blend_time = 0.35;

varying flat vec3 v_main;
varying flat vec3 v_second;
varying flat vec3 v_trim;
varying flat vec3 v_hair;

const vec3 LUM = vec3(0.2126, 0.7152, 0.0722);

mat4 bone_at(int b, int row) {
	vec4 r0 = texelFetch(bones, ivec2(b * 3, row), 0);
	vec4 r1 = texelFetch(bones, ivec2(b * 3 + 1, row), 0);
	vec4 r2 = texelFetch(bones, ivec2(b * 3 + 2, row), 0);
	return mat4(vec4(r0.x, r1.x, r2.x, 0.0), vec4(r0.y, r1.y, r2.y, 0.0), vec4(r0.z, r1.z, r2.z, 0.0), vec4(r0.w, r1.w, r2.w, 1.0));
}

// Матрица вершины в кадре f клипа c (f — дробный номер кадра, между кадрами — смесь)
mat4 skin_at(ivec4 bi, vec4 bw, int c, float f) {
	vec4 cl = clips[c];
	int n = int(cl.y);
	int f0 = int(floor(f));
	float fr = f - float(f0);
	int f1 = f0 + 1;
	if (cl.z > 0.5) {
		f0 = f0 % n;
		f1 = f1 % n;
	} else {
		f0 = min(f0, n - 1);
		f1 = min(f1, n - 1);
	}
	int r0 = int(cl.x) + f0;
	int r1 = int(cl.x) + f1;
	mat4 m = mat4(0.0);
	for (int k = 0; k < 4; k++) {
		if (bw[k] > 0.0) {
			m += (bone_at(bi[k], r0) * (1.0 - fr) + bone_at(bi[k], r1) * fr) * bw[k];
		}
	}
	return m;
}

// Номер кадра клипа c через t секунд от начала (петля — по кругу, разовый — стоит на последнем)
float frame_of(int c, float t) {
	vec4 cl = clips[c];
	float f = max(t, 0.0) * cl.w;
	if (cl.z > 0.5) {
		return mod(f, cl.y);
	}
	return min(f, cl.y - 1.0);
}

void vertex() {
	ivec4 bi = ivec4(CUSTOM0 + 0.5);
	vec4 bw = CUSTOM1;
	int c = int(INSTANCE_CUSTOM.x + 0.5);
	float t0 = INSTANCE_CUSTOM.y;
	mat4 m = skin_at(bi, bw, c, frame_of(c, crowd_now - t0));
	float w = clamp((crowd_now - INSTANCE_CUSTOM.w) / blend_time, 0.0, 1.0);
	if (w < 1.0) {
		int pc = int(floor(INSTANCE_CUSTOM.z));
		float ph = fract(INSTANCE_CUSTOM.z);
		vec4 pcl = clips[pc];
		float pt = ph * pcl.y / pcl.w + (crowd_now - INSTANCE_CUSTOM.w);
		mat4 mp = skin_at(bi, bw, pc, frame_of(pc, pt));
		w = w * w * (3.0 - 2.0 * w);
		m = mp * (1.0 - w) + m * w;
	}
	VERTEX = (m * vec4(VERTEX, 1.0)).xyz;
	NORMAL = normalize(mat3(m) * NORMAL);
	ivec4 pi = ivec4(COLOR * 255.0 + 0.5);
	v_main = texelFetch(palette, ivec2(pi.r, 0), 0).rgb;
	v_second = texelFetch(palette, ivec2(pi.g, 0), 0).rgb;
	v_trim = texelFetch(palette, ivec2(pi.b, 0), 0).rgb;
	v_hair = texelFetch(palette, ivec2(pi.a, 0), 0).rgb;
}

void fragment() {
	vec3 c;
	if (mode == 2) {
		c = v_hair;
	} else {
		c = texture(albedo_tex, UV).rgb;
		if (mode == 0 && (mask_main | mask_second | mask_trim) != 0) {
			vec2 p = fract(UV) * 4096.0;                  // PolygonAncientWorlds_Texture_01, 4096²
			int bit = -1;
			float shade = 1.0;
			if (p.x >= 1435.0 && p.x < 2047.0 && p.y >= 3788.0 && p.y < 4032.0) {
				bit = min(int((p.x - 1435.0) / 43.714), 13);
				vec3 top = textureLod(albedo_tex, vec2(1435.0 + (float(bit) + 0.5) * 43.714, 3828.0) / 4096.0, 0.0).rgb;
				shade = dot(c, LUM) / max(dot(top, LUM), 1e-4);
			} else if (p.y >= 4032.0 && p.x >= 1404.0 && p.x < 2044.0) {
				bit = 14 + int((p.x - 1404.0) / 128.0);
			} else if (p.x >= 3840.0 && p.y >= 2878.0 && p.y < 3698.0) {
				bit = 19;
				shade = mix(0.45, 1.0, clamp((dot(c, LUM) - 0.173) / 0.358, 0.0, 1.0));
			}
			if (bit >= 0) {
				int b = 1 << bit;
				if ((mask_main & b) != 0) {
					c = v_main * shade;
				} else if ((mask_second & b) != 0) {
					c = v_second * shade;
				} else if ((mask_trim & b) != 0) {
					c = v_trim * shade;
				}
			}
		}
	}
	ALBEDO = c;
	ROUGHNESS = rough;
}
