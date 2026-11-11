// Вода в бассейнах, фонтанах, корытах (#water в чертежах): живая — бегущая рябь (нормали по сумме волн и шума
// в мировых координатах, у MultiMesh — по месту каждого бассейна), светлые прожилки «каустики», блики.
// Бока коробки — ровные (рябь только сверху). Владелец 12.11: «вода тоже должна быть анимированной».
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx;

uniform vec3 tint : source_color = vec3(0.34, 0.74, 0.78);
uniform vec3 deep : source_color = vec3(0.13, 0.44, 0.54);

varying vec3 wpos;
varying vec3 wnrm;

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vn(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}

float hgt(vec2 p, float t) {
	return sin(p.x * 5.0 + t * 1.6) * 0.5 + sin(p.y * 4.3 - t * 1.3) * 0.5
		+ (vn(p * 3.0 + vec2(t * 0.35, -t * 0.25)) - 0.5) * 1.2 + (vn(p * 7.0 - vec2(t * 0.6, t * 0.4)) - 0.5) * 0.6;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float t = TIME;
	vec2 p = wpos.xz;
	float e = 0.04;
	float h0 = hgt(p, t);
	float hx = hgt(p + vec2(e, 0.0), t);
	float hz = hgt(p + vec2(0.0, e), t);
	vec3 n = normalize(vec3(-(hx - h0) / e * 0.035, 1.0, -(hz - h0) / e * 0.035));
	float top = step(0.7, wnrm.y);
	vec3 nw = normalize(mix(wnrm, n, top));
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	float c = pow(1.0 - abs(sin((vn(p * 2.5 + t * 0.3) + vn(p * 5.0 - t * 0.4)) * 3.14159)), 6.0);
	vec3 col = mix(deep, tint, 0.6 + 0.4 * vn(p * 1.5 + t * 0.1));
	ALBEDO = col + vec3(0.25, 0.3, 0.3) * c * top;
	ALPHA = 0.86;
	ROUGHNESS = 0.06;
	SPECULAR = 0.7;
}
