shader_type spatial;
// Ruhiger Teich: tiefes Tuerkis, leichte Wellen, Himmel/Rosa-Schimmer am flachen Blickwinkel.
uniform vec3 tief : source_color = vec3(0.04, 0.38, 0.5);
uniform vec3 schimmer : source_color = vec3(1.0, 0.45, 0.8);
varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float dx = sin(wp.x * 1.3 + TIME * 0.7) * 0.015 + sin(wp.z * 2.1 - TIME * 0.5 + wp.x * 0.4) * 0.012;
	float dz = sin(wp.z * 1.6 - TIME * 0.6) * 0.015 + sin(wp.x * 2.4 + TIME * 0.45) * 0.012;
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(dx, 0.0, dz, 0.0)).xyz);
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = tief;
	METALLIC = 0.55;
	ROUGHNESS = 0.04;
	EMISSION = schimmer * f * 0.22 + tief * 0.45;
	ALPHA = 0.93;
}
