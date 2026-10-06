shader_type spatial;
uniform sampler2D fields : filter_linear, repeat_disable;
global uniform float island_winter;
global uniform float island_autumn;
global uniform float island_spring;
uniform int u_transition_mask;
varying vec3 world;
varying vec3 world_normal;
void vertex(){
 int f=floatBitsToInt(CUSTOM0.w); int sides=u_transition_mask&255;
 if (((f&63)&sides)!=0 && (((f>>8)&63)&~sides)==0) VERTEX=CUSTOM0.xyz;
 int seam=(f>>16)&255; if (seam!=0 && (seam&sides)==0) VERTEX=vec3(0.0);
 world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; world_normal=MODEL_NORMAL_MATRIX*NORMAL;
}
void fragment(){
 vec4 field=texture(fields,(world.xz+512.0)/1024.0);
 float slope=clamp(normalize(world_normal).y,0.0,1.0);
 float strata=sin(world.y*0.42+sin(world.x*0.03)*1.2+sin(world.z*0.026));
 vec3 rock=mix(vec3(0.30,0.34,0.37),vec3(0.52,0.50,0.44),strata*0.24+0.5);
 vec3 soil=vec3(0.44,0.38,0.29);
 vec3 grass=mix(vec3(0.48,0.59,0.30),vec3(0.27,0.43,0.24),field.r);
 grass=mix(grass,grass*vec3(0.93,1.12,0.90),island_spring*0.6);
 grass=mix(grass,vec3(0.52,0.43,0.27),island_autumn*0.55);
 vec3 col=mix(rock,mix(soil,grass,smoothstep(0.48,0.80,slope)),smoothstep(0.45,0.80,slope));
 col=mix(col,vec3(0.74,0.69,0.52),smoothstep(6.0,0.7,world.y)*smoothstep(0.5,0.9,slope));
 col=mix(col,vec3(0.81,0.87,0.92),island_winter*smoothstep(0.25,0.80,slope)*0.94);
 float grain=sin(world.x*0.42+sin(world.z*0.37))*sin(world.z*0.51)*0.025;
 ALBEDO=col*0.86+grain; ROUGHNESS=0.92;
}
