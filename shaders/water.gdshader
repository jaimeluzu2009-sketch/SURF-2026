shader_type spatial;
// Agua con la ola desplazada en el vértice. Válido para el renderizador Compatibilidad
// (GLES3 / WebGL 2): sin texturas de pantalla ni de profundidad; todo es procedural.
render_mode cull_back, specular_schlick_ggx;

#include "res://shaders/wave_common.gdshaderinc"

uniform sampler2D ocean_noise : repeat_enable, filter_linear_mipmap;
uniform sampler2D ocean_normal : repeat_enable, filter_linear_mipmap;

uniform vec3 deep_color : source_color = vec3(0.03, 0.20, 0.27);
uniform vec3 shallow_color : source_color = vec3(0.07, 0.45, 0.45);
uniform vec3 face_color : source_color = vec3(0.16, 0.66, 0.58);
uniform vec3 foam_color : source_color = vec3(0.94, 0.97, 0.98);
uniform vec3 sky_color : source_color = vec3(0.7, 0.81, 0.9);
// Dirección HACIA el sol, en coordenadas del mundo.
uniform vec3 to_sun = vec3(0.35, 0.62, 0.70);
uniform float shore_z = 66.0;
// 0: sin rizos (calidad Baja) · 1: dos escalas · 2: tres escalas.
uniform int detail_level = 2;
// Tabla: x, z, velocidad (m/s), 1 si toca el agua.
uniform vec4 board = vec4(0.0);
// Estela: x, z, edad (s), intensidad. La más reciente primero.
uniform vec4 wake[12];
uniform int wake_count = 0;
uniform float wake_load[12];
uniform vec3 board_rails = vec3(0.0,1.0,0.0);
uniform vec4 wake_bounds = vec4(0.0);
// 1 = altura codificada en color (lo usa tests/wave_parity.gd).
uniform float debug_flat = 0.0;
uniform float tube_strength = 0.0;

varying vec3 world_pos;
varying vec4 wave_terms;
varying vec3 geo_normal;

// Textura simplex continua, compacta y con mipmaps: evita celdas de ruido cuadradas.
float vnoise(vec2 p) {
	return texture(ocean_noise,p/24.0).r;
}

vec2 ocean_slope(vec2 uv) {
	vec3 encoded=texture(ocean_normal,uv).xyz*2.0-1.0;
	return encoded.xy;
}

float seg_dist(vec2 p, vec2 a, vec2 b, out float t) {
	vec2 ab = b - a;
	t = clamp(dot(p - a, ab) / max(dot(ab, ab), 1e-4), 0.0, 1.0);
	return length(p - (a + ab * t));
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec4 terms;
	float h = wave_height_terms(wp.x, wp.z, terms);
	float e = 0.25;
	float hx = wave_height(wp.x + e, wp.z) - wave_height(wp.x - e, wp.z);
	float hz = wave_height(wp.x, wp.z + e) - wave_height(wp.x, wp.z - e);
	VERTEX.y = h - MODEL_MATRIX[3].y;
	NORMAL = normalize(vec3(-hx / (2.0 * e), 1.0, -hz / (2.0 * e)));
	geo_normal = NORMAL;
	wp.y = h;
	world_pos = wp;
	wave_terms = terms;
}

