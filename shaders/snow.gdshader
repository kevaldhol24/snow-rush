// Snow terrain (Phase 2, ART_DIRECTION.md §4). GL Compatibility-safe.
// - wrap lighting (soft terminator) + blue/violet shadow fill: shadows read blue, never grey
// - view-dependent glitter: sparkles only where the sun reflects toward the camera
// - powder rim on grazing angles, slope tint (steep = bluer), wind patches + fall-line streaks
// - distance fog shared with world.gdshader (global uniforms)
shader_type spatial;
render_mode world_vertex_coords, specular_disabled;

global uniform vec4 fog_color : source_color;
global uniform float fog_start;
global uniform float fog_end;

uniform vec3 snow_lit : source_color = vec3(0.957, 0.969, 1.0);   // #F4F7FF
uniform vec3 snow_shade : source_color = vec3(0.616, 0.706, 0.910); // #9DB4E8
uniform float wrap = 0.35;
uniform float sun_gain = 0.78;     // keeps lit snow just under white (no clipping)
uniform float shade_fill = 0.16;   // blue sky-bounce added where the sun doesn't reach
uniform float glitter = 1.6;
uniform float glitter_density = 0.997; // higher = fewer sparkles
uniform float rim = 0.22;
uniform float slope_tint = 0.35;
// Poly Haven snow_02 normal map (CC0), two scales; fades out with distance (no far shimmer)
uniform sampler2D detail_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float detail_strength = 0.55;

varying vec3 v_world;
varying vec3 v_wn;
varying float v_near; // written in fragment, read in light()

void vertex() {
	v_world = VERTEX;
	v_wn = NORMAL;
}

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(vec3(i, 0.0));
	float b = hash(vec3(i + vec2(1.0, 0.0), 0.0));
	float c = hash(vec3(i + vec2(0.0, 1.0), 0.0));
	float d = hash(vec3(i + vec2(1.0, 1.0), 0.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec3 col = snow_lit * COLOR.rgb;
	// wind-blown patches (UV = lateral m, along-path m)
	float n = vnoise(UV * vec2(0.15, 0.1)) * 0.6 + vnoise(UV * vec2(0.6, 0.4)) * 0.4;
	col *= mix(vec3(0.88, 0.92, 1.0), vec3(1.0), smoothstep(0.2, 0.8, n));
	// faint streaks along the fall line: perspective cue for the slope (Phase 1)
	float streak = vnoise(vec2(UV.x * 1.3, UV.y * 0.035)) * 0.65 + vnoise(vec2(UV.x * 3.1, UV.y * 0.08)) * 0.35;
	col *= mix(1.0, 0.94, smoothstep(0.55, 0.85, streak));
	// steep faces: bluer, slightly darker (banks, cliff run-outs, lips)
	float steep = 1.0 - clamp(v_wn.y, 0.0, 1.0);
	col = mix(col, snow_shade * 0.95, smoothstep(0.25, 0.7, steep) * slope_tint);
	ALBEDO = col;
	ROUGHNESS = 0.85;
	// detail normal: terrain chunks have no tangents, so build the tangent frame per pixel from
	// screen-space derivatives (cotangent frame, view space), then perturb NORMAL directly
	float dview = length(VERTEX);
	float dfade = detail_strength * (1.0 - smoothstep(12.0, 45.0, dview));
	if (dfade > 0.001) {
		vec3 t1 = texture(detail_normal, UV * 0.45).rgb * 2.0 - 1.0;
		vec3 t2 = texture(detail_normal, UV * 0.11 + vec2(0.37, 0.61)).rgb * 2.0 - 1.0;
		vec3 tn = normalize(vec3(t1.xy + t2.xy * 0.8, t1.z));
		vec3 dp1 = dFdx(VERTEX);
		vec3 dp2 = dFdy(VERTEX);
		vec2 duv1 = dFdx(UV);
		vec2 duv2 = dFdy(UV);
		vec3 dp2p = cross(dp2, NORMAL);
		vec3 dp1p = cross(NORMAL, dp1);
		vec3 T = dp2p * duv1.x + dp1p * duv2.x;
		vec3 B = dp2p * duv1.y + dp1p * duv2.y;
		float im = inversesqrt(max(max(dot(T, T), dot(B, B)), 1e-12));
		vec3 pn = normalize(mat3(T * im, B * im, NORMAL) * tn);
		NORMAL = normalize(mix(NORMAL, pn, dfade));
	}
	// powder rim: grazing angles glow toward the sky/haze colour
	float fr = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	float dist = length(VERTEX);
	v_near = 1.0 - smoothstep(10.0, 50.0, dist);
	float f = smoothstep(fog_start, fog_end, dist);
	vec3 em = fog_color.rgb * fr * rim;
	ALBEDO *= (1.0 - f);
	EMISSION = mix(em, fog_color.rgb, f);
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float wrapped = clamp((ndl + wrap) / (1.0 + wrap), 0.0, 1.0);
	float lit = wrapped * ATTENUATION;
	// direct sun
	DIFFUSE_LIGHT += LIGHT_COLOR * lit * sun_gain / PI;
	// shadow fill: where the sun is blocked or turned away, add a cool blue (sky bounce)
	DIFFUSE_LIGHT += snow_shade * (1.0 - lit) * shade_fill * length(LIGHT_COLOR) / (PI * 1.732);
	// glitter: tiny cells that mirror the sun into the camera
	vec3 cell = floor(v_world * 20.0); // 5 cm cells
	float h = hash(cell);
	float s = step(glitter_density, h);
	vec3 rv = reflect(-LIGHT, NORMAL);
	float spec = pow(clamp(dot(rv, VIEW), 0.0, 1.0), 6.0);
	SPECULAR_LIGHT += LIGHT_COLOR * s * spec * glitter * ATTENUATION * v_near;
}
