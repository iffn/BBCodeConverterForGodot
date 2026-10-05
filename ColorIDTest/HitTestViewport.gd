class_name HitTestViewport
extends SubViewport

@export var visible_label: RichTextLabel
@export var hidden_label: RichTextLabel

var text_buffer: TextBuffer


func _ready() -> void:
	render_target_update_mode = SubViewport.UPDATE_ALWAYS


func setup(buffer: TextBuffer) -> void:
	if text_buffer and text_buffer.text_changed.is_connected(_on_text_changed):
		text_buffer.text_changed.disconnect(_on_text_changed)

	text_buffer = buffer

	if text_buffer:
		text_buffer.text_changed.connect(_on_text_changed)

	sync_label_properties()
	update_hidden_text(text_buffer)


func _on_text_changed() -> void:
	update_hidden_text(text_buffer)


func sync_label_properties() -> void:
	if not visible_label or not hidden_label:
		return

	size = Vector2i(visible_label.size)
	hidden_label.size = visible_label.size
	hidden_label.position = Vector2.ZERO
	hidden_label.autowrap_mode = visible_label.autowrap_mode
	hidden_label.bbcode_enabled = true

	var font = visible_label.get_theme_font("normal_font")
	var font_size = visible_label.get_theme_font_size("normal_font_size")

	if font:
		hidden_label.add_theme_font_override("normal_font", font)
		hidden_label.add_theme_font_override("bold_font", font)
		hidden_label.add_theme_font_override("italics_font", font)
		hidden_label.add_theme_font_override("bold_italics_font", font)
		hidden_label.add_theme_font_override("mono_font", font)

	if font_size > 0:
		hidden_label.add_theme_font_size_override("normal_font_size", font_size)
		hidden_label.add_theme_font_size_override("bold_font_size", font_size)
		hidden_label.add_theme_font_size_override("italics_font_size", font_size)
		hidden_label.add_theme_font_size_override("bold_italics_font_size", font_size)
		hidden_label.add_theme_font_size_override("mono_font_size", font_size)


func sync_scroll(scroll_value: int) -> void:
	if not hidden_label:
		return

	var v_bar = hidden_label.get_v_scroll_bar()
	if v_bar:
		v_bar.value = scroll_value


func update_hidden_text(buffer: TextBuffer) -> void:
	if not hidden_label or not buffer:
		return

	var raw_bbcode: String = buffer.raw_text
	var result_bbcode: String = ""
	var plain_char_counter: int = 0
	var in_tag: bool = false

	var i: int = 0
	while i < raw_bbcode.length():
		var ch: String = raw_bbcode[i]

		if ch == "[":
			in_tag = true
			result_bbcode += ch
			i += 1
			continue
		elif ch == "]":
			in_tag = false
			result_bbcode += ch
			i += 1
			continue

		if in_tag:
			result_bbcode += ch
			i += 1
			continue

		if plain_char_counter < buffer.plain_text_ids.size():
			var char_color: Color = ColorIDMapper.get_color_from_index(buffer, plain_char_counter)
			var hex_color: String = ColorIDMapper.to_bbcode_color(char_color)

			if ch == "\n":
				result_bbcode += "\n"
			else:
				result_bbcode += "[color=" + hex_color + "][bgcolor=" + hex_color + "]" + ch + "[/bgcolor][/color]"

			plain_char_counter += 1
		else:
			result_bbcode += ch

		i += 1

	hidden_label.text = result_bbcode


## Decodes mouse position in viewport to corresponding plain text character index
func get_plain_index_at_position(pos: Vector2) -> int:
	var tex: ViewportTexture = get_texture()
	if not tex or not text_buffer:
		return -1

	var img: Image = tex.get_image()
	if not img:
		return -1

	var img_size: Vector2i = img.get_size()
	var px: int = clampi(int(pos.x), 0, img_size.x - 1)
	var py: int = clampi(int(pos.y), 0, img_size.y - 1)

	var sampled_color: Color = img.get_pixel(px, py)
	return ColorIDMapper.get_index_from_color(text_buffer, sampled_color)


## Locates caret position and dynamic character height for a given plain index
func get_caret_position_from_index(idx: int, preferred_x: float = -1.0) -> Dictionary:
	var default_height: float = _get_font_height()
	var fallback_result := {
		"position": Vector2.ZERO,
		"height": default_height
	}

	if not visible_label or not text_buffer or text_buffer.plain_text.length() == 0 or idx <= 0:
		return fallback_result

	var font = visible_label.get_theme_font("normal_font")
	var font_size: int = visible_label.get_theme_font_size("normal_font_size")
	if font_size <= 0:
		font_size = 16

	var target_char_idx: int = idx - 1
	var target_char: String = text_buffer.plain_text[target_char_idx]

	if target_char in ["\t", "\n"]:
		fallback_result.position = _calculate_font_fallback_pos(idx, font, font_size)
		return fallback_result

	var tex: Texture2D = get_texture()
	if not tex:
		fallback_result.position = _calculate_font_fallback_pos(idx, font, font_size)
		return fallback_result

	var img: Image = tex.get_image()
	if img and target_char_idx < text_buffer.plain_text_ids.size():
		var target_color: Color = ColorIDMapper.get_color_from_index(text_buffer, target_char_idx)
		var estimated_pos: Vector2 = _calculate_font_fallback_pos(idx, font, font_size)

		if preferred_x >= 0.0:
			estimated_pos.x = preferred_x

		var radial_res: Dictionary = _find_target_color_radially(img, estimated_pos, target_color, default_height)
		if radial_res.position != Vector2.INF:
			return radial_res

	fallback_result.position = _calculate_font_fallback_pos(idx, font, font_size)
	return fallback_result


