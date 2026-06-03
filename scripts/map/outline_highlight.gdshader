shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(1.0, 0.82, 0.08, 1.0);
uniform float outline_width : hint_range(1.0, 6.0, 0.5) = 3.0;
uniform bool outline_enabled = false;

void fragment() {
	vec4 base_color = texture(TEXTURE, UV) * COLOR;
	vec4 final_color = base_color;
	if (outline_enabled) {
		vec2 pixel = TEXTURE_PIXEL_SIZE * outline_width;
		float neighbor_alpha = 0.0;
		neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(pixel.x, 0.0)).a);
		neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(-pixel.x, 0.0)).a);
		neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(0.0, pixel.y)).a);
		neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(0.0, -pixel.y)).a);
		neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(pixel.x, pixel.y)).a);
		neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(-pixel.x, pixel.y)).a);
		neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(pixel.x, -pixel.y)).a);
		neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(-pixel.x, -pixel.y)).a);

		float outline_alpha = max(neighbor_alpha - base_color.a, 0.0);
		vec4 final_outline = vec4(outline_color.rgb, outline_color.a * outline_alpha);
		final_color = mix(final_outline, base_color, base_color.a);
	}
	COLOR = final_color;
}
