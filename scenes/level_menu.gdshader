shader_type canvas_item;

uniform float size : hint_range(1.0, 220.0) = 125.0;
uniform vec4 color1 : source_color = vec4(0.396, 0.780, 0.663, 1.0); 
uniform vec4 color2 : source_color = vec4(0.286, 0.690, 0.565, 1.0);
uniform float speed : hint_range(0.0, 10.0) = 0.4;
uniform float direction_x : hint_range(-1.0, 1.0) = 1.0; // Horizontal movement
uniform float direction_y : hint_range(-1.0, 1.0) = 1.0; // Vertical movement

void fragment() {
    vec2 pos = FRAGCOORD.xy / size;
    float time_offset = TIME * speed;

    // Use the slider values for direction and normalize them
    vec2 direction = vec2(direction_x, direction_y);
    if (length(direction) < 0.001) {
        direction = vec2(1.0, 0.0);
    } else {
        direction = normalize(direction);
    }
    vec2 movement = direction * time_offset;

    pos -= movement;
    pos = floor(pos);

    float pattern_mask = mod(pos.x + mod(pos.y, 2.0), 2.0);
    vec4 base_tex = texture(TEXTURE, UV);
    vec4 pattern_color = mix(color1, color2, pattern_mask);
    COLOR = vec4(pattern_color.rgb, base_tex.a);
}
