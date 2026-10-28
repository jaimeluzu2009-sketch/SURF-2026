shader_type spatial;
// Agua con la ola desplazada en el vértice. Válido para el renderizador Compatibilidad
// (GLES3 / WebGL 2): sin texturas de pantalla ni de profundidad; todo es procedural.
render_mode cull_back, specular_schlick_ggx;

#include "res://shaders/wave_common.gdshaderinc"

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
// 1 = altura codificada en color (lo usa tests/wave_parity.gd).
uniform float debug_flat = 0.0;

varying vec3 world_pos;
varying vec4 wave_terms;
varying vec3 geo_normal;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Gradiente (dx, dz) de un ruido que se desplaza; sirve para inclinar la normal.
vec2 ripple(vec2 p, vec2 drift, float scale) {
	vec2 q = p * scale + drift;
	float n0 = vnoise(q);
	return vec2(vnoise(q + vec2(0.2, 0.0)) - n0, vnoise(q + vec2(0.0, 0.2)) - n0) * 5.0;
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

	// --- Normales: oleaje corto en tres escalas que se mueven con el viento y el mar de fondo.
	vec3 nw = n_geo;
	if (detail_level > 0) {
		float t = wave_time;
		vec2 g = ripple(world_pos.xz, vec2(0.05, 0.35) * t, 0.35) * 0.55;
		g += ripple(world_pos.xz, vec2(-0.45, 0.6) * t, 1.1) * 0.3 * (1.0 - sstep(60.0, 260.0, dist));
		if (detail_level > 1) {
			g += ripple(world_pos.xz, vec2(0.7, -0.3) * t, 3.3) * 0.16 * (1.0 - sstep(20.0, 120.0, dist));
		}
		// En la espuma el agua está revuelta: menos reflejos limpios.
		nw = normalize(n_geo + vec3(-g.x, 0.0, -g.y) * 0.22);
		NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	}

	// --- Color del agua.
	vec3 col = mix(deep_color, shallow_color, sstep(-0.6, 1.6, world_pos.y));
	// Manchas grandes de color (fondos, corrientes, nubes) para romper la uniformidad.
	float patch = vnoise(world_pos.xz * 0.018 + vec2(wave_time * 0.01, 0.0));
	float patch2 = vnoise(world_pos.xz * 0.06 - vec2(0.0, wave_time * 0.02));
	col *= 0.86 + 0.22 * patch;
	col = mix(col, shallow_color, 0.15 * patch2);
	// Cara de la ola: agua fina que deja pasar la luz (más verde y clara).
	float face = sstep(0.25, 0.85, profile) * sstep(-0.5, 0.8, u);
	float thin = sstep(0.6, 0.95, profile) * sstep(-0.3, 0.6, u);
	col = mix(col, face_color, face * 0.7);
	col = mix(col, shallow_color * 1.15, sstep(shore_z - 22.0, shore_z, world_pos.z));
	// Reflejo del cielo según el ángulo (Fresnel): el mar lejano se funde con el horizonte.
	float fres = pow(1.0 - clamp(dot(nw, -v), 0.0, 1.0), 5.0);
	col = mix(col, sky_color * 0.8, clamp(fres * 0.6 + sstep(150.0, 900.0, dist) * 0.25, 0.0, 0.8));

	// --- Espuma.
	float nz1 = vnoise(world_pos.xz * 0.8 + vec2(0.0, wave_time * 0.9));
	float nz2 = vnoise(world_pos.xz * 2.9 - vec2(wave_time * 0.4, 0.0));
	float breakup = nz1 * 0.6 + nz2 * 0.4;
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

	// Contacto de la tabla y estela: dos bordes en V y espuma fina en el centro.
	float wk = 0.0;
	if (board.w > 0.0 && distance(world_pos.xz, board.xy) < 45.0) {
		float spd = clamp(board.z / 6.0, 0.25, 1.3);
		float d0 = distance(world_pos.xz, board.xy);
		wk += exp(-(d0 * d0) / 0.5) * spd;
		for (int i = 0; i < 11; i++) {
			if (i + 1 >= wake_count) {
				break;
			}
			float tt;
			float d = seg_dist(world_pos.xz, wake[i].xy, wake[i + 1].xy, tt);
			float age = mix(wake[i].z, wake[i + 1].z, tt);
			float strength = mix(wake[i].w, wake[i + 1].w, tt) * exp(-age * 0.55);
			float half_w = 0.3 + age * 0.75;
			float edge = (d - half_w) / (0.2 + age * 0.25);
			float core = d / (0.25 + age * 0.2);
			wk = max(wk, strength * (exp(-edge * edge) + 0.45 * exp(-core * core)));
		}
		wk *= 0.55 + 0.7 * nz2;
	}
	foam += wk;

	foam = clamp(foam, 0.0, 1.0);
	float bubbles = vnoise(world_pos.xz * 6.0 + vec2(wave_time * 0.8, 0.0));
	foam = sstep(0.32, 0.78, foam * (0.3 + 0.95 * breakup) + 0.15 * (bubbles - 0.5) * foam);
	vec3 foam_tint = mix(face_color * 1.4, foam_color, 0.55 + 0.45 * breakup);

	ALBEDO = mix(col, foam_tint, foam);
	// Luz que atraviesa la cresta cuando se mira hacia el sol (falso subsuperficial).
	float back = clamp(dot(v, normalize(to_sun)) * 0.5 + 0.5, 0.0, 1.0);
	EMISSION = face_color * thin * (0.08 + 0.22 * back * back) * (1.0 - foam);
	ROUGHNESS = mix(mix(0.05, 0.2, sstep(30.0, 260.0, dist)), 0.85, foam);
	SPECULAR = 0.5;
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
