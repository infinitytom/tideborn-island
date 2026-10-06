shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
void vertex(){ VERTEX.y=mod(VERTEX.y+MODEL_MATRIX[3].y-TIME*90.0,190.0)-MODEL_MATRIX[3].y; }
void fragment(){ ALBEDO=vec3(0.73,0.84,0.87); ALPHA=0.24; }
