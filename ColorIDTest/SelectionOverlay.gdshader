shader_type canvas_item;

uniform sampler2D mask_texture : hint_default_black;
uniform vec4 selection_color : source_color = vec4(0.0, 0.4, 0.9, 0.5);
uniform vec4 caret_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float caret_blink_speed : hint_range(0.5, 5.0) = 2.0;

void fragment() {
	vec4 mask = texture(mask_texture, UV);
	vec4 final_color = vec4(0.0);

	// Caret blinking calculation (0.0 to 1.0)
	float blink = step(0.5, fract(TIME * caret_blink_speed));

	// Detect Caret (White)
	if (mask.r > 0.2 && mask.g > 0.2 && mask.b > 0.2) {
		final_color = caret_color;
		final_color.a *= blink; // Apply GPU blinking alpha
	}
	// Detect Selection (Blue)
	else if (mask.b > 0.5 && mask.r < 0.2) {
		final_color = selection_color;
	}

	COLOR = final_color;
}