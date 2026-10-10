// Земля витрины: цвет из вершин, а поверх — «живые» кубики, как в Town to City:
// у каждого кубика чуть свой оттенок; мостовая — бруски вразбежку с тёмными щелями, площадь — плиты.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

varying vec3 wpos;
varying vec3 wnrm;
varying float kind;
varying float top_y;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	kind = UV.x;
	top_y = UV.y;
}

float h31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

void fragment() {
	vec3 c = COLOR.rgb;
	vec3 an = abs(wnrm);
	vec2 fp = an.y > 0.5 ? wpos.xz : (an.x > 0.5 ? wpos.zy : wpos.xy);
	float k = floor(kind + 0.5);
	float rough = 0.95;
	if (k == 4.0 && an.y > 0.5) {
		// булыжник: бруски 25×20 см вразбежку, у каждого свой тон, щели темнее
		vec2 q = fp * vec2(4.0, 5.0);
		q.x += mod(floor(q.y), 2.0) * 0.5;
		vec2 f = fract(q);
		float e = min(min(f.x, 1.0 - f.x) * 1.25, min(f.y, 1.0 - f.y));
		float r = h31(vec3(floor(q), 3.0));
		c *= 0.82 + 0.3 * r;
		c = mix(c * 0.48, c, smoothstep(0.05, 0.16, e));
		rough = 0.85;
	} else if (k == 5.0 && an.y > 0.5) {
		// площадь: светлые плиты травертина вразбежку
		vec2 q = fp * vec2(1.5, 2.0);
		q.x += mod(floor(q.y), 2.0) * 0.5;
		vec2 f = fract(q);
		float e = min(min(f.x, 1.0 - f.x) * 1.33, min(f.y, 1.0 - f.y));
		float r = h31(vec3(floor(q), 5.0));
		c *= 0.9 + 0.16 * r;
		c *= 0.96 + 0.06 * h31(floor(wpos * 8.0));
		c = mix(c * 0.62, c, smoothstep(0.015, 0.05, e));
		rough = 0.8;
	} else if (an.y < 0.5 && k == 2.0) {
		// обрыв: слои камня по высоте, у каждого кубика свой оттенок
		float band = 0.5 + 0.5 * sin(wpos.y * 4.2 + sin(wpos.y * 1.3) * 1.5);
		c = mix(c, c * vec3(0.88, 0.86, 0.84), band * 0.8);
		c *= 0.93 + 0.12 * h31(floor(wpos * 8.0 - wnrm * 0.5));
	} else if (an.y < 0.5 && k == 1.0) {
		// стенка уступа: сверху кромка травы, ниже — земля
		vec3 dirt = vec3(0.24, 0.15, 0.08) * (0.9 + 0.2 * h31(floor(wpos * 8.0 - wnrm * 0.5)));
		c = wpos.y > top_y - 0.05 ? c * 0.85 : dirt;
	} else {
		// трава, земля, скала, песок: кубики по 12,5 см, каждый со своим оттенком
		vec3 id = floor(wpos * 8.0 - wnrm * 0.5);
		float r = h31(id);
		float spread = k == 0.0 ? 0.16 : (k == 2.0 ? 0.12 : 0.1);
		c *= 1.0 - spread * 0.5 + spread * r;
		if (k == 0.0 && an.y > 0.5) {
			// редкие светлые «травинки» и тёмные пятна
			float s = h31(id + 17.0);
			if (s > 0.94) c *= 1.18;
			if (s < 0.04) c *= 0.85;
		}
	}
	ALBEDO = c;
	ROUGHNESS = rough;
	SPECULAR = 0.3;
}
