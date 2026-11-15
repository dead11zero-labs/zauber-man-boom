shader_type spatial;
// Leuchtstreifen und Antennenlichter: Farbe kommt pro Instanz aus der MultiMesh-Farbe.
uniform float staerke = 3.0;
uniform float blink_tempo = 0.0;

varying float blink;

void vertex() {
	blink = 1.0;
	if (blink_tempo > 0.0) {
		float ph = fract(sin(dot(MODEL_MATRIX[3].xz, vec2(12.9898, 78.233))) * 43758.5453) * 6.28;
		blink = 0.25 + 0.75 * step(0.0, sin(TIME * blink_tempo + ph));
	}
}

void fragment() {
	ALBEDO = vec3(0.02);
	EMISSION = COLOR.rgb * staerke * blink;
}
