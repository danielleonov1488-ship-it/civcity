// Листва деревьев и кустов по временам года (scripts/seasons.gd). Без времён года (season = 0) — то же, что
// обычный материал палитры (StandardMaterial3D: картинка × оттенок, шероховатость 0.85).
// season.x — осень (листья золотые, рыжие, багряные — у каждого дерева свой цвет; часть деревьев остаётся зелёной),
// season.y — зима (листва тусклая и буроватая, хвойные — темнее), season.z — весна (свежая зелень, часть деревьев в цвету).
// Красится только зелёное (листва); стволы, камни и всё прочее — как были.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 albedo : source_color = vec4(1.0);
uniform vec4 season = vec4(0.0);
uniform bool evergreen = false;           // кипарисы, пальмы, оливы: осенью зелёные, зимой темнее, весной без цвета

varying float th;
varying vec3 wp;

float lum(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;            // у MultiMesh — место этого дерева: у каждого свой оттенок
	th = fract(sin(dot(floor(o.xz * 3.0), vec2(12.9898, 78.233))) * 43758.5453);
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb * albedo.rgb;
	if (season != vec4(0.0)) {
		// листва — зелёная или оливковая (зелёный не меньше красного, синего мало); стволы бурые, камни серые
		float leaf = smoothstep(-0.03, 0.0, c.g - c.r * 0.95) * smoothstep(0.85, 0.6, c.b / max(c.g, 1e-3));
		float l = lum(c);
		vec3 t = c;
		// осень
		vec3 au = (th < 0.12 || evergreen) ? c : (th < 0.5 ? vec3(1.0, 0.66, 0.12) : (th < 0.8 ? vec3(1.0, 0.38, 0.07) : vec3(0.8, 0.15, 0.05)));
		au *= l / max(lum(au), 1e-3) * (evergreen ? 1.0 : 1.15);
		t = mix(t, au, season.x);
		// зима
		vec3 dry = vec3(0.62, 0.47, 0.26);       // сухая бурая листва (часть дубов так и зимует), не серая
		vec3 wi = (th < 0.35 || evergreen) ? c * vec3(0.8, 0.86, 0.84) : dry * (l * 0.85 / lum(dry));
		t = mix(t, wi, season.y);
		// весна
		// цветущее дерево — вся крона бело-розовая, чуть пятнистая (цветы гуще и реже)
		float spot = fract(sin(dot(floor(wp * 14.0), vec3(12.99, 78.23, 37.71))) * 43758.55);
		float bloom = evergreen ? 0.0 : step(0.62, th);
		vec3 bl = mix(vec3(0.95, 0.42, 0.6), vec3(1.0, 0.76, 0.84), fract(th * 7.0)) * max(l * 2.4, 0.2) * (0.88 + 0.24 * spot);
		t = mix(t, mix(t * vec3(0.95, 1.07, 0.9), bl, bloom * 0.9), season.z);
		c = mix(c, t, leaf);
	}
	ALBEDO = c;
	ROUGHNESS = 0.85;
}
