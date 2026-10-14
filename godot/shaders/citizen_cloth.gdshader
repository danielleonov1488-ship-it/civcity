// Одежда жителей: атлас Synty как есть, но ткани — в цвет каждого жителя.
// Цвета и маски — instance uniform: материал общий (по одному на тон кожи), лишних вызовов отрисовки нет.
// Свет как у прежнего StandardMaterial3D: burley + ggx, шероховатость 0.85, блик 0.5.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float rough = 0.85;

instance uniform vec4 cloth_main = vec4(1.0);     // ЛИНЕЙНЫЙ цвет (GDScript: Color.srgb_to_linear())
instance uniform vec4 cloth_second = vec4(1.0);
instance uniform vec4 cloth_trim = vec4(1.0);
instance uniform int mask_main = 0;   // биты: 0–13 полосы блока тканей, 14–18 белые полосы, 19 голубой меандр
instance uniform int mask_second = 0;
instance uniform int mask_trim = 0;

const vec3 LUM = vec3(0.2126, 0.7152, 0.0722);

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb;
	if ((mask_main | mask_second | mask_trim) != 0) {
		vec2 p = fract(UV) * 4096.0;                  // PolygonAncientWorlds_Texture_01, 4096²
		int bit = -1;
		float shade = 1.0;
		if (p.x >= 1435.0 && p.x < 2047.0 && p.y >= 3788.0 && p.y < 4032.0) {
			// блок тканей: 14 полос по 43.7 px, в каждой три тона (свет, середина, тень)
			bit = min(int((p.x - 1435.0) / 43.714), 13);
			// складки — как в атласе: яркость тексела к светлому тону своей полосы
			vec3 top = textureLod(albedo_tex, vec2(1435.0 + (float(bit) + 0.5) * 43.714, 3828.0) / 4096.0, 0.0).rgb;
			shade = dot(c, LUM) / max(dot(top, LUM), 1e-4);
		} else if (p.y >= 4032.0 && p.x >= 1404.0 && p.x < 2044.0) {
			bit = 14 + int((p.x - 1404.0) / 128.0);      // белые полосы по 128 px: тоги, нижние туники
		} else if (p.x >= 3840.0 && p.y >= 2878.0 && p.y < 3698.0) {
			bit = 19;                                     // голубой меандр каймы (Worker M): узор — тенью
			shade = mix(0.45, 1.0, clamp((dot(c, LUM) - 0.173) / 0.358, 0.0, 1.0));
		}
		if (bit >= 0) {
			int b = 1 << bit;
			if ((mask_main & b) != 0) {
				c = cloth_main.rgb * shade;
			} else if ((mask_second & b) != 0) {
				c = cloth_second.rgb * shade;
			} else if ((mask_trim & b) != 0) {
				c = cloth_trim.rgb * shade;
			}
		}
	}
	ALBEDO = c;
	ROUGHNESS = rough;
	// ALPHA не пишем: «тает в двери» (Citizen.set_alpha → GeometryInstance3D.transparency) работает как раньше
}
