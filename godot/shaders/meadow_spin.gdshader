// Крылья мельницы и водяное колесо (scripts/meadow.gd): вращаются в вершинах вокруг своей оси (axis через center —
// в осях сетки), у каждой мельницы своя фаза. Работает и в MultiMesh пула деталей (вершины крутятся до перевода в мир).
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 center = vec3(0.0);
uniform vec3 axis = vec3(0.0, 0.0, 1.0);
uniform float speed = 0.5;

vec3 rot(vec3 p, vec3 k, float c, float s) {
	return p * c + cross(k, p) * s + k * dot(k, p) * (1.0 - c);
}

void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;
	float a = TIME * speed + dot(o.xz, vec2(0.37, 0.61));
	vec3 k = normalize(axis);
	float c = cos(a);
	float s = sin(a);
	VERTEX = center + rot(VERTEX - center, k, c, s);
	NORMAL = rot(NORMAL, k, c, s);
}

void fragment() {
	ALBEDO = texture(albedo_tex, UV).rgb;
	ROUGHNESS = 0.85;
	SPECULAR = 0.3;
}
