shader_type canvas_item;

uniform vec4 color_top : source_color = vec4(0.05, 0.08, 0.15, 1.0);
uniform vec4 color_bottom : source_color = vec4(0.12, 0.15, 0.25, 1.0);
uniform float speed : hint_range(0.1, 2.0) = 0.5;

void fragment() {
    // 時間経過でY座標をゆらゆらと揺らす
    float wave = sin(UV.x * 3.0 + TIME * speed) * 0.05;
    float grad_t = clamp(UV.y + wave, 0.0, 1.0);
    
    // なめらかなグラデーションのブレンド
    vec4 final_color = mix(color_top, color_bottom, grad_t);
    
    // 微細なノイズを加えてアナログ感を出す
    float noise = (fract(sin(dot(UV.xy, vec2(12.9898, 78.233))) * 43758.5453) - 0.5) * 0.015;
    COLOR = final_color + vec4(noise, noise, noise, 0.0);
}
