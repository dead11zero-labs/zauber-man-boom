shader_type canvas_item;
// Leichtes analoges Filmkorn ueber dem Bild.
uniform float staerke = 0.03;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 p = floor(FRAGCOORD.xy * 0.5) + floor(fract(TIME * 24.0) * 24.0) * vec2(91.7, 37.3);
	float g = hash(p) - 0.5;
	COLOR = vec4(vec3(step(0.0, g)), abs(g) * staerke * 2.0);
}
