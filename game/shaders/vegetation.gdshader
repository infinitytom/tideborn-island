shader_type spatial;
render_mode cull_disabled;
uniform bool woody=false;
uniform bool deciduous=false;
uniform int kind=0;
uniform vec4 season_weights=vec4(1.0,0.0,0.0,0.0);
varying vec4 tint;
varying float tip;
varying float variety;
void vertex(){
 tint=COLOR;
 tip=VERTEX.y;
 vec3 world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 variety=sin(world.x*0.11+world.z*0.17)*0.5+0.5;
 float strength=woody?0.10:0.045;
 VERTEX.x+=sin(TIME*1.15+world.x*0.07+world.z*0.04)*max(VERTEX.y-1.0,0.0)*strength;
}
void fragment(){
 vec3 col=tint.rgb;
 bool leaf=col.g>col.r*1.04;
 if(leaf){
  col=mix(col,col*vec3(1.02,1.20,0.88),season_weights.x*0.65);
  col=mix(col,col*vec3(0.82,0.91,0.80),season_weights.y*0.8);
  if(deciduous) col=mix(col,mix(vec3(0.85,0.40,0.13),vec3(0.95,0.68,0.22),variety),season_weights.z*0.92);
  col=mix(col,vec3(0.64,0.75,0.72),season_weights.w*(deciduous?0.78:0.30));
 }
 float snow=season_weights.w*smoothstep(0.35,0.85,NORMAL.y);
 col=mix(col,vec3(0.91,0.95,0.97),snow*0.8);
 ALBEDO=col*(0.86+variety*0.12); ROUGHNESS=0.88;
}
