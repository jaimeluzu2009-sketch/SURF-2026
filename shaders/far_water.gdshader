shader_type spatial;
// Mar lejano: plano grande por debajo de la malla de la ola que llega hasta el horizonte.
// Solo se ve más allá del borde de la rejilla principal (unos 230 m).
render_mode cull_back, specular_schlick_ggx;

uniform vec3 deep_color : source_color = vec3(0.03, 0.20, 0.27);
uniform vec3 sky_color : source_color = vec3(0.7, 0.81, 0.9);

void fragment() {
	vec3 wpos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 v = normalize(wpos - CAMERA_POSITION_WORLD);
	float fres = pow(1.0 - clamp(-v.y, 0.0, 1.0), 5.0);
	float dist = length(wpos - CAMERA_POSITION_WORLD);
	ALBEDO = mix(deep_color * 0.95, sky_color * 0.8, clamp(fres * 0.6 + smoothstep(150.0, 900.0, dist) * 0.25, 0.0, 0.8));
	ROUGHNESS = 0.2;
	SPECULAR = 0.5;
}
