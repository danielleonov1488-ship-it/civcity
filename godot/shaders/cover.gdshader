// Подсветка домов (охват лавки, «Обзор»): дом перекрашен в цвет подсветки, но сам виден — крыша, окна, тени.
// Цвет берём не поверх, а по яркости того, что под оболочкой: одинаково читается на жёлтых, белых,
// розовых и сиреневых домах. Цвет у каждого дома свой — INSTANCE_CUSTOM (пул MultiMesh, scripts/cover.gd)
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_mix, shadows_disabled;

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float grow = 0.03;

varying vec4 tint;

void vertex() {
	tint = INSTANCE_CUSTOM;
	VERTEX += NORMAL * grow;
}

void fragment() {
	vec3 under = textureLod(screen, SCREEN_UV, 0.0).rgb;
	float lum = clamp(dot(under, vec3(0.3, 0.59, 0.11)), 0.0, 1.4);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	// мягко дышит — видно, что это подсветка, а не новая краска
	float pulse = 0.94 + 0.06 * sin(TIME * 2.0);
	ALBEDO = tint.rgb * (0.32 + 1.05 * lum) * pulse + tint.rgb * fres * 0.45;
	ALPHA = tint.a;
}
