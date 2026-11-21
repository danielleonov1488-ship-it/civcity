shader_type spatial;
render_mode specular_disabled;

uniform vec4 cover : source_color;
uniform vec4 furrow : source_color;
uniform float row_pitch = 0.625;
uniform float row_width = 0.044;
varying vec2 field_pos;

float flecks(vec2 p) {
	vec3 v = fract(vec3(floor(p).xyx) * 0.1031);
	v += dot(v, v.yzx + 33.33);
	return fract((v.x + v.y) * v.z);
}

void vertex() {
	field_pos = UV * vec2(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[2].xyz));
}

void fragment() {
	float aa = fwidth(field_pos.y);
	float offset = sin(field_pos.x * 2.2) * 0.019 + sin(field_pos.x * 6.0) * 0.009;
	float row = abs(fract((field_pos.y + offset) / row_pitch + 0.5) - 0.5);
	float row_softness = aa / row_pitch;
	float lines = 1.0 - smoothstep(row_width, row_width + 0.045 + row_softness, row);
	float coarse = flecks(field_pos * vec2(6.0, 9.0));
	float fine = flecks(field_pos * vec2(21.0, 39.0));
	float texture_gain = 0.93 + 0.14 * coarse + (fine - 0.5) * 0.24 * (1.0 - smoothstep(0.012, 0.045, aa));
	ALBEDO = mix(cover.rgb, furrow.rgb, lines) * texture_gain;
	ROUGHNESS = 1.0;
}
