shader_type spatial;
// Continuous translucent wall with bounded manual transmission lighting.
// Unshaded avoids black backfaces and self-shadow patterns in Compatibility.
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;
uniform sampler2D ocean_noise : repeat_enable, filter_linear_mipmap;
uniform vec3 tint : source_color = vec3(0.08,0.40,0.34);
uniform vec3 thin_tint : source_color = vec3(0.12,0.52,0.40);
uniform vec3 sky_tint : source_color = vec3(0.65,0.78,0.82);
uniform vec3 foam_tint : source_color = vec3(0.89,0.95,0.93);
uniform vec3 to_sun = vec3(0.3,0.7,0.5);
uniform float wave_time = 0.0;
uniform int detail_level = 1;
varying vec3 wp;
varying vec3 normal_world;
float noise2(vec2 p) { return texture(ocean_noise,p/24.0).r; }
void vertex() { wp=(MODEL_MATRIX*vec4(VERTEX,1)).xyz; normal_world=normalize((MODEL_MATRIX*vec4(NORMAL,0)).xyz); }
void fragment() {
 float t=wave_time;
 float grain=noise2(vec2(UV.x*23.0-t*0.85,UV.y*14.0+t*1.6));
 float fine=grain;
 if(detail_level>0) fine=noise2(vec2(UV.x*62.0+t*0.6,UV.y*41.0-t*2.3));
 float curtain=1.0-step(0.0,UV.y);
 float lip=(1.0-smoothstep(0.015,0.14,max(UV.y,0.0)));
 float crown=exp(-pow((UV.y-0.48)/0.12,2.0))*0.20;
 float mouth=smoothstep(0.82,0.99,UV.x);
 float foam=clamp((lip*0.82+crown+mouth*0.50)*(0.40+0.60*grain)+curtain*0.30,0.0,1.0);
 foam=smoothstep(0.18,0.85,foam+fine*lip*0.25);
 float fade=smoothstep(0.0,0.055,UV.x)*(1.0-smoothstep(0.94,1.0,UV.x));
 float ripple=sin(UV.x*67.0+UV.y*22.0-t*5.0)*0.018;
 if(detail_level>0) NORMAL_MAP=normalize(vec3(ripple,(fine-0.5)*0.10,1.0))*0.5+0.5;
 float fres=pow(1.0-clamp(abs(dot(normalize(normal_world),normalize(CAMERA_POSITION_WORLD-wp))),0.0,1.0),4.0);
 float thin=0.55+0.45*sin(clamp(UV.y,0.0,1.0)*3.14159265);
 vec3 water=mix(tint,thin_tint,thin*0.75)*(0.94+0.12*grain);
 water=mix(water,sky_tint*0.75,fres*0.28);
 float diffuse=0.72+0.28*abs(dot(normalize(normal_world),normalize(to_sun)));
 ALBEDO=mix(water*diffuse+thin_tint*0.14,foam_tint,foam*0.90);
 // Gentle transmission also keeps the inner wall from turning into a black roof.
 EMISSION=thin_tint*(0.07+thin*0.14)*(1.0-foam*0.75);
 ROUGHNESS=mix(0.23,0.78,foam);
 SPECULAR=mix(0.48,0.22,foam);
 METALLIC=0.0;
 ALPHA=mix(clamp(0.48+fres*0.16+grain*0.025,0.0,0.92),0.96,foam)*fade;
 ALPHA*=mix(1.0,smoothstep(-0.10,-0.025,UV.y)*(0.48+0.28*fine),curtain);
}
