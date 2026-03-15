shader_type canvas_item;

uniform sampler2D mask_texture : source_color;

void fragment() {
    vec4 mask = texture(mask_texture, SCREEN_UV);
    COLOR = COLOR * vec4(1.0, 1.0, 1.0, mask.r);
}