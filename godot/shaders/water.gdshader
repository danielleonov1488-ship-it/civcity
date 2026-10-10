// Море: бирюза на мели и синева в глубине, прозрачное у берега, пена у кромки, лёгкая рябь и блики.
shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx, depth_draw_always;

uniform sampler2D depth_tex : hint_depth_texture, filter_linear_mipmap;
uniform vec3 shallow : source_color = vec3(0.42, 0.80, 0.74);
uniform vec3 deep : source_color = vec3(0.10, 0.36, 0.50);

varying vec3 wpos;

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(wpos.x * 0.7 + TIME * 1.1) * 0.025 + cos(wpos.z * 0.55 + TIME * 0.9) * 0.025;
}

void fragment() {
	float d = texture(depth_tex, SCREEN_UV).r;
	vec4 v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
	v.xyz /= v.w;
	float depth = max(0.0, VERTEX.z - v.z);
	float t = clamp(depth / 2.5, 0.0, 1.0);
	vec3 col = mix(shallow, deep, sqrt(t));
	// пена: полоса у берега, рваная и бегущая
	float n = vnoise(wpos.xz * 3.0 + vec2(TIME * 0.3, TIME * 0.2)) * 0.6 + vnoise(wpos.xz * 9.0 - TIME * 0.4) * 0.4;
	float foam = (1.0 - smoothstep(0.0, 0.28, depth)) * smoothstep(0.35, 0.6, n + (1.0 - smoothstep(0.0, 0.12, depth)) * 0.5);
	ALBEDO = mix(col, vec3(0.97, 0.98, 0.96), foam);
	ALPHA = clamp(0.45 + t * 0.5 + foam, 0.0, 0.96);
	// рябь: нормаль чуть колышется
	float e = 0.05;
	vec2 p = wpos.xz * 1.6 + TIME * 0.25;
	float hx = vnoise(p + vec2(e, 0)) - vnoise(p - vec2(e, 0));
	float hz = vnoise(p + vec2(0, e)) - vnoise(p - vec2(0, e));
	vec3 nw = normalize(vec3(-hx * 0.8, 1.0, -hz * 0.8));
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	ROUGHNESS = 0.14;
	SPECULAR = 0.55;
	METALLIC = 0.0;
}
