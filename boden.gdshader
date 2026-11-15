shader_type spatial;

uniform vec4 base_color : source_color = vec4(0.06, 0.07, 0.09, 1.0);
uniform vec4 line_color : source_color = vec4(0.1, 0.8, 1.0, 1.0);
uniform float line_emission = 0.7;
uniform float grid = 20.0;

varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 g = wp.xz / grid;
	vec2 d = 0.5 - abs(fract(g) - 0.5);
	float fw = max(fwidth(g.x), fwidth(g.y));
	float l = 1.0 - smoothstep(0.004, 0.004 + fw * 1.5, min(d.x, d.y));
	ALBEDO = base_color.rgb;
	ROUGHNESS = 0.45;
	METALLIC = 0.2;
	EMISSION = line_color.rgb * l * line_emission;
}
