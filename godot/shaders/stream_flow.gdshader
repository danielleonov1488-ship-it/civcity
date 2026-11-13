// Течение ручья (scripts/meadow_nature.gd, «Средняя» и «Высокая»): полоса над водой ручья — светлые струйки и блики
// бегут вниз по течению (UV.y — метры вдоль ручья, UV.x — поперёк 0…1). Сама вода — общая (shaders/water.gdshader).
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled;

uniform float speed = 0.55;
uniform vec4 tint : source_color = vec4(0.9, 0.96, 0.95, 1.0);

float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	float across = UV.x;
	float along = UV.y;
	float t = TIME * speed;
	float n = vn(vec2(across * 6.0, along * 0.9 - t * 1.6)) * 0.6 + vn(vec2(across * 14.0 + 3.0, along * 2.4 - t * 2.6)) * 0.4;
	float streak = smoothstep(0.62, 0.86, n);
	float edge = smoothstep(0.0, 0.22, across) * smoothstep(1.0, 0.78, across);
	ALBEDO = tint.rgb;
	ALPHA = streak * edge * 0.32;
}
