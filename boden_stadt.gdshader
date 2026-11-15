shader_type spatial;
// Stadtboden: Pflaster (Poly Haven, CC0) in Weltkoordinaten. Damit die Kachelung auf 700 m nicht
// auffaellt, wird dieselbe Textur zusaetzlich in grossem Massstab als Fleckenmuster eingemischt.

uniform sampler2D tex_diff : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_rough : hint_roughness_r, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float kachel = 4.0;          // Meter pro Textur-Kachel
uniform float flecken = 57.0;        // Meter pro Flecken-Kachel (grobe Helligkeitsschwankung)
uniform float flecken_staerke = 0.35;
uniform vec4 tint : source_color = vec4(0.62, 0.64, 0.68, 1.0);
uniform float nor_staerke = 1.0;

varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// Weltachsen als Tangentenraum, damit die Normal-Map auf jeder Flaeche stimmt
	TANGENT = vec3(1.0, 0.0, 0.0);
	BINORMAL = vec3(0.0, 0.0, 1.0);
}

void fragment() {
	vec2 uv = wp.xz / kachel;
	vec3 c = texture(tex_diff, uv).rgb;
	float grob = dot(texture(tex_diff, wp.xz / flecken + 0.37).rgb, vec3(0.333));
	float grob2 = dot(texture(tex_diff, wp.zx / (flecken * 3.1)).rgb, vec3(0.333));
	float schwankung = mix(1.0, (grob + grob2) * 1.6, flecken_staerke);
	ALBEDO = c * tint.rgb * schwankung;
	ROUGHNESS = clamp(texture(tex_rough, uv).r, 0.3, 1.0);
	METALLIC = 0.0;
	NORMAL_MAP = texture(tex_nor, uv).rgb;
	NORMAL_MAP_DEPTH = nor_staerke;
}
