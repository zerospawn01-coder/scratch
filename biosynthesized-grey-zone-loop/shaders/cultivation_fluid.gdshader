shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, diffuse_burley, specular_schlick_ggx;

// 三国パラメトリック制御用ユニフォーム
uniform vec4 liquid_color : source_color = vec4(0.05, 0.45, 0.55, 0.7);
uniform vec4 glow_color : source_color = vec4(0.0, 0.95, 0.9, 1.0);
uniform float bubble_speed : hint_range(0.1, 8.0) = 1.8;
uniform float distortion_strength : hint_range(0.0, 1.0) = 0.2;
uniform float pulse_speed : hint_range(0.1, 15.0) = 3.5;
uniform float metallic_val : hint_range(0.0, 1.0) = 0.6;
uniform float roughness_val : hint_range(0.0, 1.0) = 0.15;
uniform float emission_energy : hint_range(0.0, 5.0) = 1.2;

void fragment() {
    // 時間とうねりの計算
    float time = TIME * bubble_speed;
    float wave = sin(UV.y * 18.0 + time) * cos(UV.x * 18.0 + time * 0.8);
    
    // エーテル波動パルス
    float pulse = (sin(TIME * pulse_speed) + 1.0) * 0.5;
    vec4 final_col = mix(liquid_color, glow_color, wave * distortion_strength + pulse * 0.35);
    
    ALBEDO = final_col.rgb;
    ALPHA = clamp(liquid_color.a + wave * 0.12, 0.35, 0.95);
    EMISSION = glow_color.rgb * (emission_energy * (0.4 + pulse * 0.6));
    ROUGHNESS = roughness_val;
    METALLIC = metallic_val;
}
