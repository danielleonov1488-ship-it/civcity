// Цветокоррекция кадра — как в Town to City: тёплые медовые света, прохладные серо-сиреневые тени,
// зелень уходит в оливу и охру, мягкая виньетка. Параметры плавно меняются со временем суток (game.gd).
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform vec3 gain = vec3(1.07, 0.97, 0.84);          // светлое — теплее
uniform vec3 shadow_tint = vec3(0.86, 0.84, 0.95);   // тени — прохладнее
uniform float green_shift = 0.55;                     // зелень → олива
uniform float sat = 1.05;
uniform float contrast = 1.08;
uniform float vignette = 0.45;
uniform vec3 vig_col = vec3(0.52, 0.36, 0.26);
uniform vec3 tint = vec3(1.0);                         // общий оттенок (ночью — сиреневый) и яркость
uniform float warm_keep = 0.0;                         // ночью: тёплый свет фонарей и жаровен не подсинивать

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

void fragment() {
	vec3 c0 = texture(screen_tex, SCREEN_UV).rgb;
	float l0 = max(c0.r, max(c0.g, c0.b));
	// тёплое пятно (красного заметно больше синего) — свет фонаря: его ночной сиреневый оттенок не трогает
	float warm = warm_keep * smoothstep(0.22, 0.55, (c0.r - c0.b) / (l0 + 0.02)) * smoothstep(0.06, 0.25, l0);
	vec3 c = c0 * mix(tint, vec3(1.0), max(smoothstep(0.55, 0.95, l0), warm));
	vec3 h = rgb2hsv(c);
	// зелёные тона (жёлто-зелёный … бирюзовый) тянем к оливе и чуть гасим
	float g = smoothstep(0.11, 0.19, h.x) * (1.0 - smoothstep(0.42, 0.52, h.x));
	h.x = mix(h.x, 0.115, g * green_shift * 0.55);
	h.y *= 1.0 - g * green_shift * 0.25;
	c = hsv2rgb(h);
	float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
	vec3 sh = mix(shadow_tint, vec3(1.0), smoothstep(0.02, 0.5, l));
	vec3 hi = mix(vec3(1.0), gain, smoothstep(0.2, 0.95, l) * (1.0 - warm));
	c = c * sh * hi;
	l = dot(c, vec3(0.2126, 0.7152, 0.0722));
	c = mix(vec3(l), c, sat);
	c = (c - 0.45) * contrast + 0.45;
	vec2 d = SCREEN_UV - 0.5;
	float v = smoothstep(0.32, 0.9, length(d * vec2(1.25, 1.0)));
	c = mix(c, c * vig_col, v * vignette);
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
