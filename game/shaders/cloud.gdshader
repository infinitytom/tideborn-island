shader_type spatial;
render_mode cull_disabled;
uniform float coverage=0.55;
uniform float daylight=1.0;
void fragment(){ ALBEDO=mix(vec3(0.96,0.97,0.94),vec3(0.59,0.66,0.68),smoothstep(0.65,0.95,coverage))*mix(vec3(0.42,0.51,0.69),vec3(1.0),daylight); ROUGHNESS=1.0; }
