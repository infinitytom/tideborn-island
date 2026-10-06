shader_type spatial;
uniform sampler2D fields : filter_linear, repeat_disable;
global uniform float island_winter;
global uniform float island_autumn;
global uniform float island_spring;
uniform int u_transition_mask;
varying vec3 world;
varying vec3 world_normal;
float hash3(vec3 p){return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453);}
float noise3(vec3 p){
 vec3 i=floor(p); vec3 f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(mix(hash3(i),hash3(i+vec3(1,0,0)),f.x),mix(hash3(i+vec3(0,1,0)),hash3(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash3(i+vec3(0,0,1)),hash3(i+vec3(1,0,1)),f.x),mix(hash3(i+vec3(0,1,1)),hash3(i+vec3(1,1,1)),f.x),f.y),f.z);
}
void vertex(){
 int f=floatBitsToInt(CUSTOM0.w); int sides=u_transition_mask&255;
 if (((f&63)&sides)!=0 && (((f>>8)&63)&~sides)==0) VERTEX=CUSTOM0.xyz;
 int seam=(f>>16)&255; if (seam!=0 && (seam&sides)==0) VERTEX=vec3(0.0);
 world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; world_normal=MODEL_NORMAL_MATRIX*NORMAL;
}
void fragment(){
 vec4 field=texture(fields,(world.xz+512.0)/1024.0);
 float slope=clamp(normalize(world_normal).y,0.0,1.0);
 float coarse=noise3(world*0.11); float fine=noise3(world*0.65);
 float strata=sin(world.y*0.7+coarse*3.0+sin(world.x*0.024));
 float detail=1.0/(1.0+max(fwidth(world.x),fwidth(world.z))*0.5);
 vec3 rock=mix(vec3(0.24,0.28,0.29),vec3(0.43,0.43,0.36),coarse);
 rock*=0.90+strata*0.055+fine*0.12*detail;
 vec3 soil=vec3(0.35,0.29,0.21);
 vec3 grass=mix(vec3(0.33,0.45,0.24),vec3(0.20,0.34,0.23),field.r);
 grass*=0.90+coarse*0.18;
 grass=mix(grass,grass*vec3(0.93,1.12,0.90),island_spring*0.6);
 grass=mix(grass,vec3(0.52,0.43,0.27),island_autumn*0.55);
 float grass_edge=slope+(coarse-0.5)*0.18;
 vec3 col=mix(rock,mix(soil,grass,smoothstep(0.56,0.84,grass_edge)),smoothstep(0.47,0.80,grass_edge));
 col=mix(col,vec3(0.64,0.58,0.42),smoothstep(6.0,0.7,world.y)*smoothstep(0.5,0.9,slope));
 col=mix(col,vec3(0.81,0.87,0.92),island_winter*smoothstep(0.25,0.80,slope)*0.94);
 float grain=sin(world.x*0.42+sin(world.z*0.37))*sin(world.z*0.51)*0.025;
 ALBEDO=col*0.92+grain*detail; ROUGHNESS=0.95; SPECULAR=0.2;
 AO=clamp(0.94-field.g*0.13,0.75,1.0);
}
