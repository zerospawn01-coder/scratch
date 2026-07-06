shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform float scanline_density = 720.0;
uniform float scanline_speed = 20.0;
uniform float rgb_shift_px = 7.0;
uniform float glitch_band_density = 24.0;
uniform float noise_amount = 0.08;
uniform float band_jitter = 0.15;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float st = pow(clamp(strength, 0.0, 1.0), 0.7);

	// 強度に応じて、行単位の横ずれをかける
	float band_row = floor(uv.y * glitch_band_density + TIME * (4.0 + st * 8.0));
	float band_rand = hash21(vec2(band_row, floor(TIME * 6.0)));
	float band = smoothstep(0.82, 1.0, band_rand) * st;
	uv.x += (hash21(vec2(band_row, 19.7)) - 0.5) * band_jitter * band;
	uv.y += (hash21(vec2(band_row, 91.3)) - 0.5) * band_jitter * 0.2 * band;

	// 走査線
	float scan = 0.5 + 0.5 * sin((uv.y * scanline_density + TIME * scanline_speed) * 6.2831853);
	float scanline = mix(1.0, 0.82 + 0.18 * scan, st * 0.45);

	// RGB シフト
	vec2 px = SCREEN_PIXEL_SIZE * rgb_shift_px * (0.25 + 0.75 * st);
	vec4 base = texture(screen_tex, uv);
	vec4 red = texture(screen_tex, uv + vec2(px.x, 0.0));
	vec4 blue = texture(screen_tex, uv - vec2(px.x, 0.0));
	vec4 color = vec4(red.r, base.g, blue.b, base.a);

	// グリッチの粒状ノイズ
	float noise = hash21(uv * vec2(180.0, 240.0) + vec2(TIME * 11.0, TIME * 7.0)) - 0.5;
	color.rgb += noise * noise_amount * st;
	color.rgb = mix(color.rgb, color.bgr, 0.06 * band);

	// 微細なフリッカー
	float flicker = 1.0 - (0.04 * st) * hash21(vec2(TIME * 60.0, uv.y * 8.0));
	color.rgb *= scanline * flicker;

	// ほんの少しだけ周辺減衰
	float vignette = smoothstep(1.15, 0.3, length(uv - vec2(0.5)));
	color.rgb *= mix(1.0, vignette, st * 0.12);

	COLOR = color;
}
