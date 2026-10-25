// Обводка выбранного жителя или кошки (этап 6.3): вывернутая оболочка поверх сетки (material_overlay) —
// тот же кремовый цвет, что у обводки постройки. Толщина — в метрах мира, как бы ни был отмасштабирован узел
// (у моделей Synty внутри свой масштаб), и чуть толще издали, чтобы кайма читалась и на общем плане.
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled, depth_draw_opaque;

uniform vec4 color : source_color = vec4(1.0, 0.96, 0.82, 1.0);
uniform float width = 0.02;          // метров вблизи
uniform float far_k = 0.0009;        // + столько метров на метр расстояния до камеры

void vertex() {
	float s = max(length(MODEL_MATRIX[0].xyz), 1e-4);
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float d = length(CAMERA_POSITION_WORLD - wp);
	VERTEX += NORMAL * (width + far_k * d) / s;
}

void fragment() {
	ALBEDO = color.rgb;
}
