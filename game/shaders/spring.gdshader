shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque;
uniform float selected = 0.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float radius = length(p);
	float edge = 1.0 - smoothstep(0.72, 1.0, radius);
	float ripples = pow(max(0.0, sin(radius * 24.0 - TIME * 2.2)), 10.0);
	float rim = smoothstep(0.78, 0.84, radius) * (1.0 - smoothstep(0.88, 0.96, radius));
	ALBEDO = mix(vec3(0.13, 0.34, 0.35), vec3(0.45, 0.70, 0.66), ripples * 0.33);
	ALBEDO = mix(ALBEDO, vec3(0.73, 0.94, 0.85), rim * selected);
	ROUGHNESS = 0.23;
	SPECULAR = 0.65;
	ALPHA = max(edge * 0.72, rim * selected * 0.85);
}
