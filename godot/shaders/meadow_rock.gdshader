// Камни набора Synty Meadow Forest (scripts/meadow.gd): сбоку — камень, сверху — трава (как их Rock_Grass_Triplanar
// для Unity). Картинки кладутся по миру (трипланарно), поэтому большой и маленький камень одного масштаба узора;
// трава сверху — в тон травы на земле.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D side_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D top_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 side_tint : source_color = vec4(0.8, 0.79, 0.77, 1.0);
uniform vec4 top_tint : source_color = vec4(0.72, 0.8, 0.62, 1.0);
uniform float scale = 0.45;           // повторов картинки на метр
uniform float grass_on = 1.0;         // трава сверху (0 — голый камень)

varying vec3 wp;
varying vec3 wn;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 b = pow(abs(wn), vec3(4.0));
	b /= max(b.x + b.y + b.z, 1e-4);
	vec3 s = texture(side_tex, wp.zy * scale).rgb * b.x + texture(side_tex, wp.xz * scale).rgb * b.y + texture(side_tex, wp.xy * scale).rgb * b.z;
	s *= side_tint.rgb;
	float n = fract(sin(dot(floor(wp.xz * 3.0), vec2(12.9898, 78.233))) * 43758.5453);
	float top = smoothstep(0.8, 0.95, wn.y + (n - 0.5) * 0.08) * grass_on;   // трава — только на самой макушке
	vec3 g = texture(top_tex, wp.xz * scale * 0.7).rgb * top_tint.rgb;
	ALBEDO = mix(s, g, top);
	ROUGHNESS = mix(0.9, 0.95, top);
	SPECULAR = 0.3;
}
