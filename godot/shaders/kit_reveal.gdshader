shader_type spatial;
render_mode cull_disabled;
// Стройка дома из своего набора (game.gd _grow_*): видно только то, что ниже reveal (по высоте в осях постройки) —
// низ, перекрытия и рамы встают вслед за кладкой, черепица ложится рядами от карниза к коньку.
// Цвет — как у KitLib: цвет вершин × (картинка) × tint; fresh — «свежая» светлая пыль стройки.
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_tex = false;
uniform vec4 tint : source_color = vec4(1.0);
uniform float reveal = 1000.0;
uniform float fresh = 0.0;
uniform float rough = 0.85;
varying float ly;

void vertex() {
	ly = VERTEX.y;
}

void fragment() {
	if (ly > reveal) {
		discard;
	}
	vec3 c = COLOR.rgb * tint.rgb;
	if (use_tex) {
		c *= texture(tex, UV).rgb;
	}
	ALBEDO = mix(c, vec3(0.78, 0.68, 0.52), fresh * 0.2);
	ROUGHNESS = rough;
}
