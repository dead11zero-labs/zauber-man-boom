shader_type spatial;
// Flusswasser: dunkles, leicht gruenliches Wasser mit wandernden Wellen, Fresnel-Spiegelung und
// etwas Durchsicht am steilen Blickwinkel. Ohne Texturen, laeuft auch auf dem Mobile-Renderer.

uniform vec3 tief : source_color = vec3(0.02, 0.09, 0.12);
uniform vec3 flach : source_color = vec3(0.07, 0.22, 0.24);
uniform float wellen = 0.35;
uniform float tempo = 0.6;

varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

vec2 welle(vec2 p, vec2 richtung, float laenge, float t) {
	float k = 6.2831853 / laenge;
	float phase = dot(p, richtung) * k + t;
	return richtung * cos(phase) * k;
}

void fragment() {
	float t = TIME * tempo;
	vec2 g = vec2(0.0);
	g += welle(wp.xz, normalize(vec2(1.0, 0.35)), 5.1, t * 1.3) * 0.035;
	g += welle(wp.xz, normalize(vec2(-0.4, 1.0)), 2.3, t * 1.9) * 0.014;
	g += welle(wp.xz, normalize(vec2(0.7, -0.7)), 0.9, t * 2.7) * 0.004;
	g += welle(wp.xz, normalize(vec2(-0.9, -0.2)), 0.47, t * 3.4) * 0.0016;
	vec3 n_welt = normalize(vec3(-g.x * wellen * 6.0, 1.0, -g.y * wellen * 6.0));
	NORMAL = normalize((VIEW_MATRIX * vec4(n_welt, 0.0)).xyz);
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	ALBEDO = mix(flach, tief, 1.0 - fresnel * 0.5);
	METALLIC = 0.0;
	SPECULAR = 0.8;
	ROUGHNESS = 0.05;
	ALPHA = mix(0.94, 1.0, fresnel);
}
