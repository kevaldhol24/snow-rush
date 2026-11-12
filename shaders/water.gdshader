// Frozen river: dark moving water with cracked ice plates.
shader_type spatial;
render_mode world_vertex_coords, diffuse_lambert, specular_schlick_ggx;

global uniform vec4 fog_color : source_color;
global uniform float fog_start;
global uniform float fog_end;

uniform float scroll = 0.0;

varying vec3 v_world;
varying vec3 v_local;

void vertex() {
	v_local = (inverse(MODEL_MATRIX) * vec4(VERTEX, 1.0)).xyz;
	v_world = VERTEX;
}

vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

// returns distance to cell edge (voronoi cracks)
float crack(vec2 p) {
	vec2 n = floor(p);
	vec2 f = fract(p);
	float md = 8.0;
	vec2 mr;
	for (int j = -1; j <= 1; j++)
	for (int i = -1; i <= 1; i++) {
		vec2 g = vec2(float(i), float(j));
		vec2 o = hash2(n + g);
		vec2 r = g + o - f;
		float d = dot(r, r);
		if (d < md) { md = d; mr = r; }
	}
	md = 8.0;
	for (int j = -1; j <= 1; j++)
	for (int i = -1; i <= 1; i++) {
		vec2 g = vec2(float(i), float(j));
		vec2 o = hash2(n + g);
		vec2 r = g + o - f;
		if (dot(mr - r, mr - r) > 0.00001)
			md = min(md, dot(0.5 * (mr + r), normalize(r - mr)));
	}
	return md;
}

void fragment() {
	vec2 uv = v_local.xz;
	float flow = sin(uv.x * 0.7 + TIME * 1.5 + uv.y * 0.3) * 0.5 + 0.5;
	vec3 water = mix(vec3(0.02, 0.32, 0.55), vec3(0.10, 0.58, 0.78), flow);
	// ice plates drifting sideways
	vec2 iuv = uv * 0.45 + vec2(TIME * 0.25, 0.0);
	float c = crack(iuv);
	float plate = smoothstep(0.04, 0.09, c);
	vec2 cell = floor(iuv);
	float keep = step(0.35, hash2(cell + floor(iuv + 0.5)).x);
	vec3 ice = mix(vec3(0.70, 0.88, 0.98), vec3(0.92, 0.98, 1.0), smoothstep(0.1, 0.4, c));
	vec3 col = mix(water, ice, plate * keep);
	float dist = length(VERTEX);
	float f = smoothstep(fog_start, fog_end, dist);
	ALBEDO = col * (1.0 - f);
	EMISSION = mix(vec3(0.0), fog_color.rgb, f);
	ROUGHNESS = mix(0.05, 0.5, plate * keep);
	SPECULAR = 0.8;
}
