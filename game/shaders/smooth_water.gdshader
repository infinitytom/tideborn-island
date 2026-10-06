shader_type spatial;
render_mode cull_disabled;
uniform sampler2D heightmap : filter_linear, repeat_disable;
uniform sampler2D watermap : filter_linear, repeat_disable;
uniform bool lake=false;
uniform float ice=0.0;
uniform float night=0.0;
varying vec3 world;
varying float depth;
void vertex(){
 vec3 p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 float a=sin(p.x*0.034+p.z*0.019+TIME*0.72);
 float b=sin(p.x*0.081-p.z*0.047-TIME*0.52);
 float amplitude=lake?0.045:0.32;
 VERTEX.y+=(a+b*0.35)*amplitude*(1.0-ice);
 NORMAL=normalize(vec3(-(cos(p.x*0.034+p.z*0.019+TIME*0.72)*0.034+cos(p.x*0.081-p.z*0.047-TIME*0.52)*0.081*0.35)*amplitude,1.0,-(cos(p.x*0.034+p.z*0.019+TIME*0.72)*0.019-cos(p.x*0.081-p.z*0.047-TIME*0.52)*0.047*0.35)*amplitude));
 world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 depth=COLOR.g*8.0;
}
void fragment(){
 vec2 uv=(world.xz+516.0)/1024.0;
 float bed=texture(heightmap,uv).r;
 float d=max(0.0,world.y-bed);
 if (lake && (d<0.05 || texture(watermap,uv).r<0.18)) discard;
 // Fragment normals keep ripples continuous even over a distant coarse mesh.
 float footprint=max(fwidth(world.x),fwidth(world.z));
 float amp=(lake?0.12:0.55)*(1.0-ice)/(1.0+footprint*0.3);
 float c0=cos(world.x*0.034+world.z*0.019+TIME*0.72);
 float c1=cos(world.x*0.081-world.z*0.047-TIME*0.52);
 float c2=cos(world.x*0.17+world.z*0.13+sin(world.z*0.047)*1.4+TIME*1.1);
 vec3 n=normalize(vec3(-(c0*0.034+c1*0.081*0.35+c2*0.008)*amp,1.0,-(c0*0.019-c1*0.047*0.35+c2*0.006)*amp));
 NORMAL=normalize((VIEW_MATRIX*vec4(n,0.0)).xyz);
 vec3 shallow=lake?vec3(0.17,0.49,0.43):vec3(0.22,0.55,0.57); vec3 deep=vec3(0.09,0.30,0.41);
 vec3 col=mix(shallow,deep,smoothstep(1.0,30.0,d));
 float fresnel=pow(1.0-max(0.0,dot(NORMAL,VIEW)),4.0);
 col=mix(col,vec3(0.63,0.76,0.78),fresnel*(lake?0.25:0.55));
 float foam=(1.0-smoothstep(0.3,2.0,d))*clamp(sin(world.x*0.13+world.z*0.18-TIME*1.2)*0.5+0.2,0.0,1.0);
 col=mix(col,vec3(0.72,0.81,0.74),foam*0.28);
 col=mix(col,vec3(0.67,0.79,0.84),ice);
 ALBEDO=col*(1.0-night*0.38); ROUGHNESS=mix(0.36,0.60,ice); METALLIC=0.08; SPECULAR=0.45;
}
