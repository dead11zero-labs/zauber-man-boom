shader_type spatial;
// Leuchtende Exo-Blumen: Farbverlauf von der Basisfarbe (Instanzfarbe) zur Spitze.
varying float h;

void vertex() {
	h = VERTEX.y;
}

void fragment() {
	vec3 a = COLOR.rgb;
	vec3 b = mix(a.brg, vec3(1.0, 0.95, 0.65), 0.3);
	vec3 c = mix(a, b, smoothstep(-0.5, 0.5, h));
	ALBEDO = c * 0.5;
	ROUGHNESS = 0.4;
	EMISSION = c * 2.0;
}
