shader_type spatial;
// Fassaden-Shader: echte PBR-Texturen (Poly Haven, CC0) + prozedurale Fenster mit Rahmen,
// Sprossen, Fensterbaenken, Geschossbaendern, Pilastern, Schaufenstern und Innenleben.
// Gebaeude sind nicht gedreht, daher gilt Objektraum = Weltraum (bis auf die Verschiebung).

uniform sampler2D tex_diff : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_rough : hint_roughness_r, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float tex_size = 4.0; // Meter pro Kachel
uniform float nor_staerke = 1.0;

uniform vec4 base_color : source_color = vec4(1.0, 1.0, 1.0, 1.0); // Toenung der Textur
uniform vec4 window_a : source_color = vec4(0.3, 0.6, 1.0, 1.0);
uniform vec4 window_b : source_color = vec4(1.0, 0.8, 0.3, 1.0);
uniform vec4 window_c : source_color = vec4(1.0, 0.25, 0.2, 1.0);
uniform vec4 accent : source_color = vec4(0.1, 0.9, 1.0, 1.0); // Leuchtband an den Geschossen
uniform float accent_staerke = 0.0;
uniform float emission_strength = 2.0;
uniform float lit_chance = 0.45;
uniform vec2 cell = vec2(3.2, 4.0);
uniform float metallic_val = 0.3;
uniform float roughness_val = 0.5;
// Optional: Farbpalette des Modells (z. B. Kenney-Kits). Flaechen, deren Palettenfarbe dunkler als atlas_schwelle ist,
// gelten als Detail (Gelaender, Rahmen) und bekommen keine Fenster. Ohne Textur (weiss) aendert sich nichts.
uniform sampler2D tex_atlas : source_color, filter_linear_mipmap, repeat_enable, hint_default_white;
uniform float atlas_schwelle = 0.0;
uniform float dach_schwelle = 0.5; // |Normale.y| ab hier gilt als Dach (ohne Fenster); kleiner = mehr Flaechen ohne Fenster
uniform float y_offset = 0.0; // Hoehe des Erdgeschossbodens in Weltmetern (Gebaeude auf einem Plateau)

varying vec3 wpos;
varying vec3 wnrm;
varying vec2 bseed;
varying vec2 wuv;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	bseed = MODEL_MATRIX[3].xz;
	vec3 t = vec3(1.0, 0.0, 0.0);
	if (abs(wnrm.y) < 0.5) {
		t = normalize(cross(vec3(0.0, 1.0, 0.0), wnrm));
	}
	vec3 b = cross(wnrm, t);
	vec3 lp = wpos - vec3(0.0, y_offset, 0.0);
	wuv = vec2(dot(lp, t), -dot(lp, b));
	TANGENT = t;
	BINORMAL = b;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec3 pick(float h, vec3 a, vec3 b, vec3 c) {
	return h < 0.5 ? a : (h < 0.8 ? b : c);
}

