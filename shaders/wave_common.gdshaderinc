// Forma de la ola. Copia exacta de WaveModel.height_at() (scripts/wave_model.gd).
// El script rellena estos uniforms cada fotograma.

uniform float tide = 0.0;
uniform float wave_time;
uniform float crest_z;
uniform float peel_x;
uniform float peel_dir = -1.0;
uniform float started;
uniform float amp;
uniform float front_width = 3.1;
uniform float back_width = 9.0;
uniform float swell_amp = 0.1;
uniform float set_spacing = 70.0;
uniform float set_amp1 = 0.0;
uniform float set_amp2 = 0.0;

float sstep(float a, float b, float x) {
	float t = clamp((x - a) / (b - a), 0.0, 1.0);
	return t * t * (3.0 - 2.0 * t);
}

float swell_at(float x, float z) {
	return swell_amp * sin(0.23 * x + 0.31 * z - 1.3 * wave_time)
		+ swell_amp * 0.7 * sin(-0.17 * x + 0.41 * z - 1.7 * wave_time);
}

// Devuelve la altura; en terms deja (espuma de rotura, pico, perfil, distancia a la cresta).
float wave_height_terms(float x, float z, out vec4 terms) {
	float ahead = (x - peel_x) * peel_dir;
	float broken = started * sstep(0.5, -3.5, ahead);
	float q = (ahead - 1.5) / 4.0;
	float peak = started * exp(-q * q);
	float shoulder = 1.0 - 0.55 * sstep(20.0, 75.0, abs(x - peel_x));
	float xm = -x * peel_dir; // en espejo: el cabo queda siempre en +xm
	float lateral = sstep(-160.0, -120.0, xm) * sstep(45.0, 25.0, xm);
	float a = amp * shoulder * lateral * (1.0 - 0.45 * broken) * (1.0 + 0.18 * peak);
	float wf = front_width * (1.0 - 0.3 * peak) * (1.0 + 0.9 * broken);
	float u = z - crest_z;
	float w = u > 0.0 ? wf : back_width;
	float profile = exp(-(u * u) / (w * w));
	terms = vec4(broken, peak, profile * a / max(amp, 0.01), u);
	float h = a * profile;
	// Resto de la serie: líneas que no rompen.
	float sl = lateral * shoulder;
	float u1 = u + set_spacing;
	float w1 = u1 > 0.0 ? front_width : back_width;
	h += set_amp1 * sl * exp(-(u1 * u1) / (w1 * w1));
	float u2 = u + 2.0 * set_spacing;
	float w2 = u2 > 0.0 ? front_width : back_width;
	h += set_amp2 * sl * exp(-(u2 * u2) / (w2 * w2));
	return tide + h + swell_at(x, z);
}

float wave_height(float x, float z) {
	vec4 t;
	return wave_height_terms(x, z, t);
}
