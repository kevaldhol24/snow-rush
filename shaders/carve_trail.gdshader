// Board carve trail (Phase 2, ART_DIRECTION.md §4 "Board tracks").
// Alpha blend toward a shadow-blue tint (blend_mul rendered solid dark in GL Compatibility).
// UV.x = across the board (0..1), COLOR.a = strength (age fade * carve depth).
// Two soft edge grooves + a faint pressed base between them.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec3 groove_tint : source_color = vec3(0.58, 0.68, 0.90);
uniform float strength = 0.8;

void fragment() {
	float x = UV.x;
	float edge = exp(-pow((x - 0.14) / 0.08, 2.0)) + exp(-pow((x - 0.86) / 0.08, 2.0));
	float base = 0.25;
	ALBEDO = groove_tint;
	ALPHA = clamp((edge + base) * COLOR.a * strength, 0.0, 1.0);
}