void fragment() {
	vec2 uv = wuv / tex_size;
	vec3 tex_c = texture(tex_diff, uv).rgb * base_color.rgb;
	float tex_r = texture(tex_rough, uv).r;
	vec3 nm = texture(tex_nor, uv).rgb;
	float rau = clamp(tex_r + (roughness_val - 0.5), 0.05, 1.0);

	// ---------------- Dach: matte Platten mit Fugen, keine Fenster
	if (abs(wnrm.y) > dach_schwelle) {
		vec2 pg = abs(fract(wuv / 6.0) - 0.5);
		float fuge = 1.0 - smoothstep(0.47, 0.5, max(pg.x, pg.y));
		ALBEDO = tex_c * 0.42 * mix(0.7, 1.0, fuge);
		ROUGHNESS = 0.9;
		METALLIC = 0.0;
		NORMAL_MAP = nm;
		NORMAL_MAP_DEPTH = nor_staerke;
	} else {

	vec2 g = vec2(wuv.x / cell.x, -wuv.y / cell.y);
	vec2 id = floor(g);
	vec2 f = fract(g);
	float hoehe = wpos.y - y_offset;
	bool erdgeschoss = id.y < 1.0;

	// ---------------- Rasterform: Fensteroeffnung, Rahmen, Sprosse
	vec2 lo = erdgeschoss ? vec2(0.06, 0.07) : vec2(0.14, 0.17);
	vec2 hi = erdgeschoss ? vec2(0.94, 0.66) : vec2(0.86, 0.80);
	vec2 rahmen = vec2(0.028, 0.026);
	float offen = step(lo.x, f.x) * step(f.x, hi.x) * step(lo.y, f.y) * step(f.y, hi.y);
	float glas = step(lo.x + rahmen.x, f.x) * step(f.x, hi.x - rahmen.x)
		* step(lo.y + rahmen.y, f.y) * step(f.y, hi.y - rahmen.y);
	float rahmen_m = offen - glas;
	float sprosse = glas * max(
		step(abs(f.x - 0.5), 0.011) * (erdgeschoss ? 0.0 : 1.0),
		step(abs(f.y - 0.66), 0.010));
	glas -= sprosse;
	rahmen_m = clamp(rahmen_m + sprosse, 0.0, 1.0);
	// Fensterbank und Sturz stehen leicht vor
	float bank = step(lo.x - 0.02, f.x) * step(f.x, hi.x + 0.02) * step(lo.y - 0.032, f.y) * step(f.y, lo.y);
	bank *= 1.0 - offen;
	float sturz = step(lo.x - 0.02, f.x) * step(f.x, hi.x + 0.02) * step(hi.y, f.y) * step(f.y, hi.y + 0.022);
	// Geschossband (Deckenplatte) und Pilaster
	float band = step(f.y, 0.085) * (erdgeschoss ? 0.0 : 1.0);
	float pilaster = (step(f.x, 0.04) + step(0.96, f.x)) * (erdgeschoss ? 0.0 : 1.0);
	// Schild ueber dem Schaufenster
	float schild_h = hash(id + bseed * 0.29 + wnrm.xz);
	float schild = erdgeschoss ? step(0.70, f.y) * step(f.y, 0.88) * step(0.12, f.x) * step(f.x, 0.88) * step(0.55, schild_h) : 0.0;
	// unter 2.5 m an Hausecken kein Fenster (Sockelstreifen)
	float sockel = step(hoehe, 0.9);
	offen *= 1.0 - sockel;
	glas *= 1.0 - sockel;

	// ---------------- Raum hinter dem Glas
	float h1 = hash(id + bseed * 0.37 + wnrm.xz * 1.3);
	float on = step(1.0 - (erdgeschoss ? 0.8 : lit_chance), h1);
	float h2 = hash(id.yx + bseed * 0.11);
	vec3 licht = pick(h2, window_a.rgb, window_b.rgb, window_c.rgb);
	float yy = clamp((f.y - lo.y) / (hi.y - lo.y), 0.0, 1.0);
	vec3 raum = licht * (0.5 + 0.5 * smoothstep(0.2, 1.0, yy));
	raum *= 1.0 - 0.45 * smoothstep(0.3, 0.0, yy);
	float v_hash = hash(id * 1.7 + bseed * 0.21);
	float vorhang = step(0.68, v_hash) * step(1.0 - (0.35 + 0.5 * hash(id.yx + 3.1)), yy);
	vec3 vorhang_farbe = mix(vec3(0.95, 0.75, 0.5), licht, 0.25) * 0.75;
	raum = mix(raum, vorhang_farbe, vorhang);
	float flackern = step(0.965, hash(id + bseed * 0.53)) * (0.6 + 0.4 * sin(TIME * 7.0 + hash(id) * 40.0));
	raum *= mix(1.0, flackern, step(0.965, hash(id + bseed * 0.53)));

	// ---------------- Material zusammensetzen
	float mauer = 1.0 - offen;
	vec3 mauer_c = tex_c;
	// Alterung: Dreck am Boden, Laufspuren unter den Fensterbaenken
	mauer_c *= mix(0.55, 1.0, smoothstep(0.0, 16.0, hoehe));
	float spur = step(lo.x, f.x) * step(f.x, hi.x) * (1.0 - clamp(f.y / lo.y, 0.0, 1.0)) * step(f.y, lo.y);
	mauer_c *= 1.0 - 0.38 * spur * hash(vec2(id.x, id.y * 0.37) + bseed);
	mauer_c *= mix(1.0, 0.8, band);
	mauer_c *= mix(1.0, 0.72, pilaster);
	mauer_c = mix(mauer_c, mauer_c * 1.3 + 0.02, max(bank, sturz));

	vec3 rahmen_c = vec3(0.04, 0.045, 0.055);
	vec3 glas_dunkel = vec3(0.02, 0.035, 0.06);

	vec3 alb = mauer_c;
	float met = metallic_val;
	float rgh = rau;
	alb = mix(alb, rahmen_c, rahmen_m);
	met = mix(met, 0.9, rahmen_m);
	rgh = mix(rgh, 0.35, rahmen_m);
	float ist_glas = glas;
	alb = mix(alb, glas_dunkel + raum * 0.04 * on, ist_glas);
	met = mix(met, 0.8, ist_glas);
	rgh = mix(rgh, 0.04, ist_glas);
	alb = mix(alb, vec3(0.03), schild);
	rgh = mix(rgh, 0.3, schild);

	vec3 em = vec3(0.0);
	em += raum * on * ist_glas * emission_strength;
	vec3 schild_licht = pick(hash(id + 7.7), vec3(0.2, 0.9, 1.0), vec3(1.0, 0.75, 0.25), vec3(1.0, 0.25, 0.7));
	em += schild_licht * schild * emission_strength * 0.9;
	// Leuchtband an jedem vierten Geschoss
	float band_licht = (!erdgeschoss && abs(mod(id.y, 4.0)) < 0.5) ? step(0.062, f.y) * step(f.y, 0.085) : 0.0;
	em += accent.rgb * band_licht * accent_staerke * emission_strength * 0.6;

	vec3 atlas_c = texture(tex_atlas, UV).rgb;
	float detail = 1.0 - step(atlas_schwelle, dot(atlas_c, vec3(0.299, 0.587, 0.114)));
	alb = mix(alb, atlas_c * 0.55, detail);
	met = mix(met, 0.3, detail);
	rgh = mix(rgh, 0.6, detail);
	em *= 1.0 - detail;
	ist_glas *= 1.0 - detail;
	rahmen_m *= 1.0 - detail;

	ALBEDO = alb;
	METALLIC = met;
	ROUGHNESS = rgh;
	EMISSION = em;
	NORMAL_MAP = mix(nm, vec3(0.5, 0.5, 1.0), clamp(ist_glas + rahmen_m * 0.5, 0.0, 1.0));
	NORMAL_MAP_DEPTH = nor_staerke;
	}
}
