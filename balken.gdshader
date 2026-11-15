shader_type spatial;
// Energiebalken ueber dem Gurken-Monster: Billboard, segmentiert, Neon-Look.
render_mode unshaded, depth_draw_never, cull_disabled;

uniform float fuell : hint_range(0.0, 1.0) = 1.0;
uniform int segmente = 10;

void vertex() {
	// Billboard, Skalierung des Knotens bleibt erhalten
	vec3 s = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(s.x, 0.0, 0.0, 0.0), vec4(0.0, s.y, 0.0, 0.0), vec4(0.0, 0.0, s.z, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	vec2 uv = UV;
	float rahmen = step(uv.x, 0.012) + step(1.0 - 0.012, uv.x) + step(uv.y, 0.08) + step(1.0 - 0.08, uv.y);
	vec3 farbe = vec3(0.02, 0.05, 0.04);
	float alpha = 0.75;
	float x = (uv.x - 0.02) / 0.96;
	if (x >= 0.0 && x <= 1.0 && uv.y > 0.18 && uv.y < 0.82) {
		float seg = x * float(segmente);
		float lueck = step(0.12, fract(seg));
		float an = step(floor(seg) + 0.5, fuell * float(segmente));
		vec3 voll = mix(vec3(1.0, 0.1, 0.2), vec3(0.2, 1.0, 0.2), smoothstep(0.15, 0.6, fuell));
		voll = mix(voll, vec3(1.0, 0.9, 0.1), smoothstep(0.15, 0.35, fuell) * (1.0 - smoothstep(0.35, 0.6, fuell)));
		farbe = mix(vec3(0.1, 0.2, 0.15), voll, an) * lueck;
		alpha = 1.0;
	}
	if (rahmen > 0.0) {
		farbe = vec3(0.1, 0.95, 1.0);
		alpha = 1.0;
	}
	ALBEDO = farbe;
	EMISSION = farbe;
	ALPHA = alpha;
}