void fragment() {
	float broken = wave_terms.x;
	float peak = wave_terms.y;
	float profile = wave_terms.z;
	float u = wave_terms.w;
	vec3 view_ray = world_pos - CAMERA_POSITION_WORLD;
	float dist = length(view_ray);
	vec3 v = view_ray / max(dist, 1e-3);
	vec3 n_geo = normalize(geo_normal);

	// Ondulación cruzada sin escalones de gradiente. El desplazamiento macro no cambia.
	vec2 p=world_pos.xz;
	float t=wave_time;
	vec2 g=vec2(0.0);
	if(detail_level>0) {
		vec2 q=vec2(p.x*.87+p.y*.49,-p.x*.49+p.y*.87);
		g=ocean_slope(q*.042+vec2(.009,-.015)*t)*.30;
		g+=ocean_slope(vec2(-q.y,q.x)*.093+vec2(-.012,.008)*t)*.15*(1.0-sstep(65.0,230.0,dist));
		if(detail_level>1) g+=ocean_slope(q*.21+vec2(.017,.006)*t)*.055*(1.0-sstep(18.0,85.0,dist));
	} else {
		// La calidad baja mantiene rizos suaves con una sola muestra.
		g=ocean_slope(p*.04+vec2(.008,-.013)*t)*.18;
	}
	vec3 nw=normalize(n_geo+vec3(-g.x,0.0,-g.y));
	NORMAL=normalize((VIEW_MATRIX*vec4(nw,0.0)).xyz);

	// --- Color del agua.
	vec3 col = mix(deep_color, shallow_color, sstep(-0.6, 1.6, world_pos.y));
	// Manchas grandes de color (fondos, corrientes, nubes) para romper la uniformidad.
	float patch = vnoise(world_pos.xz * 0.018 + vec2(wave_time * 0.01, 0.0));
	float patch2 = vnoise(world_pos.xz * 0.06 - vec2(0.0, wave_time * 0.02));
	col *= 0.96 + 0.07 * patch;
	col = mix(col, shallow_color, 0.045 * patch2);
	// Cara de la ola: agua fina que deja pasar la luz (más verde y clara).
	float face = sstep(0.25, 0.85, profile) * sstep(-0.5, 0.8, u);
	float thin = sstep(0.6, 0.95, profile) * sstep(-0.3, 0.6, u);
	// Grosor: la base de la pared es agua gruesa y oscura; hacia el labio se aclara
	// y deja pasar la luz (verde Pacífico). lift = altura relativa en la cara.
	float lift = clamp((world_pos.y - tide) / max(amp, 0.35), 0.0, 1.15);
	vec3 face_low = mix(deep_color, face_color, 0.42);
	vec3 face_high = face_color * 1.18 + vec3(0.0, 0.025, 0.015);
	col = mix(col, mix(face_low, face_high, sstep(0.15, 0.95, lift)), face * 0.6);
	// Mirando en vertical se ve más el fondo del agua; en rasante, más el cielo.
	float facing = clamp(dot(n_geo, -v), 0.0, 1.0);
	col = mix(col, deep_color * 0.85, (1.0 - face) * sstep(0.55, 0.95, facing) * 0.25);
	col = mix(col, shallow_color * 1.15, sstep(shore_z - 22.0, shore_z, world_pos.z));
	// Reflejo del cielo según el ángulo (Fresnel): el mar lejano se funde con el horizonte.
	float fres = pow(1.0 - clamp(dot(nw, -v), 0.0, 1.0), 5.0);
	col = mix(col, sky_color * 0.72, clamp(fres * 0.46 + sstep(150.0, 900.0, dist) * 0.25, 0.0, 0.8));

	// --- Espuma.
	float nz1 = vnoise(world_pos.xz * 0.8 + vec2(0.0, wave_time * 0.9));
	float nz2 = vnoise(world_pos.xz * 2.9 - vec2(wave_time * 0.4, 0.0));
	float breakup = nz1 * 0.52 + nz2 * 0.48;
	// Vetas alargadas en la dirección de avance de la ola (espuma que se queda atrás).
	float streak = vnoise(vec2(world_pos.x * 1.4, world_pos.z * 0.3 - wave_time * 0.5));
	float trail = (u + 3.0) / 7.0;
	float foam = broken * sstep(0.10, 0.45, profile);
	foam += broken * exp(-trail * trail) * 0.8;
	foam += broken * sstep(-25.0, -4.0, u) * (1.0 - sstep(-4.0, 0.0, u)) * sstep(0.55, 0.8, streak) * 0.7;
	foam += peak * sstep(0.82, 0.98, profile) * 0.9;
	// Labio de las crestas empinadas, aunque no hayan roto.
	float steep = 1.0 - n_geo.y;
	foam += sstep(0.9, 0.99, profile) * sstep(0.18, 0.4, steep) * 0.6;
	foam += sstep(shore_z - 7.0, shore_z - 1.0, world_pos.z) * 0.9;

	// Whitewater on the surface where the falling lip actually meets it.
	float tube_ahead = (world_pos.x-peel_x)*peel_dir;
	float tube_gate = started * sstep(-1.0, 0.4, tube_ahead) * (1.0-sstep(5.6,6.8,tube_ahead));
	float impact = (u-front_width*1.66)/(0.34+0.23*breakup);
	foam += clamp(tube_strength,0.0,1.0)*tube_gate*exp(-impact*impact)*(0.65+0.55*nz2);
	// Thin separated ribbons read as broken water rather than a solid white stripe.
	float ribbons = sstep(0.48,0.72,streak)*sstep(0.35,0.72,nz2);
	foam += broken*exp(-pow((u-1.8)/4.0,2.0))*ribbons*0.35;

	// Contacto de la tabla y estela: dos bordes en V y espuma fina en el centro.
	float wk = 0.0;
	if (world_pos.x>=wake_bounds.x && world_pos.z>=wake_bounds.y && world_pos.x<=wake_bounds.z && world_pos.z<=wake_bounds.w) {
		if(board.w>0.0) {
			vec2 f=normalize(board_rails.xy+vec2(0.00001));
			vec2 rel=world_pos.xz-board.xy;
			float along=dot(rel,f);
			float across=dot(rel,vec2(f.y,-f.x));
			float contact=exp(-pow((abs(across)-0.23)/0.11,2.0))*exp(-pow(along/0.72,4.0));
			float pressure=0.45+0.45*max(sign(across)*board_rails.z,0.0);
			wk=contact*pressure*clamp((board.z-0.8)/5.0,0.0,1.3);
		}
		for(int i=0;i<11;i++) {
			if(i+1>=wake_count) break;
			float tt;
			float d=seg_dist(world_pos.xz,wake[i].xy,wake[i+1].xy,tt);
			float age=mix(wake[i].z,wake[i+1].z,tt);
			float strength=mix(wake[i].w,wake[i+1].w,tt)*exp(-age*1.1)*(1.0-sstep(1.2,2.2,age));
			float load=mix(wake_load[i],wake_load[i+1],tt);
			strength*=1.0-sstep(float(wake_count)-2.5,float(wake_count)-1.0,float(i)+tt);
			vec2 tangent=normalize(wake[i+1].xy-wake[i].xy+vec2(0.00001));
			vec2 nearest=mix(wake[i].xy,wake[i+1].xy,tt);
			float side=dot(world_pos.xz-nearest,vec2(-tangent.y,tangent.x));
			float width=0.21+min(age,1.5)*0.32;
			float ribbon=exp(-pow((abs(side)-width)/(0.065+age*0.10),2.0));
			float outer=sign(load)*(width+abs(load)*age*0.30);
			float fan=exp(-pow((side-outer)/(0.09+age*0.16),2.0))*abs(load)*0.65;
			float core=exp(-pow(d/(0.14+age*0.09),2.0))*0.12;
			// Restrict ribbons to each finite segment instead of extending a line across the sea.
			float end_gate=exp(-max(d*d-side*side,0.0)/pow(0.15+age*0.10,2.0));
			wk=max(wk,strength*(ribbon*0.85+fan+core)*end_gate);
		}
		wk*=0.40+0.70*nz2;
	}
	foam += wk;

	foam = clamp(foam, 0.0, 1.0);
	float bubbles = vnoise(world_pos.xz * 6.0 + vec2(wave_time * 0.8, 0.0));
	foam = sstep(0.32, 0.78, foam * (0.3 + 0.95 * breakup) + 0.15 * (bubbles - 0.5) * foam);
	vec3 foam_tint = mix(face_color * 1.4, foam_color, 0.62 + 0.32 * breakup);

	ALBEDO = mix(col, foam_tint, foam);
	// Luz que atraviesa la cresta cuando se mira hacia el sol (falso subsuperficial).
	float back = clamp(dot(v, normalize(to_sun)) * 0.5 + 0.5, 0.0, 1.0);
	// Más luz transmitida cerca del labio (agua fina) y casi nada en la base gruesa.
	EMISSION = face_color * thin * (0.06 + 0.26 * back * back) * (0.45 + 0.75 * sstep(0.45, 1.0, lift)) * (1.0 - foam);
	ROUGHNESS = mix(mix(0.19, 0.33, sstep(30.0, 260.0, dist)), 0.85, foam);
	SPECULAR = 0.38;
	METALLIC = 0.0;
	if (debug_flat > 0.5) {
		// Altura codificada en color: R = parte gruesa (64 niveles), G = resto.
		float hv = clamp((world_pos.y + 2.0) / 6.0, 0.0, 0.9999);
		float hi = floor(hv * 64.0) / 64.0;
		ALBEDO = vec3(0.0);
		EMISSION = vec3(hi, (hv - hi) * 64.0, 0.0);
		ROUGHNESS = 1.0;
		SPECULAR = 0.0;
	}
}
