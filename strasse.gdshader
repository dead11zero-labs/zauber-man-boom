shader_type spatial;
// Strasse: Asphalt (Poly Haven, CC0) mit aufgemalten Markierungen. Der Balken liegt mit der
// Laengsachse auf lokal z, die Breite auf lokal x (siehe stadt.gd: _balken).
// Markierungen: gestrichelte Mittellinie, durchgezogene Randlinien, leicht abgefahren.

uniform sampler2D tex_diff : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_rough : hint_roughness_r, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float kachel = 5.0;            // Meter pro Textur-Kachel
uniform float breite = 16.0;           // Fahrbahnbreite in Metern
uniform float linie_breite = 0.18;
uniform float rand_abstand = 0.6;      // Randlinie: Abstand zur Fahrbahnkante
uniform float strich = 3.0;            // Laenge eines Mittelstrichs
uniform float luecke = 6.0;            // Luecke zwischen zwei Strichen
uniform vec4 farbe_linie : source_color = vec4(0.82, 0.82, 0.78, 1.0);
uniform vec4 tint : source_color = vec4(0.55, 0.56, 0.58, 1.0);

varying vec3 lokal;
varying vec3 wp;
varying float oben;

void vertex() {
	lokal = VERTEX;
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	oben = step(0.5, NORMAL.y);
}

void fragment() {
	vec2 uv = wp.xz / kachel;
	vec3 asphalt = texture(tex_diff, uv).rgb * tint.rgb;
	float rau = texture(tex_rough, uv).r;
	// Fahrspuren: in den Reifenbahnen etwas dunkler und glatter
	float spur = 0.5 + 0.5 * cos(lokal.x / breite * 4.0 * PI * 2.0);
	asphalt *= mix(0.86, 1.0, spur);
	float kante = abs(lokal.x);
	float aa = fwidth(lokal.x) * 1.5;
	float mitte = 1.0 - smoothstep(linie_breite * 0.5, linie_breite * 0.5 + aa, kante);
	mitte *= step(mod(lokal.z, strich + luecke), strich);
	float rand_pos = breite * 0.5 - rand_abstand;
	float rand_linie = 1.0 - smoothstep(linie_breite * 0.5, linie_breite * 0.5 + aa, abs(kante - rand_pos));
	// Abnutzung: die Farbe folgt der Koernung des Asphalts
	float abrieb = smoothstep(0.25, 0.6, texture(tex_diff, uv * 3.0).g + 0.25);
	float farbe = clamp(mitte + rand_linie, 0.0, 1.0) * abrieb * oben;
	ALBEDO = mix(asphalt, farbe_linie.rgb, farbe * 0.85);
	ROUGHNESS = mix(clamp(rau, 0.35, 1.0) * mix(0.85, 1.0, spur), 0.55, farbe);
	METALLIC = 0.0;
	NORMAL_MAP = texture(tex_nor, uv).rgb;
	NORMAL_MAP_DEPTH = 1.0 - farbe * 0.6;
}