## Finds exact pixel bounds (X, Y, Width, Height) for a character via HitTest color ID
func get_character_bounds(char_idx: int) -> Rect2:
	if not visible_label or not text_buffer or char_idx < 0 or char_idx >= text_buffer.plain_text_ids.size():
		return Rect2()

	var tex: Texture2D = get_texture()
	if not tex:
		return Rect2()

	var img: Image = tex.get_image()
	if not img:
		return Rect2()

	var target_color: Color = ColorIDMapper.get_color_from_index(text_buffer, char_idx)
	var font = visible_label.get_theme_font("normal_font")
	var font_size: int = visible_label.get_theme_font_size("normal_font_size")
	if font_size <= 0:
		font_size = 16

	var estimated_pos: Vector2 = _calculate_font_fallback_pos(char_idx + 1, font, font_size)
	var width: int = img.get_width()
	var height: int = img.get_height()

	var start_x: int = clampi(int(estimated_pos.x), 0, width - 1)
	var start_y: int = clampi(int(estimated_pos.y), 0, height - 1)

	var min_x: int = width
	var max_x: int = -1
	var min_y: int = height
	var max_y: int = -1

	var found: bool = false
	var search_radius: int = 40

	for y in range(max(0, start_y - search_radius), min(height, start_y + search_radius)):
		for x in range(max(0, start_x - search_radius), min(width, start_x + search_radius)):
			var px: Color = img.get_pixel(x, y)
			if px.a > 0.1 and _colors_match(px, target_color):
				found = true
				min_x = min(min_x, x)
				max_x = max(max_x, x)
				min_y = min(min_y, y)
				max_y = max(max_y, y)

	if not found:
		return Rect2()

	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x + 1, max_y - min_y + 1))


func _find_target_color_radially(img: Image, start_pos: Vector2, target_color: Color, default_h: float) -> Dictionary:
	var width: int = img.get_width()
	var height: int = img.get_height()
	var start_x: int = clampi(int(start_pos.x), 0, width - 1)
	var start_y: int = clampi(int(start_pos.y), 0, height - 1)

	var max_radius: int = 200
	var gap_tolerance: int = 2

	for r in range(0, max_radius):
		for y_offset in range(-40, 41):
			var test_y: int = start_y + y_offset
			if test_y < 0 or test_y >= height:
				continue

			for dir in [1, -1]:
				var test_x: int = start_x + (r * dir)
				if test_x < 0 or test_x >= width:
					continue

				var px: Color = img.get_pixel(test_x, test_y)
				if px.a > 0.1 and _colors_match(px, target_color):
					var rightmost_x: int = test_x
					while rightmost_x + 1 < width:
						var next_px: Color = img.get_pixel(rightmost_x + 1, test_y)
						if next_px.a > 0.1 and _colors_match(next_px, target_color):
							rightmost_x += 1
						else:
							break

					var line_top_y: int = test_y
					var curr_y: int = test_y
					var gaps: int = 0

					while curr_y - 1 >= 0:
						var up_px: Color = img.get_pixel(test_x, curr_y - 1)
						if up_px.a > 0.1 and _colors_match(up_px, target_color):
							line_top_y = curr_y - 1
							gaps = 0
						else:
							gaps += 1
							if gaps > gap_tolerance:
								break
						curr_y -= 1

					var line_bottom_y: int = test_y
					curr_y = test_y
					gaps = 0

					while curr_y + 1 < height:
						var down_px: Color = img.get_pixel(test_x, curr_y + 1)
						if down_px.a > 0.1 and _colors_match(down_px, target_color):
							line_bottom_y = curr_y + 1
							gaps = 0
						else:
							gaps += 1
							if gaps > gap_tolerance:
								break
						curr_y += 1

					var measured_h: float = float(line_bottom_y - line_top_y + 1)
					return {
						"position": Vector2(rightmost_x + 1.0, float(line_top_y)),
						"height": max(default_h, measured_h)
					}

	return {
		"position": Vector2.INF,
		"height": default_h
	}


func _colors_match(c1: Color, c2: Color, tol: float = 0.001) -> bool:
	return abs(c1.r - c2.r) < tol and abs(c1.g - c2.g) < tol and abs(c1.b - c2.b) < tol


func _calculate_font_fallback_pos(idx: int, font: Font, font_size: int) -> Vector2:
	var target_char_idx: int = idx - 1
	var line_start: int = _get_line_start(target_char_idx)
	var line_text: String = text_buffer.plain_text.substr(line_start, idx - line_start)
	var adv_x: float = font.get_string_size(line_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x if font else 0.0
	return Vector2(adv_x, _get_line_count(idx) * _get_font_height())


func _get_line_start(char_idx: int) -> int:
	var start: int = text_buffer.plain_text.rfind("\n", char_idx)
	return 0 if start == -1 else start + 1


func _get_line_count(idx: int) -> int:
	return text_buffer.plain_text.substr(0, idx).count("\n")


func _get_font_height() -> float:
	var font = visible_label.get_theme_font("normal_font")
	var font_size: int = visible_label.get_theme_font_size("normal_font_size")
	if font_size <= 0:
		font_size = 16
	return font.get_height(font_size) if font else font_size * 1.2
