shader_type canvas_item;
render_mode unshaded;

uniform vec4 spotlight;

void fragment() {
	vec2 inside = step(spotlight.xy, UV) - step(spotlight.zw, UV);
	COLOR.a *= 1.0 - inside.x * inside.y;
}
