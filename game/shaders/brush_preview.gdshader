shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
uniform vec4 tint : source_color = vec4(0.62,0.92,0.75,1.0);
void fragment(){
 float rim=pow(1.0-abs(dot(normalize(NORMAL),normalize(VIEW))),2.0);
 ALBEDO=tint.rgb;
 ALPHA=0.06+rim*0.42;
}
