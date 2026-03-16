shader_type canvas_item;

uniform vec2 cell_count = vec2(2.0, 3.0);
uniform vec2 scroll_speed = vec2(-0.015, 0.025);
uniform float alpha_multiplier = 0.9;

void fragment() {
	vec2 grid_uv = UV * cell_count + scroll_speed * TIME;
	vec2 cell = floor(grid_uv);
	float checker = mod(cell.x + cell.y, 2.0);

	vec4 sample_a = texture(TEXTURE, vec2(0.2, 0.2));
	vec4 sample_b = texture(TEXTURE, vec2(0.8, 0.2));
	vec4 checker_color = mix(sample_a, sample_b, checker);
	float mask_alpha = texture(TEXTURE, UV).a;

	COLOR = vec4(checker_color.rgb, checker_color.a * mask_alpha * alpha_multiplier);
}