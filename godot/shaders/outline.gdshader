// Обводка выбранной постройки по силуэту (вывернутая оболочка), как в Town to City
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.97, 0.88, 1.0);
uniform float width = 0.07;

void vertex() {
	VERTEX += NORMAL * width;
}

void fragment() {
	ALBEDO = color.rgb;
}
