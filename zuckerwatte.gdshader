shader_type spatial;
// Cyber-Baumkronen: Zuckerwatte-Look, Farbe pro Instanz, weiches Eigenleuchten und Rand-Glow.
uniform float glow = 0.2;

varying float oben;

void vertex() {
	oben = clamp(VERTEX.y * 0.35 + 0.5, 0.0, 1.0);
}

void fragment() {
	vec3 c = COLOR.rgb;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	ALBEDO = pow(c, vec3(1.5)) * (0.7 + 0.3 * oben);
	ROUGHNESS = 0.85;
	EMISSION = c * glow + c * rim * 0.4;
}
