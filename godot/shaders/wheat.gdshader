shader_type spatial;
render_mode cull_disabled, diffuse_lambert_wrap, specular_disabled;

uniform vec2 fade = vec2(118.0, 145.0);
uniform float sway = 0.095;

void vertex() {
	vec3 root = MODEL_MATRIX[3].xyz;
	float height = max(VERTEX.y, 0.0);
	float phase = dot(root.xz, vec2(0.48, 0.33)) - TIME * 1.38;
	float gust = sin(phase) + 0.24 * sin(phase * 1.7 + TIME * 0.51);
	// Корни стоят на месте, волна проходит через соседние пучки.
	vec3 wind = vec3(0.86, 0.0, 0.51) * (sway * gust * height * height);
	VERTEX += wind * mat3(MODEL_MATRIX);
	VERTEX *= 1.0 - smoothstep(fade.x, fade.y, distance(root, CAMERA_POSITION_WORLD));
	NORMAL = normalize(mix(NORMAL, vec3(0.0, 1.0, 0.0), 0.58));
}

void fragment() {
	ALBEDO = OUTPUT_IS_SRGB ? COLOR.rgb : pow(COLOR.rgb, vec3(2.2));
	BACKLIGHT = ALBEDO * 0.26;
	ROUGHNESS = 1.0;
}
