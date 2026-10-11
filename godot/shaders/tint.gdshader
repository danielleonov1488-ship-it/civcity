// Подсветка модели: полупрозрачный цвет с ободком (призрак при стройке, красная подсветка при сносе)
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_mix, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.4, 0.9, 0.4, 0.45);
uniform float grow = 0.0;

void vertex() {
	VERTEX += NORMAL * grow;
}

void fragment() {
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	ALBEDO = tint.rgb * (0.85 + 0.5 * fres);
	ALPHA = clamp(tint.a * (0.7 + 0.6 * fres), 0.0, 1.0);
}
