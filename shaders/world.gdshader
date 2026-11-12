// Curved-world shader used by every scrolling object (terrain, obstacles, coins).
// Bends geometry down + sideways with distance ahead of the player (Subway Surfers style)
// and applies a cheap distance fog that works on the Compatibility renderer.
shader_type spatial;
render_mode world_vertex_coords, diffuse_lambert, specular_schlick_ggx;

global uniform float curve_y;
global uniform float curve_x;
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
uniform bool track = false; // groomed piste pattern (terrain only)

varying vec3 v_world;

void vertex() {
	float d = max(-VERTEX.z, 0.0);
	VERTEX.y -= d * d * curve_y;
	VERTEX.x += d * d * curve_x;
	v_world = VERTEX;
}

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void fragment() {
	vec3 col = albedo.rgb;
	if (use_vertex_color) {
		col *= COLOR.rgb;
	}
	if (track) {
		float x = UV.x;
		float a = UV.y;
		float ax = abs(x);
		float on = 1.0 - smoothstep(5.2, 5.8, ax);
		// corduroy grooves along travel direction
		float cord = smoothstep(0.35, 0.5, abs(fract(x * 3.0) - 0.5));
		// lane separators
		float lane = 1.0 - smoothstep(0.03, 0.1, abs(abs(x) - 1.3)) ;
		// cross bands for speed feeling
		float band = smoothstep(0.85, 1.0, sin(a * 0.45)) ;
		vec3 piste = vec3(0.80, 0.87, 0.97);
		piste *= 1.0 - cord * 0.10;
		piste = mix(piste, vec3(0.52, 0.66, 0.92), lane * 0.75);
		piste = mix(piste, vec3(0.68, 0.78, 0.95), band * 0.6);
		// soft edge berm
		piste = mix(piste, vec3(0.70, 0.80, 0.96), smoothstep(4.0, 5.5, ax) * 0.7);
		col = mix(col, piste * COLOR.rgb / max(COLOR.rgb, vec3(0.6)), on);
	}
	float dist = length(VERTEX);
	float f = smoothstep(fog_start, fog_end, dist);
	vec3 em = emission * emission_energy;
	if (sparkle > 0.0) {
		float s = step(0.985, hash(floor(v_world * 9.0)));
		em += vec3(s * sparkle) * (1.0 - f);
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
