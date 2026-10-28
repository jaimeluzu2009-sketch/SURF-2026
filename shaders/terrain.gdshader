shader_type spatial;
// Arena, roca y vegetación con detalle procedural en coordenadas del mundo.
// El color base viene de los colores por vértice que pone scripts/beach.gd.
// Sin texturas: no hay repetición visible ni costuras. Compatible con Compatibilidad.
render_mode cull_back;

// 0 arena · 1 roca · 2 tierra / vegetación
uniform int kind = 0;
// 0 sin relieve fino (calidad Baja) · 1 con relieve.
uniform int detail_level = 1;
uniform float water_level = 0.0;

varying vec3 wpos;
varying vec3 wnrm;

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

float sstep(float a, float b, float x) {
	float t = clamp((x - a) / (b - a), 0.0, 1.0);
	return t * t * (3.0 - 2.0 * t);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float dist = length(wpos - CAMERA_POSITION_WORLD);
	float near = 1.0 - sstep(15.0, 90.0, dist);   // el grano fino solo se ve de cerca
	vec3 base = COLOR.rgb;
	float big = vnoise(wpos.xz * 0.045);
	float mid = vnoise(wpos.xz * 0.35 + 7.3);
	float fine = vnoise(wpos.xz * 4.0);
	vec3 n = normalize(wnrm);
	vec2 grad = vec2(0.0);
	float rough = 0.95;
	vec3 col = base;

	// En la roca, los vértices verdes son vegetación (la cima de los cabos): se tratan como tierra.
	int k = kind;
	if (k == 1 && base.g - max(base.r, base.b) > 0.04) {
		k = 2;
	}
	if (k == 0) {
		// Arena: manchas grandes de color, grano fino y ondas de viento en la parte seca.
		col = base * (0.86 + 0.24 * big) * (0.95 + 0.1 * mid);
		col *= 0.93 + 0.14 * mix(0.5, fine, near);
		float h = wpos.y - water_level;
		float wet = 1.0 - sstep(0.15, 1.2, h + 0.35 * (mid - 0.5));
		col = mix(col, col * vec3(0.56, 0.55, 0.58), wet);
		rough = mix(0.95, 0.3, wet);
		if (detail_level > 0) {
			float rip = sin(dot(wpos.xz, vec2(0.25, 1.0)) * 4.5 + mid * 6.0);
			grad = vec2(0.25, 1.0) * cos(dot(wpos.xz, vec2(0.25, 1.0)) * 4.5 + mid * 6.0) * 0.05 * (1.0 - wet) * near;
			grad += (vec2(vnoise(wpos.xz * 4.0 + vec2(0.1, 0.0)), vnoise(wpos.xz * 4.0 + vec2(0.0, 0.1))) - fine) * 0.6 * near;
			col *= 1.0 + 0.04 * rip * (1.0 - wet) * near;
		}
	} else if (k == 1) {
		// Roca: vetas, grietas y zona mojada y brillante junto al agua.
		float vein = vnoise(vec2(wpos.x * 0.6, wpos.y * 2.2 + wpos.z * 0.6));
		col = base * (0.72 + 0.4 * mid) * (0.85 + 0.25 * vein);
		col *= 0.9 + 0.2 * mix(0.5, fine, near);
		float wet = 1.0 - sstep(0.3, 1.8, wpos.y - water_level);
		col = mix(col, col * 0.6, wet);
		rough = mix(0.88, 0.35, wet);
		if (detail_level > 0) {
			grad = (vec2(vnoise(wpos.xz * 4.0 + vec2(0.1, 0.0)), vnoise(wpos.xz * 4.0 + vec2(0.0, 0.1))) - fine) * 0.5 * near;
		}
	} else {
		// Tierra y vegetación: matas de distinto verde y suelo seco entre ellas.
		float bush = sstep(0.35, 0.75, vnoise(wpos.xz * 0.12 + 3.1));
		col = base * (0.8 + 0.3 * big) * mix(1.12, 0.82, bush);
		col *= 0.92 + 0.16 * mid;
		rough = 0.95;
	}

	if (detail_level > 0) {
		vec3 nw = normalize(n + vec3(-grad.x, 0.0, -grad.y));
		NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.35;
}
