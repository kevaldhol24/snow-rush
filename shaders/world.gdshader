// Shared shader for terrain + props: vertex-coloured, distance fog (Compatibility-safe), snow glitter, rim.
// Phase 2 replaces this with dedicated snow/prop shaders (see docs/ART_DIRECTION.md).
shader_type spatial;
render_mode world_vertex_coords, diffuse_lambert, specular_schlick_ggx;

global uniform vec4 fog_color : source_color;
global uniform float fog_start;
global uniform float fog_end;

uniform vec4 albedo : source_color = vec4(1.0);
uniform bool use_vertex_color = true;
uniform vec3 emission : source_color = vec3(0.0);
uniform float emission_energy = 0.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.9;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float rim_strength = 0.0;
uniform float sparkle = 0.0; // snow glitter
uniform bool terrain = false; // subtle large-scale snow tint variation

varying vec3 v_world;

void vertex() {
	v_world = VERTEX;
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
	vec3 col = albedo.rgb;
	if (use_vertex_color) {
		col *= COLOR.rgb;
	}
	if (terrain) {
		// soft wind-blown patches so the snow is not one flat colour
		float n = vnoise(UV * vec2(0.15, 0.1)) * 0.6 + vnoise(UV * vec2(0.6, 0.4)) * 0.4;
		col *= mix(vec3(0.80, 0.86, 0.98), vec3(1.0), smoothstep(0.2, 0.8, n));
	}
	float dist = length(VERTEX);
	float f = smoothstep(fog_start, fog_end, dist);
	vec3 em = emission * emission_energy;
	if (sparkle > 0.0) {
		vec3 cell = floor(v_world * 7.0);
		float s = step(0.992, hash(cell));
		float facing = pow(clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
		em += vec3(s * sparkle * facing) * (1.0 - smoothstep(0.0, 45.0, dist));
	}
	if (rim_strength > 0.0) {
		float r = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
		em += vec3(1.0) * r * rim_strength;
	}
	ALBEDO = col * (1.0 - f);
	EMISSION = mix(em, fog_color.rgb, f);
	ROUGHNESS = roughness;
	METALLIC = metallic;
}
